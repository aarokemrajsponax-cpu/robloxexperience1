--!strict
-- Circles (§9.7, Appendix H7): clubs of two to twenty. Named from word lists and marked with a
-- crest (each crest held by one Circle), founded for 2,000 Gilt at the Livre d'Or. A guest joins
-- when a member invites them, or asks and the host (the founder) says yes; both happen between
-- guests in the same house. A Circle's week is its five best members' points (the Nightly,
-- ranked Library wins, counted Ballroom evenings), and the top Circles hang on the Tonight board.
-- Records live in a DataStore (one per Circle, plus one per crest to keep crests unique) and the
-- week's scores in an OrderedDataStore, so every server agrees.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)
local Circle = require(ReplicatedStorage.Shared.Circle)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rival = require(ReplicatedStorage.Shared.Rival)
local Analytics = require(script.Parent.Analytics)
local Private = require(script.Parent.Private)
local Profiles = require(script.Parent.Profiles)

local CircleService = {}

export type Member = { name: string, week: number, points: number }
export type Record = {
	id: string,
	adjective: number,
	noun: number,
	emblem: number,
	colour: number,
	host: number, -- the founder's user id
	members: { [string]: Member },
	created: number,
}

-- Tells the house (set by Main): the board's Circles, and a guest's nameplate.
CircleService.board = function(_entries: { { name: string, score: number, crest: string } }) end
CircleService.changed = function(_player: Player) end

local function cfg()
	return Config.data.Circles
end

local store: DataStore? = nil
local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(cfg().storeName)
	end)
	if ok then
		store = s
	end
	return store
end

local function weekStore(week: number): OrderedDataStore?
	local ok, s = pcall(function()
		return DataStoreService:GetOrderedDataStore(cfg().storeName .. "_Week_" .. tostring(week))
	end)
	return if ok then s else nil
end

-- Circles seen by this server, by id.
local records: { [string]: Record } = {}
-- Invitations and requests waiting for an answer: [invitee or host userId] = offer.
type Offer = { kind: "invite" | "request", circle: string, from: number, fromName: string, at: number }
local offers: { [number]: { Offer } } = {}

local function send(player: Player, message: { [string]: any })
	Remotes.event("Shop"):FireClient(player, message)
end

local function choiceOf(r: Record): Circle.Choice
	return { adjective = r.adjective, noun = r.noun, emblem = r.emblem, colour = r.colour }
end

local function count(r: Record): number
	local n = 0
	for _ in r.members do
		n += 1
	end
	return n
end

local function score(r: Record, week: number): number
	local list = {}
	for _, m in r.members do
		if m.week == week then
			table.insert(list, m.points)
		end
	end
	return Circle.weekScore(list)
end

-- The Circle a guest is in (from this server's copy, fetched when needed).
function CircleService.of(data: Profiles.Data): Record?
	local id = data.circle.id
	if id == "" then
		return nil
	end
	local r = records[id]
	if r then
		return r
	end
	local s = getStore()
	if not s then
		return nil
	end
	local ok, value = pcall(function()
		return s:GetAsync("circle:" .. id)
	end)
	if ok and type(value) == "table" then
		records[id] = value :: Record
		return value :: Record
	end
	return nil
end

-- A guest's crest for their nameplate: the glyph and its colour, or nil.
function CircleService.crest(data: Profiles.Data): (string?, Color3?)
	local r = CircleService.of(data)
	if not r then
		return nil, nil
	end
	return Circle.Emblems[r.emblem], Circle.Colours[r.colour]
end

-- Writes to a Circle's record everywhere at once (UpdateAsync), keeping this server's copy.
local function update(id: string, change: (Record) -> Record?): Record?
	local s = getStore()
	local result: Record? = nil
	if s then
		local ok, value = pcall(function()
			return s:UpdateAsync("circle:" .. id, function(old: any)
				if type(old) ~= "table" then
					return nil
				end
				return change(old :: Record)
			end)
		end)
		if ok and type(value) == "table" then
			result = value :: Record
		end
	elseif records[id] then
		-- No DataStore (a Studio place with API access off): keep it in this server only.
		result = change(records[id])
	end
	if result then
		records[id] = result
	end
	return result
end

local function publishWeek(r: Record)
	if count(r) < cfg().minMembers then
		return
	end
	local week = Rival.week()
	local ods = weekStore(week)
	if ods then
		local value = score(r, week)
		task.spawn(function()
			pcall(function()
				(ods :: OrderedDataStore):SetAsync(r.id, value)
			end)
		end)
	end
end

-- Founds a Circle: a name from the lists, a crest nobody holds, 2,000 Gilt.
function CircleService.found(player: Player, data: Profiles.Data, choice: any): { [string]: any }
	if not cfg().enabled then
		return { ok = false, why = "Circles aren't open yet." }
	elseif data.circle.id ~= "" then
		return { ok = false, why = "You're already in a Circle." }
	elseif not Circle.valid(choice) then
		return { ok = false, why = "Choose a name and a crest." }
	elseif data.gilt < cfg().foundGilt then
		return { ok = false, why = string.format("Founding a Circle takes %d Gilt.", cfg().foundGilt) }
	end
	local c = choice :: Circle.Choice
	local id = string.sub(string.gsub(HttpService:GenerateGUID(false), "-", ""), 1, 12)
	-- Claim the crest: it's one Circle's alone.
	local s = getStore()
	if s then
		local ok, holder = pcall(function()
			return s:UpdateAsync(Circle.crestKey(c), function(old: any)
				if type(old) == "string" and old ~= "" then
					return nil -- held already: leave it
				end
				return id
			end)
		end)
		if not ok then
			return { ok = false, why = "The house's books are busy. Try again in a moment." }
		elseif holder ~= id then
			return { ok = false, why = "That crest belongs to another Circle." }
		end
	else
		for _, r in records do
			if r.emblem == c.emblem and r.colour == c.colour then
				return { ok = false, why = "That crest belongs to another Circle." }
			end
		end
	end
	local week = Rival.week()
	local r: Record = {
		id = id,
		adjective = c.adjective,
		noun = c.noun,
		emblem = c.emblem,
		colour = c.colour,
		host = player.UserId,
		members = { [tostring(player.UserId)] = { name = Names.of(player), week = week, points = if data.circle.week == week then data.circle.points else 0 } },
		created = os.time(),
	}
	if s then
		local ok = pcall(function()
			s:SetAsync("circle:" .. id, r)
		end)
		if not ok then
			return { ok = false, why = "The house's books are busy. Try again in a moment." }
		end
	end
	records[id] = r
	data.gilt -= cfg().foundGilt
	Analytics.sink(player, "Gilt", cfg().foundGilt, data.gilt, "Circle")
	data.circle.id = id
	CircleService.changed(player)
	return { ok = true, name = Circle.name(c) }
end

local function join(player: Player, data: Profiles.Data, id: string): { [string]: any }
	local full = false
	local r = update(id, function(old)
		if count(old) >= cfg().maxMembers then
			full = true
			return nil
		end
		old.members[tostring(player.UserId)] = { name = Names.of(player), week = data.circle.week, points = data.circle.points }
		return old
	end)
	if full then
		return { ok = false, why = "That Circle is full." }
	elseif not r then
		return { ok = false, why = "The house's books are busy. Try again in a moment." }
	end
	data.circle.id = id
	publishWeek(r)
	CircleService.changed(player)
	return { ok = true, name = Circle.name(choiceOf(r)) }
end

local function offer(to: Player, o: Offer)
	local list = offers[to.UserId] or {}
	offers[to.UserId] = list
	for i = #list, 1, -1 do
		if list[i].circle == o.circle and list[i].from == o.from then
			table.remove(list, i)
		end
	end
	table.insert(list, o)
end

local function takeOffer(userId: number, kind: string, circle: string, from: number): Offer?
	local list = offers[userId]
	if not list then
		return nil
	end
	for i, o in list do
		if o.kind == kind and o.circle == circle and o.from == from and os.clock() - o.at <= cfg().inviteSeconds then
			table.remove(list, i)
			return o
		end
	end
	return nil
end

-- A member invites a guest in this house.
function CircleService.invite(player: Player, data: Profiles.Data, userId: number): { [string]: any }
	local r = CircleService.of(data)
	local target = Players:GetPlayerByUserId(userId)
	local targetData = target and Profiles.get(target)
	if not r then
		return { ok = false, why = "You're not in a Circle." }
	elseif not target or not targetData or target == player then
		return { ok = false, why = "They've left the house." }
	elseif targetData.circle.id ~= "" then
		return { ok = false, why = Names.of(target) .. " is already in a Circle." }
	elseif count(r) >= cfg().maxMembers then
		return { ok = false, why = "Your Circle is full." }
	end
	offer(target, { kind = "invite", circle = r.id, from = player.UserId, fromName = Names.of(player), at = os.clock() })
	send(target, { op = "circleOffer", kind = "invite", circle = r.id, from = player.UserId, fromName = Names.of(player), name = Circle.name(choiceOf(r)), emblem = r.emblem, colour = r.colour })
	return { ok = true }
end

-- A guest asks to join the Circle of someone in this house; the host is asked.
function CircleService.request(player: Player, data: Profiles.Data, userId: number): { [string]: any }
	local member = Players:GetPlayerByUserId(userId)
	local memberData = member and Profiles.get(member)
	local r = memberData and CircleService.of(memberData)
	if data.circle.id ~= "" then
		return { ok = false, why = "You're already in a Circle." }
	elseif not r then
		return { ok = false, why = "They're not in a Circle." }
	end
	local host = Players:GetPlayerByUserId(r.host)
	if not host then
		return { ok = false, why = "The Circle's host isn't in the house tonight. Ask a member to invite you." }
	end
	offer(host, { kind = "request", circle = r.id, from = player.UserId, fromName = Names.of(player), at = os.clock() })
	send(host, { op = "circleOffer", kind = "request", circle = r.id, from = player.UserId, fromName = Names.of(player), name = Circle.name(choiceOf(r)), emblem = r.emblem, colour = r.colour })
	return { ok = true }
end

-- Yes or no to an invitation (by the invitee) or a request (by the host).
function CircleService.answer(player: Player, data: Profiles.Data, kind: string, circle: string, from: number, yes: boolean): { [string]: any }
	local o = takeOffer(player.UserId, kind, circle, from)
	if not o then
		return { ok = false, why = "That has lapsed." }
	elseif not yes then
		return { ok = true }
	end
	if kind == "invite" then
		if data.circle.id ~= "" then
			return { ok = false, why = "You're already in a Circle." }
		end
		return join(player, data, circle)
	end
	-- A request: the host said yes, so the asker joins.
	local asker = Players:GetPlayerByUserId(from)
	local askerData = asker and Profiles.get(asker)
	local r = CircleService.of(data)
	if not asker or not askerData then
		return { ok = false, why = "They've left the house." }
	elseif not r or r.id ~= circle or r.host ~= player.UserId then
		return { ok = false, why = "Only the host can say yes." }
	elseif askerData.circle.id ~= "" then
		return { ok = false, why = Names.of(asker) .. " is already in a Circle." }
	end
	local result = join(asker, askerData, circle)
	if result.ok then
		send(asker, { op = "notice", title = "Circles", line = "Welcome to " .. tostring(result.name) .. "." })
	end
	return result
end

function CircleService.leave(player: Player, data: Profiles.Data): { [string]: any }
	local id = data.circle.id
	if id == "" then
		return { ok = false, why = "You're not in a Circle." }
	end
	local emptied = false
	local r = update(id, function(old)
		old.members[tostring(player.UserId)] = nil
		if old.host == player.UserId then
			-- The host's chair passes to the member who has been here longest this week.
			local best, bestPoints = nil, -1
			for uid, m in old.members do
				if m.points > bestPoints then
					best, bestPoints = tonumber(uid), m.points
				end
			end
			old.host = best or 0
		end
		emptied = next(old.members) == nil
		return old
	end)
	data.circle.id = ""
	if r and emptied then
		-- The last one out gives the crest back.
		local s = getStore()
		if s then
			task.spawn(function()
				pcall(function()
					s:RemoveAsync(Circle.crestKey(choiceOf(r)))
				end)
			end)
		end
		records[id] = nil
	elseif r then
		publishWeek(r)
	end
	CircleService.changed(player)
	return { ok = true }
end

-- Points for something a member did: added to their week and their Circle's.
function CircleService.add(player: Player, source: string, detail: number?)
	if not cfg().enabled or not Private.records() then
		return
	end
	local data = Profiles.get(player)
	if not data then
		return
	end
	local points = Circle.points(source, detail)
	if points <= 0 then
		return
	end
	local week = Rival.week()
	if data.circle.week ~= week then
		data.circle.week = week
		data.circle.points = 0
	end
	data.circle.points += points
	local id = data.circle.id
	if id == "" then
		return
	end
	local total = data.circle.points
	task.spawn(function()
		local r = update(id, function(old)
			local key = tostring(player.UserId)
			if not old.members[key] then
				return nil -- they were removed elsewhere
			end
			old.members[key] = { name = Names.of(player), week = week, points = total }
			return old
		end)
		if r then
			publishWeek(r)
		end
	end)
end

-- What the Livre d'Or shows a guest: their Circle, or how to found or join one.
function CircleService.view(player: Player, data: Profiles.Data): { [string]: any }
	local week = Rival.week()
	local r = CircleService.of(data)
	local out: { [string]: any } = {
		enabled = cfg().enabled,
		adjectives = Circle.Adjectives,
		nouns = Circle.Nouns,
		emblems = Circle.Emblems,
		emblemNames = Circle.EmblemNames,
		colourNames = Circle.ColourNames,
		foundGilt = cfg().foundGilt,
		gilt = data.gilt,
		max = cfg().maxMembers,
	}
	if r then
		local members = {}
		for uid, m in r.members do
			table.insert(members, { userId = tonumber(uid), name = m.name, points = if m.week == week then m.points else 0, host = tonumber(uid) == r.host })
		end
		table.sort(members, function(a, b)
			return a.points > b.points
		end)
		out.circle = { id = r.id, name = Circle.name(choiceOf(r)), emblem = r.emblem, colour = r.colour, members = members, score = score(r, week), host = r.host == player.UserId }
	end
	-- Guests in the house: to invite (if you're in a Circle) or to ask to join (if you aren't).
	local guests = {}
	for _, other in Players:GetPlayers() do
		local od = if other ~= player then Profiles.get(other) else nil
		if od then
			local theirs = CircleService.of(od)
			if r and not theirs then
				table.insert(guests, { userId = other.UserId, name = Names.of(other), action = "invite" })
			elseif not r and theirs then
				table.insert(guests, { userId = other.UserId, name = Names.of(other), action = "request", circle = Circle.name(choiceOf(theirs)) })
			end
		end
	end
	out.guests = guests
	return out
end

-- The week's top Circles, for the Tonight board.
local function refreshBoard()
	local ods = weekStore(Rival.week())
	if not ods then
		return
	end
	local ok, pages = pcall(function()
		return (ods :: OrderedDataStore):GetSortedAsync(false, cfg().boardTop)
	end)
	if not ok or not pages then
		return
	end
	local entries = {}
	for _, row in (pages :: DataStorePages):GetCurrentPage() do
		local r = records[row.key]
		if not r then
			local s = getStore()
			local okGet, value = pcall(function()
				return if s then s:GetAsync("circle:" .. row.key) else nil
			end)
			if okGet and type(value) == "table" then
				r = value :: Record
				records[row.key] = r
			end
		end
		if r then
			table.insert(entries, { name = Circle.name(choiceOf(r)), score = row.value, crest = Circle.Emblems[r.emblem] })
		end
	end
	CircleService.board(entries)
end

function CircleService.start()
	Players.PlayerRemoving:Connect(function(player)
		offers[player.UserId] = nil
	end)
	if not cfg().enabled then
		return
	end
	task.spawn(function()
		while true do
			refreshBoard()
			task.wait(cfg().refreshSeconds)
		end
	end)
end

return CircleService

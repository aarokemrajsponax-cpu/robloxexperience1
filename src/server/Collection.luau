--!strict
-- What a guest has gathered and become (§11): the Register (every piece, first found, how many,
-- best room), Mythics with their serial numbers (a global count per Mythic, announced on the
-- Tonight board in every server), House Standing (the Concierge says so when it rises), the
-- Evening's and the Week's Commissions, and Roblox badges.

local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Commissions = require(ReplicatedStorage.Shared.Commissions)
local Config = require(ReplicatedStorage.Shared.Config)
local Rating = require(ReplicatedStorage.Shared.Rating)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Standing = require(ReplicatedStorage.Shared.Standing)

local Analytics = require(script.Parent.Analytics)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)

local Collection = {}

-- Set by Main.
Collection.say = function(_player: Player, _line: string) end
Collection.notice = function(_player: Player, _title: string, _line: string) end
Collection.announce = function(_text: string) end
Collection.ledger = function(_player: Player, _source: string) end

local function record(data: Profiles.Data): any
	local d = data :: any
	d.badges = d.badges or {}
	d.mythics = d.mythics or {}
	d.commissions = d.commissions or { evening = { key = "", progress = 0, done = false }, week = { key = "", progress = 0, done = false } }
	d.standing = d.standing or "Guest"
	return d
end

---------------------------------------------------------------------------------------------------
-- Badges
---------------------------------------------------------------------------------------------------
function Collection.badge(player: Player, key: string)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local d = record(data)
	if d.badges[key] then
		return
	end
	d.badges[key] = true
	local id = (Config.data.Badges :: any)[key]
	if type(id) == "number" and id ~= 0 then
		task.spawn(function()
			pcall(function()
				BadgeService:AwardBadge(player.UserId, id)
			end)
		end)
	end
	Analytics.custom(player, "Badge", nil, { key = key })
end

---------------------------------------------------------------------------------------------------
-- House Standing
---------------------------------------------------------------------------------------------------
function Collection.standing(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local d = record(data)
	local now = (Standing.of(data.nights.count, data.stats.rounds))
	local before = table.find(Standing.order, d.standing) or 1
	local after = table.find(Standing.order, now) or 1
	if after > before then
		d.standing = now
		Collection.say(player, string.format("You're a %s of the house now.", now))
		Analytics.custom(player, "Standing", after, { standing = now })
	end
end

---------------------------------------------------------------------------------------------------
-- Commissions
---------------------------------------------------------------------------------------------------
local function tick(player: Player, slot: string, g: Commissions.Goal, kind: Commissions.Kind, room: string?, case: string?)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local d = record(data)
	local state = d.commissions[slot]
	if state.key ~= g.id then
		d.commissions[slot] = { key = g.id, progress = 0, done = false }
		state = d.commissions[slot]
	end
	if state.done then
		return
	end
	local step = Commissions.progress(g, kind, room, case)
	if step <= 0 then
		return
	end
	state.progress = math.min(g.target, state.progress + step)
	if state.progress >= g.target then
		state.done = true
		local big = slot == "week"
		local paid = Gilt.pay(player, data, Commissions.reward(big), if big then "The Week's Commission" else "The Evening Commission")
		Collection.ledger(player, if big then "week" else "evening")
		Collection.notice(player, if big then "The Week's Commission" else "The Evening Commission", string.format("%s. +%d Gilt.", g.text, paid))
		Analytics.custom(player, "Commission done", nil, { slot = slot, goal = g.id })
	end
end

-- Something happened that a Commission might count.
function Collection.event(player: Player, kind: Commissions.Kind, room: string?, case: string?)
	tick(player, "evening", Commissions.evening(), kind, room, case)
	tick(player, "week", Commissions.weekly(), kind, room, case)
end

function Collection.commissions(data: Profiles.Data): { { [string]: any } }
	local d = record(data)
	local out = {}
	local specs: { { slot: string, goal: Commissions.Goal, label: string } } = {
		{ slot = "evening", goal = Commissions.evening(), label = "This evening" },
		{ slot = "week", goal = Commissions.weekly(), label = "This week" },
	}
	for _, spec in specs do
		local slot, g, label = spec.slot, spec.goal, spec.label
		local state = d.commissions[slot]
		local progress = if state.key == g.id then state.progress else 0
		local done = state.key == g.id and state.done
		table.insert(out, { label = label, text = g.text, progress = progress, target = g.target, done = done, gilt = Commissions.reward(slot == "week") })
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Mythics: a serial number from a global count
---------------------------------------------------------------------------------------------------
local function nextSerial(mythicId: string): number?
	local ok, result = pcall(function()
		local store = DataStoreService:GetDataStore("MaisonNoir_Mythics")
		return store:UpdateAsync(mythicId, function(old: number?)
			return (old or 0) + 1
		end)
	end)
	return if ok and type(result) == "number" then result else nil
end

function Collection.serialText(n: number): string
	return string.format("No. %05d", n)
end

local function mythicFiled(player: Player, piece: Catalogue.Piece, roomId: string)
	task.spawn(function()
		local serial = nextSerial(piece.id)
		local data = Profiles.get(player)
		if not data then
			return
		end
		local d = record(data)
		local entry = { serial = serial or 0, at = os.time(), room = roomId }
		table.insert(d.mythics, { id = piece.id, serial = entry.serial, at = entry.at, room = roomId })
		local room = Rooms.get(roomId)
		local serialText = if serial then Collection.serialText(serial) else "its number to follow"
		Collection.say(player, string.format("It's yours: %s, %s.", piece.name, serialText))
		Collection.announce(string.format("%s · %s was found in %s.", piece.name, serialText, if room then room.name else "the house"))
		Collection.badge(player, "mythic")
		Analytics.custom(player, "Mythic filed", serial, { mythic = piece.id, room = roomId })
	end)
end

---------------------------------------------------------------------------------------------------
-- The Register
---------------------------------------------------------------------------------------------------
local function registered(data: Profiles.Data): number
	local n = 0
	for _ in data.register do
		n += 1
	end
	return n
end

-- A correct filing in the rooms or the Nightly (TableService registers the entry itself).
function Collection.filed(player: Player, pieceId: string, roomId: string, isNew: boolean)
	local piece = Catalogue.byId[pieceId]
	if not piece then
		return
	end
	Collection.event(player, "file", roomId, piece.case)
	local data = Profiles.get(player)
	if not data then
		return
	end
	if piece.mythic then
		mythicFiled(player, piece, roomId)
	end
	if isNew then
		local n = registered(data)
		for _, step in { 10, 25, 50 } do
			if n >= step then
				Collection.badge(player, "register" .. step)
			end
		end
		-- A season's full set.
		if piece.season then
			local complete = true
			for _, p in Catalogue.seasonalFor(piece.season) do
				if not data.register[p.id] then
					complete = false
				end
			end
			if complete then
				Collection.badge(player, "seasonSet")
			end
		end
	end
end

function Collection.round(player: Player, roomId: string, grade: string)
	Collection.badge(player, "firstRound")
	if grade == "Flawless" then
		Collection.badge(player, "firstFlawless")
		Collection.event(player, "flawless", roomId)
	end
	Collection.event(player, "rounds", roomId)
	Collection.standing(player)
end

function Collection.nightly(player: Player)
	Collection.badge(player, "firstNightly")
	Collection.event(player, "nightly")
end

function Collection.library(player: Player, won: boolean)
	if won then
		Collection.badge(player, "firstLibraryWin")
	end
	Collection.event(player, "library")
	local data = Profiles.get(player)
	if data and data.duel.matches >= Config.data.Library.placementMatches then
		Collection.badge(player, "mark")
	end
end

function Collection.ballroom(player: Player, place: number)
	if place == 1 then
		Collection.badge(player, "firstLastLamp")
	end
	Collection.event(player, "ballroom")
end

function Collection.arrived(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	record(data)
	Collection.standing(player)
	if data.flags.midnight then
		Collection.badge(player, "midnight")
	end
	-- The Founding Term: anyone who plays during the first Term after launch.
	local founding = (Config.data :: any).FoundingTerm
	if type(founding) == "string" and founding ~= "" and Rating.term().id == founding then
		Collection.badge(player, "foundingTerm")
	end
end

-- The Register as the guest's screen shows it.
function Collection.view(data: Profiles.Data): { [string]: any }
	local d = record(data)
	local standing, level = Standing.of(data.nights.count, data.stats.rounds)
	local nextName = Standing.order[level + 1]
	local s = Config.data.Standing :: any
	local keys = { "member", "patron", "connoisseur", "custodian", "keeper" }
	local nextKey = keys[level]
	local odds = {}
	for _, roomId in { "salon", "velvet", "obsidian", "midnight" } do
		local room = Rooms.get(roomId)
		if room then
			table.insert(odds, { room = room.name, chance = room.tuning.mythicChance })
		end
	end
	local badgeCount = 0
	for _ in d.badges do
		badgeCount += 1
	end
	return {
		register = data.register,
		mythics = d.mythics,
		standing = standing,
		next = if nextName and nextKey then { name = nextName, nights = s[nextKey .. "Nights"], rounds = s[nextKey .. "Rounds"] } else nil,
		nights = data.nights.count,
		rounds = data.stats.rounds,
		commissions = Collection.commissions(data),
		odds = odds,
		badges = badgeCount,
		total = Catalogue.totalCollectable(),
	}
end

return Collection

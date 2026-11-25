--!strict
-- (Build 96) Boosters, bought with Gilt (Shared/Boosters has the list). A guest's screen names
-- the booster's id and nothing else: what it does, for how long and what it costs come from the
-- list here, and Gilt is taken only when the guest holds enough. One of each kind runs at a time
-- (the same one bought again adds its time, two hours ahead at most). What runs is kept in the
-- guest's record, so a booster bought before a server hop keeps running in the next server.
-- Published for the guest's screen as BoosterGiltUntil / BoosterSquadUntil / BoosterXPUntil.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fortune = require(ReplicatedStorage.Shared.Fortune)
local List = require(ReplicatedStorage.Shared.Boosters)
local Analytics = require(script.Parent.Analytics)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)

local Boosters = {}

-- Set by Main (server/Brainrots.overtime): starts the squad's Overtime; returns when it ends, or
-- nil when a stronger boost is filling the jar already.
Boosters.squad = function(_player: Player, _data: Profiles.Data, _mult: number, _seconds: number, _cap: number): number?
	return nil
end
-- Set by Main (server/Brainrots.rate): what the guest's squad earns an hour, for the shelf's line.
Boosters.squadRate = function(_data: Profiles.Data): number
	return 0
end
-- Set by Main: the Badge Book and the guest's own screen.
Boosters.award = function(_player: Player, _key: string) end
Boosters.now = function(): number
	return os.time()
end

type Running = { id: string, untilAt: number }

local function page(data: Profiles.Data): { [string]: Running }
	local d = data :: any
	if type(d.boosters) ~= "table" then
		d.boosters = {}
	end
	local b = d.boosters
	for kind in List.Attribute do
		local r = b[kind]
		if type(r) ~= "table" or type(r.id) ~= "string" or type(r.untilAt) ~= "number" or List.byId[r.id] == nil then
			b[kind] = nil
		end
	end
	return b
end

-- What `kind` is running for this record now, or nil.
function Boosters.running(data: Profiles.Data, kind: string): (List.Booster?, number)
	local r = page(data)[kind]
	if r and r.untilAt > Boosters.now() then
		return List.byId[r.id], r.untilAt - Boosters.now()
	end
	return nil, 0
end

-- The multiplier `kind` gives the guest now (1 when nothing runs).
local function mult(player: Player, kind: string): number
	local data = Profiles.get(player)
	if not data then
		return 1
	end
	local b = Boosters.running(data, kind)
	return if b then b.mult else 1
end

function Boosters.giltMult(player: Player): number
	return mult(player, "gilt")
end

function Boosters.xpMult(player: Player): number
	return mult(player, "xp")
end

-- Gilt earned this session, for the cards' honest "what you've earned" line.
local session: { [Player]: { gilt: number, since: number } } = {}

function Boosters.earned(player: Player, paid: number)
	local s = session[player]
	if not s then
		s = { gilt = 0, since = Boosters.now() }
		session[player] = s
	end
	s.gilt += math.max(0, paid)
end

function Boosters.apply(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	for kind, attribute in List.Attribute do
		local r = page(data)[kind]
		player:SetAttribute(attribute, if r and r.untilAt > Boosters.now() then r.untilAt else nil)
		player:SetAttribute(attribute .. "Id", if r and r.untilAt > Boosters.now() then r.id else nil)
	end
end

-- What the Boutique's Boosters shelf shows.
function Boosters.state(player: Player, data: Profiles.Data): { [string]: any }
	local out = {}
	-- What each would add, from the guest's own record: their Gilt from play this visit (once
	-- they've played a while), and their squad's rate. Said as "about": a pace, not a promise.
	local s = session[player]
	local minutes = if s then (Boosters.now() - s.since) / 60 else 0
	local pace = if s and minutes >= List.PACE_MINUTES then s.gilt / minutes else nil
	local squadRate = Boosters.squadRate(data)
	for _, b in List.List do
		local running, left = Boosters.running(data, b.kind)
		local estimate: number? = nil
		if b.kind == "gilt" and pace then
			estimate = math.floor(pace * (b.seconds / 60) * (b.mult - 1) / 10 + 0.5) * 10
		elseif b.kind == "squad" and squadRate > 0 then
			estimate = math.floor(squadRate * (b.seconds / 3600) * (b.mult - 1) + 0.5)
		end
		table.insert(out, {
			id = b.id,
			name = b.name,
			kind = b.kind,
			mult = b.mult,
			seconds = b.seconds,
			gilt = Fortune.scaled(b.gilt), -- (Build 105: at the house's Gilt scale, as payouts are)
			glyph = b.glyph,
			line = b.line,
			colour = b.colour,
			running = if running and running.id == b.id then left else nil,
			blockedBy = if running and running.id ~= b.id then running.name else nil,
			estimate = estimate,
			squadRate = if b.kind == "squad" then squadRate else nil,
		})
	end
	return {
		list = out,
		session = if s then { gilt = s.gilt, minutes = math.max(1, math.floor((Boosters.now() - s.since) / 60)) } else nil,
	}
end

function Boosters.buy(player: Player, data: Profiles.Data, id: string): { [string]: any }
	local b = List.byId[id]
	if not b then
		return { ok = false, why = "That booster isn't sold here." }
	end
	local now = Boosters.now()
	local running, left = Boosters.running(data, b.kind)
	if running and running.id ~= b.id then
		return { ok = false, why = string.format("%s is running: %s left. This one can start when it's done.", running.name, List.duration(left)) }
	end
	if running and left + b.seconds > List.CAP then
		return { ok = false, why = string.format("%s already runs %s more: that's as far ahead as it goes.", b.name, List.duration(left)) }
	end
	-- (Build 105) Priced at the house's Gilt scale, like everything it pays.
	local cost = Fortune.scaled(b.gilt)
	if data.gilt < cost then
		return { ok = false, short = "Gilt", why = string.format("Insufficient Gilt: %s more.", Gilt.format(cost - data.gilt)) }
	end
	local untilAt: number
	if b.kind == "squad" then
		local ends = Boosters.squad(player, data, b.mult, b.seconds, List.CAP)
		if not ends then
			return { ok = false, why = "A stronger boost is filling your squad's jar already: save this for later." }
		end
		untilAt = ends
	else
		untilAt = math.min(now + List.CAP, (if running then now + left else now) + b.seconds)
	end
	data.gilt -= cost
	Analytics.sink(player, "Gilt", cost, data.gilt, "booster_" .. b.id)
	page(data)[b.kind] = { id = b.id, untilAt = untilAt }
	Gilt.changed(player)
	Boosters.apply(player)
	Boosters.award(player, "booster")
	return { ok = true, notice = { title = b.name, line = string.format("%s · %s left.", b.line, List.duration(untilAt - now)) } }
end

function Boosters.start()
	local function hello(player: Player)
		task.spawn(function()
			local data = Profiles.wait(player, 30)
			if data and player.Parent == Players then
				Boosters.apply(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hello)
	for _, p in Players:GetPlayers() do
		hello(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		session[p] = nil
	end)
	-- They run out on their own: the chips on screen go when they do.
	task.spawn(function()
		while true do
			task.wait(15)
			for _, p in Players:GetPlayers() do
				for _, attribute in List.Attribute do
					local a = p:GetAttribute(attribute)
					if type(a) == "number" and a <= Boosters.now() then
						Boosters.apply(p)
						break
					end
				end
			end
		end
	end)
end

return Boosters

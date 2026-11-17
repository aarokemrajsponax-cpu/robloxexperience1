--!strict
-- Levels on the server (Shared/Levels has the curve, Config.Levels the XP for each thing). XP is
-- only ever given here, for what the server itself saw happen: a piece put away correctly, a
-- round's grade, a Nightly, a match, an evening in the Ballroom, a find at an event, the first
-- visit of the day. Double XP (the owner's event) and an XP Surge (the Gem Shop) multiply it.
-- A level's rewards are paid once, the first time it's reached. Everyone sees a guest's level
-- (the "Level" attribute, on their nameplate); the guest's own screen also gets how far along.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Analytics = require(script.Parent.Analytics)
local Profiles = require(script.Parent.Profiles)

local Progress = {}

-- Set by Main.
Progress.boost = function(_player: Player): number
	return 1
end
Progress.levelUp = function(_player: Player, _level: number, _gilt: number) end

local function cfg(): { [string]: any }
	return Config.data.Levels :: any
end

local function rec(data: Profiles.Data): { xp: number, best: number, day: number }
	local d = data :: any
	if type(d.level) ~= "table" then
		d.level = { xp = 0, best = 1, day = -1 }
	end
	local L = d.level
	L.xp = if type(L.xp) == "number" then L.xp else 0
	L.best = if type(L.best) == "number" then L.best else 1
	L.day = if type(L.day) == "number" then L.day else -1
	return L
end

-- The guest's level on their character (everyone sees it) and how far along (their own screen).
function Progress.sync(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local level, into, need = Levels.of(rec(data).xp)
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelXP", into)
	player:SetAttribute("LevelNeed", need)
end

function Progress.level(data: Profiles.Data): number
	return (Levels.of(rec(data).xp))
end

-- Gives XP (after the boosts); returns what was given.
function Progress.add(player: Player, amount: number, reason: string): number
	local data = Profiles.get(player)
	if not data or type(amount) ~= "number" or amount <= 0 then
		return 0
	end
	local L = rec(data)
	local gained = math.floor(amount * math.max(1, Progress.boost(player)) + 0.5)
	L.xp += gained
	local now = Levels.of(L.xp)
	if now > L.best then
		local from = L.best
		L.best = now
		for level = from + 1, now do
			Progress.levelUp(player, level, Levels.reward(level))
			Analytics.custom(player, "Level", level, { reason = reason })
		end
	end
	Progress.sync(player)
	return gained
end

-- XP for a thing that happened (a key of Config.Levels).
function Progress.give(player: Player, what: string, grade: string?): number
	local c = cfg()
	local amount = c[what]
	if what == "round" and type(amount) == "table" then
		amount = amount[grade or ""] or amount.Cleared
	end
	if type(amount) ~= "number" then
		return 0
	end
	return Progress.add(player, amount, what)
end

-- (Build 88) XP for what a guest does all over the house, from the same counts the badges keep
-- (each one the server saw happen: a haul banked, a checkpoint reached, the Executive beaten, a
-- race finished, a pearl found). Config.Levels.stats gives the XP for each; Config.Levels.daily
-- Cap is the most any one of them gives in a day, so nothing done over and over levels anyone
-- up (repeating it still counts for its badge). Nothing bought is ever on the list.
local function today(data: Profiles.Data): { [string]: number }
	local L = rec(data) :: any
	local day = os.time() // 86400
	if type(L.today) ~= "table" or L.today.day ~= day then
		L.today = { day = day, by = {} }
	end
	if type(L.today.by) ~= "table" then
		L.today.by = {}
	end
	return L.today.by
end

function Progress.forStat(player: Player, stat: string, n: number): number
	local c = cfg()
	local each = type(c.stats) == "table" and tonumber((c.stats :: any)[stat]) or nil
	if not each or each <= 0 or type(n) ~= "number" or n <= 0 then
		return 0
	end
	local data = Profiles.get(player)
	if not data then
		return 0
	end
	local by = today(data)
	local cap = tonumber(c.dailyCap) or 1500
	local room = cap - (by[stat] or 0)
	if room <= 0 then
		return 0
	end
	local amount = math.min(room, math.floor(each * math.min(n, 1000) + 0.5))
	if amount <= 0 then
		return 0
	end
	by[stat] = (by[stat] or 0) + amount
	return Progress.add(player, amount, stat)
end

-- The first visit of the day: a little XP for coming back.
function Progress.daily(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local L = rec(data)
	local today = os.time() // 86400
	if L.day ~= today then
		L.day = today
		Progress.give(player, "daily")
	else
		Progress.sync(player)
	end
end

return Progress

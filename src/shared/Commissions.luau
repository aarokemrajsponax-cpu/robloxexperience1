--!strict
-- The Evening Commission and the Week's Commission (§11): one gentle optional goal a day and a
-- bigger one a week, the same for everyone, chosen by the date. Missing either costs nothing.

local Catalogue = require(script.Parent.Catalogue)
local Config = require(script.Parent.Config)
local Seed = require(script.Parent.Seed)

local Commissions = {}

export type Kind = "file" | "rounds" | "flawless" | "nightly" | "library" | "ballroom"
export type Goal = { id: string, kind: Kind, room: string?, case: string?, target: number, text: string }

local ROOMS = { salon = "the Salon", velvet = "the Velvet Room", obsidian = "the Obsidian Room" }
local ROOM_IDS = { "salon", "velvet", "obsidian" }

local function caseName(caseId: string): string
	for _, c in Catalogue.Cases do
		if c.id == caseId then
			return string.lower(c.name)
		end
	end
	return caseId
end

local WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve" }
local function words(n: number): string
	return WORDS[n] or tostring(n)
end

local function goal(key: string, big: boolean): Goal
	local rng = Random.new(Seed.hash(key))
	local kinds: { Kind } = if big then { "file", "rounds", "library", "ballroom", "nightly" } else { "file", "file", "rounds", "flawless", "nightly" }
	local kind = kinds[rng:NextInteger(1, #kinds)]
	local room = ROOM_IDS[rng:NextInteger(1, #ROOM_IDS)]
	local case = Catalogue.Cases[rng:NextInteger(1, 4)].id -- the first four cases open from round I
	if kind == "file" then
		local n = if big then 60 else 12
		return { id = key, kind = kind, room = room, case = case, target = n, text = string.format("File %s pieces of %s in %s", if big then tostring(n) else words(n), caseName(case), ROOMS[room]) }
	elseif kind == "rounds" then
		local n = if big then 15 else 3
		return { id = key, kind = kind, room = room, target = n, text = string.format("Clear %s rounds in %s", if big then tostring(n) else words(n), ROOMS[room]) }
	elseif kind == "flawless" then
		return { id = key, kind = kind, target = 1, text = "Clear a round without a single mistake" }
	elseif kind == "nightly" then
		local n = if big then 4 else 1
		return { id = key, kind = kind, target = n, text = if big then "Sit tonight's table on four nights this week" else "Sit tonight's table" }
	elseif kind == "library" then
		return { id = key, kind = kind, target = 5, text = "Play five evenings of Tête-à-Tête in the Library" }
	end
	return { id = key, kind = "ballroom", target = 3, text = "Sit three Lights Out evenings in the Ballroom" }
end

function Commissions.day(time: number?): number
	return math.floor((time or os.time()) / 86400)
end

function Commissions.week(time: number?): number
	return math.floor((Commissions.day(time) + 3) / 7)
end

function Commissions.evening(time: number?): Goal
	return goal("evening-" .. Commissions.day(time), false)
end

function Commissions.weekly(time: number?): Goal
	return goal("week-" .. Commissions.week(time), true)
end

-- How much an event moves a goal: the event's kind and where it happened.
function Commissions.progress(g: Goal, kind: Kind, room: string?, case: string?): number
	if g.kind ~= kind then
		return 0
	end
	if g.room and g.room ~= room then
		return 0
	end
	if g.case and g.case ~= case then
		return 0
	end
	return 1
end

function Commissions.reward(big: boolean): number
	return if big then Config.data.Commissions.weekGilt else Config.data.Commissions.eveningGilt
end

return Commissions

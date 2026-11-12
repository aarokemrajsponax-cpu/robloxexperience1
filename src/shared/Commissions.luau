--!strict
-- The objectives: the Evening Commission, the Week's Commission and the Season's (a quarter of the
-- year), each the same for everyone, chosen by the date on the server's clock. Most are about the
-- house's fortune now: hauls banked in Steal a Luxe, the Maison Basement's Treasury, the Executive
-- beaten, Stride trained, the Grand Prix's races, the Grand Ballroom's trivia, Runway and Arena;
-- some still at the Salon's tables. Missing any costs nothing.

local Catalogue = require(script.Parent.Catalogue)
local Config = require(script.Parent.Config)
local Seed = require(script.Parent.Seed)

local Commissions = {}

export type Kind = "file" | "rounds" | "flawless" | "nightly" | "library" | "ballroom" | "luxeBank" | "luxeWorth" | "stride" | "basementClear" | "executiveWin" | "race" | "raceWin" | "trivia" | "runway" | "arena" | "luxeJob" | "luxeEscape"
export type Goal = { id: string, kind: Kind, room: string?, case: string?, target: number, text: string }

local ROOMS = { salon = "the Salon" }
local ROOM_IDS = { "salon" }

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

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

-- (How big each goal is: an evening's, a week's, a season's.)
type Size = "evening" | "week" | "season"

local function goal(key: string, size: Size): Goal
	local rng = Random.new(Seed.hash(key))
	-- (The Grand Prix's races and the Grand Ballroom's activities too: everyone can reach them.)
	local kinds: { Kind } = if size == "season"
		then { "luxeWorth", "basementClear", "executiveWin", "luxeBank", "raceWin" }
		elseif size == "week" then { "luxeBank", "luxeWorth", "basementClear", "executiveWin", "file", "rounds", "library", "ballroom", "nightly", "race", "raceWin", "trivia", "runway", "arena", "luxeJob", "luxeEscape" }
		else { "luxeBank", "luxeWorth", "basementClear", "stride", "file", "rounds", "flawless", "nightly", "race", "trivia", "arena", "luxeJob" }
	local kind = kinds[rng:NextInteger(1, #kinds)]
	local room = ROOM_IDS[rng:NextInteger(1, #ROOM_IDS)]
	local case = Catalogue.Cases[rng:NextInteger(1, 4)].id -- the first four cases open from round I
	local big = size ~= "evening"
	if kind == "luxeBank" then
		local n = if size == "season" then 60 elseif big then 12 else 2
		return { id = key, kind = kind, target = n, text = string.format("Bank %s hauls in Steal a Luxe", if n <= 12 then words(n) else tostring(n)) }
	elseif kind == "luxeWorth" then
		local n = if size == "season" then 500000 elseif big then 60000 else 5000
		return { id = key, kind = kind, target = n, text = string.format("Bank %s in Steal a Luxe", commas(n)) }
	elseif kind == "luxeJob" then
		-- (Build 78: the run's side jobs.)
		local n = if big then 8 else 2
		return { id = key, kind = kind, target = n, text = string.format("Finish %s side jobs in Steal a Luxe", words(n)) }
	elseif kind == "luxeEscape" then
		local n = if big then 3 else 1
		return { id = key, kind = kind, target = n, text = if n == 1 then "Get away from Steal a Luxe by the van or the helicopter" else string.format("Get away from Steal a Luxe by the van or the helicopter %s times", words(n)) }
	elseif kind == "stride" then
		return { id = key, kind = kind, target = 2, text = "Train two levels of Stride on the Luxe Lounge's treadmills" }
	elseif kind == "basementClear" then
		local n = if size == "season" then 15 elseif big then 3 else 1
		return { id = key, kind = kind, target = n, text = if n == 1 then "Reach the Treasury at the foot of the Maison Basement" else string.format("Reach the Maison Basement's Treasury %s times", words(n)) }
	elseif kind == "executiveWin" then
		local n = if size == "season" then 5 else 1
		return { id = key, kind = kind, target = n, text = if n == 1 then "Beat the Executive in the Executive Suite" else string.format("Beat the Executive %s times", words(n)) }
	elseif kind == "file" then
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
	elseif kind == "race" then
		local n = if big then 10 else 2
		return { id = key, kind = kind, target = n, text = if big then "Finish ten Grand Prix races" else "Finish two Grand Prix races" }
	elseif kind == "raceWin" then
		local n = if size == "season" then 12 else 2
		return { id = key, kind = kind, target = n, text = if size == "season" then "Win twelve Grand Prix races" else "Win two Grand Prix races" }
	elseif kind == "trivia" then
		local n = if big then 8 else 2
		return { id = key, kind = kind, target = n, text = string.format("Play %s rounds of Luxury Trivia in the Grand Ballroom", words(n)) }
	elseif kind == "runway" then
		return { id = key, kind = kind, target = 3, text = "Walk in three shows on the Grand Ballroom's Runway" }
	elseif kind == "arena" then
		local n = if big then 6 else 2
		return { id = key, kind = kind, target = n, text = string.format("Take part in %s rounds of the Daily Arena", words(n)) }
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
	return goal("evening-" .. Commissions.day(time), "evening")
end

function Commissions.weekly(time: number?): Goal
	return goal("week-" .. Commissions.week(time), "week")
end

-- The season: a quarter of the year (UTC), and its goal.
function Commissions.season(time: number?): string
	local d = os.date("!*t", time or os.time()) :: any
	return string.format("%d-Q%d", d.year, (d.month - 1) // 3 + 1)
end

function Commissions.seasonal(time: number?): Goal
	return goal("season-" .. Commissions.season(time), "season")
end

-- How much an event moves a goal: the event's kind and where it happened (and, for an amount, how
-- much: the worth of a haul, levels of Stride).
function Commissions.progress(g: Goal, kind: Kind, room: string?, case: string?, amount: number?): number
	if g.kind ~= kind then
		return 0
	end
	if g.room and g.room ~= room then
		return 0
	end
	if g.case and g.case ~= case then
		return 0
	end
	return math.max(1, math.floor(amount or 1))
end

function Commissions.reward(big: boolean, season: boolean?): number
	local c = Config.data.Commissions
	if season then
		return tonumber((c :: any).seasonGilt) or 5000
	end
	return if big then c.weekGilt else c.eveningGilt
end

return Commissions

--!strict
-- Lights Out rules (§9.3, Appendix H3): the dumbwaiter's pace, the lookalikes, the sixth case,
-- parcels with the Key bonus, where a parcel goes by tab, and the evening's points. Pure rules;
-- the Ballroom service runs the evening.

local Config = require(script.Parent.Config)
local Rooms = require(script.Parent.Rooms)

local LightsOut = {}

local function cfg()
	return Config.data.Ballroom
end

-- Seconds between arrivals `t` seconds into the evening: steady, then faster, then Closing Time.
function LightsOut.pace(t: number): number
	local c = cfg()
	local steps = math.floor(math.max(0, t) / c.paceEvery)
	local pace = math.max(c.paceMin, c.paceStart - steps * c.paceStep)
	if t >= c.closingAt then
		local closing = math.floor((t - c.closingAt) / c.closingEvery) + 1
		pace = math.max(c.closingMin, math.min(pace, c.paceMin) - closing * c.closingStep)
	end
	return pace
end

function LightsOut.isClosingTime(t: number): boolean
	return t >= cfg().closingAt
end

function LightsOut.lookalike(t: number): number
	local c = cfg()
	local steps = math.floor(math.max(0, t) / c.lookalikeEvery)
	return math.min(c.lookalikeMax, c.lookalikeStart + steps * c.lookalikeStep)
end

function LightsOut.casesOpen(t: number): number
	return if t >= cfg().sixthCaseAt then 6 else cfg().casesOpen
end

-- The extra share of parcels that Keys bring: 2 Keys +25%, 4 +50%, 8 +75%, 16 +100%.
function LightsOut.keyBonus(keys: number): number
	local bonus = 0
	for _, step in cfg().keyBonus do
		if keys >= step[1] then
			bonus = step[2]
		end
	end
	return bonus
end

-- Parcels a correct filing sends: as the Library (a same-case run of 3 or more, at most 4 per
-- run, and streaks of 6, 10 and 15), then multiplied by the Key bonus. Fractions carry over.
-- Returns whole parcels, parcels counted toward the run, and the new carry.
function LightsOut.parcels(runLength: number, runParcels: number, streak: number, keys: number, carry: number): (number, number, number)
	local lib = Config.data.Library
	local fromRun = 0
	if runLength >= lib.parcelRunFrom and runParcels < cfg().parcelRunMax then
		fromRun = 1
	end
	local fromStreak = 0
	if streak == lib.streakParcelAt6 or streak == lib.streakParcelAt10 or streak == lib.streakParcelAt15 then
		fromStreak = 1
	end
	local base = fromRun + fromStreak
	if base == 0 then
		return 0, 0, carry
	end
	local total = base * (1 + LightsOut.keyBonus(keys)) + carry
	local whole = math.floor(total + 1e-9)
	return whole, fromRun, total - whole
end

-- A room-shaped rule set for the dumbwaiter: batches of pieces from the evening's seed.
function LightsOut.room(t: number): Rooms.Room
	local cases = LightsOut.casesOpen(t)
	return {
		id = "ballroom",
		name = "The Ballroom",
		line = "",
		timed = false,
		tuning = {
			firstDeal = 12,
			dealGrowth = 0,
			maxDeal = 12,
			casesRound1 = cases,
			lookalike = LightsOut.lookalike(t),
			clockBase = nil,
			clockPerPiece = nil,
			clockRefund = nil,
			clockPenalty = nil,
			clockStartsOnLift = false,
			guide = "delayed",
			guideDelay = cfg().guideDelay,
			names = true,
			multiplier = 1,
			rareRate = 0.012,
			mythicChance = 0,
			unlock = nil,
		},
	}
end

export type Seat = { index: number, alive: boolean, keys: number, felt: number, lastSender: number? }

-- Where a parcel goes, by the sender's tab. Random · Rivals (whoever last sent to you) · Leader
-- (most Keys) · Nearly out (fullest felt). Never yourself, never a lamp that's out.
function LightsOut.target(tab: string, me: Seat, seats: { Seat }, rng: Random): number?
	local alive: { Seat } = {}
	for _, s in seats do
		if s.alive and s.index ~= me.index then
			table.insert(alive, s)
		end
	end
	if #alive == 0 then
		return nil
	end
	table.sort(alive, function(a, b)
		return a.index < b.index
	end)
	if tab == "rivals" and me.lastSender then
		for _, s in alive do
			if s.index == me.lastSender then
				return s.index
			end
		end
	elseif tab == "leader" or tab == "nearlyOut" then
		local best: { Seat } = {}
		local bestValue = -math.huge
		for _, s in alive do
			local value = if tab == "leader" then s.keys else s.felt
			if value > bestValue then
				best, bestValue = { s }, value
			elseif value == bestValue then
				table.insert(best, s)
			end
		end
		return best[rng:NextInteger(1, #best)].index
	end
	return alive[rng:NextInteger(1, #alive)].index
end

LightsOut.Tabs = { "random", "rivals", "leader", "nearlyOut" }
LightsOut.TabNames = { random = "Random", rivals = "Rivals", leader = "Leader", nearlyOut = "Nearly out" }

-- Soirée and weekly-board points for a place (1 = the last lamp), plus 8 per Key.
function LightsOut.points(place: number, keys: number): number
	local list = cfg().points
	return (list[place] or 0) + keys * cfg().pointsPerKey
end

return LightsOut

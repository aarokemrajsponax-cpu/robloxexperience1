--!strict
-- Tête-à-Tête rules (§9.2, Appendix H2): identical deals per hand, parcels as the attack,
-- lookalikes on the receiver's felt, and how a capped hand is decided.

local Catalogue = require(script.Parent.Catalogue)
local Config = require(script.Parent.Config)
local Rooms = require(script.Parent.Rooms)

local Duel = {}

export type HandSpec = { pieces: number, cases: number, lookalike: number }

function Duel.hand(hand: number): HandSpec
	local c = Config.data.Library
	local i = math.clamp(hand, 1, #c.pieces)
	return { pieces = c.pieces[i], cases = c.cases[i], lookalike = c.lookalike[i] }
end

-- A room-shaped rule set for the deal generator: one round of exactly this hand's size.
function Duel.room(hand: number): Rooms.Room
	local spec = Duel.hand(hand)
	return {
		id = "library",
		name = "The Library",
		line = "",
		timed = false,
		tuning = {
			firstDeal = spec.pieces,
			dealGrowth = 0,
			maxDeal = spec.pieces,
			casesRound1 = spec.cases,
			lookalike = spec.lookalike,
			clockBase = nil,
			clockPerPiece = nil,
			clockRefund = nil,
			clockPenalty = nil,
			clockStartsOnLift = false,
			guide = "delayed",
			guideDelay = Config.data.Library.guideDelay,
			names = true,
			multiplier = 1,
			rareRate = 0.012,
			mythicChance = 0,
			unlock = nil,
		},
	}
end

-- Parcels a correct filing sends: one per filing that makes a same-case run of 3 or longer
-- (at most 3 per run), plus one when the streak reaches 6, 10 and 15.
function Duel.parcels(runLength: number, runParcelsSoFar: number, streak: number): (number, number)
	local c = Config.data.Library
	local fromRun = 0
	if runLength >= c.parcelRunFrom and runParcelsSoFar < c.parcelRunMax then
		fromRun = 1
	end
	local fromStreak = 0
	if streak == c.streakParcelAt6 or streak == c.streakParcelAt10 or streak == c.streakParcelAt15 then
		fromStreak = 1
	end
	return fromRun, fromStreak
end

-- Lookalike pieces for a parcel, drawn from the receiver's open cases.
function Duel.lookalikes(openCases: { string }, count: number, rng: Random): { string }
	local open: { [string]: boolean } = {}
	for _, c in openCases do
		open[c] = true
	end
	local pool: { string } = {}
	for _, cluster in Catalogue.Clusters do
		local members = {}
		for _, id in cluster do
			local p = Catalogue.byId[id]
			if p and open[p.case] then
				table.insert(members, id)
			end
		end
		if #members >= 2 then
			for _, id in members do
				table.insert(pool, id)
			end
		end
	end
	if #pool == 0 then
		for _, p in Catalogue.Core do
			if open[p.case] then
				table.insert(pool, p.id)
			end
		end
	end
	local out = {}
	for i = 1, count do
		out[i] = pool[rng:NextInteger(1, #pool)]
	end
	return out
end

export type SideResult = { remaining: number, accuracy: number, lastFilingAt: number }

-- A hand that hits the cap: fewer pieces left wins, then higher accuracy, then earlier last filing.
function Duel.capWinner(a: SideResult, b: SideResult): "a" | "b"
	if a.remaining ~= b.remaining then
		return if a.remaining < b.remaining then "a" else "b"
	end
	if math.abs(a.accuracy - b.accuracy) > 1e-9 then
		return if a.accuracy > b.accuracy then "a" else "b"
	end
	return if a.lastFilingAt <= b.lastFilingAt then "a" else "b"
end

-- How a Stand-in fitted to a rating plays: seconds per filing and chance of the right case.
function Duel.standInPace(rating: number): (number, number)
	local c = Config.data.Library
	local t = math.clamp((rating - 1000) / 1100, 0, 1)
	local seconds = c.standInSlowSeconds + (c.standInFastSeconds - c.standInSlowSeconds) * t
	local accuracy = c.standInLowAccuracy + (c.standInHighAccuracy - c.standInLowAccuracy) * t
	return seconds, accuracy
end

return Duel

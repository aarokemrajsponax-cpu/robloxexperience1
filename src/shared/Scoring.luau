--!strict
-- Scoring and grades (Appendix E). Pure functions; the server is the only one whose answer counts.

local Config = require(script.Parent.Config)

local Scoring = {}

export type Grade = "Flawless" | "Immaculate" | "Polished" | "Steady" | "Cleared"

export type PieceLike = { value: number, rare: boolean, seasonal: boolean, mythic: boolean }

function Scoring.multiplier(streak: number): number
	local s = Config.data.Scoring
	return math.min(1 + math.floor(streak / s.streakPerStep), s.maxMultiplier)
end

-- Points for one correct filing. `streak` is the streak after this filing counts.
function Scoring.filingPoints(piece: PieceLike, streak: number, roomMultiplier: number): number
	local s = Config.data.Scoring
	local base: number
	if piece.mythic then
		base = s.mythicValue * s.rareFactor
	else
		base = piece.value
		if piece.rare then
			base *= s.rareFactor
		end
		if piece.seasonal then
			base *= s.seasonalFactor
		end
	end
	return math.round(base * Scoring.multiplier(streak) * roomMultiplier)
end

-- From the third consecutive filing into the same case, each one pays extra.
function Scoring.setBonus(runLength: number): number
	local s = Config.data.Scoring
	if runLength < s.setBonusFrom then
		return 0
	end
	return math.min(runLength, s.setBonusCap) * s.setBonusPer
end

-- The Costs-points-too setting. Never applies in the Nightly.
function Scoring.wrongPenalty(round: number): number
	local s = Config.data.Scoring
	return s.wrongBase + round * s.wrongPerRound
end

export type RoundBonus = { perfect: number, streak: number, time: number, total: number }

function Scoring.roundEnd(round: number, mistakes: number, bestStreak: number, secondsLeft: number?, roomMultiplier: number): RoundBonus
	local s = Config.data.Scoring
	local perfect = if mistakes == 0 then math.round((s.perfectBase + round * s.perfectPerRound) * roomMultiplier) else 0
	local streak = math.round(bestStreak * s.bestStreakPer * roomMultiplier)
	local time = if secondsLeft ~= nil then math.round(math.max(0, secondsLeft) * s.secondsLeftPer * roomMultiplier) else 0
	return { perfect = perfect, streak = streak, time = time, total = perfect + streak + time }
end

function Scoring.gradeLabel(points: number): Grade
	local g = Config.data.Grades
	if points >= g.Flawless then
		return "Flawless"
	elseif points >= g.Immaculate then
		return "Immaculate"
	elseif points >= g.Polished then
		return "Polished"
	elseif points >= g.Steady then
		return "Steady"
	end
	return "Cleared"
end

-- accuracy in 0..1; clockFraction in 0..1 for timed rooms, nil otherwise.
function Scoring.grade(accuracy: number, bestStreak: number, piecesDealt: number, clockFraction: number?): (number, Grade)
	local s = Config.data.Scoring
	local acc = math.clamp(accuracy, 0, 1) ^ s.gradePower
	local streakPart = math.min(1, bestStreak / math.max(1, piecesDealt)) * 20
	local third = if clockFraction ~= nil then math.min(1, math.max(0, clockFraction)) * 20 else acc * 20
	local points = acc * 60 + streakPart + third
	return points, Scoring.gradeLabel(points)
end

-- The whole run: run accuracy, best streak over max(6, pieces sorted), and the untimed branch.
function Scoring.runGrade(accuracy: number, bestStreak: number, piecesSorted: number): (number, Grade)
	local s = Config.data.Scoring
	return Scoring.grade(accuracy, bestStreak, math.max(s.runStreakFloor, piecesSorted), nil)
end

function Scoring.giltForRun(points: number): number
	local g = Config.data.Gilt
	return math.min(math.floor(points / g.runDivisor), g.runMax)
end

return Scoring

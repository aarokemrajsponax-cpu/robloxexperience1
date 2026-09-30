--!strict
-- The arithmetic of the music (§14): how full a room's music is as the run builds, and which of
-- the Ballroom band is still playing as the lamps go out. Pure, so the rule tests can check it.

local Config = require(script.Parent.Config)

local Music = {}

-- Sparse in round I, fuller each round: min(1, 0.25 + round × 0.12).
function Music.intensity(round: number): number
	local c = Config.data.Music
	return math.clamp(c.intensityBase + math.max(0, round) * c.intensityPerRound, 0, 1)
end

export type Band = "full" | "bass" | "piano"

-- The whole band at twenty, bass and brushes at ten, a single piano and a ticking clock for the
-- final two.
function Music.band(lit: number): Band
	local c = Config.data.Music
	if lit <= c.bandPianoAt then
		return "piano"
	elseif lit <= c.bandBassAt then
		return "bass"
	end
	return "full"
end

-- The stems that sound for a band, each with its share of the volume.
function Music.stems(band: string): { [string]: number }
	if band == "piano" then
		return { piano = 1, clock = 0.6 }
	elseif band == "bass" then
		return { bass = 1 }
	end
	return { full = 1 }
end

return Music

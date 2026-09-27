--!strict
-- Seeds. Every deal comes from one, so any run can be replayed exactly.

local Seed = {}

-- FNV-1a, 32-bit. Stable across server and client, and across Roblox releases.
function Seed.hash(text: string): number
	local hash = 2166136261
	for i = 1, #text do
		hash = bit32.bxor(hash, string.byte(text, i))
		hash = (hash * 16777619) % 4294967296
	end
	return hash
end

-- The Nightly's seed is the UTC date, identical everywhere.
function Seed.nightly(year: number, month: number, day: number): number
	return Seed.hash(string.format("nightly-%04d-%02d-%02d", year, month, day))
end

-- A fresh random seed for the four rooms (server only).
function Seed.fresh(): number
	return Random.new():NextInteger(1, 2 ^ 31 - 1)
end

return Seed

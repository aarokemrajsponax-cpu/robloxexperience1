--!strict
-- The Nightly: one table for everyone on Roblox (§9.1, Appendix H1). The same five rounds, the
-- same pieces in the same order, for every guest, decided by the UTC date.

local Config = require(script.Parent.Config)
local Seed = require(script.Parent.Seed)

local Nightly = {}

local WEEKDAYS = { "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday" }

export type Night = {
	key: string, -- "2026-11-14"
	day: number, -- days since 1 January 1970 (UTC)
	weekday: string,
	room: string,
}

-- The night for a Unix time (default: now), in UTC.
function Nightly.at(time: number?): Night
	local t = time or os.time()
	local d = os.date("!*t", t)
	local weekday = WEEKDAYS[d.wday]
	local room = (Config.data.Nightly :: any)[weekday] or "velvet"
	return {
		key = string.format("%04d-%02d-%02d", d.year, d.month, d.day),
		day = math.floor(t / 86400),
		weekday = weekday,
		room = room,
	}
end

-- Every round's seed comes from the date, so every server deals the same pieces.
function Nightly.seed(key: string, round: number): number
	return Seed.hash(string.format("nightly-%s-r%d", key, round))
end

-- Seconds since the night began (for "ties go to the earlier finish").
function Nightly.secondsInto(time: number?): number
	local t = time or os.time()
	return t % 86400
end

-- Board sort key: score first, then the earlier finish.
function Nightly.sortKey(score: number, finishedAt: number): number
	return math.floor(score) * 100000 + (86400 - Nightly.secondsInto(finishedAt))
end

function Nightly.scoreFromSortKey(sortKey: number): number
	return math.floor(sortKey / 100000)
end

return Nightly

--!strict
-- The Maison's live calendar: the holidays the house keeps, when each falls in any year, and what
-- day and hour it is in the house's reference time zone (Config.LiveOps.timezone, daylight saving
-- included), so a holiday begins at midnight there, everywhere at once, and never twice.
--
--   Fixed days         New Year's Day, Valentine's Day, St Patrick's, All Hallows', Christmas
--   Rules              Easter (the Gregorian computus), Thanksgiving (the fourth Thursday of
--                      November)
--   Published tables   Lunar New Year, Diwali, Hanukkah, Eid al-Fitr: from published calendars
--                      for the years listed (they can differ by a day where the moon is sighted
--                      locally; the owner can start or end any of them early from Live Operations)
--
-- A holiday has a region ("global" or a country's): the house keeps those in Config.LiveOps.regions.
-- The holiday games (shared/HolidayGames) keep their own windows; this calendar shows them too.

local Config = require(script.Parent.Config)
local HolidayGames = require(script.Parent.HolidayGames)
local HouseEvents = require(script.Parent.HouseEvents)

local LiveCalendar = {}

export type Holiday = {
	id: string,
	name: string,
	glyph: string,
	region: string,
	lead: number, -- days before its day it begins
	linger: number, -- days after its day it lasts
	game: string?, -- its holiday game (shared/HolidayGames), if it has one
	line: string,
}

LiveCalendar.Holidays = {
	{ id = "newYear", name = "New Year's", glyph = "🎆", region = "global", lead = 1, linger = 1, line = "Fireworks over the Maison, and a new year of fortunes." },
	{ id = "lunarNewYear", name = "Lunar New Year", glyph = "🧧", region = "global", lead = 1, linger = 6, line = "Red and gold through the house for the new year." },
	{ id = "valentines", name = "Valentine's Day", glyph = "💝", region = "global", lead = 1, linger = 0, line = "Roses in the Foyer, and a little romance at the Terrace bar." },
	{ id = "stPatrick", name = "St Patrick's Day", glyph = "☘️", region = "global", lead = 3, linger = 1, game = "stPatrick", line = "The luck of the Irish: rarer finds at the tables." },
	{ id = "eidAlFitr", name = "Eid al-Fitr", glyph = "🌙", region = "global", lead = 0, linger = 2, line = "Lanterns along the Grand Stair for Eid." },
	{ id = "easter", name = "Easter", glyph = "🥚", region = "global", lead = 2, linger = 1, game = "easter", line = "The Great Egg Hunt, all through the house." },
	{ id = "halloween", name = "All Hallows'", glyph = "🎃", region = "global", lead = 7, linger = 1, game = "halloween", line = "Trick or treat on Hallows Lane." },
	{ id = "diwali", name = "Diwali", glyph = "🕯️", region = "global", lead = 1, linger = 1, line = "The house lit with a thousand lamps for Diwali." },
	{ id = "thanksgiving", name = "Thanksgiving", glyph = "🦃", region = "US", lead = 3, linger = 3, game = "thanksgiving", line = "The Turkey Round-Up in the Harvest Field." },
	{ id = "hanukkah", name = "Hanukkah", glyph = "🕎", region = "global", lead = 0, linger = 7, line = "Candles in the windows, eight nights of light." },
	{ id = "christmas", name = "Christmas", glyph = "🎄", region = "global", lead = 7, linger = 4, game = "christmas", line = "Santa's sleigh waits at the kerb." },
} :: { Holiday }

LiveCalendar.byId = {} :: { [string]: Holiday }
for _, h in LiveCalendar.Holidays do
	LiveCalendar.byId[h.id] = h
end

-- Published dates (month, day) for the holidays that follow the moon, by year.
local TABLES: { [string]: { [number]: { number } } } = {
	lunarNewYear = { [2026] = { 2, 17 }, [2027] = { 2, 6 }, [2028] = { 1, 26 }, [2029] = { 2, 13 }, [2030] = { 2, 3 } },
	diwali = { [2026] = { 11, 8 }, [2027] = { 10, 29 }, [2028] = { 10, 17 }, [2029] = { 11, 5 }, [2030] = { 10, 26 } },
	hanukkah = { [2026] = { 12, 5 }, [2027] = { 12, 25 }, [2028] = { 12, 13 }, [2029] = { 12, 2 }, [2030] = { 12, 21 } },
	eidAlFitr = { [2026] = { 3, 20 }, [2027] = { 3, 10 }, [2028] = { 2, 27 }, [2029] = { 2, 15 }, [2030] = { 2, 5 } },
}

-- A holiday's day in a year (month, day), or nil when the year isn't in its table.
function LiveCalendar.dayOf(id: string, year: number): (number?, number?)
	local h = LiveCalendar.byId[id]
	if not h then
		return nil, nil
	end
	if h.game then
		return HolidayGames.dayOf(h.game, year)
	end
	if id == "newYear" then
		return 1, 1
	elseif id == "valentines" then
		return 2, 14
	end
	local t = TABLES[id]
	local d = t and t[year]
	if d then
		return d[1], d[2]
	end
	return nil, nil
end

---------------------------------------------------------------------------------------------------
-- The reference time zone (with daylight saving)
---------------------------------------------------------------------------------------------------
local DAY = 86400

-- The nth (1-5, or -1 for the last) given weekday (0 Sunday .. 6 Saturday) of a month: its day.
local function nthWeekday(year: number, month: number, weekday: number, n: number): number
	if n > 0 then
		local first = HouseEvents.weekday(year, month, 1)
		return 1 + (weekday - first) % 7 + (n - 1) * 7
	end
	local daysIn = HolidayGames.dayNumber(if month == 12 then year + 1 else year, if month == 12 then 1 else month + 1, 1) - HolidayGames.dayNumber(year, month, 1)
	local last = HouseEvents.weekday(year, month, daysIn)
	return daysIn - (last - weekday) % 7
end

local function at(year: number, month: number, day: number, hourUtc: number): number
	return HolidayGames.dayNumber(year, month, day) * DAY + hourUtc * 3600
end

-- The zones the house knows: standard offset (hours), and when daylight saving runs (UTC instants).
type Zone = { offset: number, dst: ((year: number) -> (number, number))? }
local ZONES: { [string]: Zone } = {
	UTC = { offset = 0 },
	["America/New_York"] = { offset = -5, dst = function(y)
		return at(y, 3, nthWeekday(y, 3, 0, 2), 7), at(y, 11, nthWeekday(y, 11, 0, 1), 6)
	end },
	["America/Chicago"] = { offset = -6, dst = function(y)
		return at(y, 3, nthWeekday(y, 3, 0, 2), 8), at(y, 11, nthWeekday(y, 11, 0, 1), 7)
	end },
	["America/Los_Angeles"] = { offset = -8, dst = function(y)
		return at(y, 3, nthWeekday(y, 3, 0, 2), 10), at(y, 11, nthWeekday(y, 11, 0, 1), 9)
	end },
	["Europe/London"] = { offset = 0, dst = function(y)
		return at(y, 3, nthWeekday(y, 3, 0, -1), 1), at(y, 10, nthWeekday(y, 10, 0, -1), 1)
	end },
	["Europe/Paris"] = { offset = 1, dst = function(y)
		return at(y, 3, nthWeekday(y, 3, 0, -1), 1), at(y, 10, nthWeekday(y, 10, 0, -1), 1)
	end },
	["Asia/Tokyo"] = { offset = 9 },
	["Australia/Sydney"] = { offset = 10, dst = function(y)
		-- (The south's summer: from the first Sunday of October to the first Sunday of April.)
		return at(y, 10, nthWeekday(y, 10, 0, 1), -8), at(y, 4, nthWeekday(y, 4, 0, 1), -8)
	end },
}
LiveCalendar.ZONES = ZONES

function LiveCalendar.zone(): string
	local z = (Config.data :: any).LiveOps and (Config.data :: any).LiveOps.timezone
	return if type(z) == "string" and ZONES[z] then z else "UTC"
end

-- The reference zone's offset from UTC at an instant (seconds), daylight saving included.
function LiveCalendar.offset(utc: number, zoneName: string?): number
	local z = ZONES[zoneName or LiveCalendar.zone()] or ZONES.UTC
	local hours = z.offset
	if z.dst then
		local y = (os.date("!*t", utc) :: any).year
		local from, to = z.dst(y)
		local inDst = if from < to then (utc >= from and utc < to) else (utc >= from or utc < to)
		if inDst then
			hours += 1
		end
	end
	return hours * 3600
end

-- The date and time in the reference zone at an instant.
function LiveCalendar.localDate(utc: number, zoneName: string?): { year: number, month: number, day: number, hour: number, min: number, wday: number }
	return os.date("!*t", utc + LiveCalendar.offset(utc, zoneName)) :: any
end

---------------------------------------------------------------------------------------------------
-- What's on
---------------------------------------------------------------------------------------------------
local function regions(): { [string]: boolean }
	local out: { [string]: boolean } = { global = true }
	local list = (Config.data :: any).LiveOps and (Config.data :: any).LiveOps.regions
	if type(list) == "table" then
		for _, r in list do
			out[tostring(r)] = true
		end
	end
	return out
end

export type Window = { id: string, name: string, glyph: string, line: string, game: string?, starts: number, ends: number, day: number }

-- A holiday's window in a year, as UTC instants (from midnight in the reference zone on its first
-- day to midnight after its last), or nil.
function LiveCalendar.window(id: string, year: number, zoneName: string?): Window?
	local h = LiveCalendar.byId[id]
	local m, d = LiveCalendar.dayOf(id, year)
	if not h or not m or not d then
		return nil
	end
	local dayNum = HolidayGames.dayNumber(year, m, d)
	local startLocal = (dayNum - h.lead) * DAY
	local endLocal = (dayNum + h.linger + 1) * DAY
	-- (Local midnight to UTC: the offset at about that time.)
	local starts = startLocal - LiveCalendar.offset(startLocal, zoneName)
	local ends = endLocal - LiveCalendar.offset(endLocal, zoneName)
	return { id = h.id, name = h.name, glyph = h.glyph, line = h.line, game = h.game, starts = starts, ends = ends, day = dayNum }
end

-- Every window that's on or coming within `days`, soonest first (the house's regions only).
function LiveCalendar.upcoming(now: number, days: number, zoneName: string?): { Window }
	local keep = regions()
	local year = (os.date("!*t", now) :: any).year
	local out: { Window } = {}
	for _, h in LiveCalendar.Holidays do
		if keep[h.region] then
			for _, y in { year - 1, year, year + 1 } do
				local w = LiveCalendar.window(h.id, y, zoneName)
				if w and w.ends > now and w.starts < now + days * DAY then
					table.insert(out, w)
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.starts < b.starts
	end)
	return out
end

-- The holiday on now (the one that began most recently, when two overlap), or nil.
function LiveCalendar.active(now: number, zoneName: string?): Window?
	local best: Window? = nil
	for _, w in LiveCalendar.upcoming(now, 0.0001, zoneName) do
		if w.starts <= now and (not best or w.starts > (best :: Window).starts) then
			best = w
		end
	end
	return best
end

return LiveCalendar

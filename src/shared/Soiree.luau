--!strict
-- The Soirée (§9.5, Appendix H5): every weekend, Saturday 00:00 UTC to Monday 00:00 UTC,
-- alternating Ballroom weekends and Library weekends. Your best results count. The top 1% earn
-- the Soirée Medal (dated, wearable, never sold); the top 10% a dated invitation card in the
-- Register; three plays earn the Soirée's stamp. Holiday windows re-dress it and date the medal.

local Config = require(script.Parent.Config)
local Seasons = require(script.Parent.Seasons)

local Soiree = {}

export type Weekend = {
	key: string,
	format: "ballroom" | "library",
	active: boolean,
	startsAt: number,
	endsAt: number,
	name: string,
}

local HOLIDAYS = { hallows = true, toast = true, rose = true, emerald = true }

-- The weekend that is on now, or the next one.
function Soiree.at(time: number?): Weekend
	local now = time or os.time()
	local day = math.floor(now / 86400)
	-- Unix day 0 was a Thursday; Saturday is day 2 of that week.
	local weekday = (day + 4) % 7 -- 0 = Sunday ... 6 = Saturday
	local saturday: number
	if weekday == 6 then
		saturday = day
	elseif weekday == 0 then
		saturday = day - 1
	else
		saturday = day + (6 - weekday)
	end
	local startsAt = saturday * 86400
	local endsAt = startsAt + 2 * 86400
	local week = math.floor((saturday + 3) / 7)
	local format: "ballroom" | "library" = if week % 2 == 0 then "ballroom" else "library"
	local d = os.date("!*t", startsAt)
	local season = Seasons.forDate(d.month, d.day)
	local name = if HOLIDAYS[season.id] then "The " .. season.name .. " Soirée" else "The Soirée"
	return {
		key = string.format("%04d-%02d-%02d", d.year, d.month, d.day),
		format = format,
		active = now >= startsAt and now < endsAt,
		startsAt = startsAt,
		endsAt = endsAt,
		name = name,
	}
end

-- Points for one result: a Ballroom place (+ Keys), or a Library win or loss.
function Soiree.points(format: string, result: { place: number?, keys: number?, won: boolean? }): number
	local c = Config.data.Soiree
	if format == "ballroom" then
		local place = result.place or 20
		return (Config.data.Ballroom.points[place] or 0) + (result.keys or 0) * Config.data.Ballroom.pointsPerKey
	end
	return if result.won then c.libraryWin else c.libraryLoss
end

-- The weekend's score: the best results count (5 evenings, or 15 Library evenings).
function Soiree.score(format: string, results: { number }): number
	local sorted = table.clone(results)
	table.sort(sorted, function(a, b)
		return a > b
	end)
	local keep = if format == "ballroom" then Config.data.Soiree.ballroomBest else Config.data.Soiree.libraryBest
	local total = 0
	for i = 1, math.min(keep, #sorted) do
		total += sorted[i]
	end
	return total
end

-- What a finishing rank earns: "medal" (top 1%), "invitation" (top 10%) or nil.
function Soiree.reward(rank: number, total: number): string?
	if total <= 0 or rank <= 0 then
		return nil
	end
	local fraction = rank / total
	if fraction <= Config.data.Soiree.medalTop then
		return "medal"
	elseif fraction <= Config.data.Soiree.invitationTop then
		return "invitation"
	end
	return nil
end

-- A readable "in 1 day 4 h" / "in 3 h 12 min".
function Soiree.countdown(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local days = s // 86400
	local hours = (s % 86400) // 3600
	local minutes = (s % 3600) // 60
	if days > 0 then
		return string.format("%d day%s %d h", days, if days == 1 then "" else "s", hours)
	elseif hours > 0 then
		return string.format("%d h %d min", hours, minutes)
	end
	return string.format("%d min", math.max(1, minutes))
end

return Soiree

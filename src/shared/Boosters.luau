--!strict
-- (Build 96) Boosters, bought with Gilt in the Boutique: a strong effect for a set time from the
-- moment it's bought. The guest's screen names a booster's id and nothing else: what it does, how
-- long it runs and what it costs come from this list on the server (server/Boosters).
--   gilt:  more Gilt from everything you play (Gilt.pay), the day's soft cap lifted with it;
--   squad: your brainrot squad fills its tip jar faster (server/Brainrots);
--   xp:    more XP from everything you play.
-- One of each kind runs at a time. Buying the same one again while it runs adds its time (up to
-- two hours ahead); a different one of the same kind waits until the first has finished.
-- Boosters never touch a score, the Estate or the Wealthiest boards' ranking: Gilt bought with
-- Robux is still left out of the boards (server/Fortune).

local Boosters = {}

export type Kind = "gilt" | "squad" | "xp"
export type Booster = {
	id: string,
	name: string,
	kind: Kind,
	mult: number,
	seconds: number,
	gilt: number,
	glyph: string,
	line: string,
	colour: Color3,
}

local rgb = Color3.fromRGB

Boosters.CAP = 2 * 3600 -- never more than two hours ahead
-- The shelf says what a Gilt booster would add at the guest's own pace this visit only once
-- they've played this long (a guess from a minute's play would mislead).
Boosters.PACE_MINUTES = 5

Boosters.List = {
	{ id = "rush", name = "Gilt Rush", kind = "gilt", mult = 2, seconds = 15 * 60, gilt = 5000, glyph = "💰", colour = rgb(255, 206, 80), line = "Double Gilt from everything you play, for 15 minutes." },
	{ id = "grand", name = "Grand Rush", kind = "gilt", mult = 3, seconds = 15 * 60, gilt = 15000, glyph = "💎", colour = rgb(150, 220, 255), line = "Three times the Gilt from everything you play, for 15 minutes." },
	{ id = "midas", name = "Midas Hour", kind = "gilt", mult = 3, seconds = 60 * 60, gilt = 45000, glyph = "👑", colour = rgb(255, 170, 40), line = "Three times the Gilt from everything you play, for a whole hour." },
	{ id = "overtime", name = "Squad Overtime", kind = "squad", mult = 3, seconds = 60 * 60, gilt = 5000, glyph = "🗿", colour = rgb(140, 255, 140), line = "Your brainrot squad fills its tip jar three times as fast, for an hour." },
	{ id = "scholar", name = "XP Rush", kind = "xp", mult = 2, seconds = 30 * 60, gilt = 3000, glyph = "⭐", colour = rgb(200, 170, 255), line = "Double XP from everything you play, for 30 minutes." },
} :: { Booster }

Boosters.byId = {} :: { [string]: Booster }
for _, b in Boosters.List do
	Boosters.byId[b.id] = b
end

-- "15 min", "1 hour".
function Boosters.duration(seconds: number): string
	if seconds >= 3600 and seconds % 3600 == 0 then
		local h = seconds // 3600
		return if h == 1 then "1 hour" else string.format("%d hours", h)
	end
	return string.format("%d min", math.ceil(seconds / 60))
end

-- The attribute each kind's end time is published on (the HUD's chips read it).
Boosters.Attribute = { gilt = "BoosterGiltUntil", squad = "BoosterSquadUntil", xp = "BoosterXPUntil" } :: { [string]: string }

return Boosters

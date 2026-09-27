--!strict
-- The house follows the calendar (Appendix C). Checked in order; the first match wins.
-- Windows are inclusive month/day pairs; Midnight Toast wraps the new year.

local Seasons = {}

export type Season = {
	id: string,
	name: string,
	from: { number }, -- {month, day}
	to: { number },
	weather: string,
	line: string,
	key: Color3,
	fill: Color3,
	grade: Color3,
	weatherColours: { Color3 },
}

local function hexes(...: string): { Color3 }
	local out = {}
	for _, h in { ... } do
		table.insert(out, Color3.fromHex(h))
	end
	return out
end

Seasons.List = {
	{
		id = "hallows", name = "All Hallows", from = { 10, 18 }, to = { 11, 2 }, weather = "embers",
		line = "The lamps are low and something is watching the table.",
		key = Color3.fromRGB(255, 120, 34), fill = Color3.fromRGB(146, 54, 205), grade = Color3.fromRGB(128, 50, 160),
		weatherColours = hexes("ff9a4a", "e8622a", "ffc27a", "b06ad0"),
	},
	{
		id = "toast", name = "Midnight Toast", from = { 12, 27 }, to = { 1, 6 }, weather = "confetti",
		line = "One year closing, another poured.",
		key = Color3.fromRGB(240, 220, 168), fill = Color3.fromRGB(178, 198, 240), grade = Color3.fromRGB(196, 188, 236),
		weatherColours = hexes("ecd8a6", "dfe6ee", "c6a052", "f0c0d0"),
	},
	{
		id = "rose", name = "Rose Hour", from = { 2, 7 }, to = { 2, 20 }, weather = "petals",
		line = "Someone left the good perfume out.",
		key = Color3.fromRGB(255, 170, 192), fill = Color3.fromRGB(228, 98, 140), grade = Color3.fromRGB(242, 144, 174),
		weatherColours = hexes("f7c3cf", "fbdfe6", "e9a7b8", "ffd9e2"),
	},
	{
		id = "emerald", name = "Emerald Hour", from = { 3, 12 }, to = { 3, 19 }, weather = "clover",
		line = "Green on the felt, and luck on the table.",
		key = Color3.fromRGB(188, 238, 164), fill = Color3.fromRGB(38, 154, 84), grade = Color3.fromRGB(64, 168, 98),
		weatherColours = hexes("7ec87e", "4f9e57", "a8dd9e", "d8f0c0"),
	},
	{
		id = "harvest", name = "Harvest Nights", from = { 9, 15 }, to = { 10, 31 }, weather = "leaves",
		line = "The evenings have turned amber.",
		key = Color3.fromRGB(250, 168, 72), fill = Color3.fromRGB(150, 66, 24), grade = Color3.fromRGB(200, 108, 40),
		weatherColours = hexes("c67a3a", "a85c2a", "d9a24e", "8a4b28"),
	},
	{
		id = "longtable", name = "The Long Table", from = { 11, 1 }, to = { 11, 30 }, weather = "leaves",
		line = "Everything is copper and candlelight this month.",
		key = Color3.fromRGB(244, 158, 80), fill = Color3.fromRGB(122, 54, 18), grade = Color3.fromRGB(190, 96, 38),
		weatherColours = hexes("c0763c", "9a5427", "e0a35a", "7a4423"),
	},
	{
		id = "yule", name = "Yuletide", from = { 12, 1 }, to = { 12, 31 }, weather = "snow",
		line = "Snow on the glass and the good boxes out.",
		key = Color3.fromRGB(214, 242, 230), fill = Color3.fromRGB(34, 122, 88), grade = Color3.fromRGB(110, 184, 158),
		weatherColours = hexes("ffffff", "dbeafe", "eef6ff", "cfe6d8"),
	},
	{
		id = "frost", name = "Deep Winter", from = { 1, 1 }, to = { 3, 11 }, weather = "snow",
		line = "Quiet months. The house keeps its own hours.",
		key = Color3.fromRGB(210, 234, 255), fill = Color3.fromRGB(60, 116, 180), grade = Color3.fromRGB(132, 178, 228),
		weatherColours = hexes("ffffff", "dbeafe", "c6def5", "eef6ff"),
	},
	{
		id = "bloom", name = "First Bloom", from = { 3, 12 }, to = { 5, 31 }, weather = "petals",
		line = "The windows are open again.",
		key = Color3.fromRGB(255, 208, 230), fill = Color3.fromRGB(140, 198, 110), grade = Color3.fromRGB(206, 164, 212),
		weatherColours = hexes("f6ccd8", "ffe9f0", "cfe6b8", "f2dff0"),
	},
	{
		id = "summer", name = "High Summer", from = { 6, 1 }, to = { 9, 14 }, weather = "fireflies",
		line = "Warm nights, and the doors to the terrace open.",
		key = Color3.fromRGB(255, 210, 120), fill = Color3.fromRGB(48, 138, 184), grade = Color3.fromRGB(224, 180, 104),
		weatherColours = hexes("ffe9a8", "ffd166", "fff3c4", "bfe4f2"),
	},
} :: { Season }

Seasons.byId = {} :: { [string]: Season }
for _, s in Seasons.List do
	Seasons.byId[s.id] = s
end

local function ordinal(month: number, day: number): number
	return month * 100 + day
end

local function inWindow(season: Season, month: number, day: number): boolean
	local d = ordinal(month, day)
	local from = ordinal(season.from[1], season.from[2])
	local to = ordinal(season.to[1], season.to[2])
	if from <= to then
		return d >= from and d <= to
	end
	-- wraps the new year
	return d >= from or d <= to
end

function Seasons.forDate(month: number, day: number): Season
	for _, season in Seasons.List do
		if inWindow(season, month, day) then
			return season
		end
	end
	-- Unreachable while the windows cover the year; Deep Winter is the quiet default.
	return Seasons.byId.frost
end

-- UTC, so every server agrees.
function Seasons.now(): Season
	local t = os.date("!*t")
	return Seasons.forDate(t.month, t.day)
end

return Seasons

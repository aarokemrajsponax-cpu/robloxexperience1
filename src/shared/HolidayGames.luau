--!strict
-- The holiday games: what guests do on the holidays besides the hunts round the house. The
-- server runs them (server/Holidays) and every screen draws them (World/HolidayGames); this says
-- what each is, when it's open and where it is, so the two always agree. All free; every reward is
-- decided and paid on the server (Config.HolidayGames has the numbers).
--
--   All Hallows': trick or treat on Hallows Lane, a street of grand houses away from the Maison. A
--     host in costume answers every door with a treat: Gilt, and now and then a sugared Gem.
--   Thanksgiving: the Turkey Round-Up in the Harvest Field. The turkeys run; catch them for Gilt,
--     now and then a Gem, and more for the golden one.
--   Christmas: Santa's sleigh waits at the kerb. Ride it to the North Pole, gather the gifts lying
--     in the snow, load them on the sleigh before it flies home, and open them at the Maison:
--     Gilt, more Gilt, Gems, and once in a while a lot of Gems. (Free gifts: nothing about them
--     is ever sold.)
--   Easter: the Great Egg Hunt. Painted eggs hidden all over the house; one is golden.
--   St Patrick's: the luck of the Irish. Mythics and the rarer curios turn up far more often at the
--     tables (never a score).
--
-- Each is open for its holiday's days (Config.HolidayGames.windows) and whenever the holiday's
-- own event is on (the owner's, or the house's on the day).

local Config = require(script.Parent.Config)
local HouseEvents = require(script.Parent.HouseEvents)

local HolidayGames = {}

export type Game = {
	id: string,
	name: string, -- what it's called
	place: string?, -- where it is, when it's away from the Maison
	glyph: string,
	key: string, -- the word on its key in the dock
	area: string?, -- "lane", "field" or "pole": its own place, away from the Maison
	line: string, -- what to do, in a line
	colour: Color3, -- its colour on screen
}

local rgb = Color3.fromRGB

HolidayGames.List = {
	{ id = "halloween", name = "Trick or Treat", place = "Hallows Lane", glyph = "🎃", key = "Treats", area = "lane", line = "Knock at every door on Hallows Lane: every host has a treat for you.", colour = rgb(255, 150, 60) },
	{ id = "thanksgiving", name = "The Turkey Round-Up", place = "the Harvest Field", glyph = "🦃", key = "Turkeys", area = "field", line = "The turkeys are loose in the Harvest Field. Run them down; one is golden.", colour = rgb(236, 170, 80) },
	{ id = "christmas", name = "Santa's Sleigh", place = "the North Pole", glyph = "🛷", key = "Sleigh", area = "pole", line = "Ride Santa's sleigh to the North Pole, gather the gifts in the snow and load them before it flies home.", colour = rgb(230, 70, 70) },
	{ id = "easter", name = "The Great Egg Hunt", glyph = "🥚", key = "Eggs", line = "Painted eggs are hidden all over the house. One of them is golden.", colour = rgb(250, 180, 220) },
	{ id = "stPatrick", name = "The Luck of the Irish", glyph = "🍀", key = "Luck", line = "Mythics and rare curios turn up far more often at every table.", colour = rgb(90, 220, 120) },
} :: { Game }

HolidayGames.byId = {} :: { [string]: Game }
for _, g in HolidayGames.List do
	HolidayGames.byId[g.id] = g
end

-- The Workspace attribute holding the game that's open (its id), or nil.
HolidayGames.ATTRIBUTE = "HolidayGame"

---------------------------------------------------------------------------------------------------
-- When
---------------------------------------------------------------------------------------------------

-- Days since 1 January 1970 for a date (any calendar day, no time zone: Howard Hinnant's
-- days_from_civil).
function HolidayGames.dayNumber(year: number, month: number, day: number): number
	local y = if month <= 2 then year - 1 else year
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (month + 9) % 12
	local doy = (153 * mp + 2) // 5 + day - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	return era * 146097 + doe - 719468
end

-- A holiday's own day in a year: its month and day.
function HolidayGames.dayOf(id: string, year: number): (number, number)
	if id == "halloween" then
		return 10, 31
	elseif id == "thanksgiving" then
		-- The fourth Thursday of November.
		for d = 22, 28 do
			if HouseEvents.weekday(year, 11, d) == 4 then
				return 11, d
			end
		end
		return 11, 26
	elseif id == "christmas" then
		return 12, 25
	elseif id == "easter" then
		return HouseEvents.easter(year)
	elseif id == "stPatrick" then
		return 3, 17
	end
	return 1, 1
end

-- The game whose days a date falls in (UTC), or nil.
function HolidayGames.openOn(year: number, month: number, day: number): string?
	local today = HolidayGames.dayNumber(year, month, day)
	local windows = Config.data.HolidayGames.windows :: { [string]: { lead: number, linger: number } }
	for _, g in HolidayGames.List do
		local w = windows[g.id]
		if w then
			-- (This year's, and the next year's for a window reaching back into December.)
			for _, y in { year, year + 1, year - 1 } do
				local m, d = HolidayGames.dayOf(g.id, y)
				local on = HolidayGames.dayNumber(y, m, d)
				if today >= on - w.lead and today <= on + w.linger then
					return g.id
				end
			end
		end
	end
	return nil
end

-- The game open now by the calendar (UTC), or nil.
function HolidayGames.byCalendar(): string?
	local t = os.date("!*t") :: any
	return HolidayGames.openOn(t.year, t.month, t.day)
end

---------------------------------------------------------------------------------------------------
-- Where: each game's place, well away from the Maison (out of sight across the night air)
---------------------------------------------------------------------------------------------------

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

function HolidayGames.origin(area: string): Vector3
	local c = Config.data.HolidayGames :: any
	local o = c[area] and c[area].origin
	return if type(o) == "table" then vec(o) else Vector3.zero
end

-- Hallows Lane runs east (+X) from its gate. Eight houses face each other across it (four a side)
-- and the ninth, Maison Minuit, closes its far end. Each door's frame stands on the threshold,
-- facing out to the Lane.
HolidayGames.Lane = {
	half = 200, -- the Lane runs this far either side of its middle
	road = 12, -- half the road's width
	pavement = 24, -- the pavement's outer edge (the railings)
	front = 44, -- the houses' fronts
	porch = 3, -- a porch's floor, above the road
	houseXs = { -110, -40, 30, 100 },
	minuitX = 190,
	arrival = Vector3.new(-188, 0.6, 0), -- just inside the way home, the gate and the Lane ahead
}

-- The doors of Hallows Lane, in order (1-8 down the sides, 9 the Maison Minuit): where each
-- stands and which way it faces.
function HolidayGames.laneDoors(): { CFrame }
	local O = HolidayGames.origin("lane")
	local L = HolidayGames.Lane
	local doors = {}
	for _, side in { 1, -1 } do
		for _, x in L.houseXs do
			local at = O + Vector3.new(x, L.porch, side * L.front)
			table.insert(doors, CFrame.lookAt(at, at - Vector3.new(0, 0, side)))
		end
	end
	local at = O + Vector3.new(L.minuitX, L.porch, 0)
	table.insert(doors, CFrame.lookAt(at, at - Vector3.new(1, 0, 0)))
	return doors
end

-- The Harvest Field: a fenced field with the barn at its north end, the gate to the south.
HolidayGames.Field = {
	minX = -170,
	maxX = 170,
	minZ = -110,
	maxZ = 150,
	-- Where the turkeys may run (in front of the barn).
	run = { minX = -160, maxX = 160, minZ = -100, maxZ = 84 },
	barn = Vector3.new(0, 0, 118), -- its middle; its doors face south
	barnDoors = Vector3.new(0, 0, 92),
	arrival = Vector3.new(0, 0.6, -128),
}

-- The North Pole: the workshop to the north, the great tree, the sleigh's pad to the south, and
-- the gifts in the snow all round.
HolidayGames.Pole = {
	half = 210,
	pad = Vector3.new(0, 0, -96), -- the sleigh, parked facing east (+X)
	workshop = Vector3.new(0, 0, 104), -- its middle; its doors face south
	tree = Vector3.new(-72, 0, 12),
	giftsFrom = 36, -- the gifts lie this far from the middle...
	giftsTo = 190, -- ...to this far
	arrival = Vector3.new(0, 0.6, -70),
}

-- The sleigh at the Maison's kerb: on the road in front of the house, facing east along it.
HolidayGames.HOME_SLEIGH = CFrame.lookAt(Vector3.new(-22, 0, -70), Vector3.new(100, 0, -70))

-- The sleigh's frame at the North Pole.
function HolidayGames.poleSleigh(): CFrame
	local at = HolidayGames.origin("pole") + HolidayGames.Pole.pad
	return CFrame.lookAt(at, at + Vector3.new(1, 0, 0))
end

-- Which game's place a point is in ("lane", "field", "pole"), or nil (the Maison and its street).
function HolidayGames.areaAt(p: Vector3): string?
	local lane = HolidayGames.origin("lane")
	if math.abs(p.X - lane.X) <= 260 and math.abs(p.Z - lane.Z) <= 160 and p.Y > -60 and p.Y < 400 then
		return "lane"
	end
	local field = HolidayGames.origin("field")
	if math.abs(p.X - field.X) <= 260 and math.abs(p.Z - field.Z) <= 260 and p.Y > -60 and p.Y < 400 then
		return "field"
	end
	local pole = HolidayGames.origin("pole")
	if math.abs(p.X - pole.X) <= 260 and math.abs(p.Z - pole.Z) <= 260 and p.Y > -60 and p.Y < 400 then
		return "pole"
	end
	return nil
end

-- The game whose place `area` is.
function HolidayGames.gameOf(area: string): Game?
	for _, g in HolidayGames.List do
		if g.area == area then
			return g
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Santa's sleigh: the way it flies (every screen draws the flight from these, in step)
---------------------------------------------------------------------------------------------------

-- The points the sleigh flies through, from the kerb to the North Pole (`toPole`) or back.
function HolidayGames.flightPoints(toPole: boolean): { Vector3 }
	local H = HolidayGames.HOME_SLEIGH.Position
	local P = HolidayGames.poleSleigh().Position
	if toPole then
		return {
			H,
			H + Vector3.new(36, 0.5, 0),
			H + Vector3.new(96, 18, -6),
			Vector3.new(150, 90, 60),
			Vector3.new(70, 230, 380),
			Vector3.new(0, 330, 1150),
			Vector3.new(0, 320, 2150),
			P + Vector3.new(-130, 170, -380),
			P + Vector3.new(-170, 36, -40),
			P + Vector3.new(-60, 3, 0),
			P,
		}
	end
	return {
		P,
		P + Vector3.new(40, 0.5, 0),
		P + Vector3.new(130, 30, -40),
		P + Vector3.new(110, 190, -460),
		Vector3.new(0, 330, 2050),
		Vector3.new(0, 330, 950),
		Vector3.new(-150, 210, 260),
		Vector3.new(-220, 50, -70),
		H + Vector3.new(-90, 6, 0),
		H + Vector3.new(-30, 0.5, 0),
		H,
	}
end

-- The point and the way along a Catmull-Rom curve through `points` at `u` (0 to 1).
function HolidayGames.along(points: { Vector3 }, u: number): (Vector3, Vector3)
	local n = #points
	local x = math.clamp(u, 0, 1) * (n - 1)
	local i = math.clamp(math.floor(x) + 1, 1, n - 1)
	local t = x - (i - 1)
	local p0 = points[math.max(1, i - 1)]
	local p1 = points[i]
	local p2 = points[i + 1]
	local p3 = points[math.min(n, i + 2)]
	local t2, t3 = t * t, t * t * t
	local at = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	local way = 0.5 * ((-p0 + p2) + 2 * (2 * p0 - 5 * p1 + 4 * p2 - p3) * t + 3 * (-p0 + 3 * p1 - 3 * p2 + p3) * t2)
	return at, way
end

-- How far along the flight the sleigh is after `k` of its time (0 to 1): gentle off the ground,
-- fast through the sky, gentle down.
function HolidayGames.ease(k: number): number
	local x = math.clamp(k, 0, 1)
	return x * x * x * (x * (x * 6 - 15) + 10)
end

---------------------------------------------------------------------------------------------------
-- What a Christmas gift may hold (shown, with its odds, on the screen that opens them)
---------------------------------------------------------------------------------------------------
HolidayGames.GiftKinds = {
	{ id = "gilt", name = "Gilt", glyph = "🪙" },
	{ id = "moreGilt", name = "A heap of Gilt", glyph = "💰" },
	{ id = "gems", name = "Gems", glyph = "💎" },
	{ id = "moreGems", name = "A trove of Gems", glyph = "👑" },
}

-- "1 in 10" for each kind, from the weights (for the opening screen).
function HolidayGames.giftOdds(): { { id: string, name: string, glyph: string, odds: string } }
	local w = Config.data.HolidayGames.pole.odds :: { [string]: number }
	local total = 0
	for _, v in w do
		total += v
	end
	local out = {}
	for _, k in HolidayGames.GiftKinds do
		local share = (w[k.id] or 0) / math.max(1, total)
		local text = if share >= 0.5 then string.format("%d in 100", math.floor(share * 100 + 0.5)) else string.format("1 in %d", math.max(1, math.floor(1 / math.max(share, 1e-6) + 0.5)))
		table.insert(out, { id = k.id, name = k.name, glyph = k.glyph, odds = text })
	end
	return out
end

return HolidayGames

--!strict
-- The Maison Basement: the obby under the house (shared by the server, which builds and judges it,
-- and every screen, which moves its machinery and draws its HUD). All positions are from the
-- Basement's origin (shared/Attractions.origin("basement")); the course runs down and away along +Z,
-- sixteen stages in four parts, a checkpoint at the end of each, the Treasury at the foot.
--
--   The Wine Cellar        barrel tops, the racks' narrow plank, tiles that sink, a belt of barrels
--   The Boiler Room        pipes, steam vents, pistons that carry you, the great valve that sweeps
--   The Old Vaults         the laser hall, a truss to climb, sinking tiles and a lift, the safe door
--   The Treasury Depths    gold steps, the counting belt, falling coins, the last leap
--
-- Everything that moves, moves by the server's clock (workspace:GetServerTimeNow()): every screen
-- moves it the same way, and the server judges by the same sums. Fall, or touch steam, a laser or
-- the valve, and you're back at your last checkpoint.

local Basement = {}

export type Kind = "pad" | "beam" | "vanish" | "steam" | "mover" | "spinner" | "conveyor" | "truss" | "laser" | "pit" | "chest"
export type El = {
	kind: Kind,
	stage: number,
	at: Vector3, -- the middle of the box (a mover: at the start of its run)
	size: Vector3,
	b: Vector3?, -- a mover: the other end of its run
	period: number?, -- seconds for one cycle (movers, vanishing tiles, steam, lasers)
	phase: number?, -- 0 to 1: where in its cycle it starts
	on: number?, -- the part of the cycle it's there (a tile) or burning (steam, a laser)
	speed: number?, -- a belt (studs a second) or a valve's sweep (degrees a second)
	look: string?, -- how it's built (BasementBuild)
}
export type Zone = { id: number, name: string, line: string, from: number, to: number, colour: Color3, purse: number }
export type Checkpoint = { n: number, at: Vector3, size: Vector3, zone: number }

local rgb = Color3.fromRGB

Basement.Zones = {
	{ id = 1, name = "The Wine Cellar", line = "Barrel tops and a narrow plank. Mind the tiles that sink.", from = 1, to = 4, colour = rgb(170, 40, 70), purse = 600 },
	{ id = 2, name = "The Boiler Room", line = "Steam, pistons, and the great valve that sweeps the floor.", from = 5, to = 8, colour = rgb(230, 120, 50), purse = 1500 },
	{ id = 3, name = "The Old Vaults", line = "The laser hall, the truss, the safe door.", from = 9, to = 12, colour = rgb(90, 150, 230), purse = 3000 },
	{ id = 4, name = "The Treasury Depths", line = "Gold steps, falling coins, and the last leap to the Treasury.", from = 13, to = 16, colour = rgb(255, 196, 70), purse = 5000 },
} :: { Zone }

Basement.STAGES = 16
Basement.StageNames = {
	"The Cellar Steps", "The Racks", "The Tasting Tiles", "The Barrel Belt",
	"The Pipes", "The Pistons", "The Great Valve", "The Furnace Walk",
	"The Laser Hall", "The Truss", "The Combination", "The Safe Door",
	"The Gold Steps", "The Counting House", "The Falling Coins", "The Treasury",
} :: { string }

Basement.Elements = {} :: { El }
Basement.Checkpoints = {} :: { [number]: Checkpoint } -- 0: the start, 16: the Treasury
Basement.Pits = {} :: { [number]: El } -- under each stage

local E = Basement.Elements
local stage = 0

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function add(e: { [string]: any }): El
	e.stage = stage
	table.insert(E, e :: any)
	return e :: any
end

-- A platform whose top is at `top` (its middle in x and z at `c`).
local function pad(c: Vector3, w: number, d: number, look: string?): El
	return add({ kind = "pad", at = c - v(0, 0.5, 0), size = v(w, 1, d), look = look or "stone" })
end

local function beam(c: Vector3, w: number, d: number, look: string?): El
	return add({ kind = "beam", at = c - v(0, 0.4, 0), size = v(w, 0.8, d), look = look or "plank" })
end

local function vanish(c: Vector3, w: number, d: number, period: number, phase: number, on: number): El
	return add({ kind = "vanish", at = c - v(0, 0.5, 0), size = v(w, 1, d), period = period, phase = phase, on = on, look = "tile" })
end

-- Steam from a vent: a column over `c` (the floor), burning `on` of every `period` seconds.
local function steam(c: Vector3, w: number, d: number, period: number, phase: number, on: number): El
	return add({ kind = "steam", at = c + v(0, 4, 0), size = v(w, 8, d), period = period, phase = phase, on = on })
end

local function mover(a: Vector3, b: Vector3, w: number, d: number, period: number, phase: number): El
	return add({ kind = "mover", at = a - v(0, 0.5, 0), b = b - v(0, 0.5, 0), size = v(w, 1, d), period = period, phase = phase, look = "piston" })
end

-- The valve's bar, sweeping round its hub at knee height over the floor at `c`.
local function spinner(c: Vector3, length: number, speed: number, phase: number): El
	return add({ kind = "spinner", at = c + v(0, 1.6, 0), size = v(length, 1.2, 1.2), speed = speed, phase = phase })
end

local function conveyor(c: Vector3, w: number, d: number, speed: number): El
	return add({ kind = "conveyor", at = c - v(0, 0.5, 0), size = v(w, 1, d), speed = speed, look = "belt" })
end

local function truss(c: Vector3, h: number): El
	return add({ kind = "truss", at = c + v(0, h / 2, 0), size = v(2, h, 2) })
end

-- A laser across the way at a height over the floor at `c`, burning `on` of every `period`.
local function laser(c: Vector3, w: number, y: number, period: number, phase: number, on: number): El
	return add({ kind = "laser", at = c + v(0, y, 0), size = v(w, 0.5, 0.5), period = period, phase = phase, on = on })
end

local function checkpoint(n: number, c: Vector3, zone: number): Vector3
	pad(c, 12, 8, if n % 4 == 0 then "landing" else "checkpoint")
	Basement.Checkpoints[n] = { n = n, at = c, size = v(12, 6, 8), zone = zone }
	return c
end

local function zoneOf(n: number): number
	for _, z in Basement.Zones do
		if n >= z.from and n <= z.to then
			return z.id
		end
	end
	return 1
end
Basement.zoneOf = zoneOf

-- Skipping a stage costs more the deeper it is, so the hard stages near the Treasury are never a
-- cheap way down: Gems (the first stage's price, and more for each stage after it), or skips held
-- (one for a stage in the first part, two in the second, three in the third, four in the last).
Basement.SKIP_GEMS = 25
Basement.SKIP_GEMS_STEP = 15
function Basement.skipGems(stage: number, base: number?, step: number?): number
	local n = math.clamp(math.floor(stage), 1, Basement.STAGES)
	return math.floor((base or Basement.SKIP_GEMS) + (step or Basement.SKIP_GEMS_STEP) * (n - 1))
end
function Basement.skipsNeeded(stage: number): number
	return zoneOf(math.clamp(math.floor(stage), 1, Basement.STAGES))
end

---------------------------------------------------------------------------------------------------
-- The course (from the start, at the foot of the stair down: the top of its landing at y = 0)
---------------------------------------------------------------------------------------------------
-- (Guests jump about 3 studs up and 8 across at a walk: no gap here is wider than 5, no step up
-- higher than 2.)
local s = checkpoint(0, v(0, 0, 0), 1)

-- 1. The Cellar Steps: five barrel tops, each a stud lower.
stage = 1
do
	for i = 1, 5 do
		pad(s + v(if i % 2 == 0 then 2 else -2, -i, 4 + 4 + 2.5 + (i - 1) * 9), 5, 5, "barrel")
	end
	s = checkpoint(1, s + v(0, -6, 4 + 4 + 2.5 + 36 + 2.5 + 4 + 4), 1)
end

-- 2. The Racks: a narrow plank between the wine racks, then two barrels.
stage = 2
do
	beam(s + v(0, 0, 4 + 2 + 10), 1.8, 20)
	pad(s + v(3, -1, 4 + 2 + 20 + 4 + 2.5), 5, 5, "barrel")
	pad(s + v(-3, -2, 4 + 2 + 20 + 4 + 5 + 4 + 2.5), 5, 5, "barrel")
	s = checkpoint(2, s + v(0, -3, 4 + 2 + 20 + 4 + 5 + 4 + 5 + 4 + 4), 1)
end

-- 3. The Tasting Tiles: tiles that sink and rise again, one after another.
stage = 3
do
	for i = 1, 4 do
		vanish(s + v(0, -0.5 * i, 4 + 3 + 2.5 + (i - 1) * 8), 5, 5, 3.2, (i - 1) * 0.22, 0.62)
	end
	s = checkpoint(3, s + v(0, -2.5, 4 + 3 + 2.5 + 24 + 2.5 + 3 + 4), 1)
end

-- 4. The Barrel Belt: a belt of barrels running back toward you.
stage = 4
do
	conveyor(s + v(0, 0, 4 + 12), 7, 24, 9)
	s = checkpoint(4, s + v(0, -1, 4 + 24 + 4 + 4), 1)
end

-- 5. The Pipes: two pipes to walk, steam from a vent between them.
stage = 5
do
	beam(s + v(-2, 0, 4 + 8), 1.6, 16, "pipe")
	pad(s + v(-2, -1, 4 + 16 + 3 + 3), 6, 6, "grate")
	steam(s + v(-2, -1, 4 + 16 + 3 + 3), 6, 6, 3, 0, 0.4)
	beam(s + v(2, -1, 4 + 16 + 3 + 6 + 3 + 8), 1.6, 16, "pipe")
	s = checkpoint(5, s + v(0, -2, 4 + 16 + 3 + 6 + 3 + 16 + 3 + 4), 2)
end

-- 6. The Pistons: three platforms sliding side to side; ride each across.
stage = 6
do
	for i = 1, 3 do
		local z = 4 + 4 + 3 + (i - 1) * 10
		mover(s + v(-6, -i * 0.5, z), s + v(6, -i * 0.5, z), 6, 6, 4.5, (i - 1) * 0.33)
	end
	s = checkpoint(6, s + v(0, -2, 4 + 4 + 3 + 20 + 3 + 4 + 4), 2)
end

-- 7. The Great Valve: a round floor with the valve's bar sweeping across it; jump it or time it.
stage = 7
do
	local c = s + v(0, -1, 4 + 3 + 9)
	pad(c, 18, 18, "valve")
	spinner(c, 16, 75, 0)
	s = checkpoint(7, s + v(0, -1, 4 + 3 + 18 + 3 + 4), 2)
end

-- 8. The Furnace Walk: small grates over the furnace, a stud lower each.
stage = 8
do
	for i = 1, 5 do
		pad(s + v(if i % 2 == 0 then -2.5 else 2.5, -i * 0.8, 4 + 4 + 2 + (i - 1) * 8), 4, 4, "grate")
	end
	steam(s + v(-2.5, -1.6, 4 + 4 + 2 + 8), 4, 4, 2.6, 0.5, 0.35)
	s = checkpoint(8, s + v(0, -5, 4 + 4 + 2 + 32 + 2 + 4 + 4), 2)
end

-- 9. The Laser Hall: a long hall, lasers across it, each burning in its turn.
stage = 9
do
	pad(s + v(0, 0, 4 + 2 + 16), 8, 32, "vault")
	for i = 1, 4 do
		laser(s + v(0, 0, 4 + 2 + 4 + (i - 1) * 8), 8, 1.4 + (i % 2) * 1.6, 2.4, (i - 1) * 0.25, 0.5)
	end
	s = checkpoint(9, s + v(0, 0, 4 + 2 + 32 + 2 + 4), 3)
end

-- 10. The Truss: climb the truss to the ledge, along the beam, and drop to the next floor.
stage = 10
do
	pad(s + v(0, 0, 4 + 2 + 3), 8, 6, "vault")
	truss(s + v(0, 0, 4 + 2 + 6 + 1), 9)
	pad(s + v(0, 8, 4 + 2 + 6 + 2 + 3), 6, 6, "vault")
	beam(s + v(0, 8, 4 + 2 + 6 + 2 + 6 + 8), 1.8, 16, "steel")
	pad(s + v(0, 8, 4 + 2 + 6 + 2 + 6 + 16 + 3), 6, 6, "vault")
	s = checkpoint(10, s + v(0, -2, 4 + 2 + 6 + 2 + 6 + 16 + 6 + 3 + 4), 3)
end

-- 11. The Combination: three tiles that sink, then a lift sliding across.
stage = 11
do
	for i = 1, 3 do
		vanish(s + v(0, -0.5 * i, 4 + 3 + 2.5 + (i - 1) * 8), 5, 5, 2.8, (i - 1) * 0.3, 0.6)
	end
	mover(s + v(-5, -2, 4 + 3 + 21 + 4 + 3), s + v(5, -2, 4 + 3 + 21 + 4 + 3), 6, 6, 4, 0)
	s = checkpoint(11, s + v(0, -2, 4 + 3 + 21 + 4 + 6 + 3 + 4), 3)
end

-- 12. The Safe Door: two bars sweeping the vault floor, opposite ways, then the plank.
stage = 12
do
	local c = s + v(0, 0, 4 + 3 + 10)
	pad(c, 20, 20, "safe")
	spinner(c + v(0, 0, -5), 9, 90, 0)
	spinner(c + v(0, 0, 5), 9, -90, 0.25)
	beam(s + v(0, -1, 4 + 3 + 20 + 2 + 7), 1.8, 14, "steel")
	s = checkpoint(12, s + v(0, -2, 4 + 3 + 20 + 2 + 14 + 3 + 4), 3)
end

-- 13. The Gold Steps: small gold steps, a stud lower each.
stage = 13
do
	for i = 1, 6 do
		pad(s + v(if i % 2 == 0 then 3 else -3, -i, 4 + 4 + 1.75 + (i - 1) * 7.5), 3.5, 3.5, "gold")
	end
	s = checkpoint(13, s + v(0, -7, 4 + 4 + 3.5 + 37.5 + 4 + 4), 4)
end

-- 14. The Counting House: the belt, and steam over it.
stage = 14
do
	conveyor(s + v(0, 0, 4 + 13), 7, 26, 11)
	steam(s + v(0, 0, 4 + 9), 7, 3, 2.8, 0, 0.35)
	steam(s + v(0, 0, 4 + 19), 7, 3, 2.8, 0.5, 0.35)
	s = checkpoint(14, s + v(0, -1, 4 + 26 + 4 + 4), 4)
end

-- 15. The Falling Coins: gold tiles that sink faster.
stage = 15
do
	for i = 1, 5 do
		vanish(s + v(if i % 2 == 0 then 1.5 else -1.5, -0.6 * i, 4 + 3.5 + 2.25 + (i - 1) * 8), 4.5, 4.5, 2.4, (i - 1) * 0.2, 0.62)
	end
	s = checkpoint(15, s + v(0, -3.5, 4 + 3.5 + 4.5 + 32 + 3.5 + 4), 4)
end

-- 16. The Treasury: a narrow way, the last leap, and the Treasury itself.
stage = 16
do
	beam(s + v(0, 0, 4 + 2 + 7), 1.6, 14, "gold")
	pad(s + v(0, -1, 4 + 2 + 14 + 5 + 2.5), 5, 5, "gold")
	local t = s + v(0, -2, 4 + 2 + 14 + 5 + 5 + 4 + 8)
	pad(t, 24, 16, "treasury")
	Basement.Checkpoints[16] = { n = 16, at = t, size = v(24, 8, 16), zone = 4 }
	add({ kind = "chest", at = t + v(0, 1.5, 4), size = v(5, 3, 3.5) })
end

-- The pits: under each stage, a floor to fall to (and from it, back to the checkpoint).
for n = 1, Basement.STAGES do
	local a, b = Basement.Checkpoints[n - 1], Basement.Checkpoints[n]
	local low = math.min(a.at.Y, b.at.Y)
	for _, e in E do
		if e.stage == n then
			low = math.min(low, e.at.Y - e.size.Y / 2)
		end
	end
	local z0, z1 = a.at.Z + a.size.Z / 2, b.at.Z - b.size.Z / 2
	local pit: El = { kind = "pit", stage = n, at = v(0, low - 14, (z0 + z1) / 2), size = v(34, 2, z1 - z0 + 8) }
	table.insert(E, pit)
	Basement.Pits[n] = pit
end

-- How long the whole course runs (for the walls and the lights).
Basement.LENGTH = Basement.Checkpoints[16].at.Z + 12
Basement.Arrival = CFrame.new(v(0, 0, -1)) -- on the start landing, facing down the course (+Z: see lookToward)
Basement.ARRIVAL_AT = v(0, 0, -1)

---------------------------------------------------------------------------------------------------
-- The machinery's sums (the same on the server and on every screen)
---------------------------------------------------------------------------------------------------
local function cycle(e: El, t: number): number
	local p = e.period or 1
	return ((t / p) + (e.phase or 0)) % 1
end

-- Whether a tile is there (solid) at time t.
function Basement.solid(e: El, t: number): boolean
	if e.kind ~= "vanish" then
		return true
	end
	return cycle(e, t) < (e.on or 0.6)
end

-- How far a tile has sunk (0: there; 1: gone), for its look: it fades over the last moment.
function Basement.fade(e: El, t: number): number
	if e.kind ~= "vanish" then
		return 0
	end
	local c = cycle(e, t)
	local on = e.on or 0.6
	if c < on - 0.12 then
		return 0
	elseif c < on then
		return (c - (on - 0.12)) / 0.12 * 0.6
	end
	return 1
end

-- Whether steam or a laser is burning at time t.
function Basement.burning(e: El, t: number): boolean
	if e.kind ~= "steam" and e.kind ~= "laser" then
		return false
	end
	return cycle(e, t) < (e.on or 0.4)
end

-- Where a mover is at time t (and how fast it's going: its riders go with it).
function Basement.moverAt(e: El, t: number): (Vector3, Vector3)
	local a, b = e.at, e.b or e.at
	local p = e.period or 4
	local w = 2 * math.pi / p
	local x = ((t / p) + (e.phase or 0)) * 2 * math.pi
	local f = (1 - math.cos(x)) / 2
	local df = math.sin(x) / 2 * w
	return a:Lerp(b, f), (b - a) * df
end

-- The valve's bar at time t: its frame (turned about the vertical).
function Basement.spinnerFrame(e: El, t: number): CFrame
	local deg = (e.speed or 60) * t + (e.phase or 0) * 360
	return CFrame.new(e.at) * CFrame.Angles(0, math.rad(deg), 0)
end

-- Which checkpoint's pad a point stands on (from the origin), or nil.
function Basement.checkpointAt(p: Vector3): number?
	for n = 0, Basement.STAGES do
		local c = Basement.Checkpoints[n]
		local half = c.size / 2
		if math.abs(p.X - c.at.X) <= half.X and math.abs(p.Z - c.at.Z) <= half.Z and p.Y >= c.at.Y - 0.5 and p.Y <= c.at.Y + c.size.Y then
			return n
		end
	end
	return nil
end

-- Whether a point is inside a box (from its middle, its size, turned by `cf` if given), with room
-- to spare (`pad` studs).
function Basement.inBox(p: Vector3, at: Vector3, size: Vector3, padBy: number?, cf: CFrame?): boolean
	local rel = if cf then cf:PointToObjectSpace(p) else p - at
	local half = size / 2 + Vector3.new(1, 1, 1) * (padBy or 0)
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

-- A run's time as the boards show it (seconds, to hundredths).
function Basement.clock(seconds: number): string
	local cs = math.max(0, math.floor(seconds * 100 + 0.5))
	local m = cs // 6000
	local sec = (cs // 100) % 60
	return string.format("%d:%02d.%02d", m, sec, cs % 100)
end

return Basement

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
--
-- Build 78: the course turns over every five minutes, in turn (Variants): the House Course, Double
-- Time (every machine faster, steam on the Gold Steps), Blackout (the lights down, every edge
-- glowing) and The Gauntlet (crushers, a second sweep, a launch pad to a hidden ledge). A guest's
-- run keeps the version it started on until the Treasury; each version has two secrets to find.

local Basement = {}

export type Kind = "pad" | "beam" | "vanish" | "steam" | "mover" | "spinner" | "conveyor" | "truss" | "laser" | "pit" | "chest" | "crusher" | "bouncer" | "secret"
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
	variant: number?, -- only in this version of the course (nil: in every one)
	bounce: number?, -- a launch pad: how hard it throws you up (studs a second)
	id: string?, -- a secret: its id (kept with the guest's ledger once found)
	name: string?, -- a secret: what it is
	runUp: number?, -- (Build 82) a stage's run-up: which hop it is (the landing: the last)
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

-- A crusher over the floor at `c`: a heavy block that slams down `on` of every `period` seconds
-- (its box is the column it fills when down; it shakes and drops in the moment before).
local function crusher(c: Vector3, w: number, d: number, period: number, phase: number, on: number): El
	return add({ kind = "crusher", at = c + v(0, 4, 0), size = v(w, 8, d), period = period, phase = phase, on = on })
end

-- A launch pad: stand on it and it throws you up (`bounce` studs a second).
local function bouncer(c: Vector3, w: number, d: number, bounce: number): El
	return add({ kind = "bouncer", at = c - v(0, 0.4, 0), size = v(w, 0.8, d), bounce = bounce, look = "bouncer" })
end

-- A secret: something lost, floating over the floor at `c`, found by touching it.
local function secret(id: string, name: string, c: Vector3): El
	return add({ kind = "secret", at = c + v(0, 1.8, 0), size = v(2.4, 2.4, 2.4), id = id, name = name })
end

-- (Only in version `n` of the course.)
local function only(n: number, e: El): El
	e.variant = n
	return e
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

-- (Build 82) The hall is half as wide again and nearly twice as tall as it was, and every stage
-- opens with a run-up: platforms across the hall, more of them, smaller and further apart the
-- deeper the stage (never a gap wider than 5 studs, never a step up higher than 1), drifting out
-- across the hall and back, onto a landing as wide as a checkpoint. The course is more than twice
-- as long for it, and grows with the guest: the first stage's run-up is a single easy hop.
Basement.HALF_WIDTH = 30 -- the hall's walls stand this far either side of the course's line
Basement.HEADROOM = 32 -- the ceiling over a stage's highest platform
local RUN_LOOK = { "barrel", "grate", "steel", "gold" }
function Basement.runUpOf(n: number): (number, number, number)
	local count = 1 + math.floor(n / 2) -- 1 to 9 platforms
	local gap = math.min(4.8, 2.6 + n * 0.14) -- 2.7 to 4.8 studs between them
	local size = math.max(3.6, 6.4 - n * 0.18) -- 6.2 to 3.6 studs across
	return count, gap, size
end
local function runUp(n: number)
	local count, gap, size = Basement.runUpOf(n)
	local look = RUN_LOOK[zoneOf(n)]
	local step = size * 0.55 -- (sideways each hop: never more than half a platform, so a hop is its gap)
	local side = if n % 2 == 0 then 1 else -1
	local x, y = 0, 0
	local z = 4 + gap + size / 2
	for i = 1, count do
		-- Out across the hall for the first half, back toward the middle for the rest.
		x += side * step * (if i <= math.ceil(count / 2) then 1 else -1)
		y += if i % 3 == 0 then 1 else -0.5
		pad(s + v(x, y, z), size, size, look).runUp = i
		z += size + gap
	end
	-- The landing (where the stage itself begins), as wide as a checkpoint.
	-- (After the last platform `z` stands a platform and a gap on: the landing's near edge is one
	-- gap past the last platform's far edge.)
	local landing = s + v(0, y - 0.5, z - size / 2 + 4)
	pad(landing, 12, 8, "landing").runUp = count + 1
	s = landing
end

-- 1. The Cellar Steps: five barrel tops, each a stud lower.
stage = 1
do
	runUp(1)
	for i = 1, 5 do
		pad(s + v(if i % 2 == 0 then 2 else -2, -i, 4 + 4 + 2.5 + (i - 1) * 9), 5, 5, "barrel")
	end
	-- (The House Course's secret: a barrel off to the side of the third.)
	only(1, pad(s + v(-8.5, -2.5, 4 + 4 + 2.5 + 18), 4, 4, "barrel"))
	only(1, secret("cellarCork", "A Vintage Cork", s + v(-8.5, -2.5, 4 + 4 + 2.5 + 18)))
	s = checkpoint(1, s + v(0, -6, 4 + 4 + 2.5 + 36 + 2.5 + 4 + 4), 1)
end

-- 2. The Racks: a narrow plank between the wine racks, then two barrels.
stage = 2
do
	runUp(2)
	beam(s + v(0, 0, 4 + 2 + 10), 1.8, 20)
	only(4, crusher(s + v(0, 0, 4 + 2 + 10), 3, 3, 2.6, 0, 0.3)) -- (The Gauntlet: a crusher over the plank)
	pad(s + v(3, -1, 4 + 2 + 20 + 4 + 2.5), 5, 5, "barrel")
	pad(s + v(-3, -2, 4 + 2 + 20 + 4 + 5 + 4 + 2.5), 5, 5, "barrel")
	s = checkpoint(2, s + v(0, -3, 4 + 2 + 20 + 4 + 5 + 4 + 5 + 4 + 4), 1)
end

-- 3. The Tasting Tiles: tiles that sink and rise again, one after another.
stage = 3
do
	runUp(3)
	for i = 1, 4 do
		vanish(s + v(0, -0.5 * i, 4 + 3 + 2.5 + (i - 1) * 8), 5, 5, 3.2, (i - 1) * 0.22, 0.62)
	end
	s = checkpoint(3, s + v(0, -2.5, 4 + 3 + 2.5 + 24 + 2.5 + 3 + 4), 1)
end

-- 4. The Barrel Belt: a belt of barrels running back toward you.
stage = 4
do
	runUp(4)
	conveyor(s + v(0, 0, 4 + 12), 7, 24, 9)
	-- (Blackout's secret: a ledge beside the belt, in the dark.)
	only(3, pad(s + v(7.5, 0.5, 4 + 12), 4, 4, "barrel"))
	only(3, secret("beltLabel", "A Lost Wine Label", s + v(7.5, 0.5, 4 + 12)))
	s = checkpoint(4, s + v(0, -1, 4 + 24 + 4 + 4), 1)
end

-- 5. The Pipes: two pipes to walk, steam from a vent between them.
stage = 5
do
	runUp(5)
	beam(s + v(-2, 0, 4 + 8), 1.6, 16, "pipe")
	pad(s + v(-2, -1, 4 + 16 + 3 + 3), 6, 6, "grate")
	steam(s + v(-2, -1, 4 + 16 + 3 + 3), 6, 6, 3, 0, 0.4)
	beam(s + v(2, -1, 4 + 16 + 3 + 6 + 3 + 8), 1.6, 16, "pipe")
	s = checkpoint(5, s + v(0, -2, 4 + 16 + 3 + 6 + 3 + 16 + 3 + 4), 2)
end

-- 6. The Pistons: three platforms sliding side to side; ride each across.
stage = 6
do
	runUp(6)
	for i = 1, 3 do
		local z = 4 + 4 + 3 + (i - 1) * 10
		mover(s + v(-6, -i * 0.5, z), s + v(6, -i * 0.5, z), 6, 6, 4.5, (i - 1) * 0.33)
	end
	-- (Double Time's secret: a grate past the second piston's far end.)
	only(2, pad(s + v(12, -1, 4 + 4 + 3 + 10), 4, 4, "grate"))
	only(2, secret("pistonCog", "A Brass Cog", s + v(12, -1, 4 + 4 + 3 + 10)))
	s = checkpoint(6, s + v(0, -2, 4 + 4 + 3 + 20 + 3 + 4 + 4), 2)
end

-- 7. The Great Valve: a round floor with the valve's bar sweeping across it; jump it or time it.
stage = 7
do
	runUp(7)
	local c = s + v(0, -1, 4 + 3 + 9)
	pad(c, 18, 18, "valve")
	spinner(c, 16, 75, 0)
	only(4, spinner(c, 16, -50, 0.5)) -- (The Gauntlet: a second bar, the other way)
	s = checkpoint(7, s + v(0, -1, 4 + 3 + 18 + 3 + 4), 2)
end

-- 8. The Furnace Walk: small grates over the furnace, a stud lower each.
stage = 8
do
	runUp(8)
	for i = 1, 5 do
		pad(s + v(if i % 2 == 0 then -2.5 else 2.5, -i * 0.8, 4 + 4 + 2 + (i - 1) * 8), 4, 4, "grate")
	end
	steam(s + v(-2.5, -1.6, 4 + 4 + 2 + 8), 4, 4, 2.6, 0.5, 0.35)
	s = checkpoint(8, s + v(0, -5, 4 + 4 + 2 + 32 + 2 + 4 + 4), 2)
end

-- 9. The Laser Hall: a long hall, lasers across it, each burning in its turn.
stage = 9
do
	runUp(9)
	pad(s + v(0, 0, 4 + 2 + 16), 8, 32, "vault")
	for i = 1, 4 do
		laser(s + v(0, 0, 4 + 2 + 4 + (i - 1) * 8), 8, 1.4 + (i % 2) * 1.6, 2.4, (i - 1) * 0.25, 0.5)
	end
	only(4, crusher(s + v(0, 0, 4 + 2 + 24), 8, 3, 3, 0.5, 0.32)) -- (The Gauntlet: a crusher across the hall)
	s = checkpoint(9, s + v(0, 0, 4 + 2 + 32 + 2 + 4), 3)
end

-- 10. The Truss: climb the truss to the ledge, along the beam, and drop to the next floor.
stage = 10
do
	runUp(10)
	pad(s + v(0, 0, 4 + 2 + 3), 8, 6, "vault")
	-- (The Gauntlet's way round: a launch pad up to a hidden ledge, and its secret.)
	only(4, bouncer(s + v(-2.5, 0.2, 4 + 2 + 3), 2.5, 2.5, 82))
	only(4, pad(s + v(-6.5, 14, 4 + 2 + 3), 5, 5, "steel"))
	only(4, secret("trussKey", "The Night Porter's Key", s + v(-6.5, 14, 4 + 2 + 3)))
	truss(s + v(0, 0, 4 + 2 + 6 + 1), 9)
	pad(s + v(0, 8, 4 + 2 + 6 + 2 + 3), 6, 6, "vault")
	beam(s + v(0, 8, 4 + 2 + 6 + 2 + 6 + 8), 1.8, 16, "steel")
	pad(s + v(0, 8, 4 + 2 + 6 + 2 + 6 + 16 + 3), 6, 6, "vault")
	s = checkpoint(10, s + v(0, -2, 4 + 2 + 6 + 2 + 6 + 16 + 6 + 3 + 4), 3)
end

-- 11. The Combination: three tiles that sink, then a lift sliding across.
stage = 11
do
	runUp(11)
	for i = 1, 3 do
		vanish(s + v(0, -0.5 * i, 4 + 3 + 2.5 + (i - 1) * 8), 5, 5, 2.8, (i - 1) * 0.3, 0.6)
	end
	mover(s + v(-5, -2, 4 + 3 + 21 + 4 + 3), s + v(5, -2, 4 + 3 + 21 + 4 + 3), 6, 6, 4, 0)
	s = checkpoint(11, s + v(0, -2, 4 + 3 + 21 + 4 + 6 + 3 + 4), 3)
end

-- 12. The Safe Door: two bars sweeping the vault floor, opposite ways, then the plank.
stage = 12
do
	runUp(12)
	local c = s + v(0, 0, 4 + 3 + 10)
	pad(c, 20, 20, "safe")
	spinner(c + v(0, 0, -5), 9, 90, 0)
	spinner(c + v(0, 0, 5), 9, -90, 0.25)
	only(3, secret("safeDial", "A Safe's Dial", c + v(8.5, 0, 8.5))) -- (Blackout's: the vault's far corner)
	beam(s + v(0, -1, 4 + 3 + 20 + 2 + 7), 1.8, 14, "steel")
	s = checkpoint(12, s + v(0, -2, 4 + 3 + 20 + 2 + 14 + 3 + 4), 3)
end

-- 13. The Gold Steps: small gold steps, a stud lower each.
stage = 13
do
	runUp(13)
	for i = 1, 6 do
		pad(s + v(if i % 2 == 0 then 3 else -3, -i, 4 + 4 + 1.75 + (i - 1) * 7.5), 3.5, 3.5, "gold")
	end
	only(2, steam(s + v(-3, -3, 4 + 4 + 1.75 + 15), 3.5, 3.5, 2.4, 0.3, 0.3)) -- (Double Time: steam on the third step)
	-- (The House Course's second secret: a gold step off the fourth.)
	only(1, pad(s + v(8.5, -3.5, 4 + 4 + 1.75 + 22.5), 3.5, 3.5, "gold"))
	only(1, secret("goldLeaf", "A Gold Leaf", s + v(8.5, -3.5, 4 + 4 + 1.75 + 22.5)))
	s = checkpoint(13, s + v(0, -7, 4 + 4 + 3.5 + 37.5 + 4 + 4), 4)
end

-- 14. The Counting House: the belt, and steam over it.
stage = 14
do
	runUp(14)
	conveyor(s + v(0, 0, 4 + 13), 7, 26, 11)
	steam(s + v(0, 0, 4 + 9), 7, 3, 2.8, 0, 0.35)
	steam(s + v(0, 0, 4 + 19), 7, 3, 2.8, 0.5, 0.35)
	-- (The Gauntlet's second secret: a ledge beside the belt.)
	only(4, pad(s + v(-7.5, 0.5, 4 + 20), 4, 4, "gold"))
	only(4, secret("countingCoin", "The First Coin Counted", s + v(-7.5, 0.5, 4 + 20)))
	s = checkpoint(14, s + v(0, -1, 4 + 26 + 4 + 4), 4)
end

-- 15. The Falling Coins: gold tiles that sink faster.
stage = 15
do
	runUp(15)
	for i = 1, 5 do
		vanish(s + v(if i % 2 == 0 then 1.5 else -1.5, -0.6 * i, 4 + 3.5 + 2.25 + (i - 1) * 8), 4.5, 4.5, 2.4, (i - 1) * 0.2, 0.62)
	end
	-- (Double Time's second secret: a gold ledge off the third tile.)
	only(2, pad(s + v(-8, -1.5, 4 + 3.5 + 2.25 + 16), 4, 4, "gold"))
	only(2, secret("coinPurse", "A Silk Coin Purse", s + v(-8, -1.5, 4 + 3.5 + 2.25 + 16)))
	s = checkpoint(15, s + v(0, -3.5, 4 + 3.5 + 4.5 + 32 + 3.5 + 4), 4)
end

-- 16. The Treasury: a narrow way, the last leap, and the Treasury itself.
stage = 16
do
	runUp(16)
	beam(s + v(0, 0, 4 + 2 + 7), 1.6, 14, "gold")
	only(4, crusher(s + v(0, 0, 4 + 2 + 7), 3, 3, 2.8, 0.25, 0.3)) -- (The Gauntlet: a crusher on the narrow way)
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
	local pit: El = { kind = "pit", stage = n, at = v(0, low - 14, (z0 + z1) / 2), size = v(Basement.HALF_WIDTH * 2 - 2, 2, z1 - z0 + 8) }
	table.insert(E, pit)
	Basement.Pits[n] = pit
end

-- (Build 82) Each stage's floor: its lowest surface (its own platforms, and the checkpoints at
-- either end). A guest whose stage it is, and who is well below it, has fallen: back to their
-- checkpoint, wherever they've fallen to (a later stage's platforms below, or any pit). Nobody skips
-- a stage by dropping onto the lower ones ahead.
Basement.Floors = {} :: { [number]: number }
local FLOOR_KINDS = { pad = true, beam = true, vanish = true, mover = true, conveyor = true, bouncer = true, chest = true }
for n = 1, Basement.STAGES do
	local a, b = Basement.Checkpoints[n - 1], Basement.Checkpoints[n]
	local low = math.min(a.at.Y, b.at.Y)
	for _, e in E do
		if e.stage == n and FLOOR_KINDS[e.kind] then
			local top = e.at.Y + e.size.Y / 2
			if e.kind == "mover" and e.b then
				top = math.min(top, e.b.Y + e.size.Y / 2)
			end
			low = math.min(low, top)
		end
	end
	Basement.Floors[n] = low
end
Basement.FALL_BELOW = 6 -- how far under its stage's floor a guest has fallen

-- The secrets, in the order they're met.
Basement.Secrets = {} :: { El }
for _, e in E do
	if e.kind == "secret" then
		table.insert(Basement.Secrets, e)
	end
end

-- How long the whole course runs (for the walls and the lights).
Basement.LENGTH = Basement.Checkpoints[16].at.Z + 12
Basement.Arrival = CFrame.new(v(0, 0, -1)) -- on the start landing, facing down the course (+Z: see lookToward)
Basement.ARRIVAL_AT = v(0, 0, -1)

---------------------------------------------------------------------------------------------------
-- The versions of the course (Build 78): each up for five minutes by the server's clock, in turn
---------------------------------------------------------------------------------------------------
export type Variant = { id: string, name: string, line: string, pace: number, tint: Color3, bright: number, glow: boolean }
Basement.Variants = {
	{ id = "house", name = "The House Course", line = "The course as the house built it. Two secrets off the beaten way.", pace = 1, tint = rgb(255, 214, 160), bright = 1, glow = false },
	{ id = "doubleTime", name = "Double Time", line = "Every machine runs faster, and steam on the Gold Steps. Time your steps.", pace = 1.4, tint = rgb(255, 120, 70), bright = 1.1, glow = false },
	{ id = "blackout", name = "Blackout", line = "The lights are down and every edge glows. The machines run a little slower.", pace = 0.85, tint = rgb(120, 160, 255), bright = 0.3, glow = true },
	{ id = "gauntlet", name = "The Gauntlet", line = "Crushers, a second sweep on the Valve, and a launch pad to a hidden ledge.", pace = 1, tint = rgb(200, 255, 120), bright = 0.9, glow = false },
} :: { Variant }
Basement.VARIANT_SECONDS = 300

-- The version up at time t (1 to 4).
function Basement.variantAt(t: number): number
	return math.floor(t / Basement.VARIANT_SECONDS) % #Basement.Variants + 1
end

-- When the version up at time t gives way to the next.
function Basement.variantEnds(t: number): number
	return (math.floor(t / Basement.VARIANT_SECONDS) + 1) * Basement.VARIANT_SECONDS
end

-- The machinery's time on version n: everything runs at its pace.
function Basement.paced(n: number, t: number): number
	local var = Basement.Variants[n]
	return t * (if var then var.pace else 1)
end

-- Whether an element is part of version n (most are part of every one).
function Basement.inVariant(e: El, n: number): boolean
	return e.variant == nil or e.variant == n
end

-- How many secrets a version has.
function Basement.secretsIn(n: number): number
	local k = 0
	for _, e in Basement.Secrets do
		if e.variant == n then
			k += 1
		end
	end
	return k
end

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

-- Whether steam or a laser is burning (or a crusher is down) at time t.
function Basement.burning(e: El, t: number): boolean
	if e.kind ~= "steam" and e.kind ~= "laser" and e.kind ~= "crusher" then
		return false
	end
	return cycle(e, t) < (e.on or 0.4)
end

-- How high a crusher's block hangs over its floor at time t (0: down). Down `on` of its cycle; it
-- rises, waits at the top, and in the last moment shakes and drops: you can see it coming.
function Basement.crusherLift(e: El, t: number): number
	local c = cycle(e, t)
	local on = e.on or 0.3
	if c < on then
		return 0
	end
	local up = (c - on) / (1 - on)
	if up < 0.3 then
		return 7 * (up / 0.3)
	elseif up < 0.88 then
		return 7
	end
	return 7 * (1 - (up - 0.88) / 0.12)
end

-- Whether a crusher is about to drop (its warning: the block shakes and glows).
function Basement.crusherWarns(e: El, t: number): boolean
	local c = cycle(e, t)
	local on = e.on or 0.3
	return c >= on and (c - on) / (1 - on) >= 0.7
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

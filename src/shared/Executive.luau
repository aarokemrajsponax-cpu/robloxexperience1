--!strict
-- The Executive Suite: by invitation only (shared by the server, which builds and runs it, and
-- every screen). Positions are from its origin (shared/Attractions.origin("executive")); the way
-- runs along +Z: the lift up, the security hallway, the code door, the Executive's Office.
--
--   The hallway       (Build 81) a gallery maze: the lift's lobby (safe: nobody watches there),
--                     then five galleries one after another, walled with partitions you can
--                     hide behind (a guard or a camera sees nothing through them): the vitrine
--                     island, the split gallery, the serpentine, the colonnade, the vestibule
--                     at the door. Five cameras sweeping, five guards on their rounds, every
--                     one's line of sight drawn on the floor: seen, the alert rises; full,
--                     security shows you out (the invitation spent). Four terminals along the
--                     walls each give you one digit of the door's code (made new each run).
--   The code door     the four digits, in order, at its keypad. Three wrong tries raise the alert.
--   The Office        the Executive, in three phases: behind his shield (shoot out its three
--                     generators), his security detail (four bodyguards), and the man himself
--                     (briefcases thrown, the shockwave of a hostile takeover: jump it, and his
--                     dash). Build 78: every attack of his is wound up first, where everyone can
--                     see it (a ring, a lane, his raised hand), and at the last of his composure
--                     he goes all in (the finale: quicker, two shockwaves at a time). Beat him:
--                     his rewards, the safe, and the extraction: the lift down within a minute,
--                     for a clean getaway's bonus.
--
-- The sidearm is free and every guest takes one from the Quartermaster before going up; the rest of
-- the gear is optional, for Gilt, and works only in the Suite. Invitations come by playing (the
-- Maison Basement cleared, a great haul banked in Steal a Luxe), for Gilt at the Quartermaster's
-- desk, or from the owner. There is no chance in any of it, and no Robux.

local Executive = {}

local rgb = Color3.fromRGB

export type Gear = { id: string, name: string, line: string, price: number, glyph: string, free: boolean? }

Executive.Gear = {
	{ id = "sidearm", name = "The Executive Sidearm", line = "A stun pistol: every guest carries one up. Free, and needed for the Office.", price = 0, glyph = "🔫", free = true },
	{ id = "disguise", name = "A Disguise", line = "Cameras and guards take longer to notice you.", price = 4000, glyph = "🎭" },
	{ id = "decoy", name = "A Decoy", line = "Once a run: every camera and guard in the hallway watches it for eight seconds.", price = 2500, glyph = "🎈" },
	{ id = "scanner", name = "A Scanner", line = "Shows every guard and every code terminal through the walls, all run long.", price = 3000, glyph = "📡" },
	{ id = "vest", name = "An Armoured Vest", line = "Half as much composure again in the Office.", price = 5000, glyph = "🛡️" },
} :: { Gear }
Executive.byGear = {} :: { [string]: Gear }
for _, g in Executive.Gear do
	Executive.byGear[g.id] = g
end

-- The places (from the origin).
Executive.Arrival = Vector3.new(0, 0, -190) -- out of the lift, facing +Z
Executive.Hall = { minX = -24, maxX = 24, minZ = -200, maxZ = -22 }
-- The lift's lobby, before the first partition: nobody watches anyone there.
Executive.Lobby = { minZ = -200, maxZ = -176.5 }
-- The maze's partitions, as boxes on the floor (from min x, z to max x, z): walnut-panelled walls
-- taller than any eye in the hallway, so behind one a guest is out of sight.
Executive.PARTITION_HEIGHT = 12.5
Executive.Partitions = {
	-- The lobby's wall, its doorway in the middle.
	{ -24, -176.5, -5, -175.5 },
	{ 5, -176.5, 24, -175.5 },
	-- I. The vitrine island: round it either way.
	{ -9, -167, 9, -155 },
	-- Its far wall, open at both sides.
	{ -17, -146.5, 17, -145.5 },
	-- II. The split gallery: a spine down the middle, either half.
	{ -0.5, -145.5, 0.5, -130 },
	{ -24, -116.5, -5, -115.5 },
	{ 5, -116.5, 24, -115.5 },
	-- III. The serpentine: right, then left.
	{ -24, -106.5, 6, -105.5 },
	{ -6, -96.5, 24, -95.5 },
	{ -17, -86.5, 17, -85.5 },
	-- IV. The colonnade: two staggered screens.
	{ -24, -79, -6, -77 },
	{ 6, -70, 24, -68 },
	{ -24, -56.5, -5, -55.5 },
	{ 5, -56.5, 24, -55.5 },
	-- V. The vestibule: two vitrines to hide behind.
	{ -13, -44, -9, -40 },
	{ 9, -44, 13, -40 },
} :: { { number } }
Executive.Door = { z = -22, minX = -4, maxX = 4 } -- the code door across the hall's end
-- (Build 91) The Reception: through the arch in the lobby's back wall, behind the lift's lobby, so
-- as safe as it (nothing watches anyone there, no guard walks there). A reception desk, a lounge,
-- a bar and a window wall over the city at night; tonight's look and challenge on the board.
Executive.Reception = { minX = -30, maxX = 30, minZ = -248, maxZ = -201 }
-- The two arches in the lobby's back wall (from x, to x), either side of the way home, which
-- stands in the middle in front of it: nobody walks through that on the way to the Reception.
Executive.Arches = { { -23, -15 }, { 15, 23 } } :: { { number } }
Executive.ARCH_HEIGHT = 11
Executive.Office = { minX = -32, maxX = 32, minZ = -20, maxZ = 62 }
Executive.OfficeEntry = Vector3.new(0, 0, -14) -- just in through the door (where a revive in the Office puts you)
Executive.Desk = Vector3.new(0, 0, 44)
Executive.Lift = Vector3.new(0, 0, 58) -- the way down, behind the desk
Executive.Safe = Vector3.new(26, 0, 50)
-- (Build 94) More to raid once he's run off, each once a guest a run, beside the safe: where each
-- is (in the Office), what its prompt says and how long it's held. What each pays is the house's
-- (Config executive.loot), never the screen's.
Executive.Loot = {
	{ id = "drawers", name = "The desk drawers", action = "Rifle through", at = Vector3.new(5.6, 0, 40.6), hold = 1.5 },
	{ id = "bullion", name = "The bullion trolley", action = "Load up", at = Vector3.new(-22, 0, 48), hold = 2.5 },
	{ id = "watches", name = "The watch case", action = "Open the case", at = Vector3.new(16, 0, 12), hold = 2 },
	{ id = "briefcase", name = "His dropped briefcase", action = "Pick it up", at = Vector3.new(-8, 0, 34), hold = 1 },
} :: { { id: string, name: string, action: string, at: Vector3, hold: number } }
Executive.lootById = {} :: { [string]: { id: string, name: string, action: string, at: Vector3, hold: number } }
for _, l in Executive.Loot do
	Executive.lootById[l.id] = l
end
Executive.HEIGHT = 16

-- The hallway's terminals (each gives one digit, in order), cameras and guards' rounds.
-- (Each against a side wall, a stride in from it: the lectern stands out from the wall.)
Executive.Terminals = {
	Vector3.new(-23, 0, -161),
	Vector3.new(23, 0, -138),
	Vector3.new(-23, 0, -73.5),
	Vector3.new(23, 0, -34),
} :: { Vector3 }
-- (On the side walls, looking across: each sweeps back and forth.)
Executive.Cameras = {
	{ at = Vector3.new(23.5, 11, -161), sweep = 70, period = 6, phase = 0 },
	{ at = Vector3.new(-23.5, 11, -138), sweep = 60, period = 7, phase = 0.5 },
	{ at = Vector3.new(-23.5, 11, -111), sweep = 55, period = 6.5, phase = 0.25 },
	{ at = Vector3.new(23.5, 11, -73.5), sweep = 70, period = 7, phase = 0.75 },
	{ at = Vector3.new(-23.5, 11, -52), sweep = 50, period = 6, phase = 0.4 },
} :: { { at: Vector3, sweep: number, period: number, phase: number } }
-- (Walked in order, round and round; a there-and-back round lists its way back.)
Executive.GuardRounds = {
	{ Vector3.new(-16, 0, -171), Vector3.new(16, 0, -171), Vector3.new(16, 0, -151), Vector3.new(-16, 0, -151) },
	{ Vector3.new(-19, 0, -123), Vector3.new(19, 0, -123) },
	{ Vector3.new(-19, 0, -101), Vector3.new(19, 0, -101) },
	{ Vector3.new(15, 0, -82.5), Vector3.new(15, 0, -73.5), Vector3.new(-15, 0, -73.5), Vector3.new(-15, 0, -62), Vector3.new(-15, 0, -73.5), Vector3.new(15, 0, -73.5) },
	{ Vector3.new(-18, 0, -49), Vector3.new(18, 0, -49) },
} :: { { Vector3 } }

-- The hallway made half as wide again (Build 82): the maze was drawn at 48 studs across and felt
-- cramped, too easy to be caught in. Every x across the hall (its walls, the partitions, the
-- terminals, the cameras, the guards' rounds) is scaled by WIDEN, so the maze keeps its shape
-- with wider ways through it. (The Office keeps its own size.)
Executive.WIDEN = 1.5
do
	local w = Executive.WIDEN
	Executive.Hall.minX *= w
	Executive.Hall.maxX *= w
	for _, b in Executive.Partitions do
		b[1] *= w
		b[3] *= w
	end
	for i, t in Executive.Terminals do
		Executive.Terminals[i] = Vector3.new(t.X * w, t.Y, t.Z)
	end
	for _, c in Executive.Cameras do
		c.at = Vector3.new(c.at.X * w, c.at.Y, c.at.Z)
	end
	for _, round in Executive.GuardRounds do
		for i, p in round do
			round[i] = Vector3.new(p.X * w, p.Y, p.Z)
		end
	end
end

-- The Office: the shield's generators, where the bodyguards come in, where he may dash to.
Executive.Generators = {
	Vector3.new(-24, 0, 30),
	Vector3.new(24, 0, 30),
	Vector3.new(0, 0, 54),
} :: { Vector3 }
Executive.GuardDoors = {
	Vector3.new(-30, 0, 0),
	Vector3.new(30, 0, 0),
	Vector3.new(-30, 0, 40),
	Vector3.new(30, 0, 40),
} :: { Vector3 }
Executive.BossSpots = {
	Vector3.new(0, 0, 40),
	Vector3.new(-18, 0, 24),
	Vector3.new(18, 0, 24),
	Vector3.new(0, 0, 12),
} :: { Vector3 }

Executive.Phases = {
	{ id = "shield", name = "The Shield", line = "His shield is powered by the three blue generators around the Office. Shoot all three and it falls: then his bodyguards come.", say = "You've come a long way up. Let's see what you're worth." },
	{ id = "detail", name = "The Security Detail", line = "His bodyguards. Stun all four.", say = "Gentlemen. Show our guests out." },
	{ id = "boss", name = "The Executive", line = "Watch for his wind-up: a ring is a shockwave (jump it), a lane is his dash (step aside), a raised hand is briefcases (move). At half his composure he spins cases out all round: stand in a gap.", say = "If you want something done properly, you do it yourself." },
} :: { { id: string, name: string, line: string, say: string } }
Executive.FINALE_SAY = "A hostile takeover, then."
Executive.WON_SAY = "Well played. The lift is yours. For now."
-- (Build 94) Beaten, he doesn't stand about: he says this and runs for the nearest bodyguards' door.
Executive.EXIT_SAY = "Alright, alright, you got me. Until next time..."
Executive.EXIT_SPEED = 34 -- studs a second: a proper sprint
Executive.EXIT_SECONDS = 5 -- out of sight by then, wherever he got to
-- What each wind-up means, said on every screen while it lasts.
Executive.Windups = {
	volley = "BRIEFCASES  ·  KEEP MOVING",
	wave = "SHOCKWAVE  ·  JUMP AS THE RING REACHES YOU",
	dash = "HIS DASH  ·  STEP OUT OF THE LANE",
	spin = "CASES ALL ROUND  ·  STAND IN A GAP",
} :: { [string]: string }

-- Where a camera looks at time t (its sweep, back and forth): a direction on the level.
function Executive.cameraLook(c: { at: Vector3, sweep: number, period: number, phase: number }, t: number): Vector3
	local towardMiddle = if c.at.X > 0 then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)
	local swing = math.sin(((t / c.period) + c.phase) * 2 * math.pi) * math.rad(c.sweep)
	local cos, sin = math.cos(swing), math.sin(swing)
	-- (Turned about the vertical from facing across the hall.)
	return Vector3.new(towardMiddle.X * cos, 0, towardMiddle.X * sin)
end

-- Whether an eye looking along `look` sees a point, walls aside (the server then checks no wall
-- stands between): within `range` on the level, and within `angle` degrees either side of where
-- it looks. The same rule every screen draws on the floor.
function Executive.inSight(eye: Vector3, look: Vector3, range: number, angle: number, at: Vector3): boolean
	local to = Vector3.new(at.X - eye.X, 0, at.Z - eye.Z)
	if to.Magnitude > range or to.Magnitude < 1e-3 then
		return to.Magnitude < 1e-3
	end
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude < 1e-3 then
		return false
	end
	return flatLook.Unit:Dot(to.Unit) >= math.cos(math.rad(angle))
end

-- The edge of what an eye sees on the floor: `rays` points fanned across its angle, each as far
-- as `reach(direction)` allows (the first wall) and never past `range`.
function Executive.sightFan(look: Vector3, range: number, angle: number, rays: number, reach: (Vector3) -> number): { Vector3 }
	local flatLook = Vector3.new(look.X, 0, look.Z)
	local base = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.new(0, 0, -1)
	local out = {}
	for i = 0, rays - 1 do
		local a = math.rad(-angle + 2 * angle * i / math.max(1, rays - 1))
		local cos, sin = math.cos(a), math.sin(a)
		local dir = Vector3.new(base.X * cos - base.Z * sin, 0, base.X * sin + base.Z * cos)
		table.insert(out, dir * math.clamp(reach(dir), 0, range))
	end
	return out
end

-- A flat triangle drawn as two wedges: each wedge's CFrame and Size (a wedge's thickness along
-- its X). Degenerate triangles give nil.
function Executive.wedges(a: Vector3, b: Vector3, c: Vector3, thick: number): (CFrame?, Vector3?, CFrame?, Vector3?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local cross = ac:Cross(ab)
	if cross.Magnitude < 1e-6 or bc.Magnitude < 1e-6 then
		return nil, nil, nil, nil
	end
	local right = cross.Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	return CFrame.fromMatrix((a + b) / 2, right, up, back),
		Vector3.new(thick, height, math.abs(ab:Dot(back))),
		CFrame.fromMatrix((a + c) / 2, -right, up, -back),
		Vector3.new(thick, height, math.abs(ac:Dot(back)))
end

function Executive.inHall(p: Vector3): boolean
	local h = Executive.Hall
	return p.X >= h.minX and p.X <= h.maxX and p.Z >= h.minZ and p.Z <= h.maxZ
end

-- In the lift's lobby (safe: the alert never rises there).
function Executive.inLobby(p: Vector3): boolean
	local h, l = Executive.Hall, Executive.Lobby
	return p.X >= h.minX and p.X <= h.maxX and p.Z >= l.minZ and p.Z <= l.maxZ
end

-- Whether a point on the floor is inside a partition (a guest can't stand there).
function Executive.inPartition(p: Vector3, margin: number?): boolean
	local m = margin or 0
	for _, b in Executive.Partitions do
		if p.X >= b[1] - m and p.X <= b[3] + m and p.Z >= b[2] - m and p.Z <= b[4] + m then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------------------------------
-- (Build 90) Each run its own: the Suite's look, its guards' rounds, and a challenge
---------------------------------------------------------------------------------------------------
-- The look the Executive keeps the Suite in for a run (chosen as each run is made ready): its silk,
-- its runner and rugs, its light, the flowers about the place, and which way his guards walk their
-- rounds. Every look keeps the same walls, partitions, cameras, terminals and door: what decides
-- the run never moves.
export type Look = { id: string, name: string, line: string, silk: Color3, runner: Color3, rug: Color3, light: Color3, bright: number, flowers: Color3, reverse: boolean }
Executive.Looks = {
	{ id = "midnight", name = "Midnight Navy", line = "Navy silk and opal light: the Suite as he keeps it.", silk = rgb(24, 30, 54), runner = rgb(96, 16, 30), rug = rgb(18, 26, 54), light = rgb(255, 226, 184), bright = 1, flowers = rgb(246, 242, 232), reverse = false },
	{ id = "emerald", name = "The Emerald Study", line = "Green silk, brass lamps turned warm; his guards walk the other way round.", silk = rgb(18, 52, 38), runner = rgb(120, 84, 30), rug = rgb(16, 48, 34), light = rgb(255, 206, 140), bright = 0.9, flowers = rgb(250, 214, 120), reverse = true },
	{ id = "crimson", name = "Crimson Gala", line = "Oxblood silk and candlelight: he's entertaining tonight.", silk = rgb(70, 14, 24), runner = rgb(28, 22, 18), rug = rgb(60, 12, 22), light = rgb(255, 170, 120), bright = 0.82, flowers = rgb(200, 24, 48), reverse = false },
	{ id = "ice", name = "The Ice Penthouse", line = "Pale silk and cold white light; his guards walk the other way round.", silk = rgb(150, 160, 176), runner = rgb(40, 60, 90), rug = rgb(120, 134, 156), light = rgb(220, 236, 255), bright = 1.2, flowers = rgb(210, 230, 255), reverse = true },
} :: { Look }
Executive.lookById = {} :: { [string]: Look }
for _, l in Executive.Looks do
	Executive.lookById[l.id] = l
end

-- A run's challenge (one each run, chosen with its look, the same for everyone in it): done when
-- the Executive is beaten, it pays its Gilt to each guest who met it, once. Nothing bought counts
-- toward one: a guest revived by Chronos Defiance can't be Untouchable.
export type Challenge = { id: string, name: string, line: string, gilt: number }
Executive.Challenges = {
	{ id = "ghost", name = "Ghost", line = "Beat him without once being seen in the hallway.", gilt = 1500 },
	{ id = "steady", name = "Steady Hand", line = "Beat him without a wrong try of yours at the vault door.", gilt = 1000 },
	{ id = "untouchable", name = "Untouchable", line = "Beat him without losing any composure (no revive).", gilt = 2500 },
	{ id = "swift", name = "Swift Takeover", line = "Beat him within three minutes of the vault door opening.", gilt = 1500 },
} :: { Challenge }
Executive.challengeById = {} :: { [string]: Challenge }
for _, c in Executive.Challenges do
	Executive.challengeById[c.id] = c
end
Executive.SWIFT_SECONDS = 180

-- The season the Suite is dressed for: a holiday that's open (shared/HolidayGames), or high summer
-- (June to August) when none is. Nil otherwise.
-- (Build 94) With the house's own season (shared/Seasons, as server/Season publishes it, the owner
-- panel's choice included), the Suite is dressed all year round: a holiday that's open first, then
-- the house's season. Without it, as before.
Executive.HouseSeasons = {
	hallows = "halloween",
	harvest = "autumn",
	longtable = "thanksgiving",
	yule = "christmas",
	toast = "newYear",
	frost = "winter",
	rose = "valentine",
	emerald = "stPatrick",
	bloom = "spring",
	summer = "summer",
} :: { [string]: string }
function Executive.seasonOf(holiday: string?, month: number, house: string?): string?
	if holiday then
		return holiday
	end
	if house and Executive.HouseSeasons[house] then
		return Executive.HouseSeasons[house]
	end
	if month >= 6 and month <= 8 then
		return "summer"
	end
	return nil
end

function Executive.inReception(p: Vector3): boolean
	local r = Executive.Reception
	return p.X >= r.minX and p.X <= r.maxX and p.Z >= r.minZ and p.Z <= r.maxZ
end

function Executive.inOffice(p: Vector3): boolean
	local o = Executive.Office
	return p.X >= o.minX and p.X <= o.maxX and p.Z >= o.minZ and p.Z <= o.maxZ
end

return Executive

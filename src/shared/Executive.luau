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
Executive.Office = { minX = -32, maxX = 32, minZ = -20, maxZ = 62 }
Executive.Desk = Vector3.new(0, 0, 44)
Executive.Lift = Vector3.new(0, 0, 58) -- the way down, behind the desk
Executive.Safe = Vector3.new(26, 0, 50)
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
	{ id = "shield", name = "The Shield", line = "Shoot out the three generators behind his shield.", say = "You've come a long way up. Let's see what you're worth." },
	{ id = "detail", name = "The Security Detail", line = "His bodyguards. Stun all four.", say = "Gentlemen. Show our guests out." },
	{ id = "boss", name = "The Executive", line = "Watch for his wind-up: a ring is a shockwave (jump it), a lane is his dash (step aside), a raised hand is briefcases (move).", say = "If you want something done properly, you do it yourself." },
} :: { { id: string, name: string, line: string, say: string } }
Executive.FINALE_SAY = "A hostile takeover, then."
Executive.WON_SAY = "Well played. The lift is yours. For now."
-- What each wind-up means, said on every screen while it lasts.
Executive.Windups = {
	volley = "BRIEFCASES  ·  KEEP MOVING",
	wave = "SHOCKWAVE  ·  JUMP AS THE RING REACHES YOU",
	dash = "HIS DASH  ·  STEP OUT OF THE LANE",
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

function Executive.inOffice(p: Vector3): boolean
	local o = Executive.Office
	return p.X >= o.minX and p.X <= o.maxX and p.Z >= o.minZ and p.Z <= o.maxZ
end

return Executive

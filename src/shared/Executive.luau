--!strict
-- The Executive Suite: by invitation only (shared by the server, which builds and runs it, and
-- every screen). Positions are from its origin (shared/Attractions.origin("executive")); the way
-- runs along +Z: the lift up, the security hallway, the code door, the Executive's Office.
--
--   The hallway       two cameras sweeping, two guards on their rounds: seen, the alert rises;
--                     full, security shows you out (the invitation spent). Four terminals along
--                     the walls each give you one digit of the door's code (made new each run).
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
	{ id = "scanner", name = "A Scanner", line = "Shows where every code terminal is, and when a guard is looking your way.", price = 3000, glyph = "📡" },
	{ id = "vest", name = "An Armoured Vest", line = "Half as much composure again in the Office.", price = 5000, glyph = "🛡️" },
} :: { Gear }
Executive.byGear = {} :: { [string]: Gear }
for _, g in Executive.Gear do
	Executive.byGear[g.id] = g
end

-- The places (from the origin).
Executive.Arrival = Vector3.new(0, 0, -142) -- out of the lift, facing +Z
Executive.Hall = { minX = -10, maxX = 10, minZ = -148, maxZ = -22 }
Executive.Door = { z = -22, minX = -4, maxX = 4 } -- the code door across the hall's end
Executive.Office = { minX = -32, maxX = 32, minZ = -20, maxZ = 62 }
Executive.Desk = Vector3.new(0, 0, 44)
Executive.Lift = Vector3.new(0, 0, 58) -- the way down, behind the desk
Executive.Safe = Vector3.new(26, 0, 50)
Executive.HEIGHT = 16

-- The hallway's terminals (each gives one digit, in order), cameras and guards' rounds.
Executive.Terminals = {
	Vector3.new(-9, 0, -120),
	Vector3.new(9, 0, -96),
	Vector3.new(-9, 0, -70),
	Vector3.new(9, 0, -44),
} :: { Vector3 }
Executive.Cameras = {
	{ at = Vector3.new(9.5, 11, -108), sweep = 70, period = 6, phase = 0 },
	{ at = Vector3.new(-9.5, 11, -58), sweep = 70, period = 7, phase = 0.5 },
} :: { { at: Vector3, sweep: number, period: number, phase: number } }
Executive.GuardRounds = {
	{ Vector3.new(-5, 0, -132), Vector3.new(-5, 0, -86) },
	{ Vector3.new(5, 0, -80), Vector3.new(5, 0, -30) },
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

function Executive.inHall(p: Vector3): boolean
	local h = Executive.Hall
	return p.X >= h.minX and p.X <= h.maxX and p.Z >= h.minZ and p.Z <= h.maxZ
end

function Executive.inOffice(p: Vector3): boolean
	local o = Executive.Office
	return p.X >= o.minX and p.X <= o.maxX and p.Z >= o.minZ and p.Z <= o.maxZ
end

return Executive

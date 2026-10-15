--!strict
-- The Grand Prix: the circuit laid on the street in front of the house, the cars, and how they
-- drive. Pure numbers and geometry, shared by the server (who keeps the race), every screen (the
-- driver's car, the house's chauffeurs) and the tests.
--
-- The circuit is a stadium: two straights along the street joined by two hairpins. It is driven
-- east along the near straight (past the front door, where the start line is), round the east
-- hairpin, west along the far straight, round the west hairpin and home. Distance round it is
-- `s`, from 0 at the start line to `length()`; a lap is four sectors, which must come in order.

local GrandPrix = {}

-- World units (the house is built, then grown by Layout.SCALE; this is laid at the grown size).
GrandPrix.TRACK = {
	centre = Vector3.new(0, 0, -130), -- the middle of the infield, on the road's surface
	half = 118, -- half the length of each straight
	radius = 52, -- the hairpins' radius, to the middle of the road
	width = 26, -- the road's width
	y = 0.06, -- the circuit's surface, just above the street's
}

-- The cars: all drive alike (a race is won by the driver), each its own colour and name.
GrandPrix.CARS = {
	{ id = "phantom", name = "Noir Phantom", paint = Color3.fromRGB(14, 14, 18), trim = Color3.fromRGB(212, 175, 92), glass = Color3.fromRGB(20, 22, 28), style = "saloon" },
	{ id = "aurelia", name = "Aurelia GT", paint = Color3.fromRGB(196, 158, 82), trim = Color3.fromRGB(240, 232, 214), glass = Color3.fromRGB(24, 22, 20), style = "tourer" },
	{ id = "vespera", name = "Vespera Hyper", paint = Color3.fromRGB(18, 92, 70), trim = Color3.fromRGB(212, 175, 92), glass = Color3.fromRGB(14, 20, 18), style = "hyper" },
	{ id = "rosso", name = "Rosso Regent", paint = Color3.fromRGB(150, 18, 30), trim = Color3.fromRGB(226, 226, 230), glass = Color3.fromRGB(20, 14, 16), style = "tourer" },
	{ id = "bianca", name = "Bianca Veloce", paint = Color3.fromRGB(236, 234, 228), trim = Color3.fromRGB(30, 30, 34), glass = Color3.fromRGB(18, 20, 26), style = "hyper" },
	{ id = "sovereign", name = "Midnight Sovereign", paint = Color3.fromRGB(20, 34, 82), trim = Color3.fromRGB(212, 175, 92), glass = Color3.fromRGB(14, 16, 24), style = "saloon" },
}
-- The Private Garage (a Robux purchase, ProductConfig grandPrixGarage): two more cars, kept for
-- its holders, in their own bays. They drive exactly like every other car: a look, not an edge.
GrandPrix.GARAGE = {
	{ id = "gilded", name = "Gilded Phantom", paint = Color3.fromRGB(214, 182, 112), trim = Color3.fromRGB(24, 20, 16), glass = Color3.fromRGB(22, 18, 14), style = "saloon", private = true },
	{ id = "imperial", name = "Imperial Violet", paint = Color3.fromRGB(62, 30, 96), trim = Color3.fromRGB(222, 188, 112), glass = Color3.fromRGB(16, 12, 22), style = "hyper", private = true },
}
GrandPrix.byId = {} :: { [string]: { [string]: any } }
for _, c in GrandPrix.CARS do
	GrandPrix.byId[c.id] = c
end
for _, c in GrandPrix.GARAGE do
	GrandPrix.byId[c.id] = c
end

-- The height of a car's centre (its chassis, 1.6 tall, resting on the road).
GrandPrix.RIDE = 0.82

-- How every car drives (studs, seconds).
GrandPrix.CAR = {
	top = 92, -- top speed
	reverse = 22, -- top speed backwards
	accel = 34, -- pulling away
	brake = 75, -- the brakes (throttle against the way you're going)
	coast = 12, -- slowing with no throttle
	turn = 2.1, -- the most it turns (radians a second), from turnAt and up
	turnAt = 22, -- below this speed it turns less (a car parked doesn't spin on the spot)
	grip = 66, -- the most sideways pull the tyres hold: faster than sqrt(grip × r) a bend of radius r runs wide
}

-- The house's chauffeurs, who fill the grid: their pace on the straights and in the hairpins, and
-- how hard each of them drives (a good driver beats the quickest).
GrandPrix.AI = {
	straight = 80,
	hairpin = 52,
	paces = { 0.93, 0.88, 0.82, 0.78, 0.74 },
	names = { "Monsieur Laurent", "Madame Celeste", "Signor Bruno", "Lady Margaux", "Herr Anton" },
}

function GrandPrix.length(): number
	local t = GrandPrix.TRACK
	return 4 * t.half + 2 * math.pi * t.radius
end

-- The four sectors of a lap: 0, 1, 2, 3.
function GrandPrix.sector(s: number): number
	local L = GrandPrix.length()
	local k = (s % L) / L
	return math.clamp(math.floor(k * 4), 0, 3)
end

-- The point `s` round the circuit (on its surface) and the way the road runs there.
function GrandPrix.point(s: number): (Vector3, Vector3)
	local t = GrandPrix.TRACK
	local L = GrandPrix.length()
	local h, R, c = t.half, t.radius, t.centre
	local arc = math.pi * R
	s = s % L
	local y = t.y
	if s < h then
		return Vector3.new(c.X + s, y, c.Z + R), Vector3.new(1, 0, 0)
	end
	s -= h
	if s < arc then
		local th = s / R
		return Vector3.new(c.X + h + R * math.sin(th), y, c.Z + R * math.cos(th)), Vector3.new(math.cos(th), 0, -math.sin(th))
	end
	s -= arc
	if s < 2 * h then
		return Vector3.new(c.X + h - s, y, c.Z - R), Vector3.new(-1, 0, 0)
	end
	s -= 2 * h
	if s < arc then
		local th = s / R
		return Vector3.new(c.X - h - R * math.sin(th), y, c.Z - R * math.cos(th)), Vector3.new(-math.cos(th), 0, math.sin(th))
	end
	s -= arc
	return Vector3.new(c.X - h + s, y, c.Z + R), Vector3.new(1, 0, 0)
end

-- Where a position is on the circuit: the distance round (`s`) of the nearest point of the
-- road's middle, and how far from that middle it is.
function GrandPrix.progress(pos: Vector3): (number, number)
	local t = GrandPrix.TRACK
	local L = GrandPrix.length()
	local h, R, c = t.half, t.radius, t.centre
	local dx, dz = pos.X - c.X, pos.Z - c.Z
	if dx > h then
		local vx, vz = dx - h, dz
		local th = math.atan2(vx, vz) -- 0 on the near side, pi on the far
		if th < 0 then
			th = if vz >= 0 then 0 else math.pi
		end
		return h + R * th, math.abs(math.sqrt(vx * vx + vz * vz) - R)
	elseif dx < -h then
		local vx, vz = dx + h, dz
		local th = math.atan2(-vx, -vz)
		if th < 0 then
			th = if vz <= 0 then 0 else math.pi
		end
		return 3 * h + math.pi * R + R * th, math.abs(math.sqrt(vx * vx + vz * vz) - R)
	end
	if dz >= 0 then
		-- The near straight (the start line at dx = 0).
		local s = if dx >= 0 then dx else L + dx
		return s, math.abs(dz - R)
	end
	return h + math.pi * R + (h - dx), math.abs(dz + R)
end

-- The car, one step on: its speed (forwards, studs a second) and how fast it turns (radians a
-- second, positive to the left), from the throttle and steering (-1 to 1 each).
function GrandPrix.step(speed: number, throttle: number, steer: number, dt: number): (number, number)
	local car = GrandPrix.CAR
	throttle = math.clamp(throttle, -1, 1)
	steer = math.clamp(steer, -1, 1)
	if throttle > 0 then
		if speed < 0 then
			speed = math.min(0, speed + car.brake * throttle * dt)
		else
			speed = math.min(car.top, speed + car.accel * throttle * dt * (1 - 0.55 * speed / car.top))
		end
	elseif throttle < 0 then
		if speed > 0 then
			speed = math.max(0, speed + car.brake * throttle * dt)
		else
			speed = math.max(-car.reverse, speed + car.accel * 0.6 * throttle * dt)
		end
	else
		if speed > 0 then
			speed = math.max(0, speed - car.coast * dt)
		elseif speed < 0 then
			speed = math.min(0, speed + car.coast * dt)
		end
	end
	local v = math.abs(speed)
	local turning = car.turn * math.clamp(v / car.turnAt, 0, 1)
	-- The tyres hold only so much: fast into a bend, the car runs wide.
	if v > 1 then
		turning = math.min(turning, car.grip / v)
	end
	local yaw = -steer * turning * (if speed < 0 then -1 else 1)
	return speed, yaw
end

-- The fastest a car can truly go (for the server's check), with a margin for lag.
function GrandPrix.limit(): number
	return GrandPrix.CAR.top * 1.3
end

-- The quickest lap anyone could drive (every metre at top speed): faster than this is impossible.
function GrandPrix.quickestLap(): number
	return GrandPrix.length() / GrandPrix.CAR.top
end

-- A chauffeur's run: how far round (in total, over every lap) they are `t` seconds after the
-- start, at their `pace`. Deterministic, so every screen and the server agree.
local function segments(): { { len: number, fast: boolean } }
	local t = GrandPrix.TRACK
	local arc = math.pi * t.radius
	return {
		{ len = t.half, fast = true },
		{ len = arc, fast = false },
		{ len = 2 * t.half, fast = true },
		{ len = arc, fast = false },
		{ len = t.half, fast = true },
	}
end

function GrandPrix.lapTime(pace: number): number
	local ai = GrandPrix.AI
	local total = 0
	for _, seg in segments() do
		total += seg.len / ((if seg.fast then ai.straight else ai.hairpin) * pace)
	end
	return total
end

function GrandPrix.aiDistance(t: number, pace: number, laps: number): number
	if t <= 0 then
		return 0
	end
	local ai = GrandPrix.AI
	local L = GrandPrix.length()
	local lap = GrandPrix.lapTime(pace)
	local whole = math.floor(t / lap)
	if whole >= laps then
		return laps * L
	end
	local rest = t - whole * lap
	local d = whole * L
	for _, seg in segments() do
		local v = (if seg.fast then ai.straight else ai.hairpin) * pace
		local need = seg.len / v
		if rest <= need then
			return d + rest * v
		end
		rest -= need
		d += seg.len
	end
	return d
end

-- How long a chauffeur at `pace` takes to cover `distance` (from a standing start at the line).
function GrandPrix.aiTimeFor(distance: number, pace: number): number
	local ai = GrandPrix.AI
	local L = GrandPrix.length()
	local whole = math.floor(distance / L)
	local t = whole * GrandPrix.lapTime(pace)
	local rest = distance - whole * L
	for _, seg in segments() do
		local v = (if seg.fast then ai.straight else ai.hairpin) * pace
		if rest <= seg.len then
			return t + rest / v
		end
		t += seg.len / v
		rest -= seg.len
	end
	return t
end

function GrandPrix.aiFinish(pace: number, laps: number): number
	return GrandPrix.lapTime(pace) * laps
end

-- Grid slot `i` (1 is pole): behind the start line, two abreast.
function GrandPrix.gridSlot(i: number): CFrame
	local t = GrandPrix.TRACK
	local row = math.floor((i - 1) / 2)
	local side = if (i - 1) % 2 == 0 then -1 else 1
	local x = t.centre.X - 10 - row * 15
	local z = t.centre.Z + t.radius + side * 5.5
	return CFrame.lookAt(Vector3.new(x, GrandPrix.RIDE, z), Vector3.new(x + 10, GrandPrix.RIDE, z))
end

-- Where the cars wait between drives: along the kerb in front of the house, nose east.
function GrandPrix.bay(i: number): CFrame
	local t = GrandPrix.TRACK
	local n = #GrandPrix.CARS
	local x = (i - (n + 1) / 2) * 17
	local z = t.centre.Z + t.radius + t.width / 2 + 6.2
	return CFrame.lookAt(Vector3.new(x, GrandPrix.RIDE, z), Vector3.new(x + 10, GrandPrix.RIDE, z))
end

-- The Private Garage's bays: along the same kerb, west of the others, a little apart.
function GrandPrix.privateBay(i: number): CFrame
	local first = GrandPrix.bay(1).Position
	local x = first.X - 4 - 17 * i
	return CFrame.lookAt(Vector3.new(x, GrandPrix.RIDE, first.Z), Vector3.new(x + 10, GrandPrix.RIDE, first.Z))
end

return GrandPrix

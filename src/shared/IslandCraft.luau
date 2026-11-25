--!strict
-- (Build 104) Luxury Island's rides: the jet skis off the South Beach, the Day Yacht at the
-- marina, and the helicopter on the Grand Villa's pad. Pure rules, shared by the server (which
-- spawns every ride, sits its rider, and checks each one is where a ride of its kind can be) and
-- the rider's screen (which steers it: the same numbers, so what the server allows is what the
-- screen does). Places are from the island's origin, y = 0 at the sea.
--
--   The jet ski     yours for good, for Gilt or for Robux (the price shown is the price paid);
--                   one of your own at a time, on the water only: the shore stops it
--   The Day Yacht   every island guest's, free: one captain at a time, anyone may stand aboard
--   The helicopter  yours for good, for a great deal more Gilt or for Robux; one of your own at a
--                   time, anywhere over the island up to its ceiling
--
-- Nothing here is chance, nothing is timed against the guest, and nothing a ride does pays: the
-- rides are for the fun of it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage.Shared.Island)
local Ground = require(ReplicatedStorage.Shared.IslandGround)

local Craft = {}

export type Kind = {
	id: string,
	name: string,
	line: string,
	water: boolean, -- on the sea (else it flies)
	top: number, -- studs a second, flat out
	reverse: number,
	accel: number,
	brake: number,
	drag: number, -- slowing with nothing pressed
	turn: number, -- radians a second at full lock, once at speed
	turnAt: number, -- the speed at which it turns at its best
	ride: number, -- (water) its chassis's centre above the sea
	climb: number?, -- (air) studs a second up or down
	ceiling: number?, -- (air) the highest it goes (local y)
	gilt: number?, -- yours for good for this much Gilt
	product: string?, -- ...or for Robux (ProductConfig key)
	free: boolean?, -- every island guest's, no purchase
	size: Vector3, -- its chassis
}

Craft.KINDS = {
	jetski = {
		id = "jetski",
		name = "Jet Ski",
		line = "Yours for good: ride the lagoon and round the island, as fast as the water lets you.",
		water = true,
		top = 70,
		reverse = 14,
		accel = 32,
		brake = 60,
		drag = 12,
		turn = 2.2,
		turnAt = 18,
		ride = 0.9,
		gilt = 60000,
		product = "islandJetSki",
		size = Vector3.new(3.4, 1.6, 9),
	},
	yacht = {
		id = "yacht",
		name = "The Day Yacht",
		line = "Every island guest's: take the helm and cruise, friends aboard.",
		water = true,
		top = 30,
		reverse = 8,
		accel = 7,
		brake = 12,
		drag = 3,
		turn = 0.5,
		turnAt = 10,
		ride = 1.6,
		free = true,
		size = Vector3.new(14, 3, 46),
	},
	heli = {
		id = "heli",
		name = "Helicopter",
		line = "Yours for good: lift off from the Grand Villa's pad and fly the whole island.",
		water = false,
		top = 85,
		reverse = 20,
		accel = 24,
		brake = 36,
		drag = 10,
		turn = 1.4,
		turnAt = 0,
		ride = 0,
		climb = 28,
		ceiling = 230,
		gilt = 750000,
		product = "islandHelicopter",
		size = Vector3.new(5, 4, 12),
	},
} :: { [string]: Kind }
Craft.ORDER = { "jetski", "yacht", "heli" }

-- Where each ride is had: the prompt's place (`ask`), how near to it a guest must stand (the
-- server's own check, a little more than the prompt reaches), and where a ride comes out
-- (`launch`: each its own spot, the first one free used; facing the way it sets off).
local SEA = Plan.SEA
Craft.REACH = 16
Craft.Places = {
	-- The Jet Ski Hire: a kiosk on the South Beach below the loungers; the skis come out on the
	-- water just off the sand, facing the lagoon.
	jetski = {
		ask = Vector3.new(100, 1.2, 124),
		launch = {
			CFrame.lookAt(Vector3.new(96, SEA, 150), Vector3.new(96, SEA, 200)),
			CFrame.lookAt(Vector3.new(108, SEA, 152), Vector3.new(108, SEA, 200)),
			CFrame.lookAt(Vector3.new(84, SEA, 154), Vector3.new(84, SEA, 200)),
			CFrame.lookAt(Vector3.new(120, SEA, 154), Vector3.new(120, SEA, 200)),
			CFrame.lookAt(Vector3.new(102, SEA, 164), Vector3.new(102, SEA, 210)),
			CFrame.lookAt(Vector3.new(90, SEA, 166), Vector3.new(90, SEA, 210)),
		},
	},
	-- The Day Yacht's berth: the marina pier's seaward end; its helm amidships.
	yacht = {
		ask = Vector3.new(-312, Plan.GROUND, 80),
		launch = { CFrame.lookAt(Vector3.new(-318, SEA, 48), Vector3.new(-418, SEA, 48)) },
	},
	-- The helicopter: the Grand Villa's pad first, then two spots on the airstrip.
	heli = {
		ask = Vector3.new(119, 31.3, -6),
		launch = {
			CFrame.new(Vector3.new(119, 31.4, -6)) * CFrame.Angles(0, math.rad(-120), 0),
			CFrame.lookAt(Vector3.new(20, Plan.GROUND + 0.7, -176), Vector3.new(-80, Plan.GROUND + 0.7, -176)),
			CFrame.lookAt(Vector3.new(60, Plan.GROUND + 0.7, -176), Vector3.new(-40, Plan.GROUND + 0.7, -176)),
		},
	},
} :: { [string]: { ask: Vector3, launch: { CFrame } } }

-- (Leave a ride: get up from it, jump. An empty ride of a guest's own waits this long, then is put
-- away; the Day Yacht with no captain goes back to its berth after RETURN_SECONDS.)
Craft.IDLE_SECONDS = 15
Craft.RETURN_SECONDS = 60

-- The island's waters: how deep the sea must be under a ride on it (the shore and the reef's
-- shoals stop it), and the unseen edge it stays inside (shared/Attractions BOUNDS, less a margin).
Craft.DEPTH = 2.2
Craft.EDGE = { min = Vector3.new(-500, -40, -400), max = Vector3.new(400, 250, 420) }

function Craft.inside(p: Vector3): boolean
	local e = Craft.EDGE
	return p.X >= e.min.X and p.X <= e.max.X and p.Z >= e.min.Z and p.Z <= e.max.Z and p.Y >= e.min.Y and p.Y <= e.max.Y
end

-- Whether the sea at (x, z) is deep enough for a ride on it (local).
function Craft.deep(x: number, z: number): boolean
	return Ground.groundAt(x, z) <= SEA - Craft.DEPTH
end

-- Whether a ride of `kind` can be at `p` (local): on deep water near the surface, or (flying)
-- inside the edge, above the ground and below the ceiling. The server's check of every ride.
function Craft.allowedAt(kind: Kind, p: Vector3): boolean
	if not Craft.inside(p) then
		return false
	end
	if kind.water then
		-- (A little slack across the line its screen keeps to: the server sees a moment late.)
		return Ground.groundAt(p.X, p.Z) <= SEA - Craft.DEPTH + 0.8 and math.abs(p.Y - (SEA + kind.ride)) <= 6
	end
	return p.Y <= (kind.ceiling or 200) + 6 and p.Y >= Ground.groundAt(p.X, p.Z) - 4
end

-- One beat of the throttle and the wheel: the new speed, and how fast it turns (radians a
-- second, + to the left). Rides turn best at `turnAt` and less when slow (a helicopter turns
-- at any speed, in place).
function Craft.step(kind: Kind, speed: number, throttle: number, steer: number, dt: number): (number, number)
	throttle = math.clamp(throttle, -1, 1)
	steer = math.clamp(steer, -1, 1)
	if throttle > 0 then
		if speed < 0 then
			speed = math.min(0, speed + kind.brake * dt)
		else
			speed = math.min(kind.top * throttle, speed + kind.accel * dt)
			if speed > kind.top * throttle then
				speed = math.max(kind.top * throttle, speed - kind.drag * dt)
			end
		end
	elseif throttle < 0 then
		if speed > 0 then
			speed = math.max(0, speed - kind.brake * dt)
		else
			speed = math.max(-kind.reverse, speed - kind.accel * 0.5 * dt)
		end
	else
		if speed > 0 then
			speed = math.max(0, speed - kind.drag * dt)
		else
			speed = math.min(0, speed + kind.drag * dt)
		end
	end
	local grip = if kind.turnAt <= 0 then 1 else math.clamp(math.abs(speed) / kind.turnAt, 0, 1)
	local sign = if speed < 0 then -1 else 1
	return speed, -steer * kind.turn * grip * sign
end

-- (Flying) how fast it climbs or sinks for `lift` (-1 to 1) at `y` (local): it eases off near
-- the ceiling, and never sinks into the ground under it.
function Craft.vertical(kind: Kind, y: number, ground: number, lift: number): number
	local climb = kind.climb or 0
	lift = math.clamp(lift, -1, 1)
	local v = lift * climb
	local ceiling = kind.ceiling or 200
	if v > 0 and y > ceiling - 10 then
		v *= math.clamp((ceiling - y) / 10, 0, 1)
	end
	if v < 0 and y < ground + 6 then
		v *= math.clamp((y - ground - 1) / 5, 0, 1)
	end
	return v
end

-- Where a ride of `kind` would go this beat, kept to where it may be: on water, a move onto the
-- shore or the shoals (or out past the edge) is stopped short (and its speed with it).
function Craft.keep(kind: Kind, from: Vector3, to: Vector3): (Vector3, boolean)
	if kind.water then
		if Craft.inside(to) and Craft.deep(to.X, to.Z) then
			return to, false
		end
		return Vector3.new(from.X, to.Y, from.Z), true
	end
	if not Craft.inside(to) then
		return Vector3.new(from.X, to.Y, from.Z), true
	end
	return to, false
end

-- The price of a ride for a guest's screen and the server alike (nil: free).
function Craft.price(id: string): (number?, string?)
	local k = Craft.KINDS[id]
	if not k or k.free then
		return nil, nil
	end
	return k.gilt, k.product
end

return Craft

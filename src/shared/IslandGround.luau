--!strict
-- (Build 104) Luxury Island's ground, as a plan: the lowland's circles of sand, the lawns, the two
-- beaches' slopes, the lagoon and the hills, and the ground's height anywhere on it. Shared by
-- the server (which builds the island's terrain and parts from it, and checks every ride against
-- it) and every screen (whose ride stays on the water where it says there's water). It was the
-- builder's own until the island had rides that need to know where the shore is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage.Shared.Island)

local Ground = {}
local G = Plan.GROUND

Ground.LAND = {
	{ -30, -60, 175 }, { 110, -40, 124 }, { -150, 20, 112 }, { 10, 40, 92 }, { -60, -150, 120 }, { 40, -150, 110 },
	{ -170, -170, 70 },
}
local LAND = Ground.LAND
local LAWNS = { { -30, -60, 150 }, { 110, -40, 100 }, { -150, 20, 88 }, { 10, 30, 64 } }
-- The South Beach: from the lawns' edge (z 94, at G) down to the lagoon's floor (z 170, 6 below
-- the sea), x -160 to 140.
local BEACH = { x0 = -160, x1 = 140, z0 = 94, z1 = 170 }
local function sandAt(z: number): number
	return G - 12 * math.clamp((z - BEACH.z0) / (BEACH.z1 - BEACH.z0), 0, 1)
end
-- The Grand Villa's beach, beside its pier: from its Quay's edge down into the sea.
local BEACH2 = { x0 = 140, x1 = 188, z0 = 94, z1 = 130 }
local function sand2At(z: number): number
	return G - 12 * math.clamp((z - BEACH2.z0) / (BEACH2.z1 - BEACH2.z0), 0, 1)
end
-- The lagoon: white sand 6 below the sea inside the reef, south of the beach.
local LAGOON = { { -90, 210, 80 }, { -10, 220, 90 }, { 70, 210, 80 } }
local LAGOON_FLOOR = -6

-- The hills, smooth: rings of ground narrowing as they climb, a little steeper toward the top.
type Hill = { x: number, z: number, rings: { { number } } } -- each ring: { radius, its top }
local function hill(x: number, z: number, top: number, rBase: number, rTop: number, power: number): Hill
	local rings = {}
	local h = G + 2
	while h <= top + 1e-6 do
		local f = ((top - h) / (top - G)) ^ power
		table.insert(rings, { rTop + (rBase - rTop) * f, h })
		h += 2
	end
	return { x = x, z = z, rings = rings }
end
local HILLS: { Hill } = {
	hill(168, -78, 28, 44, 20, 1.2), -- the green hill behind the Grand Villa's terraces
	hill(-120, 40, 34, 56, 21, 1.25), -- the summit (the Lookout's drum on the top)
	hill(-100, 32, 31, 48, 5, 1), -- the ridge the Lookout's stair climbs, from the gardens
}

-- The ground's height at (x, z) (from the island's origin): for setting things on it.
local function groundAt(x: number, z: number): number
	local y = -8
	for _, c in LAND do
		local d = math.sqrt((x - c[1]) ^ 2 + (z - c[2]) ^ 2)
		if d <= c[3] then
			y = math.max(y, G)
		elseif d <= c[3] + 10 then
			y = math.max(y, -4 + math.sqrt(math.max(0, 100 - (d - c[3]) ^ 2)))
		end
	end
	if x >= BEACH.x0 and x <= BEACH.x1 and z >= BEACH.z0 then
		y = sandAt(z)
	elseif x >= BEACH2.x0 and x <= BEACH2.x1 and z >= BEACH2.z0 then
		y = sand2At(z)
	end
	for _, h in HILLS do
		local d = math.sqrt((x - h.x) ^ 2 + (z - h.z) ^ 2)
		for _, ring in h.rings do
			if d <= ring[1] then
				y = math.max(y, ring[2])
			end
		end
	end
	return y
end

Ground.G = G
Ground.LAWNS = LAWNS
Ground.BEACH = BEACH
Ground.BEACH2 = BEACH2
Ground.LAGOON = LAGOON
Ground.LAGOON_FLOOR = LAGOON_FLOOR
Ground.HILLS = HILLS
Ground.sandAt = sandAt
Ground.sand2At = sand2At
Ground.groundAt = groundAt

return Ground

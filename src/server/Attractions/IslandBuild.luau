--!strict
-- Luxury Island, built once when the house opens (shared/Island has the plan): a private island
-- at golden hour. The land and the sea are Roblox terrain where the place has it: pale sand that
-- shelves gently into turquoise shallows, lawns, two smooth green hills (the Grand Villa's
-- headland and the Sunset Lookout's summit, with the ridge its stair climbs), warm rock on the sea
-- cliffs, a lagoon of white sand inside a reef of shoals and a few rocks; with no terrain (the
-- tests), plain parts stand in. On it:
--   the airstrip and your jet (its red carpet and velvet ropes), the Jet Gallery
--   the Grand Villa on its stone podium: white volumes under thin roofs edged in gold, black steel
--     glass, a lit great room, a true infinity pool spilling over its western edge to the sunset,
--     the Sky Lounge on the roof
--   the four overwater villas on their pier (thatch, teak, a plunge pool each, rope rails)
--   the South Beach: cabanas, loungers on teak decks, the Coral Club with its terrace, its fire
--     lounge and strings of lights, tiki torches along the sand
--   the gardens and their fountain, limestone paths with black-and-gold lamps
--   the Sunset Lookout on its stone drum, its grand stair up the ridge, lamps, a telescope, a flag
--   the marina's yachts, palms that look like palms, and the postcard frames
-- Nothing here lights a light of its own: the glow is Neon, and each guest's screen lights the
-- island in its own chosen light (World/IslandView, World/IslandLife), by these tags:
--   IslandTorch    a torch's flame (firelight, flicker)
--   IslandLantern  lanterns, lamps and the bulbs of the string lights
--   IslandGlow     the lit rooms (a warm light inside)
--   IslandPool     the pools' underwater lights
--   IslandFoam     the surf along the beach (it breathes)
--   IslandFlag     flags (they stir in the breeze)
--   IslandBlink    the jet's navigation lights

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Plan = require(ReplicatedStorage.Shared.Island)
local Tracks = require(ReplicatedStorage.Shared.Tracks)
local Kit = require(script.Parent.Parent.World.Kit)

local IslandBuild = {}

local L = Kit.Looks
local rgb = Color3.fromRGB
local G = Plan.GROUND
local GOLD = rgb(232, 182, 72)

local function look(colour: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Kit.Look
	return { color = colour, material = material, reflectance = reflectance, transparency = transparency }
end
-- The ground.
local SAND = look(rgb(236, 220, 186), Enum.Material.Sand)
local GRASS = look(rgb(98, 150, 70), Enum.Material.Grass)
local ROCK = look(rgb(140, 126, 110), Enum.Material.Slate)
local SEA = look(rgb(30, 150, 170), Enum.Material.Glass, 0.3, 0.3)
-- The house's island palette: white render and pale stone, teak, black steel and gold.
local WHITE = look(rgb(244, 241, 234), Enum.Material.SmoothPlastic, 0.02)
local PLASTER = look(rgb(240, 232, 216), Enum.Material.Plaster)
local STONE = look(rgb(228, 216, 192), Enum.Material.Limestone)
local PAVER = look(rgb(238, 230, 212), Enum.Material.Limestone)
local MARBLE = look(rgb(238, 233, 222), Enum.Material.Marble, 0.1)
local TEAK = look(rgb(138, 92, 54), Enum.Material.Wood)
local DECK = look(rgb(162, 114, 72), Enum.Material.WoodPlanks)
local THATCH = look(rgb(196, 160, 104), Enum.Material.Grass)
local BLACK = L.blackLacquer
local GILT = look(GOLD, Enum.Material.Metal, 0.25)
local GLASS = look(rgb(176, 206, 214), Enum.Material.Glass, 0.2, 0.6)
local DARK_GLASS = look(rgb(22, 30, 40), Enum.Material.Glass, 0.3, 0.1)
local ROOM_GLOW = look(rgb(255, 200, 136), Enum.Material.Neon, nil, 0.3)
local COVE = look(rgb(255, 214, 160), Enum.Material.Neon, nil, 0.45)
local POOL_TILE = look(rgb(24, 96, 116), Enum.Material.SmoothPlastic, 0.05)
local POOL_EDGE = look(rgb(18, 62, 74), Enum.Material.SmoothPlastic, 0.1)
local POOL_WATER = look(rgb(52, 176, 190), Enum.Material.Glass, 0.15, 0.32)
local POOL_LIGHT = look(rgb(160, 236, 255), Enum.Material.Neon, nil, 0.1)
-- Palms, flowers, fire.
local TRUNK = look(rgb(150, 124, 96), Enum.Material.Wood)
local TRUNK_RING = look(rgb(112, 90, 66), Enum.Material.Wood)
local CROWN = look(rgb(110, 112, 58), Enum.Material.SmoothPlastic)
local COCONUT = look(rgb(96, 70, 40), Enum.Material.SmoothPlastic)
local LEAF = look(rgb(52, 112, 52), Enum.Material.SmoothPlastic)
local BAMBOO = look(rgb(176, 140, 88), Enum.Material.Wood)
local FLAME = look(rgb(255, 150, 54), Enum.Material.Neon, nil, 0.1)
local LANTERN = look(rgb(255, 214, 150), Enum.Material.Neon, nil, 0.15)
local BULB = look(rgb(255, 222, 160), Enum.Material.Neon)
-- The airstrip, the yachts.
local CANVAS = look(rgb(244, 238, 226), Enum.Material.Fabric)
local NAVY_CANVAS = look(rgb(28, 52, 92), Enum.Material.Fabric)
local RUNWAY_PAINT = look(rgb(240, 240, 236), Enum.Material.SmoothPlastic)
local EDGE_LIGHT = look(rgb(255, 226, 170), Enum.Material.Neon)
local HULL = look(rgb(246, 246, 244), Enum.Material.SmoothPlastic, 0.05)
local NAVY = look(rgb(24, 32, 60), Enum.Material.SmoothPlastic, 0.05)
local CHROME = look(rgb(200, 204, 210), Enum.Material.Metal, 0.35)
local VELVET = rgb(140, 16, 30)
local TRIM = { collide = false, query = false, shadow = false }
local SOFT = { collide = false, query = false }
local UNSEEN = { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }

local function tag(i: Instance, name: string)
	CollectionService:AddTag(i, name)
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, lk: Kit.Look, opts: { [string]: any }?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = lk.color
	w.Material = lk.material
	w.Reflectance = lk.reflectance or 0
	w.Transparency = lk.transparency or 0
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.CanTouch = false
	if opts then
		if opts.collide == false then
			w.CanCollide = false
		end
		if opts.query == false then
			w.CanQuery = false
		end
		if opts.shadow == false then
			w.CastShadow = false
		end
	end
	w.Parent = parent
	return w
end

-- A cylinder from `a` to `b` (its length along the line between them).
local function rod(parent: Instance, name: string, a: Vector3, b: Vector3, diameter: number, lk: Kit.Look, opts: { [string]: any }?): Part
	local mid = (a + b) / 2
	return Kit.cylinder(parent, name, (b - a).Magnitude, diameter, CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0), lk, opts)
end

-- A flat disc (a cylinder standing on end): its top at `top`.
local function disc(parent: Instance, name: string, diameter: number, thick: number, centre: Vector3, top: number, lk: Kit.Look, opts: { [string]: any }?): Part
	return Kit.cylinder(parent, name, thick, diameter, CFrame.new(centre.X, top - thick / 2, centre.Z) * CFrame.Angles(0, 0, math.rad(90)), lk, opts)
end

-- A block between two heights over a rectangle (x0..x1, z0..z1), from the island's origin.
local function slab(parent: Instance, name: string, o: Vector3, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, lk: Kit.Look, opts: { [string]: any }?): Part
	return Kit.part(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new(o + Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)), lk, opts)
end

---------------------------------------------------------------------------------------------------
-- Wires: a Beam between two attachments, hanging in a curve (string lights, ropes). The bulbs on
-- a string sit on the same curve the beam draws.
---------------------------------------------------------------------------------------------------
-- (An attachment's axis is its X: both point down, so the beam's two control points hang below
-- its ends and the wire sags by `sag` at its middle.)
local DOWN = CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0))

local function attachAt(holder: BasePart, at: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = "WireEnd"
	a.CFrame = holder.CFrame:ToObjectSpace(CFrame.new(at) * DOWN)
	a.Parent = holder
	return a
end

local function wire(h0: BasePart, a: Vector3, h1: BasePart, b: Vector3, sag: number, colour: Color3, width: number): Beam
	local beam = Instance.new("Beam")
	beam.Name = "Wire"
	beam.Attachment0 = attachAt(h0, a)
	beam.Attachment1 = attachAt(h1, b)
	beam.Width0 = width
	beam.Width1 = width
	beam.Color = ColorSequence.new(colour)
	beam.Transparency = NumberSequence.new(0)
	beam.LightInfluence = 1
	beam.FaceCamera = true
	beam.Segments = 16
	beam.CurveSize0 = sag * 4 / 3
	beam.CurveSize1 = -sag * 4 / 3
	beam.Parent = h0
	return beam
end

-- The point `t` (0 to 1) along a wire from `a` to `b` that sags `sag`.
local function along(a: Vector3, b: Vector3, sag: number, t: number): Vector3
	local u = 1 - t
	return a * (u * u * (1 + 2 * t)) + b * (t * t * (3 - 2 * t)) - Vector3.new(0, 4 * sag * t * u, 0)
end

-- A string of warm bulbs from `a` to `b`.
local function lights(parent: Instance, h0: BasePart, a: Vector3, h1: BasePart, b: Vector3, sag: number, bulbs: number)
	wire(h0, a, h1, b, sag, rgb(46, 36, 28), 0.07)
	for k = 1, bulbs do
		local p = along(a, b, sag, k / (bulbs + 1))
		tag(Kit.ball(parent, "Bulb", 0.42, p - Vector3.new(0, 0.28, 0), BULB, TRIM), "IslandLantern")
	end
end

---------------------------------------------------------------------------------------------------
-- The land and the sea
---------------------------------------------------------------------------------------------------
-- The island's lowland, as circles (centre x, z, radius) of sand up to G, with lawns on the inner
-- ones. The shore shelves from each circle's edge into the sea (a beach all round), except along
-- the South Beach, which slopes from the lawns into the lagoon on its own.
local LAND = {
	{ -30, -60, 175 }, { 110, -40, 124 }, { -150, 20, 112 }, { 10, 40, 92 }, { -60, -150, 120 }, { 40, -150, 110 },
	{ -170, -170, 70 },
}
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

-- The reef: shoals of sand just under the surface along an arc south of the lagoon, and a few
-- rocks breaking it.
type Shoal = { at: Vector3, r: number, rock: boolean }
local function reef(): { Shoal }
	local out: { Shoal } = {}
	for i = 0, 16 do
		local a = math.rad(198 + i * 9)
		local p = Vector3.new(-10 + math.cos(a) * 172, 0, 152 - math.sin(a) * 152)
		if i % 4 == 1 then
			table.insert(out, { at = p + Vector3.new(0, -4.5, 0), r = 6.5, rock = true })
		else
			table.insert(out, { at = p + Vector3.new(0, -12, 0), r = 9.5, rock = false })
		end
	end
	return out
end

-- Points round the island's shore (each land circle's edge, where it isn't inside another circle
-- or along the South Beach): where the shore shelves into the sea.
local function shore(): { Vector3 }
	local out = {}
	for i, c in LAND do
		local n = math.max(8, math.floor(2 * math.pi * c[3] / 11))
		for k = 0, n - 1 do
			local a = k / n * 2 * math.pi
			local x, z = c[1] + math.cos(a) * c[3], c[2] + math.sin(a) * c[3]
			local inside = false
			for j, o in LAND do
				if j ~= i and math.sqrt((x - o[1]) ^ 2 + (z - o[2]) ^ 2) < o[3] - 3 then
					inside = true
				end
			end
			local beach = x > BEACH.x0 - 6 and x < BEACH.x1 + 6 and z > BEACH.z0 - 6
			if not inside and not beach then
				table.insert(out, Vector3.new(x, 0, z))
			end
		end
	end
	return out
end

local function terrain(o: Vector3): boolean
	local t = Workspace:FindFirstChildOfClass("Terrain")
	if not t then
		return false
	end
	local ok, err = pcall(function()
		local T = t :: Terrain
		-- Turquoise and clear, a little glassy, small waves.
		T.WaterColor = rgb(26, 156, 176)
		T.WaterTransparency = 0.85
		T.WaterReflectance = 0.5
		T.WaterWaveSize = 0.12
		T.WaterWaveSpeed = 8
		pcall(function()
			T:SetMaterialColor(Enum.Material.Sand, rgb(236, 220, 186))
			T:SetMaterialColor(Enum.Material.Grass, rgb(98, 150, 70))
			T:SetMaterialColor(Enum.Material.Rock, rgb(140, 126, 110))
		end)
		local function ring(x: number, z: number, r: number, y0: number, y1: number, material: Enum.Material)
			T:FillCylinder(CFrame.new(o + Vector3.new(x, (y0 + y1) / 2, z)), y1 - y0, r, material)
		end
		-- The sea and its floor; the sandy shelf round the island in steps (the shallows turquoise,
		-- the open sea deep blue beyond).
		T:FillBlock(CFrame.new(o + Vector3.new(0, -22, 0)), Vector3.new(1600, 44, 1600), Enum.Material.Water)
		T:FillBlock(CFrame.new(o + Vector3.new(0, -46, 0)), Vector3.new(1600, 8, 1600), Enum.Material.Sand)
		ring(-20, -30, 380, -42, -32, Enum.Material.Sand)
		ring(-20, -30, 330, -42, -22, Enum.Material.Sand)
		ring(-20, -30, 290, -42, -15, Enum.Material.Sand)
		-- The lagoon's floor, white sand; and the reef.
		for _, c in LAGOON do
			ring(c[1], c[2], c[3] + 18, -42, LAGOON_FLOOR - 4, Enum.Material.Sand)
			ring(c[1], c[2], c[3], -42, LAGOON_FLOOR, Enum.Material.Sand)
		end
		for _, r in reef() do
			T:FillBall(o + r.at, r.r, if r.rock then Enum.Material.Rock else Enum.Material.Sand)
		end
		-- The land: sand up to the lowland, the shore shelving into the sea all round.
		for _, c in LAND do
			ring(c[1], c[2], c[3], -40, G, Enum.Material.Sand)
		end
		for _, p in shore() do
			T:FillBall(o + p + Vector3.new(0, -4, 0), 10, Enum.Material.Sand)
		end
		-- The South Beach: a long slope of sand from the lowland into the lagoon, its ends rounded.
		T:FillWedge(CFrame.new(o + Vector3.new((BEACH.x0 + BEACH.x1) / 2, 0, (BEACH.z0 + BEACH.z1) / 2)) * CFrame.Angles(0, math.pi, 0), Vector3.new(BEACH.x1 - BEACH.x0, 12, BEACH.z1 - BEACH.z0), Enum.Material.Sand)
		for _, x in { BEACH.x0, BEACH.x1 } do
			for z = BEACH.z0 + 6, BEACH.z1 - 6, 12 do
				T:FillBall(o + Vector3.new(x, sandAt(z) - 8, z), 8, Enum.Material.Sand)
			end
		end
		T:FillWedge(CFrame.new(o + Vector3.new((BEACH2.x0 + BEACH2.x1) / 2, 0, (BEACH2.z0 + BEACH2.z1) / 2)) * CFrame.Angles(0, math.pi, 0), Vector3.new(BEACH2.x1 - BEACH2.x0, 12, BEACH2.z1 - BEACH2.z0), Enum.Material.Sand)
		for z = BEACH2.z0 + 6, BEACH2.z1 - 6, 10 do
			T:FillBall(o + Vector3.new(BEACH2.x0 + 2, sand2At(z) - 8, z), 8, Enum.Material.Sand)
		end
		-- The lawns, and the hills.
		for _, c in LAWNS do
			ring(c[1], c[2], c[3], G - 3, G, Enum.Material.Grass)
		end
		for _, h in HILLS do
			local base = G - 1
			for _, r in h.rings do
				ring(h.x, h.z, r[1], base, r[2], Enum.Material.Grass)
				base = r[2] - 0.5
			end
		end
		-- Warm rock: the Grand Villa's terraces stand on it at the sea, and outcrops along the
		-- western shore.
		for _, b in {
			{ 240, 2, -28, 14 }, { 240, -1, 12, 11 }, { 214, 10, -62, 12 }, { 240, -2, 42, 9 }, { 238, -3, 74, 8 }, { 226, -4, 98, 7 },
			{ -268, -2, 22, 9 }, { -252, -3, -42, 10 }, { -236, -3, -206, 9 }, { 168, -4, -232, 8 },
		} do
			T:FillBall(o + Vector3.new(b[1], b[2], b[3]), b[4], Enum.Material.Rock)
		end
	end)
	if not ok then
		warn("[Maison] The island's terrain: " .. tostring(err))
		return false
	end
	return true
end

-- With no terrain: the same island in plain parts (a flat sea of glass, sand and lawns, the hills).
local function groundParts(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Ground")
	Kit.part(m, "Sea", Vector3.new(1600, 1, 1600), CFrame.new(o + Vector3.new(0, -0.5, 0)), SEA, { shadow = false })
	for _, c in LAGOON do
		disc(m, "LagoonFloor", c[3] * 2, 1, o + Vector3.new(c[1], 0, c[2]), o.Y + LAGOON_FLOOR, SAND)
	end
	for _, c in LAND do
		disc(m, "Land", c[3] * 2, G + 2, o + Vector3.new(c[1], 0, c[2]), o.Y + G, SAND)
	end
	for _, c in LAWNS do
		disc(m, "Lawn", c[3] * 2, 0.4, o + Vector3.new(c[1], 0, c[2]), o.Y + G + 0.05, GRASS)
	end
	for _, h in HILLS do
		-- (Every other ring: enough to stand on.)
		for i = 2, #h.rings, 2 do
			local r = h.rings[i]
			disc(m, "Hill", r[1] * 2, 4, o + Vector3.new(h.x, 0, h.z), o.Y + r[2], GRASS)
		end
	end
	wedge(m, "Beach", Vector3.new(BEACH.x1 - BEACH.x0, 12, BEACH.z1 - BEACH.z0), CFrame.new(o + Vector3.new((BEACH.x0 + BEACH.x1) / 2, 0, (BEACH.z0 + BEACH.z1) / 2)) * CFrame.Angles(0, math.pi, 0), SAND)
	wedge(m, "Beach", Vector3.new(BEACH2.x1 - BEACH2.x0, 12, BEACH2.z1 - BEACH2.z0), CFrame.new(o + Vector3.new((BEACH2.x0 + BEACH2.x1) / 2, 0, (BEACH2.z0 + BEACH2.z1) / 2)) * CFrame.Angles(0, math.pi, 0), SAND)
	Kit.ball(m, "Rock", 24, o + Vector3.new(240, 2, -28), ROCK)
	Kit.ball(m, "Rock", 18, o + Vector3.new(240, -1, 12), ROCK)
end

---------------------------------------------------------------------------------------------------
-- Palms, flowers, torches and lamps
---------------------------------------------------------------------------------------------------
-- A palm: a trunk that leans and curves as it rises, ringed where its segments meet, a crown
-- with a coconut, and eight fronds that rise and arch over, each tapering to a point
-- (the outer two older, lower and paler).
local FRONDS = { rgb(56, 120, 50), rgb(70, 136, 56), rgb(88, 148, 62), rgb(132, 146, 72) }
local function palm(parent: Instance, base: Vector3, height: number, lean: number, yaw: number)
	local m = Kit.model(parent, "Palm")
	local away = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
	local prev = base - Vector3.new(0, 1.2, 0)
	local segments = 4
	for i = 1, segments do
		local t = i / segments
		local p = base + Vector3.new(0, height * t, 0) + away * (lean * t ^ 1.8)
		local d = 1.9 - 0.75 * t
		rod(m, "Trunk", prev, p, d, TRUNK)
		if i < segments - 1 then
			Kit.cylinder(m, "Ring", 0.5, d + 0.2, CFrame.lookAt(p, p + (p - prev).Unit) * CFrame.Angles(0, math.rad(90), 0), TRUNK_RING, TRIM)
		end
		prev = p
	end
	local top = prev
	Kit.ball(m, "Crown", 1.9, top + Vector3.new(0, 0.2, 0), CROWN, TRIM)
	Kit.ball(m, "Coconut", 0.9, top + Vector3.new(math.cos(yaw + 1.1) * 0.8, -0.6, math.sin(yaw + 1.1) * 0.8), COCONUT, TRIM)
	for i = 0, 7 do
		local young = i < 6
		local a = yaw + (if young then i * math.pi / 3 else (i - 6) * math.pi + math.pi / 6) + ((i * 7) % 5) * 0.07
		local rise = if young then math.rad(18 + (i % 3) * 9) else math.rad(-6 - (i % 2) * 8)
		local droop = if young then math.rad(-42 - (i % 2) * 12) else math.rad(-50 - (i % 2) * 8)
		local inner, outer = if young then 4.4 else 3.8, if young then 5.6 else 4.8
		local w = if young then 2.3 else 2.0
		local colour = look(if young then FRONDS[i % 3 + 1] else FRONDS[4], Enum.Material.SmoothPlastic)
		local joint = CFrame.new(top + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, a, 0) * CFrame.Angles(rise, 0, 0)
		Kit.part(m, "Frond", Vector3.new(w, 0.14, inner), joint * CFrame.new(0, 0, -inner / 2), colour, TRIM)
		-- (The tip: two wedges meeting in a point along the frond's middle.)
		local tip = joint * CFrame.new(0, 0, -inner + 0.15) * CFrame.Angles(droop, 0, 0)
		wedge(m, "FrondTip", Vector3.new(0.14, w / 2, outer), tip * CFrame.fromMatrix(Vector3.new(w / 4, 0, -outer / 2), Vector3.new(0, -1, 0), Vector3.new(1, 0, 0)), colour, TRIM)
		wedge(m, "FrondTip", Vector3.new(0.14, w / 2, outer), tip * CFrame.fromMatrix(Vector3.new(-w / 4, 0, -outer / 2), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0)), colour, TRIM)
	end
end

-- A flowering bush: a mound of leaves with hibiscus blooms on it.
local BLOOMS = { rgb(236, 64, 96), rgb(255, 170, 64), rgb(255, 120, 170), rgb(250, 236, 120) }
local function bush(parent: Instance, at: Vector3, size: number, k: number)
	local m = Kit.model(parent, "Bush")
	Kit.ball(m, "Leaves", size, at + Vector3.new(0, size * 0.25, 0), LEAF, SOFT)
	Kit.ball(m, "Leaves", size * 0.7, at + Vector3.new(size * 0.4, size * 0.15, size * 0.2), LEAF, TRIM)
	for i = 0, 2 do
		local a = k + i * 2.1
		local p = at + Vector3.new(math.cos(a) * size * 0.36, size * 0.55, math.sin(a) * size * 0.36)
		Kit.ball(m, "Bloom", size * 0.2, p, look(BLOOMS[(k + i) % #BLOOMS + 1], Enum.Material.SmoothPlastic), TRIM)
	end
end

-- A tiki torch: a bamboo pole, a binding, a woven cup and its flame (lit on each screen).
local function torch(parent: Instance, at: Vector3)
	local m = Kit.model(parent, "Torch")
	Kit.post(m, "Pole", 6.6, 0.32, at - Vector3.new(0, 0.6, 0), BAMBOO, TRIM)
	Kit.cylinder(m, "Binding", 0.3, 0.44, CFrame.new(at + Vector3.new(0, 4.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), TRUNK_RING, TRIM)
	Kit.cylinder(m, "Cup", 1, 0.84, CFrame.new(at + Vector3.new(0, 6.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), TRUNK_RING, TRIM)
	tag(Kit.part(m, "Flame", Vector3.new(0.5, 1.1, 0.5), CFrame.new(at + Vector3.new(0, 7.3, 0)), FLAME, TRIM), "IslandTorch")
end

-- A lamp on a post: black, a gold cap, a warm lantern (lit on each screen).
local function lamp(parent: Instance, at: Vector3, height: number?)
	local m = Kit.model(parent, "Lamp")
	local h = height or 6.5
	Kit.post(m, "Post", h - 0.2, 0.3, at - Vector3.new(0, 0.4, 0), BLACK, TRIM)
	tag(Kit.part(m, "Lantern", Vector3.new(0.75, 1.2, 0.75), CFrame.new(at + Vector3.new(0, h + 0.4, 0)), LANTERN, TRIM), "IslandLantern")
	Kit.part(m, "Cap", Vector3.new(1.15, 0.28, 1.15), CFrame.new(at + Vector3.new(0, h + 1.12, 0)), GILT, TRIM)
end

-- A flag on a pole: black with a gold band (each screen lets it stir in the breeze).
local function flag(parent: Instance, at: Vector3, height: number, yaw: number, scale: number?)
	local k = scale or 1
	local m = Kit.model(parent, "Flag")
	Kit.post(m, "FlagPole", height, 0.22 * k, at, WHITE, TRIM)
	Kit.ball(m, "Finial", 0.42 * k, at + Vector3.new(0, height + 0.15, 0), GILT, TRIM)
	local cf = CFrame.new(at + Vector3.new(0, height - 1.2 * k, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(1.9 * k, 0, 0)
	tag(Kit.part(m, "Flag", Vector3.new(3.6 * k, 2.2 * k, 0.06), cf, BLACK, TRIM), "IslandFlag")
	tag(Kit.part(m, "FlagBand", Vector3.new(3.6 * k, 0.4 * k, 0.08), cf, GILT, TRIM), "IslandFlag")
end

-- A garden bench: teak on black legs, two real seats, facing `face` (the way its sitters look).
local function bench(parent: Instance, at: Vector3, face: Vector3)
	local m = Kit.model(parent, "Bench")
	local cf = CFrame.lookAt(at, at + Vector3.new(face.X, 0, face.Z))
	Kit.part(m, "BenchSeat", Vector3.new(5, 0.35, 1.8), cf * CFrame.new(0, 1.55, 0), TEAK)
	Kit.part(m, "BenchBack", Vector3.new(5, 1.5, 0.3), cf * CFrame.new(0, 2.5, 1.05) * CFrame.Angles(math.rad(10), 0, 0), TEAK)
	for _, x in { -2, 2 } do
		Kit.part(m, "BenchLeg", Vector3.new(0.4, 1.4, 1.6), cf * CFrame.new(x, 0.7, 0), BLACK)
	end
	Furniture.seatsOn(m, "BenchSeats", { cf * CFrame.new(-1.2, 1.72, -0.1), cf * CFrame.new(1.2, 1.72, -0.1) }, "The bench", 1.6)
end

-- A flight of solid stone steps from `a` (its foot) up to `b` (its head): every step a block down
-- to `floor` (so no step ever floats over the slope beneath), a low wall along each side with a
-- gold rail on it.
local function flight(parent: Instance, name: string, a: Vector3, b: Vector3, width: number, floor: number, lk: Kit.Look)
	local m = Kit.model(parent, name)
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local run, rise = flat.Magnitude, b.Y - a.Y
	local n = math.max(1, math.ceil(rise / 1.0 - 1e-6))
	local stepRise, stepRun = rise / n, run / n
	local frame = CFrame.lookAt(Vector3.new(a.X, 0, a.Z), Vector3.new(a.X, 0, a.Z) + flat.Unit)
	for i = 0, n - 1 do
		local top = a.Y + stepRise * (i + 1)
		local h = top - floor
		Kit.part(m, "Step", Vector3.new(width + 2.4, h, stepRun + 0.06), frame * CFrame.new(0, floor + h / 2, -stepRun * (i + 0.5)), lk)
	end
	local slope = math.atan2(rise, run)
	local len = math.sqrt(run * run + rise * rise)
	for _, side in { -1, 1 } do
		local mid = frame * CFrame.new(side * (width / 2 + 0.6), (a.Y + b.Y) / 2 + stepRise * 0.5 + 0.9, -run / 2) * CFrame.Angles(slope, 0, 0)
		Kit.part(m, "StairWall", Vector3.new(1.2, 2.6, len + 0.6), mid, lk)
		Kit.part(m, "StairRail", Vector3.new(0.34, 0.24, len + 0.4), mid * CFrame.new(0, 1.42, 0), GILT, TRIM)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- The jet (full size on the airstrip; small, `k`, as a model in the Jet Gallery). Built nose to
-- -Z of `cf`, wheels on `cf`'s ground. Parts take their livery colour by their "Livery" attribute
-- (body, trim, stripe, cabin): each guest's screen paints its own jet.
---------------------------------------------------------------------------------------------------
local function paint(part: BasePart, which: string)
	part:SetAttribute("Livery", which)
end

function IslandBuild.jet(parent: Instance, cf: CFrame, k: number?, simple: boolean?): Model
	local s = k or 1
	local m = Kit.model(parent, "Jet")
	local body = look(rgb(244, 240, 230), Enum.Material.SmoothPlastic, 0.18)
	local trim = look(rgb(214, 176, 96), Enum.Material.Metal, 0.2)
	local opts = if simple then TRIM else nil
	local function at(x: number, yy: number, z: number): CFrame
		return cf * CFrame.new(x * s, yy * s, z * s)
	end
	local along = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder's length along the jet)
	-- The fuselage: the cabin; the nose narrowing in steps to a point, each step rounded off by a
	-- shoulder (a sphere the width of the wider section) so it reads as one smooth taper; the
	-- tail cone sweeping up.
	paint(Kit.cylinder(m, "Fuselage", 34 * s, 7.6 * s, at(0, 6.2, 0) * along, body, opts), "body")
	paint(Kit.cylinder(m, "Nose", 6 * s, 6.8 * s, at(0, 6.1, -19.9) * along, body, opts), "body")
	paint(Kit.cylinder(m, "NoseTaper", 3.2 * s, 5.4 * s, at(0, 5.95, -24.2) * along, body, opts), "body")
	if not simple then
		paint(Kit.cylinder(m, "NoseTaper2", 2.4 * s, 3.8 * s, at(0, 5.8, -26.8) * along, body, opts), "body")
	end
	paint(Kit.ball(m, "NoseTip", 3.4 * s, (at(0, 5.7, -28.0)).Position, body, opts), "body")
	paint(Kit.cylinder(m, "Tail", 8 * s, 6.4 * s, at(0, 6.4, 20.8) * along, body, opts), "body")
	paint(Kit.cylinder(m, "TailCone", 6 * s, 4.4 * s, at(0, 6.8, 27.6) * along, body, opts), "body")
	if not simple then
		paint(Kit.ball(m, "TailTip", 3.6 * s, (at(0, 7, 30.6)).Position, body, opts), "body")
	end
	if not simple then
		for _, sh in { { 6.2, -17, 7.6 }, { 6.1, -22.9, 6.8 }, { 5.95, -25.8, 5.4 }, { 6.3, 17, 7.6 }, { 6.6, 24.8, 6.4 } } do
			paint(Kit.ball(m, "Shoulder", sh[3] * s, (at(0, sh[1], sh[2])).Position, body, TRIM), "body")
		end
	end
	-- The cheat line along each flank, and the windscreen.
	for _, side in { -1, 1 } do
		paint(Kit.part(m, "Stripe", Vector3.new(0.12 * s, 0.6 * s, 40 * s), at(side * 3.82, 5.6, -1), trim, TRIM), "stripe")
	end
	wedge(m, "Windscreen", Vector3.new(4.6 * s, 1.6 * s, 3 * s), at(0, 8.9, -20.6) * CFrame.Angles(0, math.pi, 0), DARK_GLASS, TRIM)
	if not simple then
		-- The cabin's oval windows, seven a side, and the door (open, its airstair down).
		for _, side in { -1, 1 } do
			for i = 0, 6 do
				Kit.cylinder(m, "Window", 0.2, 1.5, at(side * 3.78, 7.2, -12 + i * 3.6), DARK_GLASS, TRIM)
			end
		end
		paint(Kit.part(m, "Door", Vector3.new(0.3, 5.2, 2.8), at(-4.4, 4.6, -14.6) * CFrame.Angles(0, 0, math.rad(-8)), body, TRIM), "body")
		local stairTop = at(-4.6, 3.1, -14.6)
		for i = 0, 5 do
			local step = stairTop * CFrame.new(-1 - i * 1.1, -i * 0.55, 0)
			Kit.part(m, "Step", Vector3.new(1.1, 0.24, 2.4), step, L.blackLacquer)
		end
		for _, z in { -1.3, 1.3 } do
			local a = (stairTop * CFrame.new(-0.6, 2.4, z)).Position
			local b = (stairTop * CFrame.new(-7.4, -1.2, z)).Position
			rod(m, "Handrail", a, b, 0.18, trim, TRIM)
		end
		-- The wheels.
		for _, w in { { 0, -18 }, { -5.2, 4 }, { 5.2, 4 } } do
			Kit.cylinder(m, "Wheel", 0.9, 1.9, at(w[1], 0.95, w[2]), look(rgb(20, 20, 22), Enum.Material.Rubber))
			Kit.part(m, "Strut", Vector3.new(0.4, 2.6, 0.4), at(w[1], 2.4, w[2]), CHROME, TRIM)
		end
	end
	-- The wings: swept, a little dihedral, winglets at the tips (and the navigation lights on them).
	for _, side in { -1, 1 } do
		local root = at(side * 3.4, 4.6, 2) * CFrame.Angles(0, side * math.rad(-28), side * math.rad(-4))
		paint(Kit.part(m, "Wing", Vector3.new(24 * s, 0.8 * s, 7.2 * s), root * CFrame.new(side * 12 * s, 0, 0), body, opts), "body")
		if not simple then
			paint(Kit.part(m, "WingEdge", Vector3.new(24 * s, 0.82 * s, 0.6 * s), root * CFrame.new(side * 12 * s, 0, -3.5 * s), trim, TRIM), "trim")
		end
		local tip = root * CFrame.new(side * 24 * s, 0, 0)
		if not simple then
			paint(Kit.part(m, "Winglet", Vector3.new(0.5 * s, 4.2 * s, 3.4 * s), tip * CFrame.new(0, 2 * s, 1 * s) * CFrame.Angles(math.rad(-18), 0, side * math.rad(-12)), trim, opts), "trim")
		end
		if not simple then
			local nav = Kit.ball(m, "NavLight", 0.5, (tip * CFrame.new(side * 0.3, 0.2, -1.6)).Position, look(if side < 0 then rgb(255, 60, 60) else rgb(80, 255, 130), Enum.Material.Neon), TRIM)
			tag(nav, "IslandBlink")
		end
		-- The engines on the rear fuselage.
		paint(Kit.cylinder(m, "Engine", 9 * s, 3.8 * s, at(side * 5.4, 8.6, 17) * along, body, opts), "body")
		if not simple then
			Kit.cylinder(m, "Intake", 0.4 * s, 3.9 * s, at(side * 5.4, 8.6, 12.4) * along, trim, TRIM)
			Kit.cylinder(m, "Exhaust", 0.6 * s, 3 * s, at(side * 5.4, 8.6, 21.6) * along, look(rgb(30, 30, 34), Enum.Material.Metal), TRIM)
		end
		if not simple then
			Kit.part(m, "Pylon", Vector3.new(2 * s, 0.6 * s, 4 * s), at(side * 3.8, 8, 17), body, TRIM)
		end
	end
	-- The tail: a swept fin, and the high tailplane on top.
	paint(wedge(m, "Fin", Vector3.new(0.8 * s, 12 * s, 10 * s), at(0, 14.6, 25.4), body, opts), "body")
	paint(Kit.part(m, "FinStripe", Vector3.new(0.84 * s, 1.2 * s, 6 * s), at(0, 16.4, 26.4), trim, TRIM), "stripe")
	paint(Kit.part(m, "Tailplane", Vector3.new(16 * s, 0.6 * s, 4.4 * s), at(0, 20.4, 28.4), body, opts), "body")
	if not simple then
		tag(Kit.ball(m, "Strobe", 0.5, (at(0, 21, 30.8)).Position, look(rgb(255, 255, 255), Enum.Material.Neon), TRIM), "IslandBlink")
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- The airstrip, the jet and the Jet Gallery
---------------------------------------------------------------------------------------------------
local function airstrip(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Airstrip")
	local z, x0, x1 = -176, -210, 130
	local mid = (x0 + x1) / 2
	-- (Thick, most of it in the ground: no gap under it wherever the ground dips.)
	Kit.part(m, "Runway", Vector3.new(x1 - x0, 2, 40), CFrame.new(o + Vector3.new(mid, G - 0.4, z)), L.asphalt)
	-- The centre line, the thresholds and the edge lights.
	for x = x0 + 30, x1 - 30, 18 do
		Kit.part(m, "CentreLine", Vector3.new(9, 0.04, 0.8), CFrame.new(o + Vector3.new(x, G + 0.62, z)), RUNWAY_PAINT, TRIM)
	end
	for _, tx in { x0 + 8, x1 - 8 } do
		for i = -3, 3 do
			Kit.part(m, "Threshold", Vector3.new(10, 0.04, 2.4), CFrame.new(o + Vector3.new(tx, G + 0.62, z + i * 4.8)), RUNWAY_PAINT, TRIM)
		end
	end
	for x = x0 + 4, x1 - 4, 20 do
		for _, side in { -1, 1 } do
			Kit.part(m, "EdgeLight", Vector3.new(0.6, 0.5, 0.6), CFrame.new(o + Vector3.new(x, G + 0.85, z + side * 20.6)), EDGE_LIGHT, TRIM)
		end
	end
	-- The windsock, by the far end.
	local sock = o + Vector3.new(x1 - 20, G, z - 28)
	Kit.post(m, "WindsockPole", 12, 0.3, sock, L.brass, TRIM)
	Kit.cylinder(m, "Windsock", 5, 1.6, CFrame.new(sock + Vector3.new(2.6, 11.6, 0)) * CFrame.Angles(0, 0, math.rad(-6)), look(rgb(255, 120, 60), Enum.Material.Fabric), TRIM)
	-- Your jet, and its welcome: a red carpet from the airstair toward the island, brass stanchions
	-- with velvet ropes either side.
	IslandBuild.jet(m, CFrame.new(o) * Plan.Jet, 1, false)
	local stair = o + Plan.Airstair
	Kit.part(m, "RedCarpet", Vector3.new(4, 0.06, 18), CFrame.new(stair + Vector3.new(0, 0.66, 9)), look(rgb(150, 18, 30), Enum.Material.Carpet), TRIM)
	Kit.part(m, "CarpetEdge", Vector3.new(4.4, 0.04, 18.2), CFrame.new(stair + Vector3.new(0, 0.63, 9)), GILT, TRIM)
	for _, side in { -1, 1 } do
		local tops: { { part: BasePart, at: Vector3 } } = {}
		for i = 0, 3 do
			local p = stair + Vector3.new(side * 3.4, 0.6, 3 + i * 4.4)
			Kit.post(m, "Stanchion", 3, 0.3, p, L.brass, TRIM)
			local top = Kit.ball(m, "StanchionTop", 0.5, p + Vector3.new(0, 3.1, 0), L.brass, TRIM)
			table.insert(tops, { part = top :: BasePart, at = p + Vector3.new(0, 2.9, 0) })
		end
		for i = 1, #tops - 1 do
			wire(tops[i].part, tops[i].at, tops[i + 1].part, tops[i + 1].at, 0.6, VELVET, 0.2)
		end
	end
	-- The way home: at the foot of the airstair.
	local homeAt = Kit.part(m, "FlyHome", Vector3.new(4, 7, 4), CFrame.new(stair + Vector3.new(0, 3.6, 2)), UNSEEN, { collide = false, shadow = false })
	homeAt:SetAttribute("PromptHome", true)
	-- The sign: before a guest just landed, facing them.
	local arrival = (CFrame.new(o) * Plan.Arrival).Position
	local signAt = arrival + Plan.Arrival.LookVector * 16 + Plan.Arrival.RightVector * 10
	Kit.sign(m, "WelcomeSign", CFrame.lookAt(Vector3.new(signAt.X, o.Y + G, signAt.Z), Vector3.new(arrival.X, o.Y + G, arrival.Z)), 7, 2.4, {
		{ text = "LUXURY ISLAND", size = 0.4, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "the Lookout, the villas, the lagoon's pearls · fly home from your jet", size = 0.34, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, 3.2)
	for _, side in { -1, 1 } do
		lamp(m, Vector3.new(signAt.X, o.Y + G, signAt.Z) + Plan.Arrival.RightVector * side * 5, 5.5)
	end
end

local function gallery(parent: Instance, o: Vector3): BasePart
	local m = Kit.model(parent, "JetGallery")
	local c = o + Vector3.new(60, G, -134)
	local w, d, h = 64, 30, 16
	Kit.part(m, "Floor", Vector3.new(w, 1.6, d), CFrame.new(c + Vector3.new(0, 0, 0)), look(rgb(232, 228, 220), Enum.Material.Marble, 0.08))
	Kit.part(m, "Roof", Vector3.new(w + 6, 1.4, d + 6), CFrame.new(c + Vector3.new(0, h, 0)), WHITE)
	Kit.part(m, "Fascia", Vector3.new(w + 6.2, 0.3, d + 6.2), CFrame.new(c + Vector3.new(0, h + 0.3, 0)), GILT, TRIM)
	Kit.part(m, "Soffit", Vector3.new(w + 5.8, 0.2, d + 5.8), CFrame.new(c + Vector3.new(0, h - 0.8, 0)), TEAK, TRIM)
	Kit.part(m, "BackWall", Vector3.new(w, h, 1), CFrame.new(c + Vector3.new(0, h / 2, d / 2)), WHITE)
	for _, side in { -1, 1 } do
		Kit.part(m, "SideWall", Vector3.new(1, h, d), CFrame.new(c + Vector3.new(side * w / 2, h / 2, 0)), WHITE)
	end
	-- Its glass front, to the airstrip, between slim black columns; a warm glow along the ceiling.
	for i = 0, 8 do
		local x = -w / 2 + i * (w / 8)
		Kit.part(m, "Column", Vector3.new(0.8, h, 0.8), CFrame.new(c + Vector3.new(x, h / 2, -d / 2)), BLACK)
	end
	Kit.part(m, "Glass", Vector3.new(w, h - 1.4, 0.3), CFrame.new(c + Vector3.new(0, (h - 1.4) / 2 + 0.8, -d / 2)), GLASS, { shadow = false })
	for _, x in { -16, 16 } do
		local glow = Kit.part(m, "CeilingGlow", Vector3.new(24, 0.2, 1.2), CFrame.new(c + Vector3.new(x, h - 1.0, 4)), COVE, TRIM)
		tag(glow, "IslandGlow")
		glow:SetAttribute("Range", 26)
	end
	-- Every livery, as a model on a plinth along the back.
	for i, livery in Plan.Liveries do
		local x = -w / 2 + 6 + (i - 1) * ((w - 12) / math.max(1, #Plan.Liveries - 1))
		local plinth = Kit.part(m, "Plinth", Vector3.new(6, 3, 5), CFrame.new(c + Vector3.new(x, 2.3, d / 2 - 5)), L.blackLacquer)
		Kit.part(m, "PlinthBand", Vector3.new(6.1, 0.2, 5.1), CFrame.new(c + Vector3.new(x, 3.7, d / 2 - 5)), L.brass, TRIM)
		local model = IslandBuild.jet(m, CFrame.lookAt(c + Vector3.new(x, 3.85, d / 2 - 5), c + Vector3.new(x - 1, 3.85, d / 2 - 6)), 0.09, true)
		model:SetAttribute("Livery", livery.id)
		Kit.engrave(plinth, Enum.NormalId.Front, {
			{ text = string.upper(livery.name), size = 0.42, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		}, { ppu = 90, lit = false, brightness = 1.3 })
		plinth.CFrame = CFrame.lookAt(plinth.CFrame.Position, plinth.CFrame.Position + Vector3.new(0, 0, -1))
	end
	-- The Livery Desk.
	local desk = Kit.part(m, "LiveryDesk", Vector3.new(8, 3.6, 2.6), CFrame.new(c + Vector3.new(0, 2.6, 2)), L.blackLacquer)
	Kit.part(m, "DeskTop", Vector3.new(8.4, 0.3, 3), CFrame.new(c + Vector3.new(0, 4.55, 2)), look(rgb(232, 228, 220), Enum.Material.Marble, 0.1))
	local board = Kit.part(m, "GallerySign", Vector3.new(30, 3, 0.3), CFrame.lookAt(c + Vector3.new(0, h - 3.4, -d / 2 - 0.4), c + Vector3.new(0, h - 3.4, -d)), L.blackLacquer, TRIM)
	Kit.engrave(board, Enum.NormalId.Front, {
		{ text = "THE JET GALLERY", size = 0.52, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "choose your jet's livery and the island's light at the desk", size = 0.3, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 50, lit = false, brightness = 1.4, maxDistance = 260 })
	return desk
end

---------------------------------------------------------------------------------------------------
-- The overwater villas, the beach and the Coral Club
---------------------------------------------------------------------------------------------------
local function overwater(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Overwater")
	local x, deckY = -24, Plan.SEA + 3
	local z0, z1 = 118, 246
	-- The pier: a teak walk on posts, rope rails hanging between brass-capped posts, lanterns.
	Kit.part(m, "Pier", Vector3.new(7, 0.6, z1 - z0), CFrame.new(o + Vector3.new(x, deckY, (z0 + z1) / 2)), DECK)
	local rails: { [number]: { { part: BasePart, at: Vector3 } } } = { [-1] = {}, [1] = {} }
	for z = z0 + 4, z1, 9 do
		for _, side in { -1, 1 } do
			Kit.post(m, "PierPost", 10.4, 0.8, o + Vector3.new(x + side * 3.2, deckY - 10, z), TEAK, TRIM)
			local post = Kit.post(m, "RailPost", 2.6, 0.3, o + Vector3.new(x + side * 3.3, deckY + 0.3, z), TEAK, TRIM)
			table.insert(rails[side], { part = post :: BasePart, at = o + Vector3.new(x + side * 3.3, deckY + 2.7, z) })
		end
		if (z - z0) % 18 < 9 then
			lamp(m, o + Vector3.new(x + 3.3, deckY + 0.3, z + 4.5), 3.4)
		end
	end
	-- (The ropes stop either side of the postcard frame that stands on the pier.)
	local frames: { number } = {}
	for _, p in Plan.Postcards do
		if math.abs(p.at.X - x) < 4 and p.at.Z > z0 and p.at.Z < z1 then
			table.insert(frames, p.at.Z)
		end
	end
	for _, side in { -1, 1 } do
		local list = rails[side]
		for i = 1, #list - 1 do
			local za, zb = list[i].at.Z - o.Z, list[i + 1].at.Z - o.Z
			local crosses = false
			for _, fz in frames do
				if fz > za - 1 and fz < zb + 1 then
					crosses = true
				end
			end
			if not crosses then
				wire(list[i].part, list[i].at, list[i + 1].part, list[i + 1].at, 0.45, rgb(214, 196, 160), 0.14)
			end
		end
	end
	-- Four villas off the pier: a deck with its plunge pool and loungers, a thatched bungalow
	-- with glass doors to the water and a warm room within, a ladder down into the lagoon.
	local villas = { { -1, 168 }, { 1, 168 }, { -1, 214 }, { 1, 214 } }
	local CREAM = look(rgb(240, 230, 210), Enum.Material.Plaster)
	for i, v in villas do
		local side, z = v[1], v[2]
		local cx = x + side * 19
		local c = o + Vector3.new(cx, deckY, z)
		Kit.part(m, "Walk", Vector3.new(9, 0.5, 4), CFrame.new(o + Vector3.new(x + side * 7.5, deckY, z)), DECK)
		Kit.part(m, "VillaDeck", Vector3.new(22, 0.6, 18), CFrame.new(c), DECK)
		for _, dx in { -9, 9 } do
			for _, dz in { -7, 7 } do
				Kit.post(m, "VillaPost", 10.4, 0.9, c + Vector3.new(dx, -10, dz), TEAK, TRIM)
			end
		end
		-- The bungalow, on the pier side of the deck.
		local hc = o + Vector3.new(cx - side * 4, deckY, z)
		for _, dz in { -4, 4 } do
			Kit.part(m, "BungalowBack", Vector3.new(1, 8, 4), CFrame.new(hc + Vector3.new(-side * 5.5, 4.3, dz)), CREAM)
		end
		Kit.part(m, "BungalowLintel", Vector3.new(1, 1.4, 4), CFrame.new(hc + Vector3.new(-side * 5.5, 7.6, 0)), CREAM)
		for _, dz in { -6, 6 } do
			Kit.part(m, "BungalowSide", Vector3.new(11, 8, 1), CFrame.new(hc + Vector3.new(0, 4.3, dz)), CREAM)
			local wc = hc + Vector3.new(0, 4.6, dz + (if dz > 0 then 0.52 else -0.52))
			Kit.part(m, "Window", Vector3.new(3.4, 3, 0.12), CFrame.new(wc), DARK_GLASS, TRIM)
			Kit.part(m, "WindowFrame", Vector3.new(3.8, 3.4, 0.08), CFrame.new(wc - Vector3.new(0, 0, if dz > 0 then 0.04 else -0.04)), TEAK, TRIM)
		end
		for _, dz in { -3.75, 3.75 } do
			Kit.part(m, "GlassDoors", Vector3.new(0.3, 7.4, 3.5), CFrame.new(hc + Vector3.new(side * 5.5, 4, dz)), GLASS, { shadow = false })
		end
		Kit.part(m, "DoorMullion", Vector3.new(0.4, 7.4, 0.4), CFrame.new(hc + Vector3.new(side * 5.5, 4, 0)), TEAK, TRIM)
		-- Within: the bed and a warm lamp, seen through the glass.
		Kit.part(m, "Bed", Vector3.new(4.6, 1.6, 6), CFrame.new(hc + Vector3.new(-side * 2.4, 1.1, 0)), look(rgb(244, 240, 232), Enum.Material.Fabric))
		local glow = Kit.part(m, "RoomGlow", Vector3.new(0.2, 1.6, 6), CFrame.new(hc + Vector3.new(-side * 4.9, 5.4, 0)), ROOM_GLOW, TRIM)
		tag(glow, "IslandGlow")
		glow:SetAttribute("Range", 16)
		-- The door from the pier, its brass lamp; the pergola over the deck's open side.
		local door = hc + Vector3.new(-side * 6.05, 0, 0)
		for _, dz in { -2.2, 2.2 } do
			Kit.part(m, "DoorPost", Vector3.new(0.3, 7.4, 0.4), CFrame.new(door + Vector3.new(0, 3.7, dz)), TEAK, TRIM)
		end
		Kit.part(m, "DoorHead", Vector3.new(0.3, 0.4, 4.8), CFrame.new(door + Vector3.new(0, 7.4, 0)), TEAK, TRIM)
		tag(Kit.ball(m, "Lantern", 1.0, door + Vector3.new(-side * 0.25, 6.2, 2.9), LANTERN, TRIM), "IslandLantern")
		for _, dz in { -7.4, 7.4 } do
			Kit.post(m, "PergolaPost", 8.4, 0.5, o + Vector3.new(cx + side * 10.2, deckY + 0.3, z + dz), TEAK, TRIM)
		end
		for k = 0, 4 do
			Kit.part(m, "PergolaSlat", Vector3.new(9, 0.3, 0.4), CFrame.new(o + Vector3.new(cx + side * 5.6, deckY + 8.7, z - 6 + k * 3)), TEAK, TRIM)
		end
		Kit.part(m, "PergolaBeam", Vector3.new(0.5, 0.5, 15.4), CFrame.new(o + Vector3.new(cx + side * 10.2, deckY + 8.5, z)), TEAK, TRIM)
		-- The thatched roof: two slopes, a ridge, and its gable ends closed.
		for _, dz in { -1, 1 } do
			Kit.part(m, "Thatch", Vector3.new(14, 0.8, 8.6), CFrame.new(hc + Vector3.new(0, 10.4, dz * 3.6)) * CFrame.Angles(dz * math.rad(28), 0, 0), THATCH)
		end
		Kit.part(m, "Ridge", Vector3.new(14.4, 0.7, 0.9), CFrame.new(hc + Vector3.new(0, 12.4, 0)), TEAK, TRIM)
		for _, gx in { -5.6, 5.6 } do
			for _, dz in { -1, 1 } do
				wedge(m, "Gable", Vector3.new(0.6, 4, 6.2), CFrame.new(hc + Vector3.new(gx, 10.3, dz * 3.1)) * CFrame.Angles(0, if dz > 0 then math.pi else 0, 0), CREAM, TRIM)
			end
		end
		-- The plunge pool and the loungers, on the open side.
		local px = cx + side * 5
		Furniture.build("pool", m, CFrame.lookAt(o + Vector3.new(px, deckY + 0.3, z - 3), o + Vector3.new(px, deckY + 0.3, z - 20)), { model = "lagoon", length = 8, width = 5 }, false)
		Furniture.build("loungers", m, CFrame.lookAt(o + Vector3.new(px, deckY + 0.3, z + 4.5), o + Vector3.new(px + side * 30, deckY + 0.3, z + 4.5)), { accent = rgb(28, 52, 92) }, false)
		-- A ladder down into the lagoon.
		local lx = cx + side * 11.2
		for _, dz in { -0.9, 0.9 } do
			Kit.part(m, "LadderRail", Vector3.new(0.2, 7, 0.2), CFrame.new(o + Vector3.new(lx, deckY - 2.2, z + dz)), CHROME, TRIM)
		end
		for k = 0, 3 do
			Kit.part(m, "LadderRung", Vector3.new(0.2, 0.2, 1.8), CFrame.new(o + Vector3.new(lx, deckY - 0.6 - k * 1.5, z)), CHROME, TRIM)
		end
		tag(Kit.ball(m, "Lantern", 1.0, c + Vector3.new(side * 10.4, 3, -8.4), LANTERN, TRIM), "IslandLantern")
		local plate = Kit.part(m, "VillaPlate", Vector3.new(3.4, 1.1, 0.2), CFrame.lookAt(o + Vector3.new(x + side * 3.8, deckY + 2.2, z), o + Vector3.new(x, deckY + 2.2, z)), L.blackLacquer, TRIM)
		Kit.engrave(plate, Enum.NormalId.Front, { { text = "VILLA " .. ({ "I", "II", "III", "IV" })[i], size = 0.6, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 90, lit = false })
	end
end

-- A teak deck on sloping sand (`ground`: the sand's height along z): level, its top just above
-- the sand at its highest edge (so nothing on it ever sinks into the slope), its foot sunk below
-- the sand at its lowest. Returns its top.
local function deck(parent: Instance, o: Vector3, x: number, z: number, w: number, d: number, ground: (number) -> number): number
	local top = math.max(ground(z - d / 2), ground(z + d / 2)) + 0.25
	local foot = math.min(ground(z - d / 2), ground(z + d / 2)) - 1
	Kit.part(parent, "BeachDeck", Vector3.new(w, top - foot, d), CFrame.new(o + Vector3.new(x, (top + foot) / 2, z)), DECK)
	return top
end
local function pad(parent: Instance, o: Vector3, x: number, z: number, w: number, d: number): number
	return deck(parent, o, x, z, w, d, sandAt)
end

local function beach(parent: Instance, o: Vector3): BasePart
	local m = Kit.model(parent, "SouthBeach")
	-- Loungers in pairs on teak decks, each under its parasol, facing the lagoon.
	for i, x in { 8, 28, 112, 130 } do
		local y = pad(m, o, x, 118, 9.6, 9)
		Furniture.build("loungers", m, CFrame.lookAt(o + Vector3.new(x, y, 117), o + Vector3.new(x, y, 160)), { model = if i % 2 == 0 then "white" else nil, accent = if i % 2 == 0 then rgb(244, 238, 226) else rgb(28, 52, 92) }, false)
	end
	-- Cabanas along the top of the beach, under the summit's hill.
	for i, x in { -128, -110, -92, -74 } do
		local y = pad(m, o, x, 101, 10, 9)
		Furniture.build("cabana", m, CFrame.lookAt(o + Vector3.new(x, y, 101), o + Vector3.new(x, y, 140)), { accent = if i % 2 == 0 then rgb(28, 52, 92) else rgb(196, 160, 90) }, false)
	end
	-- Tiki torches along the top of the sand, and either side of the way onto the pier.
	for _, x in { -137, -119, -101, -83, -64, 4, 26, 92, 114, 130 } do
		torch(m, o + Vector3.new(x, sandAt(108), 108))
	end
	for _, x in { -29.5, -18.5 } do
		torch(m, o + Vector3.new(x, sandAt(114), 114))
	end
	-- The surf along the water's edge (each screen lets it breathe).
	for _, s in { { -120, 70 }, { -40, 70 }, { 40, 70 }, { 110, 56 } } do
		local foam = Kit.part(m, "Foam", Vector3.new(s[2], 0.08, 2.2), CFrame.new(o + Vector3.new(s[1], Plan.SEA + 0.06, 132.4)), look(rgb(250, 250, 246), Enum.Material.SmoothPlastic, 0, 0.45), TRIM)
		tag(foam, "IslandFoam")
	end
	-- The Coral Club: a raised deck under a thatched pavilion (the bar, the DJ), and its open
	-- terrace over the sand with a fire in a ring of sofas under strings of lights.
	local c = o + Vector3.new(66, sandAt(104) + 0.9, 104)
	local floorY = c.Y + 0.8
	Kit.part(m, "ClubDeck", Vector3.new(36, 0.8, 22), CFrame.new(c + Vector3.new(0, 0.4, 0)), DECK)
	slab(m, "ClubTerrace", o, 50, 82, floorY - o.Y - 0.8, floorY - o.Y, 115, 128, DECK)
	local posts: { [string]: BasePart } = {}
	for _, dx in { -16, 0, 16 } do
		for _, dz in { -9, 9 } do
			posts[dx .. ":" .. dz] = Kit.post(m, "ClubPost", 16, 0.9, c + Vector3.new(dx, -4.2, dz), TEAK)
		end
	end
	for _, dx in { -15, 15 } do
		for _, zz in { 121, 127.4 } do
			Kit.post(m, "TerracePost", floorY - o.Y + 1, 0.7, o + Vector3.new(66 + dx, -1, zz), TEAK, TRIM)
		end
	end
	slab(m, "TerraceGlass", o, 50.2, 81.8, floorY - o.Y, floorY - o.Y + 3, 127.6, 127.9, GLASS, { shadow = false })
	slab(m, "TerraceRail", o, 50.1, 81.9, floorY - o.Y + 3, floorY - o.Y + 3.2, 127.5, 128, GILT, TRIM)
	for k = 0, 3 do
		slab(m, "ClubStep", o, 44.6 - k * 1.4, 46 - k * 1.4, -3, floorY - o.Y - 1 - k * 0.95, 116, 124, DECK)
	end
	slab(m, "ClubLanding", o, 46, 50, -3, floorY - o.Y, 116, 124, DECK)
	for _, dz in { -1, 1 } do
		Kit.part(m, "ClubThatch", Vector3.new(40, 0.9, 13.6), CFrame.new(c + Vector3.new(0, 13.4, dz * 5.8)) * CFrame.Angles(dz * math.rad(22), 0, 0), THATCH)
	end
	Kit.part(m, "ClubRidge", Vector3.new(40.4, 0.8, 1), CFrame.new(c + Vector3.new(0, 15.8, 0)), TEAK, TRIM)
	Furniture.build("outdoorbar", m, CFrame.lookAt(c + Vector3.new(-8, 0.8, -6), c + Vector3.new(-8, 0.8, 20)), { accent = rgb(214, 176, 92) }, false)
	Kit.part(m, "DJBooth", Vector3.new(6, 3.4, 2.6), CFrame.new(c + Vector3.new(10, 2.5, -6)), L.blackLacquer)
	Kit.part(m, "DJGlow", Vector3.new(6.1, 0.3, 2.7), CFrame.new(c + Vector3.new(10, 1.2, -6)), look(rgb(255, 186, 90), Enum.Material.Neon), TRIM)
	for _, dx in { 6, 14 } do
		Kit.part(m, "Speaker", Vector3.new(2, 4, 2), CFrame.new(c + Vector3.new(dx, 2.8, -9)), L.blackLacquer)
	end
	Furniture.build("firepit", m, CFrame.lookAt(Vector3.new(c.X, floorY, o.Z + 121.5), Vector3.new(c.X, floorY, o.Z + 140)), { colour = rgb(236, 228, 210) }, false)
	-- The strings of lights: along both eaves under the thatch, and over the terrace from the
	-- pavilion's front posts to two poles at its seaward corners.
	local high = floorY + 9.6
	for _, dz in { -9, 9 } do
		local a, b = posts["-16:" .. dz], posts["16:" .. dz]
		lights(m, a, c + Vector3.new(-16, high - c.Y, dz), b, c + Vector3.new(16, high - c.Y, dz), 1.2, 8)
	end
	local poles: { BasePart } = {}
	for _, dx in { -16, 16 } do
		local pole = Kit.post(m, "LightPole", 11, 0.4, Vector3.new(c.X + dx, floorY, o.Z + 127.4), TEAK, TRIM)
		Kit.ball(m, "PoleCap", 0.6, Vector3.new(c.X + dx, floorY + 11.1, o.Z + 127.4), GILT, TRIM)
		table.insert(poles, pole)
	end
	local frontL, frontR = posts["-16:9"], posts["16:9"]
	local pl, pr = Vector3.new(c.X - 16, floorY + 10.4, o.Z + 127.4), Vector3.new(c.X + 16, floorY + 10.4, o.Z + 127.4)
	local fl, fr = c + Vector3.new(-16, high - c.Y, 9), c + Vector3.new(16, high - c.Y, 9)
	lights(m, frontL, fl, poles[1], pl, 0.9, 4)
	lights(m, frontR, fr, poles[2], pr, 0.9, 4)
	lights(m, poles[1], pl, poles[2], pr, 1.6, 9)
	lights(m, frontL, fl, poles[2], pr, 1.8, 10)
	lights(m, frontR, fr, poles[1], pl, 1.8, 10)
	local sign = Kit.part(m, "ClubSign", Vector3.new(14, 2.4, 0.3), CFrame.lookAt(c + Vector3.new(0, 9.6, 11.4), c + Vector3.new(0, 9.6, 30)), L.blackLacquer, TRIM)
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE CORAL CLUB", size = 0.55, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "barefoot, all day", size = 0.32, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 60, lit = false, brightness = 1.4 })
	-- The Pearl Exchange: a little white kiosk at the head of the pier, under a navy awning.
	local k = o + Vector3.new(-46, sandAt(104), 104)
	Kit.part(m, "KioskBase", Vector3.new(8, 3.4, 5), CFrame.new(k + Vector3.new(0, 1.7, 0)), WHITE)
	Kit.part(m, "KioskTop", Vector3.new(8.6, 0.3, 5.6), CFrame.new(k + Vector3.new(0, 3.55, 0)), look(rgb(232, 228, 220), Enum.Material.Marble, 0.1))
	Kit.part(m, "KioskBand", Vector3.new(8.1, 0.2, 5.1), CFrame.new(k + Vector3.new(0, 3.3, 0)), GILT, TRIM)
	for _, dx in { -3.8, 3.8 } do
		Kit.post(m, "KioskPost", 5, 0.3, k + Vector3.new(dx, 3.7, -2.4), L.brass, TRIM)
	end
	Kit.part(m, "KioskAwning", Vector3.new(9, 0.3, 6.4), CFrame.new(k + Vector3.new(0, 8.8, -0.6)) * CFrame.Angles(math.rad(-10), 0, 0), NAVY_CANVAS, TRIM)
	Kit.part(m, "KioskValance", Vector3.new(9, 0.6, 0.1), CFrame.new(k + Vector3.new(0, 8.0, -3.8)), CANVAS, TRIM)
	local board = Kit.part(m, "ExchangeSign", Vector3.new(8, 1.6, 0.2), CFrame.lookAt(k + Vector3.new(0, 7.4, -3.2), k + Vector3.new(0, 7.4, -10)), L.blackLacquer, TRIM)
	Kit.engrave(board, Enum.NormalId.Front, {
		{ text = "THE PEARL EXCHANGE", size = 0.5, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "the island's own pieces, for your pearls", size = 0.34, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 80, lit = false, brightness = 1.4 })
	return Kit.part(m, "ExchangeCounter", Vector3.new(6, 1, 1), CFrame.new(k + Vector3.new(0, 3.2, -2.6)), UNSEEN, { collide = false, shadow = false })
end

---------------------------------------------------------------------------------------------------
-- The gardens, the summit, the marina
---------------------------------------------------------------------------------------------------
-- A limestone path from `a` to `b` (on the lowland), lamps along it on alternate sides.
local function path(m: Instance, o: Vector3, a: Vector3, b: Vector3, lamps: number)
	local fa, fb = o + Vector3.new(a.X, G - 0.36, a.Z), o + Vector3.new(b.X, G - 0.36, b.Z)
	Kit.part(m, "Path", Vector3.new(6, 1.2, (fb - fa).Magnitude), CFrame.lookAt((fa + fb) / 2, fb), PAVER)
	local dir = (fb - fa).Unit
	local right = dir:Cross(Vector3.new(0, 1, 0))
	for k = 1, lamps do
		local p = fa:Lerp(fb, k / (lamps + 1))
		lamp(m, Vector3.new(p.X, o.Y + G, p.Z) + right * (if k % 2 == 0 then 4.2 else -4.2))
	end
end

local function gardens(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Gardens")
	local c = o + Vector3.new(-30, G, 10)
	local MARBLE_W = look(rgb(240, 236, 228), Enum.Material.Marble, 0.06)
	local FOUNTAIN = look(rgb(70, 196, 210), Enum.Material.Glass, 0.3, 0.3)
	-- The fountain court: a round pool, three tiers, a gold finial.
	disc(m, "CourtPaving", 46, 1.2, c, c.Y + 0.15, PAVER)
	disc(m, "FountainRim", 20, 1.6, c, c.Y + 1.8, MARBLE_W)
	disc(m, "FountainWater", 18.4, 0.3, c, c.Y + 1.6, FOUNTAIN, TRIM)
	for i, tier in { { 3.4, 9 }, { 5.6, 5.4 }, { 7.4, 2.6 } } do
		Kit.post(m, "FountainStem", tier[1], 1.4 - i * 0.3, c + Vector3.new(0, 1, 0), MARBLE_W, TRIM)
		disc(m, "FountainBowl", tier[2], 0.6, c, c.Y + 1.3 + tier[1], MARBLE_W)
		disc(m, "FountainSheet", tier[2] - 0.6, 0.3, c, c.Y + 1.38 + tier[1], FOUNTAIN, TRIM)
	end
	Kit.ball(m, "Finial", 1.2, c + Vector3.new(0, 9.4, 0), GILT, TRIM)
	-- Clipped hedges round the court, benches facing the fountain and flowers beside them: each set
	-- in a gap between the ways into the court (the walk up from the jet, the paths east, south and
	-- south-east, the Lookout's stair), never across one.
	-- (The whole arc from the south path round past the Lookout's stair to the walk from the jet is
	-- left open: the stair is reached straight from either, or across the court.)
	for k, deg in { 13, 268, 308 } do
		local a = math.rad(deg)
		local p = c + Vector3.new(math.cos(a) * 17, 0.4, math.sin(a) * 17)
		bench(m, p - Vector3.new(0, 0.25, 0), c - p)
		local hp = c + Vector3.new(math.cos(a) * 21, 1.3, math.sin(a) * 21)
		Kit.part(m, "Hedge", Vector3.new(9, 2.4, 2.2), CFrame.lookAt(hp, c + Vector3.new(0, 1.3, 0)), look(rgb(52, 98, 46), Enum.Material.Grass))
		bush(m, c + Vector3.new(math.cos(a + 0.24) * 23, 0.3, math.sin(a + 0.24) * 23), 3.2, k)
		bush(m, c + Vector3.new(math.cos(a - 0.24) * 23, 0.3, math.sin(a - 0.24) * 23), 2.8, k + 2)
	end
	-- The paths: east to the Grand Villa's stair, south to the pier and to the Coral Club. (The
	-- walk up from the jet is the Arrival's; the Lookout's stair rises from the court's own edge.)
	path(m, o, Vector3.new(-8, 0, 2), Vector3.new(62, 0, -36), 3)
	path(m, o, Vector3.new(-28, 0, 33), Vector3.new(-24, 0, 116), 3)
	path(m, o, Vector3.new(-14, 0, 27), Vector3.new(52, 0, 92), 3)
	for i, p in { { 22, -4 }, { 36, -30 }, { -76, -18 }, { -8, 62 }, { 16, 38 }, { -42, 46 } } do
		bush(m, o + Vector3.new(p[1], G, p[2]), 3.2 + (i % 2) * 0.8, i)
	end
end

local function summit(parent: Instance, o: Vector3): BasePart
	local m = Kit.model(parent, "SunsetLookout")
	local c = o + Plan.Places.summit.at - Vector3.new(0, 2, 0) -- (the deck's underside: its top is the Lookout's height)
	local topY = c.Y + 2
	-- The deck on its drum of stone, a band round its edge.
	disc(m, "Drum", 40, 9, c, c.Y, STONE)
	disc(m, "Deck", 38.8, 2, c, topY, PAVER)
	disc(m, "DeckEdge", 40.8, 0.6, c, c.Y + 0.5, look(rgb(214, 202, 180), Enum.Material.Limestone), TRIM)
	-- A balustrade all round, posts and a rail; the way in from the stair on the east (angle 0).
	local n = 24
	for k = 1, n - 1 do
		local a = k * math.pi * 2 / n
		local p = Vector3.new(c.X + math.cos(a) * 18.6, topY, c.Z + math.sin(a) * 18.6)
		Kit.post(m, "Baluster", 3, 0.5, p, STONE, TRIM)
		if k < n - 1 then
			local a2 = (k + 1) * math.pi * 2 / n
			local q = Vector3.new(c.X + math.cos(a2) * 18.6, topY, c.Z + math.sin(a2) * 18.6)
			rod(m, "Rail", p + Vector3.new(0, 3.1, 0), q + Vector3.new(0, 3.1, 0), 0.6, STONE, TRIM)
		end
	end
	-- An invisible guard, so nobody tumbles off.
	for k = 1, 11 do
		local a = k * math.pi * 2 / 12
		local p = Vector3.new(c.X + math.cos(a) * 19.2, topY + 3, c.Z + math.sin(a) * 19.2)
		Kit.part(m, "Guard", Vector3.new(10.4, 7, 0.6), CFrame.lookAt(p, Vector3.new(c.X, topY + 3, c.Z)), UNSEEN, { shadow = false })
	end
	-- In the middle, the toast: a brass table with champagne on ice and two flutes.
	local mid = Vector3.new(c.X, topY, c.Z)
	Kit.post(m, "ToastStand", 3.4, 0.5, mid, L.brass)
	disc(m, "ToastTop", 4.4, 0.3, mid, topY + 3.7, MARBLE)
	disc(m, "IceBucket", 1.6, 1.6, mid, topY + 5.3, CHROME, TRIM)
	Kit.cylinder(m, "Bottle", 2.2, 0.6, CFrame.new(mid + Vector3.new(0.1, 5.4, 0)) * CFrame.Angles(0, 0, math.rad(80)), look(rgb(20, 60, 40), Enum.Material.Glass, 0.2), TRIM)
	for _, dx in { -1.4, 1.4 } do
		Kit.post(m, "Flute", 1.1, 0.3, mid + Vector3.new(dx, 3.7, 1.2), look(rgb(250, 226, 160), Enum.Material.Glass, 0.2, 0.3), TRIM)
	end
	local toast = Kit.part(m, "ToastSpot", Vector3.new(5, 4, 5), CFrame.new(mid + Vector3.new(0, 4, 0)), UNSEEN, { collide = false, shadow = false })
	-- Benches facing out, all round; lamps on the rim; a brass telescope to the west; the flag.
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local p = mid + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		bench(m, p, Vector3.new(math.cos(a), 0, math.sin(a)))
	end
	for k = 0, 5 do
		local a = math.rad(30 + k * 60)
		lamp(m, mid + Vector3.new(math.cos(a) * 16.8, 0, math.sin(a) * 16.8), 4.6)
	end
	local scope = mid + Vector3.new(math.cos(math.rad(196)) * 14, 0, math.sin(math.rad(196)) * 14)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		rod(m, "Tripod", scope + Vector3.new(math.cos(a) * 1.1, 0, math.sin(a) * 1.1), scope + Vector3.new(0, 3.6, 0), 0.16, L.brass, TRIM)
	end
	rod(m, "Telescope", scope + Vector3.new(1.6, 3.4, 0.3), scope + Vector3.new(-2.2, 4.4, -0.4), 0.55, L.brass, TRIM)
	flag(m, mid + Vector3.new(math.cos(math.rad(120)) * 17.4, 0, math.sin(math.rad(120)) * 17.4), 12, math.rad(200))
	-- The grand stair up the ridge from the gardens (the summit path's foot) to the deck's edge.
	local sp = Plan.SummitPath
	local foot = o + sp.foot
	local head = o + sp.head
	local dir = Vector3.new(head.X - foot.X, 0, head.Z - foot.Z).Unit
	-- (Its head where the line from the foot meets the deck's edge.)
	local edgeAt = head
	for _ = 1, 400 do
		local flat = Vector3.new(edgeAt.X - c.X, 0, edgeAt.Z - c.Z)
		if flat.Magnitude >= 19.6 then
			break
		end
		edgeAt -= dir * 0.1
	end
	flight(m, "LookoutStair", foot, Vector3.new(edgeAt.X, topY, edgeAt.Z), 7, o.Y + G - 1.5, STONE)
	for _, side in { -1, 1 } do
		lamp(m, foot + dir:Cross(Vector3.new(0, 1, 0)) * side * 6.4 - dir * 1.5, 5.5)
	end
	local sign = Kit.part(m, "LookoutSign", Vector3.new(9, 1.8, 0.3), CFrame.lookAt(foot - dir * 3 + Vector3.new(0, 3.4, 0) - dir:Cross(Vector3.new(0, 1, 0)) * 12, foot - dir * 10 + Vector3.new(0, 3.4, 0) - dir:Cross(Vector3.new(0, 1, 0)) * 12), L.blackLacquer, TRIM)
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE SUNSET LOOKOUT", size = 0.5, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "raise a glass to the day, once a day", size = 0.34, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 80, lit = false, brightness = 1.4 })
	Kit.post(m, "SignPost", 2.6, 0.24, (sign.CFrame * CFrame.new(0, -0.9, 0)).Position - Vector3.new(0, 2.5, 0), BLACK, TRIM)
	return toast
end

-- A yacht: a white hull with a raked bow, stacked decks with dark glass, a teak aft deck and a
-- radar arch, its ensign astern. `cf`: its waterline middle, bow to -Z.
local function yacht(parent: Instance, cf: CFrame, length: number, name: string, model: string?)
	local m = Kit.model(parent, model or "Yacht")
	local k = length / 50
	Kit.part(m, "Hull", Vector3.new(11 * k, 6 * k, 38 * k), cf * CFrame.new(0, 1 * k, 4 * k), HULL)
	wedge(m, "Bow", Vector3.new(11 * k, 6 * k, 12 * k), cf * CFrame.new(0, 1 * k, -21 * k) * CFrame.Angles(0, math.pi, 0), HULL)
	Kit.part(m, "Boot", Vector3.new(11.1 * k, 1.2 * k, 38.2 * k), cf * CFrame.new(0, -1.4 * k, 4 * k), NAVY, TRIM)
	Kit.part(m, "Deck", Vector3.new(10.4 * k, 0.4 * k, 42 * k), cf * CFrame.new(0, 4.1 * k, 2 * k), DECK)
	Kit.part(m, "MainDeckhouse", Vector3.new(8.6 * k, 4 * k, 22 * k), cf * CFrame.new(0, 6.3 * k, 2 * k), HULL)
	Kit.part(m, "MainGlass", Vector3.new(8.7 * k, 1.6 * k, 20 * k), cf * CFrame.new(0, 6.6 * k, 2 * k), DARK_GLASS, TRIM)
	Kit.part(m, "UpperDeckhouse", Vector3.new(7.4 * k, 3.2 * k, 14 * k), cf * CFrame.new(0, 9.9 * k, 0), HULL)
	Kit.part(m, "UpperGlass", Vector3.new(7.5 * k, 1.3 * k, 12 * k), cf * CFrame.new(0, 10.2 * k, -0.6 * k), DARK_GLASS, TRIM)
	Kit.part(m, "Flybridge", Vector3.new(8 * k, 0.4 * k, 12 * k), cf * CFrame.new(0, 11.7 * k, 2 * k), HULL)
	Kit.part(m, "RadarArch", Vector3.new(7 * k, 3 * k, 1 * k), cf * CFrame.new(0, 13.4 * k, 4 * k), HULL)
	Kit.part(m, "Radar", Vector3.new(4 * k, 0.3 * k, 0.6 * k), cf * CFrame.new(0, 15.2 * k, 4 * k), NAVY, TRIM)
	Kit.part(m, "Railing", Vector3.new(10.6 * k, 0.2 * k, 40 * k), cf * CFrame.new(0, 5.6 * k, 2 * k), CHROME, TRIM)
	for _, side in { -1, 1 } do
		Kit.part(m, "HullWindows", Vector3.new(0.12, 0.9 * k, 26 * k), cf * CFrame.new(side * 5.56 * k, 2.4 * k, 3 * k), DARK_GLASS, TRIM)
		Kit.part(m, "Rubbing", Vector3.new(0.14, 0.25 * k, 38 * k), cf * CFrame.new(side * 5.58 * k, 0.6 * k, 4 * k), CHROME, TRIM)
	end
	Kit.part(m, "SwimPlatform", Vector3.new(10 * k, 0.4 * k, 3 * k), cf * CFrame.new(0, -0.6 * k, 24.4 * k), DECK, TRIM)
	Kit.part(m, "UpperRail", Vector3.new(7.8 * k, 0.15 * k, 14.4 * k), cf * CFrame.new(0, 12.6 * k, 2 * k), CHROME, TRIM)
	local plate = Kit.part(m, "Transom", Vector3.new(9 * k, 2 * k, 0.2), cf * CFrame.new(0, 2 * k, 23.1 * k), HULL, TRIM)
	Kit.engrave(plate, Enum.NormalId.Back, { { text = string.upper(name), size = 0.6, font = Brand.Fonts.display, color = rgb(196, 160, 82) } }, { ppu = 60, lit = false })
	local stern = (cf * CFrame.new(0, 4.3 * k, 22.4 * k)).Position
	flag(m, stern, 4.5 * k, math.atan2(-cf.LookVector.X, -cf.LookVector.Z) + math.pi / 2, 0.55 * k)
end

local function marina(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Marina")
	local y = G - 0.3
	-- The pier, out from the western shore into deep water; bollards, lamps.
	Kit.part(m, "MarinaPier", Vector3.new(84, 0.6, 8), CFrame.new(o + Vector3.new(-278, y, 80)), DECK)
	for x = -316, -244, 8 do
		for _, dz in { -3.6, 3.6 } do
			Kit.post(m, "PierPost", 14, 0.8, o + Vector3.new(x, y - 13.6, 80 + dz), TEAK, TRIM)
		end
		Kit.post(m, "Bollard", 1.2, 0.8, o + Vector3.new(x, y + 0.3, 76.8), L.brass, TRIM)
	end
	for _, x in { -256, -284, -312 } do
		lamp(m, o + Vector3.new(x, y + 0.3, 83.2), 5)
	end
	yacht(m, CFrame.new(o + Vector3.new(-284, Plan.SEA, 103)) * CFrame.Angles(0, math.rad(90), 0), 62, "Sovereign")
	yacht(m, CFrame.new(o + Vector3.new(-302, Plan.SEA, 56)) * CFrame.Angles(0, math.rad(90), 0), 44, "Aurelia")
	yacht(m, CFrame.new(o + Vector3.new(-346, Plan.SEA, 74)) * CFrame.Angles(0, math.rad(80), 0), 36, "Celeste")
end

-- A postcard frame: a gilt frame on two posts, its name on a plaque, the view behind it.
local function postcard(parent: Instance, o: Vector3, p: { id: string, name: string, at: Vector3, look: Vector3 }): BasePart
	local m = Kit.model(parent, "Postcard_" .. p.id)
	local base = o + p.at
	local face = CFrame.lookAt(base, Vector3.new(o.X + p.look.X, base.Y, o.Z + p.look.Z))
	for _, side in { -1, 1 } do
		Kit.part(m, "FramePost", Vector3.new(0.4, 6, 0.4), face * CFrame.new(side * 3.4, 3, 0), GILT)
	end
	Kit.part(m, "FrameTop", Vector3.new(7.2, 0.5, 0.5), face * CFrame.new(0, 6.2, 0), GILT, TRIM)
	Kit.part(m, "FrameFoot", Vector3.new(7.2, 0.5, 0.5), face * CFrame.new(0, 1.6, 0), GILT, TRIM)
	local plate = Kit.part(m, "FramePlate", Vector3.new(3.6, 0.8, 0.2), face * CFrame.new(0, 0.9, 0.3), L.blackLacquer, TRIM)
	Kit.engrave(plate, Enum.NormalId.Back, { { text = string.upper(p.name), size = 0.66, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 90, lit = false })
	local spot = Kit.part(m, "PostcardSpot", Vector3.new(6, 6, 2), face * CFrame.new(0, 3.6, 2), UNSEEN, { collide = false, shadow = false })
	spot:SetAttribute("Postcard", p.id)
	return spot
end

---------------------------------------------------------------------------------------------------
-- The Grand Villa: a resort in tiers on the headland, facing south over the sea (the sunset on
-- its right hand, the beach and the pier before it)
---------------------------------------------------------------------------------------------------
-- From the sea up (each tier a solid block of pale stone from the sea floor, so nothing floats):
--   the Quay (T0, its top 6.3): a stone plaza along the shore: the sunken fire lounge (a ring of
--     sofas round a fire bowl), lamps, palms; the lit pier south into the sea, the great yacht
--     moored at it; a sand beach beside the pier with parasols and loungers
--   the Pool Terrace (T1, 18.5): the infinity pool, its southern edge vanishing over the Quay;
--     the aquarium in the terrace's face below; the glass dome lounge on its round dais; cabanas
--     and loungers; the slide spiralling down into the pool; the open-air cinema
--   the Villa Terrace (T2, 31): the villa's great room behind long glass, warm within; the
--     waterfall pouring from rocks at the terrace's edge into the pool; the helipad and its
--     helicopter; the tennis court
--   the villa's upper floor and its balcony (T3, 42.6), and on its roof the glass rotunda
-- Stairs join every tier; the Grand Villa's stair rises from the gardens to T2's western face.
local RESORT = { t0 = 6.3, t1 = 18.5, t2 = 31, t3 = 42.6, base = -14 }

local SLIDE = look(rgb(246, 246, 242), Enum.Material.SmoothPlastic, 0.12)
local CUSHION = look(rgb(238, 230, 214), Enum.Material.Fabric)
local FRAME_DARK = look(rgb(40, 34, 30), Enum.Material.Wood)

-- A sofa ring round a fire bowl: `n` curved sections facing the middle (a gap left at angle
-- `gap`, the way in), real seats in every section.
local function fireLounge(parent: Instance, centre: Vector3, radius: number, gap: number)
	local m = Kit.model(parent, "FireLounge")
	disc(m, "LoungeFloor", radius * 2 + 6, 0.4, centre, centre.Y + 0.15, look(rgb(206, 192, 168), Enum.Material.Limestone))
	disc(m, "FireBowl", 4.2, 1.6, centre, centre.Y + 1.75, look(rgb(54, 50, 48), Enum.Material.Slate))
	disc(m, "Coals", 3.2, 0.2, centre, centre.Y + 1.85, look(rgb(200, 70, 24), Enum.Material.Neon, nil, 0.15), TRIM)
	tag(Kit.part(m, "Flame", Vector3.new(1.4, 1.6, 1.4), CFrame.new(centre + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.rad(45), 0), FLAME, TRIM), "IslandTorch")
	local seats: { CFrame } = {}
	local n = 9
	local floorY = centre.Y + 0.15
	for i = 0, n - 1 do
		local a = gap + (i + 1) * (2 * math.pi / (n + 1))
		local p = centre + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		local frame = CFrame.lookAt(Vector3.new(p.X, floorY, p.Z), Vector3.new(centre.X, floorY, centre.Z))
		local segW = radius * (2 * math.pi / (n + 1)) + 0.3
		Kit.part(m, "SofaBase", Vector3.new(segW, 1.0, 2.8), frame * CFrame.new(0, 0.5, 0), FRAME_DARK)
		Kit.part(m, "SofaSeat", Vector3.new(segW, 0.5, 2.6), frame * CFrame.new(0, 1.25, -0.1), CUSHION)
		Kit.part(m, "SofaBack", Vector3.new(segW, 2.2, 0.8), frame * CFrame.new(0, 1.6, 1.4), CUSHION)
		table.insert(seats, frame * CFrame.new(0, 1.5, -0.5))
	end
	Furniture.seatsOn(m, "FireLoungeSeats", seats, "The fire lounge", 2)
end

-- A lounger built from parts: frame, cushion, a raised back; its seat at the cushion's top.
local function lounger(parent: Instance, cf: CFrame): CFrame
	Kit.part(parent, "LoungerFrame", Vector3.new(2.4, 0.9, 6.4), cf * CFrame.new(0, 0.45, 0), FRAME_DARK)
	Kit.part(parent, "LoungerPad", Vector3.new(2.2, 0.4, 4.2), cf * CFrame.new(0, 1.1, -1.0), CUSHION)
	Kit.part(parent, "LoungerBack", Vector3.new(2.2, 0.4, 2.6), cf * CFrame.new(0, 1.55, 2.1) * CFrame.Angles(math.rad(-32), 0, 0), CUSHION)
	return cf * CFrame.new(0, 1.3, -0.5)
end

-- The helicopter, parked: black with a gold line, its rotor at rest. `cf`: its skids' middle on
-- the pad, nose to -Z.
local function helicopter(parent: Instance, cf: CFrame)
	local m = Kit.model(parent, "Helicopter")
	local body = look(rgb(18, 18, 22), Enum.Material.SmoothPlastic, 0.2)
	local along = CFrame.Angles(0, math.rad(90), 0)
	Kit.cylinder(m, "Cabin", 7, 5, cf * CFrame.new(0, 3.6, 0) * along, body)
	Kit.ball(m, "Nose", 5, (cf * CFrame.new(0, 3.6, -3.5)).Position, body)
	Kit.ball(m, "Canopy", 4.2, (cf * CFrame.new(0, 4.2, -4.2)).Position, DARK_GLASS, TRIM)
	Kit.ball(m, "Rear", 4.6, (cf * CFrame.new(0, 3.8, 3.4)).Position, body)
	for _, side in { -1, 1 } do
		Kit.part(m, "Stripe", Vector3.new(0.12, 0.45, 6.4), cf * CFrame.new(side * 2.5, 3.1, 0), GILT, TRIM)
	end
	rod(m, "TailBoom", (cf * CFrame.new(0, 4.4, 5)).Position, (cf * CFrame.new(0, 5.2, 14)).Position, 1.1, body)
	Kit.part(m, "TailFin", Vector3.new(0.3, 3.2, 1.8), cf * CFrame.new(0, 6.4, 14) * CFrame.Angles(math.rad(-15), 0, 0), body, TRIM)
	Kit.part(m, "TailRotor", Vector3.new(0.12, 3.2, 0.4), cf * CFrame.new(0.4, 6, 14.4), CHROME, TRIM)
	for _, side in { -1, 1 } do
		Kit.cylinder(m, "Skid", 9, 0.35, cf * CFrame.new(side * 2.2, 0.2, 0) * along, CHROME, TRIM)
		for _, z in { -2.2, 2.2 } do
			rod(m, "SkidStrut", (cf * CFrame.new(side * 2.2, 0.2, z)).Position, (cf * CFrame.new(side * 1.4, 1.6, z)).Position, 0.25, CHROME, TRIM)
		end
	end
	Kit.post(m, "Mast", 1.2, 0.5, (cf * CFrame.new(0, 6, 0)).Position, CHROME, TRIM)
	Kit.cylinder(m, "Hub", 0.5, 1.2, cf * CFrame.new(0, 7.3, 0) * CFrame.Angles(0, 0, math.rad(90)), CHROME, TRIM)
	for _, a in { 20, 110 } do
		Kit.part(m, "Blade", Vector3.new(20, 0.12, 0.8), cf * CFrame.new(0, 7.45, 0) * CFrame.Angles(0, math.rad(a), 0), body, TRIM)
	end
end

-- The slide: a white chute with walls along a path of points (each { x, y, z }: its floor's top
-- on the centre line), segment by segment. Walkable all the way (no prompt), ending over the pool.
local function chute(parent: Instance, o: Vector3, pts: { Vector3 })
	for i = 1, #pts - 1 do
		local a, b = o + pts[i], o + pts[i + 1]
		local len = (b - a).Magnitude
		local cf = CFrame.lookAt((a + b) / 2, b)
		Kit.part(parent, "SlideFloor", Vector3.new(3.8, 0.4, len + 0.5), cf * CFrame.new(0, -0.2, 0), SLIDE)
		for _, side in { -1, 1 } do
			Kit.part(parent, "SlideWall", Vector3.new(0.35, 2.2, len + 0.5), cf * CFrame.new(side * 2.07, 0.7, 0), SLIDE, { shadow = false })
		end
	end
end

-- The glass dome lounge: a dais, a dome of glass on gold ribs, drapes tied back within, a curved
-- sofa and its table under a warm lamp.
local function dome(parent: Instance, centre: Vector3)
	local m = Kit.model(parent, "GlassDome")
	local R = 12
	disc(m, "Dais", 32, 1.2, centre, centre.Y + 0.6, PAVER)
	disc(m, "DaisEdge", 32.6, 0.4, centre, centre.Y + 0.3, GILT, TRIM)
	local floor = centre + Vector3.new(0, 0.6, 0)
	-- (The glass: a sphere of glass whose lower half is hidden in the dais; it doesn't stop anyone,
	-- so the lounge is open all round.)
	Kit.ball(m, "DomeGlass", R * 2, floor, look(rgb(214, 232, 240), Enum.Material.Glass, 0.25, 0.72), { collide = false, query = false, shadow = false })
	local ribs = 8
	for k = 0, ribs - 1 do
		local a = k * 2 * math.pi / ribs
		local prev = floor + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)
		for s = 1, 4 do
			local e = s / 4 * math.pi / 2
			local p = floor + Vector3.new(math.cos(a) * R * math.cos(e), R * math.sin(e), math.sin(a) * R * math.cos(e))
			rod(m, "Rib", prev, p, 0.32, GILT, TRIM)
			prev = p
		end
		local nextA = (k + 1) * 2 * math.pi / ribs
		rod(m, "BaseRing", floor + Vector3.new(math.cos(a) * R, 0.2, math.sin(a) * R), floor + Vector3.new(math.cos(nextA) * R, 0.2, math.sin(nextA) * R), 0.5, GILT, TRIM)
		if k % 2 == 0 then
			local d = floor + Vector3.new(math.cos(a + 0.2) * (R - 3), 3.6, math.sin(a + 0.2) * (R - 3))
			Kit.part(m, "Drape", Vector3.new(2.2, 7.2, 0.3), CFrame.lookAt(d, Vector3.new(floor.X, d.Y, floor.Z)), look(rgb(248, 244, 236), Enum.Material.Fabric, 0, 0.1), TRIM)
		end
	end
	Kit.ball(m, "Finial", 1.2, floor + Vector3.new(0, R + 0.4, 0), GILT, TRIM)
	Furniture.build("sofa", m, CFrame.lookAt(floor + Vector3.new(0, 0, -2.2), floor + Vector3.new(0, 0, 10)), { model = "curved", colour = rgb(240, 232, 216) }, false)
	disc(m, "LoungeTable", 3.6, 0.3, floor + Vector3.new(0, 0, 2.6), floor.Y + 1.6, MARBLE)
	Kit.post(m, "LoungeTableFoot", 1.3, 1, floor + Vector3.new(0, 0, 2.6), GILT, TRIM)
	Kit.part(m, "PendantCord", Vector3.new(0.08, 3, 0.08), CFrame.new(floor + Vector3.new(0, R - 1.6, 0)), GILT, TRIM)
	local glow = Kit.ball(m, "Pendant", 1.6, floor + Vector3.new(0, R - 3.4, 0), ROOM_GLOW, TRIM)
	tag(glow, "IslandGlow")
	glow:SetAttribute("Range", 20)
end

-- The aquarium in the Pool Terrace's face: a long tank behind glass, sand and coral, fish (each
-- screen lets them swim), lit blue.
local function aquarium(parent: Instance, o: Vector3, x0: number, x1: number, z0: number, z1: number, y0: number, y1: number)
	local m = Kit.model(parent, "Aquarium")
	slab(m, "TankBack", o, x0, x1, y0, y1, z0, z0 + 0.2, look(rgb(20, 70, 110), Enum.Material.SmoothPlastic))
	slab(m, "TankSand", o, x0, x1, y0, y0 + 0.9, z0 + 0.2, z1 - 0.3, look(rgb(236, 224, 190), Enum.Material.Sand))
	slab(m, "TankWater", o, x0, x1, y0 + 0.9, y1 - 0.4, z0 + 0.2, z1 - 0.3, look(rgb(40, 150, 196), Enum.Material.Glass, 0.1, 0.62), TRIM)
	slab(m, "TankGlass", o, x0, x1, y0, y1, z1 - 0.3, z1, look(rgb(200, 236, 250), Enum.Material.Glass, 0.3, 0.8), { shadow = false })
	for x = x0 + 6, x1 - 1, 6 do
		slab(m, "TankMullion", o, x - 0.25, x + 0.25, y0, y1, z1 - 0.4, z1 + 0.1, GILT, TRIM)
	end
	local corals = { rgb(255, 120, 110), rgb(250, 190, 90), rgb(200, 110, 220), rgb(255, 150, 120), rgb(120, 220, 200) }
	for i, c in { { 4, 2.6 }, { 11, 1.8 }, { 17, 2.2 }, { 24, 2.8 }, { 31, 1.9 } } do
		Kit.ball(m, "Coral", c[2], o + Vector3.new(x0 + c[1], y0 + 1.2, z0 + 1.6 + (i % 2) * 1.4), look(corals[i], Enum.Material.SmoothPlastic), TRIM)
	end
	local fishColours = { rgb(255, 170, 60), rgb(250, 240, 120), rgb(90, 200, 255), rgb(255, 110, 140), rgb(250, 250, 250) }
	for i = 0, 9 do
		local fx = x0 + 3 + ((i * 7.3) % (x1 - x0 - 6))
		local fy = y0 + 2.6 + ((i * 1.7) % (y1 - y0 - 4.2))
		local fz = z0 + 1.6 + (i % 3) * 1.4
		local cf = CFrame.new(o + Vector3.new(fx, fy, fz)) * CFrame.Angles(0, if i % 2 == 0 then math.pi / 2 else -math.pi / 2, 0)
		local colour = look(fishColours[i % #fishColours + 1], Enum.Material.SmoothPlastic)
		local fish = Kit.part(m, "Fish", Vector3.new(0.5, 0.9, 1.5), cf, colour, TRIM)
		tag(fish, "IslandFish")
		local tail = wedge(m, "FishTail", Vector3.new(0.2, 0.8, 0.6), cf * CFrame.new(0, 0, 1.0), colour, TRIM)
		tag(tail, "IslandFish")
	end
	for _, x in { x0 + (x1 - x0) * 0.25, x0 + (x1 - x0) * 0.75 } do
		tag(slab(m, "TankLight", o, x - 5, x + 5, y1 - 0.6, y1 - 0.4, z0 + 1, z1 - 1, POOL_LIGHT, TRIM), "IslandPool")
	end
end

-- A band of tall glass lit warm from within, on a terrace's south face at `z` (from x0 to x1,
-- y0 to y1): the rooms behind it glow at dusk (each screen lights them).
local function litFront(parent: Instance, o: Vector3, x0: number, x1: number, y0: number, y1: number, z: number)
	local glow = slab(parent, "RoomGlow", o, x0, x1, y0, y1, z, z + 0.12, ROOM_GLOW, TRIM)
	tag(glow, "IslandGlow")
	glow:SetAttribute("Range", 20)
	slab(parent, "FrontGlass", o, x0, x1, y0, y1, z + 0.12, z + 0.32, GLASS, { shadow = false })
	slab(parent, "FrontHead", o, x0 - 0.3, x1 + 0.3, y1, y1 + 0.5, z, z + 0.5, GILT, TRIM)
	slab(parent, "FrontSill", o, x0 - 0.3, x1 + 0.3, y0 - 0.4, y0, z, z + 0.5, BLACK, TRIM)
	local n = math.max(1, math.floor((x1 - x0) / 7))
	for k = 1, n - 1 do
		local x = x0 + (x1 - x0) * k / n
		slab(parent, "FrontMullion", o, x - 0.3, x + 0.3, y0, y1, z, z + 0.45, BLACK, TRIM)
	end
end

local function resort(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "GrandVilla")
	local t0, t1, t2, t3, base = RESORT.t0, RESORT.t1, RESORT.t2, RESORT.t3, RESORT.base
	---------------------------------------------------------------------------------------------
	-- The tiers (the Pool Terrace in pieces round the pool's basin and the aquarium's tank).
	---------------------------------------------------------------------------------------------
	slab(m, "Quay", o, 100, 236, base, t0, 56, 94, PAVER)
	slab(m, "QuayEdge", o, 99.4, 236.6, t0 - 0.6, t0 + 0.08, 94, 94.6, STONE, TRIM)
	slab(m, "QuayEdge", o, 236, 236.6, t0 - 0.6, t0 + 0.08, 56, 94, STONE, TRIM)
	slab(m, "PoolTerrace", o, 100, 146, base, t1, 6, 50, STONE)
	slab(m, "PoolTerrace", o, 200, 236, base, t1, 6, 56, STONE)
	slab(m, "PoolTerrace", o, 146, 200, base, t1 - 4, 6, 44, STONE)
	slab(m, "PoolTerrace", o, 146, 200, base, t1, 47.6, 56, STONE)
	slab(m, "PoolTerrace", o, 138, 146, base, t1, 50, 56, STONE)
	slab(m, "PoolTerrace", o, 100, 138, t1 - 2, t1, 50, 56, STONE)
	slab(m, "PoolTerrace", o, 100, 138, base, t0, 50, 56, STONE)
	slab(m, "VillaTerrace", o, 100, 236, base, t2, -46, 6, STONE)
	-- Glass balustrades edged in gold round the terraces' open edges (gaps where stairs, the
	-- waterfall and the slide meet them).
	local function balustrade(x0: number, x1: number, z0: number, z1: number, y: number)
		slab(m, "Balustrade", o, x0, x1, y, y + 3.2, z0, z1, GLASS, { shadow = false })
		slab(m, "BalustradeRail", o, x0 - 0.05, x1 + 0.05, y + 3.2, y + 3.42, z0 - 0.08, z1 + 0.08, GILT, TRIM)
	end
	-- The terraces' faces: long glass lit warm from within, beneath each tier.
	litFront(m, o, 154, 232, t0 + 1.6, t1 - 2.2, 56)
	litFront(m, o, 112, 150, t1 + 2.4, t2 - 2.2, 6)
	litFront(m, o, 186, 198, t1 + 2.4, t2 - 2.2, 6)
	litFront(m, o, 218, 234, t1 + 2.4, t2 - 2.2, 6)
	balustrade(100.2, 141, 55.6, 55.9, t1)
	balustrade(151.4, 236, 55.6, 55.9, t1)
	balustrade(235.7, 236, 6.2, 55.6, t1)
	balustrade(100.1, 100.4, 26, 55.6, t1)
	balustrade(109.6, 158, 5.6, 5.9, t2)
	balustrade(178, 202.9, 5.6, 5.9, t2)
	balustrade(207.1, 235.7, 5.6, 5.9, t2)
	balustrade(235.7, 236, -45.6, 5.6, t2)
	balustrade(100.4, 236, -45.9, -45.6, t2)
	---------------------------------------------------------------------------------------------
	-- The Quay: the fire lounge, lamps, the stair up to the pool, the pier and the great yacht,
	-- the beach beside the pier.
	---------------------------------------------------------------------------------------------
	fireLounge(m, o + Vector3.new(122, t0, 79), 6.2, -math.pi / 2)
	for _, x in { 104, 140, 172, 206, 232 } do
		lamp(m, o + Vector3.new(x, t0, 92.4), 6)
	end
	for _, z in { 62, 76 } do
		lamp(m, o + Vector3.new(234.4, t0, z), 6)
	end
	flight(m, "QuayStair", o + Vector3.new(146, t0, 71), o + Vector3.new(146, t1, 56), 8, o.Y + t0 - 1, STONE)
	local deckY = 4
	slab(m, "PierStep", o, 191, 201, base, t0 - 0.9, 94.6, 96.4, DECK)
	local pier = slab(m, "ResortPier", o, 191, 201, deckY - 0.6, deckY, 96.4, 166, DECK)
	local _ = pier
	for z = 100, 164, 8 do
		for _, x in { 191.6, 200.4 } do
			Kit.post(m, "PierPile", 18, 0.9, o + Vector3.new(x, deckY - 17.4, z), TEAK, TRIM)
		end
	end
	for i, z in { 104, 120, 136, 152, 164 } do
		lamp(m, o + Vector3.new(if i % 2 == 0 then 191.8 else 200.2, deckY, z), 5.2)
		Kit.post(m, "Bollard", 1.1, 0.8, o + Vector3.new(200.2, deckY, z - 6), L.brass, TRIM)
	end
	-- The great yacht, moored along the pier's east side, lit from below.
	local yachtAt = CFrame.new(o + Vector3.new(212, Plan.SEA, 140)) * CFrame.Angles(0, math.pi, 0)
	yacht(m, yachtAt, 80, "Maison Noire", "Superyacht")
	for _, side in { -1, 1 } do
		tag(Kit.part(m, "HullGlow", Vector3.new(0.2, 0.3, 58), yachtAt * CFrame.new(side * 8.9, -0.3, 4.6), POOL_LIGHT, TRIM), "IslandPool")
	end
	-- The beach beside the pier: parasols and loungers on teak decks, facing the sea.
	for _, x in { 152, 170 } do
		local y = deck(m, o, x, 106, 9.6, 9, sand2At)
		Furniture.build("loungers", m, CFrame.lookAt(o + Vector3.new(x, y, 105), o + Vector3.new(x, y, 160)), { model = "white", accent = rgb(244, 238, 226) }, false)
	end
	---------------------------------------------------------------------------------------------
	-- The Pool Terrace.
	---------------------------------------------------------------------------------------------
	-- The infinity pool (x 146..200, z 6..44): its southern edge a weir the water spills over into
	-- a trough below, so from the dome or the villa it runs straight into the sea.
	local pool = Kit.model(m, "pool")
	local water = t1 - 0.3
	slab(pool, "PoolFloor", o, 146, 200, t1 - 4, t1 - 3.7, 6, 44, POOL_TILE)
	slab(pool, "PoolTile", o, 146, 146.1, t1 - 3.7, t1 - 0.5, 6.1, 44, POOL_TILE, TRIM)
	slab(pool, "PoolTile", o, 199.9, 200, t1 - 3.7, t1 - 0.5, 6.1, 44, POOL_TILE, TRIM)
	slab(pool, "PoolTile", o, 146, 200, t1 - 3.7, t1 - 0.5, 6, 6.1, POOL_TILE, TRIM)
	slab(pool, "Weir", o, 146.1, 199.9, t1 - 3.7, water - 0.2, 44, 44.4, POOL_EDGE)
	local w = slab(pool, "Water", o, 146.1, 199.9, t1 - 3.7, water, 6.1, 44.4, POOL_WATER, TRIM)
	w:SetAttribute("Water", true)
	slab(pool, "Spill", o, 146, 200, t1 - 1.8, water, 44.4, 44.6, look(rgb(170, 230, 236), Enum.Material.Glass, 0.2, 0.45), TRIM)
	slab(pool, "Trough", o, 146, 200, base, t1 - 2, 44.4, 47.6, POOL_EDGE)
	slab(pool, "TroughWater", o, 146, 200, t1 - 2, t1 - 1.4, 44.6, 47.4, POOL_WATER, TRIM)
	for i = 0, 2 do
		local x = 146.1 + 2.4 * (i + 1)
		slab(pool, "PoolStep", o, x - 2.4, x, t1 - 3.7, t1 - 1.2 - i * 0.9, 28, 40, PAVER)
	end
	for _, x in { 156, 173, 190 } do
		tag(slab(pool, "PoolLight", o, x - 1, x + 1, t1 - 2.6, t1 - 2.1, 6.1, 6.2, POOL_LIGHT, TRIM), "IslandPool")
	end
	-- The aquarium, below the pool terrace's western end, its glass to the Quay.
	aquarium(m, o, 100.6, 138, 50, 56, t0, t1 - 2)
	slab(m, "TankEnd", o, 100, 100.6, t0, t1 - 2, 50, 56, STONE)
	-- The glass dome lounge on its dais, at the terrace's western end.
	dome(m, o + Vector3.new(124, t1, 30))
	-- Cabanas between the dome and the pool, facing the water.
	for _, z in { 14, 46 } do
		Furniture.build("cabana", m, CFrame.lookAt(o + Vector3.new(141.6, t1, z), o + Vector3.new(170, t1, z)), { accent = rgb(196, 160, 90) }, false)
	end
	-- Loungers along the terrace's southern edge, facing the sea over the glass.
	for _, x in { 164, 186 } do
		Furniture.build("loungers", m, CFrame.lookAt(o + Vector3.new(x, t1, 52.2), o + Vector3.new(x, t1, 90)), { model = "white", accent = rgb(28, 52, 92) }, false)
	end
	-- The slide: from the villa terrace's edge, south, round three quarters of a turn about its
	-- tower and out west over the pool's corner, where it drops you in.
	local slideModel = Kit.model(m, "Slide")
	local pts: { Vector3 } = { Vector3.new(205, t2, 3), Vector3.new(205, t2 - 0.6, 9.5), Vector3.new(205, t2 - 1.2, 16) }
	local cx, cz, r = 212, 16, 7
	local steps = 12
	for k = 1, steps do
		local phi = math.pi - k / steps * (1.5 * math.pi)
		local y = (t2 - 1.2) - (k / steps) * 8.6
		table.insert(pts, Vector3.new(cx + math.cos(phi) * r, y, cz + math.sin(phi) * r))
	end
	table.insert(pts, Vector3.new(204, t2 - 10.4, 9))
	table.insert(pts, Vector3.new(197.5, t2 - 11.2, 9))
	chute(slideModel, o, pts)
	Kit.post(slideModel, "SlideTower", t2 - 2 - t1, 3, o + Vector3.new(cx, t1, cz), WHITE)
	for _, phi in { math.pi / 2, 0, -math.pi / 2 } do
		local px, pz = cx + math.cos(phi) * r, cz + math.sin(phi) * r
		local k = (math.pi - phi) / (1.5 * math.pi)
		local y = (t2 - 1.2) - k * 8.6
		Kit.post(slideModel, "SlideLeg", y - 0.4 - t1, 0.7, o + Vector3.new(px, t1, pz), WHITE)
	end
	-- The open-air cinema at the terrace's eastern end: a great screen (a sunset on it) and two
	-- rows of loungers before it.
	local cinema = Kit.model(m, "Cinema")
	for _, z in { 23, 45 } do
		Kit.post(cinema, "ScreenPost", 16, 0.8, o + Vector3.new(234.6, t1, z), BLACK)
	end
	local frame = slab(cinema, "ScreenFrame", o, 234.2, 235, t1 + 3.6, t1 + 16, 22.4, 45.6, BLACK)
	local _f = frame
	local screen = slab(cinema, "Screen", o, 233.9, 234.2, t1 + 4.2, t1 + 15.4, 23, 45, look(rgb(30, 22, 40), Enum.Material.SmoothPlastic))
	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.Left
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 20
	sg.LightInfluence = 0
	sg.Brightness = 1.6
	sg.MaxDistance = 300
	sg.Parent = screen
	local sky = Instance.new("Frame")
	sky.Name = "Sunset"
	sky.BorderSizePixel = 0
	sky.Size = UDim2.fromScale(1, 1)
	sky.BackgroundColor3 = Color3.new(1, 1, 1)
	sky.Parent = sg
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(70, 50, 120)),
		ColorSequenceKeypoint.new(0.45, rgb(250, 130, 90)),
		ColorSequenceKeypoint.new(0.62, rgb(255, 206, 120)),
		ColorSequenceKeypoint.new(0.64, rgb(40, 120, 150)),
		ColorSequenceKeypoint.new(1, rgb(20, 60, 90)),
	})
	grad.Parent = sky
	local sun = Instance.new("Frame")
	sun.Name = "Sun"
	sun.AnchorPoint = Vector2.new(0.5, 0.5)
	sun.Position = UDim2.fromScale(0.5, 0.6)
	sun.Size = UDim2.fromScale(0.14, 0.26)
	sun.BackgroundColor3 = rgb(255, 236, 170)
	sun.BorderSizePixel = 0
	sun.Parent = sky
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = sun
	for row, x in { 222, 213 } do
		local seats: { CFrame } = {}
		local lift = if row == 2 then 0.6 else 0
		if row == 2 then
			slab(cinema, "CinemaRiser", o, x - 4, x + 4, t1, t1 + lift, 24, 44, DECK)
		end
		for _, z in { 27, 31.6, 36.4, 41 } do
			table.insert(seats, lounger(cinema, CFrame.lookAt(o + Vector3.new(x, t1 + lift, z), o + Vector3.new(x + 10, t1 + lift, z))))
		end
		Furniture.seatsOn(cinema, "CinemaSeats", seats, "The cinema", 2)
	end
	-- The stair up to the villa terrace, at its western end.
	flight(m, "TerraceStair", o + Vector3.new(105, t1, 24), o + Vector3.new(105, t2, 6), 6, o.Y + t1 - 1, STONE)
	---------------------------------------------------------------------------------------------
	-- The Villa Terrace.
	---------------------------------------------------------------------------------------------
	-- The waterfall: from a spring among rocks on the terrace's edge, down its face into the pool.
	for _, b in { { 157.5, t2 - 1, 5.2, 8 }, { 178.5, t2 - 1, 5.2, 8 }, { 156, t2 - 7, 7.2, 8.5 }, { 180, t2 - 7.5, 7.2, 8.5 }, { 159.5, t2 + 1.2, 3.6, 4.6 }, { 176.5, t2 + 1.4, 3.6, 5 }, { 168, t2 + 1.4, 3.8, 3.6 }, { 153.5, t1 + 2.4, 8.8, 6 }, { 182.5, t1 + 2.2, 8.8, 6 } } do
		Kit.ball(m, "FallRock", b[4], o + Vector3.new(b[1], b[2], b[3]), ROCK)
	end
	for _, p in { { 155, t2 + 2.6, 4.2 }, { 181, t2 + 2.8, 4.2 }, { 152, t1 + 5.4, 9 } } do
		bush(m, o + Vector3.new(p[1], p[2], p[3]), 3.4, math.floor(p[1]))
	end
	local falls = Kit.model(m, "Waterfall")
	slab(falls, "Spring", o, 161.5, 174.5, t2 - 0.5, t2 + 0.6, 2, 6.2, POOL_WATER, TRIM)
	local sheet = Kit.part(falls, "FallSheet", Vector3.new(13, t2 - water + 0.6, 0.6), CFrame.new(o + Vector3.new(168, (t2 + water) / 2, 6.6)) * CFrame.Angles(math.rad(-3), 0, 0), look(rgb(214, 244, 250), Enum.Material.Glass, 0.2, 0.42), TRIM)
	local _s = sheet
	for i, x in { 163.5, 167, 170.5 } do
		Kit.part(falls, "FallStreak", Vector3.new(0.7, t2 - water, 0.2), CFrame.new(o + Vector3.new(x, (t2 + water) / 2 + i * 0.2, 7)), look(rgb(250, 252, 255), Enum.Material.SmoothPlastic, 0, 0.35), TRIM)
	end
	tag(Kit.part(falls, "FallFoam", Vector3.new(15, 0.1, 5), CFrame.new(o + Vector3.new(168, water + 0.06, 9)), look(rgb(250, 252, 250), Enum.Material.SmoothPlastic, 0, 0.35), TRIM), "IslandFoam")
	tag(Kit.part(falls, "FallMist", Vector3.new(12, 1, 3), CFrame.new(o + Vector3.new(168, water + 0.6, 8.6)), UNSEEN, TRIM), "IslandMist")
	-- The helipad, its helicopter.
	local padAt = o + Vector3.new(119, t2, -6)
	disc(m, "Helipad", 23, 0.6, padAt, padAt.Y + 0.25, look(rgb(46, 48, 52), Enum.Material.Asphalt))
	disc(m, "HelipadRing", 20, 0.08, padAt, padAt.Y + 0.29, RUNWAY_PAINT, TRIM)
	disc(m, "HelipadInner", 18.4, 0.08, padAt, padAt.Y + 0.3, look(rgb(46, 48, 52), Enum.Material.Asphalt), TRIM)
	for _, b in { { -2.4, 0, 0.9, 8 }, { 2.4, 0, 0.9, 8 }, { 0, 0, 3.9, 0.9 } } do
		Kit.part(m, "HelipadH", Vector3.new(b[3], 0.06, b[4]), CFrame.new(padAt + Vector3.new(b[1], 0.33, b[2])), RUNWAY_PAINT, TRIM)
	end
	for k = 0, 7 do
		local a = k * math.pi / 4
		tag(Kit.ball(m, "PadLight", 0.5, padAt + Vector3.new(math.cos(a) * 11.2, 0.4, math.sin(a) * 11.2), look(rgb(255, 214, 140), Enum.Material.Neon), TRIM), "IslandLantern")
	end
	helicopter(m, CFrame.new(padAt + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(-120), 0))
	-- The tennis court, east of the villa: its surface, its lines, the net, a fence behind each
	-- baseline, lamps at its corners.
	local court = Kit.model(m, "TennisCourt")
	slab(court, "CourtApron", o, 208, 235, t2, t2 + 0.1, -44, 2, look(rgb(54, 116, 96), Enum.Material.SmoothPlastic))
	slab(court, "CourtSurface", o, 213, 231, t2 + 0.1, t2 + 0.16, -39, -3, look(rgb(42, 92, 156), Enum.Material.SmoothPlastic))
	local LINE = look(rgb(246, 246, 244), Enum.Material.SmoothPlastic)
	for _, l in { { 213, 231, -39, -38.7 }, { 213, 231, -3.3, -3 }, { 213, 213.3, -39, -3 }, { 230.7, 231, -39, -3 }, { 215.2, 215.5, -39, -3 }, { 228.5, 228.8, -39, -3 }, { 215.2, 228.8, -31.2, -30.9 }, { 215.2, 228.8, -11.1, -10.8 }, { 221.85, 222.15, -31.2, -10.8 } } do
		slab(court, "CourtLine", o, l[1], l[2], t2 + 0.16, t2 + 0.19, l[3], l[4], LINE, TRIM)
	end
	for _, x in { 211.6, 232.4 } do
		Kit.post(court, "NetPost", 3.6, 0.3, o + Vector3.new(x, t2, -21), BLACK, TRIM)
	end
	slab(court, "Net", o, 211.8, 232.2, t2 + 0.6, t2 + 3.3, -21.05, -20.95, look(rgb(20, 22, 24), Enum.Material.Fabric, 0, 0.45), TRIM)
	slab(court, "NetTape", o, 211.8, 232.2, t2 + 3.3, t2 + 3.6, -21.08, -20.92, LINE, TRIM)
	for _, z in { -43.6, 1.6 } do
		slab(court, "Fence", o, 208.2, 234.8, t2, t2 + 5, z - 0.1, z + 0.1, look(rgb(24, 40, 32), Enum.Material.Fabric, 0, 0.35), { shadow = false })
	end
	for _, p in { { 209, -43 }, { 234, -43 }, { 209, 1 }, { 234, 1 } } do
		lamp(court, o + Vector3.new(p[1], t2, p[2]), 8)
	end
	-- The villa: the great room (x 140..200, z -45..-4) behind long glass to the south and the
	-- west (a doorway open in the south glass), warm within; its roof the balcony; the upper
	-- floor set back; the glass rotunda on top.
	local fl, ceil = t2 + 0.3, t3 - 0.6
	slab(m, "VillaFloor", o, 140, 200, t2, fl, -45, -4, MARBLE)
	slab(m, "Wall", o, 140, 200, fl, ceil, -45, -44, PLASTER)
	slab(m, "Wall", o, 199, 200, fl, ceil, -44, -4, PLASTER)
	slab(m, "FeatureWall", o, 186, 187.4, fl, ceil, -44, -26, STONE)
	slab(m, "GlassWest", o, 140, 140.3, fl, ceil, -44, -4, GLASS, { shadow = false })
	slab(m, "GlassSouth", o, 140, 166.5, fl, ceil, -4.3, -4, GLASS, { shadow = false })
	slab(m, "GlassSouth", o, 173.5, 199, fl, ceil, -4.3, -4, GLASS, { shadow = false })
	for _, z in { -44, -34, -24, -14, -4 } do
		slab(m, "Mullion", o, 139.8, 140.5, fl, ceil, z - 0.35, z + 0.35, BLACK)
	end
	for _, x in { 148.2, 157.4, 166.5, 173.5, 182.6, 191.8 } do
		slab(m, "Mullion", o, x - 0.35, x + 0.35, fl, ceil, -4.5, -3.8, BLACK)
	end
	slab(m, "Roof", o, 138, 202, ceil, t3, -46, -2, WHITE)
	slab(m, "Soffit", o, 138.2, 201.8, ceil - 0.2, ceil, -45.8, -2.2, TEAK, TRIM)
	slab(m, "Fascia", o, 137.8, 202.2, t3 - 0.45, t3 - 0.05, -2, -1.8, GILT, TRIM)
	slab(m, "Fascia", o, 137.8, 138, t3 - 0.45, t3 - 0.05, -46, -2, GILT, TRIM)
	slab(m, "Cove", o, 140.6, 199, ceil - 0.6, ceil - 0.35, -4.9, -4.6, COVE, TRIM)
	Furniture.build("sofa", m, CFrame.lookAt(o + Vector3.new(160, fl, -18), o + Vector3.new(160, fl, 20)), { model = "sectional", colour = rgb(236, 230, 216), accent = rgb(196, 160, 90) }, false)
	Furniture.build("coffeeTable", m, CFrame.lookAt(o + Vector3.new(160, fl, -11.5), o + Vector3.new(160, fl, 20)), { model = "marble" }, false)
	Furniture.build("piano", m, CFrame.lookAt(o + Vector3.new(178, fl, -16), o + Vector3.new(160, fl, -8)), {}, false)
	for _, p in { { 152, -20 }, { 168, -28 }, { 186, -14 } } do
		Kit.part(m, "PendantCord", Vector3.new(0.08, 2, 0.08), CFrame.new(o + Vector3.new(p[1], ceil - 1, p[2])), GILT, TRIM)
		local glow = Kit.ball(m, "Pendant", 1.4, o + Vector3.new(p[1], ceil - 2.4, p[2]), ROOM_GLOW, TRIM)
		tag(glow, "IslandGlow")
		glow:SetAttribute("Range", 22)
	end
	-- The balcony's glass, the stair up to it from the villa terrace.
	slab(m, "Balustrade", o, 138.2, 202, t3, t3 + 3, -2.3, -2, GLASS, { shadow = false })
	slab(m, "BalustradeRail", o, 138.1, 202.1, t3 + 3, t3 + 3.2, -2.4, -1.9, GILT, TRIM)
	slab(m, "Balustrade", o, 201.7, 202, t3, t3 + 3, -45.8, -2.3, GLASS, { shadow = false })
	slab(m, "Balustrade", o, 138, 138.3, t3, t3 + 3, -45.8, -18.2, GLASS, { shadow = false })
	slab(m, "Balustrade", o, 138, 138.3, t3, t3 + 3, -12, -2.3, GLASS, { shadow = false })
	flight(m, "BalconyStair", o + Vector3.new(134.6, t2, 3), o + Vector3.new(134.6, t3, -12), 4, o.Y + t2 - 1, PLASTER)
	slab(m, "BalconyLanding", o, 131.4, 138, t2, t3, -18.2, -12, PLASTER)
	-- The upper floor (x 150..196, z -42..-18): glass to the south and west, a doorway in it, the
	-- bed against the far wall, a warm lamp.
	local up, upTop = t3, t3 + 10
	slab(m, "Wall", o, 150, 196, up, upTop, -42, -41, PLASTER)
	slab(m, "Wall", o, 195, 196, up, upTop, -41, -18, PLASTER)
	slab(m, "GlassWest", o, 150, 150.3, up, upTop, -41, -18, GLASS, { shadow = false })
	slab(m, "GlassSouth", o, 150, 170, up, upTop, -18.3, -18, GLASS, { shadow = false })
	slab(m, "GlassSouth", o, 176, 195, up, upTop, -18.3, -18, GLASS, { shadow = false })
	for _, x in { 150, 160, 170, 176, 186 } do
		slab(m, "Mullion", o, x - 0.35, x + 0.35, up, upTop, -18.5, -17.8, BLACK)
	end
	slab(m, "Roof", o, 148, 198, upTop, upTop + 1, -44, -16, WHITE)
	slab(m, "Soffit", o, 148.2, 197.8, upTop - 0.2, upTop, -43.8, -16.2, TEAK, TRIM)
	slab(m, "Fascia", o, 147.8, 198.2, upTop + 0.3, upTop + 0.75, -16, -15.8, GILT, TRIM)
	slab(m, "Headboard", o, 193.6, 194.6, up, up + 4.4, -36, -26, TEAK)
	slab(m, "Bed", o, 186, 193.6, up, up + 2, -35.5, -26.5, look(rgb(242, 238, 230), Enum.Material.Fabric))
	local suite = Kit.ball(m, "Pendant", 1.2, o + Vector3.new(180, upTop - 2.2, -30), ROOM_GLOW, TRIM)
	tag(suite, "IslandGlow")
	suite:SetAttribute("Range", 18)
	-- The rotunda: a drum of glass lit from within under a thin roof, gold bands, black mullions.
	local rot = o + Vector3.new(173, upTop + 1, -30)
	disc(m, "RotundaBase", 18.4, 0.4, rot, rot.Y + 0.4, GILT)
	disc(m, "RotundaGlass", 16, 8, rot, rot.Y + 8.4, look(rgb(214, 228, 232), Enum.Material.Glass, 0.25, 0.55), { shadow = false })
	disc(m, "RotundaGlow", 15, 7.6, rot, rot.Y + 8.2, look(rgb(255, 206, 150), Enum.Material.Neon, nil, 0.7), TRIM)
	disc(m, "RotundaRoof", 21, 0.8, rot, rot.Y + 9.2, WHITE)
	disc(m, "RotundaBand", 21.3, 0.3, rot, rot.Y + 8.8, GILT, TRIM)
	for k = 0, 7 do
		local a = k * math.pi / 4
		Kit.part(m, "RotundaMullion", Vector3.new(0.4, 8, 0.4), CFrame.new(rot + Vector3.new(math.cos(a) * 8, 4.4, math.sin(a) * 8)), BLACK, TRIM)
	end
	-- Lamps and palms in planters on every tier.
	for _, p in { { 232, t2, 3.6 }, { 104, t1, 52 }, { 202, t1, 53 }, { 232, t1, 8 } } do
		lamp(m, o + Vector3.new(p[1], p[2], p[3]), 5.5)
	end
	for i, p in { { 108, t0, 89 }, { 231, t0, 88 }, { 104, t1, 46 }, { 231, t1, 52 }, { 103, t2, -14 }, { 231, t0, 62 } } do
		local at = o + Vector3.new(p[1], p[2], p[3])
		Kit.part(m, "Planter", Vector3.new(4.4, 1.6, 4.4), CFrame.new(at + Vector3.new(0, 0.8, 0)), WHITE)
		Kit.part(m, "PlanterSoil", Vector3.new(4, 0.1, 4), CFrame.new(at + Vector3.new(0, 1.62, 0)), look(rgb(70, 52, 38), Enum.Material.Ground), TRIM)
		palm(m, at + Vector3.new(0, 1.6, 0), 20 + (i % 3) * 3, 4 + (i % 2) * 2, i * 2.1)
	end
	-- The Grand Villa's stair down the hill to the gardens, lamps at its foot, the villa's sign.
	local footAt, headAt = o + Vector3.new(66, G, -36), o + Vector3.new(100, t2, -36)
	flight(m, "VillaStair", footAt, headAt, 6, o.Y + G - 1.5, STONE)
	for _, dz in { -5.4, 5.4 } do
		lamp(m, footAt + Vector3.new(-1.5, 0, dz), 5.5)
	end
	local sign = Kit.part(m, "VillaSign", Vector3.new(10, 2, 0.3), CFrame.lookAt(o + Vector3.new(106, t2 + 2.6, -45.2), o + Vector3.new(106, t2 + 2.6, -30)), L.blackLacquer, TRIM)
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE GRAND VILLA", size = 0.55, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "the infinity pool · the dome · the slide", size = 0.32, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 60, lit = false, brightness = 1.4 })
end

---------------------------------------------------------------------------------------------------
-- The Coastal Circuit (shared/Tracks): smooth charcoal road on the lowland between pale stone
-- kerbs, terracotta and stone on the bends, a chequered line under a gantry, and the island's garage.
---------------------------------------------------------------------------------------------------
local ROAD = look(rgb(44, 42, 42), Enum.Material.Asphalt, 0.03)
local EDGE = look(rgb(236, 234, 228), Enum.Material.SmoothPlastic)
local KERB_STONE = look(rgb(228, 218, 198), Enum.Material.Limestone)
local KERB_RED = look(rgb(176, 74, 54), Enum.Material.SmoothPlastic)

local function coast(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "CoastalCircuit")
	local samples = Tracks.samples("coast")
	local n = #samples
	local width = Tracks.byId.coast.width
	local top = o.Y + Plan.GROUND + Tracks.ROAD
	-- (Along the airstrip the runway is the road: its paint sits on the runway's surface.)
	local function surface(p: Vector3): number
		local x, z = p.X - o.X, p.Z - o.Z
		if x > -210 and x < 130 and z > -196 and z < -156 then
			return o.Y + G + 0.6
		end
		return top
	end
	-- The road: every other sample, a white slab with the black road laid on it a little
	-- narrower (its white edges showing either side); alternate slabs a hair apart in height, so
	-- where they overlap on the bends no two faces ever fight.
	local step = 2
	for i = 1, n, step do
		local a = samples[i]
		local b = samples[(i + step - 1) % n + 1]
		local y = surface(a)
		local lift = if (i // step) % 2 == 0 then 0 else 0.012
		local flatA, flatB = Vector3.new(a.X, y - 1, a.Z), Vector3.new(b.X, y - 1, b.Z)
		local len = (flatB - flatA).Magnitude
		if len > 0.1 then
			local mid = (flatA + flatB) / 2
			local cf = CFrame.lookAt(mid, flatB)
			if y == top then
				Kit.part(m, "Edge", Vector3.new(width + 1.6, 2, len + 1.6), cf * CFrame.new(0, lift, 0), KERB_STONE)
				Kit.part(m, "Road", Vector3.new(width - 1.2, 2, len + 1.6), cf * CFrame.new(0, 0.02 + lift, 0), ROAD)
			else
				for _, side in { -1, 1 } do
					Kit.part(m, "Edge", Vector3.new(0.5, 0.06, len + 1.6), cf * CFrame.new(side * (width / 2 - 0.5), 1.02 + lift, 0), EDGE, TRIM)
				end
			end
			-- Kerbs where the road bends.
			local c = samples[(i + 2 * step - 1) % n + 1]
			local d1 = (flatB - flatA).Unit
			local d2 = Vector3.new(c.X - b.X, 0, c.Z - b.Z)
			local bend = if d2.Magnitude > 0.1 then math.acos(math.clamp(d1:Dot(d2.Unit), -1, 1)) else 0
			if bend > math.rad(7) then
				for _, side in { -1, 1 } do
					Kit.part(m, "Kerb", Vector3.new(1.6, 0.16, len + 1.6), cf * CFrame.new(side * (width / 2 + 0.6), 1.04 + lift, 0), if (i // step) % 2 == 0 then KERB_RED else KERB_STONE, TRIM)
				end
			end
		end
	end
	-- The start line: chequered, under a gantry with its name.
	local p0, dir = Tracks.point("coast", 0)
	local lineY = surface(p0)
	local line = CFrame.lookAt(Vector3.new(p0.X, lineY, p0.Z), Vector3.new(p0.X + dir.X, lineY, p0.Z + dir.Z))
	for row = 0, 1 do
		for k = 0, 9 do
			local x = -width / 2 + width / 10 * (k + 0.5)
			Kit.part(m, "Check", Vector3.new(width / 10, 0.06, 1.2), line * CFrame.new(x, 0.06, -0.6 + row * 1.2), if (k + row) % 2 == 0 then EDGE else look(rgb(12, 12, 14), Enum.Material.SmoothPlastic), TRIM)
		end
	end
	for _, side in { -1, 1 } do
		Kit.post(m, "GantryPost", 16, 1.4, (line * CFrame.new(side * (width / 2 + 2.4), 0, 0)).Position, L.blackLacquer)
	end
	local beam = Kit.part(m, "GantryBeam", Vector3.new(width + 6, 3, 1.8), line * CFrame.new(0, 16.6, 0), L.blackLacquer)
	Kit.part(m, "GantryBand", Vector3.new(width + 6.2, 0.4, 1.9), line * CFrame.new(0, 15, 0), GILT, TRIM)
	Kit.engrave(beam, Enum.NormalId.Back, {
		{ text = "THE COASTAL CIRCUIT", size = 0.6, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "timed laps · take a car from the island's garage", size = 0.28, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 30, lit = false, brightness = 1.4, maxDistance = 260 })
	-- The island's garage: three bays beside the start straight, and its sign.
	for i = 1, #Tracks.COAST_CARS do
		local bay = Tracks.bay(i)
		for _, dz in { -4.2, 4.2 } do
			Kit.part(m, "BayLine", Vector3.new(16, 0.06, 0.3), CFrame.new(Vector3.new(bay.Position.X, top + 0.03, bay.Position.Z + dz)), { color = rgb(200, 168, 96), material = Enum.Material.SmoothPlastic, transparency = 0.3 }, TRIM)
		end
		Kit.part(m, "BayPad", Vector3.new(18, 2, 10), CFrame.new(Vector3.new(bay.Position.X, top - 1, bay.Position.Z)), ROAD)
	end
	local first = Tracks.bay(1).Position
	Kit.sign(m, "GarageSign", CFrame.lookAt(Vector3.new(first.X - 12, top, first.Z + 2), Vector3.new(first.X - 12, top, first.Z + 20)), 6.4, 2.6, {
		{ text = "THE ISLAND'S GARAGE", size = 0.4, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "Any car is yours to drive: cross the line for a timed lap.", size = 0.3, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, 4)
end

---------------------------------------------------------------------------------------------------
-- The Arrival: the walk from the jet's red carpet to the gardens, dressed. Past the welcome sign,
-- a round fountain where the walk begins; palms down it in pairs, clipped hedges, low garden
-- lights, benches facing it, a pergola heavy with bougainvillea, round beds of flowers out on the
-- lawns. Where the walk runs along the Coastal Circuit (it shares the road for a stretch), the road
-- is a boulevard: palms on each side outside its kerbs, planters at its edge. Nothing stands on
-- the road (it's raced), on the walk, or by the jet's airstair and carpet.
---------------------------------------------------------------------------------------------------
local BOUGAINVILLEA = { rgb(214, 40, 140), rgb(236, 88, 170), rgb(196, 30, 110), rgb(250, 140, 190) }
local HIBISCUS = { rgb(236, 52, 70), rgb(255, 150, 60), rgb(250, 220, 110) }

local function arrival(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Arrival")
	local samples = Tracks.samples("coast")
	local half = Tracks.byId.coast.width / 2
	-- How far a point (from the island's origin) is from the road's middle.
	local function offRoad(p: Vector3): number
		local best = math.huge
		for _, sm in samples do
			local d = math.sqrt((sm.X - o.X - p.X) ^ 2 + (sm.Z - o.Z - p.Z) ^ 2)
			if d < best then
				best = d
			end
		end
		return best
	end
	local function clear(p: Vector3, margin: number): boolean
		return offRoad(p) >= half + margin
	end
	local A = Vector3.new(Plan.Arrival.Position.X, G, Plan.Arrival.Position.Z)
	local court = Vector3.new(-30, G, 10)
	local dir = Vector3.new(court.X - A.X, 0, court.Z - A.Z).Unit
	local right = dir:Cross(Vector3.new(0, 1, 0))
	local length = (court - A).Magnitude - 23 -- (to the court's edge)
	local function at(sAlong: number, side: number): Vector3
		return A + dir * sAlong + right * side
	end
	local function ground(p: Vector3): Vector3
		return o + Vector3.new(p.X, groundAt(p.X, p.Z), p.Z)
	end
	-- The walk: from the carpet's end to where it meets the road, and on from the road to the
	-- court. (Between, it's the road's own stone-kerbed boulevard.)
	local onRoadFrom, onRoadTo = length, 0
	for sAlong = 0, length, 2 do
		if offRoad(at(sAlong, 0)) < half + 2 then
			onRoadFrom = math.min(onRoadFrom, sAlong)
			onRoadTo = math.max(onRoadTo, sAlong)
		end
	end
	if onRoadTo > onRoadFrom then
		path(m, o, at(5, 0), at(onRoadFrom, 0), 0)
		path(m, o, at(onRoadTo, 0), at(length, 0), 0)
	else
		path(m, o, at(5, 0), at(length, 0), 0)
	end
	-- Low garden lights, a bench, a palm, a bed: each only where it's clear of the road.
	local function bollard(p: Vector3)
		local g = ground(p)
		Kit.post(m, "BollardPost", 2.2, 0.5, g - Vector3.new(0, 0.3, 0), BLACK, TRIM)
		tag(Kit.part(m, "Bollard", Vector3.new(0.6, 0.45, 0.6), CFrame.new(g + Vector3.new(0, 2.1, 0)), LANTERN, TRIM), "IslandLantern")
	end
	local function bed(p: Vector3, k: number)
		local g = ground(p)
		disc(m, "FlowerBed", 7, 1.2, g, g.Y + 0.6, STONE)
		disc(m, "BedSoil", 6.2, 0.2, g, g.Y + 0.66, look(rgb(70, 52, 38), Enum.Material.Ground), TRIM)
		Kit.ball(m, "BedLeaves", 3, g + Vector3.new(0, 1.2, 0), LEAF, TRIM)
		for i = 0, 4 do
			local a = k + i * 2 * math.pi / 5
			local colours = if i % 2 == 0 then BOUGAINVILLEA else HIBISCUS
			Kit.ball(m, "Bloom", 1.5, g + Vector3.new(math.cos(a) * 2.1, 1.05, math.sin(a) * 2.1), look(colours[(i + k) % #colours + 1], Enum.Material.SmoothPlastic), TRIM)
		end
	end
	local function hedge(sAlong: number, side: number)
		local p = ground(at(sAlong, side))
		Kit.part(m, "Hedge", Vector3.new(1.6, 1.5, 8), CFrame.lookAt(p + Vector3.new(0, 0.6, 0), p + Vector3.new(0, 0.6, 0) + dir), look(rgb(52, 98, 46), Enum.Material.Grass))
	end
	-- The fountain where the walk begins: a round paved place, a basin and its bowl, lights round it.
	local fAt = 26
	local fc = ground(at(fAt, 0))
	disc(m, "FountainPlace", 18, 1.2, fc, fc.Y + 0.3, PAVER)
	disc(m, "FountainBasin", 8, 1.6, fc, fc.Y + 1.9, look(rgb(240, 236, 228), Enum.Material.Marble, 0.06))
	disc(m, "FountainWater", 7.2, 0.3, fc, fc.Y + 1.7, look(rgb(70, 196, 210), Enum.Material.Glass, 0.3, 0.3), TRIM)
	Kit.post(m, "FountainStem", 2.8, 0.8, fc + Vector3.new(0, 1.6, 0), look(rgb(240, 236, 228), Enum.Material.Marble), TRIM)
	disc(m, "FountainBowl", 3, 0.4, fc, fc.Y + 4.6, look(rgb(240, 236, 228), Enum.Material.Marble, 0.06), TRIM)
	disc(m, "FountainSheet", 2.4, 0.2, fc, fc.Y + 4.65, look(rgb(70, 196, 210), Enum.Material.Glass, 0.3, 0.3), TRIM)
	Kit.ball(m, "Finial", 0.8, fc + Vector3.new(0, 5.1, 0), GILT, TRIM)
	for k = 0, 3 do
		local a = math.pi / 4 + k * math.pi / 2
		local p = at(fAt, 0) + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)
		if clear(p, 3) then
			bollard(p)
		end
	end
	for _, side in { -1, 1 } do
		if clear(at(fAt, side * 17), 6) then
			bed(at(fAt, side * 17), fAt + side)
		end
	end
	-- Down the walk, before the road and after it: palms in pairs, hedges between them, low
	-- lights, benches facing the walk.
	local placed = 0
	for sAlong = 38, length - 8, 15 do
		if sAlong < onRoadFrom - 6 or sAlong > onRoadTo + 6 then
			for _, side in { -1, 1 } do
				local p = at(sAlong, side * 7.5)
				if clear(p, 5) then
					palm(m, ground(p) - Vector3.new(0, 0.4, 0), 22 + (placed % 3) * 2, 3 + (placed % 2) * 2, sAlong * 0.31 + side)
					placed += 1
				end
				if clear(at(sAlong + 7.5, side * 5.5), 4) and sAlong + 11.5 < length then
					hedge(sAlong + 7.5, side * 5.5)
				end
				if clear(at(sAlong + 3.5, side * 3.9), 3) then
					bollard(at(sAlong + 3.5, side * 3.9))
				end
			end
		end
	end
	-- The pergola over the walk past the road, bougainvillea over it; a bench either side.
	local pg = onRoadTo + 12
	if onRoadTo > onRoadFrom and pg + 4 < length and clear(at(pg, 5), 3) and clear(at(pg, -5), 3) then
		for _, ds in { -2.5, 2.5 } do
			for _, side in { -4.3, 4.3 } do
				Kit.post(m, "PergolaPost", 8.6, 0.6, ground(at(pg + ds, side)), TEAK, TRIM)
			end
		end
		local top = ground(at(pg, 0)).Y + 8.6
		for _, side in { -4.3, 4.3 } do
			local c = at(pg, side)
			Kit.part(m, "PergolaBeam", Vector3.new(0.6, 0.6, 7.4), CFrame.lookAt(Vector3.new(o.X + c.X, top, o.Z + c.Z), Vector3.new(o.X + c.X, top, o.Z + c.Z) + dir), TEAK, TRIM)
		end
		for k = -2, 2 do
			local c = at(pg + k * 1.4, 0)
			Kit.part(m, "PergolaSlat", Vector3.new(11.4, 0.3, 0.4), CFrame.lookAt(Vector3.new(o.X + c.X, top + 0.45, o.Z + c.Z), Vector3.new(o.X + c.X, top + 0.45, o.Z + c.Z) + dir), TEAK, TRIM)
		end
		for k = 0, 5 do
			local c = at(pg - 2.5 + (k % 3) * 2.5, if k < 3 then -4.6 else 4.6)
			Kit.ball(m, "Bougainvillea", 2.2, Vector3.new(o.X + c.X, top + 0.6 - (k % 2) * 1.6, o.Z + c.Z), look(BOUGAINVILLEA[k % #BOUGAINVILLEA + 1], Enum.Material.SmoothPlastic), TRIM)
		end
		for _, side in { -1, 1 } do
			local p = at(pg + 9, side * 6)
			if clear(p, 4) then
				bench(m, ground(p), -right * side)
			end
		end
	end
	-- Round beds of flowers out on the open lawns either side.
	for i, b in { { 60, 24 }, { 100, -26 }, { length - 30, 20 }, { length - 14, -18 } } do
		local p = at(b[1], b[2])
		if clear(p, 6) then
			bed(p, i * 3)
		end
	end
	-- The boulevard: where the walk shares the road, palms on each side outside its kerbs and
	-- planters at its edge, every so often along it.
	local last: Vector3? = nil
	for i = 1, #samples, 2 do
		local sm = samples[i] - o
		local nearWalk = false
		for sAlong = onRoadFrom, onRoadTo, 4 do
			if (Vector3.new(sm.X, 0, sm.Z) - at(sAlong, 0)).Magnitude < 8 then
				nearWalk = true
			end
		end
		local prevLast = last
		if nearWalk and (not prevLast or (sm - prevLast).Magnitude > 34) then
			last = sm
			local nxt = samples[i % #samples + 1] - o
			local tangent = Vector3.new(nxt.X - sm.X, 0, nxt.Z - sm.Z).Unit
			local normal = tangent:Cross(Vector3.new(0, 1, 0))
			for _, side in { -1, 1 } do
				local p = Vector3.new(sm.X, 0, sm.Z) + normal * side * (half + 5)
				if clear(p, 4.5) then
					palm(m, ground(p) - Vector3.new(0, 0.4, 0), 24, 3, i * 0.7 + side)
				end
				local q = Vector3.new(sm.X, 0, sm.Z) + normal * side * (half + 3) + tangent * 12
				if clear(q, 2.6) then
					local g = ground(q)
					Kit.part(m, "Planter", Vector3.new(3.2, 1.6, 3.2), CFrame.new(g + Vector3.new(0, 0.6, 0)), WHITE)
					Kit.ball(m, "PlanterShrub", 2.8, g + Vector3.new(0, 2.2, 0), LEAF, TRIM)
					Kit.ball(m, "Bloom", 1.2, g + Vector3.new(0.6, 3.2, 0.3), look(BOUGAINVILLEA[(i % 4) + 1], Enum.Material.SmoothPlastic), TRIM)
				end
			end
		end
	end
	-- A pair of palms half way along the walk east to the Grand Villa's stair.
	local e0, e1 = Vector3.new(-8, G, 2), Vector3.new(62, G, -36)
	local eDir = (e1 - e0).Unit
	local eRight = eDir:Cross(Vector3.new(0, 1, 0))
	for _, side in { -1, 1 } do
		local p = e0:Lerp(e1, 0.5) + eRight * side * 7
		palm(m, ground(p) - Vector3.new(0, 0.4, 0), 23, 3, side * 1.3)
	end
end

---------------------------------------------------------------------------------------------------
-- The palms' places (x, z, height, lean), round the shores, the beach and the gardens: each set
-- on the ground where it stands (on a slope, a beach, a lawn).
---------------------------------------------------------------------------------------------------
local PALMS = {
	-- The South Beach, between its cabanas, torches and loungers, and its two ends.
	{ -146, 104, 26, 8 }, { -119, 93, 24, 5 }, { -83, 93, 27, 7 }, { -58, 99, 23, 6 }, { -36, 101, 26, 8 },
	{ -10, 106, 25, 9 }, { 42, 106, 27, 8 }, { 90, 104, 24, 7 }, { 144, 110, 28, 10 }, { 184, 118, 23, 6 },
	-- The north shore and the airstrip's ends.
	{ -226, -150, 26, 7 }, { -214, -120, 22, 5 }, { -84, -112, 22, 4 }, { 18, -140, 24, 5 }, { 150, -150, 26, 6 },
	{ 164, -118, 22, 5 },
	-- The west shore and the marina.
	{ -196, 64, 26, 7 }, { -214, 2, 22, 5 }, { -204, -62, 24, 6 }, { -228, 44, 24, 8 },
	-- The headland's foot.
	{ 196, -74, 25, 7 }, { 150, -60, 23, 6 }, { 58, -52, 24, 5 }, { 56, -20, 22, 4 },
	-- The gardens.
	{ -58, -10, 21, 3 }, { -2, -16, 20, 3 }, { 4, 34, 22, 4 }, { -6, 54, 24, 6 }, { -62, 52, 22, 5 }, { 40, 66, 22, 4 },
}

---------------------------------------------------------------------------------------------------
-- Building it all
---------------------------------------------------------------------------------------------------
export type Built = { model: Model, home: BasePart, desk: BasePart, exchange: BasePart, toast: BasePart, postcards: { BasePart }, terrain: boolean }

function IslandBuild.build(parent: Instance, o: Vector3): Built
	local m = Kit.model(parent, "LuxuryIsland")
	local hasTerrain = terrain(o)
	if not hasTerrain then
		groundParts(m, o)
	end
	airstrip(m, o)
	local desk = gallery(m, o)
	resort(m, o)
	overwater(m, o)
	local exchange = beach(m, o)
	gardens(m, o)
	local toast = summit(m, o)
	marina(m, o)
	coast(m, o)
	arrival(m, o)
	local nature = Kit.model(m, "Palms")
	for i, p in PALMS do
		local y = groundAt(p[1], p[2])
		palm(nature, o + Vector3.new(p[1], y - 0.4, p[2]), p[3], p[4], i * 1.37)
	end
	local cards = {}
	for _, p in Plan.Postcards do
		table.insert(cards, postcard(m, o, p))
	end
	local home: BasePart? = nil
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PromptHome") then
			home = d
		end
	end
	return { model = m, home = home :: BasePart, desk = desk, exchange = exchange, toast = toast, postcards = cards, terrain = hasTerrain }
end

-- (For the tests and the viewer: the ground's height on the island, from its origin.)
IslandBuild.groundAt = groundAt

return IslandBuild

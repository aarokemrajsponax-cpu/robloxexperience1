--!strict
-- Luxury Island, built once when the house opens (shared/Island has the plan). The land and the
-- sea are Roblox terrain where the place has it (sand, grass, rock and crystal water, with the
-- lagoon shallow inside its reef); with no terrain (the tests), plain parts stand in. On it:
-- the airstrip and your jet, the Jet Gallery, the Grand Villa on its headland with the infinity
-- pool and the Sky Lounge, the overwater villas on their pier, the South Beach and the Coral
-- Club, the gardens and their fountain, the Sunset Lookout on the summit, the marina's yachts,
-- palms everywhere, and the postcard frames. Nothing here lights a light of its own (the glow is
-- Neon): each screen lights the island in its own guest's chosen light (World/IslandView).

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
local SAND = look(rgb(238, 224, 190), Enum.Material.Sand)
local GRASS = look(rgb(92, 152, 72), Enum.Material.Grass)
local ROCK = look(rgb(132, 124, 114), Enum.Material.Slate)
local SEA = look(rgb(36, 168, 196), Enum.Material.Glass, 0.25, 0.35)
local WHITE = look(rgb(242, 239, 232), Enum.Material.SmoothPlastic, 0.02)
local LIMESTONE = look(rgb(232, 226, 212), Enum.Material.Limestone)
local TEAK = look(rgb(150, 100, 60), Enum.Material.Wood)
local DECK = look(rgb(170, 124, 80), Enum.Material.WoodPlanks)
local THATCH = look(rgb(198, 166, 112), Enum.Material.Grass)
local GLASS = look(rgb(170, 214, 228), Enum.Material.Glass, 0.25, 0.55)
local DARK_GLASS = look(rgb(22, 30, 40), Enum.Material.Glass, 0.3, 0.1)
local POOL = look(rgb(70, 206, 222), Enum.Material.Glass, 0.3, 0.3)
local TRUNK = look(rgb(124, 94, 62), Enum.Material.Wood)
local TRUNK_RING = look(rgb(98, 72, 46), Enum.Material.Wood)
local LEAF = look(rgb(52, 132, 62), Enum.Material.SmoothPlastic)
local LEAF_LIGHT = look(rgb(84, 160, 74), Enum.Material.SmoothPlastic)
local COCONUT = look(rgb(96, 70, 40), Enum.Material.SmoothPlastic)
local CANVAS = look(rgb(244, 238, 226), Enum.Material.Fabric)
local STRIPE = look(rgb(36, 110, 160), Enum.Material.Fabric)
local LANTERN = look(rgb(255, 214, 150), Enum.Material.Neon, 0, 0.15)
local RUNWAY_PAINT = look(rgb(240, 240, 236), Enum.Material.SmoothPlastic)
local EDGE_LIGHT = look(rgb(255, 226, 170), Enum.Material.Neon)
local HULL = look(rgb(246, 246, 244), Enum.Material.SmoothPlastic, 0.05)
local NAVY = look(rgb(24, 32, 60), Enum.Material.SmoothPlastic, 0.05)
local CHROME = look(rgb(200, 204, 210), Enum.Material.Metal, 0.35)
local TRIM = { collide = false, query = false, shadow = false }
local SOFT = { collide = false, query = false }

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

---------------------------------------------------------------------------------------------------
-- The land and the sea
---------------------------------------------------------------------------------------------------
-- The island's ground, as cylinders (centre x, z, radius) of sand to the lowland, with grass on
-- the inner ones, and the hills (stacked, narrowing as they climb).
local LAND = {
	{ -30, -60, 175 }, { 110, -40, 124 }, { -150, 20, 112 }, { 10, 40, 92 }, { -60, -150, 120 }, { 40, -150, 110 },
	{ -170, -170, 70 },
}
local LAWNS = { { -30, -60, 150 }, { 110, -40, 100 }, { -150, 20, 88 }, { 10, 30, 64 } }
local HILLS = {
	{ x = 150, z = -10, steps = { { 76, 14 }, { 64, 22 }, { 54, 30 } } }, -- the Grand Villa's headland
	{ x = -120, z = 40, steps = { { 64, 14 }, { 50, 22 }, { 38, 30 }, { 26, 38 } } }, -- the summit
}
-- The lagoon: shallow sand inside the reef, south of the beach.
local LAGOON = { minX = -150, maxX = 130, minZ = 140, maxZ = 290, floor = -6 }

local function terrain(o: Vector3): boolean
	local t = Workspace:FindFirstChildOfClass("Terrain")
	if not t then
		return false
	end
	local ok, err = pcall(function()
		local T = t :: Terrain
		T.WaterColor = rgb(30, 170, 190)
		T.WaterTransparency = 0.9
		T.WaterReflectance = 0.55
		T.WaterWaveSize = 0.1
		T.WaterWaveSpeed = 6
		-- The sea, and its floor; the lagoon's floor (shallow, white sand); the reef.
		T:FillBlock(CFrame.new(o + Vector3.new(0, -22, 0)), Vector3.new(1600, 44, 1600), Enum.Material.Water)
		T:FillBlock(CFrame.new(o + Vector3.new(0, -46, 0)), Vector3.new(1600, 8, 1600), Enum.Material.Sand)
		local lw, ld = LAGOON.maxX - LAGOON.minX, LAGOON.maxZ - LAGOON.minZ
		T:FillBlock(CFrame.new(o + Vector3.new((LAGOON.minX + LAGOON.maxX) / 2, LAGOON.floor - 18, (LAGOON.minZ + LAGOON.maxZ) / 2)), Vector3.new(lw, 36, ld), Enum.Material.Sand)
		for i = 0, 14 do
			local a = math.rad(200 + i * 10)
			local p = o + Vector3.new(-10 + math.cos(a) * 170, -8, 150 - math.sin(a) * 150)
			T:FillBall(p, 12 + (i % 3) * 4, if i % 2 == 0 then Enum.Material.Rock else Enum.Material.Sand)
		end
		-- The land: sand up to the lowland, then grass, then the hills.
		for _, c in LAND do
			T:FillCylinder(CFrame.new(o + Vector3.new(c[1], (G - 40) / 2, c[2])), G + 40, c[3], Enum.Material.Sand)
		end
		for _, c in LAWNS do
			T:FillCylinder(CFrame.new(o + Vector3.new(c[1], G - 1.5, c[2])), 3, c[3], Enum.Material.Grass)
		end
		for _, h in HILLS do
			local base = G
			for _, step in h.steps do
				local r, top = step[1], step[2]
				T:FillCylinder(CFrame.new(o + Vector3.new(h.x, (base + top) / 2, h.z)), top - base + 2, r, Enum.Material.Grass)
				base = top
			end
		end
		-- The headland's sea cliff, and rocks along the shore.
		T:FillBall(o + Vector3.new(214, 8, -10), 34, Enum.Material.Rock)
		T:FillBall(o + Vector3.new(196, 4, 50), 22, Enum.Material.Rock)
		T:FillBall(o + Vector3.new(-250, 2, -60), 20, Enum.Material.Rock)
		T:FillBall(o + Vector3.new(-200, 30, 40), 26, Enum.Material.Rock)
		-- The South Beach: a long slope of sand from the lowland into the lagoon.
		T:FillWedge(CFrame.new(o + Vector3.new(-10, 0, 133)) * CFrame.Angles(0, math.pi, 0), Vector3.new(300, 12, 74), Enum.Material.Sand)
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
	Kit.part(m, "LagoonFloor", Vector3.new(LAGOON.maxX - LAGOON.minX, 1, LAGOON.maxZ - LAGOON.minZ), CFrame.new(o + Vector3.new((LAGOON.minX + LAGOON.maxX) / 2, LAGOON.floor - 0.5, (LAGOON.minZ + LAGOON.maxZ) / 2)), SAND)
	for _, c in LAND do
		Kit.cylinder(m, "Land", G + 2, c[3] * 2, CFrame.new(o + Vector3.new(c[1], (G - 2) / 2, c[2])) * CFrame.Angles(0, 0, math.rad(90)), SAND)
	end
	for _, c in LAWNS do
		Kit.cylinder(m, "Lawn", 0.4, c[3] * 2, CFrame.new(o + Vector3.new(c[1], G + 0.18, c[2])) * CFrame.Angles(0, 0, math.rad(90)), GRASS)
	end
	for _, h in HILLS do
		local base = G
		for _, step in h.steps do
			local r, top = step[1], step[2]
			Kit.cylinder(m, "Hill", top - base, r * 2, CFrame.new(o + Vector3.new(h.x, (base + top) / 2, h.z)) * CFrame.Angles(0, 0, math.rad(90)), GRASS)
			base = top
		end
	end
	wedge(m, "Beach", Vector3.new(300, 12, 74), CFrame.new(o + Vector3.new(-10, 0, 133)) * CFrame.Angles(0, math.pi, 0), SAND)
	Kit.ball(m, "Rock", 40, o + Vector3.new(214, 4, -10), ROCK)
	Kit.ball(m, "Rock", 26, o + Vector3.new(196, 0, 50), ROCK)
end

---------------------------------------------------------------------------------------------------
-- Palms and flowers
---------------------------------------------------------------------------------------------------
-- A palm: a trunk that leans and curves as it rises, rings along it, a crown of fronds that rise
-- and droop, and a few coconuts.
local function palm(parent: Instance, base: Vector3, height: number, lean: number, yaw: number)
	local m = Kit.model(parent, "Palm")
	local away = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(Vector3.new(0, 0, -1))
	local prev = base - Vector3.new(0, 1, 0)
	local segments = 5
	for i = 1, segments do
		local t = i / segments
		local p = base + Vector3.new(0, height * t, 0) + away * (lean * t ^ 1.7)
		rod(m, "Trunk", prev, p, 1.9 - 0.7 * t, TRUNK)
		if i < segments then
			Kit.cylinder(m, "Ring", 0.3, 2.0 - 0.7 * t, CFrame.lookAt(p, p + (p - prev).Unit) * CFrame.Angles(0, math.rad(90), 0), TRUNK_RING, TRIM)
		end
		prev = p
	end
	local top = prev
	for i = 0, 7 do
		local a = yaw + i * math.pi / 4 + (i % 2) * 0.2
		local turn = CFrame.new(top) * CFrame.Angles(0, a, 0)
		local rise = turn * CFrame.Angles(math.rad(14 - (i % 3) * 6), 0, 0) * CFrame.new(0, 0, -2.8)
		Kit.part(m, "Frond", Vector3.new(2.6, 0.12, 5.6), rise, if i % 2 == 0 then LEAF else LEAF_LIGHT, TRIM)
		local tip = turn * CFrame.Angles(math.rad(14 - (i % 3) * 6), 0, 0) * CFrame.new(0, 0, -5.4) * CFrame.Angles(math.rad(-38), 0, 0) * CFrame.new(0, 0, -2.4)
		Kit.part(m, "FrondTip", Vector3.new(1.8, 0.1, 5), tip, if i % 2 == 0 then LEAF_LIGHT else LEAF, TRIM)
	end
	for i = 0, 2 do
		local a = yaw + i * 2.1
		Kit.ball(m, "Coconut", 0.9, top + Vector3.new(math.cos(a) * 0.8, -0.7, math.sin(a) * 0.8), COCONUT, TRIM)
	end
end

-- A flowering bush: a mound of leaves with hibiscus blooms on it.
local BLOOMS = { rgb(236, 64, 96), rgb(255, 170, 64), rgb(255, 120, 170), rgb(250, 236, 120) }
local function bush(parent: Instance, at: Vector3, size: number, k: number)
	local m = Kit.model(parent, "Bush")
	Kit.ball(m, "Leaves", size, at + Vector3.new(0, size * 0.3, 0), LEAF, SOFT)
	for i = 0, 3 do
		local a = k + i * 1.7
		local p = at + Vector3.new(math.cos(a) * size * 0.38, size * 0.55, math.sin(a) * size * 0.38)
		Kit.ball(m, "Bloom", size * 0.22, p, look(BLOOMS[(k + i) % #BLOOMS + 1], Enum.Material.SmoothPlastic), TRIM)
	end
end

-- A tiki torch on the sand: a bamboo pole, a woven cup and its flame (lit on each screen).
local function torch(parent: Instance, at: Vector3)
	local m = Kit.model(parent, "Torch")
	Kit.post(m, "Pole", 6.4, 0.32, at, TRUNK, TRIM)
	for k = 1, 3 do
		Kit.cylinder(m, "Binding", 0.18, 0.42, CFrame.new(at + Vector3.new(0, 1.2 + k * 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), TRUNK_RING, TRIM)
	end
	Kit.cylinder(m, "Cup", 0.9, 0.8, CFrame.new(at + Vector3.new(0, 6.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), TRUNK_RING, TRIM)
	local flame = Kit.part(m, "Flame", Vector3.new(0.5, 1.1, 0.5), CFrame.new(at + Vector3.new(0, 7.6, 0)), look(rgb(255, 150, 50), Enum.Material.Neon, nil, 0.1), TRIM)
	Kit.part(m, "FlameCore", Vector3.new(0.28, 0.6, 0.28), CFrame.new(at + Vector3.new(0, 7.45, 0)), look(rgb(255, 230, 150), Enum.Material.Neon), TRIM)
	-- (Its light is each guest's screen's to give: World/IslandView. The island has none of its own.)
	CollectionService:AddTag(flame, "IslandTorch")
end

-- A hanging lantern: a glowing paper globe (lit brighter on a moonlit evening: World/IslandView).
local function lantern(parent: Instance, at: Vector3)
	local p = Kit.ball(parent, "Lantern", 1.1, at, LANTERN, TRIM)
	CollectionService:AddTag(p, "IslandLantern")
	return p
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
	local body = look(rgb(16, 16, 20), Enum.Material.SmoothPlastic, 0.12)
	local trim = look(rgb(214, 176, 96), Enum.Material.Metal, 0.2)
	local opts = if simple then TRIM else nil
	local y = 6.2 * s -- the fuselage's centre above the ground
	local function at(x: number, yy: number, z: number): CFrame
		return cf * CFrame.new(x * s, yy * s, z * s)
	end
	local along = CFrame.Angles(0, math.rad(90), 0) -- (a cylinder's length along the jet)
	-- The fuselage: the cabin, the nose (a taper and a round tip), the tail cone.
	paint(Kit.cylinder(m, "Fuselage", 34 * s, 7.6 * s, at(0, 6.2, 0) * along, body, opts), "body")
	paint(Kit.cylinder(m, "Nose", 7 * s, 6.8 * s, at(0, 6.1, -20.4) * along, body, opts), "body")
	paint(Kit.ball(m, "NoseTip", 6.6 * s, (at(0, 6, -23.6)).Position, body, opts), "body")
	paint(Kit.cylinder(m, "Tail", 8 * s, 6.4 * s, at(0, 6.4, 20.8) * along, body, opts), "body")
	paint(Kit.cylinder(m, "TailCone", 6 * s, 4.4 * s, at(0, 6.8, 27.6) * along, body, opts), "body")
	paint(Kit.ball(m, "TailTip", 3.6 * s, (at(0, 7, 30.6)).Position, body, opts), "body")
	-- The cheat line along each flank, and the windscreen.
	for _, side in { -1, 1 } do
		paint(Kit.part(m, "Stripe", Vector3.new(0.12 * s, 0.6 * s, 40 * s), at(side * 3.82, 5.6, -1), trim, TRIM), "stripe")
	end
	wedge(m, "Windscreen", Vector3.new(4.6 * s, 1.6 * s, 3 * s), at(0, 8.9, -20.6) * CFrame.Angles(0, math.pi, 0), DARK_GLASS, TRIM)
	if not simple then
		-- The cabin's oval windows, seven a side, and the door (open, its airstair down).
		for _, side in { -1, 1 } do
			for i = 0, 6 do
				Kit.cylinder(m, "Window", 0.2, 1.5, at(side * 3.78, 7.2, -12 + i * 3.6) * CFrame.Angles(0, 0, 0), DARK_GLASS, TRIM)
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
	-- The wings: swept, a little dihedral, winglets at the tips.
	for _, side in { -1, 1 } do
		local root = at(side * 3.4, 4.6, 2) * CFrame.Angles(0, side * math.rad(-28), side * math.rad(-4))
		paint(Kit.part(m, "Wing", Vector3.new(24 * s, 0.8 * s, 7.2 * s), root * CFrame.new(side * 12 * s, 0, 0), body, opts), "body")
		paint(Kit.part(m, "WingEdge", Vector3.new(24 * s, 0.82 * s, 0.6 * s), root * CFrame.new(side * 12 * s, 0, -3.5 * s), trim, TRIM), "trim")
		local tip = root * CFrame.new(side * 24 * s, 0, 0)
		paint(Kit.part(m, "Winglet", Vector3.new(0.5 * s, 4.2 * s, 3.4 * s), tip * CFrame.new(0, 2 * s, 1 * s) * CFrame.Angles(math.rad(-18), 0, side * math.rad(-12)), trim, opts), "trim")
		-- The engines on the rear fuselage.
		paint(Kit.cylinder(m, "Engine", 9 * s, 3.8 * s, at(side * 5.4, 8.6, 17) * along, body, opts), "body")
		Kit.cylinder(m, "Intake", 0.4 * s, 3.9 * s, at(side * 5.4, 8.6, 12.4) * along, trim, TRIM)
		Kit.cylinder(m, "Exhaust", 0.6 * s, 3 * s, at(side * 5.4, 8.6, 21.6) * along, look(rgb(30, 30, 34), Enum.Material.Metal), TRIM)
		Kit.part(m, "Pylon", Vector3.new(2 * s, 0.6 * s, 4 * s), at(side * 3.8, 8, 17), body, TRIM)
	end
	-- The tail: a swept fin, and the high tailplane on top.
	paint(wedge(m, "Fin", Vector3.new(0.8 * s, 12 * s, 10 * s), at(0, 14.6, 25.4), body, opts), "body")
	paint(Kit.part(m, "FinStripe", Vector3.new(0.84 * s, 1.2 * s, 6 * s), at(0, 16.4, 26.4), trim, TRIM), "stripe")
	paint(Kit.part(m, "Tailplane", Vector3.new(16 * s, 0.6 * s, 4.4 * s), at(0, 20.4, 28.4), body, opts), "body")
	local _ = y
	return m
end

---------------------------------------------------------------------------------------------------
-- The airstrip, the jet and the Jet Gallery
---------------------------------------------------------------------------------------------------
local function airstrip(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Airstrip")
	local z, x0, x1 = -176, -210, 130
	local mid = (x0 + x1) / 2
	Kit.part(m, "Runway", Vector3.new(x1 - x0, 0.6, 40), CFrame.new(o + Vector3.new(mid, G + 0.3, z)), L.asphalt)
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
	local cone = Kit.cylinder(m, "Windsock", 5, 1.6, CFrame.new(sock + Vector3.new(2.6, 11.6, 0)) * CFrame.Angles(0, 0, math.rad(-6)), look(rgb(255, 120, 60), Enum.Material.Fabric), TRIM)
	local _ = cone
	-- Your jet, and its welcome mat.
	IslandBuild.jet(m, CFrame.new(o) * Plan.Jet, 1, false)
	local stair = o + Plan.Airstair
	Kit.part(m, "RedCarpet", Vector3.new(4, 0.06, 18), CFrame.new(stair + Vector3.new(0, 0.66, 9)), look(rgb(150, 18, 30), Enum.Material.Carpet), TRIM)
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			local p = stair + Vector3.new(side * 3.4, 0.6, 3 + i * 4.4)
			Kit.post(m, "Stanchion", 3, 0.3, p, L.brass, TRIM)
			Kit.ball(m, "StanchionTop", 0.5, p + Vector3.new(0, 3.1, 0), L.brass, TRIM)
		end
	end
	-- The way home: at the foot of the airstair.
	local homeAt = Kit.part(m, "FlyHome", Vector3.new(4, 7, 4), CFrame.new(stair + Vector3.new(0, 3.6, 2)), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, shadow = false })
	homeAt:SetAttribute("PromptHome", true)
	-- The sign.
	Kit.sign(m, "WelcomeSign", CFrame.lookAt(o + Vector3.new(-140, G + 0.6, -160), o + Vector3.new(-132, G + 0.6, -150)), 7, 2.4, {
		{ text = "LUXURY ISLAND", size = 0.4, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "the Lookout, the villas, the lagoon's pearls · fly home from your jet", size = 0.34, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, 3.2)
end

local function gallery(parent: Instance, o: Vector3): BasePart
	local m = Kit.model(parent, "JetGallery")
	local c = o + Vector3.new(60, G, -134)
	local w, d, h = 64, 30, 16
	Kit.part(m, "Floor", Vector3.new(w, 0.8, d), CFrame.new(c + Vector3.new(0, 0.4, 0)), look(rgb(232, 228, 220), Enum.Material.Marble, 0.08))
	Kit.part(m, "Roof", Vector3.new(w + 6, 1.4, d + 6), CFrame.new(c + Vector3.new(0, h, 0)), WHITE)
	Kit.part(m, "Soffit", Vector3.new(w + 5.8, 0.2, d + 5.8), CFrame.new(c + Vector3.new(0, h - 0.8, 0)), TEAK, TRIM)
	Kit.part(m, "BackWall", Vector3.new(w, h, 1), CFrame.new(c + Vector3.new(0, h / 2, d / 2)), WHITE)
	for _, side in { -1, 1 } do
		Kit.part(m, "SideWall", Vector3.new(1, h, d), CFrame.new(c + Vector3.new(side * w / 2, h / 2, 0)), WHITE)
	end
	-- Its glass front, to the airstrip, between slim columns.
	for i = 0, 8 do
		local x = -w / 2 + i * (w / 8)
		Kit.part(m, "Column", Vector3.new(0.8, h, 0.8), CFrame.new(c + Vector3.new(x, h / 2, -d / 2)), WHITE)
	end
	Kit.part(m, "Glass", Vector3.new(w, h - 1.4, 0.3), CFrame.new(c + Vector3.new(0, (h - 1.4) / 2 + 0.8, -d / 2)), GLASS, { shadow = false })
	-- The door in the middle of the glass (an opening).
	local door = Kit.part(m, "DoorGap", Vector3.new(10, 10, 1), CFrame.new(c + Vector3.new(0, 5.8, -d / 2)), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, shadow = false })
	local _ = door
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
-- The Grand Villa, on the headland
---------------------------------------------------------------------------------------------------
local function grandVilla(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "GrandVilla")
	local top = 30
	local c = o + Vector3.new(150, top, -10)
	-- The terrace it stands on: pale stone, edged in white.
	Kit.part(m, "Terrace", Vector3.new(84, 1, 64), CFrame.new(c + Vector3.new(0, 0.5, 0)), LIMESTONE)
	-- The house: two white volumes under deep flat roofs, glass to the sea on the west and south.
	local function volume(centre: Vector3, w: number, d: number, h: number)
		Kit.part(m, "Wall", Vector3.new(w, h, 1), CFrame.new(centre + Vector3.new(0, h / 2 + 1, d / 2)), WHITE)
		Kit.part(m, "Wall", Vector3.new(1, h, d), CFrame.new(centre + Vector3.new(w / 2, h / 2 + 1, 0)), WHITE)
		Kit.part(m, "GlassWest", Vector3.new(0.3, h - 0.6, d - 1), CFrame.new(centre + Vector3.new(-w / 2, h / 2 + 1, 0)), GLASS, { shadow = false })
		Kit.part(m, "GlassSouth", Vector3.new(w - 1, h - 0.6, 0.3), CFrame.new(centre + Vector3.new(0, h / 2 + 1, -d / 2)), GLASS, { shadow = false })
		Kit.part(m, "Mullion", Vector3.new(0.6, h, 0.6), CFrame.new(centre + Vector3.new(-w / 2, h / 2 + 1, -d / 2)), WHITE)
		Kit.part(m, "Floor", Vector3.new(w, 0.4, d), CFrame.new(centre + Vector3.new(0, 1.2, 0)), look(rgb(226, 220, 206), Enum.Material.Marble, 0.08))
		Kit.part(m, "Roof", Vector3.new(w + 8, 1.2, d + 8), CFrame.new(centre + Vector3.new(0, h + 1.6, 0)), WHITE)
		Kit.part(m, "RoofSoffit", Vector3.new(w + 7.8, 0.2, d + 7.8), CFrame.new(centre + Vector3.new(0, h + 0.9, 0)), TEAK, TRIM)
	end
	volume(c + Vector3.new(14, 0, 8), 34, 22, 12)
	volume(c + Vector3.new(26, 13.2, 10), 20, 16, 9)
	-- Inside the great room: a long sofa toward the view, a low table, a chandelier of glass.
	Furniture.build("sofa", m, CFrame.lookAt(c + Vector3.new(14, 1.4, 12), c + Vector3.new(-30, 1.4, 12)), { model = "modern", colour = rgb(236, 230, 216), accent = rgb(170, 120, 60) }, false)
	Furniture.build("chair", m, CFrame.lookAt(c + Vector3.new(6, 1.4, 4), c + Vector3.new(14, 1.4, 12)), { model = "barrel", colour = rgb(226, 214, 190) }, false)
	Furniture.build("plant", m, CFrame.new(c + Vector3.new(28, 1.4, 16)), { model = "palm" }, false)
	-- The infinity pool along the terrace's western edge, its far side open to the sea.
	Furniture.build("pool", m, CFrame.lookAt(c + Vector3.new(-30, 1, -4), c + Vector3.new(-30, 1, -40)), { model = "infinity", length = 40, width = 10 }, false)
	for i = 0, 3 do
		Furniture.build("loungers", m, CFrame.lookAt(c + Vector3.new(-16, 1, -24 + i * 9), c + Vector3.new(-60, 1, -24 + i * 9)), { model = "white" }, false)
	end
	-- The Sky Lounge: on the great room's roof (its west half), a bar and chairs round a fire,
	-- reached by a stair up the house's west side and a short bridge.
	local roofY = 14.2
	Kit.part(m, "SkyDeck", Vector3.new(22, 0.4, 28), CFrame.new(c + Vector3.new(4, roofY + 0.2, 8)), DECK)
	Furniture.build("outdoorbar", m, CFrame.lookAt(c + Vector3.new(4, roofY + 0.4, 19), c + Vector3.new(4, roofY + 0.4, 0)), { model = "white", accent = rgb(214, 176, 92) }, false)
	Furniture.build("firepit", m, CFrame.new(c + Vector3.new(3, roofY + 0.4, 3)), { model = "black" }, false)
	for _, a in { 0.6, 2.4, 4.2 } do
		local p = c + Vector3.new(3 + math.cos(a) * 6.6, roofY + 0.4, 3 + math.sin(a) * 6.6)
		Furniture.build("chair", m, CFrame.lookAt(p, c + Vector3.new(3, roofY + 0.4, 3)), { model = "club", colour = rgb(236, 228, 210), material = "Fabric" }, false)
	end
	Kit.part(m, "SkyRail", Vector3.new(22, 2.6, 0.3), CFrame.new(c + Vector3.new(4, roofY + 1.7, -6)), GLASS, { shadow = false })
	for i = 0, 13 do
		Kit.part(m, "SkyStep", Vector3.new(4, 0.5, 1.2), CFrame.new(c + Vector3.new(-11, 1.3 + i * 0.95, -6 + i * 1.2)), LIMESTONE)
	end
	Kit.part(m, "SkyLanding", Vector3.new(4, 0.5, 4), CFrame.new(c + Vector3.new(-11, roofY + 0.2, 11.4)), LIMESTONE)
	Kit.part(m, "SkyBridge", Vector3.new(6, 0.5, 4), CFrame.new(c + Vector3.new(-6.5, roofY + 0.2, 11.4)), LIMESTONE)
	-- Glass balustrades round the terrace's open sides, and lanterns.
	Kit.part(m, "Balustrade", Vector3.new(0.3, 3.2, 64), CFrame.new(c + Vector3.new(-42, 2.6, 0)), GLASS, { shadow = false })
	Kit.part(m, "Balustrade", Vector3.new(84, 3.2, 0.3), CFrame.new(c + Vector3.new(0, 2.6, -32)), GLASS, { shadow = false })
	for i = 0, 5 do
		lantern(m, c + Vector3.new(-40 + i * 16, 4.2, -31))
	end
	-- The stair down to the gardens: stone steps on the headland's western slope.
	local base = o + Vector3.new(68, G, -36)
	for i = 0, 24 do
		Kit.part(m, "VillaStep", Vector3.new(1.8, 1, 6), CFrame.new(base + Vector3.new(i * 1.6, 0.5 + i * 1.0, 0)), LIMESTONE)
	end
	local sign = Kit.part(m, "VillaSign", Vector3.new(12, 2, 0.3), CFrame.lookAt(c + Vector3.new(-6, 8, 19), c + Vector3.new(-6, 8, 30)), L.blackLacquer, TRIM)
	Kit.engrave(sign, Enum.NormalId.Back, {
		{ text = "THE GRAND VILLA", size = 0.55, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "the infinity pool · the Sky Lounge", size = 0.32, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 60, lit = false, brightness = 1.4 })
end

---------------------------------------------------------------------------------------------------
-- The overwater villas, the beach and the Coral Club
---------------------------------------------------------------------------------------------------
local function overwater(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Overwater")
	local x, deckY = -24, Plan.SEA + 3
	local z0, z1 = 118, 246
	-- The pier: a teak walk on posts, rope rails, lanterns along it.
	Kit.part(m, "Pier", Vector3.new(7, 0.6, z1 - z0), CFrame.new(o + Vector3.new(x, deckY, (z0 + z1) / 2)), DECK)
	for z = z0 + 4, z1, 9 do
		for _, side in { -1, 1 } do
			Kit.post(m, "PierPost", 9, 0.8, o + Vector3.new(x + side * 3.2, deckY - 8.6, z), TEAK, TRIM)
			Kit.post(m, "RailPost", 2.6, 0.3, o + Vector3.new(x + side * 3.3, deckY + 0.3, z), TEAK, TRIM)
		end
		if (z - z0) % 18 < 9 then
			lantern(m, o + Vector3.new(x + 3.3, deckY + 3.4, z))
		end
	end
	for _, side in { -1, 1 } do
		Kit.part(m, "Rope", Vector3.new(0.18, 0.18, z1 - z0), CFrame.new(o + Vector3.new(x + side * 3.3, deckY + 2.6, (z0 + z1) / 2)), look(rgb(214, 196, 160), Enum.Material.Fabric), TRIM)
	end
	-- Four villas off the pier: a deck with its plunge pool and loungers, a thatched bungalow with
	-- glass doors to the water, a ladder down into the lagoon.
	local villas = { { -1, 168 }, { 1, 168 }, { -1, 214 }, { 1, 214 } }
	for i, v in villas do
		local side, z = v[1], v[2]
		local cx = x + side * 19
		local c = o + Vector3.new(cx, deckY, z)
		local face = Vector3.new(side, 0, 0) -- out over the water, away from the pier
		Kit.part(m, "Walk", Vector3.new(9, 0.5, 4), CFrame.new(o + Vector3.new(x + side * 7.5, deckY, z)), DECK)
		Kit.part(m, "VillaDeck", Vector3.new(22, 0.6, 18), CFrame.new(c), DECK)
		for _, dx in { -9, 9 } do
			for _, dz in { -7, 7 } do
				Kit.post(m, "VillaPost", 9, 0.9, c + Vector3.new(dx, -8.6, dz), TEAK, TRIM)
			end
		end
		-- The bungalow, on the pier side of the deck.
		local hx = cx - side * 4
		local hc = o + Vector3.new(hx, deckY, z)
		for _, dz in { -4, 4 } do
			Kit.part(m, "BungalowBack", Vector3.new(1, 8, 4), CFrame.new(hc + Vector3.new(-side * 5.5, 4.3, dz)), look(rgb(236, 226, 206), Enum.Material.Plaster))
		end
		Kit.part(m, "BungalowLintel", Vector3.new(1, 1.4, 4), CFrame.new(hc + Vector3.new(-side * 5.5, 7.6, 0)), look(rgb(236, 226, 206), Enum.Material.Plaster))
		for _, dz in { -6, 6 } do
			Kit.part(m, "BungalowSide", Vector3.new(11, 8, 1), CFrame.new(hc + Vector3.new(0, 4.3, dz)), look(rgb(236, 226, 206), Enum.Material.Plaster))
		end
		for _, dz in { -3.75, 3.75 } do
			Kit.part(m, "GlassDoors", Vector3.new(0.3, 7.4, 3.5), CFrame.new(hc + Vector3.new(side * 5.5, 4, dz)), GLASS, { shadow = false })
		end
		-- The thatched roof: two slopes and a ridge.
		for _, dz in { -1, 1 } do
			Kit.part(m, "Thatch", Vector3.new(14, 0.8, 8.6), CFrame.new(hc + Vector3.new(0, 10.4, dz * 3.6)) * CFrame.Angles(dz * math.rad(28), 0, 0), THATCH)
		end
		Kit.part(m, "Ridge", Vector3.new(14.4, 0.7, 0.9), CFrame.new(hc + Vector3.new(0, 12.4, 0)), TEAK, TRIM)
		-- The plunge pool and the loungers, on the open side.
		local px = cx + side * 5
		Furniture.build("pool", m, CFrame.lookAt(o + Vector3.new(px, deckY + 0.3, z - 3), o + Vector3.new(px, deckY + 0.3, z - 20)), { model = "lagoon", length = 8, width = 5 }, false)
		for _, dz in { 4.5 } do
			Furniture.build("loungers", m, CFrame.lookAt(o + Vector3.new(px, deckY + 0.3, z + dz), o + Vector3.new(px + side * 30, deckY + 0.3, z + dz)), {}, false)
		end
		-- A ladder down into the lagoon.
		local lx = cx + side * 11.2
		for _, dz in { -0.9, 0.9 } do
			Kit.part(m, "LadderRail", Vector3.new(0.2, 7, 0.2), CFrame.new(o + Vector3.new(lx, deckY - 2.2, z + dz)), CHROME, TRIM)
		end
		for k = 0, 4 do
			Kit.part(m, "LadderRung", Vector3.new(0.2, 0.2, 1.8), CFrame.new(o + Vector3.new(lx, deckY - 0.6 - k * 1.3, z)), CHROME, TRIM)
		end
		lantern(m, c + Vector3.new(side * 10.4, 3, -8.4))
		lantern(m, c + Vector3.new(side * 10.4, 3, 8.4))
		local plate = Kit.part(m, "VillaPlate", Vector3.new(3.4, 1.1, 0.2), CFrame.lookAt(o + Vector3.new(x + side * 3.8, deckY + 2.2, z), o + Vector3.new(x, deckY + 2.2, z)), L.blackLacquer, TRIM)
		Kit.engrave(plate, Enum.NormalId.Front, { { text = "VILLA " .. ({ "I", "II", "III", "IV" })[i], size = 0.6, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 90, lit = false })
		local _ = face
	end
end

local function parasol(parent: Instance, at: Vector3, stripes: boolean)
	local m = Kit.model(parent, "Parasol")
	Kit.post(m, "ParasolPole", 8, 0.3, at, TEAK, TRIM)
	Kit.cylinder(m, "ParasolCanopy", 0.5, 9, CFrame.new(at + Vector3.new(0, 7.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), CANVAS, TRIM)
	if stripes then
		Kit.cylinder(m, "ParasolBand", 0.52, 6, CFrame.new(at + Vector3.new(0, 7.81, 0)) * CFrame.Angles(0, 0, math.rad(90)), STRIPE, TRIM)
	end
end

local function beach(parent: Instance, o: Vector3): BasePart
	local m = Kit.model(parent, "SouthBeach")
	-- (The beach falls from the lowland at z 96 to the water's edge at z 133.)
	local function sandAt(z: number): number
		return G - 12 * math.clamp((z - 96) / 74, 0, 1)
	end
	-- Loungers in pairs under striped parasols, facing the lagoon.
	for i = 0, 5 do
		local x = 20 + i * 15
		local at = o + Vector3.new(x, sandAt(118), 118)
		parasol(m, at, i % 2 == 0)
		Furniture.build("loungers", m, CFrame.lookAt(at + Vector3.new(0, 0, 3), at + Vector3.new(0, 0, 40)), { model = if i % 2 == 0 then "white" else nil }, false)
	end
	-- Cabanas along the top of the beach.
	for i = 0, 3 do
		local at = o + Vector3.new(-100 + i * 24, sandAt(100), 100)
		Furniture.build("cabana", m, CFrame.lookAt(at, at + Vector3.new(0, 0, 20)), {}, false)
	end
	-- Tiki torches along the top of the sand, between the cabanas and the loungers, and either side
	-- of the way onto the pier: firelight at dusk.
	for _, x in { -112, -88, -64, -36, 4, 28, 42, 92, 116, 136 } do
		torch(m, o + Vector3.new(x, sandAt(108), 108))
	end
	for _, x in { -29.5, -18.5 } do
		torch(m, o + Vector3.new(x, sandAt(112), 112))
	end
	-- The Coral Club: a raised deck under a thatched pavilion, its bar, and the DJ's booth.
	local c = o + Vector3.new(66, sandAt(104) + 0.9, 104)
	Kit.part(m, "ClubDeck", Vector3.new(36, 0.8, 22), CFrame.new(c + Vector3.new(0, 0.4, 0)), DECK)
	for _, dx in { -16, 0, 16 } do
		for _, dz in { -9, 9 } do
			Kit.post(m, "ClubPost", 16, 0.9, c + Vector3.new(dx, -4.2, dz), TEAK)
		end
	end
	-- (Steps down to the sand from the deck's lagoon side.)
	for k = 0, 3 do
		Kit.part(m, "ClubStep", Vector3.new(10, 0.6, 1.6), CFrame.new(c + Vector3.new(0, 0.5 - k * 0.6, 11.8 + k * 1.6)), DECK)
	end
	for _, dz in { -1, 1 } do
		Kit.part(m, "ClubThatch", Vector3.new(40, 0.9, 13.6), CFrame.new(c + Vector3.new(0, 13.4, dz * 5.8)) * CFrame.Angles(dz * math.rad(22), 0, 0), THATCH)
	end
	Kit.part(m, "ClubRidge", Vector3.new(40.4, 0.8, 1), CFrame.new(c + Vector3.new(0, 15.8, 0)), TEAK, TRIM)
	Furniture.build("outdoorbar", m, CFrame.lookAt(c + Vector3.new(-8, 0.8, -6), c + Vector3.new(-8, 0.8, 20)), { accent = rgb(214, 176, 92) }, false)
	local booth = Kit.part(m, "DJBooth", Vector3.new(6, 3.4, 2.6), CFrame.new(c + Vector3.new(10, 2.5, -6)), L.blackLacquer)
	Kit.part(m, "DJGlow", Vector3.new(6.1, 0.3, 2.7), CFrame.new(c + Vector3.new(10, 1.2, -6)), look(rgb(90, 220, 255), Enum.Material.Neon), TRIM)
	for _, dx in { 6, 14 } do
		Kit.part(m, "Speaker", Vector3.new(2, 4, 2), CFrame.new(c + Vector3.new(dx, 2.8, -9)), L.blackLacquer)
	end
	-- String lights over the deck.
	for k = 0, 10 do
		lantern(m, c + Vector3.new(-17 + k * 3.4, 10.4 - math.sin(k / 10 * math.pi) * 1.4, 9.6))
		lantern(m, c + Vector3.new(-17 + k * 3.4, 10.4 - math.sin(k / 10 * math.pi) * 1.4, -9.6))
	end
	local sign = Kit.part(m, "ClubSign", Vector3.new(14, 2.4, 0.3), CFrame.lookAt(c + Vector3.new(0, 9.6, 11.4), c + Vector3.new(0, 9.6, 30)), L.blackLacquer, TRIM)
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE CORAL CLUB", size = 0.55, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "barefoot, all day", size = 0.32, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 60, lit = false, brightness = 1.4 })
	-- The bonfire on the sand, logs round it.
	local fire = o + Vector3.new(112, sandAt(120), 120)
	Furniture.build("firepit", m, CFrame.new(fire), {}, false)
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5
		local p = fire + Vector3.new(math.cos(a) * 6.4, 0.6, math.sin(a) * 6.4)
		Kit.cylinder(m, "Log", 4.4, 1.2, CFrame.lookAt(p, fire) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.rad(90), 0, 0), TRUNK)
	end
	-- The Pearl Exchange: a little white kiosk at the head of the pier.
	local k = o + Vector3.new(-46, sandAt(104), 104)
	Kit.part(m, "KioskBase", Vector3.new(8, 3.4, 5), CFrame.new(k + Vector3.new(0, 1.7, 0)), WHITE)
	Kit.part(m, "KioskTop", Vector3.new(8.6, 0.3, 5.6), CFrame.new(k + Vector3.new(0, 3.55, 0)), look(rgb(232, 228, 220), Enum.Material.Marble, 0.1))
	for _, dx in { -3.8, 3.8 } do
		Kit.post(m, "KioskPost", 5, 0.3, k + Vector3.new(dx, 3.7, -2.4), L.brass, TRIM)
	end
	Kit.part(m, "KioskAwning", Vector3.new(9, 0.3, 6.4), CFrame.new(k + Vector3.new(0, 8.8, -0.6)) * CFrame.Angles(math.rad(-10), 0, 0), STRIPE, TRIM)
	local board = Kit.part(m, "ExchangeSign", Vector3.new(8, 1.6, 0.2), CFrame.lookAt(k + Vector3.new(0, 7.4, -3.2), k + Vector3.new(0, 7.4, -10)), L.blackLacquer, TRIM)
	Kit.engrave(board, Enum.NormalId.Front, {
		{ text = "THE PEARL EXCHANGE", size = 0.5, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "the island's own pieces, for your pearls", size = 0.34, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 80, lit = false, brightness = 1.4 })
	local _ = booth
	return Kit.part(m, "ExchangeCounter", Vector3.new(6, 1, 1), CFrame.new(k + Vector3.new(0, 3.2, -2.6)), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, shadow = false })
end

---------------------------------------------------------------------------------------------------
-- The gardens, the summit, the marina
---------------------------------------------------------------------------------------------------
local function gardens(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Gardens")
	local c = o + Vector3.new(-30, G, 10)
	-- The fountain court: a round pool, three tiers, a gold finial.
	Kit.cylinder(m, "CourtPaving", 0.4, 46, CFrame.new(c + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), LIMESTONE)
	Kit.cylinder(m, "FountainRim", 1.6, 20, CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(240, 236, 228), Enum.Material.Marble, 0.06))
	Kit.cylinder(m, "FountainWater", 1.62, 18.4, CFrame.new(c + Vector3.new(0, 1.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), POOL, TRIM)
	for i, tier in { { 3.4, 9 }, { 5.6, 5.4 }, { 7.4, 2.6 } } do
		Kit.post(m, "FountainStem", tier[1], 1.4 - i * 0.3, c + Vector3.new(0, 1, 0), look(rgb(240, 236, 228), Enum.Material.Marble), TRIM)
		Kit.cylinder(m, "FountainBowl", 0.6, tier[2], CFrame.new(c + Vector3.new(0, 1 + tier[1], 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(240, 236, 228), Enum.Material.Marble, 0.06))
		Kit.cylinder(m, "FountainSheet", 0.62, tier[2] - 0.6, CFrame.new(c + Vector3.new(0, 1.05 + tier[1], 0)) * CFrame.Angles(0, 0, math.rad(90)), POOL, TRIM)
	end
	Kit.ball(m, "Finial", 1.2, c + Vector3.new(0, 9.4, 0), { color = GOLD, material = Enum.Material.Metal, reflectance = 0.3 }, TRIM)
	-- Paths from the court: north to the airstrip, east to the villa's stair, west to the summit's,
	-- south to the beach.
	local paths = { { Vector3.new(0, 0, -22), Vector3.new(0, 0, -150) }, { Vector3.new(22, 0, 0), Vector3.new(112, 0, -46) }, { Vector3.new(-22, 0, 0), Vector3.new(-48, 0, 24) }, { Vector3.new(0, 0, 22), Vector3.new(40, 0, 104) } }
	for _, p in paths do
		local a, b = c + p[1] + Vector3.new(0, 0.12, 0), c + p[2] + Vector3.new(0, 0.12, 0)
		local mid = (a + b) / 2
		Kit.part(m, "Path", Vector3.new(6, 0.24, (b - a).Magnitude), CFrame.lookAt(mid, b), LIMESTONE)
	end
	-- Benches round the court, and the flowers.
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local p = c + Vector3.new(math.cos(a) * 17, 0.4, math.sin(a) * 17)
		Furniture.build("bench", m, CFrame.lookAt(p, c + Vector3.new(0, 0.4, 0)), { model = "garden" }, false)
		bush(m, c + Vector3.new(math.cos(a + 0.35) * 21, 0.3, math.sin(a + 0.35) * 21), 4, k)
		bush(m, c + Vector3.new(math.cos(a - 0.35) * 21, 0.3, math.sin(a - 0.35) * 21), 3.4, k + 2)
	end
end

local function summit(parent: Instance, o: Vector3): BasePart
	local m = Kit.model(parent, "SunsetLookout")
	local topY = 38
	local c = o + Vector3.new(-120, topY, 40)
	Kit.cylinder(m, "Deck", 2, 38, CFrame.new(c + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), LIMESTONE)
	Kit.cylinder(m, "DeckEdge", 2.1, 38.6, CFrame.new(c + Vector3.new(0, 0.95, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(214, 206, 190), Enum.Material.Limestone), TRIM)
	-- A balustrade all round, posts and a rail.
	-- (The way in from the stair is on the east side: angle 0.)
	local n = 28
	for k = 1, n - 2 do
		local a = k * math.pi * 2 / n
		local p = c + Vector3.new(math.cos(a) * 18.4, 2, math.sin(a) * 18.4)
		Kit.post(m, "Baluster", 3, 0.5, p, LIMESTONE, TRIM)
		local a2 = (k + 1) * math.pi * 2 / n
		local q = c + Vector3.new(math.cos(a2) * 18.4, 2, math.sin(a2) * 18.4)
		rod(m, "Rail", p + Vector3.new(0, 3.1, 0), q + Vector3.new(0, 3.1, 0), 0.6, LIMESTONE, TRIM)
	end
	-- An invisible guard, so nobody tumbles off.
	for k = 1, 11 do
		local a = k * math.pi * 2 / 12
		local p = c + Vector3.new(math.cos(a) * 19, 5, math.sin(a) * 19)
		Kit.part(m, "Guard", Vector3.new(10.4, 7, 0.6), CFrame.lookAt(p, c + Vector3.new(0, 5, 0)), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { shadow = false })
	end
	-- In the middle, the toast: a brass table with champagne on ice.
	Kit.post(m, "ToastStand", 3.4, 0.5, c + Vector3.new(0, 2, 0), L.brass)
	Kit.cylinder(m, "ToastTop", 0.3, 4.4, CFrame.new(c + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(232, 228, 220), Enum.Material.Marble, 0.1))
	Kit.cylinder(m, "IceBucket", 1.6, 1.6, CFrame.new(c + Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), CHROME, TRIM)
	Kit.cylinder(m, "Bottle", 2.2, 0.6, CFrame.new(c + Vector3.new(0.1, 7.4, 0)) * CFrame.Angles(0, 0, math.rad(80)), look(rgb(20, 60, 40), Enum.Material.Glass, 0.2), TRIM)
	local toast = Kit.part(m, "ToastSpot", Vector3.new(5, 4, 5), CFrame.new(c + Vector3.new(0, 6, 0)), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, shadow = false })
	-- Benches facing out, all round.
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local p = c + Vector3.new(math.cos(a) * 12, 2, math.sin(a) * 12)
		Furniture.build("bench", m, CFrame.lookAt(p, p + Vector3.new(math.cos(a), 0, math.sin(a))), { model = "garden" }, false)
	end
	-- The grand stair up from the gardens' west path.
	local base = o + Vector3.new(-52, G, 26)
	for i = 0, 33 do
		Kit.part(m, "LookoutStep", Vector3.new(1.6, 1, 7), CFrame.new(base + Vector3.new(-i * 1.5, 0.5 + i * 1.0, 0.44 * i)), LIMESTONE)
	end
	local sign = Kit.part(m, "LookoutSign", Vector3.new(9, 1.8, 0.3), CFrame.lookAt(c + Vector3.new(14, 4, -6), c + Vector3.new(30, 4, -6)), L.blackLacquer, TRIM)
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE SUNSET LOOKOUT", size = 0.5, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "raise a glass to the day, once a day", size = 0.34, font = Brand.Fonts.body, color = rgb(240, 230, 210) },
	}, { ppu = 80, lit = false, brightness = 1.4 })
	return toast
end

-- A yacht: a white hull with a raked bow, stacked decks with dark glass, a teak aft deck and a
-- radar arch. `cf`: its waterline middle, bow to -Z.
local function yacht(parent: Instance, cf: CFrame, length: number, name: string)
	local m = Kit.model(parent, "Yacht")
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
	local plate = Kit.part(m, "Transom", Vector3.new(9 * k, 2 * k, 0.2), cf * CFrame.new(0, 2 * k, 23.1 * k), HULL, TRIM)
	Kit.engrave(plate, Enum.NormalId.Back, { { text = string.upper(name), size = 0.6, font = Brand.Fonts.display, color = rgb(196, 160, 82) } }, { ppu = 60, lit = false })
end

local function marina(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "Marina")
	local y = G - 0.3
	Kit.part(m, "MarinaPier", Vector3.new(66, 0.6, 8), CFrame.new(o + Vector3.new(-269, y, 80)), DECK)
	for x = -298, -240, 8 do
		for _, dz in { -3.6, 3.6 } do
			Kit.post(m, "PierPost", 12, 0.8, o + Vector3.new(x, y - 11.6, 80 + dz), TEAK, TRIM)
		end
		Kit.post(m, "Bollard", 1.2, 0.8, o + Vector3.new(x, y + 0.3, 76.8), L.brass, TRIM)
	end
	yacht(m, CFrame.new(o + Vector3.new(-262, Plan.SEA, 104)) * CFrame.Angles(0, math.rad(90), 0), 62, "Sovereign")
	yacht(m, CFrame.new(o + Vector3.new(-252, Plan.SEA, 58)) * CFrame.Angles(0, math.rad(90), 0), 44, "Aurelia")
	yacht(m, CFrame.new(o + Vector3.new(-298, Plan.SEA, 64)) * CFrame.Angles(0, math.rad(80), 0), 36, "Celeste")
end

-- A postcard frame: a gilt frame on two posts, its name on a plaque, the view behind it.
local function postcard(parent: Instance, o: Vector3, p: { id: string, name: string, at: Vector3, look: Vector3 }): BasePart
	local m = Kit.model(parent, "Postcard_" .. p.id)
	local base = o + p.at
	local face = CFrame.lookAt(base, Vector3.new(o.X + p.look.X, base.Y, o.Z + p.look.Z))
	local gold = { color = GOLD, material = Enum.Material.Metal, reflectance = 0.25 }
	for _, side in { -1, 1 } do
		Kit.part(m, "FramePost", Vector3.new(0.4, 6, 0.4), face * CFrame.new(side * 3.4, 3, 0), gold)
	end
	Kit.part(m, "FrameTop", Vector3.new(7.2, 0.5, 0.5), face * CFrame.new(0, 6.2, 0), gold, TRIM)
	Kit.part(m, "FrameFoot", Vector3.new(7.2, 0.5, 0.5), face * CFrame.new(0, 1.6, 0), gold, TRIM)
	local plate = Kit.part(m, "FramePlate", Vector3.new(3.6, 0.8, 0.2), face * CFrame.new(0, 0.9, 0.3), L.blackLacquer, TRIM)
	Kit.engrave(plate, Enum.NormalId.Back, { { text = string.upper(p.name), size = 0.66, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 90, lit = false })
	local spot = Kit.part(m, "PostcardSpot", Vector3.new(6, 6, 2), face * CFrame.new(0, 3.6, 2), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, shadow = false })
	spot:SetAttribute("Postcard", p.id)
	return spot
end

---------------------------------------------------------------------------------------------------
-- The Coastal Circuit (shared/Tracks): smooth black road on the lowland, white edges, red and
-- white kerbs on the bends, a chequered line under a gantry, and the island's garage.
---------------------------------------------------------------------------------------------------
local ROAD = look(rgb(24, 24, 28), Enum.Material.Asphalt, 0.03)
local EDGE = look(rgb(236, 234, 228), Enum.Material.SmoothPlastic)
local KERB_RED = look(rgb(196, 30, 40), Enum.Material.SmoothPlastic)

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
	-- The road: a slab every other sample, laid along the curve (thick, most of it in the ground).
	local step = 2
	for i = 1, n, step do
		local a = samples[i]
		local b = samples[(i + step - 1) % n + 1]
		local y = surface(a)
		local flatA, flatB = Vector3.new(a.X, y - 1, a.Z), Vector3.new(b.X, y - 1, b.Z)
		local len = (flatB - flatA).Magnitude
		if len > 0.1 then
			local mid = (flatA + flatB) / 2
			local cf = CFrame.lookAt(mid, flatB)
			if y == top then
				Kit.part(m, "Road", Vector3.new(width, 2, len + 1.6), cf, ROAD)
			end
			-- The edges, and kerbs where the road bends.
			local c = samples[(i + 2 * step - 1) % n + 1]
			local d1 = (flatB - flatA).Unit
			local d2 = Vector3.new(c.X - b.X, 0, c.Z - b.Z)
			local bend = if d2.Magnitude > 0.1 then math.acos(math.clamp(d1:Dot(d2.Unit), -1, 1)) else 0
			for _, side in { -1, 1 } do
				local edge = cf * CFrame.new(side * (width / 2 - 0.5), 1.02, 0)
				if bend > math.rad(5) then
					Kit.part(m, "Kerb", Vector3.new(1.6, 0.16, len + 1.6), cf * CFrame.new(side * (width / 2 + 0.6), 1.04, 0), if (i // step) % 2 == 0 then KERB_RED else EDGE, TRIM)
				end
				Kit.part(m, "Edge", Vector3.new(0.5, 0.06, len + 1.6), edge, EDGE, TRIM)
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
			Kit.part(m, "Check", Vector3.new(width / 10, 0.06, 1.2), line * CFrame.new(x, 0.04, -0.6 + row * 1.2), if (k + row) % 2 == 0 then EDGE else look(rgb(12, 12, 14), Enum.Material.SmoothPlastic), TRIM)
		end
	end
	for _, side in { -1, 1 } do
		Kit.post(m, "GantryPost", 16, 1.4, (line * CFrame.new(side * (width / 2 + 2.4), 0, 0)).Position, L.blackLacquer)
	end
	local beam = Kit.part(m, "GantryBeam", Vector3.new(width + 6, 3, 1.8), line * CFrame.new(0, 16.6, 0), L.blackLacquer)
	Kit.part(m, "GantryBand", Vector3.new(width + 6.2, 0.4, 1.9), line * CFrame.new(0, 15, 0), { color = GOLD, material = Enum.Material.Metal, reflectance = 0.2 }, TRIM)
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
-- The palms' places (x, z, height, lean), round the shores and the gardens.
---------------------------------------------------------------------------------------------------
local PALMS = {
	{ -150, 112, 24, 6 }, { -122, 118, 28, 8 }, { -84, 124, 22, 5 }, { -8, 128, 26, 9 }, { 12, 122, 22, 4 },
	{ 104, 128, 27, 7 }, { 128, 118, 23, 5 }, { -196, 64, 26, 7 }, { -210, 0, 22, 5 }, { -200, -64, 24, 6 },
	{ -226, -150, 26, 7 }, { -80, -112, 22, 4 }, { 18, -140, 24, 5 }, { 164, -150, 26, 6 }, { 150, -96, 22, 5 },
	{ 196, -70, 25, 7 }, { 188, 64, 23, 6 }, { -54, 6, 20, 3 }, { -6, 34, 22, 4 }, { -50, -20, 21, 3 },
	{ -10, -16, 20, 2 }, { 86, 70, 24, 5 }, { 40, 64, 22, 4 }, { -70, 70, 26, 6 }, { 60, -50, 22, 3 },
	{ -140, -40, 24, 5 }, { -164, 110, 20, 6 }, { 150, 104, 26, 9 },
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
	grandVilla(m, o)
	overwater(m, o)
	local exchange = beach(m, o)
	gardens(m, o)
	local toast = summit(m, o)
	marina(m, o)
	coast(m, o)
	local nature = Kit.model(m, "Palms")
	for i, p in PALMS do
		palm(nature, o + Vector3.new(p[1], G - 0.6, p[2]), p[3], p[4], i * 1.37)
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

return IslandBuild

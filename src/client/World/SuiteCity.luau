--!strict
-- (Build 104) The view from a private wing (server/Wings): the city at dusk, far below the
-- residence's glass walls on the terrace's side (south and east), all round it further off. Drawn
-- only on the screen of a guest standing in a wing, round whichever wing that is, and put away the
-- moment they leave: nobody else's screen carries it, and the house below never sees it.
--   The skyline     glass towers of every height in rings round the residence, their floors lit
--                   in warm and cool bands, gold crowns and red beacons on the tallest
--   The roundabout  off the terrace, below: a great ring road round a lit fountain and a gold
--                   obelisk, four avenues out from it lined with lamps, and cars all the while
--                   (head and tail lights) round the ring and up and down the avenues
--   The light       dusk while they're there (the house's own light given back after)
-- Built once per visit, a few hundred plain parts, nothing that collides; the cars are moved
-- together each frame.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Wing = require(ReplicatedStorage.Shared.Wing)

local SuiteCity = {}

local rgb = Color3.fromRGB
local player = Players.LocalPlayer
local city: Model? = nil
local citySlot: number? = nil
type Car = { model: Model, kind: string, a: number, r: number, speed: number, from: Vector3?, to: Vector3? }
local cars: { Car } = {}
local centre = Vector3.zero -- the roundabout's middle (world, at street level)
local stepConn: RBXScriptConnection? = nil

-- (Deterministic, so every visit is the same city.)
local seed = 2024
local function rand(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- The residence's middle and its floor (world) for a wing.
local function residence(slot: number): (Vector3, number, number, number)
	local z, gal = Layout.Suite.zone, Layout.Suite.galleryZone
	local s = math.max(1, (z.max.X - z.min.X) / 47)
	local margin = math.floor(12 * s + 0.5)
	local minX, maxX = z.min.X - margin, math.max(z.max.X, gal.max.X) + margin
	local minZ, maxZ = z.min.Z - margin, math.max(z.max.Z, gal.max.Z) + margin
	local off = Wing.offset(slot)
	return Vector3.new((minX + maxX) / 2, Layout.Suite.floorY, (minZ + maxZ) / 2) + off, minZ + off.Z, maxX + off.X, s
end

local WARM = { rgb(255, 206, 140), rgb(255, 222, 170), rgb(255, 190, 120) }
local COOL = { rgb(214, 228, 255), rgb(190, 214, 255) }
local GLASS = { rgb(34, 40, 52), rgb(44, 50, 62), rgb(38, 44, 46), rgb(56, 50, 46) }

local function tower(parent: Instance, at: Vector3, street: number, height: number, foot: number)
	local body = part(parent, "Tower", Vector3.new(foot, height, foot * (0.7 + rand() * 0.6)), CFrame.new(at.X, street + height / 2, at.Z), GLASS[1 + math.floor(rand() * #GLASS)], Enum.Material.SmoothPlastic)
	body.Reflectance = 0.22
	local warm = rand() < 0.7
	local palette = if warm then WARM else COOL
	local bands = math.floor(height / 10)
	for i = 1, bands do
		if rand() < 0.78 then
			local y = street + i * 10 - 3
			local lit = part(parent, "Windows", Vector3.new(body.Size.X + 0.2, 1.1, body.Size.Z + 0.2), CFrame.new(at.X, y, at.Z), palette[1 + math.floor(rand() * #palette)], Enum.Material.Neon)
			lit.Transparency = 0.3 + rand() * 0.35
		end
	end
	if height > 190 then
		part(parent, "Crown", Vector3.new(body.Size.X + 1, 3, body.Size.Z + 1), CFrame.new(at.X, street + height + 1.5, at.Z), rgb(230, 186, 96), Enum.Material.Neon)
		part(parent, "Spire", Vector3.new(1.2, 28, 1.2), CFrame.new(at.X, street + height + 16, at.Z), rgb(210, 210, 214), Enum.Material.Metal)
		part(parent, "Beacon", Vector3.new(2, 2, 2), CFrame.new(at.X, street + height + 31, at.Z), rgb(255, 60, 60), Enum.Material.Neon, Enum.PartType.Ball)
	end
end

local CAR_PAINT = { rgb(240, 240, 236), rgb(16, 16, 18), rgb(170, 20, 30), rgb(200, 160, 80), rgb(30, 60, 120), rgb(110, 110, 116) }
local function car(parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "CityCar"
	local paint = CAR_PAINT[1 + math.floor(rand() * #CAR_PAINT)]
	local body = part(m, "Body", Vector3.new(4.4, 1.4, 9.6), CFrame.new(0, 1, 0), paint, Enum.Material.SmoothPlastic)
	body.Reflectance = 0.2
	part(m, "Cabin", Vector3.new(3.8, 1.2, 4.6), CFrame.new(0, 2.2, 0.4), rgb(14, 16, 20), Enum.Material.Glass)
	for _, x in { -1.5, 1.5 } do
		part(m, "Head", Vector3.new(0.9, 0.4, 0.2), CFrame.new(x, 1.2, -4.85), rgb(255, 250, 230), Enum.Material.Neon)
		part(m, "Tail", Vector3.new(0.9, 0.35, 0.2), CFrame.new(x, 1.2, 4.85), rgb(255, 40, 40), Enum.Material.Neon)
	end
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

local function lamp(parent: Instance, at: Vector3)
	part(parent, "LampPost", Vector3.new(0.6, 14, 0.6), CFrame.new(at + Vector3.new(0, 7, 0)), rgb(30, 30, 34), Enum.Material.Metal)
	part(parent, "LampHead", Vector3.new(1.8, 1.8, 1.8), CFrame.new(at + Vector3.new(0, 14.4, 0)), rgb(255, 214, 150), Enum.Material.Neon, Enum.PartType.Ball)
end

local RING_R = { 52, 62 } -- the roundabout's two lanes
local AVENUE = 420 -- how far each avenue runs out

local function build(slot: number): Model
	seed = 2024
	cars = {}
	local m = Instance.new("Model")
	m.Name = "SuiteCity"
	local mid, southEdge, eastEdge, s = residence(slot)
	local street = mid.Y - 150
	-- The ground: dark streets everywhere below.
	part(m, "Streets", Vector3.new(3200, 2, 3200), CFrame.new(mid.X, street - 1, mid.Z), rgb(20, 20, 24), Enum.Material.Asphalt)
	-- The roundabout: off the terrace's corner, below.
	centre = Vector3.new(eastEdge - 40 * s, street, southEdge - 210)
	local ring = Instance.new("Model")
	ring.Name = "Roundabout"
	ring.Parent = m
	part(ring, "RingRoad", Vector3.new(0.6, 136, 136), CFrame.new(centre + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(34, 34, 38), Enum.Material.Asphalt, Enum.PartType.Cylinder)
	part(ring, "RingLight", Vector3.new(0.7, 98, 98), CFrame.new(centre + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(255, 214, 140), Enum.Material.Neon, Enum.PartType.Cylinder)
	part(ring, "Island", Vector3.new(1.4, 92, 92), CFrame.new(centre + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(52, 84, 50), Enum.Material.Grass, Enum.PartType.Cylinder)
	part(ring, "Basin", Vector3.new(2.4, 40, 40), CFrame.new(centre + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(220, 210, 190), Enum.Material.Marble, Enum.PartType.Cylinder)
	local water = part(ring, "Water", Vector3.new(0.4, 36, 36), CFrame.new(centre + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), rgb(120, 210, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	water.Transparency = 0.35
	part(ring, "Plinth", Vector3.new(8, 6, 8), CFrame.new(centre + Vector3.new(0, 5, 0)), rgb(226, 214, 190), Enum.Material.Marble)
	part(ring, "Obelisk", Vector3.new(4, 44, 4), CFrame.new(centre + Vector3.new(0, 30, 0)), rgb(214, 172, 88), Enum.Material.Metal)
	part(ring, "Tip", Vector3.new(3, 3, 3), CFrame.new(centre + Vector3.new(0, 53, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), rgb(255, 230, 160), Enum.Material.Neon)
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		lamp(ring, centre + Vector3.new(math.cos(a) * 72, 0, math.sin(a) * 72))
	end
	-- The four avenues out from it, lamps both sides.
	local dirs = { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }
	for _, dir in dirs do
		local from = centre + dir * 68
		local to = centre + dir * AVENUE
		local midAv = (from + to) / 2
		part(ring, "Avenue", Vector3.new(if dir.X ~= 0 then AVENUE - 68 else 26, 0.6, if dir.X ~= 0 then 26 else AVENUE - 68), CFrame.new(midAv + Vector3.new(0, 0.2, 0)), rgb(34, 34, 38), Enum.Material.Asphalt)
		local side = Vector3.new(dir.Z, 0, -dir.X)
		for t = 90, AVENUE, 34 do
			lamp(ring, centre + dir * t + side * 15)
			lamp(ring, centre + dir * t - side * 15)
		end
		-- Two cars each way on it, out and back.
		for lane = -1, 1, 2 do
			for n = 0, 1 do
				local c = car(ring)
				local a = centre + dir * 72 + side * 6 * lane
				local b = centre + dir * (AVENUE - 10) + side * 6 * lane
				table.insert(cars, { model = c, kind = "line", a = rand(), r = 0, speed = 34 + rand() * 12, from = if lane > 0 then a else b, to = if lane > 0 then b else a })
				local _ = n
			end
		end
	end
	-- Round the ring, two lanes.
	for lane, r in RING_R do
		local n = if lane == 1 then 7 else 9
		for i = 0, n - 1 do
			local c = car(ring)
			table.insert(cars, { model = c, kind = "ring", a = i / n * math.pi * 2 + rand() * 0.3, r = r, speed = 26 + rand() * 6, from = nil, to = nil })
		end
	end
	-- The skyline: rings of towers, kept clear of the residence's own foot, the avenues and the
	-- roundabout; taller toward the terrace's side.
	local towers = Instance.new("Model")
	towers.Name = "Skyline"
	towers.Parent = m
	for ringN = 1, 5 do
		local radius = 230 + ringN * 150
		local count = 10 + ringN * 4
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2 + rand() * 0.2
			local at = Vector3.new(mid.X + math.cos(a) * radius, 0, mid.Z + math.sin(a) * radius)
			local fromRing = Vector3.new(at.X - centre.X, 0, at.Z - centre.Z)
			local onAvenue = math.abs(fromRing.X) < 40 or math.abs(fromRing.Z) < 40
			if fromRing.Magnitude > 110 and not (onAvenue and fromRing.Magnitude < AVENUE + 20) then
				local view = (at.Z < mid.Z) or (at.X > mid.X)
				local h = (if view then 120 else 90) + rand() * (if view then 220 else 160) + (5 - ringN) * 10
				tower(towers, at, street, h, 34 + rand() * 30)
			end
		end
	end
	return m
end

-- The cars, moved together each frame.
local function step(dt: number)
	local moves: { BasePart } = {}
	local frames: { CFrame } = {}
	local _ = moves
	for _, c in cars do
		if c.kind == "ring" then
			c.a += c.speed / c.r * dt
			local p = centre + Vector3.new(math.cos(c.a) * c.r, 0.6, math.sin(c.a) * c.r)
			local ahead = centre + Vector3.new(math.cos(c.a + 0.05) * c.r, 0.6, math.sin(c.a + 0.05) * c.r)
			c.model:PivotTo(CFrame.lookAt(p, ahead))
		else
			local from, to = c.from :: Vector3, c.to :: Vector3
			local len = (to - from).Magnitude
			c.a = (c.a + c.speed / len * dt) % 1
			local p = from:Lerp(to, c.a) + Vector3.new(0, 0.6, 0)
			c.model:PivotTo(CFrame.lookAt(p, p + (to - from).Unit))
		end
	end
	local _f = frames
end

---------------------------------------------------------------------------------------------------
-- Dusk, while they're there
---------------------------------------------------------------------------------------------------
local PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation" }
local saved: { [string]: any }? = nil
local effects: { Instance } = {}

local function dusk()
	if saved then
		return
	end
	local s = {}
	for _, k in PROPS do
		pcall(function()
			s[k] = (Lighting :: any)[k]
		end)
	end
	saved = s
	pcall(function()
		local L = Lighting :: any
		L.ClockTime = 19.1
		L.Brightness = 1.4
		L.Ambient = rgb(70, 58, 64)
		L.OutdoorAmbient = rgb(96, 80, 96)
		L.ExposureCompensation = 0.1
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "SuiteCityBloom"
		bloom.Intensity, bloom.Size, bloom.Threshold = 0.7, 28, 0.92
		bloom.Parent = Lighting
		table.insert(effects, bloom)
	end)
end

local function undusk()
	for _, e in effects do
		e:Destroy()
	end
	effects = {}
	local s = saved
	if s then
		for k, v in s do
			pcall(function()
				(Lighting :: any)[k] = v
			end)
		end
	end
	saved = nil
end

-- Shows the city round wing `slot` (nil: put it away). Called by WingView with the wing this
-- guest stands in.
function SuiteCity.show(slot: number?)
	if slot == citySlot then
		return
	end
	local old = city
	if old then
		old:Destroy()
	end
	city = nil
	cars = {}
	citySlot = slot
	local conn = stepConn
	if conn then
		conn:Disconnect()
		stepConn = nil
	end
	if not slot then
		undusk()
		return
	end
	local m = build(slot)
	m.Parent = Workspace
	city = m
	dusk()
	stepConn = RunService.Heartbeat:Connect(step)
end

-- For tests: what's drawn.
function SuiteCity.current(): (Model?, number)
	return city, #cars
end
SuiteCity.step = step

local _ = player
return SuiteCity

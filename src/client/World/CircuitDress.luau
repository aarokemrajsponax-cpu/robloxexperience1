--!strict
-- The Grand Prix dressed for a night race, on this screen only: none of it is the server's, so
-- it costs the house's part budget nothing, and nothing here collides.
--
-- The cars: wide haunches over the wheels, a pair of humps behind the seats, twin stripes in the
-- car's trim over the bonnet and the tail, its racing number on the doors and the bonnet, intakes,
-- a diffuser, twin tailpipes (flame from them on a boost), five-spoke rims with red calipers, a
-- warm glow under the sills, a wing's end plates on the hypercars and a ducktail on the tourers;
-- its engine heard as it goes (higher as it goes faster), smoke from the rear tyres when they
-- slide. Each car is dressed once (a chauffeur's copy comes dressed).
--
-- The circuit: lights along the edges of the straights that run with the race, boost pads of gold
-- chevrons, red-and-white barriers round the hairpins, boards along the far wall, the infield
-- mown in stripes with the circuit's name across it, a podium, chequered flags at the line, and
-- the Timing Tower on the building opposite: the standings live through a race, the result after.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local GrandPrix = require(ReplicatedStorage.Shared.GrandPrix)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CircuitDress = {}

local rgb = Color3.fromRGB
local C = Brand.Colours
local T = GrandPrix.TRACK
local RIDE = GrandPrix.RIDE
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local CARBON = rgb(22, 22, 25)
local GOLD = rgb(232, 190, 96)

local folder: Folder? = nil
local built = false

local function home(): Instance
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "GrandPrixDress"
	made.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	folder = made
	return made
end

-- A piece of the dressing: anchored (or, on a car, welded and weightless), never in the way.
local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	if shape then
		p.Shape = shape
		p.Size = size
	end
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function oval(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = piece(parent, name, size, cf, colour, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- Words on a face of a part (lit like the part, or glowing where `glow`).
local function face(p: BasePart, side: Enum.NormalId, ppu: number, glow: boolean?): SurfaceGui
	local g = Instance.new("SurfaceGui")
	g.Face = side
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = ppu
	g.LightInfluence = if glow then 0 else 1
	g.MaxDistance = 400
	g.Parent = p
	return g
end

local function words(parent: Instance, text: string, font: Font, colour: Color3, size: UDim2, position: UDim2, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = position
	l.FontFace = font
	l.Text = text
	l.TextColor3 = colour
	l.TextScaled = true
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	return l
end

---------------------------------------------------------------------------------------------------
-- The cars
---------------------------------------------------------------------------------------------------
type Dressed = { model: Model, chassis: BasePart, engine: Sound?, smoke: { ParticleEmitter }, flames: { BasePart }, last: Vector3?, speed: number, driven: boolean }
local cars: { [Model]: Dressed } = {}

local function numberOf(carId: string): number
	for i, c in GrandPrix.CARS do
		if c.id == carId then
			return i
		end
	end
	for i, c in GrandPrix.GARAGE do
		if c.id == carId then
			return #GrandPrix.CARS + i
		end
	end
	return 0
end

-- A racing number: a white roundel, the figures in black.
local function roundel(p: BasePart, side: Enum.NormalId, n: number)
	local g = face(p, side, 60)
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(0.96, 0.96)
	disc.BackgroundColor3 = rgb(246, 244, 238)
	disc.Parent = g
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = disc
	local ring = Instance.new("UIStroke")
	ring.Color = rgb(20, 20, 22)
	ring.Thickness = 4
	ring.Parent = disc
	words(disc, string.format("%02d", n), Brand.Fonts.display, rgb(16, 16, 18), UDim2.fromScale(0.74, 0.62), UDim2.fromScale(0.13, 0.19))
end

local function attachSound(chassis: BasePart): Sound?
	local loops = (Config.data.Assets :: any).Loops
	local id = if type(loops) == "table" then loops.carEngine else nil
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = "Engine"
	s.SoundId = id
	s.Looped = true
	s.Volume = 0
	s.PlaybackSpeed = 0.8
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 14
	s.RollOffMaxDistance = 200
	s.Parent = chassis
	return s
end

-- Dresses one of the Grand Prix's cars (World/Motorcar's: its chassis at its centre, `put`'s
-- measures). Returns false if it isn't one, or is dressed already.
function CircuitDress.dressCar(model: Model): boolean
	if model:GetAttribute("Dressed") == true or cars[model] then
		return false
	end
	local chassis = model:FindFirstChild("Chassis")
	if not (chassis and chassis:IsA("BasePart")) then
		return false
	end
	local carId = model:GetAttribute("CarId")
	local def = if type(carId) == "string" then GrandPrix.byId[carId] else nil
	if not def then
		return false
	end
	model:SetAttribute("Dressed", true)
	local at = chassis.CFrame
	local paint, trim = def.paint :: Color3, def.trim :: Color3
	local list: { BasePart } = {}
	local function put(name: string, size: Vector3, x: number, y: number, z: number, colour: Color3, material: Enum.Material?, turn: CFrame?, round: boolean?, shape: Enum.PartType?): Part
		local cf = at * CFrame.new(x, y - RIDE, z) * (turn or CFrame.identity)
		local p = if round then oval(model, name, size, cf, colour, material) else piece(model, name, size, cf, colour, material, shape)
		table.insert(list, p)
		return p
	end
	local glossy = Enum.Material.SmoothPlastic
	-- The haunches over the wheels and the humps behind the seats, in the car's paint: low and
	-- long, a line over each wheel rather than a bulge.
	for _, side in { -1, 1 } do
		for _, z in { -4.8, 4.8 } do
			put("Haunch", Vector3.new(1.9, 1, 4.3), side * 3.3, 2.6, z, paint, glossy, nil, true).Reflectance = 0.16
		end
		put("Hump", Vector3.new(1.6, 0.8, 3.4), side * 1.65, 2.85, 4.7, paint, glossy, nil, true).Reflectance = 0.16
		-- A racing seat: bolsters either side, in a darker hide.
		local hide = rgb(48, 24, 18)
		for _, b in { -1, 1 } do
			put("Bolster", Vector3.new(0.3, 1.5, 0.6), side * 1.65 + b * 1.1, 3.0, 2.3, hide, Enum.Material.Leather, CFrame.Angles(math.rad(-12), 0, 0))
		end
	end
	-- Twin stripes in the trim over the bonnet and the tail.
	local bonnet = CFrame.new(0, 2.4, -4.7) * CFrame.Angles(math.rad(-5), 0, 0)
	for _, x in { -0.55, 0.55 } do
		local b = bonnet * CFrame.new(x, 0.265, 0)
		put("Stripe", Vector3.new(0.6, 0.04, 5.3), b.X, b.Y, b.Z, trim, glossy, bonnet.Rotation).Reflectance = 0.2
		put("Stripe", Vector3.new(0.6, 0.04, 4.3), x, 2.77, 5.1, trim, glossy).Reflectance = 0.2
	end
	-- The racing number: on each door, and on the bonnet.
	local n = numberOf(def.id)
	for _, side in { -1, 1 } do
		local disc = put("Number", Vector3.new(0.04, 1.4, 1.4), side * 3.62, 1.6, 0.6, paint, glossy)
		disc.Transparency = 1
		roundel(disc, if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left, n)
	end
	local top = bonnet * CFrame.new(0, 0.29, -1.1)
	local plate = put("Number", Vector3.new(1.5, 0.03, 1.5), top.X, top.Y, top.Z, paint, glossy, bonnet.Rotation * CFrame.Angles(0, math.pi, 0))
	plate.Transparency = 1
	roundel(plate, Enum.NormalId.Top, n)
	-- Intakes ahead of the rear wheels, the diffuser, twin tailpipes and the flame they throw.
	for _, side in { -1, 1 } do
		put("Intake", Vector3.new(0.12, 0.7, 1.6), side * 3.62, 1.75, 1.9, CARBON, glossy)
	end
	put("Diffuser", Vector3.new(6.2, 0.1, 1.2), 0, 0.8, 7.1, CARBON, glossy)
	for _, x in { -1.8, -0.6, 0.6, 1.8 } do
		put("Fin", Vector3.new(0.1, 0.55, 1.1), x, 1.05, 7.15, CARBON, glossy)
	end
	local flames: { BasePart } = {}
	for _, x in { -0.9, 0.9 } do
		local pipe = put("Tailpipe", Vector3.new(0.9, 0.42, 0.42), x, 1.25, 7.55, trim, Enum.Material.Metal, CFrame.Angles(0, math.rad(90), 0), false, Enum.PartType.Cylinder)
		pipe.Reflectance = 0.4
		local flame = put("Flame", Vector3.new(0.38, 0.38, 1.3), x, 1.25, 8.5, rgb(255, 150, 60), Enum.Material.Neon, nil, true)
		flame.Transparency = 1
		table.insert(flames, flame)
	end
	-- The wheels: five spokes over the rim (three bars), a red caliper behind them.
	for _, side in { -1, 1 } do
		for _, z in { -4.8, 4.8 } do
			put("Caliper", Vector3.new(0.06, 0.4, 0.7), side * 4.0, 1.85, z + 0.05, rgb(196, 24, 32), glossy)
			for k = 0, 2 do
				put("Spoke", Vector3.new(0.06, 1.56, 0.16), side * 4.03, 1.45, z, rgb(28, 28, 32), Enum.Material.Metal, CFrame.Angles(k * math.pi / 3, 0, 0))
			end
		end
	end
	-- A warm glow under the sills.
	for _, side in { -1, 1 } do
		local glow = put("Underglow", Vector3.new(0.15, 0.08, 11), side * 3.0, 0.62, 0, trim:Lerp(GOLD, 0.5), Enum.Material.Neon)
		glow.Transparency = 0.5
	end
	if def.style == "hyper" then
		for _, side in { -1, 1 } do
			put("EndPlate", Vector3.new(0.14, 1.1, 1.7), side * 3.32, 3.75, 6.7, CARBON, glossy)
		end
	elseif def.style == "tourer" then
		put("Ducktail", Vector3.new(6.4, 0.18, 0.9), 0, 2.86, 7.05, paint, glossy, CFrame.Angles(math.rad(12), 0, 0)).Reflectance = 0.16
	end
	-- Smoke from the rear tyres (only when they slide: CircuitDress.effects).
	local smoke: { ParticleEmitter } = {}
	for _, side in { -1, 1 } do
		local a = Instance.new("Attachment")
		a.Name = "TyreSmoke"
		a.Position = Vector3.new(side * 3.25, 0.2 - RIDE, 5.4)
		a.Parent = chassis
		local e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE
		e.Color = ColorSequence.new(rgb(226, 224, 220))
		e.LightEmission = 0.1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 6) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1, 1.7)
		e.Speed = NumberRange.new(2, 5)
		e.SpreadAngle = Vector2.new(35, 35)
		e.Acceleration = Vector3.new(0, 2.5, 0)
		e.Rate = 0
		e.Parent = a
		table.insert(smoke, e)
	end
	-- Welded to the chassis and weightless (a chauffeur's copy is anchored whole and moved whole).
	for _, p in list do
		p.Massless = true
		p.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = chassis
		w.Part1 = p
		w.Parent = p
	end
	cars[model] = { model = model, chassis = chassis, engine = attachSound(chassis), smoke = smoke, flames = flames, last = nil, speed = 0, driven = false }
	return true
end

-- The look of a car in motion, from the driver's screen: smoke (0 to 1) from the rear tyres and
-- flame from the tailpipes.
function CircuitDress.effects(model: Model, smoke: number, flame: boolean)
	local d = cars[model]
	if not d then
		return
	end
	for _, e in d.smoke do
		e.Rate = math.floor(math.clamp(smoke, 0, 1) * 40)
	end
	for _, f in d.flames do
		f.Transparency = if flame then 0.15 + math.random() * 0.35 else 1
		local s = f.Size
		if flame then
			f.Size = Vector3.new(s.X, s.Y, 1 + math.random() * 0.8)
		end
	end
end

-- Whether this screen is driving a car (Main: CarDrive), for its engine's level.
CircuitDress.drivingNow = function(): Model?
	return nil
end

-- A chauffeur's copy is dressed already: it only needs its engine and its smoke kept.
function CircuitDress.adopt(model: Model)
	if cars[model] then
		return
	end
	local chassis = model:FindFirstChild("Chassis")
	if not (chassis and chassis:IsA("BasePart")) then
		return
	end
	local smoke: { ParticleEmitter } = {}
	local flames: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("ParticleEmitter") and d.Parent and d.Parent.Name == "TyreSmoke" then
			table.insert(smoke, d)
		elseif d:IsA("BasePart") and d.Name == "Flame" then
			table.insert(flames, d)
		end
	end
	local engine = chassis:FindFirstChild("Engine")
	cars[model] = { model = model, chassis = chassis, engine = if engine and engine:IsA("Sound") then engine else nil, smoke = smoke, flames = flames, last = nil, speed = 0, driven = false }
end

-- Each car's engine: heard as it moves (pitch rising with its speed), quiet when parked, and only
-- the nearest few at once.
local function engines(dt: number)
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local mine = CircuitDress.drivingNow()
	local near: { { d: Dressed, dist: number } } = {}
	for model, d in cars do
		if model.Parent == nil or d.chassis.Parent == nil then
			cars[model] = nil
			continue
		end
		local p = d.chassis.Position
		if d.last and dt > 0 then
			local v = Vector3.new(p.X - d.last.X, 0, p.Z - d.last.Z).Magnitude / dt
			d.speed += (math.min(v, 140) - d.speed) * math.clamp(dt * 6, 0, 1)
		end
		d.last = p
		table.insert(near, { d = d, dist = (p - eye).Magnitude })
	end
	table.sort(near, function(a, b)
		return a.dist < b.dist
	end)
	for i, n in near do
		local d = n.d
		local s = d.engine
		if not s then
			continue
		end
		local moving = d.speed > 3 or d.model == mine
		if i <= 4 and n.dist < 220 and moving then
			local frac = math.clamp(d.speed / GrandPrix.CAR.top, 0, 1.25)
			s.PlaybackSpeed = 0.72 + frac * 0.62
			s.Volume = (if d.model == mine then 0.22 else 0.3) + frac * 0.38
			if not s.IsPlaying then
				s:Play()
			end
		elseif s.IsPlaying then
			s:Stop()
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The circuit
---------------------------------------------------------------------------------------------------
type Light = { part: Part, x: number, dirX: number }
local lights: { Light } = {}
local chevrons: { { part: Part, k: number } } = {}
local flags: { { part: Part, base: CFrame, phase: number } } = {}
local tower: { [string]: any } = {}
local podium: { [string]: any } = {}

local function straightLights(parent: Instance)
	local h, w = T.half, T.width
	local nearZ, farZ = T.centre.Z + T.radius, T.centre.Z - T.radius
	-- (The near straight is driven east, the far one west.)
	for _, row in { { z = nearZ, dirX = 1 }, { z = farZ, dirX = -1 } } do
		for _, side in { -1, 1 } do
			local z = row.z + side * (w / 2 - 1.6)
			for x = -h + 4, h - 4, 9 do
				local p = piece(parent, "TrackLight", Vector3.new(1.4, 0.1, 0.45), CFrame.new(T.centre.X + x, T.y + 0.08, z), GOLD, Enum.Material.Neon)
				p.Transparency = 0.55
				table.insert(lights, { part = p, x = T.centre.X + x, dirX = row.dirX })
			end
		end
	end
end

local function boostPads(parent: Instance)
	local b = GrandPrix.BOOST
	for i, pad in GrandPrix.boostPads() do
		local base = CFrame.lookAt(pad.at + Vector3.new(0, T.y + 0.07 - pad.at.Y, 0), pad.at + Vector3.new(0, T.y + 0.07 - pad.at.Y, 0) + pad.dir)
		local plate = piece(parent, "BoostPad", Vector3.new(b.width, 0.06, b.length), base, rgb(14, 14, 16), Enum.Material.SmoothPlastic)
		plate.Reflectance = 0.15
		plate:SetAttribute("Pad", i)
		-- Three chevrons pointing the way to drive, each two bars.
		for k = 1, 3 do
			local along = (k - 2) * 3.4
			for _, s in { -1, 1 } do
				local bar = piece(parent, "Chevron", Vector3.new(4.4, 0.05, 0.7), base * CFrame.new(s * 1.55, 0.05, -along + 0.9) * CFrame.Angles(0, s * math.rad(-35), 0), GOLD, Enum.Material.Neon)
				bar.Transparency = 0.5
				table.insert(chevrons, { part = bar, k = k })
			end
		end
	end
end

-- Red and white blocks round each hairpin's outside, just off the road.
local function hairpinBarriers(parent: Instance)
	local R, w, n = T.radius, T.width, 16
	local r = R + w / 2 + 0.9
	for _, east in { true, false } do
		local cx = T.centre.X + (if east then T.half else -T.half)
		local dirX = if east then 1 else -1
		for i = 0, n - 1 do
			local th = (i + 0.5) * math.pi / n
			local p = Vector3.new(cx + dirX * r * math.sin(th), 0.75, T.centre.Z + (if east then 1 else -1) * r * math.cos(th))
			local out = Vector3.new(dirX * math.sin(th), 0, (if east then 1 else -1) * math.cos(th))
			local len = r * math.pi / n + 0.1
			piece(parent, "Barrier", Vector3.new(len, 1.4, 0.7), CFrame.lookAt(p, p + out), if i % 2 == 0 then rgb(196, 26, 34) else rgb(240, 238, 232))
		end
	end
end

local function farBoards(parent: Instance)
	local farZ = T.centre.Z - T.radius - T.width / 2 - 3
	local z = farZ + 1.6
	local n = 8
	local len = 2 * T.half / n
	for i = 1, n do
		local x = T.centre.X - T.half + (i - 0.5) * len
		local gold = i % 2 == 0
		local board = piece(parent, "Board", Vector3.new(len - 0.4, 2.6, 0.5), CFrame.new(x, 1.3, z), if gold then rgb(196, 158, 82) else rgb(12, 12, 14), Enum.Material.SmoothPlastic)
		local g = face(board, Enum.NormalId.Back, 12)
		words(g, if gold then "GRAND PRIX" else "MAISON NOIR", Brand.Fonts.display, if gold then rgb(14, 12, 10) else GOLD, UDim2.fromScale(0.8, 0.62), UDim2.fromScale(0.1, 0.19))
	end
	piece(parent, "BoardRail", Vector3.new(2 * T.half, 0.18, 0.6), CFrame.new(T.centre.X, 2.68, z), GOLD, Enum.Material.Metal).Reflectance = 0.25
end

local function infield(parent: Instance)
	local h, R, w = T.half, T.radius, T.width
	local inner = w / 2 + 1.5
	local depth = 2 * R - 2 * inner - 1
	local n = 10
	local wide = 2 * h / n
	-- Mown in stripes: every other one a lighter green.
	for i = 1, n, 2 do
		local x = T.centre.X - h + (i - 0.5) * wide
		piece(parent, "Mown", Vector3.new(wide, 0.05, depth), CFrame.new(x, T.y + 0.085, T.centre.Z), rgb(34, 66, 40), Enum.Material.Grass)
	end
	-- The circuit's name across the grass, read from the house's side.
	local sign = piece(parent, "InfieldName", Vector3.new(130, 0.02, 30), CFrame.new(T.centre.X, T.y + 0.13, T.centre.Z - 10), C.gold)
	sign.Transparency = 1
	local g = face(sign, Enum.NormalId.Top, 6)
	words(g, "MAISON NOIR", Brand.Fonts.display, GOLD, UDim2.fromScale(1, 0.58), UDim2.fromScale(0, 0))
	words(g, "G R A N D   P R I X", Brand.Fonts.bodyBold, rgb(240, 232, 214), UDim2.fromScale(0.6, 0.3), UDim2.fromScale(0.2, 0.66))
end

-- The podium in the infield, facing the house: first in the middle, highest.
local function buildPodium(parent: Instance)
	-- (East of the line, clear of its flags.)
	local x0, z0 = T.centre.X + 34, T.centre.Z + T.radius - T.width / 2 - 12
	local steps = { { place = 2, x = -6.4, h = 3 }, { place = 1, x = 0, h = 4.6 }, { place = 3, x = 6.4, h = 2 } }
	podium.steps = {}
	for _, s in steps do
		local block = piece(parent, "Podium", Vector3.new(6.2, s.h, 6), CFrame.new(x0 + s.x, s.h / 2, z0), rgb(16, 16, 18), Enum.Material.Marble)
		block.Reflectance = 0.08
		piece(parent, "PodiumTrim", Vector3.new(6.3, 0.22, 6.1), CFrame.new(x0 + s.x, s.h + 0.05, z0), if s.place == 1 then GOLD elseif s.place == 2 then rgb(214, 216, 222) else rgb(196, 128, 72), Enum.Material.Metal).Reflectance = 0.3
		local g = face(block, Enum.NormalId.Back, 20)
		words(g, tostring(s.place), Brand.Fonts.display, if s.place == 1 then GOLD else rgb(236, 232, 224), UDim2.fromScale(0.5, math.min(0.7, 2.2 / s.h)), UDim2.fromScale(0.25, 0.12))
		-- The name of who stood there last (after a race).
		local tag = Instance.new("BillboardGui")
		tag.Name = "Name"
		tag.Size = UDim2.fromOffset(220, 30)
		tag.StudsOffsetWorldSpace = Vector3.new(0, s.h + 3.4, 0)
		tag.MaxDistance = 260
		tag.Enabled = false
		tag.Adornee = block
		tag.Parent = block
		local l = words(tag, "", Brand.Fonts.bodyBold, if s.place == 1 then GOLD else rgb(240, 236, 228), UDim2.fromScale(1, 1), UDim2.fromScale(0, 0))
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = rgb(10, 10, 12)
		stroke.Parent = l
		podium.steps[s.place] = { block = block, tag = tag, label = l, top = s.h }
	end
	-- Gold confetti from the top step, for a moment after a race.
	local top = podium.steps[1].block
	local a = Instance.new("Attachment")
	a.Position = Vector3.new(0, 9, 0)
	a.Parent = top
	local e = Instance.new("ParticleEmitter")
	e.Name = "Confetti"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(GOLD, rgb(255, 246, 214))
	e.LightEmission = 0.6
	e.Size = NumberSequence.new(0.5)
	e.Lifetime = NumberRange.new(2.5, 4)
	e.Speed = NumberRange.new(8, 16)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, -9, 0)
	e.Rate = 0
	e.Parent = a
	podium.confetti = e
	local back = piece(parent, "PodiumBoard", Vector3.new(22, 7, 0.6), CFrame.new(x0, 8.2, z0 - 4), rgb(12, 12, 14), Enum.Material.SmoothPlastic)
	local g = face(back, Enum.NormalId.Back, 14)
	words(g, "MAISON NOIR GRAND PRIX", Brand.Fonts.display, GOLD, UDim2.fromScale(0.9, 0.36), UDim2.fromScale(0.05, 0.14))
	words(g, "THE PODIUM", Brand.Fonts.bodyBold, rgb(236, 232, 224), UDim2.fromScale(0.5, 0.22), UDim2.fromScale(0.25, 0.6))
	for _, sx in { -1, 1 } do
		piece(parent, "PodiumPost", Vector3.new(0.5, 11.7, 0.5), CFrame.new(x0 + sx * 11.2, 5.85, z0 - 4), GOLD, Enum.Material.Metal).Reflectance = 0.3
	end
end

-- Chequered flags hung from the gantry's posts, out toward the cars coming up to the line.
local function lineFlags(parent: Instance)
	local x = T.centre.X
	local nearZ = T.centre.Z + T.radius
	for _, side in { -1, 1 } do
		local base = Vector3.new(x - 1.1, 0, nearZ + side * (T.width / 2 + 2.5))
		piece(parent, "FlagPole", Vector3.new(3.4, 0.2, 0.2), CFrame.new(base + Vector3.new(-1.7, 12.6, 0)), rgb(220, 220, 224), Enum.Material.Metal).Reflectance = 0.3
		local cf = CFrame.new(base + Vector3.new(-2.4, 11, 0))
		local flag = piece(parent, "Flag", Vector3.new(4.4, 3, 0.06), cf, rgb(250, 250, 250))
		for _, sideFace in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local g = face(flag, sideFace, 16)
			-- (The black squares on the white cloth.)
			for i = 0, 39 do
				local col, row = i % 8, i // 8
				if (col + row) % 2 == 0 then
					local cell = Instance.new("Frame")
					cell.BorderSizePixel = 0
					cell.BackgroundColor3 = rgb(14, 14, 16)
					cell.Size = UDim2.fromScale(1 / 8, 1 / 5)
					cell.Position = UDim2.fromScale(col / 8, row / 5)
					cell.Parent = g
				end
			end
		end
		table.insert(flags, { part = flag, base = cf, phase = side })
	end
end

-- The Timing Tower: a great screen on the building across the street.
local function timingTower(parent: Instance)
	-- (Just proud of the building's face and its windows.)
	local z = T.centre.Z - T.radius - T.width / 2 - 3 + 0.75
	local cf = CFrame.new(T.centre.X, 24, z)
	local screen = piece(parent, "TimingTower", Vector3.new(64, 26, 0.5), cf, rgb(8, 8, 10), Enum.Material.SmoothPlastic)
	for _, e in { { Vector3.new(65.4, 0.7, 0.7), Vector3.new(0, 13.2, 0) }, { Vector3.new(65.4, 0.7, 0.7), Vector3.new(0, -13.2, 0) }, { Vector3.new(0.7, 26.4, 0.7), Vector3.new(32.4, 0, 0) }, { Vector3.new(0.7, 26.4, 0.7), Vector3.new(-32.4, 0, 0) } } do
		piece(parent, "TowerFrame", e[1], cf * CFrame.new(e[2] + Vector3.new(0, 0, 0.1)), GOLD, Enum.Material.Metal).Reflectance = 0.3
	end
	local g = face(screen, Enum.NormalId.Back, 20, true)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(10, 10, 12)
	bg.BorderSizePixel = 0
	bg.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(rgb(34, 28, 20), rgb(8, 8, 10))
	grad.Parent = bg
	words(bg, "MAISON NOIR GRAND PRIX", Brand.Fonts.display, GOLD, UDim2.fromScale(0.6, 0.11), UDim2.fromScale(0.04, 0.05), Enum.TextXAlignment.Left)
	tower.state = words(bg, "", Brand.Fonts.bodyBold, rgb(236, 232, 224), UDim2.fromScale(0.34, 0.08), UDim2.fromScale(0.62, 0.065), Enum.TextXAlignment.Right)
	local rule = Instance.new("Frame")
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = GOLD
	rule.Size = UDim2.new(0.92, 0, 0, 3)
	rule.Position = UDim2.fromScale(0.04, 0.19)
	rule.Parent = bg
	tower.rows = {}
	for i = 1, 6 do
		local y = 0.23 + (i - 1) * 0.125
		local row = Instance.new("Frame")
		row.BackgroundTransparency = if i % 2 == 0 then 1 else 0.9
		row.BackgroundColor3 = rgb(255, 255, 255)
		row.BorderSizePixel = 0
		row.Size = UDim2.fromScale(0.92, 0.115)
		row.Position = UDim2.fromScale(0.04, y)
		row.Parent = bg
		local place = words(row, "", Brand.Fonts.display, GOLD, UDim2.fromScale(0.08, 0.8), UDim2.fromScale(0.01, 0.1), Enum.TextXAlignment.Left)
		local name = words(row, "", Brand.Fonts.bodyBold, rgb(240, 236, 228), UDim2.fromScale(0.6, 0.72), UDim2.fromScale(0.11, 0.14), Enum.TextXAlignment.Left)
		local info = words(row, "", Brand.Fonts.figures, rgb(206, 198, 180), UDim2.fromScale(0.26, 0.72), UDim2.fromScale(0.72, 0.14), Enum.TextXAlignment.Right)
		tower.rows[i] = { frame = row, place = place, name = name, info = info }
	end
	tower.note = words(bg, "", Brand.Fonts.body, rgb(206, 198, 180), UDim2.fromScale(0.92, 0.07), UDim2.fromScale(0.04, 0.91))
end

---------------------------------------------------------------------------------------------------
-- What the race is doing (for the tower, the lights and the podium)
---------------------------------------------------------------------------------------------------
local race = { state = "idle", laps = 3, door = "open", doorAt = 0, standings = {} :: { { [string]: any } }, results = {} :: { { [string]: any } }, resultsAt = -math.huge, goAt = 0 }

local function ordinal(n: number): string
	local last = n % 10
	local teen = n % 100 >= 11 and n % 100 <= 13
	return tostring(n) .. (if teen then "th" elseif last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th")
end

local function fmtTime(t: number): string
	t = math.max(0, t)
	return string.format("%d:%04.1f", math.floor(t / 60), t % 60)
end

local function setRow(i: number, place: string, name: string, info: string, me: boolean)
	local r = tower.rows and tower.rows[i]
	if not r then
		return
	end
	r.place.Text = place
	r.name.Text = name
	r.info.Text = info
	r.name.TextColor3 = if me then GOLD else rgb(240, 236, 228)
end

local function drawTower()
	if not tower.state then
		return
	end
	local now = os.clock()
	local me = Players.LocalPlayer and Players.LocalPlayer.UserId
	local list: { { [string]: any } } = {}
	local note = ""
	if race.state == "racing" or race.state == "countdown" then
		tower.state.Text = if race.state == "countdown" then "ON THE GRID" else "LIVE"
		list = race.standings
		note = "Three laps. First home takes the purse."
	elseif race.state == "results" or (now - race.resultsAt < 90 and #race.results > 0) then
		tower.state.Text = "RESULT"
		list = race.results
		note = "Get in any car on the street and press Race for the next one."
	elseif race.state == "gathering" then
		tower.state.Text = "STARTING SOON"
		note = "Get in a car and press Race to join."
	elseif race.door == "closed" then
		local left = math.max(0, math.ceil(race.doorAt - now))
		tower.state.Text = string.format("OPENS IN %d:%02d", left // 60, left % 60)
		note = "The cars are yours to drive until then."
	else
		tower.state.Text = "OPEN"
		note = "Get in any car on the street and press Race."
	end
	for i = 1, 6 do
		local row = list[i]
		if row then
			local finished = (row.place or 0) > 0
			local info = if race.state == "racing" then string.format("LAP %d/%d", math.max(1, tonumber(row.lap) or 1), race.laps) elseif finished and row.time then fmtTime(row.time) else tostring(row.out or "")
			setRow(i, if finished then ordinal(row.place) else "—", tostring(row.name or ""), info, row.userId == me)
		else
			setRow(i, "", "", "", false)
		end
	end
	tower.note.Text = note
end

local function showPodium(list: { { [string]: any } })
	if not podium.steps then
		return
	end
	for place = 1, 3 do
		local step = podium.steps[place]
		local row = nil
		for _, r in list do
			if r.place == place then
				row = r
			end
		end
		step.label.Text = if row then tostring(row.name or "") else ""
		step.tag.Enabled = row ~= nil
	end
	if podium.confetti then
		podium.confetti.Rate = 60
		task.delay(6, function()
			podium.confetti.Rate = 0
		end)
	end
end

local function onRace(m: { [string]: any })
	local op = m.op
	if op == "race" then
		race.state = tostring(m.state or race.state)
		race.laps = tonumber(m.laps) or race.laps
		if m.door == "open" or m.door == "closed" then
			race.door = m.door
			race.doorAt = os.clock() + (tonumber(m.doorLeft) or 0)
		end
		if race.state == "countdown" then
			race.standings = {}
			race.goAt = os.clock() + (tonumber(m.goIn) or 0)
		end
	elseif op == "standings" then
		race.standings = m.list or {}
	elseif op == "results" then
		race.results = m.list or {}
		race.resultsAt = os.clock()
		showPodium(race.results)
	elseif op == "closed" then
		race.door = "closed"
		race.doorAt = os.clock() + (tonumber(m.opensIn) or 0)
	elseif op == "opened" then
		race.door = "open"
	end
end
CircuitDress.onRace = onRace

---------------------------------------------------------------------------------------------------
-- Each frame
---------------------------------------------------------------------------------------------------
local function animate(t: number)
	local racing = race.state == "racing"
	-- The edge lights: a slow shimmer between races; in a race, a run of light chasing the way the
	-- cars go, fast.
	for _, l in lights do
		local phase = if racing then (l.x * l.dirX) / 14 - t * 9 else l.x / 30 - t * 1.2
		local on = math.sin(phase)
		if racing then
			l.part.Transparency = if on > 0.55 then 0 else 0.7
			l.part.Color = if on > 0.55 then rgb(255, 246, 214) else GOLD
		else
			l.part.Transparency = 0.45 + 0.2 * on
		end
	end
	-- The chevrons light one after another, the way to drive.
	for _, c in chevrons do
		local k = math.floor(t * 6) % 4
		c.part.Transparency = if k == c.k then 0 else 0.55
	end
	for _, f in flags do
		f.part.CFrame = f.base * CFrame.Angles(0, math.sin(t * 3 + f.phase) * 0.18, math.sin(t * 5 + f.phase) * 0.04)
	end
end

function CircuitDress.build(): boolean
	if built then
		return true
	end
	local maison = Workspace:FindFirstChild("Maison")
	if not (maison and maison:FindFirstChild("GrandPrix")) then
		return false
	end
	built = true
	local f = home()
	for _, make in { straightLights, boostPads, hairpinBarriers, farBoards, infield, buildPodium, lineFlags, timingTower } do
		local ok, err = pcall(function()
			make(f)
		end)
		if not ok then
			warn("[Maison] The Grand Prix's dressing: " .. tostring(err))
		end
	end
	drawTower()
	return true
end

function CircuitDress.isBuilt(): boolean
	return built
end

-- (For tests: the tower's lines as they read now.)
function CircuitDress.towerText(): { string }
	local out = {}
	if tower.state then
		drawTower()
		table.insert(out, tower.state.Text)
		for _, r in tower.rows do
			table.insert(out, r.place.Text .. " " .. r.name.Text .. " " .. r.info.Text)
		end
	end
	return out
end

function CircuitDress.start()
	local function tryCar(m: Instance)
		if m:IsA("Model") then
			if m:GetAttribute("Dressed") == true then
				CircuitDress.adopt(m)
			else
				pcall(CircuitDress.dressCar, m)
			end
		end
	end
	for _, m in CollectionService:GetTagged("MaisonCar") do
		tryCar(m)
	end
	CollectionService:GetInstanceAddedSignal("MaisonCar"):Connect(function(m)
		-- (A car's pieces arrive a moment after it does.)
		task.delay(0.5, function()
			tryCar(m)
		end)
	end)
	Remotes.event("Race").OnClientEvent:Connect(function(m: any)
		if type(m) == "table" then
			pcall(onRace, m)
		end
	end)
	task.spawn(function()
		while not CircuitDress.build() do
			task.wait(2)
		end
	end)
	-- (And a look round every few seconds, for a car whose arrival went unannounced.)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, m in CollectionService:GetTagged("MaisonCar") do
				if not cars[m :: any] then
					pcall(tryCar, m)
				end
			end
		end
	end)
	local clock, towerAt = 0, 0
	RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		if built then
			pcall(animate, clock)
			if clock - towerAt > 0.5 then
				towerAt = clock
				pcall(drawTower)
			end
		end
		pcall(engines, dt)
	end)
end

return CircuitDress

--!strict
-- The holiday games' things, made of parts the same way on the server (the places it builds:
-- Hallows Lane, the Harvest Field, the North Pole) and on every screen (what moves and what's
-- handed over: a treat in the air, a turkey on the run, a gift in someone's arms, an egg). Each
-- returns a Model whose parts are all anchored and untouchable, with its feet at the frame given
-- and facing the frame's way. `HolidayProps.rig` turns one into a puppet a screen can move by one
-- part (its Root) and bend by its welds.

local HolidayProps = {}

local rgb = Color3.fromRGB
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- (a cylinder's axis is its X: this stands it up)
local WHITE = Color3.new(1, 1, 1)
local GOLD = rgb(226, 178, 74)

HolidayProps.GOLD = GOLD

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end
HolidayProps.part = part

local function ellipsoid(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = part(parent, name, size, cf, colour, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end
HolidayProps.ellipsoid = ellipsoid

local function ball(parent: Instance, name: string, d: number, at: Vector3, colour: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(d, d, d), CFrame.new(at), colour, material, Enum.PartType.Ball)
end
HolidayProps.ball = ball

-- A rod (a cylinder) from `a` to `b`.
local function rod(parent: Instance, name: string, a: Vector3, b: Vector3, d: number, colour: Color3, material: Enum.Material?): Part
	local len = math.max(0.05, (b - a).Magnitude)
	local mid = (a + b) / 2
	local cf = if len > 0.06 then CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0) else CFrame.new(mid)
	return part(parent, name, Vector3.new(len, d, d), cf, colour, material, Enum.PartType.Cylinder)
end
HolidayProps.rod = rod

-- An upright cylinder standing on `base`.
local function post(parent: Instance, name: string, height: number, d: number, base: Vector3, colour: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(height, d, d), CFrame.new(base + Vector3.new(0, height / 2, 0)) * UPRIGHT, colour, material, Enum.PartType.Cylinder)
end
HolidayProps.post = post

-- A flat round lying with its face up.
local function disc(parent: Instance, name: string, thickness: number, d: number, centre: CFrame, colour: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(thickness, d, d), centre * UPRIGHT, colour, material, Enum.PartType.Cylinder)
end
HolidayProps.disc = disc

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.CastShadow = false
	w.Size = size
	w.CFrame = cf
	w.Color = colour
	w.Material = material or Enum.Material.SmoothPlastic
	w.Parent = parent
	return w
end
HolidayProps.wedge = wedge

local function model(parent: Instance?, name: string, cf: CFrame): (Model, Part)
	local m = Instance.new("Model")
	m.Name = name
	local root = part(m, "Root", Vector3.new(0.4, 0.4, 0.4), cf, WHITE)
	root.Transparency = 1
	m.PrimaryPart = root
	if parent then
		m.Parent = parent
	end
	return m, root
end

local function light(at: BasePart, colour: Color3, brightness: number, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = at
	return l
end

local function sparkle(at: BasePart, colour: Color3, rate: number, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Sparkle"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(colour:Lerp(WHITE, 0.6), colour)
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Parent = at
end
HolidayProps.sparkle = sparkle

-- Gold, where something is the golden one.
local function gild(m: Model)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Root" and d.Transparency < 1 then
			local keep = d.Name == "Eye" or d.Name == "Pupil"
			if not keep then
				d.Color = GOLD:Lerp(d.Color, 0.12)
				d.Material = Enum.Material.Metal
				d.Reflectance = 0.28
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- All Hallows'
---------------------------------------------------------------------------------------------------
local PUMPKIN = { rgb(232, 112, 30), rgb(212, 92, 22) }

-- A pumpkin `d` across, on `base`, its face (carved and lit, if `carved`) turned to `facing`.
function HolidayProps.pumpkin(parent: Instance, base: Vector3, d: number, facing: Vector3, carved: boolean, lit: boolean?, colours: { Color3 }?): Model
	local hue = colours or PUMPKIN
	local h = d * 0.78
	local centre = base + Vector3.new(0, h / 2, 0)
	local look = Vector3.new(facing.X, 0, facing.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(centre, centre + look)
	local m = model(parent, "Pumpkin", CFrame.new(base))
	ellipsoid(m, "Pumpkin", Vector3.new(d * 0.9, h, d * 0.9), frame, hue[1])
	-- (Ribs: six on a big one, four on a small one, where nobody counts.)
	local lobes = if d >= 2.4 then 6 else 4
	for k = 0, lobes - 1 do
		local a = math.rad(180 / lobes + k * 360 / lobes)
		ellipsoid(m, "Lobe", Vector3.new(d * 0.5, h * 0.98, d * 0.56), frame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -d * 0.24), hue[(k % 2) + 1])
	end
	part(m, "Stem", Vector3.new(d * 0.24, d * 0.12, d * 0.12), CFrame.new(centre + Vector3.new(0, h * 0.5 + d * 0.08, 0)) * UPRIGHT * CFrame.Angles(0.15, 0, 0), rgb(86, 96, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
	if carved then
		local glow = rgb(255, 196, 80)
		local face = frame * CFrame.new(0, 0, -d * 0.47)
		for _, sx in { -1, 1 } do
			part(m, "Eye", Vector3.new(d * 0.14, d * 0.14, d * 0.06), face * CFrame.new(sx * d * 0.16, h * 0.14, 0) * CFrame.Angles(0, 0, math.rad(45)), glow, Enum.Material.Neon)
		end
		part(m, "Nose", Vector3.new(d * 0.08, d * 0.08, d * 0.06), face * CFrame.Angles(0, 0, math.rad(45)), glow, Enum.Material.Neon)
		local teeth = if d >= 2.4 then 2 else 1
		for k = -teeth, teeth do
			local a = math.rad(270 + k * 44 / teeth)
			local r = d * 0.24
			part(m, "Smile", Vector3.new(d * (if teeth == 1 then 0.18 else 0.11), d * 0.055, d * 0.06), face * CFrame.new(math.cos(a) * r, h * 0.02 + math.sin(a) * r * 0.75, 0) * CFrame.Angles(0, 0, a - math.rad(270)), glow, Enum.Material.Neon)
		end
		if lit then
			local core = part(m, "Glow", Vector3.new(0.2, 0.2, 0.2), CFrame.new(centre), glow)
			core.Transparency = 1
			light(core, rgb(255, 150, 60), 1.3, d * 2.6)
		end
	end
	return m
end

-- A treat to hand over (what flies from a host's hand to a guest): "truffle", "apple", "lollipop",
-- "sweet", "macaron", "caramel", "beans", "floss" or "chocolate". About a stud and a half across.
function HolidayProps.treat(parent: Instance?, cf: CFrame, kind: string): Model
	local m = model(parent, "Treat", cf)
	if kind == "truffle" or kind == "chocolate" then
		ball(m, "Truffle", 1, (cf * CFrame.new(0, 0.55, 0)).Position, rgb(70, 40, 26), Enum.Material.SmoothPlastic)
		-- Gold foil cup and a gold fleck on top.
		part(m, "Cup", Vector3.new(0.5, 1.1, 1.1), cf * CFrame.new(0, 0.25, 0) * UPRIGHT, GOLD, Enum.Material.Foil, Enum.PartType.Cylinder)
		ball(m, "Fleck", 0.25, (cf * CFrame.new(0, 1.05, 0)).Position, GOLD, Enum.Material.Metal)
	elseif kind == "apple" then
		ball(m, "Apple", 1.2, (cf * CFrame.new(0, 0.6, 0)).Position, rgb(190, 30, 36), Enum.Material.SmoothPlastic)
		ellipsoid(m, "Caramel", Vector3.new(1.26, 0.6, 1.26), cf * CFrame.new(0, 0.85, 0), rgb(200, 130, 50), Enum.Material.SmoothPlastic)
		rod(m, "Stick", (cf * CFrame.new(0, 1, 0)).Position, (cf * CFrame.new(0, 2.1, 0)).Position, 0.12, rgb(214, 190, 150), Enum.Material.Wood)
	elseif kind == "lollipop" then
		rod(m, "Stick", (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 1.3, 0)).Position, 0.1, WHITE)
		local face = cf * CFrame.new(0, 1.9, 0)
		part(m, "Candy", Vector3.new(0.25, 1.3, 1.3), face * CFrame.Angles(0, math.pi / 2, 0), rgb(240, 80, 150), Enum.Material.Glass, Enum.PartType.Cylinder).Reflectance = 0.15
		part(m, "Swirl", Vector3.new(0.27, 0.8, 0.8), face * CFrame.Angles(0, math.pi / 2, 0), rgb(255, 230, 120), Enum.Material.Glass, Enum.PartType.Cylinder)
		part(m, "Swirl", Vector3.new(0.29, 0.36, 0.36), face * CFrame.Angles(0, math.pi / 2, 0), rgb(120, 220, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
	elseif kind == "macaron" then
		local colours = { rgb(250, 180, 200), rgb(190, 230, 190), rgb(230, 210, 250) }
		for i, c in colours do
			local y = 0.2 + (i - 1) * 0.42
			part(m, "Shell", Vector3.new(0.32, 1.05, 1.05), cf * CFrame.new(0, y, 0) * UPRIGHT, c, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			part(m, "Cream", Vector3.new(0.1, 0.95, 0.95), cf * CFrame.new(0, y + 0.2, 0) * UPRIGHT, rgb(255, 248, 236), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		end
	elseif kind == "floss" then
		rod(m, "Stick", (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 1.2, 0)).Position, 0.1, WHITE)
		ellipsoid(m, "Floss", Vector3.new(1.4, 1.6, 1.4), cf * CFrame.new(0, 1.8, 0), rgb(255, 170, 220), Enum.Material.Fabric)
		ellipsoid(m, "Floss", Vector3.new(1, 1.1, 1), cf * CFrame.new(0.3, 2.2, 0.2), rgb(180, 210, 255), Enum.Material.Fabric)
	elseif kind == "beans" then
		ellipsoid(m, "Bag", Vector3.new(1, 1.3, 0.8), cf * CFrame.new(0, 0.65, 0), rgb(110, 40, 140), Enum.Material.Fabric)
		part(m, "Tie", Vector3.new(0.6, 0.12, 0.6), cf * CFrame.new(0, 1.25, 0), GOLD, Enum.Material.Fabric)
		local beans = { rgb(255, 80, 80), rgb(255, 210, 60), rgb(90, 200, 90), rgb(80, 160, 255) }
		for i, c in beans do
			ellipsoid(m, "Bean", Vector3.new(0.22, 0.3, 0.2), cf * CFrame.new(-0.3 + i * 0.13, 1.45, 0) * CFrame.Angles(0, 0, i), c, Enum.Material.Glass)
		end
	else
		-- A wrapped sweet: the sweet in its paper, twisted at both ends.
		local colour = if kind == "caramel" then rgb(214, 150, 60) else rgb(160, 40, 200)
		local body = cf * CFrame.new(0, 0.5, 0)
		ellipsoid(m, "Sweet", Vector3.new(1.1, 0.7, 0.7), body, colour, Enum.Material.Foil)
		for _, sx in { -1, 1 } do
			wedge(m, "Twist", Vector3.new(0.6, 0.5, 0.45), body * CFrame.new(sx * 0.7, 0, 0) * CFrame.Angles(0, sx * math.pi / 2, 0), colour:Lerp(WHITE, 0.3), Enum.Material.Foil)
		end
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Thanksgiving
---------------------------------------------------------------------------------------------------

-- A turkey, standing at `cf` (feet on the ground, facing its look): a bronze body, a fan of tail
-- feathers banded in chestnut and cream, a blue-grey head and a red wattle. ("golden": all gold.)
-- Its parts are named for a screen to move: LegL, LegR, FootL, FootR, Head, Neck, Tail1..9.
function HolidayProps.turkey(parent: Instance?, cf: CFrame, golden: boolean?): Model
	local m = model(parent, if golden then "GoldenTurkey" else "Turkey", cf)
	local bronze = rgb(98, 62, 40)
	local dark = rgb(66, 40, 28)
	local wing = rgb(122, 80, 50)
	ellipsoid(m, "Body", Vector3.new(2, 1.9, 2.6), cf * CFrame.new(0, 1.75, 0.15), bronze, Enum.Material.Fabric)
	ellipsoid(m, "Breast", Vector3.new(1.55, 1.4, 1.2), cf * CFrame.new(0, 1.62, -0.85), dark, Enum.Material.Fabric)
	for _, sx in { -1, 1 } do
		ellipsoid(m, "Wing", Vector3.new(0.4, 1, 1.9), cf * CFrame.new(sx * 0.98, 1.85, 0.2) * CFrame.Angles(0.15, 0, sx * 0.08), wing, Enum.Material.Fabric)
	end
	-- The fan: nine feathers standing up behind, leaning back a little.
	local base = cf * CFrame.new(0, 2.05, 1.15) * CFrame.Angles(math.rad(-22), 0, 0)
	for i = 1, 9 do
		local a = math.rad(-76 + (i - 1) * 19)
		local dir = CFrame.Angles(0, 0, -a)
		local feather = base * dir * CFrame.new(0, 1.25, 0)
		local colour = if i % 2 == 0 then rgb(132, 82, 46) else rgb(104, 64, 38)
		part(m, "Tail" .. i, Vector3.new(0.62, 2.4, 0.12), feather, colour, Enum.Material.Fabric)
		part(m, "TailBand", Vector3.new(0.64, 0.28, 0.13), base * dir * CFrame.new(0, 2.05, 0), rgb(54, 34, 24), Enum.Material.Fabric)
		part(m, "TailTip", Vector3.new(0.64, 0.32, 0.14), base * dir * CFrame.new(0, 2.38, 0), rgb(236, 216, 176), Enum.Material.Fabric)
	end
	-- The neck and head.
	local neckFrom = (cf * CFrame.new(0, 2.25, -0.95)).Position
	local headAt = (cf * CFrame.new(0, 3.05, -1.38)).Position
	rod(m, "Neck", neckFrom, headAt, 0.46, rgb(150, 160, 178), Enum.Material.SmoothPlastic)
	ball(m, "Head", 0.62, headAt, rgb(170, 190, 210), Enum.Material.SmoothPlastic)
	-- (A wedge is thin at its front and foot: turned to look ahead, its tip points forward and down.)
	wedge(m, "Beak", Vector3.new(0.18, 0.2, 0.36), CFrame.lookAt(headAt + (cf.LookVector * 0.42), headAt + cf.LookVector * 2), rgb(236, 190, 90))
	ellipsoid(m, "Snood", Vector3.new(0.12, 0.42, 0.12), CFrame.new(headAt + cf.LookVector * 0.36 + cf.RightVector * 0.06 - Vector3.new(0, 0.12, 0)), rgb(200, 34, 44))
	ellipsoid(m, "Wattle", Vector3.new(0.3, 0.5, 0.26), CFrame.new(headAt + cf.LookVector * 0.18 - Vector3.new(0, 0.38, 0)), rgb(200, 34, 44))
	for _, sx in { -1, 1 } do
		ball(m, "Eye", 0.13, headAt + cf.LookVector * 0.22 + cf.RightVector * sx * 0.22 + Vector3.new(0, 0.08, 0), rgb(16, 14, 14))
	end
	-- Legs and feet.
	for _, side in { { name = "L", s = -1 }, { name = "R", s = 1 } } do
		local s = side.s
		local hip = (cf * CFrame.new(s * 0.42, 1.2, 0.05)).Position
		local ankle = (cf * CFrame.new(s * 0.42, 0.12, -0.02)).Position
		rod(m, "Leg" .. side.name, hip, ankle, 0.2, rgb(222, 150, 74), Enum.Material.SmoothPlastic)
		part(m, "Foot" .. side.name, Vector3.new(0.55, 0.1, 0.65), cf * CFrame.new(s * 0.42, 0.06, -0.2), rgb(222, 150, 74), Enum.Material.SmoothPlastic)
	end
	if golden then
		gild(m)
		local glow = m:FindFirstChild("Body") :: BasePart
		light(glow, rgb(255, 214, 120), 2.2, 16)
		sparkle(glow, rgb(255, 214, 120), 10, 0.5)
	end
	return m
end

-- A hay bale, `size` (long along the frame's X), standing on `cf`.
function HolidayProps.hayBale(parent: Instance, cf: CFrame, size: Vector3): Model
	local m = model(parent, "HayBale", cf)
	local body = part(m, "Hay", size, cf * CFrame.new(0, size.Y / 2, 0), rgb(206, 172, 92), Enum.Material.Fabric)
	body.CanCollide = true
	body.CastShadow = true
	for _, f in { -0.28, 0.28 } do
		part(m, "Twine", Vector3.new(0.12, size.Y + 0.04, size.Z + 0.04), cf * CFrame.new(f * size.X, size.Y / 2, 0), rgb(150, 110, 60), Enum.Material.Fabric)
	end
	return m
end

-- A bundle of dried corn stalks, tied, `height` tall.
function HolidayProps.cornShock(parent: Instance, base: Vector3, height: number): Model
	local m = model(parent, "CornShock", CFrame.new(base))
	local n = 9
	for i = 1, n do
		local a = i / n * math.pi * 2
		local foot = base + Vector3.new(math.cos(a) * height * 0.16, 0, math.sin(a) * height * 0.16)
		local top = base + Vector3.new(math.cos(a + 0.4) * height * 0.08, height, math.sin(a + 0.4) * height * 0.08)
		rod(m, "Stalk", foot, top, height * 0.035, if i % 2 == 0 then rgb(196, 166, 100) else rgb(176, 146, 84), Enum.Material.Wood)
	end
	part(m, "Tie", Vector3.new(height * 0.1, height * 0.2, height * 0.2), CFrame.new(base + Vector3.new(0, height * 0.55, 0)) * UPRIGHT, rgb(150, 60, 30), Enum.Material.Fabric, Enum.PartType.Cylinder)
	return m
end

-- A tree in autumn: a trunk, two boughs and a crown of leaf balls in reds and golds.
function HolidayProps.autumnTree(parent: Instance, base: Vector3, height: number, rng: Random, colours: { Color3 }?): Model
	local hues = colours or { rgb(196, 70, 30), rgb(222, 128, 38), rgb(232, 176, 60), rgb(160, 46, 30) }
	local m = model(parent, "AutumnTree", CFrame.new(base))
	local trunkH = height * 0.5
	local trunk = post(m, "Trunk", trunkH, height * 0.08, base, rgb(70, 48, 34), Enum.Material.Wood)
	trunk.CastShadow = true
	trunk.CanCollide = true
	for _, side in { -1, 1 } do
		local from = base + Vector3.new(0, trunkH * 0.7, 0)
		local to = from + Vector3.new(side * height * 0.16, height * 0.17, side * height * 0.05)
		rod(m, "Bough", from, to, height * 0.04, rgb(70, 48, 34), Enum.Material.Wood)
	end
	local crown = base + Vector3.new(0, height * 0.7, 0)
	for i = 1, 11 do
		local a = i / 11 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = if i == 11 then 0 else rng:NextNumber(0.12, 0.26) * height
		local y = if i == 11 then height * 0.12 else rng:NextNumber(-0.08, 0.1) * height
		local d = rng:NextNumber(0.26, 0.36) * height
		ball(m, "Leaves", d, crown + Vector3.new(math.cos(a) * r, y, math.sin(a) * r), hues[(i % #hues) + 1], Enum.Material.Grass).CastShadow = true
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Christmas
---------------------------------------------------------------------------------------------------
HolidayProps.WRAPS = {
	{ rgb(176, 26, 44), rgb(242, 208, 112) }, -- crimson, gold ribbon
	{ rgb(24, 98, 66), rgb(232, 64, 64) }, -- pine, red ribbon
	{ rgb(240, 236, 226), rgb(200, 30, 50) }, -- ivory, red ribbon
	{ rgb(36, 60, 150), rgb(236, 236, 246) }, -- royal blue, silver ribbon
	{ rgb(232, 182, 70), rgb(176, 26, 44) }, -- gold, crimson ribbon
	{ rgb(120, 40, 140), rgb(242, 208, 112) }, -- plum, gold ribbon
	{ rgb(250, 160, 190), rgb(255, 255, 255) }, -- pink, white ribbon
	{ rgb(40, 150, 160), rgb(242, 208, 112) }, -- teal, gold ribbon
}

-- A wrapped gift, `size`, standing on `cf`: the box, its lid, ribbons both ways and a bow.
function HolidayProps.gift(parent: Instance?, cf: CFrame, size: Vector3, wrap: Color3, ribbon: Color3): Model
	local m = model(parent, "Gift", cf)
	local body = size.Y * 0.8
	local box = part(m, "Box", Vector3.new(size.X, body, size.Z), cf * CFrame.new(0, body / 2, 0), wrap, Enum.Material.SmoothPlastic)
	box.Reflectance = 0.05
	local lidH = size.Y * 0.22
	local lid = part(m, "Lid", Vector3.new(size.X * 1.07, lidH, size.Z * 1.07), cf * CFrame.new(0, body + lidH / 2 - 0.02, 0), wrap:Lerp(WHITE, 0.06), Enum.Material.SmoothPlastic)
	lid.Reflectance = 0.06
	local rw = math.min(size.X, size.Z) * 0.16
	part(m, "Ribbon", Vector3.new(size.X + 0.05, body + 0.03, rw), cf * CFrame.new(0, body / 2, 0), ribbon, Enum.Material.Fabric)
	part(m, "Ribbon", Vector3.new(rw, body + 0.03, size.Z + 0.05), cf * CFrame.new(0, body / 2, 0), ribbon, Enum.Material.Fabric)
	part(m, "Ribbon", Vector3.new(size.X * 1.07 + 0.05, lidH + 0.03, rw), lid.CFrame, ribbon, Enum.Material.Fabric)
	part(m, "Ribbon", Vector3.new(rw, lidH + 0.03, size.Z * 1.07 + 0.05), lid.CFrame, ribbon, Enum.Material.Fabric)
	-- The bow: two loops, a knot and two tails.
	local top = cf * CFrame.new(0, body + lidH, 0)
	local loop = math.min(size.X, size.Z) * 0.34
	for _, sx in { -1, 1 } do
		ellipsoid(m, "Bow", Vector3.new(loop, loop * 0.62, loop * 0.36), top * CFrame.new(sx * loop * 0.42, loop * 0.24, 0) * CFrame.Angles(0, 0, sx * math.rad(-28)), ribbon, Enum.Material.Fabric)
		part(m, "BowTail", Vector3.new(loop * 0.5, 0.06, rw * 0.8), top * CFrame.new(sx * loop * 0.32, 0.03, rw * 0.6) * CFrame.Angles(0, sx * math.rad(30), 0), ribbon, Enum.Material.Fabric)
	end
	ball(m, "Knot", loop * 0.34, (top * CFrame.new(0, loop * 0.18, 0)).Position, ribbon:Lerp(Color3.new(0, 0, 0), 0.08), Enum.Material.Fabric)
	return m
end

-- A candy cane, red and white, `height` tall, its crook turned toward `facing`.
function HolidayProps.candyCane(parent: Instance, base: Vector3, height: number, facing: Vector3): Model
	local m = model(parent, "CandyCane", CFrame.new(base))
	local d = height * 0.09
	local segs = 8
	local stem = height * 0.78
	for i = 0, segs - 1 do
		local y = base.Y + (i + 0.5) * stem / segs
		part(m, "Cane", Vector3.new(stem / segs + 0.02, d, d), CFrame.new(base.X, y, base.Z) * UPRIGHT, if i % 2 == 0 then rgb(220, 30, 44) else WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local dir = Vector3.new(facing.X, 0, facing.Z)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(1, 0, 0)
	local top = Vector3.new(base.X, base.Y + stem, base.Z)
	local r = height * 0.13
	local centre = top + dir * r
	local pieces = 6
	for i = 0, pieces - 1 do
		local a0 = math.pi - i / pieces * math.pi
		local a1 = math.pi - (i + 1) / pieces * math.pi
		local p0 = centre + dir * math.cos(a0) * r + Vector3.new(0, math.sin(a0) * r, 0)
		local p1 = centre + dir * math.cos(a1) * r + Vector3.new(0, math.sin(a1) * r, 0)
		rod(m, "Cane", p0, p1, d, if i % 2 == 0 then WHITE else rgb(220, 30, 44))
	end
	return m
end

-- A reindeer standing at `cf`, harnessed in red with gold bells. Rudolph leads with his nose aglow.
-- Its parts are named for a screen to move: Leg1..4 and Hoof1..4 (front left, front right, back
-- left, back right), Head.
function HolidayProps.reindeer(parent: Instance?, cf: CFrame, rudolph: boolean?): Model
	local m = model(parent, if rudolph then "Rudolph" else "Reindeer", cf)
	local coat = rgb(122, 82, 52)
	local pale = rgb(214, 186, 146)
	local hoof = rgb(40, 30, 26)
	local antler = rgb(214, 188, 140)
	ellipsoid(m, "Body", Vector3.new(2, 2.1, 4.3), cf * CFrame.new(0, 3.35, 0), coat, Enum.Material.Fabric).CastShadow = true
	ellipsoid(m, "Belly", Vector3.new(1.7, 1.2, 3.3), cf * CFrame.new(0, 2.95, 0.1), pale, Enum.Material.Fabric)
	ellipsoid(m, "Chest", Vector3.new(1.6, 1.6, 1.2), cf * CFrame.new(0, 3.4, -1.8), pale, Enum.Material.Fabric)
	local legs = { { -0.62, -1.45 }, { 0.62, -1.45 }, { -0.62, 1.45 }, { 0.62, 1.45 } }
	for i, l in legs do
		local top = (cf * CFrame.new(l[1], 2.75, l[2])).Position
		local foot = (cf * CFrame.new(l[1], 0.3, l[2])).Position
		rod(m, "Leg" .. i, top, foot, 0.4, coat:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Fabric)
		part(m, "Hoof" .. i, Vector3.new(0.3, 0.48, 0.48), CFrame.new(foot - Vector3.new(0, 0.15, 0)) * UPRIGHT, hoof, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	local neckFrom = (cf * CFrame.new(0, 3.9, -1.7)).Position
	local headAt = (cf * CFrame.new(0, 5.55, -2.75)).Position
	rod(m, "Neck", neckFrom, headAt, 0.95, coat, Enum.Material.Fabric)
	ellipsoid(m, "Head", Vector3.new(1.05, 1.05, 1.5), CFrame.lookAt(headAt, headAt + cf.LookVector - Vector3.new(0, 0.35, 0)), coat, Enum.Material.Fabric)
	local muzzle = headAt + cf.LookVector * 0.85 - Vector3.new(0, 0.28, 0)
	ellipsoid(m, "Muzzle", Vector3.new(0.75, 0.62, 0.8), CFrame.lookAt(muzzle, muzzle + cf.LookVector), pale, Enum.Material.Fabric)
	local nose = ball(m, "Nose", if rudolph then 0.5 else 0.34, muzzle + cf.LookVector * 0.42 + Vector3.new(0, 0.08, 0), if rudolph then rgb(255, 40, 40) else rgb(30, 22, 20), if rudolph then Enum.Material.Neon else Enum.Material.SmoothPlastic)
	if rudolph then
		light(nose, rgb(255, 60, 50), 3, 18)
	end
	for _, sx in { -1, 1 } do
		ball(m, "Eye", 0.17, headAt + cf.LookVector * 0.35 + cf.RightVector * sx * 0.4 + Vector3.new(0, 0.2, 0), rgb(20, 16, 14))
		ellipsoid(m, "Ear", Vector3.new(0.22, 0.32, 0.62), CFrame.new(headAt + cf.RightVector * sx * 0.55 + Vector3.new(0, 0.38, 0.1)) * cf.Rotation * CFrame.Angles(0, 0, sx * -0.6), coat, Enum.Material.Fabric)
		-- An antler: a beam up and out, and two tines.
		local root = headAt + cf.RightVector * sx * 0.32 + Vector3.new(0, 0.48, 0.15)
		local tip = root + cf.RightVector * sx * 1.0 + Vector3.new(0, 1.55, 0) + cf.LookVector * -0.25
		rod(m, "Antler", root, tip, 0.17, antler, Enum.Material.SmoothPlastic)
		local mid = root:Lerp(tip, 0.5)
		rod(m, "Antler", mid, mid + cf.LookVector * 0.55 + Vector3.new(0, 0.55, 0), 0.13, antler, Enum.Material.SmoothPlastic)
		rod(m, "Antler", tip, tip + cf.RightVector * sx * 0.3 + cf.LookVector * 0.35 + Vector3.new(0, 0.35, 0), 0.12, antler, Enum.Material.SmoothPlastic)
	end
	ellipsoid(m, "Tail", Vector3.new(0.5, 0.5, 0.4), cf * CFrame.new(0, 3.9, 2.2), rgb(240, 236, 228), Enum.Material.Fabric)
	-- The harness: a red band with gold bells, and a collar.
	part(m, "Harness", Vector3.new(2.12, 0.4, 0.5), cf * CFrame.new(0, 3.35, -0.6), rgb(170, 22, 36), Enum.Material.Leather)
	part(m, "Collar", Vector3.new(1.1, 0.3, 1.1), CFrame.new(neckFrom:Lerp(headAt, 0.3)) * cf.Rotation * CFrame.Angles(math.rad(-38), 0, 0), rgb(170, 22, 36), Enum.Material.Leather)
	for k = -1, 1 do
		ball(m, "Bell", 0.3, (cf * CFrame.new(k * 0.45, 3.05, -1.55)).Position, GOLD, Enum.Material.Metal).Reflectance = 0.3
	end
	return m
end

-- A snowman, `height` tall, facing `facing`: three snowballs, a scarf, a top hat, coal buttons and
-- a carrot nose.
function HolidayProps.snowman(parent: Instance, base: Vector3, height: number, facing: Vector3): Model
	local m = model(parent, "Snowman", CFrame.new(base))
	local look = Vector3.new(facing.X, 0, facing.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local snow = rgb(232, 238, 248)
	local r1, r2, r3 = height * 0.22, height * 0.16, height * 0.12
	local y1 = r1 * 0.9
	local y2 = y1 + r1 * 0.75 + r2 * 0.8
	local y3 = y2 + r2 * 0.75 + r3 * 0.85
	local frame = CFrame.lookAt(base, base + look)
	ball(m, "Snow", r1 * 2, (frame * CFrame.new(0, y1, 0)).Position, snow, Enum.Material.Snow).CastShadow = true
	ball(m, "Snow", r2 * 2, (frame * CFrame.new(0, y2, 0)).Position, snow, Enum.Material.Snow).CastShadow = true
	local head = (frame * CFrame.new(0, y3, 0)).Position
	ball(m, "Snow", r3 * 2, head, snow, Enum.Material.Snow).CastShadow = true
	for _, sx in { -1, 1 } do
		ball(m, "Coal", r3 * 0.2, head + frame.LookVector * r3 * 0.9 + frame.RightVector * sx * r3 * 0.35 + Vector3.new(0, r3 * 0.25, 0), rgb(24, 22, 24))
	end
	wedge(m, "Carrot", Vector3.new(r3 * 0.26, r3 * 0.26, r3 * 1.1), CFrame.lookAt(head + frame.LookVector * r3 * 1.3, head + frame.LookVector * 5), rgb(240, 120, 30))
	for k = 0, 2 do
		ball(m, "Button", r2 * 0.18, (frame * CFrame.new(0, y2 + r2 * (0.4 - k * 0.4), 0)).Position + frame.LookVector * r2 * 0.95, rgb(24, 22, 24))
	end
	-- The scarf, and the top hat.
	part(m, "Scarf", Vector3.new(r2 * 0.4, r3 * 1.75, r3 * 1.75), CFrame.new((frame * CFrame.new(0, y2 + r2 * 0.75, 0)).Position) * UPRIGHT, rgb(196, 30, 44), Enum.Material.Fabric, Enum.PartType.Cylinder)
	part(m, "ScarfEnd", Vector3.new(r3 * 0.45, r2 * 1.1, r3 * 0.12), frame * CFrame.new(r3 * 0.55, y2 + r2 * 0.2, -r2 * 0.8), rgb(196, 30, 44), Enum.Material.Fabric)
	local hat = head + Vector3.new(0, r3 * 0.85, 0)
	part(m, "Brim", Vector3.new(r3 * 0.12, r3 * 1.9, r3 * 1.9), CFrame.new(hat) * UPRIGHT, rgb(20, 20, 24), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(m, "Hat", Vector3.new(r3 * 1.1, r3 * 1.25, r3 * 1.25), CFrame.new(hat + Vector3.new(0, r3 * 0.55, 0)) * UPRIGHT, rgb(20, 20, 24), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(m, "Band", Vector3.new(r3 * 0.22, r3 * 1.28, r3 * 1.28), CFrame.new(hat + Vector3.new(0, r3 * 0.18, 0)) * UPRIGHT, rgb(196, 30, 44), Enum.Material.Fabric, Enum.PartType.Cylinder)
	return m
end

-- A snowy fir: tiers of boughs (each a cone of wedges) with snow on their tops, `height` tall.
function HolidayProps.fir(parent: Instance, base: Vector3, height: number, snowy: boolean): Model
	local m = model(parent, "Fir", CFrame.new(base))
	local pines = { rgb(26, 76, 50), rgb(20, 64, 42), rgb(30, 86, 56) }
	local trunk = post(m, "Trunk", height * 0.14, height * 0.07, base, rgb(78, 52, 34), Enum.Material.Wood)
	trunk.CanCollide = true
	local tiers = 6
	local R = height * 0.31
	for i = 0, tiers - 1 do
		local r = R * (1 - i * 0.15)
		local y = base.Y + height * (0.1 + i * 0.135)
		local h = math.max(r * 1.25, height * 0.1)
		local slices = if r > 6 then 12 else 8
		local w = 2 * r * math.tan(math.pi / slices) * 1.12
		for k = 0, slices - 1 do
			local a = k / slices * math.pi * 2 + i * 0.4
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local centre = Vector3.new(base.X, y + h / 2, base.Z) + out * (r / 2)
			local wg = wedge(m, "Boughs", Vector3.new(w, h, r), CFrame.lookAt(centre, centre + out), pines[(k + i) % #pines + 1], Enum.Material.Grass)
			wg.CastShadow = true
			if snowy and k % 2 == 0 then
				local sc = Vector3.new(base.X, y + h * 0.62, base.Z) + out * (r * 0.42)
				wedge(m, "Snow", Vector3.new(w * 0.8, h * 0.28, r * 0.62), CFrame.lookAt(sc, sc + out), rgb(232, 238, 248), Enum.Material.Snow)
			end
		end
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Easter
---------------------------------------------------------------------------------------------------
HolidayProps.EGGS = {
	{ rgb(250, 182, 206), rgb(255, 240, 160), rgb(255, 255, 255) }, -- pink, butter and white
	{ rgb(170, 214, 250), rgb(255, 255, 255), rgb(250, 182, 206) }, -- sky
	{ rgb(196, 234, 180), rgb(255, 214, 120), rgb(255, 255, 255) }, -- mint
	{ rgb(220, 196, 250), rgb(250, 230, 120), rgb(170, 214, 250) }, -- lilac
	{ rgb(255, 214, 140), rgb(240, 120, 120), rgb(255, 255, 255) }, -- apricot
	{ rgb(255, 245, 170), rgb(150, 200, 255), rgb(250, 182, 206) }, -- lemon
}

-- A painted egg, `height` tall, standing on `cf`: its colour, two bands and a ring of dots.
function HolidayProps.egg(parent: Instance?, cf: CFrame, height: number, scheme: { Color3 }, golden: boolean?): Model
	local m = model(parent, if golden then "GoldenEgg" else "Egg", cf)
	local w = height * 0.74
	local frame = cf * CFrame.new(0, height / 2, 0)
	local body = ellipsoid(m, "Egg", Vector3.new(w, height, w), frame, scheme[1], Enum.Material.SmoothPlastic)
	body.Reflectance = 0.04
	for _, f in { -0.2, 0.22 } do
		local y = f * height
		local rr = w * math.sqrt(math.max(0, 1 - (2 * y / height) ^ 2))
		ellipsoid(m, "Band", Vector3.new(rr + 0.04, height * 0.08, rr + 0.04), frame * CFrame.new(0, y, 0), scheme[2], Enum.Material.SmoothPlastic)
	end
	local dots = 8
	for k = 1, dots do
		local a = k / dots * math.pi * 2
		ball(m, "Dot", height * 0.09, (frame * CFrame.new(math.cos(a) * w * 0.49, height * 0.01, math.sin(a) * w * 0.49)).Position, scheme[3], Enum.Material.SmoothPlastic)
	end
	if golden then
		gild(m)
		light(body, rgb(255, 214, 120), 1.8, 12)
		sparkle(body, rgb(255, 214, 120), 8, 0.4)
	end
	return m
end

---------------------------------------------------------------------------------------------------
-- Puppets: one part moves the whole thing, welds bend it
---------------------------------------------------------------------------------------------------

-- Welds every part of `m` to its Root (each keeping its place) and lets them go, so moving the Root
-- moves it all; returns each part's weld by the part's name (the first of that name).
function HolidayProps.rig(m: Model): { [string]: Weld }
	local root = m.PrimaryPart
	local welds: { [string]: Weld } = {}
	if not root then
		return welds
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = d
			w.C0 = root.CFrame:ToObjectSpace(d.CFrame)
			w.Parent = d
			d.Anchored = false
			d.Massless = true
			if not welds[d.Name] then
				welds[d.Name] = w
			end
		end
	end
	root.Anchored = true
	return welds
end

return HolidayProps

--!strict
-- Building blocks for the Maison: anchored parts with the house materials, lamps, engraved text.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Breathe = require(ReplicatedStorage.Shared.Breathe)

local Kit = {}

export type Look = {
	color: Color3,
	material: Enum.Material,
	reflectance: number?,
	transparency: number?,
}

local C = Brand.Colours

Kit.Looks = ({
	blackMarble = { color = Color3.fromRGB(18, 18, 21), material = Enum.Material.Marble, reflectance = 0.08 },
	boneMarble = { color = Color3.fromRGB(226, 219, 204), material = Enum.Material.Marble, reflectance = 0.05 },
	wall = { color = Color3.fromRGB(22, 22, 26), material = Enum.Material.Plaster },
	panel = { color = Color3.fromRGB(28, 28, 32), material = Enum.Material.Wood },
	facade = { color = Color3.fromRGB(14, 14, 17), material = Enum.Material.Brick },
	facadeTrim = { color = Color3.fromRGB(26, 26, 30), material = Enum.Material.Concrete },
	neighbour = { color = Color3.fromRGB(34, 32, 34), material = Enum.Material.Brick },
	neighbourStone = { color = Color3.fromRGB(58, 56, 54), material = Enum.Material.Limestone },
	-- Antique brass, a shade deeper than the gold of the type: under warm lamps it reads as metal,
	-- not as a glowing yellow.
	brass = { color = Color3.fromRGB(160, 122, 58), material = Enum.Material.Metal, reflectance = 0.15 },
	darkBrass = { color = Color3.fromRGB(98, 74, 34), material = Enum.Material.Metal, reflectance = 0.12 },
	blackLacquer = { color = Color3.fromRGB(10, 10, 12), material = Enum.Material.SmoothPlastic, reflectance = 0.18 },
	wetStone = { color = Color3.fromRGB(38, 40, 44), material = Enum.Material.Slate, reflectance = 0.06 },
	asphalt = { color = Color3.fromRGB(22, 23, 26), material = Enum.Material.Asphalt, reflectance = 0.04 },
	puddle = { color = Color3.fromRGB(16, 18, 22), material = Enum.Material.Glass, reflectance = 0.45, transparency = 0.1 },
	kerb = { color = Color3.fromRGB(70, 70, 72), material = Enum.Material.Granite },
	glassWarm = { color = Color3.fromRGB(255, 196, 120), material = Enum.Material.Glass, reflectance = 0.1, transparency = 0.25 },
	windowGlow = { color = Color3.fromRGB(255, 184, 108), material = Enum.Material.Neon, transparency = 0.35 },
	smokedGlass = { color = Color3.fromRGB(40, 44, 52), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0.55 },
	burgundyVelvet = { color = Color3.fromRGB(70, 18, 28), material = Enum.Material.Fabric },
	deepVelvet = { color = Color3.fromRGB(46, 10, 18), material = Enum.Material.Fabric },
	greenVelvet = { color = Color3.fromRGB(18, 48, 36), material = Enum.Material.Fabric },
	felt = { color = C.felt, material = Enum.Material.Fabric },
	walnut = { color = Color3.fromRGB(52, 30, 20), material = Enum.Material.Wood },
	darkWood = { color = Color3.fromRGB(30, 20, 16), material = Enum.Material.Wood },
	carpet = { color = Color3.fromRGB(58, 16, 24), material = Enum.Material.Carpet },
	leather = { color = Color3.fromRGB(58, 28, 20), material = Enum.Material.Leather },
	bone = { color = C.bone, material = Enum.Material.SmoothPlastic },
	ink = { color = Color3.fromRGB(8, 9, 12), material = Enum.Material.SmoothPlastic },
	rope = { color = Color3.fromRGB(110, 16, 30), material = Enum.Material.Fabric },
	fire = { color = Color3.fromRGB(255, 130, 50), material = Enum.Material.Neon },
	ember = { color = Color3.fromRGB(180, 60, 20), material = Enum.Material.Neon, transparency = 0.2 },
	books = { color = Color3.fromRGB(60, 24, 20), material = Enum.Material.Fabric },
	skyline = { color = Color3.fromRGB(10, 12, 18), material = Enum.Material.SmoothPlastic },
	cityLight = { color = Color3.fromRGB(255, 214, 150), material = Enum.Material.Neon, transparency = 0.2 },
} :: any) :: { [string]: Look }

function Kit.part(parent: Instance, name: string, size: Vector3, cframe: CFrame, look: Look, opts: { [string]: any }?): Part
	Breathe.now() -- (the house is thousands of parts: built in breaths, never one long stretch)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = look.color
	p.Material = look.material
	p.Reflectance = look.reflectance or 0
	p.Transparency = look.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if opts then
		if opts.shape then
			p.Shape = opts.shape
			p.Size = size
		end
		if opts.collide == false then
			p.CanCollide = false
		end
		if opts.query == false then
			p.CanQuery = false
		end
		if opts.shadow == false then
			p.CastShadow = false
		end
	end
	p.Parent = parent
	return p
end

-- A part from min/max corners, axis aligned. Handy for walls and floors.
function Kit.span(parent: Instance, name: string, a: Vector3, b: Vector3, look: Look, opts: { [string]: any }?): Part
	local lo = Vector3.new(math.min(a.X, b.X), math.min(a.Y, b.Y), math.min(a.Z, b.Z))
	local hi = Vector3.new(math.max(a.X, b.X), math.max(a.Y, b.Y), math.max(a.Z, b.Z))
	local size = hi - lo
	return Kit.part(parent, name, size, CFrame.new((lo + hi) / 2), look, opts)
end

function Kit.cylinder(parent: Instance, name: string, length: number, diameter: number, cframe: CFrame, look: Look, opts: { [string]: any }?): Part
	-- (A copy: the caller's options are often shared by many parts, and must stay as they were.)
	local o: { [string]: any } = if opts then table.clone(opts) else {}
	o.shape = Enum.PartType.Cylinder
	return Kit.part(parent, name, Vector3.new(length, diameter, diameter), cframe, look, o)
end

-- A cylinder standing upright.
function Kit.post(parent: Instance, name: string, height: number, diameter: number, base: Vector3, look: Look, opts: { [string]: any }?): Part
	local cf = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return Kit.cylinder(parent, name, height, diameter, cf, look, opts)
end

function Kit.ball(parent: Instance, name: string, diameter: number, position: Vector3, look: Look, opts: { [string]: any }?): Part
	local o: { [string]: any } = if opts then table.clone(opts) else {}
	o.shape = Enum.PartType.Ball
	return Kit.part(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(position), look, o)
end

function Kit.model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

function Kit.folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- A warm lamp: a small glowing shade with a point light, tagged so the season can tint it.
function Kit.pointLight(parent: BasePart, brightness: number, range: number, color: Color3?, shadows: boolean?): PointLight
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = range
	light.Color = color or Color3.fromRGB(255, 196, 128)
	light.Shadows = shadows == true
	light.Parent = parent
	CollectionService:AddTag(light, "HouseLamp")
	light:SetAttribute("BaseColor", light.Color)
	light:SetAttribute("BaseBrightness", brightness)
	return light
end

function Kit.spotLight(parent: BasePart, face: Enum.NormalId, brightness: number, range: number, angle: number, color: Color3?, shadows: boolean?): SpotLight
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Brightness = brightness
	light.Range = range
	light.Angle = angle
	light.Color = color or Color3.fromRGB(255, 200, 140)
	-- Shadows only where asked: dozens of shadow-casting lamps make the house stutter.
	light.Shadows = shadows ~= false
	light.Parent = parent
	CollectionService:AddTag(light, "HouseLamp")
	light:SetAttribute("BaseColor", light.Color)
	light:SetAttribute("BaseBrightness", brightness)
	return light
end

-- Engraved text on a face of a part.
function Kit.engrave(part: BasePart, face: Enum.NormalId, lines: { { text: string, size: number, font: Font?, color: Color3? } }, opts: { [string]: any }?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- Sharp at any distance a guest reads it from (fewer pixels a stud blur the letters).
	gui.PixelsPerStud = math.max(90, if opts and opts.ppu then opts.ppu else 100)
	gui.LightInfluence = if opts and opts.lit == false then 0 else 0.6
	gui.Brightness = if opts and opts.brightness then opts.brightness else 1.4
	gui.MaxDistance = if opts and opts.maxDistance then opts.maxDistance else 120
	gui.ClipsDescendants = true
	gui.Parent = part

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local inset = Instance.new("UIPadding")
	inset.PaddingTop = UDim.new(0.06, 0)
	inset.PaddingBottom = UDim.new(0.06, 0)
	inset.Parent = holder

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(if opts and opts.gap then opts.gap else 0.02, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder

	for i, line in lines do
		local label = Instance.new("TextLabel")
		label.Name = "Line" .. i
		label.LayoutOrder = i
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(0.94, 0, line.size, 0)
		label.FontFace = line.font or Brand.Fonts.display
		label.Text = line.text
		label.TextColor3 = line.color or C.gold
		label.TextScaled = true
		label.Parent = holder
	end
	return gui
end

-- A sign on a brass stand: a lacquered board in a brass frame on a slim pedestal, its words in
-- gold. `cf` is the foot of the stand, facing the way the words face; the board's centre stands
-- `raise` studs up. Returns the board (its SurfaceGui has a TextLabel per line, in order).
function Kit.sign(parent: Instance, name: string, cf: CFrame, width: number, height: number, lines: { { text: string, size: number, font: Font?, color: Color3? } }, raise: number?): BasePart
	local model = Kit.model(parent, name)
	local L = Kit.Looks
	local y = raise or 3.6
	Kit.part(model, "Base", Vector3.new(1.4, 0.12, 0.9), cf * CFrame.new(0, 0.06, 0), L.brass)
	Kit.post(model, "Post", y - height / 2 + 0.1, 0.18, (cf * CFrame.new(0, 0.12, 0)).Position, L.brass)
	Kit.part(model, "Frame", Vector3.new(width + 0.24, height + 0.24, 0.1), cf * CFrame.new(0, y, 0.04), L.brass)
	local board = Kit.part(model, "Board", Vector3.new(width, height, 0.12), cf * CFrame.new(0, y, 0), L.blackLacquer)
	Kit.engrave(board, Enum.NormalId.Front, lines, { ppu = 100, lit = false, brightness = 1.2 })
	return board
end

-- Everything in a model stays in memory on every client (streaming never drops it).
function Kit.persist(model: Model)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
end

return Kit

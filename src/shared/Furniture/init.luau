--!strict
-- The house's furniture, drawn from parts: every piece a guest can put in their Suite, and the
-- pieces the server sets in the public rooms (the Terrace, the Ballroom...). One library, used by
-- the server's builders and by each guest's own screen (SuiteView), so a piece looks the same
-- wherever it stands.
--
-- Every piece is built in its own frame: standing on the floor at the origin, its front toward -Z
-- (CFrame.lookAt(spot, whatItFaces) puts it in the room). A piece's look comes from a style table
-- (style.model picks the design within its kind; colour, accent and the rest tint it).
--
-- A piece can be built a size up (Furniture.build's `scale`: the Suite's pieces are), every part
-- and place to sit grown by it from the piece's foot.
--
-- Seats: a piece people can sit on carries invisible "SitSpot" parts (one per place to sit, its
-- top surface where a guest sits, facing the way they face) and one "SeatPrompt" for the whole
-- piece; the Seating code sits a guest in the nearest free one. Things to use (a television, a
-- shower) carry a "UsePrompt" whose attribute "Use" names what it does.

local CollectionService = game:GetService("CollectionService")

local Furniture = {}

export type Look = { color: Color3, material: Enum.Material, reflectance: number?, transparency: number? }
export type Style = { [string]: any }
export type Builder = {
	model: Model,
	base: CFrame,
	lit: boolean, -- whether the piece's lamps carry real lights
	lights: number, -- how many it has made
	seats: { CFrame }, -- every place to sit, in the piece's own frame
	k: number, -- the piece's size (1: as drawn)
}
export type Opts = { collide: boolean?, query: boolean?, shadow: boolean?, shape: Enum.PartType? }

local rgb = Color3.fromRGB

local function look(c: Color3, m: Enum.Material, refl: number?, transp: number?): Look
	return { color = c, material = m, reflectance = refl, transparency = transp }
end
Furniture.look = look

-- The house palette. Pieces take their own colours from their style; these are the fixed ones.
Furniture.Looks = {
	brass = look(rgb(170, 132, 64), Enum.Material.Metal, 0.18),
	gold = look(rgb(214, 176, 92), Enum.Material.Metal, 0.28),
	darkBrass = look(rgb(98, 74, 34), Enum.Material.Metal, 0.12),
	chrome = look(rgb(196, 200, 206), Enum.Material.Metal, 0.35),
	steel = look(rgb(36, 37, 41), Enum.Material.Metal, 0.12),
	blackLacquer = look(rgb(12, 12, 14), Enum.Material.SmoothPlastic, 0.2),
	ivoryLacquer = look(rgb(232, 224, 208), Enum.Material.SmoothPlastic, 0.1),
	walnut = look(rgb(60, 36, 24), Enum.Material.Wood),
	ebony = look(rgb(24, 18, 16), Enum.Material.Wood),
	oak = look(rgb(136, 98, 62), Enum.Material.Wood),
	whiteOak = look(rgb(184, 156, 118), Enum.Material.Wood),
	teak = look(rgb(110, 70, 40), Enum.Material.WoodPlanks),
	whiteMarble = look(rgb(232, 226, 214), Enum.Material.Marble, 0.06),
	blackMarble = look(rgb(20, 20, 23), Enum.Material.Marble, 0.1),
	greenMarble = look(rgb(28, 70, 54), Enum.Material.Marble, 0.08),
	travertine = look(rgb(204, 186, 156), Enum.Material.Limestone),
	stone = look(rgb(150, 144, 136), Enum.Material.Slate),
	linen = look(rgb(222, 214, 196), Enum.Material.Fabric),
	cream = look(rgb(238, 230, 214), Enum.Material.Fabric),
	charcoal = look(rgb(40, 40, 44), Enum.Material.Fabric),
	leather = look(rgb(74, 38, 24), Enum.Material.Leather),
	blackLeather = look(rgb(22, 20, 20), Enum.Material.Leather),
	glass = look(rgb(196, 214, 222), Enum.Material.Glass, 0.15, 0.62),
	smoked = look(rgb(40, 44, 50), Enum.Material.Glass, 0.2, 0.45),
	mirror = look(rgb(206, 212, 218), Enum.Material.Glass, 0.65, 0.05),
	water = look(rgb(52, 150, 176), Enum.Material.Glass, 0.25, 0.35),
	warmGlow = look(rgb(255, 214, 160), Enum.Material.Neon, nil, 0.05),
	coolGlow = look(rgb(170, 210, 255), Enum.Material.Neon, nil, 0.1),
	screen = look(rgb(16, 20, 30), Enum.Material.Glass, 0.3, 0),
	leaf = look(rgb(46, 86, 50), Enum.Material.Grass),
	darkLeaf = look(rgb(30, 62, 38), Enum.Material.Grass),
	soil = look(rgb(46, 34, 26), Enum.Material.Ground),
	terracotta = look(rgb(170, 92, 62), Enum.Material.Concrete),
	rubber = look(rgb(28, 28, 30), Enum.Material.Rubber),
	fire = look(rgb(255, 140, 60), Enum.Material.Neon),
	ember = look(rgb(200, 70, 24), Enum.Material.Neon, nil, 0.15),
	paper = look(rgb(240, 234, 220), Enum.Material.SmoothPlastic),
}

-- A look in a given colour and (optional) material name from a style ("Fabric", "Leather"...).
function Furniture.tint(c: any, material: any, fallback: Enum.Material?): Look
	local colour = if typeof(c) == "Color3" then c else rgb(60, 50, 46)
	local m = fallback or Enum.Material.Fabric
	if type(material) == "string" then
		local ok, found = pcall(function()
			return (Enum.Material :: any)[material]
		end)
		if ok and found then
			m = found
		end
	end
	local refl = if m == Enum.Material.Metal then 0.2 elseif m == Enum.Material.SmoothPlastic then 0.12 else nil
	return look(colour, m, refl)
end

-- A colour from a style key, or a default.
function Furniture.colour(st: Style, key: string, default: Color3): Color3
	local c = st[key]
	return if typeof(c) == "Color3" then c else default
end

---------------------------------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------------------------------

function Furniture.builder(model: Model, base: CFrame, lit: boolean?, scale: number?): Builder
	return { model = model, base = base, lit = lit ~= false, lights = 0, seats = {}, k = scale or 1 }
end

-- Where `at` (in the piece's frame, as drawn) is on a piece built at its size.
local function sized(b: Builder, at: CFrame): CFrame
	if b.k == 1 then
		return at
	end
	return at - at.Position + at.Position * b.k
end

-- A block, `at` in the piece's own frame.
function Furniture.box(b: Builder, name: string, size: Vector3, at: CFrame, lk: Look, o: Opts?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	if o and o.shape then
		p.Shape = o.shape
	end
	p.Size = size * b.k
	p.CFrame = b.base * sized(b, at)
	p.Color = lk.color
	p.Material = lk.material
	p.Reflectance = lk.reflectance or 0
	p.Transparency = lk.transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o then
		if o.collide == false then
			p.CanCollide = false
		end
		if o.query == false then
			p.CanQuery = false
		end
		if o.shadow == false then
			p.CastShadow = false
		end
	end
	-- Glowing and see-through parts never block a guest or a camera.
	if lk.material == Enum.Material.Neon or (lk.transparency or 0) > 0.5 then
		p.CastShadow = false
	end
	p.Parent = b.model
	return p
end

-- A block from two corners (in the piece's frame, axis-aligned to it).
function Furniture.span(b: Builder, name: string, a: Vector3, c: Vector3, lk: Look, o: Opts?): Part
	local lo = Vector3.new(math.min(a.X, c.X), math.min(a.Y, c.Y), math.min(a.Z, c.Z))
	local hi = Vector3.new(math.max(a.X, c.X), math.max(a.Y, c.Y), math.max(a.Z, c.Z))
	return Furniture.box(b, name, hi - lo, CFrame.new((lo + hi) / 2), lk, o)
end

-- A cylinder along the X axis of `at`.
function Furniture.cyl(b: Builder, name: string, length: number, diameter: number, at: CFrame, lk: Look, o: Opts?): Part
	local opts: Opts = { shape = Enum.PartType.Cylinder }
	if o then
		opts.collide, opts.query, opts.shadow = o.collide, o.query, o.shadow
	end
	return Furniture.box(b, name, Vector3.new(length, diameter, diameter), at, lk, opts)
end

-- A cylinder standing upright, its foot at `foot`.
function Furniture.post(b: Builder, name: string, height: number, diameter: number, foot: Vector3, lk: Look, o: Opts?): Part
	return Furniture.cyl(b, name, height, diameter, CFrame.new(foot + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), lk, o)
end

-- A flat disc (a cylinder lying on its side, standing up as a short drum), its centre at `at`.
function Furniture.disc(b: Builder, name: string, diameter: number, thickness: number, at: Vector3, lk: Look, o: Opts?): Part
	return Furniture.cyl(b, name, thickness, diameter, CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), lk, o)
end

function Furniture.ball(b: Builder, name: string, diameter: number, at: Vector3, lk: Look, o: Opts?): Part
	local opts: Opts = { shape = Enum.PartType.Ball }
	if o then
		opts.collide, opts.query, opts.shadow = o.collide, o.query, o.shadow
	end
	return Furniture.box(b, name, Vector3.new(diameter, diameter, diameter), CFrame.new(at), lk, opts)
end

-- A wedge: its full face at the back (+Z), sloping down to the front edge.
function Furniture.wedge(b: Builder, name: string, size: Vector3, at: CFrame, lk: Look, o: Opts?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Anchored = true
	p.CanTouch = false
	p.Size = size * b.k
	p.CFrame = b.base * sized(b, at)
	p.Color = lk.color
	p.Material = lk.material
	p.Reflectance = lk.reflectance or 0
	p.Transparency = lk.transparency or 0
	if o and o.collide == false then
		p.CanCollide = false
	end
	if o and o.query == false then
		p.CanQuery = false
	end
	p.Parent = b.model
	return p
end

-- Decoration that nothing walks into or aims at: no collision, no queries, no shadow.
Furniture.trim = { collide = false, query = false, shadow = false } :: Opts
Furniture.soft = { collide = false, query = false } :: Opts

-- A warm lamp's light, if the piece is lit (pieces previewed in a panel are not).
function Furniture.light(b: Builder, part: BasePart, brightness: number, range: number, colour: Color3?, shadows: boolean?): PointLight?
	if not b.lit then
		return nil
	end
	local light = Instance.new("PointLight")
	light.Brightness = brightness
	light.Range = math.min(60, range * b.k)
	light.Color = colour or rgb(255, 204, 150)
	light.Shadows = shadows == true
	light.Parent = part
	b.lights += 1
	CollectionService:AddTag(light, "FurnitureLamp")
	return light
end

function Furniture.spotLight(b: Builder, part: BasePart, face: Enum.NormalId, brightness: number, range: number, angle: number, colour: Color3?): SpotLight?
	if not b.lit then
		return nil
	end
	local light = Instance.new("SpotLight")
	light.Face = face
	light.Brightness = brightness
	light.Range = math.min(60, range * b.k)
	light.Angle = angle
	light.Color = colour or rgb(255, 208, 160)
	light.Shadows = false
	light.Parent = part
	b.lights += 1
	CollectionService:AddTag(light, "FurnitureLamp")
	return light
end

-- A place to sit: the top of `at` is where a guest sits, facing `at`'s front (-Z).
function Furniture.sit(b: Builder, drawn: CFrame, width: number?, depth: number?)
	local at = sized(b, drawn)
	table.insert(b.seats, at)
	local p = Instance.new("Part")
	p.Name = "SitSpot"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new((width or 2) * b.k, 0.2, (depth or 2) * b.k)
	p.CFrame = b.base * at * CFrame.new(0, -0.1, 0)
	p:SetAttribute("SitIndex", #b.seats)
	p.Parent = b.model
end

-- A prompt on the piece (to sit, or to use it), on an invisible anchor at `at`.
function Furniture.prompt(b: Builder, name: string, at: Vector3, action: string, object: string, use: string?): ProximityPrompt
	local anchor = Instance.new("Part")
	anchor.Name = name .. "Anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.4, 0.4, 0.4)
	anchor.CFrame = b.base * CFrame.new(at * b.k)
	anchor.Parent = b.model
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	if use then
		p:SetAttribute("Use", use)
	end
	p.Parent = anchor
	return p
end

-- Makes seats of something the rooms already have (a bench, an armchair built from parts): a
-- model named `name` under `parent` holding a SitSpot at each of `seats` (in the world: the top
-- of the seat, facing the way a guest faces) and one Sit prompt, for the Seating code.
function Furniture.seatsOn(parent: Instance, name: string, seats: { CFrame }, object: string, width: number?): Model
	local model = Instance.new("Model")
	model.Name = name
	local b = Furniture.builder(model, CFrame.new(), false)
	local centre = Vector3.zero
	for _, at in seats do
		Furniture.sit(b, at, width, width)
		centre += at.Position
	end
	centre /= math.max(1, #seats)
	Furniture.prompt(b, "SeatPrompt", centre + Vector3.new(0, 1.2, 0), "Sit", object)
	model.Parent = parent
	return model
end

---------------------------------------------------------------------------------------------------
-- The pieces
---------------------------------------------------------------------------------------------------

export type Recipe = (b: Builder, st: Style) -> ()
export type Kind = { name: string, recipe: Recipe, sit: string? }

-- Every kind of piece, by name (filled in by the room modules below).
Furniture.kinds = {} :: { [string]: Kind }

function Furniture.define(kind: string, name: string, recipe: Recipe, sit: string?)
	Furniture.kinds[kind] = { name = name, recipe = recipe, sit = sit }
end

-- The rooms' pieces (each module adds its kinds).
for _, define in {
	require(script.Decor),
	require(script.Living),
	require(script.Bedroom),
	require(script.Spa),
	require(script.Kitchen),
	require(script.Leisure),
	require(script.Outdoor),
} :: { any } do
	define(Furniture)
end

-- Builds a piece of `kind` in `style` at `cf` (its frame) into a new model under `parent`.
-- `lit` = false leaves out its lights (a preview); `scale` builds it a size up. Returns the model
-- and its builder.
function Furniture.build(kind: string, parent: Instance?, cf: CFrame, st: Style?, lit: boolean?, scale: number?): (Model?, Builder?)
	local k = Furniture.kinds[kind]
	if not k then
		return nil, nil
	end
	local model = Instance.new("Model")
	model.Name = kind
	local b = Furniture.builder(model, cf, lit, scale)
	k.recipe(b, st or {})
	if #b.seats > 0 then
		local centre = Vector3.zero
		for _, s in b.seats do
			centre += s.Position
		end
		centre /= #b.seats
		Furniture.prompt(b, "SeatPrompt", centre / b.k + Vector3.new(0, 1.2, 0), "Sit", k.sit or k.name)
	end
	model:SetAttribute("Kind", kind)
	model.Parent = parent
	return model, b
end

-- The places to sit on a piece of `kind` in `style` (built at `scale`), in its own frame (cached
-- by kind, design and size).
local seatCache: { [string]: { CFrame } } = {}
function Furniture.seatsOf(kind: string, st: Style?, scale: number?): { CFrame }
	local key = kind .. "|" .. tostring(st and st.model or "") .. "|" .. tostring(scale or 1)
	local cached = seatCache[key]
	if cached then
		return cached
	end
	local model, b = Furniture.build(kind, nil, CFrame.new(), st, false, scale)
	local seats = if b then b.seats else {}
	if model then
		model:Destroy()
	end
	seatCache[key] = seats
	return seats
end

return Furniture

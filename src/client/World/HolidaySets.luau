--!strict
-- The holidays' set pieces, on every screen (World/HolidayFX builds and clears them): the great
-- things each holiday brings to the house, on the street front, in the Foyer and in the sky. They
-- are built on each screen alone, from the same numbers (Config.Holidays), so every guest sees the
-- same house; nothing here can be touched or stood on, and nothing changes a score. Every holiday
-- is gentle: All Hallows' is pumpkins, candles, a harvest moon and cartoon bats.
--
--   All Hallows'   giant jack-o'-lanterns at the steps and a row of them along the kerb, strings
--                  of orange and violet lights under the cornices, a great harvest moon with bats
--                  crossing it, a violet mist along the street; candles floating under the Foyer's
--                  ceiling and orange and violet lights wound up its columns
--   Thanksgiving   autumn trees in red and gold either side of the door, hay bales, corn and
--                  pumpkins at the steps, garlands of autumn leaves with warm lanterns under the
--                  cornices, the harvest moon; autumn leaves wound up the Foyer's columns, harvest
--                  at their feet
--   Christmas      a great tree on the pavement, lit and hung with baubles under a golden star,
--                  presents under it, candy canes at the steps, the street under snow, lights under
--                  the cornices, the northern lights and a sleigh crossing the sky now and then; a
--                  second tree in the Foyer and pine and lights wound up its columns
--   New Year       balloons in gold, silver and black at the steps, a glitter ball turning over the
--                  street throwing beams, searchlights sweeping the sky, bursts of gold up there,
--                  gold lights under the cornices; balloons in the Foyer, gold up its columns
--   Valentine's    two great hearts of light either side of the steps, rose and red lights under
--                  the cornices, heart lanterns rising from the street into the night; hearts
--                  floating under the Foyer's ceiling, roses up its columns
--   St Patrick's   the rainbow (down to the pot of gold while it's hidden), giant shamrocks at the
--                  steps, green and gold bunting under the cornices; clovers floating in the Foyer,
--                  green and gold up its columns
--   Easter         giant painted eggs on the pavement, blossom trees either side of the door, tulips
--                  along the front, pastel bunting, butterflies; balloons and eggs in the Foyer,
--                  blossom up its columns
-- What moves (lights twinkling, bats, lanterns, balloons, the glitter ball) moves on one clock per
-- holiday, and only a share of the lights changes on each beat. How many of everything there are
-- follows Quality (the graphics level, Glow and sparks, the frame rate): the full dressing on a
-- strong machine, a lighter one on a phone, and the extras (the lights wound up the Foyer's
-- columns, the street's mist) only where they're affordable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Quality = require(script.Parent.Parent.Quality)
local Sound = require(script.Parent.Parent.Sound)

local HolidaySets = {}

local rgb = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- (a cylinder's axis is its X: this stands it up)
local WHITE = Color3.new(1, 1, 1)

type Tick = (dt: number, t: number) -> ()
export type Set = {
	id: string,
	folder: Folder,
	ticks: { Tick },
	bulbs: { BasePart },
	palette: { Color3 },
	rng: Random,
}

local function cfg(): { [string]: any }
	return (Config.data :: any).Holidays
end

-- A point from the numbers in Config ({ x, y, z }).
local function at(t: any, fallback: Vector3): Vector3
	if type(t) == "table" and type(t[1]) == "number" then
		return Vector3.new(t[1], t[2] or 0, t[3] or 0)
	end
	return fallback
end

local function camera(): Camera?
	return Workspace.CurrentCamera
end

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

local function ball(parent: Instance, name: string, d: number, centre: Vector3, colour: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(d, d, d), CFrame.new(centre), colour, material, Enum.PartType.Ball)
end

-- An upright cylinder standing on `base`.
local function post(parent: Instance, name: string, height: number, d: number, base: Vector3, colour: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(height, d, d), CFrame.new(base + Vector3.new(0, height / 2, 0)) * UPRIGHT, colour, material, Enum.PartType.Cylinder)
end

-- A flat round (a cylinder lying with its axis up).
local function disc(parent: Instance, name: string, thickness: number, d: number, centre: Vector3, colour: Color3, material: Enum.Material?): Part
	return part(parent, name, Vector3.new(thickness, d, d), CFrame.new(centre) * UPRIGHT, colour, material, Enum.PartType.Cylinder)
end

-- A stretched sphere (an egg, a pumpkin's lobe, a flame).
local function ellipsoid(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = part(parent, name, size, cf, colour, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

local function round(f: GuiObject)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
end

-- A glyph floating in the world (a bat, a heart, a clover, a butterfly), `studs` across, with a
-- soft glow behind it if asked.
local function sprite(parent: Instance, name: string, glyph: string, studs: number, colour: Color3?, glow: Color3?): (Part, TextLabel)
	local p = part(parent, name, Vector3.new(0.2, 0.2, 0.2), CFrame.new(), WHITE)
	p.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sprite"
	bb.Size = UDim2.fromScale(studs, studs)
	bb.LightInfluence = 0
	bb.MaxDistance = 100000
	bb.Parent = p
	if glow then
		local g = Instance.new("Frame")
		g.Name = "Glow"
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		g.Position = UDim2.fromScale(0.5, 0.5)
		g.Size = UDim2.fromScale(1.3, 1.3)
		g.BackgroundColor3 = glow
		g.BackgroundTransparency = 0.78
		g.BorderSizePixel = 0
		g.Parent = bb
		round(g)
	end
	local t = Instance.new("TextLabel")
	t.Name = "Glyph"
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(0.5, 0.5)
	t.Position = UDim2.fromScale(0.5, 0.5)
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	t.Text = glyph
	if colour then
		t.TextColor3 = colour
	end
	t.Parent = bb
	return p, t
end

local function emitter(parent: Instance, texture: string, colour: ColorSequence, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = colour
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

---------------------------------------------------------------------------------------------------
-- Lights and garlands
---------------------------------------------------------------------------------------------------

-- A string of `n` lights hung between two points, sagging in the middle.
local function swag(set: Set, a: Vector3, b: Vector3, sag: number, n: number, colours: { Color3 }, d: number, skipFirst: boolean?, material: Enum.Material?)
	for i = if skipFirst then 1 else 0, n do
		local t = i / n
		local p = a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
		local bulb = ball(set.folder, "Bulb", d, p, colours[(i % #colours) + 1], material or Enum.Material.Neon)
		if (material or Enum.Material.Neon) == Enum.Material.Neon then
			table.insert(set.bulbs, bulb)
		end
	end
end

-- Strings of lights (or garlands) under the street front's three cornices, in spans across the
-- house. `dress`, if given, adds something at each span's ends (a lantern, a bow).
local function frontLines(set: Set, colours: { Color3 }, d: number, perSpan: number, material: Enum.Material?, dress: ((Vector3) -> ())?, nudge: number?)
	local c = cfg()
	local z = c.frontZ - (nudge or 0)
	local half = c.frontHalf
	local spans = 4
	local each = Quality.count(perSpan, 6)
	for _, h in c.swags do
		for s = 0, spans - 1 do
			local x0 = -half + 2 * half * s / spans
			local x1 = -half + 2 * half * (s + 1) / spans
			swag(set, Vector3.new(x0, h, z), Vector3.new(x1, h, z), 2.6, each, colours, d, s > 0, material)
			if dress then
				dress(Vector3.new(x0, h, z))
				if s == spans - 1 then
					dress(Vector3.new(x1, h, z))
				end
			end
		end
	end
end

-- Lights (or leaves, or flowers) wound up each of the Foyer's four columns, three turns and a half.
local function columnWraps(set: Set, colours: { Color3 }, d: number, material: Enum.Material?, accent: { Color3 }?)
	if not Quality.rich() then
		return
	end
	local c = cfg()
	local r = (c.columnRadius or 1.9) + d * 0.45
	local y0, y1 = c.columnFrom or 7, c.columnTo or 45
	local turns = 3.5
	local length = math.sqrt((2 * math.pi * r * turns) ^ 2 + (y1 - y0) ^ 2)
	local n = math.floor(length / (d * (if Quality.level() >= 0.85 then 0.85 else 1.1)))
	for k, col in c.columns do
		local base = at(col, Vector3.zero)
		for i = 0, n do
			local t = i / n
			local a = t * turns * math.pi * 2 + k * 1.3
			local p = Vector3.new(base.X + math.cos(a) * r, y0 + (y1 - y0) * t, base.Z + math.sin(a) * r)
			local mat = material or Enum.Material.Neon
			local colour = colours[(i % #colours) + 1]
			if accent and i % 4 == 2 then
				-- (A light among the leaves.)
				local b = ball(set.folder, "Bulb", d * 0.6, p + (p - Vector3.new(base.X, p.Y, base.Z)).Unit * d * 0.35, accent[(i // 4) % #accent + 1], Enum.Material.Neon)
				table.insert(set.bulbs, b)
			end
			local b = ball(set.folder, "Wrap", d, p, colour, mat)
			if mat == Enum.Material.Neon then
				table.insert(set.bulbs, b)
			end
		end
	end
end

-- Now and then, a share of the lights winks out and back (and the rest glow on).
local function twinkle(set: Set, every: number, share: number)
	local acc = 0
	table.insert(set.ticks, function(dt: number)
		acc += dt
		if acc < every then
			return
		end
		acc = 0
		local n = #set.bulbs
		if n == 0 then
			return
		end
		for _ = 1, math.max(1, math.floor(n * share)) do
			local b = set.bulbs[set.rng:NextInteger(1, n)]
			b.Transparency = if b.Transparency > 0.1 then 0 else 0.6
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The sky
---------------------------------------------------------------------------------------------------

-- The direction of the sky over the street (south, and high), a little turned by `turn` degrees.
local function skyward(elevation: number, turn: number): Vector3
	local e, a = math.rad(elevation), math.rad(turn)
	return Vector3.new(math.sin(a) * math.cos(e), math.sin(e), -math.cos(a) * math.cos(e))
end

-- A great moon, keeping its place in the sky wherever the guest walks, a soft halo round it.
local function moon(set: Set, colour: Color3, halo: Color3, dir: Vector3, studs: number): Part
	local p = part(set.folder, "Moon", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), WHITE)
	p.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.Name = "MoonFace"
	bb.Size = UDim2.fromScale(studs, studs)
	bb.LightInfluence = 0
	bb.MaxDistance = 100000
	bb.Parent = p
	for i, s in { 2.7, 1.95, 1.45 } do
		local f = Instance.new("Frame")
		f.Name = "Halo"
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(s, s)
		f.BackgroundColor3 = halo
		f.BackgroundTransparency = ({ 0.95, 0.9, 0.8 })[i]
		f.BorderSizePixel = 0
		f.Parent = bb
		round(f)
	end
	local face = Instance.new("Frame")
	face.Name = "Disc"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(1, 1)
	face.BackgroundColor3 = WHITE
	face.BorderSizePixel = 0
	face.Parent = bb
	round(face)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 135
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour:Lerp(WHITE, 0.45)),
		ColorSequenceKeypoint.new(0.55, colour),
		ColorSequenceKeypoint.new(1, colour:Lerp(Color3.new(0, 0, 0), 0.25)),
	})
	shade.Parent = face
	for _, c in { { 0.32, 0.36, 0.2 }, { 0.62, 0.3, 0.13 }, { 0.55, 0.64, 0.17 }, { 0.3, 0.68, 0.1 }, { 0.72, 0.52, 0.08 } } do
		local crater = Instance.new("Frame")
		crater.Name = "Crater"
		crater.AnchorPoint = Vector2.new(0.5, 0.5)
		crater.Position = UDim2.fromScale(c[1], c[2])
		crater.Size = UDim2.fromScale(c[3], c[3])
		crater.BackgroundColor3 = colour:Lerp(Color3.new(0, 0, 0), 0.35)
		crater.BackgroundTransparency = 0.72
		crater.BorderSizePixel = 0
		crater.Parent = face
		round(crater)
	end
	local unit = dir.Unit
	table.insert(set.ticks, function()
		local cam = camera()
		if cam then
			p.CFrame = CFrame.new(cam.CFrame.Position + unit * 900)
		end
	end)
	return p
end

-- Bats crossing the sky in front of the moon now and then, wings beating (cartoon bats).
local function bats(set: Set, dir: Vector3, count: number)
	local right = dir:Cross(Vector3.yAxis).Unit
	local up = right:Cross(dir).Unit
	type Bat = { part: Part, glyph: TextLabel, phase: number, lane: number, speed: number }
	local list: { Bat } = {}
	for i = 1, Quality.count(count, 3) do
		local p, g = sprite(set.folder, "Bat", "🦇", 22 + (i % 3) * 6)
		table.insert(list, { part = p, glyph = g, phase = set.rng:NextNumber(0, 1), lane = set.rng:NextNumber(-80, 120), speed = set.rng:NextNumber(0.05, 0.09) })
	end
	table.insert(set.ticks, function(_dt: number, t: number)
		local cam = camera()
		if not cam then
			return
		end
		local from = cam.CFrame.Position + dir.Unit * 760
		for _, b in list do
			local s = ((t * b.speed + b.phase) % 1) * 2 - 1 -- -1..1 across the sky
			b.part.CFrame = CFrame.new(from + right * (s * 420) + up * (b.lane + math.sin(t * 2 + b.phase * 9) * 24))
			local beat = 0.65 + 0.35 * math.abs(math.sin(t * 9 + b.phase * 20))
			b.glyph.Size = UDim2.fromScale(beat, 1)
		end
	end)
end

-- Ribbons of the northern lights across the sky to the north, rippling.
local function northernLights(set: Set, colours: { Color3 })
	local holder = part(set.folder, "Aurora", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), WHITE)
	holder.Transparency = 1
	type Curtain = { a0: Attachment, a1: Attachment, base: Vector3, span: Vector3, phase: number }
	local curtains: { Curtain } = {}
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 1.2 - 0.6 -- spread across the northern sky
		local base = Vector3.new(math.sin(a) * 300, 150 + (i % 3) * 22, math.cos(a) * 300)
		local a0 = Instance.new("Attachment")
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.Parent = holder
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 60
		beam.Width1 = 60
		beam.FaceCamera = false
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 20
		beam.CurveSize0 = 30
		beam.CurveSize1 = -30
		beam.Color = ColorSequence.new(colours[(i - 1) % #colours + 1], colours[i % #colours + 1])
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.45), NumberSequenceKeypoint.new(0.75, 0.45), NumberSequenceKeypoint.new(1, 1) })
		beam.Parent = holder
		table.insert(curtains, { a0 = a0, a1 = a1, base = base, span = Vector3.new(math.cos(a) * 110, 0, -math.sin(a) * 110), phase = i })
	end
	table.insert(set.ticks, function(_dt: number, t: number)
		local cam = camera()
		if not cam then
			return
		end
		local here = cam.CFrame.Position
		for _, c in curtains do
			local wave = Vector3.new(math.sin(t * 0.4 + c.phase) * 14, math.sin(t * 0.7 + c.phase * 2) * 8, math.cos(t * 0.3 + c.phase) * 14)
			c.a0.WorldPosition = here + c.base + wave
			c.a1.WorldPosition = here + c.base + c.span - wave * 0.5
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The pieces
---------------------------------------------------------------------------------------------------

-- A pumpkin: a round of lobes, a stem, and (a jack-o'-lantern) a friendly carved face glowing from
-- inside, facing `facing`.
local PUMPKIN = { rgb(232, 118, 30), rgb(212, 96, 22) }
local function pumpkin(set: Set, base: Vector3, d: number, facing: Vector3, lit: boolean, light: boolean?, colours: { Color3 }?)
	local hue = colours or PUMPKIN
	local h = d * 0.78
	local centre = base + Vector3.new(0, h / 2, 0)
	local look = Vector3.new(facing.X, 0, facing.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local frame = CFrame.lookAt(centre, centre + look)
	ellipsoid(set.folder, "Pumpkin", Vector3.new(d * 0.9, h, d * 0.9), frame, hue[1])
	for k = 0, 5 do
		local a = math.rad(30 + k * 60)
		ellipsoid(set.folder, "Lobe", Vector3.new(d * 0.5, h * 0.98, d * 0.56), frame * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -d * 0.24), hue[(k % 2) + 1])
	end
	part(set.folder, "Stem", Vector3.new(d * 0.24, d * 0.12, d * 0.12), CFrame.new(centre + Vector3.new(0, h * 0.5 + d * 0.08, 0)) * UPRIGHT * CFrame.Angles(0.15, 0, 0), rgb(86, 96, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
	if lit then
		local glow = rgb(255, 196, 80)
		local face = frame * CFrame.new(0, 0, -d * 0.47)
		for _, sx in { -1, 1 } do
			part(set.folder, "Eye", Vector3.new(d * 0.14, d * 0.14, d * 0.06), face * CFrame.new(sx * d * 0.16, h * 0.14, 0) * CFrame.Angles(0, 0, math.rad(45)), glow, Enum.Material.Neon)
		end
		part(set.folder, "Nose", Vector3.new(d * 0.08, d * 0.08, d * 0.06), face * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), glow, Enum.Material.Neon)
		for k = -2, 2 do
			local a = math.rad(270 + k * 22)
			local r = d * 0.24
			part(set.folder, "Smile", Vector3.new(d * 0.11, d * 0.055, d * 0.06), face * CFrame.new(math.cos(a) * r, h * 0.02 + math.sin(a) * r * 0.75, 0) * CFrame.Angles(0, 0, a - math.rad(270)), glow, Enum.Material.Neon)
		end
		if light then
			local core = part(set.folder, "PumpkinLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(centre), glow)
			core.Transparency = 1
			local l = Instance.new("PointLight")
			l.Color = rgb(255, 150, 60)
			l.Brightness = 1.4
			l.Range = d * 2.6
			l.Shadows = false
			l.Parent = core
			local phase = set.rng:NextNumber(0, 10)
			table.insert(set.ticks, function(_dt: number, t: number)
				l.Brightness = 1.2 + 0.35 * math.sin(t * 7 + phase) * math.sin(t * 3.1 + phase)
			end)
		end
	end
end

-- A candle floating in the air (All Hallows' in the Foyer): it bobs, and its flame flickers.
local function floatingCandles(set: Set, count: number)
	local c = cfg()
	local lo, hi = at(c.candlesFrom, Vector3.new(-40, 28, -6)), at(c.candlesTo, Vector3.new(40, 40, 62))
	type Candle = { wax: Part, flame: Part, base: Vector3, phase: number }
	local list: { Candle } = {}
	for i = 1, Quality.count(count, 8) do
		local p = Vector3.new(set.rng:NextNumber(lo.X, hi.X), set.rng:NextNumber(lo.Y, hi.Y), set.rng:NextNumber(lo.Z, hi.Z))
		local h = set.rng:NextNumber(1.4, 2.4)
		local wax = part(set.folder, "Candle", Vector3.new(h, 0.55, 0.55), CFrame.new(p) * UPRIGHT, rgb(246, 238, 220), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		local flame = ellipsoid(set.folder, "Flame", Vector3.new(0.3, 0.6, 0.3), CFrame.new(p + Vector3.new(0, h / 2 + 0.3, 0)), rgb(255, 196, 90), Enum.Material.Neon)
		table.insert(list, { wax = wax, flame = flame, base = p, phase = set.rng:NextNumber(0, 10) })
		if i % 7 == 1 then
			local l = Instance.new("PointLight")
			l.Color = rgb(255, 170, 80)
			l.Brightness = 0.9
			l.Range = 18
			l.Shadows = false
			l.Parent = flame
		end
	end
	table.insert(set.ticks, function(_dt: number, t: number)
		for _, k in list do
			local p = k.base + Vector3.new(0, math.sin(t * 0.8 + k.phase) * 0.4, 0)
			k.wax.CFrame = CFrame.new(p) * UPRIGHT
			k.flame.CFrame = CFrame.new(p + Vector3.new(math.sin(t * 9 + k.phase) * 0.03, k.wax.Size.X / 2 + 0.3, 0))
			k.flame.Transparency = 0.1 * math.abs(math.sin(t * 11 + k.phase))
		end
	end)
end

-- A tree in leaf: a trunk with two boughs and a crown of round leafy masses (autumn's reds and
-- golds, or spring's blossom).
local function leafyTree(set: Set, base: Vector3, height: number, colours: { Color3 }, bark: Color3)
	local trunkH = height * 0.5
	post(set.folder, "Trunk", trunkH, height * 0.075, base, bark, Enum.Material.Wood).CastShadow = true
	for _, side in { -1, 1 } do
		local from = base + Vector3.new(0, trunkH * 0.7, 0)
		local to = from + Vector3.new(side * height * 0.16, height * 0.16, side * height * 0.05)
		part(set.folder, "Bough", Vector3.new((to - from).Magnitude, height * 0.04, height * 0.04), CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.pi / 2, 0), bark, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	local crown = base + Vector3.new(0, height * 0.7, 0)
	for i = 1, 11 do
		local a = i / 11 * math.pi * 2 + set.rng:NextNumber(-0.3, 0.3)
		local r = if i == 11 then 0 else set.rng:NextNumber(0.12, 0.26) * height
		local y = if i == 11 then height * 0.12 else set.rng:NextNumber(-0.08, 0.1) * height
		local d = set.rng:NextNumber(0.26, 0.36) * height
		local leaf = ball(set.folder, "Leaves", d, crown + Vector3.new(math.cos(a) * r, y, math.sin(a) * r), colours[(i % #colours) + 1], Enum.Material.Grass)
		leaf.CastShadow = true
	end
end

-- A fir tree: tiers of boughs (each a cone of wedges), a trunk, a winding string of lights,
-- baubles at the tiers' rims, presents underneath and a golden star on top.
local function firTree(set: Set, base: Vector3, height: number, lights: { Color3 }, baubles: { Color3 }, presents: boolean)
	local pines = { rgb(26, 84, 50), rgb(20, 70, 42), rgb(30, 94, 56) }
	post(set.folder, "Trunk", height * 0.14, height * 0.07, base, rgb(78, 52, 34), Enum.Material.Wood)
	local tiers = 7
	local R = height * 0.33
	local rims: { { y: number, r: number } } = {}
	for i = 0, tiers - 1 do
		local r = R * (1 - i * 0.135)
		local y = base.Y + height * (0.1 + i * 0.118)
		local h = math.max(r * 1.3, height * 0.1)
		local slices = if r > 6 then 14 else 10
		local w = 2 * r * math.tan(math.pi / slices) * 1.12
		for k = 0, slices - 1 do
			local a = k / slices * math.pi * 2 + i * 0.4
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local centre = Vector3.new(base.X, y + h / 2, base.Z) + out * (r / 2)
			local wedge = Instance.new("WedgePart")
			wedge.Name = "Boughs"
			wedge.Anchored = true
			wedge.CanCollide = false
			wedge.CanQuery = false
			wedge.CanTouch = false
			wedge.CastShadow = true
			wedge.Size = Vector3.new(w, h, r)
			-- (A wedge is high at its back: turned with its back to the trunk, it slopes down and out.)
			wedge.CFrame = CFrame.lookAt(centre, centre + out)
			wedge.Color = pines[(k + i) % #pines + 1]
			wedge.Material = Enum.Material.Grass
			wedge.Parent = set.folder
		end
		table.insert(rims, { y = y + 0.4, r = r * 0.92 })
	end
	-- The star, just over the top tier's point.
	local starAt = Vector3.new(base.X, base.Y + height * 0.95, base.Z)
	-- Baubles at the rims.
	for i, rim in rims do
		local count = Quality.count(math.max(5, rim.r * 1.6), 4)
		for k = 1, count do
			local a = k / count * math.pi * 2 + i
			local colour = baubles[(k + i) % #baubles + 1]
			local b = ball(set.folder, "Bauble", math.clamp(height * 0.03, 0.6, 1.6), Vector3.new(base.X + math.cos(a) * rim.r, rim.y - 0.3, base.Z + math.sin(a) * rim.r), colour, Enum.Material.Glass)
			b.Reflectance = 0.25
		end
	end
	-- A string of lights winding up from the lowest tier to the top.
	local turns = 5
	local n = Quality.count(height * 2.2, 20)
	for i = 0, n do
		local t = i / n
		local y = base.Y + height * (0.12 + t * 0.78)
		local f = math.clamp((y - base.Y - height * 0.1) / (height * 0.82), 0, 1)
		local r = R * (1 - f * 0.9) * 0.95 + 0.3
		local a = t * turns * math.pi * 2
		local bulb = ball(set.folder, "Bulb", math.clamp(height * 0.018, 0.4, 0.9), Vector3.new(base.X + math.cos(a) * r, y, base.Z + math.sin(a) * r), lights[(i % #lights) + 1], Enum.Material.Neon)
		table.insert(set.bulbs, bulb)
	end
	-- The star.
	local star, glyph = sprite(set.folder, "TreeStar", "★", height * 0.16, rgb(255, 214, 110), rgb(255, 230, 150))
	star.CFrame = CFrame.new(starAt)
	glyph.TextStrokeTransparency = 0.4
	glyph.TextStrokeColor3 = rgb(255, 244, 200)
	local glowAt = part(set.folder, "StarLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(starAt), WHITE)
	glowAt.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color = rgb(255, 220, 140)
	l.Brightness = 2
	l.Range = math.min(40, height * 0.8)
	l.Shadows = false
	l.Parent = glowAt
	emitter(glowAt, SPARK, ColorSequence.new(rgb(255, 250, 220), rgb(255, 210, 110)), {
		Rate = 6,
		Lifetime = NumberRange.new(0.8, 1.4),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, height * 0.025), NumberSequenceKeypoint.new(1, 0) }),
		LightEmission = 1,
	})
	-- Presents underneath.
	if presents then
		local wraps = { rgb(170, 24, 40), rgb(232, 190, 90), rgb(30, 110, 70), rgb(240, 236, 228), rgb(50, 80, 170) }
		local ribbons = { rgb(240, 214, 120), rgb(170, 24, 40), rgb(240, 236, 228) }
		local count = Quality.count(if height > 30 then 12 else 7, 4)
		for k = 1, count do
			local a = k / count * math.pi * 2 + 0.3
			local s = set.rng:NextNumber(0.07, 0.11) * height * 0.5
			local size = Vector3.new(s * set.rng:NextNumber(1, 1.5), s, s * set.rng:NextNumber(1, 1.4))
			local r = R * set.rng:NextNumber(0.55, 0.85)
			local cf = CFrame.new(base.X + math.cos(a) * r, base.Y + size.Y / 2, base.Z + math.sin(a) * r) * CFrame.Angles(0, set.rng:NextNumber(0, math.pi), 0)
			local wrap = wraps[(k % #wraps) + 1]
			local ribbon = ribbons[(k % #ribbons) + 1]
			if ribbon == wrap then
				ribbon = rgb(240, 214, 120)
			end
			local box = part(set.folder, "Present", size, cf, wrap, Enum.Material.SmoothPlastic)
			box.CastShadow = true
			part(set.folder, "Ribbon", Vector3.new(size.X + 0.04, size.Y + 0.04, size.Z * 0.16), cf, ribbon, Enum.Material.Fabric)
			part(set.folder, "Ribbon", Vector3.new(size.X * 0.16, size.Y + 0.04, size.Z + 0.04), cf, ribbon, Enum.Material.Fabric)
			ball(set.folder, "Bow", size.Y * 0.35, (cf * CFrame.new(0, size.Y / 2 + 0.05, 0)).Position, ribbon, Enum.Material.Fabric)
		end
	end
end

-- A candy cane, red and white, `height` tall, its crook turned toward `facing`.
local function candyCane(set: Set, base: Vector3, height: number, facing: Vector3)
	local d = height * 0.09
	local segs = 8
	local stem = height * 0.78
	for i = 0, segs - 1 do
		local y = base.Y + (i + 0.5) * stem / segs
		part(set.folder, "Cane", Vector3.new(stem / segs + 0.02, d, d), CFrame.new(base.X, y, base.Z) * UPRIGHT, if i % 2 == 0 then rgb(220, 30, 44) else WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	-- The crook: a half-circle over the top.
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
		part(set.folder, "Cane", Vector3.new((p1 - p0).Magnitude + d * 0.4, d, d), CFrame.lookAt((p0 + p1) / 2, p1) * CFrame.Angles(0, math.pi / 2, 0), if i % 2 == 0 then WHITE else rgb(220, 30, 44), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
end

-- A bunch of balloons tied to a weight, bobbing on their strings.
local function balloons(set: Set, base: Vector3, count: number, colours: { Color3 }, height: number)
	type Balloon = { ball: Part, string: Part, top: Vector3, phase: number }
	local list: { Balloon } = {}
	local anchorAt = base + Vector3.new(0, 0.4, 0)
	part(set.folder, "Weight", Vector3.new(0.8, 0.8, 0.8), CFrame.new(anchorAt), rgb(40, 40, 44), Enum.Material.Metal)
	for i = 1, Quality.count(count, 4) do
		local a = i / count * math.pi * 2
		local top = base + Vector3.new(math.cos(a) * set.rng:NextNumber(0.8, 2.2), height + set.rng:NextNumber(-1.5, 1.5), math.sin(a) * set.rng:NextNumber(0.8, 2.2))
		local d = set.rng:NextNumber(2, 2.6)
		local b = ellipsoid(set.folder, "Balloon", Vector3.new(d, d * 1.18, d), CFrame.new(top), colours[(i % #colours) + 1], Enum.Material.SmoothPlastic)
		b.Reflectance = 0.18
		local s = part(set.folder, "String", Vector3.new(0.05, 1, 0.05), CFrame.new(), rgb(230, 230, 230), Enum.Material.SmoothPlastic)
		table.insert(list, { ball = b, string = s, top = top, phase = set.rng:NextNumber(0, 10) })
	end
	table.insert(set.ticks, function(_dt: number, t: number)
		for _, b in list do
			local p = b.top + Vector3.new(math.sin(t * 0.7 + b.phase) * 0.35, math.sin(t * 1.1 + b.phase) * 0.3, math.cos(t * 0.6 + b.phase) * 0.35)
			b.ball.CFrame = CFrame.new(p) * CFrame.Angles(math.sin(t + b.phase) * 0.08, 0, math.cos(t * 0.8 + b.phase) * 0.08)
			local lowest = p - Vector3.new(0, b.ball.Size.Y / 2, 0)
			local span = lowest - anchorAt
			b.string.Size = Vector3.new(0.05, span.Magnitude, 0.05)
			b.string.CFrame = CFrame.lookAt((lowest + anchorAt) / 2, lowest) * CFrame.Angles(math.pi / 2, 0, 0)
		end
	end)
end

-- A heart of lights standing upright, facing `facing`, `height` tall, on two slim posts.
local function heartOfLights(set: Set, base: Vector3, height: number, facing: Vector3, colours: { Color3 })
	local look = Vector3.new(facing.X, 0, facing.Z).Unit
	local right = look:Cross(Vector3.yAxis).Unit
	local centre = base + Vector3.new(0, height * 0.62, 0)
	local n = 46
	local scale = height / 34 -- (the curve below is about 34 units tall)
	local lowest = math.huge
	local points: { Vector3 } = {}
	for i = 0, n - 1 do
		local t = i / n * math.pi * 2
		local x = 16 * math.sin(t) ^ 3
		local y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
		local p = centre + right * x * scale + Vector3.new(0, y * scale, 0)
		table.insert(points, p)
		lowest = math.min(lowest, p.Y)
	end
	for i, p in points do
		local b = ball(set.folder, "Bulb", 0.85, p, colours[(i % #colours) + 1], Enum.Material.Neon)
		table.insert(set.bulbs, b)
	end
	-- (Standing on its point: a slim post under it to the ground.)
	local tip = Vector3.new(centre.X, lowest, centre.Z)
	post(set.folder, "HeartPost", math.max(0.5, lowest - base.Y), 0.35, base, rgb(200, 170, 110), Enum.Material.Metal)
	local core = part(set.folder, "HeartGlow", Vector3.new(0.2, 0.2, 0.2), CFrame.new(centre), WHITE)
	core.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color = colours[1]
	l.Brightness = 1.6
	l.Range = height * 1.2
	l.Shadows = false
	l.Parent = core
	ball(set.folder, "HeartTip", 0.9, tip, colours[2] or colours[1], Enum.Material.Neon)
end

-- A shamrock, `height` tall, on its stem: three round leaves of two lobes each.
local function shamrock(set: Set, base: Vector3, height: number, facing: Vector3)
	local look = Vector3.new(facing.X, 0, facing.Z).Unit
	local right = look:Cross(Vector3.yAxis).Unit
	local greens = { rgb(40, 170, 80), rgb(60, 200, 100) }
	local centre = base + Vector3.new(0, height * 0.62, 0)
	post(set.folder, "Stem", height * 0.62, height * 0.06, base, rgb(40, 130, 60), Enum.Material.SmoothPlastic)
	for k = 0, 2 do
		local a = math.rad(90 + k * 120)
		local dir = right * math.cos(a) + Vector3.yAxis * math.sin(a)
		local leafCentre = centre + dir * height * 0.2
		local side = right * -math.sin(a) + Vector3.yAxis * math.cos(a)
		for _, s in { -1, 1 } do
			local lobe = ball(set.folder, "Leaf", height * 0.26, leafCentre + side * s * height * 0.08 + dir * height * 0.03, greens[(k % 2) + 1], Enum.Material.SmoothPlastic)
			lobe.CastShadow = true
		end
	end
	local glow = part(set.folder, "ShamrockGlow", Vector3.new(0.2, 0.2, 0.2), CFrame.new(centre - look * height * 0.2), WHITE)
	glow.Transparency = 1
	local l = Instance.new("PointLight")
	l.Color = rgb(120, 255, 150)
	l.Brightness = 1.2
	l.Range = height * 1.3
	l.Shadows = false
	l.Parent = glow
end

-- A giant painted egg: pastel, with a band of dots round its middle and stripes above and below.
local function paintedEgg(set: Set, base: Vector3, height: number, body: Color3, trim: Color3, spin: number)
	local w = height * 0.74
	local centre = base + Vector3.new(0, height / 2, 0)
	local cf = CFrame.new(centre) * CFrame.Angles(0, spin, 0)
	local egg = ellipsoid(set.folder, "Egg", Vector3.new(w, height, w), cf, body, Enum.Material.SmoothPlastic)
	egg.CastShadow = true
	-- Stripes: thin bands round the egg at three heights (each a flattened ring of the egg's own shape).
	for _, f in { -0.22, 0.24 } do
		local y = f * height
		local rr = w * math.sqrt(math.max(0, 1 - (2 * y / height) ^ 2))
		ellipsoid(set.folder, "Stripe", Vector3.new(rr + 0.12, height * 0.06, rr + 0.12), cf * CFrame.new(0, y, 0), trim, Enum.Material.SmoothPlastic)
	end
	local dots = 12
	for k = 1, dots do
		local a = k / dots * math.pi * 2
		local p = (cf * CFrame.new(math.cos(a) * w * 0.5, 0, math.sin(a) * w * 0.5)).Position
		ball(set.folder, "Dot", height * 0.08, p, if k % 2 == 0 then trim else WHITE, Enum.Material.SmoothPlastic)
	end
end

-- A row of tulips along the front of the house.
local function tulips(set: Set, from: Vector3, to: Vector3, count: number, colours: { Color3 })
	local n = Quality.count(count, 6)
	for i = 0, n - 1 do
		local p = from:Lerp(to, (i + 0.5) / n) + Vector3.new(0, 0, set.rng:NextNumber(-0.4, 0.4))
		local h = set.rng:NextNumber(1.6, 2.4)
		post(set.folder, "TulipStem", h, 0.16, p, rgb(70, 150, 70))
		ellipsoid(set.folder, "Tulip", Vector3.new(0.7, 0.95, 0.7), CFrame.new(p + Vector3.new(0, h + 0.3, 0)), colours[(i % #colours) + 1], Enum.Material.SmoothPlastic)
		part(set.folder, "TulipLeaf", Vector3.new(0.1, h * 0.55, 0.45), CFrame.new(p + Vector3.new(0.15, h * 0.3, 0)) * CFrame.Angles(0, 0, -0.35), rgb(80, 160, 80))
	end
end

-- A diamond pennant (bunting).
local function pennants(set: Set, colours: { Color3 })
	local c = cfg()
	local z = c.frontZ
	local half = c.frontHalf
	local spans = 4
	for _, h in c.swags do
		for s = 0, spans - 1 do
			local x0 = -half + 2 * half * s / spans
			local x1 = -half + 2 * half * (s + 1) / spans
			local n = 9
			for i = 0, n do
				local t = i / n
				local p = Vector3.new(x0 + (x1 - x0) * t, h - 2.6 * 4 * t * (1 - t), z)
				if i > 0 or s == 0 then
					ball(set.folder, "Knot", 0.3, p, rgb(240, 236, 228), Enum.Material.SmoothPlastic)
				end
				if i < n then
					local tt = t + 0.5 / n
					local y = h - 2.6 * 4 * tt * (1 - tt)
					part(set.folder, "Pennant", Vector3.new(1.6, 1.6, 0.08), CFrame.new(x0 + (x1 - x0) * tt, y - 1.25, z) * CFrame.Angles(0, 0, math.rad(45)), colours[(i + s) % #colours + 1], Enum.Material.Fabric)
				end
			end
		end
	end
end

-- Things drifting slowly in the air of the Foyer (hearts, clovers): each bobs and sways.
local function floaters(set: Set, glyph: string, count: number, colours: { Color3 }, studs: number)
	local c = cfg()
	local lo, hi = at(c.candlesFrom, Vector3.new(-40, 28, -6)), at(c.candlesTo, Vector3.new(40, 40, 62))
	type Floater = { part: Part, base: Vector3, phase: number }
	local list: { Floater } = {}
	for i = 1, Quality.count(count, 8) do
		local colour = colours[(i % #colours) + 1]
		local p = sprite(set.folder, "Floater", glyph, studs * set.rng:NextNumber(0.8, 1.3), colour, colour:Lerp(WHITE, 0.4))
		table.insert(list, { part = p, base = Vector3.new(set.rng:NextNumber(lo.X, hi.X), set.rng:NextNumber(lo.Y - 8, hi.Y - 4), set.rng:NextNumber(lo.Z, hi.Z)), phase = set.rng:NextNumber(0, 10) })
	end
	table.insert(set.ticks, function(_dt: number, t: number)
		for _, f in list do
			f.part.CFrame = CFrame.new(f.base + Vector3.new(math.sin(t * 0.3 + f.phase) * 2, math.sin(t * 0.6 + f.phase) * 1.2, math.cos(t * 0.25 + f.phase) * 2))
		end
	end)
end

-- Lanterns rising slowly from the street into the night (Valentine's: glowing hearts), each
-- swaying as it goes, then rising again from the street.
local function risingLanterns(set: Set, glyph: string, count: number, colours: { Color3 }, studs: number)
	local c = cfg()
	local lo, hi = at(c.lanternsFrom, Vector3.new(-70, 2, -100)), at(c.lanternsTo, Vector3.new(70, 2, -20))
	type Lantern = { part: Part, x: number, z: number, speed: number, phase: number, start: number }
	local list: { Lantern } = {}
	for i = 1, Quality.count(count, 12) do
		local colour = colours[(i % #colours) + 1]
		local p = sprite(set.folder, "Lantern", glyph, studs * set.rng:NextNumber(0.7, 1.2), colour, colour:Lerp(WHITE, 0.3))
		table.insert(list, { part = p, x = set.rng:NextNumber(lo.X, hi.X), z = set.rng:NextNumber(lo.Z, hi.Z), speed = set.rng:NextNumber(2.2, 4), phase = set.rng:NextNumber(0, 10), start = set.rng:NextNumber(0, 1) })
	end
	local top = 220
	table.insert(set.ticks, function(_dt: number, t: number)
		for _, l in list do
			local life = top / l.speed
			local s = ((t / life) + l.start) % 1
			local y = lo.Y + s * top
			l.part.CFrame = CFrame.new(l.x + math.sin(t * 0.5 + l.phase) * 3 * s, y, l.z + math.cos(t * 0.4 + l.phase) * 3 * s)
		end
	end)
end

-- Butterflies fluttering about the street front, wings beating.
local function butterflies(set: Set, count: number)
	type Fly = { part: Part, glyph: TextLabel, centre: Vector3, phase: number, r: number }
	local list: { Fly } = {}
	for _ = 1, Quality.count(count, 5) do
		local p, g = sprite(set.folder, "Butterfly", "🦋", set.rng:NextNumber(1.6, 2.6))
		local centre = Vector3.new(set.rng:NextNumber(-34, 34), set.rng:NextNumber(4, 12), set.rng:NextNumber(-48, -22))
		table.insert(list, { part = p, glyph = g, centre = centre, phase = set.rng:NextNumber(0, 10), r = set.rng:NextNumber(2, 6) })
	end
	table.insert(set.ticks, function(_dt: number, t: number)
		for _, f in list do
			local a = t * 0.6 + f.phase
			f.part.CFrame = CFrame.new(f.centre + Vector3.new(math.cos(a) * f.r, math.sin(t * 1.7 + f.phase) * 1.2, math.sin(a * 1.3) * f.r))
			f.glyph.Size = UDim2.fromScale(0.35 + 0.65 * math.abs(math.sin(t * 14 + f.phase)), 1)
		end
	end)
end

-- A glitter ball turning high over the street, mirror tiles catching the light, beams of light
-- thrown from it sweeping the pavement.
local function glitterBall(set: Set, centre: Vector3, d: number)
	type Tile = { part: Part, offset: CFrame }
	local tiles: { Tile } = {}
	local core = ball(set.folder, "GlitterBall", d * 0.96, centre, rgb(150, 150, 160), Enum.Material.Metal)
	core.Reflectance = 0.4
	local rows = 7
	for r = 1, rows - 1 do
		local lat = (r / rows - 0.5) * math.pi
		local ring = math.max(4, math.floor(14 * math.cos(lat)))
		for k = 0, ring - 1 do
			local lon = k / ring * math.pi * 2
			local offset = CFrame.Angles(0, lon, 0) * CFrame.Angles(lat, 0, 0) * CFrame.new(0, 0, -d / 2)
			local tile = part(set.folder, "Mirror", Vector3.new(d * 0.17, d * 0.17, 0.08), CFrame.new(centre) * offset, rgb(235, 238, 245), Enum.Material.Glass)
			tile.Reflectance = 0.6
			table.insert(tiles, { part = tile, offset = offset })
		end
	end
	local glints = part(set.folder, "Glints", Vector3.new(d, d, d), CFrame.new(centre), WHITE)
	glints.Transparency = 1
	emitter(glints, SPARK, ColorSequence.new(WHITE, rgb(255, 230, 160)), {
		Rate = 14,
		Lifetime = NumberRange.new(0.25, 0.5),
		Speed = NumberRange.new(0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.6), NumberSequenceKeypoint.new(1, 0) }),
		LightEmission = 1,
		RotSpeed = NumberRange.new(-90, 90),
	})
	-- Beams thrown down onto the pavement, turning with the ball.
	local from = Instance.new("Attachment")
	from.Parent = core
	type Ray = { hit: Part, phase: number }
	local rays: { Ray } = {}
	for i = 1, 6 do
		local hit = part(set.folder, "BeamSpot", Vector3.new(0.2, 0.2, 0.2), CFrame.new(centre - Vector3.new(0, centre.Y, 0)), WHITE)
		hit.Transparency = 1
		local to = Instance.new("Attachment")
		to.Parent = hit
		local beam = Instance.new("Beam")
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.Width0 = 0.4
		beam.Width1 = 5
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(if i % 2 == 0 then rgb(255, 220, 140) else rgb(225, 230, 255))
		beam.Transparency = NumberSequence.new(0.55, 0.9)
		beam.Parent = core
		table.insert(rays, { hit = hit, phase = i / 6 * math.pi * 2 })
	end
	table.insert(set.ticks, function(_dt: number, t: number)
		local spin = CFrame.new(centre) * CFrame.Angles(0, t * 0.5, 0)
		for _, tile in tiles do
			tile.part.CFrame = spin * tile.offset
		end
		for _, r in rays do
			local a = r.phase + t * 0.5
			r.hit.CFrame = CFrame.new(centre.X + math.cos(a) * 26, 0.2, centre.Z + math.sin(a) * 18)
		end
	end)
end

-- Searchlights on the street sweeping the night sky.
local function searchlights(set: Set, colour: Color3)
	type Light = { sky: Part, base: Vector3, phase: number }
	local list: { Light } = {}
	for i, x in { -90, -46, 46, 90 } do
		local base = Vector3.new(x, 0.4, -86)
		local foot = part(set.folder, "Searchlight", Vector3.new(2.4, 1.6, 2.4), CFrame.new(base + Vector3.new(0, 0.4, 0)), rgb(40, 40, 46), Enum.Material.Metal)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.9, 0)
		a0.Parent = foot
		local sky = part(set.folder, "SearchlightSky", Vector3.new(0.2, 0.2, 0.2), CFrame.new(base + Vector3.new(0, 400, 0)), WHITE)
		sky.Transparency = 1
		local a1 = Instance.new("Attachment")
		a1.Parent = sky
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 2.6
		beam.Width1 = 34
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Color = ColorSequence.new(colour:Lerp(WHITE, 0.5), colour)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
		beam.Parent = foot
		table.insert(list, { sky = sky, base = base, phase = i * 1.7 })
	end
	table.insert(set.ticks, function(_dt: number, t: number)
		for _, l in list do
			local a = math.sin(t * 0.35 + l.phase) * 0.6
			local b = math.cos(t * 0.27 + l.phase) * 0.35
			l.sky.CFrame = CFrame.new(l.base + Vector3.new(math.sin(a) * 260, 400, -math.cos(a) * 60 + b * 160))
		end
	end)
end

-- Bursts of gold and silver high in the night sky now and then.
local function skyBursts(set: Set, colours: { Color3 }, every: number)
	local wait = 2
	table.insert(set.ticks, function(dt: number)
		wait -= dt
		if wait > 0 then
			return
		end
		wait = every * set.rng:NextNumber(0.7, 1.3)
		local where = Vector3.new(set.rng:NextNumber(-150, 150), set.rng:NextNumber(150, 230), set.rng:NextNumber(-320, -160))
		local p = part(set.folder, "SkyBurst", Vector3.new(0.2, 0.2, 0.2), CFrame.new(where), WHITE)
		p.Transparency = 1
		local c = colours[set.rng:NextInteger(1, #colours)]
		local e = emitter(p, SPARK, ColorSequence.new(c:Lerp(WHITE, 0.5), c), {
			Rate = 0,
			Lifetime = NumberRange.new(1.6, 2.6),
			Speed = NumberRange.new(40, 70),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1.6,
			Acceleration = Vector3.new(0, -10, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 0) }),
			LightEmission = 1,
		})
		e:Emit(Quality.count(140, 50))
		pcall(Sound.play, "fireworkGlitter", 0.25, 0.9 + set.rng:NextNumber() * 0.2)
		task.delay(3, function()
			p:Destroy()
		end)
	end)
end

-- A sleigh and its reindeer crossing the sky now and then, with a trail of gold sparkles.
local function sleigh(set: Set, every: number)
	local team: { Part } = {}
	local sled = sprite(set.folder, "Sleigh", "🛷", 34)
	table.insert(team, sled)
	for _ = 1, 3 do
		local deer = sprite(set.folder, "Reindeer", "🦌", 26)
		table.insert(team, deer)
	end
	local trailAt = part(set.folder, "SleighTrail", Vector3.new(0.2, 0.2, 0.2), CFrame.new(), WHITE)
	trailAt.Transparency = 1
	local trail = emitter(trailAt, SPARK, ColorSequence.new(rgb(255, 240, 200), rgb(255, 200, 90)), {
		Rate = 0,
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0, 2),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 0) }),
		LightEmission = 1,
	})
	local crossing = 14
	local clock = every - 6
	table.insert(set.ticks, function(dt: number)
		clock += dt
		local cam = camera()
		local s = clock / crossing
		if s > 1 or not cam then
			for _, p in team do
				p.CFrame = CFrame.new(0, -500, 0)
			end
			trail.Rate = 0
			if clock > every then
				clock = 0
				pcall(Sound.play, "bellTree", 0.35, 1.1)
			end
			return
		end
		local here = cam.CFrame.Position
		local from = here + Vector3.new(-480, 170, -380)
		local to = here + Vector3.new(480, 210, -380)
		local p = from:Lerp(to, s) + Vector3.new(0, math.sin(s * math.pi) * 40, 0)
		for i, part2 in team do
			part2.CFrame = CFrame.new(p + Vector3.new((i - 1) * 30, math.sin(clock * 3 + i) * 2, 0))
		end
		trailAt.CFrame = CFrame.new(p - Vector3.new(16, 0, 0))
		trail.Rate = 40
	end)
end

-- A low mist drifting along the street (where it's affordable).
local function streetMist(set: Set, colour: Color3)
	if not Quality.rich() then
		return
	end
	local p = part(set.folder, "Mist", Vector3.new(150, 1, 70), CFrame.new(0, 1, -60), WHITE)
	p.Transparency = 1
	emitter(p, SMOKE, ColorSequence.new(colour), {
		Rate = 5,
		Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(0.4, 1.2),
		SpreadAngle = Vector2.new(60, 60),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 22) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.84), NumberSequenceKeypoint.new(0.7, 0.86), NumberSequenceKeypoint.new(1, 1) }),
		LightEmission = 0.3,
		RotSpeed = NumberRange.new(-10, 10),
		Rotation = NumberRange.new(0, 360),
	})
end

-- Snow lying on the street (the pavement and the road), and on the steps' sides.
local function snowCover(set: Set)
	local c = cfg()
	local y = c.street
	local S = Layout.Street
	-- (Snow at night is moonlit blue-grey: pure white would glare under the street lamps.)
	part(set.folder, "SnowCover", Vector3.new(300, 0.14, S.pavementZ[2] - S.pavementZ[1] - 0.2), CFrame.new(0, y + 0.05, (S.pavementZ[1] + S.pavementZ[2]) / 2), rgb(196, 206, 222), Enum.Material.Snow)
	part(set.folder, "SnowCover", Vector3.new(300, 0.14, S.roadZ[2] - S.roadZ[1]), CFrame.new(0, 0.07, (S.roadZ[1] + S.roadZ[2]) / 2), rgb(186, 197, 214), Enum.Material.Snow)
end

---------------------------------------------------------------------------------------------------
-- The holidays
---------------------------------------------------------------------------------------------------

local SOUTH = Vector3.new(0, 0, -1)
local NORTH = Vector3.new(0, 0, 1)

local BUILD: { [string]: (Set) -> () } = {}

BUILD.halloween = function(set: Set)
	local c = cfg()
	local y = c.street
	local orange, violet = rgb(255, 140, 40), rgb(160, 96, 255)
	-- Giant jack-o'-lanterns either side of the steps, smaller ones on the steps and along the kerb.
	for _, sx in { -1, 1 } do
		pumpkin(set, Vector3.new(sx * 17, y, -28), 7, SOUTH, true, true)
		pumpkin(set, Vector3.new(sx * 23.5, y, -24.5), 3.6, SOUTH + Vector3.new(-sx * 0.3, 0, 0), true, false)
		for step = 0, 2 do
			pumpkin(set, Vector3.new(sx * 9.6, 1.6 * (step + 1), -21.6 + step * 2.4), 1.7, SOUTH, true, false)
		end
	end
	for i = 0, 7 do
		pumpkin(set, Vector3.new(-42 + i * 12, y, -51), 2.4, NORTH, true, false)
	end
	frontLines(set, { orange, violet }, 0.75, 11)
	twinkle(set, 0.18, 0.05)
	-- The harvest moon, bats crossing it, a violet mist along the street.
	local sky = skyward(32, -14)
	moon(set, rgb(255, 180, 86), rgb(255, 128, 40), sky, 150)
	bats(set, sky, 7)
	streetMist(set, rgb(140, 80, 220))
	-- In the Foyer: candles floating under the ceiling, lights wound up the columns, a pumpkin at
	-- each column's foot.
	floatingCandles(set, c.candles or 28)
	columnWraps(set, { orange, violet }, 0.7)
	for _, col in c.columns do
		local p = at(col, Vector3.zero)
		pumpkin(set, Vector3.new(p.X - math.sign(p.X) * 3.6, Layout.FLOOR, p.Z), 2.6, Vector3.new(-p.X, 0, 0), true, false)
	end
end

BUILD.thanksgiving = function(set: Set)
	local c = cfg()
	local y = c.street
	local leaves = { rgb(196, 74, 28), rgb(232, 124, 40), rgb(236, 178, 60), rgb(150, 46, 30), rgb(214, 150, 60) }
	local bark = rgb(84, 56, 36)
	-- Autumn trees either side of the door.
	for _, sx in { -1, 1 } do
		leafyTree(set, Vector3.new(sx * 44, y, -32), 26, leaves, bark)
		leafyTree(set, Vector3.new(sx * 60, y, -42), 19, leaves, bark)
		-- Hay bales, corn and pumpkins at the steps.
		local bx = sx * 18.5
		local bale = rgb(214, 178, 96)
		part(set.folder, "HayBale", Vector3.new(4.2, 2.4, 2.6), CFrame.new(bx - 2.2, y + 1.2, -26), bale, Enum.Material.Fabric).CastShadow = true
		part(set.folder, "HayBale", Vector3.new(4.2, 2.4, 2.6), CFrame.new(bx + 2.2, y + 1.2, -26), bale, Enum.Material.Fabric).CastShadow = true
		part(set.folder, "HayBale", Vector3.new(4.2, 2.4, 2.6), CFrame.new(bx, y + 3.6, -26), bale:Lerp(rgb(255, 230, 160), 0.1), Enum.Material.Fabric).CastShadow = true
		pumpkin(set, Vector3.new(bx, y + 4.8, -26), 2.2, SOUTH, false)
		pumpkin(set, Vector3.new(bx - 3.4, y, -28.6), 2.6, SOUTH, false)
		pumpkin(set, Vector3.new(bx + 3.6, y, -28.4), 1.8, SOUTH, false, nil, { rgb(240, 232, 214), rgb(222, 212, 192) })
		pumpkin(set, Vector3.new(bx + 1.2, y, -29.4), 1.5, SOUTH, false, nil, { rgb(120, 140, 70), rgb(100, 120, 60) })
		-- A sheaf of corn against the front.
		for k = 0, 6 do
			local a = k / 7 * math.pi * 2
			local foot = Vector3.new(sx * 25.5 + math.cos(a) * 1.1, y, -19.6 + math.sin(a) * 0.8)
			local top = Vector3.new(sx * 25.5 + math.cos(a) * 0.4, y + 9, -19.6 + math.sin(a) * 0.3)
			part(set.folder, "Corn", Vector3.new((top - foot).Magnitude, 0.3, 0.3), CFrame.lookAt((foot + top) / 2, top) * CFrame.Angles(0, math.pi / 2, 0), rgb(204, 176, 102), Enum.Material.Fabric, Enum.PartType.Cylinder)
		end
	end
	-- Garlands of autumn leaves under the cornices, a warm lantern at every span.
	frontLines(set, leaves, 1.15, 14, Enum.Material.Grass, function(p: Vector3)
		local lamp = ellipsoid(set.folder, "Lantern", Vector3.new(1.1, 1.5, 1.1), CFrame.new(p - Vector3.new(0, 0.9, 0)), rgb(255, 190, 100), Enum.Material.Neon)
		table.insert(set.bulbs, lamp)
		part(set.folder, "LanternCap", Vector3.new(1.2, 0.3, 1.2), CFrame.new(p - Vector3.new(0, 0.05, 0)), rgb(60, 44, 30), Enum.Material.Metal)
	end)
	twinkle(set, 0.3, 0.03)
	local sky = skyward(30, 12)
	moon(set, rgb(255, 196, 110), rgb(255, 150, 70), sky, 140)
	-- In the Foyer: autumn leaves wound up the columns, with lights among them, harvest at their feet.
	columnWraps(set, leaves, 1.0, Enum.Material.Grass, { rgb(255, 200, 110) })
	for _, col in c.columns do
		local p = at(col, Vector3.zero)
		local foot = Vector3.new(p.X - math.sign(p.X) * 3.8, Layout.FLOOR, p.Z)
		pumpkin(set, foot, 2.6, Vector3.new(-p.X, 0, 0), false)
		pumpkin(set, foot + Vector3.new(0, 0, 2.6), 1.6, Vector3.new(-p.X, 0, 0), false, nil, { rgb(240, 232, 214), rgb(222, 212, 192) })
		pumpkin(set, foot + Vector3.new(0, 0, -2.4), 1.4, Vector3.new(-p.X, 0, 0), false, nil, { rgb(214, 150, 60), rgb(196, 130, 50) })
	end
end

BUILD.christmas = function(set: Set)
	local c = cfg()
	local warm = { rgb(255, 214, 140), rgb(230, 40, 52), rgb(70, 210, 100), rgb(255, 196, 70), rgb(110, 170, 255) }
	local baubles = { rgb(180, 24, 40), rgb(232, 190, 90), rgb(210, 215, 225), rgb(50, 90, 200) }
	-- The great tree on the pavement, and the Foyer's own.
	firTree(set, at(c.streetTree, Vector3.new(-56, c.street, -36)), c.streetTreeHeight or 46, warm, baubles, true)
	firTree(set, at(c.foyerTree, Vector3.new(-22, Layout.FLOOR, 28)), c.foyerTreeHeight or 26, warm, baubles, true)
	-- Candy canes at the steps.
	for _, sx in { -1, 1 } do
		for k = 0, 1 do
			candyCane(set, Vector3.new(sx * (14 + k * 6), c.street, -24.5 - k * 2), 7, Vector3.new(-sx, 0, 0))
		end
	end
	-- Snow on the street; pine and lights under the cornices.
	snowCover(set)
	frontLines(set, { rgb(26, 84, 50), rgb(20, 70, 42) }, 1.3, 11, Enum.Material.Grass, function(p: Vector3)
		ball(set.folder, "Bow", 1.2, p - Vector3.new(0, 0.6, 0.6), rgb(180, 24, 40), Enum.Material.Fabric)
	end)
	frontLines(set, warm, 0.55, 14, nil, nil, 0.75)
	twinkle(set, 0.15, 0.05)
	-- The sky: the northern lights, and a sleigh now and then.
	northernLights(set, { rgb(80, 255, 160), rgb(60, 200, 255), rgb(160, 110, 255) })
	sleigh(set, c.sleighEvery or 50)
	-- In the Foyer: pine and lights wound up the columns.
	columnWraps(set, { rgb(26, 84, 50), rgb(20, 70, 42) }, 1.15, Enum.Material.Grass, warm)
end

BUILD.newYear = function(set: Set)
	local c = cfg()
	local gold, silver, champagne, black = rgb(255, 214, 120), rgb(225, 230, 240), rgb(250, 232, 190), rgb(28, 28, 32)
	for _, sx in { -1, 1 } do
		balloons(set, Vector3.new(sx * 16, c.street, -26), 9, { gold, silver, black, champagne }, 9)
	end
	glitterBall(set, at(c.glitterBall, Vector3.new(0, 44, -50)), 7)
	searchlights(set, gold)
	skyBursts(set, { gold, silver, champagne }, c.burstEvery or 9)
	frontLines(set, { gold, champagne, silver }, 0.6, 16)
	twinkle(set, 0.12, 0.06)
	-- In the Foyer: balloons by the columns, gold and silver wound up them.
	for _, col in c.columns do
		local p = at(col, Vector3.zero)
		balloons(set, Vector3.new(p.X - math.sign(p.X) * 3.8, Layout.FLOOR, p.Z), 6, { gold, silver, black }, 8)
	end
	columnWraps(set, { gold, silver }, 0.6)
end

BUILD.valentine = function(set: Set)
	local c = cfg()
	local rose, red, blush, gold = rgb(255, 120, 170), rgb(220, 30, 70), rgb(255, 196, 214), rgb(240, 200, 120)
	for _, sx in { -1, 1 } do
		heartOfLights(set, Vector3.new(sx * 22, c.street, -27), 15, SOUTH, { rose, red, blush })
	end
	frontLines(set, { rose, red, blush }, 0.7, 12)
	twinkle(set, 0.2, 0.05)
	risingLanterns(set, "♥", c.lanterns or 36, { rose, red, rgb(255, 160, 120) }, 4)
	-- In the Foyer: hearts floating under the ceiling, roses wound up the columns.
	floaters(set, "♥", c.floaters or 22, { rose, red, blush }, 2.6)
	columnWraps(set, { red, rose }, 0.8, Enum.Material.SmoothPlastic, { gold })
end

BUILD.stPatrick = function(set: Set)
	local c = cfg()
	local emerald, green, gold = rgb(30, 170, 80), rgb(110, 220, 110), rgb(255, 206, 80)
	for _, sx in { -1, 1 } do
		shamrock(set, Vector3.new(sx * 19, c.street, -27), 9, SOUTH)
	end
	pennants(set, { emerald, gold, green, rgb(240, 236, 228) })
	frontLines(set, { gold, green }, 0.45, 18)
	twinkle(set, 0.2, 0.05)
	floaters(set, "☘", c.floaters or 22, { emerald, green }, 2.4)
	columnWraps(set, { emerald, gold }, 0.7)
end

BUILD.easter = function(set: Set)
	local c = cfg()
	local pastels = { rgb(255, 182, 214), rgb(255, 236, 140), rgb(170, 214, 255), rgb(176, 240, 200), rgb(206, 180, 255) }
	local blossom = { rgb(255, 196, 220), rgb(255, 214, 230), rgb(250, 170, 205), rgb(255, 236, 244) }
	for _, sx in { -1, 1 } do
		leafyTree(set, Vector3.new(sx * 44, c.street, -32), 24, blossom, rgb(96, 70, 56))
	end
	local eggs = {
		{ x = -24, z = -33, h = 8, body = pastels[1], trim = pastels[3] },
		{ x = 25, z = -31, h = 9, body = pastels[4], trim = pastels[5] },
		{ x = -32, z = -45, h = 6, body = pastels[2], trim = pastels[1] },
		{ x = 33, z = -46, h = 6.5, body = pastels[5], trim = pastels[2] },
	}
	for i, e in eggs do
		paintedEgg(set, Vector3.new(e.x, c.street, e.z), e.h, e.body, e.trim, i * 0.7)
	end
	for _, sx in { -1, 1 } do
		tulips(set, Vector3.new(sx * 12.5, c.street, -17.8), Vector3.new(sx * 31, c.street, -17.8), 14, pastels)
	end
	pennants(set, pastels)
	butterflies(set, c.butterflies or 14)
	-- In the Foyer: balloons and eggs by the columns, blossom wound up them.
	for _, col in c.columns do
		local p = at(col, Vector3.zero)
		local foot = Vector3.new(p.X - math.sign(p.X) * 3.8, Layout.FLOOR, p.Z)
		balloons(set, foot, 5, pastels, 8)
		paintedEgg(set, foot + Vector3.new(0, 0, 3), 2.2, pastels[(math.floor(p.Z) % #pastels) + 1], WHITE, 0.4)
	end
	columnWraps(set, blossom, 0.95, Enum.Material.Grass, { rgb(255, 250, 220) })
end

-- Builds a holiday's pieces in their own folder (in MaisonLocal); returns the set, or nil for a
-- holiday that has none.
function HolidaySets.build(id: string): Set?
	local make = BUILD[id]
	if not make then
		return nil
	end
	local folder = Instance.new("Folder")
	folder.Name = "HolidaySet_" .. id
	local set: Set = { id = id, folder = folder, ticks = {}, bulbs = {}, palette = {}, rng = Random.new(#id * 7919) }
	make(set)
	folder.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	return set
end

-- One beat of everything that moves in a set. (A piece whose beat fails is let go, never left to
-- fail again every frame.)
function HolidaySets.step(set: Set, dt: number, t: number)
	local ticks = set.ticks
	for i = #ticks, 1, -1 do
		if not pcall(ticks[i], dt, t) then
			table.remove(ticks, i)
		end
	end
end

-- (For tests: which holidays have pieces.)
function HolidaySets.has(id: string): boolean
	return BUILD[id] ~= nil
end

return HolidaySets

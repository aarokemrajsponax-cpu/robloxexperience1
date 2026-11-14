--!strict
-- Builds the Grand Ballroom (shared/Gala has the plan): one vast colonnaded hall in ivory and gold
-- under a coffered night-blue ceiling and seven crystal chandeliers, tall arched windows on the
-- night, crimson drapes. Up the nave: the doors home and two photo sets either side of them, the
-- glass Dance Floor (its tiles light to the music on every screen) and the DJ's booth, the
-- Achievement Gallery's eight frames along the colonnades, and the Moonlit Terrace under its great
-- moon with the Hall of Fame's six boards either side. The west wing: the Salon of Wits (Luxury
-- Trivia's screen, host and eight podiums) and the Daily Arena's ring; the east wing: the Runway
-- (catwalk, stage and backdrop, benches for the room) and the Exchange's four trading stands.
-- Every prompt is tagged for server/Attractions; every board the server writes is returned here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Furniture = require(ReplicatedStorage.Shared.Furniture)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Plan = require(ReplicatedStorage.Shared.Gala)
local FlexPlan = require(ReplicatedStorage.Shared.Flex)
local Kit = require(script.Parent.Parent.World.Kit)

local GalaBuild = {}

local L = Kit.Looks
local rgb = Color3.fromRGB
local v3 = Vector3.new
local H = Plan.HALL

local function look(c: Color3, m: Enum.Material, refl: number?, tr: number?): Kit.Look
	return { color = c, material = m, reflectance = refl, transparency = tr }
end

local IVORY = look(rgb(232, 224, 206), Enum.Material.Plaster)
local PANEL = look(rgb(222, 212, 190), Enum.Material.SmoothPlastic, 0.04)
local GILT = look(rgb(214, 170, 78), Enum.Material.Metal, 0.22)
local GILT_DEEP = look(rgb(164, 124, 50), Enum.Material.Metal, 0.16)
local CRIMSON = look(rgb(118, 14, 30), Enum.Material.Fabric)
local NAVY = look(rgb(16, 22, 46), Enum.Material.SmoothPlastic, 0.05)
local NIGHT = look(rgb(24, 36, 78), Enum.Material.Glass, 0.3, 0.2)
local MARBLE = L.boneMarble
local BLACK = L.blackMarble
local PARQUET = look(rgb(86, 54, 32), Enum.Material.WoodPlanks, 0.08)
local CRYSTAL = look(rgb(232, 238, 248), Enum.Material.Glass, 0.4, 0.3)
local FLAME = look(rgb(255, 216, 150), Enum.Material.Neon)
local TILE = look(rgb(28, 24, 38), Enum.Material.Glass, 0.3, 0.05)
local NEON_GOLD = look(rgb(255, 202, 112), Enum.Material.Neon)
local MOONLIGHT = look(rgb(232, 238, 255), Enum.Material.Neon)
local INVISIBLE = look(Color3.new(), Enum.Material.SmoothPlastic, 0, 1)
local VELVET = look(rgb(70, 10, 22), Enum.Material.Fabric)
local TRIM = { collide = false, query = false, shadow = false }
local SOFT = { collide = false, query = false }

export type Board = { part: BasePart, labels: { [string]: TextLabel } }
export type Built = {
	model: Model,
	home: BasePart,
	screen: Board, -- Luxury Trivia's big screen
	runwayBoard: Board,
	arenaBoard: Board,
	podiums: { BasePart }, -- each podium's glow strip, by number
	coins: Folder,
	dj: BasePart,
	flexWall: Board?, -- (Build 81) the Flex Studio's wall the server writes
}

---------------------------------------------------------------------------------------------------
-- Little helpers
---------------------------------------------------------------------------------------------------
local function prompt(parent: BasePart, kind: string, action: string, object: string, attrs: { [string]: any }?, distance: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "AttractionPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Attraction", Plan.ID)
	p:SetAttribute("Kind", kind)
	if attrs then
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
	end
	p.Parent = parent
	CollectionService:AddTag(p, "AttractionPrompt")
	return p
end

-- A SurfaceGui the server writes on: lines named as given, top to bottom (scale heights).
local function screen(part: BasePart, ppu: number, lines: { { name: string, size: number, font: Font, colour: Color3, text: string? } }, lit: boolean?): Board
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu
	gui.LightInfluence = if lit then 0.4 else 0
	gui.Brightness = 1.5
	gui.MaxDistance = 260
	gui.ClipsDescendants = true
	gui.Parent = part
	-- (Build 82) Every board in the hall dressed alike: a deep plum glass darkening to black, a
	-- gold hairline inside its edge, a gold sheen on its heading, a short gold rule under it, and
	-- the live line in a pill of its own colour.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.new(1, 1, 1)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	local wash = Instance.new("UIGradient")
	wash.Rotation = 90
	wash.Color = ColorSequence.new(rgb(46, 22, 52), rgb(8, 6, 12))
	wash.Parent = backdrop
	local inset = Instance.new("Frame")
	inset.Name = "Inset"
	inset.AnchorPoint = Vector2.new(0.5, 0.5)
	inset.Position = UDim2.fromScale(0.5, 0.5)
	inset.Size = UDim2.new(1, -math.floor(ppu * 0.5), 1, -math.floor(ppu * 0.5))
	inset.BackgroundTransparency = 1
	inset.Parent = gui
	local rim = Instance.new("UIStroke")
	rim.Color = rgb(232, 190, 96)
	rim.Transparency = 0.45
	rim.Thickness = math.max(2, math.floor(ppu * 0.08))
	rim.Parent = inset
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(ppu * 0.3))
	corner.Parent = inset
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.05, 0)
	pad.PaddingBottom = UDim.new(0.05, 0)
	pad.PaddingLeft = UDim.new(0.04, 0)
	pad.PaddingRight = UDim.new(0.04, 0)
	pad.Parent = holder
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0.015, 0)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = holder
	local labels: { [string]: TextLabel } = {}
	for i, line in lines do
		local l = Instance.new("TextLabel")
		l.Name = line.name
		l.LayoutOrder = i
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, line.size, 0)
		l.FontFace = line.font
		l.Text = line.text or ""
		l.TextColor3 = line.colour
		l.TextScaled = true
		l.TextWrapped = true
		l.Parent = holder
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = math.floor(line.size * part.Size.Y * ppu * 0.92)
		cap.Parent = l
		labels[line.name] = l
		if i == 1 then
			-- The heading in gold leaf, and a short gold rule under it.
			local sheen = Instance.new("UIGradient")
			sheen.Rotation = 90
			sheen.Color = ColorSequence.new(rgb(255, 236, 176), rgb(214, 160, 60))
			sheen.Parent = l
			l.TextColor3 = Color3.new(1, 1, 1)
			local rule = Instance.new("Frame")
			rule.Name = "Rule"
			rule.LayoutOrder = i
			rule.Size = UDim2.new(0.18, 0, 0, math.max(2, math.floor(ppu * 0.06)))
			rule.BackgroundColor3 = rgb(232, 190, 96)
			rule.BackgroundTransparency = 0.2
			rule.BorderSizePixel = 0
			rule.Parent = holder
			l.LayoutOrder = i - 1
		elseif line.name == "State" then
			-- The live line, in a pill.
			l.Size = UDim2.new(0.78, 0, line.size, 0)
			l.BackgroundColor3 = line.colour
			l.BackgroundTransparency = 0.82
			local pc = Instance.new("UICorner")
			pc.CornerRadius = UDim.new(0.5, 0)
			pc.Parent = l
			local pp = Instance.new("UIPadding")
			pp.PaddingLeft = UDim.new(0.04, 0)
			pp.PaddingRight = UDim.new(0.04, 0)
			pp.PaddingTop = UDim.new(0.12, 0)
			pp.PaddingBottom = UDim.new(0.12, 0)
			pp.Parent = l
		end
	end
	return { part = part, labels = labels }
end

-- A gilded frame round a rectangle on a wall (`cf`: the rectangle's middle, facing out).
local function frame(m: Instance, cf: CFrame, w: number, h: number, bar: number, lk: Kit.Look)
	Kit.part(m, "FrameTop", v3(w + bar * 2, bar, 0.5), cf * CFrame.new(0, h / 2 + bar / 2, 0), lk, TRIM)
	Kit.part(m, "FrameFoot", v3(w + bar * 2, bar, 0.5), cf * CFrame.new(0, -h / 2 - bar / 2, 0), lk, TRIM)
	Kit.part(m, "FrameSide", v3(bar, h, 0.5), cf * CFrame.new(-w / 2 - bar / 2, 0, 0), lk, TRIM)
	Kit.part(m, "FrameSide", v3(bar, h, 0.5), cf * CFrame.new(w / 2 + bar / 2, 0, 0), lk, TRIM)
end

-- A bench for watchers, with two seats (`cf`: its middle on the floor, facing the way they look).
local function bench(m: Instance, cf: CFrame, label: string)
	Kit.part(m, "BenchSeat", v3(6, 0.6, 1.8), cf * CFrame.new(0, 1.5, 0), CRIMSON)
	Kit.part(m, "BenchFrame", v3(6.2, 0.3, 2), cf * CFrame.new(0, 1.1, 0), GILT_DEEP, TRIM)
	for _, sx in { -2.7, 2.7 } do
		Kit.part(m, "BenchLeg", v3(0.3, 1, 1.6), cf * CFrame.new(sx, 0.5, 0), GILT_DEEP, TRIM)
	end
	local top = cf * CFrame.new(0, 1.8, 0)
	Furniture.seatsOn(m, "BenchSeats", { top * CFrame.new(-1.4, 0, 0), top * CFrame.new(1.4, 0, 0) }, label, 1.6)
end

---------------------------------------------------------------------------------------------------
-- The hall itself
---------------------------------------------------------------------------------------------------
local function shell(m: Model, o: Vector3)
	local top = H.height
	-- The floor: bone marble up the nave with a black marble border; parquet in the wings.
	Kit.span(m, "Floor", o + v3(H.minX, -2, H.minZ), o + v3(H.maxX, 0, H.maxZ), MARBLE)
	Kit.span(m, "WingFloorW", o + v3(H.minX, 0, H.minZ), o + v3(-Plan.NAVE - 2, 0.04, H.maxZ), PARQUET, TRIM)
	Kit.span(m, "WingFloorE", o + v3(Plan.NAVE + 2, 0, H.minZ), o + v3(H.maxX, 0.04, H.maxZ), PARQUET, TRIM)
	for _, side in { -1, 1 } do
		Kit.span(m, "NaveBorder", o + v3(side * (Plan.NAVE - 3), 0, H.minZ), o + v3(side * (Plan.NAVE + 2), 0.05, H.maxZ), BLACK, TRIM)
	end
	-- A long crimson runner from the doors to the dance floor, edged in gold.
	Kit.span(m, "Runner", o + v3(-4, 0, H.minZ + 2), o + v3(4, 0.08, Plan.DANCE.centre.Z - Plan.DANCE.radius - 1), look(rgb(110, 14, 28), Enum.Material.Carpet), TRIM)
	for _, sx in { -4.2, 4.2 } do
		Kit.span(m, "RunnerEdge", o + v3(sx - 0.2, 0, H.minZ + 2), o + v3(sx + 0.2, 0.09, Plan.DANCE.centre.Z - Plan.DANCE.radius - 1), GILT, TRIM)
	end
	-- The walls (ivory, with a gilded dado and cornice), and the ceiling.
	Kit.span(m, "WallS", o + v3(H.minX - 2, 0, H.minZ - 2), o + v3(H.maxX + 2, top, H.minZ), IVORY)
	Kit.span(m, "WallN", o + v3(H.minX - 2, 0, H.maxZ), o + v3(H.maxX + 2, top, H.maxZ + 2), IVORY)
	Kit.span(m, "WallW", o + v3(H.minX - 2, 0, H.minZ), o + v3(H.minX, top, H.maxZ), IVORY)
	Kit.span(m, "WallE", o + v3(H.maxX, 0, H.minZ), o + v3(H.maxX + 2, top, H.maxZ), IVORY)
	Kit.span(m, "Ceiling", o + v3(H.minX - 2, top, H.minZ - 2), o + v3(H.maxX + 2, top + 1.5, H.maxZ + 2), NAVY)
	for _, spec in {
		{ v3(H.minX, 0, H.minZ), v3(H.maxX, 3.2, H.minZ + 0.4) }, { v3(H.minX, 0, H.maxZ - 0.4), v3(H.maxX, 3.2, H.maxZ) },
		{ v3(H.minX, 0, H.minZ), v3(H.minX + 0.4, 3.2, H.maxZ) }, { v3(H.maxX - 0.4, 0, H.minZ), v3(H.maxX, 3.2, H.maxZ) },
	} do
		Kit.span(m, "Dado", o + spec[1], o + spec[2], PANEL, TRIM)
	end
	for _, spec in {
		{ v3(H.minX, top - 2.4, H.minZ), v3(H.maxX, top, H.minZ + 1.2) }, { v3(H.minX, top - 2.4, H.maxZ - 1.2), v3(H.maxX, top, H.maxZ) },
		{ v3(H.minX, top - 2.4, H.minZ), v3(H.minX + 1.2, top, H.maxZ) }, { v3(H.maxX - 1.2, top - 2.4, H.minZ), v3(H.maxX, top, H.maxZ) },
	} do
		Kit.span(m, "Cornice", o + spec[1], o + spec[2], GILT, TRIM)
	end
	Kit.span(m, "DadoRailS", o + v3(H.minX, 3.2, H.minZ), o + v3(H.maxX, 3.6, H.minZ + 0.5), GILT, TRIM)
	Kit.span(m, "DadoRailN", o + v3(H.minX, 3.2, H.maxZ - 0.5), o + v3(H.maxX, 3.6, H.maxZ), GILT, TRIM)
	Kit.span(m, "DadoRailW", o + v3(H.minX, 3.2, H.minZ), o + v3(H.minX + 0.5, 3.6, H.maxZ), GILT, TRIM)
	Kit.span(m, "DadoRailE", o + v3(H.maxX - 0.5, 3.2, H.minZ), o + v3(H.maxX, 3.6, H.maxZ), GILT, TRIM)
	-- The ceiling's coffers: gilded ribs both ways, deeper over the nave.
	local x = H.minX + 20
	while x < H.maxX - 4 do
		Kit.span(m, "RibX", o + v3(x - 0.6, top - 1.6, H.minZ), o + v3(x + 0.6, top, H.maxZ), GILT_DEEP, TRIM)
		x += 20
	end
	local z = H.minZ + 22
	while z < H.maxZ - 4 do
		Kit.span(m, "RibZ", o + v3(H.minX, top - 1.6, z - 0.6), o + v3(H.maxX, top, z + 0.6), GILT_DEEP, TRIM)
		z += 22
	end
end

-- The two colonnades down the hall, and the gilded beams they carry.
local function colonnades(m: Model, o: Vector3)
	local h = 38
	for _, side in { -1, 1 } do
		for _, z in Plan.COLUMNS do
			local base = o + v3(side * Plan.NAVE, 0, z)
			Kit.part(m, "Plinth", v3(5, 1.6, 5), CFrame.new(base + v3(0, 0.8, 0)), BLACK)
			Kit.post(m, "ColumnBase", 1, 4.4, base + v3(0, 1.6, 0), GILT, TRIM)
			Kit.post(m, "Column", h - 4.6, 3.2, base + v3(0, 2.6, 0), MARBLE)
			for k = 1, 3 do
				Kit.post(m, "Flute", 0.3, 3.5, base + v3(0, 2.6 + k * (h - 4.6) / 4, 0), GILT_DEEP, TRIM)
			end
			Kit.post(m, "Capital", 1.4, 4.2, base + v3(0, h - 2, 0), GILT, TRIM)
			Kit.part(m, "Abacus", v3(5.2, 0.8, 5.2), CFrame.new(base + v3(0, h - 0.2, 0)), GILT, TRIM)
		end
		-- The entablature along the top.
		Kit.span(m, "Beam", o + v3(side * Plan.NAVE - 2.6, h + 0.2, H.minZ), o + v3(side * Plan.NAVE + 2.6, h + 3.4, H.maxZ), PANEL)
		Kit.span(m, "BeamBand", o + v3(side * Plan.NAVE - 2.7, h + 1.4, H.minZ), o + v3(side * Plan.NAVE + 2.7, h + 2, H.maxZ), GILT, TRIM)
		Kit.span(m, "Frieze", o + v3(side * Plan.NAVE - 2.4, h + 3.4, H.minZ), o + v3(side * Plan.NAVE + 2.4, H.height, H.maxZ), IVORY, SOFT)
	end
end

-- Tall arched windows on the night, with crimson drapes, along the side walls where they're free.
local function windows(m: Model, o: Vector3)
	-- (Clear of the boards and screens on those walls; the east wall behind the Runway keeps its
	-- panels.)
	local spots = { [-1] = { -92, -26, -8, 10, 28, 94 }, [1] = { -92, -26, -8 } }
	for _, side in { -1, 1 } do
		local wx = if side < 0 then H.minX + 0.3 else H.maxX - 0.3
		for _, z in spots[side] do
			do
				local face = CFrame.lookAt(o + v3(wx, 22, z), o + v3(0, 22, z))
				Kit.part(m, "Window", v3(8, 30, 0.3), face, NIGHT, SOFT)
				Kit.cylinder(m, "WindowArch", 0.3, 8, face * CFrame.new(0, 15, 0) * CFrame.Angles(0, math.rad(90), 0), NIGHT, TRIM)
				frame(m, face * CFrame.new(0, 0, -0.2), 8, 30, 0.7, GILT)
				Kit.part(m, "Mullion", v3(0.3, 30, 0.2), face * CFrame.new(0, 0, -0.3), GILT_DEEP, TRIM)
				Kit.part(m, "Transom", v3(8, 0.3, 0.2), face * CFrame.new(0, 4, -0.3), GILT_DEEP, TRIM)
				for _, dx in { -6, 6 } do
					Kit.part(m, "Drape", v3(3.2, 40, 0.8), face * CFrame.new(dx, 6, -0.8), CRIMSON, SOFT)
					Kit.part(m, "Tieback", v3(3.4, 0.5, 1), face * CFrame.new(dx, -4, -1), GILT, TRIM)
				end
			end
		end
	end
end

-- A crystal chandelier: tiers of candles and drops (`light`: the warm light it throws).
local function chandelier(m: Model, at: Vector3, scale: number, range: number)
	local c = Kit.model(m, "Chandelier")
	Kit.post(c, "Chain", H.height - at.Y + 0.5, 0.35 * scale, at + v3(0, 2.4 * scale, 0), GILT_DEEP, TRIM)
	for tier, spec in { { r = 6, n = 14, y = 0 }, { r = 4, n = 10, y = 1.6 }, { r = 2, n = 6, y = 3 } } do
		local r = spec.r * scale
		Kit.cylinder(c, "Hoop" .. tier, 0.3 * scale, r * 2 + 0.4, CFrame.new(at + v3(0, spec.y * scale - 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT, TRIM)
		for i = 1, spec.n do
			local a = i / spec.n * math.pi * 2
			local p = at + v3(math.cos(a) * r, spec.y * scale, math.sin(a) * r)
			Kit.post(c, "Candle", 0.8 * scale, 0.24 * scale, p, L.bone, TRIM)
			Kit.part(c, "Flame", v3(0.2, 0.36, 0.2) * scale, CFrame.new(p + v3(0, 1 * scale, 0)), FLAME, TRIM)
			if tier == 1 then
				Kit.part(c, "Drop", v3(0.24, 0.9, 0.24) * scale, CFrame.new(at + v3(math.cos(a + 0.2) * (r - 0.6), -1.4 * scale, math.sin(a + 0.2) * (r - 0.6))), CRYSTAL, TRIM)
			end
		end
	end
	Kit.ball(c, "Finial", 1.4 * scale, at + v3(0, -2.4 * scale, 0), CRYSTAL, TRIM)
	local glow = Kit.part(c, "Glow", v3(0.4, 0.4, 0.4), CFrame.new(at), INVISIBLE, TRIM)
	Kit.pointLight(glow, 1.6, math.min(range, 60), rgb(255, 210, 150), false)
end

---------------------------------------------------------------------------------------------------
-- The nave
---------------------------------------------------------------------------------------------------
local function doors(m: Model, o: Vector3): BasePart
	local d = Kit.model(m, "DoorsHome")
	local at = o + Plan.DOORS
	local w, h = 14, 22
	local face = CFrame.lookAt(at + v3(0, 0, 0.6), at + v3(0, 0, 10))
	for _, side in { -1, 1 } do
		Kit.part(d, "Leaf", v3(w / 2 - 0.2, h, 0.6), face * CFrame.new(side * w / 4, h / 2, 0), look(rgb(40, 26, 18), Enum.Material.Wood, 0.08))
		Kit.part(d, "LeafPanel", v3(w / 2 - 2, h * 0.36, 0.1), face * CFrame.new(side * w / 4, h * 0.7, -0.36), GILT_DEEP, TRIM)
		Kit.part(d, "LeafPanel", v3(w / 2 - 2, h * 0.36, 0.1), face * CFrame.new(side * w / 4, h * 0.27, -0.36), GILT_DEEP, TRIM)
		Kit.part(d, "Handle", v3(0.3, 3, 0.3), face * CFrame.new(side * 0.8, h * 0.46, -0.5), GILT, TRIM)
		Kit.part(d, "Pilaster", v3(2, h + 4, 1.2), face * CFrame.new(side * (w / 2 + 1), (h + 4) / 2, 0), PANEL)
		Kit.part(d, "PilasterGilt", v3(2.2, 1, 1.4), face * CFrame.new(side * (w / 2 + 1), h + 3, 0), GILT, TRIM)
	end
	Kit.part(d, "Pediment", v3(w + 6, 3, 1.6), face * CFrame.new(0, h + 5.5, 0), PANEL)
	local plate = Kit.part(d, "DoorsPlate", v3(w, 2, 0.2), face * CFrame.new(0, h + 5.5, -0.9), INVISIBLE, TRIM)
	Kit.engrave(plate, Enum.NormalId.Front, {
		{ text = "THE BALLROOM", size = 0.62, font = Brand.Fonts.display, color = rgb(150, 110, 40) },
		{ text = "LIGHTS OUT · THE MAISON", size = 0.3, font = Brand.Fonts.bodyBold, color = rgb(120, 90, 40) },
	}, { ppu = 90, lit = true })
	local veil = Kit.part(d, "Way", v3(w, h, 0.4), face * CFrame.new(0, h / 2, -0.6), INVISIBLE, { collide = false, shadow = false })
	veil.CanQuery = true
	veil:SetAttribute("PromptHome", true)
	prompt(veil, "home", "Return", "The Ballroom", nil, 14)
	return veil
end

-- The glass Dance Floor (its tiles light on every screen, to the beat), its gold ring and the
-- moving lights over it; the DJ's booth with the jukebox.
local function danceFloor(m: Model, o: Vector3): BasePart
	local f = Kit.model(m, "DanceFloor")
	local c = o + Plan.DANCE.centre
	local r = Plan.DANCE.radius
	Kit.cylinder(f, "FloorBed", 0.2, r * 2, CFrame.new(c + v3(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(14, 12, 18), Enum.Material.SmoothPlastic, 0.2), TRIM)
	Kit.cylinder(f, "FloorRing", 0.24, r * 2 + 1.4, CFrame.new(c + v3(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT, TRIM)
	local n = 0
	for i = -7, 7 do
		for j = -7, 7 do
			local p = v3(i * 3.6, 0, j * 3.6)
			if p.Magnitude <= r - 2.4 then
				n += 1
				local tile = Kit.part(f, "Tile", v3(3.3, 0.2, 3.3), CFrame.new(c + p + v3(0, 0.12, 0)), TILE, { shadow = false })
				tile:SetAttribute("Ring", math.floor(p.Magnitude / 3.6 + 0.5))
				tile:SetAttribute("I", i)
				tile:SetAttribute("J", j)
				CollectionService:AddTag(tile, "GalaTile")
			end
		end
	end
	f:SetAttribute("Tiles", n)
	-- Four moving lights on a ring of truss above the floor (the screens sweep them).
	Kit.cylinder(f, "Truss", 0.6, r * 2 - 6, CFrame.new(c + v3(0, H.height - 12, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT_DEEP, TRIM)
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local at = c + v3(math.cos(a) * (r - 3), H.height - 12.8, math.sin(a) * (r - 3))
		local head = Kit.part(f, "Sweep", v3(1.2, 1.6, 1.2), CFrame.lookAt(at, c), look(rgb(20, 20, 24), Enum.Material.Metal, 0.2), TRIM)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Brightness = 3
		spot.Range = 48
		spot.Angle = 26
		spot.Color = ({ rgb(255, 120, 200), rgb(120, 200, 255), rgb(255, 210, 120), rgb(170, 130, 255) })[k]
		spot.Shadows = false
		spot.Parent = head
		head:SetAttribute("Sweep", k)
		CollectionService:AddTag(head, "GalaSweep")
	end
	-- The DJ's booth: a curved lacquer desk, two decks, speakers, an arch of light behind.
	local dj = o + Plan.DJ
	local face = CFrame.lookAt(dj, dj + v3(0, 0, -10))
	local b = Kit.model(m, "DJBooth")
	Kit.part(b, "Riser", v3(18, 1.2, 8), face * CFrame.new(0, 0.6, 1), BLACK)
	Kit.part(b, "Desk", v3(12, 3.4, 2.4), face * CFrame.new(0, 2.9, 0), L.blackLacquer)
	Kit.part(b, "DeskTop", v3(12.4, 0.2, 2.8), face * CFrame.new(0, 4.7, 0), GILT, TRIM)
	Kit.part(b, "DeskFront", v3(11.4, 2.6, 0.1), face * CFrame.new(0, 2.9, -1.25), NEON_GOLD, TRIM).Transparency = 0.55
	for _, dx in { -3.4, 3.4 } do
		Kit.cylinder(b, "Deck", 0.16, 2.4, face * CFrame.new(dx, 4.85, 0) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(16, 16, 18), Enum.Material.SmoothPlastic, 0.3), TRIM)
		Kit.cylinder(b, "Record", 0.18, 2.1, face * CFrame.new(dx, 4.9, 0) * CFrame.Angles(0, 0, math.rad(90)), L.ink, TRIM)
	end
	for _, dx in { -8, 8 } do
		Kit.part(b, "Speaker", v3(2.6, 7, 2.6), face * CFrame.new(dx, 4.7, 1.6), look(rgb(18, 18, 20), Enum.Material.Fabric))
		Kit.cylinder(b, "Cone", 0.2, 1.8, face * CFrame.new(dx, 6.4, 0.3) * CFrame.Angles(0, math.rad(90), 0), GILT_DEEP, TRIM)
		Kit.cylinder(b, "Cone", 0.2, 1.2, face * CFrame.new(dx, 3.6, 0.3) * CFrame.Angles(0, math.rad(90), 0), GILT_DEEP, TRIM)
	end
	-- The arch of light.
	for k = 0, 12 do
		local a = math.rad(k * 15)
		local p = face * CFrame.new(math.cos(a) * 8, 1.2 + math.sin(a) * 8, 4)
		Kit.ball(b, "ArchBulb", 0.7, p.Position, NEON_GOLD, TRIM)
	end
	local sign = Kit.part(b, "BoothSign", v3(8, 1.8, 0.2), face * CFrame.new(0, 6.6, 3.8), L.blackLacquer, TRIM)
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE JUKEBOX", size = 0.6, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "VOTE THE NEXT RECORD", size = 0.28, font = Brand.Fonts.bodyBold, color = Brand.Colours.bone },
	}, { ppu = 90, lit = false, brightness = 1.6, maxDistance = 200 })
	local box = Kit.part(b, "Jukebox", v3(12, 6, 3), face * CFrame.new(0, 4, 0), INVISIBLE, { collide = false, shadow = false })
	box.CanQuery = true
	prompt(box, "panel", "Dance & music", "The Jukebox", { Panel = "dance" }, 16)
	return box
end

-- The Achievement Gallery: eight frames on gilded easels along the colonnades; each guest's own
-- screen hangs their own Badge Book in them.
local function gallery(m: Model, o: Vector3)
	local g = Kit.model(m, "AchievementGallery")
	for i, cf0 in Plan.FRAMES do
		local cf = cf0 + o
		for _, dx in { -2.6, 2.6 } do
			Kit.part(g, "EaselLeg", v3(0.3, 11, 0.3), cf * CFrame.new(dx, 5.5, 0.6) * CFrame.Angles(math.rad(-6), 0, 0), GILT_DEEP, TRIM)
		end
		Kit.part(g, "EaselBack", v3(0.3, 10, 0.3), cf * CFrame.new(0, 5.2, 1.6) * CFrame.Angles(math.rad(16), 0, 0), GILT_DEEP, TRIM)
		Kit.part(g, "EaselRest", v3(7, 0.3, 0.8), cf * CFrame.new(0, 3.2, 0.4), GILT, TRIM)
		local canvas = Kit.part(g, "GalleryFrame", v3(6.4, 6.4, 0.2), cf * CFrame.new(0, 6.6, 0.3) * CFrame.Angles(math.rad(-6), 0, 0), look(rgb(18, 14, 12), Enum.Material.SmoothPlastic), SOFT)
		canvas:SetAttribute("Index", i)
		CollectionService:AddTag(canvas, "GalaFrame")
		frame(g, canvas.CFrame * CFrame.new(0, 0, 0.05), 6.4, 6.4, 0.5, GILT)
	end
	local cf = CFrame.lookAt(o + v3(0, 0, 28), o + v3(0, 0, 0))
	Kit.sign(g, "GallerySign", cf, 5.6, 2.2, {
		{ text = "THE ACHIEVEMENT GALLERY", size = 0.36, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "Your own Badge Book, framed: what you've earned in the house.", size = 0.42, font = Brand.Fonts.body, color = Brand.Colours.bone },
	}, 3.4)
end

-- The Moonlit Terrace (a photo set) under the great moon, the Hall of Fame's six boards either side.
local function terrace(m: Model, o: Vector3): BasePart
	local t = Kit.model(m, "MoonlitTerrace")
	local T = Plan.TERRACE
	-- The night behind it: a panel of deep blue with stars, the moon in it.
	Kit.span(t, "NightPanel", o + v3(T.minX - 0.5, T.top, H.maxZ - 0.3), o + v3(T.maxX + 0.5, H.height - 2.4, H.maxZ - 0.1), NAVY, SOFT)
	frame(t, CFrame.lookAt(o + v3(0, (T.top + H.height - 2.4) / 2, H.maxZ - 0.55), o + v3(0, (T.top + H.height - 2.4) / 2, 0)), (T.maxX - T.minX) + 1, H.height - 2.4 - T.top, 0.8, GILT)
	local rng = Random.new(1789)
	for _ = 1, 40 do
		local p = o + v3(rng:NextNumber(T.minX, T.maxX), rng:NextNumber(T.top + 4, H.height - 4), H.maxZ - 0.33)
		Kit.part(t, "Star", v3(0.22, 0.22, 0.05), CFrame.new(p) * CFrame.Angles(0, 0, math.rad(45)), MOONLIGHT, TRIM)
	end
	local moon = Kit.cylinder(t, "Moon", 0.3, 20, CFrame.new(o + Plan.MOON) * CFrame.Angles(0, math.rad(90), 0), MOONLIGHT, TRIM)
	Kit.cylinder(t, "MoonHalo", 0.2, 23, CFrame.new(o + Plan.MOON + v3(0, 0, 0.2)) * CFrame.Angles(0, math.rad(90), 0), look(rgb(160, 180, 255), Enum.Material.Neon, 0, 0.7), TRIM)
	local mlight = Instance.new("SurfaceLight")
	mlight.Face = Enum.NormalId.Right -- (the disc's face toward the hall: its +X turned to -Z)
	mlight.Brightness = 1.4
	mlight.Range = 40
	mlight.Angle = 100
	mlight.Color = rgb(200, 214, 255)
	mlight.Parent = moon
	-- The terrace: marble on a gilded edge, a balustrade either side of three steps.
	Kit.span(t, "Terrace", o + v3(T.minX, 0, T.minZ), o + v3(T.maxX, T.top, T.maxZ), MARBLE)
	Kit.span(t, "TerraceEdge", o + v3(T.minX - 0.2, T.top - 0.4, T.minZ - 0.2), o + v3(T.maxX + 0.2, T.top, T.minZ + 0.2), GILT, TRIM)
	for k = 1, 3 do
		Kit.span(t, "Step", o + v3(-4, 0, T.minZ - k * 1.4), o + v3(4, T.top * (4 - k) / 4, T.minZ - (k - 1) * 1.4), MARBLE)
	end
	for _, side in { -1, 1 } do
		local x0, x1 = if side < 0 then T.minX else 4, if side < 0 then -4 else T.maxX
		Kit.span(t, "BalustradeRail", o + v3(x0, T.top + 3, T.minZ + 0.1), o + v3(x1, T.top + 3.4, T.minZ + 0.9), MARBLE)
		local x = x0 + 0.6
		while x < x1 - 0.3 do
			Kit.post(t, "Baluster", 3, 0.5, o + v3(x, T.top, T.minZ + 0.5), MARBLE, TRIM)
			x += 1
		end
		Kit.span(t, "BalustradeGuard", o + v3(x0, T.top, T.minZ + 0.2), o + v3(x1, T.top + 3, T.minZ + 0.8), INVISIBLE)
		Furniture.build("plant", t, CFrame.new(o + v3(side * 9.5, T.top, 106)), { model = "topiary" }, false)
	end
	-- The Hall of Fame's six boards on the north wall.
	for i, b in Plan.Boards do
		local at = o + v3(Plan.BOARD_X[i], Plan.BOARD_Y, H.maxZ - 0.4)
		local cf = CFrame.lookAt(at, at + v3(0, 0, -10))
		local board = Kit.part(t, "HallBoard", v3(9, 15, 0.3), cf, look(rgb(12, 10, 14), Enum.Material.SmoothPlastic, 0.1), SOFT)
		board:SetAttribute("Board", b.id)
		CollectionService:AddTag(board, "HallBoard")
		frame(t, cf * CFrame.new(0, 0, -0.1), 9, 15, 0.6, GILT)
		Kit.part(t, "Crest", v3(2.4, 2.4, 0.4), cf * CFrame.new(0, 9.4, -0.1) * CFrame.Angles(0, 0, math.rad(45)), GILT, TRIM)
	end
	local plaque = Kit.part(t, "HallPlaque", v3(30, 2.4, 0.2), CFrame.lookAt(o + v3(-31, 7.6, H.maxZ - 0.6), o + v3(-31, 7.6, 0)), INVISIBLE, TRIM)
	Kit.engrave(plaque, Enum.NormalId.Front, { { text = "THE HALL OF FAME", size = 0.7, font = Brand.Fonts.display, color = rgb(214, 170, 78) } }, { ppu = 90, lit = true })
	local plaque2 = Kit.part(t, "HallPlaque", v3(30, 2.4, 0.2), CFrame.lookAt(o + v3(31, 7.6, H.maxZ - 0.6), o + v3(31, 7.6, 0)), INVISIBLE, TRIM)
	Kit.engrave(plaque2, Enum.NormalId.Front, { { text = "THE HOUSE'S BEST", size = 0.7, font = Brand.Fonts.display, color = rgb(214, 170, 78) } }, { ppu = 90, lit = true })
	return moon
end

-- The two photo sets by the doors: the Gilded Frame and the Rose Arch.
local function photoSets(m: Model, o: Vector3)
	for _, s in Plan.PhotoSets do
		local mark = s.mark + o
		local p = Kit.model(m, "PhotoSet_" .. s.id)
		if s.id == "frame" then
			-- A crimson velvet backdrop in a great gilded frame, a low plinth to stand on.
			Kit.part(p, "Backdrop", v3(14, 18, 0.4), mark * CFrame.new(0, 9, 3.2), VELVET, SOFT)
			frame(p, mark * CFrame.new(0, 8.6, 2.6), 11, 14, 1.2, GILT)
			for _, cx in { -6.1, 6.1 } do
				for _, cy in { 1.0, 16.2 } do
					Kit.ball(p, "Ornament", 1.8, (mark * CFrame.new(cx, cy, 2.4)).Position, GILT, TRIM)
				end
			end
			Kit.cylinder(p, "Plinth", 0.6, 6, mark * CFrame.new(0, 0.3, 0.4) * CFrame.Angles(0, 0, math.rad(90)), BLACK)
		elseif s.id == "rose" then
			-- An arch of roses on two marble pillars, petals falling through it.
			for _, side in { -1, 1 } do
				Kit.part(p, "Pillar", v3(1.8, 9, 1.8), mark * CFrame.new(side * 6, 4.5, 1), MARBLE)
				Kit.part(p, "PillarCap", v3(2.2, 0.6, 2.2), mark * CFrame.new(side * 6, 9.2, 1), GILT, TRIM)
			end
			local colours = { rgb(200, 30, 56), rgb(240, 120, 150), rgb(250, 236, 236), rgb(170, 20, 40) }
			for k = 0, 22 do
				local a = math.rad(k * (180 / 22))
				local at = (mark * CFrame.new(math.cos(a) * 6, 9.5 + math.sin(a) * 5.6, 1)).Position
				Kit.ball(p, "Rose", 1.5 + (k % 3) * 0.2, at, look(colours[k % 4 + 1], Enum.Material.Fabric), TRIM)
				if k % 2 == 0 then
					Kit.ball(p, "Leaf", 1, at + v3(0, -0.4, 0.5), look(rgb(40, 90, 50), Enum.Material.Fabric), TRIM)
				end
			end
			local drift = Kit.part(p, "Petals", v3(10, 0.2, 2), mark * CFrame.new(0, 14.6, 1), INVISIBLE, TRIM)
			HolidayProps.sparkle(drift, rgb(250, 140, 170), 4, 1.2)
			Kit.part(p, "Backdrop", v3(16, 18, 0.4), mark * CFrame.new(0, 9, 3.4), look(rgb(240, 228, 222), Enum.Material.Fabric), SOFT)
			Kit.part(p, "Step", v3(9, 0.4, 4), mark * CFrame.new(0, 0.2, 0.6), MARBLE)
		end
		-- The pose: where the camera stands, a small brass mark on the floor.
		local stand = Kit.part(p, "Pose", v3(3, 0.2, 3), mark * CFrame.new(0, if s.id == "frame" then 0.7 else 0.5, 0), INVISIBLE, { collide = false, shadow = false })
		stand.CanQuery = true
		prompt(stand, "act", "Strike a pose", s.name, { Act = "pose", What = s.id }, 10)
		-- (The photographer's camera on its stand, where the photograph is taken from.)
		Kit.post(p, "CameraStand", s.camera.Y - 1.8, 0.25, o + v3(s.camera.X, 0, s.camera.Z), GILT_DEEP, TRIM)
		Kit.part(p, "Camera", v3(1.2, 0.9, 1.6), CFrame.lookAt(o + s.camera - v3(0, 1.4, 0), o + s.look), look(rgb(20, 20, 22), Enum.Material.Metal, 0.2), TRIM)
	end
end

---------------------------------------------------------------------------------------------------
-- The west wing: the Salon of Wits and the Daily Arena
---------------------------------------------------------------------------------------------------
local function trivia(m: Model, o: Vector3): (Board, { BasePart })
	local t = Kit.model(m, "SalonOfWits")
	local T = Plan.TRIVIA
	local face = CFrame.lookAt(o + T.screen, o + T.screen + v3(10, 0, 0))
	local screenPart = Kit.part(t, "TriviaScreen", v3(38, 20, 0.3), face, look(rgb(10, 12, 22), Enum.Material.SmoothPlastic, 0.1), SOFT)
	frame(t, face * CFrame.new(0, 0, -0.1), 38, 20, 1.2, GILT)
	Kit.part(t, "ScreenGlow", v3(39, 21, 0.1), face * CFrame.new(0, 0, 0.12), look(rgb(90, 120, 255), Enum.Material.Neon, 0, 0.6), TRIM)
	local board = screen(screenPart, 24, {
		{ name = "Title", size = 0.1, font = Brand.Fonts.bodyBold, colour = rgb(255, 214, 120), text = "LUXURY TRIVIA · THE SALON OF WITS" },
		{ name = "Question", size = 0.3, font = Brand.Fonts.display, colour = rgb(240, 236, 226), text = "Seven questions. Eight podiums. The quickest right answer wins." },
		{ name = "A", size = 0.1, font = Brand.Fonts.bodyBold, colour = rgb(236, 226, 206), text = "" },
		{ name = "B", size = 0.1, font = Brand.Fonts.bodyBold, colour = rgb(236, 226, 206), text = "" },
		{ name = "C", size = 0.1, font = Brand.Fonts.bodyBold, colour = rgb(236, 226, 206), text = "" },
		{ name = "D", size = 0.1, font = Brand.Fonts.bodyBold, colour = rgb(236, 226, 206), text = "" },
		{ name = "Foot", size = 0.09, font = Brand.Fonts.body, colour = rgb(200, 190, 170), text = "Take any podium to play." },
	})
	-- The host's desk under the screen.
	local hd = CFrame.lookAt(o + T.host, o + T.host + v3(10, 0, 0))
	Kit.part(t, "HostDesk", v3(3, 3.6, 8), hd * CFrame.new(0, 1.8, 0), L.blackLacquer)
	Kit.part(t, "HostDeskTop", v3(3.4, 0.2, 8.4), hd * CFrame.new(0, 3.7, 0), GILT, TRIM)
	Kit.part(t, "HostRiser", v3(10, 1, 16), hd * CFrame.new(0, 0.5, -2), BLACK)
	-- Eight podiums in an arc.
	local glows: { BasePart } = {}
	for i = 1, Plan.PODIUMS do
		local cf = Plan.podium(i) + o
		Kit.part(t, "Podium", v3(3.4, 3.6, 2.6), cf * CFrame.new(0, 1.8, 0), L.blackLacquer)
		Kit.part(t, "PodiumTop", v3(3.8, 0.2, 3), cf * CFrame.new(0, 3.7, 0), GILT, TRIM)
		-- (Its glow and number face the guest behind it, and the room.)
		local glow = Kit.part(t, "PodiumGlow", v3(3.2, 0.3, 0.1), cf * CFrame.new(0, 3.2, 1.32), look(rgb(255, 214, 140), Enum.Material.Neon, 0, 0.5), TRIM)
		glow:SetAttribute("Index", i)
		CollectionService:AddTag(glow, "GalaPodium")
		glows[i] = glow
		local plate = Kit.part(t, "PodiumNumber", v3(1.6, 1.6, 0.1), cf * CFrame.new(0, 2, 1.36), INVISIBLE, TRIM)
		Kit.engrave(plate, Enum.NormalId.Back, { { text = tostring(i), size = 0.8, font = Brand.Fonts.display, color = rgb(214, 170, 78) } }, { ppu = 90, lit = false })
		local spot = Kit.part(t, "PodiumStand", v3(3, 0.2, 3), (Plan.podiumStand(i) + o) * CFrame.new(0, 0.1, 0), INVISIBLE, { collide = false, shadow = false })
		spot.CanQuery = true
		prompt(spot, "act", "Play", "Podium " .. i, { Act = "join", What = "trivia" }, 8)
	end
	-- Benches for the room, behind the podiums.
	for k = 0, 5 do
		local z = 30 + k * 11
		bench(t, CFrame.lookAt(o + v3(-62, 0, z), o + v3(-120, 0, z)), "The Salon's bench")
	end
	local sign = CFrame.lookAt(o + v3(-50, 0, 58), o + v3(0, 0, 58))
	Kit.sign(t, "TriviaSign", sign, 5.2, 2.4, {
		{ text = "THE SALON OF WITS", size = 0.36, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "Luxury Trivia: seven questions, quickest right answer wins.", size = 0.42, font = Brand.Fonts.body, color = Brand.Colours.bone },
	}, 3.6)
	return board, glows
end

local function arena(m: Model, o: Vector3): (Board, Folder)
	local a = Kit.model(m, "DailyArena")
	local A = Plan.ARENA
	local c = o + A.centre
	Kit.cylinder(a, "ArenaFloor", 0.24, A.radius * 2, CFrame.new(c + v3(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(24, 18, 30), Enum.Material.Marble, 0.12), { shadow = false })
	Kit.cylinder(a, "ArenaRing", 0.26, A.radius * 2 + 1.6, CFrame.new(c + v3(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT, TRIM)
	Kit.cylinder(a, "ArenaRingGlow", 0.28, A.radius * 2 + 0.4, CFrame.new(c + v3(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(255, 120, 170), Enum.Material.Neon, 0, 0.55), TRIM)
	Kit.cylinder(a, "ArenaInner", 0.25, A.radius * 2 - 1, CFrame.new(c + v3(0, 0.09, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(24, 18, 30), Enum.Material.Marble, 0.12), TRIM)
	-- The golden dais in the middle.
	Kit.cylinder(a, "Dais", 1.2, A.dais * 2, CFrame.new(c + v3(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT)
	Kit.cylinder(a, "DaisTop", 0.1, A.dais * 2 - 1.2, CFrame.new(c + v3(0, 1.22, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(255, 214, 120), Enum.Material.Neon, 0, 0.5), TRIM)
	-- Brass posts round the ring, each with a little flame.
	for k = 1, 16 do
		local ang = k / 16 * math.pi * 2
		local p = c + v3(math.cos(ang) * (A.radius + 1.6), 0, math.sin(ang) * (A.radius + 1.6))
		Kit.post(a, "RingPost", 3.4, 0.4, p, GILT_DEEP, TRIM)
		Kit.ball(a, "RingFlame", 0.6, p + v3(0, 3.7, 0), FLAME, TRIM)
	end
	-- The gate on its east side, where guests join.
	local gate = o + A.gate
	local gf = CFrame.lookAt(gate, gate + v3(10, 0, 0))
	for _, side in { -1, 1 } do
		Kit.part(a, "GatePier", v3(1.6, 12, 1.6), gf * CFrame.new(side * 6, 6, 0), PANEL)
		Kit.part(a, "GatePierCap", v3(2, 0.6, 2), gf * CFrame.new(side * 6, 12.3, 0), GILT, TRIM)
	end
	Kit.part(a, "GateLintel", v3(14, 1.6, 1.6), gf * CFrame.new(0, 12.8, 0), GILT)
	local lect = Kit.part(a, "GateLectern", v3(1.8, 3.6, 1.4), gf * CFrame.new(0, 1.8, -2.2), L.blackLacquer)
	Kit.part(a, "GateLecternTop", v3(2, 0.2, 1.6), gf * CFrame.new(0, 3.7, -2.2), GILT, TRIM)
	prompt(lect, "act", "Take part", "The Daily Arena", { Act = "join", What = "arena" }, 12)
	-- Today's challenge, on the west wall.
	local bf = CFrame.lookAt(o + A.board, o + A.board + v3(10, 0, 0))
	local boardPart = Kit.part(a, "ArenaBoard", v3(30, 14, 0.3), bf, look(rgb(14, 10, 18), Enum.Material.SmoothPlastic, 0.1), SOFT)
	frame(a, bf * CFrame.new(0, 0, -0.1), 30, 14, 1, GILT)
	local board = screen(boardPart, 24, {
		{ name = "Title", size = 0.13, font = Brand.Fonts.bodyBold, colour = rgb(255, 214, 120), text = "THE DAILY ARENA" },
		{ name = "Name", size = 0.24, font = Brand.Fonts.display, colour = rgb(240, 236, 226), text = "" },
		{ name = "How", size = 0.2, font = Brand.Fonts.body, colour = rgb(220, 210, 190), text = "" },
		{ name = "State", size = 0.14, font = Brand.Fonts.bodyBold, colour = rgb(255, 150, 190), text = "" },
		{ name = "Leader", size = 0.13, font = Brand.Fonts.body, colour = rgb(200, 190, 170), text = "" },
	})
	local coins = Kit.folder(a, "Coins")
	for k = 1, Plan.ARENA_COINS do
		local coin = Kit.cylinder(coins, "Coin", 0.3, 1.8, CFrame.new(c + v3(0, -40, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(255, 200, 80), Enum.Material.Neon), TRIM)
		coin.Transparency = 1
		coin:SetAttribute("Index", k)
	end
	return board, coins
end

---------------------------------------------------------------------------------------------------
-- The east wing: the Runway and the Exchange
---------------------------------------------------------------------------------------------------
local function runway(m: Model, o: Vector3): Board
	local r = Kit.model(m, "Runway")
	local R = Plan.RUNWAY
	local S = R.stage
	-- The catwalk: black lacquer edged in light, up from the photographers' pit to the stage.
	Kit.span(r, "Catwalk", o + v3(R.x - R.width / 2, 0, R.fromZ), o + v3(R.x + R.width / 2, R.top, R.toZ), L.blackLacquer)
	for _, side in { -1, 1 } do
		Kit.span(r, "CatwalkLight", o + v3(R.x + side * R.width / 2 - 0.2, R.top - 0.5, R.fromZ), o + v3(R.x + side * R.width / 2 + 0.2, R.top, R.toZ), NEON_GOLD, TRIM)
	end
	Kit.span(r, "CatwalkEnd", o + v3(R.x - R.width / 2, R.top - 0.5, R.fromZ - 0.2), o + v3(R.x + R.width / 2, R.top, R.fromZ + 0.2), NEON_GOLD, TRIM)
	-- The end mark where models pose.
	Kit.cylinder(r, "PoseMark", 0.06, 4, CFrame.new(o + R.finish + v3(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT, TRIM)
	-- The stage and its steps, the backdrop, the models' row.
	Kit.span(r, "Stage", o + v3(S.minX, 0, S.minZ), o + v3(S.maxX, R.top, S.maxZ), L.blackLacquer)
	Kit.span(r, "StageEdge", o + v3(S.minX, R.top - 0.4, S.minZ - 0.2), o + v3(S.maxX, R.top, S.minZ + 0.2), GILT, TRIM)
	for _, x0 in { S.minX, R.x + R.width / 2 + 1 } do
		local x1 = if x0 == S.minX then R.x - R.width / 2 - 1 else S.maxX
		for k = 1, 3 do
			Kit.span(r, "StageStep", o + v3(x0, 0, S.minZ - k * 1.2), o + v3(x1, R.top * (4 - k) / 4, S.minZ - (k - 1) * 1.2), L.blackLacquer)
		end
	end
	local back = CFrame.lookAt(o + v3(R.x, R.top, S.maxZ + 0.6), o + v3(R.x, R.top, 0))
	Kit.part(r, "Backdrop", v3(40, 30, 0.6), back * CFrame.new(0, 15, 0), look(rgb(14, 12, 16), Enum.Material.SmoothPlastic, 0.12), SOFT)
	-- An arch of bulbs round the way out onto the catwalk.
	for k = 0, 24 do
		local a = math.rad(k * 7.5)
		Kit.ball(r, "Bulb", 0.6, (back * CFrame.new(math.cos(a) * 9, 0.6 + math.sin(a) * 15, -0.5)).Position, NEON_GOLD, TRIM)
	end
	Kit.part(r, "ArchOpening", v3(14, 18, 0.2), back * CFrame.new(0, 9, -0.35), look(rgb(150, 110, 255), Enum.Material.Neon, 0, 0.75), TRIM)
	local boardPart = Kit.part(r, "RunwayBoard", v3(24, 8, 0.3), CFrame.lookAt(o + R.board, o + R.board + v3(0, 0, -10)), look(rgb(12, 10, 14), Enum.Material.SmoothPlastic, 0.1), SOFT)
	frame(r, boardPart.CFrame * CFrame.new(0, 0, -0.1), 24, 8, 0.8, GILT)
	local board = screen(boardPart, 30, {
		{ name = "Title", size = 0.18, font = Brand.Fonts.bodyBold, colour = rgb(255, 214, 120), text = "THE RUNWAY" },
		{ name = "Theme", size = 0.34, font = Brand.Fonts.display, colour = rgb(240, 236, 226), text = "The next show" },
		{ name = "State", size = 0.22, font = Brand.Fonts.body, colour = rgb(220, 210, 190), text = "Sign the models' book backstage to walk." },
	})
	-- Spotlights on the catwalk from the stage's top.
	for k, z in { 30, 60 } do
		local rig = Kit.part(r, "RunwaySpotRig", v3(1, 1, 1), CFrame.lookAt(o + v3(R.x + (if k == 1 then -10 else 10), 34, z), o + v3(R.x, R.top, z - 6)), look(rgb(20, 20, 24), Enum.Material.Metal), TRIM)
		Kit.spotLight(rig, Enum.NormalId.Front, 2.4, 50, 30, rgb(255, 236, 210), false)
	end
	-- The models' book, backstage.
	local book = Kit.part(r, "ModelsBook", v3(2, 3.6, 1.6), CFrame.lookAt(o + R.book + v3(0, 1.8, 0), o + R.book + v3(0, 1.8, -10)), L.blackLacquer)
	Kit.part(r, "ModelsBookTop", v3(2.2, 0.2, 1.8), book.CFrame * CFrame.new(0, 1.9, 0), GILT, TRIM)
	prompt(book, "act", "Walk in the next show", "The Runway", { Act = "join", What = "runway" }, 12)
	Kit.sign(r, "RunwaySign", CFrame.lookAt(o + v3(60, 0, 8), o + v3(60, 0, -20)), 5.2, 2.4, {
		{ text = "THE RUNWAY", size = 0.38, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "A themed show: walk, pose, and the room votes for the look.", size = 0.42, font = Brand.Fonts.body, color = Brand.Colours.bone },
	}, 3.6)
	-- Benches for the room down both sides.
	for k = 0, 5 do
		local z = 22 + k * 11
		bench(r, CFrame.lookAt(o + v3(R.x - 13, 0, z), o + v3(R.x, 0, z)), "The Runway's bench")
		bench(r, CFrame.lookAt(o + v3(R.x + 13, 0, z), o + v3(R.x, 0, z)), "The Runway's bench")
	end
	return board
end

local function exchange(m: Model, o: Vector3)
	local e = Kit.model(m, "Exchange")
	for i, at0 in Plan.STANDS do
		local at = o + at0
		Kit.cylinder(e, "Counter", 3.4, 8, CFrame.new(at + v3(0, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.blackLacquer)
		Kit.cylinder(e, "CounterTop", 0.24, 8.6, CFrame.new(at + v3(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT)
		Kit.cylinder(e, "CounterInner", 3.6, 4, CFrame.new(at + v3(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), IVORY, TRIM)
		for k = 1, 4 do
			local a = k / 4 * math.pi * 2 + math.pi / 4
			Kit.post(e, "CanopyPost", 10, 0.35, at + v3(math.cos(a) * 4.6, 0, math.sin(a) * 4.6), GILT_DEEP, TRIM)
		end
		Kit.cylinder(e, "Canopy", 0.6, 11, CFrame.new(at + v3(0, 10.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), CRIMSON)
		Kit.cylinder(e, "CanopyRim", 0.9, 11.4, CFrame.new(at + v3(0, 10, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT, TRIM)
		Kit.ball(e, "CanopyFinial", 1.2, at + v3(0, 11.2, 0), GILT, TRIM)
		-- Scales on the counter: a fair exchange.
		Kit.post(e, "ScalePost", 1.6, 0.2, at + v3(0, 3.6, 0), GILT, TRIM)
		Kit.part(e, "ScaleBeam", v3(2.4, 0.12, 0.12), CFrame.new(at + v3(0, 5.2, 0)), GILT, TRIM)
		for _, dx in { -1.1, 1.1 } do
			Kit.cylinder(e, "ScalePan", 0.08, 0.9, CFrame.new(at + v3(dx, 4.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT, TRIM)
		end
		local hit = Kit.part(e, "Stand", v3(8, 4, 8), CFrame.new(at + v3(0, 2, 0)), INVISIBLE, { collide = false, shadow = false })
		hit.CanQuery = true
		prompt(hit, "panel", "Trade with a guest", "Exchange stand " .. i, { Panel = "exchange" }, 10)
	end
	local bf = CFrame.lookAt(o + Plan.EXCHANGE_BOARD, o + Plan.EXCHANGE_BOARD - v3(10, 0, 0))
	local boardPart = Kit.part(e, "ExchangeBoard", v3(26, 12, 0.3), bf, look(rgb(14, 10, 18), Enum.Material.SmoothPlastic, 0.1), SOFT)
	frame(e, bf * CFrame.new(0, 0, -0.1), 26, 12, 1, GILT)
	screen(boardPart, 24, {
		{ name = "Title", size = 0.16, font = Brand.Fonts.bodyBold, colour = rgb(255, 214, 120), text = "THE EXCHANGE" },
		{ name = "Line", size = 0.26, font = Brand.Fonts.display, colour = rgb(240, 236, 226), text = "Gilt, Gems, brainrots and curios" },
		{ name = "How", size = 0.32, font = Brand.Fonts.body, colour = rgb(220, 210, 190), text = "Both sides see every offer. Nothing changes hands until both confirm the very same trade." },
	})
end

---------------------------------------------------------------------------------------------------
-- Lounges, a champagne bar, and the signs
---------------------------------------------------------------------------------------------------
local function lounges(m: Model, o: Vector3)
	local f = Kit.model(m, "Lounges")
	-- Sofas facing the dance floor, both sides of the nave.
	for _, side in { -1, 1 } do
		for _, z in { -40, -20, 0 } do
			local at = o + v3(side * 36, 0, z)
			Furniture.build("sofa", f, CFrame.lookAt(at, o + v3(0, 0, z)), { model = "chesterfield", colour = rgb(118, 14, 30) }, false)
		end
		Furniture.build("plant", f, CFrame.new(o + v3(side * 40, 0, -60)), { model = "palm" }, false)
		Furniture.build("plant", f, CFrame.new(o + v3(side * 40, 0, 14)), { model = "topiary" }, false)
	end
	-- The champagne bar along the west wing's south wall, and its stools.
	local bar = o + v3(-90, 0, -104)
	local face = CFrame.lookAt(bar, bar + v3(0, 0, 10))
	Kit.part(f, "BarCounter", v3(40, 3.6, 2.6), face * CFrame.new(0, 1.8, 0), L.blackLacquer)
	Kit.part(f, "BarTop", v3(40.6, 0.24, 3.2), face * CFrame.new(0, 3.72, 0), MARBLE, TRIM)
	Kit.part(f, "BarRail", v3(40, 0.2, 0.2), face * CFrame.new(0, 0.6, -1.5), GILT, TRIM)
	Kit.part(f, "BarBack", v3(40, 12, 1), face * CFrame.new(0, 6, 3.6), look(rgb(30, 20, 16), Enum.Material.Wood))
	for k = 1, 3 do
		Kit.part(f, "BarShelf", v3(38, 0.2, 1.2), face * CFrame.new(0, 4 + k * 2.4, 2.8), GILT_DEEP, TRIM)
		for b = -9, 9 do
			Kit.part(f, "Bottle", v3(0.5, 1.3, 0.5), face * CFrame.new(b * 2, 4.85 + k * 2.4, 2.8), look(({ rgb(40, 90, 50), rgb(200, 170, 90), rgb(90, 30, 40) })[(b + k) % 3 + 1], Enum.Material.Glass, 0.2, 0.15), TRIM)
		end
	end
	local barSign = Kit.part(f, "BarSign", v3(14, 1.6, 0.2), face * CFrame.new(0, 11, 3), INVISIBLE, TRIM)
	Kit.engrave(barSign, Enum.NormalId.Front, { { text = "THE CHAMPAGNE BAR", size = 0.8, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 90, lit = false, brightness = 1.4 })
	local barLight = Kit.part(f, "BarGlow", v3(1, 1, 1), face * CFrame.new(0, 9, 1), INVISIBLE, TRIM)
	Kit.pointLight(barLight, 0.9, 30, rgb(255, 200, 140), false)
	for k = -4, 4 do
		local s = face * CFrame.new(k * 4, 0, -2.8)
		Kit.post(f, "StoolPost", 2.6, 0.3, s.Position, GILT_DEEP, TRIM)
		Kit.cylinder(f, "StoolSeat", 0.4, 1.6, s * CFrame.new(0, 2.8, 0) * CFrame.Angles(0, 0, math.rad(90)), CRIMSON)
	end
	-- And a lounge in the east wing's south corner.
	for k, x in { 64, 84, 104 } do
		local at = o + v3(x, 0, -102)
		Furniture.build("sofa", f, CFrame.lookAt(at, at + v3(0, 0, 10)), { model = if k == 2 then "curved" else "chesterfield", colour = rgb(236, 228, 210) }, false)
	end
end

local function signs(m: Model, o: Vector3)
	local s = Kit.model(m, "Signs")
	Kit.sign(s, "WelcomeSign", CFrame.lookAt(o + v3(-12, 0, -86), o + v3(-12, 0, -120)), 6, 3, {
		{ text = "THE GRAND BALLROOM", size = 0.3, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "← The Salon of Wits  ·  The Daily Arena", size = 0.2, font = Brand.Fonts.bodyBold, color = Brand.Colours.bone },
		{ text = "The Runway  ·  The Exchange →", size = 0.2, font = Brand.Fonts.bodyBold, color = Brand.Colours.bone },
		{ text = "Ahead: the Dance Floor, the Gallery and the Hall of Fame", size = 0.18, font = Brand.Fonts.body, color = rgb(214, 200, 176) },
	}, 3.8)
	Kit.sign(s, "ArenaSign", CFrame.lookAt(o + v3(-50, 0, -40), o + v3(0, 0, -40)), 5.2, 2.4, {
		{ text = "THE DAILY ARENA", size = 0.38, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "A new challenge every day. Join at the gate.", size = 0.42, font = Brand.Fonts.body, color = Brand.Colours.bone },
	}, 3.6)
	Kit.sign(s, "ExchangeSign", CFrame.lookAt(o + v3(52, 0, -24), o + v3(0, 0, -24)), 5.2, 2.4, {
		{ text = "THE EXCHANGE", size = 0.38, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "Trade Gilt, Gems, brainrots and curios with any guest.", size = 0.42, font = Brand.Fonts.body, color = Brand.Colours.bone },
	}, 3.6)
end

---------------------------------------------------------------------------------------------------
-- The Flex Studio (Build 81): a black lacquer stage edged in pink neon, the gold mark where a guest
-- stands, the phone on its tripod with a ring light, and the Flex Wall behind, tall as a phone held
-- upright, where the reels go up. Its own lights on the mark.
---------------------------------------------------------------------------------------------------
local NEON_PINK = look(rgb(255, 70, 170), Enum.Material.Neon)
local NEON_ICE = look(rgb(120, 220, 255), Enum.Material.Neon)

local function studio(m: Model, o: Vector3): Board
	local s = Kit.model(m, "FlexStudio")
	local S = FlexPlan.STUDIO
	-- The stage, its neon edge all round.
	Kit.span(s, "Stage", o + v3(S.minX, 0, S.minZ), o + v3(S.maxX, S.top, S.maxZ), L.blackLacquer)
	local e = 0.12
	Kit.span(s, "StageNeon", o + v3(S.minX - e, S.top - 0.3, S.minZ - e), o + v3(S.maxX + e, S.top - 0.06, S.minZ + e), NEON_PINK, TRIM)
	Kit.span(s, "StageNeon", o + v3(S.minX - e, S.top - 0.3, S.maxZ - e), o + v3(S.maxX + e, S.top - 0.06, S.maxZ + e), NEON_PINK, TRIM)
	Kit.span(s, "StageNeon", o + v3(S.minX - e, S.top - 0.3, S.minZ), o + v3(S.minX + e, S.top - 0.06, S.maxZ), NEON_ICE, TRIM)
	Kit.span(s, "StageNeon", o + v3(S.maxX - e, S.top - 0.3, S.minZ), o + v3(S.maxX + e, S.top - 0.06, S.maxZ), NEON_ICE, TRIM)
	-- The gold mark, and its prompt.
	local mark = o + FlexPlan.MARK.Position
	Kit.cylinder(s, "Mark", 0.06, 4.2, CFrame.new(mark + v3(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), GILT, TRIM)
	Kit.cylinder(s, "MarkInner", 0.08, 3.2, CFrame.new(mark + v3(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.blackLacquer, TRIM)
	local markPrompt = Kit.part(s, "MarkPrompt", v3(4, 0.2, 4), CFrame.new(mark + v3(0, 2.4, 0)), INVISIBLE, TRIM)
	prompt(markPrompt, "panel", "Make a reel", "The Flex Studio", { Panel = "flex" }, 10)
	-- The tripod, the phone on it, the ring light behind the phone: all facing the mark.
	local t = o + FlexPlan.TRIPOD + v3(0, S.top, 0)
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		local foot = t + v3(math.cos(a) * 1.4, 0, math.sin(a) * 1.4)
		local top = t + v3(0, 4.2, 0)
		Kit.part(s, "TripodLeg", v3(0.14, (top - foot).Magnitude, 0.14), CFrame.lookAt((foot + top) / 2, top) * CFrame.Angles(math.rad(90), 0, 0), L.blackLacquer, TRIM)
	end
	local aim = CFrame.lookAt(t + v3(0, 4.8, 0), mark + v3(0, 4.2, 0))
	Kit.part(s, "Phone", v3(1.1, 2, 0.16), aim, look(rgb(12, 12, 16), Enum.Material.Glass, 0.3), TRIM)
	local ring = Kit.cylinder(s, "RingLight", 0.24, 5.2, aim * CFrame.new(0, 0, 0.5) * CFrame.Angles(0, math.rad(90), 0), look(rgb(255, 250, 242), Enum.Material.Neon), TRIM)
	Kit.cylinder(s, "RingHole", 0.3, 4.0, aim * CFrame.new(0, 0, 0.5) * CFrame.Angles(0, math.rad(90), 0), L.blackLacquer, TRIM)
	Kit.pointLight(ring, 1.3, 20, rgb(255, 246, 236), false)
	-- Two spotlights on the mark from the stage's front corners.
	for _, x in { -9, 9 } do
		local lamp = Kit.part(s, "StudioLamp", v3(1, 1, 1.4), CFrame.lookAt(o + v3(x, 9, S.minZ + 1), mark + v3(0, 3, 0)), L.blackLacquer, TRIM)
		Kit.spotLight(lamp, Enum.NormalId.Front, 2.2, 30, 40, rgb(255, 214, 236), false)
		Kit.post(s, "LampStand", 9, 0.3, o + v3(x, S.top, S.minZ + 1), L.blackLacquer, TRIM)
	end
	-- The Flex Wall: upright as a phone, black glass framed in pink neon.
	local W = o + FlexPlan.WALL
	local wall = Kit.part(s, "FlexWall", v3(11, 19.5, 0.4), CFrame.lookAt(W + v3(0, 11, 0), W + v3(0, 11, -10)), look(rgb(8, 8, 12), Enum.Material.SmoothPlastic))
	for _, r in { { 0, 9.95, 11.6, 0.4 }, { 0, -9.95, 11.6, 0.4 }, { -5.7, 0, 0.4, 20.3 }, { 5.7, 0, 0.4, 20.3 } } do
		Kit.part(s, "WallNeon", v3(r[3], r[4], 0.5), wall.CFrame * CFrame.new(r[1], r[2], 0), NEON_PINK, TRIM)
	end
	local board = screen(wall, 30, {
		{ name = "Title", size = 0.08, font = Brand.Fonts.display, colour = rgb(255, 120, 200), text = "THE FLEX WALL" },
		{ name = "Live", size = 0.05, font = Brand.Fonts.bodyBold, colour = rgb(255, 214, 120), text = "" },
		{ name = "Top", size = 0.2, font = Brand.Fonts.display, colour = Color3.new(1, 1, 1), text = "" },
		{ name = "TopLikes", size = 0.07, font = Brand.Fonts.bodyBold, colour = rgb(255, 90, 140), text = "" },
		{ name = "Reel2", size = 0.08, font = Brand.Fonts.bodyBold, colour = Brand.Colours.bone, text = "" },
		{ name = "Reel3", size = 0.08, font = Brand.Fonts.bodyBold, colour = Brand.Colours.bone, text = "" },
		{ name = "Reel4", size = 0.08, font = Brand.Fonts.bodyBold, colour = Brand.Colours.bone, text = "" },
		{ name = "Hint", size = 0.045, font = Brand.Fonts.body, colour = rgb(200, 186, 160), text = "Like a reel at the kiosk beside the wall" },
	}, false)
	-- The feed kiosk beside the wall: every reel up there, and a like for each.
	local kiosk = Kit.part(s, "FeedKiosk", v3(2.2, 3.8, 1.2), CFrame.lookAt(o + v3(8.4, S.top + 1.9, 65), o + v3(8.4, S.top + 1.9, 40)), L.blackLacquer)
	Kit.part(s, "KioskScreen", v3(1.8, 1.4, 0.1), kiosk.CFrame * CFrame.new(0, 1, -0.62), NEON_ICE, TRIM)
	prompt(kiosk, "panel", "Like a reel", "The Flex Wall", { Panel = "feed" }, 10)
	-- Its sign at the foot of the stage.
	Kit.sign(s, "FlexSign", CFrame.lookAt(o + v3(-8, 0, S.minZ - 2.5), o + v3(-8, 0, 0)), 5.4, 2.4, {
		{ text = "THE FLEX STUDIO", size = 0.36, font = Brand.Fonts.display, color = rgb(255, 120, 200) },
		{ text = "Stand on the gold mark: shoot a reel of what you own. Others like it on the wall.", size = 0.4, font = Brand.Fonts.body, color = Brand.Colours.bone },
	}, 3.4)
	return board
end

---------------------------------------------------------------------------------------------------
-- The whole hall
---------------------------------------------------------------------------------------------------
function GalaBuild.build(parent: Instance, o: Vector3): Built
	local m = Kit.model(parent, "GrandBallroom")
	shell(m, o)
	colonnades(m, o)
	windows(m, o)
	chandelier(m, o + v3(0, 34, Plan.DANCE.centre.Z), 1.6, 60)
	chandelier(m, o + v3(0, 36, -80), 1.1, 50)
	chandelier(m, o + v3(0, 36, 56), 1.1, 50)
	chandelier(m, o + v3(-88, 36, 58), 1.2, 56)
	chandelier(m, o + v3(-88, 36, -58), 1.2, 56)
	chandelier(m, o + v3(88, 38, 54), 1.2, 56)
	chandelier(m, o + v3(88, 36, -58), 1.2, 56)
	local home = doors(m, o)
	local dj = danceFloor(m, o)
	gallery(m, o)
	terrace(m, o)
	photoSets(m, o)
	local screenBoard, glows = trivia(m, o)
	local arenaBoard, coins = arena(m, o)
	local runwayBoard = runway(m, o)
	exchange(m, o)
	lounges(m, o)
	signs(m, o)
	-- The Luxe Lucky Boxes, in the Entrance Hall (World/LuckyShowroom).
	require(script.Parent.Parent.World.LuckyShowroom).build(m, CFrame.new(o) * Plan.LUCKY, Plan.LUCKY_SCALE)
	local flexWall = studio(m, o)
	return {
		model = m,
		home = home,
		screen = screenBoard,
		runwayBoard = runwayBoard,
		arenaBoard = arenaBoard,
		podiums = glows,
		coins = coins,
		dj = dj,
		flexWall = flexWall,
	}
end

return GalaBuild

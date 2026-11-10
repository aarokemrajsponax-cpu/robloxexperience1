--!strict
-- Steal a Luxe's residence, built once when the house opens (shared/Luxe has the plan): the
-- courtyard with the getaway car and the arch home, then the Garden Hall, the Long Gallery and the
-- Strongroom, each furnished and lit in its own way, with a plinth for every piece. And the pieces
-- themselves (LuxeBuild.piece): big and bright, so they catch the eye across a room and look worth
-- the risk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local LuxePlan = require(ReplicatedStorage.Shared.Luxe)
local Kit = require(script.Parent.Parent.World.Kit)
local Portal = require(script.Parent.Parent.Holidays.Portal)

local LuxeBuild = {}

local L = Kit.Looks
local rgb = Color3.fromRGB
local GOLD = rgb(232, 182, 72)
local H = LuxePlan.HEIGHT
local WALL = 2

local P = HolidayProps.part
local function look(colour: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Kit.Look
	return { color = colour, material = material, reflectance = reflectance, transparency = transparency }
end
local PARQUET = look(rgb(70, 42, 26), Enum.Material.WoodPlanks)
local STEEL = look(rgb(54, 58, 64), Enum.Material.DiamondPlate, 0.1)
local HEDGE = look(rgb(28, 64, 40), Enum.Material.Grass)
local WATER = look(rgb(40, 90, 120), Enum.Material.Glass, 0.3, 0.35)
local CREAM = look(rgb(214, 204, 186), Enum.Material.Marble, 0.05)

LuxeBuild.RARITY_LIGHT = {
	Common = rgb(255, 230, 190),
	Uncommon = rgb(150, 240, 160),
	Rare = rgb(120, 180, 255),
	Epic = rgb(200, 130, 255),
	Legendary = rgb(255, 200, 80),
	Mythic = rgb(255, 110, 140),
} :: { [string]: Color3 }

---------------------------------------------------------------------------------------------------
-- The architecture
---------------------------------------------------------------------------------------------------

-- A wall from (x0, z0) to (x1, z1) on the ground (axis-aligned), `h` tall, with gold trim at its foot
-- and top, leaving out the openings `gaps` ({ from, to } along it).
local function wall(parent: Instance, o: Vector3, x0: number, z0: number, x1: number, z1: number, h: number, face: Kit.Look, gaps: { { number } }?)
	local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
	local a, b = if alongX then math.min(x0, x1) else math.min(z0, z1), if alongX then math.max(x0, x1) else math.max(z0, z1)
	local cuts = table.clone(gaps or {})
	table.sort(cuts, function(p: { number }, q: { number }): boolean
		return p[1] < q[1]
	end)
	local pieces: { { number } } = {}
	local from = a
	for _, g in cuts do
		if g[1] > from then
			table.insert(pieces, { from, g[1] })
		end
		from = math.max(from, g[2])
	end
	if b > from then
		table.insert(pieces, { from, b })
	end
	for _, seg in pieces do
		local lo, hi
		if alongX then
			lo, hi = Vector3.new(seg[1], 0, z0 - WALL / 2), Vector3.new(seg[2], h, z0 + WALL / 2)
		else
			lo, hi = Vector3.new(x0 - WALL / 2, 0, seg[1]), Vector3.new(x0 + WALL / 2, h, seg[2])
		end
		Kit.span(parent, "Wall", o + lo, o + hi, face)
		local trim = { collide = false, query = false, shadow = false }
		Kit.span(parent, "Skirting", o + lo + Vector3.new(-0.08, 0, -0.08), o + Vector3.new(hi.X + 0.08, 1, hi.Z + 0.08), L.brass, trim)
		Kit.span(parent, "Cornice", o + Vector3.new(lo.X - 0.12, h - 0.8, lo.Z - 0.12), o + hi + Vector3.new(0.12, 0, 0.12), L.brass, trim)
	end
	-- Each opening gets a lintel above head height.
	for _, g in cuts do
		local lo, hi
		if alongX then
			lo, hi = Vector3.new(g[1], 12, z0 - WALL / 2), Vector3.new(g[2], h, z0 + WALL / 2)
		else
			lo, hi = Vector3.new(x0 - WALL / 2, 12, g[1]), Vector3.new(x0 + WALL / 2, h, g[2])
		end
		Kit.span(parent, "Lintel", o + lo, o + hi, face)
		Kit.span(parent, "LintelTrim", o + Vector3.new(lo.X - 0.1, 11.6, lo.Z - 0.1), o + Vector3.new(hi.X + 0.1, 12.1, hi.Z + 0.1), L.brass, { collide = false, query = false, shadow = false })
	end
end

local function chandelier(parent: Instance, at: Vector3, colour: Color3?, brightness: number?)
	local m = Kit.model(parent, "Chandelier")
	Kit.post(m, "Chain", 2.2, 0.15, at + Vector3.new(0, 0.6, 0), L.brass, { collide = false, query = false })
	Kit.part(m, "Crown", Vector3.new(4.6, 0.5, 4.6), CFrame.new(at), L.brass, { collide = false, query = false, shadow = false })
	for i = 0, 7 do
		local a = i * math.pi / 4
		local drop = Kit.part(m, "Crystal", Vector3.new(0.35, 1.3, 0.35), CFrame.new(at + Vector3.new(math.cos(a) * 2, -0.8, math.sin(a) * 2)), look(rgb(255, 240, 210), Enum.Material.Glass, 0.3, 0.2), { collide = false, query = false, shadow = false })
		drop.CastShadow = false
	end
	local bulb = Kit.part(m, "Glow", Vector3.new(1.4, 1.4, 1.4), CFrame.new(at + Vector3.new(0, -0.9, 0)), look(rgb(255, 214, 150), Enum.Material.Neon, nil, 0.1), { collide = false, query = false, shadow = false })
	Kit.pointLight(bulb, brightness or 1.6, 46, colour or rgb(255, 214, 160))
end

local function painting(parent: Instance, cf: CFrame, w: number, h: number, canvas: Color3, accent: Color3)
	local m = Kit.model(parent, "Painting")
	Kit.part(m, "Frame", Vector3.new(w + 0.8, h + 0.8, 0.3), cf, L.brass, { collide = false, query = false })
	Kit.part(m, "Canvas", Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, -0.18), look(canvas, Enum.Material.Fabric), { collide = false, query = false })
	-- A suggestion of a picture: a horizon and a sun.
	Kit.part(m, "Land", Vector3.new(w, h * 0.35, 0.06), cf * CFrame.new(0, -h * 0.325, -0.24), look(canvas:Lerp(rgb(0, 0, 0), 0.45), Enum.Material.Fabric), { collide = false, query = false, shadow = false })
	Kit.part(m, "Sun", Vector3.new(h * 0.22, h * 0.22, 0.06), cf * CFrame.new(w * 0.22, h * 0.18, -0.25), look(accent, Enum.Material.Fabric), { collide = false, query = false, shadow = false })
	local lamp = Kit.part(m, "PictureLight", Vector3.new(w * 0.6, 0.3, 0.5), cf * CFrame.new(0, h / 2 + 0.7, -0.5), L.brass, { collide = false, query = false, shadow = false })
	Kit.spotLight(lamp, Enum.NormalId.Bottom, 1.2, 10, 70, rgb(255, 226, 180))
end

local function topiary(parent: Instance, at: Vector3)
	local m = Kit.model(parent, "Topiary")
	Kit.post(m, "Pot", 2, 2.4, at, L.blackLacquer)
	Kit.post(m, "PotRim", 0.3, 2.7, at + Vector3.new(0, 2, 0), L.brass, { collide = false })
	Kit.post(m, "Stem", 2.2, 0.35, at + Vector3.new(0, 2.2, 0), L.walnut, { collide = false })
	Kit.ball(m, "Crown", 3.6, at + Vector3.new(0, 5.6, 0), HEDGE)
end

local function lamppost(parent: Instance, at: Vector3)
	local m = Kit.model(parent, "Lamp")
	Kit.post(m, "Post", 9, 0.6, at, L.blackLacquer)
	local head = Kit.part(m, "Lantern", Vector3.new(1.4, 1.8, 1.4), CFrame.new(at + Vector3.new(0, 9.9, 0)), L.glassWarm, { collide = false, shadow = false })
	Kit.pointLight(head, 1.4, 34, rgb(255, 206, 150))
	Kit.part(m, "Cap", Vector3.new(1.8, 0.4, 1.8), CFrame.new(at + Vector3.new(0, 11, 0)), L.brass, { collide = false })
end

-- The getaway car: a long black limousine with gold trim, side on, its boot open for the haul.
local function car(parent: Instance, o: Vector3)
	local m = Kit.model(parent, "GetawayCar")
	local cf = CFrame.new(o) * LuxePlan.Car
	local paint = look(rgb(12, 12, 14), Enum.Material.SmoothPlastic, 0.25)
	Kit.part(m, "Body", Vector3.new(22, 2.8, 7.4), cf * CFrame.new(0, 2.4, 0), paint)
	Kit.part(m, "Cabin", Vector3.new(12, 2.4, 6.8), cf * CFrame.new(-1, 4.9, 0), paint)
	Kit.part(m, "Glass", Vector3.new(12.2, 1.6, 6.9), cf * CFrame.new(-1, 5.1, 0), L.smokedGlass, { collide = false })
	Kit.part(m, "TrimLine", Vector3.new(22.2, 0.25, 7.5), cf * CFrame.new(0, 3.3, 0), L.brass, { collide = false, shadow = false })
	Kit.part(m, "Grille", Vector3.new(0.3, 1.6, 4.2), cf * CFrame.new(11.1, 2.5, 0), L.brass, { collide = false })
	for _, side in { -1.4, 1.4 } do
		local lamp = Kit.part(m, "Headlamp", Vector3.new(0.3, 0.8, 1.2), cf * CFrame.new(11.15, 2.9, side * 2), look(rgb(255, 246, 220), Enum.Material.Neon), { collide = false, shadow = false })
		Kit.spotLight(lamp, Enum.NormalId.Right, 2, 40, 45, rgb(255, 240, 210))
		Kit.part(m, "Taillamp", Vector3.new(0.3, 0.6, 1.2), cf * CFrame.new(-11.15, 2.9, side * 2), look(rgb(255, 40, 50), Enum.Material.Neon), { collide = false, shadow = false })
	end
	for _, wx in { -7, 7 } do
		for _, wz in { -3.5, 3.5 } do
			Kit.cylinder(m, "Wheel", 1.2, 3, cf * CFrame.new(wx, 1.5, wz) * CFrame.Angles(0, math.rad(90), 0), look(rgb(20, 20, 22), Enum.Material.Rubber))
			Kit.cylinder(m, "Hub", 1.3, 1.6, cf * CFrame.new(wx, 1.5, wz) * CFrame.Angles(0, math.rad(90), 0), L.brass, { collide = false })
		end
	end
	-- The open boot, glowing: where the haul goes.
	local boot = Kit.part(m, "Boot", Vector3.new(5, 0.4, 6.6), cf * CFrame.new(-8.5, 3.9, 0), look(GOLD, Enum.Material.Neon, nil, 0.25), { collide = false, shadow = false })
	Kit.pointLight(boot, 1.6, 18, GOLD)
	HolidayProps.sparkle(boot, GOLD, 8, 0.5)
	-- The bank: a ring of gold light on the paving round the car, and a sign over it.
	local b = LuxePlan.Bank
	local ring = look(GOLD, Enum.Material.Neon, nil, 0.35)
	local y = 0.06
	local glow = { collide = false, query = false, shadow = false }
	Kit.span(m, "BankEdge", o + Vector3.new(b.minX, 0, b.minZ), o + Vector3.new(b.maxX, y, b.minZ + 0.4), ring, glow)
	Kit.span(m, "BankEdge", o + Vector3.new(b.minX, 0, b.maxZ - 0.4), o + Vector3.new(b.maxX, y, b.maxZ), ring, glow)
	Kit.span(m, "BankEdge", o + Vector3.new(b.minX, 0, b.minZ), o + Vector3.new(b.minX + 0.4, y, b.maxZ), ring, glow)
	Kit.span(m, "BankEdge", o + Vector3.new(b.maxX - 0.4, 0, b.minZ), o + Vector3.new(b.maxX, y, b.maxZ), ring, glow)
	local sign = Kit.part(m, "BankSign", Vector3.new(14, 3, 0.4), CFrame.lookAt(o + Vector3.new(0, 12, -96.5), o + Vector3.new(0, 12, 0)), L.blackLacquer, { collide = false })
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "BANK YOUR HAUL", size = 0.5, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "walk up to the car", size = 0.3, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 60, lit = false, brightness = 1.6, maxDistance = 220 })
	Kit.post(m, "SignPost", 10.5, 0.4, o + Vector3.new(-6.6, 0, -96.5), L.brass)
	Kit.post(m, "SignPost", 10.5, 0.4, o + Vector3.new(6.6, 0, -96.5), L.brass)
end

-- A plinth for a piece: black marble with a brass top and a brass number plate.
local function plinth(parent: Instance, o: Vector3, spot: LuxePlan.Spot): BasePart
	local m = Kit.model(parent, "Plinth" .. spot.id)
	local at = o + spot.at
	local grand = spot.fixed ~= nil
	local w = if grand then 5 else 3.4
	Kit.part(m, "Base", Vector3.new(w + 0.8, 0.5, w + 0.8), CFrame.new(at + Vector3.new(0, 0.25, 0)), L.blackMarble)
	Kit.part(m, "Column", Vector3.new(w, 3, w), CFrame.new(at + Vector3.new(0, 2, 0)), if grand then CREAM else L.blackMarble)
	local top = Kit.part(m, "Top", Vector3.new(w + 0.5, 0.35, w + 0.5), CFrame.new(at + Vector3.new(0, 3.65, 0)), L.brass)
	top:SetAttribute("SpotId", spot.id)
	if grand then
		-- The Crown Jewel's own: under a glass dome's frame, with velvet ropes round it.
		for i = 0, 5 do
			local a = i * math.pi / 3
			local p = at + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
			Kit.post(m, "Stanchion", 3, 0.3, p, L.brass)
			Kit.ball(m, "StanchionTop", 0.6, p + Vector3.new(0, 3.2, 0), L.brass, { collide = false })
		end
		Kit.part(m, "Carpet", Vector3.new(16, 0.08, 16), CFrame.new(at + Vector3.new(0, 0.04, 0)), L.carpet, { collide = false, query = false })
	end
	return top
end

---------------------------------------------------------------------------------------------------
-- The pieces
---------------------------------------------------------------------------------------------------
local function gold(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = P(parent, name, size, cf, GOLD, Enum.Material.Metal)
	p.Reflectance = 0.25
	return p
end

local BUILDERS: { [string]: (m: Model, cf: CFrame, piece: LuxePlan.Piece) -> () } = {
	watch = function(m, cf)
		local face = cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(90))
		P(m, "Case", Vector3.new(0.6, 3.2, 3.2), face, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
		P(m, "Dial", Vector3.new(0.65, 2.7, 2.7), face, rgb(250, 246, 236), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		P(m, "Hour", Vector3.new(0.7, 0.9, 0.18), cf * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, 0, math.rad(25)), rgb(20, 20, 24))
		P(m, "Minute", Vector3.new(0.7, 1.2, 0.12), cf * CFrame.new(0.3, 1.6, 0) * CFrame.Angles(0, 0, math.rad(-60)), rgb(20, 20, 24))
		gold(m, "Crown", Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0, 3.55, 0))
		gold(m, "Bow", Vector3.new(0.25, 1, 1), cf * CFrame.new(0, 4.1, 0))
	end,
	pearls = function(m, cf)
		for i = 0, 15 do
			local a = i * math.pi / 8
			HolidayProps.ball(m, "Pearl", 0.55, (cf * CFrame.new(math.cos(a) * 1.5, 0.6 + math.sin(a) * 1.5 + 1.5, 0)).Position, rgb(246, 240, 232), Enum.Material.SmoothPlastic)
		end
		HolidayProps.ball(m, "Pendant", 0.9, (cf * CFrame.new(0, 0.5, 0)).Position, rgb(120, 200, 255), Enum.Material.Glass)
	end,
	cash = function(m, cf)
		for i = 0, 3 do
			local stack = cf * CFrame.new(0, 0.45 + i * 0.75, 0) * CFrame.Angles(0, math.rad(i * 9), 0)
			P(m, "Notes", Vector3.new(3, 0.7, 1.5), stack, rgb(222, 206, 160), Enum.Material.Fabric)
			P(m, "Band", Vector3.new(0.5, 0.75, 1.55), stack, GOLD, Enum.Material.Metal)
		end
	end,
	candelabra = function(m, cf)
		local silver = rgb(214, 220, 228)
		P(m, "Foot", Vector3.new(0.5, 1.6, 1.6), cf * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), silver, Enum.Material.Metal, Enum.PartType.Cylinder)
		P(m, "Stem", Vector3.new(2.8, 0.35, 0.35), cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), silver, Enum.Material.Metal, Enum.PartType.Cylinder)
		P(m, "Arms", Vector3.new(3.4, 0.25, 0.25), cf * CFrame.new(0, 2.9, 0), silver, Enum.Material.Metal)
		for _, x in { -1.6, 0, 1.6 } do
			P(m, "Candle", Vector3.new(1, 0.35, 0.35), cf * CFrame.new(x, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(250, 244, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			P(m, "Flame", Vector3.new(0.3, 0.45, 0.3), cf * CFrame.new(x, 4.2, 0), rgb(255, 190, 90), Enum.Material.Neon)
		end
	end,
	goldBar = function(m, cf)
		gold(m, "Bar", Vector3.new(3.2, 1.1, 1.6), cf * CFrame.new(0, 0.55, 0))
		gold(m, "Top", Vector3.new(2.6, 0.3, 1.1), cf * CFrame.new(0, 1.2, 0))
	end,
	handbag = function(m, cf)
		local leather = rgb(150, 30, 50)
		P(m, "Bag", Vector3.new(3, 2.2, 1.3), cf * CFrame.new(0, 1.1, 0), leather, Enum.Material.Leather)
		P(m, "Flap", Vector3.new(3.05, 0.9, 1.35), cf * CFrame.new(0, 1.85, 0), leather:Lerp(rgb(0, 0, 0), 0.2), Enum.Material.Leather)
		gold(m, "Clasp", Vector3.new(0.5, 0.4, 0.2), cf * CFrame.new(0, 1.5, -0.7))
		gold(m, "Handle", Vector3.new(0.2, 1.4, 0.2), cf * CFrame.new(-0.9, 2.9, 0) * CFrame.Angles(0, 0, math.rad(-30)))
		gold(m, "Handle", Vector3.new(0.2, 1.4, 0.2), cf * CFrame.new(0.9, 2.9, 0) * CFrame.Angles(0, 0, math.rad(30)))
	end,
	ring = function(m, cf)
		P(m, "Cushion", Vector3.new(2.6, 0.7, 2.6), cf * CFrame.new(0, 0.35, 0), rgb(60, 14, 30), Enum.Material.Fabric)
		P(m, "Band", Vector3.new(0.5, 2.2, 2.2), cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, math.rad(90), 0), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
		local gem = P(m, "Diamond", Vector3.new(1.3, 1.3, 1.3), cf * CFrame.new(0, 3.1, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)), rgb(220, 240, 255), Enum.Material.Glass)
		gem.Reflectance = 0.4
	end,
	painting = function(m, cf)
		local frame = cf * CFrame.new(0, 2.3, 0)
		gold(m, "Easel", Vector3.new(0.3, 4.6, 0.3), cf * CFrame.new(0, 2.3, 0.6))
		P(m, "Frame", Vector3.new(3.8, 3, 0.3), frame, GOLD, Enum.Material.Metal)
		P(m, "Canvas", Vector3.new(3.2, 2.4, 0.1), frame * CFrame.new(0, 0, -0.18), rgb(60, 90, 130), Enum.Material.Fabric)
		P(m, "Hills", Vector3.new(3.2, 0.9, 0.06), frame * CFrame.new(0, -0.75, -0.24), rgb(50, 90, 50), Enum.Material.Fabric)
		P(m, "Sun", Vector3.new(0.7, 0.7, 0.06), frame * CFrame.new(0.8, 0.5, -0.25), rgb(255, 210, 120), Enum.Material.Fabric)
	end,
	statuette = function(m, cf, piece)
		local c = if piece.curio then CurioList.byId[piece.curio] else nil
		gold(m, "Pedestal", Vector3.new(2.4, 0.6, 2.4), cf * CFrame.new(0, 0.3, 0))
		local medal = P(m, "Medallion", Vector3.new(0.5, 3.2, 3.2), cf * CFrame.new(0, 2.3, 0) * CFrame.Angles(0, math.rad(90), 0), if c then c.colour else GOLD, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		gold(m, "Rim", Vector3.new(0.45, 3.6, 3.6), cf * CFrame.new(0, 2.3, 0) * CFrame.Angles(0, math.rad(90), 0))
		for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
			local g = Instance.new("SurfaceGui")
			g.Face = face
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 60
			g.LightInfluence = 0
			g.Parent = medal
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Size = UDim2.fromScale(1, 1)
			t.Text = piece.glyph
			t.TextScaled = true
			t.Parent = g
		end
	end,
	bullion = function(m, cf)
		local rows = { { 3, 0 }, { 2, 1 }, { 1, 2 } }
		for _, row in rows do
			local n, level = row[1], row[2]
			for i = 1, n do
				local x = (i - (n + 1) / 2) * 1.7
				gold(m, "Bar", Vector3.new(1.5, 0.75, 3), cf * CFrame.new(x, 0.4 + level * 0.78, 0))
			end
		end
	end,
	tiara = function(m, cf)
		P(m, "Cushion", Vector3.new(3, 0.8, 3), cf * CFrame.new(0, 0.4, 0), rgb(40, 20, 70), Enum.Material.Fabric)
		P(m, "Band", Vector3.new(0.4, 2.6, 2.6), cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(230, 232, 238), Enum.Material.Metal, Enum.PartType.Cylinder)
		for i = -2, 2 do
			local h = 1.6 - math.abs(i) * 0.35
			P(m, "Spire", Vector3.new(0.25, h, 0.25), cf * CFrame.new(i * 0.5, 1.4 + h / 2, -0.9), rgb(230, 232, 238), Enum.Material.Metal)
			local gem = P(m, "Gem", Vector3.new(0.45, 0.45, 0.45), cf * CFrame.new(i * 0.5, 1.5 + h, -0.9), if i == 0 then rgb(120, 200, 255) else rgb(255, 120, 160), Enum.Material.Glass, Enum.PartType.Ball)
			gem.Reflectance = 0.3
		end
	end,
	egg = function(m, cf)
		gold(m, "Stand", Vector3.new(1.8, 0.5, 1.8), cf * CFrame.new(0, 0.25, 0))
		local shell = HolidayProps.ellipsoid(m, "Egg", Vector3.new(2.4, 3.2, 2.4), cf * CFrame.new(0, 2.1, 0), rgb(180, 40, 80), Enum.Material.SmoothPlastic)
		shell.Reflectance = 0.2
		for i = 0, 5 do
			local a = i * math.pi / 3
			gold(m, "Filigree", Vector3.new(0.15, 3.1, 0.15), cf * CFrame.new(math.cos(a) * 1.15, 2.1, math.sin(a) * 1.15))
		end
		P(m, "Jewel", Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, 3.8, 0), rgb(120, 255, 200), Enum.Material.Glass, Enum.PartType.Ball)
	end,
	crownJewel = function(m, cf)
		P(m, "Cushion", Vector3.new(4, 1, 4), cf * CFrame.new(0, 0.5, 0), rgb(110, 14, 40), Enum.Material.Fabric)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				gold(m, "Tassel", Vector3.new(0.4, 0.8, 0.4), cf * CFrame.new(sx * 1.9, 0.3, sz * 1.9))
			end
		end
		local gem = P(m, "Diamond", Vector3.new(3, 3, 3), cf * CFrame.new(0, 3, 0) * CFrame.Angles(math.rad(45), math.rad(20), math.rad(45)), rgb(210, 236, 255), Enum.Material.Glass)
		gem.Reflectance = 0.5
		local core = P(m, "Core", Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(0, 3, 0), rgb(255, 255, 255), Enum.Material.Neon, Enum.PartType.Ball)
		core.Transparency = 0.4
		HolidayProps.sparkle(core, rgb(200, 230, 255), 14, 0.7)
	end,
}

-- Builds a piece on top of the plinth `top`. Its root carries the prompt to take it; its light is
-- the colour of its rarity. Returns the model.
function LuxeBuild.piece(parent: Instance, top: BasePart, piece: LuxePlan.Piece, spotId: number): Model
	local m = Instance.new("Model")
	m.Name = "Piece"
	local base = CFrame.new(top.CFrame.Position + Vector3.new(0, top.Size.Y / 2, 0))
	local root = P(m, "Root", Vector3.new(3, 3, 3), base * CFrame.new(0, 1.5, 0), rgb(255, 255, 255))
	root.Transparency = 1
	m.PrimaryPart = root
	local build = BUILDERS[piece.look] or BUILDERS.goldBar
	build(m, base, piece)
	local colour = LuxeBuild.RARITY_LIGHT[piece.rarity] or GOLD
	Kit.pointLight(root, if piece.rarity == "Mythic" then 2.4 else 1.3, if piece.rarity == "Mythic" then 26 else 14, colour)
	if piece.rarity == "Legendary" or piece.rarity == "Mythic" or piece.rarity == "Epic" then
		HolidayProps.sparkle(root, colour, if piece.rarity == "Mythic" then 10 else 4, 0.5)
	end
	m:SetAttribute("SpotId", spotId)
	m:SetAttribute("Piece", piece.id)
	m:SetAttribute("Rarity", piece.rarity)
	m:SetAttribute("Worth", piece.worth)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Take"
	prompt.ActionText = "Take it"
	prompt.ObjectText = piece.name .. "  ·  " .. piece.rarity .. "  ·  " .. Fortune.format(piece.worth)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = if piece.rarity == "Mythic" then 1.2 elseif piece.wing >= 3 then 0.6 else 0.35
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = root
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------------------------------
-- The whole residence
---------------------------------------------------------------------------------------------------
export type Built = { root: Model, tops: { [number]: BasePart }, pieces: Folder, guards: Folder, homeArch: BasePart? }

function LuxeBuild.build(parent: Instance, o: Vector3, goHome: (player: Player) -> ()): Built
	local root = Kit.model(parent, "StealALuxe")
	root:SetAttribute("Attraction", "luxe")
	local arch = Kit.model(root, "Architecture")

	-- The ground, the courtyard's paving and its low walls, hedges and lamps.
	Kit.span(arch, "Ground", o + Vector3.new(-90, -2, -160), o + Vector3.new(90, 0, 150), L.wetStone)
	local c = LuxePlan.Courtyard
	Kit.span(arch, "Paving", o + Vector3.new(c.minX, 0, c.minZ), o + Vector3.new(c.maxX, 0.1, c.maxZ), L.blackMarble, { collide = false })
	for _, x in { c.minX, c.maxX } do
		Kit.span(arch, "CourtWall", o + Vector3.new(x - 1, 0, c.minZ), o + Vector3.new(x + 1, 4, c.maxZ), L.facadeTrim)
		Kit.span(arch, "CourtWallCap", o + Vector3.new(x - 1.3, 4, c.minZ), o + Vector3.new(x + 1.3, 4.4, c.maxZ), L.brass, { collide = false })
		for z = c.minZ + 8, c.maxZ - 8, 14 do
			Kit.span(arch, "Hedge", o + Vector3.new(x - (if x < 0 then -2 else 6), 0, z - 4), o + Vector3.new(x + (if x < 0 then 6 else -2), 3, z + 4), HEDGE)
		end
	end
	Kit.span(arch, "CourtWallSouth", o + Vector3.new(c.minX, 0, c.minZ - 1), o + Vector3.new(-8, 4, c.minZ + 1), L.facadeTrim)
	Kit.span(arch, "CourtWallSouth", o + Vector3.new(8, 0, c.minZ - 1), o + Vector3.new(c.maxX, 4, c.minZ + 1), L.facadeTrim)
	for _, at in { Vector3.new(-30, 0, -128), Vector3.new(30, 0, -128), Vector3.new(-30, 0, -80), Vector3.new(30, 0, -80), Vector3.new(-14, 0, -76), Vector3.new(14, 0, -76) } do
		lamppost(arch, o + at)
	end
	car(arch, o)

	-- The residence: its facade, walls and floors, and a ceiling over each wing.
	local F = L.facade
	wall(arch, o, -60, -70, 60, -70, H, F, { { LuxePlan.FrontDoor.minX, LuxePlan.FrontDoor.maxX } })
	wall(arch, o, -60, -70, -60, 70, H, L.wall)
	wall(arch, o, 60, -70, 60, 70, H, L.wall)
	wall(arch, o, -60, 0, 60, 0, H, L.wall, { { LuxePlan.Doors[1][1], LuxePlan.Doors[1][2] }, { LuxePlan.Doors[2][1], LuxePlan.Doors[2][2] } })
	wall(arch, o, -60, 70, 60, 70, H, L.wall, { { LuxePlan.Doors[3][1], LuxePlan.Doors[3][2] } })
	wall(arch, o, -40, 70, -40, 130, H, STEEL)
	wall(arch, o, 40, 70, 40, 130, H, STEEL)
	wall(arch, o, -40, 130, 40, 130, H, STEEL)
	wall(arch, o, -4, 10, -4, 60, H - 4, look(rgb(40, 16, 24), Enum.Material.Fabric))
	wall(arch, o, 4, 10, 4, 60, H - 4, look(rgb(40, 16, 24), Enum.Material.Fabric))
	-- The front door's grand surround, and the name over it.
	Kit.span(arch, "DoorSurround", o + Vector3.new(-8, 0, -72), o + Vector3.new(-6, 14, -70.5), L.brass)
	Kit.span(arch, "DoorSurround", o + Vector3.new(6, 0, -72), o + Vector3.new(8, 14, -70.5), L.brass)
	local name = Kit.part(arch, "NameBoard", Vector3.new(22, 3.4, 0.4), CFrame.lookAt(o + Vector3.new(0, 15.4, -71.4), o + Vector3.new(0, 15.4, -200)), L.blackLacquer, { collide = false })
	Kit.engrave(name, Enum.NormalId.Front, {
		{ text = "STEAL A LUXE", size = 0.6, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "carry out what you can · bank it at the car", size = 0.26, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 50, lit = false, brightness = 1.6, maxDistance = 260 })
	-- Floors.
	Kit.span(arch, "GardenFloor", o + Vector3.new(-59, 0, -69), o + Vector3.new(59, 0.2, -1), CREAM)
	Kit.span(arch, "GalleryFloor", o + Vector3.new(-59, 0, 1), o + Vector3.new(59, 0.2, 69), PARQUET)
	Kit.span(arch, "StrongFloor", o + Vector3.new(-39, 0, 71), o + Vector3.new(39, 0.2, 129), L.blackMarble)
	Kit.span(arch, "Runner", o + Vector3.new(-3, 0.2, -69), o + Vector3.new(3, 0.25, -1), L.carpet, { collide = false, query = false })
	-- Ceilings.
	Kit.span(arch, "Ceiling", o + Vector3.new(-61, H, -71), o + Vector3.new(61, H + 1, 71), L.blackLacquer)
	Kit.span(arch, "Ceiling", o + Vector3.new(-41, H, 71), o + Vector3.new(41, H + 1, 131), L.blackLacquer)

	-- The Garden Hall: the fountain, topiaries, chandeliers.
	local fountain = Kit.model(arch, "Fountain")
	local fc = o + Vector3.new(0, 0, -35)
	Kit.post(fountain, "Basin", 1.6, 18, fc, CREAM)
	Kit.post(fountain, "Water", 0.2, 16.4, fc + Vector3.new(0, 1.45, 0), WATER, { collide = false })
	Kit.post(fountain, "Column", 5, 2, fc, CREAM)
	Kit.post(fountain, "Bowl", 0.8, 6, fc + Vector3.new(0, 5, 0), CREAM)
	local statue = Kit.ball(fountain, "GoldOrb", 2.6, fc + Vector3.new(0, 7.2, 0), L.brass)
	Kit.pointLight(statue, 1, 16, rgb(255, 214, 150))
	for _, at in { Vector3.new(-56, 0, -66), Vector3.new(56, 0, -66), Vector3.new(-56, 0, -4), Vector3.new(56, 0, -4), Vector3.new(-26, 0, -66), Vector3.new(26, 0, -66) } do
		topiary(arch, o + at)
	end
	for _, at in { Vector3.new(-30, H - 2, -48), Vector3.new(30, H - 2, -48), Vector3.new(-30, H - 2, -20), Vector3.new(30, H - 2, -20), Vector3.new(0, H - 2, -60) } do
		chandelier(arch, o + at)
	end
	-- The Long Gallery: paintings down every wall, a chandelier over each gallery.
	local hues = { rgb(120, 40, 50), rgb(40, 70, 110), rgb(60, 90, 50), rgb(110, 80, 40), rgb(70, 50, 110) }
	local k = 0
	for z = 12, 60, 12 do
		k += 1
		local hue = hues[(k - 1) % #hues + 1]
		painting(arch, CFrame.lookAt(o + Vector3.new(-58.7, 8, z), o + Vector3.new(0, 8, z)), 5, 3.8, hue, rgb(255, 210, 140))
		painting(arch, CFrame.lookAt(o + Vector3.new(58.7, 8, z + 6), o + Vector3.new(0, 8, z + 6)), 5, 3.8, hues[k % #hues + 1], rgb(255, 230, 190))
		painting(arch, CFrame.lookAt(o + Vector3.new(-5.3, 7, z + 3), o + Vector3.new(-30, 7, z + 3)), 4, 3, hues[(k + 1) % #hues + 1], rgb(255, 200, 120))
		painting(arch, CFrame.lookAt(o + Vector3.new(5.3, 7, z + 3), o + Vector3.new(30, 7, z + 3)), 4, 3, hues[(k + 2) % #hues + 1], rgb(240, 220, 160))
	end
	for _, at in { Vector3.new(-32, H - 2, 22), Vector3.new(-32, H - 2, 50), Vector3.new(32, H - 2, 22), Vector3.new(32, H - 2, 50) } do
		chandelier(arch, o + at, rgb(255, 222, 180), 1.4)
	end
	-- The Strongroom: steel, stacks of gold behind bars, a cold white light.
	for _, x in { -36, 36 } do
		for z = 76, 124, 12 do
			local stack = Kit.model(arch, "GoldStack")
			for i = 0, 2 do
				Kit.part(stack, "Bar", Vector3.new(1.6, 0.8, 3), CFrame.new(o + Vector3.new(x + (if x < 0 then 1 else -1) * (i % 2) * 0.4, 0.6 + i * 0.85, z)), L.brass, { collide = false })
			end
			for b = -1, 1 do
				Kit.post(arch, "Bar", 9, 0.25, o + Vector3.new(x + (if x < 0 then 2.4 else -2.4), 0, z + b * 1.4), STEEL, { collide = false })
			end
		end
	end
	for _, at in { Vector3.new(0, H - 2, 84), Vector3.new(0, H - 2, 112), Vector3.new(-22, H - 2, 98), Vector3.new(22, H - 2, 98) } do
		chandelier(arch, o + at, rgb(220, 236, 255), 1.5)
	end
	-- The wings' names, over each doorway as you go in.
	type Sign = { name: string, at: Vector3, toward: Vector3 }
	local signs: { Sign } = {
		{ name = LuxePlan.Wings[1].name, at = Vector3.new(0, 13.6, -68.6), toward = Vector3.new(0, 13.6, 0) },
		{ name = LuxePlan.Wings[2].name, at = Vector3.new(-35, 13.6, 1.4), toward = Vector3.new(-35, 13.6, 40) },
		{ name = LuxePlan.Wings[2].name, at = Vector3.new(35, 13.6, 1.4), toward = Vector3.new(35, 13.6, 40) },
		{ name = LuxePlan.Wings[3].name, at = Vector3.new(0, 13.6, 71.4), toward = Vector3.new(0, 13.6, 100) },
	}
	for _, sign in signs do
		local board = Kit.part(arch, "WingSign", Vector3.new(12, 1.6, 0.2), CFrame.lookAt(o + sign.at, o + sign.toward), L.blackLacquer, { collide = false })
		Kit.engrave(board, Enum.NormalId.Front, { { text = string.upper(sign.name), size = 0.7, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 60, lit = false, brightness = 1.4 })
	end

	-- The plinths.
	local tops: { [number]: BasePart } = {}
	local plinths = Kit.folder(root, "Plinths")
	for _, spot in LuxePlan.Spots do
		tops[spot.id] = plinth(plinths, o, spot)
	end
	local pieces = Kit.folder(root, "Pieces")
	local guards = Kit.folder(root, "Guards")

	-- The arch home, at the courtyard's gate.
	local homeArch: BasePart? = nil
	local ok, err = pcall(function()
		homeArch = Portal.build(root, CFrame.new(o) * LuxePlan.HomeArch, "Steal a Luxe", goHome)
	end)
	if not ok then
		warn("[Maison] Steal a Luxe's arch home couldn't be built: " .. tostring(err))
	end
	return { root = root, tops = tops, pieces = pieces, guards = guards, homeArch = homeArch }
end

return LuxeBuild

--!strict
-- Steal a Luxe's residence, built once when the house opens (shared/Luxe has the plan): the
-- courtyard with the getaway car and the arch home, then the Garden Hall, the Long Gallery and the
-- Strongroom, each furnished and lit in its own way, with a plinth for every piece; and (Build 78)
-- the Drop Room with its loft and helipad, the Garage with its van, the Secret Stash, the cameras
-- and the Strongroom's laser grid. And the pieces themselves (LuxeBuild.piece): big and bright, so
-- they catch the eye across a room and look worth the risk.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local BrainrotFigure = require(ReplicatedStorage.Shared.BrainrotFigure)
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
	Exclusive = rgb(110, 255, 225),
	Limited = rgb(255, 72, 96),
} :: { [string]: Color3 }

-- Street luxury (Build 78): dark concrete, graphite, black chrome and brushed steel, lit by neon,
-- with the stud texture kept for what's on show (pedestals, a feature wall, the runway).
local CONCRETE = look(rgb(64, 66, 70), Enum.Material.Concrete)
local GRAPHITE = look(rgb(30, 31, 35), Enum.Material.SmoothPlastic, 0.04)
local BLACK_CHROME = look(rgb(22, 22, 26), Enum.Material.Metal, 0.35)
local BRUSHED = look(rgb(150, 154, 162), Enum.Material.Metal, 0.12)
local PINK = rgb(255, 60, 170)
local CYAN = rgb(70, 220, 255)
local LIME = rgb(190, 255, 70)
local SOFT = { collide = false, query = false, shadow = false }

-- A part with the stud texture on its faces (Plastic, so the studs show): the house's mark on
-- what's displayed.
local function studs(parent: Instance, name: string, a: Vector3, b: Vector3, colour: Color3, opts: { [string]: any }?): Part
	local p = Kit.span(parent, name, a, b, look(colour, Enum.Material.Plastic), opts)
	p.TopSurface = Enum.SurfaceType.Studs
	p.FrontSurface = Enum.SurfaceType.Studs
	p.BackSurface = Enum.SurfaceType.Studs
	p.LeftSurface = Enum.SurfaceType.Studs
	p.RightSurface = Enum.SurfaceType.Studs
	return p
end

local function neonStrip(parent: Instance, a: Vector3, b: Vector3, colour: Color3, light: number?): Part
	local p = Kit.span(parent, "NeonStrip", a, b, look(colour, Enum.Material.Neon), SOFT)
	if light then
		Kit.pointLight(p, light, 16, colour)
	end
	return p
end

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
	local bulb = Kit.part(m, "Glow", Vector3.new(1.1, 1.1, 1.1), CFrame.new(at + Vector3.new(0, -0.9, 0)), look(rgb(255, 214, 150), Enum.Material.Neon, nil, 0.35), { collide = false, query = false, shadow = false })
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		Kit.part(m, "Candle", Vector3.new(0.22, 0.5, 0.22), CFrame.new(at + Vector3.new(math.cos(a) * 1.7, 0.5, math.sin(a) * 1.7)), look(rgb(255, 226, 180), Enum.Material.Neon, nil, 0.2), { collide = false, query = false, shadow = false })
	end
	Kit.pointLight(bulb, brightness or 1.15, 42, colour or rgb(255, 214, 160))
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
	local paint = look(rgb(10, 10, 13), Enum.Material.SmoothPlastic, 0.35)
	local chrome = look(rgb(214, 218, 226), Enum.Material.Metal, 0.45)
	local soft = { collide = false, shadow = false }
	-- The body: long and low, the hood falling to a brass grille, the roof over a band of smoked
	-- glass with its pillars, chrome bumpers and running boards, a gold pinstripe.
	Kit.part(m, "Body", Vector3.new(22, 2.4, 7.4), cf * CFrame.new(0, 2.2, 0), paint)
	Kit.part(m, "Hood", Vector3.new(6.4, 0.7, 7.2), cf * CFrame.new(7.6, 3.55, 0) * CFrame.Angles(0, 0, math.rad(-4)), paint, soft)
	Kit.part(m, "Cabin", Vector3.new(11, 1.0, 6.8), cf * CFrame.new(-1.2, 3.9, 0), paint)
	Kit.part(m, "Glass", Vector3.new(10.8, 1.7, 6.6), cf * CFrame.new(-1.2, 5.25, 0), L.smokedGlass, soft)
	Kit.part(m, "Roof", Vector3.new(10.2, 0.35, 6.7), cf * CFrame.new(-1.4, 6.25, 0), paint, soft)
	Kit.part(m, "Windscreen", Vector3.new(0.3, 1.9, 6.4), cf * CFrame.new(4.5, 5.2, 0) * CFrame.Angles(0, 0, math.rad(28)), L.smokedGlass, soft)
	for _, px in { -6.5, -2.4, 1.8 } do
		Kit.part(m, "Pillar", Vector3.new(0.45, 1.8, 6.7), cf * CFrame.new(px, 5.25, 0), paint, soft)
	end
	Kit.part(m, "Pinstripe", Vector3.new(22.1, 0.12, 7.45), cf * CFrame.new(0, 3.05, 0), L.brass, soft)
	Kit.part(m, "RoofLine", Vector3.new(10.3, 0.1, 6.75), cf * CFrame.new(-1.4, 6.45, 0), L.brass, soft)
	for _, bx in { 11.2, -11.2 } do
		Kit.part(m, "Bumper", Vector3.new(0.5, 0.6, 7.6), cf * CFrame.new(bx, 1.5, 0), chrome, soft)
	end
	for _, side in { -1, 1 } do
		Kit.part(m, "RunningBoard", Vector3.new(14, 0.3, 0.5), cf * CFrame.new(-0.5, 1.15, side * 3.85), chrome, soft)
		Kit.part(m, "Handle", Vector3.new(0.8, 0.14, 0.12), cf * CFrame.new(-4.2, 3.6, side * 3.74), chrome, soft)
		Kit.part(m, "Handle", Vector3.new(0.8, 0.14, 0.12), cf * CFrame.new(0.2, 3.6, side * 3.74), chrome, soft)
	end
	Kit.part(m, "Grille", Vector3.new(0.3, 1.8, 3.6), cf * CFrame.new(11.1, 2.5, 0), L.brass, soft)
	Kit.part(m, "Mascot", Vector3.new(0.6, 0.9, 0.2), cf * CFrame.new(10.6, 4.3, 0), L.brass, soft)
	for _, side in { -1.4, 1.4 } do
		local lamp = Kit.part(m, "Headlamp", Vector3.new(0.3, 0.7, 1.1), cf * CFrame.new(11.15, 2.9, side * 2), look(rgb(255, 246, 220), Enum.Material.Neon, nil, 0.2), soft)
		Kit.spotLight(lamp, Enum.NormalId.Right, 2, 40, 45, rgb(255, 240, 210))
		Kit.part(m, "Taillamp", Vector3.new(0.3, 0.5, 1.1), cf * CFrame.new(-11.15, 2.9, side * 2), look(rgb(255, 40, 50), Enum.Material.Neon, nil, 0.15), soft)
	end
	for _, wx in { -7, 7 } do
		for _, wz in { -3.5, 3.5 } do
			Kit.cylinder(m, "Wheel", 1.2, 3, cf * CFrame.new(wx, 1.5, wz) * CFrame.Angles(0, math.rad(90), 0), look(rgb(20, 20, 22), Enum.Material.Rubber))
			Kit.cylinder(m, "Rim", 1.25, 2.0, cf * CFrame.new(wx, 1.5, wz) * CFrame.Angles(0, math.rad(90), 0), chrome, { collide = false })
			Kit.cylinder(m, "Hub", 1.3, 0.9, cf * CFrame.new(wx, 1.5, wz) * CFrame.Angles(0, math.rad(90), 0), L.brass, { collide = false })
		end
	end
	-- The open boot: its lid raised, a hold of oxblood velvet lit soft gold, where the haul goes.
	Kit.part(m, "BootLid", Vector3.new(4.4, 0.25, 6.8), cf * CFrame.new(-10.2, 5.6, 0) * CFrame.Angles(0, 0, math.rad(62)), paint, soft)
	Kit.part(m, "Velvet", Vector3.new(4.6, 0.12, 6.6), cf * CFrame.new(-8.6, 3.42, 0), look(rgb(110, 18, 32), Enum.Material.Fabric), soft)
	local boot = Kit.part(m, "Boot", Vector3.new(4.2, 0.1, 6.0), cf * CFrame.new(-8.6, 3.52, 0), look(GOLD, Enum.Material.Neon, nil, 0.6), soft)
	Kit.pointLight(boot, 1.2, 14, GOLD)
	HolidayProps.sparkle(boot, GOLD, 6, 0.5)
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
	if spot.wing >= 4 then
		-- The new wings' pedestals: black chrome, a stud-textured top in the wing's colour, a lit edge.
		local accent = LuxePlan.Wings[spot.wing].colour
		top.Material = Enum.Material.Plastic
		top.Color = accent:Lerp(rgb(20, 20, 24), 0.35)
		top.TopSurface = Enum.SurfaceType.Studs
		for _, d in m:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "Column" or d.Name == "Base") then
				d.Material = Enum.Material.Metal
				d.Color = rgb(22, 22, 26)
				d.Reflectance = 0.3
			end
		end
		Kit.part(m, "Glow", Vector3.new(w + 0.1, 0.12, w + 0.1), CFrame.new(at + Vector3.new(0, 3.42, 0)), look(accent, Enum.Material.Neon), SOFT)
	end
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
		-- (Build 82) The brainrot itself, in the round, standing on its pedestal.
		local figure = if c then BrainrotFigure.build(c.id, 3.4, c.colour) else nil
		if figure then
			BrainrotFigure.place(figure, cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, math.pi, 0))
			figure.Parent = m
			return
		end
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
	-- Build 78: the Drop Room's streetwear, the Garage's pieces, the Secret Stash's finds.
	shades = function(m, cf, piece)
		local frame = piece.tint or rgb(18, 18, 22)
		local riser = P(m, "Riser", Vector3.new(3, 0.9, 1.6), cf * CFrame.new(0, 0.45, 0), rgb(220, 226, 236), Enum.Material.Glass)
		riser.Transparency = 0.3
		local face = cf * CFrame.new(0, 1.75, 0)
		for _, x in { -0.8, 0.8 } do
			local lens = P(m, "Lens", Vector3.new(1.35, 0.9, 0.15), face * CFrame.new(x, 0, 0), rgb(26, 26, 36), Enum.Material.Glass)
			lens.Reflectance = 0.55
			P(m, "Rim", Vector3.new(1.5, 1.04, 0.12), face * CFrame.new(x, 0, 0.05), frame, Enum.Material.SmoothPlastic)
		end
		gold(m, "Bridge", Vector3.new(0.4, 0.16, 0.16), face * CFrame.new(0, 0.28, 0))
		for _, x in { -1.52, 1.52 } do
			gold(m, "Arm", Vector3.new(0.12, 0.12, 1.9), face * CFrame.new(x, 0.28, 0.95))
		end
	end,
	mask = function(m, cf)
		P(m, "Stand", Vector3.new(0.35, 1.8, 0.35), cf * CFrame.new(0, 0.9, 0.35), rgb(22, 22, 26), Enum.Material.Metal)
		local face = HolidayProps.ellipsoid(m, "Mask", Vector3.new(2.3, 3, 0.9), cf * CFrame.new(0, 2.7, 0), rgb(246, 244, 240), Enum.Material.SmoothPlastic)
		face.Reflectance = 0.15
		for _, x in { -0.52, 0.52 } do
			HolidayProps.ellipsoid(m, "Eye", Vector3.new(0.62, 0.36, 0.3), cf * CFrame.new(x, 3.0, -0.36), rgb(10, 10, 12), Enum.Material.SmoothPlastic)
		end
		HolidayProps.ellipsoid(m, "Brow", Vector3.new(2.0, 0.22, 0.95), cf * CFrame.new(0, 3.45, -0.02), rgb(255, 72, 96), Enum.Material.Neon)
	end,
	sneaker = function(m, cf, piece)
		local upper = piece.tint or rgb(230, 230, 236)
		local sole = rgb(246, 244, 238)
		local riser = P(m, "Riser", Vector3.new(3.6, 0.5, 2), cf * CFrame.new(0, 0.25, 0), rgb(220, 226, 236), Enum.Material.Glass)
		riser.Transparency = 0.3
		-- Three-quarter on, toe to the left: sole, upper, toe box, collar, a side panel, laces.
		local s = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(25), 0)
		P(m, "Sole", Vector3.new(3.3, 0.45, 1.3), s * CFrame.new(0, 0.22, 0), sole, Enum.Material.SmoothPlastic)
		P(m, "Upper", Vector3.new(2.4, 0.95, 1.2), s * CFrame.new(0.3, 0.92, 0), upper, Enum.Material.Leather)
		P(m, "Toe", Vector3.new(1.0, 0.55, 1.2), s * CFrame.new(-1.15, 0.72, 0), upper, Enum.Material.Leather)
		P(m, "Collar", Vector3.new(1.05, 0.7, 1.15), s * CFrame.new(1.0, 1.6, 0), upper:Lerp(rgb(0, 0, 0), 0.25), Enum.Material.Leather)
		P(m, "Panel", Vector3.new(1.5, 0.32, 1.24), s * CFrame.new(0.15, 0.85, 0), sole, Enum.Material.SmoothPlastic)
		P(m, "Laces", Vector3.new(1.2, 0.12, 0.62), s * CFrame.new(-0.3, 1.42, 0), sole, Enum.Material.Fabric)
		gold(m, "Heel", Vector3.new(0.18, 0.55, 0.5), s * CFrame.new(1.58, 1.2, 0))
	end,
	headphones = function(m, cf)
		local black = rgb(20, 20, 24)
		P(m, "Foot", Vector3.new(1.6, 0.25, 1.6), cf * CFrame.new(0, 0.12, 0), rgb(22, 22, 26), Enum.Material.Metal)
		P(m, "Stand", Vector3.new(0.3, 3.2, 0.3), cf * CFrame.new(0, 1.8, 0), rgb(150, 154, 162), Enum.Material.Metal)
		P(m, "Band", Vector3.new(1.5, 0.3, 0.75), cf * CFrame.new(0, 3.55, 0), black, Enum.Material.Leather)
		for _, sx in { -1, 1 } do
			P(m, "Band", Vector3.new(0.3, 1.2, 0.75), cf * CFrame.new(sx * 1.0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(sx * 25)), black, Enum.Material.Leather)
			local cup = cf * CFrame.new(sx * 1.25, 2.15, 0)
			P(m, "Cup", Vector3.new(0.55, 1.55, 1.55), cup, rgb(190, 194, 202), Enum.Material.Metal, Enum.PartType.Cylinder)
			P(m, "Cushion", Vector3.new(0.35, 1.35, 1.35), cup * CFrame.new(-sx * 0.38, 0, 0), black, Enum.Material.Fabric, Enum.PartType.Cylinder)
			P(m, "Accent", Vector3.new(0.6, 0.6, 0.6), cup, PINK, Enum.Material.Neon, Enum.PartType.Cylinder)
		end
	end,
	puffer = function(m, cf)
		local shell = rgb(16, 16, 20)
		P(m, "Pole", Vector3.new(0.3, 1.4, 0.3), cf * CFrame.new(0, 0.7, 0), rgb(150, 154, 162), Enum.Material.Metal)
		for i = 0, 3 do
			local band = P(m, "Quilt", Vector3.new(2.7 - math.abs(i - 1.5) * 0.15, 0.62, 1.6), cf * CFrame.new(0, 1.7 + i * 0.6, 0), shell, Enum.Material.SmoothPlastic)
			band.Reflectance = 0.25
		end
		for _, sx in { -1, 1 } do
			local sleeve = P(m, "Sleeve", Vector3.new(0.8, 2.3, 0.95), cf * CFrame.new(sx * 1.6, 2.5, 0) * CFrame.Angles(0, 0, math.rad(sx * 12)), shell, Enum.Material.SmoothPlastic)
			sleeve.Reflectance = 0.25
		end
		P(m, "Collar", Vector3.new(1.45, 0.6, 1.25), cf * CFrame.new(0, 4.3, 0), shell, Enum.Material.SmoothPlastic)
		P(m, "Zip", Vector3.new(0.1, 2.4, 0.05), cf * CFrame.new(0, 2.75, -0.82), rgb(214, 218, 226), Enum.Material.Metal)
		P(m, "Patch", Vector3.new(0.5, 0.3, 0.05), cf * CFrame.new(0.68, 3.3, -0.82), CYAN, Enum.Material.Neon)
	end,
	deck = function(m, cf)
		local board = cf * CFrame.new(0, 2.7, 0) * CFrame.Angles(math.rad(-8), 0, 0)
		P(m, "Bracket", Vector3.new(1.4, 0.4, 0.9), cf * CFrame.new(0, 0.2, 0.3), rgb(22, 22, 26), Enum.Material.Metal)
		P(m, "Board", Vector3.new(1.7, 4.8, 0.2), board, rgb(250, 90, 60), Enum.Material.Wood)
		P(m, "Grip", Vector3.new(1.6, 4.6, 0.05), board * CFrame.new(0, 0, 0.12), rgb(20, 20, 22), Enum.Material.Sand)
		P(m, "Art", Vector3.new(1.3, 2.3, 0.04), board * CFrame.new(0, 0.2, -0.12), rgb(255, 230, 90), Enum.Material.SmoothPlastic)
		P(m, "ArtMark", Vector3.new(0.8, 0.8, 0.05), board * CFrame.new(0, 0.6, -0.14) * CFrame.Angles(0, 0, math.rad(45)), PINK, Enum.Material.SmoothPlastic)
		for _, y in { -1.6, 1.6 } do
			P(m, "Truck", Vector3.new(1.3, 0.25, 0.35), board * CFrame.new(0, y, 0.25), rgb(190, 194, 202), Enum.Material.Metal)
			for _, x in { -0.75, 0.75 } do
				P(m, "Wheel", Vector3.new(0.35, 0.5, 0.5), board * CFrame.new(x, y, 0.45), rgb(246, 244, 238), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			end
		end
		gold(m, "Signature", Vector3.new(0.9, 0.12, 0.03), board * CFrame.new(0, -1.2, -0.15) * CFrame.Angles(0, 0, math.rad(15)))
	end,
	chain = function(m, cf, piece)
		local metal = piece.tint or rgb(220, 235, 255)
		P(m, "Bust", Vector3.new(2.4, 2.6, 1.2), cf * CFrame.new(0, 1.3, 0), rgb(16, 16, 20), Enum.Material.Fabric)
		P(m, "Neck", Vector3.new(0.9, 1.2, 0.8), cf * CFrame.new(0, 3.1, 0), rgb(16, 16, 20), Enum.Material.Fabric)
		for i = 0, 10 do
			local a = math.pi * (i / 10)
			local link = HolidayProps.ball(m, "Link", 0.4, (cf * CFrame.new(math.cos(a) * 0.95, 3.0 - math.sin(a) * 1.2, -0.65)).Position, metal, Enum.Material.Metal)
			link.Reflectance = 0.45
		end
		local pendant = P(m, "Pendant", Vector3.new(0.8, 0.8, 0.2), cf * CFrame.new(0, 1.5, -0.7) * CFrame.Angles(0, 0, math.rad(45)), metal, Enum.Material.Glass)
		pendant.Reflectance = 0.5
	end,
	artToy = function(m, cf)
		-- An original vinyl bear in a visor, edition of fifty.
		local vinyl = rgb(255, 120, 190)
		P(m, "Base", Vector3.new(2.2, 0.35, 2.2), cf * CFrame.new(0, 0.18, 0), rgb(22, 22, 26), Enum.Material.Metal)
		P(m, "Legs", Vector3.new(1.6, 0.8, 1.1), cf * CFrame.new(0, 0.75, 0), vinyl, Enum.Material.SmoothPlastic)
		P(m, "Body", Vector3.new(1.9, 1.5, 1.4), cf * CFrame.new(0, 1.9, 0), vinyl, Enum.Material.SmoothPlastic)
		local head = HolidayProps.ball(m, "Head", 2.2, (cf * CFrame.new(0, 3.55, 0)).Position, vinyl, Enum.Material.SmoothPlastic)
		head.Reflectance = 0.1
		for _, sx in { -1, 1 } do
			HolidayProps.ball(m, "Ear", 0.8, (cf * CFrame.new(sx * 0.85, 4.55, 0)).Position, vinyl, Enum.Material.SmoothPlastic)
			P(m, "Arm", Vector3.new(0.5, 1.2, 0.6), cf * CFrame.new(sx * 1.15, 1.9, 0) * CFrame.Angles(0, 0, math.rad(sx * 10)), vinyl, Enum.Material.SmoothPlastic)
		end
		local visor = P(m, "Visor", Vector3.new(1.7, 0.5, 0.4), cf * CFrame.new(0, 3.6, -0.9), rgb(30, 30, 40), Enum.Material.Glass)
		visor.Reflectance = 0.5
		P(m, "Glow", Vector3.new(1.3, 0.12, 0.42), cf * CFrame.new(0, 3.6, -0.92), CYAN, Enum.Material.Neon)
	end,
	record = function(m, cf)
		local frame = cf * CFrame.new(0, 2.5, 0)
		P(m, "Easel", Vector3.new(0.3, 3.8, 0.3), cf * CFrame.new(0, 1.9, 0.55) * CFrame.Angles(math.rad(-10), 0, 0), rgb(22, 22, 26), Enum.Material.Metal)
		local f = P(m, "Frame", Vector3.new(3.6, 3.6, 0.3), frame, rgb(18, 18, 22), Enum.Material.Metal)
		f.Reflectance = 0.3
		P(m, "Mat", Vector3.new(3.2, 3.2, 0.05), frame * CFrame.new(0, 0, -0.17), rgb(240, 240, 244), Enum.Material.SmoothPlastic)
		local disc = P(m, "Disc", Vector3.new(0.08, 2.5, 2.5), frame * CFrame.new(0, 0.1, -0.22) * CFrame.Angles(0, math.rad(90), 0), rgb(228, 230, 236), Enum.Material.Metal, Enum.PartType.Cylinder)
		disc.Reflectance = 0.55
		P(m, "Label", Vector3.new(0.1, 0.85, 0.85), frame * CFrame.new(0, 0.1, -0.24) * CFrame.Angles(0, math.rad(90), 0), PINK, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		gold(m, "Plaque", Vector3.new(1.4, 0.25, 0.05), frame * CFrame.new(0, -1.35, -0.2))
	end,
	toolchest = function(m, cf)
		local body = P(m, "Body", Vector3.new(3.2, 3.4, 1.8), cf * CFrame.new(0, 2.1, 0), rgb(24, 24, 28), Enum.Material.Metal)
		body.Reflectance = 0.35
		for i = 0, 4 do
			P(m, "Drawer", Vector3.new(3.0, 0.08, 0.05), cf * CFrame.new(0, 0.75 + i * 0.62, -0.92), rgb(214, 218, 226), Enum.Material.Metal)
			P(m, "Pull", Vector3.new(1.4, 0.12, 0.12), cf * CFrame.new(0, 1.0 + i * 0.62, -0.95), rgb(214, 218, 226), Enum.Material.Metal)
		end
		local lid = P(m, "Lid", Vector3.new(3.3, 0.25, 1.9), cf * CFrame.new(0, 3.92, 0), rgb(214, 218, 226), Enum.Material.Metal)
		lid.Reflectance = 0.4
		P(m, "Stripe", Vector3.new(3.22, 0.12, 1.82), cf * CFrame.new(0, 3.6, 0), CYAN, Enum.Material.Neon)
		for _, x in { -1.3, 1.3 } do
			for _, z in { -0.6, 0.6 } do
				P(m, "Caster", Vector3.new(0.3, 0.4, 0.4), cf * CFrame.new(x, 0.2, z), rgb(20, 20, 22), Enum.Material.Rubber, Enum.PartType.Cylinder)
			end
		end
	end,
	helmet = function(m, cf)
		P(m, "Stand", Vector3.new(0.5, 1.2, 0.5), cf * CFrame.new(0, 0.6, 0), rgb(22, 22, 26), Enum.Material.Metal)
		local shell = HolidayProps.ellipsoid(m, "Shell", Vector3.new(2.6, 2.6, 3.0), cf * CFrame.new(0, 2.45, 0), rgb(16, 16, 20), Enum.Material.SmoothPlastic)
		shell.Reflectance = 0.35
		HolidayProps.ellipsoid(m, "Stripe", Vector3.new(0.55, 2.66, 3.06), cf * CFrame.new(0, 2.45, 0), CYAN, Enum.Material.Neon)
		local visor = HolidayProps.ellipsoid(m, "Visor", Vector3.new(2.2, 1.0, 1.3), cf * CFrame.new(0, 2.55, -1.0), rgb(40, 30, 60), Enum.Material.Glass)
		visor.Reflectance = 0.6
	end,
	rims = function(m, cf)
		local wheel = cf * CFrame.new(0, 2.1, 0) * CFrame.Angles(0, math.rad(90), 0)
		P(m, "Cradle", Vector3.new(2.6, 0.5, 1.2), cf * CFrame.new(0, 0.25, 0), rgb(22, 22, 26), Enum.Material.Metal)
		P(m, "Tyre", Vector3.new(1.0, 3.8, 3.8), wheel, rgb(20, 20, 22), Enum.Material.Rubber, Enum.PartType.Cylinder)
		P(m, "Barrel", Vector3.new(1.05, 3.0, 3.0), wheel, rgb(36, 36, 42), Enum.Material.Metal, Enum.PartType.Cylinder)
		for i = 0, 4 do
			local a = i * math.pi * 2 / 5
			P(m, "Spoke", Vector3.new(0.24, 1.4, 0.3), cf * CFrame.new(0, 2.1, -0.56) * CFrame.Angles(0, 0, a) * CFrame.new(0, 0.7, 0), rgb(214, 218, 226), Enum.Material.Metal)
		end
		gold(m, "Centre", Vector3.new(0.7, 0.7, 0.3), cf * CFrame.new(0, 2.1, -0.6))
		P(m, "Caliper", Vector3.new(0.6, 0.9, 0.3), cf * CFrame.new(0.95, 1.7, -0.25), CYAN, Enum.Material.SmoothPlastic)
	end,
	chrono = function(m, cf)
		local face = cf * CFrame.new(0, 2.05, 0) * CFrame.Angles(0, math.rad(90), 0)
		P(m, "Pillow", Vector3.new(2.4, 1.0, 1.4), cf * CFrame.new(0, 0.5, 0), rgb(16, 16, 20), Enum.Material.Fabric)
		P(m, "Strap", Vector3.new(1.0, 2.6, 0.25), cf * CFrame.new(0, 1.7, 0.2), rgb(20, 20, 24), Enum.Material.Rubber)
		local case = P(m, "Case", Vector3.new(0.5, 2.7, 2.7), face, rgb(214, 218, 226), Enum.Material.Metal, Enum.PartType.Cylinder)
		case.Reflectance = 0.4
		local ice = P(m, "Bezel", Vector3.new(0.54, 2.4, 2.4), face, rgb(220, 240, 255), Enum.Material.Glass, Enum.PartType.Cylinder)
		ice.Reflectance = 0.6
		P(m, "Dial", Vector3.new(0.58, 1.9, 1.9), face, rgb(14, 14, 18), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
		for _, at in { Vector3.new(-0.45, 0.15, 0), Vector3.new(0.45, 0.15, 0), Vector3.new(0, -0.42, 0) } do
			P(m, "SubDial", Vector3.new(0.1, 0.44, 0.44), cf * CFrame.new(at.X, 2.05 + at.Y, -0.3) * CFrame.Angles(0, math.rad(90), 0), rgb(214, 218, 226), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		P(m, "Hand", Vector3.new(0.08, 0.75, 0.05), cf * CFrame.new(0.1, 2.3, -0.32) * CFrame.Angles(0, 0, math.rad(-30)), CYAN, Enum.Material.Neon)
	end,
	keyFob = function(m, cf)
		P(m, "Cushion", Vector3.new(2.8, 0.6, 2.8), cf * CFrame.new(0, 0.3, 0), rgb(30, 10, 16), Enum.Material.Fabric)
		local fob = cf * CFrame.new(0, 0.98, 0) * CFrame.Angles(0, math.rad(20), 0)
		local body = P(m, "Fob", Vector3.new(2.6, 0.7, 1.4), fob, rgb(14, 14, 18), Enum.Material.SmoothPlastic)
		body.Reflectance = 0.4
		P(m, "Band", Vector3.new(2.64, 0.16, 1.44), fob, rgb(214, 218, 226), Enum.Material.Metal)
		gold(m, "Badge", Vector3.new(0.7, 0.06, 0.7), fob * CFrame.new(-0.2, 0.38, 0))
		P(m, "Button", Vector3.new(0.4, 0.06, 0.4), fob * CFrame.new(0.8, 0.38, 0), rgb(255, 50, 60), Enum.Material.Neon)
		P(m, "Ring", Vector3.new(0.14, 1.2, 1.2), fob * CFrame.new(-1.7, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(214, 218, 226), Enum.Material.Metal, Enum.PartType.Cylinder)
	end,
	duffel = function(m, cf)
		local bag = cf * CFrame.new(0, 1.1, 0)
		P(m, "Bag", Vector3.new(3.4, 2.0, 2.0), bag, rgb(18, 18, 22), Enum.Material.Fabric, Enum.PartType.Cylinder)
		for _, x in { -1.1, 1.1 } do
			P(m, "Strap", Vector3.new(0.25, 2.05, 2.05), bag * CFrame.new(x, 0, 0), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
		P(m, "Notes", Vector3.new(1.6, 0.5, 0.9), bag * CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(8)), rgb(222, 206, 160), Enum.Material.Fabric)
		P(m, "Notes", Vector3.new(1.4, 0.45, 0.8), bag * CFrame.new(0.3, 1.15, 0.1) * CFrame.Angles(0, math.rad(20), math.rad(-6)), rgb(232, 216, 170), Enum.Material.Fabric)
		P(m, "Handle", Vector3.new(1.6, 0.2, 0.3), bag * CFrame.new(0, 1.18, -0.55), rgb(18, 18, 22), Enum.Material.Leather)
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
	local finest = piece.rarity == "Mythic" or piece.rarity == "Exclusive" or piece.rarity == "Limited"
	Kit.pointLight(root, if finest then 2.4 else 1.3, if finest then 26 else 14, colour)
	if finest or piece.rarity == "Legendary" or piece.rarity == "Epic" then
		HolidayProps.sparkle(root, colour, if finest then 10 else 4, 0.5)
	end
	-- Its grade over it, readable across the room (Rare and up): <RARE>, <EPIC>, <LEGENDARY>...
	local grade = LuxePlan.rarityOf[piece.rarity]
	if grade and grade.label then
		local tag = Instance.new("BillboardGui")
		tag.Name = "Grade"
		tag.Size = UDim2.new(3.4, 56, 0.62, 12)
		tag.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
		tag.MaxDistance = 70
		tag.LightInfluence = 0
		tag.Parent = root
		local chip = Instance.new("TextLabel")
		chip.Name = "Chip"
		chip.Size = UDim2.fromScale(1, 1)
		chip.BackgroundColor3 = rgb(10, 10, 12)
		chip.BackgroundTransparency = 0.2
		chip.BorderSizePixel = 0
		chip.Text = "<" .. string.upper(piece.rarity) .. ">"
		chip.TextColor3 = grade.colour
		chip.FontFace = Brand.Fonts.display
		chip.TextScaled = true
		chip.Parent = tag
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.3, 0)
		corner.Parent = chip
		local stroke = Instance.new("UIStroke")
		stroke.Color = grade.colour
		stroke.Thickness = 1.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = chip
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.14, 0)
		pad.PaddingBottom = UDim.new(0.14, 0)
		pad.Parent = chip
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
	prompt.HoldDuration = if finest then 1.2 elseif piece.wing >= 3 then 0.6 else 0.35 -- (the server sets the real one)
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = root
	m.Parent = parent
	return m
end

---------------------------------------------------------------------------------------------------
-- Build 78: the Drop Room, the Garage, the Secret Stash, the cameras and the laser grid
---------------------------------------------------------------------------------------------------
-- A lamp hung from the ceiling: a black chrome shade over a lit disc.
local function pendant(parent: Instance, at: Vector3, colour: Color3, range: number, brightness: number?)
	Kit.post(parent, "PendantCord", 2.4, 0.12, at + Vector3.new(0, 0.6, 0), BLACK_CHROME, SOFT)
	Kit.cylinder(parent, "PendantShade", 1.2, 2.2, CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), BLACK_CHROME, SOFT)
	local glow = Kit.cylinder(parent, "PendantGlow", 0.15, 1.9, CFrame.new(at - Vector3.new(0, 0.62, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(colour, Enum.Material.Neon), SOFT)
	Kit.pointLight(glow, brightness or 1.3, range, colour)
end

-- A way out's ring of gold light on the floor (as round the getaway car), and its sign.
local function bankRing(parent: Instance, o: Vector3, b: LuxePlan.Bank, y: number)
	local ring = look(GOLD, Enum.Material.Neon, nil, 0.35)
	local t = 0.4
	Kit.span(parent, "BankEdge", o + Vector3.new(b.minX, y, b.minZ), o + Vector3.new(b.maxX, y + 0.06, b.minZ + t), ring, SOFT)
	Kit.span(parent, "BankEdge", o + Vector3.new(b.minX, y, b.maxZ - t), o + Vector3.new(b.maxX, y + 0.06, b.maxZ), ring, SOFT)
	Kit.span(parent, "BankEdge", o + Vector3.new(b.minX, y, b.minZ), o + Vector3.new(b.minX + t, y + 0.06, b.maxZ), ring, SOFT)
	Kit.span(parent, "BankEdge", o + Vector3.new(b.maxX - t, y, b.minZ), o + Vector3.new(b.maxX, y + 0.06, b.maxZ), ring, SOFT)
end

local function sign(parent: Instance, at: Vector3, toward: Vector3, w: number, h: number, lines: { { text: string, size: number, font: Font?, color: Color3? } }): Part
	local board = Kit.part(parent, "Sign", Vector3.new(w, h, 0.3), CFrame.lookAt(at, toward), L.blackLacquer, { collide = false })
	Kit.engrave(board, Enum.NormalId.Front, lines, { ppu = 60, lit = false, brightness = 1.6, maxDistance = 180 })
	return board
end

-- A part made round (a sphere mesh): the helicopter's cabin and canopy.
local function rounded(p: BasePart): BasePart
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function helicopter(parent: Instance, cf: CFrame)
	local m = Kit.model(parent, "Helicopter")
	local paint = look(rgb(16, 16, 20), Enum.Material.SmoothPlastic, 0.3)
	local chrome = look(rgb(214, 218, 226), Enum.Material.Metal, 0.4)
	-- (Its nose toward cf's -Z.)
	rounded(Kit.part(m, "Cabin", Vector3.new(6, 5.2, 10), cf * CFrame.new(0, 3.8, 0), paint))
	rounded(Kit.part(m, "Canopy", Vector3.new(5.2, 3.4, 5), cf * CFrame.new(0, 4.6, -3), L.smokedGlass, SOFT))
	Kit.cylinder(m, "Boom", 9, 1.2, cf * CFrame.new(0, 4.6, 8.5) * CFrame.Angles(0, math.rad(90), 0), paint, SOFT)
	Kit.part(m, "Fin", Vector3.new(0.4, 3, 1.8), cf * CFrame.new(0, 6, 12.6), look(PINK, Enum.Material.Neon), SOFT)
	Kit.cylinder(m, "TailRotor", 0.2, 2.8, cf * CFrame.new(0.4, 6, 12.6), chrome, SOFT)
	Kit.post(m, "Mast", 1.4, 0.6, (cf * CFrame.new(0, 6.3, 0)).Position, chrome, SOFT)
	for _, a in { 20, 110 } do
		Kit.part(m, "Blade", Vector3.new(22, 0.15, 0.9), cf * CFrame.new(0, 7.75, 0) * CFrame.Angles(0, math.rad(a), 0), paint, SOFT)
	end
	for _, sx in { -1, 1 } do
		Kit.cylinder(m, "Skid", 11, 0.4, cf * CFrame.new(sx * 2.8, 0.3, 0) * CFrame.Angles(0, math.rad(90), 0), chrome, SOFT)
		for _, sz in { -2.5, 2.5 } do
			Kit.part(m, "Strut", Vector3.new(0.3, 1.6, 0.3), cf * CFrame.new(sx * 2.5, 1.1, sz) * CFrame.Angles(0, 0, math.rad(sx * 15)), chrome, SOFT)
		end
	end
	Kit.part(m, "Beacon", Vector3.new(0.5, 0.3, 0.5), cf * CFrame.new(0, 6.5, 3), look(rgb(255, 50, 60), Enum.Material.Neon), SOFT)
end

-- A low show car on a lit turntable: its nose along cf's +X.
local function supercar(parent: Instance, cf: CFrame, paintColour: Color3, glow: Color3)
	local m = Kit.model(parent, "ShowCar")
	local paint = look(paintColour, Enum.Material.SmoothPlastic, 0.35)
	local chrome = look(rgb(214, 218, 226), Enum.Material.Metal, 0.45)
	local W = HolidayProps.wedge
	Kit.cylinder(m, "Turntable", 0.3, 18, CFrame.new(cf.Position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), GRAPHITE)
	Kit.cylinder(m, "TurntableGlow", 0.2, 18.6, CFrame.new(cf.Position + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), look(glow, Enum.Material.Neon, nil, 0.3), SOFT)
	local c = cf * CFrame.new(-0.75, 0.3, 0)
	Kit.part(m, "Body", Vector3.new(13, 1.8, 7), c * CFrame.new(0, 1.6, 0), paint)
	W(m, "Nose", Vector3.new(7, 1.1, 2.5), c * CFrame.new(7.75, 1.25, 0) * CFrame.Angles(0, math.rad(-90), 0), paintColour, Enum.Material.SmoothPlastic)
	W(m, "Windscreen", Vector3.new(5.6, 1.3, 2.4), c * CFrame.new(3.2, 3.15, 0) * CFrame.Angles(0, math.rad(-90), 0), rgb(40, 44, 52), Enum.Material.Glass)
	Kit.part(m, "Cabin", Vector3.new(4, 1.3, 5.6), c * CFrame.new(0, 3.15, 0), L.smokedGlass, SOFT)
	Kit.part(m, "Roof", Vector3.new(4.2, 0.22, 5.4), c * CFrame.new(-0.1, 3.9, 0), paint, SOFT)
	W(m, "RearDeck", Vector3.new(6.2, 1.1, 3.2), c * CFrame.new(-3.6, 3.05, 0) * CFrame.Angles(0, math.rad(90), 0), paintColour, Enum.Material.SmoothPlastic)
	Kit.part(m, "Spoiler", Vector3.new(1.1, 0.2, 7.2), c * CFrame.new(-6.1, 3.75, 0), look(rgb(16, 16, 18), Enum.Material.SmoothPlastic, 0.2), SOFT)
	for _, z in { -2.4, 2.4 } do
		Kit.part(m, "Strut", Vector3.new(0.3, 1.1, 0.3), c * CFrame.new(-6.1, 3.15, z), chrome, SOFT)
	end
	for _, side in { -1, 1 } do
		Kit.part(m, "Intake", Vector3.new(3, 0.9, 0.1), c * CFrame.new(-2.2, 1.8, side * 3.52), look(rgb(14, 14, 16), Enum.Material.SmoothPlastic), SOFT)
	end
	for _, wx in { -4.3, 4.6 } do
		for _, wz in { -3.25, 3.25 } do
			Kit.cylinder(m, "Wheel", 1.0, 2.7, c * CFrame.new(wx, 1.05, wz) * CFrame.Angles(0, math.rad(90), 0), look(rgb(20, 20, 22), Enum.Material.Rubber), SOFT)
			Kit.cylinder(m, "Rim", 1.05, 1.8, c * CFrame.new(wx, 1.05, wz) * CFrame.Angles(0, math.rad(90), 0), chrome, SOFT)
		end
	end
	Kit.part(m, "Headlights", Vector3.new(0.15, 0.25, 6), c * CFrame.new(9, 0.85, 0), look(rgb(240, 250, 255), Enum.Material.Neon), SOFT)
	Kit.part(m, "Taillights", Vector3.new(0.15, 0.3, 6.4), c * CFrame.new(-6.55, 2.2, 0), look(rgb(255, 40, 50), Enum.Material.Neon), SOFT)
end

-- The garage van: its nose along cf's +X, its back doors open and its hold lit gold.
local function van(parent: Instance, cf: CFrame)
	local m = Kit.model(parent, "GarageVan")
	local paint = look(rgb(14, 14, 17), Enum.Material.SmoothPlastic, 0.3)
	local chrome = look(rgb(214, 218, 226), Enum.Material.Metal, 0.45)
	Kit.part(m, "Body", Vector3.new(12, 6.2, 6.8), cf * CFrame.new(-1.5, 4.0, 0), paint)
	Kit.part(m, "Hood", Vector3.new(2.5, 3.5, 6.6), cf * CFrame.new(5.75, 2.65, 0), paint)
	Kit.part(m, "Nose", Vector3.new(1.5, 2.6, 6.6), cf * CFrame.new(7.75, 2.2, 0), paint)
	Kit.part(m, "Windscreen", Vector3.new(3.7, 0.25, 6.3), cf * CFrame.new(5.75, 5.75, 0) * CFrame.Angles(0, 0, -math.atan2(2.7, 2.5)), L.smokedGlass, SOFT)
	for _, side in { -1, 1 } do
		Kit.part(m, "SideGlass", Vector3.new(2.4, 1.8, 0.1), cf * CFrame.new(3.2, 5.6, side * 3.42), L.smokedGlass, SOFT)
		Kit.part(m, "Stripe", Vector3.new(12, 0.25, 0.08), cf * CFrame.new(-1.5, 2.6, side * 3.42), look(GOLD, Enum.Material.Metal, 0.2), SOFT)
		Kit.part(m, "BackDoor", Vector3.new(3.3, 6, 0.25), cf * CFrame.new(-9.15, 4.0, side * 3.5), paint, SOFT)
		Kit.part(m, "Taillamp", Vector3.new(0.2, 1.2, 0.35), cf * CFrame.new(-7.6, 5.8, side * 3.2), look(rgb(255, 40, 50), Enum.Material.Neon), SOFT)
		Kit.part(m, "Headlamp", Vector3.new(0.2, 0.6, 1.2), cf * CFrame.new(8.55, 2.9, side * 1.8), look(rgb(255, 246, 220), Enum.Material.Neon), SOFT)
	end
	local hold = Kit.part(m, "Hold", Vector3.new(0.1, 5.4, 6), cf * CFrame.new(-7.56, 4.0, 0), look(GOLD, Enum.Material.Neon, nil, 0.55), SOFT)
	Kit.pointLight(hold, 1.2, 16, GOLD)
	HolidayProps.sparkle(hold, GOLD, 4, 0.5)
	for _, wx in { -4.5, 5.5 } do
		for _, wz in { -3.2, 3.2 } do
			Kit.cylinder(m, "Wheel", 1.0, 2.6, cf * CFrame.new(wx, 1.3, wz) * CFrame.Angles(0, math.rad(90), 0), look(rgb(20, 20, 22), Enum.Material.Rubber), SOFT)
			Kit.cylinder(m, "Rim", 1.05, 1.6, cf * CFrame.new(wx, 1.3, wz) * CFrame.Angles(0, math.rad(90), 0), chrome, SOFT)
		end
	end
end

-- The Drop Room (wing 4): a streetwear showroom off the Garden Hall's west door, a loft up the
-- stairs, and up again to the roof, where the helicopter waits.
local function dropRoom(arch: Instance, o: Vector3)
	local m = Kit.model(arch, "DropRoom")
	local LOFT, ROOF = LuxePlan.LOFT, LuxePlan.ROOF
	wall(m, o, -124, -60, -60, -60, H, CONCRETE)
	wall(m, o, -124, 20, -60, 20, H, CONCRETE)
	wall(m, o, -124, -60, -124, 20, H, CONCRETE)
	Kit.span(m, "DropFloor", o + Vector3.new(-123, 0, -59), o + Vector3.new(-61, 0.2, 19), look(rgb(52, 54, 58), Enum.Material.Concrete, 0.05))
	-- The roof, its top at ROOF, with a hatch over the stairs from the loft; a parapet round it.
	local hx0, hx1, hz0, hz1 = -123.5, -117.5, -47, -33.8
	Kit.span(m, "Roof", o + Vector3.new(-125, H, -61), o + Vector3.new(hx0, ROOF, 21), GRAPHITE)
	Kit.span(m, "Roof", o + Vector3.new(hx1, H, -61), o + Vector3.new(-61, ROOF, 21), GRAPHITE)
	Kit.span(m, "Roof", o + Vector3.new(hx0, H, -61), o + Vector3.new(hx1, ROOF, hz0), GRAPHITE)
	Kit.span(m, "Roof", o + Vector3.new(hx0, H, hz1), o + Vector3.new(hx1, ROOF, 21), GRAPHITE)
	local cap = look(rgb(40, 42, 46), Enum.Material.Concrete)
	Kit.span(m, "Parapet", o + Vector3.new(-125, ROOF, -61), o + Vector3.new(-61, ROOF + 2.5, -60), cap)
	Kit.span(m, "Parapet", o + Vector3.new(-125, ROOF, 20), o + Vector3.new(-61, ROOF + 2.5, 21), cap)
	Kit.span(m, "Parapet", o + Vector3.new(-125, ROOF, -61), o + Vector3.new(-124, ROOF + 2.5, 21), cap)
	Kit.span(m, "Parapet", o + Vector3.new(-62, ROOF, -61), o + Vector3.new(-61, ROOF + 2.5, 21), cap)
	neonStrip(m, o + Vector3.new(-125, ROOF + 2.5, -61.05), o + Vector3.new(-61, ROOF + 2.7, -60.6), PINK)
	-- The loft: a steel deck along the west side, its lit edge, glass rails, its columns.
	Kit.span(m, "Loft", o + Vector3.new(-123, LOFT - 1, -59), o + Vector3.new(-98, LOFT, 19), look(rgb(36, 38, 42), Enum.Material.DiamondPlate, 0.08))
	neonStrip(m, o + Vector3.new(-98.05, LOFT - 0.7, -59), o + Vector3.new(-97.85, LOFT - 0.3, 19), PINK)
	local glass = look(rgb(180, 200, 220), Enum.Material.Glass, 0.2, 0.7)
	for _, seg in { { -59, -6 }, { 0, 19 } } do
		Kit.span(m, "LoftRail", o + Vector3.new(-98.6, LOFT, seg[1]), o + Vector3.new(-98.2, LOFT + 3.4, seg[2]), glass)
		Kit.span(m, "LoftRailTop", o + Vector3.new(-98.7, LOFT + 3.4, seg[1]), o + Vector3.new(-98.1, LOFT + 3.6, seg[2]), BRUSHED, SOFT)
	end
	for _, z in { -50, -30, 12 } do
		Kit.span(m, "LoftColumn", o + Vector3.new(-99.5, 0.2, z - 0.5), o + Vector3.new(-98.5, LOFT - 1, z + 0.5), BLACK_CHROME)
	end
	-- The stairs: from the floor up to the loft, and from the loft up through the hatch to the roof.
	local tread = look(rgb(28, 28, 32), Enum.Material.Metal, 0.12)
	for k = 1, LOFT do
		local x1 = -80 - (k - 1) * 1.8
		Kit.span(m, "Stair", o + Vector3.new(x1 - 1.8, 0, -6), o + Vector3.new(x1, k, 0), tread)
		Kit.span(m, "StairNose", o + Vector3.new(x1 - 0.2, k - 0.12, -6), o + Vector3.new(x1, k + 0.02, 0), look(PINK, Enum.Material.Neon), SOFT)
	end
	for _, z in { -6.2, 0.2 } do
		HolidayProps.rod(m, "Handrail", o + Vector3.new(-80, 3.4, z), o + Vector3.new(-98, LOFT + 3.4, z), 0.22, rgb(150, 154, 162), Enum.Material.Metal)
	end
	for k = 1, ROOF - LOFT do
		local z0 = -50 + (k - 1) * 1.8
		Kit.span(m, "Stair", o + Vector3.new(-123, LOFT, z0), o + Vector3.new(-118, LOFT + k, z0 + 1.8), tread)
		Kit.span(m, "StairNose", o + Vector3.new(-123, LOFT + k - 0.12, z0), o + Vector3.new(-118, LOFT + k + 0.02, z0 + 0.2), look(CYAN, Enum.Material.Neon), SOFT)
	end
	Kit.span(m, "HatchRail", o + Vector3.new(hx0, ROOF, hz0 - 0.4), o + Vector3.new(hx1 + 0.4, ROOF + 3.2, hz0), glass)
	Kit.span(m, "HatchRail", o + Vector3.new(hx1, ROOF, hz0), o + Vector3.new(hx1 + 0.4, ROOF + 3.2, hz1), glass)
	-- The floor's dressing: a stud-textured pink runway in from the door, a stud wall in graphite
	-- under the room's name, and the sneaker wall: three lit shelves of pairs.
	studs(m, "Runway", o + Vector3.new(-96, 0.2, -28), o + Vector3.new(-61, 0.32, -24), rgb(170, 40, 120), SOFT)
	studs(m, "StudWall", o + Vector3.new(-96, 0.2, -59), o + Vector3.new(-64, 8, -58.6), rgb(44, 44, 50), SOFT)
	neonStrip(m, o + Vector3.new(-96, 8, -58.9), o + Vector3.new(-64, 8.3, -58.5), PINK)
	sign(m, o + Vector3.new(-80, 12, -58.7), o + Vector3.new(-80, 12, 0), 20, 4, {
		{ text = "THE DROP ROOM", size = 0.5, font = Brand.Fonts.display, color = PINK },
		{ text = "streetwear · sneakers · art toys", size = 0.22, font = Brand.Fonts.body, color = rgb(230, 230, 236) },
	})
	local shelf = look(rgb(200, 210, 225), Enum.Material.Glass, 0.2, 0.4)
	local colours = { rgb(240, 240, 244), rgb(20, 20, 24), rgb(255, 120, 40), PINK, CYAN, LIME, rgb(200, 30, 50), rgb(150, 154, 162) }
	for row = 0, 2 do
		local y = 3 + row * 3
		Kit.span(m, "Shelf", o + Vector3.new(-96, y, 17.4), o + Vector3.new(-64, y + 0.2, 19), shelf, SOFT)
		neonStrip(m, o + Vector3.new(-96, y - 0.1, 18.6), o + Vector3.new(-64, y, 18.9), PINK)
		for i = 0, 7 do
			local x = -93 + i * 4 + (row % 2) * 1.2
			local c = colours[(i + row * 3) % #colours + 1]
			P(m, "ShelfSole", Vector3.new(0.7, 0.25, 1.9), CFrame.new(o + Vector3.new(x, y + 0.33, 18.2)), rgb(246, 244, 238), Enum.Material.SmoothPlastic)
			P(m, "ShelfShoe", Vector3.new(0.66, 0.6, 1.4), CFrame.new(o + Vector3.new(x, y + 0.75, 18.4)), c, Enum.Material.Leather)
		end
	end
	neonStrip(m, o + Vector3.new(-123, H - 0.6, -59), o + Vector3.new(-61, H - 0.3, -58.7), CYAN)
	neonStrip(m, o + Vector3.new(-123, H - 0.6, 18.7), o + Vector3.new(-61, H - 0.3, 19), CYAN)
	-- Its lamps: two over the floor, two under the loft, two on it.
	pendant(m, o + Vector3.new(-80, 15.2, -40), rgb(255, 150, 220), 40, 1.3)
	pendant(m, o + Vector3.new(-80, 15.2, 6), rgb(255, 236, 244), 40, 1.2)
	for _, z in { -30, 0 } do
		local lamp = Kit.part(m, "LoftUnderlight", Vector3.new(3, 0.2, 3), CFrame.new(o + Vector3.new(-110, LOFT - 1.1, z)), look(rgb(255, 240, 250), Enum.Material.Neon), SOFT)
		Kit.pointLight(lamp, 1, 22, rgb(255, 236, 244))
	end
	pendant(m, o + Vector3.new(-110, 15.6, -18), rgb(255, 110, 200), 26, 1.1)
	pendant(m, o + Vector3.new(-110, 15.6, 10), rgb(140, 230, 255), 26, 1.1)
	-- The helipad on the roof (a way out), and the helicopter on it.
	local hb = LuxePlan.Banks[3]
	local cx, cz = (hb.minX + hb.maxX) / 2, (hb.minZ + hb.maxZ) / 2
	Kit.span(m, "Helipad", o + Vector3.new(hb.minX + 1, ROOF, hb.minZ + 1), o + Vector3.new(hb.maxX - 1, ROOF + 0.15, hb.maxZ - 1), look(rgb(34, 36, 40), Enum.Material.Concrete))
	local mark = look(rgb(236, 236, 240), Enum.Material.SmoothPlastic)
	Kit.span(m, "PadMark", o + Vector3.new(cx - 4, ROOF + 0.15, cz - 5), o + Vector3.new(cx - 2.6, ROOF + 0.2, cz + 5), mark, SOFT)
	Kit.span(m, "PadMark", o + Vector3.new(cx + 2.6, ROOF + 0.15, cz - 5), o + Vector3.new(cx + 4, ROOF + 0.2, cz + 5), mark, SOFT)
	Kit.span(m, "PadMark", o + Vector3.new(cx - 2.6, ROOF + 0.15, cz - 0.7), o + Vector3.new(cx + 2.6, ROOF + 0.2, cz + 0.7), mark, SOFT)
	bankRing(m, o, hb, ROOF + 0.15)
	helicopter(m, CFrame.new(o + Vector3.new(cx, ROOF + 0.15, cz)) * CFrame.Angles(0, math.rad(-90), 0))
	local padLight = Kit.part(m, "PadLight", Vector3.new(0.6, 0.3, 0.6), CFrame.new(o + Vector3.new(hb.minX + 1.5, ROOF + 0.3, hb.minZ + 1.5)), look(GOLD, Enum.Material.Neon), SOFT)
	Kit.pointLight(padLight, 1.2, 34, rgb(255, 226, 170))
	for _, z in { cz - 4.2, cz + 4.2 } do
		Kit.post(m, "SignPost", 4.6, 0.3, o + Vector3.new(hb.minX - 1.5, ROOF, z), BRUSHED)
	end
	sign(m, o + Vector3.new(hb.minX - 1.65, ROOF + 3.4, cz), o + Vector3.new(hb.minX - 30, ROOF + 3.4, cz), 9, 2.4, {
		{ text = "GET AWAY BY HELICOPTER", size = 0.42, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "step onto the pad with your haul", size = 0.26, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	})
end

-- The Garage (wing 5): off the Garden Hall's east door. Two show cars on turntables, a tool wall,
-- and the van by the roller door (a way out).
local function garage(arch: Instance, o: Vector3)
	local m = Kit.model(arch, "Garage")
	wall(m, o, 60, -60, 132, -60, H, CONCRETE)
	wall(m, o, 60, 30, 132, 30, H, CONCRETE)
	wall(m, o, 132, -60, 132, 30, H, CONCRETE)
	Kit.span(m, "GarageFloor", o + Vector3.new(61, 0, -59), o + Vector3.new(131, 0.2, 29), look(rgb(40, 42, 46), Enum.Material.SmoothPlastic, 0.12))
	Kit.span(m, "Ceiling", o + Vector3.new(61, H, -61), o + Vector3.new(133, H + 1, 31), L.blackLacquer)
	-- The roller door behind the van, its slats, a lime line over it.
	Kit.span(m, "RollerDoor", o + Vector3.new(106, 0.2, -59), o + Vector3.new(126, 12, -58.7), BRUSHED, SOFT)
	for i = 1, 7 do
		Kit.span(m, "Slat", o + Vector3.new(106, 0.2 + i * 1.5, -58.72), o + Vector3.new(126, 0.32 + i * 1.5, -58.6), GRAPHITE, SOFT)
	end
	neonStrip(m, o + Vector3.new(106, 12, -58.9), o + Vector3.new(126, 12.3, -58.5), LIME)
	local vb = LuxePlan.Banks[2]
	van(m, CFrame.new(o + Vector3.new(116.5, 0.2, (vb.minZ + vb.maxZ) / 2)))
	bankRing(m, o, vb, 0.2)
	sign(m, o + Vector3.new(116, 14.6, -58.4), o + Vector3.new(116, 14.6, 0), 12, 2.6, {
		{ text = "GET AWAY IN THE VAN", size = 0.42, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "walk up to it with your haul", size = 0.26, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	})
	supercar(m, CFrame.new(o + Vector3.new(86, 0.2, -6)), rgb(14, 14, 16), CYAN)
	supercar(m, CFrame.new(o + Vector3.new(110, 0.2, -6)) * CFrame.Angles(0, math.rad(180), 0), rgb(230, 230, 236), PINK)
	-- The tool wall: a stud-textured pegboard under a cyan line; tyres stacked in the corner.
	studs(m, "Pegboard", o + Vector3.new(130.6, 2, -20), o + Vector3.new(131, 10, 10), rgb(40, 40, 46), SOFT)
	neonStrip(m, o + Vector3.new(130.5, 10.2, -20), o + Vector3.new(130.9, 10.5, 10), CYAN)
	for _, z in { -55, -50.5 } do
		for i = 0, 3 do
			Kit.cylinder(m, "Tyre", 1.0, 3.6, CFrame.new(o + Vector3.new(65, 0.7 + i * 1.02, z)) * CFrame.Angles(0, 0, math.rad(90)), look(rgb(20, 20, 22), Enum.Material.Rubber))
		end
	end
	studs(m, "Bay", o + Vector3.new(74, 0.2, 16), o + Vector3.new(118, 0.26, 20), rgb(30, 60, 70), SOFT)
	neonStrip(m, o + Vector3.new(61, H - 0.6, 28.7), o + Vector3.new(131, H - 0.3, 29), CYAN)
	neonStrip(m, o + Vector3.new(61, H - 0.6, -59), o + Vector3.new(105, H - 0.3, -58.7), CYAN)
	pendant(m, o + Vector3.new(86, 15.2, -6), rgb(220, 240, 255), 34, 1.3)
	pendant(m, o + Vector3.new(110, 15.2, -6), rgb(255, 220, 240), 34, 1.3)
	pendant(m, o + Vector3.new(96, 15.2, 18), rgb(230, 240, 255), 30, 1.1)
	pendant(m, o + Vector3.new(116, 15.2, -44), rgb(255, 226, 170), 30, 1.1)
end

-- The Secret Stash (wing 6): behind a steel panel in the Strongroom's back wall, opened by the loose
-- gold bar on the last stack on the right. Returns the panel and the bar's prompt.
local function stash(arch: Instance, o: Vector3): (BasePart, ProximityPrompt)
	local m = Kit.model(arch, "SecretStash")
	local d = LuxePlan.Stash.door
	local SH = 13
	wall(m, o, -16, 131, -16, 150, SH, GRAPHITE)
	wall(m, o, 16, 131, 16, 150, SH, GRAPHITE)
	wall(m, o, -16, 150, 16, 150, SH, GRAPHITE)
	Kit.span(m, "StashFloor", o + Vector3.new(-15, 0, 131), o + Vector3.new(15, 0.2, 149), L.blackMarble)
	Kit.span(m, "StashCeiling", o + Vector3.new(-17, SH, 131), o + Vector3.new(17, SH + 1, 151), L.blackLacquer)
	-- The payoff: a wall of gold studs, cyan light along the top, cash on pallets by the door.
	studs(m, "GoldStuds", o + Vector3.new(-14, 0.2, 148.6), o + Vector3.new(14, 11, 149), GOLD, SOFT)
	neonStrip(m, o + Vector3.new(-15, SH - 0.6, 131), o + Vector3.new(-14.7, SH - 0.3, 149), CYAN)
	neonStrip(m, o + Vector3.new(14.7, SH - 0.6, 131), o + Vector3.new(15, SH - 0.3, 149), CYAN)
	for _, x in { -12, 12 } do
		Kit.span(m, "Pallet", o + Vector3.new(x - 2, 0.2, 133), o + Vector3.new(x + 2, 0.7, 137), L.walnut)
		Kit.span(m, "CashBlock", o + Vector3.new(x - 1.7, 0.7, 133.3), o + Vector3.new(x + 1.7, 3.2, 136.7), look(rgb(222, 206, 160), Enum.Material.Fabric))
		Kit.span(m, "CashBand", o + Vector3.new(x - 1.75, 1.7, 133.25), o + Vector3.new(x + 1.75, 2.2, 136.75), L.brass, SOFT)
	end
	local lamp = Kit.part(m, "StashLight", Vector3.new(4, 0.2, 4), CFrame.new(o + Vector3.new(0, SH - 0.2, 141)), look(rgb(200, 255, 245), Enum.Material.Neon), SOFT)
	Kit.pointLight(lamp, 1.3, 26, rgb(150, 255, 235))
	local warm = Kit.part(m, "StashGlow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(o + Vector3.new(0, 6, 147.5)), look(GOLD, Enum.Material.Neon), SOFT)
	Kit.pointLight(warm, 1, 16, GOLD)
	-- The panel: steel like the wall round it, with a thin gold seam the sharp-eyed will spot.
	local door = Kit.span(m, "StashDoor", o + Vector3.new(d.minX, 0, d.z - 1), o + Vector3.new(d.maxX, 12, d.z + 1), STEEL)
	for _, x in { d.minX, d.maxX } do
		Kit.span(m, "Seam", o + Vector3.new(x - 0.06, 0.2, d.z - 1.08), o + Vector3.new(x + 0.06, 12, d.z - 0.98), L.brass, SOFT)
	end
	-- The loose bar, a little askew on top of the last stack on the right, catching the light.
	local lv = LuxePlan.Stash.lever
	local bar = Kit.part(m, "LooseBar", Vector3.new(1.6, 0.8, 3), CFrame.new(o + lv + Vector3.new(-0.3, 3.2, 0)) * CFrame.Angles(0, math.rad(8), math.rad(-6)), L.brass, { collide = false })
	HolidayProps.sparkle(bar, GOLD, 1.5, 0.3)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PullBar"
	prompt.ActionText = "Pull it"
	prompt.ObjectText = "A loose gold bar"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = bar
	return door, prompt
end

-- The cameras: a black chrome head on a rod from the ceiling, a red eye, and a red light that
-- shows on the floor where it's looking (the server turns each head as it sweeps).
local function securityCameras(arch: Instance, o: Vector3): { BasePart }
	local heads: { BasePart } = {}
	for i, cam in LuxePlan.Cameras do
		local m = Kit.model(arch, "Camera" .. i)
		local at = o + cam.at
		local ceiling = if cam.wing == 6 then 13 else H
		Kit.post(m, "Mount", math.max(0.4, ceiling - cam.at.Y - 0.5), 0.3, at + Vector3.new(0, 0.5, 0), BLACK_CHROME, SOFT)
		local look0 = LuxePlan.cameraLook(cam, 0)
		local head = Kit.part(m, "Head", Vector3.new(1.1, 1.1, 2.2), CFrame.lookAt(at, at + look0 + Vector3.new(0, -0.35, 0)), BLACK_CHROME, SOFT)
		head:SetAttribute("Wing", cam.wing)
		local view = Instance.new("SpotLight")
		view.Name = "View"
		view.Face = Enum.NormalId.Front
		view.Angle = 48
		view.Range = 30
		view.Brightness = 1.2
		view.Color = rgb(255, 70, 60)
		view.Shadows = false
		view.Parent = head
		local lens = Instance.new("SurfaceGui")
		lens.Name = "Lens"
		lens.Face = Enum.NormalId.Front
		lens.LightInfluence = 0
		lens.CanvasSize = Vector2.new(60, 60)
		lens.Parent = head
		local eye = Instance.new("Frame")
		eye.AnchorPoint = Vector2.new(0.5, 0.5)
		eye.Position = UDim2.fromScale(0.5, 0.5)
		eye.Size = UDim2.fromScale(0.45, 0.45)
		eye.BackgroundColor3 = rgb(255, 40, 50)
		eye.BorderSizePixel = 0
		eye.Parent = lens
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = eye
		table.insert(heads, head)
	end
	return heads
end

-- The Strongroom's laser grid: a beam across the room for each (lit or dark as the server says),
-- an emitter at each end, and a dim line on the floor under it so it's never a surprise.
local function laserGrid(arch: Instance, o: Vector3): { BasePart }
	local beams: { BasePart } = {}
	local red = rgb(255, 40, 60)
	for _, l in LuxePlan.Lasers do
		local beam = Kit.span(arch, "Laser", o + Vector3.new(l.minX, l.y - 0.09, l.z - 0.09), o + Vector3.new(l.maxX, l.y + 0.09, l.z + 0.09), look(red, Enum.Material.Neon), SOFT)
		table.insert(beams, beam)
		for _, x in { l.minX - 0.4, l.maxX + 0.4 } do
			Kit.span(arch, "Emitter", o + Vector3.new(x - 0.4, l.y - 0.5, l.z - 0.5), o + Vector3.new(x + 0.4, l.y + 0.5, l.z + 0.5), BLACK_CHROME, SOFT)
		end
		Kit.span(arch, "LaserLine", o + Vector3.new(l.minX, 0.2, l.z - 0.12), o + Vector3.new(l.maxX, 0.24, l.z + 0.12), look(red:Lerp(rgb(0, 0, 0), 0.5), Enum.Material.Neon, nil, 0.5), SOFT)
	end
	return beams
end

---------------------------------------------------------------------------------------------------
-- The whole residence
---------------------------------------------------------------------------------------------------
export type Built = {
	root: Model,
	tops: { [number]: BasePart },
	pieces: Folder,
	guards: Folder,
	homeArch: BasePart?,
	cameras: { BasePart }?,
	lasers: { BasePart }?,
	stashDoor: BasePart?,
	stashLever: ProximityPrompt?,
}

function LuxeBuild.build(parent: Instance, o: Vector3, goHome: (player: Player) -> ()): Built
	local root = Kit.model(parent, "StealALuxe")
	root:SetAttribute("Attraction", "luxe")
	local arch = Kit.model(root, "Architecture")

	-- The ground, the courtyard's paving and its low walls, hedges and lamps.
	Kit.span(arch, "Ground", o + Vector3.new(-140, -2, -160), o + Vector3.new(140, 0, 160), L.wetStone)
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
	wall(arch, o, -60, -70, -60, 70, H, L.wall, { { LuxePlan.SideDoors[1][1], LuxePlan.SideDoors[1][2] } })
	wall(arch, o, 60, -70, 60, 70, H, L.wall, { { LuxePlan.SideDoors[2][1], LuxePlan.SideDoors[2][2] } })
	wall(arch, o, -60, 0, 60, 0, H, L.wall, { { LuxePlan.Doors[1][1], LuxePlan.Doors[1][2] }, { LuxePlan.Doors[2][1], LuxePlan.Doors[2][2] } })
	wall(arch, o, -60, 70, 60, 70, H, L.wall, { { LuxePlan.Doors[3][1], LuxePlan.Doors[3][2] } })
	wall(arch, o, -40, 70, -40, 130, H, STEEL)
	wall(arch, o, 40, 70, 40, 130, H, STEEL)
	wall(arch, o, -40, 130, 40, 130, H, STEEL, { { LuxePlan.Stash.door.minX, LuxePlan.Stash.door.maxX } })
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
	for _, x in { -3.3, 3 } do
		Kit.span(arch, "RunnerEdge", o + Vector3.new(x, 0.2, -69), o + Vector3.new(x + 0.3, 0.27, -1), L.brass, { collide = false, query = false, shadow = false })
	end
	-- (The Garden Hall's floor: black marble squares set in the cream, a chequer under the lamps.)
	for ix = 0, 13 do
		for iz = 0, 7 do
			if (ix + iz) % 2 == 0 then
				local x0, z0 = -56 + ix * 8, -67 + iz * 8.25
				if not (x0 > -8 and x0 < 4) then
					Kit.span(arch, "Chequer", o + Vector3.new(x0, 0.2, z0), o + Vector3.new(x0 + 8, 0.23, z0 + 8.25), L.blackMarble, { collide = false, query = false, shadow = false })
				end
			end
		end
	end
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
	-- The galleries' own light: brass sconces between the paintings on the outer walls, a
	-- wainscot of walnut under them, and a long runner down each gallery.
	local soft = { collide = false, query = false, shadow = false }
	for _, side in { -1, 1 } do
		local wx = side * 58.8
		Kit.span(arch, "Wainscot", o + Vector3.new(wx, 0.2, 1), o + Vector3.new(wx - side * 0.4, 4, 69), L.walnut, soft)
		Kit.span(arch, "ChairRail", o + Vector3.new(wx, 4, 1), o + Vector3.new(wx - side * 0.5, 4.3, 69), L.brass, soft)
		for z = 6, 66, 12 do
			local at = o + Vector3.new(wx - side * 0.3, 9.6, z + (if side > 0 then 6 else 0))
			Kit.part(arch, "SconcePlate", Vector3.new(0.2, 1.4, 0.7), CFrame.new(at), L.brass, soft)
			local shade = Kit.part(arch, "SconceShade", Vector3.new(0.8, 0.9, 0.8), CFrame.new(at + Vector3.new(-side * 0.6, 0.3, 0)), look(rgb(255, 214, 160), Enum.Material.Neon, nil, 0.3), soft)
			Kit.pointLight(shade, 0.6, 16, rgb(255, 214, 170))
		end
		Kit.span(arch, "GalleryRunner", o + Vector3.new(side * 30 - 3, 0.2, 4), o + Vector3.new(side * 30 + 3, 0.25, 66), L.carpet, soft)
		for _, ex in { -3.3, 3 } do
			Kit.span(arch, "RunnerEdge", o + Vector3.new(side * 30 + ex, 0.2, 4), o + Vector3.new(side * 30 + ex + 0.3, 0.27, 66), L.brass, soft)
		end
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
		chandelier(arch, o + at, rgb(214, 228, 255), 0.95)
	end
	Kit.span(arch, "StrongRunner", o + Vector3.new(-3, 0.2, 71), o + Vector3.new(3, 0.25, 120), L.carpet, { collide = false, query = false })
	-- The wings' names, over each doorway as you go in.
	type Sign = { name: string, at: Vector3, toward: Vector3 }
	local signs: { Sign } = {
		{ name = LuxePlan.Wings[1].name, at = Vector3.new(0, 13.6, -68.6), toward = Vector3.new(0, 13.6, 0) },
		{ name = LuxePlan.Wings[2].name, at = Vector3.new(-35, 13.6, 1.4), toward = Vector3.new(-35, 13.6, 40) },
		{ name = LuxePlan.Wings[2].name, at = Vector3.new(35, 13.6, 1.4), toward = Vector3.new(35, 13.6, 40) },
		{ name = LuxePlan.Wings[3].name, at = Vector3.new(0, 13.6, 71.4), toward = Vector3.new(0, 13.6, 100) },
		-- (The side doors' signs face the Garden Hall: read on the way to them.)
		{ name = LuxePlan.Wings[4].name, at = Vector3.new(-58.6, 13.6, -26), toward = Vector3.new(0, 13.6, -26) },
		{ name = LuxePlan.Wings[5].name, at = Vector3.new(58.6, 13.6, -26), toward = Vector3.new(0, 13.6, -26) },
	}
	for _, sign in signs do
		local board = Kit.part(arch, "WingSign", Vector3.new(12, 1.6, 0.2), CFrame.lookAt(o + sign.at, o + sign.toward), L.blackLacquer, { collide = false })
		Kit.engrave(board, Enum.NormalId.Front, { { text = string.upper(sign.name), size = 0.7, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 60, lit = false, brightness = 1.4 })
	end

	-- Build 78's wings, the cameras and the laser grid.
	dropRoom(arch, o)
	garage(arch, o)
	local stashDoor, stashLever = stash(arch, o)
	local cameras = securityCameras(arch, o)
	local lasers = laserGrid(arch, o)

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
	return {
		root = root,
		tops = tops,
		pieces = pieces,
		guards = guards,
		homeArch = homeArch,
		cameras = cameras,
		lasers = lasers,
		stashDoor = stashDoor,
		stashLever = stashLever,
	}
end

return LuxeBuild

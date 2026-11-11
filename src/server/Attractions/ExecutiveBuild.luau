--!strict
-- The Executive Suite, built (shared/Executive says where everything is):
--   The gallery hallway  black marble and an oxblood runner edged in brass, navy silk walls over
--                        walnut panelling, a coffered ceiling with opal pendants, paintings in gilt
--                        frames with picture lights, busts on marble plinths, sconces over the code
--                        terminals, and the cameras sweeping.
--   The vault door       steel banded in brass, a great wheel and its bolts, in a brass frame; the
--                        keypad beside it. (Its dressing goes with the door when the code is in.)
--   The Office           walnut floors and a vast navy rug, panelled walls with marble pilasters,
--                        bookcases and the bodyguards' double doors, a marble fireplace with club
--                        chairs before it, the drinks cabinet, crystal chandeliers, the city at
--                        night through a wall of mullioned glass, the partner's desk with its
--                        banker's lamp, the Executive's monogram over the lift, the safe.
-- Every piece of decoration is invisible to shots and to the guards' eyes (CanQuery off) and,
-- where it stands on the fight's floor, to bodies too: the game plays exactly as it did. The
-- guards, the bodyguards and the Executive himself are made by server/Attractions/Executive.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Furniture = require(ReplicatedStorage.Shared.Furniture)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Plan = require(ReplicatedStorage.Shared.Executive)
local Kit = require(script.Parent.Parent.World.Kit)
local Portal = require(script.Parent.Parent.Holidays.Portal)

local ExecutiveBuild = {}

export type Built = {
	root: Model,
	terminals: { ProximityPrompt },
	keypad: ProximityPrompt,
	door: BasePart,
	doorDressing: { BasePart }, -- the vault door's wheel, bolts and bands: they go with the door
	shield: BasePart,
	generators: { BasePart },
	safe: ProximityPrompt,
	liftDown: ProximityPrompt,
	cameras: { BasePart },
	actors: Folder, -- where the guards and the Executive stand
}

local L = Kit.Looks
local rgb = Color3.fromRGB
local V = Vector3.new
local GOLD = rgb(232, 182, 72)

local function look(colour: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Kit.Look
	return { color = colour, material = material, reflectance = reflectance, transparency = transparency } :: any
end

local BLACK_MARBLE = look(rgb(16, 16, 20), Enum.Material.Marble, 0.12)
local BONE_MARBLE = look(rgb(228, 220, 204), Enum.Material.Marble, 0.06)
local WALNUT = look(rgb(66, 40, 24), Enum.Material.Wood)
local DARK_WALNUT = look(rgb(38, 23, 15), Enum.Material.Wood)
local PLANKS = look(rgb(58, 36, 22), Enum.Material.WoodPlanks)
local SILK = look(rgb(24, 30, 54), Enum.Material.Fabric)
local RUNNER = look(rgb(96, 16, 30), Enum.Material.Fabric)
local RUG = look(rgb(18, 26, 54), Enum.Material.Fabric)
local RUG_GOLD = look(rgb(176, 132, 62), Enum.Material.Fabric)
local RUG_RED = look(rgb(110, 20, 34), Enum.Material.Fabric)
local LEATHER = look(rgb(70, 30, 20), Enum.Material.Leather)
local GREEN_LEATHER = look(rgb(24, 64, 44), Enum.Material.Leather)
local BRASS = L.brass
local STEEL = look(rgb(122, 128, 138), Enum.Material.Metal, 0.2)
local DARK_STEEL = look(rgb(64, 68, 76), Enum.Material.Metal, 0.15)
local GLASS = look(rgb(150, 190, 235), Enum.Material.Glass, 0.18, 0.72)
local WARM_GLOW = look(rgb(255, 232, 196), Enum.Material.Neon)
local OPAL = look(rgb(255, 214, 160), Enum.Material.Neon, nil, 0.3)
local CRYSTAL = look(rgb(236, 244, 255), Enum.Material.Glass, 0.3, 0.35)
local FIRE = look(rgb(255, 128, 40), Enum.Material.Neon)
local EMBER = look(rgb(200, 60, 20), Enum.Material.Neon, nil, 0.1)
local NIGHT = look(rgb(10, 12, 20), Enum.Material.SmoothPlastic)

-- Decoration: never in a shot's or a guard's way (query off); GHOST: nor a body's.
local DECO = { query = false }
local GHOST = { collide = false, query = false }
local GHOST_DARK = { collide = false, query = false, shadow = false }

local function prompt(parent: BasePart, name: string, action: string, object: string, hold: number?, reach: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = reach or 10
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Parent = parent
	return p
end

local function box(parent: Instance, name: string, o: Vector3, lo: Vector3, hi: Vector3, lk: Kit.Look, opts: { [string]: any }?): BasePart
	return Kit.span(parent, name, o + lo, o + hi, lk, opts)
end

-- A piece of the house's furniture, as decoration: no prompts, no seats, never in the way of a
-- shot (and, unless `solid`, of anyone walking).
local function piece(parent: Instance, kind: string, cf: CFrame, style: { [string]: any }?, scale: number?, solid: boolean?, unlit: boolean?): Model?
	local ok, m = pcall(function(): Model?
		return (Furniture.build(kind, parent, cf, style :: any, not unlit, scale))
	end)
	if not ok or not m then
		return nil
	end
	for _, d in (m :: Model):GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
			if not solid then
				d.CanCollide = false
			end
			if d:IsA("Seat") then
				(d :: Seat).Disabled = true
			end
			if unlit and d.Material == Enum.Material.Neon then
				d.Material = Enum.Material.Glass
			end
		end
	end
	return m
end

-- A painting in a gilt frame with its picture light: `at` is the middle of its face, `inward` the
-- way it faces. Two fields of colour, as the house's own modern pieces are.
local ART = {
	{ rgb(118, 22, 32), rgb(214, 128, 44), rgb(40, 14, 16) },
	{ rgb(22, 40, 72), rgb(196, 160, 96), rgb(12, 18, 32) },
	{ rgb(24, 62, 46), rgb(228, 206, 156), rgb(12, 26, 20) },
	{ rgb(64, 30, 72), rgb(236, 164, 124), rgb(26, 12, 30) },
	{ rgb(30, 30, 34), rgb(206, 170, 90), rgb(120, 22, 30) },
	{ rgb(150, 92, 40), rgb(40, 50, 80), rgb(236, 222, 196) },
	{ rgb(16, 70, 90), rgb(240, 214, 160), rgb(10, 24, 34) },
	{ rgb(90, 18, 40), rgb(26, 26, 30), rgb(232, 196, 120) },
}
local function painting(parent: Instance, at: Vector3, inward: Vector3, w: number, h: number, palette: { Color3 })
	local m = Kit.model(parent, "Painting")
	local face = CFrame.lookAt(at, at + inward)
	Kit.part(m, "Canvas", V(w, h, 0.2), face, look(palette[3], Enum.Material.Fabric), GHOST_DARK)
	Kit.part(m, "FieldHigh", V(w * 0.82, h * 0.5, 0.06), face * CFrame.new(0, h * 0.2, -0.12), look(palette[1], Enum.Material.Fabric), GHOST_DARK)
	Kit.part(m, "FieldLow", V(w * 0.82, h * 0.28, 0.06), face * CFrame.new(0, -h * 0.28, -0.12), look(palette[2], Enum.Material.Fabric), GHOST_DARK)
	local t = 0.45
	Kit.part(m, "FrameTop", V(w + 2 * t, t, 0.4), face * CFrame.new(0, h / 2 + t / 2, -0.05), BRASS, GHOST_DARK)
	Kit.part(m, "FrameBottom", V(w + 2 * t, t, 0.4), face * CFrame.new(0, -h / 2 - t / 2, -0.05), BRASS, GHOST_DARK)
	Kit.part(m, "FrameLeft", V(t, h, 0.4), face * CFrame.new(-w / 2 - t / 2, 0, -0.05), BRASS, GHOST_DARK)
	Kit.part(m, "FrameRight", V(t, h, 0.4), face * CFrame.new(w / 2 + t / 2, 0, -0.05), BRASS, GHOST_DARK)
	-- The picture light: a brass hood, glowing underneath.
	Kit.part(m, "PictureLight", V(w * 0.45, 0.2, 0.45), face * CFrame.new(0, h / 2 + 0.9, -0.42), L.darkBrass, GHOST_DARK)
end

-- A brass wall sconce with a glowing shade.
local function sconce(parent: Instance, at: Vector3, inward: Vector3, brightness: number, range: number)
	local m = Kit.model(parent, "Sconce")
	local face = CFrame.lookAt(at, at + inward)
	Kit.part(m, "Plate", V(0.7, 1.5, 0.15), face, BRASS, GHOST_DARK)
	Kit.part(m, "Arm", V(0.18, 0.18, 0.9), face * CFrame.new(0, -0.2, -0.45), BRASS, GHOST_DARK)
	local shade = Kit.part(m, "Shade", V(0.8, 0.9, 0.8), face * CFrame.new(0, 0.2, -0.95), OPAL, GHOST_DARK)
	Kit.part(m, "Cap", V(0.9, 0.12, 0.9), face * CFrame.new(0, 0.7, -0.95), BRASS, GHOST_DARK)
	Kit.pointLight(shade, brightness, range, rgb(255, 222, 176))
end

-- A crystal chandelier hanging from the ceiling at `top`.
local function chandelier(parent: Instance, top: Vector3, size: number, brightness: number, range: number)
	local m = Kit.model(parent, "Chandelier")
	local k = size
	Kit.part(m, "Chain", V(0.16, 2.2 * k, 0.16), CFrame.new(top - V(0, 1.1 * k, 0)), BRASS, GHOST_DARK)
	Kit.part(m, "Canopy", V(1.4 * k, 0.25, 1.4 * k), CFrame.new(top - V(0, 0.12, 0)), BRASS, GHOST_DARK)
	local heart = top - V(0, 3.2 * k, 0)
	local body = Kit.ball(m, "Crystal", 1.6 * k, heart, CRYSTAL, GHOST_DARK)
	Kit.cylinder(m, "Ring", 0.25, 4.6 * k, CFrame.new(heart - V(0, 0.5 * k, 0)) * CFrame.Angles(0, 0, math.rad(90)), BRASS, GHOST_DARK)
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local rim = heart + V(math.cos(a) * 2.1 * k, -0.2 * k, math.sin(a) * 2.1 * k)
		Kit.part(m, "Candle", V(0.22 * k, 0.6 * k, 0.22 * k), CFrame.new(rim), BONE_MARBLE, GHOST_DARK)
		Kit.part(m, "Flame", V(0.16 * k, 0.26 * k, 0.16 * k), CFrame.new(rim + V(0, 0.42 * k, 0)), WARM_GLOW, GHOST_DARK)
		Kit.ball(m, "Drop", 0.34 * k, rim - V(0, 0.75 * k, 0), CRYSTAL, GHOST_DARK)
	end
	Kit.ball(m, "Pendant", 0.6 * k, heart - V(0, 1.6 * k, 0), CRYSTAL, GHOST_DARK)
	Kit.pointLight(body, brightness, range, rgb(255, 230, 196))
end

-- Shows the vault door (and its dressing), or opens it.
function ExecutiveBuild.door(b: Built, shut: boolean)
	b.door.CanCollide = shut
	b.door.Transparency = if shut then 0 else 1
	for _, p in b.doorDressing do
		p.Transparency = if shut then (tonumber(p:GetAttribute("Shown")) or 0) else 1
	end
end

function ExecutiveBuild.build(parent: Instance, o: Vector3, goHome: (player: Player) -> ()): Built
	local root = Kit.model(parent, "ExecutiveSuite")
	root:SetAttribute("Attraction", "executive")
	local arch = Kit.model(root, "Architecture")
	local dress = Kit.model(root, "Dressing")
	local H = Plan.HEIGHT
	local hall, office = Plan.Hall, Plan.Office

	---------------------------------------------------------------------------------------------
	-- The gallery hallway
	---------------------------------------------------------------------------------------------
	box(arch, "HallFloor", o, V(hall.minX, -1, hall.minZ), V(hall.maxX, 0, hall.maxZ), BLACK_MARBLE)
	box(dress, "HallBorder", o, V(hall.minX, 0, hall.minZ), V(hall.minX + 1.4, 0.04, hall.maxZ), BONE_MARBLE, GHOST)
	box(dress, "HallBorder", o, V(hall.maxX - 1.4, 0, hall.minZ), V(hall.maxX, 0.04, hall.maxZ), BONE_MARBLE, GHOST)
	box(dress, "Runner", o, V(-3, 0, hall.minZ + 4), V(3, 0.06, hall.maxZ), RUNNER, GHOST)
	box(dress, "RunnerEdge", o, V(-3.3, 0, hall.minZ + 4), V(-3, 0.08, hall.maxZ), BRASS, GHOST)
	box(dress, "RunnerEdge", o, V(3, 0, hall.minZ + 4), V(3.3, 0.08, hall.maxZ), BRASS, GHOST)
	for z = hall.minZ + 10, hall.maxZ - 6, 14 do
		-- (A brass star set in the runner every few strides.)
		Kit.part(dress, "RunnerStar", V(1.4, 0.04, 1.4), CFrame.new(o + V(0, 0.08, z)) * CFrame.Angles(0, math.rad(45), 0), BRASS, GHOST_DARK)
	end
	for _, side in { -1, 1 } do
		local inner = if side < 0 then hall.minX else hall.maxX
		local wx = if side < 0 then hall.minX - 1 else hall.maxX
		box(arch, "HallWall", o, V(wx, 0, hall.minZ), V(wx + 1, H, hall.maxZ), SILK)
		box(dress, "Wainscot", o, V(inner, 0, hall.minZ), V(inner - side * 0.3, 4.2, hall.maxZ), WALNUT, DECO)
		box(dress, "Skirting", o, V(inner, 0, hall.minZ), V(inner - side * 0.42, 0.55, hall.maxZ), DARK_WALNUT, DECO)
		box(dress, "ChairRail", o, V(inner, 4.2, hall.minZ), V(inner - side * 0.45, 4.48, hall.maxZ), BRASS, DECO)
		box(dress, "Cornice", o, V(inner, H - 0.9, hall.minZ), V(inner - side * 0.55, H, hall.maxZ), WALNUT, DECO)
		box(dress, "CorniceGilt", o, V(inner, H - 1.08, hall.minZ), V(inner - side * 0.6, H - 0.9, hall.maxZ), BRASS, DECO)
		for z = hall.minZ + 3, hall.maxZ - 3, 6 do
			box(dress, "Stile", o, V(inner - side * 0.3, 0.55, z - 0.16), V(inner - side * 0.38, 4.2, z + 0.16), DARK_WALNUT, GHOST_DARK)
		end
	end
	box(arch, "HallEnd", o, V(hall.minX - 1, 0, hall.minZ - 1), V(hall.maxX + 1, H, hall.minZ), SILK)
	-- The coffered ceiling: walnut beams over black lacquer, opal pendants down the middle.
	box(arch, "HallCeiling", o, V(hall.minX - 1, H, hall.minZ - 1), V(hall.maxX + 1, H + 1, hall.maxZ), L.blackLacquer, { shadow = false })
	for _, x in { -4.5, 4.5 } do
		box(dress, "Beam", o, V(x - 0.5, H - 0.8, hall.minZ), V(x + 0.5, H, hall.maxZ), WALNUT, GHOST_DARK)
	end
	for z = hall.minZ + 9, hall.maxZ - 2, 9 do
		box(dress, "Beam", o, V(hall.minX, H - 0.8, z - 0.5), V(hall.maxX, H, z + 0.5), WALNUT, GHOST_DARK)
	end
	for z = hall.minZ + 18, hall.maxZ - 8, 27 do
		local m = Kit.model(dress, "Pendant")
		Kit.part(m, "Stem", V(0.14, 2.6, 0.14), CFrame.new(o + V(0, H - 1.3, z)), BRASS, GHOST_DARK)
		local globe = Kit.ball(m, "Globe", 1.2, o + V(0, H - 3.2, z), OPAL, GHOST_DARK)
		Kit.cylinder(m, "Gallery", 0.2, 1.7, CFrame.new(o + V(0, H - 2.5, z)) * CFrame.Angles(0, 0, math.rad(90)), BRASS, GHOST_DARK)
		Kit.pointLight(globe, 0.75, 22, rgb(255, 226, 184))
	end
	-- The paintings: on both walls, clear of the cameras and above the terminals.
	local slots: { { number } } = {
		{ -1, -136 }, { -1, -108 }, { -1, -84 }, { -1, -34 },
		{ 1, -136 }, { 1, -84 }, { 1, -58 }, { 1, -32 },
	}
	for i, s in slots do
		local x = s[1] * (hall.maxX - 0.35)
		painting(dress, o + V(x, 8.9, s[2]), V(-s[1], 0, 0), 7, 4.6, ART[i])
	end
	-- Sconces over every terminal, and across from each.
	for _, t in Plan.Terminals do
		for _, sx in { -1, 1 } do
			sconce(dress, o + V(sx * (hall.maxX - 0.2), 7.2, t.Z), V(-sx, 0, 0), 0.7, 16)
		end
	end
	-- Busts on marble plinths across from the terminals: a little cover from the guards' eyes.
	for i, t in Plan.Terminals do
		local x = (if t.X < 0 then 1 else -1) * (hall.maxX - 1.6)
		local z = t.Z + (if i % 2 == 0 then 9 else -9)
		local m = Kit.model(dress, "Bust")
		Kit.part(m, "Foot", V(2.4, 0.3, 2.4), CFrame.new(o + V(x, 0.15, z)), BRASS, DECO)
		piece(m, "sculpture", CFrame.lookAt(o + V(x, 0.3, z), o + V(0, 0.3, z)), { model = "bust" }, 1.25, true)
	end
	-- The terminals: brass lecterns with a green screen each.
	local terminals: { ProximityPrompt } = {}
	for i, at in Plan.Terminals do
		local m = Kit.model(arch, "Terminal" .. i)
		local inward = if at.X < 0 then 1 else -1
		local base = o + at + V(inward * 1.2, 0, 0)
		Kit.part(m, "Stand", V(1.4, 3.4, 1.4), CFrame.new(base + V(0, 1.7, 0)), L.brass)
		Kit.part(m, "Foot", V(2, 0.3, 2), CFrame.new(base + V(0, 0.15, 0)), DARK_WALNUT, DECO)
		Kit.part(m, "Bezel", V(0.3, 1.9, 2.5), CFrame.new(base + V(inward * 0.05, 4.1, 0)), L.blackLacquer, DECO)
		local screen = Kit.part(m, "Screen", V(0.2, 1.6, 2.2), CFrame.new(base + V(inward * 0.2, 4.1, 0)), look(rgb(60, 255, 170), Enum.Material.Neon, nil, 0.2), { collide = false })
		screen:SetAttribute("Terminal", i)
		terminals[i] = prompt(screen, "Terminal", "Read it", "A code terminal (" .. i .. " of 4)", 1.2, 8)
		CollectionService:AddTag(screen, "ExecTerminal")
	end
	-- The cameras: a dark dome on an arm, with a red eye.
	local cameras: { BasePart } = {}
	for i, c in Plan.Cameras do
		local m = Kit.model(arch, "Camera" .. i)
		Kit.part(m, "Arm", V(1.4, 0.3, 0.3), CFrame.new(o + c.at + V(if c.at.X > 0 then 0.5 else -0.5, 0.6, 0)), STEEL, { collide = false })
		local head = Kit.part(m, "Lens", V(1.2, 1, 1.6), CFrame.new(o + c.at), L.blackLacquer, { collide = false })
		head:SetAttribute("Camera", i)
		CollectionService:AddTag(head, "ExecCamera")
		local eye = Kit.part(m, "Eye", V(0.3, 0.3, 0.3), CFrame.new(o + c.at + V(0, 0, 0.8)), look(rgb(255, 40, 40), Enum.Material.Neon), { collide = false, query = false, shadow = false })
		eye.Parent = head
		cameras[i] = head
	end
	-- Over the lift you came up in: the Suite's name, in gold.
	local crest = Kit.part(dress, "Crest", V(10, 2, 0.2), CFrame.lookAt(o + V(0, H - 3, hall.minZ + 0.15), o + V(0, H - 3, hall.minZ + 10)), L.blackLacquer, GHOST_DARK)
	Kit.engrave(crest, Enum.NormalId.Front, {
		{ text = "THE EXECUTIVE SUITE", size = 0.55, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "BY INVITATION ONLY", size = 0.28, font = Brand.Fonts.bodyBold, color = rgb(200, 170, 110) },
	}, { ppu = 60, lit = false, brightness = 1.3 })
	for _, x in { -5.3, 5.3 } do
		Kit.part(dress, "CrestGilt", V(0.3, 2.4, 0.3), CFrame.new(o + V(x, H - 3, hall.minZ + 0.2)), BRASS, GHOST_DARK)
	end
	-- Palms either side of the vault door.
	for _, x in { -7.4, 7.4 } do
		piece(dress, "plant", CFrame.new(o + V(x, 0, Plan.Door.z - 3)), { model = "palm" }, 1.2, true)
	end

	---------------------------------------------------------------------------------------------
	-- The vault door
	---------------------------------------------------------------------------------------------
	local door = box(arch, "CodeDoor", o, V(Plan.Door.minX, 0, Plan.Door.z - 0.5), V(Plan.Door.maxX, 10, Plan.Door.z + 0.5), STEEL)
	for _, side in { { hall.minX - 1, Plan.Door.minX }, { Plan.Door.maxX, hall.maxX + 1 } } do
		box(arch, "DoorWall", o, V(side[1], 0, Plan.Door.z - 0.5), V(side[2], H, Plan.Door.z + 0.5), SILK)
	end
	box(arch, "DoorLintel", o, V(Plan.Door.minX, 10, Plan.Door.z - 0.5), V(Plan.Door.maxX, H, Plan.Door.z + 0.5), SILK)
	-- Its brass frame (it stays), and its dressing (it goes with the door).
	local fz = Plan.Door.z - 0.75
	box(dress, "DoorFrame", o, V(Plan.Door.minX - 1, 0, fz - 0.25), V(Plan.Door.minX, 11, fz + 0.25), BRASS, DECO)
	box(dress, "DoorFrame", o, V(Plan.Door.maxX, 0, fz - 0.25), V(Plan.Door.maxX + 1, 11, fz + 0.25), BRASS, DECO)
	box(dress, "DoorFrame", o, V(Plan.Door.minX - 1, 10, fz - 0.25), V(Plan.Door.maxX + 1, 11, fz + 0.25), BRASS, DECO)
	local doorDressing: { BasePart } = {}
	local function onDoor(p: BasePart)
		p:SetAttribute("Shown", p.Transparency)
		table.insert(doorDressing, p)
	end
	local face = o + V(0, 5, Plan.Door.z - 0.62)
	local out = CFrame.lookAt(face, face - V(0, 0, 1))
	for _, y in { 2.2, 7.8 } do
		onDoor(Kit.part(dress, "Band", V(7.6, 0.6, 0.16), CFrame.new(o + V(0, y, Plan.Door.z - 0.56)), DARK_STEEL, GHOST))
	end
	onDoor(Kit.cylinder(dress, "Wheel", 0.3, 4.4, out * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.rad(90), 0), BRASS, GHOST))
	onDoor(Kit.cylinder(dress, "WheelInner", 0.34, 3.4, out * CFrame.new(0, 0, -0.12) * CFrame.Angles(0, math.rad(90), 0), DARK_STEEL, GHOST))
	onDoor(Kit.cylinder(dress, "Hub", 0.8, 1.2, out * CFrame.new(0, 0, -0.35) * CFrame.Angles(0, math.rad(90), 0), BRASS, GHOST))
	for i = 0, 2 do
		onDoor(Kit.part(dress, "Spoke", V(3.6, 0.28, 0.2), out * CFrame.new(0, 0, -0.42) * CFrame.Angles(0, 0, math.rad(i * 60)), BRASS, GHOST))
	end
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2
		onDoor(Kit.cylinder(dress, "Bolt", 0.3, 0.42, out * CFrame.new(math.cos(a) * 3.1, math.sin(a) * 3.1, -0.15) * CFrame.Angles(0, math.rad(90), 0), BRASS, GHOST))
	end
	for _, x in { -6.4, 6.4 } do
		sconce(dress, o + V(x, 8.2, Plan.Door.z - 0.6), V(0, 0, -1), 0.9, 14)
	end
	local pad = Kit.part(arch, "Keypad", V(1.2, 1.6, 0.3), CFrame.new(o + V(Plan.Door.maxX + 1.6, 4.5, Plan.Door.z - 0.8)), look(rgb(30, 30, 34), Enum.Material.Metal), { collide = false })
	Kit.part(dress, "KeypadGlow", V(0.9, 0.2, 0.05), CFrame.new(o + V(Plan.Door.maxX + 1.6, 5.05, Plan.Door.z - 0.97)), look(rgb(90, 255, 180), Enum.Material.Neon), GHOST_DARK)
	Kit.part(dress, "KeypadPlate", V(1.6, 2.1, 0.12), CFrame.new(o + V(Plan.Door.maxX + 1.6, 4.5, Plan.Door.z - 0.62)), BRASS, GHOST_DARK)
	local keypad = prompt(pad, "Keypad", "Enter the code", "The Executive's door", 0, 8)
	local sign = Kit.part(arch, "DoorSign", V(8, 1.4, 0.2), CFrame.lookAt(o + V(0, 12.5, Plan.Door.z - 0.7), o + V(0, 12.5, Plan.Door.z - 20)), L.blackLacquer, { collide = false })
	Kit.engrave(sign, Enum.NormalId.Front, { { text = "THE EXECUTIVE", size = 0.7, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 60, lit = false, brightness = 1.4 })
	Kit.part(dress, "SignGilt", V(8.5, 1.9, 0.12), CFrame.new(o + V(0, 12.5, Plan.Door.z - 0.62)), BRASS, GHOST_DARK)

	---------------------------------------------------------------------------------------------
	-- The Office
	---------------------------------------------------------------------------------------------
	local OH = H + 4
	box(arch, "OfficeFloor", o, V(office.minX, -1, office.minZ), V(office.maxX, 0, office.maxZ), PLANKS)
	-- The rug: navy, a gold border and an oxblood one inside it (flat: nothing trips on it).
	box(dress, "Rug", o, V(-20, 0, -8), V(20, 0.05, 40), RUG, GHOST_DARK)
	for _, r in { { 1.6, RUG_GOLD }, { 3.2, RUG_RED } } :: { { any } } do
		local inset, lk = r[1], r[2]
		box(dress, "RugBorder", o, V(-20 + inset, 0, -8 + inset), V(20 - inset, 0.07, -7 + inset), lk, GHOST_DARK)
		box(dress, "RugBorder", o, V(-20 + inset, 0, 39 - inset), V(20 - inset, 0.07, 40 - inset), lk, GHOST_DARK)
		box(dress, "RugBorder", o, V(-20 + inset, 0, -8 + inset), V(-19 + inset, 0.07, 40 - inset), lk, GHOST_DARK)
		box(dress, "RugBorder", o, V(19 - inset, 0, -8 + inset), V(20 - inset, 0.07, 40 - inset), lk, GHOST_DARK)
	end
	Kit.part(dress, "RugMedallion", V(7, 0.08, 7), CFrame.new(o + V(0, 0.05, 16)) * CFrame.Angles(0, math.rad(45), 0), RUG_GOLD, GHOST_DARK)
	Kit.part(dress, "RugMedallionInner", V(4.4, 0.1, 4.4), CFrame.new(o + V(0, 0.06, 16)) * CFrame.Angles(0, math.rad(45), 0), RUG_RED, GHOST_DARK)
	-- The walls: walnut panelling, marble pilasters, a gilt cornice.
	for _, side in { -1, 1 } do
		local wx = if side < 0 then office.minX - 1 else office.maxX
		local inner = if side < 0 then office.minX else office.maxX
		box(arch, "OfficeWall", o, V(wx, 0, Plan.Door.z), V(wx + 1, OH, office.maxZ), WALNUT)
		box(dress, "Skirting", o, V(inner, 0, Plan.Door.z + 0.5), V(inner - side * 0.45, 0.7, office.maxZ), DARK_WALNUT, DECO)
		box(dress, "Cornice", o, V(inner, OH - 1.1, Plan.Door.z + 0.5), V(inner - side * 0.7, OH, office.maxZ), WALNUT, DECO)
		box(dress, "CorniceGilt", o, V(inner, OH - 1.3, Plan.Door.z + 0.5), V(inner - side * 0.75, OH - 1.1, office.maxZ), BRASS, DECO)
		box(dress, "PictureRail", o, V(inner, 12.6, Plan.Door.z + 0.5), V(inner - side * 0.3, 12.85, office.maxZ), BRASS, DECO)
		for _, z in { -12, 12, 27, 50 } do
			box(dress, "Pilaster", o, V(inner, 0, z - 0.9), V(inner - side * 0.8, OH - 1.3, z + 0.9), BONE_MARBLE, DECO)
			box(dress, "PilasterCap", o, V(inner, OH - 2.1, z - 1.1), V(inner - side * 1, OH - 1.3, z + 1.1), BRASS, DECO)
			box(dress, "PilasterBase", o, V(inner, 0, z - 1.1), V(inner - side * 1, 0.9, z + 1.1), BRASS, DECO)
		end
		-- The bodyguards' double doors (they come in through them).
		for _, gz in { 0, 40 } do
			local m = Kit.model(dress, "GuardDoors")
			box(m, "Leaf", o, V(inner, 0, gz - 2.6), V(inner - side * 0.35, 9.4, gz - 0.05), DARK_WALNUT, GHOST)
			box(m, "Leaf", o, V(inner, 0, gz + 0.05), V(inner - side * 0.35, 9.4, gz + 2.6), DARK_WALNUT, GHOST)
			box(m, "Architrave", o, V(inner, 9.4, gz - 3.3), V(inner - side * 0.5, 10.2, gz + 3.3), BRASS, GHOST)
			box(m, "Architrave", o, V(inner, 0, gz - 3.3), V(inner - side * 0.5, 9.4, gz - 2.6), BRASS, GHOST)
			box(m, "Architrave", o, V(inner, 0, gz + 2.6), V(inner - side * 0.5, 9.4, gz + 3.3), BRASS, GHOST)
			for _, dz in { -0.55, 0.55 } do
				Kit.part(m, "Handle", V(0.3, 1.4, 0.2), CFrame.new(o + V(inner - side * 0.5, 4.6, gz + dz)), BRASS, GHOST_DARK)
			end
		end
		-- Sconces between the pilasters.
		for _, z in { 0.5, 19.5, 38.5 } do
			sconce(dress, o + V(inner - side * 0.2, 10.4, if z == 0.5 then -6 elseif z == 38.5 then 33 else z), V(-side, 0, 0), 0.6, 18)
		end
	end
	-- Bookcases along the walls, between the doors.
	for _, side in { -1, 1 } do
		local x = side * (office.maxX - 1.4)
		local facing = V(-side, 0, 0)
		for _, z in { 19.5, if side < 0 then 56 else nil } :: { number? } do
			if z then
				piece(dress, "shelf", CFrame.lookAt(o + V(x, 0, z), o + V(x, 0, z) + facing), { model = "library" }, 1.5, true)
			end
		end
	end
	-- The front wall: the fireplace on the left of the door, the drinks cabinet on the right.
	for _, side in { { office.minX - 1, hall.minX - 1 }, { hall.maxX + 1, office.maxX + 1 } } do
		box(arch, "OfficeFront", o, V(side[1], 0, Plan.Door.z - 0.5), V(side[2], OH, Plan.Door.z + 0.5), WALNUT)
	end
	box(arch, "OfficeLintel", o, V(hall.minX - 1, H, Plan.Door.z - 0.5), V(hall.maxX + 1, OH, Plan.Door.z + 0.5), WALNUT)
	local fx, fz2 = -22, Plan.Door.z + 0.5
	local fire = Kit.model(dress, "Fireplace")
	box(fire, "Surround", o, V(fx - 6.5, 0, fz2), V(fx + 6.5, 9, fz2 + 1.6), BONE_MARBLE, DECO)
	box(fire, "Firebox", o, V(fx - 4, 0.4, fz2 + 1.1), V(fx + 4, 5.6, fz2 + 1.65), look(rgb(14, 12, 12), Enum.Material.Slate), GHOST_DARK)
	box(fire, "FireboxGilt", o, V(fx - 4.4, 5.6, fz2 + 1.55), V(fx + 4.4, 6.0, fz2 + 1.75), BRASS, GHOST_DARK)
	box(fire, "Mantel", o, V(fx - 7.2, 9, fz2), V(fx + 7.2, 9.6, fz2 + 2.2), BRASS, DECO)
	box(fire, "Hearth", o, V(fx - 7.2, 0, fz2 + 1.6), V(fx + 7.2, 0.25, fz2 + 4), BLACK_MARBLE, GHOST)
	for i = -3, 3 do
		Kit.part(fire, "Flame", V(0.85, 1.6 + (3 - math.abs(i)) * 0.55, 0.3), CFrame.new(o + V(fx + i * 1.0, 1.6, fz2 + 1.3)), if i % 2 == 0 then FIRE else EMBER, GHOST_DARK)
	end
	local log = Kit.part(fire, "Logs", V(6, 0.7, 0.9), CFrame.new(o + V(fx, 0.8, fz2 + 1.35)), look(rgb(40, 24, 16), Enum.Material.Wood), GHOST_DARK)
	Kit.pointLight(log, 1.8, 26, rgb(255, 140, 60))
	for _, x in { -4.6, 4.6 } do
		Kit.part(fire, "Candlestick", V(0.3, 1.4, 0.3), CFrame.new(o + V(fx + x, 10.3, fz2 + 1.2)), BRASS, GHOST_DARK)
		Kit.part(fire, "CandleFlame", V(0.2, 0.32, 0.2), CFrame.new(o + V(fx + x, 11.15, fz2 + 1.2)), WARM_GLOW, GHOST_DARK)
	end
	painting(fire, o + V(fx, 13.6, fz2 + 0.18), V(0, 0, 1), 8, 5, ART[5])
	piece(dress, "chair", CFrame.lookAt(o + V(fx - 4.5, 0, -10.5), o + V(fx, 0, fz2)), { model = "club", material = "Leather", colour = rgb(84, 40, 24) }, 1.25, false)
	piece(dress, "chair", CFrame.lookAt(o + V(fx + 4.5, 0, -10.5), o + V(fx, 0, fz2)), { model = "club", material = "Leather", colour = rgb(84, 40, 24) }, 1.25, false)
	piece(dress, "bar", CFrame.lookAt(o + V(22, 0, fz2 + 1.6), o + V(22, 0, fz2 + 20)), { model = "walnut" }, 1.4, true, true)
	painting(dress, o + V(22, 11.4, fz2 + 0.18), V(0, 0, 1), 8, 5, ART[2])
	piece(dress, "plant", CFrame.new(o + V(29, 0, -17)), { model = "fiddle" }, 1.3, true)
	piece(dress, "plant", CFrame.new(o + V(-29.5, 0, -17)), { model = "olive" }, 1.3, true)
	-- The coffered ceiling and the chandeliers.
	box(arch, "OfficeCeiling", o, V(office.minX - 1, OH, Plan.Door.z - 0.5), V(office.maxX + 1, OH + 1, office.maxZ + 1), L.blackLacquer, { shadow = false })
	for _, x in { -16, 0, 16 } do
		box(dress, "Beam", o, V(x - 0.6, OH - 1, Plan.Door.z + 0.5), V(x + 0.6, OH, office.maxZ), WALNUT, GHOST_DARK)
	end
	for z = -8, 56, 16 do
		box(dress, "Beam", o, V(office.minX, OH - 1, z - 0.6), V(office.maxX, OH, z + 0.6), WALNUT, GHOST_DARK)
	end
	chandelier(dress, o + V(-16, OH - 1, 8), 1.25, 1.3, 40)
	chandelier(dress, o + V(16, OH - 1, 8), 1.25, 1.3, 40)
	chandelier(dress, o + V(0, OH - 1, 28), 1.5, 1.5, 46)

	-- The window wall over the city: mullioned glass, a walnut sill, and the night outside.
	box(arch, "Window", o, V(office.minX - 1, 0, office.maxZ), V(office.maxX + 1, OH, office.maxZ + 1), GLASS)
	box(dress, "Sill", o, V(office.minX, 0, office.maxZ - 0.6), V(office.maxX, 1.4, office.maxZ), WALNUT, DECO)
	box(dress, "SillTop", o, V(office.minX, 1.4, office.maxZ - 0.8), V(office.maxX, 1.6, office.maxZ), BRASS, DECO)
	for x = office.minX, office.maxX, 8 do
		box(dress, "Mullion", o, V(x - 0.25, 1.6, office.maxZ - 0.3), V(x + 0.25, OH, office.maxZ + 0.2), DARK_STEEL, GHOST_DARK)
	end
	box(dress, "Transom", o, V(office.minX, 14.6, office.maxZ - 0.3), V(office.maxX, 15, office.maxZ + 0.2), DARK_STEEL, GHOST_DARK)
	local city = Kit.model(dress, "City")
	-- (The same city every time: a small seeded sequence.)
	local seed = 1931
	local rng = {
		NextNumber = function(_: any, a: number?, b: number?): number
			seed = (seed * 1103515245 + 12345) % 2147483648
			local u = seed / 2147483648
			if a and b then
				return a + (b - a) * u
			end
			return u
		end,
	}
	for i = 1, 30 do
		local x = rng:NextNumber(-300, 300)
		local z = office.maxZ + rng:NextNumber(70, 320)
		local w, d = rng:NextNumber(16, 36), rng:NextNumber(16, 36)
		local top = rng:NextNumber(-20, 120) - (if math.abs(x) < 40 and z < office.maxZ + 140 then 50 else 0)
		local tower = box(city, "Tower", o, V(x - w / 2, -260, z - d / 2), V(x + w / 2, top, z + d / 2), NIGHT, GHOST_DARK)
		tower.CastShadow = false
		local rows = math.floor((top + 200) / 14)
		for r = 1, math.min(rows, 9) do
			if rng:NextNumber() < 0.75 then
				local y = top - 6 - r * rng:NextNumber(9, 15)
				local warm = rng:NextNumber() < 0.7
				local lit = look(if warm then rgb(255, 214, 150) else rgb(170, 210, 255), Enum.Material.Neon, nil, rng:NextNumber(0.2, 0.55))
				box(city, "Lights", o, V(x - w * 0.42, y, z - d / 2 - 0.3), V(x + w * 0.42, y + 0.9, z - d / 2 - 0.1), lit, GHOST_DARK)
			end
		end
		if top > 70 then
			Kit.ball(city, "AviationLight", 1.2, o + V(x, top + 1, z), look(rgb(255, 40, 40), Enum.Material.Neon), GHOST_DARK)
		end
	end
	Kit.ball(city, "Moon", 30, o + V(-150, 170, office.maxZ + 620), look(rgb(255, 246, 226), Enum.Material.Neon), GHOST_DARK)

	-- The lift down, in a walnut core, the Executive's monogram above it.
	local core = Kit.model(dress, "LiftCore")
	box(core, "Core", o, V(-6.5, 0, Plan.Lift.Z + 2.4), V(6.5, OH, office.maxZ - 0.6), WALNUT, DECO)
	box(core, "CoreGilt", o, V(-6.8, 0, Plan.Lift.Z + 2.2), V(-6.2, OH - 1.3, Plan.Lift.Z + 2.6), BRASS, DECO)
	box(core, "CoreGilt", o, V(6.2, 0, Plan.Lift.Z + 2.2), V(6.8, OH - 1.3, Plan.Lift.Z + 2.6), BRASS, DECO)
	local liftDoor = Kit.part(arch, "LiftDown", V(8, 10, 0.4), CFrame.new(o + Plan.Lift + V(0, 5, 2)), look(GOLD, Enum.Material.Metal, 0.3))
	Kit.part(core, "LiftSeam", V(0.08, 10, 0.1), CFrame.new(o + Plan.Lift + V(0, 5, 1.78)), DARK_WALNUT, GHOST_DARK)
	Kit.part(core, "LiftHead", V(9, 1.2, 0.5), CFrame.new(o + Plan.Lift + V(0, 10.6, 1.9)), BRASS, DECO)
	local dial = Kit.cylinder(core, "Dial", 0.2, 1.8, CFrame.new(o + Plan.Lift + V(0, 12.1, 1.95)) * CFrame.Angles(0, math.rad(90), 0), BRASS, GHOST_DARK)
	Kit.part(core, "Needle", V(0.1, 0.8, 0.05), CFrame.new(o + Plan.Lift + V(0, 12.3, 1.82)) * CFrame.Angles(0, 0, math.rad(-35)), L.blackLacquer, GHOST_DARK)
	local _ = dial
	local monogram = Kit.part(core, "Monogram", V(7, 5.6, 0.2), CFrame.lookAt(o + V(0, 16.2, Plan.Lift.Z + 2.25), o + V(0, 16.2, Plan.Lift.Z - 10)), L.blackLacquer, GHOST_DARK)
	Kit.engrave(monogram, Enum.NormalId.Front, {
		{ text = "E", size = 3.6, font = Brand.Fonts.display, color = rgb(255, 210, 110) },
		{ text = "THE EXECUTIVE", size = 0.5, font = Brand.Fonts.bodyBold, color = rgb(214, 176, 100) },
	}, { ppu = 50, lit = false, brightness = 1.5 })
	for _, r in { { 0, 3.05, 7.6, 0.4 }, { 0, -3.05, 7.6, 0.4 }, { -3.6, 0, 0.4, 6.5 }, { 3.6, 0, 0.4, 6.5 } } do
		Kit.part(core, "MonogramFrame", V(r[3], r[4], 0.3), CFrame.new(o + V(r[1], 16.2 + r[2], Plan.Lift.Z + 2.2)), BRASS, GHOST_DARK)
	end
	local liftDown = prompt(liftDoor, "LiftDown", "Lift down", "Back to the Maison", 0.5, 12)
	liftDown.Enabled = false
	HolidayProps.sparkle(liftDoor, GOLD, 6, 0.5)

	-- The partner's desk: walnut and brass, a green leather top, the banker's lamp, a globe, and
	-- the high-backed chair behind it. (Solid: the Executive's cover.)
	local desk = Kit.model(arch, "Desk")
	local D = o + Plan.Desk
	Kit.part(desk, "Top", V(16, 0.7, 6.5), CFrame.new(D + V(0, 3.35, 0)), DARK_WALNUT)
	Kit.part(desk, "TopEdge", V(16.2, 0.18, 6.7), CFrame.new(D + V(0, 3.0, 0)), BRASS, DECO)
	Kit.part(desk, "Leather", V(10, 0.06, 3.6), CFrame.new(D + V(0, 3.72, 0.4)), GREEN_LEATHER, GHOST_DARK)
	for _, x in { -5.6, 5.6 } do
		Kit.part(desk, "Pedestal", V(4.6, 3, 6), CFrame.new(D + V(x, 1.5, 0)), WALNUT)
		for y = 0.6, 2.4, 0.9 do
			Kit.part(desk, "Drawer", V(3.8, 0.7, 0.08), CFrame.new(D + V(x, y, -3.02)), DARK_WALNUT, GHOST_DARK)
			Kit.part(desk, "Pull", V(0.9, 0.14, 0.12), CFrame.new(D + V(x, y, -3.1)), BRASS, GHOST_DARK)
		end
	end
	Kit.part(desk, "Front", V(6.6, 2.6, 0.5), CFrame.new(D + V(0, 1.7, -2.6)), WALNUT)
	Kit.part(desk, "FrontInlay", V(6.2, 0.12, 0.1), CFrame.new(D + V(0, 2.6, -2.88)), BRASS, GHOST_DARK)
	local lampAt = D + V(-5.4, 3.7, 1.4)
	Kit.part(desk, "LampFoot", V(1.2, 0.2, 0.8), CFrame.new(lampAt + V(0, 0.1, 0)), BRASS, GHOST_DARK)
	Kit.part(desk, "LampStem", V(0.14, 1.3, 0.14), CFrame.new(lampAt + V(0, 0.8, 0)), BRASS, GHOST_DARK)
	local shade = Kit.part(desk, "LampShade", V(1.8, 0.5, 0.9), CFrame.new(lampAt + V(0, 1.5, -0.2)), look(rgb(40, 170, 110), Enum.Material.Neon, nil, 0.15), GHOST_DARK)
	Kit.pointLight(shade, 0.9, 12, rgb(170, 255, 200))
	Kit.part(desk, "Inkwell", V(0.5, 0.4, 0.5), CFrame.new(D + V(3.2, 3.9, 1.6)), CRYSTAL, GHOST_DARK)
	Kit.part(desk, "Ledger", V(1.6, 0.3, 2.2), CFrame.new(D + V(1.2, 3.85, 0.6)) * CFrame.Angles(0, math.rad(12), 0), LEATHER, GHOST_DARK)
	piece(dress, "globe", CFrame.lookAt(o + V(10.5, 0, Plan.Desk.Z + 3), o + V(0, 0, Plan.Desk.Z)), nil, 1.2, false)
	local chairAt = o + Plan.Desk + V(0, 0, 4.6)
	local chair = Kit.model(dress, "ExecutiveChair")
	Kit.part(chair, "Seat", V(3.6, 0.9, 3.2), CFrame.new(chairAt + V(0, 2.1, 0)), LEATHER, GHOST)
	Kit.part(chair, "Back", V(3.6, 6, 0.8), CFrame.new(chairAt + V(0, 5.1, 1.4)), LEATHER, GHOST)
	Kit.part(chair, "BackPiping", V(3.8, 0.25, 0.9), CFrame.new(chairAt + V(0, 8.15, 1.4)), BRASS, GHOST_DARK)
	for _, x in { -1.9, 1.9 } do
		Kit.part(chair, "Arm", V(0.6, 1.4, 3), CFrame.new(chairAt + V(x, 3.1, 0.1)), LEATHER, GHOST)
	end
	Kit.part(chair, "Column", V(0.5, 1.6, 0.5), CFrame.new(chairAt + V(0, 0.9, 0)), BRASS, GHOST_DARK)
	Kit.part(chair, "Star", V(2.8, 0.25, 2.8), CFrame.new(chairAt + V(0, 0.15, 0)), BRASS, GHOST_DARK)

	-- The shield: a wall of glass light round the desk while it stands.
	local shieldWall = Kit.part(arch, "Shield", V(30, 12, 0.5), CFrame.new(o + Plan.Desk + V(0, 6, -8)), look(rgb(120, 200, 255), Enum.Material.ForceField, nil, 0.3), { shadow = false })
	-- The generators: a steel plinth, a brass cage round a core of blue light.
	local generators: { BasePart } = {}
	for i, at in Plan.Generators do
		local m = Kit.model(arch, "Generator" .. i)
		local g = o + at
		Kit.cylinder(m, "Base", 1, 4.2, CFrame.new(g + V(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), DARK_STEEL)
		Kit.cylinder(m, "Collar", 0.4, 3.4, CFrame.new(g + V(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), BRASS, DECO)
		local heart = Kit.part(m, "Core", V(2.2, 4.4, 2.2), CFrame.new(g + V(0, 3.2, 0)), look(rgb(120, 200, 255), Enum.Material.Neon), {})
		heart:SetAttribute("ExecTarget", "gen" .. i)
		for k = 0, 3 do
			local a = k * math.pi / 2 + math.pi / 4
			Kit.part(m, "Cage", V(0.2, 5.2, 0.2), CFrame.new(g + V(math.cos(a) * 1.75, 3.6, math.sin(a) * 1.75)), BRASS, GHOST_DARK)
		end
		Kit.cylinder(m, "Cap", 0.5, 3.2, CFrame.new(g + V(0, 6.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), BRASS, GHOST_DARK)
		Kit.ball(m, "Finial", 0.7, g + V(0, 6.8, 0), look(rgb(160, 220, 255), Enum.Material.Neon), GHOST_DARK)
		Kit.pointLight(heart, 1.2, 16, rgb(120, 200, 255))
		generators[i] = heart
	end
	-- The safe: dark steel, a gold dial and handle, brass hinges, on a marble plinth.
	local safeModel = Kit.model(arch, "Safe")
	Kit.part(safeModel, "Plinth", V(4.8, 0.6, 4.8), CFrame.new(o + Plan.Safe + V(0, 0.3, 0)), BLACK_MARBLE, DECO)
	local safeBody = Kit.part(safeModel, "Body", V(4, 5, 4), CFrame.new(o + Plan.Safe + V(0, 3.1, 0)), look(rgb(40, 44, 50), Enum.Material.Metal, 0.2))
	Kit.cylinder(safeModel, "Dial", 0.3, 1.3, CFrame.new(o + Plan.Safe + V(-2.12, 3.8, 0)), look(GOLD, Enum.Material.Metal, 0.3), GHOST)
	Kit.part(safeModel, "Handle", V(0.3, 0.3, 1.6), CFrame.new(o + Plan.Safe + V(-2.15, 2.6, 0)), look(GOLD, Enum.Material.Metal, 0.3), GHOST)
	for _, y in { 1.6, 4.6 } do
		Kit.part(safeModel, "Hinge", V(0.3, 0.6, 0.3), CFrame.new(o + Plan.Safe + V(-2.1, y, 1.9)), BRASS, GHOST_DARK)
	end
	Kit.part(safeModel, "Trim", V(0.08, 4.4, 3.4), CFrame.new(o + Plan.Safe + V(-2.03, 3.1, 0)), BRASS, GHOST_DARK)
	local safe = prompt(safeBody, "Safe", "Crack it", "The Executive's safe", 3, 9)
	safe.Enabled = false

	local actors = Kit.folder(root, "Actors")
	-- The arch home, by the lift you came up in.
	pcall(function()
		Portal.build(root, CFrame.lookAt(o + Plan.Arrival + V(0, 0, -4), o + Plan.Arrival + V(0, 0, -20)), "The Executive Suite", goHome)
	end)
	return {
		root = root,
		terminals = terminals,
		keypad = keypad,
		door = door,
		doorDressing = doorDressing,
		shield = shieldWall,
		generators = generators,
		safe = safe,
		liftDown = liftDown,
		cameras = cameras,
		actors = actors,
	}
end

return ExecutiveBuild

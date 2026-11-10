--!strict
-- The Executive Suite, built (shared/Executive says where everything is): the lift lobby, the
-- security hallway with its cameras and code terminals, the code door and its keypad, and the
-- Executive's Office: the desk behind its shield, the three generators, the safe and the lift down.
-- The guards, the bodyguards and the Executive himself are made by server/Attractions/Executive.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
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
	shield: BasePart,
	generators: { BasePart },
	safe: ProximityPrompt,
	liftDown: ProximityPrompt,
	cameras: { BasePart },
	actors: Folder, -- where the guards and the Executive stand
}

local L = Kit.Looks
local rgb = Color3.fromRGB
local GOLD = rgb(232, 182, 72)

local function look(colour: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Kit.Look
	return { color = colour, material = material, reflectance = reflectance, transparency = transparency } :: any
end

local MARBLE = look(rgb(232, 228, 220), Enum.Material.Marble, 0.05)
local WALNUT = look(rgb(60, 36, 22), Enum.Material.Wood)
local CARPET = look(rgb(18, 26, 48), Enum.Material.Fabric)
local GLASS = look(rgb(120, 200, 255), Enum.Material.Glass, 0.1, 0.55)
local STEEL = look(rgb(150, 156, 166), Enum.Material.Metal, 0.15)

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

function ExecutiveBuild.build(parent: Instance, o: Vector3, goHome: (player: Player) -> ()): Built
	local root = Kit.model(parent, "ExecutiveSuite")
	root:SetAttribute("Attraction", "executive")
	local arch = Kit.model(root, "Architecture")
	local H = Plan.HEIGHT
	local hall, office = Plan.Hall, Plan.Office

	-- The lift lobby and the hallway: marble, walnut panelling, a long carpet.
	box(arch, "HallFloor", o, Vector3.new(hall.minX, -1, hall.minZ), Vector3.new(hall.maxX, 0, hall.maxZ), MARBLE)
	box(arch, "Runner", o, Vector3.new(-3, 0, hall.minZ + 4), Vector3.new(3, 0.05, hall.maxZ), CARPET, { collide = false, query = false })
	for _, x in { hall.minX - 1, hall.maxX } do
		box(arch, "HallWall", o, Vector3.new(x, 0, hall.minZ), Vector3.new(x + 1, H, hall.maxZ), WALNUT)
	end
	box(arch, "HallEnd", o, Vector3.new(hall.minX - 1, 0, hall.minZ - 1), Vector3.new(hall.maxX + 1, H, hall.minZ), WALNUT)
	box(arch, "HallCeiling", o, Vector3.new(hall.minX - 1, H, hall.minZ - 1), Vector3.new(hall.maxX + 1, H + 1, hall.maxZ), L.blackLacquer, { shadow = false })
	for z = hall.minZ + 12, hall.maxZ - 6, 18 do
		local lamp = box(arch, "Sconce", o, Vector3.new(-0.6, H - 0.6, z - 0.6), Vector3.new(0.6, H - 0.2, z + 0.6), look(rgb(255, 236, 200), Enum.Material.Neon), { collide = false, query = false, shadow = false })
		Kit.pointLight(lamp, 0.9, 22, rgb(255, 226, 180))
	end
	-- The terminals: a brass lectern with a screen each.
	local terminals: { ProximityPrompt } = {}
	for i, at in Plan.Terminals do
		local m = Kit.model(arch, "Terminal" .. i)
		local inward = if at.X < 0 then 1 else -1
		local base = o + at + Vector3.new(inward * 1.2, 0, 0)
		Kit.part(m, "Stand", Vector3.new(1.4, 3.4, 1.4), CFrame.new(base + Vector3.new(0, 1.7, 0)), L.brass)
		local screen = Kit.part(m, "Screen", Vector3.new(0.2, 1.6, 2.2), CFrame.new(base + Vector3.new(inward * 0.2, 4.1, 0)), look(rgb(60, 255, 170), Enum.Material.Neon, nil, 0.2), { collide = false })
		screen:SetAttribute("Terminal", i)
		terminals[i] = prompt(screen, "Terminal", "Read it", "A code terminal (" .. i .. " of 4)", 1.2, 8)
		CollectionService:AddTag(screen, "ExecTerminal")
	end
	-- The cameras: a dark dome on an arm, with a red eye.
	local cameras: { BasePart } = {}
	for i, c in Plan.Cameras do
		local m = Kit.model(arch, "Camera" .. i)
		Kit.part(m, "Arm", Vector3.new(1.4, 0.3, 0.3), CFrame.new(o + c.at + Vector3.new(if c.at.X > 0 then 0.5 else -0.5, 0.6, 0)), STEEL, { collide = false })
		local head = Kit.part(m, "Lens", Vector3.new(1.2, 1, 1.6), CFrame.new(o + c.at), L.blackLacquer, { collide = false })
		head:SetAttribute("Camera", i)
		CollectionService:AddTag(head, "ExecCamera")
		local eye = Kit.part(m, "Eye", Vector3.new(0.3, 0.3, 0.3), CFrame.new(o + c.at + Vector3.new(0, 0, 0.8)), look(rgb(255, 40, 40), Enum.Material.Neon), { collide = false, query = false, shadow = false })
		eye.Parent = head
		cameras[i] = head
	end

	-- The code door, and its keypad.
	local door = box(arch, "CodeDoor", o, Vector3.new(Plan.Door.minX, 0, Plan.Door.z - 0.5), Vector3.new(Plan.Door.maxX, 10, Plan.Door.z + 0.5), STEEL)
	for _, side in { { hall.minX - 1, Plan.Door.minX }, { Plan.Door.maxX, hall.maxX + 1 } } do
		box(arch, "DoorWall", o, Vector3.new(side[1], 0, Plan.Door.z - 0.5), Vector3.new(side[2], H, Plan.Door.z + 0.5), WALNUT)
	end
	box(arch, "DoorLintel", o, Vector3.new(Plan.Door.minX, 10, Plan.Door.z - 0.5), Vector3.new(Plan.Door.maxX, H, Plan.Door.z + 0.5), WALNUT)
	local pad = Kit.part(arch, "Keypad", Vector3.new(1.2, 1.6, 0.3), CFrame.new(o + Vector3.new(Plan.Door.maxX + 1.6, 4.5, Plan.Door.z - 0.8)), look(rgb(30, 30, 34), Enum.Material.Metal), { collide = false })
	local keypad = prompt(pad, "Keypad", "Enter the code", "The Executive's door", 0, 8)
	local sign = Kit.part(arch, "DoorSign", Vector3.new(8, 1.4, 0.2), CFrame.lookAt(o + Vector3.new(0, 12, Plan.Door.z - 0.7), o + Vector3.new(0, 12, Plan.Door.z - 20)), L.blackLacquer, { collide = false })
	Kit.engrave(sign, Enum.NormalId.Front, { { text = "THE EXECUTIVE", size = 0.7, font = Brand.Fonts.display, color = rgb(255, 214, 120) } }, { ppu = 60, lit = false, brightness = 1.4 })

	-- The Office: a deep carpet, glass along the far wall over the city, the desk.
	box(arch, "OfficeFloor", o, Vector3.new(office.minX, -1, office.minZ), Vector3.new(office.maxX, 0, office.maxZ), CARPET)
	for _, x in { office.minX - 1, office.maxX } do
		box(arch, "OfficeWall", o, Vector3.new(x, 0, Plan.Door.z), Vector3.new(x + 1, H + 4, office.maxZ), WALNUT)
	end
	for _, side in { { office.minX - 1, hall.minX - 1 }, { hall.maxX + 1, office.maxX + 1 } } do
		box(arch, "OfficeFront", o, Vector3.new(side[1], 0, Plan.Door.z - 0.5), Vector3.new(side[2], H + 4, Plan.Door.z + 0.5), WALNUT)
	end
	box(arch, "Window", o, Vector3.new(office.minX - 1, 0, office.maxZ), Vector3.new(office.maxX + 1, H + 4, office.maxZ + 1), GLASS)
	box(arch, "OfficeCeiling", o, Vector3.new(office.minX - 1, H + 4, Plan.Door.z - 0.5), Vector3.new(office.maxX + 1, H + 5, office.maxZ + 1), L.blackLacquer, { shadow = false })
	for _, at in { Vector3.new(-16, H + 2, 10), Vector3.new(16, H + 2, 10), Vector3.new(0, H + 2, 34) } do
		local lamp = Kit.part(arch, "Chandelier", Vector3.new(3, 0.6, 3), CFrame.new(o + at), look(rgb(255, 240, 210), Enum.Material.Neon), { collide = false, query = false, shadow = false })
		Kit.pointLight(lamp, 1.4, 40, rgb(255, 232, 196))
	end
	local desk = Kit.model(arch, "Desk")
	Kit.part(desk, "Top", Vector3.new(14, 0.6, 5), CFrame.new(o + Plan.Desk + Vector3.new(0, 3.3, 0)), WALNUT)
	Kit.part(desk, "Front", Vector3.new(14, 3, 0.6), CFrame.new(o + Plan.Desk + Vector3.new(0, 1.5, -2.2)), WALNUT)
	Kit.part(desk, "Inlay", Vector3.new(14.1, 0.1, 0.2), CFrame.new(o + Plan.Desk + Vector3.new(0, 3.62, -2.4)), L.brass, { collide = false })
	-- The shield: a wall of glass light round the desk while it stands.
	local shield = Kit.part(arch, "Shield", Vector3.new(30, 12, 0.5), CFrame.new(o + Plan.Desk + Vector3.new(0, 6, -8)), look(rgb(120, 200, 255), Enum.Material.ForceField, nil, 0.3), { shadow = false })
	-- The generators.
	local generators: { BasePart } = {}
	for i, at in Plan.Generators do
		local m = Kit.model(arch, "Generator" .. i)
		Kit.part(m, "Base", Vector3.new(3.4, 1, 3.4), CFrame.new(o + at + Vector3.new(0, 0.5, 0)), STEEL)
		local core = Kit.part(m, "Core", Vector3.new(2.2, 4.4, 2.2), CFrame.new(o + at + Vector3.new(0, 3.2, 0)), look(rgb(120, 200, 255), Enum.Material.Neon), {})
		core:SetAttribute("ExecTarget", "gen" .. i)
		Kit.pointLight(core, 1.2, 16, rgb(120, 200, 255))
		generators[i] = core
	end
	-- The safe.
	local safeModel = Kit.model(arch, "Safe")
	local safeBody = Kit.part(safeModel, "Body", Vector3.new(4, 5, 4), CFrame.new(o + Plan.Safe + Vector3.new(0, 2.5, 0)), look(rgb(40, 44, 50), Enum.Material.Metal, 0.2))
	Kit.part(safeModel, "Dial", Vector3.new(0.3, 1.2, 1.2), CFrame.new(o + Plan.Safe + Vector3.new(-2.1, 3, 0)), look(GOLD, Enum.Material.Metal, 0.3), { collide = false })
	local safe = prompt(safeBody, "Safe", "Crack it", "The Executive's safe", 3, 9)
	safe.Enabled = false
	-- The lift down.
	local liftDoor = Kit.part(arch, "LiftDown", Vector3.new(8, 10, 0.4), CFrame.new(o + Plan.Lift + Vector3.new(0, 5, 2)), look(GOLD, Enum.Material.Metal, 0.3))
	local liftDown = prompt(liftDoor, "LiftDown", "Lift down", "Back to the Maison", 0.5, 12)
	liftDown.Enabled = false
	HolidayProps.sparkle(liftDoor, GOLD, 6, 0.5)

	local actors = Kit.folder(root, "Actors")
	-- The arch home, by the lift you came up in.
	pcall(function()
		Portal.build(root, CFrame.lookAt(o + Plan.Arrival + Vector3.new(0, 0, -4), o + Plan.Arrival + Vector3.new(0, 0, -20)), "The Executive Suite", goHome)
	end)
	return {
		root = root,
		terminals = terminals,
		keypad = keypad,
		door = door,
		shield = shield,
		generators = generators,
		safe = safe,
		liftDown = liftDown,
		cameras = cameras,
		actors = actors,
	}
end

return ExecutiveBuild

--!strict
-- Two ways into the Vault. Its own door: a steel vault door in the Foyer's back wall, a great
-- brass-ringed wheel on its face, that swings open as a guest comes near and shuts behind them
-- (the Vault is private again the moment you've gone in). And the lift: brass doors on the Suite
-- gallery's north wall and on the Vault's south wall, a dial over each showing the floor, and a
-- bell-push to ride. VaultAccess (the server) moves them; this only builds them.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local D = Layout.VaultDoor
local LIFT = Layout.Lift

local Passages = {}

local STEEL = { color = Color3.fromRGB(122, 126, 134), material = Enum.Material.DiamondPlate, reflectance = 0.12 }
local POLISHED = { color = Color3.fromRGB(176, 180, 186), material = Enum.Material.Metal, reflectance = 0.3 }
local BRIGHT_BRASS = { color = Color3.fromRGB(196, 156, 82), material = Enum.Material.Metal, reflectance = 0.25 }
local CAR = { color = Color3.fromRGB(46, 28, 20), material = Enum.Material.Wood }
local GLOW = { color = Color3.fromRGB(255, 222, 170), material = Enum.Material.Neon }
local TRIM = { collide = false, query = false, shadow = false }

-- The door's parts all hang from its hinge: each keeps where it sits relative to it (the server
-- swings the hinge and every part follows).
local function hang(part: BasePart, hinge: CFrame)
	part:SetAttribute("FromHinge", hinge:ToObjectSpace(part.CFrame))
	CollectionService:AddTag(part, "VaultDoorPart")
end

local function vaultDoor(parent: Instance)
	local m = Kit.model(parent, "VaultDoor")
	local hinge = CFrame.new(D.hinge)
	local w, h, t = D.width, D.height, D.thickness
	-- The slab, in the doorway: from the west jamb to the east, the Foyer side at the wall's face.
	local centre = D.hinge + Vector3.new(w / 2, 0.1 + h / 2, -t / 2)
	local parts: { BasePart } = {}
	local function add(p: BasePart)
		table.insert(parts, p)
	end
	add(Kit.part(m, "Slab", Vector3.new(w, h, t), CFrame.new(centre), STEEL, TRIM))
	-- On the Foyer side: a brass ring, a steel disc, the wheel and a ring of bolts.
	local face = centre.Z - t / 2
	local c = Vector3.new(centre.X, centre.Y, face)
	local outward = CFrame.new(c) * CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis along Z
	add(Kit.cylinder(m, "Ring", 0.3, 6.6, outward * CFrame.new(0.15, 0, 0), BRIGHT_BRASS, TRIM))
	add(Kit.cylinder(m, "Disc", 0.25, 5.8, outward * CFrame.new(0.32, 0, 0), POLISHED, TRIM))
	add(Kit.cylinder(m, "Hub", 0.7, 1.4, outward * CFrame.new(0.7, 0, 0), BRIGHT_BRASS, TRIM))
	for i = 0, 5 do
		local a = math.rad(i * 60)
		add(Kit.part(m, "Spoke", Vector3.new(0.28, 3.6, 0.28), CFrame.new(c - Vector3.new(0, 0, 0.75)) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.1, 0), BRIGHT_BRASS, TRIM))
		add(Kit.ball(m, "Knob", 0.45, c - Vector3.new(0, 0, 0.75) + Vector3.new(math.sin(-a) * 2.9, math.cos(a) * 2.9, 0), BRIGHT_BRASS, TRIM))
	end
	for i = 0, 11 do
		local a = math.rad(i * 30)
		add(Kit.cylinder(m, "Bolt", 0.3, 0.38, CFrame.new(c + Vector3.new(math.cos(a) * 3.05, math.sin(a) * 3.05, -0.3)) * CFrame.Angles(0, math.rad(90), 0), POLISHED, TRIM))
	end
	-- A brass edge round the slab, and its name.
	for _, e in {
		{ Vector3.new(w, 0.25, 0.1), Vector3.new(0, h / 2 - 0.125, -t / 2 - 0.05) },
		{ Vector3.new(w, 0.25, 0.1), Vector3.new(0, -h / 2 + 0.125, -t / 2 - 0.05) },
		{ Vector3.new(0.25, h, 0.1), Vector3.new(-w / 2 + 0.125, 0, -t / 2 - 0.05) },
		{ Vector3.new(0.25, h, 0.1), Vector3.new(w / 2 - 0.125, 0, -t / 2 - 0.05) },
	} do
		add(Kit.part(m, "Edge", e[1], CFrame.new(centre + e[2]), BRIGHT_BRASS, TRIM))
	end
	local plate = Kit.part(m, "NamePlate", Vector3.new(3.4, 0.55, 0.06), CFrame.lookAt(c + Vector3.new(0, -3.9, -0.08), c + Vector3.new(0, -3.9, -10)), BRIGHT_BRASS, TRIM)
	Kit.engrave(plate, Enum.NormalId.Front, { { text = "PRIVATE · THE VAULT", size = 0.3, font = Brand.Fonts.display, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 90, lit = false })
	add(plate)
	-- Hinges on the Vault side.
	for _, y in { 2, h - 2 } do
		add(Kit.cylinder(m, "Hinge", 1.6, 0.6, CFrame.new(D.hinge + Vector3.new(0, y, 0.1)) * CFrame.Angles(0, 0, math.rad(90)), POLISHED, TRIM))
	end
	for _, p in parts do
		hang(p, hinge)
	end
	m:SetAttribute("Hinge", hinge)
	CollectionService:AddTag(m, "VaultDoor")
	-- Its sounds: the heavy swing open, the clunk of it shutting.
	local slab = parts[1]
	for name: string, id: string in { Open = "rbxassetid://9116982942", Shut = "rbxassetid://9120371080" } :: { [string]: string } do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = id
		s.Volume = 0.8
		s.RollOffMaxDistance = 60
		s.Parent = slab
	end
end

-- One landing of the lift: the car behind brass doors, a dial over them, a bell-push beside.
local function landing(parent: Instance, id: string, other: string)
	local at = (LIFT :: any)[id]
	local m = Kit.model(parent, "Lift_" .. id)
	local w, h = LIFT.width, LIFT.height
	local out: Vector3 = at.out
	local base: Vector3 = at.centre
	-- The frame of reference: X along the wall, Y up, Z out of the car.
	local cf = CFrame.lookAt(base, base + out)
	local function put(name: string, size: Vector3, x: number, y: number, z: number, look: Kit.Look, opts: { [string]: any }?): Part
		-- (Size given along the wall, up, and out from it.)
		return Kit.part(m, name, size, cf * CFrame.new(x, y, -z), look, opts)
	end
	-- The car: a shallow walnut box set into the wall face, lit from above.
	put("CarBack", Vector3.new(w, h, 0.1), 0, h / 2, 0.05, CAR, TRIM)
	put("CarFloor", Vector3.new(w, 0.1, 0.5), 0, 0.05, 0.3, L.blackMarble, TRIM)
	local strip = put("CarLight", Vector3.new(w - 0.6, 0.08, 0.3), 0, h - 0.1, 0.3, GLOW, TRIM)
	Kit.pointLight(strip, 0.6, 8, Color3.fromRGB(255, 222, 170))
	-- The frame: brass jambs and a head, standing proud of the wall.
	put("JambL", Vector3.new(0.4, h + 0.4, 0.6), -w / 2 - 0.2, (h + 0.4) / 2, 0.3, BRIGHT_BRASS, TRIM)
	put("JambR", Vector3.new(0.4, h + 0.4, 0.6), w / 2 + 0.2, (h + 0.4) / 2, 0.3, BRIGHT_BRASS, TRIM)
	put("Head", Vector3.new(w + 0.8, 0.4, 0.6), 0, h + 0.2, 0.3, BRIGHT_BRASS, TRIM)
	-- Two leaves that slide apart, each a brass sheet with a walnut panel.
	for i, side in { -1, 1 } do
		local leaf = put("Leaf" .. i, Vector3.new(w / 2, h, 0.12), side * w / 4, h / 2, 0.42, BRIGHT_BRASS, TRIM)
		local panel = put("LeafPanel" .. i, Vector3.new(w / 2 - 0.5, h - 1.2, 0.04), side * w / 4, h / 2, 0.5, L.walnut, TRIM)
		for _, p in { leaf, panel } do
			p:SetAttribute("Closed", p.CFrame)
			p:SetAttribute("Slide", cf.RightVector * side * (w / 2 - 0.1))
			CollectionService:AddTag(p, "LiftLeaf")
			p:SetAttribute("Landing", id)
		end
	end
	-- The dial over the doors: a half-moon of brass, a needle pointing at this floor.
	local dial = put("Dial", Vector3.new(2.4, 1.2, 0.1), 0, h + 1.3, 0.55, BRIGHT_BRASS, TRIM)
	Kit.engrave(dial, Enum.NormalId.Front, { { text = if id == "suite" then "VAULT  ·  ▲ SUITE" else "▲ VAULT  ·  SUITE", size = 0.26, font = Brand.Fonts.bodyBold, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 90, lit = false })
	-- The bell-push beside the doors: what a guest presses to ride.
	local push = put("CallButton", Vector3.new(0.7, 1.1, 0.2), w / 2 + 1.1, 4.2, 0.4, BRIGHT_BRASS, { collide = false, shadow = false })
	put("CallLight", Vector3.new(0.3, 0.3, 0.06), w / 2 + 1.1, 4.3, 0.53, GLOW, TRIM)
	local p = Instance.new("ProximityPrompt")
	p.Name = "LiftPrompt"
	p.ActionText = "Ride the lift"
	p.ObjectText = "To " .. tostring((LIFT :: any)[other].name)
	p.HoldDuration = 0
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p:SetAttribute("Offset", 0.5)
	p.Parent = push
	push:SetAttribute("To", other)
	push:SetAttribute("From", id)
	CollectionService:AddTag(push, "LiftCall")
	-- Its sounds: the bell, and the doors.
	for name: string, sid: string in { Bell = "rbxassetid://9114302479", Doors = "rbxassetid://9114305290" } :: { [string]: string } do
		local s = Instance.new("Sound")
		s.Name = name
		s.SoundId = sid
		s.Volume = 0.7
		s.RollOffMaxDistance = 50
		s.Parent = push
	end
	-- A small plate under the push.
	local sign = put("LiftSign", Vector3.new(1.6, 0.45, 0.06), w / 2 + 1.1, 3.2, 0.33, BRIGHT_BRASS, TRIM)
	Kit.engrave(sign, Enum.NormalId.Front, { { text = "THE LIFT", size = 0.26, font = Brand.Fonts.display, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 90, lit = false })
	m:SetAttribute("Landing", id)
end

function Passages.build(parent: Instance)
	local f = Kit.folder(parent, "Passages")
	vaultDoor(f)
	landing(f, "suite", "vault")
	landing(f, "vault", "suite")
end

return Passages

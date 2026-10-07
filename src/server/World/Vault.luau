--!strict
-- The Vault (§3, §11): a quiet, low room through the Foyer's back wall. Six tall glass cabinets,
-- one for each case, fill with the pieces a guest has filed (each guest sees their own); the
-- centre cabinet holds their Mythics with their serial numbers. The Archivist keeps the Register
-- at a desk by the door: "Everything you've found is kept here."

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Layout = require(ReplicatedStorage.Shared.Layout).raw -- (the house as drawn: see World/Grand)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local V = Layout.Vault
local FLOOR = Layout.FLOOR

local VaultRoom = {}

local INVISIBLE = { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }
local GLASS = { color = Color3.fromRGB(200, 214, 224), material = Enum.Material.Glass, reflectance = 0.15, transparency = 0.8 }
local VELVET = { color = Color3.fromRGB(26, 20, 34), material = Enum.Material.Fabric }

-- A tall glass cabinet with three velvet shelves. Its local +Z faces the room.
local function cabinet(m: Model, name: string, cf: CFrame, caseId: string?, label: string)
	local model = Kit.model(m, name)
	Kit.part(model, "Plinth", Vector3.new(3.6, 0.8, 1.8), cf * CFrame.new(0, 0.4, 0), L.blackLacquer)
	Kit.part(model, "Back", Vector3.new(3.6, 7, 0.2), cf * CFrame.new(0, 4.3, -0.8), VELVET)
	for i = 1, 3 do
		local shelf = Kit.part(model, "Shelf" .. i, Vector3.new(3.4, 0.1, 1.5), cf * CFrame.new(0, 0.8 + i * 2, 0), VELVET, { collide = false, shadow = false })
		shelf:SetAttribute("Shelf", i)
	end
	Kit.part(model, "Glass", Vector3.new(3.6, 7, 1.8), cf * CFrame.new(0, 4.3, 0), GLASS, { shadow = false })
	Kit.part(model, "Crown", Vector3.new(3.8, 0.3, 2), cf * CFrame.new(0, 7.95, 0), L.brass)
	-- Only the Mythics' cabinet has its own light; the room's light finds the others.
	if not caseId then
		local light = Kit.part(model, "Light", Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 7.5, 0.3), INVISIBLE, { collide = false, query = false, shadow = false })
		Kit.pointLight(light, 0.9, 7, Color3.fromRGB(255, 236, 206))
	end
	local plate = Kit.part(model, "Plate", Vector3.new(2.4, 0.4, 0.05), cf * CFrame.new(0, 0.55, 0.93), L.brass, { collide = false, shadow = false })
	Kit.engrave(plate, Enum.NormalId.Front, { { text = Caps(label), size = 0.24, font = Brand.Fonts.bodyBold, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 100, lit = false })
	model:SetAttribute("Frame", cf)
	if caseId then
		model:SetAttribute("Case", caseId)
	else
		model:SetAttribute("Mythics", true)
	end
	CollectionService:AddTag(model, "VaultCabinet")
end

local STEEL = { color = Color3.fromRGB(150, 154, 160), material = Enum.Material.DiamondPlate, reflectance = 0.1 }
local POLISHED = { color = Color3.fromRGB(176, 180, 186), material = Enum.Material.Metal, reflectance = 0.3 }
local GOLDBAR = { color = Color3.fromRGB(232, 184, 72), material = Enum.Material.Metal, reflectance = 0.35 }

-- The room's dressing: the great round vault door on the east wall (shut, for show), a coffered
-- brass ceiling, panelled walls with a brass dado, a gold border round the rug, stacks of gold
-- bars by the door, and sconces between the cabinets.
function VaultRoom.dress(m: Model, top: number)
	-- The vault door: a steel disc in a brass ring, a wheel of spokes, a ring of bolts.
	local x = V.maxX - 0.2
	local c = Vector3.new(x - 0.6, FLOOR + 6, 55.5)
	local face = CFrame.new(c) * CFrame.Angles(0, 0, 0)
	Kit.cylinder(m, "VaultDoorRing", 0.5, 10.4, face, L.brass, { collide = false, query = false })
	Kit.cylinder(m, "VaultDoor", 0.9, 9.4, face * CFrame.new(-0.3, 0, 0), STEEL, { collide = false, query = false })
	Kit.cylinder(m, "VaultHub", 1.4, 2.2, face * CFrame.new(-0.9, 0, 0), POLISHED, { collide = false, query = false })
	for i = 0, 5 do
		local a = math.rad(i * 60)
		Kit.part(m, "VaultSpoke", Vector3.new(0.35, 5.2, 0.35), CFrame.new(c + Vector3.new(-1.3, 0, 0)) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 1.6, 0), POLISHED, { collide = false, query = false, shadow = false })
		Kit.ball(m, "VaultKnob", 0.55, c + Vector3.new(-1.35, math.cos(a) * 4.1, math.sin(a) * 4.1) - Vector3.new(0, 0, 0), L.brass, { collide = false, query = false, shadow = false })
	end
	for i = 0, 15 do
		local a = math.rad(i * 22.5)
		Kit.cylinder(m, "VaultBolt", 0.3, 0.45, CFrame.new(c + Vector3.new(-0.85, math.cos(a) * 4.3, math.sin(a) * 4.3)), POLISHED, { collide = false, query = false, shadow = false })
	end
	local vplate = Kit.part(m, "VaultPlate", Vector3.new(0.05, 0.6, 3), CFrame.lookAt(c + Vector3.new(-1, -5.6, 0), c + Vector3.new(-10, -5.6, 0)), L.brass, { collide = false, query = false, shadow = false })
	Kit.engrave(vplate, Enum.NormalId.Front, { { text = "MAISON NOIR · 1889", size = 0.3, font = Brand.Fonts.display, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 80, lit = false })
	-- Gold bars, stacked in a pyramid on a low black plinth, either side of the vault door.
	for _, z in { 51.2, 60.5 } do
		Kit.part(m, "BarPlinth", Vector3.new(2.6, 0.6, 2.2), CFrame.new(x - 1.6, FLOOR + 0.3, z), L.blackLacquer)
		for row = 0, 2 do
			for i = 0, 2 - row do
				Kit.part(m, "GoldBar", Vector3.new(0.7, 0.35, 1.6), CFrame.new(x - 2.4 + row * 0.38 + i * 0.78, FLOOR + 0.78 + row * 0.36, z), GOLDBAR, { collide = false, query = false, shadow = false })
			end
		end
	end
	-- Panelled walls: a brass dado rail, and raised panels below it.
	for _, w in {
		{ a = Vector3.new(V.minX, FLOOR + 3.2, V.minZ), b = Vector3.new(V.minX + 0.12, FLOOR + 3.4, V.maxZ) },
		{ a = Vector3.new(V.minX, FLOOR + 3.2, V.maxZ - 0.12), b = Vector3.new(V.maxX, FLOOR + 3.4, V.maxZ) },
		{ a = Vector3.new(V.maxX - 0.12, FLOOR + 3.2, V.minZ), b = Vector3.new(V.maxX, FLOOR + 3.4, 49.9) },
		{ a = Vector3.new(V.maxX - 0.12, FLOOR + 3.2, 61.1), b = Vector3.new(V.maxX, FLOOR + 3.4, V.maxZ) },
	} do
		Kit.span(m, "Dado", w.a, w.b, L.brass, { collide = false, query = false, shadow = false })
	end
	-- A coffered ceiling: brass beams in a grid.
	for xx = V.minX + 4, V.maxX - 1, 4 do
		Kit.span(m, "Coffer", Vector3.new(xx - 0.2, top - 0.5, V.minZ), Vector3.new(xx + 0.2, top, V.maxZ), L.darkBrass, { collide = false, query = false, shadow = false })
	end
	for zz = V.minZ + 4, V.maxZ - 1, 4.5 do
		Kit.span(m, "Coffer", Vector3.new(V.minX, top - 0.45, zz - 0.2), Vector3.new(V.maxX, top - 0.05, zz + 0.2), L.darkBrass, { collide = false, query = false, shadow = false })
	end
	-- A gold border round the rug.
	for _, e in {
		{ Vector3.new(-16, FLOOR + 0.05, 47), Vector3.new(0, FLOOR + 0.08, 47.4) },
		{ Vector3.new(-16, FLOOR + 0.05, 58.6), Vector3.new(0, FLOOR + 0.08, 59) },
		{ Vector3.new(-16, FLOOR + 0.05, 47.4), Vector3.new(-15.6, FLOOR + 0.08, 58.6) },
		{ Vector3.new(-0.4, FLOOR + 0.05, 47.4), Vector3.new(0, FLOOR + 0.08, 58.6) },
	} do
		Kit.span(m, "RugBorder", e[1], e[2], L.brass, { collide = false, query = false, shadow = false })
	end
	-- Sconces between the cabinets on the west wall (glow only; the room's lights do the work).
	for _, z in { 50.5, 55.5 } do
		Kit.part(m, "Sconce", Vector3.new(0.4, 0.9, 0.5), CFrame.new(V.minX + 0.3, FLOOR + 6.5, z), L.brass, { collide = false, query = false, shadow = false })
		Kit.ball(m, "SconceGlow", 0.5, Vector3.new(V.minX + 0.55, FLOOR + 7.1, z), { color = Color3.fromRGB(255, 214, 160), material = Enum.Material.Neon }, { collide = false, query = false, shadow = false })
	end
	-- A pool of light on the vault door.
	local spot = Kit.part(m, "VaultSpot", Vector3.new(0.3, 0.3, 0.3), CFrame.new(x - 6, top - 1, 55.5), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.spotLight(spot, Enum.NormalId.Bottom, 1.4, 16, 60)
end

function VaultRoom.build(parent: Instance): Model
	local m = Kit.model(parent, "Vault")
	local top = FLOOR + V.height
	Kit.span(m, "Floor", Vector3.new(V.minX, FLOOR - 1, V.minZ), Vector3.new(V.maxX, FLOOR, V.maxZ), L.blackMarble)
	Kit.span(m, "Rug", Vector3.new(-16, FLOOR, 47), Vector3.new(0, FLOOR + 0.05, 59), { color = Color3.fromRGB(34, 22, 40), material = Enum.Material.Carpet }, { collide = false, query = false })
	Kit.span(m, "Ceiling", Vector3.new(V.minX - 2, top, V.minZ), Vector3.new(V.maxX + 2, top + 1, V.maxZ + 2), L.darkWood)
	Kit.span(m, "WallW", Vector3.new(V.minX - 2, FLOOR, V.minZ), Vector3.new(V.minX, top, V.maxZ + 2), L.panel)
	Kit.span(m, "WallE", Vector3.new(V.maxX, FLOOR, V.minZ), Vector3.new(V.maxX + 2, top, V.maxZ + 2), L.panel)
	Kit.span(m, "WallN", Vector3.new(V.minX - 2, FLOOR, V.maxZ), Vector3.new(V.maxX + 2, top, V.maxZ + 2), L.panel)
	-- A brass doorframe on the Foyer side.
	local d = V.door
	local hw = V.doorWidth / 2
	Kit.part(m, "DoorJambL", Vector3.new(0.5, 10.4, 2.4), CFrame.new(d.X - hw - 0.25, FLOOR + 5.2, 43), L.brass)
	Kit.part(m, "DoorJambR", Vector3.new(0.5, 10.4, 2.4), CFrame.new(d.X + hw + 0.25, FLOOR + 5.2, 43), L.brass)
	Kit.part(m, "DoorHead", Vector3.new(V.doorWidth + 1.4, 0.5, 2.4), CFrame.new(d.X, FLOOR + 10.2, 43), L.brass)
	local sign = Kit.part(m, "DoorName", Vector3.new(6, 1, 0.1), CFrame.lookAt(Vector3.new(d.X, FLOOR + 11.3, 41.7), Vector3.new(d.X, FLOOR + 11.3, 0)), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.engrave(sign, Enum.NormalId.Front, { { text = "THE VAULT", size = 0.6, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 60, lit = false })
	-- Six cabinets: three on the west wall, three on the north wall.
	local slots = {
		CFrame.lookAt(Vector3.new(V.minX + 1, FLOOR, 48), Vector3.new(0, FLOOR, 48)),
		CFrame.lookAt(Vector3.new(V.minX + 1, FLOOR, 53), Vector3.new(0, FLOOR, 53)),
		CFrame.lookAt(Vector3.new(V.minX + 1, FLOOR, 58), Vector3.new(0, FLOOR, 58)),
		CFrame.lookAt(Vector3.new(-14, FLOOR, V.maxZ - 1), Vector3.new(-14, FLOOR, 44)),
		CFrame.lookAt(Vector3.new(-8, FLOOR, V.maxZ - 1), Vector3.new(-8, FLOOR, 44)),
		CFrame.lookAt(Vector3.new(-2, FLOOR, V.maxZ - 1), Vector3.new(-2, FLOOR, 44)),
	}
	for i, c in Catalogue.Cases do
		-- lookAt faces -Z at the room; the cabinet's own +Z should face the room, so turn it.
		cabinet(m, "Cabinet_" .. c.id, slots[i] * CFrame.Angles(0, math.pi, 0), c.id, c.name)
	end
	-- The centre cabinet: the Mythics.
	cabinet(m, "Cabinet_Mythics", CFrame.new(V.centre) * CFrame.Angles(0, math.pi, 0), nil, "Mythics")
	-- The Archivist's desk by the door, and the Register on it.
	local desk = V.desk
	Kit.part(m, "Desk", Vector3.new(1.6, 3.1, 4), desk * CFrame.new(0, 1.55, 0), L.walnut)
	Kit.part(m, "DeskTop", Vector3.new(1.9, 0.12, 4.3), desk * CFrame.new(0, 3.16, 0), L.darkWood, { shadow = false })
	local book = Kit.part(m, "RegisterBook", Vector3.new(0.9, 0.2, 1.2), desk * CFrame.new(0, 3.32, 0), { color = Color3.fromRGB(62, 30, 20), material = Enum.Material.Leather }, { collide = false })
	local p = Instance.new("ProximityPrompt")
	p.Name = "RegisterPrompt"
	p.ActionText = "Read"
	p.ObjectText = "The Register"
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p:SetAttribute("Offset", 0.5)
	p.Parent = book
	CollectionService:AddTag(book, "RegisterBook")
	local lamp = Kit.part(m, "DeskLamp", Vector3.new(0.6, 0.5, 0.6), desk * CFrame.new(0, 4, 1.5), L.brass, { collide = false })
	Kit.pointLight(lamp, 0.7, 10, Color3.fromRGB(255, 214, 160))
	VaultRoom.dress(m, top)
	local fill = Kit.part(m, "Fill", Vector3.new(1, 1, 1), CFrame.new(-8, top - 2, 53), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.pointLight(fill, 0.6, 34, Color3.fromRGB(230, 214, 200))
	return m
end

return VaultRoom

--!strict
-- The Vault (§3, §11): a quiet, low room through the Foyer's back wall. Six tall glass cabinets,
-- one for each case, fill with the pieces a guest has filed (each guest sees their own); the
-- centre cabinet holds their Mythics with their serial numbers. The Archivist keeps the Register
-- at a desk by the door: "Everything you've found is kept here."

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Layout = require(ReplicatedStorage.Shared.Layout)
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
	Kit.engrave(plate, Enum.NormalId.Front, { { text = Kit.track(string.upper(label)), size = 0.24, font = Brand.Fonts.bodyBold, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 100, lit = false })
	model:SetAttribute("Frame", cf)
	if caseId then
		model:SetAttribute("Case", caseId)
	else
		model:SetAttribute("Mythics", true)
	end
	CollectionService:AddTag(model, "VaultCabinet")
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
	Kit.engrave(sign, Enum.NormalId.Front, { { text = Kit.track("THE VAULT"), size = 0.6, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 60, lit = false })
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
	local fill = Kit.part(m, "Fill", Vector3.new(1, 1, 1), CFrame.new(-8, top - 2, 53), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.pointLight(fill, 0.6, 34, Color3.fromRGB(230, 214, 200))
	return m
end

return VaultRoom

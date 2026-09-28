--!strict
-- The Velvet Room: deep green walls, pendant lights on long cords, smoked mirrors, and a tall
-- case clock in the corner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)
local RoomShell = require(script.Parent.RoomShell)
local SortingTable = require(script.Parent.SortingTable)

local L = Kit.Looks
local V = Layout.Velvet
local FLOOR = Layout.FLOOR

local Velvet = {}

local GREEN = { color = Color3.fromRGB(16, 44, 32), material = Enum.Material.Fabric }
local MIRROR = { color = Color3.fromRGB(46, 48, 52), material = Enum.Material.Glass, reflectance = 0.55, transparency = 0 }

local function mirrors(m: Model)
	-- Tall smoked mirrors in brass frames along the far (west) wall.
	for i, z in { 36, 46, 56 } do
		local cf = CFrame.lookAt(Vector3.new(V.minX + 0.35, FLOOR + 8.5, z), Vector3.new(0, FLOOR + 8.5, z))
		Kit.part(m, "MirrorFrame" .. i, Vector3.new(5.2, 9.2, 0.25), cf * CFrame.new(0, 0, 0.05), L.brass, { collide = false })
		Kit.part(m, "Mirror" .. i, Vector3.new(4.6, 8.6, 0.1), cf * CFrame.new(0, 0, -0.1), MIRROR, { collide = false })
		local sconce = Kit.part(m, "Sconce" .. i, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, 5.4, -0.5), L.glassWarm, { collide = false, shadow = false })
		Kit.pointLight(sconce, 0.8, 12, Color3.fromRGB(255, 200, 140))
	end
end

local function caseClock(m: Model)
	-- The tall case clock in the north-west corner. The client moves its hands and pendulum.
	local model = Kit.model(m, "CaseClock")
	model:SetAttribute("Clock", true)
	local base = CFrame.lookAt(Vector3.new(V.minX + 2.2, FLOOR, V.maxZ - 2.2), Vector3.new(V.minX + 12, FLOOR, V.maxZ - 12))
	Kit.part(model, "Plinth", Vector3.new(2.6, 1.2, 1.8), base * CFrame.new(0, 0.6, 0), L.walnut)
	Kit.part(model, "Trunk", Vector3.new(2, 6.4, 1.4), base * CFrame.new(0, 4.4, 0), L.walnut)
	Kit.part(model, "TrunkGlass", Vector3.new(1.3, 4.6, 0.05), base * CFrame.new(0, 4.2, -0.72), { color = Color3.fromRGB(30, 34, 40), material = Enum.Material.Glass, reflectance = 0.3, transparency = 0.45 }, { collide = false })
	Kit.part(model, "Hood", Vector3.new(2.6, 2.8, 1.8), base * CFrame.new(0, 9, 0), L.walnut)
	Kit.part(model, "Crown", Vector3.new(2.9, 0.5, 2), base * CFrame.new(0, 10.6, 0), L.brass)
	local face = Kit.part(model, "Face", Vector3.new(0.1, 1.9, 1.9), base * CFrame.new(0, 9, -0.92) * CFrame.Angles(0, math.rad(90), 0), { color = Color3.fromRGB(236, 228, 210), material = Enum.Material.SmoothPlastic }, { collide = false, shape = Enum.PartType.Cylinder })
	face.Name = "Face"
	Kit.part(model, "Bezel", Vector3.new(0.06, 2.1, 2.1), base * CFrame.new(0, 9, -0.89) * CFrame.Angles(0, math.rad(90), 0), L.brass, { collide = false, shape = Enum.PartType.Cylinder })
	-- Hands: pivot at the centre of the face (the client turns them)
	local centre = base * CFrame.new(0, 9, -1.0)
	local hour = Kit.part(model, "HourHand", Vector3.new(0.08, 0.5, 0.03), centre * CFrame.new(0, 0.25, 0), L.ink, { collide = false, shadow = false })
	hour:SetAttribute("Pivot", centre)
	local minute = Kit.part(model, "MinuteHand", Vector3.new(0.05, 0.8, 0.03), centre * CFrame.new(0, 0.4, -0.02), L.ink, { collide = false, shadow = false })
	minute:SetAttribute("Pivot", centre)
	local pivot = base * CFrame.new(0, 6.3, -0.4)
	local pendulum = Kit.part(model, "Pendulum", Vector3.new(0.05, 3, 0.05), pivot * CFrame.new(0, -1.5, 0), L.brass, { collide = false, shadow = false })
	pendulum:SetAttribute("Pivot", pivot)
	Kit.part(model, "Bob", Vector3.new(0.5, 0.5, 0.08), pivot * CFrame.new(0, -3, 0), L.brass, { collide = false, shadow = false, shape = Enum.PartType.Cylinder }).Name = "Bob"
end

local function sideboard(m: Model)
	local cf = CFrame.lookAt(Vector3.new(-56, FLOOR, V.maxZ - 1.4), Vector3.new(-56, FLOOR, 0))
	Kit.part(m, "Sideboard", Vector3.new(10, 3.2, 2), cf * CFrame.new(0, 1.6, 0), L.darkWood)
	Kit.part(m, "SideboardTop", Vector3.new(10.3, 0.15, 2.2), cf * CFrame.new(0, 3.27, 0), L.blackMarble)
	for i = -1, 1 do
		Kit.part(m, "Decanter", Vector3.new(0.5, 1.1, 0.5), cf * CFrame.new(i * 2.2, 3.9, 0), { color = Color3.fromRGB(120, 140, 130), material = Enum.Material.Glass, reflectance = 0.25, transparency = 0.35 }, { collide = false })
	end
	local lamp = Kit.part(m, "SideboardLamp", Vector3.new(1.2, 0.8, 1.2), cf * CFrame.new(3.8, 4.9, 0), { color = Color3.fromRGB(26, 70, 48), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0.15 }, { collide = false })
	Kit.post(m, "SideboardLampStem", 1.3, 0.1, (cf * CFrame.new(3.8, 3.35, 0)).Position, L.brass, { collide = false })
	Kit.pointLight(lamp, 0.9, 12, Color3.fromRGB(255, 214, 150))
end

function Velvet.build(parent: Instance): Model
	local root = Kit.model(parent, "Velvet")
	RoomShell.build(root, {
		bounds = V,
		foyerSide = "east",
		doorZ = Layout.RoomDoors.velvet.centre.Z,
		wall = GREEN,
		floor = { color = Color3.fromRGB(36, 26, 20), material = Enum.Material.WoodPlanks },
		ceiling = { color = Color3.fromRGB(12, 22, 18), material = Enum.Material.SmoothPlastic },
		wainscot = L.darkWood,
		rail = L.brass,
		sharedSouth = true, -- the Salon's north wall
	})
	Kit.span(root, "Rug", Vector3.new(V.minX + 4, FLOOR, V.minZ + 3), Vector3.new(V.maxX - 3, FLOOR + 0.05, V.maxZ - 4), { color = Color3.fromRGB(20, 40, 30), material = Enum.Material.Carpet }, { collide = false, query = false })
	mirrors(root)
	caseClock(root)
	sideboard(root)
	local tables = Kit.folder(root, "Tables")
	local style: SortingTable.Style = {
		roomName = "The Velvet Room",
		top = L.darkWood,
		legs = L.ink,
		felt = { color = Color3.fromRGB(14, 22, 18), material = Enum.Material.Fabric },
		caseBase = { color = Color3.fromRGB(14, 36, 26), material = Enum.Material.Fabric },
		caseRim = L.brass,
		chair = { color = Color3.fromRGB(22, 50, 36), material = Enum.Material.Fabric },
		lamp = "cord",
		lampColor = Color3.fromRGB(255, 222, 170),
		lampBrightness = 1.5,
		ceiling = FLOOR + V.height,
	}
	for i, centre in V.tables do
		SortingTable.build(tables, "velvet", i, centre, style)
	end
	local fill = Kit.part(root, "FillLight", Vector3.new(1, 1, 1), CFrame.new(-56, FLOOR + 12, 46), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
	Kit.pointLight(fill, 0.4, 40, Color3.fromRGB(170, 210, 180))
	return root
end

return Velvet

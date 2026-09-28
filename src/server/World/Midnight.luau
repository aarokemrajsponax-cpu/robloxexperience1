--!strict
-- The Midnight Room: ink blue and almost dark. One lamp at each table, and the city through a
-- round window. A velvet rope across the door until you've earned it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)
local RoomShell = require(script.Parent.RoomShell)
local SortingTable = require(script.Parent.SortingTable)

local L = Kit.Looks
local M = Layout.Midnight
local FLOOR = Layout.FLOOR

local Midnight = {}

local INK = { color = Color3.fromRGB(12, 16, 32), material = Enum.Material.Fabric }

local function roundWindow(m: Model)
	local model = Kit.model(m, "RoundWindow")
	local c = M.window
	local radius = 5
	local x0 = M.maxX
	-- The far wall is built by the shell; a brass ring and the night glass sit just inside it.
	local segments = 28
	for i = 1, segments do
		local a0 = (i - 1) / segments * math.pi * 2
		local a1 = i / segments * math.pi * 2
		local p = Vector3.new(x0 - 0.3, c.Y + math.sin(a0) * radius, c.Z + math.cos(a0) * radius)
		local q = Vector3.new(x0 - 0.3, c.Y + math.sin(a1) * radius, c.Z + math.cos(a1) * radius)
		Kit.part(model, "Ring", Vector3.new(0.35, 0.35, (q - p).Magnitude + 0.05), CFrame.lookAt((p + q) / 2, q), L.brass, { collide = false, shadow = false })
	end
	-- The night outside: a disc of deep blue glass with the city's lights behind it.
	local glass = Kit.part(model, "Night", Vector3.new(0.1, radius * 2 - 0.3, radius * 2 - 0.3), CFrame.new(x0 - 0.22, c.Y, c.Z), { color = Color3.fromRGB(10, 16, 36), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0 }, { collide = false, shape = Enum.PartType.Cylinder })
	glass.CastShadow = false
	local rng = Random.new(1203)
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * (radius - 0.8)
		local y = c.Y + math.sin(a) * r
		if y < c.Y + radius * 0.35 then
			local size = rng:NextNumber(0.12, 0.3)
			Kit.part(model, "CityLight" .. i, Vector3.new(0.05, size, size * 0.7), CFrame.new(x0 - 0.28, y, c.Z + math.cos(a) * r), L.cityLight, { collide = false, query = false, shadow = false })
		end
	end
	-- Towers in silhouette across the lower half
	for i = -4, 4 do
		local h = 1.5 + ((i * 37) % 5) * 0.6
		Kit.part(model, "Tower" .. i, Vector3.new(0.04, h, 0.8), CFrame.new(x0 - 0.26, c.Y - radius + 0.8 + h / 2, c.Z + i * 1.05), { color = Color3.fromRGB(6, 8, 16), material = Enum.Material.SmoothPlastic }, { collide = false, query = false, shadow = false })
	end
	-- Moonlight falling in from the window
	local moon = Kit.part(model, "Moonlight", Vector3.new(0.4, 0.4, 0.4), CFrame.lookAt(Vector3.new(x0 - 1, c.Y, c.Z), Vector3.new(x0 - 20, FLOOR, c.Z)), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
	Kit.spotLight(moon, Enum.NormalId.Front, 0.7, 34, 40, Color3.fromRGB(150, 170, 230))
end

function Midnight.build(parent: Instance): Model
	local root = Kit.model(parent, "Midnight")
	RoomShell.build(root, {
		bounds = M,
		foyerSide = "west",
		doorZ = Layout.RoomDoors.midnight.centre.Z,
		wall = INK,
		floor = { color = Color3.fromRGB(14, 14, 20), material = Enum.Material.WoodPlanks },
		ceiling = { color = Color3.fromRGB(6, 8, 16), material = Enum.Material.SmoothPlastic },
		wainscot = { color = Color3.fromRGB(10, 12, 22), material = Enum.Material.Wood },
		rail = L.darkBrass,
	})
	roundWindow(root)
	local tables = Kit.folder(root, "Tables")
	local style: SortingTable.Style = {
		roomName = "The Midnight Room",
		top = { color = Color3.fromRGB(16, 18, 28), material = Enum.Material.Wood },
		legs = L.ink,
		felt = { color = Color3.fromRGB(10, 12, 22), material = Enum.Material.Fabric },
		caseBase = { color = Color3.fromRGB(12, 14, 30), material = Enum.Material.Fabric },
		caseRim = L.darkBrass,
		chair = { color = Color3.fromRGB(18, 22, 40), material = Enum.Material.Fabric },
		lamp = "single",
		lampColor = Color3.fromRGB(255, 206, 140),
		lampBrightness = 1.6,
		ceiling = FLOOR + M.height,
	}
	for i, centre in M.tables do
		SortingTable.build(tables, "midnight", i, centre, style)
	end
	return root
end

return Midnight

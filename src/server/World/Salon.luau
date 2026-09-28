--!strict
-- The Salon: burgundy velvet, low brass lamps, bookshelves, a fire. The warmest room in the house.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)
local RoomShell = require(script.Parent.RoomShell)
local SortingTable = require(script.Parent.SortingTable)

local L = Kit.Looks
local S = Layout.Salon
local FLOOR = Layout.FLOOR

local Salon = {}

local function bookshelves(m: Model)
	local model = Kit.model(m, "Bookshelves")
	local rng = Random.new(7)
	local spines = {
		Color3.fromRGB(70, 22, 24), Color3.fromRGB(28, 40, 34), Color3.fromRGB(46, 30, 20),
		Color3.fromRGB(24, 26, 40), Color3.fromRGB(90, 70, 40), Color3.fromRGB(20, 20, 22),
	}
	local x = S.minX + 0.9
	for bay = 0, 4 do
		local z0 = S.minZ + 3 + bay * 6
		Kit.span(model, "Case", Vector3.new(S.minX, FLOOR, z0), Vector3.new(S.minX + 1.8, FLOOR + 13, z0 + 5.6), L.darkWood)
		for shelf = 0, 5 do
			local y = FLOOR + 1 + shelf * 2
			Kit.span(model, "Shelf", Vector3.new(S.minX + 0.2, y, z0 + 0.3), Vector3.new(S.minX + 2, y + 0.15, z0 + 5.3), L.walnut, { collide = false })
			local z = z0 + 0.4
			while z < z0 + 5.1 do
				local w = rng:NextNumber(0.2, 0.42)
				local h = rng:NextNumber(1.2, 1.75)
				if z + w > z0 + 5.2 then
					break
				end
				local tilt = if rng:NextNumber() < 0.06 then math.rad(12) else 0
				Kit.part(model, "Book", Vector3.new(1.3, h, w), CFrame.new(x + 0.2, y + 0.15 + h / 2, z + w / 2) * CFrame.Angles(tilt, 0, 0), { color = spines[rng:NextInteger(1, #spines)], material = Enum.Material.Fabric }, { collide = false, query = false, shadow = false })
				z += w + 0.02
			end
		end
	end
	-- The rolling ladder, leaning against the shelves
	Kit.part(model, "LadderRailA", Vector3.new(0.18, 14, 0.18), CFrame.new(S.minX + 3.2, FLOOR + 6.8, S.minZ + 14) * CFrame.Angles(0, 0, math.rad(-12)), L.walnut, { collide = false })
	Kit.part(model, "LadderRailB", Vector3.new(0.18, 14, 0.18), CFrame.new(S.minX + 3.2, FLOOR + 6.8, S.minZ + 15.6) * CFrame.Angles(0, 0, math.rad(-12)), L.walnut, { collide = false })
	for i = 1, 10 do
		local y = FLOOR + i * 1.3
		local xOff = 3.2 + (6.8 - (y - FLOOR)) * math.tan(math.rad(12))
		Kit.part(model, "Rung", Vector3.new(0.14, 0.14, 1.6), CFrame.new(S.minX + xOff, y, S.minZ + 14.8), L.brass, { collide = false, shadow = false })
	end
end

local function fireplace(m: Model)
	local model = Kit.model(m, "Fireplace")
	local cf = S.fireplace -- LookVector points into the room
	Kit.part(model, "Surround", Vector3.new(11, 8, 1.4), cf * CFrame.new(0, 4, 0), L.blackMarble)
	Kit.part(model, "Mantel", Vector3.new(12.4, 0.6, 2.2), cf * CFrame.new(0, 8.3, -0.3), L.blackMarble)
	Kit.part(model, "MantelEdge", Vector3.new(12.5, 0.12, 2.3), cf * CFrame.new(0, 8, -0.3), L.brass, { collide = false })
	Kit.part(model, "Firebox", Vector3.new(6, 4.4, 0.4), cf * CFrame.new(0, 2.4, -0.55), L.ink)
	Kit.part(model, "Hearth", Vector3.new(12, 0.3, 3), cf * CFrame.new(0, 0.15, -1.6), L.blackMarble)
	Kit.part(model, "Fender", Vector3.new(7, 0.5, 0.15), cf * CFrame.new(0, 0.55, -2.8), L.brass, { collide = false })
	for i = -1, 1 do
		Kit.part(model, "Log", Vector3.new(3, 0.5, 0.5), cf * CFrame.new(i * 0.4, 0.7 + math.abs(i) * 0.1, -1) * CFrame.Angles(0, math.rad(i * 20), 0), L.darkWood, { collide = false })
	end
	local embers = Kit.part(model, "Embers", Vector3.new(3.2, 0.3, 1), cf * CFrame.new(0, 0.5, -1), L.ember, { collide = false, shadow = false })
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 6
	fire.Color = Color3.fromRGB(255, 140, 60)
	fire.SecondaryColor = Color3.fromRGB(255, 70, 20)
	fire.Parent = embers
	local glow = Kit.pointLight(embers, 2.4, 22, Color3.fromRGB(255, 140, 70), true)
	glow:SetAttribute("Flicker", true)
	CollectionService:AddTag(glow, "Flicker")
	-- A painting over the mantel
	Kit.part(model, "PaintingFrame", Vector3.new(7, 5, 0.3), cf * CFrame.new(0, 12.5, 0.2), L.brass)
	Kit.part(model, "Canvas", Vector3.new(6.2, 4.2, 0.1), cf * CFrame.new(0, 12.5, 0), { color = Color3.fromRGB(34, 26, 24), material = Enum.Material.Fabric })
	Kit.part(model, "CanvasMoon", Vector3.new(0.9, 0.9, 0.05), cf * CFrame.new(1.6, 13.4, -0.06), { color = Color3.fromRGB(180, 150, 100), material = Enum.Material.SmoothPlastic }, { shape = Enum.PartType.Cylinder })
	-- Two armchairs angled to the fire
	for _, side in { -1, 1 } do
		local base = cf * CFrame.new(side * 7.5, 0, -5) * CFrame.Angles(0, math.rad(side * -35), 0)
		Kit.part(model, "ArmchairSeat", Vector3.new(3, 1.2, 3), base * CFrame.new(0, 1.2, 0), L.leather)
		Kit.part(model, "ArmchairBack", Vector3.new(3, 3.2, 0.8), base * CFrame.new(0, 2.6, -1.2), L.leather)
		Kit.part(model, "ArmchairArmL", Vector3.new(0.6, 1.4, 3), base * CFrame.new(-1.5, 2, 0), L.leather)
		Kit.part(model, "ArmchairArmR", Vector3.new(0.6, 1.4, 3), base * CFrame.new(1.5, 2, 0), L.leather)
	end
end

local function floorLamp(m: Model, pos: Vector3)
	local model = Kit.model(m, "FloorLamp")
	Kit.part(model, "Foot", Vector3.new(1.2, 0.2, 1.2), CFrame.new(pos + Vector3.new(0, 0.1, 0)), L.brass)
	Kit.post(model, "Stem", 6, 0.16, pos, L.brass)
	local shade = Kit.part(model, "Shade", Vector3.new(1.8, 1.3, 1.8), CFrame.new(pos + Vector3.new(0, 6.4, 0)), { color = Color3.fromRGB(150, 60, 40), material = Enum.Material.Fabric, transparency = 0.15 }, { collide = false })
	Kit.pointLight(shade, 1.2, 14, Color3.fromRGB(255, 170, 110))
end

function Salon.build(parent: Instance): Model
	local root = Kit.model(parent, "Salon")
	RoomShell.build(root, {
		bounds = S,
		foyerSide = "east",
		doorZ = Layout.RoomDoors.salon.centre.Z,
		wall = L.deepVelvet,
		floor = { color = Color3.fromRGB(44, 28, 20), material = Enum.Material.WoodPlanks },
		ceiling = { color = Color3.fromRGB(30, 14, 16), material = Enum.Material.SmoothPlastic },
		wainscot = L.walnut,
		rail = L.brass,
	})
	Kit.span(root, "Rug", Vector3.new(S.minX + 4, FLOOR, S.minZ + 3), Vector3.new(S.maxX - 3, FLOOR + 0.05, S.maxZ - 5), L.carpet, { collide = false, query = false })
	Kit.span(root, "RugBorder", Vector3.new(S.minX + 3.6, FLOOR, S.minZ + 2.6), Vector3.new(S.maxX - 2.6, FLOOR + 0.04, S.maxZ - 4.6), L.darkBrass, { collide = false, query = false })
	bookshelves(root)
	fireplace(root)
	for _, pos in { Vector3.new(S.minX + 4, FLOOR, S.minZ + 2.5), Vector3.new(S.maxX - 3, FLOOR, S.minZ + 2.5), Vector3.new(S.maxX - 3, FLOOR, S.maxZ - 3) } do
		floorLamp(root, pos)
	end
	local tables = Kit.folder(root, "Tables")
	local style: SortingTable.Style = {
		roomName = "The Salon",
		top = L.walnut,
		legs = L.darkWood,
		felt = L.felt,
		caseBase = L.deepVelvet,
		caseRim = L.brass,
		chair = L.leather,
		lamp = "pendant",
		lampColor = Color3.fromRGB(255, 214, 160),
		lampBrightness = 1.4,
		ceiling = FLOOR + S.height,
	}
	for i, centre in S.tables do
		SortingTable.build(tables, "salon", i, centre, style)
	end
	-- A soft fill so velvet and felt never go fully black
	local fill = Kit.part(root, "FillLight", Vector3.new(1, 1, 1), CFrame.new(-56, FLOOR + 12, 11), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
	Kit.pointLight(fill, 0.45, 40, Color3.fromRGB(220, 150, 120))
	return root
end

return Salon

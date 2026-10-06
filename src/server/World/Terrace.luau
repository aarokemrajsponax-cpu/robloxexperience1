--!strict
-- The Terrace (§3): the Obsidian Room's roof, open to the night, every evening of the year. A
-- stone balustrade, planters, café tables under parasols, sun loungers facing the view, a fire
-- pit ringed with sofas, the Gold Key's cabana, strings of warm bulbs overhead, and the bar
-- (Purchases/Bar: snacks and drinks, none with alcohol). French doors in the Club hall's east
-- wall lead out.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local T = Layout.Terrace
local Y = T.floorY
local CLUB = Layout.CLUB

local Terrace = {}

local STONE = { color = Color3.fromRGB(150, 142, 130), material = Enum.Material.Limestone }
local PAVING = { color = Color3.fromRGB(112, 106, 98), material = Enum.Material.Slate }
local LEAVES = { color = Color3.fromRGB(34, 62, 36), material = Enum.Material.Grass }
local CANVAS = { color = Color3.fromRGB(226, 216, 196), material = Enum.Material.Fabric }
local BULB = { color = Color3.fromRGB(255, 206, 140), material = Enum.Material.Neon }
local INVISIBLE = { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }
local GLASS_DOOR = { color = Color3.fromRGB(30, 34, 40), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0.45 }

-- A balustrade from a to b (on the terrace floor): posts, a top rail, and an invisible guard.
local function balustrade(m: Model, a: Vector3, b: Vector3)
	local length = (b - a).Magnitude
	local dir = (b - a).Unit
	local n = math.max(1, math.floor(length / 3))
	for i = 0, n do
		local p = a + dir * (length * i / n)
		Kit.post(m, "Baluster", 3, 0.5, Vector3.new(p.X, Y, p.Z), STONE, { collide = false })
	end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, Y + 3.2, mid.Z), Vector3.new(b.X, Y + 3.2, b.Z))
	Kit.part(m, "Rail", Vector3.new(0.9, 0.4, length + 0.9), cf, STONE)
	Kit.part(m, "Guard", Vector3.new(0.6, 6, length), cf * CFrame.new(0, -0.2, 0), INVISIBLE, { shadow = false })
end

local function planter(m: Model, at: Vector3)
	Kit.part(m, "Planter", Vector3.new(3, 1.6, 3), CFrame.new(at + Vector3.new(0, 0.8, 0)), L.blackLacquer)
	Kit.ball(m, "Shrub", 3.4, at + Vector3.new(0, 2.8, 0), LEAVES, { collide = false })
end

local function lounge(m: Model, centre: Vector3)
	Kit.cylinder(m, "LowTable", 0.3, 3, CFrame.new(centre + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.brass)
	Kit.post(m, "LowTableStem", 1.3, 0.4, centre, L.darkBrass, { collide = false })
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.4
		local p = centre + Vector3.new(math.cos(a) * 3.9, 0, math.sin(a) * 3.9)
		-- A low club chair, turned to the table (its own seat and Sit prompt).
		Furniture.build("chair", m, CFrame.lookAt(p, Vector3.new(centre.X, p.Y, centre.Z)), { model = "club", colour = Color3.fromRGB(236, 228, 210), material = "Fabric", accent = Color3.fromRGB(170, 132, 64) })
	end
end

local function parasol(m: Model, at: Vector3)
	Kit.post(m, "ParasolPole", 8, 0.25, at, L.darkBrass, { collide = false })
	Kit.cylinder(m, "ParasolCanopy", 0.4, 9, CFrame.new(at + Vector3.new(0, 7.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), CANVAS, { collide = false })
end

-- A string of bulbs sagging between two points.
local function bulbs(m: Model, a: Vector3, b: Vector3, count: number)
	for i = 1, count do
		local t = i / (count + 1)
		local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 1.4, 0)
		Kit.ball(m, "Bulb", 0.35, p, BULB, { collide = false, shadow = false, query = false })
	end
end

-- Swings one leaf of the French doors open (out onto the steps) or shut.
local function swing(leaf: Instance, open: boolean)
	if not leaf:IsA("BasePart") then
		return
	end
	local hinge = leaf:GetAttribute("Hinge")
	local dir = leaf:GetAttribute("Swing")
	if typeof(hinge) ~= "Vector3" or type(dir) ~= "number" then
		return
	end
	local w = leaf.Size.Z
	local closed = CFrame.new(hinge.X, hinge.Y + leaf.Size.Y / 2, hinge.Z + dir * w / 2)
	local pivot = CFrame.new(hinge.X, hinge.Y + leaf.Size.Y / 2, hinge.Z)
	local target = if open then pivot * CFrame.Angles(0, dir * math.rad(90), 0) * pivot:Inverse() * closed else closed
	local frame = leaf:FindFirstChild("Frame")
	local offset = if frame and frame:IsA("BasePart") then leaf.CFrame:ToObjectSpace(frame.CFrame) else nil
	leaf.CFrame = target
	if frame and frame:IsA("BasePart") and offset then
		frame.CFrame = target * offset
	end
	leaf.CanCollide = not open
	leaf:SetAttribute("Open", open)
end

-- The French doors: two glazed leaves, hinged at the jambs, standing open (every evening now).
local function doors(m: Model)
	local z0, z1 = T.door.Z - T.doorWidth / 2, T.door.Z + T.doorWidth / 2
	local leafW = T.doorWidth / 2
	for i, hinge in { z0, z1 } do
		local dir = if i == 1 then 1 else -1
		local closed = CFrame.new(T.door.X, CLUB + T.doorHeight / 2, hinge + dir * leafW / 2)
		local leaf = Kit.part(m, "TerraceDoor", Vector3.new(0.3, T.doorHeight, leafW), closed, GLASS_DOOR)
		Kit.part(leaf, "Frame", Vector3.new(0.34, T.doorHeight, 0.25), closed * CFrame.new(0, 0, dir * (leafW / 2 - 0.12)), L.brass, { collide = false })
		leaf:SetAttribute("Hinge", Vector3.new(T.door.X, CLUB, hinge))
		leaf:SetAttribute("Swing", dir)
		CollectionService:AddTag(leaf, "TerraceDoor")
		swing(leaf, true)
	end
end

function Terrace.build(parent: Instance): Model
	local m = Kit.model(parent, "Terrace")
	local z0, z1 = T.door.Z - T.doorWidth / 2, T.door.Z + T.doorWidth / 2
	-- The way out: two steps up from the Club floor to the roof.
	Kit.span(m, "Step1", Vector3.new(26, CLUB - 1, z0), Vector3.new(28, CLUB + 1, z1), STONE)
	Kit.span(m, "Step2", Vector3.new(28, CLUB - 1, z0), Vector3.new(T.minX, Y, z1), STONE)
	Kit.span(m, "StepGuardN", Vector3.new(26, CLUB, z1), Vector3.new(T.minX, Y + 6, z1 + 0.6), STONE)
	Kit.span(m, "StepGuardS", Vector3.new(26, CLUB, z0 - 0.6), Vector3.new(T.minX, Y + 6, z0), STONE)
	-- The paving, laid on the roof.
	Kit.span(m, "Paving", Vector3.new(T.minX, Y - 0.2, T.minZ), Vector3.new(T.maxX, Y, T.maxZ), PAVING)
	-- The balustrade on the three open sides, and the west side beyond the Foyer's wall.
	balustrade(m, Vector3.new(T.minX + 0.5, 0, T.minZ + 0.5), Vector3.new(T.maxX - 0.5, 0, T.minZ + 0.5))
	balustrade(m, Vector3.new(T.maxX - 0.5, 0, T.minZ + 0.5), Vector3.new(T.maxX - 0.5, 0, T.maxZ - 0.5))
	balustrade(m, Vector3.new(T.maxX - 0.5, 0, T.maxZ - 0.5), Vector3.new(T.minX + 0.5, 0, T.maxZ - 0.5))
	balustrade(m, Vector3.new(T.minX + 0.5, 0, T.maxZ - 0.5), Vector3.new(T.minX + 0.5, 0, z1 + 0.5))
	balustrade(m, Vector3.new(T.minX + 0.5, 0, z0 - 0.5), Vector3.new(T.minX + 0.5, 0, 44.5))
	for _, p in { Vector3.new(33, Y, 33), Vector3.new(77.5, Y, 32.5), Vector3.new(33, Y, 60), Vector3.new(77.5, Y, 47.5), Vector3.new(64, Y, 60) } do
		planter(m, p)
	end
	-- Two café tables under parasols, in the middle of the terrace.
	for _, c in { Vector3.new(44, Y, 48), Vector3.new(57, Y, 45) } do
		lounge(m, c)
		parasol(m, c)
	end
	-- The bar under its pergola on the north side, its stools facing it (BarMenu, Purchases/Bar).
	local bar = Layout.Terrace.bar
	local barModel = Furniture.build("outdoorbar", m, CFrame.lookAt(bar, Vector3.new(bar.X, bar.Y, 20)), { model = "teak", accent = Color3.fromRGB(214, 176, 92) })
	if barModel then
		barModel.Name = "TerraceBar"
		local counter = Kit.part(barModel, "OrderAnchor", Vector3.new(0.4, 0.4, 0.4), CFrame.new(bar + Vector3.new(0, 4.6, -0.6)), INVISIBLE, { collide = false, query = false, shadow = false })
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "BarPrompt"
		prompt.ActionText = "See the menu"
		prompt.ObjectText = "The Terrace Bar"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt.Parent = counter
		-- The menu, chalked on a board beside the bar.
		local board = Kit.part(barModel, "MenuBoard", Vector3.new(3.2, 4.2, 0.2), CFrame.lookAt(bar + Vector3.new(-6.4, 3.6, 0.6), bar + Vector3.new(-6.4, 3.6, -10)), { color = Color3.fromRGB(26, 28, 26), material = Enum.Material.Slate }, { collide = false })
		Kit.post(barModel, "BoardLeg", 1.5, 0.2, bar + Vector3.new(-6.4, 0, 0.7), L.darkWood, { collide = false })
		Kit.engrave(board, Enum.NormalId.Front, {
			{ text = "THE TERRACE BAR", size = 0.42, color = Color3.fromRGB(236, 214, 160) },
			{ text = "Lemonade · Hibiscus tea · Mint & lime", size = 0.26, color = Color3.fromRGB(230, 226, 214) },
			{ text = "Espresso tonic · Hot chocolate", size = 0.26, color = Color3.fromRGB(230, 226, 214) },
			{ text = "Truffle fries · Macarons · Strawberries", size = 0.26, color = Color3.fromRGB(230, 226, 214) },
			{ text = "Nothing here has alcohol in it", size = 0.22, color = Color3.fromRGB(190, 180, 160) },
		})
	end
	-- A fire pit ringed with low sofas, open toward the doors.
	Furniture.build("firepit", m, CFrame.lookAt(Vector3.new(68, Y, 40), Vector3.new(50, Y, 40)), { colour = Color3.fromRGB(196, 170, 120) })
	-- Sun loungers along the south rail, facing the view.
	for _, x in { 38, 49 } do
		Furniture.build("loungers", m, CFrame.lookAt(Vector3.new(x, Y, 35), Vector3.new(x, Y, 10)), { colour = Color3.fromRGB(240, 234, 220), accent = Color3.fromRGB(150, 40, 46) })
	end
	-- The cabana: a curtained daybed in the north-east corner, for Gold Key holders.
	local cabana = Furniture.build("cabana", m, CFrame.lookAt(Vector3.new(74, Y, 55), Vector3.new(50, Y, 55)), { colour = Color3.fromRGB(240, 234, 220), accent = Color3.fromRGB(150, 40, 46) })
	if cabana then
		cabana.Name = "GoldKeyCabana"
		for _, d in cabana:GetChildren() do
			if d:IsA("BasePart") and d.Name == "SitSpot" then
				d:SetAttribute("GoldKey", true)
			end
		end
		local sign = Kit.part(cabana, "CabanaPlate", Vector3.new(2.2, 0.7, 0.1), CFrame.lookAt(Vector3.new(69.8, Y + 1.2, 59), Vector3.new(60, Y + 1.2, 59)), L.brass, { collide = false })
		Kit.engrave(sign, Enum.NormalId.Front, {
			{ text = "THE CABANA", size = 0.36, color = Color3.fromRGB(20, 16, 10) },
			{ text = "Gold Key holders", size = 0.24, color = Color3.fromRGB(40, 32, 20) },
		})
	end
	-- Strings of bulbs across the terrace, on poles at its corners.
	local poles = { Vector3.new(31.5, Y, 31.5), Vector3.new(78.5, Y, 31.5), Vector3.new(78.5, Y, 60.5), Vector3.new(31.5, Y, 60.5) }
	for _, p in poles do
		Kit.post(m, "LightPole", 10, 0.3, p, L.darkBrass, { collide = false })
	end
	for i = 1, #poles do
		local a, b = poles[i] + Vector3.new(0, 10, 0), poles[i % #poles + 1] + Vector3.new(0, 10, 0)
		bulbs(m, a, b, 11)
	end
	bulbs(m, poles[1] + Vector3.new(0, 10, 0), poles[3] + Vector3.new(0, 10, 0), 13)
	for _, p in { Vector3.new(44, Y + 6.5, 48), Vector3.new(57, Y + 6.5, 45) } do
		local glow = Kit.part(m, "BulbGlow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(p), INVISIBLE, { collide = false, query = false, shadow = false })
		Kit.pointLight(glow, 1.1, 22, Color3.fromRGB(255, 200, 140))
	end
	doors(m)
	-- A small brass plate in the Club hall beside the doors.
	local plate = Kit.part(m, "TerracePlate", Vector3.new(2.4, 0.9, 0.1), CFrame.lookAt(Vector3.new(23.9, CLUB + 5.5, z0 - 2), Vector3.new(0, CLUB + 5.5, z0 - 2)), L.brass, { collide = false })
	Kit.engrave(plate, Enum.NormalId.Front, {
		{ text = "THE TERRACE", size = 0.5, color = Color3.fromRGB(20, 16, 10) },
		{ text = "The bar is open", size = 0.35, color = Color3.fromRGB(40, 32, 20) },
	})
	return m
end

-- Opens (every evening now) or closes the French doors, swinging each leaf out onto the steps.
function Terrace.setOpen(open: boolean)
	for _, leaf in CollectionService:GetTagged("TerraceDoor") do
		swing(leaf, open)
	end
end

return Terrace

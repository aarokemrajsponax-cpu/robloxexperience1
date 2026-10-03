--!strict
-- The Terrace (§3): the Obsidian Room's roof, open to the night. Paving, a stone balustrade,
-- planters, low chairs round two tables, a parasol, and strings of warm bulbs overhead. French
-- doors in the Club hall's east wall lead out; they open only in High Summer (SeasonDress).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
		local p = centre + Vector3.new(math.cos(a) * 3.4, 0, math.sin(a) * 3.4)
		local cf = CFrame.lookAt(p, Vector3.new(centre.X, p.Y, centre.Z))
		Kit.part(m, "Chair", Vector3.new(2.2, 1, 2.2), cf * CFrame.new(0, 0.9, 0), L.leather)
		Kit.part(m, "ChairBack", Vector3.new(2.2, 1.8, 0.4), cf * CFrame.new(0, 1.9, 1.0), L.leather, { collide = false })
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

-- The French doors: two glazed leaves, hinged at the jambs. Closed they are solid.
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
	for _, p in { Vector3.new(36, Y, 34), Vector3.new(76, Y, 34), Vector3.new(76, Y, 58), Vector3.new(36, Y, 60), Vector3.new(56, Y, 34), Vector3.new(56, Y, 59) } do
		planter(m, p)
	end
	lounge(m, Vector3.new(48, Y, 46))
	lounge(m, Vector3.new(66, Y, 50))
	parasol(m, Vector3.new(57, Y, 47))
	-- A drinks cart in the corner past the doors, clear of the way in.
	local cart = Vector3.new(32.6, Y, 60.4)
	Kit.part(m, "Cart", Vector3.new(3, 0.3, 1.6), CFrame.new(cart + Vector3.new(0, 2.4, 0)), L.brass)
	Kit.part(m, "CartShelf", Vector3.new(3, 0.2, 1.6), CFrame.new(cart + Vector3.new(0, 0.9, 0)), L.darkBrass, { collide = false })
	for i = -1, 1 do
		Kit.post(m, "Bottle", 0.9, 0.3, cart + Vector3.new(i * 0.8, 2.55, 0), { color = Color3.fromRGB(40, 70, 44), material = Enum.Material.Glass, transparency = 0.2 }, { collide = false, shadow = false })
	end
	-- Strings of bulbs across the terrace, on poles.
	local poles = { Vector3.new(38, Y, 36), Vector3.new(74, Y, 36), Vector3.new(74, Y, 56), Vector3.new(38, Y, 56) }
	for _, p in poles do
		Kit.post(m, "LightPole", 10, 0.3, p, L.darkBrass, { collide = false })
	end
	for i = 1, #poles do
		local a, b = poles[i] + Vector3.new(0, 10, 0), poles[i % #poles + 1] + Vector3.new(0, 10, 0)
		bulbs(m, a, b, 9)
	end
	bulbs(m, poles[1] + Vector3.new(0, 10, 0), poles[3] + Vector3.new(0, 10, 0), 11)
	for _, p in { Vector3.new(48, Y + 8.5, 46), Vector3.new(66, Y + 8.5, 50) } do
		local glow = Kit.part(m, "BulbGlow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(p), INVISIBLE, { collide = false, query = false, shadow = false })
		Kit.pointLight(glow, 1.1, 22, Color3.fromRGB(255, 200, 140))
	end
	doors(m)
	-- A small brass plate in the Club hall beside the doors.
	local plate = Kit.part(m, "TerracePlate", Vector3.new(2.4, 0.9, 0.1), CFrame.lookAt(Vector3.new(23.9, CLUB + 5.5, z0 - 2), Vector3.new(0, CLUB + 5.5, z0 - 2)), L.brass, { collide = false })
	Kit.engrave(plate, Enum.NormalId.Front, {
		{ text = "THE TERRACE", size = 0.5, color = Color3.fromRGB(20, 16, 10) },
		{ text = "Opens in High Summer", size = 0.35, color = Color3.fromRGB(40, 32, 20) },
	})
	return m
end

-- Opens (High Summer) or closes the French doors, swinging each leaf out onto the steps.
function Terrace.setOpen(open: boolean)
	for _, leaf in CollectionService:GetTagged("TerraceDoor") do
		if leaf:IsA("BasePart") then
			local hinge = leaf:GetAttribute("Hinge")
			local dir = leaf:GetAttribute("Swing")
			if typeof(hinge) ~= "Vector3" or type(dir) ~= "number" then
				continue
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
	end
end

return Terrace

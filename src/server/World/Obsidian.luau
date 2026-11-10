--!strict
-- The Obsidian Room, now the Basement Stair (the way down into the Maison Basement): black on
-- black, polished stone, gilded objects on plinths along the far wall. The way down and the boards
-- are furnished at the grown size (World/Lobbies).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout).raw -- (the house as drawn: see World/Grand)
local Kit = require(script.Parent.Kit)
local RoomShell = require(script.Parent.RoomShell)

local L = Kit.Looks
local O = Layout.Obsidian
local FLOOR = Layout.FLOOR

local Obsidian = {}

local STONE = { color = Color3.fromRGB(10, 10, 12), material = Enum.Material.Marble, reflectance = 0.12 }
local GLOSS = { color = Color3.fromRGB(8, 8, 10), material = Enum.Material.Slate, reflectance = 0.18 }

local function plinths(m: Model)
	-- Black stone plinths along the far wall, each with a single gilded object under a pin light.
	for i, z in { 36, 46, 56 } do
		local base = Vector3.new(O.maxX - 2.4, FLOOR, z)
		Kit.part(m, "Plinth" .. i, Vector3.new(2.4, 4, 2.4), CFrame.new(base + Vector3.new(0, 2, 0)), STONE)
		Kit.part(m, "PlinthEdge" .. i, Vector3.new(2.5, 0.06, 2.5), CFrame.new(base + Vector3.new(0, 4.03, 0)), L.brass, { collide = false, shadow = false })
		Kit.ball(m, "Object" .. i, 0.9, base + Vector3.new(0, 4.5, 0), { color = Color3.fromRGB(212, 175, 84), material = Enum.Material.Metal, reflectance = 0.45 }, { collide = false })
		local pin = Kit.part(m, "PinLight" .. i, Vector3.new(0.3, 0.3, 0.3), CFrame.new(base + Vector3.new(0, 12, 0)), L.blackLacquer, { collide = false, shadow = false })
		Kit.spotLight(pin, Enum.NormalId.Bottom, 2.2, 12, 14, Color3.fromRGB(255, 236, 210))
	end
	-- A gold hairline set into the floor, door to far wall
	Kit.span(m, "FloorLine", Vector3.new(O.minX, FLOOR, 45.9), Vector3.new(O.maxX, FLOOR + 0.02, 46.1), L.brass, { collide = false, query = false, shadow = false })
end

function Obsidian.build(parent: Instance): Model
	local root = Kit.model(parent, "Obsidian")
	RoomShell.build(root, {
		bounds = O,
		foyerSide = "west",
		doorZ = Layout.RoomDoors.obsidian.centre.Z,
		wall = STONE,
		floor = GLOSS,
		ceiling = { color = Color3.fromRGB(6, 6, 8), material = Enum.Material.Plaster },
		wainscot = nil,
		rail = L.darkBrass,
		sharedSouth = true, -- the Midnight Room's north wall
	})
	plinths(root)
	return root
end

return Obsidian

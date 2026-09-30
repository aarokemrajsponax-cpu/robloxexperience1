--!strict
-- Your Suite (§3): the shell of the room on the Velvet Room's roof. A panelled drawing room with a
-- fireplace, windows onto the city and a bell to furnish it; two more rooms off it (the Dressing
-- Room and the Study) behind doors that open with the Gold Key. The furniture itself is drawn on
-- each guest's own screen from their own Suite (SuiteView), so every guest sees only theirs.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local S = Layout.Suite
local Y = S.floorY
local CLUB = Layout.CLUB

local SuiteRoom = {}

local PANEL = { color = Color3.fromRGB(34, 26, 22), material = Enum.Material.Wood }
local PARQUET = { color = Color3.fromRGB(64, 40, 26), material = Enum.Material.WoodPlanks }
local DOOR = { color = Color3.fromRGB(16, 14, 14), material = Enum.Material.SmoothPlastic, reflectance = 0.15 }
local SCONCE = { color = Color3.fromRGB(255, 206, 150), material = Enum.Material.Neon, transparency = 0.1 }

local function prompt(parent: Instance, name: string, action: string, object: string)
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Parent = parent
end

-- A wall along Z (fixed x range) with door openings { z0, z1, height }.
local function wallAlongZ(m: Model, name: string, x0: number, x1: number, z0: number, z1: number, top: number, openings: { { number } })
	local cursor = z0
	for _, o in openings do
		if o[1] > cursor then
			Kit.span(m, name, Vector3.new(x0, Y, cursor), Vector3.new(x1, top, o[1]), PANEL)
		end
		Kit.span(m, name .. "OverDoor", Vector3.new(x0, Y + o[3], o[1]), Vector3.new(x1, top, o[2]), PANEL)
		cursor = o[2]
	end
	if cursor < z1 then
		Kit.span(m, name, Vector3.new(x0, Y, cursor), Vector3.new(x1, top, z1), PANEL)
	end
end

function SuiteRoom.build(parent: Instance): Model
	local m = Kit.model(parent, "Suite")
	local top = Y + S.height
	local main, dressing, study = S.main, S.dressing, S.study
	local dz0, dz1 = S.door.Z - S.doorWidth / 2, S.door.Z + S.doorWidth / 2

	-- The corridor from the Club hall: a step up, then level, carpeted.
	Kit.span(m, "Step", Vector3.new(-24, CLUB - 1, dz0), Vector3.new(-22, CLUB + 1, dz1), L.blackMarble)
	Kit.span(m, "CorridorFloor", Vector3.new(-30, CLUB - 1, dz0), Vector3.new(-24, Y, dz1), L.blackMarble)
	Kit.span(m, "CorridorRunner", Vector3.new(-36, Y, dz0 + 0.8), Vector3.new(-24, Y + 0.05, dz1 - 0.8), L.carpet, { collide = false, query = false })
	Kit.span(m, "CorridorWallS", Vector3.new(-36, CLUB, dz0 - 0.6), Vector3.new(-22, top, dz0), PANEL)
	Kit.span(m, "CorridorWallN", Vector3.new(-36, CLUB, dz1), Vector3.new(-22, top, dz1 + 0.6), PANEL)
	Kit.span(m, "CorridorCeiling", Vector3.new(-36, top, dz0 - 0.6), Vector3.new(-22, top + 1, dz1 + 0.6), L.wall)
	Kit.part(m, "CorridorSconce", Vector3.new(0.3, 0.8, 0.5), CFrame.new(-29, Y + 6, dz1 - 0.1), SCONCE, { collide = false, shadow = false })

	-- The shell: floor finish, ceiling, outer walls.
	Kit.span(m, "Parquet", Vector3.new(dressing.minX, Y - 0.1, main.minZ), Vector3.new(main.maxX, Y, main.maxZ), PARQUET)
	Kit.span(m, "Ceiling", Vector3.new(dressing.minX - 1, top, main.minZ - 1), Vector3.new(main.maxX + 1, top + 1, main.maxZ + 1), L.wall)
	Kit.span(m, "WallS", Vector3.new(dressing.minX - 1, Y, main.minZ - 1), Vector3.new(main.maxX + 1, top, main.minZ), PANEL)
	Kit.span(m, "WallN", Vector3.new(dressing.minX - 1, Y, main.maxZ), Vector3.new(main.maxX + 1, top, main.maxZ + 1), PANEL)
	Kit.span(m, "WallFar", Vector3.new(dressing.minX - 1, Y, main.minZ), Vector3.new(dressing.minX, top, main.maxZ), PANEL)
	wallAlongZ(m, "WallE", main.maxX, main.maxX + 1, main.minZ, main.maxZ, top, { { dz0, dz1, S.doorHeight } })
	-- Between the drawing room and the two rooms off it, and between those two.
	wallAlongZ(m, "WallW", main.minX - 0.5, main.minX, main.minZ, main.maxZ, top, {
		{ study.door.Z - 2, study.door.Z + 2, 9 },
		{ dressing.door.Z - 2, dressing.door.Z + 2, 9 },
	})
	Kit.span(m, "WallBetween", Vector3.new(dressing.minX, Y, dressing.minZ - 0.25), Vector3.new(dressing.maxX - 0.5, top, dressing.minZ + 0.25), PANEL)

	-- The Gold Key rooms' doors: shut, until the guest's own screen opens them.
	local alcoves: { { room: string, at: Vector3 } } = { { room = "dressing", at = dressing.door }, { room = "study", at = study.door } }
	for _, alcove in alcoves do
		local room, at = alcove.room, alcove.at
		local door = Kit.part(m, "AlcoveDoor", Vector3.new(0.3, 9, 4), CFrame.new(at + Vector3.new(-0.25, 4.5, 0)), DOOR)
		door:SetAttribute("Room", room)
		CollectionService:AddTag(door, "SuiteAlcove")
		Kit.part(door, "Plate", Vector3.new(0.05, 0.5, 1.6), CFrame.new(at + Vector3.new(0.12, 6.2, 0)), L.brass, { collide = false })
	end

	-- Windows onto the city along the south wall.
	for _, x in { -54, -44 } do
		Kit.part(m, "Window", Vector3.new(4, 7, 0.2), CFrame.new(x, Y + 5.5, main.minZ + 0.05), L.smokedGlass, { collide = false })
		Kit.part(m, "WindowFrame", Vector3.new(4.4, 7.4, 0.1), CFrame.new(x, Y + 5.5, main.minZ - 0.1), L.brass, { collide = false })
		Kit.part(m, "CityBeyond", Vector3.new(4, 7, 0.1), CFrame.new(x, Y + 5.5, main.minZ - 0.3), L.skyline, { collide = false })
	end

	-- The fireplace on the north wall, under the spot for a painting.
	local fx, fz = -49, main.maxZ
	Kit.part(m, "Mantel", Vector3.new(7, 0.5, 1.4), CFrame.new(fx, Y + 4.4, fz - 0.7), L.boneMarble)
	Kit.part(m, "Surround", Vector3.new(6, 4.2, 0.9), CFrame.new(fx, Y + 2.1, fz - 0.45), L.boneMarble)
	Kit.part(m, "Firebox", Vector3.new(3.4, 2.6, 0.95), CFrame.new(fx, Y + 1.3, fz - 0.5), L.ink, { collide = false })
	local fire = Kit.part(m, "Fire", Vector3.new(2.2, 0.9, 0.5), CFrame.new(fx, Y + 0.6, fz - 0.8), L.fire, { collide = false, shadow = false })
	local light = Kit.pointLight(fire, 1.4, 20, Color3.fromRGB(255, 150, 80))
	CollectionService:AddTag(light, "Flicker")
	light:SetAttribute("BaseBrightness", 1.4)

	-- A small chandelier over the room.
	local ch = Kit.part(m, "Chandelier", Vector3.new(1.4, 0.6, 1.4), CFrame.new(-49, top - 2.2, 50), L.brass, { collide = false })
	Kit.pointLight(ch, 0.9, 26, Color3.fromRGB(255, 210, 160))
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		Kit.ball(m, "ChandelierLight", 0.3, Vector3.new(-49 + math.cos(a) * 1.3, top - 2.6, 50 + math.sin(a) * 1.3), SCONCE, { collide = false, query = false, shadow = false })
	end
	-- Sconces in the two rooms off it (no lights of their own: the light budget).
	for _, p in { Vector3.new(-69, Y + 6, 59.8), Vector3.new(-69, Y + 6, 40.2) } do
		Kit.part(m, "Sconce", Vector3.new(0.5, 0.8, 0.3), CFrame.new(p), SCONCE, { collide = false, shadow = false })
	end

	-- The bell to furnish the Suite, and the wardrobe where the guest's looks hang.
	Kit.post(m, "BellStand", 3.2, 0.5, S.furnish.Position, L.darkWood)
	local bell = Kit.ball(m, "FurnishBell", 0.6, S.furnish.Position + Vector3.new(0, 3.5, 0), L.brass, { collide = false })
	prompt(bell, "FurnishPrompt", "Furnish", "Your Suite")
	CollectionService:AddTag(bell, "SuiteFurnish")
	local cabinet = Kit.part(m, "Wardrobe", Vector3.new(4, 8, 1.6), S.wardrobe * CFrame.new(0, 4, 0), L.walnut)
	Kit.part(m, "WardrobeTrim", Vector3.new(0.1, 7, 0.05), S.wardrobe * CFrame.new(0, 4, -0.82), L.brass, { collide = false })
	prompt(cabinet, "SuiteWardrobePrompt", "Wardrobe", "Your looks")
	CollectionService:AddTag(cabinet, "WardrobeMirror")
	return m
end

return SuiteRoom

--!strict
-- Your Suite (§3): the penthouse on the roofs of the Velvet Room and the Salon. The server builds
-- its shell (walls, floors, ceilings, doors, windows, the fire, the light) and the few things
-- every guest shares (the bell to furnish it, the wardrobe, the Gold Key rooms' doors). The
-- furniture is drawn on each guest's own screen from their own Suite (SuiteView), so every
-- guest sees only theirs.
--
--   the gallery      from the Club hall's west door, with two places for pictures
--   the drawing room the fire on the north wall, a coffered ceiling, a window on the city
--   the bedroom      south of it, glass doors to the terrace
--   the bath and spa beyond the bedroom: marble, a frosted window
--   the kitchen      east of the bedroom, glass to the terrace
--   the terrace      out on the Salon's roof: a stone deck, glass to the street, string lights
--   the screening room and the gym   pavilions on the terrace's west side
--   the Dressing Room and the Study  the Gold Key's rooms, west of the drawing room

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout).raw -- (the house as drawn: see World/Grand)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local S = Layout.Suite
local Y = S.floorY
local CLUB = Layout.CLUB
local TOP = Y + S.height -- the ceilings' underside

local SuiteRoom = {}

local rgb = Color3.fromRGB
local function look(c: Color3, m: Enum.Material, refl: number?, transp: number?): Kit.Look
	return { color = c, material = m, reflectance = refl, transparency = transp }
end

-- The finishes.
local PANEL = look(rgb(34, 26, 22), Enum.Material.Wood)
local WALNUT = look(rgb(56, 34, 22), Enum.Material.Wood)
local PARQUET = look(rgb(70, 44, 28), Enum.Material.WoodPlanks)
local PARQUET2 = look(rgb(58, 36, 22), Enum.Material.WoodPlanks)
local SILK = look(rgb(54, 22, 30), Enum.Material.Fabric) -- the bedroom's walls
local CARPET = look(rgb(64, 54, 50), Enum.Material.Carpet)
local CINEMA = look(rgb(20, 18, 22), Enum.Material.Fabric)
local CINEMA_CARPET = look(rgb(46, 14, 22), Enum.Material.Carpet)
local MARBLE = look(rgb(232, 226, 214), Enum.Material.Marble, 0.06)
local BLACK_MARBLE = L.blackMarble
local TILE = look(rgb(214, 208, 198), Enum.Material.Marble, 0.05)
local RUBBER = look(rgb(30, 30, 33), Enum.Material.Rubber)
local DECK = look(rgb(196, 180, 152), Enum.Material.Limestone)
local DECK2 = look(rgb(184, 168, 140), Enum.Material.Limestone)
local CEILING = look(rgb(28, 26, 28), Enum.Material.Plaster)
local LACQUER = L.blackLacquer
local BRASS = L.brass
local GLASS = look(rgb(170, 196, 210), Enum.Material.Glass, 0.18, 0.62)
local GLOW = look(rgb(255, 214, 160), Enum.Material.Neon, nil, 0.1)
local LEAF = look(rgb(44, 82, 50), Enum.Material.Grass)
local LEAF2 = look(rgb(32, 64, 40), Enum.Material.Grass)
local DOOR = look(rgb(16, 14, 14), Enum.Material.SmoothPlastic, 0.15)
local SCONCE = look(rgb(255, 206, 150), Enum.Material.Neon, nil, 0.1)
local TRIM = { collide = false, query = false, shadow = false }

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

-- A wall running along X (between z0 and z1, x0 to x1) from the floor to `top`, with openings
-- { from, to, height } along X. Returns nothing; builds the pieces into `m`.
local function wallAlongX(m: Instance, name: string, z0: number, z1: number, x0: number, x1: number, lk: Kit.Look, openings: { { number } }?, top: number?)
	local t = top or TOP
	local cursor = x0
	for _, o in (openings or {}) :: { { number } } do
		if o[1] > cursor then
			Kit.span(m, name, Vector3.new(cursor, Y, z0), Vector3.new(o[1], t, z1), lk)
		end
		Kit.span(m, name .. "Over", Vector3.new(o[1], Y + o[3], z0), Vector3.new(o[2], t, z1), lk)
		cursor = o[2]
	end
	if cursor < x1 then
		Kit.span(m, name, Vector3.new(cursor, Y, z0), Vector3.new(x1, t, z1), lk)
	end
end

-- The same along Z (between x0 and x1, z0 to z1), openings { from, to, height } along Z.
local function wallAlongZ(m: Instance, name: string, x0: number, x1: number, z0: number, z1: number, lk: Kit.Look, openings: { { number } }?, top: number?)
	local t = top or TOP
	local cursor = z0
	for _, o in (openings or {}) :: { { number } } do
		if o[1] > cursor then
			Kit.span(m, name, Vector3.new(x0, Y, cursor), Vector3.new(x1, t, o[1]), lk)
		end
		Kit.span(m, name .. "Over", Vector3.new(x0, Y + o[3], o[1]), Vector3.new(x1, t, o[2]), lk)
		cursor = o[2]
	end
	if cursor < z1 then
		Kit.span(m, name, Vector3.new(x0, Y, cursor), Vector3.new(x1, t, z1), lk)
	end
end

-- A doorway's casing: two jambs and a head in `lk`, on both faces of a wall `thick` deep
-- centred at `at` (axis: "x" if you walk through along X).
local function casing(m: Instance, at: Vector3, axis: string, width: number, height: number, thick: number, lk: Kit.Look)
	local w2 = width / 2
	for _, side in { -1, 1 } do
		local off = side * (thick / 2 + 0.06)
		if axis == "z" then
			Kit.part(m, "Jamb", Vector3.new(0.35, height, 0.12), CFrame.new(at.X - w2 - 0.17, Y + height / 2, at.Z + off), lk, TRIM)
			Kit.part(m, "Jamb", Vector3.new(0.35, height, 0.12), CFrame.new(at.X + w2 + 0.17, Y + height / 2, at.Z + off), lk, TRIM)
			Kit.part(m, "Head", Vector3.new(width + 0.7, 0.4, 0.12), CFrame.new(at.X, Y + height + 0.2, at.Z + off), lk, TRIM)
		else
			Kit.part(m, "Jamb", Vector3.new(0.12, height, 0.35), CFrame.new(at.X + off, Y + height / 2, at.Z - w2 - 0.17), lk, TRIM)
			Kit.part(m, "Jamb", Vector3.new(0.12, height, 0.35), CFrame.new(at.X + off, Y + height / 2, at.Z + w2 + 0.17), lk, TRIM)
			Kit.part(m, "Head", Vector3.new(0.12, 0.4, width + 0.7), CFrame.new(at.X + off, Y + height + 0.2, at.Z), lk, TRIM)
		end
	end
end

-- A ceiling light: a small glowing disc under the ceiling, lit (a house lamp, so the seasons
-- tint it).
local function ceilingLight(m: Instance, at: Vector3, brightness: number, range: number, colour: Color3?)
	local can = Kit.cylinder(m, "CeilingLight", 0.12, 1.1, CFrame.new(at.X, TOP - 0.06, at.Z) * CFrame.Angles(0, 0, math.rad(90)), SCONCE, TRIM)
	Kit.pointLight(can, brightness, range, colour or rgb(255, 210, 160))
	return can
end

-- A run of skirting along a wall face (from a to b at the floor), in `lk`.
local function skirting(m: Instance, a: Vector3, b: Vector3, lk: Kit.Look)
	Kit.span(m, "Skirting", Vector3.new(a.X, Y, a.Z), Vector3.new(b.X, Y + 0.5, b.Z), lk, TRIM)
end

---------------------------------------------------------------------------------------------------
-- The gallery from the Club hall
---------------------------------------------------------------------------------------------------
local function gallery(m: Model)
	local dz0, dz1 = S.door.Z - S.doorWidth / 2, S.door.Z + S.doorWidth / 2
	-- A step up from the hall, then level, a runner down the middle.
	Kit.span(m, "Step", Vector3.new(-24, CLUB - 1, dz0), Vector3.new(-22, CLUB + 1, dz1), BLACK_MARBLE)
	Kit.span(m, "GalleryFloor", Vector3.new(-30, CLUB - 1, dz0), Vector3.new(-24, Y, dz1), BLACK_MARBLE)
	Kit.span(m, "GalleryFloorW", Vector3.new(-36, Y - 1, dz0), Vector3.new(-30, Y, dz1), BLACK_MARBLE)
	Kit.span(m, "GalleryRunner", Vector3.new(-36, Y, dz0 + 0.9), Vector3.new(-24, Y + 0.05, dz1 - 0.9), L.carpet, TRIM)
	Kit.span(m, "GalleryWallS", Vector3.new(-36, CLUB, dz0 - 0.6), Vector3.new(-22, TOP, dz0), LACQUER)
	Kit.span(m, "GalleryWallN", Vector3.new(-36, CLUB, dz1), Vector3.new(-22, TOP, dz1 + 0.6), LACQUER)
	Kit.span(m, "GalleryCeiling", Vector3.new(-36, TOP, dz0 - 0.6), Vector3.new(-22, TOP + 1, dz1 + 0.6), CEILING)
	-- A brass rail at picture height, and a light above where each picture hangs.
	for _, z in { dz0 + 0.02, dz1 - 0.02 } do
		Kit.span(m, "PictureRail", Vector3.new(-35.8, TOP - 1.2, z - 0.04), Vector3.new(-22.2, TOP - 1.1, z + 0.04), BRASS, TRIM)
	end
	local lamp = Kit.part(m, "GalleryLight", Vector3.new(6, 0.12, 0.5), CFrame.new(-29, TOP - 0.06, S.door.Z), SCONCE, TRIM)
	Kit.spotLight(lamp, Enum.NormalId.Bottom, 0.9, 14, 110, nil, false)
end

---------------------------------------------------------------------------------------------------
-- The drawing room (and the Gold Key rooms beside it)
---------------------------------------------------------------------------------------------------
local function drawingRoom(m: Model)
	local main, dressing, study = S.main, S.dressing, S.study
	local dz0, dz1 = S.door.Z - S.doorWidth / 2, S.door.Z + S.doorWidth / 2
	local bd = S.bedroom.door
	-- Herringbone, near enough: planks of two tones, laid in rows.
	Kit.span(m, "Parquet", Vector3.new(dressing.minX - 1, Y - 0.1, main.minZ), Vector3.new(main.maxX, Y, main.maxZ), PARQUET)
	for i = 0, 9 do
		local z = main.minZ + 1 + i * 2
		Kit.span(m, "Plank", Vector3.new(main.minX + 0.5, Y, z), Vector3.new(main.maxX - 0.5, Y + 0.02, z + 0.9), PARQUET2, TRIM)
	end
	Kit.span(m, "Ceiling", Vector3.new(dressing.minX - 1, TOP, main.minZ), Vector3.new(main.maxX + 1, TOP + 1, main.maxZ + 1), CEILING)
	-- The coffered ceiling: walnut beams in a grid, a gold line under each.
	for x = main.minX + 4.333, main.maxX - 1, 4.333 do
		Kit.span(m, "Beam", Vector3.new(x - 0.3, TOP - 0.7, main.minZ), Vector3.new(x + 0.3, TOP, main.maxZ), WALNUT, TRIM)
	end
	for z = main.minZ + 5, main.maxZ - 1, 5 do
		Kit.span(m, "Beam", Vector3.new(main.minX, TOP - 0.7, z - 0.3), Vector3.new(main.maxX, TOP, z + 0.3), WALNUT, TRIM)
	end
	-- The walls: the north (the fire and a window), the south (to the bedroom), the east (to the
	-- gallery), the west (the Gold Key rooms), the far wall beyond them.
	wallAlongX(m, "WallN", main.maxZ, main.maxZ + 1, dressing.minX - 1, main.maxX + 1, PANEL, { { -41.5, -37.5, 8.5 } })
	wallAlongX(m, "WallS", main.minZ - 1, main.minZ, dressing.minX - 1, main.maxX + 1, PANEL, { { bd.X - 2, bd.X + 2, S.innerDoorHeight } })
	wallAlongZ(m, "WallE", main.maxX, main.maxX + 1, main.minZ, main.maxZ, PANEL, { { dz0, dz1, S.doorHeight } })
	wallAlongZ(m, "WallW", main.minX - 0.5, main.minX, main.minZ, main.maxZ, PANEL, {
		{ study.door.Z - 2, study.door.Z + 2, S.innerDoorHeight },
		{ dressing.door.Z - 2, dressing.door.Z + 2, S.innerDoorHeight },
	})
	Kit.span(m, "WallFar", Vector3.new(dressing.minX - 1, Y, main.minZ), Vector3.new(dressing.minX, TOP, main.maxZ), PANEL)
	Kit.span(m, "WallBetween", Vector3.new(dressing.minX, Y, dressing.minZ - 0.25), Vector3.new(dressing.maxX - 0.5, TOP, dressing.minZ + 0.25), PANEL)
	-- A gold dado rail round the drawing room (broken at the bedroom's door and the window), and
	-- a marble skirting under the north wall.
	local runs = {
		{ main.minX, -41.5, main.maxZ - 0.06, main.maxZ - 0.01 },
		{ -37.5, main.maxX, main.maxZ - 0.06, main.maxZ - 0.01 },
		{ main.minX, bd.X - 2.4, main.minZ + 0.01, main.minZ + 0.06 },
		{ bd.X + 2.4, main.maxX, main.minZ + 0.01, main.minZ + 0.06 },
	}
	for _, run in runs do
		Kit.span(m, "Dado", Vector3.new(run[1], Y + 3.4, run[3]), Vector3.new(run[2], Y + 3.55, run[4]), BRASS, TRIM)
	end
	skirting(m, Vector3.new(main.minX, 0, main.maxZ - 0.12), Vector3.new(-41.5, 0, main.maxZ), BLACK_MARBLE)
	skirting(m, Vector3.new(-37.5, 0, main.maxZ - 0.12), Vector3.new(main.maxX, 0, main.maxZ), BLACK_MARBLE)
	-- The window on the city, east of the fire, and the night beyond it.
	Kit.part(m, "Window", Vector3.new(4, 8.5, 0.12), CFrame.new(-39.5, Y + 4.25, main.maxZ + 0.5), GLASS, { shadow = false })
	Kit.part(m, "Mullion", Vector3.new(0.12, 8.5, 0.2), CFrame.new(-39.5, Y + 4.25, main.maxZ + 0.5), BRASS, TRIM)
	Kit.part(m, "Transom", Vector3.new(4, 0.12, 0.2), CFrame.new(-39.5, Y + 6, main.maxZ + 0.5), BRASS, TRIM)
	Kit.part(m, "CityBeyond", Vector3.new(14, 12, 0.2), CFrame.new(-39.5, Y + 4, main.maxZ + 6), L.skyline, TRIM)
	for i = 0, 7 do
		local x = -45 + (i * 37 % 11)
		local y = Y + 1.5 + (i * 23 % 7)
		Kit.part(m, "CityLight", Vector3.new(0.4, 0.5, 0.1), CFrame.new(x, y, main.maxZ + 5.85), L.cityLight, TRIM)
	end
	casing(m, Vector3.new(bd.X, Y, main.minZ - 0.5), "z", 4, S.innerDoorHeight, 1, BRASS)
	casing(m, Vector3.new(main.maxX + 0.5, Y, S.door.Z), "x", S.doorWidth, S.doorHeight, 1, BRASS)

	-- The fire on the north wall, the painting's place above it.
	local fx, fz = S.spots.painting.Position.X, main.maxZ
	Kit.part(m, "Mantel", Vector3.new(7.4, 0.5, 1.5), CFrame.new(fx, Y + 4.5, fz - 0.75), MARBLE)
	Kit.part(m, "Surround", Vector3.new(6.2, 4.3, 0.9), CFrame.new(fx, Y + 2.15, fz - 0.45), MARBLE)
	Kit.part(m, "Hearth", Vector3.new(7.4, 0.2, 1.8), CFrame.new(fx, Y + 0.1, fz - 1.4), BLACK_MARBLE)
	Kit.part(m, "Firebox", Vector3.new(3.4, 2.6, 0.95), CFrame.new(fx, Y + 1.3, fz - 0.5), L.ink, TRIM)
	local fire = Kit.part(m, "Fire", Vector3.new(2.2, 0.9, 0.5), CFrame.new(fx, Y + 0.65, fz - 0.8), L.fire, TRIM)
	local light = Kit.pointLight(fire, 1.4, 20, rgb(255, 150, 80))
	CollectionService:AddTag(light, "Flicker")
	light:SetAttribute("BaseBrightness", 1.4)
	for i = -1, 1 do
		Kit.cylinder(m, "Log", 2.4, 0.4, CFrame.new(fx, Y + 0.45 + (i == 0 and 0.3 or 0), fz - 0.6 + i * 0.15) * CFrame.Angles(0, math.rad(i * 12), 0), L.walnut, TRIM)
	end
	-- The room's own light: a cove of warm light round the coffers, and two lamps by the fire.
	ceilingLight(m, Vector3.new(-55.5, 0, 52.5), 1.0, 26)
	ceilingLight(m, Vector3.new(-42.5, 0, 47.5), 0.6, 18)
	for _, x in { fx - 4.6, fx + 4.6 } do
		Kit.part(m, "Sconce", Vector3.new(0.5, 0.9, 0.3), CFrame.new(x, Y + 6.2, fz - 0.2), SCONCE, TRIM)
	end

	-- The Gold Key rooms' doors: shut, until the guest's own screen opens them.
	local alcoves: { { room: string, at: Vector3 } } = { { room = "dressing", at = dressing.door }, { room = "study", at = study.door } }
	for _, alcove in alcoves do
		local room, at = alcove.room, alcove.at
		local door = Kit.part(m, "AlcoveDoor", Vector3.new(0.3, S.innerDoorHeight, 4), CFrame.new(at + Vector3.new(-0.25, S.innerDoorHeight / 2, 0)), DOOR)
		door:SetAttribute("Room", room)
		CollectionService:AddTag(door, "SuiteAlcove")
		Kit.part(door, "Plate", Vector3.new(0.05, 0.5, 1.6), CFrame.new(at + Vector3.new(0.12, 6.2, 0)), BRASS, { collide = false })
		casing(m, Vector3.new(main.minX - 0.25, Y, at.Z), "x", 4, S.innerDoorHeight, 0.5, BRASS)
	end
	-- Sconces in the two rooms (no lights of their own: the light budget).
	for _, p in { Vector3.new(-69, Y + 6, 59.8), Vector3.new(-69, Y + 6, 40.2) } do
		Kit.part(m, "Sconce", Vector3.new(0.5, 0.8, 0.3), CFrame.new(p), SCONCE, TRIM)
	end
end

---------------------------------------------------------------------------------------------------
-- The bedroom, the bath and spa, and the kitchen (between the drawing room and the terrace)
---------------------------------------------------------------------------------------------------
local function middleRow(m: Model)
	local bed, spa, kit = S.bedroom, S.spa, S.kitchen
	local z0, z1 = 24, 39 -- the rooms' floor runs between the two walls
	-- Floors: carpet, marble, tiles.
	Kit.span(m, "BedroomFloor", Vector3.new(bed.minX, Y - 0.1, z0), Vector3.new(bed.maxX, Y, z1), CARPET)
	Kit.span(m, "SpaFloor", Vector3.new(spa.minX, Y - 0.1, z0), Vector3.new(spa.maxX, Y, z1), MARBLE)
	for i = 0, 3 do
		Kit.span(m, "SpaInlay", Vector3.new(spa.minX + 0.5, Y, z0 + 2 + i * 3.4), Vector3.new(spa.maxX - 0.5, Y + 0.02, z0 + 2.2 + i * 3.4), BRASS, TRIM)
	end
	Kit.span(m, "KitchenFloor", Vector3.new(kit.minX, Y - 0.1, z0), Vector3.new(kit.maxX, Y, z1), TILE)
	for x = kit.minX + 1.5, kit.maxX - 0.5, 1.5 do
		Kit.span(m, "TileJoint", Vector3.new(x - 0.03, Y, z0), Vector3.new(x + 0.03, Y + 0.02, z1), look(rgb(170, 164, 154), Enum.Material.Marble), TRIM)
	end
	Kit.span(m, "RowCeiling", Vector3.new(spa.minX - 1, TOP, z0 - 1), Vector3.new(kit.maxX + 1, TOP + 1, z1), CEILING)
	-- The bedroom's tray ceiling: a recess lined with a strip of warm light.
	Kit.span(m, "Tray", Vector3.new(bed.minX + 2, TOP - 0.5, z0 + 2), Vector3.new(bed.maxX - 2, TOP - 0.4, z1 - 2), WALNUT, TRIM)
	-- Walls: the west (outside), the spa | bedroom, the bedroom | kitchen, the east (outside),
	-- and the south to the terrace, with its glass doors.
	Kit.span(m, "WallW", Vector3.new(spa.minX - 1, Y, z0 - 1), Vector3.new(spa.minX, TOP, z1), PANEL)
	wallAlongZ(m, "WallSpa", spa.maxX, bed.minX, z0, z1, PANEL, { { spa.door.Z - 2, spa.door.Z + 2, S.innerDoorHeight } })
	Kit.span(m, "WallKitchen", Vector3.new(bed.maxX, Y, z0), Vector3.new(kit.minX, TOP, z1), PANEL)
	Kit.span(m, "WallE", Vector3.new(kit.maxX, Y, z0 - 1), Vector3.new(kit.maxX + 1, TOP, z1 + 1), PANEL)
	local btd, ktd = bed.terraceDoor, kit.terraceDoor
	wallAlongX(m, "WallS", z0 - 1, z0, spa.minX - 1, kit.maxX + 1, PANEL, {
		{ btd.X - 2, btd.X + 2, S.innerDoorHeight },
		{ ktd.X - 5.5, ktd.X + 4.5, S.innerDoorHeight },
	})
	-- Finishes on each room's walls: silk in the bedroom, marble in the spa.
	-- Silk on the bedroom's north wall behind the bed, either side of the door.
	local doorW, doorE = bed.door.X - 2.4, bed.door.X + 2.4
	Kit.span(m, "SilkN", Vector3.new(bed.minX, Y + 0.5, z1 - 0.06), Vector3.new(doorW, TOP - 0.5, z1 - 0.01), SILK, TRIM)
	Kit.span(m, "SilkN", Vector3.new(doorE, Y + 0.5, z1 - 0.06), Vector3.new(bed.maxX, TOP - 0.5, z1 - 0.01), SILK, TRIM)
	for i = 0, 6 do
		local x = bed.minX + 1.2 + i * 2.4
		if x < doorW - 0.1 or x > doorE + 0.1 then
			Kit.span(m, "SilkSeam", Vector3.new(x - 0.04, Y + 0.5, z1 - 0.09), Vector3.new(x + 0.04, TOP - 0.5, z1 - 0.05), BRASS, TRIM)
		end
	end
	Kit.span(m, "SpaMarbleN", Vector3.new(spa.minX, Y, z1 - 0.06), Vector3.new(spa.maxX, TOP, z1 - 0.01), MARBLE, TRIM)
	Kit.span(m, "SpaMarbleW", Vector3.new(spa.minX + 0.01, Y, z0), Vector3.new(spa.minX + 0.06, TOP, z1), MARBLE, TRIM)
	Kit.span(m, "SpaMarbleS", Vector3.new(spa.minX, Y, z0 + 0.01), Vector3.new(spa.maxX, TOP, z0 + 0.06), MARBLE, TRIM)
	Kit.span(m, "SpaBand", Vector3.new(spa.minX + 0.06, Y + 7.2, z0 + 0.06), Vector3.new(spa.minX + 0.1, Y + 7.5, z1 - 0.06), BRASS, TRIM)
	-- The spa's frosted window (onto the west).
	Kit.part(m, "Frosted", Vector3.new(0.1, 5, 6), CFrame.new(spa.minX + 0.12, Y + 6.5, 31.5), look(rgb(236, 240, 244), Enum.Material.Neon, nil, 0.55), TRIM)
	Kit.part(m, "FrostedFrame", Vector3.new(0.08, 5.3, 6.3), CFrame.new(spa.minX + 0.08, Y + 6.5, 31.5), BRASS, TRIM)
	-- The glass beside the kitchen's door, floor to ceiling; the bedroom's doors glazed.
	for _, pane in { { ktd.X - 3.75, 3.5 }, { ktd.X + 3.25, 2.5 } } do
		local x, w = pane[1], pane[2]
		Kit.part(m, "Glazing", Vector3.new(w, S.innerDoorHeight, 0.12), CFrame.new(x, Y + S.innerDoorHeight / 2, z0 - 0.5), GLASS, { shadow = false })
	end
	for _, x in { btd.X - 2.05, btd.X + 2.05, ktd.X - 5.55, ktd.X - 2.05, ktd.X + 2.05, ktd.X + 4.45 } do
		Kit.part(m, "Frame", Vector3.new(0.1, S.innerDoorHeight, 0.25), CFrame.new(x, Y + S.innerDoorHeight / 2, z0 - 0.5), BRASS, TRIM)
	end
	casing(m, Vector3.new(btd.X, Y, z0 - 0.5), "z", 4, S.innerDoorHeight, 1, BRASS)
	casing(m, Vector3.new(spa.door.X, Y, spa.door.Z), "x", 4, S.innerDoorHeight, 1, BRASS)
	-- Light: one in each room, and the bedroom's cove.
	local bedLight = Kit.cylinder(m, "CeilingLight", 0.12, 1.1, CFrame.new((bed.minX + bed.maxX) / 2, TOP - 0.56, 31.5) * CFrame.Angles(0, 0, math.rad(90)), SCONCE, TRIM)
	Kit.pointLight(bedLight, 0.9, 22, rgb(255, 200, 160))
	ceilingLight(m, Vector3.new((spa.minX + spa.maxX) / 2, 0, 31.5), 0.9, 20, rgb(240, 236, 230))
	ceilingLight(m, Vector3.new((kit.minX + kit.maxX) / 2, 0, 31.5), 0.9, 18, rgb(255, 230, 200))
	for _, x in { bed.minX + 2.1, bed.maxX - 2.1 } do
		Kit.span(m, "Cove", Vector3.new(x - 0.05, TOP - 0.45, z0 + 2), Vector3.new(x + 0.05, TOP - 0.4, z1 - 2), GLOW, TRIM)
	end
	-- The wardrobe where the guest's looks hang.
	local cabinet = Kit.part(m, "Wardrobe", Vector3.new(4, 8, 1.6), S.wardrobe * CFrame.new(0, 4, 0), WALNUT)
	Kit.part(m, "WardrobeTrim", Vector3.new(0.1, 7, 0.05), S.wardrobe * CFrame.new(0, 4, -0.82), BRASS, { collide = false })
	for _, x in { -0.45, 0.45 } do
		Kit.part(m, "WardrobePull", Vector3.new(0.08, 1.4, 0.08), S.wardrobe * CFrame.new(x, 4.2, -0.86), BRASS, TRIM)
	end
	prompt(cabinet, "SuiteWardrobePrompt", "Wardrobe", "Your looks")
	CollectionService:AddTag(cabinet, "WardrobeMirror")
end

---------------------------------------------------------------------------------------------------
-- The terrace, the screening room and the gym (on the Salon's roof)
---------------------------------------------------------------------------------------------------
local function roof(m: Model)
	local t, scr, gym = S.terrace, S.screening, S.gym
	-- The deck: stone in two tones, a grid of joints.
	local east = scr.maxX + 1 -- the deck north of the gym stops at the screening room's wall
	Kit.span(m, "Deck", Vector3.new(t.minX, Y - 0.1, t.minZ), Vector3.new(t.maxX, Y, scr.minZ - 0.5), DECK)
	Kit.span(m, "Deck", Vector3.new(east, Y - 0.1, scr.minZ - 0.5), Vector3.new(t.maxX, Y, 23), DECK)
	for x = t.minX + 3, t.maxX - 1, 3 do
		Kit.span(m, "Joint", Vector3.new(x - 0.04, Y, t.minZ), Vector3.new(x + 0.04, Y + 0.02, if x < east then scr.minZ - 0.5 else 23), DECK2, TRIM)
	end
	for z = t.minZ + 3, 22, 3 do
		Kit.span(m, "Joint", Vector3.new(if z < scr.minZ - 0.5 then t.minX else east, Y, z - 0.04), Vector3.new(t.maxX, Y + 0.02, z + 0.04), DECK2, TRIM)
	end
	-- The south edge: a stone curb with glass above it and a brass rail, the street below.
	Kit.span(m, "Curb", Vector3.new(gym.minX - 1, Y, t.minZ - 1), Vector3.new(t.maxX + 1, Y + 0.6, t.minZ), BLACK_MARBLE)
	Kit.span(m, "Balustrade", Vector3.new(t.minX, Y + 0.6, t.minZ - 0.6), Vector3.new(t.maxX, Y + 3.8, t.minZ - 0.45), GLASS)
	Kit.span(m, "Rail", Vector3.new(t.minX, Y + 3.8, t.minZ - 0.7), Vector3.new(t.maxX, Y + 4.0, t.minZ - 0.35), BRASS)
	for x = t.minX + 0.2, t.maxX, 4 do
		Kit.span(m, "Stanchion", Vector3.new(x - 0.08, Y + 0.6, t.minZ - 0.62), Vector3.new(x + 0.08, Y + 3.8, t.minZ - 0.43), BRASS, TRIM)
	end
	-- The east edge: a living wall of green against the Foyer's high wall, a planter at its foot.
	Kit.span(m, "GreenWall", Vector3.new(t.maxX, Y, t.minZ - 1), Vector3.new(t.maxX + 1, Y + 9, 23), PANEL)
	for i = 0, 19 do
		local z = t.minZ + 0.7 + i * 1.45
		for j = 0, 2 do
			Kit.part(m, "Leaves", Vector3.new(0.4, 2.8, 1.6), CFrame.new(t.maxX - 0.2, Y + 1.5 + j * 2.7 + (i % 2) * 0.6, z) * CFrame.Angles(math.rad((i * 7 + j * 13) % 20 - 10), 0, 0), if (i + j) % 3 == 0 then LEAF2 else LEAF, TRIM)
		end
	end
	Kit.span(m, "WallCap", Vector3.new(t.maxX - 0.2, Y + 9, t.minZ - 1), Vector3.new(t.maxX + 1, Y + 9.3, 23), BRASS, TRIM)
	-- String lights across the deck, on brass posts.
	local posts = { Vector3.new(-61, Y, -5.4), Vector3.new(-33.8, Y, -5.4), Vector3.new(-55, Y, 22.4), Vector3.new(-43.6, Y, 22.4) }
	for _, p in posts do
		Kit.post(m, "LightPost", 9.6, 0.25, p, BRASS)
	end
	local strands = { { posts[1], posts[4] }, { posts[2], posts[3] } }
	for _, s in strands do
		local a, b = s[1] + Vector3.new(0, 9.4, 0), s[2] + Vector3.new(0, 9.4, 0)
		local n = 14
		for i = 1, n - 1 do
			local f = i / n
			local p = a:Lerp(b, f) - Vector3.new(0, math.sin(f * math.pi) * 1.4, 0)
			local bulb = Kit.ball(m, "Festoon", 0.32, p, GLOW, TRIM)
			if i == n // 2 then
				Kit.pointLight(bulb, 1.1, 28, rgb(255, 206, 150))
			end
		end
	end
	local low = Kit.part(m, "DeckLight", Vector3.new(0.4, 0.4, 0.4), CFrame.new(-46, Y + 8.5, 4), GLOW, TRIM)
	Kit.pointLight(low, 0.9, 24, rgb(255, 210, 170))

	-- The screening room: dark fabric walls in panels, carpet, a ceiling of stars.
	Kit.span(m, "ScreeningFloor", Vector3.new(scr.minX, Y - 0.1, scr.minZ), Vector3.new(scr.maxX, Y, scr.maxZ), CINEMA_CARPET)
	wallAlongZ(m, "ScreeningE", scr.maxX, scr.maxX + 1, scr.minZ - 0.5, 23, CINEMA, { { scr.door.Z - 2, scr.door.Z + 2, S.innerDoorHeight } })
	Kit.span(m, "ScreeningS", Vector3.new(gym.maxX + 1, Y, scr.minZ - 0.5), Vector3.new(scr.maxX + 1, TOP, scr.minZ), CINEMA)
	Kit.span(m, "PavilionW", Vector3.new(scr.minX - 1, Y, gym.minZ - 1), Vector3.new(scr.minX, TOP, 23), PANEL)
	for i = 0, 6 do
		local z = scr.minZ + 1.2 + i * 2.2
		Kit.span(m, "AcousticPanel", Vector3.new(scr.minX + 0.01, Y + 1, z - 1), Vector3.new(scr.minX + 0.12, TOP - 1.5, z + 1), look(rgb(36, 30, 36), Enum.Material.Fabric), TRIM)
	end
	Kit.span(m, "PavilionRoof", Vector3.new(scr.minX - 1, TOP, scr.minZ - 0.5), Vector3.new(scr.maxX + 1, TOP + 1, 23), CEILING)
	Kit.span(m, "GymRoof", Vector3.new(gym.minX - 1, TOP, gym.minZ - 1), Vector3.new(gym.maxX + 1, TOP + 1, scr.minZ - 0.5), CEILING)
	for i = 0, 34 do
		local x = scr.minX + 1 + (i * 37 % 19)
		local z = scr.minZ + 1 + (i * 53 % 14)
		Kit.part(m, "Star", Vector3.new(0.12, 0.05, 0.12), CFrame.new(x, TOP - 0.03, z), look(rgb(255, 244, 220), Enum.Material.Neon), TRIM)
	end
	casing(m, Vector3.new(scr.maxX + 0.5, Y, scr.door.Z), "x", 4, S.innerDoorHeight, 1, BRASS)
	ceilingLight(m, Vector3.new(-62, 0, 15.2), 0.5, 18, rgb(200, 170, 255))

	-- The gym: rubber underfoot, glass to the terrace and the street, a mirror on the north wall.
	Kit.span(m, "GymFloor", Vector3.new(gym.minX, Y - 0.1, gym.minZ), Vector3.new(gym.maxX, Y, gym.maxZ), RUBBER)
	Kit.span(m, "GymN", Vector3.new(gym.minX, Y, gym.maxZ), Vector3.new(gym.maxX + 1, TOP, scr.minZ), PANEL)
	Kit.span(m, "GymMirror", Vector3.new(gym.minX + 1, Y + 0.5, gym.maxZ - 0.06), Vector3.new(gym.maxX - 1, Y + 7.5, gym.maxZ - 0.01), look(rgb(206, 212, 218), Enum.Material.Glass, 0.6, 0.05), TRIM)
	wallAlongZ(m, "GymGlassE", gym.maxX, gym.maxX + 1, gym.minZ - 1, gym.maxZ, GLASS, { { gym.door.Z - 2, gym.door.Z + 2, S.innerDoorHeight } })
	Kit.span(m, "GymGlassS", Vector3.new(gym.minX, Y + 0.6, gym.minZ - 0.6), Vector3.new(gym.maxX, TOP, gym.minZ - 0.4), GLASS)
	for x = gym.minX + 3, gym.maxX, 3 do
		Kit.span(m, "GlassFin", Vector3.new(x - 0.06, Y + 0.6, gym.minZ - 0.7), Vector3.new(x + 0.06, TOP, gym.minZ - 0.3), BRASS, TRIM)
	end
	casing(m, Vector3.new(gym.maxX + 0.5, Y, gym.door.Z), "x", 4, S.innerDoorHeight, 1, BRASS)
	ceilingLight(m, Vector3.new(-70, 0, 0.5), 0.8, 20, rgb(240, 240, 255))
end

function SuiteRoom.build(parent: Instance): Model
	local m = Kit.model(parent, "Suite")
	gallery(m)
	drawingRoom(m)
	middleRow(m)
	roof(m)
	-- The bell to furnish the Suite, by the gallery door.
	Kit.post(m, "BellStand", 3.2, 0.5, S.furnish.Position, L.darkWood)
	local bell = Kit.ball(m, "FurnishBell", 0.6, S.furnish.Position + Vector3.new(0, 3.5, 0), BRASS, { collide = false })
	prompt(bell, "FurnishPrompt", "Furnish", "Your Suite")
	CollectionService:AddTag(bell, "SuiteFurnish")
	return m
end

return SuiteRoom

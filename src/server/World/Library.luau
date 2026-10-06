--!strict
-- The Club Floor, up the Grand Stair: a gallery hall, and the Library off it. Two long tables under
-- green-shaded lamps, walls of leather spines, a rolling ladder. Where Tête-à-Tête is played.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)
local SortingTable = require(script.Parent.SortingTable)

local L = Kit.Looks
local C = Layout.Club
local B = Layout.Library
local Y = Layout.CLUB

local Library = {}

local BAIZE = { color = Color3.fromRGB(18, 44, 30), material = Enum.Material.Fabric }
local GREEN_SHADE = { color = Color3.fromRGB(26, 70, 48), material = Enum.Material.Glass, reflectance = 0.25, transparency = 0.1 }
local INVISIBLE = { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }

-- A wall along X (fixed z range) with door openings { x0, x1, height }.
local function wallAlongX(m: Model, name: string, z0: number, z1: number, x0: number, x1: number, top: number, look: Kit.Look, openings: { { number } })
	table.sort(openings, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = x0
	for _, o in openings do
		if o[1] > cursor then
			Kit.span(m, name, Vector3.new(cursor, Y, z0), Vector3.new(o[1], top, z1), look)
		end
		Kit.span(m, name .. "OverDoor", Vector3.new(o[1], Y + o[3], z0), Vector3.new(o[2], top, z1), look)
		cursor = o[2]
	end
	if cursor < x1 then
		Kit.span(m, name, Vector3.new(cursor, Y, z0), Vector3.new(x1, top, z1), look)
	end
end

local function hall(root: Model)
	local m = Kit.model(root, "ClubHall")
	local top = Y + C.height
	local dw = C.doorWidth / 2
	Kit.span(m, "Floor", Vector3.new(C.minX, Y - 1, C.minZ), Vector3.new(C.maxX, Y, C.maxZ), L.blackMarble)
	Kit.span(m, "Runner", Vector3.new(-16, Y, C.minZ + 2), Vector3.new(20, Y + 0.05, C.minZ + 8), L.carpet, { collide = false, query = false })
	Kit.span(m, "RunnerN", Vector3.new(-18, Y, C.minZ + 8), Vector3.new(-10, Y + 0.05, C.maxZ), L.carpet, { collide = false, query = false })
	Kit.span(m, "Ceiling", Vector3.new(C.minX - 2, top, C.minZ - 2), Vector3.new(C.maxX + 2, top + 1, C.maxZ + 2), L.wall)
	-- The west wall, with the door to the guests' Suites (Suite.luau builds the corridor).
	local S = Layout.Suite
	local sz0, sz1 = S.door.Z - S.doorWidth / 2, S.door.Z + S.doorWidth / 2
	Kit.span(m, "WallW", Vector3.new(C.minX - 2, Y, C.minZ - 2), Vector3.new(C.minX, top, sz0), L.greenVelvet)
	Kit.span(m, "WallW", Vector3.new(C.minX - 2, Y, sz1), Vector3.new(C.minX, top, C.maxZ + 2), L.greenVelvet)
	Kit.span(m, "WallWOverDoor", Vector3.new(C.minX - 2, Y + S.doorHeight, sz0), Vector3.new(C.minX, top, sz1), L.greenVelvet)
	Kit.span(m, "SuiteThreshold", Vector3.new(C.minX - 2, Y - 1, sz0), Vector3.new(C.minX, Y, sz1), L.blackMarble)
	-- The east wall, with the Terrace's French doors (Terrace.luau hangs the doors).
	local T = Layout.Terrace
	local tz0, tz1 = T.door.Z - T.doorWidth / 2, T.door.Z + T.doorWidth / 2
	Kit.span(m, "WallE", Vector3.new(C.maxX, Y, C.minZ - 2), Vector3.new(C.maxX + 2, top, tz0), L.greenVelvet)
	Kit.span(m, "WallE", Vector3.new(C.maxX, Y, tz1), Vector3.new(C.maxX + 2, top, C.maxZ + 2), L.greenVelvet)
	Kit.span(m, "WallEOverDoor", Vector3.new(C.maxX, Y + T.doorHeight, tz0), Vector3.new(C.maxX + 2, top, tz1), L.greenVelvet)
	Kit.span(m, "TerraceThreshold", Vector3.new(C.maxX, Y - 1, tz0), Vector3.new(C.maxX + 2, Y, tz1), L.blackMarble)
	-- The south wall above the Foyer's back wall, with the arch from the stair
	Kit.span(m, "WallS_W", Vector3.new(C.minX, Y, C.minZ), Vector3.new(4, top, C.minZ + 0.2), L.greenVelvet, { collide = false, query = false })
	Kit.span(m, "WallS_E", Vector3.new(12, Y, C.minZ), Vector3.new(C.maxX, top, C.minZ + 0.2), L.greenVelvet, { collide = false, query = false })
	Kit.span(m, "WallS_Top", Vector3.new(4, Y + 10, C.minZ), Vector3.new(12, top, C.minZ + 0.2), L.greenVelvet, { collide = false, query = false })
	Kit.span(m, "WallS_High", Vector3.new(C.minX - 2, Layout.FLOOR + Layout.Foyer.height + 1, C.minZ - 2), Vector3.new(C.maxX + 2, top, C.minZ), L.wall)
	wallAlongX(m, "WallN", C.maxZ, C.maxZ + 2, C.minX - 2, C.maxX + 2, top, L.greenVelvet, {
		{ C.libraryDoor.X - dw, C.libraryDoor.X + dw, C.doorHeight },
		{ C.ballroomDoor.X - dw, C.ballroomDoor.X + dw, C.doorHeight },
	})
	-- Wainscot and rail
	Kit.span(m, "WainscotW", Vector3.new(C.minX, Y, C.minZ), Vector3.new(C.minX + 0.4, Y + 3.8, sz0), L.walnut, { collide = false, query = false })
	Kit.span(m, "WainscotW", Vector3.new(C.minX, Y, sz1), Vector3.new(C.minX + 0.4, Y + 3.8, C.maxZ), L.walnut, { collide = false, query = false })
	Kit.span(m, "WainscotE", Vector3.new(C.maxX - 0.4, Y, C.minZ), Vector3.new(C.maxX, Y + 3.8, tz0), L.walnut, { collide = false, query = false })
	Kit.span(m, "WainscotE", Vector3.new(C.maxX - 0.4, Y, tz1), Vector3.new(C.maxX, Y + 3.8, C.maxZ), L.walnut, { collide = false, query = false })
	Kit.span(m, "RailW", Vector3.new(C.minX, Y + 3.8, C.minZ), Vector3.new(C.minX + 0.45, Y + 4, sz0), L.brass, { collide = false, query = false, shadow = false })
	Kit.span(m, "RailW", Vector3.new(C.minX, Y + 3.8, sz1), Vector3.new(C.minX + 0.45, Y + 4, C.maxZ), L.brass, { collide = false, query = false, shadow = false })
	Kit.span(m, "RailE", Vector3.new(C.maxX - 0.45, Y + 3.8, C.minZ), Vector3.new(C.maxX, Y + 4, tz0), L.brass, { collide = false, query = false, shadow = false })
	Kit.span(m, "RailE", Vector3.new(C.maxX - 0.45, Y + 3.8, tz1), Vector3.new(C.maxX, Y + 4, C.maxZ), L.brass, { collide = false, query = false, shadow = false })
	-- Portraits along the walls, each under a picture light
	for i = 1, 2 do
		for _, side in { -1, 1 } do
			local x = if side < 0 then C.minX + 0.3 else C.maxX - 0.3
			-- They hang either side of the Suite door (west) and the Terrace doors (east).
			local z = if i == 1 then 47 else 61.5
			local cf = CFrame.lookAt(Vector3.new(x, Y + 7.5, z), Vector3.new(0, Y + 7.5, z))
			Kit.part(m, "PortraitFrame" .. i, Vector3.new(4.2, 5.4, 0.3), cf, L.brass, { collide = false })
			Kit.part(m, "Portrait" .. i, Vector3.new(3.6, 4.8, 0.1), cf * CFrame.new(0, 0, -0.18), { color = Color3.fromRGB(34 + i * 6, 26, 22), material = Enum.Material.Fabric }, { collide = false })
			local lamp = Kit.part(m, "PictureLight" .. i, Vector3.new(2.4, 0.2, 0.3), cf * CFrame.new(0, 3.2, -0.6), L.brass, { collide = false })
			Kit.spotLight(lamp, Enum.NormalId.Bottom, 1.2, 10, 70)
		end
	end
	-- Benches against the side walls, under the portraits
	for _, x in { C.minX + 1.4, C.maxX - 1.4 } do
		local bz = 61.5 -- clear of the Suite door and the Terrace doors
		Kit.part(m, "Bench", Vector3.new(1.6, 0.6, 4), CFrame.new(x, Y + 1.3, bz), L.leather)
		local facing = if x < (C.minX + C.maxX) / 2 then 1 else -1
		local seats = {}
		for _, dz in { -1, 1 } do
			local at = Vector3.new(x, Y + 1.6, bz + dz)
			table.insert(seats, CFrame.lookAt(at, at + Vector3.new(facing, 0, 0)))
		end
		Furniture.seatsOn(m, "BenchSeats", seats, "The bench", 1.6)
		for _, dz in { -1.7, 1.7 } do
			Kit.part(m, "BenchLeg", Vector3.new(1.2, 1, 0.25), CFrame.new(x, Y + 0.5, bz + dz), L.darkWood)
		end
	end
	-- A small chandelier
	local c = Vector3.new(2, top - 3, 55)
	Kit.cylinder(m, "Chain", 2.5, 0.2, CFrame.new(c + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false })
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local p = c + Vector3.new(math.cos(a) * 2.2, 0, math.sin(a) * 2.2)
		Kit.post(m, "Candle", 0.6, 0.18, p, L.bone, { collide = false, shadow = false })
		Kit.part(m, "Flame", Vector3.new(0.14, 0.26, 0.14), CFrame.new(p + Vector3.new(0, 0.75, 0)), { color = Color3.fromRGB(255, 210, 140), material = Enum.Material.Neon }, { collide = false, shadow = false, query = false })
	end
	local glow = Kit.part(m, "ChandelierGlow", Vector3.new(0.3, 0.3, 0.3), CFrame.new(c), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.pointLight(glow, 1.4, 30, Color3.fromRGB(255, 200, 130), true)

	-- Door names
	local doors: { { at: Vector3, name: string } } = { { at = C.libraryDoor, name = "THE LIBRARY" }, { at = C.ballroomDoor, name = "THE BALLROOM" } }
	for _, spec in doors do
		local pos = spec.at + Vector3.new(0, C.doorHeight + 1.4, -0.3)
		local plate = Kit.part(m, "DoorName", Vector3.new(C.doorWidth, 1.2, 0.1), CFrame.new(pos), INVISIBLE, { collide = false, query = false, shadow = false })
		Kit.engrave(plate, Enum.NormalId.Front, { { text = spec.name, size = 0.7, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 60, lit = false })
		-- Brass door frame
		local d = spec.at
		Kit.part(m, "JambL", Vector3.new(0.6, C.doorHeight, 2.4), CFrame.new(d + Vector3.new(-C.doorWidth / 2 - 0.3, C.doorHeight / 2, 1)), L.brass)
		Kit.part(m, "JambR", Vector3.new(0.6, C.doorHeight, 2.4), CFrame.new(d + Vector3.new(C.doorWidth / 2 + 0.3, C.doorHeight / 2, 1)), L.brass)
		Kit.part(m, "Head", Vector3.new(C.doorWidth + 1.8, 0.7, 2.4), CFrame.new(d + Vector3.new(0, C.doorHeight + 0.35, 1)), L.brass)
	end
end

local function shelvesAlong(m: Model, a: Vector3, b: Vector3, facing: Vector3, rng: Random)
	-- A wall of leather spines from a to b (floor level), facing into the room.
	local spines = {
		Color3.fromRGB(70, 26, 22), Color3.fromRGB(34, 48, 36), Color3.fromRGB(52, 34, 22),
		Color3.fromRGB(28, 28, 44), Color3.fromRGB(96, 72, 40), Color3.fromRGB(22, 22, 24), Color3.fromRGB(80, 20, 30),
	}
	local along = (b - a)
	local length = along.Magnitude
	local dir = along.Unit
	Kit.part(m, "ShelfBack", Vector3.new(length, 13, 0.4), CFrame.lookAt((a + b) / 2 + Vector3.new(0, 6.5, 0) - facing * 1.6, (a + b) / 2 + Vector3.new(0, 6.5, 0) - facing * 1.6 + facing), L.darkWood)
	for shelf = 0, 4 do
		local y = 1.4 + shelf * 2.3
		local mid = (a + b) / 2 + Vector3.new(0, y, 0) - facing * 0.8
		Kit.part(m, "Shelf", Vector3.new(length, 0.15, 1.8), CFrame.lookAt(mid, mid + facing), L.walnut, { collide = false })
		local t = 0.3
		while t < length - 0.4 do
			local w = rng:NextNumber(0.35, 0.7)
			local h = rng:NextNumber(1.4, 2.0)
			local p = a + dir * (t + w / 2) + Vector3.new(0, y + 0.08 + h / 2, 0) - facing * 0.95
			Kit.part(m, "Book", Vector3.new(w, h, 1.3), CFrame.lookAt(p, p + facing), { color = spines[rng:NextInteger(1, #spines)], material = Enum.Material.Leather }, { collide = false, query = false, shadow = false })
			t += w + 0.03
		end
	end
end

local function libraryRoom(root: Model)
	local m = Kit.model(root, "Library")
	local top = Y + B.height
	local dw = C.doorWidth / 2
	Kit.span(m, "Floor", Vector3.new(B.minX, Y - 1, B.minZ), Vector3.new(B.maxX, Y, B.maxZ), { color = Color3.fromRGB(40, 26, 18), material = Enum.Material.WoodPlanks })
	Kit.span(m, "Ceiling", Vector3.new(B.minX - 2, top, B.minZ - 2), Vector3.new(B.maxX + 2, top + 1, B.maxZ + 2), { color = Color3.fromRGB(20, 16, 12), material = Enum.Material.Wood })
	Kit.span(m, "WallW", Vector3.new(B.minX - 2, Y, B.minZ), Vector3.new(B.minX, top, B.maxZ + 2), L.darkWood)
	Kit.span(m, "WallE", Vector3.new(B.maxX, Y, B.minZ), Vector3.new(B.maxX + 2, top, B.maxZ + 2), L.darkWood)
	Kit.span(m, "WallN", Vector3.new(B.minX - 2, Y, B.maxZ), Vector3.new(B.maxX + 2, top, B.maxZ + 2), L.darkWood)
	-- The south wall is the hall's north wall; close the part west of the hall.
	Kit.span(m, "WallS_W", Vector3.new(B.minX - 2, Y, B.minZ - 2), Vector3.new(C.minX - 2, top, B.minZ), L.darkWood)
	Kit.span(m, "FacingS_A", Vector3.new(B.minX, Y, B.minZ), Vector3.new(C.libraryDoor.X - dw, top, B.minZ + 0.2), L.darkWood, { collide = false, query = false })
	Kit.span(m, "FacingS_B", Vector3.new(C.libraryDoor.X + dw, Y, B.minZ), Vector3.new(B.maxX, top, B.minZ + 0.2), L.darkWood, { collide = false, query = false })
	Kit.span(m, "Rug", Vector3.new(B.minX + 4, Y, B.minZ + 4), Vector3.new(B.maxX - 4, Y + 0.05, B.maxZ - 4), { color = Color3.fromRGB(46, 20, 18), material = Enum.Material.Carpet }, { collide = false, query = false })
	-- Walls of leather spines
	local rng = Random.new(1789)
	shelvesAlong(m, Vector3.new(B.minX, Y, B.minZ + 3), Vector3.new(B.minX, Y, B.maxZ - 3), Vector3.new(1, 0, 0), rng)
	shelvesAlong(m, Vector3.new(B.maxX, Y, B.minZ + 3), Vector3.new(B.maxX, Y, B.maxZ - 3), Vector3.new(-1, 0, 0), rng)
	shelvesAlong(m, Vector3.new(B.minX + 3, Y, B.maxZ), Vector3.new(B.maxX - 3, Y, B.maxZ), Vector3.new(0, 0, -1), rng)
	-- The rolling ladder on its brass rail
	Kit.span(m, "LadderRail", Vector3.new(B.minX + 1.9, Y + 12, B.minZ + 3), Vector3.new(B.minX + 2.05, Y + 12.15, B.maxZ - 3), L.brass, { collide = false, query = false })
	for _, dz in { 0, 1.6 } do
		Kit.part(m, "LadderSide", Vector3.new(0.18, 12.8, 0.18), CFrame.new(B.minX + 3.4, Y + 6.3, 76 + dz) * CFrame.Angles(0, 0, math.rad(-7)), L.walnut, { collide = false })
	end
	for i = 1, 9 do
		Kit.part(m, "Rung", Vector3.new(0.14, 0.14, 1.6), CFrame.new(B.minX + 3.4 + (6.3 - i * 1.3) * math.tan(math.rad(7)), Y + i * 1.3, 76.8), L.brass, { collide = false, shadow = false })
	end
	-- Green-shaded reading lamps along the walls
	for _, z in { 74, 92 } do
		for _, x in { B.minX + 2.4, B.maxX - 2.4 } do
			local lamp = Kit.part(m, "ReadingLamp", Vector3.new(1.2, 0.5, 0.7), CFrame.new(x, Y + 5.2, z), GREEN_SHADE, { collide = false })
			Kit.pointLight(lamp, 0.8, 12, Color3.fromRGB(255, 220, 160))
		end
	end
	local fill = Kit.part(m, "FillLight", Vector3.new(1, 1, 1), CFrame.new(-17, Y + 12, 83), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.pointLight(fill, 0.4, 40, Color3.fromRGB(210, 190, 150))

	-- The duel tables: two halves end to end, the guests at opposite ends.
	local tables = Kit.folder(m, "Tables")
	local style: SortingTable.Style = {
		roomName = "Tête-à-Tête",
		top = L.walnut,
		legs = L.darkWood,
		felt = BAIZE,
		caseBase = { color = Color3.fromRGB(16, 36, 26), material = Enum.Material.Fabric },
		caseRim = L.brass,
		chair = L.leather,
		lamp = "cord",
		lampColor = Color3.fromRGB(255, 226, 176),
		lampBrightness = 1.5,
		ceiling = top,
	}
	for i, duel in B.duels do
		local frameA, frameB = Layout.duelFrames(duel.centre)
		local halves: { [string]: CFrame } = { a = frameA, b = frameB }
		for side, frame in halves do
			local half = SortingTable.build(tables, "library", tostring(i) .. side, frame, style)
			half:SetAttribute("Duel", duel.id)
			half:SetAttribute("Side", side)
			CollectionService:AddTag(half, "DuelHalf")
			local seat = half:FindFirstChild("Chair")
			local nightly = seat and seat:FindFirstChild("NightlyPrompt")
			if nightly then
				nightly:Destroy() -- the Nightly is played in the four rooms
			end
		end
		-- A brass plate between the halves: the duel's name, and the score between hands.
		local plate = Kit.part(tables, "DuelPlate" .. i, Vector3.new(2.4, 0.08, 0.9), CFrame.new(duel.centre + Vector3.new(Layout.Table.width / 2 + 0.3, Layout.Table.topY + 0.05, 0)), L.brass, { collide = false })
		plate:SetAttribute("Duel", duel.id)
	end
end

function Library.build(parent: Instance): Model
	local root = Kit.model(parent, "ClubFloor")
	hall(root)
	libraryRoom(root)
	return root
end

return Library

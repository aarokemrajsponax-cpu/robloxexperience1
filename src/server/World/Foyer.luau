--!strict
-- The Grand Foyer: black-and-bone marble, a brass chandelier, the piano, the lectern,
-- the Tonight board, the Wall of Names, four room doors, the roped-off Grand Stair and Boutique.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local F = Layout.Foyer
local FLOOR = Layout.FLOOR

local Foyer = {}

local TOP = FLOOR + F.height

local function floorTiles(m: Model)
	local tile = 6
	local nx = math.floor((F.maxX - F.minX) / tile)
	local nz = math.ceil((F.maxZ - F.minZ) / tile)
	local dz = (F.maxZ - F.minZ) / nz
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			local look = if (ix + iz) % 2 == 0 then L.blackMarble else L.boneMarble
			local x = F.minX + tile * (ix + 0.5)
			local z = F.minZ + dz * (iz + 0.5)
			Kit.part(m, "Tile", Vector3.new(tile, 1, dz), CFrame.new(x, FLOOR - 0.5, z), look)
		end
	end
	-- A long runner from the door to the stair.
	Kit.span(m, "Runner", Vector3.new(-4, FLOOR, F.minZ), Vector3.new(4, FLOOR + 0.06, F.stair.fromZ), L.carpet, { collide = false, query = false })
	Kit.span(m, "RunnerEdgeL", Vector3.new(-4.2, FLOOR, F.minZ), Vector3.new(-4, FLOOR + 0.07, F.stair.fromZ), L.brass, { collide = false, query = false })
	Kit.span(m, "RunnerEdgeR", Vector3.new(4, FLOOR, F.minZ), Vector3.new(4.2, FLOOR + 0.07, F.stair.fromZ), L.brass, { collide = false, query = false })
end

-- A wall along Z (at fixed x) with door openings: list of {fromZ, toZ, height}.
local function wallAlongZ(m: Model, name: string, x0: number, x1: number, z0: number, z1: number, openings: { { number } })
	table.sort(openings, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = z0
	for _, o in openings do
		if o[1] > cursor then
			Kit.span(m, name, Vector3.new(x0, FLOOR, cursor), Vector3.new(x1, TOP, o[1]), L.wall)
		end
		Kit.span(m, name .. "OverDoor", Vector3.new(x0, FLOOR + o[3], o[1]), Vector3.new(x1, TOP, o[2]), L.wall)
		cursor = o[2]
	end
	if cursor < z1 then
		Kit.span(m, name, Vector3.new(x0, FLOOR, cursor), Vector3.new(x1, TOP, z1), L.wall)
	end
end

local function wallAlongX(m: Model, name: string, z0: number, z1: number, x0: number, x1: number, openings: { { number } })
	table.sort(openings, function(a, b)
		return a[1] < b[1]
	end)
	local cursor = x0
	for _, o in openings do
		if o[1] > cursor then
			Kit.span(m, name, Vector3.new(cursor, FLOOR, z0), Vector3.new(o[1], TOP, z1), L.wall)
		end
		local bottom = o[4] or FLOOR
		if bottom > FLOOR then
			Kit.span(m, name .. "UnderDoor", Vector3.new(o[1], FLOOR, z0), Vector3.new(o[2], bottom, z1), L.wall)
		end
		Kit.span(m, name .. "OverDoor", Vector3.new(o[1], bottom + o[3], z0), Vector3.new(o[2], TOP, z1), L.wall)
		cursor = o[2]
	end
	if cursor < x1 then
		Kit.span(m, name, Vector3.new(cursor, FLOOR, z0), Vector3.new(x1, TOP, z1), L.wall)
	end
end

local function shell(m: Model)
	local dw = Layout.RoomDoorWidth / 2
	local dh = Layout.RoomDoorHeight
	local D = Layout.RoomDoors
	wallAlongZ(m, "WallWest", F.minX - 2, F.minX, F.minZ - 2, F.maxZ + 2, {
		{ D.salon.centre.Z - dw, D.salon.centre.Z + dw, dh },
		{ D.velvet.centre.Z - dw, D.velvet.centre.Z + dw, dh },
	})
	wallAlongZ(m, "WallEast", F.maxX, F.maxX + 2, F.minZ - 2, F.maxZ + 2, {
		{ D.midnight.centre.Z - dw, D.midnight.centre.Z + dw, dh },
		{ D.obsidian.centre.Z - dw, D.obsidian.centre.Z + dw, dh },
	})
	-- The back wall: the Boutique door and the landing door at the top of the stair.
	local b = F.boutiqueDoor.Position
	local st = F.stair
	wallAlongX(m, "WallNorth", F.maxZ, F.maxZ + 2, F.minX - 2, F.maxX + 2, {
		{ st.x - 4, st.x + 4, 10, FLOOR + st.topY },
		{ b.X - 4, b.X + 4, 10, FLOOR },
	})
	-- The front wall either side of the façade (the façade covers the middle).
	local hw = Layout.Street.houseHalfWidth
	Kit.span(m, "WallSouthL", Vector3.new(F.minX - 2, FLOOR, F.minZ - 2), Vector3.new(-hw, TOP, F.minZ), L.wall)
	Kit.span(m, "WallSouthR", Vector3.new(hw, FLOOR, F.minZ - 2), Vector3.new(F.maxX + 2, TOP, F.minZ), L.wall)
	-- The façade only reaches 62 studs; close the top of the entrance hall.
	Kit.span(m, "Ceiling", Vector3.new(F.minX - 2, TOP, F.minZ - 2), Vector3.new(F.maxX + 2, TOP + 1, F.maxZ + 2), L.wall)
	-- Coffers: a grid of shallow brass-edged panels
	for x = F.minX + 6, F.maxX - 6, 12 do
		for z = F.minZ + 6, F.maxZ - 6, 12 do
			Kit.part(m, "Coffer", Vector3.new(10, 0.5, 10), CFrame.new(x, TOP - 0.25, z), L.panel, { collide = false, query = false, shadow = false })
			Kit.part(m, "CofferEdge", Vector3.new(10.2, 0.12, 10.2), CFrame.new(x, TOP - 0.55, z), L.darkBrass, { collide = false, query = false, shadow = false })
		end
	end
	-- Wainscot and a brass hairline around the room
	local wain = FLOOR + 4.5
	for _, spec in {
		{ Vector3.new(F.minX, FLOOR, F.minZ), Vector3.new(F.minX + 0.3, wain, F.maxZ) },
		{ Vector3.new(F.maxX - 0.3, FLOOR, F.minZ), Vector3.new(F.maxX, wain, F.maxZ) },
		{ Vector3.new(F.minX, FLOOR, F.maxZ - 0.3), Vector3.new(F.maxX, wain, F.maxZ) },
	} do
		Kit.span(m, "Wainscot", spec[1], spec[2], L.panel, { collide = false, query = false })
	end
	for _, spec in {
		{ Vector3.new(F.minX, wain, F.minZ), Vector3.new(F.minX + 0.35, wain + 0.15, F.maxZ) },
		{ Vector3.new(F.maxX - 0.35, wain, F.minZ), Vector3.new(F.maxX, wain + 0.15, F.maxZ) },
		{ Vector3.new(F.minX, wain, F.maxZ - 0.35), Vector3.new(F.maxX, wain + 0.15, F.maxZ) },
		{ Vector3.new(F.minX, TOP - 3, F.minZ), Vector3.new(F.minX + 0.35, TOP - 2.85, F.maxZ) },
		{ Vector3.new(F.maxX - 0.35, TOP - 3, F.minZ), Vector3.new(F.maxX, TOP - 2.85, F.maxZ) },
	} do
		Kit.span(m, "Hairline", spec[1], spec[2], L.brass, { collide = false, query = false, shadow = false })
	end
end

local function column(m: Model, x: number, z: number)
	local base = Vector3.new(x, FLOOR, z)
	Kit.part(m, "Plinth", Vector3.new(3.4, 1, 3.4), CFrame.new(base + Vector3.new(0, 0.5, 0)), L.blackMarble)
	Kit.post(m, "Shaft", F.height - 3, 2.4, base + Vector3.new(0, 1, 0), L.blackMarble)
	Kit.part(m, "Capital", Vector3.new(3.2, 1.2, 3.2), CFrame.new(base + Vector3.new(0, F.height - 1.4, 0)), L.brass)
	Kit.part(m, "CapitalTop", Vector3.new(3.6, 0.8, 3.6), CFrame.new(base + Vector3.new(0, F.height - 0.4, 0)), L.blackMarble)
end

local function sconce(m: Model, pos: Vector3, facing: Vector3)
	local back = Kit.part(m, "SconcePlate", Vector3.new(0.9, 1.4, 0.2), CFrame.lookAt(pos, pos + facing), L.brass, { collide = false })
	local arm = pos + facing * 0.6 + Vector3.new(0, 0.3, 0)
	Kit.part(m, "SconceArm", Vector3.new(0.15, 0.15, 0.9), CFrame.lookAt(pos + facing * 0.35, pos + facing), L.brass, { collide = false })
	local shade = Kit.part(m, "SconceShade", Vector3.new(0.8, 0.7, 0.8), CFrame.new(arm), L.glassWarm, { collide = false, shadow = false })
	Kit.pointLight(shade, 1.1, 14, Color3.fromRGB(255, 188, 118))
	back.CanQuery = false
end

local function chandelier(m: Model)
	local c = F.chandelier
	local model = Kit.model(m, "Chandelier")
	Kit.cylinder(model, "Chain", TOP - c.Y - 1, 0.25, CFrame.new(c.X, (TOP + c.Y + 1) / 2, c.Z) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false })
	Kit.ball(model, "Boss", 1.6, c + Vector3.new(0, 0.8, 0), L.brass, { collide = false })
	local tiers = { { radius = 5.2, y = -1.2, candles = 14 }, { radius = 3.4, y = 0.6, candles = 10 }, { radius = 1.8, y = 2.2, candles = 6 } }
	for t, tier in tiers do
		local n = tier.candles
		for i = 1, n do
			local a = i / n * math.pi * 2
			local p = c + Vector3.new(math.cos(a) * tier.radius, tier.y, math.sin(a) * tier.radius)
			local nextA = (i + 1) / n * math.pi * 2
			local q = c + Vector3.new(math.cos(nextA) * tier.radius, tier.y, math.sin(nextA) * tier.radius)
			local seg = (q - p).Magnitude
			Kit.part(model, "Ring", Vector3.new(0.22, 0.22, seg + 0.05), CFrame.lookAt((p + q) / 2, q), L.brass, { collide = false, shadow = false })
			Kit.post(model, "Candle", 0.8, 0.2, p + Vector3.new(0, 0.1, 0), L.bone, { collide = false, shadow = false })
			Kit.part(model, "Flame", Vector3.new(0.16, 0.3, 0.16), CFrame.new(p + Vector3.new(0, 1.05, 0)), { color = Color3.fromRGB(255, 210, 140), material = Enum.Material.Neon }, { collide = false, shadow = false, query = false })
			if i % math.max(1, n // 2) == 0 then
				local arm = (p + c + Vector3.new(0, tier.y, 0)) / 2
				Kit.part(model, "Spoke", Vector3.new(0.14, 0.14, tier.radius), CFrame.lookAt(arm, p), L.brass, { collide = false, shadow = false })
			end
		end
		local core = Kit.part(model, "Glow" .. t, Vector3.new(0.4, 0.4, 0.4), CFrame.new(c + Vector3.new(0, tier.y + 1, 0)), { color = Color3.new(1, 1, 1), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
		Kit.pointLight(core, if t == 1 then 1.8 else 1.1, if t == 1 then 42 else 26, Color3.fromRGB(255, 200, 130), t == 1)
	end
end

local function piano(m: Model)
	local model = Kit.model(m, "GrandPiano")
	local cf = F.piano
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end
	-- Legs
	for _, o in { { -2.4, -2.2 }, { 2.4, -2.2 }, { 0, 3.4 } } do
		Kit.part(model, "Leg", Vector3.new(0.6, 2.6, 0.6), at(o[1], 1.3, o[2]), L.blackLacquer)
	end
	-- The body: a long case that narrows toward the tail
	Kit.part(model, "Case", Vector3.new(5.4, 1.4, 4), at(0, 3.3, -0.6), L.blackLacquer)
	Kit.part(model, "Tail", Vector3.new(3.6, 1.4, 3), at(-0.9, 3.3, 2.8), L.blackLacquer)
	Kit.part(model, "TailRound", Vector3.new(1.4, 3, 3), at(0.9, 3.3, 3.2) * CFrame.Angles(0, 0, math.rad(90)), L.blackLacquer, { shape = Enum.PartType.Cylinder })
	-- Lid, propped open
	Kit.part(model, "Lid", Vector3.new(5.2, 0.12, 6.2), at(-0.5, 5.4, 1.2) * CFrame.Angles(0, 0, math.rad(-28)) * CFrame.new(1.2, 0, 0), L.blackLacquer)
	Kit.part(model, "Prop", Vector3.new(0.08, 2, 0.08), at(1.9, 4.8, 1.2), L.brass)
	Kit.part(model, "Strings", Vector3.new(4.8, 0.05, 5.6), at(-0.3, 3.95, 0.9), L.darkBrass, { collide = false })
	-- Keyboard
	Kit.part(model, "Keybed", Vector3.new(5.2, 0.5, 1.3), at(0, 2.9, -3.2), L.blackLacquer)
	Kit.part(model, "Keys", Vector3.new(4.8, 0.12, 0.9), at(0, 3.2, -3.35), L.bone, { collide = false })
	for i = -11, 11 do
		if i % 7 ~= 0 and i % 7 ~= 3 then
			Kit.part(model, "Sharp", Vector3.new(0.08, 0.1, 0.5), at(i * 0.2, 3.3, -3.15), L.ink, { collide = false, shadow = false, query = false })
		end
	end
	Kit.part(model, "MusicDesk", Vector3.new(3, 0.9, 0.1), at(0, 4.2, -2.4) * CFrame.Angles(math.rad(-15), 0, 0), L.blackLacquer, { collide = false })
	-- Bench
	Kit.part(model, "Bench", Vector3.new(3, 0.5, 1.3), at(0, 2, -5), L.leather)
	for _, x in { -1.3, 1.3 } do
		Kit.part(model, "BenchLeg", Vector3.new(0.25, 1.8, 0.25), at(x, 0.9, -5), L.blackLacquer)
	end
	local lamp = Kit.part(model, "PianoLamp", Vector3.new(0.4, 0.4, 0.4), at(0, 7.6, -2), L.brass, { collide = false })
	Kit.spotLight(lamp, Enum.NormalId.Bottom, 1.4, 12, 60)
end

local function lectern(m: Model)
	local model = Kit.model(m, "Lectern")
	local cf = F.lectern
	Kit.part(model, "Base", Vector3.new(2.6, 0.4, 1.6), cf * CFrame.new(0, 0.2, 0), L.darkWood)
	Kit.part(model, "Column", Vector3.new(1.4, 3.4, 0.9), cf * CFrame.new(0, 2.1, 0), L.walnut)
	Kit.part(model, "Top", Vector3.new(2.6, 0.2, 1.8), cf * CFrame.new(0, 3.95, 0) * CFrame.Angles(math.rad(14), 0, 0), L.walnut)
	Kit.part(model, "Trim", Vector3.new(2.7, 0.08, 1.9), cf * CFrame.new(0, 3.83, 0) * CFrame.Angles(math.rad(14), 0, 0), L.brass, { collide = false })
	-- The ledger, open
	Kit.part(model, "LedgerL", Vector3.new(0.9, 0.08, 1.2), cf * CFrame.new(-0.46, 4.1, 0) * CFrame.Angles(math.rad(14), 0, math.rad(4)), L.bone, { collide = false })
	Kit.part(model, "LedgerR", Vector3.new(0.9, 0.08, 1.2), cf * CFrame.new(0.46, 4.1, 0) * CFrame.Angles(math.rad(14), 0, math.rad(-4)), L.bone, { collide = false })
	local lamp = Kit.part(model, "LecternLamp", Vector3.new(0.7, 0.35, 0.35), cf * CFrame.new(0.9, 4.6, 0.5), L.greenVelvet, { collide = false })
	Kit.post(model, "LampStem", 0.6, 0.1, (cf * CFrame.new(0.9, 4.05, 0.5)).Position, L.brass, { collide = false })
	Kit.pointLight(lamp, 1, 8, Color3.fromRGB(255, 214, 150))
end

local function board(m: Model, name: string, cf: CFrame, width: number, height: number): Part
	local model = Kit.model(m, name)
	Kit.part(model, "Frame", Vector3.new(width + 1, height + 1, 0.5), cf * CFrame.new(0, 0, -0.1), L.brass)
	local face = Kit.part(model, "Face", Vector3.new(width, height, 0.2), cf * CFrame.new(0, 0, -0.4), L.ink)
	face:SetAttribute("Board", name)
	CollectionService:AddTag(face, "MaisonBoard")
	local lampPos = (cf * CFrame.new(0, height / 2 + 1.4, -1.4)).Position
	local lamp = Kit.part(model, "PictureLight", Vector3.new(width * 0.6, 0.3, 0.4), CFrame.lookAt(lampPos, lampPos + cf.LookVector), L.brass, { collide = false })
	Kit.spotLight(lamp, Enum.NormalId.Bottom, 1.6, 16, 80)
	return face
end

local function wallOfNames(m: Model)
	local face = board(m, "WallOfNames", F.wallOfNames, 12, 12)
	local lines: { { text: string, size: number, font: Font?, color: Color3? } } = {
		{ text = Kit.track(Voice.Foyer.wall), size = 0.07, font = Brand.Fonts.display },
		{ text = Voice.Foyer.foundingTerm, size = 0.05, font = Brand.Fonts.display, color = Brand.Colours.smoke },
	}
	for i = 1, 10 do
		table.insert(lines, { text = string.rep("·", 3) .. "  " .. Voice.roman(i) .. "  " .. string.rep("·", 3), size = 0.055, font = Brand.Fonts.display, color = Brand.Colours.deepGold })
	end
	Kit.engrave(face, Enum.NormalId.Front, lines, { ppu = 40, brightness = 1.2 })
	-- Livre d'Or on its lectern
	local cf = F.livreDOr
	local model = Kit.model(m, "LivreDOr")
	Kit.part(model, "Stand", Vector3.new(1.2, 3.4, 0.8), cf * CFrame.new(0, 1.7, 0), L.walnut)
	Kit.part(model, "Top", Vector3.new(2.2, 0.2, 1.5), cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(16), 0, 0), L.walnut)
	local book = Kit.part(model, "Book", Vector3.new(1.7, 0.3, 1.2), cf * CFrame.new(0, 3.75, 0) * CFrame.Angles(math.rad(16), 0, 0), L.leather)
	Kit.part(model, "Gilt", Vector3.new(1.72, 0.08, 1.22), cf * CFrame.new(0, 3.72, 0) * CFrame.Angles(math.rad(16), 0, 0), L.brass, { collide = false })
	Kit.engrave(book, Enum.NormalId.Top, { { text = Voice.Foyer.livre, size = 0.4, font = Brand.Fonts.display } }, { ppu = 80 })
end

local function stair(m: Model)
	local model = Kit.model(m, "GrandStair")
	local st = F.stair
	local steps = st.topY
	local depth = (st.toZ - st.fromZ) / steps
	for i = 1, steps do
		local z0 = st.fromZ + (i - 1) * depth
		Kit.span(model, "Step", Vector3.new(st.x - 5, FLOOR, z0), Vector3.new(st.x + 5, FLOOR + i, z0 + depth), L.blackMarble)
		Kit.span(model, "Nosing", Vector3.new(st.x - 5, FLOOR + i - 0.1, z0 - 0.05), Vector3.new(st.x + 5, FLOOR + i + 0.02, z0 + 0.2), L.brass, { collide = false, query = false })
		Kit.span(model, "StairRunner", Vector3.new(st.x - 3, FLOOR + i, z0), Vector3.new(st.x + 3, FLOOR + i + 0.05, z0 + depth), L.carpet, { collide = false, query = false })
	end
	Kit.span(model, "Landing", Vector3.new(st.x - 5, FLOOR, st.toZ), Vector3.new(st.x + 5, FLOOR + steps, F.maxZ), L.blackMarble)
	-- Balustrades: a brass rail on posts following the slope
	for _, x in { st.x - 5, st.x + 5 } do
		for i = 0, steps, 2 do
			local z = st.fromZ + i * depth
			Kit.post(model, "Baluster", 3.2, 0.2, Vector3.new(x, FLOOR + i, z), L.brass)
		end
		local a = Vector3.new(x, FLOOR + 3.2, st.fromZ)
		local b = Vector3.new(x, FLOOR + steps + 3.2, st.toZ)
		Kit.part(model, "Handrail", Vector3.new(0.3, 0.3, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), L.brass)
	end
	-- The landing opens onto the Club Floor: a brass-framed arch, no door.
	local archPos = Vector3.new(st.x, FLOOR + steps + 5, F.maxZ + 1)
	Kit.part(model, "ArchL", Vector3.new(0.6, 10.6, 2.4), CFrame.new(archPos + Vector3.new(-4.3, 0.3, 0)), L.brass)
	Kit.part(model, "ArchR", Vector3.new(0.6, 10.6, 2.4), CFrame.new(archPos + Vector3.new(4.3, 0.3, 0)), L.brass)
	Kit.part(model, "ArchHead", Vector3.new(9.2, 0.8, 2.4), CFrame.new(archPos + Vector3.new(0, 5.4, 0)), L.brass)
	local nameplate = Kit.part(model, "ArchName", Vector3.new(8, 1.2, 0.1), CFrame.new(archPos + Vector3.new(0, 6.6, -1.25)), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
	Kit.engrave(nameplate, Enum.NormalId.Front, { { text = Kit.track(Voice.Foyer.stair), size = 0.7, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 60, lit = false })
	-- A brass sign at the foot of the stair
	local signPos = Vector3.new(st.x - 6.4, FLOOR, st.fromZ - 1.5)
	Kit.post(model, "SignPost", 3, 0.2, signPos, L.brass, { collide = false })
	local sign = Kit.part(model, "StairSign", Vector3.new(2.6, 1.3, 0.1), CFrame.new(signPos + Vector3.new(0, 3.4, 0)), L.brass, { collide = false })
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = Kit.track(Voice.Foyer.stair), size = 0.34, font = Brand.Fonts.display, color = Color3.fromRGB(40, 30, 12) },
		{ text = "The Library", size = 0.26, font = Brand.Fonts.body, color = Color3.fromRGB(50, 38, 14) },
	}, { ppu = 80, brightness = 1 })
end

local function roomDoor(m: Model, roomId: string)
	local spec = Layout.RoomDoors[roomId]
	local room = Rooms.get(roomId)
	local model = Kit.model(m, "Door_" .. roomId)
	Kit.persist(model)
	model:SetAttribute("Room", roomId)
	model:SetAttribute("Open", spec.open)
	CollectionService:AddTag(model, "RoomDoor")
	local w, h = Layout.RoomDoorWidth, Layout.RoomDoorHeight
	local facing = spec.facing
	local centre = spec.centre
	local base = CFrame.lookAt(centre, centre + facing) -- LookVector points into the Foyer
	-- Brass architrave
	Kit.part(model, "JambL", Vector3.new(0.6, h + 0.6, 2.4), base * CFrame.new(-w / 2 - 0.3, h / 2 + 0.3, 0), L.brass)
	Kit.part(model, "JambR", Vector3.new(0.6, h + 0.6, 2.4), base * CFrame.new(w / 2 + 0.3, h / 2 + 0.3, 0), L.brass)
	Kit.part(model, "Head", Vector3.new(w + 1.8, 0.8, 2.4), base * CFrame.new(0, h + 0.4, 0), L.brass)
	-- Door leaves (visual; clients swing open the ones that open)
	for side = -1, 1, 2 do
		local hinge = base * CFrame.new(side * w / 2, 0, 0)
		local leaf = Kit.part(model, if side < 0 then "LeafL" else "LeafR", Vector3.new(w / 2 - 0.1, h - 0.1, 0.3), hinge * CFrame.new(-side * (w / 4), h / 2, 0), L.blackLacquer)
		leaf:SetAttribute("Side", side)
		leaf:SetAttribute("Hinge", hinge)
		Kit.part(model, "Panel", Vector3.new(w / 2 - 1.2, h - 2, 0.05), leaf.CFrame * CFrame.new(0, 0, -0.18), L.panel, { collide = false, query = false }).Name = "Inset"
		if spec.open then
			leaf.CanCollide = false
		end
		if spec.gated then
			leaf:SetAttribute("Gated", true)
		end
	end
	-- The room's name, in serif, above the door (the client fades it in as you approach).
	-- A part's Front face is its LookVector, which here faces into the Foyer.
	local namePlate = Kit.part(model, "NamePlate", Vector3.new(w, 1.4, 0.1), base * CFrame.new(0, h + 1.6, -1.25), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
	local roomName = if room then room.name else roomId
	Kit.engrave(namePlate, Enum.NormalId.Front, { { text = roomName, size = 0.8, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 60, lit = false, brightness = 1.2 })
	CollectionService:AddTag(namePlate, "RoomName")
	-- The Midnight Room is roped until earned.
	if roomId == "midnight" then
		local p = { -w / 2 + 0.6, w / 2 - 0.6 }
		for _, x in p do
			local pos = (base * CFrame.new(x, 0, -2.2)).Position
			Kit.post(model, "Stanchion", 3.2, 0.3, pos, L.brass)
			Kit.ball(model, "StanchionTop", 0.5, pos + Vector3.new(0, 3.3, 0), L.brass)
		end
		local a = (base * CFrame.new(p[1], 3, -2.2)).Position
		local b = (base * CFrame.new(p[2], 3, -2.2)).Position
		Kit.part(model, "Rope", Vector3.new(0.25, 0.25, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), L.rope)
	end
	-- Closed rooms: a wall behind the leaves so the doorway never shows the void.
	if not spec.open and not spec.gated then
		Kit.part(model, "Backing", Vector3.new(w, h, 0.4), base * CFrame.new(0, h / 2, 1.1), L.wall)
	end
end

local function boutiqueDoor(m: Model)
	local model = Kit.model(m, "BoutiqueDoor")
	local cf = F.boutiqueDoor
	-- Open glass doors in a brass frame: the Boutique is a room you walk into.
	Kit.part(model, "FrameL", Vector3.new(0.4, 10.4, 1.2), cf * CFrame.new(-4.2, 5.2, 0.6), L.brass)
	Kit.part(model, "FrameR", Vector3.new(0.4, 10.4, 1.2), cf * CFrame.new(4.2, 5.2, 0.6), L.brass)
	Kit.part(model, "FrameTop", Vector3.new(8.8, 0.5, 1.2), cf * CFrame.new(0, 10.25, 0.6), L.brass)
	for _, side in { -1, 1 } do
		-- Each leaf swung back against the wall inside.
		local hinge = cf * CFrame.new(side * 4, 0, 1.2)
		Kit.part(model, "Leaf", Vector3.new(0.15, 9.6, 3.8), hinge * CFrame.new(-side * 0.2, 4.8, 1.9), { color = Color3.fromRGB(60, 50, 40), material = Enum.Material.Glass, reflectance = 0.35, transparency = 0.45 }, { collide = false })
		Kit.part(model, "LeafFrame", Vector3.new(0.2, 9.8, 0.2), hinge * CFrame.new(-side * 0.2, 4.9, 3.8), L.brass, { collide = false })
	end
	local sign = Kit.part(model, "Sign", Vector3.new(6, 1.2, 0.1), cf * CFrame.new(0, 11.6, -0.3), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
	Kit.engrave(sign, Enum.NormalId.Front, { { text = Kit.track(Voice.Foyer.boutique), size = 0.7, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 60, lit = false })
end

local function entranceDoors(m: Model)
	-- The front doors, opened by the Doorman (clients swing them locally).
	local model = Kit.model(m, "FrontDoors")
	Kit.persist(model)
	CollectionService:AddTag(model, "FrontDoors")
	local d = Layout.Door
	local z = Layout.Street.facadeZ + 1
	for side = -1, 1, 2 do
		local hinge = CFrame.lookAt(Vector3.new(side * d.width / 2, FLOOR, z), Vector3.new(side * d.width / 2, FLOOR, z - 10))
		local leaf = Kit.part(model, if side < 0 then "LeafL" else "LeafR", Vector3.new(d.width / 2 - 0.1, d.height - 0.1, 0.35), hinge * CFrame.new(-side * d.width / 4, d.height / 2, 0), L.blackLacquer, { collide = false })
		leaf:SetAttribute("Side", side)
		leaf:SetAttribute("Hinge", hinge)
		Kit.part(model, "Knob", Vector3.new(0.3, 0.3, 0.3), leaf.CFrame * CFrame.new(side * (d.width / 4 - 0.6), -0.5, -0.3), L.brass, { collide = false, shape = Enum.PartType.Ball }).Name = "Knob"
	end
end

function Foyer.build(parent: Instance): Model
	local root = Kit.model(parent, "Foyer")
	floorTiles(root)
	shell(root)
	for _, x in { -22, 22 } do
		for _, z in { 8, 28 } do
			column(root, x, z)
		end
	end
	for _, z in { -2, 16, 25 } do
		sconce(root, Vector3.new(F.minX + 0.3, FLOOR + 9, z), Vector3.new(1, 0, 0))
		sconce(root, Vector3.new(F.maxX - 0.3, FLOOR + 9, z), Vector3.new(-1, 0, 0))
	end
	for _, x in { -26, 26 } do
		sconce(root, Vector3.new(x, FLOOR + 9, F.maxZ - 0.3), Vector3.new(0, 0, -1))
	end
	chandelier(root)
	piano(root)
	lectern(root)
	local tonight = board(root, "TonightBoard", F.tonightBoard, 9, 11)
	tonight:SetAttribute("Kind", "tonight")
	wallOfNames(root)
	stair(root)
	for _, id in Rooms.order do
		roomDoor(root, id)
	end
	boutiqueDoor(root)
	entranceDoors(root)
	-- A soft fill so the marble never goes pitch black.
	local fill = Kit.part(root, "FillLight", Vector3.new(1, 1, 1), CFrame.new(0, FLOOR + 14, 16), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
	Kit.pointLight(fill, 0.5, 60, Color3.fromRGB(200, 170, 140))

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "FoyerSpawn"
	spawn.Anchored = true
	spawn.Enabled = false -- the server places guests itself; this marks the spot
	spawn.Size = Vector3.new(4, 0.2, 4)
	spawn.CFrame = CFrame.new(F.spawn.Position.X, FLOOR + 0.1, F.spawn.Position.Z) * F.spawn.Rotation
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Duration = 0
	spawn.Parent = root
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	return root
end

return Foyer

--!strict
-- The Ballroom (§9.3): a tall black-and-gold hall through the Club hall's right-hand door.
-- Twenty tables in a ring around a marble floor, each under its own lamp on a long cord, each
-- with a brass dumbwaiter beside it; a chandelier over the middle; the Gallery above the
-- entrance for watching, reached by a stair along the west wall; and the evening's board.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Layout = require(ReplicatedStorage.Shared.Layout).raw -- (the house as drawn: see World/Grand)
local Kit = require(script.Parent.Kit)
local SortingTable = require(script.Parent.SortingTable)

local L = Kit.Looks
local B = Layout.Ballroom
local C = Layout.Club
local Y = Layout.CLUB
local T = Layout.Table

local Ballroom = {}

local INVISIBLE = { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }
local PARQUET = { color = Color3.fromRGB(58, 36, 22), material = Enum.Material.WoodPlanks, reflectance = 0.06 }
local MIRROR = { color = Color3.fromRGB(60, 64, 72), material = Enum.Material.Glass, reflectance = 0.45, transparency = 0.05 }
local DRAPE = { color = Color3.fromRGB(56, 12, 22), material = Enum.Material.Fabric }

local function shell(m: Model)
	local top = Y + B.height
	-- Floor: parquet, with a round marble inlay ringed in brass in the middle.
	Kit.span(m, "Floor", Vector3.new(B.minX, Y - 1, B.minZ), Vector3.new(B.maxX, Y, B.maxZ), PARQUET)
	Kit.cylinder(m, "Inlay", 0.06, 56, CFrame.new(B.centre + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.boneMarble, { collide = false, query = false, shadow = false })
	Kit.cylinder(m, "InlayRing", 0.05, 57.4, CFrame.new(B.centre + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false, query = false, shadow = false })
	Kit.cylinder(m, "InlayStar", 0.07, 10, CFrame.new(B.centre + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.blackMarble, { collide = false, query = false, shadow = false })
	-- A compass rose in brass across the marble: eight long rays and eight short, a diamond at
	-- each long ray's tip.
	for i = 0, 15 do
		local long = i % 2 == 0
		local len = if long then 21 else 11
		local a = math.rad(i * 22.5)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = B.centre + dir * (5 + len / 2) + Vector3.new(0, 0.08, 0)
		Kit.part(m, "CompassRay", Vector3.new(if long then 0.5 else 0.3, 0.02, len), CFrame.lookAt(mid, mid + dir), L.brass, { collide = false, query = false, shadow = false })
		if long then
			local tip = B.centre + dir * 27 + Vector3.new(0, 0.08, 0)
			Kit.part(m, "CompassDiamond", Vector3.new(1.2, 0.02, 1.2), CFrame.new(tip) * CFrame.Angles(0, a + math.rad(45), 0), L.brass, { collide = false, query = false, shadow = false })
		end
	end
	Kit.span(m, "Ceiling", Vector3.new(B.minX - 2, top, B.minZ - 2), Vector3.new(B.maxX + 2, top + 1, B.maxZ + 2), L.blackLacquer)
	-- Walls. The west wall is shared with the Library below the Library's ceiling.
	local libraryTop = Y + Layout.Library.height
	Kit.span(m, "WallW_High", Vector3.new(B.minX - 2, libraryTop, B.minZ - 2), Vector3.new(B.minX, top, Layout.Library.maxZ + 2), L.blackLacquer)
	Kit.span(m, "WallW", Vector3.new(B.minX - 2, Y, Layout.Library.maxZ + 2), Vector3.new(B.minX, top, B.maxZ + 2), L.blackLacquer)
	Kit.span(m, "WallE", Vector3.new(B.maxX, Y, B.minZ - 2), Vector3.new(B.maxX + 2, top, B.maxZ + 2), L.blackLacquer)
	Kit.span(m, "WallN", Vector3.new(B.minX - 2, Y, B.maxZ), Vector3.new(B.maxX + 2, top, B.maxZ + 2), L.blackLacquer)
	-- The south wall: the Club hall's wall carries the door; this closes everything around it.
	local hallTop = Y + C.height
	Kit.span(m, "WallS_High", Vector3.new(B.minX - 2, hallTop, B.minZ - 2), Vector3.new(C.maxX + 2, top, B.minZ), L.blackLacquer)
	Kit.span(m, "WallS_E", Vector3.new(C.maxX + 2, Y, B.minZ - 2), Vector3.new(B.maxX + 2, top, B.minZ), L.blackLacquer)
	-- Inside faces: lacquer panels between gold pilasters.
	Kit.span(m, "FacingW", Vector3.new(B.minX, Y, B.minZ), Vector3.new(B.minX + 0.2, top, B.maxZ), L.blackLacquer, { collide = false, query = false })
	local x = B.minX + 8
	while x < B.maxX - 4 do
		Kit.span(m, "PilasterN", Vector3.new(x - 0.5, Y, B.maxZ - 0.6), Vector3.new(x + 0.5, top - 1, B.maxZ), L.brass, { collide = false, query = false })
		x += 12
	end
	local z = B.minZ + 16
	while z < B.maxZ - 4 do
		for _, side in { -1, 1 } do
			local px = if side < 0 then B.minX + 0.2 else B.maxX - 0.6
			Kit.span(m, "Pilaster", Vector3.new(px, Y, z - 0.5), Vector3.new(px + 0.4, top - 1, z + 0.5), L.brass, { collide = false, query = false })
		end
		z += 12
	end
	-- Mirrors along the north wall, between the pilasters; drapes on the east wall.
	x = B.minX + 14
	while x < B.maxX - 8 do
		Kit.span(m, "Mirror", Vector3.new(x - 4.5, Y + 3, B.maxZ - 0.4), Vector3.new(x + 4.5, Y + 20, B.maxZ - 0.2), MIRROR, { collide = false, query = false })
		x += 12
	end
	z = B.minZ + 22
	while z < B.maxZ - 8 do
		Kit.span(m, "Drape", Vector3.new(B.maxX - 1.4, Y, z - 4.4), Vector3.new(B.maxX - 0.7, top - 2, z + 4.4), DRAPE, { collide = false, query = false })
		z += 12
	end
	-- A gold cornice all round.
	Kit.span(m, "CorniceN", Vector3.new(B.minX, top - 1.2, B.maxZ - 0.8), Vector3.new(B.maxX, top - 0.6, B.maxZ), L.brass, { collide = false, query = false, shadow = false })
	Kit.span(m, "CorniceE", Vector3.new(B.maxX - 0.8, top - 1.2, B.minZ), Vector3.new(B.maxX, top - 0.6, B.maxZ), L.brass, { collide = false, query = false, shadow = false })
	Kit.span(m, "CorniceW", Vector3.new(B.minX, top - 1.2, B.minZ), Vector3.new(B.minX + 0.8, top - 0.6, B.maxZ), L.brass, { collide = false, query = false, shadow = false })
end

-- Marble statues on plinths and tall palms in the far corners.
local function corners(m: Model)
	for _, at in { Vector3.new(B.minX + 6, Y, B.maxZ - 6), Vector3.new(B.maxX - 6, Y, B.maxZ - 6), Vector3.new(B.maxX - 6, Y, B.minZ + 14) } do
		Furniture.build("statue", m, CFrame.lookAt(at, B.centre * Vector3.new(1, 0, 1) + Vector3.new(0, Y, 0)), { colour = Color3.fromRGB(236, 230, 218) })
		local side = (B.centre - at).Unit
		Furniture.build("plant", m, CFrame.new(at + Vector3.new(side.Z, 0, -side.X) * 4.5), { model = "palm" })
	end
end

local function gallery(m: Model)
	local G = B.gallery
	local S = B.stair
	local floorY = G.floorY
	-- The balcony, and a landing over the top of the stair.
	Kit.span(m, "GalleryFloor", Vector3.new(G.minX, floorY - 1, G.minZ), Vector3.new(G.maxX, floorY, G.maxZ), PARQUET)
	Kit.span(m, "GalleryLanding", Vector3.new(G.minX, floorY - 1, G.maxZ), Vector3.new(S.x1 + 1, floorY, S.topZ + 2), PARQUET)
	Kit.span(m, "GalleryFascia", Vector3.new(S.x1 + 1, floorY - 2.4, G.maxZ - 0.3), Vector3.new(G.maxX, floorY - 1, G.maxZ), L.brass, { collide = false, query = false })
	Kit.span(m, "GalleryFasciaLow", Vector3.new(S.x1 + 1, floorY - 1, G.maxZ - 0.3), Vector3.new(G.maxX, floorY, G.maxZ), L.blackLacquer, { collide = false, query = false })
	-- Railing: brass top rail on black balusters.
	local railY = floorY + 3.2
	Kit.span(m, "GalleryRail", Vector3.new(S.x1 + 1, railY, G.maxZ - 0.35), Vector3.new(G.maxX, railY + 0.25, G.maxZ - 0.05), L.brass)
	Kit.span(m, "GalleryGuard", Vector3.new(S.x1 + 1, floorY, G.maxZ - 0.3), Vector3.new(G.maxX, railY, G.maxZ - 0.1), INVISIBLE)
	Kit.span(m, "Balustrade", Vector3.new(S.x1 + 1, floorY, G.maxZ - 0.28), Vector3.new(G.maxX, railY, G.maxZ - 0.12), L.smokedGlass, { collide = false, query = false, shadow = false })
	-- Benches for watchers.
	local x = 20
	while x < G.maxX - 6 do
		Kit.part(m, "GalleryBench", Vector3.new(5, 0.6, 1.4), CFrame.new(x, floorY + 1.2, G.minZ + 1.6), L.leather)
		Kit.part(m, "GalleryBenchBase", Vector3.new(4.6, 0.9, 1.1), CFrame.new(x, floorY + 0.45, G.minZ + 1.6), L.blackLacquer)
		local top = Vector3.new(x, floorY + 1.5, G.minZ + 1.6)
		Furniture.seatsOn(m, "GallerySeats", {
			CFrame.lookAt(top + Vector3.new(-1.2, 0, 0), top + Vector3.new(-1.2, 0, 1)),
			CFrame.lookAt(top + Vector3.new(1.2, 0, 0), top + Vector3.new(1.2, 0, 1)),
		}, "The gallery bench", 1.6)
		x += 12
	end
	-- The stair along the west wall, climbing south to the landing.
	for k = 1, S.steps do
		local zTop = S.bottomZ - (k - 1) * 2
		Kit.span(m, "Step", Vector3.new(S.x0, Y, zTop - 2), Vector3.new(S.x1, Y + k, zTop), L.blackMarble)
	end
	Kit.span(m, "StairRail", Vector3.new(S.x1, Y + 3, S.topZ), Vector3.new(S.x1 + 0.2, floorY + 3.2, S.bottomZ), L.brass, { collide = false, query = false })
	Kit.span(m, "StairGuard", Vector3.new(S.x1, Y, S.topZ), Vector3.new(S.x1 + 0.2, floorY + 3.2, S.bottomZ - 4), INVISIBLE)
	-- Sconces under the Gallery light the entrance.
	for _, sx in { 20, 42, 64, 86, 108 } do
		local sconce = Kit.part(m, "GallerySconce", Vector3.new(0.6, 0.8, 0.3), CFrame.new(sx, floorY - 3.4, G.maxZ + 0.1), L.brass, { collide = false })
		local light = Kit.pointLight(sconce, 0.5, 14, Color3.fromRGB(255, 206, 150))
		light:SetAttribute("BallroomAmbient", 0.5)
	end
end

-- The evening's board, on the Gallery's fascia above the entrance: what's happening now.
local function board(m: Model)
	local part = Kit.part(m, "EveningBoard", Vector3.new(16, 3.6, 0.2), B.board, L.blackLacquer, { collide = false, query = false })
	Kit.part(m, "EveningBoardFrame", Vector3.new(16.6, 4.2, 0.1), B.board * CFrame.new(0, 0, 0.12), L.brass, { collide = false, query = false })
	Kit.engrave(part, Enum.NormalId.Front, {
		{ text = "LIGHTS OUT", size = 0.9, font = Brand.Fonts.display, color = Brand.Colours.lightGold },
		{ text = "Take any chair. The evening begins when a guest sits.", size = 0.55, font = Brand.Fonts.body, color = Brand.Colours.bone },
	}, { ppu = 50, lit = false })
	part:SetAttribute("EveningBoard", true)
end

local function chandelier(m: Model)
	local top = Y + B.height
	local c = B.centre + Vector3.new(0, B.height - 7, 0)
	Kit.cylinder(m, "ChandelierChain", 5, 0.3, CFrame.new(c + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false })
	for tier, spec in { { r = 5, n = 16, y = 0 }, { r = 3.2, n = 10, y = 1.4 }, { r = 1.6, n = 6, y = 2.6 } } do
		Kit.cylinder(m, "ChandelierHoop" .. tier, 0.2, spec.r * 2 + 0.3, CFrame.new(c + Vector3.new(0, spec.y - 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false, shadow = false, query = false })
		for i = 1, spec.n do
			local a = i / spec.n * math.pi * 2
			local p = c + Vector3.new(math.cos(a) * spec.r, spec.y, math.sin(a) * spec.r)
			Kit.post(m, "Candle", 0.7, 0.2, p, L.bone, { collide = false, shadow = false, query = false })
			Kit.part(m, "Flame", Vector3.new(0.16, 0.3, 0.16), CFrame.new(p + Vector3.new(0, 0.85, 0)), { color = Color3.fromRGB(255, 210, 140), material = Enum.Material.Neon }, { collide = false, shadow = false, query = false })
		end
	end
	for i = 1, 24 do
		local a = i / 24 * math.pi * 2
		local p = c + Vector3.new(math.cos(a) * 4.2, -1.2 - (i % 3) * 0.5, math.sin(a) * 4.2)
		Kit.part(m, "Crystal", Vector3.new(0.18, 0.5, 0.18), CFrame.new(p), { color = Color3.fromRGB(230, 236, 245), material = Enum.Material.Glass, transparency = 0.3, reflectance = 0.4 }, { collide = false, shadow = false, query = false })
	end
	local glow = Kit.part(m, "ChandelierGlow", Vector3.new(0.3, 0.3, 0.3), CFrame.new(c), INVISIBLE, { collide = false, query = false, shadow = false })
	local light = Kit.pointLight(glow, 1.3, 60, Color3.fromRGB(255, 205, 140), false)
	light:SetAttribute("BallroomAmbient", 1.3)
	-- A soft fill so the far walls read.
	for _, offset in { Vector3.new(-40, 0, 0), Vector3.new(40, 0, 0), Vector3.new(0, 0, 40), Vector3.new(0, 0, -34) } do
		local p = Vector3.new(B.centre.X, top - 6, B.centre.Z) + offset
		local fill = Kit.part(m, "FillLight", Vector3.new(1, 1, 1), CFrame.new(p), INVISIBLE, { collide = false, query = false, shadow = false })
		local l = Kit.pointLight(fill, 0.35, 44, Color3.fromRGB(210, 180, 140))
		l:SetAttribute("BallroomAmbient", 0.35)
	end
end

local function tables(m: Model)
	local folder = Kit.folder(m, "Tables")
	local style: SortingTable.Style = {
		roomName = "The Ballroom",
		top = L.blackLacquer,
		legs = L.brass,
		felt = { color = Color3.fromRGB(20, 14, 16), material = Enum.Material.Fabric },
		caseBase = { color = Color3.fromRGB(24, 14, 18), material = Enum.Material.Fabric },
		caseRim = L.brass,
		chair = L.burgundyVelvet,
		lamp = "cord",
		lampColor = Color3.fromRGB(255, 214, 160),
		lampBrightness = 1.8,
		ceiling = Y + B.height,
	}
	local count = 20
	for i = 1, count do
		local frame = Layout.ballroomFrame(i, count)
		local model = SortingTable.build(folder, "ballroom", tostring(i), frame, style)
		model:SetAttribute("Ballroom", true)
		model:SetAttribute("Seat", i)
		CollectionService:AddTag(model, "BallroomTable")
		local seat = model:FindFirstChild("Chair")
		local nightly = seat and seat:FindFirstChild("NightlyPrompt")
		if nightly then
			nightly:Destroy() -- the Nightly is played in the four rooms
		end
		-- The dumbwaiter: a brass shaft beyond the cases, toward the middle of the room, that
		-- sends the pieces up and across the felt.
		local shaftAt = frame * CFrame.new(-T.width / 2 + 1.2, 0, T.depth / 2 + 1.0)
		Kit.part(model, "Dumbwaiter", Vector3.new(1.4, T.topY + 0.9, 1.4), shaftAt * CFrame.new(0, (T.topY + 0.9) / 2, 0), L.brass)
		Kit.part(model, "DumbwaiterHatch", Vector3.new(1.1, 0.08, 1.1), shaftAt * CFrame.new(0, T.topY + 0.92, 0), L.blackLacquer, { collide = false, shadow = false })
		model:SetAttribute("Dumbwaiter", (shaftAt * CFrame.new(0, T.topY + 1.2, 0)).Position)
		-- The table's number, engraved on the shaft facing the room.
		local plate = Kit.part(model, "NumberPlate", Vector3.new(1.1, 0.7, 0.05), shaftAt * CFrame.new(0, T.topY - 0.6, 0.73) * CFrame.Angles(0, math.pi, 0), INVISIBLE, { collide = false, query = false, shadow = false })
		Kit.engrave(plate, Enum.NormalId.Front, { { text = tostring(i), size = 0.5, font = Brand.Fonts.display, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 80, lit = false })
	end
end

function Ballroom.build(parent: Instance): Model
	local m = Kit.model(parent, "Ballroom")
	shell(m)
	gallery(m)
	corners(m)
	board(m)
	chandelier(m)
	tables(m)
	return m
end

return Ballroom

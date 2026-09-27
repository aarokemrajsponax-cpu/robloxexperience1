--!strict
-- The Salon: burgundy velvet, low brass lamps, bookshelves, a fire. Six sorting tables.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local S = Layout.Salon
local T = Layout.Table
local FLOOR = Layout.FLOOR
local TOP = FLOOR + S.height

local Salon = {}

local function shell(m: Model)
	-- Floor: dark planks, with a large rug under the tables
	Kit.span(m, "Floor", Vector3.new(S.minX, FLOOR - 1, S.minZ), Vector3.new(S.maxX, FLOOR, S.maxZ), { color = Color3.fromRGB(44, 28, 20), material = Enum.Material.WoodPlanks })
	Kit.span(m, "Rug", Vector3.new(S.minX + 4, FLOOR, S.minZ + 3), Vector3.new(S.maxX - 3, FLOOR + 0.05, S.maxZ - 5), L.carpet, { collide = false, query = false })
	Kit.span(m, "RugBorder", Vector3.new(S.minX + 3.6, FLOOR, S.minZ + 2.6), Vector3.new(S.maxX - 2.6, FLOOR + 0.04, S.maxZ - 4.6), L.darkBrass, { collide = false, query = false })
	-- Walls
	Kit.span(m, "WallWest", Vector3.new(S.minX - 2, FLOOR, S.minZ - 2), Vector3.new(S.minX, TOP, S.maxZ + 2), L.deepVelvet)
	Kit.span(m, "WallSouth", Vector3.new(S.minX - 2, FLOOR, S.minZ - 2), Vector3.new(S.maxX, TOP, S.minZ), L.deepVelvet)
	Kit.span(m, "WallNorth", Vector3.new(S.minX - 2, FLOOR, S.maxZ), Vector3.new(S.maxX, TOP, S.maxZ + 2), L.deepVelvet)
	Kit.span(m, "Ceiling", Vector3.new(S.minX - 2, TOP, S.minZ - 2), Vector3.new(S.maxX, TOP + 1, S.maxZ + 2), { color = Color3.fromRGB(30, 14, 16), material = Enum.Material.SmoothPlastic })
	-- Velvet facing on the Foyer side wall, around the doorway
	local d = Layout.RoomDoors.salon.centre
	local dw = Layout.RoomDoorWidth / 2
	Kit.span(m, "FacingA", Vector3.new(S.maxX - 0.2, FLOOR, S.minZ), Vector3.new(S.maxX, TOP, d.Z - dw), L.burgundyVelvet, { collide = false, query = false })
	Kit.span(m, "FacingB", Vector3.new(S.maxX - 0.2, FLOOR, d.Z + dw), Vector3.new(S.maxX, TOP, S.maxZ), L.burgundyVelvet, { collide = false, query = false })
	Kit.span(m, "FacingC", Vector3.new(S.maxX - 0.2, FLOOR + Layout.RoomDoorHeight, d.Z - dw), Vector3.new(S.maxX, TOP, d.Z + dw), L.burgundyVelvet, { collide = false, query = false })
	-- Wainscot and picture rail on the three inner walls
	local wain = FLOOR + 3.8
	for _, spec in {
		{ Vector3.new(S.minX, FLOOR, S.minZ), Vector3.new(S.minX + 0.4, wain, S.maxZ) },
		{ Vector3.new(S.minX, FLOOR, S.minZ), Vector3.new(S.maxX, wain, S.minZ + 0.4) },
		{ Vector3.new(S.minX, FLOOR, S.maxZ - 0.4), Vector3.new(S.maxX, wain, S.maxZ) },
	} do
		Kit.span(m, "Wainscot", spec[1], spec[2], L.walnut, { collide = false, query = false })
	end
	for _, spec in {
		{ Vector3.new(S.minX, wain, S.minZ), Vector3.new(S.minX + 0.45, wain + 0.18, S.maxZ) },
		{ Vector3.new(S.minX, wain, S.minZ), Vector3.new(S.maxX, wain + 0.18, S.minZ + 0.45) },
		{ Vector3.new(S.minX, wain, S.maxZ - 0.45), Vector3.new(S.maxX, wain + 0.18, S.maxZ) },
		{ Vector3.new(S.minX, TOP - 2.5, S.maxZ - 0.45), Vector3.new(S.maxX, TOP - 2.3, S.maxZ) },
		{ Vector3.new(S.minX, TOP - 2.5, S.minZ), Vector3.new(S.maxX, TOP - 2.3, S.minZ + 0.45) },
	} do
		Kit.span(m, "Rail", spec[1], spec[2], L.brass, { collide = false, query = false, shadow = false })
	end
end

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

local function casePlate(parent: Model, index: number, caseId: string, centre: Vector3)
	local case = Catalogue.caseById[caseId]
	local c = Layout.caseCentre(centre, index)
	local pos = c + Vector3.new(0, 0.06, -T.caseDepth / 2 - 0.28)
	-- Tilted so its face points up at the seated guest's camera, text upright.
	local toward = Vector3.new(0, 0.9, -0.42).Unit
	local plate = Kit.part(parent, "CasePlate" .. index, Vector3.new(T.caseWidth - 0.16, 0.42, 0.05), CFrame.lookAt(pos, pos + toward, Vector3.new(0, 0, 1)), L.brass, { collide = false, shadow = false })
	Kit.engrave(plate, Enum.NormalId.Front, {
		{ text = string.upper(case.name), size = 0.52, font = Brand.Fonts.display, color = Color3.fromRGB(34, 26, 10) },
		{ text = case.subtitle, size = 0.3, font = Brand.Fonts.body, color = Color3.fromRGB(56, 42, 16) },
	}, { ppu = 120, brightness = 1, maxDistance = 40 })
end

local function smokedCase(parent: Model, index: number, centre: Vector3)
	local caseId = Catalogue.Cases[index].id
	local c = Layout.caseCentre(centre, index)
	local w, d = T.caseWidth, T.caseDepth
	local h = 0.55
	local glass = Kit.Looks.smokedGlass
	local base = Kit.part(parent, "Case" .. index, Vector3.new(w, 0.12, d), CFrame.new(c + Vector3.new(0, 0.06, 0)), L.deepVelvet)
	base:SetAttribute("CaseId", caseId)
	base:SetAttribute("Index", index)
	CollectionService:AddTag(base, "MaisonCase")
	Kit.part(parent, "CaseWallN", Vector3.new(w, h, 0.06), CFrame.new(c + Vector3.new(0, h / 2, d / 2)), glass, { collide = false, shadow = false })
	Kit.part(parent, "CaseWallS", Vector3.new(w, h * 0.6, 0.06), CFrame.new(c + Vector3.new(0, h * 0.3, -d / 2)), glass, { collide = false, shadow = false })
	Kit.part(parent, "CaseWallW", Vector3.new(0.06, h, d), CFrame.new(c + Vector3.new(-w / 2, h / 2, 0)), glass, { collide = false, shadow = false })
	Kit.part(parent, "CaseWallE", Vector3.new(0.06, h, d), CFrame.new(c + Vector3.new(w / 2, h / 2, 0)), glass, { collide = false, shadow = false })
	-- Brass rim, gold only on the edges
	Kit.part(parent, "CaseRimN", Vector3.new(w + 0.06, 0.05, 0.08), CFrame.new(c + Vector3.new(0, h, d / 2)), L.brass, { collide = false, shadow = false })
	Kit.part(parent, "CaseRimW", Vector3.new(0.08, 0.05, d), CFrame.new(c + Vector3.new(-w / 2, h, 0)), L.brass, { collide = false, shadow = false })
	Kit.part(parent, "CaseRimE", Vector3.new(0.08, 0.05, d), CFrame.new(c + Vector3.new(w / 2, h, 0)), L.brass, { collide = false, shadow = false })
	-- The inner glow, lit once by the client when a piece is filed correctly
	local glow = Kit.part(parent, "CaseGlow" .. index, Vector3.new(w - 0.2, 0.04, d - 0.2), CFrame.new(c + Vector3.new(0, 0.14, 0)), { color = Brand.Colours.lightGold, material = Enum.Material.Neon, transparency = 1 }, { collide = false, shadow = false, query = false })
	local light = Instance.new("PointLight")
	light.Brightness = 0
	light.Range = 5
	light.Color = Brand.Colours.lightGold
	light.Parent = glow
	-- The lid, shown when this case is closed for the round
	local lid = Kit.part(parent, "CaseLid" .. index, Vector3.new(w, 0.06, d), CFrame.new(c + Vector3.new(0, h + 0.03, 0)), { color = Color3.fromRGB(20, 20, 24), material = Enum.Material.Glass, reflectance = 0.3, transparency = 1 }, { collide = false, shadow = false, query = false })
	lid:SetAttribute("CaseId", caseId)
	casePlate(parent, index, caseId, centre)
end

local function sortingTable(parent: Instance, index: number, centre: Vector3): Model
	local id = "salon-" .. index
	local model = Kit.model(parent, "SalonTable" .. index)
	Kit.persist(model)
	model:SetAttribute("TableId", id)
	model:SetAttribute("Room", "salon")
	model:SetAttribute("Centre", centre)
	model:SetAttribute("Score", 0)
	model:SetAttribute("Multiplier", 1)
	CollectionService:AddTag(model, "MaisonTable")

	local top = centre.Y + T.topY
	-- Legs and apron
	for _, o in { { -4.9, -3.1 }, { 4.9, -3.1 }, { -4.9, 3.1 }, { 4.9, 3.1 } } do
		Kit.part(model, "Leg", Vector3.new(0.5, T.topY - 0.3, 0.5), CFrame.new(centre + Vector3.new(o[1], (T.topY - 0.3) / 2, o[2])), L.darkWood)
	end
	Kit.part(model, "Apron", Vector3.new(T.width - 0.6, 0.6, T.depth - 0.6), CFrame.new(centre.X, top - 0.55, centre.Z), L.walnut)
	-- The top: walnut edge, brass inlay, felt field
	Kit.part(model, "Top", Vector3.new(T.width, 0.3, T.depth), CFrame.new(centre.X, top - 0.15, centre.Z), L.walnut)
	Kit.part(model, "Inlay", Vector3.new(T.width - 0.5, 0.02, T.depth - 0.5), CFrame.new(centre.X, top + 0.005, centre.Z), L.brass, { collide = false, shadow = false })
	local felt = Kit.part(model, "Felt", Vector3.new(T.width - 0.7, 0.03, T.depth - 0.7), CFrame.new(centre.X, top + 0.01, centre.Z), L.felt, { collide = false })
	felt:SetAttribute("Top", top + 0.025)

	for i = 1, #Catalogue.Cases do
		smokedCase(model, i, centre)
	end

	-- The brass counter, set into the near edge and angled up at the guest
	local counterPos = centre + Vector3.new(0, T.topY + 0.12, T.counterZ)
	local toward = Vector3.new(0, 0.9, -0.42).Unit
	local counter = Kit.part(model, "Counter", Vector3.new(3.4, 0.62, 0.08), CFrame.lookAt(counterPos, counterPos + toward, Vector3.new(0, 0, 1)), L.brass, { collide = false, shadow = false })
	counter.Material = Enum.Material.Metal
	local dialPos = counterPos + Vector3.new(2.2, 0, 0)
	local dial = Kit.part(model, "Dial", Vector3.new(0.08, 0.62, 0.62), CFrame.lookAt(dialPos, dialPos + toward, Vector3.new(0, 0, 1)) * CFrame.Angles(0, math.rad(90), 0), { color = Color3.fromRGB(236, 228, 210), material = Enum.Material.SmoothPlastic }, { collide = false, shadow = false, shape = Enum.PartType.Cylinder })
	dial.Name = "Dial"

	-- Chair: the guest faces +Z, toward the cases and the fire
	local seatPos = centre + Vector3.new(0, T.seatY, T.chairZ)
	local seat = Instance.new("Seat")
	seat.Name = "Chair"
	seat.Anchored = true
	seat.Size = Vector3.new(2.4, 0.5, 2.2)
	seat.CFrame = CFrame.lookAt(seatPos, seatPos + Vector3.new(0, 0, 1))
	seat.Color = L.leather.color
	seat.Material = L.leather.material
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.CanTouch = false -- nobody sits by walking into it; the prompt seats you
	seat.Parent = model
	Kit.part(model, "ChairBack", Vector3.new(2.4, 3, 0.4), CFrame.new(seatPos + Vector3.new(0, 1.6, -1.2)), L.leather, { collide = false })
	Kit.part(model, "ChairFrame", Vector3.new(2.6, 0.2, 2.4), CFrame.new(seatPos + Vector3.new(0, -0.3, 0)), L.darkWood, { collide = false })
	for _, o in { { -1.1, -1 }, { 1.1, -1 }, { -1.1, 1 }, { 1.1, 1 } } do
		Kit.part(model, "ChairLeg", Vector3.new(0.25, T.seatY - 0.3, 0.25), CFrame.new(centre + Vector3.new(o[1], (T.seatY - 0.3) / 2, T.chairZ + o[2])), L.darkWood, { collide = false })
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SitPrompt"
	prompt.ActionText = "Sit"
	prompt.ObjectText = "The Salon"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = seat

	-- The lamp above the table, which brightens when a round begins
	local lampPos = centre + Vector3.new(0, T.lampY, 0.2)
	Kit.cylinder(model, "Cord", TOP - lampPos.Y, 0.08, CFrame.new(lampPos.X, (TOP + lampPos.Y) / 2, lampPos.Z) * CFrame.Angles(0, 0, math.rad(90)), L.ink, { collide = false, shadow = false, query = false })
	local shade = Kit.part(model, "Lamp", Vector3.new(0.9, 3.4, 3.4), CFrame.new(lampPos) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false, shape = Enum.PartType.Cylinder, query = false })
	local bulb = Kit.part(model, "Bulb", Vector3.new(0.6, 0.3, 0.6), CFrame.new(lampPos - Vector3.new(0, 0.5, 0)), { color = Color3.fromRGB(255, 220, 160), material = Enum.Material.Neon }, { collide = false, shadow = false, query = false })
	local down = Kit.spotLight(bulb, Enum.NormalId.Bottom, 1.4, 16, 72, Color3.fromRGB(255, 214, 160))
	down.Name = "TableLight"
	shade.CastShadow = true
	return model
end

function Salon.build(parent: Instance): Model
	local root = Kit.model(parent, "Salon")
	shell(root)
	bookshelves(root)
	fireplace(root)
	for _, pos in { Vector3.new(S.minX + 4, FLOOR, S.minZ + 2.5), Vector3.new(S.maxX - 3, FLOOR, S.minZ + 2.5), Vector3.new(S.maxX - 3, FLOOR, S.maxZ - 3) } do
		floorLamp(root, pos)
	end
	local tables = Kit.folder(root, "Tables")
	for i, centre in S.tables do
		sortingTable(tables, i, centre)
	end
	-- A soft fill so velvet and felt never go fully black
	local fill = Kit.part(root, "FillLight", Vector3.new(1, 1, 1), CFrame.new(-56, FLOOR + 12, 11), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, { collide = false, query = false, shadow = false })
	Kit.pointLight(fill, 0.45, 40, Color3.fromRGB(220, 150, 120))
	return root
end

return Salon

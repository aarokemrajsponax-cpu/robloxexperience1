--!strict
-- The Grand Prix circuit, laid on the street in front of the house at the grown size (after the
-- Grand Scale): a stadium of smooth black road with white edges, red and white kerbs round the
-- hairpins, tyre walls on their outsides, a chequered line in front of the door under a gantry
-- with five start lights, grid boxes, and the bays along the kerb where the cars wait.
--
-- Nothing painted on the road collides (the street beneath is the road); the only solid things
-- are the walls, and they stop cars only (the "CarWalls" group: guests walk straight through).
-- The infield is walled for cars, so nobody takes a short cut across it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local GrandPrix = require(ReplicatedStorage.Shared.GrandPrix)
local Kit = require(script.Parent.Kit)

local Circuit = {}

local T = GrandPrix.TRACK
local C = Brand.Colours

local PAINT = { collide = false, query = false, shadow = false }
local LOOK = {
	road = { color = Color3.fromRGB(16, 16, 19), material = Enum.Material.SmoothPlastic, reflectance = 0.05 },
	line = { color = Color3.fromRGB(232, 228, 218), material = Enum.Material.SmoothPlastic },
	red = { color = Color3.fromRGB(176, 24, 32), material = Enum.Material.SmoothPlastic },
	white = { color = Color3.fromRGB(236, 234, 228), material = Enum.Material.SmoothPlastic },
	black = { color = Color3.fromRGB(12, 12, 14), material = Enum.Material.SmoothPlastic },
	tyre = { color = Color3.fromRGB(20, 20, 22), material = Enum.Material.Rubber },
	lawn = { color = Color3.fromRGB(18, 40, 26), material = Enum.Material.Grass },
	hedge = { color = Color3.fromRGB(16, 46, 28), material = Enum.Material.Grass },
	gold = { color = C.gold, material = Enum.Material.Metal, reflectance = 0.2 },
	lightOff = { color = Color3.fromRGB(40, 12, 12), material = Enum.Material.SmoothPlastic },
	bay = { color = Color3.fromRGB(200, 168, 96), material = Enum.Material.SmoothPlastic, transparency = 0.35 },
	wall = { color = Color3.new(0, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 1 },
}

local function flatAt(x: number, z: number, y: number?): Vector3
	return Vector3.new(x, y or T.y, z)
end

-- A solid stop for cars only (invisible).
local function carWall(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Kit.part(parent, name, size, cf, LOOK.wall, { query = false, shadow = false })
	p.CollisionGroup = "CarWalls"
	p:SetAttribute("CarWall", true)
	return p
end

-- One hairpin, drawn as `n` slices: road, kerbs inside and out, tyre walls and the car wall on
-- the outside. `east`: the hairpin past the east end of the straights.
local function hairpin(parent: Instance, east: boolean, n: number)
	local m = Kit.model(parent, if east then "HairpinEast" else "HairpinWest")
	local R, w = T.radius, T.width
	local cx = T.centre.X + (if east then T.half else -T.half)
	local cz = T.centre.Z
	local sliceArc = math.pi / n
	for i = 0, n - 1 do
		local th = (i + 0.5) * sliceArc
		-- (Angles measured as GrandPrix.point measures them: 0 at the near straight.)
		local sx, sz = math.sin(th), math.cos(th)
		local dirX = if east then 1 else -1
		local function at(r: number, y: number?): Vector3
			return flatAt(cx + dirX * r * sx, cz + (if east then 1 else -1) * r * sz, y)
		end
		local mid = at(R)
		-- The road's slice: as wide as the road, as long as the arc at its outer edge.
		local outerLen = (R + w / 2) * sliceArc + 0.6
		local face = CFrame.lookAt(mid, mid + Vector3.new(dirX * sx, 0, (if east then 1 else -1) * sz))
		-- (lookAt faces the slice outwards: its X runs along the bend, its Z across the road.)
		Kit.part(m, "Road", Vector3.new(outerLen, 0.06, w), face, LOOK.road, PAINT)
		-- Kerbs, red and white in turn.
		local kerb = if i % 2 == 0 then LOOK.red else LOOK.white
		for _, r in { R - w / 2 + 0.9, R + w / 2 - 0.9 } do
			local p = at(r, T.y + 0.05)
			local len = r * sliceArc + 0.15
			local cf = CFrame.lookAt(p, p + Vector3.new(dirX * sx, 0, (if east then 1 else -1) * sz))
			Kit.part(m, "Kerb", Vector3.new(len, 0.12, 1.8), cf, kerb, PAINT)
		end
		-- Tyres stacked round the outside, and the wall that stops a car (one wall to every two
		-- slices: the house keeps a budget of parts).
		local outer = at(R + w / 2 + 3)
		if i % 2 == 0 then
			Kit.cylinder(m, "Tyres", 2.4, 3.2, CFrame.new(outer + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), LOOK.tyre, { collide = false, query = false })
			local wth = (i + 1) * sliceArc
			local wx, wz = math.sin(wth), math.cos(wth)
			local wr = R + w / 2 + 3
			local wallAt = flatAt(cx + dirX * wr * wx, cz + (if east then 1 else -1) * wr * wz)
			local wallCf = CFrame.lookAt(wallAt, wallAt + Vector3.new(dirX * wx, 0, (if east then 1 else -1) * wz))
			carWall(m, "OuterWall", Vector3.new(2 * wr * math.tan(sliceArc) + 1.6, 8, 2), wallCf * CFrame.new(0, 4, 0))
		end
	end
	return m
end

function Circuit.build(parent: Instance): Model
	local root = Kit.model(parent, "GrandPrix")
	root:SetAttribute("Circuit", true)
	local R, w, h = T.radius, T.width, T.half
	local cx, cz = T.centre.X, T.centre.Z
	local nearZ, farZ = cz + R, cz - R

	-- The straights: road, white edges.
	local road = Kit.model(root, "Straights")
	for _, z in { nearZ, farZ } do
		Kit.part(road, "Road", Vector3.new(2 * h + 0.6, 0.06, w), CFrame.new(flatAt(cx, z)), LOOK.road, PAINT)
		for _, side in { -1, 1 } do
			Kit.part(road, "Edge", Vector3.new(2 * h, 0.08, 0.7), CFrame.new(flatAt(cx, z + side * (w / 2 - 0.6), T.y + 0.02)), LOOK.line, PAINT)
		end
	end

	hairpin(root, true, 16)
	hairpin(root, false, 16)

	-- The start line in front of the door: a chequered band, two squares deep.
	local line = Kit.model(root, "StartLine")
	local squares = 10
	local sq = w / squares
	for row = 0, 1 do
		for i = 0, squares - 1 do
			local look = if (i + row) % 2 == 0 then LOOK.white else LOOK.black
			Kit.part(line, "Check", Vector3.new(sq, 0.08, sq), CFrame.new(flatAt(cx - sq / 2 + row * sq, nearZ - w / 2 + sq * (i + 0.5), T.y + 0.03)), look, PAINT)
		end
	end
	-- The grid: a white box for each slot.
	for i = 1, #GrandPrix.CARS do
		local slot = GrandPrix.gridSlot(i)
		local p = slot.Position
		Kit.part(line, "GridMark", Vector3.new(0.5, 0.08, 7.5), CFrame.new(flatAt(p.X + 8, p.Z, T.y + 0.03)), LOOK.line, PAINT)
	end

	-- The gantry over the line: two gold-banded posts, the beam with its name, five lights.
	local gantry = Kit.model(root, "Gantry")
	local gx = cx
	local postL = flatAt(gx, nearZ + w / 2 + 2.5)
	local postR = flatAt(gx, nearZ - w / 2 - 2.5)
	for _, p in { postL, postR } do
		Kit.post(gantry, "Post", 17, 1.6, p, LOOK.black)
		Kit.post(gantry, "Band", 0.6, 1.8, p + Vector3.new(0, 15.6, 0), LOOK.gold)
	end
	local beamLen = (postL - postR).Magnitude + 2
	local beam = Kit.part(gantry, "Beam", Vector3.new(2.2, 3.4, beamLen), CFrame.new(flatAt(gx, nearZ, 17.6)), LOOK.black)
	-- The name, facing the cars coming up to the line (they come from the west).
	Kit.engrave(beam, Enum.NormalId.Left, {
		{ text = "MAISON NOIR GRAND PRIX", size = 0.62, font = Brand.Fonts.display, color = C.gold },
		{ text = "three laps · first home takes the purse", size = 0.26, font = Brand.Fonts.body, color = C.bone },
	}, { ppu = 24, maxDistance = 260, lit = false })
	Kit.engrave(beam, Enum.NormalId.Right, {
		{ text = "MAISON NOIR GRAND PRIX", size = 0.62, font = Brand.Fonts.display, color = C.gold },
		{ text = "get in a car, press Race", size = 0.26, font = Brand.Fonts.body, color = C.bone },
	}, { ppu = 24, maxDistance = 260, lit = false })
	local lights = Kit.model(gantry, "Lights")
	for i = 1, 5 do
		local z = nearZ + (i - 3) * 2.6
		local lamp = Kit.ball(lights, "Light" .. i, 1.6, flatAt(gx - 1.3, z, 15.1), LOOK.lightOff, { collide = false, query = false })
		lamp:SetAttribute("Index", i)
	end
	beam:SetAttribute("GantryBeam", true)

	-- The infield: a dark lawn with a clipped hedge, walled for cars.
	local infield = Kit.model(root, "Infield")
	local inner = w / 2 + 1.5
	Kit.part(infield, "Lawn", Vector3.new(2 * h, 0.08, 2 * R - 2 * inner), CFrame.new(flatAt(cx, cz, T.y + 0.02)), LOOK.lawn, PAINT)
	for _, z in { nearZ - inner + 0.6, farZ + inner - 0.6 } do
		Kit.part(infield, "Hedge", Vector3.new(2 * h - 8, 1.3, 1.2), CFrame.new(flatAt(cx, z, 0.65)), LOOK.hedge, { collide = false, query = false })
	end
	carWall(infield, "InfieldWall", Vector3.new(2 * h - 4, 8, 2 * R - 2 * inner), CFrame.new(flatAt(cx, cz, 4)))
	-- (Inside each hairpin: a round of tyres, walled too.)
	for _, east in { true, false } do
		local x = cx + (if east then h else -h)
		Kit.cylinder(infield, "TyreIsland", 1.4, 2 * (R - inner) - 6, CFrame.new(flatAt(x, cz, 0.7)) * CFrame.Angles(0, 0, math.rad(90)), LOOK.tyre, { collide = false, query = false })
		-- (A square inside the bend's inner edge: its corners stay off the road.)
		local side = math.floor(2 * (R - w / 2) / math.sqrt(2)) - 4
		carWall(infield, "IslandWall", Vector3.new(side, 8, side), CFrame.new(flatAt(x, cz, 4)))
	end

	-- The far side and the ends of the street: walls for cars (the street's own walls keep
	-- guests in).
	local edges = Kit.model(root, "Walls")
	local outerZ = farZ - w / 2 - 3
	carWall(edges, "FarWall", Vector3.new(2 * h, 8, 2), CFrame.new(flatAt(cx, outerZ, 4)))
	-- Along the kerb in front of the house: cars stay on the road.
	local kerbZ = nearZ + w / 2 + 11.6
	carWall(edges, "KerbWall", Vector3.new(2 * (h + R + w), 8, 1.6), CFrame.new(flatAt(cx, kerbZ, 4)))

	-- The bays along the kerb, each a pale gold box, and a sign by the door.
	local bays = Kit.model(root, "Bays")
	for i = 1, #GrandPrix.CARS do
		local bay = GrandPrix.bay(i)
		local p = bay.Position
		for _, dz in { -4.2, 4.2 } do
			Kit.part(bays, "BayLine", Vector3.new(16, 0.07, 0.3), CFrame.new(flatAt(p.X, p.Z + dz, T.y + 0.02)), LOOK.bay, PAINT)
		end
	end
	local signCf = CFrame.lookAt(flatAt(cx + 60, kerbZ + 4, 0), flatAt(cx + 60, kerbZ + 20, 0))
	local board = Kit.sign(bays, "GarageSign", signCf, 6.4, 2.6, {
		{ text = "THE GARAGE", size = 0.4, font = Brand.Fonts.display, color = C.gold },
		{ text = "Any car is yours to drive. Press Race to race.", size = 0.3, font = Brand.Fonts.body, color = C.bone },
	}, 4)
	board:SetAttribute("GarageSign", true)
	-- The Private Garage: two more bays, west of the others, and their own sign.
	for i = 1, #GrandPrix.GARAGE do
		local p = GrandPrix.privateBay(i).Position
		for _, dz in { -4.2, 4.2 } do
			Kit.part(bays, "PrivateBayLine", Vector3.new(16, 0.07, 0.3), CFrame.new(flatAt(p.X, p.Z + dz, T.y + 0.02)), LOOK.bay, PAINT)
		end
	end
	local privateCf = CFrame.lookAt(flatAt(cx - 60, kerbZ + 4, 0), flatAt(cx - 60, kerbZ + 20, 0))
	local privateBoard = Kit.sign(bays, "PrivateGarageSign", privateCf, 6.4, 2.6, {
		{ text = "THE PRIVATE GARAGE", size = 0.4, font = Brand.Fonts.display, color = C.gold },
		{ text = "Two cars for its holders. They drive like every other car.", size = 0.3, font = Brand.Fonts.body, color = C.bone },
	}, 4)
	privateBoard:SetAttribute("GarageSign", true)

	-- Lamps round the circuit: glowing heads only (the house keeps a budget of real lights, and
	-- the street's own lamps and the night's light already reach the road).
	local lamps = Kit.model(root, "Lamps")
	for _, spot in { { -h, nearZ + w / 2 + 4 }, { h, nearZ + w / 2 + 4 }, { 0, farZ - w / 2 - 6 }, { -h, farZ - w / 2 - 6 }, { h, farZ - w / 2 - 6 } } do
		local base = flatAt(cx + spot[1], spot[2], 0)
		Kit.post(lamps, "Pole", 16, 0.7, base, LOOK.black)
		Kit.part(lamps, "Head", Vector3.new(2.2, 0.6, 2.2), CFrame.new(base + Vector3.new(0, 16.3, 0)), { color = Color3.fromRGB(255, 226, 170), material = Enum.Material.Neon, transparency = 0.15 }, { collide = false, query = false })
	end

	Kit.persist(root)
	return root
end

return Circuit

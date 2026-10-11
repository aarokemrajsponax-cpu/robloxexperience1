--!strict
-- The Harvest Field (Thanksgiving): the Turkey Round-Up, away from the Maison. A fenced field of
-- autumn grass under the harvest moon: a great red barn with its doors open on lantern light, hay
-- bales, a pumpkin patch, corn tied in shocks, a friendly scarecrow, a long table laid for the
-- feast, trees in red and gold. The turkeys wander and peck, and run (and dodge) when a guest
-- comes near; catch one by running it down: Gilt, now and then a Gem. Every so often a golden
-- turkey walks out of the barn, faster than the rest and worth far more. A caught turkey goes back
-- to the barn and another comes out (nobody is hurt: they're very pleased with themselves).
--
-- The server moves each turkey (one small invisible part each, ten times a second) and decides
-- every catch; every screen draws the birds round those parts, smoothly, legs going.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Names = require(ReplicatedStorage.Shared.Names)
local Kit = require(script.Parent.Parent.World.Kit)
local Portal = require(script.Parent.Portal)
local Types = require(script.Parent.Types)

local Field = {}

local rgb = Color3.fromRGB
local L = Kit.Looks
type Look = Kit.Look
local function look(colour: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Look
	return { color = colour, material = material, reflectance = reflectance, transparency = transparency }
end
local TRIM = { collide = false, query = false, shadow = false }

type Turkey = {
	id: number,
	part: Part,
	at: Vector3, -- (relative to the field's middle, on the ground)
	face: Vector3,
	speed: number,
	golden: boolean,
	target: Vector3?,
	rest: number, -- pecking until (os.clock)
	jukeAt: number,
	juke: number, -- the angle it's dodging by
	out: number, -- walking out of the barn until (os.clock)
}

local built: Model? = nil
local birds: Folder? = nil
local turkeys: { Turkey } = {}
local obstacles: { { at: Vector3, r: number } } = {}
local nextId = 0
local nextSpawn = 0
local nextGolden = 0
local lastCatch: { [Player]: number } = {}
local opened = false

local function origin(): Vector3
	return HolidayGames.origin("field")
end

---------------------------------------------------------------------------------------------------
-- The field
---------------------------------------------------------------------------------------------------

-- The red barn: plank walls, white trim, a gambrel roof, its great doors open on a lantern-lit
-- inside with hay, a hayloft door and a rooster weathervane.
local function barn(parent: Instance, centre: Vector3)
	local m = Kit.model(parent, "Barn")
	local red = look(rgb(150, 38, 32), Enum.Material.WoodPlanks)
	local white = look(rgb(236, 230, 214), Enum.Material.WoodPlanks)
	local roof = look(rgb(70, 56, 52), Enum.Material.Slate)
	local hw, hd, wall = 28, 22, 22
	local function box(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, lk: Look, opts: { [string]: any }?): Part
		return Kit.span(m, name, centre + Vector3.new(x0, y0, z0), centre + Vector3.new(x1, y1, z1), lk, opts)
	end
	-- Walls, with the great doorway in the south wall (the doors stand open against it).
	box("WallBack", -hw, 0, hd - 1, hw, wall, hd, red)
	box("WallWest", -hw, 0, -hd, -hw + 1, wall, hd, red)
	box("WallEast", hw - 1, 0, -hd, hw, wall, hd, red)
	box("WallFrontW", -hw, 0, -hd, -8, wall, -hd + 1, red)
	box("WallFrontE", 8, 0, -hd, hw, wall, -hd + 1, red)
	box("WallOverDoor", -8, 18, -hd, 8, wall, -hd + 1, red)
	box("Floor", -hw, -0.4, -hd, hw, 0.2, hd, look(rgb(120, 96, 64), Enum.Material.WoodPlanks))
	box("Ceiling", -hw, wall - 0.4, -hd, hw, wall, hd, look(rgb(90, 64, 44), Enum.Material.WoodPlanks))
	-- Trim: corner boards, and the white frame round the doorway.
	for _, x in { -hw, hw } do
		for _, z in { -hd, hd } do
			box("CornerBoard", x - 0.6, 0, z - 0.6, x + 0.6, wall + 0.2, z + 0.6, white, TRIM)
		end
	end
	box("DoorFrame", -8.6, 0, -hd - 0.4, -8, 18.6, -hd + 0.2, white, TRIM)
	box("DoorFrame", 8, 0, -hd - 0.4, 8.6, 18.6, -hd + 0.2, white, TRIM)
	box("DoorFrame", -8.6, 18, -hd - 0.4, 8.6, 18.6, -hd + 0.2, white, TRIM)
	-- The doors, swung open against the front wall, each with its white X.
	for _, sx in { -1, 1 } do
		local x0 = sx * 8.8
		local x1 = sx * 16.6
		box("BarnDoor", math.min(x0, x1), 0, -hd - 1.1, math.max(x0, x1), 17.6, -hd - 0.5, red)
		local mid = centre + Vector3.new((x0 + x1) / 2, 8.8, -hd - 1.2)
		local len = math.sqrt(7.8 ^ 2 + 17.6 ^ 2)
		local angle = math.atan2(17.6, 7.8)
		for _, a in { angle, -angle } do
			Kit.part(m, "DoorBrace", Vector3.new(len, 0.6, 0.2), CFrame.new(mid) * CFrame.Angles(0, 0, a), white, TRIM)
		end
		box("DoorEdge", math.min(x0, x1), 0, -hd - 1.25, math.max(x0, x1), 0.6, -hd - 1.05, white, TRIM)
		box("DoorEdge", math.min(x0, x1), 17, -hd - 1.25, math.max(x0, x1), 17.6, -hd - 1.05, white, TRIM)
	end
	-- The gambrel roof: steep lower slopes, shallow upper ones, and the gable ends.
	local function slope(name: string, size: Vector3, cf: CFrame)
		local w = Instance.new("WedgePart")
		w.Name = name
		w.Anchored = true
		w.Size = size
		w.CFrame = cf
		w.Color = roof.color
		w.Material = roof.material
		w.Parent = m
	end
	local depth = 2 * hd + 3
	local kneeX, kneeY, ridgeY = 17, wall + 11, wall + 18
	for _, sx in { -1, 1 } do
		-- (Each wedge turned a quarter so its tall side faces the middle.)
		local turn = CFrame.Angles(0, -sx * math.pi / 2, 0)
		slope("RoofLower", Vector3.new(depth, kneeY - wall, hw + 1.5 - kneeX), CFrame.new(centre + Vector3.new(sx * (kneeX + (hw + 1.5 - kneeX) / 2), (wall + kneeY) / 2, 0)) * turn)
		slope("RoofUpper", Vector3.new(depth, ridgeY - kneeY, kneeX), CFrame.new(centre + Vector3.new(sx * kneeX / 2, (kneeY + ridgeY) / 2, 0)) * turn)
		Kit.span(m, "RoofBlock", centre + Vector3.new(sx * kneeX, wall, -depth / 2), centre + Vector3.new(0, kneeY, depth / 2), roof)
	end
	for _, z in { -hd, hd } do
		Kit.span(m, "Gable", centre + Vector3.new(-hw + 0.5, wall, z - 0.5), centre + Vector3.new(hw - 0.5, kneeY - 0.4, z + 0.5), red)
		for _, sx in { -1, 1 } do
			local w = Instance.new("WedgePart")
			w.Name = "GableTop"
			w.Anchored = true
			w.Size = Vector3.new(1, ridgeY - kneeY - 0.4, kneeX - 0.6)
			w.CFrame = CFrame.new(centre + Vector3.new(sx * (kneeX - 0.6) / 2, (kneeY + ridgeY - 0.4) / 2, z)) * CFrame.Angles(0, -sx * math.pi / 2, 0)
			w.Color = red.color
			w.Material = red.material
			w.Parent = m
		end
	end
	-- The hayloft door, lit, and the weathervane.
	local loft = Kit.part(m, "Hayloft", Vector3.new(7, 7, 0.4), CFrame.new(centre + Vector3.new(0, wall + 6.5, -hd - 0.6)), look(rgb(255, 196, 120), Enum.Material.Neon, 0, 0.3), TRIM)
	Kit.pointLight(loft, 1.6, 26, rgb(255, 180, 100))
	box("LoftFrame", -4, wall + 2.6, -hd - 0.9, 4, wall + 3.2, -hd - 0.4, white, TRIM)
	box("LoftFrame", -4, wall + 9.8, -hd - 0.9, 4, wall + 10.4, -hd - 0.4, white, TRIM)
	local vane = centre + Vector3.new(0, ridgeY + 0.5, 0)
	Kit.post(m, "VanePost", 4, 0.25, vane, L.brass, TRIM)
	Kit.part(m, "VaneArrow", Vector3.new(4, 0.2, 0.2), CFrame.new(vane + Vector3.new(0, 3, 0)), L.brass, TRIM)
	HolidayProps.ellipsoid(m, "Rooster", Vector3.new(0.3, 1.6, 1.8), CFrame.new(vane + Vector3.new(0, 4.1, 0)), rgb(200, 158, 80), Enum.Material.Metal)
	-- Inside: hay bales, lanterns, warm light falling out of the doors.
	for k = 0, 5 do
		local x = -hw + 6 + (k % 3) * 5
		local z = hd - 6 - math.floor(k / 3) * 4
		HolidayProps.hayBale(m, CFrame.new(centre + Vector3.new(x, 0.2, z)) * CFrame.Angles(0, k * 0.3, 0), Vector3.new(4.4, 2.4, 2.6))
		HolidayProps.hayBale(m, CFrame.new(centre + Vector3.new(-x, 0.2, z)) * CFrame.Angles(0, -k * 0.3, 0), Vector3.new(4.4, 2.4, 2.6))
	end
	for _, sx in { -1, 1 } do
		local glass = Kit.part(m, "Lantern", Vector3.new(1.1, 1.6, 1.1), CFrame.new(centre + Vector3.new(sx * 6, 14, -hd + 3)), L.glassWarm, TRIM)
		Kit.pointLight(glass, 2.4, 34, rgb(255, 176, 100))
	end
	local over = Kit.part(m, "DoorLamp", Vector3.new(1.2, 0.8, 1.2), CFrame.new(centre + Vector3.new(0, 19.6, -hd - 1.4)), L.blackLacquer, TRIM)
	Kit.spotLight(over, Enum.NormalId.Bottom, 3, 40, 80, rgb(255, 196, 130), false)
	return m
end

-- A long table laid for the feast: white cloth, candles, pumpkins and pies.
local function feastTable(parent: Instance, centre: Vector3)
	local m = Kit.model(parent, "FeastTable")
	local wood = L.walnut
	Kit.span(m, "Top", centre + Vector3.new(-14, 3, -2.2), centre + Vector3.new(14, 3.4, 2.2), wood)
	Kit.span(m, "Cloth", centre + Vector3.new(-14.3, 3.4, -2.5), centre + Vector3.new(14.3, 3.5, 2.5), look(rgb(240, 236, 226), Enum.Material.Fabric))
	Kit.span(m, "Runner", centre + Vector3.new(-14.3, 3.5, -0.7), centre + Vector3.new(14.3, 3.56, 0.7), look(rgb(170, 70, 30), Enum.Material.Fabric), TRIM)
	for _, x in { -13, 13 } do
		for _, z in { -1.8, 1.8 } do
			Kit.post(m, "Leg", 3, 0.5, centre + Vector3.new(x, 0, z), wood)
		end
	end
	for k = -3, 3 do
		local at = centre + Vector3.new(k * 4, 3.56, 0)
		Kit.post(m, "Candle", 1.4, 0.3, at, look(rgb(250, 240, 220), Enum.Material.SmoothPlastic), TRIM)
		local flame = Kit.part(m, "Flame", Vector3.new(0.22, 0.42, 0.22), CFrame.new(at + Vector3.new(0, 1.65, 0)), look(rgb(255, 190, 90), Enum.Material.Neon), TRIM)
		if k % 2 == 0 then
			Kit.pointLight(flame, 1, 10, rgb(255, 180, 100))
		end
		flame:SetAttribute("Flame", true)
		if k ~= 0 then
			local dish = centre + Vector3.new(k * 4 + 2, 3.56, (if k % 2 == 0 then -1.3 else 1.3))
			Kit.part(m, "Pie", Vector3.new(0.4, 2.2, 2.2), CFrame.new(dish + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(200, 130, 60), Enum.Material.SmoothPlastic), { shape = Enum.PartType.Cylinder, collide = false, query = false, shadow = false })
		end
	end
	HolidayProps.pumpkin(m, centre + Vector3.new(0, 3.56, 0), 1.6, Vector3.new(0, 0, -1), false)
	-- Benches either side.
	for _, z in { -4, 4 } do
		Kit.span(m, "Bench", centre + Vector3.new(-13, 1.6, z - 0.8), centre + Vector3.new(13, 2, z + 0.8), wood)
		for _, x in { -12, 12 } do
			Kit.span(m, "BenchLeg", centre + Vector3.new(x - 0.3, 0, z - 0.6), centre + Vector3.new(x + 0.3, 1.6, z + 0.6), wood)
		end
	end
	return m
end

-- A friendly scarecrow: a straw-stuffed sack head with a stitched smile, a straw hat, a plaid
-- shirt on a crossbar, and a sign.
local function scarecrow(parent: Instance, base: Vector3, facing: Vector3)
	local m = Kit.model(parent, "Scarecrow")
	local frame = CFrame.lookAt(base, base + facing)
	Kit.post(m, "Pole", 7, 0.4, base, L.darkWood)
	Kit.part(m, "Crossbar", Vector3.new(6, 0.35, 0.35), frame * CFrame.new(0, 5.4, 0), L.darkWood)
	Kit.part(m, "Shirt", Vector3.new(2.4, 2.8, 1.2), frame * CFrame.new(0, 4.6, 0), look(rgb(170, 50, 40), Enum.Material.Fabric))
	for _, sx in { -1, 1 } do
		Kit.part(m, "Sleeve", Vector3.new(2, 0.8, 0.8), frame * CFrame.new(sx * 2.1, 5.4, 0), look(rgb(150, 40, 34), Enum.Material.Fabric), TRIM)
		HolidayProps.ellipsoid(m, "Straw", Vector3.new(0.6, 0.8, 0.8), frame * CFrame.new(sx * 3.2, 5.4, 0), rgb(220, 186, 100), Enum.Material.Fabric)
	end
	local head = frame * CFrame.new(0, 6.9, 0)
	HolidayProps.ellipsoid(m, "Sack", Vector3.new(1.7, 1.8, 1.6), head, rgb(214, 190, 140), Enum.Material.Fabric)
	for _, sx in { -1, 1 } do
		HolidayProps.ball(m, "Button", 0.26, (head * CFrame.new(sx * 0.34, 0.2, -0.78)).Position, rgb(30, 26, 24))
	end
	for k = -2, 2 do
		Kit.part(m, "Stitch", Vector3.new(0.22, 0.06, 0.06), head * CFrame.new(k * 0.18, -0.35 + math.abs(k) * 0.06, -0.8), look(rgb(60, 40, 30), Enum.Material.Fabric), TRIM)
	end
	Kit.part(m, "HatBrim", Vector3.new(0.12, 3, 3), head * CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(220, 186, 100), Enum.Material.Fabric), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
	Kit.part(m, "Hat", Vector3.new(1, 1.4, 1.4), head * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(220, 186, 100), Enum.Material.Fabric), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
	local sign = Kit.part(m, "Sign", Vector3.new(3.6, 1.6, 0.2), frame * CFrame.new(0, 2.4, -0.6), look(rgb(150, 110, 70), Enum.Material.WoodPlanks), TRIM)
	Kit.engrave(sign, Enum.NormalId.Front, { { text = "CATCH A TURKEY!", size = 0.6, font = Brand.Fonts.heavy, color = rgb(60, 30, 16) } }, { ppu = 60, brightness = 1 })
end

local function build(ctx: Types.Ctx): Model
	local O = origin()
	local F = HolidayGames.Field
	local rng = Random.new(1123)
	local root = Instance.new("Model")
	root.Name = "HarvestField"
	root:SetAttribute("Area", "field")
	local function at(x: number, y: number, z: number): Vector3
		return O + Vector3.new(x, y, z)
	end
	obstacles = {}
	-- The ground: autumn grass all round, a dirt track from the gate to the barn.
	Kit.span(root, "Ground", at(-320, -2, -260), at(320, 0, 320), look(rgb(92, 82, 44), Enum.Material.Grass))
	-- (The fields go on past the hills, under the ground's edge.)
	Kit.part(root, "Beyond", Vector3.new(1800, 1, 1800), CFrame.new(at(0, -2.7, 30)), look(rgb(60, 56, 32), Enum.Material.Grass), { collide = false, shadow = false, query = false })
	Kit.span(root, "Track", at(-6, -1.9, F.minZ - 30), at(6, 0.05, F.barnDoors.Z), look(rgb(106, 80, 54), Enum.Material.Ground))
	-- The fence: split rails on posts, the gate in the south side.
	local wood = look(rgb(104, 76, 52), Enum.Material.Wood)
	local function rail(a: Vector3, b: Vector3)
		for _, y in { 1.6, 3.4 } do
			HolidayProps.rod(root, "Rail", a + Vector3.new(0, y, 0), b + Vector3.new(0, y, 0), 0.42, wood.color, wood.material).CanCollide = true
		end
	end
	local corners = { at(F.minX, 0, F.minZ), at(F.maxX, 0, F.minZ), at(F.maxX, 0, F.maxZ), at(F.minX, 0, F.maxZ) }
	for i = 1, 4 do
		local a, b = corners[i], corners[(i % 4) + 1]
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / 12))
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			local gate = i == 1 and math.abs(p.X - O.X) < 9
			if not gate then
				Kit.post(root, "FencePost", 4.6, 0.6, p, wood).CanCollide = true
			end
		end
		if i == 1 then
			rail(a, at(-9, 0, F.minZ))
			rail(at(9, 0, F.minZ), b)
		else
			rail(a, b)
		end
	end
	-- The gate: tall posts, a board across the top with the field's name, lanterns.
	for _, sx in { -1, 1 } do
		local p = at(sx * 9, 0, F.minZ)
		Kit.post(root, "GatePost", 14, 1.4, p, wood).CanCollide = true
		local glass = Kit.part(root, "GateLantern", Vector3.new(1.1, 1.6, 1.1), CFrame.new(p + Vector3.new(0, 10.5, -1.2)), L.glassWarm, TRIM)
		Kit.pointLight(glass, 1.8, 26, rgb(255, 176, 100))
		HolidayProps.cornShock(root, p + Vector3.new(sx * 3.4, 0, -2.4), 7)
		HolidayProps.pumpkin(root, p + Vector3.new(sx * 2.4, 0, -3.6), 2.4, Vector3.new(0, 0, -1), true, true)
	end
	local board = Kit.part(root, "FieldSign", Vector3.new(20, 3.2, 0.5), CFrame.new(at(0, 12.8, F.minZ)), look(rgb(124, 90, 60), Enum.Material.WoodPlanks), { collide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		Kit.engrave(board, face, {
			{ text = "THE HARVEST FIELD", size = 0.52, font = Brand.Fonts.display, color = rgb(255, 214, 140) },
			{ text = "Catch the turkeys", size = 0.26, font = Brand.Fonts.displayItalic, color = rgb(250, 236, 210) },
		}, { ppu = 60, lit = false, brightness = 1.5, maxDistance = 220 })
	end
	-- The barn, and the feast table before it.
	barn(root, at(F.barn.X, 0, F.barn.Z))
	table.insert(obstacles, { at = Vector3.new(F.barn.X, 0, F.barn.Z), r = 32 })
	feastTable(root, at(-60, 0, 60))
	table.insert(obstacles, { at = Vector3.new(-60, 0, 60), r = 15 })
	-- Hay bales round the field (some stacked), to dodge round.
	for k = 1, 14 do
		local x = rng:NextNumber(F.run.minX + 20, F.run.maxX - 20)
		local z = rng:NextNumber(F.run.minZ + 20, F.run.maxZ - 30)
		if math.abs(x) < 10 then
			x += 24
		end
		local turn = rng:NextNumber(0, math.pi)
		HolidayProps.hayBale(root, CFrame.new(at(x, 0, z)) * CFrame.Angles(0, turn, 0), Vector3.new(5, 2.8, 3))
		if k % 3 == 0 then
			HolidayProps.hayBale(root, CFrame.new(at(x, 2.8, z)) * CFrame.Angles(0, turn + 0.2, 0), Vector3.new(5, 2.8, 3))
		end
		table.insert(obstacles, { at = Vector3.new(x, 0, z), r = 3.6 })
	end
	-- The pumpkin patch, in the field's south-east corner, and the scarecrow keeping it.
	for k = 1, 22 do
		local x = rng:NextNumber(70, 150)
		local z = rng:NextNumber(-95, -40)
		HolidayProps.pumpkin(root, at(x, 0, z), rng:NextNumber(1.4, 3.2), Vector3.new(rng:NextNumber(-1, 1), 0, -1), k % 6 == 0, false)
	end
	scarecrow(root, at(110, 0, -66), Vector3.new(-1, 0, -1))
	table.insert(obstacles, { at = Vector3.new(110, 0, -66), r = 3 })
	-- Corn shocks along the fence, lamps on posts, and trees in red and gold.
	for _, p in { at(F.minX + 3, 0, F.minZ + 3), at(F.maxX - 3, 0, F.minZ + 3), at(F.minX + 3, 0, F.maxZ - 3), at(F.maxX - 3, 0, F.maxZ - 3) } do
		HolidayProps.cornShock(root, p, 8)
	end
	for _, p in { at(-120, 0, F.minZ + 2), at(120, 0, F.minZ + 2), at(F.minX + 2, 0, 0), at(F.maxX - 2, 0, 0), at(-120, 0, 60), at(120, 0, 30) } do
		Kit.post(root, "LampPost", 12, 0.5, p, wood).CanCollide = true
		local glass = Kit.part(root, "Lamp", Vector3.new(1.2, 1.8, 1.2), CFrame.new(p + Vector3.new(0, 12.6, 0)), L.glassWarm, TRIM)
		Kit.pointLight(glass, 1.8, 40, rgb(255, 170, 96))
		glass:SetAttribute("Flicker", true)
	end
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		local r = rng:NextNumber(205, 240)
		HolidayProps.autumnTree(root, at(math.cos(a) * r, 0, 20 + math.sin(a) * r * 0.95), rng:NextNumber(24, 36), rng)
	end
	for _, p in { Vector3.new(-120, 0, -40), Vector3.new(40, 0, 20), Vector3.new(-30, 0, -70) } do
		HolidayProps.autumnTree(root, at(p.X, 0, p.Z), rng:NextNumber(22, 28), rng)
		table.insert(obstacles, { at = p, r = 3 })
	end
	-- Hills on the horizon, dark against the moonlit sky.
	for k = 1, 9 do
		local a = math.rad(-150 + k * 34)
		local p = at(math.cos(a) * 520, -30, math.sin(a) * 520 + 40)
		HolidayProps.ellipsoid(root, "Hill", Vector3.new(rng:NextNumber(260, 380), rng:NextNumber(70, 110), rng:NextNumber(160, 240)), CFrame.new(p) * CFrame.Angles(0, a, 0), rgb(48, 44, 30), Enum.Material.Grass)
	end
	-- The way home, by the gate.
	Portal.build(root, CFrame.lookAt(at(-26, 0, F.minZ - 26), at(-26, 0, F.minZ - 27)), "The Harvest Field", function(player: Player)
		if ctx.inArea(player, "field") then
			ctx.sendHome(player)
		end
	end)
	-- The edges.
	local barrier = look(Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, 0, 1)
	for _, e in { { -200, -170, -199, 190 }, { 199, -170, 200, 190 }, { -200, -170, 200, -169 }, { -200, 189, 200, 190 } } do
		Kit.span(root, "Edge", at(e[1], -2, e[2]), at(e[3], 50, e[4]), barrier, { shadow = false, query = false })
	end
	Kit.persist(root)
	return root
end

---------------------------------------------------------------------------------------------------
-- The turkeys
---------------------------------------------------------------------------------------------------
local function spawnTurkey(ctx: Types.Ctx, golden: boolean)
	local f = birds
	if not f then
		return
	end
	nextId += 1
	local F = HolidayGames.Field
	local from = Vector3.new(F.barnDoors.X + ctx.rng:NextNumber(-5, 5), 0, F.barnDoors.Z + 2)
	local p = Instance.new("Part")
	p.Name = "Turkey"
	p.Size = Vector3.new(2.6, 3, 2.6)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p:SetAttribute("Id", nextId)
	p:SetAttribute("Golden", golden)
	p.CFrame = CFrame.lookAt(origin() + from, origin() + from - Vector3.new(0, 0, 1))
	p.Parent = f
	local now = os.clock()
	table.insert(turkeys, {
		id = nextId,
		part = p,
		at = from,
		face = Vector3.new(0, 0, -1),
		speed = 0,
		golden = golden,
		target = Vector3.new(from.X + ctx.rng:NextNumber(-30, 30), 0, from.Z - ctx.rng:NextNumber(25, 60)),
		rest = 0,
		jukeAt = now,
		juke = 0,
		out = now + 3,
	})
end

local function inBounds(p: Vector3): Vector3
	local R = HolidayGames.Field.run
	return Vector3.new(math.clamp(p.X, R.minX, R.maxX), 0, math.clamp(p.Z, R.minZ, R.maxZ))
end

-- Out of anything in the way (the barn, the table, the bales, the trees).
local function clear(p: Vector3): Vector3
	for _, o in obstacles do
		local away = Vector3.new(p.X - o.at.X, 0, p.Z - o.at.Z)
		local d = away.Magnitude
		if d < o.r then
			p = Vector3.new(o.at.X, 0, o.at.Z) + (if d > 0.01 then away.Unit else Vector3.new(1, 0, 0)) * o.r
		end
	end
	return p
end

local function moveTurkeys(ctx: Types.Ctx, dt: number, guests: { { player: Player, at: Vector3 } })
	local c = ctx.cfg().field
	local now = os.clock()
	local O = origin()
	for _, t in turkeys do
		local flee: Vector3? = nil
		local nearest = math.huge
		if now >= t.out then
			for _, g in guests do
				local away = Vector3.new(t.at.X - g.at.X, 0, t.at.Z - g.at.Z)
				local d = away.Magnitude
				if d < c.fear and d < nearest then
					nearest = d
					flee = if d > 0.1 then away.Unit else Vector3.new(1, 0, 0)
				end
			end
		end
		local dir: Vector3
		local speed: number
		if flee then
			-- Running, and dodging: a new swerve every half second or so.
			if now >= t.jukeAt then
				t.jukeAt = now + ctx.rng:NextNumber(0.45, 1.1)
				t.juke = ctx.rng:NextNumber(-0.9, 0.9)
			end
			dir = CFrame.Angles(0, t.juke, 0):VectorToWorldSpace(flee)
			speed = if t.golden then c.goldenSpeed else c.speed
			t.rest = 0
			t.target = nil
		elseif now < t.rest then
			dir = t.face
			speed = 0
		else
			-- Wandering: on to a spot nearby, then a peck at the grass.
			local target = t.target
			if not target or Vector3.new(target.X - t.at.X, 0, target.Z - t.at.Z).Magnitude < 2 then
				if target then
					t.rest = now + ctx.rng:NextNumber(1, 3.5)
				end
				target = inBounds(t.at + Vector3.new(ctx.rng:NextNumber(-28, 28), 0, ctx.rng:NextNumber(-28, 28)))
				t.target = target
			end
			local to = Vector3.new((target :: Vector3).X - t.at.X, 0, (target :: Vector3).Z - t.at.Z)
			dir = if to.Magnitude > 0.1 then to.Unit else t.face
			speed = if now < t.out then 7 else 4.5
		end
		local nextAt = t.at + dir * speed * dt
		local bounded = inBounds(nextAt)
		if bounded ~= nextAt and flee then
			-- At the fence: run along it, away from the guest.
			local along = Vector3.new(if bounded.X ~= nextAt.X then 0 else dir.X, 0, if bounded.Z ~= nextAt.Z then 0 else dir.Z)
			if along.Magnitude < 0.2 then
				along = Vector3.new(-dir.Z, 0, dir.X)
			end
			dir = along.Unit
			nextAt = inBounds(t.at + dir * speed * dt)
		else
			nextAt = bounded
		end
		nextAt = clear(nextAt)
		if speed > 0 and dir.Magnitude > 0.1 then
			t.face = dir
		end
		t.speed = speed
		t.at = nextAt
		local world = O + Vector3.new(nextAt.X, 1.5, nextAt.Z)
		t.part.CFrame = CFrame.lookAt(world, world + t.face)
		t.part:SetAttribute("Speed", math.floor(speed * 10) / 10)
	end
end

local function catch(ctx: Types.Ctx, player: Player, t: Turkey)
	local c = ctx.cfg().field
	local index = table.find(turkeys, t)
	if index then
		table.remove(turkeys, index)
	end
	local where = t.part.CFrame.Position
	t.part:Destroy()
	local gilt = if t.golden then c.goldenGilt else c.gilt
	local gems = if t.golden then c.goldenGems elseif ctx.rng:NextNumber() < c.gemChance then 1 else 0
	local paid, given = ctx.reward(player, gilt, gems, if t.golden then "The golden turkey" else "Turkey Round-Up")
	ctx.award(player, "holiday_thanksgiving")
	ctx.curio(player, "goldenWishbone", "field:" .. os.date("!%Y"))
	ctx.broadcast({ op = "caught", id = t.id, by = player.UserId, golden = t.golden, at = where })
	ctx.send(player, { op = "turkey", golden = t.golden, gilt = paid, gems = given })
	if t.golden then
		ctx.award(player, "goldenTurkeyCaught")
		ctx.curio(player, "goldenTurkey", "field:gold:" .. os.date("!%Y-%j"))
		ctx.salute("The Turkey Round-Up", Names.of(player) .. " caught the golden turkey!", player)
		nextGolden = os.clock() + c.goldenEvery
	end
	-- Another walks out of the barn in a moment.
	nextSpawn = math.max(nextSpawn, os.clock() + c.back)
end

---------------------------------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------------------------------

function Field.open(ctx: Types.Ctx)
	if built then
		built:Destroy()
	end
	local m = build(ctx)
	local f = Instance.new("Folder")
	f.Name = "Turkeys"
	f.Parent = m
	birds = f
	m.Parent = ctx.folder()
	built = m
	turkeys = {}
	opened = true
	for _ = 1, ctx.cfg().field.turkeys do
		spawnTurkey(ctx, false)
		local t = turkeys[#turkeys]
		-- (The first ones are already out in the field.)
		t.at = inBounds(Vector3.new(ctx.rng:NextNumber(-140, 140), 0, ctx.rng:NextNumber(-90, 70)))
		t.out = 0
		t.target = nil
	end
	nextGolden = os.clock() + 20
	nextSpawn = 0
end

function Field.close(_ctx: Types.Ctx)
	opened = false
	if built then
		built:Destroy()
		built = nil
	end
	birds = nil
	turkeys = {}
	table.clear(lastCatch)
end

function Field.step(ctx: Types.Ctx, dt: number)
	if not opened then
		return
	end
	local c = ctx.cfg().field
	local now = os.clock()
	local O = origin()
	-- The guests in the field.
	local guests: { { player: Player, at: Vector3 } } = {}
	for _, player in Players:GetPlayers() do
		local root = ctx.rootOf(player)
		if root then
			local p = root.CFrame.Position
			if HolidayGames.areaAt(p) == "field" then
				table.insert(guests, { player = player, at = Vector3.new(p.X - O.X, p.Y - O.Y, p.Z - O.Z) })
			end
		end
	end
	moveTurkeys(ctx, dt, guests)
	-- Catches.
	for _, g in guests do
		if (lastCatch[g.player] or -math.huge) + c.catchGap > now or not ctx.trusted(g.player) then
			continue
		end
		for _, t in turkeys do
			local d = Vector3.new(t.at.X - g.at.X, 0, t.at.Z - g.at.Z).Magnitude
			if d <= c.catch and math.abs(g.at.Y - 1.5) < 8 and now >= t.out - 1 then
				lastCatch[g.player] = now
				catch(ctx, g.player, t)
				break
			end
		end
	end
	-- The barn keeps the field full, and a golden one comes out now and then.
	local golden = false
	for _, t in turkeys do
		if t.golden then
			golden = true
		end
	end
	if not golden and now >= nextGolden then
		spawnTurkey(ctx, true)
		nextGolden = now + 1e9
		ctx.broadcast({ op = "goldenTurkey" })
	elseif #turkeys < c.turkeys + (if golden then 1 else 0) and now >= nextSpawn then
		spawnTurkey(ctx, false)
		nextSpawn = now + 1.5
	end
end

function Field.arrival(_ctx: Types.Ctx, _player: Player): CFrame?
	if not opened then
		return nil
	end
	local at = origin() + HolidayGames.Field.arrival
	return CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
end

function Field.state(_ctx: Types.Ctx, _player: Player): { [string]: any }
	local golden = false
	for _, t in turkeys do
		if t.golden then
			golden = true
		end
	end
	return { turkeys = #turkeys, golden = golden }
end

function Field.leave(_ctx: Types.Ctx, player: Player)
	lastCatch[player] = nil
end

-- For tests: the turkeys (id, where, golden).
function Field.turkeys(): { { id: number, at: Vector3, golden: boolean, part: Part } }
	local list = {}
	for _, t in turkeys do
		table.insert(list, { id = t.id, at = origin() + t.at, golden = t.golden, part = t.part })
	end
	return list
end

return Field

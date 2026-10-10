--!strict
-- The Street: wet stone at night, a narrow black townhouse, lamps, the brass plaque, the city beyond.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Layout = require(ReplicatedStorage.Shared.Layout).raw -- (the house as drawn: see World/Grand)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local S = Layout.Street

local Street = {}

local function streetLamp(parent: Instance, x: number, z: number)
	local m = Kit.model(parent, "StreetLamp")
	local base = Vector3.new(x, 0, z)
	Kit.post(m, "Base", 1.2, 1.4, base, L.blackLacquer)
	Kit.post(m, "Pole", 13, 0.45, base + Vector3.new(0, 1.2, 0), L.blackLacquer)
	Kit.part(m, "Arm", Vector3.new(0.3, 0.3, 2.4), CFrame.new(base + Vector3.new(0, 14, 1)), L.blackLacquer)
	local cage = Kit.part(m, "Lantern", Vector3.new(1.3, 1.9, 1.3), CFrame.new(base + Vector3.new(0, 13.2, 2)), L.glassWarm)
	Kit.part(m, "Cap", Vector3.new(1.6, 0.35, 1.6), CFrame.new(base + Vector3.new(0, 14.3, 2)), L.blackLacquer)
	local glow = Kit.part(m, "Glow", Vector3.new(0.6, 1.1, 0.6), CFrame.new(base + Vector3.new(0, 13.2, 2)), { color = Color3.fromRGB(255, 200, 130), material = Enum.Material.Neon }, { collide = false, shadow = false })
	Kit.pointLight(glow, 3, 40, Color3.fromRGB(255, 190, 120), true)
	cage.CanCollide = false
end

local function window(parent: Instance, x: number, y: number, z: number, w: number, h: number, lit: boolean)
	local frameDepth = 0.6
	Kit.part(parent, "WindowFrame", Vector3.new(w + 0.8, h + 0.8, frameDepth), CFrame.new(x, y, z - 0.05), L.facadeTrim)
	local look = if lit then L.windowGlow else { color = Color3.fromRGB(20, 24, 30), material = Enum.Material.Glass, reflectance = 0.3, transparency = 0.1 }
	local pane = Kit.part(parent, "Window", Vector3.new(w, h, 0.2), CFrame.new(x, y, z - 0.4), look, { shadow = false })
	-- Mullions
	Kit.part(parent, "Mullion", Vector3.new(0.18, h, 0.25), CFrame.new(x, y, z - 0.5), L.blackLacquer)
	Kit.part(parent, "Transom", Vector3.new(w, 0.18, 0.25), CFrame.new(x, y + h * 0.18, z - 0.5), L.blackLacquer)
	if lit then
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Front
		light.Brightness = 0.8
		light.Range = 12
		light.Angle = 80
		light.Color = Color3.fromRGB(255, 180, 110)
		light.Parent = pane
		-- Front of a part is -Z; the façade faces the street (-Z), so this lights the pavement.
	end
end

local function facade(parent: Instance)
	local m = Kit.model(parent, "Facade")
	local z = S.facadeZ
	local hw = S.houseHalfWidth
	local height = S.facadeHeight
	-- The wall, with the doorway cut out as separate pieces.
	local door = Layout.Door
	local dh = door.width / 2
	local floor = Layout.FLOOR
	Kit.span(m, "WallLeft", Vector3.new(-hw, 0, z), Vector3.new(-dh - 1.2, height, z + 2), L.facade)
	Kit.span(m, "WallRight", Vector3.new(dh + 1.2, 0, z), Vector3.new(hw, height, z + 2), L.facade)
	Kit.span(m, "WallOverDoor", Vector3.new(-dh - 1.2, floor + door.height + 1.4, z), Vector3.new(dh + 1.2, height, z + 2), L.facade)
	Kit.span(m, "WallUnderDoor", Vector3.new(-dh - 1.2, 0, z), Vector3.new(dh + 1.2, floor, z + 2), L.facade)
	-- Door surround: stone pilasters, a lintel and a fanlight
	Kit.span(m, "PilasterLeft", Vector3.new(-dh - 1.4, floor, z - 0.6), Vector3.new(-dh, floor + door.height + 1.4, z + 0.2), L.facadeTrim)
	Kit.span(m, "PilasterRight", Vector3.new(dh, floor, z - 0.6), Vector3.new(dh + 1.4, floor + door.height + 1.4, z + 0.2), L.facadeTrim)
	Kit.span(m, "Lintel", Vector3.new(-dh - 1.8, floor + door.height, z - 0.9), Vector3.new(dh + 1.8, floor + door.height + 1.6, z + 0.2), L.facadeTrim)
	local fan = Kit.part(m, "Fanlight", Vector3.new(door.width - 1, 1.1, 0.2), CFrame.new(0, floor + door.height - 0.6, z + 0.3), L.windowGlow, { shadow = false, collide = false })
	Kit.pointLight(fan, 1.2, 14, Color3.fromRGB(255, 190, 120))
	-- A cornice at each storey
	for _, y in { 20, 36, 52 } do
		Kit.span(m, "Cornice", Vector3.new(-hw - 0.6, y, z - 0.8), Vector3.new(hw + 0.6, y + 0.8, z + 0.2), L.facadeTrim)
	end
	Kit.span(m, "Parapet", Vector3.new(-hw - 0.8, height, z - 1), Vector3.new(hw + 0.8, height + 1.2, z + 0.4), L.facadeTrim)
	-- Tall windows: ground floor either side of the door, and three storeys above.
	window(m, -12.5, 11, z, 5, 10, true)
	window(m, 12.5, 11, z, 5, 10, true)
	for i, y in { 28, 44 } do
		for _, x in { -12.5, 0, 12.5 } do
			window(m, x, y, z, 4.4, 9.5, (x + y + i) % 3 ~= 0)
		end
	end
	for _, x in { -12.5, 0, 12.5 } do
		window(m, x, 57, z, 4, 4.5, x == 0)
	end
	-- Iron balconette on the first floor
	Kit.span(m, "Balcony", Vector3.new(-6, 22.2, z - 2.2), Vector3.new(6, 22.6, z), L.blackLacquer)
	for x = -6, 6, 1 do
		Kit.part(m, "Baluster", Vector3.new(0.12, 2.6, 0.12), CFrame.new(x, 23.9, z - 2.1), L.blackLacquer)
	end
	Kit.span(m, "Rail", Vector3.new(-6, 25.2, z - 2.25), Vector3.new(6, 25.45, z - 1.95), L.blackLacquer)

	-- The brass plaque beside the door
	-- A part's Front face is -Z, which here faces the street.
	local plaque = Kit.part(m, "Plaque", Vector3.new(3.4, 2.2, 0.15), CFrame.new(dh + 3.6, floor + 6.2, z - 0.12), L.brass)
	Kit.engrave(plaque, Enum.NormalId.Front, {
		{ text = "MAISON NOIR", size = 0.36, font = Brand.Fonts.display, color = Color3.fromRGB(40, 30, 12) },
		{ text = "MEMBERS", size = 0.18, font = Brand.Fonts.bodyMedium, color = Color3.fromRGB(60, 46, 18) },
	}, { ppu = 90, brightness = 1 })
	local plaqueLamp = Kit.part(m, "PlaqueLamp", Vector3.new(0.5, 0.5, 0.4), CFrame.new(dh + 3.6, floor + 8.3, z - 0.4), L.brass, { collide = false })
	Kit.spotLight(plaqueLamp, Enum.NormalId.Bottom, 2, 8, 70, Color3.fromRGB(255, 200, 140))

	-- Steps up to the door
	for i = 1, S.steps do
		local depth = S.stepDepth * (S.steps - i + 1)
		Kit.span(m, "Step" .. i, Vector3.new(-dh - 2.5, i - 1, z - depth), Vector3.new(dh + 2.5, i, z), L.wetStone)
	end
	-- Railings along the steps
	for _, x in { -dh - 2.3, dh + 2.3 } do
		Kit.post(m, "Newel", 3.6, 0.35, Vector3.new(x, 0, z - S.stepDepth * S.steps), L.blackLacquer)
		Kit.post(m, "NewelTop", 0.4, 0.55, Vector3.new(x, 3.6, z - S.stepDepth * S.steps), L.brass)
	end
	-- Two lanterns flanking the door
	for _, x in { -dh - 2.6, dh + 2.6 } do
		local lantern = Kit.part(m, "DoorLantern", Vector3.new(0.9, 1.5, 0.9), CFrame.new(x, floor + 10.5, z - 0.8), L.glassWarm, { collide = false })
		Kit.part(m, "DoorLanternCap", Vector3.new(1.1, 0.3, 1.1), CFrame.new(x, floor + 11.4, z - 0.8), L.blackLacquer)
		Kit.pointLight(lantern, 1.6, 16, Color3.fromRGB(255, 188, 116), true)
	end
	return m
end

local function neighbours(parent: Instance)
	local m = Kit.model(parent, "Neighbours")
	local z = S.facadeZ
	local specs: { { any } } = {
		-- The two west of the house are low (three storeys), so the Suite's terrace on the roof
		-- behind them looks out over the street and its pool's glow is seen from the pavement.
		{ -44, -20, 21, L.neighbourStone },
		{ -70, -44, 21, L.neighbour },
		{ 20, 46, 48, L.neighbour },
		{ 46, 74, 56, L.neighbourStone },
	}
	for i, s in specs do
		local x0, x1, h, look = s[1] :: number, s[2] :: number, s[3] :: number, s[4] :: Kit.Look
		-- Shallow enough that the back face hides inside the rooms' walls (no fighting faces).
		Kit.span(m, "Building" .. i, Vector3.new(x0, 0, z - 0.5), Vector3.new(x1, h, z + 3), look)
		Kit.span(m, "Cornice" .. i, Vector3.new(x0, h, z - 1.2), Vector3.new(x1, h + 1, z + 3), L.facadeTrim)
		local cols = math.floor((x1 - x0) / 8)
		for c = 0, cols - 1 do
			for r, y in { 10, 24, 38 } do
				if y + 6 < h then
					local x = x0 + 4 + c * 8
					local lit = (c * 7 + r * 3 + i) % 5 == 0
					window(m, x, y, z - 0.5, 3.4, 7, lit)
				end
			end
		end
	end
end

local function ground(parent: Instance)
	local m = Kit.model(parent, "Ground")
	local road = S.roadZ
	local pave = S.pavementZ
	Kit.span(m, "Road", Vector3.new(-120, -2, road[1] - 60), Vector3.new(120, 0, road[2]), L.asphalt)
	-- (The pavement and the kerb carry Roblox's classic studs, faint on the dark stone.)
	Kit.studs(Kit.span(m, "Pavement", Vector3.new(-120, -2, pave[1]), Vector3.new(120, 0, pave[2]), L.wetStone))
	Kit.studs(Kit.span(m, "Kerb", Vector3.new(-120, -2, S.kerbZ - 0.8), Vector3.new(120, 0.35, S.kerbZ), L.kerb))
	-- Paving joints read as a grid of slightly different stones.
	for x = -60, 60, 6 do
		Kit.part(m, "Joint", Vector3.new(0.12, 0.02, pave[2] - pave[1]), CFrame.new(x, 0.01, (pave[1] + pave[2]) / 2), { color = Color3.fromRGB(26, 27, 30), material = Enum.Material.Slate }, { collide = false, query = false, shadow = false })
	end
	-- Puddles reflect the lamps.
	local puddles = {
		{ -9, -22, 5, 2.6 }, { 6, -30, 3.4, 1.8 }, { 17, -24, 4.2, 2.2 }, { -20, -30, 6, 2.4 },
		{ -4, -44, 8, 3 }, { 22, -50, 6, 2.6 }, { -30, -40, 7, 3 },
	}
	for _, pd in puddles do
		Kit.part(m, "Puddle", Vector3.new(pd[3], 0.03, pd[4]), CFrame.new(pd[1], 0.02, pd[2]) * CFrame.Angles(0, math.rad(pd[1] * 7), 0), L.puddle, { collide = false, query = false, shadow = false })
	end
	-- Road markings, faint
	for x = -110, 110, 14 do
		Kit.part(m, "Marking", Vector3.new(6, 0.02, 0.3), CFrame.new(x, 0.01, (road[1] + road[2]) / 2), { color = Color3.fromRGB(120, 116, 104), material = Enum.Material.SmoothPlastic, transparency = 0.5 }, { collide = false, query = false, shadow = false })
	end
	-- Invisible walls keep guests on the street.
	local barrier = { color = Color3.new(0, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 1 }
	Kit.span(m, "EdgeFar", Vector3.new(-80, 0, road[1] - 1), Vector3.new(80, 30, road[1]), barrier, { shadow = false, query = false })
	Kit.span(m, "EdgeLeft", Vector3.new(-81, 0, road[1]), Vector3.new(-80, 30, S.facadeZ), barrier, { shadow = false, query = false })
	Kit.span(m, "EdgeRight", Vector3.new(80, 0, road[1]), Vector3.new(81, 30, S.facadeZ), barrier, { shadow = false, query = false })
end

local function city(parent: Instance)
	local m = Kit.model(parent, "City")
	-- A dark skyline across the road, with scattered warm windows. Far enough to sit in the haze.
	local rng = Random.new(1987)
	local x = -260
	while x < 260 do
		local w = rng:NextNumber(18, 40)
		local h = rng:NextNumber(40, 150)
		local z = -140 - rng:NextNumber(0, 60)
		local b = Kit.span(m, "Tower", Vector3.new(x, 0, z - 20), Vector3.new(x + w, h, z), L.skyline, { shadow = false, query = false })
		b.CanCollide = false
		local lights = math.floor(h / 12)
		for i = 1, lights do
			if rng:NextNumber() < 0.55 then
				local lx = x + rng:NextNumber(2, w - 2)
				local ly = rng:NextNumber(6, h - 4)
				Kit.part(m, "Light", Vector3.new(1.2, 1.6, 0.2), CFrame.new(lx, ly, z + 0.15), L.cityLight, { collide = false, query = false, shadow = false })
			end
		end
		x += w + rng:NextNumber(2, 10)
	end
	-- The buildings directly opposite, closer, low and dark.
	Kit.span(m, "Opposite", Vector3.new(-120, 0, -128), Vector3.new(120, 26, -124), L.neighbour, { shadow = false })
	for lx = -110, 110, 9 do
		if (lx // 9) % 3 ~= 0 then
			Kit.part(m, "OppositeWindow", Vector3.new(3, 5, 0.2), CFrame.new(lx, 14, -123.8), L.windowGlow, { collide = false, query = false, shadow = false })
		end
	end
end

function Street.build(parent: Instance): Model
	local root = Kit.model(parent, "Street")
	ground(root)
	facade(root)
	neighbours(root)
	city(root)
	for _, x in S.lampXs do
		streetLamp(root, x, S.lampZ)
	end
	for _, x in { -45, 45 } do
		streetLamp(root, x, S.lampZ)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "StreetSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(4, 0.2, 4)
	spawn.CFrame = CFrame.new(S.spawn.Position.X, 0.1, S.spawn.Position.Z) * S.spawn.Rotation
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = root
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	return root
end

return Street

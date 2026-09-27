--!strict
-- Small 3D objects for every piece in the catalogue, built from parts so they exist without
-- uploaded meshes. Gold is polished metal, gems are glass, pearls have a soft sheen.
-- Every model has an invisible `Hit` primary part sized to its bounds for picking.

local Catalogue = require(script.Parent.Catalogue)

local PieceModels = {}

type Look = { color: Color3, material: Enum.Material, reflectance: number?, transparency: number? }

local GOLD: Look = { color = Color3.fromRGB(212, 175, 84), material = Enum.Material.Metal, reflectance = 0.45 }
local ROSE_GOLD: Look = { color = Color3.fromRGB(206, 150, 120), material = Enum.Material.Metal, reflectance = 0.4 }
local PLATINUM: Look = { color = Color3.fromRGB(214, 218, 224), material = Enum.Material.Metal, reflectance = 0.5 }
local COPPER: Look = { color = Color3.fromRGB(172, 104, 62), material = Enum.Material.Metal, reflectance = 0.35 }
local STEEL: Look = { color = Color3.fromRGB(150, 156, 164), material = Enum.Material.Metal, reflectance = 0.35 }
local BLACK: Look = { color = Color3.fromRGB(14, 14, 18), material = Enum.Material.SmoothPlastic, reflectance = 0.15 }
local LEATHER: Look = { color = Color3.fromRGB(46, 30, 26), material = Enum.Material.Fabric }
local BONE: Look = { color = Color3.fromRGB(236, 228, 210), material = Enum.Material.SmoothPlastic }
local PEARL: Look = { color = Color3.fromRGB(240, 234, 226), material = Enum.Material.SmoothPlastic, reflectance = 0.35 }
local GLASS: Look = { color = Color3.fromRGB(200, 214, 230), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0.35 }
local NOTES: Look = { color = Color3.fromRGB(122, 150, 118), material = Enum.Material.Fabric }
local DARK_GLASS: Look = { color = Color3.fromRGB(30, 34, 40), material = Enum.Material.Glass, reflectance = 0.25, transparency = 0.2 }
local VELVET: Look = { color = Color3.fromRGB(74, 22, 32), material = Enum.Material.Fabric }

local function gem(color: Color3): Look
	return { color = color, material = Enum.Material.Glass, reflectance = 0.35, transparency = 0.15 }
end

local function part(parent: Instance, shape: string, size: Vector3, cframe: CFrame, look: Look): BasePart
	local p: BasePart
	if shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		local basic = Instance.new("Part")
		if shape == "ball" then
			basic.Shape = Enum.PartType.Ball
		elseif shape == "cylinder" then
			basic.Shape = Enum.PartType.Cylinder
		else
			basic.Shape = Enum.PartType.Block
		end
		p = basic
	end
	p.Size = size
	p.CFrame = cframe
	p.Color = look.color
	p.Material = look.material
	p.Reflectance = look.reflectance or 0
	p.Transparency = look.transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A cylinder standing on its end (axis up). Roblox cylinders lie along X.
local function upright(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(90))
end

-- Flat disc: diameter d, thickness t, resting on the ground plane at y.
local function disc(parent: Instance, d: number, t: number, cf: CFrame, look: Look): BasePart
	return part(parent, "cylinder", Vector3.new(t, d, d), cf * CFrame.Angles(0, 0, math.rad(90)), look)
end

-- A ring approximated by n small beads.
local function beadRing(parent: Instance, radius: number, bead: number, n: number, y: number, look: Look, squash: number?)
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local x = math.cos(a) * radius
		local z = math.sin(a) * radius * (squash or 1)
		part(parent, "ball", Vector3.new(bead, bead, bead), CFrame.new(x, y, z), look)
	end
end

-- A band ring: a flat cylinder with a felt-coloured centre so it reads as a hole from above.
local function band(parent: Instance, d: number, t: number, y: number, look: Look, hole: Look)
	disc(parent, d, t, CFrame.new(0, y, 0), look)
	disc(parent, d * 0.62, t + 0.01, CFrame.new(0, y, 0), hole)
end

local function cutStone(parent: Instance, size: number, cf: CFrame, look: Look)
	-- Two blocks rotated against each other read as a faceted stone.
	part(parent, "block", Vector3.new(size, size * 0.75, size), cf * CFrame.Angles(0, math.rad(45), 0), look)
	part(parent, "block", Vector3.new(size * 0.8, size * 0.9, size * 0.8), cf * CFrame.Angles(math.rad(35), math.rad(20), math.rad(35)), look)
end

type Recipe = (parent: Model, felt: Look) -> ()

local recipes: { [string]: Recipe } = {}

local function watch(caseLook: Look, dialLook: Look, strapLook: Look, size: number)
	return function(parent: Model, felt: Look)
		disc(parent, size, 0.16, CFrame.new(0, 0.08, 0), caseLook)
		disc(parent, size * 0.82, 0.04, CFrame.new(0, 0.17, 0), dialLook)
		disc(parent, size * 0.82, 0.03, CFrame.new(0, 0.2, 0), GLASS)
		part(parent, "block", Vector3.new(size * 0.06, 0.01, size * 0.34), CFrame.new(0, 0.19, -size * 0.14), caseLook)
		part(parent, "block", Vector3.new(size * 0.05, 0.01, size * 0.22), CFrame.new(size * 0.08, 0.19, size * 0.03) * CFrame.Angles(0, math.rad(-40), 0), caseLook)
		part(parent, "block", Vector3.new(size * 0.35, 0.06, size * 0.7), CFrame.new(0, 0.03, -size * 0.75), strapLook)
		part(parent, "block", Vector3.new(size * 0.35, 0.06, size * 0.7), CFrame.new(0, 0.03, size * 0.75), strapLook)
	end
end

recipes.chronograph = watch(STEEL, BLACK, BLACK, 0.7)
recipes.dressWatch = watch(GOLD, BONE, LEATHER, 0.62)
recipes.diveWatch = watch(STEEL, { color = Color3.fromRGB(20, 40, 80), material = Enum.Material.SmoothPlastic }, STEEL, 0.68)
recipes.moonphase = watch(ROSE_GOLD, { color = Color3.fromRGB(28, 34, 60), material = Enum.Material.SmoothPlastic }, LEATHER, 0.66)
recipes.noirChronometer = watch(BLACK, BLACK, BLACK, 0.68)

recipes.pocketWatch = function(parent, felt)
	disc(parent, 0.78, 0.18, CFrame.new(0, 0.09, 0), GOLD)
	disc(parent, 0.64, 0.04, CFrame.new(0, 0.19, 0), BONE)
	disc(parent, 0.64, 0.03, CFrame.new(0, 0.22, 0), GLASS)
	part(parent, "cylinder", Vector3.new(0.14, 0.12, 0.12), CFrame.new(0, 0.1, -0.45) * CFrame.Angles(0, math.rad(90), 0), GOLD)
	for i = 1, 7 do
		part(parent, "ball", Vector3.new(0.07, 0.07, 0.07), CFrame.new(0.42 + i * 0.09, 0.04, -0.2 + i * 0.06), GOLD)
	end
end

local function ring(bandLook: Look, stone: Look?, stoneSize: number)
	return function(parent: Model, felt: Look)
		band(parent, 0.5, 0.12, 0.06, bandLook, felt)
		if stone then
			cutStone(parent, stoneSize, CFrame.new(0, 0.18, -0.2), stone)
		end
	end
end

recipes.diamondRing = ring(PLATINUM, gem(Color3.fromRGB(235, 242, 255)), 0.16)
recipes.signetRing = function(parent, felt)
	band(parent, 0.5, 0.14, 0.07, GOLD, felt)
	disc(parent, 0.24, 0.05, CFrame.new(0, 0.16, -0.2), GOLD)
end
recipes.amberRing = ring(GOLD, gem(Color3.fromRGB(230, 140, 40)), 0.15)

recipes.tennisBracelet = function(parent, felt)
	beadRing(parent, 0.42, 0.09, 16, 0.05, PLATINUM)
	beadRing(parent, 0.42, 0.06, 16, 0.1, gem(Color3.fromRGB(240, 245, 255)))
end
recipes.pearlNecklace = function(parent, felt)
	beadRing(parent, 0.55, 0.12, 20, 0.06, PEARL, 0.7)
end
recipes.earrings = function(parent, felt)
	for _, x in { -0.18, 0.18 } do
		part(parent, "ball", Vector3.new(0.08, 0.08, 0.08), CFrame.new(x, 0.04, -0.14), GOLD)
		part(parent, "block", Vector3.new(0.015, 0.01, 0.2), CFrame.new(x, 0.02, -0.02), GOLD)
		cutStone(parent, 0.12, CFrame.new(x, 0.07, 0.12), gem(Color3.fromRGB(240, 245, 255)))
	end
end
recipes.cufflinks = function(parent, felt)
	for _, x in { -0.16, 0.16 } do
		disc(parent, 0.2, 0.05, CFrame.new(x, 0.03, 0), GOLD)
		disc(parent, 0.1, 0.02, CFrame.new(x, 0.07, 0), BLACK)
	end
end
recipes.ravenBrooch = function(parent, felt)
	part(parent, "block", Vector3.new(0.5, 0.06, 0.28), CFrame.new(0, 0.03, 0) * CFrame.Angles(0, math.rad(20), 0), BLACK)
	part(parent, "wedge", Vector3.new(0.14, 0.1, 0.34), CFrame.new(0.26, 0.06, -0.06) * CFrame.Angles(0, math.rad(20), 0), BLACK)
	cutStone(parent, 0.08, CFrame.new(0.18, 0.09, -0.06), gem(Color3.fromRGB(220, 60, 60)))
end
recipes.heartLocket = function(parent, felt)
	part(parent, "ball", Vector3.new(0.22, 0.12, 0.22), CFrame.new(-0.09, 0.06, -0.05), ROSE_GOLD)
	part(parent, "ball", Vector3.new(0.22, 0.12, 0.22), CFrame.new(0.09, 0.06, -0.05), ROSE_GOLD)
	part(parent, "block", Vector3.new(0.26, 0.1, 0.26), CFrame.new(0, 0.05, 0.05) * CFrame.Angles(0, math.rad(45), 0), ROSE_GOLD)
	for i = 1, 8 do
		part(parent, "ball", Vector3.new(0.05, 0.05, 0.05), CFrame.new(-0.3 + i * 0.07, 0.03, -0.3 - (i % 2) * 0.03), ROSE_GOLD)
	end
end
recipes.cloverPin = function(parent, felt)
	local green = { color = Color3.fromRGB(56, 140, 80), material = Enum.Material.SmoothPlastic, reflectance = 0.2 }
	for _, o in { Vector3.new(0.1, 0, 0), Vector3.new(-0.1, 0, 0), Vector3.new(0, 0, 0.1), Vector3.new(0, 0, -0.1) } do
		part(parent, "ball", Vector3.new(0.16, 0.08, 0.16), CFrame.new(o.X, 0.04, o.Z), green)
	end
	part(parent, "block", Vector3.new(0.02, 0.02, 0.24), CFrame.new(0, 0.02, 0.22), GOLD)
end
recipes.blossomPin = function(parent, felt)
	local petal = { color = Color3.fromRGB(246, 204, 216), material = Enum.Material.SmoothPlastic }
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		part(parent, "ball", Vector3.new(0.14, 0.06, 0.14), CFrame.new(math.cos(a) * 0.1, 0.04, math.sin(a) * 0.1), petal)
	end
	part(parent, "ball", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, 0.06, 0), GOLD)
end
recipes.sunPendant = function(parent, felt)
	disc(parent, 0.36, 0.05, CFrame.new(0, 0.03, 0), GOLD)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(parent, "block", Vector3.new(0.04, 0.03, 0.12), CFrame.new(math.cos(a) * 0.24, 0.02, math.sin(a) * 0.24) * CFrame.Angles(0, -a, 0), GOLD)
	end
	for i = 1, 8 do
		part(parent, "ball", Vector3.new(0.04, 0.04, 0.04), CFrame.new(-0.3 + i * 0.075, 0.02, -0.28), GOLD)
	end
end
recipes.blueMoonPearl = function(parent, felt)
	part(parent, "block", Vector3.new(0.5, 0.08, 0.5), CFrame.new(0, 0.04, 0), VELVET)
	part(parent, "ball", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.22, 0), { color = Color3.fromRGB(190, 206, 236), material = Enum.Material.SmoothPlastic, reflectance = 0.5 })
end

local function bar(look: Look)
	return function(parent: Model, felt: Look)
		part(parent, "block", Vector3.new(0.9, 0.26, 0.46), CFrame.new(0, 0.13, 0), look)
		part(parent, "block", Vector3.new(0.78, 0.06, 0.36), CFrame.new(0, 0.29, 0), look)
	end
end
recipes.goldBar = bar(GOLD)
recipes.platinumBar = bar(PLATINUM)
recipes.copperBar = bar(COPPER)

recipes.cashStack = function(parent, felt)
	part(parent, "block", Vector3.new(0.8, 0.22, 0.4), CFrame.new(0, 0.11, 0), NOTES)
	part(parent, "block", Vector3.new(0.14, 0.24, 0.42), CFrame.new(0, 0.12, 0), BONE)
end
local function coins(look: Look, count: number)
	return function(parent: Model, felt: Look)
		for i = 1, count do
			disc(parent, 0.34, 0.05, CFrame.new(0, 0.025 + (i - 1) * 0.055, 0) * CFrame.Angles(0, math.rad(i * 9), 0), look)
		end
		disc(parent, 0.34, 0.05, CFrame.new(0.32, 0.025, 0.14), look)
		disc(parent, 0.34, 0.05, CFrame.new(-0.28, 0.025, 0.2), look)
	end
end
recipes.goldCoins = coins(GOLD, 5)
recipes.moneyClip = function(parent, felt)
	part(parent, "block", Vector3.new(0.5, 0.12, 0.3), CFrame.new(0, 0.06, 0), NOTES)
	part(parent, "block", Vector3.new(0.5, 0.03, 0.12), CFrame.new(0, 0.14, 0), GOLD)
end
local function coin(look: Look, d: number)
	return function(parent: Model, felt: Look)
		disc(parent, d, 0.07, CFrame.new(0, 0.035, 0), look)
		disc(parent, d * 0.7, 0.01, CFrame.new(0, 0.075, 0), { color = look.color:Lerp(Color3.new(0, 0, 0), 0.25), material = look.material, reflectance = look.reflectance })
	end
end
recipes.yearCoin = coin(GOLD, 0.5)
recipes.luckyCoin = coin(COPPER, 0.44)
recipes.sovereignCoin = coin({ color = Color3.fromRGB(240, 200, 100), material = Enum.Material.Metal, reflectance = 0.6 }, 0.6)

recipes.carKey = function(parent, felt)
	part(parent, "block", Vector3.new(0.26, 0.1, 0.5), CFrame.new(0, 0.05, 0), BLACK)
	part(parent, "block", Vector3.new(0.12, 0.02, 0.1), CFrame.new(0, 0.11, -0.08), STEEL)
	beadRing(parent, 0.12, 0.04, 10, 0.03, STEEL)
	local dummy = felt
	dummy = dummy
end
recipes.keyCard = function(parent, felt)
	part(parent, "block", Vector3.new(0.6, 0.03, 0.38), CFrame.new(0, 0.015, 0), BLACK)
	part(parent, "block", Vector3.new(0.6, 0.01, 0.06), CFrame.new(0, 0.035, -0.1), GOLD)
end
local function key(look: Look, length: number, ornate: boolean)
	return function(parent: Model, felt: Look)
		part(parent, "cylinder", Vector3.new(length, 0.08, 0.08), CFrame.new(0, 0.04, 0), look)
		band(parent, 0.26, 0.06, 0.03, look, felt)
		part(parent, "block", Vector3.new(0.08, 0.06, 0.12), CFrame.new(length / 2 - 0.08, 0.03, 0.08), look)
		part(parent, "block", Vector3.new(0.06, 0.06, 0.08), CFrame.new(length / 2 - 0.2, 0.03, 0.06), look)
		if ornate then
			band(parent, 0.14, 0.06, 0.03, look, felt)
			cutStone(parent, 0.07, CFrame.new(-length / 2 + 0.02, 0.08, 0), gem(Color3.fromRGB(220, 60, 60)))
		end
	end
end
recipes.valetKey = function(parent, felt)
	part(parent, "block", Vector3.new(0.3, 0.03, 0.5), CFrame.new(-0.15, 0.015, 0), LEATHER)
	part(parent, "cylinder", Vector3.new(0.45, 0.06, 0.06), CFrame.new(0.2, 0.03, 0), STEEL)
	part(parent, "block", Vector3.new(0.06, 0.06, 0.1), CFrame.new(0.38, 0.03, 0.06), STEEL)
end
recipes.vaultKey = key(STEEL, 0.9, false)
recipes.lodgeKey = key(COPPER, 0.8, false)
recipes.gardenKey = key({ color = Color3.fromRGB(100, 120, 90), material = Enum.Material.Metal, reflectance = 0.2 }, 0.8, false)
recipes.foundersKey = key(GOLD, 1.0, true)

recipes.sunglasses = function(parent, felt)
	for _, x in { -0.19, 0.19 } do
		disc(parent, 0.3, 0.03, CFrame.new(x, 0.015, 0), DARK_GLASS)
		part(parent, "block", Vector3.new(0.05, 0.05, 0.62), CFrame.new(x * 1.7, 0.03, 0.3), BLACK)
	end
	part(parent, "block", Vector3.new(0.12, 0.04, 0.04), CFrame.new(0, 0.03, -0.04), GOLD)
end
recipes.perfume = function(parent, felt)
	part(parent, "block", Vector3.new(0.34, 0.42, 0.2), CFrame.new(0, 0.21, 0), { color = Color3.fromRGB(230, 200, 160), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0.3 })
	part(parent, "block", Vector3.new(0.14, 0.16, 0.14), CFrame.new(0, 0.5, 0), GOLD)
end
recipes.roseVial = function(parent, felt)
	part(parent, "cylinder", Vector3.new(0.4, 0.16, 0.16), upright(0, 0.2, 0), { color = Color3.fromRGB(240, 170, 190), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0.3 })
	part(parent, "cylinder", Vector3.new(0.1, 0.1, 0.1), upright(0, 0.45, 0), ROSE_GOLD)
end
local function pen(look: Look, capLook: Look)
	return function(parent: Model, felt: Look)
		part(parent, "cylinder", Vector3.new(1.0, 0.09, 0.09), CFrame.new(0, 0.045, 0) * CFrame.Angles(0, math.rad(25), 0), look)
		part(parent, "cylinder", Vector3.new(0.3, 0.1, 0.1), CFrame.new(-0.3, 0.05, -0.14) * CFrame.Angles(0, math.rad(25), 0), capLook)
		part(parent, "block", Vector3.new(0.02, 0.02, 0.22), CFrame.new(-0.31, 0.1, -0.12) * CFrame.Angles(0, math.rad(-65), 0), capLook)
	end
end
recipes.fountainPen = pen(BLACK, GOLD)
recipes.obsidianPen = pen({ color = Color3.fromRGB(8, 8, 10), material = Enum.Material.Glass, reflectance = 0.3 }, GOLD)
recipes.quillPen = function(parent, felt)
	part(parent, "cylinder", Vector3.new(0.9, 0.04, 0.04), CFrame.new(0, 0.02, 0) * CFrame.Angles(0, math.rad(30), 0), BONE)
	part(parent, "wedge", Vector3.new(0.02, 0.18, 0.5), CFrame.new(-0.2, 0.1, -0.12) * CFrame.Angles(0, math.rad(120), 0), BONE)
end
recipes.wallet = function(parent, felt)
	part(parent, "block", Vector3.new(0.62, 0.12, 0.42), CFrame.new(0, 0.06, 0), LEATHER)
	part(parent, "block", Vector3.new(0.06, 0.02, 0.4), CFrame.new(-0.2, 0.13, 0), GOLD)
end
recipes.handbag = function(parent, felt)
	part(parent, "block", Vector3.new(0.6, 0.34, 0.24), CFrame.new(0, 0.17, 0), BLACK)
	part(parent, "block", Vector3.new(0.5, 0.04, 0.04), CFrame.new(0, 0.5, 0), GOLD)
	part(parent, "block", Vector3.new(0.04, 0.18, 0.04), CFrame.new(-0.24, 0.42, 0), GOLD)
	part(parent, "block", Vector3.new(0.04, 0.18, 0.04), CFrame.new(0.24, 0.42, 0), GOLD)
	part(parent, "block", Vector3.new(0.12, 0.08, 0.02), CFrame.new(0, 0.2, -0.13), GOLD)
end
recipes.headphones = function(parent, felt)
	for _, x in { -0.32, 0.32 } do
		part(parent, "cylinder", Vector3.new(0.12, 0.36, 0.36), CFrame.new(x, 0.18, 0), BLACK)
		disc(parent, 0.3, 0.02, CFrame.new(x, 0.18, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD)
	end
	for i = 0, 4 do
		local a = math.rad(-60 + i * 30)
		part(parent, "block", Vector3.new(0.18, 0.05, 0.06), CFrame.new(math.sin(a) * 0.34, 0.2 + math.cos(a) * 0.34, 0) * CFrame.Angles(0, 0, -a), BLACK)
	end
end
recipes.lighter = function(parent, felt)
	part(parent, "block", Vector3.new(0.26, 0.36, 0.1), CFrame.new(0, 0.18, 0), STEEL)
	part(parent, "block", Vector3.new(0.26, 0.1, 0.1), CFrame.new(0, 0.42, -0.03) * CFrame.Angles(math.rad(-20), 0, 0), STEEL)
end
recipes.hallowsLantern = function(parent, felt)
	part(parent, "block", Vector3.new(0.34, 0.4, 0.34), CFrame.new(0, 0.22, 0), { color = Color3.fromRGB(255, 160, 70), material = Enum.Material.Glass, reflectance = 0.1, transparency = 0.4 })
	part(parent, "block", Vector3.new(0.4, 0.04, 0.4), CFrame.new(0, 0.02, 0), BLACK)
	part(parent, "block", Vector3.new(0.4, 0.06, 0.4), CFrame.new(0, 0.45, 0), BLACK)
	part(parent, "block", Vector3.new(0.04, 0.16, 0.04), CFrame.new(0, 0.56, 0), BLACK)
end
recipes.wrappedBox = function(parent, felt)
	part(parent, "block", Vector3.new(0.5, 0.36, 0.5), CFrame.new(0, 0.18, 0), { color = Color3.fromRGB(20, 40, 34), material = Enum.Material.Fabric })
	part(parent, "block", Vector3.new(0.52, 0.38, 0.1), CFrame.new(0, 0.18, 0), GOLD)
	part(parent, "block", Vector3.new(0.1, 0.38, 0.52), CFrame.new(0, 0.18, 0), GOLD)
	part(parent, "ball", Vector3.new(0.16, 0.1, 0.16), CFrame.new(0, 0.4, 0), GOLD)
end
recipes.linenFan = function(parent, felt)
	for i = 0, 6 do
		local a = math.rad(-45 + i * 15)
		part(parent, "block", Vector3.new(0.1, 0.02, 0.7), CFrame.new(0, 0.01 + i * 0.004, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.35), BONE)
	end
	part(parent, "ball", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, 0.04, 0), GOLD)
end
recipes.hipFlask = function(parent, felt) -- Brass Compass
	disc(parent, 0.5, 0.12, CFrame.new(0, 0.06, 0), { color = Color3.fromRGB(190, 150, 80), material = Enum.Material.Metal, reflectance = 0.35 })
	disc(parent, 0.4, 0.02, CFrame.new(0, 0.13, 0), BONE)
	part(parent, "block", Vector3.new(0.03, 0.01, 0.3), CFrame.new(0, 0.145, 0) * CFrame.Angles(0, math.rad(30), 0), { color = Color3.fromRGB(180, 40, 40), material = Enum.Material.SmoothPlastic })
	disc(parent, 0.4, 0.02, CFrame.new(0, 0.16, 0), GLASS)
end
recipes.champagneCoupe = function(parent, felt) -- Crystal Hourglass
	disc(parent, 0.34, 0.04, CFrame.new(0, 0.02, 0), GOLD)
	disc(parent, 0.34, 0.04, CFrame.new(0, 0.6, 0), GOLD)
	part(parent, "ball", Vector3.new(0.26, 0.28, 0.26), CFrame.new(0, 0.18, 0), GLASS)
	part(parent, "ball", Vector3.new(0.26, 0.28, 0.26), CFrame.new(0, 0.44, 0), GLASS)
	for _, x in { -0.14, 0.14 } do
		part(parent, "cylinder", Vector3.new(0.56, 0.03, 0.03), upright(x, 0.31, 0), GOLD)
	end
end

local function stone(color: Color3, size: number)
	return function(parent: Model, felt: Look)
		cutStone(parent, size, CFrame.new(0, size * 0.4, 0), gem(color))
	end
end
recipes.looseDiamond = stone(Color3.fromRGB(240, 246, 255), 0.36)
recipes.emeraldGem = stone(Color3.fromRGB(40, 170, 90), 0.34)
recipes.rubyGem = stone(Color3.fromRGB(200, 30, 50), 0.34)
recipes.sapphireGem = stone(Color3.fromRGB(30, 60, 200), 0.34)
recipes.iceCrystal = function(parent, felt)
	local ice = gem(Color3.fromRGB(210, 236, 255))
	part(parent, "block", Vector3.new(0.12, 0.5, 0.12), CFrame.new(0, 0.25, 0) * CFrame.Angles(math.rad(8), 0, math.rad(-6)), ice)
	part(parent, "block", Vector3.new(0.1, 0.34, 0.1), CFrame.new(0.12, 0.17, 0.06) * CFrame.Angles(math.rad(-10), 0, math.rad(22)), ice)
	part(parent, "block", Vector3.new(0.08, 0.26, 0.08), CFrame.new(-0.1, 0.13, -0.06) * CFrame.Angles(math.rad(12), 0, math.rad(-25)), ice)
end
recipes.blackDiamond = stone(Color3.fromRGB(12, 12, 16), 0.4)
recipes.vipCard = function(parent, felt)
	part(parent, "block", Vector3.new(0.7, 0.03, 0.44), CFrame.new(0, 0.015, 0), BLACK)
	part(parent, "block", Vector3.new(0.5, 0.01, 0.04), CFrame.new(0, 0.035, -0.06), GOLD)
	part(parent, "block", Vector3.new(0.3, 0.01, 0.03), CFrame.new(-0.1, 0.035, 0.06), GOLD)
end
recipes.chessKing = function(parent, felt)
	disc(parent, 0.4, 0.08, CFrame.new(0, 0.04, 0), GOLD)
	part(parent, "cylinder", Vector3.new(0.5, 0.18, 0.18), upright(0, 0.33, 0), GOLD)
	part(parent, "ball", Vector3.new(0.24, 0.16, 0.24), CFrame.new(0, 0.6, 0), GOLD)
	part(parent, "block", Vector3.new(0.05, 0.16, 0.05), CFrame.new(0, 0.76, 0), GOLD)
	part(parent, "block", Vector3.new(0.14, 0.04, 0.05), CFrame.new(0, 0.78, 0), GOLD)
end
recipes.casinoPlaque = function(parent, felt) -- Commemorative Medal
	part(parent, "block", Vector3.new(0.3, 0.02, 0.5), CFrame.new(0, 0.01, 0.2), VELVET)
	disc(parent, 0.42, 0.06, CFrame.new(0, 0.03, -0.1), GOLD)
	disc(parent, 0.3, 0.01, CFrame.new(0, 0.065, -0.1), { color = Color3.fromRGB(160, 120, 50), material = Enum.Material.Metal, reflectance = 0.2 })
end
recipes.objetEgg = function(parent, felt)
	disc(parent, 0.3, 0.06, CFrame.new(0, 0.03, 0), GOLD)
	part(parent, "ball", Vector3.new(0.4, 0.54, 0.4), CFrame.new(0, 0.34, 0), { color = Color3.fromRGB(30, 60, 120), material = Enum.Material.Glass, reflectance = 0.4 })
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		part(parent, "ball", Vector3.new(0.05, 0.05, 0.05), CFrame.new(math.cos(a) * 0.19, 0.34, math.sin(a) * 0.19), GOLD)
	end
end
recipes.crystalSkull = function(parent, felt)
	part(parent, "ball", Vector3.new(0.4, 0.36, 0.42), CFrame.new(0, 0.28, 0), GLASS)
	part(parent, "block", Vector3.new(0.26, 0.16, 0.2), CFrame.new(0, 0.1, 0.06), GLASS)
	for _, x in { -0.08, 0.08 } do
		part(parent, "ball", Vector3.new(0.1, 0.1, 0.06), CFrame.new(x, 0.3, 0.18), BLACK)
	end
end
recipes.glassOrnament = function(parent, felt)
	part(parent, "ball", Vector3.new(0.42, 0.42, 0.42), CFrame.new(0, 0.21, 0), { color = Color3.fromRGB(160, 30, 40), material = Enum.Material.Glass, reflectance = 0.5, transparency = 0.1 })
	part(parent, "cylinder", Vector3.new(0.08, 0.1, 0.1), upright(0, 0.45, 0), GOLD)
end

function PieceModels.has(id: string): boolean
	return recipes[id] ~= nil
end

-- Builds the piece as a Model. `feltColour` is the colour behind ring holes.
function PieceModels.build(id: string, feltColour: Color3?): Model
	local model = Instance.new("Model")
	model.Name = id
	local recipe = recipes[id]
	local felt: Look = { color = feltColour or Color3.fromRGB(16, 17, 20), material = Enum.Material.Fabric }
	if recipe then
		recipe(model, felt)
	else
		part(model, "block", Vector3.new(0.5, 0.2, 0.5), CFrame.new(0, 0.1, 0), GOLD)
	end

	local cf, size = model:GetBoundingBox()
	local hit = Instance.new("Part")
	hit.Name = "Hit"
	hit.Size = Vector3.new(math.max(size.X, 0.6), math.max(size.Y, 0.3), math.max(size.Z, 0.6))
	hit.CFrame = cf
	hit.Transparency = 1
	hit.Anchored = true
	hit.CanCollide = false
	hit.CanQuery = true
	hit.CanTouch = false
	hit.CastShadow = false
	hit.Parent = model
	model.PrimaryPart = hit
	return model
end

-- A gilded variant shimmers: parts get a touch more reflectance and a warm tint.
function PieceModels.gild(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "Hit" then
			d.Reflectance = math.min(1, d.Reflectance + 0.25)
			d.Color = d.Color:Lerp(Color3.fromRGB(236, 216, 166), 0.35)
		end
	end
end

function PieceModels.allIds(): { string }
	local ids = {}
	for _, p in Catalogue.Core do
		table.insert(ids, p.id)
	end
	for _, p in Catalogue.Seasonal do
		table.insert(ids, p.id)
	end
	for _, p in Catalogue.Mythic do
		table.insert(ids, p.id)
	end
	return ids
end

return PieceModels

--!strict
-- The Terrace bar's menu: snacks and drinks (none of them alcoholic), each with exactly what it
-- is, what it costs and what it does. The everyday menu is bought with Gilt; three "house
-- specials" are bought with Robux, at the price shown, and are the same kind of thing made grand
-- (gold leaf, a glow, a tower, a platter to share). Nothing on the menu is random, nothing changes
-- a score, and nothing gives Gilt: you hold it, enjoy it, and it's gone.
--
-- A guest holds one treat at a time, in their right hand, seen by everyone. Each one lasts a
-- number of sips or bites (`servings`), one every few seconds, then it's finished.
--
-- Also how a treat looks in the hand (BarMenu.build), used by the server to make it.

local BarMenu = {}

local rgb = Color3.fromRGB

export type Look = "glass" | "tall" | "cup" | "cone" | "plate" | "tower" | "platter" | "bowl"
export type Item = {
	id: string,
	name: string,
	kind: "drink" | "snack",
	line: string, -- exactly what it is
	gilt: number?, -- the price in Gilt (the everyday menu)
	product: string?, -- the ProductConfig key it's bought with (the house specials)
	robux: number?, -- the reference price in Robux (Roblox's own price is shown when it has one)
	look: Look,
	colour: Color3, -- the drink, or the food's main colour
	accent: Color3, -- the garnish, the glaze
	servings: number, -- sips or bites
	glow: boolean?, -- a soft gold light, and sparkles
	share: boolean?, -- the platter: guests close by are each handed a sweet
}

BarMenu.Items = {
	-- Drinks
	{ id = "lemonade", name = "Sparkling Lemonade", kind = "drink", line = "Pressed lemons, cane sugar and soda, over ice.", gilt = 25, look = "tall", colour = rgb(250, 232, 140), accent = rgb(250, 220, 60), servings = 6 },
	{ id = "hibiscus", name = "Iced Hibiscus Tea", kind = "drink", line = "Hibiscus and rosehip, cold-brewed, with a slice of orange.", gilt = 25, look = "tall", colour = rgb(170, 30, 60), accent = rgb(250, 150, 40), servings = 6 },
	{ id = "smash", name = "Mint & Lime Smash", kind = "drink", line = "Muddled mint and lime, soda and crushed ice. No alcohol.", gilt = 35, look = "glass", colour = rgb(200, 236, 190), accent = rgb(60, 150, 70), servings = 6 },
	{ id = "tonic", name = "Espresso Tonic", kind = "drink", line = "A double espresso poured over tonic and ice.", gilt = 35, look = "glass", colour = rgb(120, 70, 40), accent = rgb(230, 210, 170), servings = 5 },
	{ id = "cocoa", name = "Hot Chocolate", kind = "drink", line = "Dark chocolate melted into warm milk, a cloud of cream on top.", gilt = 30, look = "cup", colour = rgb(90, 50, 30), accent = rgb(250, 246, 236), servings = 5 },
	-- Snacks
	{ id = "fries", name = "Truffle Fries", kind = "snack", line = "Thin fries, parmesan and truffle salt, in a paper cup.", gilt = 40, look = "cone", colour = rgb(236, 196, 100), accent = rgb(240, 236, 224), servings = 6 },
	{ id = "macarons", name = "Three Macarons", kind = "snack", line = "Raspberry, pistachio and vanilla.", gilt = 45, look = "plate", colour = rgb(236, 120, 150), accent = rgb(170, 210, 140), servings = 3 },
	{ id = "strawberries", name = "Chocolate Strawberries", kind = "snack", line = "Five strawberries, half dipped in dark chocolate.", gilt = 50, look = "bowl", colour = rgb(200, 30, 40), accent = rgb(60, 34, 24), servings = 5 },
	-- The house specials (Robux)
	{ id = "goldSpritz", name = "The Gold-Leaf Spritz", kind = "drink", line = "Sparkling white grape and elderflower with flakes of gold leaf, in a glass that glows. No alcohol.", product = "barGoldSpritz", robux = 25, look = "glass", colour = rgb(250, 226, 150), accent = rgb(255, 200, 80), servings = 8, glow = true },
	{ id = "tower", name = "The Macaron Tower", kind = "snack", line = "Twelve macarons stacked in a gold tower, with sparkles while you hold it.", product = "barMacaronTower", robux = 49, look = "tower", colour = rgb(236, 120, 150), accent = rgb(255, 214, 120), servings = 12, glow = true },
	{ id = "platter", name = "The Grand Platter", kind = "snack", line = "A silver platter of sweets you carry for everyone: each guest near you is handed a macaron, free.", product = "barGrandPlatter", robux = 99, look = "platter", colour = rgb(236, 120, 150), accent = rgb(200, 200, 210), servings = 10, glow = true, share = true },
} :: { Item }

BarMenu.byId = {} :: { [string]: Item }
BarMenu.byProduct = {} :: { [string]: Item }
for _, item in BarMenu.Items do
	BarMenu.byId[item.id] = item
	if item.product then
		BarMenu.byProduct[item.product] = item
	end
end

-- The treat a guest is handed from someone's platter.
BarMenu.Shared = { id = "sharedMacaron", name = "A Macaron", kind = "snack", line = "From someone's Grand Platter.", look = "plate", colour = rgb(170, 210, 140), accent = rgb(250, 246, 236), servings = 1 } :: Item

---------------------------------------------------------------------------------------------------
-- How a treat looks in the hand: a model of small parts around a "Handle" (held at its centre)
---------------------------------------------------------------------------------------------------
local function part(model: Model, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, transparency: number?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Transparency = transparency or 0
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- An upright cylinder (Roblox's cylinders run along X).
local function column(model: Model, name: string, height: number, width: number, at: Vector3, colour: Color3, material: Enum.Material, transparency: number?): Part
	return part(model, name, Vector3.new(height, width, width), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), colour, material, transparency, Enum.PartType.Cylinder)
end

local GLASS = rgb(230, 236, 240)
local GOLD = rgb(214, 172, 80)

-- Builds the treat at the origin (the handle at the origin, the treat standing up). Welding the
-- parts together is left to the caller (it knows what they're held by).
function BarMenu.build(item: Item): Model
	local m = Instance.new("Model")
	m.Name = "Treat"
	local handle = part(m, "Handle", Vector3.new(0.3, 0.3, 0.3), CFrame.new(), GLASS, Enum.Material.SmoothPlastic, 1)
	m.PrimaryPart = handle
	local look = item.look
	if look == "tall" then
		column(m, "Glass", 1.3, 0.55, Vector3.new(0, 0.2, 0), GLASS, Enum.Material.Glass, 0.6)
		column(m, "Drink", 1.1, 0.48, Vector3.new(0, 0.12, 0), item.colour, Enum.Material.Glass, 0.15)
		part(m, "Slice", Vector3.new(0.08, 0.38, 0.38), CFrame.new(0.24, 0.82, 0) * CFrame.Angles(0, 0, math.rad(90)), item.accent, Enum.Material.SmoothPlastic, 0, Enum.PartType.Cylinder)
		column(m, "Straw", 0.9, 0.06, Vector3.new(-0.1, 0.95, 0.05), rgb(250, 250, 250), Enum.Material.SmoothPlastic)
	elseif look == "glass" then
		column(m, "Stem", 0.55, 0.08, Vector3.new(0, -0.25, 0), GLASS, Enum.Material.Glass, 0.4)
		column(m, "Foot", 0.04, 0.4, Vector3.new(0, -0.52, 0), GLASS, Enum.Material.Glass, 0.4)
		part(m, "Bowl", Vector3.new(0.62, 0.62, 0.62), CFrame.new(0, 0.28, 0), GLASS, Enum.Material.Glass, 0.6, Enum.PartType.Ball)
		part(m, "Drink", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.22, 0), item.colour, Enum.Material.Glass, 0.15, Enum.PartType.Ball)
		part(m, "Garnish", Vector3.new(0.16, 0.16, 0.16), CFrame.new(0.2, 0.55, 0), item.accent, Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
	elseif look == "cup" then
		column(m, "Cup", 0.7, 0.6, Vector3.new(0, 0.05, 0), rgb(246, 242, 234), Enum.Material.SmoothPlastic)
		column(m, "Drink", 0.04, 0.52, Vector3.new(0, 0.39, 0), item.colour, Enum.Material.SmoothPlastic)
		part(m, "Cream", Vector3.new(0.42, 0.24, 0.42), CFrame.new(0, 0.46, 0), item.accent, Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
		part(m, "Saucer", Vector3.new(0.04, 0.85, 0.85), CFrame.new(0, -0.31, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(246, 242, 234), Enum.Material.SmoothPlastic, 0, Enum.PartType.Cylinder)
	elseif look == "cone" then
		column(m, "Cone", 0.8, 0.55, Vector3.new(0, 0.05, 0), rgb(250, 248, 240), Enum.Material.SmoothPlastic)
		column(m, "Band", 0.2, 0.57, Vector3.new(0, 0.1, 0), rgb(20, 18, 20), Enum.Material.SmoothPlastic)
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			part(m, "Fry", Vector3.new(0.07, 0.5, 0.07), CFrame.new(math.cos(a) * 0.13, 0.6, math.sin(a) * 0.13) * CFrame.Angles(math.sin(a) * 0.2, 0, math.cos(a) * 0.2), item.colour, Enum.Material.SmoothPlastic)
		end
	elseif look == "plate" or look == "bowl" then
		local wide = if look == "plate" then 1.0 else 0.8
		part(m, "Dish", Vector3.new(0.06, wide, wide), CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), rgb(246, 242, 234), Enum.Material.SmoothPlastic, 0, Enum.PartType.Cylinder)
		local n = if item.servings > 1 then math.min(item.servings, 5) else 1
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			local r = if n == 1 then 0 else 0.22
			local colour = if look == "plate" and i % 2 == 0 then item.accent else item.colour
			part(m, "Bite" .. i, Vector3.new(0.24, 0.14, 0.24), CFrame.new(math.cos(a) * r, 0.06, math.sin(a) * r), colour, Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
			if look == "bowl" then
				part(m, "Dip" .. i, Vector3.new(0.15, 0.08, 0.15), CFrame.new(math.cos(a) * r, 0.14, math.sin(a) * r), item.accent, Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
			end
		end
	elseif look == "tower" then
		part(m, "Base", Vector3.new(0.06, 0.9, 0.9), CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal, 0, Enum.PartType.Cylinder)
		local colours = { item.colour, rgb(170, 210, 140), rgb(250, 240, 210), rgb(190, 150, 220) }
		for i = 0, 5 do
			local w = 0.7 - i * 0.09
			part(m, "Tier" .. i, Vector3.new(0.17, w, w), CFrame.new(0, 0.08 + i * 0.17, 0) * CFrame.Angles(0, 0, math.rad(90)), colours[i % #colours + 1], Enum.Material.SmoothPlastic, 0, Enum.PartType.Cylinder)
		end
		part(m, "Top", Vector3.new(0.14, 0.14, 0.14), CFrame.new(0, 1.12, 0), item.accent, Enum.Material.Neon, 0, Enum.PartType.Ball)
	elseif look == "platter" then
		part(m, "Platter", Vector3.new(0.06, 1.7, 1.7), CFrame.new(0, -0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), item.accent, Enum.Material.Metal, 0, Enum.PartType.Cylinder)
		part(m, "Rim", Vector3.new(0.1, 1.8, 1.8), CFrame.new(0, -0.08, 0) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Metal, 0, Enum.PartType.Cylinder)
		local colours = { item.colour, rgb(170, 210, 140), rgb(250, 240, 210), rgb(190, 150, 220), rgb(250, 200, 120) }
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local r = if i % 2 == 0 then 0.6 else 0.35
			part(m, "Sweet" .. i, Vector3.new(0.22, 0.13, 0.22), CFrame.new(math.cos(a) * r, 0.06, math.sin(a) * r), colours[i % #colours + 1], Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
		end
	end
	if item.glow then
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Brightness = 1.2
		light.Range = 7
		light.Color = rgb(255, 210, 130)
		light.Shadows = false
		light.Parent = handle
		pcall(function() -- (sparkles are only a flourish)
			local sparkle = Instance.new("ParticleEmitter")
			sparkle.Name = "Sparkle"
			sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			sparkle.Color = ColorSequence.new(rgb(255, 226, 150))
			sparkle.LightEmission = 1
			sparkle.Size = NumberSequence.new(0.18, 0)
			sparkle.Lifetime = NumberRange.new(0.6, 1.1)
			sparkle.Rate = 6
			sparkle.Speed = NumberRange.new(0.4, 1)
			sparkle.SpreadAngle = Vector2.new(180, 180)
			sparkle.Parent = handle
		end)
	end
	m:SetAttribute("TreatId", item.id)
	m:SetAttribute("Servings", item.servings)
	return m
end

return BarMenu

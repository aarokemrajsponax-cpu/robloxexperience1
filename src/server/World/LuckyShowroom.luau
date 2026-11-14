--!strict
-- The Luxe Lucky Box showroom in the Grand Ballroom's Entrance Hall, among its entertainments and
-- in sight of the doors (shared Gala.LUCKY), built half again as large for the great hall: a black
-- marble dais ringed in gold light, three pedestals, and on each a gift box in its own colours
-- (the Gilded, the Noir raised in the middle, the Velvet), ribboned and bowed, glowing and
-- sparkling, under a velvet backdrop that names them. The boxes turn and float on each guest's
-- screen (World/LuckyShowroom on the client, tag "LuckyBoxSpin"). The prompt opens the showroom's
-- panel, where every box's odds are shown beside its price; a guest Roblox's policy restricts
-- from paid random items never sees the prompt.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local LuckyBoxes = require(ReplicatedStorage.Shared.LuckyBoxes)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local GOLD = { color = Color3.fromRGB(214, 168, 72), material = Enum.Material.Metal, reflectance = 0.28 }
local GLOW = { color = Color3.fromRGB(255, 200, 110), material = Enum.Material.Neon, transparency = 0.25 }
local FX = { collide = false, query = false, shadow = false }

local Showroom = {}

-- Where each box stands, across the dais (x: positive is the guests' left, as they face it),
-- forward (z, negative is towards the guests), and how much higher its pedestal is.
local SPOTS = {
	gilded = { x = 3.1, z = -0.1, lift = 0 },
	noir = { x = 0, z = 0.8, lift = 0.7 },
	velvet = { x = -3.1, z = -0.1, lift = 0 },
}

local function look(c: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Kit.Look
	return { color = c, material = material, reflectance = reflectance, transparency = transparency }
end

-- A box's own body: gold leaf, crimson velvet, or black lacquer.
local function bodyLook(id: string, colour: Color3): Kit.Look
	if id == "gilded" then
		return look(colour, Enum.Material.SmoothPlastic, 0.12)
	elseif id == "velvet" then
		return look(colour, Enum.Material.Fabric)
	end
	return look(colour, Enum.Material.SmoothPlastic, 0.35)
end

-- One gift box, centred on `cf` (its middle), as its own model for the screen to turn.
local function giftBox(parent: Instance, id: string, cf: CFrame): Model
	local b = LuckyBoxes.Boxes[id]
	local m = Kit.model(parent, "LuckyBox_" .. id)
	local body = bodyLook(id, b.colour)
	local ribbon = look(b.ribbon, if id == "velvet" then Enum.Material.Metal else Enum.Material.SmoothPlastic, if id == "velvet" then 0.3 else 0.1)
	local core = Kit.part(m, "Body", Vector3.new(2, 1.6, 2), cf, body, FX)
	Kit.part(m, "Lid", Vector3.new(2.24, 0.46, 2.24), cf * CFrame.new(0, 1.02, 0), body, FX)
	-- The ribbon: round the body and over the lid, both ways.
	Kit.part(m, "RibbonX", Vector3.new(2.04, 1.62, 0.34), cf, ribbon, FX)
	Kit.part(m, "RibbonZ", Vector3.new(0.34, 1.62, 2.04), cf, ribbon, FX)
	Kit.part(m, "LidRibbonX", Vector3.new(2.28, 0.48, 0.34), cf * CFrame.new(0, 1.02, 0), ribbon, FX)
	Kit.part(m, "LidRibbonZ", Vector3.new(0.34, 0.48, 2.28), cf * CFrame.new(0, 1.02, 0), ribbon, FX)
	-- The bow: two loops leaning out from a knot.
	for _, side in { -1, 1 } do
		Kit.cylinder(m, "BowLoop", 0.34, 0.9, cf * CFrame.new(side * 0.38, 1.55, 0) * CFrame.Angles(0, 0, math.rad(side * 35)), ribbon, FX)
		Kit.part(m, "BowTail", Vector3.new(0.22, 0.05, 0.7), cf * CFrame.new(side * 0.3, 1.27, -0.55) * CFrame.Angles(math.rad(-20), math.rad(side * 25), 0), ribbon, FX)
	end
	Kit.ball(m, "BowKnot", 0.42, (cf * CFrame.new(0, 1.42, 0)).Position, ribbon, FX)
	-- Its glow: a light inside, and a little shower of sparkles in its colour.
	-- (Only the Noir, in the middle, carries a light: the Ballroom keeps to its budget of lights.
	-- The others glow by their neon caps and their sparkles.)
	if id == "noir" then
		local light = Instance.new("PointLight")
		light.Brightness = 2.4
		light.Range = 15
		light.Color = b.glow
		light.Shadows = false
		light.Parent = core
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(b.glow, Color3.new(1, 1, 1))
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Rate = 7
	sparkle.Lifetime = NumberRange.new(1.2, 2.2)
	sparkle.Speed = NumberRange.new(0.4, 1.4)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.32), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	sparkle.Parent = core
	m.PrimaryPart = core
	m:SetAttribute("Box", id)
	CollectionService:AddTag(m, "LuckyBoxSpin")
	return m
end

-- Its pedestal: a lacquered column on a gold foot, a gold cap with a ring of light, and the name.
local function pedestal(parent: Instance, id: string, base: CFrame, height: number): CFrame
	local b = LuckyBoxes.Boxes[id]
	local up = CFrame.Angles(0, 0, math.rad(90))
	Kit.cylinder(parent, "PedestalFoot", 0.3, 2.3, base * CFrame.new(0, 0.15, 0) * up, GOLD)
	Kit.cylinder(parent, "Pedestal", height, 1.7, base * CFrame.new(0, 0.3 + height / 2, 0) * up, L.blackLacquer)
	Kit.cylinder(parent, "PedestalBand", 0.12, 1.78, base * CFrame.new(0, 0.3 + height * 0.72, 0) * up, GOLD, FX)
	local top = 0.3 + height
	Kit.cylinder(parent, "PedestalCap", 0.22, 2.3, base * CFrame.new(0, top + 0.11, 0) * up, GOLD)
	Kit.cylinder(parent, "CapGlow", 0.04, 2.5, base * CFrame.new(0, top + 0.02, 0) * up, look(b.glow, Enum.Material.Neon, nil, 0.2), FX)
	-- The name, on the pedestal's front (the guests' side is -Z).
	local plate = Kit.part(parent, "NamePlate", Vector3.new(1.5, 0.62, 0.05), base * CFrame.new(0, 0.3 + height * 0.42, -0.87), L.ink, FX)
	Kit.engrave(plate, Enum.NormalId.Front, {
		{ text = string.upper(b.short), size = 0.46, font = Brand.Fonts.display, color = b.glow },
		{ text = b.line, size = 0.24, font = Brand.Fonts.bodyBold, color = Color3.fromRGB(236, 226, 206) },
	}, { ppu = 120, lit = false, brightness = 1.8 })
	return base * CFrame.new(0, top + 0.22, 0)
end

-- Grows everything built about `base` by `k`: each part's size and its place from the middle,
-- and each light's reach and each sparkle's size with it.
local function grow(m: Instance, base: CFrame, k: number)
	if k == 1 then
		return
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local rel = base:ToObjectSpace(d.CFrame)
			d.Size = d.Size * k
			d.CFrame = base * (rel - rel.Position + rel.Position * k)
		elseif d:IsA("PointLight") or d:IsA("SpotLight") then
			(d :: any).Range *= k
		elseif d:IsA("ParticleEmitter") then
			local keys = {}
			for _, kp in d.Size.Keypoints do
				table.insert(keys, NumberSequenceKeypoint.new(kp.Time, kp.Value * k))
			end
			d.Size = NumberSequence.new(keys)
		end
	end
end

-- Builds the showroom standing on the floor at `at` (its front facing the way `at` looks), `k`
-- times its drawn size.
function Showroom.build(parent: Instance, at: CFrame, k: number?): Model
	local cf = at
	local m = Kit.model(parent, "LuckyShowroom")
	local up = CFrame.Angles(0, 0, math.rad(90))
	-- The dais, its gold rim and the ring of light at its foot.
	Kit.cylinder(m, "DaisGlow", 0.06, 10.8, cf * CFrame.new(0, 0.03, 0) * up, GLOW, FX)
	Kit.cylinder(m, "DaisRim", 0.34, 10.3, cf * CFrame.new(0, 0.17, 0) * up, GOLD)
	Kit.cylinder(m, "Dais", 0.5, 9.8, cf * CFrame.new(0, 0.25, 0) * up, L.blackMarble)
	Kit.cylinder(m, "DaisInlay", 0.02, 3.2, cf * CFrame.new(0, 0.51, -2.6) * up, look(Color3.fromRGB(196, 150, 70), Enum.Material.Metal, 0.3), FX)
	local deck = cf * CFrame.new(0, 0.5, 0)

	-- The backdrop: crimson velvet in a gold frame, standing on the floor behind the dais, the name
	-- across its top (above the boxes, so they never hide it) and a jewel in a gold crest.
	local back = cf * CFrame.new(0, 5.2, 4)
	Kit.part(m, "Backdrop", Vector3.new(8.6, 10.4, 0.4), back, L.deepVelvet)
	for _, s in { { 0, 5.2, 9, 0.3 }, { 0, -5.05, 9, 0.3 }, { -4.4, 0, 0.3, 10.6 }, { 4.4, 0, 0.3, 10.6 }, { 0, 1.15, 8.6, 0.12 } } do
		Kit.part(m, "BackdropFrame", Vector3.new(s[3], s[4], 0.5), back * CFrame.new(s[1], s[2], 0), GOLD)
	end
	Kit.cylinder(m, "Crest", 0.4, 1.9, back * CFrame.new(0, 5.9, 0) * CFrame.Angles(0, math.rad(90), 0), GOLD)
	Kit.ball(m, "CrestJewel", 0.6, (back * CFrame.new(0, 5.9, -0.25)).Position, look(Color3.fromRGB(255, 120, 160), Enum.Material.Neon, nil, 0.1), FX)
	local title = Kit.part(m, "Title", Vector3.new(8, 3.4, 0.05), back * CFrame.new(0, 3.2, -0.24), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, FX)
	Kit.engrave(title, Enum.NormalId.Front, {
		{ text = "LUXE", size = 0.2, font = Brand.Fonts.heavy, color = Color3.fromRGB(255, 226, 150) },
		{ text = "LUCKY BOXES", size = 0.4, font = Brand.Fonts.display, color = Brand.Colours.brightGold },
		{ text = "A brainrot in every box  ·  Every odd shown first", size = 0.13, font = Brand.Fonts.bodyBold, color = Color3.fromRGB(236, 226, 206) },
	}, { ppu = 60, lit = false, brightness = 1.9, maxDistance = 160 })
	-- One light on all three boxes from above the backdrop (two lights in all: the Ballroom's budget).
	local lamp = Kit.part(m, "ShowLight", Vector3.new(0.4, 0.4, 0.4), deck * CFrame.new(0, 9.6, -1.2), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, FX)
	Kit.spotLight(lamp, Enum.NormalId.Bottom, 3, 16, 90, Color3.fromRGB(255, 228, 190), false)

	-- The three boxes on their pedestals.
	for _, id in LuckyBoxes.Order do
		local s = SPOTS[id]
		local top = pedestal(m, id, deck * CFrame.new(s.x, 0, s.z), 2.4 + s.lift)
		giftBox(m, id, top * CFrame.new(0, 1.25, 0))
	end

	-- The way in: a prompt at the middle pedestal.
	local hub = Kit.part(m, "PromptPoint", Vector3.new(1, 1, 1), deck * CFrame.new(0, 2, -2.2), { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }, FX)
	local p = Instance.new("ProximityPrompt")
	p.Name = "LuckyBoxPrompt"
	p.ActionText = "See the boxes"
	p.ObjectText = "Luxe Lucky Boxes"
	p.HoldDuration = 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Enabled = false -- (each guest's screen turns it on when Roblox's policy allows: see the client)
	p.Parent = hub
	grow(m, cf, k or 1)
	p.MaxActivationDistance = 12 * (k or 1)
	CollectionService:AddTag(m, "LuckyShowroom")
	return m
end

return Showroom

--!strict
-- Luxury Island on a guest's own screen (shared/Island has the plan; the server builds it and keeps
-- every reward):
--   The island's light  while they're on it, the sky, the sun, the haze, the bloom and the grade of
--                       the light they chose (Golden Hour, Azure Noon, Rosé Dawn, Moonlit), and the
--                       house's own light put back exactly when they leave
--   The day's pearls    each one still to find, a pearl in an open shell with a column of bubbles
--                       rising from it; swim down beside one and it's brought up (the server
--                       decides, from where it truly sees them)
--   The jets            theirs on the airstrip in their livery; the Jet Gallery's models in theirs
--   The flight          a few seconds in the jet's cabin, clouds streaming past the windows, while
--                       the island (or the house) is made ready around them; any key skips it
-- Only this screen sees any of it.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Plan = require(ReplicatedStorage.Shared.Island)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sound = require(script.Parent.Parent.Sound)

local IslandView = {}

-- Set by Main: a notice on screen, and the island's state changed (the HUD redraws).
IslandView.notice = function(_title: string, _line: string, _seconds: number?) end
IslandView.changed = function(_state: { [string]: any }) end
-- Set by Main: the screen's keys and cards step aside for the flight, and come back after it.
IslandView.cinematic = function(_on: boolean) end

local player = Players.LocalPlayer
local rgb = Color3.fromRGB

local function origin(): Vector3
	local o = ((Config.data :: any).Attractions.island or {}).origin
	if type(o) == "table" then
		return Vector3.new(o[1], o[2], o[3])
	end
	return Vector3.zero
end

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function sound(name: string, volume: number?)
	pcall(Sound.play, name, volume or 0.6)
end

---------------------------------------------------------------------------------------------------
-- The island's light
---------------------------------------------------------------------------------------------------
type Preset = {
	clock: number,
	latitude: number,
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	top: Color3,
	bottom: Color3,
	exposure: number,
	atmo: { density: number, offset: number, colour: Color3, decay: Color3, glare: number, haze: number },
	bloom: { intensity: number, size: number, threshold: number },
	rays: { intensity: number, spread: number },
	grade: { tint: Color3, saturation: number, contrast: number, brightness: number },
	lantern: number, -- the lanterns' transparency (0: lit)
	sun: number, -- the sun's size in the sky
}

local PRESETS: { [string]: Preset } = {
	golden = {
		clock = 17.55, latitude = 24, brightness = 2.7,
		ambient = rgb(118, 92, 82), outdoor = rgb(176, 136, 114), top = rgb(255, 198, 140), bottom = rgb(120, 74, 54), exposure = 0.12,
		atmo = { density = 0.31, offset = 0.22, colour = rgb(255, 202, 168), decay = rgb(255, 122, 86), glare = 0.65, haze = 1.7 },
		bloom = { intensity = 0.85, size = 30, threshold = 0.92 }, rays = { intensity = 0.14, spread = 0.78 },
		grade = { tint = rgb(255, 240, 224), saturation = 0.14, contrast = 0.08, brightness = 0.02 }, lantern = 0.25, sun = 26,
	},
	azure = {
		clock = 13.2, latitude = 18, brightness = 3.1,
		ambient = rgb(120, 130, 142), outdoor = rgb(152, 164, 178), top = rgb(255, 250, 240), bottom = rgb(120, 150, 170), exposure = 0.02,
		atmo = { density = 0.2, offset = 0.08, colour = rgb(206, 228, 255), decay = rgb(150, 192, 240), glare = 0.12, haze = 0.5 },
		bloom = { intensity = 0.55, size = 24, threshold = 0.95 }, rays = { intensity = 0.05, spread = 0.6 },
		grade = { tint = rgb(246, 252, 255), saturation = 0.2, contrast = 0.06, brightness = 0.01 }, lantern = 0.7, sun = 20,
	},
	dawn = {
		clock = 6.35, latitude = 24, brightness = 2.2,
		ambient = rgb(128, 100, 122), outdoor = rgb(170, 132, 152), top = rgb(255, 196, 206), bottom = rgb(130, 90, 120), exposure = 0.1,
		atmo = { density = 0.3, offset = 0.2, colour = rgb(255, 208, 218), decay = rgb(238, 140, 172), glare = 0.5, haze = 1.4 },
		bloom = { intensity = 0.8, size = 30, threshold = 0.92 }, rays = { intensity = 0.12, spread = 0.72 },
		grade = { tint = rgb(255, 238, 242), saturation = 0.1, contrast = 0.05, brightness = 0.02 }, lantern = 0.4, sun = 24,
	},
	moonlit = {
		clock = 0.6, latitude = 24, brightness = 0.7,
		ambient = rgb(64, 74, 106), outdoor = rgb(76, 96, 138), top = rgb(170, 190, 255), bottom = rgb(40, 50, 90), exposure = 0.3,
		atmo = { density = 0.34, offset = 0.14, colour = rgb(124, 144, 196), decay = rgb(72, 92, 152), glare = 0.1, haze = 0.8 },
		bloom = { intensity = 1.0, size = 36, threshold = 0.84 }, rays = { intensity = 0.03, spread = 0.5 },
		grade = { tint = rgb(222, 232, 255), saturation = -0.05, contrast = 0.1, brightness = 0.0 }, lantern = 0, sun = 20,
	},
}
IslandView.PRESETS = PRESETS

local LIGHT_PROPS = { "ClockTime", "GeographicLatitude", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "ExposureCompensation" }
type Saved = { props: { [string]: any }, stash: { Instance } }
local saved: Saved? = nil
local made: { [string]: Instance } = {}
local moonLights: { Instance } = {}
local theme: string? = nil

local function ours(i: Instance): boolean
	return string.sub(i.Name, 1, 6) == "Island" or i.Name == "MaisonPhotoGrade" or i.Name == "MaisonPhotoFocus"
end

-- The house's own sky and effects step aside while the island's are up (put back on leaving).
local function stashHouse(s: Saved)
	for _, c in Lighting:GetChildren() do
		if not ours(c) and (c:IsA("Atmosphere") or c:IsA("Sky") or c:IsA("BloomEffect") or c:IsA("SunRaysEffect") or c:IsA("ColorCorrectionEffect")) then
			table.insert(s.stash, c)
			pcall(function()
				c.Parent = nil
			end)
		end
	end
end

local function effect(class: string, name: string): Instance
	local e = made[name]
	if e and e.Parent == Lighting then
		return e
	end
	local n = Instance.new(class)
	n.Name = name
	n.Parent = Lighting
	made[name] = n
	return n
end

local function setLanterns(p: Preset, id: string)
	for _, l in CollectionService:GetTagged("IslandLantern") do
		if l:IsA("BasePart") then
			l.Transparency = p.lantern
		end
	end
	-- (Moonlit: a few of the lanterns really light the night.)
	if id == "moonlit" and #moonLights == 0 then
		local n = 0
		for i, l in CollectionService:GetTagged("IslandLantern") do
			if l:IsA("BasePart") and i % 3 == 1 and n < 12 then
				local light = Instance.new("PointLight")
				light.Name = "IslandMoonLantern"
				light.Brightness = 1.6
				light.Range = 18
				light.Color = rgb(255, 196, 130)
				light.Shadows = false
				light.Parent = l
				table.insert(moonLights, light)
				n += 1
			end
		end
	elseif id ~= "moonlit" then
		for _, light in moonLights do
			light:Destroy()
		end
		moonLights = {}
	end
end

-- Lights the island in preset `id` (and keeps it so while they're there).
function IslandView.light(id: string)
	local p = PRESETS[id] or PRESETS.golden
	local s = saved
	if not s then
		local fresh: Saved = { props = {}, stash = {} }
		for _, k in LIGHT_PROPS do
			pcall(function()
				fresh.props[k] = (Lighting :: any)[k]
			end)
		end
		saved = fresh
		s = fresh
	end
	stashHouse(s :: Saved)
	local L = Lighting :: any
	pcall(function()
		L.ClockTime = p.clock
		L.GeographicLatitude = p.latitude
		L.Brightness = p.brightness
		L.Ambient = p.ambient
		L.OutdoorAmbient = p.outdoor
		L.ColorShift_Top = p.top
		L.ColorShift_Bottom = p.bottom
		L.ExposureCompensation = p.exposure
	end)
	pcall(function()
		local sky = effect("Sky", "IslandSky") :: any
		sky.SunAngularSize = p.sun
		sky.MoonAngularSize = 14
		sky.StarCount = 3000
		sky.CelestialBodiesShown = true
		local a = effect("Atmosphere", "IslandAtmosphere") :: any
		a.Density, a.Offset, a.Color, a.Decay, a.Glare, a.Haze = p.atmo.density, p.atmo.offset, p.atmo.colour, p.atmo.decay, p.atmo.glare, p.atmo.haze
		local b = effect("BloomEffect", "IslandBloom") :: any
		b.Intensity, b.Size, b.Threshold = p.bloom.intensity, p.bloom.size, p.bloom.threshold
		local r = effect("SunRaysEffect", "IslandRays") :: any
		r.Intensity, r.Spread = p.rays.intensity, p.rays.spread
		local g = effect("ColorCorrectionEffect", "IslandGrade") :: any
		g.TintColor, g.Saturation, g.Contrast, g.Brightness = p.grade.tint, p.grade.saturation, p.grade.contrast, p.grade.brightness
	end)
	setLanterns(p, id)
	theme = id
end

-- The house's own light, exactly as it was.
function IslandView.unlight()
	for _, e in made do
		e:Destroy()
	end
	made = {}
	for _, light in moonLights do
		light:Destroy()
	end
	moonLights = {}
	local s = saved
	if s then
		for k, v in s.props do
			pcall(function()
				(Lighting :: any)[k] = v
			end)
		end
		for _, c in s.stash do
			pcall(function()
				c.Parent = Lighting
			end)
		end
	end
	saved = nil
	theme = nil
end

function IslandView.theme(): string?
	return theme
end

---------------------------------------------------------------------------------------------------
-- The jets in their liveries
---------------------------------------------------------------------------------------------------
local function paint(model: Instance, liveryId: string)
	local l = Plan.liveryById[liveryId] or Plan.liveryById.noir
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local which = d:GetAttribute("Livery")
			if which == "body" then
				d.Color = l.body
				d.Material = if l.id == "sovereign" then Enum.Material.Metal else Enum.Material.SmoothPlastic
				d.Reflectance = if l.id == "sovereign" then 0.25 else 0.12
			elseif which == "trim" then
				d.Color = l.trim
			elseif which == "stripe" then
				d.Color = l.stripe
				d.Material = if l.id == "aurora" then Enum.Material.Neon else Enum.Material.Metal
			end
		end
	end
end
IslandView.paint = paint

local function island(): Instance?
	local a = Workspace:FindFirstChild("Attractions")
	return a and a:FindFirstChild("LuxuryIsland")
end

local function paintAll()
	local isle = island()
	if not isle then
		return
	end
	local strip = isle:FindFirstChild("Airstrip")
	local jet = strip and strip:FindFirstChild("Jet")
	if jet then
		local mine = player:GetAttribute("JetLivery")
		paint(jet, if type(mine) == "string" then mine else "noir")
	end
	local gallery = isle:FindFirstChild("JetGallery")
	if gallery then
		for _, m in gallery:GetChildren() do
			local id = m:GetAttribute("Livery")
			if m.Name == "Jet" and type(id) == "string" and m:GetAttribute("Painted") ~= id then
				paint(m, id)
				m:SetAttribute("Painted", id)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The day's pearls
---------------------------------------------------------------------------------------------------
local pearls: { [number]: Model } = {}
local asking: { [number]: number } = {}
local pearlFolder: Folder? = nil

local function clearPearls()
	for _, m in pearls do
		m:Destroy()
	end
	pearls = {}
end

local function pearlModel(at: Vector3, n: number): Model
	local m = Instance.new("Model")
	m.Name = "IslandPearl"
	m:SetAttribute("Pearl", n)
	local function bit(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, transparency: number?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = material
		p.Transparency = transparency or 0
		p.Parent = m
		return p
	end
	local shell = rgb(246, 226, 222)
	bit("ShellBottom", Vector3.new(2.6, 0.5, 2.4), CFrame.new(at + Vector3.new(0, -0.2, 0)), shell, Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
	bit("ShellTop", Vector3.new(2.6, 0.5, 2.4), CFrame.new(at + Vector3.new(0, 0.7, 0.9)) * CFrame.Angles(math.rad(-50), 0, 0), shell, Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
	local pearl = bit("Pearl", Vector3.new(0.95, 0.95, 0.95), CFrame.new(at + Vector3.new(0, 0.35, 0)), rgb(252, 248, 240), Enum.Material.SmoothPlastic, 0, Enum.PartType.Ball)
	pearl.Reflectance = 0.35
	bit("Glow", Vector3.new(2.8, 2.8, 2.8), CFrame.new(at + Vector3.new(0, 0.35, 0)), rgb(226, 242, 255), Enum.Material.Neon, 0.8, Enum.PartType.Ball)
	-- A column of bubbles rising to the surface: how they're found from above.
	local attach = Instance.new("Attachment")
	attach.Parent = pearl
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Rate = 7
	bubbles.Lifetime = NumberRange.new(2.4, 3.4)
	bubbles.Speed = NumberRange.new(2.4, 3.6)
	bubbles.SpreadAngle = Vector2.new(8, 8)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.34) })
	bubbles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.85, 0.5), NumberSequenceKeypoint.new(1, 1) })
	bubbles.Color = ColorSequence.new(rgb(236, 250, 255))
	bubbles.LightEmission = 0.4
	bubbles.Parent = attach
	return m
end

local function holder(): Folder
	local f = pearlFolder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "MaisonIsland"
	nf.Parent = Workspace
	pearlFolder = nf
	return nf
end

-- Draws the day's pearls still to find (from the server's state).
local function drawPearls(st: { [string]: any })
	clearPearls()
	local spots = if type(st.pearlSpots) == "table" then st.pearlSpots else {}
	local taken = if type(st.pearlTaken) == "table" then st.pearlTaken else {}
	local o = origin()
	for n, spot in spots do
		local at = Plan.PEARL_SPOTS[spot]
		if at and not taken[n] then
			local m = pearlModel(o + at, n)
			m.Parent = holder()
			pearls[n] = m
		end
	end
end

-- A guest beside a pearl: the server is asked to bring it up (once at a time per pearl).
local function reach(root: BasePart)
	local o = origin()
	local p = root.CFrame.Position
	for n, m in pearls do
		local spot = m:GetAttribute("Pearl")
		local pearl = m:FindFirstChild("Pearl")
		if spot and pearl and pearl:IsA("BasePart") and (pearl.CFrame.Position - p).Magnitude <= Plan.PEARL_REACH - 1 then
			if (asking[n] or -math.huge) + 2 < os.clock() then
				asking[n] = os.clock()
				task.spawn(function()
					local r = ask({ op = "act", id = "island", act = "pearl", n = n })
					if r and r.ok == true then
						local had = pearls[n]
						if had then
							had:Destroy()
							pearls[n] = nil
						end
						sound("reward", 0.7)
						local gems = tonumber(r.gems) or 0
						IslandView.notice("A pearl from the lagoon", string.format("+%d Gilt  ·  %d of %d today%s", tonumber(r.gilt) or 0, tonumber(r.got) or 0, tonumber(r.of) or 5, if gems > 0 then string.format("  ·  all five: +%d Gems", gems) else ""), 3)
						if type(r.state) == "table" then
							IslandView.changed(r.state)
						end
					end
				end)
			end
		end
	end
	local _ = o
end

---------------------------------------------------------------------------------------------------
-- The flight: a few seconds in the jet's cabin
---------------------------------------------------------------------------------------------------
local flying = false

local function cabinPart(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, transparency: number?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

-- The cabin, built far up in the sky: ivory leather and walnut, oval windows, club seats facing
-- across a table with two glasses of something sparkling, a warm light along the ceiling.
local function buildCabin(at: CFrame, liveryId: string): Model
	local m = Instance.new("Model")
	m.Name = "IslandCabin"
	local l = Plan.liveryById[liveryId] or Plan.liveryById.noir
	local IVORY, WALNUT, CARPET = rgb(236, 228, 212), rgb(92, 56, 34), rgb(206, 194, 172)
	cabinPart(m, "Floor", Vector3.new(9, 0.4, 30), at * CFrame.new(0, -0.2, 0), CARPET, Enum.Material.Fabric)
	cabinPart(m, "Ceiling", Vector3.new(9, 0.4, 30), at * CFrame.new(0, 7.4, 0), IVORY, Enum.Material.SmoothPlastic)
	cabinPart(m, "CeilingLight", Vector3.new(1.2, 0.1, 26), at * CFrame.new(0, 7.15, 0), rgb(255, 222, 170), Enum.Material.Neon, 0.1)
	for _, side in { -1, 1 } do
		-- The side walls: a lower panel and a curve inward above, with the windows between.
		for i = 0, 6 do
			local z = -12 + i * 4
			cabinPart(m, "WallPanel", Vector3.new(0.3, 2.6, 2.4), at * CFrame.new(side * 4.4, 1.3, z), IVORY, Enum.Material.Leather)
			cabinPart(m, "WallUpper", Vector3.new(0.3, 2.4, 2.4), at * CFrame.new(side * 4.1, 6, z) * CFrame.Angles(0, 0, side * math.rad(-18)), IVORY, Enum.Material.SmoothPlastic)
			cabinPart(m, "Pier", Vector3.new(0.3, 7.4, 1.6), at * CFrame.new(side * 4.4, 3.7, z + 2), IVORY, Enum.Material.SmoothPlastic)
			cabinPart(m, "WindowFrame", Vector3.new(0.12, 2.6, 0.24), at * CFrame.new(side * 4.3, 3.9, z - 1.12), WALNUT, Enum.Material.Wood)
			cabinPart(m, "WindowFrame", Vector3.new(0.12, 2.6, 0.24), at * CFrame.new(side * 4.3, 3.9, z + 1.12), WALNUT, Enum.Material.Wood)
			cabinPart(m, "WindowSill", Vector3.new(0.6, 0.12, 2.4), at * CFrame.new(side * 4.1, 2.62, z), WALNUT, Enum.Material.Wood)
		end
		cabinPart(m, "Ledge", Vector3.new(1.2, 0.2, 28), at * CFrame.new(side * 3.7, 2.6, 0), WALNUT, Enum.Material.Wood)
		-- A wing outside, in the livery, and the engine's glow.
		cabinPart(m, "Wing", Vector3.new(26, 0.7, 7), at * CFrame.new(side * 17, -0.4, 4) * CFrame.Angles(0, side * math.rad(-24), side * math.rad(-4)), l.body, Enum.Material.SmoothPlastic)
		cabinPart(m, "WingEdge", Vector3.new(26, 0.72, 0.5), at * CFrame.new(side * 17, -0.38, 0.6) * CFrame.Angles(0, side * math.rad(-24), side * math.rad(-4)), l.trim, Enum.Material.Metal)
	end
	-- The bulkhead ahead: walnut, and a gold plate.
	cabinPart(m, "Bulkhead", Vector3.new(9, 7.6, 0.4), at * CFrame.new(0, 3.6, -15), WALNUT, Enum.Material.Wood)
	cabinPart(m, "Plate", Vector3.new(2.4, 0.5, 0.1), at * CFrame.new(0, 5.2, -14.75), rgb(214, 176, 96), Enum.Material.Metal)
	cabinPart(m, "Aft", Vector3.new(9, 7.6, 0.4), at * CFrame.new(0, 3.6, 15), IVORY, Enum.Material.SmoothPlastic)
	-- Two pairs of club seats across a table, and the glasses.
	for _, pair in { -5, 6 } do
		for _, side in { -1, 1 } do
			for _, facing in { -1, 1 } do
				local z = pair + facing * 2.6
				local seat = at * CFrame.new(side * 2.4, 0, z) * CFrame.Angles(0, if facing == 1 then 0 else math.pi, 0)
				cabinPart(m, "Seat", Vector3.new(2.6, 1.4, 2.4), seat * CFrame.new(0, 1.2, 0), IVORY, Enum.Material.Leather)
				cabinPart(m, "SeatBack", Vector3.new(2.6, 3.2, 0.7), seat * CFrame.new(0, 3, 1.1), IVORY, Enum.Material.Leather)
				cabinPart(m, "SeatBase", Vector3.new(2, 0.6, 2), seat * CFrame.new(0, 0.3, 0), WALNUT, Enum.Material.Wood)
			end
			cabinPart(m, "Table", Vector3.new(2.4, 0.2, 2.2), at * CFrame.new(side * 2.4, 2.4, pair), WALNUT, Enum.Material.Wood)
		end
	end
	for _, x in { -2.8, -2.0 } do
		cabinPart(m, "Glass", Vector3.new(0.6, 0.22, 0.22), at * CFrame.new(x, 2.85, -5.2) * CFrame.Angles(0, 0, math.rad(90)), rgb(230, 240, 250), Enum.Material.Glass, 0.4, Enum.PartType.Cylinder)
		cabinPart(m, "Fizz", Vector3.new(0.4, 0.2, 0.2), at * CFrame.new(x, 2.8, -5.2) * CFrame.Angles(0, 0, math.rad(90)), rgb(250, 222, 150), Enum.Material.Neon, 0.3, Enum.PartType.Cylinder)
	end
	return m
end

-- The flight. `outbound`: to the island (else home). Any key or tap ends it early.
function IslandView.flight(outbound: boolean)
	if flying then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	flying = true
	pcall(IslandView.cinematic, true)
	local gui = player:FindFirstChild("PlayerGui")
	local screen = Instance.new("ScreenGui")
	screen.Name = "MaisonFlight"
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 80
	screen.ResetOnSpawn = false
	screen.Parent = gui
	local function bar(top: boolean): Frame
		local b = Instance.new("Frame")
		b.Name = if top then "BarTop" else "BarBottom"
		b.BackgroundColor3 = Color3.new(0, 0, 0)
		b.BorderSizePixel = 0
		b.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		b.Position = UDim2.fromScale(0, if top then 0 else 1)
		b.Size = UDim2.new(1, 0, 0.11, 0)
		b.Parent = screen
		return b
	end
	bar(true)
	local foot = bar(false)
	local caps = Instance.new("TextLabel")
	caps.Name = "Caps"
	caps.BackgroundTransparency = 1
	caps.Position = UDim2.new(0, 36, 0, 10)
	caps.Size = UDim2.new(0.6, 0, 0, 16)
	caps.FontFace = Brand.Fonts.bodyBold
	caps.TextSize = 13
	caps.TextXAlignment = Enum.TextXAlignment.Left
	caps.TextColor3 = rgb(255, 204, 90)
	caps.Text = "THE PRIVATE JET"
	caps.TextTransparency = 1
	caps.Parent = foot
	local words = Instance.new("TextLabel")
	words.Name = "Where"
	words.BackgroundTransparency = 1
	words.Position = UDim2.new(0, 36, 0, 28)
	words.Size = UDim2.new(0.6, 0, 0, 30)
	words.FontFace = Brand.Fonts.display
	words.TextSize = 28
	words.TextXAlignment = Enum.TextXAlignment.Left
	words.TextColor3 = rgb(246, 238, 222)
	words.Text = if outbound then "To Luxury Island" else "Home to the Maison"
	words.TextTransparency = 1
	words.Parent = foot
	local skip = Instance.new("TextLabel")
	skip.Name = "Skip"
	skip.BackgroundTransparency = 1
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -36, 0, 22)
	skip.Size = UDim2.fromOffset(200, 18)
	skip.FontFace = Brand.Fonts.body
	skip.TextSize = 12
	skip.TextXAlignment = Enum.TextXAlignment.Right
	skip.TextColor3 = rgb(180, 172, 160)
	skip.Text = "any key to skip"
	skip.Parent = foot
	local white = Instance.new("Frame")
	white.Name = "Flash"
	white.BackgroundColor3 = rgb(255, 250, 240)
	white.BackgroundTransparency = 1
	white.BorderSizePixel = 0
	white.Size = UDim2.fromScale(1, 1)
	white.ZIndex = 5
	white.Parent = screen
	TweenService:Create(caps, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	task.delay(0.25, function()
		TweenService:Create(words, TweenInfo.new(0.9), { TextTransparency = 0 }):Play()
	end)

	-- The cabin, high over the sea, and the clouds.
	local o = origin()
	local at = CFrame.new(o + Vector3.new(0, 1200, -2600)) * CFrame.Angles(0, math.pi, 0)
	local liveryId = player:GetAttribute("JetLivery")
	local cabin = buildCabin(at, if type(liveryId) == "string" then liveryId else "noir")
	local clouds = Instance.new("Model")
	clouds.Name = "Clouds"
	clouds.Parent = cabin
	local puffs: { { part: Part, offset: Vector3 } } = {}
	local rng = Random.new(7)
	for i = 1, 16 do
		local side = if i % 2 == 0 then 1 else -1
		local offset = Vector3.new(side * rng:NextNumber(26, 90), rng:NextNumber(-40, 30), rng:NextNumber(-180, 180))
		local size = rng:NextNumber(18, 46)
		local puff = cabinPart(clouds, "Cloud", Vector3.new(size, size * 0.6, size * 1.3), at * CFrame.new(offset), if outbound then rgb(255, 238, 222) else rgb(150, 160, 190), Enum.Material.SmoothPlastic, 0.12, Enum.PartType.Ball)
		table.insert(puffs, { part = puff, offset = offset })
	end
	cabin.Parent = Workspace
	local camWas = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local seat = at * CFrame.new(1.6, 4.1, 3.6)
	local t = 0
	local done = false
	local conns: { RBXScriptConnection } = {}
	local function finish()
		if done then
			return
		end
		done = true
		for _, c in conns do
			c:Disconnect()
		end
		local flash = TweenService:Create(white, TweenInfo.new(0.35), { BackgroundTransparency = 0 })
		flash:Play()
		task.delay(0.4, function()
			cabin:Destroy()
			camera.CameraType = if camWas == Enum.CameraType.Scriptable then Enum.CameraType.Custom else camWas
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				camera.CameraSubject = hum
			end
			TweenService:Create(white, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			pcall(IslandView.cinematic, false)
			task.delay(0.7, function()
				screen:Destroy()
				flying = false
			end)
		end)
	end
	table.insert(conns, RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		-- A gentle bank and the faintest sway; the clouds stream past.
		local bank = math.sin(t * 0.7) * math.rad(2.5)
		local sway = Vector3.new(math.sin(t * 1.3) * 0.04, math.sin(t * 2.1) * 0.03, 0)
		camera.CFrame = seat * CFrame.Angles(math.rad(-4), math.rad(-38) + math.sin(t * 0.4) * math.rad(3), bank) + sway
		for _, p in puffs do
			local z = ((p.offset.Z + t * 160 + 180) % 360) - 180
			p.part.CFrame = at * CFrame.new(p.offset.X, p.offset.Y, z)
		end
		if t >= 5.5 then
			finish()
		end
	end))
	table.insert(conns, UserInputService.InputBegan:Connect(function(input: InputObject)
		if t > 0.6 and (input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.Gamepad1) then
			finish()
		end
	end))
	sound(if outbound then "enter" else "leave", 0.6)
end

function IslandView.flying(): boolean
	return flying
end

---------------------------------------------------------------------------------------------------
-- On the island, and off it
---------------------------------------------------------------------------------------------------
local onIsland = false
local lastState: { [string]: any }? = nil

-- The server's word on the island (pearls, the light, the livery): drawn again.
function IslandView.update(st: { [string]: any })
	lastState = st
	if onIsland then
		drawPearls(st)
		if type(st.theme) == "string" and st.theme ~= theme then
			IslandView.light(st.theme)
		end
		paintAll()
	end
end

function IslandView.state(): { [string]: any }?
	return lastState
end

local function arrive()
	onIsland = true
	local id = player:GetAttribute("IslandTheme")
	IslandView.light(if type(id) == "string" then id else "golden")
	paintAll()
	task.spawn(function()
		local st = ask({ op = "state", id = "island" })
		if st and st.ok == true and onIsland then
			IslandView.update(st)
			IslandView.changed(st)
		end
	end)
end

local function depart()
	onIsland = false
	clearPearls()
	IslandView.unlight()
end

function IslandView.on(): boolean
	return onIsland
end

function IslandView.start()
	local function follow()
		local here = player:GetAttribute(AttractionList.ATTRIBUTE) == "island"
		if here and not onIsland then
			arrive()
		elseif not here and onIsland then
			depart()
		end
	end
	player:GetAttributeChangedSignal(AttractionList.ATTRIBUTE):Connect(follow)
	player:GetAttributeChangedSignal("IslandTheme"):Connect(function()
		local id = player:GetAttribute("IslandTheme")
		if onIsland and type(id) == "string" then
			IslandView.light(id)
		end
	end)
	player:GetAttributeChangedSignal("JetLivery"):Connect(function()
		if onIsland then
			paintAll()
		end
	end)
	follow()
	local acc, keep = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		if not onIsland then
			return
		end
		acc += dt
		keep += dt
		if acc >= 0.25 then
			acc = 0
			local c = player.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				reach(root)
			end
		end
		-- (Every two seconds: the island's light kept, and the jets painted as they stream in.)
		if keep >= 2 then
			keep = 0
			if theme then
				IslandView.light(theme)
			end
			paintAll()
		end
	end)
end

return IslandView

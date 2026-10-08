--!strict
-- Salutes on this guest's screen. A quiet line names who gave it; then, as the salute is:
--   gold leaf     real leaves of gold, swaying and turning over as they fall round every guest,
--                 glinting in the light, with a glitter of gold dust and a shimmer;
--   the encore    the Pianist plays on, a followspot finds the giver wherever they are (its beam of
--                 light seen in the air), rose petals fall round them and the house applauds;
--   chandeliers   every lamp in the house flares, in a wave out from wherever you stand, each
--                 chandelier throwing off glints of crystal, the light warming to gold;
--   fireworks     the full pyromusical over the estate (World/Fireworks);
--   the countdown the Finale's ten great golden numbers, a bell for each, then the clock chimes
--                 midnight in a flash of light, and the sky goes up.
-- The owner's events use the same effects.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Salutes = require(ReplicatedStorage.Shared.Salutes)
local Fireworks = require(script.Parent.Fireworks)
local Flakes = require(script.Parent.Flakes)
local Toast = require(script.Parent.Parent.UI.Toast)
local Sound = require(script.Parent.Parent.Sound)

local SaluteView = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local LEAF = { rgb(246, 206, 112), rgb(255, 226, 150), rgb(214, 166, 72), rgb(236, 190, 96) }
local PETALS = { rgb(190, 24, 48), rgb(220, 48, 72), rgb(150, 16, 36), rgb(236, 120, 140) }
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local DUST = "rbxasset://textures/particles/fire_sparks_main.dds"

local function folder(): Instance
	local f = Workspace:FindFirstChild("MaisonLocal")
	return f or Workspace
end

local function anchor(name: string, at: Vector3, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(1, 1, 1)
	p.Position = at
	p.Parent = folder()
	return p
end

local function rootOf(p: Player?): BasePart?
	local character = p and p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Where this guest is (or, without a character, where the camera is).
local function here(): Vector3?
	local root = rootOf(player)
	if root then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else nil
end

-- A warm tint over the whole picture for a while (the house's light turning to gold).
local function warm(seconds: number, tint: Color3, brightness: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "SaluteWarmth"
	cc.TintColor = Color3.new(1, 1, 1)
	cc.Brightness = 0
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { TintColor = tint, Brightness = brightness }):Play()
	task.delay(seconds, function()
		TweenService:Create(cc, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { TintColor = Color3.new(1, 1, 1), Brightness = 0 }):Play()
		task.wait(2.6)
		cc:Destroy()
	end)
end

-- Gold leaf: real leaves falling round this guest, and a fine glitter of gold dust with them.
local function goldLeaf(seconds: number)
	Flakes.fall({
		seconds = seconds,
		centre = here,
		colours = LEAF,
		material = Enum.Material.Metal,
		reflectance = 0.45,
		size = Vector3.new(0.55, 0.03, 0.45),
		count = 70,
		radius = 26,
		height = 18,
		fall = 2.4,
	})
	local cloud = anchor("GoldLeaf", Vector3.zero, Vector3.new(40, 1, 40))
	local e = Instance.new("ParticleEmitter")
	e.Texture = DUST
	e.Rate = 40
	e.Lifetime = NumberRange.new(4, 6)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -1.6, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.Size = NumberSequence.new(0.9, 0.4)
	e.LightEmission = 0.8
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(rgb(255, 236, 180), rgb(214, 170, 80))
	e.Parent = cloud
	warm(seconds, rgb(255, 244, 222), 0.03)
	pcall(Sound.play, "shimmerFall", 0.7)
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < seconds and cloud.Parent do
			local at = here()
			if at then
				cloud.Position = at + Vector3.new(0, 14, 0)
			end
			task.wait(0.1)
		end
		e.Enabled = false
		task.delay(6, function()
			cloud:Destroy()
		end)
	end)
	task.delay(seconds * 0.5, function()
		pcall(Sound.play, "shimmerFall", 0.5)
	end)
end

-- Every lamp in the house flares, in a wave out from wherever this guest is; each chandelier
-- throws off glints of crystal as the wave reaches it; then all settle back.
local function chandelier(seconds: number)
	local from = here() or Vector3.zero
	local lights: { { light: Light, base: number, at: Vector3 } } = {}
	for _, light in CollectionService:GetTagged("HouseLamp") do
		if light:IsA("Light") and not CollectionService:HasTag(light, "Flicker") then
			local parent = light.Parent
			local at = if parent and parent:IsA("BasePart") then parent.Position else from
			table.insert(lights, { light = light, base = light.Brightness, at = at })
		end
	end
	table.sort(lights, function(a, b)
		return (a.at - from).Magnitude < (b.at - from).Magnitude
	end)
	for i, l in lights do
		local delay = (l.at - from).Magnitude / 150
		task.delay(delay, function()
			if not l.light.Parent then
				return
			end
			TweenService:Create(l.light, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = l.base * 2.6 }):Play()
			local lamp = l.light.Parent
			if i <= 40 and lamp and lamp:IsA("BasePart") then
				local glints = Instance.new("ParticleEmitter")
				glints.Texture = SPARK
				glints.Rate = 0
				glints.Lifetime = NumberRange.new(1.2, 2.2)
				glints.Speed = NumberRange.new(2, 7)
				glints.SpreadAngle = Vector2.new(180, 180)
				glints.Acceleration = Vector3.new(0, -5, 0)
				glints.Drag = 1.2
				glints.LightEmission = 1
				glints.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
				glints.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.6), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
				glints.Color = ColorSequence.new(rgb(255, 255, 255), rgb(255, 220, 150))
				glints.Parent = lamp
				glints:Emit(16)
				task.delay(3, function()
					glints:Destroy()
				end)
			end
		end)
	end
	pcall(Sound.play, "crystal", 0.8)
	task.delay(0.6, function()
		pcall(Sound.play, "crystal", 0.6, 1.2)
	end)
	task.delay(1.2, function()
		pcall(Sound.shimmer)
	end)
	warm(seconds, rgb(255, 236, 206), 0.05)
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local bloomBase = if bloom then bloom.Intensity else 0
	if bloom then
		TweenService:Create(bloom, TweenInfo.new(1.2), { Intensity = bloomBase + 0.6 }):Play()
	end
	task.delay(seconds, function()
		for _, l in lights do
			if l.light.Parent then
				TweenService:Create(l.light, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { Brightness = l.base }):Play()
			end
		end
		if bloom then
			TweenService:Create(bloom, TweenInfo.new(2.5), { Intensity = bloomBase }):Play()
		end
	end)
end

-- Fireworks over the whole estate (World/Fireworks), as big as the salute is.
local function fireworks(seconds: number, scale: number, mine: boolean)
	-- The guest who gave it is taken out to watch at once; everyone else has the key.
	Fireworks.show(seconds, { scale = scale, watch = mine })
end

-- The Finale's countdown: ten great golden numbers on every screen, each with a bell, then the
-- clock chimes midnight in a flash of light.
local function countdown(seconds: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "FinaleCountdown"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")
	-- A dial behind the number: a ring of gold that empties as the seconds go.
	local dial = Instance.new("Frame")
	dial.AnchorPoint = Vector2.new(0.5, 0.5)
	dial.Position = UDim2.fromScale(0.5, 0.4)
	dial.Size = UDim2.fromScale(0.3, 0.3)
	dial.BackgroundTransparency = 1
	dial.Parent = gui
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = dial
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = dial
	local ring = Instance.new("UIStroke")
	ring.Color = rgb(246, 206, 120)
	ring.Thickness = 4
	ring.Transparency = 0.15
	ring.Parent = dial
	local sweep = Instance.new("UIGradient")
	sweep.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(0.501, 1), NumberSequenceKeypoint.new(1, 1) })
	sweep.Parent = ring
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.4)
	label.Size = UDim2.fromScale(0.6, 0.26)
	label.FontFace = Brand.Fonts.display
	label.TextScaled = true
	label.TextColor3 = rgb(255, 255, 255)
	label.Text = ""
	label.Parent = gui
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 240, 190)), ColorSequenceKeypoint.new(0.5, rgb(236, 186, 82)), ColorSequenceKeypoint.new(1, rgb(255, 226, 150)) })
	sheen.Rotation = 90
	sheen.Parent = label
	local edge = Instance.new("UIStroke")
	edge.Color = rgb(60, 40, 10)
	edge.Thickness = 2
	edge.Transparency = 0.3
	edge.Parent = label
	local scaler = Instance.new("UIScale")
	scaler.Parent = label
	local hush = Instance.new("ColorCorrectionEffect")
	hush.Name = "CountdownHush"
	hush.Parent = Lighting
	task.spawn(function()
		for n = seconds, 1, -1 do
			label.Text = tostring(n)
			label.TextTransparency = 0
			scaler.Scale = 1.4
			sweep.Rotation = -90 + (seconds - n) / seconds * 360
			TweenService:Create(scaler, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 0.55 }):Play()
			TweenService:Create(hush, TweenInfo.new(0.9), { Brightness = -0.012 * (seconds - n + 1), Saturation = -0.02 * (seconds - n + 1) }):Play()
			pcall(Sound.play, "bellStrike", 0.45 + 0.07 * (seconds - n), if n <= 3 then 1.06 else 1)
			task.wait(1)
		end
		label.Text = "Midnight"
		label.TextTransparency = 0
		ring.Transparency = 1
		scaler.Scale = 0.8
		TweenService:Create(scaler, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
		hush.Brightness = 0.45
		hush.Saturation = 0
		TweenService:Create(hush, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
		pcall(Sound.play, "midnightChime", 0.9)
		task.wait(2.4)
		TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
		TweenService:Create(edge, TweenInfo.new(0.8), { Transparency = 1 }):Play()
		task.wait(0.9)
		gui:Destroy()
		hush:Destroy()
	end)
end

-- An encore: a followspot finds the giver (its beam seen in the air), rose petals fall round them,
-- the house applauds, and the Pianist plays on.
local function encore(seconds: number, userId: number)
	local giver = Players:GetPlayerByUserId(userId)
	local character = giver and giver.Character
	if not character then
		return
	end
	local glow = Instance.new("Highlight")
	glow.FillColor = rgb(255, 226, 160)
	glow.FillTransparency = 0.88
	glow.OutlineColor = rgb(246, 214, 130)
	glow.OutlineTransparency = 0.2
	glow.Adornee = character
	glow.Parent = folder()
	local lamp = anchor("Spotlight", Vector3.zero)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 30
	spot.Range = 34
	spot.Brightness = 3.4
	spot.Color = rgb(255, 232, 190)
	spot.Parent = lamp
	-- The beam itself, from the lamp to the floor round the giver.
	local floorMark = anchor("SpotFloor", Vector3.zero)
	local a0 = Instance.new("Attachment")
	a0.Parent = lamp
	local a1 = Instance.new("Attachment")
	a1.Parent = floorMark
	local beam = Instance.new("Beam")
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	beam.FaceCamera = true
	beam.Width0 = 1.2
	beam.Width1 = 9
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.Segments = 1
	beam.Color = ColorSequence.new(rgb(255, 240, 210))
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0.85) })
	beam.Parent = lamp
	local function giverAt(): Vector3?
		local root = rootOf(giver)
		return if root then root.Position else nil
	end
	Flakes.fall({
		seconds = seconds,
		centre = giverAt,
		colours = PETALS,
		material = Enum.Material.SmoothPlastic,
		reflectance = 0,
		size = Vector3.new(0.45, 0.04, 0.36),
		count = 36,
		radius = 9,
		height = 13,
		fall = 2,
	})
	pcall(Sound.play, "applause", 0.6)
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < seconds and lamp.Parent do
			local root = rootOf(giver)
			if root then
				lamp.Position = root.Position + Vector3.new(0, 16, 0)
				floorMark.Position = root.Position - Vector3.new(0, 3, 0)
			end
			task.wait()
		end
		TweenService:Create(beam, TweenInfo.new(1), { Width0 = 0, Width1 = 0 }):Play()
		task.wait(1)
		glow:Destroy()
		lamp:Destroy()
		floorMark:Destroy()
	end)
	Sound.briefDip(0.1)
end

SaluteView.effects = {
	goldLeaf = function(m: { [string]: any })
		goldLeaf(m.seconds or 18)
	end,
	chandelier = function(m: { [string]: any })
		chandelier(m.seconds or 20)
	end,
	fireworks = function(m: { [string]: any })
		fireworks(m.seconds or 45, math.clamp(tonumber(m.scale) or 1, 0.5, 2), tonumber(m.userId) == player.UserId)
	end,
	countdown = function(_m: { [string]: any })
		countdown(Salutes.COUNTDOWN)
	end,
	encore = function(m: { [string]: any })
		encore(m.seconds or 25, tonumber(m.userId) or 0)
	end,
}

function SaluteView.play(m: { [string]: any })
	if type(m.line) == "string" and m.line ~= "" then
		Toast.show(if type(m.title) == "string" then m.title else "A Salute", m.line, 5)
	end
	local effects = (if type(m.effects) == "table" then m.effects else {}) :: { any }
	-- A countdown first: the rest of the salute starts when it reaches midnight.
	local wait = 0
	if table.find(effects, "countdown") then
		pcall(SaluteView.effects.countdown, m)
		wait = Salutes.COUNTDOWN
	end
	local rest = table.clone(m)
	rest.seconds = math.max(5, (tonumber(m.seconds) or 25) - wait)
	task.delay(wait, function()
		for _, name in effects do
			local fx = SaluteView.effects[name]
			if fx and name ~= "countdown" then
				pcall(fx, rest)
			end
		end
	end)
end

function SaluteView.start()
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) == "table" and m.op == "salute" then
			SaluteView.play(m)
		end
	end)
end

return SaluteView

--!strict
-- Salutes on this guest's screen: gold leaf drifting down around them, every lamp in the house
-- flaring, fireworks over the roofs, and an encore (the spotlight finds the giver, wherever they
-- are). A quiet line names who gave it. The owner's events use the same effects.

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
local Toast = require(script.Parent.Parent.UI.Toast)
local Sound = require(script.Parent.Parent.Sound)

local SaluteView = {}

local player = Players.LocalPlayer
local GOLD = { Color3.fromRGB(246, 214, 130), Color3.fromRGB(255, 236, 180), Color3.fromRGB(214, 170, 80) }

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

local function colourSequence(colours: { Color3 }): ColorSequence
	local points = {}
	for i, c in colours do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colours - 1), c))
	end
	return ColorSequence.new(points)
end

local function rootOf(p: Player?): BasePart?
	local character = p and p.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Gold leaf drifting down around this guest, wherever they are in the house.
local function goldLeaf(seconds: number)
	local cloud = anchor("GoldLeaf", Vector3.zero, Vector3.new(40, 1, 40))
	local e = Instance.new("ParticleEmitter")
	e.Rate = 70
	e.Lifetime = NumberRange.new(4, 6)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -2.2, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Size = NumberSequence.new(0.18)
	e.LightEmission = 0.6
	e.Color = colourSequence(GOLD)
	e.Parent = cloud
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < seconds and cloud.Parent do
			local root = rootOf(player)
			if root then
				cloud.Position = root.Position + Vector3.new(0, 16, 0)
			end
			task.wait(0.1)
		end
		e.Enabled = false
		task.delay(6, function()
			cloud:Destroy()
		end)
	end)
end

-- Every lamp in the house flares, then settles back.
local function chandelier(seconds: number)
	local lights = {}
	for _, light in CollectionService:GetTagged("HouseLamp") do
		if light:IsA("Light") and not CollectionService:HasTag(light, "Flicker") then
			table.insert(lights, { light = light, base = light.Brightness })
		end
	end
	for _, l in lights do
		TweenService:Create(l.light, TweenInfo.new(1.2, Enum.EasingStyle.Sine), { Brightness = l.base * 2.4 }):Play()
	end
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	local bloomBase = if bloom then bloom.Intensity else 0
	if bloom then
		TweenService:Create(bloom, TweenInfo.new(1.2), { Intensity = bloomBase + 0.5 }):Play()
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
local function fireworks(seconds: number, scale: number)
	Fireworks.show(seconds, { scale = scale })
end

-- The Finale's countdown: ten great numbers on every screen, then the sky goes up.
local function countdown(seconds: number)
	local gui = Instance.new("ScreenGui")
	gui.Name = "FinaleCountdown"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.38)
	label.Size = UDim2.fromScale(0.6, 0.3)
	label.FontFace = Brand.Fonts.display
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 226, 150)
	label.TextStrokeTransparency = 0.4
	label.Text = ""
	label.Parent = gui
	local scaler = Instance.new("UIScale")
	scaler.Parent = label
	task.spawn(function()
		for n = seconds, 1, -1 do
			label.Text = tostring(n)
			label.TextTransparency = 0
			scaler.Scale = 1.35
			TweenService:Create(scaler, TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 0.6 }):Play()
			pcall(Sound.play, "tick", 0.8, if n <= 3 then 1.3 else 1)
			task.wait(1)
		end
		label.Text = "Midnight"
		label.TextTransparency = 0
		scaler.Scale = 0.8
		TweenService:Create(scaler, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
		task.wait(2.2)
		TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.9)
		gui:Destroy()
	end)
end

-- An encore: the spotlight finds the giver, and the piano plays up.
local function encore(seconds: number, userId: number)
	local giver = Players:GetPlayerByUserId(userId)
	local character = giver and giver.Character
	if not character then
		return
	end
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 1
	glow.OutlineColor = Color3.fromRGB(246, 214, 130)
	glow.OutlineTransparency = 0.2
	glow.Adornee = character
	glow.Parent = folder()
	local lamp = anchor("Spotlight", Vector3.zero)
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 30
	spot.Range = 30
	spot.Brightness = 3
	spot.Color = Color3.fromRGB(255, 232, 190)
	spot.Parent = lamp
	local started = os.clock()
	task.spawn(function()
		while os.clock() - started < seconds and lamp.Parent do
			local root = rootOf(giver)
			if root then
				lamp.Position = root.Position + Vector3.new(0, 14, 0)
			end
			task.wait()
		end
		glow:Destroy()
		lamp:Destroy()
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
		fireworks(m.seconds or 45, math.clamp(tonumber(m.scale) or 1, 0.5, 2))
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

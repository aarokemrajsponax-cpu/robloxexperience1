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

local Remotes = require(ReplicatedStorage.Shared.Remotes)
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

-- Fireworks over the roofs: seen from the street, the Terrace and every window.
local function fireworks(seconds: number)
	local rng = Random.new()
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < seconds do
			local at = Vector3.new(rng:NextNumber(-60, 90), rng:NextNumber(70, 105), rng:NextNumber(-40, 90))
			local burst = anchor("Firework", at)
			local e = Instance.new("ParticleEmitter")
			e.Rate = 0
			e.Lifetime = NumberRange.new(1.4, 2.2)
			e.Speed = NumberRange.new(18, 26)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Acceleration = Vector3.new(0, -9, 0)
			e.Drag = 1.5
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.1) })
			e.LightEmission = 1
			e.Color = colourSequence(if rng:NextNumber() < 0.5 then GOLD else { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 220, 255) })
			e.Parent = burst
			e:Emit(90)
			local flash = Instance.new("PointLight")
			flash.Brightness = 4
			flash.Range = 60
			flash.Color = Color3.fromRGB(255, 220, 160)
			flash.Parent = burst
			TweenService:Create(flash, TweenInfo.new(0.8), { Brightness = 0 }):Play()
			Sound.play("round", 0.12, 0.5 + rng:NextNumber() * 0.2)
			task.delay(3, function()
				burst:Destroy()
			end)
			task.wait(rng:NextNumber(0.5, 1.1))
		end
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
		fireworks(m.seconds or 25)
	end,
	encore = function(m: { [string]: any })
		encore(m.seconds or 25, tonumber(m.userId) or 0)
	end,
}

function SaluteView.play(m: { [string]: any })
	if type(m.line) == "string" and m.line ~= "" then
		Toast.show(if type(m.title) == "string" then m.title else "A Salute", m.line, 5)
	end
	for _, name in (if type(m.effects) == "table" then m.effects else {}) :: { any } do
		local fx = SaluteView.effects[name]
		if fx then
			pcall(fx, m)
		end
	end
end

function SaluteView.start()
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) == "table" and m.op == "salute" then
			SaluteView.play(m)
		end
	end)
end

return SaluteView

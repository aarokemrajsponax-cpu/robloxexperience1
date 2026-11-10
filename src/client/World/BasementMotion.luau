--!strict
-- The Maison Basement's machinery on this screen: the pistons sliding (and carrying whoever rides
-- them), the tiles sinking and rising, the steam and the lasers burning, the valves' bars sweeping.
-- Each moves by the server's clock and the plan's own sums (shared/Basement), so every screen sees
-- the same thing and the server judges by it. Only while this guest is in the Basement.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Plan = require(ReplicatedStorage.Shared.Basement)

local BasementMotion = {}

local player = Players.LocalPlayer

local function now(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

local function elementOf(part: Instance): Plan.El?
	local i = part:GetAttribute("Element")
	return if type(i) == "number" then Plan.Elements[i] else nil
end

-- One frame of the machinery at time t (for tests too).
function BasementMotion.apply(t: number)
	local o = AttractionList.origin("basement")
	for _, part in CollectionService:GetTagged("BasementMover") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			local at, velocity = Plan.moverAt(e, t)
			part.CFrame = CFrame.new(o + at)
			part.AssemblyLinearVelocity = velocity
		end
	end
	for _, part in CollectionService:GetTagged("BasementVanish") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			part.Transparency = Plan.fade(e, t)
			part.CanCollide = Plan.solid(e, t)
		end
	end
	for _, part in CollectionService:GetTagged("BasementVanishGlow") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			part.Transparency = 0.2 + 0.8 * Plan.fade(e, t)
		end
	end
	for _, part in CollectionService:GetTagged("BasementSteam") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			part.Transparency = if Plan.burning(e, t) then 0.55 else 1
		end
	end
	for _, vent in CollectionService:GetTagged("BasementVent") do
		local e = elementOf(vent)
		local emitter = vent:FindFirstChild("Steam")
		if e and emitter and emitter:IsA("ParticleEmitter") then
			emitter.Rate = if Plan.burning(e, t) then 60 else 0
		end
	end
	for _, part in CollectionService:GetTagged("BasementLaser") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			-- (Off, it's a faint line: you can see where it will be.)
			part.Transparency = if Plan.burning(e, t) then 0 else 0.9
		end
	end
	for _, part in CollectionService:GetTagged("BasementSpinner") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			part.CFrame = CFrame.new(o) * Plan.spinnerFrame(e, t)
		end
	end
end

function BasementMotion.start()
	RunService.Heartbeat:Connect(function()
		if player:GetAttribute(AttractionList.ATTRIBUTE) ~= "basement" then
			return
		end
		BasementMotion.apply(now())
	end)
end

return BasementMotion

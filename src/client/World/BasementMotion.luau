--!strict
-- The Maison Basement's machinery on this screen: the pistons sliding (and carrying whoever rides
-- them), the tiles sinking and rising, the steam and the lasers burning, the valves' bars sweeping,
-- and (Build 78) the crushers dropping. Each moves by the server's clock and the plan's own sums
-- (shared/Basement), so every screen sees the same thing and the server judges by it. Only while
-- this guest is in the Basement.
--
-- Build 78: the course this guest's run is on (the server's "BasementVariant" attribute) decides
-- the pace of everything, which of the versions' own pieces are here (the rest hidden and not
-- solid, on this screen only), the light (each version's tint; Blackout's lamps down and every
-- edge glowing), the launch pad (stand on it a moment and it throws you up), and the secrets this
-- guest hasn't found yet, turning slowly where they wait.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Plan = require(ReplicatedStorage.Shared.Basement)

local BasementMotion = {}

local player = Players.LocalPlayer
local GREY = Color3.fromRGB(58, 60, 66)
local WARN = Color3.fromRGB(220, 50, 40)

-- The secrets this guest has found (set from what the server says: they're hidden here).
BasementMotion.found = {} :: { [string]: boolean }

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

-- The version of the course this guest's run is on (1: the House Course).
function BasementMotion.variant(): number
	local v = player:GetAttribute("BasementVariant")
	return if type(v) == "number" and Plan.Variants[v] then v else 1
end

-- Hidden and not solid on this screen (another version's, or a secret already found).
local function hide(part: BasePart)
	if part:GetAttribute("ShownT") == nil then
		part:SetAttribute("ShownT", part.Transparency)
		part:SetAttribute("ShownC", part.CanCollide)
	end
	part.Transparency = 1
	part.CanCollide = false
end

local function show(part: BasePart)
	local t = part:GetAttribute("ShownT")
	if type(t) == "number" then
		part.Transparency = t
		part.CanCollide = part:GetAttribute("ShownC") == true
		part:SetAttribute("ShownT", nil)
		part:SetAttribute("ShownC", nil)
	end
end

-- One frame of the machinery at time t (for tests too), on the course of version `v` (by default
-- this guest's run's).
function BasementMotion.apply(t: number, v: number?)
	local course = v or BasementMotion.variant()
	local tv = Plan.paced(course, t)
	local o = AttractionList.origin("basement")
	for _, part in CollectionService:GetTagged("BasementMover") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			local at, velocity = Plan.moverAt(e, tv)
			part.CFrame = CFrame.new(o + at)
			-- (Riders go with it, at its pace.)
			part.AssemblyLinearVelocity = velocity * (Plan.Variants[course] or Plan.Variants[1]).pace
		end
	end
	for _, part in CollectionService:GetTagged("BasementVanish") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			part.Transparency = Plan.fade(e, tv)
			part.CanCollide = Plan.solid(e, tv)
		end
	end
	for _, part in CollectionService:GetTagged("BasementVanishGlow") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			part.Transparency = 0.2 + 0.8 * Plan.fade(e, tv)
		end
	end
	for _, part in CollectionService:GetTagged("BasementSteam") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			part.Transparency = if Plan.inVariant(e, course) and Plan.burning(e, tv) then 0.55 else 1
		end
	end
	for _, vent in CollectionService:GetTagged("BasementVent") do
		local e = elementOf(vent)
		local emitter = vent:FindFirstChild("Steam")
		if e and emitter and emitter:IsA("ParticleEmitter") then
			emitter.Rate = if Plan.inVariant(e, course) and Plan.burning(e, tv) then 60 else 0
		end
	end
	for _, part in CollectionService:GetTagged("BasementLaser") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			-- (Off, it's a faint line: you can see where it will be.)
			part.Transparency = if Plan.burning(e, tv) then 0 else 0.9
		end
	end
	for _, part in CollectionService:GetTagged("BasementSpinner") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			part.CFrame = CFrame.new(o) * Plan.spinnerFrame(e, tv)
		end
	end
	-- The crushers: up, waiting, a shake and a red glow, then down.
	for _, part in CollectionService:GetTagged("BasementCrusher") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") and Plan.inVariant(e, course) then
			local warns = Plan.crusherWarns(e, tv)
			local shake = if warns then math.sin(tv * 60) * 0.08 else 0
			part.CFrame = CFrame.new(o + e.at + Vector3.new(shake, -e.size.Y / 2 + 1.2 + Plan.crusherLift(e, tv), 0))
			part.Color = if warns or Plan.burning(e, tv) then WARN else GREY
		end
	end
	-- The secrets this guest hasn't found, turning slowly where they wait.
	for _, part in CollectionService:GetTagged("BasementSecret") do
		local e = elementOf(part)
		if e and part:IsA("BasePart") then
			if Plan.inVariant(e, course) and not BasementMotion.found[e.id or ""] then
				part.CFrame = CFrame.new(o + e.at + Vector3.new(0, math.sin(t * 2) * 0.25, 0)) * CFrame.Angles(0, t * 1.4, 0) * CFrame.Angles(0, math.rad(90), 0)
				part.Transparency = 0
			else
				part.Transparency = 1
			end
		end
	end
end

-- Which version's own pieces are here, the lamps' tint and the glowing edges: set when the run's
-- course changes (and when this guest comes down).
local shownFor = 0
function BasementMotion.dress(course: number)
	shownFor = course
	local var = Plan.Variants[course] or Plan.Variants[1]
	for _, holder in CollectionService:GetTagged("BasementVariant") do
		local mine = holder:GetAttribute("Variant") == course
		for _, d in holder:GetDescendants() do
			if d:IsA("BasePart") then
				if mine then
					show(d)
				else
					hide(d)
				end
			elseif d:IsA("Light") or d:IsA("ParticleEmitter") then
				d.Enabled = mine
			end
		end
	end
	for _, g in CollectionService:GetTagged("BasementGuide") do
		if g:IsA("BasePart") then
			g.Transparency = if var.glow then 0.15 else 1
		end
	end
	local res = Workspace:FindFirstChild("Attractions")
	local root = res and res:FindFirstChild("MaisonBasement")
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("Light") then
				local base = d:GetAttribute("BaseBrightness")
				local colour = d:GetAttribute("BaseColor")
				if type(base) ~= "number" then
					base = d.Brightness
					d:SetAttribute("BaseBrightness", base)
				end
				if typeof(colour) ~= "Color3" then
					colour = d.Color
					d:SetAttribute("BaseColor", colour)
				end
				d.Brightness = (base :: number) * var.bright
				d.Color = (colour :: Color3):Lerp(var.tint, 0.35)
			end
		end
	end
end

-- The launch pad: stood on a moment, it throws this guest up (the server tells the movement watch).
local padSince: number? = nil
local launchedAt = 0
local function launchPads(course: number)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local at = root.Position - AttractionList.origin("basement")
	local on: Plan.El? = nil
	for _, part in CollectionService:GetTagged("BasementBouncer") do
		local e = elementOf(part)
		if e and Plan.inVariant(e, course) then
			local rel = at - e.at
			if math.abs(rel.X) <= e.size.X / 2 + 0.3 and math.abs(rel.Z) <= e.size.Z / 2 + 0.3 and rel.Y > 0 and rel.Y < 5 then
				on = e
			end
		end
	end
	local clock = os.clock()
	if not on then
		padSince = nil
		return
	end
	padSince = padSince or clock
	if clock - (padSince :: number) >= 0.3 and clock >= launchedAt + 1 then
		launchedAt = clock
		padSince = nil
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, (on :: Plan.El).bounce or 80, v.Z)
	end
end

function BasementMotion.start()
	RunService.Heartbeat:Connect(function()
		if player:GetAttribute(AttractionList.ATTRIBUTE) ~= "basement" then
			shownFor = 0
			return
		end
		local course = BasementMotion.variant()
		if course ~= shownFor then
			BasementMotion.dress(course)
		end
		BasementMotion.apply(now(), course)
		pcall(launchPads, course)
	end)
end

return BasementMotion

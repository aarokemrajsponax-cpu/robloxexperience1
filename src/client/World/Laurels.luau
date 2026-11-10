--!strict
-- Maison Prestige in the house, on every screen: from the Platinum Laurel, a ring of light at a
-- guest's feet in their laurel's colour (ruby from the Ruby Laurel, gold alive with light for the
-- Maison Legend); and the Laurel Flourish, a shower of gold leaves round whoever the server says
-- has called for it. All drawn here, for this screen only, from what the server publishes (each
-- guest's "Prestige" attribute, and the Empire's "flourish").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Rules = require(ReplicatedStorage.Shared.Prestige)
local Flakes = require(script.Parent.Flakes)
local Sound = require(script.Parent.Parent.Sound)

local Laurels = {}

local rgb = Color3.fromRGB
local RUBY = rgb(236, 64, 96)
local GOLD = rgb(255, 214, 110)
local rings: { [Player]: { part: BasePart, stroke: UIStroke, level: number } } = {}
local folder: Folder? = nil

local function holder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "MaisonLaurels"
	nf.Parent = Workspace
	folder = nf
	return nf
end

local function colourFor(level: number): Color3
	if level >= Rules.TOP then
		return GOLD
	elseif level >= Rules.RUBY_RING then
		return RUBY
	end
	return Rules.colour(level) or GOLD
end

local function drop(p: Player)
	local r = rings[p]
	if r then
		r.part:Destroy()
		rings[p] = nil
	end
end

-- A ring of light: a flat, unseen plate with a circle drawn on its top face.
local function ringFor(p: Player, level: number)
	local had = rings[p]
	if had and had.level == level then
		return
	end
	drop(p)
	local plate = Instance.new("Part")
	plate.Name = "LaurelRing"
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Transparency = 1
	plate.Size = Vector3.new(5.2, 0.05, 5.2)
	plate.Parent = holder()
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = plate
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.new(1, -24, 1, -24)
	circle.BackgroundColor3 = colourFor(level)
	circle.BackgroundTransparency = 0.88
	circle.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = circle
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 7
	stroke.Color = colourFor(level)
	stroke.Transparency = 0.15
	stroke.Parent = circle
	rings[p] = { part = plate, stroke = stroke, level = level }
end

local function follow(p: Player)
	local level = p:GetAttribute("Prestige")
	if type(level) == "number" and level >= Rules.RING then
		ringFor(p, level)
	else
		drop(p)
	end
end

-- The Laurel Flourish round a guest (by their user id).
function Laurels.flourish(userId: number, level: number?)
	local p = Players:GetPlayerByUserId(userId)
	if not p then
		return
	end
	local colour = colourFor(level or Rules.FLOURISH)
	Flakes.fall({
		seconds = 3,
		centre = function(): Vector3?
			local c = p.Character
			local r = c and c:FindFirstChild("HumanoidRootPart")
			return if r and r:IsA("BasePart") then r.CFrame.Position else nil
		end,
		colours = { colour, rgb(255, 232, 160), rgb(214, 170, 70) },
		material = Enum.Material.SmoothPlastic,
		size = Vector3.new(0.5, 0.02, 0.24),
		count = 50,
		radius = 6,
		height = 9,
		fall = 2.4,
		flutter = 3,
		burst = true,
	})
	if p == Players.LocalPlayer then
		pcall(Sound.play, "shimmerFall", 0.7)
	end
end

-- For tests: a guest's ring, if they have one.
function Laurels.ringOf(p: Player): BasePart?
	local r = rings[p]
	return if r then r.part else nil
end

function Laurels.start()
	local function watch(p: Player)
		p:GetAttributeChangedSignal("Prestige"):Connect(function()
			follow(p)
		end)
		follow(p)
	end
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(drop)
	local t = 0
	RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		for p, r in rings do
			local c = p.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local hum = c and c:FindFirstChildOfClass("Humanoid")
			if root and root:IsA("BasePart") and hum then
				local feet = root.CFrame.Position - Vector3.new(0, root.Size.Y / 2 + hum.HipHeight - 0.08, 0)
				r.part.CFrame = CFrame.new(feet) * CFrame.Angles(0, t * 0.6, 0)
				-- (The Legend's ring breathes; the others hold steady.)
				r.stroke.Transparency = if r.level >= Rules.TOP then 0.1 + 0.25 * (0.5 + 0.5 * math.sin(t * 2.4)) else 0.15
			else
				r.part.CFrame = CFrame.new(0, -500, 0)
			end
		end
	end)
end

return Laurels

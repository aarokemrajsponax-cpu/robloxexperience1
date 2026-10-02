--!strict
-- A guide to a place in the house: a gold pin floating over it with its name, and a soft arc of
-- light from the guest to it. The Concierge's tour points with it; one at a time.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)

local Waypoint = {}

local current: Part? = nil
local beam: Beam? = nil
local from: Attachment? = nil

function Waypoint.clear()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if from then
		from:Destroy()
		from = nil
	end
	if current then
		current:Destroy()
		current = nil
	end
end

function Waypoint.show(point: Vector3, name: string)
	Waypoint.clear()
	local anchor = Instance.new("Part")
	anchor.Name = "MaisonWaypoint"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(point + Vector3.new(0, 3, 0))
	local to = Instance.new("Attachment")
	to.Name = "To"
	to.Parent = anchor
	local pin = Instance.new("BillboardGui")
	pin.Name = "Pin"
	pin.AlwaysOnTop = true
	pin.LightInfluence = 0
	pin.Size = UDim2.fromOffset(220, 64)
	pin.StudsOffset = Vector3.new(0, 3, 0)
	pin.Parent = anchor
	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.AnchorPoint = Vector2.new(0.5, 1)
	diamond.Position = UDim2.new(0.5, 0, 1, -4)
	diamond.Size = UDim2.fromOffset(14, 14)
	diamond.Rotation = 45
	diamond.BorderSizePixel = 0
	diamond.BackgroundColor3 = Brand.Colours.gold
	diamond.Parent = pin
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.fromScale(0.5, 0)
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.FontFace = Brand.Fonts.bodyMedium
	label.TextSize = 16
	label.TextColor3 = Brand.Colours.lightGold
	label.Text = name
	label.Parent = pin
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = label
	anchor.Parent = Workspace
	current = anchor
	-- The arc of light from the guest.
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local a = Instance.new("Attachment")
		a.Name = "MaisonWaypointFrom"
		a.Position = Vector3.new(0, -1.5, 0)
		a.Parent = root
		from = a
		local b = Instance.new("Beam")
		b.Name = "Guide"
		b.Attachment0 = a
		b.Attachment1 = to
		b.Color = ColorSequence.new(Brand.Colours.lightGold, Brand.Colours.gold)
		b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0.1) })
		b.LightEmission = 1
		b.LightInfluence = 0
		b.FaceCamera = true
		b.Width0 = 0.35
		b.Width1 = 0.35
		b.Segments = 24
		b.CurveSize0 = 6
		b.CurveSize1 = -2
		b.Parent = anchor
		beam = b
	end
end

return Waypoint

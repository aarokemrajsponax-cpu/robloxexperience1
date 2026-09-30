--!strict
-- The rival's brass plate (§9.6): a small plate on the rim of your table with your rival's name
-- and one fact. When you pass them it turns over, gold side up. Local to your screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)

local State = require(script.Parent.Parent.State)

local RivalPlate = {}

local T = Layout.Table
local ENGRAVED = Color3.fromRGB(58, 44, 18)
-- Like the case plates: tilted to face the seated camera, top edge toward the cases.
local TOWARD_CAMERA = Layout.towardCamera()
local UP_TOWARD_CASES = Vector3.new(0, 0, 1)

local plate: Part? = nil
local frame: CFrame? = nil
local turned = false

local function face(part: Part, normal: Enum.NormalId, title: string, fact: string, gold: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Name = if normal == Enum.NormalId.Front then "Front" else "Back"
	gui.Face = normal
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 120
	gui.LightInfluence = 0.6
	gui.Brightness = 1.2
	gui.Parent = part
	-- The turned side is gold leaf, polished bright.
	local leaf = Instance.new("Frame")
	leaf.Name = "Leaf"
	leaf.Size = UDim2.fromScale(1, 1)
	leaf.BorderSizePixel = 0
	leaf.BackgroundColor3 = Brand.Colours.lightGold
	leaf.BackgroundTransparency = if gold then 0 else 1
	leaf.Parent = gui
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 2)
	list.Parent = leaf
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(0.92, 0, 0.36, 0)
	head.FontFace = Brand.Fonts.bodyBold
	head.TextScaled = true
	head.TextColor3 = if gold then Brand.Colours.nearBlack else ENGRAVED
	head.Text = string.upper(title)
	head.LayoutOrder = 1
	head.Parent = leaf
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Size = UDim2.new(0.92, 0, 0.4, 0)
	line.FontFace = Brand.Fonts.display
	line.TextScaled = true
	line.TextColor3 = if gold then Brand.Colours.nearBlack else ENGRAVED
	line.Text = fact
	line.LayoutOrder = 2
	line.Parent = leaf
end

-- Where the plate rests: on the rim, to the right of the brass counter. Turned, it has spun
-- half a turn on its spindle so the gold side faces you.
local function restFor(f: CFrame, isTurned: boolean): CFrame
	local pos = f:PointToWorldSpace(Vector3.new(T.width / 2 - 1.6, T.topY + 0.3, T.counterZ))
	local cf = CFrame.lookAt(pos, pos + f:VectorToWorldSpace(TOWARD_CAMERA), f:VectorToWorldSpace(UP_TOWARD_CASES))
	return if isTurned then cf * CFrame.Angles(0, math.pi, 0) else cf
end

local function build(f: CFrame, info: { name: string, fact: string, ahead: boolean })
	local p = Instance.new("Part")
	p.Name = "RivalPlate"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(2.3, 0.62, 0.05)
	p.Material = Enum.Material.Metal
	p.Color = Brand.Colours.gold
	p.Reflectance = 0.08
	face(p, Enum.NormalId.Front, "Your rival · " .. info.name, info.fact, false)
	face(p, Enum.NormalId.Back, "Ahead of " .. info.name, info.fact, true)
	turned = info.ahead
	p.CFrame = restFor(f, turned)
	local folder = Workspace:FindFirstChild("MaisonLocal")
	p.Parent = folder or Workspace
	plate = p
end

local function clear()
	if plate then
		plate:Destroy()
		plate = nil
	end
end

-- Shows (or refreshes) the plate at a table, if the house has a rival for you this week.
function RivalPlate.show(f: CFrame)
	frame = f
	local info = State.rival
	clear()
	if info and State.get("rivalUpdates") ~= "Off" then
		build(f, info)
	end
end

function RivalPlate.hide()
	frame = nil
	clear()
end

-- A new fact: rewrite the plate, turning it over if you've just passed them.
local function update()
	local f = frame
	if not f then
		return
	end
	local info = State.rival
	if not info then
		clear()
		return
	end
	local wasTurned = turned
	clear()
	build(f, info)
	local p = plate
	if p and info.ahead and not wasTurned then
		p.CFrame = restFor(f, false)
		local value = Instance.new("NumberValue")
		value.Changed:Connect(function(a)
			if p.Parent then
				p.CFrame = restFor(f, false) * CFrame.new(0, math.sin(a) * 0.25, 0) * CFrame.Angles(0, a, 0)
			end
		end)
		local t = TweenService:Create(value, Ease.scaled(TweenInfo.new(0.9, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut)), { Value = math.pi })
		t.Completed:Once(function()
			value:Destroy()
			if p.Parent then
				p.CFrame = restFor(f, true)
			end
		end)
		t:Play()
	end
end

State.RivalChanged:Connect(update)

return RivalPlate

--!strict
-- The gilded round card: it slides and flips onto the felt showing the round in Roman numerals,
-- and lands again at the end of the round with the grade embossed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Closet = require(script.Parent.Parent.Closet)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)

local RoundCard = {}

local card: Part? = nil
local labels: { TextLabel } = {}

local function folder(): Instance
	local f = Workspace:FindFirstChild("MaisonLocal")
	if not f then
		local nf = Instance.new("Folder")
		nf.Name = "MaisonLocal"
		nf.Parent = Workspace
		f = nf
	end
	return f :: Instance
end

local function make(): Part
	local p = Instance.new("Part")
	p.Name = "RoundCard"
	p.Size = Vector3.new(2.6, 1.7, 0.05)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Color = Color3.fromRGB(236, 228, 210)
	p.Material = Enum.Material.SmoothPlastic
	p.CastShadow = true
	p.Parent = folder()
	-- Gilt edge
	local edge = Instance.new("SelectionBox")
	edge.Adornee = p
	edge.Color3 = Brand.Colours.gold
	edge.LineThickness = 0.025
	edge.SurfaceTransparency = 1
	edge.Parent = p
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 110
	gui.LightInfluence = 0.4
	gui.Parent = p
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.02, 0)
	list.Parent = gui
	labels = {}
	local specs: { { any } } = { { 0.16, Brand.Fonts.bodyMedium }, { 0.42, Brand.Fonts.display }, { 0.14, Brand.Fonts.body } }
	for i, spec in specs do
		local l = Instance.new("TextLabel")
		l.LayoutOrder = i
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(0.86, spec[1])
		l.FontFace = spec[2]
		l.TextScaled = true
		l.TextColor3 = if i == 2 then Brand.Colours.deepGold else Color3.fromRGB(70, 56, 30)
		l.Text = ""
		l.Parent = gui
		table.insert(labels, l)
	end
	local back = Instance.new("SurfaceGui")
	back.Face = Enum.NormalId.Back
	back.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	back.PixelsPerStud = 60
	back.Parent = p
	local pattern = Instance.new("Frame")
	pattern.Name = "Pattern"
	pattern.Size = UDim2.fromScale(1, 1)
	pattern.BackgroundColor3 = Color3.fromRGB(18, 16, 14)
	pattern.Parent = back
	local mono = Instance.new("TextLabel")
	mono.BackgroundTransparency = 1
	mono.Size = UDim2.fromScale(1, 1)
	mono.FontFace = Brand.Fonts.display
	mono.TextScaled = true
	mono.TextColor3 = Brand.Colours.gold
	mono.Text = "MN"
	mono.Parent = pattern
	return p
end

-- Face up on the felt, text reading toward the guest.
local function resting(frame: CFrame): CFrame
	local pos = frame:PointToWorldSpace(Vector3.new(0, Layout.Table.topY + 0.08, -0.9))
	return CFrame.lookAt(pos, pos + Vector3.new(0, 1, 0), frame:VectorToWorldSpace(Vector3.new(0, 0, 1)))
end

-- The back of the card in the guest's own style (a round-card back from the Boutique).
local function dressBack(p: Part)
	local back = p:FindFirstChildWhichIsA("SurfaceGui")
	for _, g in p:GetChildren() do
		if g:IsA("SurfaceGui") and g.Face == Enum.NormalId.Back then
			back = g
		end
	end
	local pattern = back and back:FindFirstChild("Pattern")
	if not pattern or not pattern:IsA("Frame") then
		return
	end
	local style = Closet.style("card")
	pattern.BackgroundColor3 = if style and typeof(style.back) == "Color3" then style.back else Color3.fromRGB(18, 16, 14)
	local stripes = pattern:FindFirstChild("Stripes")
	if stripes then
		stripes:Destroy()
	end
	if style and style.pattern == "pinstripe" then
		local holder = Instance.new("Frame")
		holder.Name = "Stripes"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = pattern
		for i = 1, 9 do
			local line = Instance.new("Frame")
			line.BorderSizePixel = 0
			line.BackgroundColor3 = Color3.fromRGB(210, 206, 196)
			line.BackgroundTransparency = 0.7
			line.Position = UDim2.fromScale(i / 10, 0)
			line.Size = UDim2.new(0, 1, 1, 0)
			line.Parent = holder
		end
	elseif style and style.pattern == "damask" then
		local g = Instance.new("UIGradient")
		g.Name = "Stripes"
		g.Rotation = 45
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		g.Parent = pattern
	end
end

function RoundCard.land(frame: CFrame, top: string, middle: string, bottom: string): Tween
	local p = card or make()
	card = p
	dressBack(p)
	labels[1].Text = Caps(top)
	labels[2].Text = middle
	labels[3].Text = bottom
	local goal = resting(frame)
	-- Start above and to the side, face down, then slide and flip onto the felt.
	p.CFrame = CFrame.new(goal.Position + frame:VectorToWorldSpace(Vector3.new(-4.5, 3, 1.5))) * goal.Rotation * CFrame.Angles(0, math.rad(179), 0)
	p.Transparency = 0
	local t = TweenService:Create(p, Ease.scaled(TweenInfo.new(0.95, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)), { CFrame = goal })
	t:Play()
	return t
end

-- Slides the card off the felt (when play begins).
function RoundCard.clear()
	local p = card
	if not p then
		return
	end
	local goal = p.CFrame + p.CFrame.RightVector * -6 + Vector3.new(0, 0.5, 0)
	local t = TweenService:Create(p, Ease.scaled(TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.In)), { CFrame = goal })
	t:Play()
	t.Completed:Once(function()
		if card == p and (p.CFrame.Position - goal.Position).Magnitude < 0.1 then
			p.Transparency = 1
			p.CFrame = CFrame.new(0, -500, 0)
		end
	end)
end

function RoundCard.destroy()
	if card then
		card:Destroy()
		card = nil
	end
end

return RoundCard

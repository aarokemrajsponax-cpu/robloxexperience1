--!strict
-- (Build 94) How things arrive on the screen, the house's way: a panel springs up out of a slight
-- shrink (a touch past full size, then settles), a notice drops in from above, a card slides in
-- from the side; and as each lands, a band of light sweeps once across its glass. Everything here
-- is looks only, scaled by the guest's motion setting (shared/Ease.motionScale: with reduced
-- motion, no sweep and next to no movement). Nothing waits on it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ease = require(ReplicatedStorage.Shared.Ease)

local Flourish = {}

local function scaleOf(f: GuiObject, name: string): UIScale
	local existing = f:FindFirstChild(name)
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local s = Instance.new("UIScale")
	s.Name = name
	s.Parent = f
	return s
end

-- A band of light swept once across `f` (inside it: clipped to its edges), after `delay`.
function Flourish.sheen(f: GuiObject, delay: number?)
	-- (Not where a list lays out what's inside: the sweep would take a place in it.)
	if Ease.motionScale < 0.3 or f:FindFirstChildWhichIsA("UIGridStyleLayout") then
		return
	end
	local clip = Instance.new("Frame")
	clip.Name = "Sheen"
	clip.BackgroundTransparency = 1
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	clip.ZIndex = 50
	clip.Active = false
	clip.Parent = f
	local band = Instance.new("Frame")
	band.Name = "Band"
	band.BackgroundColor3 = Color3.fromRGB(255, 246, 222)
	band.BackgroundTransparency = 0
	band.BorderSizePixel = 0
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Size = UDim2.new(0, 70, 2.2, 0)
	band.Position = UDim2.new(0, -80, 0.5, 0)
	band.Rotation = 20
	band.ZIndex = 50
	band.Parent = clip
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.84),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = band
	local t = Ease.play(band, Ease.scaled(TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, delay or 0.12)), { Position = UDim2.new(1, 80, 0.5, 0) })
	t.Completed:Once(function()
		clip:Destroy()
	end)
	-- (Gone in any case, whatever happened to the tween.)
	task.delay(1.4 + (delay or 0.12), function()
		if clip.Parent then
			clip:Destroy()
		end
	end)
end

-- A panel springing up: from a little smaller and lower, a touch past full size, settling.
function Flourish.pop(f: GuiObject, from: number?)
	local s = scaleOf(f, "OpenScale")
	s.Scale = from or 0.86
	Ease.play(s, Ease.scaled(TweenInfo.new(0.46, Enum.EasingStyle.Back, Enum.EasingDirection.Out)), { Scale = 1 })
end

-- A notice or card coming in from `offset` (pixels) to where it is now, springing a little.
function Flourish.slideIn(f: GuiObject, offset: Vector2)
	local at = f.Position
	f.Position = at + UDim2.fromOffset(offset.X, offset.Y)
	Ease.play(f, Ease.scaled(TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)), { Position = at })
	local s = scaleOf(f, "ArriveScale")
	s.Scale = 0.94
	Ease.play(s, Ease.scaled(TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out)), { Scale = 1 })
end

return Flourish

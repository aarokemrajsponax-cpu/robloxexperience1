--!strict
-- What the table says back, on the guest's screen. "Correct" and the points, over the case the
-- piece went into; "Wrong case · Try again" when it didn't (and the streak it cost); a streak
-- called out as it grows; and, when you sit, one line saying what to do and how. Every message is
-- big enough to read at a glance, arrives with a small pop, and is gone again in about a second.
-- While you sort, the edges of the screen darken a little, like a room when a game starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Parent.UI.Root)
local Theme = require(script.Parent.Parent.UI.Theme)
local State = require(script.Parent.Parent.State)

local SortFeedback = {}

local GOOD = Brand.Colours.lightGold
local BAD = Color3.fromRGB(240, 128, 104)
local INK = Color3.fromRGB(8, 8, 10)

local player = Players.LocalPlayer

local function localFolder(): Instance
	local f = Workspace:FindFirstChild("MaisonLocal")
	if f then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "MaisonLocal"
	nf.Parent = Workspace
	return nf
end

local function label(parent: Instance, text: string, size: number, kind: any, colour: Color3, order: number): TextLabel
	local l = Theme.text(parent, text, size, kind, {
		TextColor3 = colour,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, math.floor(size * 1.25)),
		TextWrapped = false,
	})
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 2
	stroke.Transparency = 0.35
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = l
	return l
end

local function fade(labels: { TextLabel }, seconds: number)
	for _, l in labels do
		Ease.play(l, Ease.info(seconds, Enum.EasingStyle.Sine), { TextTransparency = 1 })
		local stroke = l:FindFirstChildOfClass("UIStroke")
		if stroke then
			Ease.play(stroke, Ease.info(seconds, Enum.EasingStyle.Sine), { Transparency = 1 })
		end
	end
end

-- A floating card over a point on the table: pops in, drifts up, fades.
local function billboard(at: Vector3, lines: { { text: string, size: number, kind: string, colour: Color3 } }, wobble: boolean): BillboardGui
	local anchor = Instance.new("Part")
	anchor.Name = "VerdictAt"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = localFolder()
	local gui = Instance.new("BillboardGui")
	gui.Name = "Verdict"
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Size = UDim2.fromOffset(300, 110)
	gui.StudsOffset = Vector3.new(0, 1.0, 0)
	gui.Parent = anchor
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.fromScale(0.5, 1)
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local list = Theme.list(holder, 0)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local scale = Instance.new("UIScale")
	scale.Scale = 0.55
	scale.Parent = holder
	local made: { TextLabel } = {}
	for i, spec in lines do
		table.insert(made, label(holder, spec.text, spec.size, spec.kind, spec.colour, i))
	end
	local seconds = Config.data.Sorting.verdictSeconds
	Ease.play(scale, Ease.info(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	Ease.play(gui, Ease.info(seconds + 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(0, 1.8, 0) })
	if wobble and Ease.motionScale >= 0.5 then
		-- A short "no" shake of the words themselves.
		local steps = { -5, 4, -3, 2, 0 }
		for i, angle in steps do
			task.delay(0.05 * i, function()
				if holder.Parent then
					Ease.play(holder, Ease.info(0.05, Enum.EasingStyle.Sine), { Rotation = angle })
				end
			end)
		end
	end
	task.delay(seconds * 0.6, function()
		if gui.Parent then
			fade(made, seconds * 0.4 + 0.2)
		end
	end)
	task.delay(seconds + 0.45, function()
		anchor:Destroy()
	end)
	return gui
end

local function number(n: number): string
	local s = tostring(math.floor(math.abs(n) + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

-- "Correct", over the case. `points` is nil where the table counts pieces, not points.
function SortFeedback.correct(at: Vector3, points: number?, multiplier: number?)
	local lines = {
		{ text = string.upper(Voice.Sorting.correct), size = 30, kind = "bodyBold", colour = GOOD },
	}
	if points and points > 0 then
		local sub = "+" .. number(points)
		if multiplier and multiplier > 1 then
			sub ..= "   ×" .. tostring(multiplier)
		end
		table.insert(lines, { text = sub, size = 22, kind = "display", colour = Brand.Colours.bone })
	end
	billboard(at, lines, false)
end

-- "Wrong case · Try again", over the case it was dropped on.
function SortFeedback.wrong(at: Vector3, lostStreak: number, penalty: number?)
	local lines = {
		{ text = string.upper(Voice.Sorting.wrong), size = 28, kind = "bodyBold", colour = BAD },
		{ text = Voice.Sorting.tryAgain, size = 19, kind = "bodyMedium", colour = Brand.Colours.bone },
	}
	if lostStreak >= 2 then
		table.insert(lines, { text = (string.gsub(Voice.Sorting.streakLost, "{n}", tostring(lostStreak))), size = 15, kind = "body", colour = Brand.Colours.smoke })
	end
	if penalty and penalty > 0 then
		table.insert(lines, { text = "−" .. number(penalty), size = 18, kind = "display", colour = BAD })
	end
	billboard(at, lines, true)
end

-- A streak called out at the top of the screen, at the moments Config names.
local callout: CanvasGroup? = nil
function SortFeedback.isMoment(streak: number): boolean
	return table.find(Config.data.Sorting.streakMoments, streak) ~= nil
end

function SortFeedback.streak(streak: number, multiplier: number)
	if callout then
		callout:Destroy()
		callout = nil
	end
	local group, content = Theme.glass(Root.hud, "Streak", UDim2.fromOffset(340, 0), UDim2.new(0.5, 0, 0, 104), Vector2.new(0.5, 0))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local pad = content:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
	end
	Theme.list(content, 2)
	local title = string.gsub(Voice.Sorting.inARow, "{n}", tostring(streak))
	Theme.text(content, title, 13, "caps", { LayoutOrder = 1, TextColor3 = GOOD })
	local line = Voice.Sorting.moments[streak] or string.gsub(Voice.Sorting.multiplier, "{n}", tostring(multiplier))
	Theme.text(content, line, 22, "display", { LayoutOrder = 2 })
	-- A band of light runs across it once.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = GOOD
	shine.BackgroundTransparency = 0.8
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(1, 1)
	shine.ZIndex = 3
	shine.Parent = group
	local sweep = Instance.new("UIGradient")
	sweep.Rotation = 20
	sweep.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sweep.Offset = Vector2.new(-1, 0)
	sweep.Parent = shine
	Ease.play(sweep, Ease.info(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) })
	local scale = Instance.new("UIScale")
	scale.Scale = 0.86
	scale.Parent = group
	group.GroupTransparency = 1
	callout = group
	Ease.play(group, Ease.info(0.22, Enum.EasingStyle.Quad), { GroupTransparency = 0 })
	Ease.play(scale, Ease.info(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	task.delay(1.5, function()
		if callout ~= group then
			return
		end
		callout = nil
		Ease.play(scale, Ease.info(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.96 })
		local t = Ease.play(group, Ease.info(0.4, Enum.EasingStyle.Sine), { GroupTransparency = 1 })
		t.Completed:Once(function()
			group:Destroy()
		end)
	end)
end

-- One line, low on the screen, the first time you sit: what to do, and how, for the controls in
-- your hands. It goes after a few correct filings (or on its own after a while).
local hint: CanvasGroup? = nil
local hintLeft = 0

local function hideHint()
	local group = hint
	if not group then
		return
	end
	hint = nil
	local t = Ease.play(group, Ease.info(0.5, Enum.EasingStyle.Sine), { GroupTransparency = 1 })
	t.Completed:Once(function()
		group:Destroy()
	end)
end

function SortFeedback.showHint()
	hideHint()
	hintLeft = Config.data.Sorting.hintFilings
	local group, content = Theme.glass(Root.hud, "SortHint", UDim2.fromOffset(560, 0), UDim2.new(0.5, 0, 1, -18), Vector2.new(0.5, 1))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local pad = content:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
	end
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(math.min(560, Root.size().X - 24), math.huge)
	limit.Parent = group
	Theme.list(content, 4)
	Theme.text(content, Voice.Sorting.objective, 19, "display", { LayoutOrder = 1 })
	Theme.text(content, (Voice.Sorting.hints :: any)[State.inputKind()] or Voice.Sorting.hints.mouse, 14, "body", { LayoutOrder = 2, TextColor3 = Brand.Colours.smoke })
	group.GroupTransparency = 1
	hint = group
	Ease.play(group, Ease.scaled(Ease.settle), { GroupTransparency = 0 })
	task.delay(14, function()
		if hint == group then
			hideHint()
		end
	end)
end

function SortFeedback.filed(correct: boolean)
	if hint and correct then
		hintLeft -= 1
		if hintLeft <= 0 then
			hideHint()
		end
	end
end

-- The edges of the screen darken a touch while you sort.
local frameGui: ScreenGui? = nil
local bars: { Frame } = {}

local function makeFrame(): ScreenGui
	if frameGui and frameGui.Parent then
		return frameGui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MaisonSortFrame"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.Parent = player:WaitForChild("PlayerGui")
	bars = {}
	for _, top in { true, false } do
		local bar = Instance.new("Frame")
		bar.Name = if top then "Top" else "Bottom"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BackgroundTransparency = 1
		bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
		bar.Position = UDim2.fromScale(0, if top then 0 else 1)
		bar.Size = UDim2.fromScale(1, 0.18)
		local g = Instance.new("UIGradient")
		g.Rotation = if top then 90 else -90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = bar
		bar.Parent = gui
		table.insert(bars, bar)
	end
	frameGui = gui
	return gui
end

function SortFeedback.frame(on: boolean)
	makeFrame()
	for _, bar in bars do
		Ease.play(bar, Ease.info(if on then 0.9 else 0.6, Enum.EasingStyle.Sine), { BackgroundTransparency = if on then 0.5 else 1 })
	end
	if not on then
		hideHint()
		if callout then
			callout:Destroy()
			callout = nil
		end
	end
end

return SortFeedback

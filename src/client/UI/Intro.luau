--!strict
-- The intro (about six seconds): a gold hairline draws across the centre, MAISON NOIR tracks in
-- from wide letter-spacing to true, the credit fades up beneath, the copyright sits in the corner.
-- Fonts load first (with a time limit, so it can never hang or blink), it fits the smallest
-- phone at its widest frame, any tap or key skips it, and it leaves nothing behind.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)

local Intro = {}

local NAME = "MAISON NOIR"

local function tween(obj: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, delay: number?): Tween
	local t = TweenService:Create(obj, TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delay or 0), goal)
	t:Play()
	return t
end

-- A black cover shown straight away so the world never flashes before the intro.
local cover = Instance.new("Frame")
cover.Name = "Cover"
cover.BackgroundColor3 = Brand.Colours.nearBlack
cover.BorderSizePixel = 0
cover.Size = UDim2.fromScale(1, 1)
cover.ZIndex = 1
cover.Parent = Root.intro

function Intro.play(onShown: (() -> ())?)
	local size = Root.size()
	local group = Instance.new("CanvasGroup")
	group.Name = "Intro"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.ZIndex = 2
	group.Parent = Root.intro

	-- Letter geometry chosen so the widest frame still fits.
	local count = utf8.len(NAME) or #NAME
	local cellRatio = 0.78
	local textSize = math.floor(math.min(64, (size.X * 0.8) / (count * cellRatio + (count - 1) * 0.08)))
	local cell = textSize * cellRatio
	local tight = textSize * 0.08
	local wide = math.max(tight, math.min(textSize * 1.1, (size.X * 0.94 - count * cell) / (count - 1)))

	local row = Instance.new("Frame")
	row.Name = "Letters"
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.new(0.5, 0, 0.5, -textSize * 0.55)
	row.Size = UDim2.fromOffset(size.X, textSize * 1.3)
	row.Parent = group
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, wide)
	list.Parent = row

	local letters: { TextLabel } = {}
	local i = 0
	for _, cp in utf8.codes(NAME) do
		i += 1
		local ch = utf8.char(cp)
		local l = Instance.new("TextLabel")
		l.LayoutOrder = i
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromOffset(if ch == " " then cell * 0.45 else cell, textSize * 1.2)
		l.FontFace = Brand.Fonts.display
		l.TextSize = textSize
		l.TextColor3 = Brand.Colours.bone
		l.TextTransparency = 1
		l.Text = ch
		l.Parent = row
		table.insert(letters, l)
	end

	local line = Instance.new("Frame")
	line.Name = "Hairline"
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0.5, 0, 0.5, textSize * 0.35)
	line.Size = UDim2.fromOffset(0, 1)
	line.BackgroundColor3 = Brand.Colours.gold
	line.BorderSizePixel = 0
	line.Parent = group

	local credit = Instance.new("TextLabel")
	credit.Name = "Credit"
	credit.AnchorPoint = Vector2.new(0.5, 0)
	credit.Position = UDim2.new(0.5, 0, 0.5, textSize * 0.6)
	credit.Size = UDim2.fromOffset(size.X * 0.9, 24)
	credit.BackgroundTransparency = 1
	credit.FontFace = Brand.Fonts.body
	credit.TextSize = math.max(14, math.floor(textSize * 0.26))
	credit.TextColor3 = Brand.Colours.smoke
	credit.TextTransparency = 1
	credit.Text = Brand.Credit
	credit.Parent = group

	local copyright = Instance.new("TextLabel")
	copyright.Name = "Copyright"
	copyright.AnchorPoint = Vector2.new(1, 1)
	copyright.Position = UDim2.new(1, -20, 1, -16)
	copyright.Size = UDim2.fromOffset(200, 18)
	copyright.BackgroundTransparency = 1
	copyright.FontFace = Brand.Fonts.body
	copyright.TextSize = 13
	copyright.TextXAlignment = Enum.TextXAlignment.Right
	copyright.TextColor3 = Brand.Colours.dim
	copyright.TextTransparency = 1
	copyright.Text = Brand.copyright()
	copyright.Parent = group

	-- Load the intro's fonts first, but never wait more than 2.5 seconds.
	local loaded = false
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ letters[1], credit, copyright })
		end)
		loaded = true
	end)
	local limit = os.clock() + 2.5
	while not loaded and os.clock() < limit do
		task.wait()
	end

	if onShown then
		onShown()
	end

	local skipped = false
	local finished = false
	local skipConn = UserInputService.InputBegan:Connect(function(input)
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch or t == Enum.UserInputType.Keyboard or t == Enum.UserInputType.Gamepad1 then
			skipped = true
		end
	end)

	local function wait(seconds: number): boolean
		local untilTime = os.clock() + seconds
		while os.clock() < untilTime do
			if skipped then
				return false
			end
			task.wait()
		end
		return not skipped
	end

	task.spawn(function()
		if not wait(0.3) then
			return
		end
		tween(line, 1.1, { Size = UDim2.fromOffset(math.min(size.X * 0.36, 420), 1) }, Enum.EasingStyle.Quint)
		if not wait(0.6) then
			return
		end
		tween(list, 2.4, { Padding = UDim.new(0, tight) }, Enum.EasingStyle.Quint)
		for n, l in letters do
			tween(l, 1.4, { TextTransparency = 0 }, Enum.EasingStyle.Sine, (n - 1) * 0.03)
		end
		if not wait(1.8) then
			return
		end
		tween(credit, 1.0, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
		if not wait(0.4) then
			return
		end
		tween(copyright, 1.0, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
		if not wait(2.4) then
			return
		end
		finished = true
	end)

	while not finished and not skipped do
		task.wait()
	end
	skipConn:Disconnect()
	local fade = tween(group, if skipped then 0.35 else 0.7, { GroupTransparency = 1 }, Enum.EasingStyle.Sine)
	tween(cover, if skipped then 0.5 else 0.9, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	fade.Completed:Wait()
	group:Destroy()
end

-- Removes the cover without the intro (Studio, and respawns never replay it).
function Intro.clear()
	cover.BackgroundTransparency = 1
	cover.Visible = false
end

return Intro

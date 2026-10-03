--!strict
-- The intro (about six seconds): a gold hairline draws across the centre, "Maison Noir" settles
-- in beneath it in the house serif, the credit fades up beneath, the copyright sits in the corner.
-- Fonts load first (with a time limit, so it can never hang or blink), it fits the smallest
-- phone at its widest frame, any tap or key skips it, and it leaves nothing behind.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Root = require(script.Parent.Root)

local Intro = {}

local NAME = "Maison Noir"

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

	-- The name as the web edition sets it: "Maison Noir" in the house serif, a gold hairline above
	-- it, the credit in spaced capitals beneath. Sized so the widest frame still fits a phone.
	local textSize = math.floor(math.clamp(size.X * 0.105, 34, 96))

	local word = Instance.new("TextLabel")
	word.Name = "Name"
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.new(0.5, 0, 0.5, -textSize * 0.1)
	word.Size = UDim2.fromOffset(size.X, textSize * 1.3)
	word.BackgroundTransparency = 1
	word.FontFace = Brand.Fonts.display
	word.TextSize = textSize
	word.TextColor3 = Brand.Colours.bone
	word.TextTransparency = 1
	word.Text = NAME
	word.Parent = group
	local grow = Instance.new("UIScale")
	grow.Scale = 1.06
	grow.Parent = word
	local letters = { word }

	local line = Instance.new("Frame")
	line.Name = "Hairline"
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0.5, 0, 0.5, -textSize * 0.82)
	line.Size = UDim2.fromOffset(0, 1)
	line.BackgroundColor3 = Brand.Colours.gold
	line.BorderSizePixel = 0
	line.Parent = group
	local lineFade = Instance.new("UIGradient")
	lineFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	lineFade.Parent = line

	local credit = Instance.new("TextLabel")
	credit.Name = "Credit"
	credit.AnchorPoint = Vector2.new(0.5, 0)
	credit.Position = UDim2.new(0.5, 0, 0.5, textSize * 0.62)
	credit.Size = UDim2.fromOffset(size.X * 0.9, 24)
	credit.BackgroundTransparency = 1
	credit.FontFace = Brand.Fonts.body
	credit.TextSize = math.max(12, math.floor(textSize * 0.16))
	credit.TextColor3 = Brand.Colours.smoke
	credit.TextTransparency = 1
	local spaced = {}
	for _, cp in utf8.codes(Caps(Brand.Credit)) do
		local ch = utf8.char(cp)
		table.insert(spaced, if ch == " " then "  " else ch)
	end
	credit.Text = table.concat(spaced, " ")
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

	local function sequence()
		if not wait(0.3) then
			return
		end
		tween(line, 1.1, { Size = UDim2.fromOffset(math.min(size.X * 0.3, 360), 1) }, Enum.EasingStyle.Quint)
		if not wait(0.6) then
			return
		end
		tween(grow, 2.6, { Scale = 1 }, Enum.EasingStyle.Quint)
		tween(word, 1.6, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
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
	end
	-- Whatever happens in the sequence, the intro ends: a failed step finishes it at once.
	task.spawn(function()
		pcall(sequence)
		finished = true
	end)

	-- And never longer than this, so the house can't be left behind a black screen.
	local deadline = os.clock() + 9
	while not finished and not skipped and os.clock() < deadline do
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

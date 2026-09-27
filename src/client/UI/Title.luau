--!strict
-- The title floats over the live street at night: the name, the tagline, tonight's season and
-- its line, and three choices. The AJKR mark sits bottom-right on the title only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local Title = {}

local current: Frame? = nil

export type Choices = { play: () -> (), how: () -> (), board: () -> () }

function Title.show(choices: Choices)
	local frame = Instance.new("Frame")
	frame.Name = "Title"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = Root.hud
	current = frame

	-- A soft vignette so type reads over the street.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = Brand.Colours.nearBlack
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundTransparency = 0.35
	shade.Parent = frame
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.25),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	g.Parent = shade

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.52)
	column.Size = UDim2.new(0.9, 0, 0.9, 0)
	column.Parent = frame
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(620, 1000)
	sizeLimit.Parent = column
	Theme.list(column, 10)

	local size = Root.size()
	local nameSize = math.floor(math.min(58, size.X * 0.09))
	Theme.text(column, Brand.Name, nameSize, "display", { LayoutOrder = 1, TextColor3 = Brand.Colours.bone })
	Theme.hairline(column, UDim.new(0, 160), 2)
	Theme.text(column, Brand.Tagline, 16, "body", { LayoutOrder = 3, TextColor3 = Brand.Colours.smoke })

	local spacer = Instance.new("Frame")
	spacer.BackgroundTransparency = 1
	spacer.Size = UDim2.fromOffset(1, 8)
	spacer.LayoutOrder = 4
	spacer.Parent = column

	local seasonName = tostring(Workspace:GetAttribute("SeasonName") or "")
	local seasonLine = tostring(Workspace:GetAttribute("SeasonLine") or "")
	if seasonName ~= "" then
		Theme.text(column, seasonName, 12, "caps", { LayoutOrder = 5 })
		Theme.text(column, seasonLine, 15, "display", { LayoutOrder = 6, TextColor3 = Brand.Colours.lightGold })
	end

	local spacer2 = spacer:Clone()
	spacer2.Size = UDim2.fromOffset(1, 14)
	spacer2.LayoutOrder = 7
	spacer2.Parent = column

	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 8
	keys.Parent = column
	Theme.list(keys, 10)
	local play = Theme.key(keys, "Play", true, choices.play, 240)
	play.LayoutOrder = 1
	Theme.key(keys, "How to play", false, choices.how, 240).LayoutOrder = 2
	Theme.key(keys, "Leaderboard", false, choices.board, 240).LayoutOrder = 3

	-- The AJKR mark, bottom-right, title only.
	local mark = Instance.new("Frame")
	mark.Name = "Mark"
	mark.BackgroundTransparency = 1
	mark.AnchorPoint = Vector2.new(1, 1)
	mark.Position = UDim2.new(1, -18, 1, -14)
	mark.Size = UDim2.fromOffset(120, 44)
	mark.Parent = frame
	local markList = Theme.list(mark, 3)
	markList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	Theme.text(mark, Brand.Owner, 14, "display", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Brand.Colours.lightGold })
	Theme.hairline(mark, UDim.new(0, 40), 2)
	Theme.text(mark, "© " .. Brand.year(), 11, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Brand.Colours.dim })

	-- Fade in
	for _, d in frame:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local text = d :: any
			local goal = text.TextTransparency
			text.TextTransparency = 1
			Ease.play(d, Ease.info(1.2, Enum.EasingStyle.Sine), { TextTransparency = goal })
		end
	end
	local shadeGoal = shade.BackgroundTransparency
	shade.BackgroundTransparency = 1
	Ease.play(shade, Ease.info(1.2, Enum.EasingStyle.Sine), { BackgroundTransparency = shadeGoal })

	-- Gamepad: start on Play.
	task.defer(function()
		local GuiService = game:GetService("GuiService")
		pcall(function()
			GuiService.SelectedObject = play
		end)
	end)
end

function Title.hide()
	local frame = current
	if not frame then
		return
	end
	current = nil
	pcall(function()
		game:GetService("GuiService").SelectedObject = nil
	end)
	for _, d in frame:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			Ease.play(d, Ease.info(0.5, Enum.EasingStyle.Sine), { TextTransparency = 1, BackgroundTransparency = 1 })
		elseif d:IsA("Frame") and d.Name ~= "Column" and d.Name ~= "Keys" and d.Name ~= "Mark" then
			Ease.play(d, Ease.info(0.5, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			Ease.play(d, Ease.info(0.4, Enum.EasingStyle.Sine), { Transparency = 1 })
		end
	end
	task.delay(0.6, function()
		frame:Destroy()
	end)
end

function Title.isShowing(): boolean
	return current ~= nil
end

return Title

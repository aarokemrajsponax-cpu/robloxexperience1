--!strict
-- The Gilt bar: a guest's Gilt, Gems and level, live, in the top-left corner while they walk the
-- house. Gilt counts up (or down) as it changes, with the difference floating off it; the level
-- has its bar of XP to the next one. Tap the Gems for the Gem Shop, the level for the Badge Book.
-- A Gilt Surge or an XP Surge shows as a chip underneath with its time left.
-- It steps aside while the guest sorts at a table or has a panel (or a selection screen) open.
-- The numbers are the server's ("Gilt", "Gems", "Level", "LevelXP", "LevelNeed" on the player).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Levels = require(ReplicatedStorage.Shared.Levels)
local Root = require(script.Parent.Root)

local GiltBar = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local HEAVY = Font.fromEnum(Enum.Font.GothamBlack)
local BOLD = Font.fromEnum(Enum.Font.GothamBold)
local GOLD = rgb(255, 204, 90)

-- Set by Main.
GiltBar.openGems = function() end
GiltBar.openBadges = function() end
GiltBar.isBusy = function(): boolean
	return false
end

local bar: Frame? = nil
local chips: Frame? = nil
local seated = false

local function format(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end
GiltBar.format = format

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function attr(name: string): number
	local v = player:GetAttribute(name)
	return if type(v) == "number" then v else 0
end

-- Whether it shows: walking the house, nothing open over it.
function GiltBar.refresh()
	local b = bar
	local show = not seated and not Root.isOpen() and not GiltBar.isBusy()
	if b then
		b.Visible = show
	end
	local c = chips
	if c then
		c.Visible = show
	end
end

function GiltBar.setSeated(on: boolean)
	seated = on
	GiltBar.refresh()
end

-- A section of the bar, a set width: an icon, a number, optionally a button.
local function part(parent: Instance, order: number, icon: string, colour: Color3, name: string, width: number): (TextButton, TextLabel)
	local b = Instance.new("TextButton")
	b.Name = name
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.BackgroundTransparency = 1
	b.Text = ""
	b.Size = UDim2.fromOffset(width, 32)
	b.Parent = parent
	local i = Instance.new("TextLabel")
	i.Name = "Icon"
	i.BackgroundTransparency = 1
	i.AnchorPoint = Vector2.new(0, 0.5)
	i.Position = UDim2.fromScale(0, 0.5)
	i.Size = UDim2.fromOffset(22, 22)
	i.TextScaled = true
	i.Text = icon
	i.Parent = b
	local n = Instance.new("TextLabel")
	n.Name = "Value"
	n.BackgroundTransparency = 1
	n.AnchorPoint = Vector2.new(0, 0.5)
	n.Position = UDim2.new(0, 28, 0.5, 0)
	n.Size = UDim2.new(1, -28, 0, 26)
	n.FontFace = HEAVY
	n.TextScaled = true
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.TextColor3 = colour
	n.TextStrokeTransparency = 0.6
	n.Text = "0"
	n.Parent = b
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 20
	limit.Parent = n
	return b, n
end

-- "+25" floating up off a number, then gone.
local function float(over: GuiObject, text: string, colour: Color3)
	local b = bar
	if not b or not b.Visible then
		return
	end
	local f = Instance.new("TextLabel")
	f.Name = "Float"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromOffset(120, 22)
	f.FontFace = HEAVY
	f.TextSize = 18
	f.TextColor3 = colour
	f.TextStrokeTransparency = 0.3
	f.Text = text
	f.TextXAlignment = Enum.TextXAlignment.Left
	-- (Where the number sits along the bar; a little in from the left if that can't be read.)
	local ok, at = pcall(function()
		return over.AbsolutePosition - b.AbsolutePosition
	end)
	local x = if ok and typeof(at) == "Vector2" then at.X / math.max(0.1, Root.scale) else 40
	f.Position = UDim2.fromOffset(x, 34)
	f.Parent = b
	TweenService:Create(f, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = f.Position + UDim2.fromOffset(0, 26), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.2, function()
		f:Destroy()
	end)
end

function GiltBar.start()
	local frame = Instance.new("Frame")
	frame.Name = "GiltBar"
	frame.BackgroundColor3 = rgb(14, 12, 10)
	frame.BackgroundTransparency = 0.12
	frame.Position = UDim2.fromOffset(12, 10)
	-- (Set widths: Gilt to a million and more, Gems, then the level.)
	frame.Size = UDim2.fromOffset(12 + 132 + 14 + 96 + 14 + 160 + 14, 44)
	frame.Parent = Root.hud
	corner(frame, 22)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = GOLD
	edge.Thickness = 1.5
	edge.Transparency = 0.2
	edge.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = frame
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 14)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	bar = frame

	local _giltKey, giltValue = part(frame, 1, "🪙", rgb(255, 214, 110), "Gilt", 132)
	local gemsKey, gemsValue = part(frame, 2, "💎", rgb(150, 220, 255), "Gems", 96)
	gemsKey.Activated:Connect(function()
		GiltBar.openGems()
	end)
	-- The level: a disc in its tier's colour, and the bar of XP to the next.
	local levelKey = Instance.new("TextButton")
	levelKey.Name = "Level"
	levelKey.LayoutOrder = 3
	levelKey.AutoButtonColor = false
	levelKey.BackgroundTransparency = 1
	levelKey.Text = ""
	levelKey.Size = UDim2.fromOffset(160, 32)
	levelKey.Parent = frame
	levelKey.Activated:Connect(function()
		GiltBar.openBadges()
	end)
	local disc = Instance.new("TextLabel")
	disc.Name = "Disc"
	disc.Size = UDim2.fromOffset(32, 32)
	disc.BackgroundColor3 = rgb(24, 20, 16)
	disc.FontFace = HEAVY
	disc.TextScaled = true
	disc.Text = "1"
	disc.Parent = levelKey
	corner(disc, 16)
	local discEdge = Instance.new("UIStroke")
	discEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	discEdge.Thickness = 2
	discEdge.Parent = disc
	local dp = Instance.new("UIPadding")
	dp.PaddingLeft = UDim.new(0, 5)
	dp.PaddingRight = UDim.new(0, 5)
	dp.PaddingTop = UDim.new(0, 6)
	dp.PaddingBottom = UDim.new(0, 6)
	dp.Parent = disc
	-- Its name on top; the bar under it, with the XP written on the bar.
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(40, 0)
	title.Size = UDim2.new(1, -40, 0, 14)
	title.FontFace = BOLD
	title.TextSize = 12
	title.TextColor3 = rgb(236, 226, 206)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Text = "NEWCOMER"
	title.Parent = levelKey
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(40, 17)
	track.Size = UDim2.new(1, -40, 0, 15)
	track.BackgroundColor3 = rgb(40, 36, 32)
	track.Parent = levelKey
	corner(track, 7)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.Parent = track
	corner(fill, 7)
	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.BackgroundTransparency = 1
	amount.Size = UDim2.fromScale(1, 1)
	amount.ZIndex = 2
	amount.FontFace = HEAVY
	amount.TextScaled = true
	amount.TextColor3 = Color3.new(1, 1, 1)
	amount.TextStrokeTransparency = 0.3
	amount.Text = ""
	amount.Parent = track
	local ap = Instance.new("UIPadding")
	ap.PaddingTop = UDim.new(0, 2)
	ap.PaddingBottom = UDim.new(0, 2)
	ap.PaddingLeft = UDim.new(0, 6)
	ap.PaddingRight = UDim.new(0, 6)
	ap.Parent = amount
	local al = Instance.new("UITextSizeConstraint")
	al.MaxTextSize = 11
	al.Parent = amount

	-- Surges: a chip under the bar each, with its time left (beside the bar, not in its row).
	local surges = Instance.new("Frame")
	surges.Name = "Surges"
	surges.BackgroundTransparency = 1
	surges.Position = UDim2.fromOffset(14, 60)
	surges.Size = UDim2.fromOffset(300, 22)
	surges.Parent = Root.hud
	chips = surges
	local sl = Instance.new("UIListLayout")
	sl.FillDirection = Enum.FillDirection.Horizontal
	sl.Padding = UDim.new(0, 6)
	sl.Parent = surges
	local function surgeChip(name: string, text: string, colour: Color3): TextLabel
		local c = Instance.new("TextLabel")
		c.Name = name
		c.AutomaticSize = Enum.AutomaticSize.X
		c.Size = UDim2.fromOffset(0, 22)
		c.BackgroundColor3 = colour
		c.FontFace = HEAVY
		c.TextSize = 12
		c.TextColor3 = rgb(16, 12, 8)
		c.Text = text
		c.Visible = false
		c.Parent = surges
		corner(c, 11)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, 8)
		p.PaddingRight = UDim.new(0, 8)
		p.Parent = c
		return c
	end
	local giltSurge = surgeChip("GiltSurge", "", rgb(255, 214, 110))
	local xpSurge = surgeChip("XPSurge", "", rgb(150, 220, 255))

	-- The numbers, counting to where the server says.
	local shownGilt = attr("Gilt")
	local targetGilt = shownGilt
	giltValue.Text = format(shownGilt)
	local function drawGems()
		gemsValue.Text = format(attr("Gems"))
	end
	local function drawLevel()
		local level = math.clamp(attr("Level"), 1, Levels.MAX)
		local into = attr("LevelXP")
		-- (Until the server has said, the size of the next level comes from the curve.)
		local said = player:GetAttribute("LevelNeed")
		local need = if type(said) == "number" then said elseif level < Levels.MAX then Levels.total(level + 1) - Levels.total(level) else 0
		disc.Text = tostring(level)
		disc.TextColor3 = Levels.colour(level)
		discEdge.Color = Levels.colour(level)
		title.Text = string.upper(Levels.title(level))
		amount.Text = if need > 0 then string.format("%s / %s XP", format(into), format(need)) else "MAX LEVEL"
		fill.BackgroundColor3 = Levels.colour(level)
		local f = if need > 0 then math.clamp(into / need, 0, 1) else 1
		TweenService:Create(fill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(f, 1) }):Play()
	end
	player:GetAttributeChangedSignal("Gilt"):Connect(function()
		local new = attr("Gilt")
		local diff = new - targetGilt
		targetGilt = new
		if diff ~= 0 then
			float(giltValue, (if diff > 0 then "+" else "−") .. format(math.abs(diff)), if diff > 0 then rgb(255, 230, 140) else rgb(255, 140, 140))
		end
	end)
	player:GetAttributeChangedSignal("Gems"):Connect(drawGems)
	for _, a in { "Level", "LevelXP", "LevelNeed" } do
		player:GetAttributeChangedSignal(a):Connect(drawLevel)
	end
	drawGems()
	drawLevel()
	RunService.RenderStepped:Connect(function(dt: number)
		if shownGilt ~= targetGilt then
			local step = (targetGilt - shownGilt) * math.min(1, dt * 8)
			if math.abs(targetGilt - shownGilt) < 1 or math.abs(step) < 0.5 then
				shownGilt = targetGilt
			else
				shownGilt += step
			end
			giltValue.Text = format(shownGilt)
		end
	end)
	task.spawn(function()
		while frame.Parent do
			local now = Workspace:GetServerTimeNow()
			local g = player:GetAttribute("GiltSurgeUntil")
			local x = player:GetAttribute("XPSurgeUntil")
			giltSurge.Visible = type(g) == "number" and g > now
			if giltSurge.Visible then
				local left = math.floor((g :: number) - now)
				giltSurge.Text = string.format("🪙 ×1.5 GILT  %d:%02d", left // 60, left % 60)
			end
			xpSurge.Visible = type(x) == "number" and x > now
			if xpSurge.Visible then
				local left = math.floor((x :: number) - now)
				xpSurge.Text = string.format("⭐ ×2 XP  %d:%02d", left // 60, left % 60)
			end
			task.wait(1)
		end
	end)
	Root.PanelsChanged:Connect(GiltBar.refresh)
	GiltBar.refresh()
end

return GiltBar

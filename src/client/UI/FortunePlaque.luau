--!strict
-- The Fortune plaque: a guest's Fortune and wealth rank, live, just under the Gilt bar while they
-- walk the house. What the whole house is about, always in sight. The number is the server's (the
-- player's "Fortune" and "FortuneRank"); it counts up as it grows. Tap it for the Fortune screen
-- (the rank ladder, what the Fortune is made of, the Wealthiest boards). It goes wherever the Gilt
-- bar goes: away at a table, behind a panel, and folded away with the bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local GiltBar = require(script.Parent.GiltBar)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local FortunePlaque = {}

-- Set by Main: open the Fortune screen, and the Badge Book (where the level is explained).
FortunePlaque.open = function() end
FortunePlaque.openLevel = function() end

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 204, 90)
local HEIGHT = 32 -- (Build 88: a little bigger: the Fortune is what the house is about)
FortunePlaque.TOP = 58 -- under the Gilt bar (10 + 44 + 4)
FortunePlaque.BOTTOM = FortunePlaque.TOP + HEIGHT

local plaque: TextButton? = nil
local levelPill: TextButton? = nil -- (the level pill beside it)

-- (Build 90) What the guiding hand points at: the plaque, and the level pill beside it.
function FortunePlaque.target(): GuiObject?
	return plaque
end
function FortunePlaque.levelTarget(): GuiObject?
	local p = levelPill
	return if p and p.Visible then p else nil
end
local figure: TextLabel? = nil
local rankLabel: TextLabel? = nil
local fill: Frame? = nil
local shownValue = 0
local target = 0

local function attr(name: string): number
	local v = player:GetAttribute(name)
	return if type(v) == "number" and v == v then v else 0
end

local function draw()
	local f, r, bar = figure, rankLabel, fill
	pcall(function()
		(FortunePlaque :: any).placePill()
	end)
	if f then
		f.Text = Rules.format(shownValue)
	end
	local rank = Rules.rank(target)
	if r then
		r.Text = string.upper(rank.name)
	end
	if bar then
		bar.Size = UDim2.new(Rules.progress(target), 0, 1, 0)
	end
end

local function follow()
	local p = plaque
	if not p then
		return
	end
	local bar = Root.hud:FindFirstChild("GiltBar")
	p.Visible = if bar and bar:IsA("GuiObject") then bar.Visible else not Root.isOpen()
	local lp = levelPill
	if lp then
		lp.Visible = p.Visible
	end
end

-- (Build 88) The level, always in sight beside the Fortune (the Gilt bar's own level key steps
-- aside on most screens): a disc in the level's tier colour, its title, and a hair of XP to the
-- next along its foot. Tap it for the Badge Book.
local levelDisc: TextLabel? = nil
local levelTitle: TextLabel? = nil
local levelFill: Frame? = nil
local function drawLevel()
	local level = math.clamp(math.floor(attr("Level")), 1, Levels.MAX)
	local into = attr("LevelXP")
	local said = player:GetAttribute("LevelNeed")
	local need = if type(said) == "number" then said elseif level < Levels.MAX then Levels.total(level + 1) - Levels.total(level) else 0
	local colour = Levels.colour(level)
	local d, t, f = levelDisc, levelTitle, levelFill
	if d then
		d.Text = tostring(level)
		d.TextColor3 = colour
		local stroke = d:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = colour
		end
	end
	if t then
		t.Text = "LEVEL " .. level .. "  ·  " .. string.upper(Levels.title(level))
	end
	if f then
		f.BackgroundColor3 = colour
		f.Size = UDim2.new(if need > 0 then math.clamp(into / need, 0, 1) else 1, 0, 1, 0)
	end
end
FortunePlaque.drawLevel = drawLevel

function FortunePlaque.start()
	local b = Instance.new("TextButton")
	b.Name = "FortunePlaque"
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Color3.fromRGB(16, 13, 9)
	b.BackgroundTransparency = 0.08
	b.Position = UDim2.fromOffset(12, FortunePlaque.TOP)
	b.Size = UDim2.fromOffset(0, HEIGHT)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Parent = Root.hud
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, HEIGHT / 2)
	corner.Parent = b
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = GOLD
	edge.Thickness = 1.25
	edge.Transparency = 0.25
	edge.Parent = b
	-- Its words in a row of their own (the hair of gold along its foot lies outside the row).
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Size = UDim2.fromOffset(0, HEIGHT)
	row.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = row
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local function word(name: string, text: string, size: number, font: Font, colour: Color3, order: number): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.fromOffset(0, HEIGHT)
		l.FontFace = font
		l.TextSize = size
		l.TextColor3 = colour
		l.Text = text
		l.LayoutOrder = order
		l.Parent = row
		return l
	end
	word("Caption", "FORTUNE", 12, Brand.Fonts.heavy, GOLD, 1)
	figure = word("Figure", "0", 18, Brand.Fonts.figures, Color3.new(1, 1, 1), 2)
	rankLabel = word("Rank", "NEWCOMER", 11, Brand.Fonts.bodyBold, GOLD, 3)
	-- How far through the rank, as a hair of gold along the foot of the plaque.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 12, 1, -3)
	track.Size = UDim2.new(1, -24, 0, 2)
	track.BackgroundColor3 = Color3.fromRGB(60, 48, 26)
	track.BorderSizePixel = 0
	track.Parent = b
	local bar = Instance.new("Frame")
	bar.Name = "Fill"
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = GOLD
	bar.BorderSizePixel = 0
	bar.Parent = track
	fill = bar
	plaque = b
	b.Activated:Connect(function()
		Theme.haptic()
		FortunePlaque.open()
	end)
	-- The level pill, just right of the plaque (placed each time the plaque's width changes).
	local lp = Instance.new("TextButton")
	lp.Name = "LevelPill"
	lp.AutoButtonColor = false
	lp.Text = ""
	lp.BackgroundColor3 = Color3.fromRGB(16, 13, 9)
	lp.BackgroundTransparency = 0.08
	lp.Size = UDim2.fromOffset(0, HEIGHT)
	lp.AutomaticSize = Enum.AutomaticSize.X
	lp.Parent = Root.hud
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, HEIGHT / 2)
	lc.Parent = lp
	local ls = Instance.new("UIStroke")
	ls.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ls.Color = Color3.fromRGB(150, 140, 124)
	ls.Transparency = 0.4
	ls.Parent = lp
	local lrow = Instance.new("Frame")
	lrow.BackgroundTransparency = 1
	lrow.AutomaticSize = Enum.AutomaticSize.X
	lrow.Size = UDim2.fromOffset(0, HEIGHT)
	lrow.Parent = lp
	local lpad = Instance.new("UIPadding")
	lpad.PaddingLeft = UDim.new(0, 4)
	lpad.PaddingRight = UDim.new(0, 12)
	lpad.Parent = lrow
	local llist = Instance.new("UIListLayout")
	llist.FillDirection = Enum.FillDirection.Horizontal
	llist.VerticalAlignment = Enum.VerticalAlignment.Center
	llist.Padding = UDim.new(0, 7)
	llist.SortOrder = Enum.SortOrder.LayoutOrder
	llist.Parent = lrow
	local disc = Instance.new("TextLabel")
	disc.Name = "Disc"
	disc.Size = UDim2.fromOffset(HEIGHT - 8, HEIGHT - 8)
	disc.BackgroundColor3 = Color3.fromRGB(26, 22, 18)
	disc.FontFace = Brand.Fonts.heavy
	disc.TextSize = 12
	disc.Text = "1"
	disc.LayoutOrder = 1
	disc.Parent = lrow
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = disc
	local ds = Instance.new("UIStroke")
	ds.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ds.Thickness = 2
	ds.Parent = disc
	levelDisc = disc
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.fromOffset(0, HEIGHT)
	title.FontFace = Brand.Fonts.bodyBold
	title.TextSize = 11
	title.TextColor3 = Color3.fromRGB(236, 228, 214)
	title.Text = "LEVEL 1"
	title.LayoutOrder = 2
	title.Parent = lrow
	levelTitle = title
	local ltrack = Instance.new("Frame")
	ltrack.Name = "Track"
	ltrack.AnchorPoint = Vector2.new(0, 1)
	ltrack.Position = UDim2.new(0, HEIGHT, 1, -3)
	ltrack.Size = UDim2.new(1, -HEIGHT - 12, 0, 2)
	ltrack.BackgroundColor3 = Color3.fromRGB(56, 50, 42)
	ltrack.BorderSizePixel = 0
	ltrack.Parent = lp
	local lfill = Instance.new("Frame")
	lfill.Name = "Fill"
	lfill.Size = UDim2.new(0, 0, 1, 0)
	lfill.BorderSizePixel = 0
	lfill.Parent = ltrack
	levelFill = lfill
	levelPill = lp
	lp.Activated:Connect(function()
		Theme.haptic()
		FortunePlaque.openLevel()
	end)
	-- (Placed by the width of the plaque's own words, measured: it grows as the figure does.)
	local function placePill()
		local w = 24 + 16
		for _, name in { "Caption", "Figure", "Rank" } do
			local l = row:FindFirstChild(name)
			if l and l:IsA("TextLabel") then
				w += Theme.measure(l.Text, l.TextSize, l.FontFace).X
			end
		end
		lp.Position = UDim2.fromOffset(12 + math.ceil(w) + 8, FortunePlaque.TOP)
	end
	FortunePlaque.placePill = placePill
	placePill()
	for _, a in { "Level", "LevelXP", "LevelNeed" } do
		player:GetAttributeChangedSignal(a):Connect(drawLevel)
	end
	drawLevel()

	target = attr("Fortune")
	shownValue = target
	draw()
	player:GetAttributeChangedSignal("Fortune"):Connect(function()
		target = attr("Fortune")
	end)
	player:GetAttributeChangedSignal("FortuneRank"):Connect(draw)
	-- The figure counts toward the server's number: quickly, then settling on it exactly.
	RunService.Heartbeat:Connect(function(dt: number)
		if shownValue == target then
			return
		end
		local gap = target - shownValue
		local step = gap * math.min(1, dt * 6)
		if math.abs(gap) < 1.5 then
			shownValue = target
		else
			shownValue = math.floor(shownValue + (if step > 0 then math.max(1, step) else math.min(-1, step)) + 0.5)
		end
		draw()
	end)
	local gilt = Root.hud:FindFirstChild("GiltBar")
	if gilt and gilt:IsA("GuiObject") then
		gilt:GetPropertyChangedSignal("Visible"):Connect(follow)
	end
	Root.PanelsChanged:Connect(follow)
	-- (Told directly whenever the bar shows or hides: seated at a table, the plaque goes with it.)
	GiltBar.shown = follow
	follow()
end

-- For the pieces that stand under it: whether it's showing now.
function FortunePlaque.showing(): boolean
	local p = plaque
	return p ~= nil and p.Visible
end

return FortunePlaque

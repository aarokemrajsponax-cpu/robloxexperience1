--!strict
-- Maison Prestige on a guest's screen (shared/Prestige): the laurel they hold, how many laurel
-- points they have and what the next laurel asks for (its points, and from the fourth laurel its
-- great deed, shown ticked or not), then the ten laurels in order, each with its medallion, its
-- needs and what it brings, the ones held marked with the day they came. Every figure is the
-- server's (EmpireAsk "prestige"); the Laurel Flourish asks the server, which decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Prestige)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local PrestigePanel = {}

local NAME = "PrestigeCard"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("EmpireAsk"):InvokeServer(request)
	end)
	if ok and type(r) == "table" then
		return r
	end
	return nil
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- A laurel's medallion: its numeral in its colour, ringed; dimmed when not yet held.
local function medallion(parent: Instance, l: Rules.Level, held: boolean, size: number): TextLabel
	local m = Instance.new("TextLabel")
	m.Name = "Medallion"
	m.Size = UDim2.fromOffset(size, size)
	m.BackgroundColor3 = Color3.fromRGB(18, 15, 11)
	m.BackgroundTransparency = if held then 0 else 0.35
	m.FontFace = Brand.Fonts.display
	m.TextScaled = true
	m.TextColor3 = if held then l.colour else l.colour:Lerp(Color3.fromRGB(90, 86, 80), 0.6)
	m.Text = l.numeral
	m.Parent = parent
	corner(m, size // 2)
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Thickness = if held then 2.5 else 1.5
	ring.Color = m.TextColor3
	ring.Transparency = if held then 0 else 0.3
	ring.Parent = m
	local pad = Instance.new("UIPadding")
	local inset = math.floor(size * 0.24)
	pad.PaddingTop = UDim.new(0, inset)
	pad.PaddingBottom = UDim.new(0, inset)
	pad.PaddingLeft = UDim.new(0, inset - 2)
	pad.PaddingRight = UDim.new(0, inset - 2)
	pad.Parent = m
	return m
end

local function dateOf(t: number): string
	local d = os.date("*t", t) :: any
	return string.format("%d %s %d", d.day, MONTHS[d.month] or "", d.year)
end

-- One laurel on the ladder.
local function rung(parent: Instance, order: number, row: { [string]: any }, points: number)
	local l = Rules.get(tonumber(row.level) or 0)
	if not l then
		return
	end
	local held = row.held == true
	local f = Instance.new("Frame")
	f.Name = "Laurel" .. tostring(l.level)
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = if held then 0.94 else 0.975
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.new(1, 0, 0, 0)
	f.LayoutOrder = order
	f.Parent = parent
	corner(f, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = f
	if held then
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = l.colour
		edge.Transparency = 0.55
		edge.Parent = f
	end
	local m = medallion(f, l, held, 40)
	m.Position = UDim2.fromOffset(0, 0)
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(54, 0)
	words.Size = UDim2.new(1, -54, 0, 0)
	words.AutomaticSize = Enum.AutomaticSize.Y
	words.Parent = f
	Theme.list(words, 2).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(words, l.name, 15, "bodyBold", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if held then l.colour else C.bone, Size = UDim2.new(1, 0, 0, 19), AutomaticSize = Enum.AutomaticSize.None })
	local needs = string.format("%d laurel points", l.points)
	if type(row.milestone) == "string" then
		needs ..= "  ·  " .. (if row.milestoneMet then "✓ " else "") .. row.milestone
	end
	Theme.text(words, needs, 12, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = if row.milestoneMet or not row.milestone then C.smoke else C.lightGold, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	Theme.text(words, table.concat(l.rewards, "  ·  "), 12, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = if held then C.bone else C.smoke, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	local state = if held and type(row.since) == "number" then "Held since " .. dateOf(row.since) elseif held then "Held" elseif points >= l.points then "Points reached: the deed remains" else string.format("%d more points", l.points - points)
	Theme.text(words, state, 11, "caps", { LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if held then GOLD else C.smoke, Size = UDim2.new(1, 0, 0, 15), AutomaticSize = Enum.AutomaticSize.None })
end

function PrestigePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = Root.panelWidth(560)
	local h = math.min(700, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Maison Prestige", 11, "caps", { LayoutOrder = 1 })
	local title = Theme.text(content, "One moment.", 26, "display", { LayoutOrder = 2 })
	Theme.text(content, "Ten laurels, earned for good: nothing you own is ever reset. Every badge earns laurel points by its tier, and from the Gold Laurel on, each laurel also asks for one great deed.", 13, "body", { LayoutOrder = 3, TextColor3 = C.smoke, TextWrapped = true })

	-- Where the guest stands: points, and a bar to the next laurel.
	local standing = Instance.new("Frame")
	standing.Name = "Standing"
	standing.BackgroundTransparency = 1
	standing.Size = UDim2.new(1, 0, 0, 0)
	standing.AutomaticSize = Enum.AutomaticSize.Y
	standing.LayoutOrder = 4
	standing.Parent = content
	Theme.list(standing, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	local pointsLine = Theme.text(standing, "", 14, "bodyBold", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = GOLD })
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	track.BackgroundTransparency = 0.9
	track.Size = UDim2.new(1, 0, 0, 6)
	track.LayoutOrder = 2
	track.Parent = standing
	corner(track, 3)
	local fillBar = Instance.new("Frame")
	fillBar.Name = "Fill"
	fillBar.BackgroundColor3 = GOLD
	fillBar.Size = UDim2.new(0, 0, 1, 0)
	fillBar.Parent = track
	corner(fillBar, 3)
	local deedLine = Theme.text(standing, "", 12, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = C.smoke })

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Ladder"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 5
	scroll.Size = UDim2.new(1, 0, 1, -(18 + 34 + 52 + 70 + 56 + 40))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = C.gold
	scroll.Parent = content
	Theme.list(scroll, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	local spad = Instance.new("UIPadding")
	spad.PaddingRight = UDim.new(0, 8)
	spad.Parent = scroll

	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 6
	keys.Parent = content
	local row = Theme.list(keys, 10, true)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local flourish = Theme.key(keys, "The Laurel Flourish", false, function()
		task.spawn(function()
			local r = ask({ op = "flourish" })
			if not r then
				Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
			elseif r.ok ~= true then
				Toast.show("Not yet", tostring(r.why or "Not just now."), 3)
			else
				Theme.haptic()
			end
		end)
	end, 210)
	flourish.LayoutOrder = 1
	flourish.Visible = false
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 160)
	close.LayoutOrder = 2

	local function fill(v: { [string]: any })
		local level = tonumber(v.level) or 0
		local points = tonumber(v.points) or 0
		local held = Rules.get(level)
		title.Text = if held then held.name else "No laurel yet"
		title.TextColor3 = if held then held.colour else C.bone
		local nxt = v.next
		if type(nxt) == "table" then
			local target = Rules.get(tonumber(nxt.level) or 0)
			local from = if held then held.points else 0
			local to = if target then target.points else from + 1
			pointsLine.Text = string.format("%d laurel points  ·  %s", points, if (tonumber(nxt.short) or 0) > 0 then string.format("%d more for the %s", tonumber(nxt.short) or 0, tostring(nxt.name)) else "enough points for the " .. tostring(nxt.name))
			fillBar.Size = UDim2.new(math.clamp((points - from) / math.max(1, to - from), 0, 1), 0, 1, 0)
			fillBar.BackgroundColor3 = if target then target.colour else GOLD
			if type(nxt.milestone) == "string" then
				deedLine.Text = (if nxt.milestoneMet then "✓ Its great deed is done: " else "Its great deed: ") .. nxt.milestone .. "."
				deedLine.TextColor3 = if nxt.milestoneMet then C.smoke else C.lightGold
			else
				deedLine.Text = "Earn badges anywhere in the house: the Badge Book shows what each is for."
				deedLine.TextColor3 = C.smoke
			end
		else
			pointsLine.Text = string.format("%d laurel points  ·  every laurel is yours", points)
			fillBar.Size = UDim2.new(1, 0, 1, 0)
			fillBar.BackgroundColor3 = if held then held.colour else GOLD
			deedLine.Text = "The house has nothing higher to give."
		end
		flourish.Visible = v.flourish == true
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for i, r in (if type(v.levels) == "table" then v.levels else {}) do
			rung(scroll, i, r, points)
		end
	end

	Theme.fillRest(scroll)
	Root.open(NAME, group)
	task.spawn(function()
		local r = ask({ op = "prestige" })
		if not group.Parent then
			return
		end
		if r and r.ok == true then
			fill(r)
		else
			title.Text = "Maison Prestige"
			deedLine.Text = "The ladder couldn't be read just now. Try again in a moment."
		end
	end)
end

function PrestigePanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

return PrestigePanel

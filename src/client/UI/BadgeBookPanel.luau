--!strict
-- The Badge Book: every badge in the house, which you've earned (and when), and how far along
-- each ladder you are (12 / 50 rounds...). A row of groups along the top; the badges below, the
-- earned ones lit in their tier's colour (bronze, silver, gold, platinum), the rest waiting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BadgeBook = require(ReplicatedStorage.Shared.BadgeBook)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local BadgeBookPanel = {}

local NAME = "BadgeBook"
local rgb = Color3.fromRGB
local HEAVY = Font.fromEnum(Enum.Font.GothamBlack)
local BODY = Font.fromEnum(Enum.Font.GothamMedium)
local group = "all"

BadgeBookPanel.TierColour = {
	bronze = rgb(205, 127, 72),
	silver = rgb(200, 206, 216),
	gold = rgb(246, 200, 92),
	platinum = rgb(150, 230, 255),
} :: { [string]: Color3 }

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function format(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

function BadgeBookPanel.open()
	if Root.isOpen(NAME) then
		Root.close(NAME)
		return
	end
	local size = Root.size()
	local w = math.min(820, size.X - 24)
	local h = math.min(660, size.Y - 40)
	local panel, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Badge Book", 26, "display", { LayoutOrder = 1 })
	local summary = Theme.text(content, "Opening the book…", 13, "body", { LayoutOrder = 2, TextColor3 = Brand.Colours.smoke })
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "Groups"
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.ScrollBarThickness = 0
	tabs.Size = UDim2.new(1, 0, 0, 36)
	tabs.CanvasSize = UDim2.new()
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabs.LayoutOrder = 3
	tabs.Parent = content
	local tl = Instance.new("UIListLayout")
	tl.FillDirection = Enum.FillDirection.Horizontal
	tl.Padding = UDim.new(0, 6)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabs
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Badges"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 4
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 20 + 36 + 44 + 48))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(if w < 520 then 150 else 180, 104)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	local foot = Instance.new("Frame")
	foot.BackgroundTransparency = 1
	foot.Size = UDim2.new(1, 0, 0, 44)
	foot.LayoutOrder = 5
	foot.Parent = content
	Theme.list(foot, 8, true)
	Theme.key(foot, "Close", true, function()
		Root.close(NAME)
	end, 180)

	local view: { [string]: any }? = nil
	local render: () -> ()

	local function drawTabs()
		for _, c in tabs:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local specs = { { id = "all", name = "All" } }
		for _, g in BadgeBook.Groups do
			table.insert(specs, { id = g.id, name = g.name })
		end
		for i, g in specs do
			local lit = g.id == group
			local b = Instance.new("TextButton")
			b.Name = "Group_" .. g.id
			b.LayoutOrder = i
			b.AutoButtonColor = false
			b.AutomaticSize = Enum.AutomaticSize.X
			b.Size = UDim2.fromOffset(0, 32)
			b.BackgroundColor3 = if lit then Brand.Colours.gold else rgb(28, 26, 30)
			b.FontFace = HEAVY
			b.TextSize = 12
			b.TextColor3 = if lit then rgb(20, 16, 8) else Brand.Colours.lightGold
			b.Text = string.upper(g.name)
			b.Parent = tabs
			corner(b, 16)
			local p = Instance.new("UIPadding")
			p.PaddingLeft = UDim.new(0, 12)
			p.PaddingRight = UDim.new(0, 12)
			p.Parent = b
			b.Activated:Connect(function()
				group = g.id
				drawTabs()
				render()
			end)
		end
	end

	render = function()
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local v = view
		local earned = if v and type(v.earned) == "table" then v.earned else {}
		local stats = if v and type(v.stats) == "table" then v.stats else {}
		-- Earned first (newest first), then the nearest to being earned.
		local list = {}
		for _, b in BadgeBook.List do
			if group == "all" or b.group == group then
				table.insert(list, b)
			end
		end
		local function progress(b: BadgeBook.Badge): number
			if earned[b.key] then
				return 2
			end
			if b.stat and b.target then
				return math.clamp((stats[b.stat] or 0) / b.target, 0, 0.99)
			end
			return 0
		end
		table.sort(list, function(a, b)
			local pa, pb = progress(a), progress(b)
			if pa ~= pb then
				return pa > pb
			end
			return a.name < b.name
		end)
		for i, b in list do
			local got = earned[b.key] ~= nil
			local colour = BadgeBookPanel.TierColour[b.tier] or Brand.Colours.gold
			local card = Instance.new("Frame")
			card.Name = "Badge_" .. b.key
			card.LayoutOrder = i
			card.BackgroundColor3 = if got then rgb(30, 26, 18) else rgb(20, 20, 24)
			card.BackgroundTransparency = if got then 0.05 else 0.3
			card.Parent = scroll
			corner(card, 8)
			local edge = Instance.new("UIStroke")
			edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			edge.Color = colour
			edge.Thickness = if got then 2 else 1
			edge.Transparency = if got then 0 else 0.6
			edge.Parent = card
			local glyph = Instance.new("TextLabel")
			glyph.BackgroundColor3 = if got then colour else rgb(40, 40, 44)
			glyph.BackgroundTransparency = if got then 0.15 else 0.2
			glyph.Position = UDim2.fromOffset(8, 8)
			glyph.Size = UDim2.fromOffset(40, 40)
			glyph.TextScaled = true
			glyph.Text = b.glyph
			glyph.TextTransparency = if got then 0 else 0.55
			glyph.Parent = card
			corner(glyph, 20)
			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Position = UDim2.fromOffset(54, 6)
			name.Size = UDim2.new(1, -60, 0, 34)
			name.FontFace = HEAVY
			name.TextSize = 13
			name.TextWrapped = true
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextYAlignment = Enum.TextYAlignment.Top
			name.TextColor3 = if got then colour else rgb(200, 196, 188)
			name.Text = b.name
			name.Parent = card
			local line = Instance.new("TextLabel")
			line.BackgroundTransparency = 1
			line.Position = UDim2.fromOffset(8, 52)
			line.Size = UDim2.new(1, -16, 0, 28)
			line.FontFace = BODY
			line.TextSize = 11
			line.TextWrapped = true
			line.TextXAlignment = Enum.TextXAlignment.Left
			line.TextYAlignment = Enum.TextYAlignment.Top
			line.TextColor3 = rgb(170, 166, 158)
			line.Text = b.line
			line.Parent = card
			local footer = Instance.new("TextLabel")
			footer.BackgroundTransparency = 1
			footer.Position = UDim2.new(0, 8, 1, -20)
			footer.Size = UDim2.new(1, -16, 0, 14)
			footer.FontFace = HEAVY
			footer.TextSize = 10
			footer.TextXAlignment = Enum.TextXAlignment.Left
			footer.TextColor3 = if got then colour else rgb(150, 146, 138)
			footer.Parent = card
			if got then
				local at = earned[b.key]
				local when = ""
				if type(at) == "number" and at > 0 then
					local ok, text = pcall(function()
						return DateTime.fromUnixTimestamp(at):FormatLocalTime("D MMM YYYY", "en-us")
					end)
					if ok and type(text) == "string" then
						when = " " .. string.upper(text)
					else
						local t = os.date("*t", at) :: any
						when = string.format(" %d/%d/%d", t.day, t.month, t.year)
					end
				end
				footer.Text = "EARNED" .. when
			elseif b.stat and b.target then
				local have = math.min(stats[b.stat] or 0, b.target)
				footer.Text = format(have) .. " / " .. format(b.target)
				local track = Instance.new("Frame")
				track.BackgroundColor3 = rgb(44, 42, 46)
				track.AnchorPoint = Vector2.new(1, 0.5)
				track.Position = UDim2.new(1, -8, 1, -13)
				track.Size = UDim2.new(0.45, 0, 0, 5)
				track.Parent = card
				corner(track, 3)
				local fill = Instance.new("Frame")
				fill.BackgroundColor3 = colour
				fill.Size = UDim2.fromScale(math.clamp(have / b.target, 0, 1), 1)
				fill.Parent = track
				corner(fill, 3)
			else
				footer.Text = "NOT YET"
			end
		end
		if v then
			summary.Text = string.format("%d of %d badges earned. Each tells you how to earn it.", v.count or 0, v.total or BadgeBook.count)
		end
	end

	drawTabs()
	render()
	Root.open(NAME, panel)
	task.spawn(function()
		local ok, result = pcall(function()
			return Remotes.func("BadgeAsk"):InvokeServer({ op = "state" })
		end)
		if ok and type(result) == "table" and result.ok and panel.Parent then
			view = result
			render()
		elseif ok and type(result) == "table" and result.why then
			Toast.show("The Badge Book", tostring(result.why), 3)
		end
	end)
end

return BadgeBookPanel

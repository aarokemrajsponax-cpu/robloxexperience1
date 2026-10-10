--!strict
-- The Owner Console: XxxXxxX_77797's own selection screen, and nobody else's. It opens by itself
-- when the owner joins (a welcome, then every power laid out as big tiles), and again from the
-- crown key or ";". Every tile asks the server, which checks it's the owner before anything
-- happens: this screen only chooses.
--
--   ABUSE      Admin Abuse Night, Mega Abuse, countdowns to them, and Stop everything
--   EFFECTS    twenty-four effects for everyone (meteors, a black hole, a UFO, the owner's army...),
--              each switched on until you switch it off
--   HOLIDAYS   the holiday hunts and the New Year countdown
--   EVENTS     Golden Hour, Double XP, giants, gold rain, the treasure hunt...
--   PLAYERS    giveaways, Gilt for everyone, the Owner's Token, bring and freeze everyone
--   WORLD      the time of day, and the house dressed for any season
--   MESSAGE    headlines across every screen (ready-made or your own words), announcements
--   POWERS     fly, ghost, invisible, speed, jump, size, go anywhere
--   MORE       the schedule, spectacles, the guest list (the classic House controls)
-- "All servers" (on by default) sends events, effects, headlines and giveaways to every server of
-- the game at once; the owner's own powers are always just the owner's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AbuseNights = require(ReplicatedStorage.Shared.AbuseNights)
local Names = require(ReplicatedStorage.Shared.Names)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)

local OwnerConsole = {}

local NAME = "OwnerConsole"
local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local HEAVY = Font.fromEnum(Enum.Font.GothamBlack)
local BOLD = Font.fromEnum(Enum.Font.GothamBold)
local BODY = Font.fromEnum(Enum.Font.GothamMedium)
local GOLD = rgb(255, 204, 90)
local INK = rgb(12, 10, 8)

-- Set by Main: opens the classic House controls on a page.
OwnerConsole.openClassic = function(_page: string?) end

export type Category = { id: string, name: string, glyph: string, accent: Color3 }
OwnerConsole.Categories = {
	{ id = "abuse", name = "ABUSE", glyph = "💥", accent = rgb(255, 90, 120) },
	{ id = "effects", name = "EFFECTS", glyph = "✨", accent = rgb(150, 110, 255) },
	{ id = "holidays", name = "HOLIDAYS", glyph = "🎃", accent = rgb(255, 150, 60) },
	{ id = "events", name = "EVENTS", glyph = "🎉", accent = rgb(255, 200, 80) },
	{ id = "players", name = "PLAYERS", glyph = "🎁", accent = rgb(90, 220, 150) },
	{ id = "world", name = "WORLD", glyph = "🌅", accent = rgb(90, 180, 255) },
	{ id = "message", name = "MESSAGE", glyph = "📣", accent = rgb(255, 120, 200) },
	{ id = "powers", name = "POWERS", glyph = "🦸", accent = rgb(120, 230, 255) },
	{ id = "more", name = "MORE", glyph = "⚙️", accent = rgb(200, 190, 170) },
} :: { Category }

local page = "abuse"
local everywhere = true
local minutes = 15
local nightChoice: string? = nil -- the night chosen for the next Admin Abuse (nil: a surprise)
local headlineStyle = "gold"
local welcomed = false

local function ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("AdminAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = colour
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.Parent = parent
	return s
end

local function label(parent: Instance, text: string, size: number, font: Font, colour: Color3, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = text
	l.TextWrapped = true
	l.Size = UDim2.new(1, 0, 0, size + 6)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

export type TileSpec = { glyph: string, name: string, line: string?, on: string?, danger: boolean?, lit: boolean?, id: string? }

-- One big tile: a glyph, a name, a line; lit when on.
local function tile(parent: Instance, order: number, accent: Color3, spec: TileSpec, onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Tile_" .. (spec.id or spec.name)
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = if spec.danger then rgb(70, 10, 16) else rgb(22, 20, 26)
	b.BorderSizePixel = 0
	b.Parent = parent
	corner(b, 10)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(150, 150, 160))
	fill.Parent = b
	local edge = stroke(b, if spec.lit then accent else accent:Lerp(INK, 0.55), if spec.lit then 2.5 else 1.5)
	label(b, spec.glyph, 30, BOLD, Color3.new(1, 1, 1), { Name = "Glyph", Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 34), TextScaled = true })
	label(b, string.upper(spec.name), 13, HEAVY, if spec.danger then rgb(255, 200, 200) else rgb(250, 240, 220), {
		Name = "Name",
		Position = UDim2.fromOffset(6, 46),
		Size = UDim2.new(1, -12, 0, 30),
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	if spec.line then
		label(b, spec.line, 10, BODY, rgb(180, 176, 168), {
			Name = "Line",
			Position = UDim2.fromOffset(6, 78),
			Size = UDim2.new(1, -12, 1, -82),
			TextYAlignment = Enum.TextYAlignment.Top,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	end
	if spec.on then
		local chip = label(b, spec.on, 10, HEAVY, INK, {
			Name = "On",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(0, 18),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0,
			BackgroundColor3 = accent,
			TextWrapped = false,
		})
		corner(chip, 9)
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, 6)
		p.PaddingRight = UDim.new(0, 6)
		p.Parent = chip
	end
	b.MouseEnter:Connect(function()
		edge.Color = accent
		edge.Thickness = 2.5
	end)
	b.MouseLeave:Connect(function()
		edge.Color = if spec.lit then accent else accent:Lerp(INK, 0.55)
		edge.Thickness = if spec.lit then 2.5 else 1.5
	end)
	b.Activated:Connect(function()
		-- A flash of the accent, then the request.
		local flash = TweenService:Create(b, TweenInfo.new(0.35), { BackgroundColor3 = if spec.danger then rgb(70, 10, 16) else rgb(22, 20, 26) })
		b.BackgroundColor3 = accent
		flash:Play()
		onPress()
	end)
	return b
end

-- A small key (a choice in a row: minutes, a style, a speed).
local function chipKey(parent: Instance, order: number, text: string, lit: boolean, accent: Color3, onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Chip_" .. text
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.AutomaticSize = Enum.AutomaticSize.X
	b.Size = UDim2.fromOffset(0, 32)
	b.BackgroundColor3 = if lit then accent else rgb(30, 28, 34)
	b.FontFace = HEAVY
	b.TextSize = 13
	b.TextColor3 = if lit then INK else rgb(236, 226, 206)
	b.Text = text
	b.Parent = parent
	corner(b, 16)
	stroke(b, accent, 1.5, if lit then 0 else 0.4)
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 14)
	p.PaddingRight = UDim.new(0, 14)
	p.Parent = b
	b.Activated:Connect(onPress)
	return b
end

---------------------------------------------------------------------------------------------------
-- The console
---------------------------------------------------------------------------------------------------
function OwnerConsole.isOpen(): boolean
	return Root.isOpen(NAME)
end

function OwnerConsole.close()
	Root.close(NAME)
end

function OwnerConsole.toggle()
	if Root.isOpen(NAME) then
		Root.close(NAME)
	else
		OwnerConsole.open()
	end
end

function OwnerConsole.open(startPage: string?)
	if startPage then
		page = startPage
	end
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local narrow = size.X < 760
	local w = math.min(1100, size.X - 16)
	local h = math.min(720, size.Y - 16)
	local group = Instance.new("Frame")
	group.Name = NAME
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromOffset(w, h)
	-- (White under the gradient: the gradient's colours are what's seen.)
	group.BackgroundColor3 = Color3.new(1, 1, 1)
	group.BackgroundTransparency = 0.02
	group.ClipsDescendants = true
	group.Parent = Root.panels
	corner(group, 14)
	stroke(group, GOLD, 2)
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(rgb(40, 32, 18), rgb(10, 9, 12))
	sheen.Parent = group

	-- The header: the crown, the welcome, where it goes (this server or all), close.
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, if narrow then 92 else 70)
	header.Parent = group
	local title = label(header, "👑 OWNER CONSOLE", if narrow then 20 else 26, HEAVY, Color3.new(1, 1, 1), {
		Name = "Title",
		Position = UDim2.fromOffset(18, 10),
		Size = UDim2.new(0.5, 0, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(rgb(255, 236, 170), rgb(230, 160, 50))
	tg.Rotation = 90
	tg.Parent = title
	local status = label(header, "Welcome back, " .. Names.owner() .. ". Only you can see this.", 12, BODY, rgb(200, 190, 170), {
		Name = "Status",
		Position = UDim2.fromOffset(18, 44),
		Size = UDim2.new(if narrow then 1 else 0.55, -24, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local right = Instance.new("Frame")
	right.Name = "Scope"
	right.BackgroundTransparency = 1
	right.AnchorPoint = Vector2.new(1, 0)
	right.Position = if narrow then UDim2.new(1, -12, 0, 60) else UDim2.new(1, -12, 0, 16)
	right.Size = UDim2.fromOffset(if narrow then w - 24 else 420, 34)
	right.Parent = header
	local rl = Instance.new("UIListLayout")
	rl.FillDirection = Enum.FillDirection.Horizontal
	rl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rl.Padding = UDim.new(0, 8)
	rl.SortOrder = Enum.SortOrder.LayoutOrder
	rl.Parent = right

	-- The rail of categories (a row along the top on a narrow screen).
	local railW = if narrow then 0 else 150
	local rail = Instance.new("ScrollingFrame")
	rail.Name = "Rail"
	rail.BackgroundTransparency = 1
	rail.BorderSizePixel = 0
	rail.ScrollBarThickness = 0
	rail.Position = UDim2.fromOffset(10, header.Size.Y.Offset)
	rail.Size = if narrow then UDim2.new(1, -20, 0, 46) else UDim2.new(0, railW, 1, -header.Size.Y.Offset - 10)
	rail.CanvasSize = UDim2.new()
	rail.AutomaticCanvasSize = if narrow then Enum.AutomaticSize.X else Enum.AutomaticSize.Y
	rail.Parent = group
	local railList = Instance.new("UIListLayout")
	railList.FillDirection = if narrow then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	railList.Padding = UDim.new(0, 6)
	railList.SortOrder = Enum.SortOrder.LayoutOrder
	railList.Parent = rail

	local bodyTop = header.Size.Y.Offset + (if narrow then 52 else 0)
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = GOLD
	body.Position = UDim2.fromOffset(railW + 20, bodyTop)
	body.Size = UDim2.new(1, -(railW + 30), 1, -bodyTop - 10)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.Parent = group
	local bodyList = Instance.new("UIListLayout")
	bodyList.Padding = UDim.new(0, 12)
	bodyList.SortOrder = Enum.SortOrder.LayoutOrder
	bodyList.Parent = body
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingRight = UDim.new(0, 8)
	bodyPad.PaddingBottom = UDim.new(0, 12)
	bodyPad.Parent = body

	local tileW = if narrow then 112 else 148
	local tileH = if narrow then 104 else 124

	local view: { [string]: any }? = nil
	local render: () -> ()

	-- What just happened, said in the console's own status line for a few seconds (gold, or red
	-- for a no), rather than a notice over the console's own rail.
	local noticeUntil = 0
	local function notice(text: string, bad: boolean?, seconds: number?)
		noticeUntil = os.clock() + (seconds or 3)
		status.Text = text
		status.TextColor3 = if bad then rgb(255, 120, 120) else GOLD
	end

	local function reload(result: any?)
		task.spawn(function()
			local v = if type(result) == "table" and result.guests then result else ask({ op = "state" })
			if type(v) == "table" and v.ok and group.Parent then
				view = v
				render()
			elseif type(v) == "table" and v.why then
				notice(tostring(v.why), true)
			end
		end)
	end

	local function send(request: { [string]: any }, done: string?)
		task.spawn(function()
			local r = ask(request)
			if type(r) == "table" and r.ok == false then
				notice(tostring(r.why), true)
			elseif done then
				notice(done, false, 2.5)
			end
			reload(r)
		end)
	end

	local function scopeText(): string
		return if everywhere then " (all servers)" else " (this server)"
	end

	-- A section: a heading and a grid of tiles (or a row of chips).
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function section(heading: string, note: string?): Frame
		local s = Instance.new("Frame")
		s.Name = "Section"
		s.BackgroundTransparency = 1
		s.Size = UDim2.new(1, 0, 0, 0)
		s.AutomaticSize = Enum.AutomaticSize.Y
		s.LayoutOrder = nextOrder()
		s.Parent = body
		local l = Instance.new("UIListLayout")
		l.Padding = UDim.new(0, 6)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = s
		label(s, heading, 13, HEAVY, GOLD, { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
		if note then
			label(s, note, 11, BODY, rgb(170, 164, 150), { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
		end
		return s
	end
	local function grid(s: Frame): Frame
		local g = Instance.new("Frame")
		g.Name = "Grid"
		g.BackgroundTransparency = 1
		g.Size = UDim2.new(1, 0, 0, 0)
		g.AutomaticSize = Enum.AutomaticSize.Y
		g.LayoutOrder = 3
		g.Parent = s
		local gl = Instance.new("UIGridLayout")
		gl.CellSize = UDim2.fromOffset(tileW, tileH)
		gl.CellPadding = UDim2.fromOffset(10, 10)
		gl.SortOrder = Enum.SortOrder.LayoutOrder
		gl.Parent = g
		return g
	end
	local function chips(s: Frame): Frame
		local r = Instance.new("Frame")
		r.Name = "Chips"
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(1, 0, 0, 0)
		r.AutomaticSize = Enum.AutomaticSize.Y
		r.LayoutOrder = 3
		r.Parent = s
		local l = Instance.new("UIGridLayout")
		l.CellSize = UDim2.fromOffset(if narrow then 96 else 118, 32)
		l.CellPadding = UDim2.fromOffset(8, 8)
		l.SortOrder = Enum.SortOrder.LayoutOrder
		l.Parent = r
		return r
	end

	local function categoryOf(id: string): Category
		for _, c in OwnerConsole.Categories do
			if c.id == id then
				return c
			end
		end
		return OwnerConsole.Categories[1]
	end

	local function drawRail()
		for _, c in rail:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, c in OwnerConsole.Categories do
			local lit = c.id == page
			local b = Instance.new("TextButton")
			b.Name = "Cat_" .. c.id
			b.LayoutOrder = i
			b.AutoButtonColor = false
			b.Size = if narrow then UDim2.fromOffset(112, 40) else UDim2.new(1, -4, 0, 44)
			b.BackgroundColor3 = if lit then c.accent else rgb(24, 22, 28)
			b.FontFace = HEAVY
			b.TextSize = 13
			b.TextColor3 = if lit then INK else rgb(236, 226, 206)
			b.Text = c.glyph .. "  " .. c.name
			b.TextXAlignment = if narrow then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
			b.Parent = rail
			corner(b, 8)
			stroke(b, c.accent, 1.5, if lit then 0 else 0.55)
			local p = Instance.new("UIPadding")
			p.PaddingLeft = UDim.new(0, 12)
			p.Parent = b
			b.Activated:Connect(function()
				page = c.id
				drawRail()
				render()
			end)
		end
	end

	local function drawScope()
		for _, c in right:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		chipKey(right, 1, "THIS SERVER", not everywhere, rgb(120, 200, 255), function()
			everywhere = false
			drawScope()
			render()
		end)
		chipKey(right, 2, "🌍 ALL SERVERS", everywhere, rgb(255, 110, 150), function()
			everywhere = true
			drawScope()
			render()
		end)
		chipKey(right, 3, "✕ CLOSE", false, GOLD, function()
			Root.close(NAME)
		end)
	end

	render = function()
		for _, c in body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		order = 0
		local v = view
		if not v then
			label(body, "Opening the console…", 14, BODY, rgb(200, 190, 170), { LayoutOrder = 1 })
			return
		end
		local cat = categoryOf(page)
		local accent = cat.accent
		local events = (v.events or {}) :: { any }
		local function eventLeft(e: any): number
			return if type(e.endsAt) == "number" then e.endsAt - Workspace:GetServerTimeNow() else 0
		end
		local function minutesRow()
			local s = section("HOW LONG", "Events and holidays last this long" .. scopeText() .. ".")
			local row = chips(s)
			for i, m in (v.minutes or { 5, 15, 30 }) :: { number } do
				chipKey(row, i, tostring(m) .. " MIN", m == minutes, accent, function()
					minutes = m
					render()
				end)
			end
		end
		if page == "abuse" then
			local abuseUntil = v.abuseUntil
			local onNow = type(abuseUntil) == "number" and abuseUntil > os.time()
			-- Tonight's show: one of the house's nights, by chance or by choice.
			local list = AbuseNights.List
			local chosen = if nightChoice then AbuseNights.byId[nightChoice] else nil
			local playing = if onNow and type(v.abuseNight) == "string" then AbuseNights.byId[v.abuseNight] else nil
			local s0 = section("TONIGHT'S SHOW", string.format("Every Admin Abuse is one of %d nights: its own opening, colours, realm, surprises, music and finale, and the same night in every server. Leave it to chance, or choose one.", #list) .. (if playing then "  Now: " .. playing.glyph .. " " .. playing.name .. "." else ""))
			local row = Instance.new("Frame")
			row.Name = "Nights"
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 0)
			row.AutomaticSize = Enum.AutomaticSize.Y
			row.LayoutOrder = 3
			row.Parent = s0
			local rl = Instance.new("UIListLayout")
			rl.FillDirection = Enum.FillDirection.Horizontal
			rl.Padding = UDim.new(0, 8)
			rl.SortOrder = Enum.SortOrder.LayoutOrder
			pcall(function()
				(rl :: any).Wraps = true
			end)
			rl.Parent = row
			local function stepNight(d: number)
				local at = 0
				for i, n in list do
					if n.id == nightChoice then
						at = i
					end
				end
				local nextAt = if at == 0 then (if d > 0 then 1 else #list) else ((at - 1 + d) % #list) + 1
				nightChoice = list[nextAt].id
				render()
			end
			chipKey(row, 1, "🎲 SURPRISE ME", chosen == nil, accent, function()
				nightChoice = nil
				render()
			end)
			chipKey(row, 2, "◀", false, accent, function()
				stepNight(-1)
			end)
			chipKey(row, 3, if chosen then chosen.glyph .. "  " .. chosen.name else "CHOOSE A NIGHT", chosen ~= nil, accent, function()
				stepNight(1)
			end)
			chipKey(row, 4, "▶", false, accent, function()
				stepNight(1)
			end)
			if chosen then
				label(s0, chosen.line, 11, BODY, rgb(236, 226, 206), { LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0) })
			end
			local s = section("ADMIN ABUSE" .. scopeText(), "Double Gilt, double XP, Mythic luck, golden pieces at every table, the night's twist and hunts, your gifts to everyone, and the night's surprises.")
			local g = grid(s)
			for i, m in (v.abuseMinutes or { 15, 30, 60 }) :: { number } do
				tile(g, i, accent, { id = "abuse" .. m, glyph = "💥", name = "Admin Abuse · " .. m .. " min", line = if chosen then chosen.name else "A night of chaos.", lit = onNow and v.mega ~= true, on = if onNow and v.mega ~= true and i == 1 then clock(abuseUntil - os.time()) else nil }, function()
					send({ op = "abuse", minutes = m, everywhere = everywhere, night = nightChoice }, "ADMIN ABUSE" .. scopeText() .. "!")
				end)
			end
			local s2 = section("MEGA ABUSE" .. scopeText(), "The night and more: extra surprises, faster, two at once more often, realm after realm, triple Gilt, a giveaway every few minutes, and the Mega Abuse Medal for everyone there.")
			local g2 = grid(s2)
			for i, m in (v.abuseMinutes or { 15, 30, 60 }) :: { number } do
				tile(g2, i, rgb(190, 90, 255), { id = "mega" .. m, glyph = "🌋", name = "MEGA ABUSE · " .. m .. " min", line = "Everything. All of it. At once.", lit = onNow and v.mega == true }, function()
					send({ op = "mega", minutes = m, everywhere = everywhere, night = nightChoice }, "MEGA ABUSE" .. scopeText() .. "!")
				end)
			end
			local s3 = section("COUNTDOWNS" .. scopeText(), "Big numbers on every screen, then it happens. Great for getting everyone ready.")
			local g3 = grid(s3)
			local n = 0
			for _, c in (v.countdowns or {}) :: { any } do
				for _, secs in (v.countdownSeconds or { 10, 30, 60 }) :: { number } do
					n += 1
					tile(g3, n, rgb(255, 170, 60), { id = "count" .. tostring(c.id) .. secs, glyph = "⏱️", name = tostring(c.name) .. " in " .. secs .. "s", line = tostring(c.label) .. " " .. secs }, function()
						send({ op = "countdown", id = c.id, seconds = secs, everywhere = everywhere, night = nightChoice }, "Counting down" .. scopeText() .. ".")
					end)
				end
			end
			local s4 = section("STOP", "Every event, the surprises, a countdown, a freeze and the time of day, back to normal.")
			local g4 = grid(s4)
			tile(g4, 1, rgb(255, 80, 80), { id = "stopAll", glyph = "🛑", name = "Stop everything", line = "Back to normal" .. scopeText() .. ".", danger = true }, function()
				send({ op = "stopAll", everywhere = everywhere }, "Everything stopped" .. scopeText() .. ".")
			end)
		elseif page == "effects" then
			local powers = v.powers or {}
			local s = section("EFFECTS FOR EVERYONE" .. scopeText(), "Tap one to switch it on: it stays on, for everyone, until you tap it again. The gentle ones simply stay; the ones that move guests come in waves. At the sorting tables: golden pieces, and the effect on the table too. Nobody sorting is moved; nobody is ever hurt.")
			local g = grid(s)
			local n = 0
			for i, e in (powers.effects or {}) :: { any } do
				local on = e.on == true
				tile(g, i, accent, { id = "fx_" .. tostring(e.id), glyph = tostring(e.glyph or "✨"), name = tostring(e.name), line = if on then "ON. Tap to switch it off." else tostring(e.line or ""), lit = on, on = if on then "ON" else nil }, function()
					send({ op = "fx", id = e.id, on = not on, everywhere = everywhere }, tostring(e.name) .. (if on then " off" else " on") .. scopeText() .. ".")
				end)
				n = i
			end
			tile(g, n + 1, rgb(255, 80, 80), { id = "fxAllOff", glyph = "🧹", name = "Every effect off", line = "Back to normal" .. scopeText() .. ".", danger = true }, function()
				send({ op = "fxAllOff", everywhere = everywhere }, "Every effect off" .. scopeText() .. ".")
			end)
		elseif page == "holidays" or page == "events" then
			minutesRow()
			local holidays = page == "holidays"
			local s = section(if holidays then "HOLIDAYS" .. scopeText() else "EVENTS" .. scopeText(), if holidays then "A hunt round the house for everyone: each find pays Gilt and a curio to keep, with one golden prize. On the real day the house runs its own every hour." else "Tap to start; tap a lit one to stop it here.")
			local g = grid(s)
			local n = 0
			for _, e in events do
				if (e.holiday == true) == holidays then
					n += 1
					local left = eventLeft(e)
					tile(g, n, accent, { id = "event_" .. tostring(e.id), glyph = tostring(e.glyph or "🎉"), name = tostring(e.name), line = tostring(e.line), lit = left > 0, on = if left > 0 then clock(left) else nil }, function()
						if left > 0 then
							send({ op = "stop", id = e.id, everywhere = everywhere }, tostring(e.name) .. " stopped" .. scopeText() .. ".")
						else
							send({ op = "event", id = e.id, minutes = minutes, everywhere = everywhere }, tostring(e.name) .. " has begun" .. scopeText() .. ".")
						end
					end)
				end
			end
		elseif page == "players" then
			local s = section("GIVEAWAYS" .. scopeText(), "One guest in each house wins, drawn on every screen. Free: nobody pays anything.")
			local g = grid(s)
			for i, amount in (v.giveawayGilt or { 250, 1000, 5000 }) :: { number } do
				tile(g, i, accent, { id = "giveaway" .. amount, glyph = "🎁", name = "Giveaway · " .. amount, line = amount .. " Gilt to one lucky guest." }, function()
					send({ op = "giveaway", amount = amount, everywhere = everywhere }, "Drawing a winner" .. scopeText() .. "…")
				end)
			end
			local s2 = section("GIFTS FOR EVERYONE" .. scopeText())
			local g2 = grid(s2)
			for i, amount in (v.giftGilt or { 100, 500, 1000 }) :: { number } do
				tile(g2, i, rgb(255, 214, 90), { id = "gift" .. amount, glyph = "🪙", name = "Gilt for all · " .. amount, line = amount .. " Gilt to every guest." }, function()
					send({ op = "giftAll", amount = amount, everywhere = everywhere }, string.format("Every guest got %d Gilt%s.", amount, scopeText()))
				end)
			end
			tile(g2, 10, rgb(255, 214, 90), { id = "token", glyph = "👑", name = "The Owner's Token", line = "A curio from you for every guest (once a day each)." }, function()
				send({ op = "token", everywhere = everywhere }, "Tokens handed out" .. scopeText() .. ".")
			end)
			local powers = v.powers or {}
			local s3 = section("EVERYONE HERE", "Just this server: everyone to you, or everyone frozen (it thaws by itself).")
			local g3 = grid(s3)
			tile(g3, 1, accent, { id = "bringAll", glyph = "🧲", name = "Bring everyone", line = "Every guest, round you." }, function()
				send({ op = "bringAll" }, "Every guest is with you.")
			end)
			tile(g3, 2, rgb(150, 220, 255), { id = "freeze", glyph = "🧊", name = if powers.frozen then "Thaw" else "Freeze", line = if powers.frozen then "Let them move again." else "Nobody moves.", lit = powers.frozen == true }, function()
				send({ op = "freeze", on = not powers.frozen }, if powers.frozen then "The house moves again." else "Frozen!")
			end)
			tile(g3, 3, accent, { id = "guests", glyph = "📋", name = "Guest list", line = "Crown, spotlight, gift, go to or remove one guest." }, function()
				Root.close(NAME)
				OwnerConsole.openClassic("guests")
			end)
		elseif page == "world" then
			local powers = v.powers or {}
			local NAMES: { [string]: string } = { midnight = "Midnight", dawn = "Dawn", noon = "Noon", sunset = "Sunset" }
			local GLYPHS: { [string]: string } = { midnight = "🌙", dawn = "🌄", noon = "☀️", sunset = "🌇" }
			local s = section("TIME OF DAY", "This server's sky.")
			local g = grid(s)
			for i, c in (powers.clocks or {}) :: { string } do
				tile(g, i, accent, { id = "clock_" .. c, glyph = GLYPHS[c] or "🕰️", name = NAMES[c] or c, lit = powers.clock == c }, function()
					send({ op = "clock", id = c })
				end)
			end
			minutesRow()
			local s2 = section("DRESS THE HOUSE", "Another season's decorations (and its pieces at the tables) for a while.")
			local g2 = grid(s2)
			for i, se in (v.seasons or {}) :: { any } do
				tile(g2, i, rgb(160, 220, 140), { id = "season_" .. tostring(se.id), glyph = "🍂", name = tostring(se.name) }, function()
					send({ op = "season", id = se.id, minutes = minutes }, "The house is dressed for " .. tostring(se.name) .. ".")
				end)
			end
		elseif page == "message" then
			local s = section("HEADLINE STYLE")
			local row = chips(s)
			for i, st in (v.headlineStyles or { "gold" }) :: { string } do
				chipKey(row, i, string.upper(st), st == headlineStyle, accent, function()
					headlineStyle = st
					render()
				end)
			end
			local s1 = section("YOUR OWN WORDS" .. scopeText(), "Up to 140 letters. Roblox's filter checks them before anyone sees them.")
			local box = Instance.new("TextBox")
			box.Name = "HeadlineText"
			box.LayoutOrder = 3
			box.Size = UDim2.new(1, 0, 0, 44)
			box.BackgroundColor3 = rgb(26, 24, 30)
			box.FontFace = BOLD
			box.TextSize = 16
			box.TextColor3 = rgb(250, 240, 220)
			box.PlaceholderText = "Type a headline for every screen…"
			box.PlaceholderColor3 = rgb(140, 132, 120)
			box.ClearTextOnFocus = false
			box.Text = ""
			box.Parent = s1
			corner(box, 8)
			stroke(box, accent, 1.5, 0.3)
			local sendRow = chips(s1)
			sendRow.LayoutOrder = 4
			chipKey(sendRow, 1, "📣 HEADLINE", true, accent, function()
				local text = string.sub(box.Text, 1, 140)
				if text == "" then
					notice("Type something first.", true, 2)
					return
				end
				send({ op = "headline", text = text, style = headlineStyle, everywhere = everywhere }, "Headline sent" .. scopeText() .. ".")
			end)
			chipKey(sendRow, 2, "💬 ANNOUNCE", false, accent, function()
				local text = string.sub(box.Text, 1, 140)
				if text == "" then
					notice("Type something first.", true, 2)
					return
				end
				send({ op = "announce", text = text, everywhere = everywhere }, "Announced" .. scopeText() .. ".")
			end)
			chipKey(sendRow, 3, "🌍 SUMMON", false, accent, function()
				send({ op = "summon", text = string.sub(box.Text, 1, 140) }, "Every house has been invited here.")
			end)
			local s2 = section("READY-MADE HEADLINES" .. scopeText(), "One tap: big words across the top of every screen.")
			local g2 = grid(s2)
			for i, line in (v.headlines or {}) :: { string } do
				tile(g2, i, accent, { id = "headline" .. i, glyph = "📣", name = line }, function()
					send({ op = "headline", preset = i, style = headlineStyle, everywhere = everywhere }, "Headline sent" .. scopeText() .. ".")
				end)
			end
		elseif page == "powers" then
			local powers = v.powers or {}
			local s = section("YOU", "Only you. The server switches each one on.")
			local g = grid(s)
			tile(g, 1, accent, { id = "fly", glyph = "🕊️", name = if powers.fly then "Land" else "Fly", line = "Space or E up, Q or Ctrl down.", lit = powers.fly == true }, function()
				send({ op = "power", power = "fly" }, if powers.fly then "Landed." else "You're flying.")
			end)
			tile(g, 2, accent, { id = "ghost", glyph = "👻", name = if powers.ghost then "Solid" else "Ghost", line = "Through walls and floors.", lit = powers.ghost == true }, function()
				send({ op = "power", power = "ghost" }, if powers.ghost then "Solid again." else "Through walls.")
			end)
			tile(g, 3, accent, { id = "invisible", glyph = "🙈", name = if powers.invisible then "Appear" else "Vanish", line = "Nobody can see you or your name.", lit = powers.invisible == true }, function()
				send({ op = "power", power = "invisible" }, if powers.invisible then "You can be seen again." else "Nobody can see you.")
			end)
			local function choiceRow(heading: string, list: { number }, current: number, power: string, names: { [number]: string }?)
				local cs = section(heading)
				local row = chips(cs)
				for i, value in list do
					chipKey(row, i, if names and names[value] then names[value] else tostring(value) .. "×", value == current, accent, function()
						send({ op = "power", power = power, value = value })
					end)
				end
			end
			choiceRow("SPEED", powers.speeds or { 1, 2, 3, 5 }, powers.speed or 1, "speed", nil)
			choiceRow("SUPER JUMP", powers.jumps or { 1, 2, 4 }, powers.jump or 1, "jump", nil)
			choiceRow("SIZE", powers.sizes or { 0.5, 1, 2, 4 }, powers.size or 1, "size", { [0.5] = "TINY", [1] = "NORMAL", [2] = "GIANT", [4] = "COLOSSAL" })
			local PLACES: { [string]: string } = { street = "Street", foyer = "Foyer", salon = "Salon", boutique = "Boutique", vault = "Vault", library = "Library", ballroom = "Ballroom", terrace = "Terrace", suite = "Suite" }
			local s2 = section("GO ANYWHERE", "In one step.")
			local g2 = grid(s2)
			for i, place in (powers.places or {}) :: { string } do
				tile(g2, i, rgb(120, 230, 255), { id = "goto_" .. place, glyph = "🚪", name = PLACES[place] or place }, function()
					send({ op = "goto", place = place })
				end)
			end
		elseif page == "more" then
			local s = section("THE CLASSIC CONTROLS", "Every page of House controls: the schedule, Salutes and Suite shows, the guest list.")
			local g = grid(s)
			local specs: { { string } } = { { "schedule", "📅", "Schedule", "Events at a time you choose, in every server, with a countdown." }, { "spectacle", "🎆", "Spectacle", "Any Salute, any Suite show, free." }, { "guests", "📋", "Guests", "One guest at a time." }, { "events", "🗂️", "Classic controls", "The original House controls." } }
			for i, spec in specs do
				tile(g, i, accent, { id = "classic_" .. spec[1], glyph = spec[2], name = spec[3], line = spec[4] }, function()
					Root.close(NAME)
					OwnerConsole.openClassic(spec[1])
				end)
			end
			local s2 = section("THE OWNER REMOTE", "Admin abuse from outside the game, in every server: send a command to the topic \"" .. tostring(Config.data.Admin.remoteTopic) .. "\" with Roblox Open Cloud (the README says how).")
			local _ = s2
		end
	end

	-- The status line: guests here, and anything big that's on.
	task.spawn(function()
		while group.Parent do
			local v = view
			if v and os.clock() >= noticeUntil then
				status.TextColor3 = rgb(200, 190, 170)
				local parts = { string.format("%d in this server", #Players:GetPlayers()) }
				local until_ = Workspace:GetAttribute("AbuseUntil")
				if type(until_) == "number" and until_ > os.time() then
					local id = Workspace:GetAttribute("AbuseNight")
					local night = if type(id) == "string" then AbuseNights.byId[id] else nil
					table.insert(parts, (if Workspace:GetAttribute("AbuseMega") == true then "MEGA ABUSE " else "ADMIN ABUSE ") .. clock(until_ - os.time()) .. " left" .. (if night then " (" .. night.name .. ")" else ""))
				end
				local on = 0
				for _, e in (v.events or {}) :: { any } do
					local ends = Workspace:GetAttribute("Event_" .. tostring(e.id))
					if type(ends) == "number" and ends > Workspace:GetServerTimeNow() then
						on += 1
					end
				end
				if on > 0 then
					table.insert(parts, on .. " events on")
				end
				table.insert(parts, if everywhere then "sending to ALL servers" else "sending to this server")
				status.Text = table.concat(parts, "  ·  ")
			end
			task.wait(1)
		end
	end)

	drawScope()
	drawRail()
	render()
	Root.open(NAME, group)
	reload()
end

-- The owner's arrival: a welcome across the screen, then the console.
function OwnerConsole.welcome()
	if welcomed then
		return
	end
	welcomed = true
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then
		OwnerConsole.open()
		return
	end
	local s = Instance.new("ScreenGui")
	s.Name = "OwnerWelcome"
	s.IgnoreGuiInset = true
	s.ResetOnSpawn = false
	s.DisplayOrder = 80
	s.Parent = gui
	local dim = Instance.new("Frame")
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.25
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = s
	local crown = label(dim, "👑", 90, BOLD, Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(160, 120), TextScaled = true })
	local words = label(dim, "WELCOME BACK, " .. string.upper(Names.owner()), 40, HEAVY, Color3.new(1, 1, 1), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.9, 0, 0, 56), TextScaled = true })
	local wg = Instance.new("UIGradient")
	wg.Color = ColorSequence.new(rgb(255, 240, 180), rgb(230, 150, 40))
	wg.Rotation = 90
	wg.Parent = words
	local sub = label(dim, "The owner · every power in the house is yours", 18, BODY, rgb(236, 226, 206), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.new(0.9, 0, 0, 24) })
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = crown
	TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	pcall(function()
		require(script.Parent.Parent.Sound).play("regalFanfare", 0.9)
	end)
	task.delay(2.2, function()
		for _, t in { words, sub, crown } do
			TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
		local fade = TweenService:Create(dim, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		fade:Play()
		fade.Completed:Once(function()
			s:Destroy()
		end)
		OwnerConsole.open()
	end)
end

-- (Brand is the house's look; the console keeps to its own louder one.)
local _ = Brand

return OwnerConsole

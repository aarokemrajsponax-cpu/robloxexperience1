--!strict
-- The Register (§6, §11): the house's record of everything you've filed, opened for you by the
-- Archivist. The first page is you: your House Standing and how far to the next, what you've
-- found, the Commissions. Then a page for each case, the season's pieces and the Mythics (with
-- the odds printed, as they must be). Each piece stands in its own vitrine: black glass, a
-- spotlight from above, a lit plinth, the real 3D model turning slowly on it, its edge in the
-- piece's own light (gold for the house's pieces, the season's colour, the Mythics' violet).
-- Pieces not yet found are shadows behind dark glass.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local PieceModels = require(ReplicatedStorage.Shared.PieceModels)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local RoundPanel = require(script.Parent.RoundPanel)
local Closet = require(script.Parent.Parent.Closet)
local State = require(script.Parent.Parent.State)

local RegisterPanel = {}

local NAME = "Register"
local MONTHS = { "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC" }
local C = Brand.Colours

local CELL_W, CELL_H = 136, 200

-- The light each kind of piece stands in: its edge, its glow, its spotlight.
type Light = { edge: Color3, glow: Color3, spot: Color3, label: string }
local LIGHTS: { [string]: Light } = {
	core = { edge = Color3.fromRGB(255, 214, 140), glow = Color3.fromRGB(255, 196, 92), spot = Color3.fromRGB(255, 236, 200), label = "THE HOUSE" },
	seasonal = { edge = Color3.fromRGB(140, 226, 255), glow = Color3.fromRGB(110, 200, 255), spot = Color3.fromRGB(220, 244, 255), label = "THE SEASON" },
	mythic = { edge = Color3.fromRGB(214, 160, 255), glow = Color3.fromRGB(190, 120, 255), spot = Color3.fromRGB(240, 220, 255), label = "MYTHIC" },
}

local spinning: { { model: Model, base: CFrame } } = {}
local spin: RBXScriptConnection? = nil

local function date(t: number): string
	local d = os.date("!*t", t)
	return string.format("%d %s %d", d.day, MONTHS[d.month], d.year)
end

local function still(): boolean
	return State.get("movement") == "Still"
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, font: Font, size: number, colour: Color3, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = text
	l.TextWrapped = true
	l.Size = UDim2.new(1, 0, 0, size + 4)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

-- A bar of progress: a dark track and a gold fill (with its own sheen).
local function bar(parent: Instance, fraction: number, order: number, height: number?): Frame
	local h = height or 8
	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, h)
	track.LayoutOrder = order
	corner(track, h // 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	corner(fill, h // 2)
	Theme.metal(fill, true)
	fill.Parent = track
	track.Parent = parent
	return track
end

-- The real model, turning slowly on its plinth, lit from above (a shadow if not yet found).
local function preview(parent: Instance, pieceId: string, found: boolean, light: Light)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundTransparency = 1
	vp.AnchorPoint = Vector2.new(0.5, 0)
	vp.Position = UDim2.new(0.5, 0, 0, 14)
	vp.Size = UDim2.new(1, -14, 0, 104)
	vp.LightColor = if found then light.spot else Color3.fromRGB(60, 60, 70)
	vp.Ambient = if found then Color3.fromRGB(120, 110, 128) else Color3.fromRGB(20, 20, 24)
	vp.LightDirection = Vector3.new(-0.3, -1, -0.5)
	vp.ZIndex = 4
	vp.Parent = parent
	local ok, model = pcall(PieceModels.build, pieceId, C.felt)
	if not ok or not model then
		return
	end
	if not found then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(8, 8, 10)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			end
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.5, 3.3), Vector3.new(0, 0.2, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	if found then
		table.insert(spinning, { model = model, base = CFrame.new() })
	end
end

-- A small dark chip with a word on it (a count, a serial).
local function chip(parent: Instance, text: string, colour: Color3, position: UDim2, anchor: Vector2): TextLabel
	local c = label(parent, text, Brand.Fonts.heavy, 11, colour, {
		Name = "Chip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		TextWrapped = false,
		BackgroundTransparency = 0.1,
		BackgroundColor3 = Color3.fromRGB(8, 8, 11),
		Position = position,
		AnchorPoint = anchor,
		ZIndex = 6,
	})
	corner(c, 9)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 7)
	pad.PaddingRight = UDim.new(0, 7)
	pad.Parent = c
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Transparency = 0.45
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = c
	return c
end

-- One vitrine.
local function cell(parent: Instance, piece: Catalogue.Piece, entry: { [string]: any }?, order: number, kind: string, serial: string?)
	local found = entry ~= nil
	local light = LIGHTS[kind] or LIGHTS.core
	local c = Instance.new("Frame")
	c.Name = "Entry_" .. piece.id
	c.BackgroundTransparency = 1
	c.LayoutOrder = order
	c.Parent = parent
	if found then
		Theme.glow(c, light.glow, 14, if kind == "mythic" then 0.9 else 0.55)
	end
	-- The glass.
	local glass = Instance.new("Frame")
	glass.Name = "Glass"
	glass.BackgroundColor3 = Color3.new(1, 1, 1)
	glass.BorderSizePixel = 0
	glass.Size = UDim2.fromScale(1, 1)
	glass.ZIndex = 1
	corner(glass, 14)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = if found
		then ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 28, 34)),
			ColorSequenceKeypoint.new(0.62, Color3.fromRGB(14, 14, 18)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(7, 7, 9)),
		})
		else ColorSequence.new(Color3.fromRGB(16, 16, 20), Color3.fromRGB(7, 7, 9))
	g.Parent = glass
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = if found then 1.5 else 1
	edge.Transparency = if found then 0 else 0.55
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local edgeLight = Instance.new("UIGradient")
	edgeLight.Rotation = 90
	edgeLight.Color = if found then ColorSequence.new(light.edge, light.edge:Lerp(Color3.new(0, 0, 0), 0.45)) else ColorSequence.new(Color3.fromRGB(110, 110, 124), Color3.fromRGB(40, 40, 48))
	edgeLight.Parent = edge
	edge.Parent = glass
	glass.Parent = c
	-- The spotlight from above, a cone of light falling to the plinth.
	local spot = Instance.new("Frame")
	spot.Name = "Spot"
	spot.BorderSizePixel = 0
	spot.BackgroundColor3 = light.spot
	spot.AnchorPoint = Vector2.new(0.5, 0)
	spot.Position = UDim2.new(0.5, 0, 0, 2)
	spot.Size = UDim2.new(0.86, 0, 0, 124)
	spot.ZIndex = 2
	corner(spot, 56)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if found then 0.78 else 0.95),
		NumberSequenceKeypoint.new(0.7, if found then 0.95 else 0.99),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Parent = spot
	spot.Parent = c
	-- The plinth: a line of light where the piece stands, with a pool of light round it.
	local pool = Instance.new("Frame")
	pool.Name = "Plinth"
	pool.BorderSizePixel = 0
	pool.BackgroundColor3 = if found then light.edge else Color3.fromRGB(90, 90, 100)
	pool.AnchorPoint = Vector2.new(0.5, 0.5)
	pool.Position = UDim2.new(0.5, 0, 0, 116)
	pool.Size = UDim2.new(0.7, 0, 0, 10)
	pool.ZIndex = 3
	corner(pool, 5)
	local pg = Instance.new("UIGradient")
	pg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, if found then 0.55 else 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	pg.Parent = pool
	pool.Parent = c
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BorderSizePixel = 0
	line.BackgroundColor3 = if found then light.edge else Color3.fromRGB(90, 90, 100)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0.5, 0, 0, 116)
	line.Size = UDim2.new(0.8, 0, 0, 1)
	line.ZIndex = 3
	local lg = Instance.new("UIGradient")
	lg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, if found then 0.05 else 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	lg.Parent = line
	line.Parent = c
	preview(c, piece.id, found, light)
	-- The words, under the plinth.
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(8, 126)
	words.Size = UDim2.new(1, -16, 0, CELL_H - 132)
	words.ZIndex = 5
	words.Parent = c
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 2)
	list.Parent = words
	if found then
		local e = entry :: { [string]: any }
		label(words, piece.name, Brand.Fonts.bodyBold, 13, Color3.new(1, 1, 1), {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 30),
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 5,
		})
		local room = Rooms.get(e.best or "")
		label(words, Caps(if room then room.name else light.label), Brand.Fonts.bodyBold, 10, light.edge, { LayoutOrder = 2, ZIndex = 5 })
		label(words, serial or ("FIRST " .. date(e.first or 0)), Brand.Fonts.body, 10, C.dim, { LayoutOrder = 3, ZIndex = 5 })
		chip(c, "×" .. tostring(e.count or 1), light.edge, UDim2.new(1, -8, 0, 8), Vector2.new(1, 0))
	else
		label(words, "Not yet found", Brand.Fonts.bodyBold, 12, Color3.fromRGB(150, 152, 162), {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 30),
			TextYAlignment = Enum.TextYAlignment.Center,
			ZIndex = 5,
		})
		label(words, string.format("%s  ·  %d PTS", light.label, piece.value), Brand.Fonts.bodyBold, 10, Color3.fromRGB(110, 112, 124), { LayoutOrder = 2, ZIndex = 5 })
	end
	-- A band of light crosses a found piece's glass now and then.
	if found and not still() then
		local sweep = Instance.new("Frame")
		sweep.Name = "Sweep"
		sweep.BorderSizePixel = 0
		sweep.BackgroundColor3 = Color3.new(1, 1, 1)
		sweep.Size = UDim2.fromScale(1, 1)
		sweep.ZIndex = 7
		corner(sweep, 14)
		local wg = Instance.new("UIGradient")
		wg.Rotation = 30
		wg.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.44, 1),
			NumberSequenceKeypoint.new(0.5, 0.86),
			NumberSequenceKeypoint.new(0.56, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		wg.Offset = Vector2.new(-1, 0)
		wg.Parent = sweep
		sweep.Parent = c
		TweenService:Create(wg, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 4 + (order % 5) * 0.8), { Offset = Vector2.new(1, 0) }):Play()
	end
end

local function grid(parent: Instance): Frame
	local g = Instance.new("Frame")
	g.Name = "Vitrines"
	g.BackgroundTransparency = 1
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.Size = UDim2.new(1, 0, 0, 0)
	g.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CELL_W, CELL_H)
	layout.CellPadding = UDim2.fromOffset(12, 14)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = g
	return g
end

-- A line saying how much of a page is found ("3 OF 6 FOUND"), with its bar.
local function tally(parent: Instance, found: number, total: number, order: number)
	local holder = Instance.new("Frame")
	holder.Name = "Tally"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 34)
	holder.LayoutOrder = order
	holder.Parent = parent
	label(holder, string.format("%d OF %d FOUND", found, total), Brand.Fonts.bodyBold, 12, C.brightGold, {
		Size = UDim2.new(1, 0, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local b = bar(holder, if total > 0 then found / total else 0, 0, 6)
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 1, -4)
	b.Size = UDim2.new(0.6, 0, 0, 6)
end

-- A tile of the "You" page: a figure and what it counts.
local function stat(parent: Instance, figure: string, what: string, order: number, fraction: number?)
	local t = Instance.new("Frame")
	t.Name = "Stat"
	t.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	t.BorderSizePixel = 0
	t.LayoutOrder = order
	corner(t, 12)
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Transparency = 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = t
	Theme.edge(s, 1.2)
	local f = label(t, figure, Brand.Fonts.heavy, 24, Color3.new(1, 1, 1), {
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 28),
		TextWrapped = false,
	})
	Theme.metal(f, true)
	label(t, Caps(what), Brand.Fonts.bodyBold, 11, C.smoke, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 14),
	})
	if fraction then
		local b = bar(t, fraction, 0, 5)
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 1, -10)
		b.Size = UDim2.new(1, -28, 0, 5)
	end
	t.Parent = parent
end

local function clear(frame: Instance)
	spinning = {}
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function RegisterPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(660, size.X - 24)
	local h = math.min(660, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Register", 28, "display", { LayoutOrder = 1 })
	local subtitle = Theme.text(content, "The house's record of every piece you've filed", 12, "caps", { LayoutOrder = 2, TextColor3 = C.brightGold })
	-- The tabs: built below, once render() exists, and placed here (LayoutOrder 3).
	local page = Instance.new("ScrollingFrame")
	page.Name = "Page"
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.new(1, 0, 1, -(32 + 18 + 46 + 44 + 40))
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = C.gold
	page.LayoutOrder = 4
	page.Parent = content
	Theme.list(page, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(page, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = C.dim })

	local view: { [string]: any }? = nil
	local tabBar: Theme.Tabs? = nil
	local current = "you"

	local function render()
		local v = view
		if not v then
			return
		end
		clear(page)
		page.CanvasPosition = Vector2.zero
		if tabBar then
			tabBar.select(current)
		end
		local register = v.register or {}
		local order = 0
		local function add(): number
			order += 1
			return order
		end
		local found = 0
		for _ in register do
			found += 1
		end
		local total = v.total or 62
		subtitle.Text = Caps(string.format("%d of %d pieces filed", found, total))
		if current == "you" then
			-- Your standing, large, and the way to the next.
			Theme.text(page, "House Standing", 11, "caps", { LayoutOrder = add() })
			Theme.text(page, v.standing, 30, "display", { LayoutOrder = add() })
			if v.next then
				Theme.text(page, string.format("Next: %s", v.next.name), 13, "bodyMedium", { LayoutOrder = add(), TextColor3 = C.smoke })
				local rows = Instance.new("Frame")
				rows.Name = "Towards"
				rows.BackgroundTransparency = 1
				rows.Size = UDim2.new(0.8, 0, 0, 0)
				rows.AutomaticSize = Enum.AutomaticSize.Y
				rows.LayoutOrder = add()
				rows.Parent = page
				Theme.list(rows, 4)
				local nights, rounds = math.min(v.nights, v.next.nights), math.min(v.rounds, v.next.rounds)
				Theme.text(rows, string.format("%d of %d nights attended", nights, v.next.nights), 12, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
				bar(rows, nights / math.max(1, v.next.nights), 2)
				Theme.text(rows, string.format("%d of %d rounds cleared", rounds, v.next.rounds), 12, "body", { LayoutOrder = 3, TextColor3 = C.smoke })
				bar(rows, rounds / math.max(1, v.next.rounds), 4)
			end
			-- Three tiles: pieces, badges, nights.
			local tiles = Instance.new("Frame")
			tiles.Name = "Stats"
			tiles.BackgroundTransparency = 1
			tiles.Size = UDim2.new(1, 0, 0, 92)
			tiles.LayoutOrder = add()
			tiles.Parent = page
			local tl = Instance.new("UIGridLayout")
			tl.CellSize = UDim2.new(1 / 3, -10, 0, 84)
			tl.CellPadding = UDim2.fromOffset(10, 0)
			tl.HorizontalAlignment = Enum.HorizontalAlignment.Center
			tl.SortOrder = Enum.SortOrder.LayoutOrder
			tl.Parent = tiles
			stat(tiles, string.format("%d/%d", found, total), "Pieces found", 1, found / math.max(1, total))
			stat(tiles, tostring(v.badges or 0), "Badges", 2)
			stat(tiles, tostring(v.nights or 0), "Nights attended", 3)
			-- The Commissions, each a card with its progress.
			Theme.hairline(page, UDim.new(0.6, 0), add())
			Theme.text(page, "Commissions", 11, "caps", { LayoutOrder = add() })
			for _, c in v.commissions or {} do
				local card = Instance.new("Frame")
				card.Name = "Commission"
				card.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
				card.BorderSizePixel = 0
				card.Size = UDim2.new(1, -8, 0, 0)
				card.AutomaticSize = Enum.AutomaticSize.Y
				card.LayoutOrder = add()
				corner(card, 12)
				local cs = Instance.new("UIStroke")
				cs.Color = if c.done then C.brightGold else Color3.fromRGB(70, 66, 58)
				cs.Transparency = if c.done then 0.1 else 0.3
				cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				cs.Parent = card
				local pad = Instance.new("UIPadding")
				pad.PaddingTop = UDim.new(0, 10)
				pad.PaddingBottom = UDim.new(0, 12)
				pad.PaddingLeft = UDim.new(0, 14)
				pad.PaddingRight = UDim.new(0, 14)
				pad.Parent = card
				local cl = Theme.list(card, 4)
				cl.HorizontalAlignment = Enum.HorizontalAlignment.Left
				Theme.text(card, c.label, 11, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
				Theme.text(card, c.text, 15, "bodyBold", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Color3.new(1, 1, 1) })
				bar(card, if c.done then 1 else c.progress / math.max(1, c.target), 3, 6)
				local status = if c.done then "Done" else string.format("%d of %d", c.progress, c.target)
				Theme.text(card, string.format("%s  ·  %s Gilt  ·  optional, and missing it costs nothing", status, RoundPanel.number(c.gilt)), 12, "body", {
					LayoutOrder = 4,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextColor3 = if c.done then C.lightGold else C.smoke,
				})
				card.Parent = page
			end
		elseif current == "mythics" then
			Theme.text(page, "Six pieces, one for each case. Only in the four rooms, never in competition, and never for sale.", 13, "body", { LayoutOrder = add(), TextColor3 = C.smoke })
			for _, o in v.odds or {} do
				Theme.text(page, string.format("%s: each piece dealt, 1 in %s", o.room, RoundPanel.number(o.chance)), 12, "bodyMedium", { LayoutOrder = add(), TextColor3 = C.lightGold })
			end
			local serials: { [string]: { any } } = {}
			local mine = 0
			for _, m in v.mythics or {} do
				if not serials[m.id] then
					mine += 1
				end
				serials[m.id] = serials[m.id] or {}
				table.insert(serials[m.id], m)
			end
			tally(page, mine, #Catalogue.Mythic, add())
			local g = grid(page)
			g.LayoutOrder = add()
			for i, piece in Catalogue.Mythic do
				local held = serials[piece.id]
				local entry = if held then { count = #held, first = held[1].at, best = held[1].room } else nil
				cell(g, piece, entry, i, "mythic", if held then string.format("No. %05d", held[1].serial) else nil)
			end
		elseif current == "seasonal" then
			local have = 0
			for _, piece in Catalogue.Seasonal do
				if register[piece.id] then
					have += 1
				end
			end
			tally(page, have, #Catalogue.Seasonal, add())
			local g = grid(page)
			g.LayoutOrder = add()
			for i, piece in Catalogue.Seasonal do
				cell(g, piece, register[piece.id], i, "seasonal")
			end
		else
			local pieces = Catalogue.coreForCase(current)
			local have = 0
			for _, piece in pieces do
				if register[piece.id] then
					have += 1
				end
			end
			tally(page, have, #pieces, add())
			local g = grid(page)
			g.LayoutOrder = add()
			for i, piece in pieces do
				cell(g, piece, register[piece.id], i, "core")
			end
		end
	end

	local specs: { { string } } = { { "you", "You" } }
	for _, c in Catalogue.Cases do
		table.insert(specs, { c.id, c.name })
	end
	table.insert(specs, { "seasonal", "Seasonal" })
	table.insert(specs, { "mythics", "Mythics" })
	tabBar = Theme.tabs(content, specs, current, function(id: string)
		current = id
		render()
	end, 3)
	Theme.key(content, "Close", true, function()
		Root.close(NAME)
	end, 200).LayoutOrder = 5
	spin = RunService.RenderStepped:Connect(function(dt: number)
		for _, s in spinning do
			if s.model.Parent then
				s.base = s.base * CFrame.Angles(0, dt * 0.6, 0)
				s.model:PivotTo(s.base)
			end
		end
	end)
	Root.open(NAME, group, function()
		if spin then
			spin:Disconnect()
			spin = nil
		end
		spinning = {}
	end)
	task.spawn(function()
		local v = Closet.ask({ op = "register" })
		if type(v) == "table" and v.standing then
			view = v
			render()
		end
	end)
end

return RegisterPanel

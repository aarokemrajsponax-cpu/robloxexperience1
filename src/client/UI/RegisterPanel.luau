--!strict
-- The Register (§6, §11): a leather-bound book the Archivist opens for you. The first page is
-- you: your House Standing, the Commissions, your badges. Then a page for each case, the season's
-- pieces and the Mythics (with the odds printed, as they must be). Every piece is its real 3D
-- model turning slowly in the page; pieces not yet found are shadows.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local PieceModels = require(ReplicatedStorage.Shared.PieceModels)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local RoundPanel = require(script.Parent.RoundPanel)
local Closet = require(script.Parent.Parent.Closet)

local RegisterPanel = {}

local NAME = "Register"
local MONTHS = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }

local spinning: { { model: Model, base: CFrame } } = {}
local spin: RBXScriptConnection? = nil

local function date(t: number): string
	local d = os.date("!*t", t)
	return string.format("%d %s %d", d.day, MONTHS[d.month], d.year)
end

-- The real model, turning slowly in a small window.
local function preview(parent: Instance, pieceId: string, found: boolean)
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.BackgroundColor3 = Color3.fromRGB(18, 16, 22)
	vp.BackgroundTransparency = 0.2
	vp.Size = UDim2.new(1, 0, 0, 84)
	vp.LightColor = Color3.fromRGB(255, 232, 196)
	vp.Ambient = Color3.fromRGB(90, 84, 96)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.6)
	vp.Parent = parent
	local ok, model = pcall(PieceModels.build, pieceId, Brand.Colours.felt)
	if not ok or not model then
		return
	end
	if not found then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(10, 10, 12)
				d.Material = Enum.Material.SmoothPlastic
				d.Reflectance = 0
			end
		end
	end
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 1.6, 3.4), Vector3.new(0, 0.2, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	if found then
		table.insert(spinning, { model = model, base = CFrame.new() })
	end
end

local function cell(parent: Instance, piece: Catalogue.Piece, entry: { [string]: any }?, order: number, extra: string?)
	local c = Instance.new("Frame")
	c.Name = "Entry_" .. piece.id
	c.BackgroundTransparency = 1
	c.LayoutOrder = order
	c.Parent = parent
	Theme.list(c, 2).VerticalAlignment = Enum.VerticalAlignment.Top
	preview(c, piece.id, entry ~= nil)
	Theme.text(c, if entry then piece.name else "Not yet found", 12, "display", { TextColor3 = if entry then Brand.Colours.bone else Brand.Colours.dim })
	if entry then
		local room = Rooms.get(entry.best or "")
		local line = string.format("×%d · %s", entry.count or 1, if room then room.name else "")
		Theme.text(c, line, 10, "body", { TextColor3 = Brand.Colours.smoke })
		Theme.text(c, extra or ("First " .. date(entry.first or 0)), 10, "body", { TextColor3 = Brand.Colours.dim })
	end
end

local function grid(parent: Instance): Frame
	local g = Instance.new("Frame")
	g.BackgroundTransparency = 1
	g.AutomaticSize = Enum.AutomaticSize.Y
	g.Size = UDim2.new(1, 0, 0, 0)
	g.Parent = parent
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(118, 150)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = g
	return g
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
	local w = math.min(640, size.X - 24)
	local h = math.min(640, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Register", 26, "display", { LayoutOrder = 1 })
	-- The tabs: built below, once render() exists, and placed here (LayoutOrder 2).
	local page = Instance.new("ScrollingFrame")
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.new(1, 0, 1, -(26 + 46 + 44 + 30))
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = Brand.Colours.gold
	page.LayoutOrder = 3
	page.Parent = content
	Theme.list(page, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(page, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })

	local view: { [string]: any }? = nil
	local tabBar: Theme.Tabs? = nil
	local current = "you"

	local function render()
		local v = view
		if not v then
			return
		end
		clear(page)
		if tabBar then
			tabBar.select(current)
		end
		local register = v.register or {}
		local order = 0
		local function add(): number
			order += 1
			return order
		end
		if current == "you" then
			local found = 0
			for _ in register do
				found += 1
			end
			Theme.text(page, v.standing, 26, "display", { LayoutOrder = add(), TextColor3 = Brand.Colours.lightGold })
			Theme.text(page, "House Standing", 11, "caps", { LayoutOrder = add() })
			if v.next then
				Theme.text(page, string.format("%s: %d of %d nights attended, %d of %d rounds cleared", v.next.name, math.min(v.nights, v.next.nights), v.next.nights, math.min(v.rounds, v.next.rounds), v.next.rounds), 13, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.smoke })
			end
			Theme.hairline(page, UDim.new(0, 90), add())
			Theme.text(page, string.format("%d of %d pieces found", found, v.total or 62), 15, "bodyMedium", { LayoutOrder = add() })
			Theme.text(page, string.format("%d badges · %d nights attended", v.badges or 0, v.nights or 0), 13, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.smoke })
			Theme.hairline(page, UDim.new(0, 90), add())
			Theme.text(page, "Commissions", 11, "caps", { LayoutOrder = add() })
			for _, c in v.commissions or {} do
				local status = if c.done then "Done" else string.format("%d of %d", c.progress, c.target)
				Theme.text(page, string.format("%s: %s", c.label, c.text), 15, "display", { LayoutOrder = add() })
				Theme.text(page, string.format("%s · %s Gilt · optional, and missing it costs nothing", status, RoundPanel.number(c.gilt)), 12, "body", { LayoutOrder = add(), TextColor3 = if c.done then Brand.Colours.lightGold else Brand.Colours.smoke })
			end
		elseif current == "mythics" then
			Theme.text(page, "Six pieces, one for each case. Only in the four rooms, never in competition, and never for sale.", 13, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.smoke })
			for _, o in v.odds or {} do
				Theme.text(page, string.format("%s: each piece dealt, 1 in %s", o.room, RoundPanel.number(o.chance)), 12, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.dim })
			end
			local serials: { [string]: { any } } = {}
			for _, m in v.mythics or {} do
				serials[m.id] = serials[m.id] or {}
				table.insert(serials[m.id], m)
			end
			local g = grid(page)
			g.LayoutOrder = add()
			for i, piece in Catalogue.Mythic do
				local mine = serials[piece.id]
				local entry = if mine then { count = #mine, first = mine[1].at, best = mine[1].room } else nil
				cell(g, piece, entry, i, if mine then string.format("No. %05d", mine[1].serial) else nil)
			end
		elseif current == "seasonal" then
			local g = grid(page)
			g.LayoutOrder = add()
			for i, piece in Catalogue.Seasonal do
				cell(g, piece, register[piece.id], i)
			end
		else
			local g = grid(page)
			g.LayoutOrder = add()
			for i, piece in Catalogue.coreForCase(current) do
				cell(g, piece, register[piece.id], i)
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
	end, 2)
	Theme.key(content, "Close", true, function()
		Root.close(NAME)
	end, 200).LayoutOrder = 4
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

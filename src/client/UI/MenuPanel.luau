--!strict
-- The Menu (the key at the top of the screen, or M): everything that isn't needed every moment,
-- in one tidy grid, so the screen itself stays clear. Each tile names where it goes and what's
-- there. Main fills in what each tile opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Icons = require(script.Parent.Icons)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local MenuPanel = {}

local NAME = "Menu"
local C = Brand.Colours

export type Tile = { id: string, title: string, line: string, glyph: string, open: () -> () }

-- Each tile's drawn icon, by its id (a tile not here keeps its glyph).
local ICONS: { [string]: string } = {
	collection = "collection", trading = "trade", gems = "gems", gemShop = "spark", badges = "badge", boutique = "bag",
	wardrobe = "wardrobe", ledger = "book", register = "crown", guestbook = "pen", circle = "circle", help = "help",
	settings = "gear", daily = "daily",
}
MenuPanel.tiles = {} :: { Tile }

function MenuPanel.add(tile: Tile)
	table.insert(MenuPanel.tiles, tile)
end

function MenuPanel.open()
	if Root.isOpen(NAME) then
		Root.close(NAME)
		return
	end
	local size = Root.size()
	local w = Root.panelWidth(720)
	local h = math.min(560, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The House", 26, "display", { LayoutOrder = 1 })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Tiles"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -(34 + 56 + 30))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.LayoutOrder = 2
	scroll.Parent = content
	-- (As many columns as fit tiles at least 200 wide: two on a tablet, where the panel is narrower
	-- beside the dock, so the words aren't squeezed into thin columns.)
	local cols = math.clamp(math.floor((w - 48) / 200), 1, 3)
	-- (Room for a tile's name beside its icon: a step smaller where it's long, on two lines where
	-- it's longer still; never cut short, on any screen.)
	local nameRoom = math.floor((w - 48 - 6) / cols) - 8 - 72
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(1 / cols, -8, 0, 100)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll
	for i, tile in MenuPanel.tiles do
		local b = Instance.new("TextButton")
		b.Name = "Tile_" .. tile.id
		b.Text = ""
		b.AutoButtonColor = false
		-- (Black and gold: a warm glow at the top corner, down into black.)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		local shade = Instance.new("UIGradient")
		shade.Rotation = 62
		shade.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(72, 58, 36)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(30, 27, 26)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 15, 18)),
		})
		shade.Parent = b
		b.LayoutOrder = i
		b.Selectable = true
		b.Parent = scroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(1, 1, 1)
		stroke.Transparency = 0.35
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		Theme.edge(stroke, 0.6)
		-- The tile's icon, drawn in light in a small glass chip (its glyph, where there isn't one).
		local chip = Instance.new("Frame")
		chip.Name = "Chip"
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, 12, 0.5, 0)
		chip.Size = UDim2.fromOffset(42, 42)
		chip.BackgroundColor3 = Color3.fromRGB(12, 13, 18)
		chip.BackgroundTransparency = 0.1
		chip.Parent = b
		local cc = Instance.new("UICorner")
		cc.CornerRadius = UDim.new(0, 10)
		cc.Parent = chip
		local cs = Instance.new("UIStroke")
		cs.Color = C.gold
		cs.Transparency = 0.55
		cs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cs.Parent = chip
		local drawn = if ICONS[tile.id] then Icons.draw(chip, ICONS[tile.id], C.lightGold, 26) else nil
		if not drawn then
			local g = Instance.new("TextLabel")
			g.BackgroundTransparency = 1
			g.Size = UDim2.fromScale(1, 1)
			g.Text = tile.glyph
			g.TextSize = 24
			g.TextColor3 = C.lightGold
			g.Parent = chip
		end
		local titleSize = 16
		while titleSize > 13 and Theme.measure(tile.title, titleSize, Brand.Fonts.bodyBold).X > nameRoom do
			titleSize -= 1
		end
		local twoLines = Theme.measure(tile.title, titleSize, Brand.Fonts.bodyBold).X > nameRoom
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(64, if twoLines then 8 else 16)
		t.Size = UDim2.new(1, -72, 0, if twoLines then 36 else 22)
		t.Text = tile.title
		t.TextWrapped = twoLines
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextYAlignment = Enum.TextYAlignment.Top
		t.FontFace = Brand.Fonts.bodyBold
		t.TextSize = titleSize
		t.TextColor3 = C.bone
		t.Parent = b
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(64, if twoLines then 46 else 40)
		l.Size = UDim2.new(1, -72, 0, if twoLines then 46 else 52)
		l.Text = tile.line
		l.TextWrapped = true
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.FontFace = Brand.Fonts.body
		l.TextSize = 13
		l.TextColor3 = C.smoke
		l.Parent = b
		b.MouseEnter:Connect(function()
			stroke.Transparency = 0.15
			cs.Transparency = 0.1
		end)
		b.MouseLeave:Connect(function()
			stroke.Transparency = 0.7
			cs.Transparency = 0.55
		end)
		b.Activated:Connect(function()
			Root.close(NAME)
			task.defer(tile.open)
		end)
	end
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 48)
	keys.LayoutOrder = 3
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 200)
	Root.open(NAME, group)
	pcall(function()
		game:GetService("GuiService").SelectedObject = close
	end)
end

return MenuPanel

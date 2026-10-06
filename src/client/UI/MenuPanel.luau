--!strict
-- The Menu (the key at the top of the screen, or M): everything that isn't needed every moment,
-- in one tidy grid, so the screen itself stays clear. Each tile names where it goes and what's
-- there. Main fills in what each tile opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local MenuPanel = {}

local NAME = "Menu"
local C = Brand.Colours

export type Tile = { id: string, title: string, line: string, glyph: string, open: () -> () }
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
	local w = math.min(720, size.X - 24)
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
	local cols = if w >= 560 then 3 elseif w >= 360 then 2 else 1
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
		b.BackgroundColor3 = Color3.fromRGB(28, 26, 28)
		b.LayoutOrder = i
		b.Selectable = true
		b.Parent = scroll
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = b
		local stroke = Instance.new("UIStroke")
		stroke.Color = C.gold
		stroke.Transparency = 0.7
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
		local g = Instance.new("TextLabel")
		g.BackgroundTransparency = 1
		g.Position = UDim2.fromOffset(12, 0)
		g.Size = UDim2.new(0, 44, 1, 0)
		g.Text = tile.glyph
		g.TextSize = 30
		g.TextColor3 = C.lightGold
		g.Parent = b
		local t = Instance.new("TextLabel")
		t.Name = "Title"
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(64, 16)
		t.Size = UDim2.new(1, -72, 0, 22)
		t.Text = tile.title
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.FontFace = Brand.Fonts.bodyBold
		t.TextSize = 16
		t.TextColor3 = C.bone
		t.Parent = b
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(64, 40)
		l.Size = UDim2.new(1, -72, 0, 52)
		l.Text = tile.line
		l.TextWrapped = true
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextYAlignment = Enum.TextYAlignment.Top
		l.FontFace = Brand.Fonts.body
		l.TextSize = 13
		l.TextColor3 = C.smoke
		l.Parent = b
		b.MouseEnter:Connect(function()
			stroke.Transparency = 0.15
		end)
		b.MouseLeave:Connect(function()
			stroke.Transparency = 0.7
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

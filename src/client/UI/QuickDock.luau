--!strict
-- The quick dock: four round keys down the left side of the screen, always one tap away
-- (and a key each on the keyboard): your Collection (C), Trade (T), your Wardrobe (V) and Gems.
-- Trade opens a short list of everyone in the house, each with a Trade key, and your past trades.
-- It steps aside while you sort at a table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local QuickDock = {}

local C = Brand.Colours
local PICKER = "TradeWith"

-- Set by Main.
QuickDock.openCollection = function() end
QuickDock.openTrades = function() end
QuickDock.openWardrobe = function() end
QuickDock.openGems = function() end
QuickDock.invite = function(_userId: number, _name: string) end
QuickDock.isSeated = function(): boolean
	return false
end

local dock: Frame? = nil

-- The list of guests to trade with.
function QuickDock.openTrade()
	if Root.isOpen(PICKER) then
		Root.close(PICKER)
		return
	end
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			table.insert(others, p)
		end
	end
	local size = Root.size()
	local rows = math.max(1, #others)
	local group, content = Theme.glass(Root.panels, PICKER, UDim2.fromOffset(math.min(420, size.X - 24), math.min(170 + rows * 52, size.Y - 90)))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Trade", 24, "display", { LayoutOrder = 1 })
	if #others == 0 then
		Theme.text(content, "Nobody else is in the house just now. Invite a friend, then trade here.", 14, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })
	else
		Theme.text(content, "Choose a guest. They're asked first; nothing changes hands until you both confirm.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })
		for i, p in others do
			local k = Theme.key(content, p.DisplayName, i == 1, function()
				Root.close(PICKER)
				QuickDock.invite(p.UserId, p.DisplayName)
			end, 320)
			k.LayoutOrder = 2 + i
		end
	end
	local past = Theme.key(content, "Your trades", false, function()
		Root.close(PICKER)
		QuickDock.openTrades()
	end, 200)
	past.LayoutOrder = 100
	local close = Theme.key(content, "Close", false, function()
		Root.close(PICKER)
	end, 200)
	close.LayoutOrder = 101
	Root.open(PICKER, group)
end

local SIZE = 62

local function tile(parent: Instance, order: number, glyph: string, label: string, hotkey: string?, onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = label
	b.LayoutOrder = order
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(SIZE, SIZE)
	b.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	b.BackgroundTransparency = 0.15
	b.Text = ""
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = C.gold
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = b
	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(1, 0, 0.62, 0)
	icon.Position = UDim2.fromScale(0, 0.06)
	icon.Text = glyph
	icon.TextScaled = true
	icon.Parent = b
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0.66)
	name.Size = UDim2.new(1, 0, 0.26, 0)
	name.FontFace = Brand.Fonts.bodyBold
	name.TextScaled = true
	name.TextColor3 = C.lightGold
	name.Text = if hotkey and not UserInputService.TouchEnabled then label .. " · " .. hotkey else label
	name.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 5)
	pad.PaddingRight = UDim.new(0, 5)
	pad.Parent = b
	b.MouseEnter:Connect(function()
		stroke.Transparency = 0
		b.BackgroundTransparency = 0
	end)
	b.MouseLeave:Connect(function()
		stroke.Transparency = 0.25
		b.BackgroundTransparency = 0.15
	end)
	b.Activated:Connect(onPress)
	b.Parent = parent
	return b
end

function QuickDock.start()
	-- On a phone (a short screen) the keys are smaller and sit high, clear of the thumbstick.
	local short = Root.size().Y < 520
	SIZE = if short then 46 else 62
	local f = Instance.new("Frame")
	f.Name = "QuickDock"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0, 0)
	f.Position = if short then UDim2.new(0, 10, 0, 60) else UDim2.new(0.0, 12, 0.5, -(4 * SIZE + 30) / 2 - 20)
	f.Size = UDim2.fromOffset(SIZE, 4 * SIZE + 3 * 10)
	f.Parent = Root.hud
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
	tile(f, 1, "🏺", "Collection", "C", function()
		QuickDock.openCollection()
	end)
	tile(f, 2, "🤝", "Trade", "T", QuickDock.openTrade)
	tile(f, 3, "👔", "Wardrobe", "V", function()
		QuickDock.openWardrobe()
	end)
	tile(f, 4, "💎", "Gems", nil, function()
		QuickDock.openGems()
	end)
	dock = f
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or QuickDock.isSeated() then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			QuickDock.openCollection()
		elseif input.KeyCode == Enum.KeyCode.T then
			QuickDock.openTrade()
		elseif input.KeyCode == Enum.KeyCode.V then
			QuickDock.openWardrobe()
		end
	end)
end

-- Out of the way while sorting.
function QuickDock.setSeated(seated: boolean)
	local f = dock
	if f then
		f.Visible = not seated
	end
end

return QuickDock

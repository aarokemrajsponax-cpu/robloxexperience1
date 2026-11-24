--!strict
-- (Build 100) The Satchel as one key: Roblox's own hotbar stays put away, and a single gold
-- satchel at the foot of the screen holds everything the guest carries (the stun pistol, a decoy,
-- the squad's brainrots, starred curios). Pressed, it opens a card listing them; a name pressed
-- takes that item in hand (or puts it back if it's already held). What the satchel holds is still
-- the server's to decide (server/Satchel); this only chooses which of those items is in hand.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local SatchelPanel = {}

local NAME = "Satchel"
local C = Brand.Colours
local GOLD = Color3.fromRGB(232, 196, 108)
local GRAPHITE = Color3.fromRGB(18, 16, 14)

-- Set by Satchel: what's in the satchel now (the Backpack's items and the one in hand).
SatchelPanel.tools = function(): { Tool }
	return {}
end

local key: TextButton? = nil
local badge: TextLabel? = nil

local function character(): Model?
	return Players.LocalPlayer.Character
end

local function inHand(t: Tool): boolean
	local c = character()
	return c ~= nil and t.Parent == c
end

-- Takes an item in hand, or puts it back if it's the one already held.
function SatchelPanel.choose(t: Tool)
	local c = character()
	local humanoid = c and c:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if inHand(t) then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(t)
	end
end

function SatchelPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local list = SatchelPanel.tools()
	local w = Root.panelWidth(380)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 300))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Your satchel", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Everything you carry", 22, "display", { LayoutOrder = 2 })
	if #list == 0 then
		Theme.text(content, "Nothing in it yet. Brainrots in your squad, starred curios and the Executive Suite's gear all come here.", 14, "body", { LayoutOrder = 3, TextColor3 = C.smoke })
	else
		Theme.text(content, "Press one to hold it. Press it again to put it away.", 13, "body", { LayoutOrder = 3, TextColor3 = C.smoke })
	end
	for i, t in list do
		local held = inHand(t)
		local row = Theme.key(content, (if held then "✓  " else "") .. t.Name, held, function()
			Root.close(NAME)
			task.defer(SatchelPanel.choose, t)
		end, w - 48)
		row.Name = "Item" .. i
		row.LayoutOrder = 10 + i
	end
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 160)
	close.LayoutOrder = 200
	Root.open(NAME, group)
end

function SatchelPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

-- The one key at the foot of the screen: shown in play (and hidden where the hotbar was), with
-- how many things are in the satchel.
function SatchelPanel.show(visible: boolean, count: number)
	local k = key
	if not k then
		local b = Instance.new("TextButton")
		b.Name = "SatchelKey"
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new(0.5, 0, 1, -6)
		-- (Smaller on a phone, where the foot of the screen is precious.)
		local side = if Root.phone() then 50 else 64
		b.Size = UDim2.fromOffset(side, side)
		b.AutoButtonColor = true
		b.BackgroundColor3 = GRAPHITE
		b.BackgroundTransparency = 0.05
		b.Text = "👜"
		b.TextSize = if Root.phone() then 24 else 30
		b.Font = Enum.Font.GothamBold
		b.TextColor3 = GOLD
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 16)
		corner.Parent = b
		local ring = Instance.new("UIStroke")
		ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ring.Color = GOLD
		ring.Thickness = 2
		ring.Parent = b
		local word = Instance.new("TextLabel")
		word.Name = "Word"
		word.BackgroundTransparency = 1
		word.AnchorPoint = Vector2.new(0.5, 0)
		word.Position = UDim2.new(0.5, 0, 1, -16)
		word.Size = UDim2.new(1, 0, 0, 14)
		word.Text = "SATCHEL"
		word.TextSize = 10
		word.Font = Enum.Font.GothamBold
		word.TextColor3 = GOLD
		word.Parent = b
		local n = Instance.new("TextLabel")
		n.Name = "Count"
		n.AnchorPoint = Vector2.new(0.5, 0.5)
		n.Position = UDim2.new(1, -4, 0, 4)
		n.Size = UDim2.fromOffset(22, 22)
		n.BackgroundColor3 = GOLD
		n.TextColor3 = GRAPHITE
		n.TextSize = 12
		n.Font = Enum.Font.GothamBold
		local nc = Instance.new("UICorner")
		nc.CornerRadius = UDim.new(1, 0)
		nc.Parent = n
		n.Parent = b
		badge = n
		b.Activated:Connect(SatchelPanel.open)
		b.Parent = Root.hud
		key = b
		k = b
	end
	local button = k :: TextButton
	button.Visible = visible
	local nb = badge
	if nb then
		nb.Text = tostring(count)
		nb.Visible = count > 0
	end
end

return SatchelPanel

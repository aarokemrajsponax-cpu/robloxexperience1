--!strict
-- A gift from another guest: a wrapped box the Concierge hands over. Open it to see what's
-- inside, then wear it now or later.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local BoutiquePanel = require(script.Parent.BoutiquePanel)
local Closet = require(script.Parent.Parent.Closet)
local Sound = require(script.Parent.Parent.Sound)

local GiftPanel = {}

local NAME = "Gift"

function GiftPanel.show(from: string, item: { [string]: any })
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local size = Root.size()
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(math.min(380, size.X - 24), 400))
	Theme.list(content, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "A gift", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "From " .. from, 22, "display", { LayoutOrder = 2 })
	-- The wrapped box: burgundy paper, a gold ribbon both ways.
	local box = Instance.new("Frame")
	box.Name = "Box"
	box.BackgroundColor3 = Color3.fromRGB(74, 22, 32)
	box.Size = UDim2.fromOffset(120, 120)
	box.LayoutOrder = 3
	box.Parent = content
	for _, spec in { { UDim2.new(0, 14, 1, 0), UDim2.new(0.5, -7, 0, 0) }, { UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0.5, -7) } } do
		local ribbon = Instance.new("Frame")
		ribbon.BackgroundColor3 = Brand.Colours.gold
		ribbon.BorderSizePixel = 0
		ribbon.Size = spec[1]
		ribbon.Position = spec[2]
		ribbon.Parent = box
	end
	local reveal = Theme.text(content, "", 18, "display", { LayoutOrder = 4, TextColor3 = Brand.Colours.lightGold, Visible = false })
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 10
	keys.Parent = content
	Theme.list(keys, 8)
	local wear: TextButton? = nil
	local open: TextButton
	open = Theme.key(keys, "Open it", true, function()
		open.Visible = false
		Sound.shimmer()
		for _, c in box:GetChildren() do
			c:Destroy()
		end
		box.BackgroundColor3 = BoutiquePanel.swatch(item.style)
		Ease.play(box, Ease.settle, { Size = UDim2.fromOffset(96, 96) })
		reveal.Text = tostring(item.name)
		reveal.Visible = true
		if wear then
			wear.Visible = true
		end
	end, 260)
	open.LayoutOrder = 1
	local w = Theme.key(keys, "Wear it", true, function()
		Root.close(NAME)
		local r = Closet.ask({ op = "equip", kind = item.kind, id = item.id })
		Toast.show("The Wardrobe", if type(r) == "table" and r.ok then tostring(item.name) .. ", worn." else "It's in your Wardrobe.", 2.5)
	end, 260)
	w.Visible = false
	w.LayoutOrder = 2
	wear = w
	Theme.key(keys, "Later", false, function()
		Root.close(NAME)
	end, 260).LayoutOrder = 3
	Root.open(NAME, group)
end

return GiftPanel

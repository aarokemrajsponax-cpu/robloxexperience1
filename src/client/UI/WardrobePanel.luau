--!strict
-- The Tailor's mirror: everything you own, by kind, and the house's own style for each. Tap a
-- piece to wear it; your table, your nameplate and your look change at once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local BoutiquePanel = require(script.Parent.BoutiquePanel)
local Closet = require(script.Parent.Parent.Closet)

local WardrobePanel = {}

local NAME = "Wardrobe"

function WardrobePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(560, size.X - 24)
	local h = math.min(620, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Wardrobe", 26, "display", { LayoutOrder = 1 })
	Theme.hairline(content, UDim.new(0, 90), 2)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 3
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 12 + 44 + 30))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.Parent = content
	Theme.list(scroll, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll
	Theme.text(scroll, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })

	local function fill(data: { [string]: any })
		for _, c in scroll:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local order = 0
		local function add(): number
			order += 1
			return order
		end
		local any = false
		for _, kind in Wardrobe.Kinds do
			local pieces = data.kinds[kind] or {}
			if #pieces > 0 and kind ~= "suite" then
				any = true
				Theme.text(scroll, Wardrobe.KindNames[kind] :: string, 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
				local wearing = data.equipped[kind] or ""
				local rowFrame = Instance.new("Frame")
				rowFrame.BackgroundTransparency = 1
				rowFrame.AutomaticSize = Enum.AutomaticSize.Y
				rowFrame.Size = UDim2.new(1, 0, 0, 0)
				rowFrame.LayoutOrder = add()
				rowFrame.Parent = scroll
				local grid = Instance.new("UIGridLayout")
				grid.CellSize = UDim2.fromOffset(160, 40)
				grid.CellPadding = UDim2.fromOffset(6, 6)
				grid.SortOrder = Enum.SortOrder.LayoutOrder
				grid.Parent = rowFrame
				local house = Theme.key(rowFrame, "The house's own", wearing == "", function()
					Closet.ask({ op = "equip", kind = kind, id = "" })
					Toast.show("The Wardrobe", "The house's own " .. string.lower(Wardrobe.KindNames[kind] :: string) .. ".", 2)
				end, 160)
				house.LayoutOrder = 0
				for i, p in pieces do
					local k = Theme.key(rowFrame, p.name, p.id == wearing, function()
						local r = Closet.ask({ op = "equip", kind = kind, id = p.id })
						Toast.show("The Wardrobe", if type(r) == "table" and r.ok then p.name .. ", worn." else "That can't be worn just now.", 2)
					end, 160)
					k.LayoutOrder = i
					-- A swatch of its colour, in its own space at the left of the key.
					local dot = Instance.new("Frame")
					dot.BackgroundColor3 = BoutiquePanel.swatch(p.style)
					dot.AnchorPoint = Vector2.new(0, 0.5)
					dot.Position = UDim2.new(0, -2, 0.5, 0)
					dot.Size = UDim2.fromOffset(10, 10)
					dot.BorderSizePixel = 0
					local round = Instance.new("UICorner")
					round.CornerRadius = UDim.new(0.5, 0)
					round.Parent = dot
					dot.Parent = k
					local padding = k:FindFirstChildOfClass("UIPadding")
					if padding then
						padding.PaddingLeft = UDim.new(0, 16)
					end
				end
			end
		end
		if not any then
			Theme.text(scroll, "Nothing yet. The Boutique, the Ledger and your evenings in the house all bring pieces here.", 14, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.smoke })
		end
	end
	local function reload()
		task.spawn(function()
			local data = Closet.ask({ op = "wardrobe" })
			if type(data) == "table" and data.kinds and scroll.Parent then
				fill(data)
			end
		end)
	end
	local conn = Closet.Changed:Connect(reload)
	Theme.key(content, "Close", true, function()
		Root.close(NAME)
	end, 200).LayoutOrder = 4
	Root.open(NAME, group, function()
		conn:Disconnect()
	end)
	reload()
end

return WardrobePanel

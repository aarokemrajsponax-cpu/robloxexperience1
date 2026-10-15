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
	-- (Wider on a phone held sideways, so three fit to a row there too.)
	local w = Root.panelWidth(if Root.scale < 0.85 then 780 else 580)
	-- (A set height, inside the screen under the keys: the list scrolls within it, on any screen.)
	local h = math.max(260, math.min(640, size.Y - 66 - 22))
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Wardrobe", 26, "display", { LayoutOrder = 1 })
	Theme.text(content, "Tap anything you own to wear it. It changes at once.", 14, "body", { LayoutOrder = 2, TextColor3 = Brand.Colours.smoke })
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 3
	scroll.Size = UDim2.new(1, 0, 1, -(34 + 20 + 44 + 3 * 8 + 6))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.Parent = content
	Theme.list(scroll, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = scroll
	Theme.text(scroll, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })
	-- (Three to a row; two where the lettering is set larger on a narrow screen.)
	local cols = if Root.scale < 0.85 and w < 700 then 2 else 3

	-- One piece: its colour in a dot at the left, its name beside it.
	local function piece(parent: Instance, name: string, on: boolean, colour: Color3?, order: number, press: () -> ())
		local k = Theme.key(parent, name, on, press, 160)
		k.LayoutOrder = order
		k.TextXAlignment = Enum.TextXAlignment.Left
		k.TextTruncate = Enum.TextTruncate.AtEnd
		Theme.keyPadding(k, 32, 10)
		local dot = Instance.new("Frame")
		dot.Name = "Swatch"
		dot.AnchorPoint = Vector2.new(0, 0.5)
		-- (The key's padding moves its children in by 32: this sits back in the margin.)
		dot.Position = UDim2.new(0, -20, 0.5, 0)
		dot.Size = UDim2.fromOffset(12, 12)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = colour or Color3.new(0, 0, 0)
		dot.BackgroundTransparency = if colour then 0 else 1
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = dot
		local ring = Instance.new("UIStroke")
		-- (Dark on the gold of what's worn, pale gold on the others.)
		ring.Color = if on then Color3.fromRGB(40, 28, 10) else Brand.Colours.lightGold
		ring.Transparency = if colour then 0.6 elseif on then 0.1 else 0.2
		ring.Thickness = if colour then 1 else 1.5
		ring.Parent = dot
		dot.Parent = k
		return k
	end

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
				Theme.text(scroll, Wardrobe.KindNames[kind] :: string, 12, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
				local wearing = data.equipped[kind] or ""
				local rowFrame = Instance.new("Frame")
				rowFrame.Name = "Row_" .. kind
				rowFrame.BackgroundTransparency = 1
				rowFrame.AutomaticSize = Enum.AutomaticSize.Y
				rowFrame.Size = UDim2.new(1, 0, 0, 0)
				rowFrame.LayoutOrder = add()
				rowFrame.Parent = scroll
				local grid = Instance.new("UIGridLayout")
				grid.CellSize = UDim2.new(1 / cols, -math.ceil(8 * (cols - 1) / cols), 0, 44)
				grid.CellPadding = UDim2.fromOffset(8, 8)
				grid.SortOrder = Enum.SortOrder.LayoutOrder
				grid.Parent = rowFrame
				piece(rowFrame, "House style", wearing == "", nil, 0, function()
					Closet.ask({ op = "equip", kind = kind, id = "" })
					Toast.show("The Wardrobe", "The house's own " .. string.lower(Wardrobe.KindNames[kind] :: string) .. ".", 2)
				end)
				for i, p in pieces do
					piece(rowFrame, p.name, p.id == wearing, BoutiquePanel.swatch(p.style), i, function()
						local r = Closet.ask({ op = "equip", kind = kind, id = p.id })
						Toast.show("The Wardrobe", if type(r) == "table" and r.ok then p.name .. ", worn." else "That can't be worn just now.", 2)
					end)
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

--!strict
-- Furnishing the Suite (the bell by the door): each spot with what stands there now, and ‹ › to
-- choose among the pieces you own (or the house's own, or nothing). Pieces you don't own yet are
-- named with where they come from, so the Boutique is a walk away, never a pop-up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Closet = require(script.Parent.Parent.Closet)

local SuitePanel = {}

local NAME = "Suite"

-- Where a piece comes from, for the ones not owned yet.
local function whereFrom(id: string): string
	local item = Wardrobe.get(id)
	if not item then
		return ""
	elseif item.source == "gilt" or item.source == "standing" then
		return string.format("%d Gilt, in the Boutique", item.gilt or 0) .. (if item.standing then " (for " .. item.standing .. "s)" else "")
	elseif item.source == "goldKey" then
		return "with the Gold Key"
	elseif item.source == "introduction" then
		return "with the Introduction"
	end
	return "from the Boutique"
end

function SuitePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(540, size.X - 24)
	local h = math.min(600, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Your Suite", 26, "display", { LayoutOrder = 1 })
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
	Theme.list(scroll, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll
	Theme.text(scroll, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })

	local fill: (view: { [string]: any }) -> ()
	local function reload()
		task.spawn(function()
			local view = Closet.ask({ op = "suite" })
			if type(view) == "table" and type(view.spots) == "table" and content.Parent then
				fill(view)
			end
		end)
	end

	fill = function(view: { [string]: any })
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
		local lastRoom = ""
		for _, spot in view.spots do
			if spot.room ~= lastRoom then
				lastRoom = spot.room
				Theme.text(scroll, (view.rooms or {})[spot.room] or spot.room, 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
				if not spot.open then
					Theme.text(scroll, "Opens with the Gold Key.", 13, "body", { LayoutOrder = add(), TextColor3 = Brand.Colours.dim, TextXAlignment = Enum.TextXAlignment.Left })
				end
			end
			if not spot.open then
				continue
			end
			-- The choices: the house's own (or bare), then each piece owned.
			local choices: { { id: string, name: string } } = { { id = "", name = if spot.house then "The house's own" else "Nothing yet" } }
			local notYet = {}
			local current = 1
			for _, o in spot.options do
				if o.owned then
					table.insert(choices, { id = o.id, name = o.name })
					if o.id == spot.placed then
						current = #choices
					end
				else
					table.insert(notYet, o.name .. " — " .. whereFrom(o.id))
				end
			end
			-- One card per spot: what stands there now, ‹ › to change it, and what else could.
			local card = Instance.new("Frame")
			card.Name = "Spot"
			card.BackgroundColor3 = Color3.fromRGB(22, 20, 22)
			card.BackgroundTransparency = 0.15
			card.BorderSizePixel = 0
			card.AutomaticSize = Enum.AutomaticSize.Y
			card.Size = UDim2.new(1, 0, 0, 0)
			card.LayoutOrder = add()
			card.Parent = scroll
			local cardCorner = Instance.new("UICorner")
			cardCorner.CornerRadius = UDim.new(0, 4)
			cardCorner.Parent = card
			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = Brand.Colours.gold
			cardStroke.Transparency = 0.82
			cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			cardStroke.Parent = card
			local cardPad = Instance.new("UIPadding")
			cardPad.PaddingTop = UDim.new(0, 10)
			cardPad.PaddingBottom = UDim.new(0, 10)
			cardPad.PaddingLeft = UDim.new(0, 14)
			cardPad.PaddingRight = UDim.new(0, 10)
			cardPad.Parent = card
			local cardList = Theme.list(card, 6)
			cardList.HorizontalAlignment = Enum.HorizontalAlignment.Left
			cardList.VerticalAlignment = Enum.VerticalAlignment.Top
			local top = Instance.new("Frame")
			top.BackgroundTransparency = 1
			top.Size = UDim2.new(1, 0, 0, 40)
			top.LayoutOrder = 1
			top.Parent = card
			Theme.text(top, spot.name, 11, "caps", {
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, -100, 0, 14),
				Position = UDim2.fromOffset(0, 1),
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			local label = Theme.text(top, choices[current].name, 16, "bodyMedium", {
				AutomaticSize = Enum.AutomaticSize.None,
				Size = UDim2.new(1, -100, 0, 22),
				Position = UDim2.fromOffset(0, 18),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = Brand.Colours.bone,
			})
			local function choose(step: number)
				if #choices < 2 then
					Toast.show("Your Suite", "Nothing else for this spot yet.", 2.5)
					return
				end
				current = (current - 1 + step) % #choices + 1
				label.Text = choices[current].name
				local r = Closet.ask({ op = "place", spot = spot.id, id = choices[current].id })
				if type(r) == "table" and not r.ok then
					Toast.show("Your Suite", tostring(r.why), 3)
					reload()
				end
			end
			local prev = Theme.key(top, "‹", false, function()
				choose(-1)
			end, 40)
			prev.Size = UDim2.fromOffset(40, 36)
			prev.AnchorPoint = Vector2.new(1, 0.5)
			prev.Position = UDim2.new(1, -46, 0.5, 0)
			local nextKey = Theme.key(top, "›", false, function()
				choose(1)
			end, 40)
			nextKey.Size = UDim2.fromOffset(40, 36)
			nextKey.AnchorPoint = Vector2.new(1, 0.5)
			nextKey.Position = UDim2.new(1, 0, 0.5, 0)
			if #notYet > 0 then
				Theme.text(card, "Also for this spot:  " .. table.concat(notYet, "  ·  "), 12, "body", {
					LayoutOrder = 2,
					TextColor3 = Brand.Colours.dim,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextWrapped = true,
				})
			end
		end
	end

	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 20
	keys.Parent = content
	Theme.list(keys, 8)
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 300)
	Root.open(NAME, group)
	pcall(function()
		game:GetService("GuiService").SelectedObject = close
	end)
	reload()
end

return SuitePanel

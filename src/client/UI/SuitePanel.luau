--!strict
-- Your Suite (the bell by the Suite's door, upstairs). Says plainly what the Suite is and how it
-- works, then each spot: the piece standing there now with ‹ › to change it, and the pieces you
-- could put there with a key to buy one (it goes straight into its spot). The Dressing Room and
-- the Study say they come with the Gold Key, with a key to see it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local BoutiquePanel = require(script.Parent.BoutiquePanel)
local RoundPanel = require(script.Parent.RoundPanel)
local Closet = require(script.Parent.Parent.Closet)

local SuitePanel = {}

local NAME = "Suite"
local C = Brand.Colours

-- What each locked room holds, for the line under its name.
local LOCKED = {
	dressing = "A tall glass and a chaise, for trying on your looks.",
	study = "A partners' desk and a globe.",
}

local STEPS = {
	"Get a piece: buy it below or in the Boutique, for Gilt or Robux. It goes straight into its spot.",
	"Change what stands in a spot with ‹ ›. Pieces you own are never lost.",
	"Want more room? The Gold Key adds two rooms: the Dressing Room and the Study.",
}

local function card(parent: Instance, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Spot"
	f.BackgroundColor3 = Color3.fromRGB(22, 20, 22)
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.new(1, 0, 0, 0)
	f.LayoutOrder = order
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.gold
	stroke.Transparency = 0.82
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = f
	local list = Theme.list(f, 6)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	return f
end

-- A row: a line of text on the left and a key on the right.
local function offerRow(parent: Instance, order: number, text: string, keyText: string, primary: boolean, onPress: () -> ())
	local row = Instance.new("Frame")
	row.Name = "Offer"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 36)
	row.LayoutOrder = order
	row.Parent = parent
	Theme.text(row, text, 13, "body", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, -150, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = C.smoke,
	})
	local k = Theme.key(row, keyText, primary, onPress, 140)
	k.Size = UDim2.fromOffset(140, 34)
	k.AnchorPoint = Vector2.new(1, 0.5)
	k.Position = UDim2.new(1, 0, 0.5, 0)
end

function SuitePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = math.min(560, size.X - 24)
	local h = math.min(640, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Your Suite", 26, "display", { LayoutOrder = 1 })
	Theme.text(content, "Your own rooms upstairs, through the door on the left of the Club hall. Only you see them this way. Just for style: nothing here changes a score.", 13, "body", {
		LayoutOrder = 2,
		TextColor3 = C.smoke,
		TextWrapped = true,
	})
	Theme.hairline(content, UDim.new(0, 90), 3)
	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 4
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 40 + 12 + 44 + 40))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = C.gold
	scroll.Parent = content
	Theme.list(scroll, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll
	Theme.text(scroll, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = C.dim })

	local fill: (view: { [string]: any }) -> ()
	local function reload()
		task.spawn(function()
			local view = Closet.ask({ op = "suite" })
			if type(view) == "table" and type(view.spots) == "table" and content.Parent then
				fill(view)
			end
		end)
	end

	local function goldKey()
		Root.close(NAME)
		BoutiquePanel.open("goldKey")
	end

	local function buyGilt(spotId: string, o: { [string]: any })
		task.spawn(function()
			local r = Closet.ask({ op = "buyGilt", item = o.id })
			if type(r) == "table" and r.ok then
				Closet.ask({ op = "place", spot = spotId, id = o.id })
				Toast.show("Your Suite", tostring(o.name) .. " is in your Suite.", 3)
				reload()
			else
				Toast.show("Your Suite", tostring(if type(r) == "table" and r.why then r.why else "One moment."), 3)
			end
		end)
	end

	local function buyRobux(o: { [string]: any })
		task.spawn(function()
			local r = Closet.ask({ op = "buy", item = o.id })
			if type(r) == "table" and not r.ok then
				Toast.show("Your Suite", tostring(r.why or "One moment."), 3)
			end
			-- Once it's bought, the house puts it in its spot and this page catches up.
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
		-- How it works, in three lines.
		local how = card(scroll, add())
		Theme.text(how, "How it works", 11, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
		for i, line in STEPS do
			Theme.text(how, string.format("%d.  %s", i, line), 13, "body", {
				LayoutOrder = 1 + i,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
			})
		end
		-- Where you are.
		local mine, open = 0, 0
		for _, spot in view.spots do
			if spot.open then
				open += 1
				if spot.placed ~= "" then
					mine += 1
				end
			end
		end
		local gilt = if type(view.gilt) == "number" then view.gilt else Closet.gilt
		Theme.text(scroll, string.format("Your pieces in %d of %d spots   ·   %s Gilt to spend", mine, open, RoundPanel.number(gilt)), 14, "bodyMedium", {
			LayoutOrder = add(),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.bone,
		})
		local lastRoom = ""
		for _, spot in view.spots do
			if spot.room ~= lastRoom then
				lastRoom = spot.room
				Theme.text(scroll, (view.rooms or {})[spot.room] or spot.room, 11, "caps", { LayoutOrder = add(), TextXAlignment = Enum.TextXAlignment.Left })
				if not spot.open then
					-- A room that comes with the Gold Key: what's in it, and the key to see it.
					local locked = card(scroll, add())
					Theme.text(locked, "Comes with the Gold Key", 15, "bodyMedium", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.lightGold })
					Theme.text(locked, (LOCKED :: any)[spot.room] or "", 13, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, TextColor3 = C.smoke })
					local k = Theme.key(locked, "See the Gold Key", true, goldKey, 220)
					k.LayoutOrder = 3
				end
			end
			if not spot.open then
				continue
			end
			-- The choices: the house's own (or bare), then each piece owned.
			local choices: { { id: string, name: string } } = { { id = "", name = if spot.house then "The house's own" else "Nothing yet" } }
			local current = 1
			local forSale: { { [string]: any } } = {}
			for _, o in spot.options do
				if o.owned then
					table.insert(choices, { id = o.id, name = o.name })
					if o.id == spot.placed then
						current = #choices
					end
				else
					table.insert(forSale, o)
				end
			end
			local box = card(scroll, add())
			local top = Instance.new("Frame")
			top.BackgroundTransparency = 1
			top.Size = UDim2.new(1, 0, 0, 40)
			top.LayoutOrder = 1
			top.Parent = box
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
				TextColor3 = C.bone,
			})
			if #choices > 1 then
				local function choose(step: number)
					current = (current - 1 + step) % #choices + 1
					label.Text = choices[current].name
					task.spawn(function()
						local r = Closet.ask({ op = "place", spot = spot.id, id = choices[current].id })
						if type(r) == "table" and not r.ok then
							Toast.show("Your Suite", tostring(r.why), 3)
							reload()
						end
					end)
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
			end
			-- What could stand here: Gilt pieces can be bought right here; Robux pieces when
			-- they're on the Boutique's shelves today; the rest say where they come from.
			table.sort(forSale, function(a, b)
				return (a.gilt or (a.robux or 0) * 10) < (b.gilt or (b.robux or 0) * 10)
			end)
			local shown = 0
			local elsewhere = {}
			for _, o in forSale do
				if shown >= 2 then
					table.insert(elsewhere, o.name)
				elseif (o.source == "gilt" or o.source == "standing") and type(o.gilt) == "number" then
					shown += 1
					local text = tostring(o.name) .. (if o.standing then "  (for " .. tostring(o.standing) .. "s)" else "")
					offerRow(box, 1 + shown, text, RoundPanel.number(o.gilt) .. " Gilt", gilt >= o.gilt, function()
						buyGilt(spot.id, o)
					end)
				elseif o.onSale and type(o.giltAlt) == "number" then
					-- On the Boutique's shelves today: for Gilt right here (or Robux, when that
					-- price tier is on sale).
					shown += 1
					offerRow(box, 1 + shown, tostring(o.name) .. "  (in the Boutique today)", RoundPanel.number(o.giltAlt) .. " Gilt", gilt >= o.giltAlt, function()
						buyGilt(spot.id, o)
					end)
					if o.robuxOnSale and type(o.robux) == "number" then
						offerRow(box, 1 + shown, "", tostring(o.robux) .. " Robux", false, function()
							buyRobux(o)
						end)
					end
				elseif o.source == "goldKey" then
					table.insert(elsewhere, tostring(o.name) .. " (with the Gold Key)")
				elseif o.source == "introduction" then
					table.insert(elsewhere, tostring(o.name) .. " (with the Introduction)")
				else
					table.insert(elsewhere, tostring(o.name) .. " (in the Boutique some days)")
				end
			end
			if #elsewhere > 0 then
				Theme.text(box, "Also: " .. table.concat(elsewhere, "  ·  "), 12, "body", {
					LayoutOrder = 10,
					TextColor3 = C.dim,
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
	local keyList = Theme.list(keys, 8, true)
	keyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local shop = Theme.key(keys, "The Boutique", false, function()
		Root.close(NAME)
		BoutiquePanel.open("gilt")
	end, 200)
	shop.LayoutOrder = 1
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 2
	Root.open(NAME, group)
	pcall(function()
		game:GetService("GuiService").SelectedObject = close
	end)
	-- A piece bought for Robux arrives a moment later: show it when it does.
	local changed: RBXScriptConnection? = nil
	changed = Closet.Changed:Connect(function()
		if not content.Parent then
			if changed then
				changed:Disconnect()
			end
			return
		end
		reload()
	end)
	reload()
end

return SuitePanel

--!strict
-- The Boutique's counter (§12): the Offers (the catalog's: Double Gilt, God-Mode Luck, the Gold
-- Key, VIP Velocity Elite, Emperor's Decree, Megalodon Rainmaker, Gilt purses, a Golden Hour for
-- the whole house), today's six, the week's two, the season's collection, the house's own pieces
-- for Gilt, the Gold Key, the Ledger and (in a guest's first week) the Introduction. Every Robux
-- price is Roblox's own, read live by the server. Nothing here changes a score. Anything can be
-- bought for another guest in the house as a gift.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local RoundPanel = require(script.Parent.RoundPanel)
local DecreePanel = require(script.Parent.DecreePanel)
local Closet = require(script.Parent.Parent.Closet)

local BoutiquePanel = {}

local NAME = "Boutique"
local ROBUX = utf8.char(0xE002) -- Roblox's Robux mark, in Builder Sans

type Card = { [string]: any }

local shelves: { [string]: any }? = nil
local currentTab = "today"
local list: ScrollingFrame? = nil
local tabBar: Theme.Tabs? = nil
local balance: TextLabel? = nil
-- Shopping for someone else (from admiring them): every Buy becomes a gift to them.
local giftFor: { userId: number, name: string }? = nil

function BoutiquePanel.swatch(style: { [string]: any }?): Color3
	if style then
		local c = style.felt or style.colour or style.back or style.frame
		if typeof(c) == "Color3" then
			return c
		end
	end
	return Brand.Colours.gold
end

local function robux(price: number?): string
	return if price then ROBUX .. " " .. tostring(price) else "Not on sale yet"
end

local function clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function after(result: any, done: string?)
	if type(result) ~= "table" then
		Toast.show("The Boutique", "The counter didn't answer. Try again in a moment.", 3)
	elseif not result.ok then
		Toast.show("The Boutique", tostring(result.why or "Not just now."), 3)
	elseif result.credited then
		Toast.show("The Boutique", "Paid with your credit. It's yours.", 3)
	elseif done then
		Toast.show("The Boutique", done, 3)
	end
end

local function giftPicker(card: Card)
	local s = shelves
	if not s or #s.guests == 0 then
		Toast.show("A gift", "There's nobody else in the house just now.", 3)
		return
	end
	local size = Root.size()
	local group, content = Theme.glass(Root.panels, "GiftPicker", UDim2.fromOffset(math.min(360, size.X - 24), math.min(120 + #s.guests * 52, size.Y - 40)))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "A gift of " .. card.name, 18, "display", { LayoutOrder = 1 })
	for i, g in s.guests do
		Theme.key(content, g.name, false, function()
			Root.close("GiftPicker")
			after(Closet.ask({ op = "buy", item = card.id, giftTo = g.userId }))
		end, 260).LayoutOrder = 1 + i
	end
	Theme.key(content, "Not now", false, function()
		Root.close("GiftPicker")
	end, 260).LayoutOrder = 100
	Root.open("GiftPicker", group)
end

-- One piece on the shelf.
local function row(parent: Instance, card: Card, order: number, mode: "robux" | "gilt" | "show")
	local r = Instance.new("Frame")
	r.Name = "Card_" .. card.id
	r.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
	r.BackgroundTransparency = 0.35
	r.Size = UDim2.new(1, 0, 0, 86)
	r.LayoutOrder = order
	r.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = r
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.BackgroundColor3 = BoutiquePanel.swatch(card.style)
	swatch.Position = UDim2.fromOffset(12, 18)
	swatch.Size = UDim2.fromOffset(48, 48)
	swatch.Parent = r
	local ring = Instance.new("UIStroke")
	ring.Color = Brand.Colours.gold
	ring.Transparency = 0.3
	ring.Parent = swatch
	local texts = Instance.new("Frame")
	texts.BackgroundTransparency = 1
	texts.Position = UDim2.fromOffset(72, 8)
	texts.Size = UDim2.new(1, -72 - 170, 1, -16)
	texts.Parent = r
	Theme.list(texts, 2).HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(texts, card.kindName or "", 10, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	Theme.text(texts, card.name, 17, "display", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left })
	Theme.text(texts, card.line or "", 12, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Brand.Colours.smoke })
	local actions = Instance.new("Frame")
	actions.BackgroundTransparency = 1
	actions.AnchorPoint = Vector2.new(1, 0.5)
	actions.Position = UDim2.new(1, -10, 0.5, 0)
	actions.Size = UDim2.fromOffset(160, 76)
	actions.Parent = r
	Theme.list(actions, 4).HorizontalAlignment = Enum.HorizontalAlignment.Right
	if card.owned then
		Theme.text(actions, "Yours", 13, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Right })
		if mode ~= "show" then
			local k = Theme.key(actions, "Wear it", false, function()
				after(Closet.ask({ op = "equip", kind = card.kind, id = card.id }), "Worn.")
			end, 150)
			k.Size = UDim2.fromOffset(150, 34)
			k.LayoutOrder = 2
		end
	elseif mode == "robux" and giftFor then
		local recipient = giftFor
		if type(card.robux) == "number" then
			local give = Theme.key(actions, "Gift · " .. robux(card.robux), true, function()
				after(Closet.ask({ op = "buy", item = card.id, giftTo = recipient.userId }))
			end, 150)
			give.Size = UDim2.fromOffset(150, 34)
			give.LayoutOrder = 1
		else
			Theme.text(actions, "Gifts open with Robux sales", 12, "body", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Brand.Colours.dim })
		end
	elseif mode == "robux" then
		-- Robux when the piece's price tier is on sale; Gilt always (Config.Gilt.perRobux).
		local both = type(card.robux) == "number" and type(card.giltAlt) == "number"
		local h = if both then 24 else 34
		if type(card.robux) == "number" then
			local buy = Theme.key(actions, "Buy · " .. robux(card.robux), true, function()
				after(Closet.ask({ op = "buy", item = card.id }))
			end, 150)
			buy.Size = UDim2.fromOffset(150, h)
			buy.LayoutOrder = 1
		end
		if type(card.giltAlt) == "number" then
			local enough = Closet.gilt >= card.giltAlt
			local g = Theme.key(actions, RoundPanel.number(card.giltAlt) .. " Gilt", not both and enough, function()
				after(Closet.ask({ op = "buyGilt", item = card.id }), "It's yours.")
			end, 150)
			g.Size = UDim2.fromOffset(150, h)
			g.LayoutOrder = 2
		end
		if type(card.robux) == "number" then
			local gift = Theme.key(actions, "Gift", false, function()
				giftPicker(card)
			end, 150)
			gift.Size = UDim2.fromOffset(150, if both then 22 else 30)
			gift.LayoutOrder = 3
		end
	elseif mode == "gilt" then
		if card.locked then
			Theme.text(actions, "For " .. tostring(card.standing) .. "s", 12, "body", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Brand.Colours.dim })
		else
			local buy = Theme.key(actions, RoundPanel.number(card.gilt or 0) .. " Gilt", true, function()
				after(Closet.ask({ op = "buyGilt", item = card.id }), "It's yours.")
			end, 150)
			buy.Size = UDim2.fromOffset(150, 34)
			buy.LayoutOrder = 1
		end
	end
end

local function note(parent: Instance, text: string, order: number)
	Theme.text(parent, text, 13, "body", { LayoutOrder = order, TextColor3 = Brand.Colours.smoke })
end

-- A key to buy something for Robux, or, while it isn't on sale (its product isn't made yet, or
-- Roblox hasn't said its price), a quiet line saying so instead of a key that does nothing.
local function buyKey(parent: Instance, label: string, price: number?, order: number, onPress: () -> (), primary: boolean?)
	if type(price) ~= "number" then
		Theme.text(parent, label .. " · not on sale yet", 13, "body", { LayoutOrder = order, TextColor3 = Brand.Colours.dim })
		return
	end
	local k = Theme.key(parent, label .. " · " .. robux(price), if primary == nil then true else primary, onPress, 320)
	k.LayoutOrder = order
end

local function render()
	local frame = list
	local s = shelves
	if not frame or not s then
		return
	end
	clear(frame)
	if tabBar then
		tabBar.select(currentTab)
	end
	if balance then
		balance.Text = string.format("%s Gilt", RoundPanel.number(Closet.gilt))
	end
	local order = 0
	local function add(): number
		order += 1
		return order
	end
	if currentTab == "offers" then
		local offers = s.offers or {}
		if #offers == 0 then
			note(frame, "Nothing on offer just now.", add())
		end
		for _, o in offers do
			local r = Instance.new("Frame")
			r.Name = "Offer_" .. tostring(o.key)
			r.BackgroundColor3 = if o.best then Color3.fromRGB(34, 26, 12) else Color3.fromRGB(16, 16, 20)
			r.BackgroundTransparency = 0.15
			r.Size = UDim2.new(1, 0, 0, 86)
			r.LayoutOrder = add()
			r.Parent = frame
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 3)
			corner.Parent = r
			local edge = Instance.new("UIStroke")
			edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			edge.Color = Brand.Colours.gold
			edge.Transparency = if o.best then 0.1 else 0.7
			edge.Parent = r
			local texts = Instance.new("Frame")
			texts.BackgroundTransparency = 1
			texts.Position = UDim2.fromOffset(14, 10)
			texts.Size = UDim2.new(1, -14 - 170, 1, -20)
			texts.Parent = r
			Theme.list(texts, 3).HorizontalAlignment = Enum.HorizontalAlignment.Left
			if o.best then
				Theme.text(texts, "Best value", 10, "caps", { LayoutOrder = 0, TextXAlignment = Enum.TextXAlignment.Left })
			end
			Theme.text(texts, o.name, 22, "display", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
			Theme.text(texts, o.line or "", 12, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Brand.Colours.smoke, TextWrapped = true })
			-- What the server says about it now (Luck's time left, a rain waiting), or why it
			-- can't be bought just now.
			local aside = if o.disabled and type(o.why) == "string" then o.why elseif type(o.status) == "string" then o.status else nil
			if aside then
				r.Size = UDim2.new(1, 0, 0, 104)
				Theme.text(texts, aside, 11, "bodyMedium", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Brand.Colours.lightGold, TextWrapped = true })
			end
			local compose = o.action == "compose"
			local k = Theme.key(r, if compose then "Write it" else robux(o.price), not o.disabled, function()
				if compose then
					Root.close(NAME)
					DecreePanel.open()
				elseif o.disabled then
					Toast.show("The Boutique", tostring(o.why or "Not just now."), 3)
				else
					after(Closet.ask({ op = "offer", key = o.key }))
				end
			end, 150)
			k.Name = "Buy"
			k.AnchorPoint = Vector2.new(1, 0.5)
			k.Position = UDim2.new(1, -12, 0.5, 0)
			k.Size = UDim2.fromOffset(150, 40)
		end
	elseif currentTab == "always" then
		note(frame, "Always in the house: the staples, never out of stock.", add())
		for _, c in s.always or {} do
			row(frame, c, add(), "robux")
		end
	elseif currentTab == "salutes" then
		note(frame, "A moment for the whole house. Everyone sees it and hears who gave it; your name goes on the Tonight board, and a gold star sits on your nameplate for half an hour. It changes no score and gives no Gilt.", add())
		if (s.saluteWaiting or 0) > 0 then
			note(frame, string.format("%d salute%s playing or waiting its turn.", s.saluteWaiting, if s.saluteWaiting == 1 then "" else "s"), add())
		end
		for _, sa in s.salutes or {} do
			local r = Instance.new("Frame")
			r.BackgroundColor3 = Color3.fromRGB(16, 16, 20)
			r.BackgroundTransparency = 0.35
			r.Size = UDim2.new(1, 0, 0, 76)
			r.LayoutOrder = add()
			r.Parent = frame
			local texts = Instance.new("Frame")
			texts.BackgroundTransparency = 1
			texts.Position = UDim2.fromOffset(14, 8)
			texts.Size = UDim2.new(1, -14 - 170, 1, -16)
			texts.Parent = r
			Theme.list(texts, 2).HorizontalAlignment = Enum.HorizontalAlignment.Left
			Theme.text(texts, sa.name, 17, "display", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
			Theme.text(texts, sa.line or "", 12, "body", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Brand.Colours.smoke, TextWrapped = true })
			if sa.ready then
				local k = Theme.key(r, robux(sa.price), true, function()
					after(Closet.ask({ op = "salute", id = sa.id }))
				end, 150)
				k.AnchorPoint = Vector2.new(1, 0.5)
				k.Position = UDim2.new(1, -10, 0.5, 0)
				k.Size = UDim2.fromOffset(150, 36)
			else
				local t = Theme.text(r, "Soon", 12, "caps", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) })
				t.TextColor3 = Brand.Colours.dim
			end
		end
	elseif currentTab == "today" or currentTab == "week" then
		local cards = if currentTab == "today" then s.today else s.featured
		note(frame, if currentTab == "today" then "Six pieces, changed at midnight." else "Two pieces for the whole week.", add())
		for _, c in cards do
			row(frame, c, add(), "robux")
		end
	elseif currentTab == "season" then
		note(frame, "The " .. s.season.name .. " collection: sold only in its season, back every year.", add())
		for _, c in s.season.pieces do
			row(frame, c, add(), "show")
		end
		buyKey(frame, "The collection", s.season.price, add(), function()
			after(Closet.ask({ op = "season" }))
		end)
	elseif currentTab == "gilt" then
		note(frame, "The house's own pieces, for Gilt. Earn it at the tables, or find purses on the Offers page.", add())
		for _, c in s.gilt do
			row(frame, c, add(), "gilt")
		end
	elseif currentTab == "goldKey" then
		Theme.text(frame, "The Gold Key", 22, "display", { LayoutOrder = add() })
		for _, line in {
			"A gold-edged nameplate",
			"Three Gold Key house looks",
			"The Gold Key chair and table trim",
			"Two more rooms in your Suite: a Dressing Room and a Study",
			"The Terrace cabana, and a drink on the house there each day",
			"+20% on all Gilt",
		} do
			note(frame, line, add())
		end
		note(frame, "Style and comfort only. Nothing here changes a score.", add())
		if s.goldKey.owned then
			Theme.text(frame, "It's yours.", 14, "caps", { LayoutOrder = add() })
		else
			buyKey(frame, "The Gold Key", s.goldKey.price, add(), function()
				after(Closet.ask({ op = "goldKey" }))
			end)
		end
		-- The Gold Key makes a fine gift.
		if s.goldKey.giftable and #s.guests > 0 then
			note(frame, "Give the Gold Key to a guest in the house:", add())
			for _, g in s.guests do
				buyKey(frame, g.name, s.goldKey.giftPrice, add(), function()
					after(Closet.ask({ op = "goldKeyGift", userId = g.userId }))
				end, false)
			end
		end
	elseif currentTab == "ledger" then
		local v = s.ledger.view
		Theme.text(frame, "The Ledger · " .. tostring(v.term), 22, "display", { LayoutOrder = add() })
		note(frame, string.format("Page %d of %d", v.page, v.pages), add())
		note(frame, "Fifty pages a Term, turned by playing anything, anywhere in the house. Every guest has the free row.", add())
		if v.leather then
			Theme.text(frame, "Bound in leather this Term", 14, "caps", { LayoutOrder = add() })
		else
			note(frame, "The Leather-Bound edition adds a second row: two cosmetics a page, and the Term's signature look on the last. Buying it late unlocks every page you've reached.", add())
			buyKey(frame, "Bind it in leather", s.ledger.price, add(), function()
				after(Closet.ask({ op = "ledgerLeather" }))
			end)
		end
	elseif currentTab == "introduction" and s.introduction then
		note(frame, "A small welcome set, offered once, only in your first week.", add())
		for _, c in s.introduction.items do
			row(frame, c, add(), "show")
		end
		buyKey(frame, "The Introduction", s.introduction.price, add(), function()
			after(Closet.ask({ op = "introduction" }))
		end)
	end
	local credits = 0
	for _, n in s.credits or {} do
		credits += n
	end
	if credits > 0 then
		note(frame, string.format("You have %d Boutique credit%s: choosing a piece at its price or below uses one.", credits, if credits == 1 then "" else "s"), add())
	end
end

local function refresh()
	task.spawn(function()
		local s = Closet.ask({ op = "shelves" })
		if type(s) == "table" and s.today then
			shelves = s
			render()
		end
	end)
end

function BoutiquePanel.open(tab: string?, forGuest: { userId: number, name: string }?)
	if Root.isOpen(NAME) then
		return
	end
	currentTab = tab or (if forGuest then "today" else "offers")
	giftFor = forGuest
	local size = Root.size()
	local w = math.min(620, size.X - 24)
	local h = math.min(640, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Boutique", 26, "display", { LayoutOrder = 1 })
	Theme.text(content, if forGuest then "Choosing a gift for " .. forGuest.name .. ". They'll hear it's from you." else "Style, never score. Prices are Roblox's own.", 12, "body", { LayoutOrder = 2, TextColor3 = if forGuest then Brand.Colours.lightGold else Brand.Colours.dim })

	local specs = {
		{ "offers", "Offers" },
		{ "always", "Always here" },
		{ "today", "Today" },
		{ "week", "This week" },
		{ "season", "In season" },
		{ "gilt", "For Gilt" },
		{ "goldKey", "The Gold Key" },
		{ "ledger", "The Ledger" },
		{ "salutes", "Salutes" },
		{ "introduction", "The Introduction" },
	}
	local bar = Theme.tabs(content, specs, currentTab, function(id: string)
		currentTab = id
		render()
	end, 3)
	bar.show("introduction", false)
	tabBar = bar

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Shelves"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.LayoutOrder = 4
	scroll.Size = UDim2.new(1, 0, 1, -(26 + 18 + 46 + 44 + 50))
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Brand.Colours.gold
	scroll.Parent = content
	local inner = Theme.list(scroll, 6)
	inner.VerticalAlignment = Enum.VerticalAlignment.Top
	local pad = Instance.new("UIPadding")
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = scroll
	list = scroll
	Theme.text(scroll, "One moment...", 14, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })

	local footer = Instance.new("Frame")
	footer.BackgroundTransparency = 1
	footer.Size = UDim2.new(1, 0, 0, 44)
	footer.LayoutOrder = 5
	footer.Parent = content
	Theme.list(footer, 12, true)
	balance = Theme.text(footer, "", 14, "caps", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromOffset(200, 40),
		LayoutOrder = 1,
	})
	Theme.key(footer, "Close", true, function()
		Root.close(NAME)
	end, 180).LayoutOrder = 2

	local conn = Closet.Changed:Connect(refresh)
	Root.open(NAME, group, function()
		conn:Disconnect()
		list = nil
		balance = nil
		giftFor = nil
		tabBar = nil
	end)
	task.spawn(function()
		local s = Closet.ask({ op = "shelves" })
		if type(s) == "table" and s.today then
			shelves = s
			local b = tabBar
			if b then
				b.show("introduction", s.introduction ~= nil)
				b.show("offers", #(s.offers or {}) > 0)
				if currentTab == "offers" and #(s.offers or {}) == 0 then
					currentTab = "today"
				end
			end
			render()
		end
	end)
end

return BoutiquePanel

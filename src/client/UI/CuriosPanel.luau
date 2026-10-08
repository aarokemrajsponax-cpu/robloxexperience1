--!strict
-- Your Collection: every curio you hold, and every one there is to find. Tabs for yours, the
-- recent finds, your starred ones, the whole book (the ones still to find shown dark), the
-- Cabinet (curios for Gems, the exact one you pick, at its price) and Gems (the packs, at
-- Roblox's price), and your trades. Search by name, sort (rarity, name, how many), filter by
-- rarity. Tap a curio for its card: what it is, how it's had, how many you hold, whether it can
-- be traded, and a star. Nothing is random to buy; the server checks everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Rating = require(ReplicatedStorage.Shared.Rating)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local CurioArt = require(script.Parent.CurioArt)
local CurioState = require(script.Parent.Parent.CurioState)

local CuriosPanel = {}

local NAME = "Curios"
local C = Brand.Colours
local ROBUX = utf8.char(0xE002)

local TABS = {
	{ "yours", "Yours" },
	{ "recent", "Recent" },
	{ "starred", "Starred" },
	{ "book", "Every curio" },
	{ "cabinet", "The Cabinet" },
	{ "gems", "Gems" },
	{ "trades", "Trades" },
}
local SORTS = { "Rarity", "Name", "How many" }

local tab = "yours"
local sortBy = "Rarity"
local rarityFilter: string? = nil
local query = ""

-- Set by Main: open the trading screen's invitation list (a guest's card has the Trade key).
CuriosPanel.onTradeHelp = function() end

local function frame(parent: Instance, name: string, order: number, size: UDim2?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = size or UDim2.new(1, 0, 0, 0)
	f.AutomaticSize = if size then Enum.AutomaticSize.None else Enum.AutomaticSize.Y
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

local function corner(f: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

-- The ids this tab shows, searched, filtered and sorted.
local function listFor(cabinet: { [string]: any }?): { string }
	local ids: { string } = {}
	if tab == "yours" then
		for id, n in CurioState.items do
			if n > 0 then
				table.insert(ids, id)
			end
		end
	elseif tab == "recent" then
		for _, id in CurioState.recent do
			table.insert(ids, id)
		end
	elseif tab == "starred" then
		for id, on in CurioState.favs do
			if on and CurioState.count(id) > 0 then
				table.insert(ids, id)
			end
		end
	elseif tab == "book" then
		-- (A Limited curio joins the book once its season has come.)
		local term = Rating.term().id
		for _, c in Curios.List do
			if Curios.shown(c.id, term) or CurioState.count(c.id) > 0 then
				table.insert(ids, c.id)
			end
		end
	elseif tab == "cabinet" and cabinet then
		for _, it in cabinet.items do
			table.insert(ids, it.id)
		end
	end
	local q = string.lower(query)
	local out = {}
	for _, id in ids do
		local c = Curios.byId[id]
		if c and (rarityFilter == nil or c.rarity == rarityFilter) and (q == "" or string.find(string.lower(c.name), q, 1, true)) then
			table.insert(out, id)
		end
	end
	if tab ~= "recent" then
		table.sort(out, function(a, b)
			if sortBy == "Name" then
				return Curios.byId[a].name < Curios.byId[b].name
			elseif sortBy == "How many" and CurioState.count(a) ~= CurioState.count(b) then
				return CurioState.count(a) > CurioState.count(b)
			end
			return Curios.compare(a, b)
		end)
	end
	return out
end

function CuriosPanel.open(start: string?)
	if Root.isOpen(NAME) then
		return
	end
	tab = start or tab
	local size = Root.size()
	local w = math.min(760, size.X - 24)
	local h = math.min(690, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Your Collection", 26, "display", { LayoutOrder = 1 })
	local summary = Theme.text(content, "", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke })

	local cabinet: { [string]: any }? = nil
	local selected: string? = nil
	local fill: () -> ()

	local bar = Theme.tabs(content, TABS, tab, function(id: string)
		tab = id
		selected = nil
		fill()
	end, 3)

	-- Search, sort and rarity: one row.
	local tools = frame(content, "Tools", 4, UDim2.new(1, 0, 0, 34))
	local tl = Theme.list(tools, 8, true)
	tl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	local search = Instance.new("TextBox")
	search.Name = "Search"
	search.PlaceholderText = "Search by name"
	search.Text = query
	search.ClearTextOnFocus = false
	search.Size = UDim2.new(0.38, 0, 1, 0)
	search.BackgroundColor3 = Color3.fromRGB(26, 24, 26)
	search.TextColor3 = C.bone
	search.PlaceholderColor3 = C.dim
	search.FontFace = Brand.Fonts.body
	search.TextSize = 15
	search.TextXAlignment = Enum.TextXAlignment.Left
	search.LayoutOrder = 1
	search.Parent = tools
	corner(search, 6)
	local sp = Instance.new("UIPadding")
	sp.PaddingLeft = UDim.new(0, 10)
	sp.Parent = search
	local sortKey = Theme.key(tools, "Sort: " .. sortBy, false, function() end, 150)
	sortKey.Size = UDim2.fromOffset(150, 34)
	sortKey.LayoutOrder = 2
	local rarityKey = Theme.key(tools, "Rarity: " .. (rarityFilter or "All"), false, function() end, 170)
	rarityKey.Size = UDim2.fromOffset(170, 34)
	rarityKey.LayoutOrder = 3

	-- The shelf of curios (left) and the chosen one's card (right).
	local body = frame(content, "Body", 5, UDim2.new(1, 0, 1, -(34 + 22 + 46 + 34 + 56 + 40)))
	local wide = w >= 620
	local shelf = Instance.new("ScrollingFrame")
	shelf.Name = "Shelf"
	shelf.BackgroundTransparency = 1
	shelf.BorderSizePixel = 0
	shelf.Size = if wide then UDim2.new(1, -250, 1, 0) else UDim2.fromScale(1, 1)
	shelf.CanvasSize = UDim2.new()
	shelf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	shelf.ScrollBarThickness = 3
	shelf.ScrollBarImageColor3 = C.gold
	shelf.Parent = body
	local detail = Instance.new("Frame")
	detail.Name = "Card"
	detail.BackgroundColor3 = Color3.fromRGB(22, 20, 22)
	detail.BackgroundTransparency = 0.05
	detail.Size = if wide then UDim2.new(0, 238, 1, 0) else UDim2.fromScale(1, 1)
	detail.AnchorPoint = Vector2.new(1, 0)
	detail.Position = UDim2.fromScale(1, 0)
	detail.Visible = wide
	detail.ZIndex = 3
	detail.Parent = body
	corner(detail, 8)
	local dpad = Instance.new("UIPadding")
	dpad.PaddingTop = UDim.new(0, 12)
	dpad.PaddingLeft = UDim.new(0, 12)
	dpad.PaddingRight = UDim.new(0, 12)
	dpad.Parent = detail
	Theme.list(detail, 6).VerticalAlignment = Enum.VerticalAlignment.Top

	local function showCard()
		for _, c in detail:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local id = selected
		local c = id and Curios.byId[id]
		if not id or not c then
			Theme.text(detail, "Tap a curio to see its card.", 14, "body", { LayoutOrder = 1, TextColor3 = C.dim })
			detail.Visible = wide
			return
		end
		detail.Visible = true
		local held = CurioState.count(id)
		local art = frame(detail, "Art", 1, UDim2.new(1, 0, 0, 120))
		local m = CurioArt.medallion(art, id, 112, held == 0 and tab == "book")
		m.AnchorPoint = Vector2.new(0.5, 0)
		m.Position = UDim2.fromScale(0.5, 0)
		Theme.text(detail, c.name, 18, "display", { LayoutOrder = 2 })
		local rr = frame(detail, "RarityRow", 3)
		Theme.list(rr, 0).HorizontalAlignment = Enum.HorizontalAlignment.Center
		CurioArt.rarity(rr, c.rarity, 13)
		Theme.text(detail, c.line, 13, "body", { LayoutOrder = 4, TextColor3 = C.smoke })
		Theme.text(detail, c.how, 12, "body", { LayoutOrder = 5, TextColor3 = C.lightGold })
		-- (A curio bought with Gems trades only where Roblox allows paid item trading: server/Policy.)
		local tradeLine = if not c.tradeable then "can't be traded"
			elseif Curios.isPaid(c) and game:GetService("Players").LocalPlayer:GetAttribute("PaidTradingAllowed") ~= true then "can't be traded on your account"
			else "can be traded"
		Theme.text(detail, string.format("You hold %d  ·  %s", held, tradeLine), 12, "body", { LayoutOrder = 6, TextColor3 = C.dim })
		if held > 0 then
			local starred = CurioState.favs[id] == true
			local k = Theme.key(detail, if starred then "Starred ★" else "Star it ☆", starred, function()
				task.spawn(function()
					local r = CurioState.ask({ op = "fav", id = id, on = not starred })
					if type(r) == "table" and r.ok then
						(CurioState.favs :: { [string]: boolean? })[id] = if not starred then true else nil
						showCard()
					end
				end)
			end, 200)
			k.LayoutOrder = 7
		end
		if c.source == "gems" and c.gems then
			local can = CurioState.gems >= c.gems
			local k = Theme.key(detail, string.format("%d Gems", c.gems), can, function()
				if not can then
					tab = "gems"
					bar.select("gems")
					fill()
					return
				end
				task.spawn(function()
					local r = CurioState.ask({ op = "buy", id = id })
					if type(r) == "table" and r.ok then
						Toast.show("The Cabinet", c.name .. " is yours.", 3)
					else
						Toast.show("The Cabinet", tostring(if type(r) == "table" and r.why then r.why else "One moment."), 3)
					end
				end)
			end, 200)
			k.LayoutOrder = 8
		end
		if not wide then
			local back = Theme.key(detail, "Back", false, function()
				selected = nil
				showCard()
				shelf.Visible = true
			end, 200)
			back.LayoutOrder = 9
			shelf.Visible = false
		end
	end

	local function card(parent: Instance, id: string, order: number)
		local c = Curios.byId[id]
		local held = CurioState.count(id)
		local locked = held == 0 and tab == "book"
		local b = Instance.new("TextButton")
		b.Name = "Curio_" .. id
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundColor3 = if selected == id then Color3.fromRGB(52, 44, 34) else Color3.fromRGB(28, 26, 28)
		b.LayoutOrder = order
		b.Parent = parent
		corner(b, 8)
		local st = Instance.new("UIStroke")
		st.Color = Curios.RarityColour[c.rarity] or C.gold
		st.Transparency = if selected == id then 0.1 else 0.65
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = b
		local m = CurioArt.medallion(b, id, 64, locked)
		m.AnchorPoint = Vector2.new(0.5, 0)
		m.Position = UDim2.new(0.5, 0, 0, 8)
		local nameLabel = Instance.new("TextLabel")
		nameLabel.BackgroundTransparency = 1
		nameLabel.Position = UDim2.new(0, 6, 0, 76)
		nameLabel.Size = UDim2.new(1, -12, 0, 34)
		nameLabel.TextWrapped = true
		nameLabel.Text = if locked then "Not found yet" else c.name
		nameLabel.FontFace = Brand.Fonts.bodyMedium
		nameLabel.TextSize = 13
		nameLabel.TextColor3 = if locked then C.dim else C.bone
		nameLabel.TextYAlignment = Enum.TextYAlignment.Top
		nameLabel.Parent = b
		if held > 1 then
			local n = Instance.new("TextLabel")
			n.BackgroundColor3 = Color3.fromRGB(14, 10, 10)
			n.AnchorPoint = Vector2.new(1, 0)
			n.Position = UDim2.new(1, -6, 0, 6)
			n.Size = UDim2.fromOffset(34, 20)
			n.Text = "×" .. tostring(held)
			n.FontFace = Brand.Fonts.bodyBold
			n.TextSize = 13
			n.TextColor3 = C.lightGold
			n.Parent = b
			corner(n, 10)
		end
		if CurioState.favs[id] then
			local star = Instance.new("TextLabel")
			star.BackgroundTransparency = 1
			star.Position = UDim2.fromOffset(6, 4)
			star.Size = UDim2.fromOffset(20, 20)
			star.Text = "★"
			star.TextColor3 = C.gold
			star.TextSize = 16
			star.Parent = b
		end
		b.Activated:Connect(function()
			selected = id
			fill()
		end)
	end

	fill = function()
		for _, c in shelf:GetChildren() do
			if c:IsA("GuiObject") or c:IsA("UIGridLayout") or c:IsA("UIListLayout") then
				c:Destroy()
			end
		end
		shelf.CanvasPosition = Vector2.zero
		shelf.Visible = true
		bar.select(tab)
		local total = 0
		for _, n in CurioState.items do
			total += n
		end
		local kinds = 0
		for id, n in CurioState.items do
			if n > 0 and Curios.byId[id] then
				kinds += 1
			end
		end
		local term = Rating.term().id
		local known = 0
		for _, c in Curios.List do
			if Curios.shown(c.id, term) then
				known += 1
			end
		end
		summary.Text = string.format("%d curios, %d of %d kinds  ·  %d Gems  ·  curios change no score", total, kinds, known, CurioState.gems)
		sortKey.Text = string.upper("Sort: " .. sortBy)
		rarityKey.Text = string.upper("Rarity: " .. (rarityFilter or "All"))
		tools.Visible = tab ~= "gems" and tab ~= "trades"
		if tab == "gems" then
			Theme.list(shelf, 8).VerticalAlignment = Enum.VerticalAlignment.Top
			Theme.text(shelf, "Gems buy curios in the Cabinet, the exact one you choose, at the price on it. Bigger packs give more Gems for each Robux.", 14, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
			for i, p in (if cabinet then cabinet.packs else {}) :: { any } do
				local row = frame(shelf, "Pack", 1 + i, UDim2.new(1, -8, 0, 52))
				row.BackgroundTransparency = 0.1
				row.BackgroundColor3 = Color3.fromRGB(28, 26, 28)
				corner(row, 6)
				local t = Theme.text(row, string.format("%s  ·  %d Gems", tostring(p.name), p.gems), 16, "bodyMedium", { TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -190, 1, 0), AutomaticSize = Enum.AutomaticSize.None, Position = UDim2.fromOffset(12, 0) })
				t.TextYAlignment = Enum.TextYAlignment.Center
				if p.ready then
					local k = Theme.key(row, string.format("%s %d", ROBUX, p.robux), true, function()
						task.spawn(function()
							local r = CurioState.ask({ op = "gems", key = p.key })
							if type(r) == "table" and not r.ok then
								Toast.show("Gems", tostring(r.why or "One moment."), 3)
							end
						end)
					end, 160)
					k.AnchorPoint = Vector2.new(1, 0.5)
					k.Position = UDim2.new(1, -8, 0.5, 0)
					k.Size = UDim2.fromOffset(160, 38)
				else
					local note = Theme.text(row, string.format("%s %d · not on sale yet", ROBUX, p.robux), 13, "body", { TextColor3 = C.dim, Size = UDim2.new(0, 170, 1, 0), AutomaticSize = Enum.AutomaticSize.None, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0) })
					note.TextYAlignment = Enum.TextYAlignment.Center
				end
			end
			showCard()
			return
		elseif tab == "trades" then
			Theme.list(shelf, 8).VerticalAlignment = Enum.VerticalAlignment.Top
			Theme.text(shelf, "To trade, walk up to a guest, admire them (R) and press Trade. Both of you choose, lock in, wait a moment and confirm: nothing changes after you confirm.", 14, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
			task.spawn(function()
				local r = CurioState.trade({ op = "history" })
				if type(r) ~= "table" or type(r.history) ~= "table" or not shelf.Parent or tab ~= "trades" then
					return
				end
				if #r.history == 0 then
					Theme.text(shelf, "No trades yet.", 14, "body", { LayoutOrder = 2, TextColor3 = C.dim })
				end
				for i, t in r.history do
					local gave = if #t.gave > 0 then table.concat(t.gave, ", ") else "nothing"
					local got = if #t.got > 0 then table.concat(t.got, ", ") else "nothing"
					Theme.text(shelf, string.format("With %s: you gave %s; you got %s.", tostring(t.with), gave, got), 13, "body", { LayoutOrder = 2 + i, TextXAlignment = Enum.TextXAlignment.Left })
				end
			end)
			showCard()
			return
		end
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(112, 116)
		grid.CellPadding = UDim2.fromOffset(8, 8)
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = shelf
		local ids = listFor(cabinet)
		if #ids == 0 then
			grid:Destroy()
			Theme.list(shelf, 8)
			local empty = if tab == "starred" then "Star a curio to keep it here." elseif tab == "cabinet" then "One moment..." else "Nothing here yet. Curios turn up among the pieces at the tables."
			Theme.text(shelf, empty, 14, "body", { LayoutOrder = 1, TextColor3 = C.dim })
		end
		for i, id in ids do
			card(shelf, id, i)
		end
		showCard()
	end

	sortKey.Activated:Connect(function()
		local i = table.find(SORTS, sortBy) or 1
		sortBy = SORTS[i % #SORTS + 1]
		fill()
	end)
	rarityKey.Activated:Connect(function()
		local i = if rarityFilter then table.find(Curios.Rarities, rarityFilter) or 0 else 0
		rarityFilter = if i >= #Curios.Rarities then nil else Curios.Rarities[i + 1]
		fill()
	end)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		query = search.Text
		fill()
	end)

	local keys = frame(content, "Keys", 20)
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local close = Theme.key(keys, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 1
	local conn = CurioState.Changed:Connect(function()
		if content.Parent then
			fill()
		end
	end)
	Root.open(NAME, group, function()
		conn:Disconnect()
	end)
	fill()
	task.spawn(function()
		local r = CurioState.ask({ op = "state" })
		if type(r) == "table" and r.ok and content.Parent then
			cabinet = r.cabinet
			CurioState.apply(r)
		end
	end)
end

return CuriosPanel

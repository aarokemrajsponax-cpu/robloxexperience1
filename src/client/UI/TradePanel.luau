--!strict
-- A trade with another guest (TradeService on the server decides everything). Your offer on the
-- left (tap your curios below to add them, tap an offered one to take it back; Gilt and Gems from
-- the purse keys), theirs on the right, exactly as the server holds them. "Lock in" when you're happy; when you both have,
-- a short countdown, then "Confirm". Any change unlocks both of you, so nothing can change after
-- you confirm. Cancel at any time. Invitations arrive as a small card: accept, no thanks, or block.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local CurioArt = require(script.Parent.CurioArt)
local CurioState = require(script.Parent.Parent.CurioState)

local TradePanel = {}

local NAME = "Trade"
local INVITE = "TradeInvite"
local C = Brand.Colours
local GILT, GEMS = "$gilt", "$gems" -- (an offer's Gilt and Gems, beside its curios)
local GOLD = Color3.fromRGB(255, 204, 90)
local GEM = Color3.fromRGB(140, 205, 255)

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

-- An offer's Gilt and Gems in a few words ("" for none).
local function purseLine(offer: { [string]: number }): string
	local parts = {}
	if (offer[GILT] or 0) > 0 then
		table.insert(parts, "💰 " .. commas(offer[GILT]) .. " Gilt")
	end
	if (offer[GEMS] or 0) > 0 then
		table.insert(parts, "💎 " .. commas(offer[GEMS]) .. " Gems")
	end
	return table.concat(parts, "   ·   ")
end

local state: { [string]: any }? = nil
local refresh: (() -> ())? = nil

local function corner(f: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

local function box(parent: Instance, name: string, order: number, size: UDim2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(24, 22, 24)
	f.BackgroundTransparency = 0.1
	f.Size = size
	f.LayoutOrder = order
	f.Parent = parent
	corner(f, 8)
	return f
end

-- A row of small medallions for an offer ({ [id] = n }); tapping one calls onTap(id).
local function offerRow(parent: Instance, offer: { [string]: number }, onTap: ((id: string) -> ())?)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(78, 96)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = parent
	local ids = {}
	for id in offer do
		-- (Curios only: an offer's Gilt and Gems are shown along the side's foot.)
		if Curios.byId[id] then
			table.insert(ids, id)
		end
	end
	table.sort(ids, Curios.compare)
	for i, id in ids do
		local c = Curios.byId[id]
		if not c then
			continue
		end
		local b = Instance.new("TextButton")
		b.Name = "Offered_" .. id
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.LayoutOrder = i
		b.Parent = parent
		local m = CurioArt.medallion(b, id, 56)
		m.AnchorPoint = Vector2.new(0.5, 0)
		m.Position = UDim2.fromScale(0.5, 0)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(0, 58)
		t.Size = UDim2.new(1, 0, 0, 36)
		t.TextWrapped = true
		t.Text = string.format("%s ×%d", c.name, offer[id])
		t.FontFace = Brand.Fonts.body
		t.TextSize = 12
		t.TextColor3 = C.bone
		t.Parent = b
		if onTap then
			b.Activated:Connect(function()
				onTap(id)
			end)
		end
	end
end

local function send(request: { [string]: any })
	task.spawn(function()
		local r = CurioState.trade(request)
		if type(r) == "table" and not r.ok and type(r.why) == "string" then
			Toast.show("Trading", r.why, 3)
		end
	end)
end

function TradePanel.open()
	if Root.isOpen(NAME) or not state then
		return
	end
	local size = Root.size()
	local w = Root.panelWidth(760)
	local h = math.min(680, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local title = Theme.text(content, "A trade", 24, "display", { LayoutOrder = 1 })
	local status = Theme.text(content, "", 14, "body", { LayoutOrder = 2, TextColor3 = C.lightGold })
	local sides = Instance.new("Frame")
	sides.Name = "Sides"
	sides.BackgroundTransparency = 1
	sides.Size = UDim2.new(1, 0, 0, 200)
	sides.LayoutOrder = 3
	sides.Parent = content
	local mineBox = box(sides, "Mine", 1, UDim2.new(0.5, -4, 1, 0))
	local theirsBox = box(sides, "Theirs", 2, UDim2.new(0.5, -4, 1, 0))
	theirsBox.Position = UDim2.new(0.5, 4, 0, 0)
	-- The purse: Gilt and Gems to add to your side (the server checks every one).
	local purse = Instance.new("Frame")
	purse.Name = "Purse"
	purse.BackgroundTransparency = 1
	purse.Size = UDim2.new(1, 0, 0, 36)
	purse.LayoutOrder = 4
	purse.Parent = content
	local purseRow = Theme.list(purse, 6, true)
	purseRow.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(content, "Your curios: tap one to offer it", 12, "caps", { LayoutOrder = 5, TextXAlignment = Enum.TextXAlignment.Left })
	local shelf = Instance.new("ScrollingFrame")
	shelf.Name = "YourCurios"
	shelf.BackgroundTransparency = 1
	shelf.BorderSizePixel = 0
	shelf.Size = UDim2.new(1, 0, 1, -(30 + 22 + 200 + 20 + 60 + 40 + 44))
	shelf.CanvasSize = UDim2.new()
	shelf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	shelf.ScrollBarThickness = 3
	shelf.LayoutOrder = 6
	shelf.Parent = content
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 48)
	keys.LayoutOrder = 7
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function setOffer(offer: { [string]: number? })
		send({ op = "offer", items = offer })
	end

	local function paint()
		local s = state
		if not s then
			return
		end
		title.Text = "A trade with " .. tostring(s.with)
		-- Each side: its heading along the top, and under it the curios on offer (in a frame of
		-- their own, so the grid lays out the curios only, never the heading among them).
		local items: { [Frame]: Frame } = {}
		for _, b in { mineBox, theirsBox } do
			for _, c in b:GetChildren() do
				if not c:IsA("UICorner") then
					c:Destroy()
				end
			end
			local list = Instance.new("Frame")
			list.Name = "Items"
			list.BackgroundTransparency = 1
			list.Position = UDim2.fromOffset(8, 34)
			list.Size = UDim2.new(1, -16, 1, -66)
			list.ClipsDescendants = true
			list.Parent = b
			items[b] = list
		end
		-- Each side's Gilt and Gems, along its foot.
		local function money(b: Frame, offer: { [string]: number })
			local line = purseLine(offer)
			local t = Instance.new("TextLabel")
			t.Name = "Money"
			t.BackgroundTransparency = 1
			t.AnchorPoint = Vector2.new(0, 1)
			t.Position = UDim2.new(0, 10, 1, -6)
			t.Size = UDim2.new(1, -20, 0, 20)
			t.TextTruncate = Enum.TextTruncate.AtEnd
			t.Text = if line == "" then "No Gilt or Gems" else line
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.FontFace = Brand.Fonts.bodyBold
			t.TextSize = 13
			t.TextColor3 = if line == "" then C.dim else GOLD
			t.Parent = b
		end
		money(mineBox, s.mine)
		money(theirsBox, s.theirs)
		local function head(b: Frame, text: string, ok: boolean)
			local t = Instance.new("TextLabel")
			t.Name = "Heading"
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromOffset(10, 8)
			t.Size = UDim2.new(1, -20, 0, 20)
			t.TextTruncate = Enum.TextTruncate.AtEnd
			t.Text = text
			t.TextXAlignment = Enum.TextXAlignment.Left
			t.FontFace = Brand.Fonts.bodyBold
			t.TextSize = 14
			t.TextColor3 = if ok then Color3.fromRGB(140, 220, 150) else C.lightGold
			t.Parent = b
		end
		head(mineBox, "You offer" .. (if s.confirmed then "  ·  confirmed" elseif s.ready then "  ·  locked in" else ""), s.ready == true)
		head(theirsBox, tostring(s.with) .. " offers" .. (if s.theyConfirmed then "  ·  confirmed" elseif s.theyReady then "  ·  locked in" else ""), s.theyReady == true)
		local mine = s.mine :: { [string]: number }
		offerRow(items[mineBox], mine, function(id: string)
			local o = table.clone(mine) :: { [string]: number? }
			local n = o[id] or 0
			o[id] = if n > 1 then n - 1 else nil
			setOffer(o)
		end)
		offerRow(items[theirsBox], s.theirs)
		-- The purse keys: add Gilt or Gems to your side (never more than you hold, or a trade's
		-- limit), or clear them.
		for _, c in purse:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local gilt = tonumber((game:GetService("Players").LocalPlayer :: Player):GetAttribute("Gilt")) or 0
		local gems = tonumber((game:GetService("Players").LocalPlayer :: Player):GetAttribute("Gems")) or 0
		local function purseKey(text: string, colour: Color3, width: number, fn: () -> ())
			local k = Theme.key(purse, text, false, fn, width)
			k.Size = UDim2.fromOffset(width, 34)
			k.TextColor3 = colour
			return k
		end
		local function add(key: string, n: number, most: number)
			local o = table.clone(mine) :: { [string]: number? }
			local now = (o[key] or 0) :: number
			o[key] = math.min(now + n, most)
			if (o[key] :: number) <= now then
				Toast.show("Trading", if key == GILT then "That's all the Gilt you can offer." else "That's all the Gems you can offer.", 2.5)
				return
			end
			setOffer(o)
		end
		local function clear(key: string)
			local o = table.clone(mine) :: { [string]: number? }
			o[key] = nil
			setOffer(o)
		end
		local maxGilt = math.min(tonumber(s.maxGilt) or 100000, gilt)
		local order = 0
		local function nextOrder(): number
			order += 1
			return order
		end
		purseKey("💰 +100", GOLD, 84, function()
			add(GILT, 100, maxGilt)
		end).LayoutOrder = nextOrder()
		purseKey("+1,000", GOLD, 80, function()
			add(GILT, 1000, maxGilt)
		end).LayoutOrder = nextOrder()
		purseKey("+10,000", GOLD, 88, function()
			add(GILT, 10000, maxGilt)
		end).LayoutOrder = nextOrder()
		if (mine[GILT] or 0) > 0 then
			purseKey("No Gilt", C.smoke, 84, function()
				clear(GILT)
			end).LayoutOrder = nextOrder()
		end
		if s.paid == true then
			local maxGems = math.min(tonumber(s.maxGems) or 100, gems, tonumber(s.gemsLeft) or 0)
			purseKey("💎 +1", GEM, 64, function()
				add(GEMS, 1, maxGems)
			end).LayoutOrder = nextOrder()
			purseKey("+10", GEM, 58, function()
				add(GEMS, 10, maxGems)
			end).LayoutOrder = nextOrder()
			if (mine[GEMS] or 0) > 0 then
				purseKey("No Gems", C.smoke, 84, function()
					clear(GEMS)
				end).LayoutOrder = nextOrder()
			end
		end
		-- Your tradeable curios, less what's already offered.
		for _, c in shelf:GetChildren() do
			c:Destroy()
		end
		local avail: { [string]: number } = {}
		for id, n in CurioState.items do
			local cu = Curios.byId[id]
			local left = n - (mine[id] or 0)
			-- (Curios bought with Gems only where Roblox allows both of you to trade them.)
			if cu and cu.tradeable and left > 0 and (s.paid == true or not Curios.isPaid(cu)) then
				avail[id] = left
			end
		end
		offerRow(shelf, avail, function(id: string)
			local o = table.clone(mine) :: { [string]: number? }
			o[id] = (o[id] or 0) + 1
			setOffer(o)
		end)
		if next(avail) == nil then
			Theme.text(shelf, "Nothing more to offer: curios you can trade show here.", 13, "body", { TextColor3 = C.dim })
		end
		for _, c in keys:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		if s.state == "open" then
			status.Text = if s.ready then "Locked in. Waiting for " .. tostring(s.with) .. "." else "Choose what to offer, then lock in."
			if s.ready then
				Theme.key(keys, "Unlock", false, function()
					send({ op = "unready" })
				end, 160).LayoutOrder = 1
			else
				Theme.key(keys, "Lock in", true, function()
					send({ op = "ready", version = s.version })
				end, 160).LayoutOrder = 1
			end
		elseif s.state == "countdown" then
			-- Counted down here, second by second, until the server opens confirming.
			task.spawn(function()
				for left = s.countdown, 1, -1 do
					if state ~= s or not status.Parent then
						return
					end
					status.Text = string.format("Both locked in. Confirm opens in %d...", left)
					task.wait(1)
				end
			end)
			Theme.key(keys, "Wait, unlock", false, function()
				send({ op = "unready" })
			end, 170).LayoutOrder = 1
		elseif s.state == "confirm" then
			status.Text = if s.confirmed then "Confirmed. Waiting for " .. tostring(s.with) .. "." else "Check both sides once more, then confirm."
			if not s.confirmed then
				Theme.key(keys, "Confirm the trade", true, function()
					send({ op = "confirm", version = s.version })
				end, 200).LayoutOrder = 1
			end
		end
		Theme.key(keys, "Cancel", false, function()
			send({ op = "cancel" })
		end, 130).LayoutOrder = 2
		Theme.key(keys, "Report", false, function()
			send({ op = "report", userId = s.withId })
			Toast.show("Trading", "Thank you. The house has a note of it.", 3)
		end, 120).LayoutOrder = 3
	end
	refresh = paint
	local conn = CurioState.Changed:Connect(paint)
	Root.open(NAME, group, function()
		refresh = nil
		conn:Disconnect()
	end)
	paint()
end

-- A trade's state from the server: open the screen, or bring it up to date.
function TradePanel.update(m: { [string]: any })
	state = m
	if Root.isOpen(NAME) and refresh then
		(refresh :: () -> ())()
	else
		TradePanel.open()
	end
end

function TradePanel.ended(m: { [string]: any })
	state = nil
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	if type(m.why) == "string" and m.why ~= "" then
		Toast.show(if m.state == "done" then "Trade done" else "Trading", m.why, 4)
	end
end

-- An invitation: a small card with three keys.
function TradePanel.invited(m: { [string]: any })
	if Root.isOpen(INVITE) then
		Root.close(INVITE)
	end
	local group, content = Theme.glass(Root.panels, INVITE, UDim2.fromOffset(math.min(420, Root.size().X - 24), 210))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "A trade?", 22, "display", { LayoutOrder = 1 })
	Theme.text(content, tostring(m.from) .. " would like to trade with you.", 14, "body", { LayoutOrder = 2, TextColor3 = C.smoke })
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 48)
	keys.LayoutOrder = 3
	keys.Parent = content
	Theme.list(keys, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function answer(op: string)
		Root.close(INVITE)
		send({ op = op, userId = m.userId })
	end
	Theme.key(keys, "Trade", true, function()
		answer("accept")
	end, 120).LayoutOrder = 1
	Theme.key(keys, "No thanks", false, function()
		answer("decline")
	end, 130).LayoutOrder = 2
	Theme.key(keys, "Block", false, function()
		answer("block")
	end, 110).LayoutOrder = 3
	Root.open(INVITE, group)
	-- It lapses on the server after a while; the card goes too.
	task.delay(30, function()
		if group.Parent and Root.isOpen(INVITE) then
			Root.close(INVITE)
		end
	end)
end

-- Asks a guest to trade (the Trade key on their card).
function TradePanel.invite(userId: number, name: string)
	task.spawn(function()
		local r = CurioState.trade({ op = "invite", userId = userId })
		if type(r) == "table" and r.ok then
			Toast.show("Trading", "Asked " .. name .. " to trade.", 3)
		else
			Toast.show("Trading", tostring(if type(r) == "table" and r.why then r.why else "One moment."), 3)
		end
	end)
end

function TradePanel.start()
	CurioState.Message:Connect(function(op: string, m: any)
		if op == "trade" then
			TradePanel.update(m)
		elseif op == "tradeEnd" then
			TradePanel.ended(m)
		elseif op == "tradeInvite" then
			TradePanel.invited(m)
		end
	end)
end

return TradePanel

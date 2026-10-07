--!strict
-- A trade with another guest (TradeService on the server decides everything). Your offer on the
-- left (tap your curios below to add them, tap an offered one to take it back), theirs on the
-- right, exactly as the server holds them. "Lock in" when you're happy; when you both have,
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
		table.insert(ids, id)
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
	local w = math.min(760, size.X - 24)
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
	Theme.text(content, "Your curios: tap one to offer it", 12, "caps", { LayoutOrder = 4, TextXAlignment = Enum.TextXAlignment.Left })
	local shelf = Instance.new("ScrollingFrame")
	shelf.Name = "YourCurios"
	shelf.BackgroundTransparency = 1
	shelf.BorderSizePixel = 0
	shelf.Size = UDim2.new(1, 0, 1, -(30 + 22 + 200 + 20 + 60 + 40))
	shelf.CanvasSize = UDim2.new()
	shelf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	shelf.ScrollBarThickness = 3
	shelf.LayoutOrder = 5
	shelf.Parent = content
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 48)
	keys.LayoutOrder = 6
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
		for _, b in { mineBox, theirsBox } do
			for _, c in b:GetChildren() do
				c:Destroy()
			end
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0, 30)
			pad.PaddingLeft = UDim.new(0, 8)
			pad.PaddingRight = UDim.new(0, 8)
			pad.Parent = b
		end
		local function head(b: Frame, text: string, ok: boolean)
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromOffset(0, -24)
			t.Size = UDim2.new(1, 0, 0, 20)
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
		offerRow(mineBox, mine, function(id: string)
			local o = table.clone(mine) :: { [string]: number? }
			local n = o[id] or 0
			o[id] = if n > 1 then n - 1 else nil
			setOffer(o)
		end)
		offerRow(theirsBox, s.theirs)
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
	Theme.text(content, tostring(m.from) .. " would like to trade curios with you.", 14, "body", { LayoutOrder = 2, TextColor3 = C.smoke })
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

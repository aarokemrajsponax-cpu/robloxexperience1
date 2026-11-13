--!strict
-- The Quartermaster's board (at his desk in the Executive's Anteroom), Build 81: going up, in three
-- numbered steps on the left, each with a plain state (a tick once it's done, never a key that
-- looks like one) and the one thing to do (take your free stun pistol; an invitation, every way to
-- earn one, and one to buy, its price on the key; then Go up now, once ready). On the right, the
-- optional gear for the next trip up, each a card: what it does, and Buy with its price, or a tick
-- once packed. Every figure and price is the server's (AttractionAsk "state"); the server takes
-- the price or says why, and the lift checks everything again.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Directory = require(ReplicatedStorage.Shared.Directory)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local ExecutivePanel = {}

local NAME = "Quartermaster"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local DONE = Color3.fromRGB(110, 230, 160)
local CARD = Color3.fromRGB(14, 16, 26)

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function frame(parent: Instance, name: string, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Size = UDim2.new(1, 0, 0, 0)
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

-- A card: dark glass with a fine edge, its words and keys stacked.
local function card(parent: Instance, name: string, order: number, edge: Color3): Frame
	local f = frame(parent, name, order)
	f.BackgroundColor3 = CARD
	f.BackgroundTransparency = 0.15
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = edge
	stroke.Transparency = 0.45
	stroke.Thickness = 1.2
	stroke.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = f
	Theme.list(f, 5).HorizontalAlignment = Enum.HorizontalAlignment.Left
	return f
end

local function words(parent: Instance, text: string, size: number, kind: string, order: number, colour: Color3?)
	Theme.text(parent, text, size, kind :: any, {
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = colour or C.smoke,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	})
end

-- A done state, said as a tick in green: plainly not a key.
local function tick(parent: Instance, text: string, order: number)
	local l = Theme.text(parent, "✓  " .. string.upper(text), 12, "caps", {
		Name = "Done",
		LayoutOrder = order,
		TextColor3 = DONE,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 18),
		TextWrapped = false,
	})
	local _ = l
end

function ExecutivePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local w = Root.panelWidth(780)
	local wide = w >= 640
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 640))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Executive Suite", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "The Quartermaster", 26, "display", { LayoutOrder = 2 })
	local body = frame(content, "Body", 3)
	Theme.list(body, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(body, "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })

	local fill: (s: { [string]: any }) -> ()
	local busy = false
	local function act(request: { [string]: any }, after: ((r: { [string]: any }) -> ())?)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = ask(request)
			busy = false
			if not r then
				Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
			elseif r.ok ~= true then
				Toast.show("Not yet", tostring(r.why or "Not just now."), 3)
			elseif after then
				after(r)
			elseif type(r.state) == "table" and group.Parent then
				Theme.haptic()
				fill(r.state)
			end
		end)
	end
	fill = function(s: { [string]: any })
		clear(body)
		local invites, most = tonumber(s.invites) or 0, tonumber(s.most) or 5
		local price = tonumber(s.invitePrice) or 25000
		local figures = Directory.figures({ executive = { inviteHaul = s.inviteHaul, invitePrice = s.invitePrice, most = s.most } })
		local armed = s.sidearm == true
		local ready = armed and invites > 0
		local gear = if type(s.gear) == "table" then s.gear else {}
		-- What's still needed, first, in one line.
		local needs = if ready then "You're ready: go up now, or take the lift at the end of this room."
			elseif invites > 0 then "One step left: take your free stun pistol (step 1)."
			elseif armed then "One thing left: an invitation (step 2)."
			else "Two things to go up: your free stun pistol, and an invitation."
		words(body, needs, 16, "bodyBold", 1, if ready then DONE else GOLD)
		-- The two columns (one above the other on a narrow screen).
		local columns = frame(body, "Columns", 2)
		local cl = Theme.list(columns, 12, wide)
		cl.VerticalAlignment = Enum.VerticalAlignment.Top
		cl.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local left = frame(columns, "GoingUp", 1)
		local right = frame(columns, "Gear", 2)
		if wide then
			local half = math.floor((w - 48 - 12) / 2)
			left.Size = UDim2.new(0, half, 0, 0)
			right.Size = UDim2.new(0, half, 0, 0)
		end
		Theme.list(left, 8).VerticalAlignment = Enum.VerticalAlignment.Top
		Theme.list(right, 8).VerticalAlignment = Enum.VerticalAlignment.Top
		local colW = if wide then math.floor((w - 48 - 12) / 2) else w - 48
		local keyW = math.min(300, colW - 24)

		-- Step 1: the stun pistol (free).
		local one = card(left, "Step1", 1, if armed then DONE else GOLD)
		words(one, "Step 1  ·  Your stun pistol", 11, "caps", 1, GOLD)
		for _, g in gear do
			if g.free then
				words(one, tostring(g.glyph or "") .. "  " .. tostring(g.name), 14, "bodyBold", 2, C.bone)
				words(one, tostring(g.line), 12, "body", 3)
			end
		end
		if armed then
			tick(one, "Taken: in your inventory", 4)
		else
			Theme.key(one, "Take it (free)", true, function()
				act({ op = "act", id = "executive", act = "sidearm" })
			end, keyW).LayoutOrder = 4
		end

		-- Step 2: an invitation, every way to get one.
		local two = card(left, "Step2", 2, if invites > 0 then DONE else GOLD)
		words(two, string.format("Step 2  ·  An invitation  ·  you hold %d of %d", invites, most), 11, "caps", 1, GOLD)
		words(two, "Each trip up uses one. Earn one free:", 12, "body", 2)
		local e = Directory.byId.executive
		local ways = e.ways or {}
		for n = 1, math.min(2, #ways) do
			words(two, string.format("%d.  %s", n, Directory.fill(ways[n], figures)), 12, "body", 2 + n, C.bone)
		end
		if invites > 0 then
			tick(two, string.format("You hold %d", invites), 6)
		end
		if invites < most then
			Theme.key(two, "3.  Buy one here  ·  " .. Rules.format(price) .. " Gilt", invites == 0, function()
				act({ op = "act", id = "executive", act = "invite" })
			end, keyW).LayoutOrder = 7
		else
			words(two, string.format("You hold the most there is (%d).", most), 12, "body", 7)
		end

		-- Step 3: up.
		local three = card(left, "Step3", 3, if ready then DONE else C.smoke)
		words(three, "Step 3  ·  The lift up", 11, "caps", 1, GOLD)
		if ready then
			words(three, "The lift at the end of this room takes you up too.", 12, "body", 2)
			Theme.key(three, "Go up now", true, function()
				act({ op = "go", id = "executive" }, function()
					Root.close(NAME)
				end)
			end, keyW).LayoutOrder = 3
		else
			words(three, "With your pistol and an invitation, it's one press from here (or the lift at the end of this room).", 12, "body", 2)
		end

		-- The gear: optional, for the next trip up.
		words(right, "Gear for your next trip up  ·  optional", 11, "caps", 1, GOLD)
		words(right, "Each piece is used up on your next trip, and works only in the Suite.", 12, "body", 2)
		local order = 2
		for _, g in gear do
			if not g.free then
				order += 1
				local c = card(right, "Gear_" .. tostring(g.id), order, if g.packed then DONE else C.smoke)
				words(c, tostring(g.glyph or "") .. "  " .. tostring(g.name), 14, "bodyBold", 1, C.bone)
				words(c, tostring(g.line), 12, "body", 2)
				if g.packed then
					tick(c, "Packed for your next trip", 3)
				else
					local cost = tonumber(g.price) or 0
					Theme.key(c, "Buy  ·  " .. Rules.format(cost) .. " Gilt", false, function()
						act({ op = "act", id = "executive", act = "gear", what = g.id })
					end, keyW).LayoutOrder = 3
				end
			end
		end
	end
	local close = Theme.key(content, "Close", false, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 20
	Root.open(NAME, group)
	task.spawn(function()
		local r = ask({ op = "state", id = "executive" })
		if not group.Parent then
			return
		end
		if r and r.ok == true then
			fill(r)
		else
			clear(body)
			Theme.text(body, "The Quartermaster's board couldn't be read just now. Try again in a moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
		end
	end)
end

function ExecutivePanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

return ExecutivePanel

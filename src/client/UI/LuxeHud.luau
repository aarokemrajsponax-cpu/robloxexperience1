--!strict
-- Steal a Luxe's own screen, shown only while a guest is in the residence (the server's
-- "Attraction" attribute): which wing they're in, the bag (a slot for each piece it holds, each in
-- its rarity's colour), what it's all worth and the banker's cut at the car, how near a guard is to
-- noticing them (and when one is after them: run), and two keys: Leave and Upgrades.
-- Everything it shows is what the server last said (op "luxe"); it decides nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local LuxeHud = {}

-- Set by Main: open the upgrades board.
LuxeHud.openBoard = function() end

local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local RED = Color3.fromRGB(235, 70, 80)
local CARD_W = 340
local CARD_H = 112
local SLOT = 28

local RARITY: { [string]: Color3 } = {
	Common = Color3.fromRGB(200, 200, 205),
	Uncommon = Color3.fromRGB(110, 210, 130),
	Rare = Color3.fromRGB(90, 160, 255),
	Epic = Color3.fromRGB(190, 110, 255),
	Legendary = Color3.fromRGB(255, 190, 60),
	Mythic = Color3.fromRGB(255, 90, 140),
}
LuxeHud.RARITY = RARITY

type View = { [string]: any }

local card: Frame? = nil
local keys: Frame? = nil
local parts: { [string]: any } = {}
local view: View = { bag = {}, capacity = 3, worth = 0, bonus = 0, wing = "The courtyard", watched = 0, chased = false, speed = 1, grace = false }
local beat: RBXScriptConnection? = nil
local topConn: RBXScriptConnection? = nil

local function label(parent: Instance, name: string, text: string, size: number, font: Font, colour: Color3, order: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.LayoutOrder = order or 0
	l.Parent = parent
	return l
end

local function place()
	local c = card
	if not c then
		return
	end
	-- Under whatever stands along the top, and under the row of keys at the top right (Shop, Menu,
	-- Settings: their foot is at 118).
	local y = math.max(Root.topClear("Luxe") + 6, 126)
	c.Position = UDim2.new(0.5, 0, 0, y)
	Root.setTop("Luxe", y + CARD_H + 4, CARD_W / 2)
	local k = keys
	if k then
		k.Position = UDim2.new(0.5, 0, 1, -(14 + Root.bottomClear()))
	end
end

local function draw()
	local c = card
	if not c then
		return
	end
	parts.wing.Text = string.upper(tostring(view.wing))
	-- The bag: a slot for each piece it can hold.
	local slots = parts.slots :: Frame
	for _, child in slots:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local capacity = math.max(1, math.floor(tonumber(view.capacity) or 3))
	local bag = if type(view.bag) == "table" then view.bag else {}
	-- (A big bag's slots are smaller, so they all fit on their row.)
	local size = math.min(SLOT, math.floor((CARD_W - 28 - 56 + 5) / capacity) - 5)
	for i = 1, capacity do
		local piece = bag[i]
		local s = Instance.new("Frame")
		s.Name = "Slot" .. i
		s.Size = UDim2.fromOffset(size, size)
		s.BackgroundColor3 = if piece then Color3.fromRGB(34, 28, 20) else Color3.fromRGB(22, 21, 26)
		s.BackgroundTransparency = if piece then 0 else 0.3
		s.LayoutOrder = i
		s.Parent = slots
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = s
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = if piece then (RARITY[tostring(piece.rarity)] or GOLD) else Color3.fromRGB(80, 74, 66)
		edge.Thickness = if piece then 1.6 else 1
		edge.Transparency = if piece then 0 else 0.4
		edge.Parent = s
		if piece then
			local g = Instance.new("TextLabel")
			g.Name = "Glyph"
			g.BackgroundTransparency = 1
			g.Size = UDim2.fromScale(1, 1)
			g.Text = tostring(piece.glyph or "✦")
			g.TextSize = 17
			g.FontFace = Brand.Fonts.body
			g.TextColor3 = Color3.new(1, 1, 1)
			g.Parent = s
		end
	end
	local worth = tonumber(view.worth) or 0
	local bonus = tonumber(view.bonus) or 0
	parts.count.Text = string.format("%d / %d", #bag, capacity)
	if #bag == 0 then
		parts.worth.Text = "Take what you can carry  ·  bank it at the car"
		parts.worth.TextColor3 = C.smoke
	else
		parts.worth.Text = "Carrying " .. Rules.format(worth) .. (if bonus > 0 then string.format("  ·  +%d%% at the car", math.floor(bonus * 100 + 0.5)) else "  ·  bank it at the car")
		parts.worth.TextColor3 = GOLD
	end
	-- The guards.
	local watched = math.clamp(tonumber(view.watched) or 0, 0, 1)
	parts.fill.Size = UDim2.new(watched, 0, 1, 0)
	parts.fill.BackgroundColor3 = Color3.fromRGB(255, 196, 80):Lerp(RED, watched)
	if view.chased then
		parts.seen.Text = "A GUARD IS AFTER YOU  ·  RUN"
		parts.seen.TextColor3 = RED
	elseif view.grace then
		parts.seen.Text = "NOBODY HAS NOTICED YOU YET"
		parts.seen.TextColor3 = C.smoke
	elseif watched > 0.05 then
		parts.seen.Text = "A GUARD IS NOTICING YOU"
		parts.seen.TextColor3 = Color3.fromRGB(255, 196, 80)
	else
		parts.seen.Text = "UNSEEN"
		parts.seen.TextColor3 = C.smoke
	end
	local speed = tonumber(view.speed) or 1
	parts.pace.Text = string.format("PACE %d%%", math.floor(speed * 100 + 0.5))
end

function LuxeHud.mounted(): boolean
	return card ~= nil
end

function LuxeHud.mount()
	if card then
		return
	end
	local c = Instance.new("Frame")
	c.Name = "LuxeCard"
	c.AnchorPoint = Vector2.new(0.5, 0)
	c.Size = UDim2.fromOffset(CARD_W, CARD_H)
	c.BackgroundColor3 = Color3.fromRGB(14, 12, 16)
	c.BackgroundTransparency = 0.08
	c.Parent = Root.hud
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = c
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = GOLD
	edge.Thickness = 1.25
	edge.Transparency = 0.3
	edge.Parent = c
	parts.edge = edge
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = c
	-- Its heading: the attraction and the wing.
	local title = label(c, "Title", "STEAL A LUXE", 11, Brand.Fonts.bodyBold, GOLD)
	title.Position = UDim2.fromOffset(0, 0)
	parts.wing = label(c, "Wing", "THE COURTYARD", 11, Brand.Fonts.bodyBold, C.bone)
	parts.wing.TextXAlignment = Enum.TextXAlignment.Right
	parts.wing.Position = UDim2.fromOffset(0, 0)
	-- The bag.
	local slots = Instance.new("Frame")
	slots.Name = "Bag"
	slots.BackgroundTransparency = 1
	slots.Position = UDim2.fromOffset(0, 22)
	slots.Size = UDim2.new(1, -56, 0, SLOT)
	slots.Parent = c
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = UDim.new(0, 5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Parent = slots
	parts.slots = slots
	parts.count = label(c, "Count", "0 / 3", 13, Brand.Fonts.figures, C.bone)
	parts.count.TextXAlignment = Enum.TextXAlignment.Right
	parts.count.Position = UDim2.fromOffset(0, 22 + (SLOT - 19) / 2)
	parts.worth = label(c, "Worth", "", 13, Brand.Fonts.bodyBold, GOLD)
	parts.worth.Position = UDim2.fromOffset(0, 54)
	-- How near a guard is to noticing.
	parts.seen = label(c, "Seen", "UNSEEN", 10, Brand.Fonts.bodyBold, C.smoke)
	parts.seen.Position = UDim2.fromOffset(0, 74)
	parts.pace = label(c, "Pace", "PACE 100%", 10, Brand.Fonts.bodyBold, C.smoke)
	parts.pace.TextXAlignment = Enum.TextXAlignment.Right
	parts.pace.Position = UDim2.fromOffset(0, 74)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromOffset(0, 94)
	track.Size = UDim2.new(1, 0, 0, 4)
	track.BackgroundColor3 = Color3.fromRGB(48, 42, 36)
	track.BorderSizePixel = 0
	track.Parent = c
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.fromRGB(255, 196, 80)
	fill.Parent = track
	parts.fill = fill
	card = c

	-- Leave and Upgrades, at the foot of the screen.
	local k = Instance.new("Frame")
	k.Name = "LuxeKeys"
	k.AnchorPoint = Vector2.new(0.5, 1)
	k.BackgroundTransparency = 1
	k.Size = UDim2.fromOffset(300, 44)
	k.Parent = Root.hud
	Theme.list(k, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(k, "Leave", false, function()
		task.spawn(function()
			local ok, r = pcall(function()
				return Remotes.func("AttractionAsk"):InvokeServer({ op = "home" })
			end)
			if ok and type(r) == "table" and r.ok ~= true and type(r.why) == "string" then
				Toast.show("Not just now", r.why, 3)
			end
		end)
	end, 130)
	Theme.key(k, "Upgrades", true, function()
		LuxeHud.openBoard()
	end, 130)
	keys = k

	place()
	draw()
	topConn = Root.TopChanged:Connect(place)
	-- The edge glows red while a guard is after them.
	local t = 0
	beat = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local e = parts.edge :: UIStroke
		if view.chased then
			e.Color = RED
			e.Transparency = 0.1 + 0.3 * (0.5 + 0.5 * math.sin(t * 9))
		else
			e.Color = GOLD
			e.Transparency = 0.3
		end
	end)
end

function LuxeHud.unmount()
	if beat then
		beat:Disconnect()
		beat = nil
	end
	if topConn then
		topConn:Disconnect()
		topConn = nil
	end
	if card then
		card:Destroy()
		card = nil
	end
	if keys then
		keys:Destroy()
		keys = nil
	end
	parts = {}
	view = { bag = {}, capacity = 3, worth = 0, bonus = 0, wing = "The courtyard", watched = 0, chased = false, speed = 1, grace = false }
	Root.setTop("Luxe", nil)
end

-- What the server says about the guest's run.
function LuxeHud.on(m: { [string]: any })
	local op = m.op
	if op == "luxe" then
		view = m
		draw()
	elseif op == "took" then
		Toast.show("Taken: " .. tostring(m.name), string.format("%s  ·  %s  ·  worth %s", tostring(m.glyph or ""), tostring(m.rarity or ""), Rules.format(tonumber(m.worth) or 0)), 2.5)
	elseif op == "banked" then
		local line = string.format("%s to your Estate  ·  %s Gilt to your purse", Rules.format(tonumber(m.worth) or 0), Rules.format(tonumber(m.gilt) or 0))
		if (tonumber(m.gems) or 0) > 0 then
			line ..= string.format("  ·  %d Gems", m.gems)
		end
		if type(m.brainrots) == "table" and #m.brainrots > 0 then
			line ..= "  ·  a brainrot for your collection"
		end
		Toast.show(if m.record then "A record haul: " .. Rules.format(tonumber(m.worth) or 0) else "Banked: " .. Rules.format(tonumber(m.worth) or 0), line, 5)
	elseif op == "caught" then
		local n = tonumber(m.n) or 0
		Toast.show("Caught", if n > 0 then string.format("The guards took back %d %s (%s). You're shown out to the courtyard.", n, if n == 1 then "piece" else "pieces", Rules.format(tonumber(m.lost) or 0)) else "You're shown out to the courtyard.", 5)
	elseif op == "spotted" then
		view.chased = true
		draw()
	end
end

return LuxeHud

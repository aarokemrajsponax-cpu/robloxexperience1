--!strict
-- The Brainrots tab of your Collection: the tip jar your squad fills with Gilt every hour (collect
-- it; or a Feast, eight hours of it at once, at its price), your squad's places (who earns, who
-- walks beside you, and three more in the Penthouse), and every brainrot you hold, with its stars
-- and what it would earn. Every number comes from the server (CurioState.squad); the jar ticks up
-- on screen between its messages, at the rate it said.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local CurioArt = require(script.Parent.CurioArt)
local CurioState = require(script.Parent.Parent.CurioState)

local BrainrotSquad = {}

local rgb = Color3.fromRGB
local C = Brand.Colours
local ROBUX = utf8.char(0xE002)
local GREEN = rgb(96, 222, 132)
local DEEP = rgb(22, 110, 60)
local CARD = rgb(26, 24, 30)

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end
BrainrotSquad.commas = commas

local function corner(f: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

local function stroke(f: GuiObject, colour: Color3, thickness: number?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = colour
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.Parent = f
	return s
end

local function box(parent: Instance, name: string, order: number, size: UDim2, colour: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour or CARD
	f.BackgroundTransparency = if colour then (transparency or 0) else 1
	f.Size = size
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, text: string, size: number, font: Font, colour: Color3, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = font
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Size = UDim2.new(1, 0, 0, size + 6)
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

-- A glossy green key (Collect, Add): the action the squad is about.
local function greenKey(parent: Instance, name: string, text: string, size: UDim2, onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BorderSizePixel = 0
	b.Size = size
	b.Text = text
	b.FontFace = Brand.Fonts.heavy
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.TextStrokeColor3 = rgb(6, 40, 18)
	b.TextStrokeTransparency = 0.4
	b.Parent = parent
	corner(b, 12)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, GREEN:Lerp(Color3.new(1, 1, 1), 0.25)),
		ColorSequenceKeypoint.new(0.55, GREEN:Lerp(DEEP, 0.45)),
		ColorSequenceKeypoint.new(1, DEEP),
	})
	g.Parent = b
	stroke(b, GREEN:Lerp(Color3.new(1, 1, 1), 0.4), 1.5, 0.2)
	b.Activated:Connect(onPress)
	return b
end

-- Asks the server; says why if it says no.
local function ask(request: { [string]: any }, title: string): { [string]: any }?
	local r = CurioState.ask(request)
	if type(r) ~= "table" then
		Toast.show(title, "One moment, the house is busy.", 3)
		return nil
	end
	if not r.ok and r.why then
		Toast.show(title, tostring(r.why), 3)
	end
	return r
end

local function info(): { [string]: any }
	return CurioState.squad or { ids = {}, mut = {}, slots = Brainrots.SLOTS, rate = 0, held = 0, cap = 0, feast = 0, prices = {}, wing = false }
end

-- The tip jar: what's in it now (ticking), how full, what the squad earns, Collect and a Feast.
local function jarCard(parent: Instance, width: number, order: number)
	local s = info()
	local card = box(parent, "Jar", order, UDim2.fromOffset(width, 132), Color3.new(1, 1, 1), 0)
	corner(card, 14)
	stroke(card, GREEN, 1.5, 0.35)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(rgb(36, 74, 50), rgb(14, 26, 18))
	g.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingTop = UDim.new(0, 12)
	pad.Parent = card
	local right = 210
	label(card, "Title", "💰  TIP JAR", 14, Brand.Fonts.heavy, GREEN, { Size = UDim2.new(1, -right, 0, 18) })
	local amount = label(card, "Amount", "0 Gilt", 30, Brand.Fonts.heavy, rgb(236, 255, 240), { Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, -right, 0, 36) })
	local track = box(card, "Track", 0, UDim2.new(1, -right, 0, 12), rgb(10, 14, 12), 0)
	track.Position = UDim2.fromOffset(0, 62)
	corner(track, 6)
	local fill = box(track, "Fill", 0, UDim2.fromScale(0, 1), Color3.new(1, 1, 1), 0)
	corner(fill, 6)
	local fg = Instance.new("UIGradient")
	fg.Color = ColorSequence.new(GREEN:Lerp(Color3.new(1, 1, 1), 0.2), rgb(250, 214, 90))
	fg.Parent = fill
	local status = label(card, "Status", "", 13, Brand.Fonts.bodyMedium, C.smoke, { Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, -right, 0, 18) })
	local earn = label(card, "Earns", "", 13, Brand.Fonts.body, C.dim, { Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, -right, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	-- Collect, and the Feast under it.
	local collect = greenKey(card, "Collect", "COLLECT", UDim2.fromOffset(right - 14, 50), function()
		task.spawn(function()
			local r = ask({ op = "collect" }, "Tip jar")
			if r and r.ok then
				Toast.show("Tip jar", string.format("+%s Gilt from your brainrots", commas(r.gilt or 0)), 3)
			end
		end)
	end)
	collect.AnchorPoint = Vector2.new(1, 0)
	collect.Position = UDim2.new(1, 0, 0, 4)
	local feastPrice = s.prices and s.prices.brainrotFeast
	local feastText = if feastPrice then string.format("FEAST  +%s  ·  %s %d", Brainrots.short(s.feast or 0), ROBUX, feastPrice) else "FEAST  ·  NOT ON SALE YET"
	local feast = Theme.key(card, feastText, false, function()
		if not feastPrice then
			return
		end
		task.spawn(function()
			ask({ op = "brainrotBuy", key = "brainrotFeast" }, "Brainrot Feast")
		end)
	end, right - 14)
	feast.Name = "Feast"
	feast.AnchorPoint = Vector2.new(1, 0)
	feast.Position = UDim2.new(1, 0, 0, 62)
	feast.Size = UDim2.fromOffset(right - 14, 40)
	local function tick()
		local now, cap, rate = CurioState.jar()
		amount.Text = commas(now) .. " Gilt"
		fill.Size = UDim2.fromScale(if cap > 0 then math.clamp(now / cap, 0, 1) else 0, 1)
		if rate <= 0 then
			status.Text = "Put a brainrot in your squad and it fills this every hour."
		elseif now >= cap - 0.5 then
			status.Text = string.format("Full: %s Gilt. Collect it so your squad keeps earning.", commas(cap))
		else
			local secs = (cap - now) / rate * 3600
			status.Text = string.format("of %s  ·  full in %dh %02dm", commas(cap), math.floor(secs / 3600), math.floor(secs % 3600 / 60))
		end
		local left, mult = CurioState.frenzy()
		if left > 0 then
			earn.Text = string.format("MEME FRENZY ×%d: %s Gilt an hour for %d:%02d more.", mult, commas(rate * mult), math.floor(left / 60), math.floor(left % 60))
			earn.TextColor3 = rgb(255, 214, 90)
		else
			earn.Text = string.format("Your squad earns %s Gilt an hour, even while you're away.", commas(rate))
			earn.TextColor3 = C.dim
		end
		collect.BackgroundTransparency = if now >= 1 then 0 else 0.5
	end
	tick()
	task.spawn(function()
		while card.Parent do
			task.wait(0.5)
			if card.Parent then
				tick()
			end
		end
	end)
end

-- One place in the squad: the brainrot, its stars and mutation, what it earns, Walk and Out.
local function slotCard(parent: Instance, id: string?, order: number, locked: boolean)
	local s = info()
	local card = box(parent, "Slot" .. order, order, UDim2.new(), CARD, 0)
	corner(card, 12)
	if locked then
		card.BackgroundColor3 = rgb(18, 16, 20)
		stroke(card, C.gold, 1, 0.6)
		label(card, "Lock", "🔒", 34, Brand.Fonts.heavy, C.gold, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 44) })
		label(card, "Words", "PENTHOUSE PLACE", 13, Brand.Fonts.heavy, C.lightGold, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 18) })
		label(card, "Line", "Three more brainrots earning", 12, Brand.Fonts.body, C.dim, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 16) })
		return
	end
	if not id then
		stroke(card, GREEN, 1, 0.7)
		label(card, "Plus", "+", 40, Brand.Fonts.heavy, GREEN, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 48) })
		label(card, "Words", "AN EMPTY PLACE", 13, Brand.Fonts.heavy, C.bone, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 18) })
		label(card, "Line", "Add a brainrot from below", 12, Brand.Fonts.body, C.dim, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 16) })
		return
	end
	local c = Curios.byId[id]
	local n = CurioState.count(id)
	local mut = if type(s.mut) == "table" then s.mut[id] else nil
	local rarityColour = Curios.RarityColour[c.rarity] or C.gold
	local walking = s.walk == id
	stroke(card, if walking then GREEN else rarityColour, if walking then 2 else 1.5, if walking then 0 else 0.35)
	local medal = CurioArt.medallion(card, id, 70)
	medal.AnchorPoint = Vector2.new(0.5, 0)
	medal.Position = UDim2.new(0.5, 0, 0, 10)
	CurioArt.mutate(medal, mut)
	local tag = (if mut then string.upper(Brainrots.Mutations[mut].name) .. "  ·  " else "") .. string.upper(c.rarity)
	label(card, "Name", c.name, 14, Brand.Fonts.heavy, C.bone, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(6, 84), Size = UDim2.new(1, -12, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
	label(card, "Rarity", tag, 11, Brand.Fonts.heavy, if mut then Brainrots.Mutations[mut].colour else rarityColour, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 102), Size = UDim2.new(1, 0, 0, 14) })
	label(card, "Stars", Brainrots.starText(Brainrots.stars(n)), 15, Brand.Fonts.heavy, rgb(255, 210, 80), { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 18) })
	label(card, "Rate", string.format("+%s Gilt/hr", commas(Brainrots.rate(id, n, mut))), 14, Brand.Fonts.heavy, GREEN, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 138), Size = UDim2.new(1, 0, 0, 18) })
	local keys = box(card, "Keys", 0, UDim2.new(1, -16, 0, 34))
	keys.Position = UDim2.new(0, 8, 1, -42)
	local walk = Instance.new("TextButton")
	walk.Name = "Walk_" .. id
	walk.AutoButtonColor = false
	walk.Size = UDim2.new(0.62, -4, 1, 0)
	walk.BackgroundColor3 = if walking then GREEN else rgb(40, 38, 44)
	walk.Text = if walking then "WALKING ✓" else "WALK WITH ME"
	walk.FontFace = Brand.Fonts.heavy
	walk.TextSize = 12
	walk.TextColor3 = if walking then rgb(8, 40, 18) else C.bone
	walk.Parent = keys
	corner(walk, 8)
	walk.Activated:Connect(function()
		task.spawn(function()
			ask({ op = "walk", id = if walking then nil else id }, "Brainrots")
		end)
	end)
	local out = Instance.new("TextButton")
	out.Name = "Out_" .. id
	out.AutoButtonColor = false
	out.AnchorPoint = Vector2.new(1, 0)
	out.Position = UDim2.fromScale(1, 0)
	out.Size = UDim2.new(0.38, -4, 1, 0)
	out.BackgroundColor3 = rgb(40, 38, 44)
	out.Text = "OUT"
	out.FontFace = Brand.Fonts.heavy
	out.TextSize = 12
	out.TextColor3 = C.smoke
	out.Parent = keys
	corner(out, 8)
	out.Activated:Connect(function()
		task.spawn(function()
			ask({ op = "squadRemove", id = id }, "Brainrots")
		end)
	end)
end

-- One brainrot you hold that isn't placed: its stars, copies to the next star, and Add.
local function heldCard(parent: Instance, id: string, order: number, full: boolean)
	local s = info()
	local c = Curios.byId[id]
	local n = CurioState.count(id)
	local mut = if type(s.mut) == "table" then s.mut[id] else nil
	local card = box(parent, "Brainrot_" .. id, order, UDim2.new(), CARD, 0)
	corner(card, 10)
	stroke(card, Curios.RarityColour[c.rarity] or C.gold, 1, 0.55)
	local medal = CurioArt.medallion(card, id, 54)
	medal.AnchorPoint = Vector2.new(0.5, 0)
	medal.Position = UDim2.new(0.5, 0, 0, 8)
	CurioArt.mutate(medal, mut)
	if n > 1 then
		local count = label(card, "Count", "×" .. tostring(n), 12, Brand.Fonts.heavy, C.lightGold, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(34, 18), BackgroundTransparency = 0, BackgroundColor3 = rgb(14, 10, 10), TextXAlignment = Enum.TextXAlignment.Center })
		corner(count, 9)
	end
	label(card, "Name", c.name, 12, Brand.Fonts.bodyBold, C.bone, { TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Position = UDim2.fromOffset(4, 64), Size = UDim2.new(1, -8, 0, 30), TextYAlignment = Enum.TextYAlignment.Top })
	local nextAt = Brainrots.nextStar(n)
	label(card, "Stars", Brainrots.starText(Brainrots.stars(n)), 12, Brand.Fonts.heavy, rgb(255, 210, 80), { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 14) })
	label(card, "Rate", string.format("+%s/hr%s", Brainrots.short(Brainrots.rate(id, n, mut)), if nextAt then string.format("  ·  ★ at %d", nextAt) else ""), 11, Brand.Fonts.bodyBold, GREEN, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 14) })
	if full then
		label(card, "Full", "SQUAD FULL", 11, Brand.Fonts.heavy, C.dim, { TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 22) })
	else
		local add = greenKey(card, "Add_" .. id, "ADD", UDim2.new(1, -16, 0, 28), function()
			task.spawn(function()
				ask({ op = "squadAdd", id = id }, "Brainrots")
			end)
		end)
		add.TextSize = 13
		add.Position = UDim2.new(0, 8, 1, -34)
	end
end

-- Draws the whole tab into `shelf` (a vertical list), `width` across.
function BrainrotSquad.draw(shelf: Instance, width: number)
	local s = info()
	local list = Theme.list(shelf, 12)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	jarCard(shelf, width, 1)

	-- The squad's places.
	local ids: { string } = if type(s.ids) == "table" then s.ids else {}
	local slots = if type(s.slots) == "number" then s.slots else Brainrots.SLOTS
	local head = box(shelf, "SquadHead", 2, UDim2.fromOffset(width, 30))
	label(head, "Title", string.format("YOUR SQUAD  ·  %d / %d", #ids, slots), 16, Brand.Fonts.heavy, C.bone, { Size = UDim2.new(1, -230, 1, 0) })
	local penthouse = s.prices and s.prices.brainrotPenthouse
	if not s.wing then
		local k = Theme.key(head, if penthouse then string.format("PENTHOUSE +3  ·  %s %d", ROBUX, penthouse) else "PENTHOUSE · NOT ON SALE YET", true, function()
			if not penthouse then
				return
			end
			task.spawn(function()
				ask({ op = "brainrotBuy", key = "brainrotPenthouse" }, "Brainrot Penthouse")
			end)
		end, 224)
		k.Name = "Penthouse"
		k.AnchorPoint = Vector2.new(1, 0.5)
		k.Position = UDim2.new(1, 0, 0.5, 0)
		k.Size = UDim2.fromOffset(224, 30)
	end
	local row = box(shelf, "Squad", 3, UDim2.fromOffset(width, 0))
	row.AutomaticSize = Enum.AutomaticSize.Y
	local grid = Instance.new("UIGridLayout")
	local cell = math.floor((width - 2 * 10) / 3)
	grid.CellSize = UDim2.fromOffset(cell, 204)
	grid.CellPadding = UDim2.fromOffset(10, 10)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = row
	local shown = if s.wing then slots else Brainrots.SLOTS + Brainrots.WING_SLOTS
	for i = 1, shown do
		slotCard(row, ids[i], i, i > slots)
	end

	-- Every brainrot held that isn't placed.
	local spare: { string } = {}
	local found = 0
	for _, id in Brainrots.all() do
		if CurioState.count(id) > 0 then
			found += 1
			if not table.find(ids, id) then
				table.insert(spare, id)
			end
		end
	end
	local all = #Brainrots.all()
	label(shelf, "HeldTitle", string.format("YOUR BRAINROTS  ·  %d OF %d FOUND", found, all), 16, Brand.Fonts.heavy, C.bone, { LayoutOrder = 4, Size = UDim2.fromOffset(width, 22) })
	if #spare == 0 then
		label(shelf, "Empty", if found == 0 then "Bank a run at any table and a brainrot may turn up among the pieces. The first goes straight into your squad." else "Every brainrot you hold is in your squad. More copies give them stars; rarer ones earn far more.", 13, Brand.Fonts.body, C.smoke, { LayoutOrder = 5, Size = UDim2.fromOffset(width, 40), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	else
		local held = box(shelf, "Held", 5, UDim2.fromOffset(width, 0))
		held.AutomaticSize = Enum.AutomaticSize.Y
		local hg = Instance.new("UIGridLayout")
		local per = math.max(3, math.floor((width + 8) / 128))
		hg.CellSize = UDim2.fromOffset(math.floor((width - (per - 1) * 8) / per), 172)
		hg.CellPadding = UDim2.fromOffset(8, 8)
		hg.SortOrder = Enum.SortOrder.LayoutOrder
		hg.Parent = held
		for i, id in spare do
			heldCard(held, id, i, #ids >= slots)
		end
	end
	label(shelf, "How", "★ More copies of a brainrot give it stars: each star earns half again. Found at the tables, one may come Gold (×2), Diamond (×3) or Rainbow (×5). The one walking with you adds its bonus to every run you bank. Scores are never touched.", 12, Brand.Fonts.body, C.dim, { LayoutOrder = 6, Size = UDim2.fromOffset(width, 48), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
end

return BrainrotSquad

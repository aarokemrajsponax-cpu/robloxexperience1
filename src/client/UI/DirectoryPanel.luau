--!strict
-- The Maison Directory (the Play key at the top right, the Menu's first tile): every game in the
-- house on a card of its own (shared/Directory): its picture, what it is, whether it's open to you
-- and what opens it if not, and how far you've come in it. Whether a game is open, and every
-- figure, is the server's (AttractionAsk "directory"); the cards only draw them, and a card that
-- says open never opens a door by itself (the server checks again at the door).
--
-- A tap on a card opens its closer look (over the cards, which come back as they were when it
-- closes): how it plays, what it pays, how to open it, and the ways there. Go in (standing in the
-- room its way in is in), Take me there (the house takes you to that room) and Walk me there (the
-- Concierge's gold arrows; nobody is moved). Close, the ✕, Escape or B put either away.
--
-- Every card has the same shape and the same places for the same things. Pointed at, a card lifts
-- and its edge brightens; pressed, it gives a little; the one last looked at keeps a gold edge;
-- one that's closed to you is dimmed under a lock, its line saying what opens it. Three cards
-- across on a computer, two on a tablet beside the dock, and smaller pictures on a phone on its
-- side so both rows fit without scrolling.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local BasementRules = require(ReplicatedStorage.Shared.Basement)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Directory = require(ReplicatedStorage.Shared.Directory)
local Ease = require(ReplicatedStorage.Shared.Ease)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local PieceIcon = require(script.Parent.PieceIcon)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local DirectoryPanel = {}

local NAME = "Directory"
local CARD = "DirectoryCard"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local rgb = Color3.fromRGB

-- Set by Main: to a place by the house (Travel "go"), the gold arrows there (Travel "way"), into an
-- attraction from the room its way in is in (AttractionAsk "go"), whether the guest is at a table.
DirectoryPanel.go = function(_place: string) end
DirectoryPanel.walk = function(_place: string) end
DirectoryPanel.enter = function(_id: string) end
DirectoryPanel.isSeated = function(): boolean
	return false
end

local player = Players.LocalPlayer

-- The server's last word on the cards (nil: not asked yet, or no answer).
local status: { [string]: any }? = nil
-- The card last looked at closely (kept gold-edged when the cards come back).
local selected: string? = nil
-- Each card on screen, redrawn when the server's word arrives.
local redraws: { [string]: () -> () } = {}
local spinning: { RBXScriptConnection } = {}

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function still(): boolean
	return State.get("movement") == "Still"
end

---------------------------------------------------------------------------------------------------
-- What the server says of each card
---------------------------------------------------------------------------------------------------
-- An entry's card from the server (the Grand Auction, in the Library, is always open).
local function cardOf(e: Directory.Entry): { [string]: any }?
	if not e.attraction then
		return { open = true }
	end
	local s = status
	local cards = s and s.cards
	if type(cards) == "table" and type(cards[e.attraction]) == "table" then
		return cards[e.attraction]
	end
	return nil
end

-- Whether an entry is open to the guest: true, false, or nil (the server hasn't said).
local function isOpen(e: Directory.Entry): boolean?
	local c = cardOf(e)
	if c == nil then
		return nil
	end
	return c.open == true
end

-- The figures its words quote: the server's, else the house's own settings.
local function figures(): { [string]: string }
	local s = status
	return Directory.figures(if s and type(s.cards) == "table" then s.cards else nil)
end

local function fill(text: string): string
	return Directory.fill(text, figures())
end

-- The short line under a card's name: how far you've come in it, or what opens it.
local function progress(e: Directory.Entry): string?
	local c = cardOf(e)
	if c == nil then
		return nil
	end
	local open = c.open == true
	if e.id == "luxe" then
		local hauls = tonumber(c.hauls) or 0
		if hauls <= 0 then
			return "No hauls banked yet"
		end
		return string.format("%s  ·  best %s", if hauls == 1 then "1 haul" else tostring(hauls) .. " hauls", Rules.format(tonumber(c.best) or 0))
	elseif e.id == "basement" then
		local deepest, stages = tonumber(c.deepest) or 0, tonumber(c.stages) or BasementRules.STAGES
		local clears = tonumber(c.clears) or 0
		if clears > 0 then
			return string.format("Cleared %s", if clears == 1 then "once" else tostring(clears) .. " times")
		elseif deepest > 0 then
			return string.format("Deepest: stage %d of %d", math.min(deepest, stages), stages)
		end
		return string.format("%d stages to the Treasury", stages)
	elseif e.id == "executive" then
		local n = tonumber(c.invites) or 0
		if open then
			return string.format("%s held", if n == 1 then "1 invitation" else tostring(n) .. " invitations")
		end
		return "Needs an invitation"
	elseif e.id == "gala" then
		local cap = tonumber(c.galaGilt) or 0
		if cap > 0 then
			return string.format("Today: %s of %s Gilt", Rules.format(tonumber(c.giltToday) or 0), Rules.format(cap))
		end
		return nil
	elseif e.id == "island" then
		if open then
			return "The Island Key is yours"
		end
		return if c.rankReady == true then "Ready for the Island Key" else "Needs the Island Key"
	elseif e.id == "auction" then
		return "New lots every week"
	end
	return nil
end

-- What's on in the house right now, if anything (an event or a holiday): its glyph, name, line.
local function happening(): (string?, string?, string?)
	local now = Workspace:GetServerTimeNow()
	for _, ev in HouseEvents.List do
		local ends = Workspace:GetAttribute(HouseEvents.attribute(ev.id))
		if type(ends) == "number" and ends > now then
			return ev.glyph, ev.name, ev.line
		end
	end
	return nil, nil, nil
end

-- Why the ways there can't be used just now, if they can't.
local function blocked(e: Directory.Entry): string?
	if DirectoryPanel.isSeated() then
		return "Leave your table first."
	end
	local inside = player:GetAttribute(AttractionList.ATTRIBUTE)
	if type(inside) == "string" then
		local def = AttractionList.byId[inside]
		if e.attraction == inside then
			return "You're in it now."
		end
		return string.format("You're in %s: leave it by its way out first.", if def then def.name else "an attraction")
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- A card's picture: its colours, a pool of light, and its treasure, turning gently
---------------------------------------------------------------------------------------------------
local function picture(parent: Instance, e: Directory.Entry, height: number, px: number, corner: number): Frame
	local art = Instance.new("Frame")
	art.Name = "Picture"
	art.BorderSizePixel = 0
	art.BackgroundColor3 = Color3.new(1, 1, 1)
	art.Size = UDim2.new(1, 0, 0, height)
	art.ClipsDescendants = true
	art.Parent = parent
	local ac = Instance.new("UICorner")
	ac.CornerRadius = UDim.new(0, corner)
	ac.Parent = art
	local shade = Instance.new("UIGradient")
	shade.Rotation = 35
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, e.accent:Lerp(Color3.new(1, 1, 1), 0.08)),
		ColorSequenceKeypoint.new(0.55, e.accent:Lerp(e.deep, 0.62)),
		ColorSequenceKeypoint.new(1, e.deep),
	})
	shade.Parent = art
	-- (A fine sheen across it, like light on lacquer.)
	local sheen = Instance.new("Frame")
	sheen.Name = "Sheen"
	sheen.BorderSizePixel = 0
	sheen.BackgroundColor3 = Color3.new(1, 1, 1)
	sheen.BackgroundTransparency = 0.86
	sheen.AnchorPoint = Vector2.new(0.5, 0.5)
	sheen.Position = UDim2.fromScale(0.3, 0.1)
	sheen.Size = UDim2.new(0, 46, 2, 0)
	sheen.Rotation = 28
	sheen.Parent = art
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Rotation = 90
	sg.Parent = sheen
	-- The pool of light the treasure sits in.
	for k, size in { 1.0, 0.74, 0.5 } do
		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromScale(0.5, 0.52)
		glow.Size = UDim2.fromOffset(px * 1.5 * size, px * 1.5 * size)
		glow.BorderSizePixel = 0
		glow.BackgroundColor3 = e.accent:Lerp(Color3.new(1, 1, 1), 0.55)
		glow.BackgroundTransparency = 0.9 - k * 0.025
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(0.5, 0)
		gc.Parent = glow
		glow.Parent = art
	end
	local holder = Instance.new("Frame")
	holder.Name = "Treasure"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.52)
	holder.Size = UDim2.fromOffset(px, px)
	holder:SetAttribute("Piece", e.piece)
	holder.Parent = art
	PieceIcon.piece(holder, e.piece, px)
	-- (A hairline of gold along its foot, where it meets the words.)
	local foot = Instance.new("Frame")
	foot.Name = "Foot"
	foot.BorderSizePixel = 0
	foot.BackgroundColor3 = C.lightGold
	foot.BackgroundTransparency = 0.45
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.fromScale(0, 1)
	foot.Size = UDim2.new(1, 0, 0, 1)
	foot.Parent = art
	if not still() then
		local t = math.random() * 6
		table.insert(spinning, RunService.RenderStepped:Connect(function(dt: number)
			t += dt
			holder.Position = UDim2.new(0.5, 0, 0.52, math.sin(t * 1.3) * 3)
			holder.Rotation = math.sin(t * 0.8) * 4
		end))
	end
	return art
end

-- A small rounded chip of words on a picture (OPEN, LOCKED, YOU'RE HERE).
local function chip(parent: Instance, text: string, fg: Color3, bg: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = "Chip"
	l.AnchorPoint = Vector2.new(1, 0)
	l.Position = UDim2.new(1, -10, 0, 10)
	l.Size = UDim2.fromOffset(0, 22)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.BackgroundColor3 = bg
	l.BackgroundTransparency = 0.12
	l.FontFace = Brand.Fonts.bodyBold
	l.TextSize = 11
	l.TextColor3 = fg
	l.Text = Caps(text)
	l.ZIndex = 4
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = l
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 9)
	pad.PaddingRight = UDim.new(0, 9)
	pad.Parent = l
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = fg
	st.Transparency = 0.5
	st.Parent = l
	l.Parent = parent
	return l
end

-- The lock over a picture that's closed to the guest.
local function lock(art: Frame)
	local veil = Instance.new("Frame")
	veil.Name = "Lock"
	veil.BorderSizePixel = 0
	veil.BackgroundColor3 = rgb(8, 8, 10)
	veil.BackgroundTransparency = 0.38
	veil.Size = UDim2.fromScale(1, 1)
	veil.ZIndex = 3
	veil.Parent = art
	local g = Instance.new("TextLabel")
	g.Name = "Padlock"
	g.BackgroundTransparency = 1
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = UDim2.fromScale(0.5, 0.52)
	g.Size = UDim2.fromOffset(40, 40)
	g.Text = "🔒"
	g.TextSize = 26
	g.TextColor3 = C.lightGold
	g.ZIndex = 4
	g.Parent = veil
end

-- The state chip a card's picture wears.
local function stateChip(art: Frame, e: Directory.Entry)
	local open = isOpen(e)
	local s = status
	local inside = player:GetAttribute(AttractionList.ATTRIBUTE)
	if e.attraction and inside == e.attraction then
		chip(art, "You're in it", GOLD, rgb(24, 20, 10))
	elseif e.attraction and s and s.here == e.attraction and open == true then
		chip(art, "You're here", GOLD, rgb(24, 20, 10))
	elseif open == false then
		chip(art, "Locked", C.bone, rgb(16, 16, 20))
		lock(art)
	elseif open == true then
		chip(art, "Open", rgb(170, 240, 190), rgb(10, 26, 16))
	end
end

---------------------------------------------------------------------------------------------------
-- The cards
---------------------------------------------------------------------------------------------------
local function setLift(button: GuiButton, scale: UIScale, stroke: UIStroke, e: Directory.Entry, how: string)
	local on = selected == e.id
	local goal = if how == "over" then 1.025 elseif how == "down" then 0.975 else 1
	Ease.play(scale, Ease.quick, { Scale = goal })
	stroke.Thickness = if on then 2 elseif how == "over" then 1.75 else 1.25
	stroke.Color = if on then GOLD else e.accent:Lerp(Color3.new(1, 1, 1), if how == "over" then 0.35 else 0.1)
	stroke.Transparency = if on or how == "over" then 0.05 else 0.45
	button:SetAttribute("Look", if on then "selected" else how)
end

-- A card's shape: its picture on top ("tall"), or at its left on a short screen ("wide").
export type Shape = { wide: boolean, w: number, h: number, art: number, px: number }

local function card(parent: Instance, e: Directory.Entry, order: number, shape: Shape, open: (id: string) -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Card_" .. e.id
	b.Text = ""
	b.AutoButtonColor = false
	b.Selectable = true
	b.LayoutOrder = order
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b:SetAttribute("Destination", e.id)
	b:SetAttribute("Shape", if shape.wide then "wide" else "tall")
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(30, 26, 22)),
		ColorSequenceKeypoint.new(1, rgb(14, 13, 16)),
	})
	bg.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Thickness = 1.25
	stroke.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.Parent = parent

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = b

	local function draw()
		for _, c in body:GetChildren() do
			c:Destroy()
		end
		local openNow = isOpen(e)
		local holder: Frame = body
		local wordsLeft, wordsTop = 14, shape.art + 8
		if shape.wide then
			-- (The picture down the card's left side, as tall as the card.)
			local side = Instance.new("Frame")
			side.Name = "Side"
			side.BackgroundTransparency = 1
			side.Size = UDim2.new(0, shape.art, 1, 0)
			side.Parent = body
			holder = side
			wordsLeft, wordsTop = shape.art + 12, 10
		end
		local art = picture(holder, e, if shape.wide then shape.h else shape.art, shape.px, 14)
		if shape.wide then
			art.Size = UDim2.fromScale(1, 1)
		end
		stateChip(art, e)
		-- (Every height and width here is the words' own, at the size they're really set: larger on
		-- a phone, where small words are raised to be read at a glance.)
		local room = shape.w - wordsLeft - 12
		local nameH = math.ceil(Theme.textSize(18, "display") * 1.25)
		local footLine = math.ceil(Theme.textSize(12, "bodyMedium") * 1.25)
		local moreLine = math.ceil(Theme.textSize(11, "caps") * 1.25)
		local moreW = Theme.measureAs("Closer look  ›", 11, "caps").X + 6
		local footH = if shape.wide or room - moreW < 90 then footLine + moreLine else math.max(footLine, moreLine)
		local words = Instance.new("Frame")
		words.Name = "Words"
		words.BackgroundTransparency = 1
		words.Position = UDim2.fromOffset(wordsLeft, wordsTop)
		words.Size = UDim2.new(1, -(wordsLeft + 12), 0, math.max(0, shape.h - wordsTop - 8 - footH - 4))
		words.ClipsDescendants = true
		words.Parent = body
		local list = Theme.list(words, 2)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Left
		list.VerticalAlignment = Enum.VerticalAlignment.Top
		-- (Its name on one line at the largest size that fits the card: never cut off.)
		local nameSize = 18
		while nameSize > 13 and Theme.measureAs(e.name, nameSize, "display").X > room do
			nameSize -= 1
		end
		local title = Theme.text(words, e.name, nameSize, "display", {
			Name = "Title",
			LayoutOrder = 1,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.bone,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(1, 0, 0, nameH),
			TextWrapped = false,
		})
		Theme.fit(title, nameSize, 12)
		-- (Closed to the guest: what opens it, in place of what it is.)
		local locked = openNow == false and e.unlock ~= nil
		local lineRoom = math.max(0, shape.h - wordsTop - 8 - footH - 4 - nameH - 2)
		local oneLine = math.ceil(Theme.textSize(13, "body") * 1.25)
		local line = if locked then (progress(e) or "Locked") elseif Theme.measureAs(e.tagline, 13, "body", room).Y <= lineRoom then e.tagline else e.short
		-- (Two lines kept for it wherever the card has them, so a word is never lost to a font that
		-- runs a little wider than measured.)
		local lineH = if locked then oneLine else math.min(lineRoom, math.max(oneLine * 2, Theme.measureAs(line, 13, "body", room).Y + 2))
		Theme.text(words, line, 13, "body", {
			Name = "Line",
			LayoutOrder = 2,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = if locked then C.lightGold else C.smoke,
			TextWrapped = true,
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(1, 0, 0, math.max(oneLine, lineH)),
		})
		if locked then
			-- (Closed: what opens it, in a few words more, where there's room for them.)
			local hint = if e.id == "executive" then "Clear the Basement, bank a great haul, or buy one from the Quartermaster." elseif e.id == "island" then fill("Reach {keyRank}, then buy the key at the Jet Lounge.") else nil
			local hintRoom = lineRoom - oneLine - 2
			if hint and Theme.measureAs(hint, 12, "body", room).Y <= hintRoom then
				Theme.text(words, hint, 12, "body", {
					Name = "Hint",
					LayoutOrder = 3,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					TextColor3 = C.smoke,
					TextWrapped = true,
					AutomaticSize = Enum.AutomaticSize.None,
					Size = UDim2.new(1, 0, 0, hintRoom),
				})
			end
		end
		-- (Its foot: how far you've come, and the way to a closer look.)
		local done = if locked then nil else progress(e)
		local foot = Instance.new("Frame")
		foot.Name = "Foot"
		foot.BackgroundTransparency = 1
		foot.AnchorPoint = Vector2.new(0, 1)
		foot.Position = UDim2.new(0, wordsLeft, 1, -8)
		foot.Size = UDim2.new(1, -(wordsLeft + 12), 0, footH)
		foot.Parent = body
		local stacked = footH > math.max(footLine, moreLine)
		Theme.text(foot, done or "", 12, "bodyMedium", {
			Name = "Progress",
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = e.accent:Lerp(Color3.new(1, 1, 1), 0.35),
			AutomaticSize = Enum.AutomaticSize.None,
			Size = if stacked then UDim2.new(1, 0, 0, footLine) else UDim2.new(1, -(moreW + 6), 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		})
		Theme.text(foot, "Closer look  ›", 11, "caps", {
			Name = "More",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.new(0, moreW, 0, moreLine),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
			TextColor3 = GOLD,
		})
		setLift(b, scale, stroke, e, "rest")
	end
	draw()
	redraws[e.id] = draw

	local over = false
	b.MouseEnter:Connect(function()
		if not over then
			over = true
			Theme.playHover()
		end
		setLift(b, scale, stroke, e, "over")
	end)
	b.MouseLeave:Connect(function()
		over = false
		setLift(b, scale, stroke, e, "rest")
	end)
	b.SelectionGained:Connect(function()
		setLift(b, scale, stroke, e, "over")
	end)
	b.SelectionLost:Connect(function()
		setLift(b, scale, stroke, e, "rest")
	end)
	b.MouseButton1Down:Connect(function()
		setLift(b, scale, stroke, e, "down")
	end)
	b.MouseButton1Up:Connect(function()
		setLift(b, scale, stroke, e, if over then "over" else "rest")
	end)
	b.Activated:Connect(function()
		Theme.playClick()
		Theme.haptic()
		selected = e.id
		open(e.id)
	end)
	return b
end

local function stopSpinning()
	for _, c in spinning do
		c:Disconnect()
	end
	table.clear(spinning)
end

---------------------------------------------------------------------------------------------------
-- A closer look
---------------------------------------------------------------------------------------------------
local function heading(parent: Instance, text: string, order: number, colour: Color3?)
	Theme.text(parent, text, 11, "caps", { LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = colour })
end

local function paragraph(parent: Instance, text: string, order: number, colour: Color3?)
	Theme.text(parent, text, 14, "body", {
		LayoutOrder = order,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = colour or C.smoke,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	})
end

-- One of its three steps: the number in a ring of its colour, and the line.
local function step(parent: Instance, n: number, text: string, accent: Color3, order: number)
	local row = Instance.new("Frame")
	row.Name = "Step" .. n
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Size = UDim2.new(1, 0, 0, 0)
	row.LayoutOrder = order
	row.Parent = parent
	local ring = Instance.new("TextLabel")
	ring.Name = "Number"
	ring.Size = UDim2.fromOffset(26, 26)
	ring.BackgroundColor3 = rgb(20, 18, 16)
	ring.FontFace = Brand.Fonts.figures
	ring.TextSize = 14
	ring.TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.3)
	ring.Text = tostring(n)
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rs.Color = accent
	rs.Transparency = 0.25
	rs.Thickness = 1.25
	rs.Parent = ring
	ring.Parent = row
	Theme.text(row, text, 14, "body", {
		Name = "Line",
		Position = UDim2.fromOffset(38, 3),
		Size = UDim2.new(1, -38, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.bone,
	})
end

-- A key that can't be used just now: dimmed, and pressing it does nothing.
local function dim(key: TextButton)
	key.Active = false
	key.AutoButtonColor = false
	key:SetAttribute("Disabled", true)
	key.TextTransparency = 0.5
	local stroke = key:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0.75
	end
end

function DirectoryPanel.closer(id: string)
	local e = Directory.byId[id]
	if not e then
		return
	end
	if Root.isOpen(CARD) then
		Root.close(CARD)
	end
	selected = id
	-- (Two columns where the screen is wide, a phone on its side too, so it's never too tall for
	-- it; one beside the dock on a tablet.)
	local sx = Root.size().X
	local w = math.min(if sx >= 900 then 860 else 580, sx - 24)
	local inner = w - 48
	local twoCols = inner >= 700
	local colW = if twoCols then math.floor((inner - 20) / 2) else inner
	local group, content = Theme.glass(Root.panels, CARD, UDim2.fromOffset(w, 600), nil, nil, e.mood)
	group:SetAttribute("Destination", id)
	group:SetAttribute("Columns", if twoCols then 2 else 1)
	local outer = Theme.list(content, 10)
	outer.VerticalAlignment = Enum.VerticalAlignment.Top

	-- Its head: the picture, and beside it the room, the name and the line.
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 104)
	head.LayoutOrder = 1
	head.Parent = content
	local artBox = Instance.new("Frame")
	artBox.Name = "ArtBox"
	artBox.BackgroundTransparency = 1
	artBox.Size = UDim2.fromOffset(104, 104)
	artBox.Parent = head
	local mark = #spinning
	local art = picture(artBox, e, 104, 64, 12)
	local open = isOpen(e)
	if open == false then
		lock(art)
	end
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(120, 0)
	words.Size = UDim2.new(1, -(120 + 48), 1, 0)
	words.Parent = head
	local wl = Theme.list(words, 3)
	wl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	wl.VerticalAlignment = Enum.VerticalAlignment.Center
	Theme.text(words, "Its way in: " .. e.room, 11, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = e.accent:Lerp(Color3.new(1, 1, 1), 0.3) })
	local title = Theme.text(words, e.name, 24, "display", {
		Name = "Title",
		LayoutOrder = 2,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 30),
		TextWrapped = false,
	})
	Theme.fit(title, 24, 16)
	Theme.text(words, e.tagline, 13, "body", {
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = C.smoke,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	})
	-- (The ✕ in its corner, big enough for a thumb.)
	local x = Instance.new("TextButton")
	x.Name = "CloseX"
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, 0, 0, -6)
	x.Size = UDim2.fromOffset(44, 44)
	x.BackgroundTransparency = 1
	x.Text = "✕"
	x.TextSize = 20
	x.TextColor3 = C.lightGold
	x.FontFace = Brand.Fonts.bodyBold
	x.Parent = head
	x.Activated:Connect(function()
		Theme.playClick()
		Root.close(CARD)
	end)

	-- Its words: how it plays on the left, what opens it and what it pays on the right (or all in
	-- one column, one after the other).
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Size = UDim2.new(1, 0, 0, 0)
	body.LayoutOrder = 2
	body.Parent = content
	local bl = Theme.list(body, if twoCols then 20 else 10, twoCols)
	bl.VerticalAlignment = Enum.VerticalAlignment.Top
	bl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local function column(name: string, order: number): Frame
		local col = Instance.new("Frame")
		col.Name = name
		col.BackgroundTransparency = 1
		col.AutomaticSize = Enum.AutomaticSize.Y
		col.Size = UDim2.new(0, colW, 0, 0)
		col.LayoutOrder = order
		col.Parent = body
		Theme.list(col, 8).HorizontalAlignment = Enum.HorizontalAlignment.Left
		return col
	end
	local left = column("Plays", if twoCols then 1 else 2)
	local right = column("Pays", if twoCols then 2 else 3)
	local c = cardOf(e)
	if open == false and e.unlock then
		-- What opens it, first, in a box of its own (in one column, before how it plays).
		local box = Instance.new("Frame")
		box.Name = "Unlock"
		box.BackgroundColor3 = rgb(16, 14, 12)
		box.BackgroundTransparency = 0.2
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.Size = UDim2.new(1, 0, 0, 0)
		box.LayoutOrder = 1
		box.Parent = if twoCols then right else column("Opens", 1)
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 10)
		bc.Parent = box
		local bs = Instance.new("UIStroke")
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Color = GOLD
		bs.Transparency = 0.45
		bs.Parent = box
		local bp = Instance.new("UIPadding")
		bp.PaddingTop = UDim.new(0, 10)
		bp.PaddingBottom = UDim.new(0, 10)
		bp.PaddingLeft = UDim.new(0, 12)
		bp.PaddingRight = UDim.new(0, 12)
		bp.Parent = box
		Theme.list(box, 4).HorizontalAlignment = Enum.HorizontalAlignment.Left
		heading(box, "🔒  How to open it", 1, GOLD)
		paragraph(box, fill(e.unlock), 2, C.bone)
		if e.id == "island" and c and c.rankReady == true then
			paragraph(box, "You've reached the rank. The key is at the Jet Lounge's desk, its price shown before you pay.", 3, C.lightGold)
		elseif e.id == "executive" and c and c.sidearm ~= true then
			paragraph(box, "Your sidearm is free from the Quartermaster, in the Anteroom.", 3, C.lightGold)
		end
	end
	heading(left, "How it plays", 1)
	for n, s in e.steps do
		step(left, n, fill(s), e.accent, 1 + n)
	end
	heading(right, "What it pays", 10)
	paragraph(right, fill(e.rewards), 11)
	local done = progress(e)
	if done and open ~= false then
		heading(right, "You so far", 20)
		paragraph(right, done, 21, e.accent:Lerp(Color3.new(1, 1, 1), 0.35))
	end

	-- The ways there.
	local why = blocked(e)
	local s = status
	local here = e.attraction ~= nil and s ~= nil and s.here == e.attraction and open == true
	local note = Theme.text(content, why or "", 13, "bodyMedium", {
		Name = "Note",
		LayoutOrder = 3,
		TextColor3 = C.lightGold,
		TextWrapped = true,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
	})
	note.Visible = why ~= nil
	-- (One row of three keys where they fit, else the two ways there over Back.)
	local three = inner >= 3 * 150 + 16
	local kw = if three then math.min(240, math.floor((inner - 16) / 3)) else math.floor((inner - 8) / 2)
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 4
	keys.Parent = content
	Theme.list(keys, 8).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 44)
	row.LayoutOrder = 1
	row.Parent = keys
	Theme.list(row, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function leaveThen(fn: () -> ()): () -> ()
		return function()
			if blocked(e) then
				return
			end
			Root.close(CARD)
			Root.close(NAME)
			fn()
		end
	end
	local first: TextButton
	if here then
		first = Theme.key(row, "Go in", true, leaveThen(function()
			DirectoryPanel.enter(e.attraction :: string)
		end), kw)
	else
		first = Theme.key(row, "Take me there", true, leaveThen(function()
			DirectoryPanel.go(e.place)
		end), kw)
	end
	first.Name = "Key_Go"
	first.LayoutOrder = 1
	local walk = Theme.key(row, "Walk me there", false, leaveThen(function()
		DirectoryPanel.walk(e.place)
	end), kw)
	walk.Name = "Key_Walk"
	walk.LayoutOrder = 2
	if why then
		dim(first)
		dim(walk)
	end
	local back = Theme.key(if three then row else keys, "Back", false, function()
		Root.close(CARD)
	end, if three then kw else inner)
	back.Name = "Key_Back"
	back.LayoutOrder = 3
	Theme.fitHeight(group, content)
	Root.open(CARD, group, function()
		-- (Its treasure stops turning; back to the cards, the one just looked at gold-edged.)
		for i = #spinning, mark + 1, -1 do
			spinning[i]:Disconnect()
			table.remove(spinning, i)
		end
		for _, redraw in redraws do
			redraw()
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The Directory
---------------------------------------------------------------------------------------------------
function DirectoryPanel.open()
	if Root.isOpen(NAME) then
		Root.close(NAME)
		return
	end
	stopSpinning()
	table.clear(redraws)
	local size = Root.size()
	-- (The whole width there is, up to a point: the house's own selection screen, over the dock.)
	local w = math.min(1000, size.X - 24)
	local inner = w - 48
	local gap = 12
	-- The cards take the room there is: their pictures beside their words (on top, where the
	-- screen is tall enough for both rows that way); as many across as leave every name room on
	-- one line at the size it's really set (three on a computer, two on a phone or a tablet).
	local avail = size.Y - 66 - 12
	local headH = 82
	local glyph, eventName, eventLine = happening()
	if eventName then
		headH += 34
	end
	local roomForCards = avail - 44 - headH - 10 - 6
	local nameNeed = 0
	for _, e in Directory.List do
		nameNeed = math.max(nameNeed, Theme.measureAs(e.name, 16, "display").X)
	end
	-- (The least a card needs: its name, two lines, and its foot.)
	local least = 10 + math.ceil(Theme.textSize(18, "display") * 1.25) + 2 + math.ceil(Theme.textSize(13, "body") * 1.2) * 2 + 6 + math.ceil(Theme.textSize(12, "bodyMedium") * 1.25) + math.ceil(Theme.textSize(11, "caps") * 1.25) + 8
	local cols, cardW, artW = 1, inner - 6, 132
	for c = 3, 1, -1 do
		local cw = math.floor((inner - 6 - gap * (c - 1)) / c)
		local aw = math.clamp(math.floor(cw * 0.28), 84, 132)
		if cw - aw - 24 >= nameNeed or c == 1 then
			cols, cardW, artW = c, cw, aw
			break
		end
	end
	local rows = math.ceil(#Directory.List / cols)
	local each = math.floor((roomForCards - (rows - 1) * gap) / rows)
	-- (Short of room for every row at its least: the hint under the title goes, since every card
	-- says "Closer look" itself, and the rows have its height.)
	local hint = true
	if each < least then
		hint = false
		local hintH = math.ceil(Theme.textSize(13, "body") * 1.25) + 6
		headH -= hintH
		roomForCards += hintH
		each = math.floor((roomForCards - (rows - 1) * gap) / rows)
	end
	local shape: Shape
	if each - 106 >= 76 and cardW - 26 >= nameNeed then
		local h = math.min(236, each)
		shape = { wide = false, w = cardW, h = h, art = h - 106, px = math.clamp(h - 106 - 22, 48, 80) }
	else
		local h = math.clamp(each, least, 200)
		shape = { wide = true, w = cardW, h = h, art = artW, px = math.clamp(math.min(artW, h) - 26, 48, 84) }
	end
	local gridH = rows * shape.h + (rows - 1) * gap
	local h = 44 + headH + 10 + gridH + 6
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	local list = Theme.list(content, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Maison Directory", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Every game in the house", 26, "display", { LayoutOrder = 2 })
	if hint then
		local sub = Theme.text(content, "Tap a card for a closer look, and the way there.", 13, "body", { LayoutOrder = 3, TextColor3 = C.smoke })
		sub.Name = "Hint"
	end
	if eventName then
		-- What's on in the house tonight (the attractions are dressed for a holiday, too).
		local ribbon = Instance.new("Frame")
		ribbon.Name = "Tonight"
		ribbon.BackgroundColor3 = rgb(28, 22, 12)
		ribbon.BackgroundTransparency = 0.15
		ribbon.Size = UDim2.new(1, 0, 0, 28)
		ribbon.LayoutOrder = 4
		ribbon.Parent = content
		local rc = Instance.new("UICorner")
		rc.CornerRadius = UDim.new(0, 8)
		rc.Parent = ribbon
		local rs = Instance.new("UIStroke")
		rs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		rs.Color = GOLD
		rs.Transparency = 0.55
		rs.Parent = ribbon
		local words = Theme.text(ribbon, string.format("%s  %s, on now: %s", glyph or "✨", eventName, eventLine or ""), 13, "bodyMedium", {
			Name = "Words",
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 1, 0),
			AutomaticSize = Enum.AutomaticSize.None,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = C.lightGold,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
		})
		Theme.fit(words, 13, 11)
	end
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Cards"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.LayoutOrder = 5
	grid.ScrollBarThickness = 3
	grid.ScrollBarImageColor3 = C.gold
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Size = UDim2.new(1, 0, 0, math.max(120, math.min(gridH + 6, group.Size.Y.Offset - 44 - headH - 10)))
	grid.ClipsDescendants = true
	grid.Parent = content
	-- (Room round each card for it to lift when pointed at.)
	local gp = Instance.new("UIPadding")
	gp.PaddingTop = UDim.new(0, 3)
	gp.PaddingBottom = UDim.new(0, 3)
	gp.PaddingLeft = UDim.new(0, 3)
	gp.PaddingRight = UDim.new(0, 3)
	gp.Parent = grid
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(gap, gap)
	layout.CellSize = UDim2.fromOffset(cardW, shape.h)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, e in Directory.List do
		card(grid, e, i, shape, DirectoryPanel.closer)
	end
	Root.open(NAME, group, function()
		stopSpinning()
		table.clear(redraws)
		if Root.isOpen(CARD) then
			Root.close(CARD)
		end
	end)
	-- The server's word on each card: open or not, its figures, how far you've come.
	task.spawn(function()
		local r = ask({ op = "directory" })
		if r and r.ok == true then
			status = r
		end
		if Root.isOpen(NAME) then
			for _, redraw in redraws do
				redraw()
			end
		end
	end)
end

function DirectoryPanel.isOpen(): boolean
	return Root.isOpen(NAME) or Root.isOpen(CARD)
end

-- For tests.
function DirectoryPanel.status(): { [string]: any }?
	return status
end

return DirectoryPanel

--!strict
-- The Friend Booster, in the bottom-right corner. Friends on Roblox in the house together both earn
-- more Gilt (+25% with one friend here, +10% more for each further friend, up to +55%) and more XP;
-- the server counts them and pays it (server/Friends), and tells this screen alone who's here.
--   The card: FRIEND BOOSTER and a live light, the boost in big gold figures (and the XP), the
--   faces of the friends here (AJKR's crest for the owner, never their avatar), the four steps of
--   the boost with this one lit, what one more friend would bring, and a key to invite a friend
--   (Roblox's own invite; a friend's first visit is thanked in Gilt too).
--   With nobody here it's a small invitation. Either way it folds to a slim pill after a few
--   seconds (tap it to open it again), and opens by itself, lit up, when a friend arrives.
-- It steps aside while the guest sorts at a table, has a panel open, is in photo mode or on the
-- title, and while the Concierge is speaking on a narrow screen. On a touch screen it sits above
-- Roblox's jump button.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Dialogue = require(script.Parent.Dialogue)
local Invite = require(script.Parent.Invite)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local OwnerCameo = require(script.Parent.Parent.World.OwnerCameo)

local FriendBooster = {}

-- Set by Main: whether something else has the screen (the title, photo mode).
FriendBooster.isBusy = function(): boolean
	return false
end

type Friend = { userId: number, name: string, owner: boolean }

local C = Brand.Colours
local rgb = Color3.fromRGB
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local W = 284 -- the card's width
local OPEN_SECONDS = 10 -- open this long, then it folds to the pill
local FACE = 30
local SHOWN = 4 -- faces shown (then "+2")

local friends: { Friend } = {}
local boost = 1
local xpBoost = 1
local started = false
local seated = false
local open = true
local openToken = 0
local holder: Frame? = nil
local card: Frame? = nil
local pill: TextButton? = nil
local lastCount = 0

local function cfg(): { [string]: any }
	return Config.data.Friends
end

-- The boost for `n` friends here (the server's own rule, for the steps and "one more friend").
local function boostFor(n: number): number
	local c = cfg()
	if n <= 0 then
		return 1
	end
	return math.min(c.maxBoost, c.giltBoost + c.perFriend * (n - 1))
end

local function percent(b: number): string
	return string.format("+%d%%", math.floor((b - 1) * 100 + 0.5))
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal):Play()
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, name: string, text: string, font: Font, size: number, colour: Color3, props: { [string]: any }?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	if props then
		for k, v in props do
			(l :: any)[k] = v
		end
	end
	l.Parent = parent
	return l
end

local function frame(parent: Instance, name: string, colour: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency
	f.Parent = parent
	return f
end

-- Gold metal, bright to deep, on text or a fill.
local function metal(target: GuiObject)
	local g = Instance.new("UIGradient")
	g.Name = "Metal"
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 250, 228)),
		ColorSequenceKeypoint.new(0.5, C.brightGold),
		ColorSequenceKeypoint.new(1, C.gold),
	})
	g.Parent = target
end

-- A friend's face in a gold ring (AJKR's crest for the owner).
local function face(parent: Instance, f: Friend, size: number, order: number): Frame
	local ring = frame(parent, "Face" .. order, C.nearBlack, 0)
	ring.LayoutOrder = order
	ring.Size = UDim2.fromOffset(size, size)
	ring.ZIndex = 20 - order
	corner(ring, size)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = C.brightGold
	edge.Thickness = 1.5
	edge.Parent = ring
	if f.owner then
		local crest = OwnerCameo.crest(ring)
		crest.ZIndex = ring.ZIndex
	else
		local image = Instance.new("ImageLabel")
		image.Name = "Headshot"
		image.BackgroundColor3 = rgb(36, 34, 40)
		image.BackgroundTransparency = 0
		image.Size = UDim2.fromScale(1, 1)
		image.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", f.userId)
		image.ZIndex = ring.ZIndex
		corner(image, size)
		image.Parent = ring
	end
	return ring
end

-- Where it sits: the bottom-right corner, above Roblox's jump button on a touch screen.
local function place()
	local h = holder
	if not h then
		return
	end
	local camera = Workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local up = 18
	if State.inputKind() == "touch" then
		up = if math.min(vp.X, vp.Y) < 500 then 112 else 232
	end
	h.Position = UDim2.new(1, -16, 1, -up)
end

local function narrow(): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and camera.ViewportSize.X < 1100
end

-- Whether it shows: walking the house, nothing else on the screen in its way.
function FriendBooster.visible(): boolean
	return started and not seated and not Root.isOpen() and not FriendBooster.isBusy() and not (Dialogue.isOpen() and narrow())
end

local function refreshVisible()
	local h = holder
	if h then
		h.Visible = FriendBooster.visible()
	end
end

function FriendBooster.setSeated(on: boolean)
	seated = on
	refreshVisible()
end

---------------------------------------------------------------------------------------------------
-- The card and the pill
---------------------------------------------------------------------------------------------------

local function steps(parent: Instance, y: number, n: number)
	local row = frame(parent, "Steps", Color3.new(0, 0, 0), 1)
	row.Position = UDim2.fromOffset(0, y)
	row.Size = UDim2.new(1, 0, 0, 24)
	local gap = 5
	for i = 1, 4 do
		local lit = n >= i
		local here = n == i or (i == 4 and n > 4)
		local seg = frame(row, "Step" .. i, if lit then Color3.new(1, 1, 1) else rgb(46, 46, 54), 0)
		seg.Position = UDim2.new((i - 1) / 4, if i == 1 then 0 else gap / 2, 0, 0)
		seg.Size = UDim2.new(0.25, -gap + (if i == 1 or i == 4 then gap / 2 else 0), 0, 5)
		corner(seg, 3)
		if lit then
			metal(seg)
		end
		local tag = label(row, "Tag" .. i, percent(boostFor(i)), Brand.Fonts.bodyBold, 10, if here then C.brightGold elseif lit then C.lightGold else C.dim, {
			Position = UDim2.new((i - 1) / 4, 0, 0, 9),
			Size = UDim2.new(0.25, 0, 0, 12),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		tag.TextTransparency = if lit or n == 0 then 0 else 0.25
	end
	return row
end

local function nextLine(n: number): string
	if n <= 0 then
		return string.format("Bring a friend: you both get %s Gilt", percent(boostFor(1)))
	end
	if boostFor(n + 1) > boostFor(n) + 1e-6 then
		return string.format("One more friend here: %s for you", percent(boostFor(n + 1)))
	end
	return "The biggest boost there is. Enjoy it together."
end

-- Draws the card for what's known now (the friends here, the boost).
local function drawCard(arrived: Friend?)
	local h = holder
	if not h then
		return
	end
	local old = h:FindFirstChild("Card")
	if old then
		old:Destroy()
	end
	local n = #friends
	local height = if n > 0 then 228 else 184
	local c = frame(h, "Card", Color3.new(0, 0, 0), 1)
	c.AnchorPoint = Vector2.new(1, 1)
	c.Position = UDim2.fromScale(1, 1)
	c.Size = UDim2.fromOffset(W, height)
	card = c
	Theme.glow(c, C.glow, 18, if n > 0 then 1 else 0.6)
	local fill = frame(c, "Fill", C.nearBlack, 0.04)
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = 2
	corner(fill, 18)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = C.gold
	edge.Thickness = 1.2
	edge.Transparency = 0.1
	edge.Parent = fill
	Theme.edge(edge, 0.8)
	-- (A breath of gold through the glass from its top.)
	local warm = Instance.new("UIGradient")
	warm.Rotation = 90
	warm.Color = ColorSequence.new(rgb(46, 36, 18), C.nearBlack)
	warm.Parent = fill
	local body = frame(fill, "Body", Color3.new(0, 0, 0), 1)
	body.Position = UDim2.fromOffset(16, 14)
	body.Size = UDim2.new(1, -32, 1, -28)
	-- FRIEND BOOSTER, and a live light while it's on.
	local mark = frame(body, "Mark", C.brightGold, 0)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromOffset(4, 8)
	mark.Size = UDim2.fromOffset(7, 7)
	mark.Rotation = 45
	label(body, "Title", "FRIEND BOOSTER", Brand.Fonts.display, 12, C.lightGold, {
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -96, 0, 16),
	})
	if n > 0 then
		local live = frame(body, "Live", rgb(24, 46, 30), 0)
		live.AnchorPoint = Vector2.new(1, 0)
		live.Position = UDim2.new(1, 0, 0, -1)
		live.Size = UDim2.fromOffset(70, 18)
		corner(live, 9)
		local liveEdge = Instance.new("UIStroke")
		liveEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		liveEdge.Color = rgb(120, 230, 150)
		liveEdge.Transparency = 0.45
		liveEdge.Parent = live
		local dot = frame(live, "Dot", rgb(130, 255, 160), 0)
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 9, 0.5, 0)
		dot.Size = UDim2.fromOffset(6, 6)
		corner(dot, 3)
		label(live, "Word", "ACTIVE", Brand.Fonts.bodyBold, 10, rgb(170, 255, 190), {
			Position = UDim2.fromOffset(20, 0),
			Size = UDim2.new(1, -24, 1, 0),
		})
		-- (The light breathes.)
		task.spawn(function()
			while dot.Parent do
				tween(dot, 0.7, { BackgroundTransparency = 0.6 }, Enum.EasingStyle.Sine)
				task.wait(0.75)
				tween(dot, 0.7, { BackgroundTransparency = 0 }, Enum.EasingStyle.Sine)
				task.wait(0.75)
			end
		end)
	end
	if n > 0 then
		-- The boost, in big gold figures, and the XP beside it.
		local big = label(body, "Boost", percent(boost), HEAVY, 36, Color3.new(1, 1, 1), {
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.fromOffset(112, 40),
		})
		metal(big)
		label(body, "Gilt", "GILT", Brand.Fonts.display, 13, C.bone, {
			Position = UDim2.fromOffset(112, 40),
			Size = UDim2.fromOffset(60, 16),
		})
		local xpCap = frame(body, "XP", rgb(30, 26, 44), 0)
		xpCap.AnchorPoint = Vector2.new(1, 0)
		xpCap.Position = UDim2.new(1, 0, 0, 34)
		xpCap.Size = UDim2.fromOffset(74, 22)
		corner(xpCap, 11)
		local xpEdge = Instance.new("UIStroke")
		xpEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		xpEdge.Color = rgb(180, 150, 255)
		xpEdge.Transparency = 0.4
		xpEdge.Parent = xpCap
		label(xpCap, "Word", percent(xpBoost) .. " XP", Brand.Fonts.bodyBold, 12, rgb(214, 198, 255), {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		-- Their faces, overlapping a little, and how many.
		local faces = frame(body, "Faces", Color3.new(0, 0, 0), 1)
		faces.Position = UDim2.fromOffset(0, 72)
		faces.Size = UDim2.new(1, 0, 0, FACE)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.Padding = UDim.new(0, -7)
		list.Parent = faces
		local shown = math.min(n, SHOWN)
		for i = 1, shown do
			local f = friends[i]
			local ring = face(faces, f, FACE, i)
			if arrived and f.userId == arrived.userId then
				local pop = Instance.new("UIScale")
				pop.Scale = 0.2
				pop.Parent = ring
				tween(pop, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
		local more = n - shown
		local facesWide = shown * FACE - (shown - 1) * 7
		if more > 0 then
			local extra = frame(faces, "More", rgb(40, 36, 30), 0)
			extra.LayoutOrder = SHOWN + 1
			extra.Size = UDim2.fromOffset(FACE, FACE)
			corner(extra, FACE)
			label(extra, "Count", "+" .. more, Brand.Fonts.bodyBold, 12, C.lightGold, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			facesWide += FACE - 7
		end
		local who = if n == 1 then friends[1].name .. " is here" else string.format("%d friends here", n)
		label(body, "Who", who, Brand.Fonts.bodyBold, 13, C.bone, {
			Position = UDim2.fromOffset(facesWide + 10, 72),
			Size = UDim2.new(1, -(facesWide + 10), 0, FACE),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		steps(body, 112, n)
		label(body, "Next", if arrived then string.format("%s arrived: %s Gilt now", arrived.name, percent(boost)) else nextLine(n), Brand.Fonts.body, 12, if arrived then C.brightGold else C.smoke, {
			Position = UDim2.fromOffset(0, 140),
			Size = UDim2.new(1, 0, 0, 14),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
	else
		label(body, "Lead", "Play with a friend", Brand.Fonts.bodyBold, 15, C.bone, {
			Position = UDim2.fromOffset(0, 24),
			Size = UDim2.new(1, 0, 0, 18),
		})
		local offer = label(body, "Offer", string.format("%s GILT  ·  %s XP", percent(boostFor(1)), percent(cfg().xpBoost)), HEAVY, 18, Color3.new(1, 1, 1), {
			Position = UDim2.fromOffset(0, 44),
			Size = UDim2.new(1, 0, 0, 22),
		})
		metal(offer)
		label(body, "Both", "For you both, more with each friend", Brand.Fonts.body, 12, C.smoke, {
			Position = UDim2.fromOffset(0, 68),
			Size = UDim2.new(1, 0, 0, 14),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		steps(body, 92, 0)
	end
	local key = Theme.key(body, "Invite friends", true, function()
		Invite.house()
	end, W - 32)
	key.Name = "Invite"
	key.AnchorPoint = Vector2.new(0, 1)
	key.Position = UDim2.fromScale(0, 1)
	key.Size = UDim2.new(1, 0, 0, 36)
	-- A tap on the card's heading folds it now.
	local fold = Instance.new("TextButton")
	fold.Name = "Fold"
	fold.BackgroundTransparency = 1
	fold.Text = ""
	fold.Size = UDim2.new(1, 0, 0, 20)
	fold.Parent = body
	fold.Activated:Connect(function()
		FriendBooster.fold()
	end)
end

local function drawPill()
	local h = holder
	if not h then
		return
	end
	local old = h:FindFirstChild("Pill")
	if old then
		old:Destroy()
	end
	local n = #friends
	local shown = math.min(n, 3)
	local width = if n > 0 then 156 + shown * 16 else 214
	local p = Instance.new("TextButton")
	p.Name = "Pill"
	p.AutoButtonColor = false
	p.Text = ""
	p.AnchorPoint = Vector2.new(1, 1)
	p.Position = UDim2.fromScale(1, 1)
	p.Size = UDim2.fromOffset(width, 38)
	p.BackgroundColor3 = C.nearBlack
	p.BackgroundTransparency = 0.06
	p.BorderSizePixel = 0
	corner(p, 19)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = C.gold
	edge.Thickness = 1.2
	edge.Transparency = 0.15
	edge.Parent = p
	Theme.edge(edge, 0.8)
	local mark = frame(p, "Mark", C.brightGold, 0)
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.new(0, 18, 0.5, 0)
	mark.Size = UDim2.fromOffset(6, 6)
	mark.Rotation = 45
	if n > 0 then
		local big = label(p, "Boost", percent(boost) .. " GILT", HEAVY, 15, Color3.new(1, 1, 1), {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(0, 96, 1, 0),
		})
		metal(big)
		local faces = frame(p, "Faces", Color3.new(0, 0, 0), 1)
		faces.AnchorPoint = Vector2.new(1, 0.5)
		faces.Position = UDim2.new(1, -10, 0.5, 0)
		faces.Size = UDim2.fromOffset(shown * 22 - (shown - 1) * 6, 22)
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, -6)
		list.Parent = faces
		for i = 1, shown do
			face(faces, friends[i], 22, i)
		end
	else
		label(p, "Word", "FRIEND BOOSTER", Brand.Fonts.display, 10, C.lightGold, {
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(0, 120, 1, 0),
		})
		local offer = label(p, "Offer", percent(boostFor(1)), HEAVY, 15, Color3.new(1, 1, 1), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 0),
			Size = UDim2.new(0, 56, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		metal(offer)
	end
	p.Activated:Connect(function()
		FriendBooster.unfold()
	end)
	p.Parent = h
	pill = p
end

local function show()
	local c = card
	local p = pill
	if c then
		c.Visible = open
	end
	if p then
		p.Visible = not open
	end
end

-- Opens the card (for OPEN_SECONDS, then it folds to the pill again).
function FriendBooster.unfold(arrived: Friend?)
	open = true
	openToken += 1
	local mine = openToken
	drawCard(arrived)
	show()
	local c = card
	if c then
		local s = Instance.new("UIScale")
		s.Scale = if arrived then 0.9 else 0.96
		s.Parent = c
		tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	task.delay(OPEN_SECONDS, function()
		if openToken == mine and open then
			FriendBooster.fold()
		end
	end)
end

function FriendBooster.fold()
	open = false
	openToken += 1
	drawPill()
	show()
end

function FriendBooster.isOpen(): boolean
	return open
end

-- What the server says: the friends here and the boost.
function FriendBooster.set(list: { any }, gilt: number?, xp: number?)
	local was: { [number]: boolean } = {}
	for _, f in friends do
		was[f.userId] = true
	end
	local fresh: { Friend } = {}
	local arrived: Friend? = nil
	for _, f in list do
		if type(f) == "table" and type(f.userId) == "number" then
			local entry: Friend = { userId = f.userId, name = tostring(f.name or "A friend"), owner = f.owner == true }
			table.insert(fresh, entry)
			if not was[entry.userId] then
				arrived = entry
			end
		end
	end
	friends = fresh
	boost = if type(gilt) == "number" then gilt else boostFor(#fresh)
	xpBoost = if type(xp) == "number" then xp else (if #fresh > 0 then cfg().xpBoost else 1)
	local n = #fresh
	if not holder then
		lastCount = n
		return
	end
	-- (Both drawn afresh every time, so whichever is folded away is never out of date.)
	drawPill()
	if n > lastCount and arrived then
		-- A friend arrived: the card opens, lit, and says so.
		FriendBooster.unfold(arrived)
		pcall(Sound.play, "notify", 0.7, 1.25)
		task.delay(0.11, function()
			pcall(Sound.play, "notify", 0.7, 1.68)
		end)
	else
		drawCard(nil)
		show()
	end
	lastCount = n
end

function FriendBooster.count(): number
	return #friends
end

function FriendBooster.start()
	if started then
		return
	end
	started = true
	local h = Instance.new("Frame")
	h.Name = "FriendBooster"
	h.BackgroundTransparency = 1
	h.AnchorPoint = Vector2.new(1, 1)
	h.Size = UDim2.fromOffset(W, 40)
	h.Parent = Root.hud
	holder = h
	place()
	lastCount = #friends
	FriendBooster.unfold(nil)
	pcall(function()
		Remotes.event("Guest").OnClientEvent:Connect(function(m: any)
			if type(m) == "table" and m.op == "friends" and type(m.friends) == "table" then
				FriendBooster.set(m.friends, m.gilt, m.xp)
			end
		end)
	end)
	Root.PanelsChanged:Connect(refreshVisible)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
	end
	-- (The title, photo mode or the Concierge on a narrow screen come and go without a word: a
	-- look four times a second.)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			refreshVisible()
		end
	end)
	refreshVisible()
end

return FriendBooster

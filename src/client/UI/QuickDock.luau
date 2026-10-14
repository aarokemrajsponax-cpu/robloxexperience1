--!strict
-- The quick dock: six big keys down the left side of the screen, two by two, always one tap away
-- (and a key each on the keyboard): your Collection (C), Trade (T), your Wardrobe (V), Gems,
-- Suites (your own, or a friend's: friends on Roblox may visit each other's), and Invite (Roblox's
-- invite prompt, to bring a friend). Big enough to read at a glance on a phone.
-- Trade opens a short list of everyone in the house, each with a Trade key, and your past trades.
-- It steps aside while you sort at a table (looked at four times a second as well, so it's never
-- left over the cloth), and folds away for good with the ‹ key at its corner or Settings → Keys
-- down the left (a small KEYS › tab brings it back). On a phone its keys are smaller.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Names = require(ReplicatedStorage.Shared.Names)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Icons = require(script.Parent.Icons)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local QuickDock = {}

local C = Brand.Colours
local PICKER = "TradeWith"
local SUITES = "SuiteVisit"

-- Set by Main.
QuickDock.openCollection = function() end
QuickDock.openTrades = function() end
QuickDock.openWardrobe = function() end
QuickDock.openGems = function() end
QuickDock.inviteFriend = function() end
QuickDock.invite = function(_userId: number, _name: string) end
QuickDock.isSeated = function(): boolean
	return false
end
-- Set by Main: whether the guest is sorting (at a table, or the sorting screen is up).
QuickDock.isSorting = function(): boolean
	return false
end

local dock: Frame? = nil

-- The list of guests to trade with.
function QuickDock.openTrade()
	if Root.isOpen(PICKER) then
		Root.close(PICKER)
		return
	end
	local others = {}
	for _, p in Players:GetPlayers() do
		if p ~= Players.LocalPlayer then
			table.insert(others, p)
		end
	end
	local size = Root.size()
	local rows = math.max(1, #others)
	local group, content = Theme.glass(Root.panels, PICKER, UDim2.fromOffset(math.min(420, size.X - 24), math.min(170 + rows * 52, size.Y - 90)))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Trade", 24, "display", { LayoutOrder = 1 })
	if #others == 0 then
		Theme.text(content, "Nobody else is in the house just now. Invite a friend, then trade here.", 14, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })
	else
		Theme.text(content, "Choose a guest. They're asked first; nothing changes hands until you both confirm.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })
		for i, p in others do
			local k = Theme.key(content, Names.of(p), i == 1, function()
				Root.close(PICKER)
				QuickDock.invite(p.UserId, Names.of(p))
			end, 320)
			k.LayoutOrder = 2 + i
		end
	end
	local past = Theme.key(content, "Your trades", false, function()
		Root.close(PICKER)
		QuickDock.openTrades()
	end, 200)
	past.LayoutOrder = 100
	local close = Theme.key(content, "Close", false, function()
		Root.close(PICKER)
	end, 200)
	close.LayoutOrder = 101
	Root.open(PICKER, group)
end

-- Your Suite, or a friend's: friends in the house (the server knows who), each with a key.
local function askSuites(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("SuiteAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

function QuickDock.openSuites()
	if Root.isOpen(SUITES) then
		Root.close(SUITES)
		return
	end
	task.spawn(function()
		local r = askSuites({ op = "list" })
		local friends = if type(r) == "table" and type(r.friends) == "table" then r.friends else {}
		local visiting = if type(r) == "table" then r.visiting else nil
		local size = Root.size()
		local rows = #friends + 1
		local group, content = Theme.glass(Root.panels, SUITES, UDim2.fromOffset(math.min(420, size.X - 24), math.min(200 + rows * 52, size.Y - 90)))
		Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
		Theme.text(content, "Suites", 24, "display", { LayoutOrder = 1 })
		Theme.text(content, "Your own, private Suite, or a friend's: friends on Roblox may visit each other's.", 13, "body", { LayoutOrder = 2, TextColor3 = C.smoke, TextWrapped = true })
		local function go(request: { [string]: any })
			Root.close(SUITES)
			task.spawn(function()
				local res = askSuites(request)
				if type(res) == "table" and res.ok == false and res.why then
					QuickDock.say("Suites", tostring(res.why))
				end
			end)
		end
		local home = Theme.key(content, if visiting then "Back to my Suite" else "My Suite", true, function()
			go({ op = "home" })
		end, 320)
		home.Name = "MySuite"
		home.LayoutOrder = 3
		if #friends == 0 then
			Theme.text(content, "No friends in the house just now. Invite one with the Invite key, then visit each other's Suites.", 13, "body", { LayoutOrder = 4, TextColor3 = C.smoke, TextWrapped = true })
		end
		for i, f in friends do
			local k = Theme.key(content, tostring(f.name) .. "'s Suite" .. (if visiting == f.userId then "  ·  here" else ""), false, function()
				go({ op = "visit", userId = f.userId })
			end, 320)
			k.Name = "Visit_" .. tostring(f.userId)
			k.LayoutOrder = 4 + i
		end
		local close = Theme.key(content, "Close", false, function()
			Root.close(SUITES)
		end, 200)
		close.LayoutOrder = 100
		Root.open(SUITES, group)
	end)
end

-- A short word on screen (set by Main: a toast).
QuickDock.say = function(_title: string, _line: string) end

local SIZE = 64
-- Each key a little wider than it is tall, so the longest names (Collection, Wardrobe) sit whole
-- on the foot of the key at a size you can read.
local WIDE = 1.22
local function keyWidth(): number
	return math.floor(SIZE * WIDE + 0.5)
end
local KEYS = 6
local GAP = 10

local TweenService = game:GetService("TweenService")

-- Each key's own colour (light and deep), softened on the key (tintOf) so the dock reads at a glance.
local ACCENTS: { [string]: { Color3 } } = {
	Collection = { Color3.fromRGB(255, 196, 92), Color3.fromRGB(166, 104, 22) },
	Trade = { Color3.fromRGB(92, 232, 210), Color3.fromRGB(16, 120, 112) },
	Wardrobe = { Color3.fromRGB(196, 150, 255), Color3.fromRGB(92, 48, 170) },
	Gems = { Color3.fromRGB(110, 210, 255), Color3.fromRGB(26, 96, 196) },
	Suites = { Color3.fromRGB(255, 140, 178), Color3.fromRGB(170, 40, 92) },
	Invite = { Color3.fromRGB(140, 240, 140), Color3.fromRGB(30, 140, 64) },
	Watch = { Color3.fromRGB(255, 120, 220), Color3.fromRGB(150, 30, 160) },
	-- The holiday games' key (one at a time, in its holiday's colours).
	Treats = { Color3.fromRGB(255, 160, 60), Color3.fromRGB(120, 40, 140) },
	Turkeys = { Color3.fromRGB(240, 176, 80), Color3.fromRGB(140, 60, 24) },
	Sleigh = { Color3.fromRGB(255, 96, 96), Color3.fromRGB(150, 16, 30) },
	Gifts = { Color3.fromRGB(255, 120, 110), Color3.fromRGB(30, 110, 70) },
	Eggs = { Color3.fromRGB(255, 180, 220), Color3.fromRGB(110, 150, 230) },
	Home = { Color3.fromRGB(255, 222, 150), Color3.fromRGB(150, 110, 40) },
}

-- A key on the dock, made to look like a thing in the house rather than a screen: a tile of warm
-- dark leather with a fine brass edge and a soft shadow under it; its icon drawn clean in the
-- key's own colour, softened; its name in ivory beneath, and a short stripe of its colour along
-- its foot. No glow, no sweeping light. Pointed at, it lifts a little; pressed, it sinks.
local ICONS: { [string]: string } = { Collection = "collection", Trade = "trade", Wardrobe = "wardrobe", Gems = "gems", Suites = "suites", Invite = "invite", Watch = "watch", Back = "home", Home = "home" }
local IVORY = Color3.fromRGB(238, 232, 220)
local BRASS = Color3.fromRGB(128, 106, 72)

-- A key's colour, softened toward ivory: a natural tint, never neon.
local function tintOf(label: string): Color3
	local accent = ACCENTS[label] or ACCENTS.Collection
	return accent[1]:Lerp(IVORY, 0.4)
end

local function tile(parent: Instance, order: number, glyph: string, label: string, hotkey: string?, onPress: () -> ()): TextButton
	local tint = tintOf(label)
	local radius = math.floor(SIZE * 0.2)
	local holder = Instance.new("Frame")
	holder.Name = label
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(keyWidth(), SIZE)
	holder.Parent = parent
	-- A soft shadow, a little below: the key sits on the screen, it doesn't shine.
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 3)
	shadow.Size = UDim2.new(1, 2, 1, 2)
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.55
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	local shc = Instance.new("UICorner")
	shc.CornerRadius = UDim.new(0, radius + 1)
	shc.Parent = shadow
	shadow.Parent = holder
	local b = Instance.new("TextButton")
	b.Name = "Key"
	b.AutoButtonColor = false
	b.Size = UDim2.fromScale(1, 1)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.02
	b.Text = ""
	b.ZIndex = 2
	b.ClipsDescendants = true
	b.Parent = holder
	-- Warm dark leather, a shade lighter at the top.
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new(Color3.fromRGB(50, 44, 38), Color3.fromRGB(29, 26, 23))
	fill.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = b
	-- The fine brass edge.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = BRASS
	stroke.Thickness = 1
	stroke.Transparency = 0.2
	stroke.Parent = b
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	-- The icon: drawn where the house has one, the glyph otherwise (the holiday keys).
	local orb = Instance.new("Frame")
	orb.Name = "Orb"
	orb.AnchorPoint = Vector2.new(0.5, 0)
	orb.Position = UDim2.new(0.5, 0, 0, math.floor(SIZE * 0.13))
	orb.Size = UDim2.fromOffset(math.floor(SIZE * 0.46), math.floor(SIZE * 0.46))
	orb.BackgroundTransparency = 1
	orb.ZIndex = 4
	orb.Parent = b
	local iconName = ICONS[label]
	-- (Bolder on a phone, where the keys are small.)
	local weight = if UserInputService.TouchEnabled then 2.7 else nil
	local drawn = if iconName then Icons.draw(orb, iconName, tint, math.floor(SIZE * 0.42), weight) else nil
	if drawn then
		for _, f in drawn:GetDescendants() do
			if f:IsA("GuiObject") then
				f.ZIndex = 4
			end
		end
	else
		local icon = Instance.new("TextLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.Size = UDim2.fromScale(1, 1)
		icon.Text = glyph
		icon.TextScaled = true
		icon.TextColor3 = Color3.new(1, 1, 1)
		icon.ZIndex = 4
		icon.Parent = orb
	end
	local name = Instance.new("TextLabel")
	name.Name = "Label"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -math.floor(SIZE * 0.1))
	name.Size = UDim2.new(1, -10, 0, math.floor(SIZE * 0.22))
	name.FontFace = Brand.Fonts.bodyBold
	name.TextWrapped = false
	name.TextColor3 = IVORY
	name.TextStrokeTransparency = 1
	name.Text = label
	name.ZIndex = 5
	if UserInputService.TouchEnabled then
		-- (On a phone the keys are small: the name at a set size you can read, a step smaller
		-- only if it wouldn't fit the key.)
		name.TextScaled = false
		local px = math.max(10, math.floor(SIZE * 0.2))
		while px > 8 and Theme.measure(label, px, Brand.Fonts.bodyBold).X > keyWidth() - 8 do
			px -= 1
		end
		name.TextSize = px
	else
		-- (Scaled to fit the key's foot, and never cut short.)
		name.TextScaled = true
		local nameFit = Instance.new("UITextSizeConstraint")
		nameFit.MaxTextSize = math.max(11, math.floor(SIZE * 0.19))
		nameFit.MinTextSize = 1
		nameFit.Parent = name
	end
	name.Parent = b
	-- A short stripe of the key's colour along its foot.
	local stripe = Instance.new("Frame")
	stripe.Name = "Underline"
	stripe.BorderSizePixel = 0
	stripe.BackgroundColor3 = tint
	stripe.BackgroundTransparency = 0.25
	stripe.AnchorPoint = Vector2.new(0.5, 1)
	stripe.Position = UDim2.new(0.5, 0, 1, -3)
	stripe.Size = UDim2.new(0.28, 0, 0, 2)
	stripe.ZIndex = 5
	local sc = Instance.new("UICorner")
	sc.CornerRadius = UDim.new(1, 0)
	sc.Parent = stripe
	stripe.Parent = b
	-- The keyboard key, a small chip on the corner (not on phones).
	if hotkey and not UserInputService.TouchEnabled then
		local badge = Instance.new("TextLabel")
		badge.Name = "Hotkey"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 5, 0, -5)
		local bpx = math.max(20, math.floor(SIZE * 0.27))
		badge.Size = UDim2.fromOffset(bpx, bpx)
		badge.BackgroundColor3 = Color3.fromRGB(24, 21, 18)
		badge.TextColor3 = IVORY
		badge.FontFace = Brand.Fonts.heavy
		badge.TextSize = math.max(12, math.floor(bpx * 0.56))
		badge.Text = hotkey
		badge.ZIndex = 6
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, math.floor(bpx * 0.3))
		bc.Parent = badge
		local bs = Instance.new("UIStroke")
		bs.Color = BRASS
		bs.Thickness = 1
		bs.Transparency = 0.15
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Parent = badge
		badge.Parent = holder
	end
	local over = false
	local function lit(on: boolean)
		over = on
		TweenService:Create(scale, TweenInfo.new(0.14, Enum.EasingStyle.Quad), { Scale = if on then 1.04 else 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.14), { Transparency = if on then 0 else 0.2, Color = if on then C.gold else BRASS }):Play()
	end
	b.MouseEnter:Connect(function()
		lit(true)
	end)
	b.MouseLeave:Connect(function()
		lit(false)
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.95 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if over then 1.04 else 1 }):Play()
	end)
	b.Activated:Connect(function()
		Theme.haptic()
		onPress()
	end)
	return b
end

local watchTile: Frame? = nil
local watchKey: TextButton? = nil
local holidayTile: Frame? = nil
local holidaySpec: string? = nil
local COLUMNS = 2
-- (Defined below, with the dock's folding away: called whenever a key comes or goes.)
local refreshVisible: () -> ()

-- The dock's size for `n` keys, two by two.
local function dockSize(n: number): UDim2
	local rows = math.ceil(n / COLUMNS)
	return UDim2.fromOffset(COLUMNS * keyWidth() + (COLUMNS - 1) * GAP, rows * SIZE + (rows - 1) * GAP)
end

-- The dock's keys now: the six, and Watch and the holiday key when they're there.
local function keyCount(): number
	return KEYS + (if watchTile then 1 else 0) + (if holidayTile then 1 else 0)
end

-- How far right the dock reaches, in the HUD's units (what stands beside it starts after this).
function QuickDock.right(): number
	return 16 + COLUMNS * keyWidth() + (COLUMNS - 1) * GAP
end

-- The key to watch a fireworks show from across the street (and to come back), at the foot of the
-- dock under Invite while a show is on: never in the middle of the screen. Set by Main from the
-- fireworks' own offer.
QuickDock.watchPressed = function() end
function QuickDock.setWatch(show: boolean, watching: boolean?)
	local f = dock
	if not f then
		return
	end
	if not show then
		local t = watchTile
		watchTile, watchKey = nil, nil
		if t then
			t:Destroy()
		end
		f.Size = dockSize(keyCount())
		refreshVisible()
		return
	end
	if not watchKey then
		local k = tile(f, 7, "🎆", "Watch", nil, function()
			QuickDock.watchPressed()
		end)
		watchKey = k
		watchTile = k.Parent :: Frame
		f.Size = dockSize(keyCount())
		refreshVisible()
	end
	local k = watchKey :: TextButton
	local label = k:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = if watching then "Back" else "Watch"
	end
	-- (Its icon: the burst of fireworks to go and watch, the house to come back.)
	local icon = k:FindFirstChild("Icon", true)
	local want = if watching then "home" else "watch"
	if icon and icon:GetAttribute("Icon") ~= want then
		local orb = icon.Parent
		icon:Destroy()
		local drawn = if orb then Icons.draw(orb, want, tintOf("Watch"), math.floor(SIZE * 0.42), if UserInputService.TouchEnabled then 2.7 else nil) else nil
		if drawn then
			for _, part in drawn:GetDescendants() do
				if part:IsA("GuiObject") then
					part.ZIndex = 4
				end
			end
		end
	end
end

-- The holiday game's key, at the foot of the dock while its game is on: Treats (to Hallows Lane),
-- Turkeys (the Harvest Field), the Sleigh (aboard, from anywhere in the house), your Gifts to open,
-- Eggs (how many are left), or Home (back to the Maison from a holiday place). `count`: a small
-- number on its corner (the gifts waiting). Set by World/HolidayPlay; nil takes it away.
QuickDock.holidayPressed = function() end
function QuickDock.setHoliday(glyph: string?, label: string?, count: number?)
	local f = dock
	if not f then
		return
	end
	if not glyph or not label then
		local t = holidayTile
		holidayTile, holidaySpec = nil, nil
		if t then
			t:Destroy()
		end
		f.Size = dockSize(keyCount())
		refreshVisible()
		return
	end
	local spec = glyph .. "|" .. label
	if spec ~= holidaySpec then
		local old = holidayTile
		if old then
			old:Destroy()
		end
		local k = tile(f, 8, glyph, label, nil, function()
			QuickDock.holidayPressed()
		end)
		holidayTile = k.Parent :: Frame
		holidaySpec = spec
		f.Size = dockSize(keyCount())
		refreshVisible()
	end
	local holder = holidayTile :: Frame
	local bubble = holder:FindFirstChild("Count") :: TextLabel?
	if count and count > 0 then
		if not bubble then
			local b = Instance.new("TextLabel")
			b.Name = "Count"
			b.AnchorPoint = Vector2.new(1, 0)
			b.Position = UDim2.new(1, 6, 0, -6)
			local px = math.max(22, math.floor(SIZE * 0.3))
			b.Size = UDim2.fromOffset(px, px)
			b.BackgroundColor3 = Color3.fromRGB(220, 36, 52)
			b.TextColor3 = Color3.new(1, 1, 1)
			b.FontFace = Brand.Fonts.heavy
			b.TextSize = math.max(12, math.floor(px * 0.58))
			b.ZIndex = 7
			local bc = Instance.new("UICorner")
			bc.CornerRadius = UDim.new(1, 0)
			bc.Parent = b
			local bs = Instance.new("UIStroke")
			bs.Color = Color3.new(1, 1, 1)
			bs.Thickness = 1.5
			bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			bs.Parent = b
			b.Parent = holder
			bubble = b
		end
		(bubble :: TextLabel).Text = if count > 99 then "99+" else tostring(count)
	elseif bubble then
		bubble:Destroy()
	end
end

-- Folded away (Settings → Keys down the left, or the ‹ key at the dock's corner): a small KEYS ›
-- tab stands where the dock was, and brings it back. The event keys never fold away (Watch the
-- fireworks, and the holiday's: the Sleigh, Turkeys, Treats, Gifts, Eggs, Home): while the rest is
-- folded they stand under the tab, so what's on in the house is always one tap away.
local foldKey: TextButton? = nil -- the ‹ beside the dock's top corner
local unfoldTab: TextButton? = nil -- KEYS ›, while it's folded away
local special: Frame? = nil -- the event keys' place under the tab, while the rest is folded
local TOP = 74

local function folded(): boolean
	return State.get("sideKeys") == "Hidden"
end

-- A small round key in the house's dark glass and gold: `text` on it, `width` wide.
local function smallKey(name: string, text: string, width: number, height: number, onPress: () -> ()): TextButton
	local k = Instance.new("TextButton")
	k.Name = name
	k.AutoButtonColor = false
	k.Size = UDim2.fromOffset(width, height)
	k.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	k.BackgroundTransparency = 0.08
	k.FontFace = Brand.Fonts.heavy
	k.TextSize = math.floor(height * 0.46)
	k.TextColor3 = C.lightGold
	k.Text = text
	k.ZIndex = 6
	local kc = Instance.new("UICorner")
	kc.CornerRadius = UDim.new(1, 0)
	kc.Parent = k
	local ks = Instance.new("UIStroke")
	ks.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ks.Color = C.gold
	ks.Transparency = 0.25
	ks.Thickness = 1.25
	ks.Parent = k
	k.Activated:Connect(function()
		Theme.haptic()
		onPress()
	end)
	k.Parent = Root.hud
	return k
end

-- Out of the way while sorting, while the piano's keys are up, and while a panel is open (a panel
-- is the whole of what the guest is doing then: the keys come back the moment it closes, and
-- never sit under its glass). And folded away, if the guest put it away.
local seatedNow = false
local pianoNow = false
local function rehome(t: Frame?, home: Instance)
	if t and t.Parent ~= home then
		t.Parent = home
	end
end
refreshVisible = function()
	local f = dock
	if not f then
		return
	end
	local ok, sorting = pcall(QuickDock.isSorting)
	local away = seatedNow or pianoNow or Root.isOpen() or (ok and sorting == true)
	local fold = folded()
	f.Visible = not away and not fold
	local k = foldKey
	if k then
		k.Visible = not away and not fold
	end
	local t = unfoldTab
	if t then
		t.Visible = not away and fold
	end
	-- (The event keys: in the dock, or under the tab while the rest is folded away.)
	local s = special
	local home: Instance = if fold and s then s else f
	rehome(watchTile, home)
	rehome(holidayTile, home)
	if s then
		s.Visible = not away and fold
	end
	-- (Centred panels and the big moments keep clear of what's down the left: the whole dock, or
	-- only the tab and the event keys while it's folded away.)
	local events = watchTile ~= nil or holidayTile ~= nil
	Root.left = if fold and t then 16 + math.max(t.Size.X.Offset, if events then keyWidth() else 0) else QuickDock.right()
end

function QuickDock.setSeated(seated: boolean)
	seatedNow = seated
	refreshVisible()
end

-- The piano's keyboard runs the width of the screen: the dock steps aside while it's up.
function QuickDock.setPiano(on: boolean)
	pianoNow = on
	refreshVisible()
end

function QuickDock.isFolded(): boolean
	return folded()
end

function QuickDock.start()
	-- Down the left, starting under the Gilt bar, two by two, with room for a seventh key (Watch,
	-- during a fireworks show) and clear of the thumbstick. On a phone the keys are smaller: the
	-- screen is small, and the table and the room come first.
	local touch = UserInputService.TouchEnabled
	local h = Root.size().Y
	local top = TOP
	local room = h - top - 24
	local most = if touch then 64 else 88
	GAP = if touch then 8 else 10
	SIZE = math.clamp(math.floor((room - 3 * GAP) / 4), if touch then 48 else 56, most)
	-- (How far right the dock reaches, once its keys have their size: centred panels and the
	-- big moments keep clear of it.)
	Root.left = QuickDock.right()
	local f = Instance.new("Frame")
	f.Name = "QuickDock"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0, 0)
	f.Position = UDim2.new(0, 16, 0, top)
	f.Size = dockSize(KEYS)
	f.Parent = Root.hud
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(keyWidth(), SIZE)
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.FillDirectionMaxCells = COLUMNS
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = f
	tile(f, 1, "🏺", "Collection", "C", function()
		QuickDock.openCollection()
	end)
	tile(f, 2, "🤝", "Trade", "T", QuickDock.openTrade)
	tile(f, 3, "👔", "Wardrobe", "V", function()
		QuickDock.openWardrobe()
	end)
	tile(f, 4, "💎", "Gems", nil, function()
		QuickDock.openGems()
	end)
	tile(f, 5, "🛋️", "Suites", nil, QuickDock.openSuites)
	tile(f, 6, "✉️", "Invite", nil, function()
		QuickDock.inviteFriend()
	end)
	dock = f
	-- The ‹ key just right of the dock's top corner (clear of the T key's chip), and the KEYS ›
	-- tab where the dock begins, for while it's folded away. Bigger to the touch on a phone.
	local side = if touch then 40 else 30
	local fk = smallKey("DockFold", "‹", side, side, function()
		State.set("sideKeys", "Hidden")
		refreshVisible()
	end)
	fk.Position = UDim2.fromOffset(QuickDock.right() + 8, top)
	foldKey = fk
	local tabHeight = if touch then 40 else 32
	local tabText = "KEYS  ›"
	local tabSize = math.floor(tabHeight * 0.4)
	local ut = smallKey("DockUnfold", tabText, Theme.measure(tabText, tabSize, Brand.Fonts.heavy).X + 28, tabHeight, function()
		State.set("sideKeys", "Shown")
		refreshVisible()
	end)
	ut.TextSize = tabSize
	ut.Position = UDim2.fromOffset(16, top)
	unfoldTab = ut
	local sp = Instance.new("Frame")
	sp.Name = "DockEvents"
	sp.BackgroundTransparency = 1
	sp.Position = UDim2.fromOffset(16, top + tabHeight + GAP)
	sp.Size = UDim2.fromOffset(keyWidth(), 2 * SIZE + GAP)
	sp.Visible = false
	sp.Parent = Root.hud
	local spList = Instance.new("UIListLayout")
	spList.Padding = UDim.new(0, GAP)
	spList.SortOrder = Enum.SortOrder.LayoutOrder
	spList.Parent = sp
	special = sp
	Root.PanelsChanged:Connect(refreshVisible)
	State.watch("sideKeys", function()
		refreshVisible()
	end)
	-- (Sitting down, the sorting screen, a panel: the table says so, and a look four times a second
	-- makes sure, so nothing that starts late or misses a word leaves the keys over the cloth.)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			refreshVisible()
		end
	end)
	-- (What stands beside the dock, the perk chips, starts just right of it.)
	local chips = Root.hud:FindFirstChild("PerkChips")
	if chips and chips:IsA("Frame") then
		chips.Position = UDim2.new(0, QuickDock.right() + 18, chips.Position.Y.Scale, chips.Position.Y.Offset)
	end
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or QuickDock.isSeated() then
			return
		end
		if input.KeyCode == Enum.KeyCode.C then
			QuickDock.openCollection()
		elseif input.KeyCode == Enum.KeyCode.T then
			QuickDock.openTrade()
		elseif input.KeyCode == Enum.KeyCode.V then
			QuickDock.openWardrobe()
		end
	end)
end



return QuickDock

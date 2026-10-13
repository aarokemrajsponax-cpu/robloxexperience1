--!strict
-- The quick dock: six big keys down the left side of the screen, two by two, always one tap away
-- (and a key each on the keyboard): your Collection (C), Trade (T), your Wardrobe (V), Gems,
-- Suites (your own, or a friend's: friends on Roblox may visit each other's), and Invite (Roblox's
-- invite prompt, to bring a friend). Big enough to read at a glance on a phone.
-- Trade opens a short list of everyone in the house, each with a Trade key, and your past trades.
-- It steps aside while you sort at a table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Names = require(ReplicatedStorage.Shared.Names)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Icons = require(script.Parent.Icons)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

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

-- Each key's own colour (its tile and its glow, light and deep), so the dock reads at a glance.
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

local function still(): boolean
	local ok, value = pcall(function()
		return require(script.Parent.Parent.State).get("movement")
	end)
	return ok and value == "Still"
end

-- A key on the dock, made to be seen and to look like the house: a tile of dark glass, lit from
-- above, with a fine edge and a wash of the key's own colour; its icon drawn in light (a neon tube
-- in glass, not a cartoon); its name clean beneath; a bar of its colour along its foot that runs
-- wider under the pointer. A soft glow of its colour breathes round it. Pressed, it sinks.
local ICONS: { [string]: string } = { Collection = "collection", Trade = "trade", Wardrobe = "wardrobe", Gems = "gems", Suites = "suites", Invite = "invite", Watch = "watch", Back = "home", Home = "home" }

local function tile(parent: Instance, order: number, glyph: string, label: string, hotkey: string?, onPress: () -> ()): TextButton
	local accent = ACCENTS[label] or ACCENTS.Collection
	local light = accent[1]
	local radius = math.floor(SIZE * 0.22)
	local holder = Instance.new("Frame")
	holder.Name = label
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(keyWidth(), SIZE)
	holder.Parent = parent
	local glow = Theme.glow(holder, light, radius, 0.75)
	-- The dark rim, just outside the tile, so it reads over any room.
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.new(1, 4, 1, 4)
	rim.BackgroundColor3 = Color3.fromRGB(4, 5, 8)
	rim.BackgroundTransparency = 0.35
	rim.BorderSizePixel = 0
	rim.ZIndex = 1
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, radius + 2)
	rc.Parent = rim
	rim.Parent = holder
	local b = Instance.new("TextButton")
	b.Name = "Key"
	b.AutoButtonColor = false
	b.Size = UDim2.fromScale(1, 1)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0.04
	b.Text = ""
	b.ZIndex = 2
	b.ClipsDescendants = true
	b.Parent = holder
	-- Dark glass, lit from above.
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 37, 48)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(17, 19, 26)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(9, 10, 14)),
	})
	fill.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = b
	-- The fine edge: the key's colour, brightest along the top, fading down the sides.
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = light
	stroke.Thickness = 1.5
	stroke.Transparency = 0.15
	stroke.Parent = b
	local strokeLight = Instance.new("UIGradient")
	strokeLight.Rotation = 90
	strokeLight.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.55, 0.55),
		NumberSequenceKeypoint.new(1, 0.25),
	})
	strokeLight.Parent = stroke
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	-- A wash of the key's colour, from the top: the glass holds its light.
	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.BorderSizePixel = 0
	wash.BackgroundColor3 = light
	wash.Size = UDim2.fromScale(1, 0.75)
	wash.ZIndex = 2
	local wg = Instance.new("UIGradient")
	wg.Rotation = 90
	wg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	wg.Parent = wash
	-- (Rounded like the tile: a frame's clipping keeps square corners, so the wash has its own.)
	local wc = Instance.new("UICorner")
	wc.CornerRadius = UDim.new(0, radius)
	wc.Parent = wash
	wash.Parent = b
	-- A hairline of white light along the top edge.
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BorderSizePixel = 0
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.AnchorPoint = Vector2.new(0.5, 0)
	gloss.Position = UDim2.new(0.5, 0, 0, 1)
	gloss.Size = UDim2.new(1, -radius * 2, 0, 1)
	gloss.ZIndex = 3
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	gg.Parent = gloss
	gloss.Parent = b
	-- The icon: drawn in light where the house has one, the glyph otherwise (the holiday keys).
	local orb = Instance.new("Frame")
	orb.Name = "Orb"
	orb.AnchorPoint = Vector2.new(0.5, 0)
	orb.Position = UDim2.new(0.5, 0, 0, math.floor(SIZE * 0.13))
	orb.Size = UDim2.fromOffset(math.floor(SIZE * 0.46), math.floor(SIZE * 0.46))
	orb.BackgroundTransparency = 1
	orb.ZIndex = 4
	orb.Parent = b
	local iconName = ICONS[label]
	local drawn = if iconName then Icons.draw(orb, iconName, light, math.floor(SIZE * 0.42)) else nil
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
	-- (Scaled to fit the key's foot, and never cut short.)
	name.TextScaled = true
	name.TextWrapped = false
	name.TextColor3 = Color3.fromRGB(238, 240, 246)
	name.TextStrokeTransparency = 1
	name.Text = label
	name.ZIndex = 5
	local nameFit = Instance.new("UITextSizeConstraint")
	nameFit.MaxTextSize = math.max(11, math.floor(SIZE * 0.19))
	nameFit.MinTextSize = 1
	nameFit.Parent = name
	name.Parent = b
	-- The bar of the key's colour along its foot.
	local underline = Instance.new("Frame")
	underline.Name = "Underline"
	underline.BorderSizePixel = 0
	underline.BackgroundColor3 = light
	underline.AnchorPoint = Vector2.new(0.5, 1)
	underline.Position = UDim2.new(0.5, 0, 1, -3)
	underline.Size = UDim2.new(0.3, 0, 0, 2)
	underline.ZIndex = 5
	local uc = Instance.new("UICorner")
	uc.CornerRadius = UDim.new(1, 0)
	uc.Parent = underline
	underline.Parent = b
	-- A band of light that sweeps across the key now and then (each key at its own moment).
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BorderSizePixel = 0
	sweep.BackgroundColor3 = Color3.new(1, 1, 1)
	sweep.BackgroundTransparency = 0
	sweep.Size = UDim2.fromScale(1, 1)
	sweep.ZIndex = 5
	sweep.Parent = b
	local sc = Instance.new("UICorner")
	sc.CornerRadius = corner.CornerRadius
	sc.Parent = sweep
	local sg = Instance.new("UIGradient")
	sg.Rotation = 25
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.44, 1),
		NumberSequenceKeypoint.new(0.5, 0.86),
		NumberSequenceKeypoint.new(0.56, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Offset = Vector2.new(-1, 0)
	sg.Parent = sweep
	if not still() then
		-- The glow breathes; the light sweeps across every few seconds.
		for i, h in glow:GetChildren() do
			if h:IsA("Frame") then
				local from = h.BackgroundTransparency
				TweenService:Create(h, TweenInfo.new(1.8 + i * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = math.min(1, from + 0.06) }):Play()
			end
		end
		TweenService:Create(sg, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 5 + order * 0.7), { Offset = Vector2.new(1, 0) }):Play()
	end
	-- The keyboard key, a small chip on the corner in the key's colour (not on phones).
	if hotkey and not UserInputService.TouchEnabled then
		local badge = Instance.new("TextLabel")
		badge.Name = "Hotkey"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 5, 0, -5)
		local bpx = math.max(20, math.floor(SIZE * 0.27))
		badge.Size = UDim2.fromOffset(bpx, bpx)
		badge.BackgroundColor3 = Color3.fromRGB(8, 9, 13)
		badge.TextColor3 = light:Lerp(Color3.new(1, 1, 1), 0.4)
		badge.FontFace = Brand.Fonts.heavy
		badge.TextSize = math.max(12, math.floor(bpx * 0.56))
		badge.Text = hotkey
		badge.ZIndex = 6
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, math.floor(bpx * 0.3))
		bc.Parent = badge
		local bs = Instance.new("UIStroke")
		bs.Color = light
		bs.Thickness = 1.25
		bs.Transparency = 0.1
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Parent = badge
		badge.Parent = holder
	end
	local over = false
	local function lit(on: boolean)
		over = on
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = if on then 1.06 else 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.16), { Transparency = if on then 0 else 0.15 }):Play()
		TweenService:Create(underline, TweenInfo.new(0.2, Enum.EasingStyle.Quint), { Size = UDim2.new(if on then 0.62 else 0.3, 0, 0, 2) }):Play()
		-- (The glow reaches further while lit: each halo by half its own spread again.)
		for _, h in glow:GetChildren() do
			if h:IsA("Frame") then
				local spread = if h.Name == "Halo2" then 28 else 12
				local reach = if on then math.floor(spread * 1.5) else spread
				h.Size = UDim2.new(1, reach, 1, reach)
			end
		end
	end
	b.MouseEnter:Connect(function()
		lit(true)
	end)
	b.MouseLeave:Connect(function()
		lit(false)
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if over then 1.06 else 1 }):Play()
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
		return
	end
	if not watchKey then
		local k = tile(f, 7, "🎆", "Watch", nil, function()
			QuickDock.watchPressed()
		end)
		watchKey = k
		watchTile = k.Parent :: Frame
		f.Size = dockSize(keyCount())
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
		local drawn = if orb then Icons.draw(orb, want, (ACCENTS.Watch)[1], math.floor(SIZE * 0.42)) else nil
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

-- Out of the way while sorting, and while a panel is open (a panel is the whole of what the guest
-- is doing then: the keys come back the moment it closes, and never sit under its glass).
local seatedNow = false
local function refreshVisible()
	local f = dock
	if f then
		f.Visible = not seatedNow and not Root.isOpen()
	end
end

function QuickDock.setSeated(seated: boolean)
	seatedNow = seated
	refreshVisible()
end

function QuickDock.start()
	-- Down the left, starting under the Gilt bar, two by two, big (bigger still on a phone, where
	-- everything is drawn smaller), with room for a seventh key (Watch, during a fireworks show)
	-- and clear of the thumbstick.
	local h = Root.size().Y
	local top = 74
	local room = h - top - 24
	local most = if UserInputService.TouchEnabled then 100 else 88
	GAP = 10
	SIZE = math.clamp(math.floor((room - 3 * GAP) / 4), 56, most)
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
	Root.PanelsChanged:Connect(refreshVisible)
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

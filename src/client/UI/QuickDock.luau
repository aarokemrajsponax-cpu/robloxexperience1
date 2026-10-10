--!strict
-- The quick dock: six round keys down the left side of the screen, always one tap away
-- (and a key each on the keyboard): your Collection (C), Trade (T), your Wardrobe (V), Gems,
-- Suites (your own, or a friend's: friends on Roblox may visit each other's), and Invite (Roblox's
-- invite prompt, to bring a friend).
-- Trade opens a short list of everyone in the house, each with a Trade key, and your past trades.
-- It steps aside while you sort at a table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Names = require(ReplicatedStorage.Shared.Names)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
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
}

local function still(): boolean
	local ok, value = pcall(function()
		return require(script.Parent.Parent.State).get("movement")
	end)
	return ok and value == "Still"
end

-- A key on the dock, made to be seen: a glossy tile in the key's own colour (lit from above, a
-- sheen across its top, deeper at its foot where its name sits), a bright edge, a dark rim
-- round it so it stands out over any room, a large icon, and a soft glow of its colour that
-- breathes. Under the pointer it lifts and glows brighter; pressed, it sinks.
local function tile(parent: Instance, order: number, glyph: string, label: string, hotkey: string?, onPress: () -> ()): TextButton
	local accent = ACCENTS[label] or ACCENTS.Collection
	local radius = math.floor(SIZE * 0.28)
	local holder = Instance.new("Frame")
	holder.Name = label
	holder.LayoutOrder = order
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(SIZE, SIZE)
	holder.Parent = parent
	local glow = Theme.glow(holder, accent[1], radius, 1.35)
	-- The dark rim, just outside the tile.
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.Position = UDim2.fromScale(0.5, 0.5)
	rim.Size = UDim2.new(1, 6, 1, 6)
	rim.BackgroundColor3 = Color3.fromRGB(6, 6, 9)
	rim.BackgroundTransparency = 0.25
	rim.BorderSizePixel = 0
	rim.ZIndex = 1
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, radius + 3)
	rc.Parent = rim
	rim.Parent = holder
	local b = Instance.new("TextButton")
	b.Name = "Key"
	b.AutoButtonColor = false
	b.Size = UDim2.fromScale(1, 1)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.BackgroundTransparency = 0
	b.Text = ""
	b.ZIndex = 2
	b.Parent = holder
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accent[1]:Lerp(Color3.new(1, 1, 1), 0.18)),
		ColorSequenceKeypoint.new(0.55, accent[1]:Lerp(accent[2], 0.45)),
		ColorSequenceKeypoint.new(1, accent[2]:Lerp(Color3.new(0, 0, 0), 0.25)),
	})
	fill.Parent = b
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = accent[1]:Lerp(Color3.new(1, 1, 1), 0.65)
	stroke.Thickness = 2
	stroke.Transparency = 0.05
	stroke.Parent = b
	local strokeLight = Instance.new("UIGradient")
	strokeLight.Rotation = 90
	strokeLight.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.35),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	strokeLight.Parent = stroke
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	-- The sheen across the top half, like light on lacquer.
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BorderSizePixel = 0
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.Position = UDim2.fromOffset(3, 3)
	gloss.Size = UDim2.new(1, -6, 0.48, 0)
	gloss.ZIndex = 3
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0, math.max(4, radius - 3))
	gc.Parent = gloss
	local gg = Instance.new("UIGradient")
	gg.Rotation = 90
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.62),
		NumberSequenceKeypoint.new(1, 1),
	})
	gg.Parent = gloss
	gloss.Parent = b
	-- The foot, deeper, where the name sits.
	local foot = Instance.new("Frame")
	foot.Name = "Foot"
	foot.BorderSizePixel = 0
	foot.BackgroundColor3 = Color3.new(0, 0, 0)
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.fromScale(0, 1)
	foot.Size = UDim2.new(1, 0, 0.42, 0)
	foot.ZIndex = 3
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, radius)
	fc.Parent = foot
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	fg.Parent = foot
	foot.Parent = b
	-- The icon, large; it stands in for the old orb (kept by name for the checks).
	local orb = Instance.new("Frame")
	orb.Name = "Orb"
	orb.AnchorPoint = Vector2.new(0.5, 0)
	orb.Position = UDim2.new(0.5, 0, 0, math.floor(SIZE * 0.08))
	orb.Size = UDim2.fromOffset(math.floor(SIZE * 0.58), math.floor(SIZE * 0.58))
	orb.BackgroundTransparency = 1
	orb.ZIndex = 4
	orb.Parent = b
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
	local name = Instance.new("TextLabel")
	name.Name = "Label"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -math.floor(SIZE * 0.06))
	name.Size = UDim2.new(1, -4, 0, math.floor(SIZE * 0.24))
	name.FontFace = Brand.Fonts.heavy
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeColor3 = Color3.new(0, 0, 0)
	name.TextStrokeTransparency = 0.25
	name.Text = label
	name.ZIndex = 5
	local nameFit = Instance.new("UITextSizeConstraint")
	nameFit.MaxTextSize = if SIZE >= 60 then 13 else 11
	nameFit.MinTextSize = 8
	nameFit.Parent = name
	name.Parent = b
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
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.72),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Offset = Vector2.new(-1, 0)
	sg.Parent = sweep
	if not still() then
		-- The glow breathes; the light sweeps across every few seconds.
		for i, h in glow:GetChildren() do
			if h:IsA("Frame") then
				local from = h.BackgroundTransparency
				TweenService:Create(h, TweenInfo.new(1.8 + i * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = math.min(1, from + 0.08) }):Play()
			end
		end
		TweenService:Create(sg, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 5 + order * 0.7), { Offset = Vector2.new(1, 0) }):Play()
	end
	-- The keyboard key, a small gold badge on the corner (not on phones).
	if hotkey and not UserInputService.TouchEnabled then
		local badge = Instance.new("TextLabel")
		badge.Name = "Hotkey"
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 5, 0, -5)
		badge.Size = UDim2.fromOffset(20, 20)
		badge.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
		badge.TextColor3 = Color3.new(1, 1, 1)
		badge.FontFace = Brand.Fonts.heavy
		badge.TextSize = 12
		badge.Text = hotkey
		badge.ZIndex = 6
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = badge
		local bs = Instance.new("UIStroke")
		bs.Color = accent[1]
		bs.Thickness = 1.5
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Parent = badge
		badge.Parent = holder
	end
	local over = false
	local function lit(on: boolean)
		over = on
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Scale = if on then 1.08 else 1 }):Play()
		TweenService:Create(stroke, TweenInfo.new(0.16), { Transparency = if on then 0 else 0.1 }):Play()
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
		TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad), { Scale = 0.93 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if over then 1.08 else 1 }):Play()
	end)
	b.Activated:Connect(function()
		Theme.haptic()
		onPress()
	end)
	return b
end

local watchTile: Frame? = nil
local watchKey: TextButton? = nil

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
		f.Size = UDim2.fromOffset(SIZE, KEYS * SIZE + (KEYS - 1) * GAP)
		return
	end
	if not watchKey then
		local k = tile(f, 7, "🎆", "Watch", nil, function()
			QuickDock.watchPressed()
		end)
		watchKey = k
		watchTile = k.Parent :: Frame
		f.Size = UDim2.fromOffset(SIZE, (KEYS + 1) * SIZE + KEYS * GAP)
	end
	local k = watchKey :: TextButton
	local label = k:FindFirstChild("Label", true)
	if label and label:IsA("TextLabel") then
		label.Text = if watching then "Back" else "Watch"
	end
	local icon = k:FindFirstChild("Icon", true)
	if icon and icon:IsA("TextLabel") then
		icon.Text = if watching then "🏠" else "🎆"
	end
end

function QuickDock.start()
	-- Down the left, starting under the Gilt bar, with room for a seventh key (Watch, during a
	-- fireworks show); smaller keys on a short screen (a phone), clear of the thumbstick.
	local h = Root.size().Y
	local top = 74
	local room = h - top - 24
	SIZE = math.clamp(math.floor((room - 6 * 10) / 7), 40, 66)
	GAP = if SIZE < 52 then 8 else 10
	local f = Instance.new("Frame")
	f.Name = "QuickDock"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0, 0)
	f.Position = UDim2.new(0, 16, 0, top)
	f.Size = UDim2.fromOffset(SIZE, KEYS * SIZE + (KEYS - 1) * GAP)
	f.Parent = Root.hud
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, GAP)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = f
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

-- Out of the way while sorting.
function QuickDock.setSeated(seated: boolean)
	local f = dock
	if f then
		f.Visible = not seated
	end
end

return QuickDock

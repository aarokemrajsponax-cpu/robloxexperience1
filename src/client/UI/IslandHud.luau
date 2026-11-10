--!strict
-- Luxury Island's own screen, shown only while a guest is on the island (the server's
-- "Attraction" attribute): the island's name and the light it's in, the day at a glance (pearls
-- brought up of five, the sunset toasted or not, postcards of six), and two keys at the foot:
-- Fly home, and Liveries & light. A postcard taken frames its view for a photograph. Every figure
-- is the server's; it decides nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Plan = require(ReplicatedStorage.Shared.Island)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local IslandHud = {}

-- Set by Main: open the island's board (a tab), and photo mode.
IslandHud.openBoard = function(_which: string?) end
IslandHud.photo = function() end

local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local SEA = Color3.fromRGB(110, 220, 236)
local CARD_W = 380
local CARD_H = 92

local card: Frame? = nil
local keys: Frame? = nil
local parts: { [string]: any } = {}
local topConn: RBXScriptConnection? = nil
local view: { [string]: any } = {}

local function label(parent: Instance, name: string, text: string, size: number, font: Font, colour: Color3): TextLabel
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
	l.Parent = parent
	return l
end

-- One of the day's three: a glyph, its count, a word under it.
local function chip(parent: Instance, name: string, order: number): (TextLabel, TextLabel)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	f.BackgroundTransparency = 0.95
	f.Size = UDim2.new(1 / 3, -6, 1, 0)
	f.LayoutOrder = order
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = f
	local big = label(f, "Figure", "", 15, Brand.Fonts.bodyBold, C.bone)
	big.Position = UDim2.fromOffset(0, 3)
	big.TextXAlignment = Enum.TextXAlignment.Center
	local small = label(f, "Word", "", 10, Brand.Fonts.bodyBold, C.smoke)
	small.Position = UDim2.fromOffset(0, 24)
	small.TextXAlignment = Enum.TextXAlignment.Center
	return big, small
end

local function place()
	local c = card
	if not c then
		return
	end
	local y = math.max(Root.topClear() + 6, 126)
	c.Position = UDim2.new(0.5, 0, 0, y)
	Root.setTop("Island", y + CARD_H + 4, CARD_W / 2)
	local k = keys
	if k then
		k.Position = UDim2.new(0.5, 0, 1, -(14 + Root.bottomClear()))
	end
end

local function draw()
	if not card then
		return
	end
	local themeDef = Plan.themeById[tostring(view.theme or "golden")] or Plan.themeById.golden
	parts.light.Text = string.upper(themeDef.name)
	local taken = 0
	local total = 0
	for _, t in (if type(view.pearlTaken) == "table" then view.pearlTaken else {}) do
		total += 1
		if t then
			taken += 1
		end
	end
	total = math.max(total, Plan.PEARLS_A_DAY)
	parts.pearls.Text = string.format("🐚 %d / %d", taken, total)
	parts.pearlsWord.Text = if taken >= total then "PEARLS · ALL FOUND" else "PEARLS TODAY"
	parts.pearls.TextColor3 = if taken >= total then GOLD else C.bone
	parts.toast.Text = if view.toasted then "🌅 Toasted" else "🌅 Ready"
	parts.toastWord.Text = if view.toasted then "SUNSET · TOMORROW" else "AT THE LOOKOUT"
	parts.toast.TextColor3 = if view.toasted then GOLD else C.bone
	local cards = tonumber(view.postcardCount) or 0
	local of = tonumber(view.postcardTotal) or #Plan.Postcards
	parts.cards.Text = string.format("📸 %d / %d", cards, of)
	parts.cardsWord.Text = if cards >= of then "POSTCARDS · ALL" else "POSTCARDS"
	parts.cards.TextColor3 = if cards >= of then GOLD else C.bone
end

function IslandHud.mounted(): boolean
	return card ~= nil
end

function IslandHud.mount()
	if card then
		return
	end
	local c = Instance.new("Frame")
	c.Name = "IslandCard"
	c.AnchorPoint = Vector2.new(0.5, 0)
	c.Size = UDim2.fromOffset(CARD_W, CARD_H)
	c.BackgroundColor3 = Color3.fromRGB(12, 16, 20)
	c.BackgroundTransparency = 0.12
	c.Parent = Root.hud
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = c
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = SEA
	edge.Thickness = 1.25
	edge.Transparency = 0.35
	edge.Parent = c
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = c
	local title = label(c, "Title", "LUXURY ISLAND", 11, Brand.Fonts.bodyBold, GOLD)
	title.Position = UDim2.fromOffset(0, 0)
	parts.light = label(c, "Light", "GOLDEN HOUR", 11, Brand.Fonts.bodyBold, SEA)
	parts.light.TextXAlignment = Enum.TextXAlignment.Right
	parts.light.Position = UDim2.fromOffset(0, 0)
	local row = Instance.new("Frame")
	row.Name = "Day"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 24)
	row.Size = UDim2.new(1, 0, 0, 52)
	row.Parent = c
	local list = Theme.list(row, 9, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	parts.pearls, parts.pearlsWord = chip(row, "Pearls", 1)
	parts.toast, parts.toastWord = chip(row, "Toast", 2)
	parts.cards, parts.cardsWord = chip(row, "Postcards", 3)
	card = c

	local k = Instance.new("Frame")
	k.Name = "IslandKeys"
	k.AnchorPoint = Vector2.new(0.5, 1)
	k.BackgroundTransparency = 1
	k.Size = UDim2.fromOffset(360, 44)
	k.Parent = Root.hud
	Theme.list(k, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(k, "Fly home", false, function()
		task.spawn(function()
			local ok, r = pcall(function()
				return Remotes.func("AttractionAsk"):InvokeServer({ op = "home" })
			end)
			if ok and type(r) == "table" and r.ok ~= true and type(r.why) == "string" then
				Toast.show("Not just now", r.why, 3)
			end
		end)
	end, 140)
	Theme.key(k, "Liveries & light", true, function()
		IslandHud.openBoard("liveries")
	end, 180)
	keys = k
	place()
	draw()
	topConn = Root.TopChanged:Connect(place)
end

function IslandHud.unmount()
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
	Root.setTop("Island", nil)
end

-- The island's state from the server.
function IslandHud.update(st: { [string]: any })
	view = st
	draw()
end

-- A postcard taken: framed for a photograph, from the frame toward its view.
local function frame(id: string)
	local spot = nil
	for _, p in Plan.Postcards do
		if p.id == id then
			spot = p
		end
	end
	local camera = Workspace.CurrentCamera
	local o = ((Config.data :: any).Attractions.island or {}).origin
	if not spot or not camera or type(o) ~= "table" then
		return
	end
	local origin = Vector3.new(o[1], o[2], o[3])
	local from = origin + spot.at + Vector3.new(0, 5.5, 0)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(from, origin + spot.look)
	IslandHud.photo()
end

-- What the server says that's the island's own.
function IslandHud.on(m: { [string]: any })
	if m.op == "postcard" then
		local paid = tonumber(m.paid) or 0
		Toast.show("Postcard: " .. tostring(m.name or ""), string.format("%d of %d postcard spots%s", tonumber(m.count) or 0, tonumber(m.total) or 6, if paid > 0 then string.format("  ·  every one: +%d Gilt", paid) else ""), 3.5)
		view.postcardCount = tonumber(m.count) or view.postcardCount
		draw()
		frame(tostring(m.id))
	elseif m.op == "toasted" then
		view.toasted = true
		draw()
	end
end

return IslandHud

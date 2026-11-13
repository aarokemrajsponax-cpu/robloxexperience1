--!strict
-- The Home Screen: the first thing every guest sees. WELCOME TO MAISON NOIR over the house itself
-- (the camera takes a slow walk through its rooms, one after another, each named in the corner),
-- the guest's own Gilt, Gems and level, and the keys: Play (into the Foyer, in front of the
-- Concierge), the Shop, How to play and the Leaderboard. While it's up, the rooms it shows and the
-- Foyer are asked for ahead of time (the house streams in by distance), so the room is there and
-- lit the moment Play is pressed. Black chrome, a neon edge and gold: the house's street-luxury
-- look. The AJKR mark sits bottom-right.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Voice = require(ReplicatedStorage.Shared.Voice)
local CameraRig = require(script.Parent.Parent.Camera)
local Icons = require(script.Parent.Icons)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local Title = {}

local C = Brand.Colours
local NEON = Color3.fromRGB(255, 70, 170)
local ICE = Color3.fromRGB(120, 220, 255)
local GRAPHITE = Color3.fromRGB(16, 17, 21)

local current: Frame? = nil
local tourId = 0
local connections: { RBXScriptConnection } = {}

export type Choices = { play: () -> (), how: () -> (), board: () -> (), shop: (() -> ())? }
export type Shot = { name: string, line: string, from: CFrame, to: CFrame, seconds: number, at: Vector3 }

-- A slow slide across a room: from `a` to `b`, looking at `look` (then `look2`).
local function slide(name: string, line: string, a: Vector3, b: Vector3, look: Vector3, look2: Vector3?, seconds: number?): Shot
	return { name = name, line = line, from = CFrame.lookAt(a, look), to = CFrame.lookAt(b, look2 or look), seconds = seconds or 8, at = (a + look) / 2 }
end

-- The walk through the house, room by room (the Foyer first: it's where Play leads).
function Title.shots(): { Shot }
	local F, S, B, L, T = Layout.Foyer, Layout.Salon, Layout.Ballroom, Layout.Library, Layout.Terrace
	local floor, club = Layout.FLOOR, Layout.CLUB
	return {
		slide("THE FOYER", "Where every evening starts: the Concierge, the grand piano, every door.",
			Vector3.new(F.minX + 34, floor + 13, F.minZ + 6), Vector3.new(F.minX + 58, floor + 15, F.minZ + 4),
			Vector3.new(F.maxX - 26, floor + 18, F.maxZ - 26), Vector3.new(F.maxX - 18, floor + 20, F.maxZ - 30), 9),
		slide("THE STREET", "Ultra-luxury cars at the kerb, and the Grand Prix on the street.",
			Vector3.new(F.minX, floor + 12, Layout.Street.kerbZ - 20), Vector3.new(F.maxX - 8, floor + 16, Layout.Street.kerbZ - 16),
			Vector3.new(0, floor + 14, Layout.Street.facadeZ), Vector3.new(10, floor + 16, Layout.Street.facadeZ), 9),
		slide("THE SALON", "The tables, and the calmest room: sit anywhere and sort at your own pace.",
			Vector3.new(S.maxX - 6, floor + 10, S.maxZ - 6), Vector3.new(S.maxX - 10, floor + 12, S.minZ + 22),
			Vector3.new(S.minX + 20, floor + 2, S.minZ + 12), Vector3.new(S.minX + 20, floor + 2, S.maxZ - 26), 8),
		slide("THE BALLROOM", "Lights Out every 20 minutes: the last lamp still lit wins the pot.",
			Vector3.new(B.minX + 12, club + 34, B.minZ + 10), Vector3.new(B.minX + 36, club + 30, B.minZ + 8),
			Vector3.new(B.centre.X, club + 2, B.centre.Z + 20), Vector3.new(B.centre.X + 18, club + 2, B.centre.Z + 30), 9),
		slide("THE LIBRARY", "Tête-à-Tête: one on one, the very same pieces.",
			Vector3.new(L.minX + 6, club + 12, L.minZ + 6), Vector3.new(L.minX + 12, club + 10, L.maxZ - 6),
			Vector3.new(L.maxX - 14, club + 4, L.maxZ - 10), Vector3.new(L.maxX - 8, club + 4, L.minZ + 14), 8),
		slide("THE TERRACE", "A rooftop under the stars, and the jet to Luxury Island.",
			Vector3.new(T.minX + 6, T.floorY + 14, T.minZ + 6), Vector3.new(T.maxX - 10, T.floorY + 14, T.minZ + 6),
			Vector3.new(T.maxX - 20, T.floorY + 4, T.maxZ - 8), Vector3.new(T.minX + 30, T.floorY + 4, T.maxZ - 8), 9),
	}
end

-- Asks for the house around `at` to be sent ahead (instance streaming): the room is there, lamps
-- and all, by the time the camera or the guest gets to it.
local function streamAround(at: Vector3)
	task.spawn(function()
		pcall(function()
			(Players.LocalPlayer :: any):RequestStreamAroundAsync(at, 4)
		end)
	end)
end
Title.streamAround = streamAround

local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- A chip: an icon and a live figure (the guest's Gilt, Gems or level), black chrome with a fine edge.
local function chip(parent: Instance, name: string, icon: string?, colour: Color3, width: number, height: number, order: number): TextLabel
	local box = Instance.new("Frame")
	box.Name = name
	box.LayoutOrder = order
	box.BackgroundColor3 = GRAPHITE
	box.BackgroundTransparency = 0.12
	box.Size = UDim2.fromOffset(width, height)
	box.Parent = parent
	corner(box, height // 2)
	stroke(box, colour, 1.2, 0.35)
	local x = 12
	if icon and Icons.has(icon) then
		local holder = Instance.new("Frame")
		holder.Name = "Icon"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0, 0.5)
		holder.Position = UDim2.new(0, 10, 0.5, 0)
		holder.Size = UDim2.fromOffset(height - 14, height - 14)
		holder.Parent = box
		Icons.draw(holder, icon, colour, height - 14)
		x = height + 2
	end
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(0, 0.5)
	value.Position = UDim2.new(0, x, 0.5, 0)
	value.Size = UDim2.new(1, -x - 10, 0, height - 12)
	value.FontFace = Brand.Fonts.figures
	value.TextScaled = true
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextColor3 = C.bone
	value.Text = "—"
	value.Parent = box
	return value
end

function Title.show(choices: Choices)
	if current then
		return
	end
	local player = Players.LocalPlayer
	local size = Root.size()
	local small = size.Y < 520 or size.X < 760
	local frame = Instance.new("Frame")
	frame.Name = "Title"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = Root.hud
	current = frame
	tourId += 1
	local id = tourId

	-- The house's rooms behind it all, a deep shade on the left so the words read over them.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.BorderSizePixel = 0
	shade.BackgroundColor3 = C.nearBlack
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundTransparency = 0
	shade.Parent = frame
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(if small then 0.62 else 0.45, 0.55),
		NumberSequenceKeypoint.new(1, 0.92),
	})
	g.Parent = shade

	-- The column: welcome, the name, the guest's own figures, the keys.
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0, 0.5)
	column.Position = UDim2.new(0, if small then 28 else 72, 0.5, 0)
	local width = if small then math.min(400, size.X - 56) else 520
	column.Size = UDim2.fromOffset(width, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.Parent = frame
	local list = Theme.list(column, if small then 6 else 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left

	-- A neon edge down the column's side: the street's own light.
	local edge = Instance.new("Frame")
	edge.Name = "NeonEdge"
	edge.BorderSizePixel = 0
	edge.BackgroundColor3 = NEON
	edge.AnchorPoint = Vector2.new(1, 0.5)
	edge.Position = UDim2.new(0, if small then 16 else 50, 0.5, 0)
	edge.Size = UDim2.new(0, 3, 0, if small then 230 else 360)
	edge.Parent = frame
	local edgeFade = Instance.new("UIGradient")
	edgeFade.Rotation = 90
	edgeFade.Color = ColorSequence.new(NEON, ICE)
	edgeFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
	edgeFade.Parent = edge

	local welcome = Theme.text(column, "WELCOME TO", if small then 12 else 14, "caps", { LayoutOrder = 1, TextColor3 = ICE, TextXAlignment = Enum.TextXAlignment.Left })
	welcome.Name = "Welcome"
	-- (Sized to sit on one line across the column: the house's heavy capitals run about 7.6 to a size.)
	local nameSize = math.floor(math.min(if small then 46 else 68, width / 7.6, if small then size.Y * 0.12 else math.huge))
	local name = Theme.text(column, "MAISON NOIR", nameSize, "display", { LayoutOrder = 2, TextColor3 = C.bone, TextXAlignment = Enum.TextXAlignment.Left })
	name.Name = "Name"
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.brightGold),
		ColorSequenceKeypoint.new(0.55, C.lightGold),
		ColorSequenceKeypoint.new(1, C.gold),
	})
	sheen.Parent = name
	if not small then
		Theme.text(column, Brand.Tagline, 18, "italic", { LayoutOrder = 3, TextColor3 = C.bone, TextXAlignment = Enum.TextXAlignment.Left })
	end

	-- The guest's own Gilt, Gems and level, live.
	local chips = Instance.new("Frame")
	chips.Name = "Purse"
	chips.BackgroundTransparency = 1
	chips.LayoutOrder = 4
	chips.Size = UDim2.new(1, 0, 0, if small then 30 else 38)
	chips.Parent = column
	Theme.list(chips, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
	local h = if small then 30 else 38
	local gilt = chip(chips, "Gilt", "gilt", C.lightGold, if small then 122 else 150, h, 1)
	local gems = chip(chips, "Gems", "gems", ICE, if small then 96 else 116, h, 2)
	local level = chip(chips, "Level", "crown", NEON, if small then 84 else 100, h, 3)
	local function refresh()
		local gv, ev, lv = player:GetAttribute("Gilt"), player:GetAttribute("Gems"), player:GetAttribute("Level")
		gilt.Text = if type(gv) == "number" then Fortune.format(gv) else "—"
		gems.Text = if type(ev) == "number" then Fortune.format(ev) else "—"
		level.Text = if type(lv) == "number" then "LV " .. tostring(math.floor(lv)) else "LV —"
	end
	refresh()
	for _, attribute in { "Gilt", "Gems", "Level" } do
		table.insert(connections, player:GetAttributeChangedSignal(attribute):Connect(refresh))
	end

	-- The keys: Play, big and gold; the Shop, How to play and the Leaderboard under it.
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 6
	keys.Parent = column
	local keyList = Theme.list(keys, if small then 6 else 10)
	keyList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local playWidth = if small then 250 else 320
	local play = Theme.key(keys, "Play", true, choices.play, playWidth)
	play.Name = "Key_Play"
	play.LayoutOrder = 1
	play.Size = UDim2.fromOffset(playWidth, if small then 48 else 58)
	Theme.glow(play, C.brightGold, 18, 0.5)
	local row = Instance.new("Frame")
	row.Name = "More"
	row.BackgroundTransparency = 1
	row.LayoutOrder = 2
	row.Size = UDim2.new(1, 0, 0, 44)
	row.Parent = keys
	Theme.list(row, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
	local third = math.floor((width - 16) / 3)
	local each = math.min(if small then 128 else 150, third)
	if choices.shop then
		Theme.key(row, "Shop", true, choices.shop, each).LayoutOrder = 1
	end
	Theme.key(row, "How to play", false, choices.how, each).LayoutOrder = 2
	Theme.key(row, "Leaderboard", false, choices.board, each).LayoutOrder = 3

	-- Tonight, in a line: the season, tonight's table, a Private Evening.
	local notes = {}
	local seasonName = tostring(Workspace:GetAttribute("SeasonName") or "")
	if seasonName ~= "" then
		table.insert(notes, seasonName)
	end
	local nightlyRoom = Rooms.get(tostring(Workspace:GetAttribute("NightlyRoom") or ""))
	if nightlyRoom then
		table.insert(notes, "Tonight's table: " .. string.lower(Rooms.pace(nightlyRoom.id)))
	end
	if Workspace:GetAttribute("PrivateEvening") == true then
		table.insert(notes, Voice.Private.title)
	end
	if #notes > 0 and not small then
		Theme.text(column, table.concat(notes, "  ·  "), 13, "body", { LayoutOrder = 7, TextColor3 = C.smoke, TextXAlignment = Enum.TextXAlignment.Left })
	end

	-- What the camera is showing: the room's name, and a line about it.
	local caption = Instance.new("Frame")
	caption.Name = "NowShowing"
	caption.BackgroundColor3 = GRAPHITE
	caption.BackgroundTransparency = 0.2
	caption.AnchorPoint = Vector2.new(1, 1)
	caption.Position = UDim2.new(1, -18, 1, if small then -14 else -70)
	caption.Size = UDim2.fromOffset(if small then 300 else 380, if small then 46 else 56)
	caption.Visible = not small or size.X >= 760
	caption.Parent = frame
	corner(caption, 10)
	stroke(caption, NEON, 1.2, 0.3)
	local roomName = Instance.new("TextLabel")
	roomName.Name = "Room"
	roomName.BackgroundTransparency = 1
	roomName.Position = UDim2.fromOffset(14, 7)
	roomName.Size = UDim2.new(1, -28, 0, if small then 18 else 22)
	roomName.FontFace = Brand.Fonts.display
	roomName.TextScaled = true
	roomName.TextXAlignment = Enum.TextXAlignment.Left
	roomName.TextColor3 = C.bone
	roomName.Text = ""
	roomName.Parent = caption
	local roomLine = Instance.new("TextLabel")
	roomLine.Name = "Line"
	roomLine.BackgroundTransparency = 1
	roomLine.Position = UDim2.new(0, 14, 0, if small then 25 else 31)
	roomLine.Size = UDim2.new(1, -28, 0, if small then 14 else 16)
	roomLine.FontFace = Brand.Fonts.body
	roomLine.TextScaled = true
	roomLine.TextXAlignment = Enum.TextXAlignment.Left
	roomLine.TextColor3 = C.smoke
	roomLine.Text = ""
	roomLine.Parent = caption

	-- The AJKR mark, bottom-right, on the Home Screen only.
	if not small then
		local mark = Instance.new("Frame")
		mark.Name = "Mark"
		mark.BackgroundTransparency = 1
		mark.AnchorPoint = Vector2.new(1, 1)
		mark.Position = UDim2.new(1, -18, 1, -14)
		mark.Size = UDim2.fromOffset(120, 44)
		mark.Parent = frame
		local markList = Theme.list(mark, 3)
		markList.HorizontalAlignment = Enum.HorizontalAlignment.Right
		Theme.text(mark, Brand.Owner, 14, "display", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.lightGold })
		Theme.hairline(mark, UDim.new(0, 40), 2)
		Theme.text(mark, "© " .. Brand.year(), 11, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.dim })
	end

	-- A curtain for the cuts between rooms (and the first look: nothing seen before it's ready).
	local curtain = Instance.new("Frame")
	curtain.Name = "Curtain"
	curtain.BorderSizePixel = 0
	curtain.BackgroundColor3 = Color3.new(0, 0, 0)
	curtain.BackgroundTransparency = 0
	curtain.Size = UDim2.fromScale(1, 1)
	curtain.ZIndex = 0
	curtain.Parent = frame
	-- (Under everything: a cut darkens the house behind the words, never the words.)
	shade.ZIndex = 1
	local layers: { Instance? } = { column, edge, caption, frame:FindFirstChild("Mark") }
	for _, layer in layers do
		if layer and layer:IsA("GuiObject") then
			layer.ZIndex = 2
		end
	end

	-- The walk through the house: Play's room first, every room asked for ahead.
	local shots = Title.shots()
	streamAround(Layout.Foyer.spawn.Position)
	for _, s in shots do
		streamAround(s.at)
	end
	local function showShot(s: Shot)
		pcall(CameraRig.tour, s.from, s.to, s.seconds)
		roomName.Text = s.name
		roomLine.Text = s.line
	end
	showShot(shots[1])
	Ease.play(curtain, Ease.info(0.8, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
	task.spawn(function()
		local i = 1
		while current == frame and tourId == id do
			task.wait(math.max(1, shots[i].seconds - 0.45))
			if current ~= frame or tourId ~= id then
				return
			end
			-- (A cut through black: the curtain closes, the camera moves on, the curtain opens.)
			Ease.play(curtain, Ease.info(0.35, Enum.EasingStyle.Sine), { BackgroundTransparency = 0 })
			task.wait(0.4)
			if current ~= frame or tourId ~= id then
				return
			end
			i = i % #shots + 1
			showShot(shots[i])
			Ease.play(curtain, Ease.info(0.5, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
		end
	end)

	-- In: the column fades up, the Play key last.
	for _, d in column:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			local text = d :: any
			local goal = text.TextTransparency
			text.TextTransparency = 1
			Ease.play(d, Ease.info(0.9, Enum.EasingStyle.Sine), { TextTransparency = goal })
		end
	end

	-- A controller starts on Play.
	task.defer(function()
		Theme.select(play)
	end)
end

-- Play: a cut to black, the camera to the Foyer by the Concierge (where the guest stands), and the
-- screen lifts as the camera settles behind them.
function Title.hide()
	local frame = current
	if not frame then
		return
	end
	current = nil
	tourId += 1
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	pcall(function()
		game:GetService("GuiService").SelectedObject = nil
	end)
	local spawn = Layout.Foyer.spawn
	local look = spawn.LookVector
	local from = spawn.Position - look * 14 + Vector3.new(0, 7, 0)
	pcall(CameraRig.tour, CFrame.lookAt(from, spawn.Position + look * 10), CFrame.lookAt(from + look * 2, spawn.Position + look * 10), 1)
	local curtain = frame:FindFirstChild("Curtain")
	if curtain and curtain:IsA("Frame") then
		curtain.ZIndex = 10
		curtain.BackgroundTransparency = 0
	end
	for _, d in frame:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			Ease.play(d, Ease.info(0.25, Enum.EasingStyle.Sine), { TextTransparency = 1, BackgroundTransparency = 1 })
		elseif d:IsA("Frame") and d.Name ~= "Curtain" then
			Ease.play(d, Ease.info(0.25, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
		elseif d:IsA("UIStroke") then
			Ease.play(d, Ease.info(0.25, Enum.EasingStyle.Sine), { Transparency = 1 })
		end
	end
	if curtain and curtain:IsA("Frame") then
		Ease.play(curtain, Ease.info(0.9, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
	end
	task.delay(1, function()
		frame:Destroy()
	end)
end

function Title.isShowing(): boolean
	return current ~= nil
end

return Title

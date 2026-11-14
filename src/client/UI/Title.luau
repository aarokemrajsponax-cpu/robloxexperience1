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
		slide("THE BALLROOM", "Lights Out: party games on the floor, the last lamp lit takes the pot.",
			Vector3.new(B.minX + 12, club + 34, B.minZ + 10), Vector3.new(B.minX + 36, club + 30, B.minZ + 8),
			Vector3.new(B.centre.X, club + 2, B.centre.Z + 20), Vector3.new(B.centre.X + 18, club + 2, B.centre.Z + 30), 9),
		slide("THE LIBRARY", "The Grand Auction: rare lots, bid for in every server at once.",
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

-- How long until a server time, in plain words for the ticker.
local function untilText(at: unknown): string?
	if type(at) ~= "number" then
		return nil
	end
	local left = at - Workspace:GetServerTimeNow()
	if left <= 0 then
		return nil
	end
	if left < 60 then
		return "UNDER A MINUTE"
	end
	local m = math.ceil(left / 60)
	return if m == 1 then "1 MIN" else tostring(m) .. " MIN"
end

-- The ticker along the foot: what's true in this house right now (who's here, Lights Out, the Grand
-- Prix, an event, the season), then the house's games. Nothing on it is made up or hurried.
function Title.tickerItems(): { string }
	local items: { string } = {}
	local n = #Players:GetPlayers()
	table.insert(items, if n == 1 then "1 GUEST IN THE HOUSE" else tostring(n) .. " GUESTS IN THE HOUSE")
	local state, at = Workspace:GetAttribute("BallroomState"), Workspace:GetAttribute("BallroomAt")
	local pot = Workspace:GetAttribute("BallroomPot")
	local potText = if type(pot) == "number" and pot > 0 then " · POT " .. Fortune.format(pot) .. " GILT" else ""
	if state == "playing" then
		table.insert(items, "LIGHTS OUT IS ON NOW IN THE BALLROOM")
	elseif state == "gathering" then
		local t = untilText(at)
		table.insert(items, (if t then "LIGHTS OUT STARTS IN " .. t else "LIGHTS OUT STARTS ANY MOMENT") .. potText)
	elseif state == "open" then
		table.insert(items, "LIGHTS OUT IS OPEN · TAKE A PLACE IN THE BALLROOM" .. potText)
	elseif state == "closed" then
		local t = untilText(at)
		if t then
			table.insert(items, "LIGHTS OUT OPENS IN " .. t)
		end
	end
	local door, doorAt = Workspace:GetAttribute("GrandPrixDoor"), Workspace:GetAttribute("GrandPrixAt")
	if door == "open" then
		table.insert(items, "THE GRAND PRIX IS OPEN ON THE STREET")
	elseif door == "racing" then
		table.insert(items, "A GRAND PRIX IS RACING NOW")
	elseif door == "closed" then
		local t = untilText(doorAt)
		if t then
			table.insert(items, "THE GRAND PRIX OPENS IN " .. t)
		end
	end
	local abuse = Workspace:GetAttribute("AbuseUntil")
	if type(abuse) == "number" and abuse > Workspace:GetServerTimeNow() then
		table.insert(items, "ADMIN ABUSE IS ON NOW")
	end
	local eventName = Workspace:GetAttribute("NextEventName")
	local eventIn = untilText(Workspace:GetAttribute("NextEventAt"))
	if type(eventName) == "string" and eventName ~= "" and eventIn then
		table.insert(items, string.upper(eventName) .. " IN " .. eventIn)
	end
	local season = Workspace:GetAttribute("SeasonName")
	if type(season) == "string" and season ~= "" then
		table.insert(items, string.upper(season) .. " SEASON")
	end
	table.insert(items, "STEAL A LUXE · THE MAISON BASEMENT · THE EXECUTIVE SUITE · THE GRAND AUCTION · LUXURY ISLAND")
	table.insert(items, "NEW · FLEX YOUR BRAINROTS FROM THE HOTBAR")
	return items
end

local function tween(o: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, repeats: number?, reverses: boolean?, delay: number?): Tween
	local t = game:GetService("TweenService"):Create(o, TweenInfo.new(seconds, style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut, repeats or 0, reverses or false, delay or 0), goal)
	t:Play()
	return t
end

local function click()
	pcall(function()
		require(script.Parent.Parent.Sound).play("click", 0.6)
	end)
end

-- A key that grows a touch under the pointer (or a controller's selection).
local function lift(b: GuiButton)
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local function to(v: number)
		tween(scale, 0.14, { Scale = v }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end
	b.MouseEnter:Connect(function()
		to(1.035)
	end)
	b.MouseLeave:Connect(function()
		to(1)
	end)
	b.SelectionGained:Connect(function()
		to(1.035)
	end)
	b.SelectionLost:Connect(function()
		to(1)
	end)
end

-- PLAY: gold, heavy, a neon edge that breathes and a shine that runs across it now and then.
local function playKey(parent: Instance, w: number, h: number, small: boolean, onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Key_Play"
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(w, h)
	b.BackgroundColor3 = Color3.new(1, 1, 1)
	b.ClipsDescendants = true
	b.Text = "PLAY"
	b.FontFace = Brand.Fonts.heavy
	b.TextSize = Theme.textSize(if small then 22 else 28, "display")
	b.TextColor3 = Color3.fromRGB(26, 16, 4)
	b.Selectable = true
	b.LayoutOrder = 1
	b.Parent = parent
	corner(b, 14)
	local gold = Instance.new("UIGradient")
	gold.Rotation = 90
	gold.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 186)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 196, 96)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(204, 140, 46)),
	})
	gold.Parent = b
	local edge = stroke(b, NEON, 2, 0.05)
	tween(edge, 1.1, { Thickness = 3.5, Transparency = 0.5 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	-- (The ▶ beside the word, drawn apart from it: the key's own text stays the one word.)
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.AnchorPoint = Vector2.new(0, 0.5)
	arrow.Position = UDim2.new(0.5, -(if small then 62 else 76), 0.5, 0)
	arrow.Size = UDim2.fromOffset(if small then 22 else 28, if small then 22 else 28)
	arrow.Text = "▶"
	arrow.FontFace = Brand.Fonts.heavy
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.fromRGB(26, 16, 4)
	arrow.Parent = b
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.AnchorPoint = Vector2.new(0.5, 0.5)
	shine.Position = UDim2.fromScale(-0.3, 0.5)
	shine.Size = UDim2.new(0, 46, 2, 0)
	shine.Rotation = 18
	shine.Parent = b
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
	fade.Parent = shine
	tween(shine, 1.2, { Position = UDim2.fromScale(1.3, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 2.6)
	lift(b)
	b.Activated:Connect(function()
		click()
		onPress()
	end)
	return b
end

-- A glass key with its icon: the Shop, How to play, the Leaderboard.
local function glassKey(parent: Instance, text: string, icon: string, accent: Color3, w: number, h: number, order: number, onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Key_" .. string.gsub(text, "%s", "")
	b.AutoButtonColor = false
	b.Size = UDim2.fromOffset(w, h)
	b.BackgroundColor3 = GRAPHITE
	b.BackgroundTransparency = 0.18
	b.Text = string.upper(text)
	b.FontFace = Brand.Fonts.bodyBold
	-- (Scaled to fit, never above its size: one line on any screen, clear of its icon.)
	b.TextScaled = true
	b.TextWrapped = false
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = Theme.textSize(if h < 44 then 12 else 14, "bodyBold")
	fit.MinTextSize = 7
	fit.Parent = b
	b.TextColor3 = C.bone
	b.Selectable = true
	b.LayoutOrder = order
	b.Parent = parent
	corner(b, 12)
	stroke(b, accent, 1.4, 0.35)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, h - 12)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, math.floor(h * 0.3))
	pad.PaddingBottom = UDim.new(0, math.floor(h * 0.3))
	pad.Parent = b
	if Icons.has(icon) then
		local holder = Instance.new("Frame")
		holder.Name = "IconHolder"
		holder.BackgroundTransparency = 1
		holder.AnchorPoint = Vector2.new(0, 0.5)
		holder.Position = UDim2.new(0, -(h - 20), 0.5, 0)
		holder.Size = UDim2.fromOffset(h - 22, h - 22)
		holder.Parent = b
		Icons.draw(holder, icon, accent, h - 22)
	end
	lift(b)
	b.Activated:Connect(function()
		click()
		onPress()
	end)
	return b
end

-- The screen the Home Screen is laid out for. Roblox reports a tiny viewport for a moment as a
-- client starts (1 by 1 in Studio), and a layout built for that has no room at all: the column
-- goes negative, the name hangs off the left and PLAY has no width. So a screen too small to be
-- real is taken as a usual one, and the layout is built again once the real size is known (and
-- whenever it changes: a window resized, a phone turned).
local function screen(): Vector2
	local size = Root.size()
	if size.X < 320 or size.Y < 240 then
		return Vector2.new(1280, 720) / math.max(Root.scale, 0.01)
	end
	return size
end

-- A small gold diamond: the ticker's separator (drawn, so it shows in every font).
local function diamond(parent: Instance, side: number, colour: Color3, order: number): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Sep"
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Size = UDim2.fromOffset(side + 6, side + 6)
	holder.Parent = parent
	local d = Instance.new("Frame")
	d.Name = "Diamond"
	d.BorderSizePixel = 0
	d.BackgroundColor3 = colour
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = UDim2.fromScale(0.5, 0.5)
	d.Size = UDim2.fromOffset(side, side)
	d.Rotation = 45
	d.Parent = holder
	return holder
end

-- The ticker along the foot, like a broadcast's: a LIVE plate on the left, then what's true in the
-- house right now running right to left between gold diamonds, fading in and out at the edges.
local function ticker(parent: Instance, small: boolean, height: number, isCurrent: () -> boolean): Frame
	local BAND = Color3.fromRGB(9, 9, 12)
	local band = Instance.new("Frame")
	band.Name = "Ticker"
	band.BorderSizePixel = 0
	band.BackgroundColor3 = BAND
	band.BackgroundTransparency = 0.04
	band.AnchorPoint = Vector2.new(0, 1)
	band.Position = UDim2.fromScale(0, 1)
	band.Size = UDim2.new(1, 0, 0, height)
	band.ClipsDescendants = true
	band.Parent = parent
	local depth = Instance.new("UIGradient")
	depth.Rotation = 90
	depth.Color = ColorSequence.new(Color3.fromRGB(28, 26, 30), BAND)
	depth.Parent = band
	-- A fine gold line along its top, brightest in the middle.
	local top = Instance.new("Frame")
	top.Name = "Hairline"
	top.BorderSizePixel = 0
	top.BackgroundColor3 = C.lightGold
	top.Size = UDim2.new(1, 0, 0, 1)
	top.ZIndex = 3
	top.Parent = band
	local topFade = Instance.new("UIGradient")
	topFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.7),
	})
	topFade.Parent = top

	-- LIVE: a neon plate with a breathing dot, its right edge cut to a point.
	local plateW = if small then 78 else 104
	local plate = Instance.new("Frame")
	plate.Name = "Live"
	plate.BorderSizePixel = 0
	plate.BackgroundColor3 = NEON
	plate.Size = UDim2.new(0, plateW, 1, 0)
	plate.ZIndex = 4
	plate.Parent = band
	local point = Instance.new("Frame")
	point.Name = "Point"
	point.BorderSizePixel = 0
	point.BackgroundColor3 = NEON
	point.AnchorPoint = Vector2.new(0.5, 0.5)
	point.Position = UDim2.new(1, 0, 0.5, 0)
	point.Size = UDim2.fromOffset(math.floor(height * 0.72), math.floor(height * 0.72))
	point.Rotation = 45
	point.ZIndex = 3
	point.Parent = plate
	local dotSide = if small then 7 else 9
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, if small then 12 else 16, 0.5, 0)
	dot.Size = UDim2.fromOffset(dotSide, dotSide)
	dot.ZIndex = 5
	dot.Parent = plate
	corner(dot, dotSide)
	tween(dot, 0.9, { BackgroundTransparency = 0.65 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local live = Instance.new("TextLabel")
	live.Name = "Word"
	live.BackgroundTransparency = 1
	live.AnchorPoint = Vector2.new(0, 0.5)
	live.Position = UDim2.new(0, (if small then 12 else 16) + dotSide + 7, 0.5, 0)
	live.Size = UDim2.new(1, -((if small then 12 else 16) + dotSide + 7), 0, height)
	live.FontFace = Brand.Fonts.heavy
	live.TextSize = Theme.textSize(if small then 12 else 15, "display")
	live.TextColor3 = Color3.new(1, 1, 1)
	live.TextXAlignment = Enum.TextXAlignment.Left
	live.Text = "LIVE"
	live.ZIndex = 5
	live.Parent = plate

	-- The track the news runs along, clipped, with soft edges.
	local gap = if small then 16 else 22
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.Position = UDim2.new(0, plateW + math.floor(height * 0.4) + 6, 0, 0)
	track.Size = UDim2.new(1, -(plateW + math.floor(height * 0.4) + 6), 1, 0)
	track.ClipsDescendants = true
	track.ZIndex = 2
	track.Parent = band
	local function edge(name: string, left: boolean, width: number)
		local f = Instance.new("Frame")
		f.Name = name
		f.BorderSizePixel = 0
		f.BackgroundColor3 = BAND
		f.AnchorPoint = Vector2.new(if left then 0 else 1, 0)
		f.Position = UDim2.fromScale(if left then 0 else 1, 0)
		f.Size = UDim2.new(0, width, 1, 0)
		f.ZIndex = 3
		f.Parent = track
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new(if left then 0 else 1, if left then 1 else 0)
		g.Parent = f
	end
	edge("FadeIn", true, 28)
	edge("FadeOut", false, 64)
	local run = Instance.new("Frame")
	run.Name = "News"
	run.BackgroundTransparency = 1
	run.AutomaticSize = Enum.AutomaticSize.X
	run.Size = UDim2.new(0, 0, 1, 0)
	run.ZIndex = 2
	run.Parent = track
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, gap)
	list.Parent = run
	local textSize = if small then 12 else 14
	local sepSide = if small then 5 else 6
	local running: Tween? = nil
	local function fill()
		for _, child in run:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		local items = Title.tickerItems()
		local order = 0
		local width = 0
		-- (Twice over, so the second run follows the first with no seam.)
		for copy = 1, 2 do
			for _, item in items do
				order += 1
				local label = Instance.new("TextLabel")
				label.Name = "Item"
				label.BackgroundTransparency = 1
				label.LayoutOrder = order
				label.FontFace = Brand.Fonts.bodyBold
				label.TextSize = Theme.textSize(textSize, "bodyBold")
				label.TextColor3 = C.bone
				label.Text = item
				local w = math.ceil(Theme.measureAs(item, textSize, "bodyBold").X) + 4
				label.Size = UDim2.new(0, w, 1, 0)
				label.ZIndex = 2
				label.Parent = run
				order += 1
				diamond(run, sepSide, C.lightGold, order).ZIndex = 2
				if copy == 1 then
					width += w + (sepSide + 6) + gap * 2
				end
			end
		end
		if running then
			running:Cancel()
		end
		run.Position = UDim2.new(0, 0, 0, 0)
		-- (A steady 60 pixels a second, however much there is to say.)
		running = tween(run, math.max(10, width / 60), { Position = UDim2.new(0, -width, 0, 0) }, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1)
	end
	fill()
	task.spawn(function()
		while isCurrent() and band.Parent do
			task.wait(20)
			if isCurrent() and band.Parent then
				fill()
			end
		end
	end)
	return band
end

function Title.show(choices: Choices)
	if current then
		return
	end
	local player = Players.LocalPlayer
	local frame = Instance.new("Frame")
	frame.Name = "Title"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = Root.hud
	current = frame
	tourId += 1
	local id = tourId
	local function isCurrent(): boolean
		return current == frame and tourId == id
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

	-- What the camera is showing (the walk sets these; each layout makes its own labels).
	local roomName: TextLabel? = nil
	local roomLine: TextLabel? = nil
	local nowName, nowLine = "", ""
	local play: TextButton? = nil
	local builtFor = Vector2.zero

	local function build(fadeIn: boolean)
		local old = frame:FindFirstChild("Layout")
		if old then
			old:Destroy()
		end
		for _, c in connections do
			c:Disconnect()
		end
		table.clear(connections)
		local size = screen()
		builtFor = size
		local small = size.Y < 520 or size.X < 760
		local tickerH = if small then 34 else 44
		local layout = Instance.new("Frame")
		layout.Name = "Layout"
		layout.BackgroundTransparency = 1
		layout.Size = UDim2.fromScale(1, 1)
		layout.Parent = frame

		-- The house's rooms behind it all: deep shade on the left so the words read, and along the foot.
		local shade = Instance.new("Frame")
		shade.Name = "Shade"
		shade.BorderSizePixel = 0
		shade.BackgroundColor3 = C.nearBlack
		shade.Size = UDim2.fromScale(1, 1)
		shade.BackgroundTransparency = 0
		shade.ZIndex = 1
		shade.Parent = layout
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(if small then 0.64 else 0.48, 0.5),
			NumberSequenceKeypoint.new(1, 0.94),
		})
		g.Parent = shade
		local foot = Instance.new("Frame")
		foot.Name = "FootShade"
		foot.BorderSizePixel = 0
		foot.BackgroundColor3 = C.nearBlack
		foot.AnchorPoint = Vector2.new(0, 1)
		foot.Position = UDim2.fromScale(0, 1)
		foot.Size = UDim2.new(1, 0, 0.3, 0)
		foot.ZIndex = 1
		foot.Parent = layout
		local footFade = Instance.new("UIGradient")
		footFade.Rotation = 90
		footFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.25) })
		footFade.Parent = foot

		-- The column: welcome, the name, the line, the guest's own figures, the keys, the season.
		local left = if small then 28 else math.clamp(math.floor(size.X * 0.06), 48, 96)
		local width = math.clamp(math.floor(size.X - left * 2), 260, if small then 420 else 560)
		local column = Instance.new("Frame")
		column.Name = "Column"
		column.BackgroundTransparency = 1
		column.AnchorPoint = Vector2.new(0, 0.5)
		column.Position = UDim2.new(0, left, 0.5, -tickerH // 2)
		column.Size = UDim2.fromOffset(width, 0)
		column.AutomaticSize = Enum.AutomaticSize.Y
		column.ZIndex = 2
		column.Parent = layout
		local list = Theme.list(column, if small then 8 else 12)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Left

		-- A neon edge down the column's side: the street's own light.
		local edge = Instance.new("Frame")
		edge.Name = "NeonEdge"
		edge.BorderSizePixel = 0
		edge.BackgroundColor3 = NEON
		edge.AnchorPoint = Vector2.new(1, 0.5)
		edge.Position = UDim2.new(0, left - (if small then 12 else 28), 0.5, -tickerH // 2)
		edge.Size = UDim2.new(0, 3, 0, if small then 260 else 430)
		edge.ZIndex = 2
		edge.Parent = layout
		local edgeFade = Instance.new("UIGradient")
		edgeFade.Rotation = 90
		edgeFade.Color = ColorSequence.new(NEON, ICE)
		edgeFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		edgeFade.Parent = edge

		-- WELCOME TO, in a small neon tag.
		local tag = Instance.new("Frame")
		tag.Name = "WelcomeTag"
		tag.LayoutOrder = 1
		tag.BackgroundColor3 = GRAPHITE
		tag.BackgroundTransparency = 0.1
		tag.Size = UDim2.fromOffset(if small then 118 else 138, if small then 22 else 26)
		tag.Parent = column
		corner(tag, 13)
		stroke(tag, NEON, 1.2, 0.2)
		local welcome = Theme.text(tag, "WELCOME TO", if small then 11 else 12, "caps", {
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = ICE,
			TextWrapped = false,
		})
		welcome.Name = "Welcome"

		-- The name, stacked and heavy, in gold that catches the light now and then.
		local nameSize = math.floor(math.max(30, math.min(if small then 54 else 80, width / 5.6, size.Y * 0.11)))
		local name = Theme.text(column, "MAISON\nNOIR", nameSize, "display", { LayoutOrder = 2, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, LineHeight = 0.88 })
		name.Name = "Name"
		local sheen = Instance.new("UIGradient")
		sheen.Rotation = 90
		sheen.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 246, 214)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 206, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 140, 56)),
		})
		sheen.Parent = name
		-- (One gradient per label in Roblox: the glint runs over a second, bright copy of the name.)
		local shimmer = name:Clone()
		shimmer.Name = "NameGlint"
		for _, child in shimmer:GetChildren() do
			child:Destroy()
		end
		shimmer.TextColor3 = Color3.new(1, 1, 1)
		shimmer.BackgroundTransparency = 1
		shimmer.Position = UDim2.fromOffset(0, 0)
		shimmer.Size = UDim2.fromScale(1, 1)
		shimmer.AutomaticSize = Enum.AutomaticSize.None
		shimmer.LayoutOrder = 0
		shimmer.Parent = name
		local glint = Instance.new("UIGradient")
		glint.Rotation = 20
		glint.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.44, 1),
			NumberSequenceKeypoint.new(0.5, 0.35),
			NumberSequenceKeypoint.new(0.56, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		glint.Offset = Vector2.new(-1, 0)
		glint.Parent = shimmer
		tween(glint, 1.6, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 3)
		local underline = Instance.new("Frame")
		underline.Name = "Underline"
		underline.LayoutOrder = 3
		underline.BorderSizePixel = 0
		underline.BackgroundColor3 = Color3.new(1, 1, 1)
		underline.Size = UDim2.fromOffset(if small then 96 else 140, 4)
		underline.Parent = column
		corner(underline, 2)
		local underlineColour = Instance.new("UIGradient")
		underlineColour.Color = ColorSequence.new(NEON, ICE)
		underlineColour.Parent = underline
		Theme.text(column, Brand.Tagline, if small then 14 else 18, "italic", { LayoutOrder = 4, TextColor3 = C.bone, TextXAlignment = Enum.TextXAlignment.Left })

		-- The guest's own Gilt, Gems and level, live.
		local chips = Instance.new("Frame")
		chips.Name = "Purse"
		chips.BackgroundTransparency = 1
		chips.LayoutOrder = 5
		chips.Size = UDim2.new(1, 0, 0, if small then 30 else 38)
		chips.Parent = column
		Theme.list(chips, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
		local h = if small then 30 else 38
		local gilt = chip(chips, "Gilt", "gilt", C.lightGold, if small then 122 else 156, h, 1)
		local gems = chip(chips, "Gems", "gems", ICE, if small then 96 else 118, h, 2)
		local level = chip(chips, "Level", "crown", NEON, if small then 84 else 102, h, 3)
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

		-- The keys: PLAY, big and gold; the Shop, How to play and the Leaderboard under it, alike.
		local keys = Instance.new("Frame")
		keys.Name = "Keys"
		keys.BackgroundTransparency = 1
		keys.AutomaticSize = Enum.AutomaticSize.Y
		keys.Size = UDim2.new(1, 0, 0, 0)
		keys.LayoutOrder = 6
		keys.Parent = column
		local keyList = Theme.list(keys, if small then 8 else 10)
		keyList.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local rowW = math.min(width, if small then 390 else 500)
		play = playKey(keys, rowW, if small then 54 else 70, small, choices.play)
		local row = Instance.new("Frame")
		row.Name = "More"
		row.BackgroundTransparency = 1
		row.LayoutOrder = 2
		row.Size = UDim2.new(0, rowW, 0, if small then 40 else 48)
		row.Parent = keys
		Theme.list(row, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
		local each = math.floor((rowW - 16) / 3)
		local keyH = if small then 40 else 48
		if choices.shop then
			glassKey(row, "Shop", "bag", NEON, each, keyH, 1, choices.shop)
		end
		glassKey(row, "How to play", "help", ICE, each, keyH, 2, choices.how)
		glassKey(row, "Leaderboard", "badge", C.lightGold, each, keyH, 3, choices.board)

		-- The season, and a Private Evening, in small tags.
		local tags = Instance.new("Frame")
		tags.Name = "Tags"
		tags.BackgroundTransparency = 1
		tags.LayoutOrder = 7
		tags.Size = UDim2.new(1, 0, 0, if small then 22 else 26)
		tags.Parent = column
		Theme.list(tags, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Left
		local function smallTag(text: string, colour: Color3, order: number)
			local w = math.ceil(Theme.measureAs(text, if small then 10 else 11, "caps").X) + 26
			local t = Instance.new("Frame")
			t.Name = "Tag"
			t.LayoutOrder = order
			t.BackgroundColor3 = GRAPHITE
			t.BackgroundTransparency = 0.25
			t.Size = UDim2.fromOffset(w, if small then 22 else 26)
			t.Parent = tags
			corner(t, 13)
			stroke(t, colour, 1, 0.45)
			Theme.text(t, text, if small then 10 else 11, "caps", { AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromScale(1, 1), TextColor3 = colour, TextWrapped = false })
		end
		local seasonName = tostring(Workspace:GetAttribute("SeasonName") or "")
		if seasonName ~= "" then
			smallTag(seasonName .. " season", C.lightGold, 1)
		end
		if Workspace:GetAttribute("PrivateEvening") == true then
			smallTag(Voice.Private.title, ICE, 2)
		end

		-- What the camera is showing: the room's name, and a line about it.
		local caption = Instance.new("Frame")
		caption.Name = "NowShowing"
		caption.BackgroundColor3 = GRAPHITE
		caption.BackgroundTransparency = 0.2
		caption.AnchorPoint = Vector2.new(1, 1)
		caption.Position = UDim2.new(1, -18, 1, -(tickerH + 14))
		caption.Size = UDim2.fromOffset(if small then 300 else 400, if small then 58 else 72)
		-- (Only where it can't sit over the column.)
		caption.Visible = size.X >= left + width + 24 + (if small then 300 else 400)
		caption.ZIndex = 2
		caption.Parent = layout
		corner(caption, 10)
		stroke(caption, NEON, 1.2, 0.3)
		local kicker = Instance.new("TextLabel")
		kicker.Name = "Kicker"
		kicker.BackgroundTransparency = 1
		kicker.Position = UDim2.fromOffset(14, 7)
		kicker.Size = UDim2.new(1, -28, 0, if small then 11 else 12)
		kicker.FontFace = Brand.Fonts.bodyBold
		kicker.TextScaled = true
		kicker.TextXAlignment = Enum.TextXAlignment.Left
		kicker.TextColor3 = NEON
		kicker.Text = "NOW SHOWING"
		kicker.Parent = caption
		local room = Instance.new("TextLabel")
		room.Name = "Room"
		room.BackgroundTransparency = 1
		room.Position = UDim2.fromOffset(14, if small then 20 else 22)
		room.Size = UDim2.new(1, -28, 0, if small then 18 else 22)
		room.FontFace = Brand.Fonts.display
		room.TextScaled = true
		room.TextXAlignment = Enum.TextXAlignment.Left
		room.TextColor3 = C.bone
		room.Text = nowName
		room.Parent = caption
		local line = Instance.new("TextLabel")
		line.Name = "Line"
		line.BackgroundTransparency = 1
		line.Position = UDim2.new(0, 14, 0, if small then 40 else 48)
		line.Size = UDim2.new(1, -28, 0, if small then 12 else 15)
		line.FontFace = Brand.Fonts.body
		line.TextScaled = true
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = C.smoke
		line.Text = nowLine
		line.Parent = caption
		roomName, roomLine = room, line

		-- The AJKR mark, top right.
		if not small then
			local mark = Instance.new("Frame")
			mark.Name = "Mark"
			mark.BackgroundTransparency = 1
			mark.AnchorPoint = Vector2.new(1, 0)
			mark.Position = UDim2.new(1, -22, 0, 18)
			mark.Size = UDim2.fromOffset(120, 44)
			mark.ZIndex = 2
			mark.Parent = layout
			local markList = Theme.list(mark, 3)
			markList.HorizontalAlignment = Enum.HorizontalAlignment.Right
			Theme.text(mark, Brand.Owner, 14, "display", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.lightGold })
			Theme.hairline(mark, UDim.new(0, 40), 2)
			Theme.text(mark, "© " .. Brand.year(), 11, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = C.dim })
		end

		ticker(layout, small, tickerH, isCurrent).ZIndex = 2

		-- In: the column fades up; PLAY lands last with a little bounce (only the first time).
		if fadeIn then
			for _, d in column:GetDescendants() do
				if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Name ~= "NameGlint" then
					local text = d :: any
					local goal = text.TextTransparency
					text.TextTransparency = 1
					Ease.play(d, Ease.info(0.9, Enum.EasingStyle.Sine), { TextTransparency = goal })
				end
			end
			local pop = play and play:FindFirstChildOfClass("UIScale")
			if pop then
				pop.Scale = 0.86
				tween(pop, 0.55, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.35)
			end
		end
		-- A controller starts on Play.
		task.defer(function()
			if play and isCurrent() then
				Theme.select(play)
			end
		end)
	end
	build(true)

	-- Laid out again when the screen's real size arrives, or changes.
	task.spawn(function()
		while isCurrent() do
			task.wait(0.5)
			if not isCurrent() then
				return
			end
			local now = screen()
			if math.abs(now.X - builtFor.X) > 12 or math.abs(now.Y - builtFor.Y) > 12 then
				build(false)
			end
		end
	end)

	-- The walk through the house: Play's room first, every room asked for ahead.
	local shots = Title.shots()
	streamAround(Layout.Foyer.spawn.Position)
	for _, s in shots do
		streamAround(s.at)
	end
	local function showShot(s: Shot)
		pcall(CameraRig.tour, s.from, s.to, s.seconds)
		nowName, nowLine = s.name, s.line
		if roomName then
			roomName.Text = s.name
		end
		if roomLine then
			roomLine.Text = s.line
		end
	end
	showShot(shots[1])
	Ease.play(curtain, Ease.info(0.8, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
	task.spawn(function()
		local i = 1
		while isCurrent() do
			task.wait(math.max(1, shots[i].seconds - 0.45))
			if not isCurrent() then
				return
			end
			-- (A cut through black: the curtain closes, the camera moves on, the curtain opens.)
			Ease.play(curtain, Ease.info(0.35, Enum.EasingStyle.Sine), { BackgroundTransparency = 0 })
			task.wait(0.4)
			if not isCurrent() then
				return
			end
			i = i % #shots + 1
			showShot(shots[i])
			Ease.play(curtain, Ease.info(0.5, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
		end
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

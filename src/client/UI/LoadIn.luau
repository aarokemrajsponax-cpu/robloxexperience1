--!strict
-- Arriving at Steal a Luxe, the Maison Basement or the Executive Suite (Build 82): the server holds
-- the guest still for a few seconds (their root anchored) while this screen makes the place ready,
-- and lets them go once the few seconds are up and this screen has said it's ready (or at most a
-- little later, so nobody waits for ever). What's waited for is real: the place's own model on this
-- screen, and its textures, meshes and sounds (ContentProvider). Shown meanwhile: the place's
-- name, a line about it, a tip worth knowing before the first step, and each thing as it's ready.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Controls = require(script.Parent.Parent.Controls)
local Root = require(script.Parent.Root)

local LoadIn = {}

local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local GREEN = Color3.fromRGB(120, 220, 150)
local NAME = "MaisonLoadIn"

-- A tip for each, before the first step.
LoadIn.TIPS = {
	luxe = "Security sleeps until you lift something. Then a guard comes after you: get to a way out.",
	basement = "Fall, and you're back at your last checkpoint. The run-ups grow longer the deeper you go.",
	executive = "Read the four terminals for the door's code, and stay out of the red light.",
} :: { [string]: string }

local shown: { [string]: any }? = nil

local function label(parent: Instance, name: string, text: string, size: number, font: Font, colour: Color3, y: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(1, 0, 0, size + 8)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = text
	l.TextWrapped = true
	l.ZIndex = 61
	l.Parent = parent
	return l
end

-- The place's own model on this screen (each is tagged with its id), if it's there yet.
local function placeModel(id: string): Instance?
	local folder = Workspace:FindFirstChild("Attractions")
	if not folder then
		return nil
	end
	for _, m in folder:GetChildren() do
		if m:GetAttribute("Attraction") == id then
			return m
		end
	end
	return nil
end

local function step(row: Frame?, done: boolean)
	if not row then
		return
	end
	local dot = row:FindFirstChild("Dot") :: Frame?
	local text = row:FindFirstChild("Text") :: TextLabel?
	if dot then
		dot.BackgroundColor3 = if done then GREEN else Color3.fromRGB(90, 84, 74)
	end
	if text then
		text.TextColor3 = if done then C.bone else C.smoke
	end
end

-- (Build 87) Each place's own loading screen: its colours, its pattern and its words, on a screen
-- of its own that covers the house's keys (they were showing through before). Steal a Luxe: velvet
-- crimson, security lasers sweeping across and a vault dial; the Basement: dark green stone, copper
-- courses of brick and gold chevrons going down; the Executive Suite: midnight blue, a blueprint
-- grid, a scanning line and the four lights of the door's code lighting as it loads.
type Theme = { top: Color3, bottom: Color3, accent: Color3, tag: string, motif: string }
LoadIn.THEMES = {
	luxe = { top = Color3.fromRGB(46, 8, 20), bottom = Color3.fromRGB(8, 3, 6), accent = Color3.fromRGB(255, 92, 124), tag = "THE HEIST", motif = "lasers" },
	basement = { top = Color3.fromRGB(10, 32, 32), bottom = Color3.fromRGB(3, 9, 10), accent = Color3.fromRGB(226, 152, 92), tag = "SIXTEEN STAGES DOWN", motif = "bricks" },
	executive = { top = Color3.fromRGB(10, 20, 46), bottom = Color3.fromRGB(2, 4, 12), accent = Color3.fromRGB(110, 200, 255), tag = "BY INVITATION ONLY", motif = "grid" },
} :: { [string]: Theme }
local PLAIN: Theme = { top = Color3.fromRGB(28, 22, 14), bottom = Color3.fromRGB(6, 5, 4), accent = GOLD, tag = "", motif = "" }

local function line(parent: Instance, x: number, y: number, w: number, h: number, colour: Color3, t: number, rot: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = t
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.Rotation = rot or 0
	f.ZIndex = 60
	f.Parent = parent
	return f
end

-- The pattern behind the words, and what moves in it (called each frame with the time and the
-- progress, 0 to 1).
local function motif(layer: Frame, theme: Theme, size: Vector2): (t: number, f: number) -> ()
	local W, H = size.X, size.Y
	local a = theme.accent
	if theme.motif == "lasers" then
		local beams = {}
		for i = 1, 7 do
			local b = line(layer, W * (i / 8), H / 2, 2, H * 1.6, a, 0.55, -28 + i * 9)
			table.insert(beams, b)
		end
		-- The vault dial, faint, on the right.
		local dial = Instance.new("Frame")
		dial.Name = "Dial"
		dial.AnchorPoint = Vector2.new(0.5, 0.5)
		dial.Position = UDim2.fromOffset(W * 0.82, H * 0.5)
		local d = math.floor(math.min(W, H) * 0.62)
		dial.Size = UDim2.fromOffset(d, d)
		dial.BackgroundTransparency = 1
		dial.ZIndex = 60
		dial.Parent = layer
		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Parent = dial
		local ds = Instance.new("UIStroke")
		ds.Color = GOLD
		ds.Thickness = 6
		ds.Transparency = 0.82
		ds.Parent = dial
		for k = 0, 11 do
			local n = line(dial, d / 2, d / 2, 4, d * 0.92, GOLD, 0.86, k * 15)
			n.ZIndex = 60
		end
		return function(t: number, _f: number)
			for i, b in beams do
				b.Rotation = -28 + i * 9 + math.sin(t * 0.7 + i) * 6
				b.BackgroundTransparency = 0.5 + 0.3 * (0.5 + 0.5 * math.sin(t * 2 + i * 1.3))
			end
			dial.Rotation = t * 12
		end
	elseif theme.motif == "bricks" then
		local rowH = 40
		local rows = math.ceil(H / rowH) + 1
		for r = 0, rows do
			line(layer, W / 2, r * rowH, W, 2, a, 0.86)
			local shift = if r % 2 == 0 then 0 else 60
			for x = shift, W, 120 do
				line(layer, x, r * rowH + rowH / 2, 2, rowH, a, 0.9)
			end
		end
		-- Gold chevrons, going down, on the right.
		local chevrons = {}
		for k = 1, 5 do
			local y = H * 0.24 + k * 46
			local l1 = line(layer, W * 0.86 - 13, y, 34, 6, GOLD, 0.4, 35)
			local l2 = line(layer, W * 0.86 + 13, y, 34, 6, GOLD, 0.4, -35)
			table.insert(chevrons, { l1, l2 })
		end
		return function(t: number, _f: number)
			for k, pair in chevrons do
				local glow = 0.15 + 0.7 * (0.5 - 0.5 * math.sin(t * 4 - k * 0.9))
				pair[1].BackgroundTransparency = glow
				pair[2].BackgroundTransparency = glow
			end
		end
	elseif theme.motif == "grid" then
		for x = 0, W, 48 do
			line(layer, x, H / 2, 1, H, a, 0.88)
		end
		for y = 0, H, 48 do
			line(layer, W / 2, y, W, 1, a, 0.88)
		end
		local scan = line(layer, W / 2, 0, W, 3, a, 0.35)
		-- The door's four code lights, lighting as the Suite loads.
		local lights = {}
		for k = 1, 4 do
			local box = line(layer, W * 0.82 + (k - 2.5) * 46, H * 0.5, 36, 48, Color3.fromRGB(8, 14, 30), 0.1)
			local s = Instance.new("UIStroke")
			s.Color = a
			s.Thickness = 2
			s.Transparency = 0.3
			s.Parent = box
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = box
			local dot = line(box, 18, 24, 12, 12, a, 0.85)
			local dc = Instance.new("UICorner")
			dc.CornerRadius = UDim.new(1, 0)
			dc.Parent = dot
			table.insert(lights, dot)
		end
		return function(t: number, f: number)
			scan.Position = UDim2.fromOffset(W / 2, (t * 140) % H)
			for k, dot in lights do
				dot.BackgroundTransparency = if f >= k / 4.4 then 0 else 0.85
			end
		end
	end
	return function(_t: number, _f: number) end
end

-- Shows the card for `id` and starts making the place ready. `seconds`: the least the server holds.
-- `after`: what to do once the guest can move (the first-visit card, a line).
function LoadIn.start(id: string, seconds: number, after: (() -> ())?)
	LoadIn.finish(true)
	local def = AttractionList.byId[id]
	local size = Root.size()
	local wasControls = Controls.wanted()
	Controls.set(false)
	local theme = LoadIn.THEMES[id] or PLAIN

	-- The whole screen, the place's own colours, over everything of the house's.
	local shade = Instance.new("Frame")
	shade.Name = NAME
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(1, 1, 1)
	shade.BackgroundTransparency = 0
	shade.BorderSizePixel = 0
	shade.ZIndex = 60
	shade.Active = true
	shade.Parent = Root.hud
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Color = ColorSequence.new(theme.top, theme.bottom)
	fade.Parent = shade
	local layer = Instance.new("Frame")
	layer.Name = "Motif"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ClipsDescendants = true
	layer.ZIndex = 60
	layer.Parent = shade
	local moving = motif(layer, theme, size)

	-- The words, on the left of the middle: what's coming, the name, the line.
	local narrow = size.X < 700
	local w = math.min(520, math.max(260, size.X - 48))
	local col = Instance.new("Frame")
	col.Name = "Column"
	col.AnchorPoint = Vector2.new(if narrow then 0.5 else 0, 0.5)
	col.Position = if narrow then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, math.max(32, size.X * 0.08), 0.5, 0)
	col.Size = UDim2.fromOffset(w, 300)
	col.BackgroundTransparency = 1
	col.ZIndex = 61
	col.Parent = shade
	local align = if narrow then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	local kicker = label(col, "Kicker", "NOW ENTERING" .. (if theme.tag ~= "" then "  ·  " .. theme.tag else ""), 12, Brand.Fonts.heavy, theme.accent, 0)
	kicker.TextXAlignment = align
	local titleSize = math.clamp(math.floor(w / math.max(8, #(if def then def.name else "")) * 1.5), 30, 52)
	local title = label(col, "Title", string.upper(if def then def.name else ""), titleSize, Brand.Fonts.display, C.bone, 20)
	title.TextScaled = false
	title.TextXAlignment = align
	local bar = Instance.new("Frame")
	bar.Name = "Rule"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = theme.accent
	bar.AnchorPoint = Vector2.new(if narrow then 0.5 else 0, 0)
	bar.Position = UDim2.new(if narrow then 0.5 else 0, 0, 0, 30 + titleSize)
	bar.Size = UDim2.fromOffset(64, 3)
	bar.ZIndex = 61
	bar.Parent = col
	local lineLabel = label(col, "Line", if def then def.line else "", 15, Brand.Fonts.body, Color3.fromRGB(226, 218, 204), 42 + titleSize)
	lineLabel.Size = UDim2.new(1, 0, 0, 42)
	lineLabel.TextXAlignment = align
	local top = 92 + titleSize

	-- The progress: a line in the place's colour filling over the hold.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(if narrow then 0.5 else 0, 0)
	track.Position = UDim2.new(if narrow then 0.5 else 0, 0, 0, top)
	track.Size = UDim2.new(1, 0, 0, 6)
	track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	track.BackgroundTransparency = 0.88
	track.BorderSizePixel = 0
	track.ZIndex = 61
	track.Parent = col
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(1, 0)
	tc.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = theme.accent
	fill.BorderSizePixel = 0
	fill.ZIndex = 62
	fill.Parent = track
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill

	-- What's being made ready, each lit as it is, side by side.
	local rows: { [string]: Frame } = {}
	for i, spec in { { "rooms", "The rooms" }, { "assets", "Textures and sounds" }, { "ready", "Your way in" } } do
		local row = Instance.new("Frame")
		row.Name = "Step_" .. spec[1]
		row.BackgroundTransparency = 1
		row.Position = UDim2.new((i - 1) / 3, 0, 0, top + 16)
		row.Size = UDim2.new(1 / 3, -6, 0, 18)
		row.ZIndex = 61
		row.Parent = col
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 0, 0.5, 0)
		dot.Size = UDim2.fromOffset(8, 8)
		dot.BorderSizePixel = 0
		dot.ZIndex = 62
		dot.Parent = row
		local dc = Instance.new("UICorner")
		dc.CornerRadius = UDim.new(1, 0)
		dc.Parent = dot
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Position = UDim2.fromOffset(14, 0)
		text.Size = UDim2.new(1, -14, 1, 0)
		text.FontFace = Brand.Fonts.bodyBold
		text.TextSize = 12
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextTruncate = Enum.TextTruncate.AtEnd
		text.Text = spec[2]
		text.ZIndex = 62
		text.Parent = row
		rows[spec[1]] = row
		step(row, false)
	end
	local tip = LoadIn.TIPS[id]
	if tip then
		-- A tip in a box with the place's colour down its side.
		local box = Instance.new("Frame")
		box.Name = "TipBox"
		box.Position = UDim2.fromOffset(0, top + 48)
		box.Size = UDim2.new(1, 0, 0, 0)
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		box.BackgroundTransparency = 0.45
		box.BorderSizePixel = 0
		box.ZIndex = 61
		box.Parent = col
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 10)
		bc.Parent = box
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 12)
		pad.PaddingTop = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 10)
		pad.Parent = box
		local stack = Instance.new("UIListLayout")
		stack.Padding = UDim.new(0, 4)
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = box
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = theme.accent
		edge.Transparency = 0.55
		edge.Parent = box
		local head = label(box, "TipHead", "BEFORE YOU GO IN", 11, Brand.Fonts.heavy, theme.accent, 0)
		head.LayoutOrder = 1
		head.Size = UDim2.new(1, 0, 0, 14)
		head.TextXAlignment = Enum.TextXAlignment.Left
		local tl = label(box, "Tip", tip, 13, Brand.Fonts.bodyBold, C.bone, 0)
		tl.LayoutOrder = 2
		tl.Size = UDim2.new(1, 0, 0, 0)
		tl.AutomaticSize = Enum.AutomaticSize.Y
		tl.TextXAlignment = Enum.TextXAlignment.Left
	end
	-- The house's name, small, at the foot.
	local mark = label(shade, "Brand", string.upper(Brand.Title), 11, Brand.Fonts.heavy, Color3.fromRGB(200, 186, 160), size.Y - 30)
	mark.TextTransparency = 0.3

	local state: { [string]: any } = { id = id, shade = shade, fill = fill, rows = rows, from = os.clock(), seconds = math.max(0.5, seconds), after = after, controls = wasControls, ready = false }
	shown = state

	-- The progress line, kept up to the moment (it waits short of the end until the server lets go),
	-- and the place's pattern moving behind it.
	state.beat = RunService.Heartbeat:Connect(function()
		local f = math.clamp((os.clock() - state.from) / state.seconds, 0, 0.96)
		fill.Size = UDim2.fromScale(f, 1)
		pcall(moving, os.clock() - state.from, f)
	end)

	-- Make the place ready: its model on this screen, then its assets; then say so to the server.
	task.spawn(function()
		local model: Instance? = nil
		local deadline = os.clock() + 12
		while shown == state and os.clock() < deadline do
			model = placeModel(id)
			if model then
				break
			end
			task.wait(0.2)
		end
		if shown ~= state then
			return
		end
		step(rows.rooms, model ~= nil)
		if model then
			local done = false
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync({ model })
				end)
				done = true
			end)
			local until_ = os.clock() + 8
			while not done and shown == state and os.clock() < until_ do
				task.wait(0.1)
			end
		end
		if shown ~= state then
			return
		end
		step(rows.assets, true)
		state.ready = true
		pcall(function()
			Remotes.func("AttractionAsk"):InvokeServer({ op = "ready", id = id })
		end)
	end)
end

-- The server let go: the card fills, fades, and the guest can move. `quiet`: just put it away.
function LoadIn.finish(quiet: boolean?)
	local state = shown
	if not state then
		return
	end
	shown = nil
	if state.beat then
		state.beat:Disconnect()
	end
	Controls.set(state.controls ~= false)
	local shade = state.shade :: Frame
	if quiet then
		shade:Destroy()
		return
	end
	step(state.rows.rooms, true)
	step(state.rows.assets, true)
	step(state.rows.ready, true)
	state.fill.Size = UDim2.fromScale(1, 1)
	Ease.play(shade, Ease.info(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	for _, d in shade:GetDescendants() do
		if d:IsA("TextLabel") then
			Ease.play(d, Ease.info(0.45, Enum.EasingStyle.Quad), { TextTransparency = 1 })
		elseif d:IsA("Frame") then
			Ease.play(d, Ease.info(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		end
	end
	task.delay(0.5, function()
		shade:Destroy()
	end)
	local after = state.after
	if after then
		task.delay(0.5, after)
	end
end

function LoadIn.active(): boolean
	return shown ~= nil
end

return LoadIn

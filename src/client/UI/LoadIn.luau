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
local Skyline = require(ReplicatedStorage.Shared.Skyline)
local Toast = require(script.Parent.Toast)

local LoadIn = {}

local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local GREEN = Color3.fromRGB(120, 220, 150)
local NAME = "MaisonLoadIn"

-- (Build 88) What it does for the guest's Fortune: the one aim of the whole house.
LoadIn.FORTUNE = {
	luxe = "Every piece shows its exact Gilt reward. Bank it at the getaway car and exactly that is added to your Gilt.",
	basement = "Every checkpoint shows its exact Gilt reward before you reach it, and pays exactly that.",
	executive = "Beat him for the biggest prize in the house, and watch your Fortune leap.",
} :: { [string]: string }

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

-- (Build 87) Each place's own loading screen: its colours and its words, on a screen of its own
-- that covers the house's keys. (Build 102: the whole screen, the house at night in the place's
-- own colours, Shared/Skyline; `top`, `bottom` and `motif` are no longer drawn.)
type Theme = { top: Color3, bottom: Color3, accent: Color3, tag: string, motif: string }
LoadIn.THEMES = {
	luxe = { top = Color3.fromRGB(46, 8, 20), bottom = Color3.fromRGB(8, 3, 6), accent = Color3.fromRGB(255, 92, 124), tag = "THE HEIST", motif = "lasers" },
	basement = { top = Color3.fromRGB(10, 32, 32), bottom = Color3.fromRGB(3, 9, 10), accent = Color3.fromRGB(226, 152, 92), tag = "THIRTY-TWO STAGES DOWN", motif = "bricks" },
	executive = { top = Color3.fromRGB(10, 20, 46), bottom = Color3.fromRGB(2, 4, 12), accent = Color3.fromRGB(110, 200, 255), tag = "BY INVITATION ONLY", motif = "grid" },
} :: { [string]: Theme }
local PLAIN: Theme = { top = Color3.fromRGB(28, 22, 14), bottom = Color3.fromRGB(6, 5, 4), accent = GOLD, tag = "", motif = "" }

-- Shows the card for `id` and starts making the place ready. `seconds`: the least the server holds.
-- `after`: what to do once the guest can move (the first-visit card, a line).
function LoadIn.start(id: string, seconds: number, after: (() -> ())?)
	LoadIn.finish(true)
	-- (Build 102) Notices wait until it's gone (they showed over it before).
	Toast.hold(true)
	local def = AttractionList.byId[id]
	local size = Root.size()
	local wasControls = Controls.wanted()
	Controls.set(false)
	local theme = LoadIn.THEMES[id] or PLAIN

	-- (Build 102) The whole screen, truly: a layer of its own over everything (Roblox's top bar
	-- and the phone's notch included), not the HUD's scaled layer, where a "full screen" frame came
	-- out as a smaller card. The background fills it at any shape of screen; the words and the
	-- pattern sit on a stage scaled like the rest of the house's lettering, centred, never stretched.
	local gui = Instance.new("ScreenGui")
	gui.Name = "MaisonLoadScreen"
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.None
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 95
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = Root.hud.Parent
	local shade = Instance.new("Frame")
	shade.Name = NAME
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 4, 12)
	shade.BackgroundTransparency = 0
	shade.BorderSizePixel = 0
	shade.ZIndex = 60
	shade.Active = true
	shade.Parent = gui
	-- (Build 102) The house at night in the place's own colours, edge to edge in the screen's real
	-- pixels (Shared/Skyline): searchlights, the lit facade, its reflection in the marble and gold
	-- dust, all moving gently while it loads. Less of it on a phone.
	local camera = Workspace.CurrentCamera
	local pixels = if camera then camera.ViewportSize else size * Root.scale
	local scene = Skyline.build(shade, id, pixels, Root.phone())
	-- The words' stage: the whole screen, its lettering a size up on a phone so every line reads.
	local sc = if Root.phone() then math.max(Root.scale, 0.8) else Root.scale
	size = Vector2.new(pixels.X / sc, pixels.Y / sc)
	-- A shade down the left (and along the foot) so the words read over any part of the scene.
	local scrim = Instance.new("Frame")
	scrim.Name = "Scrim"
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Color3.new(0, 0, 0)
	scrim.BorderSizePixel = 0
	scrim.ZIndex = 59
	scrim.Parent = shade
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(0.45, 0.42), NumberSequenceKeypoint.new(0.75, 1), NumberSequenceKeypoint.new(1, 1) })
	sg.Parent = scrim
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(size.X, size.Y)
	stage.ZIndex = 60
	stage.Parent = shade
	local stageScale = Instance.new("UIScale")
	stageScale.Scale = sc
	stageScale.Parent = stage
	local moving = scene.step

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
	col.Parent = stage
	local align = if narrow then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
	local kicker = label(col, "Kicker", "NOW ENTERING" .. (if theme.tag ~= "" then "  ·  " .. theme.tag else ""), 12, Brand.Fonts.heavy, theme.accent, 0)
	kicker.TextXAlignment = align
	local titleSize = math.clamp(math.floor(w / math.max(8, #(if def then def.name else "")) * 1.6), 32, 64)
	local title = label(col, "Title", string.upper(if def then def.name else ""), titleSize, Brand.Fonts.display, C.bone, 20)
	title.TextScaled = false
	title.TextXAlignment = align
	-- (Build 102) The name in light gold, bright at the top, as if lit by the low sun.
	local metal = Instance.new("UIGradient")
	metal.Rotation = 90
	metal.Color = ColorSequence.new(Color3.fromRGB(255, 248, 230), Color3.fromRGB(240, 200, 120))
	metal.Parent = title
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
	-- (Room above the line for how far along it is.)
	local top = 112 + titleSize

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
	-- (Build 88) Its part in the guest's Fortune, in gold, under the tip.
	local fortune = LoadIn.FORTUNE[id]
	if fortune then
		local fl = label(col, "Fortune", "◆  " .. fortune, 13, Brand.Fonts.bodyBold, GOLD, top + 128)
		fl.Size = UDim2.new(1, 0, 0, 36)
		fl.TextXAlignment = align
	end
	-- The game's name at the foot, with a turning ring of light beside how far along it is.
	local mark = label(stage, "Brand", "◆  " .. Brand.Name, 13, Brand.Fonts.heavy, Color3.fromRGB(240, 214, 150), 22)
	-- (At the top right: Roblox's own buttons sit at the top left.)
	mark.AnchorPoint = Vector2.new(1, 0)
	mark.Position = UDim2.fromOffset(size.X - math.max(32, size.X * 0.05), 22)
	mark.Size = UDim2.fromOffset(math.min(420, size.X * 0.6), 22)
	mark.TextXAlignment = Enum.TextXAlignment.Right
	local percent = label(col, "Percent", "LOADING  0%", 11, Brand.Fonts.heavy, theme.accent, top - 18)
	percent.TextXAlignment = if narrow then Enum.TextXAlignment.Center else Enum.TextXAlignment.Right
	local ring = Instance.new("Frame")
	ring.Name = "Spinner"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.new(1, -36, 1, -40)
	ring.Size = UDim2.fromOffset(28, 28)
	ring.BackgroundTransparency = 1
	ring.ZIndex = 62
	ring.Parent = stage
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.Color = theme.accent
	rs.Thickness = 3
	rs.Parent = ring
	local arc = Instance.new("UIGradient")
	arc.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.51, 1), NumberSequenceKeypoint.new(1, 1) })
	arc.Parent = rs

	-- (Build 102) Real progress, not a clock: what's actually ready moves the line. Finding the
	-- place's model is the first third; each texture, mesh and sound as it arrives moves it on
	-- through the second; the server letting the guest in fills it.
	local state: { [string]: any } = { id = id, shade = shade, gui = gui, fill = fill, rows = rows, from = os.clock(), seconds = math.max(0.5, seconds), after = after, controls = wasControls, ready = false, target = 0.06, shownAt = 0, assets = 0 }
	shown = state

	state.beat = RunService.Heartbeat:Connect(function(dt: number)
		local goal = math.clamp(state.target, 0, 1)
		state.shownAt += (goal - state.shownAt) * math.min(1, dt * 6)
		fill.Size = UDim2.fromScale(state.shownAt, 1)
		percent.Text = string.format("LOADING  %d%%", math.floor(state.shownAt * 100 + 0.5))
		arc.Rotation = (arc.Rotation + dt * 240) % 360
		pcall(moving, os.clock() - state.from)
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
		state.target = 0.35
		if model then
			local done = false
			task.spawn(function()
				pcall(function()
					ContentProvider:PreloadAsync({ model }, function()
						state.assets += 1
						state.target = 0.35 + 0.5 * (1 - math.exp(-state.assets / 25))
					end)
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
		state.target = 0.9
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
	task.delay(if quiet then 0 else 0.6, Toast.hold, false)
	Controls.set(state.controls ~= false)
	local shade = state.shade :: Frame
	local gui = state.gui :: ScreenGui
	if quiet then
		gui:Destroy()
		return
	end
	state.target = 1
	step(state.rows.rooms, true)
	step(state.rows.assets, true)
	step(state.rows.ready, true)
	state.fill.Size = UDim2.fromScale(1, 1)
	for _, d in shade:GetDescendants() do
		if d:IsA("UIStroke") then
			Ease.play(d, Ease.info(0.45, Enum.EasingStyle.Quad), { Transparency = 1 })
		end
	end
	Ease.play(shade, Ease.info(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	for _, d in shade:GetDescendants() do
		if d:IsA("TextLabel") then
			Ease.play(d, Ease.info(0.45, Enum.EasingStyle.Quad), { TextTransparency = 1 })
		elseif d:IsA("Frame") then
			Ease.play(d, Ease.info(0.45, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		end
	end
	task.delay(0.5, function()
		gui:Destroy()
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

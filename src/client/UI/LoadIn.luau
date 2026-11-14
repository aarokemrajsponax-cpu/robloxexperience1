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

-- Shows the card for `id` and starts making the place ready. `seconds`: the least the server holds.
-- `after`: what to do once the guest can move (the first-visit card, a line).
function LoadIn.start(id: string, seconds: number, after: (() -> ())?)
	LoadIn.finish(true)
	local def = AttractionList.byId[id]
	local size = Root.size()
	local wasControls = Controls.wanted()
	Controls.set(false)

	local shade = Instance.new("Frame")
	shade.Name = NAME
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.fromRGB(6, 6, 8)
	shade.BackgroundTransparency = 0.12
	shade.BorderSizePixel = 0
	shade.ZIndex = 60
	shade.Active = true
	shade.Parent = Root.hud
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.25) })
	fade.Parent = shade

	local w = math.min(440, math.max(260, size.X - 32))
	local col = Instance.new("Frame")
	col.Name = "Column"
	col.AnchorPoint = Vector2.new(0.5, 0.5)
	col.Position = UDim2.fromScale(0.5, 0.5)
	col.Size = UDim2.fromOffset(w, 260)
	col.BackgroundTransparency = 1
	col.ZIndex = 61
	col.Parent = shade

	label(col, "Kicker", "NOW ENTERING", 12, Brand.Fonts.heavy, GOLD, 0)
	local title = label(col, "Title", if def then def.name else "", 34, Brand.Fonts.display, C.bone, 20)
	title.TextScaled = false
	label(col, "Line", if def then def.line else "", 14, Brand.Fonts.body, C.smoke, 64).Size = UDim2.new(1, 0, 0, 40)

	-- The progress: a gold line filling over the hold.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 116)
	track.Size = UDim2.new(1, 0, 0, 4)
	track.BackgroundColor3 = Color3.fromRGB(46, 42, 36)
	track.BorderSizePixel = 0
	track.ZIndex = 61
	track.Parent = col
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(1, 0)
	tc.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.ZIndex = 62
	fill.Parent = track
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill

	-- What's being made ready, each lit as it is.
	local rows: { [string]: Frame } = {}
	for i, spec in { { "rooms", "The rooms" }, { "assets", "Textures and sounds" }, { "ready", "Your way in" } } do
		local row = Instance.new("Frame")
		row.Name = "Step_" .. spec[1]
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0)
		row.Position = UDim2.new(0.5, 0, 0, 132 + (i - 1) * 22)
		row.Size = UDim2.fromOffset(200, 18)
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
		text.Position = UDim2.fromOffset(16, 0)
		text.Size = UDim2.new(1, -16, 1, 0)
		text.FontFace = Brand.Fonts.bodyBold
		text.TextSize = 13
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = spec[2]
		text.ZIndex = 62
		text.Parent = row
		rows[spec[1]] = row
		step(row, false)
	end
	local tip = LoadIn.TIPS[id]
	if tip then
		label(col, "Tip", tip, 13, Brand.Fonts.bodyBold, GOLD, 206).Size = UDim2.new(1, 0, 0, 40)
	end

	local state: { [string]: any } = { id = id, shade = shade, fill = fill, rows = rows, from = os.clock(), seconds = math.max(0.5, seconds), after = after, controls = wasControls, ready = false }
	shown = state

	-- The progress line, kept up to the moment (it waits short of the end until the server lets go).
	state.beat = RunService.Heartbeat:Connect(function()
		local f = math.clamp((os.clock() - state.from) / state.seconds, 0, 0.96)
		fill.Size = UDim2.fromScale(f, 1)
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

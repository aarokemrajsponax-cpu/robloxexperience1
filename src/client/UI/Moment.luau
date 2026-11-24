--!strict
-- (Build 103) The house's moments: a piece lifted, a checkpoint reached, a generator down, the
-- Executive beaten, a round won in the Ballroom. Not a notice in the corner but a moment in the
-- room: a soft glow blooms behind a plate of dark glass, the plate rises into place, a band of
-- light passes across it, the reward counts up rather than appearing, gold motes drift away, and
-- it leaves as gently as it came. One at a time: a small moment gives way to the next; a big one
-- (a boss beaten) always has a good look first (what comes meanwhile waits for that), then makes
-- way gracefully.
--
--   Moment.show({ title = "Checkpoint 8", line = "+55 Gilt", kicker = "THE BASEMENT",
--                 tone = Color3, seconds = 2.6, big = false, sound = "chime" })
--
-- The words are exactly the ones given (title and line), so what's said stays the server's truth.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Sound = require(script.Parent.Parent.Sound)
local Root = require(script.Parent.Root)

local Moment = {}

export type Spec = {
	title: string,
	line: string?,
	kicker: string?,
	tone: Color3?,
	seconds: number?,
	big: boolean?,
	sound: string?,
	volume: number?,
	value: number?, -- a figure that counts up, big and gold ("+55 GILT")
	unit: string?, -- after the figure (default "GILT")
}

local GOLD = Color3.fromRGB(240, 200, 110)
local player = Players.LocalPlayer
local current: { [string]: any }? = nil
local queue: { Spec } = {}

local function screen(): ScreenGui?
	local gui = player:FindFirstChild("PlayerGui")
	if not gui then
		return nil
	end
	local existing = gui:FindFirstChild("MaisonMoments")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonMoments"
	s.ResetOnSpawn = false
	s.IgnoreGuiInset = false
	s.DisplayOrder = 64
	s.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = gui
	return s
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, Ease.scaled(TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out)), goal)
	t:Play()
	return t
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

-- A figure counting up from nothing to `target` ("+1,240 GILT"), slowing as it arrives.
local function countUp(label: TextLabel, target: number, unit: string, seconds: number)
	local before, after = "+", " " .. unit
	local words = before .. commas(target) .. after
	if target < 10 or Ease.motionScale < 0.5 then
		label.Text = words
		return
	end
	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local t = math.clamp((os.clock() - started) / seconds, 0, 1)
		local eased = 1 - (1 - t) ^ 3
		label.Text = before .. commas(target * eased) .. after
		if t >= 1 or label.Parent == nil then
			label.Text = words
			if conn then
				conn:Disconnect()
			end
		end
	end)
	label.Text = before .. "0" .. after
end

local function text(parent: Instance, name: string, words: string, size: number, font: Font, colour: Color3, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(0, y)
	l.Size = UDim2.new(1, 0, 0, height)
	l.Text = words
	l.TextSize = size
	l.FontFace = font
	l.TextColor3 = colour
	l.TextWrapped = true
	l.ZIndex = 5
	l.Parent = parent
	return l
end

local function leave(state: { [string]: any }, quick: boolean)
	if state.gone then
		return
	end
	state.gone = true
	local holder = state.holder :: Frame
	local seconds = if quick == true then 0.3 else 0.8
	tween(holder, seconds, { Position = holder.Position - UDim2.fromOffset(0, 12) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for _, d in holder:GetDescendants() do
		if d:IsA("TextLabel") then
			tween(d, seconds, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Sine)
		elseif d:IsA("Frame") then
			tween(d, seconds, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
		elseif d:IsA("UIStroke") then
			tween(d, seconds, { Transparency = 1 }, Enum.EasingStyle.Sine)
		end
	end
	task.delay(seconds + 0.05, function()
		holder:Destroy()
	end)
end

local function present(spec: Spec)
	local gui = screen()
	if not gui then
		return
	end
	local big = spec.big == true
	local tone = spec.tone or GOLD
	local seconds = spec.seconds or (if big then 4.5 else 2.8)
	local size = Root.size()
	local w = math.min(if big then 560 else 440, size.X - 40)
	local figureSize = if big then 34 else 26
	-- (Its height from its words: a long line gets the room it needs, never clipped.)
	local lineSize = if big then 17 else 14
	local lineLines = 0
	if spec.line and spec.line ~= "" then
		local perLine = math.max(12, math.floor((w - 40) / (lineSize * 0.52)))
		local n = utf8.len(spec.line) or #spec.line
		lineLines = math.max(1, math.ceil(n / perLine))
	end
	local padY = if big then 18 else 12
	local titleBox = (if big then 30 else 20) + 10
	local h = padY * 2 + (if spec.kicker then 18 else 0) + titleBox + (if spec.value then figureSize + 6 else 0) + lineLines * (lineSize + 5)
	h = math.max(h, if big then 120 else 70)

	local holder = Instance.new("Frame")
	holder.Name = "Moment"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, if big then 0.4 else 0.36, 18)
	holder.Size = UDim2.fromOffset(w, h)
	holder.Parent = gui
	-- (Drawn at the house's lettering scale for this screen, as the HUD is; it settles from a
	-- touch smaller.)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.9 * Root.scale
	scale.Parent = holder

	-- The glow behind it: soft, wide, in the moment's colour.
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.new(1.5, 0, 2.4, 0)
	glow.BackgroundColor3 = tone
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.ZIndex = 1
	glow.Parent = holder
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(0.5, 0)
	gc.Parent = glow
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow

	-- The plate: dark glass, a gold hairline above and below.
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Color3.fromRGB(10, 8, 8)
	plate.BackgroundTransparency = 1
	plate.BorderSizePixel = 0
	plate.ZIndex = 2
	plate.ClipsDescendants = true
	plate.Parent = holder
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 16)
	pc.Parent = plate
	local edge = Instance.new("UIStroke")
	edge.Color = tone
	edge.Thickness = if big then 2 else 1.5
	edge.Transparency = 1
	edge.Parent = plate
	local pg = Instance.new("UIGradient")
	pg.Rotation = 90
	pg.Color = ColorSequence.new(Color3.fromRGB(34, 26, 18), Color3.fromRGB(8, 6, 6))
	pg.Parent = plate
	-- The band of light that passes across.
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.AnchorPoint = Vector2.new(0.5, 0.5)
	sweep.Position = UDim2.fromScale(-0.3, 0.5)
	sweep.Size = UDim2.new(0.18, 0, 2, 0)
	sweep.Rotation = 18
	sweep.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
	sweep.BackgroundTransparency = 1
	sweep.BorderSizePixel = 0
	sweep.ZIndex = 3
	sweep.Parent = plate
	local sg = Instance.new("UIGradient")
	sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) })
	sg.Parent = sweep

	local pad = if big then 18 else 12
	local inner = Instance.new("Frame")
	inner.Name = "Words"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(20, pad)
	inner.Size = UDim2.new(1, -40, 1, -pad * 2)
	inner.ZIndex = 4
	inner.Parent = plate
	local y = 0
	if spec.kicker then
		local k = text(inner, "Kicker", string.upper(spec.kicker), 11, Brand.Fonts.heavy, tone, y, 14)
		k.TextTransparency = 1
		y += 18
	end
	local titleSize = if big then 30 else 20
	local title = text(inner, "Title", spec.title, titleSize, Brand.Fonts.display, Color3.new(1, 1, 1), y, titleSize + 8)
	title.TextTransparency = 1
	local metal = Instance.new("UIGradient")
	metal.Rotation = 90
	metal.Color = ColorSequence.new(Color3.fromRGB(255, 250, 236), tone:Lerp(Color3.new(1, 1, 1), 0.25))
	metal.Parent = title
	y += titleSize + 10
	local figure: TextLabel? = nil
	if spec.value then
		local f = text(inner, "Figure", "", figureSize, Brand.Fonts.display, Color3.new(1, 1, 1), y - 4, figureSize + 4)
		f.TextTransparency = 1
		local fg = Instance.new("UIGradient")
		fg.Rotation = 90
		fg.Color = ColorSequence.new(Color3.fromRGB(255, 240, 190), Color3.fromRGB(214, 160, 60))
		fg.Parent = f
		figure = f
		y += figureSize + 6
	end
	if spec.line and spec.line ~= "" then
		local l = text(inner, "Line", spec.line, lineSize, Brand.Fonts.bodyBold, Color3.fromRGB(246, 232, 200), y, h - pad * 2 - y)
		l.TextTransparency = 1
		l.TextYAlignment = Enum.TextYAlignment.Top
	end

	-- In: the glow blooms, the plate rises and settles, the light passes, the words come up.
	tween(scale, 0.75, { Scale = Root.scale })
	tween(holder, 0.75, { Position = UDim2.new(0.5, 0, if big then 0.4 else 0.36, 0) })
	tween(glow, 1.1, { BackgroundTransparency = if big then 0.45 else 0.6 }, Enum.EasingStyle.Sine)
	tween(plate, 0.6, { BackgroundTransparency = 0.08 }, Enum.EasingStyle.Sine)
	tween(edge, 0.9, { Transparency = 0.15 }, Enum.EasingStyle.Sine)
	for _, d in inner:GetChildren() do
		if d:IsA("TextLabel") then
			task.delay(0.12, function()
				if d.Parent then
					tween(d, 0.6, { TextTransparency = 0 }, Enum.EasingStyle.Sine)
				end
			end)
		end
	end
	task.delay(0.35, function()
		if sweep.Parent then
			sweep.BackgroundTransparency = 0
			tween(sweep, 1.2, { Position = UDim2.fromScale(1.3, 0.5) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end
	end)
	local f = figure
	if f and spec.value then
		countUp(f, spec.value, spec.unit or "GILT", if big then 1.6 else 1.0)
	end
	-- Gold motes drifting away from it.
	if Ease.motionScale >= 0.5 then
		for i = 1, if big then 14 else 8 do
			local mote = Instance.new("Frame")
			mote.Name = "Mote"
			mote.AnchorPoint = Vector2.new(0.5, 0.5)
			mote.Position = UDim2.fromScale(0.5 + (math.random() - 0.5) * 0.6, 0.5)
			local d = math.random(3, 6)
			mote.Size = UDim2.fromOffset(d, d)
			mote.Rotation = 45
			mote.BackgroundColor3 = if i % 3 == 0 then Color3.fromRGB(255, 248, 230) else tone
			mote.BackgroundTransparency = 0.1
			mote.BorderSizePixel = 0
			mote.ZIndex = 6
			mote.Parent = holder
			local angle = math.random() * math.pi * 2
			local reach = math.random(60, if big then 200 else 140)
			task.delay(0.2 + i * 0.03, function()
				if mote.Parent then
					tween(mote, 1.6, { Position = UDim2.new(mote.Position.X.Scale, math.cos(angle) * reach, 0.5, math.sin(angle) * reach * 0.6), BackgroundTransparency = 1, Rotation = 45 + math.random(-90, 90) }, Enum.EasingStyle.Quint)
				end
			end)
		end
	end
	if spec.sound then
		pcall(Sound.play, spec.sound, spec.volume or 0.7)
	end
	local state: { [string]: any } = { holder = holder, big = big, gone = false, since = os.clock() }
	current = state
	-- (A slow breath in the glow while it stands.)
	task.spawn(function()
		local t0 = os.clock()
		while glow.Parent and not state.gone do
			glow.BackgroundTransparency = (if big then 0.45 else 0.6) + 0.06 * math.sin((os.clock() - t0) * 2)
			task.wait(1 / 30)
		end
	end)
	task.delay(seconds, function()
		if state.gone then
			return -- (already made way for another)
		end
		if current == state then
			current = nil
		end
		leave(state, false)
		local nextSpec = table.remove(queue, 1)
		if nextSpec then
			task.delay(0.25, Moment.show, nextSpec)
		end
	end)
end

local BIG_LOOK = 2 -- seconds a big moment always stands before anything takes its place

-- Shows a moment: a small one gives way to the next straight away; a big one stands for a good
-- look first (BIG_LOOK seconds; what comes meanwhile waits for that), then makes way.
function Moment.show(spec: Spec)
	local now = current
	if now and not now.gone then
		local stood = os.clock() - (now.since :: number)
		if now.big and stood < BIG_LOOK then
			if #queue < 3 then
				table.insert(queue, spec)
				if #queue == 1 then
					task.delay(BIG_LOOK - stood, function()
						if current == now then
							current = nil
							leave(now, true)
						end
						local nextSpec = table.remove(queue, 1)
						if nextSpec then
							Moment.show(nextSpec)
						end
					end)
				end
			end
			return
		end
		current = nil
		leave(now, true)
	end
	present(spec)
end

-- (Build 103) The moment in the room as well as on the screen: where the guest stands, a pool of
-- light spreads across the floor and fades, a soft light swells and dies away, and a few sparks
-- rise. Only on this guest's screen; a few parts for a second and a half.
function Moment.burst(colour: Color3?, big: boolean?)
	if Ease.motionScale < 0.5 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local tone = colour or GOLD
	local at = root.CFrame.Position - Vector3.new(0, 2.8, 0)
	local ring = Instance.new("Part")
	ring.Name = "MomentRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = tone
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.08, 3, 3)
	ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace.CurrentCamera or workspace
	local light = Instance.new("PointLight")
	light.Color = tone
	light.Brightness = 0
	light.Range = if big then 22 else 14
	light.Shadows = false
	light.Parent = ring
	local reach = if big then 26 else 16
	tween(ring, 1.3, { Size = Vector3.new(0.08, reach, reach), Transparency = 1 }, Enum.EasingStyle.Quint)
	tween(light, 0.25, { Brightness = if big then 3 else 2 }, Enum.EasingStyle.Sine)
	task.delay(0.3, function()
		if light.Parent then
			tween(light, 1.1, { Brightness = 0 }, Enum.EasingStyle.Sine)
		end
	end)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 248, 230), tone)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
	sparks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparks.Lifetime = NumberRange.new(0.8, 1.4)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.Drag = 2
	sparks.Rate = 0
	sparks.EmissionDirection = Enum.NormalId.Right
	sparks.Parent = ring
	pcall(function()
		sparks:Emit(if big then 40 else 18)
	end)
	task.delay(1.6, function()
		ring:Destroy()
	end)
end

-- Whether a moment is on the screen (for tests, and for what should wait for it).
function Moment.showing(): boolean
	return current ~= nil
end

return Moment

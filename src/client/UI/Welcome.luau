--!strict
-- A welcome as a guest arrives, drawn on their own screen only: nobody else sees it. WELCOME,
-- letter by letter in gold metal, then their name, on a band of dark glass between two lines of
-- light; a sweep of light crosses it, gold sparks burst out of it and a soft chime plays; in the
-- house, a ring of light and gold sparkles round their feet (made on this screen, so only they see
-- those too). On a first evening a line under it: the Concierge shows new guests round, and a gold
-- arrow points the way (World/ConciergeGuide). A returning guest is welcomed back, shorter. It's
-- gone after a few seconds (Config.Welcome), never waits on a click, and never covers a table.
-- With the Movement setting on Still: the words alone, no flying letters, sparks or sweep.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)

local Welcome = {}

local player = Players.LocalPlayer
local C = Brand.Colours
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local SPARKS = 18
local BEADS = 28

local current: ScreenGui? = nil

local function cfg(): { [string]: any }
	return Config.data.Welcome
end

local function still(): boolean
	return State.get("movement") == "Still"
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, delay: number?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, delay or 0), goal)
	t:Play()
	return t
end

local function sound(name: string, volume: number, pitch: number?)
	pcall(Sound.play, name, volume, pitch)
end

local function frame(parent: Instance, name: string, colour: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency
	f.Parent = parent
	return f
end

local function text(parent: Instance, name: string, words: string, font: Font, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.FontFace = font
	l.Text = words
	l.TextColor3 = colour
	l.TextScaled = true
	l.TextTransparency = 1
	l.Parent = parent
	return l
end

-- Gold metal on a letter: bright at the top through the house's gold to a deeper gold.
local function metal(target: GuiObject)
	local g = Instance.new("UIGradient")
	g.Name = "Metal"
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 230)),
		ColorSequenceKeypoint.new(0.48, C.brightGold),
		ColorSequenceKeypoint.new(1, C.gold),
	})
	g.Parent = target
end

-- A line of light, brightest in the middle, gone at its ends.
local function lightLine(parent: Instance, name: string, y: number): Frame
	local line = frame(parent, name, C.brightGold, 0)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.new(0.5, 0, 0, y)
	line.Size = UDim2.new(0, 0, 0, 2)
	line.ZIndex = 4
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = line
	return line
end

-- A small gold diamond.
local function diamond(parent: Instance, name: string, size: number): Frame
	local d = frame(parent, name, C.brightGold, 0)
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Size = UDim2.fromOffset(size, size)
	d.Rotation = 45
	return d
end

-- In the house, round the guest's feet: a ring of light opening across the floor and a burst of
-- gold sparkles. Made on this screen, so only the guest sees them.
local function feetBurst()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	local feet = root.CFrame.Position - Vector3.new(0, hip + root.Size.Y / 2 - 0.25, 0)
	local holder = Instance.new("Folder")
	holder.Name = "MaisonWelcomeRing"
	holder.Parent = Workspace.CurrentCamera or Workspace
	for i = 1, BEADS do
		local a = (i / BEADS) * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local bead = Instance.new("Part")
		bead.Name = "Bead"
		bead.Shape = Enum.PartType.Ball
		bead.Anchored = true
		bead.CanCollide = false
		bead.CanQuery = false
		bead.CanTouch = false
		bead.CastShadow = false
		bead.Material = Enum.Material.Neon
		bead.Color = C.brightGold
		bead.Transparency = 0.1
		bead.Size = Vector3.new(0.45, 0.45, 0.45)
		bead.CFrame = CFrame.new(feet + out * 1.6)
		bead.Parent = holder
		tween(bead, 1.1, { CFrame = CFrame.new(feet + out * 13 + Vector3.new(0, 0.6, 0)), Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) }, Enum.EasingStyle.Quart)
	end
	local at = Instance.new("Attachment")
	at.Name = "MaisonWelcomeSparkles"
	at.Parent = root
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Rate = 0
	sparkles.Color = ColorSequence.new(C.brightGold, Color3.fromRGB(255, 250, 230))
	sparkles.LightEmission = 1
	sparkles.LightInfluence = 0
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparkles.Lifetime = NumberRange.new(0.9, 1.6)
	sparkles.Speed = NumberRange.new(7, 13)
	sparkles.SpreadAngle = Vector2.new(180, 180)
	sparkles.Acceleration = Vector3.new(0, -5, 0)
	sparkles.Drag = 2
	sparkles.Parent = at
	pcall(function()
		sparkles:Emit(40)
	end)
	task.delay(2.5, function()
		holder:Destroy()
		at:Destroy()
	end)
end

-- Gold sparks flying out of the middle of the welcome, and a few motes drifting up after.
local function sparks(parent: Frame, u: number)
	for i = 1, SPARKS do
		local a = (i / SPARKS) * math.pi * 2 + (math.random() - 0.5) * 0.35
		local reach = (150 + math.random() * 170) * u
		local size = math.floor((5 + math.random() * 6) * u + 0.5)
		local d = diamond(parent, "Spark", size)
		d.Position = UDim2.new(0.5, 0, 0.5, 0)
		d.BackgroundTransparency = 0
		local to = UDim2.new(0.5, math.cos(a) * reach, 0.5, math.sin(a) * reach * 0.42)
		tween(d, 0.95, { Position = to, BackgroundTransparency = 1, Rotation = 45 + 180 * (if i % 2 == 0 then 1 else -1) }, Enum.EasingStyle.Quart)
	end
	for i = 1, 8 do
		local d = diamond(parent, "Mote", math.floor(4 * u + 0.5))
		local x = (math.random() - 0.5) * 520 * u
		d.Position = UDim2.new(0.5, x, 0.5, (math.random() - 0.2) * 40 * u)
		d.BackgroundTransparency = 0.2
		tween(d, 2.6 + math.random(), { Position = UDim2.new(0.5, x + (math.random() - 0.5) * 30 * u, 0.5, -90 * u), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine, 0.1 * i)
	end
end

function Welcome.showing(): boolean
	return current ~= nil and current.Parent ~= nil
end

function Welcome.clear()
	local gui = current
	current = nil
	if gui then
		gui:Destroy()
	end
end

-- `name`: the guest's name as the house shows it. `first`: their first evening (the line about the
-- Concierge; Main starts the arrow).
function Welcome.show(name: string, first: boolean)
	if cfg().enabled ~= true or (not first and cfg().returning ~= true) then
		return
	end
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return
	end
	Welcome.clear()
	local camera = Workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local u = math.clamp(math.min(vp.Y / 720, vp.X / 1000), 0.62, 1.35)
	local calm = still()
	local seconds = if first then cfg().seconds else cfg().backSeconds

	local gui = Instance.new("ScreenGui")
	gui.Name = "MaisonWelcome"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	current = gui

	-- (On a narrow screen the line about the Concierge takes two lines rather than shrinking.)
	local narrow = vp.X < 600
	local lineH = if narrow then 30 else math.floor(17 * u + 0.5)
	local bandH = math.floor((if first then 192 else 162) * u + 0.5) + (if first then lineH - math.floor(17 * u + 0.5) else 0)
	local holder = frame(gui, "Welcome", Color3.new(0, 0, 0), 1)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, cfg().heightAt)
	holder.Size = UDim2.new(0, math.min(vp.X, 980 * u), 0, bandH)

	-- The band of dark glass, gone at its ends, a breath of gold through its middle.
	local band = frame(holder, "Band", C.nearBlack, 1)
	band.Size = UDim2.fromScale(1, 1)
	band.ZIndex = 1
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.24, 0.12),
		NumberSequenceKeypoint.new(0.76, 0.12),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = band
	local warmth = frame(holder, "Warmth", C.glow, 1)
	warmth.AnchorPoint = Vector2.new(0.5, 0.5)
	warmth.Position = UDim2.fromScale(0.5, 0.5)
	warmth.Size = UDim2.new(0, math.min(vp.X, 760 * u), 1, 0)
	warmth.ZIndex = 2
	local warmthFade = Instance.new("UIGradient")
	warmthFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.86),
		NumberSequenceKeypoint.new(1, 1),
	})
	warmthFade.Parent = warmth
	local top = lightLine(holder, "TopLine", 1)
	local bottom = lightLine(holder, "BottomLine", bandH - 1)

	-- MAISON NOIR, between two diamonds.
	local kicker = text(holder, "Kicker", "MAISON  NOIR", Brand.Fonts.display, C.lightGold)
	kicker.Position = UDim2.new(0.5, 0, 0, 26 * u)
	kicker.Size = UDim2.new(0, 220 * u, 0, 15 * u)
	kicker.ZIndex = 5
	local leftMark = diamond(holder, "MarkLeft", math.floor(6 * u + 0.5))
	leftMark.Position = UDim2.new(0.5, -128 * u, 0, 26 * u)
	leftMark.ZIndex = 5
	leftMark.BackgroundTransparency = 1
	local rightMark = diamond(holder, "MarkRight", math.floor(6 * u + 0.5))
	rightMark.Position = UDim2.new(0.5, 128 * u, 0, 26 * u)
	rightMark.ZIndex = 5
	rightMark.BackgroundTransparency = 1

	-- WELCOME (or WELCOME BACK), lit a letter at a time: every letter the same size, side by side.
	local wordText = if first then "WELCOME" else "WELCOME BACK"
	local count = #wordText
	local size = math.floor(math.min(46 * u, (vp.X - 60) / (count * 1.2)) + 0.5)
	local wordH = math.floor(size * 1.3 + 0.5)
	local wordY = 42 * u + wordH / 2
	local word = frame(holder, "Word", Color3.new(0, 0, 0), 1)
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.new(0.5, 0, 0, wordY - (if calm then 0 else 14 * u))
	word.Size = UDim2.new(1, 0, 0, wordH)
	word.ZIndex = 5
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, math.max(1, math.floor(size * 0.06)))
	list.Parent = word
	local letters: { TextLabel } = {}
	for i = 1, count do
		local ch = string.sub(wordText, i, i)
		if ch == " " then
			local gap = frame(word, "Gap", Color3.new(0, 0, 0), 1)
			gap.LayoutOrder = i
			gap.Size = UDim2.new(0, math.floor(size * 0.55), 1, 0)
		else
			local l = Instance.new("TextLabel")
			l.Name = "Letter" .. i
			l.LayoutOrder = i
			l.BackgroundTransparency = 1
			l.AutomaticSize = Enum.AutomaticSize.X
			l.Size = UDim2.new(0, 0, 1, 0)
			l.FontFace = Brand.Fonts.display
			l.TextSize = size
			l.Text = ch
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextTransparency = 1
			l.ZIndex = 6
			metal(l)
			local glow = Instance.new("UIStroke")
			glow.Name = "Glow"
			glow.Color = C.glow
			glow.Thickness = math.max(1, 2 * u)
			glow.Transparency = 1
			glow.Parent = l
			l.Parent = word
			table.insert(letters, l)
		end
	end

	-- Their name, in white, heavy.
	local nameLabel = text(holder, "Name", string.upper(name), HEAVY, Color3.new(1, 1, 1))
	local nameY = 42 * u + wordH + 28 * u
	nameLabel.Position = UDim2.new(0.5, 0, 0, nameY + (if calm then 0 else 10 * u))
	nameLabel.Size = UDim2.new(0, math.min(vp.X - 48, 620 * u), 0, 32 * u)
	nameLabel.ZIndex = 6
	local nameShadow = Instance.new("UIStroke")
	nameShadow.Color = Color3.new(0, 0, 0)
	nameShadow.Transparency = 1
	nameShadow.Thickness = 1
	nameShadow.Parent = nameLabel

	-- A first evening: the Concierge shows new guests round.
	local line: TextLabel? = nil
	if first then
		local l = text(holder, "Line", "The Concierge shows new guests round  ·  follow the gold arrow", Brand.Fonts.body, C.smoke)
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, nameY + 22 * u)
		l.Size = UDim2.new(0, math.min(vp.X - 48, 560 * u), 0, lineH)
		l.TextWrapped = true
		l.ZIndex = 6
		local most = Instance.new("UITextSizeConstraint")
		most.MaxTextSize = 17
		most.Parent = l
		line = l
	end

	-- A sweep of light across it (kept to the band).
	local clip = frame(holder, "Sweep", Color3.new(0, 0, 0), 1)
	clip.Size = UDim2.fromScale(1, 1)
	clip.ClipsDescendants = true
	clip.ZIndex = 7
	local glint = frame(clip, "Glint", Color3.new(1, 1, 1), 0.55)
	glint.AnchorPoint = Vector2.new(0.5, 0.5)
	glint.Position = UDim2.new(0, -200 * u, 0.5, 0)
	glint.Size = UDim2.new(0, 220 * u, 1.6, 0)
	glint.ZIndex = 7
	local glintShape = Instance.new("UIGradient")
	glintShape.Rotation = 20
	glintShape.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	glintShape.Parent = glint
	glint.Visible = not calm

	local sparkLayer = frame(holder, "Sparks", Color3.new(0, 0, 0), 1)
	sparkLayer.Size = UDim2.fromScale(1, 1)
	sparkLayer.ZIndex = 8

	-- In: the glass, the lines opening out, the word settling as its letters light one by one.
	tween(band, 0.35, { BackgroundTransparency = 0.18 })
	tween(warmth, 0.6, { BackgroundTransparency = 0 })
	tween(top, 0.7, { Size = UDim2.new(0.62, 0, 0, 2) }, Enum.EasingStyle.Quart)
	tween(bottom, 0.7, { Size = UDim2.new(0.62, 0, 0, 2) }, Enum.EasingStyle.Quart, 0.08)
	tween(kicker, 0.4, { TextTransparency = 0.05 }, nil, 0.1)
	tween(leftMark, 0.4, { BackgroundTransparency = 0 }, nil, 0.1)
	tween(rightMark, 0.4, { BackgroundTransparency = 0 }, nil, 0.1)
	sound("sparklePass", 0.55)
	tween(word, 0.6, { Position = UDim2.new(0.5, 0, 0, wordY) }, Enum.EasingStyle.Quart, 0.1)
	local landed = 0.15
	for i, l in letters do
		local at = 0.15 + (i - 1) * 0.06
		landed = at + 0.3
		tween(l, 0.3, { TextTransparency = 0 }, nil, at)
		local glow = l:FindFirstChild("Glow")
		if glow and not calm then
			-- (Each letter flares gold as it lights, then settles.)
			tween(glow, 0.12, { Transparency = 0.15 }, nil, at + 0.05)
			tween(glow, 0.6, { Transparency = 1 }, nil, at + 0.2)
		end
	end
	tween(nameLabel, 0.45, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0, nameY) }, Enum.EasingStyle.Quart, landed - 0.1)
	tween(nameShadow, 0.45, { Transparency = 0.6 }, nil, landed - 0.1)
	if line then
		tween(line, 0.5, { TextTransparency = 0 }, nil, landed + 0.35)
	end
	task.delay(landed - 0.05, function()
		if current ~= gui then
			return
		end
		sound(if first then "bellTree" else "chime", if first then 0.35 else 0.3, if first then 1 else 1.5)
		if not calm then
			sparks(sparkLayer, u)
			tween(glint, 0.95, { Position = UDim2.new(1, 200 * u, 0.5, 0) }, Enum.EasingStyle.Sine)
		end
	end)
	if not calm then
		task.delay(0.3, function()
			if current == gui then
				pcall(feetBurst)
			end
		end)
	end

	-- Out, a few seconds later.
	task.delay(seconds, function()
		if current ~= gui then
			return
		end
		for _, d in gui:GetDescendants() do
			if d:IsA("TextLabel") then
				tween(d, 0.5, { TextTransparency = 1 })
			elseif d:IsA("UIStroke") then
				tween(d, 0.5, { Transparency = 1 })
			elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
				tween(d, 0.5, { BackgroundTransparency = 1 })
			end
		end
		task.delay(0.6, function()
			if current == gui then
				Welcome.clear()
			end
		end)
	end)
end

return Welcome

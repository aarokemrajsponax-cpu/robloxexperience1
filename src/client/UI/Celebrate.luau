--!strict
-- Moments worth celebrating on a guest's own screen:
--   levelUp  LEVEL UP! in the middle of the screen, the new level in its tier's colour, its name,
--            what it brought (Gilt, and Gems every tenth level), with confetti and a fanfare
--   badge    a card sliding in from the right: the badge's glyph in its tier's colour, its name
--            and what it was for (several in a row wait their turn)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Levels = require(ReplicatedStorage.Shared.Levels)
local Flakes = require(script.Parent.Parent.World.Flakes)
local NeoFX = require(script.Parent.Parent.World.NeoFX)
local Sound = require(script.Parent.Parent.Sound)

local Celebrate = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BODY = Font.fromEnum(Enum.Font.GothamMedium)
-- (The big words: the house's sans at its heaviest, cut clean.)
local IMPACT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local TIER: { [string]: Color3 } = {
	bronze = rgb(205, 127, 72),
	silver = rgb(200, 206, 216),
	gold = rgb(246, 200, 92),
	platinum = rgb(150, 230, 255),
}

local function screen(): ScreenGui
	local gui = player:FindFirstChild("PlayerGui")
	local existing = gui and gui:FindFirstChild("MaisonCelebrate")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonCelebrate"
	s.ResetOnSpawn = false
	s.IgnoreGuiInset = false
	s.DisplayOrder = 66
	s.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	s.Parent = gui
	return s
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function sound(name: string, volume: number?, pitch: number?)
	pcall(Sound.play, name, volume or 0.8, pitch)
end

local function format(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

function Celebrate.levelUp(level: number, title: string, gilt: number)
	local gui = screen()
	local old = gui:FindFirstChild("LevelUp")
	if old then
		old:Destroy()
	end
	local colour = Levels.colour(level)
	-- (Build 103) Not a card that pops and snaps shut: a moment. A halo of the level's colour
	-- blooms and turns slowly behind it, the words rise into place and a band of light passes
	-- over them, the fanfare plays its whole first phrase (the house's music bows under it), and
	-- after a good look it all lifts away softly.
	local box = Instance.new("Frame")
	box.Name = "LevelUp"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(0.5, 0, 0.38, 26)
	box.Size = UDim2.fromOffset(520, 260)
	box.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.72
	scale.Parent = box
	local function ease(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?)
		TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out), goal):Play()
	end
	-- The halo: a soft disc of light, and long rays turning slowly through it.
	local halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromOffset(260, 117)
	halo.Size = UDim2.fromOffset(420, 420)
	halo.BackgroundColor3 = colour
	halo.BackgroundTransparency = 1
	halo.BorderSizePixel = 0
	halo.ZIndex = 0
	halo.Parent = box
	corner(halo, 210)
	local hg = Instance.new("UIGradient")
	hg.Color = ColorSequence.new(rgb(255, 246, 214), colour)
	hg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) })
	hg.Parent = halo
	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromOffset(260, 117)
	rays.Size = UDim2.fromOffset(10, 10)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 0
	rays.Parent = box
	local beams: { Frame } = {}
	for i = 0, 5 do
		local beam = Instance.new("Frame")
		beam.AnchorPoint = Vector2.new(0.5, 0.5)
		beam.Position = UDim2.fromScale(0.5, 0.5)
		beam.Size = UDim2.fromOffset(560, 26)
		beam.Rotation = i * 30
		beam.BackgroundColor3 = rgb(255, 240, 200)
		beam.BackgroundTransparency = 1
		beam.BorderSizePixel = 0
		beam.ZIndex = 0
		beam.Parent = rays
		local bg = Instance.new("UIGradient")
		bg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
		bg.Parent = beam
		table.insert(beams, beam)
	end
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 56)
	head.FontFace = IMPACT
	head.TextScaled = true
	head.TextColor3 = Color3.new(1, 1, 1)
	head.TextStrokeTransparency = 1
	head.TextStrokeColor3 = rgb(36, 22, 4)
	head.TextTransparency = 1
	head.Text = "LEVEL UP!"
	head.ClipsDescendants = true
	-- (In gold metal: bright at the top, deep at the foot.)
	local metal = Instance.new("UIGradient")
	metal.Rotation = 90
	metal.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 250, 226)),
		ColorSequenceKeypoint.new(0.5, rgb(255, 214, 120)),
		ColorSequenceKeypoint.new(1, rgb(214, 150, 50)),
	})
	metal.Parent = head
	head.Parent = box
	-- (A band of light passing along the words, once they're up.)
	local shine = Instance.new("UIGradient")
	shine.Name = "Shine"
	shine.Rotation = 20
	shine.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) })
	shine.Offset = Vector2.new(-1, 0)
	local shineLabel = Instance.new("TextLabel")
	shineLabel.Name = "HeadShine"
	shineLabel.BackgroundTransparency = 1
	shineLabel.Size = UDim2.fromScale(1, 1)
	shineLabel.FontFace = IMPACT
	shineLabel.TextScaled = true
	shineLabel.TextColor3 = rgb(255, 255, 255)
	shineLabel.Text = ""
	shineLabel.Parent = head
	shine.Parent = shineLabel
	local disc = Instance.new("TextLabel")
	disc.Name = "Level"
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.Position = UDim2.new(0.5, 0, 0, 62)
	disc.Size = UDim2.fromOffset(110, 110)
	disc.BackgroundColor3 = rgb(20, 16, 12)
	disc.BackgroundTransparency = 1
	disc.FontFace = HEAVY
	disc.TextScaled = true
	disc.TextColor3 = colour
	disc.TextTransparency = 1
	disc.Text = tostring(level)
	disc.Parent = box
	corner(disc, 55)
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Thickness = 5
	ring.Color = colour
	ring.Transparency = 1
	ring.Parent = disc
	local dp = Instance.new("UIPadding")
	dp.PaddingTop = UDim.new(0, 22)
	dp.PaddingBottom = UDim.new(0, 22)
	dp.PaddingLeft = UDim.new(0, 18)
	dp.PaddingRight = UDim.new(0, 18)
	dp.Parent = disc
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(0, 180)
	name.Size = UDim2.new(1, 0, 0, 34)
	name.FontFace = HEAVY
	name.TextScaled = true
	name.TextColor3 = colour
	name.TextStrokeTransparency = 1
	name.TextTransparency = 1
	name.Text = string.upper(title)
	name.Parent = box
	local reward = Instance.new("TextLabel")
	reward.BackgroundTransparency = 1
	reward.Position = UDim2.fromOffset(0, 220)
	reward.Size = UDim2.new(1, 0, 0, 26)
	reward.FontFace = HEAVY
	reward.TextScaled = true
	reward.TextColor3 = rgb(255, 230, 150)
	reward.TextStrokeTransparency = 1
	reward.TextTransparency = 1
	reward.Text = "+" .. format(gilt) .. " Gilt"
	reward.Parent = box

	-- In: the halo blooms first, then everything rises into place, one after another.
	ease(scale, 1.1, { Scale = 1 })
	ease(box, 1.1, { Position = UDim2.fromScale(0.5, 0.38) })
	ease(halo, 1.4, { BackgroundTransparency = 0.55 }, Enum.EasingStyle.Sine)
	for _, beam in beams do
		ease(beam, 1.6, { BackgroundTransparency = 0.78 }, Enum.EasingStyle.Sine)
	end
	ease(head, 0.7, { TextTransparency = 0, TextStrokeTransparency = 0.25 }, Enum.EasingStyle.Sine)
	task.delay(0.25, function()
		if box.Parent then
			ease(disc, 0.7, { BackgroundTransparency = 0, TextTransparency = 0 }, Enum.EasingStyle.Sine)
			ease(ring, 0.8, { Transparency = 0 }, Enum.EasingStyle.Sine)
		end
	end)
	task.delay(0.5, function()
		if box.Parent then
			ease(name, 0.7, { TextTransparency = 0, TextStrokeTransparency = 0.3 }, Enum.EasingStyle.Sine)
		end
	end)
	task.delay(0.75, function()
		if box.Parent then
			ease(reward, 0.7, { TextTransparency = 0, TextStrokeTransparency = 0.4 }, Enum.EasingStyle.Sine)
		end
	end)
	task.delay(0.9, function()
		if box.Parent then
			shineLabel.Text = head.Text
			TweenService:Create(shine, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(1, 0) }):Play()
		end
	end)
	-- (The halo breathes and the rays turn while it stands.)
	task.spawn(function()
		local t0 = os.clock()
		while box.Parent and rays.Parent do
			local t = os.clock() - t0
			rays.Rotation = t * 9
			halo.Size = UDim2.fromOffset(420 + 18 * math.sin(t * 1.6), 420 + 18 * math.sin(t * 1.6))
			task.wait(1 / 30)
		end
	end)
	-- The fanfare's whole first phrase, the music bowing under it.
	pcall(Sound.briefDip, 9.5)
	sound("levelFanfare", 0.9)
	task.delay(0.15, sound, "shimmerFall", 0.8)
	-- (A burst of gold flakes round the guest only for every tenth level: the big ones. The rest
	-- are the moment and the fanfare, no fireworks.)
	local big = level % 10 == 0
	if big then
		Flakes.fall({
			seconds = 3.5,
			centre = function(): Vector3?
				local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				return if r and r:IsA("BasePart") then r.Position else nil
			end,
			colours = { colour, rgb(255, 240, 200), rgb(255, 214, 110) },
			material = Enum.Material.SmoothPlastic,
			size = Vector3.new(0.34, 0.02, 0.18),
			count = 60,
			radius = 9,
			height = 10,
			fall = 3,
			flutter = 3,
			burst = true,
		})
	end
	-- Out: after a good look, it lifts and fades away together, unhurried.
	task.delay(6.2, function()
		if not box.Parent then
			return
		end
		local out = 1.3
		ease(scale, out, { Scale = 1.06 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		ease(box, out, { Position = UDim2.new(0.5, 0, 0.38, -16) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		ease(halo, out, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
		ease(disc, out, { BackgroundTransparency = 1, TextTransparency = 1 }, Enum.EasingStyle.Sine)
		ease(ring, out, { Transparency = 1 }, Enum.EasingStyle.Sine)
		for _, beam in beams do
			ease(beam, out, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
		end
		for _, l in { head, shineLabel, name, reward } do
			ease(l, out, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Sine)
		end
		task.delay(out + 0.05, function()
			box:Destroy()
		end)
	end)
end

-- (Build 96) A haul worth celebrating, in Steal a Luxe (the server decides which: server
-- Attractions/Luxe):
--   first    a new guest's very first haul, whatever it's worth: the biggest moment, words to
--            the middle of the screen, the worth counting up, a long burst of gold, a fanfare,
--            and a key to the Boutique (a key only: it opens nothing by itself)
--   record   a new best haul; big / massive: one far above the guest's usual
-- Every other haul is the plain toast, as before. Returns the kind shown, or nil.
Celebrate.openBoutique = function() end

function Celebrate.haulKind(m: { [string]: any }): string?
	if m.first == true then
		return "first"
	elseif m.size == "massive" then
		return "massive"
	elseif m.record == true then
		return "record"
	elseif m.size == "big" then
		return "big"
	end
	return nil
end

-- How long a haul's moment stays up (the notice with its details waits until it's gone).
function Celebrate.haulSeconds(kind: string): number
	return if kind == "first" then 7 else 3.6
end

local HAUL_WORDS = {
	first = { head = "YOUR FIRST HAUL!", line = "Banked. Every haul makes you richer." },
	record = { head = "NEW BEST HAUL!", line = "Your biggest haul yet." },
	big = { head = "BIG HAUL!", line = "Twice your usual." },
	massive = { head = "MASSIVE HAUL!", line = "Far above your usual." },
}

function Celebrate.haul(m: { [string]: any }): string?
	local kind = Celebrate.haulKind(m)
	if not kind then
		return nil
	end
	local words = HAUL_WORDS[kind]
	local gilt = tonumber(m.gilt) or 0
	local gui = screen()
	local old = gui:FindFirstChild("Haul")
	if old then
		old:Destroy()
	end
	local big = kind == "first" or kind == "massive"
	-- (On a short screen, a phone held sideways, it sits lower and a size down: clear of the keys
	-- along the top.)
	local camera = workspace.CurrentCamera
	local tall = if camera then camera.ViewportSize.Y else 720
	local short = tall < 500
	local finalScale = if short then math.clamp((tall - 150) / 268, 0.6, 0.85) else 1
	local box = Instance.new("Frame")
	box.Name = "Haul"
	box:SetAttribute("Kind", kind)
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, if short then 0.62 else 0.36)
	box.Size = UDim2.fromOffset(if big then 560 else 480, if kind == "first" then 268 else 200)
	box.Parent = gui
	local fit = Instance.new("UISizeConstraint")
	fit.MaxSize = Vector2.new(if big then 560 else 480, 268)
	fit.Parent = box
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = box
	local head = Instance.new("TextLabel")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, if big then 60 else 48)
	head.FontFace = IMPACT
	head.TextScaled = true
	head.TextColor3 = Color3.new(1, 1, 1)
	head.TextStrokeTransparency = 0.2
	head.TextStrokeColor3 = rgb(36, 22, 4)
	head.Text = words.head
	local metal = Instance.new("UIGradient")
	metal.Rotation = 90
	metal.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 250, 226)),
		ColorSequenceKeypoint.new(0.5, rgb(255, 214, 120)),
		ColorSequenceKeypoint.new(1, rgb(214, 150, 50)),
	})
	metal.Parent = head
	head.Parent = box
	local amount = Instance.new("TextLabel")
	amount.Name = "Worth"
	amount.BackgroundTransparency = 1
	amount.Position = UDim2.fromOffset(0, if big then 68 else 54)
	amount.Size = UDim2.new(1, 0, 0, if big then 70 else 56)
	amount.FontFace = HEAVY
	amount.TextScaled = true
	amount.TextColor3 = rgb(255, 236, 160)
	amount.TextStrokeTransparency = 0.3
	amount.Text = "+0"
	amount.Parent = box
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(0, if big then 144 else 116)
	line.Size = UDim2.new(1, 0, 0, 26)
	line.FontFace = BODY
	line.TextScaled = true
	line.TextColor3 = Color3.new(1, 1, 1)
	line.TextStrokeTransparency = 0.4
	-- (Build 102) The big number is the exact Gilt credited; no Estate sums to work out.
	line.Text = words.line
	line.Parent = box
	if kind == "first" then
		local key = Instance.new("TextButton")
		key.Name = "Boutique"
		key.AnchorPoint = Vector2.new(0.5, 0)
		key.Position = UDim2.new(0.5, 0, 0, 186)
		key.Size = UDim2.fromOffset(300, 44)
		key.BackgroundColor3 = rgb(255, 206, 90)
		key.FontFace = HEAVY
		key.TextSize = 17
		key.TextColor3 = rgb(36, 22, 4)
		key.Text = "Spend it in the Boutique ›"
		key.Parent = box
		corner(key, 22)
		key.Activated:Connect(function()
			box:Destroy()
			Celebrate.openBoutique()
		end)
		local hint = Instance.new("TextLabel")
		hint.Name = "Hint"
		hint.BackgroundTransparency = 1
		hint.Position = UDim2.fromOffset(0, 236)
		hint.Size = UDim2.new(1, 0, 0, 22)
		hint.FontFace = BODY
		hint.TextScaled = true
		hint.TextColor3 = rgb(230, 220, 200)
		hint.TextStrokeTransparency = 0.5
		hint.Text = "Boosters, brainrots and nameplates. Or keep stealing: bigger bags, bigger hauls."
		hint.Parent = box
	end
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = finalScale }):Play()
	sound(if big then "regalFanfare" else "kaching", 0.9)
	task.delay(0.2, sound, "shimmerFall", 0.8)
	-- The worth, counting up to what the server said.
	task.spawn(function()
		local steps = 24
		for i = 1, steps do
			if not box.Parent then
				return
			end
			amount.Text = "+" .. format(gilt * i / steps) .. " GILT"
			task.wait(0.04)
		end
		amount.Text = "+" .. format(gilt) .. " GILT"
	end)
	Flakes.fall({
		seconds = if big then 4.5 else 3,
		centre = function(): Vector3?
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			return if r and r:IsA("BasePart") then r.Position else nil
		end,
		colours = { rgb(255, 214, 110), rgb(255, 240, 200), rgb(120, 220, 130) },
		material = Enum.Material.SmoothPlastic,
		size = Vector3.new(0.34, 0.02, 0.18),
		count = if kind == "first" then 140 elseif kind == "massive" then 110 else 60,
		radius = 10,
		height = 11,
		fall = 3,
		flutter = 3,
		burst = true,
	})
	task.delay(Celebrate.haulSeconds(kind), function()
		if box.Parent then
			local t = TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.01 })
			t:Play()
			t.Completed:Once(function()
				box:Destroy()
			end)
		end
	end)
	return kind
end

-- Badges wait their turn, one card at a time.
local queue: { { [string]: any } } = {}
local showing = false

local function nextBadge()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local b = table.remove(queue, 1) :: { [string]: any }
	local colour = TIER[tostring(b.tier)] or rgb(246, 200, 92)
	local neo = { a = colour:Lerp(Color3.new(1, 1, 1), 0.25), b = colour, core = Color3.new(1, 1, 1) }
	local hasNext = type(b.nextName) == "string" and type(b.nextTarget) == "number"
	local gui = screen()
	-- A pane of dark glass at the side: the medal in a turning ring of its tier's light, the
	-- badge resolving in, how many the guest has now, and the next on the same ladder.
	local card = Instance.new("Frame")
	card.Name = "Badge"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, 380, 0.3, 0)
	card.Size = UDim2.fromOffset(350, if hasNext then 122 else 96)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0.04
	card.Parent = gui
	corner(card, 14)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new(rgb(24, 24, 32):Lerp(colour, 0.12), rgb(8, 8, 12))
	fill.Parent = card
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Thickness = 1.5
	edge.Color = Color3.new(1, 1, 1)
	edge.Parent = card
	NeoFX.shimmer(edge, neo, 30)
	-- The medal.
	local medal = Instance.new("Frame")
	medal.Name = "Medal"
	medal.BackgroundColor3 = colour
	medal.BackgroundTransparency = 0.82
	medal.Position = UDim2.fromOffset(14, 16)
	medal.Size = UDim2.fromOffset(64, 64)
	medal.Parent = card
	corner(medal, 32)
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = 2
	ring.Parent = medal
	local sweep = Instance.new("UIGradient")
	sweep.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, colour), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, colour) })
	sweep.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 0.9) })
	sweep.Parent = ring
	TweenService:Create(sweep, TweenInfo.new(2.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(0.66, 0.66)
	glyph.TextScaled = true
	glyph.Text = tostring(b.glyph or "🏅")
	glyph.Parent = medal
	local top = Instance.new("TextLabel")
	top.BackgroundTransparency = 1
	top.Position = UDim2.fromOffset(92, 12)
	top.Size = UDim2.new(1, -104, 0, 14)
	top.FontFace = NeoFX.MONO_BOLD
	top.TextSize = 11
	top.TextXAlignment = Enum.TextXAlignment.Left
	top.TextColor3 = neo.a
	top.Text = "BADGE EARNED  ·  " .. string.upper(tostring(b.tier or ""))
	top.Parent = card
	if type(b.count) == "number" and type(b.total) == "number" then
		-- (How many now, of how many.)
		local tally = Instance.new("TextLabel")
		tally.Name = "Tally"
		tally.BackgroundTransparency = 1
		tally.AnchorPoint = Vector2.new(1, 0)
		tally.Position = UDim2.new(1, -12, 0, 12)
		tally.Size = UDim2.fromOffset(90, 14)
		tally.FontFace = NeoFX.MONO
		tally.TextSize = 11
		tally.TextXAlignment = Enum.TextXAlignment.Right
		tally.TextColor3 = rgb(200, 196, 188)
		tally.Text = string.format("%d / %d", b.count, b.total)
		tally.Parent = card
		top.Size = UDim2.new(1, -200, 0, 14)
	end
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(92, 28)
	name.Size = UDim2.new(1, -104, 0, 24)
	name.FontFace = HEAVY
	name.TextSize = 19
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = rgb(250, 244, 230)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = tostring(b.name)
	name.Parent = card
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(92, 54)
	line.Size = UDim2.new(1, -104, 0, 28)
	line.FontFace = BODY
	line.TextSize = 11
	line.TextWrapped = true
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextColor3 = rgb(190, 184, 172)
	line.Text = tostring(b.line or "")
	line.Parent = card
	if hasNext then
		-- The next on the ladder, and how far along: a thin bar of the tier's light.
		local have = math.max(0, tonumber(b.nextHave) or 0)
		local target = math.max(1, tonumber(b.nextTarget) or 1)
		local nextLine = Instance.new("TextLabel")
		nextLine.Name = "Next"
		nextLine.BackgroundTransparency = 1
		nextLine.Position = UDim2.fromOffset(14, 88)
		nextLine.Size = UDim2.new(1, -28, 0, 14)
		nextLine.FontFace = NeoFX.MONO
		nextLine.TextSize = 11
		nextLine.TextXAlignment = Enum.TextXAlignment.Left
		nextLine.TextTruncate = Enum.TextTruncate.AtEnd
		nextLine.TextColor3 = rgb(214, 208, 198)
		nextLine.Text = string.format("NEXT:  %s  ·  %s / %s", string.upper(tostring(b.nextName)), format(math.min(have, target)), format(target))
		nextLine.Parent = card
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.BorderSizePixel = 0
		track.BackgroundColor3 = Color3.new(1, 1, 1)
		track.BackgroundTransparency = 0.88
		track.Position = UDim2.fromOffset(14, 106)
		track.Size = UDim2.new(1, -28, 0, 4)
		track.Parent = card
		corner(track, 2)
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = colour
		bar.Size = UDim2.fromScale(0, 1)
		bar.Parent = track
		corner(bar, 2)
		task.delay(0.5, function()
			if bar.Parent then
				TweenService:Create(bar, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromScale(math.clamp(have / target, 0.02, 1), 1) }):Play()
			end
		end)
	end
	TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, -14, 0.3, 0) }):Play()
	task.delay(0.12, function()
		if card.Parent and name.Parent then
			NeoFX.decode(name, name.Text, 0.35)
		end
	end)
	sound(if b.tier == "gold" or b.tier == "platinum" then "regalFanfare" else "shimmer", 0.7)
	task.delay(4.2, function()
		local out = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, 380, 0.3, 0) })
		out:Play()
		out.Completed:Once(function()
			card:Destroy()
			showing = false
			nextBadge()
		end)
	end)
end

-- Whether a badge is coming in at the side (the objective card steps aside for it).
function Celebrate.badgeUp(): boolean
	return showing
end

function Celebrate.badge(b: { [string]: any })
	table.insert(queue, b)
	nextBadge()
end

-- A new laurel of Maison Prestige: MAISON PRESTIGE over a medallion with its numeral in the
-- laurel's colour (a ring of light turning round it), the laurel's name in metal, what it brings
-- first, and gold leaves falling round the guest.
function Celebrate.prestige(level: number, name: string, numeral: string, colour: Color3, gift: string?)
	local gui = screen()
	local old = gui:FindFirstChild("Prestige")
	if old then
		old:Destroy()
	end
	local box = Instance.new("Frame")
	box.Name = "Prestige"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.38)
	box.Size = UDim2.fromOffset(540, 300)
	box.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = box
	local head = Instance.new("TextLabel")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 30)
	head.FontFace = HEAVY
	head.TextScaled = true
	head.TextColor3 = rgb(255, 236, 190)
	head.TextStrokeTransparency = 0.35
	head.TextStrokeColor3 = rgb(36, 22, 4)
	head.Text = "MAISON PRESTIGE"
	head.Parent = box
	local disc = Instance.new("TextLabel")
	disc.Name = "Medallion"
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.Position = UDim2.new(0.5, 0, 0, 40)
	disc.Size = UDim2.fromOffset(132, 132)
	disc.BackgroundColor3 = rgb(20, 16, 12)
	disc.FontFace = HEAVY
	disc.TextScaled = true
	disc.TextColor3 = colour
	disc.Text = numeral
	disc.Parent = box
	corner(disc, 66)
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Thickness = 6
	ring.Color = Color3.new(1, 1, 1)
	ring.Parent = disc
	-- (The ring's light turns: a band of white running round the laurel's colour.)
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour),
		ColorSequenceKeypoint.new(0.45, colour),
		ColorSequenceKeypoint.new(0.5, rgb(255, 255, 255)),
		ColorSequenceKeypoint.new(0.55, colour),
		ColorSequenceKeypoint.new(1, colour),
	})
	sheen.Parent = ring
	TweenService:Create(sheen, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	local dp = Instance.new("UIPadding")
	dp.PaddingTop = UDim.new(0, 30)
	dp.PaddingBottom = UDim.new(0, 30)
	dp.PaddingLeft = UDim.new(0, 20)
	dp.PaddingRight = UDim.new(0, 20)
	dp.Parent = disc
	local title = Instance.new("TextLabel")
	title.Name = "Laurel"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(0, 184)
	title.Size = UDim2.new(1, 0, 0, 46)
	title.FontFace = IMPACT
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.3
	title.TextStrokeColor3 = rgb(30, 20, 6)
	title.Text = string.upper(name)
	title.Parent = box
	local metal = Instance.new("UIGradient")
	metal.Rotation = 90
	metal.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, colour:Lerp(Color3.new(1, 1, 1), 0.7)),
		ColorSequenceKeypoint.new(0.5, colour),
		ColorSequenceKeypoint.new(1, colour:Lerp(Color3.new(0, 0, 0), 0.25)),
	})
	metal.Parent = title
	local line = Instance.new("TextLabel")
	line.Name = "Gift"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(0, 238)
	line.Size = UDim2.new(1, 0, 0, 24)
	line.FontFace = BODY
	line.TextScaled = true
	line.TextColor3 = rgb(255, 230, 170)
	line.TextStrokeTransparency = 0.45
	line.Text = string.format("Laurel %s  ·  %s", numeral, gift or "Yours for good")
	line.Parent = box
	local _ = level
	TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	sound("regalFanfare", 0.9)
	task.delay(0.2, sound, "shimmerFall", 0.85)
	Flakes.fall({
		seconds = 4.5,
		centre = function(): Vector3?
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			return if r and r:IsA("BasePart") then r.Position else nil
		end,
		colours = { colour, rgb(255, 228, 150), rgb(214, 170, 70) },
		material = Enum.Material.SmoothPlastic,
		size = Vector3.new(0.5, 0.02, 0.24),
		count = 80,
		radius = 10,
		height = 12,
		fall = 2.6,
		flutter = 3.4,
		burst = true,
	})
	task.delay(4.6, function()
		if box.Parent then
			local t = TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.01 })
			t:Play()
			t.Completed:Once(function()
				box:Destroy()
			end)
		end
	end)
end

return Celebrate

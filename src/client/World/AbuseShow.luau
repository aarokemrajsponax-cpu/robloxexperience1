--!strict
-- Admin Abuse as a show, on this screen. Every Admin Abuse is one of the house's nights (shared/
-- AbuseNights: fifty-odd of them), worked out here from its seed exactly as every server worked it
-- out, so every screen in every server sees the same night. The server says when it begins, which
-- realm the house is in and when AJKR sends a gift; everything is drawn here:
--   the opening   the night's own: a transmission, a countdown, the lights going out, the sky
--                 cracking, a vault door, a hyperspace jump, a hijacked signal, velvet curtains,
--                 BREAKING NEWS, a hacker's terminal, a portal, the bass pumping. The camera flies
--                 out over the house (from one of several angles). Then the drop: a flash, ADMIN
--                 ABUSE landing its own way (slammed, dropped, stamped, zoomed, split, flickered on
--                 like neon), tonight's night by name, a shockwave, confetti, and the music (the
--                 night's own playlist). At a table, the same over the sorting screen.
--   arriving late a welcome, naming tonight's night.
--   the realms    each night its own (fifteen in all); Mega Abuse moves from realm to realm: a
--                 glitch, a flash, "ENTERING · THE COSMOS", then the house in its colours, its own
--                 air round the guest (stars, sweets, embers, petals, rain, code...).
--   the cameos    AJKR's card (their crest, never a picture of their avatar) whenever a surprise
--                 lands, with their line for it; AJKR's giant over the house only on the few nights
--                 made for it (World/OwnerCameo).
--   the gifts     AJKR's gift: a card to open (and a golden box falling beside the guest, opened
--                 by walking into it); the server checks it and pays.
--   the finale    the night's own: fireworks, a shower of gold, a film's closing credits (starring
--                 the guest), a supernova, a confetti storm, or a curtain call; then the guest's
--                 haul (Gilt, gifts, golden pieces, realms, effects seen).
-- Nothing here changes anything kept: the server pays, this only shows.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AbuseNights = require(ReplicatedStorage.Shared.AbuseNights)
local Config = require(ReplicatedStorage.Shared.Config)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AbuseMusic = require(script.Parent.AbuseMusic)
local Fireworks = require(script.Parent.Fireworks)
local OwnerCameo = require(script.Parent.OwnerCameo)
local Sound = require(script.Parent.Parent.Sound)

local AbuseShow = {}

-- Hooks (set by Main).
AbuseShow.isBusy = function(): boolean
	return false -- at a table: the camera stays and nothing moves the guest
end
AbuseShow.cameraMoment = function(_shot: CFrame, _hold: number) end
AbuseShow.cameraShake = function(_size: number, _seconds: number) end

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local GOLD = rgb(255, 204, 110)
local GOLD_LIGHT = rgb(255, 238, 190)
local GOLD_DEEP = rgb(196, 140, 48)
local IMPACT = Font.fromEnum(Enum.Font.LuckiestGuy)
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local CONFETTI = { rgb(255, 60, 140), rgb(80, 140, 255), rgb(90, 255, 170), rgb(255, 214, 80), rgb(246, 206, 112), rgb(255, 240, 200), rgb(190, 90, 255) }

local function cfg(): { [string]: any }
	return (Config.data.Admin :: any).show
end

local function abusing(): boolean
	local ends = Workspace:GetAttribute("AbuseUntil")
	return type(ends) == "number" and ends > Workspace:GetServerTimeNow()
end

local function isMega(): boolean
	return Workspace:GetAttribute("AbuseMega") == true
end

local function sound(name: string, volume: number?, pitch: number?)
	pcall(Sound.play, name, volume or 1, pitch)
end

local function ownerName(): string
	return tostring(Config.data.Admin.ownerName or "The owner")
end

local function view(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

-- How big to draw, for this screen (a phone smaller, a big monitor larger).
local function unit(): number
	local v = view()
	return math.clamp(math.min(v.X / 1280, v.Y / 720), 0.5, 1.5)
end

---------------------------------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------------------------------
local function screen(): ScreenGui
	local gui = player:FindFirstChild("PlayerGui")
	local existing = gui and gui:FindFirstChild("MaisonAbuseShow")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonAbuseShow"
	s.IgnoreGuiInset = true
	s.ResetOnSpawn = false
	-- (Over the panels, notices and headlines; under the Owner Console.)
	s.DisplayOrder = 72
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = gui
	return s
end

local function frame(parent: Instance, name: string, colour: Color3, alpha: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = alpha
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, text: string, font: Font, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = text
	l.TextColor3 = colour
	l.TextScaled = true
	l.Parent = parent
	return l
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function golden(parent: Instance, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GOLD_LIGHT), ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(1, GOLD_DEEP) })
	g.Rotation = rotation or 90
	g.Parent = parent
end

local function tween(o: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(o, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- A burst of confetti from a point on the screen (falling, turning, gone in a couple of seconds).
local function confettiBurst(parent: Instance, at: Vector2, count: number, power: number)
	local bits: { { f: Frame, x: number, y: number, vx: number, vy: number, spin: number, age: number } } = {}
	for _ = 1, count do
		local size = math.random(6, 13)
		local f = frame(parent, "Confetti", CONFETTI[math.random(1, #CONFETTI)], 0)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.ZIndex = 60
		f.Size = UDim2.fromOffset(size, size * 0.55)
		local a = math.random() * math.pi * 2
		local speed = power * (0.45 + math.random() * 0.75)
		table.insert(bits, { f = f, x = at.X, y = at.Y, vx = math.cos(a) * speed, vy = math.sin(a) * speed - power * 0.35, spin = math.random(-720, 720), age = 0 })
	end
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		local alive = 0
		for _, b in bits do
			if b.f.Parent then
				b.age += dt
				b.vy += 1500 * dt
				b.vx *= 0.985
				b.x += b.vx * dt
				b.y += b.vy * dt
				b.f.Position = UDim2.fromOffset(b.x, b.y)
				b.f.Rotation += b.spin * dt
				b.f.BackgroundTransparency = math.clamp((b.age - 1.6) / 0.6, 0, 1)
				if b.age > 2.3 then
					b.f:Destroy()
				else
					alive += 1
				end
			end
		end
		if alive == 0 and conn then
			conn:Disconnect()
		end
	end)
end

-- A ring of light racing out from a point on the screen.
local function shockwave(parent: Instance, at: Vector2, colour: Color3, reach: number, seconds: number)
	local ring = frame(parent, "Shockwave", Color3.new(1, 1, 1), 1)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(at.X, at.Y)
	ring.Size = UDim2.fromOffset(20, 20)
	corner(ring, UDim.new(1, 0))
	local s = stroke(ring, colour, 16)
	tween(ring, seconds, { Size = UDim2.fromOffset(reach, reach) })
	tween(s, seconds, { Thickness = 2, Transparency = 1 })
	task.delay(seconds + 0.05, function()
		ring:Destroy()
	end)
end

---------------------------------------------------------------------------------------------------
-- The night (what this guest gets, for the finale)
---------------------------------------------------------------------------------------------------
type Night = {
	since: number,
	ends: number,
	gilt: number,
	gifts: number,
	golden: number,
	realms: { [string]: boolean },
	seen: { [string]: boolean }, -- the effects this guest saw tonight
	mega: boolean,
	-- Tonight's night: its name, its colours, its finale.
	name: string,
	glyph: string,
	palette: string,
	finale: string,
}
local night: Night? = nil
local skyHeld = false
local openingSeen = -math.huge -- when this screen last played the opening (os.clock)

local function giltNow(): number
	local g = player:GetAttribute("Gilt")
	return if type(g) == "number" then g else 0
end

-- A golden piece filed during the night (TableClient says).
function AbuseShow.noteGolden(_gilt: number?)
	local n = night
	if n then
		n.golden += 1
	end
end

---------------------------------------------------------------------------------------------------
-- The opening
---------------------------------------------------------------------------------------------------
local openingToken = 0

-- Tonight's night, worked out on this screen from its seed exactly as every server worked it out.
local function planOf(seed: number?, mega: boolean, nightId: string?): AbuseNights.Plan?
	local s = AbuseNights.cleanSeed(seed)
	if not s then
		return nil
	end
	return AbuseNights.plan(s, mega, 0, nightId, { giant = cfg().giant })
end
local function currentPlan(): AbuseNights.Plan?
	local seed = Workspace:GetAttribute("AbuseSeed")
	local id = Workspace:GetAttribute("AbuseNight")
	return planOf(if type(seed) == "number" then seed else nil, isMega(), if type(id) == "string" then id else nil)
end
AbuseShow.currentPlan = currentPlan

local function paletteOf(plan: AbuseNights.Plan?): AbuseNights.Palette
	return (if plan then AbuseNights.Palettes[plan.palette] else nil) or AbuseNights.Palettes.gold
end

-- A gradient in the night's colours (Mega Abuse, or a rainbow night: every colour).
local function painted(parent: Instance, P: AbuseNights.Palette, mega: boolean, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	if mega or P.rainbow then
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 80, 200)), ColorSequenceKeypoint.new(0.35, rgb(255, 214, 80)), ColorSequenceKeypoint.new(0.7, rgb(90, 255, 200)), ColorSequenceKeypoint.new(1, rgb(150, 110, 255)) })
	else
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.light), ColorSequenceKeypoint.new(0.5, P.main), ColorSequenceKeypoint.new(1, P.deep) })
	end
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

-- A line drawn between two points on the screen (a crack, a streak).
local function line(parent: Instance, a: Vector2, b: Vector2, thickness: number, colour: Color3, alpha: number?): Frame
	local d = b - a
	local f = frame(parent, "Line", colour, alpha or 0)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(d.Magnitude, thickness)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	return f
end

-- The shots of the house from outside for the opening (not at a table): high over the street,
-- low from the pavement, from the side over the Terrace, from high above; AJKR's giant, on its
-- nights, framed behind the house.
local function establishing(plan: AbuseNights.Plan?): CFrame
	local S = Layout.SCALE
	local front = Layout.Foyer.minZ * S
	if plan and plan.giant then
		local feet = OwnerCameo.where()
		local eye = Vector3.new(feet.X + 46, 108, front - 130)
		return CFrame.lookAt(eye, Vector3.new(feet.X, 170, feet.Z))
	end
	local house = Vector3.new(0, 34, 60 * S)
	-- (Each one looked at in the 3D viewer: the whole lit house, from wherever the night picks.)
	local shots = {
		CFrame.lookAt(Vector3.new(40, 110, front - 140), house), -- high, from the front right
		CFrame.lookAt(Vector3.new(-14, 9, front - 70), house + Vector3.new(0, 30, 0)), -- low, at the door
		CFrame.lookAt(Vector3.new(-150, 70, front - 107), Vector3.new(0, 30, 60)), -- down the street from the west
		CFrame.lookAt(Vector3.new(-90, 150, front - 157), Vector3.new(0, 20, 70)), -- high, from the front left
		CFrame.lookAt(Vector3.new(0, 40, front - 187), Vector3.new(0, 40, 60)), -- straight on, across the street
	}
	local pick = if plan then (plan.seed % #shots) + 1 else 1
	return shots[pick]
end

type Ctx = {
	root: Frame,
	holo: Frame,
	u: number,
	v: Vector2,
	centre: Vector2,
	P: AbuseNights.Palette,
	mega: boolean,
	plan: AbuseNights.Plan?,
	dropAt: number,
	my: number,
	step: ((t: number, hard: number, dt: number) -> ())?,
	atDrop: (() -> ())?,
}

local function still(c: Ctx): boolean
	return openingToken == c.my and c.root.Parent ~= nil
end

local function later(c: Ctx, seconds: number, fn: () -> ())
	task.delay(seconds, function()
		if still(c) then
			fn()
		end
	end)
end

local OPENINGS: { [string]: (Ctx) -> () } = {}

-- AJKR's crest in a ring of gold, an incoming transmission, the words glitching harder and harder.
OPENINGS.transmission = function(c: Ctx)
	local u, centre, P = c.u, c.centre, c.P
	local d = 230 * u
	local ring = frame(c.holo, "Ring", rgb(20, 14, 8), 0.1)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(centre.X, centre.Y - 30 * u)
	ring.Size = UDim2.fromOffset(d, d)
	ring.ZIndex = 6
	corner(ring, UDim.new(1, 0))
	local ringEdge = stroke(ring, P.main, 5 * u)
	local ringScale = Instance.new("UIScale")
	ringScale.Scale = 0.2
	ringScale.Parent = ring
	tween(ringScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	OwnerCameo.crest(ring, P.main)
	local pulses: { Frame } = {}
	for i = 1, 3 do
		local p = frame(c.holo, "Pulse", Color3.new(1, 1, 1), 1)
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = ring.Position
		p.Size = UDim2.fromOffset(d, d)
		p.ZIndex = 5
		corner(p, UDim.new(1, 0))
		stroke(p, if c.mega then rgb(200, 120, 255) else P.main, 3)
		p:SetAttribute("Phase", (i - 1) / 3)
		table.insert(pulses, p)
	end
	local chip = label(c.holo, "Live", "●  LIVE  ·  INCOMING TRANSMISSION", HEAVY, Color3.new(1, 1, 1))
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = rgb(220, 30, 60)
	chip.AnchorPoint = Vector2.new(0.5, 1)
	chip.Position = UDim2.fromOffset(centre.X, centre.Y - 30 * u - d / 2 - 14 * u)
	chip.Size = UDim2.fromOffset(330 * u, 28 * u)
	chip.ZIndex = 8
	corner(chip, UDim.new(0, 14 * u))
	local name = label(c.holo, "Name", string.upper(ownerName()), IMPACT, Color3.new(1, 1, 1))
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromOffset(centre.X, centre.Y - 30 * u + d / 2 + 16 * u)
	name.Size = UDim2.fromOffset(math.min(c.v.X - 40, 640 * u), 58 * u)
	name.ZIndex = 8
	painted(name, P, false)
	stroke(name, rgb(40, 24, 6), 3)
	local whatAt = centre.Y - 30 * u + d / 2 + 78 * u
	local what = label(c.holo, "What", if c.mega then "HAS BROKEN THE MULTIVERSE" else "IS ABUSING THEIR POWERS", HEAVY, Color3.new(1, 1, 1))
	what.AnchorPoint = Vector2.new(0.5, 0)
	what.Position = UDim2.fromOffset(centre.X, whatAt)
	what.Size = UDim2.fromOffset(math.min(c.v.X - 40, 560 * u), 32 * u)
	what.ZIndex = 8
	local ghostR = label(c.holo, "GhostR", what.Text, HEAVY, rgb(255, 40, 80))
	ghostR.AnchorPoint = what.AnchorPoint
	ghostR.Position = what.Position
	ghostR.Size = what.Size
	ghostR.TextTransparency = 0.45
	ghostR.ZIndex = 7
	local ghostB = ghostR:Clone()
	ghostB.Name = "GhostB"
	ghostB.TextColor3 = rgb(40, 200, 255)
	ghostB.Parent = c.holo
	sound("glitch", 0.8)
	c.step = function(t: number, hard: number)
		for _, p in pulses do
			local k = ((t * 1.1) + (p:GetAttribute("Phase") :: number)) % 1
			p.Size = UDim2.fromOffset(d * (1 + k * 1.3), d * (1 + k * 1.3))
			local s = p:FindFirstChildOfClass("UIStroke")
			if s then
				s.Transparency = k
			end
		end
		ringEdge.Transparency = 0.1 + 0.3 * math.abs(math.sin(t * 7))
		chip.BackgroundTransparency = if math.floor(t * 3) % 2 == 0 then 0 else 0.3
		local jump = if math.random() < 0.18 + hard * 0.4 then (math.random() - 0.5) * 14 * u * (0.5 + hard) else 0
		what.Position = UDim2.fromOffset(centre.X + jump, whatAt)
		ghostR.Position = UDim2.fromOffset(centre.X + jump - 5 * u * (0.5 + hard), whatAt)
		ghostB.Position = UDim2.fromOffset(centre.X + jump + 5 * u * (0.5 + hard), whatAt)
		ringScale.Scale = 1 + hard * 0.08 + (if math.random() < hard * 0.3 then 0.04 else 0)
	end
end

-- 3, 2, 1: each number slammed onto the screen, bigger than the last, each its own colour.
OPENINGS.countdown = function(c: Ctx)
	local u, centre, P = c.u, c.centre, c.P
	local kicker = label(c.holo, "Kicker", "★  " .. string.upper(ownerName()) .. " SAYS GET READY  ★", HEAVY, P.light)
	kicker.AnchorPoint = Vector2.new(0.5, 0.5)
	kicker.Position = UDim2.fromOffset(centre.X, centre.Y - 190 * u)
	kicker.Size = UDim2.fromOffset(math.min(c.v.X - 40, 620 * u), 30 * u)
	kicker.ZIndex = 8
	local colours = { P.main, P.accent, P.deep:Lerp(Color3.new(1, 1, 1), 0.3) }
	local step = (c.dropAt - 0.6) / 3
	for i = 1, 3 do
		later(c, 0.3 + (i - 1) * step, function()
			local old = c.holo:FindFirstChild("Number")
			if old then
				old:Destroy()
			end
			local n = label(c.holo, "Number", tostring(4 - i), IMPACT, colours[i])
			n.AnchorPoint = Vector2.new(0.5, 0.5)
			n.Position = UDim2.fromOffset(centre.X, centre.Y)
			n.Size = UDim2.fromOffset(300 * u, 300 * u * (0.8 + i * 0.12))
			n.ZIndex = 9
			stroke(n, rgb(20, 12, 4), 6)
			local s = Instance.new("UIScale")
			s.Scale = 2.6
			s.Parent = n
			tween(s, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
			shockwave(c.holo, centre, colours[i], 520 * u * (0.7 + i * 0.2), 0.5)
			sound("lowHit", 0.9 + i * 0.1, 0.9 + i * 0.08)
			sound("tick", 1, 1 + i * 0.1)
			pcall(AbuseShow.cameraShake, 0.3 + i * 0.15, 0.25)
		end)
	end
	c.step = function(t: number)
		kicker.TextTransparency = 0.15 + 0.15 * math.sin(t * 9)
		local n = c.holo:FindFirstChild("Number")
		if n and n:IsA("TextLabel") then
			n.Rotation = math.sin(t * 20) * 2
		end
	end
end

-- The lights go out; one spotlight hunts round the dark and comes to rest in the middle.
OPENINGS.blackout = function(c: Ctx)
	local u, centre, v, P = c.u, c.centre, c.v, c.P
	local dark = frame(c.holo, "Dark", Color3.new(0, 0, 0), 1)
	dark.Size = UDim2.fromScale(1, 1)
	dark.ZIndex = 4
	tween(dark, 0.15, { BackgroundTransparency = 0.06 })
	sound("lowHit", 1, 0.7)
	sound("click", 1, 0.6)
	local r = 190 * u
	local beam = frame(c.holo, "Spotlight", P.light, 0.55)
	beam.AnchorPoint = Vector2.new(0.5, 0.5)
	beam.Size = UDim2.fromOffset(r * 2, r * 2)
	beam.ZIndex = 5
	corner(beam, UDim.new(1, 0))
	for i, spec in { { 1.7, 0.94 }, { 1.45, 0.9 }, { 1.2, 0.84 } } do
		local halo = frame(beam, "Halo" .. i, P.light, spec[2])
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.Size = UDim2.fromScale(spec[1], spec[1])
		halo.ZIndex = 4
		corner(halo, UDim.new(1, 0))
	end
	local core = frame(beam, "Core", Color3.new(1, 1, 1), 0.7)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.55, 0.55)
	core.ZIndex = 6
	corner(core, UDim.new(1, 0))
	beam.Visible = false
	later(c, 0.5, function()
		beam.Visible = true
		sound("lowHit", 0.9, 0.9)
	end)
	local words = label(c.holo, "Words", "LIGHTS OUT.  " .. string.upper(ownerName()) .. " HAS THE REMOTE.", HEAVY, P.light)
	words.AnchorPoint = Vector2.new(0.5, 1)
	words.Position = UDim2.new(0.5, 0, 0.86, 0)
	words.Size = UDim2.fromOffset(math.min(v.X - 40, 700 * u), 30 * u)
	words.ZIndex = 8
	words.MaxVisibleGraphemes = 0
	c.step = function(t: number, hard: number)
		-- (Round the dark, closing in on the middle as the drop nears.)
		local wander = 1 - hard
		local x = centre.X + math.sin(t * 1.9) * v.X * 0.34 * wander
		local y = centre.Y + math.sin(t * 2.7 + 1) * v.Y * 0.26 * wander
		beam.Position = UDim2.fromOffset(x, y)
		words.MaxVisibleGraphemes = math.floor(math.max(0, t - 0.8) * 26)
	end
end

-- The screen cracks, wider and wider, and shatters outwards at the drop.
OPENINGS.skyCrack = function(c: Ctx)
	local u, centre, v, P = c.u, c.centre, c.v, c.P
	local rng = Random.new((if c.plan then c.plan.seed else 1) % 100000)
	local cracks: { { f: Frame, at: number } } = {}
	local branches = 9
	for b = 1, branches do
		local a = (b / branches) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
		local from = centre
		local length = math.max(v.X, v.Y) * rng:NextNumber(0.35, 0.75)
		local steps = 6
		for i = 1, steps do
			a += rng:NextNumber(-0.45, 0.45)
			local to = from + Vector2.new(math.cos(a), math.sin(a)) * (length / steps)
			local seg = line(c.holo, from, to, math.max(1.5, (5 - i * 0.6) * u), P.light, 0.05)
			seg.ZIndex = 7
			seg.Visible = false
			stroke(seg, P.main, 1.5)
			table.insert(cracks, { f = seg, at = (i - 1) / steps * 0.9 + rng:NextNumber(0, 0.08) })
			from = to
		end
	end
	local warn = label(c.holo, "Warning", "⚠  REALITY IS CRACKING  ⚠", HEAVY, P.accent)
	warn.AnchorPoint = Vector2.new(0.5, 0.5)
	warn.Position = UDim2.new(0.5, 0, 0.2, 0)
	warn.Size = UDim2.fromOffset(math.min(v.X - 40, 640 * u), 34 * u)
	warn.ZIndex = 8
	local lastCrack = 0
	c.step = function(t: number, hard: number)
		local shown = 0
		for _, k in cracks do
			if hard >= k.at and not k.f.Visible then
				k.f.Visible = true
				shown += 1
			end
		end
		if shown > 0 and t - lastCrack > 0.12 then
			lastCrack = t
			sound("crystal", 0.5 + hard * 0.5, 0.7 + math.random() * 0.4)
		end
		c.holo.Position = UDim2.fromOffset((math.random() - 0.5) * 10 * u * hard, (math.random() - 0.5) * 8 * u * hard)
		warn.TextTransparency = if math.floor(t * 6) % 2 == 0 then 0 else 0.5
	end
	-- The shatter: shards of the picture flying outwards.
	c.atDrop = function()
		for _ = 1, 22 do
			local size = rng:NextNumber(40, 120) * u
			local shard = frame(c.root, "Shard", P.light, 0.25)
			shard.AnchorPoint = Vector2.new(0.5, 0.5)
			shard.Position = UDim2.fromOffset(centre.X + rng:NextNumber(-80, 80) * u, centre.Y + rng:NextNumber(-60, 60) * u)
			shard.Size = UDim2.fromOffset(size, size * rng:NextNumber(0.3, 0.8))
			shard.Rotation = rng:NextNumber(0, 360)
			shard.ZIndex = 16
			stroke(shard, Color3.new(1, 1, 1), 1.5)
			local a = rng:NextNumber(0, math.pi * 2)
			local far = math.max(v.X, v.Y) * 0.9
			tween(shard, rng:NextNumber(0.6, 1), { Position = UDim2.fromOffset(centre.X + math.cos(a) * far, centre.Y + math.sin(a) * far), Rotation = shard.Rotation + rng:NextNumber(-360, 360), BackgroundTransparency = 1 }, Enum.EasingStyle.Quad)
			task.delay(1.1, function()
				shard:Destroy()
			end)
		end
		sound("crystal", 1, 0.5)
	end
end

-- A vault door: the wheel spins, the bolts slide back, the door swings open, gold light floods out.
OPENINGS.vault = function(c: Ctx)
	local u, centre, v, P = c.u, c.centre, c.v, c.P
	local d = math.min(v.Y * 0.5, 360 * u)
	local glow = frame(c.holo, "Glow", P.main, 1)
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromOffset(centre.X, centre.Y)
	glow.Size = UDim2.fromOffset(d, d)
	glow.ZIndex = 4
	corner(glow, UDim.new(1, 0))
	local door = frame(c.holo, "Door", Color3.new(1, 1, 1), 0)
	door.AnchorPoint = Vector2.new(0.5, 0.5)
	door.Position = UDim2.fromOffset(centre.X, centre.Y)
	door.Size = UDim2.fromOffset(d, d)
	door.ZIndex = 5
	corner(door, UDim.new(1, 0))
	local metal = Instance.new("UIGradient")
	metal.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(120, 112, 100)), ColorSequenceKeypoint.new(0.5, rgb(60, 56, 52)), ColorSequenceKeypoint.new(1, rgb(30, 28, 26)) })
	metal.Rotation = 60
	metal.Parent = door
	stroke(door, P.main, 6 * u)
	local inner = frame(door, "Inner", Color3.new(1, 1, 1), 1)
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.78, 0.78)
	inner.ZIndex = 6
	corner(inner, UDim.new(1, 0))
	stroke(inner, P.deep, 3 * u)
	local bolts: { { f: Frame, a: number } } = {}
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local b = frame(door, "Bolt", P.main, 0)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Size = UDim2.fromOffset(18 * u, 18 * u)
		b.ZIndex = 7
		corner(b, UDim.new(1, 0))
		painted(b, P, false)
		table.insert(bolts, { f = b, a = a })
	end
	local wheel = frame(door, "Wheel", Color3.new(1, 1, 1), 1)
	wheel.AnchorPoint = Vector2.new(0.5, 0.5)
	wheel.Position = UDim2.fromScale(0.5, 0.5)
	wheel.Size = UDim2.fromScale(0.5, 0.5)
	wheel.ZIndex = 8
	for i = 0, 2 do
		local spoke = frame(wheel, "Spoke", P.main, 0)
		spoke.AnchorPoint = Vector2.new(0.5, 0.5)
		spoke.Position = UDim2.fromScale(0.5, 0.5)
		spoke.Size = UDim2.new(1, 0, 0, 12 * u)
		spoke.Rotation = i * 60
		spoke.ZIndex = 8
		corner(spoke, UDim.new(1, 0))
		painted(spoke, P, false, 0)
	end
	local hub = frame(wheel, "Hub", P.light, 0)
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(0.3, 0.3)
	hub.ZIndex = 9
	corner(hub, UDim.new(1, 0))
	local title = label(c.holo, "Words", "THE VAULT IS OPENING", HEAVY, P.light)
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.fromOffset(centre.X, centre.Y + d / 2 + 14 * u)
	title.Size = UDim2.fromOffset(math.min(v.X - 40, 560 * u), 30 * u)
	title.ZIndex = 9
	local slid = false
	local opened = false
	local spin = 0
	c.step = function(_t: number, hard: number, dt: number)
		spin += dt * (60 + hard * 720)
		wheel.Rotation = spin
		local out = if hard > 0.55 then math.clamp((hard - 0.55) / 0.2, 0, 1) else 0
		if out > 0 and not slid then
			slid = true
			sound("slide", 1, 0.7)
			sound("lowHit", 0.8)
		end
		for _, b in bolts do
			local r = 0.45 + out * 0.09
			b.f.Position = UDim2.fromScale(0.5 + math.cos(b.a) * r, 0.5 + math.sin(b.a) * r)
		end
		if hard > 0.82 and not opened then
			opened = true
			sound("kaching", 1)
			sound("heavenly", 0.8)
			-- The door swings open (seen edge-on), the gold light behind it pouring out.
			tween(door, 0.55, { Size = UDim2.fromOffset(d * 0.06, d), Position = UDim2.fromOffset(centre.X - d * 0.47, centre.Y) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			glow.BackgroundTransparency = 0.1
			tween(glow, 0.7, { Size = UDim2.fromOffset(math.max(v.X, v.Y) * 1.6, math.max(v.X, v.Y) * 1.6), BackgroundTransparency = 0.35 })
		end
	end
end

-- Hyperspace: streaks of starlight racing out from the middle, faster and faster.
OPENINGS.warp = function(c: Ctx)
	local u, centre, v, P = c.u, c.centre, c.v, c.P
	local far = math.max(v.X, v.Y) * 0.8
	local streaks: { { f: Frame, a: number, r: number, speed: number } } = {}
	for _ = 1, 80 do
		local f = frame(c.holo, "Streak", if math.random() < 0.6 then Color3.new(1, 1, 1) else P.light, 0.1)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.ZIndex = 6
		table.insert(streaks, { f = f, a = math.random() * math.pi * 2, r = math.random() * far, speed = 0.6 + math.random() * 0.8 })
	end
	local core = frame(c.holo, "Core", P.light, 0.3)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromOffset(centre.X, centre.Y)
	core.Size = UDim2.fromOffset(20 * u, 20 * u)
	core.ZIndex = 7
	corner(core, UDim.new(1, 0))
	local words = label(c.holo, "Words", "ENGAGING HYPERDRIVE", HEAVY, P.light)
	words.AnchorPoint = Vector2.new(0.5, 1)
	words.Position = UDim2.new(0.5, 0, 0.86, 0)
	words.Size = UDim2.fromOffset(math.min(v.X - 40, 520 * u), 28 * u)
	words.ZIndex = 8
	sound("warpBuild", 1)
	later(c, math.max(0, c.dropAt - 1.2), function()
		sound("riseWhoosh", 1)
	end)
	c.step = function(t: number, hard: number, dt: number)
		local pace = 120 + hard * hard * 2600
		for _, s in streaks do
			s.r += dt * pace * s.speed * (0.3 + s.r / far)
			if s.r > far then
				s.r = math.random() * 40 * u
			end
			local length = math.max(4, (8 + hard * 140) * u * (0.4 + s.r / far))
			local mid = s.r + length / 2
			s.f.Position = UDim2.fromOffset(centre.X + math.cos(s.a) * mid, centre.Y + math.sin(s.a) * mid)
			s.f.Size = UDim2.fromOffset(length, math.max(1.5, 2.5 * u * (0.5 + s.r / far)))
			s.f.Rotation = math.deg(s.a)
		end
		local k = 20 + hard * 160
		core.Size = UDim2.fromOffset(k * u, k * u)
		words.TextTransparency = if math.floor(t * 4) % 2 == 0 then 0 else 0.4
	end
end

-- A hijacked signal: static, scanlines, error windows popping up all over.
local ERRORS = { "TOO MUCH ABUSE DETECTED", "GRAVITY.EXE HAS STOPPED WORKING", "FUN LEVELS CRITICAL", "ADMIN.DLL OVERLOADED", "THE HOUSE IS NOT RESPONDING", "CHILL NOT FOUND", "WARNING: GILT OVERFLOW", "ERROR 404: CALM", "RULES.TXT DELETED", "CPU: 9999% HYPE" }
OPENINGS.hijack = function(c: Ctx)
	local u, v, P = c.u, c.v, c.P
	local cols, rows = 16, 9
	local cells: { Frame } = {}
	for y = 0, rows - 1 do
		for x = 0, cols - 1 do
			local f = frame(c.holo, "Static", Color3.new(0.5, 0.5, 0.5), 0.6)
			f.Position = UDim2.fromScale(x / cols, y / rows)
			f.Size = UDim2.fromScale(1 / cols + 0.002, 1 / rows + 0.002)
			f.ZIndex = 4
			table.insert(cells, f)
		end
	end
	local scan = frame(c.holo, "Scan", P.main, 0.75)
	scan.Size = UDim2.new(1, 0, 0, 40 * u)
	scan.ZIndex = 5
	local banner = label(c.holo, "Hijacked", "SIGNAL HIJACKED", IMPACT, Color3.new(1, 1, 1))
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.42)
	banner.Size = UDim2.fromOffset(math.min(v.X - 30, 820 * u), 110 * u)
	banner.ZIndex = 40
	stroke(banner, rgb(20, 10, 10), 4)
	local red = label(c.holo, "GhostR", banner.Text, IMPACT, rgb(255, 40, 80))
	red.AnchorPoint = banner.AnchorPoint
	red.Size = banner.Size
	red.TextTransparency = 0.4
	red.ZIndex = 39
	local blue = red:Clone()
	blue.Name = "GhostB"
	blue.TextColor3 = rgb(40, 210, 255)
	blue.Parent = c.holo
	local by = label(c.holo, "By", "BY " .. string.upper(ownerName()), HEAVY, P.main)
	by.AnchorPoint = Vector2.new(0.5, 0)
	by.Position = UDim2.new(0.5, 0, 0.42, 62 * u)
	by.Size = UDim2.fromOffset(400 * u, 30 * u)
	by.ZIndex = 40
	sound("glitch", 1)
	sound("recordScratch", 0.8)
	local popped = 0
	local nextPop = 0.4
	c.step = function(t: number, hard: number)
		for _, f in cells do
			local g = math.random()
			f.BackgroundColor3 = Color3.new(g, g, g)
			f.BackgroundTransparency = 0.55 + math.random() * 0.35
		end
		scan.Position = UDim2.new(0, 0, (t * 0.9) % 1, 0)
		local jump = (math.random() - 0.5) * 18 * u * (0.4 + hard)
		banner.Position = UDim2.new(0.5, jump, 0.42, 0)
		red.Position = UDim2.new(0.5, jump - 6 * u, 0.42, 0)
		blue.Position = UDim2.new(0.5, jump + 6 * u, 0.42, 0)
		if t >= nextPop and popped < 12 then
			popped += 1
			nextPop = t + 0.28 - hard * 0.15
			local w = frame(c.holo, "Error", rgb(235, 235, 240), 0)
			w.Size = UDim2.fromOffset(260 * u, 84 * u)
			w.Position = UDim2.fromOffset(math.random() * math.max(1, v.X - 260 * u), math.random() * math.max(1, v.Y - 84 * u))
			w.ZIndex = 10 + popped
			corner(w, UDim.new(0, 6 * u))
			stroke(w, rgb(40, 40, 50), 2)
			local bar = frame(w, "Bar", if popped % 2 == 0 then rgb(220, 40, 60) else P.deep, 0)
			bar.Size = UDim2.new(1, 0, 0, 22 * u)
			bar.ZIndex = w.ZIndex
			corner(bar, UDim.new(0, 6 * u))
			local head = label(bar, "Head", "⚠ ERROR", HEAVY, Color3.new(1, 1, 1))
			head.Position = UDim2.fromOffset(8 * u, 3 * u)
			head.Size = UDim2.new(1, -16 * u, 1, -6 * u)
			head.TextXAlignment = Enum.TextXAlignment.Left
			head.ZIndex = w.ZIndex
			local msg = label(w, "Message", ERRORS[(popped - 1) % #ERRORS + 1], BOLD, rgb(30, 30, 40))
			msg.Position = UDim2.fromOffset(10 * u, 30 * u)
			msg.Size = UDim2.new(1, -20 * u, 0, 40 * u)
			msg.TextWrapped = true
			msg.ZIndex = w.ZIndex
			local s = Instance.new("UIScale")
			s.Scale = 0.3
			s.Parent = w
			tween(s, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
			sound("wrong", 0.5, 1 + popped * 0.04)
		end
	end
end

-- Velvet curtains, a drumroll, a spotlight; the curtains part at the drop.
OPENINGS.curtain = function(c: Ctx)
	local u, v, P = c.u, c.v, c.P
	local halves: { Frame } = {}
	for i = 0, 1 do
		local h = frame(c.root, "Curtain", Color3.new(1, 1, 1), 0)
		h.Size = UDim2.new(0.5, 2, 1, 0)
		h.Position = UDim2.fromScale(i * 0.5, 0)
		h.ZIndex = 18
		local folds = Instance.new("UIGradient")
		local keys = {}
		for k = 0, 8 do
			table.insert(keys, ColorSequenceKeypoint.new(k / 8, if k % 2 == 0 then rgb(150, 18, 34) else rgb(84, 6, 18)))
		end
		folds.Color = ColorSequence.new(keys)
		folds.Parent = h
		local hem = frame(h, "Hem", P.main, 0)
		hem.AnchorPoint = Vector2.new(0, 1)
		hem.Position = UDim2.fromScale(0, 1)
		hem.Size = UDim2.new(1, 0, 0, 10 * u)
		hem.ZIndex = 19
		table.insert(halves, h)
	end
	local spot = frame(c.root, "Spot", P.light, 0.78)
	spot.AnchorPoint = Vector2.new(0.5, 0.5)
	spot.Position = UDim2.fromScale(0.5, 0.48)
	spot.Size = UDim2.fromOffset(460 * u, 460 * u)
	spot.ZIndex = 19
	corner(spot, UDim.new(1, 0))
	local words = label(c.root, "Presents", "LADIES AND GENTLEMEN...", IMPACT, P.light)
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Position = UDim2.fromScale(0.5, 0.48)
	words.Size = UDim2.fromOffset(math.min(v.X - 40, 760 * u), 70 * u)
	words.ZIndex = 20
	stroke(words, rgb(40, 6, 12), 3)
	later(c, c.dropAt * 0.5, function()
		words.Text = string.upper(ownerName()) .. " PRESENTS..."
		sound("bellStrike", 0.7)
	end)
	sound("applause", 0.4)
	-- The drumroll: quicker and quicker.
	local beats = 0
	local nextBeat = 0.2
	c.step = function(t: number, hard: number)
		if t >= nextBeat then
			beats += 1
			nextBeat = t + math.max(0.06, 0.22 - hard * 0.18)
			sound("fireworkTaiko", 0.35 + hard * 0.4, 1.4 + hard * 0.4)
		end
		spot.Size = UDim2.fromOffset((440 + math.sin(t * 6) * 20) * u, (440 + math.sin(t * 6) * 20) * u)
	end
	c.atDrop = function()
		words:Destroy()
		spot:Destroy()
		sound("applause", 0.9)
		tween(halves[1], 0.9, { Position = UDim2.fromScale(-0.52, 0) }, Enum.EasingStyle.Quint)
		tween(halves[2], 0.9, { Position = UDim2.fromScale(1.02, 0) }, Enum.EasingStyle.Quint)
		task.delay(1, function()
			for _, h in halves do
				h:Destroy()
			end
		end)
	end
end

-- BREAKING NEWS: the bars, the headline, the ticker running along the bottom.
OPENINGS.breaking = function(c: Ctx)
	local u, v, P = c.u, c.v, c.P
	local back = frame(c.holo, "Studio", Color3.new(1, 1, 1), 0.35)
	back.Size = UDim2.fromScale(1, 1)
	back.ZIndex = 4
	local studio = Instance.new("UIGradient")
	studio.Color = ColorSequence.new(P.deep:Lerp(Color3.new(0, 0, 0), 0.5), rgb(6, 6, 12))
	studio.Rotation = 120
	studio.Parent = back
	local stripes: { Frame } = {}
	for i = 1, 8 do
		local s = frame(c.holo, "Stripe", P.main, 0.88)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Size = UDim2.fromOffset(60 * u, v.Y * 2)
		s.Rotation = 25
		s.ZIndex = 4
		s:SetAttribute("Phase", i / 8)
		table.insert(stripes, s)
	end
	local width = math.min(v.X - 40, 900 * u)
	local red = label(c.holo, "Breaking", "  BREAKING NEWS  ", IMPACT, Color3.new(1, 1, 1))
	red.BackgroundTransparency = 0
	red.BackgroundColor3 = rgb(210, 20, 40)
	red.AnchorPoint = Vector2.new(0, 1)
	red.Position = UDim2.new(0.5, -width / 2, 0.68, 0)
	red.Size = UDim2.fromOffset(width * 0.42, 54 * u)
	red.ZIndex = 8
	red.TextXAlignment = Enum.TextXAlignment.Left
	local headline = label(c.holo, "Headline", string.upper(ownerName()) .. " HAS TAKEN OVER THE HOUSE", HEAVY, rgb(20, 20, 30))
	headline.BackgroundTransparency = 0
	headline.BackgroundColor3 = Color3.new(1, 1, 1)
	headline.AnchorPoint = Vector2.new(0, 0)
	headline.Position = UDim2.new(0.5, -width / 2, 0.68, 0)
	headline.Size = UDim2.fromOffset(width, 48 * u)
	headline.ZIndex = 8
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12 * u)
	pad.PaddingTop = UDim.new(0, 8 * u)
	pad.PaddingBottom = UDim.new(0, 8 * u)
	pad.Parent = headline
	local live = label(c.holo, "Live", "● LIVE", HEAVY, Color3.new(1, 1, 1))
	live.BackgroundTransparency = 0
	live.BackgroundColor3 = rgb(210, 20, 40)
	live.AnchorPoint = Vector2.new(1, 1)
	live.Position = UDim2.new(0.5, width / 2, 0.68, 0)
	live.Size = UDim2.fromOffset(96 * u, 30 * u)
	live.ZIndex = 8
	corner(live, UDim.new(0, 6 * u))
	local tickerBar = frame(c.holo, "TickerBar", P.deep, 0.05)
	tickerBar.AnchorPoint = Vector2.new(0, 1)
	tickerBar.Position = UDim2.fromScale(0, 0.89)
	tickerBar.Size = UDim2.new(1, 0, 0, 34 * u)
	tickerBar.ZIndex = 8
	tickerBar.ClipsDescendants = true
	local nightName = if c.plan then c.plan.night.name else "ADMIN ABUSE"
	local ticker = label(tickerBar, "Ticker", "GILT DOUBLED  ◆  GRAVITY OPTIONAL  ◆  EXPERTS BAFFLED  ◆  TONIGHT: " .. nightName .. "  ◆  STAY IN THE SERVER  ◆  GIFTS INCOMING  ◆  ", HEAVY, P.light)
	ticker.Size = UDim2.new(3, 0, 1, -8 * u)
	ticker.Position = UDim2.fromOffset(v.X, 4 * u)
	ticker.TextXAlignment = Enum.TextXAlignment.Left
	ticker.ZIndex = 9
	local slide = Instance.new("UIScale")
	slide.Scale = 0
	slide.Parent = red
	tween(slide, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	sound("stinger", 1)
	later(c, 0.4, function()
		sound("chime", 0.8, 1.2)
	end)
	c.step = function(t: number)
		for _, s in stripes do
			local k = ((t * 0.25) + (s:GetAttribute("Phase") :: number)) % 1
			s.Position = UDim2.fromOffset(-200 * u + k * (v.X + 400 * u), v.Y / 2)
		end
		ticker.Position = UDim2.fromOffset(v.X - t * 420 * u, 4 * u)
		live.BackgroundTransparency = if math.floor(t * 2) % 2 == 0 then 0 else 0.4
	end
end

-- A hacker's terminal: the command types itself, the bar fills, ACCESS GRANTED.
OPENINGS.terminal = function(c: Ctx)
	local u, v, P = c.u, c.v, c.P
	local w = math.min(v.X - 40, 760 * u)
	local h = math.min(v.Y - 120 * u, 330 * u)
	local term = frame(c.holo, "Terminal", rgb(8, 10, 12), 0.04)
	term.AnchorPoint = Vector2.new(0.5, 0.5)
	term.Position = UDim2.fromScale(0.5, 0.46)
	term.Size = UDim2.fromOffset(w, h)
	term.ZIndex = 6
	corner(term, UDim.new(0, 10 * u))
	stroke(term, P.main, 2)
	local bar = frame(term, "TitleBar", rgb(36, 38, 44), 0)
	bar.Size = UDim2.new(1, 0, 0, 26 * u)
	bar.ZIndex = 7
	corner(bar, UDim.new(0, 10 * u))
	for i, col in { rgb(255, 95, 86), rgb(255, 189, 46), rgb(39, 201, 63) } do
		local dot = frame(bar, "Dot", col, 0)
		dot.Position = UDim2.fromOffset((8 + (i - 1) * 20) * u, 7 * u)
		dot.Size = UDim2.fromOffset(12 * u, 12 * u)
		dot.ZIndex = 8
		corner(dot, UDim.new(1, 0))
	end
	local titleText = label(bar, "Title", "ajkr@maison-noir: ~", BOLD, rgb(200, 200, 210))
	titleText.Size = UDim2.new(1, 0, 1, -8 * u)
	titleText.Position = UDim2.fromOffset(0, 4 * u)
	titleText.ZIndex = 8
	local nightName = if c.plan then c.plan.night.name else "ADMIN ABUSE"
	local lines = {
		"> sudo admin_abuse --everyone --max",
		"[ok] gravity.dll ... unloaded",
		"[ok] gilt multiplier ... x" .. tostring(if c.mega then (Config.data.Admin :: any).table.megaGilt else Config.data.Admin.goldenHourGilt),
		"[ok] night ... " .. nightName,
		"[ok] chill ... not found",
		"> run",
	}
	local text = label(term, "Text", "", Font.fromEnum(Enum.Font.Code), P.main)
	text.TextScaled = false
	text.TextSize = math.max(12, math.floor(19 * u))
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Position = UDim2.fromOffset(16 * u, 36 * u)
	text.Size = UDim2.new(1, -32 * u, 1, -90 * u)
	text.ZIndex = 8
	text.Text = table.concat(lines, "\n")
	text.MaxVisibleGraphemes = 0
	local total = utf8.len(text.Text) or #text.Text
	local progress = frame(term, "Progress", P.deep, 0.3)
	progress.AnchorPoint = Vector2.new(0.5, 1)
	progress.Position = UDim2.new(0.5, 0, 1, -16 * u)
	progress.Size = UDim2.new(1, -32 * u, 0, 18 * u)
	progress.ZIndex = 8
	corner(progress, UDim.new(0, 4 * u))
	local fill = frame(progress, "Fill", P.main, 0)
	fill.Size = UDim2.fromScale(0, 1)
	fill.ZIndex = 9
	corner(fill, UDim.new(0, 4 * u))
	local granted = false
	local lastShown = 0
	c.step = function(t: number, hard: number)
		local shown = math.floor(math.clamp(t / (c.dropAt * 0.7), 0, 1) * total)
		if shown > lastShown then
			text.MaxVisibleGraphemes = shown
			if shown - lastShown >= 2 then
				sound("click", 0.35, 1 + math.random() * 0.3)
			end
			lastShown = shown
		end
		fill.Size = UDim2.fromScale(math.clamp((hard - 0.55) / 0.35, 0, 1), 1)
		if hard >= 0.9 and not granted then
			granted = true
			sound("complete", 1)
			local yes = label(c.holo, "Granted", "ACCESS GRANTED", IMPACT, P.main)
			yes.AnchorPoint = Vector2.new(0.5, 0.5)
			yes.Position = UDim2.fromScale(0.5, 0.46)
			yes.Size = UDim2.fromOffset(math.min(v.X - 40, 700 * u), 90 * u)
			yes.ZIndex = 12
			stroke(yes, rgb(0, 20, 0), 4)
		end
	end
end

-- A portal opening in the middle of the screen, swirling, pulling motes of light in.
OPENINGS.portal = function(c: Ctx)
	local u, centre, v, P = c.u, c.centre, c.v, c.P
	local d = math.min(v.Y * 0.7, 460 * u)
	-- (Everything in a box over the whole screen, centred, so it grows from the middle.)
	local box = frame(c.holo, "Box", Color3.new(0, 0, 0), 1)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromScale(1, 1)
	box.ZIndex = 5
	local rings: { { f: Frame, g: UIGradient, speed: number } } = {}
	for i = 1, 5 do
		local f = frame(box, "Ring", Color3.new(1, 1, 1), 1)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(centre.X, centre.Y)
		f.Size = UDim2.fromOffset(d * (1 - (i - 1) * 0.16), d * (1 - (i - 1) * 0.16))
		f.ZIndex = 5 + i
		corner(f, UDim.new(1, 0))
		local s = stroke(f, Color3.new(1, 1, 1), (8 - i) * u)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, P.main), ColorSequenceKeypoint.new(0.5, P.accent), ColorSequenceKeypoint.new(1, P.deep) })
		g.Parent = s
		table.insert(rings, { f = f, g = g, speed = (if i % 2 == 0 then -1 else 1) * (90 + i * 40) })
	end
	local core = frame(box, "Core", P.light, 0.2)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromOffset(centre.X, centre.Y)
	core.Size = UDim2.fromOffset(d * 0.2, d * 0.2)
	core.ZIndex = 11
	corner(core, UDim.new(1, 0))
	local coreScale = Instance.new("UIScale")
	coreScale.Scale = 0.3
	coreScale.Parent = core
	local motes: { { f: Frame, a: number, r: number } } = {}
	for _ = 1, 40 do
		local f = frame(box, "Mote", if math.random() < 0.5 then P.light else P.main, 0)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(6 * u, 6 * u)
		f.ZIndex = 12
		corner(f, UDim.new(1, 0))
		table.insert(motes, { f = f, a = math.random() * math.pi * 2, r = d * (0.5 + math.random() * 0.9) })
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = box
	sound("magicZoom", 1)
	sound("warpBuild", 0.8)
	c.step = function(_t: number, hard: number, dt: number)
		scale.Scale = 0.25 + hard * 0.95
		for _, r in rings do
			r.g.Rotation = (r.g.Rotation + r.speed * dt * (1 + hard * 2)) % 360
		end
		coreScale.Scale = 0.3 + hard * 1.2
		for _, m in motes do
			m.a += dt * (2 + 400 / math.max(20, m.r))
			m.r -= dt * (40 + 260 * hard) * u
			if m.r < 10 * u then
				m.r = d * (0.6 + math.random() * 0.8)
			end
			m.f.Position = UDim2.fromOffset(centre.X + math.cos(m.a) * m.r, centre.Y + math.sin(m.a) * m.r)
		end
	end
end

-- The bass: the screen pumps on every beat, faster and faster, the words calling the drop.
local PULSE_WORDS = { "GET", "READY", "FOR", "THE", "DROP", "3", "2", "1" }
OPENINGS.pulse = function(c: Ctx)
	local u, v, P = c.u, c.v, c.P
	local colours = { P.main, P.accent, P.deep:Lerp(Color3.new(1, 1, 1), 0.3), P.light }
	local edge = frame(c.holo, "Edge", Color3.new(1, 1, 1), 1)
	edge.Size = UDim2.fromScale(1, 1)
	edge.ZIndex = 4
	local edgeStroke = stroke(edge, P.main, 30 * u)
	edgeStroke.Transparency = 1
	local word = label(c.holo, "Word", "", IMPACT, Color3.new(1, 1, 1))
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.45)
	word.Size = UDim2.fromOffset(math.min(v.X - 40, 700 * u), 160 * u)
	word.ZIndex = 9
	stroke(word, rgb(12, 8, 18), 5)
	local wordScale = Instance.new("UIScale")
	wordScale.Parent = word
	local bars: { Frame } = {}
	local count = 16
	for i = 1, count do
		local b = frame(c.holo, "Bar", colours[(i - 1) % #colours + 1], 0.1)
		b.AnchorPoint = Vector2.new(0.5, 1)
		b.Position = UDim2.new((i - 0.5) / count, 0, 0.92, 0)
		b.Size = UDim2.new(0.8 / count, 0, 0, 20 * u)
		b.ZIndex = 6
		corner(b, UDim.new(0, 4 * u))
		table.insert(bars, b)
	end
	local beat = 0
	local nextBeat = 0.1
	c.step = function(t: number, hard: number)
		if t >= nextBeat and beat < 40 then
			beat += 1
			nextBeat = t + math.max(0.11, 0.48 - hard * 0.4)
			local colour = colours[(beat - 1) % #colours + 1]
			word.Text = PULSE_WORDS[math.min(#PULSE_WORDS, math.floor(hard * #PULSE_WORDS) + 1)]
			word.TextColor3 = colour
			wordScale.Scale = 1.35
			tween(wordScale, 0.16, { Scale = 1 }, Enum.EasingStyle.Quad)
			edgeStroke.Color = colour
			edgeStroke.Transparency = 0.2
			tween(edgeStroke, 0.25, { Transparency = 1 })
			sound(if beat % 2 == 0 then "subHit" else "lowHit", 0.6 + hard * 0.4, 1 + hard * 0.2)
			for _, b in bars do
				b.Size = UDim2.new(0.8 / count, 0, 0, (20 + math.random() * 200 * (0.4 + hard)) * u)
				tween(b, 0.22, { Size = UDim2.new(0.8 / count, 0, 0, 16 * u) })
			end
		end
	end
end

-- The titles: ADMIN ABUSE (or MEGA ABUSE) landing on the screen, in the night's own way.
local TITLES: { [string]: (Ctx, TextLabel, UDim2) -> () } = {}

-- Slammed down, huge, a red and a blue ghost closing in on it.
TITLES.slam = function(c: Ctx, title: TextLabel, at: UDim2)
	local scale = Instance.new("UIScale")
	scale.Scale = 3.2
	scale.Parent = title
	tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	for i, colour in { rgb(255, 40, 90), rgb(40, 210, 255) } do
		local ghost = label(c.root, "Ghost", title.Text, IMPACT, colour)
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.Size = title.Size
		ghost.Position = at + UDim2.fromOffset((if i == 1 then -40 else 40) * c.u, 0)
		ghost.TextTransparency = 0.35
		ghost.ZIndex = 16
		tween(ghost, 0.7, { Position = at, TextTransparency = 1 }, Enum.EasingStyle.Quint)
		task.delay(0.75, function()
			ghost:Destroy()
		end)
	end
end

-- Falls from the top and bounces to a stop.
TITLES.drop = function(c: Ctx, title: TextLabel, at: UDim2)
	title.Position = at - UDim2.fromOffset(0, c.v.Y * 0.6)
	tween(title, 0.75, { Position = at }, Enum.EasingStyle.Bounce)
end

-- Letter by letter, each stamped down. (The letters are the title's own: they lift away with it.)
TITLES.stamp = function(c: Ctx, title: TextLabel)
	title.TextTransparency = 1
	local stroked = title:FindFirstChildOfClass("UIStroke")
	if stroked then
		stroked.Transparency = 1
	end
	local text = title.Text
	local n = #text
	for i = 1, n do
		local ch = string.sub(text, i, i)
		if ch ~= " " then
			task.delay((i - 1) * 0.055, function()
				if not title.Parent then
					return
				end
				local l = label(title, "Letter", ch, IMPACT, Color3.new(1, 1, 1))
				l.AnchorPoint = Vector2.new(0.5, 0.5)
				l.Position = UDim2.fromScale(0.12 + 0.76 * (i - 0.5) / n, 0.5)
				l.Size = UDim2.fromScale(0.76 * 1.2 / n, 1)
				l.ZIndex = 17
				painted(l, c.P, c.mega)
				stroke(l, rgb(30, 16, 4), 4)
				local s = Instance.new("UIScale")
				s.Scale = 2.2
				s.Parent = l
				tween(s, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
				sound("lowHit", 0.35, 1.2 + i * 0.03)
			end)
		end
	end
end

-- From a dot, spinning up to full size.
TITLES.zoom = function(_c: Ctx, title: TextLabel)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.05
	scale.Parent = title
	title.Rotation = -200
	tween(scale, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(title, 0.6, { Rotation = 0 }, Enum.EasingStyle.Quint)
end

-- Two halves sliding in from either side and locking together. (The halves are the title's own:
-- they lift away with it.)
TITLES.split = function(c: Ctx, title: TextLabel, at: UDim2)
	local words = string.split(title.Text, " ")
	if #words < 2 then
		TITLES.slam(c, title, at)
		return
	end
	title.TextTransparency = 1
	local stroked = title:FindFirstChildOfClass("UIStroke")
	if stroked then
		stroked.Transparency = 1
	end
	local gap = 8 * c.u
	for i, word in { words[1], table.concat(words, " ", 2) } do
		local l = label(title, "Half", word, IMPACT, Color3.new(1, 1, 1))
		l.AnchorPoint = Vector2.new(if i == 1 then 1 else 0, 0.5)
		l.Size = UDim2.fromScale(0.5, 1)
		l.TextXAlignment = if i == 1 then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left
		l.ZIndex = 17
		painted(l, c.P, c.mega)
		stroke(l, rgb(30, 16, 4), 5)
		local rest = if i == 1 then -gap else gap
		local from = if i == 1 then -c.v.X * 0.7 else c.v.X * 0.7
		l.Position = UDim2.new(0.5, from + rest, 0.5, 0)
		tween(l, 0.42, { Position = UDim2.new(0.5, rest, 0.5, 0) }, Enum.EasingStyle.Quint)
	end
	task.delay(0.42, function()
		sound("subHit", 0.8)
		pcall(AbuseShow.cameraShake, 0.6, 0.3)
	end)
end

-- A neon sign buzzing to life.
TITLES.flicker = function(c: Ctx, title: TextLabel)
	local glow = title:FindFirstChildOfClass("UIStroke")
	if glow then
		glow.Color = c.P.main
		glow.Thickness = 6
	end
	task.spawn(function()
		for _, on in { false, true, false, false, true, false, true, true } do
			if not title.Parent then
				return
			end
			title.TextTransparency = if on then 0 else 0.85
			if glow then
				glow.Transparency = if on then 0.1 else 0.9
			end
			if on then
				sound("click", 0.5, 1.6)
			end
			task.wait(0.07)
		end
		title.TextTransparency = 0
	end)
end

function AbuseShow.opening(mega: boolean, seed: number?, nightId: string?)
	openingToken += 1
	local my = openingToken
	openingSeen = os.clock()
	local s = cfg()
	local dropAt: number = s.dropAt
	local total: number = s.seconds
	local u = unit()
	local v = view()
	local centre = Vector2.new(v.X / 2, v.Y * 0.44)
	local plan = planOf(seed, mega, nightId) or currentPlan()
	local P = paletteOf(plan)
	local style = if plan and OPENINGS[plan.opening] then plan.opening else "transmission"
	local titleStyle = if plan and TITLES[plan.title] then plan.title else "slam"
	local gui = screen()
	for _, name in { "Opening", "Arrival" } do
		local old = gui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local root = frame(gui, "Opening", Color3.new(0, 0, 0), 1)
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 1
	root:SetAttribute("Style", style)
	root:SetAttribute("TitleStyle", titleStyle)
	-- The picture darkens; cinema bars close in.
	local dim = frame(root, "Dim", Color3.new(0, 0, 0), 1)
	dim.Size = UDim2.fromScale(1, 1)
	tween(dim, 0.5, { BackgroundTransparency = 0.45 })
	local top = frame(root, "BarTop", Color3.new(0, 0, 0), 0)
	top.Size = UDim2.fromScale(1, 0)
	top.ZIndex = 20
	local bottom = frame(root, "BarBottom", Color3.new(0, 0, 0), 0)
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.fromScale(1, 0)
	bottom.ZIndex = 20
	tween(top, 0.5, { Size = UDim2.fromScale(1, 0.11) })
	tween(bottom, 0.5, { Size = UDim2.fromScale(1, 0.11) })
	-- What comes before the drop (the night's own opening), in its own layer.
	local holo = frame(root, "Transmission", Color3.new(0, 0, 0), 1)
	holo.Size = UDim2.fromScale(1, 1)
	holo.ZIndex = 5
	local ctx: Ctx = { root = root, holo = holo, u = u, v = v, centre = centre, P = P, mega = mega, plan = plan, dropAt = dropAt, my = my, step = nil, atDrop = nil }
	local ok, err = pcall(function()
		OPENINGS[style](ctx)
	end)
	if not ok then
		warn("[Maison] opening " .. style .. ": " .. tostring(err))
	end
	-- Flash and title, ready for the drop.
	local flash = frame(root, "Flash", Color3.new(1, 1, 1), 1)
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 15
	-- The music waits for the drop; the house's music falls away under the riser.
	pcall(AbuseMusic.holdFor, dropAt)
	pcall(Sound.hush, dropAt)
	sound("showRiser", 1)
	task.delay(math.max(0, dropAt - 2.75), function()
		if openingToken == my then
			sound("showBuild", 1)
		end
	end)
	task.delay(0.5, function()
		if openingToken == my then
			sound("heavenly", 0.5)
		end
	end)
	-- AJKR's giant (on its nights) rises behind the house; the camera flies out to see the house
	-- (not at a table).
	if plan and plan.giant then
		OwnerCameo.colossus(true, dropAt - 0.2, mega)
	end
	if not AbuseShow.isBusy() then
		pcall(AbuseShow.cameraMoment, establishing(plan), math.max(1, total - 3.2))
	end
	-- (The opening has the screen and the camera: no "Watch the fireworks" key over it.)
	pcall(Fireworks.hideWatch, total)
	local started = os.clock()
	local dropped = false
	local shakeLeft = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		if openingToken ~= my or not root.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local t = os.clock() - started
		if not dropped and ctx.step then
			local step = ctx.step :: (number, number, number) -> ()
			local stepOk, stepErr = pcall(function()
				step(t, math.clamp(t / dropAt, 0, 1), dt)
			end)
			if not stepOk then
				warn("[Maison] opening " .. style .. ": " .. tostring(stepErr))
				ctx.step = nil
			end
		end
		if shakeLeft > 0 then
			shakeLeft = math.max(0, shakeLeft - dt)
			local k = shakeLeft / 0.8
			root.Position = UDim2.fromOffset((math.random() - 0.5) * 34 * k * u, (math.random() - 0.5) * 24 * k * u)
		else
			root.Position = UDim2.fromOffset(0, 0)
		end
	end)
	-- The drop.
	task.delay(dropAt, function()
		if openingToken ~= my or not root.Parent then
			return
		end
		dropped = true
		holo:Destroy()
		if ctx.atDrop then
			pcall(ctx.atDrop :: () -> ())
		end
		flash.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(P.light, 0.3)
		flash.BackgroundTransparency = 0
		tween(flash, 0.9, { BackgroundTransparency = 1 })
		tween(dim, 0.4, { BackgroundTransparency = 0.6 })
		shakeLeft = 0.8
		sound("showDrop", 1.1)
		sound("sonicBoom", 1)
		sound("subHit", 1)
		for i = 0, 2 do
			task.delay(i * 0.32, function()
				sound("airHorn", 1, 1 + i * 0.06)
			end)
		end
		task.delay(0.5, sound, "crowdCheer", 0.8)
		pcall(AbuseShow.cameraShake, 1.4, 0.9)
		-- The title, landing the night's own way.
		local words = if mega then "MEGA ABUSE" else "ADMIN ABUSE"
		local titleSize = UDim2.fromOffset(math.min(v.X - 30, 980 * u), 150 * u)
		local titleAt = UDim2.fromOffset(centre.X, centre.Y)
		local title = label(root, "Title", words, IMPACT, Color3.new(1, 1, 1))
		title.AnchorPoint = Vector2.new(0.5, 0.5)
		title.Position = titleAt
		title.Size = titleSize
		-- (Over the flash: the words land on the white, then the picture comes back round them.)
		title.ZIndex = 17
		painted(title, P, mega)
		stroke(title, rgb(30, 16, 4), 5)
		local landed, landErr = pcall(function()
			TITLES[titleStyle](ctx, title, titleAt)
		end)
		if not landed then
			warn("[Maison] title " .. titleStyle .. ": " .. tostring(landErr))
		end
		-- Above it, tonight's night by name; below it, what it brings.
		if plan then
			local kicker = label(root, "Night", plan.night.glyph .. "  TONIGHT:  " .. plan.night.name .. "  " .. plan.night.glyph, HEAVY, P.light)
			kicker.AnchorPoint = Vector2.new(0.5, 1)
			kicker.Position = UDim2.fromOffset(centre.X, centre.Y - 80 * u)
			kicker.Size = UDim2.fromOffset(math.min(v.X - 40, 760 * u), 30 * u)
			kicker.ZIndex = 17
			stroke(kicker, rgb(20, 12, 4), 2)
			kicker.TextTransparency = 1
			task.delay(0.2, function()
				tween(kicker, 0.35, { TextTransparency = 0 })
			end)
		end
		local sub = label(root, "Sub", if mega then "TRIPLE GILT  ·  A NEW REALM EVERY FEW MINUTES  ·  GIFTS FROM " .. string.upper(ownerName()) .. "  ·  GIVEAWAYS" else "DOUBLE GILT  ·  GOLDEN PIECES  ·  GIFTS FROM " .. string.upper(ownerName()) .. "  ·  SURPRISES ALL NIGHT", HEAVY, P.light)
		sub.AnchorPoint = Vector2.new(0.5, 0)
		sub.Position = UDim2.fromOffset(centre.X, centre.Y + 82 * u)
		sub.Size = UDim2.fromOffset(math.min(v.X - 40, 860 * u), 26 * u)
		sub.ZIndex = 17
		sub.TextTransparency = 1
		task.delay(0.35, function()
			tween(sub, 0.4, { TextTransparency = 0 })
		end)
		shockwave(root, centre, if mega then rgb(220, 140, 255) else P.main, math.max(v.X, v.Y) * 1.8, 0.8)
		task.delay(0.12, shockwave, root, centre, Color3.new(1, 1, 1), math.max(v.X, v.Y) * 1.2, 0.7)
		confettiBurst(root, centre, 90, 1100 * u)
	end)
	-- The way out: the title lifts away, the bars open.
	task.delay(total - 1.2, function()
		if openingToken ~= my or not root.Parent then
			return
		end
		local title = root:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			tween(title, 0.7, { Position = UDim2.fromOffset(centre.X, -80 * u), TextTransparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			local s2 = title:FindFirstChildOfClass("UIStroke")
			if s2 then
				tween(s2, 0.5, { Transparency = 1 })
			end
		end
		for _, name in { "Sub", "Night" } do
			local l = root:FindFirstChild(name)
			if l and l:IsA("TextLabel") then
				tween(l, 0.4, { TextTransparency = 1 })
				local s3 = l:FindFirstChildOfClass("UIStroke")
				if s3 then
					tween(s3, 0.4, { Transparency = 1 })
				end
			end
		end
		tween(top, 0.6, { Size = UDim2.fromScale(1, 0) })
		tween(bottom, 0.6, { Size = UDim2.fromScale(1, 0) })
		tween(dim, 0.6, { BackgroundTransparency = 1 })
	end)
	task.delay(total, function()
		if openingToken ~= my then
			return
		end
		root:Destroy()
		local hello = if mega then "MEGA ABUSE IS ON! The multiverse is open. Don't you dare leave! 🌋" else "ADMIN ABUSE IS ON! Gifts, golden pieces, surprises. Let's GO! 🔥"
		if plan then
			hello = (if mega then "MEGA ABUSE: " else "Tonight: ") .. plan.night.name .. "! " .. plan.night.line
		end
		OwnerCameo.say(hello, "cheer", 6, P.main)
		-- (Mega Abuse's first realm, named now the opening is over.)
		if mega then
			task.delay(0.6, AbuseShow.announceRealm)
		end
	end)
end

-- Arriving while it's on: a welcome, tonight's night by name (and AJKR's giant, on its nights).
function AbuseShow.arrived(mega: boolean)
	local plan = currentPlan()
	local P = paletteOf(plan)
	if plan and plan.giant then
		OwnerCameo.colossus(true, nil, mega)
	end
	local gui = screen()
	local u = unit()
	local v = view()
	local old = gui:FindFirstChild("Arrival")
	if old then
		old:Destroy()
	end
	local card = frame(gui, "Arrival", Color3.new(1, 1, 1), 0)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, -140 * u)
	card.Size = UDim2.fromOffset(math.min(v.X - 24, 640 * u), 122 * u)
	corner(card, UDim.new(0, 18 * u))
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(P.deep:Lerp(Color3.new(0, 0, 0), 0.55), rgb(12, 9, 6))
	fill.Rotation = 90
	fill.Parent = card
	stroke(card, if mega then rgb(210, 130, 255) else P.main, 2)
	local big = label(card, "Title", if mega then "YOU ARRIVED DURING MEGA ABUSE!" else "YOU ARRIVED DURING ADMIN ABUSE!", IMPACT, Color3.new(1, 1, 1))
	big.Position = UDim2.new(0, 16 * u, 0, 10 * u)
	big.Size = UDim2.new(1, -32 * u, 0, 44 * u)
	painted(big, P, mega)
	local which = label(card, "Night", if plan then plan.night.glyph .. "  TONIGHT: " .. plan.night.name else "TONIGHT: ADMIN ABUSE", HEAVY, P.light)
	which.Position = UDim2.new(0, 16 * u, 0, 58 * u)
	which.Size = UDim2.new(1, -32 * u, 0, 22 * u)
	local small = label(card, "Line", if mega then "Triple Gilt, a new realm every few minutes, gifts from " .. ownerName() .. "." else "Double Gilt, golden pieces at every table, gifts from " .. ownerName() .. ".", BOLD, rgb(240, 230, 210))
	small.Position = UDim2.new(0, 16 * u, 0, 86 * u)
	small.Size = UDim2.new(1, -32 * u, 0, 22 * u)
	sound("stinger", 0.8)
	tween(card, 0.5, { Position = UDim2.new(0.5, 0, 0, 70 * u) }, Enum.EasingStyle.Back)
	task.delay(5.5, function()
		if card.Parent then
			tween(card, 0.4, { Position = UDim2.new(0.5, 0, 0, -160 * u) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.45, function()
				card:Destroy()
			end)
		end
	end)
	OwnerCameo.say(if plan then "Welcome in! Tonight is " .. plan.night.name .. ". Grab the gifts! 🎁" else "Welcome in! You made it for Admin Abuse. Grab the gifts! 🎁", "wave", 5, P.main)
end

---------------------------------------------------------------------------------------------------
-- The realms
---------------------------------------------------------------------------------------------------
type Realm = {
	name: string,
	line: string,
	glyph: string,
	colour: Color3,
	tint: Color3,
	brightness: number,
	contrast: number,
	saturation: number,
	bloom: number,
	air: { colours: { Color3 }, rate: number, size: number, speed: number, fall: number, light: number },
	stars: boolean?,
}

-- How each realm looks (its name and line are HouseEvents.Realms').
local LOOKS = {
	gilded = { colour = GOLD, tint = rgb(255, 236, 205), brightness = 0.02, contrast = 0.1, saturation = 0.12, bloom = 0.7, air = { colours = { GOLD, GOLD_LIGHT }, rate = 26, size = 0.45, speed = 2, fall = -2, light = 1 } },
	cosmos = { colour = rgb(170, 150, 255), tint = rgb(190, 180, 255), brightness = -0.08, contrast = 0.2, saturation = 0.25, bloom = 1.1, air = { colours = { rgb(220, 220, 255), rgb(170, 140, 255), rgb(120, 200, 255) }, rate = 40, size = 0.35, speed = 1, fall = 0, light = 1 }, stars = true },
	candy = { colour = rgb(255, 130, 210), tint = rgb(255, 210, 238), brightness = 0.08, contrast = 0.05, saturation = 0.45, bloom = 0.9, air = { colours = { rgb(255, 120, 200), rgb(130, 230, 255), rgb(255, 240, 150) }, rate = 50, size = 0.6, speed = 3, fall = -3, light = 0.8 } },
	midas = { colour = rgb(255, 214, 90), tint = rgb(255, 218, 150), brightness = 0.05, contrast = 0.15, saturation = -0.2, bloom = 1.2, air = { colours = { rgb(255, 214, 90), rgb(255, 245, 200) }, rate = 60, size = 0.5, speed = 4, fall = 10, light = 1 } },
	neon = { colour = rgb(80, 255, 240), tint = rgb(205, 170, 255), brightness = -0.1, contrast = 0.4, saturation = 0.65, bloom = 1.6, air = { colours = { rgb(80, 255, 240), rgb(255, 60, 220), rgb(255, 240, 80) }, rate = 55, size = 0.4, speed = 6, fall = -8, light = 1 } },
	abyss = { colour = rgb(80, 200, 255), tint = rgb(150, 210, 255), brightness = -0.08, contrast = 0.1, saturation = 0.1, bloom = 0.8, air = { colours = { rgb(200, 240, 255), rgb(120, 210, 255) }, rate = 45, size = 0.7, speed = 3, fall = -6, light = 0.5 } },
	frost = { colour = rgb(210, 240, 255), tint = rgb(225, 242, 255), brightness = 0.1, contrast = 0.05, saturation = -0.35, bloom = 0.9, air = { colours = { Color3.new(1, 1, 1), rgb(220, 240, 255) }, rate = 220, size = 0.3, speed = 3, fall = 6, light = 0.5 } },
	-- (Embers rising.)
	inferno = { colour = rgb(255, 110, 40), tint = rgb(255, 205, 175), brightness = -0.02, contrast = 0.25, saturation = 0.2, bloom = 1.2, air = { colours = { rgb(255, 220, 120), rgb(255, 150, 50), rgb(255, 80, 30) }, rate = 70, size = 0.35, speed = 4, fall = -9, light = 1 } },
	-- (Soft light, drifting down like feathers.)
	heaven = { colour = rgb(255, 246, 220), tint = rgb(255, 250, 238), brightness = 0.14, contrast = -0.04, saturation = -0.1, bloom = 1.4, air = { colours = { Color3.new(1, 1, 1), rgb(255, 236, 190) }, rate = 30, size = 0.8, speed = 1, fall = 1, light = 0.6 } },
	-- (Green code, raining.)
	matrix = { colour = rgb(80, 255, 120), tint = rgb(190, 255, 200), brightness = -0.12, contrast = 0.35, saturation = -0.3, bloom = 1.3, air = { colours = { rgb(160, 255, 180), rgb(60, 230, 100) }, rate = 120, size = 0.25, speed = 10, fall = 24, light = 1 } },
	-- (Petals, falling.)
	sakura = { colour = rgb(255, 170, 210), tint = rgb(255, 230, 242), brightness = 0.06, contrast = 0.05, saturation = 0.15, bloom = 0.9, air = { colours = { rgb(255, 205, 228), rgb(255, 150, 200), Color3.new(1, 1, 1) }, rate = 60, size = 0.5, speed = 2, fall = 4, light = 0.4 } },
	-- (Neon dust, a sky of stars.)
	synthwave = { colour = rgb(255, 90, 200), tint = rgb(240, 182, 255), brightness = -0.05, contrast = 0.3, saturation = 0.5, bloom = 1.5, air = { colours = { rgb(255, 80, 200), rgb(80, 220, 255), rgb(255, 200, 90) }, rate = 45, size = 0.4, speed = 5, fall = -4, light = 1 }, stars = true },
	-- (Fireflies.)
	jungle = { colour = rgb(90, 230, 120), tint = rgb(205, 255, 210), brightness = -0.04, contrast = 0.15, saturation = 0.3, bloom = 0.9, air = { colours = { rgb(220, 255, 120), rgb(255, 240, 150) }, rate = 35, size = 0.35, speed = 1.5, fall = 0, light = 1 } },
	-- (Rain, hard.)
	thunder = { colour = rgb(160, 180, 255), tint = rgb(188, 202, 240), brightness = -0.15, contrast = 0.3, saturation = -0.25, bloom = 1.0, air = { colours = { rgb(205, 218, 255) }, rate = 200, size = 0.18, speed = 30, fall = 60, light = 0.3 } },
	-- (Sand on the wind.)
	desert = { colour = rgb(255, 200, 110), tint = rgb(255, 226, 172), brightness = 0.06, contrast = 0.12, saturation = -0.05, bloom = 1.0, air = { colours = { rgb(240, 200, 130), rgb(255, 226, 160) }, rate = 90, size = 0.3, speed = 8, fall = 2, light = 0.4 } },
} :: { [string]: any }

AbuseShow.Realms = {} :: { [string]: Realm }
for _, info in HouseEvents.Realms do
	local look = LOOKS[info.id]
	if look then
		AbuseShow.Realms[info.id] = {
			name = info.name,
			line = info.line,
			glyph = info.glyph,
			colour = look.colour,
			tint = look.tint,
			brightness = look.brightness,
			contrast = look.contrast,
			saturation = look.saturation,
			bloom = look.bloom,
			air = look.air,
			stars = look.stars,
		}
	end
end

local realmNow: string? = nil
local realmToken = 0
local realmBits: { Instance } = {}
local realmConn: RBXScriptConnection? = nil

local function rootOf(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function localStage(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

local function clearRealm()
	realmToken += 1
	if realmConn then
		realmConn:Disconnect()
		realmConn = nil
	end
	local bits = realmBits
	realmBits = {}
	for _, b in bits do
		if b:IsA("ColorCorrectionEffect") then
			tween(b, 1, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 })
		elseif b:IsA("BloomEffect") then
			tween(b, 1, { Intensity = 0 })
		elseif b:IsA("ParticleEmitter") then
			b.Enabled = false
		end
	end
	task.delay(1.2, function()
		for _, b in bits do
			b:Destroy()
		end
	end)
end

-- The realm's own air round the guest: a box of drifting motes that follows them.
local function realmAir(r: Realm)
	local box = Instance.new("Part")
	box.Name = "RealmAir"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(90, 36, 90)
	box.Parent = localStage()
	table.insert(realmBits, box)
	local att = Instance.new("Attachment")
	att.Parent = box
	local e = Instance.new("ParticleEmitter")
	e.Name = "Air"
	e.Texture = SPARK
	local keys = {}
	for i, colour in r.air.colours do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #r.air.colours - 1), colour))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, r.air.colours[1]))
	end
	e.Color = ColorSequence.new(keys)
	e.LightEmission = r.air.light
	e.Rate = r.air.rate
	e.Lifetime = NumberRange.new(3, 6)
	e.Speed = NumberRange.new(r.air.speed * 0.5, r.air.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -r.air.fall, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, r.air.size), NumberSequenceKeypoint.new(0.85, r.air.size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = att
	table.insert(realmBits, e)
	local my = realmToken
	realmConn = RunService.Heartbeat:Connect(function()
		if realmToken ~= my then
			return
		end
		local root = rootOf()
		if root then
			box.Position = root.Position + Vector3.new(0, 10, 0)
		end
	end)
end

-- The cosmos: stars all round the sky and a ringed planet over the house.
local function realmStars()
	local folder = Instance.new("Folder")
	folder.Name = "RealmStars"
	folder.Parent = localStage()
	table.insert(realmBits, folder)
	local centre = OwnerCameo.where() * Vector3.new(1, 0, 0.5)
	local rng = Random.new(54)
	for _ = 1, 180 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.1, 1), rng:NextNumber(-1, 1)).Unit
		local s = Instance.new("Part")
		s.Name = "Star"
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Material = Enum.Material.Neon
		s.Shape = Enum.PartType.Ball
		s.Color = Color3.new(1, 1, 1):Lerp(rgb(170, 190, 255), rng:NextNumber())
		s.Size = Vector3.one * rng:NextNumber(1.5, 4)
		s.Position = centre + dir * rng:NextNumber(700, 900)
		s.Parent = folder
	end
	local planet = Instance.new("Part")
	planet.Name = "Planet"
	planet.Anchored = true
	planet.CanCollide = false
	planet.CanQuery = false
	planet.CanTouch = false
	planet.Shape = Enum.PartType.Ball
	planet.Material = Enum.Material.SmoothPlastic
	planet.Color = rgb(150, 110, 230)
	planet.Size = Vector3.one * 180
	planet.Position = centre + Vector3.new(-420, 330, 520)
	planet.Parent = folder
	local ring = Instance.new("Part")
	ring.Name = "PlanetRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = rgb(240, 210, 150)
	ring.Transparency = 0.45
	ring.Size = Vector3.new(2, 380, 380)
	ring.CFrame = CFrame.new(planet.Position) * CFrame.Angles(math.rad(70), 0, math.rad(20))
	ring.Parent = folder
end

-- The shift: a glitch, a flash, the realm's name.
local function shiftCard(r: Realm)
	local gui = screen()
	local u = unit()
	local v = view()
	local old = gui:FindFirstChild("Shift")
	if old then
		old:Destroy()
	end
	local root = frame(gui, "Shift", Color3.new(0, 0, 0), 1)
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 30
	sound("warpBurst", 0.9)
	sound("glitch", 0.7)
	-- The glitch: bars of colour tearing across the picture.
	local bars: { Frame } = {}
	for _ = 1, 12 do
		local b = frame(root, "Tear", Color3.new(1, 1, 1), 0.5)
		b.ZIndex = 31
		table.insert(bars, b)
	end
	local colours = { r.colour, Color3.new(1, 1, 1), rgb(255, 40, 120), rgb(40, 220, 255) }
	local word = label(root, "Word", "REALM SHIFT", IMPACT, Color3.new(1, 1, 1))
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.45)
	word.Size = UDim2.fromOffset(math.min(v.X - 40, 760 * u), 110 * u)
	word.ZIndex = 33
	stroke(word, rgb(20, 10, 30), 4)
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		for _, b in bars do
			b.BackgroundColor3 = colours[math.random(1, #colours)]
			b.BackgroundTransparency = 0.25 + math.random() * 0.6
			b.Position = UDim2.fromScale(math.random() * 0.2 - 0.1, math.random())
			b.Size = UDim2.new(1.2, 0, 0, math.random(4, 46) * u)
		end
		word.Position = UDim2.new(0.5, (math.random() - 0.5) * 30 * u, 0.45, (math.random() - 0.5) * 12 * u)
		word.TextColor3 = colours[math.random(1, #colours)]
	end)
	task.delay(0.6, function()
		if conn then
			conn:Disconnect()
		end
		if not root.Parent then
			return
		end
		for _, b in bars do
			b:Destroy()
		end
		word:Destroy()
		local flash = frame(root, "Flash", Color3.new(1, 1, 1), 0)
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 32
		tween(flash, 0.6, { BackgroundTransparency = 1 })
		sound("stinger", 0.9)
		sound("subHit", 0.8)
		local card = frame(root, "Card", Color3.new(0, 0, 0), 1)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.4)
		card.Size = UDim2.fromOffset(math.min(v.X - 30, 820 * u), 230 * u)
		card.ZIndex = 33
		local glyph = label(card, "Glyph", r.glyph, HEAVY, Color3.new(1, 1, 1))
		glyph.AnchorPoint = Vector2.new(0.5, 0)
		glyph.Position = UDim2.fromScale(0.5, 0)
		glyph.Size = UDim2.fromOffset(84 * u, 84 * u)
		glyph.ZIndex = 34
		local entering = label(card, "Entering", "E N T E R I N G", HEAVY, Color3.new(1, 1, 1))
		entering.AnchorPoint = Vector2.new(0.5, 0)
		entering.Position = UDim2.new(0.5, 0, 0, 86 * u)
		entering.Size = UDim2.fromOffset(300 * u, 20 * u)
		entering.ZIndex = 34
		local name = label(card, "Realm", r.name, IMPACT, r.colour)
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.new(0.5, 0, 0, 108 * u)
		name.Size = UDim2.new(1, 0, 0, 80 * u)
		name.ZIndex = 34
		stroke(name, rgb(16, 10, 24), 4)
		local line = label(card, "Line", r.line, BOLD, rgb(245, 240, 230))
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0.5, 0, 0, 192 * u)
		line.Size = UDim2.new(0.9, 0, 0, 26 * u)
		line.ZIndex = 34
		local scale = Instance.new("UIScale")
		scale.Scale = 0.4
		scale.Parent = card
		tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(3, function()
			if card.Parent then
				tween(scale, 0.35, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				for _, l in { glyph, entering, name, line } do
					tween(l, 0.35, { TextTransparency = 1 })
				end
				local s = name:FindFirstChildOfClass("UIStroke")
				if s then
					tween(s, 0.3, { Transparency = 1 })
				end
			end
			task.delay(0.4, function()
				root:Destroy()
			end)
		end)
	end)
end

-- The house in a realm (or back to itself). `announce`: with the shift's glitch and name.
function AbuseShow.realm(id: string?, announce: boolean)
	if id == realmNow then
		return
	end
	clearRealm()
	realmNow = id
	local r = if id then AbuseShow.Realms[id] else nil
	if not r then
		return
	end
	local n = night
	if n and id then
		n.realms[id] = true
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AbuseRealm"
	cc.Parent = Lighting
	table.insert(realmBits, cc)
	tween(cc, 1.2, { TintColor = r.tint, Brightness = r.brightness, Contrast = r.contrast, Saturation = r.saturation })
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "AbuseRealmBloom"
	bloom.Intensity = 0
	bloom.Size = 30
	bloom.Threshold = 0.85
	bloom.Parent = Lighting
	table.insert(realmBits, bloom)
	tween(bloom, 1.2, { Intensity = r.bloom })
	realmAir(r)
	if r.stars then
		realmStars()
	end
	if announce then
		shiftCard(r)
	end
end

function AbuseShow.realmNow(): string?
	return realmNow
end

-- The name of the realm the house is in, shown now (after the opening).
function AbuseShow.announceRealm()
	local r = if realmNow then AbuseShow.Realms[realmNow] else nil
	if r and isMega() then
		shiftCard(r)
	end
end

---------------------------------------------------------------------------------------------------
-- The gifts
---------------------------------------------------------------------------------------------------
local giftToken = 0
local giftBox: () -> () = function() end -- (the last gift's box beside the guest, taken away)

-- Where the floor is below a point (or the point itself).
local function floorBelow(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { localStage() }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

-- A golden box falling from the sky beside the guest; walking into it opens the gift.
local function fallingGift(onTouch: () -> ()): () -> ()
	local root = rootOf()
	if not root or AbuseShow.isBusy() then
		return function() end
	end
	local a = math.random() * math.pi * 2
	local landAt = floorBelow(root.Position + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9)) + Vector3.new(0, 1.6, 0)
	local model = Instance.new("Model")
	model.Name = "OwnerGift"
	local function piece(name: string, size: Vector3, colour: Color3, material: Enum.Material, offset: CFrame): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.Color = colour
		p.Material = material
		p:SetAttribute("Offset", offset)
		p.Parent = model
		return p
	end
	local box = piece("Box", Vector3.new(3.2, 3.2, 3.2), GOLD, Enum.Material.SmoothPlastic, CFrame.new())
	box.Reflectance = 0.25
	piece("RibbonA", Vector3.new(3.3, 3.3, 0.6), rgb(220, 30, 60), Enum.Material.SmoothPlastic, CFrame.new())
	piece("RibbonB", Vector3.new(0.6, 3.3, 3.3), rgb(220, 30, 60), Enum.Material.SmoothPlastic, CFrame.new())
	piece("BowL", Vector3.new(1.3, 1.3, 1.3), rgb(240, 50, 80), Enum.Material.SmoothPlastic, CFrame.new(-0.7, 1.9, 0))
	piece("BowR", Vector3.new(1.3, 1.3, 1.3), rgb(240, 50, 80), Enum.Material.SmoothPlastic, CFrame.new(0.7, 1.9, 0))
	model.PrimaryPart = box
	model.Parent = localStage()
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 18
	glow.Brightness = 2.5
	glow.Parent = box
	local att = Instance.new("Attachment")
	att.Parent = box
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = SPARK
	sparkle.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	sparkle.LightEmission = 1
	sparkle.Rate = 30
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = att
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(120, 34)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.MaxDistance = 80
	tag.Parent = box
	local tagText = label(tag, "Text", "🎁 WALK INTO IT", HEAVY, GOLD_LIGHT)
	tagText.Size = UDim2.fromScale(1, 1)
	stroke(tagText, rgb(30, 18, 4), 2)
	local function place(cf: CFrame)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				local offset = p:GetAttribute("Offset")
				p.CFrame = cf * (if typeof(offset) == "CFrame" then offset else CFrame.new())
			end
		end
	end
	local from = landAt + Vector3.new(0, 70, 0)
	local started = os.clock()
	local landed = false
	local done = false
	local conn: RBXScriptConnection? = nil
	local function finish()
		if done then
			return
		end
		done = true
		if conn then
			conn:Disconnect()
		end
		sparkle.Rate = 0
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = SPARK
		burst.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
		burst.LightEmission = 1
		burst.Rate = 0
		burst.Speed = NumberRange.new(10, 26)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Lifetime = NumberRange.new(0.6, 1.2)
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		burst.Parent = att
		pcall(function()
			burst:Emit(70)
		end)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
		tag.Enabled = false
		task.delay(1.4, function()
			model:Destroy()
		end)
	end
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		if not landed then
			local k = math.min(1, t / 1.5)
			place(CFrame.new(from:Lerp(landAt, k * k)) * CFrame.Angles(t * 2, t * 3, 0))
			if k >= 1 then
				landed = true
				sound("fairyDust", 0.9)
				sound("lowHit", 0.6)
			end
			return
		end
		place(CFrame.new(landAt + Vector3.new(0, 0.4 + math.sin(t * 3) * 0.4, 0)) * CFrame.Angles(0, t * 1.4, 0))
		local me = rootOf()
		if me and (me.Position - landAt).Magnitude < 7 then
			onTouch()
		end
	end)
	return finish
end

-- The owner's gift on this screen: a card to open, and a box beside the guest.
function AbuseShow.gift(m: { [string]: any })
	local id = m.id
	if type(id) ~= "number" then
		return
	end
	giftToken += 1
	local my = giftToken
	local gilt = if type(m.gilt) == "number" then m.gilt else 0
	local crown = m.crown == true
	local bonus = if type(m.bonus) == "number" then m.bonus else nil
	local seconds = if type(m.seconds) == "number" then m.seconds else 25
	local gui = screen()
	local u = unit()
	local old = gui:FindFirstChild("Gift")
	if old then
		old:Destroy()
	end
	pcall(giftBox)
	local width = math.min(view().X - 24, 300 * u)
	local card = frame(gui, "Gift", Color3.new(1, 1, 1), 0)
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = UDim2.new(1, width + 40, 0.52, 0)
	card.Size = UDim2.fromOffset(width, 236 * u)
	card.ZIndex = 40
	corner(card, UDim.new(0, 20 * u))
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(rgb(52, 36, 14), rgb(14, 10, 6))
	fill.Rotation = 90
	fill.Parent = card
	local edge = stroke(card, GOLD, 3)
	local head = label(card, "Head", "A GIFT FROM " .. string.upper(ownerName()), HEAVY, GOLD)
	head.Position = UDim2.new(0, 14 * u, 0, 12 * u)
	head.Size = UDim2.new(1, -28 * u, 0, 18 * u)
	head.ZIndex = 41
	-- The present, on a turning sunburst.
	local burst = frame(card, "Sunburst", GOLD, 0.55)
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.new(0.5, 0, 0, 78 * u)
	burst.Size = UDim2.fromOffset(96 * u, 96 * u)
	burst.ZIndex = 41
	corner(burst, UDim.new(1, 0))
	local rays = Instance.new("UIGradient")
	rays.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0.2) })
	rays.Parent = burst
	local box = label(card, "Present", "🎁", HEAVY, Color3.new(1, 1, 1))
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(0.5, 0, 0, 78 * u)
	box.Size = UDim2.fromOffset(74 * u, 74 * u)
	box.ZIndex = 42
	local reward = label(card, "Reward", "+" .. tostring(gilt) .. " GILT" .. (if crown then "  +  👑 THE ADMIN'S CROWN" elseif bonus then "  +  " .. tostring(bonus) .. " BONUS" else ""), HEAVY, Color3.new(1, 1, 1))
	reward.Position = UDim2.new(0, 14 * u, 0, 130 * u)
	reward.Size = UDim2.new(1, -28 * u, 0, 22 * u)
	reward.ZIndex = 41
	local button = Instance.new("TextButton")
	button.Name = "Open"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 160 * u)
	button.Size = UDim2.new(1, -28 * u, 0, 48 * u)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.FontFace = IMPACT
	button.TextScaled = true
	button.TextColor3 = rgb(40, 24, 6)
	button.Text = "OPEN IT!"
	button.ZIndex = 42
	button.Parent = card
	corner(button, UDim.new(0, 14 * u))
	golden(button)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8 * u)
	pad.PaddingBottom = UDim.new(0, 6 * u)
	pad.Parent = button
	local timer = frame(card, "Timer", GOLD, 0.1)
	timer.AnchorPoint = Vector2.new(0, 1)
	timer.Position = UDim2.new(0, 14 * u, 1, -10 * u)
	timer.Size = UDim2.new(1, -28 * u, 0, 5 * u)
	timer.ZIndex = 41
	corner(timer, UDim.new(1, 0))
	tween(timer, seconds, { Size = UDim2.new(0, 0, 0, 5 * u) }, Enum.EasingStyle.Linear)
	tween(card, 0.5, { Position = UDim2.new(1, -14, 0.52, 0) }, Enum.EasingStyle.Back)
	sound("fairyDust", 0.8)
	sound("magicZoom", 0.6)
	local closed = false
	local function close(after: number)
		task.delay(after, function()
			if closed then
				return
			end
			closed = true
			tween(card, 0.35, { Position = UDim2.new(1, width + 40, 0.52, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.4, function()
				card:Destroy()
			end)
		end)
	end
	local started = os.clock()
	local spin: RBXScriptConnection
	spin = RunService.RenderStepped:Connect(function()
		if not card.Parent then
			spin:Disconnect()
			return
		end
		local t = os.clock() - started
		rays.Rotation = (t * 60) % 360
		box.Rotation = math.sin(t * 5) * 8
		edge.Transparency = 0.1 + 0.4 * math.abs(math.sin(t * 4))
		local s = 1 + 0.04 * math.sin(t * 8)
		button.Size = UDim2.new(1, -28 * u * s, 0, 48 * u * s)
	end)
	local opening = false
	local finishBox: () -> () = function() end
	local function open()
		if opening or closed or giftToken ~= my then
			return
		end
		opening = true
		button.Text = "OPENING..."
		button.AutoButtonColor = false
		local ok, r = pcall(function(): any
			return Remotes.func("AbuseGiftAsk"):InvokeServer({ op = "open", id = id })
		end)
		finishBox()
		spin:Disconnect()
		if ok and type(r) == "table" and r.ok then
			local n = night
			if n then
				n.gifts += 1
			end
			sound("kaching", 1)
			sound("coinDrop", 0.9)
			task.delay(0.15, sound, "shimmerFall", 0.7)
			box.Text = "💥"
			tween(box, 0.25, { Size = UDim2.fromOffset(110 * u, 110 * u), TextTransparency = 1 })
			button.Visible = false
			reward.Text = "+" .. tostring(r.gilt or gilt) .. " GILT" .. (if r.crown then "  +  👑 THE CROWN!" else "")
			reward.TextColor3 = GOLD_LIGHT
			local scale = Instance.new("UIScale")
			scale.Scale = 1.6
			scale.Parent = reward
			tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			-- (From the middle of the card: right-hand side, just below half way down.)
			local v = view()
			confettiBurst(gui, Vector2.new(v.X - 14 - width / 2, v.Y * 0.52), 40, 700 * u)
			close(1.8)
		else
			reward.Text = if ok and type(r) == "table" and type(r.why) == "string" then r.why else "That gift has gone."
			button.Visible = false
			close(1.4)
		end
	end
	button.Activated:Connect(open)
	finishBox = fallingGift(open)
	giftBox = finishBox
	task.delay(seconds, function()
		if not opening then
			spin:Disconnect()
			finishBox()
			close(0)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The finale
---------------------------------------------------------------------------------------------------
local function thousands(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- Coins (or anything) raining down the whole screen for a while.
local function rainDown(parent: Instance, glyphs: { string }, count: number, seconds: number)
	local v = view()
	local u = unit()
	for i = 1, count do
		task.delay((i / count) * seconds * 0.7, function()
			if not parent.Parent then
				return
			end
			local size = (26 + math.random() * 30) * u
			local l = label(parent, "Rain", glyphs[math.random(1, #glyphs)], HEAVY, Color3.new(1, 1, 1))
			l.AnchorPoint = Vector2.new(0.5, 0.5)
			l.Size = UDim2.fromOffset(size, size)
			l.Position = UDim2.fromOffset(math.random() * v.X, -size)
			l.ZIndex = 49
			l.Rotation = math.random(-40, 40)
			local fall = 1.4 + math.random() * 1.3
			tween(l, fall, { Position = UDim2.fromOffset(math.random() * v.X, v.Y + size), Rotation = l.Rotation + math.random(-220, 220) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(fall + 0.05, function()
				l:Destroy()
			end)
		end)
	end
end

-- The haul card: thank you, and what this guest got tonight.
local function haulCard(n: Night, stopped: boolean, P: AbuseNights.Palette, delayIn: number)
	local gui = screen()
	local u = unit()
	local v = view()
	local old = gui:FindFirstChild("Finale")
	if old then
		old:Destroy()
	end
	-- (Only what there is to tell: no "+0 GILT" for a guest, or AJKR, who didn't sort tonight.)
	local gained = math.max(0, giltNow() - n.gilt)
	local rows: { { glyph: string, text: string } } = {}
	if gained > 0 then
		table.insert(rows, { glyph = "🪙", text = "+" .. thousands(gained) .. " GILT" })
	end
	if n.gifts > 0 then
		table.insert(rows, { glyph = "🎁", text = tostring(n.gifts) .. (if n.gifts == 1 then " GIFT OPENED" else " GIFTS OPENED") })
	end
	if n.golden > 0 then
		table.insert(rows, { glyph = "✨", text = tostring(n.golden) .. (if n.golden == 1 then " GOLDEN PIECE" else " GOLDEN PIECES") })
	end
	local realms = 0
	for _ in n.realms do
		realms += 1
	end
	if n.mega and realms > 0 then
		table.insert(rows, { glyph = "🌌", text = tostring(realms) .. (if realms == 1 then " REALM VISITED" else " REALMS VISITED") })
	end
	local seen = 0
	for _ in n.seen do
		seen += 1
	end
	if seen > 0 then
		table.insert(rows, { glyph = "🎆", text = tostring(seen) .. (if seen == 1 then " EFFECT WITNESSED" else " EFFECTS WITNESSED") })
	end
	local height = (if #rows > 0 then 176 + #rows * 40 else 146) * u
	local card = frame(gui, "Finale", Color3.new(1, 1, 1), 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.45)
	card.Size = UDim2.fromOffset(math.min(v.X - 24, 560 * u), height)
	card.ZIndex = 50
	card.Visible = false
	corner(card, UDim.new(0, 22 * u))
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(P.deep:Lerp(Color3.new(0, 0, 0), 0.6), rgb(12, 9, 6))
	fill.Rotation = 90
	fill.Parent = card
	stroke(card, P.main, 3)
	local title = label(card, "Title", if stopped then "ADMIN ABUSE IS OVER" else "THAT'S A WRAP!", IMPACT, Color3.new(1, 1, 1))
	title.Position = UDim2.new(0, 18 * u, 0, 16 * u)
	title.Size = UDim2.new(1, -36 * u, 0, 58 * u)
	title.ZIndex = 51
	painted(title, P, n.mega)
	stroke(title, rgb(30, 16, 4), 3)
	local which = label(card, "Night", n.glyph .. "  " .. n.name, HEAVY, P.light)
	which.Position = UDim2.new(0, 18 * u, 0, 78 * u)
	which.Size = UDim2.new(1, -36 * u, 0, 22 * u)
	which.ZIndex = 51
	local thanks = label(card, "Thanks", if #rows > 0 then "THANK YOU FOR COMING  ·  YOUR HAUL" else "THANK YOU FOR COMING", HEAVY, rgb(245, 236, 220))
	thanks.Position = UDim2.new(0, 18 * u, 0, 106 * u)
	thanks.Size = UDim2.new(1, -36 * u, 0, 18 * u)
	thanks.ZIndex = 51
	for i, r in rows do
		local row = label(card, "Row", r.glyph .. "  " .. r.text, HEAVY, if i == 1 then P.light else Color3.new(1, 1, 1))
		row.Position = UDim2.new(0, 18 * u, 0, (138 + (i - 1) * 40) * u)
		row.Size = UDim2.new(1, -36 * u, 0, 30 * u)
		row.ZIndex = 51
		row.TextTransparency = 1
		task.delay(delayIn + 0.5 + i * 0.45, function()
			tween(row, 0.3, { TextTransparency = 0 })
			sound("tick", 0.8, 1 + i * 0.08)
		end)
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = card
	task.delay(delayIn, function()
		if not card.Parent then
			return
		end
		card.Visible = true
		tween(scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
		sound("regalFanfare", 0.8)
		task.delay(0.3, sound, "crowdCheer", 0.7)
		confettiBurst(gui, Vector2.new(v.X / 2, v.Y * 0.4), 110, 1000 * u)
	end)
	local seconds = (cfg().finaleSeconds or 9) + delayIn
	task.delay(seconds, function()
		if card.Parent then
			tween(scale, 0.35, { Scale = 0.5 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.38, function()
				card:Destroy()
			end)
		end
	end)
end

-- A layer over the screen for a finale's own show (gone by itself).
local function finaleLayer(seconds: number): Frame
	local gui = screen()
	local old = gui:FindFirstChild("FinaleShow")
	if old then
		old:Destroy()
	end
	local layer = frame(gui, "FinaleShow", Color3.new(0, 0, 0), 1)
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 45
	task.delay(seconds, function()
		layer:Destroy()
	end)
	return layer
end

local FINALES: { [string]: (Night, boolean, AbuseNights.Palette) -> () } = {}

-- The house's fireworks over everyone, and the haul.
FINALES.fireworks = function(n: Night, stopped: boolean, P: AbuseNights.Palette)
	haulCard(n, stopped, P, 0)
	pcall(function()
		Fireworks.show(10, { scale = 1, watch = false, music = false })
	end)
end

-- Gold raining down the screen, coins chiming, and the haul.
FINALES.goldShower = function(n: Night, stopped: boolean, P: AbuseNights.Palette)
	local layer = finaleLayer(7)
	rainDown(layer, { "🪙", "🪙", "🪙", "💰", "✨" }, 70, 4)
	for i = 0, 5 do
		task.delay(i * 0.35, sound, "coinDrop", 0.7, 1 + i * 0.05)
	end
	sound("kaching", 1)
	haulCard(n, stopped, P, 0.8)
end

-- A film's closing credits rolling up the screen: starring you; then the haul.
FINALES.credits = function(n: Night, stopped: boolean, P: AbuseNights.Palette)
	local v = view()
	local u = unit()
	local seconds = 9
	local layer = finaleLayer(seconds + 0.6)
	layer.BackgroundTransparency = 1
	tween(layer, 0.6, { BackgroundTransparency = 0.25 })
	-- (The roll runs in a window between the keys along the top and AJKR's farewell at the foot of
	-- the screen, its edges softened into the dark.)
	local clear = 170
	local top = math.floor(v.Y * 0.16)
	local window = frame(layer, "Window", Color3.new(0, 0, 0), 1)
	window.Position = UDim2.fromOffset(0, top)
	window.Size = UDim2.new(1, 0, 1, -(clear + top))
	window.ClipsDescendants = true
	window.ZIndex = 46
	for i, edge in { 0, 1 } do
		local fade = frame(window, "Fade", Color3.new(0, 0, 0), 0.25)
		fade.AnchorPoint = Vector2.new(0, edge)
		fade.Position = UDim2.fromScale(0, edge)
		fade.Size = UDim2.new(1, 0, 0, 70 * u)
		fade.ZIndex = 48
		local g = Instance.new("UIGradient")
		g.Rotation = if i == 1 then 90 else -90
		g.Transparency = NumberSequence.new(0, 1)
		g.Parent = fade
	end
	pcall(Fireworks.hideWatch, seconds + 1)
	local roll = frame(window, "Credits", Color3.new(0, 0, 0), 1)
	roll.AnchorPoint = Vector2.new(0.5, 0)
	roll.Size = UDim2.fromOffset(math.min(v.X - 40, 640 * u), 10)
	roll.Position = UDim2.new(0.5, 0, 1, 0)
	roll.ZIndex = 46
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0, 10 * u)
	list.Parent = roll
	local seen = {}
	for id in n.seen do
		local e = HouseEvents.effectById[id]
		if e then
			table.insert(seen, tostring(e.glyph) .. " " .. string.upper(tostring(e.name)))
		end
	end
	table.sort(seen)
	local lines: { { text: string, big: boolean? } } = {
		{ text = "MAISON NOIR PRESENTS", big = false },
		{ text = n.glyph .. "  " .. n.name, big = true },
		{ text = " " },
		{ text = "STARRING" },
	}
	-- (Each guest stars as themselves; AJKR's own screen thanks the house's guests instead of
	-- naming AJKR twice.)
	if Names.isOwner(player) then
		table.insert(lines, { text = string.upper(ownerName()) .. "  as  THE OWNER", big = true })
		table.insert(lines, { text = "AND" })
		table.insert(lines, { text = "EVERY GUEST  as  THEMSELVES", big = true })
	else
		table.insert(lines, { text = string.upper(Names.of(player)) .. "  as  THE GUEST", big = true })
		table.insert(lines, { text = "AND" })
		table.insert(lines, { text = string.upper(ownerName()) .. "  as  THE OWNER", big = true })
	end
	table.insert(lines, { text = " " })
	table.insert(lines, { text = "SPECIAL EFFECTS" })
	for i = 1, math.min(8, #seen) do
		table.insert(lines, { text = seen[i] })
	end
	-- (The Gilt earned, when there is some to tell.)
	local earned = math.max(0, giltNow() - n.gilt)
	local tail: { string } = if earned > 0 then { " ", "GILT EARNED TONIGHT", "+" .. thousands(earned) } else {}
	for _, extra in { " ", "NO GUESTS WERE HARMED IN THE MAKING OF THIS NIGHT", " ", "THANK YOU FOR COMING" } do
		table.insert(tail, extra)
	end
	for _, extra in tail do
		table.insert(lines, { text = extra, big = extra == "THANK YOU FOR COMING" })
	end
	local height = 0
	for i, l in lines do
		local h = (if l.big then 40 else 24) * u
		local t = label(roll, "Line", l.text, if l.big then IMPACT else HEAVY, if l.big then P.light else rgb(236, 230, 220))
		t.Size = UDim2.new(1, 0, 0, h)
		t.LayoutOrder = i
		t.ZIndex = 47
		height += h + 10 * u
	end
	roll.Size = UDim2.fromOffset(roll.Size.X.Offset, height)
	-- (Rolled frame by frame: up from the foot of the screen and away over the top.)
	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if not roll.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local k = math.clamp((os.clock() - started) / seconds, 0, 1)
		roll.Position = UDim2.new(0.5, 0, 1, -k * (v.Y - clear - top + height))
	end)
	sound("regalFanfare", 0.6)
	haulCard(n, stopped, P, seconds - 1)
end

-- A flash of white light from the middle, rings racing out, and the haul.
FINALES.supernova = function(n: Night, stopped: boolean, P: AbuseNights.Palette)
	local v = view()
	local layer = finaleLayer(3)
	local centre = Vector2.new(v.X / 2, v.Y * 0.45)
	local ball = frame(layer, "Nova", Color3.new(1, 1, 1), 0)
	ball.AnchorPoint = Vector2.new(0.5, 0.5)
	ball.Position = UDim2.fromOffset(centre.X, centre.Y)
	ball.Size = UDim2.fromOffset(20, 20)
	ball.ZIndex = 46
	corner(ball, UDim.new(1, 0))
	local big = math.max(v.X, v.Y) * 2.4
	tween(ball, 0.9, { Size = UDim2.fromOffset(big, big), BackgroundTransparency = 1 }, Enum.EasingStyle.Quint)
	for i, colour in { P.main, P.light, P.accent } do
		task.delay(i * 0.15, shockwave, layer, centre, colour, big, 1)
	end
	sound("sonicBoom", 1)
	sound("heavenly", 0.8)
	haulCard(n, stopped, P, 0.7)
end

-- Confetti from every corner, again and again, and the haul.
FINALES.confettiStorm = function(n: Night, stopped: boolean, P: AbuseNights.Palette)
	local v = view()
	local u = unit()
	local layer = finaleLayer(6)
	for round = 0, 4 do
		task.delay(round * 0.6, function()
			for _, corner2 in { Vector2.new(0, v.Y), Vector2.new(v.X, v.Y), Vector2.new(0, 0), Vector2.new(v.X, 0) } do
				confettiBurst(layer, corner2, 30, 1200 * u)
			end
			sound("partyHorn", 0.8, 1 + round * 0.05)
		end)
	end
	haulCard(n, stopped, P, 0.5)
end

-- The curtains close, THANK YOU on them, a bow; then they part on the haul.
FINALES.curtainCall = function(n: Night, stopped: boolean, P: AbuseNights.Palette)
	local u = unit()
	local layer = finaleLayer(5)
	local halves: { Frame } = {}
	for i = 0, 1 do
		local h = frame(layer, "Curtain", Color3.new(1, 1, 1), 0)
		h.Size = UDim2.new(0.5, 2, 1, 0)
		h.Position = UDim2.fromScale(if i == 0 then -0.5 else 1, 0)
		h.ZIndex = 46
		local folds = Instance.new("UIGradient")
		local keys = {}
		for k = 0, 8 do
			table.insert(keys, ColorSequenceKeypoint.new(k / 8, if k % 2 == 0 then rgb(150, 18, 34) else rgb(84, 6, 18)))
		end
		folds.Color = ColorSequence.new(keys)
		folds.Parent = h
		tween(h, 0.8, { Position = UDim2.fromScale(i * 0.5, 0) }, Enum.EasingStyle.Quint)
		table.insert(halves, h)
	end
	local thanks = label(layer, "Thanks", "THANK YOU!", IMPACT, Color3.new(1, 1, 1))
	thanks.AnchorPoint = Vector2.new(0.5, 0.5)
	thanks.Position = UDim2.fromScale(0.5, 0.45)
	thanks.Size = UDim2.fromOffset(700 * u, 130 * u)
	thanks.ZIndex = 47
	painted(thanks, P, n.mega)
	stroke(thanks, rgb(40, 6, 12), 4)
	thanks.TextTransparency = 1
	task.delay(0.8, function()
		tween(thanks, 0.3, { TextTransparency = 0 })
		sound("applause", 1)
	end)
	task.delay(2.6, function()
		thanks:Destroy()
		for i, h in halves do
			tween(h, 0.8, { Position = UDim2.fromScale(if i == 1 then -0.52 else 1.02, 0) }, Enum.EasingStyle.Quint)
		end
	end)
	haulCard(n, stopped, P, 2.8)
end

function AbuseShow.finale(n: Night, stopped: boolean)
	local P = AbuseNights.Palettes[n.palette] or AbuseNights.Palettes.gold
	local style = if FINALES[n.finale] then n.finale else "fireworks"
	local ok, err = pcall(function()
		FINALES[style](n, stopped, P)
	end)
	if not ok then
		warn("[Maison] finale " .. style .. ": " .. tostring(err))
	end
end

---------------------------------------------------------------------------------------------------
-- Watching the house
---------------------------------------------------------------------------------------------------
local function begin(since: number)
	local plan = currentPlan()
	night = {
		since = since,
		ends = (Workspace:GetAttribute("AbuseUntil") :: number?) or 0,
		gilt = giltNow(),
		gifts = 0,
		golden = 0,
		realms = {},
		seen = {},
		mega = isMega(),
		name = if plan then plan.night.name else "ADMIN ABUSE",
		glyph = if plan then plan.night.glyph else "👑",
		palette = if plan then plan.palette else "gold",
		finale = if plan then plan.finale else "fireworks",
	}
	if not skyHeld then
		skyHeld = true
		pcall(Fireworks.clearSky, true)
	end
	-- (The opening comes by its own message: a guest who didn't get it, arriving late, is welcomed.)
	task.delay(1.6, function()
		local n = night
		if n and n.since == since and os.clock() - openingSeen > 12 then
			AbuseShow.arrived(isMega())
		end
	end)
end

local function finish()
	local n = night
	night = nil
	if skyHeld then
		skyHeld = false
		pcall(Fireworks.clearSky, false)
	end
	openingToken += 1
	local gui = screen()
	for _, name in { "Opening", "Arrival", "Gift" } do
		local f = gui:FindFirstChild(name)
		if f then
			f:Destroy()
		end
	end
	OwnerCameo.colossus(false)
	AbuseShow.realm(nil, false)
	if n then
		-- (Ended on time: the full finale. Stopped early: the same, its title says so.)
		local early = Workspace:GetServerTimeNow() < n.ends - 5
		OwnerCameo.say(if early then "That's all for tonight! Thank you for coming! 👋" else "That's a wrap! See you at the next Admin Abuse! 👋", "wave", 6)
		AbuseShow.finale(n, early)
	end
end

local function check()
	local since = Workspace:GetAttribute("AbuseSince")
	if abusing() and type(since) == "number" then
		local n = night
		if not n or n.since ~= since then
			begin(since)
		else
			local mega = isMega()
			n.mega = n.mega or mega
			local ends = Workspace:GetAttribute("AbuseUntil")
			if type(ends) == "number" then
				n.ends = ends
			end
		end
		-- (A change of realm in Mega Abuse is announced; the first, at the opening, after it.)
		local realm = Workspace:GetAttribute("AbuseRealm")
		AbuseShow.realm(if type(realm) == "string" then realm else nil, isMega() and realmNow ~= nil)
	elseif night then
		finish()
	end
end
AbuseShow.check = check

function AbuseShow.start()
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "abuseShow" and m.stage == "intro" then
			AbuseShow.opening(m.mega == true, if type(m.seed) == "number" then m.seed else nil, if type(m.night) == "string" then m.night else nil)
		elseif m.op == "abuseGift" then
			AbuseShow.gift(m)
		elseif m.op == "abuseFX" and type(m.id) == "string" then
			local e = HouseEvents.effectById[m.id]
			if e then
				local n = night
				if n then
					n.seen[m.id] = true
				end
				-- AJKR's line for it (the night's, the same on every screen), or what it is. (The
				-- second of two at once comes without a line: the first's card stays.)
				local looks = AbuseNights.variant(m.id, if type(m.v) == "number" then m.v else nil)
				local name = if looks then looks.banner else string.upper(tostring(e.name)) .. "!"
				local what = tostring(e.glyph) .. " " .. name
				if type(m.line) == "string" then
					OwnerCameo.say(what .. "  " .. m.line, "point", 4.5, paletteOf(currentPlan()).main)
				elseif not n then
					OwnerCameo.say("cast " .. what, "point", 4)
				end
			end
		elseif m.op == "giveaway" and type(m.winner) == "string" then
			OwnerCameo.say("GIVEAWAY! Good luck, everyone... 🍀", "cheer", 4)
		end
	end)
	-- An effect switched on (from the console or the Owner Remote): the owner says so.
	for _, e in HouseEvents.Effects do
		local attr = HouseEvents.fxAttribute(e.id)
		local was = Workspace:GetAttribute(attr) ~= nil
		Workspace:GetAttributeChangedSignal(attr):Connect(function()
			local on = Workspace:GetAttribute(attr) ~= nil
			if on and not was then
				-- (In the looks it was switched on with: "switched on ☄️ ICE COMETS!")
				local v = Workspace:GetAttribute(HouseEvents.fxVariantAttribute(e.id))
				local looks = AbuseNights.variant(e.id, if type(v) == "number" then v else nil)
				local name = if looks then looks.banner else string.upper(tostring(e.name)) .. "!"
				OwnerCameo.say(string.format("switched on %s %s It stays on.", tostring(e.glyph), name), "point", 4)
				OwnerCameo.gesture("point")
			end
			was = on
		end)
	end
	for _, name in { "AbuseUntil", "AbuseSince", "AbuseMega", "AbuseRealm" } do
		Workspace:GetAttributeChangedSignal(name):Connect(check)
	end
	-- The owner walking into this server: their hologram waves hello to everyone already here.
	Players.PlayerAdded:Connect(function(p: Player)
		if p.UserId == Config.data.Admin.ownerUserId and p ~= player then
			task.delay(2, function()
				if p.Parent == Players then
					OwnerCameo.say("I'm here! Say hi! 👋 Something big might be about to happen...", "wave", 6)
				end
			end)
		end
	end)
	check()
	-- (It ends at a time, not with a change: look now and then.)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(check)
		end
	end)
end

return AbuseShow

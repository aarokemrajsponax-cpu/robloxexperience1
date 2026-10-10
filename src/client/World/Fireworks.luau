--!strict
-- The house's fireworks: a pyromusical over the whole estate, drawn on each guest's own screen when
-- the server says (Salutes, Suite spectacles), in three acts, each to its own score from Roblox's
-- licensed library (Config.Fireworks.score):
--
--   Hanabi    to taiko drums: the Japanese masters' shells, one perfect sphere at a time.
--             Chrysanthemums trailing gold, peonies that change colour as they fall, double and
--             triple petals with a heart of another colour, the thousand flowers, rings, Saturn,
--             hearts and stars drawn in the sky, kamuro crowns of gold that hang and drip.
--   Liberty   to Sousa: red, white and blue. Thunderous salutes, palms of gold comets, crackling
--             dragon's eggs, brocade crowns, strobes, mines fired from the ground, fans of shells
--             across the sky, and Niagara Falls pouring silver down the front of the house.
--   Majesty   to Handel's Music for the Royal Fireworks: searchlights sweep the sky, a canopy of
--             gold kamuro, the barrage, the house's monogram written in gold stars, and a last wall
--             of golden willows hanging over every roof, to cheers.
--
-- A short show plays the first and the last. Every star is a streak that stretches as it flies and
-- slows; behind it a glitter tail; each burst a white-hot flash and a shockwave, light that floods
-- the roofs, smoke that drifts and catches the bursts after it, and thunder that arrives a beat
-- after the light, as it does. Slower computers get fewer stars, never a stall. Every number that
-- shapes it lives in Config.Fireworks.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local CameraRig = require(script.Parent.Parent.Camera)
local Sound = require(script.Parent.Parent.Sound)

local Fireworks = {}

export type Options = {
	scale: number?, -- 1: a show; more: bigger shells, more of them (the Grand Salute, the Finale)
	finale: boolean?, -- end on the grand finale (default true)
	watch: boolean?, -- this guest bought it: the camera goes out to watch at once
	music: boolean?, -- play the show's score (default true)
	act: string?, -- one act only, the whole show long ("hanabi", "liberty" or "majesty"): an effect's own looks
	tag: string?, -- who it's for: "effect" (an Admin Abuse effect's), stopped with the rest by Fireworks.stop("effect")
}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds" -- a star with a soft glow
local DUST = "rbxasset://textures/particles/fire_sparks_main.dds" -- a scatter of tiny sparks
local RING = "rbxasset://textures/particles/forcefield_vortex_main.dds" -- a ring of light
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local rgb = Color3.fromRGB
local WHITE = rgb(255, 252, 244)
local GOLD = rgb(255, 196, 90)
local AMBER = rgb(255, 146, 46)
local EMBER = rgb(190, 80, 24)
local SILVER = rgb(214, 222, 240)
local RED = rgb(255, 46, 60)
local BLUE = rgb(60, 112, 255)
local SAKURA = rgb(255, 128, 196)
local FUJI = rgb(176, 104, 255)
local MATCHA = rgb(110, 255, 140)
local SORA = rgb(90, 224, 255)
local LEMON = rgb(255, 238, 120)
local ROSE = rgb(255, 70, 120)

type Palette = { Color3 }
-- The colours a shell's stars burn in, in turn: a change of colour as they fall.
local HANABI: { Palette } = {
	{ SAKURA, WHITE }, { FUJI, SAKURA }, { GOLD, RED }, { MATCHA, GOLD }, { SORA, FUJI }, { RED, MATCHA },
	{ LEMON, SORA }, { WHITE, SAKURA }, { ROSE, GOLD }, { SORA, WHITE }, { FUJI, LEMON },
}
local LIBERTY: { Palette } = { { RED }, { WHITE }, { BLUE }, { RED, WHITE }, { BLUE, WHITE }, { WHITE, RED }, { WHITE, BLUE }, { GOLD, RED } }
local MAJESTY: { Palette } = { { GOLD }, { GOLD, WHITE }, { SILVER }, { GOLD, RED }, { WHITE, GOLD }, { GOLD, FUJI }, { SILVER, SORA } }
local GOLDEN: Palette = { GOLD, AMBER }

local live = 0 -- shells in the sky now (Config.Fireworks.maxLive caps it)
local q = 1 -- how many stars this computer draws (Config.Fireworks.density, the graphics level)
type Box = { min: Vector3, max: Vector3 }
local bounds: Box? = nil

local function cfg(): { [string]: any }
	return (Config.data :: any).Fireworks
end

local function kp(t: number, v: number): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(t, v)
end

local function randomIn(lo: number, hi: number): number
	return lo + math.random() * (hi - lo)
end

local function pick<T>(list: { T }): T
	return list[math.random(1, #list)]
end

-- The guest's graphics level: fewer stars on slower settings.
local function quality(): number
	local ok, level = pcall(function(): any
		return (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Value
	end)
	local density = tonumber(cfg().density) or 1
	if ok and type(level) == "number" and level > 0 then
		return density * math.clamp(0.4 + level * 0.06, 0.5, 1)
	end
	return density * 0.85
end

-- How many of something a shell of size `s` throws.
local function count(base: number, s: number): number
	return math.max(1, math.floor(base * q * math.clamp(s / cfg().size, 0.7, 1.6)))
end

local function folder(): Instance
	local holder = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local f = holder:FindFirstChild("Fireworks")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Fireworks"
		f.Parent = holder
	end
	return f :: Instance
end

-- The grounds the show covers: the house's own footprint (its rooms, from Layout; never the city
-- across the street), with a margin; its height is the highest roof inside it, measured once.
local function grounds(): Box
	local known = bounds
	if known then
		return known
	end
	local lo = Vector3.new(Layout.Salon.minX, 0, Layout.Foyer.minZ - 4)
	local hi = Vector3.new(Layout.Ballroom.maxX, 60, Layout.Ballroom.maxZ)
	local maison = Workspace:FindFirstChild("Maison")
	if maison then
		local top = 0
		for _, d in maison:GetDescendants() do
			if d:IsA("BasePart") then
				local p = d.Position
				if p.X >= lo.X and p.X <= hi.X and p.Z >= lo.Z and p.Z <= hi.Z then
					top = math.max(top, p.Y + d.Size.Y / 2)
				end
			end
		end
		if top > 0 then
			hi = Vector3.new(hi.X, math.min(top, cfg().roofCap), hi.Z)
		end
	end
	local margin = cfg().margin
	local b = { min = lo - Vector3.new(margin, 0, margin), max = hi + Vector3.new(margin, 0, margin) }
	bounds = b
	return b
end

-- The stage: where the shells burst, over the front of the house, centred on its doors (seen whole
-- from the street, the Terrace, the Suite's terrace and every front window).
local function stage(): (number, number, number, number, number)
	local g = grounds()
	local c = cfg()
	local mid = Layout.Door.centre.X
	local half = c.stageHalfWidth
	local front = Layout.Foyer.minZ
	local back = front + (g.max.Z - front) * c.stageDepth
	return mid - half, mid + half, front, back, g.max.Y
end

local function anchor(at: Vector3, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Shell"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = at
	p.Parent = folder()
	return p
end

-- White-hot as it bursts, then each colour in turn, the change between them quick.
local function sequence(colours: Palette, hot: number?): ColorSequence
	local h = hot or 0.07
	local points = { ColorSequenceKeypoint.new(0, WHITE) }
	local n = #colours
	for i, c in colours do
		local from = h + (1 - h) * (i - 1) / n
		local to = h + (1 - h) * i / n
		table.insert(points, ColorSequenceKeypoint.new(math.min(from + 0.03, 0.97), c))
		if i < n then
			table.insert(points, ColorSequenceKeypoint.new(math.min(to - 0.03, 0.98), c))
		end
	end
	table.insert(points, ColorSequenceKeypoint.new(1, colours[n]))
	local ok, seq = pcall(function()
		return ColorSequence.new(points)
	end)
	return if ok then seq else ColorSequence.new(colours[1])
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Rate = 0
	e.LightEmission = 1
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.LockedToPart = false
	pcall(function()
		(e :: any).Brightness = cfg().brightness -- (stars that glow through the night air)
	end)
	for k, v in props do
		pcall(function()
			(e :: any)[k] = v
		end)
	end
	e.Parent = parent
	return e
end

-- The sky's generation: clearing it (Fireworks.stop) starts a new one, and what a shell still had
-- to do (its second burst, a flash, its own clearing) is dropped with it, never done in a shell
-- that's gone.
local generation = 0

local function later(seconds: number, fn: () -> ())
	local born = generation
	task.delay(seconds, function()
		if born == generation then
			pcall(fn)
		end
	end)
end

-- A shell's things are cleared once its last star is out.
local function done(p: Instance, after: number)
	local born = generation
	task.delay(after, function()
		if born == generation then
			p:Destroy()
			live -= 1
		end
	end)
end

local function flash(at: BasePart, colour: Color3, brightness: number, seconds: number?)
	local l = Instance.new("PointLight")
	l.Range = 60
	l.Brightness = brightness
	l.Color = colour
	l.Shadows = false
	l.Parent = at
	TweenService:Create(l, TweenInfo.new(seconds or 1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
end

-- A sound from the sky: a little after the light (sound is slower than light), quieter the
-- further off.
local function hear(at: Vector3, name: string, loud: number, pitchLo: number?, pitchHi: number?)
	local camera = Workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - at).Magnitude else 200
	local volume = loud * math.clamp(1 - distance / cfg().hearing, 0.3, 1)
	local lo, hi = pitchLo or 0.9, pitchHi or 1.1
	task.delay(math.min(distance / 1200, 0.6), function()
		pcall(Sound.play, name, volume, randomIn(lo, hi))
	end)
end

-- Every big burst lights the whole screen a moment in its colour (seen even from indoors, as light
-- through the windows), never more than a few times a second.
local lastGlow = 0
local function glow(colour: Color3, strength: number)
	local now = os.clock()
	if now - lastGlow < 0.16 then
		return
	end
	lastGlow = now
	local cc = Lighting:FindFirstChild("FireworkGlow")
	if not cc then
		local e = Instance.new("ColorCorrectionEffect")
		e.Name = "FireworkGlow"
		e.Brightness = 0
		e.TintColor = Color3.new(1, 1, 1)
		e.Parent = Lighting
		cc = e
	end
	local e = cc :: ColorCorrectionEffect
	e.Brightness = math.clamp(cfg().screenGlow * strength, 0, 0.3)
	e.TintColor = Color3.new(1, 1, 1):Lerp(colour, 0.35)
	TweenService:Create(e, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, TintColor = Color3.new(1, 1, 1) }):Play()
end

---------------------------------------------------------------------------------------------------
-- What every burst is made of
---------------------------------------------------------------------------------------------------

-- A star's head: bigger for a bigger shell, but always a point of light, never a blob.
local function head(s: number): number
	return 0.75 + 0.32 * s
end

type StarSpec = {
	n: number, -- how many (before the shell's size and the computer's quality)
	speed: number, -- how fast they're thrown (times the shell's size)
	spread: number?, -- how unevenly (0: a perfect sphere)
	life: number, -- seconds they burn
	drag: number?,
	fall: number?,
	size: number?,
	streak: number?, -- how long the streak behind each one (0: a round star)
	flicker: boolean?, -- strobing as they fall
	texture: string?,
	inner: number?, -- the slowest as a share of the fastest (a filled sphere, not a shell)
	direction: Enum.NormalId?,
	cone: number?, -- (with `direction`) the spread, in degrees
}

local STROBE = NumberSequence.new({
	kp(0, 0), kp(0.1, 0), kp(0.14, 1), kp(0.2, 0), kp(0.26, 1), kp(0.32, 0), kp(0.38, 1), kp(0.44, 0), kp(0.5, 1),
	kp(0.56, 0), kp(0.62, 1), kp(0.68, 0), kp(0.74, 1), kp(0.8, 0), kp(0.86, 1), kp(0.92, 0), kp(1, 1),
})

-- The stars of a burst: streaks that stretch as they fly and shrink as they slow.
local function stars(p: Instance, s: number, paint: Palette, o: StarSpec): ParticleEmitter
	local streak = o.streak or 2.2
	local size = head(s) * (o.size or 1)
	local fastest = o.speed * s
	local slowest = fastest * (o.inner or (1 - (o.spread or 0.05)))
	local e = emitter(p, {
		Texture = o.texture or SPARK,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Speed = NumberRange.new(slowest, fastest),
		Drag = o.drag or 2.3,
		Lifetime = NumberRange.new(o.life * 0.85, o.life),
		Acceleration = Vector3.new(0, -(o.fall or 8), 0),
		Size = NumberSequence.new({ kp(0, size * 1.5), kp(0.5, size), kp(1, 0) }),
		Squash = NumberSequence.new({ kp(0, 0), kp(0.05, streak), kp(0.5, streak * 0.55), kp(1, 0.2) }),
		Transparency = if o.flicker then STROBE else NumberSequence.new({ kp(0, 0), kp(0.72, 0.05), kp(1, 1) }),
		Color = sequence(paint),
		EmissionDirection = o.direction or Enum.NormalId.Top,
		SpreadAngle = if o.cone then Vector2.new(o.cone, o.cone) else Vector2.new(180, 180),
	})
	e:Emit(count(o.n, s))
	return e
end

-- Glitter tails: a haze of tiny sparks filling the path each star took (the chrysanthemum's gold).
local function tails(p: Instance, s: number, colour: Color3, n: number, speed: number, life: number, drag: number?)
	local e = emitter(p, {
		Texture = DUST,
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Speed = NumberRange.new(speed * s * 0.15, speed * s * 0.96),
		Drag = drag or 2.3,
		Lifetime = NumberRange.new(life * 0.5, life),
		Acceleration = Vector3.new(0, -9, 0),
		Size = NumberSequence.new({ kp(0, head(s) * 2.4), kp(1, 0) }),
		Squash = NumberSequence.new(1.2),
		Transparency = NumberSequence.new({ kp(0, 0.1), kp(0.5, 0.3), kp(1, 1) }),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.15, colour), ColorSequenceKeypoint.new(1, EMBER) }),
	})
	e:Emit(count(n, s))
end

-- Glitter that twinkles where it hangs, falling slowly (the kamuro's and the brocade's).
local function glitter(p: Instance, s: number, colour: Color3, n: number, speed: number, life: number)
	local e = emitter(p, {
		Texture = DUST,
		Speed = NumberRange.new(speed * s * 0.2, speed * s),
		Drag = 1.6,
		Lifetime = NumberRange.new(life * 0.6, life),
		Acceleration = Vector3.new(0, -7, 0),
		Size = NumberSequence.new({ kp(0, head(s) * 1.6), kp(1, head(s) * 0.6) }),
		Transparency = STROBE,
		Color = ColorSequence.new(WHITE, colour),
	})
	e:Emit(count(n, s))
end

-- Dragon's eggs: sparks that ride out dark, then crackle into tiny flashes where they hang.
local function crackles(p: Instance, s: number, n: number, speed: number, at: number?)
	local start = at or 0.62
	local e = emitter(p, {
		Speed = NumberRange.new(speed * s * 0.25, speed * s),
		Drag = 2.4,
		Lifetime = NumberRange.new(1.3, 2.1),
		Acceleration = Vector3.new(0, -6, 0),
		Size = NumberSequence.new(head(s) * 0.9),
		Transparency = NumberSequence.new({
			kp(0, 1), kp(start, 1), kp(start + 0.02, 0), kp(start + 0.06, 1), kp(start + 0.11, 0), kp(start + 0.15, 1),
			kp(start + 0.21, 0), kp(start + 0.25, 1), kp(1, 1),
		}),
		Color = ColorSequence.new(WHITE, LEMON),
	})
	e:Emit(count(n, s))
end

-- The burst's white-hot heart and its shockwave.
local function blast(p: BasePart, s: number, colour: Color3, size: number?)
	local core = emitter(p, {
		Speed = NumberRange.new(0, 1),
		Lifetime = NumberRange.new(0.1, 0.16),
		Size = NumberSequence.new({ kp(0, (size or 9) * head(s)), kp(1, (size or 9) * head(s) * 0.4) }),
		Color = ColorSequence.new(WHITE, colour),
	})
	core:Emit(2)
	local wave = emitter(p, {
		Texture = RING,
		Speed = NumberRange.new(0, 0),
		Lifetime = NumberRange.new(0.32, 0.42),
		Rotation = NumberRange.new(0, 360),
		Size = NumberSequence.new({ kp(0, 2 * head(s)), kp(1, (size or 9) * head(s) * 3.2) }),
		Transparency = NumberSequence.new({ kp(0, 0.25), kp(1, 1) }),
		Color = ColorSequence.new(WHITE, colour),
	})
	wave:Emit(1)
end

-- Smoke that hangs where a shell burst, drifting, lit by the bursts after it.
local function smoke(at: Vector3, s: number)
	if q < 0.6 then
		return
	end
	local p = anchor(at, "Smoke")
	local e = emitter(p, {
		Texture = SMOKE,
		LightEmission = 0.05,
		LightInfluence = 0.9,
		Speed = NumberRange.new(2, 6),
		Drag = 0.4,
		Lifetime = NumberRange.new(7, 11),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-8, 8),
		Acceleration = Vector3.new(1.4, 0.5, 0.7),
		Size = NumberSequence.new({ kp(0, 10 * head(s)), kp(1, 26 * head(s)) }),
		Transparency = NumberSequence.new({ kp(0, 1), kp(0.12, 0.88), kp(0.7, 0.92), kp(1, 1) }),
		Color = ColorSequence.new(rgb(96, 96, 108)),
	})
	pcall(function()
		(e :: any).Brightness = 1
	end)
	e:Emit(math.max(1, math.floor(3 * q)))
	task.delay(12, function()
		p:Destroy()
	end)
end

---------------------------------------------------------------------------------------------------
-- Comets: stars with real tails (trails that follow them through the sky), for palms, willows and
-- the kamuro's branches. A comet flies on its own, slowed by the air and pulled down.
---------------------------------------------------------------------------------------------------

type Comet = { part: Part, vel: Vector3, drag: number, fall: number, ends: number, sparks: ParticleEmitter? }
local comets: { Comet } = {}
local cometStep: RBXScriptConnection? = nil

local function stepComets(dt: number)
	local now = os.clock()
	for i = #comets, 1, -1 do
		local c = comets[i]
		if now >= c.ends or c.part.Parent == nil then
			table.remove(comets, i)
			local sparks = c.sparks
			if sparks then
				sparks.Enabled = false
			end
			-- (It stops where it is; its tail fades on its own, then it goes.)
			local part = c.part
			task.delay(2.5, function()
				part:Destroy()
			end)
		else
			c.vel = c.vel * math.exp(-c.drag * dt) - Vector3.new(0, c.fall * dt, 0)
			c.part.Position += c.vel * dt
		end
	end
	if #comets == 0 then
		local step = cometStep
		if step then
			step:Disconnect()
			cometStep = nil
		end
	end
end

type CometLook = { colour: Color3, width: number, tail: number, drag: number, fall: number, glitter: boolean? }

local function comet(from: Vector3, vel: Vector3, life: number, look: CometLook)
	if #comets >= cfg().maxComets then
		return
	end
	local p = anchor(from, "Comet")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, look.width / 2, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -look.width / 2, 0)
	a1.Parent = p
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.FaceCamera = true
	t.Lifetime = look.tail
	t.MinLength = 0.1
	t.LightEmission = 1
	t.LightInfluence = 0
	t.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, WHITE), ColorSequenceKeypoint.new(0.2, look.colour), ColorSequenceKeypoint.new(1, EMBER) })
	t.Transparency = NumberSequence.new({ kp(0, 0), kp(0.45, 0.3), kp(1, 1) })
	t.WidthScale = NumberSequence.new({ kp(0, 1), kp(1, 0.15) })
	pcall(function()
		(t :: any).Brightness = 3
	end)
	t.Parent = p
	local sparks: ParticleEmitter? = nil
	if look.glitter and q >= 0.6 then
		sparks = emitter(p, {
			Texture = DUST,
			Rate = 26,
			Speed = NumberRange.new(0, 2),
			Lifetime = NumberRange.new(0.6, 1.3),
			Acceleration = Vector3.new(0, -8, 0),
			Size = NumberSequence.new({ kp(0, look.width * 1.4), kp(1, 0) }),
			Transparency = STROBE,
			Color = ColorSequence.new(WHITE, look.colour),
		})
	end
	table.insert(comets, { part = p, vel = vel, drag = look.drag, fall = look.fall, ends = os.clock() + life, sparks = sparks })
	if not cometStep then
		cometStep = RunService.Heartbeat:Connect(stepComets)
	end
end

-- A spray of comets from `at`, in every direction a little above the horizon and below it.
local function cometBurst(at: Vector3, s: number, n: number, speed: number, life: number, look: CometLook, upward: number?)
	local total = math.max(3, math.floor(n * math.sqrt(q)))
	for i = 1, total do
		local a = (i - 1) / total * math.pi * 2 + randomIn(-0.12, 0.12)
		local up = randomIn(-0.35, 0.55) + (upward or 0)
		local dir = Vector3.new(math.cos(a), up, math.sin(a)).Unit
		comet(at, dir * speed * s * randomIn(0.92, 1.05), life * randomIn(0.85, 1.05), look)
	end
end

---------------------------------------------------------------------------------------------------
-- The shells
---------------------------------------------------------------------------------------------------

type Burst = (at: Vector3, s: number, paint: Palette) -> ()

-- Kiku, the chrysanthemum: a perfect sphere of stars, each trailing gold as it flies.
local function kiku(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	stars(p, s, paint, { n = 200, speed = 62, life = 2.8, streak = 2.6 })
	tails(p, s, GOLD, 300, 62, 2.4)
	blast(p, s, paint[1])
	flash(p, paint[1], 8)
	hear(at, "fireworkBoom", 1)
	smoke(at, s)
	done(p, 3.4)
end

-- Botan, the peony: bright stars with no tails, changing colour as they fall.
local function botan(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	stars(p, s, paint, { n = 260, speed = 64, life = 2.7, streak = 1.5 })
	blast(p, s, paint[1])
	flash(p, paint[1], 7)
	hear(at, "fireworkBoom", 0.95)
	smoke(at, s)
	done(p, 3.2)
end

-- Yae-zaki: a double petal, a sphere round a heart of another colour.
local function yae(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	stars(p, s, paint, { n = 220, speed = 64, life = 2.7, streak = 1.8 })
	local heart = pick(HANABI)
	stars(p, s, heart, { n = 110, speed = 30, life = 2.4, streak = 1.2, size = 0.9 })
	blast(p, s, paint[1])
	flash(p, heart[1], 8)
	hear(at, "fireworkBoom", 1)
	smoke(at, s)
	done(p, 3.2)
end

-- Mie-zaki: a triple petal, three spheres one inside the next.
local function mie(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	stars(p, s, paint, { n = 220, speed = 66, life = 2.8, streak = 1.8 })
	stars(p, s, pick(HANABI), { n = 120, speed = 40, life = 2.5, streak = 1.4, size = 0.9 })
	stars(p, s, pick(HANABI), { n = 60, speed = 18, life = 2.2, streak = 0.8, size = 0.8 })
	blast(p, s, paint[1])
	flash(p, paint[1], 9)
	hear(at, "fireworkBoom", 1.05)
	smoke(at, s)
	done(p, 3.4)
end

local GOLD_COMET: CometLook = { colour = GOLD, width = 1.4, tail = 1.3, drag = 1.3, fall = 12, glitter = true }

-- Kamuro: a crown of heavy gold that hangs, then droops and drips, glittering, for seconds.
local function kamuro(at: Vector3, s: number, _paint: Palette)
	local p = anchor(at)
	stars(p, s, GOLDEN, { n = 150, speed = 50, life = 6, drag = 1.5, fall = 11, streak = 1.3, size = 1.1 })
	glitter(p, s, GOLD, 380, 50, 6)
	cometBurst(at, s, 16, 48, 4.5, GOLD_COMET)
	blast(p, s, GOLD, 11)
	flash(p, GOLD, 10, 2)
	hear(at, "fireworkBoom", 1.1, 0.8, 0.95)
	later(1.4, function()
		hear(at, "fireworkGlitter", 0.55)
	end)
	smoke(at, s)
	done(p, 6.8)
end

local WILLOW: CometLook = { colour = GOLD, width = 0.9, tail = 2.2, drag = 0.95, fall = 14 }

-- Yanagi, the willow: long gold branches that hang right down.
local function willow(at: Vector3, s: number, _paint: Palette)
	local p = anchor(at)
	stars(p, s, GOLDEN, { n = 90, speed = 46, life = 5, drag = 1.2, fall = 13, streak = 1.6, size = 0.8 })
	cometBurst(at, s, 26, 40, 5, WILLOW, 0.2)
	blast(p, s, GOLD, 8)
	flash(p, GOLD, 8, 2)
	hear(at, "fireworkBoom", 0.9, 0.8, 0.95)
	done(p, 5.6)
end

-- A palm: thick gold comets thrown out and curling down like fronds, glittering.
local PALM: CometLook = { colour = GOLD, width = 2.2, tail = 1.1, drag = 1.0, fall = 18, glitter = true }
local function palm(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	cometBurst(at, s, 11, 62, 3.2, PALM, 0.25)
	stars(p, s, paint, { n = 70, speed = 22, life = 1.8, streak = 1, size = 0.8 })
	blast(p, s, GOLD, 10)
	flash(p, GOLD, 9)
	hear(at, "fireworkBoom", 1.05)
	smoke(at, s)
	done(p, 3.6)
end

-- A ring: a hoop of stars, tilted, with a small heart of another colour.
local function ring(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	p.CFrame = CFrame.new(at) * CFrame.Angles(math.rad(randomIn(55, 90)), math.rad(randomIn(0, 360)), 0)
	local e = emitter(p, {
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		ShapePartial = 1,
		SpreadAngle = Vector2.new(1, 1),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Speed = NumberRange.new(64 * s, 66 * s),
		Drag = 2.3,
		Lifetime = NumberRange.new(2.3, 2.7),
		Acceleration = Vector3.new(0, -4, 0),
		Size = NumberSequence.new({ kp(0, head(s) * 1.5), kp(1, 0) }),
		Squash = NumberSequence.new({ kp(0, 0), kp(0.05, 2), kp(1, 0.4) }),
		Color = sequence(paint),
	})
	e:Emit(count(170, s))
	stars(p, s, { if paint[#paint] == paint[1] then WHITE else paint[#paint] }, { n = 50, speed = 14, life = 2, streak = 0.6, size = 0.8 })
	blast(p, s, paint[1])
	flash(p, paint[1], 6)
	hear(at, "fireworkBoom", 0.85)
	done(p, 3)
end

-- Saturn: a small planet with a ring round it.
local function saturn(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	stars(p, s, paint, { n = 140, speed = 26, life = 2.6, streak = 1, size = 0.9 })
	local band = anchor(at)
	band.CFrame = CFrame.new(at) * CFrame.Angles(math.rad(72), math.rad(randomIn(-25, 25)), 0)
	local e = emitter(band, {
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		ShapePartial = 1,
		SpreadAngle = Vector2.new(1, 1),
		Orientation = Enum.ParticleOrientation.VelocityParallel,
		Speed = NumberRange.new(66 * s, 68 * s),
		Drag = 2.3,
		Lifetime = NumberRange.new(2.4, 2.8),
		Size = NumberSequence.new({ kp(0, head(s) * 1.3), kp(1, 0) }),
		Squash = NumberSequence.new({ kp(0, 0), kp(0.05, 2.2), kp(1, 0.4) }),
		Color = sequence({ GOLD }),
	})
	e:Emit(count(160, s))
	blast(p, s, paint[1])
	flash(p, GOLD, 7)
	hear(at, "fireworkBoom", 0.9)
	task.delay(3.2, function()
		band:Destroy()
	end)
	done(p, 3.2)
end

-- Senrin, the thousand flowers: a burst whose sparks each bloom again into a little flower.
local function senrin(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	stars(p, s, { GOLD }, { n = 50, speed = 30, life = 0.8, streak = 1.5, size = 0.7 })
	blast(p, s, GOLD, 6)
	flash(p, GOLD, 5)
	hear(at, "fireworkBoom", 0.8)
	local n = math.max(6, math.floor(18 * q))
	for i = 1, n do
		local dir = Vector3.new(randomIn(-1, 1), randomIn(-0.6, 0.8), randomIn(-1, 1)).Unit
		local where = at + dir * randomIn(14, 30) * s
		later(randomIn(0.65, 1.35), function()
			local f = anchor(where, "Flower")
			stars(f, s, pick(HANABI), { n = 34, speed = 14, life = 1.4, streak = 0.8, size = 0.6 })
			flash(f, WHITE, 2, 0.4)
			task.delay(1.7, function()
				f:Destroy()
			end)
		end)
	end
	later(0.9, function()
		hear(at, "fireworkCrackle", 0.75)
	end)
	done(p, 3)
end

-- Dragon's eggs: a burst of gold that crackles into a cloud of tiny white flashes.
local function crackle(at: Vector3, s: number, paint: Palette)
	local p = anchor(at)
	stars(p, s, { GOLD, paint[1] }, { n = 80, speed = 50, life = 1.4, streak = 1.8, size = 0.9 })
	crackles(p, s, 420, 52)
	blast(p, s, GOLD)
	flash(p, GOLD, 6)
	hear(at, "fireworkBoom", 0.85)
	later(0.95, function()
		hear(at, "fireworkCrackle", 0.9)
	end)
	smoke(at, s)
	done(p, 3)
end

-- A salute: a blinding white flash, a double shockwave and the loudest report of the show.
local function salute(at: Vector3, s: number, _paint: Palette)
	local p = anchor(at)
	blast(p, s, WHITE, 16)
	later(0.05, function()
		blast(p, s * 1.3, WHITE, 12)
	end)
	stars(p, s, { WHITE }, { n = 170, speed = 40, life = 1.4, streak = 1, size = 0.6, flicker = true, inner = 0.25 })
	flash(p, WHITE, 18, 0.6)
	glow(WHITE, 2.2)
	hear(at, "fireworkReport", 1.35, 0.92, 1.08)
	later(0.12, function()
		hear(at, "fireworkRumble", 0.8, 0.85, 1)
	end)
	done(p, 2)
end

-- A strobe pot: white stars that hang and blink.
local function strobe(at: Vector3, s: number, _paint: Palette)
	local p = anchor(at)
	stars(p, s, { WHITE }, { n = 110, speed = 30, life = 3.2, drag = 1.6, fall = 3, streak = 0.2, size = 0.8, flicker = true, inner = 0.3 })
	for i = 0, 2 do
		later(0.5 + i * 0.6, function()
			flash(p, WHITE, 4, 0.25)
		end)
	end
	hear(at, "fireworkBoom", 0.7, 1.05, 1.2)
	later(0.6, function()
		hear(at, "fireworkGlitter", 0.45)
	end)
	done(p, 3.6)
end

-- A brocade crown: heavy gold glitter thrown wide, falling in a crown.
local function brocade(at: Vector3, s: number, _paint: Palette)
	local p = anchor(at)
	stars(p, s, GOLDEN, { n = 220, speed = 58, life = 4, drag = 1.8, fall = 9, streak = 1.9, size = 1.1 })
	tails(p, s, GOLD, 380, 58, 3.4, 1.8)
	glitter(p, s, LEMON, 220, 56, 4.5)
	blast(p, s, GOLD, 10)
	flash(p, GOLD, 10, 1.6)
	hear(at, "fireworkBoom", 1.05, 0.85, 1)
	later(1.2, function()
		hear(at, "fireworkGlitter", 0.5)
	end)
	smoke(at, s)
	done(p, 4.8)
end

-- A peony that bursts three times, a beat apart, in three colours.
local function multiBreak(at: Vector3, s: number, paint: Palette)
	local choices = { { RED }, { WHITE }, { BLUE } }
	if math.random() < 0.5 then
		choices = { paint, { GOLD }, pick(MAJESTY) }
	end
	for i = 1, 3 do
		later((i - 1) * 0.38, function()
			live += 1
			local offset = Vector3.new(randomIn(-20, 20), (i - 2) * 12, randomIn(-20, 20)) * s * 0.4
			botan(at + offset, s * 0.62, choices[i])
		end)
	end
	live -= 1 -- (the three count themselves)
end

-- Shapes drawn in the sky: each star thrown to its own place, so the shape opens out whole and
-- facing whoever watches (each guest's own screen).
local function shapePoints(kind: string): { Vector2 }
	local out: { Vector2 } = {}
	if kind == "heart" then
		for i = 0, 39 do
			local t = i / 40 * math.pi * 2
			local x = 16 * math.sin(t) ^ 3
			local y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
			table.insert(out, Vector2.new(x, y) / 17)
		end
	elseif kind == "star" then
		local corners = {}
		for i = 0, 9 do
			local a = math.pi / 2 + i / 10 * math.pi * 2
			local r = if i % 2 == 0 then 1 else 0.42
			table.insert(corners, Vector2.new(math.cos(a), math.sin(a)) * r)
		end
		for i = 1, 10 do
			local a, b = corners[i], corners[i % 10 + 1]
			for k = 0, 3 do
				table.insert(out, a:Lerp(b, k / 4))
			end
		end
	elseif kind == "smile" then
		for i = 0, 27 do
			local a = i / 28 * math.pi * 2
			table.insert(out, Vector2.new(math.cos(a), math.sin(a)))
		end
		for i = 0, 10 do
			local a = math.rad(200 + i * 14)
			table.insert(out, Vector2.new(math.cos(a), math.sin(a)) * 0.6)
		end
		for _, ex in { -0.35, 0.35 } do
			table.insert(out, Vector2.new(ex, 0.35))
			table.insert(out, Vector2.new(ex, 0.25))
		end
	elseif kind == "rings" then
		for i = 0, 29 do
			local a = i / 30 * math.pi * 2
			table.insert(out, Vector2.new(math.cos(a) - 0.55, math.sin(a)) * 0.62)
			table.insert(out, Vector2.new(math.cos(a) + 0.55, math.sin(a)) * 0.62)
		end
	elseif kind == "monogram" then
		-- The house's initials, M and N, side by side.
		local strokes: { { Vector2 } } = {
			{ Vector2.new(-1, -0.6), Vector2.new(-1, 0.6), Vector2.new(-0.7, 0), Vector2.new(-0.4, 0.6), Vector2.new(-0.4, -0.6) },
			{ Vector2.new(0.2, -0.6), Vector2.new(0.2, 0.6), Vector2.new(0.9, -0.6), Vector2.new(0.9, 0.6) },
		}
		for _, stroke in strokes do
			for i = 1, #stroke - 1 do
				local a, b = stroke[i], stroke[i + 1]
				local steps = math.max(3, math.floor((b - a).Magnitude * 9))
				for k = 0, steps - 1 do
					table.insert(out, a:Lerp(b, k / steps))
				end
			end
			table.insert(out, stroke[#stroke])
		end
	end
	return out
end

local function shape(kind: string, at: Vector3, s: number, paint: Palette)
	local p = anchor(at, "Shape")
	p:SetAttribute("Shape", kind)
	-- Facing whoever watches: the shape's front toward the camera, right way round.
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else at - Vector3.new(0, 0, 200)
	local away = at - eye
	if away.Magnitude < 1 then
		away = Vector3.new(0, 0, 1)
	end
	p.CFrame = CFrame.lookAt(at, at + Vector3.new(away.X, 0, away.Z))
	local points = shapePoints(kind)
	local radius = cfg().shapeRadius * s
	local drag = 2.2
	for _, pt in points do
		local local3 = Vector3.new(pt.X, pt.Y, 0)
		local reach = local3.Magnitude
		if reach < 0.01 then
			continue
		end
		local a = Instance.new("Attachment")
		local dir = local3.Unit
		a.CFrame = CFrame.lookAt(Vector3.zero, dir, if math.abs(dir.Y) > 0.99 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0))
		a.Parent = p
		local e = emitter(a, {
			EmissionDirection = Enum.NormalId.Front,
			SpreadAngle = Vector2.new(0, 0),
			-- (In air that slows it as `drag`, a star thrown at v comes to rest v / drag away.)
			Speed = NumberRange.new(reach * radius * drag),
			Drag = drag,
			Lifetime = NumberRange.new(2.8, 3.1),
			Acceleration = Vector3.new(0, -3, 0),
			Size = NumberSequence.new({ kp(0, head(s) * 1.6), kp(0.8, head(s) * 1.2), kp(1, 0) }),
			Transparency = NumberSequence.new({ kp(0, 0), kp(0.8, 0.05), kp(1, 1) }),
			Color = sequence(paint, 0.1),
		})
		e:Emit(if q >= 0.7 then 2 else 1)
	end
	blast(p, s, paint[1], 8)
	flash(p, paint[1], 9)
	hear(at, "fireworkBoom", 1)
	done(p, 3.4)
end

local function shaped(kind: string): Burst
	return function(at: Vector3, s: number, paint: Palette)
		shape(kind, at, s, paint)
	end
end

local KINDS: { [string]: Burst } = {
	kiku = kiku,
	botan = botan,
	yae = yae,
	mie = mie,
	kamuro = kamuro,
	willow = willow,
	palm = palm,
	ring = ring,
	saturn = saturn,
	senrin = senrin,
	crackle = crackle,
	salute = salute,
	strobe = strobe,
	brocade = brocade,
	multiBreak = multiBreak,
	heart = shaped("heart"),
	star = shaped("star"),
	smile = shaped("smile"),
	rings = shaped("rings"),
	monogram = shaped("monogram"),
}

---------------------------------------------------------------------------------------------------
-- Launching
---------------------------------------------------------------------------------------------------

-- Where a shell goes up from, and where it bursts: over the stage.
local function sites(x: number?, height: number?): (Vector3, Vector3)
	local x0, x1, z0, z1, roof = stage()
	local c = cfg()
	local bx = x or randomIn(x0, x1)
	local bz = randomIn(z0, z1)
	local top = Vector3.new(bx, roof + (height or randomIn(c.heightMin, c.heightMax)), bz)
	local from = Vector3.new(bx + randomIn(-16, 16), 0, bz + randomIn(-16, 16))
	return from, top
end

-- One shell: up from the ground on a trail of sparks (some whistle as they go), then the burst.
local function launch(kind: string, s: number, paint: Palette, from: Vector3, top: Vector3)
	if live >= cfg().maxLive then
		return
	end
	live += 1
	local rocket = anchor(from, "Rocket")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.5, 0)
	a0.Parent = rocket
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.5, 0)
	a1.Parent = rocket
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.FaceCamera = true
	trail.Lifetime = 0.5
	trail.LightEmission = 1
	trail.Color = ColorSequence.new(rgb(255, 236, 190), AMBER)
	trail.Transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) })
	trail.WidthScale = NumberSequence.new({ kp(0, 1), kp(1, 0) })
	trail.Parent = rocket
	emitter(rocket, {
		Texture = DUST,
		Rate = 70,
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(14, 14),
		EmissionDirection = Enum.NormalId.Bottom,
		Lifetime = NumberRange.new(0.4, 0.9),
		Acceleration = Vector3.new(0, -14, 0),
		Size = NumberSequence.new({ kp(0, head(s) * 1.3), kp(1, 0) }),
		Color = ColorSequence.new(rgb(255, 236, 190), AMBER),
	})
	hear(from, "fireworkLaunch", 0.55, 0.75, 0.95)
	if math.random() < cfg().whistleChance then
		hear(from, "fireworkWhistle", 0.7, 0.9, 1.15)
	end
	local rise = randomIn(1.4, 2.1)
	TweenService:Create(rocket, TweenInfo.new(rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = top }):Play()
	local born = generation
	task.delay(rise, function()
		if born ~= generation then
			return -- (the sky was cleared while it climbed)
		end
		rocket:Destroy()
		local burst = KINDS[kind] or kiku
		local ok = pcall(burst, top, s, paint)
		if ok then
			glow(paint[1], s / cfg().size)
		else
			live -= 1
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Set pieces
---------------------------------------------------------------------------------------------------

-- A fan of shells side by side across the sky, in the colours given in turn.
local function fan(kind: string, s: number, paints: { Palette }, height: number?, alive: (() -> boolean)?)
	local x0, x1 = stage()
	local n = #paints
	local _, _, z0, z1 = stage()
	local z = (z0 + z1) / 2
	for i, paint in paints do
		if alive and not alive() then
			return
		end
		local x = x0 + (x1 - x0) * (i - 0.5) / n
		local from, top = sites(x, height)
		launch(kind, s, paint, Vector3.new(from.X, 0, z + randomIn(-10, 10)), Vector3.new(top.X, top.Y, z))
		task.wait(0.09)
	end
end

-- Mines: stars fired straight up from the ground in a fan.
local function mine(at: Vector3, s: number, paint: Palette)
	live += 1
	local p = anchor(at, "Mine")
	stars(p, s, paint, { n = 150, speed = 46, life = 2.2, drag = 0.9, fall = 40, streak = 2.2, size = 0.9, direction = Enum.NormalId.Top, cone = 22, inner = 0.55 })
	crackles(p, s * 0.6, 160, 60, 0.7)
	flash(p, paint[1], 6)
	hear(at, "fireworkBoom", 0.7, 1.1, 1.25)
	done(p, 3)
end

-- The street front of the house: its width either side of the doors, its parapet, its face.
local function facade(): (number, number, number, number)
	local St = Layout.Street
	return -St.houseHalfWidth, St.houseHalfWidth, St.facadeHeight, St.facadeZ - 1.5
end

-- Fountains (gerbs) of gold along the parapet of the house's front, for a few seconds.
local function fountains(s: number, seconds: number)
	local x0, x1, top, z = facade()
	local n = math.max(4, math.floor(9 * q))
	for i = 1, n do
		local x = x0 + (x1 - x0) * (i - 0.5) / n
		local p = anchor(Vector3.new(x, top + 1.5, z), "Fountain")
		local e = emitter(p, {
			Rate = 70 * q,
			Speed = NumberRange.new(36 * s * 0.5, 48 * s * 0.5),
			SpreadAngle = Vector2.new(9, 9),
			EmissionDirection = Enum.NormalId.Top,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Lifetime = NumberRange.new(1.6, 2.2),
			Acceleration = Vector3.new(0, -34, 0),
			Size = NumberSequence.new({ kp(0, head(s) * 0.9), kp(1, 0) }),
			Squash = NumberSequence.new(2),
			Color = ColorSequence.new(WHITE, GOLD),
		})
		flash(p, GOLD, 3, seconds)
		task.delay(seconds, function()
			e.Enabled = false
			task.wait(2.5)
			p:Destroy()
		end)
	end
	pcall(Sound.play, "fireworkHiss", 0.6)
end

-- Niagara Falls: a curtain of silver pouring from the parapet down the whole front of the house.
local function niagara(s: number, seconds: number)
	local x0, x1, top, z = facade()
	local n = math.max(8, math.floor(22 * q))
	for i = 1, n do
		local x = x0 + (x1 - x0) * (i - 0.5) / n
		local p = anchor(Vector3.new(x, top, z - 1), "Falls")
		local e = emitter(p, {
			Rate = 55 * q,
			Speed = NumberRange.new(3, 9),
			SpreadAngle = Vector2.new(10, 10),
			EmissionDirection = Enum.NormalId.Bottom,
			Orientation = Enum.ParticleOrientation.VelocityParallel,
			Lifetime = NumberRange.new(2.6, 3.4),
			Acceleration = Vector3.new(0, -18, 0),
			Size = NumberSequence.new({ kp(0, head(s) * 0.8), kp(1, head(s) * 0.3) }),
			Squash = NumberSequence.new(1.6),
			Transparency = NumberSequence.new({ kp(0, 0), kp(0.8, 0.2), kp(1, 1) }),
			Color = ColorSequence.new(WHITE, SILVER),
		})
		if i % 4 == 1 then
			flash(p, SILVER, 3, seconds)
		end
		task.delay(seconds, function()
			e.Enabled = false
			task.wait(3.5)
			p:Destroy()
		end)
	end
	pcall(Sound.play, "fireworkHiss", 0.8)
end

-- Searchlights: beams from the roofs sweeping the sky, for the grand finale.
local beams: { { beam: Beam, target: Attachment, base: Vector3, phase: number } } = {}
local beamStep: RBXScriptConnection? = nil
local function searchlights(on: boolean)
	if not on then
		local step = beamStep
		if step then
			step:Disconnect()
			beamStep = nil
		end
		for _, b in beams do
			local beam = b.beam
			TweenService:Create(beam, TweenInfo.new(1.5), { Width0 = 0, Width1 = 0 }):Play()
			task.delay(1.6, function()
				local holder = beam.Parent
				if holder then
					holder:Destroy()
				end
			end)
		end
		beams = {}
		return
	end
	if #beams > 0 then
		return
	end
	local x0, x1, z0, z1, roof = stage()
	local n = cfg().searchlights
	for i = 1, n do
		local x = x0 + (x1 - x0) * (i - 0.5) / n
		local base = Vector3.new(x, roof - 2, (z0 + z1) / 2)
		local holder = anchor(base, "Searchlight")
		local a0 = Instance.new("Attachment")
		a0.Parent = holder
		local a1 = Instance.new("Attachment")
		a1.WorldPosition = base + Vector3.new(0, 500, 0)
		a1.Parent = holder
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.Width0 = 3
		beam.Width1 = 36
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Color = ColorSequence.new(rgb(255, 244, 222))
		beam.Transparency = NumberSequence.new({ kp(0, 0.55), kp(0.6, 0.85), kp(1, 1) })
		beam.Parent = holder
		table.insert(beams, { beam = beam, target = a1, base = base, phase = i * 1.7 })
	end
	local t = 0
	beamStep = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		for _, b in beams do
			local lean = math.sin(t * 0.45 + b.phase) * 0.6
			local turn = math.cos(t * 0.3 + b.phase * 0.7) * 0.5
			local dir = Vector3.new(math.sin(lean), 1, math.sin(turn) * 0.6).Unit
			b.target.WorldPosition = b.base + dir * 500
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The score
---------------------------------------------------------------------------------------------------

local conductor = 0 -- the show whose music is playing (the latest to start)
local stopScore: (() -> ())? = nil

local function music(show: number, cue: string?)
	if show ~= conductor then
		return
	end
	local stop = stopScore
	if stop then
		stop()
		stopScore = nil
	end
	local score = cfg().score
	local id = if cue and type(score) == "table" then score[cue] else nil
	if type(id) == "string" and id ~= "" then
		stopScore = Sound.score(id, cfg().scoreVolume)
	end
end

---------------------------------------------------------------------------------------------------
-- Watching
---------------------------------------------------------------------------------------------------

-- The camera goes outside, across the street, and looks up at the show over the house (drifting
-- between three views), until the show ends or the guest goes back.
local watching = false
local watchGui: ScreenGui? = nil
local watchKey: TextButton? = nil

local function shot(i: number): CFrame
	local x0, x1, z0, z1, roof = stage()
	local c = cfg()
	local cx = (x0 + x1) / 2
	local sky = Vector3.new(cx, roof + c.heightMin + 25, (z0 + z1) / 2)
	local front = Layout.Foyer.minZ - c.watchDistance
	local spots = {
		Vector3.new(cx - 70, roof - 15, front),
		Vector3.new(cx + 70, roof - 5, front + 8),
		Vector3.new(cx, roof + 10, front - 10),
	}
	local eye = spots[(i - 1) % #spots + 1]
	return CFrame.lookAt(eye, sky)
end

local function setKey(text: string)
	local k = watchKey
	if k then
		k.Text = text
	end
end

function Fireworks.watch(on: boolean)
	if on == watching then
		return
	end
	if on and CameraRig.isAtTable() then
		return -- (at a table the sorting screen keeps the camera)
	end
	watching = on
	if on then
		local i = 0
		CameraRig.watch(function(): CFrame?
			i += 1
			return shot(i)
		end, 7)
		setKey("Back to the house")
	else
		CameraRig.stopWatching()
		setKey("Watch the fireworks")
	end
end

function Fireworks.isWatching(): boolean
	return watching
end

-- (Kept out of sight for a while under a cinematic that has the screen and the camera: Admin
-- Abuse's opening. It comes back by itself after.)
local watchHiddenUntil = 0

function Fireworks.hideWatch(seconds: number)
	watchHiddenUntil = math.max(watchHiddenUntil, os.clock() + seconds)
	local gui = watchGui
	if gui then
		gui.Enabled = false
	end
	task.delay(seconds, function()
		local g = watchGui
		if g and os.clock() >= watchHiddenUntil - 0.05 then
			g.Enabled = true
		end
	end)
end

-- The key to watch (and to come back), low in the middle of the screen while a show is on.
local function offerWatch(on: boolean)
	if not on then
		local gui = watchGui
		watchGui = nil
		watchKey = nil
		if gui then
			gui:Destroy()
		end
		return
	end
	if watchGui then
		return
	end
	local player = Players.LocalPlayer
	local parent = player and player:FindFirstChild("PlayerGui")
	if not parent then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FireworksWatch"
	gui.IgnoreGuiInset = false
	gui.ResetOnSpawn = false
	-- (Just under the sorting screen: a guest at a table isn't offered it over their pieces.)
	gui.DisplayOrder = 17
	gui.Enabled = os.clock() >= watchHiddenUntil
	local k = Instance.new("TextButton")
	k.Name = "Watch"
	-- Clear of the notices at the top that announce the show, and of the Eat key below it.
	k.AnchorPoint = Vector2.new(0.5, 1)
	k.Position = UDim2.new(0.5, 0, 1, -190)
	k.Size = UDim2.fromOffset(260, 44)
	k.BackgroundColor3 = Color3.fromRGB(176, 140, 72)
	k.TextColor3 = Color3.fromRGB(20, 16, 10)
	k.FontFace = Brand.Fonts.bodyBold
	k.TextSize = 18
	k.AutoButtonColor = true
	k.Text = if watching then "Back to the house" else "Watch the fireworks"
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = k
	k.Activated:Connect(function()
		Fireworks.watch(not watching)
	end)
	k.Parent = gui
	gui.Parent = parent
	watchGui = gui
	watchKey = k
end

-- Moving (or jumping) while watching brings the camera home.
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if watching and not processed and (input.KeyCode == Enum.KeyCode.W or input.KeyCode == Enum.KeyCode.A or input.KeyCode == Enum.KeyCode.S or input.KeyCode == Enum.KeyCode.D or input.KeyCode == Enum.KeyCode.Space) then
		Fireworks.watch(false)
	end
end)

-- While a show is on, the night air thins so the sky is clear (put back after).
local showsOn = 0
local savedAir: { density: number, haze: number }? = nil
local function clearSky(on: boolean)
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	showsOn = math.max(0, showsOn + (if on then 1 else -1))
	if not air then
		return
	end
	if on and showsOn == 1 then
		savedAir = { density = air.Density, haze = air.Haze }
		TweenService:Create(air, TweenInfo.new(2), { Density = math.min(air.Density, cfg().clearDensity), Haze = 0 }):Play()
	elseif not on and showsOn == 0 then
		local was = savedAir
		if was then
			TweenService:Create(air, TweenInfo.new(4), { Density = was.density, Haze = was.haze }):Play()
		end
		savedAir = nil
	end
end
-- (Admin Abuse's show thins the air too while its giant stands over the house: one count for both.)
Fireworks.clearSky = clearSky

---------------------------------------------------------------------------------------------------
-- The show
---------------------------------------------------------------------------------------------------

export type Act = { name: string, from: number, to: number }

-- The acts of a show `seconds` long: a short one plays Hanabi and Majesty, a longer one all three.
function Fireworks.acts(seconds: number): { Act }
	local c = cfg()
	if seconds < c.threeActsFrom then
		local cut = seconds * 0.46
		return { { name = "hanabi", from = 0, to = cut }, { name = "majesty", from = cut, to = seconds } }
	end
	return {
		{ name = "hanabi", from = 0, to = seconds * 0.34 },
		{ name = "liberty", from = seconds * 0.34, to = seconds * 0.68 },
		{ name = "majesty", from = seconds * 0.68, to = seconds },
	}
end

type ActPlan = { mix: { string }, palettes: { Palette }, pace: number }
local ACTS: { [string]: ActPlan } = {
	hanabi = { mix = { "kiku", "kiku", "botan", "botan", "yae", "mie", "kamuro", "senrin", "ring", "willow", "saturn" }, palettes = HANABI, pace = 1.15 },
	liberty = { mix = { "botan", "botan", "salute", "palm", "palm", "crackle", "brocade", "strobe", "multiBreak", "kiku", "crackle" }, palettes = LIBERTY, pace = 1.9 },
	majesty = { mix = { "kamuro", "brocade", "kiku", "crackle", "ring", "palm", "salute", "senrin", "willow", "yae", "botan" }, palettes = MAJESTY, pace = 2.4 },
}

-- (Thrown through a show that's been stopped, to end it where it stands.)
local HALTED = "[Maison] fireworks halted"

-- Fires the act's own shells at its pace until `untilT` (seconds since the show began), `busy` the
-- pace's multiple (the finale's barrage).
local function body(t0: number, untilT: number, s: number, act: ActPlan, busy: number, alive: () -> boolean)
	while alive() and os.clock() - t0 < untilT do
		local rate = act.pace * s / cfg().size * busy
		if math.random() < 0.18 then
			-- A volley: the same shell, side by side, a beat apart.
			local kind = pick(act.mix)
			local paint = pick(act.palettes)
			local x0, x1 = stage()
			local n = math.random(3, 5)
			local cx = randomIn(x0 + 60, x1 - 60)
			for i = 1, n do
				local from, top = sites(cx + (i - (n + 1) / 2) * 42)
				launch(kind, s, paint, from, top)
				task.wait(0.1)
			end
		else
			local from, top = sites()
			launch(pick(act.mix), s, pick(act.palettes), from, top)
		end
		task.wait(randomIn(0.55, 1.35) / math.max(0.25, rate))
	end
	if not alive() then
		error(HALTED, 0)
	end
end

local shows = 0
-- The shows going on now, each with its tag and the way to stop it.
local running: { [number]: { tag: string?, halt: (now: boolean) -> () } } = {}

-- Plays a show of `seconds` over the whole estate.
function Fireworks.show(seconds: number, options: Options?)
	local o: Options = options or {}
	local scale = o.scale or 1
	local s = scale * cfg().size
	local grand = o.finale ~= false
	q = quality()
	shows += 1
	local me = shows
	if o.music ~= false then
		conductor = me
	end
	clearSky(true)
	offerWatch(true)
	if o.watch then
		Fireworks.watch(true)
	end
	local stopped = false
	local halted = false
	local function alive(): boolean
		return not stopped and not halted
	end
	local ended = false
	local function finish()
		if ended then
			return
		end
		ended = true
		stopped = true
		running[me] = nil
		clearSky(false)
		if showsOn == 0 then
			offerWatch(false)
			Fireworks.watch(false)
			searchlights(false)
		end
	end
	-- Stopped: no more launches; it ends at once (the sky cleared) or once its last shells are out.
	running[me] = {
		tag = o.tag,
		halt = function(now: boolean)
			halted = true
			if now then
				finish()
			else
				task.delay(4, finish)
			end
		end,
	}
	task.delay(seconds + 7, finish)
	task.spawn(function()
		local t0 = os.clock()
		-- (Every pause in the show ends it if it's been stopped meanwhile.)
		local function pause(t: number)
			task.wait(t)
			if not alive() then
				error(HALTED, 0)
			end
		end
		local function at(tt: number)
			local wait = tt - (os.clock() - t0)
			if wait > 0 then
				pause(wait)
			end
		end
		pcall(Sound.play, "fireworkTaiko", 0.9)
		local acts: { Act } = if o.act and ACTS[o.act] then { { name = o.act, from = 0, to = seconds } :: Act } else Fireworks.acts(seconds)
		local ok, why = pcall(function(): string?
			for _, act in acts do
				if not alive() then
					return nil
				end
				at(act.from)
				local plan = ACTS[act.name]
				local len = act.to - act.from
				music(me, act.name)
				if act.name == "hanabi" then
					-- The opening: three salutes across the sky, fountains of gold along the parapet, then
					-- the first great chrysanthemum alone. (A short act keeps only the chrysanthemum.)
					if len >= 10 then
						task.spawn(fan, "salute", s, { { WHITE }, { WHITE }, { WHITE } }, nil, alive)
						task.spawn(fountains, s, math.min(6, len * 0.3))
						pause(1.6)
					end
					local from, top = sites()
					local x0, x1 = stage()
					launch("kiku", s * 1.15, pick(HANABI), Vector3.new((x0 + x1) / 2, 0, from.Z), Vector3.new((x0 + x1) / 2, top.Y, top.Z))
					if len >= 16 then
						pause(1.4)
						body(t0, act.from + len * 0.4, s, plan, 1, alive)
						local f1, top1 = sites()
						launch("heart", s, { SAKURA, ROSE }, f1, top1)
						pause(0.8)
						body(t0, act.from + len * 0.62, s, plan, 1, alive)
						local f2, top2 = sites()
						launch(pick({ "star", "smile", "rings" }), s, pick(HANABI), f2, top2)
						local f3, top3 = sites()
						launch("saturn", s, pick(HANABI), f3, top3)
						pause(0.8)
						body(t0, act.from + len * 0.86, s, plan, 1.2, alive)
						task.spawn(fan, "kamuro", s, { GOLDEN, GOLDEN }, nil, alive)
					end
					body(t0, act.to, s, plan, 1, alive)
				elseif act.name == "liberty" then
					-- The flag across the sky and two salutes; then mines, Niagara, the body, and a volley of
					-- salutes to end it.
					task.spawn(fan, "botan", s, { { RED }, { WHITE }, { BLUE }, { WHITE }, { RED } }, nil, alive)
					pause(1.2)
					task.spawn(fan, "salute", s, { { WHITE }, { WHITE } }, nil, alive)
					body(t0, act.from + len * 0.3, s, plan, 1, alive)
					local x0, x1, z0 = stage()
					for i = 1, 5 do
						mine(Vector3.new(x0 + (x1 - x0) * (i - 0.5) / 5, 0, z0 - 6), s, pick(LIBERTY))
						pause(0.2)
					end
					body(t0, act.from + len * 0.45, s, plan, 1, alive)
					task.spawn(niagara, s, math.min(10, len * 0.4))
					body(t0, act.from + len * 0.85, s, plan, 1.2, alive)
					task.spawn(fan, "salute", s, { { WHITE }, { WHITE }, { WHITE }, { WHITE }, { WHITE } }, nil, alive)
					body(t0, act.to, s, plan, 1, alive)
				else
					-- Majesty: searchlights, a canopy of gold, the barrage, the house's monogram, and the
					-- last wall of golden willows.
					searchlights(true)
					if len >= 12 then
						task.spawn(fan, "kamuro", s, { GOLDEN, GOLDEN, GOLDEN, GOLDEN, GOLDEN }, nil, alive)
						pause(1.5)
					end
					if not grand then
						body(t0, act.to, s, plan, 1.2, alive)
						continue
					end
					-- (The close takes its last five seconds.)
					local close = math.max(act.from, act.to - 5)
					body(t0, act.from + (close - act.from) * 0.35, s, plan, 1.3, alive)
					body(t0, act.from + (close - act.from) * 0.6, s, plan, cfg().barrage, alive)
					if len >= 14 then
						local _, top = sites(nil, cfg().heightMax * 0.8)
						local x0, x1 = stage()
						launch("monogram", s * 1.1, GOLDEN, Vector3.new((x0 + x1) / 2, 0, top.Z), Vector3.new((x0 + x1) / 2, top.Y, top.Z))
						task.spawn(fan, "ring", s, { { GOLD }, { WHITE } }, nil, alive)
						pause(1)
					end
					body(t0, close, s, plan, cfg().barrage, alive)
					-- The close: a wall of gold willows over every roof, crackling, and the last salutes.
					music(me, "close")
					local wall: { Palette } = {}
					for _ = 1, cfg().closingWillows do
						table.insert(wall, GOLDEN)
					end
					task.spawn(fan, "willow", s * 1.2, wall, cfg().heightMax, alive)
					pause(0.6)
					task.spawn(fan, "crackle", s, { GOLDEN, GOLDEN, GOLDEN }, nil, alive)
					pause(1.4)
					task.spawn(fan, "salute", s * 1.2, { { WHITE }, { WHITE }, { WHITE } }, nil, alive)
					pause(1)
					if me == conductor then
						pcall(Sound.play, "crowdCheer", 0.8)
					end
				end
			end
			return nil
		end)
		if not ok and why ~= HALTED then
			warn("[Maison] fireworks: " .. tostring(why))
		end
		if me == conductor then
			music(me, nil)
		end
	end)
end

-- Stops shows: those with `tag` ("effect": Admin Abuse's, for Every effect OFF), or with none
-- given, every one. They launch nothing more. If no other show is left in the sky it's cleared at
-- once; otherwise (a guest's Salute going on) the stopped ones' last shells simply burn out.
function Fireworks.stop(tag: string?)
	local others = false
	for _, r in running do
		if tag ~= nil and r.tag ~= tag then
			others = true
		end
	end
	for _, r in running do
		if tag == nil or r.tag == tag then
			r.halt(not others)
		end
	end
	if others then
		return
	end
	generation += 1
	local f = (Workspace:FindFirstChild("MaisonLocal") or Workspace):FindFirstChild("Fireworks")
	if f then
		f:ClearAllChildren()
	end
	comets = {}
	searchlights(false)
	local stop = stopScore
	if stop then
		stop()
		stopScore = nil
	end
	live = 0
end

-- (For the client's checks: how many shells are in the sky.)
function Fireworks.live(): number
	return live
end

return Fireworks

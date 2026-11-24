--!strict
-- Luxury Island's life on a guest's own screen, while they're on it (World/IslandView starts and
-- stops it, and tells it the island's chosen light). The island itself is built on the server with
-- no lights of its own; here, by the tags it carries (server/Attractions/IslandBuild):
--   IslandTorch    firelight: a flame and a warm light that flickers (unlit at noon)
--   IslandLantern  lamps and string lights glowing (a share of the lamps really light the night)
--   IslandGlow     the lit rooms behind the glass, warm
--   IslandPool     the pools' and the aquarium's blue light, the great yacht's glow beneath it
--   IslandFoam     the surf breathing along the sand, at the waterfall's foot
--   IslandFlag     flags stirring in the breeze
--   IslandBlink    the jet's navigation lights blinking
--   IslandFish     the aquarium's fish swimming
--   IslandMist     the waterfall's mist and spray
-- and, of its own: glitter on the water (a path of it toward the sun or the moon), fireflies in the
-- gardens and on the terraces at dusk and at night, gulls circling in the day.
-- Everything is put back as it was when the guest leaves. On a phone (touch, no keyboard), half
-- the sparkle and fewer real lights; only the gulls move every frame (the rest is tweened by the
-- engine, or flickers a few times a second).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local IslandLife = {}

local rgb = Color3.fromRGB

type Mood = {
	torch: number, -- the torches' light (0: unlit)
	lantern: number, -- the lanterns' glass (its transparency: 0 is fully lit)
	lamp: number, -- the lamps' real light
	glow: number, -- the rooms' light
	room: number, -- the rooms' glass (its transparency)
	pool: number, -- the pools' light
	sparkle: Color3,
	glitter: number, -- sparkles a second on the lagoon (the open sea's path takes more)
	fireflies: number, -- fireflies a second in each place (0: none)
	gulls: boolean,
}

local MOODS: { [string]: Mood } = {
	golden = { torch = 1.3, lantern = 0.2, lamp = 1.1, glow = 1.5, room = 0.3, pool = 1.2, sparkle = rgb(255, 222, 170), glitter = 36, fireflies = 1.2, gulls = true },
	azure = { torch = 0, lantern = 0.75, lamp = 0, glow = 0.5, room = 0.65, pool = 0.3, sparkle = rgb(255, 255, 250), glitter = 26, fireflies = 0, gulls = true },
	dawn = { torch = 0.9, lantern = 0.45, lamp = 0.6, glow = 1.1, room = 0.42, pool = 0.9, sparkle = rgb(255, 206, 214), glitter = 30, fireflies = 0.6, gulls = true },
	moonlit = { torch = 1.6, lantern = 0, lamp = 1.6, glow = 1.9, room = 0.15, pool = 1.8, sparkle = rgb(214, 226, 255), glitter = 10, fireflies = 1.6, gulls = false },
	starlit = { torch = 1.6, lantern = 0, lamp = 1.5, glow = 1.8, room = 0.15, pool = 1.8, sparkle = rgb(200, 214, 255), glitter = 7, fireflies = 1.8, gulls = false },
}
IslandLife.MOODS = MOODS

local function phone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function origin(): Vector3
	local o = ((Config.data :: any).Attractions.island or {}).origin
	if type(o) == "table" then
		return Vector3.new(o[1], o[2], o[3])
	end
	return Vector3.zero
end

---------------------------------------------------------------------------------------------------
-- What's been made and changed (all undone on leaving)
---------------------------------------------------------------------------------------------------
local active = false
local moodId: string? = nil
local made: { Instance } = {}
local conns: { RBXScriptConnection } = {}
local tweens: { Tween } = {}
local restore: { { part: BasePart, cf: CFrame, transparency: number } } = {}
local touched: { [Instance]: boolean } = {}
local folder: Folder? = nil

type Flicker = { light: PointLight, seed: number }
local torches: { { flame: BasePart, light: PointLight, fire: Fire? } } = {}
local flickers: { Flicker } = {}
local lanterns: { BasePart } = {}
local lampLights: { PointLight } = {}
local glows: { BasePart } = {}
local glowLights: { PointLight } = {}
local poolLights: { PointLight } = {}
local glitters: { { emitter: ParticleEmitter, share: number } } = {}
local flies: { ParticleEmitter } = {}
type Gull = { body: BasePart, left: BasePart, right: BasePart, centre: Vector3, radius: number, speed: number, phase: number, height: number }
local gulls: { Gull } = {}

-- (Caps on real lights: a desktop, a phone.)
local function cap(desktop: number, onPhone: number): number
	return if phone() then onPhone else desktop
end

local function remember(part: BasePart)
	if touched[part] then
		return
	end
	touched[part] = true
	table.insert(restore, { part = part, cf = part.CFrame, transparency = part.Transparency })
end

local function holder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "IslandLife"
	nf.Parent = Workspace
	folder = nf
	table.insert(made, nf)
	return nf
end

local function pointLight(parent: Instance, colour: Color3, range: number): PointLight
	local l = Instance.new("PointLight")
	l.Name = "IslandLight"
	l.Color = colour
	l.Range = range
	l.Brightness = 0
	l.Shadows = false
	l.Parent = parent
	table.insert(made, l)
	return l
end

local function play(t: Tween)
	table.insert(tweens, t)
	t:Play()
end

-- A particle emitter, its rate halved on a phone (and marked so the house's own easing, which
-- halves every emitter on a light screen, leaves it as it is).
local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "IslandEmitter"
	e:SetAttribute("QualityEased", true)
	for k, v in props do
		pcall(function()
			(e :: any)[k] = v
		end)
	end
	e.Parent = parent
	table.insert(made, e)
	return e
end

local function rate(n: number): number
	return if phone() then n * 0.5 else n
end

-- An unseen anchored part: where particles come from.
local function volume(name: string, size: Vector3, at: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.CFrame = CFrame.new(at)
	p.Parent = holder()
	return p
end

---------------------------------------------------------------------------------------------------
-- The tagged pieces of the island
---------------------------------------------------------------------------------------------------
local function onTorch(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	remember(i)
	local light = pointLight(i, rgb(255, 150, 70), if i.Size.X > 1 then 20 else 14)
	local fire: Fire? = nil
	if not phone() or #torches % 2 == 0 then
		local f = Instance.new("Fire")
		f.Name = "IslandFire"
		f.Size = if i.Size.X > 1 then 4 else 2.2
		f.Heat = 6
		f.Color = rgb(255, 120, 40)
		f.SecondaryColor = rgb(255, 204, 100)
		f.Enabled = false
		f.Parent = i
		table.insert(made, f)
		fire = f
	end
	table.insert(torches, { flame = i, light = light, fire = fire })
	table.insert(flickers, { light = light, seed = #flickers * 1.7 + 0.3 })
end

local function onLantern(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	remember(i)
	table.insert(lanterns, i)
	-- (A share of the lamps light the night for real: every third, up to the screen's cap.)
	if i.Name == "Lantern" and #lanterns % 3 == 1 and #lampLights < cap(18, 6) then
		table.insert(lampLights, pointLight(i, rgb(255, 196, 128), 14))
	end
end

local function onGlow(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	remember(i)
	table.insert(glows, i)
	local range = i:GetAttribute("Range")
	local r = if type(range) == "number" then range else 18
	-- (A long band of glass: a light every so far along it, three at most.)
	local long = math.max(i.Size.X, i.Size.Z)
	local n = math.clamp(math.floor(long / 26) + 1, 1, 3)
	for k = 1, n do
		if #glowLights >= cap(24, 8) then
			return
		end
		local a = Instance.new("Attachment")
		a.Name = "IslandGlowAt"
		local along = (k - 0.5) / n - 0.5
		a.Position = if i.Size.X >= i.Size.Z then Vector3.new(along * i.Size.X, 0, 0) else Vector3.new(0, 0, along * i.Size.Z)
		a.Parent = i
		table.insert(made, a)
		table.insert(glowLights, pointLight(a, rgb(255, 196, 130), r))
	end
end

local function onPool(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	remember(i)
	if #poolLights < cap(10, 4) then
		table.insert(poolLights, pointLight(i, rgb(120, 220, 255), 16))
	end
end

-- (A period for a piece, the same for pieces at the same height: a flag and its band, a fish and
-- its tail, move as one.)
local function period(part: BasePart, low: number, high: number): number
	local k = (math.floor(part.Position.Y * 10 + 0.5) % 97) / 97
	return low + (high - low) * k
end

local function onFoam(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	remember(i)
	local cf = i.CFrame
	play(TweenService:Create(i, TweenInfo.new(period(i, 3.2, 4.6), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = cf + Vector3.new(0, 0, -1.2), Transparency = math.min(0.9, i.Transparency + 0.4) }))
end

local function onFlag(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	remember(i)
	local hinge = i.CFrame * CFrame.new(-i.Size.X / 2, 0, 0)
	local swing = math.rad(14)
	i.CFrame = hinge * CFrame.Angles(0, -swing, 0) * CFrame.new(i.Size.X / 2, 0, 0)
	play(TweenService:Create(i, TweenInfo.new(period(i, 1.8, 2.6), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = hinge * CFrame.Angles(0, swing, 0) * CFrame.new(i.Size.X / 2, 0, 0) }))
end

local function onBlink(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	remember(i)
	play(TweenService:Create(i, TweenInfo.new(0.14, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1, true, 1.1), { Transparency = 0.9 }))
end

local function onFish(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	remember(i)
	local swim = i.CFrame.LookVector * -3
	play(TweenService:Create(i, TweenInfo.new(period(i, 3, 5), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = i.CFrame + swim }))
end

local function onMist(i: Instance)
	if not i:IsA("BasePart") or touched[i] then
		return
	end
	touched[i] = true
	emitter(i, {
		Rate = rate(8),
		Lifetime = NumberRange.new(2, 3.2),
		Speed = NumberRange.new(1, 2.4),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(rgb(250, 252, 255)),
		LightEmission = 0.15,
		RotSpeed = NumberRange.new(-20, 20),
		Rotation = NumberRange.new(0, 360),
	})
	emitter(i, {
		Rate = rate(22),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(5, 9),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, -26, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.15) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(rgb(255, 255, 255)),
		LightEmission = 0.4,
	})
end

local WATCH: { [string]: (Instance) -> () } = {
	IslandTorch = onTorch,
	IslandLantern = onLantern,
	IslandGlow = onGlow,
	IslandPool = onPool,
	IslandFoam = onFoam,
	IslandFlag = onFlag,
	IslandBlink = onBlink,
	IslandFish = onFish,
	IslandMist = onMist,
}

---------------------------------------------------------------------------------------------------
-- Of its own: glitter on the water, fireflies, gulls
---------------------------------------------------------------------------------------------------
local function water()
	local o = origin()
	-- The lagoon, a path of glitter across the open sea toward the west (the sunset's side), the
	-- shallows by the Grand Villa's pier.
	type Glint = { name: string, size: Vector3, at: Vector3, share: number, small: number, big: number }
	local places: { Glint } = {
		{ name = "Lagoon", size = Vector3.new(240, 0.2, 130), at = Vector3.new(-10, 0.15, 215), share = 1, small = 0.5, big = 1.1 },
		{ name = "SunPath", size = Vector3.new(220, 0.2, 520), at = Vector3.new(-430, 0.15, 30), share = 1.6, small = 1.2, big = 2.6 },
		{ name = "Shallows", size = Vector3.new(90, 0.2, 60), at = Vector3.new(205, 0.15, 130), share = 0.5, small = 0.5, big = 1 },
	}
	for _, w in places do
		local part = volume("IslandGlitter" .. w.name, w.size, o + w.at)
		local e = emitter(part, {
			Rate = 0,
			Lifetime = NumberRange.new(0.35, 0.9),
			Speed = NumberRange.new(0, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, (w.small + w.big) / 2), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new(0.1),
			LightEmission = 1,
			LightInfluence = 0,
			Rotation = NumberRange.new(0, 360),
			ZOffset = 0.5,
		})
		table.insert(glitters, { emitter = e, share = w.share })
	end
end

local function fireflies()
	local o = origin()
	for _, f in { { Vector3.new(70, 6, 70), Vector3.new(-30, 9, 10) }, { Vector3.new(40, 4, 40), Vector3.new(-120, 43, 40) }, { Vector3.new(80, 5, 16), Vector3.new(-100, 9, 98) }, { Vector3.new(60, 5, 40), Vector3.new(124, 22, 30) }, { Vector3.new(40, 5, 30), Vector3.new(120, 9, 76) } } do
		local part = volume("IslandFireflies", f[1], o + f[2])
		table.insert(flies, emitter(part, {
			Rate = 0,
			Lifetime = NumberRange.new(4, 7),
			Speed = NumberRange.new(0.2, 0.7),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.08, 0),
			Drag = 0.4,
			Size = NumberSequence.new(0.16),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.12, 0.1),
				NumberSequenceKeypoint.new(0.3, 0.8),
				NumberSequenceKeypoint.new(0.45, 0.05),
				NumberSequenceKeypoint.new(0.65, 0.85),
				NumberSequenceKeypoint.new(0.8, 0.15),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Color = ColorSequence.new(rgb(255, 226, 120)),
			LightEmission = 1,
			LightInfluence = 0,
		}))
	end
end

local function gullPart(name: string, size: Vector3, colour: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = holder()
	return p
end

local function makeGulls()
	local o = origin()
	local rng = Random.new(11)
	for i = 1, (if phone() then 3 else 5) do
		table.insert(gulls, {
			body = gullPart("Gull", Vector3.new(0.5, 0.45, 1.6), rgb(246, 246, 244)),
			left = gullPart("GullWing", Vector3.new(2.6, 0.1, 0.9), rgb(232, 234, 236)),
			right = gullPart("GullWing", Vector3.new(2.6, 0.1, 0.9), rgb(232, 234, 236)),
			centre = o + Vector3.new(rng:NextNumber(-120, 120), 0, rng:NextNumber(-100, 140)),
			radius = rng:NextNumber(50, 130),
			speed = rng:NextNumber(0.1, 0.2) * (if i % 2 == 0 then 1 else -1),
			phase = rng:NextNumber(0, math.pi * 2),
			height = rng:NextNumber(60, 110),
		})
	end
end

local clock = 0
local function stepGulls(dt: number)
	clock += dt
	local parts: { BasePart } = {}
	local cfs: { CFrame } = {}
	for _, g in gulls do
		local a = g.phase + clock * g.speed
		local at = g.centre + Vector3.new(math.cos(a) * g.radius, g.height + math.sin(clock * 0.5 + g.phase) * 3, math.sin(a) * g.radius)
		local ahead = g.centre + Vector3.new(math.cos(a + 0.05 * math.sign(g.speed)) * g.radius, g.height, math.sin(a + 0.05 * math.sign(g.speed)) * g.radius)
		local bank = math.rad(14) * math.sign(g.speed)
		local body = CFrame.lookAt(at, Vector3.new(ahead.X, at.Y, ahead.Z)) * CFrame.Angles(0, 0, bank)
		-- (Wings: a few beats, then a long glide.)
		local beat = math.sin(clock * 9 + g.phase)
		local flap = if math.sin(clock * 0.7 + g.phase) > 0.2 then math.rad(8) else beat * math.rad(32)
		table.insert(parts, g.body)
		table.insert(cfs, body)
		table.insert(parts, g.left)
		table.insert(cfs, body * CFrame.new(-0.25, 0.1, 0) * CFrame.Angles(0, 0, -flap) * CFrame.new(-1.3, 0, 0))
		table.insert(parts, g.right)
		table.insert(cfs, body * CFrame.new(0.25, 0.1, 0) * CFrame.Angles(0, 0, flap) * CFrame.new(1.3, 0, 0))
	end
	if #parts > 0 then
		pcall(function()
			Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- The light of the moment
---------------------------------------------------------------------------------------------------
local function applyMood(id: string)
	local mood = MOODS[id] or MOODS.golden
	for _, t in torches do
		local lit = mood.torch > 0
		t.flame.Transparency = if lit then 0.1 else 1
		t.light.Enabled = lit
		t.light.Brightness = mood.torch
		local fire = t.fire
		if fire then
			fire.Enabled = lit
		end
	end
	for _, l in lanterns do
		l.Transparency = mood.lantern
	end
	for _, l in lampLights do
		l.Brightness = mood.lamp
		l.Enabled = mood.lamp > 0
	end
	for _, g in glows do
		g.Transparency = mood.room
	end
	for _, l in glowLights do
		l.Brightness = mood.glow
	end
	for _, l in poolLights do
		l.Brightness = mood.pool
		l.Enabled = mood.pool > 0
	end
	for _, g in glitters do
		g.emitter.Rate = rate(mood.glitter * g.share)
		g.emitter.Color = ColorSequence.new(mood.sparkle)
	end
	for _, f in flies do
		f.Rate = rate(mood.fireflies)
	end
	for _, g in gulls do
		for _, p in { g.body, g.left, g.right } do
			p.Transparency = if mood.gulls then 0 else 1
		end
	end
end

-- The island's light chosen (or changed): the island's life follows it.
function IslandLife.theme(id: string)
	if not active or moodId == id then
		return
	end
	moodId = id
	pcall(applyMood, id)
end

---------------------------------------------------------------------------------------------------
-- On the island, and off it
---------------------------------------------------------------------------------------------------
function IslandLife.enter(id: string)
	if active then
		IslandLife.theme(id)
		return
	end
	active = true
	moodId = nil
	for name, fn in WATCH do
		for _, i in CollectionService:GetTagged(name) do
			pcall(fn, i)
		end
		-- (Pieces streamed in later, while the guest is here.)
		table.insert(conns, CollectionService:GetInstanceAddedSignal(name):Connect(function(i: Instance)
			if active then
				pcall(fn, i)
				local m = moodId
				if m then
					pcall(applyMood, m)
				end
			end
		end))
	end
	pcall(water)
	pcall(fireflies)
	pcall(makeGulls)
	IslandLife.theme(id)
	local acc = 0
	table.insert(conns, RunService.Heartbeat:Connect(function(dt: number)
		if #gulls > 0 and moodId and (MOODS[moodId] or MOODS.golden).gulls then
			stepGulls(dt)
		end
		-- (The firelight flickers some fifteen times a second.)
		acc += dt
		if acc >= 1 / 15 then
			acc = 0
			local mood = MOODS[moodId or "golden"] or MOODS.golden
			local t = os.clock()
			for _, f in flickers do
				f.light.Brightness = mood.torch * (0.8 + 0.45 * (math.noise(t * 2.6, f.seed) + 0.5))
			end
		end
	end))
end

function IslandLife.leave()
	if not active then
		return
	end
	active = false
	moodId = nil
	for _, c in conns do
		c:Disconnect()
	end
	conns = {}
	for _, t in tweens do
		pcall(function()
			t:Cancel()
		end)
	end
	tweens = {}
	for _, r in restore do
		pcall(function()
			r.part.CFrame = r.cf
			r.part.Transparency = r.transparency
		end)
	end
	restore = {}
	for i = #made, 1, -1 do
		pcall(function()
			made[i]:Destroy()
		end)
	end
	made = {}
	touched = {}
	folder = nil
	torches, flickers, lanterns, lampLights, glows, glowLights, poolLights, glitters, flies, gulls = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
end

function IslandLife.active(): boolean
	return active
end

return IslandLife

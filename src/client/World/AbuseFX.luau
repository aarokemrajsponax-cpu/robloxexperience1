--!strict
-- Effects for everyone: the owner's taps in House controls, and the surprises all through Admin
-- Abuse Night. The server says which (only the owner can ask it); this screen plays it round its
-- own guest. Nothing here changes Gilt, a score or anything kept, and a guest sorting at a table is
-- never moved (they still see and hear it).
--   intro       ADMIN ABUSE slams onto the screen in gold, air horns, a flash
--   launch      every guest shoots into the sky on a trail of smoke
--   dance       every guest dances (Roblox's own dances) under pulsing disco light
--   storm       lightning forks down round the house, the sky flashes, thunder rolls in after
--   memeRain    the house's memes pour from the sky round every guest, air horns
--   confetti    cannons of confetti burst on every side, party horns
--   shockwave   a ring of gold blasts out from the owner and throws every guest near them back
--   spin        every guest spins like a top
--   meteor      blazing meteors streak down and slam into the ground round every guest
--   blackHole   a black hole opens overhead and pulls everyone up into its swirl, then lets go
--   aurora      ribbons of green and violet light ripple across the sky
--   galaxy      the sky turns to deep space: stars, nebulae and a ringed planet
--   ufo         a flying saucer hovers over each guest and beams them up a little way
--   blizzard    a whiteout: snow sweeping sideways, a white haze
--   earthquake  the ground rumbles, dust rises and the screen shakes
--   rainbow     every colour at once, a rainbow trail behind you
--   bubbles     bubbles floating up all round, popping
--   goldWave    a tidal wave of gold coins washes across the screen
--   fireIce     embers rising and snow falling, red on one side, blue on the other
--   blackout    the lights go out, spotlights sweep the dark, then everything blazes back
--   tornado     a whirlwind spins up beside each guest and carries them round
--   fireworks   fireworks over the whole house
--   titan       a colossal meme rises over the rooftops, looks round, and sinks
--   zeroG       everyone floats, then drifts gently back down
--   ownerArmy   a crowd of the owner (their own avatar) drops from the sky round every guest,
--               lands in a ring and dances round them
--   stop        whatever is still playing stops

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AbuseNights = require(ReplicatedStorage.Shared.AbuseNights)
local Config = require(ReplicatedStorage.Shared.Config)
local Curios = require(ReplicatedStorage.Shared.Curios)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fireworks = require(script.Parent.Fireworks)
local Flakes = require(script.Parent.Flakes)
local OwnerCameo = require(script.Parent.OwnerCameo)
local Sound = require(script.Parent.Parent.Sound)

local AbuseFX = {}

-- Set by Main: whether the guest is busy at a table (then nothing moves them).
AbuseFX.isBusy = function(): boolean
	return false
end

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local GOLD = rgb(255, 204, 110)
local RAINBOW = { rgb(255, 60, 140), rgb(80, 140, 255), rgb(90, 255, 170), rgb(255, 214, 80), rgb(190, 90, 255), rgb(255, 120, 40), rgb(60, 230, 255) }
local IMPACT = Font.fromEnum(Enum.Font.LuckiestGuy)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- Which of its looks each effect has as it starts (shared/AbuseNights' Variants: ice comets or
-- golden meteors, a crimson vortex or a white hole...): set by AbuseFX.play, the same in every
-- server (the server chose it).
local looksNow: { [string]: number } = {}
local function looks(id: string): AbuseNights.Variant
	return AbuseNights.variant(id, looksNow[id]) :: AbuseNights.Variant
end

-- Colours into a sequence (one colour: just it).
local function sequence(colours: { Color3 }): ColorSequence
	if #colours <= 1 then
		return ColorSequence.new(colours[1] or Color3.new(1, 1, 1))
	end
	local keys = {}
	for i, c in colours do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / (#colours - 1), c))
	end
	return ColorSequence.new(keys)
end

local token = 0 -- bumped by "stop": every effect still playing ends
-- Each effect's own life: switching one effect off ends only it (its channel is bumped).
local channel: { [string]: number } = {}
local starting = "" -- the effect being started just now (set by AbuseFX.play)
local repeating = false -- a switched-on effect coming round again (its banner was shown)
export type Life = { gen: number, id: string, chan: number }
local function life(): Life
	return { gen = token, id = starting, chan = channel[starting] or 0 }
end
local function alive(l: Life): boolean
	return token == l.gen and (channel[l.id] or 0) == l.chan
end

-- What an effect must put back if it's stopped part-way (the camera, gravity, a guest held up).
local undo: { [number]: () -> () } = {}
local undoNext = 0
local function onStop(fn: () -> ()): number
	undoNext += 1
	undo[undoNext] = fn
	return undoNext
end
local function finished(id: number)
	local fn = undo[id]
	undo[id] = nil
	if fn then
		pcall(fn)
	end
end

local function cfg(): { [string]: any }
	return Config.data.Admin :: any
end

local function stage(): Folder
	local parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local f = parent:FindFirstChild("AbuseFX")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "AbuseFX"
	nf.Parent = parent
	return nf
end

local function rootOf(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Whether this guest may be moved: not at a table, not seated anywhere.
local function free(): boolean
	if AbuseFX.isBusy() then
		return false
	end
	local h = humanoidOf()
	local seat = if h then h.SeatPart else nil
	return h ~= nil and seat == nil
end

local function screen(): ScreenGui
	local gui = player:FindFirstChild("PlayerGui")
	local existing = gui and gui:FindFirstChild("AbuseFX")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "AbuseFX"
	s.IgnoreGuiInset = true
	s.ResetOnSpawn = false
	s.DisplayOrder = 34
	s.Parent = gui
	return s
end

-- Big words slammed onto the screen, then gone: lit from above (white into the effect's colour), a
-- dark shadow under them, a gleam of light sweeping across, a tilt as they land; they lift away.
local function banner(text: string, colour: Color3, seconds: number)
	if repeating then
		return
	end
	local gui = screen()
	local old = gui:FindFirstChild("Banner")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.Name = "Banner"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.Size = UDim2.fromScale(0.9, 0.16)
	holder.Parent = gui
	local shadow = Instance.new("TextLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 5, 0.5, 7)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.FontFace = IMPACT
	shadow.TextScaled = true
	shadow.Text = text
	shadow.TextColor3 = Color3.new(0, 0, 0)
	shadow.TextTransparency = 0.45
	shadow.Parent = holder
	local label = Instance.new("TextLabel")
	label.Name = "Words"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = IMPACT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeColor3 = rgb(30, 16, 4)
	label.TextStrokeTransparency = 0
	label.Parent = holder
	local lit = Instance.new("UIGradient")
	lit.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1):Lerp(colour, 0.25)), ColorSequenceKeypoint.new(0.55, colour), ColorSequenceKeypoint.new(1, colour:Lerp(Color3.new(0, 0, 0), 0.25)) })
	lit.Rotation = 90
	lit.Parent = label
	-- The gleam: a bright band crossing the words once.
	local gleam = label:Clone()
	gleam.Name = "Gleam"
	gleam.TextStrokeTransparency = 1
	gleam.ZIndex = 2
	for _, c in gleam:GetChildren() do
		c:Destroy()
	end
	gleam.Parent = holder
	local band = Instance.new("UIGradient")
	band.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) })
	band.Offset = Vector2.new(-1, 0)
	band.Rotation = 20
	band.Parent = gleam
	local scale = Instance.new("UIScale")
	scale.Scale = 2.6
	scale.Parent = holder
	holder.Rotation = -6
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	task.delay(0.3, function()
		TweenService:Create(band, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Offset = Vector2.new(1, 0) }):Play()
	end)
	task.delay(seconds, function()
		if not holder.Parent then
			return
		end
		TweenService:Create(holder, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 0.22) }):Play()
		for _, l in { label, shadow, gleam } do
			TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		task.delay(0.6, function()
			holder:Destroy()
		end)
	end)
end

-- A flash of the whole picture (tinted), easing back.
local function flash(colour: Color3, brightness: number, seconds: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AbuseFlash"
	cc.TintColor = colour
	cc.Brightness = brightness
	cc.Parent = Lighting
	local t = TweenService:Create(cc, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, TintColor = Color3.new(1, 1, 1) })
	t:Play()
	task.delay(seconds + 0.1, function()
		cc:Destroy()
	end)
end

local function sound(name: string, volume: number?, pitch: number?)
	pcall(Sound.play, name, volume or 1, pitch)
end

local function anchor(name: string, at: Vector3, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at)
	p.Position = at
	p.Parent = stage()
	return p
end

local function throw(velocity: Vector3)
	local root = rootOf()
	local h = humanoidOf()
	if not root or not h then
		return
	end
	pcall(function()
		h:ChangeState(Enum.HumanoidStateType.Freefall)
	end)
	pcall(function()
		root.AssemblyLinearVelocity = velocity
	end)
end

---------------------------------------------------------------------------------------------------
-- The effects
---------------------------------------------------------------------------------------------------

local function intro(seconds: number)
	banner("ADMIN ABUSE", GOLD, seconds - 1)
	flash(rgb(255, 230, 170), 0.45, 1.4)
	for i = 0, 2 do
		task.delay(i * 0.45, function()
			sound("airHorn", 1, 1 + i * 0.06)
		end)
	end
	sound("fireworkBoom", 0.8)
end

local function launch(seconds: number)
	local V = looks("launch")
	banner(V.banner, V.colour, 2)
	sound("fireworkLaunch", 1.2, 0.8)
	if not free() then
		return
	end
	local root = rootOf()
	if not root then
		return
	end
	local trail = Instance.new("Attachment")
	trail.Name = "LaunchTrail"
	trail.Parent = root
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Rate = 60
	smoke.Lifetime = NumberRange.new(1, 1.8)
	smoke.Speed = NumberRange.new(2, 5)
	smoke.SpreadAngle = Vector2.new(25, 25)
	smoke.Size = NumberSequence.new(1.2, 4)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Color = ColorSequence.new(V.colours[1], rgb(120, 110, 100))
	smoke.Parent = trail
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Rate = 40
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Color = sequence(V.colours)
	sparks.Parent = trail
	local rng = Random.new()
	throw(Vector3.new(rng:NextNumber(-12, 12), cfg().launchSpeed, rng:NextNumber(-12, 12)))
	task.delay(math.min(seconds, 3), function()
		smoke.Enabled = false
		sparks.Enabled = false
		task.delay(2, function()
			trail:Destroy()
		end)
	end)
end

local DANCES = { "dance", "dance2", "dance3" }

local function dance(seconds: number, words: string?, colour: Color3?)
	local V = looks("dance")
	banner(words or V.banner, colour or V.colour, 2.5)
	sound("partyHorn", 1)
	local my = life()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DanceLight"
	cc.Parent = Lighting
	task.spawn(function()
		local started = os.clock()
		local beat = 0
		while alive(my) and os.clock() - started < seconds do
			beat += 1
			cc.TintColor = Color3.new(1, 1, 1):Lerp(V.colours[beat % #V.colours + 1], 0.16)
			if beat % 12 == 1 and free() then
				local h = humanoidOf()
				if h then
					task.spawn(function()
						pcall(function()
							(h :: any):PlayEmote(DANCES[math.random(1, #DANCES)])
						end)
					end)
				end
			end
			task.wait(0.5)
		end
		cc:Destroy()
	end)
end

-- One fork of lightning from the sky to the ground, near the guest.
local function bolt(at: Vector3, colour: Color3)
	local rng = Random.new()
	local top = at + Vector3.new(0, 140, 0)
	local folder = Instance.new("Folder")
	folder.Name = "Bolt"
	folder.Parent = stage()
	local from = top
	for i = 1, 9 do
		local to = top:Lerp(at, i / 9) + Vector3.new(rng:NextNumber(-7, 7), 0, rng:NextNumber(-7, 7))
		if i == 9 then
			to = at
		end
		local length = (to - from).Magnitude
		local seg = Instance.new("Part")
		seg.Name = "Fork"
		seg.Anchored = true
		seg.CanCollide = false
		seg.CanQuery = false
		seg.CanTouch = false
		seg.CastShadow = false
		seg.Material = Enum.Material.Neon
		seg.Color = colour
		seg.Size = Vector3.new(0.6, 0.6, length)
		seg.CFrame = CFrame.lookAt((from + to) / 2, to)
		seg.Position = (from + to) / 2
		seg.Parent = folder
		from = to
	end
	local glow = Instance.new("PointLight")
	glow.Range = 60
	glow.Brightness = 6
	glow.Color = colour
	glow.Parent = folder:FindFirstChild("Fork")
	task.delay(0.18, function()
		folder:Destroy()
	end)
end

local function storm(seconds: number)
	local V = looks("storm")
	banner(V.banner, V.colour, 2.5)
	local my = life()
	task.spawn(function()
		local started = os.clock()
		local rng = Random.new()
		while alive(my) and os.clock() - started < seconds do
			local root = rootOf()
			if root then
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(40, 130)
				bolt(Vector3.new(root.Position.X + math.cos(a) * r, root.Position.Y - 3, root.Position.Z + math.sin(a) * r), V.colours[1])
				flash(V.colours[1], 0.35, 0.5)
				task.delay(rng:NextNumber(0.3, 1.1), function()
					sound(if rng:NextNumber() < 0.5 then "fireworkRumble" else "fireworkBoom", 0.9, rng:NextNumber(0.6, 0.8))
				end)
			end
			task.wait(rng:NextNumber(1.2, 3))
		end
	end)
end

local function memeRain(seconds: number)
	local V = looks("memeRain")
	banner(V.banner, V.colour, 2.5)
	sound("airHorn", 1)
	task.delay(0.6, function()
		sound("airHorn", 1, 1.1)
	end)
	local glyphs = {}
	if type(V.glyphs) == "table" then
		glyphs = V.glyphs
	else
		for _, c in Curios.List do
			if c.family == "meme" then
				table.insert(glyphs, c.glyph)
			end
		end
	end
	if #glyphs == 0 then
		glyphs = { "🤡", "🗿", "💀" }
	end
	local my = life()
	task.spawn(function()
		local started = os.clock()
		local rng = Random.new()
		local falling: { { part: Part, speed: number, spin: number, label: TextLabel } } = {}
		local conn = RunService.Heartbeat:Connect(function(dt: number)
			for i = #falling, 1, -1 do
				local f = falling[i]
				local p = f.part
				if p.Parent == nil then
					-- (Stopped: the stage has gone.)
					table.remove(falling, i)
					continue
				end
				local at = p.Position - Vector3.new(0, f.speed * dt, 0)
				p.Position = at
				p.CFrame = CFrame.new(at)
				f.label.Rotation += f.spin * dt
				local root = rootOf()
				if not root or at.Y < root.Position.Y - 6 then
					p:Destroy()
					table.remove(falling, i)
				end
			end
		end)
		while alive(my) and os.clock() - started < seconds do
			local root = rootOf()
			if root then
				for _ = 1, 3 do
					local a = rng:NextNumber(0, math.pi * 2)
					local r = rng:NextNumber(3, 40)
					local p = anchor("Meme", root.Position + Vector3.new(math.cos(a) * r, rng:NextNumber(30, 45), math.sin(a) * r))
					local size = rng:NextNumber(2.5, 5)
					local bb = Instance.new("BillboardGui")
					bb.Size = UDim2.fromScale(size, size)
					bb.LightInfluence = 0
					bb.MaxDistance = 200
					bb.Parent = p
					local label = Instance.new("TextLabel")
					label.BackgroundTransparency = 1
					label.Size = UDim2.fromScale(1, 1)
					label.TextScaled = true
					label.Text = glyphs[rng:NextInteger(1, #glyphs)]
					label.Parent = bb
					table.insert(falling, { part = p, speed = rng:NextNumber(12, 22), spin = rng:NextNumber(-180, 180), label = label })
				end
			end
			task.wait(0.25)
		end
		local waited = 0
		while #falling > 0 and waited < 4 do
			task.wait(0.25)
			waited += 0.25
		end
		conn:Disconnect()
		for _, f in falling do
			f.part:Destroy()
		end
	end)
end

local function confetti(seconds: number)
	local V = looks("confetti")
	banner(V.banner, V.colour, 2)
	sound("partyHorn", 1)
	task.delay(0.3, function()
		sound("partyHorn", 1, 1.15)
	end)
	local my = life()
	local stops = {}
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local offset = Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		table.insert(stops, Flakes.fall({
			seconds = seconds,
			centre = function(): Vector3?
				local root = rootOf()
				return if root then root.Position + offset else nil
			end,
			colours = V.colours,
			material = Enum.Material.SmoothPlastic,
			reflectance = 0.1,
			size = Vector3.new(0.34, 0.02, 0.18),
			count = 50,
			radius = 14,
			height = 16,
			fall = 3,
			flutter = 3,
			burst = true,
		}))
	end
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < seconds do
			if not alive(my) then
				for _, stop in stops do
					stop()
				end
				return
			end
			task.wait(0.25)
		end
	end)
end

local function shockwave(seconds: number, origin: Vector3?)
	local V = looks("shockwave")
	local root = rootOf()
	local centre = origin or (if root then root.Position else nil)
	if not centre then
		return
	end
	sound("fireworkBoom", 1.2, 0.7)
	flash(rgb(255, 236, 190), 0.5, 0.8)
	local ring = anchor("Shockwave", centre, Vector3.new(0.4, 2, 2))
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = V.colours[1]
	ring.Transparency = 0.2
	ring.CFrame = CFrame.new(centre) * CFrame.Angles(0, 0, math.rad(90))
	local reach = cfg().shockwaveRadius
	local t = TweenService:Create(ring, TweenInfo.new(math.min(1.2, seconds), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, reach * 2, reach * 2), Transparency = 1 })
	t:Play()
	task.delay(seconds, function()
		ring:Destroy()
	end)
	if root and free() then
		local away = Vector3.new(root.Position.X - centre.X, 0, root.Position.Z - centre.Z)
		local d = away.Magnitude
		if d <= reach then
			local dir = if d > 0.5 then away.Unit else Vector3.new(1, 0, 0)
			local strength = 1 - d / reach * 0.6
			throw(dir * 110 * strength + Vector3.new(0, 70 * strength, 0))
		end
	end
end

local function spin(seconds: number)
	local V = looks("spin")
	banner(V.banner, V.colour, 1.5)
	local speed: number = if type(V.speed) == "number" then V.speed else 14
	if not free() then
		return
	end
	local h = humanoidOf()
	local root = rootOf()
	if not h or not root then
		return
	end
	local my = life()
	local was = h.AutoRotate
	h.AutoRotate = false
	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		if not alive(my) or os.clock() - started > seconds or not root.Parent then
			if conn then
				conn:Disconnect()
			end
			h.AutoRotate = was
			return
		end
		root.CFrame = root.CFrame * CFrame.Angles(0, speed * dt, 0)
	end)
end


---------------------------------------------------------------------------------------------------
-- More effects
---------------------------------------------------------------------------------------------------
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARKS = "rbxasset://textures/particles/fire_sparks_main.dds"
local RING = "rbxasset://textures/particles/forcefield_vortex_main.dds"

local function part(name: string, size: Vector3, colour: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = colour
	p.Material = material or Enum.Material.Neon
	p.Transparency = transparency or 0
	p.Parent = stage()
	return p
end

local function emitter(parent: Instance, texture: string, colour: ColorSequence, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = colour
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

-- The camera shakes for a while (strength in studs, easing off).
local function shake(seconds: number, strength: number, given: Life?)
	local name = "MaisonShake" .. tostring(math.random(1, 1e6))
	local started = os.clock()
	local my = given or life()
	local ok = pcall(function()
		RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
			local t = os.clock() - started
			if t > seconds or not alive(my) then
				RunService:UnbindFromRenderStep(name)
				return
			end
			local camera = Workspace.CurrentCamera
			if camera then
				local k = strength * (1 - t / seconds)
				camera.CFrame = camera.CFrame * CFrame.new(math.noise(t * 25, 1) * k, math.noise(t * 25, 2) * k, 0) * CFrame.Angles(0, 0, math.noise(t * 20, 3) * k * 0.02)
			end
		end)
	end)
	if not ok then
		return
	end
	local id = onStop(function()
		pcall(function()
			RunService:UnbindFromRenderStep(name)
		end)
	end)
	task.delay(seconds + 0.2, function()
		undo[id] = nil
	end)
end

-- Holds the guest up in the air (a black hole, a UFO, a tornado): while `hold` gives a point, they
-- drift towards it; then they're let go to fall softly. Returns at once.
local function carry(seconds: number, hold: (t: number) -> Vector3?, given: Life?)
	if not free() then
		return
	end
	local root, h = rootOf(), humanoidOf()
	if not root or not h then
		return
	end
	local my = given or life()
	local started = os.clock()
	pcall(function()
		h.PlatformStand = true
	end)
	local conn: RBXScriptConnection? = nil
	local function release()
		if conn then
			conn:Disconnect()
			conn = nil
		end
		pcall(function()
			h.PlatformStand = false
			h:ChangeState(Enum.HumanoidStateType.Freefall)
			root.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
			root.AssemblyAngularVelocity = Vector3.zero
		end)
	end
	local id = onStop(release)
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		local target = hold(t)
		if t > seconds or not alive(my) or not target or not root.Parent then
			finished(id)
			return
		end
		local to = target - root.Position
		local v = to * 2.5
		if v.Magnitude > 60 then
			v = v.Unit * 60
		end
		root.AssemblyLinearVelocity = v
		root.AssemblyAngularVelocity = Vector3.new(0, 4, 0)
	end)
end

-- Where the floor is under a point (the house's floors, the street), ignoring the effects.
local function groundUnder(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { stage() }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position else at
end

-- Chunks of rock thrown up from an impact, arcing out and falling (drawn, never solid).
local function debris(at: Vector3, count: number, power: number, hot: boolean)
	local rng = Random.new()
	local bits: { { p: Part, v: Vector3, spin: Vector3, age: number } } = {}
	for _ = 1, count do
		local size = rng:NextNumber(0.6, 1.8) * (power / 40)
		local p = part("Debris", Vector3.new(size, size * rng:NextNumber(0.5, 1), size), if hot and rng:NextNumber() < 0.4 then rgb(255, 120, 40) else rgb(70, 60, 55), if hot then Enum.Material.Neon else Enum.Material.Slate)
		p.Position = at + Vector3.new(0, 1, 0)
		local a = rng:NextNumber(0, math.pi * 2)
		table.insert(bits, { p = p, v = Vector3.new(math.cos(a) * rng:NextNumber(0.3, 1) * power, rng:NextNumber(0.6, 1.2) * power, math.sin(a) * rng:NextNumber(0.3, 1) * power), spin = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8)), age = 0 })
	end
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function(dt: number)
		local left = 0
		for _, b in bits do
			if b.p.Parent then
				b.age += dt
				b.v += Vector3.new(0, -Workspace.Gravity * 0.6 * dt, 0)
				b.p.CFrame = (b.p.CFrame + b.v * dt) * CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
				b.p.Transparency = math.clamp((b.age - 1) / 0.6, 0, 1)
				if b.age > 1.6 then
					b.p:Destroy()
				else
					left += 1
				end
			end
		end
		if left == 0 and conn then
			conn:Disconnect()
		end
	end)
end

-- One meteor: from high in the sky, at a slant, streaking fire, into the ground near the guest:
-- a flash, a ring of fire racing out, rock thrown up, a cloud of dust. A big one (every few):
-- three times the size, slower, and a sonic boom when it lands.
local function oneMeteor(centre: Vector3, rng: Random, big: boolean?, V: AbuseNights.Variant)
	local hot, mid, deep = V.colours[1], V.colours[2] or V.colours[1], V.colours[3] or V.colours[1]
	if V.rainbow then
		mid = AbuseNights.RAINBOW[rng:NextInteger(1, #AbuseNights.RAINBOW)]
		deep = mid:Lerp(Color3.new(0, 0, 0), 0.4)
	end
	local a = rng:NextNumber(0, math.pi * 2)
	local r = if big then rng:NextNumber(30, 60) else rng:NextNumber(14, 80)
	local hit = groundUnder(Vector3.new(centre.X + math.cos(a) * r, centre.Y, centre.Z + math.sin(a) * r))
	local from = hit + Vector3.new(rng:NextNumber(-90, 90), if big then 280 else 190, rng:NextNumber(-90, 90))
	local size = if big then 20 else rng:NextNumber(5, 8.5)
	local rock = part("Meteor", Vector3.one * size, mid)
	rock.Shape = Enum.PartType.Ball
	rock.Position = from
	local core = Instance.new("Attachment")
	core.Parent = rock
	-- The streak behind it, white-hot to deep red.
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, size * 0.42, 0)
	top.Parent = rock
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -size * 0.42, 0)
	bottom.Parent = rock
	local streak = Instance.new("Trail")
	streak.Attachment0 = top
	streak.Attachment1 = bottom
	streak.FaceCamera = true
	streak.Lifetime = if big then 1 else 0.55
	streak.LightEmission = 1
	streak.LightInfluence = 0
	streak.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, hot), ColorSequenceKeypoint.new(0.25, mid), ColorSequenceKeypoint.new(1, deep) })
	streak.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	streak.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.15) })
	streak.Parent = rock
	emitter(core, FIRE, ColorSequence.new(hot, mid), { Rate = if big then 220 else 120, Lifetime = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(1, 4), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.9), NumberSequenceKeypoint.new(1, size * 0.15) }), LightEmission = 1, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }) })
	emitter(core, SMOKE, ColorSequence.new(rgb(90, 70, 60)), { Rate = 45, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.5, 1.5), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, size * 1.6) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }) })
	local glow = Instance.new("PointLight")
	glow.Color = mid
	glow.Range = 60
	glow.Brightness = if big then 8 else 4
	glow.Parent = rock
	sound("fireworkWhistle", if big then 1.2 else 0.8, if big then 0.5 else rng:NextNumber(0.7, 0.9))
	local fall = if big then 2.6 else rng:NextNumber(1, 1.5)
	local t = TweenService:Create(rock, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = hit })
	t:Play()
	t.Completed:Once(function()
		if not rock.Parent then
			return
		end
		rock.Transparency = 1
		streak.Enabled = false
		for _, e in core:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		glow.Brightness = if big then 14 else 7
		glow.Range = if big then 60 else 40
		TweenService:Create(glow, TweenInfo.new(0.9), { Brightness = 0 }):Play()
		-- The impact: a ring of fire racing out, sparks, rock, dust, a boom; the screen shakes if near.
		local reach = if big then 110 else 46
		local ring = part("Impact", Vector3.new(0.6, 4, 4), mid, Enum.Material.Neon, 0.05)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(hit + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		TweenService:Create(ring, TweenInfo.new(if big then 1.1 else 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.6, reach, reach), Transparency = 1 }):Play()
		local scorch = part("Scorch", Vector3.new(0.2, size * 2.4, size * 2.4), rgb(30, 22, 18), Enum.Material.SmoothPlastic, 0.15)
		scorch.Shape = Enum.PartType.Cylinder
		scorch.CFrame = CFrame.new(hit + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
		TweenService:Create(scorch, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
		local burst = Instance.new("Attachment")
		burst.WorldPosition = hit + Vector3.new(0, 1, 0)
		burst.Parent = Workspace.Terrain
		local sp = emitter(burst, SPARKS, ColorSequence.new(hot, mid), { Rate = 0, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(if big then 40 else 20, if big then 90 else 45), SpreadAngle = Vector2.new(70, 70), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if big then 2.4 else 1.2), NumberSequenceKeypoint.new(1, 0) }), LightEmission = 1, Acceleration = Vector3.new(0, -40, 0) })
		local dust = emitter(burst, SMOKE, ColorSequence.new(rgb(150, 130, 110)), { Rate = 0, Lifetime = NumberRange.new(1.6, 2.8), Speed = NumberRange.new(4, if big then 28 else 14), SpreadAngle = Vector2.new(80, 80), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.8), NumberSequenceKeypoint.new(1, size * 3) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }), Acceleration = Vector3.new(0, 3, 0) })
		pcall(function()
			sp:Emit(if big then 160 else 60)
			dust:Emit(if big then 40 else 14)
		end)
		debris(hit, if big then 22 else 8, if big then 70 else 40, true)
		sound("fireworkBoom", 1, rng:NextNumber(0.55, 0.75))
		if big then
			sound("sonicBoom", 1)
			sound("showDrop", 0.7)
		end
		local me = rootOf()
		if me then
			local d = (me.Position - hit).Magnitude
			local near = if big then 140 else 45
			if d < near then
				shake(if big then 1.4 else 0.6, (if big then 3 else 1.4) * (1 - d / near))
			end
			if big and d < 160 then
				flash(rgb(255, 210, 160), 0.5 * (1 - d / 160), 0.7)
			end
			local throwAt = if big then 30 else 14
			if d < throwAt and free() then
				local away = Vector3.new(me.Position.X - hit.X, 0, me.Position.Z - hit.Z)
				throw((if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)) * 50 + Vector3.new(0, 45, 0))
			end
		end
		task.delay(3, function()
			rock:Destroy()
			ring:Destroy()
			burst:Destroy()
		end)
		task.delay(4.2, function()
			scorch:Destroy()
		end)
	end)
end

local function meteor(seconds: number)
	local V = looks("meteor")
	banner(V.banner, V.colour, 2.5)
	flash(V.colour, 0.25, 1)
	local my = life()
	-- The sky glows the colour of fire while it lasts.
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "MeteorSky"
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(1.5), { TintColor = if typeof(V.sky) == "Color3" then V.sky else rgb(255, 222, 200), Contrast = 0.08 }):Play()
	task.spawn(function()
		local rng = Random.new()
		local started = os.clock()
		local count = 0
		while alive(my) and os.clock() - started < seconds do
			local root = rootOf()
			if root then
				count += 1
				-- (Every seventh, a giant.)
				oneMeteor(root.Position, rng, count % 7 == 0, V)
				if rng:NextNumber() < 0.35 then
					oneMeteor(root.Position, rng, false, V)
				end
			end
			task.wait(rng:NextNumber(0.45, 1.1))
		end
		TweenService:Create(cc, TweenInfo.new(1.5), { TintColor = Color3.new(1, 1, 1), Contrast = 0 }):Play()
		task.delay(1.6, function()
			cc:Destroy()
		end)
	end)
end

-- The black hole: a disc of fire round a hole of nothing, a ring of light at its edge (the light
-- bent round it), everything near pulled in spirals and stretched thin; at the end it bursts in a
-- supernova of white light.
local function blackHole(seconds: number)
	local V = looks("blackHole")
	local c1, c2, c3 = V.colours[1], V.colours[2] or V.colours[1], V.colours[3] or V.colours[1]
	banner(V.banner, V.colour, 2.5)
	local root = rootOf()
	if not root then
		return
	end
	local my = life()
	local centre = root.Position + Vector3.new(0, 52, 0)
	local hole = part("BlackHole", Vector3.new(2, 2, 2), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	hole.Shape = Enum.PartType.Ball
	hole.Position = centre
	local disks: { { p: Part, size: number, spin: number, tilt: number } } = {}
	for i, spec in { { size = 70, colour = c1, alpha = 0.2, spin = 2.2, tilt = 12 }, { size = 96, colour = c2, alpha = 0.55, spin = 1.5, tilt = 10 }, { size = 128, colour = c3, alpha = 0.7, spin = -1, tilt = 14 } } do
		local d = part("Disk" .. i, Vector3.new(0.5, 2, 2), spec.colour, Enum.Material.Neon, spec.alpha)
		d.Shape = Enum.PartType.Cylinder
		table.insert(disks, { p = d, size = spec.size, spin = spec.spin, tilt = spec.tilt })
	end
	-- The ring of light round its edge, always facing the guest.
	local photon = part("PhotonRing", Vector3.new(0.3, 2, 2), c2:Lerp(Color3.new(1, 1, 1), 0.7), Enum.Material.Neon, 0.1)
	photon.Shape = Enum.PartType.Cylinder
	local swirl = Instance.new("Attachment")
	swirl.Parent = hole
	emitter(swirl, RING, ColorSequence.new(c3, c1), { Rate = 12, Lifetime = NumberRange.new(1.5, 2), Speed = NumberRange.new(0, 0), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 60), NumberSequenceKeypoint.new(1, 10) }), LightEmission = 1, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }), RotSpeed = NumberRange.new(120, 200), Rotation = NumberRange.new(0, 360) })
	emitter(swirl, SPARK, ColorSequence.new(c3:Lerp(Color3.new(1, 1, 1), 0.4)), { Rate = 90, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(-40, -24), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), LightEmission = 1 })
	-- Bits of the night pulled in: stretched thin as they spiral down into it.
	local rng = Random.new()
	local pulled: { { p: Part, a: number, r: number, h: number, speed: number } } = {}
	for _ = 1, 26 do
		local p = part("Pulled", Vector3.new(0.6, 0.6, 1.6), if rng:NextNumber() < 0.5 then c2 else c3, Enum.Material.Neon, 0.1)
		table.insert(pulled, { p = p, a = rng:NextNumber(0, math.pi * 2), r = rng:NextNumber(30, 90), h = rng:NextNumber(-20, 20), speed = rng:NextNumber(0.8, 1.6) })
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BlackHoleDark"
	cc.Brightness = -0.18
	cc.Contrast = 0.15
	cc.TintColor = Color3.new(1, 1, 1):Lerp(c3, 0.25)
	cc.Parent = Lighting
	sound("fireworkRumble", 1, 0.5)
	sound("warpBuild", 0.8, 0.7)
	local grow = 0.9
	TweenService:Create(hole, TweenInfo.new(grow, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(20, 20, 20) }):Play()
	local started = os.clock()
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock() - started
		local s = math.min(1, t / grow)
		for i, d in disks do
			d.p.Size = Vector3.new(0.5, d.size * s, d.size * s)
			d.p.CFrame = CFrame.new(centre) * CFrame.Angles(math.rad(d.tilt), t * d.spin + i, 0) * CFrame.Angles(0, 0, math.rad(90))
		end
		local camera = Workspace.CurrentCamera
		if camera then
			photon.Size = Vector3.new(0.3, 24 * s, 24 * s)
			photon.CFrame = CFrame.lookAt(centre, camera.CFrame.Position) * CFrame.Angles(0, math.rad(90), 0)
			photon.Transparency = 0.05 + 0.2 * math.abs(math.sin(t * 5))
		end
		for _, b in pulled do
			b.a += dt * b.speed * (1 + 40 / math.max(4, b.r))
			b.r -= dt * (6 + 120 / math.max(4, b.r))
			b.h *= 1 - dt * 0.8
			if b.r < 6 then
				b.r = rng:NextNumber(60, 95)
				b.h = rng:NextNumber(-20, 20)
			end
			local at = centre + Vector3.new(math.cos(b.a) * b.r, b.h, math.sin(b.a) * b.r)
			local ahead = centre + Vector3.new(math.cos(b.a + 0.1) * b.r, b.h, math.sin(b.a + 0.1) * b.r)
			-- (Stretched along its path the nearer it gets.)
			b.p.Size = Vector3.new(0.6, 0.6, math.clamp(80 / b.r, 1.5, 9))
			b.p.CFrame = CFrame.lookAt(at, ahead)
		end
	end)
	carry(math.max(1, seconds - 2.5), function(t: number): Vector3?
		local a = t * 2.4
		local r = math.max(6, 18 - t * 2)
		return centre + Vector3.new(math.cos(a) * r, -16 + math.min(8, t * 2), math.sin(a) * r)
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.2)
		end
		conn:Disconnect()
		cc:Destroy()
		for _, x in { hole, photon } do
			x:Destroy()
		end
		for _, d in disks do
			d.p:Destroy()
		end
		for _, b in pulled do
			b.p:Destroy()
		end
		if not alive(my) then
			return
		end
		-- The supernova: a sphere of white light bursting out from where it was.
		local nova = part("Supernova", Vector3.new(4, 4, 4), rgb(255, 250, 235), Enum.Material.Neon, 0)
		nova.Shape = Enum.PartType.Ball
		nova.Position = centre
		TweenService:Create(nova, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(220, 220, 220), Transparency = 1 }):Play()
		task.delay(1.3, function()
			nova:Destroy()
		end)
		flash(rgb(240, 225, 255), 0.6, 1)
		sound("sonicBoom", 1)
		sound("fireworkBoom", 1, 0.5)
		shake(0.9, 1.6)
	end)
end

local function aurora(seconds: number)
	local V = looks("aurora")
	banner(V.banner, V.colour, 2)
	sound("shimmerFall", 0.8)
	local root = rootOf()
	if not root then
		return
	end
	local my = life()
	local centre = root.Position
	local curtains: { { a0: Attachment, a1: Attachment, base: Vector3, a1base: Vector3, phase: number } } = {}
	local holderPart = part("Aurora", Vector3.new(1, 1, 1), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	holderPart.Position = centre
	local colours = {}
	for i, c in V.colours do
		table.insert(colours, ColorSequence.new(c, V.colours[i % #V.colours + 1]))
	end
	for i = 1, 9 do
		local a = (i / 9) * math.pi * 1.6 - 0.8
		local base = centre + Vector3.new(math.cos(a) * 140, 110 + (i % 3) * 14, math.sin(a) * 140)
		local a0 = Instance.new("Attachment")
		a0.WorldPosition = base
		a0.Parent = holderPart
		local a1 = Instance.new("Attachment")
		a1.WorldPosition = base + Vector3.new(math.sin(a) * 60, 0, -math.cos(a) * 60)
		a1.Parent = holderPart
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 34
		beam.Width1 = 34
		beam.FaceCamera = false
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = colours[(i % #colours) + 1]
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) })
		beam.CurveSize0 = 20
		beam.CurveSize1 = -20
		beam.Segments = 20
		beam.Parent = holderPart
		table.insert(curtains, { a0 = a0, a1 = a1, base = base, a1base = a1.WorldPosition, phase = i })
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AuroraNight"
	cc.Brightness = -0.06
	cc.TintColor = rgb(210, 240, 255)
	cc.Parent = Lighting
	local started = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		-- (It keeps over the guest as they walk: switched on, it may be up a long while.)
		local r = rootOf()
		local shift = if r then r.Position - centre else Vector3.zero
		for _, c in curtains do
			local wave = Vector3.new(math.sin(t * 0.5 + c.phase) * 8, math.sin(t * 0.8 + c.phase * 2) * 6, math.cos(t * 0.4 + c.phase) * 8)
			c.a0.WorldPosition = c.base + shift + wave
			c.a1.WorldPosition = c.base + shift + (c.a1base - c.base)
		end
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.25)
		end
		conn:Disconnect()
		cc:Destroy()
		holderPart:Destroy()
	end)
end

local function galaxy(seconds: number)
	local V = looks("galaxy")
	banner(V.banner, V.colour, 2.5)
	sound("shimmerFall", 0.9, 0.8)
	local root = rootOf()
	if not root then
		return
	end
	local my = life()
	local centre = root.Position
	local rng = Random.new()
	local folder = Instance.new("Folder")
	folder.Name = "Galaxy"
	folder.Parent = stage()
	local stars: { Part } = {}
	for _ = 1, 260 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.12, 1), rng:NextNumber(-1, 1)).Unit
		local s = part("Star", Vector3.new(1, 1, 1) * rng:NextNumber(0.8, 2.2), Color3.new(1, 1, 1):Lerp(rgb(170, 200, 255), rng:NextNumber()))
		s.Shape = Enum.PartType.Ball
		s.Position = centre + dir * rng:NextNumber(380, 520)
		s.Parent = folder
		table.insert(stars, s)
	end
	for _ = 1, 7 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.25, 0.9), rng:NextNumber(-1, 1)).Unit
		local n = part("Nebula", Vector3.new(1, 1, 1) * rng:NextNumber(110, 200), if rng:NextNumber() < 0.5 then V.colours[1] else V.colours[2] or V.colours[1], Enum.Material.Neon, 0.86)
		n.Shape = Enum.PartType.Ball
		n.Position = centre + dir * 560
		n.Parent = folder
	end
	local planetAt = centre + Vector3.new(-260, 190, -320)
	local planet = part("Planet", Vector3.new(110, 110, 110), if typeof(V.planet) == "Color3" then V.planet else rgb(220, 150, 90), Enum.Material.SmoothPlastic)
	planet.Shape = Enum.PartType.Ball
	planet.Position = planetAt
	planet.Parent = folder
	local ringP = part("PlanetRing", Vector3.new(1, 230, 230), rgb(240, 210, 150), Enum.Material.Neon, 0.45)
	ringP.Shape = Enum.PartType.Cylinder
	ringP.CFrame = CFrame.new(planetAt) * CFrame.Angles(math.rad(70), 0, math.rad(20))
	ringP.Parent = folder
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "GalaxyNight"
	cc.Brightness = -0.18
	cc.TintColor = rgb(170, 170, 255)
	cc.Saturation = 0.2
	cc.Parent = Lighting
	local started = os.clock()
	task.spawn(function()
		local at = centre
		while alive(my) and os.clock() - started < seconds do
			for _ = 1, 10 do
				local s = stars[rng:NextInteger(1, #stars)]
				s.Transparency = rng:NextNumber(0, 0.7)
			end
			-- (The sky goes with the guest: switched on, they may walk the whole house under it.)
			local r = rootOf()
			if r and (r.Position - at).Magnitude > 60 then
				local shift = r.Position - at
				at = r.Position
				for _, p in folder:GetChildren() do
					if p:IsA("BasePart") then
						p.CFrame = p.CFrame + shift
					end
				end
			end
			task.wait(0.15)
		end
		cc:Destroy()
		folder:Destroy()
	end)
end

local function ufo(seconds: number)
	local V = looks("ufo")
	local tone = V.colours[1]
	banner(V.banner, V.colour, 2.5)
	local root = rootOf()
	if not root then
		return
	end
	local my = life()
	local hover = root.Position + Vector3.new(0, 34, 0)
	local saucer = part("Saucer", Vector3.new(4, 26, 26), rgb(170, 180, 190), Enum.Material.Metal)
	saucer.Shape = Enum.PartType.Cylinder
	saucer.Reflectance = 0.3
	local dome = part("Dome", Vector3.new(11, 11, 11), tone:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Glass, 0.35)
	dome.Shape = Enum.PartType.Ball
	local lights: { Part } = {}
	for i = 1, 10 do
		local l = part("Light", Vector3.new(1.6, 1.6, 1.6), RAINBOW[i % #RAINBOW + 1])
		l.Shape = Enum.PartType.Ball
		table.insert(lights, l)
	end
	local beam = part("TractorBeam", Vector3.new(34, 14, 14), tone, Enum.Material.Neon, 0.75)
	beam.Shape = Enum.PartType.Cylinder
	local glow = Instance.new("PointLight")
	glow.Color = tone
	glow.Range = 40
	glow.Brightness = 3
	glow.Parent = beam
	-- Motes of light rising up the beam.
	local lift = Instance.new("Attachment")
	lift.Parent = beam
	local motes = emitter(lift, SPARK, ColorSequence.new(tone:Lerp(Color3.new(1, 1, 1), 0.3), Color3.new(1, 1, 1)), { Rate = 0, Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(10, 18), SpreadAngle = Vector2.new(8, 8), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) }), LightEmission = 1, EmissionDirection = Enum.NormalId.Right })
	motes.Shape = Enum.ParticleEmitterShape.Cylinder
	motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sound("slideWhistle", 1, 1.2)
	local started = os.clock()
	local from = hover + Vector3.new(0, 120, -160)
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local arrive = math.min(1, t / 1.5)
		local at = from:Lerp(hover, 1 - (1 - arrive) ^ 3) + Vector3.new(math.sin(t * 2) * 1.5, math.sin(t * 3) * 1, 0)
		local leaving = t > seconds - 1.5
		if leaving then
			at += Vector3.new(0, (t - (seconds - 1.5)) ^ 2 * 60, 0)
		end
		saucer.CFrame = CFrame.new(at) * CFrame.Angles(0, t * 1.5, math.rad(90)) * CFrame.Angles(math.sin(t * 2) * 0.08, 0, 0)
		dome.Position = at + Vector3.new(0, 2.6, 0)
		for i, l in lights do
			local a = t * 3 + i / #lights * math.pi * 2
			l.Position = at + Vector3.new(math.cos(a) * 12.5, -0.8, math.sin(a) * 12.5)
		end
		beam.Transparency = if leaving or t < 1.6 then 1 else 0.72 + math.sin(t * 8) * 0.05
		motes.Rate = if leaving or t < 1.6 then 0 else 60
		beam.CFrame = CFrame.new(at - Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end)
	task.delay(1.6, function()
		if not alive(my) then
			return
		end
		sound("shimmer", 1, 0.7)
		carry(seconds - 3.4, function(t: number): Vector3?
			return hover - Vector3.new(0, math.max(8, 30 - t * 6), 0)
		end, my)
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.2)
		end
		conn:Disconnect()
		for _, x in { saucer, dome, beam } do
			x:Destroy()
		end
		for _, l in lights do
			l:Destroy()
		end
	end)
end

-- A box of particles that follows the guest (snow, embers, bubbles, dust...).
local function cloud(name: string, size: Vector3, offset: Vector3, configure: (Attachment) -> ()): (() -> ())
	local box = part(name, size, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local att = Instance.new("Attachment")
	att.Parent = box
	configure(att)
	local conn = RunService.Heartbeat:Connect(function()
		local root = rootOf()
		if root then
			box.Position = root.Position + offset
		end
	end)
	return function()
		conn:Disconnect()
		for _, e in att:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		task.delay(3, function()
			box:Destroy()
		end)
	end
end

local function boxed(e: ParticleEmitter)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
end

local function blizzard(seconds: number)
	local V = looks("blizzard")
	banner(V.banner, V.colour, 2.5)
	sound("fireworkHiss", 1, 0.5)
	local my = life()
	local stopSnow = cloud("Blizzard", Vector3.new(120, 30, 120), Vector3.new(0, 18, 0), function(att)
		boxed(emitter(att, SPARK, sequence(V.colours), { Rate = 900, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(4, 8), Acceleration = Vector3.new(60, -25, 10), Size = NumberSequence.new(0.35, 0.2), LightEmission = 0.4 }))
		boxed(emitter(att, SMOKE, ColorSequence.new(rgb(240, 248, 255)), { Rate = 25, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(2, 4), Acceleration = Vector3.new(30, -4, 0), Size = NumberSequence.new(10, 18), Transparency = NumberSequence.new(0.75, 1) }))
	end)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Whiteout"
	cc.Brightness = 0.12
	cc.Saturation = -0.4
	cc.TintColor = if typeof(V.tint) == "Color3" then V.tint else rgb(225, 240, 255)
	cc.Parent = Lighting
	task.spawn(function()
		local started = os.clock()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.25)
		end
		stopSnow()
		cc:Destroy()
	end)
end

local function earthquake(seconds: number)
	local V = looks("earthquake")
	banner(V.banner, V.colour, 2)
	sound("fireworkRumble", 1.2, 0.45)
	task.delay(0.5, sound, "fireworkTaiko", 1, 0.6)
	shake(seconds, 1.8)
	local my = life()
	local stopDust = cloud("Dust", Vector3.new(60, 2, 60), Vector3.new(0, -3, 0), function(att)
		boxed(emitter(att, SMOKE, sequence(V.colours), { Rate = 40, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(2, 6), Size = NumberSequence.new(3, 8), Transparency = NumberSequence.new(0.5, 1) }))
	end)
	task.spawn(function()
		local started = os.clock()
		while alive(my) and os.clock() - started < seconds do
			if free() and math.random() < 0.35 then
				throw(Vector3.new(math.random(-8, 8), 22, math.random(-8, 8)))
			end
			task.wait(0.8)
		end
		stopDust()
	end)
end

local function rainbowMode(seconds: number)
	local V = looks("rainbow")
	local C = V.colours
	banner(V.banner, V.colour, 2)
	sound("shimmer", 1)
	local my = life()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Rainbow"
	cc.Saturation = 0.5
	cc.Parent = Lighting
	local root = rootOf()
	local made: { Instance } = {}
	if root then
		local t0 = Instance.new("Attachment")
		t0.Position = Vector3.new(0, 1.5, 0)
		t0.Parent = root
		local t1 = Instance.new("Attachment")
		t1.Position = Vector3.new(0, -1.5, 0)
		t1.Parent = root
		local tr = Instance.new("Trail")
		tr.Attachment0 = t0
		tr.Attachment1 = t1
		tr.Lifetime = 1.2
		tr.LightEmission = 1
		tr.Color = sequence(C)
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.Parent = root
		made = { tr, t0, t1 }
		emitter(t1, SPARK, sequence(C), { Rate = 30, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.7, 0), LightEmission = 1 })
	end
	local started = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		-- (Every colour of its own in turn, blending one into the next.)
		local k = (t * 0.7) % #C
		local i = math.floor(k)
		cc.TintColor = Color3.new(1, 1, 1):Lerp(C[i + 1]:Lerp(C[(i + 1) % #C + 1], k - i), 0.3)
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.25)
		end
		conn:Disconnect()
		cc:Destroy()
		for _, x in made do
			x:Destroy()
		end
	end)
end

local function bubbles(seconds: number)
	local V = looks("bubbles")
	banner(V.banner, V.colour, 2)
	sound("shimmer", 0.8, 1.3)
	local my = life()
	local rng = Random.new()
	local list: { { part: Part, speed: number, phase: number } } = {}
	for _ = 1, 45 do
		local b = part("Bubble", Vector3.new(1, 1, 1) * rng:NextNumber(0.8, 2.6), V.colours[rng:NextInteger(1, #V.colours)]:Lerp(Color3.new(1, 1, 1), 0.45), Enum.Material.Glass, 0.55)
		b.Shape = Enum.PartType.Ball
		b.Reflectance = 0.35
		b.Position = Vector3.new(0, -1000, 0)
		table.insert(list, { part = b, speed = rng:NextNumber(3, 7), phase = rng:NextNumber(0, 6) })
	end
	local function respawn(b: { part: Part, speed: number, phase: number }, centre: Vector3)
		b.part.Position = centre + Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(-4, 2), rng:NextNumber(-25, 25))
	end
	local started = os.clock()
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		local root = rootOf()
		if not root then
			return
		end
		local centre = root.Position
		for _, b in list do
			local p = b.part.Position
			if p.Y < centre.Y - 20 or p.Y > centre.Y + 26 then
				respawn(b, centre)
				if p.Y > centre.Y + 26 and math.random() < 0.15 then
					sound("pickup", 0.25, 2)
				end
			else
				local t = os.clock() + b.phase
				b.part.Position = p + Vector3.new(math.sin(t * 1.3) * dt * 2, b.speed * dt, math.cos(t) * dt * 2)
			end
		end
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.25)
		end
		conn:Disconnect()
		for _, b in list do
			b.part:Destroy()
		end
	end)
end

local function goldWave(seconds: number)
	local V = looks("goldWave")
	sound("coinDrop", 1)
	task.delay(0.3, sound, "coinDrop", 1, 1.1)
	task.delay(0.6, sound, "crowdCheer", 0.6)
	if AbuseFX.isBusy() then
		-- (At a table the sorting screen draws its own wave of gold.)
		return
	end
	local gui = screen()
	local holderFrame = Instance.new("Frame")
	holderFrame.Name = "GoldWave"
	holderFrame.BackgroundTransparency = 1
	holderFrame.Size = UDim2.fromScale(1, 1)
	holderFrame.Parent = gui
	local wave = Instance.new("Frame")
	wave.Name = "Wave"
	wave.BorderSizePixel = 0
	wave.BackgroundColor3 = V.colours[1]
	wave.Position = UDim2.fromScale(-1.2, 0)
	wave.Size = UDim2.fromScale(1, 1)
	wave.Parent = holderFrame
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.6, 0.55), NumberSequenceKeypoint.new(0.85, 0.2), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = wave
	TweenService:Create(wave, TweenInfo.new(math.min(seconds, 3), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.fromScale(1.2, 0) }):Play()
	local rng = Random.new()
	for i = 1, 110 do
		local c = Instance.new("TextLabel")
		c.BackgroundTransparency = 1
		c.Text = if type(V.glyph) == "string" then V.glyph else "🪙"
		c.TextScaled = true
		local s = rng:NextNumber(0.04, 0.09)
		c.Size = UDim2.fromScale(s, s * 1.6)
		c.Position = UDim2.fromScale(rng:NextNumber(-0.6, -0.1), rng:NextNumber(-0.1, 1))
		c.Rotation = rng:NextNumber(-40, 40)
		c.Parent = holderFrame
		task.delay(i * 0.012, function()
			TweenService:Create(c, TweenInfo.new(rng:NextNumber(1.6, 2.8), Enum.EasingStyle.Sine), { Position = UDim2.fromScale(rng:NextNumber(1.05, 1.4), c.Position.Y.Scale + rng:NextNumber(-0.2, 0.2)), Rotation = c.Rotation + rng:NextNumber(-360, 360) }):Play()
		end)
	end
	banner(V.banner, V.colour, 2.2)
	task.delay(seconds, function()
		holderFrame:Destroy()
	end)
end

local function fireIce(seconds: number)
	local V = looks("fireIce")
	local warm, cool = V.colours[1], V.colours[2] or V.colours[1]
	banner(V.banner, V.colour, 2.2)
	sound("fireworkHiss", 0.9)
	local my = life()
	local stopFire = cloud("Embers", Vector3.new(50, 2, 50), Vector3.new(0, -3, 0), function(att)
		boxed(emitter(att, FIRE, ColorSequence.new(warm:Lerp(Color3.new(1, 1, 1), 0.3), warm), { Rate = 60, Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(4, 9), Size = NumberSequence.new(0.9, 0), LightEmission = 1, Acceleration = Vector3.new(0, 6, 0) }))
	end)
	local stopIce = cloud("Frost", Vector3.new(60, 2, 60), Vector3.new(0, 26, 0), function(att)
		boxed(emitter(att, SPARK, ColorSequence.new(cool:Lerp(Color3.new(1, 1, 1), 0.4), Color3.new(1, 1, 1)), { Rate = 120, Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(4, 7), Size = NumberSequence.new(0.5, 0.2), LightEmission = 0.6, Acceleration = Vector3.new(0, -6, 0), EmissionDirection = Enum.NormalId.Bottom }))
	end)
	local gui = screen()
	local sides = Instance.new("Frame")
	sides.Name = "FireIce"
	-- (At a table the sorting screen draws its own fire and ice.)
	sides.Visible = not AbuseFX.isBusy()
	sides.BackgroundTransparency = 1
	sides.Size = UDim2.fromScale(1, 1)
	sides.Parent = gui
	for i, colour in { warm, cool } do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = colour
		f.Size = UDim2.fromScale(0.5, 1)
		f.Position = UDim2.fromScale(if i == 1 then 0 else 0.5, 0)
		f.Parent = sides
		local g = Instance.new("UIGradient")
		g.Transparency = if i == 1 then NumberSequence.new(0.6, 1) else NumberSequence.new(1, 0.6)
		g.Parent = f
	end
	task.spawn(function()
		local started = os.clock()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.25)
		end
		stopFire()
		stopIce()
		sides:Destroy()
	end)
end

local function blackout(seconds: number)
	local V = looks("blackout")
	sound("bellStrike", 0.9, 0.6)
	local my = life()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Blackout"
	cc.Brightness = 0
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.5), { Brightness = -0.55, Saturation = -0.5 }):Play()
	banner(V.banner, V.colour, 2)
	local root = rootOf()
	local beams: { Part } = {}
	if root then
		for i = 1, 4 do
			local p = part("Spot", Vector3.new(1, 1, 1), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
			local light = Instance.new("SpotLight")
			light.Angle = 30
			light.Range = 120
			light.Brightness = 12
			light.Color = V.colours[(i - 1) % #V.colours + 1]
			light.Face = Enum.NormalId.Front
			light.Shadows = false
			light.Parent = p
			table.insert(beams, p)
		end
	end
	local started = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local r = rootOf()
		if not r then
			return
		end
		local t = os.clock() - started
		for i, p in beams do
			local a = t * 0.9 + i * math.pi / 2
			local at = r.Position + Vector3.new(math.cos(a) * 30, 40, math.sin(a) * 30)
			local look = r.Position + Vector3.new(math.cos(a * 1.7) * 18, -4, math.sin(a * 1.3) * 18)
			p.CFrame = CFrame.lookAt(at, look)
		end
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.2)
		end
		conn:Disconnect()
		for _, p in beams do
			p:Destroy()
		end
		cc:Destroy()
		if alive(my) then
			flash(Color3.new(1, 1, 1), 0.8, 1.2)
			sound("fireworkBoom", 1, 0.9)
			sound("crowdCheer", 0.6)
			banner("LIGHTS ON!", GOLD, 1.5)
		end
	end)
end

local function tornado(seconds: number)
	local V = looks("tornado")
	banner(V.banner, V.colour, 2.2)
	sound("fireworkHiss", 1, 0.4)
	task.delay(0.4, sound, "fireworkRumble", 0.8, 0.5)
	local root = rootOf()
	if not root then
		return
	end
	local my = life()
	local rng = Random.new()
	local start = root.Position + Vector3.new(26, -3, 0)
	local rings: { Part } = {}
	for i = 1, 12 do
		local w = 6 + i * 3.2
		-- (A plain one is dust; one of colours glows: fire, a rainbow, water.)
		local glowing = #V.colours > 1
		local ring = part("Funnel", Vector3.new(3, w, w), V.colours[(i - 1) % #V.colours + 1], if glowing then Enum.Material.Neon else Enum.Material.SmoothPlastic, (if glowing then 0.62 else 0.55) + i * 0.02)
		ring.Shape = Enum.PartType.Cylinder
		table.insert(rings, ring)
	end
	local debris: { Part } = {}
	for _ = 1, 26 do
		local d = part("Debris", Vector3.new(rng:NextNumber(0.5, 1.6), rng:NextNumber(0.2, 0.8), rng:NextNumber(0.5, 1.6)), if rng:NextNumber() < 0.5 then rgb(110, 90, 70) else rgb(90, 140, 70), Enum.Material.SmoothPlastic)
		table.insert(debris, d)
	end
	local started = os.clock()
	local centreAt = start
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local r = rootOf()
		if r then
			-- It wanders towards the guest.
			local to = Vector3.new(r.Position.X - centreAt.X, 0, r.Position.Z - centreAt.Z)
			if to.Magnitude > 4 then
				centreAt += to.Unit * math.min(to.Magnitude, 0.25)
			end
			centreAt = Vector3.new(centreAt.X, r.Position.Y - 3, centreAt.Z)
		end
		for i, ring in rings do
			local y = i * 3.4
			ring.CFrame = CFrame.new(centreAt + Vector3.new(math.sin(t * 2 + i * 0.4) * i * 0.3, y, math.cos(t * 2 + i * 0.4) * i * 0.3)) * CFrame.Angles(0, t * 6 + i, math.rad(90))
		end
		for i, d in debris do
			local a = t * 4 + i
			local h = (i / #debris) * 36
			local rr = 4 + h * 0.45
			d.CFrame = CFrame.new(centreAt + Vector3.new(math.cos(a) * rr, h, math.sin(a) * rr)) * CFrame.Angles(t * 3 + i, t * 2, 0)
		end
	end)
	task.delay(2, function()
		if not alive(my) then
			return
		end
		carry(seconds - 4, function(t: number): Vector3?
			local a = t * 3.2
			local rr = 9
			return centreAt + Vector3.new(math.cos(a) * rr, 8 + math.min(14, t * 3), math.sin(a) * rr)
		end, my)
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.2)
		end
		conn:Disconnect()
		for _, x in rings do
			x:Destroy()
		end
		for _, x in debris do
			x:Destroy()
		end
	end)
end

local function fireworksShow(seconds: number)
	local V = looks("fireworks")
	banner(V.banner, V.colour, 2)
	pcall(function()
		Fireworks.show(seconds, { scale = 1, watch = false, music = false, act = if type(V.act) == "string" then V.act else nil })
	end)
end

local function titan(seconds: number)
	local V = looks("titan")
	local glyphs = {}
	for _, c in Curios.List do
		if c.family == "meme" then
			table.insert(glyphs, c.glyph)
		end
	end
	local glyph = if type(V.glyph) == "string" then V.glyph elseif #glyphs > 0 then glyphs[math.random(1, #glyphs)] else "🗿"
	local camera = Workspace.CurrentCamera
	local root = rootOf()
	if not camera or not root then
		return
	end
	local my = life()
	local look = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local dir = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local base = root.Position + dir * 260
	local giant = part("Titan", Vector3.new(1, 1, 1), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	giant.Position = base - Vector3.new(0, 160, 0)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(170, 170)
	bb.LightInfluence = 0
	bb.MaxDistance = 2000
	bb.Parent = giant
	local face = Instance.new("TextLabel")
	face.BackgroundTransparency = 1
	face.Size = UDim2.fromScale(1, 1)
	face.TextScaled = true
	face.Text = glyph
	face.Parent = bb
	sound("fireworkRumble", 1.2, 0.35)
	shake(2.5, 0.8)
	banner("SOMETHING BIG...", rgb(255, 120, 120), 2)
	TweenService:Create(giant, TweenInfo.new(3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = base + Vector3.new(0, 70, 0) }):Play()
	local started = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		face.Rotation = math.sin(t * 1.2) * 14
	end)
	task.delay(3.2, function()
		if alive(my) then
			sound("gong", 1.2, 0.6)
			sound("airHorn", 1, 0.7)
			flash(rgb(255, 220, 200), 0.3, 0.6)
			banner(V.banner .. "!", V.colour, 2)
		end
	end)
	task.delay(math.max(4, seconds - 3), function()
		if giant.Parent then
			TweenService:Create(giant, TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = base - Vector3.new(0, 180, 0) }):Play()
		end
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.2)
		end
		conn:Disconnect()
		giant:Destroy()
	end)
end

-- Zero gravity: this guest's own world goes light for a while (their screen moves them).
local ZERO_G = 12 -- (the pull of the look that's on: set as it starts)
local zeroing = 0
local serverGravity: number? = nil
Workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
	-- (The house changing its gravity meanwhile, Featherlight say: kept for after.)
	if zeroing > 0 and math.abs(Workspace.Gravity - ZERO_G) > 0.01 then
		serverGravity = Workspace.Gravity
		Workspace.Gravity = ZERO_G
	end
end)

local function zeroG(seconds: number)
	local V = looks("zeroG")
	banner(V.banner, V.colour, 2.2)
	if zeroing == 0 and type(V.gravity) == "number" then
		ZERO_G = V.gravity
	end
	sound("shimmerFall", 0.9, 1.2)
	if zeroing == 0 then
		serverGravity = Workspace.Gravity
	end
	zeroing += 1
	Workspace.Gravity = ZERO_G
	if free() then
		throw(Vector3.new(0, if type(V.hop) == "number" then V.hop else 28, 0))
	end
	local my = life()
	local done = false
	local function back()
		if done then
			return
		end
		done = true
		zeroing = math.max(0, zeroing - 1)
		if zeroing == 0 then
			Workspace.Gravity = serverGravity or 196.2
		end
	end
	local id = onStop(back)
	task.spawn(function()
		local started = os.clock()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.2)
		end
		finished(id)
	end)
end

-- The owner's army: copies of the owner (their own avatar) drop from the sky in a ring round the
-- guest, land with a burst of gold, and dance round them, turning slowly, till it's over; then each
-- vanishes in a puff of gold. (Without the owner's avatar yet: a dance party.)
local function ownerArmy(seconds: number)
	local V = looks("ownerArmy")
	local template = OwnerCameo.template()
	local root = rootOf()
	if not template or not root then
		-- (AJKR's avatar not here yet: a dance party, under the army's name.)
		dance(seconds, V.banner, V.colour)
		return
	end
	banner(V.banner, V.colour, 2.5)
	local my = life()
	sound("airHorn", 1)
	task.delay(0.4, sound, "partyHorn", 1)
	-- (How far the avatar's root stands above its feet.)
	local lift = 3
	pcall(function()
		local cf, size = template:GetBoundingBox()
		lift = template:GetPivot().Position.Y - (cf.Position.Y - size.Y / 2)
	end)
	local count = 12
	local centre = root.Position
	local army: { { m: Model, a: number, land: number, ground: number } } = {}
	for i = 1, count do
		local m = template:Clone()
		m.Name = "OwnerCopy"
		local a = i / count * math.pi * 2
		local at = Vector3.new(centre.X + math.cos(a) * 15, centre.Y, centre.Z + math.sin(a) * 15)
		local ground = groundUnder(at).Y
		pcall(function()
			m:PivotTo(CFrame.new(at.X, ground + lift + 90 + i * 4, at.Z))
		end)
		m.Parent = stage()
		OwnerCameo.emote(m, "cheer", true)
		local pivot = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
		if pivot and pivot:IsA("BasePart") then
			local att = Instance.new("Attachment")
			att.Parent = pivot
			emitter(att, SPARK, sequence(V.colours), { Rate = 25, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) }), LightEmission = 1 })
		end
		table.insert(army, { m = m, a = a, land = 1 + i * 0.12, ground = ground })
	end
	local started = os.clock()
	local landedAll = false
	local conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		local me = rootOf()
		local here = if me then me.Position else centre
		local allDown = true
		for i, s in army do
			if not s.m.Parent then
				continue
			end
			local spin = s.a + math.max(0, t - 2.5) * 0.25
			local x, z = here.X + math.cos(spin) * 15, here.Z + math.sin(spin) * 15
			local k = math.clamp(t / s.land, 0, 1)
			local drop = (1 - k * k) * (90 + i * 4)
			if k < 1 then
				allDown = false
			elseif s.m:GetAttribute("Landed") == nil then
				s.m:SetAttribute("Landed", true)
				OwnerCameo.emote(s.m, if i % 3 == 0 then "dance2" elseif i % 3 == 1 then "dance" else "dance3", true)
			end
			pcall(function()
				s.m:PivotTo(CFrame.lookAt(Vector3.new(x, s.ground + lift + drop, z), Vector3.new(here.X, s.ground + lift + drop, here.Z)))
			end)
		end
		if allDown and not landedAll then
			landedAll = true
			sound("subHit", 0.9)
			sound("crowdCheer", 0.8)
			shake(0.4, 0.6)
		end
	end)
	task.spawn(function()
		while alive(my) and os.clock() - started < seconds do
			task.wait(0.25)
		end
		conn:Disconnect()
		for _, s in army do
			local m = s.m
			local ok, at = pcall(function(): Vector3
				return m:GetPivot().Position
			end)
			if ok then
				local puff = Instance.new("Attachment")
				puff.WorldPosition = at
				puff.Parent = Workspace.Terrain
				local e = emitter(puff, SPARK, ColorSequence.new(GOLD), { Rate = 0, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }), LightEmission = 1 })
				pcall(function()
					e:Emit(30)
				end)
				task.delay(1.2, function()
					puff:Destroy()
				end)
			end
			m:Destroy()
		end
		if alive(my) then
			sound("sparklePass", 0.8)
		end
	end)
end

local PLAYERS: { [string]: (number, Vector3?) -> () } = {
	intro = function(s)
		intro(s)
	end,
	launch = function(s)
		launch(s)
	end,
	dance = function(s)
		dance(s)
	end,
	storm = function(s)
		storm(s)
	end,
	memeRain = function(s)
		memeRain(s)
	end,
	confetti = function(s)
		confetti(s)
	end,
	shockwave = function(s, origin)
		shockwave(s, origin)
	end,
	spin = function(s)
		spin(s)
	end,
	meteor = function(s)
		meteor(s)
	end,
	blackHole = function(s)
		blackHole(s)
	end,
	aurora = function(s)
		aurora(s)
	end,
	galaxy = function(s)
		galaxy(s)
	end,
	ufo = function(s)
		ufo(s)
	end,
	blizzard = function(s)
		blizzard(s)
	end,
	earthquake = function(s)
		earthquake(s)
	end,
	rainbow = function(s)
		rainbowMode(s)
	end,
	bubbles = function(s)
		bubbles(s)
	end,
	goldWave = function(s)
		goldWave(s)
	end,
	fireIce = function(s)
		fireIce(s)
	end,
	blackout = function(s)
		blackout(s)
	end,
	tornado = function(s)
		tornado(s)
	end,
	fireworks = function(s)
		fireworksShow(s)
	end,
	titan = function(s)
		titan(s)
	end,
	zeroG = function(s)
		zeroG(s)
	end,
	ownerArmy = function(s)
		ownerArmy(s)
	end,
}

-- Plays one effect (as the server said), or "stop". `lasting`: switched on (no time limit: it
-- runs until its switch goes off).
function AbuseFX.play(id: string, seconds: number?, origin: Vector3?, lasting: boolean?, v: number?)
	if id == "stop" then
		token += 1
		-- Put back what's held (a guest in the air, the camera, gravity), then clear the stage.
		for key in undo do
			finished(key)
		end
		pcall(Fireworks.stop)
		local f = (Workspace:FindFirstChild("MaisonLocal") or Workspace):FindFirstChild("AbuseFX")
		if f then
			f:Destroy()
		end
		local gui = player:FindFirstChild("PlayerGui")
		local s = gui and gui:FindFirstChild("AbuseFX")
		if s then
			for _, c in s:GetChildren() do
				c:Destroy()
			end
		end
		-- (Anything still switched on starts again: only the server's switches decide.)
		task.delay(0.5, AbuseFX.resync)
		return
	end
	local fn = PLAYERS[id]
	if fn then
		local s = seconds or (cfg().fxSeconds[id] or 6)
		local was = starting
		starting = id
		looksNow[id] = if type(v) == "number" then v else 1
		local ok, err = pcall(function()
			fn(if lasting then math.max(1, s) else math.clamp(s, 1, 60), origin)
		end)
		starting = was
		if not ok then
			warn("[Maison] effect " .. id .. ": " .. tostring(err))
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Switched on: until it's switched off
---------------------------------------------------------------------------------------------------
-- The owner switches an effect on and it stays on, for everyone, until switched off (the server
-- keeps the switch: Workspace's Fx_<id>, so a guest arriving later joins in). The gentle ones
-- simply stay; the ones that move guests come in waves (Config.Admin.fxWaves), with a rest
-- between to walk and sort.
local LASTING = 1e7
local switched: { [string]: number } = {} -- id -> its run (bumped each time it's switched)
local onState: { [string]: boolean } = {} -- what this screen last heard each switch say

local function isOn(id: string): boolean
	return Workspace:GetAttribute(HouseEvents.fxAttribute(id)) ~= nil
end

function AbuseFX.sustain(id: string, on: boolean)
	if not PLAYERS[id] then
		return
	end
	local run = (switched[id] or 0) + 1
	switched[id] = run
	-- Whatever of it is playing now ends (a fresh start when switched on again).
	channel[id] = (channel[id] or 0) + 1
	if not on then
		return
	end
	task.spawn(function()
		-- (Arriving: wait for this guest's own character, round which it all plays.)
		while switched[id] == run and not rootOf() do
			task.wait(0.5)
		end
		local wave = (cfg().fxWaves :: any)[id]
		local first = true
		while switched[id] == run do
			repeating = not first
			-- (Its looks: as the server switched it on, the same in every server.)
			local v = Workspace:GetAttribute(HouseEvents.fxVariantAttribute(id))
			local looksV = if type(v) == "number" then v else nil
			if wave then
				AbuseFX.play(id, wave.on, nil, nil, looksV)
			else
				AbuseFX.play(id, LASTING, nil, true, looksV)
			end
			repeating = false
			first = false
			if not wave then
				return
			end
			local waited = 0
			while switched[id] == run and waited < wave.on + wave.rest do
				task.wait(0.25)
				waited += 0.25
			end
		end
	end)
end

-- Every switch as the server has it now (after a stop, the ones still on start again).
function AbuseFX.resync()
	for _, e in HouseEvents.Effects do
		local on = isOn(e.id)
		if on or onState[e.id] then
			onState[e.id] = on
			AbuseFX.sustain(e.id, on)
		end
	end
end

function AbuseFX.start()
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) == "table" and m.op == "abuseFX" and type(m.id) == "string" then
			local origin = if typeof(m.origin) == "Vector3" then m.origin else nil
			AbuseFX.play(m.id, if type(m.seconds) == "number" then m.seconds else nil, origin, nil, if type(m.v) == "number" then m.v else nil)
		end
	end)
	for _, e in HouseEvents.Effects do
		local id = e.id
		Workspace:GetAttributeChangedSignal(HouseEvents.fxAttribute(id)):Connect(function()
			local on = isOn(id)
			if on ~= (onState[id] == true) then
				onState[id] = on
				AbuseFX.sustain(id, on)
			end
		end)
	end
	AbuseFX.resync()
	-- A new character (a reset): the switched-on effects start again round it.
	player.CharacterAdded:Connect(function()
		task.delay(1, function()
			for id, on in onState do
				if on then
					AbuseFX.sustain(id, true)
				end
			end
		end)
	end)
end

return AbuseFX

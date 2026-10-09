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
--   stop        whatever is still playing stops

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Curios = require(ReplicatedStorage.Shared.Curios)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fireworks = require(script.Parent.Fireworks)
local Flakes = require(script.Parent.Flakes)
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
local CONFETTI = { rgb(255, 60, 140), rgb(80, 140, 255), rgb(90, 255, 170), rgb(255, 214, 80), rgb(246, 206, 112), rgb(255, 240, 200), rgb(190, 90, 255) }
local IMPACT = Font.fromEnum(Enum.Font.LuckiestGuy)
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

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

-- Big words slammed onto the screen, then gone.
local function banner(text: string, colour: Color3, seconds: number)
	if repeating then
		return
	end
	local label = Instance.new("TextLabel")
	label.Name = "Banner"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.32)
	label.Size = UDim2.fromScale(0.9, 0.16)
	label.FontFace = IMPACT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = colour
	label.TextStrokeColor3 = rgb(40, 24, 4)
	label.TextStrokeTransparency = 0
	local scale = Instance.new("UIScale")
	scale.Scale = 2.6
	scale.Parent = label
	label.Parent = screen()
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(seconds, function()
		local t = TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
		t:Play()
		task.delay(0.6, function()
			label:Destroy()
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
	banner("LIFT OFF!", rgb(255, 120, 60), 2)
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
	smoke.Color = ColorSequence.new(rgb(255, 200, 120), rgb(120, 110, 100))
	smoke.Parent = trail
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK
	sparks.Rate = 40
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Color = ColorSequence.new(GOLD)
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

local function dance(seconds: number)
	banner("DANCE PARTY!", rgb(255, 80, 200), 2.5)
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
			cc.TintColor = Color3.new(1, 1, 1):Lerp(RAINBOW[beat % #RAINBOW + 1], 0.16)
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
local function bolt(at: Vector3)
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
		seg.Color = rgb(210, 225, 255)
		seg.Size = Vector3.new(0.6, 0.6, length)
		seg.CFrame = CFrame.lookAt((from + to) / 2, to)
		seg.Position = (from + to) / 2
		seg.Parent = folder
		from = to
	end
	local glow = Instance.new("PointLight")
	glow.Range = 60
	glow.Brightness = 6
	glow.Color = rgb(200, 220, 255)
	glow.Parent = folder:FindFirstChild("Fork")
	task.delay(0.18, function()
		folder:Destroy()
	end)
end

local function storm(seconds: number)
	banner("LIGHTNING STORM", rgb(190, 215, 255), 2.5)
	local my = life()
	task.spawn(function()
		local started = os.clock()
		local rng = Random.new()
		while alive(my) and os.clock() - started < seconds do
			local root = rootOf()
			if root then
				local a = rng:NextNumber(0, math.pi * 2)
				local r = rng:NextNumber(40, 130)
				bolt(Vector3.new(root.Position.X + math.cos(a) * r, root.Position.Y - 3, root.Position.Z + math.sin(a) * r))
				flash(rgb(210, 225, 255), 0.35, 0.5)
				task.delay(rng:NextNumber(0.3, 1.1), function()
					sound(if rng:NextNumber() < 0.5 then "fireworkRumble" else "fireworkBoom", 0.9, rng:NextNumber(0.6, 0.8))
				end)
			end
			task.wait(rng:NextNumber(1.2, 3))
		end
	end)
end

local function memeRain(seconds: number)
	banner("BRAINROT STORM", rgb(120, 255, 120), 2.5)
	sound("airHorn", 1)
	task.delay(0.6, function()
		sound("airHorn", 1, 1.1)
	end)
	local glyphs = {}
	for _, c in Curios.List do
		if c.family == "meme" then
			table.insert(glyphs, c.glyph)
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
	banner("CONFETTI!", rgb(255, 214, 80), 2)
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
			colours = CONFETTI,
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
	ring.Color = GOLD
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
	banner("SPIN!", rgb(90, 230, 255), 1.5)
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
		root.CFrame = root.CFrame * CFrame.Angles(0, 14 * dt, 0)
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

-- One meteor: from high in the sky, at an angle, into the ground near the guest.
local function oneMeteor(centre: Vector3, rng: Random)
	local a = rng:NextNumber(0, math.pi * 2)
	local r = rng:NextNumber(14, 80)
	local hit = Vector3.new(centre.X + math.cos(a) * r, centre.Y - 3, centre.Z + math.sin(a) * r)
	local from = hit + Vector3.new(rng:NextNumber(-70, 70), 160, rng:NextNumber(-70, 70))
	local rock = part("Meteor", Vector3.new(4, 4, 4), rgb(255, 150, 60))
	rock.Shape = Enum.PartType.Ball
	rock.Position = from
	local att = Instance.new("Attachment")
	att.Parent = rock
	emitter(att, FIRE, ColorSequence.new(rgb(255, 220, 120), rgb(255, 80, 30)), { Rate = 120, Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(1, 3), Size = NumberSequence.new(4, 0.5), LightEmission = 1, Transparency = NumberSequence.new(0.1, 1) })
	emitter(att, SMOKE, ColorSequence.new(rgb(90, 70, 60)), { Rate = 40, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(0.5, 1.5), Size = NumberSequence.new(3, 7), Transparency = NumberSequence.new(0.4, 1) })
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 170, 80)
	glow.Range = 40
	glow.Brightness = 4
	glow.Parent = rock
	sound("fireworkWhistle", 0.8, rng:NextNumber(0.7, 0.9))
	local fall = rng:NextNumber(1, 1.5)
	local t = TweenService:Create(rock, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = hit })
	t:Play()
	t.Completed:Once(function()
		if not rock.Parent then
			return
		end
		rock.Transparency = 1
		for _, e in att:GetChildren() do
			if e:IsA("ParticleEmitter") then
				e.Enabled = false
			end
		end
		-- The impact: a ring of fire, sparks, a boom, the screen shaking if it was close.
		local ring = part("Impact", Vector3.new(0.6, 4, 4), rgb(255, 140, 50), Enum.Material.Neon, 0.1)
		ring.Shape = Enum.PartType.Cylinder
		ring.CFrame = CFrame.new(hit) * CFrame.Angles(0, 0, math.rad(90))
		TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.6, 46, 46), Transparency = 1 }):Play()
		local burst = Instance.new("Attachment")
		burst.WorldPosition = hit
		burst.Parent = Workspace.Terrain
		local sp = emitter(burst, SPARKS, ColorSequence.new(rgb(255, 230, 140), rgb(255, 90, 30)), { Rate = 0, Lifetime = NumberRange.new(0.6, 1.2), Speed = NumberRange.new(20, 45), SpreadAngle = Vector2.new(70, 70), Size = NumberSequence.new(1.2, 0), LightEmission = 1, Acceleration = Vector3.new(0, -40, 0) })
		sp:Emit(60)
		sound("fireworkBoom", 1, rng:NextNumber(0.55, 0.75))
		local me = rootOf()
		if me then
			local d = (me.Position - hit).Magnitude
			if d < 45 then
				shake(0.6, 1.4 * (1 - d / 45))
			end
			if d < 14 and free() then
				local away = Vector3.new(me.Position.X - hit.X, 0, me.Position.Z - hit.Z)
				throw((if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)) * 50 + Vector3.new(0, 45, 0))
			end
		end
		task.delay(1.5, function()
			rock:Destroy()
			ring:Destroy()
			burst:Destroy()
		end)
	end)
end

local function meteor(seconds: number)
	banner("METEOR SHOWER!", rgb(255, 150, 60), 2.5)
	flash(rgb(255, 170, 110), 0.25, 1)
	local my = life()
	task.spawn(function()
		local rng = Random.new()
		local started = os.clock()
		while alive(my) and os.clock() - started < seconds do
			local root = rootOf()
			if root then
				oneMeteor(root.Position, rng)
			end
			task.wait(rng:NextNumber(0.5, 1.3))
		end
	end)
end

local function blackHole(seconds: number)
	banner("BLACK HOLE!", rgb(190, 120, 255), 2.5)
	local root = rootOf()
	if not root then
		return
	end
	local my = life()
	local centre = root.Position + Vector3.new(0, 48, 0)
	local hole = part("BlackHole", Vector3.new(2, 2, 2), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	hole.Shape = Enum.PartType.Ball
	hole.Position = centre
	local disk = part("Disk", Vector3.new(0.6, 2, 2), rgb(255, 140, 60), Enum.Material.Neon, 0.25)
	disk.Shape = Enum.PartType.Cylinder
	local halo = part("Halo", Vector3.new(0.4, 2, 2), rgb(170, 90, 255), Enum.Material.Neon, 0.5)
	halo.Shape = Enum.PartType.Cylinder
	local swirl = Instance.new("Attachment")
	swirl.Parent = hole
	emitter(swirl, RING, ColorSequence.new(rgb(200, 140, 255), rgb(255, 150, 80)), { Rate = 10, Lifetime = NumberRange.new(1.5, 2), Speed = NumberRange.new(0, 0), Size = NumberSequence.new(40, 8), LightEmission = 1, Transparency = NumberSequence.new(0.3, 1), RotSpeed = NumberRange.new(120, 200), Rotation = NumberRange.new(0, 360) })
	emitter(swirl, SPARK, ColorSequence.new(rgb(220, 180, 255)), { Rate = 60, Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(-30, -18), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.8, 0), LightEmission = 1 })
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BlackHoleDark"
	cc.Brightness = -0.15
	cc.TintColor = rgb(200, 180, 255)
	cc.Parent = Lighting
	sound("fireworkRumble", 1, 0.5)
	local grow = 0.8
	TweenService:Create(hole, TweenInfo.new(grow, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(16, 16, 16) }):Play()
	local started = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		local s = math.min(1, t / grow)
		disk.Size = Vector3.new(0.6, 46 * s, 46 * s)
		halo.Size = Vector3.new(0.4, 62 * s, 62 * s)
		disk.CFrame = CFrame.new(centre) * CFrame.Angles(math.rad(12), t * 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		halo.CFrame = CFrame.new(centre) * CFrame.Angles(math.rad(-8), -t * 1.3, 0) * CFrame.Angles(0, 0, math.rad(90))
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
		flash(rgb(230, 210, 255), 0.4, 0.8)
		sound("fireworkBoom", 1, 0.5)
		for _, x in { hole, disk, halo } do
			x:Destroy()
		end
	end)
end

local function aurora(seconds: number)
	banner("AURORA", rgb(120, 255, 200), 2)
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
	local colours = {
		ColorSequence.new(rgb(80, 255, 170), rgb(120, 200, 255)),
		ColorSequence.new(rgb(120, 255, 140), rgb(190, 110, 255)),
		ColorSequence.new(rgb(90, 220, 255), rgb(220, 120, 255)),
	}
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
	banner("TO THE STARS", rgb(170, 150, 255), 2.5)
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
		local n = part("Nebula", Vector3.new(1, 1, 1) * rng:NextNumber(110, 200), if rng:NextNumber() < 0.5 then rgb(160, 80, 255) else rgb(60, 140, 255), Enum.Material.Neon, 0.86)
		n.Shape = Enum.PartType.Ball
		n.Position = centre + dir * 560
		n.Parent = folder
	end
	local planetAt = centre + Vector3.new(-260, 190, -320)
	local planet = part("Planet", Vector3.new(110, 110, 110), rgb(220, 150, 90), Enum.Material.SmoothPlastic)
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
	banner("ABDUCTED!", rgb(120, 255, 140), 2.5)
	local root = rootOf()
	if not root then
		return
	end
	local my = life()
	local hover = root.Position + Vector3.new(0, 34, 0)
	local saucer = part("Saucer", Vector3.new(4, 26, 26), rgb(170, 180, 190), Enum.Material.Metal)
	saucer.Shape = Enum.PartType.Cylinder
	saucer.Reflectance = 0.3
	local dome = part("Dome", Vector3.new(11, 11, 11), rgb(150, 240, 255), Enum.Material.Glass, 0.35)
	dome.Shape = Enum.PartType.Ball
	local lights: { Part } = {}
	for i = 1, 10 do
		local l = part("Light", Vector3.new(1.6, 1.6, 1.6), RAINBOW[i % #RAINBOW + 1])
		l.Shape = Enum.PartType.Ball
		table.insert(lights, l)
	end
	local beam = part("TractorBeam", Vector3.new(34, 14, 14), rgb(140, 255, 160), Enum.Material.Neon, 0.75)
	beam.Shape = Enum.PartType.Cylinder
	local glow = Instance.new("PointLight")
	glow.Color = rgb(140, 255, 160)
	glow.Range = 40
	glow.Brightness = 3
	glow.Parent = beam
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
	banner("BLIZZARD!", rgb(220, 240, 255), 2.5)
	sound("fireworkHiss", 1, 0.5)
	local my = life()
	local stopSnow = cloud("Blizzard", Vector3.new(120, 30, 120), Vector3.new(0, 18, 0), function(att)
		boxed(emitter(att, SPARK, ColorSequence.new(Color3.new(1, 1, 1)), { Rate = 900, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(4, 8), Acceleration = Vector3.new(60, -25, 10), Size = NumberSequence.new(0.35, 0.2), LightEmission = 0.4 }))
		boxed(emitter(att, SMOKE, ColorSequence.new(rgb(240, 248, 255)), { Rate = 25, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(2, 4), Acceleration = Vector3.new(30, -4, 0), Size = NumberSequence.new(10, 18), Transparency = NumberSequence.new(0.75, 1) }))
	end)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Whiteout"
	cc.Brightness = 0.12
	cc.Saturation = -0.4
	cc.TintColor = rgb(225, 240, 255)
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
	banner("EARTHQUAKE!", rgb(230, 170, 110), 2)
	sound("fireworkRumble", 1.2, 0.45)
	task.delay(0.5, sound, "fireworkTaiko", 1, 0.6)
	shake(seconds, 1.8)
	local my = life()
	local stopDust = cloud("Dust", Vector3.new(60, 2, 60), Vector3.new(0, -3, 0), function(att)
		boxed(emitter(att, SMOKE, ColorSequence.new(rgb(170, 150, 120)), { Rate = 40, Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(2, 6), Size = NumberSequence.new(3, 8), Transparency = NumberSequence.new(0.5, 1) }))
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
	banner("RAINBOW MODE!", Color3.new(1, 1, 1), 2)
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
		tr.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, RAINBOW[1]),
			ColorSequenceKeypoint.new(0.33, RAINBOW[4]),
			ColorSequenceKeypoint.new(0.66, RAINBOW[3]),
			ColorSequenceKeypoint.new(1, RAINBOW[5]),
		})
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.Parent = root
		made = { tr, t0, t1 }
		emitter(t1, SPARK, ColorSequence.new(RAINBOW[1], RAINBOW[5]), { Rate = 30, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(0.7, 0), LightEmission = 1 })
	end
	local started = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - started
		cc.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromHSV((t * 0.35) % 1, 0.8, 1), 0.3)
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
	banner("BUBBLES!", rgb(160, 220, 255), 2)
	sound("shimmer", 0.8, 1.3)
	local my = life()
	local rng = Random.new()
	local list: { { part: Part, speed: number, phase: number } } = {}
	for _ = 1, 45 do
		local b = part("Bubble", Vector3.new(1, 1, 1) * rng:NextNumber(0.8, 2.6), rgb(200, 235, 255), Enum.Material.Glass, 0.55)
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
	wave.BackgroundColor3 = rgb(255, 200, 70)
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
		c.Text = "🪙"
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
	banner("GOLD WAVE!", rgb(255, 214, 90), 2.2)
	task.delay(seconds, function()
		holderFrame:Destroy()
	end)
end

local function fireIce(seconds: number)
	banner("FIRE & ICE", rgb(255, 160, 120), 2.2)
	sound("fireworkHiss", 0.9)
	local my = life()
	local stopFire = cloud("Embers", Vector3.new(50, 2, 50), Vector3.new(0, -3, 0), function(att)
		boxed(emitter(att, FIRE, ColorSequence.new(rgb(255, 200, 90), rgb(255, 60, 30)), { Rate = 60, Lifetime = NumberRange.new(1.2, 2.2), Speed = NumberRange.new(4, 9), Size = NumberSequence.new(0.9, 0), LightEmission = 1, Acceleration = Vector3.new(0, 6, 0) }))
	end)
	local stopIce = cloud("Frost", Vector3.new(60, 2, 60), Vector3.new(0, 26, 0), function(att)
		boxed(emitter(att, SPARK, ColorSequence.new(rgb(200, 235, 255), Color3.new(1, 1, 1)), { Rate = 120, Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(4, 7), Size = NumberSequence.new(0.5, 0.2), LightEmission = 0.6, Acceleration = Vector3.new(0, -6, 0), EmissionDirection = Enum.NormalId.Bottom }))
	end)
	local gui = screen()
	local sides = Instance.new("Frame")
	sides.Name = "FireIce"
	-- (At a table the sorting screen draws its own fire and ice.)
	sides.Visible = not AbuseFX.isBusy()
	sides.BackgroundTransparency = 1
	sides.Size = UDim2.fromScale(1, 1)
	sides.Parent = gui
	for i, colour in { rgb(255, 80, 30), rgb(60, 160, 255) } do
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
	sound("bellStrike", 0.9, 0.6)
	local my = life()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Blackout"
	cc.Brightness = 0
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(0.5), { Brightness = -0.55, Saturation = -0.5 }):Play()
	banner("LIGHTS OUT", rgb(220, 220, 255), 2)
	local root = rootOf()
	local beams: { Part } = {}
	if root then
		for i = 1, 4 do
			local p = part("Spot", Vector3.new(1, 1, 1), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
			local light = Instance.new("SpotLight")
			light.Angle = 30
			light.Range = 120
			light.Brightness = 12
			light.Color = RAINBOW[i * 2 % #RAINBOW + 1]
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
	banner("TORNADO!", rgb(200, 200, 210), 2.2)
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
		local ring = part("Funnel", Vector3.new(3, w, w), rgb(150, 150, 160), Enum.Material.SmoothPlastic, 0.55 + i * 0.02)
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
	banner("FIREWORKS!", rgb(255, 214, 110), 2)
	pcall(function()
		Fireworks.show(seconds, { scale = 1, watch = false, music = false })
	end)
end

local function titan(seconds: number)
	local glyphs = {}
	for _, c in Curios.List do
		if c.family == "meme" then
			table.insert(glyphs, c.glyph)
		end
	end
	local glyph = if #glyphs > 0 then glyphs[math.random(1, #glyphs)] else "🗿"
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
local ZERO_G = 12
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
	banner("ZERO GRAVITY", rgb(170, 200, 255), 2.2)
	sound("shimmerFall", 0.9, 1.2)
	if zeroing == 0 then
		serverGravity = Workspace.Gravity
	end
	zeroing += 1
	Workspace.Gravity = ZERO_G
	if free() then
		throw(Vector3.new(0, 28, 0))
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
}

-- Plays one effect (as the server said), or "stop". `lasting`: switched on (no time limit: it
-- runs until its switch goes off).
function AbuseFX.play(id: string, seconds: number?, origin: Vector3?, lasting: boolean?)
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
			if wave then
				AbuseFX.play(id, wave.on)
			else
				AbuseFX.play(id, LASTING, nil, true)
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
			AbuseFX.play(m.id, if type(m.seconds) == "number" then m.seconds else nil, origin)
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

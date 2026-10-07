--!strict
-- The Meme Takeover (a Suite spectacle): ninety seconds of the house's meme curios taking over
-- the room you're standing in, in six acts.
--   1. The warning: the lights go purple, sirens of colour, MEME TAKEOVER across the screen.
--   2. The portal: a spinning ring opens mid-room and spews memes that bounce off the walls.
--   3. The conga: every meme lines up and dances round you under disco lights.
--   4. The rain: hundreds of little memes and confetti pour from the ceiling.
--   5. The boss: a giant meme descends, laser eyes sweeping, the room shaking, the rest orbiting.
--   6. Chaos, then the finale: everything bursts into confetti. GG.
-- Drawn on this screen only (a Suite is its owner's alone); the server only says when. Every
-- number that shapes it is in Config.Spectacles.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Layout = require(ReplicatedStorage.Shared.Layout)
local CameraRig = require(script.Parent.Parent.Camera)
local Sound = require(script.Parent.Parent.Sound)

local MemeTakeover = {}

type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
type Actor = { part: Part, gui: BillboardGui, glyph: TextLabel, size: number, v: Vector3, at: Vector3, spin: number, phase: number, home: number }

local DISCO = { Color3.fromRGB(255, 60, 200), Color3.fromRGB(60, 200, 255), Color3.fromRGB(120, 255, 90), Color3.fromRGB(255, 220, 60), Color3.fromRGB(170, 80, 255), Color3.fromRGB(255, 90, 60) }
local IMPACT = Font.fromEnum(Enum.Font.LuckiestGuy)

local running = false

local function cfg(): { [string]: any }
	return (Config.data :: any).Spectacles
end

-- The room of the Suite the guest stands in (the drawing room if we can't tell).
local function roomOf(at: Vector3): Box
	local S = Layout.Suite :: any
	for _, key in { "main", "bedroom", "kitchen", "spa", "screening", "gym", "dressing", "study", "terrace" } do
		local b = S[key]
		if b and at.X >= b.minX and at.X <= b.maxX and at.Z >= b.minZ and at.Z <= b.maxZ then
			return b
		end
	end
	return S.main
end

local function memes(): { any }
	local out = {}
	for _, c in Curios.List do
		if c.family == "meme" then
			table.insert(out, c)
		end
	end
	return out
end

local function newPart(parent: Instance, at: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(0.5, 0.5, 0.5)
	p.CFrame = CFrame.new(at)
	p.Parent = parent
	return p
end

-- A meme: its glyph big, its accent riding on its shoulder.
local function actor(parent: Instance, c: any, size: number, at: Vector3): Actor
	local p = newPart(parent, at)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size, size)
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Parent = p
	local g = Instance.new("TextLabel")
	g.BackgroundTransparency = 1
	g.Size = UDim2.fromScale(1, 1)
	g.Text = c.glyph
	g.TextScaled = true
	g.Rotation = 0
	g.Parent = bb
	local a = Instance.new("TextLabel")
	a.BackgroundTransparency = 1
	a.AnchorPoint = Vector2.new(1, 0)
	a.Position = UDim2.fromScale(1.05, -0.05)
	a.Size = UDim2.fromScale(0.45, 0.45)
	a.Text = c.accent or ""
	a.TextScaled = true
	a.Parent = g
	return { part = p, gui = bb, glyph = g, size = size, v = Vector3.zero, at = at, spin = 0, phase = math.random() * 10, home = math.random() * math.pi * 2 }
end

local lastCaption: TextLabel? = nil

local function caption(gui: ScreenGui, text: string, colour: Color3, hold: number)
	-- (One at a time: a new line replaces the last at once.)
	local prev = lastCaption
	if prev then
		prev:Destroy()
	end
	local label = Instance.new("TextLabel")
	lastCaption = label
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.22)
	label.Size = UDim2.fromScale(0.86, 0.14)
	label.FontFace = IMPACT
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = gui
	local s = Instance.new("UIScale")
	s.Scale = 2.2
	s.Parent = label
	TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < hold and label.Parent do
			label.Rotation = math.sin(os.clock() * 30) * 3
			task.wait()
		end
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.wait(0.45)
		label:Destroy()
	end)
end

local function confetti(parent: Instance, at: Vector3, area: Vector3, rate: number): ParticleEmitter
	local p = newPart(parent, at)
	p.Size = area
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate
	e.Lifetime = NumberRange.new(2.5, 4)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(40, 40)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Acceleration = Vector3.new(0, -6, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Size = NumberSequence.new(0.6, 0.3)
	e.LightEmission = 0.7
	pcall(function()
		local points = {}
		for i, c in DISCO do
			table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#DISCO - 1), c))
		end
		e.Color = ColorSequence.new(points)
	end)
	e.Parent = p
	return e
end

local function burst(parent: Instance, at: Vector3, n: number)
	local p = newPart(parent, at)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.8, 1.6)
	e.Speed = NumberRange.new(12, 30)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 2
	e.Acceleration = Vector3.new(0, -10, 0)
	e.Size = NumberSequence.new(0.9, 0)
	e.LightEmission = 1
	pcall(function()
		e.Color = ColorSequence.new(DISCO[math.random(1, #DISCO)], DISCO[math.random(1, #DISCO)])
	end)
	e.Parent = p
	e:Emit(n)
	task.delay(2, function()
		p:Destroy()
	end)
end

-- Plays the Takeover in the room around `at` (the guest's position), for `seconds`.
function MemeTakeover.play(seconds: number?)
	if running then
		return
	end
	local player = Players.LocalPlayer
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local centre: Vector3 = if rootPart and rootPart:IsA("BasePart") then rootPart.Position else Vector3.new(-49, Layout.Suite.floorY + 3, 50)
	local room = roomOf(centre)
	local floorY = Layout.Suite.floorY
	local ceiling = floorY + Layout.Suite.height - 1
	local mid = Vector3.new((room.minX + room.maxX) / 2, floorY, (room.minZ + room.maxZ) / 2)
	local T = seconds or cfg().memeSeconds
	running = true

	local folder = Instance.new("Folder")
	folder.Name = "MemeTakeover"
	folder.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "MemeTakeover"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 35
	gui.Parent = player:WaitForChild("PlayerGui")
	local tint = Instance.new("Frame")
	tint.BackgroundColor3 = DISCO[1]
	tint.BackgroundTransparency = 1
	tint.BorderSizePixel = 0
	tint.Size = UDim2.fromScale(1, 1)
	tint.Parent = gui

	-- The room's own lights turn party colours (put back after), and disco lights hang overhead.
	local saved: { [Light]: Color3 } = {}
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Light") and d.Parent and d.Parent:IsA("BasePart") then
			local p = (d.Parent :: BasePart).Position
			if p.X >= room.minX - 1 and p.X <= room.maxX + 1 and p.Z >= room.minZ - 1 and p.Z <= room.maxZ + 1 and p.Y >= floorY - 1 and p.Y <= ceiling + 3 then
				saved[d] = d.Color
			end
		end
	end
	local discos: { PointLight } = {}
	for i = 1, 4 do
		local holder = newPart(folder, mid + Vector3.new(math.cos(i * 1.57) * 5, Layout.Suite.height - 2, math.sin(i * 1.57) * 5))
		local l = Instance.new("PointLight")
		l.Range = 26
		l.Brightness = 0
		l.Shadows = false
		l.Parent = holder
		table.insert(discos, l)
	end
	local siren = Lighting:FindFirstChild("MemeTint")
	if not siren then
		local e = Instance.new("ColorCorrectionEffect")
		e.Name = "MemeTint"
		e.Parent = Lighting
		siren = e
	end
	local cc = siren :: ColorCorrectionEffect
	cc.Enabled = true

	local list = memes()
	local cast: { Actor } = {}
	local minis: { Actor } = {}
	local boss: Actor? = nil
	local lasers: { Beam } = {}
	local act = 0
	local t0 = os.clock()
	local beat = 0
	local rain: ParticleEmitter? = nil

	local function spawnMeme(size: number, at: Vector3, v: Vector3): Actor
		local a = actor(folder, list[math.random(1, #list)], size, at)
		a.v = v
		table.insert(cast, a)
		return a
	end

	local function setAct(n: number)
		if n == act then
			return
		end
		act = n
		if n == 1 then
			caption(gui, "⚠️ MEME TAKEOVER ⚠️", Color3.fromRGB(255, 70, 90), 4)
			pcall(Sound.play, "fireworkBoom", 1, 0.6)
		elseif n == 2 then
			caption(gui, "THE PORTAL IS OPEN", Color3.fromRGB(120, 255, 120), 3)
		elseif n == 3 then
			caption(gui, "CONGA LINE!!", Color3.fromRGB(255, 220, 60), 3)
		elseif n == 4 then
			caption(gui, "IT'S RAINING MEMES", Color3.fromRGB(90, 200, 255), 3)
			rain = confetti(folder, Vector3.new(mid.X, ceiling, mid.Z), Vector3.new(room.maxX - room.minX - 2, 0.5, room.maxZ - room.minZ - 2), 220)
		elseif n == 5 then
			caption(gui, "THE BIG CHEESE HAS ARRIVED", Color3.fromRGB(255, 200, 80), 4)
			pcall(Sound.play, "fireworkBoom", 1, 0.45)
			local cheese = Curios.byId and (Curios.byId :: any).moonCheese
			local a = actor(folder, cheese or list[#list], cfg().bossSize, Vector3.new(mid.X, ceiling + 10, mid.Z))
			boss = a
			-- Laser eyes: two beams from the boss to points sweeping the floor.
			for i = 1, 2 do
				local from = Instance.new("Attachment")
				from.Parent = a.part
				from.Position = Vector3.new(if i == 1 then -1.2 else 1.2, 1, 0)
				local hit = newPart(folder, mid)
				local to = Instance.new("Attachment")
				to.Parent = hit
				local b = Instance.new("Beam")
				b.Attachment0 = from
				b.Attachment1 = to
				b.Width0 = 0.6
				b.Width1 = 1.4
				b.LightEmission = 1
				b.FaceCamera = true
				b.Color = ColorSequence.new(Color3.fromRGB(255, 40, 40))
				b.Transparency = NumberSequence.new(0.1)
				b.Parent = a.part
				table.insert(lasers, b)
				b:SetAttribute("Hit", i)
				hit.Name = "LaserHit" .. i
			end
		elseif n == 6 then
			caption(gui, "MAXIMUM BRAINROT", Color3.fromRGB(255, 80, 220), 3)
			if rain then
				rain.Rate = 500
			end
		elseif n == 7 then
			caption(gui, "GG · MEME TAKEOVER COMPLETE", Color3.fromRGB(255, 240, 200), 3.5)
			pcall(Sound.play, "fireworkBoom", 1, 0.8)
			for _, a in cast do
				burst(folder, a.at, 40)
				a.part:Destroy()
			end
			for _, a in minis do
				a.part:Destroy()
			end
			table.clear(cast)
			table.clear(minis)
			local b = boss
			if b then
				burst(folder, b.at, 200)
				b.part:Destroy()
				boss = nil
			end
			if rain then
				rain.Rate = 0
			end
			tint.BackgroundColor3 = Color3.new(1, 1, 1)
			tint.BackgroundTransparency = 0.2
			TweenService:Create(tint, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		end
	end

	-- When each act begins, as a share of the whole.
	local ACTS = { 0, 0.06, 0.22, 0.42, 0.58, 0.8, 0.95 }
	local spawned = 0
	local lastBeat = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		local t = os.clock() - t0
		local k = t / T
		if k >= 1 or not folder.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local n = 1
		for i, start in ACTS do
			if k >= start then
				n = i
			end
		end
		setAct(n)
		local me = player.Character
		local myRoot = me and me:FindFirstChild("HumanoidRootPart")
		local you: Vector3 = if myRoot and myRoot:IsA("BasePart") then myRoot.Position else centre
		-- The beat: twice a second (four times in the chaos).
		local every = if act >= 6 then 0.25 else 0.5
		if t - lastBeat >= every then
			lastBeat = t
			beat += 1
			if act >= 2 and act <= 6 then
				pcall(Sound.play, "tick", 0.5, if beat % 4 == 0 then 0.7 else 1.1)
			end
			local c = DISCO[beat % #DISCO + 1]
			for i, l in discos do
				l.Color = DISCO[(beat + i) % #DISCO + 1]
				l.Brightness = if act >= 2 and act <= 6 then 3 else 0
			end
			for light in saved do
				if light.Parent then
					light.Color = if act <= 6 then c else saved[light]
				end
			end
			if act == 1 or act >= 5 then
				tint.BackgroundColor3 = c
				tint.BackgroundTransparency = if act == 1 then 0.75 else 0.88
				TweenService:Create(tint, TweenInfo.new(every * 0.9), { BackgroundTransparency = 1 }):Play()
			end
			if act >= 5 and act <= 6 then
				pcall(CameraRig.shake, if act == 6 then 0.5 else 0.3, every)
			end
		end
		cc.Saturation = if act >= 2 and act <= 6 then 0.5 else 0
		-- Act 2: the portal spews memes, a few each beat, until the cast is full.
		if act == 2 and spawned < cfg().memeCast then
			spawned += 1
			local a = math.random() * math.pi * 2
			spawnMeme(math.random(25, 55) / 10, Vector3.new(mid.X, floorY + 4, mid.Z), Vector3.new(math.cos(a) * 16, 14 + math.random() * 10, math.sin(a) * 16))
			if spawned % 4 == 0 then
				pcall(Sound.play, "pickup", 0.4, 0.8 + math.random() * 0.6)
				burst(folder, Vector3.new(mid.X, floorY + 4, mid.Z), 25)
			end
		end
		-- Act 4: little memes rain from the ceiling.
		if act == 4 and #minis < cfg().memeRain and math.random() < 0.8 then
			local m = actor(folder, list[math.random(1, #list)], math.random(8, 16) / 10, Vector3.new(room.minX + 1 + math.random() * (room.maxX - room.minX - 2), ceiling, room.minZ + 1 + math.random() * (room.maxZ - room.minZ - 2)))
			m.v = Vector3.new(0, -math.random(4, 10), 0)
			table.insert(minis, m)
		end
		-- Moving everyone.
		for i, a in cast do
			local goal: Vector3? = nil
			if act == 3 then
				-- The conga: a ring round the guest, turning, every one bobbing to the beat.
				local ang = a.home + t * 1.2 + i * 0.05
				goal = you + Vector3.new(math.cos(ang) * 7, 1.5 + math.abs(math.sin(t * 6 + i)) * 1.5, math.sin(ang) * 7)
			elseif act == 5 then
				-- Orbiting the boss.
				local b = boss
				if b then
					local ang = a.home + t * 2
					goal = b.at + Vector3.new(math.cos(ang) * (6 + (i % 3) * 2), math.sin(t * 3 + i) * 3 - 2, math.sin(ang) * (6 + (i % 3) * 2))
				end
			end
			if goal then
				a.at = a.at:Lerp(goal, math.min(1, dt * 4))
			else
				-- Bouncing off the floor and the walls (and, in the chaos, much faster).
				local speed = if act == 6 then 1.8 else 1
				a.v -= Vector3.new(0, 30 * dt, 0)
				local nxt = a.at + a.v * dt * speed
				if nxt.Y < floorY + a.size / 2 then
					nxt = Vector3.new(nxt.X, floorY + a.size / 2, nxt.Z)
					a.v = Vector3.new(a.v.X, math.abs(a.v.Y) * 0.9 + 6, a.v.Z)
				end
				if nxt.Y > ceiling then
					a.v = Vector3.new(a.v.X, -math.abs(a.v.Y), a.v.Z)
				end
				if nxt.X < room.minX + 1 or nxt.X > room.maxX - 1 then
					a.v = Vector3.new(-a.v.X, a.v.Y, a.v.Z)
					nxt = Vector3.new(math.clamp(nxt.X, room.minX + 1, room.maxX - 1), nxt.Y, nxt.Z)
				end
				if nxt.Z < room.minZ + 1 or nxt.Z > room.maxZ - 1 then
					a.v = Vector3.new(a.v.X, a.v.Y, -a.v.Z)
					nxt = Vector3.new(nxt.X, nxt.Y, math.clamp(nxt.Z, room.minZ + 1, room.maxZ - 1))
				end
				a.at = nxt
			end
			a.spin += dt * (if act == 6 then 720 else 160)
			a.glyph.Rotation = if act == 3 then math.sin(t * 8 + i) * 20 else a.spin % 360
			local squash = 1 + math.sin(t * 10 + a.phase) * 0.12
			a.gui.Size = UDim2.fromScale(a.size * squash, a.size / squash)
			a.part.CFrame = CFrame.new(a.at)
		end
		for _, m in minis do
			m.v -= Vector3.new(0, 20 * dt, 0)
			local nxt = m.at + m.v * dt
			if nxt.Y < floorY + 0.5 then
				nxt = Vector3.new(nxt.X, floorY + 0.5, nxt.Z)
				m.v = Vector3.new((math.random() - 0.5) * 8, math.abs(m.v.Y) * 0.5, (math.random() - 0.5) * 8)
			end
			m.at = nxt
			m.glyph.Rotation += dt * 300
			m.part.CFrame = CFrame.new(m.at)
		end
		-- The boss: down from the ceiling, turning, its lasers sweeping the floor.
		local b = boss
		if b then
			local goal = Vector3.new(mid.X, floorY + cfg().bossSize / 2 + 1, mid.Z)
			b.at = b.at:Lerp(goal, math.min(1, dt * 1.2))
			b.part.CFrame = CFrame.new(b.at)
			local pulse = 1 + math.sin(t * 6) * 0.06
			b.gui.Size = UDim2.fromScale(b.size * pulse, b.size * pulse)
			b.glyph.Rotation = math.sin(t * 2) * 12
			for _, beam in lasers do
				local i = beam:GetAttribute("Hit") :: number
				local hit = folder:FindFirstChild("LaserHit" .. tostring(i))
				if hit and hit:IsA("BasePart") then
					local ang = t * 1.7 + i * math.pi
					hit.CFrame = CFrame.new(mid + Vector3.new(math.cos(ang) * (room.maxX - room.minX) * 0.4, 0.2, math.sin(ang * 1.3) * (room.maxZ - room.minZ) * 0.4))
					if math.random() < 0.05 then
						burst(folder, hit.Position, 15)
					end
				end
			end
		end
	end)
	task.delay(T + 3, function()
		running = false
		for light, c in saved do
			if light.Parent then
				light.Color = c
			end
		end
		cc.Saturation = 0
		cc.Enabled = false
		folder:Destroy()
		gui:Destroy()
	end)
end

function MemeTakeover.isRunning(): boolean
	return running
end

return MemeTakeover

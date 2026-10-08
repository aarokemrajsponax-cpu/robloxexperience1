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
--   stop        whatever is still playing stops

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
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
	local my = token
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "DanceLight"
	cc.Parent = Lighting
	task.spawn(function()
		local started = os.clock()
		local beat = 0
		while token == my and os.clock() - started < seconds do
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
	local my = token
	task.spawn(function()
		local started = os.clock()
		local rng = Random.new()
		while token == my and os.clock() - started < seconds do
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
	local my = token
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
		while token == my and os.clock() - started < seconds do
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
	local my = token
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
			if token ~= my then
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
	local my = token
	local was = h.AutoRotate
	h.AutoRotate = false
	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		if token ~= my or os.clock() - started > seconds or not root.Parent then
			if conn then
				conn:Disconnect()
			end
			h.AutoRotate = was
			return
		end
		root.CFrame = root.CFrame * CFrame.Angles(0, 14 * dt, 0)
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
}

-- Plays one effect (as the server said), or "stop".
function AbuseFX.play(id: string, seconds: number?, origin: Vector3?)
	if id == "stop" then
		token += 1
		local f = (Workspace:FindFirstChild("MaisonLocal") or Workspace):FindFirstChild("AbuseFX")
		if f then
			f:Destroy()
		end
		return
	end
	local fn = PLAYERS[id]
	if fn then
		local s = seconds or (cfg().fxSeconds[id] or 6)
		local ok, err = pcall(function()
			fn(math.clamp(s, 1, 60), origin)
		end)
		if not ok then
			warn("[Maison] effect " .. id .. ": " .. tostring(err))
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
end

return AbuseFX

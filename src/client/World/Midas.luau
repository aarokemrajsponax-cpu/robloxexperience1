--!strict
-- The Golden Transformation: the Midas touch, a Suite spectacle on its owner's screen only.
--
--   The touch       A temple gong. The lights sink low, and a ring of gold runs out across the
--                   floor from where the guest stands: everything it passes turns to gold, the
--                   floors and the walls, the ceilings, every piece of furniture, the fireplace.
--   The splendour   A heavenly choir. Leaves of gold fall through the rooms, gold coins rain from
--                   the ceiling and ring as they land round the guest, shafts of light fall from
--                   above, the fire burns gold, and everything glows.
--   The crowning    A regal fanfare: a crown of gold set with jewels settles on the guest's head
--                   in a whirl of sparks, and they shine.
--   The ending      The gold ebbs back across the rooms to the guest, the coins melt into light,
--                   the crown rises and is gone, and the lights come up as they were.
--
-- Nothing is changed for anyone else: every colour is put back as it was. Every number that shapes
-- it lives in Config.Midas.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Flakes = require(script.Parent.Flakes)
local Sound = require(script.Parent.Parent.Sound)

local Midas = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local GOLD_LIGHT = rgb(255, 224, 146)
local GOLD_DEEP = rgb(142, 100, 36)
local GOLD = rgb(255, 204, 110)
local CONFETTI = { rgb(246, 206, 112), rgb(255, 226, 150), rgb(214, 166, 72), rgb(236, 190, 96), rgb(255, 240, 200) }
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local RING = "rbxasset://textures/particles/forcefield_vortex_main.dds"

local function cfg(): { [string]: any }
	return (Config.data :: any).Midas
end

local function holder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

local function rootOf(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function guestAt(): Vector3?
	local root = rootOf()
	return if root then root.Position else nil
end

local function anchor(parent: Instance, name: string, at: Vector3, size: Vector3?): Part
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
	p.Parent = parent
	return p
end

-- Gold for a colour: its own lightness kept, so the shading of the room still reads.
local function goldOf(c: Color3): Color3
	local lum = 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
	return GOLD_DEEP:Lerp(GOLD_LIGHT, math.clamp(lum * 1.5 + 0.18, 0, 1))
end

type Saved = { part: BasePart, color: Color3, material: Enum.Material, reflectance: number, distance: number }
type Lamp = { light: Light, color: Color3, brightness: number }

-- Everything in the Suite (its rooms, and this guest's furniture), nearest to `from` first.
local function gather(from: Vector3): ({ Saved }, { Lamp })
	local parts: { Saved } = {}
	local lamps: { Lamp } = {}
	local roots: { Instance } = {}
	local maison = Workspace:FindFirstChild("Maison")
	local shell = maison and maison:FindFirstChild("Suite")
	if shell then
		table.insert(roots, shell)
	end
	local mine = holder():FindFirstChild("Suite")
	if mine then
		table.insert(roots, mine)
	end
	-- (The Suite's front doors stand in the Club hall: they stay as they are.)
	local doors = shell and shell:FindFirstChild("SuiteDoors")
	for _, r in roots do
		for _, d in r:GetDescendants() do
			if doors and d:IsDescendantOf(doors) then
				continue
			end
			if d:IsA("BasePart") then
				if d.Transparency < 0.9 and d.Material ~= Enum.Material.Neon then
					table.insert(parts, { part = d, color = d.Color, material = d.Material, reflectance = d.Reflectance, distance = (d.Position - from).Magnitude })
				end
			elseif d:IsA("Light") then
				table.insert(lamps, { light = d, color = d.Color, brightness = d.Brightness })
			end
		end
	end
	table.sort(parts, function(a, b)
		return a.distance < b.distance
	end)
	return parts, lamps
end

local function gild(s: Saved)
	local p = s.part
	if p.Parent == nil then
		return
	end
	p.Color = goldOf(s.color)
	if s.material ~= Enum.Material.Glass then
		p.Material = Enum.Material.Metal
		p.Reflectance = math.max(s.reflectance, cfg().reflectance)
	end
end

local function ungild(s: Saved)
	local p = s.part
	if p.Parent == nil then
		return
	end
	p.Color = s.color
	p.Material = s.material
	p.Reflectance = s.reflectance
end

-- Runs `touch` on each part as a ring spreading at `speed` reaches it (or, `inward`, as it ebbs
-- back from the furthest); `spark` is told where the ring is touching now and then.
local function wave(list: { Saved }, speed: number, inward: boolean, touch: (Saved) -> (), spark: (Vector3) -> ()): number
	local far = if #list > 0 then list[#list].distance else 0
	local seconds = far / speed
	local t0 = os.clock()
	local i = if inward then #list else 1
	local lastSpark = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		local reach = if inward then far - t * speed else t * speed
		local touched: Vector3? = nil
		if inward then
			while i >= 1 and list[i].distance >= reach do
				touch(list[i])
				touched = list[i].part.Position
				i -= 1
			end
		else
			while i <= #list and list[i].distance <= reach do
				touch(list[i])
				touched = list[i].part.Position
				i += 1
			end
		end
		if touched and t - lastSpark > 0.05 then
			lastSpark = t
			spark(touched)
		end
		if (inward and i < 1) or (not inward and i > #list) then
			local c = connection
			if c then
				c:Disconnect()
			end
		end
	end)
	return seconds
end

-- The flat ring of light running out across the floor.
local function floorRing(parent: Instance, at: Vector3, radius: number, seconds: number)
	local p = anchor(parent, "MidasRing", at + Vector3.new(0, 0.2, 0))
	local e = Instance.new("ParticleEmitter")
	e.Texture = RING
	e.Rate = 0
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.EmissionDirection = Enum.NormalId.Top
	e.Speed = NumberRange.new(0.01)
	e.SpreadAngle = Vector2.new(0, 0)
	e.Lifetime = NumberRange.new(seconds)
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, radius * 2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Color = ColorSequence.new(rgb(255, 250, 230), GOLD)
	e.Parent = p
	e:Emit(1)
	task.delay(seconds + 0.5, function()
		p:Destroy()
	end)
end

-- Sparks where the gold is spreading.
local function sparker(parent: Instance): (Vector3) -> ()
	local p = anchor(parent, "MidasSparks", Vector3.zero)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Rate = 0
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Acceleration = Vector3.new(0, -4, 0)
	e.Drag = 1.5
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(rgb(255, 255, 240), GOLD)
	e.Parent = p
	return function(at: Vector3)
		p.CFrame = CFrame.new(at)
		e:Emit(5)
	end
end

-- Coins of gold raining from the ceiling, each bouncing to rest on the floor round the guest.
local function coins(parent: Instance, seconds: number): { BasePart }
	local landed: { BasePart } = {}
	local S = Layout.Suite
	local ceiling = S.floorY + S.height - 1
	local params = RaycastParams.new()
	pcall(function()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { parent, player.Character :: Instance }
	end)
	local total = math.floor(cfg().coins)
	local gap = seconds / math.max(1, total)
	task.spawn(function()
		for i = 1, total do
			local centre = guestAt()
			if not centre or parent.Parent == nil then
				break
			end
			local a = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * cfg().coinRadius
			local x, z = centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r
			local floorY = S.floorY
			local hit = Workspace:Raycast(Vector3.new(x, ceiling, z), Vector3.new(0, -(ceiling - S.floorY) - 4, 0), params)
			if hit then
				floorY = hit.Position.Y
			end
			local coin = Instance.new("Part")
			coin.Name = "Coin"
			coin.Shape = Enum.PartType.Cylinder
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = false
			coin.CanTouch = false
			coin.Size = Vector3.new(0.16, 0.8, 0.8)
			coin.Material = Enum.Material.Metal
			coin.Reflectance = 0.5
			coin.Color = if i % 3 == 0 then rgb(236, 186, 82) else rgb(255, 214, 120)
			local yaw = math.random() * math.pi * 2
			-- (A cylinder's round faces are on its X axis: turned 90 degrees, it lies flat.)
			local flat = CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(90))
			coin.CFrame = CFrame.new(x, ceiling, z) * CFrame.Angles(math.random() * 6, yaw, math.random() * 6)
			coin.Parent = parent
			local fall = 1.2 + math.random() * 0.6
			TweenService:Create(coin, TweenInfo.new(fall, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = CFrame.new(x, floorY + 0.08, z) * flat }):Play()
			table.insert(landed, coin)
			if i % 3 == 0 then
				task.delay(fall * 0.55, function()
					pcall(Sound.play, "coinDrop", 0.45, 0.9 + math.random() * 0.3)
				end)
			end
			task.wait(gap)
		end
	end)
	return landed
end

-- Shafts of light falling from the ceiling round the guest, swaying slowly.
local function shafts(parent: Instance, seconds: number)
	local S = Layout.Suite
	local ceiling = S.floorY + S.height - 0.5
	local beams: { { top: Part, floor: Part, beam: Beam, phase: number } } = {}
	for i = 1, cfg().shafts do
		local top = anchor(parent, "ShaftTop", Vector3.zero)
		local floorMark = anchor(parent, "ShaftFloor", Vector3.zero)
		local a0 = Instance.new("Attachment")
		a0.Parent = top
		local a1 = Instance.new("Attachment")
		a1.Parent = floorMark
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.FaceCamera = true
		beam.Width0 = 2
		beam.Width1 = 7
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Segments = 1
		beam.Color = ColorSequence.new(rgb(255, 238, 190), GOLD)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.62), NumberSequenceKeypoint.new(1, 0.9) })
		beam.Parent = top
		table.insert(beams, { top = top, floor = floorMark, beam = beam, phase = i / cfg().shafts * math.pi * 2 })
	end
	local t = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local centre = guestAt()
		if centre then
			for _, b in beams do
				local a = b.phase + t * 0.25
				local top = Vector3.new(centre.X + math.cos(a) * 9, ceiling, centre.Z + math.sin(a) * 9)
				b.top.CFrame = CFrame.new(top)
				b.floor.CFrame = CFrame.new(centre.X + math.cos(a) * 6, S.floorY, centre.Z + math.sin(a) * 6)
			end
		end
		if t >= seconds then
			local c = connection
			if c then
				c:Disconnect()
			end
			for _, b in beams do
				TweenService:Create(b.beam, TweenInfo.new(1.5), { Width0 = 0, Width1 = 0 }):Play()
			end
		end
	end)
end

-- A crown of gold set with jewels, over the guest's head; it settles in a whirl of sparks.
local function crown(parent: Instance, seconds: number)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local model = Instance.new("Model")
	model.Name = "MidasCrown"
	model.Parent = parent
	local parts: { { part: Part, offset: CFrame } } = {}
	local function piece(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.Material = material
		p.Reflectance = if material == Enum.Material.Metal then 0.45 else 0.2
		p.Color = colour
		p.Parent = model
		table.insert(parts, { part = p, offset = offset })
	end
	local r = 0.62
	local n = 12
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local at = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)
		piece("Band", Vector3.new(2 * r * math.tan(math.pi / n) + 0.02, 0.32, 0.08), at, GOLD, Enum.Material.Metal)
		if i % 2 == 0 then
			piece("Point", Vector3.new(0.12, 0.42, 0.06), at * CFrame.new(0, 0.36, 0), GOLD, Enum.Material.Metal)
			piece("Pearl", Vector3.new(0.14, 0.14, 0.14), at * CFrame.new(0, 0.6, 0), rgb(250, 246, 236), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			local jewel = if (i // 2) % 3 == 0 then rgb(200, 20, 40) elseif (i // 2) % 3 == 1 then rgb(30, 80, 220) else rgb(30, 170, 90)
			piece("Jewel", Vector3.new(0.16, 0.16, 0.16), at * CFrame.new(0, 0, -0.05), jewel, Enum.Material.Glass, Enum.PartType.Ball)
		end
	end
	local whirl = Instance.new("Part")
	whirl.Name = "Whirl"
	whirl.Anchored = true
	whirl.CanCollide = false
	whirl.CanQuery = false
	whirl.Transparency = 1
	whirl.Size = Vector3.new(1.4, 0.2, 1.4)
	whirl.Parent = model
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Rate = 50
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(rgb(255, 250, 230), GOLD)
	e.Parent = whirl
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Brightness = 1.2
	glow.Range = 10
	glow.Parent = whirl
	local aura = Instance.new("Highlight")
	aura.FillColor = GOLD
	aura.FillTransparency = 0.82
	aura.OutlineColor = rgb(255, 226, 150)
	aura.OutlineTransparency = 0.25
	aura.Adornee = character
	aura.Parent = parent
	local t = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		if head.Parent == nil or model.Parent == nil then
			local c = connection
			if c then
				c:Disconnect()
			end
			return
		end
		-- Down from above in the first two seconds; up and away in the last two.
		local settle = math.clamp(t / 2, 0, 1)
		local lift = math.clamp((t - (seconds - 2)) / 2, 0, 1)
		local height = 0.85 + (1 - settle) ^ 2 * 3.5 + lift * 6
		local spin = (1 - settle) * t * 6 + lift * t * 4
		local base = CFrame.new(head.Position + Vector3.new(0, height, 0)) * CFrame.Angles(0, spin, 0)
		for _, pt in parts do
			pt.part.CFrame = base * pt.offset
			pt.part.Transparency = lift
		end
		whirl.CFrame = base
		e.Rate = if settle < 1 or lift > 0 then 60 else 8
		if t >= seconds then
			local c = connection
			if c then
				c:Disconnect()
			end
			model:Destroy()
			aura:Destroy()
		end
	end)
end

-- The fire burns gold (and higher) while the room is gold.
local function goldenFire(seconds: number)
	local maison = Workspace:FindFirstChild("Maison")
	local suite = maison and maison:FindFirstChild("Suite")
	local fireplace = suite and suite:FindFirstChild("Fireplace")
	local core = fireplace and fireplace:FindFirstChild("FireCore")
	if not core then
		return
	end
	local saved: { { e: ParticleEmitter, colour: ColorSequence, rate: number } } = {}
	for _, d in core:GetChildren() do
		if d:IsA("ParticleEmitter") then
			table.insert(saved, { e = d, colour = d.Color, rate = d.Rate })
			d.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 250, 220)), ColorSequenceKeypoint.new(0.4, GOLD), ColorSequenceKeypoint.new(1, rgb(200, 130, 40)) })
			d.Rate = d.Rate * 1.8
		end
	end
	task.delay(seconds, function()
		for _, s in saved do
			if s.e.Parent then
				s.e.Color = s.colour
				s.e.Rate = s.rate
			end
		end
	end)
end

local busyUntil = 0

-- Plays the transformation, `seconds` long (one after another if two are played together).
function Midas.play(seconds: number)
	local now = os.clock()
	local wait = math.max(0, busyUntil - now)
	busyUntil = now + wait + seconds + 2
	task.delay(wait, function()
		local from = guestAt()
		if not from then
			return
		end
		local c = cfg()
		local stage = Instance.new("Folder")
		stage.Name = "MidasTouch"
		stage.Parent = holder()
		local parts, lamps = gather(from)
		local spark = sparker(stage)
		-- The touch: a gong; the lights sink; the ring of gold runs out across the floor.
		pcall(Sound.play, "gong", 0.9)
		for _, l in lamps do
			TweenService:Create(l.light, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Brightness = l.brightness * 0.35 }):Play()
		end
		local stopScore = Sound.score(c.choir, c.choirVolume)
		local spread = wave(parts, c.speed, false, gild, spark)
		floorRing(stage, from, c.speed * math.min(spread, 6), math.min(spread, 6))
		for k = 0, 2 do
			task.delay(k * math.max(1, spread / 3), function()
				pcall(Sound.play, "shimmerFall", 0.7, 1 + k * 0.08)
			end)
		end
		-- As the gold spreads, the lights come up gold.
		task.delay(math.min(spread, 4), function()
			for _, l in lamps do
				if l.light.Parent then
					TweenService:Create(l.light, TweenInfo.new(2, Enum.EasingStyle.Sine), { Brightness = l.brightness * 1.5, Color = GOLD }):Play()
				end
			end
		end)
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MidasGlow"
		cc.Parent = Lighting
		TweenService:Create(cc, TweenInfo.new(3, Enum.EasingStyle.Sine), { TintColor = rgb(255, 240, 210), Saturation = 0.12, Brightness = 0.03 }):Play()
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		local bloomBase = if bloom then bloom.Intensity else 0
		if bloom then
			TweenService:Create(bloom, TweenInfo.new(3), { Intensity = bloomBase + 0.4 }):Play()
		end
		-- The splendour: gold confetti, coins, shafts of light, a golden fire.
		local splendour = seconds * 0.82 - 2
		Flakes.fall({
			seconds = splendour,
			centre = guestAt,
			colours = CONFETTI,
			material = Enum.Material.Metal,
			reflectance = 0.5,
			size = Vector3.new(0.34, 0.02, 0.18),
			flutter = 3,
			count = c.confetti,
			radius = 28,
			height = Layout.Suite.height - 4,
			fall = 2.2,
		})
		task.delay(2, function()
			coins(stage, seconds * 0.5)
		end)
		shafts(stage, splendour)
		goldenFire(seconds * 0.85)
		-- The crowning, past the middle: a fanfare, and the crown settles.
		task.delay(seconds * 0.5, function()
			pcall(Sound.play, "regalFanfare", 0.8)
			pcall(Sound.play, "bellTree", 0.8)
			crown(stage, seconds * 0.5 - 1)
		end)
		-- The ending: the gold ebbs back to the guest, the coins melt into light.
		task.delay(seconds * 0.82, function()
			pcall(Sound.play, "bellTree", 0.6, 0.9)
			wave(parts, c.speed * 1.6, true, ungild, spark)
			for _, coin in stage:GetChildren() do
				if coin:IsA("BasePart") and coin.Name == "Coin" then
					TweenService:Create(coin, TweenInfo.new(1.6), { Transparency = 1 }):Play()
				end
			end
			for _, l in lamps do
				if l.light.Parent then
					TweenService:Create(l.light, TweenInfo.new(3, Enum.EasingStyle.Sine), { Brightness = l.brightness, Color = l.color }):Play()
				end
			end
			TweenService:Create(cc, TweenInfo.new(3), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0 }):Play()
			if bloom then
				TweenService:Create(bloom, TweenInfo.new(3), { Intensity = bloomBase }):Play()
			end
			stopScore()
		end)
		task.delay(seconds + 1, function()
			-- Whatever the wave didn't reach (a piece rebuilt meanwhile) is put back all the same.
			for _, s in parts do
				ungild(s)
			end
			for _, l in lamps do
				if l.light.Parent then
					l.light.Color = l.color
					l.light.Brightness = l.brightness
				end
			end
			cc:Destroy()
			stage:Destroy()
		end)
	end)
end

return Midas

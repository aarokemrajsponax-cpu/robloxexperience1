--!strict
-- The Golden Transformation: the Midas touch, a Suite spectacle on its owner's screen only, staged
-- like a film in five acts.
--
--   The hush        Black bars close in, the lights sink, a gong: motes of gold spiral in to the
--                   guest from all round, faster and faster, and gather into a small sun before
--                   them. THE MIDAS TOUCH.
--   The touch       The sun bursts. A wall of golden light runs out across the rooms from where the
--                   guest stands and everything it passes flares white-gold and settles into gold:
--                   the floors and the walls, the ceilings, every piece of furniture, the fireplace.
--                   The camera rises to watch it go.
--   The splendour   A heavenly choir. Gold confetti drifts down, gold coins rain from the ceiling
--                   and glint and ring as they land, shafts of light sweep the room with gold dust
--                   flowing down them, the air itself glitters, fountains of gold sparks rise in the
--                   room's corners, the fire burns gold, and the guest's own likeness, cast in
--                   gold, rises out of the floor on a plinth of black marble.
--   The crowning    A fanfare: the bars close in again, a pillar of light falls on the guest with a
--                   follow spot from the ceiling, cold-spark fountains fire up in a ring round them,
--                   a cape of red velvet edged in gold falls on their shoulders and a jewelled crown
--                   settles on their head, the camera looking up at them. ALL HAIL, and their name.
--   The finale      A golden supernova, with the room quaking; then the gold ebbs back across the
--                   rooms, the coins rise as light, the statue crumbles into gold dust and sinks
--                   away, the crown rises and is gone, and the lights come up as they were.
--                   LONG MAY YOU SHINE.
--
-- Nothing is changed for anyone else: every colour is put back as it was. Every number that shapes
-- it lives in Config.Midas; fewer sparks on slower graphics settings, and the camera and the quake
-- keep still with the movement setting turned down.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Flakes = require(script.Parent.Flakes)
local Stagecraft = require(script.Parent.Stagecraft)
local Quality = require(script.Parent.Parent.Quality)
local Sound = require(script.Parent.Parent.Sound)

local Midas = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local GOLD_LIGHT = rgb(255, 224, 146)
local GOLD_DEEP = rgb(142, 100, 36)
local GOLD = rgb(255, 204, 110)
local GOLD_WHITE = rgb(255, 247, 222)
local GOLD_RICH = rgb(226, 160, 52)
local VELVET = rgb(118, 12, 30)
local ERMINE = rgb(232, 224, 210)
local MARBLE = rgb(26, 22, 20)
local CONFETTI = { rgb(246, 206, 112), rgb(255, 226, 150), rgb(214, 166, 72), rgb(236, 190, 96), rgb(255, 240, 200) }
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local RING = "rbxasset://textures/particles/forcefield_vortex_main.dds"
local FLARE = 0.6 -- seconds a part shines white-gold as the light passes, before it settles into gold
local GOLD_TITLE: Stagecraft.TitleLook = { deep = GOLD_RICH, mid = GOLD, light = GOLD_WHITE, ink = rgb(46, 30, 8), kicker = GOLD_LIGHT }

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

local function headOf(): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function guestAt(): Vector3?
	local root = rootOf()
	return if root then root.CFrame.Position else nil
end

-- Which way the guest faces, along the floor.
local function flatLook(root: BasePart): Vector3
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	return if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
end

-- How many sparks: as many as this screen can take (Quality: the graphics level, Glow and
-- sparks, the frame rate).
local function density(): number
	return Quality.level()
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

-- A part of pure light.
local function neon(parent: Instance, name: string, colour: Color3, size: Vector3, at: CFrame, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = colour
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = at
	p.Parent = parent
	return p
end

-- Sparks of gold, for an emitter to shape.
local function sparkle(parent: Instance, name: string?): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	if name then
		e.Name = name
	end
	e.Texture = SPARK
	e.Rate = 0
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(GOLD_WHITE, GOLD)
	e.Parent = parent
	return e
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

-- Runs `touch` on each part as a ring spreading from `origin` at `speed` reaches it (or, `inward`,
-- as it ebbs back from the furthest); `spark` is told where the ring is touching now and then.
-- With `flare`, what the ring has just passed shines white-gold and settles into its gold.
local function wave(list: { Saved }, origin: Vector3, speed: number, inward: boolean, touch: (Saved) -> (), spark: (Vector3) -> (), flare: boolean?): number
	local far = if #list > 0 then list[#list].distance else 0
	local seconds = far / speed
	local t0 = os.clock()
	local i = if inward then #list else 1
	local lastSpark = 0
	local shining: { { s: Saved, t: number, gold: Color3 } } = {}
	-- (A wall or a floor: the spark where the ring meets it, not at its far-off middle.)
	local function at(p: BasePart, reach: number): Vector3
		if p.Size.Magnitude > 12 then
			local out = p.Position - origin
			return if out.Magnitude > 0.01 then origin + out.Unit * reach else p.Position
		end
		return p.Position
	end
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0
		local reach = math.max(0, if inward then far - t * speed else t * speed)
		local touched: Vector3? = nil
		if inward then
			while i >= 1 and list[i].distance >= reach do
				touch(list[i])
				touched = at(list[i].part, reach)
				i -= 1
			end
		else
			while i <= #list and list[i].distance <= reach do
				local s = list[i]
				touch(s)
				if flare and s.part.Parent then
					table.insert(shining, { s = s, t = t, gold = s.part.Color })
					s.part.Color = GOLD_WHITE
				end
				touched = at(s.part, reach)
				i += 1
			end
		end
		if touched and t - lastSpark > 0.05 then
			lastSpark = t
			spark(touched)
		end
		local n = #shining
		local j = 1
		while j <= n do
			local f = shining[j]
			local k = (t - f.t) / FLARE
			if k >= 1 or f.s.part.Parent == nil then
				if f.s.part.Parent then
					f.s.part.Color = f.gold
				end
				shining[j] = shining[n]
				shining[n] = nil
				n -= 1
			else
				f.s.part.Color = GOLD_WHITE:Lerp(f.gold, 1 - (1 - k) * (1 - k))
				j += 1
			end
		end
		if n == 0 and ((inward and i < 1) or (not inward and i > #list)) then
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

-- A wall of golden light running out across the floor from the guest as the gold spreads: a
-- bright edge along the floor under a fainter curtain, both fading as they go.
local function lightWall(parent: Instance, centre: Vector3, floorY: number, speed: number, reach: number)
	local n = math.floor(40 * math.max(0.6, density()))
	local edges: { Part } = {}
	local veils: { Part } = {}
	for i = 1, n do
		edges[i] = neon(parent, "LightEdge", GOLD_WHITE, Vector3.new(0.2, 0.7, 0.2), CFrame.new(centre))
		veils[i] = neon(parent, "LightVeil", GOLD_LIGHT, Vector3.new(0.2, 1, 0.12), CFrame.new(centre))
		edges[i].Transparency = 1
		veils[i].Transparency = 1
	end
	local t = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local r = 1.2 + t * speed
		local k = math.clamp(r / reach, 0, 1)
		if k >= 1 or parent.Parent == nil then
			local c = connection
			if c then
				c:Disconnect()
			end
			for i = 1, n do
				edges[i]:Destroy()
				veils[i]:Destroy()
			end
			return
		end
		local width = 2 * math.pi * r / n * 1.04
		local tall = 7 * (1 - 0.5 * k)
		local fade = k * k
		local middle = Vector3.new(centre.X, floorY, centre.Z)
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			local face = CFrame.lookAt(Vector3.new(centre.X + math.cos(a) * r, floorY, centre.Z + math.sin(a) * r), middle)
			local e = edges[i]
			e.Size = Vector3.new(width, 0.7, 0.2)
			e.CFrame = face + Vector3.new(0, 0.35, 0)
			e.Transparency = 0.15 + 0.85 * fade
			local v = veils[i]
			v.Size = Vector3.new(width, tall, 0.12)
			v.CFrame = face + Vector3.new(0, tall / 2, 0)
			v.Transparency = 0.74 + 0.26 * fade
		end
	end)
end

-- Sparks where the gold is spreading.
local function sparker(parent: Instance): (Vector3) -> ()
	local p = anchor(parent, "MidasSparks", Vector3.zero)
	local e = sparkle(p)
	e.Speed = NumberRange.new(2, 7)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Acceleration = Vector3.new(0, -4, 0)
	e.Drag = 1.5
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	return function(at: Vector3)
		p.CFrame = CFrame.new(at)
		e:Emit(6)
	end
end

-- A burst of gold sparks flung out from `at`.
local function burst(parent: Instance, at: Vector3, n: number, speed: number?)
	if parent.Parent == nil then
		return
	end
	local p = anchor(parent, "Burst", at)
	local top = speed or 24
	local e = sparkle(p)
	e.Lifetime = NumberRange.new(0.9, 1.8)
	e.Speed = NumberRange.new(top * 0.45, top)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 2.2
	e.Acceleration = Vector3.new(0, -7, 0)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	e.Color = ColorSequence.new(GOLD_WHITE, GOLD_RICH)
	e:Emit(math.floor(n * density()))
	task.delay(2.2, function()
		p:Destroy()
	end)
end

-- A ring of light beads opening across the floor.
local function shockwave(parent: Instance, at: Vector3, colour: Color3, reach: number, seconds: number)
	if parent.Parent == nil then
		return
	end
	local beads = 32
	for i = 1, beads do
		local a = (i / beads) * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local b = neon(parent, "Wave", colour, Vector3.new(0.8, 0.8, 0.8), CFrame.new(at + out * 1.5), Enum.PartType.Ball)
		b.Transparency = 0.05
		TweenService:Create(b, TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + out * reach), Transparency = 1, Size = Vector3.new(0.3, 0.3, 0.3) }):Play()
		task.delay(seconds + 0.1, function()
			b:Destroy()
		end)
	end
end

-- The hush: motes of gold spiralling in from all round the guest, faster and faster, gathering
-- into a small sun before them. Returns the sun, for the touch to burst.
type Mote = { part: Part, a: number, r: number, y: number, spin: number }
local function gathering(parent: Instance, seconds: number): Part?
	local root = rootOf()
	if not root then
		return nil
	end
	local function core(): Vector3
		local r = rootOf() or root
		return r.CFrame.Position + flatLook(r) * 1.4 + Vector3.new(0, 0.5, 0)
	end
	local motes: { Mote } = {}
	for i = 1, math.floor(32 * density()) do
		local p = neon(parent, "Mote", if i % 3 == 0 then GOLD_WHITE else GOLD_LIGHT, Vector3.new(0.24, 0.24, 0.24), CFrame.new(core()), Enum.PartType.Ball)
		p.Transparency = 1
		table.insert(motes, { part = p, a = math.random() * math.pi * 2, r = 6 + math.random() * 7, y = math.random() * 9 - 2, spin = (0.9 + math.random() * 1.4) * (if i % 2 == 0 then 1 else -1) })
	end
	local sun = neon(parent, "Sun", GOLD_WHITE, Vector3.new(0.15, 0.15, 0.15), CFrame.new(core()), Enum.PartType.Ball)
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Brightness = 0
	light.Range = 4
	light.Shadows = false
	light.Parent = sun
	local t = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local k = math.clamp(t / seconds, 0, 1)
		local e = k * k * (3 - 2 * k)
		local c = core()
		for _, m in motes do
			local a = m.a + t * m.spin * (1 + 3 * k)
			local r = m.r * (1 - e)
			m.part.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, m.y * (1 - e), math.sin(a) * r))
			m.part.Transparency = math.max(0, 1 - t * 3)
		end
		if sun.Parent then
			sun.CFrame = CFrame.new(c)
			local s = 0.15 + 1.1 * e
			sun.Size = Vector3.new(s, s, s)
			light.Range = 4 + 14 * e
			light.Brightness = 3 * e
		end
		if t >= seconds or parent.Parent == nil then
			local cc = connection
			if cc then
				cc:Disconnect()
			end
			for _, m in motes do
				m.part:Destroy()
			end
		end
	end)
	return sun
end

-- Coins of gold raining from the ceiling, each bouncing to rest on the floor round the guest, with
-- a glint as it lands.
local function coins(parent: Instance, floorY: number, seconds: number)
	local ceiling = floorY + Layout.Suite.height - 1
	local params = RaycastParams.new()
	pcall(function()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { parent, player.Character :: Instance }
	end)
	local total = math.floor(cfg().coins * density())
	local gap = seconds / math.max(1, total)
	local glintAt = anchor(parent, "CoinGlint", Vector3.zero, Vector3.new(0.2, 0.2, 0.2))
	local glint = sparkle(glintAt)
	glint.Lifetime = NumberRange.new(0.25, 0.45)
	glint.Speed = NumberRange.new(0)
	glint.RotSpeed = NumberRange.new(-120, 120)
	glint.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 1.1), NumberSequenceKeypoint.new(1, 0) })
	glint.Color = ColorSequence.new(GOLD_WHITE)
	task.spawn(function()
		for i = 1, total do
			local centre = guestAt()
			if not centre or parent.Parent == nil then
				break
			end
			local a = math.random() * math.pi * 2
			local r = math.sqrt(math.random()) * cfg().coinRadius
			local x, z = centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r
			local land = floorY
			local hit = Workspace:Raycast(Vector3.new(x, ceiling, z), Vector3.new(0, -(ceiling - floorY) - 4, 0), params)
			if hit then
				land = hit.Position.Y
			end
			local coin = Instance.new("Part")
			coin.Name = "Coin"
			coin.Shape = Enum.PartType.Cylinder
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = false
			coin.CanTouch = false
			coin.Size = Vector3.new(0.16, 0.85, 0.85)
			coin.Material = Enum.Material.Metal
			coin.Reflectance = 0.5
			coin.Color = if i % 3 == 0 then rgb(236, 186, 82) else rgb(255, 214, 120)
			local yaw = math.random() * math.pi * 2
			-- (A cylinder's round faces are on its X axis: turned 90 degrees, it lies flat.)
			local flat = CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(90))
			coin.CFrame = CFrame.new(x, ceiling, z) * CFrame.Angles(math.random() * 6, yaw, math.random() * 6)
			coin.Parent = parent
			local fall = 1.2 + math.random() * 0.6
			TweenService:Create(coin, TweenInfo.new(fall, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = CFrame.new(x, land + 0.08, z) * flat }):Play()
			if i % 2 == 0 then
				task.delay(fall * 0.55, function()
					if glintAt.Parent then
						glintAt.CFrame = CFrame.new(x, land + 0.35, z)
						glint:Emit(1)
					end
				end)
			end
			if i % 3 == 0 then
				task.delay(fall * 0.55, function()
					pcall(Sound.play, "coinDrop", 0.45, 0.9 + math.random() * 0.3)
				end)
			end
			task.wait(gap)
		end
	end)
end

-- The coins rise as light: each turns to light and floats up as it fades.
local function coinsRise(parent: Instance)
	for _, coin in parent:GetChildren() do
		if coin:IsA("BasePart") and coin.Name == "Coin" then
			task.delay(math.random() * 0.9, function()
				if coin.Parent == nil then
					return
				end
				coin.Material = Enum.Material.Neon
				coin.Color = GOLD_LIGHT
				TweenService:Create(coin, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
					CFrame = coin.CFrame + Vector3.new(0, 3.5, 0),
					Transparency = 1,
				}):Play()
			end)
		end
	end
end

-- Shafts of light falling from the ceiling round the guest, swaying slowly, gold dust flowing
-- down each.
type Shaft = { top: Part, floor: Part, glow: Beam, dust: Beam, phase: number, reach: number }
local function shafts(parent: Instance, floorY: number, seconds: number)
	local ceiling = floorY + Layout.Suite.height - 0.5
	local count = math.max(0, math.floor(cfg().shafts))
	local list: { Shaft } = {}
	for i = 1, count do
		local top = anchor(parent, "ShaftTop", Vector3.zero)
		local floorMark = anchor(parent, "ShaftFloor", Vector3.zero)
		local a0 = Instance.new("Attachment")
		a0.Parent = top
		local a1 = Instance.new("Attachment")
		a1.Parent = floorMark
		local glow = Instance.new("Beam")
		glow.Attachment0 = a0
		glow.Attachment1 = a1
		glow.FaceCamera = true
		glow.Width0 = 0
		glow.Width1 = 0
		glow.LightEmission = 1
		glow.LightInfluence = 0
		glow.Segments = 1
		glow.Color = ColorSequence.new(rgb(255, 238, 190), GOLD)
		glow.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.62), NumberSequenceKeypoint.new(1, 0.9) })
		glow.Parent = top
		local dust = Instance.new("Beam")
		dust.Attachment0 = a0
		dust.Attachment1 = a1
		dust.FaceCamera = true
		dust.Width0 = 0
		dust.Width1 = 0
		dust.LightEmission = 1
		dust.LightInfluence = 0
		dust.Segments = 1
		dust.Texture = SPARK
		dust.TextureMode = Enum.TextureMode.Wrap
		dust.TextureLength = 2.5
		dust.TextureSpeed = 0.35
		dust.Color = ColorSequence.new(GOLD_WHITE)
		dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.85) })
		dust.Parent = top
		TweenService:Create(glow, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { Width0 = 2.4, Width1 = 7.5 }):Play()
		TweenService:Create(dust, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { Width0 = 2, Width1 = 6 }):Play()
		table.insert(list, { top = top, floor = floorMark, glow = glow, dust = dust, phase = i / math.max(1, count) * math.pi * 2, reach = 6 + (i % 3) * 2.5 })
	end
	local t = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		if parent.Parent == nil then
			local c = connection
			if c then
				c:Disconnect()
			end
			return
		end
		local centre = guestAt()
		if centre then
			for _, s in list do
				local a = s.phase + t * 0.22
				s.top.CFrame = CFrame.new(centre.X + math.cos(a) * (s.reach + 2.5), ceiling, centre.Z + math.sin(a) * (s.reach + 2.5))
				s.floor.CFrame = CFrame.new(centre.X + math.cos(a) * s.reach, floorY, centre.Z + math.sin(a) * s.reach)
			end
		end
		if t >= seconds then
			local c = connection
			if c then
				c:Disconnect()
			end
			for _, s in list do
				TweenService:Create(s.glow, TweenInfo.new(1.5), { Width0 = 0, Width1 = 0 }):Play()
				TweenService:Create(s.dust, TweenInfo.new(1.5), { Width0 = 0, Width1 = 0 }):Play()
			end
		end
	end)
end

-- The air itself glitters: gold dust twinkling all through the room.
local function goldDust(parent: Instance, room: Stagecraft.Box, floorY: number): ParticleEmitter
	local h = Layout.Suite.height - 2
	local p = anchor(parent, "GoldDust", Vector3.new((room.minX + room.maxX) / 2, floorY + 1 + h / 2, (room.minZ + room.maxZ) / 2), Vector3.new(room.maxX - room.minX, h, room.maxZ - room.minZ))
	local e = sparkle(p)
	e.Rate = (tonumber(cfg().dust) or 30) * density()
	e.Lifetime = NumberRange.new(2.5, 4.5)
	e.Speed = NumberRange.new(0.1, 0.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, 0.12, 0)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.24), NumberSequenceKeypoint.new(1, 0) })
	return e
end

-- Fountains of gold sparks rising from pools of light in the room's corners.
local function fountains(parent: Instance, room: Stagecraft.Box, floorY: number): { ParticleEmitter }
	local out: { ParticleEmitter } = {}
	local inset = 3.2
	local corners = {
		Vector3.new(room.minX + inset, floorY, room.minZ + inset),
		Vector3.new(room.maxX - inset, floorY, room.maxZ - inset),
		Vector3.new(room.maxX - inset, floorY, room.minZ + inset),
		Vector3.new(room.minX + inset, floorY, room.maxZ - inset),
	}
	for i = 1, math.clamp(math.floor(tonumber(cfg().fountains) or 4), 0, 4) do
		local at = corners[i]
		task.delay((i - 1) * 0.3, function()
			if parent.Parent == nil then
				return
			end
			local pool = neon(parent, "GoldPool", GOLD, Vector3.new(0.12, 2.6, 2.6), CFrame.new(at + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
			pool.Transparency = 1
			TweenService:Create(pool, TweenInfo.new(0.8), { Transparency = 0.35 }):Play()
			local l = Instance.new("PointLight")
			l.Color = GOLD
			l.Brightness = 1.8
			l.Range = 14
			l.Shadows = false
			l.Parent = pool
			local jet = anchor(parent, "GoldFountain", at + Vector3.new(0, 0.4, 0), Vector3.new(0.6, 0.2, 0.6))
			local e = sparkle(jet)
			e.EmissionDirection = Enum.NormalId.Top
			e.Rate = 42 * density()
			e.Lifetime = NumberRange.new(1.5, 2)
			e.Speed = NumberRange.new(19, 26)
			e.SpreadAngle = Vector2.new(9, 9)
			e.Acceleration = Vector3.new(0, -30, 0)
			e.Drag = 0.4
			e.RotSpeed = NumberRange.new(-180, 180)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(0.7, 0.26), NumberSequenceKeypoint.new(1, 0) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) })
			e.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GOLD_WHITE), ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(1, GOLD_RICH) })
			table.insert(out, e)
		end)
	end
	return out
end

-- The guest's own likeness cast in gold: a copy of them as they stand (their clothes, face and
-- every texture taken off, every part gold), on a plinth of black marble banded in gold, rising
-- out of the floor before them and a little to one side, wherever there's room, and turning a
-- little this way and that. Returns where it stands (if it does) and what crumbles it at the end.
local function likeness(parent: Instance, floorY: number): (Vector3?, () -> ())
	local none = function() end
	local character = player.Character
	local root = rootOf()
	if cfg().statue == false or not character or not root then
		return nil, none
	end
	-- Where: the first way with room enough, looking from the guest.
	local look = flatLook(root)
	local params = RaycastParams.new()
	pcall(function()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { parent, character }
	end)
	local eye = Vector3.new(root.CFrame.Position.X, floorY + 3, root.CFrame.Position.Z)
	local best, bestRoom = look, -1
	for _, deg in { 35, -35, 75, -75, 0, 140, -140 } do
		local dir = CFrame.Angles(0, math.rad(deg), 0) * look
		local ok, hit = pcall(function()
			return Workspace:Raycast(eye, dir * 11, params)
		end)
		local room = if ok and hit then (hit.Position - eye).Magnitude else 11
		if room > bestRoom then
			best, bestRoom = dir, room
		end
		if room >= 9 then
			break
		end
	end
	if bestRoom < 4.5 then
		return nil, none
	end
	local spot = Vector3.new(root.CFrame.Position.X, floorY, root.CFrame.Position.Z) + best * math.min(6.5, bestRoom - 2.5)
	-- The copy, stripped and gilded.
	local was = character.Archivable
	local ok, copy = pcall(function(): Instance?
		character.Archivable = true
		return character:Clone()
	end)
	pcall(function()
		character.Archivable = was
	end)
	if not ok or not copy then
		return nil, none
	end
	if not copy:IsA("Model") then
		copy:Destroy()
		return nil, none
	end
	local statue = copy :: Model
	statue.Name = "Likeness"
	local stripped = pcall(function()
		local drop: { Instance } = {}
		for _, d in statue:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			elseif d:IsA("WrapLayer") then
				table.insert(drop, d:FindFirstAncestorOfClass("Accessory") or d)
			elseif
				d:IsA("Humanoid")
				or d:IsA("LuaSourceContainer")
				or d:IsA("Sound")
				or d:IsA("Decal")
				or d:IsA("Clothing")
				or d:IsA("ShirtGraphic")
				or d:IsA("BodyColors")
				or d:IsA("SurfaceAppearance")
				or d:IsA("ParticleEmitter")
				or d:IsA("Trail")
				or d:IsA("Beam")
				or d:IsA("Light")
				or d:IsA("LayerCollector")
				or d:IsA("Highlight")
				or d:IsA("ForceField")
				or d:IsA("JointInstance")
				or d:IsA("ProximityPrompt")
			then
				table.insert(drop, d)
			end
		end
		for _, d in drop do
			d:Destroy()
		end
		for _, d in statue:GetDescendants() do
			if d:IsA("BasePart") then
				if d.Name == "HumanoidRootPart" or d.Transparency > 0.95 then
					d.Transparency = 1
				else
					d.Material = Enum.Material.Metal
					d.Reflectance = 0.32
					d.Color = goldOf(d.Color):Lerp(GOLD, 0.45)
					d.CastShadow = true
					if d:IsA("MeshPart") then
						pcall(function()
							(d :: MeshPart).TextureID = ""
						end)
					end
				end
			elseif d:IsA("SpecialMesh") then
				pcall(function()
					(d :: SpecialMesh).TextureId = ""
				end)
			end
		end
	end)
	if not stripped then
		statue:Destroy()
		return nil, none
	end
	pcall(function()
		statue:ScaleTo(tonumber(cfg().statueScale) or 1.25)
	end)
	-- The plinth, and the statue stood on it facing the guest.
	local monument = Instance.new("Model")
	monument.Name = "MidasStatue"
	local pivot = anchor(monument, "Pivot", spot, Vector3.new(0.2, 0.2, 0.2))
	monument.PrimaryPart = pivot
	local function disc(name: string, height: number, diameter: number, y: number, colour: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = Enum.PartType.Cylinder
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = Vector3.new(height, diameter, diameter)
		p.CFrame = CFrame.new(spot + Vector3.new(0, y + height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Material = material
		p.Color = colour
		p.Reflectance = if material == Enum.Material.Metal then 0.35 else 0.08
		p.Parent = monument
		return p
	end
	disc("PlinthFoot", 0.45, 3.6, 0, MARBLE, Enum.Material.Marble)
	disc("PlinthBand", 0.12, 3.3, 0.45, GOLD, Enum.Material.Metal)
	disc("Plinth", 1.6, 3, 0.57, MARBLE, Enum.Material.Marble)
	local cap = disc("PlinthTop", 0.3, 3.4, 2.17, GOLD, Enum.Material.Metal)
	local top = 2.47
	local light = Instance.new("PointLight")
	light.Color = GOLD_LIGHT
	light.Brightness = 1.6
	light.Range = 12
	light.Shadows = false
	light.Parent = cap
	local height = 6
	local placed = pcall(function()
		local box, size = statue:GetBoundingBox()
		local from = statue:GetPivot()
		local lift = from.Position.Y - (box.Position.Y - size.Y / 2)
		local facing = CFrame.lookAt(spot, Vector3.new(root.CFrame.Position.X, spot.Y, root.CFrame.Position.Z))
		statue:PivotTo(facing.Rotation + Vector3.new(spot.X, spot.Y + top + lift, spot.Z))
		height = math.max(2, size.Y)
	end)
	if not placed then
		statue:Destroy()
		monument:Destroy()
		return nil, none
	end
	statue.Parent = monument
	local glints = anchor(monument, "Glints", spot + Vector3.new(0, top + height / 2, 0), Vector3.new(2.4, height, 2.4))
	local g = sparkle(glints)
	g.Rate = 8 * density()
	g.Lifetime = NumberRange.new(0.5, 0.9)
	g.Speed = NumberRange.new(0)
	g.RotSpeed = NumberRange.new(-90, 90)
	g.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.7), NumberSequenceKeypoint.new(1, 0) })
	local dust = anchor(monument, "RiseDust", spot + Vector3.new(0, 0.2, 0), Vector3.new(3.4, 0.2, 3.4))
	local d = sparkle(dust)
	d.EmissionDirection = Enum.NormalId.Top
	d.Rate = 60 * density()
	d.Lifetime = NumberRange.new(0.8, 1.4)
	d.Speed = NumberRange.new(2, 5)
	d.SpreadAngle = Vector2.new(80, 80)
	d.Acceleration = Vector3.new(0, -3, 0)
	d.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	-- Up out of the floor (all of it, then turning gently while it stands).
	local sink = top + height + 0.6
	monument.Parent = parent
	monument:PivotTo(CFrame.new(spot - Vector3.new(0, sink, 0)))
	local t = 0
	local fall: number? = nil
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		if monument.Parent == nil then
			local c = connection
			if c then
				c:Disconnect()
			end
			return
		end
		local rise = math.clamp(t / 3, 0, 1)
		local up = 1 - (1 - rise) ^ 3
		local down = if fall then math.clamp((t - fall) / 1.8, 0, 1) ^ 2 * (top + 0.6) else 0
		if rise >= 1 and d.Rate > 0 then
			d.Rate = 0
		end
		-- (The statue never moves the plinth's dust: that one stays on the floor.)
		monument:PivotTo(CFrame.new(spot - Vector3.new(0, sink * (1 - up) + down, 0)) * CFrame.Angles(0, math.sin(t * 0.35) * 0.45, 0))
		dust.CFrame = CFrame.new(spot + Vector3.new(0, 0.2, 0))
	end)
	-- The end: it crumbles into gold dust from the head down, and the plinth sinks away.
	return spot, function()
		if monument.Parent == nil then
			return
		end
		g.Rate = 0
		d:Emit(math.floor(160 * density()))
		local bottom = spot.Y + top
		for _, part in statue:GetDescendants() do
			if part:IsA("BasePart") and part.Transparency < 1 then
				local h = math.clamp((part.CFrame.Position.Y - bottom) / height, 0, 1)
				task.delay((1 - h) * 0.7, function()
					if part.Parent then
						TweenService:Create(part, TweenInfo.new(0.9), { Transparency = 1 }):Play()
					end
				end)
			end
		end
		fall = t + 1.2
	end
end

-- A pillar of light falling on the guest: a shimmering shell of gold from floor to ceiling (a
-- veil, never a glare: the guest, the cape and the crown show through it), a soft pool of light at
-- their feet, a follow spot from the ceiling and sparks rising round them.
local function pillar(parent: Instance, floorY: number, seconds: number)
	local h = Layout.Suite.height
	local column = neon(parent, "Pillar", GOLD_LIGHT, Vector3.new(h, 5.5, 5.5), CFrame.new(), Enum.PartType.Cylinder)
	column.Material = Enum.Material.ForceField
	column.Transparency = 1
	local pool = neon(parent, "PillarPool", GOLD_WHITE, Vector3.new(0.1, 4.4, 4.4), CFrame.new(), Enum.PartType.Cylinder)
	pool.Transparency = 1
	local lamp = anchor(parent, "FollowSpot", Vector3.zero, Vector3.new(0.4, 0.4, 0.4))
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Bottom
	spot.Angle = 32
	spot.Range = math.min(60, h + 8)
	spot.Brightness = 0
	spot.Color = GOLD_WHITE
	spot.Shadows = true
	spot.Parent = lamp
	local rising = anchor(parent, "PillarSparks", Vector3.zero, Vector3.new(4, 0.2, 4))
	local e = sparkle(rising)
	e.EmissionDirection = Enum.NormalId.Top
	e.Speed = NumberRange.new(5, 11)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
	local dense = density()
	local t = 0
	local connection: RBXScriptConnection? = nil
	connection = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		local centre = guestAt()
		if parent.Parent == nil or t >= seconds then
			local c = connection
			if c then
				c:Disconnect()
			end
			column:Destroy()
			pool:Destroy()
			lamp:Destroy()
			rising:Destroy()
			return
		end
		local k = math.clamp(t / 0.6, 0, 1) * (1 - math.clamp((t - (seconds - 1.5)) / 1.5, 0, 1))
		if centre then
			local upright = CFrame.Angles(0, 0, math.rad(90))
			column.CFrame = CFrame.new(centre.X, floorY + h / 2, centre.Z) * upright
			pool.CFrame = CFrame.new(centre.X, floorY + 0.06, centre.Z) * upright
			lamp.CFrame = CFrame.new(centre.X, floorY + h - 0.6, centre.Z)
			rising.CFrame = CFrame.new(centre.X, floorY + 0.2, centre.Z)
		end
		column.Transparency = 1 - 0.65 * k
		pool.Transparency = 1 - 0.3 * k
		spot.Brightness = 3.5 * k
		e.Rate = 45 * dense * k
	end)
end

-- Cold-spark fountains firing up in a ring round the guest, one after another (none where the
-- statue stands).
local function sparkRing(parent: Instance, centre: Vector3, floorY: number, avoid: Vector3?, seconds: number)
	local n = math.clamp(math.floor(tonumber(cfg().sparkMachines) or 8), 0, 12)
	local dense = density()
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local at = Vector3.new(centre.X + math.cos(a) * 5.5, floorY, centre.Z + math.sin(a) * 5.5)
		if avoid and (Vector3.new(avoid.X, floorY, avoid.Z) - at).Magnitude < 2.8 then
			continue
		end
		task.delay(i * 0.12, function()
			if parent.Parent == nil then
				return
			end
			local box = Instance.new("Part")
			box.Name = "SparkMachine"
			box.Anchored = true
			box.CanCollide = false
			box.CanQuery = false
			box.CanTouch = false
			box.Size = Vector3.new(0.8, 0.45, 0.8)
			box.Material = Enum.Material.Metal
			box.Color = rgb(28, 26, 30)
			box.CFrame = CFrame.new(at + Vector3.new(0, 0.225, 0))
			box.Parent = parent
			neon(parent, "SparkNozzle", GOLD_WHITE, Vector3.new(0.3, 0.06, 0.3), CFrame.new(at + Vector3.new(0, 0.48, 0)))
			local e = sparkle(box)
			e.EmissionDirection = Enum.NormalId.Top
			e.Speed = NumberRange.new(15, 21)
			e.SpreadAngle = Vector2.new(4, 4)
			e.Lifetime = NumberRange.new(0.8, 1.15)
			e.Acceleration = Vector3.new(0, -14, 0)
			e.Rate = 34 * dense
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
			task.delay(seconds, function()
				e.Rate = 0
			end)
		end)
	end
	pcall(Sound.play, "fireworkHiss", 0.35)
end

-- A royal cape of red velvet edged in gold, with an ermine collar, on the guest's shoulders:
-- welded to them, weightless, touching nothing. Returns its parts, to fade them.
local function cape(parent: Instance): { BasePart }
	local character = player.Character
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	if cfg().cape == false or not torso or not torso:IsA("BasePart") then
		return {}
	end
	local body = torso :: BasePart
	local T = body.Size
	local H = T.Y * (if body.Name == "UpperTorso" then 1.85 else 1.45)
	local wC, wS = T.X * 0.72, T.X * 0.34
	local hinge = body.CFrame * CFrame.new(0, T.Y / 2 - 0.08, T.Z / 2 + 0.07) * CFrame.Angles(math.rad(-9), 0, 0)
	local parts: { BasePart } = {}
	local function piece(name: string, size: Vector3, at: CFrame, colour: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = at
		p.Color = colour
		p.Material = material
		p.Transparency = 1
		p.Parent = parent
		local w = Instance.new("WeldConstraint")
		w.Part0 = p
		w.Part1 = body
		w.Parent = p
		table.insert(parts, p)
		return p
	end
	piece("Cape", Vector3.new(wC, H, 0.1), hinge * CFrame.new(0, -H / 2, 0), VELVET, Enum.Material.Fabric)
	piece("CapeHem", Vector3.new(wC, 0.2, 0.14), hinge * CFrame.new(0, -H + 0.1, 0), GOLD, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		local edge = hinge * CFrame.new(side * wC / 2, -H / 2, 0) * CFrame.Angles(0, side * math.rad(28), 0)
		piece("Cape", Vector3.new(wS, H * 0.97, 0.1), edge * CFrame.new(side * wS / 2, 0, 0), VELVET, Enum.Material.Fabric)
		piece("CapeEdge", Vector3.new(0.14, H * 0.97, 0.14), edge * CFrame.new(side * wS, 0, 0), GOLD, Enum.Material.Metal)
		piece("CapeHem", Vector3.new(wS, 0.2, 0.14), edge * CFrame.new(side * wS / 2, -H * 0.97 / 2 + 0.1, 0), GOLD, Enum.Material.Metal)
	end
	local collar = piece("Ermine", Vector3.new(T.X * 1.08, 0.36, T.Z * 1.25), body.CFrame * CFrame.new(0, T.Y / 2 - 0.02, 0.06), ERMINE, Enum.Material.Fabric)
	for i = -2, 2 do
		piece("ErmineSpot", Vector3.new(0.07, 0.16, 0.04), collar.CFrame * CFrame.new(i * T.X * 0.2, -0.02, T.Z * 1.25 / 2 + 0.01), rgb(20, 18, 18), Enum.Material.SmoothPlastic)
	end
	for _, p in parts do
		TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Transparency = 0 }):Play()
	end
	return parts
end

-- A crown of gold over the guest's head: a band set with jewels under points tipped with pearls, a
-- cap of red velvet, two arches meeting under an orb of gold and a diamond that glints. It comes
-- down from above in a whirl of sparks and settles, facing the way they face.
type Piece = { part: Part, offset: CFrame }
local function crown(parent: Instance, seconds: number)
	local character = player.Character
	local head = headOf()
	if not character or not head then
		return
	end
	local k = math.clamp(head.Size.X / 1.2, 0.75, 1.6)
	local model = Instance.new("Model")
	model.Name = "MidasCrown"
	model.Parent = parent
	local pieces: { Piece } = {}
	local function piece(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material, shape: Enum.PartType?): Part
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
		p.Size = size * k
		p.Material = material
		p.Reflectance = if material == Enum.Material.Metal then 0.45 else 0.2
		p.Color = colour
		p.Parent = model
		table.insert(pieces, { part = p, offset = CFrame.new(offset.Position * k) * offset.Rotation })
		return p
	end
	local r = 0.66
	local n = 14
	for i = 0, n - 1 do
		local a = i / n * math.pi * 2
		local at = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -r)
		local w = 2 * r * math.tan(math.pi / n) + 0.02
		piece("Band", Vector3.new(w, 0.34, 0.09), at, GOLD, Enum.Material.Metal)
		piece("Lip", Vector3.new(w, 0.07, 0.15), at * CFrame.new(0, -0.17, 0), GOLD_RICH, Enum.Material.Metal)
		if i % 2 == 0 then
			piece("Point", Vector3.new(0.13, 0.44, 0.07), at * CFrame.new(0, 0.38, 0), GOLD, Enum.Material.Metal)
			piece("Pearl", Vector3.new(0.15, 0.15, 0.15), at * CFrame.new(0, 0.64, 0), rgb(250, 246, 236), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			local which = (i // 2) % 3
			local jewel = if which == 0 then rgb(200, 20, 40) elseif which == 1 then rgb(30, 80, 220) else rgb(30, 170, 90)
			local big = if i == 0 then 0.24 else 0.16
			piece("Jewel", Vector3.new(big, big, big), at * CFrame.new(0, 0, -0.05), jewel, Enum.Material.Glass, Enum.PartType.Ball)
		end
	end
	piece("Cap", Vector3.new(2 * r * 0.92, 0.62, 2 * r * 0.92), CFrame.new(0, 0.18, 0), VELVET, Enum.Material.Fabric, Enum.PartType.Ball)
	for _, yaw in { 0, math.pi / 2 } do
		for j = 1, 7 do
			local th = j / 8 * math.pi
			piece("Arch", Vector3.new(0.12, 0.12, 0.12), CFrame.Angles(0, yaw, 0) * CFrame.new(math.cos(th) * r * 0.9, 0.17 + math.sin(th) * 0.62, 0), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
		end
	end
	piece("Orb", Vector3.new(0.26, 0.26, 0.26), CFrame.new(0, 0.9, 0), GOLD, Enum.Material.Metal, Enum.PartType.Ball)
	local diamond = piece("Diamond", Vector3.new(0.15, 0.15, 0.15), CFrame.new(0, 1.09, 0), rgb(225, 240, 255), Enum.Material.Glass, Enum.PartType.Ball)
	local glint = sparkle(diamond, "Glint")
	glint.Rate = 1.5
	glint.Lifetime = NumberRange.new(0.3, 0.45)
	glint.Speed = NumberRange.new(0)
	glint.RotSpeed = NumberRange.new(90)
	glint.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 1.4 * k), NumberSequenceKeypoint.new(1, 0) })
	glint.Color = ColorSequence.new(Color3.new(1, 1, 1))
	local whirl = Instance.new("Part")
	whirl.Name = "Whirl"
	whirl.Anchored = true
	whirl.CanCollide = false
	whirl.CanQuery = false
	whirl.CanTouch = false
	whirl.Transparency = 1
	whirl.Size = Vector3.new(1.4, 0.2, 1.4) * k
	whirl.Parent = model
	local e = sparkle(whirl)
	e.Rate = 50
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.RotSpeed = NumberRange.new(-180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Brightness = 1.2
	glow.Range = 10
	glow.Parent = whirl
	local aura = Instance.new("Highlight")
	aura.FillColor = GOLD
	aura.FillTransparency = 0.85
	aura.OutlineColor = rgb(255, 226, 150)
	aura.OutlineTransparency = 0.3
	aura.Adornee = character
	aura.Parent = parent
	local t = 0
	local shown = 0
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
		local height = head.Size.Y * 0.5 + 0.17 * k + (1 - settle) ^ 2 * 3.5 + lift * 6
		local spin = (1 - settle) * t * 6 + lift * t * 4
		local lv = head.CFrame.LookVector
		local yaw = math.atan2(-lv.X, -lv.Z)
		local base = CFrame.new(head.CFrame.Position + Vector3.new(0, height, 0)) * CFrame.Angles(0, yaw + spin, 0)
		for _, pt in pieces do
			pt.part.CFrame = base * pt.offset
		end
		if lift ~= shown then
			shown = lift
			for _, pt in pieces do
				pt.part.Transparency = lift
			end
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
local live = 0

-- Plays the transformation, `seconds` long (one after another if two are played together).
function Midas.play(seconds: number)
	local now = os.clock()
	local queued = math.max(0, busyUntil - now)
	busyUntil = now + queued + seconds + 2
	task.delay(queued, function()
		local from = guestAt()
		if not from then
			return
		end
		live += 1
		local c = cfg()
		local S = seconds
		local dense = density()
		local floorY = Layout.Suite.floorY
		if math.abs(from.Y - floorY) > 12 then
			floorY = from.Y - 3
		end
		local room = Stagecraft.roomOf(from)
		local HUSH = math.min(1.6, S * 0.06)
		local STATUE = math.min(7.5, S * 0.2)
		local CROWN = S * 0.5
		local NOVA = S * 0.72
		local EBB = S * 0.82
		local stage = Instance.new("Folder")
		stage.Name = "MidasTouch"
		stage.Parent = holder()
		local gui = Instance.new("ScreenGui")
		gui.Name = "MidasTouch"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 35
		gui.Parent = player:WaitForChild("PlayerGui")
		local glare = Instance.new("Frame")
		glare.Name = "Flash"
		glare.BorderSizePixel = 0
		glare.BackgroundColor3 = GOLD_WHITE
		glare.BackgroundTransparency = 1
		glare.Size = UDim2.fromScale(1, 1)
		glare.ZIndex = 15
		glare.Parent = gui
		local function flash(fromTransparency: number, over: number)
			glare.BackgroundTransparency = fromTransparency
			TweenService:Create(glare, TweenInfo.new(over, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		end
		local parts, lamps = gather(from)
		local spark = sparker(stage)
		local jets: { ParticleEmitter } = {}
		local dust: ParticleEmitter? = nil
		local statueAt: Vector3? = nil
		local crumble: () -> () = function() end
		local capeParts: { BasePart } = {}

		-- I. The hush: the bars close in, the lights sink, a gong; the gold gathers.
		Stagecraft.letterbox(gui, true)
		pcall(Sound.play, "gong", 0.9)
		pcall(Sound.play, "magicZoom", 0.55)
		local stopScore = Sound.score(c.choir, c.choirVolume)
		for _, l in lamps do
			TweenService:Create(l.light, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Brightness = l.brightness * 0.25 }):Play()
		end
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "MidasGlow"
		cc.Parent = Lighting
		TweenService:Create(cc, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Brightness = -0.05, Contrast = 0.1, Saturation = -0.1 }):Play()
		local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
		local bloomBase = if bloom then bloom.Intensity else 0
		local okSpec, specBase = pcall(function(): number
			return (Lighting :: any).EnvironmentSpecularScale
		end)
		local sun = gathering(stage, HUSH)
		task.delay(0.35, function()
			Stagecraft.title(gui, "The Golden Transformation", "THE MIDAS TOUCH", 3.4, GOLD_TITLE)
		end)
		task.delay(HUSH + 3.6, function()
			if gui.Parent then
				Stagecraft.letterbox(gui, false)
			end
		end)

		-- II. The touch: the sun bursts and the gold runs out across the rooms.
		task.delay(HUSH, function()
			if stage.Parent == nil then
				return
			end
			if sun and sun.Parent then
				burst(stage, sun.CFrame.Position, 150, 26)
				TweenService:Create(sun, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(7, 7, 7), Transparency = 1 }):Play()
				local l = sun:FindFirstChildOfClass("PointLight")
				if l then
					TweenService:Create(l, TweenInfo.new(1.2), { Brightness = 0, Range = 30 }):Play()
				end
			end
			flash(0.35, 0.9)
			Stagecraft.quake(0.22, 0.6)
			pcall(Sound.play, "subHit", 0.8)
			pcall(Sound.play, "shimmerFall", 0.8)
			local spread = wave(parts, from, c.speed, false, gild, spark, true)
			floorRing(stage, Vector3.new(from.X, floorY, from.Z), c.speed * math.min(spread, 6), math.min(spread, 6))
			lightWall(stage, from, floorY, c.speed, math.min(c.speed * math.max(spread, 2), tonumber(c.wallReach) or 46))
			for k = 1, 2 do
				task.delay(k * math.max(1, spread / 3), function()
					pcall(Sound.play, "shimmerFall", 0.6, 1 + k * 0.08)
				end)
			end
			-- The camera rises behind the guest to watch it go.
			local root = rootOf()
			if root then
				local focus = root.CFrame.Position + Vector3.new(0, 1, 0)
				Stagecraft.shot(focus, focus - flatLook(root) * 8 + Vector3.new(0, 9, 0), 2.2, { stage :: Instance })
			end
			-- The room goes gold: the lamps, the colour, the glow, the shine on the metal.
			TweenService:Create(cc, TweenInfo.new(2.5, Enum.EasingStyle.Sine), { TintColor = rgb(255, 238, 206), Saturation = 0.16, Brightness = 0.03, Contrast = 0.06 }):Play()
			if bloom then
				TweenService:Create(bloom, TweenInfo.new(3), { Intensity = bloomBase + 0.45 }):Play()
			end
			if okSpec then
				pcall(function()
					TweenService:Create(Lighting, TweenInfo.new(3), { EnvironmentSpecularScale = 1 }):Play()
				end)
			end
			task.delay(math.min(spread, 3), function()
				for _, l in lamps do
					if l.light.Parent then
						TweenService:Create(l.light, TweenInfo.new(2, Enum.EasingStyle.Sine), { Brightness = l.brightness * 1.6, Color = GOLD }):Play()
					end
				end
			end)
			goldenFire(EBB + 2.6 - HUSH)
			-- III. The splendour.
			Flakes.fall({
				seconds = EBB - HUSH,
				centre = guestAt,
				colours = CONFETTI,
				material = Enum.Material.Metal,
				reflectance = 0.5,
				size = Vector3.new(0.34, 0.02, 0.18),
				flutter = 3,
				count = math.floor(c.confetti * dense),
				radius = 28,
				height = Layout.Suite.height - 4,
				fall = 2.2,
			})
			dust = goldDust(stage, room, floorY)
			task.delay(1, function()
				if stage.Parent then
					shafts(stage, floorY, EBB - HUSH - 1)
				end
			end)
			task.delay(2.4, function()
				if stage.Parent then
					coins(stage, floorY, S * 0.5)
				end
			end)
			task.delay(4, function()
				if stage.Parent then
					jets = fountains(stage, room, floorY)
					pcall(Sound.play, "sparklePass", 0.55)
				end
			end)
		end)

		-- The likeness rises.
		task.delay(STATUE, function()
			if stage.Parent == nil then
				return
			end
			pcall(Sound.play, "riseWhoosh", 0.6)
			local ok, at, f = pcall(likeness, stage, floorY)
			if ok then
				statueAt = at
				crumble = f
			end
			task.delay(3, function()
				if stage.Parent then
					pcall(Sound.play, "bellStrike", 0.55)
				end
			end)
		end)

		-- IV. The crowning.
		task.delay(CROWN - 0.4, function()
			if gui.Parent then
				Stagecraft.letterbox(gui, true)
			end
		end)
		task.delay(CROWN, function()
			if stage.Parent == nil then
				return
			end
			pcall(Sound.play, "regalFanfare", 0.85)
			pcall(Sound.play, "bellTree", 0.8)
			pcall(Sound.play, "heavenly", 0.55)
			pillar(stage, floorY, 6.5)
			crown(stage, S - CROWN - 1)
			local at = guestAt() or from
			sparkRing(stage, at, floorY, statueAt, 6)
			task.delay(0.9, function()
				if stage.Parent then
					capeParts = cape(stage)
				end
			end)
			task.delay(2.1, function()
				if not stage.Parent then
					return
				end
				Stagecraft.quake(0.16, 0.35)
				pcall(Sound.play, "bellStrike", 0.7)
				pcall(Sound.play, "crystal", 0.6)
				local head = headOf()
				if head then
					burst(stage, head.CFrame.Position + Vector3.new(0, 1, 0), 60, 12)
				end
				Stagecraft.title(gui, "All hail", string.upper(player.DisplayName), 3.4, GOLD_TITLE)
			end)
			-- The camera looks up at them, from the side away from the statue.
			local root, head = rootOf(), headOf()
			if root and head then
				local look = flatLook(root)
				local right = Vector3.new(-look.Z, 0, look.X)
				local statueSide = if statueAt then (statueAt - root.CFrame.Position):Dot(right) else 1
				local turn = if statueSide > 0 then 35 else -35
				local side = CFrame.Angles(0, math.rad(turn), 0) * look
				local focus = head.CFrame.Position + Vector3.new(0, 0.7, 0)
				Stagecraft.shot(focus, root.CFrame.Position - Vector3.new(0, 1, 0) + side * 7, 3.2, { stage :: Instance })
			end
		end)

		-- V. The finale: a golden supernova.
		task.delay(NOVA - 1.2, function()
			if stage.Parent then
				pcall(Sound.play, "riseWhoosh", 0.7, 1.1)
			end
		end)
		task.delay(NOVA, function()
			if stage.Parent == nil then
				return
			end
			local at = guestAt() or from
			burst(stage, at + Vector3.new(0, 1.5, 0), 300, 34)
			shockwave(stage, Vector3.new(at.X, floorY + 0.4, at.Z), GOLD_WHITE, 24, 1.1)
			task.delay(0.25, function()
				shockwave(stage, Vector3.new(at.X, floorY + 0.4, at.Z), GOLD, 18, 1.1)
			end)
			flash(0.15, 1.3)
			Stagecraft.quake(0.4, 1)
			if bloom then
				bloom.Intensity = bloomBase + 1.6
				TweenService:Create(bloom, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Intensity = bloomBase + 0.45 }):Play()
			end
			for _, e in jets do
				if e.Parent then
					e:Emit(math.floor(60 * dense))
				end
			end
			pcall(Sound.play, "fireworkBoom", 1, 0.8)
			pcall(Sound.play, "celebrate", 0.8)
			pcall(Sound.play, "shimmerFall", 0.9, 0.9)
		end)

		-- The ending: the gold ebbs back to the guest, the coins rise as light, the statue crumbles.
		task.delay(EBB, function()
			pcall(Sound.play, "bellTree", 0.6, 0.9)
			pcall(Sound.play, "fairyDust", 0.6)
			wave(parts, from, c.speed * 1.6, true, ungild, spark)
			coinsRise(stage)
			crumble()
			for _, e in jets do
				e.Rate = 0
			end
			local d = dust
			if d then
				d.Rate = 0
			end
			for _, l in lamps do
				if l.light.Parent then
					TweenService:Create(l.light, TweenInfo.new(3, Enum.EasingStyle.Sine), { Brightness = l.brightness, Color = l.color }):Play()
				end
			end
			TweenService:Create(cc, TweenInfo.new(3), { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 }):Play()
			if bloom then
				TweenService:Create(bloom, TweenInfo.new(3), { Intensity = bloomBase }):Play()
			end
			if okSpec then
				pcall(function()
					TweenService:Create(Lighting, TweenInfo.new(3), { EnvironmentSpecularScale = specBase }):Play()
				end)
			end
			stopScore()
			task.delay(1.2, function()
				Stagecraft.title(gui, nil, "LONG MAY YOU SHINE", 3, GOLD_TITLE)
			end)
		end)
		task.delay(S - 2, function()
			for _, p in capeParts do
				if p.Parent then
					TweenService:Create(p, TweenInfo.new(1, Enum.EasingStyle.Sine), { Transparency = 1 }):Play()
				end
			end
		end)
		task.delay(S - 0.6, function()
			if gui.Parent then
				Stagecraft.letterbox(gui, false)
			end
		end)
		task.delay(S + 1, function()
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
			if okSpec then
				pcall(function()
					(Lighting :: any).EnvironmentSpecularScale = specBase
				end)
			end
			cc:Destroy()
			Stagecraft.calm()
			stage:Destroy()
			gui:Destroy()
			live = math.max(0, live - 1)
		end)
	end)
end

-- A transformation is on this screen (the card of what to do next steps aside for its words).
function Midas.isRunning(): boolean
	return live > 0
end

return Midas

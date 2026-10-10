--!strict
-- The Meme Takeover (a Suite spectacle): ninety seconds of the house's meme curios taking over the
-- room you're standing in, in six acts and a finale. It comes in editions (shared/MemeTakeovers),
-- and the server picks one you haven't seen lately, so it's never the same show twice in a row:
-- each has its own colours, cast, boss, music and words, and its own way through the acts.
--   1. The opening    a siren of colour, a glitch, a countdown, or the lights going out
--   2. The entrance   through a portal, dropping from the ceiling, a fountain, a march, a swirl
--   3. The dance      a conga, a tornado, orbits, a wave, a bounce, a dance-off, a tower
--   4. The rain       little memes, or the edition's own (stars, coins, sweets...), or bubbles
--   5. The boss       a giant meme: laser eyes, a stomp, a spin, a split, a halo
--   6. The chaos      a frenzy, zero gravity, a rainbow, slow motion and the drop
--   7. The finale     a burst, an implosion, a freeze that shatters, rockets, a bow, gold
-- Drawn on this screen only (a Suite is its owner's alone); the server only says when, and which
-- edition. Nothing in it is a prize. Every number that shapes it is in Config.Spectacles.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Layout = require(ReplicatedStorage.Shared.Layout)
local MemeTakeovers = require(ReplicatedStorage.Shared.MemeTakeovers)
local CameraRig = require(script.Parent.Parent.Camera)
local Sound = require(script.Parent.Parent.Sound)

local MemeTakeover = {}

type Box = { minX: number, maxX: number, minZ: number, maxZ: number }
type Actor = { part: Part, gui: BillboardGui, glyph: TextLabel, size: number, v: Vector3, at: Vector3, spin: number, phase: number, home: number }

-- (The big words: the house's sans at its heaviest, cut clean.)
local IMPACT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local rgb = Color3.fromRGB

local running = false
local lastEdition: string? = nil
local finaleDone = false -- the last show's finale has played through

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

-- The cast: the edition's own memes, or every meme curio.
local function castOf(V: MemeTakeovers.Variant): { any }
	local out = {}
	local wanted: { [string]: boolean }? = nil
	if V.cast then
		wanted = {}
		for _, id in V.cast do
			(wanted :: { [string]: boolean })[id] = true
		end
	end
	for _, c in Curios.List do
		if c.family == "meme" and (wanted == nil or wanted[c.id]) then
			table.insert(out, c)
		end
	end
	if #out == 0 then
		for _, c in Curios.List do
			if c.family == "meme" then
				table.insert(out, c)
			end
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

-- A meme (or a glyph of the edition's own): big, its accent riding on its shoulder.
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
	if c.accent and c.accent ~= "" then
		local a = Instance.new("TextLabel")
		a.BackgroundTransparency = 1
		a.AnchorPoint = Vector2.new(1, 0)
		a.Position = UDim2.fromScale(1.05, -0.05)
		a.Size = UDim2.fromScale(0.45, 0.45)
		a.Text = c.accent
		a.TextScaled = true
		a.Parent = g
	end
	return { part = p, gui = bb, glyph = g, size = size, v = Vector3.zero, at = at, spin = 0, phase = math.random() * 10, home = math.random() * math.pi * 2 }
end

local function sequenceOf(palette: { Color3 }): ColorSequence
	local points = {}
	for i, c in palette do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / math.max(1, #palette - 1), c))
	end
	return ColorSequence.new(points)
end

local lastCaption: Frame? = nil

-- A caption across the upper screen: the edition's colours through big heavy letters, a dark
-- edge round them, a soft shadow; it punches in and wobbles while it holds. The first carries the
-- edition's name above it.
local function caption(gui: ScreenGui, text: string, palette: { Color3 }, hold: number, kicker: string?)
	if gui.Parent == nil then
		return
	end
	-- (One at a time: a new line replaces the last at once.)
	local prev = lastCaption
	if prev and prev.Parent then
		prev:Destroy()
	end
	local holder = Instance.new("Frame")
	holder.Name = "Caption"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.22)
	holder.Size = UDim2.fromScale(0.86, 0.14)
	holder.Parent = gui
	lastCaption = holder
	local shadow = Instance.new("TextLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Position = UDim2.new(0, 3, 0, 5)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.FontFace = IMPACT
	shadow.TextScaled = true
	shadow.TextColor3 = Color3.new(0, 0, 0)
	shadow.TextTransparency = 0.55
	shadow.Text = text
	shadow.Parent = holder
	local label = Instance.new("TextLabel")
	label.Name = "Words"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = IMPACT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.Parent = holder
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.45, palette[1]),
		ColorSequenceKeypoint.new(1, palette[math.min(2, #palette)]),
	})
	fill.Parent = label
	local edge = Instance.new("UIStroke")
	edge.Color = rgb(12, 8, 20)
	edge.Thickness = 3
	edge.Parent = label
	if kicker then
		local k = Instance.new("TextLabel")
		k.Name = "Kicker"
		k.BackgroundTransparency = 1
		k.AnchorPoint = Vector2.new(0.5, 1)
		k.Position = UDim2.new(0.5, 0, 0, -4)
		k.Size = UDim2.new(0.7, 0, 0.32, 0)
		k.FontFace = Brand.Fonts.display
		k.TextScaled = true
		k.TextColor3 = Color3.new(1, 1, 1)
		k.Text = kicker
		k.Parent = holder
		local kEdge = Instance.new("UIStroke")
		kEdge.Color = rgb(12, 8, 20)
		kEdge.Thickness = 2
		kEdge.Parent = k
		local kFill = Instance.new("UIGradient")
		kFill.Color = sequenceOf(palette)
		kFill.Parent = k
	end
	local s = Instance.new("UIScale")
	s.Scale = 2.2
	s.Parent = holder
	TweenService:Create(s, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < hold and holder.Parent do
			holder.Rotation = math.sin(os.clock() * 30) * 3
			fill.Offset = Vector2.new(0, math.sin(os.clock() * 4) * 0.15)
			task.wait()
		end
		-- (Replaced by the next line, or the show put away: nothing to fade.)
		if holder.Parent == nil then
			return
		end
		for _, d in holder:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
		task.wait(0.45)
		if lastCaption == holder then
			lastCaption = nil
		end
		holder:Destroy()
	end)
end

local function confetti(parent: Instance, at: Vector3, area: Vector3, rate: number, palette: { Color3 }, up: boolean?): ParticleEmitter
	local p = newPart(parent, at)
	p.Size = area
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Rate = rate
	e.Lifetime = NumberRange.new(2.5, 4)
	e.Speed = NumberRange.new(2, 6)
	e.SpreadAngle = Vector2.new(40, 40)
	e.EmissionDirection = if up then Enum.NormalId.Top else Enum.NormalId.Bottom
	e.Acceleration = Vector3.new(0, if up then 3 else -6, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Size = NumberSequence.new(0.6, 0.3)
	e.LightEmission = 0.7
	pcall(function()
		e.Color = sequenceOf(palette)
	end)
	e.Parent = p
	return e
end

local function burst(parent: Instance, at: Vector3, n: number, palette: { Color3 })
	-- (Never into a show that's already been put away.)
	if parent.Parent == nil then
		return
	end
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
		e.Color = ColorSequence.new(palette[math.random(1, #palette)], palette[math.random(1, #palette)])
	end)
	e.Parent = p
	e:Emit(n)
	task.delay(2, function()
		p:Destroy()
	end)
end

-- A ring of light opening across the floor (the boss's stomp).
local function shockwave(parent: Instance, at: Vector3, colour: Color3, reach: number)
	if parent.Parent == nil then
		return
	end
	local beads = 26
	for i = 1, beads do
		local a = (i / beads) * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local b = Instance.new("Part")
		b.Name = "Wave"
		b.Shape = Enum.PartType.Ball
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.Neon
		b.Color = colour
		b.Transparency = 0.1
		b.Size = Vector3.new(0.7, 0.7, 0.7)
		b.CFrame = CFrame.new(at + out * 1.5)
		b.Parent = parent
		TweenService:Create(b, TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { CFrame = CFrame.new(at + out * reach), Transparency = 1, Size = Vector3.new(0.25, 0.25, 0.25) }):Play()
		task.delay(1, function()
			b:Destroy()
		end)
	end
end

-- The music for an edition: a track of its list in Config.Assets.AbuseMusic, or the show's own.
local function musicOf(V: MemeTakeovers.Variant): (string, number)
	local base = cfg().memeMusicVolume or 0.75
	if V.music ~= "" then
		local lists = (Config.data.Assets :: any).AbuseMusic
		local list = if type(lists) == "table" then lists[V.music] else nil
		if type(list) == "table" and #list > 0 then
			local track = list[math.random(1, #list)]
			if type(track) == "table" and type(track.id) == "string" then
				return track.id, base * (tonumber(track.gain) or 1)
			end
		end
	end
	return cfg().memeMusic or "", base
end

-- Plays the Takeover in the room around the guest, for `seconds`, in edition `editionId` (the
-- server's choice; the classic if it's unknown).
function MemeTakeover.play(seconds: number?, editionId: string?)
	if running then
		return
	end
	local V = MemeTakeovers.get(editionId)
	lastEdition = V.id
	local P = V.palette
	local player = Players.LocalPlayer
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	local centre: Vector3 = if rootPart and rootPart:IsA("BasePart") then rootPart.CFrame.Position else Vector3.new(-49 * Layout.SCALE, Layout.Suite.floorY + 3, 50 * Layout.SCALE)
	local room = roomOf(centre)
	local floorY = Layout.Suite.floorY
	local ceiling = floorY + Layout.Suite.height - 1
	local mid = Vector3.new((room.minX + room.maxX) / 2, floorY, (room.minZ + room.maxZ) / 2)
	local T = seconds or cfg().memeSeconds
	running = true

	local folder = Instance.new("Folder")
	folder.Name = "MemeTakeover"
	folder:SetAttribute("Edition", V.id)
	folder.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "MemeTakeover"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 35
	gui:SetAttribute("Edition", V.id)
	gui.Parent = player:WaitForChild("PlayerGui")
	local tint = Instance.new("Frame")
	tint.BackgroundColor3 = P[1]
	tint.BackgroundTransparency = 1
	tint.BorderSizePixel = 0
	tint.Size = UDim2.fromScale(1, 1)
	tint.Parent = gui

	-- The room's own lights turn the edition's colours (put back after), and party lights hang
	-- overhead.
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
	cc.TintColor = Color3.new(1, 1, 1)

	-- (Lines and directions laid out from where the guest is looking as the dance begins.)
	local camera = Workspace.CurrentCamera
	local look = if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1)
	local front = Vector3.new(look.X, 0, look.Z)
	front = if front.Magnitude > 0.01 then front.Unit else Vector3.new(0, 0, -1)
	local right = front:Cross(Vector3.new(0, 1, 0)).Unit

	local list = castOf(V)
	local cast: { Actor } = {}
	local minis: { Actor } = {}
	local clones: { Actor } = {}
	local boss: Actor? = nil
	local lasers: { Beam } = {}
	local halo: { BasePart } = {}
	local act = 0
	local t0 = os.clock()
	local beat = 0
	local rain: ParticleEmitter? = nil
	local actAt = 0 -- when this act began
	local pace = 1 -- the chaos's slow motion (and the finale's freeze)
	local nextStomp = 0
	finaleDone = false

	local function spawnMeme(size: number, at: Vector3, v: Vector3): Actor
		local a = actor(folder, list[math.random(1, #list)], size, at)
		a.v = v
		table.insert(cast, a)
		return a
	end

	local stopScore: (() -> ())? = nil
	local function sound(name: string, volume: number, at: number?, pitch: number?)
		task.delay(at or 0, function()
			pcall(Sound.play, name, volume, pitch)
		end)
	end
	local function sounds(names: { string }, volume: number)
		for i, n in names do
			sound(n, volume, (i - 1) * 0.45)
		end
	end

	local function clearActors()
		for _, a in cast do
			a.part:Destroy()
		end
		for _, a in minis do
			a.part:Destroy()
		end
		for _, a in clones do
			a.part:Destroy()
		end
		table.clear(cast)
		table.clear(minis)
		table.clear(clones)
		local b = boss
		if b then
			b.part:Destroy()
			boss = nil
		end
		for _, h in halo do
			h:Destroy()
		end
		table.clear(halo)
		table.clear(lasers)
	end

	local function flash(colour: Color3, from: number, seconds: number)
		tint.BackgroundColor3 = colour
		tint.BackgroundTransparency = from
		TweenService:Create(tint, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
	end

	-- The opening, by the edition's way in.
	local function opening()
		if V.opening == "countdown" then
			for i, n in { "3", "2", "1" } do
				task.delay((i - 1) * 1.2, function()
					if folder.Parent then
						caption(gui, n, P, 0.9)
						sound("tick", 0.8, 0, 0.8 + i * 0.1)
					end
				end)
			end
			task.delay(3.6, function()
				if folder.Parent then
					caption(gui, V.captions[1], P, 2.2, "MEME TAKEOVER  ·  " .. V.name)
					sounds(V.sounds.open, 0.9)
				end
			end)
		elseif V.opening == "blackout" then
			tint.BackgroundColor3 = Color3.new(0, 0, 0)
			tint.BackgroundTransparency = 0.25
			sound("lowHit", 1, 0, 0.8)
			task.delay(1.4, function()
				if folder.Parent then
					flash(P[1], 0.3, 1.2)
					caption(gui, V.captions[1], P, 3, "MEME TAKEOVER  ·  " .. V.name)
					sounds(V.sounds.open, 0.9)
				end
			end)
		elseif V.opening == "glitch" then
			caption(gui, V.captions[1], P, 4, "MEME TAKEOVER  ·  " .. V.name)
			sounds(V.sounds.open, 0.9)
			pcall(CameraRig.shake, 0.25, 0.6)
		else
			caption(gui, V.captions[1], P, 4, "MEME TAKEOVER  ·  " .. V.name)
			pcall(Sound.play, "fireworkBoom", 1, 0.6)
			sounds(V.sounds.open, 0.9)
			for i = 0, 2 do
				sound("airHorn", 0.7, 1.4 + i * 0.45, 1 + i * 0.04)
			end
		end
	end

	-- The boss and its show.
	local function bossArrives()
		local byId = (Curios :: any).byId
		local c = (if byId then byId[V.boss] else nil) or list[#list]
		local a = actor(folder, c, cfg().bossSize, Vector3.new(mid.X, ceiling + 10, mid.Z))
		boss = a
		pcall(Sound.play, "fireworkBoom", 1, 0.45)
		sounds(V.sounds.boss, 0.9)
		if V.bossMove == "lasers" then
			-- Laser eyes: two beams from the boss to points sweeping the floor.
			for i = 1, 2 do
				local from = Instance.new("Attachment")
				from.Parent = a.part
				from.Position = Vector3.new(if i == 1 then -1.2 else 1.2, 1, 0)
				local hit = newPart(folder, mid)
				hit.Name = "LaserHit" .. i
				local to = Instance.new("Attachment")
				to.Parent = hit
				local b = Instance.new("Beam")
				b.Attachment0 = from
				b.Attachment1 = to
				b.Width0 = 0.6
				b.Width1 = 1.4
				b.LightEmission = 1
				b.FaceCamera = true
				b.Color = ColorSequence.new(P[1], P[math.min(3, #P)])
				b.Transparency = NumberSequence.new(0.1)
				b:SetAttribute("Hit", i)
				b.Parent = a.part
				table.insert(lasers, b)
			end
		elseif V.bossMove == "halo" then
			-- A ring of light over its head, turning, and beams of light turning round it.
			for i = 1, 16 do
				local h = Instance.new("Part")
				h.Name = "Halo"
				h.Shape = Enum.PartType.Ball
				h.Anchored = true
				h.CanCollide = false
				h.CanQuery = false
				h.CanTouch = false
				h.CastShadow = false
				h.Material = Enum.Material.Neon
				h.Color = P[1]:Lerp(Color3.new(1, 1, 1), 0.4)
				h.Size = Vector3.new(0.6, 0.6, 0.6)
				h:SetAttribute("I", i)
				h.Parent = folder
				table.insert(halo, h)
			end
		elseif V.bossMove == "spin" then
			local trail = Instance.new("ParticleEmitter")
			trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			trail.Rate = 60
			trail.Lifetime = NumberRange.new(0.8, 1.4)
			trail.Speed = NumberRange.new(4, 10)
			trail.SpreadAngle = Vector2.new(180, 180)
			trail.LightEmission = 1
			trail.Size = NumberSequence.new(0.7, 0)
			pcall(function()
				trail.Color = sequenceOf(P)
			end)
			trail.Parent = a.part
		end
	end

	-- The finale, by the edition's way out. (Those that move finish within the act's few seconds.)
	local function finale()
		pace = if V.finale == "freeze" then 0 else 1
		caption(gui, V.captions[7], P, 3.5)
		sounds(V.sounds.finale, 0.95)
		local stop = stopScore
		if stop then
			stopScore = nil
			task.delay(2.5, stop)
		end
		if rain then
			rain.Rate = 0
		end
		if V.finale == "burst" then
			pcall(Sound.play, "fireworkBoom", 1, 0.8)
			for _, a in cast do
				burst(folder, a.at, 40, P)
			end
			local b = boss
			if b then
				burst(folder, b.at, 200, P)
			end
			clearActors()
			flash(Color3.new(1, 1, 1), 0.2, 1.2)
			finaleDone = true
		elseif V.finale == "freeze" then
			-- Everything stops, the room goes icy, then it all shatters, one after another.
			pace = 0
			cc.TintColor = rgb(200, 230, 255)
			cc.Saturation = -0.3
			pcall(Sound.play, "crystal", 1, 0.8)
			local all: { Actor } = {}
			for _, a in cast do
				table.insert(all, a)
			end
			for _, a in minis do
				table.insert(all, a)
			end
			-- (However many there are, the whole room shatters within a second and a bit.)
			local gap = math.min(0.03, 1.1 / math.max(1, #all))
			task.delay(1.3, function()
				for i, a in all do
					task.delay(i * gap, function()
						if a.part.Parent then
							burst(folder, a.at, 12, P)
							a.part:Destroy()
						end
					end)
				end
				task.delay(#all * gap + 0.2, function()
					local b = boss
					if b then
						burst(folder, b.at, 160, P)
					end
					pcall(Sound.play, "shimmerFall", 1)
					clearActors()
					flash(Color3.new(1, 1, 1), 0.25, 1)
					cc.TintColor = Color3.new(1, 1, 1)
					finaleDone = true
				end)
			end)
		elseif V.finale == "gold" then
			cc.TintColor = rgb(255, 225, 150)
			for _, a in cast do
				a.glyph.Text = "🪙"
				local accent = a.glyph:FindFirstChildOfClass("TextLabel")
				if accent then
					accent.Text = ""
				end
				a.v = Vector3.new(0, 0, 0)
			end
			pcall(Sound.play, "kaching", 1)
			task.delay(2.2, function()
				for _, a in cast do
					burst(folder, a.at, 14, P)
				end
				local b = boss
				if b then
					burst(folder, b.at, 160, P)
				end
				clearActors()
				flash(rgb(255, 230, 160), 0.2, 1.2)
				cc.TintColor = Color3.new(1, 1, 1)
				finaleDone = true
			end)
		elseif V.finale == "rockets" then
			for _, a in cast do
				a.v = Vector3.new((math.random() - 0.5) * 4, 30 + math.random() * 18, (math.random() - 0.5) * 4)
			end
			task.delay(2.6, function()
				local b = boss
				if b then
					burst(folder, b.at, 200, P)
				end
				clearActors()
				flash(Color3.new(1, 1, 1), 0.3, 1)
				finaleDone = true
			end)
		else
			-- implode and bow move in the frame loop, then end here.
			task.delay(if V.finale == "bow" then 2.8 else 1.1, function()
				pcall(Sound.play, "fireworkBoom", 1, if V.finale == "implode" then 0.5 else 0.9)
				local at = Vector3.new(mid.X, floorY + 5, mid.Z)
				if V.finale == "implode" then
					burst(folder, at, 260, P)
				else
					for _, a in cast do
						burst(folder, a.at, 20, P)
					end
				end
				local b = boss
				if b then
					burst(folder, b.at, 120, P)
				end
				clearActors()
				flash(Color3.new(1, 1, 1), 0.2, 1.2)
				finaleDone = true
			end)
		end
		tint.BackgroundTransparency = 1
	end

	local function setAct(n: number)
		if n == act then
			return
		end
		act = n
		actAt = os.clock() - t0
		if n == 1 then
			opening()
		elseif n == 2 then
			caption(gui, V.captions[2], P, 3)
			if not stopScore then
				local id, volume = musicOf(V)
				stopScore = Sound.score(id, volume)
			end
		elseif n == 3 then
			caption(gui, V.captions[3], P, 3)
			sound("partyHorn", 0.7)
			sound("partyHorn", 0.7, 0.5, 1.15)
		elseif n == 4 then
			caption(gui, V.captions[4], P, 3)
			rain = confetti(folder, Vector3.new(mid.X, if V.rainUp then floorY + 0.5 else ceiling, mid.Z), Vector3.new(room.maxX - room.minX - 2, 0.5, room.maxZ - room.minZ - 2), 220, P, V.rainUp)
		elseif n == 5 then
			caption(gui, V.captions[5], P, 4)
			bossArrives()
		elseif n == 6 then
			caption(gui, V.captions[6], P, 3)
			sound("airHorn", 0.8)
			sound("recordScratch", 0.7, 0.6)
			if V.chaos == "frenzy" and rain then
				rain.Rate = 500
			elseif V.chaos == "slowmo" then
				sound("lowHit", 1, 0, 0.6)
			end
		elseif n == 7 then
			finale()
		end
	end

	-- When each act begins, as a share of the whole.
	local ACTS = { 0, 0.06, 0.22, 0.42, 0.58, 0.8, 0.95 }
	local spawned = 0
	local lastBeat = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(rawDt: number)
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
		local inAct = t - actAt
		-- Slow motion, then the drop: a quarter speed for most of the chaos, then double.
		if act == 6 and V.chaos == "slowmo" then
			local drop = inAct > (T * (ACTS[7] - ACTS[6])) * 0.6
			if drop and pace < 1 then
				sound("sonicBoom", 1)
				pcall(CameraRig.shake, 0.5, 0.4)
			end
			pace = if drop then 2 else 0.25
		elseif act ~= 7 then
			pace = 1
		end
		local dt = rawDt * pace
		local me = player.Character
		local myRoot = me and me:FindFirstChild("HumanoidRootPart")
		local you: Vector3 = if myRoot and myRoot:IsA("BasePart") then myRoot.CFrame.Position else centre
		-- The beat: twice a second (four times in the chaos).
		local every = if act == 6 and V.chaos ~= "slowmo" then 0.25 else 0.5
		if t - lastBeat >= every then
			lastBeat = t
			beat += 1
			if act >= 2 and act <= 6 then
				pcall(Sound.play, "tick", 0.5, if beat % 4 == 0 then 0.7 else 1.1)
			end
			local c = P[beat % #P + 1]
			for i, l in discos do
				l.Color = P[(beat + i) % #P + 1]
				l.Brightness = if act >= 2 and act <= 6 then 3 else 0
			end
			for light in saved do
				if light.Parent then
					light.Color = if act <= 6 then c else saved[light]
				end
			end
			if (act == 1 and V.opening == "siren") or (act >= 5 and act <= 6 and V.chaos ~= "rainbow") then
				tint.BackgroundColor3 = c
				tint.BackgroundTransparency = if act == 1 then 0.75 else 0.88
				TweenService:Create(tint, TweenInfo.new(every * 0.9), { BackgroundTransparency = 1 }):Play()
			end
			if act >= 5 and act <= 6 then
				pcall(CameraRig.shake, if act == 6 then 0.4 else 0.25, every)
			end
		end
		-- A glitch opening jitters; a rainbow chaos turns every colour through.
		if act == 1 and V.opening == "glitch" then
			local cap = lastCaption
			if cap and cap.Parent then
				cap.Position = UDim2.new(0.5, math.random(-8, 8), 0.22, math.random(-5, 5))
			end
			if math.random() < 0.12 then
				tint.BackgroundColor3 = P[math.random(1, #P)]
				tint.BackgroundTransparency = 0.8
			else
				tint.BackgroundTransparency = 1
			end
		end
		if act == 6 and V.chaos == "rainbow" then
			local hue = (t * 0.35) % 1
			tint.BackgroundColor3 = Color3.fromHSV(hue, 0.6, 1)
			tint.BackgroundTransparency = 0.86
			cc.TintColor = Color3.fromHSV(hue, 0.15, 1)
		elseif act ~= 7 or (V.finale ~= "gold" and V.finale ~= "freeze") then
			cc.TintColor = Color3.new(1, 1, 1)
		end
		cc.Saturation = if act >= 2 and act <= 6 then 0.5 else (if act == 7 then cc.Saturation else 0)
		-- Act 2: the memes arrive, a few each frame, until the cast is full.
		if act == 2 and spawned < cfg().memeCast then
			spawned += 1
			local size = math.random(25, 55) / 10
			if V.entrance == "drop" then
				spawnMeme(size, Vector3.new(room.minX + 1 + math.random() * (room.maxX - room.minX - 2), ceiling, room.minZ + 1 + math.random() * (room.maxZ - room.minZ - 2)), Vector3.zero)
			elseif V.entrance == "fountain" then
				spawnMeme(size, Vector3.new(mid.X, floorY + 1, mid.Z), Vector3.new((math.random() - 0.5) * 8, 26 + math.random() * 8, (math.random() - 0.5) * 8))
			elseif V.entrance == "march" then
				local z = room.minZ + 1.5 + ((spawned * 1.7) % math.max(1, room.maxZ - room.minZ - 3))
				spawnMeme(size, Vector3.new(room.minX + 1.5, floorY + size / 2, z), Vector3.new(8 + math.random() * 3, 3, 0))
			elseif V.entrance == "swirl" then
				local a = (spawned / cfg().memeCast) * math.pi * 4
				local r = math.min(room.maxX - room.minX, room.maxZ - room.minZ) * 0.45
				spawnMeme(size, mid + Vector3.new(math.cos(a) * r, 3, math.sin(a) * r), Vector3.new(-math.sin(a) * 14, 6, math.cos(a) * 14))
			else
				local a = math.random() * math.pi * 2
				spawnMeme(size, Vector3.new(mid.X, floorY + 4, mid.Z), Vector3.new(math.cos(a) * 16, 14 + math.random() * 10, math.sin(a) * 16))
			end
			if spawned % 4 == 0 then
				pcall(Sound.play, "pickup", 0.4, 0.8 + math.random() * 0.6)
				if V.entrance == "portal" or V.entrance == "fountain" then
					burst(folder, Vector3.new(mid.X, floorY + 4, mid.Z), 25, P)
				end
			end
		end
		-- Act 4: the rain (or the bubbles rising).
		if act == 4 and #minis < cfg().memeRain and math.random() < 0.8 then
			local glyphs = V.rain
			local c = if glyphs then { glyph = glyphs[math.random(1, #glyphs)], accent = "" } else list[math.random(1, #list)]
			local y = if V.rainUp then floorY + 0.5 else ceiling
			local m = actor(folder, c, math.random(8, 16) / 10, Vector3.new(room.minX + 1 + math.random() * (room.maxX - room.minX - 2), y, room.minZ + 1 + math.random() * (room.maxZ - room.minZ - 2)))
			m.v = if V.rainUp then Vector3.new(0, math.random(3, 6), 0) else Vector3.new(0, -math.random(4, 10), 0)
			table.insert(minis, m)
		end
		-- Moving everyone.
		local b = boss
		for i, a in cast do
			if not a.part.Parent then
				continue
			end
			local goal: Vector3? = nil
			if act == 3 then
				local d = V.dance
				if d == "tornado" then
					local ang = a.home + t * 2.6 + i * 0.21
					local r = 2.5 + (i % 6) * 0.9
					local h = (t * 3 + i * 0.37) % math.max(1, Layout.Suite.height - 3)
					goal = Vector3.new(you.X + math.cos(ang) * r, floorY + 1 + h, you.Z + math.sin(ang) * r)
				elseif d == "orbit" then
					local ring = i % 3
					local r = 5 + ring * 3
					local ang = a.home + t * (1.4 - ring * 0.3)
					goal = you + Vector3.new(math.cos(ang) * r, 2 + math.sin(ang + ring) * ring * 1.5, math.sin(ang) * r)
				elseif d == "wave" then
					local col, row = (i - 1) % 8, (i - 1) // 8
					goal = you + right * (-10 + col * 2.8) + front * (6 + row * 2.5) + Vector3.new(0, 1.5 + math.sin(t * 5 - col * 0.7 - row * 0.5) * 1.6 + row * 0.3, 0)
				elseif d == "bounce" then
					local r = 6 + (i % 2) * 2.5
					local ang = a.home
					goal = you + Vector3.new(math.cos(ang) * r, 1 + math.abs(math.sin(t * math.pi * 2 + (i % 2) * math.pi / 2)) * 3, math.sin(ang) * r)
				elseif d == "duel" then
					local side = i % 2
					local idx = (i - 1) // 2
					goal = you + front * 8 + right * (if side == 0 then -5 else 5) + front * (idx % 10 - 5) * 0.9 + Vector3.new(0, 1 + math.max(0, math.sin(t * 6 + side * math.pi)) * 2.5, 0)
				elseif d == "stack" then
					local level, slot = (i - 1) // 4, (i - 1) % 4
					local sway = math.sin(t * 3 + level * 0.4) * level * 0.08
					goal = you + front * 7 + right * ((slot % 2) * 1.8 - 0.9 + sway) + front * ((slot // 2) * 1.8 - 0.9) + Vector3.new(0, 1 + level * 1.6, 0)
				else
					-- The conga: a ring round the guest, turning, every one bobbing to the beat.
					local ang = a.home + t * 1.2 + i * 0.05
					goal = you + Vector3.new(math.cos(ang) * 7, 1.5 + math.abs(math.sin(t * 6 + i)) * 1.5, math.sin(ang) * 7)
				end
			elseif act == 5 and b then
				-- Orbiting the boss (wider and faster round a spinning one).
				local wide = if V.bossMove == "spin" then 3 else 0
				local ang = a.home + t * (if V.bossMove == "spin" then 3.5 else 2)
				goal = b.at + Vector3.new(math.cos(ang) * (6 + wide + (i % 3) * 2), math.sin(t * 3 + i) * 3 - 2, math.sin(ang) * (6 + wide + (i % 3) * 2))
			elseif act == 7 and V.finale == "implode" then
				goal = Vector3.new(mid.X, floorY + 5, mid.Z)
			elseif act == 7 and V.finale == "bow" then
				local slots = math.max(1, #cast)
				goal = you + front * 8 + right * ((i - 1) / slots * 16 - 8) + Vector3.new(0, 1.5 - (if (t - actAt) > 0.9 then math.max(0, math.sin((t - actAt - 0.9) * 5)) * 1.2 else 0), 0)
			end
			if goal then
				a.at = a.at:Lerp(goal, math.min(1, dt * (if act == 7 then 6 else 4)))
			elseif act == 7 and V.finale == "freeze" then
				-- (Frozen where they are.)
			elseif act == 7 and V.finale == "gold" then
				-- Turned to gold, they fall like coins.
				a.v -= Vector3.new(0, 40 * rawDt, 0)
				local nxt = a.at + a.v * rawDt
				if nxt.Y < floorY + 0.6 then
					nxt = Vector3.new(nxt.X, floorY + 0.6, nxt.Z)
					a.v = Vector3.new(0, math.abs(a.v.Y) * 0.35, 0)
				end
				a.at = nxt
			elseif act == 7 and V.finale == "rockets" then
				local nxt = a.at + a.v * rawDt
				a.at = nxt
				if nxt.Y > ceiling then
					burst(folder, nxt, 30, P)
					if math.random() < 0.3 then
						pcall(Sound.play, "fireworkBoom", 0.6, 0.9 + math.random() * 0.4)
					end
					a.part:Destroy()
					continue
				end
			else
				-- Bouncing off the floor and the walls (faster in a frenzy, floating in zero
				-- gravity).
				local floating = act == 6 and V.chaos == "zeroG"
				local speed = if act == 6 and V.chaos == "frenzy" then 1.8 else 1
				a.v -= Vector3.new(0, (if floating then -4 else 30) * dt, 0)
				local nxt = a.at + a.v * dt * speed
				if nxt.Y < floorY + a.size / 2 then
					nxt = Vector3.new(nxt.X, floorY + a.size / 2, nxt.Z)
					a.v = Vector3.new(a.v.X, math.abs(a.v.Y) * 0.9 + 6, a.v.Z)
				end
				if nxt.Y > ceiling then
					nxt = Vector3.new(nxt.X, ceiling, nxt.Z)
					a.v = Vector3.new(a.v.X, -math.abs(a.v.Y) * (if floating then 0.3 else 1), a.v.Z)
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
			a.spin += dt * (if act == 6 and V.chaos == "frenzy" then 720 else 160)
			a.glyph.Rotation = if act == 3 and (V.dance == "conga" or V.dance == "duel" or V.dance == "bounce") then math.sin(t * 8 + i) * 20
				elseif act == 3 and V.dance == "stack" then math.sin(t * 3 + i) * 6
				elseif act == 7 and V.finale == "bow" then 0
				else a.spin % 360
			local squash = 1 + math.sin(t * 10 + a.phase) * 0.12 * pace
			local shrink = if act == 7 and V.finale == "implode" then math.max(0.2, 1 - (t - actAt)) else 1
			a.gui.Size = UDim2.fromScale(a.size * squash * shrink, a.size / squash * shrink)
			if a.part.Parent then
				a.part.CFrame = CFrame.new(a.at)
			end
		end
		for _, m in minis do
			if not m.part.Parent then
				continue
			end
			if V.rainUp then
				m.v += Vector3.new(0, 2 * dt, 0)
				local nxt = m.at + m.v * dt + Vector3.new(math.sin(t * 3 + m.phase) * dt * 1.5, 0, 0)
				if nxt.Y > ceiling and m.part.Parent then
					-- A bubble pops at the ceiling and another rises.
					burst(folder, nxt, 6, P)
					nxt = Vector3.new(nxt.X, floorY + 0.5, nxt.Z)
					m.v = Vector3.new(0, math.random(3, 6), 0)
				end
				m.at = nxt
			elseif not (act == 7 and V.finale == "freeze") then
				m.v -= Vector3.new(0, 20 * dt, 0)
				local nxt = m.at + m.v * dt
				if nxt.Y < floorY + 0.5 then
					nxt = Vector3.new(nxt.X, floorY + 0.5, nxt.Z)
					m.v = Vector3.new((math.random() - 0.5) * 8, math.abs(m.v.Y) * 0.5, (math.random() - 0.5) * 8)
				end
				m.at = nxt
			end
			m.glyph.Rotation += dt * 300
			if m.part.Parent then
				m.part.CFrame = CFrame.new(m.at)
			end
		end
		-- The boss: down from the ceiling, then its own show.
		if b and b.part.Parent then
			local inBoss = t - (T * ACTS[5])
			local hover = Vector3.new(mid.X, floorY + cfg().bossSize / 2 + 1, mid.Z)
			if V.bossMove == "stomp" and inBoss > 2.5 and act <= 6 then
				-- Up, and down with a thump that sends a ring of light across the floor.
				local cycle = (inBoss - 2.5) % 1.8
				local lift = if cycle < 1.2 then math.sin(cycle / 1.2 * math.pi / 2) * 5 else 5 * (1 - (cycle - 1.2) / 0.6)
				b.at = hover + Vector3.new(0, math.max(0, lift), 0)
				if inBoss >= nextStomp and cycle > 1.75 then
					nextStomp = inBoss + 1.2
					shockwave(folder, Vector3.new(mid.X, floorY + 0.4, mid.Z), P[math.random(1, #P)], math.min(room.maxX - room.minX, room.maxZ - room.minZ) * 0.5)
					burst(folder, Vector3.new(mid.X, floorY + 1, mid.Z), 40, P)
					pcall(Sound.play, "subHit", 0.9, 0.9)
					pcall(CameraRig.shake, 0.6, 0.3)
				end
			elseif V.bossMove == "halo" then
				b.at = b.at:Lerp(hover + Vector3.new(0, 2 + math.sin(t * 1.5) * 1, 0), math.min(1, dt * 1.2))
			else
				b.at = b.at:Lerp(hover, math.min(1, dt * 1.2))
			end
			b.part.CFrame = CFrame.new(b.at)
			local pulse = 1 + math.sin(t * 6) * 0.06
			b.gui.Size = UDim2.fromScale(b.size * pulse, b.size * pulse)
			b.glyph.Rotation = if V.bossMove == "spin" then (t * 540) % 360 else math.sin(t * 2) * 12
			for _, beam in lasers do
				local i = beam:GetAttribute("Hit") :: number
				local hit = folder:FindFirstChild("LaserHit" .. tostring(i))
				if hit and hit:IsA("BasePart") then
					local ang = t * 1.7 + i * math.pi
					hit.CFrame = CFrame.new(mid + Vector3.new(math.cos(ang) * (room.maxX - room.minX) * 0.4, 0.2, math.sin(ang * 1.3) * (room.maxZ - room.minZ) * 0.4))
					if math.random() < 0.05 then
						burst(folder, hit.Position, 15, P)
					end
				end
			end
			for _, h in halo do
				local i = h:GetAttribute("I") :: number
				local ang = t * 1.4 + i / #halo * math.pi * 2
				h.CFrame = CFrame.new(b.at + Vector3.new(math.cos(ang) * cfg().bossSize * 0.45, cfg().bossSize * 0.6, math.sin(ang) * cfg().bossSize * 0.45))
			end
			-- The split: copies peel off, circle, and come back together, again and again.
			if V.bossMove == "split" and act <= 6 then
				local phase = (inBoss % 6) / 6
				local apart = phase > 0.15 and phase < 0.85
				if apart and #clones == 0 then
					local byId = (Curios :: any).byId
					local c = (if byId then byId[V.boss] else nil) or list[#list]
					for _ = 1, 5 do
						local copy = actor(folder, c, cfg().bossSize * 0.4, b.at)
						table.insert(clones, copy)
					end
					pcall(Sound.play, "warpBurst", 0.8)
					burst(folder, b.at, 60, P)
				elseif not apart and #clones > 0 then
					for _, copy in clones do
						copy.part:Destroy()
					end
					table.clear(clones)
					pcall(Sound.play, "magicZoom", 0.8)
				end
				for i, copy in clones do
					local ang = t * 2.2 + i / math.max(1, #clones) * math.pi * 2
					copy.at = copy.at:Lerp(b.at + Vector3.new(math.cos(ang) * 9, math.sin(t * 3 + i) * 2, math.sin(ang) * 9), math.min(1, dt * 4))
					copy.part.CFrame = CFrame.new(copy.at)
					copy.glyph.Rotation = (t * 200 + i * 40) % 360
				end
			end
		end
	end)
	task.delay(T + 3, function()
		running = false
		local stop = stopScore
		if stop then
			stopScore = nil
			stop()
		end
		for light, c in saved do
			if light.Parent then
				light.Color = c
			end
		end
		cc.Saturation = 0
		cc.TintColor = Color3.new(1, 1, 1)
		cc.Enabled = false
		folder:Destroy()
		gui:Destroy()
		lastCaption = nil
	end)
end

function MemeTakeover.isRunning(): boolean
	return running
end

-- The edition played last (for tests and the owner), and whether its finale has played through.
function MemeTakeover.lastEdition(): string?
	return lastEdition
end

function MemeTakeover.finaleDone(): boolean
	return finaleDone
end

return MemeTakeover

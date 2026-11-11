--!strict
-- The Grand Ballroom on a guest's own screen (the server decides everything; this only shows it):
--   the hall's night light (warm chandeliers, a soft bloom; the house's own light back exactly as
--   it was on leaving), the jukebox's record (looping, at the same bar as everyone in the hall),
--   the dance floor's tiles lighting to its beat in rings, checks and sweeps, the four moving
--   lights over it, the Achievement Gallery's frames hung with this guest's own Badge Book, a
--   spotlight on whoever is walking the Runway and the cameras flashing when they pose, the Daily
--   Arena's spotlight drifting across its ring, and a pose at a photo set framed for a photograph.
-- Dance moves are Roblox's own R15 emotes, played on the guest's own avatar (everyone sees them).

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BadgeBook = require(ReplicatedStorage.Shared.BadgeBook)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Plan = require(ReplicatedStorage.Shared.Gala)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sound = require(script.Parent.Parent.Sound)

local GalaView = {}

-- Set by Main: open photo mode (the camera already framed).
GalaView.photo = function() end
-- The hall's state changed (the HUD shows it).
GalaView.changed = function(_st: { [string]: any }) end

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local PALETTE = { rgb(255, 196, 110), rgb(255, 92, 186), rgb(96, 200, 255), rgb(170, 120, 255) }
local DARK = rgb(28, 24, 38)

local active = false
local view: { [string]: any } = {}
local stopRecord: (() -> ())? = nil
local recordSound: Sound? = nil
local recordNow: { [string]: any }? = nil
local beatConn: RBXScriptConnection? = nil
local made: { Instance } = {}
local glows: { [Player]: PointLight } = {}
local spot: BasePart? = nil
local arenaPlay: { [string]: any }? = nil

local function origin(): Vector3
	local o = ((Config.data :: any).Attractions.gala or {}).origin
	if type(o) == "table" then
		return Vector3.new(o[1], o[2], o[3])
	end
	return Vector3.zero
end

local function serverNow(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

---------------------------------------------------------------------------------------------------
-- The hall's light
---------------------------------------------------------------------------------------------------
local LIGHT_PROPS = { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "ColorShift_Bottom", "ExposureCompensation" }
type Saved = { props: { [string]: any }, stash: { Instance } }
local saved: Saved? = nil
local effects: { [string]: Instance } = {}

local function ours(i: Instance): boolean
	return string.sub(i.Name, 1, 4) == "Gala" or string.sub(i.Name, 1, 6) == "Island" or i.Name == "MaisonPhotoGrade" or i.Name == "MaisonPhotoFocus"
end

local function effect(class: string, name: string): Instance
	local e = effects[name]
	if e and e.Parent == Lighting then
		return e
	end
	local n = Instance.new(class)
	n.Name = name
	n.Parent = Lighting
	effects[name] = n
	return n
end

local function light()
	if not saved then
		local s: Saved = { props = {}, stash = {} }
		for _, k in LIGHT_PROPS do
			pcall(function()
				s.props[k] = (Lighting :: any)[k]
			end)
		end
		for _, c in Lighting:GetChildren() do
			if not ours(c) and (c:IsA("Atmosphere") or c:IsA("Sky") or c:IsA("BloomEffect") or c:IsA("SunRaysEffect") or c:IsA("ColorCorrectionEffect")) then
				table.insert(s.stash, c)
				pcall(function()
					c.Parent = nil
				end)
			end
		end
		saved = s
	end
	pcall(function()
		local L = Lighting :: any
		L.ClockTime = 21
		L.Brightness = 1.1
		L.Ambient = rgb(78, 64, 56)
		L.OutdoorAmbient = rgb(54, 56, 76)
		L.ColorShift_Top = rgb(255, 222, 186)
		L.ColorShift_Bottom = rgb(40, 34, 50)
		L.ExposureCompensation = 0.18
		local sky = effect("Sky", "GalaSky") :: any
		sky.StarCount = 3000
		sky.MoonAngularSize = 16
		local b = effect("BloomEffect", "GalaBloom") :: any
		b.Intensity, b.Size, b.Threshold = 0.85, 30, 0.9
		local g = effect("ColorCorrectionEffect", "GalaGrade") :: any
		g.TintColor, g.Saturation, g.Contrast, g.Brightness = rgb(255, 246, 232), 0.08, 0.1, 0.02
		local a = effect("Atmosphere", "GalaAir") :: any
		a.Density, a.Offset, a.Color, a.Decay, a.Glare, a.Haze = 0.22, 0, rgb(206, 176, 142), rgb(96, 74, 64), 0, 1.1
	end)
end

local function unlight()
	for _, e in effects do
		e:Destroy()
	end
	effects = {}
	local s = saved
	if s then
		for k, v in s.props do
			pcall(function()
				(Lighting :: any)[k] = v
			end)
		end
		for _, c in s.stash do
			pcall(function()
				c.Parent = Lighting
			end)
		end
	end
	saved = nil
end

---------------------------------------------------------------------------------------------------
-- The jukebox's record, and the dance floor lighting to its beat
---------------------------------------------------------------------------------------------------
local function playRecord(juke: { [string]: any }?)
	if not juke then
		return
	end
	local list = if type(juke.records) == "table" then juke.records else {}
	local rec = list[tonumber(juke.track) or 1]
	if not rec or (recordNow and recordNow.id == rec.id and recordSound and recordSound.Parent) then
		return
	end
	local stop = stopRecord
	stopRecord = nil
	if stop then
		stop()
	end
	local base = tonumber(((Config.data :: any).Assets or {}).AbuseMusicVolume) or 0.85
	local at = math.max(0, serverNow() - (tonumber(juke.startedAt) or serverNow()))
	local s, snd = Sound.scoreLoop(tostring(rec.id), base * (tonumber(rec.gain) or 1), at)
	stopRecord = s
	recordSound = snd
	recordNow = rec
end

local function stopMusic()
	local stop = stopRecord
	stopRecord = nil
	recordSound = nil
	recordNow = nil
	if stop then
		stop()
	end
end

-- Where the beat is: the beat's number and how far through it (0 to 1).
function GalaView.beat(): (number, number)
	local rec = recordNow
	local bpm = if rec then tonumber(rec.bpm) or 120 else 120
	local offset = if rec then tonumber(rec.beat) or 0 else 0
	local t = os.clock()
	local snd = recordSound
	if snd then
		local ok, pos = pcall(function()
			return snd.TimePosition
		end)
		if ok and type(pos) == "number" and pos > 0 then
			t = pos
		end
	end
	local phase = (t - offset) * bpm / 60
	local n = math.floor(phase)
	return n, phase - n
end

local tiles: { BasePart } = {}
local sweeps: { { part: BasePart, at: Vector3 } } = {}
local lastTiles = 0

local function lightTiles()
	local now = os.clock()
	if now - lastTiles < 0.05 then
		return
	end
	lastTiles = now
	local n, f = GalaView.beat()
	local bar = n // 4
	local pattern = bar % 3
	local colour = PALETTE[n % #PALETTE + 1]
	for _, t in tiles do
		local i = tonumber(t:GetAttribute("I")) or 0
		local j = tonumber(t:GetAttribute("J")) or 0
		local ring = tonumber(t:GetAttribute("Ring")) or 0
		local lit
		if pattern == 0 then
			lit = ring == n % 7
		elseif pattern == 1 then
			lit = (i + j + n) % 2 == 0
		else
			local a = math.deg(math.atan2(j, i)) % 360
			local sweepAt = (n * 45) % 360
			local d = math.abs(((a - sweepAt + 180) % 360) - 180)
			lit = d < 30
		end
		if lit then
			t.Material = Enum.Material.Neon
			t.Color = colour
			t.Transparency = 0.1 + f * 0.45
		else
			t.Material = Enum.Material.Glass
			t.Color = DARK
			t.Transparency = 0.05
		end
	end
	-- The moving lights sweep the floor.
	local c = origin() + Plan.DANCE.centre
	for k, h in sweeps do
		local a = now * 0.55 + k * math.pi / 2
		local target = c + Vector3.new(math.cos(a) * 14, 0, math.sin(a * 1.3) * 14)
		h.part.CFrame = CFrame.lookAt(h.at, target)
	end
end

---------------------------------------------------------------------------------------------------
-- The Achievement Gallery: this guest's own Badge Book in the eight frames
---------------------------------------------------------------------------------------------------
local TIER = { bronze = rgb(214, 150, 96), silver = rgb(206, 212, 222), gold = rgb(255, 204, 90), platinum = rgb(180, 230, 255) }

local function hang(frame: BasePart, badge: BadgeBook.Badge?, earnedAt: number?, count: number, total: number)
	local old = frame:FindFirstChild("GalaPortrait")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "GalaPortrait"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.15
	gui.Brightness = 1.3
	gui.MaxDistance = 90
	gui.Parent = frame
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = rgb(20, 16, 14)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new(rgb(40, 30, 24), rgb(12, 10, 10))
	grad.Parent = bg
	local function line(text: string, y: number, h: number, font: Font, colour: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.08, y)
		l.Size = UDim2.fromScale(0.84, h)
		l.Text = text
		l.FontFace = font
		l.TextColor3 = colour
		l.TextScaled = true
		l.TextWrapped = true
		l.Parent = bg
		return l
	end
	if badge then
		local colour = TIER[badge.tier] or TIER.gold
		local earned = earnedAt ~= nil
		local glyph = line(badge.glyph, 0.08, 0.3, Brand.Fonts.body, colour)
		glyph.TextTransparency = if earned then 0 else 0.55
		line(badge.name, 0.42, 0.13, Brand.Fonts.display, if earned then rgb(244, 236, 220) else rgb(150, 140, 130))
		line(string.upper(badge.tier) .. (if earned then "" else "  ·  STILL TO EARN"), 0.57, 0.07, Brand.Fonts.bodyBold, colour)
		line(badge.line, 0.67, 0.17, Brand.Fonts.body, rgb(200, 190, 176))
		line(if earned and earnedAt and earnedAt > 0 then "Earned " .. os.date("%d %b %Y", earnedAt) else string.format("Your Badge Book: %d of %d", count, total), 0.87, 0.06, Brand.Fonts.bodyBold, rgb(170, 150, 120))
	else
		line("🖼️", 0.18, 0.28, Brand.Fonts.body, rgb(214, 170, 78))
		line("A frame for your next badge", 0.52, 0.16, Brand.Fonts.display, rgb(200, 190, 176))
	end
end

function GalaView.gallery()
	task.spawn(function()
		local ok, r = pcall(function()
			return Remotes.func("BadgeAsk"):InvokeServer({ op = "state" })
		end)
		if not ok or type(r) ~= "table" or r.ok ~= true or not active then
			return
		end
		local earned: { [string]: number } = if type(r.earned) == "table" then r.earned else {}
		local list: { { badge: BadgeBook.Badge, at: number } } = {}
		for key, at in earned do
			local b = BadgeBook.byKey[key]
			if b then
				table.insert(list, { badge = b, at = tonumber(at) or 0 })
			end
		end
		-- The latest earned first; then the Grand Ballroom's own still to earn.
		table.sort(list, function(a, b)
			return a.at > b.at
		end)
		local hung: { { badge: BadgeBook.Badge, at: number? } } = {}
		for i = 1, math.min(#list, 6) do
			table.insert(hung, { badge = list[i].badge, at = list[i].at })
		end
		for _, b in BadgeBook.List do
			if #hung >= #Plan.FRAMES then
				break
			end
			if b.group == "pavilion" and earned[b.key] == nil then
				table.insert(hung, { badge = b, at = nil })
			end
		end
		local frames = CollectionService:GetTagged("GalaFrame")
		table.sort(frames, function(a, b)
			return (tonumber(a:GetAttribute("Index")) or 0) < (tonumber(b:GetAttribute("Index")) or 0)
		end)
		for i, f in frames do
			if f:IsA("BasePart") then
				local h = hung[i]
				hang(f, if h then h.badge else nil, if h then h.at else nil, tonumber(r.count) or 0, tonumber(r.total) or BadgeBook.count)
			end
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The Runway's spotlight and cameras, the Arena's spotlight
---------------------------------------------------------------------------------------------------
local function glowOn(p: Player)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and not glows[p] then
		local l = Instance.new("PointLight")
		l.Name = "GalaRunwayGlow"
		l.Brightness = 2.2
		l.Range = 16
		l.Color = rgb(255, 240, 220)
		l.Shadows = false
		l.Parent = root
		glows[p] = l
	end
end

local function glowOff(p: Player)
	local l = glows[p]
	if l then
		l:Destroy()
		glows[p] = nil
	end
end

local function watchModel(p: Player)
	local function follow()
		if p:GetAttribute("RunwayModel") == true and active then
			glowOn(p)
		else
			glowOff(p)
		end
	end
	p:GetAttributeChangedSignal("RunwayModel"):Connect(follow)
	follow()
end

-- The cameras at the foot of the catwalk, flashing.
local function flashes()
	local o = origin()
	local at = o + Plan.RUNWAY.finish + Vector3.new(0, 4, -6)
	local p = Instance.new("Part")
	p.Name = "GalaFlashes"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at)
	p.Parent = Workspace
	local l = Instance.new("PointLight")
	l.Brightness = 0
	l.Range = 26
	l.Color = rgb(240, 246, 255)
	l.Parent = p
	task.spawn(function()
		for _ = 1, 7 do
			l.Brightness = 6
			task.wait(0.06)
			l.Brightness = 0
			task.wait(0.12 + math.random() * 0.22)
		end
		p:Destroy()
	end)
	Sound.play("shimmer", 0.5)
end

local function arenaSpot(on: boolean)
	if on and not spot then
		local d = Instance.new("Part")
		d.Name = "GalaArenaSpot"
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		d.Shape = Enum.PartType.Cylinder
		d.Size = Vector3.new(0.1, Plan.SPOT_RADIUS * 2, Plan.SPOT_RADIUS * 2)
		d.Material = Enum.Material.Neon
		d.Color = rgb(255, 230, 170)
		d.Transparency = 0.45
		d.Parent = Workspace
		local l = Instance.new("PointLight")
		l.Brightness = 2.4
		l.Range = 14
		l.Color = rgb(255, 230, 170)
		l.Parent = d
		spot = d
		table.insert(made, d)
	elseif not on and spot then
		spot:Destroy()
		spot = nil
	end
end

local function stepArena()
	local a = arenaPlay
	local d = spot
	if not a or not d then
		return
	end
	local t = serverNow() - (tonumber(a.serverStart) or serverNow())
	local p = origin() + Plan.spotlightAt(t)
	d.CFrame = CFrame.new(p + Vector3.new(0, 0.32, 0)) * CFrame.Angles(0, 0, math.rad(90))
end

---------------------------------------------------------------------------------------------------
-- Dance moves (and poses at the photo sets)
---------------------------------------------------------------------------------------------------
local track: AnimationTrack? = nil
local moveConn: RBXScriptConnection? = nil

function GalaView.stopMove()
	local t = track
	track = nil
	if t then
		pcall(function()
			t:Stop(0.25)
		end)
	end
	if moveConn then
		moveConn:Disconnect()
		moveConn = nil
	end
end

-- Plays a move on this guest's own avatar (a dance loops until they walk away).
function GalaView.move(id: string): boolean
	local m = Plan.moveById[id]
	local anims = (Config.data :: any).Assets.OwnerEmotes or {}
	local animId = m and anims[m.anim]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if type(animId) ~= "string" or animId == "" or not humanoid or not animator then
		return false
	end
	GalaView.stopMove()
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local ok, t = pcall(function()
		return (animator :: Animator):LoadAnimation(anim)
	end)
	if not ok or not t then
		return false
	end
	local tr = t :: AnimationTrack
	tr.Looped = (m :: Plan.Move).loop
	tr.Priority = Enum.AnimationPriority.Action
	tr:Play(0.2)
	track = tr
	-- (Walking off stops a dance.)
	local h = humanoid :: Humanoid
	moveConn = RunService.Heartbeat:Connect(function()
		if h.MoveDirection.Magnitude > 0.2 then
			GalaView.stopMove()
		end
	end)
	return true
end

-- A pose at a photo set: the camera framed on the set, then photo mode.
function GalaView.frameSet(id: string)
	local s = Plan.photoById[id]
	local camera = Workspace.CurrentCamera
	if not s or not camera then
		return
	end
	local o = origin()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(o + s.camera, o + s.look)
	GalaView.photo()
end

---------------------------------------------------------------------------------------------------
-- In and out
---------------------------------------------------------------------------------------------------
function GalaView.active(): boolean
	return active
end

function GalaView.state(): { [string]: any }
	return view
end

function GalaView.update(st: { [string]: any })
	view = st
	if active then
		playRecord(st.juke)
	end
	GalaView.changed(st)
end

function GalaView.enter()
	if active then
		return
	end
	active = true
	light()
	tiles = {}
	for _, t in CollectionService:GetTagged("GalaTile") do
		if t:IsA("BasePart") then
			table.insert(tiles, t)
		end
	end
	sweeps = {}
	for _, h in CollectionService:GetTagged("GalaSweep") do
		if h:IsA("BasePart") then
			-- (Each turns where it hangs.)
			local ok, at = pcall(function()
				return h.Position
			end)
			if ok and typeof(at) == "Vector3" then
				table.insert(sweeps, { part = h, at = at })
			end
		end
	end
	beatConn = RunService.Heartbeat:Connect(function()
		lightTiles()
		stepArena()
	end)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("RunwayModel") == true then
			glowOn(p)
		end
	end
	GalaView.gallery()
	task.spawn(function()
		local ok, r = pcall(function()
			return Remotes.func("AttractionAsk"):InvokeServer({ op = "state", id = Plan.ID })
		end)
		if ok and type(r) == "table" and r.ok == true and active then
			GalaView.update(r)
		end
	end)
end

function GalaView.leave()
	if not active then
		return
	end
	active = false
	if beatConn then
		beatConn:Disconnect()
		beatConn = nil
	end
	stopMusic()
	unlight()
	GalaView.stopMove()
	arenaSpot(false)
	arenaPlay = nil
	for p in glows do
		glowOff(p)
	end
	for _, i in made do
		i:Destroy()
	end
	made = {}
	for _, t in tiles do
		t.Material = Enum.Material.Glass
		t.Color = DARK
		t.Transparency = 0.05
	end
end

-- What the server says that the hall's screen of the world shows.
function GalaView.on(m: { [string]: any })
	if m.kind == "juke" then
		view.juke = m
		if active then
			playRecord(m)
		end
	elseif m.kind == "runway" and m.phase == "posed" then
		if active then
			flashes()
		end
	elseif m.kind == "arena" then
		if m.phase == "play" and m.challenge == "spotlight" then
			arenaPlay = m
			arenaSpot(active)
		elseif m.phase ~= "score" and m.phase ~= "play" then
			arenaPlay = nil
			arenaSpot(false)
		end
	elseif m.kind == "pose" then
		GalaView.frameSet(tostring(m.set))
	end
end

function GalaView.start()
	for _, p in Players:GetPlayers() do
		watchModel(p)
	end
	Players.PlayerAdded:Connect(watchModel)
	Players.PlayerRemoving:Connect(glowOff)
end

return GalaView

--!strict
-- The owner, on every screen, during Admin Abuse: their own avatar (the server builds it from the
-- owner's UserId and keeps it in ReplicatedStorage, so it's there whether or not the owner is in
-- this server), drawn two ways:
--   the hologram  a portrait that slides up at the foot of the screen, lit in gold, doing one of
--                 Roblox's own emotes, with a line ("cast METEOR SHOWER!"): every time the owner
--                 casts something. It sits above any panel, and over the sorting screen too.
--   the colossus  the owner as a giant over the house all night (behind it, facing the street),
--                 dancing, ringed in gold light, a crown of light over their head and searchlights
--                 sweeping up at them: seen from the street, the Terrace and any window. It rises
--                 from behind the house at the opening, and waves goodbye and sinks at the end.
-- Nothing here is touched or kept: it's this screen's own copy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Sound = require(script.Parent.Parent.Sound)

local OwnerCameo = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local GOLD = rgb(255, 204, 110)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local AVATAR = "MaisonOwnerAvatar"

local function cfg(): { [string]: any }
	return (Config.data.Admin :: any).show
end

local function ownerName(): string
	return tostring(Config.data.Admin.ownerName or "The owner")
end

-- The owner's avatar as the server built it, or nil (not built yet, or Roblox couldn't).
function OwnerCameo.template(): Model?
	local m = ReplicatedStorage:FindFirstChild(AVATAR)
	return if m and m:IsA("Model") then m else nil
end

local function emoteId(name: string): string?
	local list = (Config.data.Assets :: any).OwnerEmotes
	local id = if type(list) == "table" then list[name] else nil
	return if type(id) == "string" and id ~= "" then id else nil
end

-- Plays one of Roblox's emotes on a copy of the avatar (what it played before stops).
local function emote(model: Model, name: string, looped: boolean): AnimationTrack?
	local id = emoteId(name)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not id or not humanoid then
		return nil
	end
	local ok, track = pcall(function(): AnimationTrack
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local a = Instance.new("Animator")
			a.Parent = humanoid
			animator = a
		end
		for _, t in (animator :: Animator):GetPlayingAnimationTracks() do
			t:Stop(0.3)
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local t = (animator :: Animator):LoadAnimation(anim)
		t.Looped = looped
		t:Play(0.3)
		return t
	end)
	return if ok then track else nil
end
OwnerCameo.emote = emote

---------------------------------------------------------------------------------------------------
-- The hologram
---------------------------------------------------------------------------------------------------
local function screen(): ScreenGui
	local gui = player:FindFirstChild("PlayerGui")
	local existing = gui and gui:FindFirstChild("MaisonOwnerCameo")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonOwnerCameo"
	s.IgnoreGuiInset = true
	s.ResetOnSpawn = false
	-- (Above the panels and notices: never missed; under the celebrations and headlines.)
	s.DisplayOrder = 64
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = gui
	return s
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

-- A portrait of the owner in a little 3D window: the avatar, waist up, lit warm and gold, doing
-- `pose`. Returns the window (or nil without the avatar).
function OwnerCameo.portrait(parent: GuiObject, pose: string?): ViewportFrame?
	local template = OwnerCameo.template()
	if not template then
		return nil
	end
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Portrait"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.fromScale(1, 1)
	vp.Ambient = rgb(170, 150, 120)
	vp.LightColor = rgb(255, 232, 190)
	vp.LightDirection = Vector3.new(-0.5, -0.8, 0.6)
	vp.Parent = parent
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local model = template:Clone()
	model.Parent = world
	local camera = Instance.new("Camera")
	camera.FieldOfView = 28
	camera.Parent = vp
	vp.CurrentCamera = camera
	pcall(function()
		model:PivotTo(CFrame.new())
		local head = model:FindFirstChild("Head")
		local headY = if head and head:IsA("BasePart") then head.Position.Y else 1.5
		-- (The avatar faces -Z: the camera stands in front of it, a little to one side and below the
		-- eyes, looking up at the face: the owner looks down at you.)
		camera.CFrame = CFrame.lookAt(Vector3.new(1.1, headY - 0.6, -7.2), Vector3.new(0, headY - 0.9, 0))
	end)
	emote(model, pose or "wave", false)
	return vp
end

local cardToken = 0

-- The owner says something on every screen: the hologram slides up, does `pose`, says `line`.
function OwnerCameo.say(line: string, pose: string?, seconds: number?, accent: Color3?)
	cardToken += 1
	local my = cardToken
	local gui = screen()
	local old = gui:FindFirstChild("Cameo")
	if old then
		old:Destroy()
	end
	local tint = accent or GOLD
	local camera = Workspace.CurrentCamera
	local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local width = math.min(430, view.X - 24)
	local card = Instance.new("Frame")
	card.Name = "Cameo"
	-- (At the foot of the screen, in the middle: clear of the keys down the left.)
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, 160)
	card.Size = UDim2.fromOffset(width, 128)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BorderSizePixel = 0
	card.Parent = gui
	corner(card, UDim.new(0, 18))
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(rgb(36, 26, 14), rgb(10, 8, 6))
	fill.Rotation = 90
	fill.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Color = tint
	edge.Thickness = 2
	edge.Parent = card
	-- The hologram's window: a ring of gold, the portrait inside it, a scan of light over it.
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.new(0, 10, 0.5, 0)
	ring.Size = UDim2.fromOffset(108, 108)
	ring.BackgroundColor3 = rgb(24, 18, 10)
	ring.Parent = card
	corner(ring, UDim.new(1, 0))
	local ringEdge = Instance.new("UIStroke")
	ringEdge.Color = tint
	ringEdge.Thickness = 3
	ringEdge.Parent = ring
	local glow = Instance.new("UIGradient")
	glow.Color = ColorSequence.new(rgb(90, 66, 30), rgb(20, 14, 8))
	glow.Rotation = 90
	glow.Parent = ring
	local vp = OwnerCameo.portrait(ring, pose)
	if vp then
		corner(vp, UDim.new(1, 0))
	else
		-- (Without the avatar: the owner's crown.)
		local crown = Instance.new("TextLabel")
		crown.Name = "Crown"
		crown.BackgroundTransparency = 1
		crown.Size = UDim2.fromScale(1, 1)
		crown.TextScaled = true
		crown.Text = "👑"
		crown.Parent = ring
	end
	local scan = Instance.new("Frame")
	scan.Name = "Scan"
	scan.BackgroundColor3 = tint
	scan.BackgroundTransparency = 0.82
	scan.BorderSizePixel = 0
	scan.Size = UDim2.new(1, 0, 0, 6)
	scan.Parent = ring
	-- The words: who, a LIVE mark, and the line.
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(130, 14)
	name.Size = UDim2.new(1, -144, 0, 22)
	name.FontFace = HEAVY
	name.TextSize = 18
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = tint
	name.Text = ownerName() .. "  👑"
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = card
	local live = Instance.new("TextLabel")
	live.Name = "Live"
	live.BackgroundColor3 = rgb(230, 40, 60)
	live.Position = UDim2.fromOffset(130, 40)
	live.Size = UDim2.fromOffset(86, 18)
	live.FontFace = HEAVY
	live.TextSize = 11
	live.TextColor3 = Color3.new(1, 1, 1)
	live.Text = "● THE OWNER"
	live.Parent = card
	corner(live, UDim.new(0, 9))
	local words = Instance.new("TextLabel")
	words.Name = "Line"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(130, 62)
	words.Size = UDim2.new(1, -144, 0, 54)
	words.FontFace = BOLD
	words.TextSize = 20
	words.TextWrapped = true
	words.TextXAlignment = Enum.TextXAlignment.Left
	words.TextYAlignment = Enum.TextYAlignment.Top
	words.TextColor3 = Color3.new(1, 1, 1)
	words.Text = line
	words.MaxVisibleGraphemes = 0
	words.Parent = card
	pcall(Sound.play, "riseWhoosh", 0.9)
	task.delay(0.15, function()
		pcall(Sound.play, "sparklePass", 0.6)
	end)
	TweenService:Create(card, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -18) }):Play()
	-- The words type themselves out; the scan of light runs down the window.
	task.spawn(function()
		local count = utf8.len(line) or #line
		for i = 1, count do
			if cardToken ~= my or not words.Parent then
				return
			end
			words.MaxVisibleGraphemes = i
			task.wait(0.022)
		end
		words.MaxVisibleGraphemes = -1
	end)
	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if cardToken ~= my or not card.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local t = os.clock() - started
		scan.Position = UDim2.new(0, 0, (t * 0.6) % 1, 0)
		ringEdge.Transparency = 0.15 + 0.25 * math.abs(math.sin(t * 3))
		live.BackgroundTransparency = if math.floor(t * 2) % 2 == 0 then 0 else 0.35
	end)
	task.delay(seconds or 4.5, function()
		if cardToken ~= my or not card.Parent then
			return
		end
		local out = TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 1, 160) })
		out:Play()
		out.Completed:Wait()
		if card.Parent then
			card:Destroy()
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The colossus
---------------------------------------------------------------------------------------------------
local colossus: Model? = nil
local colossusParts: { Instance } = {}
local colossusConn: RBXScriptConnection? = nil
local colossusToken = 0
local danceAt = 0
local highlight: Highlight? = nil

local function stage(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

-- Where the giant stands (on the ground behind the house, facing the street) and how big.
local function standing(): (CFrame, number)
	local c = cfg().colossus
	local at = Vector3.new(c.x, c.y, c.z) * Layout.SCALE
	return CFrame.new(at) * CFrame.Angles(0, math.rad(c.turn or 0), 0), c.scale
end

-- The giant's height and where its feet are, once built.
local function measure(model: Model): (number, number)
	local ok, cf, size = pcall(function()
		local cf, size = model:GetBoundingBox()
		return cf, size
	end)
	if ok and typeof(cf) == "CFrame" and typeof(size) == "Vector3" then
		return (size :: Vector3).Y, (cf :: CFrame).Position.Y - (size :: Vector3).Y / 2
	end
	return 5 * cfg().colossus.scale, 0
end

local function build(): Model?
	local template = OwnerCameo.template()
	if not template then
		return nil
	end
	local model = template:Clone()
	model.Name = "OwnerColossus"
	local base, scale = standing()
	pcall(function()
		model:PivotTo(base)
		model:ScaleTo(scale)
	end)
	model.Parent = stage()
	-- Ringed in gold light (a glow round the whole figure, seen from anywhere).
	local h = Instance.new("Highlight")
	h.Name = "Glow"
	h.FillColor = GOLD
	h.FillTransparency = 0.88
	h.OutlineColor = rgb(255, 230, 160)
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = model
	h.Parent = model
	highlight = h
	-- A crown of light over the head, and gold dust drifting off the figure.
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local crownAt = Instance.new("Attachment")
		crownAt.Name = "Crown"
		crownAt.Position = Vector3.new(0, head.Size.Y * 1.1, 0)
		crownAt.Parent = head
		local halo = Instance.new("ParticleEmitter")
		halo.Name = "Halo"
		halo.Texture = SPARK
		halo.Color = ColorSequence.new(GOLD, rgb(255, 245, 210))
		halo.LightEmission = 1
		halo.Rate = 40
		halo.Lifetime = NumberRange.new(1.2, 2)
		halo.Speed = NumberRange.new(2, 6)
		halo.SpreadAngle = Vector2.new(25, 25)
		halo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, head.Size.Y * 0.35), NumberSequenceKeypoint.new(1, 0) })
		halo.Parent = crownAt
		table.insert(colossusParts, halo)
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local dust = Instance.new("ParticleEmitter")
		dust.Name = "GoldDust"
		dust.Texture = SPARK
		dust.Color = ColorSequence.new(GOLD)
		dust.LightEmission = 1
		dust.Rate = 60
		dust.Lifetime = NumberRange.new(3, 5)
		dust.Speed = NumberRange.new(4, 12)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0) })
		dust.Parent = root
		table.insert(colossusParts, dust)
	end
	-- Searchlights at its feet, sweeping up at it.
	local foot = base.Position
	for i = 1, 4 do
		local lamp = Instance.new("Part")
		lamp.Name = "Searchlight"
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.CanQuery = false
		lamp.CanTouch = false
		lamp.Transparency = 1
		lamp.Size = Vector3.new(1, 1, 1)
		lamp.Position = foot + Vector3.new((i - 2.5) * 70, 2, -60)
		lamp.Parent = stage()
		local a0 = Instance.new("Attachment")
		a0.Parent = lamp
		local a1 = Instance.new("Attachment")
		a1.Name = "Tip"
		a1.Parent = lamp
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.Width0 = 6
		beam.Width1 = 60
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(rgb(255, 236, 190))
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		beam.Segments = 2
		beam.Parent = lamp
		table.insert(colossusParts, lamp)
	end
	return model
end

-- The giant is there (rising from behind the house over `rise` seconds, if given), or gone.
function OwnerCameo.colossus(on: boolean, rise: number?, mega: boolean?)
	colossusToken += 1
	local my = colossusToken
	if not on then
		local model = colossus
		local parts = colossusParts
		colossus = nil
		colossusParts = {}
		highlight = nil
		if colossusConn then
			colossusConn:Disconnect()
			colossusConn = nil
		end
		if model then
			-- A wave goodbye, then it sinks behind the house.
			emote(model, "wave", false)
			task.delay(2.2, function()
				local height = measure(model)
				local from = model:GetPivot()
				local started = os.clock()
				while model.Parent and os.clock() - started < 2.5 do
					local k = (os.clock() - started) / 2.5
					pcall(function()
						model:PivotTo(from - Vector3.new(0, height * k * k, 0))
					end)
					RunService.Heartbeat:Wait()
				end
				model:Destroy()
				for _, p in parts do
					p:Destroy()
				end
			end)
		else
			for _, p in parts do
				p:Destroy()
			end
		end
		return
	end
	if colossus and colossus.Parent then
		return
	end
	local model = build()
	if not model then
		return
	end
	colossus = model
	local height, feet = measure(model)
	local ground = cfg().colossus.y * Layout.SCALE
	local stand = model:GetPivot() + Vector3.new(0, ground - feet - height * 0.04, 0)
	local sunk = stand - Vector3.new(0, height * 0.95, 0)
	pcall(function()
		model:PivotTo(if rise then sunk else stand)
	end)
	emote(model, if rise then "cheer" else "dance", not rise)
	danceAt = os.clock() + (rise or 0) + 3
	local started = os.clock()
	local dances = { "dance", "dance2", "dance3" }
	local which = 0
	colossusConn = RunService.Heartbeat:Connect(function()
		if colossusToken ~= my or not model.Parent then
			return
		end
		local t = os.clock() - started
		if rise and t <= rise then
			local k = t / rise
			local e = 1 - (1 - k) ^ 3
			pcall(function()
				model:PivotTo(sunk:Lerp(stand, e))
			end)
		end
		-- A new dance every so often.
		if os.clock() >= danceAt then
			which = which % #dances + 1
			emote(model, dances[which], true)
			danceAt = os.clock() + 12
		end
		-- The searchlights sweep; in Mega Abuse the glow turns through every colour.
		for i, p in colossusParts do
			if p:IsA("Part") then
				local tip = p:FindFirstChild("Tip")
				if tip and tip:IsA("Attachment") then
					local sway = math.sin(t * 0.6 + i * 1.7)
					tip.WorldPosition = stand.Position + Vector3.new(sway * height * 0.35, height * (0.55 + 0.3 * math.sin(t * 0.4 + i)), 0)
				end
			end
		end
		local h = highlight
		if h then
			h.OutlineColor = if mega then Color3.fromHSV((t * 0.12) % 1, 0.55, 1) else rgb(255, 230, 160)
		end
	end)
end

-- The giant does something for a moment (a point when the owner casts a surprise), then dances on.
function OwnerCameo.gesture(name: string)
	local model = colossus
	if model and model.Parent then
		emote(model, name, false)
		danceAt = os.clock() + 2.5
	end
end

function OwnerCameo.isUp(): boolean
	return colossus ~= nil and colossus.Parent ~= nil
end

-- Where the giant stands (for the opening's shot), whether or not it's up.
function OwnerCameo.where(): Vector3
	local base = standing()
	return base.Position
end

return OwnerCameo

--!strict
-- Admin Abuse as a show, on this screen. The server says when it begins, which realm the house is
-- in and when the owner sends a gift; everything is drawn here:
--   the opening   the screen goes cinematic (bars top and bottom), a transmission comes in (the
--                 owner's own avatar in a ring of gold: "XxxXxxX_77797 IS ABUSING THEIR POWERS"),
--                 a riser climbs while the camera flies out over the street and the owner rises,
--                 giant, from behind the house; then the drop: a flash, ADMIN ABUSE slammed onto
--                 the screen, a shockwave, confetti, a sonic boom, and the music. At a table, the
--                 same over the sorting screen (the camera stays).
--   arriving late the giant already standing over the house, and a welcome.
--   the realms    Mega Abuse moves the house from realm to realm (Admin Abuse keeps to the
--                 gilded night): a glitch, a flash, "ENTERING · THE COSMOS", then the house in its
--                 colours, its own air (stars, sweets, gold, neon, bubbles, snow) round the guest,
--                 and the sorting screen with it.
--   the cameos    the owner's hologram whenever they cast a surprise, switch an effect on or start
--                 a giveaway (World/OwnerCameo).
--   the gifts     the owner's gift: a card to open (and a golden box falling beside the guest,
--                 opened by walking into it); the server checks it and pays.
--   the finale    when it ends: the giant waves goodbye and sinks, fireworks, and the guest's haul
--                 (Gilt, gifts, golden pieces, realms).
-- Nothing here changes anything kept: the server pays, this only shows.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AbuseMusic = require(script.Parent.AbuseMusic)
local Fireworks = require(script.Parent.Fireworks)
local OwnerCameo = require(script.Parent.OwnerCameo)
local Sound = require(script.Parent.Parent.Sound)

local AbuseShow = {}

-- Hooks (set by Main).
AbuseShow.isBusy = function(): boolean
	return false -- at a table: the camera stays and nothing moves the guest
end
AbuseShow.cameraMoment = function(_shot: CFrame, _hold: number) end
AbuseShow.cameraShake = function(_size: number, _seconds: number) end

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local GOLD = rgb(255, 204, 110)
local GOLD_LIGHT = rgb(255, 238, 190)
local GOLD_DEEP = rgb(196, 140, 48)
local IMPACT = Font.fromEnum(Enum.Font.LuckiestGuy)
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local CONFETTI = { rgb(255, 60, 140), rgb(80, 140, 255), rgb(90, 255, 170), rgb(255, 214, 80), rgb(246, 206, 112), rgb(255, 240, 200), rgb(190, 90, 255) }

local function cfg(): { [string]: any }
	return (Config.data.Admin :: any).show
end

local function abusing(): boolean
	local ends = Workspace:GetAttribute("AbuseUntil")
	return type(ends) == "number" and ends > Workspace:GetServerTimeNow()
end

local function isMega(): boolean
	return Workspace:GetAttribute("AbuseMega") == true
end

local function sound(name: string, volume: number?, pitch: number?)
	pcall(Sound.play, name, volume or 1, pitch)
end

local function ownerName(): string
	return tostring(Config.data.Admin.ownerName or "The owner")
end

local function view(): Vector2
	local camera = Workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

-- How big to draw, for this screen (a phone smaller, a big monitor larger).
local function unit(): number
	local v = view()
	return math.clamp(math.min(v.X / 1280, v.Y / 720), 0.5, 1.5)
end

---------------------------------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------------------------------
local function screen(): ScreenGui
	local gui = player:FindFirstChild("PlayerGui")
	local existing = gui and gui:FindFirstChild("MaisonAbuseShow")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonAbuseShow"
	s.IgnoreGuiInset = true
	s.ResetOnSpawn = false
	-- (Over the panels, notices and headlines; under the Owner Console.)
	s.DisplayOrder = 72
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = gui
	return s
end

local function frame(parent: Instance, name: string, colour: Color3, alpha: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = alpha
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, text: string, font: Font, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = font
	l.Text = text
	l.TextColor3 = colour
	l.TextScaled = true
	l.Parent = parent
	return l
end

local function corner(parent: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Parent = parent
	return s
end

local function golden(parent: Instance, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, GOLD_LIGHT), ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(1, GOLD_DEEP) })
	g.Rotation = rotation or 90
	g.Parent = parent
end

local function tween(o: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(o, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- A burst of confetti from a point on the screen (falling, turning, gone in a couple of seconds).
local function confettiBurst(parent: Instance, at: Vector2, count: number, power: number)
	local bits: { { f: Frame, x: number, y: number, vx: number, vy: number, spin: number, age: number } } = {}
	for _ = 1, count do
		local size = math.random(6, 13)
		local f = frame(parent, "Confetti", CONFETTI[math.random(1, #CONFETTI)], 0)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.ZIndex = 60
		f.Size = UDim2.fromOffset(size, size * 0.55)
		local a = math.random() * math.pi * 2
		local speed = power * (0.45 + math.random() * 0.75)
		table.insert(bits, { f = f, x = at.X, y = at.Y, vx = math.cos(a) * speed, vy = math.sin(a) * speed - power * 0.35, spin = math.random(-720, 720), age = 0 })
	end
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		local alive = 0
		for _, b in bits do
			if b.f.Parent then
				b.age += dt
				b.vy += 1500 * dt
				b.vx *= 0.985
				b.x += b.vx * dt
				b.y += b.vy * dt
				b.f.Position = UDim2.fromOffset(b.x, b.y)
				b.f.Rotation += b.spin * dt
				b.f.BackgroundTransparency = math.clamp((b.age - 1.6) / 0.6, 0, 1)
				if b.age > 2.3 then
					b.f:Destroy()
				else
					alive += 1
				end
			end
		end
		if alive == 0 and conn then
			conn:Disconnect()
		end
	end)
end

-- A ring of light racing out from a point on the screen.
local function shockwave(parent: Instance, at: Vector2, colour: Color3, reach: number, seconds: number)
	local ring = frame(parent, "Shockwave", Color3.new(1, 1, 1), 1)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(at.X, at.Y)
	ring.Size = UDim2.fromOffset(20, 20)
	corner(ring, UDim.new(1, 0))
	local s = stroke(ring, colour, 16)
	tween(ring, seconds, { Size = UDim2.fromOffset(reach, reach) })
	tween(s, seconds, { Thickness = 2, Transparency = 1 })
	task.delay(seconds + 0.05, function()
		ring:Destroy()
	end)
end

---------------------------------------------------------------------------------------------------
-- The night (what this guest gets, for the finale)
---------------------------------------------------------------------------------------------------
type Night = { since: number, ends: number, gilt: number, gifts: number, golden: number, realms: { [string]: boolean }, mega: boolean }
local night: Night? = nil
local skyHeld = false
local openingSeen = -math.huge -- when this screen last played the opening (os.clock)

local function giltNow(): number
	local g = player:GetAttribute("Gilt")
	return if type(g) == "number" then g else 0
end

-- A golden piece filed during the night (TableClient says).
function AbuseShow.noteGolden(_gilt: number?)
	local n = night
	if n then
		n.golden += 1
	end
end

---------------------------------------------------------------------------------------------------
-- The opening
---------------------------------------------------------------------------------------------------
local openingToken = 0

-- The shot from high over the street: the house, and the owner rising behind it.
local function establishing(): CFrame
	local feet = OwnerCameo.where()
	local front = Layout.Foyer.minZ
	local eye = Vector3.new(feet.X + 46, 108, front - 130)
	local look = Vector3.new(feet.X, 170, feet.Z)
	return CFrame.lookAt(eye, look)
end

function AbuseShow.opening(mega: boolean)
	openingToken += 1
	local my = openingToken
	openingSeen = os.clock()
	local c = cfg()
	local dropAt: number = c.dropAt
	local total: number = c.seconds
	local u = unit()
	local v = view()
	local centre = Vector2.new(v.X / 2, v.Y * 0.44)
	local gui = screen()
	for _, name in { "Opening", "Arrival" } do
		local old = gui:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local root = frame(gui, "Opening", Color3.new(0, 0, 0), 1)
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 1
	-- The picture darkens; cinema bars close in.
	local dim = frame(root, "Dim", Color3.new(0, 0, 0), 1)
	dim.Size = UDim2.fromScale(1, 1)
	tween(dim, 0.5, { BackgroundTransparency = 0.45 })
	local top = frame(root, "BarTop", Color3.new(0, 0, 0), 0)
	top.Size = UDim2.fromScale(1, 0)
	top.ZIndex = 20
	local bottom = frame(root, "BarBottom", Color3.new(0, 0, 0), 0)
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.fromScale(1, 0)
	bottom.ZIndex = 20
	tween(top, 0.5, { Size = UDim2.fromScale(1, 0.11) })
	tween(bottom, 0.5, { Size = UDim2.fromScale(1, 0.11) })
	-- The transmission: the owner in a ring of gold, rings of light pulsing out, the words.
	local holo = frame(root, "Transmission", Color3.new(0, 0, 0), 1)
	holo.Size = UDim2.fromScale(1, 1)
	holo.ZIndex = 5
	local d = 230 * u
	local ring = frame(holo, "Ring", rgb(20, 14, 8), 0.1)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(centre.X, centre.Y - 30 * u)
	ring.Size = UDim2.fromOffset(d, d)
	ring.ZIndex = 6
	corner(ring, UDim.new(1, 0))
	local ringEdge = stroke(ring, GOLD, 5 * u)
	local ringScale = Instance.new("UIScale")
	ringScale.Scale = 0.2
	ringScale.Parent = ring
	tween(ringScale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	local portrait = OwnerCameo.portrait(ring, "point")
	if portrait then
		portrait.ZIndex = 7
		corner(portrait, UDim.new(1, 0))
	else
		local crown = label(ring, "Crown", "👑", HEAVY, GOLD)
		crown.ZIndex = 7
		crown.Size = UDim2.fromScale(0.7, 0.7)
		crown.AnchorPoint = Vector2.new(0.5, 0.5)
		crown.Position = UDim2.fromScale(0.5, 0.5)
	end
	local pulses: { Frame } = {}
	for i = 1, 3 do
		local p = frame(holo, "Pulse", Color3.new(1, 1, 1), 1)
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = ring.Position
		p.Size = UDim2.fromOffset(d, d)
		p.ZIndex = 5
		corner(p, UDim.new(1, 0))
		stroke(p, if mega then rgb(200, 120, 255) else GOLD, 3)
		p:SetAttribute("Phase", (i - 1) / 3)
		table.insert(pulses, p)
	end
	local chip = label(holo, "Live", "●  LIVE  ·  INCOMING TRANSMISSION", HEAVY, Color3.new(1, 1, 1))
	chip.BackgroundTransparency = 0
	chip.BackgroundColor3 = rgb(220, 30, 60)
	chip.AnchorPoint = Vector2.new(0.5, 1)
	chip.Position = UDim2.fromOffset(centre.X, centre.Y - 30 * u - d / 2 - 14 * u)
	chip.Size = UDim2.fromOffset(330 * u, 28 * u)
	chip.ZIndex = 8
	corner(chip, UDim.new(0, 14 * u))
	local name = label(holo, "Name", string.upper(ownerName()), IMPACT, Color3.new(1, 1, 1))
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.fromOffset(centre.X, centre.Y - 30 * u + d / 2 + 16 * u)
	name.Size = UDim2.fromOffset(math.min(v.X - 40, 640 * u), 58 * u)
	name.ZIndex = 8
	golden(name)
	stroke(name, rgb(40, 24, 6), 3)
	local what = label(holo, "What", if mega then "HAS BROKEN THE MULTIVERSE" else "IS ABUSING THEIR POWERS", HEAVY, Color3.new(1, 1, 1))
	what.AnchorPoint = Vector2.new(0.5, 0)
	what.Position = UDim2.fromOffset(centre.X, centre.Y - 30 * u + d / 2 + 78 * u)
	what.Size = UDim2.fromOffset(math.min(v.X - 40, 560 * u), 32 * u)
	what.ZIndex = 8
	-- (A glitch: the words jump, a red and a blue ghost behind them.)
	local ghostR = label(holo, "GhostR", what.Text, HEAVY, rgb(255, 40, 80))
	ghostR.AnchorPoint = what.AnchorPoint
	ghostR.Position = what.Position
	ghostR.Size = what.Size
	ghostR.TextTransparency = 0.45
	ghostR.ZIndex = 7
	local ghostB = ghostR:Clone()
	ghostB.Name = "GhostB"
	ghostB.TextColor3 = rgb(40, 200, 255)
	ghostB.Parent = holo
	-- Flash and title, ready for the drop.
	local flash = frame(root, "Flash", Color3.new(1, 1, 1), 1)
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 15
	-- The music waits for the drop; the house's music falls away under the riser.
	pcall(AbuseMusic.holdFor, dropAt)
	pcall(Sound.hush, dropAt)
	sound("glitch", 0.8)
	sound("showRiser", 1)
	task.delay(math.max(0, dropAt - 2.75), function()
		if openingToken == my then
			sound("showBuild", 1)
		end
	end)
	task.delay(0.5, function()
		if openingToken == my then
			sound("heavenly", 0.7)
		end
	end)
	-- The owner rises behind the house; the camera flies out to see it (not at a table).
	OwnerCameo.colossus(true, dropAt - 0.2, mega)
	if not AbuseShow.isBusy() then
		pcall(AbuseShow.cameraMoment, establishing(), math.max(1, total - 3.2))
	end
	local started = os.clock()
	local dropped = false
	local shakeLeft = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		if openingToken ~= my or not root.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local t = os.clock() - started
		if not dropped then
			for _, p in pulses do
				local k = ((t * 1.1) + (p:GetAttribute("Phase") :: number)) % 1
				p.Size = UDim2.fromOffset(d * (1 + k * 1.3), d * (1 + k * 1.3))
				local s = p:FindFirstChildOfClass("UIStroke")
				if s then
					s.Transparency = k
				end
			end
			ringEdge.Transparency = 0.1 + 0.3 * math.abs(math.sin(t * 7))
			chip.BackgroundTransparency = if math.floor(t * 3) % 2 == 0 then 0 else 0.3
			-- The glitch comes harder as the drop nears.
			local hard = math.clamp(t / dropAt, 0, 1)
			local jump = if math.random() < 0.18 + hard * 0.4 then (math.random() - 0.5) * 14 * u * (0.5 + hard) else 0
			what.Position = UDim2.fromOffset(centre.X + jump, centre.Y - 30 * u + d / 2 + 78 * u)
			ghostR.Position = UDim2.fromOffset(centre.X + jump - 5 * u * (0.5 + hard), centre.Y - 30 * u + d / 2 + 78 * u)
			ghostB.Position = UDim2.fromOffset(centre.X + jump + 5 * u * (0.5 + hard), centre.Y - 30 * u + d / 2 + 78 * u)
			ringScale.Scale = 1 + hard * 0.08 + (if math.random() < hard * 0.3 then 0.04 else 0)
		end
		if shakeLeft > 0 then
			shakeLeft = math.max(0, shakeLeft - dt)
			local k = shakeLeft / 0.8
			root.Position = UDim2.fromOffset((math.random() - 0.5) * 34 * k * u, (math.random() - 0.5) * 24 * k * u)
		else
			root.Position = UDim2.fromOffset(0, 0)
		end
	end)
	-- The drop.
	task.delay(dropAt, function()
		if openingToken ~= my or not root.Parent then
			return
		end
		dropped = true
		holo:Destroy()
		flash.BackgroundTransparency = 0
		tween(flash, 0.9, { BackgroundTransparency = 1 })
		tween(dim, 0.4, { BackgroundTransparency = 0.6 })
		shakeLeft = 0.8
		sound("showDrop", 1.1)
		sound("sonicBoom", 1)
		sound("subHit", 1)
		for i = 0, 2 do
			task.delay(i * 0.32, function()
				sound("airHorn", 1, 1 + i * 0.06)
			end)
		end
		task.delay(0.5, sound, "crowdCheer", 0.8)
		pcall(AbuseShow.cameraShake, 1.4, 0.9)
		-- The title: slammed down, a red and a blue ghost closing in on it.
		local words = if mega then "MEGA ABUSE" else "ADMIN ABUSE"
		local titleSize = UDim2.fromOffset(math.min(v.X - 30, 980 * u), 150 * u)
		local titleAt = UDim2.fromOffset(centre.X, centre.Y)
		local title = label(root, "Title", words, IMPACT, Color3.new(1, 1, 1))
		title.AnchorPoint = Vector2.new(0.5, 0.5)
		title.Position = titleAt
		title.Size = titleSize
		-- (Over the flash: the words land on the white, then the picture comes back round them.)
		title.ZIndex = 17
		if mega then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(255, 80, 200)), ColorSequenceKeypoint.new(0.35, rgb(255, 214, 80)), ColorSequenceKeypoint.new(0.7, rgb(90, 255, 200)), ColorSequenceKeypoint.new(1, rgb(150, 110, 255)) })
			g.Parent = title
		else
			golden(title)
		end
		stroke(title, rgb(30, 16, 4), 5)
		local scale = Instance.new("UIScale")
		scale.Scale = 3.2
		scale.Parent = title
		tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		for i, colour in { rgb(255, 40, 90), rgb(40, 210, 255) } do
			local ghost = label(root, "Ghost", words, IMPACT, colour)
			ghost.AnchorPoint = Vector2.new(0.5, 0.5)
			ghost.Size = titleSize
			ghost.Position = UDim2.fromOffset(centre.X + (if i == 1 then -40 else 40) * u, centre.Y)
			ghost.TextTransparency = 0.35
			ghost.ZIndex = 16
			tween(ghost, 0.7, { Position = titleAt, TextTransparency = 1 }, Enum.EasingStyle.Quint)
			task.delay(0.75, function()
				ghost:Destroy()
			end)
		end
		local sub = label(root, "Sub", if mega then "TRIPLE GILT  ·  A NEW REALM EVERY 90s  ·  GIFTS FROM THE OWNER  ·  GIVEAWAYS" else "DOUBLE GILT  ·  GOLDEN PIECES  ·  GIFTS FROM THE OWNER  ·  SURPRISES ALL NIGHT", HEAVY, GOLD_LIGHT)
		sub.AnchorPoint = Vector2.new(0.5, 0)
		sub.Position = UDim2.fromOffset(centre.X, centre.Y + 82 * u)
		sub.Size = UDim2.fromOffset(math.min(v.X - 40, 860 * u), 26 * u)
		sub.ZIndex = 12
		sub.TextTransparency = 1
		sub.ZIndex = 17
		task.delay(0.35, function()
			tween(sub, 0.4, { TextTransparency = 0 })
		end)
		shockwave(root, centre, if mega then rgb(220, 140, 255) else GOLD, math.max(v.X, v.Y) * 1.8, 0.8)
		task.delay(0.12, shockwave, root, centre, Color3.new(1, 1, 1), math.max(v.X, v.Y) * 1.2, 0.7)
		confettiBurst(root, centre, 90, 1100 * u)
	end)
	-- The way out: the title lifts away, the bars open.
	task.delay(total - 1.2, function()
		if openingToken ~= my or not root.Parent then
			return
		end
		local title = root:FindFirstChild("Title")
		if title and title:IsA("TextLabel") then
			tween(title, 0.7, { Position = UDim2.fromOffset(centre.X, -80 * u), TextTransparency = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			local s = title:FindFirstChildOfClass("UIStroke")
			if s then
				tween(s, 0.5, { Transparency = 1 })
			end
		end
		local sub = root:FindFirstChild("Sub")
		if sub and sub:IsA("TextLabel") then
			tween(sub, 0.4, { TextTransparency = 1 })
		end
		tween(top, 0.6, { Size = UDim2.fromScale(1, 0) })
		tween(bottom, 0.6, { Size = UDim2.fromScale(1, 0) })
		tween(dim, 0.6, { BackgroundTransparency = 1 })
	end)
	task.delay(total, function()
		if openingToken ~= my then
			return
		end
		root:Destroy()
		OwnerCameo.say(if mega then "MEGA ABUSE IS ON! The multiverse is open. Don't you dare leave! 🌋" else "ADMIN ABUSE IS ON! Gifts, golden pieces, surprises. Let's GO! 🔥", "cheer", 5)
		-- (Mega Abuse's first realm, named now the opening is over.)
		if mega then
			task.delay(0.6, AbuseShow.announceRealm)
		end
	end)
end

-- Arriving while it's on: the giant already up, a welcome.
function AbuseShow.arrived(mega: boolean)
	OwnerCameo.colossus(true, nil, mega)
	local gui = screen()
	local u = unit()
	local v = view()
	local old = gui:FindFirstChild("Arrival")
	if old then
		old:Destroy()
	end
	local card = frame(gui, "Arrival", Color3.new(1, 1, 1), 0)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, -120 * u)
	card.Size = UDim2.fromOffset(math.min(v.X - 24, 620 * u), 96 * u)
	corner(card, UDim.new(0, 18 * u))
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(rgb(40, 28, 12), rgb(12, 9, 6))
	fill.Rotation = 90
	fill.Parent = card
	stroke(card, if mega then rgb(210, 130, 255) else GOLD, 2)
	local big = label(card, "Title", if mega then "YOU ARRIVED DURING MEGA ABUSE!" else "YOU ARRIVED DURING ADMIN ABUSE!", IMPACT, Color3.new(1, 1, 1))
	big.Position = UDim2.new(0, 16 * u, 0, 10 * u)
	big.Size = UDim2.new(1, -32 * u, 0, 44 * u)
	golden(big)
	local small = label(card, "Line", if mega then "Triple Gilt, a new realm every minute and a half, gifts from the owner." else "Double Gilt, golden pieces at every table, gifts from the owner.", BOLD, rgb(240, 230, 210))
	small.Position = UDim2.new(0, 16 * u, 0, 58 * u)
	small.Size = UDim2.new(1, -32 * u, 0, 24 * u)
	sound("stinger", 0.8)
	tween(card, 0.5, { Position = UDim2.new(0.5, 0, 0, 70 * u) }, Enum.EasingStyle.Back)
	task.delay(5.5, function()
		if card.Parent then
			tween(card, 0.4, { Position = UDim2.new(0.5, 0, 0, -140 * u) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.45, function()
				card:Destroy()
			end)
		end
	end)
	OwnerCameo.say("Welcome in! You made it for Admin Abuse. Grab the gifts! 🎁", "wave", 5)
end

---------------------------------------------------------------------------------------------------
-- The realms
---------------------------------------------------------------------------------------------------
type Realm = {
	name: string,
	line: string,
	glyph: string,
	colour: Color3,
	tint: Color3,
	brightness: number,
	contrast: number,
	saturation: number,
	bloom: number,
	air: { colours: { Color3 }, rate: number, size: number, speed: number, fall: number, light: number },
	stars: boolean?,
}

-- How each realm looks (its name and line are HouseEvents.Realms').
local LOOKS = {
	gilded = { colour = GOLD, tint = rgb(255, 236, 205), brightness = 0.02, contrast = 0.1, saturation = 0.12, bloom = 0.7, air = { colours = { GOLD, GOLD_LIGHT }, rate = 26, size = 0.45, speed = 2, fall = -2, light = 1 } },
	cosmos = { colour = rgb(170, 150, 255), tint = rgb(190, 180, 255), brightness = -0.08, contrast = 0.2, saturation = 0.25, bloom = 1.1, air = { colours = { rgb(220, 220, 255), rgb(170, 140, 255), rgb(120, 200, 255) }, rate = 40, size = 0.35, speed = 1, fall = 0, light = 1 }, stars = true },
	candy = { colour = rgb(255, 130, 210), tint = rgb(255, 210, 238), brightness = 0.08, contrast = 0.05, saturation = 0.45, bloom = 0.9, air = { colours = { rgb(255, 120, 200), rgb(130, 230, 255), rgb(255, 240, 150) }, rate = 50, size = 0.6, speed = 3, fall = -3, light = 0.8 } },
	midas = { colour = rgb(255, 214, 90), tint = rgb(255, 218, 150), brightness = 0.05, contrast = 0.15, saturation = -0.2, bloom = 1.2, air = { colours = { rgb(255, 214, 90), rgb(255, 245, 200) }, rate = 60, size = 0.5, speed = 4, fall = 10, light = 1 } },
	neon = { colour = rgb(80, 255, 240), tint = rgb(205, 170, 255), brightness = -0.1, contrast = 0.4, saturation = 0.65, bloom = 1.6, air = { colours = { rgb(80, 255, 240), rgb(255, 60, 220), rgb(255, 240, 80) }, rate = 55, size = 0.4, speed = 6, fall = -8, light = 1 } },
	abyss = { colour = rgb(80, 200, 255), tint = rgb(150, 210, 255), brightness = -0.08, contrast = 0.1, saturation = 0.1, bloom = 0.8, air = { colours = { rgb(200, 240, 255), rgb(120, 210, 255) }, rate = 45, size = 0.7, speed = 3, fall = -6, light = 0.5 } },
	frost = { colour = rgb(210, 240, 255), tint = rgb(225, 242, 255), brightness = 0.1, contrast = 0.05, saturation = -0.35, bloom = 0.9, air = { colours = { Color3.new(1, 1, 1), rgb(220, 240, 255) }, rate = 220, size = 0.3, speed = 3, fall = 6, light = 0.5 } },
} :: { [string]: any }

AbuseShow.Realms = {} :: { [string]: Realm }
for _, info in HouseEvents.Realms do
	local look = LOOKS[info.id]
	if look then
		AbuseShow.Realms[info.id] = {
			name = info.name,
			line = info.line,
			glyph = info.glyph,
			colour = look.colour,
			tint = look.tint,
			brightness = look.brightness,
			contrast = look.contrast,
			saturation = look.saturation,
			bloom = look.bloom,
			air = look.air,
			stars = look.stars,
		}
	end
end

local realmNow: string? = nil
local realmToken = 0
local realmBits: { Instance } = {}
local realmConn: RBXScriptConnection? = nil

local function rootOf(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function localStage(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

local function clearRealm()
	realmToken += 1
	if realmConn then
		realmConn:Disconnect()
		realmConn = nil
	end
	local bits = realmBits
	realmBits = {}
	for _, b in bits do
		if b:IsA("ColorCorrectionEffect") then
			tween(b, 1, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Contrast = 0, Saturation = 0 })
		elseif b:IsA("BloomEffect") then
			tween(b, 1, { Intensity = 0 })
		elseif b:IsA("ParticleEmitter") then
			b.Enabled = false
		end
	end
	task.delay(1.2, function()
		for _, b in bits do
			b:Destroy()
		end
	end)
end

-- The realm's own air round the guest: a box of drifting motes that follows them.
local function realmAir(r: Realm)
	local box = Instance.new("Part")
	box.Name = "RealmAir"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = Vector3.new(90, 36, 90)
	box.Parent = localStage()
	table.insert(realmBits, box)
	local att = Instance.new("Attachment")
	att.Parent = box
	local e = Instance.new("ParticleEmitter")
	e.Name = "Air"
	e.Texture = SPARK
	local keys = {}
	for i, colour in r.air.colours do
		table.insert(keys, ColorSequenceKeypoint.new((i - 1) / math.max(1, #r.air.colours - 1), colour))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, r.air.colours[1]))
	end
	e.Color = ColorSequence.new(keys)
	e.LightEmission = r.air.light
	e.Rate = r.air.rate
	e.Lifetime = NumberRange.new(3, 6)
	e.Speed = NumberRange.new(r.air.speed * 0.5, r.air.speed)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -r.air.fall, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, r.air.size), NumberSequenceKeypoint.new(0.85, r.air.size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.6) })
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Parent = att
	table.insert(realmBits, e)
	local my = realmToken
	realmConn = RunService.Heartbeat:Connect(function()
		if realmToken ~= my then
			return
		end
		local root = rootOf()
		if root then
			box.Position = root.Position + Vector3.new(0, 10, 0)
		end
	end)
end

-- The cosmos: stars all round the sky and a ringed planet over the house.
local function realmStars()
	local folder = Instance.new("Folder")
	folder.Name = "RealmStars"
	folder.Parent = localStage()
	table.insert(realmBits, folder)
	local centre = OwnerCameo.where() * Vector3.new(1, 0, 0.5)
	local rng = Random.new(54)
	for _ = 1, 180 do
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.1, 1), rng:NextNumber(-1, 1)).Unit
		local s = Instance.new("Part")
		s.Name = "Star"
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Material = Enum.Material.Neon
		s.Shape = Enum.PartType.Ball
		s.Color = Color3.new(1, 1, 1):Lerp(rgb(170, 190, 255), rng:NextNumber())
		s.Size = Vector3.one * rng:NextNumber(1.5, 4)
		s.Position = centre + dir * rng:NextNumber(700, 900)
		s.Parent = folder
	end
	local planet = Instance.new("Part")
	planet.Name = "Planet"
	planet.Anchored = true
	planet.CanCollide = false
	planet.CanQuery = false
	planet.CanTouch = false
	planet.Shape = Enum.PartType.Ball
	planet.Material = Enum.Material.SmoothPlastic
	planet.Color = rgb(150, 110, 230)
	planet.Size = Vector3.one * 180
	planet.Position = centre + Vector3.new(-420, 330, 520)
	planet.Parent = folder
	local ring = Instance.new("Part")
	ring.Name = "PlanetRing"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = rgb(240, 210, 150)
	ring.Transparency = 0.45
	ring.Size = Vector3.new(2, 380, 380)
	ring.CFrame = CFrame.new(planet.Position) * CFrame.Angles(math.rad(70), 0, math.rad(20))
	ring.Parent = folder
end

-- The shift: a glitch, a flash, the realm's name.
local function shiftCard(r: Realm)
	local gui = screen()
	local u = unit()
	local v = view()
	local old = gui:FindFirstChild("Shift")
	if old then
		old:Destroy()
	end
	local root = frame(gui, "Shift", Color3.new(0, 0, 0), 1)
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = 30
	sound("warpBurst", 0.9)
	sound("glitch", 0.7)
	-- The glitch: bars of colour tearing across the picture.
	local bars: { Frame } = {}
	for _ = 1, 12 do
		local b = frame(root, "Tear", Color3.new(1, 1, 1), 0.5)
		b.ZIndex = 31
		table.insert(bars, b)
	end
	local colours = { r.colour, Color3.new(1, 1, 1), rgb(255, 40, 120), rgb(40, 220, 255) }
	local word = label(root, "Word", "REALM SHIFT", IMPACT, Color3.new(1, 1, 1))
	word.AnchorPoint = Vector2.new(0.5, 0.5)
	word.Position = UDim2.fromScale(0.5, 0.45)
	word.Size = UDim2.fromOffset(math.min(v.X - 40, 760 * u), 110 * u)
	word.ZIndex = 33
	stroke(word, rgb(20, 10, 30), 4)
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if not root.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		for _, b in bars do
			b.BackgroundColor3 = colours[math.random(1, #colours)]
			b.BackgroundTransparency = 0.25 + math.random() * 0.6
			b.Position = UDim2.fromScale(math.random() * 0.2 - 0.1, math.random())
			b.Size = UDim2.new(1.2, 0, 0, math.random(4, 46) * u)
		end
		word.Position = UDim2.new(0.5, (math.random() - 0.5) * 30 * u, 0.45, (math.random() - 0.5) * 12 * u)
		word.TextColor3 = colours[math.random(1, #colours)]
	end)
	task.delay(0.6, function()
		if conn then
			conn:Disconnect()
		end
		if not root.Parent then
			return
		end
		for _, b in bars do
			b:Destroy()
		end
		word:Destroy()
		local flash = frame(root, "Flash", Color3.new(1, 1, 1), 0)
		flash.Size = UDim2.fromScale(1, 1)
		flash.ZIndex = 32
		tween(flash, 0.6, { BackgroundTransparency = 1 })
		sound("stinger", 0.9)
		sound("subHit", 0.8)
		local card = frame(root, "Card", Color3.new(0, 0, 0), 1)
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.4)
		card.Size = UDim2.fromOffset(math.min(v.X - 30, 820 * u), 230 * u)
		card.ZIndex = 33
		local glyph = label(card, "Glyph", r.glyph, HEAVY, Color3.new(1, 1, 1))
		glyph.AnchorPoint = Vector2.new(0.5, 0)
		glyph.Position = UDim2.fromScale(0.5, 0)
		glyph.Size = UDim2.fromOffset(84 * u, 84 * u)
		glyph.ZIndex = 34
		local entering = label(card, "Entering", "E N T E R I N G", HEAVY, Color3.new(1, 1, 1))
		entering.AnchorPoint = Vector2.new(0.5, 0)
		entering.Position = UDim2.new(0.5, 0, 0, 86 * u)
		entering.Size = UDim2.fromOffset(300 * u, 20 * u)
		entering.ZIndex = 34
		local name = label(card, "Realm", r.name, IMPACT, r.colour)
		name.AnchorPoint = Vector2.new(0.5, 0)
		name.Position = UDim2.new(0.5, 0, 0, 108 * u)
		name.Size = UDim2.new(1, 0, 0, 80 * u)
		name.ZIndex = 34
		stroke(name, rgb(16, 10, 24), 4)
		local line = label(card, "Line", r.line, BOLD, rgb(245, 240, 230))
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0.5, 0, 0, 192 * u)
		line.Size = UDim2.new(0.9, 0, 0, 26 * u)
		line.ZIndex = 34
		local scale = Instance.new("UIScale")
		scale.Scale = 0.4
		scale.Parent = card
		tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(3, function()
			if card.Parent then
				tween(scale, 0.35, { Scale = 0.6 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				for _, l in { glyph, entering, name, line } do
					tween(l, 0.35, { TextTransparency = 1 })
				end
				local s = name:FindFirstChildOfClass("UIStroke")
				if s then
					tween(s, 0.3, { Transparency = 1 })
				end
			end
			task.delay(0.4, function()
				root:Destroy()
			end)
		end)
	end)
end

-- The house in a realm (or back to itself). `announce`: with the shift's glitch and name.
function AbuseShow.realm(id: string?, announce: boolean)
	if id == realmNow then
		return
	end
	clearRealm()
	realmNow = id
	local r = if id then AbuseShow.Realms[id] else nil
	if not r then
		return
	end
	local n = night
	if n and id then
		n.realms[id] = true
	end
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "AbuseRealm"
	cc.Parent = Lighting
	table.insert(realmBits, cc)
	tween(cc, 1.2, { TintColor = r.tint, Brightness = r.brightness, Contrast = r.contrast, Saturation = r.saturation })
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "AbuseRealmBloom"
	bloom.Intensity = 0
	bloom.Size = 30
	bloom.Threshold = 0.85
	bloom.Parent = Lighting
	table.insert(realmBits, bloom)
	tween(bloom, 1.2, { Intensity = r.bloom })
	realmAir(r)
	if r.stars then
		realmStars()
	end
	if announce then
		shiftCard(r)
	end
end

function AbuseShow.realmNow(): string?
	return realmNow
end

-- The name of the realm the house is in, shown now (after the opening).
function AbuseShow.announceRealm()
	local r = if realmNow then AbuseShow.Realms[realmNow] else nil
	if r and isMega() then
		shiftCard(r)
	end
end

---------------------------------------------------------------------------------------------------
-- The gifts
---------------------------------------------------------------------------------------------------
local giftToken = 0
local giftBox: () -> () = function() end -- (the last gift's box beside the guest, taken away)

-- Where the floor is below a point (or the point itself).
local function floorBelow(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { localStage() }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

-- A golden box falling from the sky beside the guest; walking into it opens the gift.
local function fallingGift(onTouch: () -> ()): () -> ()
	local root = rootOf()
	if not root or AbuseShow.isBusy() then
		return function() end
	end
	local a = math.random() * math.pi * 2
	local landAt = floorBelow(root.Position + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9)) + Vector3.new(0, 1.6, 0)
	local model = Instance.new("Model")
	model.Name = "OwnerGift"
	local function piece(name: string, size: Vector3, colour: Color3, material: Enum.Material, offset: CFrame): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.Color = colour
		p.Material = material
		p:SetAttribute("Offset", offset)
		p.Parent = model
		return p
	end
	local box = piece("Box", Vector3.new(3.2, 3.2, 3.2), GOLD, Enum.Material.SmoothPlastic, CFrame.new())
	box.Reflectance = 0.25
	piece("RibbonA", Vector3.new(3.3, 3.3, 0.6), rgb(220, 30, 60), Enum.Material.SmoothPlastic, CFrame.new())
	piece("RibbonB", Vector3.new(0.6, 3.3, 3.3), rgb(220, 30, 60), Enum.Material.SmoothPlastic, CFrame.new())
	piece("BowL", Vector3.new(1.3, 1.3, 1.3), rgb(240, 50, 80), Enum.Material.SmoothPlastic, CFrame.new(-0.7, 1.9, 0))
	piece("BowR", Vector3.new(1.3, 1.3, 1.3), rgb(240, 50, 80), Enum.Material.SmoothPlastic, CFrame.new(0.7, 1.9, 0))
	model.PrimaryPart = box
	model.Parent = localStage()
	local glow = Instance.new("PointLight")
	glow.Color = GOLD
	glow.Range = 18
	glow.Brightness = 2.5
	glow.Parent = box
	local att = Instance.new("Attachment")
	att.Parent = box
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = SPARK
	sparkle.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
	sparkle.LightEmission = 1
	sparkle.Rate = 30
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = att
	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(120, 34)
	tag.StudsOffset = Vector3.new(0, 4, 0)
	tag.AlwaysOnTop = true
	tag.LightInfluence = 0
	tag.MaxDistance = 80
	tag.Parent = box
	local tagText = label(tag, "Text", "🎁 WALK INTO IT", HEAVY, GOLD_LIGHT)
	tagText.Size = UDim2.fromScale(1, 1)
	stroke(tagText, rgb(30, 18, 4), 2)
	local function place(cf: CFrame)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				local offset = p:GetAttribute("Offset")
				p.CFrame = cf * (if typeof(offset) == "CFrame" then offset else CFrame.new())
			end
		end
	end
	local from = landAt + Vector3.new(0, 70, 0)
	local started = os.clock()
	local landed = false
	local done = false
	local conn: RBXScriptConnection? = nil
	local function finish()
		if done then
			return
		end
		done = true
		if conn then
			conn:Disconnect()
		end
		sparkle.Rate = 0
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = SPARK
		burst.Color = ColorSequence.new(GOLD, Color3.new(1, 1, 1))
		burst.LightEmission = 1
		burst.Rate = 0
		burst.Speed = NumberRange.new(10, 26)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Lifetime = NumberRange.new(0.6, 1.2)
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
		burst.Parent = att
		pcall(function()
			burst:Emit(70)
		end)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
		tag.Enabled = false
		task.delay(1.4, function()
			model:Destroy()
		end)
	end
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		if not landed then
			local k = math.min(1, t / 1.5)
			place(CFrame.new(from:Lerp(landAt, k * k)) * CFrame.Angles(t * 2, t * 3, 0))
			if k >= 1 then
				landed = true
				sound("fairyDust", 0.9)
				sound("lowHit", 0.6)
			end
			return
		end
		place(CFrame.new(landAt + Vector3.new(0, 0.4 + math.sin(t * 3) * 0.4, 0)) * CFrame.Angles(0, t * 1.4, 0))
		local me = rootOf()
		if me and (me.Position - landAt).Magnitude < 7 then
			onTouch()
		end
	end)
	return finish
end

-- The owner's gift on this screen: a card to open, and a box beside the guest.
function AbuseShow.gift(m: { [string]: any })
	local id = m.id
	if type(id) ~= "number" then
		return
	end
	giftToken += 1
	local my = giftToken
	local gilt = if type(m.gilt) == "number" then m.gilt else 0
	local crown = m.crown == true
	local bonus = if type(m.bonus) == "number" then m.bonus else nil
	local seconds = if type(m.seconds) == "number" then m.seconds else 25
	local gui = screen()
	local u = unit()
	local old = gui:FindFirstChild("Gift")
	if old then
		old:Destroy()
	end
	pcall(giftBox)
	local width = math.min(view().X - 24, 300 * u)
	local card = frame(gui, "Gift", Color3.new(1, 1, 1), 0)
	card.AnchorPoint = Vector2.new(1, 0.5)
	card.Position = UDim2.new(1, width + 40, 0.52, 0)
	card.Size = UDim2.fromOffset(width, 236 * u)
	card.ZIndex = 40
	corner(card, UDim.new(0, 20 * u))
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(rgb(52, 36, 14), rgb(14, 10, 6))
	fill.Rotation = 90
	fill.Parent = card
	local edge = stroke(card, GOLD, 3)
	local head = label(card, "Head", "A GIFT FROM " .. string.upper(ownerName()), HEAVY, GOLD)
	head.Position = UDim2.new(0, 14 * u, 0, 12 * u)
	head.Size = UDim2.new(1, -28 * u, 0, 18 * u)
	head.ZIndex = 41
	-- The present, on a turning sunburst.
	local burst = frame(card, "Sunburst", GOLD, 0.55)
	burst.AnchorPoint = Vector2.new(0.5, 0.5)
	burst.Position = UDim2.new(0.5, 0, 0, 78 * u)
	burst.Size = UDim2.fromOffset(96 * u, 96 * u)
	burst.ZIndex = 41
	corner(burst, UDim.new(1, 0))
	local rays = Instance.new("UIGradient")
	rays.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.9), NumberSequenceKeypoint.new(1, 0.2) })
	rays.Parent = burst
	local box = label(card, "Present", "🎁", HEAVY, Color3.new(1, 1, 1))
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(0.5, 0, 0, 78 * u)
	box.Size = UDim2.fromOffset(74 * u, 74 * u)
	box.ZIndex = 42
	local reward = label(card, "Reward", "+" .. tostring(gilt) .. " GILT" .. (if crown then "  +  👑 THE ADMIN'S CROWN" elseif bonus then "  +  " .. tostring(bonus) .. " BONUS" else ""), HEAVY, Color3.new(1, 1, 1))
	reward.Position = UDim2.new(0, 14 * u, 0, 130 * u)
	reward.Size = UDim2.new(1, -28 * u, 0, 22 * u)
	reward.ZIndex = 41
	local button = Instance.new("TextButton")
	button.Name = "Open"
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.Position = UDim2.new(0.5, 0, 0, 160 * u)
	button.Size = UDim2.new(1, -28 * u, 0, 48 * u)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = true
	button.FontFace = IMPACT
	button.TextScaled = true
	button.TextColor3 = rgb(40, 24, 6)
	button.Text = "OPEN IT!"
	button.ZIndex = 42
	button.Parent = card
	corner(button, UDim.new(0, 14 * u))
	golden(button)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8 * u)
	pad.PaddingBottom = UDim.new(0, 6 * u)
	pad.Parent = button
	local timer = frame(card, "Timer", GOLD, 0.1)
	timer.AnchorPoint = Vector2.new(0, 1)
	timer.Position = UDim2.new(0, 14 * u, 1, -10 * u)
	timer.Size = UDim2.new(1, -28 * u, 0, 5 * u)
	timer.ZIndex = 41
	corner(timer, UDim.new(1, 0))
	tween(timer, seconds, { Size = UDim2.new(0, 0, 0, 5 * u) }, Enum.EasingStyle.Linear)
	tween(card, 0.5, { Position = UDim2.new(1, -14, 0.52, 0) }, Enum.EasingStyle.Back)
	sound("fairyDust", 0.8)
	sound("magicZoom", 0.6)
	local closed = false
	local function close(after: number)
		task.delay(after, function()
			if closed then
				return
			end
			closed = true
			tween(card, 0.35, { Position = UDim2.new(1, width + 40, 0.52, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.4, function()
				card:Destroy()
			end)
		end)
	end
	local started = os.clock()
	local spin: RBXScriptConnection
	spin = RunService.RenderStepped:Connect(function()
		if not card.Parent then
			spin:Disconnect()
			return
		end
		local t = os.clock() - started
		rays.Rotation = (t * 60) % 360
		box.Rotation = math.sin(t * 5) * 8
		edge.Transparency = 0.1 + 0.4 * math.abs(math.sin(t * 4))
		local s = 1 + 0.04 * math.sin(t * 8)
		button.Size = UDim2.new(1, -28 * u * s, 0, 48 * u * s)
	end)
	local opening = false
	local finishBox: () -> () = function() end
	local function open()
		if opening or closed or giftToken ~= my then
			return
		end
		opening = true
		button.Text = "OPENING..."
		button.AutoButtonColor = false
		local ok, r = pcall(function(): any
			return Remotes.func("AbuseGiftAsk"):InvokeServer({ op = "open", id = id })
		end)
		finishBox()
		spin:Disconnect()
		if ok and type(r) == "table" and r.ok then
			local n = night
			if n then
				n.gifts += 1
			end
			sound("kaching", 1)
			sound("coinDrop", 0.9)
			task.delay(0.15, sound, "shimmerFall", 0.7)
			box.Text = "💥"
			tween(box, 0.25, { Size = UDim2.fromOffset(110 * u, 110 * u), TextTransparency = 1 })
			button.Visible = false
			reward.Text = "+" .. tostring(r.gilt or gilt) .. " GILT" .. (if r.crown then "  +  👑 THE CROWN!" else "")
			reward.TextColor3 = GOLD_LIGHT
			local scale = Instance.new("UIScale")
			scale.Scale = 1.6
			scale.Parent = reward
			tween(scale, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
			-- (From the middle of the card: right-hand side, just below half way down.)
			local v = view()
			confettiBurst(gui, Vector2.new(v.X - 14 - width / 2, v.Y * 0.52), 40, 700 * u)
			close(1.8)
		else
			reward.Text = if ok and type(r) == "table" and type(r.why) == "string" then r.why else "That gift has gone."
			button.Visible = false
			close(1.4)
		end
	end
	button.Activated:Connect(open)
	finishBox = fallingGift(open)
	giftBox = finishBox
	task.delay(seconds, function()
		if not opening then
			spin:Disconnect()
			finishBox()
			close(0)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- The finale
---------------------------------------------------------------------------------------------------
local function thousands(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function AbuseShow.finale(n: Night, stopped: boolean)
	local gui = screen()
	local u = unit()
	local v = view()
	local old = gui:FindFirstChild("Finale")
	if old then
		old:Destroy()
	end
	local gained = math.max(0, giltNow() - n.gilt)
	local rows: { { glyph: string, text: string } } = { { glyph = "🪙", text = "+" .. thousands(gained) .. " GILT" } }
	if n.gifts > 0 then
		table.insert(rows, { glyph = "🎁", text = tostring(n.gifts) .. (if n.gifts == 1 then " GIFT OPENED" else " GIFTS OPENED") })
	end
	if n.golden > 0 then
		table.insert(rows, { glyph = "✨", text = tostring(n.golden) .. (if n.golden == 1 then " GOLDEN PIECE" else " GOLDEN PIECES") })
	end
	local realms = 0
	for _ in n.realms do
		realms += 1
	end
	if n.mega and realms > 0 then
		table.insert(rows, { glyph = "🌌", text = tostring(realms) .. (if realms == 1 then " REALM VISITED" else " REALMS VISITED") })
	end
	local height = (150 + #rows * 40) * u
	local card = frame(gui, "Finale", Color3.new(1, 1, 1), 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.45)
	card.Size = UDim2.fromOffset(math.min(v.X - 24, 560 * u), height)
	card.ZIndex = 50
	corner(card, UDim.new(0, 22 * u))
	local fill = Instance.new("UIGradient")
	fill.Color = ColorSequence.new(rgb(46, 32, 12), rgb(12, 9, 6))
	fill.Rotation = 90
	fill.Parent = card
	stroke(card, GOLD, 3)
	local title = label(card, "Title", if stopped then "ADMIN ABUSE IS OVER" else "THAT'S A WRAP!", IMPACT, Color3.new(1, 1, 1))
	title.Position = UDim2.new(0, 18 * u, 0, 16 * u)
	title.Size = UDim2.new(1, -36 * u, 0, 58 * u)
	title.ZIndex = 51
	golden(title)
	stroke(title, rgb(30, 16, 4), 3)
	local thanks = label(card, "Thanks", "THANK YOU FOR COMING  ·  YOUR HAUL", HEAVY, rgb(245, 236, 220))
	thanks.Position = UDim2.new(0, 18 * u, 0, 80 * u)
	thanks.Size = UDim2.new(1, -36 * u, 0, 20 * u)
	thanks.ZIndex = 51
	for i, r in rows do
		local row = label(card, "Row", r.glyph .. "  " .. r.text, HEAVY, if i == 1 then GOLD_LIGHT else Color3.new(1, 1, 1))
		row.Position = UDim2.new(0, 18 * u, 0, (112 + (i - 1) * 40) * u)
		row.Size = UDim2.new(1, -36 * u, 0, 30 * u)
		row.ZIndex = 51
		row.TextTransparency = 1
		task.delay(0.5 + i * 0.45, function()
			tween(row, 0.3, { TextTransparency = 0 })
			sound("tick", 0.8, 1 + i * 0.08)
		end)
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = card
	tween(scale, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	sound("regalFanfare", 0.8)
	task.delay(0.3, sound, "crowdCheer", 0.7)
	confettiBurst(gui, Vector2.new(v.X / 2, v.Y * 0.4), 110, 1000 * u)
	pcall(function()
		Fireworks.show(10, { scale = 1, watch = false, music = false })
	end)
	local seconds = cfg().finaleSeconds or 9
	task.delay(seconds, function()
		if card.Parent then
			tween(scale, 0.35, { Scale = 0.5 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.38, function()
				card:Destroy()
			end)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Watching the house
---------------------------------------------------------------------------------------------------
local function begin(since: number)
	night = { since = since, ends = (Workspace:GetAttribute("AbuseUntil") :: number?) or 0, gilt = giltNow(), gifts = 0, golden = 0, realms = {}, mega = isMega() }
	if not skyHeld then
		skyHeld = true
		pcall(Fireworks.clearSky, true)
	end
	-- (The opening comes by its own message: a guest who didn't get it, arriving late, is welcomed.)
	task.delay(1.6, function()
		local n = night
		if n and n.since == since and os.clock() - openingSeen > 12 then
			AbuseShow.arrived(isMega())
		end
	end)
end

local function finish()
	local n = night
	night = nil
	if skyHeld then
		skyHeld = false
		pcall(Fireworks.clearSky, false)
	end
	openingToken += 1
	local gui = screen()
	for _, name in { "Opening", "Arrival", "Gift" } do
		local f = gui:FindFirstChild(name)
		if f then
			f:Destroy()
		end
	end
	OwnerCameo.colossus(false)
	AbuseShow.realm(nil, false)
	if n then
		-- (Ended on time: the full finale. Stopped early: the same, its title says so.)
		local early = Workspace:GetServerTimeNow() < n.ends - 5
		OwnerCameo.say(if early then "That's all for tonight! Thank you for coming! 👋" else "That's a wrap! See you at the next Admin Abuse! 👋", "wave", 6)
		AbuseShow.finale(n, early)
	end
end

local function check()
	local since = Workspace:GetAttribute("AbuseSince")
	if abusing() and type(since) == "number" then
		local n = night
		if not n or n.since ~= since then
			begin(since)
		else
			local mega = isMega()
			n.mega = n.mega or mega
			local ends = Workspace:GetAttribute("AbuseUntil")
			if type(ends) == "number" then
				n.ends = ends
			end
		end
		-- (A change of realm in Mega Abuse is announced; the first, at the opening, after it.)
		local realm = Workspace:GetAttribute("AbuseRealm")
		AbuseShow.realm(if type(realm) == "string" then realm else nil, isMega() and realmNow ~= nil)
	elseif night then
		finish()
	end
end
AbuseShow.check = check

function AbuseShow.start()
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "abuseShow" and m.stage == "intro" then
			AbuseShow.opening(m.mega == true)
		elseif m.op == "abuseGift" then
			AbuseShow.gift(m)
		elseif m.op == "abuseFX" and type(m.id) == "string" then
			local e = HouseEvents.effectById[m.id]
			if e then
				OwnerCameo.say(string.format("cast %s %s!", tostring(e.glyph), string.upper(tostring(e.name))), "point", 4)
				OwnerCameo.gesture("point")
			end
		elseif m.op == "giveaway" and type(m.winner) == "string" then
			OwnerCameo.say("GIVEAWAY! Good luck, everyone... 🍀", "cheer", 4)
		end
	end)
	-- An effect switched on (from the console or the Owner Remote): the owner says so.
	for _, e in HouseEvents.Effects do
		local attr = HouseEvents.fxAttribute(e.id)
		local was = Workspace:GetAttribute(attr) ~= nil
		Workspace:GetAttributeChangedSignal(attr):Connect(function()
			local on = Workspace:GetAttribute(attr) ~= nil
			if on and not was then
				OwnerCameo.say(string.format("switched on %s %s! It stays on.", tostring(e.glyph), string.upper(tostring(e.name))), "point", 4)
				OwnerCameo.gesture("point")
			end
			was = on
		end)
	end
	for _, name in { "AbuseUntil", "AbuseSince", "AbuseMega", "AbuseRealm" } do
		Workspace:GetAttributeChangedSignal(name):Connect(check)
	end
	check()
	-- (It ends at a time, not with a change: look now and then.)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(check)
		end
	end)
end

return AbuseShow

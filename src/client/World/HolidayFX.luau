--!strict
-- The holidays on this screen while one is on (the server runs them and their hunts: AdminService).
-- What each brings to the house, on the street front, in the Foyer and in the sky, is
-- World/HolidaySets. When one begins, black bars close in and its title comes up in its own
-- colours with what to do, a chime sounds and its colours burst round the guest while the house
-- dresses itself, the pieces appearing from the ground up. While it's on:
--   the light     a tint of its own over the picture
--   the air       snow (Christmas), autumn leaves (Thanksgiving), rose petals and drifting hearts
--                 (Valentine's), blossom (Easter), clover and gold (St Patrick's), champagne bubbles
--                 and gold confetti now and then (New Year), fireflies and cartoon bats (All
--                 Hallows'): in full in the open air, gentler indoors
--   the music     its own (World/AbuseMusic plays it, from Config.Assets.HolidayMusic)
--   the hunt      every pickup glows in the holiday's colours and sparkles; the golden prize stands
--                 in a column of golden light with sparks rising up it, seen from across the house;
--                 St Patrick's rainbow comes down to the pot of gold while it's hidden
-- Nothing here is frightening: All Hallows' is pumpkins, candles, a harvest moon and cartoon bats.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Flakes = require(script.Parent.Flakes)
local HolidayKit = require(script.Parent.HolidayKit)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local HolidaySets = require(script.Parent.HolidaySets)
local Quality = require(script.Parent.Parent.Quality)
local Stagecraft = require(script.Parent.Stagecraft)
local Sound = require(script.Parent.Parent.Sound)

local HolidayFX = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function holder(): Instance
	return Workspace:FindFirstChild("MaisonLocal") or Workspace
end

local function rootPos(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.CFrame.Position else nil
end

-- How each holiday looks on the screen: its tint, its title's colours and greeting, its chime, the
-- colours that burst when it begins and glow round its pickups.
type Look = { tint: Color3, amount: number, saturation: number, greeting: string, title: Stagecraft.TitleLook, sting: { string }, colours: { Color3 } }
local LOOKS: { [string]: Look } = {
	halloween = {
		tint = rgb(170, 90, 255),
		amount = 0.18,
		saturation = 0.12,
		greeting = "Happy Halloween",
		title = { deep = rgb(214, 96, 18), mid = rgb(255, 150, 50), light = rgb(255, 232, 170), ink = rgb(40, 14, 60), kicker = rgb(206, 170, 255) },
		sting = { "magicZoom", "bellStrike" },
		colours = { rgb(255, 140, 40), rgb(160, 96, 255), rgb(255, 210, 120) },
	},
	thanksgiving = {
		tint = rgb(255, 170, 70),
		amount = 0.14,
		saturation = 0.12,
		greeting = "Happy Thanksgiving",
		title = { deep = rgb(170, 70, 24), mid = rgb(232, 140, 48), light = rgb(255, 228, 160), ink = rgb(50, 26, 10), kicker = rgb(255, 214, 150) },
		sting = { "bellStrike", "shimmerFall" },
		colours = { rgb(232, 124, 40), rgb(236, 178, 60), rgb(196, 74, 28) },
	},
	christmas = {
		tint = rgb(200, 225, 255),
		amount = 0.12,
		saturation = 0.05,
		greeting = "Merry Christmas",
		title = { deep = rgb(170, 24, 40), mid = rgb(236, 64, 72), light = rgb(255, 240, 220), ink = rgb(20, 50, 30), kicker = rgb(160, 230, 180) },
		sting = { "bellTree", "chime" },
		colours = { rgb(230, 40, 52), rgb(70, 210, 100), rgb(255, 214, 140), rgb(255, 255, 255) },
	},
	newYear = {
		tint = rgb(255, 214, 120),
		amount = 0.14,
		saturation = 0.15,
		greeting = "Happy New Year",
		title = { deep = rgb(214, 160, 60), mid = rgb(255, 214, 120), light = rgb(255, 250, 230), ink = rgb(30, 24, 10), kicker = rgb(230, 230, 240) },
		sting = { "bellTree", "shimmer" },
		colours = { rgb(255, 214, 120), rgb(225, 230, 240), rgb(250, 232, 190) },
	},
	valentine = {
		tint = rgb(255, 120, 170),
		amount = 0.16,
		saturation = 0.1,
		greeting = "Happy Valentine's Day",
		title = { deep = rgb(200, 30, 70), mid = rgb(255, 110, 160), light = rgb(255, 230, 240), ink = rgb(60, 10, 30), kicker = rgb(255, 196, 214) },
		sting = { "fairyDust", "chime" },
		colours = { rgb(255, 120, 170), rgb(220, 30, 70), rgb(255, 196, 214) },
	},
	stPatrick = {
		tint = rgb(120, 255, 150),
		amount = 0.14,
		saturation = 0.12,
		greeting = "Happy St Patrick's Day",
		title = { deep = rgb(20, 130, 60), mid = rgb(80, 210, 100), light = rgb(255, 236, 160), ink = rgb(10, 40, 20), kicker = rgb(255, 214, 110) },
		sting = { "kaching", "sparklePass" },
		colours = { rgb(30, 170, 80), rgb(110, 220, 110), rgb(255, 206, 80) },
	},
	easter = {
		tint = rgb(255, 220, 240),
		amount = 0.12,
		saturation = 0.08,
		greeting = "Happy Easter",
		title = { deep = rgb(220, 120, 170), mid = rgb(255, 182, 214), light = rgb(255, 250, 220), ink = rgb(70, 50, 90), kicker = rgb(190, 220, 255) },
		sting = { "fairyDust", "chime" },
		colours = { rgb(255, 182, 214), rgb(255, 236, 140), rgb(170, 214, 255), rgb(176, 240, 200) },
	},
}

-- The screen the holidays' words go on.
local screen: ScreenGui? = nil
local function gui(): ScreenGui?
	local s = screen
	if s and s.Parent then
		return s
	end
	local pg = player:WaitForChild("PlayerGui", 5)
	if not pg then
		return nil
	end
	local g = Instance.new("ScreenGui")
	g.Name = "HolidayFX"
	g.IgnoreGuiInset = true
	g.ResetOnSpawn = false
	g.DisplayOrder = 30
	g.Parent = pg
	screen = g
	return g
end

---------------------------------------------------------------------------------------------------
-- The light and the air
---------------------------------------------------------------------------------------------------

-- A soft tint over the picture while it's on (it comes in over two seconds and goes in one).
local function tint(look: Look): () -> ()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HolidayTint"
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(2, Enum.EasingStyle.Sine), { TintColor = Color3.new(1, 1, 1):Lerp(look.tint, look.amount), Saturation = look.saturation }):Play()
	return function()
		cc.Name = "HolidayTintFading"
		TweenService:Create(cc, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { TintColor = Color3.new(1, 1, 1), Saturation = 0 }):Play()
		task.delay(1, function()
			cc:Destroy()
		end)
	end
end

-- Things falling round the guest (snow, leaves, petals, clover), from the Flakes.
local function shower(colours: { Color3 }, size: Vector3, fall: number, flutter: number, count: number, material: Enum.Material?): () -> ()
	return Flakes.fall({
		seconds = 36000,
		centre = rootPos,
		colours = colours,
		material = material or Enum.Material.SmoothPlastic,
		size = size,
		count = Quality.count(count, 30),
		radius = 32,
		height = 28,
		fall = fall,
		flutter = flutter,
	})
end

-- Particles in the air round the camera (snow far and near, motes, bubbles): in full in the open
-- air, a quarter as many indoors.
local function air(props: { [string]: any }, colour: ColorSequence, rate: number, lift: number, box: Vector3): () -> ()
	local p = Instance.new("Part")
	p.Name = "HolidayAir"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = box
	p.Parent = holder()
	local e = Instance.new("ParticleEmitter")
	e.Color = colour
	e.LightInfluence = 0
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Rate = 0
	e.Parent = p
	local acc = 1
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		local at = cam.CFrame.Position
		p.CFrame = CFrame.new(at + Vector3.new(0, lift, 0))
		acc += dt
		if acc > 0.5 then
			acc = 0
			local zone = Layout.zoneAt(at)
			local open = zone == "street" or zone == "terrace" or zone == "none"
			e.Rate = rate * (if open then 1 else 0.25) * Quality.level()
		end
	end)
	return function()
		conn:Disconnect()
		p:Destroy()
	end
end

-- Glyphs wheeling overhead round the guest (All Hallows' cartoon bats), or drifting down (hearts).
local function glyphs(glyph: string, count: number, mode: "fall" | "wheel"): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "HolidayGlyphs"
	folder.Parent = holder()
	local rng = Random.new()
	type G = { part: Part, label: TextLabel, offset: Vector3, speed: number, phase: number }
	local list: { G } = {}
	for _ = 1, Quality.count(count, 5) do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		local bb = Instance.new("BillboardGui")
		local s = rng:NextNumber(1.4, 2.6)
		bb.Size = UDim2.fromScale(s, s)
		bb.LightInfluence = 0
		bb.MaxDistance = 140
		bb.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.5)
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Text = glyph
		t.Parent = bb
		p.Parent = folder
		table.insert(list, { part = p, label = t, offset = Vector3.new(rng:NextNumber(-30, 30), rng:NextNumber(0, 30), rng:NextNumber(-30, 30)), speed = rng:NextNumber(2, 5), phase = rng:NextNumber(0, math.pi * 2) })
	end
	local conn = RunService.RenderStepped:Connect(function(dt: number)
		local centre = rootPos()
		if not centre then
			return
		end
		local t = os.clock()
		for _, g in list do
			if mode == "fall" then
				local y = g.offset.Y - g.speed * dt
				if y < -6 then
					y = 30
				end
				g.offset = Vector3.new(g.offset.X, y, g.offset.Z)
				g.part.CFrame = CFrame.new(centre + g.offset + Vector3.new(math.sin(t + g.phase) * 1.5, 0, 0))
			else
				local a = t * 0.4 * g.speed / 3 + g.phase
				local r = 18 + g.offset.X * 0.3
				g.part.CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * r, 22 + math.sin(t * 2 + g.phase) * 3, math.sin(a) * r))
				-- (Wings beating.)
				g.label.Size = UDim2.fromScale(0.6 + 0.4 * math.abs(math.sin(t * 9 + g.phase)), 1)
			end
		end
	end)
	return function()
		conn:Disconnect()
		folder:Destroy()
	end
end

-- Gold and silver confetti bursting over the guest now and then (New Year).
local function confettiBursts(every: number): () -> ()
	local alive = true
	local stops: { () -> () } = {}
	task.spawn(function()
		task.wait(4)
		while alive do
			table.insert(stops, Flakes.fall({
				seconds = 5,
				centre = rootPos,
				colours = { rgb(255, 214, 120), rgb(225, 230, 240), rgb(250, 232, 190), rgb(214, 166, 72) },
				material = Enum.Material.Metal,
				reflectance = 0.5,
				size = Vector3.new(0.32, 0.02, 0.18),
				count = 60,
				radius = 18,
				height = 18,
				fall = 2.4,
				flutter = 3,
				burst = true,
			}))
			pcall(Sound.play, "fireworkGlitter", 0.35, 1.1)
			task.wait(every)
		end
	end)
	return function()
		alive = false
		for _, s in stops do
			pcall(s)
		end
	end
end

-- The air of each holiday.
local AIR: { [string]: () -> { () -> () } } = {
	halloween = function()
		return {
			glyphs("🦇", 10, "wheel"),
			air({ Texture = SPARK, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.2, 0.8), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }), LightEmission = 1 }, ColorSequence.new(rgb(255, 170, 60), rgb(180, 120, 255)), 10, -4, Vector3.new(60, 10, 60)),
		}
	end,
	thanksgiving = function()
		return {
			shower({ rgb(220, 110, 30), rgb(190, 60, 30), rgb(240, 170, 50), rgb(140, 80, 30) }, Vector3.new(0.6, 0.03, 0.45), 3.6, 1.3, 80),
			air({ Texture = SPARK, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(0.1, 0.5), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 0) }), LightEmission = 1 }, ColorSequence.new(rgb(255, 214, 140)), 14, -2, Vector3.new(60, 14, 60)),
		}
	end,
	christmas = function()
		return {
			shower({ rgb(255, 255, 255), rgb(235, 245, 255) }, Vector3.new(0.28, 0.28, 0.28), 3, 0.5, 90),
			air({ Texture = SMOKE, EmissionDirection = Enum.NormalId.Bottom, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(18, 18), Acceleration = Vector3.new(0.8, 0, 0.4), Size = NumberSequence.new(0.35), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.15), NumberSequenceKeypoint.new(1, 1) }), LightEmission = 0.4, RotSpeed = NumberRange.new(-40, 40) }, ColorSequence.new(rgb(255, 255, 255)), 160, 26, Vector3.new(140, 1, 140)),
		}
	end,
	newYear = function()
		return {
			air({ Texture = SPARK, EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(20, 20), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.3) }), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }), LightEmission = 0.7 }, ColorSequence.new(rgb(250, 232, 190), rgb(255, 250, 235)), 24, -8, Vector3.new(50, 1, 50)),
			confettiBursts(28),
		}
	end,
	valentine = function()
		return {
			shower({ rgb(190, 24, 48), rgb(220, 48, 72), rgb(236, 120, 140), rgb(255, 190, 205) }, Vector3.new(0.45, 0.03, 0.36), 2.5, 1.4, 70),
			glyphs("💖", 14, "fall"),
		}
	end,
	stPatrick = function()
		return {
			shower({ rgb(40, 170, 80), rgb(110, 220, 110), rgb(60, 200, 100), rgb(255, 206, 80) }, Vector3.new(0.4, 0.03, 0.4), 2.6, 1.3, 60),
			air({ Texture = SPARK, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(0.2, 0.6), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) }), LightEmission = 1 }, ColorSequence.new(rgb(255, 220, 110)), 14, -2, Vector3.new(50, 12, 50)),
		}
	end,
	easter = function()
		return {
			shower({ rgb(255, 196, 220), rgb(255, 236, 244), rgb(250, 170, 205), rgb(255, 250, 220) }, Vector3.new(0.38, 0.03, 0.3), 2.2, 1.2, 70),
		}
	end,
}

---------------------------------------------------------------------------------------------------
-- The hunt
---------------------------------------------------------------------------------------------------

-- Each pickup drawn as the real thing, round the server's invisible part (on this screen only):
-- a carved pumpkin, a wrapped present, a love letter sealed with a wax heart, a four-leaf clover,
-- a painted egg, a turkey on the run; and the golden prizes their own (a golden pumpkin, a golden
-- bell, the heart of gold with Cupid's arrow through it, the pot of gold, the golden egg, the
-- golden turkey). What you'd find lies where it was hidden; love letters, the heart of gold and
-- the golden bell float, turning. Found, it goes in a burst of its colours.
type Prop = { model: Model, float: boolean, moves: boolean, home: Vector3, phase: number, colours: { Color3 } }
local props: { [BasePart]: Prop } = {}
local GOLDS = { rgb(255, 214, 110), rgb(236, 176, 60) }

local function buildProp(p: BasePart): Prop?
	local hunt = tostring(p:GetAttribute("Hunt"))
	local jackpot = p:GetAttribute("Jackpot") == true
	local moves = p:GetAttribute("Moves") == true
	local base = p:GetAttribute("Base")
	local cf = if typeof(base) == "CFrame" then base else p.CFrame
	local at = cf.Position
	local floorAt = at - Vector3.new(0, 3.2, 0)
	local yaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local floor = CFrame.new(floorAt) * yaw
	local f = holder()
	local m: Model? = nil
	local float = false
	local colours = GOLDS
	if hunt == "valentine" then
		float = true
		m = if jackpot then HolidayProps.heartOfGold(f, CFrame.new(at), 2.6) else HolidayProps.loveLetter(f, CFrame.new(at), 1.8)
		colours = if jackpot then GOLDS else { rgb(255, 120, 170), rgb(220, 30, 70), rgb(255, 230, 236) }
	elseif hunt == "stPatrick" then
		m = if jackpot then HolidayProps.potOfGold(f, floor, 3.2) else HolidayProps.clover(f, floor, 2.6, true)
		colours = if jackpot then GOLDS else { rgb(46, 170, 70), rgb(120, 220, 120), rgb(255, 214, 110) }
	elseif hunt == "easter" then
		local scheme = HolidayProps.EGGS[math.random(1, #HolidayProps.EGGS)]
		m = HolidayProps.egg(f, floor, if jackpot then 2.3 else 1.7, scheme, jackpot)
		colours = if jackpot then GOLDS else scheme
	elseif hunt == "halloween" then
		m = HolidayProps.pumpkin(f, floorAt, if jackpot then 2.8 else 2.1, cf.LookVector, true, true, if jackpot then GOLDS else nil)
		colours = if jackpot then GOLDS else { rgb(255, 140, 40), rgb(160, 96, 255) }
	elseif hunt == "christmas" then
		if jackpot then
			float = true
			m = HolidayProps.goldenBell(f, CFrame.new(at - Vector3.new(0, 1.1, 0)), 2.2)
		else
			local wrap = HolidayProps.WRAPS[math.random(1, #HolidayProps.WRAPS)]
			m = HolidayProps.gift(f, floor, Vector3.new(1.9, 1.7, 1.9), wrap[1], wrap[2])
			colours = { wrap[1], wrap[2] }
		end
	elseif hunt == "thanksgiving" then
		m = HolidayProps.turkey(f, floor, jackpot)
		colours = if jackpot then GOLDS else { rgb(236, 170, 80), rgb(150, 90, 40) }
	end
	if not m then
		return nil
	end
	local bb = p:FindFirstChildOfClass("BillboardGui")
	if bb then
		bb.Enabled = false
	end
	return { model = m, float = float, moves = moves, home = if float then at else floorAt, phase = math.random() * math.pi * 2, colours = colours }
end

local function stepProps(t: number)
	for p, prop in props do
		if not p.Parent then
			props[p] = nil
			local pivot = prop.model:GetPivot().Position
			prop.model:Destroy()
			pcall(HolidayKit.burst, pivot + Vector3.new(0, 1.5, 0), prop.colours, 18, 0.5, true)
		elseif prop.float then
			local bob = math.sin(t * 2 + prop.phase) * 0.35
			prop.model:PivotTo(CFrame.new(prop.home + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * 0.9 + prop.phase, math.sin(t * 1.3 + prop.phase) * 0.08))
		elseif prop.moves then
			local now = p.CFrame.Position - Vector3.new(0, 3.2, 0)
			local last = prop.home
			local dir = Vector3.new(now.X - last.X, 0, now.Z - last.Z)
			local facing = if dir.Magnitude > 0.05 then CFrame.lookAt(now, now + dir) else CFrame.new(now) * (prop.model:GetPivot() - prop.model:GetPivot().Position)
			prop.model:PivotTo(facing)
			prop.home = now
		end
	end
end

-- Every pickup glows in its holiday's colours and sparkles (decorated on this screen only; the
-- server's pickup carries it, so it goes when the pickup goes).
local dressed: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function dress(p: Instance)
	if dressed[p] or not p:IsA("BasePart") then
		return
	end
	local look = LOOKS[tostring(p:GetAttribute("Hunt"))]
	if not look then
		return
	end
	dressed[p] = true
	local jackpot = p:GetAttribute("Jackpot") == true
	local glowColour = if jackpot then rgb(255, 214, 110) else look.colours[1]
	local bb = p:FindFirstChildOfClass("BillboardGui")
	if bb then
		local halo = Instance.new("Frame")
		halo.Name = "HolidayGlow"
		halo.AnchorPoint = Vector2.new(0.5, 0.5)
		halo.Position = UDim2.fromScale(0.5, 0.5)
		halo.Size = UDim2.fromScale(1.45, 1.45)
		halo.BackgroundColor3 = glowColour
		halo.BackgroundTransparency = 0.55
		halo.BorderSizePixel = 0
		halo.ZIndex = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = halo
		local soft = Instance.new("UIGradient")
		soft.Rotation = 90
		soft.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 0.85) })
		soft.Parent = halo
		halo.Parent = bb
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "HolidaySparkle"
	e.Texture = SPARK
	e.Rate = if jackpot then 10 else 3
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(0.5, 2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Color = ColorSequence.new(glowColour:Lerp(Color3.new(1, 1, 1), 0.4), glowColour)
	e.Parent = p
	if not props[p :: BasePart] then
		local ok, prop = pcall(buildProp, p :: BasePart)
		if ok and prop then
			props[p :: BasePart] = prop
		end
	end
end

-- A column of golden light over each hunt's golden prize, sparks rising up it.
local function prizeLights(): () -> ()
	type Column = { beam: Part, foot: Part }
	local made: { [Instance]: Column } = {}
	local look = 1
	local conn = RunService.Heartbeat:Connect(function(dt: number)
		look += dt
		local tagged = if look >= 0.5 then CollectionService:GetTagged("HuntJackpot") else {}
		if look >= 0.5 then
			look = 0
		end
		for _, p in tagged do
			if p:IsA("BasePart") and not made[p] then
				local beam = Instance.new("Part")
				beam.Name = "PrizeLight"
				beam.Anchored = true
				beam.CanCollide = false
				beam.CanQuery = false
				beam.CanTouch = false
				beam.CastShadow = false
				beam.Shape = Enum.PartType.Cylinder
				beam.Material = Enum.Material.ForceField
				beam.Color = rgb(255, 214, 110)
				beam.Transparency = 0.25
				beam.Size = Vector3.new(120, 2.8, 2.8)
				beam.Parent = holder()
				local foot = Instance.new("Part")
				foot.Name = "PrizeSparks"
				foot.Anchored = true
				foot.CanCollide = false
				foot.CanQuery = false
				foot.CanTouch = false
				foot.Transparency = 1
				foot.Size = Vector3.new(2, 0.2, 2)
				foot.Parent = holder()
				local e = Instance.new("ParticleEmitter")
				e.Texture = SPARK
				e.EmissionDirection = Enum.NormalId.Top
				e.Rate = 16
				e.Lifetime = NumberRange.new(3, 5)
				e.Speed = NumberRange.new(12, 20)
				e.SpreadAngle = Vector2.new(4, 4)
				e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
				e.LightEmission = 1
				e.LightInfluence = 0
				e.Color = ColorSequence.new(rgb(255, 250, 220), rgb(255, 200, 90))
				e.Parent = foot
				made[p] = { beam = beam, foot = foot }
			end
		end
		for p, col in made do
			if p.Parent and p:IsA("BasePart") then
				local at = p.CFrame.Position
				col.beam.CFrame = CFrame.new(at + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.rad(90))
				col.foot.CFrame = CFrame.new(at - Vector3.new(0, 2.6, 0))
			else
				col.beam:Destroy()
				col.foot:Destroy()
				made[p] = nil
			end
		end
	end)
	return function()
		conn:Disconnect()
		for _, col in made do
			col.beam:Destroy()
			col.foot:Destroy()
		end
	end
end

-- A rainbow: six bands of light arching from far off down to a point (the pot of gold), or, with
-- nothing to point at, across the sky over the street.
local function rainbowTo(target: Vector3?): () -> ()
	local folder = Instance.new("Folder")
	folder.Name = "Rainbow"
	folder.Parent = holder()
	local bands = { rgb(255, 70, 90), rgb(255, 160, 60), rgb(255, 230, 80), rgb(90, 220, 120), rgb(80, 160, 255), rgb(150, 100, 255) }
	local a: Vector3, b: Vector3
	if target then
		a, b = target + Vector3.new(-230, 0, 130), target
	else
		a, b = Vector3.new(-260, 0, -230), Vector3.new(260, 0, -230)
	end
	local along = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	local height = math.min(170, (b - a).Magnitude * 0.45)
	local anchor = Instance.new("Part")
	anchor.Name = "RainbowAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new()
	anchor.Parent = folder
	local width = 4.2
	for i, colour in bands do
		-- (Outer bands rise higher and land wider.)
		local k = #bands - i
		local spread = along * k * width * 0.6
		local a0 = Instance.new("Attachment")
		a0.CFrame = CFrame.fromMatrix(a - spread, Vector3.yAxis, along)
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.CFrame = CFrame.fromMatrix(b + spread, Vector3.yAxis, along)
		a1.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0 = a0
		beam.Attachment1 = a1
		beam.CurveSize0 = height + k * width
		beam.CurveSize1 = -(height + k * width)
		beam.Segments = 40
		beam.Width0 = width
		beam.Width1 = width
		beam.FaceCamera = true
		beam.LightEmission = 0.8
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(colour)
		beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(0.2, 0.3), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 0.5) })
		beam.Name = "Band"
		beam.Parent = anchor
	end
	if target then
		-- Gold glittering where it comes down.
		local glitter = Instance.new("Part")
		glitter.Name = "RainbowGold"
		glitter.Anchored = true
		glitter.CanCollide = false
		glitter.CanQuery = false
		glitter.CanTouch = false
		glitter.Transparency = 1
		glitter.Size = Vector3.new(4, 4, 4)
		glitter.CFrame = CFrame.new(target)
		glitter.Parent = folder
		local e = Instance.new("ParticleEmitter")
		e.Texture = SPARK
		e.Rate = 18
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(1, 4)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Color = ColorSequence.new(rgb(255, 240, 180), rgb(255, 200, 80))
		e.Parent = glitter
	end
	return function()
		folder:Destroy()
	end
end

---------------------------------------------------------------------------------------------------
-- The pieces appearing, and going
---------------------------------------------------------------------------------------------------

-- Every piece starts unseen and they appear from the ground up over a few seconds (the lights
-- coming on as they go). `instant`: all at once (a guest arriving in the middle of a holiday).
local function reveal(set: HolidaySets.Set, instant: boolean)
	if instant then
		return
	end
	type Item = { part: BasePart, to: number, y: number }
	local list: { Item } = {}
	for _, d in set.folder:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(list, { part = d, to = d.Transparency, y = d.CFrame.Position.Y })
			d.Transparency = 1
		end
	end
	if #list == 0 then
		return
	end
	table.sort(list, function(x, y)
		return x.y < y.y
	end)
	local lo, hi = list[1].y, list[#list].y
	local t0 = os.clock()
	local i = 1
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local level = lo + (hi - lo + 1) * math.clamp((os.clock() - t0) / 3, 0, 1)
		while i <= #list and list[i].y <= level do
			local item = list[i]
			if item.part.Parent then
				item.part.Transparency = item.to
			end
			i += 1
		end
		if i > #list or set.folder.Parent == nil then
			local c = conn
			if c then
				c:Disconnect()
			end
		end
	end)
end

-- A holiday begins on this screen: the bars, its title in its colours with what to do, its chime,
-- a burst of its colours round the guest. (Its event's name and line while its event is on; on its
-- holiday game's other days, the game's: there's no hunt round the house then.)
local function arrive(id: string, look: Look)
	local e = HouseEvents.byId[id]
	local g = gui()
	if not e or not g then
		return
	end
	local name, line = e.name, e.line
	local ends = Workspace:GetAttribute(HouseEvents.attribute(id))
	local game = HolidayGames.byId[id]
	if game and not (type(ends) == "number" and ends > Workspace:GetServerTimeNow()) then
		name, line = game.name, game.line
	end
	Stagecraft.letterbox(g, true, 0.08)
	task.delay(4.6, function()
		if g.Parent then
			Stagecraft.letterbox(g, false)
		end
	end)
	Stagecraft.title(g, look.greeting, string.upper(name), 4.2, look.title, line)
	for i, s in look.sting do
		task.delay((i - 1) * 0.35, function()
			pcall(Sound.play, s, 0.8)
		end)
	end
	local at = rootPos()
	if at then
		local p = Instance.new("Part")
		p.Name = "HolidayBurst"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(1, 1, 1)
		p.CFrame = CFrame.new(at + Vector3.new(0, 2, 0))
		p.Parent = holder()
		local burst = Instance.new("ParticleEmitter")
		burst.Texture = SPARK
		burst.Rate = 0
		burst.Lifetime = NumberRange.new(1, 2)
		burst.Speed = NumberRange.new(10, 24)
		burst.SpreadAngle = Vector2.new(180, 180)
		burst.Drag = 2.4
		burst.Acceleration = Vector3.new(0, -6, 0)
		burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		burst.LightEmission = 1
		burst.LightInfluence = 0
		burst.Color = ColorSequence.new(look.colours[1], look.colours[2] or look.colours[1])
		burst.Parent = p
		burst:Emit(120)
		task.delay(2.5, function()
			p:Destroy()
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- On and off
---------------------------------------------------------------------------------------------------

type Running = { set: HolidaySets.Set?, stops: { () -> () } }
local running: { [string]: Running } = {}
local rainbow: (() -> ())? = nil
local rainbowAt: Vector3? = nil
local prizes: (() -> ())? = nil
local booted = false
local clock = 0

-- A holiday is on while its event is (the owner's, or the house's own on the day), and for all of
-- its holiday game's days (shared/HolidayGames): the house stays dressed while there's trick or
-- treating, a sleigh at the kerb, eggs to find.
local function on(id: string): boolean
	if Workspace:GetAttribute("HolidayGame") == id then
		return true
	end
	local ends = Workspace:GetAttribute(HouseEvents.attribute(id))
	return type(ends) == "number" and ends > Workspace:GetServerTimeNow()
end

local function begin(id: string, instant: boolean)
	local look = LOOKS[id]
	local stops: { () -> () } = {}
	local set: HolidaySets.Set? = nil
	if look then
		table.insert(stops, tint(look))
		local make = AIR[id]
		if make then
			local ok, list = pcall(make)
			if ok then
				for _, s in list do
					table.insert(stops, s)
				end
			end
		end
		-- (New Year's countdown is its own moment: no title over it.)
		if not instant and id ~= "newYear" then
			pcall(arrive, id, look)
		end
	end
	local ok, built = pcall(HolidaySets.build, id)
	if ok and built then
		set = built
		reveal(built, instant)
	end
	running[id] = { set = set, stops = stops }
end

local function finish(id: string)
	local r = running[id]
	running[id] = nil
	if not r then
		return
	end
	for _, stop in r.stops do
		pcall(stop)
	end
	local set = r.set
	if set then
		set.folder:Destroy()
	end
end

local function update()
	local anyHunt = false
	for _, id in HouseEvents.Holidays do
		local isOn = on(id)
		if isOn and id ~= "newYear" then
			anyHunt = true
		end
		if isOn and not running[id] then
			begin(id, not booted)
		elseif not isOn and running[id] then
			finish(id)
		end
	end
	booted = true
	-- St Patrick's rainbow comes down to the pot of gold (while it hasn't been found); with no pot to
	-- point at, it arches over the street.
	local want: Vector3? = nil
	local wantRainbow = running.stPatrick ~= nil
	if wantRainbow then
		for _, p in CollectionService:GetTagged("HuntJackpot") do
			if p:IsA("BasePart") and p:GetAttribute("Hunt") == "stPatrick" then
				want = p.CFrame.Position - Vector3.new(0, 3, 0)
			end
		end
	end
	local moved = (want == nil) ~= (rainbowAt == nil) or (want ~= nil and rainbowAt ~= nil and (want - rainbowAt).Magnitude > 4)
	if rainbow and (not wantRainbow or moved) then
		rainbow()
		rainbow = nil
		rainbowAt = nil
	end
	if wantRainbow and not rainbow then
		rainbow = rainbowTo(want)
		rainbowAt = want
	end
	-- The pickups glow; the golden prizes stand in their columns of light.
	for _, tag in { "HuntPickup", "HuntJackpot" } do
		for _, p in CollectionService:GetTagged(tag) do
			dress(p)
		end
	end
	if anyHunt and not prizes then
		prizes = prizeLights()
	elseif not anyHunt and prizes then
		prizes()
		prizes = nil
	end
end

function HolidayFX.start()
	for _, id in HouseEvents.Holidays do
		Workspace:GetAttributeChangedSignal(HouseEvents.attribute(id)):Connect(function()
			pcall(update)
		end)
	end
	Workspace:GetAttributeChangedSignal("HolidayGame"):Connect(function()
		pcall(update)
	end)
	for _, tag in { "HuntPickup", "HuntJackpot" } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(p: Instance)
			task.defer(function()
				pcall(dress, p)
			end)
		end)
	end
	-- Everything that moves in the holidays' pieces, on one clock.
	RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		stepProps(clock)
		for _, r in running do
			local set = r.set
			if set and set.folder.Parent then
				HolidaySets.step(set, dt, clock)
			end
		end
	end)
	task.spawn(function()
		while true do
			pcall(update)
			task.wait(1)
		end
	end)
end

-- (For tests: the holidays on now, and the pieces of one.)
function HolidayFX.running(id: string): boolean
	return running[id] ~= nil
end
function HolidayFX.setOf(id: string): Folder?
	local r = running[id]
	local set = r and r.set
	return if set then set.folder else nil
end

HolidayFX.update = update

return HolidayFX

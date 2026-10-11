--!strict
-- Hallows Lane on this screen (the server builds the street and its hosts, and decides every
-- treat). When someone knocks, the door swings open on its lit hall, the host steps out onto the
-- threshold and waves, says their line, and throws the treat to whoever knocked, in an arc of
-- sparkle; then steps back, and the door closes. Over every door a jack-o'-lantern says it's still
-- to knock at, and a gold tick that it's done this round. While you're on the Lane: a violet mist
-- rolling along the cobbles, candles floating over it, bats crossing the moon, every lamp and
-- jack-o'-lantern flickering. How much of that there is follows Quality.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Quality = require(script.Parent.Parent.Quality)
local Sound = require(script.Parent.Parent.Sound)
local HolidayKit = require(script.Parent.HolidayKit)

local HolidayLane = {}

local rgb = Color3.fromRGB
local WAVE = "rbxassetid://507770239" -- Roblox's own wave (R15)

type Leaf = { model: Model, parts: { BasePart }, base: { CFrame }, hinge: Vector3, side: number }
type Door = {
	i: number,
	house: Model,
	leaves: { Leaf },
	frame: CFrame,
	host: Model?,
	hostRoot: BasePart?,
	hostHome: CFrame?,
	open: number, -- 0 shut .. 1 wide
	since: number, -- when it was knocked at (os.clock); 0: shut
	marker: BillboardGui?,
	hall: PointLight?,
	hallBase: number,
}

local lane: Model? = nil
local doors: { [number]: Door } = {}
local visited: { [number]: boolean } = {}
local dressing: Folder? = nil
local candles: { { part: BasePart, flame: BasePart, base: Vector3, phase: number } } = {}
local bats: { { part: BasePart, label: TextLabel, centre: Vector3, r: number, phase: number, speed: number } } = {}
-- (The candles and the bats move together, in one move a frame.)
local moving: { BasePart } = {}
local movingTo: { CFrame } = {}

local OPEN_FOR = 4.2 -- seconds a door stays open
local SWING = math.rad(102)

local function hostOf(house: Model): Model?
	for _, d in house:GetChildren() do
		if d:IsA("Model") and d:GetAttribute("Host") ~= nil then
			return d
		end
	end
	return nil
end

-- Finds the doors of the Lane that arrived on this screen (each house: its two leaves, its hall
-- light, its host when they've dressed).
local function index(model: Model)
	doors = {}
	local frames = HolidayGames.laneDoors()
	for _, house in model:GetChildren() do
		local i = house:GetAttribute("Door")
		if house:IsA("Model") and type(i) == "number" and frames[i] then
			local leaves: { Leaf } = {}
			for _, name in { "DoorL", "DoorR" } do
				local leaf = house:FindFirstChild(name)
				local hinge = leaf and leaf:GetAttribute("Hinge")
				local side = leaf and leaf:GetAttribute("Side")
				if leaf and leaf:IsA("Model") and typeof(hinge) == "Vector3" and type(side) == "number" then
					local parts: { BasePart } = {}
					local base: { CFrame } = {}
					for _, d in leaf:GetDescendants() do
						if d:IsA("BasePart") then
							table.insert(parts, d)
							table.insert(base, d.CFrame)
						end
					end
					table.insert(leaves, { model = leaf, parts = parts, base = base, hinge = hinge, side = side })
				end
			end
			local chandelier = house:FindFirstChild("Chandelier")
			local hall = chandelier and chandelier:FindFirstChildOfClass("PointLight")
			doors[i] = {
				i = i,
				house = house,
				leaves = leaves,
				frame = frames[i],
				host = nil,
				hostRoot = nil,
				hostHome = nil,
				open = 0,
				since = 0,
				marker = nil,
				hall = hall,
				hallBase = if hall then hall.Brightness else 0,
			}
		end
	end
end

local function findHost(d: Door)
	if d.host and d.host.Parent then
		return
	end
	local host = hostOf(d.house)
	local root = host and host:FindFirstChild("HumanoidRootPart")
	if host and root and root:IsA("BasePart") then
		d.host = host
		d.hostRoot = root
		d.hostHome = root.CFrame
	end
end

local function setOpen(d: Door, k: number)
	if math.abs(k - d.open) < 1e-3 then
		return
	end
	d.open = k
	local eased = k * k * (3 - 2 * k)
	for _, leaf in d.leaves do
		local pivot = CFrame.new(leaf.hinge)
		local turn = pivot * CFrame.Angles(0, leaf.side * SWING * eased, 0) * pivot:Inverse()
		local cfs = table.create(#leaf.parts)
		for j, b in leaf.base do
			cfs[j] = turn * b
		end
		pcall(function()
			Workspace:BulkMoveTo(leaf.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end)
	end
	if d.hall then
		d.hall.Brightness = d.hallBase * (1 + eased * 1.4)
	end
end

local function say(host: Model, line: string)
	local head = host:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local old = head:FindFirstChild("HostSays")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "HostSays"
	gui.Size = UDim2.fromOffset(260, 64)
	gui.StudsOffset = Vector3.new(0, 2.8, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 70
	gui.AlwaysOnTop = true
	gui.Parent = head
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = rgb(16, 12, 22)
	bubble.BackgroundTransparency = 0.08
	bubble.TextColor3 = rgb(255, 236, 214)
	bubble.FontFace = Brand.Fonts.displayItalic
	bubble.TextScaled = true
	bubble.TextWrapped = true
	bubble.Text = line
	bubble.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = bubble
	local s = Instance.new("UIStroke")
	s.Color = rgb(255, 160, 70)
	s.Thickness = 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = bubble
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.Parent = bubble
	task.delay(3.6, function()
		gui:Destroy()
	end)
end

local function wave(host: Model)
	local humanoid = host:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	pcall(function()
		local a = Instance.new("Animation")
		a.AnimationId = WAVE
		local track = (animator :: Animator):LoadAnimation(a)
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.2)
		task.delay(2.4, function()
			track:Stop(0.4)
		end)
	end)
end

---------------------------------------------------------------------------------------------------
-- Markers over the doors
---------------------------------------------------------------------------------------------------
local function mark(d: Door)
	local gui = d.marker
	if not gui then
		local holder = HolidayKit.folder("HolidayLane")
		local p = HolidayKit.anchor(holder, "DoorMarker", (d.frame * CFrame.new(0, 17.4, -3)).Position)
		local g = Instance.new("BillboardGui")
		g.Name = "Marker"
		g.Size = UDim2.fromScale(4.2, 4.2)
		g.LightInfluence = 0
		g.MaxDistance = 220
		g.Parent = p
		local label = Instance.new("TextLabel")
		label.Name = "Glyph"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.FontFace = Brand.Fonts.heavy
		label.Parent = g
		d.marker = g
		gui = g
	end
	local label = (gui :: BillboardGui):FindFirstChild("Glyph") :: TextLabel
	if visited[d.i] then
		label.Text = "✓"
		label.TextColor3 = rgb(255, 214, 120)
		label.TextStrokeColor3 = rgb(60, 40, 10)
		label.TextStrokeTransparency = 0.2
	else
		label.Text = "🎃"
		label.TextStrokeTransparency = 1
	end
end

---------------------------------------------------------------------------------------------------
-- The dressing while you're on the Lane
---------------------------------------------------------------------------------------------------
local function dress()
	local model = lane
	if dressing or not model then
		return
	end
	local f = HolidayKit.folder("HolidayLane")
	dressing = f
	local O = HolidayGames.origin("lane")
	local L = HolidayGames.Lane
	local rng = Random.new(77)
	-- The mist, rolling low along the cobbles.
	local banks = Quality.count(9, 4)
	for k = 1, banks do
		local x = -L.half + 10 + (k - 0.5) / banks * (L.minuitX + L.half - 30)
		local p = HolidayKit.anchor(f, "Mist", O + Vector3.new(x, 1.2, 0))
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(rgb(150, 120, 200), rgb(90, 70, 130))
		e.LightEmission = 0.25
		e.Rate = 3 * Quality.level()
		e.Lifetime = NumberRange.new(9, 14)
		e.Speed = NumberRange.new(0.6, 1.6)
		e.SpreadAngle = Vector2.new(180, 10)
		e.Acceleration = Vector3.new(0.4, 0, 0)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 18) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.86), NumberSequenceKeypoint.new(1, 1) })
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-8, 8)
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		p.Size = Vector3.new((L.minuitX + L.half) / banks, 1, 40)
		e.Parent = p
	end
	-- Candles floating over the Lane.
	candles = {}
	for _ = 1, Quality.count(18, 6) do
		local base = O + Vector3.new(rng:NextNumber(-L.half + 20, L.minuitX - 30), rng:NextNumber(11, 17), rng:NextNumber(-20, 20))
		local stick: BasePart = HolidayProps.part(f, "Candle", Vector3.new(0.5, 1.6, 0.5), CFrame.new(base), rgb(250, 240, 220), Enum.Material.SmoothPlastic)
		local flame: BasePart = HolidayProps.ellipsoid(f, "Flame", Vector3.new(0.3, 0.6, 0.3), CFrame.new(base + Vector3.new(0, 1.1, 0)), rgb(255, 196, 90), Enum.Material.Neon)
		if #candles % 4 == 0 then
			local l = Instance.new("PointLight")
			l.Color = rgb(255, 170, 90)
			l.Brightness = 1
			l.Range = 12
			l.Parent = flame
			HolidayKit.flicker(l)
		end
		table.insert(candles, { part = stick, flame = flame, base = base, phase = rng:NextNumber(0, 10) })
	end
	-- Bats crossing the sky (cartoon ones).
	bats = {}
	for k = 1, Quality.count(7, 2) do
		local p: BasePart = HolidayKit.anchor(f, "Bat", O)
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromScale(5, 5)
		g.LightInfluence = 0
		g.MaxDistance = 2000
		g.Parent = p
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = "🦇"
		label.Parent = g
		table.insert(bats, { part = p, label = label, centre = O + Vector3.new(rng:NextNumber(-120, 120), rng:NextNumber(70, 110), rng:NextNumber(-60, 60)), r = rng:NextNumber(30, 70), phase = k * 1.7, speed = rng:NextNumber(0.25, 0.5) })
	end
	-- Every lamp, jack-o'-lantern and brazier flickers; the braziers burn.
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") then
			local p = d.Parent
			if p and (p.Name == "Glow" or p.Name == "Lantern" or p.Name == "GateLantern" or p.Name == "Fire") then
				HolidayKit.flicker(d)
			end
		elseif d:IsA("BasePart") and d:GetAttribute("Flame") == true then
			HolidayKit.fire(d, 2.6)
		end
	end
	for _, d in doors do
		mark(d)
	end
	moving, movingTo = {}, {}
	for _, c in candles do
		table.insert(moving, c.part)
		table.insert(moving, c.flame)
	end
	for _, b in bats do
		table.insert(moving, b.part)
	end
	for i, p in moving do
		movingTo[i] = p.CFrame
	end
end

local function undress()
	local f = dressing
	if not f then
		return
	end
	dressing = nil
	HolidayKit.unflicker(f)
	if lane then
		HolidayKit.unflicker(lane)
		for _, d in lane:GetDescendants() do
			if d:IsA("ParticleEmitter") and d.Name == "HolidayFire" then
				d:Destroy()
			end
		end
	end
	for _, d in doors do
		if d.marker then
			local p = d.marker.Parent
			if p then
				p:Destroy()
			end
			d.marker = nil
		end
	end
	f:Destroy()
	candles = {}
	bats = {}
	moving, movingTo = {}, {}
end

---------------------------------------------------------------------------------------------------
-- What happens
---------------------------------------------------------------------------------------------------

-- The Lane arrived on this screen (or left it).
function HolidayLane.attach(model: Model?)
	if model == lane then
		return
	end
	undress()
	lane = model
	doors = {}
	if model then
		index(model)
	end
end

-- Someone knocked at door `i`: it opens, its host comes out and waves; a treat for the knocker
-- unless they'd had theirs this round.
function HolidayLane.door(i: number, by: number, empty: boolean?, treatKind: string?)
	local d = doors[i]
	if not d then
		return
	end
	findHost(d)
	d.since = os.clock()
	Sound.play("bellStrike", 0.35, 1.6)
	local host = d.host
	if host then
		task.delay(0.5, function()
			wave(host)
		end)
	end
	local who = Players:GetPlayerByUserId(by)
	if host and who and not empty then
		-- The treat, from the host's hands to the guest.
		task.delay(1.1, function()
			local root = d.hostRoot
			local from = if root then (root.CFrame * CFrame.new(0, 0.6, -1.4)).Position else d.frame.Position + Vector3.new(0, 4, 0)
			local houseTreat = d.house:GetAttribute("Treat")
			local kind = treatKind or (if type(houseTreat) == "string" then houseTreat else "truffle")
			local treat = HolidayProps.treat(HolidayKit.folder("HolidayLane"), CFrame.new(from), kind)
			HolidayProps.sparkle(treat.PrimaryPart :: BasePart, rgb(255, 200, 120), 18, 0.35)
			HolidayKit.throw(treat, from, function(): Vector3
				local character = who.Character
				local r = character and character:FindFirstChild("HumanoidRootPart")
				return if r and r:IsA("BasePart") then r.CFrame.Position + Vector3.new(0, 1, 0) else from
			end, 4, 0.9, 7, true, function()
				local character = who.Character
				local r = character and character:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") then
					HolidayKit.burst(r.CFrame.Position + Vector3.new(0, 1.5, 0), { rgb(255, 200, 100), rgb(200, 120, 255), rgb(255, 255, 255) }, 26, 0.5)
				end
			end)
		end)
	end
end

-- This guest's treat (and the doors they've knocked at this round).
function HolidayLane.mine(list: { number }?, host: string?, line: string?)
	if list then
		visited = {}
		for _, i in list do
			visited[i] = true
		end
		for _, d in doors do
			if d.marker then
				mark(d)
			end
		end
	end
	if host and line then
		for _, d in doors do
			if d.host and d.host:GetAttribute("Host") == host then
				say(d.host, line)
			end
		end
	end
end

function HolidayLane.visited(): { [number]: boolean }
	return visited
end

-- While the camera is on the Lane, it's dressed.
function HolidayLane.here(on: boolean)
	if on then
		dress()
	else
		undress()
	end
end

function HolidayLane.step(_dt: number, t: number)
	local now = os.clock()
	for _, d in doors do
		if d.since > 0 then
			local age = now - d.since
			-- Open (0.6 s), held, closed (0.7 s).
			local k = if age < 0.6 then age / 0.6 elseif age < OPEN_FOR then 1 elseif age < OPEN_FOR + 0.7 then 1 - (age - OPEN_FOR) / 0.7 else 0
			setOpen(d, math.clamp(k, 0, 1))
			-- The host steps out onto the threshold and back.
			local root, home = d.hostRoot, d.hostHome
			if root and home then
				local step = if age < 0.4 then 0 elseif age < 1.1 then (age - 0.4) / 0.7 elseif age < OPEN_FOR - 0.6 then 1 elseif age < OPEN_FOR + 0.2 then 1 - (age - OPEN_FOR + 0.6) / 0.8 else 0
				step = math.clamp(step, 0, 1)
				root.CFrame = home * CFrame.new(0, 0, -3.2 * step * step * (3 - 2 * step))
			end
			if age >= OPEN_FOR + 0.8 then
				d.since = 0
				setOpen(d, 0)
				if root and home then
					root.CFrame = home
				end
			end
		end
		local m = d.marker
		if m then
			m.StudsOffset = Vector3.new(0, math.sin(t * 2 + d.i) * 0.35, 0)
		end
	end
	if #moving == 0 then
		return
	end
	local n = 0
	for _, c in candles do
		local bob = Vector3.new(0, math.sin(t * 0.9 + c.phase) * 0.6, 0)
		movingTo[n + 1] = CFrame.new(c.base + bob)
		movingTo[n + 2] = CFrame.new(c.base + bob + Vector3.new(0, 1.1, 0)) * CFrame.Angles(math.sin(t * 6 + c.phase) * 0.12, 0, math.cos(t * 5 + c.phase) * 0.12)
		n += 2
	end
	for _, b in bats do
		local a = t * b.speed + b.phase
		n += 1
		movingTo[n] = CFrame.new(b.centre + Vector3.new(math.cos(a) * b.r, math.sin(a * 2.3) * 4, math.sin(a) * b.r * 0.6))
		b.label.Rotation = math.sin(t * 9 + b.phase) * 14
	end
	pcall(function()
		Workspace:BulkMoveTo(moving, movingTo, Enum.BulkMoveMode.FireCFrameChanged)
	end)
end

return HolidayLane

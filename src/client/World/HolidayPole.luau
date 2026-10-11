--!strict
-- Santa's sleigh and the North Pole on this screen (the server builds them, carries the riders and
-- decides every gift). Here: the gifts lying in the snow, wrapped and ribboned, a glint now and then;
-- a gift flying into the arms of whoever picked it up, and the stack each guest carries before
-- them; a ring of gold light at the back of the sleigh while you've gifts to load, and the gifts
-- flying into the sack when you do; the sleigh's own sign (board now / leaving in 0:12 / back from
-- the North Pole in 1:20); and, while you're at the Pole, the snow falling, the chimney smoking,
-- the great tree lit with its star, lights along the workshop's eaves, and the time left before the
-- sleigh leaves, large at the top of the screen.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Quality = require(script.Parent.Parent.Quality)
local Sound = require(script.Parent.Parent.Sound)
local Root = require(script.Parent.Parent.UI.Root)
local Flakes = require(script.Parent.Flakes)
local HolidayKit = require(script.Parent.HolidayKit)

local HolidayPole = {}

local rgb = Color3.fromRGB
local SIZES = { 1.6, 2.1, 2.7 }
local CARGO = CFrame.new(0, 3, 9.8) -- (server/Holidays/Pole's)

type Gift = { id: number, part: BasePart, model: Model }

local area: Model? = nil
local sleigh: Model? = nil
local giftModels: { [number]: Gift } = {} -- by each gift's Id
local limbo: { Gift } = {} -- gifts just taken from the snow, waiting to be thrown to who took them
local stacks: { [Player]: { n: number, model: Model? } } = {}
local connections: { RBXScriptConnection } = {}
local dressing: Folder? = nil
local endSnow: (() -> ())? = nil
local ring: Part? = nil
local sign: BillboardGui? = nil
local kerbSign: Part? = nil
local pill: Frame? = nil
local lastTick = -1
local carrying = 0

local function sleighState(): string?
	local s = Workspace:GetAttribute("SleighState")
	return if type(s) == "string" then s else nil
end

local function leavesIn(): number?
	local at = Workspace:GetAttribute("SleighLeaves")
	if type(at) ~= "number" then
		return nil
	end
	local ok, now = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return math.max(0, at - (if ok then now else os.time()))
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

---------------------------------------------------------------------------------------------------
-- Gifts in the snow
---------------------------------------------------------------------------------------------------
local function giftId(part: Instance): number?
	local id = part:GetAttribute("Id")
	return if part:IsA("BasePart") and type(id) == "number" then id else nil
end

local function addGift(part: BasePart)
	local id = giftId(part)
	if not id or giftModels[id] then
		return
	end
	local wrapIndex = part:GetAttribute("Wrap")
	local sizeIndex = part:GetAttribute("Size")
	local wrap = HolidayProps.WRAPS[if type(wrapIndex) == "number" then math.clamp(wrapIndex, 1, #HolidayProps.WRAPS) else 1]
	local s = SIZES[if type(sizeIndex) == "number" then math.clamp(sizeIndex, 1, 3) else 2]
	local floor = part.CFrame * CFrame.new(0, -part.Size.Y / 2, 0)
	local m = HolidayProps.gift(HolidayKit.folder("HolidayGifts"), floor * CFrame.Angles(0, 0, math.rad(4)), Vector3.new(s, s * 0.9, s * 1.1), wrap[1], wrap[2])
	if math.random() < 0.4 then
		HolidayKit.glint(m.PrimaryPart :: BasePart, wrap[2], 0.5)
	end
	giftModels[id] = { id = id, part = part, model = m }
end

local function removeGift(id: number)
	local g = giftModels[id]
	if not g then
		return
	end
	giftModels[id] = nil
	-- (Held a moment: "picked" says who took it, and it flies to them.)
	table.insert(limbo, g)
	task.delay(0.6, function()
		local i = table.find(limbo, g)
		if i then
			table.remove(limbo, i)
			g.model:Destroy()
		end
	end)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

---------------------------------------------------------------------------------------------------
-- What everyone carries
---------------------------------------------------------------------------------------------------
local function restack(player: Player)
	local want = player:GetAttribute("GiftsCarried")
	local n = if type(want) == "number" then want else 0
	local s = stacks[player]
	if s and s.n == n and s.model and s.model.Parent then
		return
	end
	if s and s.model then
		s.model:Destroy()
	end
	stacks[player] = { n = n, model = nil }
	if player == Players.LocalPlayer then
		carrying = n
	end
	local root = rootOf(player)
	if n <= 0 or not root then
		return
	end
	local m = Instance.new("Model")
	m.Name = "GiftStack"
	for k = 1, n do
		local wrap = HolidayProps.WRAPS[((player.UserId + k) % #HolidayProps.WRAPS) + 1]
		local cf = root.CFrame * CFrame.new(0, -0.6 + (k - 1) * 1.05, -1.6) * CFrame.Angles(0, (k % 2) * 0.35 - 0.15, 0)
		local g = HolidayProps.gift(m, cf, Vector3.new(1.3, 1, 1.3), wrap[1], wrap[2])
		for _, d in g:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				d.CanCollide = false
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = d
				w.Parent = d
			end
		end
	end
	m.Parent = HolidayKit.folder("HolidayStacks")
	stacks[player].model = m
end

local function watchPlayer(player: Player)
	table.insert(connections, player:GetAttributeChangedSignal("GiftsCarried"):Connect(function()
		restack(player)
	end))
	table.insert(connections, player.CharacterAdded:Connect(function()
		task.wait(0.5)
		restack(player)
	end))
	restack(player)
end

---------------------------------------------------------------------------------------------------
-- The sleigh's sign, the ring where gifts are loaded, the clock at the top of the screen
---------------------------------------------------------------------------------------------------
local function ensureSign()
	local m = sleigh
	local root = m and m.PrimaryPart
	if not m or not root then
		return
	end
	if sign and sign.Parent == root then
		return
	end
	local g = Instance.new("BillboardGui")
	g.Name = "SleighSign"
	g.Size = UDim2.fromOffset(300, 86)
	g.StudsOffset = Vector3.new(0, 14, 0)
	g.LightInfluence = 0
	g.MaxDistance = 260
	g.Parent = root
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.45, 0)
	title.FontFace = Brand.Fonts.display
	title.TextScaled = true
	title.TextColor3 = rgb(255, 226, 150)
	title.TextStrokeTransparency = 0.3
	title.Text = "SANTA'S SLEIGH"
	title.Parent = g
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromScale(0, 0.48)
	line.Size = UDim2.new(1, 0, 0.42, 0)
	line.FontFace = Brand.Fonts.heavy
	line.TextScaled = true
	line.TextColor3 = rgb(255, 255, 255)
	line.TextStrokeTransparency = 0.3
	line.Parent = g
	sign = g
end

local function updateSign()
	ensureSign()
	local g = sign
	if not g then
		return
	end
	local line = g:FindFirstChild("Line") :: TextLabel?
	if not line then
		return
	end
	local state = sleighState()
	local left = leavesIn()
	local atPole = HolidayGames.areaAt((sleigh and sleigh.PrimaryPart and sleigh.PrimaryPart.CFrame.Position) or Vector3.zero) == "pole"
	if state == "home" then
		line.Text = "To the North Pole! Board now"
	elseif state == "boarding" then
		line.Text = if left then "Leaving in " .. clock(left) else "Leaving soon"
	elseif state == "pole" and atPole then
		line.Text = if left then "Back to the Maison in " .. clock(left) else "Back to the Maison soon"
	else
		line.Text = ""
	end
end

-- A sign at the kerb while the sleigh is away.
local function updateKerb()
	local state = sleighState()
	local away = state == "pole" or state == "toPole"
	if away and not kerbSign then
		local p = HolidayKit.anchor(HolidayKit.folder("HolidaySleighSign"), "KerbSign", HolidayGames.HOME_SLEIGH.Position + Vector3.new(0, 8, 0))
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(320, 70)
		g.LightInfluence = 0
		g.MaxDistance = 220
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.Name = "Line"
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.FontFace = Brand.Fonts.heavy
		t.TextScaled = true
		t.TextColor3 = rgb(255, 236, 214)
		t.TextStrokeTransparency = 0.3
		t.Parent = g
		kerbSign = p
	elseif not away and kerbSign then
		kerbSign:Destroy()
		kerbSign = nil
	end
	local k = kerbSign
	if k then
		local t = k:FindFirstChildWhichIsA("BillboardGui")
		local label = t and t:FindFirstChild("Line") :: TextLabel?
		if label then
			local left = leavesIn()
			local flight = Workspace:GetAttribute("SleighFlight")
			local back = if state == "pole" and left and type(flight) == "number" then left + flight else nil
			label.Text = if back then "🛷 Santa's sleigh is at the North Pole · back in " .. clock(back) else "🛷 Santa's sleigh is on its way to the North Pole"
		end
	end
end

local function updateRing()
	local state = sleighState()
	local m = sleigh
	local want = m ~= nil and m.PrimaryPart ~= nil and state == "pole" and carrying > 0
	if want and not ring then
		local p = Instance.new("Part")
		p.Name = "LoadRing"
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.2, 22, 22)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = rgb(255, 214, 120)
		p.Transparency = 0.6
		p.Parent = HolidayKit.folder("HolidayGifts")
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromOffset(240, 56)
		g.StudsOffset = Vector3.new(0, 9, 0)
		g.LightInfluence = 0
		g.AlwaysOnTop = true
		g.MaxDistance = 400
		g.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.FontFace = Brand.Fonts.heavy
		t.TextScaled = true
		t.TextColor3 = rgb(255, 226, 150)
		t.TextStrokeTransparency = 0.2
		t.Text = "LOAD YOUR GIFTS HERE ⬇"
		t.Parent = g
		ring = p
	elseif not want and ring then
		ring:Destroy()
		ring = nil
	end
	local r = ring
	if r and m and m.PrimaryPart then
		local at = (m.PrimaryPart.CFrame * CARGO).Position
		r.CFrame = CFrame.new(at.X, HolidayGames.origin("pole").Y + 0.12, at.Z) * CFrame.Angles(0, 0, math.pi / 2)
		r.Transparency = 0.55 + 0.25 * math.sin(os.clock() * 4)
	end
end

local function updatePill()
	local state = sleighState()
	local me = Players.LocalPlayer
	local root = rootOf(me)
	local here = root and HolidayGames.areaAt(root.CFrame.Position)
	local left = leavesIn()
	local seated = false
	local humanoid = me.Character and me.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart and humanoid.SeatPart.Name == "SleighSeat" then
		seated = true
	end
	local show = left ~= nil and ((state == "pole" and here == "pole") or (state == "boarding" and seated))
	if not show then
		if pill then
			pill:Destroy()
			pill = nil
		end
		return
	end
	local p = pill
	if not p then
		local f = Instance.new("Frame")
		f.Name = "SleighClock"
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.Size = UDim2.fromOffset(300, 64)
		f.BackgroundColor3 = rgb(14, 12, 16)
		f.BackgroundTransparency = 0.12
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 18)
		c.Parent = f
		local s = Instance.new("UIStroke")
		s.Name = "Edge"
		s.Color = rgb(255, 214, 120)
		s.Thickness = 2
		s.Parent = f
		local cap = Instance.new("TextLabel")
		cap.Name = "Caption"
		cap.BackgroundTransparency = 1
		cap.Position = UDim2.fromOffset(0, 6)
		cap.Size = UDim2.new(1, 0, 0, 16)
		cap.FontFace = Brand.Fonts.bodyBold
		cap.TextSize = 13
		cap.TextColor3 = rgb(255, 222, 150)
		cap.Parent = f
		local digits = Instance.new("TextLabel")
		digits.Name = "Digits"
		digits.BackgroundTransparency = 1
		digits.Position = UDim2.fromOffset(0, 22)
		digits.Size = UDim2.new(1, 0, 0, 36)
		digits.FontFace = Brand.Fonts.figures
		digits.TextSize = 32
		digits.TextColor3 = rgb(255, 255, 255)
		digits.Parent = f
		f.Parent = Root.hud
		pill = f
		p = f
	end
	local f = p :: Frame
	f.Position = UDim2.new(0.5, 0, 0, math.max(14, Root.topClear() + 10))
	local cap = f:FindFirstChild("Caption") :: TextLabel
	local digits = f:FindFirstChild("Digits") :: TextLabel
	local edge = f:FindFirstChild("Edge") :: UIStroke
	cap.Text = if state == "pole" then "🛷  THE SLEIGH LEAVES FOR HOME IN" else "🛷  THE SLEIGH TAKES OFF IN"
	digits.Text = clock(left :: number)
	local urgent = (left :: number) <= 15
	digits.TextColor3 = if urgent then rgb(255, 120, 110) else rgb(255, 255, 255)
	edge.Color = if urgent then rgb(255, 90, 80) else rgb(255, 214, 120)
	local whole = math.ceil(left :: number)
	if urgent and whole ~= lastTick and whole <= 10 and whole > 0 then
		lastTick = whole
		Sound.play("deal", 0.6, 1.4)
	end
end

---------------------------------------------------------------------------------------------------
-- The dressing while you're at the Pole
---------------------------------------------------------------------------------------------------
local function dress()
	local model = area
	if dressing or not model then
		return
	end
	local f = HolidayKit.folder("HolidayPole")
	dressing = f
	endSnow = Flakes.fall({
		seconds = 1e9,
		centre = function(): Vector3?
			local cam = Workspace.CurrentCamera
			return if cam then cam.CFrame.Position else nil
		end,
		colours = { rgb(255, 255, 255), rgb(226, 236, 255) },
		material = Enum.Material.SmoothPlastic,
		size = Vector3.new(0.22, 0.22, 0.04),
		count = Quality.count(90, 30),
		radius = 46,
		height = 34,
		fall = 5,
		below = 6,
		flutter = 1.2,
	})
	-- The chimney smokes.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Smoke") == true then
			HolidayKit.smoke(d)
		elseif d:IsA("PointLight") and d.Parent and (d.Parent.Name == "Lantern" or d.Parent.Name == "Window") then
			HolidayKit.flicker(d)
		end
	end
	-- The great tree: a winding string of lights and its star.
	local base = model:GetAttribute("Tree")
	if typeof(base) == "Vector3" then
		local height = 58
		local R = height * 0.31
		local colours = { rgb(255, 80, 80), rgb(255, 214, 110), rgb(110, 200, 255), rgb(120, 255, 150), rgb(255, 140, 220) }
		local n = Quality.count(120, 40)
		for i = 0, n do
			local t = i / n
			local y = height * (0.12 + t * 0.76)
			local r = R * (1 - t * 0.88) * 0.98 + 0.4
			local a = t * 6 * math.pi * 2
			HolidayProps.ball(f, "TreeBulb", 0.7, base + Vector3.new(math.cos(a) * r, y, math.sin(a) * r), colours[(i % #colours) + 1], Enum.Material.Neon)
		end
		local star = HolidayKit.anchor(f, "TreeStar", base + Vector3.new(0, height * 0.97, 0))
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromScale(9, 9)
		g.LightInfluence = 0
		g.MaxDistance = 2000
		g.Parent = star
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Text = "★"
		t.TextColor3 = rgb(255, 222, 120)
		t.TextStrokeColor3 = rgb(255, 246, 210)
		t.TextStrokeTransparency = 0.4
		t.Parent = g
		local l = Instance.new("PointLight")
		l.Color = rgb(255, 220, 140)
		l.Brightness = 2.4
		l.Range = 40
		l.Parent = star
		HolidayProps.sparkle(star, rgb(255, 230, 150), 8, 1.2)
	end
	-- Lights along the workshop's eaves.
	local W = HolidayGames.origin("pole") + HolidayGames.Pole.workshop
	local colours = { rgb(255, 80, 80), rgb(255, 230, 140), rgb(120, 255, 150), rgb(110, 200, 255) }
	local every = if Quality.rich() then 2.2 else 3.6
	local x = -35
	local k = 0
	while x <= 35 do
		k += 1
		HolidayProps.ball(f, "EaveBulb", 0.55, W + Vector3.new(x, 19.4 - math.abs(math.sin(x * 0.45)) * 0.6, -18.9), colours[(k % #colours) + 1], Enum.Material.Neon)
		x += every
	end
end

local function undress()
	local f = dressing
	if not f then
		return
	end
	dressing = nil
	if endSnow then
		endSnow()
		endSnow = nil
	end
	HolidayKit.unflicker(f)
	if area then
		HolidayKit.unflicker(area)
		for _, d in area:GetDescendants() do
			if d:IsA("ParticleEmitter") and d.Name == "HolidaySmoke" then
				d:Destroy()
			end
		end
	end
	f:Destroy()
end

---------------------------------------------------------------------------------------------------
-- What happens
---------------------------------------------------------------------------------------------------

-- The North Pole and the sleigh arrived on this screen (or went).
function HolidayPole.attach(poleModel: Model?, sleighModel: Model?)
	if poleModel ~= area then
		undress()
		for _, g in giftModels do
			g.model:Destroy()
		end
		giftModels = {}
		for _, c in connections do
			c:Disconnect()
		end
		connections = {}
		area = poleModel
		if poleModel then
			local gifts = poleModel:FindFirstChild("Gifts")
			if gifts then
				for _, p in gifts:GetChildren() do
					if p:IsA("BasePart") then
						addGift(p)
					end
				end
				table.insert(connections, gifts.ChildAdded:Connect(function(p)
					if p:IsA("BasePart") then
						addGift(p)
					end
				end))
				table.insert(connections, gifts.ChildRemoved:Connect(function(p)
					local id = giftId(p)
					if id then
						removeGift(id)
					end
				end))
			end
			for _, player in Players:GetPlayers() do
				watchPlayer(player)
			end
			table.insert(connections, Players.PlayerAdded:Connect(watchPlayer))
			table.insert(connections, Players.PlayerRemoving:Connect(function(player: Player)
				local s = stacks[player]
				if s and s.model then
					s.model:Destroy()
				end
				stacks[player] = nil
			end))
		else
			for _, s in stacks do
				if s.model then
					s.model:Destroy()
				end
			end
			stacks = {}
			carrying = 0
		end
	end
	if sleighModel ~= sleigh then
		sleigh = sleighModel
		sign = nil
	end
end

-- A gift picked up (by anyone): it flies into their arms.
function HolidayPole.picked(id: number, by: number)
	local who = Players:GetPlayerByUserId(by)
	for i, g in limbo do
		if g.id == id then
			table.remove(limbo, i)
			local root = g.model.PrimaryPart
			if who and root then
				HolidayKit.throw(g.model, root.CFrame.Position, function(): Vector3
					local r = rootOf(who)
					return if r then r.CFrame.Position + Vector3.new(0, 0.5, 0) else root.CFrame.Position
				end, 3, 0.35, 5, true)
			else
				g.model:Destroy()
			end
			if who == Players.LocalPlayer then
				Sound.play("pickup", 0.6, 1.2)
			end
			return
		end
	end
end

-- Gifts loaded on the sleigh (by anyone): they fly from the guest into the sack.
function HolidayPole.loaded(by: number, n: number)
	local who = Players:GetPlayerByUserId(by)
	local m = sleigh
	local root = who and rootOf(who)
	if not root or not m or not m.PrimaryPart then
		return
	end
	local sack = (m.PrimaryPart.CFrame * CFrame.new(0, 6, 8.8)).Position
	for k = 1, math.min(n, 8) do
		task.delay((k - 1) * 0.09, function()
			local wrap = HolidayProps.WRAPS[(k % #HolidayProps.WRAPS) + 1]
			local from = root.CFrame.Position + Vector3.new(0, 1 + k * 0.4, 0)
			local g = HolidayProps.gift(HolidayKit.folder("HolidayGifts"), CFrame.new(from), Vector3.new(1.3, 1, 1.3), wrap[1], wrap[2])
			HolidayKit.throw(g, from, function(): Vector3
				return sack
			end, 6, 0.55, 6, true, function()
				HolidayKit.burst(sack, { rgb(255, 214, 120), rgb(255, 255, 255), rgb(255, 90, 90) }, 10, 0.5)
			end)
		end)
	end
	if who == Players.LocalPlayer then
		Sound.play("bellTree", 0.6)
	end
end

function HolidayPole.here(on: boolean)
	if on then
		dress()
	else
		undress()
	end
end

local beat = 0
function HolidayPole.step(dt: number, _t: number)
	beat += dt
	updateRing()
	if beat >= 0.25 then
		beat = 0
		if sleigh then
			updateSign()
		end
		updateKerb()
		updatePill()
	end
end

-- How many gifts this guest has in their arms (for the card).
function HolidayPole.carrying(): number
	return carrying
end

-- For tests: the gifts drawn in the snow.
function HolidayPole.count(): number
	local n = 0
	for _ in giftModels do
		n += 1
	end
	return n
end

return HolidayPole

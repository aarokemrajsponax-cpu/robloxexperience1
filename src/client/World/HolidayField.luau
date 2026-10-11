--!strict
-- The Harvest Field on this screen (the server builds the field and moves each turkey, one small
-- invisible part each, ten times a second). Every turkey is drawn here round its part: bronze, with
-- its fan of feathers, gliding smoothly after it, legs running as fast as it runs, pecking at the
-- grass when it stops; the golden one in gold, sparkling. A catch: a puff of feathers and a
-- "GOBBLE!". While you're in the field: festoon lights strung from the barn, leaves falling,
-- lanterns and candles flickering. How much follows Quality.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Quality = require(script.Parent.Parent.Quality)
local HolidayKit = require(script.Parent.HolidayKit)

local HolidayField = {}

local rgb = Color3.fromRGB

type Bird = {
	id: number,
	part: BasePart,
	model: Model,
	root: BasePart,
	legs: { { weld: Weld, base: CFrame, hip: CFrame, side: number } },
	at: CFrame,
	phase: number,
}

local field: Model? = nil
local birds: { [BasePart]: Bird } = {}
local folder: Folder? = nil
local connections: { RBXScriptConnection } = {}
local dressing: Folder? = nil
local leaves: { { part: BasePart, label: TextLabel, phase: number, fall: number, at: Vector3 } } = {}

local function rigTurkey(m: Model): { { weld: Weld, base: CFrame, hip: CFrame, side: number } }
	local root = m.PrimaryPart :: BasePart
	local legs = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = d
			w.C0 = root.CFrame:ToObjectSpace(d.CFrame)
			w.Parent = d
			d.Anchored = false
			d.Massless = true
			d.CanCollide = false
			local side = if string.sub(d.Name, -1) == "L" then -1 elseif string.sub(d.Name, -1) == "R" then 1 else 0
			if (string.sub(d.Name, 1, 3) == "Leg" or string.sub(d.Name, 1, 4) == "Foot") and side ~= 0 then
				table.insert(legs, { weld = w, base = w.C0, hip = CFrame.new(side * 0.42, 1.2, 0.05), side = side })
			end
		end
	end
	root.Anchored = true
	return legs
end

local function add(part: BasePart)
	if birds[part] or not folder then
		return
	end
	local id = part:GetAttribute("Id")
	local golden = part:GetAttribute("Golden") == true
	local ground = part.CFrame * CFrame.new(0, -1.5, 0)
	local m = HolidayProps.turkey(folder, ground, golden)
	local legs = rigTurkey(m)
	birds[part] = { id = if type(id) == "number" then id else 0, part = part, model = m, root = m.PrimaryPart :: BasePart, legs = legs, at = ground, phase = math.random() * 6 }
end

local function remove(part: BasePart)
	local b = birds[part]
	if b then
		birds[part] = nil
		b.model:Destroy()
	end
end

local function watchBirds(model: Model)
	local f = model:FindFirstChild("Turkeys")
	if not f then
		return
	end
	for _, p in f:GetChildren() do
		if p:IsA("BasePart") then
			add(p)
		end
	end
	table.insert(connections, f.ChildAdded:Connect(function(p)
		if p:IsA("BasePart") then
			add(p)
		end
	end))
	table.insert(connections, f.ChildRemoved:Connect(function(p)
		if p:IsA("BasePart") then
			remove(p)
		end
	end))
end

---------------------------------------------------------------------------------------------------
-- The dressing while you're in the field
---------------------------------------------------------------------------------------------------
local function dress()
	local model = field
	if dressing or not model then
		return
	end
	local f = HolidayKit.folder("HolidayField")
	dressing = f
	local O = HolidayGames.origin("field")
	local F = HolidayGames.Field
	-- Festoon lights strung from the barn's corners across the yard.
	local colours = { rgb(255, 210, 140), rgb(255, 170, 90), rgb(255, 236, 190) }
	local runs = {
		{ O + Vector3.new(-27, 17, F.barnDoors.Z + 2), O + Vector3.new(-120, 12.6, 60) },
		{ O + Vector3.new(27, 17, F.barnDoors.Z + 2), O + Vector3.new(120, 12.6, 30) },
		{ O + Vector3.new(-120, 12.6, 60), O + Vector3.new(-9, 13.6, F.minZ) },
	}
	local every = if Quality.rich() then 3.4 else 5.5
	for _, r in runs do
		local a, b = r[1], r[2]
		local n = math.max(4, math.floor((b - a).Magnitude / every))
		for k = 1, n - 1 do
			local s = k / n
			local p = a:Lerp(b, s) - Vector3.new(0, math.sin(s * math.pi) * 5, 0)
			HolidayProps.ball(f, "Bulb", 0.55, p, colours[(k % #colours) + 1], Enum.Material.Neon)
		end
	end
	-- Leaves falling round the camera.
	leaves = {}
	for k = 1, Quality.count(14, 5) do
		local p: BasePart = HolidayKit.anchor(f, "Leaf", O)
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromScale(1.6, 1.6)
		g.LightInfluence = 0.6
		g.MaxDistance = 120
		g.Parent = p
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.Text = if k % 3 == 0 then "🍁" else "🍂"
		label.Parent = g
		table.insert(leaves, { part = p, label = label, phase = k * 1.3, fall = 0, at = O + Vector3.new(math.random(-40, 40), 20 + math.random() * 20, math.random(-40, 40)) })
	end
	-- Lanterns and candles flicker; the table's candles burn.
	for _, d in model:GetDescendants() do
		if d:IsA("PointLight") then
			local p = d.Parent
			if p and (p.Name == "Lamp" or p.Name == "Lantern" or p.Name == "GateLantern" or p.Name == "Flame" or p.Name == "Glow") then
				HolidayKit.flicker(d)
			end
		elseif d:IsA("BasePart") and d:GetAttribute("Flame") == true then
			HolidayKit.fire(d, 0.5)
		end
	end
end

local function undress()
	local f = dressing
	if not f then
		return
	end
	dressing = nil
	HolidayKit.unflicker(f)
	if field then
		HolidayKit.unflicker(field)
		for _, d in field:GetDescendants() do
			if d:IsA("ParticleEmitter") and d.Name == "HolidayFire" then
				d:Destroy()
			end
		end
	end
	f:Destroy()
	leaves = {}
end

---------------------------------------------------------------------------------------------------
-- What happens
---------------------------------------------------------------------------------------------------

function HolidayField.attach(model: Model?)
	if model == field then
		return
	end
	undress()
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	for part in birds do
		remove(part)
	end
	field = model
	if folder then
		folder:Destroy()
		folder = nil
	end
	if model then
		folder = HolidayKit.folder("HolidayTurkeys")
		watchBirds(model)
	end
end

-- A turkey caught (by anyone): feathers fly and it gobbles.
function HolidayField.caught(id: number, golden: boolean, at: Vector3?)
	local where = at
	for _, b in birds do
		if b.id == id then
			where = b.root.CFrame.Position + Vector3.new(0, 1.8, 0)
		end
	end
	if not where then
		return
	end
	local feathers = if golden then { rgb(255, 214, 110), rgb(255, 246, 210) } else { rgb(120, 76, 46), rgb(236, 216, 176), rgb(80, 50, 32) }
	HolidayKit.burst(where, feathers, if golden then 40 else 24, 0.7, true)
	HolidayKit.words(where + Vector3.new(0, 2, 0), if golden then "GOLDEN GOBBLE!" else "GOBBLE!", if golden then rgb(255, 214, 110) else rgb(255, 236, 214), if golden then 12 else 8)
end

function HolidayField.here(on: boolean)
	if on then
		dress()
	else
		undress()
	end
end

function HolidayField.step(dt: number, t: number)
	local alpha = 1 - math.exp(-12 * dt)
	for part, b in birds do
		if not part.Parent then
			continue
		end
		local target = part.CFrame * CFrame.new(0, -1.5, 0)
		b.at = b.at:Lerp(target, alpha)
		local speed = part:GetAttribute("Speed")
		local v = if type(speed) == "number" then speed else 0
		b.phase += dt * (4 + v * 0.85)
		local swing = math.sin(b.phase) * math.min(0.95, 0.12 + v / 20)
		local bob = math.abs(math.sin(b.phase)) * math.min(0.28, v / 55)
		-- Pecking at the grass when it stands still.
		local peck = if v < 0.5 then math.max(0, math.sin(t * 2.2 + b.id)) ^ 8 * 0.55 else 0
		b.root.CFrame = b.at * CFrame.new(0, bob, 0) * CFrame.Angles(-peck, 0, 0)
		for _, leg in b.legs do
			local a = swing * leg.side
			leg.weld.C0 = leg.hip * CFrame.Angles(a, 0, 0) * leg.hip:Inverse() * leg.base
		end
	end
	-- Leaves drifting down round the camera, back up top when they reach the grass.
	if #leaves > 0 then
		local cam = Workspace.CurrentCamera
		local c = if cam then cam.CFrame.Position else HolidayGames.origin("field")
		for _, l in leaves do
			l.fall += dt
			local p = l.at + Vector3.new(math.sin(t * 0.7 + l.phase) * 3, -l.fall * 3.2, math.cos(t * 0.5 + l.phase) * 2)
			if p.Y < HolidayGames.origin("field").Y + 0.5 or (p - c).Magnitude > 70 then
				l.at = c + Vector3.new(math.random(-36, 36), math.random(10, 26), math.random(-36, 36))
				l.fall = 0
				p = l.at
			end
			l.part.CFrame = CFrame.new(p)
			l.label.Rotation = math.sin(t * 2 + l.phase) * 40
		end
	end
end

-- For tests: the turkeys drawn here.
function HolidayField.count(): number
	local n = 0
	for _ in birds do
		n += 1
	end
	return n
end


return HolidayField

--!strict
-- The holiday games' little moves, on this screen: something thrown in an arc (a treat to a guest,
-- a gift into the sleigh), a burst of sparkle or feathers, words rising and fading over a spot,
-- and a light that flickers like a flame. Everything here is this screen's own, made and tidied
-- away here, and moved once a frame from World/HolidayPlay's beat.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Quality = require(script.Parent.Parent.Quality)

local HolidayKit = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local WHITE = Color3.new(1, 1, 1)

-- Where this screen's own holiday things live.
function HolidayKit.folder(name: string): Folder
	local parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = name
	nf.Parent = parent
	return nf
end

-- A part that's only there to carry something (a light, an emitter, a billboard).
function HolidayKit.anchor(parent: Instance, name: string, at: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = CFrame.new(at)
	p.Parent = parent
	return p
end

---------------------------------------------------------------------------------------------------
-- Things in flight
---------------------------------------------------------------------------------------------------
type Flight = {
	parts: { BasePart },
	offsets: { CFrame },
	from: Vector3,
	to: () -> Vector3,
	height: number,
	seconds: number,
	t: number,
	spin: number,
	shrink: boolean,
	done: (() -> ())?,
	model: Model,
}
local flights: { Flight } = {}

-- Throws `model` (its parts anchored, its PrimaryPart its middle) from `from` to wherever `to()`
-- says at the end (a guest who's moving), arcing `height` over the straight line, in `seconds`,
-- turning as it goes. It's destroyed on arrival, after `done`.
function HolidayKit.throw(model: Model, from: Vector3, to: () -> Vector3, height: number, seconds: number, spin: number?, shrink: boolean?, done: (() -> ())?)
	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
	end
	local parts: { BasePart } = {}
	local offsets: { CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			table.insert(parts, d)
			table.insert(offsets, root.CFrame:ToObjectSpace(d.CFrame))
		end
	end
	table.insert(flights, {
		parts = parts,
		offsets = offsets,
		from = from,
		to = to,
		height = height,
		seconds = math.max(0.1, seconds),
		t = 0,
		spin = spin or 6,
		shrink = shrink == true,
		done = done,
		model = model,
	})
end

local function stepFlights(dt: number)
	for i = #flights, 1, -1 do
		local f = flights[i]
		f.t += dt
		local k = math.clamp(f.t / f.seconds, 0, 1)
		local ok, target = pcall(f.to)
		local to = if ok and typeof(target) == "Vector3" then target else f.from
		local at = f.from:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * f.height, 0)
		local frame = CFrame.new(at) * CFrame.Angles(f.t * f.spin * 0.6, f.t * f.spin, 0)
		local scale = if f.shrink then 1 - 0.65 * k * k else 1
		local cfs = table.create(#f.parts)
		for j, o in f.offsets do
			cfs[j] = frame * (o - o.Position + o.Position * scale)
		end
		pcall(function()
			Workspace:BulkMoveTo(f.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end)
		if k >= 1 then
			table.remove(flights, i)
			if f.done then
				pcall(f.done)
			end
			f.model:Destroy()
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Bursts, words, flames
---------------------------------------------------------------------------------------------------

-- A burst of sparkle (or, with `soft`, of drifting flakes: feathers, confetti) at `at`.
function HolidayKit.burst(at: Vector3, colours: { Color3 }, count: number, size: number, soft: boolean?)
	local holder = HolidayKit.folder("HolidayBursts")
	local p = HolidayKit.anchor(holder, "Burst", at)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	local keys = {}
	for i, c in colours do
		table.insert(keys, ColorSequenceKeypoint.new(if #colours == 1 then 0 else (i - 1) / (#colours - 1), c))
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, colours[1]))
	end
	e.Color = ColorSequence.new(keys)
	e.LightEmission = if soft then 0.2 else 1
	e.Rate = 0
	e.Lifetime = if soft then NumberRange.new(1, 1.8) else NumberRange.new(0.5, 1)
	e.Speed = if soft then NumberRange.new(6, 12) else NumberRange.new(8, 18)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = if soft then Vector3.new(0, -9, 0) else Vector3.new(0, -4, 0)
	e.Drag = if soft then 2.5 else 1.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-200, 200)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, if soft then size * 0.8 else 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = p
	e:Emit(Quality.count(count, math.min(count, 8)))
	task.delay(2.5, function()
		p:Destroy()
	end)
end

type Words = { gui: BillboardGui, label: TextLabel, t: number, life: number, part: Part }
local words: { Words } = {}

-- Words rising over `at` and fading (GOBBLE!, a name, +45).
function HolidayKit.words(at: Vector3, text: string, colour: Color3, studs: number?, life: number?)
	local holder = HolidayKit.folder("HolidayBursts")
	local p = HolidayKit.anchor(holder, "Words", at)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(studs or 8, (studs or 8) * 0.3)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.FontFace = Brand.Fonts.heavy
	label.Text = text
	label.TextColor3 = colour
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	table.insert(words, { gui = gui, label = label, t = 0, life = life or 1.6, part = p })
end

local function stepWords(dt: number)
	for i = #words, 1, -1 do
		local w = words[i]
		w.t += dt
		local k = w.t / w.life
		w.part.CFrame = w.part.CFrame + Vector3.new(0, dt * 2.2, 0)
		w.label.TextTransparency = math.clamp((k - 0.6) / 0.4, 0, 1)
		w.label.TextStrokeTransparency = 0.3 + 0.7 * math.clamp((k - 0.6) / 0.4, 0, 1)
		if k >= 1 then
			table.remove(words, i)
			w.part:Destroy()
		end
	end
end

-- Lights that flicker like flames (a lantern, a jack-o'-lantern, a brazier), each at its own pace.
type Flame = { light: Light, base: number, phase: number }
local flames: { Flame } = {}
local flameClock = 0

function HolidayKit.flicker(light: Light)
	table.insert(flames, { light = light, base = light.Brightness, phase = math.random() * 10 })
end

function HolidayKit.unflicker(within: Instance)
	for i = #flames, 1, -1 do
		local f = flames[i]
		if f.light:IsDescendantOf(within) or f.light.Parent == nil then
			table.remove(flames, i)
		end
	end
end

local function stepFlames(dt: number, t: number)
	-- (Fifteen times a second is flame enough.)
	flameClock += dt
	if flameClock < 1 / 15 then
		return
	end
	flameClock = 0
	for i = #flames, 1, -1 do
		local f = flames[i]
		if f.light.Parent == nil then
			table.remove(flames, i)
			continue
		end
		local n = math.sin(t * 7.3 + f.phase) * 0.5 + math.sin(t * 13.1 + f.phase * 1.7) * 0.3 + math.sin(t * 2.1 + f.phase) * 0.2
		f.light.Brightness = f.base * (0.86 + 0.14 * n)
	end
end

-- A fire on a part (a brazier, a candle): flames rising, embers.
function HolidayKit.fire(at: BasePart, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Name = "HolidayFire"
	e.Texture = "rbxasset://textures/particles/fire_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 90, 30))
	e.LightEmission = 0.9
	e.Rate = Quality.count(22, 8)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(2, 4)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(0, 3, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.15) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	e.Parent = at
end

-- Smoke from a chimney.
function HolidayKit.smoke(at: BasePart)
	local e = Instance.new("ParticleEmitter")
	e.Name = "HolidaySmoke"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(200, 200, 210), Color3.fromRGB(120, 120, 130))
	e.LightEmission = 0
	e.Rate = Quality.count(4, 2)
	e.Lifetime = NumberRange.new(5, 8)
	e.Speed = NumberRange.new(3, 5)
	e.SpreadAngle = Vector2.new(10, 10)
	e.Acceleration = Vector3.new(1.2, 0.6, 0)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Parent = at
end

-- A soft glint now and then on something small that's hidden (an egg, a gift in the snow).
function HolidayKit.glint(at: BasePart, colour: Color3, rate: number?)
	local e = Instance.new("ParticleEmitter")
	e.Name = "Glint"
	e.Texture = SPARK
	e.Color = ColorSequence.new(colour:Lerp(WHITE, 0.6), colour)
	e.LightEmission = 1
	e.Rate = rate or 0.6
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.6), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = at
end

-- The beat (World/HolidayPlay calls it every frame).
function HolidayKit.step(dt: number, t: number)
	if #flights > 0 then
		stepFlights(dt)
	end
	if #words > 0 then
		stepWords(dt)
	end
	if #flames > 0 then
		stepFlames(dt, t)
	end
end

-- For tests: what's in the air.
function HolidayKit.inFlight(): number
	return #flights
end

return HolidayKit

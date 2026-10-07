--!strict
-- The house's fireworks: a real show over the whole estate, the Fourth of July and New Year's Eve
-- at once. Shells go up from launch sites all around the grounds, trailing sparks, and burst high
-- over the roofs (seen from the street, the Terrace, the Suite and every window): peonies,
-- chrysanthemums, hanging gold willows, rings, palms, crackling crossettes, multi-break shells and
-- white strobing salutes, in red, white and blue, gold, and New Year's neon. Each show builds:
-- an opening, the body of the show, then a finale barrage and a sky full of gold willows to close.
-- Drawn on this screen only (the server says when: Salutes, Suite spectacles); every number that
-- shapes it lives in Config.Fireworks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(script.Parent.Parent.Sound)

local Fireworks = {}

export type Options = {
	scale: number?, -- 1: a show; more: bigger shells, more of them (the Grand Salute, the Finale)
	finale: boolean?, -- end on the barrage and the willows (default true)
}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- Colours a shell can burst in, each with its white-hot first instant built in.
local PALETTES: { { Color3 } } = {
	{ Color3.fromRGB(255, 60, 70) }, -- red
	{ Color3.fromRGB(245, 245, 255) }, -- white
	{ Color3.fromRGB(70, 120, 255) }, -- blue
	{ Color3.fromRGB(255, 205, 110) }, -- gold
	{ Color3.fromRGB(200, 210, 230) }, -- silver
	{ Color3.fromRGB(255, 70, 200) }, -- magenta
	{ Color3.fromRGB(90, 255, 140) }, -- green
	{ Color3.fromRGB(170, 90, 255) }, -- violet
	{ Color3.fromRGB(80, 230, 255) }, -- cyan
	{ Color3.fromRGB(255, 60, 70), Color3.fromRGB(245, 245, 255), Color3.fromRGB(70, 120, 255) }, -- the flag
	{ Color3.fromRGB(255, 205, 110), Color3.fromRGB(245, 245, 255) }, -- champagne
	{ Color3.fromRGB(255, 70, 200), Color3.fromRGB(80, 230, 255) }, -- midnight neon
}
local GOLD = { Color3.fromRGB(255, 196, 90), Color3.fromRGB(255, 160, 60) }

local live = 0 -- shells in the sky now (Config.Fireworks.maxLive caps it, for slower machines)
local bounds: { min: Vector3, max: Vector3 }? = nil

local function cfg(): { [string]: any }
	return (Config.data :: any).Fireworks
end

local function folder(): Instance
	local holder = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local f = holder:FindFirstChild("Fireworks")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Fireworks"
		f.Parent = holder
	end
	return f :: Instance
end

-- The grounds the show covers: the house's own footprint (measured once), with a margin.
local function grounds(): { min: Vector3, max: Vector3 }
	if bounds then
		return bounds
	end
	local lo = Vector3.new(-80, 0, -40)
	local hi = Vector3.new(120, 40, 185)
	local maison = Workspace:FindFirstChild("Maison")
	if maison then
		local x0, z0, x1, z1, y1 = math.huge, math.huge, -math.huge, -math.huge, -math.huge
		for _, d in maison:GetDescendants() do
			if d:IsA("BasePart") then
				local p = d.Position
				-- (The street's far ends and stray props don't stretch the sky.)
				if math.abs(p.X) < 400 and math.abs(p.Z) < 400 then
					x0, z0 = math.min(x0, p.X), math.min(z0, p.Z)
					x1, z1 = math.max(x1, p.X), math.max(z1, p.Z)
					y1 = math.max(y1, p.Y)
				end
			end
		end
		if x0 < x1 and z0 < z1 then
			lo = Vector3.new(x0, 0, z0)
			hi = Vector3.new(x1, math.max(20, y1), z1)
		end
	end
	local margin = cfg().margin
	local b = { min = lo - Vector3.new(margin, 0, margin), max = hi + Vector3.new(margin, 0, margin) }
	bounds = b
	return b
end

local function anchor(at: Vector3): Part
	local p = Instance.new("Part")
	p.Name = "Shell"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = Vector3.new(1, 1, 1)
	p.Position = at
	p.Parent = folder()
	return p
end

local function sequence(colours: { Color3 }): ColorSequence
	-- White-hot as it bursts, then the shell's colours.
	local points = { ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 252, 240)) }
	for i, c in colours do
		table.insert(points, ColorSequenceKeypoint.new(math.min(0.12 + (i - 1) / math.max(1, #colours) * 0.88, 1), c))
	end
	if #colours == 1 then
		table.insert(points, ColorSequenceKeypoint.new(1, colours[1]))
	elseif points[#points].Time < 1 then
		table.insert(points, ColorSequenceKeypoint.new(1, colours[#colours]))
	end
	local ok, seq = pcall(function()
		return ColorSequence.new(points)
	end)
	return if ok then seq else ColorSequence.new(colours[1])
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.Rate = 0
	e.LightEmission = 1
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.LockedToPart = false
	for k, v in props do
		pcall(function()
			(e :: any)[k] = v
		end)
	end
	e.Parent = parent
	return e
end

local function flash(at: Part, colour: Color3, brightness: number)
	local l = Instance.new("PointLight")
	l.Range = 60
	l.Brightness = brightness
	l.Color = colour
	l.Shadows = false
	l.Parent = at
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
end

-- A boom, a little after the light (sound is slower than light), quieter the further off.
local function boom(at: Vector3, loud: number)
	local camera = Workspace.CurrentCamera
	local distance = if camera then (camera.CFrame.Position - at).Magnitude else 150
	local volume = loud * math.clamp(1 - distance / 700, 0.25, 1)
	task.delay(math.min(distance / 1100, 0.5), function()
		pcall(Sound.play, "fireworkBoom", volume, 0.85 + math.random() * 0.3)
	end)
end

local function later(seconds: number, fn: () -> ())
	task.delay(seconds, function()
		pcall(fn)
	end)
end

local function done(p: Instance, after: number)
	task.delay(after, function()
		p:Destroy()
		live -= 1
	end)
end

-- The shells. Each takes where it bursts, its colours, and the show's scale.
type Burst = (at: Vector3, colours: { Color3 }, scale: number) -> ()

local function peony(at: Vector3, colours: { Color3 }, scale: number)
	local p = anchor(at)
	local e = emitter(p, {
		Speed = NumberRange.new(62 * scale, 70 * scale),
		Drag = 2.4,
		Lifetime = NumberRange.new(2.2, 2.8),
		Acceleration = Vector3.new(0, -7, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.6 * scale), NumberSequenceKeypoint.new(0.6, 1.8 * scale), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Color = sequence(colours),
	})
	e:Emit(math.floor(260 * scale))
	flash(p, colours[1], 7)
	boom(at, 0.9)
	done(p, 3.2)
end

-- A peony whose stars leave trails of gold behind them.
local function chrysanthemum(at: Vector3, colours: { Color3 }, scale: number)
	peony(at, colours, scale)
	live += 1
	local p = anchor(at)
	local e = emitter(p, {
		Speed = NumberRange.new(10 * scale, 66 * scale),
		Drag = 2.2,
		Lifetime = NumberRange.new(1.4, 2.4),
		Acceleration = Vector3.new(0, -9, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 * scale), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Color = sequence(GOLD),
	})
	e:Emit(math.floor(420 * scale))
	done(p, 2.8)
end

-- The gold willow: slow, heavy stars that hang and fall like branches.
local function willow(at: Vector3, _colours: { Color3 }, scale: number)
	local p = anchor(at)
	local e = emitter(p, {
		Speed = NumberRange.new(50 * scale, 58 * scale),
		Drag = 1.5,
		Lifetime = NumberRange.new(4.5, 6),
		Acceleration = Vector3.new(0, -13, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2 * scale), NumberSequenceKeypoint.new(0.5, 1.5 * scale), NumberSequenceKeypoint.new(1, 0.3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		Color = sequence(GOLD),
	})
	e:Emit(math.floor(300 * scale))
	-- Glitter falling with it.
	local g = emitter(p, {
		Speed = NumberRange.new(20 * scale, 55 * scale),
		Drag = 1.6,
		Lifetime = NumberRange.new(3, 5),
		Acceleration = Vector3.new(0, -11, 0),
		Size = NumberSequence.new(0.5 * scale, 0),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.1, 0.9), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.3, 0.9), NumberSequenceKeypoint.new(0.4, 0), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 200)),
	})
	g:Emit(math.floor(250 * scale))
	flash(p, GOLD[1], 8)
	boom(at, 1)
	done(p, 6.5)
end

-- A ring of stars, tilted toward the sky at a random angle.
local function ring(at: Vector3, colours: { Color3 }, scale: number)
	local p = anchor(at)
	p.CFrame = CFrame.new(at) * CFrame.Angles(math.rad(math.random(50, 90)), math.rad(math.random(0, 360)), 0)
	local e = emitter(p, {
		Shape = Enum.ParticleEmitterShape.Disc,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
		ShapePartial = 1,
		SpreadAngle = Vector2.new(2, 2),
		Speed = NumberRange.new(66 * scale, 68 * scale),
		Drag = 2.4,
		Lifetime = NumberRange.new(2.2, 2.6),
		Acceleration = Vector3.new(0, -5, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4 * scale), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
		Color = sequence(colours),
	})
	e:Emit(math.floor(160 * scale))
	-- A small heart of another colour in the middle.
	local core = emitter(p, {
		Speed = NumberRange.new(14 * scale, 18 * scale),
		Drag = 2.5,
		Lifetime = NumberRange.new(1.6, 2),
		Size = NumberSequence.new(1.6 * scale, 0),
		Color = sequence({ colours[#colours] == colours[1] and Color3.fromRGB(245, 245, 255) or colours[#colours] }),
	})
	core:Emit(math.floor(60 * scale))
	flash(p, colours[1], 6)
	boom(at, 0.85)
	done(p, 3)
end

-- A palm: a dozen heavy gold comets thrown out and curling down.
local function palm(at: Vector3, colours: { Color3 }, scale: number)
	local p = anchor(at)
	local e = emitter(p, {
		Speed = NumberRange.new(70 * scale, 80 * scale),
		Drag = 1.1,
		Lifetime = NumberRange.new(2.8, 3.4),
		Acceleration = Vector3.new(0, -16, 0),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5 * scale), NumberSequenceKeypoint.new(1, 0.6) }),
		Color = sequence(GOLD),
	})
	e:Emit(14)
	-- Each comet sheds sparks as it goes: a second cloud, thinner, in the shell's colour.
	local trail = emitter(p, {
		Speed = NumberRange.new(20 * scale, 78 * scale),
		Drag = 1.4,
		Lifetime = NumberRange.new(1.5, 2.6),
		Acceleration = Vector3.new(0, -14, 0),
		Size = NumberSequence.new(0.8 * scale, 0),
		Color = sequence(colours),
	})
	trail:Emit(math.floor(220 * scale))
	flash(p, GOLD[1], 7)
	boom(at, 1)
	done(p, 3.8)
end

-- A crossette: a burst, then every star breaks again into crackling white glitter.
local function crackle(at: Vector3, colours: { Color3 }, scale: number)
	local p = anchor(at)
	local e = emitter(p, {
		Speed = NumberRange.new(48 * scale, 56 * scale),
		Drag = 2.6,
		Lifetime = NumberRange.new(1.2, 1.5),
		Size = NumberSequence.new(2 * scale, 0.8),
		Color = sequence(colours),
	})
	e:Emit(math.floor(120 * scale))
	flash(p, colours[1], 6)
	boom(at, 0.8)
	later(1.0, function()
		local c = emitter(p, {
			Speed = NumberRange.new(5 * scale, 48 * scale),
			Drag = 1.8,
			Lifetime = NumberRange.new(0.5, 1.1),
			Acceleration = Vector3.new(0, -10, 0),
			Size = NumberSequence.new(0.9 * scale, 0.3),
			-- A flicker: on, off, on, off.
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.15, 1), NumberSequenceKeypoint.new(0.3, 0), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.6, 0), NumberSequenceKeypoint.new(0.8, 1), NumberSequenceKeypoint.new(1, 1) }),
			Color = ColorSequence.new(Color3.fromRGB(255, 250, 235)),
		})
		c:Emit(math.floor(420 * scale))
		pcall(Sound.play, "fireworkCrackle", 0.7, 0.9 + math.random() * 0.2)
	end)
	done(p, 3)
end

-- A strobing white salute: a blinding flash and the loudest bang of the show.
local function salute(at: Vector3, _colours: { Color3 }, scale: number)
	local p = anchor(at)
	local e = emitter(p, {
		Speed = NumberRange.new(0, 4),
		Lifetime = NumberRange.new(0.12, 0.18),
		Size = NumberSequence.new(34 * scale, 10 * scale),
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
	})
	e:Emit(3)
	local strobe = emitter(p, {
		Speed = NumberRange.new(20 * scale, 60 * scale),
		Drag = 2,
		Lifetime = NumberRange.new(0.6, 1.4),
		Size = NumberSequence.new(1.4 * scale, 0.4),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 1), NumberSequenceKeypoint.new(0.35, 0), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(0.7, 0), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255)),
	})
	strobe:Emit(math.floor(160 * scale))
	flash(p, Color3.fromRGB(255, 255, 255), 14)
	boom(at, 1.3)
	done(p, 2)
end

-- A multi-break: one shell that bursts three times, a beat apart, in three colours.
local function multiBreak(at: Vector3, colours: { Color3 }, scale: number)
	local choices = { PALETTES[1], PALETTES[2], PALETTES[3] }
	if math.random() < 0.5 then
		choices = { colours, PALETTES[4], PALETTES[12] }
	end
	for i = 1, 3 do
		later((i - 1) * 0.35, function()
			live += 1
			local offset = Vector3.new(math.random(-18, 18), (i - 2) * 10, math.random(-18, 18)) * scale
			peony(at + offset, choices[i], scale * 0.6)
		end)
	end
	live -= 1 -- (the three count themselves)
end

local KINDS: { [string]: Burst } = {
	peony = peony,
	chrysanthemum = chrysanthemum,
	willow = willow,
	ring = ring,
	palm = palm,
	crackle = crackle,
	salute = salute,
	multiBreak = multiBreak,
}
local MIX = { "peony", "peony", "chrysanthemum", "chrysanthemum", "willow", "ring", "ring", "palm", "crackle", "crackle", "multiBreak", "salute" }

local function randomIn(lo: number, hi: number): number
	return lo + math.random() * (hi - lo)
end

-- Where a shell goes up from, and where it bursts: anywhere around the grounds.
local function sites(): (Vector3, Vector3)
	local g = grounds()
	local c = cfg()
	local x = randomIn(g.min.X, g.max.X)
	local z = randomIn(g.min.Z, g.max.Z)
	local from = Vector3.new(x, 0, z)
	local top = Vector3.new(x + randomIn(-12, 12), g.max.Y + randomIn(c.heightMin, c.heightMax), z + randomIn(-12, 12))
	return from, top
end

-- One shell: up from the ground on a trail of sparks, then the burst.
local function launch(kind: string, scale: number, colours: { Color3 }?, at: { from: Vector3, top: Vector3 }?)
	if live >= cfg().maxLive then
		return
	end
	live += 1
	local from, top
	if at then
		from, top = at.from, at.top
	else
		from, top = sites()
	end
	local paint = colours or PALETTES[math.random(1, #PALETTES)]
	local rocket = anchor(from)
	rocket.Name = "Rocket"
	emitter(rocket, {
		Rate = 90,
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(12, 12),
		EmissionDirection = Enum.NormalId.Bottom,
		Lifetime = NumberRange.new(0.4, 0.8),
		Acceleration = Vector3.new(0, -12, 0),
		Size = NumberSequence.new(1.1 * scale, 0),
		Color = sequence(GOLD),
	})
	local rise = randomIn(1.1, 1.6)
	local tween = TweenService:Create(rocket, TweenInfo.new(rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = top })
	tween:Play()
	task.delay(rise, function()
		rocket:Destroy()
		local burst = KINDS[kind] or peony
		local ok = pcall(burst, top, paint, scale)
		if not ok then
			live -= 1
		end
	end)
end

-- Plays a show of `seconds` over the whole estate.
function Fireworks.show(seconds: number, options: Options?)
	local o: Options = options or {}
	local scale = o.scale or 1
	local finale = o.finale ~= false
	local c = cfg()
	task.spawn(function()
		local t0 = os.clock()
		local finaleAt = if finale then seconds * (1 - c.finaleShare) else math.huge
		pcall(Sound.play, "fireworkBarrage", 0.35)
		-- The opening and the body of the show.
		while os.clock() - t0 < math.min(seconds, finaleAt) do
			local k = (os.clock() - t0) / math.max(1, finaleAt)
			local rate = c.rate * scale * (0.6 + 0.6 * k)
			if math.random() < 0.22 then
				-- A volley: a fan of the same shell, side by side, in one colour.
				local kind = MIX[math.random(1, #MIX)]
				local paint = PALETTES[math.random(1, #PALETTES)]
				local from, top = sites()
				local n = math.random(3, 5)
				for i = 1, n do
					local side = (i - (n + 1) / 2) * 28
					launch(kind, scale, paint, { from = from + Vector3.new(side, 0, 0), top = top + Vector3.new(side * 1.6, math.abs(side) * -0.2, 0) })
					task.wait(0.12)
				end
			else
				launch(MIX[math.random(1, #MIX)], scale)
			end
			task.wait(randomIn(0.6, 1.4) / math.max(0.2, rate))
		end
		if not finale then
			return
		end
		-- The finale: the sky full, everything at once, crackling.
		pcall(Sound.play, "fireworkBarrage", 0.9)
		local finaleEnd = t0 + seconds - 4
		while os.clock() < finaleEnd do
			for _ = 1, math.random(2, 4) do
				launch(MIX[math.random(1, #MIX)], scale)
			end
			if math.random() < 0.3 then
				launch("salute", scale)
			end
			task.wait(randomIn(0.6, 1.2) / (c.finaleRate * scale))
		end
		-- To close: a row of great gold willows hanging over the whole house.
		local g = grounds()
		local n = c.closingWillows
		for i = 1, n do
			local x = g.min.X + (g.max.X - g.min.X) * (i - 0.5) / n
			local z = (g.min.Z + g.max.Z) / 2 + randomIn(-30, 30)
			local top = Vector3.new(x, g.max.Y + c.heightMax, z)
			launch("willow", scale * 1.35, GOLD, { from = Vector3.new(x, 0, z), top = top })
			task.wait(0.08)
		end
	end)
end

-- Clears the sky at once.
function Fireworks.stop()
	local f = (Workspace:FindFirstChild("MaisonLocal") or Workspace):FindFirstChild("Fireworks")
	if f then
		f:ClearAllChildren()
	end
	live = 0
end

-- (For the client's checks: how many shells are in the sky.)
function Fireworks.live(): number
	return live
end

return Fireworks

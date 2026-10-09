--!strict
-- The owner's effects and Admin Abuse, drawn flat on a screen: over the sorting table (so a guest
-- sorting never misses the party) and, lighter, over the house as you walk (so it shows indoors,
-- where the sky can't be seen). Every effect switched on has its own: meteors streaking across,
-- a black hole turning in a corner, an aurora rippling along the top, a starry sky and a ringed
-- planet, a flying saucer with its beam, a blizzard, an earthquake shaking the desk, a rainbow
-- round the edges, bubbles, a wave of gold coins, embers and frost, the lights going out with a
-- spotlight sweeping, a whirlwind of leaves, fireworks, a titan meme rising behind the desk,
-- floating feathers, disco lights, lightning, falling memes, confetti, a shockwave, a spiral,
-- rockets. During Admin Abuse: gold sparks and a glowing edge; Mega Abuse: a rainbow one.
--
-- Over the table, a ribbon says what's on and what it brings ("ADMIN ABUSE · ×2 GILT · GOLDEN
-- PIECES"). Nothing here is ever clickable or covers a piece for long; it changes nothing kept
-- (the server decides golden pieces and Gilt).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Curios = require(ReplicatedStorage.Shared.Curios)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ScreenFX = {}

local rgb = Color3.fromRGB
local HEAVY = Font.fromEnum(Enum.Font.GothamBlack)
local GOLD = rgb(255, 204, 90)
local RAINBOW = { rgb(255, 70, 120), rgb(255, 170, 60), rgb(255, 236, 90), rgb(90, 240, 140), rgb(80, 170, 255), rgb(190, 100, 255) }
local CONFETTI = { rgb(255, 60, 140), rgb(80, 140, 255), rgb(90, 255, 170), rgb(255, 214, 80), rgb(255, 240, 200), rgb(190, 90, 255) }

export type Mode = "table" | "walk"

-- What a theme gets: where to draw (behind the table's pieces, or in front), how big the screen
-- is, how busy to be, and a random source.
export type Ctx = {
	back: Frame,
	front: Frame,
	size: () -> Vector2,
	density: number,
	rng: Random,
	mode: Mode,
	shake: (px: number) -> (),
}
type Theme = { step: (dt: number, t: number) -> (), stop: () -> () }

---------------------------------------------------------------------------------------------------
-- Little drawing helpers
---------------------------------------------------------------------------------------------------
local function frame(parent: Instance, colour: Color3, alpha: number, round: boolean?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = alpha
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Parent = parent
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
	end
	return f
end

local function glyph(parent: Instance, text: string, px: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(px, px)
	l.TextScaled = true
	l.Text = text
	l.Parent = parent
	return l
end

local function gradient(parent: Instance, colours: ColorSequence?, alphas: NumberSequence?, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	if colours then
		g.Color = colours
	end
	if alphas then
		g.Transparency = alphas
	end
	g.Rotation = rotation or 0
	g.Parent = parent
	return g
end

-- A fade from one transparency to another (written as keypoints: plain and certain).
local function fade(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

local function ring(parent: Instance, colour: Color3, thickness: number): Frame
	local f = frame(parent, colour, 1, true)
	local s = Instance.new("UIStroke")
	s.Color = colour
	s.Thickness = thickness
	s.Parent = f
	return f
end

local function at(f: GuiObject, x: number, y: number, w: number, h: number)
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
end

local function memeGlyphs(): { string }
	local out = {}
	for _, c in Curios.List do
		if c.family == "meme" then
			table.insert(out, c.glyph)
		end
	end
	return if #out > 0 then out else { "🗿", "🤡", "💀" }
end

-- Particles: frames that move, spin and fade, recycled when they leave the screen.
type Particle = { f: GuiObject, x: number, y: number, vx: number, vy: number, spin: number, age: number, life: number, alpha: number, w: number, h: number }

local function particles(): ({ Particle }, (Particle) -> (), (number, (Particle) -> boolean) -> ())
	local list: { Particle } = {}
	local function add(p: Particle)
		table.insert(list, p)
	end
	-- Moves them all; `keep` says whether one stays (else it's destroyed).
	local function move(dt: number, keep: (Particle) -> boolean)
		for i = #list, 1, -1 do
			local p = list[i]
			p.age += dt
			p.x += p.vx * dt
			p.y += p.vy * dt
			p.f.Position = UDim2.fromOffset(p.x, p.y)
			if p.spin ~= 0 then
				p.f.Rotation += p.spin * dt
			end
			if p.life > 0 then
				local k = math.clamp(p.age / p.life, 0, 1)
				local a = p.alpha + (1 - p.alpha) * k * k
				if p.f:IsA("TextLabel") then
					(p.f :: TextLabel).TextTransparency = a
				else
					p.f.BackgroundTransparency = a
				end
			end
			if not keep(p) or (p.life > 0 and p.age >= p.life) then
				p.f:Destroy()
				table.remove(list, i)
			end
		end
	end
	return list, add, move
end

local function clearAll(list: { Particle })
	for _, p in list do
		p.f:Destroy()
	end
	table.clear(list)
end

---------------------------------------------------------------------------------------------------
-- The themes
---------------------------------------------------------------------------------------------------
local THEMES: { [string]: (Ctx) -> Theme } = {}

-- Falling things (snow, confetti, memes, coins, petals): from above, drifting, spinning.
local function fall(ctx: Ctx, layer: Frame, rate: number, make: (Particle) -> GuiObject, speed: NumberRange, drift: number, spin: number): Theme
	local list, add, move = particles()
	local acc = 1 -- (the first one at once)
	return {
		step = function(dt: number, _t: number)
			local size = ctx.size()
			acc += dt * rate * ctx.density
			while acc >= 1 do
				acc -= 1
				local p: Particle = { f = nil :: any, x = ctx.rng:NextNumber(-0.05, 1.05) * size.X, y = -30, vx = ctx.rng:NextNumber(-drift, drift), vy = ctx.rng:NextNumber(speed.Min, speed.Max) * size.Y, spin = ctx.rng:NextNumber(-spin, spin), age = 0, life = 0, alpha = 0, w = 0, h = 0 }
				p.f = make(p)
				p.f.Parent = layer
				add(p)
			end
			move(dt, function(p)
				return p.y < size.Y + 40
			end)
		end,
		stop = function()
			clearAll(list)
		end,
	}
end

THEMES.blizzard = function(ctx)
	local haze = frame(ctx.front, Color3.new(1, 1, 1), 1)
	haze.AnchorPoint = Vector2.zero
	haze.Size = UDim2.fromScale(1, 1)
	gradient(haze, nil, NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.18, 0.93), NumberSequenceKeypoint.new(0.82, 0.93), NumberSequenceKeypoint.new(1, 0.55) }), 0)
	haze.BackgroundTransparency = 0
	local list, add, move = particles()
	local acc = 1 -- (the first one at once)
	return {
		step = function(dt)
			local size = ctx.size()
			acc += dt * 90 * ctx.density
			while acc >= 1 do
				acc -= 1
				local px = ctx.rng:NextNumber(2, 6)
				local p: Particle = { f = frame(ctx.front, Color3.new(1, 1, 1), ctx.rng:NextNumber(0.05, 0.4), true), x = ctx.rng:NextNumber(-0.3, 1) * size.X, y = -10, vx = ctx.rng:NextNumber(0.25, 0.45) * size.X, vy = ctx.rng:NextNumber(0.35, 0.6) * size.Y, spin = 0, age = 0, life = 0, alpha = 0, w = px, h = px }
				p.f.Size = UDim2.fromOffset(px, px)
				add(p)
			end
			move(dt, function(p)
				return p.y < size.Y + 20 and p.x < size.X + 20
			end)
		end,
		stop = function()
			clearAll(list)
			haze:Destroy()
		end,
	}
end

THEMES.confetti = function(ctx)
	return fall(ctx, ctx.front, 26, function(p)
		local f = frame(ctx.front, CONFETTI[ctx.rng:NextInteger(1, #CONFETTI)], 0.05)
		f.Size = UDim2.fromOffset(ctx.rng:NextNumber(6, 11), ctx.rng:NextNumber(3, 5))
		p.vx = ctx.rng:NextNumber(-40, 40)
		return f
	end, NumberRange.new(0.18, 0.32), 40, 360)
end

THEMES.memeRain = function(ctx)
	local glyphs = memeGlyphs()
	return fall(ctx, ctx.front, 5, function(_p)
		local l = glyph(ctx.front, glyphs[ctx.rng:NextInteger(1, #glyphs)], ctx.rng:NextNumber(26, 46))
		return l
	end, NumberRange.new(0.16, 0.3), 30, 160)
end

THEMES.goldWave = function(ctx)
	local sheen = frame(ctx.front, rgb(255, 210, 90), 0)
	sheen.AnchorPoint = Vector2.zero
	sheen.Size = UDim2.fromScale(0.35, 1)
	gradient(sheen, nil, NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.8), NumberSequenceKeypoint.new(1, 1) }), 0)
	local coins = fall(ctx, ctx.front, 14, function(_p)
		return glyph(ctx.front, "🪙", ctx.rng:NextNumber(20, 34))
	end, NumberRange.new(0.25, 0.42), 60, 300)
	return {
		step = function(dt, t)
			coins.step(dt, t)
			sheen.Position = UDim2.fromScale(((t * 0.45) % 1.7) - 0.5, 0)
		end,
		stop = function()
			coins.stop()
			sheen:Destroy()
		end,
	}
end

THEMES.bubbles = function(ctx)
	local list, add, move = particles()
	local acc = 1 -- (the first one at once)
	return {
		step = function(dt, t)
			local size = ctx.size()
			acc += dt * 6 * ctx.density
			while acc >= 1 do
				acc -= 1
				local px = ctx.rng:NextNumber(14, 44)
				local b = ring(ctx.front, rgb(190, 235, 255), 1.5)
				b.BackgroundTransparency = 0.88
				b.BackgroundColor3 = rgb(200, 240, 255)
				b.Size = UDim2.fromOffset(px, px)
				local shine = frame(b, Color3.new(1, 1, 1), 0.35, true)
				shine.Size = UDim2.fromScale(0.22, 0.22)
				shine.Position = UDim2.fromScale(0.32, 0.3)
				add({ f = b, x = ctx.rng:NextNumber(0.02, 0.98) * size.X, y = size.Y + 30, vx = 0, vy = -ctx.rng:NextNumber(0.08, 0.16) * size.Y, spin = 0, age = 0, life = 0, alpha = 0.88, w = px, h = px })
			end
			for _, p in list do
				p.x += math.sin(t * 2 + p.w) * 18 * dt
			end
			move(dt, function(p)
				return p.y > -40
			end)
		end,
		stop = function()
			clearAll(list)
		end,
	}
end

THEMES.meteor = function(ctx)
	local list: { { head: Frame, tail: Frame, x: number, y: number, vx: number, vy: number, hitY: number } } = {}
	local rings: { { f: Frame, age: number } } = {}
	local acc = 1 -- (the first one at once)
	-- The sky burns: a warm glow along the top while the shower lasts.
	local sky = frame(ctx.back, rgb(255, 110, 40), 0)
	sky.AnchorPoint = Vector2.zero
	sky.Size = UDim2.fromScale(1, 0.35)
	gradient(sky, ColorSequence.new(rgb(255, 150, 60), rgb(160, 40, 20)), NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }), 90)
	local function stopAll()
		for _, m in list do
			m.head:Destroy()
			m.tail:Destroy()
		end
		table.clear(list)
		for _, r in rings do
			r.f:Destroy()
		end
		table.clear(rings)
		sky:Destroy()
	end
	return {
		step = function(dt, t)
			local size = ctx.size()
			sky.BackgroundTransparency = 0.05 * math.sin(t * 3)
			acc += dt * 1.8 * ctx.density
			while acc >= 1 do
				acc -= 1
				local tail = frame(ctx.back, rgb(255, 170, 70), 0)
				tail.Size = UDim2.fromOffset(150, 5)
				gradient(tail, ColorSequence.new(rgb(255, 90, 30), rgb(255, 240, 180)), NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) }), 0)
				local head = frame(ctx.back, rgb(255, 236, 190), 0, true)
				head.Size = UDim2.fromOffset(14, 14)
				local glow = Instance.new("UIStroke")
				glow.Color = rgb(255, 150, 60)
				glow.Thickness = 4
				glow.Transparency = 0.3
				glow.Parent = head
				local speed = ctx.rng:NextNumber(0.7, 1.1) * size.Y
				table.insert(list, { head = head, tail = tail, x = ctx.rng:NextNumber(0.3, 1.2) * size.X, y = -20, vx = -speed * 0.75, vy = speed, hitY = ctx.rng:NextNumber(0.45, 0.95) * size.Y })
			end
			for i = #list, 1, -1 do
				local m = list[i]
				m.x += m.vx * dt
				m.y += m.vy * dt
				local angle = math.deg(math.atan2(m.vy, m.vx))
				m.head.Position = UDim2.fromOffset(m.x, m.y)
				m.tail.Rotation = angle
				m.tail.Position = UDim2.fromOffset(m.x - math.cos(math.rad(angle)) * 75, m.y - math.sin(math.rad(angle)) * 75)
				if m.y >= m.hitY then
					-- The impact: a ring of fire, a jolt.
					local r = ring(ctx.back, rgb(255, 160, 70), 3)
					r.Position = UDim2.fromOffset(m.x, m.y)
					r.Size = UDim2.fromOffset(10, 10)
					table.insert(rings, { f = r, age = 0 })
					ctx.shake(3)
					m.head:Destroy()
					m.tail:Destroy()
					table.remove(list, i)
				end
			end
			for i = #rings, 1, -1 do
				local r = rings[i]
				r.age += dt
				local k = r.age / 0.6
				r.f.Size = UDim2.fromOffset(10 + 120 * k, (10 + 120 * k) * 0.45)
				local stroke = r.f:FindFirstChildOfClass("UIStroke")
				if stroke then
					stroke.Transparency = k
				end
				if k >= 1 then
					r.f:Destroy()
					table.remove(rings, i)
				end
			end
		end,
		stop = stopAll,
	}
end

THEMES.blackHole = function(ctx)
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Parent = ctx.back
	local disks: { Frame } = {}
	for i, colour in { rgb(255, 150, 60), rgb(200, 110, 255), rgb(255, 210, 120) } do
		local d = ring(holder, colour, 3 + i)
		d.Size = UDim2.fromScale(0.7 + i * 0.28, (0.7 + i * 0.28) * 0.36)
		d.Position = UDim2.fromScale(0.5, 0.5)
		table.insert(disks, d)
	end
	local core = frame(holder, Color3.new(0, 0, 0), 0, true)
	core.Size = UDim2.fromScale(0.62, 0.62)
	core.Position = UDim2.fromScale(0.5, 0.5)
	local edge = Instance.new("UIStroke")
	edge.Color = rgb(255, 190, 120)
	edge.Thickness = 2
	edge.Parent = core
	local list, add, move = particles()
	local acc = 1 -- (the first one at once)
	return {
		step = function(dt, t)
			local size = ctx.size()
			local d = math.min(size.X, size.Y) * (if ctx.mode == "table" then 0.32 else 0.22)
			-- (At a table: over the cloth, clear of the figures; walking: clear of the keys.)
			local cx, cy = size.X * (if ctx.mode == "table" then 0.82 else 0.8), size.Y * (if ctx.mode == "table" then 0.5 else 0.36)
			holder.Position = UDim2.fromOffset(cx, cy)
			holder.Size = UDim2.fromOffset(d, d)
			for i, disk in disks do
				disk.Rotation = (t * (18 + i * 9) * (if i % 2 == 0 then -1 else 1)) % 360
			end
			-- Motes pulled in from round the screen.
			acc += dt * 14 * ctx.density
			while acc >= 1 do
				acc -= 1
				local a = ctx.rng:NextNumber(0, math.pi * 2)
				local r = d * ctx.rng:NextNumber(1.2, 2.4)
				local f = frame(ctx.back, RAINBOW[ctx.rng:NextInteger(1, #RAINBOW)], 0.2, true)
				f.Size = UDim2.fromOffset(4, 4)
				add({ f = f, x = cx + math.cos(a) * r, y = cy + math.sin(a) * r, vx = 0, vy = 0, spin = 0, age = 0, life = 3, alpha = 0.2, w = a, h = r })
			end
			for _, p in list do
				p.h = math.max(0, p.h - dt * d * 0.8)
				p.w += dt * 2.6
				p.vx, p.vy = 0, 0
				p.x = cx + math.cos(p.w) * p.h
				p.y = cy + math.sin(p.w) * p.h * 0.6
			end
			move(dt, function(p)
				return p.h > d * 0.3
			end)
		end,
		stop = function()
			clearAll(list)
			holder:Destroy()
		end,
	}
end

THEMES.aurora = function(ctx)
	local bands: { Frame } = {}
	local colours = {
		ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(80, 255, 170)), ColorSequenceKeypoint.new(0.5, rgb(120, 200, 255)), ColorSequenceKeypoint.new(1, rgb(80, 255, 170)) }),
		ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(190, 110, 255)), ColorSequenceKeypoint.new(0.5, rgb(120, 255, 140)), ColorSequenceKeypoint.new(1, rgb(190, 110, 255)) }),
		ColorSequence.new({ ColorSequenceKeypoint.new(0, rgb(90, 220, 255)), ColorSequenceKeypoint.new(0.5, rgb(220, 120, 255)), ColorSequenceKeypoint.new(1, rgb(90, 220, 255)) }),
	}
	for i = 1, 3 do
		local b = frame(ctx.back, Color3.new(1, 1, 1), 0)
		b.AnchorPoint = Vector2.new(0.5, 0)
		gradient(b, colours[i], NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.55), NumberSequenceKeypoint.new(0.65, 0.6), NumberSequenceKeypoint.new(1, 1) }), 90)
		table.insert(bands, b)
	end
	return {
		step = function(_dt, t)
			local size = ctx.size()
			for i, b in bands do
				local w = size.X * 1.6
				b.Size = UDim2.fromOffset(w, size.Y * (0.22 + 0.05 * i))
				b.Position = UDim2.fromOffset(size.X * 0.5 + math.sin(t * 0.35 + i * 2) * size.X * 0.18, size.Y * (0.01 + 0.04 * i) + math.sin(t * 0.8 + i) * 8)
				b.Rotation = math.sin(t * 0.25 + i) * 4
				local g = b:FindFirstChildOfClass("UIGradient")
				if g then
					g.Offset = Vector2.new(0, math.sin(t * 0.6 + i) * 0.08)
				end
			end
		end,
		stop = function()
			for _, b in bands do
				b:Destroy()
			end
		end,
	}
end

THEMES.galaxy = function(ctx)
	local night = frame(ctx.back, rgb(10, 8, 40), 0)
	night.AnchorPoint = Vector2.zero
	night.Size = UDim2.fromScale(1, 1)
	gradient(night, ColorSequence.new(rgb(40, 20, 90), rgb(10, 8, 40)), NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.55, 0.72), NumberSequenceKeypoint.new(1, 0.9) }), 90)
	local stars: { { f: Frame, x: number, y: number, phase: number } } = {}
	for _ = 1, math.floor((if ctx.mode == "table" then 140 else 80) * ctx.density) do
		local px = ctx.rng:NextNumber(1.5, 4)
		local s = frame(ctx.back, Color3.new(1, 1, 1):Lerp(rgb(170, 200, 255), ctx.rng:NextNumber()), 0.1, true)
		s.Size = UDim2.fromOffset(px, px)
		table.insert(stars, { f = s, x = ctx.rng:NextNumber(), y = ctx.rng:NextNumber() * 0.7, phase = ctx.rng:NextNumber(0, 6) })
	end
	local planet = frame(ctx.back, rgb(220, 150, 90), 0, true)
	gradient(planet, ColorSequence.new(rgb(255, 200, 140), rgb(120, 60, 40)), nil, 45)
	local band = ring(ctx.back, rgb(240, 210, 150), 3)
	return {
		step = function(_dt, t)
			local size = ctx.size()
			for _, s in stars do
				s.f.Position = UDim2.fromOffset(s.x * size.X, s.y * size.Y)
				s.f.BackgroundTransparency = 0.1 + 0.6 * (0.5 + 0.5 * math.sin(t * 2.2 + s.phase))
			end
			local d = math.min(size.X, size.Y) * 0.16
			-- (Clear of the header and the Gilt bar: low on the right at a table, high on it walking.)
			local px = size.X * (if ctx.mode == "table" then 0.86 else 0.82)
			local py = size.Y * (if ctx.mode == "table" then 0.58 else 0.34) + math.sin(t * 0.3) * 6
			planet.Size = UDim2.fromOffset(d, d)
			planet.Position = UDim2.fromOffset(px, py)
			band.Size = UDim2.fromOffset(d * 1.9, d * 0.42)
			band.Position = UDim2.fromOffset(px, py)
			band.Rotation = -18
		end,
		stop = function()
			for _, s in stars do
				s.f:Destroy()
			end
			night:Destroy()
			planet:Destroy()
			band:Destroy()
		end,
	}
end

THEMES.ufo = function(ctx)
	local saucer = frame(ctx.back, rgb(170, 180, 195), 0, true)
	gradient(saucer, ColorSequence.new(rgb(230, 235, 245), rgb(110, 115, 130)), nil, 90)
	local dome = frame(saucer, rgb(150, 240, 255), 0.25, true)
	dome.Size = UDim2.fromScale(0.42, 0.9)
	dome.Position = UDim2.fromScale(0.5, -0.05)
	local lights: { Frame } = {}
	for i = 1, 6 do
		local l = frame(saucer, RAINBOW[i], 0, true)
		l.Size = UDim2.fromScale(0.07, 0.22)
		l.Position = UDim2.fromScale(0.12 + (i - 1) * 0.152, 0.62)
		table.insert(lights, l)
	end
	local beam = frame(ctx.back, rgb(140, 255, 160), 0.7)
	beam.AnchorPoint = Vector2.new(0.5, 0)
	gradient(beam, nil, NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }), 90)
	return {
		step = function(_dt, t)
			local size = ctx.size()
			local w = math.min(size.X * 0.2, 220)
			local cycle = (t % 14) / 14
			local x = size.X * (-0.15 + 1.3 * cycle)
			local y = size.Y * (if ctx.mode == "table" then 0.3 else 0.22) + math.sin(t * 2) * 6
			saucer.Size = UDim2.fromOffset(w, w * 0.32)
			saucer.Position = UDim2.fromOffset(x, y)
			saucer.Rotation = math.sin(t * 1.7) * 6
			for i, l in lights do
				l.BackgroundTransparency = if math.floor(t * 6 + i) % 2 == 0 then 0 else 0.6
			end
			-- It stops in the middle and beams down.
			local beaming = cycle > 0.4 and cycle < 0.6
			beam.Visible = beaming
			beam.Size = UDim2.fromOffset(w * 0.7, size.Y * 0.75)
			beam.Position = UDim2.fromOffset(x, y + w * 0.1)
			beam.BackgroundTransparency = 0.62 + math.sin(t * 9) * 0.06
		end,
		stop = function()
			saucer:Destroy()
			beam:Destroy()
		end,
	}
end

THEMES.earthquake = function(ctx)
	local dust = fall(ctx, ctx.front, 10, function(p)
		local f = frame(ctx.front, rgb(170, 150, 120), 0.5, true)
		local px = ctx.rng:NextNumber(10, 30)
		f.Size = UDim2.fromOffset(px, px)
		p.life = 1.6
		p.alpha = 0.5
		p.y = ctx.size().Y - 5 -- (dust rises off the floor)
		return f
	end, NumberRange.new(-0.06, -0.02), 30, 0)
	local next_ = 0
	return {
		step = function(dt, t)
			dust.step(dt, t)
			-- Rumbles: a few seconds of shaking, then a breather.
			if t >= next_ then
				next_ = t + 0.12
				if (t % 6) < 2.5 then
					ctx.shake(5)
				end
			end
		end,
		stop = dust.stop,
	}
end

THEMES.rainbow = function(ctx)
	local edges: { Frame } = {}
	for i = 1, 4 do
		local e = frame(ctx.front, Color3.new(1, 1, 1), 0)
		e.AnchorPoint = Vector2.zero
		gradient(e, nil, fade(0.15, 1), ({ 90, 270, 0, 180 })[i])
		table.insert(edges, e)
	end
	local sparks = fall(ctx, ctx.front, 10, function(p)
		local f = frame(ctx.front, RAINBOW[ctx.rng:NextInteger(1, #RAINBOW)], 0.1, true)
		f.Size = UDim2.fromOffset(6, 6)
		p.life = 2.5
		p.alpha = 0.1
		return f
	end, NumberRange.new(0.05, 0.12), 20, 0)
	return {
		step = function(dt, t)
			sparks.step(dt, t)
			local size = ctx.size()
			local th = math.max(12, math.min(size.X, size.Y) * 0.05)
			at(edges[1], 0, 0, size.X, th)
			at(edges[2], 0, size.Y - th, size.X, th)
			at(edges[3], 0, 0, th, size.Y)
			at(edges[4], size.X - th, 0, th, size.Y)
			for i, e in edges do
				e.BackgroundColor3 = Color3.fromHSV((t * 0.25 + i * 0.25) % 1, 0.75, 1)
			end
		end,
		stop = function()
			sparks.stop()
			for _, e in edges do
				e:Destroy()
			end
		end,
	}
end

THEMES.fireIce = function(ctx)
	local left = frame(ctx.back, rgb(255, 80, 30), 0)
	left.AnchorPoint = Vector2.zero
	gradient(left, nil, fade(0.45, 1), 0)
	local right = frame(ctx.back, rgb(60, 160, 255), 0)
	right.AnchorPoint = Vector2.zero
	gradient(right, nil, fade(1, 0.45), 0)
	local list, add, move = particles()
	local acc = 1 -- (the first one at once)
	return {
		step = function(dt)
			local size = ctx.size()
			at(left, 0, 0, size.X * 0.3, size.Y)
			at(right, size.X * 0.7, 0, size.X * 0.3, size.Y)
			acc += dt * 30 * ctx.density
			while acc >= 1 do
				acc -= 1
				local fire = ctx.rng:NextNumber() < 0.5
				local px = ctx.rng:NextNumber(3, 7)
				local f = frame(ctx.front, if fire then rgb(255, 170, 60) else rgb(220, 240, 255), 0.1, true)
				f.Size = UDim2.fromOffset(px, px)
				local x = if fire then ctx.rng:NextNumber(0, 0.35) else ctx.rng:NextNumber(0.65, 1)
				add({ f = f, x = x * size.X, y = if fire then size.Y + 10 else -10, vx = ctx.rng:NextNumber(-15, 15), vy = (if fire then -1 else 1) * ctx.rng:NextNumber(0.12, 0.25) * size.Y, spin = 0, age = 0, life = 5, alpha = 0.1, w = px, h = px })
			end
			move(dt, function(p)
				return p.y > -20 and p.y < size.Y + 20
			end)
		end,
		stop = function()
			clearAll(list)
			left:Destroy()
			right:Destroy()
		end,
	}
end

-- The lights go out: the screen dims, and a round spotlight with a soft edge sweeps across it (a
-- ring of darkness round a clear circle, its inner edges feathered).
THEMES.blackout = function(ctx)
	local layers: { { f: Frame, inset: number } } = {}
	for i, spec in { { inset = 0, thick = 3000, alpha = 0.42 }, { inset = 18, thick = 18, alpha = 0.7 }, { inset = 34, thick = 16, alpha = 0.85 }, { inset = 48, thick = 14, alpha = 0.93 } } do
		local f = frame(ctx.front, Color3.new(0, 0, 0), 1, true)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = spec.thick
		stroke.Transparency = spec.alpha
		stroke.Parent = f
		f.ZIndex = 10 - i
		table.insert(layers, { f = f, inset = spec.inset })
	end
	return {
		step = function(_dt, t)
			local size = ctx.size()
			local r = math.min(size.X, size.Y) * 0.34
			local cx = size.X * (0.5 + 0.3 * math.sin(t * 0.5))
			local cy = size.Y * (0.52 + 0.16 * math.sin(t * 0.73))
			for _, l in layers do
				-- (The outer ring's stroke grows outward from the circle; the feathering rings lie
				-- just inside it, each fainter.)
				local d = (r - l.inset) * 2
				l.f.Position = UDim2.fromOffset(cx, cy)
				l.f.Size = UDim2.fromOffset(d, d)
			end
		end,
		stop = function()
			for _, l in layers do
				l.f:Destroy()
			end
		end,
	}
end

THEMES.tornado = function(ctx)
	-- The funnel: soft grey bands, narrow at the ground and wide at the top, overlapping so the
	-- middle reads darker, each swaying a little behind the one below; a dust cloud at its foot
	-- and leaves and grit whirling round it.
	local rings: { Frame } = {}
	for i = 1, 20 do
		local r = ring(ctx.back, rgb(205, 205, 215), 1.5)
		local stroke = r:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = 0.55 + i * 0.015
		end
		r.BackgroundColor3 = rgb(150, 150, 162)
		r.BackgroundTransparency = 0.84 + i * 0.004
		table.insert(rings, r)
	end
	local dust = frame(ctx.back, rgb(150, 130, 105), 0, true)
	gradient(dust, nil, fade(0.95, 0.55), 90)
	local list: { { f: GuiObject, a: number, h: number, speed: number } } = {}
	for i = 1, math.floor(30 * ctx.density) do
		local f: GuiObject = if i % 3 == 0 then glyph(ctx.back, "🍃", 26) else frame(ctx.back, if i % 2 == 0 then rgb(130, 105, 80) else rgb(160, 160, 170), 0.1)
		if f:IsA("Frame") then
			f.Size = UDim2.fromOffset(ctx.rng:NextNumber(8, 18), ctx.rng:NextNumber(4, 9))
		end
		table.insert(list, { f = f, a = ctx.rng:NextNumber(0, 6.28), h = i / 30, speed = ctx.rng:NextNumber(2.5, 4) })
	end
	return {
		step = function(dt, t)
			local size = ctx.size()
			-- (At a table it keeps to the open felt either side; walking, it roams the screen.)
			local reach = if ctx.mode == "table" then 0.32 else 0.28
			local cx = size.X * (0.5 + reach * math.sin(t * 0.3))
			local top = if ctx.mode == "table" then 0.26 else 0.3
			for i, r in ipairs(rings) do
				local k = (i - 1) / (#rings - 1)
				local w = 34 + k * size.X * top
				r.Size = UDim2.fromOffset(w, 24 + w * 0.2)
				-- (The higher bands lag behind the foot, so the funnel bends as it travels.)
				r.Position = UDim2.fromOffset(cx + math.sin(t * 2.2 + i * 0.55) * (6 + k * 26) - math.cos(t * 0.3) * k * 40, size.Y * (0.93 - k * 0.8))
				r.Rotation = math.sin(t * 3 + i) * 3
			end
			at(dust, cx, size.Y * 0.95, 160 + math.sin(t * 4) * 12, 40)
			for _, d in list do
				d.a += d.speed * dt
				local y = size.Y * (0.93 - d.h * 0.8)
				local r = 20 + d.h * size.X * top * 0.55
				d.f.Position = UDim2.fromOffset(cx + math.cos(d.a) * r - math.cos(t * 0.3) * d.h * 40, y + math.sin(d.a) * r * 0.18)
				d.f.Rotation = (d.a * 90) % 360
			end
		end,
		stop = function()
			for _, d in list do
				d.f:Destroy()
			end
			for _, r in rings do
				r:Destroy()
			end
			dust:Destroy()
		end,
	}
end

THEMES.fireworks = function(ctx)
	local list, add, move = particles()
	local acc = 1 -- (the first one at once)
	return {
		step = function(dt)
			local size = ctx.size()
			acc += dt * 1.3 * ctx.density
			while acc >= 1 do
				acc -= 1
				local cx, cy = ctx.rng:NextNumber(0.1, 0.9) * size.X, ctx.rng:NextNumber(0.08, 0.5) * size.Y
				local colour = RAINBOW[ctx.rng:NextInteger(1, #RAINBOW)]
				local n = 18
				for k = 1, n do
					local a = k / n * math.pi * 2
					local speed = ctx.rng:NextNumber(0.18, 0.26) * size.Y
					local f = frame(ctx.back, colour:Lerp(Color3.new(1, 1, 1), 0.3), 0, true)
					f.Size = UDim2.fromOffset(5, 5)
					add({ f = f, x = cx, y = cy, vx = math.cos(a) * speed, vy = math.sin(a) * speed, spin = 0, age = 0, life = 1.3, alpha = 0, w = 5, h = 5 })
				end
			end
			for _, p in list do
				p.vy += size.Y * 0.18 * dt
				p.vx *= 0.985
			end
			move(dt, function(_p)
				return true
			end)
		end,
		stop = function()
			clearAll(list)
		end,
	}
end

THEMES.titan = function(ctx)
	local glyphs = memeGlyphs()
	local face = glyph(ctx.back, glyphs[ctx.rng:NextInteger(1, #glyphs)], 300)
	face.TextTransparency = 0.1
	return {
		step = function(_dt, t)
			local size = ctx.size()
			local px = math.min(size.X, size.Y) * (if ctx.mode == "table" then 0.7 else 0.42)
			face.Size = UDim2.fromOffset(px, px)
			-- Rises behind the desk, looks round, sinks, and again.
			local cycle = (t % 16) / 16
			local up = if cycle < 0.15 then cycle / 0.15 elseif cycle < 0.8 then 1 else 1 - (cycle - 0.8) / 0.2
			face.Position = UDim2.fromOffset(size.X * 0.5, size.Y + px * 0.5 - up * px * 0.75)
			face.Rotation = math.sin(t * 1.2) * 12
		end,
		stop = function()
			face:Destroy()
		end,
	}
end

THEMES.zeroG = function(ctx)
	return fall(ctx, ctx.back, 6, function(p)
		local l = glyph(ctx.back, if ctx.rng:NextNumber() < 0.5 then "🪶" else "✨", ctx.rng:NextNumber(18, 30))
		p.vx = ctx.rng:NextNumber(-20, 20)
		p.y = ctx.size().Y + 30
		return l
	end, NumberRange.new(-0.07, -0.04), 20, 40)
end

THEMES.dance = function(ctx)
	local ball = glyph(ctx.front, "🪩", 60)
	local beams: { Frame } = {}
	for i = 1, 4 do
		local b = frame(ctx.back, RAINBOW[i + 1], 0)
		b.AnchorPoint = Vector2.new(0.5, 0)
		gradient(b, nil, fade(0.55, 1), 90)
		table.insert(beams, b)
	end
	local tint = frame(ctx.back, Color3.new(1, 1, 1), 0.92)
	tint.AnchorPoint = Vector2.zero
	tint.Size = UDim2.fromScale(1, 1)
	return {
		step = function(_dt, t)
			local size = ctx.size()
			ball.Position = UDim2.fromOffset(size.X * 0.5 + math.sin(t * 1.4) * 20, 42)
			ball.Rotation = math.sin(t * 2) * 10
			for i, b in beams do
				b.Size = UDim2.fromOffset(size.X * 0.08, size.Y * 1.2)
				b.Position = UDim2.fromOffset(size.X * 0.5, 42)
				b.Rotation = math.sin(t * 1.1 + i * 1.6) * 55
			end
			tint.BackgroundColor3 = RAINBOW[math.floor(t * 2) % #RAINBOW + 1]
		end,
		stop = function()
			ball:Destroy()
			tint:Destroy()
			for _, b in beams do
				b:Destroy()
			end
		end,
	}
end

THEMES.storm = function(ctx)
	local flash = frame(ctx.front, Color3.new(1, 1, 1), 1)
	flash.AnchorPoint = Vector2.zero
	flash.Size = UDim2.fromScale(1, 1)
	local rain = fall(ctx, ctx.back, 50, function(p)
		local f = frame(ctx.back, rgb(170, 190, 230), 0.4)
		f.Size = UDim2.fromOffset(2, ctx.rng:NextNumber(12, 22))
		f.Rotation = 12
		p.vx = -80
		return f
	end, NumberRange.new(1.1, 1.5), 10, 0)
	local bolts: { { parts: { Frame }, age: number } } = {}
	local nextBolt = 1
	return {
		step = function(dt, t)
			rain.step(dt, t)
			local size = ctx.size()
			if t >= nextBolt then
				nextBolt = t + ctx.rng:NextNumber(1.5, 3.5)
				local x = ctx.rng:NextNumber(0.1, 0.9) * size.X
				local y = 0
				local parts = {}
				for _ = 1, 7 do
					local nx, ny = x + ctx.rng:NextNumber(-40, 40), y + size.Y * 0.09
					local seg = frame(ctx.back, rgb(225, 235, 255), 0)
					local len = math.sqrt((nx - x) ^ 2 + (ny - y) ^ 2)
					seg.Size = UDim2.fromOffset(3, len)
					seg.Position = UDim2.fromOffset((x + nx) / 2, (y + ny) / 2)
					seg.Rotation = math.deg(math.atan2(ny - y, nx - x)) - 90
					table.insert(parts, seg)
					x, y = nx, ny
				end
				table.insert(bolts, { parts = parts, age = 0 })
				flash.BackgroundTransparency = 0.7
			end
			flash.BackgroundTransparency = math.min(1, flash.BackgroundTransparency + dt * 2.5)
			for i = #bolts, 1, -1 do
				local b = bolts[i]
				b.age += dt
				if b.age > 0.25 then
					for _, s in b.parts do
						s:Destroy()
					end
					table.remove(bolts, i)
				end
			end
		end,
		stop = function()
			rain.stop()
			flash:Destroy()
			for _, b in bolts do
				for _, s in b.parts do
					s:Destroy()
				end
			end
		end,
	}
end

THEMES.shockwave = function(ctx)
	local rings: { { f: Frame, age: number } } = {}
	local nextRing = 0
	return {
		step = function(dt, t)
			local size = ctx.size()
			if t >= nextRing then
				nextRing = t + 2.2
				local r = ring(ctx.back, GOLD, 5)
				r.Position = UDim2.fromScale(0.5, 0.5)
				table.insert(rings, { f = r, age = 0 })
				ctx.shake(4)
			end
			for i = #rings, 1, -1 do
				local r = rings[i]
				r.age += dt
				local k = r.age / 1.1
				local d = math.max(size.X, size.Y) * 1.3 * k
				r.f.Size = UDim2.fromOffset(d, d)
				local s = r.f:FindFirstChildOfClass("UIStroke")
				if s then
					s.Transparency = k
				end
				if k >= 1 then
					r.f:Destroy()
					table.remove(rings, i)
				end
			end
		end,
		stop = function()
			for _, r in rings do
				r.f:Destroy()
			end
		end,
	}
end

THEMES.spin = function(ctx)
	local arms: { Frame } = {}
	for i = 1, 6 do
		local a = frame(ctx.back, RAINBOW[i], 0)
		a.AnchorPoint = Vector2.new(0.5, 1)
		gradient(a, nil, fade(0.6, 1), 90)
		table.insert(arms, a)
	end
	return {
		step = function(_dt, t)
			local size = ctx.size()
			local len = math.max(size.X, size.Y) * 0.75
			for i, a in arms do
				a.Size = UDim2.fromOffset(size.X * 0.05, len)
				a.Position = UDim2.fromOffset(size.X * 0.5, size.Y * 0.5)
				a.Rotation = (t * 80 + i * 60) % 360
			end
		end,
		stop = function()
			for _, a in arms do
				a:Destroy()
			end
		end,
	}
end

THEMES.launch = function(ctx)
	local list, add, move = particles()
	local smoke, addSmoke, moveSmoke = particles()
	local acc = 1 -- (the first one at once)
	return {
		step = function(dt)
			local size = ctx.size()
			acc += dt * 1.2 * ctx.density
			while acc >= 1 do
				acc -= 1
				local l = glyph(ctx.back, "🚀", 40)
				l.Rotation = -45
				add({ f = l, x = ctx.rng:NextNumber(0.1, 0.9) * size.X, y = size.Y + 40, vx = 0, vy = -ctx.rng:NextNumber(0.6, 0.9) * size.Y, spin = 0, age = 0, life = 0, alpha = 0, w = 40, h = 40 })
			end
			for _, p in list do
				if math.random() < 0.6 then
					local s = frame(ctx.back, rgb(255, 210, 160), 0.3, true)
					s.Size = UDim2.fromOffset(10, 10)
					addSmoke({ f = s, x = p.x, y = p.y + 22, vx = math.random(-20, 20), vy = 30, spin = 0, age = 0, life = 0.9, alpha = 0.3, w = 10, h = 10 })
				end
			end
			move(dt, function(p)
				return p.y > -60
			end)
			moveSmoke(dt, function(_p)
				return true
			end)
		end,
		stop = function()
			clearAll(list)
			clearAll(smoke)
		end,
	}
end

-- Admin Abuse (no effect of its own on): gold sparks rising and the edges glowing gold; Mega
-- Abuse: rainbow sparks and a rainbow glow.
local function abuseTheme(mega: boolean): (Ctx) -> Theme
	return function(ctx)
		local glow = {}
		for i = 1, 2 do
			local e = frame(ctx.back, GOLD, 0)
			e.AnchorPoint = Vector2.zero
			gradient(e, nil, fade(0.5, 1), if i == 1 then 0 else 180)
			table.insert(glow, e)
		end
		local sparks = fall(ctx, ctx.front, if mega then 22 else 12, function(p)
			local f = frame(ctx.front, if mega then RAINBOW[ctx.rng:NextInteger(1, #RAINBOW)] else GOLD, 0.05, true)
			f.Size = UDim2.fromOffset(5, 5)
			p.life = 3
			p.alpha = 0.05
			p.y = ctx.size().Y + 10
			return f
		end, NumberRange.new(-0.22, -0.1), 30, 0)
		return {
			step = function(dt, t)
				sparks.step(dt, t)
				local size = ctx.size()
				local w = size.X * 0.12
				at(glow[1], 0, 0, w, size.Y)
				at(glow[2], size.X - w, 0, w, size.Y)
				for i, e in glow do
					e.BackgroundColor3 = if mega then Color3.fromHSV((t * 0.3 + i * 0.5) % 1, 0.8, 1) else GOLD
					e.BackgroundTransparency = 0.45 + 0.25 * math.sin(t * 3 + i)
				end
			end,
			stop = function()
				sparks.stop()
				for _, e in glow do
					e:Destroy()
				end
			end,
		}
	end
end
THEMES.__abuse = abuseTheme(false)
THEMES.__mega = abuseTheme(true)

ScreenFX.Themes = THEMES

---------------------------------------------------------------------------------------------------
-- A screen's effects
---------------------------------------------------------------------------------------------------
export type FX = {
	ctx: Ctx,
	running: { [string]: Theme },
	pulses: { [string]: number },
	ribbon: TextLabel?,
	t: number,
	enabled: boolean,
	golden: boolean,
	shakeLeft: number,
	shakeTarget: GuiObject?,
}

local all: { FX } = {}

-- Each of Admin Abuse's realms (World/AbuseShow) drawn as one of the effects' looks.
local REALM_THEMES: { [string]: string } = {
	cosmos = "galaxy",
	candy = "bubbles",
	midas = "goldWave",
	neon = "rainbow",
	abyss = "bubbles",
	frost = "blizzard",
}

-- What's on now, newest first: switched-on effects (by when), Admin Abuse, and short surprises.
local function wanted(fx: FX): { string }
	local list: { { id: string, since: number } } = {}
	for _, e in HouseEvents.Effects do
		local since = Workspace:GetAttribute(HouseEvents.fxAttribute(e.id))
		if type(since) == "number" and THEMES[e.id] then
			table.insert(list, { id = e.id, since = since })
		end
	end
	local now = os.clock()
	for id, untilAt in fx.pulses do
		if untilAt > now and THEMES[id] then
			table.insert(list, { id = id, since = math.huge })
		end
	end
	local ends = Workspace:GetAttribute("AbuseUntil")
	if type(ends) == "number" and ends > Workspace:GetServerTimeNow() then
		table.insert(list, { id = if Workspace:GetAttribute("AbuseMega") == true then "__mega" else "__abuse", since = -1 })
		-- The realm the house is in (Mega Abuse moves from one to the next): its look too.
		local realm = Workspace:GetAttribute("AbuseRealm")
		local theme = if type(realm) == "string" then REALM_THEMES[realm] else nil
		local at = Workspace:GetAttribute("AbuseRealmAt")
		if theme and THEMES[theme] then
			table.insert(list, { id = theme, since = if type(at) == "number" then at else 0 })
		end
	end
	table.sort(list, function(a, b)
		return a.since > b.since
	end)
	local out = {}
	for i = 1, math.min(3, #list) do
		table.insert(out, list[i].id)
	end
	return out
end

-- The ribbon's words over the table.
function ScreenFX.ribbonText(golden: boolean): string?
	local ends = Workspace:GetAttribute("AbuseUntil")
	local abusing = type(ends) == "number" and ends > Workspace:GetServerTimeNow()
	local cfg = require(ReplicatedStorage.Shared.Config).data.Admin
	local gold = if golden then "  ·  GOLDEN PIECES" else ""
	if abusing and Workspace:GetAttribute("AbuseMega") == true then
		local realm = Workspace:GetAttribute("AbuseRealm")
		local r = if type(realm) == "string" then HouseEvents.realmById[realm] else nil
		local where = if r then "  ·  " .. r.glyph .. " " .. r.name else ""
		return "🌋 MEGA ABUSE  ·  ×" .. tostring(cfg.table.megaGilt) .. " GILT" .. where .. gold
	elseif abusing then
		return "💥 ADMIN ABUSE  ·  ×" .. tostring(cfg.goldenHourGilt) .. " GILT" .. gold
	end
	local names = {}
	local newest, newestAt = nil :: string?, -1
	for _, e in HouseEvents.Effects do
		local since = Workspace:GetAttribute(HouseEvents.fxAttribute(e.id))
		if type(since) == "number" then
			table.insert(names, e.name)
			if since > newestAt then
				newest, newestAt = e.name, since
			end
		end
	end
	if #names == 0 then
		return nil
	end
	local what = if #names == 1 then string.upper(newest :: string) else string.format("%d EFFECTS ON", #names)
	return "✨ " .. what .. gold
end

local function refreshRibbon(fx: FX)
	local r = fx.ribbon
	if not r then
		return
	end
	local text = ScreenFX.ribbonText(fx.golden)
	r.Visible = text ~= nil and fx.enabled
	if text then
		r.Text = text
	end
end

-- Draws into `parent`: `back` behind the table's pieces, `front` over them (both never take a
-- click). `size` says how big the screen is; `mode` how busy to be.
function ScreenFX.new(back: Frame, front: Frame, size: () -> Vector2, mode: Mode, shakeTarget: GuiObject?): FX
	local fx: FX
	fx = {
		ctx = {
			back = back,
			front = front,
			size = size,
			density = if mode == "table" then 1 else 0.6,
			rng = Random.new(),
			mode = mode,
			shake = function(px: number)
				fx.shakeLeft = math.max(fx.shakeLeft, px)
			end,
		},
		running = {},
		pulses = {},
		ribbon = nil,
		t = 0,
		enabled = true,
		golden = false,
		shakeLeft = 0,
		shakeTarget = shakeTarget,
	}
	for _, f in { back, front } do
		f.Active = false
		f.BackgroundTransparency = 1
		f.ClipsDescendants = true
	end
	if mode == "table" then
		local r = Instance.new("TextLabel")
		r.Name = "AbuseRibbon"
		r.AnchorPoint = Vector2.new(0.5, 0)
		r.AutomaticSize = Enum.AutomaticSize.X
		r.Size = UDim2.fromOffset(0, 28)
		r.BackgroundColor3 = rgb(24, 14, 4)
		r.BackgroundTransparency = 0.08
		r.FontFace = HEAVY
		r.TextSize = 14
		r.TextColor3 = rgb(255, 226, 150)
		r.Visible = false
		r.ZIndex = 20
		r.Parent = front
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 14)
		c.Parent = r
		local p = Instance.new("UIPadding")
		p.PaddingLeft = UDim.new(0, 16)
		p.PaddingRight = UDim.new(0, 16)
		p.Parent = r
		local s = Instance.new("UIStroke")
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Thickness = 2
		s.Color = GOLD
		s.Parent = r
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, RAINBOW[1]),
			ColorSequenceKeypoint.new(0.25, RAINBOW[2]),
			ColorSequenceKeypoint.new(0.5, RAINBOW[3]),
			ColorSequenceKeypoint.new(0.75, RAINBOW[4]),
			ColorSequenceKeypoint.new(1, RAINBOW[6]),
		})
		g.Parent = s
		fx.ribbon = r
	end
	table.insert(all, fx)
	refreshRibbon(fx)
	return fx
end

-- Where the ribbon sits (the table puts it just under its header).
function ScreenFX.placeRibbon(fx: FX, y: number)
	local r = fx.ribbon
	if r then
		r.Position = UDim2.new(0.5, 0, 0, y)
	end
end

-- On or off (the walking screen goes quiet at a table: the table's own takes over).
function ScreenFX.setEnabled(fx: FX, on: boolean)
	fx.enabled = on
	if not on then
		for id, th in fx.running do
			th.stop()
			fx.running[id] = nil
		end
	end
	refreshRibbon(fx)
end

-- Whether this table's deals hold golden pieces (the rooms do; the Library and Ballroom don't).
function ScreenFX.setGolden(fx: FX, on: boolean)
	fx.golden = on
	refreshRibbon(fx)
end

-- A short one (an Admin Abuse surprise), for `seconds`.
function ScreenFX.pulse(id: string, seconds: number)
	for _, fx in all do
		fx.pulses[id] = os.clock() + seconds
	end
end

local function stepFX(fx: FX, dt: number)
	if not fx.enabled then
		return
	end
	fx.t += dt
	local want = wanted(fx)
	local keep: { [string]: boolean } = {}
	for _, id in want do
		keep[id] = true
		if not fx.running[id] then
			local ok, th = pcall(THEMES[id], fx.ctx)
			if ok and th then
				fx.running[id] = th
			end
		end
	end
	for id, th in fx.running do
		if not keep[id] then
			pcall(th.stop)
			fx.running[id] = nil
		else
			local ok, err = pcall(th.step :: any, dt, fx.t)
			if not ok then
				warn("[Maison] screen effect " .. id .. ": " .. tostring(err))
				pcall(th.stop)
				fx.running[id] = nil
				fx.pulses[id] = nil
			end
		end
	end
	for id, untilAt in fx.pulses do
		if untilAt <= os.clock() then
			fx.pulses[id] = nil
		end
	end
	-- A jolt (an impact, an earthquake), easing off.
	local target = fx.shakeTarget
	if target then
		if fx.shakeLeft > 0.2 then
			local s = fx.shakeLeft
			target.Position = UDim2.fromOffset(fx.ctx.rng:NextNumber(-s, s), fx.ctx.rng:NextNumber(-s, s))
			fx.shakeLeft *= math.exp(-10 * dt)
		elseif target.Position ~= UDim2.new() then
			target.Position = UDim2.new()
			fx.shakeLeft = 0
		end
	end
end

local started = false
function ScreenFX.start()
	if started then
		return
	end
	started = true
	RunService.RenderStepped:Connect(function(dt: number)
		for _, fx in all do
			stepFX(fx, dt)
		end
	end)
	local function ribbons()
		for _, fx in all do
			refreshRibbon(fx)
		end
	end
	for _, e in HouseEvents.Effects do
		Workspace:GetAttributeChangedSignal(HouseEvents.fxAttribute(e.id)):Connect(ribbons)
	end
	Workspace:GetAttributeChangedSignal("AbuseUntil"):Connect(ribbons)
	Workspace:GetAttributeChangedSignal("AbuseMega"):Connect(ribbons)
	Workspace:GetAttributeChangedSignal("AbuseRealm"):Connect(ribbons)
	-- Admin Abuse's surprises show here too, for as long as they play.
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) == "table" and m.op == "abuseFX" and type(m.id) == "string" and THEMES[m.id] then
			ScreenFX.pulse(m.id, if type(m.seconds) == "number" then math.clamp(m.seconds, 2, 40) else 8)
		elseif type(m) == "table" and m.op == "abuseFX" and m.id == "stop" then
			for _, fx in all do
				table.clear(fx.pulses)
			end
		end
	end)
	-- (Abuse ending is a time, not a change: check the ribbons now and then.)
	task.spawn(function()
		while true do
			task.wait(2)
			ribbons()
		end
	end)
end

-- The walking screen's layer (under the keys, over the house).
function ScreenFX.walkLayer(): FX?
	local gui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not gui then
		return nil
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonScreenFX"
	s.IgnoreGuiInset = true
	s.ResetOnSpawn = false
	s.DisplayOrder = 12
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Back"
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = s
	local front = Instance.new("Frame")
	front.Name = "Front"
	front.Size = UDim2.fromScale(1, 1)
	front.Parent = s
	return ScreenFX.new(back, front, function(): Vector2
		local camera = Workspace.CurrentCamera
		return if camera then camera.ViewportSize else Vector2.new(1280, 720)
	end, "walk", nil)
end

return ScreenFX

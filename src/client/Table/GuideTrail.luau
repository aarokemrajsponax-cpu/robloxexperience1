--!strict
-- The guide on the sorting screen. Pick a piece up and, in the rooms that help you, a thread of
-- light runs from it to the case it belongs in: beads flowing toward the case with a brighter
-- pulse running ahead, sparkles twinkling along the way, the case itself lit, and a gold arrow
-- bobbing over it. A carried piece also sheds a few sparkles behind it, in every room.
--
-- It follows the guest's settings (The guide: Trail, Trail colour, Trail pace; The room: Glow and
-- sparks, Movement) and the trail they wear from the Boutique or the Ledger. Frames only, placed
-- by hand in screen pixels, so it looks the same on a phone and a monitor and tests can see it.

local GuideTrail = {}

export type Look = {
	kind: string, -- "Sparkles" | "Ribbon" | "Comet" | "Runway" | "Case only"
	colour: Color3,
	pace: number, -- 1 normal, 1.6 lively, 0.55 calm
	glow: number, -- sparkles: 1 full, 0.5 subtle, 0 off
	motion: number, -- 1 full, 0.6 calm, 0 still
}

type Star = {
	frame: Frame,
	bars: { Frame },
	core: Frame,
	alive: boolean,
	born: number,
	life: number,
	at: Vector2,
	drift: Vector2,
	size: number,
	spin: number,
	turn: number,
}

local BEADS = 30
local STARS = 40
local WHITE = Color3.new(1, 1, 1)

local layer: Frame? = nil
local beads: { Frame } = {}
local stars: { Star } = {}
local arrow: Frame? = nil
local caseGlow: Frame? = nil
local caseRing: UIStroke? = nil
local look: Look = { kind = "Sparkles", colour = Color3.fromRGB(236, 216, 166), pace = 1, glow = 1, motion = 1 }
local now = 0
local emitCarry = 0
local shedCarry = 0
local rng = Random.new()

local function frame(parent: Instance, name: string, z: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.ZIndex = z
	f.Visible = false
	f.Parent = parent
	return f
end

local function round(f: Frame)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
end

-- Fades a bar from solid at its middle to nothing at its ends: one arm of a glint.
local function taper(f: Frame, rotation: number)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
end

local function makeStar(parent: Frame): Star
	local holder = frame(parent, "Sparkle", 6)
	holder.BackgroundTransparency = 1
	local across = frame(holder, "Arm", 6)
	across.Size = UDim2.fromScale(1, 0.14)
	across.Position = UDim2.fromScale(0.5, 0.5)
	across.Visible = true
	taper(across, 0)
	local down = frame(holder, "Arm", 6)
	down.Size = UDim2.fromScale(0.14, 1)
	down.Position = UDim2.fromScale(0.5, 0.5)
	down.Visible = true
	taper(down, 90)
	local core = frame(holder, "Core", 6)
	core.Size = UDim2.fromScale(0.26, 0.26)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Visible = true
	round(core)
	return { frame = holder, bars = { across, down }, core = core, alive = false, born = 0, life = 1, at = Vector2.zero, drift = Vector2.zero, size = 10, spin = 0, turn = 0 }
end

-- Builds the beads, the sparkles and the arrow in `parent` (the screen's trail layer), once.
function GuideTrail.attach(parent: Frame)
	if layer == parent and #beads > 0 then
		return
	end
	-- A new screen: the old one's pieces go with it.
	for _, b in beads do
		b:Destroy()
	end
	for _, st in stars do
		st.frame:Destroy()
	end
	if arrow then
		arrow:Destroy()
	end
	if caseGlow then
		caseGlow:Destroy()
	end
	caseGlow, caseRing, arrow = nil, nil, nil
	layer = parent
	beads, stars = {}, {}
	for i = 1, BEADS do
		local b = frame(parent, "Light", 5)
		round(b)
		b:SetAttribute("Index", i)
		table.insert(beads, b)
	end
	for _ = 1, STARS do
		table.insert(stars, makeStar(parent))
	end
	-- The arrow over the right case: two short bars meeting in a point.
	local a = frame(parent, "Arrow", 6)
	a.BackgroundTransparency = 1
	for _, side in { -1, 1 } do
		local bar = frame(a, "Arm", 6)
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Size = UDim2.fromScale(0.64, 0.22)
		bar.Position = UDim2.fromScale(0.5 + side * 0.2, 0.42)
		bar.Rotation = side * -42
		bar.BackgroundTransparency = 0
		bar.Visible = true
		round(bar)
	end
	arrow = a
end

function GuideTrail.setLook(l: Look)
	look = l
	local starColour = l.colour:Lerp(WHITE, 0.35)
	for _, b in beads do
		b.BackgroundColor3 = l.colour:Lerp(WHITE, 0.3)
	end
	for _, st in stars do
		for _, bar in st.bars do
			bar.BackgroundColor3 = starColour
		end
		st.core.BackgroundColor3 = WHITE
	end
	local a = arrow
	if a then
		for _, bar in a:GetChildren() do
			if bar:IsA("Frame") then
				bar.BackgroundColor3 = l.colour:Lerp(WHITE, 0.2)
			end
		end
	end
	if caseGlow then
		caseGlow.BackgroundColor3 = l.colour
	end
	if caseRing then
		caseRing.Color = l.colour
	end
end

function GuideTrail.look(): Look
	return look
end

-- Lights the case the piece belongs in: a soft wash of the trail's colour and a pulsing edge.
function GuideTrail.target(case: Frame?)
	if caseGlow then
		caseGlow:Destroy()
		caseGlow = nil
		caseRing = nil
	end
	if not case then
		return
	end
	local g = Instance.new("Frame")
	g.Name = "Guide"
	g.BorderSizePixel = 0
	g.BackgroundColor3 = look.colour
	g.BackgroundTransparency = 1
	g.Size = UDim2.fromScale(1, 1)
	g.ZIndex = 1
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 3)
	c.Parent = g
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0.8) })
	grad.Parent = g
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Color = look.colour
	ring.Thickness = 2
	ring.Transparency = 1
	ring.Parent = g
	g.Parent = case
	caseGlow = g
	caseRing = ring
end

local function hidePath()
	for _, b in beads do
		b.Visible = false
	end
	if arrow then
		arrow.Visible = false
	end
end

-- Stops the thread and the case light. Sparkles already out finish on their own.
function GuideTrail.hide()
	emitCarry = 0
	hidePath()
	GuideTrail.target(nil)
end

-- Everything off at once (the screen is closing).
function GuideTrail.clear()
	GuideTrail.hide()
	for _, st in stars do
		st.alive = false
		st.frame.Visible = false
	end
end

local function spawnStar(at: Vector2, drift: Vector2, size: number, life: number)
	for _, st in stars do
		if not st.alive then
			st.alive = true
			st.born = now
			st.life = life
			st.at = at
			st.drift = drift
			st.size = size
			st.spin = rng:NextNumber(0, 90)
			st.turn = rng:NextNumber(-120, 120)
			st.frame.Visible = true
			return
		end
	end
end

-- Moves every sparkle on: each one swells, turns a little and fades over its short life.
local function stepStars()
	for _, st in stars do
		if not st.alive then
			continue
		end
		local k = (now - st.born) / st.life
		if k >= 1 then
			st.alive = false
			st.frame.Visible = false
			continue
		end
		local swell = math.sin(math.pi * k)
		local p = st.at + st.drift * k
		local size = st.size * (0.35 + 0.65 * swell)
		st.frame.Position = UDim2.fromOffset(p.X, p.Y)
		st.frame.Size = UDim2.fromOffset(size, size)
		st.frame.Rotation = st.spin + st.turn * k
		local fade = 1 - swell * 0.95
		for _, bar in st.bars do
			bar.BackgroundTransparency = fade
		end
		st.core.BackgroundTransparency = math.min(1, fade + 0.1)
	end
end

local function bezier(from: Vector2, control: Vector2, to: Vector2, u: number): Vector2
	local a = from:Lerp(control, u)
	local b = control:Lerp(to, u)
	return a:Lerp(b, u)
end

-- One frame of the thread from `from` (the piece) to `to` (the top of its case). `appear` fades
-- it in (0 to 1); `s` is the screen's scale. Call every frame while it should show, after tick.
function GuideTrail.draw(dt: number, from: Vector2, to: Vector2, appear: number, s: number)
	local d = to - from
	local len = d.Magnitude
	local moving = look.motion >= 0.3
	local t0 = if moving then now else 0
	-- The arrow over the case, in every style: a slow bob.
	local a = arrow
	if a then
		local bob = if moving then math.sin(t0 * 5.2) * 5 * s else 0
		local w = 32 * s
		a.Visible = true
		a.Size = UDim2.fromOffset(w, w)
		a.Position = UDim2.fromOffset(to.X, to.Y - 26 * s + bob)
		for _, bar in a:GetChildren() do
			if bar:IsA("Frame") then
				bar.BackgroundTransparency = 1 - appear * 0.95
			end
		end
	end
	if caseGlow and caseRing then
		local pulse = 0.5 + 0.5 * math.sin(t0 * 4.4)
		caseGlow.BackgroundTransparency = 1 - appear * (0.22 + 0.1 * pulse)
		caseRing.Transparency = 1 - appear * (0.45 + 0.5 * pulse)
	end
	local kind = look.kind
	if kind == "Case only" or len < 30 * s then
		for _, b in beads do
			b.Visible = false
		end
		return
	end
	local normal = Vector2.new(-d.Y, d.X) / len
	local bend = if d.X >= 0 then 1 else -1
	local control = from + d * 0.5 + normal * math.min(len * 0.18, 110 * s) * bend
	local pace = look.pace
	local glow = look.glow
	-- A brighter pulse runs from the piece to the case, over and over: the way to go.
	local pulseAt = (t0 * 0.85 * pace) % 1.35
	for i = 1, BEADS do
		local b = beads[i]
		local u, size, alpha
		if kind == "Comet" then
			-- One bright head flying to the case, a tapering tail behind it.
			local head = (t0 * 0.7 * pace) % 1.25
			u = head - (i - 1) * 0.022
			local tail = (i - 1) / (BEADS - 1)
			size = (11 - 8 * tail) * s
			alpha = (1 - tail) ^ 1.4
			if u < 0.08 or u > 1 then
				alpha = 0
			end
		elseif kind == "Runway" then
			-- A row of lamps along the way, lit one after another toward the case.
			local n = 14
			if i > n then
				b.Visible = false
				continue
			end
			u = 0.1 + (i - 1) / (n - 1) * 0.9
			local wave = ((t0 * 1.3 * pace - u) % 1)
			local lit = math.max(0, 1 - wave / 0.3)
			size = (5 + 4 * lit) * s
			alpha = 0.35 + 0.65 * lit
		else
			local t = ((i - 1) / BEADS + t0 * 0.3 * pace) % 1
			u = 0.1 + t * 0.9
			local edge = math.abs(t - 0.5) * 2
			local near = math.exp(-((u - pulseAt) ^ 2) / 0.006)
			if kind == "Ribbon" then
				size = (9 + 4 * near) * s
				alpha = (1 - edge ^ 4) * (0.8 + 0.2 * near)
			else
				size = (6 + 3 * (1 - edge) + 5 * near) * s
				alpha = (1 - edge ^ 3) * (0.85 + 0.15 * near)
			end
		end
		local p = bezier(from, control, to, math.clamp(u, 0, 1))
		alpha *= appear
		b.Visible = alpha > 0.02
		b.Position = UDim2.fromOffset(p.X, p.Y)
		b.Size = UDim2.fromOffset(size, size)
		b.BackgroundTransparency = 1 - alpha
	end
	-- Sparkles along the way (the Sparkles trail), or flung off the Comet's head.
	if moving and glow > 0 and appear > 0.5 and (kind == "Sparkles" or kind == "Comet") then
		local rate = (if kind == "Comet" then 12 else 22) * pace * glow
		emitCarry += rate * dt
		while emitCarry >= 1 do
			emitCarry -= 1
			local u = if kind == "Comet" then math.clamp((t0 * 0.7 * pace) % 1.25, 0.1, 1) else rng:NextNumber(0.12, 1)
			local p = bezier(from, control, to, u) + normal * rng:NextNumber(-10, 10) * s
			local drift = Vector2.new(rng:NextNumber(-10, 10), rng:NextNumber(-22, -6)) * s
			spawnStar(p, drift, rng:NextNumber(16, 28) * s, rng:NextNumber(0.45, 0.85))
		end
	end
end

-- Every frame, before draw and whether or not the thread shows: sparkles shed by a carried
-- piece (`at`, moving at `velocity` pixels a second), and the sparkles already out.
function GuideTrail.tick(dt: number, at: Vector2?, velocity: Vector2?, s: number)
	now += dt
	if at and velocity and look.glow > 0 and look.motion >= 0.3 then
		local speed = velocity.Magnitude
		if speed > 90 * s then
			shedCarry += math.min(30, speed / (30 * s)) * look.glow * dt
			local back = -velocity.Unit
			while shedCarry >= 1 do
				shedCarry -= 1
				local p = at + back * rng:NextNumber(6, 20) * s + Vector2.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12)) * s
				spawnStar(p, back * rng:NextNumber(10, 26) * s + Vector2.new(0, rng:NextNumber(-10, 4) * s), rng:NextNumber(10, 18) * s, rng:NextNumber(0.35, 0.6))
			end
		end
	else
		shedCarry = 0
	end
	stepStars()
end

-- How many sparkles are out (for tests).
function GuideTrail.sparkles(): number
	local n = 0
	for _, st in stars do
		if st.alive then
			n += 1
		end
	end
	return n
end

return GuideTrail

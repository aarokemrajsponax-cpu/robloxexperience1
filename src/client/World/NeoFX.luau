--!strict
-- The house's look for its biggest moments (Admin and Mega Abuse, the realms, the haul): big,
-- bold and loud, but clean. Heavy type that punches in, a shine running across it, a soft shadow
-- under it, shockwaves, light bursts and lens streaks. Everything here is a few frames on the
-- screen, moved by the engine's own tweens or one short-lived step each, so the show costs next
-- to nothing to draw.
--   decode     words that punch in: big, then settling, with a flash of white
--   typeOut    words that fade up in place
--   chroma     a soft drop shadow that follows a title wherever its entrance takes it
--   streak     a lens streak through a point, opening sideways
--   ring       a double ring racing out (a shockwave)
--   sparks     a burst of light flung out, slowing, fading
--   shimmer    a shine that runs along words for as long as they're up
-- (brackets, scan, grid and readout are kept for the callers that still ask: they draw nothing.)

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local NeoFX = {}

-- The type: the heaviest the house has for the big words, its bold for everything said with them.
NeoFX.TITLE = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
NeoFX.MONO = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
NeoFX.MONO_BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)

local rgb = Color3.fromRGB
NeoFX.CYAN = rgb(255, 214, 96) -- (Mega Abuse's two lights: hot gold...)
NeoFX.MAGENTA = rgb(255, 58, 150) -- (...and hot pink)
NeoFX.VIOLET = rgb(170, 110, 255)
NeoFX.WHITE = rgb(242, 246, 255)
NeoFX.INK = rgb(5, 6, 10)

export type Neo = { a: Color3, b: Color3, core: Color3 }

-- The two lights of a moment, and its white-hot core. Mega Abuse: hot gold and hot pink.
-- Otherwise the night's own colour, lifted, against its deeper partner.
function NeoFX.colours(mega: boolean, light: Color3?, main: Color3?): Neo
	if mega or not light or not main then
		return { a = NeoFX.CYAN, b = NeoFX.MAGENTA, core = NeoFX.WHITE }
	end
	return { a = light:Lerp(Color3.new(1, 1, 1), 0.15), b = main, core = NeoFX.WHITE }
end

local function tween(o: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(o, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end
NeoFX.tween = tween

local function bar(parent: Instance, name: string, colour: Color3, alpha: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = alpha
	f.Parent = parent
	return f
end

local function fadeLater(o: Instance, after: number)
	task.delay(after, function()
		if o.Parent then
			o:Destroy()
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Words
---------------------------------------------------------------------------------------------------
-- `label` shows `final`, punching in: big and bright, settling to its size in a blink. (The words
-- are there from the first frame.)
function NeoFX.decode(label: TextLabel, final: string, seconds: number?, onDone: (() -> ())?)
	label.Text = final
	local found = label:FindFirstChild("Pop")
	local pop: UIScale
	if found and found:IsA("UIScale") then
		pop = found
	else
		pop = Instance.new("UIScale")
		pop.Name = "Pop"
		pop.Parent = label
	end
	local s = math.clamp((seconds or 0.5) * 0.9, 0.25, 0.6)
	pop.Scale = 1.35
	tween(pop, s, { Scale = 1 }, Enum.EasingStyle.Back)
	if onDone then
		task.delay(s, onDone)
	end
end

-- `label` shows `text`, fading up in place.
function NeoFX.typeOut(label: TextLabel, text: string, _perSecond: number?, delay: number?)
	label.Text = text
	local was = label.TextTransparency
	label.TextTransparency = 1
	task.delay(delay or 0, function()
		if label.Parent then
			tween(label, 0.35, { TextTransparency = was })
		end
	end)
end

-- A soft drop shadow under `title` (a dark copy just beneath it), following it wherever its own
-- entrance takes it, gone after `life` seconds. (jitter, merge and out are the old ghosts' calls:
-- out fades the shadow with the title; the others do nothing.)
export type Chroma = { jitter: (seconds: number, amount: number?) -> (), merge: (seconds: number) -> (), out: (seconds: number) -> (), destroy: () -> () }
function NeoFX.chroma(title: TextLabel, life: number): Chroma
	local g = Instance.new("TextLabel")
	g.Name = "Shadow"
	g.BackgroundTransparency = 1
	g.FontFace = title.FontFace
	g.TextScaled = title.TextScaled
	g.TextSize = title.TextSize
	g.Text = title.Text
	g.TextColor3 = Color3.new(0, 0, 0)
	g.TextTransparency = 0.45
	g.ZIndex = math.max(1, title.ZIndex - 1)
	g.AnchorPoint = title.AnchorPoint
	g.Parent = title.Parent
	local alive = true
	local fade = 0.45
	local ok, high = pcall(function()
		return title.AbsoluteSize.Y
	end)
	local drop = math.max(3, (if ok and type(high) == "number" then high else 60) * 0.04)
	local conn = RunService.RenderStepped:Connect(function()
		if not alive then
			return
		end
		if not title.Parent then
			alive = false
			return
		end
		g.Position = title.Position + UDim2.fromOffset(0, drop)
		g.Size = title.Size
		g.Rotation = title.Rotation
		g.Text = title.Text
		g.TextTransparency = math.max(fade, title.TextTransparency)
		g.Visible = title.Visible
	end)
	local function destroy()
		alive = false
		conn:Disconnect()
		g:Destroy()
	end
	task.delay(life, destroy)
	return {
		jitter = function(_seconds: number, _amount: number?) end,
		merge = function(_seconds: number) end,
		out = function(seconds: number)
			fade = 1
			if g.Parent then
				tween(g, seconds, { TextTransparency = 1 })
			end
		end,
		destroy = destroy,
	}
end

-- A gradient that runs along `target`'s words (or its fill, or its edge: a UIStroke) in the
-- moment's colours, for as long as `target` is up: a sheen of white-hot light crossing them every
-- couple of seconds.
function NeoFX.shimmer(target: Instance, neo: Neo, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, neo.a),
		ColorSequenceKeypoint.new(0.42, neo.a:Lerp(neo.core, 0.55)),
		ColorSequenceKeypoint.new(0.5, neo.core),
		ColorSequenceKeypoint.new(0.58, neo.b:Lerp(neo.core, 0.55)),
		ColorSequenceKeypoint.new(1, neo.b),
	})
	g.Rotation = rotation or 0
	g.Offset = Vector2.new(-0.6, 0)
	g.Parent = target
	TweenService:Create(g, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Offset = Vector2.new(0.6, 0) }):Play()
	return g
end

---------------------------------------------------------------------------------------------------
-- Light
---------------------------------------------------------------------------------------------------

-- (Kept for callers: an empty holder, gone of itself.)
function NeoFX.brackets(parent: Instance, centre: Vector2, size: Vector2, _colour: Color3, z: number?, _thickness: number?): Frame
	local holder = bar(parent, "Brackets", Color3.new(), 1)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromOffset(centre.X, centre.Y)
	holder.Size = UDim2.fromOffset(size.X, size.Y)
	holder.ZIndex = z or 18
	fadeLater(holder, 6)
	return holder
end

function NeoFX.scan(_parent: Instance, _colour: Color3, _seconds: number?, _z: number?) end

-- A lens streak through `at`, opening sideways to `width` and fading.
function NeoFX.streak(parent: Instance, at: Vector2, colour: Color3, width: number, z: number?)
	for i, spec in { { 4, 0 }, { 18, 0.6 } } do
		local s = bar(parent, "Streak", if i == 1 then Color3.new(1, 1, 1) else colour, spec[2])
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromOffset(at.X, at.Y)
		s.Size = UDim2.fromOffset(width * 0.1, spec[1])
		s.ZIndex = (z or 18) - (i - 1)
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = s
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = s
		tween(s, 0.35, { Size = UDim2.fromOffset(width, spec[1]) }, Enum.EasingStyle.Quint)
		task.delay(0.3, function()
			if s.Parent then
				tween(s, 0.7, { BackgroundTransparency = 1, Size = UDim2.fromOffset(width * 1.15, spec[1] * 0.4) })
			end
		end)
		fadeLater(s, 1.1)
	end
end

-- A thin double ring of light racing out from `at` to `reach` pixels across.
function NeoFX.ring(parent: Instance, at: Vector2, colour: Color3, reach: number, seconds: number?, z: number?)
	local s = seconds or 0.7
	for i = 1, 2 do
		local r = bar(parent, "Ring", Color3.new(1, 1, 1), 1)
		r.AnchorPoint = Vector2.new(0.5, 0.5)
		r.Position = UDim2.fromOffset(at.X, at.Y)
		r.Size = UDim2.fromOffset(24, 24)
		r.ZIndex = z or 17
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = r
		local st = Instance.new("UIStroke")
		st.Color = if i == 1 then colour else Color3.new(1, 1, 1)
		st.Thickness = if i == 1 then 5 else 1.5
		st.Transparency = if i == 1 then 0.25 else 0.1
		st.Parent = r
		local go = s * (if i == 1 then 1 else 0.82)
		local far = reach * (if i == 1 then 1 else 0.86)
		task.delay((i - 1) * 0.06, function()
			if r.Parent then
				tween(r, go, { Size = UDim2.fromOffset(far, far) }, Enum.EasingStyle.Quint)
				tween(st, go, { Transparency = 1, Thickness = 1 })
			end
		end)
		fadeLater(r, go + 0.2)
	end
end

-- An energy burst from `at`: `count` thin lines of light flung outward, slowing and fading.
function NeoFX.sparks(parent: Instance, at: Vector2, count: number, power: number, colours: { Color3 }, z: number?)
	type Spark = { f: Frame, x: number, y: number, vx: number, vy: number, age: number, life: number }
	local list: { Spark } = {}
	for _ = 1, count do
		local a = math.random() * math.pi * 2
		local speed = power * (0.35 + math.random() * 0.9)
		local f = bar(parent, "Spark", colours[math.random(1, #colours)], 0)
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(math.random(10, 26), 2)
		f.Rotation = math.deg(a)
		f.ZIndex = z or 20
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = f
		table.insert(list, { f = f, x = at.X, y = at.Y, vx = math.cos(a) * speed, vy = math.sin(a) * speed, age = 0, life = 0.55 + math.random() * 0.6 })
	end
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		local alive = 0
		for _, s in list do
			if s.f.Parent then
				s.age += dt
				local drag = math.exp(-3.2 * dt)
				s.vx *= drag
				s.vy *= drag
				s.x += s.vx * dt
				s.y += s.vy * dt
				s.f.Position = UDim2.fromOffset(s.x, s.y)
				local k = s.age / s.life
				s.f.BackgroundTransparency = math.clamp(k * k, 0, 1)
				if k >= 1 then
					s.f:Destroy()
				else
					alive += 1
				end
			end
		end
		if alive == 0 and conn then
			conn:Disconnect()
			conn = nil
		end
	end)
end

-- (Kept for callers: empty holders, gone of themselves.)
function NeoFX.grid(parent: Instance, _view: Vector2, _colour: Color3, _spacing: number, seconds: number, z: number?): Frame
	local holder = bar(parent, "Grid", Color3.new(), 1)
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = z or 2
	fadeLater(holder, seconds + 0.2)
	return holder
end

function NeoFX.readout(parent: Instance, _lines: { string }, anchor: Vector2, _colour: Color3, _px: number, z: number?): Frame
	local holder = bar(parent, "Readout", Color3.new(), 1)
	holder.AnchorPoint = anchor
	holder.Size = UDim2.fromOffset(0, 0)
	holder.ZIndex = z or 19
	fadeLater(holder, 12)
	return holder
end

return NeoFX

--!strict
-- (Build 102) The house's loading scene: the Maison itself at night, drawn with the engine's own
-- frames (nothing to fetch, so it's there on the very first frame and sharp at any size). A night
-- sky with two searchlights sweeping it, as on a gala night; the great house across the
-- forecourt, its portico and columns, its tall arched windows lit gold (a chandelier glowing in
-- the middle one), light spilling from the open doors down the steps; the whole facade mirrored in
-- the polished black marble of the forecourt; and gold dust drifting up through it all. Each place
-- has its own colours (Steal a Luxe's crimson, the Basement's copper, the Executive Suite's midnight
-- blue, the house's black and gold).
--
--   local scene = Skyline.build(frame, "luxe", viewportPixels, lite?, centred?)
--   scene.step(secondsSinceShown)   -- each frame: the lights, the windows and the dust move
--
-- Built in the screen's real pixels, so arches and lights stay round and nothing is stretched at
-- any shape of screen; `lite` draws less for small or low-end devices.

local Skyline = {}

export type Palette = {
	sky: { { number | Color3 } },
	glow: Color3,
	stone: Color3,
	trim: Color3,
	window: Color3,
	windowDeep: Color3,
	floor: Color3,
	beam: Color3,
	dust: Color3,
}

local rgb = Color3.fromRGB

Skyline.PALETTES = {
	-- The house: black and gold.
	house = {
		sky = { { 0, rgb(6, 5, 10) }, { 0.55, rgb(22, 16, 22) }, { 0.85, rgb(58, 40, 26) }, { 1, rgb(96, 66, 34) } },
		glow = rgb(255, 196, 110),
		stone = rgb(20, 16, 18),
		trim = rgb(214, 168, 84),
		window = rgb(255, 214, 140),
		windowDeep = rgb(196, 120, 52),
		floor = rgb(8, 7, 9),
		beam = rgb(255, 226, 170),
		dust = rgb(255, 214, 140),
	},
	-- Steal a Luxe: velvet crimson.
	luxe = {
		sky = { { 0, rgb(10, 3, 8) }, { 0.55, rgb(40, 8, 22) }, { 0.85, rgb(96, 18, 44) }, { 1, rgb(150, 36, 64) } },
		glow = rgb(255, 110, 140),
		stone = rgb(24, 8, 14),
		trim = rgb(232, 170, 110),
		window = rgb(255, 196, 180),
		windowDeep = rgb(210, 60, 96),
		floor = rgb(10, 4, 7),
		beam = rgb(255, 170, 190),
		dust = rgb(255, 190, 170),
	},
	-- The Basement: copper over deep teal.
	basement = {
		sky = { { 0, rgb(3, 10, 12) }, { 0.55, rgb(10, 30, 34) }, { 0.85, rgb(54, 46, 34) }, { 1, rgb(110, 72, 40) } },
		glow = rgb(240, 160, 90),
		stone = rgb(10, 20, 22),
		trim = rgb(214, 140, 80),
		window = rgb(255, 200, 130),
		windowDeep = rgb(190, 100, 50),
		floor = rgb(4, 9, 10),
		beam = rgb(240, 200, 150),
		dust = rgb(255, 190, 120),
	},
	-- The Executive Suite: midnight blue, cold light in the windows.
	executive = {
		sky = { { 0, rgb(2, 4, 14) }, { 0.55, rgb(8, 16, 44) }, { 0.85, rgb(26, 34, 84) }, { 1, rgb(60, 60, 130) } },
		glow = rgb(130, 190, 255),
		stone = rgb(8, 12, 26),
		trim = rgb(170, 200, 240),
		window = rgb(196, 230, 255),
		windowDeep = rgb(80, 140, 230),
		floor = rgb(3, 5, 12),
		beam = rgb(190, 220, 255),
		dust = rgb(190, 220, 255),
	},
} :: { [string]: Palette }

export type Scene = { step: (t: number) -> (), root: Frame }

-- A seeded generator: a place's house is lit the same way every time.
local function rng(seed: number): (number, number) -> number
	local r = Random.new(seed)
	return function(a: number, b: number): number
		return a + (b - a) * r:NextNumber()
	end
end

local function frame(parent: Instance, name: string, colour: Color3, x: number, y: number, w: number, h: number, t: number?, z: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = t or 0
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

local function round(f: GuiObject, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or UDim.new(1, 0)
	c.Parent = f
end

local function sequence(stops: { { number | Color3 } }): ColorSequence
	local keys = {}
	for _, s in stops do
		table.insert(keys, ColorSequenceKeypoint.new(s[1] :: number, s[2] :: Color3))
	end
	return ColorSequence.new(keys)
end

local function fade(f: GuiObject, stops: { { number } }, rotation: number?)
	local keys = {}
	for _, s in stops do
		table.insert(keys, NumberSequenceKeypoint.new(s[1], s[2]))
	end
	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 0
	g.Transparency = NumberSequence.new(keys)
	g.Parent = f
	return g
end

-- An arched window: a tall pane, round at the top, lit from below, with its glazing bars.
local function window(parent: Instance, P: Palette, x: number, y: number, w: number, h: number, lit: boolean, z: number): Frame
	local f = frame(parent, "Window", Color3.new(1, 1, 1), x, y, w, h, 0, z)
	round(f, UDim.new(0, math.floor(w / 2)))
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = if lit then ColorSequence.new(P.window, P.windowDeep) else ColorSequence.new(rgb(26, 22, 26), rgb(10, 9, 12))
	g.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = P.trim
	stroke.Thickness = math.max(1, w * 0.06)
	stroke.Transparency = 0.25
	stroke.Parent = f
	-- The glazing: a bar down the middle and two across.
	frame(f, "Mullion", P.stone, w / 2 - 1, w * 0.4, 2, h - w * 0.4, 0.2, z + 1)
	frame(f, "Transom", P.stone, 0, h * 0.38, w, 2, 0.2, z + 1)
	frame(f, "Transom", P.stone, 0, h * 0.7, w, 2, 0.2, z + 1)
	f:SetAttribute("Lit", lit)
	return f
end

function Skyline.build(parent: Instance, place: string?, size: Vector2, lite: boolean?, centred: boolean?): Scene
	local P: Palette = Skyline.PALETTES[place or "house"] or Skyline.PALETTES.house
	local W, H = math.max(320, size.X), math.max(240, size.Y)
	local seed = 0
	for i = 1, #(place or "house") do
		seed += string.byte(place or "house", i) * i
	end
	local R = rng(seed)
	local few = lite == true

	local root = Instance.new("Frame")
	root.Name = "Skyline"
	root.BackgroundColor3 = P.floor
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.Parent = parent

	local ground = math.floor(H * 0.72) -- where the house stands on the forecourt
	-- The night sky.
	local sky = frame(root, "Sky", Color3.new(1, 1, 1), 0, 0, W, ground + 2, 0, 1)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Color = sequence(P.sky)
	sg.Parent = sky

	-- A few stars.
	local stars: { Frame } = {}
	for _ = 1, if few then 16 else 34 do
		local d = R(1, 2.2)
		local s = frame(root, "Star", rgb(255, 246, 230), R(0, W), R(0, ground * 0.5), d, d, R(0.2, 0.7), 2)
		round(s)
		table.insert(stars, s)
	end

	-- The house's size and place: on the right, clear of the words (in the middle when centred).
	local houseW = math.min(W * (if centred then 0.86 else 0.46), H * (if centred then 1.5 else 1.3))
	local houseH = houseW * 0.42
	local hx = if centred then (W - houseW) / 2 else W - houseW - W * 0.03
	local hy = ground - houseH

	-- Two searchlights behind the house, sweeping the sky.
	local beams: { { f: Frame, base: number, speed: number, phase: number } } = {}
	for i, spec in { { hx + houseW * 0.22, -1 }, { hx + houseW * 0.78, 1 } } do
		local b = frame(root, "Searchlight", P.beam, spec[1] :: number, ground, math.max(10, W * 0.05), H * 1.4, 0, 3)
		b.AnchorPoint = Vector2.new(0.5, 1)
		fade(b, { { 0, 1 }, { 0.15, 0.82 }, { 0.85, 0.9 }, { 1, 0.6 } }, 90)
		table.insert(beams, { f = b, base = (spec[2] :: number) * 18, speed = 0.35 + i * 0.07, phase = i * 1.7 })
	end
	-- A warm glow behind the house, as if the whole forecourt were lit.
	local halo = frame(root, "Halo", P.glow, hx - houseW * 0.1, hy - houseH * 0.5, houseW * 1.2, houseH * 1.4, 0.55, 4)
	round(halo, UDim.new(0.5, 0))
	fade(halo, { { 0, 1 }, { 0.5, 0.55 }, { 1, 1 } }, 90)

	-- The house: two wings and the raised centre with its portico.
	local body = frame(root, "House", P.stone, hx, hy + houseH * 0.18, houseW, houseH * 0.82, 0, 6)
	local bodyShade = Instance.new("UIGradient")
	bodyShade.Rotation = 90
	bodyShade.Color = ColorSequence.new(P.stone:Lerp(Color3.new(1, 1, 1), 0.06), P.stone:Lerp(Color3.new(0, 0, 0), 0.5))
	bodyShade.Parent = body
	local centreW = houseW * 0.34
	local cx = hx + (houseW - centreW) / 2
	local centre = frame(root, "Centre", P.stone, cx, hy, centreW, houseH, 0, 7)
	local centreShade = bodyShade:Clone()
	centreShade.Parent = centre
	-- The pediment over the portico: a square turned on its corner, its lower half behind.
	local ped = centreW * 0.52
	local pediment = frame(root, "Pediment", P.stone, cx + centreW / 2, hy + 2, ped, ped, 0, 6)
	pediment.AnchorPoint = Vector2.new(0.5, 0.5)
	pediment.Rotation = 45
	local pedEdge = Instance.new("UIStroke")
	pedEdge.Color = P.trim
	pedEdge.Thickness = 2
	pedEdge.Transparency = 0.2
	pedEdge.Parent = pediment
	-- Gold cornices along the roofline and the floor line, and a balustrade on the wings.
	frame(root, "Cornice", P.trim, hx - 4, hy + houseH * 0.18 - 3, houseW + 8, 3, 0.1, 8)
	frame(root, "CorniceCentre", P.trim, cx - 4, hy - 3, centreW + 8, 3, 0.05, 8)
	frame(root, "Plinth", P.trim, hx - 6, ground - 3, houseW + 12, 3, 0.2, 8)
	local posts = if few then 10 else 18
	for i = 0, posts do
		local px = hx + houseW * (i / posts)
		if px < cx - 2 or px > cx + centreW + 2 then
			frame(root, "Baluster", P.trim, px - 1, hy + houseH * 0.18 - 12, 2, 10, 0.45, 8)
		end
	end
	frame(root, "Rail", P.trim, hx, hy + houseH * 0.18 - 13, houseW, 2, 0.35, 8)

	-- The windows: two rows on each wing, the portico's columns and its great doors between.
	local windows: { Frame } = {}
	local cols = if few then 3 else 4
	local wingW = (houseW - centreW) / 2
	local winW = wingW / (cols * 1.9)
	for side = 0, 1 do
		local x0 = if side == 0 then hx else cx + centreW
		for row = 0, 1 do
			local wy = hy + houseH * (0.3 + row * 0.33)
			local wh = houseH * 0.24
			for c = 0, cols - 1 do
				local wx = x0 + wingW * ((c + 0.5) / cols) - winW / 2
				table.insert(windows, window(root, P, wx, wy, winW, wh, R(0, 1) < 0.8, 9))
			end
		end
	end
	-- The middle window over the doors, with a chandelier's glow in it.
	local midW = centreW * 0.22
	local mid = window(root, P, cx + centreW / 2 - midW / 2, hy + houseH * 0.16, midW, houseH * 0.3, true, 9)
	local chandelier = frame(mid, "Chandelier", rgb(255, 246, 220), midW / 2, houseH * 0.12, midW * 0.7, midW * 0.7, 0.15, 11)
	chandelier.AnchorPoint = Vector2.new(0.5, 0.5)
	round(chandelier)
	fade(chandelier, { { 0, 0.1 }, { 1, 0.9 } }, 90)
	-- Columns across the portico.
	local n = 6
	for i = 0, n - 1 do
		local colX = cx + centreW * (0.08 + 0.84 * (i / (n - 1)))
		local col = frame(root, "Column", P.trim, colX - 3, hy + houseH * 0.5, 6, houseH * 0.5, 0.15, 10)
		fade(col, { { 0, 0.1 }, { 1, 0.6 } }, 90)
	end
	-- The great doors, open, the light pouring out and down the steps.
	local doorW = centreW * 0.22
	local door = frame(root, "Doors", P.window, cx + centreW / 2 - doorW / 2, ground - houseH * 0.36, doorW, houseH * 0.36, 0, 9)
	round(door, UDim.new(0, math.floor(doorW / 2)))
	local doorLight = Instance.new("UIGradient")
	doorLight.Rotation = 90
	doorLight.Color = ColorSequence.new(rgb(255, 250, 236), P.window)
	doorLight.Parent = door
	local spill = frame(root, "Spill", P.glow, cx + centreW / 2 - doorW * 1.6, ground, doorW * 3.2, (H - ground) * 0.7, 0.35, 5)
	fade(spill, { { 0, 0.2 }, { 1, 1 } }, 90)
	-- Steps.
	for k = 1, 3 do
		frame(root, "Step", P.trim, cx + centreW / 2 - doorW * (0.9 + k * 0.35), ground + k * 4, doorW * (1.8 + k * 0.7), 2, 0.55 + k * 0.1, 8)
	end

	-- The forecourt: polished black marble, the house mirrored in it.
	local floor = frame(root, "Forecourt", P.floor, 0, ground, W, H - ground, 0, 4)
	local fg = Instance.new("UIGradient")
	fg.Rotation = 90
	fg.Color = ColorSequence.new(P.floor:Lerp(P.glow, 0.08), P.floor)
	fg.Parent = floor
	local reflections: { { f: Frame, phase: number } } = {}
	for _, w in windows do
		if w:GetAttribute("Lit") then
			local r = frame(root, "Reflection", P.window, w.Position.X.Offset + w.Size.X.Offset * 0.15, ground + (ground - w.Position.Y.Offset - w.Size.Y.Offset) * 0.6, w.Size.X.Offset * 0.7, w.Size.Y.Offset * 0.8, 0.8, 5)
			fade(r, { { 0, 0.6 }, { 1, 1 } }, 90)
			table.insert(reflections, { f = r, phase = R(0, 6.28) })
		end
	end
	-- Fine joints in the marble, receding.
	for k = 1, if few then 3 else 5 do
		frame(root, "Joint", P.trim, 0, ground + (H - ground) * (k / 6) ^ 1.6, W, 1, 0.9, 5)
	end

	-- Gold dust, drifting up.
	local dust: { { f: Frame, x: number, y: number, speed: number, sway: number } } = {}
	for _ = 1, if few then 18 else 40 do
		local d = R(1.5, 3.5)
		local m = frame(root, "Dust", P.dust, 0, 0, d, d, R(0.2, 0.6), 12)
		round(m)
		table.insert(dust, { f = m, x = R(0, W), y = R(0, H), speed = R(10, 34), sway = R(6, 20) })
	end

	local function step(t: number)
		for i, b in beams do
			b.f.Rotation = b.base + math.sin(t * b.speed + b.phase) * 16
			b.f.BackgroundTransparency = 0.05 * (0.5 + 0.5 * math.sin(t * 1.1 + i))
		end
		for i, s in stars do
			if i % 3 == math.floor(t * 5) % 3 then
				s.BackgroundTransparency = 0.25 + 0.5 * (0.5 + 0.5 * math.sin(t * 2.1 + i * 1.9))
			end
		end
		chandelier.BackgroundTransparency = 0.1 + 0.12 * (0.5 + 0.5 * math.sin(t * 2.6))
		halo.BackgroundTransparency = 0.5 + 0.08 * math.sin(t * 0.9)
		for _, r in reflections do
			r.f.BackgroundTransparency = 0.74 + 0.08 * math.sin(t * 1.7 + r.phase)
		end
		for _, m in dust do
			local y = (m.y - t * m.speed) % (H + 10)
			m.f.Position = UDim2.fromOffset(m.x + math.sin(t * 0.8 + m.y) * m.sway, y)
		end
	end

	return { step = step, root = root }
end

return Skyline

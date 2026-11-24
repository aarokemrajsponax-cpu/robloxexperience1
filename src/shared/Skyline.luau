--!strict
-- (Build 102) The house's loading scene: a city at dusk seen across the water, drawn with the
-- engine's own frames (no images to fetch, so it is there on the very first frame and never
-- blurry). A sky falling from night to the last of the sun, a low sun (or the moon) on the horizon
-- with its glow, a far and a near skyline with lit windows and neon on the tallest towers, the sun
-- laid across the water in broken gold, two palms in silhouette at the edges, and the lights of a
-- promenade road streaming along the foot. Each place has its own hour and colours.
--
--   local scene = Skyline.build(frame, "luxe", viewportPixels)
--   scene.step(secondsSinceShown)   -- each frame: stars, sun, clouds, water and the road move
--
-- It is built in real pixels (the screen's), so circles stay round and nothing is stretched at any
-- shape of screen; `lite` draws fewer windows, stars and lights for small or low-end devices.

local Skyline = {}

export type Palette = {
	sky: { { number | Color3 } },
	sun: Color3,
	sunEdge: Color3,
	glow: Color3,
	far: Color3,
	near: Color3,
	window: Color3,
	neon: { Color3 },
	waterTop: Color3,
	waterBottom: Color3,
	cloud: Color3,
	moon: boolean?,
}

local rgb = Color3.fromRGB

Skyline.PALETTES = {
	-- The house's own hour: the sun just going, magenta into gold.
	house = {
		sky = { { 0, rgb(12, 8, 34) }, { 0.32, rgb(46, 18, 84) }, { 0.55, rgb(150, 46, 120) }, { 0.78, rgb(246, 112, 104) }, { 1, rgb(255, 178, 118) } },
		sun = rgb(255, 236, 170),
		sunEdge = rgb(255, 134, 96),
		glow = rgb(255, 150, 110),
		far = rgb(92, 40, 104),
		near = rgb(22, 12, 38),
		window = rgb(255, 208, 140),
		neon = { rgb(255, 84, 178), rgb(96, 224, 255) },
		waterTop = rgb(120, 48, 112),
		waterBottom = rgb(10, 6, 24),
		cloud = rgb(255, 140, 170),
	},
	-- Steal a Luxe: rose and magenta, neon pink on the towers.
	luxe = {
		sky = { { 0, rgb(16, 4, 26) }, { 0.35, rgb(70, 12, 66) }, { 0.6, rgb(196, 40, 116) }, { 0.82, rgb(255, 104, 136) }, { 1, rgb(255, 160, 150) } },
		sun = rgb(255, 222, 196),
		sunEdge = rgb(255, 86, 140),
		glow = rgb(255, 90, 150),
		far = rgb(96, 26, 82),
		near = rgb(24, 6, 26),
		window = rgb(255, 190, 210),
		neon = { rgb(255, 70, 160), rgb(255, 150, 220) },
		waterTop = rgb(130, 26, 92),
		waterBottom = rgb(12, 3, 16),
		cloud = rgb(255, 120, 170),
	},
	-- The Basement: copper dusk over teal water.
	basement = {
		sky = { { 0, rgb(6, 14, 22) }, { 0.35, rgb(18, 44, 56) }, { 0.62, rgb(120, 78, 64) }, { 0.84, rgb(232, 144, 88) }, { 1, rgb(255, 196, 128) } },
		sun = rgb(255, 230, 170),
		sunEdge = rgb(240, 140, 70),
		glow = rgb(255, 168, 96),
		far = rgb(52, 60, 70),
		near = rgb(10, 18, 22),
		window = rgb(255, 196, 120),
		neon = { rgb(255, 170, 80), rgb(80, 220, 200) },
		waterTop = rgb(40, 74, 80),
		waterBottom = rgb(4, 10, 14),
		cloud = rgb(240, 160, 120),
	},
	-- The Executive Suite: full night, the moon, cold blue neon.
	executive = {
		sky = { { 0, rgb(3, 6, 22) }, { 0.38, rgb(12, 24, 70) }, { 0.66, rgb(52, 44, 132) }, { 0.86, rgb(128, 78, 180) }, { 1, rgb(190, 120, 200) } },
		sun = rgb(236, 240, 255),
		sunEdge = rgb(170, 190, 255),
		glow = rgb(140, 160, 255),
		far = rgb(40, 40, 96),
		near = rgb(6, 8, 26),
		window = rgb(170, 220, 255),
		neon = { rgb(90, 200, 255), rgb(170, 120, 255) },
		waterTop = rgb(40, 40, 110),
		waterBottom = rgb(2, 4, 14),
		cloud = rgb(150, 130, 230),
		moon = true,
	},
} :: { [string]: Palette }

export type Scene = { step: (t: number) -> (), root: Frame }

-- A little seeded generator, so a place's skyline is the same every time it's seen.
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

local function fadeSides(f: GuiObject, edge: number, middle: number, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 0
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(edge, middle),
		NumberSequenceKeypoint.new(1 - edge, middle),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
end

-- A palm in silhouette: a leaning trunk in tapering pieces and drooping fronds from its crown.
-- Returns its crown, which sways.
local function palm(parent: Instance, colour: Color3, baseX: number, baseY: number, height: number, lean: number, z: number): Frame
	local crownX, crownY = baseX + lean, baseY - height
	local pieces = 8
	for i = 1, pieces do
		local a, b = (i - 1) / pieces, i / pieces
		-- (A gentle curve: the lean comes in more towards the top.)
		local x1, y1 = baseX + lean * a * a, baseY - height * a
		local x2, y2 = baseX + lean * b * b, baseY - height * b
		local len = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2) + 2
		local width = height * (0.05 - 0.022 * a)
		local seg = frame(parent, "Trunk", colour, (x1 + x2) / 2, (y1 + y2) / 2, width, len, 0, z)
		seg.AnchorPoint = Vector2.new(0.5, 0.5)
		seg.Rotation = math.deg(math.atan2(x2 - x1, -(y2 - y1)))
		round(seg, UDim.new(0, 2))
	end
	local crown = frame(parent, "Crown", colour, crownX, crownY, 1, 1, 1, z + 1)
	crown.AnchorPoint = Vector2.new(0.5, 0.5)
	local frond = height * 0.42
	local thick = math.max(3, height * 0.05)
	for k, angle in { -168, -142, -118, -92, -66, -40, -14, 10, -190 } do
		-- Each frond in two pieces, the outer one drooping further.
		local inner = frame(crown, "Frond", colour, 0, 0, frond * 0.55, thick, 0, z + 1)
		inner.AnchorPoint = Vector2.new(0, 0.5)
		inner.Position = UDim2.fromScale(0.5, 0.5)
		inner.Rotation = angle
		round(inner)
		local droop = if math.cos(math.rad(angle)) >= 0 then 26 else -26
		local outer = frame(inner, "Tip", colour, 0, 0, frond * 0.55, thick * 0.8, 0, z + 1)
		outer.AnchorPoint = Vector2.new(0, 0.5)
		outer.Position = UDim2.new(1, -thick * 0.6, 0.5, 0)
		outer.Rotation = droop + (k % 3) * 4
		round(outer)
	end
	return crown
end

function Skyline.build(parent: Instance, place: string?, size: Vector2, lite: boolean?): Scene
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
	root.BackgroundColor3 = P.waterBottom
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.ClipsDescendants = true
	root.Parent = parent

	local horizon = math.floor(H * 0.6)
	local road = math.floor(H * 0.9)

	-- The sky, night above to the last of the sun at the horizon.
	local sky = frame(root, "Sky", Color3.new(1, 1, 1), 0, 0, W, horizon + 2, 0, 1)
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Color = sequence(P.sky)
	sg.Parent = sky

	-- Stars, only up where it's dark.
	local stars: { Frame } = {}
	for i = 1, if few then 22 else 48 do
		local d = R(1, 2.6)
		local s = frame(root, "Star", Color3.fromRGB(255, 244, 230), R(0, W), R(0, horizon * 0.45), d, d, R(0.1, 0.6), 2)
		round(s)
		table.insert(stars, s)
	end

	-- The sun (or the moon), low, with its glow and a haze along the horizon.
	local sunD = math.floor(H * (if P.moon then 0.16 else 0.3))
	local sunX = math.floor(W * 0.64)
	local sunY = if P.moon then math.floor(H * 0.2) else horizon - math.floor(sunD * 0.28)
	local glows: { Frame } = {}
	local GLOW_T = { 0.94, 0.9, 0.82 }
	for k, spec in { { 3.6, GLOW_T[1] }, { 2.4, GLOW_T[2] }, { 1.55, GLOW_T[3] } } do
		local d = sunD * spec[1]
		local g = frame(root, "Glow" .. k, P.glow, sunX, sunY, d, d, spec[2], 2)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		round(g)
		table.insert(glows, g)
	end
	local sun = frame(root, if P.moon then "Moon" else "Sun", Color3.new(1, 1, 1), sunX, sunY, sunD, sunD, 0, 3)
	sun.AnchorPoint = Vector2.new(0.5, 0.5)
	round(sun)
	local sunG = Instance.new("UIGradient")
	sunG.Rotation = 90
	sunG.Color = ColorSequence.new(P.sun, P.sunEdge)
	sunG.Parent = sun
	if P.moon then
		-- (A crescent: the night's own colour over most of the disc.)
		local bite = frame(sun, "Shadow", P.sky[2][2] :: Color3, sunD * 0.28, -sunD * 0.08, sunD, sunD, 0, 3)
		round(bite)
	end
	local haze = frame(root, "Haze", P.glow, 0, horizon - H * 0.09, W, H * 0.18, 0, 3)
	fadeSides(haze, 0.5, 0.55, 90)

	-- Long thin clouds catching the light, drifting.
	local clouds: { { f: Frame, x: number, speed: number } } = {}
	for i = 1, if few then 4 else 7 do
		local w = R(0.18, 0.42) * W
		local y = R(0.12, 0.48) * horizon
		local c = frame(root, "Cloud", P.cloud, R(-0.2, 1) * W, y, w, R(0.008, 0.022) * H, R(0.35, 0.6), 3)
		round(c)
		fadeSides(c, 0.35, 0)
		table.insert(clouds, { f = c, x = c.Position.X.Offset, speed = R(4, 12) })
	end

	-- The far skyline, faint with distance.
	local x = -R(0, 30)
	while x < W do
		local w = R(0.02, 0.05) * W
		local h = R(0.04, 0.17) * H
		frame(root, "Far", P.far, x, horizon - h, w + 1, h + 1, 0.12, 4)
		x += w
	end

	-- The near towers: darker, taller, lit windows, neon up the edges of the tallest few.
	local neonBars: { Frame } = {}
	local reflections: { Frame } = {}
	local windows = 0
	local maxWindows = if few then 90 else 220
	x = -R(0, 40)
	local tall = 0
	while x < W do
		local w = R(0.035, 0.075) * W
		local h = R(0.08, 0.36) * H
		-- (A clear sky over the sun: the towers there stay low.)
		if math.abs(x + w / 2 - sunX) < sunD * 0.6 then
			h = R(0.04, 0.1) * H
		end
		local tower = frame(root, "Tower", P.near, x, horizon - h, w + 1, h + 1, 0, 5)
		if h > H * 0.27 and tall < 4 then
			tall += 1
			-- A spire, and a neon line down one edge, laid on the water too.
			frame(tower, "Spire", P.near, w / 2 - 1, -h * 0.12, 2, h * 0.12, 0, 5)
			local colour = P.neon[(tall % #P.neon) + 1]
			local bar = frame(tower, "Neon", colour, if tall % 2 == 0 then 0 else w - 2, 0, 2, h, 0.1, 6)
			table.insert(neonBars, bar)
			for k = 0, 5 do
				local r = frame(root, "NeonOnWater", colour, x + (if tall % 2 == 0 then 0 else w - 3), horizon + 4 + k * H * 0.035, 3, H * 0.022, 0.55 + k * 0.07, 7)
				table.insert(reflections, r)
			end
		end
		-- Windows: a few columns, some lit.
		local cols = math.max(2, math.floor(w / 9))
		local rows = math.max(2, math.floor(h / 11))
		for cx = 1, cols - 1 do
			for ry = 1, rows - 1 do
				if windows < maxWindows and R(0, 1) < 0.16 then
					windows += 1
					frame(tower, "Window", P.window, cx * (w / cols) - 1, ry * (h / rows), 2, 2, R(0, 0.45), 6)
				end
			end
		end
		x += w + R(0, 0.012) * W
	end

	-- The water: the light on it at the horizon, darkening to the shore.
	local water = frame(root, "Water", Color3.new(1, 1, 1), 0, horizon, W, road - horizon, 0, 4)
	local wg = Instance.new("UIGradient")
	wg.Rotation = 90
	wg.Color = ColorSequence.new(P.waterTop, P.waterBottom)
	wg.Parent = water
	water.ZIndex = 4
	-- The sun laid across it in broken gold.
	local glints: { { f: Frame, w: number, phase: number } } = {}
	for k = 0, if few then 9 else 16 do
		local y = horizon + 4 + k * (road - horizon) / 18
		local w = sunD * (0.9 - k * 0.035) * R(0.6, 1.1)
		local g = frame(root, "Glint", P.sun, sunX, y, w, math.max(2, H * 0.006), 0.3, 7)
		g.AnchorPoint = Vector2.new(0.5, 0.5)
		round(g)
		table.insert(glints, { f = g, w = w, phase = R(0, 6.28) })
	end

	-- The promenade along the foot, its lights streaming both ways.
	local street = frame(root, "Road", Color3.fromRGB(8, 5, 14), 0, road, W, H - road + 2, 0, 8)
	frame(street, "Kerb", P.glow, 0, 0, W, 2, 0.4, 9)
	local trails: { { f: Frame, speed: number, x: number } } = {}
	for i = 1, if few then 6 else 12 do
		local leftward = i % 2 == 0
		local colour = if leftward then Color3.fromRGB(255, 244, 220) else Color3.fromRGB(255, 70, 80)
		local laneY = if leftward then (H - road) * 0.32 else (H - road) * 0.62
		local t = frame(street, "Trail", colour, R(0, W), laneY, R(0.05, 0.11) * W, math.max(2, H * 0.005), 0.05, 9)
		round(t)
		local tg = Instance.new("UIGradient")
		tg.Transparency = NumberSequence.new(if leftward then 0 else 1, if leftward then 1 else 0)
		tg.Parent = t
		table.insert(trails, { f = t, speed = (if leftward then -1 else 1) * R(0.12, 0.22) * W, x = t.Position.X.Offset })
	end

	-- Two palms at the edges, against everything.
	local ink = Color3.fromRGB(6, 3, 12)
	local crowns = {
		palm(root, ink, W * 0.04, H + 4, H * 0.86, W * 0.05, 20),
		palm(root, ink, W * 0.97, H + 4, H * 0.66, -W * 0.04, 20),
	}

	local function step(t: number)
		for i, s in stars do
			if i % 3 == math.floor(t * 6) % 3 then
				s.BackgroundTransparency = 0.25 + 0.5 * (0.5 + 0.5 * math.sin(t * 2.2 + i * 1.7))
			end
		end
		for i, g in glows do
			g.BackgroundTransparency = math.min(0.97, GLOW_T[i] + 0.02 * math.sin(t * 1.3 + i))
		end
		for _, c in clouds do
			local nx = c.x + t * c.speed
			local w = c.f.Size.X.Offset
			nx = ((nx + w) % (W + w)) - w
			c.f.Position = UDim2.fromOffset(nx, c.f.Position.Y.Offset)
		end
		for _, g in glints do
			local k = 0.5 + 0.5 * math.sin(t * 2.4 + g.phase)
			g.f.Size = UDim2.fromOffset(g.w * (0.75 + 0.35 * k), g.f.Size.Y.Offset)
			g.f.BackgroundTransparency = 0.2 + 0.45 * (1 - k)
		end
		for i, r in reflections do
			r.BackgroundTransparency = math.clamp(0.55 + (i % 6) * 0.07 + 0.12 * math.sin(t * 3 + i), 0, 1)
		end
		for i, b in neonBars do
			b.BackgroundTransparency = 0.05 + 0.15 * (0.5 + 0.5 * math.sin(t * 1.8 + i * 2))
		end
		for _, tr in trails do
			local w = tr.f.Size.X.Offset
			local nx = ((tr.x + tr.speed * t + w) % (W + w)) - w
			tr.f.Position = UDim2.fromOffset(nx, tr.f.Position.Y.Offset)
		end
		for i, c in crowns do
			c.Rotation = math.sin(t * 0.9 + i * 1.4) * 2.5
		end
	end

	return { step = step, root = root }
end

return Skyline

--!strict
-- Decoration: rugs, lamps, paintings, chandeliers, plants, sculptures, mirrors, display cases and
-- an aquarium. (Each kind's designs are picked by style.model.)

return function(F: any)
	local L = F.Looks
	local box, cyl, post, ball, disc = F.box, F.cyl, F.post, F.ball, F.disc
	local trim, soft = F.trim, F.soft
	local rgb = Color3.fromRGB
	local look = F.look
	local rad = math.rad

	-- A hoop of `radius` at height `y`: short straight lengths around a circle (a cylinder part
	-- would be a solid disc).
	local function hoop(b: any, name: string, radius: number, y: number, thick: number, lk: any, n: number?)
		local count = n or 16
		local len = 2 * math.pi * radius / count + 0.02
		for i = 0, count - 1 do
			local a = (i + 0.5) / count * math.pi * 2
			box(b, name, Vector3.new(thick, thick, len), CFrame.new(math.cos(a) * radius, y, math.sin(a) * radius) * CFrame.Angles(0, -a, 0), lk, trim)
		end
	end

	-------------------------------------------------------------------------------------------
	-- Rugs: laid in layers a fiftieth of a stud apart, so no two ever lie in one plane.
	-------------------------------------------------------------------------------------------
	local function layer(b: any, name: string, w: number, d: number, n: number, c: Color3, rot: number?)
		local mat = Enum.Material.Fabric
		box(b, name, Vector3.new(w, 0.02, d), CFrame.new(0, 0.01 + n * 0.02, 0) * CFrame.Angles(0, rad(rot or 0), 0), look(c, mat), trim)
	end
	local function frameOf(b: any, name: string, w: number, d: number, t: number, n: number, c: Color3)
		local y = 0.01 + n * 0.02
		local lk = look(c, Enum.Material.Fabric)
		box(b, name, Vector3.new(w, 0.02, t), CFrame.new(0, y, -d / 2 + t / 2), lk, trim)
		box(b, name, Vector3.new(w, 0.02, t), CFrame.new(0, y, d / 2 - t / 2), lk, trim)
		box(b, name, Vector3.new(t, 0.02, d - 2 * t), CFrame.new(-w / 2 + t / 2, y, 0), lk, trim)
		box(b, name, Vector3.new(t, 0.02, d - 2 * t), CFrame.new(w / 2 - t / 2, y, 0), lk, trim)
	end
	F.define("rug", "The rug", function(b: any, st: any)
		local field = F.colour(st, "colour", rgb(96, 24, 28))
		local accent = F.colour(st, "accent", rgb(196, 150, 80))
		local w, d = st.width or 12, st.depth or 8
		local model = st.model or "persian"
		if model == "round" then
			disc(b, "Rug", math.min(w, d) + 0.6, 0.02, Vector3.new(0, 0.01, 0), look(accent, Enum.Material.Fabric), trim)
			disc(b, "RugField", math.min(w, d), 0.02, Vector3.new(0, 0.03, 0), look(field, Enum.Material.Fabric), trim)
			disc(b, "RugRing", math.min(w, d) * 0.62, 0.02, Vector3.new(0, 0.05, 0), look(accent:Lerp(field, 0.45), Enum.Material.Fabric), trim)
			disc(b, "RugHeart", math.min(w, d) * 0.5, 0.02, Vector3.new(0, 0.07, 0), look(field:Lerp(rgb(0, 0, 0), 0.15), Enum.Material.Fabric), trim)
			return
		end
		layer(b, "Rug", w, d, 0, accent)
		layer(b, "RugField", w - 0.6, d - 0.6, 1, field)
		if model == "persian" then
			frameOf(b, "RugBorder", w - 1.4, d - 1.4, 0.35, 2, accent:Lerp(field, 0.35))
			layer(b, "Medallion", 2.6, 2.6, 2, accent, 45)
			layer(b, "MedallionHeart", 1.6, 1.6, 3, field:Lerp(rgb(20, 10, 10), 0.3), 45)
			layer(b, "MedallionEye", 0.7, 0.7, 4, accent, 45)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local x, z = sx * (w / 2 - 1.6), sz * (d / 2 - 1.6)
					box(b, "Corner", Vector3.new(0.9, 0.02, 0.9), CFrame.new(x, 0.07, z) * CFrame.Angles(0, rad(45), 0), look(accent, Enum.Material.Fabric), trim)
				end
			end
			-- The fringe at either end.
			for _, sx in { -1, 1 } do
				box(b, "Fringe", Vector3.new(0.3, 0.015, d - 0.4), CFrame.new(sx * (w / 2 + 0.15), 0.008, 0), look(rgb(230, 220, 196), Enum.Material.Fabric), trim)
			end
		elseif model == "stripe" then
			local n = 7
			for i = 1, n do
				if i % 2 == 0 then
					box(b, "Stripe", Vector3.new(w - 0.6, 0.02, (d - 0.6) / n), CFrame.new(0, 0.05, -(d - 0.6) / 2 + (i - 0.5) * (d - 0.6) / n), look(accent:Lerp(field, 0.3), Enum.Material.Fabric), trim)
				end
			end
		elseif model == "deco" then
			frameOf(b, "RugBorder", w - 1.2, d - 1.2, 0.18, 2, accent)
			frameOf(b, "RugBorder2", w - 2, d - 2, 0.1, 2, accent)
			for i = -2, 2 do
				box(b, "Fan", Vector3.new(0.12, 0.02, 2.4), CFrame.new(0, 0.07, 0) * CFrame.Angles(0, rad(i * 22), 0) * CFrame.new(0, 0, 1.2), look(accent, Enum.Material.Fabric), trim)
			end
		else
			frameOf(b, "RugBorder", w - 1.2, d - 1.2, 0.2, 2, accent)
		end
	end)

	-------------------------------------------------------------------------------------------
	-- Floor lamps
	-------------------------------------------------------------------------------------------
	F.define("lamp", "The lamp", function(b: any, st: any)
		local shadeC = F.colour(st, "colour", rgb(236, 214, 170))
		local metal = look(F.colour(st, "accent", rgb(170, 132, 64)), Enum.Material.Metal, 0.2)
		local model = st.model or "brass"
		local warm = rgb(255, 206, 150)
		if model == "arc" then
			disc(b, "Base", 1.4, 0.35, Vector3.new(0, 0.18, 0), L.whiteMarble)
			-- The arc: up from the pole, bowing forward until it hangs its shade over whatever
			-- stands in front.
			post(b, "Pole", 4.4, 0.14, Vector3.new(0, 0.35, 0), metal, soft)
			local at = Vector3.new(0, 4.75, 0)
			local step = 0.75
			for i = 0, 7 do
				local phi = rad(5 + i * 14)
				local dir = Vector3.new(0, math.cos(phi), -math.sin(phi))
				local mid = at + dir * step / 2
				box(b, "Arc", Vector3.new(0.13, 0.13, step + 0.05), CFrame.lookAt(mid, mid + dir), metal, trim)
				at += dir * step
			end
			ball(b, "Shade", 1.5, at + Vector3.new(0, -0.45, 0), look(metal.color, Enum.Material.Metal, 0.25), trim)
			local bulb = ball(b, "Bulb", 0.6, at + Vector3.new(0, -1.05, 0), L.warmGlow, trim)
			F.spotLight(b, bulb, Enum.NormalId.Bottom, 1.6, 16, 70, warm)
		elseif model == "tripod" then
			for i = 0, 2 do
				local a = rad(i * 120)
				local foot = Vector3.new(math.cos(a) * 0.9, 0, math.sin(a) * 0.9)
				local top = Vector3.new(0, 4.2, 0)
				local mid = (foot + top) / 2
				local len = (top - foot).Magnitude
				box(b, "Leg", Vector3.new(0.12, len, 0.12), CFrame.lookAt(mid, top) * CFrame.Angles(rad(90), 0, 0), F.Looks.walnut, soft)
			end
			local shade = cyl(b, "Shade", 1.4, 1.9, CFrame.new(0, 4.9, 0) * CFrame.Angles(0, 0, rad(90)), look(shadeC, Enum.Material.Fabric, nil, 0.08), trim)
			F.light(b, shade, 1.1, 14, warm)
		elseif model == "crystal" then
			disc(b, "Base", 1.1, 0.2, Vector3.new(0, 0.1, 0), metal)
			for i = 1, 5 do
				ball(b, "Crystal", 0.75 - i * 0.04, Vector3.new(0, 0.2 + i * 0.7, 0), L.glass, trim)
			end
			post(b, "Stem", 4, 0.1, Vector3.new(0, 0.2, 0), metal, trim)
			local shade = cyl(b, "Shade", 1.1, 1.6, CFrame.new(0, 4.8, 0) * CFrame.Angles(0, 0, rad(90)), look(shadeC, Enum.Material.Fabric, nil, 0.06), trim)
			F.light(b, shade, 1, 13, rgb(240, 236, 255))
		else -- brass, with a pleated silk shade
			disc(b, "Base", 1.2, 0.22, Vector3.new(0, 0.11, 0), metal)
			post(b, "Pole", 4.4, 0.16, Vector3.new(0, 0.22, 0), metal, soft)
			disc(b, "Collar", 0.36, 0.2, Vector3.new(0, 2.4, 0), metal, trim)
			local shade = cyl(b, "Shade", 1.5, 1.8, CFrame.new(0, 5.1, 0) * CFrame.Angles(0, 0, rad(90)), look(shadeC, Enum.Material.Fabric, nil, 0.08), trim)
			for i = 0, 11 do
				local a = rad(i * 30)
				box(b, "Pleat", Vector3.new(0.04, 1.5, 0.05), CFrame.new(math.cos(a) * 0.9, 5.1, math.sin(a) * 0.9) * CFrame.Angles(0, -a, 0), look(shadeC:Lerp(rgb(0, 0, 0), 0.12), Enum.Material.Fabric), trim)
			end
			F.light(b, shade, 1.1, 14, warm)
		end
	end)

	-------------------------------------------------------------------------------------------
	-- Paintings: a gilt frame and a canvas, its picture laid in coloured shapes. The frame hangs
	-- with its back on the wall at the piece's origin, centred on it.
	-------------------------------------------------------------------------------------------
	local function canvasShape(b: any, name: string, w: number, h: number, x: number, y: number, n: number, c: Color3, rot: number?)
		-- n: how far in front of the canvas (in layers of a fiftieth of a stud)
		box(b, name, Vector3.new(w, h, 0.02), CFrame.new(x, y, -0.17 - n * 0.02) * CFrame.Angles(0, 0, rad(rot or 0)), look(c, Enum.Material.SmoothPlastic), trim)
	end
	local function round(b: any, name: string, d: number, x: number, y: number, n: number, c: Color3)
		cyl(b, name, 0.02, d, CFrame.new(x, y, -0.17 - n * 0.02) * CFrame.Angles(0, rad(90), 0), look(c, Enum.Material.SmoothPlastic), trim)
	end
	F.define("painting", "The painting", function(b: any, st: any)
		local w, h = st.width or 5.6, st.height or 4
		local gold = look(F.colour(st, "accent", rgb(198, 160, 82)), Enum.Material.Metal, 0.22)
		local lip = look(gold.color:Lerp(rgb(40, 30, 10), 0.35), Enum.Material.Metal, 0.1)
		local base = F.colour(st, "colour", rgb(30, 34, 60))
		box(b, "Backing", Vector3.new(w + 0.7, h + 0.7, 0.12), CFrame.new(0, 0, -0.06), gold, soft)
		box(b, "Canvas", Vector3.new(w, h, 0.04), CFrame.new(0, 0, -0.14), look(base, Enum.Material.SmoothPlastic), trim)
		-- The moulding stands proud of the canvas all round, a darker lip inside it.
		for _, sy in { -1, 1 } do
			box(b, "Moulding", Vector3.new(w + 0.7, 0.35, 0.34), CFrame.new(0, sy * (h / 2 + 0.175), -0.17), gold, soft)
			box(b, "Lip", Vector3.new(w, 0.08, 0.06), CFrame.new(0, sy * (h / 2 - 0.04), -0.2), lip, trim)
		end
		for _, sx in { -1, 1 } do
			box(b, "Moulding", Vector3.new(0.35, h, 0.34), CFrame.new(sx * (w / 2 + 0.175), 0, -0.17), gold, soft)
			box(b, "Lip", Vector3.new(0.08, h - 0.16, 0.06), CFrame.new(sx * (w / 2 - 0.04), 0, -0.2), lip, trim)
		end
		local art = st.art or "night"
		if art == "night" then
			-- The city at three: a deepening sky, a moon, roofs with a few lit windows.
			canvasShape(b, "Sky", w, h * 0.4, 0, h * 0.3, 1, base:Lerp(rgb(80, 90, 140), 0.35))
			round(b, "Moon", h * 0.18, w * 0.28, h * 0.28, 2, rgb(240, 230, 200))
			local x = -w / 2
			local i = 0
			while x < w / 2 - 0.3 do
				i += 1
				local bw = 0.5 + ((i * 37) % 5) * 0.12
				local bh = h * (0.25 + ((i * 53) % 7) * 0.05)
				bw = math.min(bw, w / 2 - x)
				canvasShape(b, "Building", bw, bh, x + bw / 2, -h / 2 + bh / 2, 3, rgb(14, 14, 22))
				if i % 2 == 1 then
					canvasShape(b, "Window", 0.12, 0.12, x + bw / 2, -h / 2 + bh * 0.7, 4, rgb(255, 210, 120))
				end
				x += bw + 0.04
			end
		elseif art == "portrait" then
			canvasShape(b, "Ground", w, h, 0, 0, 1, base:Lerp(rgb(10, 8, 6), 0.4))
			canvasShape(b, "Shoulders", w * 0.62, h * 0.32, 0, -h * 0.34, 2, F.colour(st, "dress", rgb(20, 20, 26)))
			canvasShape(b, "Neck", w * 0.1, h * 0.14, 0, -h * 0.12, 3, rgb(214, 176, 146))
			round(b, "Face", h * 0.3, 0, h * 0.08, 3, rgb(222, 186, 156))
			round(b, "Hair", h * 0.34, 0, h * 0.14, 2, F.colour(st, "hair", rgb(40, 26, 18)))
			canvasShape(b, "Collar", w * 0.2, h * 0.05, 0, -h * 0.2, 4, rgb(236, 230, 214))
		elseif art == "abstract" then
			canvasShape(b, "FieldA", w * 0.86, h * 0.42, 0, h * 0.2, 1, F.colour(st, "a", rgb(170, 60, 40)))
			canvasShape(b, "FieldB", w * 0.86, h * 0.34, 0, -h * 0.24, 1, F.colour(st, "b", rgb(40, 40, 70)))
			canvasShape(b, "Line", w * 0.86, h * 0.03, 0, -h * 0.02, 2, rgb(230, 200, 120))
		elseif art == "landscape" then
			canvasShape(b, "Sky", w, h * 0.55, 0, h * 0.22, 1, rgb(206, 164, 120))
			round(b, "Sun", h * 0.22, -w * 0.2, h * 0.08, 2, rgb(250, 214, 150))
			canvasShape(b, "HillA", w * 0.8, h * 0.5, -w * 0.18, -h * 0.28, 3, rgb(70, 86, 60), 8)
			canvasShape(b, "HillB", w * 0.8, h * 0.5, w * 0.22, -h * 0.32, 4, rgb(52, 66, 46), -6)
			canvasShape(b, "Water", w, h * 0.16, 0, -h * 0.42, 5, rgb(90, 110, 130))
		elseif art == "still" then
			canvasShape(b, "Ground", w, h, 0, 0, 1, base:Lerp(rgb(0, 0, 0), 0.3))
			canvasShape(b, "Table", w, h * 0.24, 0, -h * 0.38, 2, rgb(70, 44, 28))
			canvasShape(b, "Vase", w * 0.16, h * 0.34, 0, -h * 0.12, 3, rgb(40, 80, 110))
			for i, c in { rgb(220, 60, 70), rgb(240, 200, 90), rgb(240, 236, 230), rgb(190, 90, 140), rgb(220, 120, 60) } do
				local a = rad(-60 + i * 22)
				round(b, "Bloom", h * 0.13, math.cos(a + rad(90)) * w * 0.14, h * 0.12 + math.sin(a + rad(90)) * h * 0.06, 4, c)
			end
		end
		-- A picture light above, lighting the canvas.
		local bar = cyl(b, "PictureLight", w * 0.6, 0.22, CFrame.new(0, h / 2 + 0.55, -0.55), gold, trim)
		F.spotLight(b, bar, Enum.NormalId.Bottom, 0.9, 7, 70, rgb(255, 214, 160))
		box(b, "PictureLightArm", Vector3.new(0.08, 0.08, 0.5), CFrame.new(0, h / 2 + 0.55, -0.3), gold, trim)
	end)

	-------------------------------------------------------------------------------------------
	-- Chandeliers: built hanging from the ceiling at the piece's origin, downward.
	-------------------------------------------------------------------------------------------
	F.define("chandelier", "The chandelier", function(b: any, st: any)
		local metal = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		local model = st.model or "ring"
		local drop = st.drop or 2.6
		local warm = rgb(255, 212, 160)
		disc(b, "Canopy", 1.2, 0.2, Vector3.new(0, -0.1, 0), metal, trim)
		post(b, "Chain", drop, 0.08, Vector3.new(0, -drop, 0), metal, trim)
		local y = -drop
		if model == "crystal" then
			post(b, "Column", 2.4, 0.3, Vector3.new(0, y - 2.4, 0), metal, trim)
			for tier = 1, 3 do
				local r = 0.7 + tier * 0.55
				local ty = y - 0.4 - tier * 0.6
				hoop(b, "Ring", r, ty, 0.1, metal, 8 + tier * 4)
				local n = 4 + tier * 3
				for i = 1, n do
					local a = rad(i * 360 / n + tier * 12)
					ball(b, "Drop", 0.28, Vector3.new(math.cos(a) * r, ty - 0.35, math.sin(a) * r), look(rgb(236, 244, 255), Enum.Material.Glass, 0.3, 0.25), trim)
					if tier == 3 and i % 2 == 0 then
						ball(b, "Candle", 0.22, Vector3.new(math.cos(a) * r, ty + 0.2, math.sin(a) * r), L.warmGlow, trim)
					end
				end
			end
			local heart = ball(b, "Heart", 0.8, Vector3.new(0, y - 2.2, 0), look(rgb(236, 244, 255), Enum.Material.Glass, 0.35, 0.2), trim)
			F.light(b, heart, 1.4, 26, warm)
		elseif model == "sputnik" then
			local centre = Vector3.new(0, y - 0.6, 0)
			local core = ball(b, "Core", 0.9, centre, metal, trim)
			for i = 1, 14 do
				local a = rad(i * 137.5)
				local up = ((i % 5) - 2) * 0.35
				local dir = Vector3.new(math.cos(a), up, math.sin(a)).Unit
				local tip = centre + dir * 1.8
				box(b, "Rod", Vector3.new(0.06, 0.06, 1.8), CFrame.lookAt((centre + tip) / 2, tip), metal, trim)
				ball(b, "Bulb", 0.32, tip, L.warmGlow, trim)
			end
			F.light(b, core, 1.3, 24, warm)
		elseif model == "cascade" then
			for i = 1, 16 do
				local a = rad(i * 360 / 16)
				local r = 0.6 + (i % 3) * 0.45
				local len = 1.2 + ((i * 7) % 5) * 0.4
				box(b, "Strand", Vector3.new(0.03, len, 0.03), CFrame.new(math.cos(a) * r, y - len / 2, math.sin(a) * r), metal, trim)
				ball(b, "Bead", 0.3, Vector3.new(math.cos(a) * r, y - len - 0.1, math.sin(a) * r), look(rgb(236, 244, 255), Enum.Material.Glass, 0.3, 0.2), trim)
			end
			disc(b, "Crown", 2.6, 0.12, Vector3.new(0, y, 0), metal, trim)
			local glow = disc(b, "Glow", 2.2, 0.06, Vector3.new(0, y - 0.08, 0), L.warmGlow, trim)
			F.light(b, glow, 1.3, 24, warm)
		else -- a brass ring of candles
			local r = 1.6
			hoop(b, "Ring", r, y - 0.4, 0.14, metal, 16)
			for i = 1, 8 do
				local a = rad(i * 45)
				local p = Vector3.new(math.cos(a) * r, y - 0.4, math.sin(a) * r)
				box(b, "Arm", Vector3.new(0.06, 0.06, r), CFrame.lookAt(Vector3.new(0, y - 0.4, 0):Lerp(p, 0.5), p), metal, trim)
				post(b, "Candle", 0.5, 0.14, p + Vector3.new(0, 0.05, 0), L.paper, trim)
				ball(b, "Flame", 0.16, p + Vector3.new(0, 0.65, 0), L.warmGlow, trim)
			end
			local hub = ball(b, "Hub", 0.5, Vector3.new(0, y - 0.4, 0), metal, trim)
			F.light(b, hub, 1.2, 22, warm)
			-- Crystal: a drop under each arm, a lower ring of drops, and a heart under the hub.
			local glass = look(rgb(236, 244, 255), Enum.Material.Glass, 0.35, 0.25)
			for i = 1, 8 do
				local a = rad(i * 45 + 22.5)
				post(b, "DropWire", 0.4, 0.02, Vector3.new(math.cos(a) * r, y - 0.8, math.sin(a) * r), metal, trim)
				ball(b, "Drop", 0.22, Vector3.new(math.cos(a) * r, y - 0.9, math.sin(a) * r), glass, trim)
			end
			hoop(b, "LowerRing", r * 0.55, y - 1.1, 0.08, metal, 12)
			for i = 1, 6 do
				local a = rad(i * 60)
				ball(b, "Drop", 0.2, Vector3.new(math.cos(a) * r * 0.55, y - 1.35, math.sin(a) * r * 0.55), glass, trim)
			end
			ball(b, "Heart", 0.5, Vector3.new(0, y - 1.25, 0), glass, trim)
		end
	end)

	-------------------------------------------------------------------------------------------
	-- Plants
	-------------------------------------------------------------------------------------------
	local function pot(b: any, st: any, d: number, h: number): number
		local potC = st.pot
		local lk = if typeof(potC) == "Color3" then look(potC, Enum.Material.SmoothPlastic, 0.1) else L.blackLacquer
		post(b, "Pot", h, d, Vector3.zero, lk)
		disc(b, "PotRim", d + 0.12, 0.12, Vector3.new(0, h - 0.06, 0), lk, trim)
		disc(b, "Soil", d - 0.1, 0.04, Vector3.new(0, h - 0.1, 0), L.soil, trim)
		return h
	end
	F.define("plant", "The plant", function(b: any, st: any)
		local model = st.model or "palm"
		local leaf = look(F.colour(st, "colour", rgb(52, 96, 56)), Enum.Material.Grass)
		if model == "olive" then
			local top = pot(b, st, 1.8, 1.6)
			for i, lean in { -8, 6, 0 } do
				box(b, "Trunk", Vector3.new(0.18, 3.4, 0.18), CFrame.new((i - 2) * 0.12, top + 1.7, 0) * CFrame.Angles(0, 0, rad(lean)), L.walnut, soft)
			end
			local olive = look(rgb(110, 130, 96), Enum.Material.Grass)
			for _, p in { Vector3.new(0, 5.3, 0), Vector3.new(0.8, 4.8, 0.3), Vector3.new(-0.7, 4.9, -0.4), Vector3.new(0.2, 4.6, 0.8), Vector3.new(-0.3, 5.6, 0.5) } do
				ball(b, "Canopy", 1.7, p, olive, soft)
			end
		elseif model == "fiddle" then
			local top = pot(b, st, 1.5, 1.4)
			post(b, "Stem", 4.2, 0.14, Vector3.new(0, top, 0), L.walnut, soft)
			for i = 1, 11 do
				local a = rad(i * 137.5)
				local y = top + 1.4 + i * 0.28
				local out = 0.55
				box(b, "Leaf", Vector3.new(0.9, 0.05, 1.1), CFrame.new(math.cos(a) * out, y, math.sin(a) * out) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, rad(-30)), if i % 3 == 0 then L.darkLeaf else leaf, trim)
			end
		elseif model == "topiary" then
			local top = pot(b, st, 1.4, 1.3)
			post(b, "Stem", 2.6, 0.14, Vector3.new(0, top, 0), L.walnut, soft)
			ball(b, "Ball", 1.7, Vector3.new(0, top + 1.6, 0), L.darkLeaf, soft)
			ball(b, "Ball", 1.3, Vector3.new(0, top + 3, 0), L.darkLeaf, soft)
		elseif model == "orchid" then
			local top = pot(b, st, 0.7, 0.6)
			post(b, "Stem", 1.4, 0.04, Vector3.new(0, top, 0), L.darkLeaf, trim)
			for i = 1, 5 do
				ball(b, "Bloom", 0.28, Vector3.new(0.1 + i * 0.08, top + 1.0 + i * 0.12, 0), look(F.colour(st, "bloom", rgb(236, 210, 230)), Enum.Material.SmoothPlastic), trim)
			end
			for i = 0, 2 do
				box(b, "Leaf", Vector3.new(0.7, 0.03, 0.25), CFrame.new(0, top + 0.1, 0) * CFrame.Angles(0, rad(i * 120), 0) * CFrame.new(0.3, 0, 0), L.darkLeaf, trim)
			end
		else -- a palm in a tall planter, gilded at the rim and the foot
			local top = pot(b, st, 1.7, 1.9)
			local gilt = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.3)
			disc(b, "PlanterRim", 1.86, 0.12, Vector3.new(0, top - 0.02, 0), gilt, trim)
			disc(b, "PlanterFoot", 1.8, 0.16, Vector3.new(0, 0.08, 0), gilt, trim)
			disc(b, "PlanterBand", 1.74, 0.08, Vector3.new(0, top * 0.55, 0), gilt, trim)
			for i, spec in { { h = 3.4, lean = -9, x = -0.3 }, { h = 4.2, lean = 3, x = 0 }, { h = 2.8, lean = 12, x = 0.32 }, { h = 3.7, lean = -3, x = 0.12 }, { h = 3.0, lean = 7, x = -0.14 } } do
				local trunk = CFrame.new(spec.x, top, (i % 2) * 0.18 - 0.09) * CFrame.Angles(0, 0, rad(spec.lean))
				box(b, "Trunk", Vector3.new(0.13, spec.h, 0.13), trunk * CFrame.new(0, spec.h / 2, 0), L.walnut, soft)
				local crown = trunk * CFrame.new(0, spec.h, 0)
				for j = 0, 6 do
					local a = rad(j * 360 / 7 + i * 23)
					-- Each frond arches out, then droops: two lengths of leaf, the outer bent down.
					local inner = crown * CFrame.Angles(0, a, 0) * CFrame.Angles(rad(22), 0, 0)
					box(b, "Frond", Vector3.new(0.55, 0.04, 1.4), inner * CFrame.new(0, 0, -0.7), if j % 2 == 0 then leaf else L.darkLeaf, trim)
					box(b, "Frond", Vector3.new(0.48, 0.04, 1.3), inner * CFrame.new(0, 0, -1.35) * CFrame.Angles(rad(30), 0, 0) * CFrame.new(0, 0, -0.6), if j % 2 == 0 then L.darkLeaf else leaf, trim)
				end
			end
		end
	end)

	-------------------------------------------------------------------------------------------
	-- Sculpture on a plinth
	-------------------------------------------------------------------------------------------
	F.define("sculpture", "The sculpture", function(b: any, st: any)
		local model = st.model or "bust"
		local plinth = if st.plinth == "black" then L.blackMarble else L.whiteMarble
		box(b, "Plinth", Vector3.new(1.6, 3.4, 1.6), CFrame.new(0, 1.7, 0), plinth)
		box(b, "PlinthCap", Vector3.new(1.8, 0.16, 1.8), CFrame.new(0, 3.48, 0), plinth, trim)
		box(b, "PlinthFoot", Vector3.new(1.8, 0.2, 1.8), CFrame.new(0, 0.1, 0), plinth, trim)
		local y = 3.56
		local mat = look(F.colour(st, "colour", rgb(232, 226, 214)), if st.metal then Enum.Material.Metal else Enum.Material.Marble, if st.metal then 0.3 else 0.05)
		if model == "sphere" then
			ball(b, "Sphere", 1.5, Vector3.new(0, y + 0.8, 0), mat)
			disc(b, "Seat", 0.6, 0.1, Vector3.new(0, y + 0.05, 0), mat, trim)
		elseif model == "twist" then
			for i = 0, 7 do
				box(b, "Turn", Vector3.new(0.9 - i * 0.06, 0.32, 0.9 - i * 0.06), CFrame.new(0, y + 0.16 + i * 0.33, 0) * CFrame.Angles(0, rad(i * 12), 0), mat)
			end
		elseif model == "wave" then
			for i = 0, 5 do
				box(b, "Ribbon", Vector3.new(0.08, 1.6, 0.5), CFrame.new(-0.5 + i * 0.2, y + 0.8 + math.sin(i) * 0.2, 0) * CFrame.Angles(rad(i * 14), rad(i * 9), 0), mat, trim)
			end
		else -- a classical bust
			box(b, "Socle", Vector3.new(0.6, 0.3, 0.6), CFrame.new(0, y + 0.15, 0), mat)
			box(b, "Chest", Vector3.new(1.3, 0.8, 0.6), CFrame.new(0, y + 0.7, 0), mat)
			for _, x in { -0.62, 0.62 } do
				ball(b, "Shoulder", 0.62, Vector3.new(x, y + 0.85, 0), mat)
			end
			post(b, "Neck", 0.4, 0.34, Vector3.new(0, y + 1.05, 0), mat)
			ball(b, "Head", 0.82, Vector3.new(0, y + 1.75, 0), mat)
			ball(b, "Hair", 0.86, Vector3.new(0, y + 1.86, 0.08), mat)
			box(b, "Nose", Vector3.new(0.08, 0.16, 0.1), CFrame.new(0, y + 1.72, -0.4), mat, trim)
		end
	end)

	-------------------------------------------------------------------------------------------
	-- A tall mirror in a frame (its back to the wall)
	-------------------------------------------------------------------------------------------
	F.define("mirror", "The glass", function(b: any, st: any)
		local frameLk = look(F.colour(st, "accent", rgb(198, 160, 82)), Enum.Material.Metal, 0.25)
		local model = st.model or "pier"
		if model == "round" then
			cyl(b, "Frame", 0.2, 4.4, CFrame.new(0, 5, -0.1) * CFrame.Angles(0, rad(90), 0), frameLk)
			cyl(b, "Glass", 0.06, 4, CFrame.new(0, 5, -0.22) * CFrame.Angles(0, rad(90), 0), L.mirror, trim)
		else
			box(b, "Frame", Vector3.new(3.4, 8.4, 0.25), CFrame.new(0, 4.5, -0.12), frameLk)
			box(b, "Glass", Vector3.new(2.9, 7.8, 0.05), CFrame.new(0, 4.5, -0.27), L.mirror, trim)
			box(b, "Crest", Vector3.new(1.6, 0.6, 0.3), CFrame.new(0, 8.9, -0.12), frameLk, trim)
			ball(b, "Finial", 0.4, Vector3.new(0, 9.4, -0.12), frameLk, trim)
		end
	end)

	-------------------------------------------------------------------------------------------
	-- A lit glass display case for collectables (its shelves hold them: DisplayShelf1..3).
	-------------------------------------------------------------------------------------------
	F.define("display", "The display case", function(b: any, st: any)
		local wood = F.tint(st.colour or rgb(24, 18, 16), "Wood", Enum.Material.Wood)
		local metal = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		local w, d, h = 4.4, 1.6, 7
		box(b, "Plinth", Vector3.new(w, 1.2, d), CFrame.new(0, 0.6, 0), wood)
		box(b, "Crown", Vector3.new(w + 0.2, 0.4, d + 0.2), CFrame.new(0, h - 0.2, 0), wood)
		box(b, "Back", Vector3.new(w, h - 1.6, 0.12), CFrame.new(0, (h + 0.8) / 2, d / 2 - 0.06), look(rgb(30, 22, 20), Enum.Material.Fabric))
		for _, x in { -w / 2 + 0.08, w / 2 - 0.08 } do
			box(b, "Post", Vector3.new(0.16, h - 1.6, 0.16), CFrame.new(x, (h + 0.8) / 2, -d / 2 + 0.08), metal)
		end
		box(b, "Front", Vector3.new(w - 0.3, h - 1.6, 0.05), CFrame.new(0, (h + 0.8) / 2, -d / 2 + 0.05), L.glass, soft)
		for _, x in { -w / 2 + 0.03, w / 2 - 0.03 } do
			box(b, "Side", Vector3.new(0.05, h - 1.6, d - 0.3), CFrame.new(x, (h + 0.8) / 2, 0.02), L.glass, soft)
		end
		for i = 1, 3 do
			local y = 1.2 + i * 1.5
			local shelf = box(b, "DisplayShelf" .. i, Vector3.new(w - 0.3, 0.08, d - 0.3), CFrame.new(0, y, 0.02), L.glass, trim)
			shelf:SetAttribute("Shelf", i)
		end
		local glow = box(b, "CaseLight", Vector3.new(w - 0.5, 0.06, 0.2), CFrame.new(0, h - 0.47, -0.3), L.warmGlow, trim)
		F.spotLight(b, glow, Enum.NormalId.Bottom, 1.1, 8, 90, rgb(255, 230, 200))
	end)

	-------------------------------------------------------------------------------------------
	-- A wall aquarium: glass, water, sand, rock and coral, and fish (Fish1..n; a guest's screen
	-- swims them).
	-------------------------------------------------------------------------------------------
	F.define("aquarium", "The aquarium", function(b: any, st: any)
		local w, h, d = 9, 4.6, 1.8
		local y0 = 2.2
		box(b, "Cabinet", Vector3.new(w + 0.4, y0, d + 0.3), CFrame.new(0, y0 / 2, 0), L.blackLacquer)
		box(b, "Hood", Vector3.new(w + 0.4, 0.6, d + 0.3), CFrame.new(0, y0 + h + 0.3, 0), L.blackLacquer)
		box(b, "BackPanel", Vector3.new(w, h, 0.1), CFrame.new(0, y0 + h / 2, d / 2 - 0.05), look(rgb(10, 40, 70), Enum.Material.SmoothPlastic))
		box(b, "Water", Vector3.new(w - 0.1, h - 0.3, d - 0.2), CFrame.new(0, y0 + (h - 0.3) / 2, 0), look(rgb(60, 140, 190), Enum.Material.Glass, 0.1, 0.72), soft)
		box(b, "Glass", Vector3.new(w, h, 0.06), CFrame.new(0, y0 + h / 2, -d / 2 + 0.03), look(rgb(210, 230, 240), Enum.Material.Glass, 0.25, 0.85), soft)
		box(b, "Sand", Vector3.new(w - 0.1, 0.4, d - 0.2), CFrame.new(0, y0 + 0.2, 0), look(rgb(226, 206, 160), Enum.Material.Sand), trim)
		for i, p in { Vector3.new(-3, 0.7, 0.3), Vector3.new(-2.2, 0.55, 0.4), Vector3.new(2.6, 0.8, 0.2), Vector3.new(3.4, 0.6, 0.4) } do
			ball(b, "Rock", 0.6 + (i % 2) * 0.3, p + Vector3.new(0, y0, 0), L.stone, trim)
		end
		for i, c in { rgb(240, 110, 120), rgb(250, 170, 90), rgb(170, 110, 220), rgb(240, 120, 160) } do
			for j = 0, 2 do
				ball(b, "Coral", 0.3, Vector3.new(-1 + i * 0.9, y0 + 0.5 + j * 0.25, 0.4 + (j % 2) * 0.1), look(c, Enum.Material.SmoothPlastic), trim)
			end
		end
		for i = 1, 7 do
			local c = ({ rgb(255, 150, 40), rgb(60, 160, 255), rgb(255, 230, 80), rgb(240, 80, 90) })[(i % 4) + 1]
			local fish = box(b, "Fish" .. i, Vector3.new(0.4, 0.22, 0.1), CFrame.new(-3.6 + i * 1.0, y0 + 1.2 + (i % 3) * 0.9, -0.2 + (i % 2) * 0.4), look(c, Enum.Material.SmoothPlastic), trim)
			fish:SetAttribute("Fish", i)
		end
		local lamp = box(b, "TankLight", Vector3.new(w - 0.4, 0.08, 0.3), CFrame.new(0, y0 + h - 0.1, 0), L.coolGlow, trim)
		F.spotLight(b, lamp, Enum.NormalId.Bottom, 1.2, 8, 100, rgb(170, 215, 255))
	end)
end

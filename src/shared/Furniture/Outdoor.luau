--!strict
-- Out on the roof: a raised pool with glass sides, a hot tub, sun loungers under a parasol, a
-- cabana, a fire pit in a ring of sofas, planters, an outdoor bar and a garden statue. Water is
-- walk-in (a guest wades); its shimmer and bubbles are drawn on the guest's own screen.

return function(F: any)
	local L = F.Looks
	local box, post, ball, disc = F.box, F.post, F.ball, F.disc
	local trim, soft = F.trim, F.soft
	local rgb = Color3.fromRGB
	local look = F.look
	local rad = math.rad

	-- A pool raised on the deck: coping all round, glass on the open side, steps in at one end.
	F.define("pool", "The pool", function(b: any, st: any)
		local model = st.model or "infinity"
		local len, width = st.length or 20, st.width or 9
		local wall = 0.8
		local h = 2.4 -- the coping's top above the deck
		local tile = if model == "gold" then look(rgb(196, 160, 80), Enum.Material.Foil, 0.2) elseif model == "lagoon" then look(rgb(60, 150, 140), Enum.Material.SmoothPlastic, 0.1) else look(rgb(40, 110, 150), Enum.Material.SmoothPlastic, 0.1)
		local coping = if model == "gold" then L.whiteMarble else L.travertine
		local water = look(F.colour(st, "colour", if model == "lagoon" then rgb(70, 190, 170) else rgb(60, 170, 210)), Enum.Material.Glass, 0.3, 0.35)
		-- The basin's floor and walls (the inside tiled).
		box(b, "PoolFloor", Vector3.new(len, 0.3, width), CFrame.new(0, 0.15, 0), tile)
		box(b, "WallBack", Vector3.new(len + 2 * wall, h, wall), CFrame.new(0, h / 2, width / 2 + wall / 2), coping)
		box(b, "WallBackTile", Vector3.new(len, h - 0.6, 0.06), CFrame.new(0, 0.3 + (h - 0.6) / 2, width / 2 - 0.03), tile, trim)
		for _, sx in { -1, 1 } do
			box(b, "WallEnd", Vector3.new(wall, h, width), CFrame.new(sx * (len / 2 + wall / 2), h / 2, 0), coping)
			box(b, "WallEndTile", Vector3.new(0.06, h - 0.6, width), CFrame.new(sx * (len / 2 - 0.03), 0.3 + (h - 0.6) / 2, 0), tile, trim)
		end
		-- The front: glass to see into the water (the infinity edge), a low lip.
		box(b, "Lip", Vector3.new(len + 2 * wall, 0.6, wall), CFrame.new(0, 0.3, -width / 2 - wall / 2), coping)
		box(b, "GlassFront", Vector3.new(len, h - 0.6, 0.2), CFrame.new(0, 0.6 + (h - 0.6) / 2, -width / 2 - wall / 2), look(rgb(150, 210, 230), Enum.Material.Glass, 0.3, 0.55))
		box(b, "Coping", Vector3.new(len + 2 * wall + 0.4, 0.2, wall + 0.4), CFrame.new(0, h + 0.1, width / 2 + wall / 2), coping, soft)
		for _, sx in { -1, 1 } do
			box(b, "Coping", Vector3.new(wall + 0.4, 0.2, width + 2 * wall), CFrame.new(sx * (len / 2 + wall / 2), h + 0.1, 0), coping, soft)
		end
		-- The water, a little below the coping (walk-in: it doesn't stop anyone).
		local surface = box(b, "Water", Vector3.new(len, h - 0.6, width), CFrame.new(0, 0.3 + (h - 0.6) / 2 - 0.15, 0), water, { collide = false, query = false, shadow = false })
		surface:SetAttribute("Water", true)
		-- Steps up the outside at the right end and down inside.
		for i = 0, 2 do
			box(b, "StepOut", Vector3.new(2.4, 0.8 * (i + 1), 1.0), CFrame.new(len / 2 - 2, 0.4 * (i + 1), -width / 2 - wall - 3.0 + i * 1.0), coping)
		end
		for i = 0, 2 do
			box(b, "StepIn", Vector3.new(2.4, 0.6 * (3 - i), 0.9), CFrame.new(len / 2 - 2, 0.3 * (3 - i), -width / 2 + 0.45 + i * 0.9), coping)
		end
		-- Lights in the walls.
		for i = -2, 2 do
			local lamp = box(b, "PoolLight", Vector3.new(0.7, 0.4, 0.06), CFrame.new(i * len / 5, 0.9, width / 2 - 0.08), look(rgb(170, 230, 255), Enum.Material.Neon, nil, 0.1), trim)
			if i == 0 then
				F.light(b, lamp, 1.6, 18, rgb(150, 220, 255))
			end
		end
		if model == "lagoon" then
			for i, p in { Vector3.new(-len / 2 + 1, h, width / 2 - 0.5), Vector3.new(-len / 2 + 2.5, h + 0.3, width / 2), Vector3.new(len / 2 - 4, h, width / 2 - 0.3) } do
				ball(b, "Rock", 1.6 + (i % 2) * 0.8, p, L.stone, soft)
			end
			box(b, "Waterfall", Vector3.new(2, h + 1.6, 0.2), CFrame.new(-len / 2 + 2.2, (h + 1.6) / 2, width / 2 - 0.2), look(rgb(200, 240, 255), Enum.Material.Glass, 0.2, 0.4), trim)
		end
	end)

	F.define("hottub", "The hot tub", function(b: any, st: any)
		local surround = if st.model == "stone" then L.travertine else L.teak
		local water = look(F.colour(st, "colour", rgb(110, 200, 220)), Enum.Material.Glass, 0.3, 0.35)
		local d, h = 8, 2.6
		disc(b, "Shell", d, h, Vector3.new(0, h / 2, 0), surround)
		disc(b, "Rim", d + 0.4, 0.2, Vector3.new(0, h + 0.1, 0), if st.model == "stone" then L.whiteMarble else L.walnut, soft)
		disc(b, "Inside", d - 1.0, 0.06, Vector3.new(0, h + 0.02, 0), look(rgb(230, 236, 240), Enum.Material.SmoothPlastic), trim)
		local surface = disc(b, "Water", d - 1.1, 0.06, Vector3.new(0, h + 0.07, 0), water, trim)
		surface:SetAttribute("Bubbles", true)
		local glow = disc(b, "Glow", d - 1.6, 0.04, Vector3.new(0, h + 0.05, 0), look(rgb(120, 220, 255), Enum.Material.Neon, nil, 0.55), trim)
		F.light(b, glow, 1.2, 14, rgb(140, 220, 255))
		for i = 0, 2 do
			box(b, "Step", Vector3.new(2.2, 0.8 * (i + 1), 0.9), CFrame.new(0, 0.4 * (i + 1), -d / 2 - 2.4 + i * 0.85), surround)
		end
		for i = 0, 3 do
			local a = rad(45 + i * 90)
			local p = Vector3.new(math.cos(a) * (d / 2 - 1.1), h - 0.9, math.sin(a) * (d / 2 - 1.1))
			F.sit(b, CFrame.lookAt(p, Vector3.new(0, h - 0.9, 0)))
		end
		F.prompt(b, "UsePrompt", Vector3.new(0, h + 1.2, -d / 2 - 0.4), "Bubbles", "The hot tub", "bubbles")
	end)

	-- A sun lounger, centred at x, its head at +Z.
	local function lounger(b: any, x: number, cushion: any, frame: any)
		box(b, "LoungerFrame", Vector3.new(2.4, 0.3, 6.4), CFrame.new(x, 0.9, 0), frame)
		for _, sz in { -1, 1 } do
			for _, sx in { -1, 1 } do
				box(b, "LoungerLeg", Vector3.new(0.25, 0.8, 0.25), CFrame.new(x + sx * 1.0, 0.4, sz * 2.9), frame, soft)
			end
		end
		box(b, "LoungerPad", Vector3.new(2.2, 0.35, 4.2), CFrame.new(x, 1.22, -1.0), cushion)
		box(b, "LoungerBack", Vector3.new(2.2, 0.35, 2.4), CFrame.new(x, 1.75, 2.2) * CFrame.Angles(rad(-35), 0, 0), cushion)
		box(b, "Towel", Vector3.new(1.4, 0.06, 2.4), CFrame.new(x, 1.42, -1.6), look(rgb(236, 230, 214), Enum.Material.Fabric), trim)
		F.sit(b, CFrame.new(x, 1.4, -0.6))
	end
	F.define("loungers", "The sun loungers", function(b: any, st: any)
		local cushion = look(F.colour(st, "colour", rgb(240, 234, 220)), Enum.Material.Fabric)
		local frame = if st.model == "black" then L.blackLacquer else L.teak
		lounger(b, -2.2, cushion, frame)
		lounger(b, 2.2, cushion, frame)
		-- A side table between, a parasol behind.
		disc(b, "Table", 1.4, 0.15, Vector3.new(0, 1.7, -1.5), frame, trim)
		post(b, "TablePost", 1.6, 0.12, Vector3.new(0, 0, -1.5), frame, soft)
		post(b, "Drink", 0.5, 0.3, Vector3.new(0.2, 1.78, -1.5), look(rgb(250, 160, 60), Enum.Material.Glass, 0.2, 0.3), trim)
		post(b, "ParasolPole", 8.6, 0.2, Vector3.new(0, 0, 3.6), frame, soft)
		local canopy = F.colour(st, "accent", rgb(236, 228, 210))
		for i = 0, 7 do
			local a = rad(i * 45 + 22.5)
			box(b, "Canopy", Vector3.new(2.4, 0.08, 3.4), CFrame.new(0, 8.3, 3.6) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.6) * CFrame.Angles(rad(-14), 0, 0), look(canopy, Enum.Material.Fabric), soft)
		end
		disc(b, "Finial", 0.5, 0.4, Vector3.new(0, 8.8, 3.6), L.brass, trim)
	end)

	F.define("cabana", "The cabana", function(b: any, st: any)
		local drape = look(F.colour(st, "colour", rgb(240, 234, 220)), Enum.Material.Fabric, nil, 0.1)
		local wood = L.teak
		local w, d, h = 8, 7, 9
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(b, "Post", Vector3.new(0.45, h, 0.45), CFrame.new(sx * w / 2, h / 2, sz * d / 2), wood)
			end
			-- Curtains tied back at the front, hanging at the back.
			box(b, "DrapeFront", Vector3.new(1.4, h - 0.6, 0.2), CFrame.new(sx * (w / 2 - 0.6), (h - 0.6) / 2, -d / 2 + 0.2) * CFrame.Angles(0, rad(-sx * 20), 0), drape, soft)
			box(b, "DrapeSide", Vector3.new(0.2, h - 0.6, d - 1.4), CFrame.new(sx * w / 2, (h - 0.6) / 2, 0), drape, soft)
		end
		box(b, "DrapeBack", Vector3.new(w - 0.4, h - 0.6, 0.2), CFrame.new(0, (h - 0.6) / 2, d / 2 - 0.1), drape, soft)
		box(b, "Roof", Vector3.new(w + 0.8, 0.4, d + 0.8), CFrame.new(0, h + 0.2, 0), wood)
		box(b, "RoofCloth", Vector3.new(w + 0.4, 0.15, d + 0.4), CFrame.new(0, h + 0.47, 0), drape)
		-- The daybed within.
		box(b, "Bed", Vector3.new(w - 1.6, 1.0, d - 2), CFrame.new(0, 0.7, 0.4), wood)
		box(b, "Cushion", Vector3.new(w - 1.8, 0.5, d - 2.2), CFrame.new(0, 1.45, 0.4), look(rgb(236, 230, 214), Enum.Material.Fabric))
		for i = -1, 1 do
			box(b, "Pillow", Vector3.new(1.8, 1.4, 0.45), CFrame.new(i * 2.0, 2.2, d / 2 - 1.4) * CFrame.Angles(rad(15), 0, 0), look(F.colour(st, "accent", rgb(40, 110, 130)), Enum.Material.Fabric), soft)
		end
		local lantern = ball(b, "Lantern", 0.7, Vector3.new(0, h - 1.2, 0), L.warmGlow, trim)
		F.light(b, lantern, 0.8, 12)
		F.sit(b, CFrame.new(-1.5, 1.7, -0.6))
		F.sit(b, CFrame.new(1.5, 1.7, -0.6))
	end)

	F.define("firepit", "The fire pit", function(b: any, st: any)
		local stone = if st.model == "black" then L.blackMarble else L.stone
		local cushion = look(F.colour(st, "colour", rgb(196, 170, 120)), Enum.Material.Fabric)
		disc(b, "Pit", 4, 1.4, Vector3.new(0, 0.7, 0), stone)
		disc(b, "Bowl", 3.0, 0.2, Vector3.new(0, 1.41, 0), L.steel, trim)
		for i = 0, 6 do
			local a = rad(i * 51)
			ball(b, "Coal", 0.5, Vector3.new(math.cos(a) * 0.8, 1.6, math.sin(a) * 0.8), L.ember, trim)
		end
		local flame = box(b, "Flame", Vector3.new(1.4, 1.2, 1.4), CFrame.new(0, 2.1, 0) * CFrame.Angles(0, rad(45), 0), look(rgb(255, 150, 60), Enum.Material.Neon, nil, 0.35), trim)
		flame:SetAttribute("Flame", true)
		local light = F.light(b, flame, 1.6, 18, rgb(255, 150, 80))
		if light then
			light:SetAttribute("Flicker", true)
		end
		-- A ring of low sofas around it, open at the front.
		local r = 5.6
		for i = 0, 5 do
			local a = rad(-150 + i * 60)
			if math.abs(math.deg(a) + 90) < 20 then
				continue -- leave the front open
			end
			local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			local cf = CFrame.lookAt(p, Vector3.zero)
			box(b, "Sofa", Vector3.new(3.2, 1.1, 2.4), cf * CFrame.new(0, 0.55, 0), L.teak)
			box(b, "SofaCushion", Vector3.new(3.0, 0.45, 2.2), cf * CFrame.new(0, 1.32, 0), cushion)
			box(b, "SofaBack", Vector3.new(3.0, 1.4, 0.5), cf * CFrame.new(0, 2.0, 1.0), cushion)
			F.sit(b, cf * CFrame.new(0, 1.55, -0.1))
		end
	end)

	F.define("garden", "The garden", function(b: any, st: any)
		local planter = if st.model == "white" then L.ivoryLacquer else L.blackLacquer
		local bloom = F.colour(st, "colour", rgb(150, 110, 200))
		local len = st.length or 12
		box(b, "Planter", Vector3.new(len, 2.0, 2.4), CFrame.new(0, 1.0, 0), planter)
		box(b, "Soil", Vector3.new(len - 0.4, 0.1, 2.0), CFrame.new(0, 1.96, 0), L.soil, trim)
		-- Olive trees at the ends, lavender between.
		for _, sx in { -1, 1 } do
			local x = sx * (len / 2 - 1.4)
			box(b, "Trunk", Vector3.new(0.3, 3.4, 0.3), CFrame.new(x, 3.7, 0) * CFrame.Angles(0, 0, rad(sx * 5)), L.walnut, soft)
			for i, p in { Vector3.new(0, 5.8, 0), Vector3.new(0.7, 5.4, 0.3), Vector3.new(-0.6, 5.5, -0.4), Vector3.new(0.1, 6.3, 0.2) } do
				ball(b, "Olive", 1.8 - (i % 2) * 0.3, p + Vector3.new(x, 0, 0), look(rgb(116, 136, 100), Enum.Material.Grass), soft)
			end
		end
		local n = math.floor((len - 5) / 0.8)
		for i = 0, n do
			local x = -len / 2 + 2.6 + i * 0.8
			post(b, "Lavender", 0.9, 0.15, Vector3.new(x, 2.0, -0.4 + (i % 2) * 0.7), L.darkLeaf, trim)
			ball(b, "Bloom", 0.4, Vector3.new(x, 3.0, -0.4 + (i % 2) * 0.7), look(bloom, Enum.Material.SmoothPlastic), trim)
		end
	end)

	F.define("outdoorbar", "The outdoor bar", function(b: any, st: any)
		local body = if st.model == "white" then L.ivoryLacquer else L.teak
		local accent = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.28)
		box(b, "Bar", Vector3.new(8, 3.4, 1.8), CFrame.new(0, 1.7, 0), body)
		box(b, "BarTop", Vector3.new(8.4, 0.25, 2.4), CFrame.new(0, 3.5, -0.2), L.whiteMarble)
		box(b, "BackBar", Vector3.new(8, 3.2, 1.2), CFrame.new(0, 1.6, 3.2), body)
		box(b, "BackShelf", Vector3.new(8, 0.15, 1.0), CFrame.new(0, 5.2, 3.4), body)
		for i = 0, 7 do
			post(b, "Bottle", 1.0, 0.3, Vector3.new(-3.2 + i * 0.9, 5.28, 3.4), look(({ rgb(40, 70, 44), rgb(150, 30, 40), rgb(200, 180, 120), rgb(90, 140, 160) })[i % 4 + 1], Enum.Material.Glass, 0.2, 0.15), trim)
		end
		-- A pergola over it, with lights strung along.
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(b, "Post", Vector3.new(0.4, 9, 0.4), CFrame.new(sx * 4.6, 4.5, 1.4 + sz * 2.6), body)
			end
		end
		for i = 0, 6 do
			box(b, "Slat", Vector3.new(0.25, 0.4, 6.2), CFrame.new(-4.2 + i * 1.4, 9.1, 1.4), body)
		end
		for i = 0, 8 do
			local bulb = ball(b, "Bulb", 0.3, Vector3.new(-4 + i * 1.0, 8.4 - math.sin(i / 8 * math.pi) * 0.5, -1.0), L.warmGlow, trim)
			if i == 4 then
				F.light(b, bulb, 1.0, 14)
			end
		end
		for _, x in { -2.6, 0, 2.6 } do
			post(b, "StoolPost", 2.6, 0.16, Vector3.new(x, 0.1, -2.2), accent, soft)
			disc(b, "StoolFoot", 1.0, 0.1, Vector3.new(x, 0.05, -2.2), accent, soft)
			disc(b, "StoolSeat", 1.3, 0.35, Vector3.new(x, 2.85, -2.2), L.teak)
			F.sit(b, CFrame.new(x, 3.05, -2.2) * CFrame.Angles(0, rad(180), 0))
		end
	end)

	F.define("statue", "The statue", function(b: any, st: any)
		local stone = look(F.colour(st, "colour", rgb(226, 220, 206)), if st.metal then Enum.Material.Metal else Enum.Material.Marble, if st.metal then 0.3 else 0.05)
		box(b, "Plinth", Vector3.new(3, 2.4, 3), CFrame.new(0, 1.2, 0), L.travertine)
		box(b, "PlinthCap", Vector3.new(3.3, 0.3, 3.3), CFrame.new(0, 2.55, 0), L.travertine, trim)
		local y = 2.7
		-- A standing figure in a draped robe, one arm raised.
		box(b, "Robe", Vector3.new(1.8, 3.6, 1.2), CFrame.new(0, y + 1.8, 0), stone)
		box(b, "RobeHem", Vector3.new(2.2, 0.8, 1.5), CFrame.new(0, y + 0.4, 0), stone)
		box(b, "Torso", Vector3.new(1.6, 1.6, 0.9), CFrame.new(0, y + 4.2, 0), stone)
		ball(b, "Head", 0.95, Vector3.new(0, y + 5.55, 0), stone)
		box(b, "ArmUp", Vector3.new(0.4, 2.2, 0.4), CFrame.new(1.0, y + 5.4, 0) * CFrame.Angles(0, 0, rad(-20)), stone)
		box(b, "ArmDown", Vector3.new(0.4, 2.0, 0.4), CFrame.new(-1.0, y + 3.8, 0.1) * CFrame.Angles(0, 0, rad(10)), stone)
		ball(b, "Torch", 0.6, Vector3.new(1.4, y + 6.6, 0), look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.3), trim)
	end)
end

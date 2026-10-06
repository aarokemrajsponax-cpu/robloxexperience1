--!strict
-- The drawing room: sofas, armchairs, the coffee table, the drinks cabinet, bookcases, the
-- television, a baby grand, and the Dressing Room's chaise and the Study's desk and globe.

return function(F: any)
	local L = F.Looks
	local box, cyl, post, ball, disc = F.box, F.cyl, F.post, F.ball, F.disc
	local trim, soft = F.trim, F.soft
	local rgb = Color3.fromRGB
	local look = F.look
	local rad = math.rad

	local function darker(c: Color3, by: number): Color3
		return c:Lerp(Color3.new(0, 0, 0), by)
	end

	-- Upholstery from a style: its colour in its material (velvet by default).
	local function cloth(st: any, default: Color3): any
		return F.tint(F.colour(st, "colour", default), st.material, Enum.Material.Fabric)
	end

	-- A cylinder running front to back (along Z).
	local function roll(b: any, name: string, length: number, d: number, at: Vector3, lk: any, o: any?)
		return cyl(b, name, length, d, CFrame.new(at) * CFrame.Angles(0, rad(90), 0), lk, o)
	end

	-- Four short legs under a base of w x d, each `h` tall, in `lk`.
	local function legs(b: any, w: number, d: number, h: number, lk: any, inset: number?, round: boolean?)
		local i = inset or 0.3
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local p = Vector3.new(sx * (w / 2 - i), 0, sz * (d / 2 - i))
				if round then
					ball(b, "Foot", h * 1.6, p + Vector3.new(0, h * 0.6, 0), lk, soft)
				else
					post(b, "Leg", h, 0.18, p, lk, soft)
				end
			end
		end
	end

	-------------------------------------------------------------------------------------------
	-- Sofas (about 8 studs long, the seat 1.65 up)
	-------------------------------------------------------------------------------------------
	F.define("sofa", "The sofa", function(b: any, st: any)
		local model = st.model or "chesterfield"
		local c = cloth(st, rgb(70, 30, 20))
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.2)
		local dark = look(darker(c.color, 0.25), c.material)
		if model == "curved" then
			-- A crescent of velvet: seven sections around a point in front of it.
			local centre = Vector3.new(0, 0, -3.6)
			local radius = 5
			local n = 7
			local span = rad(120)
			for i = 0, n - 1 do
				local a = -span / 2 + (i + 0.5) * span / n
				local p = centre + Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
				local frame = CFrame.lookAt(p, centre)
				local segW = radius * span / n + 0.12
				box(b, "Base", Vector3.new(segW, 0.6, 2.8), frame * CFrame.new(0, 0.55, 0), dark)
				box(b, "Seat", Vector3.new(segW, 0.55, 2.6), frame * CFrame.new(0, 1.15, -0.1), c)
				box(b, "Back", Vector3.new(segW + 0.15, 1.9, 0.7), frame * CFrame.new(0, 1.95, 1.15) * CFrame.Angles(rad(8), 0, 0), c)
			end
			for _, sx in { -1, 1 } do
				local a = sx * span / 2
				local p = centre + Vector3.new(math.sin(a) * radius, 0, math.cos(a) * radius)
				post(b, "ArmEnd", 2.3, 1.1, p, c)
			end
			for _, a in { -40, 0, 40 } do
				local p = centre + Vector3.new(math.sin(rad(a)) * (radius - 0.2), 1.42, math.cos(rad(a)) * (radius - 0.2))
				F.sit(b, CFrame.lookAt(p, Vector3.new(centre.X, 1.42, centre.Z)))
			end
			return
		end
		local w, d = 8.4, 3.4
		if model == "modern" then
			local metal = L.steel
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					box(b, "Leg", Vector3.new(0.14, 0.45, 0.14), CFrame.new(sx * (w / 2 - 0.4), 0.225, sz * (d / 2 - 0.35)), metal, soft)
				end
			end
			box(b, "Base", Vector3.new(w, 0.5, d), CFrame.new(0, 0.7, 0), dark)
			for _, sx in { -1, 1 } do
				box(b, "Cushion", Vector3.new((w - 1.2) / 2 - 0.05, 0.55, d - 0.9), CFrame.new(sx * ((w - 1.2) / 4), 1.22, -0.35), c)
				box(b, "BackCushion", Vector3.new((w - 1.2) / 2 - 0.05, 1.5, 0.65), CFrame.new(sx * ((w - 1.2) / 4), 1.95, d / 2 - 0.5) * CFrame.Angles(rad(10), 0, 0), c)
				box(b, "Arm", Vector3.new(0.6, 1.25, d), CFrame.new(sx * (w / 2 - 0.3), 1.37, 0), c)
				box(b, "Pillow", Vector3.new(1.1, 1.1, 0.35), CFrame.new(sx * (w / 2 - 1.4), 2.05, d / 2 - 0.95) * CFrame.Angles(rad(14), rad(sx * 12), 0), look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Fabric), soft)
			end
			box(b, "BackRail", Vector3.new(w, 1.3, 0.3), CFrame.new(0, 1.55, d / 2 - 0.15), dark)
			for _, x in { -2.4, 0, 2.4 } do
				F.sit(b, CFrame.new(x, 1.5, -0.35))
			end
			return
		end
		if model == "sectional" then
			-- An L: the long run, and a chaise coming forward on the left.
			box(b, "Base", Vector3.new(w, 0.75, d), CFrame.new(0, 0.6, 0), dark)
			box(b, "ChaiseBase", Vector3.new(3, 0.75, 3.6), CFrame.new(-w / 2 + 1.5, 0.6, -d / 2 - 1.8), dark)
			box(b, "Seat", Vector3.new(w - 0.9, 0.5, d - 0.8), CFrame.new(0.2, 1.22, -0.35), c)
			box(b, "ChaiseSeat", Vector3.new(2.8, 0.5, 3.6), CFrame.new(-w / 2 + 1.5, 1.22, -d / 2 - 1.8), c)
			box(b, "Back", Vector3.new(w, 1.7, 0.75), CFrame.new(0, 2.0, d / 2 - 0.37), c)
			box(b, "Arm", Vector3.new(0.6, 1.15, d), CFrame.new(w / 2 - 0.3, 1.5, 0), c)
			for i = 0, 2 do
				box(b, "Pillow", Vector3.new(1.2, 1.2, 0.35), CFrame.new(-2 + i * 2.2, 2.25, d / 2 - 0.95) * CFrame.Angles(rad(12), 0, 0), look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Fabric), soft)
			end
			legs(b, w, d, 0.24, accent, 0.4)
			for _, x in { -1.2, 1.2, 3.2 } do
				F.sit(b, CFrame.new(x, 1.47, -0.35))
			end
			F.sit(b, CFrame.new(-w / 2 + 1.5, 1.47, -d / 2 - 1.6))
			return
		end
		-- The Chesterfield: buttoned back, rolled arms, bun feet.
		legs(b, w, d, 0.3, accent, 0.45, true)
		box(b, "Base", Vector3.new(w, 0.9, d), CFrame.new(0, 0.75, 0), dark)
		for i = -1, 1 do
			box(b, "Cushion", Vector3.new((w - 1.5) / 3 - 0.06, 0.48, d - 0.95), CFrame.new(i * (w - 1.5) / 3, 1.44, -0.3), c)
		end
		box(b, "Back", Vector3.new(w - 0.6, 1.75, 0.72), CFrame.new(0, 2.05, d / 2 - 0.36), c)
		cyl(b, "BackRoll", w - 0.6, 0.78, CFrame.new(0, 2.92, d / 2 - 0.36), c)
		for _, sx in { -1, 1 } do
			box(b, "Arm", Vector3.new(0.72, 1.1, d), CFrame.new(sx * (w / 2 - 0.36), 1.75, 0), c)
			roll(b, "ArmRoll", d, 0.86, Vector3.new(sx * (w / 2 - 0.36), 2.3, 0), c)
			cyl(b, "ArmFace", 0.06, 0.7, CFrame.new(sx * (w / 2 - 0.36), 2.3, -d / 2 - 0.02) * CFrame.Angles(0, rad(90), 0), dark, trim)
		end
		-- The buttons
		for row = 0, 1 do
			for col = 0, 6 do
				ball(b, "Button", 0.11, Vector3.new(-3 + col * 1.0 + row * 0.5, 2.0 + row * 0.55, d / 2 - 0.74), dark, trim)
			end
		end
		for _, x in { -2.3, 0, 2.3 } do
			F.sit(b, CFrame.new(x, 1.68, -0.3))
		end
	end)

	-------------------------------------------------------------------------------------------
	-- Armchairs (one seat)
	-------------------------------------------------------------------------------------------
	F.define("chair", "The armchair", function(b: any, st: any)
		local model = st.model or "wing"
		local c = cloth(st, rgb(92, 20, 30))
		local dark = look(darker(c.color, 0.25), c.material)
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.2)
		if model == "club" then
			box(b, "Base", Vector3.new(3.4, 1.0, 3.2), CFrame.new(0, 0.7, 0), dark)
			box(b, "Seat", Vector3.new(2.3, 0.5, 2.5), CFrame.new(0, 1.43, -0.25), c)
			box(b, "Back", Vector3.new(3.4, 1.6, 0.8), CFrame.new(0, 2.0, 1.2), c)
			cyl(b, "BackRoll", 3.4, 0.8, CFrame.new(0, 2.8, 1.2), c)
			for _, sx in { -1, 1 } do
				box(b, "Arm", Vector3.new(0.55, 1.25, 3.2), CFrame.new(sx * 1.43, 1.6, 0), c)
				roll(b, "ArmRoll", 3.2, 0.7, Vector3.new(sx * 1.43, 2.22, 0), c)
			end
			legs(b, 3.4, 3.2, 0.2, accent, 0.4, true)
			F.sit(b, CFrame.new(0, 1.68, -0.25))
		elseif model == "barrel" then
			disc(b, "Base", 3.2, 0.9, Vector3.new(0, 0.65, 0), dark)
			disc(b, "Seat", 2.8, 0.5, Vector3.new(0, 1.35, -0.1), c)
			for i = 0, 6 do
				local a = rad(-100 + i * (200 / 6))
				local p = Vector3.new(math.sin(a) * 1.45, 0, math.cos(a) * 1.45)
				box(b, "Back", Vector3.new(0.85, 2.2, 0.5), CFrame.lookAt(p, Vector3.zero) * CFrame.new(0, 1.75, 0), c)
			end
			disc(b, "Ring", 3.3, 0.12, Vector3.new(0, 0.2, 0), accent, trim)
			F.sit(b, CFrame.new(0, 1.6, -0.15))
		elseif model == "lounge" then
			-- The lounge chair and its ottoman: walnut shells, black leather, a five-star base.
			local wood = L.walnut
			local hide = F.tint(F.colour(st, "colour", rgb(22, 20, 20)), "Leather", Enum.Material.Leather)
			for i = 0, 4 do
				local a = rad(i * 72)
				box(b, "Star", Vector3.new(0.18, 0.12, 1.4), CFrame.new(0, 0.3, 0.2) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -0.65), L.chrome, soft)
			end
			post(b, "Column", 0.9, 0.3, Vector3.new(0, 0.3, 0.2), L.chrome, soft)
			box(b, "SeatShell", Vector3.new(2.8, 0.25, 2.6), CFrame.new(0, 1.25, 0) * CFrame.Angles(rad(8), 0, 0), wood)
			box(b, "Seat", Vector3.new(2.5, 0.45, 2.4), CFrame.new(0, 1.55, -0.05) * CFrame.Angles(rad(8), 0, 0), hide)
			box(b, "BackShell", Vector3.new(2.8, 2.6, 0.25), CFrame.new(0, 2.7, 1.3) * CFrame.Angles(rad(18), 0, 0), wood)
			box(b, "BackCushion", Vector3.new(2.5, 2.3, 0.4), CFrame.new(0, 2.75, 1.05) * CFrame.Angles(rad(18), 0, 0), hide)
			for _, sx in { -1, 1 } do
				box(b, "Arm", Vector3.new(0.4, 0.3, 2.2), CFrame.new(sx * 1.45, 2.05, 0.1) * CFrame.Angles(rad(6), 0, 0), hide, soft)
			end
			-- The ottoman, in front.
			post(b, "OttoColumn", 0.7, 0.24, Vector3.new(0, 0.2, -2.9), L.chrome, soft)
			box(b, "OttoShell", Vector3.new(2.2, 0.2, 1.7), CFrame.new(0, 0.95, -2.9), wood)
			box(b, "OttoCushion", Vector3.new(2.0, 0.4, 1.5), CFrame.new(0, 1.25, -2.9), hide)
			F.sit(b, CFrame.new(0, 1.8, 0))
		else -- the wing chair
			legs(b, 3.2, 3.0, 0.5, look(rgb(60, 36, 24), Enum.Material.Wood), 0.3)
			box(b, "Base", Vector3.new(3.2, 0.7, 3.0), CFrame.new(0, 0.85, 0), dark)
			box(b, "Seat", Vector3.new(2.3, 0.45, 2.4), CFrame.new(0, 1.42, -0.2), c)
			box(b, "Back", Vector3.new(2.9, 3.2, 0.6), CFrame.new(0, 2.7, 1.2) * CFrame.Angles(rad(6), 0, 0), c)
			cyl(b, "Crest", 2.9, 0.6, CFrame.new(0, 4.3, 1.33), c)
			for _, sx in { -1, 1 } do
				box(b, "Wing", Vector3.new(0.4, 1.6, 1.3), CFrame.new(sx * 1.35, 3.2, 0.75) * CFrame.Angles(0, rad(sx * 18), 0), c)
				box(b, "Arm", Vector3.new(0.5, 1.0, 2.6), CFrame.new(sx * 1.35, 1.7, -0.15), c)
				roll(b, "ArmRoll", 2.6, 0.62, Vector3.new(sx * 1.35, 2.2, -0.15), c)
			end
			for i = 0, 3 do
				ball(b, "Nail", 0.08, Vector3.new(-1.2 + i * 0.8, 1.3, -1.5), accent, trim)
			end
			F.sit(b, CFrame.new(0, 1.65, -0.2))
		end
	end)

	-------------------------------------------------------------------------------------------
	-- The coffee table, with a few things on it
	-------------------------------------------------------------------------------------------
	F.define("coffeeTable", "The coffee table", function(b: any, st: any)
		local model = st.model or "marble"
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		local topY: number
		if model == "glass" then
			box(b, "Top", Vector3.new(5, 0.12, 2.8), CFrame.new(0, 1.5, 0), L.glass, soft)
			box(b, "Shelf", Vector3.new(4.6, 0.1, 2.4), CFrame.new(0, 0.5, 0), look(rgb(30, 26, 24), Enum.Material.Wood), soft)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					post(b, "Leg", 1.44, 0.12, Vector3.new(sx * 2.4, 0, sz * 1.3), accent, soft)
				end
				box(b, "Rail", Vector3.new(0.1, 0.1, 2.7), CFrame.new(sx * 2.45, 1.42, 0), accent, trim)
			end
			topY = 1.56
		elseif model == "block" then
			box(b, "Block", Vector3.new(4.6, 1.3, 2.8), CFrame.new(0, 0.65, 0), L.walnut)
			box(b, "Tray", Vector3.new(2.2, 0.08, 1.4), CFrame.new(0.6, 1.34, 0), accent, trim)
			topY = 1.3
		else -- a round marble top on a brass drum
			disc(b, "Top", 4, 0.22, Vector3.new(0, 1.39, 0), L.whiteMarble)
			disc(b, "Drum", 2.6, 1.0, Vector3.new(0, 0.78, 0), accent)
			disc(b, "Foot", 3, 0.28, Vector3.new(0, 0.14, 0), accent)
			topY = 1.5
		end
		-- Books, a bowl, a candle.
		box(b, "Book", Vector3.new(1.3, 0.16, 1.0), CFrame.new(-0.8, topY + 0.08, 0.1) * CFrame.Angles(0, rad(8), 0), look(rgb(110, 30, 26), Enum.Material.Fabric), trim)
		box(b, "Book", Vector3.new(1.1, 0.14, 0.85), CFrame.new(-0.8, topY + 0.23, 0.1) * CFrame.Angles(0, rad(-4), 0), look(rgb(230, 222, 204), Enum.Material.Fabric), trim)
		disc(b, "Bowl", 0.9, 0.3, Vector3.new(0.9, topY + 0.15, -0.2), accent, trim)
		post(b, "Candle", 0.4, 0.22, Vector3.new(0.3, topY, 0.5), L.paper, trim)
	end)

	-------------------------------------------------------------------------------------------
	-- Drinks: the cabinet, the bar, the cart
	-------------------------------------------------------------------------------------------
	local BOTTLES = { rgb(40, 70, 44), rgb(120, 60, 20), rgb(150, 30, 40), rgb(200, 180, 120), rgb(30, 30, 34), rgb(90, 140, 160) }
	local function bottles(b: any, n: number, from: Vector3, step: number)
		for i = 1, n do
			local c = BOTTLES[(i - 1) % #BOTTLES + 1]
			local h = 0.9 + (i % 3) * 0.18
			local p = from + Vector3.new((i - 1) * step, 0, 0)
			post(b, "Bottle", h, 0.3, p, look(c, Enum.Material.Glass, 0.2, 0.15), trim)
			post(b, "Neck", 0.3, 0.12, p + Vector3.new(0, h, 0), look(c, Enum.Material.Glass, 0.2, 0.15), trim)
		end
	end
	F.define("bar", "The drinks cabinet", function(b: any, st: any)
		local model = st.model or "walnut"
		local body = F.tint(F.colour(st, "colour", rgb(66, 38, 24)), if model == "lacquer" then "SmoothPlastic" else "Wood", Enum.Material.Wood)
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		if model == "cart" then
			for _, y in { 0.9, 2.3 } do
				box(b, "Shelf", Vector3.new(3.6, 0.08, 1.8), CFrame.new(0, y, 0), L.glass, soft)
				box(b, "Rim", Vector3.new(3.7, 0.12, 0.08), CFrame.new(0, y + 0.06, -0.92), accent, trim)
				box(b, "Rim", Vector3.new(3.7, 0.12, 0.08), CFrame.new(0, y + 0.06, 0.92), accent, trim)
			end
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					post(b, "Post", 3.0, 0.1, Vector3.new(sx * 1.8, 0.3, sz * 0.9), accent, soft)
					cyl(b, "Wheel", 0.12, 0.6, CFrame.new(sx * 1.8, 0.3, sz * 0.9) * CFrame.Angles(0, rad(90), 0), L.blackLacquer, trim)
				end
			end
			cyl(b, "Handle", 2, 0.1, CFrame.new(0, 3.25, 0.95) * CFrame.Angles(0, 0, 0), accent, trim)
			bottles(b, 5, Vector3.new(-1.3, 2.34, 0.2), 0.62)
			for i = 0, 3 do
				post(b, "Glass", 0.35, 0.26, Vector3.new(-1.1 + i * 0.6, 0.94, -0.3), L.glass, trim)
			end
			ball(b, "Decanter", 0.6, Vector3.new(1.2, 1.25, 0.2), look(rgb(150, 80, 30), Enum.Material.Glass, 0.25, 0.2), trim)
			return
		end
		local w, d, h = 5.6, 1.8, 3.8
		box(b, "Body", Vector3.new(w, h, d), CFrame.new(0, h / 2, 0), body)
		box(b, "Top", Vector3.new(w + 0.2, 0.18, d + 0.2), CFrame.new(0, h + 0.09, 0), if model == "lacquer" then L.blackMarble else L.whiteMarble)
		for _, x in { -w / 4, w / 4 } do
			box(b, "Door", Vector3.new(w / 2 - 0.25, h - 0.6, 0.06), CFrame.new(x, h / 2, -d / 2 - 0.03), look(darker(body.color, 0.12), body.material), trim)
			box(b, "Handle", Vector3.new(0.08, 0.6, 0.08), CFrame.new(x + (if x < 0 then w / 4 - 0.35 else -(w / 4 - 0.35)), h / 2, -d / 2 - 0.1), accent, trim)
		end
		-- A mirrored back with glass shelves and bottles.
		box(b, "Mirror", Vector3.new(w - 0.4, 3.6, 0.1), CFrame.new(0, h + 2.0, d / 2 - 0.1), L.mirror, soft)
		box(b, "MirrorFrame", Vector3.new(w, 4.0, 0.08), CFrame.new(0, h + 2.0, d / 2 - 0.02), accent, trim)
		for i, y in { h + 1.1, h + 2.5 } do
			box(b, "GlassShelf", Vector3.new(w - 0.6, 0.06, 0.8), CFrame.new(0, y, d / 2 - 0.5), L.glass, trim)
			bottles(b, 6, Vector3.new(-w / 2 + 0.8, y + 0.04, d / 2 - 0.5), (w - 1.6) / 5)
			local strip = box(b, "Glow", Vector3.new(w - 0.6, 0.04, 0.06), CFrame.new(0, y - 0.05, d / 2 - 0.15), L.warmGlow, trim)
			if i == 1 then
				F.light(b, strip, 0.8, 8, rgb(255, 214, 160))
			end
		end
		for i = 0, 2 do
			post(b, "Glass", 0.4, 0.28, Vector3.new(-1.2 + i * 0.5, h + 0.18, -0.3), L.glass, trim)
		end
		ball(b, "Decanter", 0.7, Vector3.new(1.5, h + 0.5, 0), look(rgb(150, 80, 30), Enum.Material.Glass, 0.25, 0.2), trim)
	end)

	-------------------------------------------------------------------------------------------
	-- Bookcases and display shelves (their backs to the wall)
	-------------------------------------------------------------------------------------------
	local SPINES = { rgb(110, 30, 26), rgb(30, 60, 46), rgb(40, 34, 60), rgb(150, 110, 60), rgb(80, 30, 40), rgb(200, 186, 150), rgb(26, 26, 30), rgb(120, 70, 40) }
	F.define("shelf", "The bookcase", function(b: any, st: any)
		local model = st.model or "library"
		local wood = F.tint(F.colour(st, "colour", rgb(40, 24, 16)), "Wood", Enum.Material.Wood)
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.2)
		local w, h, d = 7.2, 9.4, 1.4
		box(b, "Back", Vector3.new(w, h, 0.15), CFrame.new(0, h / 2, d / 2 - 0.08), look(darker(wood.color, 0.3), wood.material))
		for _, sx in { -1, 1 } do
			box(b, "Side", Vector3.new(0.2, h, d), CFrame.new(sx * (w / 2 - 0.1), h / 2, 0), wood)
		end
		box(b, "Cornice", Vector3.new(w + 0.4, 0.4, d + 0.3), CFrame.new(0, h + 0.2, 0), wood)
		box(b, "Plinth", Vector3.new(w + 0.2, 0.5, d + 0.1), CFrame.new(0, 0.25, 0), wood)
		local shelves = 5
		for i = 1, shelves do
			local y = 0.5 + (i - 1) * (h - 0.6) / shelves
			box(b, "Shelf", Vector3.new(w - 0.4, 0.12, d - 0.15), CFrame.new(0, y, 0.05), wood, soft)
			if model == "display" then
				-- Objets: a vase, a sphere, a short stack of books.
				post(b, "Vase", 0.9, 0.45, Vector3.new(-2.2, y + 0.06, 0), look(SPINES[i % #SPINES + 1], Enum.Material.SmoothPlastic, 0.1), trim)
				ball(b, "Orb", 0.55, Vector3.new(0.2, y + 0.34, 0), accent, trim)
				box(b, "Books", Vector3.new(1.2, 0.5, 0.9), CFrame.new(2.0, y + 0.31, 0), look(SPINES[(i + 3) % #SPINES + 1], Enum.Material.Fabric), trim)
			elseif i > 1 then
				-- Rows of spines, in runs of a colour.
				local x = -w / 2 + 0.35
				local j = 0
				while x < w / 2 - 0.8 do
					j += 1
					local run = 0.45 + ((i * 13 + j * 7) % 5) * 0.18
					run = math.min(run, w / 2 - 0.3 - x)
					local bh = 1.05 + ((i * 7 + j * 3) % 4) * 0.08
					box(b, "Books", Vector3.new(run - 0.03, bh, 0.95), CFrame.new(x + run / 2, y + 0.06 + bh / 2, 0.05), look(SPINES[(i * 3 + j) % #SPINES + 1], Enum.Material.Fabric), trim)
					x += run
					if j % 3 == 0 then
						x += 0.25
					end
				end
			end
		end
		if model == "display" then
			local glow = box(b, "Glow", Vector3.new(w - 0.6, 0.04, 0.08), CFrame.new(0, h - 0.15, -0.3), L.warmGlow, trim)
			F.spotLight(b, glow, Enum.NormalId.Bottom, 0.8, 10, 100)
		end
	end)

	-------------------------------------------------------------------------------------------
	-- The television: a media wall with the screen above a low console. Its screen is
	-- "Screen" (a guest's screen plays something on it when it's switched on).
	-------------------------------------------------------------------------------------------
	F.define("tv", "The television", function(b: any, st: any)
		local model = st.model or "wall"
		local big = model == "cinema"
		local w = if big then 11 else 7.6
		local h = w * 9 / 16
		local console = F.tint(F.colour(st, "colour", rgb(16, 14, 14)), "Wood", Enum.Material.Wood)
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		box(b, "Console", Vector3.new(w + 1.4, 1.6, 1.6), CFrame.new(0, 0.95, -0.6), console)
		box(b, "ConsoleTop", Vector3.new(w + 1.5, 0.12, 1.7), CFrame.new(0, 1.81, -0.6), if model == "frame" then L.whiteMarble else L.blackMarble)
		for i = -1, 1 do
			box(b, "Drawer", Vector3.new((w + 1.4) / 3 - 0.2, 1.2, 0.05), CFrame.new(i * (w + 1.4) / 3, 0.95, -1.42), look(darker(console.color, 0.15), console.material), trim)
		end
		for _, sx in { -1, 1 } do
			box(b, "Foot", Vector3.new(0.3, 0.15, 1.5), CFrame.new(sx * (w / 2 + 0.3), 0.07, -0.6), accent, soft)
		end
		local y = 2.6 + h / 2 + (if big then 0.4 else 0.2)
		box(b, "Bezel", Vector3.new(w + 0.2, h + 0.2, 0.25), CFrame.new(0, y, 0.15), if model == "frame" then accent else L.blackLacquer)
		local screen = box(b, "Screen", Vector3.new(w, h, 0.05), CFrame.new(0, y, 0.0), look(rgb(20, 24, 34), Enum.Material.Glass, 0.35, 0), trim)
		screen:SetAttribute("Screen", true)
		box(b, "Soundbar", Vector3.new(w * 0.6, 0.35, 0.4), CFrame.new(0, 2.15, -0.6), L.blackLacquer, trim)
		-- A soft glow on the wall behind it.
		local back = box(b, "Backlight", Vector3.new(w - 1, h - 1, 0.04), CFrame.new(0, y, 0.3), look(rgb(120, 140, 255), Enum.Material.Neon, nil, 0.3), trim)
		if b.lit then
			local halo = Instance.new("SurfaceLight")
			halo.Face = Enum.NormalId.Back
			halo.Brightness = 1.2
			halo.Range = 7
			halo.Angle = 120
			halo.Color = rgb(120, 140, 255)
			halo.Parent = back
		end
		F.prompt(b, "UsePrompt", Vector3.new(0, 2.6, -1.6), "Turn on", "The television", "tv")
	end)

	-------------------------------------------------------------------------------------------
	-- A baby grand: playable by its owner (UsePrompt "piano"). Its keys are Key1..Key37.
	-------------------------------------------------------------------------------------------
	F.define("piano", "The baby grand", function(b: any, st: any)
		local lacquer = F.tint(F.colour(st, "colour", rgb(12, 12, 14)), "SmoothPlastic", Enum.Material.SmoothPlastic)
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		for _, o in { { -2.2, -1.6 }, { 2.2, -1.6 }, { 0, 3.4 } } do
			post(b, "Leg", 2.5, 0.5, Vector3.new(o[1], 0, o[2]), lacquer)
			disc(b, "Castor", 0.4, 0.12, Vector3.new(o[1], 0.06, o[2]), accent, trim)
		end
		box(b, "Case", Vector3.new(5, 1.3, 3.8), CFrame.new(0, 3.15, 0), lacquer)
		box(b, "Tail", Vector3.new(3.4, 1.3, 2.6), CFrame.new(-0.8, 3.15, 3.0), lacquer)
		cyl(b, "TailRound", 1.3, 2.8, CFrame.new(0.85, 3.15, 3.3) * CFrame.Angles(0, 0, rad(90)), lacquer)
		box(b, "Lid", Vector3.new(4.8, 0.1, 5.8), CFrame.new(-0.4, 5.1, 1.4) * CFrame.Angles(0, 0, rad(-26)) * CFrame.new(1.1, 0, 0), lacquer, soft)
		box(b, "Prop", Vector3.new(0.07, 1.8, 0.07), CFrame.new(1.8, 4.6, 1.4), accent, trim)
		box(b, "Strings", Vector3.new(4.4, 0.04, 5.2), CFrame.new(-0.2, 3.82, 1.2), look(rgb(98, 74, 34), Enum.Material.Metal, 0.12), trim)
		box(b, "Keybed", Vector3.new(4.9, 0.45, 1.2), CFrame.new(0, 2.8, -2.4), lacquer)
		local keyboard = Instance.new("Model")
		keyboard.Name = "Keyboard"
		keyboard.Parent = b.model
		local whiteW = 4.5 / 22
		local count = 0
		local lowest = 48
		for i = 1, 37 do
			local step = (lowest + i - 1) % 12
			local black = step == 1 or step == 3 or step == 6 or step == 8 or step == 10
			local key: Part
			if black then
				key = box(b, "Key" .. i, Vector3.new(whiteW * 0.56, 0.1, 0.48), CFrame.new(2.25 - count * whiteW, 3.13, -2.4), L.blackLacquer, trim)
			else
				key = box(b, "Key" .. i, Vector3.new(whiteW - 0.02, 0.11, 0.84), CFrame.new(2.25 - (count + 0.5) * whiteW, 3.03, -2.58), L.paper, trim)
				count += 1
			end
			key.Parent = keyboard
		end
		box(b, "MusicDesk", Vector3.new(2.8, 0.85, 0.08), CFrame.new(0, 3.95, -1.7) * CFrame.Angles(rad(-15), 0, 0), lacquer, soft)
		box(b, "Bench", Vector3.new(2.8, 0.45, 1.2), CFrame.new(0, 1.9, -4.3), F.tint(F.colour(st, "bench", rgb(22, 20, 20)), "Leather", Enum.Material.Leather))
		for _, x in { -1.2, 1.2 } do
			post(b, "BenchLeg", 1.68, 0.2, Vector3.new(x, 0, -4.3), lacquer, soft)
		end
		F.prompt(b, "UsePrompt", Vector3.new(0, 3.6, -3.4), "Play", "Your piano", "piano")
	end)

	-------------------------------------------------------------------------------------------
	-- The Dressing Room's chaise and the Study's desk and globe
	-------------------------------------------------------------------------------------------
	F.define("chaise", "The chaise", function(b: any, st: any)
		local c = cloth(st, rgb(46, 10, 18))
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.22)
		box(b, "Base", Vector3.new(5.4, 0.6, 2.2), CFrame.new(0, 0.8, 0), look(darker(c.color, 0.25), c.material))
		box(b, "Seat", Vector3.new(5.0, 0.45, 2.0), CFrame.new(0.2, 1.32, 0), c)
		box(b, "Back", Vector3.new(1.4, 1.9, 2.0), CFrame.new(-2.3, 2.0, 0) * CFrame.Angles(0, 0, rad(14)), c)
		roll(b, "Bolster", 1.9, 0.7, Vector3.new(-1.8, 1.75, 0), look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Fabric), soft)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(b, "Leg", Vector3.new(0.16, 0.5, 0.16), CFrame.new(sx * 2.4, 0.25, sz * 0.85) * CFrame.Angles(rad(-sz * 8), 0, 0), accent, soft)
			end
		end
		F.sit(b, CFrame.new(0.8, 1.55, 0) * CFrame.Angles(0, rad(90), 0))
	end)

	F.define("desk", "The desk", function(b: any, st: any)
		local wood = F.tint(F.colour(st, "colour", rgb(52, 30, 20)), "Wood", Enum.Material.Wood)
		local inlay = look(F.colour(st, "accent", rgb(26, 70, 48)), Enum.Material.Leather)
		local brass = L.brass
		box(b, "Top", Vector3.new(5.6, 0.25, 2.8), CFrame.new(0, 3.0, 0), wood)
		box(b, "Inlay", Vector3.new(4.2, 0.04, 1.9), CFrame.new(0, 3.14, 0), inlay, trim)
		for _, sx in { -1, 1 } do
			box(b, "Pedestal", Vector3.new(1.5, 2.85, 2.6), CFrame.new(sx * 1.95, 1.45, 0), wood)
			for i = 0, 2 do
				box(b, "Drawer", Vector3.new(1.3, 0.75, 0.05), CFrame.new(sx * 1.95, 0.55 + i * 0.9, -1.32), look(darker(wood.color, 0.12), wood.material), trim)
				box(b, "Pull", Vector3.new(0.4, 0.06, 0.06), CFrame.new(sx * 1.95, 0.6 + i * 0.9, -1.38), brass, trim)
			end
		end
		-- A green banker's lamp, a pen stand and a leather blotter.
		post(b, "LampStem", 0.8, 0.1, Vector3.new(1.6, 3.12, 0.6), brass, trim)
		local shade = cyl(b, "LampShade", 1.0, 0.45, CFrame.new(1.6, 3.95, 0.45), look(rgb(26, 90, 58), Enum.Material.Glass, 0.2, 0.1), trim)
		F.light(b, shade, 0.9, 10, rgb(255, 222, 170))
		box(b, "Blotter", Vector3.new(1.6, 0.04, 1.1), CFrame.new(-0.6, 3.17, -0.2), look(rgb(20, 20, 22), Enum.Material.Leather), trim)
		post(b, "Pen", 0.5, 0.06, Vector3.new(-1.8, 3.13, 0.5), brass, trim)
		-- Its chair.
		box(b, "ChairSeat", Vector3.new(2.2, 0.4, 2.0), CFrame.new(0, 1.9, -2.2), look(rgb(26, 70, 48), Enum.Material.Leather))
		box(b, "ChairBack", Vector3.new(2.2, 2.0, 0.35), CFrame.new(0, 3.0, -3.1), look(rgb(26, 70, 48), Enum.Material.Leather))
		post(b, "ChairColumn", 1.7, 0.25, Vector3.new(0, 0, -2.2), L.steel, soft)
		F.sit(b, CFrame.new(0, 2.1, -2.2) * CFrame.Angles(0, rad(180), 0))
	end)

	F.define("globe", "The globe", function(b: any, st: any)
		local stand = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Wood)
		for i = 0, 2 do
			local a = rad(i * 120)
			box(b, "Leg", Vector3.new(0.14, 2.4, 0.14), CFrame.new(math.cos(a) * 0.7, 1.2, math.sin(a) * 0.7) * CFrame.Angles(math.sin(a) * rad(10), 0, -math.cos(a) * rad(10)), stand, soft)
		end
		disc(b, "Horizon", 2.6, 0.12, Vector3.new(0, 2.5, 0), L.brass, trim)
		local sea = look(F.colour(st, "colour", rgb(196, 170, 120)), Enum.Material.SmoothPlastic)
		ball(b, "Globe", 2.1, Vector3.new(0, 3.4, 0), sea)
		for i, p in { Vector3.new(0.7, 3.7, -0.75), Vector3.new(-0.5, 3.1, -0.9), Vector3.new(0.2, 4.1, -0.6) } do
			box(b, "Land", Vector3.new(0.5 + i * 0.1, 0.4, 0.06), CFrame.lookAt(p, Vector3.new(0, 3.4, 0)), look(rgb(120, 100, 60), Enum.Material.SmoothPlastic), trim)
		end
		cyl(b, "Meridian", 0.08, 2.5, CFrame.new(0, 3.4, 0) * CFrame.Angles(0, rad(90), rad(23)), L.brass, trim)
	end)
end

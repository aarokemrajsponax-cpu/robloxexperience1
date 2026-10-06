--!strict
-- The screening room, the games corner and the gym: a cinema screen, recliners, a gaming
-- setup, arcade cabinets, a popcorn cart; a treadmill, a weights rack, a bench, a punchbag, a
-- spin bike and a yoga corner. Screens are "Screen" parts (a guest's screen plays them).

return function(F: any)
	local L = F.Looks
	local box, cyl, post, ball, disc = F.box, F.cyl, F.post, F.ball, F.disc
	local trim, soft = F.trim, F.soft
	local rgb = Color3.fromRGB
	local look = F.look
	local rad = math.rad

	F.define("screen", "The cinema screen", function(b: any, st: any)
		local velvet = look(F.colour(st, "colour", rgb(90, 14, 30)), Enum.Material.Fabric)
		local accent = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.28)
		local w = st.width or 14
		local h = w * 9 / 16
		box(b, "Stage", Vector3.new(w + 4, 1.0, 2.6), CFrame.new(0, 0.5, 0.4), L.blackLacquer)
		box(b, "StageEdge", Vector3.new(w + 4, 0.1, 0.1), CFrame.new(0, 1.0, -0.9), accent, trim)
		box(b, "Frame", Vector3.new(w + 0.6, h + 0.6, 0.3), CFrame.new(0, 1.6 + h / 2, 1.5), L.blackLacquer)
		local screen = box(b, "Screen", Vector3.new(w, h, 0.05), CFrame.new(0, 1.6 + h / 2, 1.33), look(rgb(232, 232, 236), Enum.Material.SmoothPlastic), trim)
		screen:SetAttribute("Screen", true)
		-- Curtains drawn back either side, a pelmet across the top.
		for _, sx in { -1, 1 } do
			for i = 0, 3 do
				box(b, "Curtain", Vector3.new(0.7, h + 2, 0.35), CFrame.new(sx * (w / 2 + 0.6 + i * 0.55), 1.4 + (h + 2) / 2, 1.2 - (i % 2) * 0.2), velvet, soft)
			end
			-- Tall speakers.
			box(b, "Speaker", Vector3.new(1.4, 4.6, 1.2), CFrame.new(sx * (w / 2 + 3.4), 1.0 + 2.3, 0.2), L.blackLacquer)
			for j = 0, 2 do
				cyl(b, "Driver", 0.08, 0.6 + (j % 2) * 0.3, CFrame.new(sx * (w / 2 + 3.4), 1.8 + j * 1.3, -0.42) * CFrame.Angles(0, rad(90), 0), L.steel, trim)
			end
		end
		box(b, "Pelmet", Vector3.new(w + 5, 1.1, 0.6), CFrame.new(0, 1.6 + h + 1.4, 1.2), velvet)
		box(b, "PelmetTrim", Vector3.new(w + 5, 0.1, 0.62), CFrame.new(0, 1.6 + h + 0.9, 1.2), accent, trim)
		F.prompt(b, "UsePrompt", Vector3.new(0, 2.6, -1.4), "Start the film", "The screen", "film")
	end)

	F.define("recliners", "The recliners", function(b: any, st: any)
		local hide = F.tint(F.colour(st, "colour", rgb(22, 20, 20)), "Leather", Enum.Material.Leather)
		local glow = look(F.colour(st, "accent", rgb(255, 180, 110)), Enum.Material.Neon, nil, 0.2)
		for i = -1, 1 do
			local x = i * 3.4
			box(b, "Base", Vector3.new(3, 1.0, 3.4), CFrame.new(x, 0.6, 0), L.blackLacquer)
			box(b, "Seat", Vector3.new(2.3, 0.55, 2.6), CFrame.new(x, 1.35, -0.1), hide)
			box(b, "Back", Vector3.new(2.6, 3.2, 0.8), CFrame.new(x, 2.6, 1.35) * CFrame.Angles(rad(15), 0, 0), hide)
			box(b, "Headrest", Vector3.new(2.2, 0.8, 0.5), CFrame.new(x, 4.1, 1.75) * CFrame.Angles(rad(15), 0, 0), hide)
			box(b, "Footrest", Vector3.new(2.2, 0.4, 1.4), CFrame.new(x, 1.0, -1.9) * CFrame.Angles(rad(10), 0, 0), hide)
			for _, sx in { -1, 1 } do
				box(b, "Arm", Vector3.new(0.4, 1.0, 2.8), CFrame.new(x + sx * 1.3, 1.8, 0), hide)
			end
			disc(b, "CupHolder", 0.4, 0.06, Vector3.new(x + 1.3, 2.33, -0.8), L.steel, trim)
			box(b, "Underglow", Vector3.new(2.6, 0.05, 3), CFrame.new(x, 0.08, 0), glow, trim)
			F.sit(b, CFrame.new(x, 1.62, -0.1))
		end
	end)

	F.define("gaming", "The gaming setup", function(b: any, st: any)
		local rgbGlow = F.colour(st, "colour", rgb(140, 90, 255))
		local desk = L.blackLacquer
		box(b, "Desk", Vector3.new(7, 0.25, 2.8), CFrame.new(0, 2.9, 0.4), desk)
		for _, sx in { -1, 1 } do
			box(b, "DeskLeg", Vector3.new(0.3, 2.8, 2.4), CFrame.new(sx * 3.2, 1.4, 0.4), L.steel)
		end
		box(b, "Strip", Vector3.new(7, 0.06, 0.08), CFrame.new(0, 2.76, -0.95), look(rgbGlow, Enum.Material.Neon), trim)
		-- Three screens, the middle one straight, the outer two turned in.
		for i = -1, 1 do
			local cf = CFrame.new(i * 2.3, 4.6, 1.3) * CFrame.Angles(0, rad(i * 22), 0)
			box(b, "Monitor", Vector3.new(2.4, 1.45, 0.12), cf, L.blackLacquer)
			local screen = box(b, "Screen", Vector3.new(2.25, 1.3, 0.04), cf * CFrame.new(0, 0, -0.08), look(rgb(40, 60, 120), Enum.Material.Neon, nil, 0.35), trim)
			screen:SetAttribute("Screen", true)
			box(b, "Stand", Vector3.new(0.12, 1.4, 0.12), cf * CFrame.new(0, -1.25, 0.1), L.steel, trim)
		end
		box(b, "Keyboard", Vector3.new(1.8, 0.08, 0.6), CFrame.new(-0.3, 3.07, -0.2), look(rgbGlow:Lerp(rgb(20, 20, 24), 0.5), Enum.Material.Neon, nil, 0.4), trim)
		box(b, "Mouse", Vector3.new(0.3, 0.1, 0.45), CFrame.new(1.2, 3.08, -0.2), L.blackLacquer, trim)
		-- The tower, glass-sided with lit fans.
		box(b, "Tower", Vector3.new(1.0, 2.6, 2.2), CFrame.new(3.9, 1.3, 0.6), L.blackLacquer)
		box(b, "TowerGlass", Vector3.new(0.05, 2.2, 1.9), CFrame.new(3.38, 1.3, 0.6), L.smoked, trim)
		for j = 0, 2 do
			cyl(b, "Fan", 0.06, 0.55, CFrame.new(3.34, 0.6 + j * 0.65, 0.6), look(rgbGlow, Enum.Material.Neon, nil, 0.2), trim)
		end
		-- The chair.
		post(b, "ChairColumn", 1.5, 0.25, Vector3.new(0, 0.2, -2.1), L.steel, soft)
		for i = 0, 4 do
			box(b, "ChairStar", Vector3.new(0.16, 0.12, 1.3), CFrame.new(0, 0.2, -2.1) * CFrame.Angles(0, rad(i * 72), 0) * CFrame.new(0, 0, -0.6), L.steel, soft)
		end
		box(b, "ChairSeat", Vector3.new(2.1, 0.45, 2.0), CFrame.new(0, 1.85, -2.1), L.blackLeather)
		box(b, "ChairBack", Vector3.new(2.0, 3.0, 0.4), CFrame.new(0, 3.5, -3.15) * CFrame.Angles(rad(-10), 0, 0), L.blackLeather)
		box(b, "ChairStripe", Vector3.new(0.4, 2.8, 0.05), CFrame.new(0, 3.5, -2.93) * CFrame.Angles(rad(-10), 0, 0), look(rgbGlow, Enum.Material.Fabric), trim)
		local lamp = box(b, "Backglow", Vector3.new(7, 0.06, 0.06), CFrame.new(0, 3.05, 1.7), look(rgbGlow, Enum.Material.Neon), trim)
		F.light(b, lamp, 0.9, 10, rgbGlow)
		F.sit(b, CFrame.new(0, 2.08, -2.1) * CFrame.Angles(0, rad(180), 0))
	end)

	F.define("arcade", "The arcade cabinet", function(b: any, st: any)
		local model = st.model or "classic"
		local body = look(F.colour(st, "colour", rgb(30, 30, 70)), Enum.Material.SmoothPlastic, 0.1)
		local glow = F.colour(st, "accent", rgb(255, 60, 160))
		if model == "pinball" then
			box(b, "Table", Vector3.new(2.6, 0.8, 5), CFrame.new(0, 3.0, 0) * CFrame.Angles(rad(-6), 0, 0), body)
			box(b, "Playfield", Vector3.new(2.3, 0.05, 4.6), CFrame.new(0, 3.42, 0) * CFrame.Angles(rad(-6), 0, 0), look(rgb(30, 120, 200), Enum.Material.Neon, nil, 0.3), trim)
			box(b, "Glass", Vector3.new(2.3, 0.04, 4.6), CFrame.new(0, 3.5, 0) * CFrame.Angles(rad(-6), 0, 0), L.glass, trim)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					box(b, "Leg", Vector3.new(0.25, 2.8, 0.25), CFrame.new(sx * 1.1, 1.4, sz * 2.2), L.chrome, soft)
				end
			end
			box(b, "Backbox", Vector3.new(2.6, 2.2, 0.8), CFrame.new(0, 4.7, 2.4), body)
			local face = box(b, "Screen", Vector3.new(2.3, 1.8, 0.05), CFrame.new(0, 4.7, 1.98), look(glow, Enum.Material.Neon, nil, 0.2), trim)
			face:SetAttribute("Screen", true)
			for i = 0, 3 do
				ball(b, "Bumper", 0.35, Vector3.new(-0.6 + (i % 2) * 1.2, 3.6, 0.8 - (i // 2) * 0.9), look(rgb(255, 220, 60), Enum.Material.Neon), trim)
			end
		else
			box(b, "Body", Vector3.new(2.6, 6.2, 2.4), CFrame.new(0, 3.1, 0.3), body)
			for _, sx in { -1, 1 } do
				box(b, "SideArt", Vector3.new(0.06, 4.6, 2.2), CFrame.new(sx * 1.32, 3.4, 0.3), look(glow:Lerp(body.color, 0.4), Enum.Material.SmoothPlastic), trim)
			end
			box(b, "Panel", Vector3.new(2.6, 0.3, 1.4), CFrame.new(0, 3.5, -1.25) * CFrame.Angles(rad(-18), 0, 0), L.blackLacquer)
			ball(b, "Stick", 0.3, Vector3.new(-0.5, 3.95, -1.25), look(rgb(230, 40, 40), Enum.Material.SmoothPlastic), trim)
			post(b, "StickShaft", 0.35, 0.08, Vector3.new(-0.5, 3.62, -1.25), L.chrome, trim)
			for i = 0, 2 do
				disc(b, "Button", 0.26, 0.1, Vector3.new(0.2 + i * 0.35, 3.72, -1.3 + (i % 2) * 0.12), look(({ rgb(255, 220, 60), rgb(60, 200, 255), rgb(120, 255, 120) })[i + 1], Enum.Material.Neon), trim)
			end
			local screen = box(b, "Screen", Vector3.new(2.1, 1.7, 0.05), CFrame.new(0, 4.75, -0.85) * CFrame.Angles(rad(12), 0, 0), look(rgb(20, 30, 60), Enum.Material.Neon, nil, 0.3), trim)
			screen:SetAttribute("Screen", true)
			local marquee = box(b, "Marquee", Vector3.new(2.6, 0.9, 0.3), CFrame.new(0, 6.0, -0.75), look(glow, Enum.Material.Neon, nil, 0.1), trim)
			F.light(b, marquee, 0.7, 8, glow)
			if model == "racing" then
				box(b, "Seat", Vector3.new(2.0, 0.5, 1.8), CFrame.new(0, 1.7, -3.2), L.blackLeather)
				box(b, "SeatBack", Vector3.new(2.0, 2.2, 0.4), CFrame.new(0, 2.8, -4.1) * CFrame.Angles(rad(-12), 0, 0), L.blackLeather)
				box(b, "SeatBase", Vector3.new(1.6, 1.4, 1.6), CFrame.new(0, 0.7, -3.3), body)
				cyl(b, "Wheel", 0.15, 1.2, CFrame.new(0, 3.3, -1.8) * CFrame.Angles(0, rad(90), rad(-20)), L.blackLacquer, trim)
				F.sit(b, CFrame.new(0, 1.95, -3.2) * CFrame.Angles(0, rad(180), 0))
			end
		end
		F.prompt(b, "UsePrompt", Vector3.new(0, 3.8, -2.0), "Play", "The arcade", "arcade")
	end)

	F.define("popcorn", "The popcorn cart", function(b: any, st: any)
		local red = look(F.colour(st, "colour", rgb(180, 20, 30)), Enum.Material.SmoothPlastic, 0.1)
		box(b, "Cart", Vector3.new(2.6, 2.6, 1.8), CFrame.new(0, 1.7, 0), red)
		box(b, "Case", Vector3.new(2.2, 2.0, 1.6), CFrame.new(0, 4.0, 0), L.glass, soft)
		box(b, "Corn", Vector3.new(2.0, 0.8, 1.4), CFrame.new(0, 3.4, 0), look(rgb(250, 236, 180), Enum.Material.Sand), trim)
		box(b, "Roof", Vector3.new(2.6, 0.3, 2.0), CFrame.new(0, 5.15, 0), red)
		for _, sx in { -1, 1 } do
			cyl(b, "Wheel", 0.2, 1.0, CFrame.new(sx * 1.35, 0.5, 0), L.blackLacquer, trim)
		end
		local glow = box(b, "Lamp", Vector3.new(1.6, 0.08, 0.6), CFrame.new(0, 4.95, 0), L.warmGlow, trim)
		F.light(b, glow, 0.6, 6)
	end)

	-- The gym ---------------------------------------------------------------------------------
	F.define("treadmill", "The treadmill", function(b: any, st: any)
		local accent = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.25)
		box(b, "Deck", Vector3.new(2.8, 0.6, 6.4), CFrame.new(0, 0.4, 0), L.blackLacquer)
		box(b, "Belt", Vector3.new(2.2, 0.05, 5.8), CFrame.new(0, 0.73, 0.1), L.rubber, trim)
		for _, sx in { -1, 1 } do
			box(b, "Upright", Vector3.new(0.2, 3.8, 0.3), CFrame.new(sx * 1.3, 2.4, -2.8) * CFrame.Angles(rad(8), 0, 0), L.steel)
			box(b, "Rail", Vector3.new(0.15, 0.15, 2.2), CFrame.new(sx * 1.3, 3.7, -1.9), accent, trim)
		end
		box(b, "Console", Vector3.new(2.8, 1.2, 0.4), CFrame.new(0, 4.6, -3.0) * CFrame.Angles(rad(-25), 0, 0), L.blackLacquer)
		local screen = box(b, "Screen", Vector3.new(1.8, 0.8, 0.05), CFrame.new(0, 4.62, -2.82) * CFrame.Angles(rad(-25), 0, 0), look(rgb(80, 200, 255), Enum.Material.Neon, nil, 0.3), trim)
		screen:SetAttribute("Screen", true)
	end)

	F.define("weights", "The weights rack", function(b: any, st: any)
		local accent = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.3)
		for _, y in { 1.0, 2.2 } do
			box(b, "Tier", Vector3.new(6, 0.15, 1.2), CFrame.new(0, y, 0) * CFrame.Angles(rad(-10), 0, 0), L.steel)
		end
		for _, sx in { -1, 1 } do
			box(b, "End", Vector3.new(0.2, 2.6, 1.4), CFrame.new(sx * 3, 1.3, 0), L.steel)
		end
		for row, y in { 1.3, 2.5 } do
			for i = 0, 4 do
				local x = -2.4 + i * 1.2
				local d = 0.42 + (i + row) * 0.05
				cyl(b, "Bell", 0.5, d, CFrame.new(x, y, 0) * CFrame.Angles(0, rad(90), 0), if (i + row) % 2 == 0 then accent else L.blackLacquer, trim)
				cyl(b, "BellBar", 0.4, 0.14, CFrame.new(x, y, 0) * CFrame.Angles(0, rad(90), 0), L.chrome, trim)
			end
		end
	end)

	F.define("benchpress", "The bench", function(b: any, st: any)
		local pad = look(F.colour(st, "colour", rgb(22, 20, 20)), Enum.Material.Leather)
		box(b, "Pad", Vector3.new(1.4, 0.4, 5), CFrame.new(0, 1.7, 0), pad)
		box(b, "Frame", Vector3.new(0.4, 1.5, 4.4), CFrame.new(0, 0.75, 0), L.steel)
		for _, sx in { -1, 1 } do
			box(b, "Upright", Vector3.new(0.25, 4.2, 0.25), CFrame.new(sx * 1.6, 2.1, 2.0), L.steel)
			box(b, "Hook", Vector3.new(0.4, 0.15, 0.3), CFrame.new(sx * 1.6, 3.8, 1.8), L.steel, trim)
		end
		cyl(b, "Bar", 5.4, 0.18, CFrame.new(0, 3.9, 1.8), L.chrome)
		for _, sx in { -1, 1 } do
			for j = 0, 1 do
				cyl(b, "Plate", 0.25, 1.6 - j * 0.4, CFrame.new(sx * (2.2 + j * 0.27), 3.9, 1.8), L.blackLacquer, trim)
			end
		end
		F.sit(b, CFrame.new(0, 1.9, -0.6) * CFrame.Angles(0, rad(90), 0))
	end)

	F.define("punchbag", "The punchbag", function(b: any, st: any)
		local leather = look(F.colour(st, "colour", rgb(120, 20, 26)), Enum.Material.Leather)
		box(b, "Base", Vector3.new(3, 0.3, 3), CFrame.new(0, 0.15, 1.0), L.steel)
		box(b, "Post", Vector3.new(0.35, 9.4, 0.35), CFrame.new(0, 4.7, 2.2), L.steel)
		box(b, "Boom", Vector3.new(0.3, 0.3, 2.4), CFrame.new(0, 9.2, 1.1), L.steel)
		box(b, "Chain", Vector3.new(0.06, 1.4, 0.06), CFrame.new(0, 8.3, 0), L.chrome, trim)
		local bag = post(b, "Bag", 4.2, 1.6, Vector3.new(0, 3.4, 0), leather)
		bag:SetAttribute("Swings", true)
		disc(b, "Cap", 1.6, 0.2, Vector3.new(0, 7.7, 0), L.blackLacquer, trim)
		F.prompt(b, "UsePrompt", Vector3.new(0, 4.8, -1.4), "Hit it", "The punchbag", "punch")
	end)

	F.define("bike", "The spin bike", function(b: any, st: any)
		local accent = look(F.colour(st, "colour", rgb(214, 176, 92)), Enum.Material.Metal, 0.25)
		box(b, "Frame", Vector3.new(0.4, 0.4, 4.4), CFrame.new(0, 0.3, 0), L.steel)
		cyl(b, "Flywheel", 0.3, 2.2, CFrame.new(0, 1.4, -1.4), accent)
		box(b, "Down", Vector3.new(0.3, 3.2, 0.3), CFrame.new(0, 1.9, 0.3) * CFrame.Angles(rad(-15), 0, 0), L.steel)
		box(b, "Saddle", Vector3.new(0.8, 0.25, 1.3), CFrame.new(0, 3.5, 0.9), L.blackLeather)
		box(b, "BarPost", Vector3.new(0.25, 2.6, 0.25), CFrame.new(0, 2.5, -1.4) * CFrame.Angles(rad(10), 0, 0), L.steel)
		box(b, "Bars", Vector3.new(1.8, 0.15, 0.6), CFrame.new(0, 3.8, -1.7), L.blackLeather)
		F.sit(b, CFrame.new(0, 3.65, 0.9) * CFrame.Angles(0, 0, 0))
	end)

	F.define("yoga", "The yoga corner", function(b: any, st: any)
		local mat = look(F.colour(st, "colour", rgb(150, 120, 170)), Enum.Material.Rubber)
		for i = -1, 1 do
			box(b, "Mat", Vector3.new(2.2, 0.06, 6), CFrame.new(i * 2.8, 0.03, 0), look(mat.color:Lerp(rgb(255, 255, 255), (i + 1) * 0.12), mat.material), trim)
		end
		ball(b, "Ball", 2.2, Vector3.new(4.6, 1.1, 1.6), look(rgb(220, 210, 196), Enum.Material.Rubber), soft)
		for i = 0, 1 do
			box(b, "Block", Vector3.new(0.9, 0.6, 1.3), CFrame.new(4.4 + i * 1.0, 0.3, -1.6), look(rgb(196, 170, 120), Enum.Material.Wood), trim)
		end
		cyl(b, "Roll", 2.2, 0.5, CFrame.new(-4.6, 0.25, 1.5) * CFrame.Angles(0, rad(90), 0), look(rgb(120, 140, 120), Enum.Material.Rubber), trim)
		F.sit(b, CFrame.new(0, 0.25, 0))
	end)
end

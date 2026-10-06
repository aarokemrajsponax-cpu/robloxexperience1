--!strict
-- The kitchen and the dining room: a run of cabinets with an island, a dining table with its
-- chairs, an espresso bar and a wine wall.

return function(F: any)
	local L = F.Looks
	local box, cyl, post, ball, disc = F.box, F.cyl, F.post, F.ball, F.disc
	local trim, soft = F.trim, F.soft
	local rgb = Color3.fromRGB
	local look = F.look
	local rad = math.rad

	local function finish(st: any): (any, any, any)
		local model = st.model or "marble"
		if model == "noir" then
			return L.blackLacquer, L.blackMarble, look(rgb(214, 176, 92), Enum.Material.Metal, 0.3)
		elseif model == "walnut" then
			return L.walnut, L.whiteMarble, look(rgb(36, 37, 41), Enum.Material.Metal, 0.2)
		end
		return L.ivoryLacquer, L.whiteMarble, look(rgb(214, 176, 92), Enum.Material.Metal, 0.3)
	end

	local function stool(b: any, x: number, z: number, seat: any, metal: any)
		post(b, "StoolPost", 2.5, 0.16, Vector3.new(x, 0.1, z), metal, soft)
		disc(b, "StoolFoot", 1.1, 0.1, Vector3.new(x, 0.05, z), metal, soft)
		disc(b, "StoolRing", 1.0, 0.06, Vector3.new(x, 1.1, z), metal, trim)
		disc(b, "StoolSeat", 1.3, 0.35, Vector3.new(x, 2.75, z), seat)
	end

	-- Cabinets along the back (+Z) with an island in front; three stools on the island's front.
	F.define("kitchen", "The kitchen", function(b: any, st: any)
		local body, top, metal = finish(st)
		local w = st.width or 14
		local zb = 3.4 -- the back run's centre
		box(b, "BaseRun", Vector3.new(w, 3.0, 2.2), CFrame.new(0, 1.65, zb), body)
		box(b, "Toe", Vector3.new(w - 0.2, 0.15, 2.0), CFrame.new(0, 0.08, zb + 0.1), L.blackLacquer, trim)
		box(b, "Counter", Vector3.new(w + 0.1, 0.25, 2.4), CFrame.new(0, 3.27, zb - 0.05), top)
		box(b, "Splash", Vector3.new(w, 3.2, 0.12), CFrame.new(0, 5.0, zb + 1.04), top)
		box(b, "Uppers", Vector3.new(w, 2.8, 1.3), CFrame.new(0, 8.0, zb + 0.45), body)
		for i = 0, 5 do
			local x = -w / 2 + 1.15 + i * (w - 2.3) / 5
			box(b, "Door", Vector3.new(2.0, 2.6, 0.05), CFrame.new(x, 1.75, zb - 1.12), look(body.color:Lerp(Color3.new(0, 0, 0), 0.06), body.material), trim)
			box(b, "Pull", Vector3.new(0.9, 0.06, 0.06), CFrame.new(x, 2.85, zb - 1.18), metal, trim)
			box(b, "UpperDoor", Vector3.new(2.0, 2.5, 0.05), CFrame.new(x, 8.0, zb - 0.22), look(body.color:Lerp(Color3.new(0, 0, 0), 0.06), body.material), trim)
		end
		-- A range with its hood, and the sink.
		box(b, "Range", Vector3.new(3, 0.08, 2), CFrame.new(-2.5, 3.43, zb - 0.1), L.blackLacquer, trim)
		for _, o in { { -3.2, -0.6 }, { -1.8, -0.6 }, { -3.2, 0.4 }, { -1.8, 0.4 } } do
			disc(b, "Burner", 0.7, 0.05, Vector3.new(o[1], 3.49, zb + o[2]), L.steel, trim)
		end
		box(b, "Hood", Vector3.new(3.4, 1.4, 1.6), CFrame.new(-2.5, 6.4, zb + 0.2), metal)
		box(b, "Sink", Vector3.new(2.2, 0.06, 1.4), CFrame.new(3, 3.42, zb - 0.1), L.steel, trim)
		post(b, "Faucet", 1.1, 0.14, Vector3.new(3, 3.4, zb + 0.75), metal, trim)
		box(b, "FaucetSpout", Vector3.new(0.12, 0.12, 0.8), CFrame.new(3, 4.5, zb + 0.4), metal, trim)
		-- A tall fridge column at the end.
		box(b, "Fridge", Vector3.new(3, 9.6, 2.4), CFrame.new(w / 2 + 1.5, 4.8, zb), body)
		box(b, "FridgeSeam", Vector3.new(0.04, 9, 0.06), CFrame.new(w / 2 + 1.5, 4.8, zb - 1.21), L.blackLacquer, trim)
		for _, sx in { -0.25, 0.25 } do
			box(b, "FridgePull", Vector3.new(0.08, 2.4, 0.1), CFrame.new(w / 2 + 1.5 + sx, 5, zb - 1.28), metal, trim)
		end
		-- Things on the counter.
		disc(b, "Bowl", 1.3, 0.4, Vector3.new(1, 3.6, zb - 0.2), L.whiteMarble, trim)
		for i = 0, 2 do
			ball(b, "Lemon", 0.42, Vector3.new(0.8 + i * 0.3, 3.85, zb - 0.2 + (i % 2) * 0.2), look(rgb(240, 210, 60), Enum.Material.SmoothPlastic), trim)
		end
		box(b, "Board", Vector3.new(1.6, 0.12, 1.0), CFrame.new(5, 3.46, zb - 0.3), L.oak, trim)
		-- The island.
		box(b, "Island", Vector3.new(8, 3.0, 2.8), CFrame.new(0, 1.65, -2.2), body)
		box(b, "IslandTop", Vector3.new(8.6, 0.25, 3.6), CFrame.new(0, 3.27, -2.4), top)
		for _, x in { -2.6, 0, 2.6 } do
			stool(b, x, -4.6, look(F.colour(st, "colour", rgb(26, 70, 48)), Enum.Material.Leather), metal)
			F.sit(b, CFrame.new(x, 2.95, -4.6) * CFrame.Angles(0, rad(180), 0))
		end
		-- Pendants over the island.
		for _, x in { -2.6, 0, 2.6 } do
			box(b, "Cord", Vector3.new(0.04, 3.2, 0.04), CFrame.new(x, 9.8, -2.4), L.steel, trim)
			local shade = ball(b, "Pendant", 0.9, Vector3.new(x, 8.0, -2.4), look(metal.color, Enum.Material.Metal, 0.3), trim)
			local bulb = ball(b, "Bulb", 0.35, Vector3.new(x, 7.65, -2.4), L.warmGlow, trim)
			if x == 0 then
				F.spotLight(b, bulb, Enum.NormalId.Bottom, 1.2, 12, 90)
			end
			local _ = shade
		end
	end)

	F.define("dining", "The dining table", function(b: any, st: any)
		local model = st.model or "walnut"
		local metal = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.28)
		local seatLook = look(F.colour(st, "colour", rgb(90, 20, 30)), Enum.Material.Fabric)
		local len, width = 10, 4
		if model == "marble" then
			box(b, "Top", Vector3.new(len, 0.3, width), CFrame.new(0, 3.05, 0), L.whiteMarble)
			for _, sx in { -1, 1 } do
				post(b, "Pedestal", 2.9, 1.0, Vector3.new(sx * 3, 0, 0), L.whiteMarble)
				disc(b, "Foot", 1.8, 0.2, Vector3.new(sx * 3, 0.1, 0), L.whiteMarble)
			end
		elseif model == "glass" then
			box(b, "Top", Vector3.new(len, 0.15, width), CFrame.new(0, 3.1, 0), L.glass, soft)
			for _, sx in { -1, 1 } do
				box(b, "Frame", Vector3.new(0.3, 3, width - 0.6), CFrame.new(sx * (len / 2 - 1), 1.5, 0), metal)
				box(b, "FrameFoot", Vector3.new(1.2, 0.2, width - 0.4), CFrame.new(sx * (len / 2 - 1), 0.1, 0), metal)
			end
		else
			box(b, "Top", Vector3.new(len, 0.35, width), CFrame.new(0, 3.0, 0), L.walnut)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					box(b, "Leg", Vector3.new(0.4, 2.85, 0.4), CFrame.new(sx * (len / 2 - 0.6), 1.42, sz * (width / 2 - 0.5)), L.walnut)
				end
			end
		end
		-- The centrepiece: a candelabra between two low bowls of flowers.
		post(b, "Candelabra", 1.4, 0.2, Vector3.new(0, 3.2, 0), metal, trim)
		for i = -1, 1 do
			box(b, "CandleArm", Vector3.new(0.9, 0.08, 0.08), CFrame.new(i * 0.45, 4.35, 0), metal, trim)
			post(b, "Candle", 0.7, 0.14, Vector3.new(i * 0.9, 4.4, 0), L.paper, trim)
			ball(b, "Flame", 0.14, Vector3.new(i * 0.9, 5.2, 0), L.warmGlow, trim)
		end
		for _, x in { -2.8, 2.8 } do
			disc(b, "FlowerBowl", 1.2, 0.35, Vector3.new(x, 3.35, 0), metal, trim)
			for i = 0, 4 do
				ball(b, "Bloom", 0.38, Vector3.new(x - 0.4 + i * 0.2, 3.65, (i % 2) * 0.25 - 0.1), look(({ rgb(240, 236, 230), rgb(236, 180, 190), rgb(200, 40, 60) })[i % 3 + 1], Enum.Material.SmoothPlastic), trim)
			end
		end
		-- Six chairs: two each side and one at each end.
		local spots = { { -2.6, -1 }, { 0, -1 }, { 2.6, -1 }, { -2.6, 1 }, { 0, 1 }, { 2.6, 1 } }
		for _, s in spots do
			local x, side = s[1], s[2]
			local z = side * (width / 2 + 1.0)
			local face = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, 0))
			box(b, "ChairSeat", Vector3.new(1.9, 0.35, 1.8), face * CFrame.new(0, 1.85, 0), seatLook)
			box(b, "ChairBack", Vector3.new(1.9, 2.4, 0.3), face * CFrame.new(0, 3.1, 0.85), seatLook)
			box(b, "ChairFrame", Vector3.new(2.0, 0.25, 0.4), face * CFrame.new(0, 4.35, 0.85), metal, soft)
			for _, lx in { -0.8, 0.8 } do
				for _, lz in { -0.7, 0.7 } do
					box(b, "ChairLeg", Vector3.new(0.14, 1.7, 0.14), face * CFrame.new(lx, 0.85, lz), metal, soft)
				end
			end
			F.sit(b, face * CFrame.new(0, 2.02, -0.05))
		end
	end)

	F.define("espresso", "The espresso bar", function(b: any, st: any)
		local body, top, metal = finish(st)
		box(b, "Counter", Vector3.new(5, 3.0, 2), CFrame.new(0, 1.6, 0), body)
		box(b, "Top", Vector3.new(5.1, 0.2, 2.1), CFrame.new(0, 3.2, 0), top)
		-- The machine: a chrome body, two group heads, a steam wand.
		box(b, "Machine", Vector3.new(2.4, 1.6, 1.4), CFrame.new(-0.6, 4.1, 0.2), L.chrome)
		box(b, "MachineTop", Vector3.new(2.4, 0.15, 1.4), CFrame.new(-0.6, 4.98, 0.2), metal, trim)
		for _, x in { -1.1, -0.1 } do
			post(b, "Group", 0.3, 0.35, Vector3.new(x, 3.55, -0.3), L.chrome, trim)
			box(b, "Handle", Vector3.new(0.12, 0.12, 0.7), CFrame.new(x, 3.6, -0.75), L.blackLacquer, trim)
			post(b, "Cup", 0.3, 0.3, Vector3.new(x, 3.3, -0.35), L.paper, trim)
		end
		box(b, "Wand", Vector3.new(0.06, 0.8, 0.06), CFrame.new(0.5, 3.8, -0.4), L.chrome, trim)
		local gauge = disc(b, "Gauge", 0.4, 0.05, Vector3.new(-0.6, 4.4, -0.52), L.paper, trim)
		gauge.CFrame = gauge.CFrame * CFrame.Angles(rad(90), 0, 0)
		-- The grinder and a row of cups.
		post(b, "Grinder", 1.0, 0.6, Vector3.new(1.4, 3.3, 0.3), L.blackLacquer, trim)
		box(b, "Hopper", Vector3.new(0.5, 0.6, 0.5), CFrame.new(1.4, 4.6, 0.3), L.smoked, trim)
		for i = 0, 3 do
			post(b, "Cup", 0.28, 0.32, Vector3.new(-2.0 + i * 0.4, 3.3, 0.6), L.paper, trim)
		end
		F.prompt(b, "UsePrompt", Vector3.new(-0.6, 4.2, -1.4), "Make a coffee", "The espresso machine", "espresso")
	end)

	F.define("wine", "The wine wall", function(b: any, st: any)
		local _, _, metal = finish(st)
		local w, h, d = 7, 9, 1.6
		box(b, "Case", Vector3.new(w, h, d), CFrame.new(0, h / 2, 0.1), L.blackLacquer)
		box(b, "Glass", Vector3.new(w - 0.4, h - 0.6, 0.06), CFrame.new(0, h / 2, -d / 2 + 0.05), L.glass, soft)
		box(b, "Inside", Vector3.new(w - 0.4, h - 0.6, 0.06), CFrame.new(0, h / 2, d / 2 - 0.05), look(rgb(60, 36, 24), Enum.Material.Wood), trim)
		box(b, "Mullion", Vector3.new(0.1, h - 0.6, 0.08), CFrame.new(0, h / 2, -d / 2 + 0.02), metal, trim)
		local colours = { rgb(90, 14, 30), rgb(120, 30, 40), rgb(200, 190, 140), rgb(70, 10, 20) }
		for row = 0, 7 do
			for col = 0, 6 do
				local c = colours[(row + col) % #colours + 1]
				cyl(b, "Bottle", 1.0, 0.3, CFrame.new(-2.7 + col * 0.9, 0.9 + row * 1.0, 0.2) * CFrame.Angles(0, rad(90), 0), look(c, Enum.Material.Glass, 0.2, 0.15), trim)
			end
		end
		local glow = box(b, "Glow", Vector3.new(w - 0.6, 0.05, 0.1), CFrame.new(0, h - 0.4, -0.3), look(rgb(255, 200, 150), Enum.Material.Neon, nil, 0.2), trim)
		F.spotLight(b, glow, Enum.NormalId.Bottom, 0.9, 10, 100, rgb(255, 196, 150))
	end)
end

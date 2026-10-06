--!strict
-- The bath and spa: bathtubs, the rain shower, the double vanity, the sauna and the massage
-- chair. Water is glass-blue; what flows (the shower, the sauna's steam) is drawn on the guest's
-- own screen when they use it (UsePrompt "shower", "sauna", "massage").

return function(F: any)
	local L = F.Looks
	local box, cyl, post, ball, disc = F.box, F.cyl, F.post, F.ball, F.disc
	local trim, soft = F.trim, F.soft
	local rgb = Color3.fromRGB
	local look = F.look
	local rad = math.rad

	-- A tub's body in plan: a box between two upright half-round ends (along X).
	local function oval(b: any, name: string, len: number, width: number, height: number, y0: number, lk: any, o: any?)
		box(b, name, Vector3.new(len - width, height, width), CFrame.new(0, y0 + height / 2, 0), lk, o)
		for _, sx in { -1, 1 } do
			post(b, name .. "End", height, width, Vector3.new(sx * (len - width) / 2, y0, 0), lk, o)
		end
	end

	-- The rim of an oval tub: straight sides and half-round ends of short lengths, `thick` wide,
	-- from y0 up `h`.
	local function rim(b: any, len: number, width: number, y0: number, h: number, thick: number, lk: any)
		local straight = len - width
		for _, sz in { -1, 1 } do
			box(b, "Rim", Vector3.new(straight + 0.02, h, thick), CFrame.new(0, y0 + h / 2, sz * (width / 2 - thick / 2)), lk)
		end
		local r = width / 2 - thick / 2
		local n = 8
		for _, sx in { -1, 1 } do
			for i = 0, n - 1 do
				local a = -math.pi / 2 + (i + 0.5) / n * math.pi
				local len2 = math.pi * r / n + 0.04
				local cx, cz = sx * (straight / 2 + math.cos(a) * r), math.sin(a) * r
				box(b, "Rim", Vector3.new(thick, h, len2), CFrame.new(cx, y0 + h / 2, cz) * CFrame.Angles(0, sx * -a, 0), lk)
			end
		end
	end

	F.define("bathtub", "The bathtub", function(b: any, st: any)
		local model = st.model or "clawfoot"
		local accent = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.3)
		local water = look(rgb(150, 200, 214), Enum.Material.Glass, 0.3, 0.4)
		if model == "sunken" then
			-- A marble dais with steps, framing a basin of water set into it.
			local bw, bd = 5.4, 3.0
			local W, D, H = 7.6, 5.2, 1.6
			for _, sz in { -1, 1 } do
				box(b, "Dais", Vector3.new(W, H, (D - bd) / 2), CFrame.new(0, H / 2, 0.3 + sz * (bd / 2 + (D - bd) / 4)), L.whiteMarble)
			end
			for _, sx in { -1, 1 } do
				box(b, "Dais", Vector3.new((W - bw) / 2, H, bd), CFrame.new(sx * (bw / 2 + (W - bw) / 4), H / 2, 0.3), L.whiteMarble)
			end
			box(b, "Basin", Vector3.new(bw, 0.3, bd), CFrame.new(0, 0.15, 0.3), look(rgb(150, 200, 214), Enum.Material.SmoothPlastic, 0.1), trim)
			local pool = box(b, "Water", Vector3.new(bw, 1.1, bd), CFrame.new(0, 0.85, 0.3), water, { collide = false, query = false, shadow = false })
			pool:SetAttribute("Water", true)
			box(b, "Step", Vector3.new(4, 0.8, 1.4), CFrame.new(0, 0.4, -D / 2 - 0.4), L.whiteMarble)
			for _, sx in { -1, 1 } do
				post(b, "Column", 6, 0.6, Vector3.new(sx * (W / 2 - 0.4), H, D / 2 - 0.1), L.whiteMarble)
				post(b, "Candle", 0.5, 0.25, Vector3.new(sx * (W / 2 - 0.5), H, -D / 2 + 0.6), L.paper, trim)
				ball(b, "Flame", 0.14, Vector3.new(sx * (W / 2 - 0.5), H + 0.6, -D / 2 + 0.6), L.warmGlow, trim)
			end
			local glow = box(b, "Glow", Vector3.new(bw - 0.4, 0.2, 0.06), CFrame.new(0, 0.9, 0.3 + bd / 2 - 0.05), look(rgb(150, 220, 255), Enum.Material.Neon, nil, 0.2), trim)
			F.light(b, glow, 0.9, 10, rgb(170, 220, 255))
			box(b, "Spout", Vector3.new(0.3, 0.2, 0.8), CFrame.new(0, H + 0.3, 0.3 + bd / 2 + 0.2), accent, trim)
			F.sit(b, CFrame.new(-1.2, 0.6, 0.3))
			F.sit(b, CFrame.new(1.2, 0.6, 0.3))
			return
		end
		local stone = model == "stone"
		local shell = if stone then L.travertine else look(F.colour(st, "colour", rgb(240, 238, 232)), Enum.Material.SmoothPlastic, 0.12)
		local len, width, height = 6.2, 3.0, 1.9
		local y0 = if stone then 0 else 0.5
		local lip = 0.45 -- the rim above the water
		oval(b, "Tub", len, width, height - lip, y0, shell)
		oval(b, "Water", len - 0.4, width - 0.4, 0.08, y0 + height - lip, water, soft)
		rim(b, len, width, y0 + height - lip, lip, 0.22, shell)
		if not stone then
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					ball(b, "Claw", 0.5, Vector3.new(sx * 2.2, 0.25, sz * 0.9), accent, soft)
				end
			end
			-- The tub's outside in a colour, inside white.
			oval(b, "Skin", len + 0.08, width + 0.08, 1.2, y0 + 0.1, look(F.colour(st, "outside", rgb(26, 26, 30)), Enum.Material.SmoothPlastic, 0.15), soft)
		end
		-- A floor-standing tap at the end.
		post(b, "Tap", 3.0, 0.2, Vector3.new(len / 2 + 0.4, 0, 0), accent)
		box(b, "Spout", Vector3.new(0.9, 0.15, 0.15), CFrame.new(len / 2 - 0.05, 3.0, 0), accent, trim)
		box(b, "Tray", Vector3.new(0.5, 0.06, width + 0.5), CFrame.new(-0.6, y0 + height + 0.03, 0), L.teak, trim)
		post(b, "Candle", 0.35, 0.2, Vector3.new(-0.6, y0 + height + 0.06, 0.6), L.paper, trim)
		F.sit(b, CFrame.new(-0.6, y0 + 0.8, 0) * CFrame.Angles(0, rad(-90), 0))
	end)

	F.define("shower", "The shower", function(b: any, st: any)
		local accent = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.3)
		local tile = look(F.colour(st, "colour", rgb(220, 214, 204)), Enum.Material.Marble, 0.06)
		local w, d, h = 5, 4.4, 9
		box(b, "Tray", Vector3.new(w, 0.25, d), CFrame.new(0, 0.12, 0), L.blackMarble)
		box(b, "Drain", Vector3.new(w - 0.6, 0.02, 0.18), CFrame.new(0, 0.26, d / 2 - 0.5), accent, trim)
		box(b, "BackWall", Vector3.new(w, h, 0.3), CFrame.new(0, h / 2, d / 2 - 0.15), tile)
		box(b, "SideWall", Vector3.new(0.3, h, d), CFrame.new(-w / 2 + 0.15, h / 2, 0), tile)
		box(b, "Niche", Vector3.new(1.6, 0.9, 0.1), CFrame.new(-0.6, 4, d / 2 - 0.33), look(rgb(190, 150, 74), Enum.Material.Metal, 0.25), trim)
		-- Glass on the open side and front (the door).
		box(b, "GlassSide", Vector3.new(0.08, h - 1, d - 0.4), CFrame.new(w / 2 - 0.04, (h - 1) / 2 + 0.25, 0.2), L.glass, soft)
		box(b, "GlassDoor", Vector3.new(w * 0.45, h - 1, 0.08), CFrame.new(w * 0.2, (h - 1) / 2 + 0.25, -d / 2 + 0.05), L.glass, soft)
		box(b, "Frame", Vector3.new(0.1, h - 1, 0.1), CFrame.new(w / 2 - 0.05, (h - 1) / 2 + 0.25, -d / 2 + 0.05), accent, trim)
		box(b, "DoorPull", Vector3.new(0.08, 1.2, 0.08), CFrame.new(w * 0.02, 4.2, -d / 2 - 0.05), accent, trim)
		-- The rain head and its arm, and a hand shower.
		box(b, "Arm", Vector3.new(0.12, 0.12, 2.2), CFrame.new(0, h - 1.2, d / 2 - 1.2), accent, trim)
		local head = disc(b, "RainHead", 1.6, 0.12, Vector3.new(0, h - 1.35, 0.6), accent, trim)
		head:SetAttribute("ShowerHead", true)
		post(b, "Valve", 0.3, 0.3, Vector3.new(-1.2, 4.2, d / 2 - 0.4), accent, trim)
		F.prompt(b, "UsePrompt", Vector3.new(0, 4.5, -d / 2 - 0.4), "Turn on", "The rain shower", "shower")
	end)

	F.define("vanity", "The vanity", function(b: any, st: any)
		local wood = F.tint(F.colour(st, "colour", rgb(40, 26, 20)), st.material or "Wood", Enum.Material.Wood)
		local accent = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.3)
		local top = if st.model == "black" then L.blackMarble else L.whiteMarble
		local w = 8
		box(b, "Cabinet", Vector3.new(w, 2.6, 2), CFrame.new(0, 1.6, 0), wood)
		box(b, "Counter", Vector3.new(w + 0.2, 0.25, 2.2), CFrame.new(0, 3.02, 0), top)
		for _, x in { -w / 4, w / 4 } do
			cyl(b, "Basin", 0.32, 1.5, CFrame.new(x, 3.25, -0.1) * CFrame.Angles(0, 0, rad(90)), L.ivoryLacquer, soft)
			post(b, "Tap", 0.8, 0.12, Vector3.new(x, 3.15, 0.75), accent, trim)
			box(b, "TapSpout", Vector3.new(0.1, 0.1, 0.6), CFrame.new(x, 3.9, 0.5), accent, trim)
			box(b, "DoorPair", Vector3.new(w / 2 - 0.4, 2.0, 0.05), CFrame.new(x, 1.6, -1.02), look(wood.color:Lerp(Color3.new(0, 0, 0), 0.12), wood.material), trim)
			box(b, "Pull", Vector3.new(0.6, 0.06, 0.06), CFrame.new(x, 2.4, -1.08), accent, trim)
			-- A round mirror over each basin, lit behind.
			cyl(b, "MirrorRing", 0.12, 3.2, CFrame.new(x, 6.2, 0.9) * CFrame.Angles(0, rad(90), 0), accent)
			cyl(b, "Mirror", 0.05, 2.9, CFrame.new(x, 6.2, 0.82) * CFrame.Angles(0, rad(90), 0), L.mirror, trim)
		end
		local glow = box(b, "Backlight", Vector3.new(w - 1, 0.05, 0.08), CFrame.new(0, 8.0, 0.92), L.warmGlow, trim)
		F.spotLight(b, glow, Enum.NormalId.Bottom, 0.9, 9, 110)
		-- Towels rolled on the counter, a soap dish, a sprig of green.
		for i = 0, 2 do
			cyl(b, "Towel", 0.9, 0.45, CFrame.new(-0.4 + i * 0.4, 3.38, -0.6) * CFrame.Angles(0, rad(90), 0), L.cream, trim)
		end
		post(b, "Vase", 0.7, 0.3, Vector3.new(0.9, 3.15, 0.6), L.glass, trim)
		box(b, "Sprig", Vector3.new(0.05, 1.0, 0.4), CFrame.new(0.9, 4.1, 0.6), L.leaf, trim)
	end)

	F.define("sauna", "The sauna", function(b: any, st: any)
		local cedar = F.tint(F.colour(st, "colour", rgb(170, 116, 70)), "WoodPlanks", Enum.Material.WoodPlanks)
		local dark = look(cedar.color:Lerp(Color3.new(0, 0, 0), 0.3), cedar.material)
		local w, d, h = 7.6, 6.4, 8.4
		-- The cabin: walls of cedar, a glass front with a door gap.
		box(b, "Floor", Vector3.new(w, 0.3, d), CFrame.new(0, 0.15, 0), dark)
		box(b, "Roof", Vector3.new(w + 0.4, 0.4, d + 0.4), CFrame.new(0, h + 0.2, 0), dark)
		box(b, "BackWall", Vector3.new(w, h, 0.4), CFrame.new(0, h / 2, d / 2 - 0.2), cedar)
		for _, sx in { -1, 1 } do
			box(b, "SideWall", Vector3.new(0.4, h, d), CFrame.new(sx * (w / 2 - 0.2), h / 2, 0), cedar)
		end
		box(b, "Front", Vector3.new(w * 0.5, h - 0.3, 0.12), CFrame.new(-w * 0.2, h / 2, -d / 2 + 0.06), look(rgb(230, 190, 150), Enum.Material.Glass, 0.2, 0.55), soft)
		box(b, "Lintel", Vector3.new(w, 1.0, 0.4), CFrame.new(0, h - 0.5, -d / 2 + 0.2), cedar)
		box(b, "DoorPost", Vector3.new(0.3, h - 1, 0.4), CFrame.new(w * 0.07, (h - 1) / 2, -d / 2 + 0.2), cedar)
		-- Two tiers of benches inside.
		box(b, "BenchLow", Vector3.new(w - 0.8, 0.3, 1.6), CFrame.new(0, 1.7, d / 2 - 2.6), cedar)
		box(b, "BenchHigh", Vector3.new(w - 0.8, 0.3, 1.6), CFrame.new(0, 3.2, d / 2 - 1.2), cedar)
		box(b, "BenchFace", Vector3.new(w - 0.8, 1.5, 0.15), CFrame.new(0, 2.45, d / 2 - 2.0), dark)
		-- The stove and its stones, glowing.
		box(b, "Stove", Vector3.new(1.4, 2.2, 1.2), CFrame.new(-w / 2 + 1.3, 1.4, -d / 2 + 1.4), L.steel)
		for i = 0, 5 do
			ball(b, "Stone", 0.4, Vector3.new(-w / 2 + 1.0 + (i % 3) * 0.3, 2.65 + (i // 3) * 0.2, -d / 2 + 1.2 + (i % 2) * 0.3), L.stone, trim)
		end
		local glow = box(b, "Embers", Vector3.new(1.0, 0.1, 0.9), CFrame.new(-w / 2 + 1.3, 2.52, -d / 2 + 1.4), L.ember, trim)
		F.light(b, glow, 1.0, 12, rgb(255, 150, 80))
		box(b, "Bucket", Vector3.new(0.6, 0.5, 0.6), CFrame.new(-w / 2 + 2.4, 0.55, -d / 2 + 1.0), cedar, trim)
		F.sit(b, CFrame.new(-1.6, 1.85, d / 2 - 2.6) * CFrame.Angles(0, 0, 0))
		F.sit(b, CFrame.new(1.6, 1.85, d / 2 - 2.6))
		F.sit(b, CFrame.new(0, 3.35, d / 2 - 1.2))
		F.prompt(b, "UsePrompt", Vector3.new(-w / 2 + 2.2, 3, -d / 2 - 0.6), "Pour water", "The sauna's stones", "sauna")
	end)

	F.define("massage", "The massage chair", function(b: any, st: any)
		local hide = F.tint(F.colour(st, "colour", rgb(30, 28, 30)), "Leather", Enum.Material.Leather)
		local shell = look(F.colour(st, "accent", rgb(214, 176, 92)), Enum.Material.Metal, 0.3)
		box(b, "Base", Vector3.new(3.2, 0.8, 4.4), CFrame.new(0, 0.4, 0.2), L.blackLacquer)
		box(b, "Seat", Vector3.new(2.4, 0.6, 2.4), CFrame.new(0, 1.4, 0.2) * CFrame.Angles(rad(-8), 0, 0), hide)
		box(b, "Back", Vector3.new(2.4, 3.4, 0.7), CFrame.new(0, 2.9, 1.7) * CFrame.Angles(rad(28), 0, 0), hide)
		box(b, "Headrest", Vector3.new(1.6, 0.9, 0.6), CFrame.new(0, 4.6, 2.6) * CFrame.Angles(rad(28), 0, 0), hide)
		box(b, "LegRest", Vector3.new(2.0, 2.2, 0.7), CFrame.new(0, 0.9, -1.4) * CFrame.Angles(rad(35), 0, 0), hide)
		for _, sx in { -1, 1 } do
			box(b, "Arm", Vector3.new(0.7, 1.6, 3.0), CFrame.new(sx * 1.55, 1.9, 0.4), shell)
			box(b, "ArmPad", Vector3.new(0.6, 0.25, 2.6), CFrame.new(sx * 1.55, 2.78, 0.4), hide)
		end
		local panel = box(b, "Control", Vector3.new(0.5, 0.06, 0.8), CFrame.new(1.55, 2.95, -0.6), look(rgb(120, 200, 255), Enum.Material.Neon, nil, 0.3), trim)
		local _ = panel
		F.sit(b, CFrame.new(0, 1.75, 0.3))
		F.prompt(b, "UsePrompt", Vector3.new(1.8, 3.2, -1.2), "Start", "The massage chair", "massage")
	end)
end

--!strict
-- The bedroom: beds (its head against the wall at +Z), the nightstands either side of it, a
-- dresser with its glass, and a bench for the foot of the bed.

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

	-- The bed itself: base, mattress, duvet, pillows, a throw. Head at +Z. Returns the top.
	local function bedding(b: any, w: number, len: number, baseLook: any, duvet: Color3, throw: Color3): number
		box(b, "Base", Vector3.new(w, 1.1, len), CFrame.new(0, 0.85, 0), baseLook)
		box(b, "Mattress", Vector3.new(w - 0.3, 0.7, len - 0.3), CFrame.new(0, 1.75, 0), L.cream)
		-- The duvet over the foot two-thirds, turned down at the top.
		local dl = len * 0.68
		box(b, "Duvet", Vector3.new(w - 0.1, 0.35, dl), CFrame.new(0, 2.15, -len / 2 + dl / 2 + 0.05), look(duvet, Enum.Material.Fabric))
		box(b, "DuvetFold", Vector3.new(w - 0.1, 0.4, 0.5), CFrame.new(0, 2.2, -len / 2 + dl + 0.25), look(duvet:Lerp(rgb(255, 255, 255), 0.25), Enum.Material.Fabric))
		for _, sx in { -1, 1 } do
			box(b, "DuvetSide", Vector3.new(0.12, 0.9, dl), CFrame.new(sx * (w / 2), 1.85, -len / 2 + dl / 2 + 0.05), look(duvet, Enum.Material.Fabric), soft)
		end
		-- A throw across the foot.
		box(b, "Throw", Vector3.new(w + 0.1, 0.12, 1.6), CFrame.new(0, 2.36, -len / 2 + 1.2), look(throw, Enum.Material.Fabric), soft)
		box(b, "ThrowFall", Vector3.new(w + 0.1, 0.8, 0.1), CFrame.new(0, 1.98, -len / 2 - 0.02), look(throw, Enum.Material.Fabric), soft)
		-- Pillows: two big against the headboard, two in front, a bolster.
		for _, sx in { -1, 1 } do
			box(b, "Pillow", Vector3.new(w / 2 - 0.3, 1.5, 0.45), CFrame.new(sx * (w / 4), 2.65, len / 2 - 0.55) * CFrame.Angles(rad(14), 0, 0), L.cream, soft)
			box(b, "Pillow", Vector3.new(w / 2 - 0.7, 1.1, 0.4), CFrame.new(sx * (w / 4), 2.45, len / 2 - 1.05) * CFrame.Angles(rad(18), 0, 0), look(duvet:Lerp(rgb(255, 255, 255), 0.4), Enum.Material.Fabric), soft)
		end
		cyl(b, "Bolster", w * 0.6, 0.55, CFrame.new(0, 2.3, len / 2 - 1.55), look(throw, Enum.Material.Fabric), soft)
		return 2.33
	end

	F.define("bed", "The bed", function(b: any, st: any)
		local model = st.model or "classic"
		local duvet = F.colour(st, "colour", rgb(232, 226, 214))
		local accent = F.colour(st, "accent", rgb(190, 150, 74))
		local metal = look(accent, Enum.Material.Metal, 0.25)
		local head = F.tint(F.colour(st, "headboard", rgb(70, 30, 34)), st.material, Enum.Material.Fabric)
		local w, len = 7, 8.6
		if model == "round" then
			disc(b, "Plinth", 9.2, 0.8, Vector3.new(0, 0.4, 0), look(darker(head.color, 0.2), head.material))
			disc(b, "Mattress", 8.6, 0.9, Vector3.new(0, 1.25, 0), L.cream)
			disc(b, "Cover", 8.7, 0.3, Vector3.new(0, 1.8, -0.2), look(duvet, Enum.Material.Fabric))
			for i = 0, 6 do
				local a = rad(-60 + i * 20)
				local p = Vector3.new(math.sin(a) * 4.5, 0, math.cos(a) * 4.5)
				box(b, "Head", Vector3.new(1.45, 4.2, 0.6), CFrame.lookAt(p, Vector3.zero) * CFrame.new(0, 2.1, 0), head)
			end
			for i = -1, 1 do
				box(b, "Pillow", Vector3.new(1.8, 1.2, 0.45), CFrame.new(i * 1.9, 2.4, 3.2 - math.abs(i) * 0.5) * CFrame.Angles(rad(15), rad(-i * 18), 0), L.cream, soft)
			end
			disc(b, "Glow", 9.3, 0.06, Vector3.new(0, 0.05, 0), look(accent, Enum.Material.Neon, nil, 0.4), trim)
			F.sit(b, CFrame.new(-1.6, 2.0, -3.6))
			F.sit(b, CFrame.new(1.6, 2.0, -3.6))
			return
		end
		local baseLook = look(darker(head.color, 0.2), head.material)
		if model == "floating" then
			baseLook = L.blackLacquer
		end
		local top = bedding(b, w, len, baseLook, duvet, F.colour(st, "throw", accent))
		if model == "canopy" then
			local wood = F.tint(F.colour(st, "wood", rgb(40, 24, 16)), "Wood", Enum.Material.Wood)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local p = Vector3.new(sx * (w / 2 + 0.1), 0, sz * (len / 2 + 0.1))
					post(b, "Post", 9.2, 0.4, p, wood)
					ball(b, "Finial", 0.5, p + Vector3.new(0, 9.4, 0), metal, trim)
					-- Drapes gathered at each post.
					box(b, "Drape", Vector3.new(0.9, 8.2, 0.35), CFrame.new(p + Vector3.new(-sx * 0.35, 4.9, -sz * 0.35)) * CFrame.Angles(0, rad(45 * sx * sz), 0), look(F.colour(st, "drape", rgb(236, 228, 210)), Enum.Material.Fabric, nil, 0.15), soft)
				end
				box(b, "Rail", Vector3.new(0.25, 0.3, len + 0.6), CFrame.new(sx * (w / 2 + 0.1), 9.15, 0), wood, soft)
			end
			for _, sz in { -1, 1 } do
				box(b, "Rail", Vector3.new(w + 0.6, 0.3, 0.25), CFrame.new(0, 9.15, sz * (len / 2 + 0.1)), wood, soft)
			end
			box(b, "Headboard", Vector3.new(w, 3.6, 0.4), CFrame.new(0, 3.5, len / 2 - 0.1), wood)
			box(b, "HeadPanel", Vector3.new(w - 1, 2.6, 0.1), CFrame.new(0, 3.6, len / 2 - 0.33), head, trim)
		elseif model == "floating" then
			-- A low platform lit from beneath, the headboard running wide with shelves for nightstands.
			box(b, "Platform", Vector3.new(w + 1.2, 0.4, len + 1.2), CFrame.new(0, 0.55, 0), L.blackLacquer)
			box(b, "Glow", Vector3.new(w + 0.8, 0.08, len + 0.8), CFrame.new(0, 0.3, 0), look(accent, Enum.Material.Neon, nil, 0.25), trim)
			box(b, "Headboard", Vector3.new(w + 6, 3.4, 0.5), CFrame.new(0, 2.5, len / 2 + 0.25), head)
			for _, sx in { -1, 1 } do
				box(b, "Ledge", Vector3.new(2.4, 0.25, 1.4), CFrame.new(sx * (w / 2 + 1.6), 2.0, len / 2 - 0.5), L.blackLacquer)
				local lamp = box(b, "Strip", Vector3.new(2.2, 0.05, 0.1), CFrame.new(sx * (w / 2 + 1.6), 4.1, len / 2 - 0.05), L.warmGlow, trim)
				if sx == 1 then
					F.spotLight(b, lamp, Enum.NormalId.Front, 0.8, 8, 90)
				end
			end
		elseif model == "royal" then
			-- A gilded headboard under a crowned canopy, velvet falling either side.
			local velvet = look(F.colour(st, "drape", rgb(90, 14, 30)), Enum.Material.Fabric)
			box(b, "Headboard", Vector3.new(w + 1, 5.6, 0.5), CFrame.new(0, 3.6, len / 2 + 0.1), metal)
			box(b, "HeadPanel", Vector3.new(w - 0.2, 4.4, 0.2), CFrame.new(0, 3.7, len / 2 - 0.2), head)
			for row = 0, 2 do
				for col = 0, 4 do
					ball(b, "Button", 0.14, Vector3.new(-2.4 + col * 1.2, 2.6 + row * 1.0, len / 2 - 0.32), metal, trim)
				end
			end
			cyl(b, "Crest", 0.5, 3.0, CFrame.new(0, 6.6, len / 2 + 0.1) * CFrame.Angles(0, rad(90), 0), metal)
			-- The crown above.
			disc(b, "Crown", 3.4, 0.5, Vector3.new(0, 10.4, len / 2 - 0.6), metal)
			for i = 0, 7 do
				local a = rad(i * 45)
				ball(b, "CrownPoint", 0.35, Vector3.new(math.cos(a) * 1.6, 10.9, len / 2 - 0.6 + math.sin(a) * 1.6), metal, trim)
			end
			for _, sx in { -1, 1 } do
				box(b, "Drape", Vector3.new(1.6, 9.6, 0.3), CFrame.new(sx * (w / 2 + 0.6), 5.4, len / 2 - 0.9) * CFrame.Angles(0, rad(sx * 25), rad(sx * -4)), velvet, soft)
				box(b, "Tieback", Vector3.new(1.0, 0.2, 0.4), CFrame.new(sx * (w / 2 + 0.6), 4.0, len / 2 - 0.9), metal, trim)
			end
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					ball(b, "Foot", 0.5, Vector3.new(sx * (w / 2 - 0.3), 0.25, sz * (len / 2 - 0.3)), metal, soft)
				end
			end
		else -- classic: a tall upholstered headboard, channel-tufted
			box(b, "Headboard", Vector3.new(w + 0.6, 4.6, 0.5), CFrame.new(0, 3.1, len / 2 + 0.1), head)
			for i = 0, 6 do
				box(b, "Channel", Vector3.new(0.06, 3.8, 0.06), CFrame.new(-3 + i * 1.0, 3.3, len / 2 - 0.17), look(darker(head.color, 0.3), head.material), trim)
			end
			box(b, "Cap", Vector3.new(w + 0.7, 0.18, 0.55), CFrame.new(0, 5.45, len / 2 + 0.1), metal, trim)
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					post(b, "Leg", 0.3, 0.3, Vector3.new(sx * (w / 2 - 0.3), 0, sz * (len / 2 - 0.3)), metal, soft)
				end
			end
		end
		F.sit(b, CFrame.new(-1.6, top - 0.2, -len / 2 + 0.9))
		F.sit(b, CFrame.new(1.6, top - 0.2, -len / 2 + 0.9))
	end, "The bed")

	F.define("nightstands", "The nightstands", function(b: any, st: any)
		local wood = F.tint(F.colour(st, "colour", rgb(40, 24, 16)), st.material or "Wood", Enum.Material.Wood)
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		local gap = st.gap or 9.6 -- between the two (the bed stands between)
		for i, sx in { -1, 1 } do
			local x = sx * gap / 2
			box(b, "Stand", Vector3.new(2.2, 2.2, 1.8), CFrame.new(x, 1.2, 0), wood)
			box(b, "Top", Vector3.new(2.3, 0.12, 1.9), CFrame.new(x, 2.36, 0), if st.model == "marble" then L.whiteMarble else wood)
			box(b, "Drawer", Vector3.new(1.9, 0.7, 0.05), CFrame.new(x, 1.7, -0.92), look(darker(wood.color, 0.12), wood.material), trim)
			box(b, "Pull", Vector3.new(0.5, 0.06, 0.06), CFrame.new(x, 1.7, -0.97), accent, trim)
			for _, lx in { -0.9, 0.9 } do
				box(b, "Leg", Vector3.new(0.14, 0.2, 0.14), CFrame.new(x + lx, 0.1, 0), accent, soft)
			end
			-- A lamp on each.
			disc(b, "LampBase", 0.6, 0.15, Vector3.new(x, 2.5, 0.2), accent, trim)
			post(b, "LampStem", 1.1, 0.08, Vector3.new(x, 2.55, 0.2), accent, trim)
			local shade = cyl(b, "LampShade", 0.75, 1.0, CFrame.new(x, 3.95, 0.2) * CFrame.Angles(0, 0, rad(90)), look(F.colour(st, "shade", rgb(236, 220, 190)), Enum.Material.Fabric, nil, 0.08), trim)
			if i == 1 then
				F.light(b, shade, 0.8, 10)
			end
			box(b, "Book", Vector3.new(0.7, 0.12, 0.5), CFrame.new(x - 0.5, 2.48, -0.4) * CFrame.Angles(0, rad(10), 0), look(rgb(110, 30, 26), Enum.Material.Fabric), trim)
		end
	end)

	F.define("dresser", "The dresser", function(b: any, st: any)
		local wood = F.tint(F.colour(st, "colour", rgb(232, 224, 208)), st.material or "SmoothPlastic", Enum.Material.SmoothPlastic)
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		box(b, "Body", Vector3.new(6, 2.9, 1.8), CFrame.new(0, 1.75, 0), wood)
		box(b, "Top", Vector3.new(6.1, 0.12, 1.9), CFrame.new(0, 3.26, 0), L.whiteMarble)
		for row = 0, 2 do
			for col = -1, 1 do
				box(b, "Drawer", Vector3.new(1.85, 0.8, 0.05), CFrame.new(col * 1.95, 0.75 + row * 0.92, -0.92), look(darker(wood.color, 0.06), wood.material), trim)
				ball(b, "Knob", 0.14, Vector3.new(col * 1.95, 0.75 + row * 0.92, -1.0), accent, trim)
			end
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(b, "Leg", Vector3.new(0.2, 0.3, 0.2), CFrame.new(sx * 2.8, 0.15, sz * 0.7), accent, soft)
			end
		end
		-- Its glass, and a few things on top.
		box(b, "MirrorFrame", Vector3.new(4.2, 3.4, 0.15), CFrame.new(0, 5.2, 0.7), accent)
		box(b, "Mirror", Vector3.new(3.8, 3.0, 0.05), CFrame.new(0, 5.2, 0.6), L.mirror, trim)
		post(b, "Perfume", 0.4, 0.3, Vector3.new(-2, 3.32, -0.2), look(rgb(240, 200, 210), Enum.Material.Glass, 0.2, 0.2), trim)
		post(b, "Perfume", 0.5, 0.24, Vector3.new(-1.6, 3.32, 0), look(rgb(200, 220, 240), Enum.Material.Glass, 0.2, 0.2), trim)
		disc(b, "Tray", 1.2, 0.06, Vector3.new(1.5, 3.35, -0.1), accent, trim)
		post(b, "Vase", 0.9, 0.4, Vector3.new(2.2, 3.32, 0.2), L.ivoryLacquer, trim)
		for i = 0, 2 do
			ball(b, "Bloom", 0.35, Vector3.new(2.1 + i * 0.12, 4.35 + (i % 2) * 0.15, 0.2), look(rgb(240, 236, 230), Enum.Material.SmoothPlastic), trim)
		end
	end)

	F.define("bench", "The bench", function(b: any, st: any)
		local c = F.tint(F.colour(st, "colour", rgb(196, 170, 120)), st.material, Enum.Material.Fabric)
		local accent = look(F.colour(st, "accent", rgb(190, 150, 74)), Enum.Material.Metal, 0.25)
		box(b, "Seat", Vector3.new(5.4, 0.55, 1.8), CFrame.new(0, 1.6, 0), c)
		for i = 0, 4 do
			ball(b, "Button", 0.1, Vector3.new(-2 + i * 1.0, 1.89, 0), look(c.color:Lerp(Color3.new(0, 0, 0), 0.3), c.material), trim)
		end
		box(b, "Rail", Vector3.new(5.2, 0.15, 1.6), CFrame.new(0, 1.25, 0), accent)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(b, "Leg", Vector3.new(0.16, 1.2, 0.16), CFrame.new(sx * 2.4, 0.6, sz * 0.65) * CFrame.Angles(rad(-sz * 6), 0, rad(sx * 6)), accent, soft)
			end
		end
		F.sit(b, CFrame.new(-1.2, 1.88, 0))
		F.sit(b, CFrame.new(1.2, 1.88, 0))
	end)
end

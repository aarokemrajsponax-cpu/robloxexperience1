--!strict
-- The Suite's two grandest pieces, built at the house's true size once the rooms are grown (World/
-- Build, after the Grand Scale), so every proportion is exactly as drawn here:
--
--   the fireplace   on the drawing room's north wall: a marble chimneypiece with gilded fluted
--                   pilasters, a carved frieze with the house's cartouche and swags of gold, a
--                   black marble mantel dressed with candelabra, a clock and orchids; a splayed
--                   firebrick firebox with brass andirons, a basket of burning logs (flames,
--                   rising sparks, a flickering glow and the crackle of the fire), a brass fender
--                   and fire irons on the hearth; above it all a gilded overmantel for the guest's
--                   painting, and candle sconces either side.
--   the front doors in the Club hall's west wall: tall black lacquer double doors with gilded
--                   panels, medallions and long pulls in a black marble architrave, the Suite's
--                   name in gold in the frieze, a cornice and the house's crest above, a lantern
--                   either side. They swing open as a guest comes near (World/Ambient).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Layout = require(ReplicatedStorage.Shared.Layout) -- the grown house
local Kit = require(script.Parent.Kit)

local SuiteFinish = {}

local rgb = Color3.fromRGB
local function look(c: Color3, m: Enum.Material, refl: number?, transp: number?): Kit.Look
	return { color = c, material = m, reflectance = refl, transparency = transp }
end

local GOLD = look(rgb(201, 160, 78), Enum.Material.Metal, 0.3)
local DEEP_GOLD = look(rgb(150, 112, 48), Enum.Material.Metal, 0.2)
local CALACATTA = look(rgb(238, 233, 224), Enum.Material.Marble, 0.08)
local VEINED = look(rgb(214, 206, 192), Enum.Material.Marble, 0.06)
local NERO = look(rgb(16, 15, 17), Enum.Material.Marble, 0.14)
local FIREBRICK = look(rgb(66, 30, 22), Enum.Material.Brick)
local MORTAR = look(rgb(34, 18, 14), Enum.Material.Concrete)
local SOOT = look(rgb(10, 9, 9), Enum.Material.Slate)
local LOG = look(rgb(58, 38, 26), Enum.Material.Wood)
local CHAR = look(rgb(24, 18, 16), Enum.Material.Slate)
local EMBER = look(rgb(255, 96, 28), Enum.Material.Neon, nil, 0.1)
local COAL = look(rgb(255, 150, 60), Enum.Material.Neon)
local IRON = look(rgb(40, 36, 34), Enum.Material.Metal, 0.1)
local CANDLE = look(rgb(244, 238, 222), Enum.Material.SmoothPlastic)
local FLAME = look(rgb(255, 206, 130), Enum.Material.Neon)
local CRYSTAL = look(rgb(214, 228, 236), Enum.Material.Glass, 0.25, 0.45)
local STEM = look(rgb(70, 110, 60), Enum.Material.SmoothPlastic)
local ORCHID = look(rgb(250, 246, 250), Enum.Material.SmoothPlastic)
local SILK = look(rgb(64, 16, 26), Enum.Material.Fabric)
local LACQUER = look(rgb(12, 11, 13), Enum.Material.SmoothPlastic, 0.22)
local FIELD = look(rgb(22, 20, 24), Enum.Material.SmoothPlastic, 0.12)
local DIAL = look(rgb(246, 240, 226), Enum.Material.SmoothPlastic)
local LANTERN_GLASS = look(rgb(255, 204, 140), Enum.Material.Glass, 0.1, 0.3)
local TRIM = { collide = false, query = false, shadow = false }
local SOFT = { collide = false, query = false }

---------------------------------------------------------------------------------------------------
-- The fireplace
---------------------------------------------------------------------------------------------------

-- An emitter of `props` on `parent`.
local function emitter(parent: Instance, name: string, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	for k, v in props do
		pcall(function()
			(e :: any)[k] = v
		end)
	end
	e.Parent = parent
	return e
end

-- The fire itself: tongues of flame from the logs, sparks rising, the classic fire's flicker,
-- and the glow on the room (it flickers: World/Ambient), with the crackle of it.
local function flames(model: Model, at: CFrame, width: number)
	local core = Kit.part(model, "FireCore", Vector3.new(width, 0.4, 1.2), at, { color = rgb(0, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 1 }, TRIM)
	emitter(core, "Flames", {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Rate = 70,
		Lifetime = NumberRange.new(0.55, 0.95),
		Speed = NumberRange.new(2.5, 4.5),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 3, 0),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-60, 60),
		LightEmission = 0.95,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(0.35, 2.1), NumberSequenceKeypoint.new(1, 0.3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.25, 0.1), NumberSequenceKeypoint.new(0.8, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 236, 170)),
			ColorSequenceKeypoint.new(0.3, rgb(255, 170, 60)),
			ColorSequenceKeypoint.new(0.7, rgb(240, 90, 30)),
			ColorSequenceKeypoint.new(1, rgb(120, 30, 10)),
		}),
		ZOffset = 0.4,
	})
	-- The hot heart of it, low and bright.
	emitter(core, "Heart", {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Rate = 30,
		Lifetime = NumberRange.new(0.3, 0.5),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(20, 20),
		EmissionDirection = Enum.NormalId.Top,
		Rotation = NumberRange.new(0, 360),
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(rgb(255, 214, 120), rgb(255, 120, 40)),
		ZOffset = 0.5,
	})
	emitter(core, "Sparks", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 7,
		Lifetime = NumberRange.new(1.2, 2.4),
		Speed = NumberRange.new(3, 6.5),
		SpreadAngle = Vector2.new(22, 22),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 1.5, 0),
		Drag = 0.6,
		LightEmission = 1,
		LightInfluence = 0,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(rgb(255, 200, 110), rgb(255, 90, 30)),
	})
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 7
	fire.Color = rgb(255, 120, 40)
	fire.SecondaryColor = rgb(255, 214, 110)
	fire.Parent = core
	local glow = Kit.pointLight(core, 2.4, 30, rgb(255, 146, 70))
	CollectionService:AddTag(glow, "Flicker")
	glow:SetAttribute("BaseBrightness", 2.4)
	-- The crackle (a loop on each guest's screen, at their ambience level: World/Ambient).
	CollectionService:AddTag(core, "HearthSound")
end

local function fireplace(parent: Instance)
	local S = Layout.Suite
	local model = Kit.model(parent, "Fireplace")
	local cx = S.spots.painting.Position.X
	local floor = S.floorY
	local wall = S.main.maxZ -- the north wall's face; the room is toward -Z
	-- A point `x` along the wall from the middle, `y` up from the floor, `out` from the wall.
	local function P(x: number, y: number, out: number): Vector3
		return Vector3.new(cx + x, floor + y, wall - out)
	end
	local function box(name: string, a: Vector3, b: Vector3, lk: Kit.Look, opts: { [string]: any }?): Part
		return Kit.span(model, name, a, b, lk, opts)
	end
	-- Along the wall (X), standing up from it (its round faces to the room).
	local function disc(name: string, d: number, thick: number, at: Vector3, lk: Kit.Look, opts: { [string]: any }?): Part
		return Kit.cylinder(model, name, thick, d, CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0), lk, opts or TRIM)
	end
	local function rod(name: string, length: number, d: number, at: Vector3, lk: Kit.Look, opts: { [string]: any }?): Part
		return Kit.cylinder(model, name, length, d, CFrame.new(at), lk, opts or TRIM)
	end
	local function upright(name: string, height: number, d: number, foot: Vector3, lk: Kit.Look, opts: { [string]: any }?): Part
		return Kit.post(model, name, height, d, foot, lk, opts or TRIM)
	end

	-- The hearth: a black marble slab with a rounded edge and a brass inlay.
	box("Hearth", P(-7.4, 0, 0), P(7.4, 0.45, 4.0), NERO)
	rod("HearthNose", 14.8, 0.45, P(0, 0.225, 4.0), NERO, SOFT)
	box("HearthInlay", P(-7.1, 0.45, 3.45), P(7.1, 0.47, 3.6), GOLD, TRIM)

	-- The firebox: a back of firebrick laid in courses, splayed cheeks, a sooty soffit.
	box("FireBack", P(-3.4, 0.45, 0), P(3.4, 6.9, 0.15), FIREBRICK)
	for y = 1.05, 6.6, 0.6 do
		box("Course", P(-3.35, y, 0.15), P(3.35, y + 0.06, 0.18), MORTAR, TRIM)
	end
	for _, side in { -1, 1 } do
		local back = P(side * 3.4, 3.675, 0.15)
		local front = P(side * 4.7, 3.675, 2.3)
		local length = (front - back).Magnitude
		Kit.part(model, "Cheek", Vector3.new(0.2, 6.45, length), CFrame.lookAt((back + front) / 2, front), FIREBRICK)
	end
	box("Soffit", P(-4.7, 6.85, 0), P(4.7, 7.0, 2.3), SOOT)

	-- The chimneypiece: fluted pilasters on black plinths, gilded capitals.
	for _, side in { -1, 1 } do
		local x0, x1 = if side < 0 then -6.6 else 4.7, if side < 0 then -4.7 else 6.6
		box("Plinth", P(x0 - 0.12, 0.45, 0), P(x1 + 0.12, 1.05, 2.7), NERO)
		box("Pilaster", P(x0, 1.05, 0), P(x1, 7.6, 2.5), CALACATTA)
		for _, f in { 0.45, 0.95, 1.45 } do
			local x = x0 + f
			box("Flute", P(x - 0.06, 1.5, 2.5), P(x + 0.06, 7.15, 2.56), GOLD, TRIM)
		end
		box("Capital", P(x0 - 0.15, 7.6, 0), P(x1 + 0.15, 8.25, 2.75), GOLD)
		-- A gilded rosette on each capital, and a scroll either side of it.
		Kit.ball(model, "Rosette", 0.5, P(side * 5.65, 7.93, 2.8), GOLD, TRIM)
		for _, d in { -0.62, 0.62 } do
			disc("Volute", 0.42, 0.18, P(side * 5.65 + d, 7.93, 2.78), DEEP_GOLD)
		end
		-- A gilded bead up the opening's edge.
		local bx = side * 4.7
		box("Bead", P(bx - 0.08, 0.45, 2.3), P(bx + 0.08, 7.0, 2.55), GOLD, TRIM)
	end
	box("BeadTop", P(-4.78, 6.92, 2.3), P(4.78, 7.06, 2.55), GOLD, TRIM)
	-- The frieze across it: white marble with the house's cartouche and gold swags.
	box("Frieze", P(-6.75, 7.0, 0), P(6.75, 8.6, 2.4), VEINED)
	disc("Cartouche", 1.7, 0.12, P(0, 7.8, 2.46), GOLD)
	disc("CartoucheField", 1.25, 0.06, P(0, 7.8, 2.55), NERO)
	local crest = Kit.part(model, "Crest", Vector3.new(1.0, 0.7, 0.04), CFrame.new(P(0, 7.8, 2.6)), { color = rgb(0, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 1 }, TRIM)
	Kit.engrave(crest, Enum.NormalId.Front, { { text = "MN", size = 0.8, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 120, lit = false })
	for _, side in { -1, 1 } do
		for i = 0, 8 do
			local t = i / 8
			local x = side * (1.25 + t * 3.1)
			local y = 8.25 - math.sin(t * math.pi) * 0.7
			Kit.ball(model, "Swag", if i % 2 == 0 then 0.26 else 0.2, P(x, y, 2.45), GOLD, TRIM)
		end
		Kit.ball(model, "SwagTie", 0.34, P(side * 4.45, 8.3, 2.48), GOLD, TRIM)
	end
	-- The mantel: black marble with a gilded edge and a bead under it.
	box("MantelBed", P(-6.95, 8.5, 2.4), P(6.95, 8.6, 2.62), GOLD, TRIM)
	box("Mantel", P(-7.3, 8.6, 0), P(7.3, 9.1, 3.0), NERO)
	box("MantelEdge", P(-7.3, 8.7, 3.0), P(7.3, 9.0, 3.06), GOLD, TRIM)

	-- The fire: brass andirons, an iron grate, a bed of embers and four burning logs.
	for _, side in { -1, 1 } do
		local x = side * 2.9
		upright("Andiron", 1.5, 0.26, P(x, 0.45, 2.05), GOLD)
		Kit.ball(model, "Finial", 0.48, P(x, 2.1, 2.05), GOLD, TRIM)
		box("FireDog", P(x - 0.1, 0.6, 0.6), P(x + 0.1, 0.78, 2.0), IRON, TRIM)
	end
	for _, out in { 0.75, 1.25, 1.75 } do
		rod("Grate", 5.2, 0.12, P(0, 0.8, out), IRON)
	end
	box("Embers", P(-2.5, 0.45, 0.55), P(2.5, 0.62, 1.95), EMBER, TRIM)
	for i = 0, 9 do
		local x = -2.1 + (i * 37 % 42) / 10
		local out = 0.75 + (i * 23 % 11) / 10
		Kit.ball(model, "Coal", 0.26 + (i % 3) * 0.06, P(x, 0.66, out), COAL, TRIM)
	end
	local logs: { { length: number, d: number, at: Vector3, turn: number, tilt: number } } = {
		{ length = 4.6, d = 0.72, at = P(0, 1.15, 1.55), turn = 0, tilt = 0 },
		{ length = 4.2, d = 0.66, at = P(0.25, 1.1, 0.85), turn = 4, tilt = 0 },
		{ length = 3.8, d = 0.56, at = P(-0.3, 1.72, 1.2), turn = 18, tilt = 6 },
		{ length = 3.0, d = 0.46, at = P(0.7, 2.1, 1.05), turn = -26, tilt = -8 },
	}
	for i, lg in logs do
		local cf = CFrame.new(lg.at) * CFrame.Angles(0, math.rad(lg.turn), math.rad(lg.tilt))
		Kit.cylinder(model, "Log", lg.length, lg.d, cf, LOG, TRIM)
		-- Charred ends, and a seam of fire along the top where it's burning through.
		for _, e in { -1, 1 } do
			Kit.cylinder(model, "LogEnd", 0.06, lg.d * 0.92, cf * CFrame.new(e * lg.length / 2, 0, 0), CHAR, TRIM)
		end
		Kit.part(model, "Burn", Vector3.new(lg.length * 0.7, 0.06, 0.14), cf * CFrame.new(0, lg.d / 2 - 0.01, if i % 2 == 0 then 0.1 else -0.1), EMBER, TRIM)
	end
	flames(model, CFrame.new(P(0, 1.9, 1.25)), 4)
	-- A brass fender along the hearth, and the fire irons and a log basket at either end.
	for _, side in { -1, 1 } do
		upright("FenderPost", 0.8, 0.22, P(side * 5.9, 0.45, 3.55), GOLD)
		Kit.ball(model, "FenderKnob", 0.32, P(side * 5.9, 1.3, 3.55), GOLD, TRIM)
	end
	rod("FenderRail", 11.8, 0.14, P(0, 1.18, 3.55), GOLD)
	rod("FenderFoot", 11.8, 0.1, P(0, 0.52, 3.55), GOLD)
	-- Fire irons on their stand (left).
	Kit.cylinder(model, "IronsBase", 0.12, 0.9, CFrame.new(P(-6.95, 0.51, 3.35)) * CFrame.Angles(0, 0, math.rad(90)), GOLD, TRIM)
	upright("IronsStand", 3.0, 0.14, P(-6.95, 0.45, 3.35), GOLD)
	Kit.ball(model, "IronsTop", 0.32, P(-6.95, 3.5, 3.35), GOLD, TRIM)
	rod("IronsBar", 0.9, 0.1, P(-6.95, 3.2, 3.35), GOLD)
	for i, x in { -7.3, -6.95, -6.6 } do
		upright("Iron", 2.2, 0.08, P(x, 0.9, 3.35 + (i - 2) * 0.12), IRON)
		Kit.ball(model, "IronHandle", 0.18, P(x, 3.15, 3.35 + (i - 2) * 0.12), GOLD, TRIM)
	end
	-- A basket of logs (right).
	box("BasketBase", P(6.35, 0.45, 2.95), P(7.35, 0.55, 3.85), GOLD, TRIM)
	for _, out in { 2.95, 3.85 } do
		box("BasketSide", P(6.35, 0.55, out - 0.04), P(7.35, 1.35, out + 0.04), GOLD, TRIM)
	end
	for i = 0, 2 do
		rod("BasketLog", 0.95, 0.34, P(6.85, 0.8 + (i // 2) * 0.32, 3.2 + (i % 2) * 0.42), LOG)
	end

	-- On the mantel: a gilded clock in the middle, crystal vases of orchids, candelabra at the ends.
	local top = 9.1
	box("ClockCase", P(-0.55, top, 1.2), P(0.55, top + 1.35, 1.85), GOLD)
	Kit.ball(model, "ClockFinial", 0.3, P(0, top + 1.5, 1.52), GOLD, TRIM)
	disc("ClockDial", 0.78, 0.04, P(0, top + 0.78, 1.87), DIAL)
	Kit.part(model, "HourHand", Vector3.new(0.05, 0.22, 0.02), CFrame.new(P(0.04, top + 0.86, 1.9)) * CFrame.Angles(0, 0, math.rad(-35)), IRON, TRIM)
	Kit.part(model, "MinuteHand", Vector3.new(0.04, 0.32, 0.02), CFrame.new(P(-0.07, top + 0.9, 1.9)) * CFrame.Angles(0, 0, math.rad(25)), IRON, TRIM)
	for _, side in { -1, 1 } do
		-- A crystal vase of white orchids.
		local vx = side * 2.9
		upright("Vase", 1.0, 0.5, P(vx, top, 1.5), CRYSTAL, SOFT)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			local sx, so = math.cos(a) * 0.25, math.sin(a) * 0.18
			upright("Stem", 1.1, 0.05, P(vx + sx * 0.3, top + 0.9, 1.5 + so * 0.3), STEM)
			Kit.ball(model, "Orchid", 0.26, P(vx + sx * 1.4, top + 1.95 + (k % 2) * 0.22, 1.5 + so * 1.4), ORCHID, TRIM)
		end
		-- A candelabrum: three candles on gilded arms.
		local kx = side * 5.7
		Kit.cylinder(model, "CandelabrumBase", 0.12, 0.75, CFrame.new(P(kx, top + 0.06, 1.5)) * CFrame.Angles(0, 0, math.rad(90)), GOLD, TRIM)
		upright("CandelabrumStem", 1.5, 0.16, P(kx, top, 1.5), GOLD)
		rod("CandelabrumArm", 1.5, 0.1, P(kx, top + 1.5, 1.5), GOLD)
		for _, dx in { -0.7, 0, 0.7 } do
			local y = top + 1.55 + (if dx == 0 then 0.25 else 0)
			upright("CandleCup", 0.12, 0.26, P(kx + dx, y - 0.05, 1.5), GOLD)
			upright("Candle", 0.75, 0.16, P(kx + dx, y + 0.05, 1.5), CANDLE)
			Kit.ball(model, "CandleFlame", 0.16, P(kx + dx, y + 0.9, 1.5), FLAME, TRIM)
		end
	end

	-- The overmantel: a gilded frame round a field of silk, where the guest's painting hangs; the
	-- house's crest in the middle when it hangs bare.
	local py = S.spots.painting.Position.Y - floor
	local hw, hh = 5.5, 4.4
	box("Overmantel", P(-hw, py - hh, 0), P(hw, py + hh, 0.1), SILK)
	box("OvermantelFrameT", P(-hw - 0.45, py + hh, 0), P(hw + 0.45, py + hh + 0.45, 0.3), GOLD)
	box("OvermantelFrameB", P(-hw - 0.45, py - hh - 0.45, 0), P(hw + 0.45, py - hh, 0.3), GOLD)
	box("OvermantelFrameL", P(-hw - 0.45, py - hh, 0), P(-hw, py + hh, 0.3), GOLD)
	box("OvermantelFrameR", P(hw, py - hh, 0), P(hw + 0.45, py + hh, 0.3), GOLD)
	box("OvermantelLip", P(-hw, py + hh - 0.1, 0.1), P(hw, py + hh, 0.18), DEEP_GOLD, TRIM)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			Kit.ball(model, "Corner", 0.62, P(sx * (hw + 0.22), py + sy * (hh + 0.22), 0.34), GOLD, TRIM)
		end
	end
	-- A crown of gold on the frame's top.
	Kit.ball(model, "Crown", 0.7, P(0, py + hh + 0.75, 0.25), GOLD, TRIM)
	for _, d in { -0.75, 0.75 } do
		Kit.ball(model, "CrownLeaf", 0.42, P(d, py + hh + 0.6, 0.25), GOLD, TRIM)
	end
	disc("OvermantelCrest", 2.2, 0.06, P(0, py, 0.13), GOLD)
	local plaque = Kit.part(model, "OvermantelMonogram", Vector3.new(1.6, 1.1, 0.04), CFrame.new(P(0, py, 0.2)), { color = rgb(0, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 1 }, TRIM)
	Kit.engrave(plaque, Enum.NormalId.Front, { { text = "MN", size = 0.8, font = Brand.Fonts.display, color = rgb(40, 28, 10) } }, { ppu = 100, lit = true })
	-- Candle sconces either side of it, lit.
	for _, side in { -1, 1 } do
		local sx = side * (hw + 1.35)
		local sy = py - 0.4
		box("SconcePlate", P(sx - 0.3, sy - 0.8, 0), P(sx + 0.3, sy + 0.8, 0.14), GOLD)
		rod("SconceArm", 1.5, 0.1, P(sx, sy - 0.2, 0.75), GOLD)
		upright("SconceStem", 0.75, 0.12, P(sx, sy - 0.2, 0.14), GOLD)
		Kit.part(model, "SconceBracket", Vector3.new(0.12, 0.12, 0.7), CFrame.new(P(sx, sy - 0.2, 0.45)), GOLD, TRIM)
		local lit: Part? = nil
		for _, dx in { -0.6, 0.6 } do
			upright("SconceCup", 0.12, 0.28, P(sx + dx, sy - 0.15, 0.75), GOLD)
			upright("SconceCandle", 0.7, 0.16, P(sx + dx, sy - 0.05, 0.75), CANDLE)
			lit = Kit.ball(model, "SconceFlame", 0.18, P(sx + dx, sy + 0.78, 0.75), FLAME, TRIM)
		end
		if lit then
			local l = Kit.pointLight(lit, 0.9, 18, rgb(255, 196, 130))
			CollectionService:AddTag(l, "Flicker")
			l:SetAttribute("BaseBrightness", 0.9)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The front doors
---------------------------------------------------------------------------------------------------

local function doors(parent: Instance)
	local S = Layout.Suite
	local C = Layout.Club
	local model = Kit.model(parent, "SuiteDoors")
	Kit.persist(model)
	CollectionService:AddTag(model, "HouseDoor")
	local w, h = S.doorWidth, S.doorHeight
	local floor = S.door.Y
	local cz = S.door.Z
	local face = C.minX -- the wall's face on the hall side; the hall is toward +X
	local mid = (face + (C.minX - 2 * Layout.SCALE)) / 2 -- the middle of the wall's thickness
	local z0, z1 = cz - w / 2, cz + w / 2
	-- The leaves hang in the middle of the wall and swing out into the hall (World/Ambient).
	local base = CFrame.lookAt(Vector3.new(mid, floor, cz), Vector3.new(mid - 1, floor, cz))
	for side = -1, 1, 2 do
		local hinge = base * CFrame.new(side * w / 2, 0, 0)
		local leaf = Kit.part(model, if side < 0 then "LeafL" else "LeafR", Vector3.new(w / 2 - 0.06, h - 0.1, 0.45), hinge * CFrame.new(-side * (w / 4), h / 2, 0), LACQUER, { collide = false, query = false })
		leaf:SetAttribute("Side", side)
		leaf:SetAttribute("Hinge", hinge)
		local lw = w / 2 - 0.06
		-- On both faces: three panels framed in gold, a medallion on the middle one, a kick plate
		-- and a long pull at the meeting edge.
		for _, f in { -1, 1 } do
			local z = f * 0.225
			local panels = { { y0 = 0.12, y1 = 0.44 }, { y0 = -0.09, y1 = 0.07 }, { y0 = -0.44, y1 = -0.15 } }
			for _, pn in panels do
				local y0, y1 = pn.y0 * h, pn.y1 * h
				local pw = lw - 1.1
				local cf = leaf.CFrame * CFrame.new(0, (y0 + y1) / 2, z + f * 0.03)
				Kit.part(model, "Inset", Vector3.new(pw, y1 - y0, 0.06), cf, FIELD, TRIM)
				local fz = z + f * 0.07
				Kit.part(model, "Inset", Vector3.new(pw + 0.24, 0.12, 0.05), leaf.CFrame * CFrame.new(0, y1 + 0.06, fz), GOLD, TRIM)
				Kit.part(model, "Inset", Vector3.new(pw + 0.24, 0.12, 0.05), leaf.CFrame * CFrame.new(0, y0 - 0.06, fz), GOLD, TRIM)
				Kit.part(model, "Inset", Vector3.new(0.12, y1 - y0, 0.05), leaf.CFrame * CFrame.new(-(pw / 2 + 0.06), (y0 + y1) / 2, fz), GOLD, TRIM)
				Kit.part(model, "Inset", Vector3.new(0.12, y1 - y0, 0.05), leaf.CFrame * CFrame.new(pw / 2 + 0.06, (y0 + y1) / 2, fz), GOLD, TRIM)
			end
			Kit.cylinder(model, "Inset", 0.06, 1.15, leaf.CFrame * CFrame.new(0, -0.01 * h, z + f * 0.08) * CFrame.Angles(0, math.rad(90), 0), GOLD, TRIM)
			Kit.cylinder(model, "Inset", 0.04, 0.7, leaf.CFrame * CFrame.new(0, -0.01 * h, z + f * 0.12) * CFrame.Angles(0, math.rad(90), 0), DEEP_GOLD, TRIM)
			Kit.part(model, "Inset", Vector3.new(lw - 0.3, 0.7, 0.04), leaf.CFrame * CFrame.new(0, -h / 2 + 0.5, z + f * 0.03), GOLD, TRIM)
			local ex = -side * (lw / 2 - 0.45)
			Kit.part(model, "Knob", Vector3.new(0.16, 3.4, 0.16), leaf.CFrame * CFrame.new(ex, 0.02 * h, z + f * 0.32), GOLD, TRIM)
			for _, dy in { -1.4, 1.4 } do
				Kit.part(model, "Knob", Vector3.new(0.1, 0.1, 0.3), leaf.CFrame * CFrame.new(ex, 0.02 * h + dy, z + f * 0.16), GOLD, TRIM)
			end
		end
	end
	-- The architrave on the hall side: black marble jambs and head with a gilded bead.
	local out = face + 0.6
	Kit.span(model, "JambL", Vector3.new(face, floor, z0 - 1.1), Vector3.new(out, floor + h + 1.2, z0), NERO)
	Kit.span(model, "JambR", Vector3.new(face, floor, z1), Vector3.new(out, floor + h + 1.2, z1 + 1.1), NERO)
	Kit.span(model, "Head", Vector3.new(face, floor + h, z0), Vector3.new(out, floor + h + 1.2, z1), NERO)
	Kit.span(model, "ArchitraveBead", Vector3.new(out, floor, z0 - 0.18), Vector3.new(out + 0.08, floor + h + 0.18, z0), GOLD, TRIM)
	Kit.span(model, "ArchitraveBead", Vector3.new(out, floor, z1), Vector3.new(out + 0.08, floor + h + 0.18, z1 + 0.18), GOLD, TRIM)
	Kit.span(model, "ArchitraveBead", Vector3.new(out, floor + h, z0 - 0.18), Vector3.new(out + 0.08, floor + h + 0.18, z1 + 0.18), GOLD, TRIM)
	for _, z in { z0 - 0.55, z1 + 0.55 } do
		Kit.span(model, "JambPlinth", Vector3.new(face, floor, z - 0.65), Vector3.new(out + 0.12, floor + 1.4, z + 0.65), GOLD)
	end
	-- The frieze with the Suite's name, a gilded cornice, and the crest.
	local frieze = Kit.span(model, "Frieze", Vector3.new(face, floor + h + 1.2, z0 - 1.1), Vector3.new(out - 0.1, floor + h + 2.8, z1 + 1.1), NERO)
	Kit.engrave(frieze, Enum.NormalId.Right, { { text = "Y O U R   S U I T E", size = 0.62, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 60, lit = false })
	Kit.span(model, "Cornice", Vector3.new(face, floor + h + 2.8, z0 - 1.5), Vector3.new(out + 0.4, floor + h + 3.3, z1 + 1.5), GOLD)
	Kit.span(model, "CorniceDentil", Vector3.new(face, floor + h + 2.62, z0 - 1.3), Vector3.new(out + 0.15, floor + h + 2.8, z1 + 1.3), DEEP_GOLD, TRIM)
	local crestAt = Vector3.new(face + 0.25, floor + h + 4.5, cz)
	Kit.cylinder(model, "Crest", 0.14, 2.1, CFrame.new(crestAt), GOLD, TRIM)
	Kit.cylinder(model, "CrestField", 0.06, 1.55, CFrame.new(crestAt + Vector3.new(0.08, 0, 0)), NERO, TRIM)
	local mono = Kit.part(model, "CrestMonogram", Vector3.new(0.04, 1.0, 1.4), CFrame.new(crestAt + Vector3.new(0.14, 0, 0)), { color = rgb(0, 0, 0), material = Enum.Material.SmoothPlastic, transparency = 1 }, TRIM)
	Kit.engrave(mono, Enum.NormalId.Right, { { text = "MN", size = 0.8, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 100, lit = false })
	for _, d in { -1.35, 1.35 } do
		Kit.ball(model, "CrestLaurel", 0.5, crestAt + Vector3.new(0.05, -0.35, d), GOLD, TRIM)
	end
	-- A lantern either side, on a bracket from the wall.
	for _, z in { z0 - 2.9, z1 + 2.9 } do
		local y = floor + h * 0.62
		Kit.span(model, "LanternPlate", Vector3.new(face, y - 0.6, z - 0.35), Vector3.new(face + 0.12, y + 0.6, z + 0.35), GOLD)
		Kit.span(model, "LanternBracket", Vector3.new(face + 0.12, y + 0.35, z - 0.07), Vector3.new(face + 1.0, y + 0.49, z + 0.07), GOLD, TRIM)
		local lx = face + 1.15
		Kit.part(model, "LanternCap", Vector3.new(1.0, 0.25, 1.0), CFrame.new(lx, y + 0.55, z), GOLD, TRIM)
		Kit.part(model, "LanternFoot", Vector3.new(0.8, 0.2, 0.8), CFrame.new(lx, y - 1.05, z), GOLD, TRIM)
		local glass = Kit.part(model, "LanternGlass", Vector3.new(0.75, 1.4, 0.75), CFrame.new(lx, y - 0.25, z), LANTERN_GLASS, TRIM)
		for _, c in { Vector3.new(-0.4, 0, -0.4), Vector3.new(0.4, 0, -0.4), Vector3.new(-0.4, 0, 0.4), Vector3.new(0.4, 0, 0.4) } do
			Kit.part(model, "LanternRib", Vector3.new(0.08, 1.45, 0.08), CFrame.new(Vector3.new(lx, y - 0.25, z) + c), GOLD, TRIM)
		end
		Kit.ball(model, "LanternFlame", 0.3, Vector3.new(lx, y - 0.25, z), FLAME, TRIM)
		Kit.ball(model, "LanternFinial", 0.3, Vector3.new(lx, y + 0.8, z), GOLD, TRIM)
		Kit.pointLight(glass, 1.1, 18, rgb(255, 196, 130))
	end
end

-- Builds them into the Suite (`root`: the house, grown).
function SuiteFinish.build(root: Instance)
	local suite = root:FindFirstChild("Suite") or root
	fireplace(suite)
	doors(suite)
end

return SuiteFinish

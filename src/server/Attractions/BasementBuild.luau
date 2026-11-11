--!strict
-- The Maison Basement, built (shared/Basement says where everything is): the entry hall with the
-- arch home, sixteen stages down through the Wine Cellar, the Boiler Room, the Old Vaults and the
-- Treasury Depths, walls and a ceiling over each, a pit under each, the checkpoints (a lift up to
-- the Maison at the end of each part), and the Treasury's chest at the foot.
--
-- What moves (the pistons, the sinking tiles, the steam, the lasers, the valve's bars) is built
-- here where it stands at the start; every screen moves it by the server's clock (World/
-- BasementMotion), each part tagged with its kind and its element's number in the plan.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Plan = require(ReplicatedStorage.Shared.Basement)
local Kit = require(script.Parent.Parent.World.Kit)
local Portal = require(script.Parent.Parent.Holidays.Portal)

local BasementBuild = {}

export type Built = {
	root: Model,
	parts: { [number]: BasePart }, -- by element number
	checkpoints: { [number]: BasePart },
	lifts: { [number]: ProximityPrompt },
	chest: Model?,
	homeArch: BasePart?,
}

local L = Kit.Looks
local rgb = Color3.fromRGB
local GOLD = rgb(232, 182, 72)

local function look(colour: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Kit.Look
	return { color = colour, material = material, reflectance = reflectance, transparency = transparency } :: any
end

local LOOKS: { [string]: Kit.Look } = {
	stone = look(rgb(58, 50, 46), Enum.Material.Slate),
	barrel = look(rgb(96, 60, 34), Enum.Material.WoodPlanks),
	plank = look(rgb(120, 84, 50), Enum.Material.WoodPlanks),
	tile = look(rgb(226, 218, 204), Enum.Material.Marble),
	grate = look(rgb(70, 66, 62), Enum.Material.DiamondPlate),
	pipe = look(rgb(184, 110, 64), Enum.Material.Metal, 0.15),
	piston = look(rgb(150, 150, 156), Enum.Material.DiamondPlate),
	valve = look(rgb(60, 56, 54), Enum.Material.Metal),
	belt = look(rgb(28, 26, 26), Enum.Material.Rubber),
	checkpoint = look(rgb(24, 22, 26), Enum.Material.Marble),
	landing = look(rgb(30, 26, 22), Enum.Material.Marble),
	vault = look(rgb(52, 58, 66), Enum.Material.Concrete),
	safe = look(rgb(80, 86, 96), Enum.Material.Metal, 0.1),
	steel = look(rgb(120, 128, 140), Enum.Material.Metal, 0.1),
	gold = look(GOLD, Enum.Material.Metal, 0.25),
	treasury = look(rgb(40, 30, 16), Enum.Material.Marble),
}

-- What waits below each part's stages (each looks like what it is, never a flat colour): a dark,
-- glossy pool of spilled wine; the furnace's cracked lava; an inky abyss under the vaults; a sea
-- of gold coins.
local PIT: { [number]: Kit.Look } = {
	look(rgb(74, 8, 24), Enum.Material.Glass, 0.35, 0.05), -- spilled wine
	look(rgb(255, 104, 28), Enum.Material.CrackedLava), -- the furnace
	look(rgb(12, 20, 40), Enum.Material.Glass, 0.3, 0.08), -- the vault's depths
	look(rgb(214, 162, 52), Enum.Material.Foil, 0.35), -- a sea of coins
}
-- (The light each gives off.)
local PIT_GLOW: { [number]: Color3 } = { rgb(150, 20, 50), rgb(255, 110, 30), rgb(60, 110, 220), rgb(240, 180, 60) }
local WALL: { [number]: Kit.Look } = {
	look(rgb(48, 30, 26), Enum.Material.Brick),
	look(rgb(60, 44, 34), Enum.Material.CorrodedMetal),
	look(rgb(44, 50, 58), Enum.Material.Concrete),
	look(rgb(40, 32, 20), Enum.Material.Marble),
}

local function tag(part: Instance, name: string, index: number)
	part:SetAttribute("Element", index)
	CollectionService:AddTag(part, name)
end

local function prompt(parent: BasePart, name: string, action: string, object: string, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.Parent = parent
	return p
end

-- A sign over the way: the stage's name and number.
local function sign(parent: Instance, at: Vector3, toward: Vector3, title: string, line: string, colour: Color3)
	local board = Kit.part(parent, "StageSign", Vector3.new(14, 2.6, 0.3), CFrame.lookAt(at, toward), L.blackLacquer, { collide = false })
	Kit.engrave(board, Enum.NormalId.Front, {
		{ text = title, size = 0.5, font = Brand.Fonts.display, color = colour:Lerp(rgb(255, 255, 255), 0.35) },
		{ text = line, size = 0.32, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 50, lit = false, brightness = 1.5, maxDistance = 140 })
end

-- One element of the course.
local function element(parent: Instance, o: Vector3, i: number, e: Plan.El, zone: number): BasePart?
	local cf = CFrame.new(o + e.at)
	local kind = e.kind
	if kind == "pad" or kind == "beam" then
		local lk = LOOKS[e.look or "stone"] or LOOKS.stone
		if e.look == "valve" or e.look == "safe" then
			-- A round floor (its edge is the edge of the sweep).
			local disc = Kit.cylinder(parent, "Floor", e.size.Y, math.min(e.size.X, e.size.Z), cf * CFrame.Angles(0, 0, math.rad(90)), lk)
			return disc
		end
		local p = Kit.part(parent, if kind == "beam" then "Beam" else "Pad", e.size, cf, lk)
		if e.look == "barrel" then
			-- The barrel under its lid.
			Kit.cylinder(parent, "Barrel", 6, e.size.X - 0.4, cf * CFrame.new(0, -3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), LOOKS.barrel, { collide = false })
			for _, dy in { -1.6, -5.2 } do
				Kit.cylinder(parent, "Hoop", 0.3, e.size.X - 0.2, cf * CFrame.new(0, dy, 0) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false, shadow = false })
			end
		elseif e.look == "pipe" then
			Kit.cylinder(parent, "Pipe", e.size.Z, e.size.X + 0.4, cf * CFrame.new(0, -0.3, 0) * CFrame.Angles(0, math.rad(90), 0), LOOKS.pipe, { collide = false })
		end
		return p
	elseif kind == "vanish" then
		local p = Kit.part(parent, "Tile", e.size, cf, LOOKS.tile)
		local edge = Kit.part(parent, "TileGlow", Vector3.new(e.size.X + 0.1, 0.12, e.size.Z + 0.1), cf * CFrame.new(0, -0.45, 0), look(Plan.Zones[zone].colour, Enum.Material.Neon), { collide = false, query = false, shadow = false })
		edge:SetAttribute("Element", i)
		tag(p, "BasementVanish", i)
		CollectionService:AddTag(edge, "BasementVanishGlow")
		return p
	elseif kind == "mover" then
		local p = Kit.part(parent, "Piston", e.size, cf, look(rgb(214, 170, 40), Enum.Material.DiamondPlate, 0.1))
		tag(p, "BasementMover", i)
		return p
	elseif kind == "conveyor" then
		local p = Kit.part(parent, "Belt", e.size, cf, LOOKS.belt)
		local speed = e.speed or 8
		p.AssemblyLinearVelocity = Vector3.new(0, 0, -speed) -- (back toward the start)
		for k = 0, math.floor(e.size.Z / 4) - 1 do
			Kit.part(parent, "Chevron", Vector3.new(e.size.X - 1, 0.06, 0.4), cf * CFrame.new(0, 0.52, -e.size.Z / 2 + 2 + k * 4), look(rgb(240, 190, 40), Enum.Material.Neon, nil, 0.3), { collide = false, query = false, shadow = false })
		end
		return p
	elseif kind == "truss" then
		local t = Instance.new("TrussPart")
		t.Name = "Truss"
		t.Size = Vector3.new(2, math.max(2, math.floor(e.size.Y / 2) * 2), 2)
		t.CFrame = cf
		t.Anchored = true
		t.Material = Enum.Material.Metal
		t.Color = rgb(150, 150, 160)
		t.Parent = parent
		return t
	elseif kind == "steam" then
		local vent = Kit.part(parent, "Vent", Vector3.new(e.size.X, 0.15, e.size.Z), cf * CFrame.new(0, -e.size.Y / 2 + 0.05, 0), look(rgb(30, 28, 26), Enum.Material.DiamondPlate), { collide = false, query = false })
		local column = Kit.part(parent, "Steam", e.size, cf, look(rgb(235, 235, 240), Enum.Material.SmoothPlastic, nil, 0.7), { collide = false, query = false, shadow = false })
		tag(column, "BasementSteam", i)
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Steam"
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.6, 1)
		emitter.Speed = NumberRange.new(10, 14)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.2) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		emitter.EmissionDirection = Enum.NormalId.Top
		emitter.Parent = vent
		vent:SetAttribute("Element", i)
		CollectionService:AddTag(vent, "BasementVent")
		return column
	elseif kind == "laser" then
		local beamPart = Kit.part(parent, "Laser", e.size, cf, look(rgb(255, 40, 60), Enum.Material.Neon), { collide = false, query = false, shadow = false })
		for _, side in { -1, 1 } do
			Kit.part(parent, "Emitter", Vector3.new(0.6, 1.4, 1.4), cf * CFrame.new(side * (e.size.X / 2 + 0.3), 0, 0), L.blackLacquer, { collide = false })
		end
		tag(beamPart, "BasementLaser", i)
		return beamPart
	elseif kind == "spinner" then
		local bar = Kit.part(parent, "ValveBar", e.size, cf, look(rgb(200, 40, 40), Enum.Material.Metal, 0.1), { collide = false, query = false })
		Kit.post(parent, "Hub", 2.4, 2.2, o + e.at - Vector3.new(0, 1.6, 0), look(rgb(184, 110, 64), Enum.Material.Metal, 0.15))
		tag(bar, "BasementSpinner", i)
		return bar
	elseif kind == "pit" then
		local p = Kit.part(parent, "Pit", e.size, cf, PIT[zone] or PIT[1], { shadow = false })
		Kit.pointLight(p, if zone == 2 then 1.1 else 0.7, 30, PIT_GLOW[zone] or PIT_GLOW[1])
		return p
	end
	return nil
end

function BasementBuild.build(parent: Instance, o: Vector3, goHome: (player: Player) -> ()): Built
	local root = Kit.model(parent, "MaisonBasement")
	root:SetAttribute("Attraction", "basement")
	local course = Kit.model(root, "Course")
	local arch = Kit.model(root, "Architecture")
	local parts: { [number]: BasePart } = {}
	local checkpoints: { [number]: BasePart } = {}
	local lifts: { [number]: ProximityPrompt } = {}

	-- The entry hall, at the foot of the stair down, with the arch home behind you.
	Kit.part(arch, "EntryHall", Vector3.new(12, 1, 12), CFrame.new(o + Vector3.new(0, -0.5, -10)), LOOKS.stone)
	Kit.part(arch, "EntryWall", Vector3.new(37, 34, 1), CFrame.new(o + Vector3.new(0, 1, -17.5)), WALL[1])

	for i, e in Plan.Elements do
		local zone = Plan.zoneOf(math.max(1, e.stage))
		local p = element(course, o, i, e, zone)
		if p then
			parts[i] = p
		end
	end

	-- The checkpoints: a ring of the part's colour round each, its number, a lift at each part's end.
	for n = 0, Plan.STAGES do
		local c = Plan.Checkpoints[n]
		local zone = Plan.Zones[c.zone]
		local top = o + c.at
		local ring = Kit.part(course, "CheckpointRing", Vector3.new(c.size.X - 1, 0.1, c.size.Z - 1), CFrame.new(top + Vector3.new(0, 0.06, 0)), look(zone.colour, Enum.Material.Neon, nil, 0.55), { collide = false, query = false, shadow = false })
		ring.Name = "Checkpoint" .. n
		ring:SetAttribute("Checkpoint", n)
		checkpoints[n] = ring
		if n > 0 and n < Plan.STAGES then
			sign(course, top + Vector3.new(0, 9, c.size.Z / 2 + 0.4), top + Vector3.new(0, 9, c.size.Z / 2 + 40), string.format("%d  ·  %s", n + 1, string.upper(Plan.StageNames[n + 1])), zone.name, zone.colour)
		elseif n == 0 then
			sign(course, top + Vector3.new(0, 9, c.size.Z / 2 + 0.4), top + Vector3.new(0, 9, c.size.Z / 2 + 40), "1  ·  " .. string.upper(Plan.StageNames[1]), "The Maison Basement  ·  sixteen stages down to the Treasury", zone.colour)
		end
		if n > 0 and n % 4 == 0 and n < Plan.STAGES then
			-- A lift up to the Maison: everything you've earned is yours.
			local cage = Kit.model(course, "Lift" .. n)
			local at = top + Vector3.new(c.size.X / 2 - 1.6, 0, 0)
			for _, dz in { -1.4, 1.4 } do
				Kit.post(cage, "Rail", 9, 0.3, at + Vector3.new(0, 0, dz), L.brass, { collide = false })
			end
			local plate = Kit.part(cage, "LiftDoor", Vector3.new(0.3, 7, 2.6), CFrame.new(at + Vector3.new(0.6, 3.5, 0)), look(GOLD, Enum.Material.Metal, 0.3), { collide = false })
			lifts[n] = prompt(plate, "Lift", "Lift up", "Back to the Maison, with all you've earned", 0.4)
			Kit.pointLight(plate, 0.9, 14, rgb(255, 214, 150))
		end
		-- (A lamp over every checkpoint.)
		local lamp = Kit.part(course, "Lamp", Vector3.new(1.2, 0.4, 1.2), CFrame.new(top + Vector3.new(0, 12, 0)), look(rgb(255, 230, 190), Enum.Material.Neon), { collide = false, query = false, shadow = false })
		Kit.pointLight(lamp, 1.1, 30, zone.colour:Lerp(rgb(255, 240, 220), 0.6))
	end

	-- Walls and a ceiling over each stage, in its part's look.
	for n = 1, Plan.STAGES do
		local a, b = Plan.Checkpoints[n - 1], Plan.Checkpoints[n]
		local pit = Plan.Pits[n]
		local zone = Plan.zoneOf(n)
		-- (From the middle of one checkpoint to the middle of the next: no two walls overlap.)
		local z0 = if n == 1 then -17 else a.at.Z
		local z1 = if n == Plan.STAGES then b.at.Z + b.size.Z / 2 + 1 else b.at.Z
		local high = math.max(a.at.Y, b.at.Y) + 18
		if n == 10 then
			high += 8 -- (over the truss's ledge)
		end
		local low = pit.at.Y - 1
		local h = high - low
		for _, x in { -18, 18 } do
			Kit.part(arch, "Wall", Vector3.new(1, h, z1 - z0), CFrame.new(o + Vector3.new(x, low + h / 2, (z0 + z1) / 2)), WALL[zone])
		end
		Kit.part(arch, "Ceiling", Vector3.new(37, 1, z1 - z0), CFrame.new(o + Vector3.new(0, high + 0.5, (z0 + z1) / 2)), L.blackLacquer, { shadow = false })
		if n == Plan.STAGES then
			Kit.part(arch, "EndWall", Vector3.new(37, h, 1), CFrame.new(o + Vector3.new(0, low + h / 2, z1 + 0.5)), WALL[zone])
		end
	end

	-- The Treasury: the chest, the gold, and the arch home.
	local t = Plan.Checkpoints[Plan.STAGES]
	local chestEl: Plan.El? = nil
	for _, e in Plan.Elements do
		if e.kind == "chest" then
			chestEl = e
		end
	end
	local chest: Model? = nil
	if chestEl then
		local m = Kit.model(root, "TreasuryChest")
		local c = CFrame.new(o + chestEl.at)
		Kit.part(m, "Chest", chestEl.size, c, LOOKS.barrel)
		Kit.part(m, "Lid", Vector3.new(chestEl.size.X + 0.2, 0.6, chestEl.size.Z + 0.2), c * CFrame.new(0, chestEl.size.Y / 2 + 0.3, 0), look(GOLD, Enum.Material.Metal, 0.3))
		local glow = Kit.part(m, "Glow", Vector3.new(chestEl.size.X - 0.6, 0.2, chestEl.size.Z - 0.6), c * CFrame.new(0, chestEl.size.Y / 2 + 0.7, 0), look(GOLD, Enum.Material.Neon), { collide = false, shadow = false })
		Kit.pointLight(glow, 2, 30, GOLD)
		HolidayProps.sparkle(glow, GOLD, 10, 0.7)
		for k = -2, 2 do
			Kit.part(m, "GoldStack", Vector3.new(2, 1 + math.abs(k) * 0.6, 3), CFrame.new(o + t.at + Vector3.new(k * 4.4, 0.5 + math.abs(k) * 0.3, 6.5)), look(GOLD, Enum.Material.Metal, 0.3), { collide = false })
		end
		chest = m
	end
	local homeArch: BasePart? = nil
	local ok, err = pcall(function()
		homeArch = Portal.build(root, CFrame.lookAt(o + Vector3.new(0, 0, -13.5), o + Vector3.new(0, 0, -30)), "The Maison Basement", goHome)
	end)
	if not ok then
		warn("[Maison] The Maison Basement's arch home couldn't be built: " .. tostring(err))
	end
	pcall(function()
		Portal.build(root, CFrame.lookAt(o + t.at + Vector3.new(0, 0, t.size.Z / 2 - 1.5), o + t.at + Vector3.new(0, 0, t.size.Z / 2 + 20)), "The Maison Basement", goHome)
	end)
	return { root = root, parts = parts, checkpoints = checkpoints, lifts = lifts, chest = chest, homeArch = homeArch }
end

return BasementBuild

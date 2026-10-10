--!strict
-- The Vault (§3, §11): a quiet, low room through the Foyer's back wall. Six tall glass cabinets,
-- one for each case, fill with the pieces a guest has filed (each guest sees their own); the
-- centre cabinet holds their Mythics with their serial numbers. The Archivist keeps the Register
-- at a desk by the door: "Everything you've found is kept here."

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Layout = require(ReplicatedStorage.Shared.Layout).raw -- (the house as drawn: see World/Grand)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local V = Layout.Vault
local FLOOR = Layout.FLOOR

local VaultRoom = {}

local INVISIBLE = { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }
local GLASS = { color = Color3.fromRGB(214, 226, 236), material = Enum.Material.Glass, reflectance = 0.18, transparency = 0.9 }
local VELVET = { color = Color3.fromRGB(22, 14, 28), material = Enum.Material.Fabric }
local FLOOR_LOOK = { color = Color3.fromRGB(12, 12, 15), material = Enum.Material.Marble, reflectance = 0.22 }
local GOLD_LIGHT = Color3.fromRGB(255, 204, 122)
local VIOLET_LIGHT = Color3.fromRGB(196, 128, 255)
local function led(colour: Color3, transparency: number?): Kit.Look
	return { color = colour, material = Enum.Material.Neon, transparency = transparency or 0 }
end

-- A vitrine's measures (its own frame: origin on the floor at its foot, +Z facing the room).
local W, D, H = 4.6, 2.5, 9.6 -- the glass
local BASE = 1 -- the plinth
local SHELVES, STEP, FIRST = 4, 2.3, BASE + 0.25 -- shelves, apart, the first one's middle

-- A tall vitrine: a black lacquer plinth with a line of light along its foot, a back of dark
-- velvet, four shelves of softly lit glass, glowing gold lines up its front corners, a lit
-- ceiling inside its brass crown (a spotlight down onto the pieces), and its name on a brass
-- plate. The Mythics' vitrine is lit violet.
local function cabinet(m: Model, name: string, cf: CFrame, caseId: string?, label: string)
	local model = Kit.model(m, name)
	local glow = if caseId then GOLD_LIGHT else VIOLET_LIGHT
	local off = { collide = false, query = false, shadow = false }
	Kit.part(model, "Plinth", Vector3.new(W, BASE, D), cf * CFrame.new(0, BASE / 2, 0), L.blackLacquer)
	Kit.part(model, "PlinthLight", Vector3.new(W - 0.3, 0.08, 0.06), cf * CFrame.new(0, BASE - 0.16, D / 2 + 0.02), led(glow), off)
	Kit.part(model, "Back", Vector3.new(W, H, 0.2), cf * CFrame.new(0, BASE + H / 2, -D / 2 + 0.1), VELVET)
	for i = 1, SHELVES do
		-- (Each shelf a pane of lit glass: it glows softly in the case's own light.)
		local y = FIRST + (i - 1) * STEP
		local shelf = Kit.part(model, "Shelf" .. i, Vector3.new(W - 0.3, 0.08, D - 0.4), cf * CFrame.new(0, y, 0), led(glow:Lerp(Color3.new(1, 1, 1), 0.55), 0.78), off)
		shelf:SetAttribute("Shelf", i)
	end
	for _, side in { -1, 1 } do
		Kit.part(model, "EdgeLight", Vector3.new(0.07, H - 0.1, 0.07), cf * CFrame.new(side * (W / 2 - 0.05), BASE + H / 2, D / 2 - 0.05), led(glow, 0.05), off)
	end
	Kit.part(model, "Glass", Vector3.new(W, H, D), cf * CFrame.new(0, BASE + H / 2, 0), GLASS, { shadow = false })
	Kit.part(model, "Crown", Vector3.new(W + 0.3, 0.5, D + 0.3), cf * CFrame.new(0, BASE + H + 0.25, 0), L.brass)
	-- The lit ceiling of the case, and its light falling on every shelf.
	local lightbox = Kit.part(model, "Lightbox", Vector3.new(W - 0.3, 0.06, D - 0.4), cf * CFrame.new(0, BASE + H - 0.06, 0), led(Color3.fromRGB(255, 240, 220), 0.15), off)
	Kit.spotLight(lightbox, Enum.NormalId.Bottom, if caseId then 1.5 else 2.2, 13, 80, if caseId then Color3.fromRGB(255, 236, 210) else Color3.fromRGB(232, 210, 255), false)
	local plate = Kit.part(model, "Plate", Vector3.new(2.6, 0.42, 0.05), cf * CFrame.new(0, 0.5, D / 2 + 0.03), L.brass, off)
	Kit.engrave(plate, Enum.NormalId.Front, { { text = Caps(label), size = 0.6, font = Brand.Fonts.bodyBold, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 100, lit = false })
	model:SetAttribute("Frame", cf)
	-- (Where the pieces stand, for the Vault's own screen: VaultView.)
	model:SetAttribute("SlotShelves", SHELVES)
	model:SetAttribute("SlotFirstY", FIRST + 0.04)
	model:SetAttribute("SlotStepY", STEP)
	model:SetAttribute("SlotSpan", W - 1.2)
	if caseId then
		model:SetAttribute("Case", caseId)
	else
		model:SetAttribute("Mythics", true)
	end
	CollectionService:AddTag(model, "VaultCabinet")
end

local STEEL = { color = Color3.fromRGB(150, 154, 160), material = Enum.Material.DiamondPlate, reflectance = 0.1 }
local POLISHED = { color = Color3.fromRGB(176, 180, 186), material = Enum.Material.Metal, reflectance = 0.3 }
local GOLDBAR = { color = Color3.fromRGB(232, 184, 72), material = Enum.Material.Metal, reflectance = 0.35 }

-- A thin bar of light from `a` to `b`.
local function beam(m: Instance, name: string, a: Vector3, b: Vector3, look: Kit.Look, thick: number?)
	local t = thick or 0.06
	Kit.part(m, name, Vector3.new(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), look, { collide = false, query = false, shadow = false })
end

-- The room's dressing: the great round vault door on the east wall (shut, for show) in a halo of
-- light behind a soft laser grid, gold bars stacked either side; a floor of polished black marble
-- with a ring of light round the Mythics, and a shaft of light falling on them
-- from the ceiling; lines of light up the walls and round the ceiling's edge; gold motes drifting
-- in the air; sconces; and a glowing sign over the Archivist's desk.
function VaultRoom.dress(m: Model, top: number)
	local off = { collide = false, query = false, shadow = false }
	-- The vault door: a steel disc in a brass ring, a wheel of spokes, a ring of bolts, all one
	-- piece (a "door": it opens out with the room as one, its wheel the right size for its disc).
	local x = V.maxX - 0.2
	local c = Vector3.new(x - 0.6, FLOOR + 6, 55.5)
	local face = CFrame.new(c)
	local works = Kit.model(m, "VaultDoorWorks")
	Kit.cylinder(works, "VaultDoorHalo", 0.12, 11.8, face * CFrame.new(0.32, 0, 0), led(GOLD_LIGHT, 0.35), off)
	Kit.cylinder(works, "VaultDoorRing", 0.5, 10.4, face, L.brass, { collide = false, query = false })
	Kit.cylinder(works, "VaultDoor", 0.9, 9.4, face * CFrame.new(-0.3, 0, 0), STEEL, { collide = false, query = false })
	Kit.cylinder(works, "VaultDoorInner", 0.1, 8.2, face * CFrame.new(-0.78, 0, 0), led(GOLD_LIGHT, 0.6), off)
	Kit.cylinder(works, "VaultHub", 1.4, 2.2, face * CFrame.new(-0.9, 0, 0), POLISHED, { collide = false, query = false })
	for i = 0, 5 do
		local a = math.rad(i * 60)
		Kit.part(works, "VaultSpoke", Vector3.new(0.35, 5.2, 0.35), CFrame.new(c + Vector3.new(-1.3, 0, 0)) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 1.6, 0), POLISHED, off)
		Kit.ball(works, "VaultKnob", 0.55, c + Vector3.new(-1.35, math.cos(a) * 4.1, math.sin(a) * 4.1), L.brass, off)
	end
	for i = 0, 15 do
		local a = math.rad(i * 22.5)
		Kit.cylinder(works, "VaultBolt", 0.3, 0.45, CFrame.new(c + Vector3.new(-0.85, math.cos(a) * 4.3, math.sin(a) * 4.3)), POLISHED, off)
	end
	local vplate = Kit.part(works, "VaultPlate", Vector3.new(0.05, 0.6, 3), CFrame.lookAt(c + Vector3.new(-1, -5.6, 0), c + Vector3.new(-10, -5.6, 0)), L.brass, off)
	Kit.engrave(vplate, Enum.NormalId.Front, { { text = "MAISON NOIR · 1889", size = 0.3, font = Brand.Fonts.display, color = Color3.fromRGB(40, 30, 12) } }, { ppu = 80, lit = false })
	-- A soft laser grid before the door (light only: nothing to trip on).
	local lx = c.X - 2.2
	local laser = led(Color3.fromRGB(255, 70, 96), 0.3)
	beam(m, "Laser", Vector3.new(lx, FLOOR + 1.6, 52), Vector3.new(lx, FLOOR + 9.6, 59), laser, 0.05)
	beam(m, "Laser", Vector3.new(lx, FLOOR + 9.6, 52), Vector3.new(lx, FLOOR + 1.6, 59), laser, 0.05)
	beam(m, "Laser", Vector3.new(lx, FLOOR + 5.6, 51.6), Vector3.new(lx, FLOOR + 5.6, 59.4), laser, 0.05)
	-- Gold bars, stacked in a pyramid on a low black plinth with a line of light, either side of
	-- the vault door.
	for _, z in { 51.2, 60.5 } do
		Kit.part(m, "BarPlinth", Vector3.new(2.6, 0.6, 2.2), CFrame.new(x - 1.6, FLOOR + 0.3, z), L.blackLacquer)
		Kit.part(m, "BarPlinthLight", Vector3.new(0.05, 0.06, 2), CFrame.new(x - 2.92, FLOOR + 0.48, z), led(GOLD_LIGHT), off)
		for row = 0, 2 do
			for i = 0, 2 - row do
				Kit.part(m, "GoldBar", Vector3.new(0.7, 0.35, 1.6), CFrame.new(x - 2.4 + row * 0.38 + i * 0.78, FLOOR + 0.78 + row * 0.36, z), GOLDBAR, off)
			end
		end
	end
	-- Panelled walls: a brass dado rail, and raised panels below it.
	for _, w in {
		{ a = Vector3.new(V.minX, FLOOR + 3.2, V.minZ), b = Vector3.new(V.minX + 0.12, FLOOR + 3.4, V.maxZ) },
		{ a = Vector3.new(V.minX, FLOOR + 3.2, V.maxZ - 0.12), b = Vector3.new(V.maxX, FLOOR + 3.4, V.maxZ) },
		{ a = Vector3.new(V.maxX - 0.12, FLOOR + 3.2, V.minZ), b = Vector3.new(V.maxX, FLOOR + 3.4, 49.9) },
		{ a = Vector3.new(V.maxX - 0.12, FLOOR + 3.2, 61.1), b = Vector3.new(V.maxX, FLOOR + 3.4, V.maxZ) },
	} do
		Kit.span(m, "Dado", w.a, w.b, L.brass, { collide = false, query = false, shadow = false })
	end
	-- Lines of light up the walls, between and beside the vitrines.
	for _, z in { 45.5, 50.5, 55.5, 60.5 } do
		Kit.span(m, "WallLight", Vector3.new(V.minX + 0.02, FLOOR + 0.6, z - 0.06), Vector3.new(V.minX + 0.14, top - 0.8, z + 0.06), led(GOLD_LIGHT, 0.15), off)
	end
	for _, xx in { -17, -11, -5, 1 } do
		Kit.span(m, "WallLight", Vector3.new(xx - 0.06, FLOOR + 0.6, V.maxZ - 0.14), Vector3.new(xx + 0.06, top - 0.8, V.maxZ - 0.02), led(GOLD_LIGHT, 0.15), off)
	end
	-- A coffered ceiling: brass beams in a grid, and a line of light round its edge.
	for xx = V.minX + 4, V.maxX - 1, 4 do
		Kit.span(m, "Coffer", Vector3.new(xx - 0.2, top - 0.5, V.minZ), Vector3.new(xx + 0.2, top, V.maxZ), L.darkBrass, { collide = false, query = false, shadow = false })
	end
	for zz = V.minZ + 4, V.maxZ - 1, 4.5 do
		Kit.span(m, "Coffer", Vector3.new(V.minX, top - 0.45, zz - 0.2), Vector3.new(V.maxX, top - 0.05, zz + 0.2), L.darkBrass, { collide = false, query = false, shadow = false })
	end
	local cove = led(GOLD_LIGHT, 0.25)
	Kit.span(m, "CoveLight", Vector3.new(V.minX + 0.2, top - 0.7, V.minZ + 0.2), Vector3.new(V.maxX - 0.2, top - 0.6, V.minZ + 0.32), cove, off)
	Kit.span(m, "CoveLight", Vector3.new(V.minX + 0.2, top - 0.7, V.maxZ - 0.32), Vector3.new(V.maxX - 0.2, top - 0.6, V.maxZ - 0.2), cove, off)
	Kit.span(m, "CoveLight", Vector3.new(V.minX + 0.2, top - 0.7, V.minZ + 0.2), Vector3.new(V.minX + 0.32, top - 0.6, V.maxZ - 0.2), cove, off)
	Kit.span(m, "CoveLight", Vector3.new(V.maxX - 0.32, top - 0.7, V.minZ + 0.2), Vector3.new(V.maxX - 0.2, top - 0.6, V.maxZ - 0.2), cove, off)
	-- A ring of light in the floor round the Mythics, and a shaft of light falling on them.
	local centre = V.centre
	local flat = CFrame.new(centre.X, FLOOR, centre.Z) * CFrame.Angles(0, 0, math.rad(90))
	Kit.cylinder(m, "FloorRing", 0.03, 9.6, flat * CFrame.new(0.02, 0, 0), led(VIOLET_LIGHT, 0.2), off)
	Kit.cylinder(m, "FloorRingInner", 0.03, 9, flat * CFrame.new(0.04, 0, 0), FLOOR_LOOK, off)
	Kit.cylinder(m, "FloorRing2", 0.03, 7.4, flat * CFrame.new(0.05, 0, 0), led(GOLD_LIGHT, 0.35), off)
	Kit.cylinder(m, "FloorRing2Inner", 0.03, 7.1, flat * CFrame.new(0.06, 0, 0), FLOOR_LOOK, off)
	Kit.cylinder(m, "LightShaft", top - FLOOR - 0.6, 6.6, CFrame.new(centre.X, (FLOOR + top) / 2, centre.Z) * CFrame.Angles(0, 0, math.rad(90)), led(Color3.fromRGB(222, 196, 255), 0.94), off)
	local shaftLamp = Kit.part(m, "ShaftLamp", Vector3.new(0.4, 0.4, 0.4), CFrame.new(centre.X, top - 0.8, centre.Z), INVISIBLE, off)
	Kit.spotLight(shaftLamp, Enum.NormalId.Bottom, 2.4, 18, 34, Color3.fromRGB(230, 210, 255), false)
	-- Sconces between the vitrines on the west wall (glow only; the room's lights do the work).
	for _, z in { 50.5, 55.5 } do
		Kit.part(m, "Sconce", Vector3.new(0.4, 0.9, 0.5), CFrame.new(V.minX + 0.3, FLOOR + 6.5, z), L.brass, { collide = false, query = false, shadow = false })
		Kit.ball(m, "SconceGlow", 0.5, Vector3.new(V.minX + 0.55, FLOOR + 7.1, z), { color = Color3.fromRGB(255, 214, 160), material = Enum.Material.Neon }, { collide = false, query = false, shadow = false })
	end
	-- A pool of light on the vault door.
	local spot = Kit.part(m, "VaultSpot", Vector3.new(0.3, 0.3, 0.3), CFrame.new(x - 6, top - 1, 55.5), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.spotLight(spot, Enum.NormalId.Bottom, 1.6, 16, 60)
	-- Gold motes drifting through the air of the room.
	local air = Kit.part(m, "AirMotes", Vector3.new(V.maxX - V.minX - 4, top - FLOOR - 3, V.maxZ - V.minZ - 4), CFrame.new((V.minX + V.maxX) / 2, (FLOOR + top) / 2, (V.minZ + V.maxZ) / 2), INVISIBLE, off)
	local motes = Instance.new("ParticleEmitter")
	motes.Name = "Motes"
	motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	motes.Rate = 7
	motes.Lifetime = NumberRange.new(8, 13)
	motes.Speed = NumberRange.new(0.1, 0.4)
	motes.SpreadAngle = Vector2.new(180, 180)
	motes.RotSpeed = NumberRange.new(-20, 20)
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, 0.16), NumberSequenceKeypoint.new(1, 0) })
	motes.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.25), NumberSequenceKeypoint.new(0.8, 0.4), NumberSequenceKeypoint.new(1, 1) })
	motes.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150), Color3.fromRGB(255, 196, 92))
	pcall(function()
		(motes :: any).Shape = Enum.ParticleEmitterShape.Box;
		(motes :: any).ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	end)
	motes.Parent = air
end

function VaultRoom.build(parent: Instance): Model
	local m = Kit.model(parent, "Vault")
	local top = FLOOR + V.height
	Kit.span(m, "Floor", Vector3.new(V.minX, FLOOR - 1, V.minZ), Vector3.new(V.maxX, FLOOR, V.maxZ), FLOOR_LOOK)
	Kit.span(m, "Ceiling", Vector3.new(V.minX - 2, top, V.minZ), Vector3.new(V.maxX + 2, top + 1, V.maxZ + 2), L.darkWood)
	Kit.span(m, "WallW", Vector3.new(V.minX - 2, FLOOR, V.minZ), Vector3.new(V.minX, top, V.maxZ + 2), L.panel)
	Kit.span(m, "WallE", Vector3.new(V.maxX, FLOOR, V.minZ), Vector3.new(V.maxX + 2, top, V.maxZ + 2), L.panel)
	Kit.span(m, "WallN", Vector3.new(V.minX - 2, FLOOR, V.maxZ), Vector3.new(V.maxX + 2, top, V.maxZ + 2), L.panel)
	-- A brass doorframe on the Foyer side.
	local d = V.door
	local hw = V.doorWidth / 2
	Kit.part(m, "DoorJambL", Vector3.new(0.5, 10.4, 2.4), CFrame.new(d.X - hw - 0.25, FLOOR + 5.2, 43), L.brass)
	Kit.part(m, "DoorJambR", Vector3.new(0.5, 10.4, 2.4), CFrame.new(d.X + hw + 0.25, FLOOR + 5.2, 43), L.brass)
	Kit.part(m, "DoorHead", Vector3.new(V.doorWidth + 1.4, 0.5, 2.4), CFrame.new(d.X, FLOOR + 10.2, 43), L.brass)
	local sign = Kit.part(m, "DoorName", Vector3.new(6, 1, 0.1), CFrame.lookAt(Vector3.new(d.X, FLOOR + 11.3, 41.7), Vector3.new(d.X, FLOOR + 11.3, 0)), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.engrave(sign, Enum.NormalId.Front, { { text = "THE VAULT", size = 0.6, font = Brand.Fonts.display, color = Brand.Colours.lightGold } }, { ppu = 60, lit = false })
	-- Six cabinets: three on the west wall, three on the north wall.
	local slots = {
		CFrame.lookAt(Vector3.new(V.minX + 1, FLOOR, 48), Vector3.new(0, FLOOR, 48)),
		CFrame.lookAt(Vector3.new(V.minX + 1, FLOOR, 53), Vector3.new(0, FLOOR, 53)),
		CFrame.lookAt(Vector3.new(V.minX + 1, FLOOR, 58), Vector3.new(0, FLOOR, 58)),
		CFrame.lookAt(Vector3.new(-14, FLOOR, V.maxZ - 1), Vector3.new(-14, FLOOR, 44)),
		CFrame.lookAt(Vector3.new(-8, FLOOR, V.maxZ - 1), Vector3.new(-8, FLOOR, 44)),
		CFrame.lookAt(Vector3.new(-2, FLOOR, V.maxZ - 1), Vector3.new(-2, FLOOR, 44)),
	}
	for i, c in Catalogue.Cases do
		-- lookAt faces -Z at the room; the cabinet's own +Z should face the room, so turn it.
		cabinet(m, "Cabinet_" .. c.id, slots[i] * CFrame.Angles(0, math.pi, 0), c.id, c.name)
	end
	-- The centre cabinet: the Mythics.
	cabinet(m, "Cabinet_Mythics", CFrame.new(V.centre) * CFrame.Angles(0, math.pi, 0), nil, "Mythics")
	-- The Archivist's desk by the door, and the Register on it. (It goes exactly where its spot
	-- goes in the Grand house, so the Archivist behind it has room: World/Grand.)
	local desk = V.desk
	local deskModel = Kit.model(m, "ArchivistDesk")
	deskModel:SetAttribute("GrandAnchor", desk.Position)
	Kit.part(deskModel, "Desk", Vector3.new(1.6, 3.1, 4), desk * CFrame.new(0, 1.55, 0), L.walnut)
	Kit.part(deskModel, "DeskTop", Vector3.new(1.9, 0.12, 4.3), desk * CFrame.new(0, 3.16, 0), L.darkWood, { shadow = false })
	local book = Kit.part(deskModel, "RegisterBook", Vector3.new(0.9, 0.2, 1.2), desk * CFrame.new(0, 3.32, 0), { color = Color3.fromRGB(62, 30, 20), material = Enum.Material.Leather }, { collide = false })
	local p = Instance.new("ProximityPrompt")
	p.Name = "RegisterPrompt"
	p.ActionText = "Read"
	p.ObjectText = "The Register"
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p:SetAttribute("Offset", 0.5)
	p.Parent = book
	CollectionService:AddTag(book, "RegisterBook")
	local lamp = Kit.part(deskModel, "DeskLamp", Vector3.new(0.6, 0.5, 0.6), desk * CFrame.new(0, 4, 1.5), L.brass, { collide = false })
	Kit.pointLight(lamp, 0.7, 10, Color3.fromRGB(255, 214, 160))
	-- Over the desk, glowing in the air: what's kept here, so nobody walks past it.
	local over = Kit.part(deskModel, "RegisterGlow", Vector3.new(5, 1.3, 0.05), desk * CFrame.new(0, 6.6, 0), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.engrave(over, Enum.NormalId.Front, {
		{ text = "THE REGISTER", size = 0.56, font = Brand.Fonts.display, color = Brand.Colours.brightGold },
		{ text = "Everything you've filed, kept here", size = 0.3, font = Brand.Fonts.bodyBold, color = Color3.fromRGB(236, 226, 206) },
	}, { ppu = 90, lit = false, brightness = 2 })
	VaultRoom.dress(m, top)
	local fill = Kit.part(m, "Fill", Vector3.new(1, 1, 1), CFrame.new(-8, top - 2, 53), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.pointLight(fill, 0.6, 34, Color3.fromRGB(230, 214, 200))
	return m
end

return VaultRoom

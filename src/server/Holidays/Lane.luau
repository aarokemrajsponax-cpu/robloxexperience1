--!strict
-- Hallows Lane (All Hallows'): trick or treat, away from the Maison. A cobbled street of grand
-- houses under the harvest moon, eight facing each other across it and the ninth, Maison Minuit,
-- closing its far end; railings, gas lamps, jack-o'-lanterns on every step, violet light washing
-- up the fronts. Knock at a door (its prompt) and it opens on a lit hall, where a host in costume
-- (a masked countess, a pumpkin-headed gentleman, a friendly ghost in a bow tie...) hands over a
-- treat: Gilt, and now and then a sugared Gem. Each door once a round for each guest; every door
-- in one round fills the bag (more Gilt, a few Gems, the Candy Pail). Everything is gentle:
-- costumes, sweets and candlelight.
--
-- The server builds the street and the hosts and decides every treat; every screen opens the
-- doors, walks the host out and throws the treat (World/HolidayGames), and dresses the street
-- with mist and flickering candles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Names = require(ReplicatedStorage.Shared.Names)
local Kit = require(script.Parent.Parent.World.Kit)
local Profiles = require(script.Parent.Parent.Profiles)
local Rig = require(script.Parent.Parent.Staff.Rig)
local Dress = require(script.Parent.Dress)
local Types = require(script.Parent.Types)

local Lane = {}

local rgb = Color3.fromRGB
local L = Kit.Looks
local WHITE = Color3.new(1, 1, 1)

type Look = Kit.Look
local function look(colour: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Look
	return { color = colour, material = material, reflectance = reflectance, transparency = transparency }
end

-- The hosts, door by door: who answers, what they wear, the treat and what they say.
export type Host = { name: string, costume: string, treat: string, treatName: string, line: string, skin: Color3, coat: Color3 }
Lane.Hosts = {
	{ name = "Lady Belladonna", costume = "masquerade", treat = "truffle", treatName = "a gold-wrapped truffle", line = "Happy Halloween, darling. Do take a truffle.", skin = rgb(236, 192, 160), coat = rgb(16, 12, 18) },
	{ name = "The Count of Velvet", costume = "count", treat = "apple", treatName = "a caramel apple", line = "Good evening! A caramel apple, freshly dipped.", skin = rgb(228, 206, 190), coat = rgb(14, 12, 16) },
	{ name = "Madame Hexley", costume = "witch", treat = "lollipop", treatName = "a lollipop the size of your hand", line = "A little spell for luck, and a lollipop!", skin = rgb(198, 140, 102), coat = rgb(70, 34, 100) },
	{ name = "Mr Pumpkin", costume = "pumpkin", treat = "chocolate", treatName = "a chocolate pumpkin", line = "Trick or treat? Treat. Always treat.", skin = rgb(160, 110, 80), coat = rgb(30, 44, 30) },
	{ name = "The Black Cat", costume = "cat", treat = "macaron", treatName = "a stack of macarons", line = "Purr-fect timing. Macarons, all for you.", skin = rgb(120, 84, 62), coat = rgb(12, 12, 14) },
	{ name = "Merlin", costume = "wizard", treat = "caramel", treatName = "a salted caramel", line = "Abracadabra! One salted caramel, conjured.", skin = rgb(234, 184, 146), coat = rgb(30, 40, 110) },
	{ name = "Boo", costume = "ghost", treat = "beans", treatName = "a velvet bag of jelly beans", line = "Boo! ...sorry, did I startle you? Jelly beans?", skin = rgb(240, 240, 240), coat = rgb(240, 240, 240) },
	{ name = "The Fairy Godmother", costume = "fairy", treat = "floss", treatName = "a cloud of candy floss", line = "A wish for you, and a cloud of candy floss.", skin = rgb(255, 214, 180), coat = rgb(150, 190, 240) },
	{ name = "The Midnight Hostess", costume = "hostess", treat = "truffle", treatName = "the good chocolate", line = "Welcome to Maison Minuit. The good chocolate is for you.", skin = rgb(176, 120, 90), coat = rgb(10, 10, 12) },
} :: { Host }

-- How each house looks: its name, width, storeys, roof, walls, trim, roof slate, door, and the
-- light in its windows and washing up its front.
type Style = { name: string, width: number, storeys: number, roof: string, wall: Look, trim: Look, slate: Look, door: Color3, glow: Color3, wash: Color3 }
local ORANGE = rgb(255, 156, 64)
local VIOLET = rgb(176, 108, 255)
local STYLES: { Style } = {
	{ name = "The Velvet Manor", width = 40, storeys = 3, roof = "mansard", wall = look(rgb(64, 30, 52), Enum.Material.Brick), trim = look(rgb(214, 200, 176), Enum.Material.Limestone), slate = look(rgb(34, 34, 42), Enum.Material.Slate), door = rgb(120, 20, 36), glow = ORANGE, wash = VIOLET },
	{ name = "Rosewood Hall", width = 44, storeys = 2, roof = "gable", wall = look(rgb(96, 34, 30), Enum.Material.Brick), trim = look(rgb(232, 228, 216), Enum.Material.Plaster), slate = look(rgb(40, 36, 40), Enum.Material.Slate), door = rgb(16, 16, 18), glow = ORANGE, wash = ORANGE },
	{ name = "The Raven's Rest", width = 38, storeys = 3, roof = "turret", wall = look(rgb(52, 54, 60), Enum.Material.Slate), trim = look(rgb(150, 154, 162), Enum.Material.Limestone), slate = look(rgb(28, 30, 38), Enum.Material.Slate), door = rgb(74, 30, 90), glow = VIOLET, wash = VIOLET },
	{ name = "Château Lumière", width = 46, storeys = 2, roof = "mansard", wall = look(rgb(196, 168, 120), Enum.Material.Limestone), trim = look(rgb(238, 232, 218), Enum.Material.Marble), slate = look(rgb(46, 52, 66), Enum.Material.Slate), door = rgb(24, 36, 70), glow = ORANGE, wash = ORANGE },
	{ name = "Hollowmere House", width = 40, storeys = 3, roof = "flat", wall = look(rgb(30, 52, 42), Enum.Material.Plaster), trim = look(rgb(222, 206, 160), Enum.Material.Limestone), slate = look(rgb(30, 34, 32), Enum.Material.Slate), door = rgb(150, 110, 40), glow = ORANGE, wash = VIOLET },
	{ name = "The Gilded Gate", width = 42, storeys = 2, roof = "turret", wall = look(rgb(28, 26, 30), Enum.Material.Brick), trim = look(rgb(200, 158, 80), Enum.Material.Limestone), slate = look(rgb(26, 26, 30), Enum.Material.Slate), door = rgb(140, 30, 30), glow = VIOLET, wash = ORANGE },
	{ name = "Moonlight Villa", width = 44, storeys = 2, roof = "flat", wall = look(rgb(214, 214, 222), Enum.Material.Plaster), trim = look(rgb(150, 160, 190), Enum.Material.Marble), slate = look(rgb(40, 44, 58), Enum.Material.Slate), door = rgb(40, 50, 90), glow = VIOLET, wash = VIOLET },
	{ name = "Thornbury Manor", width = 40, storeys = 3, roof = "gable", wall = look(rgb(110, 76, 52), Enum.Material.Brick), trim = look(rgb(226, 214, 190), Enum.Material.Limestone), slate = look(rgb(36, 32, 30), Enum.Material.Slate), door = rgb(36, 70, 44), glow = ORANGE, wash = ORANGE },
	{ name = "Maison Minuit", width = 64, storeys = 3, roof = "turret", wall = look(rgb(16, 15, 18), Enum.Material.Marble, 0.05), trim = look(rgb(200, 158, 80), Enum.Material.Limestone), slate = look(rgb(20, 20, 26), Enum.Material.Slate), door = rgb(10, 10, 12), glow = ORANGE, wash = VIOLET },
}

local SH = 12 -- a storey's height
local DEPTH = 30

type Door = { cf: CFrame, house: Model, host: Model?, prompt: ProximityPrompt }
local doors: { Door } = {}
local built: Model? = nil
local lastKnock: { [Player]: number } = {}
local opened = false

---------------------------------------------------------------------------------------------------
-- A grand house
---------------------------------------------------------------------------------------------------

-- A box in the door's own frame (+x along the front, +y up from the porch, +z into the house).
local function boxIn(parent: Instance, door: CFrame, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, lk: Look, opts: { [string]: any }?): Part
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local centre = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	return Kit.part(parent, name, size, door * CFrame.new(centre), lk, opts)
end

local TRIM_OPTS = { collide = false, query = false, shadow = false }

local function window(m: Model, door: CFrame, x: number, y: number, w: number, h: number, s: Style, lit: boolean, colour: Color3)
	boxIn(m, door, "WindowFrame", x - w / 2 - 0.45, y - h / 2 - 0.45, -0.32, x + w / 2 + 0.45, y + h / 2 + 0.45, 0.05, s.trim, TRIM_OPTS)
	local pane = if lit
		then look(colour, Enum.Material.Neon, 0, 0.22)
		else look(rgb(18, 20, 28), Enum.Material.Glass, 0.3, 0.05)
	boxIn(m, door, "Window", x - w / 2, y - h / 2, -0.44, x + w / 2, y + h / 2, -0.3, pane, TRIM_OPTS)
	boxIn(m, door, "Mullion", x - 0.09, y - h / 2, -0.56, x + 0.09, y + h / 2, -0.44, L.blackLacquer, TRIM_OPTS)
	boxIn(m, door, "Transom", x - w / 2, y + h * 0.18 - 0.09, -0.56, x + w / 2, y + h * 0.18 + 0.09, -0.44, L.blackLacquer, TRIM_OPTS)
	boxIn(m, door, "Sill", x - w / 2 - 0.7, y - h / 2 - 0.75, -0.8, x + w / 2 + 0.7, y - h / 2 - 0.4, 0.05, s.trim, TRIM_OPTS)
	boxIn(m, door, "Hood", x - w / 2 - 0.6, y + h / 2 + 0.45, -0.7, x + w / 2 + 0.6, y + h / 2 + 0.95, 0.05, s.trim, TRIM_OPTS)
end

-- A triangle standing in the door's frame (a gable or a pediment): its foot from x0 to x1 at y,
-- `height` tall, from z0 to z1.
local function triangle(m: Model, door: CFrame, name: string, x0: number, x1: number, y: number, height: number, z0: number, z1: number, lk: Look)
	local half = (x1 - x0) / 2
	local mid = (x0 + x1) / 2
	local depth = math.abs(z1 - z0)
	local zc = (z0 + z1) / 2
	-- (A wedge is tall at its back (+Z): turned a quarter, its tall side faces the middle.)
	local left = Instance.new("WedgePart")
	left.Name = name
	left.Anchored = true
	left.CanCollide = false
	left.Size = Vector3.new(depth, height, half)
	left.CFrame = door * CFrame.new(mid - half / 2, y + height / 2, zc) * CFrame.Angles(0, math.pi / 2, 0)
	left.Color = lk.color
	left.Material = lk.material
	left.Parent = m
	local right = left:Clone()
	right.CFrame = door * CFrame.new(mid + half / 2, y + height / 2, zc) * CFrame.Angles(0, -math.pi / 2, 0)
	right.Parent = m
end

-- A cone of stacked rounds (a turret's roof, a witch's hat): from diameter `d` at `base` up
-- `height`, in `tiers`.
local function cone(parent: Instance, name: string, base: Vector3, d: number, height: number, tiers: number, lk: Look)
	for i = 0, tiers - 1 do
		local f = i / tiers
		local h = height / tiers
		local di = d * (1 - f) + 0.2
		Kit.part(parent, name, Vector3.new(h + 0.02, di, di), CFrame.new(base + Vector3.new(0, h * (i + 0.5), 0)) * CFrame.Angles(0, 0, math.pi / 2), lk, { shape = Enum.PartType.Cylinder, collide = false })
	end
end

local function mansion(parent: Instance, door: CFrame, s: Style, index: number, rng: Random): (Model, Model, Model)
	local m = Kit.model(parent, "House" .. index)
	local W = s.width
	local hw = W / 2
	local storeys = s.storeys
	local R = storeys * SH -- the top of the walls, above the porch
	local G = -(HolidayGames.Lane.porch - 0.35) -- the garden's level (the pavement's), below the porch
	local D = DEPTH
	-- The plinth the house stands on, and its body round the hall behind the door.
	boxIn(m, door, "Plinth", -hw - 0.6, G - 0.4, -0.5, hw + 0.6, 0, D + 0.6, s.trim)
	boxIn(m, door, "WallLeft", -hw, 0, 0, -3.6, R, 1.2, s.wall)
	boxIn(m, door, "WallRight", 3.6, 0, 0, hw, R, 1.2, s.wall)
	boxIn(m, door, "WallOverDoor", -3.6, 11, 0, 3.6, R, 1.2, s.wall)
	boxIn(m, door, "BodyLeft", -hw, 0, 1.2, -5.6, R, D, s.wall)
	boxIn(m, door, "BodyRight", 5.6, 0, 1.2, hw, R, D, s.wall)
	boxIn(m, door, "BodyBack", -5.6, 0, 11, 5.6, R, D, s.wall)
	boxIn(m, door, "BodyTop", -5.6, 12.4, 1.2, 5.6, R, 11, s.wall)
	-- The hall behind the door: cream walls, a chequered floor, a chandelier and a portrait.
	local cream = look(rgb(232, 218, 190), Enum.Material.Plaster)
	boxIn(m, door, "HallFloor", -5.6, -0.2, 1.2, 5.6, 0.02, 11, look(rgb(232, 228, 220), Enum.Material.Marble, 0.05))
	for i = 0, 3 do
		for j = 0, 3 do
			if (i + j) % 2 == 0 then
				boxIn(m, door, "Chequer", -5.6 + i * 2.8, 0.02, 1.2 + j * 2.45, -5.6 + (i + 1) * 2.8, 0.05, 1.2 + (j + 1) * 2.45, look(rgb(20, 20, 24), Enum.Material.Marble, 0.05), TRIM_OPTS)
			end
		end
	end
	boxIn(m, door, "HallWall", -5.6, 0, 1.2, -5.4, 12.4, 11, cream, TRIM_OPTS)
	boxIn(m, door, "HallWall", 5.4, 0, 1.2, 5.6, 12.4, 11, cream, TRIM_OPTS)
	boxIn(m, door, "HallWall", -5.6, 0, 10.8, 5.6, 12.4, 11, cream, TRIM_OPTS)
	boxIn(m, door, "HallCeiling", -5.6, 12.2, 1.2, 5.6, 12.4, 11, cream, TRIM_OPTS)
	boxIn(m, door, "Portrait", -2.2, 4.6, 10.6, 2.2, 9.4, 10.8, L.brass, TRIM_OPTS)
	boxIn(m, door, "Canvas", -1.8, 5, 10.5, 1.8, 9, 10.62, look(s.wash:Lerp(rgb(30, 20, 30), 0.55), Enum.Material.SmoothPlastic), TRIM_OPTS)
	local chandelier = Kit.part(m, "Chandelier", Vector3.new(1.6, 1.6, 1.6), door * CFrame.new(0, 10.4, 6), L.brass, { shape = Enum.PartType.Ball, collide = false, query = false })
	Kit.pointLight(chandelier, 2.2, 18, rgb(255, 204, 150))
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		Kit.part(m, "Crystal", Vector3.new(0.4, 0.7, 0.4), door * CFrame.new(math.cos(a) * 1.1, 9.8, 6 + math.sin(a) * 1.1), look(rgb(255, 240, 220), Enum.Material.Glass, 0.2, 0.2), TRIM_OPTS)
	end
	-- The great door: two leaves (each a model of its own, for the screens to swing open), in its
	-- surround of pilasters, a cornice and a lit fanlight.
	local leaves: { Model } = {}
	for _, side in { -1, 1 } do
		local leaf = Kit.model(m, if side < 0 then "DoorL" else "DoorR")
		local x0 = if side < 0 then -3.6 else 0
		local x1 = if side < 0 then 0 else 3.6
		local panel = boxIn(leaf, door, "Leaf", x0, 0, 0.4, x1, 11, 0.8, look(s.door, Enum.Material.Wood, 0.08))
		leaf.PrimaryPart = panel
		for _, y in { 2.4, 7.4 } do
			boxIn(leaf, door, "Moulding", x0 + 0.5, y - 1.8, 0.28, x1 - 0.5, y + 1.8, 0.4, look(s.door:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Wood), TRIM_OPTS)
		end
		local knob = (if side < 0 then x1 - 0.5 else x0 + 0.5)
		Kit.part(leaf, "Knob", Vector3.new(0.35, 0.35, 0.35), door * CFrame.new(knob, 5.4, 0.2), L.brass, { shape = Enum.PartType.Ball, collide = false, query = false })
		leaf:SetAttribute("Hinge", (door * CFrame.new(side * 3.6, 0, 0.6)).Position)
		leaf:SetAttribute("Side", side)
		table.insert(leaves, leaf)
	end
	boxIn(m, door, "Pilaster", -4.6, 0, -0.5, -3.6, 12.6, 0.2, s.trim, TRIM_OPTS)
	boxIn(m, door, "Pilaster", 3.6, 0, -0.5, 4.6, 12.6, 0.2, s.trim, TRIM_OPTS)
	boxIn(m, door, "DoorCornice", -5.2, 12.6, -0.9, 5.2, 13.4, 0.2, s.trim, TRIM_OPTS)
	local fan = boxIn(m, door, "Fanlight", -3.4, 11.15, 0.1, 3.4, 12.35, 0.3, look(rgb(255, 196, 120), Enum.Material.Neon, 0, 0.2), TRIM_OPTS)
	fan.CastShadow = false
	for k = -2, 2 do
		boxIn(m, door, "FanBar", k * 1.3 - 0.06, 11.15, 0.0, k * 1.3 + 0.06, 12.35, 0.12, L.blackLacquer, TRIM_OPTS)
	end
	-- Storey bands and the corners.
	for k = 1, storeys - 1 do
		boxIn(m, door, "Band", -hw - 0.4, k * SH - 0.35, -0.55, hw + 0.4, k * SH + 0.35, 0.1, s.trim, TRIM_OPTS)
	end
	boxIn(m, door, "Corner", -hw - 0.3, 0, -0.35, -hw + 1.3, R, 0.2, s.trim, TRIM_OPTS)
	boxIn(m, door, "Corner", hw - 1.3, 0, -0.35, hw + 0.3, R, 0.2, s.trim, TRIM_OPTS)
	-- Windows: across every storey, round the portico on the ground floor; most lit, a few dark.
	local usable = W - 10
	local n = math.clamp(math.floor(usable / 7) + 1, 3, 9)
	for storey = 0, storeys - 1 do
		local h = if storey == 0 then 7.4 else 6.6
		local y = storey * SH + SH * 0.5
		for k = 0, n - 1 do
			local x = -usable / 2 + k * usable / (n - 1)
			if storey == 0 and math.abs(x) < 11.5 then
				continue
			end
			if storey > 0 and math.abs(x) < 2.2 and n % 2 == 1 and storey == 1 then
				-- (The middle window over the portico is a balcony door: taller.)
				window(m, door, x, y + 0.4, 3.4, 8, s, true, s.glow)
				continue
			end
			local lit = rng:NextNumber() > 0.18
			local colour = if rng:NextNumber() < 0.3 then s.wash else s.glow
			window(m, door, x, y, 3.4, h, s, lit, colour)
		end
	end
	-- The roof.
	boxIn(m, door, "Cornice", -hw - 1, R, -1, hw + 1, R + 1.2, D + 1, s.trim)
	local top = R + 1.2
	local function slopeWedge(name: string, size: Vector3, cf: CFrame)
		local w = Instance.new("WedgePart")
		w.Name = name
		w.Anchored = true
		w.Size = size
		w.CFrame = cf
		w.Color = s.slate.color
		w.Material = s.slate.material
		w.Parent = m
	end
	local mansard = s.roof == "mansard" or s.roof == "turret"
	if mansard then
		-- Steep slopes all round (a wedge is tall at its back: each turned to rise inward), a flat
		-- top, dormers in the front slope and an iron crest along the top.
		local rise, run = 8, 3.6
		slopeWedge("Slope", Vector3.new(W + 1.6, rise, run), door * CFrame.new(0, top + rise / 2, -0.8 + run / 2))
		slopeWedge("Slope", Vector3.new(W + 1.6, rise, run), door * CFrame.new(0, top + rise / 2, D + 0.8 - run / 2) * CFrame.Angles(0, math.pi, 0))
		slopeWedge("Slope", Vector3.new(D + 1.6, rise, run), door * CFrame.new(-hw - 0.8 + run / 2, top + rise / 2, D / 2) * CFrame.Angles(0, math.pi / 2, 0))
		slopeWedge("Slope", Vector3.new(D + 1.6, rise, run), door * CFrame.new(hw + 0.8 - run / 2, top + rise / 2, D / 2) * CFrame.Angles(0, -math.pi / 2, 0))
		boxIn(m, door, "RoofTop", -hw - 0.8 + run, top, -0.8 + run, hw + 0.8 - run, top + rise, D + 0.8 - run, s.slate)
		for k = 0, n - 1, 2 do
			local x = -usable / 2 + k * usable / (n - 1)
			boxIn(m, door, "Dormer", x - 1.6, top + 0.6, 0.6, x + 1.6, top + 5.2, 3.4, s.trim)
			boxIn(m, door, "DormerWindow", x - 1.05, top + 1.2, 0.45, x + 1.05, top + 4.3, 0.62, look(s.glow, Enum.Material.Neon, 0, 0.25), TRIM_OPTS)
			triangle(m, door, "DormerGable", x - 1.9, x + 1.9, top + 5.2, 1.6, 0.4, 3.4, s.slate)
		end
		boxIn(m, door, "Crest", -hw - 0.8 + run, top + rise, -0.8 + run - 0.1, hw + 0.8 - run, top + rise + 0.25, -0.8 + run + 0.1, L.blackLacquer, TRIM_OPTS)
		for x = -hw + run, hw - run, 2.4 do
			Kit.part(m, "Finial", Vector3.new(0.18, 1.1, 0.18), door * CFrame.new(x, top + rise + 0.8, -0.8 + run), L.blackLacquer, TRIM_OPTS)
		end
	elseif s.roof == "gable" then
		-- A pitched roof with its gable to the street, a round window in it, barge boards.
		local rise = 10
		slopeWedge("Slope", Vector3.new(D + 2, rise, hw + 1), door * CFrame.new(-(hw + 1) / 2, top + rise / 2, D / 2) * CFrame.Angles(0, math.pi / 2, 0))
		slopeWedge("Slope", Vector3.new(D + 2, rise, hw + 1), door * CFrame.new((hw + 1) / 2, top + rise / 2, D / 2) * CFrame.Angles(0, -math.pi / 2, 0))
		triangle(m, door, "Gable", -hw, hw, top, rise - 0.6, 0.2, 1, s.wall)
		local oculus = Kit.part(m, "Oculus", Vector3.new(0.3, 3.4, 3.4), door * CFrame.new(0, top + rise * 0.36, 0.05) * CFrame.Angles(0, math.pi / 2, 0), look(s.glow, Enum.Material.Neon, 0, 0.2), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
		oculus.CastShadow = false
		Kit.part(m, "OculusRing", Vector3.new(0.25, 4.2, 4.2), door * CFrame.new(0, top + rise * 0.36, 0.15) * CFrame.Angles(0, math.pi / 2, 0), s.trim, { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
		local slope = math.atan2(rise, hw + 1)
		for _, sx in { -1, 1 } do
			local mid = door * CFrame.new(sx * (hw + 1) / 2, top + rise / 2, -0.3)
			Kit.part(m, "Barge", Vector3.new(math.sqrt((hw + 1) ^ 2 + rise ^ 2), 0.7, 0.5), mid * CFrame.Angles(0, 0, -sx * slope), s.trim, TRIM_OPTS)
		end
	else
		-- A flat roof behind a balustrade, urns at the corners (with a pumpkin on each).
		boxIn(m, door, "RoofTop", -hw, R, 0, hw, top + 0.2, D, s.slate)
		boxIn(m, door, "Parapet", -hw - 0.7, top, -0.9, hw + 0.7, top + 0.5, 0.4, s.trim, TRIM_OPTS)
		boxIn(m, door, "Rail", -hw - 0.7, top + 2.6, -0.9, hw + 0.7, top + 3.1, 0.4, s.trim, TRIM_OPTS)
		for x = -hw, hw, 1.4 do
			Kit.part(m, "Baluster", Vector3.new(2.1, 0.55, 0.55), door * CFrame.new(x, top + 1.55, -0.25) * CFrame.Angles(0, 0, math.pi / 2), s.trim, { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
		end
		for _, sx in { -1, 1 } do
			local urn = (door * CFrame.new(sx * hw, top + 3.1, -0.25)).Position
			Kit.part(m, "Urn", Vector3.new(1.6, 1.4, 1.6), CFrame.new(urn + Vector3.new(0, 0.7, 0)), s.trim, TRIM_OPTS)
			HolidayProps.pumpkin(m, urn + Vector3.new(0, 1.4, 0), 2.2, door.LookVector, true, false)
		end
	end
	if s.roof == "turret" then
		-- A round tower at the front corner, rising past the roof to a slate cone and a gold finial.
		local corner = (door * CFrame.new(-hw + 2.5, 0, 2)).Position
		local towerTop = R + 14
		Kit.part(m, "Turret", Vector3.new(towerTop - G, 11, 11), CFrame.new(corner + Vector3.new(0, (G + towerTop) / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), s.wall, { shape = Enum.PartType.Cylinder })
		Kit.part(m, "TurretBand", Vector3.new(1, 11.8, 11.8), CFrame.new(corner + Vector3.new(0, towerTop, 0)) * CFrame.Angles(0, 0, math.pi / 2), s.trim, { shape = Enum.PartType.Cylinder, collide = false })
		for storey = 0, storeys do
			local y = storey * SH + SH * 0.5
			local face = CFrame.lookAt(corner + Vector3.new(0, y, 0), corner + Vector3.new(0, y, 0) + door.LookVector)
			Kit.part(m, "TurretWindow", Vector3.new(2, 5.4, 0.3), face * CFrame.new(0, 0, -5.45), look(s.glow, Enum.Material.Neon, 0, 0.2), TRIM_OPTS)
		end
		cone(m, "TurretRoof", corner + Vector3.new(0, towerTop + 0.4, 0), 12.4, 12, 8, s.slate)
		Kit.part(m, "Finial", Vector3.new(0.9, 0.9, 0.9), CFrame.new(corner + Vector3.new(0, towerTop + 12.8, 0)), L.brass, { shape = Enum.PartType.Ball, collide = false })
		Kit.part(m, "Spire", Vector3.new(0.2, 2.6, 0.2), CFrame.new(corner + Vector3.new(0, towerTop + 14.4, 0)), L.brass, TRIM_OPTS)
	end
	-- Chimneys.
	for _, sx in { -1, 1 } do
		local x = sx * (hw - 5)
		local chimneyTop = top + (if s.roof == "gable" then 9 else 11)
		boxIn(m, door, "Chimney", x - 1.6, top - 1, D * 0.55 - 1.6, x + 1.6, chimneyTop, D * 0.55 + 1.6, look(rgb(90, 50, 40), Enum.Material.Brick))
		boxIn(m, door, "ChimneyCap", x - 1.9, chimneyTop, D * 0.55 - 1.9, x + 1.9, chimneyTop + 0.5, D * 0.55 + 1.9, s.trim, TRIM_OPTS)
		for _, dx in { -0.7, 0.7 } do
			Kit.part(m, "Pot", Vector3.new(1.4, 0.8, 0.8), door * CFrame.new(x + dx, chimneyTop + 1.2, D * 0.55) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(150, 80, 50), Enum.Material.Concrete), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
		end
	end
	-- The portico: a porch on four columns, an entablature and a pediment, and steps down.
	boxIn(m, door, "Porch", -10, G, -8, 10, -0.2, 0, s.trim)
	boxIn(m, door, "PorchFloor", -10, -0.2, -8, 10, 0, 0, look(rgb(226, 222, 212), Enum.Material.Marble, 0.05))
	for _, x in { -9, -6.5, 6.5, 9 } do
		local base = (door * CFrame.new(x, 0, -7.2)).Position
		Kit.part(m, "ColumnBase", Vector3.new(1.9, 0.6, 1.9), CFrame.new(base + Vector3.new(0, 0.3, 0)) * door.Rotation, s.trim)
		Kit.post(m, "Column", 11.6, 1.3, base + Vector3.new(0, 0.6, 0), s.trim)
		Kit.part(m, "Capital", Vector3.new(2.1, 0.7, 2.1), CFrame.new(base + Vector3.new(0, 12.55, 0)) * door.Rotation, s.trim)
	end
	boxIn(m, door, "Entablature", -10.4, 12.9, -8.4, 10.4, 14.4, 0, s.trim)
	triangle(m, door, "Pediment", -10.4, 10.4, 14.4, 4, -8.4, -7.6, s.trim)
	for k = 1, 3 do
		boxIn(m, door, "Step", -5.5, G, -8 - k * 1.2, 5.5, -k * 0.66, -8 - (k - 1) * 1.2, s.trim)
	end
	-- Lanterns either side of the door, and the house's number.
	for _, sx in { -1, 1 } do
		local glass = Kit.part(m, "Lantern", Vector3.new(0.9, 1.5, 0.9), door * CFrame.new(sx * 5.4, 8.6, -0.7), L.glassWarm, TRIM_OPTS)
		Kit.part(m, "LanternCap", Vector3.new(1.1, 0.3, 1.1), door * CFrame.new(sx * 5.4, 9.5, -0.7), L.blackLacquer, TRIM_OPTS)
		Kit.pointLight(glass, 1.3, 15, rgb(255, 180, 110))
	end
	local plaque = boxIn(m, door, "Plaque", 4.9, 5.4, -0.62, 6.5, 6.6, -0.5, L.brass, TRIM_OPTS)
	Kit.engrave(plaque, Enum.NormalId.Back, { { text = if index == 9 then "M" else tostring(index), size = 0.8, font = Brand.Fonts.display, color = rgb(40, 30, 12) } }, { ppu = 90, brightness = 1 })
	-- Light washing up the front (violet or orange), from the garden.
	for _, sx in { -1, 1 } do
		local cup = boxIn(m, door, "Uplight", sx * hw * 0.62 - 0.5, G, -6.5, sx * hw * 0.62 + 0.5, G + 0.5, -5.5, L.blackLacquer, TRIM_OPTS)
		Kit.spotLight(cup, Enum.NormalId.Top, 3, 46, 64, s.wash, false)
	end
	-- The garden: a path, topiary, the jack-o'-lanterns on the steps.
	boxIn(m, door, "Path", -3.2, G - 0.3, -20, 3.2, G + 0.04, -11.6, look(rgb(120, 116, 110), Enum.Material.Cobblestone))
	for _, sx in { -1, 1 } do
		local foot = (door * CFrame.new(sx * 7, G, -15)).Position
		Kit.part(m, "Pot", Vector3.new(2, 1.6, 2), CFrame.new(foot + Vector3.new(0, 0.8, 0)) * door.Rotation, look(rgb(60, 58, 56), Enum.Material.Concrete))
		Kit.post(m, "TopiaryTrunk", 1.6, 0.35, foot + Vector3.new(0, 1.6, 0), L.darkWood, TRIM_OPTS)
		Kit.part(m, "Topiary", Vector3.new(3.4, 3.4, 3.4), CFrame.new(foot + Vector3.new(0, 4.4, 0)), look(rgb(28, 54, 34), Enum.Material.Grass), { shape = Enum.PartType.Ball, collide = false })
		HolidayProps.pumpkin(m, (door * CFrame.new(sx * 7.6, G, -10.2)).Position, 2.6, door.LookVector, true, sx > 0)
		HolidayProps.pumpkin(m, (door * CFrame.new(sx * 6.6, G, -12.6)).Position, 1.7, door.LookVector, rng:NextNumber() < 0.5, false)
		HolidayProps.pumpkin(m, (door * CFrame.new(sx * 8.2, 0, -1.6)).Position, 2, door.LookVector, true, false)
	end
	return m, leaves[1], leaves[2]
end

---------------------------------------------------------------------------------------------------
-- The hosts, in costume
---------------------------------------------------------------------------------------------------
local GOLD = Dress.GOLD

local function costume(rig: Model, host: Host)
	local head = rig:FindFirstChild("Head") :: BasePart?
	local upper = (rig:FindFirstChild("UpperTorso") or rig:FindFirstChild("Body")) :: BasePart?
	if not head or not head:IsA("BasePart") then
		return
	end
	local hs = head.Size.Y
	local kind = host.costume
	if kind == "masquerade" then
		Dress.mask(head, GOLD, 3)
		Dress.tiara(head)
		Dress.skirt(rig, rgb(18, 12, 22), GOLD, 1.5)
	elseif kind == "count" then
		if upper and upper:IsA("BasePart") then
			Dress.cape(upper, rgb(14, 12, 16), rgb(150, 16, 30), true)
			Dress.attach(upper, "Medallion", Vector3.new(0.08, upper.Size.X * 0.24, upper.Size.X * 0.24), CFrame.new(0, upper.Size.Y * 0.2, -upper.Size.Z * 0.5 - 0.05) * CFrame.Angles(0, math.pi / 2, 0), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	elseif kind == "witch" then
		Dress.pointedHat(head, rgb(60, 26, 90), GOLD, 1.7, 2.6)
		Dress.skirt(rig, rgb(60, 26, 90), rgb(30, 14, 46), 1.1)
		if upper and upper:IsA("BasePart") then
			-- Her broom, held upright at her side.
			local broom = Dress.attach(upper, "Broom", Vector3.new(5.4, 0.18, 0.18), CFrame.new(upper.Size.X * 0.9, -0.6, -0.3) * CFrame.Angles(0, 0, math.pi / 2), rgb(110, 70, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
			Dress.attach(broom, "Bristles", Vector3.new(1.2, 0.8, 0.8), CFrame.new(-3, 0, 0), rgb(200, 160, 90), Enum.Material.Fabric, nil, true)
		end
	elseif kind == "pumpkin" then
		head.Transparency = 1
		local face = head:FindFirstChildOfClass("Decal")
		if face then
			face:Destroy()
		end
		local base = head.CFrame.Position - Vector3.new(0, hs * 0.75, 0)
		local p = HolidayProps.pumpkin(rig, base, hs * 1.9, head.CFrame.LookVector, true, true)
		for _, d in p:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = head
				w.Part1 = d
				w.Parent = d
			end
		end
		Dress.topHat(head, CFrame.new(0, hs * 0.75, 0))
	elseif kind == "cat" then
		for _, sx in { -1, 1 } do
			local ear = Dress.attach(head, "Ear", Vector3.new(hs * 0.12, hs * 0.42, hs * 0.36), CFrame.new(sx * hs * 0.3, hs * 0.62, 0) * CFrame.Angles(0, 0, sx * math.rad(-14)), rgb(14, 14, 16), Enum.Material.Fabric)
			Dress.attach(ear, "EarInner", Vector3.new(hs * 0.04, hs * 0.26, hs * 0.2), CFrame.new(0, -hs * 0.04, -hs * 0.08), rgb(240, 150, 180), Enum.Material.Fabric)
			for k = -1, 1 do
				Dress.attach(head, "Whisker", Vector3.new(hs * 0.42, 0.03, 0.03), CFrame.new(sx * hs * 0.42, -hs * 0.06 + k * hs * 0.07, -hs * 0.5) * CFrame.Angles(0, 0, k * sx * 0.18), WHITE, Enum.Material.SmoothPlastic)
			end
		end
		Dress.attach(head, "Nose", Vector3.new(hs * 0.12, hs * 0.08, 0.05), CFrame.new(0, -hs * 0.02, -hs * 0.56), rgb(240, 120, 160), Enum.Material.SmoothPlastic, nil, true)
		if upper and upper:IsA("BasePart") then
			Dress.attach(upper, "Bow", Vector3.new(upper.Size.X * 0.5, upper.Size.Y * 0.22, 0.1), CFrame.new(0, upper.Size.Y * 0.42, -upper.Size.Z * 0.5 - 0.05), rgb(240, 120, 170), Enum.Material.Fabric, nil, true)
		end
		local lower = rig:FindFirstChild("LowerTorso")
		if lower and lower:IsA("BasePart") then
			local tail = Dress.attach(lower, "Tail", Vector3.new(0.22, 0.22, lower.Size.Y * 2.6), CFrame.new(0, 0, lower.Size.Z * 0.5 + lower.Size.Y * 1.2) * CFrame.Angles(math.rad(-25), 0, 0), rgb(14, 14, 16), Enum.Material.Fabric, nil, true)
			Dress.attach(tail, "TailTip", Vector3.new(0.24, 0.24, lower.Size.Y * 1.4), CFrame.new(0, lower.Size.Y * 0.55, lower.Size.Y * 1.4) * CFrame.Angles(math.rad(-55), 0, 0), rgb(14, 14, 16), Enum.Material.Fabric, nil, true)
		end
	elseif kind == "wizard" then
		Dress.pointedHat(head, rgb(30, 40, 110), GOLD, 2.2, 2.2)
		for k = 1, 5 do
			local a = k * 1.3
			Dress.attach(head, "Star", Vector3.new(hs * 0.14, hs * 0.14, hs * 0.14), CFrame.new(math.cos(a) * hs * 0.4, hs * (0.8 + k * 0.22), math.sin(a) * hs * 0.4), rgb(255, 220, 110), Enum.Material.Neon, Enum.PartType.Ball)
		end
		Dress.attach(head, "Beard", Vector3.new(hs * 0.9, hs * 1.2, hs * 0.5), CFrame.new(0, -hs * 0.62, -hs * 0.32), rgb(236, 236, 240), Enum.Material.Fabric, nil, true)
		Dress.skirt(rig, rgb(30, 40, 110), GOLD, 0.7)
		if upper and upper:IsA("BasePart") then
			local staff = Dress.attach(upper, "Staff", Vector3.new(6.2, 0.22, 0.22), CFrame.new(-upper.Size.X * 0.95, -0.4, -0.4) * CFrame.Angles(0, 0, math.pi / 2), rgb(90, 60, 40), Enum.Material.Wood, Enum.PartType.Cylinder)
			local orb = Dress.attach(staff, "Orb", Vector3.new(0.7, 0.7, 0.7), CFrame.new(3.3, 0, 0), rgb(120, 200, 255), Enum.Material.Neon, Enum.PartType.Ball)
			local l = Instance.new("PointLight")
			l.Color = rgb(120, 200, 255)
			l.Brightness = 1.6
			l.Range = 10
			l.Parent = orb
		end
	elseif kind == "ghost" then
		if upper and upper:IsA("BasePart") then
			-- A sheet over everything, two black eyes, and a bow tie: a very polite ghost.
			local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = rig:FindFirstChildOfClass("Humanoid")
			local tall = if root and humanoid then humanoid.HipHeight + root.Size.Y / 2 + upper.Size.Y + hs * 1.2 else 5
			local sheet = Dress.attach(upper, "Sheet", Vector3.new(upper.Size.X * 2, tall * 1.15, upper.Size.Z * 2.4), CFrame.new(0, hs * 0.55 - tall * 0.35, 0), rgb(246, 246, 250), Enum.Material.Fabric, nil, true)
			for _, sx in { -1, 1 } do
				Dress.attach(sheet, "GhostEye", Vector3.new(hs * 0.3, hs * 0.42, 0.06), CFrame.new(sx * hs * 0.26, tall * 0.32, -upper.Size.Z * 1.18), rgb(16, 16, 20), Enum.Material.SmoothPlastic, nil, true)
				Dress.attach(sheet, "BowTie", Vector3.new(hs * 0.3, hs * 0.24, 0.1), CFrame.new(sx * hs * 0.16, tall * 0.08, -upper.Size.Z * 1.2) * CFrame.Angles(0, 0, sx * 0.3), rgb(20, 20, 24), Enum.Material.Fabric)
			end
			for _, d in rig:GetDescendants() do
				if d:IsA("BasePart") and d.Parent == rig and d.Name ~= "HumanoidRootPart" then
					d.Transparency = 1
				elseif d:IsA("Decal") then
					d.Transparency = 1
				end
			end
		end
	elseif kind == "fairy" then
		Dress.tiara(head)
		Dress.skirt(rig, rgb(150, 190, 240), rgb(240, 240, 255), 1.2)
		if upper and upper:IsA("BasePart") then
			for _, sx in { -1, 1 } do
				local wing = Dress.attach(upper, "Wing", Vector3.new(0.08, upper.Size.Y * 2.1, upper.Size.Y * 1.4), CFrame.new(sx * upper.Size.X * 0.55, upper.Size.Y * 0.35, upper.Size.Z * 0.6) * CFrame.Angles(0, sx * math.rad(-35), sx * math.rad(-20)), rgb(190, 230, 255), Enum.Material.Glass, nil, true)
				wing.Transparency = 0.35
				Dress.attach(upper, "Wing", Vector3.new(0.08, upper.Size.Y * 1.2, upper.Size.Y * 0.9), CFrame.new(sx * upper.Size.X * 0.5, -upper.Size.Y * 0.35, upper.Size.Z * 0.6) * CFrame.Angles(0, sx * math.rad(-35), sx * math.rad(-60)), rgb(250, 200, 240), Enum.Material.Glass, nil, true).Transparency = 0.35
			end
			HolidayProps.sparkle(upper, rgb(200, 230, 255), 6, 0.3)
			local wand = Dress.attach(upper, "Wand", Vector3.new(1.8, 0.1, 0.1), CFrame.new(upper.Size.X * 0.85, -0.2, -0.6) * CFrame.Angles(0, math.rad(-20), math.rad(60)), WHITE, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
			local star = Dress.attach(wand, "WandStar", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0.95, 0, 0), rgb(255, 230, 120), Enum.Material.Neon, Enum.PartType.Ball)
			local l = Instance.new("PointLight")
			l.Color = rgb(255, 230, 160)
			l.Brightness = 1.4
			l.Range = 8
			l.Parent = star
		end
	elseif kind == "hostess" then
		Dress.mask(head, GOLD, 5)
		Dress.tiara(head)
		Dress.skirt(rig, rgb(14, 12, 16), GOLD, 1.9)
		if upper and upper:IsA("BasePart") then
			Dress.attach(upper, "Stole", Vector3.new(upper.Size.X * 1.5, upper.Size.Y * 0.5, upper.Size.Z * 1.5), CFrame.new(0, upper.Size.Y * 0.38, 0), rgb(240, 236, 228), Enum.Material.Fabric, nil, true)
			local bowl = Dress.attach(upper, "Bowl", Vector3.new(0.4, upper.Size.X * 0.95, upper.Size.X * 0.95), CFrame.new(0, -upper.Size.Y * 0.25, -upper.Size.Z * 0.5 - 0.7) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
			for k = 1, 4 do
				local a = k * 1.6
				Dress.attach(bowl, "Truffle", Vector3.new(0.34, 0.34, 0.34), CFrame.new(0.25, math.cos(a) * 0.3, math.sin(a) * 0.3), rgb(70, 40, 26), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
			end
		end
	end
end

local function host(m: Model, door: CFrame, i: number): Model?
	local def = Lane.Hosts[i]
	local spec: Rig.LookSpec = {
		shirt = 0,
		pants = 0,
		accessories = "",
		skin = def.skin,
		coat = def.coat,
		gloves = if def.costume == "ghost" then WHITE else rgb(240, 238, 232),
		heightScale = 1,
		lapelKey = false,
		tails = def.costume == "count",
	}
	local ok, staff = pcall(Rig.build, "Host" .. i, spec, door * CFrame.new(0, 0, 4.6), m)
	if not ok or not staff then
		return nil
	end
	staff.root.Anchored = true
	staff.model:SetAttribute("Host", def.name)
	pcall(costume, staff.model, def)
	return staff.model
end

---------------------------------------------------------------------------------------------------
-- The Lane itself
---------------------------------------------------------------------------------------------------

-- A gas lamp on the pavement: a black post, a lantern with its flame, a warm light.
local function gasLamp(parent: Instance, base: Vector3)
	local m = Kit.model(parent, "GasLamp")
	Kit.post(m, "Base", 1.4, 1.2, base, L.blackLacquer)
	Kit.post(m, "Post", 11, 0.42, base + Vector3.new(0, 1.4, 0), L.blackLacquer)
	Kit.part(m, "Crossbar", Vector3.new(2.2, 0.16, 0.16), CFrame.new(base + Vector3.new(0, 11.4, 0)), L.blackLacquer, TRIM_OPTS)
	local glass = Kit.part(m, "Lantern", Vector3.new(1.4, 2, 1.4), CFrame.new(base + Vector3.new(0, 13.4, 0)), L.glassWarm, TRIM_OPTS)
	Kit.part(m, "Cap", Vector3.new(1.8, 0.4, 1.8), CFrame.new(base + Vector3.new(0, 14.6, 0)), L.blackLacquer, TRIM_OPTS)
	Kit.part(m, "Flame", Vector3.new(0.4, 0.8, 0.4), CFrame.new(base + Vector3.new(0, 13.3, 0)), look(rgb(255, 170, 80), Enum.Material.Neon), TRIM_OPTS)
	Kit.pointLight(glass, 1.8, 32, rgb(255, 170, 96))
	m:SetAttribute("Flicker", true)
end

-- A tree beyond the houses, dark against the sky (a trunk and two rounds of leaves).
local function darkTree(parent: Instance, base: Vector3, height: number, rng: Random)
	Kit.post(parent, "Trunk", height * 0.45, height * 0.07, base, look(rgb(36, 28, 26), Enum.Material.Wood), { shadow = false })
	local hue = if rng:NextNumber() < 0.5 then rgb(38, 30, 40) else rgb(30, 40, 34)
	Kit.part(parent, "Crown", Vector3.new(height * 0.6, height * 0.6, height * 0.6), CFrame.new(base + Vector3.new(0, height * 0.62, 0)), look(hue, Enum.Material.Grass), { shape = Enum.PartType.Ball, collide = false, shadow = false })
	Kit.part(parent, "Crown", Vector3.new(height * 0.42, height * 0.42, height * 0.42), CFrame.new(base + Vector3.new(rng:NextNumber(-2, 2), height * 0.9, rng:NextNumber(-2, 2))), look(hue:Lerp(rgb(60, 40, 70), 0.2), Enum.Material.Grass), { shape = Enum.PartType.Ball, collide = false, shadow = false })
end

local function build(ctx: Types.Ctx): Model
	local O = HolidayGames.origin("lane")
	local LG = HolidayGames.Lane
	local rng = Random.new(1031)
	local root = Instance.new("Model")
	root.Name = "HallowsLane"
	root:SetAttribute("Area", "lane")
	local function at(x: number, y: number, z: number): Vector3
		return O + Vector3.new(x, y, z)
	end
	local function span(name: string, a: Vector3, b: Vector3, lk: Look, opts: { [string]: any }?): Part
		return Kit.span(root, name, O + a, O + b, lk, opts)
	end
	local west, east = -LG.half - 4, LG.minuitX + 46
	local back = 84
	-- The ground: the cobbled road, kerbs, the pavements, the gardens and the forecourt before
	-- Maison Minuit.
	span("Road", Vector3.new(west, -2, -LG.road), Vector3.new(LG.minuitX - 30, 0, LG.road), look(rgb(54, 50, 50), Enum.Material.Cobblestone))
	for _, sz in { 1, -1 } do
		span("Kerb", Vector3.new(west, -2, sz * LG.road), Vector3.new(LG.minuitX - 30, 0.35, sz * (LG.road + 0.8)), L.kerb)
		span("Pavement", Vector3.new(west, -2, sz * (LG.road + 0.8)), Vector3.new(LG.minuitX - 14, 0.35, sz * LG.pavement), L.wetStone)
		span("Garden", Vector3.new(west, -2, sz * LG.pavement), Vector3.new(east, 0.35, sz * back), look(rgb(30, 44, 30), Enum.Material.LeafyGrass))
	end
	span("Forecourt", Vector3.new(LG.minuitX - 30, -2, -LG.pavement), Vector3.new(LG.minuitX - 14, 0.35, LG.pavement), L.wetStone)
	span("Lawn", Vector3.new(LG.minuitX - 14, -2, -LG.pavement), Vector3.new(east, 0.35, LG.pavement), look(rgb(30, 44, 30), Enum.Material.LeafyGrass))
	-- Puddles on the cobbles catch the lamps.
	for _ = 1, 10 do
		local x = rng:NextNumber(west + 20, LG.minuitX - 40)
		Kit.part(root, "Puddle", Vector3.new(rng:NextNumber(4, 8), 0.03, rng:NextNumber(2, 3)), CFrame.new(at(x, 0.02, rng:NextNumber(-8, 8))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), L.puddle, TRIM_OPTS)
	end
	-- The houses: eight down the sides, Maison Minuit at the end; a host behind every door.
	doors = {}
	local doorFrames = HolidayGames.laneDoors()
	for i, cf in doorFrames do
		local s = STYLES[i]
		local house = mansion(root, cf, s, i, rng)
		house:SetAttribute("Door", i)
		house:SetAttribute("HouseName", s.name)
		house:SetAttribute("Treat", Lane.Hosts[i].treat)
		-- Its gate in the railings, and the knock.
		local knocker = Kit.part(house, "Knock", Vector3.new(7, 11, 1), cf * CFrame.new(0, 5.5, -0.6), look(WHITE, Enum.Material.SmoothPlastic, 0, 1), { collide = false, shadow = false })
		knocker.CanQuery = true
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TrickOrTreat"
		prompt.ActionText = "Trick or treat!"
		prompt.ObjectText = s.name
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = math.min(14, ctx.cfg().lane.reach)
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt:SetAttribute("Offset", 0)
		prompt.Parent = knocker
		local index = i
		prompt.Triggered:Connect(function(player: Player)
			Lane.knock(ctx, player, index)
		end)
		table.insert(doors, { cf = cf, house = house, host = nil, prompt = prompt })
	end
	-- Railings along the pavements, with gate piers (a jack-o'-lantern on each) at every path.
	for _, sz in { 1, -1 } do
		local gaps = {}
		for _, x in LG.houseXs do
			table.insert(gaps, x)
		end
		local x = west + 2
		while x < LG.minuitX - 16 do
			local nearGate = false
			for _, gx in gaps do
				if math.abs(x - gx) < 4.2 then
					nearGate = true
				end
			end
			if not nearGate then
				Kit.part(root, "Railing", Vector3.new(0.14, 4, 0.14), CFrame.new(at(x, 2.35, sz * (LG.pavement - 0.2))), L.blackLacquer, TRIM_OPTS)
				if math.floor(x / 2.4 + 0.5) % 2 == 0 then
					Kit.part(root, "Spear", Vector3.new(0.3, 0.3, 0.3), CFrame.new(at(x, 4.5, sz * (LG.pavement - 0.2))), L.brass, { shape = Enum.PartType.Ball, collide = false, query = false, shadow = false })
				end
			end
			x += 2.4
		end
		for _, gx in gaps do
			for _, side in { -1, 1 } do
				local pier = at(gx + side * 4.4, 0.35, sz * (LG.pavement - 0.2))
				Kit.part(root, "Pier", Vector3.new(1.8, 5.2, 1.8), CFrame.new(pier + Vector3.new(0, 2.6, 0)), look(rgb(120, 116, 108), Enum.Material.Limestone))
				HolidayProps.pumpkin(root, pier + Vector3.new(0, 5.2, 0), 1.9, Vector3.new(0, 0, -sz), true, false)
			end
		end
		-- The rails between the posts.
		local runs = { { west + 2, LG.houseXs[1] - 4.4 } }
		for k = 1, #LG.houseXs - 1 do
			table.insert(runs, { LG.houseXs[k] + 4.4, LG.houseXs[k + 1] - 4.4 })
		end
		table.insert(runs, { LG.houseXs[#LG.houseXs] + 4.4, LG.minuitX - 16 })
		for _, r in runs do
			for _, y in { 1.1, 3.9 } do
				span("Rail", Vector3.new(r[1], y + 0.35 - 0.08, sz * (LG.pavement - 0.28)), Vector3.new(r[2], y + 0.35 + 0.08, sz * (LG.pavement - 0.12)), L.blackLacquer, TRIM_OPTS)
			end
		end
		-- Lamps along each pavement, between the gates.
		for _, lx in { -150, -75, -5, 65, 135 } do
			gasLamp(root, at(lx, 0.35, sz * (LG.road + 3)))
		end
	end
	-- The gate at the Lane's start: two stone piers and an iron arch with the Lane's name.
	local gateX = LG.arrival.X + 12
	for _, sz in { 1, -1 } do
		local pier = at(gateX, 0, sz * (LG.road + 2.4))
		Kit.part(root, "GatePier", Vector3.new(3.4, 18, 3.4), CFrame.new(pier + Vector3.new(0, 9, 0)), look(rgb(70, 66, 64), Enum.Material.Limestone))
		Kit.part(root, "GatePierCap", Vector3.new(4.2, 1, 4.2), CFrame.new(pier + Vector3.new(0, 18.5, 0)), look(rgb(110, 104, 98), Enum.Material.Limestone))
		HolidayProps.pumpkin(root, pier + Vector3.new(0, 19, 0), 3, Vector3.new(1, 0, 0), true, true)
		local lantern = Kit.part(root, "GateLantern", Vector3.new(1.2, 1.8, 1.2), CFrame.new(pier + Vector3.new(1.9, 12, 0)), L.glassWarm, TRIM_OPTS)
		Kit.pointLight(lantern, 1.6, 22, rgb(255, 170, 96))
	end
	-- The arch: an iron curve across the road, and the board hung from it.
	local archR = LG.road + 2.4
	local segs = 14
	for k = 0, segs - 1 do
		local a0 = math.pi * k / segs
		local a1 = math.pi * (k + 1) / segs
		local p0 = at(gateX, 17 + math.sin(a0) * 6, math.cos(a0) * archR)
		local p1 = at(gateX, 17 + math.sin(a1) * 6, math.cos(a1) * archR)
		HolidayProps.rod(root, "Arch", p0, p1, 0.5, rgb(16, 16, 18), Enum.Material.Metal)
	end
	local board = Kit.part(root, "LaneSign", Vector3.new(0.4, 3.4, 18), CFrame.new(at(gateX, 19.2, 0)), L.blackLacquer, { collide = false })
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		Kit.engrave(board, face, {
			{ text = "HALLOWS LANE", size = 0.5, font = Brand.Fonts.display, color = rgb(255, 176, 90) },
			{ text = "Trick or treat at every door", size = 0.24, font = Brand.Fonts.displayItalic, color = rgb(214, 190, 250) },
		}, { ppu = 60, lit = false, brightness = 1.6, maxDistance = 220 })
	end
	-- The way home: a lit archway behind the gate, back to the Maison.
	local home = Kit.part(root, "WayHome", Vector3.new(1, 12, 10), CFrame.new(at(west + 6, 6.35, 0)), look(rgb(255, 214, 140), Enum.Material.Neon, 0, 0.55), { collide = false, shadow = false })
	home.CanQuery = true
	local homePrompt = Instance.new("ProximityPrompt")
	homePrompt.Name = "WayHome"
	homePrompt.ActionText = "Back to the Maison"
	homePrompt.ObjectText = "Hallows Lane"
	homePrompt.KeyboardKeyCode = Enum.KeyCode.E
	homePrompt.HoldDuration = 0
	homePrompt.MaxActivationDistance = 12
	homePrompt.RequiresLineOfSight = false
	homePrompt.Style = Enum.ProximityPromptStyle.Custom
	homePrompt.Parent = home
	homePrompt.Triggered:Connect(function(player: Player)
		if ctx.inArea(player, "lane") then
			ctx.sendHome(player)
		end
	end)
	-- Braziers before Maison Minuit.
	for _, sz in { 1, -1 } do
		local base = at(LG.minuitX - 22, 0.35, sz * 16)
		Kit.post(root, "Brazier", 4, 1, base, L.blackLacquer)
		Kit.part(root, "Bowl", Vector3.new(1, 3, 3), CFrame.new(base + Vector3.new(0, 4.4, 0)) * CFrame.Angles(0, 0, math.pi / 2), L.brass, { shape = Enum.PartType.Cylinder })
		local fire = Kit.part(root, "Fire", Vector3.new(1.8, 1.6, 1.8), CFrame.new(base + Vector3.new(0, 5.4, 0)), L.fire, { shape = Enum.PartType.Ball, collide = false, shadow = false })
		Kit.pointLight(fire, 2.4, 30, rgb(255, 150, 70))
		fire:SetAttribute("Flame", true)
	end
	-- Beyond the houses: dark trees, a wall, and nothing more.
	for x = west, east, 18 do
		for _, sz in { 1, -1 } do
			darkTree(root, at(x + rng:NextNumber(-4, 4), 0.35, sz * rng:NextNumber(back - 6, back - 1)), rng:NextNumber(26, 40), rng)
		end
	end
	for _, z in { -back + 6, back - 6 } do
		for x = -LG.half + 40, LG.minuitX - 40, 70 do
			if math.abs(x) > 4 then
				darkTree(root, at(x + 35, 0.35, z * 0.92), rng:NextNumber(18, 26), rng)
			end
		end
	end
	-- (Dark ground on out under the night, so the Lane never ends at a cliff.)
	Kit.part(root, "Beyond", Vector3.new(1600, 1, 1600), CFrame.new(at(0, -2.7, 0)), look(rgb(16, 20, 16), Enum.Material.Grass), { collide = false, shadow = false, query = false })
	local barrier = look(Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, 0, 1)
	span("EdgeWest", Vector3.new(west - 1, -2, -back), Vector3.new(west, 40, back), barrier, { shadow = false, query = false })
	span("EdgeEast", Vector3.new(east, -2, -back), Vector3.new(east + 1, 40, back), barrier, { shadow = false, query = false })
	span("EdgeNorth", Vector3.new(west, -2, back), Vector3.new(east, 40, back + 1), barrier, { shadow = false, query = false })
	span("EdgeSouth", Vector3.new(west, -2, -back - 1), Vector3.new(east, 40, -back), barrier, { shadow = false, query = false })
	Kit.persist(root)
	return root
end

---------------------------------------------------------------------------------------------------
-- Knocking
---------------------------------------------------------------------------------------------------

local function round(ctx: Types.Ctx): number
	return math.floor(os.time() / (math.max(1, ctx.cfg().lane.roundMinutes) * 60))
end

-- When this round ends (seconds since 1970).
local function roundEnds(ctx: Types.Ctx): number
	local span = math.max(1, ctx.cfg().lane.roundMinutes) * 60
	return (round(ctx) + 1) * span
end

local function visited(ctx: Types.Ctx, h: Types.Saved): { number }
	if h.round ~= round(ctx) then
		h.round = round(ctx)
		h.doors = {}
	end
	local list = {}
	for i = 1, #doors do
		if h.doors[tostring(i)] then
			table.insert(list, i)
		end
	end
	return list
end

-- A guest knocks at door `i` (its prompt). The server checks they're at that door, that it's
-- theirs to knock this round, and pays the treat.
function Lane.knock(ctx: Types.Ctx, player: Player, i: number)
	local door = doors[i]
	if not opened or not door then
		return
	end
	local root = ctx.rootOf(player)
	local data = Profiles.get(player)
	if not root or not data then
		return
	end
	local p = root.CFrame.Position
	local d = door.cf.Position
	local c = ctx.cfg().lane
	if Vector3.new(p.X - d.X, 0, p.Z - d.Z).Magnitude > c.reach or math.abs(p.Y - d.Y) > 10 then
		return
	end
	if not ctx.trusted(player) then
		return
	end
	local now = os.clock()
	if (lastKnock[player] or -math.huge) + c.knockGap > now then
		return
	end
	lastKnock[player] = now
	local h = ctx.saved(data)
	local before = visited(ctx, h)
	local host = Lane.Hosts[i]
	local key = tostring(i)
	if h.doors[key] then
		-- Already had this one's treat this round: the door opens, the host waves, no treat.
		ctx.broadcast({ op = "door", i = i, by = player.UserId, empty = true })
		ctx.send(player, { op = "treat", i = i, host = host.name, line = "Back so soon? The other doors are waiting!", empty = true, visited = before, total = #doors, ends = roundEnds(ctx) })
		return
	end
	h.doors[key] = true
	local list = visited(ctx, h)
	local gilt = if i == #doors then c.minuitGilt else c.gilt
	local gems = if ctx.rng:NextNumber() < c.gemChance then 1 else 0
	local paid, given = ctx.reward(player, gilt, gems, "Trick or treat")
	ctx.award(player, "holiday_halloween")
	ctx.curio(player, "jackOLantern", "lane:" .. tostring(h.round))
	local message: { [string]: any } = {
		op = "treat",
		i = i,
		host = host.name,
		line = host.line,
		treat = host.treat,
		treatName = host.treatName,
		gilt = paid,
		gems = given,
		visited = list,
		total = #doors,
		ends = roundEnds(ctx),
	}
	if #list >= #doors then
		-- Every door in one round: a full bag.
		local bonusGilt, bonusGems = ctx.reward(player, c.fullBagGilt, c.fullBagGems, "Trick or treat: a full bag")
		message.full = true
		message.bonusGilt = bonusGilt
		message.bonusGems = bonusGems
		ctx.award(player, "fullBag")
		ctx.curio(player, "candyPail", "lane:full:" .. tostring(h.round))
		ctx.salute("Hallows Lane", Names.of(player) .. " has knocked at every door. A full bag!", player)
	end
	ctx.broadcast({ op = "door", i = i, by = player.UserId, treat = host.treat })
	ctx.send(player, message)
end

---------------------------------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------------------------------

function Lane.open(ctx: Types.Ctx)
	if built then
		built:Destroy()
	end
	local m = build(ctx)
	m.Parent = ctx.folder()
	built = m
	opened = true
	-- The hosts take their places (each takes a moment to dress).
	for i, door in doors do
		task.spawn(function()
			local model = host(door.house, door.cf, i)
			if model and opened and door.house.Parent then
				door.host = model
			elseif model then
				model:Destroy()
			end
		end)
	end
end

function Lane.close(_ctx: Types.Ctx)
	opened = false
	if built then
		built:Destroy()
		built = nil
	end
	doors = {}
	table.clear(lastKnock)
end

function Lane.arrival(_ctx: Types.Ctx, _player: Player): CFrame?
	if not opened then
		return nil
	end
	local O = HolidayGames.origin("lane")
	local at = O + HolidayGames.Lane.arrival
	return CFrame.lookAt(at, at + Vector3.new(1, 0, 0))
end

function Lane.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return {}
	end
	return { visited = visited(ctx, ctx.saved(data)), total = #doors, ends = roundEnds(ctx) }
end

function Lane.leave(_ctx: Types.Ctx, player: Player)
	lastKnock[player] = nil
end

-- For tests: the doors (each one's frame).
function Lane.doors(): { CFrame }
	local list = {}
	for _, d in doors do
		table.insert(list, d.cf)
	end
	return list
end

return Lane

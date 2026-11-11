--!strict
-- The attractions' rooms off the Foyer, furnished at their grown size (built after the Grand Scale,
-- like the Suite's fireplace): each with a grand entrance to its attraction on its far wall (walk
-- up and press: in), and what else it needs.
--   The Luxe Lounge (the Velvet Room): four treadmills to train your Stride on (their belts really
--   run: keep walking or be carried off the end), the golden treadmill (double Stride, for Gems),
--   and the lectern with the upgrades board.
--   The Basement Stair (the Obsidian Room): the way down into the Maison Basement, and its boards.
--   The Jet Lounge (on the Terrace): the private jet's boarding arch, to Luxury Island.
-- The prompts are tagged "AttractionPrompt" (server/Attractions connects them): Kind "go" takes a
-- guest in, "panel" opens the attraction's board on their screen.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Brand = require(ReplicatedStorage.Shared.Brand)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)

local Lobbies = {}

local L = Kit.Looks
local rgb = Color3.fromRGB
local GOLD = rgb(232, 182, 72)

local function prompt(parent: BasePart, id: string, kind: string, action: string, object: string, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = "AttractionPrompt"
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 14
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom -- (the house's own prompt cards)
	p:SetAttribute("Attraction", id)
	p:SetAttribute("Kind", kind)
	p.Parent = parent
	CollectionService:AddTag(p, "AttractionPrompt")
	return p
end

-- A grand entrance on a wall: a tall arch of black lacquer and brass, a curtain of the attraction's
-- light hanging in it, its name over it. `cf`: the arch's middle on the floor, facing into the room.
function Lobbies.entrance(parent: Instance, id: string, cf: CFrame, noPlaque: boolean?): BasePart
	local def = AttractionList.byId[id]
	local m = Kit.model(parent, "Entrance_" .. id)
	local w, h = 14, 17
	for _, side in { -1, 1 } do
		Kit.part(m, "Pier", Vector3.new(2.4, h + 2, 2.4), cf * CFrame.new(side * (w / 2 + 1.2), (h + 2) / 2, 0), L.blackLacquer)
		Kit.part(m, "PierBand", Vector3.new(2.6, 0.5, 2.6), cf * CFrame.new(side * (w / 2 + 1.2), h * 0.66, 0), L.brass, { collide = false })
		Kit.part(m, "PierCap", Vector3.new(3, 0.8, 3), cf * CFrame.new(side * (w / 2 + 1.2), h + 2.3, 0), L.brass)
	end
	Kit.part(m, "Lintel", Vector3.new(w + 5, 2.6, 2.4), cf * CFrame.new(0, h + 1.3, 0), L.blackLacquer)
	local board = Kit.part(m, "NameBoard", Vector3.new(w + 2, 2, 0.3), cf * CFrame.new(0, h + 1.3, -1.3), L.blackLacquer, { collide = false })
	Kit.engrave(board, Enum.NormalId.Front, {
		{ text = string.upper(def.name), size = 0.62, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = def.tag, size = 0.3, font = Brand.Fonts.bodyBold, color = rgb(232, 222, 204) },
	}, { ppu = 60, lit = false, brightness = 1.6, maxDistance = 200 })
	local veil = Kit.part(m, "Veil", Vector3.new(w, h, 0.3), cf * CFrame.new(0, h / 2, 0), { color = def.colour:Lerp(GOLD, 0.35), material = Enum.Material.Neon, transparency = 0.6 }, { collide = false, shadow = false })
	veil.CanQuery = true
	Kit.pointLight(veil, 1.6, 26, def.colour:Lerp(rgb(255, 255, 255), 0.4))
	HolidayProps.sparkle(veil, def.colour:Lerp(GOLD, 0.5), 6, 0.6)
	prompt(veil, id, "go", "Go in", def.name, 0.3)
	if noPlaque then
		return veil
	end
	-- A plaque beside it: what it is, in a sentence.
	local plaque = Kit.part(m, "Plaque", Vector3.new(6.4, 3.4, 0.25), cf * CFrame.new(w / 2 + 6.5, 6, -0.6) * CFrame.Angles(0, 0, 0), L.blackLacquer, { collide = false })
	Kit.engrave(plaque, Enum.NormalId.Front, {
		{ text = string.upper(def.name), size = 0.22, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = def.line, size = 0.56, font = Brand.Fonts.body, color = rgb(232, 222, 204) },
	}, { ppu = 80, lit = false, brightness = 1.3, gap = 0.03 })
	return veil
end

-- A treadmill: a lacquered deck with a running belt (a conveyor: it carries you off the end unless
-- you keep walking), brass handrails and a console. `cf`: the deck's middle on the floor, its belt
-- running back toward -Z (you walk toward +Z, facing the console).
local function treadmill(parent: Instance, cf: CFrame, golden: boolean): BasePart
	local m = Kit.model(parent, if golden then "GoldenTreadmill" else "Treadmill")
	local deck = if golden then { color = GOLD, material = Enum.Material.Metal, reflectance = 0.2 } else L.blackLacquer
	Kit.part(m, "Deck", Vector3.new(5.4, 1, 11), cf * CFrame.new(0, 0.5, 0), deck)
	local belt = Kit.part(m, "Belt", Vector3.new(4.2, 0.2, 10), cf * CFrame.new(0, 1.1, 0), { color = rgb(26, 26, 30), material = Enum.Material.Rubber })
	belt.CanTouch = true
	belt:SetAttribute("Golden", golden)
	belt:SetAttribute("Speed", if golden then 16 else 12)
	-- (Moving with it: an anchored part's velocity carries whoever stands on it.)
	belt.AssemblyLinearVelocity = -cf.LookVector * (if golden then 16 else 12)
	CollectionService:AddTag(belt, "LuxeTreadmill")
	for _, side in { -1, 1 } do
		Kit.post(m, "RailPost", 3.6, 0.3, (cf * CFrame.new(side * 2.5, 1, 3.8)).Position, L.brass, { collide = false })
		Kit.part(m, "Rail", Vector3.new(0.3, 0.3, 4.6), cf * CFrame.new(side * 2.5, 4.6, 2.2), L.brass, { collide = false })
	end
	local console = Kit.part(m, "Console", Vector3.new(5, 2.6, 0.8), cf * CFrame.new(0, 4.6, 5.2) * CFrame.Angles(math.rad(-20), 0, 0), L.blackLacquer, { collide = false })
	Kit.engrave(console, Enum.NormalId.Back, {
		{ text = if golden then "GOLDEN · DOUBLE STRIDE" else "STRIDE", size = 0.45, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "keep walking", size = 0.3, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 80, lit = false, brightness = 1.5 })
	Kit.part(m, "Glow", Vector3.new(4.4, 0.12, 0.3), cf * CFrame.new(0, 1.25, -4.9), { color = if golden then GOLD else rgb(214, 62, 92), material = Enum.Material.Neon }, { collide = false, query = false, shadow = false })
	return belt
end

-- The Luxe Lounge, in the Velvet Room.
local function luxeLounge(parent: Instance)
	local R = Layout.Velvet
	local y = R.arrival.Y
	local m = Kit.model(parent, "LuxeLounge")
	local midZ = (R.minZ + R.maxZ) / 2
	-- The way in, on the far (west) wall, facing into the room.
	local at = Vector3.new(R.minX + 2.2, y, midZ)
	Lobbies.entrance(m, "luxe", CFrame.lookAt(at, at + Vector3.new(1, 0, 0)))
	-- Four treadmills along the north wall, walked toward the wall; the golden one by the south wall.
	for i = 0, 3 do
		local x = R.minX + 22 + i * 11
		treadmill(m, CFrame.lookAt(Vector3.new(x, y, R.maxZ - 10), Vector3.new(x, y, R.maxZ + 10)), false)
	end
	local gx = (R.minX + R.maxX) / 2 + 6
	treadmill(m, CFrame.lookAt(Vector3.new(gx, y, R.minZ + 10), Vector3.new(gx, y, R.minZ - 10)), true)
	local goldSign = Kit.part(m, "GoldenSign", Vector3.new(8, 2.4, 0.25), CFrame.lookAt(Vector3.new(gx, y + 10, R.minZ + 1.4), Vector3.new(gx, y + 10, R.maxZ)), L.blackLacquer, { collide = false })
	Kit.engrave(goldSign, Enum.NormalId.Front, {
		{ text = "THE GOLDEN TREADMILL", size = 0.45, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "double Stride · yours for Gems at the board", size = 0.3, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 70, lit = false, brightness = 1.5 })
	-- The board: a brass lectern with the upgrades, and a sign over the treadmills.
	local lx = R.minX + 14
	local lectern = Kit.model(m, "Lectern")
	local lcf = CFrame.lookAt(Vector3.new(lx, y, R.minZ + 8), Vector3.new(lx, y, R.maxZ))
	Kit.part(lectern, "Stand", Vector3.new(2.2, 3.6, 1.6), lcf * CFrame.new(0, 1.8, 0), L.brass)
	local top = Kit.part(lectern, "Desk", Vector3.new(3.2, 0.3, 2.4), lcf * CFrame.new(0, 3.8, 0) * CFrame.Angles(math.rad(-18), 0, 0), L.blackLacquer)
	prompt(top, "luxe", "panel", "Upgrades", "Steal a Luxe")
	Kit.pointLight(top, 0.9, 12, rgb(255, 214, 160))
	local sign = Kit.part(m, "LoungeSign", Vector3.new(26, 3.2, 0.3), CFrame.lookAt(Vector3.new((R.minX + R.maxX) / 2, y + 15, R.maxZ - 1.4), Vector3.new((R.minX + R.maxX) / 2, y + 15, R.minZ)), L.blackLacquer, { collide = false })
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE LUXE LOUNGE", size = 0.55, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "run the treadmills for Stride: faster in the residence, where it matters", size = 0.28, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 50, lit = false, brightness = 1.5, maxDistance = 180 })
end

-- The Basement Stair, in the Obsidian Room: the way down on its north wall, and the boards.
local function basementStair(parent: Instance)
	local R = Layout.Obsidian
	local y = R.arrival.Y
	local m = Kit.model(parent, "BasementStair")
	local midX = (R.minX + R.maxX) / 2
	local at = Vector3.new(midX, y, R.maxZ - 2.2)
	Lobbies.entrance(m, "basement", CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
	-- The boards: a lectern beside the way down, and the times over it.
	local lx = midX - 18
	local lectern = Kit.model(m, "Lectern")
	local lcf = CFrame.lookAt(Vector3.new(lx, y, R.maxZ - 8), Vector3.new(lx, y, R.minZ))
	Kit.part(lectern, "Stand", Vector3.new(2.2, 3.6, 1.6), lcf * CFrame.new(0, 1.8, 0), L.brass)
	local top = Kit.part(lectern, "Desk", Vector3.new(3.2, 0.3, 2.4), lcf * CFrame.new(0, 3.8, 0) * CFrame.Angles(math.rad(-18), 0, 0), L.blackLacquer)
	prompt(top, "basement", "panel", "Best times", "The Maison Basement")
	Kit.pointLight(top, 0.9, 12, rgb(255, 214, 160))
	local sign = Kit.part(m, "StairSign", Vector3.new(22, 3.2, 0.3), CFrame.lookAt(Vector3.new(lx, y + 9, R.maxZ - 1.4), Vector3.new(lx, y + 9, R.minZ)), L.blackLacquer, { collide = false })
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE MAISON BASEMENT", size = 0.55, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "sixteen stages down to the Treasury · best times at the lectern", size = 0.28, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 50, lit = false, brightness = 1.5, maxDistance = 180 })
end

-- The Executive's Anteroom, in the Midnight Room: the lift up on its south wall, and the
-- Quartermaster at his desk beside it (the sidearm, the gear, invitations).
local function anteroom(parent: Instance)
	local R = Layout.Midnight
	local y = R.arrival.Y
	local m = Kit.model(parent, "ExecutiveAnteroom")
	local midX = (R.minX + R.maxX) / 2
	local at = Vector3.new(midX, y, R.minZ + 2.2)
	Lobbies.entrance(m, "executive", CFrame.lookAt(at, at + Vector3.new(0, 0, 1)))
	-- The Quartermaster's desk: walnut and brass, his gear laid out on it.
	local dx = midX + 20
	local dcf = CFrame.lookAt(Vector3.new(dx, y, R.minZ + 9), Vector3.new(dx, y, R.maxZ))
	local desk = Kit.model(m, "QuartermasterDesk")
	Kit.part(desk, "Counter", Vector3.new(9, 3.6, 2.6), dcf * CFrame.new(0, 1.8, 0), L.walnut)
	local top = Kit.part(desk, "Top", Vector3.new(9.4, 0.3, 3), dcf * CFrame.new(0, 3.75, 0), L.brass)
	for k, glyphColour in { rgb(40, 40, 46), rgb(90, 70, 50), rgb(60, 90, 70) } do
		Kit.part(desk, "Case" .. k, Vector3.new(1.6, 0.6, 1.1), dcf * CFrame.new(-3 + (k - 1) * 3, 4.2, 0), { color = glyphColour, material = Enum.Material.Leather }, { collide = false })
	end
	prompt(top, "executive", "panel", "Equipment", "The Quartermaster")
	Kit.pointLight(top, 1, 14, rgb(255, 220, 170))
	local sign = Kit.part(m, "AnteroomSign", Vector3.new(24, 3.2, 0.3), CFrame.lookAt(Vector3.new(midX, y + 15, R.minZ + 1.4), Vector3.new(midX, y + 15, R.maxZ)), L.blackLacquer, { collide = false })
	Kit.engrave(sign, Enum.NormalId.Front, {
		{ text = "THE EXECUTIVE SUITE", size = 0.55, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "by invitation only · see the Quartermaster for your sidearm and gear", size = 0.28, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 50, lit = false, brightness = 1.5, maxDistance = 180 })
end

-- The auction house round the rostrum: a velvet backdrop under a brass pelmet, two lots on marble
-- pedestals under glass in their own pools of light (each with its brass lot plate), a rope line
-- with its opening in front of the rostrum, and a stand of bidding paddles on the dais. Only the
-- pedestals are solid; nothing stands in the way to the rostrum or the duel tables.
local function auctionHouse(m: Model, rcf: CFrame)
	local DECO = { collide = false, query = false }
	local GLASS = { color = rgb(220, 232, 240), material = Enum.Material.Glass, transparency = 0.82, reflectance = 0.15 }
	local GOLD = { color = rgb(232, 186, 82), material = Enum.Material.Metal, reflectance = 0.2 }
	-- The backdrop: folds of velvet behind the dais, below the board.
	for i = -8, 7 do
		local look = if i % 2 == 0 then L.burgundyVelvet else L.deepVelvet
		Kit.part(m, "Drape", Vector3.new(1.02, 7.4, 0.3 + (i % 2) * 0.12), rcf * CFrame.new(i + 0.5, 4.5, 3.4), look, DECO)
	end
	Kit.part(m, "Pelmet", Vector3.new(16.6, 0.6, 0.6), rcf * CFrame.new(0, 8.45, 3.2), L.brass, DECO)
	Kit.part(m, "Fringe", Vector3.new(16.4, 0.25, 0.4), rcf * CFrame.new(0, 8.05, 3.1), GOLD, DECO)
	-- Two lots, each on its pedestal under glass, lit from above.
	for k, side in { -1, 1 } do
		local base = rcf * CFrame.new(side * 9, 0, -2)
		Kit.part(m, "LotPlinth" .. k, Vector3.new(2, 3.4, 2), base * CFrame.new(0, 1.7, 0), L.boneMarble)
		Kit.part(m, "LotPlinthFoot" .. k, Vector3.new(2.4, 0.3, 2.4), base * CFrame.new(0, 0.15, 0), L.blackMarble, DECO)
		Kit.part(m, "LotPlinthTop" .. k, Vector3.new(2.3, 0.2, 2.3), base * CFrame.new(0, 3.5, 0), L.brass, DECO)
		if k == 1 then
			-- (A golden egg on a little ebony stand.)
			Kit.part(m, "LotStand" .. k, Vector3.new(0.6, 0.3, 0.6), base * CFrame.new(0, 3.75, 0), L.blackLacquer, DECO)
			Kit.ball(m, "LotEgg", 1.1, (base * CFrame.new(0, 4.45, 0)).Position, GOLD, DECO)
			Kit.ball(m, "LotEggJewel", 0.28, (base * CFrame.new(0, 4.5, -0.5)).Position, { color = rgb(200, 30, 60), material = Enum.Material.Glass }, DECO)
		else
			-- (A porcelain vase with a gold band.)
			Kit.post(m, "LotVase" .. k, 1.3, 0.7, (base * CFrame.new(0, 3.6, 0)).Position, L.bone, DECO)
			Kit.post(m, "LotVaseNeck" .. k, 0.5, 0.42, (base * CFrame.new(0, 4.9, 0)).Position, L.bone, DECO)
			Kit.post(m, "LotVaseBand" .. k, 0.14, 0.74, (base * CFrame.new(0, 4.3, 0)).Position, GOLD, DECO)
		end
		Kit.part(m, "LotDome" .. k, Vector3.new(1.8, 2.1, 1.8), base * CFrame.new(0, 4.65, 0), GLASS, DECO)
		local plate = Kit.part(m, "LotPlate" .. k, Vector3.new(1.3, 0.45, 0.06), base * CFrame.new(0, 2.6, -1.04), L.brass, DECO)
		Kit.engrave(plate, Enum.NormalId.Front, { { text = if k == 1 then "LOT I" else "LOT II", size = 0.6, font = Brand.Fonts.display, color = rgb(40, 28, 10) } }, { ppu = 60, lit = true, maxDistance = 60 })
		-- (Its light: a small spot high above, pointed down at it.)
		local lamp = Kit.part(m, "LotLamp" .. k, Vector3.new(0.4, 0.4, 0.4), base * CFrame.new(0, 12, 0), { color = rgb(30, 30, 30), material = Enum.Material.Metal, transparency = 1 }, DECO)
		Kit.spotLight(lamp, Enum.NormalId.Bottom, 2.2, 16, 26, rgb(255, 236, 200), false)
	end
	-- The rope line, open in front of the rostrum.
	for k, x in { -7.5, -4.5, 4.5, 7.5 } do
		local at = rcf * CFrame.new(x, 0, -4.8)
		Kit.post(m, "Stanchion" .. k, 3, 0.25, at.Position, L.brass, DECO)
		Kit.ball(m, "StanchionTop" .. k, 0.42, (at * CFrame.new(0, 3.1, 0)).Position, L.brass, DECO)
		Kit.post(m, "StanchionFoot" .. k, 0.14, 0.9, at.Position, L.brass, DECO)
	end
	for k, x in { -6, 6 } do
		Kit.cylinder(m, "Rope" .. k, 3, 0.2, rcf * CFrame.new(x, 2.55, -4.8), L.burgundyVelvet, DECO)
	end
	-- The bidding paddles, in a walnut stand on the dais beside the rostrum (out of the way to it).
	local stand = rcf * CFrame.new(3.9, 0.8, -0.4)
	Kit.part(m, "PaddleStand", Vector3.new(1.4, 2.6, 0.7), stand * CFrame.new(0, 1.3, 0), L.walnut, DECO)
	for k = 1, 3 do
		local cf = stand * CFrame.new(-0.42 + (k - 1) * 0.42, 3.25, 0) * CFrame.Angles(0, 0, math.rad(-8 + (k - 1) * 8))
		Kit.part(m, "PaddleHandle" .. k, Vector3.new(0.12, 0.9, 0.12), cf, L.darkWood, DECO)
		Kit.cylinder(m, "Paddle" .. k, 0.08, 0.7, cf * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, math.rad(90), 0), L.bone, DECO)
	end
end

-- The Grand Auction, in the Library: the auctioneer's rostrum at the far end, and its board.
local function auctionRoom(parent: Instance)
	local R = Layout.Library
	local y = R.arrival.Y
	local m = Kit.model(parent, "GrandAuction")
	local midX = (R.minX + R.maxX) / 2
	local rcf = CFrame.lookAt(Vector3.new(midX, y, R.maxZ - 6), Vector3.new(midX, y, R.minZ))
	Kit.part(m, "Dais", Vector3.new(12, 0.8, 6), rcf * CFrame.new(0, 0.4, 0), L.walnut)
	Kit.part(m, "DaisEdge", Vector3.new(12.2, 0.12, 6.2), rcf * CFrame.new(0, 0.82, 0), L.brass, { collide = false })
	Kit.part(m, "Rostrum", Vector3.new(3.4, 4, 2), rcf * CFrame.new(0, 2.8, -1.2), L.walnut)
	local top = Kit.part(m, "RostrumTop", Vector3.new(3.8, 0.3, 2.4), rcf * CFrame.new(0, 4.95, -1.2) * CFrame.Angles(math.rad(-15), 0, 0), L.brass)
	Kit.part(m, "Gavel", Vector3.new(0.4, 0.4, 1.4), rcf * CFrame.new(0.8, 5.3, -1.2), L.walnut, { collide = false })
	prompt(top, "auction", "panel", "Bid", "The Grand Auction", 0)
	Kit.pointLight(top, 1.1, 18, rgb(255, 220, 170))
	local board = Kit.part(m, "AuctionBoard", Vector3.new(20, 5, 0.3), CFrame.lookAt(Vector3.new(midX, y + 11, R.maxZ - 1.2), Vector3.new(midX, y + 11, R.minZ)), L.blackLacquer, { collide = false })
	Kit.engrave(board, Enum.NormalId.Front, {
		{ text = "THE GRAND AUCTION", size = 0.36, font = Brand.Fonts.display, color = rgb(255, 214, 120) },
		{ text = "this week's lots · one of a kind · bid at the rostrum in Gilt or Gems", size = 0.18, font = Brand.Fonts.body, color = rgb(230, 220, 200) },
	}, { ppu = 50, lit = false, brightness = 1.5, maxDistance = 200 })
	auctionHouse(m, rcf)
end

-- The Jet Lounge, on the Terrace: the private jet's boarding arch in the east balustrade's middle
-- (between its two planters), facing the fire pit. A guest without the Island Key who walks up is
-- shown how to get it (server/Attractions: the island is "locked" for them).
local function jetLounge(parent: Instance)
	local R = Layout.Terrace
	local y = R.floorY
	local m = Kit.model(parent, "JetLounge")
	local z = R.minZ + 10 * Layout.SCALE -- (the terrace's z 40 as drawn: between the planters)
	local at = Vector3.new(R.maxX - 3, y, z)
	Lobbies.entrance(m, "island", CFrame.lookAt(at, at - Vector3.new(1, 0, 0)), true)
end

-- The Ballroom's far end: the great doors to the Grand Ballroom, on the axis of the room, past the
-- marble floor and the chandelier (between the two tables nearest the north wall).
local function grandDoors(parent: Instance)
	local m = Kit.model(parent, "GrandBallroomDoors")
	local at = Layout.Ballroom.galaDoors
	Lobbies.entrance(m, "gala", CFrame.lookAt(at, at + Vector3.new(0, 0, -1)), true)
end

function Lobbies.build(parent: Instance)
	local root = Kit.model(parent, "Lobbies")
	local rooms: { { name: string, fn: (Instance) -> () } } = {
		{ name = "The Grand Ballroom's doors", fn = grandDoors },
		{ name = "The Luxe Lounge", fn = luxeLounge },
		{ name = "The Basement Stair", fn = basementStair },
		{ name = "The Executive's Anteroom", fn = anteroom },
		{ name = "The Grand Auction", fn = auctionRoom },
		{ name = "The Jet Lounge", fn = jetLounge },
	}
	for _, room in rooms do
		local ok, err = pcall(room.fn :: any, root)
		if not ok then
			warn("[Maison] " .. room.name .. " couldn't be furnished: " .. tostring(err))
		end
	end
end

return Lobbies

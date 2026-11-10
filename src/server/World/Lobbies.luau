--!strict
-- The attractions' rooms off the Foyer, furnished at their grown size (built after the Grand Scale,
-- like the Suite's fireplace): each with a grand entrance to its attraction on its far wall (walk
-- up and press: in), and what else it needs.
--   The Luxe Lounge (the Velvet Room): four treadmills to train your Stride on (their belts really
--   run: keep walking or be carried off the end), the golden treadmill (double Stride, for Gems),
--   and the lectern with the upgrades board.
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
function Lobbies.entrance(parent: Instance, id: string, cf: CFrame): BasePart
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

function Lobbies.build(parent: Instance)
	local root = Kit.model(parent, "Lobbies")
	local ok, err = pcall(luxeLounge :: any, root)
	if not ok then
		warn("[Maison] The Luxe Lounge couldn't be furnished: " .. tostring(err))
	end
end

return Lobbies

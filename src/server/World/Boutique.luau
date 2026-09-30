--!strict
-- The Boutique (§3, §12): a narrow mirrored shop through the Foyer's back wall. Mirror panels
-- between brass pilasters, glass counters along both walls lit from within, the Tailor behind
-- the long counter at the far end, a dress form wearing the week's featured piece, the tall
-- mirror where you choose what to wear, and the Ledger open on a lectern by the door. Shopping is
-- a place you walk into, never a pop-up.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)

local L = Kit.Looks
local B = Layout.Boutique
local FLOOR = Layout.FLOOR

local BoutiqueRoom = {}

local INVISIBLE = { color = Color3.new(), material = Enum.Material.SmoothPlastic, transparency = 1 }
local MIRROR = { color = Color3.fromRGB(70, 74, 82), material = Enum.Material.Glass, reflectance = 0.5, transparency = 0.02 }
local VITRINE = { color = Color3.fromRGB(200, 214, 224), material = Enum.Material.Glass, reflectance = 0.2, transparency = 0.72 }
local SATIN = { color = Color3.fromRGB(40, 12, 20), material = Enum.Material.Fabric }

local function prompt(parent: Instance, name: string, action: string, object: string, offset: number): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Name = name
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.HoldDuration = 0
	p.MaxActivationDistance = 8
	p.RequiresLineOfSight = false
	p.Style = Enum.ProximityPromptStyle.Custom
	p:SetAttribute("Offset", offset)
	p.Parent = parent
	return p
end

local function shell(m: Model)
	local top = FLOOR + B.height
	Kit.span(m, "Floor", Vector3.new(B.minX, FLOOR - 1, B.minZ), Vector3.new(B.maxX, FLOOR, B.maxZ), L.boneMarble)
	Kit.span(m, "Runner", Vector3.new(17, FLOOR, B.minZ), Vector3.new(25, FLOOR + 0.05, B.maxZ - 5), L.carpet, { collide = false, query = false })
	Kit.span(m, "Ceiling", Vector3.new(B.minX - 2, top, B.minZ), Vector3.new(B.maxX, top + 1, B.maxZ + 2), L.blackLacquer)
	Kit.span(m, "WallW", Vector3.new(B.minX - 2, FLOOR, B.minZ), Vector3.new(B.minX, top, B.maxZ + 2), L.wall)
	Kit.span(m, "WallN", Vector3.new(B.minX - 2, FLOOR, B.maxZ), Vector3.new(B.maxX, top, B.maxZ + 2), L.wall)
	-- The east side is the Obsidian Room's wall: only a facing on this side.
	Kit.span(m, "FacingE", Vector3.new(B.maxX - 0.2, FLOOR, B.minZ), Vector3.new(B.maxX, top, B.maxZ), L.wall, { collide = false, query = false })
	-- Mirror panels between brass pilasters, down both long walls.
	for _, side in { -1, 1 } do
		local x = if side < 0 then B.minX + 0.05 else B.maxX - 0.25
		local z = B.minZ + 2
		while z < B.maxZ - 2 do
			Kit.span(m, "Pilaster", Vector3.new(x, FLOOR, z - 0.3), Vector3.new(x + 0.2, top, z + 0.3), L.brass, { collide = false, query = false })
			if z + 4 < B.maxZ - 1 then
				Kit.span(m, "MirrorPanel", Vector3.new(x, FLOOR + 4.5, z + 0.4), Vector3.new(x + 0.15, top - 1.5, z + 3.6), MIRROR, { collide = false, query = false })
			end
			z += 4
		end
	end
	-- A brass cornice and small pendant lights.
	Kit.span(m, "Cornice", Vector3.new(B.minX, top - 0.6, B.minZ), Vector3.new(B.maxX, top - 0.3, B.minZ + 0.3), L.brass, { collide = false, query = false, shadow = false })
	for _, z in { 48, 54 } do
		local lamp = Kit.part(m, "Pendant", Vector3.new(1.2, 0.5, 1.2), CFrame.new(21, top - 2.2, z), L.brass, { collide = false })
		Kit.cylinder(m, "PendantCord", 1.7, 0.06, CFrame.new(21, top - 1.1, z) * CFrame.Angles(0, 0, math.rad(90)), L.brass, { collide = false, shadow = false, query = false })
		Kit.pointLight(lamp, 0.9, 16, Color3.fromRGB(255, 214, 170))
	end
end

-- A glass counter along a wall, lit from within, with small things on velvet inside.
local function vitrine(m: Model, name: string, cf: CFrame, length: number)
	Kit.part(m, name .. "Base", Vector3.new(length, 2.6, 1.8), cf * CFrame.new(0, 1.3, 0), L.blackLacquer)
	Kit.part(m, name .. "Velvet", Vector3.new(length - 0.3, 0.1, 1.5), cf * CFrame.new(0, 2.65, 0), SATIN, { collide = false, shadow = false })
	Kit.part(m, name .. "Glass", Vector3.new(length, 1.2, 1.8), cf * CFrame.new(0, 3.3, 0), VITRINE, { shadow = false })
	Kit.part(m, name .. "Rail", Vector3.new(length + 0.1, 0.08, 1.9), cf * CFrame.new(0, 3.93, 0), L.brass, { collide = false, shadow = false })
	local n = math.floor(length / 1.4)
	for i = 1, n do
		local x = -length / 2 + (i - 0.5) * (length / n)
		local colour = ({ Brand.Colours.gold, Color3.fromRGB(190, 190, 200), Color3.fromRGB(120, 30, 40), Color3.fromRGB(230, 226, 214) })[(i % 4) + 1]
		Kit.part(m, name .. "Piece", Vector3.new(0.35, 0.18, 0.5), cf * CFrame.new(x, 2.8, 0) * CFrame.Angles(0, math.rad(i * 23), 0), { color = colour, material = Enum.Material.Metal, reflectance = 0.3 }, { collide = false, shadow = false, query = false })
	end
	local glow = Kit.part(m, name .. "Glow", Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 3.5, 0), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.pointLight(glow, 0.5, 6, Color3.fromRGB(255, 232, 200))
end

local function counters(m: Model)
	vitrine(m, "CounterW", CFrame.new(B.minX + 1.4, FLOOR, 52) * CFrame.Angles(0, math.rad(90), 0), 8)
	vitrine(m, "CounterE", CFrame.new(B.maxX - 1.4, FLOOR, 54.5) * CFrame.Angles(0, math.rad(90), 0), 6)
	-- The long counter at the far end, the Tailor behind it.
	local c = B.counter
	Kit.part(m, "LongCounter", Vector3.new(10, 3.4, 1.6), c * CFrame.new(0, 1.7, 0), L.walnut)
	Kit.part(m, "LongCounterTop", Vector3.new(10.4, 0.15, 1.9), c * CFrame.new(0, 3.47, 0), L.blackMarble, { shadow = false })
	Kit.part(m, "LongCounterRail", Vector3.new(10.4, 0.1, 0.1), c * CFrame.new(0, 3.2, -0.85), L.brass, { collide = false, shadow = false })
	-- A ledger of prices is never shown here: prices are read live on the screen.
	local bell = Kit.part(m, "CounterBell", Vector3.new(0.5, 0.35, 0.5), c * CFrame.new(-3, 3.72, -0.2), L.brass, { collide = false, shadow = false })
	prompt(bell, "BoutiquePrompt", "Browse", "The Boutique", 1.5)
	CollectionService:AddTag(bell, "BoutiqueCounter")
end

local function dressForm(m: Model)
	local cf = B.dressForm
	Kit.post(m, "FormStand", 3.4, 0.25, cf.Position, L.brass, { collide = false })
	Kit.part(m, "FormBase", Vector3.new(1.6, 0.2, 1.6), cf * CFrame.new(0, 0.1, 0), L.blackLacquer)
	local body = Kit.part(m, "FormBody", Vector3.new(1.8, 2.6, 1.1), cf * CFrame.new(0, 4.7, 0), SATIN, { collide = false })
	body:SetAttribute("DressForm", true)
	Kit.part(m, "FormNeck", Vector3.new(0.5, 0.6, 0.5), cf * CFrame.new(0, 6.3, 0), L.walnut, { collide = false })
	Kit.part(m, "FormCap", Vector3.new(0.7, 0.2, 0.7), cf * CFrame.new(0, 6.65, 0), L.brass, { collide = false })
	-- A small plate naming what it wears (written by the Shop each week).
	local plate = Kit.part(m, "FormPlate", Vector3.new(2.2, 0.6, 0.05), cf * CFrame.new(0, 1.2, -0.9), L.brass, { collide = false, shadow = false })
	Kit.engrave(plate, Enum.NormalId.Front, {
		{ text = Kit.track("THIS WEEK"), size = 0.18, font = Brand.Fonts.bodyBold, color = Color3.fromRGB(40, 30, 12) },
		{ text = "The Boutique", size = 0.22, font = Brand.Fonts.display, color = Color3.fromRGB(40, 30, 12) },
	}, { ppu = 100, lit = false })
	plate:SetAttribute("FeaturedPlate", true)
	local spot = Kit.part(m, "FormSpot", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 11, -2), INVISIBLE, { collide = false, query = false, shadow = false })
	Kit.pointLight(spot, 0.8, 10, Color3.fromRGB(255, 226, 190))
end

local function mirror(m: Model)
	local cf = B.mirror
	Kit.part(m, "WardrobeMirrorFrame", Vector3.new(3.4, 8.4, 0.3), cf * CFrame.new(0, 4.4, 0.15), L.brass)
	local glass = Kit.part(m, "WardrobeMirror", Vector3.new(3, 8, 0.1), cf * CFrame.new(0, 4.4, -0.05), MIRROR, { collide = false })
	prompt(glass, "WardrobePrompt", "Wardrobe", "The Tailor's mirror", 0)
	CollectionService:AddTag(glass, "WardrobeMirror")
end

local function ledger(m: Model)
	local cf = B.ledger
	Kit.post(m, "LedgerStand", 3.2, 0.3, cf.Position, L.walnut, { collide = false })
	Kit.part(m, "LedgerFoot", Vector3.new(1.4, 0.2, 1.4), cf * CFrame.new(0, 0.1, 0), L.darkWood)
	Kit.part(m, "LedgerRest", Vector3.new(1.6, 0.15, 1.2), cf * CFrame.new(0, 3.35, 0) * CFrame.Angles(math.rad(-20), 0, 0), L.walnut, { collide = false })
	local book = Kit.part(m, "LedgerBook", Vector3.new(1.4, 0.18, 1.0), cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(math.rad(-20), 0, 0), { color = Color3.fromRGB(62, 30, 20), material = Enum.Material.Leather }, { collide = false })
	Kit.part(m, "LedgerPages", Vector3.new(1.3, 0.05, 0.9), cf * CFrame.new(0, 3.61, 0) * CFrame.Angles(math.rad(-20), 0, 0), L.bone, { collide = false, shadow = false })
	prompt(book, "LedgerPrompt", "Read", "The Ledger", 0.5)
	CollectionService:AddTag(book, "LedgerBook")
end

function BoutiqueRoom.build(parent: Instance): Model
	local m = Kit.model(parent, "Boutique")
	shell(m)
	counters(m)
	dressForm(m)
	mirror(m)
	ledger(m)
	return m
end

return BoutiqueRoom

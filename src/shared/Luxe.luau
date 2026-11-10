--!strict
-- Steal a Luxe: the residence, what's in it, and where (shared by the server, which builds and runs
-- it, and every screen, which draws its HUD). All positions are from the residence's origin
-- (shared/Attractions.origin("luxe")), on its ground: +Z runs from the courtyard into the house.
--
--   The courtyard     the getaway car (bank what you carry by walking up to it) and the arch home
--   The Garden Hall   wing 1: the first rooms, two guards, the easier pieces
--   The Long Gallery  wing 2: three guards along two galleries, better pieces, a brainrot
--   The Strongroom    wing 3: three sharp-eyed guards, the finest pieces and the Crown Jewel
-- The deeper the wing, the more its pieces are worth, the further its guards see and the faster
-- they run. Everything carried and not yet banked is lost if a guard catches you.

local Luxe = {}

export type Wing = { id: number, name: string, line: string, minZ: number, maxZ: number, minX: number, maxX: number, sharp: number, colour: Color3 }
export type Piece = {
	id: string,
	name: string,
	rarity: string,
	worth: number, -- in Gilt: what it adds to a Fortune when banked
	glyph: string,
	look: string, -- how it's built (server/Attractions/LuxeProps)
	wing: number,
	weight: number, -- how often it's set out in its wing (never sold: found by playing)
	curio: string?, -- banked, it's also this collectible (shared/Curios)
	gems: number?, -- banked, it also pays these Gems (within the day's cap)
}
export type Spot = { id: number, wing: number, at: Vector3, fixed: string? }

local rgb = Color3.fromRGB

Luxe.Wings = {
	{ id = 1, name = "The Garden Hall", line = "The way in. Two guards, and pieces left lying about.", minX = -60, maxX = 60, minZ = -70, maxZ = 0, sharp = 1, colour = rgb(120, 200, 140) },
	{ id = 2, name = "The Long Gallery", line = "Two long galleries of paintings and cases. Three guards.", minX = -60, maxX = 60, minZ = 0, maxZ = 70, sharp = 1.15, colour = rgb(110, 160, 240) },
	{ id = 3, name = "The Strongroom", line = "The finest things in the house, and the sharpest guards.", minX = -40, maxX = 40, minZ = 70, maxZ = 130, sharp = 1.3, colour = rgb(240, 176, 60) },
} :: { Wing }

Luxe.Pieces = {
	-- The Garden Hall
	{ id = "pocketWatch", name = "Gold Pocket Watch", rarity = "Common", worth = 220, glyph = "⌚", look = "watch", wing = 1, weight = 30 },
	{ id = "pearls", name = "Pearl Necklace", rarity = "Common", worth = 260, glyph = "📿", look = "pearls", wing = 1, weight = 30 },
	{ id = "notes", name = "A Stack of Gilt Notes", rarity = "Common", worth = 300, glyph = "💵", look = "cash", wing = 1, weight = 25 },
	{ id = "candelabra", name = "Silver Candelabra", rarity = "Uncommon", worth = 480, glyph = "🕯️", look = "candelabra", wing = 1, weight = 15 },
	-- The Long Gallery
	{ id = "goldBar", name = "Gold Bar", rarity = "Uncommon", worth = 900, glyph = "🔶", look = "goldBar", wing = 2, weight = 30 },
	{ id = "handbag", name = "Designer Handbag", rarity = "Rare", worth = 1400, glyph = "👜", look = "handbag", wing = 2, weight = 25 },
	{ id = "diamondRing", name = "Diamond Ring", rarity = "Rare", worth = 1700, glyph = "💍", look = "ring", wing = 2, weight = 22 },
	{ id = "painting", name = "Old Master Painting", rarity = "Epic", worth = 3200, glyph = "🖼️", look = "painting", wing = 2, weight = 12 },
	{ id = "ladro", name = "Ladro Lussuoso", rarity = "Epic", worth = 2500, glyph = "🦝", look = "statuette", wing = 2, weight = 8, curio = "ladroLussuoso" },
	-- The Strongroom
	{ id = "bullion", name = "Gold Bullion Stack", rarity = "Epic", worth = 4800, glyph = "🧱", look = "bullion", wing = 3, weight = 35 },
	{ id = "tiara", name = "The Duchess's Tiara", rarity = "Legendary", worth = 8500, glyph = "👑", look = "tiara", wing = 3, weight = 20, gems = 2 },
	{ id = "egg", name = "Jewelled Egg", rarity = "Legendary", worth = 9500, glyph = "🥚", look = "egg", wing = 3, weight = 18, gems = 2 },
	{ id = "gatto", name = "Gatto Gioielliere", rarity = "Legendary", worth = 7000, glyph = "🐈", look = "statuette", wing = 3, weight = 10, curio = "gattoGioielliere", gems = 2 },
	{ id = "crownJewel", name = "The Crown Jewel", rarity = "Mythic", worth = 20000, glyph = "💎", look = "crownJewel", wing = 3, weight = 0, gems = 5 },
} :: { Piece }

Luxe.byId = {} :: { [string]: Piece }
for _, p in Luxe.Pieces do
	Luxe.byId[p.id] = p
end

-- Where pieces are set out (each on its own plinth). The Crown Jewel always stands on its own, at
-- the far end of the Strongroom, and comes back more slowly than the rest.
Luxe.Spots = {
	-- The Garden Hall: round the fountain and along the walls.
	{ id = 1, wing = 1, at = Vector3.new(-44, 0, -58) },
	{ id = 2, wing = 1, at = Vector3.new(44, 0, -58) },
	{ id = 3, wing = 1, at = Vector3.new(-50, 0, -30) },
	{ id = 4, wing = 1, at = Vector3.new(50, 0, -30) },
	{ id = 5, wing = 1, at = Vector3.new(-22, 0, -12) },
	{ id = 6, wing = 1, at = Vector3.new(22, 0, -12) },
	{ id = 7, wing = 1, at = Vector3.new(-14, 0, -46) },
	{ id = 8, wing = 1, at = Vector3.new(14, 0, -46) },
	-- The Long Gallery: down both galleries.
	{ id = 9, wing = 2, at = Vector3.new(-48, 0, 14) },
	{ id = 10, wing = 2, at = Vector3.new(-20, 0, 30) },
	{ id = 11, wing = 2, at = Vector3.new(-48, 0, 46) },
	{ id = 12, wing = 2, at = Vector3.new(-20, 0, 62) },
	{ id = 13, wing = 2, at = Vector3.new(48, 0, 14) },
	{ id = 14, wing = 2, at = Vector3.new(20, 0, 30) },
	{ id = 15, wing = 2, at = Vector3.new(48, 0, 46) },
	{ id = 16, wing = 2, at = Vector3.new(20, 0, 62) },
	-- The Strongroom.
	{ id = 17, wing = 3, at = Vector3.new(-30, 0, 82) },
	{ id = 18, wing = 3, at = Vector3.new(30, 0, 82) },
	{ id = 19, wing = 3, at = Vector3.new(-30, 0, 108) },
	{ id = 20, wing = 3, at = Vector3.new(30, 0, 108) },
	{ id = 21, wing = 3, at = Vector3.new(0, 0, 120), fixed = "crownJewel" },
} :: { Spot }

-- The guards' rounds: each walks his points in order and back to the first, in his wing.
Luxe.Patrols = {
	{ wing = 1, points = { Vector3.new(-30, 0, -60), Vector3.new(-30, 0, -10), Vector3.new(-52, 0, -10), Vector3.new(-52, 0, -60) } },
	{ wing = 1, points = { Vector3.new(30, 0, -10), Vector3.new(30, 0, -60), Vector3.new(52, 0, -60), Vector3.new(52, 0, -10) } },
	{ wing = 2, points = { Vector3.new(-34, 0, 8), Vector3.new(-34, 0, 64) } },
	{ wing = 2, points = { Vector3.new(34, 0, 64), Vector3.new(34, 0, 8) } },
	{ wing = 2, points = { Vector3.new(-12, 0, 66), Vector3.new(12, 0, 66), Vector3.new(12, 0, 6), Vector3.new(-12, 0, 6) } },
	{ wing = 3, points = { Vector3.new(-18, 0, 76), Vector3.new(-18, 0, 124), Vector3.new(18, 0, 124), Vector3.new(18, 0, 76) } },
	{ wing = 3, points = { Vector3.new(0, 0, 76), Vector3.new(0, 0, 100) } },
	{ wing = 3, points = { Vector3.new(34, 0, 120), Vector3.new(-34, 0, 120) } },
} :: { { wing: number, points: { Vector3 } } }

-- The courtyard, the car and the way in and home.
Luxe.Courtyard = { minX = -56, maxX = 56, minZ = -136, maxZ = -70 }
Luxe.Car = CFrame.lookAt(Vector3.new(0, 0, -108), Vector3.new(30, 0, -108)) -- the getaway car, side on
Luxe.Bank = { minX = -16, maxX = 16, minZ = -120, maxZ = -96 } -- walk in here with the bag: banked
Luxe.Arrival = CFrame.lookAt(Vector3.new(0, 0, -126), Vector3.new(0, 0, 0))
Luxe.HomeArch = CFrame.lookAt(Vector3.new(0, 0, -133), Vector3.new(0, 0, -140)) -- walk through: home
Luxe.FrontDoor = { minX = -6, maxX = 6, z = -70 } -- the residence's front door
-- Doorways between the wings: { x from, x to, z }.
Luxe.Doors = {
	{ -40, -30, 0 },
	{ 30, 40, 0 },
	{ -5, 5, 70 },
}
Luxe.HEIGHT = 18 -- the residence's walls

-- The wing a point is in (from the origin), or nil (the courtyard and beyond).
function Luxe.wingAt(p: Vector3): number?
	for _, w in Luxe.Wings do
		if p.X >= w.minX and p.X <= w.maxX and p.Z >= w.minZ and p.Z <= w.maxZ then
			return w.id
		end
	end
	return nil
end

function Luxe.inBank(p: Vector3): boolean
	local b = Luxe.Bank
	return p.X >= b.minX and p.X <= b.maxX and p.Z >= b.minZ and p.Z <= b.maxZ
end

-- Picks a piece for a plinth in `wing` from a number in [0, 1): by weight (never the Crown Jewel,
-- which has its own plinth).
function Luxe.pick(wing: number, x: number): Piece
	local total = 0
	for _, p in Luxe.Pieces do
		if p.wing == wing then
			total += p.weight
		end
	end
	local at = x * total
	local last: Piece? = nil
	for _, p in Luxe.Pieces do
		if p.wing == wing and p.weight > 0 then
			last = p
			at -= p.weight
			if at < 0 then
				return p
			end
		end
	end
	return last :: Piece
end

-- Stride: the level reached with `points` (1 to the top), and the points to the next (nil at the top).
function Luxe.strideLevel(points: number, steps: { number }): (number, number?)
	local level = 1
	for i, need in steps do
		if points >= need then
			level = i
		end
	end
	return level, steps[level + 1]
end

return Luxe

--!strict
-- Steal a Luxe: the residence, what's in it, and where (shared by the server, which builds and runs
-- it, and every screen, which draws its HUD). All positions are from the residence's origin
-- (shared/Attractions.origin("luxe")), on its ground: +Z runs from the courtyard into the house.
--
--   The courtyard     the getaway car (bank what you carry by walking up to it) and the arch home
--   The Garden Hall   wing 1: the first rooms, two guards, the easier pieces
--   The Long Gallery  wing 2: three guards along two galleries, better pieces, a brainrot
--   The Strongroom    wing 3: three sharp-eyed guards, the finest pieces and the Crown Jewel
--                     behind a laser grid, and a loose gold bar that opens the Secret Stash
--   The Drop Room     wing 4 (Build 78): a streetwear showroom off the Garden Hall: sneakers,
--                     chains, art toys; a loft up the stairs, and the roof's helicopter out
--   The Garage        wing 5: supercars, keys and rims; the garage van is a way out too
--   The Secret Stash  wing 6: behind the Strongroom's back wall, one-of-one finds
-- Security (Build 78): every wing has cameras that sweep; a guest seen by one puts the wing on
-- Alert (its guards come looking where they were seen); seen again on Alert, a laser crossed, or the
-- Crown Jewel lifted, and the wing locks down (red light, the alarm, two more guards for a while).
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
	look: string, -- how it's built (server/Attractions/LuxeBuild)
	wing: number,
	weight: number, -- how often it's set out in its wing (never sold: found by playing)
	curio: string?, -- banked, it's also this collectible (shared/Curios)
	gems: number?, -- banked, it also pays these Gems (within the day's cap)
	size: string?, -- tiny, small, medium, large, huge: how long it takes to lift (Config luxe.hold)
	mass: number?, -- kilograms: what it adds to the bag's weight
	limited: string?, -- set out only while this holiday is open (shared/HolidayGames): Limited
	tint: Color3?, -- its colourway (sneakers, chains)
}
export type Spot = { id: number, wing: number, at: Vector3, fixed: string? }

-- The grades, lowest first: each one's colour and whether a piece wears a label over it. Limited
-- is only ever a piece set out during its holiday (never made scarce for show).
export type Rarity = { id: string, colour: Color3, label: boolean, order: number }

local rgb = Color3.fromRGB

Luxe.Rarities = {
	{ id = "Common", colour = rgb(200, 200, 205), label = false, order = 1 },
	{ id = "Uncommon", colour = rgb(110, 210, 130), label = false, order = 2 },
	{ id = "Rare", colour = rgb(90, 160, 255), label = true, order = 3 },
	{ id = "Epic", colour = rgb(190, 110, 255), label = true, order = 4 },
	{ id = "Legendary", colour = rgb(255, 190, 60), label = true, order = 5 },
	{ id = "Exclusive", colour = rgb(110, 255, 225), label = true, order = 6 },
	{ id = "Limited", colour = rgb(255, 72, 96), label = true, order = 7 },
} :: { Rarity }
Luxe.rarityOf = {} :: { [string]: Rarity }
for _, r in Luxe.Rarities do
	Luxe.rarityOf[r.id] = r
end

Luxe.Wings = {
	{ id = 1, name = "The Garden Hall", line = "The way in. Two guards, and pieces left lying about.", minX = -60, maxX = 60, minZ = -70, maxZ = 0, sharp = 1, colour = rgb(120, 200, 140) },
	{ id = 2, name = "The Long Gallery", line = "Two long galleries of paintings and cases. Three guards.", minX = -60, maxX = 60, minZ = 0, maxZ = 70, sharp = 1.15, colour = rgb(110, 160, 240) },
	{ id = 3, name = "The Strongroom", line = "The finest things in the house, and the sharpest guards.", minX = -40, maxX = 40, minZ = 70, maxZ = 130, sharp = 1.3, colour = rgb(240, 176, 60) },
	{ id = 4, name = "The Drop Room", line = "Sneakers, chains and art toys. A loft upstairs, the roof above.", minX = -124, maxX = -61, minZ = -60, maxZ = 20, sharp = 1.1, colour = rgb(255, 70, 180) },
	{ id = 5, name = "The Garage", line = "Supercars, their keys and rims. The van is a way out.", minX = 61, maxX = 132, minZ = -60, maxZ = 30, sharp = 1.2, colour = rgb(80, 220, 255) },
	{ id = 6, name = "The Secret Stash", line = "Behind the Strongroom's back wall. One-of-one finds.", minX = -16, maxX = 16, minZ = 131, maxZ = 150, sharp = 1.3, colour = rgb(110, 255, 225) },
} :: { Wing }

Luxe.Pieces = {
	-- The Garden Hall
	{ id = "pocketWatch", name = "Gold Pocket Watch", rarity = "Common", worth = 220, glyph = "⌚", look = "watch", wing = 1, weight = 30 , size = "small", mass = 0.3 },
	{ id = "pearls", name = "Pearl Necklace", rarity = "Common", worth = 260, glyph = "📿", look = "pearls", wing = 1, weight = 30 , size = "small", mass = 0.2 },
	{ id = "notes", name = "A Stack of Gilt Notes", rarity = "Common", worth = 300, glyph = "💵", look = "cash", wing = 1, weight = 25 , size = "small", mass = 0.5 },
	{ id = "candelabra", name = "Silver Candelabra", rarity = "Uncommon", worth = 480, glyph = "🕯️", look = "candelabra", wing = 1, weight = 15 , size = "medium", mass = 4 },
	-- The Long Gallery
	{ id = "goldBar", name = "Gold Bar", rarity = "Uncommon", worth = 900, glyph = "🔶", look = "goldBar", wing = 2, weight = 30 , size = "medium", mass = 12 },
	{ id = "handbag", name = "Designer Handbag", rarity = "Rare", worth = 1400, glyph = "👜", look = "handbag", wing = 2, weight = 25 , size = "medium", mass = 1.2 },
	{ id = "diamondRing", name = "Diamond Ring", rarity = "Rare", worth = 1700, glyph = "💍", look = "ring", wing = 2, weight = 22 , size = "tiny", mass = 0.05 },
	{ id = "painting", name = "Old Master Painting", rarity = "Epic", worth = 3200, glyph = "🖼️", look = "painting", wing = 2, weight = 12 , size = "large", mass = 9 },
	{ id = "ladro", name = "Ladro Lussuoso", rarity = "Epic", worth = 2500, glyph = "🦝", look = "statuette", wing = 2, weight = 8, curio = "ladroLussuoso" , size = "medium", mass = 3 },
	-- The Strongroom
	{ id = "bullion", name = "Gold Bullion Stack", rarity = "Epic", worth = 4800, glyph = "🧱", look = "bullion", wing = 3, weight = 35 , size = "huge", mass = 40 },
	{ id = "tiara", name = "The Duchess's Tiara", rarity = "Legendary", worth = 8500, glyph = "👑", look = "tiara", wing = 3, weight = 20, gems = 2 , size = "small", mass = 0.6 },
	{ id = "egg", name = "Jewelled Egg", rarity = "Legendary", worth = 9500, glyph = "🥚", look = "egg", wing = 3, weight = 18, gems = 2 , size = "small", mass = 1.2 },
	{ id = "gatto", name = "Gatto Gioielliere", rarity = "Legendary", worth = 7000, glyph = "🐈", look = "statuette", wing = 3, weight = 10, curio = "gattoGioielliere", gems = 2 , size = "medium", mass = 4 },
	{ id = "crownJewel", name = "The Crown Jewel", rarity = "Exclusive", worth = 20000, glyph = "💎", look = "crownJewel", wing = 3, weight = 0, gems = 5 , size = "medium", mass = 2.5 },
	-- The Drop Room (Build 78): streetwear and sneakers.
	{ id = "shades", name = "Designer Shades", rarity = "Common", worth = 240, glyph = "🕶️", look = "shades", wing = 4, weight = 22, size = "tiny", mass = 0.1 },
	{ id = "hiTops", name = "Retro High-Tops", rarity = "Uncommon", worth = 700, glyph = "👟", look = "sneaker", wing = 4, weight = 26, size = "small", mass = 1, tint = rgb(230, 230, 236) },
	{ id = "headphones", name = "Studio Headphones", rarity = "Uncommon", worth = 650, glyph = "🎧", look = "headphones", wing = 4, weight = 20, size = "small", mass = 0.4 },
	{ id = "grails", name = "Grail Sneakers", rarity = "Rare", worth = 1600, glyph = "👟", look = "sneaker", wing = 4, weight = 18, size = "small", mass = 1, tint = rgb(255, 60, 90) },
	{ id = "puffer", name = "Designer Puffer", rarity = "Rare", worth = 1300, glyph = "🧥", look = "puffer", wing = 4, weight = 14, size = "medium", mass = 1.8 },
	{ id = "deck", name = "Signed Skate Deck", rarity = "Rare", worth = 1500, glyph = "🛹", look = "deck", wing = 4, weight = 12, size = "large", mass = 2.5 },
	{ id = "chain", name = "Iced Cuban Chain", rarity = "Epic", worth = 3600, glyph = "⛓️", look = "chain", wing = 4, weight = 10, size = "small", mass = 0.8, tint = rgb(220, 235, 255) },
	{ id = "artToy", name = "Art Toy, Edition of 50", rarity = "Epic", worth = 2800, glyph = "🧸", look = "artToy", wing = 4, weight = 10, size = "medium", mass = 2 },
	{ id = "record", name = "Platinum Record", rarity = "Legendary", worth = 7500, glyph = "💿", look = "record", wing = 4, weight = 4, size = "medium", mass = 1.5, gems = 2 },
	-- The Garage: supercars, their keys, their rims.
	{ id = "toolchest", name = "Chrome Tool Chest", rarity = "Uncommon", worth = 900, glyph = "🧰", look = "toolchest", wing = 5, weight = 18, size = "huge", mass = 60 },
	{ id = "helmet", name = "Racing Helmet", rarity = "Rare", worth = 1800, glyph = "⛑️", look = "helmet", wing = 5, weight = 24, size = "medium", mass = 1.5 },
	{ id = "rims", name = "Forged Carbon Rims", rarity = "Epic", worth = 4200, glyph = "⚙️", look = "rims", wing = 5, weight = 20, size = "large", mass = 14 },
	{ id = "chrono", name = "Iced Chronograph", rarity = "Epic", worth = 5200, glyph = "⌚", look = "chrono", wing = 5, weight = 16, size = "tiny", mass = 0.2 },
	{ id = "keyFob", name = "Supercar Key", rarity = "Legendary", worth = 9000, glyph = "🔑", look = "keyFob", wing = 5, weight = 8, size = "tiny", mass = 0.1, gems = 2 },
	-- The Secret Stash: one-of-one finds (Exclusive), or a bag of cash.
	{ id = "stashCash", name = "A Duffel of Cash", rarity = "Legendary", worth = 8000, glyph = "💰", look = "duffel", wing = 6, weight = 70, size = "medium", mass = 6, gems = 1 },
	{ id = "goldGrail", name = "The Golden Grail", rarity = "Exclusive", worth = 25000, glyph = "👟", look = "sneaker", wing = 6, weight = 15, size = "small", mass = 1.5, gems = 5, tint = rgb(255, 196, 60) },
	{ id = "blackChain", name = "Black Diamond Chain", rarity = "Exclusive", worth = 18000, glyph = "⛓️", look = "chain", wing = 6, weight = 15, size = "small", mass = 0.9, gems = 4, tint = rgb(30, 30, 36) },
	-- Limited: set out in the Drop Room only while their holiday is open.
	{ id = "phantomMask", name = "Phantom Mask", rarity = "Limited", worth = 5000, glyph = "🎭", look = "mask", wing = 4, weight = 0, size = "small", mass = 0.4, limited = "halloween", gems = 2 },
	{ id = "harvestChain", name = "Harvest Gold Chain", rarity = "Limited", worth = 5000, glyph = "⛓️", look = "chain", wing = 4, weight = 0, size = "small", mass = 0.8, limited = "thanksgiving", gems = 2, tint = rgb(230, 150, 60) },
	{ id = "frostGrail", name = "Frost Grail Sneakers", rarity = "Limited", worth = 6000, glyph = "👟", look = "sneaker", wing = 4, weight = 0, size = "small", mass = 1, limited = "christmas", gems = 2, tint = rgb(170, 220, 255) },
	{ id = "cloverKicks", name = "Four-Leaf Kicks", rarity = "Limited", worth = 5000, glyph = "👟", look = "sneaker", wing = 4, weight = 0, size = "small", mass = 1, limited = "stPatrick", gems = 2, tint = rgb(70, 200, 110) },
	{ id = "chromeEgg", name = "Chrome Egg", rarity = "Limited", worth = 5000, glyph = "🥚", look = "egg", wing = 4, weight = 0, size = "small", mass = 1.2, limited = "easter", gems = 2 },
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
	-- The Drop Room: the floor, under the loft, and up on the loft (10 studs up).
	{ id = 22, wing = 4, at = Vector3.new(-70, 0, -50) },
	{ id = 23, wing = 4, at = Vector3.new(-84, 0, -50) },
	{ id = 24, wing = 4, at = Vector3.new(-70, 0, 6) },
	{ id = 25, wing = 4, at = Vector3.new(-84, 0, 6) },
	{ id = 26, wing = 4, at = Vector3.new(-112, 0, -40) },
	{ id = 27, wing = 4, at = Vector3.new(-112, 0, 2) },
	{ id = 28, wing = 4, at = Vector3.new(-114, 10, -20) },
	{ id = 29, wing = 4, at = Vector3.new(-114, 10, 4) },
	{ id = 30, wing = 4, at = Vector3.new(-114, 10, 14), fixed = "record" },
	-- The Garage.
	{ id = 31, wing = 5, at = Vector3.new(78, 0, 18) },
	{ id = 32, wing = 5, at = Vector3.new(96, 0, 18) },
	{ id = 33, wing = 5, at = Vector3.new(114, 0, 18) },
	{ id = 34, wing = 5, at = Vector3.new(122, 0, 8) },
	{ id = 35, wing = 5, at = Vector3.new(84, 0, -46) },
	{ id = 36, wing = 5, at = Vector3.new(98, 0, -20) },
	-- The Secret Stash.
	{ id = 37, wing = 6, at = Vector3.new(-9, 0, 142) },
	{ id = 38, wing = 6, at = Vector3.new(0, 0, 146) },
	{ id = 39, wing = 6, at = Vector3.new(9, 0, 142) },
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
	{ wing = 4, points = { Vector3.new(-77, 0, -56), Vector3.new(-77, 0, 16), Vector3.new(-104, 0, 16), Vector3.new(-104, 0, -56) } },
	{ wing = 4, points = { Vector3.new(-106, 10, -56), Vector3.new(-106, 10, 16) } },
	{ wing = 5, points = { Vector3.new(70, 0, -36), Vector3.new(70, 0, 26), Vector3.new(128, 0, 26), Vector3.new(128, 0, -36) } },
	{ wing = 5, points = { Vector3.new(86, 0, -28), Vector3.new(122, 0, -28) } },
} :: { { wing: number, points: { Vector3 } } }

-- The cameras: where each hangs, which way it faces (degrees: 0 is +Z, 90 is +X), how far it sweeps
-- either side, and how long one sweep takes. Each sees `Config luxe.cameraRange` studs, within
-- `cameraAngle` degrees of where it points, and only what nothing stands in front of.
export type Camera = { wing: number, at: Vector3, yaw: number, sweep: number, period: number }
Luxe.Cameras = {
	{ wing = 1, at = Vector3.new(-57, 12, -67), yaw = 45, sweep = 35, period = 7 },
	{ wing = 1, at = Vector3.new(57, 12, -3), yaw = 225, sweep = 35, period = 8 },
	{ wing = 2, at = Vector3.new(-57, 12, 67), yaw = 135, sweep = 30, period = 7.5 },
	{ wing = 2, at = Vector3.new(57, 12, 3), yaw = 315, sweep = 30, period = 6.5 },
	{ wing = 3, at = Vector3.new(-37, 12, 73), yaw = 45, sweep = 30, period = 6 },
	{ wing = 3, at = Vector3.new(37, 12, 127), yaw = 225, sweep = 30, period = 6 },
	{ wing = 4, at = Vector3.new(-63, 9, -57), yaw = 315, sweep = 35, period = 7 },
	{ wing = 4, at = Vector3.new(-121, 16, 17), yaw = 135, sweep = 30, period = 8 },
	{ wing = 5, at = Vector3.new(63, 12, 27), yaw = 135, sweep = 35, period = 7 },
	{ wing = 5, at = Vector3.new(129, 12, -57), yaw = 315, sweep = 35, period = 7.5 },
	{ wing = 6, at = Vector3.new(-15, 8, 149), yaw = 135, sweep = 25, period = 5 },
} :: { Camera }

-- The Strongroom's laser grid, across the whole room before the Crown Jewel: each beam is on for
-- part of its cycle (staggered), and crossing a lit one locks the Strongroom down.
export type Laser = { z: number, minX: number, maxX: number, y: number, phase: number }
Luxe.Lasers = {
	{ z = 104, minX = -39, maxX = 39, y = 2.6, phase = 0 },
	{ z = 107, minX = -39, maxX = 39, y = 2.6, phase = 1.3 },
	{ z = 110, minX = -39, maxX = 39, y = 2.6, phase = 2.6 },
} :: { Laser }
Luxe.LASER_CYCLE = 4 -- seconds
Luxe.LASER_ON = 0.55 -- of each cycle

-- The Secret Stash's door: a steel panel in the Strongroom's back wall, opened for a while by the
-- loose gold bar on the last stack on the right.
Luxe.Stash = { door = { minX = -4, maxX = 4, z = 130 }, lever = Vector3.new(36, 0, 124), openFor = 45 }

-- The ways out: walk in here with the bag and it's banked. The car (the front), the garage van
-- (the side, close to the Garage and the Strongroom), and the helicopter on the Drop Room's roof
-- (a climb, and a clean getaway: a little more for it).
export type Bank = { id: string, name: string, minX: number, maxX: number, minZ: number, maxZ: number, minY: number?, bonus: number }
Luxe.Banks = {
	{ id = "car", name = "the getaway car", minX = -16, maxX = 16, minZ = -120, maxZ = -96, bonus = 0 },
	{ id = "van", name = "the garage van", minX = 104, maxX = 128, minZ = -58, maxZ = -44, bonus = 0.05 },
	{ id = "heli", name = "the helicopter", minX = -112, maxX = -84, minZ = -40, maxZ = -12, minY = 17, bonus = 0.1 },
} :: { Bank }

-- A run's side jobs: three are given at the start of each, at random; each pays its Gilt the moment
-- it's done (once a run).
export type Objective = { id: string, line: string, gilt: number }
Luxe.Objectives = {
	{ id = "bankRare", line = "Bank a Rare piece or better", gilt = 600 },
	{ id = "dropRoom", line = "Lift something in the Drop Room", gilt = 400 },
	{ id = "loft", line = "Lift something on the Drop Room's loft", gilt = 700 },
	{ id = "garage", line = "Lift something in the Garage", gilt = 500 },
	{ id = "van", line = "Get away in the garage van", gilt = 600 },
	{ id = "heli", line = "Get away by helicopter, from the roof", gilt = 1200 },
	{ id = "stash", line = "Find the Secret Stash", gilt = 1500 },
	{ id = "unseen", line = "Bank 3 pieces in one trip, never spotted", gilt = 1000 },
	{ id = "crown", line = "Lift the Crown Jewel", gilt = 2000 },
	{ id = "big", line = "Bank a haul worth 6,000 or more", gilt = 900 },
} :: { Objective }
Luxe.objectiveOf = {} :: { [string]: Objective }
for _, o in Luxe.Objectives do
	Luxe.objectiveOf[o.id] = o
end

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
-- The side doors (in the Garden Hall's west and east walls): { z from, z to, x }.
Luxe.SideDoors = {
	{ -30, -22, -60 }, -- to the Drop Room
	{ -30, -22, 60 }, -- to the Garage
}
-- The Drop Room's stairs: up to the loft (10 studs), and from the loft to the roof.
Luxe.LOFT = 10
Luxe.ROOF = 19
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

-- The way out a guest stands in (the car, the van, the helicopter), or nil.
function Luxe.bankAt(p: Vector3): Bank?
	for _, b in Luxe.Banks do
		if p.X >= b.minX and p.X <= b.maxX and p.Z >= b.minZ and p.Z <= b.maxZ and p.Y >= (b.minY or -math.huge) then
			return b
		end
	end
	return nil
end
function Luxe.inBank(p: Vector3): boolean
	return Luxe.bankAt(p) ~= nil
end

-- How long a piece takes to lift (seconds), from `distance` studs away, with Quick Hands' `hands`
-- (1 = none): its size, its grade, its worth, and how far there is to reach (Config luxe.hold).
-- Every screen works it out the same way; the server checks a guest stood within reach that long.
function Luxe.holdFor(piece: Piece, distance: number, hands: number, c: { [string]: any }): number
	local size = (c.size :: any)[piece.size or "small"] or 0.45
	local grade = (c.rarity :: any)[piece.rarity] or 0
	local worth = math.min(c.valueMost, piece.worth / c.valuePer)
	local reach = math.max(0, distance - c.near) * c.perStud
	return math.clamp((size + grade + worth + reach) * (hands or 1), c.least, c.most)
end

-- Where a camera points at time `t` (a unit vector on the floor's plane, sweeping to and fro).
function Luxe.cameraLook(cam: Camera, t: number): Vector3
	local yaw = math.rad(cam.yaw + cam.sweep * math.sin(t / cam.period * math.pi * 2))
	return Vector3.new(math.sin(yaw), 0, math.cos(yaw))
end

-- Whether a laser beam is lit at time `t`.
function Luxe.laserOn(l: Laser, t: number): boolean
	local at = (t + l.phase) % Luxe.LASER_CYCLE
	return at < Luxe.LASER_CYCLE * Luxe.LASER_ON
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

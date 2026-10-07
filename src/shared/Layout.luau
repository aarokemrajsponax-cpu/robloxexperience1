--!strict
-- Where everything in the Maison sits, in studs. The server builds from these numbers and the
-- client uses the same ones for zones, cameras and doors, so the two can never disagree.
-- +Z points from the street into the house. Street ground is y = 0; the house floor is y = 3.

local Layout = {}

Layout.FLOOR = 3

export type Box = { min: Vector3, max: Vector3 }

local function box(minX: number, minY: number, minZ: number, maxX: number, maxY: number, maxZ: number): Box
	return { min = Vector3.new(minX, minY, minZ), max = Vector3.new(maxX, maxY, maxZ) }
end

Layout.Street = {
	zone = box(-80, -5, -70, 80, 60, -10),
	roadZ = { -64, -34 },
	pavementZ = { -34, -10 },
	kerbZ = -34,
	facadeZ = -10,
	houseHalfWidth = 20,
	spawn = CFrame.lookAt(Vector3.new(0, 3, -28), Vector3.new(0, 3, 0)),
	steps = 3, -- each one stud high
	stepDepth = 1.5,
	lampXs = { -15, 15 },
	lampZ = -31,
	titleShot = {
		from = CFrame.lookAt(Vector3.new(-30, 9, -44), Vector3.new(-6, 12, -10)),
		to = CFrame.lookAt(Vector3.new(26, 11, -42), Vector3.new(4, 13, -10)),
		seconds = 26,
	},
}

Layout.Door = {
	centre = Vector3.new(0, 3, -9),
	width = 9,
	height = 13,
}

Layout.Foyer = {
	zone = box(-30, 0, -8, 30, 32, 42),
	minX = -30, maxX = 30, minZ = -8, maxZ = 42, height = 28,
	spawn = CFrame.lookAt(Vector3.new(-20, 6, 12), Vector3.new(0, 6, 12)),
	lectern = CFrame.lookAt(Vector3.new(9, 3, 1.5), Vector3.new(9, 3, -10)),
	conciergeHome = CFrame.lookAt(Vector3.new(9, 3, 4.2), Vector3.new(9, 3, -10)),
	chandelier = Vector3.new(0, 27, 16),
	piano = CFrame.lookAt(Vector3.new(18, 3, 20), Vector3.new(0, 3, 20)),
	-- The Pianist on the bench, facing the keys (the bench is 5 studs in front of the piano).
	pianist = CFrame.lookAt(Vector3.new(18, 3, 20), Vector3.new(0, 3, 20)) * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0),
	pianoBenchTop = 2.25, -- above the floor
	-- Where a guest sits to play: on the bench, facing the keys.
	pianoSeat = CFrame.lookAt(Vector3.new(18, 3, 20), Vector3.new(0, 3, 20)) * CFrame.new(0, 2.35, -5) * CFrame.Angles(0, math.pi, 0),
	tonightBoard = CFrame.lookAt(Vector3.new(-29.4, 13, 17), Vector3.new(0, 13, 17)),
	wallOfNames = CFrame.lookAt(Vector3.new(-19, 14, 41.4), Vector3.new(-19, 14, 0)),
	livreDOr = CFrame.lookAt(Vector3.new(-19, 3, 36), Vector3.new(-19, 3, 0)),
	stair = { x = 8, fromZ = 24, toZ = 38, topY = 17 },
	stairRopeZ = 22.5,
	-- The Soirée's countdown board, on a stand left of the stair, facing guests as they come in.
	soireeBoard = CFrame.lookAt(Vector3.new(-5, 3, 23), Vector3.new(-12, 3, 12)),
	boutiqueDoor = CFrame.lookAt(Vector3.new(19, 3, 41.5), Vector3.new(19, 3, 0)),
}

-- The Boutique: a narrow mirrored shop through the Foyer's back wall, under the Club Floor.
Layout.Boutique = {
	zone = box(12, 0, 44, 30, 17, 62),
	minX = 12, maxX = 30, minZ = 44, maxZ = 62, height = 14,
	-- The Tailor behind the long counter at the far end, facing the door.
	tailorHome = CFrame.lookAt(Vector3.new(21, 3, 58.5), Vector3.new(21, 3, 40)),
	counter = CFrame.new(21, 3, 56),
	mirror = CFrame.lookAt(Vector3.new(13.2, 3, 51), Vector3.new(30, 3, 51)),
	dressForm = CFrame.lookAt(Vector3.new(27, 3, 49), Vector3.new(12, 3, 49)),
	ledger = CFrame.lookAt(Vector3.new(15.5, 3, 46.8), Vector3.new(21, 3, 52)),
	arrival = Vector3.new(19, 3, 47),
}

-- The Vault: through the Foyer's back wall, left of the stair. Glass cabinets of everything a
-- guest has filed, a centre cabinet for Mythics, and the Archivist who keeps the Register.
Layout.Vault = {
	zone = box(-22, 0, 44, 6, 17, 62),
	minX = -22, maxX = 6, minZ = 44, maxZ = 62, height = 13,
	door = Vector3.new(-3, 3, 42), -- the doorway in the Foyer's back wall
	doorWidth = 7,
	archivistHome = CFrame.lookAt(Vector3.new(3, 3, 49), Vector3.new(-8, 3, 49)),
	desk = CFrame.lookAt(Vector3.new(1, 3, 49), Vector3.new(-8, 3, 49)),
	centre = Vector3.new(-8, 3, 53),
	arrival = Vector3.new(-3, 3, 47),
}

-- The Vault's own door: a steel vault door in the Foyer's back wall, hinged on its west jamb and
-- swinging into the Vault. It opens as a guest comes near and shuts behind them.
Layout.VaultDoor = {
	hinge = Vector3.new(-6.5, 3, 43.6), -- the hinge line's foot (the Vault side of the west jamb)
	width = 7,
	height = 9.9,
	thickness = 1.2,
	reach = 9, -- studs from the doorway at which it opens
	seconds = 1.6, -- how long it takes to swing
}

-- The lift between the Suite and the Vault: brass doors on the Suite gallery's north wall and on
-- the Vault's south wall. `face`: the wall face the doors stand on; `out`: the way out of the car.
Layout.Lift = {
	suite = { centre = Vector3.new(-33.6, 22, 56.5), out = Vector3.new(0, 0, -1), name = "your Suite" },
	vault = { centre = Vector3.new(-15.5, 3, 44), out = Vector3.new(0, 0, 1), name = "the Vault" },
	width = 3.6,
	height = 8,
	ride = 2.2, -- seconds between the floors
}

-- The four room doors, as seen from the Foyer. `facing` points into the Foyer.
Layout.RoomDoors = {
	-- `approach`: clear points across the Foyer toward each door (around the piano and lectern).
	salon = { centre = Vector3.new(-30, 3, 4), facing = Vector3.new(1, 0, 0), open = true, gated = false, approach = { Vector3.new(-12, 3, 8) } },
	velvet = { centre = Vector3.new(-30, 3, 35), facing = Vector3.new(1, 0, 0), open = true, gated = false, approach = { Vector3.new(-4, 3, 14), Vector3.new(-14, 3, 24) } },
	-- The Midnight Room's door opens only for guests who have earned it (see the gate).
	midnight = { centre = Vector3.new(30, 3, 4), facing = Vector3.new(-1, 0, 0), open = false, gated = true, approach = { Vector3.new(4, 3, 8), Vector3.new(16, 3, 7) } },
	obsidian = { centre = Vector3.new(30, 3, 35), facing = Vector3.new(-1, 0, 0), open = true, gated = false, approach = { Vector3.new(4, 3, 12), Vector3.new(26, 3, 12), Vector3.new(26, 3, 28) } },
}
Layout.RoomDoorWidth = 8
Layout.RoomDoorHeight = 12

Layout.Salon = {
	zone = box(-80, 0, -6, -32, 24, 28),
	minX = -80, maxX = -32, minZ = -6, maxZ = 28, height = 18,
	-- Where the Concierge stops after walking a guest in.
	arrival = Vector3.new(-34.5, 3, 4),
	-- Table centres. Guests sit on the -Z side and face +Z, toward the fire.
	tables = {
		Vector3.new(-42, 3, 4),
		Vector3.new(-56, 3, 4),
		Vector3.new(-70, 3, 4),
		Vector3.new(-42, 3, 18.5),
		Vector3.new(-56, 3, 18.5),
		Vector3.new(-70, 3, 18.5),
	},
	fireplace = CFrame.lookAt(Vector3.new(-56, 3, 27.4), Vector3.new(-56, 3, 0)),
}

Layout.Velvet = {
	zone = box(-80, 0, 30, -32, 24, 62),
	minX = -80, maxX = -32, minZ = 30, maxZ = 62, height = 18,
	arrival = Vector3.new(-34.5, 3, 35),
	tables = {
		Vector3.new(-42, 3, 38.5),
		Vector3.new(-56, 3, 38.5),
		Vector3.new(-70, 3, 38.5),
		Vector3.new(-42, 3, 53),
		Vector3.new(-56, 3, 53),
		Vector3.new(-70, 3, 53),
	},
}

Layout.Obsidian = {
	zone = box(32, 0, 30, 80, 24, 62),
	minX = 32, maxX = 80, minZ = 30, maxZ = 62, height = 18,
	arrival = Vector3.new(34.5, 3, 35),
	tables = {
		Vector3.new(42, 3, 38.5),
		Vector3.new(56, 3, 38.5),
		Vector3.new(70, 3, 38.5),
		Vector3.new(42, 3, 53),
		Vector3.new(56, 3, 53),
		Vector3.new(70, 3, 53),
	},
}

Layout.Midnight = {
	zone = box(32, 0, -6, 80, 24, 28),
	minX = 32, maxX = 80, minZ = -6, maxZ = 28, height = 18,
	arrival = Vector3.new(34.5, 3, 4),
	tables = {
		Vector3.new(42, 3, 4),
		Vector3.new(56, 3, 4),
		Vector3.new(70, 3, 4),
		Vector3.new(42, 3, 18.5),
		Vector3.new(56, 3, 18.5),
		Vector3.new(70, 3, 18.5),
	},
	window = Vector3.new(80, 13, 11), -- the round window in the far wall
}

-- The Club Floor, up the Grand Stair: a gallery hall, and the Library off it.
Layout.CLUB = Layout.FLOOR + 17

Layout.Club = {
	zone = box(-20, 18, 44, 24, 36, 66),
	minX = -20, maxX = 24, minZ = 44, maxZ = 66, height = 14,
	libraryDoor = Vector3.new(-14, 20, 66),
	ballroomDoor = Vector3.new(12, 20, 66),
	doorWidth = 8,
	doorHeight = 11,
}

-- The Terrace (§3): the Obsidian Room's roof, through French doors in the Club hall's east wall
-- and two steps up. Open every evening of the year, with its bar.
Layout.Terrace = {
	zone = box(26, 21.5, 30, 82, 44, 64), -- above the Obsidian Room's ceiling
	minX = 30, maxX = 80, minZ = 30, maxZ = 62,
	floorY = 22, -- the top of the Obsidian Room's ceiling
	door = Vector3.new(25, 20, 54), -- in the Club hall's east wall (x 24..26)
	doorWidth = 6,
	doorHeight = 10,
	arrival = Vector3.new(34, 22, 54),
	bar = Vector3.new(55, 22, 57), -- the bar, under its pergola on the north side, facing south
}

-- Your Suite (§3): a penthouse on the roofs of the Velvet Room and the Salon, through a door in
-- the Club hall's west wall and down a gallery. The drawing room; the bedroom, the bath and
-- spa, and the kitchen beyond it; out on the roof, the terrace with its pool, the screening
-- room and the gym; and two more rooms (the Dressing Room and the Study) that open with the Gold
-- Key. Every spot's frame faces the way its piece faces (CFrame.lookAt(spot, whatItFaces)).
local function facing(x: number, y: number, z: number, tx: number, tz: number): CFrame
	return CFrame.lookAt(Vector3.new(x, y, z), Vector3.new(tx, y, tz))
end
Layout.Suite = {
	zone = box(-79, 21.5, -8, -32, 46, 63), -- above the Velvet Room's and the Salon's ceilings
	galleryZone = box(-36, 21.5, 51, -22, 37, 57), -- the gallery from the Club hall
	floorY = 22,
	height = 15, -- tall rooms: the Suite should feel like the finest floor in the house
	main = { minX = -62, maxX = -36, minZ = 40, maxZ = 60 },
	dressing = { minX = -76, maxX = -62, minZ = 50, maxZ = 60, door = Vector3.new(-62, 22, 55) },
	study = { minX = -76, maxX = -62, minZ = 40, maxZ = 50, door = Vector3.new(-62, 22, 45) },
	bedroom = { minX = -61.5, maxX = -44.5, minZ = 24, maxZ = 39, door = Vector3.new(-47, 22, 39.5), terraceDoor = Vector3.new(-47, 22, 23.5) },
	spa = { minX = -77, maxX = -62.5, minZ = 24, maxZ = 39, door = Vector3.new(-62, 22, 27.5) },
	kitchen = { minX = -43.5, maxX = -33, minZ = 24, maxZ = 39, terraceDoor = Vector3.new(-38, 22, 23.5) },
	screening = { minX = -77, maxX = -56.5, minZ = 7.5, maxZ = 23, door = Vector3.new(-56, 22, 19.5) },
	gym = { minX = -77, maxX = -62.5, minZ = -6, maxZ = 7, door = Vector3.new(-62, 22, 2.5) },
	terrace = { minX = -61.5, maxX = -33, minZ = -6, maxZ = 23 },
	innerDoorWidth = 4,
	innerDoorHeight = 9,
	door = Vector3.new(-21, 20, 54), -- in the Club hall's west wall (x -22..-20)
	doorWidth = 5,
	doorHeight = 10,
	arrival = Vector3.new(-39, 22, 54),
	spots = {
		-- The drawing room: the fire on the north wall, the sofa facing it.
		sofa = facing(-55, 22, 45.6, -55, 60),
		chair = facing(-46.4, 22, 50.6, -70, 50.6),
		rug = facing(-55, 22, 50.4, -55, 60),
		coffeeTable = facing(-55, 22, 50.6, -55, 60),
		lamp = facing(-50.4, 22, 47.4, -50.4, 30),
		painting = facing(-55, 31.5, 59.6, -55, 40),
		bar = facing(-57.4, 22, 41.2, -57.4, 60),
		shelf = facing(-46.6, 22, 59.2, -46.6, 40),
		chandelier = CFrame.new(-51.2, 37, 47.5), -- in a coffer of the ceiling
		plant = facing(-60.2, 22, 58.6, -50, 50),
		display = facing(-39.6, 22, 41.0, -39.6, 60),
		piano = facing(-41, 22, 45.4, -70, 45.4),
		-- The gallery to it.
		galleryArtS = facing(-29, 27.2, 51.62, -29, 60),
		galleryArtN = facing(-26.6, 27.2, 56.38, -26.6, 40), -- (east of the lift)
		-- The bedroom: the bed's head on the north wall, the television facing it.
		bed = facing(-55.6, 22, 34.1, -55.6, 0),
		nightstands = facing(-55.6, 22, 37.6, -55.6, 0),
		bedRug = facing(-55.6, 22, 31.4, -55.6, 0),
		bedBench = facing(-55.6, 22, 28.5, -55.6, 0),
		bedTv = facing(-55.6, 22, 24.9, -55.6, 40),
		dresser = facing(-45.3, 22, 31.5, -70, 31.5),
		-- The bath and spa.
		bathtub = facing(-66.8, 22, 33.4, -66.8, 0),
		shower = facing(-74.4, 22, 36.6, -74.4, 0),
		vanity = facing(-66.4, 22, 38.0, -66.4, 0),
		sauna = facing(-73.6, 22, 28.0, -50, 28.0),
		spaPlant = facing(-63.4, 22, 33.0, -80, 33.0),
		-- The kitchen: the run on the east wall, the island before it.
		kitchen = facing(-37.6, 22, 33.0, -60, 33.0),
		-- The screening room: the screen on the west wall.
		screen = facing(-75.2, 22, 15.2, -50, 15.2),
		recliners = facing(-66.2, 22, 15.2, -90, 15.2),
		gaming = facing(-62.2, 22, 21.7, -62.2, 0),
		arcade = facing(-58.1, 22, 9.4, -58.1, 30),
		arcade2 = facing(-61.1, 22, 9.4, -61.1, 30),
		popcorn = facing(-57.6, 22, 14.6, -80, 14.6),
		-- The gym, glass on two sides.
		treadmill = facing(-75, 22, 0.6, -75, -20),
		bike = facing(-71.4, 22, 0.4, -71.4, -20),
		weights = facing(-72, 22, 6.2, -72, -20),
		massage = facing(-66.6, 22, 0.8, -66.6, -20),
		punchbag = facing(-66, 22, -3.6, -90, -3.6),
		-- The terrace: the pool along the south edge, its glass toward the house.
		pool = facing(-45, 22, -0.7, -45, 40),
		hottub = facing(-37.6, 22, 9.6, -60, 9.6),
		loungers = facing(-50.6, 22, 9.8, -50.6, -20),
		firepit = facing(-44.4, 22, 18.4, -44.4, 40),
		garden = facing(-34.4, 22, 18.6, -60, 18.6),
		statue = facing(-58.6, 22, -2.6, -40, -2.6),
		-- The Gold Key rooms.
		mirror = facing(-75.4, 22, 55, -60, 55),
		chaise = facing(-69, 22, 58.2, -69, 40),
		desk = facing(-71, 22, 45, -60, 45),
		globe = facing(-66, 22, 41.8, -66, 60),
	} :: { [string]: CFrame },
	furnish = facing(-34.6, 22, 52.6, -34.6, 60), -- the bell to furnish, in the gallery by the door
	wardrobe = facing(-60.4, 22, 36.4, -40, 36.4), -- your looks hang here (the bedroom)
}

Layout.Library = {
	zone = box(-36, 18, 68, 2, 40, 100),
	minX = -36, maxX = 2, minZ = 68, maxZ = 100, height = 16, -- behind the hall's north wall (z 66..68)
	arrival = Vector3.new(-14, 20, 70),
	-- Each duel is a long table: two halves end to end, the guests at opposite ends.
	duels = {
		{ id = "library-1", centre = Vector3.new(-25, 20, 83) },
		{ id = "library-2", centre = Vector3.new(-9, 20, 83) },
	},
}

-- The Ballroom, through the Club hall's right-hand door: twenty tables in a ring around a
-- marble floor, each under its own lamp, and the Gallery above the entrance for watching.
Layout.Ballroom = {
	zone = box(4, 18, 68, 118, 52, 182),
	minX = 4, maxX = 118, minZ = 68, maxZ = 182, height = 30,
	centre = Vector3.new(61, 20, 125),
	-- Wide enough that two neighbouring tables leave a walkable gap at their inner corners.
	radius = 47,
	arrival = Vector3.new(12, 20, 72),
	-- The Gallery: a balcony along the south wall, reached by a stair along the west wall.
	gallery = { minX = 4, maxX = 118, minZ = 68, maxZ = 76, floorY = 32 },
	galleryArrival = Vector3.new(61, 32, 72.5),
	stair = { x0 = 5, x1 = 11, bottomZ = 100, topZ = 76, steps = 12 },
	-- Where the camera watches from (the Gallery rail, looking into the ring).
	galleryView = CFrame.lookAt(Vector3.new(61, 40, 73), Vector3.new(61, 22, 125)),
	board = CFrame.lookAt(Vector3.new(61, 28, 76.3), Vector3.new(61, 28, 125)),
}

-- Table `i` of the Ballroom's ring (1 to 20): its centre, facing the middle of the room.
function Layout.ballroomFrame(i: number, count: number?): CFrame
	local n = count or 20
	local B = Layout.Ballroom
	local angle = -math.pi / 2 + (i - 1) / n * math.pi * 2
	local centre = B.centre + Vector3.new(math.cos(angle) * B.radius, 0, math.sin(angle) * B.radius)
	return Layout.tableFrame(centre, (B.centre - centre).Unit)
end

-- The two halves of a duel table: side "a" faces +Z, side "b" faces -Z, cases meeting in the middle.
function Layout.duelFrames(centre: Vector3): (CFrame, CFrame)
	local half = Layout.Table.depth / 2
	return Layout.tableFrame(centre - Vector3.new(0, 0, half), Vector3.new(0, 0, 1)),
		Layout.tableFrame(centre + Vector3.new(0, 0, half), Vector3.new(0, 0, -1))
end

-- Every doorway through a wall, for the world's checks. Walls are two studs thick and each room's
-- floor stops at its own wall, so where `sill` is set the builder lays a marble sill across the
-- wall's thickness (`wall`: where the wall stands along `axis`, the way you walk through) and the
-- floor runs on through. The others have their own floor through the wall (a landing, a step, a
-- corridor).
-- `height` is the clear height a guest walks through; `rise`, how far steps climb within it.
export type Doorway = { name: string, centre: Vector3, axis: "x" | "z", width: number, height: number, floorY: number, wall: { number }?, sill: boolean, reach: number?, rise: number? }
Layout.Doorways = {
	-- (The front steps fall away outside, so only the threshold itself is looked at; the fanlight
	-- glass above head height is part of the doors.)
	{ name = "the front door", centre = Layout.Door.centre, axis = "z", width = Layout.Door.width, height = 9, floorY = Layout.FLOOR, sill = false, reach = 1.5 },
	{ name = "the Salon door", centre = Layout.RoomDoors.salon.centre, axis = "x", width = Layout.RoomDoorWidth, height = Layout.RoomDoorHeight, floorY = Layout.FLOOR, wall = { -32, -30 }, sill = true },
	{ name = "the Velvet Room door", centre = Layout.RoomDoors.velvet.centre, axis = "x", width = Layout.RoomDoorWidth, height = Layout.RoomDoorHeight, floorY = Layout.FLOOR, wall = { -32, -30 }, sill = true },
	{ name = "the Midnight Room door", centre = Layout.RoomDoors.midnight.centre, axis = "x", width = Layout.RoomDoorWidth, height = Layout.RoomDoorHeight, floorY = Layout.FLOOR, wall = { 30, 32 }, sill = true },
	{ name = "the Obsidian Room door", centre = Layout.RoomDoors.obsidian.centre, axis = "x", width = Layout.RoomDoorWidth, height = Layout.RoomDoorHeight, floorY = Layout.FLOOR, wall = { 30, 32 }, sill = true },
	{ name = "the Vault door", centre = Layout.Vault.door, axis = "z", width = Layout.Vault.doorWidth, height = 10, floorY = Layout.FLOOR, wall = { 42, 44 }, sill = true },
	{ name = "the Boutique door", centre = Vector3.new(Layout.Foyer.boutiqueDoor.Position.X, Layout.FLOOR, 43), axis = "z", width = 8, height = 10, floorY = Layout.FLOOR, wall = { 42, 44 }, sill = true },
	{ name = "the Library door", centre = Layout.Club.libraryDoor, axis = "z", width = Layout.Club.doorWidth, height = Layout.Club.doorHeight, floorY = Layout.CLUB, wall = { 66, 68 }, sill = true },
	{ name = "the Ballroom door", centre = Layout.Club.ballroomDoor, axis = "z", width = Layout.Club.doorWidth, height = Layout.Club.doorHeight, floorY = Layout.CLUB, wall = { 66, 68 }, sill = true },
	{ name = "the landing door at the top of the stair", centre = Vector3.new(Layout.Foyer.stair.x, Layout.CLUB, 43), axis = "z", width = 8, height = 10, floorY = Layout.CLUB, sill = false },
	{ name = "the Suite door", centre = Layout.Suite.door, axis = "x", width = Layout.Suite.doorWidth, height = Layout.Suite.doorHeight, floorY = Layout.CLUB, sill = false, rise = 2 },
	{ name = "the Terrace doors", centre = Layout.Terrace.door, axis = "x", width = Layout.Terrace.doorWidth, height = Layout.Terrace.doorHeight, floorY = Layout.CLUB, sill = false, rise = 2 },
	{ name = "the Dressing Room door", centre = Layout.Suite.dressing.door, axis = "x", width = 4, height = 9, floorY = Layout.Suite.floorY, sill = false },
	{ name = "the Study door", centre = Layout.Suite.study.door, axis = "x", width = 4, height = 9, floorY = Layout.Suite.floorY, sill = false },
	{ name = "the Suite's bedroom door", centre = Layout.Suite.bedroom.door, axis = "z", width = 4, height = 9, floorY = Layout.Suite.floorY, sill = false },
	{ name = "the bedroom's doors to the terrace", centre = Layout.Suite.bedroom.terraceDoor, axis = "z", width = 4, height = 9, floorY = Layout.Suite.floorY, sill = false },
	{ name = "the bath's door", centre = Layout.Suite.spa.door, axis = "x", width = 4, height = 9, floorY = Layout.Suite.floorY, sill = false },
	{ name = "the kitchen's door to the terrace", centre = Layout.Suite.kitchen.terraceDoor, axis = "z", width = 4, height = 9, floorY = Layout.Suite.floorY, sill = false },
	{ name = "the screening room door", centre = Layout.Suite.screening.door, axis = "x", width = 4, height = 9, floorY = Layout.Suite.floorY, sill = false },
	{ name = "the gym door", centre = Layout.Suite.gym.door, axis = "x", width = 4, height = 9, floorY = Layout.Suite.floorY, sill = false },
} :: { Doorway }

-- The four rooms in order, for code that treats them alike.
Layout.Rooms = {
	salon = Layout.Salon,
	velvet = Layout.Velvet,
	obsidian = Layout.Obsidian,
	midnight = Layout.Midnight,
}

-- Table geometry, relative to a table centre on the floor.
Layout.Table = {
	topY = 3.4, -- felt height above the floor
	width = 11, -- along X
	depth = 7.4, -- along Z
	chairZ = -5.3,
	seatY = 1.9,
	caseRowZ = 2.55, -- centre line of the case row
	caseWidth = 1.62,
	caseDepth = 1.5,
	caseGap = 0.16,
	feltMinZ = -3.2, -- where pieces may sit
	feltMaxZ = 1.45,
	counterZ = -3.55, -- the brass counter on the near edge
	lampY = 9.5,
	-- The sorting camera looks down the table from above the chair at this angle (degrees above
	-- the felt); the case plates and the counter are turned to face it.
	cameraPitch = 56,
}

-- The Concierge's tour: where the Concierge stops (on the floor), what they turn to, and the way
-- there from the stop before. Every leg keeps to open floor: around the piano and the foot of
-- the Grand Stair, up the stair's middle, through the arch onto the Club Floor.
export type TourStop = { id: string, name: string, stand: Vector3, face: Vector3, via: { Vector3 } }
Layout.Tour = {
	stops = {
		{ id = "lectern", name = "The Concierge", stand = Vector3.new(9, 3, 6.5), face = Vector3.new(9, 3, 16), via = {} },
		{ id = "salon", name = "The Salon", stand = Vector3.new(-21, 3, 5), face = Vector3.new(-30, 3, 4), via = { Vector3.new(-2, 3, 8) } },
		{ id = "tonight", name = "Tonight's table", stand = Vector3.new(-22, 3, 15), face = Vector3.new(-29.4, 3, 17), via = {} },
		{ id = "vault", name = "The Vault", stand = Vector3.new(-3, 3, 47), face = Vector3.new(-8, 3, 53), via = { Vector3.new(-6, 3, 26), Vector3.new(-3, 3, 38) } },
		{
			id = "boutique",
			name = "The Boutique",
			stand = Vector3.new(19, 3, 48.5),
			face = Vector3.new(21, 3, 56),
			via = { Vector3.new(-3, 3, 38), Vector3.new(-3, 3, 13), Vector3.new(25, 3, 13), Vector3.new(25, 3, 38), Vector3.new(19, 3, 40.5) },
		},
		{
			id = "library",
			name = "The Library",
			stand = Vector3.new(-14, 20, 61),
			face = Vector3.new(-14, 20, 66),
			via = {
				Vector3.new(19, 3, 40.5),
				Vector3.new(25, 3, 38),
				Vector3.new(25, 3, 13),
				Vector3.new(8, 3, 13),
				Vector3.new(8, 3, 23.2), -- the foot of the Grand Stair
				Vector3.new(8, 20, 38.2), -- the top
				Vector3.new(8, 20, 47), -- through the arch
				Vector3.new(-6, 20, 57),
			},
		},
		{ id = "ballroom", name = "The Ballroom", stand = Vector3.new(12, 20, 61), face = Vector3.new(12, 20, 66), via = { Vector3.new(0, 20, 61) } },
		{ id = "terrace", name = "The Terrace", stand = Vector3.new(19, 20, 54), face = Vector3.new(25, 20, 54), via = {} },
		{ id = "suite", name = "Your Suite", stand = Vector3.new(-15, 20, 54), face = Vector3.new(-21, 20, 54), via = { Vector3.new(2, 20, 54) } },
	} :: { TourStop },
	-- The things the cards point at (a gold pin floats over each).
	points = {
		salonDoor = Vector3.new(-30, 3, 4),
		velvetDoor = Vector3.new(-30, 3, 35),
		tonightBoard = Vector3.new(-29.4, 9, 17),
		livreDOr = Vector3.new(-19, 3, 36),
		vault = Vector3.new(-8, 3, 53),
		counter = Vector3.new(21, 3, 56),
		mirror = Vector3.new(13.2, 3, 51),
		ledger = Vector3.new(15.5, 3, 46.8),
		libraryDoor = Vector3.new(-14, 20, 66),
		ballroomDoor = Vector3.new(12, 20, 66),
		terraceDoor = Vector3.new(25, 20, 54),
		suiteDoor = Vector3.new(-21, 20, 54),
	} :: { [string]: Vector3 },
}

-- The direction from the felt toward the sorting camera, in the table's own frame (+Z toward
-- the cases).
function Layout.towardCamera(): Vector3
	local pitch = math.rad(Layout.Table.cameraPitch)
	return Vector3.new(0, math.sin(pitch), -math.cos(pitch))
end

function Layout.inBox(b: Box, p: Vector3): boolean
	return p.X >= b.min.X and p.X <= b.max.X and p.Y >= b.min.Y and p.Y <= b.max.Y and p.Z >= b.min.Z and p.Z <= b.max.Z
end

export type ZoneName = "street" | "foyer" | "salon" | "velvet" | "obsidian" | "midnight" | "club" | "library" | "ballroom" | "boutique" | "vault" | "terrace" | "suite" | "none"

function Layout.zoneAt(p: Vector3): ZoneName
	if Layout.inBox(Layout.Terrace.zone, p) then
		return "terrace"
	elseif Layout.inBox(Layout.Suite.zone, p) or Layout.inBox(Layout.Suite.galleryZone, p) then
		return "suite"
	elseif Layout.inBox(Layout.Salon.zone, p) then
		return "salon"
	elseif Layout.inBox(Layout.Velvet.zone, p) then
		return "velvet"
	elseif Layout.inBox(Layout.Obsidian.zone, p) then
		return "obsidian"
	elseif Layout.inBox(Layout.Midnight.zone, p) then
		return "midnight"
	elseif Layout.inBox(Layout.Library.zone, p) then
		return "library"
	elseif Layout.inBox(Layout.Ballroom.zone, p) then
		return "ballroom"
	elseif Layout.inBox(Layout.Club.zone, p) then
		return "club"
	elseif Layout.inBox(Layout.Boutique.zone, p) then
		return "boutique"
	elseif Layout.inBox(Layout.Vault.zone, p) then
		return "vault"
	elseif Layout.inBox(Layout.Foyer.zone, p) then
		return "foyer"
	elseif Layout.inBox(Layout.Street.zone, p) then
		return "street"
	end
	return "none"
end

-- A table's frame: at its centre on the floor, with local +Z pointing the way the seated guest
-- faces (toward the cases). Tables in the four rooms face +Z; duel and Ballroom tables turn.
function Layout.tableFrame(centre: Vector3, forward: Vector3?): CFrame
	local f = forward or Vector3.new(0, 0, 1)
	return CFrame.lookAt(centre, centre - Vector3.new(f.X, 0, f.Z).Unit)
end

-- The centre of case `index` (1-6) in the table's own coordinates.
function Layout.caseLocal(index: number): Vector3
	local t = Layout.Table
	local total = 6 * t.caseWidth + 5 * t.caseGap
	local x = -total / 2 + t.caseWidth / 2 + (index - 1) * (t.caseWidth + t.caseGap)
	return Vector3.new(x, t.topY, t.caseRowZ)
end

-- The centre of case `index` in the world.
function Layout.caseCentre(frame: CFrame, index: number): Vector3
	return frame:PointToWorldSpace(Layout.caseLocal(index))
end

-- Felt slots for pieces: a grid in front of the cases, filled from the centre out.
function Layout.pieceSlots(frame: CFrame, count: number): { Vector3 }
	local t = Layout.Table
	local cols = if count <= 12 then 5 else 6
	local rows = math.ceil(count / cols)
	local usableX = t.width - 1.6
	local usableZ = t.feltMaxZ - t.feltMinZ
	local dx = usableX / cols
	local dz = usableZ / math.max(rows, 3)
	local slots = {}
	for i = 1, count do
		local row = math.floor((i - 1) / cols)
		local col = (i - 1) % cols
		local inRow = math.min(cols, count - row * cols)
		local x = (col - (inRow - 1) / 2) * dx
		local z = t.feltMaxZ - dz * (row + 0.5)
		slots[i] = frame:PointToWorldSpace(Vector3.new(x, t.topY, z))
	end
	return slots
end

---------------------------------------------------------------------------------------------------
-- The Grand Scale. Everything above is the house as drawn; the builders build that (Layout.raw)
-- and then open every room out by SCALE (World/Grand): walls, floors, ceilings, doorways and stairs
-- grow, furniture keeps its true size and moves with its room. The game itself plays in the grown
-- house, so every position and size here is scaled to match: positions, room extents, door widths
-- and heights, stair runs. What is not a distance is left alone (directions, counts, seconds), and
-- so is what keeps its size (the sorting table's own geometry, the piano's bench, the lift's car).
---------------------------------------------------------------------------------------------------
Layout.SCALE = 1.35

local KEEP_KEYS: { [string]: boolean } = {
	SCALE = true, seconds = true, ride = true, steps = true, cameraPitch = true, pianoBenchTop = true,
	facing = true, out = true, name = true, id = true, open = true, gated = true, sill = true, axis = true,
}
local KEEP_TABLES: { [string]: boolean } = { Table = true }
local KEEP_PATHS: { [string]: boolean } = { ["Lift.width"] = true, ["Lift.height"] = true }

local function copy(v: any, seen: { [any]: any }): any
	if type(v) ~= "table" then
		return v
	end
	if seen[v] then
		return seen[v]
	end
	local out = {}
	seen[v] = out
	for k, x in v do
		out[k] = copy(x, seen)
	end
	return out
end

local function grow(t: { [any]: any }, S: number, path: string, seen: { [any]: boolean })
	if seen[t] then
		return
	end
	seen[t] = true
	for k, v in t do
		local key = tostring(k)
		local here = if path == "" then key else path .. "." .. key
		if KEEP_KEYS[key] or KEEP_PATHS[here] or type(v) == "function" then
			continue
		end
		if type(v) == "table" then
			if not KEEP_TABLES[key] then
				grow(v, S, here, seen)
			end
		elseif type(v) == "number" then
			t[k] = v * S
		elseif typeof(v) == "Vector3" then
			t[k] = v * S
		elseif typeof(v) == "CFrame" then
			t[k] = v - v.Position + v.Position * S
		end
	end
end

-- The house as drawn: the builders' numbers. (Its functions are the same, but for the one that
-- reads the room's own numbers.)
local raw = copy(Layout, {})
raw.SCALE = 1
raw.ballroomFrame = function(i: number, count: number?): CFrame
	local n = count or 20
	local B = raw.Ballroom
	local angle = -math.pi / 2 + (i - 1) / n * math.pi * 2
	local centre = B.centre + Vector3.new(math.cos(angle) * B.radius, 0, math.sin(angle) * B.radius)
	return Layout.tableFrame(centre, (B.centre - centre).Unit)
end
grow(Layout :: any, Layout.SCALE, "", {})
Layout.raw = raw :: typeof(Layout)
-- The pianist and the guest at the keys sit at the piano's bench, which keeps its size: from the
-- piano's grown spot, the drawn distance.
Layout.Foyer.pianist = Layout.Foyer.piano * CFrame.new(0, 0, -5) * CFrame.Angles(0, math.pi, 0)
Layout.Foyer.pianoSeat = Layout.Foyer.piano * CFrame.new(0, 2.35, -5) * CFrame.Angles(0, math.pi, 0)

return Layout

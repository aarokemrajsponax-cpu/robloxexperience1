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
	tonightBoard = CFrame.lookAt(Vector3.new(-29.4, 13, 17), Vector3.new(0, 13, 17)),
	wallOfNames = CFrame.lookAt(Vector3.new(-19, 14, 41.4), Vector3.new(-19, 14, 0)),
	livreDOr = CFrame.lookAt(Vector3.new(-19, 3, 36), Vector3.new(-19, 3, 0)),
	stair = { x = 8, fromZ = 24, toZ = 38, topY = 17 },
	stairRopeZ = 22.5,
	-- The Soirée's gilded countdown board, on an easel at the foot of the stair.
	soireeBoard = CFrame.lookAt(Vector3.new(2.5, 3, 23), Vector3.new(-4, 3, 12)),
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
}

function Layout.inBox(b: Box, p: Vector3): boolean
	return p.X >= b.min.X and p.X <= b.max.X and p.Y >= b.min.Y and p.Y <= b.max.Y and p.Z >= b.min.Z and p.Z <= b.max.Z
end

export type ZoneName = "street" | "foyer" | "salon" | "velvet" | "obsidian" | "midnight" | "club" | "library" | "ballroom" | "boutique" | "vault" | "none"

function Layout.zoneAt(p: Vector3): ZoneName
	if Layout.inBox(Layout.Salon.zone, p) then
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

return Layout

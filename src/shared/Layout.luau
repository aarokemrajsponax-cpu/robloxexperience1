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
	tonightBoard = CFrame.lookAt(Vector3.new(-29.4, 13, 17), Vector3.new(0, 13, 17)),
	wallOfNames = CFrame.lookAt(Vector3.new(-19, 14, 41.4), Vector3.new(-19, 14, 0)),
	livreDOr = CFrame.lookAt(Vector3.new(-19, 3, 36), Vector3.new(-19, 3, 0)),
	stair = { x = 8, fromZ = 24, toZ = 38, topY = 17 },
	stairRopeZ = 22.5,
	boutiqueDoor = CFrame.lookAt(Vector3.new(19, 3, 41.5), Vector3.new(19, 3, 0)),
}

-- The four room doors, as seen from the Foyer. `facing` points into the Foyer.
Layout.RoomDoors = {
	salon = { centre = Vector3.new(-30, 3, 4), facing = Vector3.new(1, 0, 0), open = true },
	velvet = { centre = Vector3.new(-30, 3, 31), facing = Vector3.new(1, 0, 0), open = false },
	midnight = { centre = Vector3.new(30, 3, 4), facing = Vector3.new(-1, 0, 0), open = false },
	obsidian = { centre = Vector3.new(30, 3, 31), facing = Vector3.new(-1, 0, 0), open = false },
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

export type ZoneName = "street" | "foyer" | "salon" | "none"

function Layout.zoneAt(p: Vector3): ZoneName
	if Layout.inBox(Layout.Salon.zone, p) then
		return "salon"
	elseif Layout.inBox(Layout.Foyer.zone, p) then
		return "foyer"
	elseif Layout.inBox(Layout.Street.zone, p) then
		return "street"
	end
	return "none"
end

-- The centre of case `index` (1-6) on a table centred at `centre`.
function Layout.caseCentre(centre: Vector3, index: number): Vector3
	local t = Layout.Table
	local total = 6 * t.caseWidth + 5 * t.caseGap
	local x = -total / 2 + t.caseWidth / 2 + (index - 1) * (t.caseWidth + t.caseGap)
	return centre + Vector3.new(x, t.topY, t.caseRowZ)
end

-- Felt slots for pieces: a grid in front of the cases, filled from the centre out.
function Layout.pieceSlots(centre: Vector3, count: number): { Vector3 }
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
		slots[i] = centre + Vector3.new(x, t.topY, z)
	end
	return slots
end

return Layout

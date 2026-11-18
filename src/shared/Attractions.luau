--!strict
-- The Maison's three great attractions, each reached through its own room off the Foyer, each
-- played in its own place well away from the house (server/Attractions builds them; their screens
-- draw them):
--   Steal a Luxe          (through the Velvet Room): slip into a great residence, carry out what
--                          you can and bank it at the getaway car before the guards catch you.
--   The Maison Basement   (through the Obsidian Room): an obstacle course under the house, chamber
--                          by chamber, with a chest at each way out and the Treasury at the bottom.
--   The Executive Suite   (through the Midnight Room): by invitation only. Security, puzzles, the
--                          Executive himself, and the lift out with what you took.
--   The Grand Ballroom    (through the great doors at the far end of the Ballroom): dancing,
--                          Luxury Trivia, the Runway, the Daily Arena, photo sets, the Exchange
--                          and the Hall of Fame.
--   Luxury Island         (from the Jet Lounge on the Terrace): the private island, by the jet,
--                          for guests who hold the Island Key.
-- While a guest is in one, the server sets their "Attraction" attribute to its id: its screen (and
-- only its screen) shows then, and goes when they leave.

local Config = require(script.Parent.Config)

local Attractions = {}

Attractions.ATTRIBUTE = "Attraction"

-- (Build 94) Where the brainrot walking beside a guest, and their Gem Shop companion, step aside so
-- everyone can see the way: Steal a Luxe, the Maison Basement and the Executive Suite. A guest can
-- call theirs back in for that visit ("CompanionsIn" on them names the attraction it was called
-- into; the server sets it), and it's beside them again as soon as they leave.
Attractions.HIDES_COMPANIONS = { luxe = true, basement = true, executive = true } :: { [string]: boolean }
Attractions.COMPANIONS_IN = "CompanionsIn"

-- Whether `player`'s brainrot and companion are put away just now (on every screen alike).
function Attractions.companionsHidden(player: Player): boolean
	local a = player:GetAttribute(Attractions.ATTRIBUTE)
	if type(a) ~= "string" or not Attractions.HIDES_COMPANIONS[a] then
		return false
	end
	return player:GetAttribute(Attractions.COMPANIONS_IN) ~= a
end

export type Def = {
	id: string,
	name: string,
	room: string, -- the room off the Foyer it is entered through
	roomName: string, -- what that room is called now
	tag: string, -- a few words for the sign over its entrance
	line: string, -- what it is, in a sentence
	glyph: string,
	colour: Color3,
}

local rgb = Color3.fromRGB

Attractions.List = {
	{
		id = "luxe",
		name = "Steal a Luxe",
		room = "velvet",
		roomName = "The Luxe Lounge",
		tag = "SLIP IN · CARRY OUT · BANK IT",
		line = "Slip into a great residence, carry out what you can, and bank it at the getaway car before the guards catch you.",
		glyph = "💎",
		colour = rgb(214, 62, 92),
	},
	{
		id = "basement",
		name = "The Maison Basement",
		room = "obsidian",
		roomName = "The Basement Stair",
		tag = "JUMP · CLIMB · CLAIM",
		line = "An obstacle course under the house: four chambers, a chest at every way out, and the Treasury at the very bottom.",
		glyph = "🏁",
		colour = rgb(240, 176, 60),
	},
	{
		id = "executive",
		name = "The Executive Suite",
		room = "midnight",
		roomName = "The Executive's Anteroom",
		tag = "BY INVITATION ONLY",
		line = "By invitation only: past the security, through the puzzles, face to face with the Executive, and out by the lift with what you took.",
		glyph = "🕴️",
		colour = rgb(120, 200, 255),
	},
	{
		id = "gala",
		name = "The Grand Ballroom",
		-- (Build 94: its doors are in the Club hall now, where the old Ballroom's were.)
		room = "club",
		roomName = "the Club hall, up the Grand Stair",
		tag = "DANCE · TRIVIA · THE RUNWAY · THE ARENA",
		line = "The house's hall of entertainments: the dance floor, Luxury Trivia, the Runway, the Daily Arena, the photo sets, the Exchange and the Hall of Fame.",
		glyph = "💃",
		colour = rgb(255, 196, 120),
	},
	{
		id = "island",
		name = "Luxury Island",
		room = "terrace",
		roomName = "The Jet Lounge",
		tag = "THE PRIVATE JET · NOW BOARDING",
		line = "Fly to the house's private island: the villas, the lagoon's pearls, the Sunset Lookout and your own jet.",
		glyph = "🏝️",
		colour = rgb(90, 210, 230),
	},
} :: { Def }

Attractions.byId = {} :: { [string]: Def }
Attractions.byRoom = {} :: { [string]: Def }
for _, a in Attractions.List do
	Attractions.byId[a.id] = a
	Attractions.byRoom[a.room] = a
end

local function cfg(): { [string]: any }
	return (Config.data :: any).Attractions
end

-- Where an attraction's place is, if it has one yet (Config Attractions[id].origin).
local function placed(id: string): Vector3?
	local c = cfg()[id]
	local o = c and c.origin
	if type(o) == "table" and type(o[1]) == "number" and type(o[2]) == "number" and type(o[3]) == "number" then
		return Vector3.new(o[1], o[2], o[3])
	end
	return nil
end

-- Where an attraction's place is: its middle, on its ground.
function Attractions.origin(id: string): Vector3
	return placed(id) or Vector3.zero
end

-- How far an attraction's place reaches from its origin: the box it's built in (a guest inside it
-- is in that attraction; anywhere else, in the Maison).
Attractions.BOUNDS = {
	luxe = { min = Vector3.new(-260, -140, -260), max = Vector3.new(260, 140, 260) },
	basement = { min = Vector3.new(-90, -300, -60), max = Vector3.new(90, 80, 3950) }, -- (Build 89: thirty-two stages, twice as long again)
	executive = { min = Vector3.new(-320, -120, -280), max = Vector3.new(320, 120, 160) }, -- (Build 91: the Reception, behind the lobby)
	island = { min = Vector3.new(-520, -80, -420), max = Vector3.new(420, 260, 440) },
	gala = { min = Vector3.new(-160, -40, -140), max = Vector3.new(160, 90, 140) },
} :: { [string]: { min: Vector3, max: Vector3 } }

-- Which attraction's place a point is in, or nil (the Maison and everywhere else).
function Attractions.areaAt(p: Vector3): string?
	for _, a in Attractions.List do
		-- (One with no place yet has no area: never the Maison's own.)
		local o = placed(a.id)
		local b = Attractions.BOUNDS[a.id]
		if o and b then
			local rel = p - o
			if rel.X >= b.min.X and rel.X <= b.max.X and rel.Y >= b.min.Y and rel.Y <= b.max.Y and rel.Z >= b.min.Z and rel.Z <= b.max.Z then
				return a.id
			end
		end
	end
	return nil
end

return Attractions

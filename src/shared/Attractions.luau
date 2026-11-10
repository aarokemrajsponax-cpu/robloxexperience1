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
-- While a guest is in one, the server sets their "Attraction" attribute to its id: its screen (and
-- only its screen) shows then, and goes when they leave.

local Config = require(script.Parent.Config)

local Attractions = {}

Attractions.ATTRIBUTE = "Attraction"

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

-- How far an attraction's place reaches either side of its middle (and below and above it).
Attractions.REACH = {
	luxe = Vector3.new(260, 140, 260),
	basement = Vector3.new(260, 160, 260),
	executive = Vector3.new(320, 120, 160),
} :: { [string]: Vector3 }

-- Which attraction's place a point is in, or nil (the Maison and everywhere else).
function Attractions.areaAt(p: Vector3): string?
	for _, a in Attractions.List do
		-- (One with no place yet has no area: never the Maison's own.)
		local o = placed(a.id)
		local r = Attractions.REACH[a.id]
		if o and r and math.abs(p.X - o.X) <= r.X and math.abs(p.Z - o.Z) <= r.Z and p.Y >= o.Y - r.Y and p.Y <= o.Y + r.Y then
			return a.id
		end
	end
	return nil
end

return Attractions

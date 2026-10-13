--!strict
-- The four rooms (§8, Appendix D). Numbers come from Config so they can be tuned live.

local Config = require(script.Parent.Config)

local Rooms = {}

export type Room = {
	id: string,
	name: string,
	line: string,
	tag: string, -- a few words for the sign by its door ("TIMED · HARD")
	level: number, -- how hard, 1 (the Salon) to 4 (the Midnight Room)
	timed: boolean,
	tuning: Config.RoomTuning,
}

local order = { "salon", "velvet", "obsidian", "midnight" }

local names = {
	salon = "The Salon",
	velvet = "The Velvet Room",
	obsidian = "The Obsidian Room",
	midnight = "The Midnight Room",
}

local lines = {
	salon = "No clock at all. Sort at your own pace, for as long as you like.",
	velvet = "A soft clock that waits for you to lift the first piece.",
	obsidian = "Every case open from the first deal, and the clock starts with it.",
	midnight = "The house is closing. Nothing is named and nothing is pointed out.",
}

-- For the signs by the doors: a few words, and how hard (a pip each).
local tags = {
	salon = "No clock · Learn here",
	velvet = "Timed · Gentle",
	obsidian = "Timed · Hard",
	midnight = "Timed · Hardest",
}
local levels = { salon = 1, velvet = 2, obsidian = 3, midnight = 4 }

function Rooms.get(id: string): Room?
	local tuning = Config.data.Rooms[id]
	if tuning == nil then
		return nil
	end
	return {
		id = id,
		name = names[id],
		line = lines[id],
		tag = tags[id] or "",
		level = levels[id] or 1,
		timed = tuning.clockBase ~= nil,
		tuning = tuning,
	}
end

function Rooms.all(): { Room }
	local out = {}
	for _, id in order do
		local room = Rooms.get(id)
		if room then
			table.insert(out, room)
		end
	end
	return out
end

Rooms.order = order

return Rooms

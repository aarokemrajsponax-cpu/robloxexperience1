--!strict
-- The House Trophies (Build 92): a piece for your Suite from each of the house's games, earned by
-- playing it, never bought. Each is had the moment the guest's own count of a feat reaches it (the
-- counts the server keeps for the Badge Book: server/Achievements tally), and then stays: placed
-- from the Suite's bell like any piece. What you win at one game furnishes the home you come back
-- to, so every game counts toward the same place.
--
--   Trophies.List           each trophy: its Suite piece, the count it needs and how it's had
--   Trophies.byItem[id]     the trophy a Suite piece is
--   Trophies.earned(data, id)  whether this guest has earned it (by their own record)

local Trophies = {}

export type Trophy = { item: string, stat: string, need: number, game: string, how: string }

Trophies.List = {
	{ item = "suite_trophy_jewels", stat = "crownJewels", need = 1, game = "Steal a Luxe", how = "Carry a crown jewel out of Steal a Luxe" },
	{ item = "suite_trophy_treasury", stat = "basementClears", need = 1, game = "The Maison Basement", how = "Reach the Treasury at the bottom of the Maison Basement" },
	{ item = "suite_trophy_executive", stat = "executiveWins", need = 1, game = "The Executive Suite", how = "Beat the Executive in his Office" },
	{ item = "suite_trophy_chequered", stat = "raceWins", need = 1, game = "The Grand Prix", how = "Win a race in the Grand Prix" },
	{ item = "suite_trophy_arena", stat = "arenaWins", need = 1, game = "The Grand Ballroom", how = "Win the Daily Arena in the Grand Ballroom" },
	{ item = "suite_trophy_auction", stat = "auctionWins", need = 1, game = "The Grand Auction", how = "Win a lot at the Grand Auction" },
} :: { Trophy }

Trophies.byItem = {} :: { [string]: Trophy }
Trophies.byStat = {} :: { [string]: { Trophy } }
for _, t in Trophies.List do
	Trophies.byItem[t.item] = t
	Trophies.byStat[t.stat] = Trophies.byStat[t.stat] or {}
	table.insert(Trophies.byStat[t.stat], t)
end

-- The guest's own count of a feat (their record: never anything a screen says).
function Trophies.count(data: any, stat: string): number
	local tally = type(data) == "table" and data.tally or nil
	return if type(tally) == "table" then math.max(0, tonumber(tally[stat]) or 0) else 0
end

function Trophies.earned(data: any, itemId: string): boolean
	local t = Trophies.byItem[itemId]
	return t ~= nil and Trophies.count(data, t.stat) >= t.need
end

return Trophies

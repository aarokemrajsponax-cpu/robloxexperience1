--!strict
-- The house's events (the owner's panel): what each one is called and what it says. They change
-- Gilt, the Ledger, Mythic luck and how the house feels, never a score, so the boards stay fair.
-- The numbers live in Config.Admin.

local HouseEvents = {}

export type Event = { id: string, name: string, line: string }

HouseEvents.List = {
	{ id = "goldenHour", name = "Golden Hour", line = "Gilt counts double." },
	{ id = "luckyHour", name = "Lucky Hour", line = "Mythics are ten times as likely in the four rooms." },
	{ id = "pageTurner", name = "The Page-Turner", line = "The Ledger's pages turn twice as fast." },
	{ id = "giants", name = "A Night of Giants", line = "Every guest walking the house stands tall." },
	{ id = "quickstep", name = "The Quickstep", line = "Everyone walks and runs faster." },
	{ id = "featherlight", name = "Featherlight", line = "The house's gravity is gentle. Jump." },
	{ id = "goldRain", name = "Gold Rain", line = "Gold coins are scattered through the house. Walk over them for Gilt." },
	{ id = "treasure", name = "The Treasure Hunt", line = "Golden keys are hidden around the house. The finder of each wins Gilt." },
} :: { Event }

HouseEvents.byId = {} :: { [string]: Event }
for _, e in HouseEvents.List do
	HouseEvents.byId[e.id] = e
end

-- Lines the owner can announce with one tap (anything typed is filtered by Roblox first).
HouseEvents.Announcements = {
	"The owner is in the house tonight. Come and say good evening.",
	"Everyone to the Ballroom: the next evening is a big one.",
	"Golden Hour is on. Every table pays double Gilt.",
	"A treasure hunt has begun. Look everywhere.",
	"Thank you for spending your evening at Maison Noir.",
	"The Terrace is open. Come and see the fireworks.",
}

-- The Workspace attribute that carries an event's end time (seconds since 1970), or nil.
function HouseEvents.attribute(id: string): string
	return "Event_" .. id
end

return HouseEvents

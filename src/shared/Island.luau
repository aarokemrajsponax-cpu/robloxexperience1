--!strict
-- Luxury Island: the house's private island, reached by the private jet from the Jet Lounge on
-- the Terrace. Pure plan and rules, shared by the server (which builds it and keeps every
-- reward), every screen and the tests. Places are given from the island's origin (Config
-- Attractions.island.origin), y = 0 at the sea.
--
--   The airstrip      on the north shore: your jet waits at its west end, in your livery
--   The Jet Gallery   a hangar by the airstrip: every livery as a model, and the Livery Desk
--   The Grand Villa   on the eastern headland: white stone, glass and teak, an infinity pool,
--                     the Sky Lounge and its bar
--   The lagoon        crystal water inside the reef, the four overwater villas on their pier,
--                     each with its own plunge pool; the day's pearls lie on its floor
--   The South Beach   white sand, cabanas, loungers and the Coral Club (a beach bar and a deck)
--   The gardens       palms, hibiscus and a fountain court in the middle of the island
--   The summit        the Sunset Lookout: a round stone deck with the whole sea around it, where
--                     the day's sunset is toasted
--   The marina        three yachts on the west pier
--   The Coastal Circuit  a ribbon of road round the airstrip, for timed laps (World/Coast)
--
-- Reasons to come back, every day: five pearls on the lagoon's floor (new places each day), the
-- sunset toast (with friends, a little more), the postcard spots, the Pearl Exchange (the
-- island's own pieces for your Suite, for pearls), and liveries and island lights to choose.
-- How the island is opened, and what everything costs, is shown at the Jet Lounge before anyone
-- pays: nothing here is chance, and nothing is sold for Robux that can't be had otherwise except
-- two jet liveries that are only a look.

local Island = {}

local rgb = Color3.fromRGB

Island.ID = "island"
Island.SEA = 0 -- the sea's surface (local y)
Island.GROUND = 6 -- the island's lowland (local y): the airstrip, the gardens, the beach's top

-- Where a guest steps out of the jet, by its airstair, facing the island.
Island.Arrival = CFrame.lookAt(Vector3.new(-132, Island.GROUND + 0.5, -150), Vector3.new(-60, Island.GROUND + 0.5, -40))
-- The jet on the airstrip (its nose east), and the way home: its airstair.
Island.Jet = CFrame.lookAt(Vector3.new(-150, Island.GROUND, -176), Vector3.new(0, Island.GROUND, -176))
Island.Airstair = Vector3.new(-150, Island.GROUND, -158)

-- The places, for signs, the Concierge and the postcards.
Island.Places = {
	airstrip = { name = "The Airstrip", at = Vector3.new(-40, Island.GROUND, -176) },
	gallery = { name = "The Jet Gallery", at = Vector3.new(60, Island.GROUND, -150) },
	villa = { name = "The Grand Villa", at = Vector3.new(150, 30, -10) },
	lagoon = { name = "The Lagoon", at = Vector3.new(-20, Island.SEA, 190) },
	beach = { name = "The South Beach", at = Vector3.new(60, Island.GROUND - 2, 150) },
	gardens = { name = "The Gardens", at = Vector3.new(-30, Island.GROUND, 10) },
	summit = { name = "The Sunset Lookout", at = Vector3.new(-120, 40, 40) },
	marina = { name = "The Marina", at = Vector3.new(-230, Island.SEA, 80) },
} :: { [string]: { name: string, at: Vector3 } }

---------------------------------------------------------------------------------------------------
-- Opening the island: the Island Key
---------------------------------------------------------------------------------------------------
-- A wealth rank to have reached (Tycoon), and the key itself for Gilt or for Gems: both shown at
-- the Jet Lounge. (Config Attractions.island can change the figures.)
Island.KEY_RANK = 6
Island.KEY_GILT = 25000
Island.KEY_GEMS = 250

---------------------------------------------------------------------------------------------------
-- The pearls
---------------------------------------------------------------------------------------------------
-- Where pearls can lie on the lagoon's floor (local, on the sand). Each day, five of them, the same
-- five for everyone that day, chosen by the day itself.
Island.PEARL_SPOTS = {
	Vector3.new(-80, -5.4, 168), Vector3.new(-58, -5.4, 205), Vector3.new(-30, -5.4, 182), Vector3.new(-6, -5.4, 214),
	Vector3.new(18, -5.4, 172), Vector3.new(40, -5.4, 200), Vector3.new(64, -5.4, 222), Vector3.new(-96, -5.4, 214),
	Vector3.new(-44, -5.4, 236), Vector3.new(-12, -5.4, 244), Vector3.new(30, -5.4, 240), Vector3.new(-70, -5.4, 248),
	Vector3.new(84, -5.4, 196), Vector3.new(-110, -5.4, 190), Vector3.new(6, -5.4, 192), Vector3.new(52, -5.4, 252),
} :: { Vector3 }
Island.PEARLS_A_DAY = 5
Island.PEARL_REACH = 7 -- how near a guest must be to bring one up
Island.PEARL_GILT = 250 -- each pearl
Island.PEARL_SET_GEMS = 2 -- all five in a day

-- The day's pearls: `count` spots (indices into PEARL_SPOTS), the same for everyone on `day`.
function Island.pearlsFor(day: number, count: number?): { number }
	local n = count or Island.PEARLS_A_DAY
	local order = {}
	for i = 1, #Island.PEARL_SPOTS do
		order[i] = i
	end
	-- (A small deterministic shuffle seeded by the day: every server, every screen agrees.)
	local seed = (day * 2654435761) % 4294967296
	for i = #order, 2, -1 do
		seed = (seed * 1103515245 + 12345) % 2147483648
		local j = seed % i + 1
		order[i], order[j] = order[j], order[i]
	end
	local out = {}
	for i = 1, math.min(n, #order) do
		out[i] = order[i]
	end
	table.sort(out)
	return out
end

---------------------------------------------------------------------------------------------------
-- The sunset toast
---------------------------------------------------------------------------------------------------
Island.TOAST_GILT = 300 -- once a day
Island.TOAST_FRIEND = 50 -- for each friend who toasts in the same few minutes (in the house)
Island.TOAST_FRIENDS_MOST = 4 -- counted at most
Island.TOAST_WINDOW = 180 -- seconds: toasting "together"
Island.TOAST_REACH = 26 -- how near the Lookout's middle

---------------------------------------------------------------------------------------------------
-- The postcard spots: a frame on a post, a view behind it. A photograph at every one: a badge
-- and Gilt, once.
---------------------------------------------------------------------------------------------------
Island.Postcards = {
	{ id = "jet", name = "Wheels Down", at = Vector3.new(-120, Island.GROUND, -146), look = Vector3.new(-150, Island.GROUND + 6, -176) },
	{ id = "villa", name = "The Infinity Pool", at = Vector3.new(118, 31, -28), look = Vector3.new(60, 28, -60) },
	{ id = "pier", name = "Overwater", at = Vector3.new(-24, Island.SEA + 3.3, 150), look = Vector3.new(-30, 6, 236) },
	{ id = "beach", name = "Barefoot", at = Vector3.new(96, 2.6, 116), look = Vector3.new(60, 2, 260) },
	{ id = "summit", name = "Golden Hour", at = Vector3.new(-110, 40, 50), look = Vector3.new(-300, 30, 160) },
	{ id = "marina", name = "Anchors Aweigh", at = Vector3.new(-236, Island.GROUND, 70), look = Vector3.new(-280, 8, 100) },
} :: { { id: string, name: string, at: Vector3, look: Vector3 } }
Island.POSTCARD_REACH = 12
Island.POSTCARDS_GILT = 1000

---------------------------------------------------------------------------------------------------
-- Liveries for your jet, and the island's lights (each guest's own choice, on their own screen)
---------------------------------------------------------------------------------------------------
export type Livery = { id: string, name: string, line: string, body: Color3, trim: Color3, stripe: Color3, cabin: Color3, gilt: number?, gems: number?, product: string? }
Island.Liveries = {
	{ id = "ivory", name = "Ivory & Gold", line = "Ivory lacquer and a gold cheat line: the classic private jet.", body = rgb(244, 240, 230), trim = rgb(206, 166, 84), stripe = rgb(196, 152, 66), cabin = rgb(214, 200, 176) },
	{ id = "noir", name = "Maison Noir", line = "Black lacquer and gold: the house's own.", body = rgb(16, 16, 20), trim = rgb(214, 176, 96), stripe = rgb(240, 206, 120), cabin = rgb(84, 46, 30) },
	{ id = "riviera", name = "Riviera", line = "White as a yacht, a line of Mediterranean blue.", body = rgb(240, 240, 236), trim = rgb(36, 96, 168), stripe = rgb(86, 160, 226), cabin = rgb(214, 200, 176), gilt = 12000 },
	{ id = "champagne", name = "Champagne", line = "Pale gold from nose to tail.", body = rgb(226, 206, 160), trim = rgb(150, 116, 60), stripe = rgb(255, 238, 190), cabin = rgb(236, 226, 206), gilt = 30000 },
	{ id = "emerald", name = "Emerald Club", line = "Racing green and brass.", body = rgb(18, 70, 52), trim = rgb(200, 164, 88), stripe = rgb(236, 214, 150), cabin = rgb(120, 66, 40), gems = 120 },
	{ id = "rose", name = "Rosé", line = "Blush and rose gold.", body = rgb(236, 196, 196), trim = rgb(196, 132, 120), stripe = rgb(255, 226, 214), cabin = rgb(240, 222, 214), gems = 180 },
	{ id = "aurora", name = "Midnight Aurora", line = "Navy, with violet light along its flanks.", body = rgb(18, 22, 54), trim = rgb(150, 110, 255), stripe = rgb(120, 220, 255), cabin = rgb(40, 34, 70), product = "jetAurora" },
	{ id = "sovereign", name = "Sovereign Gold", line = "Gold leaf over black, for a Sovereign's arrival.", body = rgb(200, 158, 70), trim = rgb(20, 18, 16), stripe = rgb(255, 230, 150), cabin = rgb(30, 24, 18), product = "jetSovereign" },
} :: { Livery }
Island.liveryById = {} :: { [string]: Livery }
for _, l in Island.Liveries do
	Island.liveryById[l.id] = l
end

export type Theme = { id: string, name: string, line: string, clock: number, gilt: number?, gems: number? }
Island.Themes = {
	{ id = "golden", name = "Golden Hour", line = "The sun low over the sea, everything warm.", clock = 17.55 },
	{ id = "azure", name = "Azure Noon", line = "High sun, clear water, the brightest blue.", clock = 13.2, gilt = 8000 },
	{ id = "dawn", name = "Rosé Dawn", line = "First light in pink and gold.", clock = 6.35, gems = 60 },
	{ id = "moonlit", name = "Moonlit", line = "A full moon on the lagoon, and the lanterns lit.", clock = 0.6, gilt = 20000 },
} :: { Theme }
Island.themeById = {} :: { [string]: Theme }
for _, t in Island.Themes do
	Island.themeById[t.id] = t
end

---------------------------------------------------------------------------------------------------
-- The Pearl Exchange: the island's own pieces for your Suite, for pearls brought up from the
-- lagoon (shared/SuiteCatalog lists them with source "island").
---------------------------------------------------------------------------------------------------
Island.Exchange = {
	{ id = "suite_shelllamp", pearls = 15 },
	{ id = "suite_palmlounger", pearls = 30 },
	{ id = "suite_coralthrone", pearls = 60 },
	{ id = "suite_pearlchandelier", pearls = 120 },
} :: { { id: string, pearls: number } }
Island.exchangeById = {} :: { [string]: number }
for _, e in Island.Exchange do
	Island.exchangeById[e.id] = e.pearls
end

-- The day number (UTC) a time falls on.
function Island.day(t: number): number
	return math.floor(t / 86400)
end

return Island

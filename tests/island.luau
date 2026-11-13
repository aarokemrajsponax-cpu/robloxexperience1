--!nocheck
-- Luxury Island on the server (server/Attractions/Island, IslandBuild, World/Lobbies), under Lune
-- on a fake clock, in the house's test harness: the Jet Lounge on the Terrace; the island built
-- (its places, its prompts, within its budget); the Island Key (a Tycoon's, for Gilt or Gems: its
-- price and its rank shown, never taken twice); the flight in and home; the day's pearls (the same
-- five for everyone, only from beside them, once each, all five a little more); the sunset toast
-- (once a day, at the Lookout, more with friends); the postcards; liveries and the island's light
-- (for Gilt or Gems, worn on the guest for every screen; the Robux two only offered); the Pearl
-- Exchange; and requests that aren't the island's refused.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/island.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles, broadcasts = H.module, H.profiles, H.broadcasts
local Remotes, Config = H.Remotes, H.Config

local Layout = module("ReplicatedStorage", "Shared", "Layout")
local Plan = module("ReplicatedStorage", "Shared", "Island")
local Wardrobe = module("ReplicatedStorage", "Shared", "Wardrobe")
local AttractionList = module("ReplicatedStorage", "Shared", "Attractions")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Game = module("ServerScriptService", "Server", "Attractions", "Island")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Fortune = module("ServerScriptService", "Server", "Fortune")
local Herald = module("ServerScriptService", "Server", "Herald")

local T = 1795000000 -- a fixed day
Game.now = function()
	return T
end
local awards = {}
Attractions.award = function(p, key)
	table.insert(awards, { p = p, key = key })
end
local friendsWith = {}
Game.friends = function(a, b)
	return friendsWith[a.UserId .. ":" .. b.UserId] == true or friendsWith[b.UserId .. ":" .. a.UserId] == true
end
local offered = {}
Game.offerLivery = function(p, product)
	table.insert(offered, { p = p, product = product })
	return true, nil
end

local workspace = H.game:GetService("Workspace")
Lobbies.build(workspace)
local ada = H.guest("Ada", 901)
local bo = H.guest("Bo", 902)
run(Herald.start)
run(Attractions.start)
local o = Config.data.Attractions.island.origin
local O = Vector3.new(o[1], o[2], o[3])

local ask = Remotes.funcs.AttractionAsk.OnServerInvoke
local function askAs(g, request)
	advance(0.4)
	local r
	run(function()
		r = ask(g, request)
	end)
	return r
end
local function last(g, op)
	for i = #g.inbox, 1, -1 do
		if g.inbox[i].op == op then
			return g.inbox[i]
		end
	end
	return nil
end
local function data(g)
	return profiles[g].Data
end
local function page(g)
	return Game.page(Attractions.ctx, data(g))
end
local function stand(g, at, y)
	g.Character = g.body
	g.root.CFrame = CFrame.new(at + Vector3.new(0, y or 3, 0))
end
local function standOn(g, v, y)
	stand(g, O + v, y)
end
local function act(g, what)
	what.op, what.id = "act", "island"
	return askAs(g, what)
end

---------------------------------------------------------------------------------------------------
-- 1. The Jet Lounge, and the island as built
---------------------------------------------------------------------------------------------------
local kinds = {}
for _, p in H.tagged.AttractionPrompt or {} do
	if p:GetAttribute("Attraction") == "island" then
		local key = p:GetAttribute("Kind") .. ":" .. tostring(p:GetAttribute("Panel") or p:GetAttribute("Act") or "")
		kinds[key] = (kinds[key] or 0) + 1
		if p:GetAttribute("Kind") == "go" then
			check("the jet's arch stands in the Jet Lounge, on the Terrace", Layout.zoneAt(p.Parent.CFrame.Position) == "terrace", p.Parent.CFrame.Position)
		end
	end
end
check("the island is one of the attractions, entered from the Terrace", AttractionList.byId.island ~= nil and AttractionList.byId.island.room == "terrace")
check("its prompts: the arch, the way home, the Livery Desk, the Exchange, the toast, six postcards", kinds["go:"] == 1 and kinds["home:"] == 1 and kinds["panel:liveries"] == 1 and kinds["panel:exchange"] == 1 and kinds["act:toast"] == 1 and kinds["act:postcard"] == 6)
-- Walking into the jet's arch without the Island Key: still locked, and what opens it is shown
-- (once per walk-in), never a way round it.
do
	local zone
	for _, z in H.tagged.AttractionPortal or {} do
		if z:GetAttribute("Attraction") == "island" then
			zone = z
		end
	end
	check("the jet's arch has a zone to walk through", zone ~= nil)
	if zone then
		local keyless = H.guest("Kip", 911)
		local function panels()
			local n = 0
			for _, m in keyless.inbox do
				if m.op == "panel" and m.id == "island" then
					n += 1
				end
			end
			return n
		end
		local floorY = zone.CFrame.Position.Y - zone.Size.Y / 2
		stand(keyless, Vector3.new(zone.CFrame.Position.X, floorY, zone.CFrame.Position.Z))
		for _ = 1, 8 do
			advance(0.1)
		end
		check("walked into without the Island Key: still locked, what opens it shown once", Attractions.inside(keyless) == nil and panels() == 1, panels())
		keyless.Parent = nil
		advance(0.3)
	end
end
local built = Game.built()
local isle = built and built.model
check("the island is built", isle ~= nil)
local function count(name)
	local n = 0
	for _, d in isle:GetDescendants() do
		if d.Name == name then
			n += 1
		end
	end
	return n
end
check("its places: the airstrip and the jet, the Jet Gallery, the Grand Villa, the overwater villas, the beach, the gardens, the Lookout, the marina", isle:FindFirstChild("Airstrip") and isle.Airstrip:FindFirstChild("Jet") and isle:FindFirstChild("JetGallery") and isle:FindFirstChild("GrandVilla") and isle:FindFirstChild("Overwater") and isle:FindFirstChild("SouthBeach") and isle:FindFirstChild("Gardens") and isle:FindFirstChild("SunsetLookout") and isle:FindFirstChild("Marina"))
check("four overwater villas, each with its own pool", count("VillaDeck") == 4 and count("pool") >= 5, count("pool"))
check("three yachts in the marina; palms all over", count("Yacht") == 3 and count("Palm") >= 24, count("Palm"))
check("every livery in the Jet Gallery, as a model", (function()
	local seen = 0
	for _, d in isle.JetGallery:GetChildren() do
		if d.Name == "Jet" and type(d:GetAttribute("Livery")) == "string" then
			seen += 1
		end
	end
	return seen == #Plan.Liveries
end)())
local parts, lights = 0, 0
for _, d in isle:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lights += 1
	end
end
check("within its budget: under 5,000 parts and no lights of its own (each screen lights it)", parts < 5000 and lights == 0, parts, lights)
local painted = 0
for _, d in isle.Airstrip.Jet:GetDescendants() do
	if d:IsA("BasePart") and type(d:GetAttribute("Livery")) == "string" then
		painted += 1
	end
end
check("the jet's paint is marked for each screen's livery", painted >= 10, painted)
check("no terrain under Lune: the island's ground is parts", built.terrain == false and isle:FindFirstChild("Ground") ~= nil)
check("the island lies in its own area, away from the house", AttractionList.areaAt(O + Plan.Arrival.Position) == "island" and AttractionList.areaAt(Layout.Terrace.arrival) == nil)
check("its pearls lie in the lagoon, under the water", (function()
	for _, p in Plan.PEARL_SPOTS do
		if p.Y >= 0 or p.Z < 150 then
			return false
		end
	end
	return true
end)())

---------------------------------------------------------------------------------------------------
-- 2. The Island Key
---------------------------------------------------------------------------------------------------
data(ada).gilt, data(ada).gems = 0, 0
stand(ada, Layout.Terrace.arrival)
local r = askAs(ada, { op = "go", id = "island" })
check("without the Island Key: no flight, and what opens it", r.ok == false and string.find(r.why, "Island Key", 1, true) ~= nil, r.why)
check("...the island is locked for them (its arch shows the Jet Lounge's card instead)", Game.locked(Attractions.ctx, ada) == true)
local state = askAs(ada, { op = "state", id = "island" })
check("the card: the rank and both prices, before anyone pays", state.ok == true and state.key == false and state.keyRank == 6 and state.keyRankName == "Tycoon" and state.keyGilt == 25000 and state.keyGems == 250)
r = act(ada, { act = "key" })
check("below a Tycoon: no key, and how far to go", r.ok == false and string.find(r.why, "Tycoon", 1, true) ~= nil and string.find(r.why, "100,000", 1, true) ~= nil, r.why)
Fortune.page(data(ada)).rank = 6
r = act(ada, { act = "key" })
check("a Tycoon without the Gilt: its price", r.ok == false and r.why == "The Island Key is 25,000 Gilt.", r.why)
data(ada).gilt = 30000
r = act(ada, { act = "key" })
check("a Tycoon with the Gilt: the key, for good", r.ok == true and page(ada).key == true and data(ada).gilt == 5000)
local badge = false
for _, a in awards do
	if a.p == ada and a.key == "islandKey" then
		badge = true
	end
end
check("...the badge", badge)
local told = false
for _, b in broadcasts do
	if b.remote == "Empire" and b.message.op == "feat" and b.message.kind == "island" then
		told = true
	end
end
check("...and the house hears of it", told)
r = act(ada, { act = "key" })
check("never sold twice", r.ok == false and data(ada).gilt == 5000)
Fortune.page(data(bo)).rank = 7
data(bo).gems = 300
r = act(bo, { act = "key", what = "gems" })
check("or for Gems", r.ok == true and page(bo).key == true and data(bo).gems == 50)

---------------------------------------------------------------------------------------------------
-- 3. Flying in, and home
---------------------------------------------------------------------------------------------------
r = askAs(ada, { op = "go", id = "island" })
check("with the key: the jet flies them in", r.ok == true and ada:GetAttribute("Attraction") == "island")
check("...beside the jet, on the island", (ada.root.CFrame.Position - (O + Plan.Arrival.Position)).Magnitude < 6)
check("...their livery and their light, on them for every screen", ada:GetAttribute("JetLivery") == "ivory" and ada:GetAttribute("IslandTheme") == "golden")
check("...and the flight counted", page(ada).flights == 1)

---------------------------------------------------------------------------------------------------
-- 4. The day's pearls
---------------------------------------------------------------------------------------------------
local day = Plan.day(T)
local today = Plan.pearlsFor(day)
check("five pearls a day, the same for everyone", #today == 5 and table.concat(Plan.pearlsFor(day), ",") == table.concat(today, ","))
check("...new places the next day", table.concat(Plan.pearlsFor(day + 1), ",") ~= table.concat(today, ","))
state = askAs(ada, { op = "state", id = "island" })
check("the screen is told where today's lie, and none taken", #state.pearlSpots == 5 and state.pearlTaken[1] == false)
standOn(ada, Vector3.new(-132, 6, -150))
r = act(ada, { act = "pearl", n = 1 })
check("from the airstrip: nothing (swim down beside it)", r.ok == false and string.find(r.why, "beside it", 1, true) ~= nil)
local giltBefore = data(ada).gilt
standOn(ada, Plan.PEARL_SPOTS[today[1]], 0.5)
r = act(ada, { act = "pearl", n = 1 })
check("beside it: brought up, and paid", r.ok == true and r.got == 1 and data(ada).gilt == giltBefore + 250 and page(ada).pearls == 1)
r = act(ada, { act = "pearl", n = 1 })
check("...once a day", r.ok == false)
r = act(ada, { act = "pearl", n = 9 })
check("a pearl that isn't today's: refused", r.ok == false)
data(ada).gems = 0
giltBefore = data(ada).gilt
for i = 2, 5 do
	standOn(ada, Plan.PEARL_SPOTS[today[i]], 0.5)
	r = act(ada, { act = "pearl", n = i })
end
check("all five in a day: a little more Gilt", r.ok == true and r.got == 5 and r.set == Plan.PEARL_SET_GILT and data(ada).gilt == giltBefore + 4 * 250 + Plan.PEARL_SET_GILT, r.set, data(ada).gilt - giltBefore)
check("...and never a Gem: those come only from Robux", r.gems == nil and data(ada).gems == 0)
T += 86400
state = askAs(ada, { op = "state", id = "island" })
check("the next day: five new pearls to find", state.pearlTaken[1] == false and page(ada).pearls == 5)

---------------------------------------------------------------------------------------------------
-- 5. The sunset toast
---------------------------------------------------------------------------------------------------
standOn(ada, Vector3.new(0, 6, 0))
r = act(ada, { act = "toast" })
check("away from the Lookout: no toast", r.ok == false and string.find(r.why, "Lookout", 1, true) ~= nil)
giltBefore = data(ada).gilt
standOn(ada, Plan.Places.summit.at + Vector3.new(4, 0, 2))
r = act(ada, { act = "toast" })
check("at the Lookout: the toast, once a day", r.ok == true and data(ada).gilt == giltBefore + 300 and r.friends == 0)
r = act(ada, { act = "toast" })
check("...not twice", r.ok == false)
friendsWith["901:902"] = true
stand(bo, Layout.Terrace.arrival)
askAs(bo, { op = "go", id = "island" })
standOn(bo, Plan.Places.summit.at + Vector3.new(-3, 0, 1))
giltBefore = data(bo).gilt
r = act(bo, { act = "toast" })
check("a friend toasting in the same few minutes: a little more", r.ok == true and r.friends == 1 and data(bo).gilt == giltBefore + 350, r.friends)

---------------------------------------------------------------------------------------------------
-- 6. The postcards
---------------------------------------------------------------------------------------------------
standOn(ada, Vector3.new(0, 6, 0))
r = act(ada, { act = "postcard", what = "jet" })
check("a postcard from far off: refused", r.ok == false)
giltBefore = data(ada).gilt
for _, p in Plan.Postcards do
	standOn(ada, p.at, 2)
	r = act(ada, { act = "postcard", what = p.id })
end
local sent = last(ada, "postcard")
check("every postcard spot: the set, Gilt once (the day's soft cap applies, as everywhere), and the badge", r.ok == true and r.count == 6 and sent.paid > 0 and data(ada).gilt == giltBefore + sent.paid and (function()
	for _, a in awards do
		if a.p == ada and a.key == "postcards" then
			return true
		end
	end
	return false
end)())
check("...told to the screen (to frame the view)", last(ada, "postcard") ~= nil and last(ada, "postcard").count == 6)

---------------------------------------------------------------------------------------------------
-- 7. Liveries, the island's light, the Exchange
---------------------------------------------------------------------------------------------------
data(ada).gilt = 1000
r = act(ada, { act = "livery", what = "riviera" })
check("a livery without the Gilt: its price", r.ok == false and r.why == "Riviera is 12,000 Gilt.", r.why)
data(ada).gilt = 20000
r = act(ada, { act = "livery", what = "riviera" })
check("bought: owned for good, and worn at once", r.ok == true and page(ada).liveries.riviera == true and ada:GetAttribute("JetLivery") == "riviera" and data(ada).gilt == 8000)
r = act(ada, { act = "livery", what = "noir" })
check("back to the house's own (always yours): free", r.ok == true and ada:GetAttribute("JetLivery") == "noir" and data(ada).gilt == 8000)
r = act(ada, { act = "livery", what = "aurora" })
check("a Robux livery: only the purchase window is opened (never given)", r.ok == false and r.prompted == true and offered[#offered].product == "jetAurora" and page(ada).liveries.aurora == nil)
r = act(ada, { act = "theme", what = "azure" })
check("an island light: bought and set", r.ok == true and ada:GetAttribute("IslandTheme") == "azure" and data(ada).gilt == 0)
r = act(ada, { act = "theme", what = "nothing" })
check("a light that isn't the island's: refused", r.ok == false)
r = act(ada, { act = "exchange", what = "suite_coralthrone" })
check("the Exchange: not enough pearls, how many it is", r.ok == false and string.find(r.why, "60 pearls", 1, true) ~= nil, r.why)
r = act(ada, { act = "exchange", what = "suite_shelllamp" })
check("...not enough for the lamp either (5 pearls)", r.ok == false)
page(ada).pearls = 20
r = act(ada, { act = "exchange", what = "suite_shelllamp" })
check("enough: the island's piece, in the Suite's collection", r.ok == true and data(ada).owned.suite_shelllamp == true and page(ada).pearls == 5)
r = act(ada, { act = "exchange", what = "suite_shelllamp" })
check("...once", r.ok == false)
check("every Exchange piece is a real piece for the Suite", (function()
	for _, e in Plan.Exchange do
		local item = Wardrobe.get(e.id)
		if not item or item.kind ~= "suite" or item.source ~= "island" then
			return false
		end
	end
	return true
end)())

---------------------------------------------------------------------------------------------------
-- 8. Requests that aren't the island's
---------------------------------------------------------------------------------------------------
r = act(ada, { act = "pearl", n = 1.5 })
check("a pearl that isn't a whole number: refused", r.ok == false)
r = askAs(ada, { op = "act", id = "island", act = "key", gilt = 1 })
check("a request with anything else in it: refused", r.ok == false)
r = act(ada, { act = "gift" })
check("something the island doesn't do: refused", r.ok == false)

---------------------------------------------------------------------------------------------------
-- 9. Home
---------------------------------------------------------------------------------------------------
advance(3)
r = askAs(ada, { op = "home" })
check("home again: back in the Jet Lounge", r.ok == true and ada:GetAttribute("Attraction") == nil and Layout.zoneAt(ada.root.CFrame.Position) == "terrace", ada.root.CFrame.Position)

---------------------------------------------------------------------------------------------------
-- 10. The Maison Directory's cards, and the first-time notes
---------------------------------------------------------------------------------------------------
do
	-- (A guest new to the house: no key, no invitation.)
	local cy = H.guest("Cy", 903)
	advance(1)
	local d = askAs(cy, { op = "directory" })
	local cards = d and d.cards or {}
	check("the Directory: a card from the server for every attraction", d.ok == true and cards.luxe ~= nil and cards.basement ~= nil and cards.executive ~= nil and cards.gala ~= nil and cards.island ~= nil)
	check("...the island closed without the Island Key, with what opens it (the rank, both prices)", cards.island.open == false and cards.island.keyRank == "Tycoon" and cards.island.keyRankAt == 100000 and cards.island.keyGilt == 25000 and cards.island.keyGems == 250 and cards.island.rankReady == false, string.format("%s %s %s %s %s %s", tostring(cards.island.open), tostring(cards.island.keyRank), tostring(cards.island.keyRankAt), tostring(cards.island.keyGilt), tostring(cards.island.keyGems), tostring(cards.island.rankReady)))
	check("...the Executive Suite closed without an invitation, with how one is earned", cards.executive.open == false and cards.executive.invites == 0 and cards.executive.inviteHaul == 8000 and cards.executive.invitePrice == 25000)
	check("...Steal a Luxe, the Basement and the Grand Ballroom open to everyone, with the figures", cards.luxe.open == true and cards.basement.open == true and cards.basement.stages == 16 and cards.gala.open == true and cards.gala.galaGilt == 1200)
	local da = askAs(ada, { op = "directory" })
	check("...the island open to the guest who holds the key", da.cards.island.open == true)
	check("...and, standing in the Jet Lounge, the island is the one whose door is here", da.here == "island" and da.inside == nil, da.here)
	local ex = module("ServerScriptService", "Server", "Attractions", "Executive")
	ex.invite(Attractions.ctx, cy, "owner")
	d = askAs(cy, { op = "directory" })
	check("...an invitation opens the Suite's card (one is spent going up)", d.cards.executive.open == true and d.cards.executive.invites == 1)
	d = askAs(cy, { op = "directory", gilt = 100 })
	check("a Directory request with anything else in it: refused", d.ok == false)
	-- The first time in: the screen is told so, once ever.
	local entered = {}
	for _, m in ada.inbox do
		if m.op == "entered" and m.id == "island" then
			table.insert(entered, m)
		end
	end
	check("the first flight in: told it's the first time (how it works, on the screen)", #entered >= 1 and entered[1].first == true)
	check("...and noted in the record's one-time flags", data(ada).flags.guide_island == true and Attractions.firstLook(data(ada), "island") == false)
	advance(3)
	local again = askAs(ada, { op = "go", id = "island" })
	local latest = nil
	for i = #ada.inbox, 1, -1 do
		if ada.inbox[i].op == "entered" then
			latest = ada.inbox[i]
			break
		end
	end
	check("...after that, never again", again.ok == true and latest ~= nil and latest.first == false)
	advance(3)
	askAs(ada, { op = "home" })
	-- The rooms' guide cards (the Vault) and the Grand Auction's: once each, nothing paid.
	local giltBefore, gemsBefore = data(cy).gilt, data(cy).gems
	local r = askAs(cy, { op = "guide", what = "vault" })
	check("a room's guide card: the first time, said so", r.ok == true and r.first == true)
	r = askAs(cy, { op = "guide", what = "vault" })
	check("...and only once (kept in the record)", r.ok == true and r.first == false and data(cy).flags.guide_vault == true)
	r = askAs(cy, { op = "guide", what = "auction" })
	check("the Grand Auction's: once too", r.ok == true and r.first == true)
	check("...and nothing is paid for any of it", data(cy).gilt == giltBefore and data(cy).gems == gemsBefore)
	r = askAs(cy, { op = "guide", what = "gilt" })
	check("a guide card that isn't the house's: refused", r.ok == false)
	r = askAs(cy, { op = "guide", what = string.rep("v", 40) })
	check("...or one far too long", r.ok == false)
end

H.finish()

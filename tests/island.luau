--!nocheck
-- Luxury Island on the server (server/Attractions/Island, IslandBuild, World/Lobbies), under Lune
-- on a fake clock, in the house's test harness: the Jet Lounge on the Terrace; the island built
-- (its places, its prompts, within its budget; the jet's airstair on the carpet and the way home;
-- no pearl hidden under a deck; its unseen edge); the Island Key (a Tycoon's, for Gilt or Gems:
-- its price and its rank shown, never taken twice); the flight in and home; the day's pearls (the
-- same five for everyone, only from the water beside them, once each, all five a little more,
-- paid exactly as shown even past the day's soft cap); the sunset toast (once a day, at the
-- Lookout, reached by the summit path; more with friends, for both of them, and friends on the
-- island told); the postcards; liveries and the island's light (for Gilt or Gems, worn on the
-- guest for every screen; the Robux two only offered); the Pearl Exchange; Island Standing
-- (a day flown in counts once, however many flights); a guest carried out to sea flown home; and
-- requests that aren't the island's refused.
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
-- The notices a guest has been sent since inbox position `from`, by title.
local function noticed(g, title, from)
	for i = (from or 0) + 1, #g.inbox do
		local m = g.inbox[i]
		if m.op == "notice" and m.title == title then
			return m
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
local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
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
		if p:GetAttribute("Act") == "postcard" then
			kinds.postcardReach = p.MaxActivationDistance
		end
	end
end
check("the island is one of the attractions, entered from the Terrace", AttractionList.byId.island ~= nil and AttractionList.byId.island.room == "terrace")
check("its prompts: the arch, the way home, the Livery Desk, the Exchange, the toast, six postcards", kinds["go:"] == 1 and kinds["home:"] == 1 and kinds["panel:liveries"] == 1 and kinds["panel:exchange"] == 1 and kinds["act:toast"] == 1 and kinds["act:postcard"] == 6)
check("Build 103: ...and the summit path's two ends (up to the Lookout, down to the gardens)", kinds["act:path"] == 2, kinds["act:path"])
check("Build 103: a postcard's prompt never reaches a guest the server would call too far from the frame", kinds.postcardReach == Plan.POSTCARD_PROMPT and Plan.POSTCARD_REACH >= Plan.POSTCARD_PROMPT + 4, kinds.postcardReach)
---------------------------------------------------------------------------------------------------
-- (Build 103) Open: it ships with comingSoon off. While the house sets it on (Build 98's "coming
-- soon"): no way in, no key sold, the arch never opens the key's card, the Directory says Coming
-- soon, even for a guest who holds the key.
---------------------------------------------------------------------------------------------------
do
	check("Build 103: the island ships open (comingSoon off)", Config.data.Attractions.island.comingSoon == false)
	Config.data.Attractions.island.comingSoon = true
	stand(ada, Layout.Terrace.arrival)
	data(ada).gilt = 1000000
	local soonGo = askAs(ada, { op = "go", id = "island" })
	check("closed (coming soon): no flight, and it says so", soonGo.ok == false and string.find(soonGo.why, "coming soon", 1, true) ~= nil, soonGo.why)
	local soonKey = act(ada, { act = "key" })
	check("...no key sold for it (no Gilt taken)", soonKey.ok == false and string.find(soonKey.why, "coming soon", 1, true) ~= nil and data(ada).gilt == 1000000 and page(ada).key ~= true, soonKey.why)
	check("...the arch doesn't open the key's card", Game.locked(Attractions.ctx, ada) == false)
	local card = Game.directory(Attractions.ctx, ada)
	check("...its Directory card: coming soon, not open", card.comingSoon == true and card.open == false)
	page(ada).key = true
	check("...even with the key: not open", Game.directory(Attractions.ctx, ada).open == false and askAs(ada, { op = "go", id = "island" }).ok == false)
	page(ada).key = nil
	data(ada).gilt = 0
	Config.data.Attractions.island.comingSoon = false
	check("...and open again the moment it's off", Game.directory(Attractions.ctx, ada).comingSoon == false and Game.locked(Attractions.ctx, ada) == true)
end

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
-- (Build 103) The jet's airstair comes down onto the red carpet, where the way home is, and the
-- guest steps out at the carpet's end.
do
	local foot = nil
	for _, d in isle.Airstrip.Jet:GetChildren() do
		if d.Name == "Step" and (not foot or d.CFrame.Position.Y < foot.Y) then
			foot = d.CFrame.Position
		end
	end
	local home = built.home.CFrame.Position
	local carpet = isle.Airstrip:FindFirstChild("RedCarpet")
	check("Build 103: the jet's airstair comes down at the way home (Fly home is at its foot)", foot ~= nil and flat(foot, O + Plan.Airstair) <= 2 and flat(foot, home) <= 4, foot and flat(foot, home))
	check("...onto the red carpet, and the guest steps out at the carpet's end", carpet ~= nil and foot ~= nil and flat(foot, carpet.CFrame.Position) <= carpet.Size.Z / 2 + 2 and flat(O + Plan.Arrival.Position, carpet.CFrame.Position) <= carpet.Size.Z / 2 + 6)
end
-- (Build 103) Every pearl spot is open water: none under a villa's deck, the pier or its walks.
check("Build 103: no pearl lies hidden under a villa's deck or the pier", (function()
	for _, d in isle.Overwater:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "VillaDeck" or d.Name == "Pier" or d.Name == "Walk") then
			local c, s = d.CFrame.Position, d.Size
			for i, p in Plan.PEARL_SPOTS do
				local w = O + p
				if math.abs(w.X - c.X) <= s.X / 2 + 1 and math.abs(w.Z - c.Z) <= s.Z / 2 + 1 then
					print("pearl spot " .. i .. " is under " .. d.Name)
					return false
				end
			end
		end
	end
	return true
end)())
-- (Build 103) The island's unseen edge, inside its area, all round.
do
	local ways = isle.Parent:FindFirstChild("IslandWays")
	local ok = ways ~= nil
	for _, name in { "EdgeWest", "EdgeEast", "EdgeSouth", "EdgeNorth" } do
		local w = ways and ways:FindFirstChild(name)
		ok = ok and w ~= nil and w.CanCollide == true and w.Transparency == 1 and AttractionList.areaAt(w.CFrame.Position) == "island"
	end
	check("Build 103: the island's waters have an unseen edge all round, just inside its area", ok)
	-- ...and everything on the island stands inside it (nothing cut off beyond it).
	local outside = {}
	local b = AttractionList.BOUNDS.island
	for _, d in isle:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(isle.Ground) then
			local p = d.CFrame.Position - O
			if p.X < b.min.X + Plan.EDGE_INSET or p.X > b.max.X - Plan.EDGE_INSET or p.Z < b.min.Z + Plan.EDGE_INSET or p.Z > b.max.Z - Plan.EDGE_INSET then
				table.insert(outside, d:GetFullName())
			end
		end
	end
	check("...and everything built on the island stands inside its edge", #outside == 0, outside[1])
end
-- (Build 103) Everywhere the island sets a guest down is clear of anything solid (a guest set down
-- in a bench or a hedge is stuck in it), and every postcard frame stands on its ground, clear of
-- everything round it, with room to stand behind it and look through.
do
	local function inside(p, at)
		local rel = p.CFrame:PointToObjectSpace(at)
		local h = p.Size / 2
		return math.abs(rel.X) <= h.X and math.abs(rel.Y) <= h.Y and math.abs(rel.Z) <= h.Z
	end
	-- The parts near a point (solid, or seen), the island's ground stand-ins aside.
	local all = {}
	for _, d in isle:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(isle.Ground) and (d.CanCollide or d.Transparency < 1) then
			table.insert(all, d)
		end
	end
	local function near(at, r, skip)
		local out = {}
		for _, p in all do
			if (p.CFrame.Position - at).Magnitude <= r + p.Size.Magnitude / 2 and not (skip and p:IsDescendantOf(skip)) then
				table.insert(out, p)
			end
		end
		return out
	end
	local function hit(parts, at, solidOnly)
		for _, p in parts do
			if (not solidOnly or p.CanCollide) and inside(p, at) then
				return p.Name .. " (" .. p.Parent.Name .. ")"
			end
		end
		return nil
	end
	local bad = {}
	for name, v in { arrival = Plan.Arrival.Position, ["the summit path's foot"] = Plan.SummitPath.footArrive.Position, ["the summit path's head"] = Plan.SummitPath.headArrive.Position } do
		local at = O + v
		local parts = near(at, 8)
		for dx = -0.8, 0.8, 0.8 do
			for dz = -0.8, 0.8, 0.8 do
				for _, dy in { 0.6, 1.5, 2.5, 3.5, 4.5 } do
					local h = hit(parts, at + Vector3.new(dx, dy, dz), true)
					if h then
						bad[name] = h
					end
				end
			end
		end
	end
	local list = {}
	for k, v in bad do
		table.insert(list, k .. " is in " .. v)
	end
	check("Build 103: everywhere the island sets a guest down is clear of anything solid", #list == 0, table.concat(list, "; "))
	list = {}
	for _, p in Plan.Postcards do
		local base = O + p.at
		local face = CFrame.lookAt(base, Vector3.new(O.X + p.look.X, base.Y, O.Z + p.look.Z))
		local own = isle:FindFirstChild("Postcard_" .. p.id)
		local parts = near(base, 12, own)
		local h = nil
		for x = -3.6, 3.6, 0.6 do
			for y = 0.6, 6.2, 0.8 do
				h = h or hit(parts, (face * CFrame.new(x, y, 0)).Position, false)
			end
		end
		for z = 1.2, 3.6, 0.6 do
			for x = -1.2, 1.2, 0.6 do
				for _, y in { 0.8, 2.4, 4 } do
					h = h or hit(parts, (face * CFrame.new(x, y, z)).Position, true)
				end
			end
		end
		-- (Its ground: something to stand on just under the frame's foot, or the island's own.)
		local ground = hit(near(base, 6), base - Vector3.new(0, 0.3, 0), true) ~= nil or math.abs(module("ServerScriptService", "Server", "Attractions", "IslandBuild").groundAt(p.at.X, p.at.Z) - p.at.Y) <= 0.6
		if h or not ground then
			table.insert(list, p.id .. ": " .. (h or "nothing under it"))
		end
	end
	check("Build 103: every postcard frame stands on its ground, clear, with room to stand behind it", #list == 0, table.concat(list, "; "))
end

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
check("Build 103: ...how far their Fortune has come toward the rank", state.keyRankAt == 100000 and type(state.fortune) == "number")
check("Build 103: ...and every reward the island pays, as the very sums paid", state.rewards ~= nil and state.rewards.pearl == 250 and state.rewards.pearlSet == 100 and state.rewards.toast == 300 and state.rewards.toastFriend == 50 and state.rewards.toastFriendsMost == 4 and state.rewards.toastMinutes == 3 and state.rewards.postcards == 1000)
check("Build 103: ...and that they stand in the Jet Lounge, not on the island", state.lounge == true and state.here == false)
r = act(ada, { act = "key" })
check("below a Tycoon: no key, and how far to go", r.ok == false and string.find(r.why, "Tycoon", 1, true) ~= nil and string.find(r.why, "100,000", 1, true) ~= nil, r.why)
Fortune.page(data(ada)).rank = 6
r = act(ada, { act = "key" })
check("a Tycoon without the Gilt: its price", r.ok == false and r.why == "The Island Key is 25,000 Gilt.", r.why)
data(ada).gilt = 30000
r = act(ada, { act = "key" })
check("a Tycoon with the Gilt: the key, for good", r.ok == true and page(ada).key == true and data(ada).gilt == 5000)
check("...and the card says so at once (the island is theirs, the jet ready here)", r.state ~= nil and r.state.key == true and r.state.lounge == true)
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
check("...and the flight counted (the day's first: a day on the island)", page(ada).flights == 1 and page(ada).flightDays == 1)
state = askAs(ada, { op = "state", id = "island" })
check("Build 103: the card knows they're on the island", state.here == true and state.lounge == false)

---------------------------------------------------------------------------------------------------
-- 4. The day's pearls
---------------------------------------------------------------------------------------------------
local day = Plan.day(T)
local today = Plan.pearlsFor(day)
check("five pearls a day, the same for everyone", #today == 5 and table.concat(Plan.pearlsFor(day), ",") == table.concat(today, ","))
check("...new places the next day", table.concat(Plan.pearlsFor(day + 1), ",") ~= table.concat(today, ","))
state = askAs(ada, { op = "state", id = "island" })
check("the screen is told where today's lie, and none taken", #state.pearlSpots == 5 and state.pearlTaken[1] == false and state.pearlsGot == 0)
standOn(ada, Vector3.new(-132, 6, -150))
r = act(ada, { act = "pearl", n = 1 })
check("from the airstrip: nothing (swim down beside it)", r.ok == false and string.find(r.why, "beside it", 1, true) ~= nil)
local spot1 = Plan.PEARL_SPOTS[today[1]]
standOn(ada, Vector3.new(spot1.X, Plan.SEA + 3.3, spot1.Z))
r = act(ada, { act = "pearl", n = 1 })
check("Build 103: from a deck or the pier above it: nothing (in the water only)", r.ok == false and string.find(r.why, "beside it", 1, true) ~= nil)
standOn(ada, Vector3.new(spot1.X + Plan.PEARL_REACH + Plan.PEARL_SLACK + 2, Plan.SEA - 4, spot1.Z))
r = act(ada, { act = "pearl", n = 1 })
check("...nor from well across the water", r.ok == false)
-- (Past the day's soft cap on earned Gilt: the island's pearl still pays exactly what's shown.)
data(ada).giltDay = { day = math.floor(H.fakeOs.time() / 86400), earned = 10000000 }
local giltBefore = data(ada).gilt
standOn(ada, Vector3.new(spot1.X + Plan.PEARL_REACH + 1, Plan.SEA - 4, spot1.Z))
r = act(ada, { act = "pearl", n = 1 })
check("swimming beside it (as the server sees a swimmer, a moment behind): brought up, and paid", r.ok == true and r.got == 1 and data(ada).gilt == giltBefore + 250 and page(ada).pearls == 1, r.why)
check("Build 103: ...exactly the Gilt the card shows, even past the day's soft cap", r.gilt == state.rewards.pearl and r.state.pearlsGot == 1)
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
data(ada).giltDay = { day = -1, earned = 0 }
T += 86400
state = askAs(ada, { op = "state", id = "island" })
check("the next day: five new pearls to find", state.pearlTaken[1] == false and page(ada).pearls == 5)

---------------------------------------------------------------------------------------------------
-- 5. The summit path, and the sunset toast
---------------------------------------------------------------------------------------------------
standOn(ada, Vector3.new(0, 6, 0))
r = act(ada, { act = "toast" })
check("away from the Lookout: no toast", r.ok == false and string.find(r.why, "Lookout", 1, true) ~= nil)
r = act(ada, { act = "path", what = "up" })
check("Build 103: the summit path from far off: refused, and where it starts", r.ok == false and string.find(r.why, "foot of the Lookout's stair", 1, true) ~= nil, r.why)
r = act(ada, { act = "path", what = "sideways" })
check("...a way it doesn't go: refused", r.ok == false)
standOn(ada, Plan.SummitPath.foot)
r = act(ada, { act = "path", what = "up" })
check("Build 103: from the foot of the Lookout's stair, the summit path takes them up to the Lookout", r.ok == true and flat(ada.root.CFrame.Position, O + Plan.SummitPath.headArrive.Position) < 2 and ada.root.CFrame.Position.Y > O.Y + Plan.Places.summit.at.Y and Attractions.inside(ada) == "island", r.why)
-- (A friend flies in meanwhile: they hear of the toast when it's raised.)
friendsWith["901:902"] = true
stand(bo, Layout.Terrace.arrival)
askAs(bo, { op = "go", id = "island" })
local boInbox = #bo.inbox
giltBefore = data(ada).gilt
r = act(ada, { act = "toast" })
check("at the Lookout: the toast, once a day", r.ok == true and data(ada).gilt == giltBefore + 300 and r.friends == 0)
check("Build 103: ...and a friend on the island hears of it, with the window to join (real, and said as it is)", noticed(bo, "A toast at the Lookout", boInbox) ~= nil and string.find(noticed(bo, "A toast at the Lookout", boInbox).line, "within 3 minutes", 1, true) ~= nil)
r = act(ada, { act = "toast" })
check("...not twice", r.ok == false)
standOn(bo, Plan.Places.summit.at + Vector3.new(-3, 0, 1))
giltBefore = data(bo).gilt
local adaGilt, adaInbox = data(ada).gilt, #ada.inbox
r = act(bo, { act = "toast" })
check("a friend toasting in the same few minutes: a little more", r.ok == true and r.friends == 1 and data(bo).gilt == giltBefore + 350, r.friends)
check("Build 103: ...and the friend who toasted first has the same, told who joined them", data(ada).gilt == adaGilt + 50 and noticed(ada, "A toast together", adaInbox) ~= nil and string.find(noticed(ada, "A toast together", adaInbox).line, "+50 Gilt", 1, true) ~= nil)
check("...each friend counted once for each toast", Game.toasts()[1].friends == 1)
r = act(ada, { act = "path", what = "down" })
check("Build 103: the summit path back down, from the Lookout to the gardens", r.ok == true and flat(ada.root.CFrame.Position, O + Plan.SummitPath.footArrive.Position) < 2, r.why)
r = act(ada, { act = "path", what = "down" })
check("...and only from its head", r.ok == false)

---------------------------------------------------------------------------------------------------
-- 6. The postcards
---------------------------------------------------------------------------------------------------
standOn(ada, Vector3.new(0, 6, 0))
r = act(ada, { act = "postcard", what = "jet" })
check("a postcard from far off: refused", r.ok == false)
giltBefore = data(ada).gilt
local inboxAt = #ada.inbox
for _, p in Plan.Postcards do
	standOn(ada, p.at, 2)
	r = act(ada, { act = "postcard", what = p.id })
end
local sent = last(ada, "postcard")
-- (Build 90: an Island Standing rank reached on the way pays its own Gilt, told on its own.)
local standingGilt = 0
for i = inboxAt + 1, #ada.inbox do
	if ada.inbox[i].op == "islandStanding" then
		standingGilt += tonumber(ada.inbox[i].gilt) or 0
	end
end
check("every postcard spot: the set, Gilt once, and the badge", r.ok == true and r.count == 6 and sent.paid > 0 and data(ada).gilt == giltBefore + sent.paid + standingGilt and (function()
	for _, a in awards do
		if a.p == ada and a.key == "postcards" then
			return true
		end
	end
	return false
end)())
check("Build 103: ...paid in full, the very sum the card shows", sent.paid == state.rewards.postcards and r.state.postcardsPaid == true and #r.state.postcardList == 6)
check("...told to the screen (to frame the view)", last(ada, "postcard") ~= nil and last(ada, "postcard").count == 6)
standOn(ada, Plan.Postcards[1].at, 2)
r = act(ada, { act = "postcard", what = Plan.Postcards[1].id })
check("...and never paid twice", r.ok == true and last(ada, "postcard").paid == 0, r.why)

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
-- (Build 90) Island Standing: what's done on the island, counted toward a rank.
do
	local pg = page(ada)
	local pts = Plan.standingPoints(pg.pearlsAll, pg.sunsetsAll, (function()
		local n = 0
		for _ in pg.postcards do
			n += 1
		end
		return n
	end)(), pg.flightDays + pg.flightsBefore)
	check("Build 90: Island Standing counts pearls, sunsets, postcards and days flown in", pts > 0 and Plan.standingPoints(2, 1, 1, 1) == 2 + 3 + 2 + 1 and Plan.standingOf(0) == 1 and Plan.standingOf(35) == 3 and select(2, Plan.standingOf(35)) == 80 and select(2, Plan.standingOf(500)) == nil)
	local st = askAs(ada, { op = "state", id = "island" }).standing
	check("...the guest's board says their rank and how far to the next", st ~= nil and st.points == pts and st.name == Plan.Standing[Plan.standingOf(pts)].name)
	r = act(ada, { act = "theme", what = "starlit" })
	check("the Starlit lights can't be bought: they come with Islander", r.ok == false and r.why == "Starlit comes with Island Standing: Islander." and page(ada).themes.starlit == nil and data(ada).gilt == 0, r.why)
	r = act(ada, { act = "livery", what = "patron" })
	check("...nor the Island Patron livery: it comes with Patron of the Island", r.ok == false and r.why == "Island Patron comes with Island Standing: Patron of the Island." and page(ada).liveries.patron == nil, r.why)
	-- Up to Patron of the Island at once: every rank on the way paid, once each.
	pg.pearlsAll = 80
	local giltWas = data(ada).gilt
	local before = #ada.inbox
	local heardBefore = #broadcasts
	Game.standingCheck(Attractions.ctx, ada, pg)
	local told = 0
	for i = before + 1, #ada.inbox do
		if ada.inbox[i].op == "islandStanding" then
			told += 1
		end
	end
	local paidTo = pg.standingPaid
	check("a rank reached pays its Gilt, every rank on the way, each told", told >= 2 and paidTo >= 4 and data(ada).gilt > giltWas, told, paidTo)
	check("...and opens what comes with it: the Starlit lights, the Patron's livery", pg.themes.starlit == true and pg.liveries.patron == true)
	advance(8)
	check("Build 103: ...and the house hears of an Islander or better (the herald's own pace and gaps kept)", (function()
		for i = heardBefore + 1, #broadcasts do
			local b = broadcasts[i]
			if b.remote == "Empire" and b.message.op == "feat" and b.message.kind == "island" and string.find(tostring(b.message.line), "Island Standing", 1, true) then
				return true
			end
		end
		for i = before + 1, #ada.inbox do
			local m = ada.inbox[i]
			if m.op == "feat" and m.kind == "island" and string.find(tostring(m.line), "Island Standing", 1, true) then
				return true
			end
		end
		return false
	end)())
	local giltNow = data(ada).gilt
	Game.standingCheck(Attractions.ctx, ada, pg)
	check("...once: never paid again", data(ada).gilt == giltNow and pg.standingPaid == paidTo)
	r = act(ada, { act = "theme", what = "starlit" })
	check("earned: chosen like any other", r.ok == true and ada:GetAttribute("IslandTheme") == "starlit")
	-- A rank reached is never shown taken back.
	pg.pearlsAll = 0
	st = askAs(ada, { op = "state", id = "island" }).standing
	check("...and the board never shows a rank below one reached", st.rank >= paidTo, st.rank)
	pg.pearlsAll = 80
end
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
-- 9. Home; a day flown in counts once; carried out to sea, flown home
---------------------------------------------------------------------------------------------------
advance(3)
r = askAs(ada, { op = "home" })
check("home again: back in the Jet Lounge", r.ok == true and ada:GetAttribute("Attraction") == nil and Layout.zoneAt(ada.root.CFrame.Position) == "terrace", ada.root.CFrame.Position)
do
	-- (Build 103) Flying in and out at will never farms Island Standing: a day counts once.
	local pg = page(ada)
	local flights, days = pg.flights, pg.flightDays
	for _ = 1, 3 do
		advance(3)
		askAs(ada, { op = "go", id = "island" })
		advance(3)
		askAs(ada, { op = "home" })
	end
	-- (The clock moved on a day in section 4: the first of these is that day's first flight.)
	check("Build 103: three more flights in a day: each counted, but the day only once for Standing", pg.flights == flights + 3 and pg.flightDays == days + 1, string.format("%d flights, %d days", pg.flights, pg.flightDays))
	T += 86400
	advance(3)
	askAs(ada, { op = "go", id = "island" })
	check("...and the next day's first flight is a new day on the island", pg.flightDays == days + 2 and Attractions.inside(ada) == "island", pg.flightDays)
	-- A record from before Build 103 (every flight counted): its flights go on counting as they
	-- did, set once; its standing, rank and the Gilt paid for it are unchanged, nothing paid twice.
	local old = { attractions = { island = { key = true, keyAt = T - 3 * 86400, flights = 40, pearlsAll = 10, standingPaid = 3 } } }
	local og = Game.page(Attractions.ctx, old)
	local giltWas = data(ada).gilt
	Game.standingCheck(Attractions.ctx, ada, og)
	check("Build 103: an older record's flights still count as before (its standing, rank and Gilt paid unchanged)", og.flightsBefore == 40 and og.flightDays == 0 and Plan.standingOf(Plan.standingPoints(og.pearlsAll, og.sunsetsAll, 0, og.flightDays + og.flightsBefore)) == 3 and og.standingPaid == 3 and data(ada).gilt == giltWas)
	og.flights = 45
	og = Game.page(Attractions.ctx, old)
	check("...set once: later flights never add to them", og.flightsBefore == 40 and og.flights == 45)
	local fresh = Game.page(Attractions.ctx, { attractions = {} })
	check("...and a new record starts at nothing", fresh.flightsBefore == 0 and fresh.flightDays == 0 and fresh.flights == 0)
	-- Carried out past the island's waters (by anything): let go of, and flown home, not left adrift.
	advance(6)
	local inboxBefore = #ada.inbox
	stand(ada, O + Vector3.new(AttractionList.BOUNDS.island.max.X + 80, -1, 0))
	advance(2.5)
	check("Build 103: carried out to sea past the island's edge: flown home to the Jet Lounge, and told", Attractions.inside(ada) == nil and Layout.zoneAt(ada.root.CFrame.Position) == "terrace" and noticed(ada, "Home from the island", inboxBefore) ~= nil, ada.root.CFrame.Position)
	-- Moved by the house somewhere else entirely: left where the house put them.
	advance(3)
	askAs(ada, { op = "go", id = "island" })
	advance(6)
	local foyer = Layout.Foyer.spawn.Position
	stand(ada, foyer)
	advance(2.5)
	check("...but someone the house moved elsewhere is left where the house put them", Attractions.inside(ada) == nil and flat(ada.root.CFrame.Position, foyer) < 1)
	stand(ada, Layout.Terrace.arrival)
	advance(3)
end

---------------------------------------------------------------------------------------------------
-- 9b. (Build 103) Every prompt on the island does what it says, pressed as a guest presses it
-- (E or a tap: the prompt's Triggered); a seated guest flies in and home standing; and nobody is
-- ever on the island without having flown in.
---------------------------------------------------------------------------------------------------
do
	local prompts = {}
	for _, p in H.tagged.AttractionPrompt or {} do
		if p:GetAttribute("Attraction") == "island" then
			local key = p:GetAttribute("Kind") .. ":" .. tostring(p:GetAttribute("Panel") or p:GetAttribute("Act") or "") .. ":" .. tostring(p:GetAttribute("What") or "")
			prompts[key] = p
		end
	end
	local function press(key, g)
		local p = prompts[key]
		if not p then
			return false
		end
		advance(0.3)
		p.Triggered:Fire(g)
		advance(0.3)
		return true
	end
	-- A seat on the Terrace (a lounger): boarding from it, the guest leaves the seat behind.
	local function seatGuest(g)
		local seat = H.Instance.new("Seat")
		seat.Anchored = true
		local weld = H.Instance.new("Weld")
		weld.Name = "SeatWeld"
		weld.Parent = seat
		g.humanoid.SeatPart = seat
		g.humanoid.Sit = true
		return seat
	end
	advance(3)
	local lounger = seatGuest(ada)
	check("the Jet Lounge's arch, pressed with the key: the jet flies them in", press("go::", ada) and Attractions.inside(ada) == "island")
	check("...from a lounger: stood up first, the seat left behind", lounger:FindFirstChild("SeatWeld") == nil and ada.humanoid.Sit == false)
	local before = #ada.inbox
	check("the Livery Desk: opens the Jet Lounge's card at Liveries", press("panel:liveries:", ada) and last(ada, "panel") ~= nil and last(ada, "panel").id == "island" and last(ada, "panel").which == "liveries" and #ada.inbox > before)
	check("the Pearl Exchange's kiosk: opens it at the Exchange", press("panel:exchange:", ada) and last(ada, "panel").which == "exchange")
	standOn(ada, Vector3.new(0, 6, 0))
	before = #ada.inbox
	press("act:toast:", ada)
	check("Raise a glass, away from the Lookout: says why, nothing paid", noticed(ada, "Not just now", before) ~= nil and page(ada).toastDay ~= Plan.day(T))
	standOn(ada, Plan.SummitPath.foot)
	check("Up to the Lookout (at the stair's foot): up on the Lookout's deck", press("act:path:up", ada) and flat(ada.root.CFrame.Position, O + Plan.SummitPath.headArrive.Position) < 2)
	before = #ada.inbox
	local giltBefore = data(ada).gilt
	press("act:toast:", ada)
	check("Raise a glass, on the Lookout: the toast, its Gilt, and said so", noticed(ada, "To the sunset", before) ~= nil and data(ada).gilt == giltBefore + 300 and last(ada, "toasted") ~= nil)
	local summitCard = nil
	for _, p in Plan.Postcards do
		if p.id == "summit" then
			summitCard = p
		end
	end
	standOn(ada, summitCard.at)
	before = #ada.inbox
	check("Take a postcard, at the Lookout's frame: the postcard, framed on their screen", press("act:postcard:summit", ada) and last(ada, "postcard") ~= nil and last(ada, "postcard").id == "summit" and #ada.inbox > before)
	standOn(ada, Plan.SummitPath.head)
	check("Down to the gardens (at the stair's head): down at the stair's foot", press("act:path:down", ada) and flat(ada.root.CFrame.Position, O + Plan.SummitPath.footArrive.Position) < 2)
	-- Fly home, from a lounger by the pool: home, standing.
	standOn(ada, Plan.Airstair)
	local poolside = seatGuest(ada)
	advance(3)
	check("Fly home (the jet's airstair): home in the Jet Lounge", press("home::", ada) and Attractions.inside(ada) == nil and Layout.zoneAt(ada.root.CFrame.Position) == "terrace")
	check("...stood up from any seat first, so they arrive standing", poolside:FindFirstChild("SeatWeld") == nil and ada.humanoid.Sit == false)
	ada.humanoid.SeatPart = nil
	-- Set down on the island without flying in (an owner's "bring"): flown home after a few moments.
	local sam = H.guest("Sam", 912)
	advance(0.5)
	stand(sam, O + Plan.Arrival.Position)
	before = #sam.inbox
	advance(Plan.STRAY_SECONDS - 2)
	check("Build 103: set down on the island without flying in: not left there", Attractions.inside(sam) == nil and AttractionList.areaAt(sam.root.CFrame.Position) == "island")
	advance(3)
	check("...flown home to the Jet Lounge after a few moments, and told why", Layout.zoneAt(sam.root.CFrame.Position) == "terrace" and noticed(sam, "Home from the island", before) ~= nil, sam.root.CFrame.Position)
	-- (The owner, whose own powers take them anywhere, is left where they went.)
	local ownerWas = Attractions.isOwner
	Attractions.isOwner = function(p)
		return p == sam
	end
	stand(sam, O + Plan.Arrival.Position)
	advance(Plan.STRAY_SECONDS + 2)
	check("...the owner aside", AttractionList.areaAt(sam.root.CFrame.Position) == "island")
	Attractions.isOwner = ownerWas
	sam.Parent = nil
	advance(0.5)
	stand(ada, Layout.Terrace.arrival)
	advance(3)
end

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
	check("...the island closed without the Island Key, with what opens it (the rank, both prices)", cards.island.open == false and cards.island.keyRank == "Tycoon" and cards.island.keyRankAt == 100000 and cards.island.keyGilt == 25000 and cards.island.keyGems == 250 and cards.island.rankReady == false and cards.island.comingSoon == false, string.format("%s %s %s %s %s %s", tostring(cards.island.open), tostring(cards.island.keyRank), tostring(cards.island.keyRankAt), tostring(cards.island.keyGilt), tostring(cards.island.keyGems), tostring(cards.island.rankReady)))
	check("...the Executive Suite closed without an invitation, with how one is earned", cards.executive.open == false and cards.executive.invites == 0 and cards.executive.inviteHaul == 8000 and cards.executive.invitePrice == 25000)
	check("...Steal a Luxe, the Basement and the Grand Ballroom open to everyone, with the figures", cards.luxe.open == true and cards.basement.open == true and cards.basement.stages == 32 and cards.gala.open == true and cards.gala.galaGilt == 1200)
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

-- (Build 104) Sitting on the island: every seat on it stands above the ground it's on (a guest sat
-- there sits on the cushion, not in the sand), every beach deck stands clear of the sand at all
-- four corners, and every seat really sits a guest who walks up to it, one by one.
do
	local IB = module("ServerScriptService", "Server", "Attractions", "IslandBuild")
	local Seating = module("ServerScriptService", "Server", "Seating")
	local island = nil
	for _, d in workspace:GetDescendants() do
		if d.Name == "LuxuryIsland" or (d:IsA("Model") and d:FindFirstChild("SouthBeach")) then
			island = d
			break
		end
	end
	local spots, decks = {}, {}
	for _, d in (island or workspace):GetDescendants() do
		if d:IsA("BasePart") and d.Name == "SitSpot" then
			local p = d.CFrame.Position - O
			if math.abs(p.X) < 600 and math.abs(p.Z) < 600 and p.Y > -60 and p.Y < 300 then
				table.insert(spots, d)
			end
		elseif d:IsA("BasePart") and d.Name == "BeachDeck" then
			table.insert(decks, d)
		end
	end
	local low = {}
	for _, s in spots do
		local p = s.CFrame.Position - O
		local ground = IB.groundAt(p.X, p.Z)
		if p.Y - ground < 0.9 then
			table.insert(low, string.format("%s at (%.0f, %.1f, %.0f) ground %.1f", s.Parent and s.Parent.Name or "?", p.X, p.Y, p.Z, ground))
		end
	end
	check(string.format("every one of the island's %d seats stands on its piece, above the ground under it", #spots), #spots >= 20 and #low == 0, table.concat(low, "; "))
	local buried = {}
	for _, d in decks do
		local c = d.CFrame.Position - O
		local top = c.Y + d.Size.Y / 2
		for _, dx in { -1, 1 } do
			for _, dz in { -1, 1 } do
				local x, z = c.X + dx * d.Size.X / 2, c.Z + dz * d.Size.Z / 2
				if top < IB.groundAt(x, z) + 0.25 then
					table.insert(buried, string.format("(%.0f, %.0f) top %.1f ground %.1f", x, z, top, IB.groundAt(x, z)))
				end
			end
		end
	end
	check(string.format("every one of the beach's %d decks stands clear of the sand at all four corners", #decks), #decks >= 8 and #buried == 0, table.concat(buried, "; "))
	-- Sit in every one, walking up to each.
	run(Seating.start)
	local sitAsk = Remotes.funcs.SitAsk.OnServerInvoke
	local refused = {}
	local sat = 0
	for _, s in spots do
		local id = s:GetAttribute("SeatId")
		if type(id) ~= "number" then
			table.insert(refused, "unnumbered " .. (s.Parent and s.Parent.Name or "?"))
			continue
		end
		bo.Character = bo.body
		bo.root.CFrame = s.CFrame * CFrame.new(0, 0, -2)
		advance(0.6)
		local r
		run(function()
			r = sitAsk(bo, { op = "sit", seat = id })
		end)
		if type(r) == "table" and r.ok == true and Seating.isSeated(bo) then
			sat += 1
		else
			table.insert(refused, (s.Parent and s.Parent.Name or "?") .. ": " .. tostring(r and r.why))
		end
		advance(0.6)
		run(function()
			sitAsk(bo, { op = "stand" })
		end)
	end
	check(string.format("each island seat sits a guest who walks up to it (%d of %d)", sat, #spots), #refused == 0, table.concat(refused, "; "))
	print(string.format("  (island seats checked: %d, sat in: %d; beach decks: %d)", #spots, sat, #decks))
end

H.finish()

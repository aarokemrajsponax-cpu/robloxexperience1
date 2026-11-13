--!nocheck
-- The Satchel on the server (server/Satchel): what a guest carries as items in their inventory,
-- decided from their saved data. The Executive Suite's stun pistol once it's taken, a decoy while
-- one is packed or carried and not yet thrown, then the squad's brainrots and starred curios
-- (rarest first, seven at most); the tools themselves; and every flex checked (only what's in
-- the satchel, never gear, never twice in three seconds, never a malformed ask).
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/satchel.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles = H.module, H.profiles
local Remotes = H.Remotes

H.stubs["ServerScriptService.Server.Staff.Rig"] = function()
	return {
		build = function()
			error("no rigs under Lune")
		end,
		look = function()
			return {}
		end,
	}
end

local Plan = module("ReplicatedStorage", "Shared", "Executive")
local Layout = module("ReplicatedStorage", "Shared", "Layout")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local BrainrotList = module("ReplicatedStorage", "Shared", "Brainrots")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Game = module("ServerScriptService", "Server", "Attractions", "Executive")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Herald = module("ServerScriptService", "Server", "Herald")
local Satchel = module("ServerScriptService", "Server", "Satchel")
local Curios = module("ServerScriptService", "Server", "Curios")

local T = 2000
Game.clock = function()
	return T
end
Game.ray = function()
	return nil
end
Game.clear = function()
	return true
end
Game.walk = function() end

local workspace = H.game:GetService("Workspace")
Lobbies.build(workspace)
local cy = H.guest("Cy", 703)
run(Herald.start)
run(Attractions.start)
local O = Game.origin()

local ask = Remotes.funcs.AttractionAsk.OnServerInvoke
local function askAs(g, request)
	advance(0.4)
	local r
	run(function()
		r = ask(g, request)
	end)
	return r
end
local function data(g)
	return profiles[g].Data
end
local function page(g)
	return Game.page(Attractions.ctx, data(g))
end

local changed = 0
Game.carriedChanged = function(p)
	if p == cy then
		changed += 1
	end
end
Satchel.carried = function(p)
	return Game.carried(Attractions.ctx, p)
end
local function keys()
	local out = {}
	for _, e in Satchel.wanted(data(cy), Satchel.carried(cy)) do
		table.insert(out, e.key)
	end
	return table.concat(out, ",")
end

---------------------------------------------------------------------------------------------------
-- 1. The Executive Suite's gear
---------------------------------------------------------------------------------------------------
check("nothing carried before the Quartermaster", keys() == "", keys())
local r = askAs(cy, { op = "act", id = "executive", act = "sidearm" })
check("the stun pistol is carried once it's taken (and the satchel is told)", r.ok == true and keys() == "gear:sidearm" and changed == 1, keys())
data(cy).gilt = 100000
r = askAs(cy, { op = "act", id = "executive", act = "gear", what = "decoy" })
check("a decoy packed for the next run is carried too", r.ok == true and keys() == "gear:sidearm,gear:decoy" and changed == 2, keys())
r = askAs(cy, { op = "act", id = "executive", act = "gear", what = "vest" })
check("...other gear (worn, not used) isn't an item in the hand", r.ok == true and keys() == "gear:sidearm,gear:decoy" and changed == 3, keys())
page(cy).invites = 1
cy.Character = cy.body
cy.root.CFrame = CFrame.new(Layout.Midnight.arrival + Vector3.new(0, 3, 0))
r = askAs(cy, { op = "go", id = "executive" })
check("going up: the decoy moves from the pack into the run, still carried", r.ok == true and next(page(cy).kit) == nil and keys() == "gear:sidearm,gear:decoy" and changed == 4, r.why or changed)
cy.Character = cy.body
cy.root.CFrame = CFrame.new(O + Vector3.new(0, 3, Plan.Cameras[1].at.Z))
r = askAs(cy, { op = "act", id = "executive", act = "decoy" })
check("thrown in the hallway, the decoy is gone from the satchel", r.ok == true and keys() == "gear:sidearm" and changed == 5, r.why or changed)
advance(3)
r = askAs(cy, { op = "home" })
check("home again: the pistol stays (it's the guest's for good)", keys() == "gear:sidearm" and changed == 6, changed)

---------------------------------------------------------------------------------------------------
-- 2. The squad and starred curios
---------------------------------------------------------------------------------------------------
local byRarity = {}
local rots = {}
for _, c in CurioList.List do
	if BrainrotList.is(c.id) then
		table.insert(rots, c.id)
	elseif c.rarity ~= "Limited" and c.rarity ~= "Secret" then
		byRarity[c.rarity] = byRarity[c.rarity] or {}
		table.insert(byRarity[c.rarity], c.id)
	end
end
table.sort(rots)
local d = data(cy)
local bag = Curios.bag(d)
local rot = rots[1]
bag.items[rot] = 1
bag.squad = { ids = { rot }, mut = { [rot] = "gold" } }
local ranks = {}
for rarity in byRarity do
	table.insert(ranks, rarity)
end
table.sort(ranks, function(a, b)
	return CurioList.RarityRank[a] < CurioList.RarityRank[b]
end)
local lowest, highest = ranks[1], ranks[#ranks]
local common, epic = byRarity[lowest][1], byRarity[highest][1]
bag.items[common] = 2
bag.items[epic] = 1
bag.favs[common] = true
bag.favs[epic] = true
bag.favs[rot] = true -- (already there as one of the squad: once only)
local w = Satchel.wanted(d, Satchel.carried(cy))
check("after the gear: the squad, then starred curios, rarest first", #w == 4 and w[2].key == "flex:" .. rot and w[3].key == "flex:" .. epic and w[4].key == "flex:" .. common, keys())
check("...a gold brainrot is named and marked so", w[2].mut == "gold" and string.find(w[2].name, "Gold", 1, true) == 1, w[2].name)
local unheld
for _, c in CurioList.List do
	if not unheld and not BrainrotList.is(c.id) and (bag.items[c.id] or 0) == 0 then
		unheld = c.id
	end
end
bag.favs[unheld] = true
check("...a star on something not held puts nothing in the satchel", #Satchel.wanted(d, Satchel.carried(cy)) == 4)
local n = 0
for _, list in byRarity do
	for _, id in list do
		if n < 12 then
			bag.items[id] = (bag.items[id] or 0) + 1
			bag.favs[id] = true
			n += 1
		end
	end
end
w = Satchel.wanted(d, Satchel.carried(cy))
local flexes = 0
for _, e in w do
	if e.kind == "flex" then
		flexes += 1
	end
end
check("never more than seven to flex (with the gear, nine keys)", flexes == Satchel.FLEX_MOST and #w == 8, #w)

---------------------------------------------------------------------------------------------------
-- 3. Flexes, checked
---------------------------------------------------------------------------------------------------
local carried = Satchel.carried(cy)
local e, why = Satchel.check(d, carried, "flex:" .. rot, nil, 100)
check("a flex of what's in the satchel is allowed", e ~= nil and e.id == rot, why)
e, why = Satchel.check(d, carried, "flex:" .. rot, 98.5, 100)
check("...but not twice in three seconds", e == nil and why == "soon")
e, why = Satchel.check(d, carried, "flex:not-a-curio", nil, 100)
check("...nor something not in it", e == nil and why == "not held")
e, why = Satchel.check(d, carried, "gear:sidearm", nil, 100)
check("...nor the gear (it isn't for showing off)", e == nil and why == "not held")
e, why = Satchel.check(d, carried, { "flex:" .. rot }, nil, 100)
check("...nor a malformed ask", e == nil and why == "malformed")
check("a flex from a guest with nothing in hand is refused, and nothing is sent", Satchel.flex(cy, "flex:" .. rot) == false)

---------------------------------------------------------------------------------------------------
-- 4. The tools themselves
---------------------------------------------------------------------------------------------------
local pistol = Satchel.make(Satchel.wanted(d, carried)[1])
check("the pistol: a tool with a handle, a chrome slide and an ice muzzle, never dropped", pistol:IsA("Tool") and pistol:FindFirstChild("Handle") ~= nil and pistol:FindFirstChild("Muzzle") ~= nil and pistol.CanBeDropped == false and pistol:GetAttribute("SatchelId") == "sidearm" and pistol.Name == "Stun Pistol")
local medal = Satchel.make(w[2])
local held = medal:FindFirstChild("Handle") and medal.Handle:FindFirstChild("Held")
check("a brainrot: held up on a disc in its colour, its glyph on it", held ~= nil and held:IsA("BillboardGui") and medal:GetAttribute("SatchelKind") == "flex" and medal:GetAttribute("Mutation") == "gold")

H.finish()

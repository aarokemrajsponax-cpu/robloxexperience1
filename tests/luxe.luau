--!nocheck
-- Steal a Luxe on the server (server/Attractions, Attractions/Luxe, World/Lobbies), under Lune on a
-- fake clock, in the house's test harness: the Luxe Lounge in the Velvet Room (its entrance, its
-- treadmills, its board), going in only from there, a way through the residence that can be walked,
-- taking a piece (only within reach, only with room in the bag), the weight of the bag, the guards
-- (seeing, chasing, giving up, catching: the bag lost), banking at the car (the Estate, the cash
-- share, the brainrots, the day's Gems), the upgrades (their real prices, never the screen's),
-- Stride from the treadmills, and every way out letting go of the guest.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/luxe.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles, broadcasts = H.module, H.profiles, H.broadcasts
local Remotes, Config = H.Remotes, H.Config

-- (No dressed rigs under Lune: the guards are plain figures, as they would be if Roblox couldn't
-- build one.)
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

local Layout = module("ReplicatedStorage", "Shared", "Layout")
local AttractionList = module("ReplicatedStorage", "Shared", "Attractions")
local Plan = module("ReplicatedStorage", "Shared", "Luxe")
local Speed = module("ReplicatedStorage", "Shared", "Speed")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Luxe = module("ServerScriptService", "Server", "Attractions", "Luxe")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Fortune = module("ServerScriptService", "Server", "Fortune")
local Herald = module("ServerScriptService", "Server", "Herald")
local C = Config.data.Attractions.luxe

-- The guards: they stand still unless a test lets them walk; nothing stands between them and a
-- guest unless a test puts a wall there.
local walking = false
local walled = false
Luxe.walk = function(g, target, speed)
	if not walking then
		return
	end
	local at = g.root.CFrame.Position
	local d = Vector3.new(target.X - at.X, 0, target.Z - at.Z)
	if d.Magnitude < 1e-3 then
		return
	end
	local stepBy = math.min(d.Magnitude, speed * 0.1)
	local to = at + d.Unit * stepBy
	g.root.CFrame = CFrame.lookAt(to, to + d.Unit)
end
Luxe.clear = function()
	return not walled
end

local tallies, awards = {}, {}
Attractions.tally = function(p, stat, n)
	tallies[p.UserId .. ":" .. stat] = (tallies[p.UserId .. ":" .. stat] or 0) + n
end
Attractions.award = function(p, key)
	table.insert(awards, { p = p, key = key })
end
local seated = {}
Attractions.isSeated = function(p)
	return seated[p] == true
end

local workspace = H.game:GetService("Workspace")
Lobbies.build(workspace)
-- (Guests in the house when it opens: the attractions watch their respawns.)
local ava = H.guest("Ava", 501)
local ben = H.guest("Ben", 502)
run(Herald.start)
run(Attractions.start)

local O = Luxe.origin()
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
local function count(g, op)
	local n = 0
	for _, m in g.inbox do
		if m.op == op then
			n += 1
		end
	end
	return n
end
local function data(g)
	return profiles[g].Data
end
local function page(g)
	return Luxe.page(Attractions.ctx, data(g))
end
-- Stands a guest at a point in the world (on their feet: the root three studs up).
local function stand(g, at, toward)
	g.Character = g.body
	local p = at + Vector3.new(0, 3, 0)
	g.root.CFrame = if toward then CFrame.lookAt(p, toward + Vector3.new(0, 3, 0)) else CFrame.new(p)
end
-- In the residence (from its origin).
local function standIn(g, v, toward)
	stand(g, O + v, if toward then O + toward else nil)
end
local function steps(n)
	for _ = 1, n do
		advance(0.1)
	end
end
local lobby = Layout.Velvet.arrival
local function inLounge(g)
	stand(g, lobby)
end
-- Every guard out of the way (far off, facing away), but `except`.
local function parkGuards(except)
	for _, g in Luxe.guards do
		if g ~= except then
			g.root.CFrame = CFrame.lookAt(O + Vector3.new(900, 3, 900), O + Vector3.new(1000, 3, 1000))
			g.state, g.target = "patrol", nil
			g.suspicion = {}
		end
	end
end
local function giltOf(g)
	return data(g).gilt
end

---------------------------------------------------------------------------------------------------
-- 1. The plan
---------------------------------------------------------------------------------------------------
check("three wings, each deeper one sharper", #Plan.Wings == 3 and Plan.Wings[1].sharp < Plan.Wings[2].sharp and Plan.Wings[2].sharp < Plan.Wings[3].sharp)
do
	local ok = true
	for _, s in Plan.Spots do
		if Plan.wingAt(s.at) ~= s.wing then
			ok = false
		end
	end
	check("every plinth stands in its own wing", ok)
	local crowns = 0
	for _, s in Plan.Spots do
		if s.fixed == "crownJewel" then
			crowns += 1
		end
	end
	check("the Crown Jewel has one plinth of its own, in the Strongroom", crowns == 1 and Plan.Spots[21].fixed == "crownJewel" and Plan.Spots[21].wing == 3)
	local never = true
	for i = 0, 999 do
		local p = Plan.pick(3, i / 1000)
		if p.id == "crownJewel" or p.wing ~= 3 then
			never = false
		end
	end
	check("a plinth in the Strongroom is never given the Crown Jewel by chance", never)
	local worth = { 0, 0, 0 }
	local n = { 0, 0, 0 }
	for _, p in Plan.Pieces do
		if p.weight > 0 then
			worth[p.wing] += p.worth
			n[p.wing] += 1
		end
	end
	check("the deeper the wing, the more its pieces are worth", worth[1] / n[1] < worth[2] / n[2] and worth[2] / n[2] < worth[3] / n[3])
	for _, p in Plan.Pieces do
		if p.curio then
			check("the brainrot " .. p.name .. " is a real collectible", CurioList.byId[p.curio] ~= nil, p.curio)
		end
	end
	for _, w in Plan.Patrols do
		local inside = true
		for _, pt in w.points do
			if Plan.wingAt(pt) ~= w.wing then
				inside = false
			end
		end
		check("a guard's round stays in his wing (wing " .. w.wing .. ")", inside)
	end
	check("the bank is in the courtyard, out of every wing", Plan.wingAt(Vector3.new(0, 0, -108)) == nil and Plan.inBank(Vector3.new(0, 0, -108)))
	check("Stride: no points is level 1; the last step is the top", Plan.strideLevel(0, C.stride) == 1 and Plan.strideLevel(C.stride[#C.stride], C.stride) == #C.stride and select(2, Plan.strideLevel(C.stride[#C.stride], C.stride)) == nil)
end

---------------------------------------------------------------------------------------------------
-- 2. What's built: the residence, far from the house, and the Luxe Lounge in the Velvet Room
---------------------------------------------------------------------------------------------------
check("the residence is built at its own origin, far from the Maison", (O - Vector3.new(-3000, 0, -3000)).Magnitude < 1e-3 and AttractionList.areaAt(O + Vector3.new(0, 3, 0)) == "luxe" and AttractionList.areaAt(Layout.Foyer.spawn.Position) == nil)
do
	local full = 0
	for _, s in Luxe.spots do
		if s.piece and s.model and s.model.Parent then
			full += 1
		end
	end
	check("every plinth has a piece on it when the house opens (21)", full == 21, full)
	check("the Crown Jewel is on its plinth", Luxe.spots[21].piece and Luxe.spots[21].piece.id == "crownJewel")
	check("eight guards walk the residence", #Luxe.guards == 8, #Luxe.guards)
	local torches = 0
	for _, g in Luxe.guards do
		if g.model:FindFirstChild("Torch", true) then
			torches += 1
		end
	end
	check("every guard carries a torch (where he looks, everyone can see)", torches == 8, torches)
	local take = Luxe.spots[1].model:FindFirstChild("Take", true)
	check("a piece can be taken with a prompt", take ~= nil and take:IsA("ProximityPrompt"))
end
local R = Layout.Velvet
local belts = H.tagged.LuxeTreadmill or {}
do
	check("the Luxe Lounge has five treadmills, one of them golden", #belts == 5, #belts)
	local golden, inRoom = 0, true
	for _, b in belts do
		if b:GetAttribute("Golden") then
			golden += 1
		end
		local p = b.CFrame.Position
		if p.X - 3 < R.minX or p.X + 3 > R.maxX or p.Z - 6 < R.minZ or p.Z + 6 > R.maxZ then
			inRoom = false
		end
		if Layout.zoneAt(p + Vector3.new(0, 3, 0)) ~= "velvet" then
			inRoom = false
		end
	end
	check("one golden treadmill", golden == 1, golden)
	check("every treadmill stands wholly inside the Velvet Room", inRoom)
	local moving = true
	for _, b in belts do
		if b.AssemblyLinearVelocity.Magnitude < 10 then
			moving = false
		end
	end
	check("every treadmill's belt really runs (it carries you off unless you walk)", moving)
	local kinds = {}
	for _, p in H.tagged.AttractionPrompt or {} do
		kinds[p:GetAttribute("Kind") .. ":" .. p:GetAttribute("Attraction")] = p
	end
	check("the Lounge has the way in to Steal a Luxe", kinds["go:luxe"] ~= nil)
	check("and its upgrades board", kinds["panel:luxe"] ~= nil)
	local veil = kinds["go:luxe"] and kinds["go:luxe"].Parent
	check("the way in stands inside the Velvet Room", veil ~= nil and Layout.zoneAt(veil.CFrame.Position) == "velvet")
end

-- A way through the residence that can be walked: from the arrival to the car, through the front
-- door, the Garden Hall, a doorway into the Long Gallery, down it and into the Strongroom, to the
-- Crown Jewel. Nothing solid stands in it (a guest is about two studs across).
do
	local solids = {}
	for _, d in workspace.Attractions:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and not d:IsDescendantOf(workspace.Attractions.StealALuxe.Pieces) then
			table.insert(solids, d)
		end
	end
	local function blocked(p)
		for _, s in solids do
			local rel = s.CFrame:PointToObjectSpace(p)
			local half = s.Size / 2
			if math.abs(rel.X) <= half.X + 1 and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z + 1 then
				return s
			end
		end
		return nil
	end
	local function walk(points)
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local n = math.ceil((b - a).Magnitude)
			for k = 0, n do
				local p = a:Lerp(b, k / n)
				for _, y in { 1.5, 3, 4.5 } do
					local hit = blocked(O + Vector3.new(p.X, y, p.Z))
					if hit then
						return string.format("%s at (%.0f, %.0f)", hit:GetFullName(), p.X, p.Z)
					end
				end
			end
		end
		return nil
	end
	local route = {
		Plan.Arrival.Position,
		Vector3.new(-10, 0, -118),
		Vector3.new(-10, 0, -100), -- beside the car, in the bank
		Vector3.new(0, 0, -84),
		Vector3.new(0, 0, -64), -- through the front door
		Vector3.new(0, 0, -50),
		Vector3.new(-30, 0, -50), -- round the fountain
		Vector3.new(-35, 0, -20),
		Vector3.new(-35, 0, 8), -- through the west doorway
		Vector3.new(-35, 0, 66), -- down the west gallery
		Vector3.new(0, 0, 66),
		Vector3.new(0, 0, 78), -- into the Strongroom
		Vector3.new(0, 0, 112), -- before the Crown Jewel
	}
	local why = walk(route)
	check("a way from the arrival, past the car, through every wing to the Crown Jewel can be walked", why == nil, why)
	local east = walk({ Vector3.new(0, 0, -50), Vector3.new(30, 0, -50), Vector3.new(35, 0, -20), Vector3.new(35, 0, 8), Vector3.new(35, 0, 66), Vector3.new(0, 0, 66) })
	check("and the east doorway into the Long Gallery too", east == nil, east)
	local home = walk({ Plan.Arrival.Position, Vector3.new(0, 0, -130) })
	check("the arch home is a few steps from the arrival, with nothing in the way", home == nil and (Plan.HomeArch.Position - Plan.Arrival.Position).Magnitude < 10, home)
end

---------------------------------------------------------------------------------------------------
-- 3. Going in: only from the Lounge
---------------------------------------------------------------------------------------------------
data(ava).gilt = 0
stand(ava, Layout.Foyer.spawn.Position)
local r = askAs(ava, { op = "go", id = "luxe" })
check("from the Foyer, the way in is refused: its entrance is in the Luxe Lounge", r.ok == false and r.why == "Its entrance is in The Luxe Lounge, off the Foyer.", r.why)
check("and nothing changed", ava:GetAttribute("Attraction") == nil and Attractions.inside(ava) == nil)
r = askAs(ava, { op = "go", id = "vault" })
check("a place that isn't an attraction is refused", r.ok == false and r.why == "There's no such place.")
inLounge(ava)
seated[ava] = true
r = askAs(ava, { op = "go", id = "luxe" })
check("from a table, the way in is refused", r.ok == false and r.why == "Leave your table first.", r.why)
seated[ava] = nil
r = askAs(ava, { op = "go", id = "luxe", gilt = 999 })
check("a request with anything else in it is refused", r.ok == false and Attractions.inside(ava) == nil)
r = askAs(ava, { op = "go", id = "luxe" })
check("from the Lounge, a guest goes in", r.ok == true and Attractions.inside(ava) == "luxe", r.why)
check("their screen is told (and shows the HUD only now)", ava:GetAttribute("Attraction") == "luxe" and last(ava, "entered") ~= nil and last(ava, "entered").id == "luxe")
local arrived = ava.root.CFrame.Position
check("they arrive in the courtyard, at the residence's arrival", (arrived - (O + Plan.Arrival.Position + Vector3.new(0, 3, 0))).Magnitude < 0.01, arrived)
check("with no Stride and nothing carried, they move at the house's pace", ava:GetAttribute("SpeedTrained") == nil)
steps(2)
local hud = last(ava, "luxe")
check("the HUD is told the bag, its room, the wing and the worth", hud ~= nil and #hud.bag == 0 and hud.capacity == C.bag[1] and hud.worth == 0 and hud.wing == "The courtyard")
r = askAs(ava, { op = "go", id = "luxe" })
check("once in, asking again is refused", r.ok == false and r.why == "You're already in Steal a Luxe.", r.why)

---------------------------------------------------------------------------------------------------
-- 4. Taking a piece
---------------------------------------------------------------------------------------------------
parkGuards(nil)
steps(25) -- (past the few seconds nobody notices a guest who has just come in)
local function spotNear(g, id)
	local s = Luxe.spots[id]
	local top = s.top.CFrame.Position - O
	standIn(g, Vector3.new(top.X, 0, top.Z - 4))
	return s
end
standIn(ava, Vector3.new(0, 0, -40))
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 1 })
check("a piece out of reach can't be taken", r.ok == false and r.why == "Get closer to it.", r.why)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 1.5 })
check("a plinth that isn't one is refused", r.ok == false and r.why == "Not that.")
local s1 = spotNear(ava, 1)
local first = s1.piece
local trustedWas = Attractions.ctx.trusted
Attractions.ctx.trusted = function()
	return false
end
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 1 })
check("just after a move nobody could make, nothing can be taken", r.ok == false and r.why == "Not just now.", r.why)
Attractions.ctx.trusted = trustedWas
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 1 })
check("within reach, the piece is taken", r.ok == true and r.piece == first.id, r.why)
check("it's in the bag", #Luxe.runs[ava].bag == 1 and Luxe.runs[ava].bag[1] == first)
check("and gone from its plinth for everyone", s1.piece == nil and s1.model == nil)
check("the guest is told what they took and its worth", last(ava, "took") ~= nil and last(ava, "took").worth == first.worth)
local slowed = ava:GetAttribute("SpeedTrained")
check("a piece in the bag slows them a little", type(slowed) == "number" and math.abs(slowed - (1 - C.weight)) < 1e-3, slowed)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 1 })
check("an empty plinth has nothing to take", r.ok == false and r.why == "Someone has been here before you.")
-- Through the prompt, as a guest would.
local s2 = spotNear(ava, 2)
local second = s2.piece
s2.model:FindFirstChild("Take", true).Triggered:Fire(ava)
check("the prompt on a piece takes it too", #Luxe.runs[ava].bag == 2 and Luxe.runs[ava].bag[2] == second)
spotNear(ava, 3)
askAs(ava, { op = "act", id = "luxe", act = "take", n = 3 })
check("a third: the bag (three to begin with) is full", #Luxe.runs[ava].bag == 3)
spotNear(ava, 4)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 4 })
check("a fourth doesn't fit, and the guest is told how to carry more", r.ok == false and string.find(r.why, "Your bag is full (3)", 1, true) ~= nil, r.why)
check("three pieces: slower again, but never below the slowest", math.abs(ava:GetAttribute("SpeedTrained") - math.max(C.slowest, 1 - 3 * C.weight)) < 1e-3)
steps(C.respawn * 10 + 5)
check("a plinth is given another piece of its wing a while later", s1.piece ~= nil and s1.piece.wing == 1 and s1.model ~= nil)

---------------------------------------------------------------------------------------------------
-- 5. Banking at the car
---------------------------------------------------------------------------------------------------
local bag = Luxe.runs[ava].bag
local worth = 0
for _, p in bag do
	worth += p.worth
end
local estateWas = Fortune.page(data(ava)).estate
local giltWas = giltOf(ava)
standIn(ava, Vector3.new(0, 0, -108))
steps(2)
local banked = last(ava, "banked")
check("walking up to the car with the bag banks it", banked ~= nil and banked.worth == worth and #Luxe.runs[ava].bag == 0, banked and banked.worth)
check("its whole worth goes to the Estate", Fortune.page(data(ava)).estate == estateWas + worth, Fortune.page(data(ava)).estate)
check("and a fifth of it to the purse in Gilt", giltOf(ava) - giltWas == banked.gilt and banked.gilt > 0 and banked.gilt <= math.floor(worth * Config.data.Fortune.cashShare + 0.5) * 2)
check("the haul is kept: one haul, its worth, the best", page(ava).hauls == 1 and page(ava).banked == worth and page(ava).best == worth)
check("the first haul is a record", banked.record == true)
check("speed is back to the guest's own with the bag empty", ava:GetAttribute("SpeedTrained") == nil)
check("tallied for the house's records", tallies["501:luxeHauls"] == 1 and tallies["501:luxeWorth"] == worth and tallies["501:luxeTaken"] == 3)
local n = count(ava, "banked")
steps(5)
check("standing by the car with nothing carried banks nothing more", count(ava, "banked") == n)

---------------------------------------------------------------------------------------------------
-- 6. The guards
---------------------------------------------------------------------------------------------------
local g1 = Luxe.guards[1]
parkGuards(g1)
-- A frame at `at` looking toward `toward` (on the level). (Lune's CFrame.lookAt turns a look down
-- +Z round the wrong way, so it's made from a turn about the vertical, as Roblox's would be.)
local function facing(at, toward)
	local d = toward - at
	return CFrame.new(at) * CFrame.Angles(0, math.atan2(-d.X, -d.Z), 0)
end
local function faceGuard(at, toward)
	g1.root.CFrame = facing(O + at + Vector3.new(0, 3, 0), O + toward + Vector3.new(0, 3, 0))
	g1.state, g1.target, g1.suspicion = "patrol", nil, {}
end
-- A guest standing in front of him, in his wing, in plain sight.
faceGuard(Vector3.new(0, 0, -50), Vector3.new(0, 0, 0))
local s5 = spotNear(ava, 5)
askAs(ava, { op = "act", id = "luxe", act = "take", n = 5 })
check("(a piece in the bag)", #Luxe.runs[ava].bag == 1)
faceGuard(Vector3.new(0, 0, -50), Vector3.new(0, 0, 0))
standIn(ava, Vector3.new(0, 0, -35))
steps(1)
check("in front of a guard, he starts to notice (not all at once)", (g1.suspicion[ava] or 0) > 0 and g1.state == "patrol", g1.suspicion[ava])
local hudNow = last(ava, "luxe")
steps(10)
check("seen long enough, he gives chase", g1.state == "chase" and g1.target == ava)
check("and the guest is told", last(ava, "spotted") ~= nil and last(ava, "spotted").wing == 1)
steps(2)
check("their screen shows the chase", last(ava, "luxe").chased == true)
-- Out of his wing: he gives up.
standIn(ava, Vector3.new(0, 0, -90))
steps(2)
check("out of his wing (in the courtyard), he gives up", g1.state ~= "chase" and g1.target == nil)
check("the bag is still theirs", #Luxe.runs[ava].bag == 1)
-- Behind him: unseen.
faceGuard(Vector3.new(0, 0, -50), Vector3.new(0, 0, 0))
standIn(ava, Vector3.new(0, 0, -62))
steps(15)
check("behind a guard, he doesn't see you", (g1.suspicion[ava] or 0) == 0 and g1.state ~= "chase")
-- Another wing: unseen.
faceGuard(Vector3.new(-35, 0, -10), Vector3.new(-35, 0, 40))
standIn(ava, Vector3.new(-35, 0, 6))
steps(15)
check("a guest in another wing is no business of his", (g1.suspicion[ava] or 0) == 0)
-- Behind a wall: unseen.
faceGuard(Vector3.new(0, 0, -50), Vector3.new(0, 0, 0))
standIn(ava, Vector3.new(0, 0, -35))
walled = true
steps(15)
check("behind a wall, he doesn't see you", (g1.suspicion[ava] or 0) == 0)
walled = false
-- Far off: unseen; nearer with ordinary shoes, seen; with the quietest shoes, unseen again.
faceGuard(Vector3.new(0, 0, -60), Vector3.new(0, 0, 0))
standIn(ava, Vector3.new(0, 0, -60 + C.seeRange + 2))
steps(15)
check("beyond his sight, unseen", (g1.suspicion[ava] or 0) == 0)
local d = C.seeRange * 0.8
faceGuard(Vector3.new(0, 0, -60), Vector3.new(0, 0, 0))
standIn(ava, Vector3.new(0, 0, -60 + d))
steps(4)
check("well within it, seen", (g1.suspicion[ava] or 0) > 0)
faceGuard(Vector3.new(0, 0, -60), Vector3.new(0, 0, 0))
page(ava).quiet = #C.quiet
standIn(ava, Vector3.new(0, 0, -60 + d))
steps(15)
check("with the quietest shoes, the same distance is too far for him", (g1.suspicion[ava] or 0) == 0)
page(ava).quiet = 1
-- Caught: the bag is lost and they're shown out to the courtyard.
faceGuard(Vector3.new(0, 0, -50), Vector3.new(0, 0, 0))
standIn(ava, Vector3.new(0, 0, -40))
steps(12)
check("(he's after them)", g1.state == "chase")
local carried = 0
for _, p in Luxe.runs[ava].bag do
	carried += p.worth
end
standIn(ava, Vector3.new(0, 0, -47))
steps(1)
local c = last(ava, "caught")
check("within his reach, the guest is caught", c ~= nil and c.lost == carried and c.n == 1, c and c.lost)
check("everything in the bag is lost", #Luxe.runs[ava].bag == 0)
check("they're shown out to the courtyard", (ava.root.CFrame.Position - (O + Plan.Arrival.Position + Vector3.new(0, 3, 0))).Magnitude < 0.01)
check("caught is counted", page(ava).caught == 1)
check("but they're still in the residence (they may try again)", Attractions.inside(ava) == "luxe")
faceGuard(Vector3.new(0, 0, -50), Vector3.new(0, 0, 0))
standIn(ava, Vector3.new(0, 0, -40))
steps(math.floor(C.caughtGrace * 10) - 5)
check("for a few seconds after, nobody notices them", (g1.suspicion[ava] or 0) == 0)
steps(15)
check("then they can be noticed again", (g1.suspicion[ava] or 0) > 0 or g1.state == "chase")
steps(15)
check("the plinth they emptied is filled again within seconds (not the usual wait)", s5.piece ~= nil and s5.model ~= nil)
-- He walks his rounds.
parkGuards(nil)
local g6 = Luxe.guards[6]
g6.root.CFrame = CFrame.new(g6.points[1] + Vector3.new(0, 3, 0))
g6.index, g6.state = 2, "patrol"
walking = true
standIn(ava, Vector3.new(0, 0, -108))
steps(80)
walking = false
check("a guard walks his round, point to point", g6.index ~= 2 or (g6.root.CFrame.Position - (g6.points[1] + Vector3.new(0, 3, 0))).Magnitude > 5)

---------------------------------------------------------------------------------------------------
-- 7. The rarest pieces: the brainrots, the Gems (a day's cap), the Crown Jewel
---------------------------------------------------------------------------------------------------
parkGuards(nil)
local spotC = Luxe.spots[21]
local function bankOne(g, s, piece)
	-- (A piece put on a plinth for the test, as the residence would.)
	if s.model then
		s.model:Destroy()
	end
	s.piece = nil
	s.back = 0
	steps(1)
	if piece then
		s.model:Destroy()
		s.piece = piece
		s.model = module("ServerScriptService", "Server", "Attractions", "LuxeBuild").piece(workspace.Attractions.StealALuxe.Pieces, s.top, piece, s.spot.id)
	end
	local top = s.top.CFrame.Position - O
	standIn(g, Vector3.new(top.X, 0, top.Z - 4))
	local res = askAs(g, { op = "act", id = "luxe", act = "take", n = s.spot.id })
	standIn(g, Vector3.new(0, 0, -108))
	steps(2)
	return res, last(g, "banked")
end
local gemsWas = data(ava).gems
local res, b2 = bankOne(ava, spotC, nil)
check("the Crown Jewel can be taken and banked", res.ok == true and b2 ~= nil and b2.worth == Plan.byId.crownJewel.worth and b2.pieces[1].id == "crownJewel", res.why)
check("it pays its Gems", b2.gems == Plan.byId.crownJewel.gems and data(ava).gems == gemsWas + Plan.byId.crownJewel.gems, b2.gems)
check("and earns its achievement", #awards > 0 and awards[#awards].key == "crownJewel")
steps(80)
local feat = nil
for _, bc in broadcasts do
	if bc.remote == "Empire" and bc.message.op == "feat" and bc.message.title == "The Crown Jewel" then
		feat = bc.message
	end
end
check("the house is told (a real feat, by a real guest)", feat ~= nil and feat.worth == b2.worth)
steps(C.respawn * 10 + 20 - 80)
check("the Crown Jewel comes back far more slowly than the rest (still gone after the usual wait)", spotC.piece == nil)
local res2, b3 = bankOne(ava, Luxe.spots[9], Plan.byId.ladro)
check("a brainrot piece banked is the guest's to keep as a brainrot", res2.ok == true and b3 ~= nil and b3.brainrots[1] == "ladroLussuoso" and (data(ava).curios.items.ladroLussuoso or 0) == 1, res2.why)
-- Gems: never more than the day's cap.
local paid = Plan.byId.crownJewel.gems
for i = 1, 6 do
	local _, b = bankOne(ava, Luxe.spots[17], Plan.byId.tiara)
	paid += b.gems
end
check("Gems from Steal a Luxe stop at the day's cap", paid == C.dailyGems, paid)

---------------------------------------------------------------------------------------------------
-- 8. Upgrades: the house's prices
---------------------------------------------------------------------------------------------------
data(ava).gilt = 1000
r = askAs(ava, { op = "act", id = "luxe", act = "upgrade", what = "bag" })
check("a bigger bag without the Gilt is refused, with its real price", r.ok == false and r.why == "That's 1,500 Gilt.", r.why)
check("and nothing is taken", data(ava).gilt == 1000 and page(ava).bag == 1)
data(ava).gilt = 2000
r = askAs(ava, { op = "act", id = "luxe", act = "upgrade", what = "bag" })
check("with it, the bag is bigger and its price paid exactly", r.ok == true and page(ava).bag == 2 and data(ava).gilt == 500 and r.upgrades.bag.now == "carries " .. C.bag[2] .. " pieces")
r = askAs(ava, { op = "act", id = "luxe", act = "upgrade", what = "bag", price = 0 })
check("a screen can't name its own price", r.ok == false and page(ava).bag == 2)
r = askAs(ava, { op = "act", id = "luxe", act = "upgrade", what = "wings" })
check("an upgrade there isn't is refused", r.ok == false and r.why == "There's no such upgrade.")
page(ava).banker = #C.banker
r = askAs(ava, { op = "act", id = "luxe", act = "upgrade", what = "banker" })
check("at the top, no further", r.ok == false and r.why == "That's as good as it gets.")
-- The banker's cut on what's banked.
local res3, b4 = bankOne(ava, Luxe.spots[1], Plan.byId.notes)
check("the banker's cut is added to what's banked", res3.ok == true and b4.worth == math.floor(Plan.byId.notes.worth * (1 + C.banker[#C.banker]) + 0.5) and b4.base == Plan.byId.notes.worth, b4 and b4.worth)
page(ava).banker = 1
data(ava).gems = 10
r = askAs(ava, { op = "act", id = "luxe", act = "golden" })
check("the golden treadmill without the Gems is refused, with its price", r.ok == false and r.why == "That's " .. C.goldenGems .. " Gems.", r.why)
data(ava).gems = C.goldenGems + 5
r = askAs(ava, { op = "act", id = "luxe", act = "golden" })
check("with them, it's theirs, for exactly its price", r.ok == true and page(ava).golden == true and data(ava).gems == 5)
r = askAs(ava, { op = "act", id = "luxe", act = "golden" })
check("and it isn't sold twice", r.ok == false and data(ava).gems == 5)
local st = askAs(ava, { op = "state", id = "luxe" })
check("the board is told every upgrade, its level and its next price", st.ok == true and st.upgrades.bag.level == 2 and st.upgrades.bag.price == C.bagPrice[3] and st.upgrades.quiet.price == C.quietPrice[2] and st.upgrades.golden == true and st.run ~= nil)

---------------------------------------------------------------------------------------------------
-- 9. Every way out lets go of the guest
---------------------------------------------------------------------------------------------------
local s6 = spotNear(ava, 6)
askAs(ava, { op = "act", id = "luxe", act = "take", n = 6 })
check("(a piece in the bag)", #Luxe.runs[ava].bag == 1)
r = askAs(ava, { op = "home" })
check("home: the guest is out", r.ok == true and Attractions.inside(ava) == nil and ava:GetAttribute("Attraction") == nil)
check("their screen is told, and what wasn't banked is lost (and they're told)", last(ava, "left") ~= nil and last(ava, "left").why == "home" and last(ava, "lostOnLeaving") ~= nil and Luxe.runs[ava] == nil)
check("they're back in the Luxe Lounge", Layout.zoneAt(ava.root.CFrame.Position) == "velvet")
check("and their speed is the house's again", ava:GetAttribute("SpeedTrained") == nil)
r = askAs(ava, { op = "home" })
check("home again from the house is refused", r.ok == false)
-- A respawn.
advance(3)
r = askAs(ava, { op = "go", id = "luxe" })
check("(in again)", r.ok == true)
run(function()
	ava.CharacterAdded:Fire()
end)
check("a respawn lets go of them", Attractions.inside(ava) == nil and last(ava, "left").why == "respawn")
-- Moved out of the residence some other way.
inLounge(ava)
advance(3)
r = askAs(ava, { op = "go", id = "luxe" })
check("(in again)", r.ok == true)
stand(ava, Layout.Foyer.spawn.Position)
steps(2)
check("moved back to the house some other way: let go of", Attractions.inside(ava) == nil and last(ava, "left").why == "away")
-- Too quickly.
inLounge(ava)
advance(3)
askAs(ava, { op = "go", id = "luxe" })
run(function()
	r = ask(ava, { op = "home" })
end)
check("straight back out is a moment too soon", r.ok == false and r.why == "One moment.", r.why)
advance(3)
check("then home", askAs(ava, { op = "home" }).ok == true)
-- The entrance's prompt.
inLounge(ava)
advance(3)
local veilPrompt
for _, p in H.tagged.AttractionPrompt or {} do
	if p:GetAttribute("Kind") == "go" and p:GetAttribute("Attraction") == "luxe" then
		veilPrompt = p
	end
end
veilPrompt.Triggered:Fire(ava)
check("the entrance's prompt takes a guest in", Attractions.inside(ava) == "luxe")
local arch
for _, d in workspace.Attractions.StealALuxe:GetDescendants() do
	if d:IsA("ProximityPrompt") and d.Name == "WayHome" then
		arch = d
	end
end
advance(3)
arch.Triggered:Fire(ava)
check("the arch home takes them home", Attractions.inside(ava) == nil and last(ava, "left").why == "home")
-- Quitting.
inLounge(ava)
advance(3)
askAs(ava, { op = "go", id = "luxe" })
ava.Parent = nil
steps(2)
check("quitting lets go of them", Attractions.inside(ava) == nil and Luxe.runs[ava] == nil)
ava.Parent = H.PlayersService

---------------------------------------------------------------------------------------------------
-- 10. Stride: the treadmills in the Lounge
---------------------------------------------------------------------------------------------------
local plain, golden
for _, b in belts do
	if b:GetAttribute("Golden") then
		golden = b
	else
		plain = plain or b
	end
end
stand(ben, (plain.CFrame * CFrame.new(0, 0.1, 0)).Position)
steps(10)
local pts = page(ben).stride
check("walking a treadmill builds Stride, about a point a second", pts > 0.8 and pts < 1.3, pts)
check("the guest's screen counts it", last(ben, "stride") ~= nil)
steps(C.stride[2] * 10)
check("enough Stride: the next level, and they're told", page(ben).stride >= C.stride[2] and last(ben, "strideUp") ~= nil and last(ben, "strideUp").level == 2)
stand(ben, lobby)
local was = page(ben).stride
steps(20)
check("off the treadmill, nothing", page(ben).stride == was)
stand(ben, (golden.CFrame * CFrame.new(0, 0.1, 0)).Position)
steps(20)
check("the golden treadmill does nothing for a guest without it", page(ben).stride == was)
page(ben).golden = true
steps(10)
check("with it, Stride comes twice as fast", math.abs(page(ben).stride - was - 2) < 0.4, page(ben).stride - was)
-- Stride in the residence (and only there).
check("Stride is no faster in the house itself", ben:GetAttribute("SpeedTrained") == nil)
inLounge(ben)
advance(3)
askAs(ben, { op = "go", id = "luxe" })
local level = Plan.strideLevel(page(ben).stride, C.stride)
local expect = 1 + (level - 1) * C.stridePerLevel
check("in the residence, Stride makes them faster", level >= 2 and math.abs((ben:GetAttribute("SpeedTrained") or 1) - expect) < 1e-3, ben:GetAttribute("SpeedTrained"))
local m = Config.data.Movement
check("the walk with Stride is faster than without", Speed.resolve(false, nil, nil, nil, expect) > Speed.resolve(false, nil, nil, nil, nil))
check("never past the residence's own cap", Speed.resolve(true, 3, 3, nil, 3) == m.trainedMaxSpeed)
check("and the house's cap stands for everyone without it", Speed.resolve(true, 3, 3, nil, nil) == m.maxSpeed)
check("a bag never slows anyone below the slowest", Luxe.speedOf(Attractions.ctx, page(ben), 100) >= C.slowest * expect - 1e-6)

-- A malformed request.
r = askAs(ben, "go")
check("a request that isn't one is refused", type(r) == "table" and r.ok == false)
r = askAs(ben, { op = "act", id = "luxe", act = "steal everything" })
check("a request the residence doesn't know is refused", r.ok == false and r.why == "That isn't something the house does.")

H.finish()

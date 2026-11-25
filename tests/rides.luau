--!nocheck
-- (Build 104) Luxury Island's rides (server/Attractions/IslandRides, shared/IslandCraft), under
-- Lune in the house's test harness: no garage left on the island and no garage cars; the Jet Ski
-- Hire, the helipad and the Day Yacht's berth with their prompts; a ride not yet theirs refused
-- with its price and the card's Rides page opened; bought with Gilt at exactly the price shown,
-- never twice, refused without the Gilt (nothing taken); a Robux ride not made in Creator Hub said
-- so (no window, nothing taken); a Robux receipt's grant; riding: the guest's own ride out at its
-- launch spot, sat at its helm, handed to their screen, one at a time; the rules every screen and
-- the server share (deep water only, the shore stops a ride, the ceiling); a ride somewhere it
-- can't be taken back; an empty ride put away; every ride put away when its rider leaves the
-- island or the house; the Day Yacht free, one captain, boarding, back to its berth; the
-- Sovereign's leap (near its rail only).
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/rides.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles = H.module, H.profiles
local Remotes, Config = H.Remotes, H.Config

local roblox = require("@lune/roblox")
-- (Build 104) A vehicle seat sits a guest like any seat.
roblox.implementMethod("VehicleSeat", "Sit", function(self, h)
	if type(h) == "table" then
		h.SeatPart = self
		return
	end
	local character = h.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = self.CFrame * CFrame.new(0, 2, 0)
	end
end)
roblox.implementMethod("VehicleSeat", "GetPropertyChangedSignal", function()
	return { Connect = function() return { Disconnect = function() end } end }
end)
-- (Build 104) A model's pivot (its primary part's frame, or its first part's), moving it moves
-- every part in it, as Roblox's PivotTo does.
local function pivotOf(m)
	local pp = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
	if pp then
		return pp.CFrame
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			return d.CFrame
		end
	end
	return CFrame.new()
end
roblox.implementMethod("Model", "GetPivot", function(self)
	return pivotOf(self)
end)
roblox.implementMethod("Model", "PivotTo", function(self, cf)
	local from = pivotOf(self)
	local delta = cf * from:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)
roblox.implementMethod("Model", "GetExtentsSize", function(self)
	local lo, hi = nil, nil
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			local p = d.CFrame.Position
			local h = d.Size / 2
			local a, b = p - h, p + h
			lo = if lo then Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
			hi = if hi then Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
		end
	end
	return if lo and hi then hi - lo else Vector3.zero
end)


local Layout = module("ReplicatedStorage", "Shared", "Layout")
local Plan = module("ReplicatedStorage", "Shared", "Island")
local Craft = module("ReplicatedStorage", "Shared", "IslandCraft")
local Ground = module("ReplicatedStorage", "Shared", "IslandGround")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Game = module("ServerScriptService", "Server", "Attractions", "Island")
local Rides = module("ServerScriptService", "Server", "Attractions", "IslandRides")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Herald = module("ServerScriptService", "Server", "Herald")

local T = 1795000000
Game.now = function()
	return T
end
local clock = 0
Rides.setClock(function()
	return clock
end)
local offered = {}
local onSale = {}
Rides.offer = function(p, product)
	table.insert(offered, { p = p, product = product })
	return true, nil
end
Rides.onSale = function(product)
	return onSale[product] == true
end

local workspace = H.game:GetService("Workspace")
Lobbies.build(workspace)
local ada = H.guest("Ada", 1901)
local bo = H.guest("Bo", 1902)
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
local function step(n)
	for _ = 1, n do
		clock += 0.3
		advance(0.3)
	end
end
local prompts = {}
for _, p in H.tagged.AttractionPrompt or {} do
	if p:GetAttribute("Attraction") == "island" then
		prompts[tostring(p:GetAttribute("Act")) .. ":" .. tostring(p:GetAttribute("What") or "")] = p
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
local function seatOf(g)
	return g.humanoid.SeatPart
end

---------------------------------------------------------------------------------------------------
-- 1. The island as built: no garage, the rides' places and prompts
---------------------------------------------------------------------------------------------------
local island = workspace:FindFirstChild("LuxuryIsland", true)
check("the island is built", island ~= nil)
local garage = false
for _, d in workspace:GetDescendants() do
	if d.Name == "GarageSign" or d.Name == "BayPad" or (d:GetAttribute("CarId") and tostring(d:GetAttribute("CarId")):sub(1, 5) == "coast") then
		garage = true
	end
end
check("no island garage: no bays, no garage sign, no garage cars", not garage)
check("the Jet Ski Hire, the helicopter, the Day Yacht's helm and its boarding, the Sovereign's gangway and leap: each with its prompt", prompts["ride:jetski"] ~= nil and prompts["ride:heli"] ~= nil and prompts["ride:yacht"] ~= nil and prompts["board:yacht"] ~= nil and prompts["board:sovereign"] ~= nil and prompts["leap:"] ~= nil)
check("the Jet Ski Hire stands on the sand, with its sign", workspace:FindFirstChild("JetSkiHire", true) ~= nil)
local rides = Rides.rides()
check("the Day Yacht waits at its berth, its helm a real vehicle seat", rides.yacht ~= nil and rides.yacht.seat:IsA("VehicleSeat") and rides.yacht.model:GetAttribute("CraftKind") == "yacht")
check("...where the Aurelia was moored: no second yacht in its place", (function()
	local n = 0
	for _, d in workspace:GetDescendants() do
		if d.Name == "Yacht" and d:IsA("Model") then
			local hull = d:FindFirstChild("Hull")
			if hull and (hull.CFrame.Position - (O + Vector3.new(-302, 0, 56))).Magnitude < 20 then
				n += 1
			end
		end
	end
	return n == 0
end)())

---------------------------------------------------------------------------------------------------
-- 2. The rules every screen and the server share
---------------------------------------------------------------------------------------------------
for i, at in Craft.Places.jetski.launch do
	check("jet ski launch spot " .. i .. " is deep water", Craft.deep(at.Position.X, at.Position.Z))
end
check("the Day Yacht's berth is deep water", Craft.deep(Craft.Places.yacht.launch[1].Position.X, Craft.Places.yacht.launch[1].Position.Z))
local ski = Craft.KINDS.jetski
local from = Vector3.new(96, ski.ride, 150)
local kept, stopped = Craft.keep(ski, from, Vector3.new(96, ski.ride, 120))
check("a jet ski driven at the beach is stopped at the shore", stopped == true and kept.Z == 150)
kept, stopped = Craft.keep(ski, from, Vector3.new(96, ski.ride, 160))
check("...and goes on over deep water", stopped == false and kept.Z == 160)
check("the server's check: a jet ski on the sand is somewhere it can't be; on the lagoon it's fine", Craft.allowedAt(ski, Vector3.new(60, ski.ride, 110)) == false and Craft.allowedAt(ski, Vector3.new(96, ski.ride, 160)) == true)
local heli = Craft.KINDS.heli
check("a helicopter may fly anywhere over the island up to its ceiling, not above it", Craft.allowedAt(heli, Vector3.new(0, 120, 0)) == true and Craft.allowedAt(heli, Vector3.new(0, heli.ceiling + 30, 0)) == false)
local s, yawRate = Craft.step(ski, 0, 1, 0, 1)
check("full throttle from rest: away, and faster each moment", s > 0 and s <= ski.top and yawRate == 0)
local s2 = s
for _ = 1, 20 do
	s2 = Craft.step(ski, s2, 1, 0, 0.5)
end
check("...never past its top speed", math.abs(s2 - ski.top) < 1e-6)
local _, turn = Craft.step(ski, ski.top, 1, 1, 0.1)
check("the wheel turns it (to the right, from the right)", turn < 0)
check("a helicopter climbs with lift and eases off at its ceiling", Craft.vertical(heli, 50, 6, 1) == heli.climb and Craft.vertical(heli, heli.ceiling, 6, 1) == 0)
check("...and never sinks into the ground under it", Craft.vertical(heli, 7, 6, -1) == 0)
check("the island's ground is shared: the builder's own and the rides' agree", module("ServerScriptService", "Server", "Attractions", "IslandBuild").groundAt(40, 40) == Ground.groundAt(40, 40))

---------------------------------------------------------------------------------------------------
-- 3. Not theirs yet; buying with Gilt; Robux
---------------------------------------------------------------------------------------------------
page(ada).key = true
stand(ada, Layout.Terrace.arrival)
advance(3)
local r = askAs(ada, { op = "go", id = "island" })
check("(flown in)", r.ok == true and Attractions.inside(ada) == "island")
advance(10)
standOn(ada, Craft.Places.jetski.ask)
data(ada).gilt = 1000
local before = #ada.inbox
check("the Jet Ski Hire, the jet ski not theirs: refused", press("ride:jetski", ada) and seatOf(ada) == nil)
check("...the island's card opened at its Rides page, and the price said", last(ada, "panel") ~= nil and last(ada, "panel").which == "rides" and (function()
	for i = before + 1, #ada.inbox do
		local m = ada.inbox[i]
		if m.op == "notice" and string.find(m.line, "60,000 Gilt", 1, true) then
			return true
		end
	end
	return false
end)())
local st = askAs(ada, { op = "state", id = "island" })
check("the card's rides: each one's Gilt price and whether it's theirs", st.ok == true and type(st.rides) == "table" and st.rides.jetski.gilt == 60000 and st.rides.jetski.owned == false and st.rides.yacht.free == true and st.rides.heli.gilt == 750000 and st.rides.heli.owned == false)
r = askAs(ada, { op = "act", id = "island", act = "buyRide", what = "jetski", how = "gilt" })
check("without the Gilt: refused, with the price, and nothing taken", r.ok == false and string.find(r.why, "60,000", 1, true) ~= nil and data(ada).gilt == 1000 and page(ada).rides.jetski ~= true)
data(ada).gilt = 100000
r = askAs(ada, { op = "act", id = "island", act = "buyRide", what = "jetski", how = "gilt" })
check("bought with Gilt: exactly the price shown taken, and the jet ski theirs for good", r.ok == true and data(ada).gilt == 40000 and page(ada).rides.jetski == true)
r = askAs(ada, { op = "act", id = "island", act = "buyRide", what = "jetski", how = "gilt" })
check("...never charged twice: refused, nothing taken", r.ok == false and data(ada).gilt == 40000)
r = askAs(ada, { op = "act", id = "island", act = "buyRide", what = "heli", how = "robux" })
check("the helicopter for Robux, its product not made yet: said so, no window, nothing taken", r.ok == false and #offered == 0 and string.find(r.why, "isn't on sale for Robux yet", 1, true) ~= nil)
onSale.islandHelicopter = true
r = askAs(ada, { op = "act", id = "island", act = "buyRide", what = "heli", how = "robux" })
check("...once it's made: Roblox's window opens (its price is in it), and nothing's granted until the receipt", r.prompted == true and #offered == 1 and offered[1].product == "islandHelicopter" and page(ada).rides.heli ~= true)
check("the receipt's grant: the helicopter theirs for good", Rides.grant(page(ada), "heli") == true and page(ada).rides.heli == true)
r = askAs(ada, { op = "act", id = "island", act = "buyRide", what = "yacht", how = "gilt" })
check("the Day Yacht isn't sold (it's every guest's)", r.ok == false and data(ada).gilt == 40000)
r = askAs(ada, { op = "act", id = "island", act = "buyRide", what = "submarine", how = "gilt" })
check("a ride the island hasn't: refused", r.ok == false and data(ada).gilt == 40000)

---------------------------------------------------------------------------------------------------
-- 4. Riding the jet ski
---------------------------------------------------------------------------------------------------
standOn(ada, Craft.Places.jetski.ask)
local pressed = press("ride:jetski", ada)
check("the Jet Ski Hire: their jet ski out on the water, and them at its helm", pressed and rides["jetski:1901"] ~= nil and seatOf(ada) == rides["jetski:1901"].seat)
local mine = rides["jetski:1901"]
local at = mine.chassis.CFrame.Position - O
check("...at a launch spot, on the sea's surface, facing the lagoon", (at - (Craft.Places.jetski.launch[1].Position + Vector3.new(0, ski.ride, 0))).Magnitude < 0.01)
check("...handed to their screen to steer (let go by the server)", mine.chassis.Anchored == false)
check("...theirs: its owner on it for every screen", mine.model:GetAttribute("Owner") == 1901 and mine.model:GetAttribute("CraftKind") == "jetski")
standOn(ada, Craft.Places.jetski.ask)
press("ride:jetski", ada)
local count = 0
for k in rides do
	if string.sub(k, 1, 7) == "jetski:" then
		count += 1
	end
end
check("asked again: the same jet ski, never a second", count == 1 and rides["jetski:1901"] == mine)
-- On the sand (a screen gone wrong, or a cheat): taken back to where it last was fine.
step(2)
mine.model:PivotTo(CFrame.new(O + Vector3.new(60, ski.ride, 110)))
step(2)
local back = mine.chassis.CFrame.Position - O
check("a jet ski found on the sand is taken back onto the water", Craft.allowedAt(ski, back) and (back - Vector3.new(60, ski.ride, 110)).Magnitude > 5)
-- Off it: put away after a while.
ada.humanoid.SeatPart = nil
step(5)
check("off it: it stops where it is and waits", rides["jetski:1901"] ~= nil and mine.chassis.Anchored == true)
step(math.ceil(Craft.IDLE_SECONDS / 0.3) + 2)
check("...and after a while it's put away", rides["jetski:1901"] == nil and mine.model.Parent == nil)

---------------------------------------------------------------------------------------------------
-- 5. The helicopter, and leaving the island
---------------------------------------------------------------------------------------------------
standOn(ada, Craft.Places.heli.ask)
check("the helipad: their helicopter, them at its helm", press("ride:heli", ada) and rides["heli:1901"] ~= nil and seatOf(ada) == rides["heli:1901"].seat)
local pad = workspace:FindFirstChild("PadHelicopter", true)
check("...the helicopter that stands on the pad steps aside while theirs is out", pad ~= nil and (function()
	for _, d in pad:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			return false
		end
	end
	return true
end)())
standOn(bo, Craft.Places.heli.ask)
page(bo).key = true
r = askAs(bo, { op = "act", id = "island", act = "ride", what = "heli" })
check("someone else at the pad without the helicopter: refused, its price said", r.ok == false and string.find(r.why, "750,000", 1, true) ~= nil and rides["heli:1902"] == nil)
ada.humanoid.SeatPart = nil
r = askAs(ada, { op = "home" })
advance(2)
check("home from the island: their helicopter put away at once", r.ok == true and rides["heli:1901"] == nil)
check("...and the pad's own helicopter back", (function()
	for _, d in pad:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Cabin" and d.Transparency < 1 then
			return true
		end
	end
	return false
end)())

---------------------------------------------------------------------------------------------------
-- 6. The Day Yacht, the Sovereign, the leap
---------------------------------------------------------------------------------------------------
stand(ada, Layout.Terrace.arrival)
advance(3)
askAs(ada, { op = "go", id = "island" })
advance(10)
page(bo).key = true
stand(bo, Layout.Terrace.arrival)
advance(3)
askAs(bo, { op = "go", id = "island" })
advance(10)
standOn(ada, Craft.Places.yacht.ask)
check("the Day Yacht: free, and Ada at its helm", press("ride:yacht", ada) and seatOf(ada) == rides.yacht.seat and rides.yacht.chassis.Anchored == false and data(ada).gilt == 40000)
standOn(bo, Craft.Places.yacht.ask)
r = askAs(bo, { op = "act", id = "island", act = "ride", what = "yacht" })
check("one captain at a time: Bo is told who has the helm", r.ok == false and string.find(r.why, "has the helm", 1, true) ~= nil)
r = askAs(bo, { op = "act", id = "island", act = "board", what = "yacht" })
local deck = rides.yacht.chassis.CFrame * CFrame.new(0, 3.2, 8)
check("...and boards instead: on its deck", r.ok == true and (bo.root.CFrame.Position - (deck.Position + Vector3.new(0, 3, 0))).Magnitude < 0.5)
-- The yacht out at sea, its captain gone: back to its berth, Bo set on the pier.
rides.yacht.model:PivotTo(CFrame.new(O + Vector3.new(-380, 1.6, 40)))
bo.root.CFrame = rides.yacht.chassis.CFrame * CFrame.new(0, 4, 6)
ada.humanoid.SeatPart = nil
step(math.ceil(Craft.RETURN_SECONDS / 0.3) + 3)
check("with nobody at its helm, the Day Yacht goes back to its berth", (rides.yacht.chassis.CFrame.Position - (O + Craft.Places.yacht.launch[1].Position + Vector3.new(0, Craft.KINDS.yacht.ride, 0))).Magnitude < 0.5 and rides.yacht.chassis.Anchored == true)
check("...anyone aboard set on the pier first, not left in the sea", (bo.root.CFrame.Position - (O + Craft.Places.yacht.ask)).Magnitude < 5)
-- The Sovereign.
standOn(bo, Vector3.new(-284, Plan.GROUND, 86))
check("the Sovereign's gangway: aboard its top deck", press("board:sovereign", bo) and bo.root.CFrame.Position.Y > O.Y + 14)
r = askAs(bo, { op = "act", id = "island", act = "leap" })
check("Leap at its rail: yes, out over the sea (the screen is told which way)", r.ok == true and type(r.send) == "table" and r.send.what == "leap")
standOn(bo, Vector3.new(0, 6, 0))
r = askAs(bo, { op = "act", id = "island", act = "leap" })
check("...anywhere else: refused", r.ok == false)
-- Leaving the house with a ride out.
standOn(ada, Craft.Places.jetski.ask)
press("ride:jetski", ada)
check("(a jet ski out)", rides["jetski:1901"] ~= nil)
local skiModel = rides["jetski:1901"].model
H.PlayersService.PlayerRemoving:Fire(ada)
ada.Parent = nil
step(3)
check("leaving the house: their jet ski goes with them", rides["jetski:1901"] == nil and skiModel.Parent == nil)

H.finish()

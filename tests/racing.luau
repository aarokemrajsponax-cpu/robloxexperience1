--!nocheck
-- Timed laps and racing ranks (shared/Tracks, server/TimeTrials, with server/GrandPrixService),
-- under Lune on a fake clock: the two circuits (the Grand Boulevard, Luxury Island's Coastal
-- Circuit); a timed lap from line to line by the server's own clock, counted only with every gate
-- passed in order and never faster than any car can go; the best kept and put on the boards (all
-- time and this week, only ever improved), friends' bests beside it; racing points (laps, bests,
-- races) and the ranks they climb, painted on the stripes of the car a ranked racer drives; no
-- timed laps in a race; and Join the next race (a free car and the grid, from anywhere).
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/racing.luau

local roblox = require("@lune/roblox")
local H = require("./harness")
local check, advance = H.check, H.advance
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

roblox.implementMethod("Model", "GetPivot", function(self)
	return if self.PrimaryPart then self.PrimaryPart.CFrame else CFrame.new()
end)
roblox.implementMethod("Model", "PivotTo", function(self, cf)
	local primary = self.PrimaryPart
	if not primary then
		return
	end
	local from = primary.CFrame
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = cf * from:ToObjectSpace(d.CFrame)
		end
	end
end)
roblox.implementMethod("VehicleSeat", "Sit", function(self, h)
	if type(h) == "table" then
		h.SeatPart = self
	end
end)

local GrandPrix = H.module("ReplicatedStorage", "Shared", "GrandPrix")
local Tracks = H.module("ReplicatedStorage", "Shared", "Tracks")
local BadgeBook = H.module("ReplicatedStorage", "Shared", "BadgeBook")
local Config = H.Config
local Service = H.module("ServerScriptService", "Server", "GrandPrixService")
local TimeTrials = H.module("ServerScriptService", "Server", "TimeTrials")
local world = roblox.Instance.new("Folder")
world.Name = "Maison"
Service.start(world)
local awards, tallies, heralds, moved = {}, {}, {}, {}
TimeTrials.award = function(p, key)
	table.insert(awards, { p = p, key = key })
end
TimeTrials.tally = function(p, stat, n)
	tallies[stat] = (tallies[stat] or 0) + n
end
TimeTrials.herald = function(p, feat)
	table.insert(heralds, feat)
end
TimeTrials.teleport = function(p, cf)
	p.root.Position = cf.Position
	table.insert(moved, p)
	return true
end
TimeTrials.friendIds = function(p)
	return { 9911 }
end
TimeTrials.start()
local C = Config.data.GrandPrix

local nextId = 1900
local function guestAt(pos)
	nextId += 1
	local g = H.newGuest("Racer" .. nextId, nextId)
	table.insert(H.guests, g)
	H.newProfile(g, H.TEMPLATE)
	local data = H.profiles[g].Data
	data.gems = data.gems or 0
	H.loadedSignal:Fire(g, data)
	g.root.Position = pos
	return g, data
end
local function carOf(id)
	for _, car in Service.cars() do
		if car.def.id == id then
			return car
		end
	end
end
local function inboxOf(g, op, after)
	local out = {}
	for i = (after or 0) + 1, #g.inbox do
		if g.inbox[i].op == op then
			table.insert(out, g.inbox[i])
		end
	end
	return out
end
-- Drives `car` round `track` from distance `from` to `to` at `speed`, in fake time.
local function drive(car, track, s)
	local p, dir = Tracks.point(track, s)
	local at = Vector3.new(p.X, Tracks.ride(track), p.Z)
	car.model:PivotTo(CFrame.lookAt(at, at + dir))
end
local function run(car, track, from, to, speed)
	local s = from
	while s < to do
		s = math.min(to, s + speed / 30)
		drive(car, track, s)
		advance(1 / 30)
	end
	return s
end

---------------------------------------------------------------------------------------------------
-- 1. The circuits
---------------------------------------------------------------------------------------------------
check("two circuits for timed laps: the Grand Boulevard and the Coastal Circuit", #Tracks.List == 2 and Tracks.byId.boulevard and Tracks.byId.coast)
local LC = Tracks.length("coast")
check("the Coastal Circuit is a proper lap (600 to 900 studs)", LC > 600 and LC < 900, LC)
local p = Tracks.point("coast", 123)
local s, off = Tracks.progress("coast", p)
check("a point round the circuit is found again where it lies", math.abs(s - 123) < 1 and off < 0.5, s)
check("its gates come in order round the lap", Tracks.gate("coast", 0) == 0 and Tracks.gate("coast", LC * 0.5) == 8 and Tracks.gate("coast", LC - 1) == 15)
check("the Boulevard is the Grand Prix's own circuit", Tracks.length("boulevard") == GrandPrix.length())
check("each ace's mark can be beaten, but not by much: above the quickest lap any car could drive", Tracks.byId.boulevard.ace > Tracks.quickest("boulevard") and Tracks.byId.coast.ace > Tracks.quickest("coast"))
check("their badges are real", BadgeBook.byKey.lapAce ~= nil and BadgeBook.byKey.coastAce ~= nil)
check("the island's three cars wait in its garage", carOf("coastSpyder") and carOf("coastSpyder").track == "coast" and (carOf("coastSpyder").chassis.CFrame.Position - Tracks.bay(1).Position).Magnitude < 0.01)
check("the racing ranks climb from Rookie to Legend", Tracks.RANKS[1].name == "Rookie" and Tracks.RANKS[#Tracks.RANKS].name == "Legend" and select(2, Tracks.rank(0)) == 1 and select(2, Tracks.rank(400)) == 4)

---------------------------------------------------------------------------------------------------
-- 2. A timed lap of the Boulevard
---------------------------------------------------------------------------------------------------
local L = Tracks.length("boulevard")
local phantom = carOf("phantom")
local ana, anaData = guestAt(GrandPrix.bay(1).Position + Vector3.new(0, 0, 6))
local ok, why = Service.drive(ana, "phantom")
check("(at the wheel)", ok, why)
-- Up to the line, round once, and over it again.
local sNow = run(phantom, "boulevard", L - 60, L + 5, 70)
local started = inboxOf(ana, "trialStart")
check("over the line: a timed lap starts (by the server's clock)", #started == 1 and started[1].track == "boulevard" and type(started[1].at) == "number")
sNow = run(phantom, "boulevard", sNow, 2 * L + 5, 70)
local lap = inboxOf(ana, "trialLap")[1]
check("round and over the line again: the lap, timed", lap ~= nil and math.abs(lap.time - L / 70) < 0.5 and lap.best == true, lap and lap.time)
check("...kept as their best", math.abs(anaData.racing.pb.boulevard - lap.time) < 0.001)
check("...on the boards, for every server", type(H.orderedStores.Laps_boulevard) == "table" and H.orderedStores.Laps_boulevard[tostring(ana.UserId)] == math.floor(lap.time * 1000 + 0.5))
check("...a track record: the house hears of it", #heralds >= 1 and heralds[#heralds].kind == "trackRecord")
check("...racing points: a lap and a new best", anaData.racing.points == Tracks.POINTS.lap + Tracks.POINTS.best and ana:GetAttribute("RacingPoints") == anaData.racing.points)
check("...counted for the Badge Book", (tallies.trialLaps or 0) == 1)
-- A slower lap: not a new best, and the board keeps the better.
sNow = run(phantom, "boulevard", sNow, 3 * L + 5, 60)
local second = inboxOf(ana, "trialLap")[2]
check("a slower lap: timed, but the best stands", second ~= nil and second.best == false and math.abs(anaData.racing.pb.boulevard - lap.time) < 0.001)
check("...and the board keeps the better", H.orderedStores.Laps_boulevard[tostring(ana.UserId)] == math.floor(lap.time * 1000 + 0.5))
-- Across the infield: gates out of order, the lap doesn't count.
local before = #inboxOf(ana, "trialLap")
local voids = #inboxOf(ana, "trialVoid")
sNow = run(phantom, "boulevard", sNow, sNow + 60, 60)
drive(phantom, "boulevard", sNow + L * 0.5)
advance(0.2)
check("a lap with gates missed: void, and said so", #inboxOf(ana, "trialVoid") == voids + 1)
-- (The jump itself was too far for any car too: either way, nothing counts.)
sNow = run(phantom, "boulevard", sNow + L * 0.5, sNow + L * 1.6, 60)
check("...no lap counted from it", #inboxOf(ana, "trialLap") == before)

---------------------------------------------------------------------------------------------------
-- 3. The Coastal Circuit, an ace's lap, and the card
---------------------------------------------------------------------------------------------------
local spyder = carOf("coastSpyder")
local bo, boData = guestAt(Tracks.bay(1).Position + Vector3.new(0, 0, 6))
ok, why = Service.drive(bo, "coastSpyder")
check("the island's cars are driven like any other", ok, why)
local r, rWhy = Service.join(bo)
check("...but the Grand Prix races on the Boulevard: no race from the island", r == false and string.find(rWhy, "Grand Boulevard", 1, true) ~= nil)
sNow = run(spyder, "coast", LC - 40, LC + 5, 80)
sNow = run(spyder, "coast", sNow, 2 * LC + 5, 88)
local coastLap = inboxOf(bo, "trialLap")[1]
check("a timed lap of the Coastal Circuit", coastLap ~= nil and coastLap.track == "coast" and coastLap.best == true, coastLap and coastLap.time)
local ace = false
for _, a in awards do
	if a.p == bo and a.key == "coastAce" then
		ace = true
	end
end
check("under the ace's mark: Coast Ace", coastLap and coastLap.time < Tracks.byId.coast.ace and ace)
H.orderedStores.Laps_coast = H.orderedStores.Laps_coast or {}
H.orderedStores.Laps_coast["9911"] = 7000 -- (a friend a little quicker)
local card = TimeTrials.card(bo)
local coastCard = nil
for _, t in card.tracks do
	if t.id == "coast" then
		coastCard = t
	end
end
check("the card: their best on each circuit, the boards", card.ok == true and coastCard ~= nil and math.abs(coastCard.pb - coastLap.time) < 0.001 and type(coastCard.all) == "table" and type(coastCard.week) == "table")
check("...and their friends' bests beside theirs, quickest first", #coastCard.friends == 2 and coastCard.friends[1].userId == 9911 and coastCard.friends[2].userId == bo.UserId)
check("...their racing rank and points", card.rankName == "Rookie" and card.points == boData.racing.points)

---------------------------------------------------------------------------------------------------
-- 4. Ranks and stripes
---------------------------------------------------------------------------------------------------
check("a Rookie's car: no stripes", (function()
	for _, d in spyder.model:GetChildren() do
		if d.Name == "RacingStripe" and d.Transparency < 1 then
			return false
		end
	end
	return true
end)())
TimeTrials.addPoints(bo, 400, "test")
check("enough points: a new rank, told", bo:GetAttribute("RacingRank") == 4 and inboxOf(bo, "racingRank")[1] ~= nil and inboxOf(bo, "racingRank")[1].name == "Ace")
local striped = 0
for _, d in spyder.model:GetChildren() do
	if d.Name == "RacingStripe" and d.Transparency == 0 and d.Color == Tracks.RANKS[4].stripe then
		striped += 1
	end
end
check("...and the car they drive wears their rank's stripes, for everyone", striped == 4, striped)
bo.humanoid.SeatPart = nil
advance(0.5)
check("out of the car: the stripes go with them", (function()
	for _, d in spyder.model:GetChildren() do
		if d.Name == "RacingStripe" and d.Transparency < 1 then
			return false
		end
	end
	return true
end)())

---------------------------------------------------------------------------------------------------
-- 5. Join the next race (from anywhere), and no timed laps in a race
---------------------------------------------------------------------------------------------------
local cy = guestAt(Vector3.new(0, 30, 300))
local joined = TimeTrials.joinNext(cy)
check("Join the next race: taken to a free car on the street, and on the grid", joined.ok == true and table.find(moved, cy) ~= nil and Service.carOf(cy) ~= nil and Service.carOf(cy).track == "boulevard" and Service.state().state == "gathering" and table.find(Service.state().entrants, cy) ~= nil)
advance(C.gather + 0.2)
advance(C.countdown + 0.2)
check("(racing)", Service.state().state == "racing")
local cyCar = Service.carOf(cy)
local starts = #inboxOf(cy, "trialStart")
run(cyCar, "boulevard", L - 20, L + 30, 60)
check("in a race, laps are the race's: no timed lap starts", #inboxOf(cy, "trialStart") == starts)

H.finish()

--!nocheck
-- The Grand Prix (server/GrandPrixService) under Lune on a fake clock: the cars in their bays,
-- getting in and out, a car left empty going home, Reset, and races: the gathering, the grid, the
-- house's chauffeurs, laps counted only sector by sector, the order home, the prizes (Gilt, and
-- Gems for a win up to the day's cap), and the cheats it won't pay (a car that jumps further than
-- a car can, a lap that skips the circuit, a driver who gets out). The hours (open, a 50-second
-- countdown, closed for ten minutes after), opening it early (bought, or the owner, who may also
-- start a countdown at once), and the Private Garage's two cars (only for its holders).
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/races.luau

local roblox = require("@lune/roblox")
local H = require("./harness")
local check, advance = H.check, H.advance
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

-- (Roblox moves a model by its primary part; Lune's models need telling how.)
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
local Config = H.Config
local Service = H.module("ServerScriptService", "Server", "GrandPrixService")
local world = roblox.Instance.new("Folder")
world.Name = "Maison"
Service.start(world)
local raceEvent = H.Remotes.event("Race")
local C = Config.data.GrandPrix
local L = GrandPrix.length()

local function broadcastsOf(op, after)
	local out = {}
	for i = (after or 0) + 1, #H.broadcasts do
		local b = H.broadcasts[i]
		if b.remote == "Race" and b.message.op == op then
			table.insert(out, b.message)
		end
	end
	return out
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

local nextId = 900
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

---------------------------------------------------------------------------------------------------
-- The cars in their bays
---------------------------------------------------------------------------------------------------
local cars = Service.cars()
check("six cars, one in each bay along the kerb, and the Private Garage's two in theirs, parked (anchored)", #cars == 8 and (function()
	for i, car in cars do
		local want = if i <= 6 then GrandPrix.bay(i).Position else GrandPrix.privateBay(i - 6).Position
		if (car.chassis.CFrame.Position - want).Magnitude > 0.01 or not car.chassis.Anchored then
			return false
		end
	end
	return true
end)())
local phantom = carOf("phantom")
check("the Private Garage's cars say so on their Drive prompt", carOf("gilded").model:GetAttribute("Private") == true and string.find(carOf("gilded").seat.DrivePrompt.ObjectText, "Private Garage", 1, true) ~= nil and phantom.model:GetAttribute("Private") == nil)
check("...and are a look, never an edge: nothing in them but a name and colours", (function()
	local looks = { id = true, name = true, paint = true, trim = true, glass = true, style = true, private = true }
	for _, def in GrandPrix.GARAGE do
		for k in def do
			if not looks[k] then
				return false
			end
		end
	end
	return true
end)())
check("the Grand Prix opens with the server: open, for five minutes", Service.door() == "open" and select(2, Service.door()) > H.now() + C.openSeconds - 5 and H.game:GetService("Workspace"):GetAttribute("GrandPrixDoor") == "open")
check("each car: a driver's seat with Drive, a seat beside it with Ride along, the two movers", phantom.seat:FindFirstChild("DrivePrompt") ~= nil and phantom.passenger:FindFirstChild("RidePrompt") ~= nil and phantom.chassis:FindFirstChild("Drive") ~= nil and phantom.chassis:FindFirstChild("Steer") ~= nil)
check("only the chassis collides, in the Cars group (cars pass through guests and each other)", phantom.chassis.CollisionGroup == "Cars" and (function()
	for _, d in phantom.model:GetDescendants() do
		if d:IsA("BasePart") and d ~= phantom.chassis and d.CanCollide then
			return false
		end
	end
	return true
end)())
check("every car's name is its own (no real makes)", (function()
	local seen = {}
	for _, car in cars do
		local n = car.model:GetAttribute("CarName")
		if type(n) ~= "string" or seen[n] then
			return false
		end
		seen[n] = true
	end
	return true
end)())

---------------------------------------------------------------------------------------------------
-- Getting in, getting out
---------------------------------------------------------------------------------------------------
local bayPos = GrandPrix.bay(1).Position
local far = guestAt(bayPos + Vector3.new(0, 0, 80))
local ok, why = Service.drive(far, "phantom")
check("a guest far from the car can't drive it", not ok and why == "Walk up to the car.", why)
local ana, anaData = guestAt(bayPos + Vector3.new(0, 0, 6))
ok = Service.drive(ana, "phantom")
check("near it: Drive seats them at the wheel and lets the car go", ok and ana.humanoid.SeatPart == phantom.seat and phantom.driver == ana and not phantom.chassis.Anchored)
check("...and tells their screen which car", #inboxOf(ana, "driving") == 1 and inboxOf(ana, "driving")[1].carId == "phantom")
local ben = guestAt(bayPos + Vector3.new(2, 0, 6))
ok, why = Service.drive(ben, "phantom")
check("nobody else can take a car being driven", not ok, why)
ok = Service.ride(ben, "phantom")
check("but a friend can ride along", ok and ben.humanoid.SeatPart == phantom.passenger and phantom.rider == ben)
ok, why = Service.drive(ana, "aurelia")
check("one car at a time", not ok, why)

-- The Private Garage: its two cars only for its holders; for anyone else, Drive opens Roblox's
-- purchase window (the price is in it) and nothing more.
local gilded = carOf("gilded")
local dee = guestAt(GrandPrix.privateBay(1).Position + Vector3.new(0, 0, 6))
local offered = {}
Service.offerGarage = function(p)
	table.insert(offered, p)
	return true, nil
end
ok, why = Service.drive(dee, "gilded")
check("a Private Garage car without it: not driven, and the purchase window offered", not ok and #offered == 1 and offered[1] == dee and gilded.driver == nil and string.find(tostring(why), "drives like every other car", 1, true) ~= nil, why)
Service.hasGarage = function(p)
	return p == dee
end
ok = Service.drive(dee, "gilded")
check("with it: theirs to drive, like any car", ok and gilded.driver == dee and not gilded.chassis.Anchored and #offered == 1)
gilded.model:PivotTo(CFrame.new(-30, GrandPrix.RIDE, -120))
dee.humanoid.SeatPart = nil

-- Driven away and left: the car goes home.
phantom.model:PivotTo(CFrame.new(40, GrandPrix.RIDE, -120))
advance(0.3)
ana.humanoid.SeatPart = nil
advance(0.5)
check("getting out: the car is nobody's, and stops", phantom.driver == nil and #inboxOf(ana, "parked") == 1)
advance(C.returnAfter + 1)
check("left empty, after a few seconds it's back in its bay, parked", (phantom.chassis.CFrame.Position - bayPos).Magnitude < 0.01 and phantom.chassis.Anchored)
check("and the friend riding along is set down", phantom.rider == nil and ben.humanoid.Sit == false)
check("a Private Garage car goes home to its own bay", (gilded.chassis.CFrame.Position - GrandPrix.privateBay(1).Position).Magnitude < 0.01 and gilded.chassis.Anchored)

-- Reset: a stuck car set right, not too often.
ana.root.Position = bayPos + Vector3.new(0, 0, 6)
ana.humanoid.SeatPart = nil
ok = Service.drive(ana, "phantom")
phantom.model:PivotTo(CFrame.new(10, 3, -100) * CFrame.Angles(0, 0, math.rad(170)))
advance(0.2)
ok = Service.reset(ana)
local up = phantom.chassis.CFrame.UpVector
check("Reset turns an overturned car the right way up where it is", ok and up.Y > 0.99 and math.abs(phantom.chassis.CFrame.Position.Y - (GrandPrix.RIDE + 0.4)) < 0.01)
check("...but not again straight away", Service.reset(ana) == false)
advance(C.resetEvery + 0.1)
check("...only every few seconds", Service.reset(ana) == true)

---------------------------------------------------------------------------------------------------
-- A race, alone against the house's chauffeurs
---------------------------------------------------------------------------------------------------
local function drive(car, s)
	local p, dir = GrandPrix.point(s)
	local at = Vector3.new(p.X, GrandPrix.RIDE, p.Z)
	car.model:PivotTo(CFrame.lookAt(at, at + dir))
end

-- Drives `car` round from distance `from` to `to` at `speed`, in fake time.
local function run(car, from, to, speed)
	local s = from
	while s < to do
		s = math.min(to, s + speed / 30)
		drive(car, s)
		advance(1 / 30)
	end
	return s
end

local mark = #H.broadcasts
ok, why = Service.join(ana)
check("Race: the race gathers", ok and Service.state().state == "gathering" and #broadcastsOf("race", mark) >= 1 and broadcastsOf("race", mark)[1].state == "gathering", why)
ok, why = Service.join(ben)
check("someone not at a wheel can't join", not ok and why == "Get in a car first.", why)
advance(C.gather + 0.2)
local st = Service.state()
check("after the gathering: the countdown, the car set on the grid's first box and held there", st.state == "countdown" and (phantom.chassis.CFrame.Position - GrandPrix.gridSlot(1).Position).Magnitude < 0.01 and phantom.chassis.Anchored)
check("the house's chauffeurs fill the grid to four, each a name, a car and a pace", #st.chauffeurs == C.field - 1 and st.chauffeurs[1].pace == GrandPrix.AI.paces[1] and st.chauffeurs[1].slot == 2)
local countdown = broadcastsOf("race", mark)
local last = countdown[#countdown]
check("every screen is told the grid, the chauffeurs and the moment of the start", last.state == "countdown" and #last.grid == 1 and #last.ai == 3 and type(last.startAt) == "number")
ok = Service.reset(ana)
check("no Reset on the grid", ok == false)
advance(C.countdown + 0.1)
check("lights out: racing, and the car is the driver's to drive", Service.state().state == "racing" and not phantom.chassis.Anchored)

-- Three laps at a good clip (about 37 seconds: quicker than the quickest chauffeur).
local behind = GrandPrix.TRACK.centre.X - GrandPrix.gridSlot(1).Position.X
local s = run(phantom, L - behind, L + 5, 72)
local laps0 = #inboxOf(ana, "lap")
s = run(phantom, s, L + L + 5, 72)
check("a lap counts when its four sectors are driven in order", #inboxOf(ana, "lap") == laps0 + 1 and inboxOf(ana, "lap")[#inboxOf(ana, "lap")].lap == 2)
check("standings go out while racing", #broadcastsOf("standings", mark) > 5)
local giltBefore, gemsBefore = anaData.gilt, anaData.gems
s = run(phantom, s, 4 * L + 5, 72)
check("over the line after three: home, with the time", #inboxOf(ana, "home") == 1 and inboxOf(ana, "home")[1].time > 30 and inboxOf(ana, "home")[1].time < 45, inboxOf(ana, "home")[1] and inboxOf(ana, "home")[1].time)
advance(0.3)
local results = broadcastsOf("results", mark)
local mine = inboxOf(ana, "yourResult")
check("all racers home: the results, every chauffeur placed by their own time", #results == 1 and #results[1].list == 4 and results[1].list[1].userId == ana.UserId and results[1].list[2].ai == true)
check("first: the winner's Gilt and Gems", mine[1] and mine[1].place == 1 and mine[1].gilt > 0 and mine[1].gems == C.winGems and anaData.gems == gemsBefore + C.winGems and anaData.gilt > giltBefore, mine[1] and mine[1].gilt)
check("the race is remembered: one run, one win, the best time", anaData.racing.races == 1 and anaData.racing.wins == 1 and anaData.racing.best > 30)
-- Race again while the results show: closed, saying when it opens and what opening it costs.
local inbox0 = #ana.inbox
Service.openInfo = function()
	return { price = 39, held = 0 }
end
raceEvent.OnServerEvent:Fire(ana, { op = "race" })
local closedMsg = inboxOf(ana, "closed", inbox0)[1]
check("Race again during the results: closed, opening after the results and ten minutes", closedMsg ~= nil and math.abs(closedMsg.opensIn - (C.results + C.closedSeconds)) < 1 and closedMsg.price == 39, closedMsg and closedMsg.opensIn)
advance(C.results + 0.5)
check("after the results, the circuit rests: closed for ten minutes", Service.state().state == "idle" and Service.door() == "closed" and Service.isClosed() and H.game:GetService("Workspace"):GetAttribute("GrandPrixDoor") == "closed")
ok, why = Service.join(ana)
check("...and Race says when it opens", not ok and (string.find(tostring(why), "opens in 10:00", 1, true) ~= nil or string.find(tostring(why), "opens in 9:59", 1, true) ~= nil), why)
mark = #H.broadcasts
advance(C.closedSeconds - 5)
check("...still closed a little before ten minutes", Service.door() == "closed" and #broadcastsOf("opened", mark) == 0)
advance(6)
check("then it opens by itself, and every screen is told", Service.door() == "open" and #broadcastsOf("opened", mark) == 1 and broadcastsOf("opened", mark)[1].by == nil)
advance(C.openSeconds + 1)
check("open five minutes with nobody racing: it closes again", Service.door() == "closed")
-- Opened now (bought, or the owner's word): open for everyone, at once, in their name.
ok = Service.openNow("Racer901")
local opened = broadcastsOf("opened", mark)
check("opened early: open for everyone, in their name", ok and Service.door() == "open" and opened[#opened].by == "Racer901")
check("...and not twice", Service.openNow("Someone") == false)
-- The owner's "start now": the 50-second countdown cut to a few seconds.
check("start now with nobody on the grid: nothing to start", Service.startNow() == false)
Service.join(ana)
advance(1)
check("a race gathers for fifty seconds", math.abs(Service.state().gatherEnds - H.now() - (C.gather - 1)) < 0.2)
ok = Service.startNow()
check("the owner's start now: the countdown cut to a few seconds", ok and Service.state().gatherEnds <= H.now() + C.ownerStart + 0.01)
advance(C.ownerStart + 0.2)
check("...and the cars go to the grid", Service.state().state == "countdown")
Service.leaveRace(ana)
advance(C.countdown + 0.5)
-- Opening it as a race's results show: it opens as they close, instead of resting.
check("bought as the results show: taken", Service.state().state == "results" and Service.isClosed() and Service.openNow("Racer901") == true and not Service.isClosed())
advance(C.results + 0.5)
check("...and it's open when they close", Service.state().state == "idle" and Service.door() == "open")

---------------------------------------------------------------------------------------------------
-- What isn't paid
---------------------------------------------------------------------------------------------------
-- A car that jumps further than any car could.
local function startSolo(g)
	if Service.isClosed() then
		Service.openNow("Racer901")
	end
	Service.join(g)
	advance(C.gather + 0.2)
	advance(C.countdown + 0.1)
end
mark = #H.broadcasts
local inboxMark = #ana.inbox
startSolo(ana)
run(phantom, L - behind, L - behind + 40, 60)
drive(phantom, 300)
advance(0.2)
check("a car that jumps across the circuit is out of the race", #inboxOf(ana, "out", inboxMark) == 1 and inboxOf(ana, "out", inboxMark)[1].why == "Moved faster than any car")
advance(C.maxRace + 1)
mine = inboxOf(ana, "yourResult", inboxMark)
check("...and paid nothing", mine[1] and mine[1].place == 0 and mine[1].gilt == 0)
advance(C.results + 0.5)

-- Crossing the line back and forth without driving round counts no lap.
inboxMark = #ana.inbox
startSolo(ana)
s = run(phantom, L - behind, L + 10, 60) -- over the line: lap one begins
for _ = 1, 3 do
	for k = 1, 10 do
		drive(phantom, L + 10 - k * 3)
		advance(1 / 30)
	end
	run(phantom, L - 20, L + 10, 60)
end
check("back and forth over the line, no lap is counted", #inboxOf(ana, "lap", inboxMark) == 1 and #inboxOf(ana, "home", inboxMark) == 0)
-- Getting out mid-race.
ana.humanoid.SeatPart = nil
advance(0.3)
check("getting out mid-race: out of it", #inboxOf(ana, "out", inboxMark) == 1 and inboxOf(ana, "out", inboxMark)[1].why == "Left the car")
advance(0.5)
mine = inboxOf(ana, "yourResult", inboxMark)
check("...the race ends with nobody left in it, and nothing paid", mine[1] and mine[1].place == 0 and mine[1].gilt == 0)
advance(C.results + 0.5)

---------------------------------------------------------------------------------------------------
-- The day's Gems, and two drivers at once
---------------------------------------------------------------------------------------------------
ana.root.Position = phantom.chassis.CFrame.Position + Vector3.new(0, 0, 6)
ana.humanoid.SeatPart = nil
advance(C.returnAfter + 1)
ana.root.Position = bayPos + Vector3.new(0, 0, 6)
Service.drive(ana, "phantom")
local gemsStart = anaData.gems
local winsBefore = anaData.racing.wins
for _ = 1, 7 do
	startSolo(ana)
	run(phantom, L - behind, 4 * L + 5, 72)
	advance(0.3)
	advance(C.results + 0.5)
end
check("seven wins in a day: Gems only up to the day's cap", anaData.racing.wins == winsBefore + 7 and anaData.gems - gemsStart <= C.gemsPerDay and anaData.racing.gems == C.gemsPerDay, anaData.gems - gemsStart)

local cara = guestAt(GrandPrix.bay(2).Position + Vector3.new(0, 0, 6))
Service.drive(cara, "aurelia")
local aurelia = carOf("aurelia")
mark = #H.broadcasts
Service.openNow("Racer901")
Service.join(ana)
Service.join(cara)
advance(C.gather + 0.2)
st = Service.state()
check("two drivers: both on the grid, two chauffeurs make four", #st.racers == 2 and #st.chauffeurs == 2 and (aurelia.chassis.CFrame.Position - GrandPrix.gridSlot(2).Position).Magnitude < 0.01)
advance(C.countdown + 0.1)
-- Ana quick, Cara slower: both home, Ana ahead.
local sa, sc = L - behind, L - (GrandPrix.TRACK.centre.X - GrandPrix.gridSlot(2).Position.X)
while sa < 4 * L + 5 do
	sa = math.min(4 * L + 5, sa + 72 / 30)
	sc = sc + 66 / 30
	drive(phantom, sa)
	drive(aurelia, sc)
	advance(1 / 30)
end
while sc < 4 * L + 5 do
	sc = sc + 66 / 30
	drive(aurelia, sc)
	advance(1 / 30)
end
advance(0.3)
results = broadcastsOf("results", mark)
local placeOf = {}
for _, row in results[1] and results[1].list or {} do
	if row.userId then
		placeOf[row.userId] = row.place
	end
end
check("both home: Ana first, Cara behind her", placeOf[ana.UserId] == 1 and (placeOf[cara.UserId] or 0) > 1, placeOf[cara.UserId])

H.finish()

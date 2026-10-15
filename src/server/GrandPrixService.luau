--!strict
-- The Grand Prix: the house's cars on the street, and races round the circuit (World/Circuit,
-- Shared/GrandPrix). Everything here is the server's: who's driving which car, where each racer
-- truly is, their laps, the order home, and the prizes.
--
-- Driving: "Drive" on a car sits the guest in it and hands the car to their screen (network
-- ownership), which drives it (GrandPrix.step: smooth on every device). Get out (jump) and the
-- car waits; left empty it goes back to its bay. "Reset" puts a stuck car right.
--
-- Racing keeps hours, like the Ballroom (Config.GrandPrix): open for five minutes; the first
-- driver to press Race starts a 50-second countdown (others may join until it ends, never after);
-- then closed for ten minutes, after a race or when nobody raced. It opens early for everyone
-- when a guest buys "Open the Grand Prix Now", or the owner says so (who may also cut a
-- countdown short). The cars may be driven at any hour.
--
-- A race: the cars are set on the grid, the lights count down, and it's three laps. The house's
-- chauffeurs fill the grid (drawn on every screen from the same numbers, so all agree where they
-- are). A lap counts only with its four sectors driven in order; nobody gets round faster than a
-- car can go (a racer who jumps further than any car could is out). Prizes by place, in Gilt
-- (the day's soft cap applies as everywhere) and, for the winner, Gems up to a few a day.
--
-- The Private Garage (Robux, Purchases/Racing): two more cars for its holders, which drive
-- exactly like the rest. Pressing Drive on one without it opens the purchase window, price shown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local GrandPrix = require(ReplicatedStorage.Shared.GrandPrix)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Motorcar = require(script.Parent.World.Motorcar)

local Service = {}

-- Hooks set by Main.
Service.isBusy = function(_player: Player): boolean
	return false
end
Service.gemsChanged = function(_player: Player) end
Service.onFinish = function(_player: Player, _place: number, _field: number) end
-- Whether a guest holds the Private Garage, and offering it (Main: Purchases.Racing).
Service.hasGarage = function(_player: Player): boolean
	return false
end
Service.offerGarage = function(_player: Player): (boolean, string?)
	return false, "That isn't on sale yet."
end
-- A guest asked to open the Grand Prix now (Main: Purchases.Racing.openNow, the purchase).
Service.requestOpen = function(_player: Player): (boolean, string?)
	return false, "That isn't on sale yet."
end
-- What opening it now costs this guest, and how many they hold (Main: Purchases.Racing.info).
Service.openInfo = function(_player: Player): { price: number?, held: number }
	return { price = nil, held = 0 }
end

type Car = {
	def: { [string]: any },
	index: number,
	home: CFrame,
	model: Model,
	chassis: BasePart,
	seat: BasePart,
	passenger: BasePart,
	driver: Player?,
	rider: Player?,
	emptySince: number?,
	lastReset: number,
}

type Racer = {
	player: Player,
	car: Car,
	slot: number,
	sector: number,
	crossings: number,
	lastS: number,
	lapStart: number,
	laps: { number },
	history: { { at: Vector3, t: number } },
	finished: number?,
	out: string?,
	progress: number,
}

type Chauffeur = { name: string, carId: string, pace: number, slot: number, behind: number, finish: number }

local cars: { Car } = {}
local byPlayer: { [Player]: Car } = {}
local remote: RemoteEvent? = nil

-- The hours: "open" (a race may start) or "closed", until when (os.clock). Only kept while no
-- race is on.
local door = { state = "open", untilAt = 0, reopenBy = nil :: string? }

local race = {
	state = "idle", -- idle | gathering | countdown | racing | results
	id = 0,
	entrants = {} :: { Player },
	racers = {} :: { Racer },
	chauffeurs = {} :: { Chauffeur },
	gatherEnds = 0,
	goAt = 0,
	firstHome = nil :: number?,
	resultsEnd = 0,
	standingsAt = 0,
}

local function cfg(): { [string]: any }
	return (Config.data :: any).GrandPrix
end

local function now(): number
	return os.clock()
end

-- The shared clock every screen reads (the chauffeurs move by it).
local function serverTime(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.time()
end

local function send(player: Player, message: { [string]: any })
	if remote then
		(remote :: RemoteEvent):FireClient(player, message)
	end
end

local function sendAll(message: { [string]: any })
	if remote then
		(remote :: RemoteEvent):FireAllClients(message)
	end
end

local function humanoidOf(player: Player): any
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player): any
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function racerOf(player: Player): Racer?
	for _, r in race.racers do
		if r.player == player then
			return r
		end
	end
	return nil
end

local function setOwner(car: Car, player: Player?)
	pcall(function()
		(car.chassis :: any):SetNetworkOwner(player)
	end)
end

local function stopMovers(car: Car)
	local drive = car.chassis:FindFirstChild("Drive")
	if drive then
		(drive :: any).VectorVelocity = Vector3.zero
	end
	pcall(function()
		car.chassis.AssemblyLinearVelocity = Vector3.zero
		car.chassis.AssemblyAngularVelocity = Vector3.zero
	end)
end

-- Puts a car at `cf` (its chassis's centre), still. `hold`: anchored there (parked, or on the grid).
local function place(car: Car, cf: CFrame, hold: boolean)
	setOwner(car, nil)
	stopMovers(car)
	car.chassis.Anchored = true
	car.model:PivotTo(cf)
	local steer = car.chassis:FindFirstChild("Steer")
	if steer then
		(steer :: any).CFrame = cf.Rotation
	end
	if not hold then
		car.chassis.Anchored = false
		if car.driver then
			setOwner(car, car.driver)
		end
	end
end

local function toBay(car: Car)
	place(car, car.home, true)
	car.emptySince = nil
end

---------------------------------------------------------------------------------------------------
-- The race
---------------------------------------------------------------------------------------------------
-- The hours on the world, for every screen and sign: open, closed or racing, and the server's
-- clock of the next change.
local function publish()
	local state = if race.state ~= "idle" then "racing" else door.state
	Workspace:SetAttribute("GrandPrixDoor", state)
	Workspace:SetAttribute("GrandPrixAt", if state ~= "racing" then serverTime() + math.max(0, door.untilAt - now()) else nil)
end

-- The race as it stands, to one screen (`to`) or every screen.
local function broadcastState(to: Player?)
	publish()
	local grid = {}
	for _, r in race.racers do
		table.insert(grid, { name = Names.of(r.player), userId = r.player.UserId, carId = r.car.def.id, slot = r.slot })
	end
	local ai = {}
	for _, c in race.chauffeurs do
		table.insert(ai, { name = c.name, carId = c.carId, slot = c.slot, pace = c.pace, behind = c.behind })
	end
	local entrants = {}
	for _, p in race.entrants do
		table.insert(entrants, Names.of(p))
	end
	local message = {
		op = "race",
		state = race.state,
		id = race.id,
		laps = cfg().laps,
		entrants = entrants,
		gatherLeft = math.max(0, race.gatherEnds - now()),
		goIn = math.max(0, race.goAt - now()),
		-- (Screens time the chauffeurs from the server's clock: the moment of the start on it.)
		startAt = serverTime() + (race.goAt - now()),
		grid = grid,
		ai = ai,
		door = door.state,
		doorLeft = math.max(0, door.untilAt - now()),
	}
	if to then
		send(to, message)
	else
		sendAll(message)
	end
end

local function openDoor(by: string?)
	door.state = "open"
	door.untilAt = now() + cfg().openSeconds
	broadcastState()
	sendAll({ op = "opened", by = by, closesIn = cfg().openSeconds, gather = cfg().gather })
end

local function closeDoor()
	door.state = "closed"
	door.untilAt = now() + cfg().closedSeconds
	broadcastState()
end

local function behindFor(slot: number): number
	local p = GrandPrix.gridSlot(slot).Position
	return math.max(0, GrandPrix.TRACK.centre.X - p.X)
end

-- A racer's distance round from the start of lap one (negative before the line).
local function progressOf(r: Racer, s: number): number
	local L = GrandPrix.length()
	if r.crossings == 0 then
		return s - L
	end
	return (r.crossings - 1) * L + s
end

local function outOf(r: Racer, why: string)
	if r.finished or r.out then
		return
	end
	r.out = why
	send(r.player, { op = "out", why = why })
end

local function startCountdown()
	local c = cfg()
	-- Only drivers still in their cars race.
	local entrants = {}
	for _, p in race.entrants do
		local car = byPlayer[p]
		if car and car.driver == p and p.Parent == Players then
			table.insert(entrants, p)
		end
	end
	if #entrants == 0 then
		race.state = "idle"
		race.entrants = {}
		broadcastState()
		return
	end
	race.state = "countdown"
	race.goAt = now() + c.countdown
	race.racers = {}
	for i, p in entrants do
		local car = byPlayer[p] :: Car
		place(car, GrandPrix.gridSlot(i), true)
		local s = GrandPrix.progress(car.chassis.CFrame.Position)
		table.insert(race.racers, {
			player = p,
			car = car,
			slot = i,
			sector = 3,
			crossings = 0,
			lastS = s,
			lapStart = 0,
			laps = {},
			history = {},
			finished = nil,
			out = nil,
			progress = 0,
		})
	end
	race.chauffeurs = {}
	local chauffeurs = math.max(0, math.min(c.field, #GrandPrix.CARS) - #entrants)
	local ai = GrandPrix.AI
	local L = GrandPrix.length()
	for k = 1, chauffeurs do
		local slot = #entrants + k
		local behind = behindFor(slot)
		local pace = ai.paces[k] or ai.paces[#ai.paces]
		local carDef = GrandPrix.CARS[((race.id + k) % #GrandPrix.CARS) + 1]
		table.insert(race.chauffeurs, {
			name = ai.names[k] or ("Chauffeur " .. k),
			carId = carDef.id,
			pace = pace,
			slot = slot,
			behind = behind,
			finish = GrandPrix.aiTimeFor(c.laps * L + behind, pace),
		})
	end
	race.firstHome = nil
	broadcastState()
end

local function begin()
	race.state = "racing"
	for _, r in race.racers do
		r.lapStart = now()
		local car = r.car
		car.chassis.Anchored = false
		setOwner(car, r.player)
		r.history = { { at = car.chassis.CFrame.Position, t = now() } }
	end
	broadcastState()
end

local function payDriver(player: Player, place_: number, time: number, field: number): (number, number)
	local data = Profiles.get(player)
	if not data then
		return 0, 0
	end
	local d = data :: any
	if type(d.racing) ~= "table" then
		d.racing = { day = -1, gems = 0, races = 0, wins = 0, best = 0 }
	end
	local c = cfg()
	local today = math.floor(os.time() / 86400)
	if d.racing.day ~= today then
		d.racing.day = today
		d.racing.gems = 0
	end
	d.racing.races += 1
	if d.racing.best == 0 or time < d.racing.best then
		d.racing.best = time
	end
	local purse = c.prizes[place_] or c.finishGilt
	local gilt = Gilt.pay(player, data, purse, "Grand Prix")
	local gems = 0
	if place_ == 1 then
		d.racing.wins += 1
		gems = math.max(0, math.min(c.winGems, c.gemsPerDay - d.racing.gems))
		if gems > 0 then
			d.gems += gems
			d.racing.gems += gems
			pcall(Service.gemsChanged, player)
		end
	end
	pcall(Service.onFinish, player, place_, field)
	return gilt, gems
end

local function finishRace()
	race.state = "results"
	race.resultsEnd = now() + cfg().results
	-- Everyone home, in order of their times (the chauffeurs' times are known to the hundredth).
	local order: { { [string]: any } } = {}
	for _, r in race.racers do
		if r.finished then
			table.insert(order, { name = Names.of(r.player), time = r.finished, racer = r })
		end
	end
	for _, ch in race.chauffeurs do
		table.insert(order, { name = ch.name, time = ch.finish, ai = true })
	end
	table.sort(order, function(a, b)
		return a.time < b.time
	end)
	local field = #race.racers + #race.chauffeurs
	local list: { { [string]: any } } = {}
	for i, row in order do
		local entry = { place = i, name = row.name, time = math.floor(row.time * 100 + 0.5) / 100, ai = row.ai == true }
		if row.racer then
			local gilt, gems = payDriver(row.racer.player, i, row.time, field)
			entry.userId = row.racer.player.UserId
			send(row.racer.player, { op = "yourResult", place = i, field = field, time = entry.time, gilt = gilt, gems = gems })
		end
		table.insert(list, entry)
	end
	for _, r in race.racers do
		if not r.finished then
			table.insert(list, { place = 0, name = Names.of(r.player), out = r.out or "Did not finish", userId = r.player.UserId })
			send(r.player, { op = "yourResult", place = 0, field = field, out = r.out or "Did not finish", gilt = 0, gems = 0 })
		end
	end
	sendAll({ op = "results", id = race.id, list = list })
	-- The cars are theirs again.
	for _, r in race.racers do
		if r.car.driver == r.player then
			r.car.chassis.Anchored = false
			setOwner(r.car, r.player)
		end
	end
end

local function trackRacer(r: Racer, t: number)
	if r.finished or r.out then
		return
	end
	local car = r.car
	if car.driver ~= r.player then
		outOf(r, "Left the car")
		return
	end
	local pos = car.chassis.CFrame.Position
	-- Nobody moves faster than a car can: measured over the last second and a half.
	table.insert(r.history, { at = pos, t = t })
	while #r.history > 2 and t - r.history[1].t > 1.5 do
		table.remove(r.history, 1)
	end
	local oldest = r.history[1]
	local span = t - oldest.t
	local flat = Vector3.new(pos.X - oldest.at.X, 0, pos.Z - oldest.at.Z).Magnitude
	if flat > GrandPrix.limit() * span + 18 then
		outOf(r, "Moved faster than any car")
		return
	end
	local s, off = GrandPrix.progress(pos)
	if off <= GrandPrix.TRACK.width / 2 + 8 then
		r.lastS = s
	end
	local sector = GrandPrix.sector(s)
	if sector == (r.sector + 1) % 4 then
		r.sector = sector
		if sector == 0 then
			r.crossings += 1
			if r.crossings >= 2 then
				local lap = t - r.lapStart
				if lap < GrandPrix.quickestLap() * 0.95 then
					outOf(r, "A lap quicker than any car can drive")
					return
				end
				table.insert(r.laps, lap)
			end
			r.lapStart = t
			if r.crossings - 1 >= cfg().laps then
				r.finished = t - race.goAt
				race.firstHome = race.firstHome or t
				send(r.player, { op = "home", time = r.finished })
				return
			end
			send(r.player, { op = "lap", lap = r.crossings, laps = cfg().laps })
		end
	end
	r.progress = progressOf(r, s)
end

local function standings(t: number)
	local L = GrandPrix.length()
	local c = cfg()
	local rows: { { [string]: any } } = {}
	local elapsed = t - race.goAt
	for _, r in race.racers do
		local done = if r.finished then 1e9 - r.finished else r.progress
		table.insert(rows, { name = Names.of(r.player), userId = r.player.UserId, done = done, out = r.out ~= nil, lap = math.clamp(r.crossings, 1, c.laps) })
	end
	for _, ch in race.chauffeurs do
		local d = GrandPrix.aiDistance(elapsed, ch.pace, c.laps + 1) - ch.behind
		local home = elapsed >= ch.finish
		table.insert(rows, { name = ch.name, ai = true, done = if home then 1e9 - ch.finish else d, lap = math.clamp(math.floor(d / L) + 1, 1, c.laps) })
	end
	table.sort(rows, function(a, b)
		if a.out ~= b.out then
			return not a.out
		end
		return a.done > b.done
	end)
	local list = {}
	for i, row in rows do
		table.insert(list, { place = i, name = row.name, userId = row.userId, ai = row.ai == true, lap = row.lap, out = row.out })
	end
	sendAll({ op = "standings", id = race.id, list = list, elapsed = elapsed })
end

local function stepRace()
	local t = now()
	local c = cfg()
	if race.state == "gathering" then
		if t >= race.gatherEnds then
			startCountdown()
		end
	elseif race.state == "countdown" then
		if t >= race.goAt then
			begin()
		end
	elseif race.state == "racing" then
		for _, r in race.racers do
			trackRacer(r, t)
		end
		if t >= race.standingsAt then
			race.standingsAt = t + 0.5
			standings(t)
		end
		local allDone = true
		for _, r in race.racers do
			if not r.finished and not r.out then
				allDone = false
			end
		end
		if allDone or t - race.goAt > c.maxRace or (race.firstHome and t - race.firstHome > c.afterFirst) then
			finishRace()
		end
	elseif race.state == "results" then
		if t >= race.resultsEnd then
			race.state = "idle"
			race.entrants = {}
			race.racers = {}
			race.chauffeurs = {}
			-- After a race, the circuit rests (unless someone opened it again meanwhile).
			if door.reopenBy then
				local by = door.reopenBy
				door.reopenBy = nil
				openDoor(by)
			else
				closeDoor()
			end
		end
	elseif race.state == "idle" then
		-- The hours: open for a while, then closed for a while.
		if door.state == "open" and t >= door.untilAt then
			closeDoor()
		elseif door.state == "closed" and t >= door.untilAt then
			openDoor(nil)
		end
	end
end

local function clockText(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- Seconds until the Grand Prix opens (0 while open or racing; after a race, the rest included).
function Service.opensIn(): number
	if race.state == "results" then
		return if door.reopenBy then 0 else math.max(0, race.resultsEnd - now()) + cfg().closedSeconds
	end
	if race.state ~= "idle" or door.state == "open" then
		return 0
	end
	return math.max(0, door.untilAt - now())
end

-- A driver presses Race. (The third value: true when the Grand Prix is closed just now.)
function Service.join(player: Player): (boolean, string?, boolean?)
	local car = byPlayer[player]
	if not car or car.driver ~= player then
		return false, "Get in a car first."
	end
	if race.state == "results" and not door.reopenBy then
		return false, "The next Grand Prix opens in " .. clockText(Service.opensIn()) .. ".", true
	end
	if race.state ~= "idle" and race.state ~= "gathering" then
		return false, "A race is on. You can join the next one when the Grand Prix opens again."
	end
	if race.state == "idle" and door.state == "closed" then
		return false, "The Grand Prix opens in " .. clockText(Service.opensIn()) .. ".", true
	end
	if table.find(race.entrants, player) then
		return true, nil
	end
	if #race.entrants >= cfg().maxDrivers then
		return false, "The grid is full."
	end
	table.insert(race.entrants, player)
	if race.state == "idle" then
		race.state = "gathering"
		race.id += 1
		race.gatherEnds = now() + cfg().gather
	end
	broadcastState()
	return true, nil
end

function Service.leaveRace(player: Player)
	local i = table.find(race.entrants, player)
	if i and race.state == "gathering" then
		table.remove(race.entrants, i)
		if #race.entrants == 0 then
			race.state = "idle"
		end
		broadcastState()
		return
	end
	local r = racerOf(player)
	if r and (race.state == "racing" or race.state == "countdown") then
		outOf(r, "Retired")
	end
end

---------------------------------------------------------------------------------------------------
-- The cars
---------------------------------------------------------------------------------------------------
local function carById(id: string): Car?
	for _, car in cars do
		if car.def.id == id then
			return car
		end
	end
	return nil
end

local function leftCar(car: Car)
	local player = car.driver
	car.driver = nil
	if player then
		byPlayer[player] = nil
		local i = table.find(race.entrants, player)
		if i and race.state == "gathering" then
			table.remove(race.entrants, i)
			if #race.entrants == 0 then
				race.state = "idle"
			end
			broadcastState()
		end
		local r = racerOf(player)
		if r then
			if race.state == "countdown" then
				r.out = "Left the car"
			else
				outOf(r, "Left the car")
			end
		end
		send(player, { op = "parked" })
	end
	if race.state == "countdown" or race.state == "racing" then
		-- (A racer's car on the grid stays put; out on the circuit it stops where it is.)
		stopMovers(car)
	else
		stopMovers(car)
	end
	setOwner(car, nil)
	car.emptySince = now()
end

-- "Drive": sits the guest at the wheel and hands them the car.
function Service.drive(player: Player, carId: string): (boolean, string?)
	local car = carById(carId)
	if not car then
		return false, "No such car."
	end
	if car.driver then
		return false, "Someone's driving that one."
	end
	if byPlayer[player] then
		return false, "You're driving already."
	end
	if car.def.private and not Service.hasGarage(player) then
		-- The purchase window, with its price: nothing is bought without the guest's yes.
		Service.offerGarage(player)
		return false, "This one is for holders of The Private Garage. It drives like every other car."
	end
	local humanoid = humanoidOf(player)
	local root = rootOf(player)
	if not humanoid or not root then
		return false, "Not now."
	end
	if humanoid.SeatPart ~= nil or Service.isBusy(player) then
		return false, "Stand up first."
	end
	if (root.Position - car.chassis.CFrame.Position).Magnitude > 24 then
		return false, "Walk up to the car."
	end
	if car.rider == player then
		car.rider = nil
	end
	car.driver = player
	byPlayer[player] = car
	car.emptySince = nil
	-- A parked car is anchored; it's let go once the driver is in (and not while on the grid).
	local holding = race.state == "countdown" and racerOf(player) ~= nil
	;(car.seat :: any):Sit(humanoid)
	if not holding then
		car.chassis.Anchored = false
		setOwner(car, player)
	end
	send(player, { op = "driving", carId = car.def.id, name = car.def.name })
	return true, nil
end

-- "Ride along": the seat beside the driver.
function Service.ride(player: Player, carId: string): (boolean, string?)
	local car = carById(carId)
	if not car or car.rider or byPlayer[player] == car then
		return false, "That seat's taken."
	end
	local humanoid = humanoidOf(player)
	local root = rootOf(player)
	if not humanoid or not root or humanoid.SeatPart ~= nil or Service.isBusy(player) then
		return false, "Not now."
	end
	if (root.Position - car.chassis.CFrame.Position).Magnitude > 24 then
		return false, "Walk up to the car."
	end
	car.rider = player
	;(car.passenger :: any):Sit(humanoid)
	return true, nil
end

-- "Reset": a stuck or overturned car put right (on the circuit during a race, where its driver
-- last was on the road).
function Service.reset(player: Player): boolean
	local car = byPlayer[player]
	if not car or car.driver ~= player then
		return false
	end
	local t = now()
	if t - car.lastReset < cfg().resetEvery then
		return false
	end
	car.lastReset = t
	local r = racerOf(player)
	local cf
	if r and race.state == "racing" and not r.finished and not r.out then
		local p, dir = GrandPrix.point(r.lastS)
		cf = CFrame.lookAt(Vector3.new(p.X, GrandPrix.RIDE, p.Z), Vector3.new(p.X + dir.X, GrandPrix.RIDE, p.Z + dir.Z))
		-- (Its record starts again where it's set down: a reset is no jump.)
		r.history = { { at = cf.Position, t = t } }
	elseif race.state == "countdown" and r then
		return false
	else
		local pos = car.chassis.CFrame.Position
		local look = car.chassis.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then
			flat = Vector3.new(1, 0, 0)
		end
		local at = Vector3.new(pos.X, GrandPrix.RIDE + 0.4, pos.Z)
		cf = CFrame.lookAt(at, at + flat.Unit)
	end
	place(car, cf, false)
	send(player, { op = "reset" })
	return true
end

local function upkeep()
	local t = now()
	for _, car in cars do
		local driver = car.driver
		if driver then
			local humanoid = humanoidOf(driver)
			if driver.Parent ~= Players or not humanoid or humanoid.SeatPart ~= car.seat then
				leftCar(car)
			end
		end
		local rider = car.rider
		if rider then
			local humanoid = humanoidOf(rider)
			if rider.Parent ~= Players or not humanoid or humanoid.SeatPart ~= car.passenger then
				car.rider = nil
			end
		end
		-- Off the world: straight back to the bay (or set right, if someone's at the wheel).
		local y = car.chassis.CFrame.Position.Y
		if y < -40 then
			if car.driver then
				car.lastReset = 0
				Service.reset(car.driver)
			else
				toBay(car)
			end
		end
		-- Left empty: home after a while (not while it's on the grid or racing).
		if not car.driver and car.emptySince and t - car.emptySince > cfg().returnAfter then
			local onGrid = false
			for _, r in race.racers do
				if r.car == car and (race.state == "countdown" or race.state == "racing") then
					onGrid = true
				end
			end
			if not onGrid then
				if car.rider then
					local humanoid = humanoidOf(car.rider)
					if humanoid then
						humanoid.Sit = false
					end
					car.rider = nil
				end
				toBay(car)
			end
		end
	end
end

local function onMessage(player: Player, message: unknown)
	if type(message) ~= "table" then
		return
	end
	local m = message :: { [string]: unknown }
	local op = m.op
	if op == "race" then
		local ok, why, closed = Service.join(player)
		if closed then
			local info = Service.openInfo(player)
			send(player, { op = "closed", why = why, opensIn = Service.opensIn(), price = info.price, held = info.held })
		elseif not ok then
			send(player, { op = "refused", why = why })
		end
	elseif op == "openNow" then
		local ok, why = Service.requestOpen(player)
		if not ok then
			send(player, { op = "refused", why = why })
		end
	elseif op == "leave" then
		Service.leaveRace(player)
	elseif op == "reset" then
		Service.reset(player)
	elseif op == "hello" then
		-- A screen that just arrived: the race as it stands.
		local car = byPlayer[player]
		if car then
			send(player, { op = "driving", carId = car.def.id, name = car.def.name })
		end
		broadcastState(player)
	end
end

-- Opens the Grand Prix now, for everyone (bought, or the owner's word). False if it's already
-- open or a race is on. (Bought as a race's results show, it opens as they close.)
function Service.openNow(by: string?): (boolean, string?)
	if race.state == "results" and not door.reopenBy then
		door.reopenBy = by or "the house"
		return true, nil
	end
	if race.state ~= "idle" then
		return false, "A race is already on."
	end
	if door.state == "open" then
		return false, "The Grand Prix is already open."
	end
	openDoor(by)
	return true, nil
end

-- The owner's word during a countdown: the race starts in a few seconds.
function Service.startNow(): (boolean, string?)
	if race.state ~= "gathering" then
		return false, if race.state == "idle" then "Nobody has pressed Race yet." else "A race is already on."
	end
	race.gatherEnds = math.min(race.gatherEnds, now() + cfg().ownerStart)
	broadcastState()
	return true, nil
end

-- Whether the Grand Prix is shut just now (no race, between its hours; or a race's results
-- showing, before it rests).
function Service.isClosed(): boolean
	return (race.state == "idle" and door.state == "closed") or (race.state == "results" and not door.reopenBy)
end

-- The hours, for the owner's tools and tests: the state and when it changes (os.clock).
function Service.door(): (string, number)
	return door.state, door.untilAt
end

-- The race as it stands (for tests and the owner's tools).
function Service.state(): { [string]: any }
	return race
end

function Service.cars(): { Car }
	return cars
end

local function setupGroups()
	pcall(function()
		local PhysicsService = game:GetService("PhysicsService")
		for _, name in { "Cars", "CarWalls", "Guests", "Staff" } do
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end
		PhysicsService:CollisionGroupSetCollidable("Cars", "Cars", false)
		PhysicsService:CollisionGroupSetCollidable("Cars", "Guests", false)
		PhysicsService:CollisionGroupSetCollidable("Cars", "Staff", false)
		PhysicsService:CollisionGroupSetCollidable("CarWalls", "Guests", false)
		PhysicsService:CollisionGroupSetCollidable("CarWalls", "Staff", false)
		PhysicsService:CollisionGroupSetCollidable("CarWalls", "Default", false)
	end)
end

function Service.start(parent: Instance?)
	setupGroups()
	remote = Remotes.event("Race") :: any
	local holder = Instance.new("Folder")
	holder.Name = "GrandPrixCars"
	holder.Parent = parent or Workspace
	door.state = "open"
	door.untilAt = now() + cfg().openSeconds
	publish()
	local fleet: { { def: { [string]: any }, home: CFrame } } = {}
	for i, def in GrandPrix.CARS do
		table.insert(fleet, { def = def, home = GrandPrix.bay(i) })
	end
	for i, def in GrandPrix.GARAGE do
		table.insert(fleet, { def = def, home = GrandPrix.privateBay(i) })
	end
	for i, entry in fleet do
		local def = entry.def
		local model = Motorcar.build(holder, def, entry.home)
		local car: Car = {
			def = def,
			index = i,
			home = entry.home,
			model = model,
			chassis = model:FindFirstChild("Chassis") :: BasePart,
			seat = model:FindFirstChild("DriverSeat") :: BasePart,
			passenger = model:FindFirstChild("PassengerSeat") :: BasePart,
			driver = nil,
			rider = nil,
			emptySince = nil,
			lastReset = 0,
		}
		table.insert(cars, car)
		-- (Wired in a pcall: where prompts have no events, as in the tests, the API above does.)
		pcall(function()
			local drivePrompt = car.seat:FindFirstChild("DrivePrompt") :: ProximityPrompt
			drivePrompt.Triggered:Connect(function(player: Player)
				local ok, why = Service.drive(player, def.id)
				if not ok then
					send(player, { op = "refused", why = why })
				end
			end)
			local ridePrompt = car.passenger:FindFirstChild("RidePrompt") :: ProximityPrompt
			ridePrompt.Triggered:Connect(function(player: Player)
				local ok, why = Service.ride(player, def.id)
				if not ok then
					send(player, { op = "refused", why = why })
				end
			end)
		end)
	end
	RemoteGuard.event(remote, "race", onMessage)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.1 then
			return
		end
		acc = 0
		local ok, err = pcall(function()
			upkeep()
			stepRace()
		end)
		if not ok then
			warn("[Maison] The Grand Prix: " .. tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local car = byPlayer[player]
		if car then
			leftCar(car)
		end
		local i = table.find(race.entrants, player)
		if i then
			table.remove(race.entrants, i)
		end
	end)
end

return Service

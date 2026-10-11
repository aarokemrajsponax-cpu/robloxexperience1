--!nocheck
-- The holiday games on the server (server/Holidays), under Lune on a fake clock, in the house's
-- test harness: when each is open, the trips there and home, trick or treat on Hallows Lane (only
-- at the door, once a round, the full bag), the turkeys (they run; a catch pays; the golden one),
-- Santa's sleigh (boarding, the flight, the Pole, gifts picked up, carried and loaded, left behind,
-- the flight home, opening them with the odds as shown), the Great Egg Hunt, the luck of the
-- Irish, the day's ceiling on Gems, and a character that jumps further than anyone can.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/holidays.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local roblox, Vector3, CFrame = H.roblox, H.Vector3, H.CFrame
local module, profiles, broadcasts = H.module, H.profiles, H.broadcasts
local services, Remotes, Config = H.services, H.Remotes, H.Config
local PlayersService = H.PlayersService

---------------------------------------------------------------------------------------------------
-- What Lune's instances don't do: events (a signal per instance and name), seats, pivots
---------------------------------------------------------------------------------------------------
local signals = {}
local nextSid = 0
local function signalOf(inst, name)
	local id = inst:GetAttribute("TestSid")
	if not id then
		nextSid += 1
		id = nextSid
		inst:SetAttribute("TestSid", id)
	end
	local key = tostring(id) .. ":" .. name
	signals[key] = signals[key] or H.signal()
	return signals[key]
end
roblox.implementProperty("ProximityPrompt", "Triggered", function(self)
	return signalOf(self, "Triggered")
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, prop)
	return signalOf(self, "prop:" .. prop)
end)
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
roblox.implementMethod("Model", "GetPivot", pivotOf)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local delta = target * pivotOf(self):Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)

---------------------------------------------------------------------------------------------------
-- The house's holiday games, and the hooks Main sets
---------------------------------------------------------------------------------------------------
-- (Staff rigs are dressed avatars Roblox builds: none here, so the hosts, Santa and the elves stay
-- in the wings. The games go on without them, as they would if Roblox couldn't build one.)
H.stubs["ServerScriptService.Server.Staff.Rig"] = function()
	return {
		build = function()
			error("no rigs under Lune")
		end,
	}
end
local HolidayGames = module("ReplicatedStorage", "Shared", "HolidayGames")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local Layout = module("ReplicatedStorage", "Shared", "Layout")
local CuriosS = module("ServerScriptService", "Server", "Curios")
local Holidays = module("ServerScriptService", "Server", "Holidays")
local Lane = Holidays.GAMES.halloween
local Field = Holidays.GAMES.thanksgiving
local Pole = Holidays.GAMES.christmas
local Eggs = Holidays.GAMES.easter

local awards = {}
local eventsOn = {}
local calendarSays = nil
Holidays.award = function(p, key)
	awards[p.UserId .. ":" .. key] = true
end
Holidays.eventOn = function(id)
	return eventsOn[id] == true
end
Holidays.calendar = function()
	return calendarSays
end
CuriosS.luck = Holidays.curioLuck
run(Holidays.start)
local ask = Remotes.funcs.HolidayAsk.OnServerInvoke
local function askAs(p, request)
	advance(0.3)
	local r
	run(function()
		r = ask(p, request)
	end)
	return r
end
local function refresh()
	run(Holidays.refresh)
	advance(0.2)
end
local function last(p, op)
	for i = #p.inbox, 1, -1 do
		if p.inbox[i].op == op then
			return p.inbox[i]
		end
	end
	return nil
end
local function count(p, op)
	local n = 0
	for _, m in p.inbox do
		if m.op == op then
			n += 1
		end
	end
	return n
end
local function cast(op)
	for i = #broadcasts, 1, -1 do
		local b = broadcasts[i]
		if b.remote == "Holiday" and b.message.op == op then
			return b.message
		end
	end
	return nil
end

-- A guest with a body (a root, a head, a humanoid) standing at `at`.
local function body(g, at)
	local m = roblox.Instance.new("Model")
	m.Name = g.Name
	local r = roblox.Instance.new("Part")
	r.Name = "HumanoidRootPart"
	r.Size = Vector3.new(2, 2, 1)
	r.CFrame = CFrame.new(at)
	r.Parent = m
	local head = roblox.Instance.new("Part")
	head.Name = "Head"
	head.CFrame = CFrame.new(at + Vector3.new(0, 1.5, 0))
	head.Parent = m
	local h = roblox.Instance.new("Humanoid")
	h.Parent = m
	m.PrimaryPart = r
	m.Parent = services.Workspace
	g.Character = m
	return r
end
local function rootOf(g)
	return g.Character:FindFirstChild("HumanoidRootPart")
end
local function at(g)
	return rootOf(g).CFrame.Position
end
-- Moves a guest as the server would (a trip): never counted as a jump of their own.
local function place(g, p)
	Holidays.ctx.moved(g)
	rootOf(g).CFrame = CFrame.new(p)
	Holidays.ctx.moved(g)
	advance(0.15)
end
local function data(g)
	return profiles[g].Data
end
local C = Config.data.HolidayGames

---------------------------------------------------------------------------------------------------
-- 1. When each is open
---------------------------------------------------------------------------------------------------
check("days are counted from 1970", HolidayGames.dayNumber(1970, 1, 1) == 0 and HolidayGames.dayNumber(2000, 3, 1) - HolidayGames.dayNumber(2000, 2, 28) == 2)
check("All Hallows' week: trick or treat from the 24th of October to the 1st of November", HolidayGames.openOn(2026, 10, 24) == "halloween" and HolidayGames.openOn(2026, 11, 1) == "halloween" and HolidayGames.openOn(2026, 10, 23) == nil and HolidayGames.openOn(2026, 11, 2) == nil)
check("Thanksgiving week, Monday to Sunday (Thursday the 26th in 2026)", HolidayGames.openOn(2026, 11, 23) == "thanksgiving" and HolidayGames.openOn(2026, 11, 29) == "thanksgiving" and HolidayGames.openOn(2026, 11, 22) == nil and HolidayGames.openOn(2026, 11, 30) == nil)
check("Christmas from the 18th to the 29th of December", HolidayGames.openOn(2026, 12, 18) == "christmas" and HolidayGames.openOn(2026, 12, 29) == "christmas" and HolidayGames.openOn(2026, 12, 17) == nil and HolidayGames.openOn(2026, 12, 30) == nil)
check("Easter from Good Friday to Easter Monday (the 28th of March in 2027)", HolidayGames.openOn(2027, 3, 26) == "easter" and HolidayGames.openOn(2027, 3, 29) == "easter" and HolidayGames.openOn(2027, 3, 25) == nil)
check("St Patrick's from the 14th to the 18th of March", HolidayGames.openOn(2027, 3, 14) == "stPatrick" and HolidayGames.openOn(2027, 3, 18) == "stPatrick" and HolidayGames.openOn(2027, 3, 19) == nil)
check("nothing on an ordinary day", HolidayGames.openOn(2026, 10, 11) == nil and HolidayGames.openOn(2027, 7, 4) == nil)

local wren = H.guest("Wren", 401)
body(wren, Layout.Foyer.spawn.Position)
check("with no holiday on, nothing is open", services.Workspace:GetAttribute("HolidayGame") == nil and askAs(wren, { op = "state" }).game == nil)
check("and there's nowhere to go", askAs(wren, { op = "go" }).ok == false)
check("a malformed ask is refused", askAs(wren, { op = "go", gilt = 1e9 }).ok == false and askAs(wren, "go").ok == false)

---------------------------------------------------------------------------------------------------
-- 2. Hallows Lane
---------------------------------------------------------------------------------------------------
eventsOn.halloween = true
refresh()
check("the All Hallows' event opens trick or treat", services.Workspace:GetAttribute("HolidayGame") == "halloween")
local lane = services.Workspace:FindFirstChild("HolidayGames") and services.Workspace.HolidayGames:FindFirstChild("HallowsLane")
check("Hallows Lane is built, away from the Maison", lane ~= nil and HolidayGames.areaAt(HolidayGames.origin("lane")) == "lane" and HolidayGames.areaAt(Layout.Foyer.spawn.Position) == nil)
local doors = Lane.doors()
check("nine doors, eight down the sides and Maison Minuit at the end", #doors == 9)
local prompts = {}
if lane then
	for _, d in lane:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "TrickOrTreat" then
			local house = d:FindFirstAncestorWhichIsA("Model")
			while house and house:GetAttribute("Door") == nil do
				house = house.Parent and house.Parent:IsA("Model") and house.Parent or nil
			end
			if house then
				prompts[house:GetAttribute("Door")] = d
			end
		end
	end
end
check("every door has its knock", #prompts == 9)
local went = askAs(wren, { op = "go" })
check("a guest goes to the Lane from the house", went.ok == true and HolidayGames.areaAt(at(wren)) == "lane" and wren:GetAttribute("HolidayArea") == "lane")
local function knock(g, i)
	advance(C.lane.knockGap + 0.1)
	prompts[i].Triggered:Fire(g)
	advance(0.1)
end
local giltWas = data(wren).gilt
knock(wren, 1)
check("knocking from the Lane's gate does nothing: come up to the door", last(wren, "treat") == nil and data(wren).gilt == giltWas)
local function atDoor(g, i)
	place(g, (doors[i] * CFrame.new(0, 0, -5)).Position + Vector3.new(0, 2.5, 0))
end
-- A jump nobody could make (a character teleported by its own screen): nothing for a moment.
rootOf(wren).CFrame = CFrame.new((doors[1] * CFrame.new(0, 0, -5)).Position + Vector3.new(0, 2.5, 0))
advance(0.3)
knock(wren, 1)
check("a character that jumped further than anyone can finds nothing for a moment", last(wren, "treat") == nil)
advance(3.2)
knock(wren, 1)
local treat = last(wren, "treat")
check("at the door: the host answers with a treat", treat ~= nil and treat.i == 1 and treat.empty == nil and treat.gilt >= C.lane.gilt and treat.host == Lane.Hosts[1].name)
check("its Gilt is paid by the server", data(wren).gilt == giltWas + treat.gilt)
check("and every screen sees the door open", cast("door") ~= nil and cast("door").i == 1 and cast("door").by == 401)
check("the treat counts for the badge, and the curio", awards["401:holiday_halloween"] == true and CuriosS.count(data(wren), "jackOLantern") == 1)
local before = data(wren).gilt
knock(wren, 1)
check("the same door twice in a round: a wave, no treat", last(wren, "treat").empty == true and data(wren).gilt == before)
-- Too quick between knocks.
atDoor(wren, 2)
knock(wren, 2)
atDoor(wren, 3)
prompts[3].Triggered:Fire(wren)
check("knocks are a moment apart", count(wren, "treat") == 3)
-- Gems: never more than the day's ceiling from all the games together.
Config.set("HolidayGames.lane.gemChance", 1)
Config.set("HolidayGames.gemsPerDay", 2)
local gemsWas = data(wren).gems or 0
for i = 3, 5 do
	atDoor(wren, i)
	knock(wren, i)
end
check("a sugared Gem with a treat now and then, never past the day's ceiling", (data(wren).gems or 0) - gemsWas <= 2 and (data(wren).gems or 0) - gemsWas >= 1, (data(wren).gems or 0) - gemsWas)
Config.set("HolidayGames.gemsPerDay", 25)
Config.set("HolidayGames.lane.gemChance", 0.15)
for i = 6, 9 do
	atDoor(wren, i)
	knock(wren, i)
end
local full = last(wren, "treat")
check("every door in one round fills the bag: more Gilt, the Candy Pail, the badge", full.full == true and full.bonusGilt > 0 and CuriosS.count(data(wren), "candyPail") == 1 and awards["401:fullBag"] == true)
check("Maison Minuit gives the most", full.i == 9 and full.gilt >= C.lane.minuitGilt)
check("the whole house hears of a full bag", (function()
	for i = #broadcasts, 1, -1 do
		local b = broadcasts[i]
		if b.remote == "Salute" and string.find(b.message.line or "", "every door", 1, true) then
			return true
		end
	end
	return false
end)())
local state = askAs(wren, { op = "state" })
check("the guest's screen is told the doors knocked this round", state.game == "halloween" and #state.visited == 9 and state.total == 9 and type(state.ends) == "number")
-- A new round: every door opens again.
H.setWallClock(os.time() + C.lane.roundMinutes * 60 + 5)
atDoor(wren, 4)
before = data(wren).gilt
knock(wren, 4)
check("a new round: the doors open to you again", last(wren, "treat").empty == nil and data(wren).gilt > before)
-- Closing: everyone on the Lane comes home.
eventsOn.halloween = false
refresh()
check("when All Hallows' ends the Lane is taken down", services.Workspace:GetAttribute("HolidayGame") == nil and services.Workspace.HolidayGames:FindFirstChild("HallowsLane") == nil)
check("and whoever was on it is back at the Maison", HolidayGames.areaAt(at(wren)) == nil and (at(wren) - Layout.Street.spawn.Position).Magnitude < 20 and wren:GetAttribute("HolidayArea") == nil)

---------------------------------------------------------------------------------------------------
-- 3. The Harvest Field
---------------------------------------------------------------------------------------------------
eventsOn.thanksgiving = true
refresh()
check("Thanksgiving opens the Harvest Field", services.Workspace:GetAttribute("HolidayGame") == "thanksgiving" and services.Workspace.HolidayGames:FindFirstChild("HarvestField") ~= nil)
check("the field's turkeys are out (and the event leaves the house's own Trot alone)", #Field.turkeys() == C.field.turkeys and Holidays.ownsHunt("thanksgiving") and Holidays.ownsHunt("easter") and not Holidays.ownsHunt("halloween"))
local hunter = H.guest("Hal", 402)
body(hunter, Layout.Foyer.spawn.Position)
check("a guest goes to the field", askAs(hunter, { op = "go" }).ok and HolidayGames.areaAt(at(hunter)) == "field")
advance(1)
local t1 = Field.turkeys()[1]
local near = t1.at + Vector3.new(9, 2.5, 0)
place(hunter, near)
local d0 = (Field.turkeys()[1].at - at(hunter)).Magnitude
advance(0.8)
local tNow
for _, t in Field.turkeys() do
	if t.id == t1.id then
		tNow = t
	end
end
check("a turkey runs from a guest who comes near", tNow ~= nil and (tNow.at - at(hunter)).Magnitude > d0 + 3, tNow and (tNow.at - at(hunter)).Magnitude)
-- Running one down.
giltWas = data(hunter).gilt
local target = Field.turkeys()[2]
place(hunter, target.at + Vector3.new(0, 2.5, 0))
advance(0.2)
local caught = last(hunter, "turkey")
check("caught: Gilt, and the turkey goes back to the barn", caught ~= nil and caught.gilt >= C.field.gilt and data(hunter).gilt >= giltWas + C.field.gilt and cast("caught") ~= nil and cast("caught").by == 402)
check("a catch earns the badge and the Golden Wishbone", awards["402:holiday_thanksgiving"] == true and CuriosS.count(data(hunter), "goldenWishbone") == 1)
place(hunter, HolidayGames.origin("field") + Vector3.new(0, 2.5, -140))
advance(C.field.back + 3)
check("another walks out of the barn to take its place", #Field.turkeys() >= C.field.turkeys)
-- The golden turkey.
advance(22)
local golden
for _, t in Field.turkeys() do
	if t.golden then
		golden = t
	end
end
check("a golden turkey walks out of the barn, and the field hears", golden ~= nil and cast("goldenTurkey") ~= nil)
if golden then
	gemsWas = data(hunter).gems or 0
	giltWas = data(hunter).gilt
	advance(C.field.catchGap)
	place(hunter, golden.at + Vector3.new(0, 2.5, 0))
	advance(0.2)
	local g = last(hunter, "turkey")
	check("the golden turkey pays far more, with Gems", g.golden == true and g.gilt >= C.field.goldenGilt and (data(hunter).gems or 0) - gemsWas == C.field.goldenGems)
	check("and its own curio and badge", CuriosS.count(data(hunter), "goldenTurkey") == 1 and awards["402:goldenTurkeyCaught"] == true)
end
eventsOn.thanksgiving = false
refresh()
check("the field is taken down after", services.Workspace.HolidayGames:FindFirstChild("HarvestField") == nil and HolidayGames.areaAt(at(hunter)) == nil)

---------------------------------------------------------------------------------------------------
-- 4. Santa's sleigh and the North Pole
---------------------------------------------------------------------------------------------------
eventsOn.christmas = true
refresh()
local sleigh = Pole.sleigh()
check("Christmas brings Santa's sleigh to the kerb, and builds the North Pole", sleigh ~= nil and services.Workspace:GetAttribute("SleighState") == "home" and services.Workspace.HolidayGames:FindFirstChild("NorthPole") ~= nil)
check("its reindeer, Rudolph leading (his nose aglow)", sleigh and sleigh:FindFirstChild("Rudolph", true) ~= nil and #sleigh.Reindeer:GetChildren() == 9 and sleigh:FindFirstChild("Rudolph", true).Nose:FindFirstChildOfClass("PointLight") ~= nil)
check("gifts lie in the snow at the Pole", #Pole.gifts() == C.pole.gifts)
local noel = H.guest("Noel", 403)
body(noel, Layout.Foyer.spawn.Position)
check("opening gifts with none is refused, and says how to get some", (function()
	local r = askAs(noel, { op = "open" })
	return r.ok == false and string.find(r.why, "sleigh", 1, true) ~= nil
end)())
local boarded = askAs(noel, { op = "board" })
check("boarding from inside the house brings you to the kerb and seats you", boarded.ok == true and (at(noel) - HolidayGames.HOME_SLEIGH.Position).Magnitude < 20 and sleigh:FindFirstChild("SleighSeat") ~= nil)
check("the sleigh waits a little for more riders", services.Workspace:GetAttribute("SleighState") == "boarding" and type(services.Workspace:GetAttribute("SleighLeaves")) == "number")
advance(C.pole.boarding + 0.3)
check("then takes off for the North Pole", services.Workspace:GetAttribute("SleighState") == "toPole" and noel:GetAttribute("SleighRide") == "toPole" and type(services.Workspace:GetAttribute("SleighT0")) == "number")
check("the rider is carried by the server, out of sight, while every screen draws the flight", rootOf(noel).Anchored == true and HolidayGames.areaAt(at(noel)) == "pole" and at(noel).Y > 200)
check("with a copy of the rider in the sleigh for the flight", sleigh:FindFirstChild("Passenger") ~= nil)
check("nobody leaves a sleigh in mid-air", askAs(noel, { op = "home" }).ok == false)
advance(C.pole.flight + 0.3)
check("it lands at the North Pole", services.Workspace:GetAttribute("SleighState") == "pole" and HolidayGames.areaAt(at(noel)) == "pole" and rootOf(noel).Anchored == false and noel:GetAttribute("SleighRide") == nil)
check("the sleigh stands on the Pole's pad, the passengers' copies gone", (sleigh.PrimaryPart.CFrame.Position - HolidayGames.poleSleigh().Position).Magnitude < 0.5 and sleigh:FindFirstChild("Passenger") == nil)
check("the first ride: the badge and Santa's Sleigh Bell", awards["403:northPole"] == true and CuriosS.count(data(noel), "sleighBell") == 1 and last(noel, "arrived").place == "pole")
-- Gifts: picked up a few at a time.
local function pickNear()
	local g = Pole.gifts()[1]
	place(noel, g.CFrame.Position + Vector3.new(0, 1.3, 0))
	advance(0.15)
end
pickNear()
check("walking into a gift picks it up", noel:GetAttribute("GiftsCarried") == 1 and cast("picked") ~= nil and cast("picked").by == 403)
for _ = 1, 7 do
	pickNear()
end
check("no more than five in your arms at once", noel:GetAttribute("GiftsCarried") == C.pole.carry)
advance(4.5)
check("the snow fills up again", #Pole.gifts() == C.pole.gifts)
-- Loading them on the sleigh.
local cargo = (sleigh.PrimaryPart.CFrame * Pole.CARGO).Position
place(noel, cargo + Vector3.new(6, 0, 0))
advance(0.2)
local loaded = last(noel, "gifts")
check("at the sleigh, they're loaded", loaded ~= nil and loaded.loaded == 5 and loaded.carrying == 0 and noel:GetAttribute("GiftsCarried") == nil)
check("and kept on the guest's record, to open at home", Holidays.saved(data(noel)).gifts == 5)
for _ = 1, 2 do
	for _ = 1, 5 do
		pickNear()
	end
	place(noel, cargo + Vector3.new(6, 0, 0))
	advance(0.2)
end
check("ten in one trip: Santa's Helper, and the Snow Globe", last(noel, "gifts").loaded == 15 and awards["403:santasHelper"] == true and CuriosS.count(data(noel), "snowGlobe") == 1)
pickNear()
pickNear()
place(noel, cargo + Vector3.new(6, 0, 0))
advance(0.2)
check("no more than fifteen loaded a trip (the rest stay in your arms)", last(noel, "full") ~= nil and noel:GetAttribute("GiftsCarried") == 2)
-- Left behind: whatever's still in your arms when it goes.
place(noel, HolidayGames.origin("pole") + Vector3.new(150, 2.5, 150))
local _, leaves = Pole.status()
advance(leaves - H.now() + 0.5)
check("everyone at the Pole flies home with it", services.Workspace:GetAttribute("SleighState") == "toHome" and noel:GetAttribute("SleighRide") == "toHome")
check("and the gifts still in your arms are left in the snow", last(noel, "dropped") ~= nil and last(noel, "dropped").n >= 2 and noel:GetAttribute("GiftsCarried") == nil)
advance(C.pole.flight + 0.3)
local home = last(noel, "arrived")
check("home: on the pavement before the Maison, told the gifts to open", services.Workspace:GetAttribute("SleighState") == "home" and HolidayGames.areaAt(at(noel)) == nil and home.place == "home" and home.gifts == 15)
check("and the sleigh is back at the kerb", (sleigh.PrimaryPart.CFrame.Position - HolidayGames.HOME_SLEIGH.Position).Magnitude < 0.5)
-- Opening them: the server chooses what each holds.
giltWas = data(noel).gilt
local opened = askAs(noel, { op = "open", n = 10 })
local kinds = { gilt = true, moreGilt = true, gems = true, moreGems = true }
check("ten opened at once: each Gilt or Gems, decided on the server", opened.ok and #opened.results == 10 and opened.gifts == 5 and (function()
	for _, r in opened.results do
		if not kinds[r.kind] or (r.gilt <= 0 and r.gems <= 0) then
			return false
		end
	end
	return true
end)())
check("and paid", data(noel).gilt > giltWas)
check("asking for fifty at once opens one (never more than ten)", (function()
	local r = askAs(noel, { op = "open", n = 50 })
	return r.ok == true and #r.results == 1
end)())
-- The odds, as the opening screen shows them.
Holidays.saved(data(noel)).gifts = 4000
local seen = { gilt = 0, moreGilt = 0, gems = 0, moreGems = 0 }
for _ = 1, 300 do
	local r
	run(function()
		r = Pole.openGifts(Holidays.ctx, noel, 10)
	end)
	for _, x in r.results do
		seen[x.kind] += 1
	end
end
local total = seen.gilt + seen.moreGilt + seen.gems + seen.moreGems
local function share(k)
	return seen[k] / total
end
check("the odds are the odds shown (60, 28, 10, 2 in 100)", math.abs(share("gilt") - 0.6) < 0.04 and math.abs(share("moreGilt") - 0.28) < 0.04 and math.abs(share("gems") - 0.1) < 0.03 and math.abs(share("moreGems") - 0.02) < 0.012, string.format("%.3f %.3f %.3f %.3f", share("gilt"), share("moreGilt"), share("gems"), share("moreGems")))
check("Gems past the day's ceiling come as Gilt instead (and say so)", (function()
	local r
	run(function()
		r = Pole.openGifts(Holidays.ctx, noel, 10)
	end)
	for _ = 1, 30 do
		for _, x in r.results do
			if (x.kind == "gems" or x.kind == "moreGems") then
				return x.converted == true and x.gems == 0 and x.gilt > 0
			end
		end
		run(function()
			r = Pole.openGifts(Holidays.ctx, noel, 10)
		end)
	end
	return false
end)())
check("the opening screen's odds add up", (function()
	local list = HolidayGames.giftOdds()
	return #list == 4 and list[1].odds == "60 in 100" and list[4].odds == "1 in 50"
end)())
-- Gifts are opened at home, never at the Pole.
local was = at(noel)
place(noel, HolidayGames.origin("pole") + Vector3.new(0, 2.5, 0))
check("not at the Pole: they're for the fireside", askAs(noel, { op = "open" }).ok == false)
place(noel, was)
-- A rider in the air when Christmas ends comes down at home.
askAs(noel, { op = "board" })
advance(C.pole.boarding + 0.3)
check("aboard again, in the air", noel:GetAttribute("SleighRide") == "toPole")
eventsOn.christmas = false
refresh()
check("Christmas over mid-flight: the rider lands at home, the sleigh and the Pole gone", noel:GetAttribute("SleighRide") == nil and rootOf(noel).Anchored == false and HolidayGames.areaAt(at(noel)) == nil and Pole.sleigh() == nil and services.Workspace:GetAttribute("SleighState") == nil)
check("unopened gifts keep after Christmas", askAs(noel, { op = "open" }).ok == true)

---------------------------------------------------------------------------------------------------
-- 5. The Great Egg Hunt
---------------------------------------------------------------------------------------------------
eventsOn.easter = true
refresh()
local eggs = Eggs.list()
local goldenEggs = 0
for _, e in eggs do
	if e:GetAttribute("Golden") then
		goldenEggs += 1
	end
end
check("Easter hides the painted eggs all over the house, one golden", #eggs == C.eggs.count and goldenEggs == 1)
check("never on a sorting table", (function()
	for _, e in eggs do
		for _, room in Layout.Rooms do
			for _, t in room.tables do
				local p = e.CFrame.Position
				if Vector3.new(p.X - t.X, 0, p.Z - t.Z).Magnitude < 8.5 then
					return false
				end
			end
		end
	end
	return true
end)())
local finder = H.guest("Ivy", 404)
body(finder, Layout.Foyer.spawn.Position)
gemsWas = data(finder).gems or 0
giltWas = data(finder).gilt
for _, e in Eggs.list() do
	place(finder, e.CFrame.Position + Vector3.new(0, 1, 0))
	advance(0.15)
end
local found = 0
for _, m in finder.inbox do
	if m.op == "eggFound" then
		found += 1
	end
end
check("walking up to an egg finds it: Gilt for every one", found == C.eggs.count and data(finder).gilt - giltWas >= C.eggs.count * C.eggs.gilt)
check("the golden egg: Gems, its curio, its badge", (data(finder).gems or 0) - gemsWas >= C.eggs.goldenGems and CuriosS.count(data(finder), "goldenEgg") == 1 and awards["404:goldenEggFound"] == true)
check("every egg found: the house hides more a minute later", cast("eggsDone") ~= nil and #Eggs.list() == 0)
advance(C.eggs.again + 1)
check("more eggs, hidden afresh", #Eggs.list() == C.eggs.count)
eventsOn.easter = false
refresh()
check("after Easter the eggs are put away", #Eggs.list() == 0 and services.Workspace:GetAttribute("HolidayGame") == nil)

---------------------------------------------------------------------------------------------------
-- 6. The luck of the Irish, and the calendar
---------------------------------------------------------------------------------------------------
check("no luck on an ordinary day", Holidays.mythicLuck() == 1 and select(1, Holidays.curioLuck()) == 1)
calendarSays = "stPatrick"
refresh()
local find, rare = Holidays.curioLuck()
check("St Patrick's week opens by the calendar alone", services.Workspace:GetAttribute("HolidayGame") == "stPatrick")
check("Mythics five times likelier, curios found more often and the rarer ones likelier", Holidays.mythicLuck() == C.luck.mythic and find == C.luck.curioFind and rare == C.luck.curioRare)
check("the luck finds more curios", CuriosS.chance(1, 0.5) > CurioList.findChance(1, 0.5))
local function rareShare(luck)
	local n = 0
	for k = 1, 4000 do
		local c = CurioList.pick((k - 0.5) / 4000, 0.5, luck)
		if CurioList.RarityRank[c.rarity] >= CurioList.RarityRank.Rare then
			n += 1
		end
	end
	return n / 4000
end
check("and Rare curios and rarer turn up far more among them", rareShare(C.luck.curioRare) > rareShare(1) * 2)
calendarSays = nil
refresh()
check("and it ends", Holidays.mythicLuck() == 1 and services.Workspace:GetAttribute("HolidayGame") == nil)

---------------------------------------------------------------------------------------------------
-- 7. Leaving
---------------------------------------------------------------------------------------------------
eventsOn.christmas = true
refresh()
local quick = H.guest("Quill", 405)
body(quick, Layout.Foyer.spawn.Position)
askAs(quick, { op = "board" })
local sat = Pole.sleigh() and Pole.sleigh():FindFirstChild("SleighSeat")
quick.Parent = nil
PlayersService.PlayerRemoving:Fire(quick)
advance(0.2)
check("a rider who leaves the house gives up their seat", sat ~= nil and sat.Parent == nil)
eventsOn.christmas = false
refresh()

H.finish()

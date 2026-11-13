--!nocheck
-- Lights Out on the dance floor (server/FloorShow), under Lune on a fake clock: the door's hours,
-- joining and leaving, the countdown, stand-ins on a quiet night (never taking the pot), guests
-- brought onto the floor, the Chairs (one guest a seat, fewer seats than guests), Lights Out (be
-- in a circle), the Spinner's duel (shoves only within reach, not too often, only by the two in
-- the ring; out of the ring, out), the last lamp's pot, the records' hooks, and the door closing.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/floorshow.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles = H.module, H.profiles

local Config = H.Config
-- (Tweens land at once here: a lamp going out is its brightness at 0.)
H.services.TweenService = {
	Create = function(_, instance, _info, goal)
		return {
			Play = function()
				for k, v in goal do
					pcall(function()
						instance[k] = v
					end)
				end
			end,
		}
	end,
}
local FloorShow = module("ServerScriptService", "Server", "FloorShow")
local F = Config.data.Ballroom.floor

local T = 1000
FloorShow.clock = function()
	return T
end
-- (The harness's dice are seeded: every run the same.)
local finished = {}
FloorShow.onFinished = function(p, place, keys, counted)
	table.insert(finished, { p = p, place = place, counted = counted })
end
local busy = {}
FloorShow.isBusy = function(p)
	return busy[p] == true
end

local workspace = H.game:GetService("Workspace")
local ada = H.guest("Ada", 801)
local bo = H.guest("Bo", 802)
local cy = H.guest("Cy", 803)
for _, g in { ada, bo, cy } do
	profiles[g].Data.gilt = 0
	g.Character = g.body
end
run(FloorShow.start)

local function tick(seconds)
	local steps = math.max(1, math.floor(seconds / 0.1 + 0.5))
	for _ = 1, steps do
		T += 0.1
		run(FloorShow.step, T)
	end
end
local function last(g, op)
	for i = #g.inbox, 1, -1 do
		if g.inbox[i].op == op then
			return g.inbox[i]
		end
	end
	return nil
end
local function stand(g, p)
	g.root.CFrame = CFrame.new(p + Vector3.new(0, 3, 0))
end
local function untilPhase(name, most)
	for _ = 1, math.floor((most or 30) / 0.1) do
		if FloorShow.current() and FloorShow.current().phase == name then
			return true
		end
		tick(0.1)
	end
	return false
end
local centre, radius = FloorShow.arena()

---------------------------------------------------------------------------------------------------
-- 1. The door, joining, the countdown
---------------------------------------------------------------------------------------------------
check("the Ballroom opens its doors: Lights Out on the floor", FloorShow.door() == "open" and workspace:GetAttribute("BallroomState") == "open" and workspace:GetAttribute("LightsOutFloor") == true)
busy[cy] = true
local ok, why = FloorShow.join(cy)
check("busy elsewhere (a table, an attraction): no joining, and it's said why", ok == false and string.find(why, "Finish what you're doing", 1, true) ~= nil, why)
busy[cy] = nil
ok = FloorShow.join(ada)
check("the first guest to join starts the countdown", ok == true and FloorShow.door() == "gathering" and last(ada, "joined") ~= nil)
check("...and the screens are told when it starts", workspace:GetAttribute("BallroomState") == "gathering" and type(workspace:GetAttribute("BallroomAt")) == "number")
FloorShow.join(bo)
FloorShow.join(cy)
check("three guests, each a lamp of their own", #FloorShow.current().guests == 3 and FloorShow.current().byPlayer[cy].seat == 3)
FloorShow.leave(cy)
check("leaving before it starts gives the lamp back", #FloorShow.current().guests == 2 and FloorShow.current().byPlayer[cy] == nil and last(cy, "left") ~= nil)
FloorShow.join(cy)
check("waiting for the start isn't being seated (free to wander)", FloorShow.isSeated(ada) == false)
tick(F.countdown + 0.2)
local s = FloorShow.current()
check("at the end of the countdown, the show begins", s.state == "playing" and last(ada, "showStart") ~= nil)
check("a quiet night: the house's stand-ins make it six (never more than the guests need)", s.of == math.max(F.fill, 3) and s.real == 3)
check("...the pot for three real guests (stand-ins add nothing)", s.pot == math.min(F.pot.most, F.pot.base + F.pot.perGuest * 3), s.pot)
check("everyone who joined is brought onto the floor", (function()
	for _, g in { ada, bo, cy } do
		local d = Vector3.new(g.root.Position.X - centre.X, 0, g.root.Position.Z - centre.Z).Magnitude
		if d > radius then
			return false
		end
	end
	return true
end)())
check("playing, a guest is as good as seated: nothing else takes them", FloorShow.isSeated(ada) == true)
local late = H.guest("Late", 809)
local ok2, why2 = FloorShow.join(late)
check("nobody joins late (asking is asking to be told when it opens again)", ok2 == false and string.find(why2 or "", "told when it opens again", 1, true) ~= nil, why2)

---------------------------------------------------------------------------------------------------
-- 2. The Chairs
---------------------------------------------------------------------------------------------------
check("round one: the Chairs, named first", s.round == 1 and s.kind == "chairs" and s.phase == "intro")
check("...the music plays", untilPhase("music", F.intro + 1))
check("...it stops, and gold seats light up: fewer than the guests", untilPhase("scramble", F.musicMax + 1) and #s.spots > 0 and #s.spots < s.alive, #s.spots)
local seats = {}
for _, spot in s.spots do
	table.insert(seats, spot)
end
stand(ada, seats[1].at)
stand(bo, seats[1].at + Vector3.new(1.5, 0, 0)) -- (the same seat: one guest a seat)
stand(cy, centre + Vector3.new(radius * 2, 0, 0))
tick(0.2)
check("a guest on a seat takes it", seats[1].by == s.byPlayer[ada] and last(ada, "safe") ~= nil)
check("...and nobody shares it", s.byPlayer[bo].holding == nil)
stand(bo, seats[2].at)
tick(0.2)
check("another seat, another guest", seats[2].by == s.byPlayer[bo])
tick(F.scramble + 1)
check("no seat when the time's up: the lamp goes out, and its guest is told why and where they finished", s.byPlayer[cy].alive == false and last(cy, "out") ~= nil and last(cy, "out").reason == "chairs" and last(cy, "out").place >= 3)
check("...seated guests stay lit", s.byPlayer[ada].alive and s.byPlayer[bo].alive)

---------------------------------------------------------------------------------------------------
-- 3. On to the end: the Lights, then the Spinner's duel
---------------------------------------------------------------------------------------------------
local sawLights, sawDuel = false, false
local refusedFar, refusedOthers, pushed = false, false, false
for _ = 1, 400 do
	if s.state ~= "playing" then
		break
	end
	if s.phase == "scramble" then
		for i, g in { ada, bo } do
			local mine = s.byPlayer[g]
			if mine.alive and not mine.holding then
				for _, spot in s.spots do
					if not spot.by then
						stand(g, spot.at)
						break
					end
				end
			end
		end
	elseif s.phase == "warn" or s.phase == "dark" then
		sawLights = true
		stand(ada, s.spots[1].at)
		stand(bo, s.spots[1].at + Vector3.new(1, 0, 0))
	elseif s.phase == "duel" and not sawDuel then
		sawDuel = true
		-- (The spinner picks the two; whichever way round, Ada does the shoving here.)
		local a, b = ada, bo
		stand(a, centre + Vector3.new(-6, 0, 0))
		stand(b, centre + Vector3.new(6, 0, 0))
		local far = FloorShow.shove(a)
		refusedFar = far == false
		local outsider = FloorShow.shove(cy)
		refusedOthers = outsider == false
		stand(b, centre + Vector3.new(4, 0, 0))
		stand(a, centre + Vector3.new(-2, 0, 0))
		local okShove = FloorShow.shove(a)
		pushed = okShove == true and last(b, "shoved") ~= nil and last(b, "shoved").by == "Ada"
		check("...a second shove straight after is too soon", FloorShow.shove(a) == false)
		-- Pushed out of the ring: out.
		stand(b, centre + Vector3.new(F.ring + 5, 0, 0))
	end
	tick(0.3)
end
check("Lights Out: circles of light, and the dark", sawLights)
check("the Spinner: with only guests left, two of them in the ring", sawDuel)
check("...a shove from too far is refused", refusedFar)
check("...nobody outside the ring can shove", refusedOthers)
check("...within reach, the other is pushed (their own screen moves them)", pushed)
check("the show ends: one lamp left", s.state == "after")
local winner
for _, g in s.guests do
	if g.place == 1 then
		winner = g
	end
end
check("the last lamp is Ada's, and she takes the pot", winner ~= nil and winner.player == ada and profiles[ada].Data.gilt >= s.pot and last(ada, "showResult").won == true, profiles[ada].Data.gilt)
check("...nobody else is paid", profiles[bo].Data.gilt == 0 and profiles[cy].Data.gilt == 0)
check("every guest's place goes to the records (a quiet night isn't counted)", #finished == 3 and finished[1].counted == false)
check("...and everyone hears who won", last(bo, "showEnd") ~= nil and last(bo, "showEnd").winner == "Ada")
tick(9)
check("then the Ballroom closes until its next opening", FloorShow.door() == "closed" and FloorShow.isClosed())

---------------------------------------------------------------------------------------------------
-- 4. Closed: reminders, and opening it now
---------------------------------------------------------------------------------------------------
local ok3, why3 = FloorShow.join(bo)
check("closed: joining asks to be reminded, and says when it opens", ok3 == false and string.find(why3, "opens in", 1, true) ~= nil)
check("opening it now (the purchase, or the owner)", FloorShow.openNow("Ada") == true and FloorShow.door() == "open" and last(bo, "reminder") ~= nil)
check("...and whoever asked during the last show is told too", last(late, "reminder") ~= nil)
check("...not twice", FloorShow.openNow("Ada") == false)
-- Saying hello: the door, and what opening it early costs this guest (on the key, never hidden).
FloorShow.openOffer = function(p)
	return 49, if p == ada then 1 else 0
end
H.advance(1)
run(function()
	H.Remotes.event("LightsOut").OnServerEvent:Fire(ada, { op = "hello" })
end)
local hi = last(ada, "hello")
check("hello: the door's state, the pot, and opening it now's price and the credits held", hi ~= nil and hi.state == "open" and hi.openPrice == 49 and hi.openHeld == 1 and type(hi.pot) == "number", hi and hi.openPrice)

---------------------------------------------------------------------------------------------------
-- 5. A night of stand-ins: the last real guest out ends it, and no stand-in is paid
---------------------------------------------------------------------------------------------------
FloorShow.join(cy)
tick(F.countdown + 0.2)
s = FloorShow.current()
check("one guest and the stand-ins", s.state == "playing" and s.real == 1 and s.of == F.fill)
stand(cy, centre + Vector3.new(radius * 2, 0, 0))
for _ = 1, 200 do
	if s.state ~= "playing" then
		break
	end
	tick(0.3)
end
check("the only guest out: the show ends at once", s.state == "after" and s.byPlayer[cy].alive == false)
check("...and the stand-ins take no pot", profiles[cy].Data.gilt == 0 and last(cy, "showResult").won == false)

H.finish()

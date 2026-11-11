--!nocheck
-- The Executive Suite on the server (server/Attractions/Executive, ExecutiveBuild, World/Lobbies),
-- under Lune on a fake clock, in the house's test harness: the Anteroom in the Midnight Room, the
-- sidearm (free, and needed), invitations (earned, bought for Gilt, spent going up; never chance,
-- never Robux), gear (packed for the next run, for Gilt), the hallway's cameras and the alert
-- (slower in a disguise, nobody looking during a decoy, full: shown out), the terminals' digits and
-- the code door, the Executive's three phases, his attacks (the briefcases, the shockwave jumped),
-- composure, the rewards, the safe once each, the lift down, and every shot judged by the server.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/executive.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles, broadcasts = H.module, H.profiles, H.broadcasts
local Remotes, Config = H.Remotes, H.Config

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
local Plan = module("ReplicatedStorage", "Shared", "Executive")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Game = module("ServerScriptService", "Server", "Attractions", "Executive")
local Basement = module("ServerScriptService", "Server", "Attractions", "Basement")
local Luxe = module("ServerScriptService", "Server", "Attractions", "Luxe")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Fortune = module("ServerScriptService", "Server", "Fortune")
local Herald = module("ServerScriptService", "Server", "Herald")
local C = Config.data.Attractions.executive

local T = 2000
Game.clock = function()
	return T
end
local aimAt = nil -- what the next shot hits
Game.ray = function()
	return aimAt
end
local walled = false
Game.clear = function()
	return not walled
end
Game.walk = function() end
local awards = {}
Attractions.award = function(p, key)
	table.insert(awards, { p = p, key = key })
end

local workspace = H.game:GetService("Workspace")
Lobbies.build(workspace)
local ada = H.guest("Ada", 701)
local bo = H.guest("Bo", 702)
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
local function stand(g, at, y)
	g.Character = g.body
	g.root.CFrame = CFrame.new(at + Vector3.new(0, y or 3, 0))
end
local function standIn(g, v, y)
	stand(g, O + v, y)
end
local function steps(n)
	for _ = 1, n do
		advance(0.1)
	end
end
local fire = Remotes.event("AttractionFire")
local function shoot(g, target)
	aimAt = target
	advance(0.35)
	run(function()
		fire.OnServerEvent:Fire(g, Vector3.new(0, 0, 1))
	end)
	aimAt = nil
end
local function page(g)
	return Game.page(Attractions.ctx, data(g))
end

for _, g in { ada, bo } do
	data(g).gilt = 0
	data(g).gems = 0
end

---------------------------------------------------------------------------------------------------
-- 1. The Anteroom, the sidearm, invitations
---------------------------------------------------------------------------------------------------
do
	local kinds = {}
	for _, p in H.tagged.AttractionPrompt or {} do
		kinds[p:GetAttribute("Kind") .. ":" .. p:GetAttribute("Attraction")] = p
	end
	local veil = kinds["go:executive"] and kinds["go:executive"].Parent
	check("the lift up stands in the Midnight Room (the Executive's Anteroom)", veil ~= nil and Layout.zoneAt(veil.CFrame.Position) == "midnight")
	check("...with the Quartermaster's desk", kinds["panel:executive"] ~= nil)
	check("the Midnight Room's door is open to everyone now (the invitation is checked at the lift)", Layout.RoomDoors.midnight.open == true and Layout.RoomDoors.midnight.gated == false)
	check("Il Dirigente Supremo is a real brainrot", CurioList.byId.dirigenteSupremo ~= nil)
end
stand(ada, Layout.Midnight.arrival)
local r = askAs(ada, { op = "go", id = "executive" })
check("no sidearm: the lift says to take the free stun pistol from the Quartermaster first", r.ok == false and string.find(r.why, "free stun pistol", 1, true) ~= nil and string.find(r.why, "Quartermaster", 1, true) ~= nil, r.why)
r = askAs(ada, { op = "act", id = "executive", act = "sidearm" })
check("the sidearm is free", r.ok == true and page(ada).sidearm == true and data(ada).gilt == 0)
r = askAs(ada, { op = "go", id = "executive" })
check("no invitation: said plainly, with every way to get one and the real figures", r.ok == false and string.find(r.why, "You need an invitation", 1, true) ~= nil and string.find(r.why, "Maison Basement", 1, true) ~= nil and string.find(r.why, "8,000", 1, true) ~= nil and string.find(r.why, "25,000 Gilt", 1, true) ~= nil, r.why)
r = askAs(ada, { op = "act", id = "executive", act = "invite" })
check("an invitation for Gilt, without the Gilt: its price", r.ok == false and r.why == "An invitation is 25,000 Gilt.", r.why)
data(ada).gilt = 30000
r = askAs(ada, { op = "act", id = "executive", act = "invite" })
check("with it: an invitation, for exactly its price", r.ok == true and page(ada).invites == 1 and data(ada).gilt == 5000)
-- Earned.
run(function()
	Basement.cleared(ada)
end)
check("the Maison Basement cleared: an invitation", page(ada).invites == 2 and last(ada, "invited") ~= nil and last(ada, "invited").why == "basement")
run(function()
	Luxe.banked(ada, 7999)
end)
check("a haul under the mark: none", page(ada).invites == 2)
run(function()
	Luxe.banked(ada, C.inviteHaul)
end)
check("a great haul banked in Steal a Luxe: an invitation", page(ada).invites == 3)
page(ada).invites = C.maxInvites
run(function()
	Luxe.banked(ada, 50000)
end)
check("never more than the most a guest holds", page(ada).invites == C.maxInvites)
check("the owner can give one too", (function()
	page(bo).invites = 0
	return Attractions.invite(bo) == true and page(bo).invites == 1
end)())
-- Gear.
data(ada).gilt = 0
r = askAs(ada, { op = "act", id = "executive", act = "gear", what = "disguise" })
check("gear for Gilt, without the Gilt: its price", r.ok == false and r.why == "That's 4,000 Gilt.", r.why)
data(ada).gilt = 10000
r = askAs(ada, { op = "act", id = "executive", act = "gear", what = "disguise" })
check("a disguise, packed for the next run, for exactly its price", r.ok == true and page(ada).kit.disguise == true and data(ada).gilt == 6000)
r = askAs(ada, { op = "act", id = "executive", act = "gear", what = "disguise" })
check("...and not sold twice", r.ok == false and data(ada).gilt == 6000)
r = askAs(ada, { op = "act", id = "executive", act = "gear", what = "decoy" })
check("a decoy too", r.ok == true and page(ada).kit.decoy == true)
r = askAs(ada, { op = "act", id = "executive", act = "gear", what = "sidearm" })
check("the sidearm isn't for sale (it's free)", r.ok == false)
local st = askAs(ada, { op = "state", id = "executive" })
check("the Quartermaster's board: invitations, every piece of gear with its price, what's packed", st.ok == true and st.invites == C.maxInvites and #st.gear == 5 and st.invitePrice == C.invitePrice)

---------------------------------------------------------------------------------------------------
-- 2. Up to the Suite: the hallway
---------------------------------------------------------------------------------------------------
local before = page(ada).invites
r = askAs(ada, { op = "go", id = "executive" })
check("with a sidearm and an invitation, up they go", r.ok == true and Attractions.inside(ada) == "executive", r.why)
check("...an invitation spent", page(ada).invites == before - 1)
check("...the gear they packed is with them (only in the Suite), and unpacked from the board", Game.guests[ada].gear.disguise == true and Game.guests[ada].gear.decoy == true and Game.guests[ada].gear.sidearm == true and next(page(ada).kit) == nil)
check("they arrive by the lift, at the hallway's start", (ada.root.CFrame.Position - (O + Plan.Arrival + Vector3.new(0, 3, 0))).Magnitude < 0.01)
steps(2)
-- A camera, looking straight across: seen (slower in a disguise).
local cam = Plan.Cameras[1]
T = 6000 - cam.phase * cam.period -- (its sweep at the middle)
standIn(ada, Vector3.new(0, 0, cam.at.Z))
steps(10)
local a1 = Game.guests[ada].alert
check("in a camera's sight, the alert rises (slower in a disguise)", a1 > 0.2 and a1 < 0.35, a1)
-- A decoy: nobody looks at anyone.
r = askAs(ada, { op = "act", id = "executive", act = "decoy" })
check("a decoy, once", r.ok == true)
local a2 = Game.guests[ada].alert
steps(20)
check("while it's out, nobody watches anyone (the alert falls)", Game.guests[ada].alert < a2)
r = askAs(ada, { op = "act", id = "executive", act = "decoy" })
check("...and only once a run", r.ok == false)
-- Behind a wall: unseen.
T += 20
walled = true
local a3 = Game.guests[ada].alert
steps(10)
check("out of sight, the alert falls", Game.guests[ada].alert <= a3)
walled = false
-- The terminals: a digit each.
r = askAs(ada, { op = "act", id = "executive", act = "terminal", n = 1 })
check("a terminal out of reach gives nothing", r.ok == false and r.why == "Get closer to it.")
local code = Game.run.code
for n, at in Plan.Terminals do
	standIn(ada, at + Vector3.new(if at.X < 0 then 3 else -3, 0, 0))
	r = askAs(ada, { op = "act", id = "executive", act = "terminal", n = n })
	check("terminal " .. n .. " gives its digit, to the guest who read it", r.ok == true and last(ada, "digit").n == n and last(ada, "digit").digit == string.sub(code, n, n))
end
check("their screen shows the code as found", last(ada, "executive").digits == table.concat({ string.sub(code, 1, 1), string.sub(code, 2, 2), string.sub(code, 3, 3), string.sub(code, 4, 4) }, " "))
-- The door.
r = askAs(ada, { op = "act", id = "executive", act = "code", code = "1234" })
check("the code from afar: at the keypad", r.ok == false and r.why == "Enter it at the keypad by the door.")
standIn(ada, Vector3.new(0, 0, Plan.Door.z - 4))
local wrong = if code == "0000" then "1111" else "0000"
r = askAs(ada, { op = "act", id = "executive", act = "code", code = wrong })
check("a wrong code", r.ok == false and r.why == "That's not the code.")
r = askAs(ada, { op = "act", id = "executive", act = "code", code = "12a4" })
check("four digits only", r.ok == false and r.why == "Four digits.")
askAs(ada, { op = "act", id = "executive", act = "code", code = wrong })
local alertBefore = Game.guests[ada].alert
r = askAs(ada, { op = "act", id = "executive", act = "code", code = wrong })
check("three wrong: the alert jumps", r.ok == false and Game.guests[ada].alert >= alertBefore + 0.4)
r = askAs(ada, { op = "act", id = "executive", act = "code", code = code })
check("the right code opens the door, for everyone up here", r.ok == true and Game.run.open == true and Game.built().door.CanCollide == false and last(ada, "doorOpen") ~= nil)
check("...its wheel, bolts and bands go with it", #Game.built().doorDressing >= 10 and (function()
	for _, p in Game.built().doorDressing do
		if p.Transparency ~= 1 then
			return false
		end
	end
	return true
end)())

---------------------------------------------------------------------------------------------------
-- 3. The Office: three phases
---------------------------------------------------------------------------------------------------
standIn(ada, Vector3.new(-10, 0, 10))
steps(2)
check("into the Office: the Executive, behind his shield", Game.run.phase == "shield" and last(ada, "phase").phase == "shield")
-- Shots: the server judges them.
shoot(ada, "boss")
check("he can't be hurt behind his shield", Game.run.actors.boss.hp == 1)
local genHp = Game.run.generators.gen1
shoot(ada, "gen1")
check("a shot that hits a generator stuns it a little", Game.run.generators.gen1 == genHp - C.damage)
aimAt = "gen1"
advance(0.35)
run(function()
	fire.OnServerEvent:Fire(ada, Vector3.new(0, 0, 1))
	fire.OnServerEvent:Fire(ada, Vector3.new(0, 0, 1))
end)
aimAt = nil
check("never two shots closer than the sidearm allows", Game.run.generators.gen1 == genHp - 2 * C.damage)
advance(0.4)
run(function()
	fire.OnServerEvent:Fire(ada, "everything")
end)
check("a shot that isn't one is ignored", Game.run.generators.gen1 == genHp - 2 * C.damage)
for _, gen in { "gen1", "gen2", "gen3" } do
	while Game.run.generators[gen] > 0 do
		shoot(ada, gen)
	end
end
check("the three generators down: his security detail", Game.run.phase == "detail" and Game.built().shield.CanCollide == false)
local guards = 0
for _, a in Game.run.actors do
	if a.kind == "guard" then
		guards += 1
	end
end
check("four bodyguards", guards == 4)
-- A bodyguard close by: his fists.
local g1 = Game.run.actors.guard1
local composure = Game.guests[ada].composure
g1.root.CFrame = CFrame.new(ada.root.CFrame.Position + Vector3.new(2, 0, 0))
T += 2
steps(2)
check("a bodyguard within reach takes composure", Game.guests[ada].composure == composure - C.punch and last(ada, "hurt").why == "bodyguard")
for k = 1, 4 do
	while Game.run.actors["guard" .. k].hp > 0 do
		shoot(ada, "guard" .. k)
	end
end
check("all four stunned: the Executive himself", Game.run.phase == "boss" and Game.run.actors.boss.hp > 1)
-- His briefcases.
composure = Game.guests[ada].composure
T = Game.run.nextAttack + 0.01
steps(1)
local thrown = last(ada, "throw")
check("he throws briefcases (every screen is told where, and when)", thrown ~= nil and thrown.speed > 0)
local s = Game.run.shots[#Game.run.shots]
T = s.born + 0.3
local p1 = s.from + s.dir * s.speed * 0.3
standIn(ada, Vector3.new(p1.X, 0, p1.Z))
steps(1)
check("a briefcase that reaches you takes composure, once", Game.guests[ada].composure == composure - C.briefcase)
steps(2)
check("...only once", Game.guests[ada].composure == composure - C.briefcase)
-- The shockwave: jump it.
T = Game.run.nextAttack + 0.01
steps(1)
local w = Game.run.waves[#Game.run.waves]
check("his shockwave (every screen is told)", w ~= nil and last(ada, "wave") ~= nil)
composure = Game.guests[ada].composure
T = w.born + 0.5
standIn(ada, w.at + Vector3.new(w.speed * 0.5, 0, 0), 6.5)
steps(1)
check("in the air as it passes: it misses", Game.guests[ada].composure == composure)
local w2 = nil
Game.run.waves = {}
T = Game.run.nextAttack + 3 * 2.6 + 0.01
Game.run.attackIndex = 1 -- (the next is the shockwave)
Game.run.nextAttack = T - 0.01
steps(1)
w2 = Game.run.waves[#Game.run.waves]
T = w2.born + 0.5
standIn(ada, w2.at + Vector3.new(w2.speed * 0.5, 0, 0))
steps(1)
check("on the ground as it passes: it takes composure", Game.guests[ada].composure == composure - C.shockwave)
-- Bo comes up and is escorted out at no composure.
stand(bo, Layout.Midnight.arrival)
data(bo).gilt = 0
askAs(bo, { op = "act", id = "executive", act = "sidearm" })
r = askAs(bo, { op = "go", id = "executive" })
check("(Bo comes up)", r.ok == true)
standIn(bo, Vector3.new(10, 0, 10))
steps(2)
Game.guests[bo].composure = 5
local s2 = nil
Game.run.attackIndex = 0
Game.run.nextAttack = T
T += 0.01
steps(1)
for _, sh in Game.run.shots do
	s2 = sh
end
T = s2.born + 0.2
local p2 = s2.from + s2.dir * s2.speed * 0.2
standIn(bo, Vector3.new(p2.X, 0, p2.Z))
standIn(ada, Vector3.new(-25, 0, 50))
steps(1)
check("no composure left: escorted out", Attractions.inside(bo) == nil and last(bo, "escorted") ~= nil)
-- He falls.
local estateWas = Fortune.page(data(ada)).estate
local gemsWas = data(ada).gems
standIn(ada, Vector3.new(-10, 0, 10))
while Game.run.actors.boss.hp > 0 do
	shoot(ada, "boss")
end
local won = last(ada, "won")
check("the Executive beaten: everyone in the Office is paid", Game.run.phase == "won" and won ~= nil and Fortune.page(data(ada)).estate == estateWas + C.prize)
check("...his Gems", data(ada).gems == gemsWas + C.prizeGems and won.gems == C.prizeGems)
check("...Il Dirigente Supremo, the first time", won.first == true and won.brainrot == "dirigenteSupremo" and (data(ada).curios.items.dirigenteSupremo or 0) == 1)
check("...the badge", (function()
	for _, a in awards do
		if a.p == ada and a.key == "executiveBoss" then
			return true
		end
	end
	return false
end)())
check("...nobody escorted out is paid", ((data(bo).curios and data(bo).curios.items.dirigenteSupremo) or 0) == 0 and last(bo, "won") == nil)
-- The safe and the lift down.
r = askAs(ada, { op = "act", id = "executive", act = "safe" })
check("the safe from afar: closer", r.ok == false)
standIn(ada, Plan.Safe + Vector3.new(-4, 0, 0))
estateWas = Fortune.page(data(ada)).estate
r = askAs(ada, { op = "act", id = "executive", act = "safe" })
check("the safe, once each: to the Estate", r.ok == true and Fortune.page(data(ada)).estate == estateWas + C.safe)
r = askAs(ada, { op = "act", id = "executive", act = "safe" })
check("...only once", r.ok == false)
check("the lift down is open", Game.built().liftDown.Enabled == true)
advance(3)
Game.built().liftDown.Triggered:Fire(ada)
check("and takes them home", Attractions.inside(ada) == nil and Layout.zoneAt(ada.root.CFrame.Position) == "midnight")
-- Empty: a new run.
check("the Suite empty: a new run, with a new code", Game.run.phase == "hall" and Game.run.open == false and Game.built().door.CanCollide == true)
check("...and the vault door shut again, dressed as it was", Game.built().door.Transparency == 0 and Game.built().doorDressing[1].Transparency == 0)
check("the Office's decoration never stops a shot or a guard's eye", (function()
	local root = Game.built().root
	local dressing = root:FindFirstChild("Dressing")
	if not dressing then
		return false
	end
	for _, d in dressing:GetDescendants() do
		if d:IsA("BasePart") and d.CanQuery then
			return false
		end
	end
	return true
end)())

---------------------------------------------------------------------------------------------------
-- 4. The alarm
---------------------------------------------------------------------------------------------------
page(ada).invites = 1
stand(ada, Layout.Midnight.arrival)
advance(3)
r = askAs(ada, { op = "go", id = "executive" })
check("(up again, no disguise this time)", r.ok == true and Game.guests[ada].gear.disguise == nil)
T = 9000 - cam.phase * cam.period
standIn(ada, Vector3.new(0, 0, cam.at.Z))
steps(30)
check("seen long enough: the alarm, and security shows them out", Attractions.inside(ada) == nil and last(ada, "alarm") ~= nil)

H.finish()

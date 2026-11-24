--!nocheck
-- (Build 102) Private wings and the elevator (server/Wings) under Lune in the house's test harness:
-- each guest's own copy of the Suite and the Vault, high above the house; the three journeys and
-- their exact lengths (5.5 seconds to your own Suite or Vault, 6.5 to a friend's); one journey at a
-- time; friends only, and only when the host allows it (asked again at the door); nobody in a wing
-- that isn't theirs, or in the house's own sealed Suite and Vault; visitors taken home when the
-- host closes up or leaves; the zones the rest of the house sees in a wing.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/wings.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module = H.module
local Instance, Vector3, CFrame = H.Instance, H.Vector3, H.CFrame

local Wing = module("ReplicatedStorage", "Shared", "Wing")
local Layout = module("ReplicatedStorage", "Shared", "Layout")
local Friends = module("ServerScriptService", "Server", "Friends")
local Wings = module("ServerScriptService", "Server", "Wings")
local SuiteVisits = module("ServerScriptService", "Server", "SuiteVisits")

-- A small house to copy: a Suite with a floor, a Vault with a floor, the lift's two landings.
local Workspace = H.game:GetService("Workspace")
local maison = Instance.new("Folder")
maison.Name = "Maison"
local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end
local function part(name, parent, at)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CFrame = CFrame.new(at)
	p.Parent = parent
	return p
end
local suite = model("Suite", maison)
part("Floor", suite, Vector3.new(-45, 21.9, 45))
local vault = model("Vault", maison)
part("Floor", vault, Vector3.new(-8, 2.9, 53))
local passages = Instance.new("Folder")
passages.Name = "Passages"
passages.Parent = maison
local landing = model("Lift_suite", passages)
local push = part("Push", landing, Layout.Lift.suite.centre)
local prompt = Instance.new("ProximityPrompt")
prompt.Name = "LiftPrompt"
prompt.Parent = push
model("VaultDoor", passages)
maison.Parent = Workspace

local friendsWith = {}
Friends.are = function(a, b)
	return friendsWith[a.UserId .. ":" .. b.UserId] == true or friendsWith[b.UserId .. ":" .. a.UserId] == true
end
Friends.inServer = function(p)
	local out = {}
	for _, other in H.game:GetService("Players"):GetPlayers() do
		if other ~= p and Friends.are(p, other) then
			table.insert(out, other)
		end
	end
	return out
end
local open = {}
Wings.mayVisit = function(host, _visitor)
	if open[host] then
		return true, nil
	end
	return false, "Their Suite is closed to visitors."
end
local visits = {}
Wings.visited = function(v, h)
	table.insert(visits, { v, h })
end
local hosts = {}
Wings.hostChanged = function(p, h)
	hosts[p] = h
end

local ada = H.guest("Ada", 3101)
local bo = H.guest("Bo", 3102)
local cy = H.guest("Cy", 3103)
friendsWith["3101:3102"] = true
for _, g in { ada, bo, cy } do
	g.Character = g.body
end
run(Wings.start)

local function rootOf(g)
	return g.Character:FindFirstChild("HumanoidRootPart")
end
local function standAt(g, p)
	rootOf(g).CFrame = CFrame.new(p)
end
local function events(g, op)
	local n = 0
	for _, m in g.inbox do
		if type(m) == "table" and m.op == op then
			n += 1
		end
	end
	return n
end
local function ask(g, request)
	local r
	run(function()
		r = Wings.handle(g, request)
	end)
	return r
end
local foyer = Vector3.new(0, 6, 20)
standAt(ada, foyer)
standAt(bo, foyer)
standAt(cy, foyer)

---------------------------------------------------------------------------------------------------
-- 1. Each guest's own wing
---------------------------------------------------------------------------------------------------
check("every guest is given a wing of their own as they arrive, never shared", Wings.slotOf(ada) ~= nil and Wings.slotOf(bo) ~= nil and Wings.slotOf(cy) ~= nil and Wings.slotOf(ada) ~= Wings.slotOf(bo) and Wings.slotOf(bo) ~= Wings.slotOf(cy))
check("...and their screen is told which (so it keeps it drawn)", ada:GetAttribute("Wing") == Wings.slotOf(ada))
local wa = Wings.ensure(Wings.slotOf(ada))
check("a wing is a real copy of the Suite, the Vault and the lift's landings, up where it stands", wa ~= nil and wa:FindFirstChild("Suite") ~= nil and wa:FindFirstChild("Vault") ~= nil and wa:FindFirstChild("Passages") ~= nil and math.abs(wa.Suite.Floor.CFrame.Position.Y - (21.9 + Wing.offset(Wings.slotOf(ada)).Y)) < 1e-3)
check("...without the house's Vault door to the Foyer, and with its open sides walled", wa.Passages:FindFirstChild("VaultDoor") == nil and wa:FindFirstChild("Seals") ~= nil and wa.Seals:FindFirstChild("VaultSouth") ~= nil and wa.Seals:FindFirstChild("GalleryEnd") ~= nil)
-- (Build 104) A wing's own grounds: nothing to fall from, nothing below to see.
do
	local g = wa:FindFirstChild("Garden")
	local up = Wing.offset(Wings.slotOf(ada)).Y
	local lawn = g and g:FindFirstChild("Lawn")
	local S = Layout.Suite
	local top = lawn and (lawn.CFrame.Position.Y + lawn.Size.Y / 2)
	check("Build 104: a wing has its own walled garden: a lawn just under the Suite's floor, all round it", lawn ~= nil and math.abs(top - (S.floorY + up)) < 0.1 and (function()
		local c, half = lawn.CFrame.Position, lawn.Size / 2
		return c.X - half.X <= S.zone.min.X and c.X + half.X >= S.galleryZone.max.X and c.Z - half.Z <= S.zone.min.Z and c.Z + half.Z >= S.zone.max.Z
	end)())
	local walls, tallEnough, barriers = 0, true, 0
	for _, n in { "WallN", "WallS", "WallW", "WallE" } do
		local w = g and g:FindFirstChild(n)
		if w then
			walls += 1
			if w.CFrame.Position.Y + w.Size.Y / 2 < S.floorY + up + 12 then
				tallEnough = false
			end
		end
		local b = g and g:FindFirstChild(n .. "Barrier")
		if b and b.CanCollide and b.Transparency == 1 and b.CFrame.Position.Y + b.Size.Y / 2 > S.floorY + up + 100 then
			barriers += 1
		end
	end
	check("...walled on all four sides, taller than a guest looking over (only sky beyond)", walls == 4 and tallEnough)
	check("...and an unseen barrier above every wall, so nobody leaves over them", barriers == 4)
	local seats = 0
	for _, d in g:GetDescendants() do
		if d.Name == "SitSpot" then
			seats += 1
		end
	end
	check("...two garden benches with real seats", seats == 4, seats)
	local vf = g and g:FindFirstChild("VaultFloor")
	check("...and the Vault below on a floor of its own, walled in unseen", vf ~= nil and g:FindFirstChild("VaultBarrierN") ~= nil and g:FindFirstChild("VaultBarrierS") ~= nil and g:FindFirstChild("VaultBarrierW") ~= nil and g:FindFirstChild("VaultBarrierE") ~= nil)
end
local inWing = Wings.arrival(Wings.slotOf(ada), "suite").Position
check("in a wing, the house sees the Suite (and nothing else is up there)", Layout.zoneAt(inWing) == "suite" and Layout.zoneAt(Wings.arrival(Wings.slotOf(ada), "vault").Position) == "vault" and Layout.zoneAt(inWing + Vector3.new(500, 0, 0)) == "none")
check("...and the house itself is just as it was", Layout.zoneAt(Layout.Foyer.spawn.Position) == "foyer" and Layout.zoneAt(Layout.Suite.arrival) == "suite")

---------------------------------------------------------------------------------------------------
-- 2. The three journeys, exactly as long as promised
---------------------------------------------------------------------------------------------------
local r = ask(ada, { op = "ride", to = "suite" })
check("Ada rides to her Suite", r.ok == true, r)
check("...her screen is told the journey: 5.5 seconds", events(ada, "elevator") == 1)
check("a second ride while the first is under way is refused (no double trips)", ask(ada, { op = "ride", to = "vault" }).ok == false)
advance(5.4)
check("at 5.4 seconds she is still on her way", Wing.slotAt(rootOf(ada).Position) == nil)
advance(0.15)
check("at 5.5 seconds she steps out in her own Suite", Wing.slotAt(rootOf(ada).Position) == Wings.slotOf(ada) and Layout.zoneAt(rootOf(ada).Position) == "suite" and events(ada, "elevatorArrived") == 1)
advance(1.1)
r = ask(ada, { op = "ride", to = "vault" })
check("from her Suite, down to her Vault", r.ok == true, r)
advance(5.45)
check("not before 5.5 seconds", Layout.zoneAt(rootOf(ada).Position) == "suite")
advance(0.1)
check("in her own Vault at 5.5 seconds", Wing.slotAt(rootOf(ada).Position) == Wings.slotOf(ada) and Layout.zoneAt(rootOf(ada).Position) == "vault")
advance(1.1)
ask(ada, { op = "ride", to = "suite" })
advance(5.6)

-- A friend's Suite: only a friend, only when the host allows it.
r = ask(cy, { op = "ride", to = "friend", userId = 3101 })
check("someone who isn't Ada's friend can't ride to her Suite", r.ok == false and r.why ~= nil)
r = ask(bo, { op = "ride", to = "friend", userId = 3101 })
check("her friend can't either while her Suite is closed to visitors", r.ok == false and r.why == "Their Suite is closed to visitors.", r)
open[ada] = true
r = ask(bo, { op = "ride", to = "friend", userId = 3101 })
check("once she opens it, her friend rides up", r.ok == true, r)
check("...told on their screen before the doors open which wing to draw", bo:GetAttribute("WingVisit") == Wings.slotOf(ada))
advance(6.4)
check("at 6.4 seconds he is still on his way", Wing.slotAt(rootOf(bo).Position) == nil)
advance(0.15)
check("at 6.5 seconds he steps out in Ada's Suite, as her visitor", Wing.slotAt(rootOf(bo).Position) == Wings.slotOf(ada) and Wings.hostOf(bo) == ada and hosts[bo] == ada)
check("...and the Badge Book hears of the visit", #visits == 1 and visits[1][1] == bo and visits[1][2] == ada)
check("...and Ada is told who has come up", (function()
	for _, m in ada.inbox do
		if type(m) == "table" and m.op == "notice" and m.title == "A visitor" and string.find(m.line, "Bo", 1, true) then
			return true
		end
	end
	return false
end)())
advance(1)
check("the watch leaves a visitor who was let in where he is", Wings.watch() == 0 and Wing.slotAt(rootOf(bo).Position) == Wings.slotOf(ada))

---------------------------------------------------------------------------------------------------
-- 3. Nobody where they may not be
---------------------------------------------------------------------------------------------------
standAt(cy, Wings.arrival(Wings.slotOf(ada), "suite").Position)
check("someone found in a wing that isn't theirs is taken straight home", Wings.watch() >= 1 and Wing.slotAt(rootOf(cy).Position) == Wings.slotOf(cy))
standAt(cy, Wings.arrival(Wings.slotOf(ada), "vault").Position)
Wings.watch()
check("...the Vault too", Wing.slotAt(rootOf(cy).Position) == Wings.slotOf(cy))
standAt(cy, Layout.Vault.centre + Vector3.new(0, 3, 0))
Wings.watch()
check("nobody stands in the house's own (sealed) Vault: put back outside its door", Wing.slotAt(rootOf(cy).Position) == nil and Layout.zoneAt(rootOf(cy).Position) ~= "vault")
standAt(cy, Layout.Suite.arrival + Vector3.new(0, 3, 0))
Wings.watch()
check("...nor its Suite", Layout.zoneAt(rootOf(cy).Position) ~= "suite")
-- Following someone: a ride takes only the one who asked.
standAt(cy, rootOf(ada).Position)
advance(1.1)
ask(ada, { op = "ride", to = "vault" })
advance(5.6)
check("riding with someone takes nobody along: Ada is in her Vault, Cy is not", Layout.zoneAt(rootOf(ada).Position) == "vault" and Wing.slotAt(rootOf(cy).Position) ~= Wings.slotOf(ada))
-- Asking for someone else's floors by name gets the asker's own.
advance(1.1)
r = ask(cy, { op = "ride", to = "suite", userId = 3101 })
advance(5.6)
check("asking for 'suite' with someone else's id still takes you to your own", r.ok == true and Wing.slotAt(rootOf(cy).Position) == Wings.slotOf(cy))
check("a made-up floor is refused", ask(cy, { op = "ride", to = "roof" }).ok == false)

-- The host closes up: the visitor goes home.
open[ada] = nil
Wings.watch()
check("when the host closes her Suite, her visitor is taken to his own", Wing.slotAt(rootOf(bo).Position) == Wings.slotOf(bo) and Wings.hostOf(bo) == nil)
-- Asked again at the door: closed on the way up.
open[ada] = true
advance(1.1)
ask(bo, { op = "ride", to = "friend", userId = 3101 })
advance(3)
open[ada] = nil
advance(3.6)
check("a Suite closed while a friend rides up: he arrives in his own instead", Wing.slotAt(rootOf(bo).Position) == Wings.slotOf(bo) and Wings.hostOf(bo) == nil)

-- The host leaves: her wing goes, and anyone in it is taken home first.
open[ada] = true
advance(1.1)
ask(bo, { op = "ride", to = "friend", userId = 3101 })
advance(6.6)
check("(Bo visiting Ada again)", Wings.hostOf(bo) == ada)
local adaSlot = Wings.slotOf(ada)
local adaWing = Wings.ensure(adaSlot)
H.game:GetService("Players").PlayerRemoving:Fire(ada)
advance(0.1)
check("when the host leaves, her visitor is taken home and her wing taken away", Wing.slotAt(rootOf(bo).Position) == Wings.slotOf(bo) and adaWing.Parent == nil and Wings.slotOf(ada) == nil)

---------------------------------------------------------------------------------------------------
-- 4. The Suites key goes by the elevator too
---------------------------------------------------------------------------------------------------
SuiteVisits.ride = Wings.ride
SuiteVisits.mayVisit = Wings.mayVisit
advance(1.1)
local before = events(cy, "elevator")
local sv
run(function()
	sv = SuiteVisits.handle(cy, { op = "home" })
end)
check("going home from the Suites key rides the elevator", sv.ok == true and events(cy, "elevator") == before + 1)
advance(5.6)
check("the floors offered: their own Suite and Vault, and friends' Suites with whether each is open", (function()
	local f = Wings.floors(bo)
	return type(f.friends) == "table" and f.seconds.suite == 5.5 and f.seconds.vault == 5.5 and f.seconds.friend == 6.5
end)())

H.finish()

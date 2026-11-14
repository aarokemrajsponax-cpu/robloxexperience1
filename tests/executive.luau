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
-- (The guards stand still here; each walk asked of them is noted: its speed, by guard.)
local walked = {}
Game.walk = function(a, _target, speed)
	walked[a.id] = speed
end
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
check("an invitation for Gilt, without the Gilt: its price, marked as the purse being short (the screen says Insufficient Gilt)", r.ok == false and r.why == "An invitation is 25,000 Gilt." and r.short == "Gilt", r.why)
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
standIn(ada, Vector3.new(14, 0, cam.at.Z))
steps(10)
local a1 = Game.guests[ada].alert
check("in a camera's sight, the alert rises (slower in a disguise)", a1 > 0.2 and a1 < 0.35, a1)
check("...and their screen is told a camera has them", last(ada, "executive").seen == "camera")
-- A decoy: nobody looks at anyone.
r = askAs(ada, { op = "act", id = "executive", act = "decoy" })
check("a decoy, once", r.ok == true)
local a2 = Game.guests[ada].alert
steps(20)
check("while it's out, nobody watches anyone (the alert falls)", Game.guests[ada].alert < a2)
check("...and every guard stops where it stands to watch it (never walking off into a wall)", (function()
	for i = 1, #Plan.GuardRounds do
		if walked["hall" .. i] ~= 0 then
			return false
		end
	end
	return true
end)())
r = askAs(ada, { op = "act", id = "executive", act = "decoy" })
check("...and only once a run", r.ok == false)
-- Behind a wall: unseen.
T += 20
walled = true
local a3 = Game.guests[ada].alert
steps(10)
check("out of sight, the alert falls", Game.guests[ada].alert <= a3)
walled = false
-- The lift's lobby is safe: nobody watches anyone there, even a guard looking straight in.
do
	local g1 = Game.run.hallGuards[1]
	local keep = g1.root.CFrame
	-- (Facing -Z, the lobby's way: an unturned CFrame. Lune's CFrame.lookAt turns the wrong way
	-- along Z, so it isn't used for a facing here.)
	g1.root.CFrame = CFrame.new(O + Vector3.new(0, 3, -171))
	standIn(ada, Vector3.new(0, 0, -186))
	Game.guests[ada].alert = 0
	steps(10)
	check("the lift's lobby is safe: nobody watches anyone there", Game.guests[ada].alert == 0 and Game.guests[ada].seen == nil)
	standIn(ada, Vector3.new(0, 0, -174))
	steps(5)
	check("...a step past its doorway, a guard looking that way sees them (their screen told who)", Game.guests[ada].alert > 0 and last(ada, "executive").seen == "guard")
	standIn(ada, Vector3.new(0, 0, -186))
	steps(3)
	check("...back in the lobby, out of sight (their screen told that too)", last(ada, "executive").seen == nil)
	g1.root.CFrame = keep
	-- A guard pushed off its round (a crowd of guests) is put back on it.
	local g2 = Game.run.hallGuards[2]
	g2.root.CFrame = CFrame.new(O + Vector3.new(0, 3, -131))
	steps(1)
	check("a guard pushed off its round is put back on it (never left to walk into a wall)", math.abs(g2.root.CFrame.Position.Z - (O.Z - 123)) < 0.5, g2.root.CFrame.Position.Z - O.Z)
	Game.guests[ada].alert = 0
end
-- Never read through a wall of the maze.
do
	local at = Plan.Terminals[2]
	standIn(ada, at + Vector3.new(-3, 0, 0))
	walled = true
	r = askAs(ada, { op = "act", id = "executive", act = "terminal", n = 2 })
	walled = false
	check("a terminal is never read through a wall of the maze", r.ok == false and string.find(r.why, "other side of the wall", 1, true) ~= nil, r.why)
end
-- The terminals: a digit each.
r = askAs(ada, { op = "act", id = "executive", act = "terminal", n = 1 })
check("a terminal out of reach gives nothing", r.ok == false and r.why == "Get closer to the terminal.")
local code = Game.run.code
-- Pressed from the edge of its prompt's reach (10 studs from the screen, across the hallway):
-- read, never refused for distance. (The check used to measure from the lectern's foot, a stride
-- further off, and refuse in silence.)
do
	local at = Plan.Terminals[1]
	local inward = if at.X < 0 then 1 else -1
	standIn(ada, at + Vector3.new(inward * (1.4 + 9.5), 0, 0))
	r = askAs(ada, { op = "act", id = "executive", act = "terminal", n = 1 })
	check("a terminal read from the edge of its prompt's reach", r.ok == true, r.why)
	-- And a refusal through the prompt itself is said on the guest's screen.
	standIn(ada, Vector3.new(0, 0, Plan.Door.z - 4))
	local promptOf
	for _, d in workspace:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "Terminal" and d.Parent and d.Parent:GetAttribute("Terminal") == 2 then
			promptOf = d
		end
	end
	local before = #ada.inbox
	if promptOf then
		promptOf.Triggered:Fire(ada)
	end
	local said
	for i = before + 1, #ada.inbox do
		if ada.inbox[i].op == "notice" then
			said = ada.inbox[i]
		end
	end
	check("a press that's refused says why on the guest's screen (never a silent E)", said ~= nil and said.line == "Get closer to the terminal.", said and said.line)
	check("the terminals answer a short hold (0.8 s) from 10 studs", promptOf ~= nil and math.abs(promptOf.HoldDuration - 0.8) < 1e-3 and promptOf.MaxActivationDistance == 10)
end
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
-- 2b. The maze (Build 81): built as planned, every way through open, every guard's round clear
---------------------------------------------------------------------------------------------------
do
	local b = Game.built()
	local hall = Plan.Hall
	-- Every partition, solid, taller than any eye up here, and among what blocks sight.
	local built, tall = 0, true
	local sightModel = b.sight[1]
	for _, d in sightModel:GetDescendants() do
		if d:GetAttribute("Partition") then
			built += 1
			if d.Size.Y < 12 or d.CanCollide == false or d.CanQuery == false then
				tall = false
			end
		end
	end
	check("the maze: every partition built, solid, taller than any eye, and blocking sight", built == #Plan.Partitions and tall, built)
	check("...the door blocks sight too, and the lobby holds the lift's arrival", table.find(b.sight, b.door) ~= nil and Plan.inLobby(Plan.Arrival) and not Plan.inLobby(Vector3.new(0, 0, -170)))
	-- Walking it: a grid over the floor, a guest's width from every wall (and the lecterns).
	local R, S = 1.2, 0.5
	local boxes = {}
	for _, pb in Plan.Partitions do
		table.insert(boxes, pb)
	end
	for _, t in Plan.Terminals do
		local x = t.X + (if t.X < 0 then 1.2 else -1.2)
		table.insert(boxes, { x - 0.7, t.Z - 0.7, x + 0.7, t.Z + 0.7 })
	end
	local function free(x, z, r)
		if x < hall.minX + r or x > hall.maxX - r or z < hall.minZ + r or z > hall.maxZ - r then
			return false
		end
		for _, q in boxes do
			local dx = math.max(q[1] - x, 0, x - q[3])
			local dz = math.max(q[2] - z, 0, z - q[4])
			if math.sqrt(dx * dx + dz * dz) <= r then
				return false
			end
		end
		return true
	end
	local function key(i, j)
		return i * 100000 + j
	end
	local si, sj = math.floor(Plan.Arrival.X / S + 0.5), math.floor(Plan.Arrival.Z / S + 0.5)
	local seen, queue, head = { [key(si, sj)] = true }, { { si, sj } }, 1
	while head <= #queue do
		local c = queue[head]
		head += 1
		for _, dd in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local ni, nj = c[1] + dd[1], c[2] + dd[2]
			local k = key(ni, nj)
			if not seen[k] and free(ni * S, nj * S, R) then
				seen[k] = true
				table.insert(queue, { ni, nj })
			end
		end
	end
	local function reach(x, z)
		return seen[key(math.floor(x / S + 0.5), math.floor(z / S + 0.5))] == true
	end
	local allTerminals = true
	for _, t in Plan.Terminals do
		if not reach(t.X + (if t.X < 0 then 3.5 else -3.5), t.Z) then
			allTerminals = false
		end
	end
	check("from the lift, every terminal can be walked to", allTerminals)
	check("...and the keypad and the vault door", reach(Plan.Door.maxX + 1.6, Plan.Door.z - 4) and reach(0, Plan.Door.z - 2.5))
	check("...and not through a wall (the grid finds walls: inside one is never reached)", not reach(0, -161) and not reach(-10, -106))
	-- Every guard's round: straight lines through the open lanes, nothing in the way.
	local roundsClear = true
	for gi, pts in Plan.GuardRounds do
		for k = 1, #pts do
			local a, z = pts[k], pts[k % #pts + 1]
			for step = 0, 100 do
				local q = a:Lerp(z, step / 100)
				if not free(q.X, q.Z, 1.5) then
					roundsClear = false
					print("  guard " .. gi .. " blocked at", q)
					break
				end
			end
		end
	end
	check("every guard's round runs clear of every wall", roundsClear)
	-- Every camera on a side wall, none inside the maze's walls; every terminal against a side wall.
	local camsOk = true
	for _, c in Plan.Cameras do
		if math.abs(math.abs(c.at.X) - hall.maxX) > 1 or Plan.inPartition(c.at) then
			camsOk = false
		end
	end
	check("every camera hangs on a side wall, clear of the maze's walls", camsOk and #b.cameras == #Plan.Cameras)
	-- Nothing solid from the dressing stands in a lane: only what hugs a wall.
	local inWay = {}
	local dressing = b.root:FindFirstChild("Dressing")
	for _, d in (dressing and dressing:GetDescendants() or {}) do
		local okPos, pos = pcall(function()
			return d.CFrame.Position
		end)
		if d:IsA("BasePart") and d.CanCollide ~= false and okPos then
			local p, size = pos - O, d.Size
			if p.Y < 7 and p.X > hall.minX and p.X < hall.maxX and p.Z > hall.minZ and p.Z < Plan.Door.z then
				local half = math.max(size.X, size.Z) / 2
				-- (Against a side wall, the end wall, the door's wall, or a partition.)
				local hugs = math.abs(p.X - hall.minX) <= size.X / 2 + 0.8
					or math.abs(p.X - hall.maxX) <= size.X / 2 + 0.8
					or math.abs(p.Z - hall.minZ) <= size.Z / 2 + 0.8
					or math.abs(p.Z - (Plan.Door.z - 0.5)) <= size.Z / 2 + 0.8
					or Plan.inPartition(p, half + 0.3)
				if not hugs then
					table.insert(inWay, d.Name)
				end
			end
		end
	end
	check("nothing solid stands in a lane: decoration only hugs the walls", #inWay == 0, table.concat(inWay, ", "))
end

---------------------------------------------------------------------------------------------------
-- 2c. The sight every screen draws: the server's own rule, and the floor's triangles
---------------------------------------------------------------------------------------------------
do
	local eye, look = Vector3.new(0, 4, 0), Vector3.new(0, 0, -1)
	check("in sight: within its range and its angle", Plan.inSight(eye, look, 26, 55, Vector3.new(5, 0, -20)) == true)
	check("...not past its angle, nor past its range", Plan.inSight(eye, look, 26, 55, Vector3.new(20, 0, -5)) == false and Plan.inSight(eye, look, 26, 55, Vector3.new(0, 0, -30)) == false)
	local fan = Plan.sightFan(look, 26, 55, 7, function()
		return 100
	end)
	local edge = math.deg(math.acos(math.clamp(fan[1].Unit:Dot(look), -1, 1)))
	check("the fan: one point a ray, out to its range, its edges at its angle", #fan == 7 and math.abs(fan[1].Magnitude - 26) < 1e-6 and math.abs(edge - 55) < 1e-3 and fan[4].Unit:Dot(look) > 0.999, edge)
	local short = Plan.sightFan(look, 26, 55, 7, function()
		return 9
	end)
	check("...each ray stopped at the first wall", math.abs(short[4].Magnitude - 9) < 1e-6)
	local a, b2, c = Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(3, 0, -6)
	local cf1, s1, cf2, s2 = Plan.wedges(a, b2, c, 0.05)
	local area = 0.5 * s1.Y * s1.Z + 0.5 * s2.Y * s2.Z
	local function corners(cf, s)
		return {
			cf:PointToWorldSpace(Vector3.new(0, -s.Y / 2, -s.Z / 2)),
			cf:PointToWorldSpace(Vector3.new(0, -s.Y / 2, s.Z / 2)),
			cf:PointToWorldSpace(Vector3.new(0, s.Y / 2, s.Z / 2)),
		}
	end
	local function foot(p, q, r)
		local u = (r - q).Unit
		return q + u * (p - q):Dot(u)
	end
	local known = { a, b2, c, foot(a, b2, c), foot(b2, a, c), foot(c, a, b2) }
	local onTriangle = true
	for _, w in { corners(cf1, s1), corners(cf2, s2) } do
		for _, q in w do
			local near = false
			for _, k in known do
				if (q - k).Magnitude < 1e-4 then
					near = true
				end
			end
			onTriangle = onTriangle and near
		end
	end
	check("a triangle on the floor, drawn as two wedges, covers exactly it", math.abs(area - 30) < 1e-6 and onTriangle, area)
	check("...and one with no area isn't drawn", Plan.wedges(a, b2, Vector3.new(20, 0, 0), 0.05) == nil)
end

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
-- His briefcases. (Build 78: every attack is wound up first, where everyone can see it, and said
-- plainly while it lasts; then it comes.)
local function unleash()
	T = Game.run.nextAttack + 0.01
	steps(1)
	local p = Game.run.pending
	if p then
		T = p.fireAt + 0.01
		steps(1)
	end
end
composure = Game.guests[ada].composure
T = Game.run.nextAttack + 0.01
steps(1)
local wound = last(ada, "windup")
check("his briefcases are wound up first: every screen is told what's coming, and for how long", wound ~= nil and wound.kind == "volley" and math.abs(wound.seconds - C.windup) < 1e-6 and wound.line == Plan.Windups.volley and last(ada, "throw") == nil)
T = Game.run.pending.fireAt + 0.01
steps(1)
local thrown = last(ada, "throw")
check("he throws briefcases when it's up (every screen is told where, and when)", thrown ~= nil and thrown.speed > 0)
local s = Game.run.shots[#Game.run.shots]
T = s.born + 0.3
local p1 = s.from + s.dir * s.speed * 0.3
standIn(ada, Vector3.new(p1.X, 0, p1.Z))
steps(1)
check("a briefcase that reaches you takes composure, once", Game.guests[ada].composure == composure - C.briefcase)
steps(2)
check("...only once", Game.guests[ada].composure == composure - C.briefcase)
-- The shockwave: jump it.
unleash()
local w = Game.run.waves[#Game.run.waves]
check("his shockwave, wound up first where it will start (every screen is told)", w ~= nil and last(ada, "wave") ~= nil and last(ada, "windup").kind == "wave" and (last(ada, "windup").at - (O + w.at)).Magnitude < 1e-3)
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
T = Game.run.pending.fireAt + 0.01
steps(1)
w2 = Game.run.waves[#Game.run.waves]
T = w2.born + 0.5
standIn(ada, w2.at + Vector3.new(w2.speed * 0.5, 0, 0))
steps(1)
check("on the ground as it passes: it takes composure", Game.guests[ada].composure == composure - C.shockwave)
-- His dash: the lane shown first; still in it when he comes, it takes composure; out of it, nothing.
local function dashLane()
	Game.run.attackIndex = 2 -- (the next is his dash)
	Game.run.nextAttack = T
	T += 0.01
	steps(1)
	local p = Game.run.pending
	return p, last(ada, "windup")
end
local lane, said = dashLane()
check("his dash is wound up first: the lane it will take, from where he stands to where he's going", lane ~= nil and lane.kind == "dash" and said.kind == "dash" and said.to ~= nil and (said.to - (O + lane.to)).Magnitude < 1e-3)
composure = Game.guests[ada].composure
local mid = (lane.from + lane.to) / 2
standIn(ada, Vector3.new(mid.X, 0, mid.Z))
T = lane.fireAt + 0.01
steps(1)
check("still in its lane when he comes: it takes composure", Game.guests[ada].composure == composure - C.dash and last(ada, "hurt").why == "dash")
lane = dashLane()
local side = (lane.to - lane.from)
local across = Vector3.new(-side.Z, 0, side.X).Unit
local mid2 = (lane.from + lane.to) / 2 + across * 8
composure = Game.guests[ada].composure
standIn(ada, Vector3.new(mid2.X, 0, mid2.Z))
T = lane.fireAt + 0.01
steps(1)
check("stepped out of the lane: nothing", Game.guests[ada].composure == composure)
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
T = Game.run.pending.fireAt + 0.01
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
-- His finale: at the last of his composure, said on every screen; quicker wind-ups; two rings.
local boss = Game.run.actors.boss
standIn(ada, Vector3.new(-10, 0, 10))
while boss.hp > boss.max * C.finaleAt do
	shoot(ada, "boss")
end
Game.run.pending = nil
T += 0.01
steps(1)
local fin = last(ada, "finale")
check("at the last of his composure, his finale: said on every screen", fin ~= nil and fin.say == Plan.FINALE_SAY and Game.run.finale == true and last(ada, "executive").finale == true)
Game.run.attackIndex = 1 -- (the next is the shockwave)
Game.run.nextAttack = T
Game.run.waves = {}
T += 0.01
steps(1)
check("...his wind-ups quicker", Game.run.pending ~= nil and math.abs(last(ada, "windup").seconds - C.windupFinale) < 1e-6 and last(ada, "windup").finale == true)
T = Game.run.pending.fireAt + 0.01
steps(1)
check("...and two rings at a time", #Game.run.waves == 2 and Game.run.waves[2].born > Game.run.waves[1].born)
Game.run.waves = {}
-- He falls.
local estateWas = Fortune.page(data(ada)).estate
local gemsWas, giltWas = data(ada).gems, data(ada).gilt
standIn(ada, Vector3.new(-10, 0, 10))
while Game.run.actors.boss.hp > 0 do
	shoot(ada, "boss")
end
local won = last(ada, "won")
check("the Executive beaten: everyone in the Office is paid", Game.run.phase == "won" and won ~= nil and Fortune.page(data(ada)).estate == estateWas + C.prize)
check("...the prize's Gilt, in full (once an invitation: outside the day's soft cap)", won.gilt == C.prizeGilt and data(ada).gilt >= giltWas + C.prizeGilt, won.gilt)
check("...and never a Gem: those come only from Robux", won.gems == nil and data(ada).gems == gemsWas)
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
local ex = last(ada, "extract")
check("beaten: the extraction's minute, said to everyone in the Office (with its bonus)", ex ~= nil and ex.seconds == C.extractSeconds and ex.gilt == C.extractGilt and math.abs(Game.run.extractUntil - (Game.run.wonAt + C.extractSeconds)) < 1e-6 and last(ada, "executive").extractUntil ~= nil)
advance(3)
local giltBefore = data(ada).gilt
Game.built().liftDown.Triggered:Fire(ada)
local away = last(ada, "extracted")
check("the lift down within the minute: a clean getaway's bonus", away ~= nil and away.gilt > 0 and data(ada).gilt - giltBefore == away.gilt)
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
check("...with no revive held and none on sale, at once (no moment offered)", last(ada, "alarm").revive == false and last(ada, "caught") == nil)

---------------------------------------------------------------------------------------------------
-- 5. Chronos Defiance in the Suite: caught, a revive keeps the run going
---------------------------------------------------------------------------------------------------
local rv = { held = 0, onSale = true, price = 89, spent = 0, offered = 0, offerOk = true, context = nil }
Game.revives.held = function()
	return rv.held
end
Game.revives.onSale = function()
	return rv.onSale
end
Game.revives.price = function()
	return rv.price
end
Game.revives.spend = function()
	if rv.held > 0 then
		rv.held -= 1
		rv.spent += 1
		return true
	end
	return false
end
Game.revives.offer = function(_p, context)
	rv.offered += 1
	rv.context = context
	return rv.offerOk, if rv.offerOk then nil else "The purchase window couldn't open."
end
local function caughtAt()
	T = 9000 - cam.phase * cam.period
	standIn(ada, Vector3.new(0, 0, cam.at.Z))
	steps(30)
end
page(ada).invites = 1
stand(ada, Layout.Midnight.arrival)
advance(3)
r = askAs(ada, { op = "go", id = "executive" })
check("(up again)", r.ok == true)
Game.guests[ada].digits[1] = true
Game.guests[ada].digits[2] = true
caughtAt()
local moment = last(ada, "caught")
check("caught, with Chronos Defiance on sale: the moment for a revive, still in the Suite", Attractions.inside(ada) == "executive" and Game.guests[ada].out == true and moment ~= nil and last(ada, "alarm").revive == true)
check("...its price shown, nothing held, where it puts you back, and how long it stands", moment.price == 89 and moment.onSale == true and moment.held == 0 and moment.where == "hall" and math.abs(moment.left - Game.REVIVE.window) < 0.01 and moment.usesLeft == Game.REVIVE.most)
r = askAs(ada, { op = "act", id = "executive", act = "terminal", n = 3 })
check("while caught, nothing else in the Suite works", r.ok == false and r.why == "You were caught: security is showing you out.")
r = askAs(ada, { op = "act", id = "executive", act = "revive" })
local upd = last(ada, "caughtUpdate")
check("revive with none held: Roblox's purchase window, for the Suite", r.ok == true and r.prompting == true and rv.offered == 1 and rv.context == "executive" and upd ~= nil and upd.prompting == true)
check("...and the moment waits while it's open", Game.guests[ada].revive.deadline == T + Game.REVIVE.promptWait)
r = askAs(ada, { op = "act", id = "executive", act = "revive" })
check("...one window at a time", r.ok == false and rv.offered == 1)
Game.reviveClosed(ada, true)
check("bought: the moment waits for Roblox's receipt", Game.guests[ada].revive.prompting == false and Game.guests[ada].revive.deadline == T + Game.REVIVE.receiptWait and last(ada, "caughtUpdate").prompting == false)
rv.held = 1 -- (the receipt's credit)
check("the receipt revives the run (Purchases/Revive asks the Suite)", Game.reviveOpen(ada) == true and Game.reviveNow(ada) == true and rv.spent == 1 and rv.held == 0)
local back = last(ada, "revived")
check("...back at the lift, the alert down, composure full, the digits read kept", back ~= nil and back.where == "hall" and Game.guests[ada].out == false and Game.guests[ada].alert == 0 and Game.guests[ada].composure == Game.guests[ada].max and Game.guests[ada].digits[1] == true and Game.guests[ada].digits[2] == true and (ada.root.CFrame.Position - (O + Plan.Arrival + Vector3.new(0, 3, 0))).Magnitude < 0.01)
check("...and one credit revives once", Game.reviveOpen(ada) == false and Game.reviveNow(ada) == false and rv.spent == 1)
-- Caught again, a revive held: used at once, with no purchase.
rv.held = 2
caughtAt()
r = askAs(ada, { op = "act", id = "executive", act = "revive" })
check("caught again with revives held: one used at once, no purchase window", r.ok == true and rv.held == 1 and rv.offered == 1 and Game.guests[ada].out == false and Game.guests[ada].revives == 2)
-- A purchase window that couldn't open: said, and the moment stands.
rv.held = 0
rv.offerOk = false
caughtAt()
r = askAs(ada, { op = "act", id = "executive", act = "revive" })
check("a purchase window that couldn't open: said, and the moment still stands", r.ok == false and r.why == "The purchase window couldn't open." and Game.guests[ada].revive ~= nil and Game.guests[ada].revive.prompting == false)
rv.offerOk = true
-- The moment passes: shown out.
T += Game.REVIVE.window + 1
steps(1)
check("the moment passes: security shows them out", Attractions.inside(ada) == nil and last(ada, "caughtEnd") ~= nil)
-- Leave, at once.
page(ada).invites = 1
stand(ada, Layout.Midnight.arrival)
advance(3)
r = askAs(ada, { op = "go", id = "executive" })
caughtAt()
r = askAs(ada, { op = "act", id = "executive", act = "leaveCaught" })
check("Leave in the moment: home at once", r.ok == true and Attractions.inside(ada) == nil)
r = askAs(ada, { op = "act", id = "executive", act = "revive" })
check("...and no revive to take once home", r.ok == false)
-- The most one run takes.
page(ada).invites = 1
stand(ada, Layout.Midnight.arrival)
advance(3)
r = askAs(ada, { op = "go", id = "executive" })
Game.guests[ada].revives = Game.REVIVE.most
rv.held = 1
caughtAt()
check("a run that's used its last revive: shown out at once", Attractions.inside(ada) == nil and last(ada, "alarm").revive == false and rv.held == 1)
-- In the Office: back just inside its door, untouchable for a moment.
page(ada).invites = 1
stand(ada, Layout.Midnight.arrival)
advance(3)
r = askAs(ada, { op = "go", id = "executive" })
local gA = Game.guests[ada]
gA.out = true
gA.composure = 0
gA.revive = { where = "office", deadline = T + 10, prompting = false, left = 10 }
check("a revive in the Office: back just inside its door", Game.reviveNow(ada) == true and (ada.root.CFrame.Position - (O + Plan.OfficeEntry + Vector3.new(0, 3, 0))).Magnitude < 0.01 and gA.composure == gA.max and gA.safeUntil == T + 3)
r = askAs(ada, { op = "home" })
Game.revives.held = function()
	return 0
end
Game.revives.onSale = function()
	return false
end

-- Security's armour (on the staff rig's figure): helmet and visor, a plate carrier marked SECURITY,
-- pads, a belt and a radio, all welded on and walked through, and nothing that shoots.
do
	local Instance = H.Instance
	local fig = Instance.new("Model")
	for _, spec in {
		{ "Head", Vector3.new(1.2, 1.2, 1.2) }, { "UpperTorso", Vector3.new(2, 1.6, 1) }, { "LowerTorso", Vector3.new(2, 0.4, 1) },
		{ "LeftUpperArm", Vector3.new(1, 1.2, 1) }, { "RightUpperArm", Vector3.new(1, 1.2, 1) },
		{ "LeftLowerLeg", Vector3.new(1, 1.2, 1) }, { "RightLowerLeg", Vector3.new(1, 1.2, 1) },
	} do
		local p = Instance.new("Part")
		p.Name = spec[1]
		p.Size = spec[2]
		p.Parent = fig
	end
	local tie = Instance.new("Part")
	tie.Name = "Tie"
	tie.Parent = fig
	Game.armour(fig)
	local want = { "Helmet", "Visor", "Vest", "Plate", "Radio", "Belt", "LeftShoulder", "RightShoulder", "LeftKnee", "RightKnee" }
	local all = true
	for _, n in want do
		local p = fig:FindFirstChild(n)
		all = all and p ~= nil and p.CanCollide == false and p.CanQuery == false and p.Massless == true and p:FindFirstChildOfClass("WeldConstraint") ~= nil
	end
	check("security in armour: helmet, visor, plate carrier, pads, belt and radio, welded on and walked through", all)
	local vest = fig:FindFirstChild("Vest")
	local marked = vest and vest:FindFirstChild("MarkFront") and vest:FindFirstChild("MarkBack")
	check("...SECURITY across the chest and the back", marked ~= nil and vest.MarkFront:FindFirstChildOfClass("TextLabel").Text == "SECURITY")
	local armed = false
	for _, d in fig:GetDescendants() do
		if d:IsA("Tool") or string.find(string.lower(d.Name), "gun", 1, true) or string.find(string.lower(d.Name), "rifle", 1, true) then
			armed = true
		end
	end
	check("...and nothing that shoots: no weapon of any kind", not armed)
	check("...the butler's tie is gone", fig:FindFirstChild("Tie") == nil)
end

H.finish()

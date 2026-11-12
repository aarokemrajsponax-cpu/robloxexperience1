--!nocheck
-- Steal a Luxe on the server (server/Attractions, Attractions/Luxe, World/Lobbies), under Lune on a
-- fake clock, in the house's test harness: the Luxe Lounge in the Velvet Room (its entrance, its
-- treadmills, its board), going in only from there, a way through the residence that can be walked,
-- taking a piece (only within reach, only with room in the bag), the weight of the bag, the guards
-- (seeing, chasing, giving up, catching: the bag lost), banking at the car (the Estate, the cash
-- share, the brainrots, never a Gem), the upgrades (their real prices, never the screen's),
-- Stride from the treadmills, and every way out letting go of the guest. Build 78: six wings (the
-- Drop Room with its loft and roof, the Garage, the Secret Stash), lifts that take their hold, the
-- van and the helicopter, the cameras, the alarm and its lockdown, the laser grid, the side jobs,
-- the Limited pieces, and each plinth's own five minutes (kept with the guest's ledger).
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
-- (The house's calendar, as the tests say: no holiday open unless a test opens one.)
local HolidayGames = module("ReplicatedStorage", "Shared", "HolidayGames")
local holidayOpen = nil
HolidayGames.byCalendar = function()
	return holidayOpen
end
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
-- (The cameras look away until their own tests: a guest stood still for a test isn't seen by one.)
local camsKept = table.clone(Luxe.cams)
table.clear(Luxe.cams)
local function calm()
	for _, a in Luxe.alarms do
		a.level, a.untilAt = 0, 0
	end
end
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
-- Stood within reach long enough to lift what's on plinth `s`: its hold, as every screen works it out.
local function holdOn(g, s)
	if s.piece then
		local d = (g.root.CFrame.Position - s.top.CFrame.Position).Magnitude
		local need = Plan.holdFor(s.piece, d, C.hands[page(g).hands] or 1, C.hold)
		steps(math.ceil(need * 10) + 1)
	end
end

---------------------------------------------------------------------------------------------------
-- 1. The plan
---------------------------------------------------------------------------------------------------
check("six wings: the house's three each sharper than the last, and the three beyond them too", #Plan.Wings == 6 and Plan.Wings[1].sharp < Plan.Wings[2].sharp and Plan.Wings[2].sharp < Plan.Wings[3].sharp and Plan.Wings[4].sharp < Plan.Wings[5].sharp and Plan.Wings[5].sharp < Plan.Wings[6].sharp)
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
	local worth = { 0, 0, 0, 0, 0, 0 }
	local n = { 0, 0, 0, 0, 0, 0 }
	for _, p in Plan.Pieces do
		if p.weight > 0 then
			worth[p.wing] += p.worth
			n[p.wing] += 1
		end
	end
	check("the deeper the wing, the more its pieces are worth (and the Secret Stash's the most)", worth[1] / n[1] < worth[2] / n[2] and worth[2] / n[2] < worth[3] / n[3] and worth[4] / n[4] < worth[5] / n[5] and worth[5] / n[5] < worth[6] / n[6] and worth[6] / n[6] > worth[3] / n[3])
	local labels = true
	for _, r in Plan.Rarities do
		if r.label ~= (r.order >= 3) then
			labels = false
		end
	end
	check("seven grades, Common to Limited: Rare and up wear a label", #Plan.Rarities == 7 and Plan.Rarities[7].id == "Limited" and labels)
	local limitedOk, limitedCount = true, 0
	for _, p in Plan.Pieces do
		if p.rarity == "Limited" then
			limitedCount += 1
			if p.weight ~= 0 or p.limited == nil or HolidayGames.byId[p.limited] == nil then
				limitedOk = false
			end
		elseif p.limited ~= nil then
			limitedOk = false
		end
	end
	check("every Limited piece belongs to a real holiday, and is never set out by chance", limitedOk and limitedCount == 5, limitedCount)
	local sized = true
	for _, p in Plan.Pieces do
		if C.hold.size[p.size or ""] == nil or type(p.mass) ~= "number" then
			sized = false
		end
	end
	check("every piece has a size (how long it takes to lift) and a weight", sized)
	local tiny = Plan.holdFor(Plan.byId.shades, 0, 1, C.hold)
	local huge = Plan.holdFor(Plan.byId.bullion, 0, 1, C.hold)
	local far = Plan.holdFor(Plan.byId.shades, C.reach, 1, C.hold)
	local quick = Plan.holdFor(Plan.byId.bullion, 0, C.hands[#C.hands], C.hold)
	check("a lift takes longer the bigger, rarer and dearer the piece, and the further the reach", tiny < huge and far > tiny and tiny >= C.hold.least and huge <= C.hold.most, tiny, huge, far)
	check("Quick Hands shortens it", quick < huge)
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
	check("the garage van is a way out, in the Garage", Plan.bankAt(Vector3.new(110, 3, -50)).id == "van" and Plan.wingAt(Vector3.new(110, 3, -50)) == 5)
	check("the helicopter is a way out, up on the Drop Room's roof (not the floor below it)", Plan.bankAt(Vector3.new(-98, Plan.ROOF + 3, -26)).id == "heli" and Plan.bankAt(Vector3.new(-98, 3, -26)) == nil and Plan.bankAt(Vector3.new(-98, Plan.LOFT + 3, -26)) == nil)
	local camsIn = true
	for _, cam in Plan.Cameras do
		if Plan.wingAt(cam.at) ~= cam.wing then
			camsIn = false
		end
	end
	check("every wing has a camera, each hung in its own wing", camsIn and #Plan.Cameras >= #Plan.Wings)
	local goalsOk = true
	for _, o in Plan.Objectives do
		if Plan.objectiveOf[o.id] ~= o or o.gilt <= 0 then
			goalsOk = false
		end
	end
	check("ten side jobs, each paying its Gilt", #Plan.Objectives == 10 and goalsOk)
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
	check("every plinth has a piece on it when the house opens (" .. #Plan.Spots .. ")", full == #Plan.Spots, full)
	check("the Crown Jewel is on its plinth", Luxe.spots[21].piece and Luxe.spots[21].piece.id == "crownJewel")
	check("a guard for every round walks the residence", #Luxe.guards == #Plan.Patrols and #Plan.Patrols == 12, #Luxe.guards)
	local torches = 0
	for _, g in Luxe.guards do
		if g.model:FindFirstChild("Torch", true) then
			torches += 1
		end
	end
	check("every guard carries a torch (where he looks, everyone can see)", torches == #Plan.Patrols, torches)
	local take = Luxe.spots[1].model:FindFirstChild("Take", true)
	check("a piece can be taken with a prompt", take ~= nil and take:IsA("ProximityPrompt"))
	local holds, labelsOk = true, true
	for _, sp in Luxe.spots do
		local pr = sp.model and sp.model:FindFirstChild("Take", true)
		if not pr or math.abs(pr.HoldDuration - Plan.holdFor(sp.piece, 0, 1, C.hold)) > 1e-3 or pr:GetAttribute("Piece") ~= sp.piece.id then
			holds = false
		end
		local grade = sp.model and sp.model:FindFirstChild("Grade", true)
		local wants = Plan.rarityOf[sp.piece.rarity].label
		if wants ~= (grade ~= nil) or (grade and grade.Chip.Text ~= "<" .. string.upper(sp.piece.rarity) .. ">") then
			labelsOk = false
		end
	end
	check("each piece's prompt holds for its own lift (up close: the screen adds the reach)", holds)
	check("Rare and up wear their grade over them, <RARE> to <EXCLUSIVE>; the rest don't", labelsOk and Luxe.spots[21].model:FindFirstChild("Grade", true).Chip.Text == "<EXCLUSIVE>")
	local res = workspace.Attractions.StealALuxe
	local heads = 0
	for _, cam in camsKept do
		if cam.head and cam.head:FindFirstChild("View") then
			heads += 1
		end
	end
	check("a camera for every camera in the plan, each with a head that turns and a light where it looks", #camsKept == #Plan.Cameras and heads == #Plan.Cameras, heads)
	local beams = 0
	for _, d in res:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Laser" then
			beams += 1
			if d.CanCollide or d.CanQuery then
				beams = -99
			end
		end
	end
	check("the Strongroom's laser grid is built (light only: nothing to bump into or hide behind)", beams == #Plan.Lasers, beams)
	local door = res:FindFirstChild("StashDoor", true)
	local lever = res:FindFirstChild("PullBar", true)
	check("the Secret Stash's panel is shut, and a loose gold bar waits on the last stack on the right", door ~= nil and door.CanCollide and lever ~= nil and lever:IsA("ProximityPrompt"))
	local van = res:FindFirstChild("GarageVan", true)
	local heli = res:FindFirstChild("Helicopter", true)
	check("the van waits in the Garage, the helicopter on the roof", van ~= nil and heli ~= nil and heli:FindFirstChild("Cabin").CFrame.Position.Y > O.Y + Plan.ROOF)
	local stairs, top = 0, 0
	for _, d in res.Architecture.DropRoom:GetChildren() do
		if d.Name == "Stair" then
			stairs += 1
			top = math.max(top, d.CFrame.Position.Y + d.Size.Y / 2 - O.Y)
		end
	end
	check("stairs a stud a step: up to the loft, and on up to the roof", stairs == Plan.ROOF and math.abs(top - Plan.ROOF) < 1e-3, stairs, top)
	local hatch = O + Vector3.new(-120, Plan.ROOF - 0.5, -40)
	local covered = false
	for _, d in res.Architecture.DropRoom:GetChildren() do
		if d.Name == "Roof" then
			local rel = d.CFrame:PointToObjectSpace(hatch)
			if math.abs(rel.X) < d.Size.X / 2 and math.abs(rel.Y) < d.Size.Y / 2 and math.abs(rel.Z) < d.Size.Z / 2 then
				covered = true
			end
		end
	end
	check("and a hatch in the roof over the top flight (nobody bumps their head)", not covered)
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
	local drop = walk({ Vector3.new(-40, 0, -26), Vector3.new(-92, 0, -26) })
	check("the Garden Hall's west door leads into the Drop Room", drop == nil, drop)
	local garage = walk({ Vector3.new(40, 0, -26), Vector3.new(96, 0, -26), Vector3.new(96, 0, -40), Vector3.new(105, 0, -45) })
	check("its east door into the Garage, and on to the van", garage == nil and Plan.bankAt(Vector3.new(105, 3, -45)).id == "van", garage)
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
	standIn(g, Vector3.new(top.X, s.spot.at.Y, top.Z - 4))
	holdOn(g, s)
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
check("its plinth says when it's back (five minutes, its own timer), for every screen's countdown", math.abs(s1.top:GetAttribute("BackAt") - (workspace:GetServerTimeNow() + C.respawn)) < 1, s1.top:GetAttribute("BackAt"))
check("the guest is told what they took and its worth", last(ava, "took") ~= nil and last(ava, "took").worth == first.worth)
local slowed = ava:GetAttribute("SpeedTrained")
local function slowFor(bag)
	local mass = 0
	for _, p in bag do
		mass += p.mass or 0
	end
	return math.max(C.slowest, 1 - #bag * C.weight - mass * C.massSlow)
end
check("a piece in the bag slows them a little (and more the heavier it is)", type(slowed) == "number" and math.abs(slowed - slowFor(Luxe.runs[ava].bag)) < 1e-3, slowed)
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
check("three pieces: slower again, but never below the slowest", math.abs(ava:GetAttribute("SpeedTrained") - slowFor(Luxe.runs[ava].bag)) < 1e-3)
steps(C.respawn * 10 - 50)
check("a lifted piece isn't back before its five minutes", s1.piece == nil)
steps(60)
check("then the same piece is back on its own plinth", s1.piece == first and s1.model ~= nil and s1.top:GetAttribute("BackAt") == nil)

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
-- Far off: unseen; nearer with ordinary shoes, seen; with the quietest shoes, unseen again. (The
-- wing calm again first: on Alert its guards see further.)
calm()
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
calm()
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
steps(C.dropBack * 10)
check("the plinth they emptied is filled again in a few seconds (not the five-minute wait)", s5.piece ~= nil and s5.model ~= nil)
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
-- 7. The rarest pieces: the brainrots, never a Gem, the Crown Jewel
---------------------------------------------------------------------------------------------------
parkGuards(nil)
local spotC = Luxe.spots[21]
local function bankOne(g, s, piece)
	-- (A piece put on a plinth for the test, as the residence would; the house quiet.)
	parkGuards(nil)
	calm()
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
	standIn(g, Vector3.new(top.X, s.spot.at.Y, top.Z - 4))
	holdOn(g, s)
	local res = askAs(g, { op = "act", id = "luxe", act = "take", n = s.spot.id })
	standIn(g, Vector3.new(0, 0, -108))
	steps(2)
	return res, last(g, "banked")
end
local gemsWas = data(ava).gems
local res, b2 = bankOne(ava, spotC, nil)
check("the Crown Jewel can be taken and banked", res.ok == true and b2 ~= nil and b2.worth == Plan.byId.crownJewel.worth and b2.pieces[1].id == "crownJewel", res.why)
check("it pays its worth, and never a Gem (those come only from Robux)", b2.gems == nil and data(ava).gems == gemsWas, b2.gems)
check("and earns its achievement", #awards > 0 and awards[#awards].key == "crownJewel")
steps(80)
local feat = nil
for _, bc in broadcasts do
	if bc.remote == "Empire" and bc.message.op == "feat" and bc.message.title == "The Crown Jewel" then
		feat = bc.message
	end
end
check("the house is told (a real feat, by a real guest)", feat ~= nil and feat.worth == b2.worth)
steps(C.respawn * 10 - 80 - 50)
check("the Crown Jewel isn't back before its five minutes", spotC.piece == nil)
steps(70)
check("then it's back on its own plinth", spotC.piece ~= nil and spotC.piece.id == "crownJewel")
local res2, b3 = bankOne(ava, Luxe.spots[9], Plan.byId.ladro)
check("a brainrot piece banked is the guest's to keep as a brainrot", res2.ok == true and b3 ~= nil and b3.brainrots[1] == "ladroLussuoso" and (data(ava).curios.items.ladroLussuoso or 0) == 1, res2.why)
-- Gems: never, however rare the piece or however many are banked.
local gemsNow = data(ava).gems
local anyGem = false
for _, id in { 17, 18, 11, 12, 13, 14 } do
	local _, b = bankOne(ava, Luxe.spots[id], Plan.byId.tiara)
	anyGem = anyGem or b == nil or b.gems ~= nil
end
check("no haul in Steal a Luxe pays a Gem, however rare", not anyGem and data(ava).gems == gemsNow)
check("...and no piece says it would", (function()
	for _, p in Plan.Pieces do
		if (p :: any).gems ~= nil then
			return false
		end
	end
	return true
end)())

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
-- 8b. Build 78: lifts that take their hold, the side jobs, the van and the helicopter, the cameras,
-- the alarm and its lockdown, the laser grid, the Secret Stash, Limited pieces, the five minutes
---------------------------------------------------------------------------------------------------
local LuxeBuild = module("ServerScriptService", "Server", "Attractions", "LuxeBuild")
local function setPiece(s, piece)
	if s.model then
		s.model:Destroy()
	end
	s.piece = piece
	s.back = 0
	s.model = LuxeBuild.piece(workspace.Attractions.StealALuxe.Pieces, s.top, piece, s.spot.id)
end
local function beside(g, s)
	local top = s.top.CFrame.Position - O
	standIn(g, Vector3.new(top.X, s.spot.at.Y, top.Z - 4))
end
parkGuards(nil)
calm()
page(ava).banker = 1
Luxe.runs[ava].goals = { { id = "dropRoom", done = false }, { id = "van", done = false }, { id = "loft", done = false } }
-- A big piece in the Drop Room: tried at once, refused; held long enough, lifted.
local deckSpot = Luxe.spots[22]
setPiece(deckSpot, Plan.byId.deck)
beside(ava, deckSpot)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 22 })
check("a big piece lifted at once is refused: a lift takes its hold", r.ok == false and r.why == "Hold it a moment longer.", r.why)
holdOn(ava, deckSpot)
local giltBefore = giltOf(ava)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 22 })
check("held long enough, it's lifted", r.ok == true and r.piece == "deck", r.why)
local job = last(ava, "objective")
-- (Paid as all Gilt is, under the day's soft cap: the screen is told what was actually paid.)
check("lifting in the Drop Room is a side job: done, and its Gilt paid at once", job ~= nil and job.id == "dropRoom" and job.gilt > 0 and giltOf(ava) - giltBefore == job.gilt and Luxe.runs[ava].goals[1].done == true, job and job.id)
local hud = last(ava, "luxe")
local hudGoals = hud and hud.goals or {}
check("the screen is told the run's side jobs, what each pays and which are done", #hudGoals == 3 and hudGoals[1].line == Plan.objectiveOf.dropRoom.line and hudGoals[1].done == true and hudGoals[2].gilt == Plan.objectiveOf.van.gilt)
-- The van.
standIn(ava, Vector3.new(105, 0, -45))
steps(2)
local bv = last(ava, "banked")
check("the garage van is a way out: walk up to it with the bag and it's banked", bv ~= nil and bv.route == "van" and #Luxe.runs[ava].bag == 0, bv and bv.route)
check("with its bonus (a little more for the side way out)", bv and bv.worth == math.floor(Plan.byId.deck.worth * (1 + C.banker[1] + Plan.Banks[2].bonus) + 0.5), bv and bv.worth)
check("and that side job is done too", last(ava, "objective").id == "van")
-- The loft, and the helicopter on the roof.
local loftSpot = Luxe.spots[28]
setPiece(loftSpot, Plan.byId.headphones)
beside(ava, loftSpot)
holdOn(ava, loftSpot)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 28 })
check("a piece up on the loft is lifted from the loft (and that's a side job)", r.ok == true and last(ava, "objective").id == "loft", r.why)
standIn(ava, Vector3.new(-98, 0, -26))
steps(2)
check("on the floor under the helipad, nothing is banked", #Luxe.runs[ava].bag == 1)
standIn(ava, Vector3.new(-98, Plan.ROOF, -26))
steps(2)
local bh = last(ava, "banked")
check("up on the roof, the helicopter banks it, with the best bonus of all", bh ~= nil and bh.route == "heli" and #Luxe.runs[ava].bag == 0 and bh.worth == math.floor(Plan.byId.headphones.worth * (1 + C.banker[1] + Plan.Banks[3].bonus) + 0.5), bh and bh.worth)
-- A Legendary lifted puts its wing on Alert.
calm()
local keySpot = Luxe.spots[31]
setPiece(keySpot, Plan.byId.keyFob)
beside(ava, keySpot)
holdOn(ava, keySpot)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 31 })
check("lifting a Legendary puts its wing on Alert", r.ok == true and Luxe.alarms[5].level == 1 and workspace.Attractions.StealALuxe:GetAttribute("Alarm5") == 1, Luxe.alarms[5].level)
standIn(ava, Vector3.new(0, 0, -108))
steps(2)

-- The cameras: one held still for the test sees a guest in front of it, in its wing.
for _, cam in camsKept do
	table.insert(Luxe.cams, cam)
end
calm()
parkGuards(nil)
local cam = Luxe.cams[3]
local sweepWas = cam.def.sweep
cam.def.sweep = 0
local look = Plan.cameraLook(cam.def, 0)
local inFront = cam.def.at + look * 14
local spottedBefore = count(ava, "spotted")
standIn(ava, Vector3.new(inFront.X, 0, inFront.Z))
steps(15)
local sp = last(ava, "spotted")
check("a camera that sees a guest long enough puts its wing on Alert", count(ava, "spotted") == spottedBefore + 1 and sp.by == "a camera" and Luxe.alarms[cam.def.wing].level == 1, sp and sp.by)
local aimed = CFrame.lookAt(cam.world, cam.world + look + Vector3.new(0, -0.35, 0))
check("its head turns where it looks", (cam.head.CFrame.Position - aimed.Position).Magnitude < 1e-3 and cam.head.CFrame.LookVector:Dot(aimed.LookVector) > 0.999)
local guardsBefore = #Luxe.guards
steps(50)
check("seen again on Alert, the wing locks down", Luxe.alarms[cam.def.wing].level == 2, Luxe.alarms[cam.def.wing].level)
check("more guards come", #Luxe.guards == guardsBefore + C.reinforcements, #Luxe.guards - guardsBefore)
check("every screen can see it (the residence says so) and the guest is told", workspace.Attractions.StealALuxe:GetAttribute("Alarm" .. cam.def.wing) == 2 and last(ava, "alarm") ~= nil and last(ava, "alarm").level == 2)
local behind = cam.def.at - look * 6
standIn(ava, Vector3.new(behind.X, 0, behind.Z))
local n0 = count(ava, "spotted")
steps(30)
check("behind a camera, unseen", count(ava, "spotted") == n0)
standIn(ava, Vector3.new(inFront.X, 0, inFront.Z))
walled = true
steps(30)
check("behind something solid, unseen", count(ava, "spotted") == n0)
walled = false
cam.def.sweep = sweepWas
table.clear(Luxe.cams)
standIn(ava, Vector3.new(0, 0, -108))
steps(math.ceil((C.lockdownFor + C.alertFor) * 10) + 20)
check("then it cools: the lockdown to Alert, Alert to calm, and the extra guards go", Luxe.alarms[cam.def.wing].level == 0 and #Luxe.guards == guardsBefore, Luxe.alarms[cam.def.wing].level)

-- The laser grid: a dark beam can be crossed; a lit one locks the Strongroom down.
calm()
parkGuards(nil)
local t = Luxe.now()
local lit, dark = nil, nil
for _, l in Plan.Lasers do
	if not Plan.laserOn(l, t + 0.1) and not dark then
		dark = l
	end
end
for _, l in Plan.Lasers do
	if Plan.laserOn(l, t + 0.2) and not lit then
		lit = l
	end
end
check("(one beam is dark and one lit)", lit ~= nil and dark ~= nil)
local before = count(ava, "spotted")
standIn(ava, Vector3.new(-20, 0, dark.z))
steps(1)
check("a dark beam can be crossed", count(ava, "spotted") == before and Luxe.alarms[3].level == 0)
standIn(ava, Vector3.new(-20, 0, lit.z))
steps(1)
check("a lit one is seen: the Strongroom locks down", count(ava, "spotted") == before + 1 and last(ava, "spotted").by == "the laser grid" and Luxe.alarms[3].level == 2, Luxe.alarms[3].level)
local shown = true
for _, d in workspace.Attractions.StealALuxe:GetDescendants() do
	if d:IsA("BasePart") and d.Name == "Laser" then
		for _, l in Plan.Lasers do
			if math.abs(d.CFrame.Position.Z - (O.Z + l.z)) < 0.1 and (d.Transparency < 0.5) ~= Plan.laserOn(l, Luxe.now()) then
				shown = false
			end
		end
	end
end
check("each beam shows lit or dark as the server says", shown)
standIn(ava, Vector3.new(-20, 0, lit.z + 1.5))
steps(20)
calm()
parkGuards(nil)

-- The Secret Stash: the loose bar opens its panel; inside, a side job; it shuts again when nobody's
-- in the doorway (never on anyone).
local door = workspace.Attractions.StealALuxe:FindFirstChild("StashDoor", true)
local lever = workspace.Attractions.StealALuxe:FindFirstChild("PullBar", true)
Luxe.runs[ava].goals = { { id = "stash", done = false } }
standIn(ava, Plan.Stash.lever + Vector3.new(-5, 0, 0))
lever.Triggered:Fire(ava)
check("pulled, the panel slides open, and the guest is told", door.CanCollide == false and door.Transparency == 1 and last(ava, "notice").line == "A panel slid open at the back of the Strongroom.")
standIn(ava, Vector3.new(0, 0, 141))
steps(2)
check("walking into the Secret Stash is a side job, done", last(ava, "objective") ~= nil and last(ava, "objective").id == "stash")
steps(Plan.Stash.openFor * 10 + 10)
check("it never shuts on a guest inside", door.CanCollide == false)
standIn(ava, Vector3.new(0, 0, 100))
steps(40)
check("out again, it shuts", door.CanCollide == true and door.Transparency == 0)
local stashSpot = Luxe.spots[37]
check("its plinths hold the finest things in the house", stashSpot.piece ~= nil and stashSpot.piece.wing == 6 and Plan.rarityOf[stashSpot.piece.rarity].order >= 5)
standIn(ava, Vector3.new(0, 0, -108))
steps(2)

-- Each plinth's five minutes, kept with the guest's ledger: a piece they banked can't be lifted by
-- them again sooner (not in a fresh server, not after a restart).
local sX = Luxe.spots[23]
local resX = bankOne(ava, sX, Plan.byId.shades)
check("(banked)", resX.ok == true, resX.why)
setPiece(sX, Plan.byId.shades) -- (as a fresh server would have it: full again at once)
beside(ava, sX)
holdOn(ava, sX)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 23 })
check("a guest can't lift a piece they banked again before its five minutes, even where it's back sooner", r.ok == false and string.find(r.why, "You banked this one not long ago", 1, true) ~= nil, r.why)
check("it's kept with their ledger", type(page(ava).lifted["23"]) == "number")
H.setWallClock(H.fakeOs.time() + C.respawn + 1)
r = askAs(ava, { op = "act", id = "luxe", act = "take", n = 23 })
check("after its five minutes, it's theirs to lift again", r.ok == true, r.why)
standIn(ava, Vector3.new(0, 0, -108))
steps(2)

-- Limited pieces: set out only while their holiday is open on the house's calendar.
local sL = Luxe.spots[24]
local seen, wrong = 0, 0
local function cycle(n)
	for _ = 1, n do
		if sL.model then
			sL.model:Destroy()
		end
		sL.piece, sL.model, sL.back = nil, nil, 0
		steps(1)
		if sL.piece and sL.piece.rarity == "Limited" then
			if sL.piece.limited == holidayOpen then
				seen += 1
			else
				wrong += 1
			end
		end
	end
end
holidayOpen = nil
cycle(40)
check("with no holiday open, a Limited piece is never set out", seen == 0 and wrong == 0)
holidayOpen = "halloween"
cycle(60)
check("while Halloween is open, the Drop Room sets out its Limited piece now and then (and no other)", seen > 0 and wrong == 0, seen)
local tag = sL.model and sL.model:FindFirstChild("Grade", true)
check("and it wears its label, <LIMITED>", sL.piece.rarity ~= "Limited" or (tag ~= nil and tag.Chip.Text == "<LIMITED>"))
holidayOpen = nil
cycle(1)
check("once the holiday closes, its plinth is given an ordinary piece", sL.piece ~= nil and sL.piece.rarity ~= "Limited")
local logged = {}
for _, e in H.customEvents do
	logged[e.name] = true
end
check("what guests do here is logged for the owner (lifts, banks, side jobs, wings, the stash)", logged["Luxe taken"] and logged["Luxe banked"] and logged["Luxe objective"] and logged["Luxe wing"] and logged["Luxe stash opened"])

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
-- Walking through the arch (Build 78): every way in has an entry zone, and walking into it takes a
-- guest in, on any device; once per walk-in, never back in a loop, never through a wall.
local zones = {}
for _, z in H.tagged.AttractionPortal or {} do
	zones[z:GetAttribute("Attraction")] = z
end
local everyWay = true
for _, p in H.tagged.AttractionPrompt or {} do
	if p:GetAttribute("Kind") == "go" and zones[p:GetAttribute("Attraction")] == nil then
		everyWay = false
	end
end
check("every way in has a zone to walk through", everyWay and zones.luxe ~= nil)
local function within(z, at)
	local rel = z.CFrame:PointToObjectSpace(at)
	return math.abs(rel.X) <= z.Size.X / 2 and math.abs(rel.Y) <= z.Size.Y / 2 and math.abs(rel.Z) <= z.Size.Z / 2
end
local loops = {}
for id, z in zones do
	local home = Attractions.lobbyFrame(id).Position + Vector3.new(0, 3, 0)
	for _, other in zones do
		if within(other, home) then
			table.insert(loops, id)
		end
	end
end
check("nobody comes home into a way in (no loops)", #loops == 0, table.concat(loops, ", "))
local zl = zones.luxe
local floorY = zl.CFrame.Position.Y - zl.Size.Y / 2
advance(3)
stand(ava, Vector3.new(zl.CFrame.Position.X, floorY, zl.CFrame.Position.Z))
steps(3)
check("walking into the arch takes a guest in", Attractions.inside(ava) == "luxe")
advance(3)
arch.Triggered:Fire(ava)
steps(3)
check("...and home again, they stay home (the zone isn't where they arrive)", Attractions.inside(ava) == nil)
advance(3)
-- Standing in the zone on arrival doesn't count: they must walk out and in again.
stand(ava, Vector3.new(zl.CFrame.Position.X, floorY, zl.CFrame.Position.Z))
steps(3)
local entered = Attractions.inside(ava) == "luxe"
check("in again by walking in again", entered)
advance(3)
arch.Triggered:Fire(ava)
steps(2)
-- Just through the wall behind the arch (another room): nothing happens.
local behind = zl.CFrame * CFrame.new(0, 0, zl.Size.Z / 2 + 3)
stand(ava, Vector3.new(behind.Position.X, floorY, behind.Position.Z))
steps(3)
check("from the other side of the wall: nothing", Attractions.inside(ava) == nil)
-- A way in that turns a guest back (the Executive Suite: an invitation from her haul, but no stun
-- pistol yet), walked into: told why, once per walk-in (not every moment they stand there).
local ze = zones.executive
if ze then
	local function count()
		local n = 0
		for _, m in ava.inbox do
			if (m.op == "notice" and m.line == "First take your free stun pistol from the Quartermaster, at his desk in this room.") or (m.op == "panel" and m.id == "executive") then
				n += 1
			end
		end
		return n
	end
	local before = count()
	local fy = ze.CFrame.Position.Y - ze.Size.Y / 2
	advance(3)
	stand(ava, Vector3.new(ze.CFrame.Position.X, fy, ze.CFrame.Position.Z))
	steps(6)
	check("a way in that turns a guest back, walked into: told why once (not every moment they stand there)", count() == before + 1 and Attractions.inside(ava) == nil, count() - before)
	inLounge(ava)
	steps(2)
end
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

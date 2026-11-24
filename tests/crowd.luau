--!nocheck
-- (Build 103) A full house: 24 guests in one server, all at once, each doing a bit of everything
-- in a random order (the same order every run): Steal a Luxe, the Basement, the Executive Suite,
-- the Grand Ballroom, Luxury Island, the house's seats, the elevator to their own wing and to a
-- friend's, the Boutique, the Lucky Boxes, owner-only commands they have no right to, nonsense
-- requests, leaving and coming back. After every round the house is checked:
--   - no request ever fails inside the server ("The house couldn't do that just now.");
--   - Gilt and Gems are always whole, finite and never below zero;
--   - nobody is in two attractions at once, and what their screen is told matches the server;
--   - no seat holds two guests, and nobody holds two seats;
--   - no two guests share a private wing;
--   - an owner-only command from a guest never works;
-- and at the end everyone goes home and leaves, and nothing of theirs is left behind.
--
-- This runs the house's real server code under Lune on a fake clock (tests/harness): it shows
-- what the server does with a full, busy house. It is not a load test on Roblox's servers.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/crowd.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame, Instance = H.Vector3, H.CFrame, H.Instance
local module, profiles = H.module, H.profiles
local Remotes = H.Remotes

-- (No dressed rigs under Lune: guards and staff are plain figures.)
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
local Furniture = module("ReplicatedStorage", "Shared", "Furniture")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Herald = module("ServerScriptService", "Server", "Herald")
local Seating = module("ServerScriptService", "Server", "Seating")
local Wings = module("ServerScriptService", "Server", "Wings")
local Friends = module("ServerScriptService", "Server", "Friends")
local Workspace = H.game:GetService("Workspace")

-- A small house to copy for the private wings (as tests/wings builds it), with a bench to sit on.
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
local foyerRoom = model("Foyer", maison)
local benches = {}
for i = 1, 6 do
	table.insert(benches, Furniture.seatsOn(foyerRoom, "BenchSeats", { CFrame.new(i * 6, 2, 30), CFrame.new(i * 6 + 2.5, 2, 30) }, "The bench", 1.6))
end
maison.Parent = Workspace
Lobbies.build(Workspace)

-- Friends: every guest with the next two (so friend visits happen, and are refused otherwise).
Friends.are = function(a, b)
	local d = math.abs(a.UserId - b.UserId)
	return d >= 1 and d <= 2
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
local openSuite = {}
Wings.mayVisit = function(host, _visitor)
	if openSuite[host] then
		return true, nil
	end
	return false, "Their Suite is closed to visitors."
end

-- The guests: 24, the most a server holds, each with some Gilt and Gems (as if earned and bought).
-- (A small seeded generator of our own: the same evening every run.)
local rng = { state = 103 }
function rng:NextNumber()
	self.state = (self.state * 1103515245 + 12345) % 2147483648
	return self.state / 2147483648
end
function rng:NextInteger(a, b)
	return a + math.floor(self:NextNumber() * (b - a + 1))
end
local guests = {}
for i = 1, 24 do
	local g = H.guest("Guest" .. i, 7000 + i)
	g.Character = g.body
	g.root.CFrame = CFrame.new(Vector3.new(rng:NextInteger(-20, 20), 6, rng:NextInteger(10, 40)))
	local data = profiles[g].Data
	data.gilt = rng:NextInteger(0, 50000)
	data.gems = rng:NextInteger(0, 600)
	openSuite[g] = rng:NextNumber() < 0.5
	table.insert(guests, g)
end
run(Herald.start)
run(Attractions.start)
-- Half the guests have earned an invitation up to the Executive Suite and taken the free sidearm
-- (as if from earlier evenings), so the Suite is busy too.
local Executive = module("ServerScriptService", "Server", "Attractions", "Executive")
for i, g in guests do
	if i % 2 == 0 then
		local pg = Executive.page(Attractions.ctx, profiles[g].Data)
		pg.invites = 3
		pg.sidearm = true
	end
end
run(Seating.start)
run(Wings.start)

---------------------------------------------------------------------------------------------------
-- What a guest can ask
---------------------------------------------------------------------------------------------------
local crashes = {}
local CRASH = "The house couldn't do that just now."
local function noteCrash(g, remote, request, r)
	if type(r) == "table" and r.why == CRASH then
		table.insert(crashes, string.format("%s %s %s", g.Name, remote, H.encode and H.encode(request) or tostring(request.op or request.act)))
	end
end
local stats = {}
local whys = {}
local missing = {}
local function tally(key)
	stats[key] = (stats[key] or 0) + 1
end
local function invoke(g, remote, request)
	advance(0.05)
	local f = Remotes.funcs[remote]
	if not f or not f.OnServerInvoke then
		missing[remote] = true
		return nil
	end
	local r
	run(function()
		r = f.OnServerInvoke(g, request)
	end)
	noteCrash(g, remote, request, r)
	local what = tostring(request.op) .. (if request.act then "/" .. tostring(request.act) elseif request.id and request.op == "go" then "/" .. tostring(request.id) else "")
	local key = remote .. " " .. what .. (if type(r) == "table" and r.ok == true then " ok" else " refused")
	tally(key)
	if type(r) == "table" and r.ok ~= true and type(r.why) == "string" then
		whys[key] = whys[key] or {}
		whys[key][r.why] = (whys[key][r.why] or 0) + 1
	end
	return r
end
local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local ATTRACTIONS = { "luxe", "basement", "executive", "gala", "island" }
local ACTS = {
	luxe = function()
		return pick({
			{ act = "take", n = rng:NextInteger(1, 30) },
			{ act = "golden" },
			{ act = "upgrade", what = pick({ "bag", "wings", "hands", "nonsense" }) },
		})
	end,
	basement = function()
		return pick({
			{ act = "skip" },
			{ act = "skip", what = "gems" },
			{ act = "skip", what = "gems", price = 0 },
			{ act = "boards", what = pick({ "week", "friends", "all" }) },
		})
	end,
	executive = function()
		return pick({
			{ act = "invite" },
			{ act = "gear", what = pick({ "disguise", "sidearm", "decoy", "nonsense" }) },
			{ act = "code", code = tostring(rng:NextInteger(0, 9999)) },
			{ act = "terminal", n = rng:NextInteger(1, 6) },
			{ act = "sidearm" },
			{ act = "decoy" },
			{ act = "safe" },
			{ act = "loot", what = pick({ "bullion", "watches", "briefcase", "drawers" }) },
			{ act = "revive" },
		})
	end,
	gala = function()
		return pick({
			{ act = "join", what = pick({ "trivia", "runway", "arena", "dance", "nonsense" }) },
			{ act = "vote", userId = 7000 + rng:NextInteger(1, 24) },
			{ act = "pose", n = rng:NextInteger(1, 6) },
			{ act = "answer", n = rng:NextInteger(1, 4) },
			{ act = "quit", what = pick({ "trivia", "runway", "arena" }) },
			{ act = "fly" },
		})
	end,
	island = function()
		return pick({
			{ act = "key", what = pick({ "gilt", "gems" }) },
			{ act = "pearl", n = rng:NextInteger(1, 16) },
			{ act = "postcard", id = pick({ "jet", "villa", "pier", "beach", "summit", "marina", "nonsense" }) },
			{ act = "toast" },
			{ act = "path", to = pick({ "head", "foot" }) },
			{ act = "exchange", id = "nonsense" },
			{ act = "livery", id = "nonsense" },
			{ act = "theme", id = "nonsense" },
		})
	end,
}
local SHOP = {
	function()
		return { op = "buy", id = pick({ "aura_free", "aura_golddust", "aura_rainbow", "comp_fox", "title_legend", "boost_gilt", "nonsense" }) }
	end,
	function()
		return { op = "buyGilt", item = pick({ "trail_jade", "nonsense" }) }
	end,
	function()
		return { op = "equip", kind = pick({ "aura", "companion", "title" }), id = pick({ "aura_rainbow", "comp_fox", "", "nonsense" }) }
	end,
	function()
		return { op = "state" }
	end,
	function()
		return { op = "visit", userId = 7000 + rng:NextInteger(1, 24) }
	end,
}
-- What only the owner may do: a guest asking must never get it.
local OWNER_ONLY = {
	{ op = "power", power = "fly" },
	{ op = "power", power = "speed", value = 5 },
	{ op = "abuse" },
	{ op = "mega" },
	{ op = "freeze", userId = 7001 },
	{ op = "headline", text = "hello" },
	{ op = "fx", id = "confetti" },
	{ op = "goldKeyGift", userId = 7002 },
}
local ownerOnlyAllowed = {}

local present = {}
for _, g in guests do
	present[g] = true
end

local function seatSpots()
	local out = {}
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "SitSpot" and type(d:GetAttribute("SeatId")) == "number" then
			table.insert(out, d)
		end
	end
	return out
end

-- Where each attraction's entrance room is (a point inside it, on its floor): a guest walks there
-- first, as a real guest does, before asking to go in.
local AttractionList = module("ReplicatedStorage", "Shared", "Attractions")
local lobbyAt = {}
for _, id in ATTRACTIONS do
	local def = AttractionList.byId[id]
	for _, v in Layout do
		if type(v) == "table" and type(v.zone) == "table" and v.zone.min and v.zone.max then
			local c = (v.zone.min + v.zone.max) / 2
			local p = Vector3.new(c.X, v.zone.min.Y + 3, c.Z)
			if def and Layout.zoneAt(p) == def.room then
				lobbyAt[id] = p
				break
			end
		end
	end
end
local entered = {}

-- Playing inside, as a guest does: in Steal a Luxe, walking up to a plinth, holding, lifting the
-- piece, and now and then walking to the getaway car to bank the bag; in the Basement, reaching
-- the next checkpoint in order.
local Luxe = module("ServerScriptService", "Server", "Attractions", "Luxe")
local Basement = module("ServerScriptService", "Server", "Attractions", "Basement")
local BPlan = module("ReplicatedStorage", "Shared", "Basement")
local played = { took = 0, banked = 0, checkpoint = 0 }
local function countOps(op)
	local n = 0
	for _, g in guests do
		for _, m in g.inbox do
			if type(m) == "table" and m.op == op then
				n += 1
			end
		end
	end
	return n
end
local function playInside(g, id)
	if id == "luxe" then
		local O = Luxe.origin()
		if rng:NextNumber() < 0.35 and Luxe.runs[g] and #Luxe.runs[g].bag > 0 then
			g.root.CFrame = CFrame.new(O + Vector3.new(0, 3, -108))
			advance(0.3)
			return
		end
		local ids = {}
		for sid, sp in Luxe.spots do
			if sp.piece and sp.top then
				table.insert(ids, sid)
			end
		end
		if #ids == 0 then
			return
		end
		local sid = pick(ids)
		local sp = Luxe.spots[sid]
		local top = sp.top.CFrame.Position
		g.root.CFrame = CFrame.new(Vector3.new(top.X, O.Y + sp.spot.at.Y + 3, top.Z - 4))
		for _ = 1, 30 do
			advance(0.1)
		end
		invoke(g, "AttractionAsk", { op = "act", id = "luxe", act = "take", n = sid })
	elseif id == "basement" then
		local run = Basement.runs[g]
		if not run then
			return
		end
		local nextN = (run.checkpoint or 0) + 1
		local cp = BPlan.Checkpoints[nextN]
		if cp then
			g.root.CFrame = CFrame.new(Basement.origin() + cp.at + Vector3.new(0, 3, 0))
			advance(0.15)
		end
	end
end

local function oneTurn(g)
	local roll = rng:NextNumber()
	if roll < 0.16 then
		local id = pick(ATTRACTIONS)
		if lobbyAt[id] and rng:NextNumber() < 0.85 then
			g.root.CFrame = CFrame.new(lobbyAt[id])
		end
		local r = invoke(g, "AttractionAsk", { op = "go", id = id })
		if type(r) == "table" and r.ok == true then
			entered[id] = (entered[id] or 0) + 1
			advance(0.3)
			invoke(g, "AttractionAsk", { op = "ready", id = id })
		end
	elseif roll < 0.33 and (Attractions.inside(g) == "luxe" or Attractions.inside(g) == "basement") then
		playInside(g, Attractions.inside(g))
	elseif roll < 0.45 then
		local id = Attractions.inside(g) or pick(ATTRACTIONS)
		local a = ACTS[id]()
		a.op, a.id = "act", id
		invoke(g, "AttractionAsk", a)
	elseif roll < 0.5 then
		invoke(g, "AttractionAsk", { op = "home" })
	elseif roll < 0.6 then
		local spots = seatSpots()
		if #spots > 0 then
			local s = pick(spots)
			if rng:NextNumber() < 0.7 then
				g.root.CFrame = s.CFrame * CFrame.new(0, 0, -2)
			end
			invoke(g, "SitAsk", { op = "sit", seat = s:GetAttribute("SeatId") })
		end
	elseif roll < 0.65 then
		invoke(g, "SitAsk", { op = "stand" })
	elseif roll < 0.73 then
		local to = pick({ "suite", "vault", "house", "friend" })
		local request = { to = if to == "friend" then "suite" else to }
		if to == "friend" then
			request.host = 7000 + rng:NextInteger(1, 24)
		end
		run(function()
			local ok, r = pcall(Wings.handle, g, request)
			if not ok then
				table.insert(crashes, g.Name .. " elevator " .. tostring(r))
			end
		end)
		advance(0.05)
	elseif roll < 0.85 then
		local r = invoke(g, "ShopAsk", pick(SHOP)())
		local _ = r
	elseif roll < 0.9 then
		local request = table.clone(pick(OWNER_ONLY))
		local r = invoke(g, "ShopAsk", request)
		if type(r) == "table" and r.ok == true then
			table.insert(ownerOnlyAllowed, g.Name .. " " .. tostring(request.op))
		end
	elseif roll < 0.95 then
		-- Nonsense: wrong types, huge numbers, missing fields.
		local junk = pick({
			{ op = "act", id = pick(ATTRACTIONS), act = "take", n = 1e9 },
			{ op = "go", id = 12 },
			{ op = string.rep("x", 300) },
			{ op = "act", id = "luxe", act = "take", n = -1 },
			{ op = "act", id = "island", act = "pearl", n = 0 / 0 },
			{},
		})
		invoke(g, "AttractionAsk", junk)
		invoke(g, "ShopAsk", junk)
		invoke(g, "SitAsk", junk)
	else
		-- Wander somewhere in the house.
		g.root.CFrame = CFrame.new(Vector3.new(rng:NextInteger(-60, 60), 6, rng:NextInteger(-40, 80)))
	end
end

---------------------------------------------------------------------------------------------------
-- The house's health, checked after every round
---------------------------------------------------------------------------------------------------
local problems = {}
local function problem(kind, detail)
	problems[kind] = problems[kind] or {}
	if #problems[kind] < 5 then
		table.insert(problems[kind], detail)
	end
end
local function audit(round)
	local seatOf = {}
	for _, s in seatSpots() do
		local who = s:GetAttribute("Taken")
		if who ~= nil then
			if seatOf[who] then
				problem("two seats", string.format("round %d: %s holds two seats", round, tostring(who)))
			end
			seatOf[who] = true
		end
	end
	local wings = {}
	for _, g in guests do
		if present[g] then
			local data = profiles[g] and profiles[g].Data
			if data then
				for _, k in { "gilt", "gems" } do
					local v = data[k]
					if type(v) ~= "number" or v ~= v or v == math.huge or v < 0 or v ~= math.floor(v) then
						problem("money", string.format("round %d: %s %s = %s", round, g.Name, k, tostring(v)))
					end
				end
			end
			local inside = Attractions.inside(g)
			local told = g:GetAttribute("Attraction")
			if told ~= nil and told ~= inside then
				problem("attraction mismatch", string.format("round %d: %s told %s, server says %s", round, g.Name, tostring(told), tostring(inside)))
			end
			local slot = Wings.slotOf(g)
			if slot ~= nil then
				if wings[slot] then
					problem("shared wing", string.format("round %d: %s and %s share wing %d", round, wings[slot].Name, g.Name, slot))
				end
				wings[slot] = g
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The evening
---------------------------------------------------------------------------------------------------
local ROUNDS = 150
local leftAndBack = 0
for round = 1, ROUNDS do
	for _, g in guests do
		if present[g] then
			oneTurn(g)
		end
	end
	-- Now and then someone leaves, and comes back a little later.
	if round % 10 == 5 then
		local g = guests[rng:NextInteger(1, #guests)]
		if present[g] then
			present[g] = false
			run(function()
				H.PlayersService.PlayerRemoving:Fire(g)
			end)
			leftAndBack += 1
		end
	elseif round % 10 == 8 then
		for _, g in guests do
			if not present[g] then
				present[g] = true
				run(function()
					H.PlayersService.PlayerAdded:Fire(g)
				end)
			end
		end
	end
	advance(0.5)
	audit(round)
end

-- What the evening actually did (so a quiet pass can't hide a test that did nothing).
local keys = {}
for k in stats do
	table.insert(keys, k)
end
table.sort(keys)
for _, k in keys do
	print(string.format("  %5d  %s", stats[k], k))
	if os.getenv and false then
		print("")
	end
	for why, n in whys[k] or {} do
		print(string.format("           %4d x %s", n, string.sub(why, 1, 110)))
	end
end
local sumOk = 0
for k, n in stats do
	if string.find(k, " ok$") then
		sumOk += n
	end
end
check("every remote the evening used exists", next(missing) == nil, (function()
	local out = {}
	for k in missing do
		table.insert(out, k)
	end
	return table.concat(out, ", ")
end)())
check("the evening really happened: hundreds of requests the house said yes to", sumOk >= 200, sumOk)
check(string.format("24 guests, %d rounds of everything at once: no request failed inside the server", ROUNDS), #crashes == 0, table.concat(crashes, "\n  "))
check("Gilt and Gems stayed whole, finite and never below zero for everyone", problems.money == nil, problems.money and table.concat(problems.money, "; "))
check("nobody held two seats", problems["two seats"] == nil, problems["two seats"] and table.concat(problems["two seats"], "; "))
check("nobody's screen was told a different attraction from the server's", problems["attraction mismatch"] == nil, problems["attraction mismatch"] and table.concat(problems["attraction mismatch"], "; "))
check("no two guests ever shared a private wing", problems["shared wing"] == nil, problems["shared wing"] and table.concat(problems["shared wing"], "; "))
check("an owner-only command from a guest never worked", #ownerOnlyAllowed == 0, table.concat(ownerOnlyAllowed, "; "))
check("guests left and came back during the evening", leftAndBack > 0)
played.took, played.banked, played.checkpoint = countOps("took"), countOps("banked"), countOps("checkpoint")
print(string.format("  played: %d pieces lifted, %d bags banked, %d Basement checkpoints reached", played.took, played.banked, played.checkpoint))
check("guests really played: pieces lifted and banked in Steal a Luxe, checkpoints reached in the Basement", played.took > 0 and played.banked > 0 and played.checkpoint > 0, string.format("took %d banked %d checkpoints %d", played.took, played.banked, played.checkpoint))
check("guests really went into every open attraction (Luxe, the Basement, the Executive Suite, the Ballroom)", (entered.luxe or 0) > 0 and (entered.basement or 0) > 0 and (entered.executive or 0) > 0 and (entered.gala or 0) > 0, (function()
	local out = {}
	for _, id in ATTRACTIONS do
		table.insert(out, id .. "=" .. tostring(entered[id] or 0) .. (if lobbyAt[id] then "" else "(no entrance found)"))
	end
	return table.concat(out, " ")
end)())

-- Everyone goes home, stands up, and leaves.
for _, g in guests do
	if present[g] then
		invoke(g, "SitAsk", { op = "stand" })
		invoke(g, "AttractionAsk", { op = "home" })
	end
end
advance(8)
local stillIn = {}
for _, g in guests do
	if present[g] and Attractions.inside(g) ~= nil then
		table.insert(stillIn, g.Name .. ":" .. tostring(Attractions.inside(g)))
	end
end
check("asked to go home, everyone is out of every attraction", #stillIn == 0, table.concat(stillIn, ", "))
for _, g in guests do
	if present[g] then
		present[g] = false
		run(function()
			H.PlayersService.PlayerRemoving:Fire(g)
		end)
	end
end
advance(3)
local left = {}
for _, g in guests do
	if Seating.isSeated(g) then
		table.insert(left, g.Name .. " seated")
	end
	if Wings.slotOf(g) ~= nil then
		table.insert(left, g.Name .. " wing")
	end
	if Attractions.inside(g) ~= nil then
		table.insert(left, g.Name .. " in " .. tostring(Attractions.inside(g)))
	end
end
local taken = 0
for _, s in seatSpots() do
	if s:GetAttribute("Taken") ~= nil then
		taken += 1
	end
end
check("once everyone has left: no seat still taken, no wing still held, nobody still in an attraction", #left == 0 and taken == 0, table.concat(left, ", ") .. (if taken > 0 then " / seats taken: " .. taken else ""))
check("after it all, no request failed inside the server", #crashes == 0, #crashes)

H.finish()

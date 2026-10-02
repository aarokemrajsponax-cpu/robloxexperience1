--!nocheck
-- Plays whole Tête-à-Tête evenings against the real DuelService under Lune, on a fake clock:
-- two guests at a Library table, identical deals, parcels and their fuses, defence, fumbles,
-- the hand cap, forfeits, a Stand-in, ratings and Another. Every message a client would get is
-- recorded and checked for the fields the client reads.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/duel.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Instance, Vector3, Enum, CFrame = roblox.Instance, roblox.Vector3, roblox.Enum, roblox.CFrame

local passed, failed = 0, 0
local function check(name: string, ok: boolean, detail: any?)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (if detail ~= nil then "  -> " .. tostring(detail) else ""))
	end
end

---------------------------------------------------------------------------------------------------
-- A fake clock, a scheduler and signals
---------------------------------------------------------------------------------------------------
local now = 1000
local timers = {}
local function schedule(at, fn, ...)
	table.insert(timers, { at = at, fn = fn, args = table.pack(...) })
end

local function run(fn, ...)
	local co = coroutine.create(fn)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(debug.traceback(co, tostring(err)))
	end
end

local function signal()
	local s = { handlers = {} }
	function s:Connect(fn)
		local entry = { fn = fn, live = true }
		table.insert(self.handlers, entry)
		return {
			Disconnect = function()
				entry.live = false
			end,
		}
	end
	function s:Once(fn)
		local c
		c = self:Connect(function(...)
			c.Disconnect()
			fn(...)
		end)
		return c
	end
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			if h.live then
				run(h.fn, ...)
			end
		end
	end
	return s
end

local heartbeat = signal()

local function step(dt: number)
	local target = now + dt
	while true do
		table.sort(timers, function(a, b)
			return a.at < b.at
		end)
		local t = timers[1]
		if not t or t.at > target then
			break
		end
		table.remove(timers, 1)
		now = math.max(now, t.at)
		run(t.fn, table.unpack(t.args, 1, t.args.n))
	end
	now = target
	heartbeat:Fire(dt)
end

local function advance(seconds: number)
	local left = seconds
	while left > 1e-9 do
		local dt = math.min(1 / 30, left)
		step(dt)
		left -= dt
	end
end

local taskShim = {
	spawn = function(fn, ...)
		run(fn, ...)
	end,
	delay = function(t, fn, ...)
		schedule(now + (t or 0), fn, ...)
	end,
	defer = function(fn, ...)
		schedule(now, fn, ...)
	end,
	wait = function(t)
		local co = coroutine.running()
		schedule(now + (t or 1 / 30), function()
			local ok, err = coroutine.resume(co)
			if not ok then
				error(debug.traceback(co, tostring(err)))
			end
		end)
		coroutine.yield()
		return t
	end,
}

---------------------------------------------------------------------------------------------------
-- Guests, their characters and what they receive
---------------------------------------------------------------------------------------------------
local PlayersService = { PlayerRemoving = signal(), PlayerAdded = signal() }
local workspace = {}

local function humanoid()
	return {
		Health = 100,
		Sit = false,
		SeatPart = nil,
		Seated = signal(),
		Died = signal(),
	}
end

local function newGuest(name: string, userId: number)
	local h = humanoid()
	local root = { Position = Vector3.new(0, 0, 0) }
	local character = {
		FindFirstChildOfClass = function(_, class)
			return if class == "Humanoid" then h else nil
		end,
		FindFirstChild = function(_, n)
			return if n == "HumanoidRootPart" then root elseif n == "Humanoid" then h else nil
		end,
		PivotTo = function(_, cf)
			root.Position = cf.Position
		end,
		Parent = workspace,
	}
	return {
		Name = name,
		DisplayName = name,
		UserId = userId,
		AccountAge = 400,
		Parent = PlayersService,
		Character = character,
		humanoid = h,
		root = root,
		inbox = {},
		CharacterAdded = signal(),
	}
end

roblox.implementMethod("Seat", "Sit", function(self, h)
	h.SeatPart = self
end)

---------------------------------------------------------------------------------------------------
-- The Library: two long tables, each two halves facing each other
---------------------------------------------------------------------------------------------------
local halves = {}
local seatAt = {}
local function makeHalf(duelId: string, side: string, z: number)
	local m = Instance.new("Model")
	m.Name = "Table" .. duelId .. side
	m:SetAttribute("Duel", duelId)
	m:SetAttribute("Side", side)
	m:SetAttribute("TableId", duelId .. side)
	local seat = Instance.new("Seat")
	seat.Name = "Chair"
	seat.CFrame = CFrame.new(0, 2, z)
	seat.Position = Vector3.new(0, 2, z) -- Lune stores Position separately from CFrame
	seat.Parent = m
	seatAt[m] = Vector3.new(0, 2, z)
	m:AddTag("DuelHalf")
	table.insert(halves, m)
	return m
end
local l1a, l1b = makeHalf("library-1", "a", -8), makeHalf("library-1", "b", 8)
local l2a, l2b = makeHalf("library-2", "a", 92), makeHalf("library-2", "b", 108)


---------------------------------------------------------------------------------------------------
-- Stubs for the server modules around the duel (the shared rules load for real)
---------------------------------------------------------------------------------------------------
local profiles = {}
local function profileFor(player)
	local data = profiles[player]
	if not data then
		data = {
			nights = { count = 6 },
			stats = { rounds = 40 },
			settings = { offerStandIn = "Yes" },
			duel = { r = 1500, rd = 350, vol = 0.06, matches = 0, wins = 0, losses = 0, termMatches = 0, term = "", best = 0, recent = {} },
			gilt = 0,
		}
		profiles[player] = data
	end
	return data
end

local tableEvent = {
	OnServerEvent = signal(),
	FireClient = function(_, player, message)
		table.insert(player.inbox, message)
	end,
}
local dialogueChoice = "standin"
local dialogues = {}
local ratingsSubmitted = {}

local sourcemap = serde.decode("json", fs.readFile("sourcemap.json"))
local proxies, cache = {}, {}
local requireModule

local function pathOf(node, parentPath)
	return if parentPath then parentPath .. "." .. node.name else node.name
end

local function proxyFor(node, parent, path)
	if proxies[node] then
		return proxies[node]
	end
	local p = {}
	proxies[node] = p
	setmetatable(p, {
		__index = function(_, key)
			if key == "Parent" then
				return parent
			elseif key == "Name" then
				return node.name
			end
			for _, child in node.children or {} do
				if child.name == key then
					return proxyFor(child, p, pathOf(child, path))
				end
			end
			error(`{key} is not a valid member of {node.name}`)
		end,
	})
	rawset(p, "__node", node)
	rawset(p, "__path", path)
	return p
end
local root = proxyFor(sourcemap, nil, nil)

local function module(...)
	local p = root
	for _, name in { ... } do
		p = p[name]
	end
	return requireModule(p)
end

local stubs = {
	["ReplicatedStorage.Shared.Remotes"] = function()
		return {
			event = function(name)
				assert(name == "Table", "unexpected remote " .. name)
				return tableEvent
			end,
			func = function()
				return {}
			end,
		}
	end,
	["ServerScriptService.Server.Analytics"] = function()
		return { custom = function() end, step = function() end }
	end,
	["ServerScriptService.Server.Boards"] = function()
		return {
			submitRating = function(player, r)
				ratingsSubmitted[player.Name] = r
			end,
		}
	end,
	["ServerScriptService.Server.Dialogue"] = function()
		return {
			say = function(player, speaker, line, choices, onChoice)
				table.insert(dialogues, { player = player, line = line, choices = choices })
				if onChoice then
					schedule(now + 0.5, onChoice, dialogueChoice)
				end
			end,
		}
	end,
	["ServerScriptService.Server.Gilt"] = function()
		return {
			pay = function(_player, data, earned)
				data.gilt += earned
				return earned
			end,
		}
	end,
	["ServerScriptService.Server.Profiles"] = function()
		return { get = profileFor }
	end,
	["ServerScriptService.Server.Season"] = function()
		return {
			current = function()
				return module("ReplicatedStorage", "Shared", "Seasons").now()
			end,
		}
	end,
	["ServerScriptService.Server.Staff.Rig"] = function()
		return {
			look = function()
				return {}
			end,
			build = function(name, _look, cf, parent)
				local m = Instance.new("Model")
				m.Name = name
				local head = Instance.new("Part")
				head.Name = "Head"
				head.CFrame = cf
				head.Parent = m
				m.Parent = parent
				return { model = m, humanoid = humanoid() }
			end,
		}
	end,
}

local CollectionService = {
	GetTagged = function(_, tag)
		return if tag == "DuelHalf" then halves else {}
	end,
}
local services = {
	Players = PlayersService,
	CollectionService = CollectionService,
	RunService = {
		Heartbeat = heartbeat,
		IsServer = function()
			return true
		end,
		IsStudio = function()
			return true
		end,
	},
}

local gameShim = setmetatable({
	GetService = function(_, name)
		if services[name] then
			return services[name]
		end
		for _, child in sourcemap.children do
			if child.name == name then
				return proxyFor(child, root, child.name)
			end
		end
		error("no service " .. name)
	end,
}, {})

local fakeOs = setmetatable({
	clock = function()
		return now
	end,
}, { __index = os })

local globals = {
	Instance = Instance,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	Color3 = roblox.Color3,
	Enum = Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Font = {
		new = roblox.Font.new,
		fromName = roblox.Font.fromName,
		fromEnum = function(e)
			local ok, f = pcall(roblox.Font.fromEnum, e)
			return if ok then f else roblox.Font.new("rbxasset://fonts/families/BuilderSans.json")
		end,
	},
	Random = nil, -- filled below
	task = taskShim,
	game = gameShim,
	os = fakeOs,
	warn = function(...)
		print("warn:", ...)
	end,
}

-- Roblox's Random, deterministic enough for a test (xorshift).
local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = (math.floor(seed or 1) * 2654435761 + 12345) % 4294967296
	if state == 0 then
		state = 1
	end
	return setmetatable({ state = state }, Random)
end
function Random:next()
	local s = self.state
	s = bit32.bxor(s, bit32.lshift(s, 13) % 4294967296)
	s = bit32.bxor(s, bit32.rshift(s, 17))
	s = bit32.bxor(s, bit32.lshift(s, 5) % 4294967296)
	self.state = s
	return s / 4294967296
end
function Random:NextNumber(a, b)
	local r = self:next()
	return if a then a + r * (b - a) else r
end
function Random:NextInteger(a, b)
	return a + math.floor(self:next() * (b - a + 1))
end
globals.Random = Random

function requireModule(proxy)
	local node = rawget(proxy, "__node")
	if cache[node] ~= nil then
		return cache[node]
	end
	local stub = stubs[rawget(proxy, "__path")]
	if stub then
		cache[node] = stub()
		return cache[node]
	end
	local path
	for _, f in node.filePaths or {} do
		if string.find(f, "%.luau$") then
			path = f
		end
	end
	assert(path, "no source for " .. node.name)
	local env = { script = proxy, require = requireModule }
	for k, v in globals do
		env[k] = v
	end
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env, injectGlobals = true })
	local result = fn()
	cache[node] = result
	return result
end

-- Lune reads files asynchronously, which would pause a coroutine mid-hand; load every module
-- the service touches up front.
module("ReplicatedStorage", "Shared", "Seasons")
local Config = module("ReplicatedStorage", "Shared", "Config")
local L = Config.data.Library
local DuelService = module("ServerScriptService", "Server", "DuelService")
local said = {}
DuelService.say = function(player, line)
	table.insert(said, { player = player, line = line })
end

---------------------------------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------------------------------
local function take(player, op, since: number?)
	local out = {}
	for i, m in player.inbox do
		if m.op == op and i > (since or 0) then
			table.insert(out, m)
		end
	end
	return out
end
local function mark(player): number
	return #player.inbox
end
local function last(player, op)
	local list = take(player, op)
	return list[#list]
end
local function clearInbox(...)
	for _, p in { ... } do
		p.inbox = {}
	end
end
local function sit(player, half)
	player.root.Position = seatAt[half] + Vector3.new(0, 0, -2)
	local result
	run(function()
		result = table.pack(DuelService.sit(player, half, function()
			return false
		end))
	end)
	advance(0.1)
	return result[1], result[2]
end
local function send(player, message)
	tableEvent.OnServerEvent:Fire(player, message)
end

-- The guest's live felt, rebuilt from their messages.
local function felt(player)
	local pieces = {}
	for _, m in player.inbox do
		if m.op == "deal" then
			pieces = {}
			for _, p in m.pieces do
				pieces[p.uid] = p
			end
		elseif m.op == "parcelOpen" and m.side == player.side then
			for _, p in m.pieces do
				pieces[p.uid] = p
			end
		elseif m.op == "filed" and m.correct then
			pieces[m.uid] = nil
		end
	end
	return pieces
end
local function sortedUids(pieces)
	local out = {}
	for uid in pieces do
		table.insert(out, uid)
	end
	table.sort(out)
	return out
end
local function wrongCase(cases, right)
	for _, c in cases do
		if c ~= right then
			return c
		end
	end
	return right
end

-- Files one piece: the right case, or a wrong one.
local function fileOne(player, correct: boolean, preferCase: string?)
	local pieces = felt(player)
	local deal = last(player, "deal")
	local pick
	for _, uid in sortedUids(pieces) do
		if preferCase == nil or pieces[uid].case == preferCase then
			pick = pieces[uid]
			break
		end
	end
	if not pick then
		return false
	end
	send(player, { op = "file", uid = pick.uid, case = if correct then pick.case else wrongCase(deal.cases, pick.case) })
	return true
end

-- Files the whole felt as runs: every piece of one case, then the next (sends parcels).
local function clearFelt(player, gap: number, maxSteps: number?)
	local steps = 0
	while true do
		local pieces = felt(player)
		local uids = sortedUids(pieces)
		if #uids == 0 then
			return true
		end
		local caseCounts = {}
		for _, uid in uids do
			local c = pieces[uid].case
			caseCounts[c] = (caseCounts[c] or 0) + 1
		end
		local lastFiled = last(player, "filed")
		local prefer = if lastFiled and lastFiled.correct and caseCounts[lastFiled.case] then lastFiled.case else nil
		if not prefer then
			local best, bestN = nil, -1
			for c, n in caseCounts do
				if n > bestN or (n == bestN and c < best) then
					best, bestN = c, n
				end
			end
			prefer = best
		end
		fileOne(player, true, prefer)
		advance(gap)
		steps += 1
		if maxSteps and steps >= maxSteps then
			return false
		end
		local ended = last(player, "handEnd")
		if ended and ended.hand == (last(player, "deal") or {}).round then
			return true
		end
	end
end

local function fieldsPresent(message, fields)
	for _, f in fields do
		if message[f] == nil then
			return false, f
		end
	end
	return true
end

DuelService.start(function()
	return false
end)

---------------------------------------------------------------------------------------------------
-- 1. Two guests sit; a ranked evening starts; identical deals
---------------------------------------------------------------------------------------------------
local ada = newGuest("Ada", 1)
local ben = newGuest("Ben", 2)
ada.side, ben.side = "a", "b"

local ok = sit(ada, l1a)
check("first guest sits", ok == true)
check("seated message says duel and library", (last(ada, "seated") or {}).mode == "duel" and last(ada, "seated").room == "library")
check("first guest waits", last(ada, "duelWaiting") ~= nil)
check("the house says a table is being laid", #said > 0)
check("a far guest can't sit", (function()
	local far = newGuest("Far", 9)
	far.root.Position = Vector3.new(500, 0, 500)
	local r
	run(function()
		r = table.pack(DuelService.sit(far, l2a, function()
			return false
		end))
	end)
	return r[1] == false and r[2] == "far"
end)())
local okTaken, whyTaken = sit(newGuest("Cleo", 3), l1a)
check("a taken chair is refused", okTaken == false and whyTaken == "taken", whyTaken)

sit(ben, l1b)
local startA, startB = last(ada, "duelStart"), last(ben, "duelStart")
check("both guests get the start", startA ~= nil and startB ~= nil)
check("start names the rival", startA and startA.rival == "Ben" and startB.rival == "Ada")
check("two eligible guests play ranked", startA and startA.ranked == true)
check("start has the fields the client reads", fieldsPresent(startA or {}, { "side", "rival", "ranked", "standIn" }))
check("sides are a and b", startA and startA.side == "a" and startB.side == "b")

advance(2.6)
local dealA, dealB = last(ada, "deal"), last(ben, "deal")
check("hand I is dealt to both", dealA ~= nil and dealB ~= nil)
check("deal has the fields the client reads", fieldsPresent(dealA or {}, { "mode", "room", "side", "round", "cases", "pieces", "score", "wins", "clock" }))
check("hand I is 14 pieces", dealA and #dealA.pieces == L.pieces[1], dealA and #dealA.pieces)
check("hand I opens 4 cases", dealA and #dealA.cases == L.cases[1])
local sameDeal = dealA ~= nil and dealB ~= nil and #dealA.pieces == #dealB.pieces
if sameDeal then
	for i, p in dealA.pieces do
		if dealB.pieces[i].id ~= p.id then
			sameDeal = false
		end
	end
end
check("the identical deal is on both felts", sameDeal)
check("each guest sees the rival's felt", (last(ada, "rivalDeal") or { pieces = {} }).pieces[1] ~= nil and #last(ada, "rivalDeal").pieces == L.pieces[1])
check("the counter shows the pieces left", l1a:GetAttribute("Score") == L.pieces[1])

---------------------------------------------------------------------------------------------------
-- 2. Fumbles and the filing gap
---------------------------------------------------------------------------------------------------
local m2 = mark(ada)
fileOne(ada, false)
local wrong = last(ada, "filed")
check("a wrong case is filed as wrong", wrong and wrong.correct == false)
check("a wrong case reports the fumble", wrong and wrong.fumble == L.fumble)
check("the rival hears about it", last(ben, "rivalFiled") ~= nil and last(ben, "rivalFiled").correct == false)
advance(0.2)
fileOne(ada, true)
check("filing during the fumble is rejected", last(ada, "rejected") ~= nil)
advance(L.fumble)
fileOne(ada, true)
local right = last(ada, "filed")
check("after the fumble a right case files", right and right.correct == true and right.remaining == L.pieces[1] - 1)
check("filed has the fields the client reads", fieldsPresent(right or {}, { "uid", "case", "correct", "score", "streak", "runLength", "multiplier", "remaining" }))
local lastFiledUid = right and right.uid
send(ada, { op = "file", uid = lastFiledUid, case = right and right.case })
advance(0.3)
local double = take(ada, "filed", m2)
check("a piece can't be filed twice", #double == 2)
send(ada, { op = "file", uid = 99999, case = dealA.cases[1] })
send(ada, { op = "file", uid = "x", case = 5 })
advance(0.3)
check("nonsense filings are ignored", #take(ada, "filed", m2) == 2)

---------------------------------------------------------------------------------------------------
-- 3. Parcels: a run of three sends one; defence cancels; the fuse opens the rest
---------------------------------------------------------------------------------------------------
-- Ada files runs; Ben does nothing, so parcels land on Ben.
clearFelt(ada, 0.25, 6)
local parcels = take(ben, "parcel")
check("a same-case run sends a parcel", #parcels >= 1, #parcels)
local p1 = parcels[1]
check("parcel has the fields the client reads", fieldsPresent(p1 or {}, { "from", "to", "id", "count", "fuse" }))
check("the parcel goes to the rival", p1 and p1.from == "a" and p1.to == "b")
check("the parcel has a 2 second fuse", p1 and p1.fuse == L.parcelFuse)
check("the sender sees their parcel go", #take(ada, "parcel") == #parcels)
local benBefore = 0
for _ in felt(ben) do
	benBefore += 1
end
advance(L.parcelFuse + 0.1)
local opened = take(ben, "parcelOpen")
check("the fuse runs out and the parcel opens", #opened >= 1)
check("parcelOpen has the fields the client reads", fieldsPresent(opened[1] or {}, { "side", "id", "pieces", "remaining" }))
local benAfter = 0
for _ in felt(ben) do
	benAfter += 1
end
check("lookalikes land on the receiver's felt", benAfter > benBefore, string.format("%d -> %d", benBefore, benAfter))
check("the receiver's count grows", opened[#opened] and opened[#opened].remaining == benAfter, opened[#opened] and opened[#opened].remaining)
local cases = dealA.cases
local lookalikesOpen = true
for _, m in opened do
	for _, p in m.pieces do
		if not table.find(cases, p.case) then
			lookalikesOpen = false
		end
	end
end
check("parcel pieces belong to open cases", lookalikesOpen)
check("the rival sees parcels open too", #take(ada, "parcelOpen") == #opened)

-- Defence: Ada sends one more parcel; Ben runs three of his own before the fuse and cancels it.
local m3 = mark(ben)
local m3a = mark(ada)
local incoming = {}
for _ = 1, 8 do
	clearFelt(ada, 0.25, 1)
	incoming = take(ben, "parcel", m3)
	if #incoming > 0 then
		break
	end
end
check("another parcel is on its way to Ben", #incoming >= 1, #incoming)
-- Ben answers fast with a run of three in one case.
local benPieces = felt(ben)
local counts = {}
for _, p in benPieces do
	counts[p.case] = (counts[p.case] or 0) + 1
end
local runCase
for c, n in counts do
	if n >= 3 and (runCase == nil or c < runCase) then
		runCase = c
	end
end
check("Ben has a case with three pieces for a run", runCase ~= nil)
for _ = 1, 3 do
	fileOne(ben, true, runCase)
	advance(0.2)
end
local cancelled = take(ben, "parcelCancel", m3)
local shrunk = take(ben, "parcelShrink", m3)
check("Ben's run cancels a waiting parcel", #cancelled + #shrunk >= 1, string.format("%d cancelled, %d shrunk", #cancelled, #shrunk))
check("the sender sees the cancel", #take(ada, "parcelCancel", m3a) == #cancelled)
check("a cancelled parcel never opens", (function()
	advance(L.parcelFuse + 0.2)
	for _, o in take(ben, "parcelOpen", m3) do
		for _, c in cancelled do
			if o.id == c.id then
				return false
			end
		end
	end
	return true
end)())

---------------------------------------------------------------------------------------------------
-- 4. The hand ends when a felt is clear; first to three hands
---------------------------------------------------------------------------------------------------
clearFelt(ada, 0.25)
local handEnd = last(ada, "handEnd")
check("clearing the felt wins the hand", handEnd and handEnd.winner == "a", handEnd and handEnd.winner)
check("handEnd has the fields the client reads", fieldsPresent(handEnd or {}, { "winner", "wins", "hand" }))
check("both guests see the hand end", last(ben, "handEnd") ~= nil)
check("wins are 1-0", handEnd and handEnd.wins.a == 1 and handEnd.wins.b == 0)
advance(0.5)
check("filings between hands do nothing", (function()
	local before = #take(ben, "filed")
	fileOne(ben, true)
	advance(0.3)
	return #take(ben, "filed") == before
end)())

local function playHand(winner, loser, expectHand)
	advance(L.betweenHands + 0.2)
	local d = last(winner, "deal")
	check("hand " .. expectHand .. " is dealt", d and d.round == expectHand, d and d.round)
	check("hand " .. expectHand .. " is " .. L.pieces[expectHand] .. " pieces", d and #d.pieces == L.pieces[expectHand], d and #d.pieces)
	check("hand " .. expectHand .. " opens " .. L.cases[expectHand] .. " cases", d and #d.cases == L.cases[expectHand])
	clearFelt(winner, 0.25)
end

playHand(ada, ben, 2)
check("wins are 2-0", last(ada, "handEnd").wins.a == 2)
local ratingBefore = profileFor(ada).duel.r
playHand(ada, ben, 3)
advance(2)
local endA, endB = last(ada, "duelEnd"), last(ben, "duelEnd")
check("three hands take the table", endA ~= nil and endA.won == true, endA and endA.won)
check("the loser hears it too", endB ~= nil and endB.won == false)
check("duelEnd has the fields the client reads", fieldsPresent(endA or {}, { "won", "wins", "reason", "ranked", "standIn", "rival", "gilt" }))
check("ranked: the winner's rating rises", profileFor(ada).duel.r > ratingBefore, profileFor(ada).duel.r)
check("ranked: the loser's rating falls", profileFor(ben).duel.r < 1500, profileFor(ben).duel.r)
check("ratings go to the board", ratingsSubmitted.Ada ~= nil and ratingsSubmitted.Ben ~= nil)
check("the result says before and after", endA and endA.before == 1500 and endA.after > 1500)
check("placement: the Mark stays hidden for the first five", endA and endA.markAfter == nil and endA.placementLeft == L.placementMatches - 1)
check("the winner is paid Gilt", profileFor(ada).gilt == L.giltWin and endA.gilt == L.giltWin)
check("the loser is paid a little", profileFor(ben).gilt == L.giltLoss)
check("wins and losses are counted", profileFor(ada).duel.wins == 1 and profileFor(ben).duel.losses == 1)
check("the house has a word for each", (function()
	local win, loss = false, false
	for _, s in said do
		if s.player == ada and string.find(s.line, "Well played") then
			win = true
		elseif s.player == ben and string.find(s.line, "Close") then
			loss = true
		end
	end
	return win and loss
end)())

---------------------------------------------------------------------------------------------------
-- 5. Another: one asks, the other is told; both ask, a new evening starts
---------------------------------------------------------------------------------------------------
clearInbox(ada, ben)
local benLossesBeforeSecond = profileFor(ben).duel.losses
local benRatingBeforeSecond = profileFor(ben).duel.r
send(ada, { op = "again" })
check("the rival is told someone wants another", last(ben, "rematchAsked") ~= nil and last(ben, "rematchAsked").by == "Ada")
send(ben, { op = "again" })
check("both asking starts another", last(ada, "duelStart") ~= nil and last(ben, "duelStart") ~= nil)
advance(2.6)
check("another hand I is dealt", last(ada, "deal") ~= nil and last(ada, "deal").round == 1)

---------------------------------------------------------------------------------------------------
-- 6. The hand cap: nobody clears; fewer pieces left takes it
---------------------------------------------------------------------------------------------------
-- Ada files two correctly; Ben files nothing. At the cap Ada has fewer left.
fileOne(ada, true)
advance(0.3)
fileOne(ada, true)
advance(L.handCap)
local capped = last(ada, "handEnd")
check("the hand cap ends the hand", capped ~= nil)
check("at the cap, fewer pieces left takes it", capped and capped.winner == "a", capped and capped.winner)

---------------------------------------------------------------------------------------------------
-- 7. Leaving mid-evening forfeits; the one left waits again
---------------------------------------------------------------------------------------------------
advance(L.betweenHands + 0.2)
clearInbox(ada, ben)
send(ben, { op = "leave" })
check("the leaver is told they've left", last(ben, "left") ~= nil)
local forfeit = last(ada, "duelEnd")
check("leaving hands the table to the other guest", forfeit and forfeit.won == true and forfeit.reason == "forfeit")
check("the leaver gets a loss", profileFor(ben).duel.losses == benLossesBeforeSecond + 1, profileFor(ben).duel.losses)
check("the leaver's rating takes the loss", profileFor(ben).duel.r < benRatingBeforeSecond, profileFor(ben).duel.r)
check("the one left waits for a new guest", last(ada, "duelWaiting") ~= nil)
check("the leaver is no longer seated", DuelService.isSeated(ben) == false)
check("the stayer is still seated", DuelService.isSeated(ada) == true)

---------------------------------------------------------------------------------------------------
-- 8. A Stand-in after waiting; never ranked; it plays to the end
---------------------------------------------------------------------------------------------------
clearInbox(ada)
advance(L.standInAt + 1)
check("the Concierge offers a Stand-in", #dialogues >= 1)
advance(1)
local standStart = last(ada, "duelStart")
check("a Stand-in sits opposite", standStart ~= nil and standStart.standIn == true, standStart and standStart.rival)
check("a Stand-in evening is never ranked", standStart and standStart.ranked == false)
check("the Stand-in is shown in the chair", l1b:FindFirstChild("StandIn") ~= nil)
local sitAgain, whyAgain = sit(newGuest("Dora", 4), l1b)
check("the Stand-in's chair can't be taken", sitAgain == false and whyAgain == "taken", whyAgain)
local ratingBeforeStandIn = profileFor(ada).duel.r
-- Ada idles; the Stand-in should clear its felt and win hands on its own.
advance(2.6)
local rivalFilings = 0
for _ = 1, 60 do
	advance(1)
	rivalFilings = #take(ada, "rivalFiled")
	if last(ada, "duelEnd") then
		break
	end
end
check("the Stand-in files pieces", rivalFilings > 0, rivalFilings)
-- Keep going until the evening ends (the Stand-in clears or the cap decides).
for _ = 1, 400 do
	if last(ada, "duelEnd") then
		break
	end
	advance(1)
end
local standEnd = last(ada, "duelEnd")
check("a Stand-in evening ends", standEnd ~= nil)
check("the Stand-in takes an idle guest's hands", standEnd and standEnd.won == false)
check("no rating moves against a Stand-in", profileFor(ada).duel.r == ratingBeforeStandIn)
check("the result says it wasn't ranked", standEnd and standEnd.ranked == false and standEnd.before == nil)
send(ada, { op = "again" })
check("Another against a Stand-in starts at once", last(ada, "duelStart") ~= nil and last(ada, "duelStart").standIn == true)
send(ada, { op = "leave" })
check("leaving a Stand-in evening clears the chair", l1b:FindFirstChild("StandIn") == nil)
check("the counters reset", l1a:GetAttribute("Score") == 0 and l1b:GetAttribute("Score") == 0)

---------------------------------------------------------------------------------------------------
-- 9. Declining the Stand-in; a guest who leaves the game while seated
---------------------------------------------------------------------------------------------------
dialogueChoice = "wait"
local eve = newGuest("Eve", 5)
sit(eve, l2a)
clearInbox(eve)
advance(L.standInAt + 2)
check("declining the Stand-in keeps the guest waiting", last(eve, "duelStart") == nil)
advance(L.standInAt + 2)
check("the offer is made only once per wait", (function()
	local n = 0
	for _, d in dialogues do
		if d.player == eve then
			n += 1
		end
	end
	return n == 1
end)())
local fay = newGuest("Fay", 6)
fay.AccountAge = 1
sit(fay, l2b)
local eveStart = last(eve, "duelStart")
check("a new account plays friendly, not ranked", eveStart and eveStart.ranked == false)
advance(3)
eve.Parent = nil
PlayersService.PlayerRemoving:Fire(eve)
check("a dropped connection holds the chair first", last(fay, "rivalAway") ~= nil and last(fay, "rivalAway").seconds == L.disconnectGrace)
check("no forfeit during the grace", last(fay, "duelEnd") == nil)
local fayFiled = #take(fay, "filed")
fileOne(fay, true)
advance(0.3)
check("the hand waits while the chair is held", #take(fay, "filed") == fayFiled)
advance(L.disconnectGrace + 0.5)
check("after the grace the evening is forfeit", last(fay, "duelEnd") ~= nil and last(fay, "duelEnd").reason == "forfeit" and last(fay, "duelEnd").won == true)
check("nothing is sent to a guest who has gone", last(eve, "duelEnd") == nil)
check("the one left waits again", last(fay, "duelWaiting") ~= nil)
fay.humanoid.Died:Fire()
check("a guest who falls is unseated", DuelService.isSeated(fay) == false)

---------------------------------------------------------------------------------------------------
-- 10. The queue: guests alone at different tables are paired by rating
---------------------------------------------------------------------------------------------------
local gus, hal = newGuest("Gus", 7), newGuest("Hal", 8)
profileFor(hal).duel.r = 1560
sit(gus, l1a)
advance(0.2)
sit(hal, l2a)
advance(1)
local moved = last(hal, "left")
check("the later guest is shown across", moved ~= nil and moved.moving == true)
check("they're seated opposite the first", (last(hal, "seated") or {}).table == "library-1b", (last(hal, "seated") or {}).table)
check("the paired evening is ranked", last(hal, "duelStart") ~= nil and last(hal, "duelStart").ranked == true and last(gus, "duelStart").rival == "Hal")
check("the house explains the move", (function()
	for _, s in said do
		if s.player == hal and string.find(s.line, "other table") then
			return true
		end
	end
	return false
end)())
gus.side, hal.side = "a", "b"
advance(2.6)
check("ranked: a provisional loss is written at the start", profileFor(gus).duel.losses == 1 and profileFor(gus).duel.r < 1500)
-- Hal's connection drops for good: forfeit after the grace, and the loss stands.
hal.Parent = nil
PlayersService.PlayerRemoving:Fire(hal)
advance(L.disconnectGrace + 0.5)
local gusEnd = last(gus, "duelEnd")
check("a ranked dropout is forfeit after the grace", gusEnd ~= nil and gusEnd.won == true and gusEnd.reason == "forfeit")
check("the winner's provisional loss is undone", profileFor(gus).duel.losses == 0 and profileFor(gus).duel.wins == 1 and profileFor(gus).duel.r > 1500)
check("the dropout keeps the loss", profileFor(hal).duel.losses == 1 and profileFor(hal).duel.r < 1560)
send(gus, { op = "leave" })

-- Far apart: they wait until the window has widened enough.
local ivy, jon = newGuest("Ivy", 10), newGuest("Jon", 11)
profileFor(jon).duel.r = 1880
sit(ivy, l1a)
sit(jon, l2a)
advance(6)
check("guests far apart aren't paired at first", last(jon, "duelStart") == nil and last(ivy, "duelStart") == nil)
advance(25)
check("the widened window pairs them", last(jon, "duelStart") ~= nil and last(ivy, "duelStart") ~= nil)
send(ivy, { op = "leave" })
send(jon, { op = "leave" })
advance(0.5)

---------------------------------------------------------------------------------------------------
-- 11. Invite to the Library: the chair is kept; the friend is seated opposite, friendly
---------------------------------------------------------------------------------------------------
local kim, lou = newGuest("Kim", 12), newGuest("Lou", 13)
kim.side, lou.side = "a", "b"
local offersBefore = #dialogues
sit(kim, l2a)
send(kim, { op = "inviting" })
local mia = newGuest("Mia", 14)
sit(mia, l1a)
advance(L.standInAt + 6)
check("an inviting guest isn't offered a Stand-in", (function()
	for i = offersBefore + 1, #dialogues do
		if dialogues[i].player == kim then
			return false
		end
	end
	return true
end)())
check("an inviting guest isn't paired by the queue", last(kim, "duelStart") == nil)
send(mia, { op = "leave" })
local joined = false
run(function()
	joined = DuelService.joinFriend(lou, kim.UserId)
end)
advance(0.2)
check("the invited friend is seated opposite", joined and (last(lou, "seated") or {}).table == "library-2b")
check("an invited evening is friendly", last(lou, "duelStart") ~= nil and last(lou, "duelStart").ranked == false)
check("an invite to someone not waiting is refused", (function()
	local r
	run(function()
		r = DuelService.joinFriend(newGuest("Ned", 15), 99)
	end)
	return r == false
end)())

---------------------------------------------------------------------------------------------------
-- 12. Back within the grace: seated again, the hand resumes
---------------------------------------------------------------------------------------------------
advance(2.6)
check("the invited evening deals", last(lou, "deal") ~= nil)
fileOne(lou, true)
advance(0.3)
local louLeft = last(lou, "filed").remaining
lou.Parent = nil
PlayersService.PlayerRemoving:Fire(lou)
advance(5)
local lou2 = newGuest("Lou", 13)
lou2.side = "b"
PlayersService.PlayerAdded:Fire(lou2)
advance(1.5)
check("back in time, the guest is seated again", (last(lou2, "seated") or {}).table == "library-2b")
check("the evening is sent again", last(lou2, "duelStart") ~= nil and last(lou2, "deal") ~= nil)
check("the felt is as they left it", last(lou2, "deal") and #last(lou2, "deal").pieces == louLeft, last(lou2, "deal") and #last(lou2, "deal").pieces)
check("the rival is told they're back", last(kim, "rivalBack") ~= nil)
local before2 = #take(lou2, "filed")
fileOne(lou2, true)
advance(0.3)
check("the hand carries on", #take(lou2, "filed") == before2 + 1)
check("the evening wasn't forfeit", last(kim, "duelEnd") == nil)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end

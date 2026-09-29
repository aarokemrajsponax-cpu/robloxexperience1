--!nocheck
-- Plays whole Lights Out evenings against the real BallroomService under Lune, on a fake clock:
-- guests gathering, Stand-ins in the empty chairs, the dumbwaiter speeding up, filings and
-- fumbles, parcels by tab and their defence, felts flickering and lamps going out, Keys, a whole
-- evening to the last lamp, and the next evening. Every message a client would get is recorded
-- and checked for the fields the client reads.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/ballroom.luau

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
	local root = {
		Position = Vector3.new(0, 0, 0),
		IsA = function(_, class)
			return class == "BasePart" or class == "Part"
		end,
	}
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
-- The Ballroom: twenty tables, each with a chair and a lamp; the room's lights; the board
---------------------------------------------------------------------------------------------------
local tagged = { BallroomTable = {}, MaisonTable = {} }
local seatAt = {}
local lamps = {}
local ballroom = Instance.new("Model")
ballroom.Name = "Ballroom"
local tablesFolder = Instance.new("Folder")
tablesFolder.Name = "Tables"
tablesFolder.Parent = ballroom
for i = 1, 20 do
	local m = Instance.new("Model")
	m.Name = "BallroomTable" .. i
	m:SetAttribute("Ballroom", true)
	m:SetAttribute("Seat", i)
	m:SetAttribute("TableId", "ballroom-" .. i)
	local seat = Instance.new("Seat")
	seat.Name = "Chair"
	local angle = (i - 1) / 20 * math.pi * 2
	local pos = Vector3.new(61 + math.cos(angle) * 53, 22, 125 + math.sin(angle) * 53)
	seat.CFrame = CFrame.new(pos)
	seat.Position = pos
	seat.Parent = m
	seatAt[i] = pos
	local bulb = Instance.new("Part")
	bulb.Name = "Bulb"
	bulb.Parent = m
	local light = Instance.new("SpotLight")
	light.Name = "TableLight"
	light.Brightness = 1.8
	light.Parent = bulb
	lamps[i] = light
	m.Parent = tablesFolder
	table.insert(tagged.BallroomTable, m)
	table.insert(tagged.MaisonTable, m)
end
local chandelier = Instance.new("Part")
chandelier.Parent = ballroom
local chandelierLight = Instance.new("PointLight")
chandelierLight:SetAttribute("BallroomAmbient", 1.3)
chandelierLight.Brightness = 1.3
chandelierLight.Parent = chandelier
local boardPart = Instance.new("Part")
boardPart:SetAttribute("EveningBoard", true)
boardPart.Parent = ballroom
local boardGui = Instance.new("SurfaceGui")
boardGui.Parent = boardPart
local boardLines = {}
for i = 1, 2 do
	local l = Instance.new("TextLabel")
	l.LayoutOrder = i
	l.Parent = boardGui
	boardLines[i] = l
end

---------------------------------------------------------------------------------------------------
-- Stubs for the server modules around the Ballroom (the shared rules load for real)
---------------------------------------------------------------------------------------------------
local profiles = {}
local function profileFor(player)
	local data = profiles[player]
	if not data then
		data = { gilt = 0, giltDay = { day = -1, earned = 0 } }
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
local guests = {}
PlayersService.GetPlayers = function()
	local out = {}
	for _, g in guests do
		if g.Parent == PlayersService then
			table.insert(out, g)
		end
	end
	return out
end

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

local finished = {}
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
		return { custom = function() end, step = function() end, source = function() end }
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

local tweens = 0
local services = {
	Players = PlayersService,
	CollectionService = {
		GetTagged = function(_, tag)
			return tagged[tag] or {}
		end,
	},
	TweenService = {
		Create = function(_, instance, _info, goal)
			return {
				Play = function()
					tweens += 1
					for k, v in goal do
						instance[k] = v
					end
				end,
			}
		end,
	},
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

local globals = {
	Instance = Instance,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	Color3 = roblox.Color3,
	Enum = Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Random = Random,
	TweenInfo = {
		new = function(t)
			return { Time = t }
		end,
	},
	task = taskShim,
	game = gameShim,
	os = fakeOs,
	warn = function(...)
		print("warn:", ...)
	end,
}

local sources = {}
local function preload(node)
	for _, f in node.filePaths or {} do
		if string.find(f, "%.luau$") then
			sources[f] = fs.readFile(f)
		end
	end
	for _, c in node.children or {} do
		preload(c)
	end
end
preload(sourcemap)

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
	local fn = luau.load(sources[path] or fs.readFile(path), { debugName = path, environment = env, injectGlobals = true })
	local result = fn()
	cache[node] = result
	return result
end

module("ReplicatedStorage", "Shared", "Seasons")
local Config = module("ReplicatedStorage", "Shared", "Config")
local C = Config.data.Ballroom
local Catalogue = module("ReplicatedStorage", "Shared", "Catalogue")
local BallroomService = module("ServerScriptService", "Server", "BallroomService")
local said = {}
BallroomService.say = function(player, line)
	table.insert(said, { player = player, line = line })
end
BallroomService.onFinished = function(player, place, keys, counted)
	table.insert(finished, { player = player, place = place, keys = keys, counted = counted })
end
local results = {}
BallroomService.onResult = function(n, name, keys)
	table.insert(results, { n = n, name = name, keys = keys })
end
BallroomService.start(function()
	return false
end)

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
local function last(player, op)
	local list = take(player, op)
	return list[#list]
end
local function mark(player): number
	return #player.inbox
end
local function guest(name, id)
	local g = newGuest(name, id)
	table.insert(guests, g)
	return g
end
local function sit(player, i)
	player.root.Position = seatAt[i] + Vector3.new(0, 0, 2)
	local r
	run(function()
		r = table.pack(BallroomService.sit(player, tagged.BallroomTable[i], function()
			return false
		end))
	end)
	advance(0.1)
	return r[1], r[2]
end
local function send(player, message)
	tableEvent.OnServerEvent:Fire(player, message)
end
-- The guest's felt, rebuilt from what they were sent.
local function felt(player)
	local pieces = {}
	for _, m in player.inbox do
		if m.op == "deal" then
			pieces = {}
			for _, p in m.pieces do
				pieces[p.uid] = p
			end
		elseif m.op == "arrive" or (m.op == "parcelOpen" and m.side == "mine") then
			for _, p in m.pieces do
				pieces[p.uid] = p
			end
		elseif m.op == "filed" and m.correct then
			pieces[m.uid] = nil
		end
	end
	return pieces
end
local function count(t)
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end
local function oldest(pieces, case)
	local best
	for uid, p in pieces do
		if (case == nil or p.case == case) and (best == nil or uid < best.uid) then
			best = p
		end
	end
	return best
end
local function fieldsPresent(message, fields)
	for _, f in fields do
		if message[f] == nil then
			return false, f
		end
	end
	return true
end

---------------------------------------------------------------------------------------------------
-- 1. The first guest sits: the evening gathers
---------------------------------------------------------------------------------------------------
local ada = guest("Ada", 1)
local ok = sit(ada, 1)
check("a guest sits at a Ballroom table", ok == true)
local seated = last(ada, "seated")
check("seated says ballroom", seated and seated.mode == "ballroom" and seated.room == "ballroom" and seated.table == "ballroom-1")
local gathering = last(ada, "gathering")
check("the evening gathers for 30 s", gathering and math.abs(gathering.startsIn - C.gatherSeconds) < 0.5, gathering and gathering.startsIn)
advance(1)
check("the board counts down", string.find(boardLines[2].Text, "begins in", 1, true) ~= nil, boardLines[2].Text)
local ben = guest("Ben", 2)
sit(ben, 2)
check("a second guest joins the gathering", last(ben, "gathering") ~= nil and last(ben, "gathering").startsIn < C.gatherSeconds)
local okTaken, whyTaken = sit(guest("Cleo", 3), 1)
check("a taken chair is refused", okTaken == false and whyTaken == "taken", whyTaken)
check("a far guest can't sit", (function()
	local far = guest("Far", 90)
	local r
	run(function()
		r = table.pack(BallroomService.sit(far, tagged.BallroomTable[5], function()
			return false
		end))
	end)
	return r[1] == false and r[2] == "far"
end)())

---------------------------------------------------------------------------------------------------
-- 2. The evening begins: Stand-ins fill the chairs; the same six pieces on every felt
---------------------------------------------------------------------------------------------------
advance(C.gatherSeconds)
local start = last(ada, "eveningStart")
check("the evening begins", start ~= nil)
check("eveningStart has the fields the client reads", fieldsPresent(start or {}, { "seat", "names", "capacity", "tab", "counted", "real" }))
check("two real guests: not counted for records", start and start.counted == false and start.real == 2)
local standIns = 0
for _, m in tagged.BallroomTable do
	if m:FindFirstChild("StandIn") then
		standIns += 1
	end
end
check("Stand-ins fill the other eighteen chairs", standIns == 18, standIns)
local dealA, dealB = last(ada, "deal"), last(ben, "deal")
check("the opening deal is six pieces", dealA and #dealA.pieces == C.openingDeal)
check("deal has the fields the client reads", fieldsPresent(dealA or {}, { "mode", "room", "round", "cases", "pieces", "score" }))
local same = dealA ~= nil and dealB ~= nil
if same then
	for i, p in dealA.pieces do
		if dealB.pieces[i].id ~= p.id then
			same = false
		end
	end
end
check("the same pieces on every felt", same)
check("five cases are open", dealA and #dealA.cases == C.casesOpen)
check("the counter shows the felt", tagged.BallroomTable[1]:GetAttribute("Score") == C.openingDeal)

---------------------------------------------------------------------------------------------------
-- 3. The dumbwaiter: steady, then faster; the same piece arrives on every felt
---------------------------------------------------------------------------------------------------
local m3 = mark(ada)
advance(C.paceStart + 0.05)
local arrA, arrB = take(ada, "arrive", m3), take(ben, "arrive")
check("a piece arrives after 1.6 s", #arrA == 1, #arrA)
check("arrive has the fields the client reads", fieldsPresent(arrA[1] or {}, { "pieces", "remaining" }))
check("it's the same piece on every felt", arrA[1] and arrB[#arrB] and arrA[1].pieces[1].id == arrB[#arrB].pieces[1].id)
local m3b = mark(ada)
advance(11)
local early = #take(ada, "arrive", m3b)
check("steady at one every 1.6 s", early >= 6 and early <= 7, early)

---------------------------------------------------------------------------------------------------
-- 4. Filing and fumbling; parcels by tab; the lamp flickers and goes out
---------------------------------------------------------------------------------------------------
local p1 = oldest(felt(ada))
send(ada, { op = "file", uid = p1.uid, case = p1.case })
local filed = last(ada, "filed")
check("a right case files", filed and filed.correct and filed.uid == p1.uid)
check("filed has the fields the client reads", fieldsPresent(filed or {}, { "uid", "case", "correct", "score", "streak", "runLength", "multiplier", "remaining", "keys" }))
advance(0.2)
local p2 = oldest(felt(ada))
local wrongCase = (function()
	for _, c in dealA.cases do
		if c ~= p2.case then
			return c
		end
	end
end)()
send(ada, { op = "file", uid = p2.uid, case = wrongCase })
check("a wrong case fumbles for 0.6 s", last(ada, "filed").correct == false and last(ada, "filed").fumble == C.fumble)
advance(0.2)
send(ada, { op = "file", uid = p2.uid, case = p2.case })
check("filing during the fumble is rejected", last(ada, "rejected") ~= nil)
advance(0.6)

-- Ben idles and aims at the fullest felt; Ada aims at Ben's (the fullest, since he idles).
send(ben, { op = "tab", tab = "nearlyOut" })
check("a tab can be chosen", last(ben, "tab") and last(ben, "tab").tab == "nearlyOut")
send(ada, { op = "tab", tab = "bogus" })
check("an unknown tab is ignored", last(ada, "tab") == nil)
send(ada, { op = "tab", tab = "nearlyOut" })

-- Ada keeps her felt clear, filing runs of one case when she can.
local function play(player, gap)
	local pieces = felt(player)
	local lastFiled = last(player, "filed")
	local prefer = if lastFiled and lastFiled.correct then lastFiled.case else nil
	local p = oldest(pieces, prefer) or oldest(pieces)
	if p then
		send(player, { op = "file", uid = p.uid, case = p.case })
	end
	advance(gap)
end
local benOut = nil
local parcelsFromAda = 0
for _ = 1, 400 do
	play(ada, 0.25)
	benOut = last(ben, "out")
	if benOut then
		break
	end
end
for _, m in ada.inbox do
	if m.op == "parcel" and m.from == 1 then
		parcelsFromAda += 1
	end
end
check("Ada's runs send parcels", parcelsFromAda > 0, parcelsFromAda)
check("parcel has the fields the client reads", fieldsPresent(last(ada, "parcel") or {}, { "from", "to", "id", "count", "fuse" }))
check("an idle felt flickers first", last(ben, "flicker") ~= nil)
check("then Ben's lamp goes out", benOut ~= nil)
check("out has the fields the client reads", fieldsPresent(benOut or {}, { "place", "keys", "reason", "of" }))
check("his place is counted from the back", benOut and benOut.place >= 2 and benOut.place <= 20, benOut and benOut.place)
check("his lamp is dark", lamps[2].Brightness == 0)
check("the table says it's out", tagged.BallroomTable[2]:GetAttribute("Out") == true)
local out = last(ada, "lampOut")
check("everyone hears which lamp went out", out ~= nil and fieldsPresent(out, { "seat", "place", "alive" }))
check("the room grows darker", chandelierLight.Brightness < 1.3)

---------------------------------------------------------------------------------------------------
-- 5. Ada plays on to the last lamp
---------------------------------------------------------------------------------------------------
local ended
for _ = 1, 4000 do
	play(ada, 0.2)
	ended = last(ada, "eveningEnd")
	if ended or last(ada, "out") then
		break
	end
end
local adaOut = last(ada, "out")
check("Ada keeps her lamp to the end", adaOut == nil, adaOut and adaOut.place)
check("the evening ends", ended ~= nil)
check("eveningEnd has the fields the client reads", fieldsPresent(ended or {}, { "winner", "winnerName", "keys", "seconds", "counted", "results" }))
check("Ada keeps the last lamp", ended and ended.winner == 1 and ended.winnerName == "Ada")
check("an evening lasts minutes, not seconds", ended and ended.seconds > 120, ended and ended.seconds)
print(string.format("  (the evening lasted %d s, %d Keys to the winner)", ended and ended.seconds or 0, ended and ended.keys or 0))
local result = last(ada, "eveningResult")
check("the result card says first", result and result.place == 1 and result.won == true)
check("eveningResult has the fields the client reads", fieldsPresent(result or {}, { "place", "of", "keys", "points", "gilt", "counted", "won" }))
check("the winner is paid Gilt", result and result.gilt == C.giltBase + C.giltTopFive + C.giltWin)
check("the Concierge says the last lamp is yours", (function()
	for _, s in said do
		if s.player == ada and string.find(s.line, "last lamp") then
			return true
		end
	end
	return false
end)())
check("the whole room is dark but her lamp", lamps[1].Brightness > 2 and lamps[5].Brightness == 0 and chandelierLight.Brightness == 0)
check("the result goes to the other servers", #results == 1 and results[1].n == 1)
check("records are told it didn't count", #finished >= 1 and finished[#finished].counted == false)
local placeSet = {}
for _, r in ended.results do
	placeSet[r.place] = true
end
check("twenty places, one each", count(placeSet) == 20)

---------------------------------------------------------------------------------------------------
-- 6. The next evening: the winner stays; a guest who asked is seated
---------------------------------------------------------------------------------------------------
local cleo = guest("Cleo", 4)
cleo.root.Position = Vector3.new(61, 32, 72)
send(cleo, { op = "nextEvening" })
check("mid-evening, a guest is queued for the next", last(cleo, "queued") ~= nil)
local m6 = mark(ada)
advance(C.afterEvening + 0.5)
check("the room lights come back", chandelierLight.Brightness > 1)
check("the Stand-ins leave", (function()
	for _, m in tagged.BallroomTable do
		if m:FindFirstChild("StandIn") then
			return false
		end
	end
	return true
end)())
check("the winner's next evening gathers", #take(ada, "gathering", m6) >= 1)
check("the queued guest is seated", last(cleo, "seated") ~= nil and BallroomService.isSeated(cleo))
local okMid, whyMid = sit(guest("Dora", 5), 7)
check("during a gathering, anyone can take a chair", okMid == true, whyMid)

---------------------------------------------------------------------------------------------------
-- 7. With no real guest left lit, the evening ends at once (fast re-entry)
---------------------------------------------------------------------------------------------------
advance(C.gatherSeconds + 0.5)
check("the second evening begins", last(cleo, "eveningStart") ~= nil)
local m7 = mark(ada)
send(ada, { op = "leave" })
send(cleo, { op = "leave" })
local dora = guests[#guests]
send(dora, { op = "leave" })
-- Ben went out in the first evening but stayed in his chair, so he's in this one too.
check("a guest whose lamp went out stays seated for the next evening", last(ben, "eveningStart") ~= nil and #take(ben, "eveningStart") == 2)
send(ben, { op = "leave" })
check("leaving mid-evening puts your lamp out", last(ada, "out") ~= nil and last(ada, "out").reason == "left")
advance(0.5)
check("with nobody real left lit, the evening ends", #take(ada, "eveningEnd", m7) >= 1 or BallroomService.evening() == nil or BallroomService.evening().state ~= "playing")
advance(C.afterEvening + 1)
check("an empty room goes quiet", BallroomService.evening() == nil)
check("the board says to take any chair", string.find(boardLines[2].Text, "Take any chair", 1, true) ~= nil, boardLines[2].Text)

---------------------------------------------------------------------------------------------------
-- 8. A full house counts for records
---------------------------------------------------------------------------------------------------
local house = {}
for i = 1, 8 do
	local g = guest("Guest" .. i, 100 + i)
	sit(g, i)
	table.insert(house, g)
end
advance(C.gatherSeconds + 0.5)
check("eight real guests: the evening counts", last(house[1], "eveningStart") and last(house[1], "eveningStart").counted == true)
for _, g in house do
	send(g, { op = "leave" })
end
advance(1)
check("leavers are recorded with a counted evening", finished[#finished].counted == true)
advance(C.afterEvening + 1)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end

--!nocheck
-- The test house for the money: the real Shop, Ledger, Dressing and purchase system (server
-- Purchases) under Lune, on a fake clock, with Roblox's services faked just enough: the
-- marketplace (prompts, receipts, prices, passes, developer products by name), saved profiles that
-- save on a delay like ProfileStore (and can be made to fail), DataStores, the text filter, chat
-- permissions and country lookups. Used by tests/shop.luau and tests/purchases.luau.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Instance, Vector3, Enum, CFrame = roblox.Instance, roblox.Vector3, roblox.Enum, roblox.CFrame

local H = {}
H.savesWork = true -- false: profile saves never land (a DataStore outage)
H.saveDelay = 0.3 -- seconds a profile save takes to land

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
		FindFirstChild = function()
			return nil
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
		attrs = {},
		SetAttribute = function(self, k, v)
			self.attrs[k] = v
		end,
		GetAttribute = function(self, k)
			return self.attrs[k]
		end,
	}
end

roblox.implementMethod("Seat", "Sit", function(self, h)
	h.SeatPart = self
end)

---------------------------------------------------------------------------------------------------
-- Roblox's marketplace, and saved profiles that save on a delay (like ProfileStore)
---------------------------------------------------------------------------------------------------
local prompts = {}
local productPrices = {}
local passOwners = {}
local subscribers = {}
local MarketplaceService = {
	PromptGamePassPurchaseFinished = signal(),
	PromptProductPurchaseFinished = signal(),
	PromptProductPurchase = function(_, player, id)
		table.insert(prompts, { player = player, id = id, kind = "product" })
	end,
	PromptGamePassPurchase = function(_, player, id)
		table.insert(prompts, { player = player, id = id, kind = "pass" })
	end,
	GetProductInfo = function(_, id)
		return { PriceInRobux = productPrices[id] }
	end,
	UserOwnsGamePassAsync = function(_, userId, id)
		return passOwners[userId .. ":" .. id] == true
	end,
	GetUserSubscriptionStatusAsync = function(_, player, id)
		return { IsSubscribed = subscribers[player.UserId .. ":" .. id] == true, IsRenewing = true }
	end,
	GetSubscriptionProductInfoAsync = function(_, _id)
		return { DisplayPrice = "$4.99" }
	end,
	PromptSubscriptionPurchase = function(_, player, id)
		table.insert(prompts, { player = player, id = id, kind = "subscription" })
	end,
	-- The experience's developer products, as Roblox lists them (filled in by the tests below).
	devProducts = {},
	-- Regional pricing: each guest's price level (1000 = full price unless a test says otherwise);
	-- `priceLevelsDown` makes Roblox fail to answer.
	priceLevels = {},
	priceLevelsDown = false,
	GetUsersPriceLevelsAsync = function(self, ids)
		if self.priceLevelsDown then
			error("price levels unavailable (test)")
		end
		local out = {}
		for _, id in ids do
			table.insert(out, { UserId = id, PriceLevel = self.priceLevels[id] or 1000 })
		end
		return out
	end,
	GetDeveloperProductsAsync = function(self)
		local list = self.devProducts
		return {
			IsFinished = true,
			GetCurrentPage = function()
				return list
			end,
			AdvanceToNextPageAsync = function() end,
		}
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
PlayersService.GetPlayerByUserId = function(_, id)
	for _, g in guests do
		if g.UserId == id and g.Parent == PlayersService then
			return g
		end
	end
	return nil
end

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end

local profiles = {}
local loadedSignal = signal()
local function newProfile(player, template)
	local data = deepCopy(template)
	data.firstVisit = os.time() - 86400
	local p = {
		Data = data,
		LastSavedData = deepCopy(data),
		OnAfterSave = signal(),
		active = true,
	}
	function p:IsActive()
		return self.active
	end
	function p:Save()
		if not H.savesWork then
			return
		end
		taskShim.delay(H.saveDelay, function()
			self.LastSavedData = deepCopy(self.Data)
			self.OnAfterSave:Fire(self.LastSavedData)
		end)
	end
	profiles[player] = p
	return p
end

---------------------------------------------------------------------------------------------------
-- Module loading
---------------------------------------------------------------------------------------------------
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


local shopEvents = {}
local broadcasts = {}
local customEvents = {}
local stubs = {
	["ReplicatedStorage.Shared.Remotes"] = function()
		local funcs = {}
		local events = {}
		return {
			event = function(name)
				if events[name] then
					return events[name]
				end
				events[name] = {
					FireClient = function(_, player, message)
						table.insert(player.inbox, message)
					end,
					FireAllClients = function(_, message)
						table.insert(broadcasts, { remote = name, message = message })
					end,
					OnServerEvent = signal(),
				}
				return events[name]
			end,
			func = function(name)
				funcs[name] = funcs[name] or {}
				return funcs[name]
			end,
			funcs = funcs,
		}
	end,
	["ServerScriptService.Server.Analytics"] = function()
		return {
			custom = function(player, name, value, fields)
				table.insert(customEvents, { player = player, name = name, value = value, fields = fields })
			end,
			step = function() end,
			stamp = function()
				return nil
			end,
			source = function() end,
			sink = function() end,
		}
	end,
	["ServerScriptService.Server.Profiles"] = function()
		return {
			get = function(player)
				local p = profiles[player]
				return if p and p.active then p.Data else nil
			end,
			profile = function(player)
				local p = profiles[player]
				return if p and p.active then p else nil
			end,
			wait = function(player)
				local p = profiles[player]
				return if p then p.Data else nil
			end,
			isMock = function()
				return false
			end,
			Loaded = loadedSignal,
		}
	end,
	["ServerScriptService.Server.Season"] = function()
		return {
			current = function()
				return module("ReplicatedStorage", "Shared", "Seasons").byId.harvest
			end,
		}
	end,
}

local mythicCounts = {}
local memoryMaps = {}
local awarded = {}
local dataStores, orderedStores, guidCount = {}, {}, 0
local published, subscriptions, teleports = {}, {}, {}
local services = {
	Players = PlayersService,
	MarketplaceService = MarketplaceService,
	DataStoreService = {
		GetDataStore = function(_, name)
			local data = if name == "MaisonNoir_Mythics" then mythicCounts else (dataStores[name] or {})
			dataStores[name] = data
			return {
				-- As on Roblox: returning nil cancels the write, and UpdateAsync returns nil. A
				-- test can make a store fail (H.storeFault(name, key, old) returning true).
				UpdateAsync = function(_, key, fn)
					if H.storeFault and H.storeFault(name, key, data[key]) then
						error("DataStore request failed (test)")
					end
					local new = fn(data[key])
					if new == nil then
						return nil
					end
					data[key] = new
					return new
				end,
				GetAsync = function(_, key)
					if H.storeFault and H.storeFault(name, key, data[key]) then
						error("DataStore request failed (test)")
					end
					return data[key]
				end,
				SetAsync = function(_, key, value)
					data[key] = value
				end,
				RemoveAsync = function(_, key)
					data[key] = nil
				end,
			}
		end,
		GetOrderedDataStore = function(_, name)
			local data = orderedStores[name] or {}
			orderedStores[name] = data
			return {
				SetAsync = function(_, key, value)
					data[key] = value
				end,
				GetSortedAsync = function(_, _ascending, size)
					local rows = {}
					for k, v in data do
						table.insert(rows, { key = k, value = v })
					end
					table.sort(rows, function(x, y)
						return x.value > y.value
					end)
					while #rows > size do
						table.remove(rows)
					end
					return { GetCurrentPage = function()
						return rows
					end }
				end,
			}
		end,
	},
	HttpService = {
		GenerateGUID = function()
			guidCount += 1
			return string.format("%08x-0000-0000-0000-000000000000", guidCount)
		end,
	},
	MemoryStoreService = {
		GetSortedMap = function(_, name)
			memoryMaps[name] = memoryMaps[name] or {}
			local m = memoryMaps[name]
			return {
				UpdateAsync = function(_, key, fn)
					local value, sortKey = fn(m[key] and m[key].value, m[key] and m[key].sortKey)
					m[key] = { key = key, value = value, sortKey = sortKey }
				end,
				GetSizeAsync = function()
					local n = 0
					for _ in m do
						n += 1
					end
					return n
				end,
				GetRangeAsync = function(_, _dir, count)
					local list = {}
					for _, v in m do
						table.insert(list, v)
					end
					table.sort(list, function(a, b)
						return a.sortKey > b.sortKey
					end)
					local out = {}
					for i = 1, math.min(count, #list) do
						out[i] = list[i]
					end
					return out
				end,
			}
		end,
	},
	Workspace = (function()
		local dm = roblox.Instance.new("DataModel")
		return dm:GetService("Workspace")
	end)(),
	MessagingService = {
		PublishAsync = function(_, topic, message)
			table.insert(published, { topic = topic, message = message })
		end,
		SubscribeAsync = function(_, topic, fn)
			subscriptions[topic] = fn
		end,
	},
	TeleportService = {
		TeleportAsync = function(_, placeId, players, options)
			table.insert(teleports, { placeId = placeId, players = players, jobId = options and options.ServerInstanceId })
		end,
	},
	-- Where Roblox places each guest (by UserId; "US" unless a test says otherwise).
	LocalizationService = {
		regions = {},
		GetCountryRegionForPlayerAsync = function(self, player)
			return self.regions[player.UserId] or "US"
		end,
	},
	-- Whether each guest's account may chat (true unless a test says otherwise).
	TextChatService = {
		muted = {},
		CanUserChatAsync = function(self, userId)
			return not self.muted[userId]
		end,
	},
	TextService = {
		FilterStringAsync = function(_, text)
			return {
				GetNonChatStringForBroadcastAsync = function()
					return (string.gsub(text, "rude", "####"))
				end,
			}
		end,
	},
	BadgeService = {
		AwardBadge = function(_, userId, id)
			table.insert(awarded, { userId = userId, id = id })
		end,
	},
	CollectionService = {
		GetTagged = function()
			return {}
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

-- Wall-clock time runs with the fake clock (the Ledger's Term and the Boutique's day read it).
local startTime = os.time({ year = 2026, month = 10, day = 7, hour = 12 })
local fakeOs = setmetatable({
	clock = function()
		return now
	end,
	time = function(t)
		if t then
			return os.time(t)
		end
		return startTime + math.floor(now)
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
	Font = {
		new = roblox.Font.new,
		fromName = roblox.Font.fromName,
		fromEnum = function(e)
			local ok, f = pcall(roblox.Font.fromEnum, e)
			return if ok then f else roblox.Font.new("rbxasset://fonts/families/BuilderSans.json")
		end,
	},
	Random = Random,
	TweenInfo = {
		new = function(t)
			return { Time = t }
		end,
	},
	task = taskShim,
	game = gameShim,
	workspace = { FindFirstChild = function() return nil end },
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

---------------------------------------------------------------------------------------------------
-- The house's money
---------------------------------------------------------------------------------------------------
module("ReplicatedStorage", "Shared", "Seasons")
local Config = module("ReplicatedStorage", "Shared", "Config")
local Wardrobe = module("ReplicatedStorage", "Shared", "Wardrobe")
local Boutique = module("ReplicatedStorage", "Shared", "Boutique")
local Remotes = module("ReplicatedStorage", "Shared", "Remotes")
local Gilt = module("ServerScriptService", "Server", "Gilt")
local LedgerService = module("ServerScriptService", "Server", "LedgerService")
-- The tests set up their own products: start from a house with no ids pasted (the ids that ship
-- are kept in H.shippedIds, for the tests that check them).
H.shippedIds = {}
for key in module("ReplicatedStorage", "Shared", "ProductConfig").byKey do
	if type(Config.data.Products[key]) == "number" then
		H.shippedIds[key] = Config.data.Products[key]
		Config.data.Products[key] = 0
	end
end
local Shop = module("ServerScriptService", "Server", "Shop")
local handovers = {}
Shop.handOver = function(player, from, itemName)
	table.insert(handovers, { player = player, from = from, item = itemName })
end
Shop.start()
-- Every Robux purchase goes through the purchase system (receipts, the ledger, the products).
local Purchases = module("ServerScriptService", "Server", "Purchases")
Purchases.start()
module("ServerScriptService", "Server", "RemoteGuard").start()
local ask = Remotes.funcs.ShopAsk.OnServerInvoke

local TEMPLATE = {
	visits = 1, firstVisit = 0, nights = { count = 1, lastDay = -1 }, settings = {}, flags = {}, register = {},
	stats = { runs = 0, rounds = 0, filings = 0, correct = 0, flawless = 0, nightlies = 0 },
	duel = { r = 1500, rd = 350, vol = 0.06, matches = 0, wins = 0, losses = 0, termMatches = 0, term = "", best = 0, recent = {} },
	gilt = 0, giltDay = { day = -1, earned = 0 }, purchases = {},
	owned = {}, equipped = { look = "", table = "", lamp = "", chime = "", trail = "", nameplate = "", card = "", flourish = "", gesture = "" },
	credits = {}, receipts = {}, pending = { product = "", item = "", giftTo = 0, at = 0 },
	goldKey = false, introduction = false, blackCard = { active = false, months = {} }, suite = {}, circle = { id = "", week = -1, points = 0 },
	memory = { lastSeen = 0, highlight = "", highlightAt = 0, tables = {}, admired = 0, admiredSince = 0, signedDay = -1 },
	ledger = { term = "", points = 0, freeClaimed = 0, leatherClaimed = 0, leather = {} },
	gifts = {},
	perks = { credits = {}, luck = { remaining = 0 }, velocity = false, velocityPass = false, rains = {} },
	risk = { regions = {}, purchases = {}, failures = {}, state = "Normal", restrictedUntil = 0 },
	ledgerOutbox = {},
}

local function guest(name, id)
	local g = newGuest(name, id)
	g.Character = nil
	table.insert(guests, g)
	newProfile(g, TEMPLATE)
	profiles[g].Data.firstVisit = fakeOs.time() - 86400 -- yesterday, on the house's clock
	loadedSignal:Fire(g, profiles[g].Data)
	return g
end
local function receipt(player, productId, purchaseId, spent)
	local result
	run(function()
		result = MarketplaceService.ProcessReceipt({ PlayerId = player.UserId, ProductId = productId, PurchaseId = purchaseId, CurrencySpent = spent or 99 })
	end)
	advance(1)
	-- (A receipt waiting on retries takes a few seconds more.)
	local waited = 0
	while result == nil and waited < 5 do
		advance(0.25)
		waited += 0.25
	end
	return result
end
local function askAs(player, request)
	advance(0.15) -- a guest's taps, not a script's
	local r
	run(function()
		r = ask(player, request)
	end)
	return r
end
local function lastOp(player, op)
	for i = #player.inbox, 1, -1 do
		if player.inbox[i].op == op then
			return player.inbox[i]
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- What the tests use
---------------------------------------------------------------------------------------------------
H.check = check
H.run = run
H.advance = advance
H.signal = signal
H.heartbeat = heartbeat
H.PlayersService = PlayersService
H.newGuest = newGuest
H.prompts = prompts
H.productPrices = productPrices
H.passOwners = passOwners
H.subscribers = subscribers
H.MarketplaceService = MarketplaceService
H.guests = guests
H.deepCopy = deepCopy
H.profiles = profiles
H.loadedSignal = loadedSignal
H.newProfile = newProfile
H.module = module
H.shopEvents = shopEvents
H.broadcasts = broadcasts
H.customEvents = customEvents
H.mythicCounts = mythicCounts
H.memoryMaps = memoryMaps
H.awarded = awarded
H.dataStores = dataStores
H.orderedStores = orderedStores
H.published = published
H.subscriptions = subscriptions
H.teleports = teleports
H.services = services
H.stubs = stubs -- a test may stub a module (by its path) before anything requires it
H.fakeOs = fakeOs
H.Config = Config
H.Wardrobe = Wardrobe
H.Boutique = Boutique
H.Remotes = Remotes
H.Gilt = Gilt
H.LedgerService = LedgerService
H.Shop = Shop
H.Purchases = Purchases
H.handovers = handovers
H.ask = ask
H.TEMPLATE = TEMPLATE
H.guest = guest
H.receipt = receipt
H.askAs = askAs
H.lastOp = lastOp
H.Instance = Instance
H.Vector3 = Vector3
H.Enum = Enum
H.CFrame = CFrame
H.roblox = roblox

-- The fake clock, now.
function H.now(): number
	return now
end

-- Moves the house's wall clock so that os.time() reads `t` now.
function H.setWallClock(t: number)
	startTime = t - math.floor(now)
end

-- Prints the totals and fails the run if anything failed.
function H.finish()
	print(string.format("%d passed, %d failed", passed, failed))
	if failed > 0 then
		process.exit(1)
	end
end

return H

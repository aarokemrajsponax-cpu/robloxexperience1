--!nocheck
-- Guests arriving, against the real Guests module under Lune on a fake clock. Above all the case
-- that left the owner stuck in Studio: Roblox spawned their character at the Baseplate
-- template's SpawnLocation (in the middle of the Foyer, just behind the front doors, half inside
-- the floor) before the house was built, and nothing ever moved it. Also: nobody is spawned twice,
-- a slow profile still gets a character, a respawn comes once, and the server boots guests first.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/guests.luau

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
	function s:Fire(...)
		for _, h in table.clone(self.handlers) do
			if h.live then
				run(h.fn, ...)
			end
		end
	end
	return s
end
local function advance(seconds: number)
	local target = now + seconds
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
-- Players and characters
---------------------------------------------------------------------------------------------------
local PlayersService = { PlayerRemoving = signal(), PlayerAdded = signal(), CharacterAutoLoads = true }
local players = {}
PlayersService.GetPlayers = function()
	local out = {}
	for _, p in players do
		if p.Parent == PlayersService then
			table.insert(out, p)
		end
	end
	return out
end
PlayersService.GetPlayerByUserId = function(_, id)
	for _, p in players do
		if p.UserId == id then
			return p
		end
	end
	return nil
end

local function newCharacter(at: Vector3)
	local c = { pivot = CFrame.new(at), DescendantAdded = signal(), Parent = true }
	c.humanoid = { WalkSpeed = 16, JumpPower = 50, Died = signal() }
	c.root = {
		IsA = function(_, class)
			return class == "BasePart" or class == "Part"
		end,
	}
	setmetatable(c.root, {
		__index = function(_, key)
			if key == "Position" then
				return c.pivot.Position
			end
			return nil
		end,
	})
	function c:GetDescendants()
		return {}
	end
	function c:WaitForChild(name)
		return if name == "Humanoid" then self.humanoid else nil
	end
	function c:FindFirstChild(name)
		return if name == "HumanoidRootPart" then self.root elseif name == "Humanoid" then self.humanoid else nil
	end
	function c:FindFirstChildOfClass(class)
		return if class == "Humanoid" then self.humanoid else nil
	end
	function c:PivotTo(cf)
		self.pivot = cf
	end
	function c:GetPivot()
		return self.pivot
	end
	return c
end

local function newPlayer(name: string, id: number, character)
	local p = {
		Name = name,
		DisplayName = name,
		UserId = id,
		Parent = PlayersService,
		Character = character,
		CharacterAdded = signal(),
		attrs = {},
		loads = 0,
		inbox = {},
	}
	function p:SetAttribute(k, v)
		self.attrs[k] = v
	end
	function p:GetAttribute(k)
		return self.attrs[k]
	end
	function p:GetJoinData()
		return {}
	end
	-- Like Roblox: it yields a moment, then the character arrives (at the world's centre, as
	-- there's no SpawnLocation in this test) and CharacterAdded fires.
	function p:LoadCharacterAsync()
		self.loads += 1
		taskShim.wait(0.2)
		local c = newCharacter(Vector3.new(0, 100, 0))
		self.Character = c
		self.CharacterAdded:Fire(c)
	end
	table.insert(players, p)
	return p
end

---------------------------------------------------------------------------------------------------
-- The world (the Baseplate template's floor and spawn are there, as in a new Studio place)
---------------------------------------------------------------------------------------------------
local dm = Instance.new("DataModel")
local workspace = dm:GetService("Workspace")
local baseplate = Instance.new("Part")
baseplate.Name = "Baseplate"
baseplate.Parent = workspace
local templateSpawn = Instance.new("SpawnLocation")
templateSpawn.Name = "SpawnLocation"
templateSpawn.Parent = workspace

local registered = {}
local services = {
	Players = PlayersService,
	Workspace = workspace,
	PhysicsService = {
		IsCollisionGroupRegistered = function(_, name)
			return registered[name] == true
		end,
		RegisterCollisionGroup = function(_, name)
			registered[name] = true
		end,
		CollisionGroupSetCollidable = function() end,
	},
	RunService = {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return true
		end,
	},
}

---------------------------------------------------------------------------------------------------
-- The modules around Guests are stand-ins; Guests itself and the shared rules are real.
---------------------------------------------------------------------------------------------------
local profiles = {}
local loaded = signal()
local greeted = {}
local stubs = {
	["ReplicatedStorage.Shared.Remotes"] = function()
		local events = {}
		return {
			event = function(name)
				events[name] = events[name]
					or {
						OnServerEvent = signal(),
						FireClient = function(_, player, message)
							table.insert(player.inbox, message)
						end,
						FireAllClients = function() end,
					}
				return events[name]
			end,
			func = function()
				return {}
			end,
		}
	end,
	["ServerScriptService.Server.Analytics"] = function()
		return { custom = function() end, step = function() end, source = function() end, stamp = function() end }
	end,
	["ServerScriptService.Server.LiveConfig"] = function()
		return { overrides = {} }
	end,
	["ServerScriptService.Server.Memory"] = function()
		return {
			greeting = function()
				return nil
			end,
		}
	end,
	["ServerScriptService.Server.Profiles"] = function()
		return {
			Loaded = loaded,
			get = function(player)
				return profiles[player]
			end,
			isMock = function()
				return true
			end,
		}
	end,
	["ServerScriptService.Server.TableService"] = function()
		return {
			isSeated = function()
				return false
			end,
		}
	end,
	["ServerScriptService.Server.Staff.Concierge"] = function()
		return {
			greet = function(player)
				table.insert(greeted, player)
			end,
			isLeading = function()
				return false
			end,
			offerHelp = function() end,
			line = function() end,
		}
	end,
}

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
	CFrame = CFrame,
	Color3 = roblox.Color3,
	Enum = Enum,
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

local Layout = module("ReplicatedStorage", "Shared", "Layout")
local Guests = module("ServerScriptService", "Server", "Guests")

local function near(a: Vector3, b: Vector3, within: number): boolean
	return (a - b).Magnitude <= within
end
local function profile(firstVisit: boolean)
	return {
		visits = if firstVisit then 0 else 3,
		firstVisit = 0,
		nights = { count = 1, lastDay = -1 },
		settings = {},
		register = {},
		gilt = 0,
		best = {},
		flags = {},
		nightly = { day = -1, score = 0, grade = "" },
	}
end

---------------------------------------------------------------------------------------------------
-- 1. Studio: Roblox spawned the owner at the template's spawn before the house was ready
---------------------------------------------------------------------------------------------------
-- The template SpawnLocation is at the world's centre: inside the Foyer, behind the front doors,
-- with the Foyer's floor at y = 3 cutting through the character's legs.
local early = newCharacter(Vector3.new(0, 3.5, 0))
local owner = newPlayer("AJKR", 1, early)
check("the scene: the early character stands inside the Foyer, behind the front doors", Layout.zoneAt(early:GetPivot().Position) == "foyer" and early:GetPivot().Position.Z > Layout.Door.centre.Z)
run(Guests.start)
check("Roblox no longer spawns anyone by itself", PlayersService.CharacterAutoLoads == false)
check("the Baseplate template's floor and spawn are cleared away", workspace:FindFirstChild("Baseplate") == nil and workspace:FindFirstChild("SpawnLocation") == nil)
local spawnAt = Layout.Foyer.spawn.Position + Vector3.new(0, 1, 0)
check("the early character is moved at once to where guests arrive", near(early:GetPivot().Position, spawnAt, 0.1), early:GetPivot().Position)
check("standing on the Foyer's floor, not in it", early:GetPivot().Position.Y > Layout.FLOOR + 2)
check("with the house's walking speed", early.humanoid.WalkSpeed == module("ReplicatedStorage", "Shared", "Config").data.Movement.walkSpeed)
check("and no second character on top of it", owner.loads == 0)
-- Their profile loads: the welcome goes out, still one character.
profiles[owner] = profile(true)
loaded:Fire(owner, profiles[owner])
advance(5)
check("the welcome reaches the owner's screen", owner.inbox[1] ~= nil and owner.inbox[1].op == "welcome")
check("a guest who already has a character isn't given another", owner.loads == 0 and owner.Character == early)

---------------------------------------------------------------------------------------------------
-- 2. A guest joining normally: one character, placed, even if the profile is slow
---------------------------------------------------------------------------------------------------
local ben = newPlayer("Ben", 2, nil)
PlayersService.PlayerAdded:Fire(ben)
advance(3.9)
check("no character before the profile or the fallback", ben.Character == nil)
advance(0.5)
check("a slow profile still gets a character after four seconds", ben.Character ~= nil and ben.loads == 1)
check("placed where guests arrive", ben.Character ~= nil and near(ben.Character:GetPivot().Position, spawnAt, 0.1))
profiles[ben] = profile(false)
loaded:Fire(ben, profiles[ben])
advance(1)
check("the profile arriving later doesn't spawn a second one", ben.loads == 1)

-- Both asking at the same moment: still one.
local cy = newPlayer("Cy", 3, nil)
PlayersService.PlayerAdded:Fire(cy)
advance(3.95)
profiles[cy] = profile(true)
loaded:Fire(cy, profiles[cy])
advance(1)
check("the profile and the fallback at the same moment: one character", cy.loads == 1, cy.loads)
check("a first-ever visit arrives in the lit Foyer", cy.Character ~= nil and Layout.zoneAt(cy.Character:GetPivot().Position) == "foyer")

---------------------------------------------------------------------------------------------------
-- 3. A fall or a reset: the character comes back once
---------------------------------------------------------------------------------------------------
local before = ben.loads
local body = ben.Character
body.humanoid.Died:Fire()
advance(2.9)
check("a moment's pause after a fall", ben.loads == before)
advance(0.5)
check("then one new character", ben.loads == before + 1 and ben.Character ~= body)
advance(5)
check("and only one", ben.loads == before + 1)

---------------------------------------------------------------------------------------------------
-- 4. The server boots guests first; Studio never spawns anyone by itself
---------------------------------------------------------------------------------------------------
local main = fs.readFile("src/server/Main.server.luau")
local autoAt = string.find(main, "Players.CharacterAutoLoads = false", 1, true)
local buildAt = string.find(main, "World.run()", 1, true)
local liveAt = string.find(main, "LiveConfig.start", 1, true)
local guestsAt = string.find(main, 'boot("Guests", Guests.start)', 1, true)
check("the server stops Roblox's own spawning before anything else", autoAt ~= nil and autoAt < (liveAt or 0) and autoAt < (buildAt or 0))
check("guests start right after the house is built", guestsAt ~= nil and buildAt ~= nil and guestsAt > buildAt)
local firstOtherBoot = math.huge
for name in string.gmatch(main, 'boot%("([^"]+)"') do
	if name ~= "Live Configs" and name ~= "The house" and name ~= "Guests" then
		firstOtherBoot = math.min(firstOtherBoot, string.find(main, 'boot("' .. name .. '"', 1, true))
	end
end
check("...and before every other part of the house", guestsAt ~= nil and guestsAt < firstOtherBoot)
local project = serde.decode("json", fs.readFile("default.project.json"))
check("Rojo tells Studio not to spawn anyone by itself", project.tree.Players and project.tree.Players["$properties"] and project.tree.Players["$properties"].CharacterAutoLoads == false)

print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
	process.exit(1)
end

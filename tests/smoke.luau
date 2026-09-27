--!nocheck
-- Builds the Maison under Lune (a standalone Luau runtime with Roblox's instance model and
-- reflection database), so every property, enum and value the builders set is checked for real.
-- Then checks the result: tables, prompts, doors, and a clear walking route from the street
-- spawn to a Salon chair.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/smoke.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Instance, Vector3, Enum = roblox.Instance, roblox.Vector3, roblox.Enum

-- Lune 0.10's CFrame.lookAt faces away from its target; Roblox's faces toward it (LookVector
-- points at the target). Everything else in Lune's CFrame matches Roblox, so only this is fixed.
local function lookAt(at, target, up)
	up = up or Vector3.new(0, 1, 0)
	local look = (target - at).Unit
	local right = look:Cross(up)
	if right.Magnitude < 1e-6 then
		right = look:Cross(Vector3.new(0, 0, 1))
	end
	right = right.Unit
	local up2 = right:Cross(look)
	return roblox.CFrame.fromMatrix(at, right, up2, -look)
end
local CFrame = setmetatable({ lookAt = lookAt }, { __index = roblox.CFrame })

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
-- Engine methods Lune doesn't implement
---------------------------------------------------------------------------------------------------
local function corners(cf, size)
	local out = {}
	for _, sx in { -0.5, 0.5 } do
		for _, sy in { -0.5, 0.5 } do
			for _, sz in { -0.5, 0.5 } do
				table.insert(out, cf * Vector3.new(size.X * sx, size.Y * sy, size.Z * sz))
			end
		end
	end
	return out
end

local function boundingBox(model)
	local lo, hi
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			for _, c in corners(d.CFrame, d.Size) do
				lo = if lo then Vector3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z)) else c
				hi = if hi then Vector3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z)) else c
			end
		end
	end
	if not lo then
		return CFrame.new(), Vector3.new()
	end
	return CFrame.new((lo + hi) / 2), hi - lo
end

roblox.implementMethod("Model", "GetBoundingBox", function(self)
	return boundingBox(self)
end)
roblox.implementMethod("Model", "GetPivot", function(self)
	local pp = self.PrimaryPart
	return if pp then pp.CFrame else (boundingBox(self))
end)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local pivot = if self.PrimaryPart then self.PrimaryPart.CFrame else (boundingBox(self))
	local delta = target * pivot:Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)
roblox.implementMethod("Model", "GetScale", function()
	return 1
end)
roblox.implementMethod("Model", "ScaleTo", function() end)

---------------------------------------------------------------------------------------------------
-- A tiny Roblox runtime: services, task, Random, TweenInfo
---------------------------------------------------------------------------------------------------
local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")

local function signal()
	return {
		Connect = function()
			return { Disconnect = function() end }
		end,
		Once = function()
			return { Disconnect = function() end }
		end,
		Wait = function() end,
	}
end

local CollectionService = {
	AddTag = function(_, instance, tag)
		instance:AddTag(tag)
	end,
	HasTag = function(_, instance, tag)
		return instance:HasTag(tag)
	end,
	GetTagged = function(_, tag)
		local out = {}
		for _, d in game:GetDescendants() do
			if d:HasTag(tag) then
				table.insert(out, d)
			end
		end
		return out
	end,
	GetInstanceAddedSignal = function()
		return signal()
	end,
}

local TweenService = {
	Create = function(_, instance, _info, goal)
		return {
			Play = function()
				for k, v in goal do
					instance[k] = v -- jump to the goal: validates the tweened properties too
				end
			end,
			Cancel = function() end,
			Completed = signal(),
		}
	end,
}

local services = {
	CollectionService = CollectionService,
	TweenService = TweenService,
	RunService = {
		IsServer = function()
			return true
		end,
		IsStudio = function()
			return true
		end,
		Heartbeat = signal(),
	},
}

local Random = {}
Random.__index = Random
function Random.new(seed)
	local state = ((seed or 1) * 2654435761 + 12345) % 4294967296
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

local taskShim = {
	spawn = function(fn, ...)
		local co = coroutine.create(fn)
		coroutine.resume(co, ...)
	end,
	delay = function() end,
	defer = function() end,
	wait = function()
		coroutine.yield()
	end,
}

---------------------------------------------------------------------------------------------------
-- Module loading from the Rojo sourcemap
---------------------------------------------------------------------------------------------------
local sourcemap = serde.decode("json", fs.readFile("sourcemap.json"))

local proxies = {}
local cache = {}
local requireModule

local function proxyFor(node, parent)
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
					return proxyFor(child, p)
				end
			end
			error(`{key} is not a valid member of {node.name}`)
		end,
	})
	rawset(p, "__node", node)
	return p
end

local root = proxyFor(sourcemap, nil)
local function service(name)
	if services[name] then
		return services[name]
	end
	for _, child in sourcemap.children do
		if child.name == name then
			return proxyFor(child, root)
		end
	end
	return game:GetService(name)
end
local gameShim = setmetatable({
	GetService = function(_, name)
		return service(name)
	end,
}, {
	__index = function(_, key)
		return service(key)
	end,
})

local globals = {
	Instance = Instance,
	Vector3 = Vector3,
	Vector2 = roblox.Vector2,
	CFrame = CFrame,
	Color3 = roblox.Color3,
	Enum = Enum,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	-- Lune's font table predates Builder Sans; fall back so the rest can be checked.
	Font = {
		new = roblox.Font.new,
		fromName = roblox.Font.fromName,
		fromEnum = function(e)
			local ok, f = pcall(roblox.Font.fromEnum, e)
			return if ok then f else roblox.Font.new("rbxasset://fonts/families/BuilderSans.json")
		end,
	},
	NumberRange = roblox.NumberRange,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	PhysicalProperties = roblox.PhysicalProperties,
	Rect = roblox.Rect,
	Random = Random,
	TweenInfo = {
		new = function(...)
			return { Time = select(1, ...) or 1, EasingStyle = select(2, ...), EasingDirection = select(3, ...), RepeatCount = 0, Reverses = false, DelayTime = 0 }
		end,
	},
	task = taskShim,
	game = gameShim,
	workspace = workspace,
	warn = function(...)
		print("warn:", ...)
	end,
}

function requireModule(proxy)
	local node = rawget(proxy, "__node")
	if cache[node] ~= nil then
		return cache[node]
	end
	local path
	for _, f in node.filePaths or {} do
		if string.find(f, "%.luau$") then
			path = f
		end
	end
	assert(path, "no source for " .. node.name)
	-- Lune reads raw fields of the environment, so copy the globals in.
	local env = { script = proxy, require = requireModule }
	for k, v in globals do
		env[k] = v
	end
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env, injectGlobals = true })
	local result = fn()
	cache[node] = result
	return result
end

local function module(...)
	local p = root
	for _, name in { ... } do
		p = p[name]
	end
	return requireModule(p)
end

---------------------------------------------------------------------------------------------------
-- 1. Build the Maison
---------------------------------------------------------------------------------------------------
local ok, err = pcall(function()
	module("ServerScriptService", "Server", "World", "Build").run()
end)
check("the Maison builds without an error", ok, err)
if not ok then
	print(("\n%d passed, %d failed"):format(passed, failed))
	process.exit(1)
end

local maison = workspace:FindFirstChild("Maison")
local parts, lights, guis = 0, 0, 0
for _, d in maison:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	elseif d:IsA("Light") then
		lights += 1
	elseif d:IsA("SurfaceGui") then
		guis += 1
	end
end
print(("built: %d parts, %d lights, %d surface guis"):format(parts, lights, guis))
check("part budget (under 4,000)", parts < 4000, parts)
check("light budget (under 120)", lights < 120, lights)

-- Season lighting setup (server)
local okSeason, errSeason = pcall(function()
	module("ServerScriptService", "Server", "Season").start()
end)
check("season lighting applies without an error", okSeason, errSeason)
check("season published to the Workspace", workspace:GetAttribute("Season") ~= nil, workspace:GetAttribute("Season"))

---------------------------------------------------------------------------------------------------
-- 2. The pieces the client builds
---------------------------------------------------------------------------------------------------
local PieceModels = module("ReplicatedStorage", "Shared", "PieceModels")
local Catalogue = module("ReplicatedStorage", "Shared", "Catalogue")
local missing, broken, oversize = {}, {}, {}
for _, id in PieceModels.allIds() do
	if not PieceModels.has(id) then
		table.insert(missing, id)
	end
	local okPiece, model = pcall(PieceModels.build, id)
	if not okPiece then
		table.insert(broken, id .. ": " .. tostring(model))
	else
		local _, size = boundingBox(model)
		if size.X > 1.6 or size.Z > 1.6 then
			table.insert(oversize, string.format("%s (%.2f x %.2f)", id, size.X, size.Z))
		end
		pcall(PieceModels.gild, model)
		model:Destroy()
	end
end
check("every catalogue piece has its own model", #missing == 0, table.concat(missing, ", "))
check("every piece model builds", #broken == 0, table.concat(broken, "; "))
check("every piece fits a felt slot (1.6 studs)", #oversize == 0, table.concat(oversize, ", "))
check("62 collectable pieces", Catalogue.totalCollectable() == 62, Catalogue.totalCollectable())

---------------------------------------------------------------------------------------------------
-- 3. Tables, prompts and doors are wired the way the client expects
---------------------------------------------------------------------------------------------------
local Layout = module("ReplicatedStorage", "Shared", "Layout")
local tables = CollectionService.GetTagged(CollectionService, "MaisonTable")
check("six Salon tables", #tables == 6, #tables)
local ids = {}
for _, t in tables do
	local id = t:GetAttribute("TableId")
	check("table has a unique id " .. tostring(id), id ~= nil and not ids[id])
	ids[id] = true
	local chair = t:FindFirstChild("Chair")
	check(id .. " chair is a Seat", chair ~= nil and chair:IsA("Seat"))
	check(id .. " chair can't be sat in by walking into it", chair ~= nil and chair.CanTouch == false)
	local prompt = chair and chair:FindFirstChild("SitPrompt")
	check(id .. " has a Sit prompt (custom style)", prompt ~= nil and prompt.Style == Enum.ProximityPromptStyle.Custom)
	check(id .. " chair faces the table (+Z)", chair ~= nil and chair.CFrame.LookVector.Z > 0.99)
	for _, name in { "Felt", "Counter", "Dial", "Bulb", "Lamp" } do
		check(id .. " has " .. name, t:FindFirstChild(name) ~= nil)
	end
	local light = t:FindFirstChild("Bulb") and t.Bulb:FindFirstChild("TableLight")
	check(id .. " lamp has its TableLight", light ~= nil)
	for i = 1, 6 do
		local case = t:FindFirstChild("Case" .. i)
		check(id .. " case " .. i, case ~= nil and case:GetAttribute("CaseId") == Catalogue.Cases[i].id)
		check(id .. " lid " .. i, t:FindFirstChild("CaseLid" .. i) ~= nil)
		check(id .. " glow " .. i, t:FindFirstChild("CaseGlow" .. i) ~= nil)
		check(id .. " plate " .. i, t:FindFirstChild("CasePlate" .. i) ~= nil)
	end
	check(id .. " streams as one persistent model", t.ModelStreamingMode == Enum.ModelStreamingMode.Persistent)
	local centre = t:GetAttribute("Centre")
	check(id .. " sits inside the Salon", centre ~= nil and Layout.zoneAt(centre + Vector3.new(0, 3, 0)) == "salon", centre)
	-- The case plates and counter face up toward the guest's camera.
	local counter = t:FindFirstChild("Counter")
	check(id .. " counter faces the guest's camera", counter ~= nil and counter.CFrame.LookVector.Y > 0.8 and counter.CFrame.LookVector.Z < 0)
	check(id .. " counter reads upright (top toward the cases)", counter ~= nil and counter.CFrame.UpVector.Z > 0.8)
end

local front = CollectionService.GetTagged(CollectionService, "FrontDoors")
check("front doors tagged", #front == 1)
local roomDoors = CollectionService.GetTagged(CollectionService, "RoomDoor")
check("four room doors tagged", #roomDoors == 4, #roomDoors)
local names = CollectionService.GetTagged(CollectionService, "RoomName")
check("four room name plates", #names == 4, #names)
for _, n in names do
	local facing = n.CFrame.LookVector
	-- Name plates face into the Foyer (toward x = 0).
	check("room name faces the Foyer: " .. n.Parent.Name, facing:Dot(Vector3.new(-n.CFrame.Position.X, 0, 0).Unit) > 0.9, facing)
end
for _, door in roomDoors do
	for _, leaf in { door:FindFirstChild("LeafL"), door:FindFirstChild("LeafR") } do
		check(door.Name .. " leaf has a hinge", leaf ~= nil and typeof(leaf:GetAttribute("Hinge")) == "CFrame")
	end
end
local boards = CollectionService.GetTagged(CollectionService, "MaisonBoard")
local tonight = 0
for _, b in boards do
	if b:GetAttribute("Kind") == "tonight" then
		tonight += 1
	end
end
check("the Tonight board exists", tonight == 1)
local plaque = maison:FindFirstChild("Street") and maison.Street:FindFirstChild("Facade") and maison.Street.Facade:FindFirstChild("Plaque")
check("the brass plaque faces the street", plaque ~= nil and plaque.CFrame.LookVector.Z < -0.99)

---------------------------------------------------------------------------------------------------
-- 4. The walk: street spawn -> door -> Foyer -> Salon door -> a chair, with nothing solid in the way
---------------------------------------------------------------------------------------------------
local solids = {}
for _, d in maison:GetDescendants() do
	if d:IsA("BasePart") and d.CanCollide and not d:IsA("Seat") then
		table.insert(solids, d)
	end
end

-- Does a vertical capsule (radius r, from y0 to y1) at point p overlap a part's box?
local function blocked(p: Vector3, r: number, y0: number, y1: number)
	for _, part in solids do
		local rel = part.CFrame:PointToObjectSpace(p)
		local half = part.Size / 2
		-- Vertical extent of the part in world space (parts here are mostly axis aligned).
		local _, size = boundingBox({ GetDescendants = function()
			return { part }
		end })
		local bottom = part.CFrame.Position.Y - size.Y / 2
		local top = part.CFrame.Position.Y + size.Y / 2
		if top > y0 and bottom < y1 then
			local dx = math.max(0, math.abs(rel.X) - half.X)
			local dz = math.max(0, math.abs(rel.Z) - half.Z)
			if dx * dx + dz * dz < r * r and math.abs(part.CFrame.UpVector.Y) > 0.9 then
				return part
			end
		end
	end
	return nil
end

local FLOOR = Layout.FLOOR
local salonDoor = Layout.RoomDoors.salon.centre
local firstTable = Layout.Salon.tables[1]
local chair = firstTable + Vector3.new(0, 0, Layout.Table.chairZ - 1.6)
local route = {
	{ Layout.Street.spawn.Position, 0 },
	{ Vector3.new(0, 0, -16), 0 }, -- foot of the steps
	{ Vector3.new(0, FLOOR, -9), FLOOR }, -- through the front door
	{ Vector3.new(0, FLOOR, 0), FLOOR },
	{ Vector3.new(-24, FLOOR, 4), FLOOR },
	{ salonDoor + Vector3.new(4, 0, 0), FLOOR }, -- in front of the Salon door
	{ salonDoor + Vector3.new(-4.5, 0, 0), FLOOR }, -- through it
	{ Vector3.new(salonDoor.X - 4.5, FLOOR, chair.Z), FLOOR }, -- along the wall, past the first table
	{ Vector3.new(chair.X + 3.5, FLOOR, chair.Z), FLOOR },
	{ Vector3.new(chair.X, FLOOR, chair.Z), FLOOR },
}
local walkBlocked = nil
for i = 1, #route - 1 do
	local a, b = route[i][1], route[i + 1][1]
	local steps = math.ceil((b - a).Magnitude / 0.5)
	for s = 0, steps do
		local t = s / steps
		local p = a:Lerp(b, t)
		-- The front steps: each is 1 stud high and 1.5 deep (humanoids step up 1 stud freely).
		local function stepGround(z: number): number
			if z >= -8 then
				return FLOOR
			elseif z >= -11.5 then
				return 3
			elseif z >= -13 then
				return 2
			elseif z >= -14.5 then
				return 1
			end
			return 0
		end
		local ground = if route[i][2] == route[i + 1][2] then route[i][2] else stepGround(p.Z)
		-- Capsule from knee height (steps are climbable) to head height.
		local hit = blocked(Vector3.new(p.X, 0, p.Z), 1.0, ground + 1.2, ground + 5.2)
		if hit and not walkBlocked then
			walkBlocked = string.format("%s at (%.1f, %.1f) on leg %d", hit:GetFullName(), p.X, p.Z, i)
		end
	end
end
check("a guest can walk from the street spawn to a Salon chair", walkBlocked == nil, walkBlocked)
check("the street spawn is clear", blocked(Layout.Street.spawn.Position, 1, 1.2, 5) == nil)
check("the Foyer spawn is clear", blocked(Layout.Foyer.spawn.Position, 1, FLOOR + 1.2, FLOOR + 5) == nil)
-- The Concierge's route to the Salon must be clear too.
local conciergeBlocked = nil
local home = Layout.Foyer.conciergeHome.Position
local legs = { { home, Vector3.new(home.X, FLOOR, 12) }, { Vector3.new(home.X, FLOOR, 12), salonDoor + Vector3.new(4, 0, 0) }, { salonDoor + Vector3.new(4, 0, 0), Layout.Salon.arrival } }
for i, leg in legs do
	local a, b = leg[1], leg[2]
	local steps = math.ceil((b - a).Magnitude / 0.5)
	for s = 0, steps do
		local p = a:Lerp(b, s / steps)
		local hit = blocked(Vector3.new(p.X, 0, p.Z), 0.9, FLOOR + 1.2, FLOOR + 5.2)
		if hit and not conciergeBlocked then
			conciergeBlocked = string.format("%s at (%.1f, %.1f) on leg %d", hit:GetFullName(), p.X, p.Z, i)
		end
	end
end
check("the Concierge has a clear walk to the Salon", conciergeBlocked == nil, conciergeBlocked)

-- Pieces laid out on the felt stay inside it and never overlap.
for count = 4, 28 do
	local slots = Layout.pieceSlots(Vector3.new(), count)
	local okSlots = #slots == count
	for i, s in slots do
		if math.abs(s.X) > Layout.Table.width / 2 - 0.6 or s.Z < Layout.Table.feltMinZ - 0.01 or s.Z > Layout.Table.feltMaxZ + 0.01 then
			okSlots = false
		end
		for j = i + 1, #slots do
			if (slots[j] - s).Magnitude < 0.75 then
				okSlots = false
			end
		end
	end
	check(("%d pieces fit the felt without overlapping"):format(count), okSlots)
end

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	process.exit(1)
end

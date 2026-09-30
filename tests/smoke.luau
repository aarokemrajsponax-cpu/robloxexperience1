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
	elseif d:IsA("Light") and d.Enabled then
		lights += 1
	elseif d:IsA("SurfaceGui") then
		guis += 1
	end
end
print(("built: %d parts, %d lights, %d surface guis"):format(parts, lights, guis))
-- The Ballroom's twenty tables brought the house past 6,500; the world streams by distance, so
-- a phone holds the room it's in, not the whole house.
check("part budget (under 7,500)", parts < 7500, parts)
check("light budget (under 140 lit)", lights < 140, lights)

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
check("48 tables: six in each room, four duel halves in the Library, twenty in the Ballroom", #tables == 48, #tables)
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
	local frame = t:GetAttribute("Frame")
	local forward = if typeof(frame) == "CFrame" then frame:VectorToWorldSpace(Vector3.new(0, 0, 1)) else Vector3.new(0, 0, 1)
	check(id .. " chair faces its table", chair ~= nil and chair.CFrame.LookVector:Dot(forward) > 0.99)
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
	check(id .. " sits inside its room", centre ~= nil and Layout.zoneAt(centre + Vector3.new(0, 3, 0)) == t:GetAttribute("Room"), centre)
	if t:GetAttribute("Ballroom") then
		check(id .. " (the Ballroom) has no Nightly prompt", chair ~= nil and chair:FindFirstChild("NightlyPrompt") == nil)
	elseif t:GetAttribute("Duel") == nil then
		check(id .. " has the Nightly prompt", chair ~= nil and chair:FindFirstChild("NightlyPrompt") ~= nil)
	else
		check(id .. " (a duel half) has no Nightly prompt", chair ~= nil and chair:FindFirstChild("NightlyPrompt") == nil)
	end
	check(id .. " has a clock rail", t:FindFirstChild("ClockRail") ~= nil)
	-- The case plates and counter face up toward the guest's camera.
	local counter = t:FindFirstChild("Counter")
	check(id .. " counter faces the guest's camera", counter ~= nil and counter.CFrame.LookVector.Y > 0.8 and counter.CFrame.LookVector:Dot(forward) < 0)
	check(id .. " counter reads upright (top toward the cases)", counter ~= nil and counter.CFrame.UpVector:Dot(forward) > 0.8)
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

local function walk(route: { { any } }, radius: number, ignore: ((BasePart) -> boolean)?): string?
	for i = 1, #route - 1 do
		local a, b = route[i][1], route[i + 1][1]
		local steps = math.ceil((b - a).Magnitude / 0.5)
		for s = 0, steps do
			local p = a:Lerp(b, s / steps)
			local ground = if route[i][2] == route[i + 1][2] then route[i][2] else stepGround(p.Z)
			-- Capsule from knee height (steps are climbable) to head height.
			local hit = blocked(Vector3.new(p.X, 0, p.Z), radius, ground + 1.2, ground + 5.2)
			if hit and not (ignore and ignore(hit)) then
				return string.format("%s at (%.1f, %.1f) on leg %d", hit:GetFullName(), p.X, p.Z, i)
			end
		end
	end
	return nil
end

-- The Midnight Room's doors and rope are solid until a guest earns it; the client opens them.
local function earned(part: BasePart): boolean
	return part:GetAttribute("Gated") == true or (part.Parent ~= nil and part.Parent.Name == "Door_midnight" and (part.Name == "Rope" or part.Name == "Stanchion" or part.Name == "StanchionTop"))
end

for _, roomId in { "salon", "velvet", "obsidian", "midnight" } do
	local door = Layout.RoomDoors[roomId]
	local spec = Layout.Rooms[roomId]
	local inward = -door.facing -- from the Foyer into the room
	local firstTable = spec.tables[1]
	local chair = firstTable + Vector3.new(0, 0, Layout.Table.chairZ - 1.6)
	local inside = door.centre + inward * 4.5
	local route = {
		{ Layout.Street.spawn.Position, 0 },
		{ Vector3.new(0, 0, -16), 0 }, -- foot of the steps
		{ Vector3.new(0, FLOOR, -9), FLOOR }, -- through the front door
		{ Vector3.new(0, FLOOR, 0), FLOOR },
	}
	for _, point in door.approach do
		table.insert(route, { point, FLOOR })
	end
	for _, leg in {
		{ door.centre + door.facing * 6, FLOOR }, -- in front of the room's door
		{ inside, FLOOR }, -- through it
		{ Vector3.new(inside.X, FLOOR, chair.Z), FLOOR }, -- along the wall, past the first table
		{ Vector3.new(chair.X - inward.X * 3.5, FLOOR, chair.Z), FLOOR },
		{ Vector3.new(chair.X, FLOOR, chair.Z), FLOOR },
	} do
		table.insert(route, leg)
	end
	local why = walk(route, 1.0, if roomId == "midnight" then earned else nil)
	check("a guest can walk from the street spawn to a chair in " .. roomId, why == nil, why)
	-- The Concierge's walk from the lectern to the room's arrival point.
	local home = Layout.Foyer.conciergeHome.Position
	local legs = { { home, FLOOR } }
	for _, point in door.approach do
		table.insert(legs, { point, FLOOR })
	end
	table.insert(legs, { door.centre + door.facing * 4, FLOOR })
	table.insert(legs, { spec.arrival, FLOOR })
	local cwhy = walk(legs, 0.9, if roomId == "midnight" then earned else nil)
	check("the Concierge has a clear walk to " .. roomId, cwhy == nil, cwhy)
end
-- Duel tables: the two halves face each other and their case rows meet in the middle.
for _, duel in Layout.Library.duels do
	local halves = {}
	for _, t in tables do
		if t:GetAttribute("Duel") == duel.id then
			halves[t:GetAttribute("Side")] = t
		end
	end
	check(duel.id .. " has both halves", halves.a ~= nil and halves.b ~= nil)
	if halves.a and halves.b then
		local fa, fb = halves.a:GetAttribute("Frame"), halves.b:GetAttribute("Frame")
		local forwardA = fa:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local forwardB = fb:VectorToWorldSpace(Vector3.new(0, 0, 1))
		check(duel.id .. " halves face each other", forwardA:Dot(forwardB) < -0.99)
		local caseA = Layout.caseCentre(fa, 3)
		local caseB = Layout.caseCentre(fb, 4)
		check(duel.id .. " case rows meet in the middle", (caseA - caseB).Magnitude < 3.5, (caseA - caseB).Magnitude)
		local chairA, chairB = halves.a.Chair, halves.b.Chair
		check(duel.id .. " guests sit at opposite ends", (chairA.CFrame.Position - chairB.CFrame.Position).Magnitude > 15, (chairA.CFrame.Position - chairB.CFrame.Position).Magnitude)
		check(duel.id .. " guest a faces guest b", chairA.CFrame.LookVector:Dot((chairB.CFrame.Position - chairA.CFrame.Position).Unit) > 0.99)
	end
end

-- Up the Grand Stair to the Library: steps of one stud, then the Club Floor at y = 20.
do
	local st = Layout.Foyer.stair
	local depth = (st.toZ - st.fromZ) / st.topY
	local function stairGround(z: number): number
		if z < st.fromZ then
			return FLOOR
		elseif z >= st.toZ then
			return Layout.CLUB
		end
		return FLOOR + math.floor((z - st.fromZ) / depth) + 1
	end
	local duel = Layout.Library.duels[1]
	local frameA = Layout.duelFrames(duel.centre)
	local chairA = frameA:PointToWorldSpace(Vector3.new(0, 0, Layout.Table.chairZ - 1.6))
	local legs = {
		{ Vector3.new(0, 0, 0), Vector3.new(st.x, 0, 12) },
		{ Vector3.new(st.x, 0, 12), Vector3.new(st.x, 0, st.fromZ - 1) },
		{ Vector3.new(st.x, 0, st.fromZ - 1), Vector3.new(st.x, 0, st.toZ + 1) }, -- the stair
		{ Vector3.new(st.x, 0, st.toZ + 1), Vector3.new(st.x, 0, 50) }, -- through the arch
		{ Vector3.new(st.x, 0, 50), Vector3.new(Layout.Club.libraryDoor.X, 0, 60) },
		{ Vector3.new(Layout.Club.libraryDoor.X, 0, 60), Vector3.new(Layout.Club.libraryDoor.X, 0, 71) }, -- into the Library
		{ Vector3.new(Layout.Club.libraryDoor.X, 0, 71), Vector3.new(chairA.X + 3.5, 0, 71) },
		{ Vector3.new(chairA.X + 3.5, 0, 71), Vector3.new(chairA.X + 3.5, 0, chairA.Z) },
		{ Vector3.new(chairA.X + 3.5, 0, chairA.Z), Vector3.new(chairA.X, 0, chairA.Z) },
	}
	local why = nil
	for i, leg in legs do
		local a, b = leg[1], leg[2]
		local n = math.ceil((b - a).Magnitude / 0.4)
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			local ground = if p.Z >= st.fromZ - 1 then stairGround(p.Z) else FLOOR
			-- On the stair itself the next two steps are within a body's reach; a humanoid
			-- climbs one-stud risers, so only check above knee height there.
			local onStair = p.Z >= st.fromZ - 1 and p.Z < st.toZ
			local hit = blocked(Vector3.new(p.X, 0, p.Z), 0.9, ground + (if onStair then 2.2 else 1.2), ground + 5.2)
			if hit and not why then
				why = string.format("%s at (%.1f, %.1f) on leg %d", hit:GetFullName(), p.X, p.Z, i)
			end
		end
	end
	check("a guest can climb the Grand Stair and reach a Library chair", why == nil, why)
end

-- The Ballroom: twenty tables in a ring, each facing the middle, none touching.
do
	local ring = {}
	for _, t in tables do
		if t:GetAttribute("Ballroom") then
			ring[t:GetAttribute("Seat")] = t
		end
	end
	local n = 0
	for _ in ring do
		n += 1
	end
	check("the Ballroom has twenty tables", n == 20, n)
	local B = Layout.Ballroom
	for i, t in ring do
		local frame = t:GetAttribute("Frame")
		local forward = frame:VectorToWorldSpace(Vector3.new(0, 0, 1))
		local toMiddle = (B.centre - frame.Position).Unit
		check("ballroom table " .. i .. " faces the middle", forward:Dot(toMiddle) > 0.99)
		local chair = t:FindFirstChild("Chair")
		check("ballroom table " .. i .. " has its chair on the outside", chair ~= nil and (chair.CFrame.Position - B.centre).Magnitude > B.radius)
		check("ballroom table " .. i .. " has a dumbwaiter", typeof(t:GetAttribute("Dumbwaiter")) == "Vector3" and t:FindFirstChild("Dumbwaiter") ~= nil)
		check("ballroom table " .. i .. " has no Nightly prompt", chair ~= nil and chair:FindFirstChild("NightlyPrompt") == nil)
		local next_ = ring[i % 20 + 1]
		if next_ then
			local gap = (next_:GetAttribute("Centre") - t:GetAttribute("Centre")).Magnitude
			check("ballroom tables " .. i .. " and " .. (i % 20 + 1) .. " don't touch", gap > Layout.Table.width + 0.5, gap)
		end
		local cp = chair and chair.CFrame.Position
		check("ballroom chair " .. i .. " is inside the room", cp ~= nil and Layout.inBox(B.zone, cp + Vector3.new(0, 1, 0)))
	end
	-- From the Club hall into the Ballroom, under the Gallery, to table 1's chair.
	local chair1 = ring[1] and ring[1].Chair.CFrame.Position
	local door = Layout.Club.ballroomDoor
	local why = walk({
		{ Vector3.new(door.X, 0, 58), Layout.CLUB },
		{ Vector3.new(door.X, 0, 72), Layout.CLUB },
		{ Vector3.new(chair1.X - 3.5, 0, 72), Layout.CLUB },
		{ Vector3.new(chair1.X - 3.5, 0, chair1.Z), Layout.CLUB },
	}, 0.9)
	check("a guest can walk from the Club hall into the Ballroom to a chair", why == nil, why)
	-- Across the floor between the tables to the middle.
	local between = Layout.ballroomFrame(1.5):PointToWorldSpace(Vector3.new(0, 0, -6))
	local whyMiddle = walk({ { Vector3.new(between.X, 0, between.Z), Layout.CLUB }, { B.centre, Layout.CLUB } }, 0.9)
	check("the middle of the Ballroom can be reached between two tables", whyMiddle == nil, whyMiddle)
	-- Up the stair to the Gallery.
	local S = B.stair
	local function ground(z: number): number
		if z > S.bottomZ then
			return Layout.CLUB
		elseif z < S.topZ then
			return B.gallery.floorY
		end
		local k = math.floor((S.bottomZ - z) / 2) + 1
		return Layout.CLUB + math.min(k, S.steps)
	end
	local sx = (S.x0 + S.x1) / 2
	-- Each leg: from, to, and how the ground runs ("floor", "stair" or "gallery").
	local legs = {
		{ Vector3.new(door.X + 1, 0, 72), Vector3.new(door.X + 1, 0, S.bottomZ + 3), "floor" },
		{ Vector3.new(door.X + 1, 0, S.bottomZ + 3), Vector3.new(sx, 0, S.bottomZ + 3), "floor" },
		{ Vector3.new(sx, 0, S.bottomZ + 3), Vector3.new(sx, 0, S.topZ - 1), "stair" },
		{ Vector3.new(sx, 0, S.topZ - 1), Vector3.new(sx, 0, 72.5), "gallery" },
		{ Vector3.new(sx, 0, 72.5), Vector3.new(B.galleryArrival.X, 0, 72.5), "gallery" },
	}
	local whyStair = nil
	for i, leg in legs do
		local a, b = leg[1], leg[2]
		local steps = math.ceil((b - a).Magnitude / 0.4)
		for k = 0, steps do
			local p = a:Lerp(b, k / steps)
			local onStair = leg[3] == "stair"
			local g = if leg[3] == "floor" then Layout.CLUB elseif leg[3] == "gallery" then B.gallery.floorY else ground(p.Z)
			local hit = blocked(Vector3.new(p.X, 0, p.Z), 0.9, g + (if onStair then 2.2 else 1.2), g + 5.2)
			if hit and not whyStair then
				whyStair = string.format("%s at (%.1f, %.1f) on leg %d", hit:GetFullName(), p.X, p.Z, i)
			end
		end
	end
	check("a guest can climb to the Gallery and walk along it", whyStair == nil, whyStair)
	check("the Gallery arrival is clear", blocked(B.galleryArrival, 0.9, B.gallery.floorY + 1.2, B.gallery.floorY + 5) == nil)
	check("the Ballroom arrival is clear", blocked(B.arrival, 0.9, Layout.CLUB + 1.2, Layout.CLUB + 5) == nil)
end

-- The Boutique: open to walk into, with its counter, mirror and Ledger.
do
	local Bq = Layout.Boutique
	local door = Layout.Foyer.boutiqueDoor.Position
	local why = walk({
		{ Vector3.new(door.X, 0, 30), FLOOR },
		{ Vector3.new(door.X, 0, 47), FLOOR },
		{ Vector3.new(21, 0, 47), FLOOR },
		{ Vector3.new(21, 0, 53.5), FLOOR },
	}, 0.9)
	check("a guest can walk from the Foyer into the Boutique to the counter", why == nil, why)
	local found = {}
	for _, d in maison:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			found[d.Name] = true
		end
	end
	check("the Boutique counter has its prompt", found.BoutiquePrompt == true)
	check("the Tailor's mirror has its prompt", found.WardrobePrompt == true)
	check("the Ledger has its prompt", found.LedgerPrompt == true)
	check("the Boutique is its own zone", Layout.zoneAt(Vector3.new(21, 5, 50)) == "boutique")
	check("the Boutique arrival is clear", blocked(Bq.arrival, 0.9, FLOOR + 1.2, FLOOR + 5) == nil)
end

-- The Vault: through the Foyer's back wall, the Archivist's desk and seven cabinets.
do
	local V = Layout.Vault
	local why = walk({
		{ Vector3.new(V.door.X, 0, 30), FLOOR },
		{ Vector3.new(V.door.X, 0, 47), FLOOR },
		{ Vector3.new(-1.5, 0, 47), FLOOR },
	}, 0.9)
	check("a guest can walk from the Foyer into the Vault to the Archivist's desk", why == nil, why)
	local cabinets = CollectionService.GetTagged(CollectionService, "VaultCabinet")
	check("the Vault has six case cabinets and the Mythics'", #cabinets == 7, #cabinets)
	check("the Register can be read", (function()
		for _, d in maison:GetDescendants() do
			if d:IsA("ProximityPrompt") and d.Name == "RegisterPrompt" then
				return true
			end
		end
		return false
	end)())
	check("the Vault is its own zone", Layout.zoneAt(Vector3.new(-8, 5, 50)) == "vault")
	check("the way round the centre cabinet is clear", walk({ { Vector3.new(-3, 0, 47), FLOOR }, { Vector3.new(-3, 0, 57), FLOOR }, { Vector3.new(-14, 0, 57), FLOOR } }, 0.9) == nil)
end

check("the street spawn is clear", blocked(Layout.Street.spawn.Position, 1, 1.2, 5) == nil)
check("the Foyer spawn is clear", blocked(Layout.Foyer.spawn.Position, 1, FLOOR + 1.2, FLOOR + 5) == nil)
-- Until it's earned, the Midnight Room's doorway is closed.
local closed = walk({ { Layout.RoomDoors.midnight.centre + Vector3.new(-4, 0, 0), FLOOR }, { Layout.RoomDoors.midnight.centre + Vector3.new(4, 0, 0), FLOOR } }, 1.0)
check("the Midnight Room is closed until earned", closed ~= nil)

-- Pieces laid out on the felt stay inside it and never overlap.
for count = 4, 28 do
	local slots = Layout.pieceSlots(CFrame.new(), count)
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

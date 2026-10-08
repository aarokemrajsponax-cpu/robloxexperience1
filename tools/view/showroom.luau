--!nocheck
-- The furniture showroom: builds every design of every piece in the Furniture library on a lit
-- floor, each in its own bay, and writes it for the 3D viewer, with a camera shot per bay.
--
--   rojo sourcemap default.project.json -o sourcemap.json
--   lune run tools/view/showroom.luau <world.json> <shots.json> [kind]
--   python3 tools/view/textures.py <world.json> <tex-dir>
--   node tools/view/shoot.js <world.json> <tex-dir> <three-dir> <shots.json> <out-dir>

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance, Vector3, Enum = roblox.Instance, roblox.Vector3, roblox.Enum
local rgb = roblox.Color3.fromRGB
local exportWorld = require("./export")

-- Lune's CFrame.lookAt faces away from its target; Roblox's faces toward it.
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

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
local services = {
	CollectionService = {
		AddTag = function(_, inst, tag)
			inst:AddTag(tag)
		end,
		HasTag = function(_, inst, tag)
			return inst:HasTag(tag)
		end,
		GetTagged = function()
			return {}
		end,
	},
}
local root
local function service(name)
	if services[name] then
		return services[name]
	end
	for _, child in root and rawget(root, "__node").children or {} do
		if child.name == name then
			return root[name]
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

-- Modules from the Rojo sourcemap.
local sourcemap = serde.decode("json", fs.readFile("sourcemap.json"))
local cache = {}
local proxies = {}
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
root = proxyFor(sourcemap, nil)
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
	local env = {
		script = proxy,
		require = requireModule,
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrame,
		Color3 = roblox.Color3,
		Enum = Enum,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		PhysicalProperties = roblox.PhysicalProperties,
		Font = {
			new = roblox.Font.new,
			fromName = roblox.Font.fromName,
			fromEnum = function(e)
				local ok, f = pcall(roblox.Font.fromEnum, e)
				return if ok then f else roblox.Font.new("rbxasset://fonts/families/BuilderSans.json")
			end,
		},
		game = gameShim,
	}
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

local Furniture = module("ReplicatedStorage", "Shared", "Furniture")

-- `suite house|full <world.json> <shots.json>`: the Suite's shell with every spot furnished, either
-- with the house's own pieces only, or with the finest piece for each spot. The shell is grown to
-- the Grand Scale as the house is (with the fireplace and the front doors built after), and the
-- furniture built a size up, as each guest's screen draws it.
if process.args[1] == "suite" then
	local mode = process.args[2] or "full"
	local out = process.args[3] or "suite.json"
	local shotsOut = process.args[4] or "suite-shots.json"
	local Layout = module("ReplicatedStorage", "Shared", "Layout")
	local Suite = module("ReplicatedStorage", "Shared", "Suite")
	local SuiteRoom = module("ServerScriptService", "Server", "World", "Suite")
	local SuiteFinish = module("ServerScriptService", "Server", "World", "SuiteFinish")
	local Grand = module("ServerScriptService", "Server", "World", "Grand")
	local Flush = module("ServerScriptService", "Server", "World", "Flush")
	local root = Instance.new("Folder")
	root.Name = "Maison"
	root.Parent = workspace
	-- The roofs it stands on (the rooms below), so the floor reads as it does in the house.
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Anchored = true
	roof.Size = Vector3.new(50, 1, 70)
	roof.CFrame = CFrame.new(-56, 21.5, 28)
	roof.Color = roblox.Color3.fromRGB(40, 38, 40)
	roof.Material = Enum.Material.Concrete
	roof.Parent = root
	SuiteRoom.build(root)
	Grand.apply(root, Layout.SCALE)
	SuiteFinish.build(root)
	Flush.settle(root)
	local placed = {}
	local goldKey = true
	if mode == "full" then
		for _, spot in Suite.Spots do
			local options = Suite.piecesFor(spot.id)
			local best = options[#options]
			if best then
				placed[spot.id] = best.id
			end
		end
	end
	local pieces = Suite.pieces(placed, goldKey)
	local furniture = Instance.new("Folder")
	furniture.Name = "Furniture"
	furniture.Parent = workspace
	local count = 0
	for spotId, style in pieces do
		local kind = Suite.kindOf(spotId, style)
		local cf = Layout.Suite.spots[spotId]
		local ok, err = pcall(function()
			Furniture.build(kind, furniture, cf, style, true, Layout.SUITE_FURNITURE)
		end)
		if not ok then
			print("FAIL " .. spotId .. ": " .. tostring(err))
		end
		count += 1
	end
	lighting.ClockTime = 0.2
	lighting.Brightness = 1.4
	lighting.Ambient = rgb(34, 32, 36)
	lighting.OutdoorAmbient = rgb(70, 72, 92)
	lighting.ExposureCompensation = 0.35
	exportWorld(workspace, lighting, out)
	-- (The shots are drawn in the house's drawn numbers, then grown with it.)
	local G = Layout.SCALE
	local Y = 22
	local shots = {
		{ name = "living", pos = { -38.5, Y + 7, 42 }, look = { -55, Y + 3, 55 } },
		{ name = "living-fire", pos = { -55, Y + 6.5, 42.2 }, look = { -55, Y + 4, 60 } },
		{ name = "living-back", pos = { -60, Y + 7, 58 }, look = { -42, Y + 3, 44 } },
		{ name = "gallery", pos = { -23, Y + 6, 54 }, look = { -36, Y + 4, 54 } },
		{ name = "bedroom", pos = { -46, Y + 7, 26 }, look = { -56, Y + 3, 35 } },
		{ name = "bedroom-tv", pos = { -55.6, Y + 6.5, 37 }, look = { -55.6, Y + 4, 24 } },
		{ name = "spa", pos = { -63.5, Y + 7, 25.5 }, look = { -72, Y + 3, 34 } },
		{ name = "kitchen", pos = { -42.8, Y + 7, 25 }, look = { -36, Y + 3, 34 } },
		{ name = "terrace", pos = { -36, Y + 9, 21.5 }, look = { -48, Y + 2, 2 } },
		{ name = "terrace-pool", pos = { -56, Y + 7, 12 }, look = { -42, Y + 2, 0 } },
		{ name = "screening", pos = { -58, Y + 7, 22 }, look = { -72, Y + 4, 13 } },
		{ name = "gym", pos = { -63.5, Y + 7, 5.5 }, look = { -73, Y + 3, -2 } },
		{ name = "aerial", pos = { -20, Y + 40, -30 }, look = { -55, Y, 25 } },
	}
	for _, sh in shots do
		sh.fov = 70
		sh.lights = 32
		sh.pos = { sh.pos[1] * G, sh.pos[2] * G, sh.pos[3] * G }
		sh.look = { sh.look[1] * G, sh.look[2] * G, sh.look[3] * G }
	end
	fs.writeFile(shotsOut, serde.encode("json", shots))
	print(string.format("the Suite (%s): %d pieces", mode, count))
	process.exit(0)
end

-- Every design to show: { kind, style }.
local DESIGNS = {
	{ "sofa", { model = "chesterfield", material = "Leather", colour = rgb(84, 40, 24) } },
	{ "sofa", { model = "modern", colour = rgb(214, 204, 186), accent = rgb(170, 120, 60) } },
	{ "sofa", { model = "curved", colour = rgb(30, 70, 60) } },
	{ "sofa", { model = "sectional", colour = rgb(60, 60, 66) } },
	{ "chair", { model = "wing", colour = rgb(92, 20, 30) } },
	{ "chair", { model = "club", material = "Leather", colour = rgb(84, 44, 26) } },
	{ "chair", { model = "barrel", colour = rgb(200, 180, 150) } },
	{ "chair", { model = "lounge" } },
	{ "coffeeTable", { model = "marble" } },
	{ "coffeeTable", { model = "glass" } },
	{ "coffeeTable", { model = "block" } },
	{ "bar", { model = "walnut" } },
	{ "bar", { model = "lacquer", colour = rgb(12, 12, 14) } },
	{ "bar", { model = "cart" } },
	{ "shelf", { model = "library" } },
	{ "shelf", { model = "display", colour = rgb(20, 18, 18) } },
	{ "tv", { model = "wall" } },
	{ "tv", { model = "cinema" } },
	{ "piano", {} },
	{ "chaise", {} },
	{ "desk", {} },
	{ "globe", {} },
	{ "rug", { model = "persian" } },
	{ "rug", { model = "round", colour = rgb(20, 24, 48), accent = rgb(200, 206, 214) } },
	{ "rug", { model = "deco", colour = rgb(14, 14, 16) } },
	{ "lamp", { model = "brass" } },
	{ "lamp", { model = "arc" } },
	{ "lamp", { model = "tripod" } },
	{ "lamp", { model = "crystal" } },
	{ "painting", { art = "night" } },
	{ "painting", { art = "portrait", colour = rgb(70, 46, 34) } },
	{ "painting", { art = "abstract", colour = rgb(230, 220, 200) } },
	{ "painting", { art = "landscape" } },
	{ "painting", { art = "still", colour = rgb(30, 22, 18) } },
	{ "chandelier", { model = "crystal" } },
	{ "chandelier", { model = "ring" } },
	{ "chandelier", { model = "sputnik" } },
	{ "chandelier", { model = "cascade" } },
	{ "plant", { model = "palm" } },
	{ "plant", { model = "fiddle" } },
	{ "plant", { model = "olive" } },
	{ "plant", { model = "topiary" } },
	{ "sculpture", { model = "bust" } },
	{ "sculpture", { model = "sphere", metal = true, colour = rgb(214, 176, 92), plinth = "black" } },
	{ "sculpture", { model = "twist", metal = true, colour = rgb(120, 80, 50) } },
	{ "mirror", {} },
	{ "display", {} },
	{ "aquarium", {} },
	{ "bed", { model = "classic" } },
	{ "bed", { model = "canopy" } },
	{ "bed", { model = "round", headboard = rgb(30, 30, 50) } },
	{ "bed", { model = "floating", headboard = rgb(40, 40, 44) } },
	{ "bed", { model = "royal" } },
	{ "nightstands", {} },
	{ "dresser", {} },
	{ "bench", {} },
	{ "bathtub", { model = "clawfoot" } },
	{ "bathtub", { model = "stone" } },
	{ "bathtub", { model = "sunken" } },
	{ "shower", {} },
	{ "vanity", {} },
	{ "sauna", {} },
	{ "massage", {} },
	{ "kitchen", { model = "marble" } },
	{ "kitchen", { model = "noir" } },
	{ "dining", { model = "walnut" } },
	{ "dining", { model = "marble" } },
	{ "espresso", {} },
	{ "wine", {} },
	{ "screen", {} },
	{ "recliners", {} },
	{ "gaming", {} },
	{ "arcade", { model = "classic" } },
	{ "arcade", { model = "racing" } },
	{ "arcade", { model = "pinball" } },
	{ "popcorn", {} },
	{ "treadmill", {} },
	{ "weights", {} },
	{ "benchpress", {} },
	{ "punchbag", {} },
	{ "bike", {} },
	{ "yoga", {} },
	{ "pool", { model = "infinity" } },
	{ "pool", { model = "lagoon" } },
	{ "hottub", {} },
	{ "loungers", {} },
	{ "cabana", {} },
	{ "firepit", {} },
	{ "garden", {} },
	{ "outdoorbar", {} },
	{ "statue", {} },
}

local only = process.args[3]
local out = process.args[1] or "showroom.json"
local shotsOut = process.args[2] or "showroom-shots.json"

local folder = Instance.new("Folder")
folder.Name = "Showroom"
folder.Parent = workspace
local BAY = 60
local cols = 8
local shots = {}
local problems = {}
local n = 0
for i, d in DESIGNS do
	local kind, style = d[1], d[2]
	if only and kind ~= only then
		continue
	end
	n += 1
	local col, row = (n - 1) % cols, (n - 1) // cols
	local x, z = col * BAY, row * BAY
	-- The bay: a pale floor and a back wall, lit from above and in front.
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(BAY - 2, 1, BAY - 2)
	floor.CFrame = CFrame.new(x, -0.5, z)
	floor.Color = rgb(70, 60, 52)
	floor.Material = Enum.Material.WoodPlanks
	floor.Parent = folder
	local wall = Instance.new("Part")
	wall.Anchored = true
	wall.Size = Vector3.new(BAY - 2, 16, 1)
	wall.CFrame = CFrame.new(x, 8, z + 9)
	wall.Color = rgb(40, 34, 36)
	wall.Material = Enum.Material.Plaster
	wall.Parent = folder
	local lamp = Instance.new("Part")
	lamp.Anchored = true
	lamp.Transparency = 1
	lamp.Size = Vector3.new(1, 1, 1)
	lamp.CFrame = CFrame.new(x, 13, z - 8)
	lamp.Parent = folder
	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 30
	light.Color = rgb(255, 230, 200)
	light.Parent = lamp
	local hanging = kind == "chandelier"
	local cf = if hanging then CFrame.new(x, 14, z) else (if kind == "painting" or kind == "mirror" or kind == "aquarium" or kind == "shelf" or kind == "display" or kind == "wine" then CFrame.lookAt(Vector3.new(x, if kind == "painting" then 6 else 0, z + 8.5), Vector3.new(x, if kind == "painting" then 6 else 0, z - 10)) else CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x, 0, z - 10)))
	local lo, hi
	local ok, err = pcall(function()
		local model, b = Furniture.build(kind, folder, cf, style, true)
		if model then
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local c, h = p.CFrame.Position, p.Size / 2
					local r = math.max(h.X, h.Y, h.Z)
					local a, z2 = c - Vector3.new(r, r, r), c + Vector3.new(r, r, r)
					lo = if lo then Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
					hi = if hi then Vector3.new(math.max(hi.X, z2.X), math.max(hi.Y, z2.Y), math.max(hi.Z, z2.Z)) else z2
				end
			end
			local parts = 0
			for _, p in model:GetDescendants() do
				if p:IsA("BasePart") then
					parts += 1
				end
			end
			print(string.format("%-12s %-12s %4d parts  %d seats  %d lights", kind, tostring(style.model or style.art or ""), parts, #b.seats, b.lights))
		else
			table.insert(problems, kind .. ": no such kind")
		end
	end)
	if not ok then
		table.insert(problems, kind .. " " .. tostring(style.model or "") .. ": " .. tostring(err))
	end
	-- Frame the piece: from the front and a little to the left, far enough to see all of it.
	local centre = if lo then (lo + hi) / 2 else Vector3.new(x, 2, z)
	local size = if lo then hi - lo else Vector3.new(6, 6, 6)
	local reach = math.max(size.X, size.Y * 1.3, size.Z) * 0.95 + 2
	local from = centre + Vector3.new(-reach * 0.45, reach * 0.42, -reach)
	table.insert(shots, {
		name = string.format("%02d-%s-%s", n, kind, tostring(style.model or style.art or "")),
		pos = { from.X, math.max(from.Y, 2), from.Z },
		look = { centre.X, centre.Y, centre.Z },
		fov = 50,
		lights = 6,
	})
end

lighting.ClockTime = 0.2
lighting.Brightness = 1.4
lighting.Ambient = rgb(70, 66, 70)
lighting.OutdoorAmbient = rgb(90, 92, 110)
lighting.ExposureCompensation = 0.4
exportWorld(workspace, lighting, out)
fs.writeFile(shotsOut, serde.encode("json", shots))
if #problems > 0 then
	print("\nPROBLEMS:")
	for _, p in problems do
		print("  " .. p)
	end
	process.exit(1)
end
print(string.format("%d designs built", n))

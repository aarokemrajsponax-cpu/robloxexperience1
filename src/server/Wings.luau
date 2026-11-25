--!strict
-- (Build 102) Every guest's own Suite and Vault, and the elevator that is the only way into them.
--
-- Each guest has a private wing (Shared/Wing): a real copy of the house's Suite and Vault, high
-- above the house, made when they first need it and taken away when they leave. Nobody can walk
-- there; the elevator takes a guest to their own Suite or Vault (5.5 seconds), to a friend's Suite
-- when that friend allows it (6.5 seconds), or back down to the house. The server decides every
-- journey: where a guest rides from, whether they may go where they ask, one journey at a time,
-- and where they step out. Riding with someone takes nobody along: each guest rides alone.
--
-- And it keeps watch: anyone found in a wing that isn't theirs (and isn't a friend's they were
-- let into) is taken straight home, and anyone found inside the house's own Suite or Vault (the
-- doors are sealed now; those rooms are only the pattern the wings are made from) is put back
-- outside the door. Other guests, their brainrots and their pets are never in your wing, because
-- they are somewhere else entirely, not because they are hidden.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Furniture = require(ReplicatedStorage.Shared.Furniture)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Wing = require(ReplicatedStorage.Shared.Wing)
local Friends = require(script.Parent.Friends)
local Integrity = require(script.Parent.Integrity)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Wings = {}

-- Set by Main: whether a host lets this guest into their Suite now (server/Showcase: friends,
-- invited friends only, or nobody).
Wings.mayVisit = function(_host: Player, _visitor: Player): (boolean, string?)
	return false, "Their Suite isn't open just now."
end
-- Set by Main: whether a guest is busy where a journey can't start (seated at a table, inside an
-- attraction, on the jet): the reason, or nil.
Wings.busy = function(_player: Player): string?
	return nil
end
-- Set by Main: a guest has arrived in a friend's Suite (the Badge Book), and whose Suite a guest
-- is in now (SuiteVisits tells their screen how it's furnished).
Wings.visited = function(_visitor: Player, _host: Player) end
Wings.hostChanged = function(_player: Player, _host: Player?) end

-- The house machinery that must never act on a copy: the Vault's door to the Foyer and the old
-- lift between the floors (in a wing the lift's bell calls the elevator instead).
local OFF_TAGS = { "VaultDoor", "VaultDoorPart", "LiftCall", "LiftLeaf" }

local template: Folder? = nil
local holder: Folder? = nil
local own: { [Player]: number } = {}
local owner: { [number]: Player? } = {}
local built: { [number]: Model } = {}
local guestOf: { [Player]: Player } = {}
local rides: { [Player]: { to: string, ends: number } } = {}
local rested: { [Player]: number } = {}
local strays: { [Player]: number } = {} -- (Build 105) watches in a row out of the rooms
local lastFloor: { [Player]: string } = {} -- the last floor of their wing a guest stood on
local leaving: { [Player]: boolean } = {}

local REST = 1 -- seconds after arriving before another journey can start
local REACH = 16 -- how near the elevator's call a guest must stand to ride from it

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function notice(player: Player, title: string, line: string)
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = title, line = line })
end

---------------------------------------------------------------------------------------------------
-- The pattern, and the wings made from it
---------------------------------------------------------------------------------------------------

local function wall(parent: Instance, name: string, from: Vector3, to: Vector3, visible: boolean)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = Vector3.new(math.abs(to.X - from.X), math.abs(to.Y - from.Y), math.abs(to.Z - from.Z))
	p.CFrame = CFrame.new((from + to) / 2)
	p.Material = Enum.Material.Wood
	p.Color = Color3.fromRGB(46, 30, 22)
	p.Transparency = if visible then 0 else 1
	p.CastShadow = visible
	p.Parent = parent
	return p
end

-- (Build 104) A wing's own grounds: one residence round the Suite, not a garden beside it. The
-- Suite stands in a winter garden of its own under a glass roof on a gold lattice: a planted lawn
-- all round it at its floor, a stone path, cypresses and lanterns, two benches. On the north and
-- west the residence's walls are the Suite's own pale stone, pilastered and corniced; on the
-- south and east (the terrace's side) they're glass from floor to roof between gold mullions, and
-- beyond them, far below, the city at dusk (drawn on the screen of whoever stands in this wing:
-- World/SuiteCity). Nothing is open: walls to the roof all round, the roof over it all, and an
-- unseen barrier above, so nobody leaves, falls or climbs out. The Vault, below, sits on a floor of
-- its own, walled in unseen. (Its size follows the Suite's own: the house is built at a scale.)
local function gardenBounds(): { minX: number, maxX: number, minZ: number, maxZ: number, wall: number, s: number }
	local z = Layout.Suite.zone
	local s = math.max(1, (z.max.X - z.min.X) / 47)
	-- (Build 105) The same box the rest of the house knows as the Suite's grounds (shared/Layout).
	local g = Layout.suiteGrounds()
	return {
		minX = g.min.X,
		maxX = g.max.X,
		minZ = g.min.Z,
		maxZ = g.max.Z,
		wall = math.floor(Layout.Suite.height + 4 * s + 0.5),
		s = s,
	}
end
local function gardenPart(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function garden(parent: Instance)
	local G = gardenBounds()
	local k = G.s
	local y = Layout.Suite.floorY
	local f = Instance.new("Folder")
	f.Name = "Garden"
	f.Parent = parent
	local cx, cz = (G.minX + G.maxX) / 2, (G.minZ + G.maxZ) / 2
	local w, d = G.maxX - G.minX, G.maxZ - G.minZ
	local LAWN = Color3.fromRGB(78, 116, 62)
	local STONE = Color3.fromRGB(214, 203, 182)
	local COPING = Color3.fromRGB(236, 228, 212)
	local HEDGE = Color3.fromRGB(46, 78, 44)
	-- The lawn: just under the Suite's own floors, so it shows only where they don't reach.
	gardenPart(f, "Lawn", Vector3.new(w, 1, d), CFrame.new(cx, y - 0.56, cz), LAWN, Enum.Material.Grass)
	-- A stone path along the walls, a step in from them.
	type Slab = { name: string, size: Vector3, at: Vector3 }
	local paths: { Slab } = {
		{ name = "PathN", size = Vector3.new(w - 6 * k, 0.2, 3 * k), at = Vector3.new(cx, y - 0.02, G.maxZ - 5 * k) },
		{ name = "PathS", size = Vector3.new(w - 6 * k, 0.2, 3 * k), at = Vector3.new(cx, y - 0.02, G.minZ + 5 * k) },
		{ name = "PathW", size = Vector3.new(3 * k, 0.2, d - 6 * k), at = Vector3.new(G.minX + 5 * k, y - 0.02, cz) },
		{ name = "PathE", size = Vector3.new(3 * k, 0.2, d - 6 * k), at = Vector3.new(G.maxX - 5 * k, y - 0.02, cz) },
	}
	for _, side in paths do
		gardenPart(f, side.name, side.size, CFrame.new(side.at), STONE, Enum.Material.Limestone)
	end
	-- The residence's walls (stone on the north and west, glass toward the city on the south and
	-- east), each to the roof, and the unseen barrier above them.
	local H = G.wall
	local GOLD = Color3.fromRGB(206, 168, 92)
	type Wall = { name: string, size: Vector3, at: Vector3, inward: Vector3, glass: boolean }
	local walls: { Wall } = {
		{ name = "WallN", size = Vector3.new(w + 4, H, 2), at = Vector3.new(cx, y + H / 2, G.maxZ + 1), inward = Vector3.new(0, 0, -1), glass = false },
		{ name = "WallS", size = Vector3.new(w + 4, H, 2), at = Vector3.new(cx, y + H / 2, G.minZ - 1), inward = Vector3.new(0, 0, 1), glass = true },
		{ name = "WallW", size = Vector3.new(2, H, d), at = Vector3.new(G.minX - 1, y + H / 2, cz), inward = Vector3.new(1, 0, 0), glass = false },
		{ name = "WallE", size = Vector3.new(2, H, d), at = Vector3.new(G.maxX + 1, y + H / 2, cz), inward = Vector3.new(-1, 0, 0), glass = true },
	}
	for _, wl in walls do
		local size, at, inward = wl.size, wl.at, wl.inward
		local alongX = size.X > size.Z
		local long = math.max(size.X, size.Z) - 12 * k
		local function along(t: number): Vector3
			return if alongX then Vector3.new(t, 0, 0) else Vector3.new(0, 0, t)
		end
		if wl.glass then
			-- Glass from the floor to the roof, gold mullions every few studs, a gold sill and head.
			local pane = gardenPart(f, wl.name, size, CFrame.new(at), Color3.fromRGB(176, 204, 222), Enum.Material.Glass)
			pane.Transparency = 0.8
			pane.Reflectance = 0.12
			pane.CastShadow = false
			local bays = math.max(3, math.floor(math.max(size.X, size.Z) / (9 * k)))
			for i = 0, bays do
				local t = -math.max(size.X, size.Z) / 2 + math.max(size.X, size.Z) * i / bays
				gardenPart(f, "Mullion", if alongX then Vector3.new(0.5 * k, H, 0.9) else Vector3.new(0.9, H, 0.5 * k), CFrame.new(at + along(t)), GOLD, Enum.Material.Metal, false)
			end
			for _, yy in { -H / 2 + 0.3, H / 2 - 0.3, -H / 2 + H * 0.62 } do
				gardenPart(f, "Rail", if alongX then Vector3.new(size.X, 0.5, 1.1) else Vector3.new(1.1, 0.5, size.Z), CFrame.new(at + Vector3.new(0, yy, 0)), GOLD, Enum.Material.Metal, false)
			end
			-- (Low planters at its foot: nothing in the way of the view.)
			local planter = Vector3.new(if alongX then size.X - 8 * k else 1.6 * k, 0.9 * k, if alongX then 1.6 * k else size.Z - 8 * k)
			gardenPart(f, wl.name .. "Planter", planter, CFrame.new(at + inward * 2 * k + Vector3.new(0, -H / 2 + 0.45 * k, 0)), Color3.fromRGB(58, 96, 52), Enum.Material.Grass)
		else
			gardenPart(f, wl.name, size, CFrame.new(at), STONE, Enum.Material.Sandstone)
			gardenPart(f, wl.name .. "Cornice", Vector3.new(size.X + 0.8, 0.8, size.Z + 0.8), CFrame.new(at + Vector3.new(0, H / 2 - 0.4, 0) + inward * 0.4), COPING, Enum.Material.Marble, false)
			local hedge = Vector3.new(if alongX then size.X - 8 * k else 2 * k, 2.6 * k, if alongX then 2 * k else size.Z - 8 * k)
			gardenPart(f, wl.name .. "Hedge", hedge, CFrame.new(at + inward * 2.2 * k + Vector3.new(0, -H / 2 + 1.3 * k, 0)), HEDGE, Enum.Material.Grass)
			-- Pilasters in pale marble along its face, so it reads as the residence's wall.
			local piers = math.max(2, math.floor(long / (16 * k)))
			for i = 0, piers do
				local t = -long / 2 + long * i / piers
				gardenPart(f, "Pilaster", if alongX then Vector3.new(1.8 * k, H, 0.8 * k) else Vector3.new(0.8 * k, H, 1.8 * k), CFrame.new(at + inward * 1.2 + along(t)), COPING, Enum.Material.Marble, false)
			end
			-- Cypresses along it, a lantern by every third.
			local count = math.max(2, math.floor(long / (12 * k)))
			for i = 0, count do
				local t = -long / 2 + long * i / count
				local base = at + inward * 4.6 * k + along(t) + Vector3.new(0, -H / 2, 0)
				gardenPart(f, "CypressTrunk", Vector3.new(0.7 * k, 2 * k, 0.7 * k), CFrame.new(base + Vector3.new(0, k, 0)), Color3.fromRGB(92, 66, 44), Enum.Material.Wood, false)
				local crown = gardenPart(f, "Cypress", Vector3.new(11 * k, 3.2 * k, 3.2 * k), CFrame.new(base + Vector3.new(0, 7.5 * k, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(38, 70, 40), Enum.Material.Grass, false)
				crown.Shape = Enum.PartType.Cylinder
				if i % 3 == 0 then
					local lamp = gardenPart(f, "Lantern", Vector3.new(0.9 * k, 1.3 * k, 0.9 * k), CFrame.new(at + inward * 1.5 + along(t + 9 * k) + Vector3.new(0, 1.5 * k, 0)), Color3.fromRGB(255, 214, 150), Enum.Material.Neon, false)
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 200, 140)
					light.Brightness = 0.9
					light.Range = 16 * k
					light.Shadows = false
					light.Parent = lamp
				end
			end
		end
		local barrier = gardenPart(f, wl.name .. "Barrier", Vector3.new(size.X, 140, size.Z), CFrame.new(at + Vector3.new(0, H / 2 + 70, 0)), STONE, Enum.Material.SmoothPlastic)
		barrier.Transparency = 1
		barrier.CastShadow = false
		barrier.CanQuery = false
	end
	-- The glass roof over it all on a gold lattice: nothing open to the sky, nothing to climb out by.
	local roof = gardenPart(f, "GlassRoof", Vector3.new(w + 4, 0.6, d + 4), CFrame.new(cx, y + H + 0.3, cz), Color3.fromRGB(190, 212, 226), Enum.Material.Glass)
	roof.Transparency = 0.86
	roof.Reflectance = 0.1
	roof.CastShadow = false
	local spanX = math.max(2, math.floor(w / (14 * k)))
	for i = 0, spanX do
		gardenPart(f, "RoofBeam", Vector3.new(0.5 * k, 0.6, d + 4), CFrame.new(G.minX - 2 + (w + 4) * i / spanX, y + H - 0.1, cz), GOLD, Enum.Material.Metal, false)
	end
	local spanZ = math.max(2, math.floor(d / (14 * k)))
	for i = 0, spanZ do
		gardenPart(f, "RoofBeam", Vector3.new(w + 4, 0.6, 0.5 * k), CFrame.new(cx, y + H - 0.1, G.minZ - 2 + (d + 4) * i / spanZ), GOLD, Enum.Material.Metal, false)
	end
	-- Two benches on the lawn by the north wall, to sit and look at the house.
	for _, x in { cx - 14 * k, cx + 14 * k } do
		local at = Vector3.new(x, y, G.maxZ - 9 * k)
		gardenPart(f, "BenchSeat", Vector3.new(5, 0.4, 1.6), CFrame.new(at + Vector3.new(0, 1.4, 0)), Color3.fromRGB(110, 76, 48), Enum.Material.Wood)
		gardenPart(f, "BenchBack", Vector3.new(5, 1.6, 0.3), CFrame.new(at + Vector3.new(0, 2.4, 0.75)), Color3.fromRGB(110, 76, 48), Enum.Material.Wood)
		for _, sx in { -2.2, 2.2 } do
			gardenPart(f, "BenchLeg", Vector3.new(0.3, 1.2, 1.4), CFrame.new(at + Vector3.new(sx, 0.6, 0)), Color3.fromRGB(40, 34, 30), Enum.Material.Metal)
		end
		local top = CFrame.lookAt(at + Vector3.new(0, 1.6, 0), at + Vector3.new(0, 1.6, -10))
		Furniture.seatsOn(f, "BenchSeats", { top * CFrame.new(-1.2, 0, 0), top * CFrame.new(1.2, 0, 0) }, "The garden bench", 1.6)
	end
	-- (Build 105) By the south wall, a brass plaque where the Infinity Pool goes (it opens the
	-- Suite's furnishing, where the pool is offered); gone from a wing whose pool is built.
	local plaque = gardenPart(f, "PoolPlaque", Vector3.new(2.4 * k, 1.4 * k, 0.3), CFrame.new(cx, y + 1.6 * k, G.minZ + 8.5 * k) * CFrame.Angles(math.rad(-20), 0, 0), GOLD, Enum.Material.Metal, false)
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "PoolPrompt"
	pp.ActionText = "The Infinity Pool"
	pp.ObjectText = "57,000 Gilt or 150 Gems"
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.GamepadKeyCode = Enum.KeyCode.ButtonX
	pp.HoldDuration = 0
	pp.MaxActivationDistance = 10
	pp.RequiresLineOfSight = false
	pp.Style = Enum.ProximityPromptStyle.Custom
	pp.Parent = plaque
	CollectionService:AddTag(plaque, "SuiteFurnish")
	-- The Vault, below: a floor under it all, and unseen walls round it.
	local V = Layout.Vault
	local vx, vz = (V.minX + V.maxX) / 2, (V.minZ + V.maxZ) / 2
	gardenPart(f, "VaultFloor", Vector3.new(V.maxX - V.minX + 16, 1, V.maxZ - V.minZ + 16), CFrame.new(vx, Layout.FLOOR - 0.56, vz), Color3.fromRGB(30, 26, 24), Enum.Material.Slate)
	local vaultSides: { Slab } = {
		{ name = "S", size = Vector3.new(V.maxX - V.minX + 16, 22, 1), at = Vector3.new(vx, Layout.FLOOR + 11, V.minZ - 8) },
		{ name = "N", size = Vector3.new(V.maxX - V.minX + 16, 22, 1), at = Vector3.new(vx, Layout.FLOOR + 11, V.maxZ + 8) },
		{ name = "W", size = Vector3.new(1, 22, V.maxZ - V.minZ + 16), at = Vector3.new(V.minX - 8, Layout.FLOOR + 11, vz) },
		{ name = "E", size = Vector3.new(1, 22, V.maxZ - V.minZ + 16), at = Vector3.new(V.maxX + 8, Layout.FLOOR + 11, vz) },
	}
	for _, side in vaultSides do
		local b = gardenPart(f, "VaultBarrier" .. side.name, side.size, CFrame.new(side.at), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		b.Transparency = 1
		b.CastShadow = false
		b.CanQuery = false
	end
end

-- (Build 105) Whether a guest owns the Infinity Pool (set by Main, from their saved record).
Wings.hasPool = function(_player: Player): boolean
	return false
end

-- The Infinity Pool in a wing (house coordinates moved up by `up`): along the garden's south glass,
-- its water level with an unseen lip at the glass so it seems to run on into the city; coping and
-- steps on the house side, lights under the water, loungers and parasols on its deck. The garden's
-- south path and the planter there make way for it, and the plaque that offered it goes.
local function buildPool(model: Instance, up: Vector3)
	if model:FindFirstChild("InfinityPool") then
		return
	end
	local G = gardenBounds()
	local k = G.s
	local y = Layout.Suite.floorY
	local garden = model:FindFirstChild("Garden")
	if garden then
		for _, name in { "PathS", "WallSPlanter", "PoolPlaque" } do
			local old = garden:FindFirstChild(name)
			if old then
				old:Destroy()
			end
		end
	end
	local f = Instance.new("Folder")
	f.Name = "InfinityPool"
	local cx = (G.minX + G.maxX) / 2
	local length = (G.maxX - G.minX) - 10 * k
	local z0, z1 = G.minZ + 0.2, G.minZ + 7 * k
	local depth = z1 - z0
	local cz = (z0 + z1) / 2
	local WATER = Color3.fromRGB(64, 186, 226)
	local TILE = Color3.fromRGB(40, 132, 176)
	local COPING = Color3.fromRGB(240, 234, 222)
	local DECK = Color3.fromRGB(196, 170, 132)
	local GOLD = Color3.fromRGB(206, 168, 92)
	local function at(x: number, yy: number, z: number): CFrame
		return CFrame.new(Vector3.new(x, yy, z) + up)
	end
	-- The basin's floor and walls (its floor at the lawn, its walls a step high round three sides).
	gardenPart(f, "PoolFloor", Vector3.new(length, 0.3, depth), at(cx, y + 0.1, cz), TILE, Enum.Material.CeramicTiles)
	gardenPart(f, "CopingN", Vector3.new(length + 2.4, 1.5, 1.2), at(cx, y + 0.75, z1 + 0.6), COPING, Enum.Material.Marble)
	gardenPart(f, "CopingW", Vector3.new(1.2, 1.5, depth), at(cx - length / 2 - 0.6, y + 0.75, cz), COPING, Enum.Material.Marble)
	gardenPart(f, "CopingE", Vector3.new(1.2, 1.5, depth), at(cx + length / 2 + 0.6, y + 0.75, cz), COPING, Enum.Material.Marble)
	-- The infinity edge: a lip just under the water at the glass, the water spilling over it in light.
	gardenPart(f, "Lip", Vector3.new(length, 1.2, 0.4), at(cx, y + 0.6, z0 + 0.2), TILE, Enum.Material.CeramicTiles)
	local spill = gardenPart(f, "Spill", Vector3.new(length, 0.08, 0.5), at(cx, y + 1.26, z0 + 0.15), Color3.fromRGB(170, 236, 255), Enum.Material.Neon, false)
	spill.Transparency = 0.35
	spill.CastShadow = false
	-- The water: walked into, never stood on.
	local water = gardenPart(f, "Water", Vector3.new(length, 1.05, depth - 0.4), at(cx, y + 0.78, cz + 0.2), WATER, Enum.Material.Glass, false)
	water.Transparency = 0.42
	water.Reflectance = 0.18
	water.CastShadow = false
	water.CanQuery = false
	water.CanTouch = false
	water:SetAttribute("PoolWater", true)
	-- Steps in from the deck (out of the water and back over the coping without a jump).
	for i, sx in { -length / 4, length / 4 } do
		gardenPart(f, "StepOut" .. i, Vector3.new(4 * k, 0.75, 1.4), at(cx + sx, y + 0.375, z1 + 1.9), COPING, Enum.Material.Marble)
		gardenPart(f, "StepIn" .. i, Vector3.new(4 * k, 0.75, 1.4), at(cx + sx, y + 0.625, z1 - 0.7), COPING, Enum.Material.Marble)
	end
	-- Lights under the water.
	local lights = math.max(3, math.floor(length / (14 * k)))
	for i = 1, lights do
		local x = cx - length / 2 + length * (i - 0.5) / lights
		local lamp = gardenPart(f, "PoolLight", Vector3.new(1.2, 0.12, 1.2), at(x, y + 0.31, cz), Color3.fromRGB(170, 230, 255), Enum.Material.Neon, false)
		lamp.CastShadow = false
		local light = Instance.new("SurfaceLight")
		light.Face = Enum.NormalId.Top
		light.Color = Color3.fromRGB(120, 210, 255)
		light.Brightness = 2.2
		light.Range = 12 * k
		light.Angle = 120
		light.Shadows = false
		light.Parent = lamp
	end
	-- The deck: teak boards from the coping to the Suite, loungers and parasols along it.
	local deckD = (G.minZ + 12 * k) - (z1 + 1.2)
	if deckD > 1 then
		gardenPart(f, "Deck", Vector3.new(length + 2.4, 0.2, deckD), at(cx, y - 0.02, z1 + 1.2 + deckD / 2), DECK, Enum.Material.WoodPlanks)
	end
	local loungers = math.max(2, math.floor(length / (12 * k)))
	for i = 1, loungers do
		local x = cx - length / 2 + length * (i - 0.5) / loungers
		local base = Vector3.new(x, y, z1 + 4.4 * k)
		gardenPart(f, "LoungerFrame", Vector3.new(2.6, 0.5, 6), at(base.X, y + 0.65, base.Z), Color3.fromRGB(236, 232, 224), Enum.Material.SmoothPlastic)
		gardenPart(f, "LoungerCushion", Vector3.new(2.4, 0.3, 4.2), at(base.X, y + 1.05, base.Z - 0.7), Color3.fromRGB(250, 248, 242), Enum.Material.Fabric, false)
		local back = gardenPart(f, "LoungerBack", Vector3.new(2.4, 0.3, 2.2), at(base.X, y + 1.7, base.Z + 2.2) * CFrame.Angles(math.rad(-40), 0, 0), Color3.fromRGB(250, 248, 242), Enum.Material.Fabric, false)
		back.CastShadow = false
		gardenPart(f, "Towel", Vector3.new(1.6, 0.06, 1.2), at(base.X, y + 1.23, base.Z - 1.6), if i % 2 == 0 then Color3.fromRGB(64, 120, 186) else GOLD, Enum.Material.Fabric, false)
		-- (A seat and its own Sit prompt for each lounger: one prompt for the whole row would only
		-- show by the middle one.)
		Furniture.seatsOn(f, "PoolLounger" .. i, { CFrame.lookAt(Vector3.new(base.X, y + 1.2, base.Z) + up, Vector3.new(base.X, y + 1.2, base.Z - 10) + up) }, "A lounger by the pool", 1.6)
		if i < loungers then
			local px = x + length / loungers / 2
			gardenPart(f, "ParasolPole", Vector3.new(0.25, 7, 0.25), at(px, y + 3.5, base.Z), GOLD, Enum.Material.Metal, false)
			local canopy = gardenPart(f, "Parasol", Vector3.new(1.2, 6.5, 6.5), at(px, y + 7, base.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(246, 240, 226), Enum.Material.Fabric, false)
			canopy.Shape = Enum.PartType.Cylinder
		end
	end
	f.Parent = model
end
Wings.buildPool = buildPool

-- (Build 105) Builds a guest's Infinity Pool in their own wing, once they own it (bought just now,
-- or found in their record when they arrive).
function Wings.setPool(player: Player)
	local slot = own[player]
	local m = slot and built[slot]
	if slot and m and m.Parent and Wings.hasPool(player) then
		buildPool(m, Wing.offset(slot))
	end
end

-- What the copies are made from: the house's own Suite, Vault and lift landings, with the
-- house's doorways closed (in a wing they would open onto nothing) and the house's machinery off.
function Wings.prepare(): boolean
	local maison = Workspace:FindFirstChild("Maison")
	if not maison then
		return false
	end
	local t = Instance.new("Folder")
	t.Name = "WingPattern"
	for _, name in { "Suite", "Vault", "Passages" } do
		local m = maison:FindFirstChild(name)
		if m then
			local ok, copy = pcall(function()
				return m:Clone()
			end)
			if ok and copy then
				copy.Parent = t
			end
		end
	end
	local passages = t:FindFirstChild("Passages")
	local door = passages and passages:FindFirstChild("VaultDoor")
	if door then
		door:Destroy()
	end
	for _, d in t:GetDescendants() do
		for _, tag in OFF_TAGS do
			if CollectionService:HasTag(d, tag) then
				CollectionService:RemoveTag(d, tag)
			end
		end
	end
	-- The Vault's south side is the Foyer's back wall in the house: a wall of its own here. And
	-- the gallery's far end, which opens onto the Club hall in the house.
	local V = Layout.Vault
	local seals = Instance.new("Folder")
	seals.Name = "Seals"
	seals.Parent = t
	wall(seals, "VaultSouth", Vector3.new(V.minX - 2, Layout.FLOOR - 1, 41.2), Vector3.new(V.maxX + 2, Layout.FLOOR + V.height + 1, 43.2), true)
	local d = Layout.Suite.door
	wall(seals, "GalleryEnd", Vector3.new(d.X - 0.4, d.Y - 1, d.Z - 5), Vector3.new(d.X + 0.6, Layout.Suite.floorY + Layout.Suite.height + 2, d.Z + 5), true)
	garden(t)
	-- (Kept out of the world: only copies of it stand anywhere.)
	template = t
	return true
end

local function folder(): Folder
	local f = holder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "PrivateWings"
	nf.Parent = Workspace
	holder = nf
	return nf
end

-- Vector3/CFrame attributes that are offsets, not places (World/Grand keeps the same list).
local RELATIVE = { Slide = true, FromHinge = true }

-- Moves every part of a copy up to its wing, and every place written on it with it.
-- (Build 105) Until now only a lift door's "Closed" moved: a Vault cabinet's "Frame" (where its
-- shelves are) stayed down in the house, so a guest's own pieces were set out in the house's
-- sealed Vault and their wing's cabinets stood empty; a door's "Hinge" stayed behind too.
local function lift(model: Instance, by: Vector3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = d.CFrame + by
		end
		for name, v in d:GetAttributes() do
			if not RELATIVE[name] then
				if typeof(v) == "CFrame" then
					d:SetAttribute(name, v + by)
				elseif typeof(v) == "Vector3" then
					d:SetAttribute(name, v + by)
				end
			end
		end
	end
end
Wings.lift = lift

-- The elevator's bell in a wing (the old lift's push): rings for the guest standing at it.
local function wireCalls(model: Model, slot: number)
	for _, d in model:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "LiftPrompt" then
			d.ActionText = "Elevator"
			d.ObjectText = "Choose a floor"
			d.Triggered:Connect(function(player: Player)
				Wings.menu(player, slot)
			end)
		end
	end
end

-- Wing `slot`, made if it isn't there yet.
function Wings.ensure(slot: number): Model?
	local m = built[slot]
	if m and m.Parent then
		return m
	end
	local t = template
	if not t then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Wing" .. slot
	model:SetAttribute("Wing", slot)
	for _, child in t:GetChildren() do
		child:Clone().Parent = model
	end
	lift(model, Wing.offset(slot))
	wireCalls(model, slot)
	-- (Build 105) Its owner's Infinity Pool, if they have one.
	local who = owner[slot]
	if who and Wings.hasPool(who) then
		buildPool(model, Wing.offset(slot))
	end
	model.Parent = folder()
	built[slot] = model
	return model
end

-- Each guest's own wing number, from the moment they arrive.
function Wings.slotOf(player: Player): number?
	return own[player]
end

local function claim(player: Player): number?
	local s = own[player]
	if s then
		return s
	end
	if leaving[player] then
		return nil
	end
	for k = 0, Wing.MAX - 1 do
		if owner[k] == nil then
			owner[k] = player
			own[player] = k
			-- (Their screen keeps their own wing drawn, always.)
			player:SetAttribute("Wing", k)
			return k
		end
	end
	return nil
end

-- Where a guest steps out: in front of the elevator's doors on that floor, facing into the room.
function Wings.arrival(slot: number, floor: string): CFrame
	local at = (Layout.Lift :: any)[floor] or Layout.Lift.suite
	local base: Vector3 = at.centre
	local out: Vector3 = at.out
	local spot = base + out * 3.5 + Vector3.new(0, 3, 0) + Wing.offset(slot)
	return CFrame.lookAt(spot, spot + out)
end

-- Where a guest stands back in the house: outside the Vault's door, facing the Foyer.
function Wings.houseArrival(): CFrame
	local d = Layout.Vault.door
	local spot = Vector3.new(d.X, Layout.FLOOR + 3, d.Z - 6)
	return CFrame.lookAt(spot, spot - Vector3.new(0, 0, 1))
end

-- The wing a guest stands in now (theirs, a friend's, or none), and the room there.
function Wings.where(player: Player): (number?, string?)
	local root = rootOf(player)
	if not root then
		return nil, nil
	end
	local _, k = Wing.toHouse(root.Position)
	if not k then
		return nil, nil
	end
	local zone = Layout.zoneAt(root.Position)
	return k, if zone == "suite" or zone == "vault" then zone else nil
end

-- Whose Suite a guest is visiting now (nil: their own, or none).
function Wings.hostOf(player: Player): Player?
	return guestOf[player]
end

---------------------------------------------------------------------------------------------------
-- The elevator
---------------------------------------------------------------------------------------------------

-- Where a guest stands in their own wing's Suite or Vault (the wing made ready), or nil.
function Wings.homeSpot(player: Player, floor: string?): CFrame?
	local slot = claim(player)
	if not slot or not Wings.ensure(slot) then
		return nil
	end
	guestOf[player] = nil
	return Wings.arrival(slot, floor or "suite")
end

-- Puts a guest straight into their own wing (a returning guest arriving, or sent home): no ride.
function Wings.place(player: Player, floor: string?): boolean
	local slot = claim(player)
	local character = player.Character
	if not slot or not character or not Wings.ensure(slot) then
		return false
	end
	guestOf[player] = nil
	Wings.hostChanged(player, nil)
	Integrity.teleport(player, character, Wings.arrival(slot, floor or "suite"))
	return true
end

-- Whether a journey is under way for this guest.
function Wings.riding(player: Player): boolean
	return rides[player] ~= nil
end

-- A guest asks to ride: `to` is "suite" or "vault" (their own), "friend" (with `host`), or
-- "house". Returns whether the journey began, and why not.
function Wings.ride(player: Player, to: string, host: Player?): (boolean, string?)
	local seconds = Wing.SECONDS[to]
	if not seconds then
		return false, "There's no such floor."
	end
	if rides[player] then
		return false, "You're already on your way."
	end
	if rested[player] and os.clock() - (rested[player] :: number) < REST then
		return false, "One moment."
	end
	local busy = Wings.busy(player)
	if busy then
		return false, busy
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or not rootOf(player) then
		return false, "Not just now."
	end
	local slot = claim(player)
	if not slot then
		return false, "The elevator is busy. Try again in a moment."
	end
	local destination: number = slot
	local floor = if to == "vault" then "vault" else "suite"
	if to == "friend" then
		if not host or host == player or host.Parent ~= Players then
			return false, "That guest has left the house."
		end
		if not Friends.are(player, host) then
			return false, "Only friends on Roblox may visit each other's Suites."
		end
		local may, why = Wings.mayVisit(host, player)
		if not may then
			return false, why or "Their Suite isn't open just now."
		end
		local hs = claim(host)
		if not hs then
			return false, "Their Suite isn't open just now."
		end
		destination = hs
	end
	if to ~= "house" and not Wings.ensure(destination) then
		return false, "Not just now."
	end
	local started = os.clock()
	rides[player] = { to = to, ends = started + seconds }
	-- (The friend's wing drawn on the visitor's screen before the doors open on it.)
	player:SetAttribute("WingVisit", if to == "friend" then destination else nil)
	Remotes.event("Guest"):FireClient(player, {
		op = "elevator",
		to = to,
		seconds = seconds,
		name = if to == "friend" and host then Names.of(host) .. "'s Suite" elseif to == "vault" then "Your Vault" elseif to == "house" then "The house" else "Your Suite",
		floor = if to == "house" then "L" elseif to == "vault" then "V" else "PH",
	})
	task.delay(seconds, function()
		local ride = rides[player]
		if not ride or player.Parent ~= Players then
			rides[player] = nil
			return
		end
		rides[player] = nil
		rested[player] = os.clock()
		local c = player.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if not c or not h or h.Health <= 0 then
			return
		end
		local at: CFrame
		local visiting: Player? = nil
		if to == "house" then
			at = Wings.houseArrival()
		elseif to == "friend" and host then
			-- (Asked again at the door: a host who closed their Suite on the way up closes it.)
			local still = host.Parent == Players and Friends.are(player, host) and (Wings.mayVisit(host, player))
			if still and own[host] then
				at = Wings.arrival(own[host] :: number, "suite")
				visiting = host
			else
				notice(player, "Your Suite", "Their Suite closed to visitors on the way up, so this is your own.")
				at = Wings.arrival(slot, "suite")
			end
		else
			at = Wings.arrival(slot, floor)
		end
		if visiting then
			guestOf[player] = visiting
		else
			guestOf[player] = nil
			player:SetAttribute("WingVisit", nil)
		end
		Wings.hostChanged(player, visiting)
		Integrity.teleport(player, c, at)
		Remotes.event("Guest"):FireClient(player, { op = "elevatorArrived", to = to })
		if visiting then
			notice(visiting, "A visitor", Names.of(player) .. " is visiting your Suite.")
			Wings.visited(player, visiting)
		end
	end)
	return true, nil
end

-- The floors this guest may choose, for the elevator's panel: their own Suite and Vault, the
-- house, and each friend in the house whose Suite is open to them.
function Wings.floors(player: Player): { [string]: any }
	local friends = {}
	for _, f in Friends.inServer(player) do
		local may = Wings.mayVisit(f, player)
		table.insert(friends, { userId = f.UserId, name = Names.of(f), open = may == true })
	end
	local k, room = Wings.where(player)
	local here = if k == nil then "house" elseif guestOf[player] then "friend" else room or "suite"
	return { here = here, friends = friends, seconds = Wing.SECONDS }
end

-- Shows the elevator's panel on a guest's screen (they pressed a call button).
function Wings.menu(player: Player, slot: number?)
	-- (A wing's own bell is for those allowed in that wing: its owner, or their visitor.)
	if slot ~= nil then
		local k = Wings.where(player)
		if k ~= slot then
			return
		end
	end
	Remotes.event("Guest"):FireClient(player, { op = "elevatorMenu", floors = Wings.floors(player) })
end

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 3, 0)
	if not r then
		RemoteGuard.reject(player, "elevatorAsk", "malformed")
		return { ok = false }
	end
	if r.op == "floors" then
		return { ok = true, floors = Wings.floors(player) }
	elseif r.op == "ride" then
		local to = RemoteGuard.string(r.to, 12)
		if to ~= "suite" and to ~= "vault" and to ~= "house" and to ~= "friend" then
			return { ok = false, why = "There's no such floor." }
		end
		local host: Player? = nil
		if to == "friend" then
			local id = RemoteGuard.number(r.userId, -1e15, 1e15, true)
			host = if id then Players:GetPlayerByUserId(id) else nil
		end
		local ok, why = Wings.ride(player, to :: string, host)
		return { ok = ok, why = why }
	end
	return { ok = false }
end

---------------------------------------------------------------------------------------------------
-- The watch
---------------------------------------------------------------------------------------------------

-- May this guest stand in wing `k`?
local function allowed(player: Player, k: number): boolean
	if own[player] == k then
		return true
	end
	local host = guestOf[player]
	if host and own[host] == k and host.Parent == Players and Friends.are(player, host) then
		return (Wings.mayVisit(host, player))
	end
	return false
end

-- Everyone where they may be. Returns how many were moved (for tests).
function Wings.watch(): number
	local moved = 0
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local character = player.Character
		if not root or not character or rides[player] or leaving[player] then
			continue
		end
		local house, k = Wing.toHouse(root.Position)
		if k and allowed(player, k) then
			-- (Build 105) Never out of the rooms: a guest who has slipped through a wall, over the
			-- glass or off the edge of their wing (anywhere in it that isn't its Suite or its Vault)
			-- is back at the elevator of the floor they were last on, within a second.
			local zone = Layout.zoneAt(root.Position)
			if zone == "suite" or zone == "vault" then
				lastFloor[player] = zone
				strays[player] = nil
			else
				strays[player] = (strays[player] or 0) + 1
				if strays[player] >= 2 then
					strays[player] = nil
					moved += 1
					Integrity.teleport(player, character, Wings.arrival(k, lastFloor[player] or "suite"))
					notice(player, "Your Suite", "That's the edge of your wing: you're back inside.")
				end
			end
		elseif k then
			if not allowed(player, k) then
				moved += 1
				local was = guestOf[player]
				guestOf[player] = nil
				player:SetAttribute("WingVisit", nil)
				Wings.hostChanged(player, nil)
				local mine = claim(player)
				if mine and Wings.ensure(mine) then
					Integrity.teleport(player, character, Wings.arrival(mine, "suite"))
				else
					Integrity.teleport(player, character, Wings.houseArrival())
				end
				notice(player, "Your Suite", if was then "That Suite has closed to visitors, so you're back in your own." else "Every Suite is private: this one is yours.")
			end
		else
			-- The house's own Suite and Vault are sealed: nobody stands in them.
			local zone = Layout.zoneAt(house)
			if zone == "suite" or zone == "vault" then
				moved += 1
				Integrity.teleport(player, character, Wings.houseArrival())
				notice(player, "The elevator", "Your Suite and Vault are private: the elevator by the Vault's door takes you up.")
			elseif guestOf[player] then
				guestOf[player] = nil
				Wings.hostChanged(player, nil)
			end
		end
	end
	return moved
end

---------------------------------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------------------------------

-- The house's own doors become the elevator's: a call button by each (the Vault's door in the
-- Foyer, the Suite's on the Club Floor), and a seal in each doorway.
local function callButtons()
	local f = Instance.new("Folder")
	f.Name = "ElevatorCalls"
	f.Parent = Workspace:FindFirstChild("Maison") or Workspace
	local V = Layout.Vault
	local S = Layout.Suite
	wall(f, "VaultDoorSeal", Vector3.new(V.door.X - V.doorWidth / 2 - 0.2, Layout.FLOOR, 42.6), Vector3.new(V.door.X + V.doorWidth / 2 + 0.2, Layout.FLOOR + 11, 43.6), false)
	wall(f, "SuiteDoorSeal", Vector3.new(S.door.X - 1.2, S.door.Y - 0.5, S.door.Z - S.doorWidth / 2 - 0.2), Vector3.new(S.door.X - 0.2, S.door.Y + S.doorHeight + 0.5, S.door.Z + S.doorWidth / 2 + 0.2), false)
	local function call(name: string, at: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.Transparency = 1
		p.Size = Vector3.new(2, 2, 2)
		p.CFrame = CFrame.new(at)
		p.Parent = f
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ElevatorPrompt"
		prompt.ActionText = "Elevator"
		prompt.ObjectText = "Your Suite and Vault"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = p
		prompt.Triggered:Connect(function(player: Player)
			local root = rootOf(player)
			if root and (root.Position - at).Magnitude <= REACH then
				Wings.menu(player, nil)
			end
		end)
	end
	call("VaultDoorCall", Vector3.new(V.door.X, Layout.FLOOR + 4, V.door.Z - 2))
	call("SuiteDoorCall", Vector3.new(S.door.X + 2, S.door.Y + 4, S.door.Z))
end

function Wings.start()
	Wings.prepare()
	pcall(callButtons)
	RemoteGuard.invoke(Remotes.func("ElevatorAsk"), "elevatorAsk", onAsk)
	for _, p in Players:GetPlayers() do
		claim(p)
	end
	Players.PlayerAdded:Connect(function(p: Player)
		leaving[p] = nil
		claim(p)
	end)
	Players.PlayerRemoving:Connect(function(p: Player)
		leaving[p] = true
		task.delay(30, function()
			leaving[p] = nil
		end)
		rides[p] = nil
		rested[p] = nil
		guestOf[p] = nil
		strays[p] = nil
		lastFloor[p] = nil
		local slot = own[p]
		own[p] = nil
		if slot then
			owner[slot] = nil
			local m = built[slot]
			built[slot] = nil
			-- (Anyone visiting is taken home first, then the wing goes.)
			task.defer(function()
				pcall(Wings.watch)
				if m then
					m:Destroy()
				end
			end)
		end
		for v, h in guestOf do
			if h == p then
				guestOf[v] = nil
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.3)
			pcall(Wings.watch)
		end
	end)
end

-- For tests.
Wings.handle = onAsk

return Wings

--!strict
-- The Great Egg Hunt (Easter): painted eggs hidden all over the house, on shelves and sideboards,
-- in corners, under the piano, round the Ballroom's ring; one of them gold. Walk up to one to find
-- it: Gilt, now and then a Gem; the golden egg far more. When every egg has been found, the house
-- hides another batch a minute later. (It stands in for the Easter event's old hunt: the eggs are
-- real painted eggs now, drawn on every screen round the small invisible parts placed here.)
--
-- Hiding places are found by looking down from each room's ceiling for a surface to set an egg on,
-- never on a sorting table, never in the Midnight Room (it's earned) or anyone's Suite (they're
-- private).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Names = require(ReplicatedStorage.Shared.Names)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Types = require(script.Parent.Types)

local Eggs = {}

type Egg = { id: number, part: Part, golden: boolean }
local eggs: { Egg } = {}
local folder: Folder? = nil
local nextId = 0
local round = 0
local rehideAt = 0
local opened = false

-- The rooms eggs are hidden in (each takes eggs by its size).
local ROOMS = { "Foyer", "Salon", "Velvet", "Obsidian", "Club", "Library", "Ballroom", "Boutique", "Vault" }

local function tables(): { Vector3 }
	local list = {}
	for _, room in Layout.Rooms :: { [string]: any } do
		for _, t in room.tables :: { Vector3 } do
			table.insert(list, t)
		end
	end
	return list
end

-- A place to hide an egg: a surface found from above in one of the rooms (or, where nothing can
-- be found, a spot on the room's floor).
local function spot(ctx: Types.Ctx, taken: { Vector3 }): Vector3
	local rng = ctx.rng
	local weights = {}
	local total = 0
	for _, name in ROOMS do
		local room = (Layout :: any)[name]
		local z = room.zone :: Layout.Box
		local w = (z.max.X - z.min.X) * (z.max.Z - z.min.Z)
		table.insert(weights, w)
		total += w
	end
	local avoid = tables()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { ctx.folder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	for _ = 1, 40 do
		local x = rng:NextNumber() * total
		local name = ROOMS[1]
		for i, w in weights do
			if x < w then
				name = ROOMS[i]
				break
			end
			x -= w
		end
		local room = (Layout :: any)[name]
		local z = room.zone :: Layout.Box
		local px = rng:NextNumber(z.min.X + 3, z.max.X - 3)
		local pz = rng:NextNumber(z.min.Z + 3, z.max.Z - 3)
		local floorY = if z.min.Y > 10 then Layout.CLUB else Layout.FLOOR
		local at: Vector3? = nil
		-- (From just under any ceiling, down past the floor.)
		local ok, hit = pcall(function()
			return Workspace:Raycast(Vector3.new(px, floorY + 9, pz), Vector3.new(0, -12, 0), params)
		end)
		if ok and hit then
			local part = hit.Instance
			local good = hit.Normal.Y > 0.75 and hit.Position.Y >= floorY - 0.5 and hit.Position.Y <= floorY + 7
			if good and part:IsA("BasePart") and part.Transparency < 0.5 and not string.find(part.Name, "Felt") and not string.find(part.Name, "Seat") then
				at = hit.Position
			end
		elseif not ok or hit == nil then
			-- (Nothing to look down on: the floor itself.)
			at = Vector3.new(px, floorY + 0.05, pz)
		end
		if at then
			local clear = true
			for _, t in avoid do
				if Vector3.new(at.X - t.X, 0, at.Z - t.Z).Magnitude < 9 then
					clear = false
					break
				end
			end
			for _, o in taken do
				if (o - at).Magnitude < 10 then
					clear = false
					break
				end
			end
			if clear then
				return at
			end
		end
	end
	return Layout.Foyer.hall + Vector3.new(rng:NextNumber(-12, 12), -1.5, rng:NextNumber(-12, 12))
end

local function hide(ctx: Types.Ctx)
	local f = folder
	if not f then
		return
	end
	for _, e in eggs do
		e.part:Destroy()
	end
	eggs = {}
	round += 1
	local c = ctx.cfg().eggs
	local taken: { Vector3 } = {}
	local goldenAt = ctx.rng:NextInteger(1, c.count)
	for k = 1, c.count do
		local at = spot(ctx, taken)
		table.insert(taken, at)
		nextId += 1
		local golden = k == goldenAt
		local height = if golden then 2 else ctx.rng:NextNumber(1.3, 1.8)
		local p = Instance.new("Part")
		p.Name = "Egg"
		p.Size = Vector3.new(1.6, height, 1.6)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CFrame = CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, ctx.rng:NextNumber(0, math.pi * 2), ctx.rng:NextNumber(-0.25, 0.25))
		p:SetAttribute("Id", nextId)
		p:SetAttribute("Scheme", ctx.rng:NextInteger(1, #HolidayProps.EGGS))
		p:SetAttribute("Golden", golden)
		p:SetAttribute("Height", height)
		p.Parent = f
		table.insert(eggs, { id = nextId, part = p, golden = golden })
	end
	rehideAt = 0
	ctx.broadcast({ op = "eggsHidden", n = #eggs })
end

local function find(ctx: Types.Ctx, player: Player, e: Egg)
	local c = ctx.cfg().eggs
	local i = table.find(eggs, e)
	if i then
		table.remove(eggs, i)
	end
	local at = e.part.CFrame.Position
	e.part:Destroy()
	local gilt = if e.golden then c.goldenGilt else c.gilt
	local gems = if e.golden then c.goldenGems elseif ctx.rng:NextNumber() < c.gemChance then 1 else 0
	local paid, given = ctx.reward(player, gilt, gems, if e.golden then "The golden egg" else "The Great Egg Hunt")
	ctx.award(player, "holiday_easter")
	ctx.curio(player, "paintedEgg", "eggs:" .. os.date("!%Y") .. ":" .. tostring(round))
	ctx.broadcast({ op = "egg", id = e.id, by = player.UserId, golden = e.golden, at = at })
	ctx.send(player, { op = "eggFound", golden = e.golden, gilt = paid, gems = given, left = #eggs })
	if e.golden then
		ctx.award(player, "goldenEggFound")
		ctx.curio(player, "goldenEgg", "eggs:gold:" .. os.date("!%Y-%j"))
		ctx.salute("The Great Egg Hunt", Names.of(player) .. " found the golden egg!", player)
	end
	if #eggs == 0 then
		rehideAt = os.clock() + c.again
		ctx.broadcast({ op = "eggsDone", again = c.again })
	end
end

function Eggs.open(ctx: Types.Ctx)
	if folder then
		folder:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = "Eggs"
	f.Parent = ctx.folder()
	folder = f
	opened = true
	hide(ctx)
end

function Eggs.close(_ctx: Types.Ctx)
	opened = false
	if folder then
		folder:Destroy()
		folder = nil
	end
	eggs = {}
end

function Eggs.step(ctx: Types.Ctx, _dt: number)
	if not opened then
		return
	end
	if #eggs == 0 then
		if rehideAt > 0 and os.clock() >= rehideAt then
			hide(ctx)
		end
		return
	end
	local reach = ctx.cfg().eggs.reach
	for _, player in Players:GetPlayers() do
		local root = ctx.rootOf(player)
		if not root or not ctx.trusted(player) then
			continue
		end
		local p = root.CFrame.Position
		for k = #eggs, 1, -1 do
			local e = eggs[k]
			local at = e.part.CFrame.Position
			if Vector3.new(at.X - p.X, 0, at.Z - p.Z).Magnitude <= reach and math.abs(at.Y - p.Y) < 7 then
				find(ctx, player, e)
				break
			end
		end
	end
end

function Eggs.state(ctx: Types.Ctx, _player: Player): { [string]: any }
	return { eggs = #eggs, total = ctx.cfg().eggs.count }
end

-- For tests: the eggs (their parts).
function Eggs.list(): { Part }
	local list = {}
	for _, e in eggs do
		table.insert(list, e.part)
	end
	return list
end

return Eggs

--!strict
-- The Grand Scale: the house is built at its drawn size (Layout.raw), then every room is opened
-- out by Layout.SCALE: floors, walls, ceilings, doorways, stairs, rugs and windows all grow, so
-- each room is that much wider, deeper and taller. Furniture keeps its own true size and moves
-- with its room (a chair stays a chair; the room around it is grander): every piece goes to where
-- its spot moved to, standing on the same floor (or hanging from the same ceiling) as before.
-- The gameplay numbers (Layout) are scaled the same way, so the house and the game agree.
--
-- What grows (the architecture): any part not inside a piece of furniture whose size or name says
-- it's part of the building. What moves without growing (the furniture): a group (a Model) of
-- modest size, or a small loose part. Doors, doorframes, stairs, rails and signs above doors
-- always grow with the walls they stand in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Breathe = require(ReplicatedStorage.Shared.Breathe)
local Layout = require(ReplicatedStorage.Shared.Layout)

local Grand = {}

local R = Layout.raw

-- A group larger than this (studs, across the floor) is part of the building, not furniture.
local GROUP_MAX = 16
-- A loose part this small is furniture (or a fitting): it moves, it doesn't grow.
local LOOSE_MAX = 6
local LOOSE_TALL = 8
-- Touching small parts move together, unless they run longer than this.
local SPREAD = 10
-- A grown part at least this tall is a wall (or a column): what stood flush against it stays so,
-- if it stood within this of it.
local WALL_TALL = 6
local TOUCH = 0.12

-- Names that are always the building, wherever they are and however small.
local BUILDING = {
	"Wall", "Floor", "Ceiling", "Roof", "Step", "Stair", "Tread", "Riser", "Landing", "Rail", "Baluster",
	"Newel", "Sill", "Jamb", "Head", "Lintel", "Door", "Leaf", "Arch", "Column", "Pillar", "Pilaster",
	"Beam", "Coffer", "Cornice", "Skirting", "Dado", "Wainscot", "Window", "Pane", "Mullion", "Transom",
	"Fanlight", "Parapet", "Balustrade", "Kerb", "Pavement", "Road", "Facade", "Frame", "Casing", "Moulding",
	"Gallery", "Cove", "Joint", "Sign", "Plaque", "DoorName", "Name", "Header", "Portal", "Opening", "Shaft",
	"Tile", "Threshold",
}
-- Models that are always the building (their parts all grow): any door, stair, gate or gallery.
local BUILDING_MODELS = { "Door", "Stair", "Gallery", "Gate" }

-- Vector3/CFrame attributes that are offsets (they don't move with a piece of furniture).
local RELATIVE = { Slide = true, FromHinge = true }

local function named(s: string, list: { string }): boolean
	for _, p in list do
		if string.find(s, p, 1, true) then
			return true
		end
	end
	return false
end

-- The floors of the house, as drawn: a piece of furniture stands on the highest one below it.
local LEVELS = { 0, R.FLOOR, R.CLUB, R.Suite.floorY, R.Terrace.floorY, R.Ballroom.gallery.floorY }
table.sort(LEVELS)

local function levelUnder(y: number): number
	local best = LEVELS[1]
	for _, l in LEVELS do
		if l <= y + 0.6 then
			best = l
		end
	end
	return best
end

local function corners(cf: CFrame, size: Vector3): { Vector3 }
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

local function boundsOf(parts: { BasePart }): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		for _, c in corners(p.CFrame, p.Size) do
			lo = lo:Min(c)
			hi = hi:Max(c)
		end
	end
	return lo, hi
end

local function partsOf(inst: Instance): { BasePart }
	local out = {}
	if inst:IsA("BasePart") then
		table.insert(out, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(out, d)
		end
	end
	return out
end

export type Piece = { root: Instance, parts: { BasePart }, lo: Vector3, hi: Vector3, anchor: Vector3, delta: Vector3, hung: boolean?, pinned: boolean? }
export type Plan = {
	grow: { BasePart }, -- the building: positions and sizes scaled
	pieces: { Piece }, -- furniture: each moved, as one, by its delta
}

-- Is this group (a Model below a room) a piece of furniture?
local function isPiece(m: Instance, parts: { BasePart }): boolean
	if named(m.Name, BUILDING_MODELS) or #parts == 0 then
		return false
	end
	local lo, hi = boundsOf(parts)
	local span = hi - lo
	return math.max(span.X, span.Z) <= GROUP_MAX
end

local function isSmall(p: BasePart): boolean
	if named(p.Name, BUILDING) then
		return false
	end
	local lo, hi = boundsOf({ p })
	local span = hi - lo
	return math.max(span.X, span.Z) <= LOOSE_MAX and span.Y <= LOOSE_TALL
end

-- Small loose parts that touch are one thing (a stack of gold bars, books along a shelf): they
-- move together. Grouped through a grid, so it's quick for thousands of parts.
local function clusters(parts: { BasePart }): { { BasePart } }
	local n = #parts
	local los: { Vector3 }, his: { Vector3 } = {}, {}
	for i, p in parts do
		local lo, hi = boundsOf({ p })
		los[i] = lo
		his[i] = hi
	end
	local up: { number } = {}
	for i = 1, n do
		up[i] = i
	end
	local function find(i: number): number
		while up[i] ~= i do
			up[i] = up[up[i]]
			i = up[i]
		end
		return i
	end
	local CELL = 4
	local grid: { [string]: { number } } = {}
	for i = 1, n do
		local lo, hi = los[i], his[i]
		for gx = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
			for gz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				local key = gx .. ":" .. gz
				local list = grid[key]
				if not list then
					list = {}
					grid[key] = list
				end
				for _, j in list do
					local x, y = los[j], his[j]
					local t = 0.06
					if lo.X <= y.X + t and hi.X >= x.X - t and lo.Y <= y.Y + t and hi.Y >= x.Y - t and lo.Z <= y.Z + t and hi.Z >= x.Z - t then
						up[find(i)] = find(j)
					end
				end
				table.insert(list, i)
			end
		end
		Breathe.now()
	end
	local groups: { [number]: { BasePart } } = {}
	local out: { { BasePart } } = {}
	for i, p in parts do
		local r = find(i)
		local g = groups[r]
		if g == nil then
			local fresh: { BasePart } = {}
			groups[r] = fresh
			table.insert(out, fresh)
			g = fresh
		end
		table.insert(g :: { BasePart }, p)
	end
	return out
end

type Surface = { lo: Vector3, hi: Vector3, piece: number? }

-- Sorts everything built under `root` into the building and the pieces, and works out where
-- each piece goes: across the floor, to where its spot moved (its anchor: the Frame it was built
-- at, or the middle of its footprint; `GrandAnchor` if set, for things that stay together, like
-- the two halves of a duel table); up, by exactly as much as whatever it rests on rose (the
-- floor, a shelf, a counter, another piece); or, if it hangs, by as much as the ceiling above it.
-- `pieceDepth`: how far below `root` a Model may be a piece (1: below the rooms).
function Grand.plan(root: Instance, S: number, pieceDepth: number?): Plan
	local minDepth = pieceDepth or 1
	local grow: { BasePart } = {}
	local pieces: { Piece } = {}
	local small: { BasePart } = {}
	local function addPiece(r: Instance, parts: { BasePart })
		local lo, hi = boundsOf(parts)
		local anchor = Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
		local frame = r:GetAttribute("GrandAnchor") or r:GetAttribute("Frame") or r:GetAttribute("Anchor")
		if typeof(frame) == "CFrame" then
			anchor = Vector3.new(frame.Position.X, lo.Y, frame.Position.Z)
		elseif typeof(frame) == "Vector3" then
			anchor = Vector3.new(frame.X, lo.Y, frame.Z)
		end
		-- (A piece built at a spot the game knows goes exactly where that spot went.)
		local pinned = typeof(frame) == "CFrame" or typeof(frame) == "Vector3"
		table.insert(pieces, { root = r, parts = parts, lo = lo, hi = hi, anchor = anchor, delta = Vector3.zero, pinned = pinned })
	end
	-- One walk down the tree: the outermost modest-sized Model deep enough below `root` is a
	-- piece (and nothing inside it is looked at again); the parts of the building's own models
	-- grow; the other loose parts are fittings if small (moved, in touching clusters), else the
	-- building (grown). (A walk rather than a set of claimed parts: an instance isn't always the
	-- same key twice outside Roblox.)
	local function visit(inst: Instance, depth: number, building: boolean)
		for _, child in inst:GetChildren() do
			Breathe.now()
			if child:IsA("Model") then
				local isBuilding = building or named(child.Name, BUILDING_MODELS)
				if depth >= minDepth and not isBuilding then
					local parts = partsOf(child)
					if isPiece(child, parts) then
						addPiece(child, parts)
						continue
					end
				end
				visit(child, depth + 1, isBuilding)
			elseif child:IsA("BasePart") then
				if building or not isSmall(child) then
					table.insert(grow, child)
				else
					table.insert(small, child)
				end
				visit(child, depth + 1, building)
			elseif child:IsA("Folder") then
				visit(child, depth + 1, building)
			end
		end
	end
	visit(root, 0, false)
	for _, c in clusters(small) do
		local lo, hi = boundsOf(c)
		if math.max(hi.X - lo.X, hi.Z - lo.Z) > SPREAD then
			-- A long run of little things (books along a shelf, ivy up a wall) spreads out with
			-- the room: each moves on its own.
			for _, p in c do
				addPiece(p, { p })
			end
		else
			addPiece(c[1], c)
		end
	end
	-- What each piece rests on. Surfaces: every grown part, every piece.
	local CELL = 8
	local surfaces: { [string]: { Surface } } = {}
	local function addSurface(lo: Vector3, hi: Vector3, piece: number?)
		local sfc: Surface = { lo = lo, hi = hi, piece = piece }
		for gx = math.floor(lo.X / CELL), math.floor(hi.X / CELL) do
			for gz = math.floor(lo.Z / CELL), math.floor(hi.Z / CELL) do
				local key = gx .. ":" .. gz
				local list = surfaces[key]
				if not list then
					list = {}
					surfaces[key] = list
				end
				table.insert(list, sfc)
			end
		end
	end
	for _, p in grow do
		local lo, hi = boundsOf({ p })
		addSurface(lo, hi, nil)
		Breathe.now()
	end
	for i, pc in pieces do
		addSurface(pc.lo, pc.hi, i)
	end
	-- Against a wall: a piece that stood flush with a wall (or a column) keeps standing flush with
	-- it, on the side it stood; across that axis it moves exactly as the wall's face moved.
	local function againstWalls(pc: Piece): (number?, number?)
		local lo, hi = pc.lo, pc.hi
		local seen: { [Surface]: boolean } = {}
		local minusX: number?, plusX: number?, minusZ: number?, plusZ: number? = nil, nil, nil, nil
		for gx = math.floor((lo.X - 0.2) / CELL), math.floor((hi.X + 0.2) / CELL) do
			for gz = math.floor((lo.Z - 0.2) / CELL), math.floor((hi.Z + 0.2) / CELL) do
				local cell: { Surface } = surfaces[gx .. ":" .. gz] or {}
				for _, sfc in cell do
					if sfc.piece == nil and not seen[sfc] then
						seen[sfc] = true
						if sfc.hi.Y - sfc.lo.Y >= WALL_TALL and sfc.lo.Y < hi.Y - 0.1 and sfc.hi.Y > lo.Y + 0.1 then
							if math.min(hi.Z, sfc.hi.Z) - math.max(lo.Z, sfc.lo.Z) > 0.2 then
								if math.abs(lo.X - sfc.hi.X) <= TOUCH then
									minusX = sfc.hi.X
								elseif math.abs(sfc.lo.X - hi.X) <= TOUCH then
									plusX = sfc.lo.X
								end
							end
							if math.min(hi.X, sfc.hi.X) - math.max(lo.X, sfc.lo.X) > 0.2 then
								if math.abs(lo.Z - sfc.hi.Z) <= TOUCH then
									minusZ = sfc.hi.Z
								elseif math.abs(sfc.lo.Z - hi.Z) <= TOUCH then
									plusZ = sfc.lo.Z
								end
							end
						end
					end
				end
			end
		end
		-- (Wedged between two walls, it keeps to its own spot.)
		local dx = if minusX and not plusX then minusX * (S - 1) elseif plusX and not minusX then plusX * (S - 1) else nil
		local dz = if minusZ and not plusZ then minusZ * (S - 1) elseif plusZ and not minusZ then plusZ * (S - 1) else nil
		return dx, dz
	end
	local resolved: { [number]: boolean } = {}
	local resolving: { [number]: boolean } = {}
	local function resolve(i: number): Vector3
		local pc = pieces[i]
		if resolved[i] then
			return pc.delta
		end
		local a = pc.anchor
		if resolving[i] then
			return Vector3.new(a.X * (S - 1), levelUnder(pc.lo.Y) * (S - 1), a.Z * (S - 1))
		end
		resolving[i] = true
		local best: Surface? = nil
		local list: { Surface } = surfaces[math.floor(a.X / CELL) .. ":" .. math.floor(a.Z / CELL)] or {}
		for _, sfc in list do
			if sfc.piece ~= i and a.X >= sfc.lo.X - 0.05 and a.X <= sfc.hi.X + 0.05 and a.Z >= sfc.lo.Z - 0.05 and a.Z <= sfc.hi.Z + 0.05 then
				local top = sfc.hi.Y
				local b = best
				if top <= pc.lo.Y + 0.35 and top >= pc.lo.Y - 0.6 and (b == nil or top > b.hi.Y) then
					best = sfc
				end
			end
		end
		local dx, dz = a.X * (S - 1), a.Z * (S - 1)
		local dy: number
		local b = best
		local under = b and b.piece
		if b and under then
			-- On another piece (a vase on a sideboard): it goes with it.
			local carried = resolve(under)
			dy = carried.Y
			if not pc.pinned then
				dx, dz = carried.X, carried.Z
			end
		else
			if b then
				dy = b.hi.Y * (S - 1)
			else
				local level = levelUnder(pc.lo.Y)
				dy = level * (S - 1)
				-- Nothing under it, well clear of the floor: if a ceiling meets its top, it hangs there.
				if pc.lo.Y - level > 3 then
					for _, sfc in list do
						if sfc.piece == nil and sfc.lo.Y >= pc.hi.Y - 0.4 and sfc.lo.Y <= pc.hi.Y + 1.5 and a.X >= sfc.lo.X and a.X <= sfc.hi.X and a.Z >= sfc.lo.Z and a.Z <= sfc.hi.Z then
							dy = sfc.lo.Y * (S - 1)
							pc.hung = true
							break
						end
					end
				end
			end
			if not pc.pinned then
				local wx, wz = againstWalls(pc)
				dx = wx or dx
				dz = wz or dz
			end
		end
		pc.delta = Vector3.new(dx, dy, dz)
		resolved[i] = true
		resolving[i] = false
		return pc.delta
	end
	for i in pieces do
		resolve(i)
		Breathe.now()
	end
	return { grow = grow, pieces = pieces }
end

local function scaleAttributes(inst: Instance, S: number)
	for name, v in inst:GetAttributes() do
		if typeof(v) == "Vector3" then
			inst:SetAttribute(name, v * S)
		elseif typeof(v) == "CFrame" then
			inst:SetAttribute(name, v - v.Position + v.Position * S)
		end
	end
end

local function moveAttributes(inst: Instance, delta: Vector3)
	for name, v in inst:GetAttributes() do
		if not RELATIVE[name] then
			if typeof(v) == "Vector3" then
				inst:SetAttribute(name, v + delta)
			elseif typeof(v) == "CFrame" then
				inst:SetAttribute(name, v + delta)
			end
		end
	end
end

-- A flight of grown steps rises that much more per step: an unseen ramp along the line of its
-- nosings carries every guest (whatever their size) up and down it smoothly, as Roblox
-- staircases usually are. One per flight: the steps (`Step`, `Step1`, ...) under one parent.
local function ramps(grown: { BasePart })
	local flights: { [string]: { BasePart } } = {}
	local order: { string } = {}
	for _, p in grown do
		if string.match(p.Name, "^Step%d*$") and p.Parent then
			local key = (p.Parent :: Instance):GetFullName()
			if not flights[key] then
				flights[key] = {}
				table.insert(order, key)
			end
			table.insert(flights[key], p)
		end
	end
	for _, key in order do
		local steps = flights[key]
		if #steps < 2 then
			continue
		end
		table.sort(steps, function(a, b)
			return a.CFrame.Position.Y + a.Size.Y / 2 < b.CFrame.Position.Y + b.Size.Y / 2
		end)
		local first, last = steps[1], steps[#steps]
		local run = last.CFrame.Position - first.CFrame.Position
		run = Vector3.new(run.X, 0, run.Z)
		if run.Magnitude < 0.5 then
			continue
		end
		local dir = run.Unit
		local side = dir:Cross(Vector3.yAxis)
		-- Reach of a step along the flight and across it (the steps are upright boxes).
		local function reach(p: BasePart, along: Vector3): number
			local h = p.Size / 2
			return math.abs(p.CFrame.RightVector:Dot(along)) * h.X + math.abs(p.CFrame.LookVector:Dot(along)) * h.Z
		end
		local width = math.huge
		for _, p in steps do
			width = math.min(width, reach(p, side) * 2)
		end
		local a = first.CFrame.Position - dir * reach(first, dir)
		a = Vector3.new(a.X, first.CFrame.Position.Y - first.Size.Y / 2, a.Z)
		local b = last.CFrame.Position - dir * reach(last, dir)
		b = Vector3.new(b.X, last.CFrame.Position.Y + last.Size.Y / 2, b.Z)
		local length = (b - a).Magnitude
		local ramp = Instance.new("Part")
		ramp.Name = "StairRamp"
		ramp.Anchored = true
		ramp.Transparency = 1
		ramp.CanQuery = false
		ramp.CanTouch = false
		ramp.CastShadow = false
		ramp.Size = Vector3.new(math.max(1, width - 0.2), 0.2, length)
		ramp.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -0.1, 0)
		ramp.Parent = first.Parent
	end
end

-- What a builder hung from a ceiling inside a piece of furniture (a table's lamp) is carried up
-- to that ceiling's grown height: "ceiling" parts move up with it, a "cord" stretches up to it.
local function hangFrom(p: BasePart, S: number, risen: number)
	local kind = p:GetAttribute("GrandHang")
	local ceiling = p:GetAttribute("GrandCeiling")
	if (kind ~= "ceiling" and kind ~= "cord") or typeof(ceiling) ~= "number" then
		return
	end
	local rise = ceiling * (S - 1) - risen
	if math.abs(rise) < 1e-3 then
		return
	end
	if kind == "ceiling" then
		p.CFrame = p.CFrame + Vector3.new(0, rise, 0)
		for _, d in p:GetChildren() do
			if d:IsA("SpotLight") or d:IsA("PointLight") or d:IsA("SurfaceLight") then
				local l = d :: any
				l.Range = math.min(60, l.Range + rise)
			end
		end
		return
	end
	-- A cord: longer along whichever of its own axes stands upright, its foot where it was.
	local cf = p.CFrame
	local size = p.Size
	if math.abs(cf.RightVector.Y) > 0.9 then
		size = Vector3.new(size.X + rise, size.Y, size.Z)
	elseif math.abs(cf.UpVector.Y) > 0.9 then
		size = Vector3.new(size.X, size.Y + rise, size.Z)
	elseif math.abs(cf.LookVector.Y) > 0.9 then
		size = Vector3.new(size.X, size.Y, size.Z + rise)
	else
		return
	end
	p.Size = size
	p.CFrame = cf + Vector3.new(0, rise / 2, 0)
end

-- Opens the house out by S.
function Grand.apply(root: Instance, S: number, pieceDepth: number?): Plan
	local plan = Grand.plan(root, S, pieceDepth)
	if S == 1 then
		return plan
	end
	for _, p in plan.grow do
		Breathe.now()
		local cf = p.CFrame
		p.Size = p.Size * S
		p.CFrame = cf - cf.Position + cf.Position * S
		scaleAttributes(p, S)
		for _, d in p:GetChildren() do
			if d:IsA("Attachment") then
				d.Position = d.Position * S
			elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
				local l = d :: any
				l.Range = math.min(60, l.Range * S)
			elseif d:IsA("SurfaceGui") and d.SizingMode == Enum.SurfaceGuiSizingMode.PixelsPerStud then
				d.PixelsPerStud = d.PixelsPerStud / S
			elseif d:IsA("Texture") then
				d.StudsPerTileU *= S
				d.StudsPerTileV *= S
			end
		end
	end
	-- (A finishing touch: if it fails, the house is still opened out.)
	local ok, err = pcall(function()
		ramps(plan.grow)
	end)
	if not ok then
		warn("[Maison] The stair ramps weren't laid: " .. tostring(err))
	end
	-- The models of the building carry positions too (a door's hinge).
	for _, d in root:GetDescendants() do
		if d:IsA("Model") and named(d.Name, BUILDING_MODELS) then
			scaleAttributes(d, S)
		end
	end
	for _, piece in plan.pieces do
		Breathe.now()
		for _, p in piece.parts do
			p.CFrame = p.CFrame + piece.delta
			moveAttributes(p, piece.delta)
			hangFrom(p, S, piece.delta.Y)
			-- A lamp hung from a ceiling that rose is that much farther from the floor it lights.
			if piece.hung then
				for _, d in p:GetChildren() do
					if d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
						local l = d :: any
						l.Range = math.min(60, l.Range * S)
					end
				end
			end
		end
		if not piece.root:IsA("BasePart") then
			moveAttributes(piece.root, piece.delta)
			for _, d in piece.root:GetDescendants() do
				if d:IsA("Model") then
					moveAttributes(d, piece.delta)
				end
			end
		end
	end
	return plan
end

return Grand

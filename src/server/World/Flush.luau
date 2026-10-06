--!strict
-- The last step of building. Wherever two different-looking surfaces lie flush in one plane, facing
-- the same way (a rug on a floor, a door frame against a wall, the Terrace laid on a roof), the
-- renderer can't tell which is in front and they flicker as the camera moves. The builders lay
-- parts flush on purpose (it keeps their numbers simple), so this lifts the smaller of each such
-- pair of faces GAP studs clear of the other: too little to see, enough never to flicker.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Breathe = require(ReplicatedStorage.Shared.Breathe)

local Flush = {}

Flush.GAP = 0.03 -- studs between two faces that were flush
local NEAR = 0.012 -- faces nearer than this flicker
local MIN_OVERLAP = 0.02 -- square studs; less than this is a seam, not a surface

-- A block's bounds and look, read from the part once (reading a part's properties is far slower
-- than comparing plain numbers, and the house has thousands of parts). `axisOf` says which of its
-- own axes (1 Size.X, 2 Size.Y, 3 Size.Z) runs along each world axis.
type Box = { part: Part, lo: { number }, hi: { number }, axisOf: { number }, look: string }
type Face = { box: Box, axis: number, side: number, plane: number, area: number }

local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }
-- For a face across one axis, the two axes it lies along.
local ALONG = { { 2, 3 }, { 1, 3 }, { 1, 2 } }

local function comp(v: Vector3, axis: number): number
	return if axis == 1 then v.X elseif axis == 2 then v.Y else v.Z
end

-- A block lined up with the world's axes. Nil for anything else.
local function boxOf(part: Part): Box?
	if part.Shape ~= Enum.PartType.Block or part.Transparency >= 0.9 then
		return nil
	end
	local cf = part.CFrame
	local own = { cf.RightVector, cf.UpVector, cf.LookVector }
	local axisOf = { 0, 0, 0 }
	for k, v in own do
		for a = 1, 3 do
			if math.abs(comp(v, a)) > 0.9995 then
				axisOf[a] = k
			end
		end
	end
	if axisOf[1] == 0 or axisOf[2] == 0 or axisOf[3] == 0 then
		return nil
	end
	local size = part.Size
	local p = cf.Position
	local lo, hi = {}, {}
	for a = 1, 3 do
		local half = comp(size, axisOf[a]) / 2
		lo[a] = comp(p, a) - half
		hi[a] = comp(p, a) + half
	end
	local c = part.Color
	local look = string.format("%.5f %.5f %.5f %s %.4f %.4f", c.R, c.G, c.B, part.Material.Name, part.Transparency, part.Reflectance)
	return { part = part, lo = lo, hi = hi, axisOf = axisOf, look = look }
end

-- Overlap (square studs) of two faces in the plane across `axis`.
local function overlap(a: Box, b: Box, axis: number): number
	local area = 1
	for _, ax in ALONG[axis] do
		area *= math.max(0, math.min(a.hi[ax], b.hi[ax]) - math.max(a.lo[ax], b.lo[ax]))
	end
	return area
end

local function boxesUnder(root: Instance): { Box }
	local out = {}
	for _, d in root:GetDescendants() do
		Breathe.now()
		if d:IsA("Part") then
			local box = boxOf(d)
			if box then
				table.insert(out, box)
			end
		end
	end
	return out
end

local function keyOf(axis: number, side: number, cell: number): string
	return string.format("%d%d:%d", axis, side, cell)
end

-- The pairs of faces that flicker, as { mover, other } (the mover is the smaller face).
local function find(boxes: { Box }): { { Face } }
	-- Faces that could be flush sit in the same thin slice of space (or the next one up).
	local buckets: { [string]: { Face } } = {}
	local cells: { [string]: { axis: number, side: number, cell: number } } = {}
	for _, box in boxes do
		for axis = 1, 3 do
			local along = ALONG[axis]
			local area = (box.hi[along[1]] - box.lo[along[1]]) * (box.hi[along[2]] - box.lo[along[2]])
			for _, side in { -1, 1 } do
				local plane = if side > 0 then box.hi[axis] else box.lo[axis]
				local cell = math.floor(plane * 40)
				local key = keyOf(axis, side, cell)
				local list = buckets[key]
				if not list then
					list = {}
					buckets[key] = list
					cells[key] = { axis = axis, side = side, cell = cell }
				end
				table.insert(list, { box = box, axis = axis, side = side, plane = plane, area = area })
			end
		end
	end
	local pairsFound: { { Face } } = {}
	local function add(f: Face, g: Face)
		if f.area < g.area or (f.area == g.area and f.box.part:GetFullName() < g.box.part:GetFullName()) then
			table.insert(pairsFound, { f, g })
		else
			table.insert(pairsFound, { g, f })
		end
	end
	for key, list in buckets do
		local at = cells[key]
		local nextList = buckets[keyOf(at.axis, at.side, at.cell + 1)]
		-- Sweep along one of the face's own axes: only faces whose spans meet there can overlap.
		local u = ALONG[at.axis][1]
		local items: { { face: Face, mine: boolean } } = {}
		for _, f in list do
			table.insert(items, { face = f, mine = true })
		end
		if nextList then
			for _, f in nextList do
				table.insert(items, { face = f, mine = false })
			end
		end
		if #items < 2 then
			continue
		end
		table.sort(items, function(a, b)
			return a.face.box.lo[u] < b.face.box.lo[u]
		end)
		for i = 1, #items do
			Breathe.now()
			local fi = items[i]
			local f = fi.face
			local reach = f.box.hi[u]
			for j = i + 1, #items do
				local gi = items[j]
				local g = gi.face
				if g.box.lo[u] >= reach then
					break
				end
				if (fi.mine or gi.mine) and f.box ~= g.box and math.abs(f.plane - g.plane) < NEAR and f.box.look ~= g.box.look and overlap(f.box, g.box, f.axis) > MIN_OVERLAP then
					add(f, g)
				end
			end
		end
	end
	return pairsFound
end

local function settleNow(root: Instance): number
	local moved = 0
	local boxes = boxesUnder(root)
	-- Two faces lifted off the same surface can end up flush with each other, so another round
	-- follows, each with a wider gap than the last, until nothing is flush.
	for round = 1, 6 do
		local found = find(boxes)
		if #found == 0 then
			break
		end
		local gap = Flush.GAP * round
		-- How far each face goes: just past the furthest face it was flush with.
		local grow: { [Part]: { box: Box, out: { [number]: number } } } = {}
		for _, pair in found do
			local mover, other = pair[1], pair[2]
			local target = (other.plane - mover.plane) * mover.side + gap
			local entry = grow[mover.box.part]
			if not entry then
				entry = { box = mover.box, out = {} }
				grow[mover.box.part] = entry
			end
			local k = mover.axis * 2 + (if mover.side > 0 then 1 else 0)
			entry.out[k] = math.max(entry.out[k] or 0, target)
		end
		for part, entry in grow do
			local size = part.Size
			local shift = Vector3.zero
			local sizes = { size.X, size.Y, size.Z }
			local box = entry.box
			for axis = 1, 3 do
				local plus = entry.out[axis * 2 + 1] or 0
				local minus = entry.out[axis * 2] or 0
				if plus ~= 0 or minus ~= 0 then
					local own = box.axisOf[axis]
					sizes[own] += plus + minus
					shift += AXES[axis] * ((plus - minus) / 2)
					box.hi[axis] += plus
					box.lo[axis] -= minus
					moved += (if plus ~= 0 then 1 else 0) + (if minus ~= 0 then 1 else 0)
				end
			end
			part.Size = Vector3.new(sizes[1], sizes[2], sizes[3])
			part.CFrame = part.CFrame + shift
		end
	end
	return moved
end

local busy = false

-- Lifts every flickering face clear. Returns how many faces it moved. (One at a time: the
-- house's own pass runs just after guests spawn, and the season's dressing asks for another.)
function Flush.settle(root: Instance): number
	while busy do
		task.wait()
	end
	busy = true
	local ok, result = pcall(function()
		return settleNow(root)
	end)
	busy = false
	if not ok then
		error(result, 0)
	end
	return result
end

-- The faces that still flicker under `root`, one line each (for the world's checks).
function Flush.report(root: Instance): { string }
	local out = {}
	for _, pair in find(boxesUnder(root)) do
		table.insert(out, string.format("%s | %s", pair[1].box.part:GetFullName(), pair[2].box.part:GetFullName()))
	end
	table.sort(out)
	return out
end

return Flush

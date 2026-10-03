--!strict
-- The last step of building. Wherever two different-looking surfaces lie flush in one plane, facing
-- the same way (a rug on a floor, a door frame against a wall, the Terrace laid on a roof), the
-- renderer can't tell which is in front and they flicker as the camera moves. The builders lay
-- parts flush on purpose (it keeps their numbers simple), so this lifts the smaller of each such
-- pair of faces GAP studs clear of the other: too little to see, enough never to flicker.

local Flush = {}

Flush.GAP = 0.03 -- studs between two faces that were flush
local NEAR = 0.012 -- faces nearer than this flicker
local MIN_OVERLAP = 0.02 -- square studs; less than this is a seam, not a surface

type Box = { part: Part, lo: Vector3, hi: Vector3, axisOf: { number } }
type Face = { box: Box, axis: number, side: number, plane: number, area: number }

local AXES = { Vector3.xAxis, Vector3.yAxis, Vector3.zAxis }

local function comp(v: Vector3, axis: number): number
	return if axis == 1 then v.X elseif axis == 2 then v.Y else v.Z
end

-- A block lined up with the world's axes: its bounds, and which of its own axes (1 Size.X,
-- 2 Size.Y, 3 Size.Z) runs along each world axis. Nil for anything else.
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
	local half = Vector3.new(comp(size, axisOf[1]), comp(size, axisOf[2]), comp(size, axisOf[3])) / 2
	return { part = part, lo = cf.Position - half, hi = cf.Position + half, axisOf = axisOf }
end

local function looksSame(a: Part, b: Part): boolean
	return a.Color == b.Color and a.Material == b.Material and a.Transparency == b.Transparency and a.Reflectance == b.Reflectance
end

-- Overlap (square studs) of two faces in the plane across `axis`.
local function overlap(a: Box, b: Box, axis: number): number
	local area = 1
	for ax = 1, 3 do
		if ax ~= axis then
			area *= math.max(0, math.min(comp(a.hi, ax), comp(b.hi, ax)) - math.max(comp(a.lo, ax), comp(b.lo, ax)))
		end
	end
	return area
end

-- The pairs of faces that flicker, as { mover, other } (the mover is the smaller face).
local function find(root: Instance): { { Face } }
	local buckets: { [string]: { Face } } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("Part") then
			local box = boxOf(d)
			if box then
				for axis = 1, 3 do
					local area = 1
					for ax = 1, 3 do
						if ax ~= axis then
							area *= comp(box.hi, ax) - comp(box.lo, ax)
						end
					end
					for _, side in { -1, 1 } do
						local plane = if side > 0 then comp(box.hi, axis) else comp(box.lo, axis)
						local face: Face = { box = box, axis = axis, side = side, plane = plane, area = area }
						local key = string.format("%d%d:%d", axis, side, math.floor(plane * 40))
						local list = buckets[key]
						if not list then
							list = {}
							buckets[key] = list
						end
						table.insert(list, face)
					end
				end
			end
		end
	end
	local pairsFound: { { Face } } = {}
	for key, list in buckets do
		local axis, side, b = string.match(key, "^(%d)(%-?%d):(%-?%d+)$")
		local nextList = buckets[string.format("%s%s:%d", axis :: string, side :: string, (tonumber(b) :: number) + 1)] or {}
		for i, f in list do
			for _, other in { list, nextList } do
				for j, g in other do
					if (other ~= list or j > i) and f.box ~= g.box and math.abs(f.plane - g.plane) < NEAR and not looksSame(f.box.part, g.box.part) and overlap(f.box, g.box, f.axis) > MIN_OVERLAP then
						if f.area < g.area or (f.area == g.area and f.box.part:GetFullName() < g.box.part:GetFullName()) then
							table.insert(pairsFound, { f, g })
						else
							table.insert(pairsFound, { g, f })
						end
					end
				end
			end
		end
	end
	return pairsFound
end

-- Lifts every flickering face clear. Returns how many faces it moved.
function Flush.settle(root: Instance): number
	local moved = 0
	-- Two faces lifted off the same surface can end up flush with each other, so another round
	-- follows, each with a wider gap than the last, until nothing is flush.
	for round = 1, 6 do
		local found = find(root)
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
			for axis = 1, 3 do
				local plus = entry.out[axis * 2 + 1] or 0
				local minus = entry.out[axis * 2] or 0
				if plus ~= 0 or minus ~= 0 then
					local own = entry.box.axisOf[axis]
					sizes[own] += plus + minus
					shift += AXES[axis] * ((plus - minus) / 2)
					moved += (if plus ~= 0 then 1 else 0) + (if minus ~= 0 then 1 else 0)
				end
			end
			part.Size = Vector3.new(sizes[1], sizes[2], sizes[3])
			part.CFrame = part.CFrame + shift
		end
	end
	return moved
end

-- The faces that still flicker under `root`, one line each (for the world's checks).
function Flush.report(root: Instance): { string }
	local out = {}
	for _, pair in find(root) do
		table.insert(out, string.format("%s | %s", pair[1].box.part:GetFullName(), pair[2].box.part:GetFullName()))
	end
	table.sort(out)
	return out
end

return Flush

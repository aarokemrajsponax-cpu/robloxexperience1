--!strict
-- The walls, floor and ceiling of a room off the Foyer. The Foyer's own wall has the doorway;
-- this adds the room's facing around it. Walls shared with a neighbouring room are built once
-- (the other room adds only a thin facing), so faces never fight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Kit = require(script.Parent.Kit)

local RoomShell = {}

local FLOOR = Layout.FLOOR

export type Spec = {
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number, height: number },
	foyerSide: "east" | "west", -- which side the Foyer is on
	doorZ: number,
	wall: Kit.Look,
	floor: Kit.Look,
	ceiling: Kit.Look,
	wainscot: Kit.Look?,
	rail: Kit.Look?,
	sharedSouth: boolean?, -- the south wall already exists (built by the room next door)
	sharedNorth: boolean?,
}

function RoomShell.build(m: Model, spec: Spec)
	local b = spec.bounds
	local top = FLOOR + b.height
	local noHit = { collide = false, query = false }
	Kit.span(m, "Floor", Vector3.new(b.minX, FLOOR - 1, b.minZ), Vector3.new(b.maxX, FLOOR, b.maxZ), spec.floor)
	Kit.span(m, "Ceiling", Vector3.new(b.minX - 2, top, b.minZ - 2), Vector3.new(b.maxX + 2, top + 1, b.maxZ + 2), spec.ceiling)

	-- The far wall (opposite the Foyer)
	if spec.foyerSide == "east" then
		Kit.span(m, "WallFar", Vector3.new(b.minX - 2, FLOOR, b.minZ - 2), Vector3.new(b.minX, top, b.maxZ + 2), spec.wall)
	else
		Kit.span(m, "WallFar", Vector3.new(b.maxX, FLOOR, b.minZ - 2), Vector3.new(b.maxX + 2, top, b.maxZ + 2), spec.wall)
	end
	-- South and north walls: full, or just a facing if the neighbour already built the wall.
	if spec.sharedSouth then
		Kit.span(m, "FacingSouth", Vector3.new(b.minX, FLOOR, b.minZ), Vector3.new(b.maxX, top, b.minZ + 0.2), spec.wall, noHit)
	else
		Kit.span(m, "WallSouth", Vector3.new(b.minX - 2, FLOOR, b.minZ - 2), Vector3.new(b.maxX + 2, top, b.minZ), spec.wall)
	end
	if spec.sharedNorth then
		Kit.span(m, "FacingNorth", Vector3.new(b.minX, FLOOR, b.maxZ - 0.2), Vector3.new(b.maxX, top, b.maxZ), spec.wall, noHit)
	else
		Kit.span(m, "WallNorth", Vector3.new(b.minX - 2, FLOOR, b.maxZ), Vector3.new(b.maxX + 2, top, b.maxZ + 2), spec.wall)
	end
	-- Facing on the Foyer side, around the doorway
	local dw = Layout.RoomDoorWidth / 2
	local x0, x1
	if spec.foyerSide == "east" then
		x0, x1 = b.maxX - 0.2, b.maxX
	else
		x0, x1 = b.minX, b.minX + 0.2
	end
	Kit.span(m, "FacingDoorA", Vector3.new(x0, FLOOR, b.minZ), Vector3.new(x1, top, spec.doorZ - dw), spec.wall, noHit)
	Kit.span(m, "FacingDoorB", Vector3.new(x0, FLOOR, spec.doorZ + dw), Vector3.new(x1, top, b.maxZ), spec.wall, noHit)
	Kit.span(m, "FacingDoorC", Vector3.new(x0, FLOOR + Layout.RoomDoorHeight, spec.doorZ - dw), Vector3.new(x1, top, spec.doorZ + dw), spec.wall, noHit)

	-- Wainscot and rails on the three inner walls
	local wain = FLOOR + 3.8
	local farX0, farX1 = if spec.foyerSide == "east" then b.minX else b.maxX - 0.45, if spec.foyerSide == "east" then b.minX + 0.45 else b.maxX
	local inset = if spec.sharedSouth then 0.2 else 0
	local insetN = if spec.sharedNorth then 0.2 else 0
	if spec.wainscot then
		Kit.span(m, "Wainscot", Vector3.new(farX0, FLOOR, b.minZ), Vector3.new(farX1 - 0.05, wain, b.maxZ), spec.wainscot, noHit)
		Kit.span(m, "Wainscot", Vector3.new(b.minX, FLOOR, b.minZ + inset), Vector3.new(b.maxX, wain, b.minZ + inset + 0.4), spec.wainscot, noHit)
		Kit.span(m, "Wainscot", Vector3.new(b.minX, FLOOR, b.maxZ - insetN - 0.4), Vector3.new(b.maxX, wain, b.maxZ - insetN), spec.wainscot, noHit)
	end
	if spec.rail then
		local rail = spec.rail
		local opts = { collide = false, query = false, shadow = false }
		Kit.span(m, "Rail", Vector3.new(farX0, wain, b.minZ), Vector3.new(farX1, wain + 0.18, b.maxZ), rail, opts)
		Kit.span(m, "Rail", Vector3.new(b.minX, wain, b.minZ + inset), Vector3.new(b.maxX, wain + 0.18, b.minZ + inset + 0.45), rail, opts)
		Kit.span(m, "Rail", Vector3.new(b.minX, wain, b.maxZ - insetN - 0.45), Vector3.new(b.maxX, wain + 0.18, b.maxZ - insetN), rail, opts)
		Kit.span(m, "Rail", Vector3.new(b.minX, top - 2.5, b.maxZ - insetN - 0.45), Vector3.new(b.maxX, top - 2.3, b.maxZ - insetN), rail, opts)
		Kit.span(m, "Rail", Vector3.new(b.minX, top - 2.5, b.minZ + inset), Vector3.new(b.maxX, top - 2.3, b.minZ + inset + 0.45), rail, opts)
	end
end

return RoomShell

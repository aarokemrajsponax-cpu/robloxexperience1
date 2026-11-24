--!strict
-- (Build 102) Every guest's own Suite and Vault: a real, separate copy of both for each guest (a
-- private wing), high above the house where nobody can walk to it. The only way in is the
-- elevator, and the server decides who rides where: your own wing, or a friend's when they allow
-- it. This is the shared arithmetic: where each wing stands, and how a point inside one maps back
-- to the house's own Suite and Vault (so everything that knows those rooms knows a wing too).

local Wing = {}

-- The first wing's height above the house, and the height between wings (each holds a Vault and,
-- above it, a Suite: about 60 studs tall).
Wing.BASE = 2400
Wing.SPACING = 400
Wing.MAX = 48
-- How far below or above a wing still counts as in it (its floors, a jump on its terrace).
local BELOW, ABOVE = 150, 250

-- The elevator's journeys, in seconds: exactly these.
Wing.SECONDS = {
	suite = 5.5, -- to your own Suite
	vault = 5.5, -- to your own Vault
	friend = 6.5, -- to a friend's Suite
	house = 5.5, -- back down to the house
} :: { [string]: number }

-- Where wing `slot` (0, 1, 2...) stands, as an offset from the house's own Suite and Vault.
function Wing.offset(slot: number): Vector3
	return Vector3.new(0, Wing.BASE + slot * Wing.SPACING, 0)
end

-- The wing a point is in, if any.
function Wing.slotAt(p: Vector3): number?
	if p.Y < Wing.BASE - BELOW then
		return nil
	end
	local k = math.floor((p.Y - Wing.BASE + BELOW) / Wing.SPACING)
	if k < 0 or k >= Wing.MAX then
		return nil
	end
	local local_ = p.Y - (Wing.BASE + k * Wing.SPACING)
	if local_ > ABOVE then
		return nil
	end
	return k
end

-- A point in a wing, as the same point in the house's own Suite or Vault (and which wing).
-- Anywhere else is itself.
function Wing.toHouse(p: Vector3): (Vector3, number?)
	local k = Wing.slotAt(p)
	if not k then
		return p, nil
	end
	return p - Wing.offset(k), k
end

return Wing

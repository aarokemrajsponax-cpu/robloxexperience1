--!strict
-- Your Suite (§3): a private room you furnish from what you've earned. Each spot holds one piece
-- (Wardrobe items of kind "suite" whose style names the spot). A spot left empty shows the house's
-- own piece where the house has one. The Gold Key opens two more rooms: the Dressing Room and the
-- Study. Each guest's screen draws only their own Suite.

local Wardrobe = require(script.Parent.Wardrobe)

local Suite = {}

export type Spot = { id: string, name: string, room: "main" | "dressing" | "study", house: boolean }

Suite.Spots = {
	{ id = "sofa", name = "The sofa", room = "main", house = true },
	{ id = "chair", name = "The armchair", room = "main", house = true },
	{ id = "rug", name = "The rug", room = "main", house = true },
	{ id = "lamp", name = "The lamp", room = "main", house = true },
	{ id = "painting", name = "Over the fireplace", room = "main", house = false },
	{ id = "bar", name = "The drinks cabinet", room = "main", house = false },
	{ id = "shelf", name = "The bookcase", room = "main", house = false },
	{ id = "mirror", name = "The Dressing Room: the glass", room = "dressing", house = false },
	{ id = "chaise", name = "The Dressing Room: the chaise", room = "dressing", house = false },
	{ id = "desk", name = "The Study: the desk", room = "study", house = false },
	{ id = "globe", name = "The Study: the globe", room = "study", house = false },
} :: { Spot }

Suite.byId = {} :: { [string]: Spot }
for _, s in Suite.Spots do
	Suite.byId[s.id] = s
end

Suite.RoomNames = { main = "The Suite", dressing = "The Dressing Room", study = "The Study" }

-- Is this room open to the guest? The Dressing Room and the Study come with the Gold Key.
function Suite.roomOpen(room: string, goldKey: boolean): boolean
	return room == "main" or goldKey
end

-- The spot a Suite piece goes in, or nil.
function Suite.spotOf(item: Wardrobe.Item): string?
	if item.kind ~= "suite" then
		return nil
	end
	local spot = item.style.spot
	return if type(spot) == "string" and Suite.byId[spot] then spot else nil
end

-- Can this piece go in this spot for a guest (owned, the right spot, the room open)?
function Suite.canPlace(spotId: string, item: Wardrobe.Item?, owned: boolean, goldKey: boolean): (boolean, string?)
	local spot = Suite.byId[spotId]
	if not spot then
		return false, "There's no such place in the Suite."
	elseif not Suite.roomOpen(spot.room, goldKey) then
		return false, Suite.RoomNames[spot.room] .. " opens with the Gold Key."
	elseif item == nil then
		return true, nil -- clearing a spot (the house's piece, or nothing)
	elseif Suite.spotOf(item) ~= spotId then
		return false, "That doesn't go there."
	elseif not owned then
		return false, "It isn't yours yet."
	end
	return true, nil
end

-- Every Suite piece that goes in a spot.
function Suite.piecesFor(spotId: string): { Wardrobe.Item }
	local out = {}
	for _, item in Wardrobe.all do
		if Suite.spotOf(item) == spotId then
			table.insert(out, item)
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

return Suite

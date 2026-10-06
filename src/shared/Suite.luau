--!strict
-- Your Suite (§3): a penthouse you furnish from what you've earned or bought. Each spot holds one
-- piece (Wardrobe items of kind "suite" whose style names the spot: SuiteCatalog). A spot left
-- empty shows the house's own piece where the house has one, so the Suite is lived-in from the
-- first visit. The Gold Key opens two more rooms: the Dressing Room and the Study. Each guest's
-- screen draws only their own Suite (SuiteView), with the Furniture library.

local Wardrobe = require(script.Parent.Wardrobe)

local Suite = {}

local rgb = Color3.fromRGB
local GOLD = rgb(198, 160, 82)

export type Room = "main" | "gallery" | "bedroom" | "spa" | "kitchen" | "terrace" | "screening" | "gym" | "dressing" | "study"
-- `kind`: the Furniture kind built there (a piece's style.kind may name another).
-- `house`: the house's own piece for an empty spot (its style), or nil (empty means empty).
export type Spot = { id: string, name: string, room: Room, kind: string, house: { [string]: any }? }

Suite.Spots = {
	-- The drawing room
	{ id = "sofa", name = "The sofa", room = "main", kind = "sofa", house = { model = "chesterfield", colour = rgb(22, 20, 22), material = "Leather" } },
	{ id = "chair", name = "The armchair", room = "main", kind = "chair", house = { model = "wing", colour = rgb(22, 20, 22), accent = GOLD } },
	{ id = "rug", name = "The rug", room = "main", kind = "rug", house = { model = "deco", colour = rgb(40, 14, 18), accent = GOLD } },
	{ id = "coffeeTable", name = "The coffee table", room = "main", kind = "coffeeTable", house = { model = "marble" } },
	{ id = "lamp", name = "The floor lamp", room = "main", kind = "lamp", house = { model = "brass", colour = rgb(236, 214, 170), accent = GOLD } },
	{ id = "chandelier", name = "The chandelier", room = "main", kind = "chandelier", house = { model = "ring", accent = GOLD } },
	{ id = "painting", name = "Over the fireplace", room = "main", kind = "painting" },
	{ id = "bar", name = "The drinks cabinet", room = "main", kind = "bar" },
	{ id = "shelf", name = "The bookcase", room = "main", kind = "shelf", house = { model = "library", colour = rgb(40, 24, 16) } },
	{ id = "plant", name = "The plant", room = "main", kind = "plant", house = { model = "palm" } },
	{ id = "display", name = "The display case", room = "main", kind = "display" },
	{ id = "piano", name = "The baby grand", room = "main", kind = "piano" },
	-- The gallery
	{ id = "galleryArtS", name = "The gallery: the south wall", room = "gallery", kind = "painting" },
	{ id = "galleryArtN", name = "The gallery: the north wall", room = "gallery", kind = "painting" },
	-- The bedroom
	{ id = "bed", name = "The bed", room = "bedroom", kind = "bed", house = { model = "classic", headboard = rgb(70, 30, 34), colour = rgb(236, 230, 218), throw = GOLD } },
	{ id = "nightstands", name = "The nightstands", room = "bedroom", kind = "nightstands", house = { colour = rgb(40, 24, 16) } },
	{ id = "bedRug", name = "The bedroom rug", room = "bedroom", kind = "rug", house = { model = "plain", colour = rgb(60, 52, 48), accent = GOLD, width = 11, depth = 9 } },
	{ id = "bedBench", name = "The end of the bed", room = "bedroom", kind = "bench" },
	{ id = "bedTv", name = "The bedroom wall", room = "bedroom", kind = "tv" },
	{ id = "dresser", name = "The dresser", room = "bedroom", kind = "dresser" },
	-- The bath and spa
	{ id = "bathtub", name = "The bath", room = "spa", kind = "bathtub", house = { model = "clawfoot", outside = rgb(240, 238, 232) } },
	{ id = "shower", name = "The shower", room = "spa", kind = "shower", house = { colour = rgb(226, 220, 210) } },
	{ id = "vanity", name = "The vanity", room = "spa", kind = "vanity", house = { colour = rgb(40, 26, 20) } },
	{ id = "sauna", name = "The sauna", room = "spa", kind = "sauna" },
	{ id = "spaPlant", name = "The spa's green", room = "spa", kind = "plant" },
	-- The kitchen
	{ id = "kitchen", name = "The kitchen", room = "kitchen", kind = "kitchen", house = { model = "marble", width = 10, colour = rgb(30, 30, 34) } },
	-- The screening room
	{ id = "screen", name = "The screen", room = "screening", kind = "screen", house = { width = 10, colour = rgb(40, 34, 40) } },
	{ id = "recliners", name = "The seats", room = "screening", kind = "recliners", house = { colour = rgb(40, 38, 40) } },
	{ id = "gaming", name = "The gaming desk", room = "screening", kind = "gaming" },
	{ id = "arcade", name = "The arcade", room = "screening", kind = "arcade" },
	{ id = "arcade2", name = "The second cabinet", room = "screening", kind = "arcade" },
	{ id = "popcorn", name = "The popcorn", room = "screening", kind = "popcorn" },
	-- The gym
	{ id = "treadmill", name = "The treadmill", room = "gym", kind = "treadmill", house = {} },
	{ id = "bike", name = "The bike", room = "gym", kind = "bike" },
	{ id = "weights", name = "The weights", room = "gym", kind = "weights", house = {} },
	{ id = "massage", name = "The recovery corner", room = "gym", kind = "massage" },
	{ id = "punchbag", name = "The punchbag", room = "gym", kind = "punchbag" },
	-- The terrace
	{ id = "pool", name = "The pool", room = "terrace", kind = "pool" },
	{ id = "hottub", name = "The hot tub", room = "terrace", kind = "hottub" },
	{ id = "loungers", name = "The loungers", room = "terrace", kind = "loungers", house = { colour = rgb(240, 234, 220) } },
	{ id = "firepit", name = "The fire pit", room = "terrace", kind = "firepit" },
	{ id = "garden", name = "The planter", room = "terrace", kind = "garden", house = { length = 10 } },
	{ id = "statue", name = "The statue", room = "terrace", kind = "statue" },
	-- The Gold Key rooms
	{ id = "mirror", name = "The Dressing Room: the glass", room = "dressing", kind = "mirror" },
	{ id = "chaise", name = "The Dressing Room: the chaise", room = "dressing", kind = "chaise" },
	{ id = "desk", name = "The Study: the desk", room = "study", kind = "desk" },
	{ id = "globe", name = "The Study: the globe", room = "study", kind = "globe" },
} :: { Spot }

Suite.byId = {} :: { [string]: Spot }
for _, s in Suite.Spots do
	Suite.byId[s.id] = s
end

-- The rooms, in the order a guest walks them (and the furnishing panel's tabs).
Suite.Rooms = { "main", "gallery", "bedroom", "spa", "kitchen", "terrace", "screening", "gym", "dressing", "study" } :: { Room }
Suite.RoomNames = {
	main = "The Drawing Room",
	gallery = "The Gallery",
	bedroom = "The Bedroom",
	spa = "The Bath & Spa",
	kitchen = "The Kitchen",
	terrace = "The Terrace",
	screening = "The Screening Room",
	gym = "The Gym",
	dressing = "The Dressing Room",
	study = "The Study",
}

-- Is this room open to the guest? The Dressing Room and the Study come with the Gold Key.
function Suite.roomOpen(room: string, goldKey: boolean): boolean
	return (room ~= "dressing" and room ~= "study") or goldKey
end

-- The spot a Suite piece goes in, or nil.
function Suite.spotOf(item: Wardrobe.Item): string?
	if item.kind ~= "suite" then
		return nil
	end
	local spot = item.style.spot
	return if type(spot) == "string" and Suite.byId[spot] then spot else nil
end

-- The Furniture kind a piece is built as (its own, or its spot's).
function Suite.kindOf(spotId: string, style: { [string]: any }?): string?
	local spot = Suite.byId[spotId]
	if not spot then
		return nil
	end
	local own = style and style.kind
	return if type(own) == "string" then own else spot.kind
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

-- Every Suite piece that goes in a spot, the house's cheapest first.
function Suite.piecesFor(spotId: string): { Wardrobe.Item }
	local out = {}
	for _, item in Wardrobe.all do
		if Suite.spotOf(item) == spotId then
			table.insert(out, item)
		end
	end
	local function rank(i: Wardrobe.Item): number
		if i.source == "gilt" or i.source == "standing" then
			return (i.gilt or 0)
		elseif i.robux then
			return 100000 + i.robux
		end
		return 50000
	end
	table.sort(out, function(a, b)
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	return out
end

-- What stands in each spot for a guest: { [spot] = style }, leaving out empty spots and rooms the
-- guest hasn't opened. `placed` is their Suite (spot -> item id).
function Suite.pieces(placed: { [string]: string }, goldKey: boolean): { [string]: { [string]: any } }
	local out = {}
	for _, spot in Suite.Spots do
		if not Suite.roomOpen(spot.room, goldKey) then
			continue
		end
		local id = placed[spot.id]
		local item = if type(id) == "string" and id ~= "" then Wardrobe.get(id) else nil
		if item and Suite.spotOf(item) == spot.id then
			out[spot.id] = item.style
		elseif spot.house then
			out[spot.id] = spot.house
		end
	end
	return out
end

return Suite

--!strict
-- Every piece a guest can put in their Suite: Wardrobe items of kind "suite" whose style names the
-- spot they stand in (style.spot), the design they're built as (style.model, style.art) and their
-- colours. A piece may be a different kind of thing from the spot's own (style.kind: the
-- bedroom's wall can hold a television or an aquarium).
--
-- How each is had, and for how much, is plain on its card: Gilt (earned at the tables), Robux
-- (one of the Boutique's price tiers; every Robux piece can also be had for Gilt), the Gold Key,
-- or a House Standing. Nothing is random: what you pay for is what stands in your Suite.

local rgb = Color3.fromRGB
local GOLD = rgb(198, 160, 82)
local PALE_GOLD = rgb(236, 210, 140)
local SILVER = rgb(200, 206, 214)
local BLACK = rgb(18, 18, 20)
local IVORY = rgb(234, 226, 210)

type Style = { [string]: any }
type Item = { [string]: any }

local items: { Item } = {}

local function add(spot: string, id: string, name: string, line: string, style: Style, price: { [string]: any })
	style.spot = spot
	local item: Item = { id = id, name = name, kind = "suite", line = line, style = style }
	for k, v in price do
		item[k] = v
	end
	table.insert(items, item)
end
-- How a piece is had.
local function gilt(n: number): { [string]: any }
	return { source = "gilt", gilt = n }
end
local function robux(n: number): { [string]: any }
	return { source = "boutique", robux = n }
end
local function goldKey(): { [string]: any }
	return { source = "goldKey" }
end
local function standing(n: number, rank: string): { [string]: any }
	return { source = "standing", gilt = n, standing = rank }
end

---------------------------------------------------------------------------------------------------
-- The drawing room
---------------------------------------------------------------------------------------------------
add("sofa", "suite_sofa_chesterfield", "Chesterfield", "Buttoned leather, rolled arms.", { model = "chesterfield", colour = rgb(70, 30, 20), material = "Leather" }, gilt(1500))
add("sofa", "suite_sofa_ivory", "Ivory Crescent Sofa", "Pale silk in a curve, made for a conversation.", { model = "curved", colour = rgb(228, 218, 196), accent = GOLD }, robux(249))
add("sofa", "suite_sofa_emerald", "Emerald Crescent", "Deep green velvet around the fire.", { model = "curved", colour = rgb(24, 74, 58) }, gilt(4200))
add("sofa", "suite_sofa_linen", "Linen Lounge Sofa", "Low, long and very soft.", { model = "modern", colour = rgb(214, 204, 186), accent = rgb(170, 120, 60) }, gilt(2200))
add("sofa", "suite_sofa_noir", "Noir Sectional", "Charcoal, with room to stretch out.", { model = "sectional", colour = rgb(44, 44, 50), accent = GOLD }, robux(299))
add("sofa", "suite_sofa_royal", "The Royal Chesterfield", "Oxblood velvet, every button gilt. The finest sofa in the house.", { model = "chesterfield", colour = rgb(96, 16, 30), accent = PALE_GOLD }, robux(499))

add("chair", "suite_chair_velvet", "Oxblood Wing Chair", "Deep velvet, high wings.", { model = "wing", colour = rgb(92, 20, 30), accent = GOLD }, gilt(600))
add("chair", "suite_chair_leather", "Club Leather Armchair", "Worn in by nobody but you.", { model = "club", colour = rgb(84, 44, 26), material = "Leather" }, gilt(900))
add("chair", "suite_chair_emerald", "Emerald Club Chair", "Green as the old baize.", { model = "club", colour = rgb(18, 70, 46), accent = GOLD }, robux(149))
add("chair", "suite_chair_goldkey", "The Gold Key Chair", "Gold Key holders only.", { model = "wing", colour = rgb(20, 16, 10), accent = rgb(236, 196, 98) }, goldKey())
add("chair", "suite_chair_barrel", "Cream Barrel Chair", "A round, deep seat in bouclé.", { model = "barrel", colour = rgb(214, 200, 176) }, gilt(1800))
add("chair", "suite_chair_lounge", "The Lounge Chair & Ottoman", "Walnut shells and black leather. A classic.", { model = "lounge", colour = rgb(22, 20, 20) }, robux(249))

add("rug", "suite_rug_persian", "Night Garden Rug", "Deep reds, knotted by hand.", { model = "persian", colour = rgb(96, 24, 28), accent = rgb(196, 150, 80) }, gilt(800))
add("rug", "suite_rug_black", "Black Deco Rug", "Black wool, a gold fan in the middle.", { model = "deco", colour = rgb(14, 14, 16), accent = GOLD }, gilt(400))
add("rug", "suite_rug_moon", "Moonlit Rug", "Ink blue, a silver ring.", { model = "round", colour = rgb(20, 24, 48), accent = SILVER }, robux(149))
add("rug", "suite_rug_ivory", "Ivory Border Rug", "Pale wool, a fine gold border.", { model = "plain", colour = rgb(226, 218, 200), accent = GOLD }, gilt(1200))
add("rug", "suite_rug_emerald", "Emerald Persian", "Green and gold, a hundred years old.", { model = "persian", colour = rgb(20, 60, 44), accent = rgb(210, 170, 90) }, gilt(3000))

add("coffeeTable", "suite_table_marble", "Marble Drum Table", "Carrara on brass.", { model = "marble" }, gilt(900))
add("coffeeTable", "suite_table_glass", "Glass & Brass Table", "Two tiers, books on the lower.", { model = "glass" }, gilt(1400))
add("coffeeTable", "suite_table_block", "Walnut Block", "One piece of wood, a brass tray.", { model = "block" }, gilt(700))

add("lamp", "suite_lamp_crystal", "Crystal Lamp", "Cut glass, cold white light.", { model = "crystal", colour = rgb(230, 240, 255), accent = SILVER }, robux(99))
add("lamp", "suite_lamp_brass", "Brass Floor Lamp", "A pleated silk shade.", { model = "brass", colour = rgb(236, 214, 170), accent = GOLD }, gilt(300))
add("lamp", "suite_lamp_green", "Library Lamp", "A green silk shade on brass.", { model = "brass", colour = rgb(40, 96, 66), accent = GOLD }, gilt(450))
add("lamp", "suite_lamp_arc", "Arc Lamp", "A brass arc over the sofa.", { model = "arc", accent = GOLD }, gilt(2400))
add("lamp", "suite_lamp_tripod", "Tripod Lamp", "Three walnut legs, a linen drum.", { model = "tripod", colour = rgb(230, 220, 200) }, gilt(800))

add("painting", "suite_painting", "A Suite Painting", "A small oil of the house at night.", { art = "night", colour = rgb(40, 44, 70), accent = GOLD }, { source = "introduction" })
add("painting", "suite_painting_portrait", "A Portrait of a Stranger", "Nobody knows who sat for it.", { art = "portrait", colour = rgb(70, 46, 34), accent = GOLD }, gilt(1200))
add("painting", "suite_painting_ballroom", "The Last Lamp", "A still life by the last lamp lit.", { art = "still", colour = rgb(30, 22, 18), accent = GOLD }, robux(149))
add("painting", "suite_painting_skyline", "The City at Three", "Lit windows, one by one.", { art = "night", colour = rgb(16, 22, 44), accent = rgb(216, 186, 120) }, robux(99))
add("painting", "suite_painting_field", "Colour Field", "Two reds and a line of gold.", { art = "abstract", colour = rgb(220, 210, 196), a = rgb(170, 50, 40), b = rgb(40, 36, 60) }, gilt(2600))
add("painting", "suite_painting_valley", "The Valley at Evening", "Hills going blue, the sun going down.", { art = "landscape", colour = rgb(206, 164, 120) }, gilt(1800))

add("bar", "suite_bar_walnut", "Walnut Drinks Cabinet", "For Patrons of the house.", { model = "walnut", colour = rgb(66, 38, 24), accent = GOLD }, standing(2000, "Patron"))
add("bar", "suite_bar_lacquer", "Black Lacquer Bar", "Mirrored inside, lit when opened.", { model = "lacquer", colour = rgb(10, 10, 12), accent = rgb(236, 216, 166) }, robux(299))
add("bar", "suite_bar_cart", "Brass Bar Cart", "Bottles, a decanter, two shelves of glass.", { model = "cart" }, gilt(1600))

add("shelf", "suite_shelf_books", "A Wall of Books", "Leather spines, never read.", { model = "library", colour = rgb(40, 24, 16), accent = rgb(110, 30, 26) }, gilt(1000))
add("shelf", "suite_shelf_display", "Ebony Display Shelves", "Objets d'art, lit from above.", { model = "display", colour = rgb(20, 18, 18), accent = GOLD }, gilt(2800))

add("chandelier", "suite_chandelier_ring", "Ring of Candles", "Eight candles on a brass hoop.", { model = "ring", accent = GOLD }, gilt(1500))
add("chandelier", "suite_chandelier_crystal", "Crystal Chandelier", "Three tiers of drops, catching every light.", { model = "crystal", accent = PALE_GOLD }, robux(399))
add("chandelier", "suite_chandelier_sputnik", "Starburst", "Fourteen arms of brass and light.", { model = "sputnik", accent = GOLD }, gilt(5200))
add("chandelier", "suite_chandelier_cascade", "Cascade", "Strands of glass falling from a gold crown.", { model = "cascade", accent = GOLD }, robux(299))

add("plant", "suite_plant_palm", "Kentia Palm", "In a black pot.", { model = "palm" }, gilt(500))
add("plant", "suite_plant_fiddle", "Fiddle-Leaf Fig", "Big leaves, very fashionable.", { model = "fiddle" }, gilt(700))
add("plant", "suite_plant_olive", "Olive Tree", "Silver-green, in a white pot.", { model = "olive", pot = IVORY }, gilt(1200))
add("plant", "suite_plant_topiary", "Box Topiary", "Two clipped spheres.", { model = "topiary", pot = BLACK }, gilt(600))

add("display", "suite_display_ebony", "Ebony Vitrine", "Glass on three sides, lit within. For what you've found.", { colour = rgb(24, 18, 16), accent = GOLD }, gilt(3500))
add("display", "suite_display_ivory", "Ivory Vitrine", "Lacquered ivory, brass corners.", { colour = IVORY, accent = GOLD }, robux(199))
add("display", "suite_display_aquarium", "The Reef", "A wall of water: coral, sand and seven fish.", { kind = "aquarium" }, robux(599))

add("piano", "suite_piano_black", "Baby Grand", "Black lacquer, your own keys. Play it any time, free.", { colour = rgb(12, 12, 14), accent = GOLD }, robux(499))
add("piano", "suite_piano_white", "White Baby Grand", "Ivory lacquer and gold. Play it any time, free.", { colour = rgb(236, 232, 224), accent = PALE_GOLD, bench = rgb(236, 232, 224) }, robux(599))

---------------------------------------------------------------------------------------------------
-- The gallery
---------------------------------------------------------------------------------------------------
for _, spot in { "galleryArtS", "galleryArtN" } do
	local side = if spot == "galleryArtS" then "s" else "n"
	add(spot, "suite_gallery_" .. side .. "_night", "Nocturne", "The city after midnight.", { art = "night", width = 5, height = 3.4, colour = rgb(20, 24, 50) }, gilt(900))
	add(spot, "suite_gallery_" .. side .. "_portrait", "The Sitter", "Who were they? Nobody remembers.", { art = "portrait", width = 3.2, height = 4, colour = rgb(60, 40, 30) }, gilt(1100))
	add(spot, "suite_gallery_" .. side .. "_field", "Red over Ink", "Bold, quiet, expensive.", { art = "abstract", width = 5, height = 3.4, colour = rgb(230, 220, 200), a = rgb(190, 40, 40), b = rgb(30, 30, 46) }, robux(149))
	add(spot, "suite_gallery_" .. side .. "_valley", "Summer Hills", "Somewhere warm.", { art = "landscape", width = 5, height = 3.4 }, gilt(1300))
end

---------------------------------------------------------------------------------------------------
-- The bedroom
---------------------------------------------------------------------------------------------------
add("bed", "suite_bed_linen", "Linen Bed", "A tall channelled headboard in sand linen.", { model = "classic", headboard = rgb(196, 180, 150), colour = rgb(240, 236, 228), throw = rgb(170, 140, 100) }, gilt(1800))
add("bed", "suite_bed_velvet", "Midnight Velvet Bed", "Ink velvet, a gold throw.", { model = "classic", headboard = rgb(24, 26, 48), colour = rgb(232, 228, 220), throw = GOLD }, gilt(4500))
add("bed", "suite_bed_canopy", "Four-Poster", "Walnut posts and white muslin.", { model = "canopy", wood = rgb(52, 32, 22) }, robux(299))
add("bed", "suite_bed_round", "The Round Bed", "A circle of navy velvet, lit from beneath.", { model = "round", headboard = rgb(26, 28, 56), accent = PALE_GOLD }, robux(399))
add("bed", "suite_bed_floating", "Floating Bed", "A platform on a line of light.", { model = "floating", headboard = rgb(44, 44, 48), accent = rgb(255, 200, 140) }, gilt(7200))
add("bed", "suite_bed_royal", "The Royal Bed", "Gilded, crowned, curtained in velvet. Fit for the house's best.", { model = "royal", headboard = rgb(80, 14, 30), drape = rgb(90, 14, 30), colour = rgb(240, 232, 216), throw = rgb(214, 176, 92) }, robux(599))

add("nightstands", "suite_nightstands_walnut", "Walnut Nightstands", "A pair, with linen lamps.", { colour = rgb(56, 34, 22) }, gilt(700))
add("nightstands", "suite_nightstands_marble", "Marble-Top Nightstands", "Black lacquer, white marble.", { model = "marble", colour = rgb(16, 16, 18), shade = rgb(240, 230, 210) }, gilt(1600))

add("bedRug", "suite_bedrug_ivory", "Ivory Rug", "Soft underfoot, first thing in the morning.", { model = "plain", colour = rgb(226, 218, 200), accent = GOLD }, gilt(600))
add("bedRug", "suite_bedrug_round", "Round Silk Rug", "Rose silk in rings.", { model = "round", colour = rgb(150, 90, 100), accent = rgb(230, 200, 190) }, gilt(1400))
add("bedRug", "suite_bedrug_persian", "Persian Runner", "Faded reds.", { model = "persian", colour = rgb(120, 40, 40), accent = rgb(200, 160, 100) }, robux(99))

add("bedBench", "suite_bench_velvet", "Velvet End Bench", "Buttoned, on brass legs.", { colour = rgb(196, 170, 120) }, gilt(900))
add("bedBench", "suite_bench_ink", "Ink Bench", "Navy velvet, gold legs.", { colour = rgb(26, 28, 52) }, gilt(1300))

add("bedTv", "suite_tv_wall", "Media Wall", "A wide screen over a long walnut console.", { model = "wall", colour = rgb(40, 26, 18) }, gilt(3200))
add("bedTv", "suite_tv_frame", "The Frame", "A screen in a gilt frame, over marble.", { model = "frame", colour = rgb(18, 16, 16), accent = GOLD }, robux(299))
add("bedTv", "suite_tv_reef", "The Bedroom Reef", "An aquarium where the television would be.", { kind = "aquarium" }, robux(599))

add("dresser", "suite_dresser_ivory", "Ivory Dresser", "Nine drawers, a gilt glass.", { colour = rgb(232, 224, 208) }, gilt(1500))
add("dresser", "suite_dresser_walnut", "Walnut Dresser", "Brass knobs, a tall glass.", { colour = rgb(56, 34, 22), material = "Wood" }, gilt(2200))

---------------------------------------------------------------------------------------------------
-- The bath and spa
---------------------------------------------------------------------------------------------------
add("bathtub", "suite_tub_clawfoot", "Clawfoot Bath", "Black outside, white within, gold feet.", { model = "clawfoot", outside = rgb(22, 22, 26) }, gilt(1500))
add("bathtub", "suite_tub_rose", "Rose Clawfoot", "Blush outside, gold claws.", { model = "clawfoot", outside = rgb(200, 150, 150) }, gilt(2800))
add("bathtub", "suite_tub_stone", "Stone Bath", "One piece of travertine.", { model = "stone" }, robux(199))
add("bathtub", "suite_tub_sunken", "The Marble Pool Bath", "Sunk into a marble dais between two columns.", { model = "sunken" }, robux(499))

add("shower", "suite_shower_marble", "Rain Shower", "Marble walls, a gold rain head.", { colour = rgb(226, 220, 210) }, gilt(1200))
add("shower", "suite_shower_black", "Black Marble Shower", "Dark stone, gold fittings.", { colour = rgb(28, 28, 32) }, gilt(3400))

add("vanity", "suite_vanity_walnut", "Double Vanity", "Two basins, two round glasses.", { colour = rgb(40, 26, 20) }, gilt(1100))
add("vanity", "suite_vanity_black", "Black Marble Vanity", "Lacquer and black marble.", { model = "black", colour = rgb(16, 16, 18) }, gilt(2600))

add("sauna", "suite_sauna_cedar", "Cedar Sauna", "Hot stones, two tiers of benches. Pour water for steam.", {}, robux(399))
add("sauna", "suite_sauna_ash", "Pale Ash Sauna", "Light wood, the same heat.", { colour = rgb(214, 186, 150) }, gilt(9000))

add("spaPlant", "suite_spaplant_fiddle", "Fiddle-Leaf Fig", "Loves the steam.", { model = "fiddle", pot = IVORY }, gilt(600))
add("spaPlant", "suite_spaplant_orchid", "White Orchid", "On the marble ledge.", { model = "orchid" }, gilt(400))

---------------------------------------------------------------------------------------------------
-- The kitchen
---------------------------------------------------------------------------------------------------
add("kitchen", "suite_kitchen_marble", "Marble Kitchen", "Ivory doors, Carrara tops, brass pulls.", { model = "marble", width = 10, colour = rgb(26, 70, 48) }, gilt(2500))
add("kitchen", "suite_kitchen_noir", "Noir Kitchen", "Black lacquer, black marble, gold.", { model = "noir", width = 10, colour = rgb(90, 20, 30) }, robux(399))
add("kitchen", "suite_kitchen_walnut", "Walnut Kitchen", "Warm wood and white stone.", { model = "walnut", width = 10, colour = rgb(40, 40, 44) }, gilt(5600))

---------------------------------------------------------------------------------------------------
-- The screening room
---------------------------------------------------------------------------------------------------
add("screen", "suite_screen_velvet", "Velvet Screen", "A screen between red curtains. Start a film.", { width = 10, colour = rgb(90, 14, 30) }, gilt(3000))
add("screen", "suite_screen_midnight", "Midnight Screen", "Navy curtains, gold trim.", { width = 10, colour = rgb(20, 24, 56) }, robux(299))

add("recliners", "suite_recliners_black", "Leather Recliners", "Three, with cup holders and a glow underneath.", { colour = rgb(22, 20, 20) }, gilt(2400))
add("recliners", "suite_recliners_red", "Red Velvet Recliners", "Like the old picture palaces.", { colour = rgb(110, 20, 30) }, robux(199))

add("gaming", "suite_gaming_violet", "The Battlestation", "Three screens, a lit tower, a racing chair.", { colour = rgb(140, 90, 255) }, robux(299))
add("gaming", "suite_gaming_gold", "Gold Battlestation", "The same, in the house's gold.", { colour = rgb(255, 196, 90) }, gilt(8000))

for _, spot in { "arcade", "arcade2" } do
	local n = if spot == "arcade" then "" else "2"
	add(spot, "suite_arcade" .. n .. "_classic", "Arcade Cabinet", "Insert no coin: it's yours.", { model = "classic", colour = rgb(30, 30, 70), accent = rgb(255, 60, 160) }, gilt(2000))
	add(spot, "suite_arcade" .. n .. "_racer", "Racing Cabinet", "A seat, a wheel and a long straight.", { model = "racing", colour = rgb(120, 20, 20), accent = rgb(255, 200, 40) }, robux(249))
	add(spot, "suite_arcade" .. n .. "_pinball", "Pinball Table", "Bumpers, lights, glass.", { model = "pinball", colour = rgb(20, 40, 80), accent = rgb(255, 120, 200) }, robux(199))
end

add("popcorn", "suite_popcorn", "Popcorn Cart", "Red and gold, always full.", {}, gilt(600))

---------------------------------------------------------------------------------------------------
-- The gym
---------------------------------------------------------------------------------------------------
add("treadmill", "suite_treadmill", "Treadmill", "Facing the glass and the city.", {}, gilt(1500))
add("bike", "suite_bike", "Spin Bike", "Gold flywheel.", {}, gilt(1200))
add("bike", "suite_bike_black", "Black Spin Bike", "All black.", { colour = rgb(30, 30, 34) }, gilt(900))
add("weights", "suite_weights", "Dumbbell Rack", "Gold and black, two tiers.", {}, gilt(1300))
add("massage", "suite_massage", "Massage Chair", "Lie back. Press start.", { colour = rgb(30, 28, 30) }, robux(249))
add("massage", "suite_massage_ivory", "Ivory Massage Chair", "Cream leather, gold arms.", { colour = rgb(226, 214, 194) }, gilt(9500))
add("punchbag", "suite_punchbag", "Punchbag", "Oxblood leather on a black stand.", {}, gilt(800))

---------------------------------------------------------------------------------------------------
-- The terrace
---------------------------------------------------------------------------------------------------
add("pool", "suite_pool_blue", "The Pool", "Glass to the deck, lit within. Wade in.", { model = "infinity" }, robux(499))
add("pool", "suite_pool_lagoon", "Lagoon Pool", "Turquoise water, rocks and a waterfall.", { model = "lagoon" }, robux(599))
add("pool", "suite_pool_gold", "The Gold Pool", "Gold mosaic, marble edges. The pool of the house.", { model = "gold", colour = rgb(90, 190, 200) }, robux(599))
add("pool", "suite_pool_gilt", "The Patron's Pool", "Blue water, travertine edges.", { model = "infinity", colour = rgb(60, 160, 200) }, standing(30000, "Patron"))

add("hottub", "suite_hottub_teak", "Hot Tub", "Teak, eight feet across, bubbles on demand.", {}, robux(299))
add("hottub", "suite_hottub_stone", "Stone Hot Tub", "Travertine and marble.", { model = "stone" }, gilt(12000))

add("loungers", "suite_loungers", "Sun Loungers", "Two, a parasol, a cold drink.", { colour = rgb(240, 234, 220) }, gilt(1400))
add("loungers", "suite_loungers_black", "Black Loungers", "Lacquer frames, ink cushions.", { model = "black", colour = rgb(30, 32, 48), accent = rgb(30, 32, 48) }, gilt(2600))

add("firepit", "suite_firepit", "Fire Pit", "Stone, a ring of sofas, the night sky.", { colour = rgb(196, 170, 120) }, robux(249))
add("firepit", "suite_firepit_black", "Black Marble Fire Pit", "Ink cushions round a black bowl.", { model = "black", colour = rgb(40, 40, 56) }, gilt(9000))

add("garden", "suite_garden", "Olive Planter", "Two olive trees, lavender between.", {}, gilt(1100))
add("garden", "suite_garden_white", "White Planter", "Olives and white roses.", { model = "white", colour = rgb(244, 240, 232) }, gilt(1800))

add("statue", "suite_statue_marble", "Marble Muse", "Holding up a gold torch.", {}, gilt(3600))
add("statue", "suite_statue_gold", "The Gold Muse", "Gilded head to foot.", { metal = true, colour = rgb(214, 176, 92) }, robux(399))

---------------------------------------------------------------------------------------------------
-- The Gold Key rooms
---------------------------------------------------------------------------------------------------
add("mirror", "suite_mirror_gilt", "Gilt Pier Glass", "Tall enough for the whole look.", { colour = SILVER, accent = GOLD }, gilt(1400))
add("mirror", "suite_mirror_round", "Round Glass", "A gold ring of a mirror.", { model = "round", accent = GOLD }, gilt(900))
add("chaise", "suite_chaise_velvet", "Velvet Chaise", "For waiting while someone dresses.", { colour = rgb(46, 10, 18), accent = GOLD }, gilt(1800))
add("chaise", "suite_chaise_ivory", "Ivory Chaise", "Cream silk, brass feet.", { colour = rgb(226, 214, 194), accent = GOLD }, robux(149))
add("desk", "suite_desk_partners", "Partners' Desk", "For Connoisseurs.", { colour = rgb(52, 30, 20), accent = rgb(26, 70, 48) }, standing(3000, "Connoisseur"))
add("desk", "suite_desk_ebony", "Ebony Writing Desk", "Black wood, red leather.", { colour = rgb(24, 18, 16), accent = rgb(110, 24, 30) }, gilt(2400))
add("globe", "suite_globe", "Library Globe", "Old borders, brass meridian.", { colour = rgb(196, 170, 120), accent = GOLD }, gilt(700))

return items

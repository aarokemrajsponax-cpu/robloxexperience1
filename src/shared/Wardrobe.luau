--!strict
-- Everything the house can dress you in (§12, Appendix I3): table styles, lamp styles, chimes,
-- guide trails, nameplate frames, round-card backs, victory flourishes, gestures, house looks and
-- Suite pieces. All of it is style, never score. Robux prices here only choose a price tier: the
-- price a guest sees is always read live from Roblox. Items that need an uploaded asset (a look's
-- clothing, a chime's sound, a gesture's animation) are only offered once Config has the asset.

local Config = require(script.Parent.Config)
local Seasons = require(script.Parent.Seasons)
local SoundSheet = require(script.Parent.SoundSheet)

local Wardrobe = {}

export type Kind = "look" | "table" | "lamp" | "chime" | "trail" | "gesture" | "flourish" | "nameplate" | "card" | "suite"
export type Source = "blackCard" | "boutique" | "gilt" | "goldKey" | "introduction" | "ledger" | "season" | "standing"

export type Item = {
	id: string,
	name: string,
	kind: Kind,
	line: string,
	source: Source,
	robux: number?, -- the Boutique price tier (Appendix I3)
	gilt: number?, -- a Gilt price
	standing: string?, -- the House Standing needed to buy it
	season: string?, -- a season collection piece: sold only in its season
	always: boolean?, -- always on the Boutique's shelves ("Always in the house"), not in the rotation
	style: { [string]: any },
}

Wardrobe.Kinds = { "table", "lamp", "trail", "chime", "nameplate", "card", "flourish", "gesture", "look", "suite" } :: { Kind }
Wardrobe.KindNames = {
	look = "House looks",
	table = "Table styles",
	lamp = "Lamp styles",
	chime = "Chimes",
	trail = "Guide trails",
	gesture = "Gestures",
	flourish = "Victory flourishes",
	nameplate = "Nameplate frames",
	card = "Round-card backs",
	suite = "Suite pieces",
}

-- The price tiers the Boutique sells at (one developer product each).
Wardrobe.Tiers = { 49, 79, 99, 149, 199, 249, 299, 399, 499, 599 }

local rgb = Color3.fromRGB
local GOLD = rgb(198, 160, 82)
local SILVER = rgb(186, 190, 198)

local items: { Item } = {
	-- Table styles: the felt and the case rims of whichever table you sit at.
	{ id = "table_oxblood", name = "Oxblood Felt", kind = "table", source = "boutique", robux = 249, always = true, line = "Deep red felt, gold rims.", style = { felt = rgb(74, 18, 26), rim = GOLD } },
	{ id = "table_sapphire", name = "Sapphire Silk", kind = "table", source = "boutique", robux = 299, line = "Blue silk, silver rims.", style = { felt = rgb(20, 40, 90), rim = SILVER } },
	{ id = "table_rose", name = "Rose Velvet", kind = "table", source = "boutique", robux = 349, line = "Dusky rose, gold rims.", style = { felt = rgb(112, 46, 60), rim = GOLD } },
	{ id = "table_gilded", name = "Gilded Baize", kind = "table", source = "boutique", robux = 599, line = "Bronze baize, rims of pale gold. The finest table in the house.", style = { felt = rgb(64, 50, 22), rim = rgb(250, 222, 150) } },
	{ id = "table_ivory", name = "Ivory Felt", kind = "table", source = "boutique", robux = 349, line = "Pale felt that makes every piece read.", style = { felt = rgb(214, 204, 186), rim = GOLD } },
	{ id = "table_midnight", name = "Midnight Baize", kind = "table", source = "boutique", robux = 449, line = "Ink-blue baize and silver rims.", style = { felt = rgb(18, 24, 52), rim = SILVER } },
	{ id = "table_emerald", name = "Emerald Club", kind = "table", source = "gilt", gilt = 2000, line = "The old club green.", style = { felt = rgb(16, 52, 36), rim = GOLD } },
	{ id = "table_smoke", name = "Smoke and Brass", kind = "table", source = "gilt", gilt = 3500, line = "Grey felt, dark brass.", style = { felt = rgb(42, 42, 46), rim = rgb(111, 87, 34) } },
	{ id = "table_noir", name = "Black Lacquer", kind = "table", source = "gilt", gilt = 6000, line = "Black on black, the rims in pale gold.", style = { felt = rgb(12, 12, 14), rim = rgb(236, 216, 166) } },
	{ id = "table_goldkey", name = "The Gold Key Trim", kind = "table", source = "goldKey", line = "Gold Key holders only.", style = { felt = rgb(22, 18, 12), rim = rgb(236, 196, 98) } },

	-- Lamp styles: the colour of your table's lamp (Ballroom lamp styles, Appendix I3).
	{ id = "lamp_rose", name = "Rose Glass", kind = "lamp", source = "boutique", robux = 149, line = "A lamp with a blush in it.", style = { colour = rgb(255, 196, 196) } },
	{ id = "lamp_moon", name = "Moonlight", kind = "lamp", source = "boutique", robux = 149, line = "Cool and silver.", style = { colour = rgb(206, 222, 255) } },
	{ id = "lamp_emerald", name = "Emerald Glass", kind = "lamp", source = "boutique", robux = 149, line = "The green of an old club.", style = { colour = rgb(170, 240, 200) } },
	{ id = "lamp_amber", name = "Amber", kind = "lamp", source = "boutique", robux = 149, line = "Honey-coloured, low and warm.", style = { colour = rgb(255, 170, 90) } },
	{ id = "lamp_candle", name = "Candlelight", kind = "lamp", source = "boutique", robux = 149, always = true, line = "Warm as a candle.", style = { colour = rgb(255, 188, 120) } },
	{ id = "lamp_absinthe", name = "Absinthe", kind = "lamp", source = "boutique", robux = 149, line = "A faint green, very late.", style = { colour = rgb(212, 246, 196) } },

	-- Chimes: the sound of a correct filing (need an uploaded sound in Config.Assets.Sounds.chimes).
	{ id = "chime_harp", name = "The Harp", kind = "chime", source = "boutique", robux = 99, line = "A plucked string for every piece.", style = { sound = "harp" } },
	{ id = "chime_musicbox", name = "The Music Box", kind = "chime", source = "boutique", robux = 99, line = "A small comb of steel.", style = { sound = "musicBox" } },
	{ id = "chime_celesta", name = "The Celesta", kind = "chime", source = "introduction", robux = 99, line = "Little bells, struck softly.", style = { sound = "celesta" } },
	{ id = "chime_glass", name = "The Glass Harmonica", kind = "chime", source = "boutique", robux = 99, line = "A wet finger on crystal.", style = { sound = "glass" } },

	-- Guide trails: the colour of the thread that shows the way.
	{ id = "trail_onyx", name = "Onyx Smoke", kind = "trail", source = "boutique", robux = 79, line = "A grey thread, like smoke.", style = { colour = rgb(120, 120, 132) } },
	{ id = "trail_ruby", name = "Ruby", kind = "trail", source = "boutique", robux = 99, line = "A red thread, bright as a stone.", style = { colour = rgb(224, 64, 84) } },
	{ id = "trail_aurora", name = "Aurora", kind = "trail", source = "boutique", robux = 149, line = "Green-white, like northern light.", style = { colour = rgb(150, 255, 214) } },
	{ id = "trail_champagne", name = "Champagne", kind = "trail", source = "boutique", robux = 79, always = true, line = "Pale gold and fizzing.", style = { colour = rgb(246, 226, 170) } },
	{ id = "trail_sapphire", name = "Sapphire", kind = "trail", source = "boutique", robux = 99, line = "A deep blue thread.", style = { colour = rgb(96, 136, 232) } },
	{ id = "trail_pearl", name = "Pearl", kind = "trail", source = "boutique", robux = 149, line = "White with a sheen of colour.", style = { colour = rgb(244, 240, 232) } },
	{ id = "trail_rosegold", name = "Rose Gold", kind = "trail", source = "gilt", gilt = 800, line = "Copper warmed with pink.", style = { colour = rgb(232, 170, 146) } },
	{ id = "trail_jade", name = "Jade", kind = "trail", source = "gilt", gilt = 800, line = "Green stone, polished.", style = { colour = rgb(126, 196, 160) } },
	{ id = "trail_ember", name = "Ember", kind = "trail", source = "gilt", gilt = 800, line = "The last of the fire.", style = { colour = rgb(236, 128, 76) } },

	-- Nameplate frames: the plate over your head.
	{ id = "plate_filigree", name = "Gold Filigree", kind = "nameplate", source = "boutique", robux = 149, line = "Fine gold wire on black.", style = { frame = GOLD, fill = rgb(26, 20, 12), line = rgb(250, 230, 170) } },
	{ id = "plate_enamel", name = "Midnight Enamel", kind = "nameplate", source = "boutique", robux = 99, line = "Blue enamel, a silver edge.", style = { frame = SILVER, fill = rgb(14, 20, 44) } },
	{ id = "plate_silver", name = "Engraved Silver", kind = "nameplate", source = "boutique", robux = 99, always = true, line = "A plate of hand-engraved silver.", style = { frame = SILVER, fill = rgb(20, 22, 26) } },
	{ id = "plate_onyx", name = "Onyx Rim", kind = "nameplate", source = "boutique", robux = 99, line = "Black stone, a hairline of gold.", style = { frame = rgb(24, 24, 26), fill = rgb(10, 10, 12), line = GOLD } },
	{ id = "plate_pearl", name = "Pearl Inlay", kind = "nameplate", source = "boutique", robux = 99, line = "Mother of pearl, set in brass.", style = { frame = rgb(232, 226, 214), fill = rgb(30, 28, 26) } },
	{ id = "plate_blackcard", name = "The Black Lacquer Nameplate", kind = "nameplate", source = "blackCard", line = "While you hold the Black Card.", style = { frame = rgb(58, 54, 60), fill = rgb(4, 4, 6), line = rgb(232, 226, 214) } },
	{ id = "plate_goldkey", name = "The Gold Key Nameplate", kind = "nameplate", source = "goldKey", line = "Gold-edged, for Gold Key holders.", style = { frame = rgb(236, 196, 98), fill = rgb(16, 14, 10), line = rgb(236, 196, 98) } },

	-- Round-card backs: the card that lands on the felt between rounds.
	{ id = "card_damask", name = "Damask", kind = "card", source = "boutique", robux = 99, line = "A woven pattern in burgundy.", style = { back = rgb(62, 18, 28), pattern = "damask" } },
	{ id = "card_pinstripe", name = "Pinstripe", kind = "card", source = "boutique", robux = 99, line = "Charcoal with a fine chalk stripe.", style = { back = rgb(34, 34, 38), pattern = "pinstripe" } },
	{ id = "card_deco", name = "Art Deco", kind = "card", source = "boutique", robux = 99, line = "Teal and gold, in fine stripes.", style = { back = rgb(16, 40, 44), pattern = "pinstripe" } },
	{ id = "card_marble", name = "White Marble", kind = "card", source = "boutique", robux = 99, line = "Pale stone, veined.", style = { back = rgb(226, 220, 208), pattern = "damask" } },
	{ id = "card_monogram", name = "Monogram", kind = "card", source = "boutique", robux = 99, always = true, line = "The house initials, repeated.", style = { back = rgb(20, 18, 14), pattern = "monogram" } },

	-- Victory flourishes: a Library win, and the last lamp in the Ballroom.
	{ id = "flourish_stardust", name = "Stardust", kind = "flourish", source = "boutique", robux = 199, line = "A drift of cold silver light.", style = { colour = rgb(200, 220, 255), kind = "leaf" } },
	{ id = "flourish_petals", name = "Rose Petals", kind = "flourish", source = "boutique", robux = 199, line = "Petals falling on the felt.", style = { colour = rgb(240, 150, 170), kind = "leaf" } },
	{ id = "flourish_leaf", name = "Gold Leaf", kind = "flourish", source = "boutique", robux = 149, always = true, line = "Flakes of gold leaf, drifting.", style = { colour = rgb(236, 206, 120), kind = "leaf" } },
	{ id = "flourish_snuff", name = "Candle Snuff", kind = "flourish", source = "boutique", robux = 199, line = "A curl of smoke and a spark.", style = { colour = rgb(220, 214, 206), kind = "snuff" } },
	{ id = "flourish_spray", name = "Champagne", kind = "flourish", source = "boutique", robux = 249, line = "A spray of pale gold.", style = { colour = rgb(250, 232, 176), kind = "spray" } },

	-- Gestures (need an uploaded animation in Config.Assets.Animations).
	{ id = "gesture_tiphat", name = "Tip of the Hat", kind = "gesture", source = "boutique", robux = 49, line = "A small courtesy.", style = { animation = "tipHat" } },
	{ id = "gesture_clap", name = "Slow Applause", kind = "gesture", source = "boutique", robux = 79, line = "Three slow claps.", style = { animation = "applause" } },
	{ id = "gesture_bow", name = "The Bow", kind = "gesture", source = "boutique", robux = 99, line = "Unhurried, from the waist.", style = { animation = "bow" } },

	-- House looks (need clothing in Config.Assets.Looks).
	{ id = "look_velvet", name = "Velvet Evening Jacket", kind = "look", source = "introduction", robux = 199, line = "Black velvet, satin lapels.", style = { outfit = "velvet" } },
	{ id = "look_gown", name = "Silk Evening Gown", kind = "look", source = "boutique", robux = 299, line = "Midnight silk to the floor.", style = { outfit = "gown" } },
	{ id = "look_tux", name = "Midnight Tuxedo", kind = "look", source = "boutique", robux = 399, line = "Ink blue, cut close.", style = { outfit = "tux" } },
	{ id = "look_cape", name = "Opera Cape", kind = "look", source = "boutique", robux = 499, line = "For leaving the house at 3 am.", style = { outfit = "cape" } },
	{ id = "look_gk1", name = "Gold Key Smoking Jacket", kind = "look", source = "goldKey", line = "Gold Key holders only.", style = { outfit = "goldKey1" } },
	{ id = "look_gk2", name = "Gold Key Gown", kind = "look", source = "goldKey", line = "Gold Key holders only.", style = { outfit = "goldKey2" } },
	{ id = "look_gk3", name = "Gold Key Tails", kind = "look", source = "goldKey", line = "Gold Key holders only.", style = { outfit = "goldKey3" } },
	-- The Black Card's cardholder looks: one each month, kept for good.
	{ id = "look_card1", name = "The Cardholder's Dinner Jacket", kind = "look", source = "blackCard", line = "A Black Card month's look.", style = { outfit = "card1" } },
	{ id = "look_card2", name = "The Cardholder's Column Gown", kind = "look", source = "blackCard", line = "A Black Card month's look.", style = { outfit = "card2" } },
	{ id = "look_card3", name = "The Cardholder's Velvet Tails", kind = "look", source = "blackCard", line = "A Black Card month's look.", style = { outfit = "card3" } },
	{ id = "look_card4", name = "The Cardholder's Satin Wrap", kind = "look", source = "blackCard", line = "A Black Card month's look.", style = { outfit = "card4" } },
	{ id = "look_card5", name = "The Cardholder's Midnight Suit", kind = "look", source = "blackCard", line = "A Black Card month's look.", style = { outfit = "card5" } },
	{ id = "look_card6", name = "The Cardholder's Opera Coat", kind = "look", source = "blackCard", line = "A Black Card month's look.", style = { outfit = "card6" } },
	{ id = "look_patron", name = "The Patron's Waistcoat", kind = "look", source = "standing", gilt = 4000, standing = "Patron", line = "For Patrons of the house.", style = { outfit = "patron" } },
	{ id = "look_connoisseur", name = "The Connoisseur's Coat", kind = "look", source = "standing", gilt = 4000, standing = "Connoisseur", line = "For Connoisseurs.", style = { outfit = "connoisseur" } },
	{ id = "look_custodian", name = "The Custodian's Dress Coat", kind = "look", source = "standing", gilt = 4000, standing = "Custodian", line = "For Custodians.", style = { outfit = "custodian" } },
	{ id = "look_keeper", name = "The Keeper's Robe", kind = "look", source = "standing", gilt = 4000, standing = "Keeper of the House", line = "For the Keepers of the House.", style = { outfit = "keeper" } },

	-- Suite pieces (Suite.luau says where each goes).
	{ id = "suite_painting", name = "A Suite Painting", kind = "suite", source = "introduction", line = "A small oil of the house at night.", style = { spot = "painting", colour = rgb(40, 44, 70), accent = GOLD } },
	-- The Suite's furniture (Appendix I: Gilt 300–3,000; the Boutique 49–299). `colour` is the
	-- main fabric or wood, `accent` the trim.
	{ id = "suite_chair_velvet", name = "Oxblood Wing Chair", kind = "suite", source = "gilt", gilt = 600, line = "Deep velvet, high wings.", style = { spot = "chair", colour = rgb(92, 20, 30), accent = GOLD } },
	{ id = "suite_chair_leather", name = "Club Leather Armchair", kind = "suite", source = "gilt", gilt = 900, line = "Worn in by nobody but you.", style = { spot = "chair", colour = rgb(84, 44, 26), accent = rgb(40, 24, 16), material = "Leather" } },
	{ id = "suite_chair_emerald", name = "Emerald Club Chair", kind = "suite", source = "boutique", robux = 149, line = "Green as the old baize.", style = { spot = "chair", colour = rgb(18, 70, 46), accent = GOLD } },
	{ id = "suite_chair_goldkey", name = "The Gold Key Chair", kind = "suite", source = "goldKey", line = "Gold Key holders only.", style = { spot = "chair", colour = rgb(20, 16, 10), accent = rgb(236, 196, 98) } },
	{ id = "suite_sofa_chesterfield", name = "Chesterfield", kind = "suite", source = "gilt", gilt = 1500, line = "Buttoned leather, rolled arms.", style = { spot = "sofa", colour = rgb(70, 30, 20), accent = rgb(34, 20, 14), material = "Leather" } },
	{ id = "suite_sofa_ivory", name = "Ivory Salon Sofa", kind = "suite", source = "boutique", robux = 249, line = "Pale silk, gilt feet.", style = { spot = "sofa", colour = rgb(228, 218, 196), accent = GOLD } },
	{ id = "suite_rug_persian", name = "Night Garden Rug", kind = "suite", source = "gilt", gilt = 800, line = "Deep reds, knotted by hand.", style = { spot = "rug", colour = rgb(96, 24, 28), accent = rgb(196, 150, 80) } },
	{ id = "suite_rug_black", name = "Black Fringed Rug", kind = "suite", source = "gilt", gilt = 400, line = "Black wool, a gold border.", style = { spot = "rug", colour = rgb(14, 14, 16), accent = GOLD } },
	{ id = "suite_painting_portrait", name = "A Portrait of a Stranger", kind = "suite", source = "gilt", gilt = 1200, line = "Nobody knows who sat for it.", style = { spot = "painting", colour = rgb(70, 46, 34), accent = GOLD } },
	{ id = "suite_painting_ballroom", name = "The Last Lamp", kind = "suite", source = "boutique", robux = 149, line = "A painting of one table still lit.", style = { spot = "painting", colour = rgb(30, 22, 18), accent = GOLD } },
	{ id = "suite_rug_moon", name = "Moonlit Rug", kind = "suite", source = "boutique", robux = 149, line = "Ink blue, a silver border.", style = { spot = "rug", colour = rgb(20, 24, 48), accent = rgb(200, 206, 214) } },
	{ id = "suite_lamp_crystal", name = "Crystal Lamp", kind = "suite", source = "boutique", robux = 99, line = "Cut glass, cold white light.", style = { spot = "lamp", colour = rgb(230, 240, 255), accent = rgb(200, 206, 214) } },
	{ id = "suite_painting_skyline", name = "The City at Three", kind = "suite", source = "boutique", robux = 99, always = true, line = "Lit windows, one by one.", style = { spot = "painting", colour = rgb(16, 22, 44), accent = rgb(216, 186, 120) } },
	{ id = "suite_lamp_brass", name = "Brass Floor Lamp", kind = "suite", source = "gilt", gilt = 300, line = "A pleated silk shade.", style = { spot = "lamp", colour = rgb(236, 214, 170), accent = GOLD } },
	{ id = "suite_lamp_green", name = "Library Lamp", kind = "suite", source = "gilt", gilt = 450, line = "The green glass shade.", style = { spot = "lamp", colour = rgb(26, 90, 58), accent = GOLD } },
	{ id = "suite_bar_walnut", name = "Walnut Drinks Cabinet", kind = "suite", source = "standing", gilt = 2000, standing = "Patron", line = "For Patrons of the house.", style = { spot = "bar", colour = rgb(66, 38, 24), accent = GOLD } },
	{ id = "suite_bar_lacquer", name = "Black Lacquer Bar", kind = "suite", source = "boutique", robux = 299, line = "Mirrored inside, lit when opened.", style = { spot = "bar", colour = rgb(10, 10, 12), accent = rgb(236, 216, 166) } },
	{ id = "suite_shelf_books", name = "A Wall of Books", kind = "suite", source = "gilt", gilt = 1000, line = "Leather spines, never read.", style = { spot = "shelf", colour = rgb(40, 24, 16), accent = rgb(110, 30, 26) } },
	{ id = "suite_mirror_gilt", name = "Gilt Pier Glass", kind = "suite", source = "gilt", gilt = 1400, line = "Tall enough for the whole look.", style = { spot = "mirror", colour = rgb(200, 206, 214), accent = GOLD } },
	{ id = "suite_chaise_velvet", name = "Velvet Chaise", kind = "suite", source = "gilt", gilt = 1800, line = "For waiting while someone dresses.", style = { spot = "chaise", colour = rgb(46, 10, 18), accent = GOLD } },
	{ id = "suite_desk_partners", name = "Partners' Desk", kind = "suite", source = "standing", gilt = 3000, standing = "Connoisseur", line = "For Connoisseurs.", style = { spot = "desk", colour = rgb(52, 30, 20), accent = rgb(26, 70, 48) } },
	{ id = "suite_globe", name = "Library Globe", kind = "suite", source = "gilt", gilt = 700, line = "Old borders, brass meridian.", style = { spot = "globe", colour = rgb(196, 170, 120), accent = GOLD } },
}

-- Season collections: a look, a table style and a trail for each season, sold only in it.
for _, season in Seasons.List do
	local key = season.key
	table.insert(items, { id = "season_" .. season.id .. "_table", name = season.name .. " Felt", kind = "table", source = "season", season = season.id, line = "Only in " .. season.name .. ".", style = { felt = key:Lerp(rgb(12, 12, 14), 0.55), rim = GOLD } })
	table.insert(items, { id = "season_" .. season.id .. "_trail", name = season.name .. " Thread", kind = "trail", source = "season", season = season.id, line = "Only in " .. season.name .. ".", style = { colour = key } })
	table.insert(items, { id = "season_" .. season.id .. "_look", name = season.name .. " Look", kind = "look", source = "season", season = season.id, line = "Only in " .. season.name .. ".", style = { outfit = "season_" .. season.id } })
end

Wardrobe.all = items
local byId: { [string]: Item } = {}
for _, item in items do
	byId[item.id] = item
end

-- The Ledger's pages carry their own editions (see Ledger); they register here as they're made.
function Wardrobe.register(item: Item)
	byId[item.id] = item
end

function Wardrobe.get(id: string): Item?
	return byId[id]
end

-- The Soirée Medal for a weekend: a dated nameplate frame, earned only, never sold.
function Wardrobe.soireeMedal(key: string): Item
	local id = "soiree:" .. key .. ":medal"
	local existing = byId[id]
	if existing then
		return existing
	end
	local item: Item = {
		id = id,
		name = "The Soirée Medal · " .. key,
		kind = "nameplate",
		line = "Top 1% at the Soirée of " .. key .. ". Never sold.",
		source = "ledger",
		style = { frame = Color3.fromRGB(236, 196, 98), fill = Color3.fromRGB(40, 12, 20), line = Color3.fromRGB(236, 216, 166) },
	}
	byId[id] = item
	return item
end

-- Whether the house can actually deliver an item: looks need clothing, chimes a sound and
-- gestures an animation uploaded and named in Config.
-- The cardholder look for the month containing `time` (UTC): the six take turns.
function Wardrobe.cardholderLook(time: number?): Item?
	local d = os.date("!*t", time or os.time())
	local index = ((d.year * 12 + d.month - 1) % 6) + 1
	return Wardrobe.get("look_card" .. index)
end

-- The month a cardholder look is claimed for ("2026-10").
function Wardrobe.cardMonth(time: number?): string
	return os.date("!%Y-%m", time or os.time()) :: string
end

function Wardrobe.deliverable(item: Item): boolean
	local assets = Config.data.Assets :: any
	if item.kind == "look" then
		local look = assets.Looks and assets.Looks[item.style.outfit]
		return type(look) == "table" and ((look.shirt or 0) ~= 0 or (look.pants or 0) ~= 0 or (look.accessories or "") ~= "")
	elseif item.kind == "chime" then
		local chimes = assets.Sounds and assets.Sounds.chimes
		local own = type(chimes) == "table" and (chimes[item.style.sound] or "") ~= ""
		-- Or the house's sound sheet, which carries every chime the Boutique sells.
		local sheet = (assets.SoundSheet or "") ~= "" and SoundSheet.cues["chime_" .. tostring(item.style.sound)] ~= nil
		return own or sheet
	elseif item.kind == "gesture" then
		return ((assets.Animations and assets.Animations[item.style.animation]) or "") ~= ""
	elseif item.kind == "suite" then
		return true -- kept for the Suite
	end
	return true
end

-- "Always in the house": the Boutique's permanent shelf, never out of stock.
function Wardrobe.alwaysPool(): { Item }
	local out = {}
	for _, item in items do
		if item.source == "boutique" and item.robux and item.always and Wardrobe.deliverable(item) then
			table.insert(out, item)
		end
	end
	return out
end

-- The Boutique's pool: everything sold for Robux in the rotation that can be delivered now.
function Wardrobe.boutiquePool(): { Item }
	local out = {}
	for _, item in items do
		if item.source == "boutique" and item.robux and not item.always and Wardrobe.deliverable(item) then
			table.insert(out, item)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

function Wardrobe.giltPool(): { Item }
	local out = {}
	for _, item in items do
		if (item.source == "gilt" or item.source == "standing") and item.gilt and Wardrobe.deliverable(item) then
			table.insert(out, item)
		end
	end
	table.sort(out, function(a, b)
		return (a.gilt or 0) < (b.gilt or 0)
	end)
	return out
end

function Wardrobe.seasonPieces(seasonId: string): { Item }
	local out = {}
	for _, item in items do
		if item.source == "season" and item.season == seasonId then
			table.insert(out, item)
		end
	end
	return out
end

-- The tier product a Robux price maps to (the nearest tier at or above it).
function Wardrobe.tierFor(robux: number): number
	for _, t in Wardrobe.Tiers do
		if robux <= t then
			return t
		end
	end
	return Wardrobe.Tiers[#Wardrobe.Tiers]
end

return Wardrobe

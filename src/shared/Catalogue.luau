--!strict
-- The catalogue (Appendix A), seasonal pieces (Appendix C) and lookalike clusters (Appendix B).
-- Pieces flagged `review` are the all-ages replacements waiting on AJKR's decision (§16, §19).

local Catalogue = {}

export type Case = { id: string, name: string, subtitle: string }
export type Piece = {
	id: string,
	name: string,
	case: string,
	value: number,
	season: string?, -- set for seasonal pieces
	mythic: boolean?,
	review: string?, -- the original name this piece replaced, pending a decision
}

Catalogue.Cases = {
	{ id = "watches", name = "Watches", subtitle = "Wrist & pocket" },
	{ id = "jewelry", name = "Jewelry", subtitle = "Rings, pearls, links" },
	{ id = "money", name = "Money", subtitle = "Bars, notes, coins" },
	{ id = "keys", name = "Keys", subtitle = "Fobs, cards, tags" },
	{ id = "accessories", name = "Accessories", subtitle = "Glasses, pens, bags" },
	{ id = "collectibles", name = "Collectibles", subtitle = "Gems, cards, curios" },
} :: { Case }

local function piece(id: string, name: string, case: string, value: number, review: string?): Piece
	return { id = id, name = name, case = case, value = value, review = review }
end

Catalogue.Core = {
	piece("chronograph", "Chronograph", "watches", 120),
	piece("dressWatch", "Dress Watch", "watches", 120),
	piece("diveWatch", "Diver", "watches", 120),
	piece("moonphase", "Moonphase", "watches", 140),
	piece("pocketWatch", "Pocket Watch", "watches", 150),
	piece("diamondRing", "Solitaire Ring", "jewelry", 140),
	piece("signetRing", "Signet Ring", "jewelry", 120),
	piece("tennisBracelet", "Tennis Bracelet", "jewelry", 150),
	piece("pearlNecklace", "Pearl Strand", "jewelry", 140),
	piece("earrings", "Drop Earrings", "jewelry", 130),
	piece("cufflinks", "Cufflinks", "jewelry", 110),
	piece("goldBar", "Gold Bar", "money", 150),
	piece("platinumBar", "Platinum Bar", "money", 160),
	piece("cashStack", "Banded Notes", "money", 110),
	piece("goldCoins", "Gold Coins", "money", 120),
	piece("moneyClip", "Money Clip", "money", 110),
	piece("carKey", "Key Fob", "keys", 110),
	piece("keyCard", "Suite Key", "keys", 100),
	piece("valetKey", "Valet Tag", "keys", 110),
	piece("vaultKey", "Vault Key", "keys", 140),
	piece("sunglasses", "Sunglasses", "accessories", 110),
	piece("perfume", "Parfum", "accessories", 120),
	piece("fountainPen", "Fountain Pen", "accessories", 120),
	piece("wallet", "Billfold", "accessories", 110),
	piece("handbag", "Evening Bag", "accessories", 130),
	piece("headphones", "Headphones", "accessories", 120),
	piece("lighter", "Lighter", "accessories", 100, "Lighter (check)"),
	piece("looseDiamond", "Loose Diamond", "collectibles", 170),
	piece("emeraldGem", "Emerald", "collectibles", 160),
	piece("rubyGem", "Ruby", "collectibles", 160),
	piece("sapphireGem", "Sapphire", "collectibles", 160),
	piece("vipCard", "VIP Invitation", "collectibles", 130),
	piece("chessKing", "Gold King", "collectibles", 150),
	piece("casinoPlaque", "Commemorative Medal", "collectibles", 140, "Casino Plaque"),
	piece("objetEgg", "Objet d'Art", "collectibles", 190),
} :: { Piece }

local function seasonal(id: string, name: string, case: string, value: number, season: string, review: string?): Piece
	return { id = id, name = name, case = case, value = value, season = season, review = review }
end

Catalogue.Seasonal = {
	seasonal("crystalSkull", "Crystal Skull", "collectibles", 210, "hallows"),
	seasonal("ravenBrooch", "Raven Brooch", "jewelry", 190, "hallows"),
	seasonal("hallowsLantern", "Hallows Lantern", "accessories", 180, "hallows"),
	seasonal("champagneCoupe", "Crystal Hourglass", "accessories", 190, "toast", "Champagne Coupe"),
	seasonal("yearCoin", "Year Coin", "money", 200, "toast"),
	seasonal("heartLocket", "Heart Locket", "jewelry", 200, "rose"),
	seasonal("roseVial", "Rose Vial", "accessories", 185, "rose"),
	seasonal("cloverPin", "Clover Pin", "jewelry", 195, "emerald"),
	seasonal("luckyCoin", "Lucky Coin", "money", 195, "emerald"),
	seasonal("amberRing", "Amber Ring", "jewelry", 185, "harvest"),
	seasonal("hipFlask", "Brass Compass", "accessories", 175, "harvest", "Hip Flask"),
	seasonal("copperBar", "Copper Bar", "money", 180, "longtable"),
	seasonal("quillPen", "Quill Pen", "accessories", 185, "longtable"),
	seasonal("glassOrnament", "Glass Ornament", "collectibles", 200, "yule"),
	seasonal("wrappedBox", "Wrapped Box", "accessories", 190, "yule"),
	seasonal("iceCrystal", "Ice Crystal", "collectibles", 200, "frost"),
	seasonal("lodgeKey", "Lodge Key", "keys", 175, "frost"),
	seasonal("blossomPin", "Blossom Pin", "jewelry", 185, "bloom"),
	seasonal("gardenKey", "Garden Key", "keys", 175, "bloom"),
	seasonal("sunPendant", "Sun Pendant", "jewelry", 190, "summer"),
	seasonal("linenFan", "Linen Fan", "accessories", 175, "summer"),
} :: { Piece }

Catalogue.Mythic = {
	{ id = "noirChronometer", name = "The Noir Chronometer", case = "watches", value = 200, mythic = true },
	{ id = "blueMoonPearl", name = "Blue Moon Pearl", case = "jewelry", value = 200, mythic = true },
	{ id = "sovereignCoin", name = "The Sovereign's Coin", case = "money", value = 200, mythic = true },
	{ id = "foundersKey", name = "The Founder's Key", case = "keys", value = 200, mythic = true },
	{ id = "obsidianPen", name = "The Obsidian Pen", case = "accessories", value = 200, mythic = true },
	{ id = "blackDiamond", name = "Black Diamond", case = "collectibles", value = 200, mythic = true },
} :: { Piece }

Catalogue.Clusters = {
	{ "looseDiamond", "diamondRing", "earrings", "tennisBracelet" },
	{ "goldCoins", "casinoPlaque", "moneyClip", "vipCard" },
	{ "valetKey", "wallet", "vaultKey", "keyCard" },
	{ "pocketWatch", "chessKing", "signetRing", "objetEgg" },
	{ "platinumBar", "goldBar", "lighter", "cashStack" },
	{ "cufflinks", "earrings", "sunglasses", "perfume" },
} :: { { string } }

-- Indexes
Catalogue.byId = {} :: { [string]: Piece }
Catalogue.caseById = {} :: { [string]: Case }
Catalogue.caseIndex = {} :: { [string]: number }
local coreByCase: { [string]: { Piece } } = {}
local mythicByCase: { [string]: Piece } = {}
local seasonalBySeason: { [string]: { Piece } } = {}

for index, case in Catalogue.Cases do
	Catalogue.caseById[case.id] = case
	Catalogue.caseIndex[case.id] = index
	coreByCase[case.id] = {}
end
for _, p in Catalogue.Core do
	Catalogue.byId[p.id] = p
	table.insert(coreByCase[p.case], p)
end
for _, p in Catalogue.Seasonal do
	Catalogue.byId[p.id] = p
	local season = p.season :: string
	seasonalBySeason[season] = seasonalBySeason[season] or {}
	table.insert(seasonalBySeason[season], p)
end
for _, p in Catalogue.Mythic do
	Catalogue.byId[p.id] = p
	mythicByCase[p.case] = p
end

function Catalogue.coreForCase(caseId: string): { Piece }
	return coreByCase[caseId] or {}
end

function Catalogue.seasonalFor(seasonId: string?): { Piece }
	if seasonId == nil then
		return {}
	end
	return seasonalBySeason[seasonId] or {}
end

function Catalogue.mythicForCase(caseId: string): Piece
	return mythicByCase[caseId]
end

function Catalogue.caseOf(pieceId: string): string?
	local p = Catalogue.byId[pieceId]
	return if p then p.case else nil
end

function Catalogue.totalCollectable(): number
	return #Catalogue.Core + #Catalogue.Seasonal + #Catalogue.Mythic
end

return Catalogue

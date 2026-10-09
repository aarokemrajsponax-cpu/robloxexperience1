--!strict
-- Curios: small, silly treasures that turn up among the pieces at the tables, and the house's
-- cabinet of them. Each has a rarity (Common to Secret, and Limited for the ones that only come in
-- a season or an event), a family (the meme set, the delicacies, the relics), and a look drawn
-- from a big glyph on a coloured medallion with an accent beside it.
--
-- How they're had, all plain on each card:
--   * found at the tables (Curios.findChance per banked run; rarer ones less often). Earned by
--     playing, never bought: nothing random is ever sold.
--   * from events (Gilt Rain, the Brainrot Parade...) and achievements, named on the card.
--   * from the Cabinet for Gems, at a fixed price, the exact curio you choose.
-- Curios change no score. A found curio also pays a little Gilt (Curios.RarityGilt), so the meme
-- set is worth chasing at the tables. Most can be traded (Trading); a few can't, and say so.
--
-- The names are the house's own: original characters in the spirit of the internet's brainrot
-- memes, not copies of anyone's.

local Curios = {}

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Secret" | "Limited"
export type Family = "meme" | "delicacy" | "relic"
export type Curio = {
	id: string,
	name: string,
	line: string, -- what it is (and the joke)
	rarity: Rarity,
	family: Family,
	glyph: string, -- the big emoji on its medallion
	accent: string, -- a small emoji beside it ("" for none)
	colour: Color3, -- the medallion
	source: "tables" | "event" | "gems" | "achievement" | "season",
	gems: number?, -- its price in the Cabinet, when it's sold there
	tradeable: boolean,
	how: string, -- how it's had, in words, for its card
}

local rgb = Color3.fromRGB

Curios.Rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Limited" } :: { Rarity }
Curios.RarityRank = {} :: { [string]: number }
for i, r in Curios.Rarities do
	Curios.RarityRank[r] = i
end
Curios.RarityColour = {
	Common = rgb(190, 186, 176),
	Uncommon = rgb(120, 200, 130),
	Rare = rgb(90, 160, 240),
	Epic = rgb(180, 110, 240),
	Legendary = rgb(250, 190, 70),
	Mythic = rgb(250, 90, 110),
	Secret = rgb(40, 40, 44),
	Limited = rgb(80, 230, 220),
} :: { [string]: Color3 }
-- A little Gilt with each curio found at the tables (so the rarer finds are worth more).
Curios.RarityGilt = { Common = 10, Uncommon = 25, Rare = 60, Epic = 150, Legendary = 400, Mythic = 1000, Secret = 2500, Limited = 0 } :: { [string]: number }
-- How often each rarity turns up, among the finds at the tables (weights; Secret has its own rule).
Curios.FindWeights = { Common = 600, Uncommon = 260, Rare = 100, Epic = 32, Legendary = 7, Mythic = 1 } :: { [string]: number }

local function tables(r: Rarity): string
	return "Found at the tables (" .. r .. ")"
end

Curios.List = {
	-- The meme set: found at the tables
	{ id = "croissantino", name = "Croissantino Furioso", line = "A croissant with a temper. Do not call him a pastry.", rarity = "Common", family = "meme", glyph = "🥐", accent = "😠", colour = rgb(214, 160, 90), source = "tables", tradeable = true, how = tables("Common") },
	{ id = "baguettone", name = "Baguettone Gigante", line = "Taller than you. Still rising.", rarity = "Common", family = "meme", glyph = "🥖", accent = "💪", colour = rgb(220, 180, 110), source = "tables", tradeable = true, how = tables("Common") },
	{ id = "pigeonetto", name = "Pigeonetto Parisiano", line = "Has seen every street in Paris. Judges all of them.", rarity = "Common", family = "meme", glyph = "🐦", accent = "🎩", colour = rgb(140, 150, 170), source = "tables", tradeable = true, how = tables("Common") },
	{ id = "fromaggio", name = "Fromaggio Fantasma", line = "A cheese that haunts the cellar. Smells eternal.", rarity = "Common", family = "meme", glyph = "🧀", accent = "👻", colour = rgb(240, 210, 90), source = "tables", tradeable = true, how = tables("Common") },
	{ id = "teacupo", name = "Teacupo Tornado", line = "Spins at four o'clock sharp. Spills nothing.", rarity = "Uncommon", family = "meme", glyph = "🫖", accent = "🌪️", colour = rgb(170, 200, 210), source = "tables", tradeable = true, how = tables("Uncommon") },
	{ id = "moustachio", name = "Monsieur Moustachio", line = "Only a moustache. Somehow, a gentleman.", rarity = "Uncommon", family = "meme", glyph = "👨", accent = "🥸", colour = rgb(120, 80, 60), source = "tables", tradeable = true, how = tables("Uncommon") },
	{ id = "gelato", name = "Gelato Grandioso", line = "Three scoops, one opera voice.", rarity = "Uncommon", family = "meme", glyph = "🍨", accent = "🎤", colour = rgb(250, 190, 210), source = "tables", tradeable = true, how = tables("Uncommon") },
	{ id = "chatCouture", name = "Le Chat Couture", line = "A cat in a better coat than yours.", rarity = "Rare", family = "meme", glyph = "🐈", accent = "👗", colour = rgb(60, 50, 70), source = "tables", tradeable = true, how = tables("Rare") },
	{ id = "macaronMaestro", name = "Macaron Maestro", line = "Conducts the dessert trolley. Tempo: allegro.", rarity = "Rare", family = "meme", glyph = "🧁", accent = "🎼", colour = rgb(240, 150, 180), source = "tables", tradeable = true, how = tables("Rare") },
	{ id = "snailExpress", name = "L'Escargot Express", line = "The fastest snail in France. Still late.", rarity = "Rare", family = "meme", glyph = "🐌", accent = "🚀", colour = rgb(150, 120, 90), source = "tables", tradeable = true, how = tables("Rare") },
	{ id = "lobsterLuxe", name = "Homard de Luxe", line = "A lobster in pearls who only eats at the Ballroom.", rarity = "Epic", family = "meme", glyph = "🦞", accent = "📿", colour = rgb(220, 70, 60), source = "tables", tradeable = true, how = tables("Epic") },
	{ id = "pianoPanda", name = "Panda Pianissimo", line = "Plays the Foyer's piano at three in the morning. Softly.", rarity = "Epic", family = "meme", glyph = "🐼", accent = "🎹", colour = rgb(230, 230, 230), source = "tables", tradeable = true, how = tables("Epic") },
	{ id = "goldenGoose", name = "L'Oie d'Or", line = "A goose that lays nothing, but in gold.", rarity = "Legendary", family = "meme", glyph = "🪿", accent = "✨", colour = rgb(240, 190, 60), source = "tables", tradeable = true, how = tables("Legendary") },
	{ id = "frogKing", name = "Le Roi Grenouille", line = "Crowned at a lily pond in 1789. Never abdicated.", rarity = "Legendary", family = "meme", glyph = "🐸", accent = "👑", colour = rgb(90, 170, 80), source = "tables", tradeable = true, how = tables("Legendary") },
	{ id = "moonCheese", name = "Fromage de la Lune", line = "Cut from the moon itself, they say. It is very far from fresh.", rarity = "Mythic", family = "meme", glyph = "🌕", accent = "🧀", colour = rgb(250, 230, 150), source = "tables", tradeable = true, how = tables("Mythic") },
	-- The Secret: found only by a flawless run at the Midnight Room's table
	{ id = "midnightOwl", name = "Hibou de Minuit", line = "Only seen by those who sort without a single slip after midnight.", rarity = "Secret", family = "meme", glyph = "🦉", accent = "🌙", colour = rgb(30, 30, 50), source = "tables", tradeable = false, how = "A secret: a flawless run at the Midnight Room's table" },
	-- Delicacies: the Cabinet, for Gems (the exact one you choose)
	{ id = "truffle", name = "The Black Truffle", line = "From Périgord, in a velvet box.", rarity = "Rare", family = "delicacy", glyph = "🍄", accent = "🖤", colour = rgb(50, 40, 40), source = "gems", gems = 60, tradeable = true, how = "The Cabinet: 60 Gems" },
	{ id = "caviarTin", name = "A Tin of Caviar", line = "Gold lid, mother-of-pearl spoon.", rarity = "Epic", family = "delicacy", glyph = "🥫", accent = "🥄", colour = rgb(30, 40, 60), source = "gems", gems = 150, tradeable = true, how = "The Cabinet: 150 Gems" },
	{ id = "goldEclair", name = "The Gold Éclair", line = "Covered in gold leaf. Too beautiful to eat, so nobody has.", rarity = "Legendary", family = "delicacy", glyph = "🥖", accent = "✨", colour = rgb(230, 180, 80), source = "gems", gems = 400, tradeable = true, how = "The Cabinet: 400 Gems" },
	{ id = "croquembouche", name = "The Croquembouche", line = "A tower of choux, spun sugar and a sparkler on top.", rarity = "Mythic", family = "delicacy", glyph = "🎂", accent = "🎆", colour = rgb(240, 200, 140), source = "gems", gems = 900, tradeable = true, how = "The Cabinet: 900 Gems" },
	-- Relics: events and achievements
	{ id = "rainCoin", name = "A Coin from the Gold Rain", line = "Caught in the air during a Gilt Rain.", rarity = "Uncommon", family = "relic", glyph = "🪙", accent = "🌧️", colour = rgb(220, 180, 80), source = "event", tradeable = true, how = "Gilt Rain events" },
	{ id = "paradeBalloon", name = "A Parade Balloon", line = "From the Brainrot Parade. Still floating.", rarity = "Rare", family = "relic", glyph = "🎈", accent = "🥐", colour = rgb(240, 90, 110), source = "event", tradeable = true, how = "The Brainrot Parade" },
	{ id = "discoBall", name = "The Disco Ball", line = "From the night the Ballroom became a disco.", rarity = "Epic", family = "relic", glyph = "🪩", accent = "🕺", colour = rgb(200, 200, 220), source = "event", tradeable = true, how = "Ballroom Disco Night" },
	{ id = "firstKey", name = "The First Key", line = "For a guest's first hundred rounds.", rarity = "Rare", family = "relic", glyph = "🗝️", accent = "", colour = rgb(170, 130, 60), source = "achievement", tradeable = false, how = "Achievement: clear 100 rounds" },
	{ id = "hallmark", name = "The House Hallmark", line = "For a thousand pieces put away correctly.", rarity = "Epic", family = "relic", glyph = "⚜️", accent = "", colour = rgb(200, 160, 80), source = "achievement", tradeable = false, how = "Achievement: 1,000 correct filings" },
	-- The Cabinet's newer pieces, for Gems (the exact one you choose).
	{ id = "saffronJar", name = "A Jar of Saffron", line = "Worth more than its weight in gold. Smells like sunshine.", rarity = "Rare", family = "delicacy", glyph = "🍯", accent = "🌼", colour = rgb(220, 120, 40), source = "gems", gems = 60, tradeable = true, how = "The Cabinet: 60 Gems" },
	{ id = "emeraldTeacup", name = "The Emerald Teacup", line = "Carved from one stone. The tea tastes green.", rarity = "Rare", family = "delicacy", glyph = "🍵", accent = "💚", colour = rgb(40, 140, 90), source = "gems", gems = 80, tradeable = true, how = "The Cabinet: 80 Gems" },
	{ id = "goldMacarons", name = "A Box of Gold Macarons", line = "Six of them, gilded, in a box that clicks shut.", rarity = "Epic", family = "delicacy", glyph = "🍪", accent = "✨", colour = rgb(240, 200, 110), source = "gems", gems = 180, tradeable = true, how = "The Cabinet: 180 Gems" },
	{ id = "crystalSwan", name = "The Crystal Swan", line = "Spun glass on a mirror lake. Don't breathe near it.", rarity = "Epic", family = "relic", glyph = "🦢", accent = "💎", colour = rgb(190, 220, 240), source = "gems", gems = 220, tradeable = true, how = "The Cabinet: 220 Gems" },
	{ id = "goldenPeacock", name = "The Golden Peacock", line = "It struts. It shines. It does nothing else.", rarity = "Legendary", family = "relic", glyph = "🦚", accent = "🪙", colour = rgb(240, 196, 80), source = "gems", gems = 450, tradeable = true, how = "The Cabinet: 450 Gems" },
	{ id = "jewelledEgg", name = "The Jewelled Egg", line = "Enamel, pearls and a tiny clockwork bird inside.", rarity = "Mythic", family = "relic", glyph = "🥚", accent = "💎", colour = rgb(170, 60, 120), source = "gems", gems = 1000, tradeable = true, how = "The Cabinet: 1,000 Gems" },
	-- The holidays (the owner's hunts, and the house's own on the real day): one for finding any,
	-- one for the golden prize.
	{ id = "jackOLantern", name = "The Jack-o'-Lantern", line = "Carved on All Hallows' night. Still flickering.", rarity = "Rare", family = "relic", glyph = "🎃", accent = "🕯️", colour = rgb(230, 120, 30), source = "event", tradeable = true, how = "The All Hallows' Hunt" },
	{ id = "goldenPumpkin", name = "The Golden Pumpkin", line = "One in the whole house, and you found it.", rarity = "Legendary", family = "relic", glyph = "🎃", accent = "👑", colour = rgb(240, 190, 60), source = "event", tradeable = true, how = "The All Hallows' Hunt: the golden one" },
	{ id = "goldenWishbone", name = "The Golden Wishbone", line = "From the Turkey Trot. Make a wish.", rarity = "Rare", family = "relic", glyph = "🦃", accent = "✨", colour = rgb(170, 110, 60), source = "event", tradeable = true, how = "The Turkey Trot" },
	{ id = "goldenTurkey", name = "The Golden Turkey", line = "The fastest bird in the house. You caught it.", rarity = "Legendary", family = "relic", glyph = "🦃", accent = "👑", colour = rgb(240, 190, 60), source = "event", tradeable = true, how = "The Turkey Trot: the golden one" },
	{ id = "housePresent", name = "A Present from the House", line = "From the Gift Drop. The ribbon is real silk.", rarity = "Rare", family = "relic", glyph = "🎁", accent = "❄️", colour = rgb(190, 40, 50), source = "event", tradeable = true, how = "The Gift Drop" },
	{ id = "goldenBell", name = "The Golden Bell", line = "It rang when you found it. Everyone heard.", rarity = "Legendary", family = "relic", glyph = "🔔", accent = "✨", colour = rgb(240, 190, 60), source = "event", tradeable = true, how = "The Gift Drop: the golden one" },
	{ id = "newYearSparkler", name = "The New Year Sparkler", line = "Lit at midnight, at the house. Still fizzing.", rarity = "Epic", family = "relic", glyph = "🎇", accent = "🎉", colour = rgb(60, 50, 120), source = "event", tradeable = true, how = "The New Year Countdown" },
	{ id = "redRose", name = "A Red Rose", line = "Left in a love letter. Nobody signed it.", rarity = "Rare", family = "relic", glyph = "🌹", accent = "💌", colour = rgb(200, 30, 60), source = "event", tradeable = true, how = "Sweethearts" },
	{ id = "heartOfGold", name = "The Heart of Gold", line = "The one golden letter in the house. It was for you.", rarity = "Legendary", family = "relic", glyph = "💛", accent = "💘", colour = rgb(240, 190, 60), source = "event", tradeable = true, how = "Sweethearts: the golden one" },
	{ id = "fourLeafClover", name = "A Four-Leaf Clover", line = "Pressed in the house's guest book. Very lucky.", rarity = "Rare", family = "relic", glyph = "🍀", accent = "✨", colour = rgb(40, 160, 80), source = "event", tradeable = true, how = "The Lucky Clover" },
	{ id = "potOfGold", name = "The Pot of Gold", line = "At the end of the rainbow, exactly where they said.", rarity = "Legendary", family = "relic", glyph = "🪙", accent = "🌈", colour = rgb(240, 190, 60), source = "event", tradeable = true, how = "The Lucky Clover: the pot at the rainbow's end" },
	{ id = "paintedEgg", name = "A Painted Egg", line = "Hand-painted, from the Egg Hunt.", rarity = "Rare", family = "relic", glyph = "🥚", accent = "🌷", colour = rgb(170, 200, 240), source = "event", tradeable = true, how = "The Egg Hunt" },
	{ id = "goldenEgg", name = "The Golden Egg", line = "Hidden best of all. Found by you.", rarity = "Legendary", family = "relic", glyph = "🥚", accent = "👑", colour = rgb(240, 190, 60), source = "event", tradeable = true, how = "The Egg Hunt: the golden one" },
	-- The owner's own.
	{ id = "ownerToken", name = "The Owner's Token", line = "Handed out by the owner, in person, to everyone in the house.", rarity = "Epic", family = "relic", glyph = "👑", accent = "🪙", colour = rgb(30, 24, 14), source = "event", tradeable = false, how = "From the owner (once a day, when they hand them out)" },
	{ id = "abuseMedal", name = "The Mega Abuse Medal", line = "You were there for Mega Abuse. Nobody believes you.", rarity = "Epic", family = "relic", glyph = "🏅", accent = "💥", colour = rgb(120, 30, 160), source = "event", tradeable = false, how = "Be in the house when the owner starts Mega Abuse" },
	-- Limited: this season only
	{ id = "autumnLeaf", name = "The Gilded Leaf", line = "Autumn 2026, at the house. Never again.", rarity = "Limited", family = "relic", glyph = "🍁", accent = "✨", colour = rgb(210, 110, 40), source = "season", tradeable = true, how = "Limited: any banked run in Autumn 2026" },
} :: { Curio }

-- The season a Limited curio belongs to (only found while that season is on).
Curios.LimitedSeason = { autumnLeaf = "2026-autumn" } :: { [string]: string }

-- Terms in order (Rating.term's ids, "2026-autumn"): spring, summer, autumn, winter in a year.
local TERM_ORDER = { spring = 0, summer = 1, autumn = 2, winter = 3 }

function Curios.termIndex(termId: string): number?
	local y, s = string.match(termId, "^(%d+)%-(%a+)$")
	local n = tonumber(y)
	local o = if s then TERM_ORDER[s] else nil
	return if n and o then n * 4 + o else nil
end

-- A Limited curio for every season ahead, one a Term, so the house's seasons never run out: each
-- found only while its own season is on, with its year on it, and never again after.
local SEASONAL = {
	winter = { name = "The Frost Star", glyph = "❄️", accent = "✨", colour = rgb(170, 206, 240), line = "Winter %s at the house: snow on the glass. Never again.", season = "Winter" },
	spring = { name = "The Spring Blossom", glyph = "🌸", accent = "✨", colour = rgb(242, 168, 200), line = "Spring %s at the house: the windows open again. Never again.", season = "Spring" },
	summer = { name = "The Summer Sun", glyph = "☀️", accent = "✨", colour = rgb(250, 200, 90), line = "Summer %s at the house: warm nights on the terrace. Never again.", season = "Summer" },
	autumn = { name = "The Harvest Moon", glyph = "🌕", accent = "🍂", colour = rgb(214, 130, 50), line = "Autumn %s at the house: amber evenings. Never again.", season = "Autumn" },
}
local first = Curios.termIndex("2026-autumn") :: number
for year = 2026, 2031 do
	for _, s in { "spring", "summer", "autumn", "winter" } do
		local term = tostring(year) .. "-" .. s
		if (Curios.termIndex(term) :: number) > first then
			local d = SEASONAL[s]
			local id = "season" .. tostring(year) .. s
			-- (Winter runs from December into the next year: "Winter 2026–27".)
			local label = if s == "winter" then string.format("%d–%02d", year, (year + 1) % 100) else tostring(year)
			table.insert(Curios.List, {
				id = id,
				name = d.name .. " · " .. d.season .. " " .. label,
				line = string.format(d.line, label),
				rarity = "Limited",
				family = "relic",
				glyph = d.glyph,
				accent = d.accent,
				colour = d.colour,
				source = "season",
				tradeable = true,
				how = "Limited: any banked run in " .. d.season .. " " .. label,
			} :: Curio)
			Curios.LimitedSeason[id] = term
		end
	end
end

-- Whether a curio is shown in the Collection's book yet: a Limited one once its season has come.
function Curios.shown(id: string, termId: string): boolean
	local season = Curios.LimitedSeason[id]
	if not season then
		return true
	end
	local a, b = Curios.termIndex(season), Curios.termIndex(termId)
	return a == nil or b == nil or a <= b
end

Curios.byId = {} :: { [string]: Curio }
for _, c in Curios.List do
	Curios.byId[c.id] = c
end


-- The curios that can turn up at the tables, by rarity.
local byRarity: { [string]: { Curio } } = {}
for _, c in Curios.List do
	if c.source == "tables" and c.rarity ~= "Secret" then
		byRarity[c.rarity] = byRarity[c.rarity] or {}
		table.insert(byRarity[c.rarity], c)
	end
end

-- Picks a find at the tables from two numbers in [0, 1) (the server rolls them): the rarity by
-- FindWeights, then one curio of it.
function Curios.pick(a: number, b: number): Curio
	local total = 0
	for _, w in Curios.FindWeights do
		total += w
	end
	local x = a * total
	local chosen: string = "Common"
	for _, r in Curios.Rarities do
		local w = Curios.FindWeights[r]
		if w then
			if x < w then
				chosen = r
				break
			end
			x -= w
		end
	end
	local pool = byRarity[chosen] or byRarity.Common
	return pool[math.clamp(math.floor(b * #pool) + 1, 1, #pool)]
end

-- The chance (0..1) of a banked run finding a curio: more rounds, better odds.
function Curios.findChance(rounds: number, accuracy: number): number
	if rounds <= 0 then
		return 0
	end
	return math.clamp(0.25 + 0.12 * rounds + 0.25 * accuracy, 0, 0.9)
end

-- Sorts a list of curio ids: by rarity (rarest first), then name.
-- Bought with Robux (through Gems, in the Cabinet): trading it is "paid item trading", which
-- Roblox allows only for some guests (server/Policy).
function Curios.isPaid(c: Curio): boolean
	return c.source == "gems"
end

function Curios.compare(a: string, b: string): boolean
	local ca, cb = Curios.byId[a], Curios.byId[b]
	if not ca or not cb then
		return a < b
	end
	local ra, rb = Curios.RarityRank[ca.rarity], Curios.RarityRank[cb.rarity]
	if ra ~= rb then
		return ra > rb
	end
	return ca.name < cb.name
end

return Curios

--!strict
-- The Gem Shop: what Gems buy, each at one fixed price, the exact thing you choose (never random).
-- Gems only: none of these can be had any other way.
--   Companions: a little friend floating at your shoulder, that everyone in the house sees.
--   Table felts: the leather of your sorting table, in colours no Boutique sells, drifting.
--   Guide trails: the thread of light to the right case, in a colour of its own.
--   Auras: a glow round you that everyone in the house sees.
--   Titles: a line above your name on your nameplate.
--   Surges: more Gilt, or more XP, for half an hour from when you buy it (buying another adds
--           half an hour more).
--   Gilt: Gems changed for Gilt at a set rate, better for more.
--   Curios: the Cabinet's pieces (Shared/Curios, source "gems").
-- Wearable things (companions, felts, trails, auras, titles) are kept for good and worn one of a
-- kind at a time. All style or convenience, never a score: nothing here wins a game.
--
-- Prices sit at 250, 500, 1,000 and 2,500 Gems, so each Gem pack buys something whole: a Pouch
-- (250) a companion or a trail, a Case (1,100) a thousand-Gem piece, a Trunk (3,000) the finest.
-- Gems are also earned by playing (levels, badges), more slowly.

local GemShop = {}

export type Kind = "companion" | "felt" | "trail" | "aura" | "title" | "boost" | "exchange"
export type Item = {
	id: string,
	name: string,
	kind: Kind,
	gems: number,
	line: string,
	glyph: string,
	style: { [string]: any },
}

local rgb = Color3.fromRGB

GemShop.Kinds = { "companion", "felt", "trail", "aura", "title", "boost", "exchange", "curio" }
GemShop.KindNames = { companion = "Companions", felt = "Table Felts", trail = "Guide Trails", aura = "Auras", title = "Titles", boost = "Surges", exchange = "Gilt", curio = "Curios" }
-- What's worn (one of each kind at a time), and the attribute everyone's screens read it from.
GemShop.Wearable = { companion = "Companion", felt = "GemFelt", trail = "GemTrail", aura = "Aura", title = "Title" } :: { [string]: string }

GemShop.List = {
	-- Companions: a little friend at your shoulder, bobbing as it follows you, in a glow of its own
	-- (`glow`), with sparkles (`colours`), embers (`fire`) or every colour (`rainbow`).
	{ id = "comp_fox", name = "Fox Kit", kind = "companion", gems = 250, glyph = "🦊", line = "A little fox at your shoulder, wherever you go.", style = { glyph = "🦊", glow = rgb(255, 160, 80), colours = { rgb(255, 190, 120), rgb(255, 240, 210) } } },
	{ id = "comp_owl", name = "Snow Owl", kind = "companion", gems = 250, glyph = "🦉", line = "Wise, white and very quiet.", style = { glyph = "🦉", glow = rgb(190, 220, 255), colours = { rgb(220, 236, 255), rgb(255, 255, 255) } } },
	{ id = "comp_panda", name = "Panda", kind = "companion", gems = 250, glyph = "🐼", line = "Round, soft, and always pleased to see you.", style = { glyph = "🐼", glow = rgb(230, 230, 236), colours = { rgb(255, 255, 255), rgb(160, 160, 170) } } },
	{ id = "comp_bunny", name = "Velvet Bunny", kind = "companion", gems = 250, glyph = "🐰", line = "A bunny with a pink glow and a soft hop.", style = { glyph = "🐰", glow = rgb(255, 170, 200), colours = { rgb(255, 200, 220), rgb(255, 240, 246) } } },
	{ id = "comp_swan", name = "Golden Swan", kind = "companion", gems = 500, glyph = "🦢", line = "A swan in gold light, trailing gold dust.", style = { glyph = "🦢", glow = rgb(255, 214, 110), colours = { rgb(255, 214, 110), rgb(255, 246, 210) }, rate = 14 } },
	{ id = "comp_corgi", name = "Royal Corgi", kind = "companion", gems = 500, glyph = "🐶", line = "The house's favourite, with a crown of stars.", style = { glyph = "🐶", glow = rgb(255, 200, 120), colours = { rgb(255, 230, 150), rgb(255, 255, 255) }, crown = true } },
	{ id = "comp_butterfly", name = "Moon Butterfly", kind = "companion", gems = 500, glyph = "🦋", line = "Blue wings that leave a trail of moonlight.", style = { glyph = "🦋", glow = rgb(120, 180, 255), colours = { rgb(140, 200, 255), rgb(220, 240, 255) }, rate = 14 } },
	{ id = "comp_unicorn", name = "Unicorn", kind = "companion", gems = 1000, glyph = "🦄", line = "Every colour at once, sparkling as it goes.", style = { glyph = "🦄", glow = rgb(255, 170, 240), rainbow = true, rate = 20 } },
	{ id = "comp_dragon", name = "Little Dragon", kind = "companion", gems = 1000, glyph = "🐉", line = "A small green dragon breathing small warm embers.", style = { glyph = "🐉", glow = rgb(120, 255, 150), fire = true, rate = 16 } },
	{ id = "comp_jewel", name = "The Crown Jewel", kind = "companion", gems = 2500, glyph = "💎", line = "A great diamond turning in its own light, throwing rainbows. The finest thing in the house.", style = { glyph = "💎", glow = rgb(200, 240, 255), rainbow = true, rate = 28, light = rgb(210, 236, 255), big = true } },
	-- Table felts: your sorting table's leather, corner to corner (`light` where the lamp falls,
	-- `mid`, `deep`), a tone drifting over it (`shift`), the lamp's pool (`pool`), the case rims.
	{ id = "felt_aurora", name = "Aurora Silk", kind = "felt", gems = 500, glyph = "🌌", line = "Northern lights on your table: green running into violet, drifting.", style = { light = rgb(40, 168, 136), mid = rgb(26, 70, 112), deep = rgb(18, 10, 48), shift = rgb(170, 80, 255), pool = rgb(200, 255, 230), rim = rgb(170, 255, 220) } },
	{ id = "felt_sakura", name = "Sakura", kind = "felt", gems = 500, glyph = "🌸", line = "Cherry blossom pink into deep plum.", style = { light = rgb(214, 120, 160), mid = rgb(120, 44, 84), deep = rgb(44, 12, 30), shift = rgb(255, 190, 220), pool = rgb(255, 220, 236), rim = rgb(255, 196, 220) } },
	{ id = "felt_ice", name = "Ice Palace", kind = "felt", gems = 500, glyph = "❄️", line = "Ice blue into the deep of a winter night.", style = { light = rgb(110, 180, 236), mid = rgb(30, 70, 128), deep = rgb(8, 16, 44), shift = rgb(210, 240, 255), pool = rgb(230, 246, 255), rim = rgb(220, 240, 255) } },
	{ id = "felt_gold", name = "Liquid Gold", kind = "felt", gems = 1000, glyph = "🪙", line = "Molten gold into bronze and shadow. Every piece looks expensive on it.", style = { light = rgb(226, 170, 70), mid = rgb(120, 76, 20), deep = rgb(40, 22, 6), shift = rgb(255, 230, 160), pool = rgb(255, 236, 180), rim = rgb(255, 222, 140) } },
	{ id = "felt_galaxy", name = "Galaxy Velvet", kind = "felt", gems = 1000, glyph = "🪐", line = "Violet nebula into the black of space, a blue tide over it.", style = { light = rgb(118, 76, 214), mid = rgb(40, 24, 100), deep = rgb(6, 4, 24), shift = rgb(60, 160, 255), pool = rgb(220, 210, 255), rim = rgb(200, 180, 255) } },
	{ id = "felt_inferno", name = "Obsidian Fire", kind = "felt", gems = 2500, glyph = "🔥", line = "Black glass with fire moving under it. The rarest table in the house.", style = { light = rgb(220, 96, 30), mid = rgb(80, 18, 10), deep = rgb(10, 6, 6), shift = rgb(255, 190, 70), pool = rgb(255, 200, 140), rim = rgb(255, 170, 80) } },
	-- Guide trails: the thread of light from a held piece to its case.
	{ id = "gtrail_diamond", name = "Diamond Dust", kind = "trail", gems = 250, glyph = "💠", line = "A thread of ice-white light, glittering.", style = { colour = rgb(214, 240, 255) } },
	{ id = "gtrail_phoenix", name = "Phoenix", kind = "trail", gems = 500, glyph = "🔥", line = "A thread of fire, orange into gold.", style = { colour = rgb(255, 140, 60) } },
	{ id = "gtrail_nebula", name = "Nebula", kind = "trail", gems = 500, glyph = "🌌", line = "A thread of violet starlight.", style = { colour = rgb(176, 120, 255) } },
	{ id = "gtrail_prism", name = "Prism", kind = "trail", gems = 1000, glyph = "🌈", line = "Every colour of the rainbow, turning as it runs.", style = { colour = rgb(255, 120, 200), rainbow = true } },
	-- Auras. `particle`: sparkles, smoke or fire, in these colours; `glyph`: little icons that
	-- circle you instead.
	{ id = "aura_golddust", name = "Gold Dust", kind = "aura", gems = 120, glyph = "✨", line = "A drift of gold dust, always.", style = { particle = "sparkles", colours = { rgb(255, 214, 110), rgb(255, 240, 190) }, rate = 18 } },
	{ id = "aura_rose", name = "Rose Petals", kind = "aura", gems = 150, glyph = "🌹", line = "Soft pink light, falling like petals.", style = { particle = "sparkles", colours = { rgb(255, 120, 160), rgb(255, 200, 220) }, rate = 16 } },
	{ id = "aura_emerald", name = "Emerald Sparks", kind = "aura", gems = 150, glyph = "💚", line = "Green sparks round your feet.", style = { particle = "sparkles", colours = { rgb(70, 230, 140), rgb(190, 255, 210) }, rate = 18 } },
	{ id = "aura_frost", name = "Frost", kind = "aura", gems = 180, glyph = "❄️", line = "A cold blue shimmer and a breath of mist.", style = { particle = "sparkles", colours = { rgb(170, 220, 255), rgb(240, 250, 255) }, rate = 16, mist = rgb(220, 240, 255) } },
	{ id = "aura_ember", name = "Embers", kind = "aura", gems = 180, glyph = "🔥", line = "Little embers rising off you, warm and orange.", style = { particle = "fire", colours = { rgb(255, 170, 60), rgb(255, 90, 40) }, rate = 10 } },
	{ id = "aura_starlight", name = "Starlight", kind = "aura", gems = 220, glyph = "⭐", line = "White starlight that twinkles as you move.", style = { particle = "sparkles", colours = { rgb(255, 255, 255), rgb(200, 220, 255) }, rate = 24 } },
	{ id = "aura_shadow", name = "Velvet Shadow", kind = "aura", gems = 220, glyph = "🖤", line = "Dark violet wisps curling round you.", style = { particle = "smoke", colours = { rgb(80, 40, 110), rgb(20, 10, 30) }, rate = 6 } },
	{ id = "aura_hearts", name = "Hearts", kind = "aura", gems = 160, glyph = "💖", line = "Hearts circling you, slowly.", style = { glyph = "💖", orbit = 5 } },
	{ id = "aura_clover", name = "Lucky Clovers", kind = "aura", gems = 160, glyph = "🍀", line = "Four-leaf clovers circling you.", style = { glyph = "🍀", orbit = 5 } },
	{ id = "aura_crown", name = "Crown of Stars", kind = "aura", gems = 350, glyph = "👑", line = "A ring of stars turning above your head.", style = { glyph = "⭐", orbit = 7, crown = true } },
	{ id = "aura_galaxy", name = "Galaxy", kind = "aura", gems = 400, glyph = "🌌", line = "Violet and blue starlight and a haze of nebula.", style = { particle = "sparkles", colours = { rgb(150, 90, 255), rgb(80, 160, 255) }, rate = 26, mist = rgb(120, 70, 200) } },
	{ id = "aura_rainbow", name = "Rainbow", kind = "aura", gems = 500, glyph = "🌈", line = "Every colour at once, all the time.", style = { particle = "sparkles", rainbow = true, rate = 30 } },
	-- Titles: a line above your name.
	{ id = "title_collector", name = "The Collector", kind = "title", gems = 100, glyph = "🏺", line = "For the one with every shelf full.", style = { colour = rgb(236, 216, 166) } },
	{ id = "title_nightowl", name = "Night Owl", kind = "title", gems = 100, glyph = "🦉", line = "Always here after midnight.", style = { colour = rgb(170, 190, 255) } },
	{ id = "title_highsociety", name = "High Society", kind = "title", gems = 150, glyph = "🎩", line = "Very important, very well dressed.", style = { colour = rgb(255, 230, 180) } },
	{ id = "title_goldentouch", name = "Golden Touch", kind = "title", gems = 200, glyph = "🪙", line = "Everything you touch turns to Gilt.", style = { colour = rgb(255, 210, 90) } },
	{ id = "title_brainrot", name = "Brainrot Royalty", kind = "title", gems = 200, glyph = "🗿", line = "Ruler of the memes.", style = { colour = rgb(140, 255, 140) } },
	{ id = "title_chaos", name = "Agent of Chaos", kind = "title", gems = 250, glyph = "💥", line = "Wherever Admin Abuse is, so are you.", style = { colour = rgb(255, 110, 90) } },
	{ id = "title_untouchable", name = "The Untouchable", kind = "title", gems = 250, glyph = "🛡️", line = "Flawless, every time.", style = { colour = rgb(200, 240, 255) } },
	{ id = "title_mythic", name = "Mythic Hunter", kind = "title", gems = 300, glyph = "🌟", line = "They find Mythics the way others find coins.", style = { colour = rgb(255, 120, 150) } },
	{ id = "title_main", name = "Main Character", kind = "title", gems = 300, glyph = "🎬", line = "The story is about you, obviously.", style = { colour = rgb(255, 180, 240) } },
	{ id = "title_legend", name = "Certified Legend", kind = "title", gems = 400, glyph = "🏆", line = "The house has checked. It's official.", style = { colour = rgb(255, 200, 60) } },
	-- Surges: for half an hour from the moment you buy one.
	{ id = "boost_gilt", name = "Gilt Surge", kind = "boost", gems = 60, glyph = "🪙", line = "Half again as much Gilt from everything you play, for 30 minutes.", style = { boost = "gilt", seconds = 1800 } },
	{ id = "boost_xp", name = "XP Surge", kind = "boost", gems = 60, glyph = "⭐", line = "Double XP from everything you play, for 30 minutes.", style = { boost = "xp", seconds = 1800 } },
	-- Gilt for Gems, at a set rate (better for more).
	{ id = "swap_small", name = "A Purse of Gilt", kind = "exchange", gems = 25, glyph = "👛", line = "1,000 Gilt for 25 Gems.", style = { gilt = 1000 } },
	{ id = "swap_medium", name = "A Bag of Gilt", kind = "exchange", gems = 100, glyph = "💰", line = "4,500 Gilt for 100 Gems.", style = { gilt = 4500 } },
	{ id = "swap_large", name = "A Chest of Gilt", kind = "exchange", gems = 250, glyph = "🧰", line = "12,500 Gilt for 250 Gems.", style = { gilt = 12500 } },
} :: { Item }

GemShop.byId = {} :: { [string]: Item }
for _, item in GemShop.List do
	GemShop.byId[item.id] = item
end

GemShop.SURGE_CAP = 3 * 3600 -- a Surge never runs more than three hours ahead

return GemShop

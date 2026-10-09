--!strict
-- The Gem Shop: what Gems buy, each at one fixed price, the exact thing you choose (never random).
--   Auras: a glow round you that everyone in the house sees (wear one at a time).
--   Titles: a line above your name on your nameplate.
--   Surges: more Gilt, or more XP, for half an hour from when you buy it (buying another adds
--           half an hour more).
--   Gilt: Gems changed for Gilt at a set rate, better for more.
--   Curios: the Cabinet's pieces (Shared/Curios, source "gems").
-- All style or convenience, never a score: nothing here wins a game.

local GemShop = {}

export type Kind = "aura" | "title" | "boost" | "exchange"
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

GemShop.Kinds = { "aura", "title", "boost", "exchange", "curio" }
GemShop.KindNames = { aura = "Auras", title = "Titles", boost = "Surges", exchange = "Gilt", curio = "Curios" }

GemShop.List = {
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

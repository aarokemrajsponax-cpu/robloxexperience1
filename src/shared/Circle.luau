--!strict
-- Circles (§9.7, Appendix H7): the words a name is chosen from (never typed), the crests, and the
-- week's arithmetic. Pure, so the rule tests can check it.

local Config = require(script.Parent.Config)

local Circle = {}

Circle.Adjectives = {
	"Velvet", "Quiet", "Gilded", "Midnight", "Silver", "Scarlet", "Hidden", "Last", "Crimson", "Ivory",
	"Emerald", "Sleepless", "Golden", "Smoky", "Lucky", "Distant", "Violet", "Patient", "Nimble", "Black",
}
Circle.Nouns = {
	"Ravens", "Keys", "Foxes", "Lanterns", "Owls", "Aces", "Moths", "Hands", "Wolves", "Lamps",
	"Swans", "Magpies", "Cards", "Stags", "Roses", "Ciphers", "Hours", "Spires", "Herons", "Dials",
}
-- Twelve emblems (drawn as glyphs) and eight colours: ninety-six crests, each held by one Circle.
Circle.Emblems = { "♠", "♣", "♥", "♦", "★", "☾", "✦", "♛", "♜", "♞", "⚓", "❦" }
Circle.EmblemNames = { "Spade", "Club", "Heart", "Diamond", "Star", "Moon", "Spark", "Crown", "Tower", "Knight", "Anchor", "Leaf" }
Circle.Colours = {
	Color3.fromRGB(198, 160, 82), -- gold
	Color3.fromRGB(150, 22, 32), -- oxblood
	Color3.fromRGB(26, 90, 58), -- emerald
	Color3.fromRGB(40, 56, 110), -- midnight
	Color3.fromRGB(200, 204, 212), -- silver
	Color3.fromRGB(110, 40, 120), -- violet
	Color3.fromRGB(226, 216, 196), -- ivory
	Color3.fromRGB(184, 104, 58), -- copper
}
Circle.ColourNames = { "Gold", "Oxblood", "Emerald", "Midnight", "Silver", "Violet", "Ivory", "Copper" }

export type Choice = { adjective: number, noun: number, emblem: number, colour: number }

function Circle.valid(c: any): boolean
	if type(c) ~= "table" then
		return false
	end
	local function index(v: any, n: number): boolean
		return type(v) == "number" and v == math.floor(v) and v >= 1 and v <= n
	end
	return index(c.adjective, #Circle.Adjectives) and index(c.noun, #Circle.Nouns) and index(c.emblem, #Circle.Emblems) and index(c.colour, #Circle.Colours)
end

function Circle.name(c: Choice): string
	return "The " .. Circle.Adjectives[c.adjective] .. " " .. Circle.Nouns[c.noun]
end

-- The key that makes a crest the one Circle's.
function Circle.crestKey(c: Choice): string
	return string.format("crest:%d:%d", c.emblem, c.colour)
end

-- A member's points for something they did this week.
-- Nightly: 100 minus the percentile (top 5% = 95). Library: 10 a win. Ballroom: its points (H5).
function Circle.points(source: string, detail: number?): number
	local c = Config.data.Circles
	if source == "nightly" then
		return math.max(0, 100 - math.clamp(detail or 100, 1, 100))
	elseif source == "library" then
		return c.libraryWin
	elseif source == "ballroom" then
		return math.max(0, detail or 0)
	end
	return 0
end

-- A Circle's week: the sum of its five best members' points this week.
function Circle.weekScore(points: { number }): number
	local sorted = table.clone(points)
	table.sort(sorted, function(a, b)
		return a > b
	end)
	local total = 0
	for i = 1, math.min(Config.data.Circles.best, #sorted) do
		total += sorted[i]
	end
	return total
end

return Circle

--!strict
-- The brainrots: the meme set of curios (Curios, family "meme") as characters with powers of their
-- own. Every guest has a squad of them (three places, three more in the Brainrot Penthouse):
--   * each one in the squad earns Gilt every hour, into a tip jar that holds eight hours of it,
--     even while you're away (collect it when you're back);
--   * the one you choose walks beside you through the house, as big as its rarity, and adds its
--     bonus to the Gilt of every run you bank;
--   * more copies of the same one give it stars (★1 to ★5), each star half again as much;
--   * found at the tables, one can turn up Gold, Diamond or Rainbow: two, three or five times
--     as much. Earned by playing only; nothing random is ever sold.
-- None of it touches a score: the boards stay fair.

local Curios = require(script.Parent.Curios)

local Brainrots = {}

export type Mutation = "gold" | "diamond" | "rainbow"
export type MutationInfo = { name: string, mult: number, chance: number, colour: Color3, rank: number, bonus: number }

local rgb = Color3.fromRGB

Brainrots.SLOTS = 3 -- places in everyone's squad
Brainrots.WING_SLOTS = 3 -- more with the Brainrot Penthouse
Brainrots.JAR_HOURS = 8 -- the tip jar holds this many hours of what the squad earns

-- Gilt an hour for one at ★1, by rarity.
Brainrots.Rate = {
	Common = 40,
	Uncommon = 90,
	Rare = 200,
	Epic = 450,
	Legendary = 1000,
	Mythic = 2200,
	Secret = 4000,
} :: { [string]: number }

-- The walking one's bonus on every banked run's Gilt, by rarity (and +2% a star above the first).
Brainrots.RunBonus = {
	Common = 0.05,
	Uncommon = 0.08,
	Rare = 0.12,
	Epic = 0.18,
	Legendary = 0.25,
	Mythic = 0.4,
	Secret = 0.6,
} :: { [string]: number }

-- How tall it stands when it walks beside you (studs), by rarity.
Brainrots.Height = {
	Common = 3.4,
	Uncommon = 4,
	Rare = 4.8,
	Epic = 5.8,
	Legendary = 7,
	Mythic = 8.4,
	Secret = 9.5,
} :: { [string]: number }

-- Copies held for each star: one for ★1, three for ★2, and so on.
Brainrots.StarAt = { 1, 3, 6, 12, 25 }
Brainrots.STAR_FACTOR = 1.5
Brainrots.STAR_BONUS = 0.02

Brainrots.Mutations = {
	gold = { name = "Gold", mult = 2, chance = 1 / 12, colour = rgb(255, 204, 70), rank = 1, bonus = 0.05 },
	diamond = { name = "Diamond", mult = 3, chance = 1 / 50, colour = rgb(150, 232, 255), rank = 2, bonus = 0.1 },
	rainbow = { name = "Rainbow", mult = 5, chance = 1 / 200, colour = rgb(255, 120, 210), rank = 3, bonus = 0.2 },
} :: { [string]: MutationInfo }
-- Rarest first (the roll checks them in this order).
Brainrots.MutationOrder = { "rainbow", "diamond", "gold" } :: { string }

-- Whether a curio is a brainrot (the meme set).
function Brainrots.is(id: string): boolean
	local c = Curios.byId[id]
	return c ~= nil and c.family == "meme"
end

-- Every brainrot there is, rarest first.
function Brainrots.all(): { string }
	local ids = {}
	for _, c in Curios.List do
		if c.family == "meme" then
			table.insert(ids, c.id)
		end
	end
	table.sort(ids, Curios.compare)
	return ids
end

-- Stars for `count` copies held (0 if none).
function Brainrots.stars(count: number): number
	local s = 0
	for i, need in Brainrots.StarAt do
		if count >= need then
			s = i
		end
	end
	return s
end

-- Copies needed for the next star, or nil at ★5.
function Brainrots.nextStar(count: number): number?
	for _, need in Brainrots.StarAt do
		if count < need then
			return need
		end
	end
	return nil
end

local function mutMult(mut: string?): number
	local m = if mut then Brainrots.Mutations[mut] else nil
	return if m then m.mult else 1
end

-- Gilt an hour from one in the squad with `count` copies held (and its best mutation).
function Brainrots.rate(id: string, count: number, mut: string?): number
	local c = Curios.byId[id]
	if not c or c.family ~= "meme" or count <= 0 then
		return 0
	end
	local base = Brainrots.Rate[c.rarity] or 0
	local stars = math.max(1, Brainrots.stars(count))
	return math.floor(base * Brainrots.STAR_FACTOR ^ (stars - 1) * mutMult(mut) + 0.5)
end

-- The walking one's bonus on a banked run's Gilt (0.25 is +25%).
function Brainrots.runBonus(id: string, count: number, mut: string?): number
	local c = Curios.byId[id]
	if not c or c.family ~= "meme" or count <= 0 then
		return 0
	end
	local stars = math.max(1, Brainrots.stars(count))
	local m = if mut then Brainrots.Mutations[mut] else nil
	return (Brainrots.RunBonus[c.rarity] or 0) + Brainrots.STAR_BONUS * (stars - 1) + (if m then m.bonus else 0)
end

-- A find's mutation from a number in [0, 1) (the server rolls it), or nil for a plain one.
function Brainrots.roll(x: number): string?
	local edge = 0
	for _, key in Brainrots.MutationOrder do
		edge += Brainrots.Mutations[key].chance
		if x < edge then
			return key
		end
	end
	return nil
end

-- Whether mutation `a` is better than `b` (nil is plain).
function Brainrots.better(a: string?, b: string?): boolean
	local ra = if a and Brainrots.Mutations[a] then Brainrots.Mutations[a].rank else 0
	local rb = if b and Brainrots.Mutations[b] then Brainrots.Mutations[b].rank else 0
	return ra > rb
end

-- The jar's Gilt at `now`: what was in it at `at`, plus `rate` an hour since, up to its size.
-- (While a Meme Frenzy lasts, until `boostUntil`, the squad earns `boostMult` times as much.)
function Brainrots.jar(held: number, rate: number, at: number, now: number, boostUntil: number?, boostMult: number?): number
	local cap = math.max(held, rate * Brainrots.JAR_HOURS)
	local gained = 0
	local from = at
	if boostUntil and boostMult and boostUntil > from then
		local stop = math.min(now, boostUntil)
		gained += rate * boostMult * math.max(0, stop - from) / 3600
		from = math.max(from, stop)
	end
	gained += rate * math.max(0, now - from) / 3600
	return math.min(cap, held + gained)
end

-- The Meme Frenzy: after a Meme Takeover plays, the squad earns this many times as much for this long.
Brainrots.FRENZY_MULT = 2
Brainrots.FRENZY_SECONDS = 15 * 60

-- 1234 -> "1.2K", 2500000 -> "2.5M".
function Brainrots.short(n: number): string
	if n >= 1e6 then
		return (string.gsub(string.format("%.1fM", n / 1e6), "%.0M", "M"))
	elseif n >= 1e4 then
		return string.format("%dK", math.floor(n / 1e3))
	elseif n >= 1e3 then
		return (string.gsub(string.format("%.1fK", n / 1e3), "%.0K", "K"))
	end
	return tostring(math.floor(n))
end

-- "★★★☆☆" for `stars` of five.
function Brainrots.starText(stars: number): string
	return string.rep("★", stars) .. string.rep("☆", 5 - stars)
end

return Brainrots

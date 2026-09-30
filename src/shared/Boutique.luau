--!strict
-- The rotating Boutique (§12): six pieces a day and two featured each week, chosen from the
-- Wardrobe by the date so every server shows the same shelves. Days turn at 00:00 UTC; weeks on
-- Monday.

local Seed = require(script.Parent.Seed)
local Wardrobe = require(script.Parent.Wardrobe)

local Boutique = {}

Boutique.dailyCount = 6
Boutique.featuredCount = 2

local function day(time: number?): number
	return math.floor((time or os.time()) / 86400)
end

local function week(time: number?): number
	return math.floor((day(time) + 3) / 7)
end

-- `count` distinct items from the pool, the same for everyone on the same key.
local function pick(pool: { Wardrobe.Item }, key: string, count: number, avoid: { [string]: boolean }?): { Wardrobe.Item }
	local rng = Random.new(Seed.hash(key))
	local candidates = {}
	for _, item in pool do
		if not (avoid and avoid[item.id]) then
			table.insert(candidates, item)
		end
	end
	local out = {}
	while #out < count and #candidates > 0 do
		local i = rng:NextInteger(1, #candidates)
		table.insert(out, table.remove(candidates, i) :: Wardrobe.Item)
	end
	return out
end

-- The week's two featured pieces.
function Boutique.featured(time: number?): { Wardrobe.Item }
	return pick(Wardrobe.boutiquePool(), "boutique-week-" .. week(time), Boutique.featuredCount)
end

-- Today's six (never repeating this week's featured pair).
function Boutique.today(time: number?): { Wardrobe.Item }
	local avoid: { [string]: boolean } = {}
	for _, item in Boutique.featured(time) do
		avoid[item.id] = true
	end
	return pick(Wardrobe.boutiquePool(), "boutique-day-" .. day(time), Boutique.dailyCount, avoid)
end

-- Whether an item is on the shelves right now (today, featured, or its season's collection).
function Boutique.onSale(itemId: string, seasonId: string, time: number?): boolean
	for _, item in Boutique.today(time) do
		if item.id == itemId then
			return true
		end
	end
	for _, item in Boutique.featured(time) do
		if item.id == itemId then
			return true
		end
	end
	local item = Wardrobe.get(itemId)
	return item ~= nil and item.source == "season" and item.season == seasonId and Wardrobe.deliverable(item)
end

return Boutique

--!strict
-- The rotating Boutique (§12): six pieces a day and two featured each week, chosen from the
-- Wardrobe by the date so every server shows the same shelves. Days turn at 00:00 UTC; weeks on
-- Monday.

local Curios = require(script.Parent.Curios)
local Fortune = require(script.Parent.Fortune)
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

-- The permanent shelf: always there, the same in every server.
function Boutique.always(): { Wardrobe.Item }
	return Wardrobe.alwaysPool()
end

-- Whether an item is on the shelves right now (always, today, featured, or its season's).
function Boutique.onSale(itemId: string, seasonId: string, time: number?): boolean
	-- The Suite's pieces are always to be had, at the Suite's bell.
	local piece = Wardrobe.get(itemId)
	-- (Build 96) The sorting tables' pieces aren't sold any more (kept by whoever has them).
	if piece and Wardrobe.retired(piece) then
		return false
	end
	if piece and piece.kind == "suite" then
		return Wardrobe.deliverable(piece)
	end
	for _, item in Boutique.always() do
		if item.id == itemId then
			return true
		end
	end
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

-- Seconds until the shelves turn (00:00 UTC): the real time, the same in every server.
function Boutique.secondsToTurn(time: number?): number
	local t = time or os.time()
	return 86400 - (t % 86400)
end

-- (Build 96) The Brainrot Market: four brainrots a day (five from Build 105) for Gilt, chosen by the date so every
-- server shows the same four (one Common or Uncommon, one Rare, one Epic, one Legendary). Each is
-- the exact one shown, never a random pick, at a fixed price by its rarity; a guest can buy each
-- of the day's four once a day. Secrets are never sold: they're found.
-- (Build 105) Five a day: a Mythic joins them. The price ladder climbs steeply by rarity, at the
-- house's Gilt scale (shared/Fortune), so at the payouts that ship (x10) it reads 15,000 for a
-- Common, 35,000 Uncommon, 80,000 Rare, 160,000 Epic, 350,000 Legendary and 900,000 for a Mythic.
-- The rarest of all (Secrets, the Auction's numbered limiteds) are never on the Market.
Boutique.MarketBands = { { "Common", "Uncommon" }, { "Rare" }, { "Epic" }, { "Legendary" }, { "Mythic" } }
Boutique.MarketPrice = { Common = 1500, Uncommon = 3500, Rare = 8000, Epic = 16000, Legendary = 35000, Mythic = 90000 } :: { [string]: number }

-- What one of `rarity` costs at the Market today, in Gilt (at the house's scale).
function Boutique.marketGilt(rarity: string): number
	return Fortune.scaled(Boutique.MarketPrice[rarity] or 0)
end

export type MarketPick = { id: string, rarity: string, gilt: number }

-- The day's four.
function Boutique.market(time: number?): { MarketPick }
	local rng = Random.new(Seed.hash("brainrot-market-" .. day(time)))
	local out: { MarketPick } = {}
	for _, band in Boutique.MarketBands do
		local pool = {}
		for _, c in Curios.List do
			-- (Only the meme set's own, found in play and tradeable: no event or season pieces.)
			if c.family == "meme" and c.tradeable == true and (c.source == "tables" or c.source == "attraction") and table.find(band, c.rarity) then
				table.insert(pool, c)
			end
		end
		table.sort(pool, function(a, b)
			return a.id < b.id
		end)
		if #pool > 0 then
			local c = pool[rng:NextInteger(1, #pool)]
			table.insert(out, { id = c.id, rarity = c.rarity :: string, gilt = Boutique.marketGilt(c.rarity :: string) })
		end
	end
	return out
end

-- The Gilt price of `id` at the Market today, or nil if it isn't one of today's four.
function Boutique.marketPrice(id: string, time: number?): number?
	for _, m in Boutique.market(time) do
		if m.id == id then
			return m.gilt
		end
	end
	return nil
end

-- The day number the shelves are on (for once-a-day limits).
Boutique.day = day

return Boutique

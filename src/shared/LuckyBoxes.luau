--!strict
-- The Luxe Lucky Boxes: three boxes sold for Robux, each opening to one brainrot, rarer the
-- dearer the box. Everything a guest needs to decide is shown before they buy and is exactly what
-- the server rolls with:
--   * the odds of every brainrot in the box (they add up to 100%; every open gives one, there is
--     no empty result), and the odds of it coming Gold, Diamond or Rainbow;
--   * the guarantee (pity): if this many opens in a row bring nothing of a rarity or better, the
--     next one does, picked by the same odds among those. Its counter is on the box;
--   * the price, on the key, from Roblox.
-- Only brainrots that are also found free at the tables are in the boxes (never a Secret, never
-- an auction or attraction one): a box is a quicker way to them, never the only way. And they're
-- only sold where Roblox's policy for the guest allows paid random items (server/Policy).

local Brainrots = require(script.Parent.Brainrots)
local Curios = require(script.Parent.Curios)

local LuckyBoxes = {}

export type Box = {
	id: string,
	key: string, -- its ProductConfig key
	name: string,
	short: string,
	line: string,
	price: number, -- the reference price (Roblox's own price is shown when it's known)
	colour: Color3, -- the box
	ribbon: Color3,
	glow: Color3,
	odds: { { rarity: string, chance: number } }, -- percent, rarest last; adds up to 100
	mut: { [string]: number }, -- the chance (0 to 1) it comes Gold, Diamond or Rainbow
	pity: { at: number, rarity: string },
}

local rgb = Color3.fromRGB

LuckyBoxes.Order = { "gilded", "velvet", "noir" }

LuckyBoxes.Boxes = {
	gilded = {
		id = "gilded",
		key = "luckyGilded",
		name = "The Gilded Box",
		short = "Gilded",
		line = "Rare or better, every time.",
		price = 79,
		colour = rgb(222, 172, 70),
		ribbon = rgb(160, 18, 40),
		glow = rgb(255, 210, 120),
		odds = {
			{ rarity = "Rare", chance = 60 },
			{ rarity = "Epic", chance = 30 },
			{ rarity = "Legendary", chance = 9 },
			{ rarity = "Mythic", chance = 1 },
		},
		mut = { gold = 0.08, diamond = 0.02, rainbow = 0.005 },
		pity = { at = 20, rarity = "Legendary" },
	},
	velvet = {
		id = "velvet",
		key = "luckyVelvet",
		name = "The Velvet Box",
		short = "Velvet",
		line = "Epic or better, every time.",
		price = 199,
		colour = rgb(178, 24, 56),
		ribbon = rgb(255, 204, 90),
		glow = rgb(255, 96, 130),
		odds = {
			{ rarity = "Epic", chance = 56 },
			{ rarity = "Legendary", chance = 36 },
			{ rarity = "Mythic", chance = 8 },
		},
		mut = { gold = 0.12, diamond = 0.04, rainbow = 0.015 },
		pity = { at = 15, rarity = "Mythic" },
	},
	noir = {
		id = "noir",
		key = "luckyNoir",
		name = "The Noir Box",
		short = "Noir",
		line = "Legendary or better, every time.",
		price = 449,
		colour = rgb(20, 18, 24),
		ribbon = rgb(255, 214, 110),
		glow = rgb(196, 150, 255),
		odds = {
			{ rarity = "Legendary", chance = 69 },
			{ rarity = "Mythic", chance = 31 },
		},
		mut = { gold = 0.18, diamond = 0.07, rainbow = 0.03 },
		pity = { at = 4, rarity = "Mythic" },
	},
} :: { [string]: Box }

LuckyBoxes.byKey = {} :: { [string]: Box }
for _, b in LuckyBoxes.Boxes do
	LuckyBoxes.byKey[b.key] = b
end

-- The brainrots of a rarity that a box can hold: those found free at the tables, by id.
function LuckyBoxes.pool(rarity: string): { string }
	local out = {}
	for _, c in Curios.List do
		if c.family == "meme" and c.rarity == rarity and c.source == "tables" then
			table.insert(out, c.id)
		end
	end
	table.sort(out)
	return out
end

-- Every brainrot in a box with its chance (percent), rarest first, then by name.
function LuckyBoxes.odds(id: string): { { id: string, rarity: string, chance: number } }
	local box = LuckyBoxes.Boxes[id]
	local out = {}
	if not box then
		return out
	end
	for i = #box.odds, 1, -1 do
		local tier = box.odds[i]
		local ids = LuckyBoxes.pool(tier.rarity)
		for _, cid in ids do
			table.insert(out, { id = cid, rarity = tier.rarity, chance = tier.chance / #ids })
		end
	end
	return out
end

-- The chance (0 to 1) of no mutation: a plain one.
function LuckyBoxes.plain(id: string): number
	local box = LuckyBoxes.Boxes[id]
	if not box then
		return 1
	end
	local m = 0
	for _, c in box.mut do
		m += c
	end
	return math.max(0, 1 - m)
end

local function rank(rarity: string): number
	return Curios.RarityRank[rarity] or 0
end
LuckyBoxes.rank = rank

-- Opens until the guarantee, after `since` opens without its rarity (1: the next one is it).
function LuckyBoxes.pityLeft(id: string, since: number): number
	local box = LuckyBoxes.Boxes[id]
	if not box then
		return 0
	end
	return math.max(1, box.pity.at - math.max(0, since))
end

-- The pick, from two numbers in [0, 1) the server rolls: `x` the rarity by the odds, `y` which
-- one of that rarity. `forced`: the guarantee is due, so only its rarity or better (the same odds
-- among those). Returns the brainrot's id and its rarity.
function LuckyBoxes.pick(id: string, x: number, y: number, forced: boolean?): (string?, string?)
	local box = LuckyBoxes.Boxes[id]
	if not box then
		return nil, nil
	end
	local tiers = {}
	local total = 0
	for _, tier in box.odds do
		if (not forced or rank(tier.rarity) >= rank(box.pity.rarity)) and #LuckyBoxes.pool(tier.rarity) > 0 then
			table.insert(tiers, tier)
			total += tier.chance
		end
	end
	if total <= 0 then
		return nil, nil
	end
	local at = math.clamp(x, 0, 0.999999) * total
	local chosen = tiers[#tiers]
	local edge = 0
	for _, tier in tiers do
		edge += tier.chance
		if at < edge then
			chosen = tier
			break
		end
	end
	local ids = LuckyBoxes.pool(chosen.rarity)
	local i = math.clamp(math.floor(math.clamp(y, 0, 0.999999) * #ids) + 1, 1, #ids)
	return ids[i], chosen.rarity
end

-- Its mutation from a number in [0, 1) (rarest first, as at the tables), or nil for plain.
function LuckyBoxes.mutation(id: string, z: number): string?
	local box = LuckyBoxes.Boxes[id]
	if not box then
		return nil
	end
	local edge = 0
	for _, key in Brainrots.MutationOrder do
		edge += box.mut[key] or 0
		if z < edge then
			return key
		end
	end
	return nil
end

-- A chance as the box shows it, exactly (to two places): "12%", "15.5%", "0.5%".
function LuckyBoxes.percent(chance: number): string
	local s = string.format("%.2f", chance)
	s = (s:gsub("0+$", ""))
	s = (s:gsub("%.$", ""))
	return s .. "%"
end

return LuckyBoxes

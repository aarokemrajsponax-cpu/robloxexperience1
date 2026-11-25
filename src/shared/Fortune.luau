--!strict
-- A guest's Fortune: what the whole house is about. BUILD YOUR FORTUNE. MASTER THE MAISON. BECOME
-- THE WEALTHIEST. It is everything a guest owns, in Gilt:
--   * the Gilt in their purse and their Gems (each worth Config.Fortune.gemWorth);
--   * their collection: every brainrot and curio, by its rarity (Fortune.RarityWorth);
--   * their Suite and wardrobe: every piece that has a Gilt price, at that price;
--   * their Estate: everything carried out of Steal a Luxe, won in the Maison Basement, taken from
--     the Executive's office and won at the Grand Auction. The Estate never goes down.
-- The server works it out from the saved record (server/Fortune); nothing a screen says counts.
-- The boards rank the Fortune a guest has EARNED: Gilt and Gems bought with Robux are left out of
-- the ranking (they still show in the guest's own Fortune), so nobody buys the top of the board.

local Config = require(script.Parent.Config)

local Fortune = {}

Fortune.TAGLINE = "BUILD YOUR FORTUNE. MASTER THE MAISON. BECOME THE WEALTHIEST."
Fortune.TAGLINE_LINES = { "Build your fortune.", "Master the Maison.", "Become the wealthiest." }

-- What one of each rarity adds to a Fortune.
Fortune.RarityWorth = {
	Common = 50,
	Uncommon = 150,
	Rare = 500,
	Epic = 1500,
	Legendary = 5000,
	Mythic = 20000,
	Secret = 50000,
	Limited = 10000,
} :: { [string]: number }

export type Rank = { id: string, name: string, at: number, line: string }

-- The wealth ranks, lowest first: the Fortune each begins at. (Names only: nothing here is money.)
Fortune.Ranks = {
	{ id = "newcomer", name = "Newcomer", at = 0, line = "Everyone starts at the door." },
	{ id = "climber", name = "Climber", at = 1000, line = "A first thousand to your name." },
	{ id = "affluent", name = "Affluent", at = 5000, line = "The staff have learned your name." },
	{ id = "wealthy", name = "Wealthy", at = 15000, line = "Your Suite is the talk of the Club Floor." },
	{ id = "magnate", name = "Magnate", at = 40000, line = "Doors open before you reach them." },
	{ id = "tycoon", name = "Tycoon", at = 100000, line = "The Vault keeps a wing for you." },
	{ id = "baron", name = "Baron", at = 250000, line = "The house asks your opinion now." },
	{ id = "mogul", name = "Mogul", at = 600000, line = "Half the Maison is yours in all but name." },
	{ id = "billionaire", name = "Billionaire", at = 1500000, line = "There is very little left to buy." },
	{ id = "sovereign", name = "Sovereign of the Maison", at = 5000000, line = "The wealthiest there is." },
} :: { Rank }

-- The rank a Fortune stands at, its number (1 = Newcomer), and the next one (nil at the top).
function Fortune.rank(total: number): (Rank, number, Rank?)
	local at = 1
	for i, r in Fortune.Ranks do
		if total >= r.at then
			at = i
		end
	end
	return Fortune.Ranks[at], at, Fortune.Ranks[at + 1]
end

-- How far through its rank a Fortune is (0 to 1; 1 at the top rank).
function Fortune.progress(total: number): number
	local r, _, nextRank = Fortune.rank(total)
	if not nextRank then
		return 1
	end
	return math.clamp((total - r.at) / math.max(1, nextRank.at - r.at), 0, 1)
end

-- 12,500 -> "12,500"; and for small spaces 12,500 -> "12.5K", 1,250,000 -> "1.25M".
function Fortune.format(n: number): string
	local text = tostring(math.floor(math.max(0, n)))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

function Fortune.short(n: number): string
	n = math.max(0, math.floor(n))
	local function trim(x: number, unit: string): string
		local s = if x >= 100 then string.format("%.0f", x) elseif x >= 10 then string.format("%.1f", x) else string.format("%.2f", x)
		if string.find(s, ".", 1, true) then
			s = string.gsub(string.gsub(s, "0+$", ""), "%.$", "")
		end
		return s .. unit
	end
	if n >= 1e9 then
		return trim(n / 1e9, "B")
	elseif n >= 1e6 then
		return trim(n / 1e6, "M")
	elseif n >= 10000 then
		return trim(n / 1e3, "K")
	end
	return Fortune.format(n)
end

export type Parts = { gilt: number, gems: number, collection: number, suite: number, estate: number }

-- The whole of a Fortune from its parts.
function Fortune.total(p: Parts): number
	return math.floor(p.gilt + p.gems + p.collection + p.suite + p.estate)
end

-- The part of a haul's worth paid in Gilt when it's banked (the rest is the Estate alone).
-- (Build 102) The one sum for what a reward pays in Gilt, used by the server to pay it and by a
-- screen to show it first, so the two are always the same number: `raw` Gilt, times the guest's
-- boosts (`boost`, then the Gold Key's `key`), with the day's soft cap (`softCap` times the boost,
-- less `today` already earned) and what's over it paid at `rate`.
-- (Build 104) The house's Gilt scale (Config.Gilt.payoutScale): every reward for playing is this
-- many times its base figure.
function Fortune.scale(): number
	local g = (Config.data :: any).Gilt
	local s = tonumber(g and g.payoutScale) or 1
	return if s >= 1 then s else 1
end

-- A base Gilt figure at the house's scale: what a prize pays, and what a screen shows of it.
function Fortune.scaled(raw: number): number
	return math.floor(raw * Fortune.scale() + 0.5)
end

function Fortune.giltPaid(raw: number, boost: number, key: number, softCap: number, today: number, rate: number): number
	-- (Build 104) At the house's scale, the reward and the day's soft cap alike.
	local scale = Fortune.scale()
	raw *= scale
	softCap *= scale
	local earned = math.floor(raw * boost + 0.5)
	if key > 1 then
		earned = math.floor(earned * key + 0.5)
	end
	local full = math.max(0, math.min(earned, softCap * boost - today))
	local reduced = math.floor((earned - full) * rate)
	return full + reduced
end

-- (Build 102) What `raw` Gilt would pay this guest now, read from what the server publishes on
-- them ("GiltBoost", "GiltKey", "GiltCap", "GiltToday", "GiltRate"); for a screen to show a
-- reward before it's earned. The server pays with the same sum (server/Gilt).
function Fortune.quoteFor(player: Instance, raw: number): number
	local function num(name: string, default: number): number
		local v = player:GetAttribute(name)
		return if type(v) == "number" then v else default
	end
	return Fortune.giltPaid(raw, num("GiltBoost", 1), num("GiltKey", 1), num("GiltCap", math.huge), num("GiltToday", 0), num("GiltRate", 1))
end

function Fortune.cash(worth: number): number
	local share = tonumber((Config.data :: any).Fortune and (Config.data :: any).Fortune.cashShare) or 0.2
	return math.floor(math.max(0, worth) * share + 0.5)
end

return Fortune

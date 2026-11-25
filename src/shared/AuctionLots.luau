--!strict
-- The Grand Auction's lots (shared by the server, which runs the bidding, and every screen). Each
-- week has its lots, the same in every server (chosen from the pool by the week's number), and a
-- season adds one of its own while it lasts. Every lot is one of a kind for its winner: a piece
-- for their collection that's only ever won here, never sold.

local Fortune = require(script.Parent.Fortune)

local AuctionLots = {}

export type Lot = {
	key: string, -- which lot it is (the pool's)
	name: string,
	line: string,
	glyph: string,
	curio: string, -- what the winner receives (shared/Curios)
	currency: string, -- "Gilt" or "Gems"
	start: number, -- the first bid
}
export type Live = Lot & { id: string, week: number, ends: number, seasonal: boolean }

-- (Build 105) The first bids climb with the lot (in Gilt at the house's Gilt scale, shared/Fortune:
-- x10 as it ships, so from 400,000 Gilt for the Imperial Teacup to 2,500,000 for the Golden Lion),
-- and three more lots join the pool, four a week. Each is still won by one guest only.
AuctionLots.Pool = {
	{ key = "pavone", name = "Il Pavone d'Oro", line = "A golden peacock that has never once lowered its tail.", glyph = "🦚", curio = "pavoneDoro", currency = "Gilt", start = 60000 },
	{ key = "banchiere", name = "Il Banchiere Bianco", line = "A banker in white tie who counts in his sleep.", glyph = "🎩", curio = "banchiereBianco", currency = "Gilt", start = 80000 },
	{ key = "leone", name = "Il Leone d'Oro", line = "A golden lion in a velvet cape. He has never once queued.", glyph = "🦁", curio = "leoneOro", currency = "Gilt", start = 250000 },
	{ key = "uovo", name = "The Midnight Egg", line = "A jewelled egg that opens on a tiny ballroom.", glyph = "🥚", curio = "uovoMezzanotte", currency = "Gilt", start = 120000 },
	{ key = "orologio", name = "L'Orologio del Re", line = "The king's watch: it runs a minute fast, on purpose.", glyph = "⌚", curio = "orologioRe", currency = "Gems", start = 150 },
	{ key = "tazza", name = "La Tazza Imperiale", line = "An emperor's teacup. Still warm, somehow.", glyph = "🍵", curio = "tazzaImperiale", currency = "Gilt", start = 40000 },
	{ key = "corvo", name = "Il Corvo di Diamante", line = "A crow that only ever steals diamonds, and only the good ones.", glyph = "🐦‍⬛", curio = "corvoDiamante", currency = "Gems", start = 400 },
	{ key = "lupo", name = "Il Lupo di Borsa", line = "A wolf in a waistcoat who reads the markets aloud.", glyph = "🐺", curio = "lupoBorsa", currency = "Gems", start = 250 },
} :: { Lot }

-- The seasons' own lots: on offer while their dates last (month and day, in UTC).
AuctionLots.Seasonal = {
	{ key = "cigno", name = "Il Cigno d'Inverno", line = "A swan carved from winter itself. It never melts.", glyph = "🦢", curio = "cignoInverno", currency = "Gilt", start = 150000, from = { 12, 1 }, to = { 1, 6 } },
	{ key = "renna", name = "La Renna di Ghiaccio", line = "A reindeer of blue ice who pulls the Maison's sleigh on Christmas Eve.", glyph = "🦌", curio = "rennaGhiaccio", currency = "Gilt", start = 200000, from = { 12, 1 }, to = { 1, 6 } },
	{ key = "coniglio", name = "Il Coniglio di Primavera", line = "A spring hare in a gilded waistcoat.", glyph = "🐇", curio = "coniglioPrimavera", currency = "Gilt", start = 100000, from = { 3, 20 }, to = { 4, 30 } },
	{ key = "zucca", name = "La Zucca d'Argento", line = "A silver pumpkin with a candle that never burns down.", glyph = "🎃", curio = "zuccaArgento", currency = "Gilt", start = 100000, from = { 10, 1 }, to = { 11, 2 } },
} :: { Lot & { from: { number }, to: { number } } }

AuctionLots.PER_WEEK = 4
AuctionLots.WEEK = 7 * 86400

-- (Build 105) A lot's first bid as it's shown and taken: Gilt at the house's Gilt scale, Gems as set.
function AuctionLots.startOf(lot: Lot): number
	return if lot.currency == "Gilt" then Fortune.scaled(lot.start) else lot.start
end

-- The week's number (Mondays, UTC) and when it ends.
function AuctionLots.week(now: number): number
	return math.floor((math.floor(now / 86400) + 3) / 7)
end

function AuctionLots.ends(week: number): number
	-- (Its Monday is day 7w - 3; it closes that Sunday evening, at 19:00 UTC.)
	return (week * 7 - 3 + 6) * 86400 + 19 * 3600
end

local function inSeason(s: { from: { number }, to: { number } }, now: number): boolean
	local d = os.date("!*t", now) :: any
	local m, day = d.month, d.day
	local a = s.from[1] * 100 + s.from[2]
	local b = s.to[1] * 100 + s.to[2]
	local x = m * 100 + day
	if a <= b then
		return x >= a and x <= b
	end
	return x >= a or x <= b -- (a season across the new year)
end

-- The lots on offer in a week (the same everywhere), and the season's if one is on.
function AuctionLots.forWeek(week: number, now: number): { Live }
	local out: { Live } = {}
	local pool = AuctionLots.Pool
	for i = 1, AuctionLots.PER_WEEK do
		local lot = pool[((week * AuctionLots.PER_WEEK + i - 1) % #pool) + 1]
		local live = table.clone(lot) :: any
		live.start = AuctionLots.startOf(lot)
		live.id = string.format("w%d-%s", week, lot.key)
		live.week = week
		live.ends = AuctionLots.ends(week)
		live.seasonal = false
		table.insert(out, live)
	end
	for _, s in AuctionLots.Seasonal do
		if inSeason(s, now) then
			local live = table.clone(s) :: any
			live.start = AuctionLots.startOf(s)
			live.from, live.to = nil, nil
			live.id = string.format("w%d-%s", week, s.key)
			live.week = week
			live.ends = AuctionLots.ends(week)
			live.seasonal = true
			table.insert(out, live)
		end
	end
	return out
end

-- The least the next bid may be: the first bid, or a twentieth over the highest (rounded up to a
-- tidy step).
function AuctionLots.minNext(lot: Lot, high: number?): number
	if not high or high <= 0 then
		return lot.start
	end
	local step = if lot.currency == "Gems" then 5 else 100
	return math.max(high + step, math.ceil(high * 1.05 / step) * step)
end

return AuctionLots

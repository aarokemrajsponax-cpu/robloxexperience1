--!nocheck
-- The Grand Auction on the server (server/Auction, shared/AuctionLots), under Lune in the house's
-- test harness: the week's lots (the same in every server) and the season's; the least next bid;
-- a bid taken from the purse only if it stands; two servers bidding at once (only one stands, the
-- other is given straight back); an outbid guest paid back (now, or when they next come); the lot
-- closing, settled once and delivered once to its winner; requests that aren't bids refused.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/auction.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module, profiles = H.module, H.profiles
local Remotes = H.Remotes

local Lots = module("ReplicatedStorage", "Shared", "AuctionLots")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local Auction = module("ServerScriptService", "Server", "Auction")

-- Wednesday 12 November 2026, noon UTC.
local T = os.time({ year = 2026, month = 11, day = 11, hour = 12 }) + 86400
Auction.now = function()
	return T
end
local awards = {}
Auction.award = function(p, key)
	table.insert(awards, { p = p, key = key })
end

local function askAs(g, request)
	advance(0.4)
	local r
	run(function()
		r = Remotes.funcs.AuctionAsk.OnServerInvoke(g, request)
	end)
	return r
end
local function data(g)
	return profiles[g].Data
end
local function last(g, op)
	for i = #g.inbox, 1, -1 do
		if g.inbox[i].op == op then
			return g.inbox[i]
		end
	end
	return nil
end
local store = function()
	return H.dataStores.Auction_v1 or {}
end

---------------------------------------------------------------------------------------------------
-- 1. The lots
---------------------------------------------------------------------------------------------------
local week = Lots.week(T)
local lots = Lots.forWeek(week, T)
check("three lots a week (no season in mid-November)", #lots == 3)
local again = Lots.forWeek(week, T + 3600)
check("the same lots in every server, all week", again[1].id == lots[1].id and again[3].id == lots[3].id)
local nextWeek = Lots.forWeek(week + 1, T + 7 * 86400)
check("next week, others", nextWeek[1].key ~= lots[1].key)
local endsAt = os.date("!*t", lots[1].ends)
check("a week's lots close on its Sunday evening (19:00 UTC)", endsAt.wday == 1 and endsAt.hour == 19 and lots[1].ends > T and lots[1].ends - T < 7 * 86400, os.date("!%c", lots[1].ends))
local december = os.time({ year = 2026, month = 12, day = 10, hour = 12 })
local winter = Lots.forWeek(Lots.week(december), december)
local seasonal = nil
for _, l in winter do
	if l.seasonal then
		seasonal = l
	end
end
check("in its season, a seasonal lot as well", #winter == 4 and seasonal ~= nil and seasonal.key == "cigno")
local allReal = true
for _, l in Lots.Pool do
	if not CurioList.byId[l.curio] then
		allReal = false
	end
end
for _, l in Lots.Seasonal do
	if not CurioList.byId[l.curio] then
		allReal = false
	end
end
check("every lot is a real piece for the collection", allReal)
local giltLot, gemLot = nil, nil
for _, l in lots do
	if l.currency == "Gilt" and not giltLot then
		giltLot = l
	elseif l.currency == "Gems" and not gemLot then
		gemLot = l
	end
end
check("(this week has a Gilt lot)", giltLot ~= nil)
check("the least next bid: the opening price, then a twentieth more in tidy steps", Lots.minNext(giltLot, nil) == giltLot.start and Lots.minNext(giltLot, 10000) == 10500 and Lots.minNext(giltLot, 10010) == 10600)

---------------------------------------------------------------------------------------------------
-- 2. Bidding
---------------------------------------------------------------------------------------------------
run(Auction.start)
local ada, bo = H.guest("Ada", 901), H.guest("Bo", 902)
data(ada).gilt, data(bo).gilt = 100000, 100000
local board = askAs(ada, { op = "board" })
check("the board: this week's lots, their time left, no bids yet", board.ok == true and #board.lots == 3 and board.lots[1].high == 0 and board.lots[1].left > 0 and board.lots[1].minNext == board.lots[1].start)
local r = askAs(ada, { op = "bid", lot = giltLot.id, amount = giltLot.start - 1 })
check("under the least bid: refused, and nothing taken", r.ok == false and string.find(r.why, "least bid", 1, true) ~= nil and data(ada).gilt == 100000, r.why)
data(ada).gilt = giltLot.start - 1
r = askAs(ada, { op = "bid", lot = giltLot.id, amount = giltLot.start })
check("more than the purse holds: refused", r.ok == false and data(ada).gilt == giltLot.start - 1)
data(ada).gilt = 100000
r = askAs(ada, { op = "bid", lot = giltLot.id, amount = giltLot.start })
check("a bid that stands: taken from the purse", r.ok == true and data(ada).gilt == 100000 - giltLot.start)
check("...on the lot's record, for every server", store()[giltLot.id].high == giltLot.start and store()[giltLot.id].by == 901)
check("...and the screen says it's theirs", r.lot.mine == true and r.lot.high == giltLot.start)
r = askAs(ada, { op = "bid", lot = giltLot.id, amount = giltLot.start * 2 })
check("their own bid can't be outbid by themselves", r.ok == false and data(ada).gilt == 100000 - giltLot.start)
local adaBid = giltLot.start
local boBid = Lots.minNext(giltLot, adaBid)
r = askAs(bo, { op = "bid", lot = giltLot.id, amount = boBid })
check("outbid by another guest", r.ok == true and data(bo).gilt == 100000 - boBid and store()[giltLot.id].by == 902)
advance(1)
check("the guest outbid is paid back at once (they're here), and told", data(ada).gilt == 100000 and last(ada, "outbid") ~= nil and last(ada, "outbid").back == adaBid)
check("...and nothing's owed in the record any more", (store()[giltLot.id].refunds["901"] or 0) == 0)

-- Another server's bid, a moment before this one's.
local theirs = Lots.minNext(giltLot, boBid)
local rec = table.clone(store()[giltLot.id])
rec.refunds = table.clone(rec.refunds)
rec.refunds["902"] = (rec.refunds["902"] or 0) + rec.high
rec.high, rec.by, rec.name = theirs, 999, "Zed"
rec.bids = table.clone(rec.bids)
table.insert(rec.bids, { u = 999, n = "Zed", a = theirs, t = T })
store()[giltLot.id] = rec
local stale = Lots.minNext(giltLot, boBid) -- (what this server last knew was enough)
local before = data(ada).gilt
r = askAs(ada, { op = "bid", lot = giltLot.id, amount = stale })
check("two servers at once: the later bid doesn't stand, and is given straight back", r.ok == false and string.find(r.why, "Someone bid first", 1, true) ~= nil and data(ada).gilt == before, r.why)
check("...the record keeps the one that stood", store()[giltLot.id].by == 999 and store()[giltLot.id].high == theirs)
-- (Every server reads the lots again every 45 seconds, then pays what's owed to its guests.)
run(function()
	Auction.read(giltLot.id)
	Auction.claim(bo)
end)
check("the guest that other server outbid is paid back here", data(bo).gilt == 100000 and last(bo, "outbid") ~= nil)
-- The store failing mid-bid.
H.storeFault = function(name)
	return name == "Auction_v1"
end
before = data(ada).gilt
r = askAs(ada, { op = "bid", lot = giltLot.id, amount = Lots.minNext(giltLot, theirs) })
H.storeFault = nil
check("the auction's store failing: the bid doesn't stand, and nothing is lost", r.ok == false and data(ada).gilt == before)
-- A winning bid.
local final = Lots.minNext(giltLot, theirs)
r = askAs(ada, { op = "bid", lot = giltLot.id, amount = final })
check("(Ada bids again, and it stands)", r.ok == true and store()[giltLot.id].by == 901)
board = askAs(bo, { op = "board" })
local mineView = nil
for _, l in board.lots do
	if l.id == giltLot.id then
		mineView = l
	end
end
check("everyone's board: the highest bid and by whom, the least next bid, the last bids", mineView.high == final and mineView.by == "Ada" and mineView.minNext == Lots.minNext(giltLot, final) and #mineView.history >= 3 and mineView.history[1].amount == final)
if gemLot then
	data(bo).gems = 1000
	r = askAs(bo, { op = "bid", lot = gemLot.id, amount = gemLot.start })
	check("a lot in Gems takes Gems", r.ok == true and data(bo).gems == 1000 - gemLot.start)
end

---------------------------------------------------------------------------------------------------
-- 3. Requests that aren't bids
---------------------------------------------------------------------------------------------------
r = askAs(bo, { op = "bid", lot = giltLot.id, amount = -5 })
check("a negative bid is refused", r.ok == false)
r = askAs(bo, { op = "bid", lot = giltLot.id, amount = 0 / 0 })
check("a bid that isn't a number is refused", r.ok == false)
r = askAs(bo, { op = "bid", lot = giltLot.id, amount = 1e9, winner = true })
check("a request with anything else in it is refused", r.ok == false)
r = askAs(bo, { op = "bid", lot = "w1-nothing", amount = 50000 })
check("a lot that isn't up for auction is refused", r.ok == false)

---------------------------------------------------------------------------------------------------
-- 4. The close: settled once, delivered once
---------------------------------------------------------------------------------------------------
-- Bo was outbid on a lot and leaves before he's paid back.
local other = nil
for _, l in lots do
	if l.currency == "Gilt" and l.id ~= giltLot.id then
		other = l
	end
end
if other then
	askAs(bo, { op = "bid", lot = other.id, amount = other.start })
	local boLeft = data(bo).gilt
	local rec2 = table.clone(store()[other.id])
	rec2.refunds = table.clone(rec2.refunds)
	rec2.refunds["902"] = (rec2.refunds["902"] or 0) + rec2.high
	rec2.high, rec2.by = Lots.minNext(other, rec2.high), 999
	store()[other.id] = rec2
	check("(an outbid guest's money waits in the lot's record)", store()[other.id].refunds["902"] == other.start and data(bo).gilt == boLeft)
end
T = giltLot.ends + 60
r = askAs(bo, { op = "bid", lot = giltLot.id, amount = 1e6 })
check("after the close, no more bids", r.ok == false)
run(function()
	Auction.claim(ada)
end)
local won = last(ada, "auctionWon")
check("its highest bidder wins: the piece in their collection, and told", won ~= nil and won.lot == giltLot.id and (data(ada).curios.items[giltLot.curio] or 0) == 1)
check("...the badge", #awards > 0 and awards[#awards].key == "auctionWin")
check("...settled once, for every server", store()[giltLot.id].settled == true and store()[giltLot.id].winner == 901 and store()[giltLot.id].delivered == true)
run(function()
	Auction.claim(ada)
end)
check("delivered once only", (data(ada).curios.items[giltLot.curio] or 0) == 1)
run(function()
	if other then
		Auction.read(other.id)
	end
	Auction.claim(bo)
end)
check("nobody else is given it", ((data(bo).curios and data(bo).curios.items[giltLot.curio]) or 0) == 0)
if other then
	check("an outbid guest is paid back when they next come", (store()[other.id].refunds["902"] or 0) == 0 and last(bo, "outbid") ~= nil)
end

H.finish()

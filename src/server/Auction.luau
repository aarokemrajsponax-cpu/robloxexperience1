--!strict
-- The Grand Auction (in the Library): the week's lots and the season's (shared/AuctionLots), bid
-- for in Gilt or Gems by guests in every server at once.
--
--   A bid       the bidder names an amount (never less than the least next bid). It's taken from
--               their purse first (reserved), then written to the lot's record in one step that
--               checks it's still enough (UpdateAsync): two bids at once in two servers, and only
--               one of them stands. A bid that doesn't stand is given straight back.
--   Outbid      the bid it beat is owed back to its bidder, kept in the lot's own record, and paid
--               to them by whichever server they're in (now, or the next time they come).
--   The end     a lot closes when its week does; its highest bidder wins, and the piece is
--               delivered to them by the server they're in (now, or the next time they come).
-- Nothing a screen says is a price, a bid that stands, or a winner.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lots = require(ReplicatedStorage.Shared.AuctionLots)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Curios = require(script.Parent.Curios)
local Fortune = require(script.Parent.Fortune)
local Gilt = require(script.Parent.Gilt)
local Herald = require(script.Parent.Herald)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Auction = {}

-- Set by Main: a badge, a count for the house's records.
Auction.award = function(_player: Player, _key: string) end
Auction.tally = function(_player: Player, _stat: string, _n: number, _once: string?) end
-- The store (set by tests).
Auction.store = function(): any
	return DataStoreService:GetDataStore("Auction_v1")
end
-- The time (set by tests).
Auction.now = function(): number
	return os.time()
end

export type Record = {
	high: number,
	by: number?,
	name: string?,
	bids: { { u: number, n: string, a: number, t: number } },
	refunds: { [string]: number }, -- UserId (as text) -> owed back
	settled: boolean,
	winner: number?,
	delivered: boolean,
}

local cache: { [string]: Record } = {} -- lot id -> its record as last read
local fetched: { [string]: number } = {} -- lot id -> when it was last read (os.clock)
local event = Remotes.event("Empire")

local function blank(): Record
	return { high = 0, by = nil, name = nil, bids = {}, refunds = {}, settled = false, winner = nil, delivered = false }
end

local function copy(r: any): Record
	local out = blank()
	if type(r) ~= "table" then
		return out
	end
	out.high = tonumber(r.high) or 0
	out.by = tonumber(r.by)
	out.name = if type(r.name) == "string" then r.name else nil
	out.bids = if type(r.bids) == "table" then table.clone(r.bids) else {}
	out.refunds = if type(r.refunds) == "table" then table.clone(r.refunds) else {}
	out.settled = r.settled == true
	out.winner = tonumber(r.winner)
	out.delivered = r.delivered == true
	return out
end

-- The lots on offer now, and last week's (still to settle and deliver).
function Auction.lots(): { Lots.Live }
	local now = Auction.now()
	local week = Lots.week(now)
	local out = Lots.forWeek(week, now)
	for _, l in Lots.forWeek(week - 1, now - Lots.WEEK) do
		table.insert(out, l)
	end
	return out
end

local function lotById(id: string): Lots.Live?
	for _, l in Auction.lots() do
		if l.id == id then
			return l
		end
	end
	return nil
end

local function purse(data: any, currency: string): number
	return if currency == "Gems" then (tonumber(data.gems) or 0) else (tonumber(data.gilt) or 0)
end

local function changePurse(player: Player, data: any, currency: string, delta: number, why: string)
	if currency == "Gems" then
		data.gems = (tonumber(data.gems) or 0) + delta
		player:SetAttribute("Gems", data.gems)
		Curios.push(player)
	else
		data.gilt = (tonumber(data.gilt) or 0) + delta
		Gilt.changed(player)
	end
	if delta < 0 then
		Analytics.sink(player, currency, -delta, purse(data, currency), why)
	else
		Analytics.source(player, currency, delta, purse(data, currency), why)
	end
	Fortune.sync(player)
end

local function read(id: string): Record?
	local ok, got = pcall(function()
		return Auction.store():GetAsync(id)
	end)
	if not ok then
		return nil
	end
	local r = copy(got)
	cache[id] = r
	fetched[id] = os.clock()
	return r
end

-- A lot's record, read again if it's more than `age` seconds old (bids come from every server).
local function fresh(id: string, age: number): Record?
	local at = fetched[id]
	if not cache[id] or not at or os.clock() - at > age then
		return read(id) or cache[id]
	end
	return cache[id]
end

-- What a guest's screen shows of a lot.
local function view(l: Lots.Live, r: Record?, me: number): { [string]: any }
	local rec = r or blank()
	local history = {}
	for k = #rec.bids, math.max(1, #rec.bids - 5), -1 do
		local b = rec.bids[k]
		table.insert(history, { name = b.n, amount = b.a, at = b.t })
	end
	return {
		id = l.id,
		name = l.name,
		line = l.line,
		glyph = l.glyph,
		curio = l.curio, -- (Build 82: its medallion on the lot's card)
		currency = l.currency,
		start = l.start,
		ends = l.ends,
		left = math.max(0, l.ends - Auction.now()),
		high = rec.high,
		by = rec.name,
		mine = rec.by == me,
		minNext = Lots.minNext(l, if rec.high > 0 then rec.high else nil),
		history = history,
		seasonal = l.seasonal,
		settled = rec.settled or Auction.now() >= l.ends,
		won = rec.settled and rec.winner == me,
	}
end

-- Places a bid. Returns { ok, why }.
function Auction.bid(player: Player, id: string, amount: number): { [string]: any }
	local l = lotById(id)
	if not l or l.week ~= Lots.week(Auction.now()) then
		return { ok = false, why = "That lot isn't up for auction." }
	end
	if Auction.now() >= l.ends then
		return { ok = false, why = "Bidding on that lot has closed." }
	end
	amount = math.floor(amount)
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local known = cache[id]
	local need = Lots.minNext(l, if known and known.high > 0 then known.high else nil)
	if amount < need then
		return { ok = false, why = string.format("The least bid now is %s %s.", Rules.format(need), l.currency) }
	end
	if known and known.by == player.UserId then
		return { ok = false, why = "Yours is already the highest bid." }
	end
	if purse(data, l.currency) < amount then
		return { ok = false, why = string.format("You'd need %s %s.", Rules.format(amount), l.currency) }
	end
	-- Reserved first, then written: if it doesn't stand, it's given straight back.
	changePurse(player, data, l.currency, -amount, "auction_bid")
	local stood, why, beaten = false, nil :: string?, nil :: number?
	local ok, err = pcall(function()
		Auction.store():UpdateAsync(id, function(old: any): any
			local r = copy(old)
			stood, why, beaten = false, nil, nil
			if r.settled or Auction.now() >= l.ends then
				why = "Bidding on that lot has closed."
				return nil
			end
			if r.by == player.UserId then
				why = "Yours is already the highest bid."
				return nil
			end
			local least = Lots.minNext(l, if r.high > 0 then r.high else nil)
			if amount < least then
				why = string.format("Someone bid first: the least bid now is %s %s.", Rules.format(least), l.currency)
				return nil
			end
			if r.by then
				local key = tostring(r.by)
				r.refunds[key] = (r.refunds[key] or 0) + r.high
				beaten = r.by
			end
			r.high = amount
			r.by = player.UserId
			r.name = Names.of(player)
			table.insert(r.bids, { u = player.UserId, n = Names.of(player), a = amount, t = Auction.now() })
			while #r.bids > 20 do
				table.remove(r.bids, 1)
			end
			stood = true
			cache[id] = r
			return r
		end)
	end)
	if not ok or not stood then
		changePurse(player, data, l.currency, amount, "auction_returned")
		return { ok = false, why = why or ("The auction couldn't take that bid just now: " .. tostring(err)) }
	end
	Auction.tally(player, "auctionBids", 1)
	event:FireAllClients({ op = "auctionBid", lot = l.id, name = l.name, by = Names.of(player), amount = amount, currency = l.currency })
	-- The bidder it beat, if they're here: their bid back now.
	if beaten then
		local other = Players:GetPlayerByUserId(beaten)
		if other then
			task.spawn(Auction.claim, other)
		end
	end
	return { ok = true, lot = view(l, cache[id], player.UserId) }
end

-- Pays a guest what they're owed (bids that were beaten) and delivers what they've won.
function Auction.claim(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local key = tostring(player.UserId)
	local now = Auction.now()
	for _, l in Auction.lots() do
		local r = cache[l.id] or read(l.id)
		if not r then
			continue
		end
		-- A bid beaten: owed back.
		if (r.refunds[key] or 0) > 0 then
			local owed = 0
			pcall(function()
				Auction.store():UpdateAsync(l.id, function(old: any): any
					local fresh = copy(old)
					owed = fresh.refunds[key] or 0
					if owed <= 0 then
						return nil
					end
					fresh.refunds[key] = nil
					cache[l.id] = fresh
					return fresh
				end)
			end)
			if owed > 0 then
				changePurse(player, data, l.currency, owed, "auction_refund")
				event:FireClient(player, { op = "outbid", lot = l.id, name = l.name, back = owed, currency = l.currency })
			end
		end
		-- Closed: settled (once, by whichever server comes first), and the piece delivered.
		if now >= l.ends then
			local mine = false
			pcall(function()
				Auction.store():UpdateAsync(l.id, function(old: any): any
					local fresh = copy(old)
					mine = false
					if not fresh.settled then
						fresh.settled = true
						fresh.winner = fresh.by
					end
					if fresh.winner == player.UserId and not fresh.delivered then
						fresh.delivered = true
						mine = true
					end
					cache[l.id] = fresh
					return fresh
				end)
			end)
			if mine then
				Curios.give(player, data, l.curio, 1, "The Grand Auction")
				Curios.push(player)
				Auction.award(player, "auctionWin")
				Auction.tally(player, "auctionWins", 1)
				local paid = (cache[l.id] or blank()).high
				event:FireClient(player, { op = "auctionWon", lot = l.id, name = l.name, glyph = l.glyph, amount = paid, currency = l.currency })
				Herald.feat(player, { kind = "auction", title = "Sold at the Grand Auction", line = "won " .. l.name .. " at the Grand Auction", glyph = l.glyph, worth = if l.currency == "Gilt" then paid else nil, everywhere = true })
			end
		end
	end
end

-- What a guest's Grand Auction screen shows.
function Auction.board(player: Player): { [string]: any }
	local week = Lots.week(Auction.now())
	local lots = {}
	for _, l in Auction.lots() do
		if l.week == week then
			table.insert(lots, view(l, fresh(l.id, 10), player.UserId))
		end
	end
	return { ok = true, lots = lots, now = Auction.now() }
end

function Auction.start()
	RemoteGuard.invoke(Remotes.func("AuctionAsk"), "auctionAsk", function(player: Player, request: unknown): any
		local r = RemoteGuard.message(request, 3, 0)
		if not r then
			RemoteGuard.reject(player, "auctionAsk", "malformed")
			return { ok = false, why = "That isn't something the house does." }
		end
		for k in r do
			if k ~= "op" and k ~= "lot" and k ~= "amount" then
				RemoteGuard.reject(player, "auctionAsk", "malformed")
				return { ok = false, why = "That isn't something the house does." }
			end
		end
		if r.op == "board" then
			return Auction.board(player)
		elseif r.op == "bid" then
			local id, amount = r.lot, tonumber(r.amount)
			if type(id) ~= "string" or #id > 40 or not amount or amount ~= amount or amount <= 0 or amount > 1e12 then
				return { ok = false, why = "That isn't a bid." }
			end
			return Auction.bid(player, id, amount)
		end
		return { ok = false, why = "That isn't something the house does." }
	end)
	Profiles.Loaded:Connect(function(player: Player)
		task.spawn(Auction.claim, player)
	end)
	task.spawn(function()
		while true do
			task.wait(45)
			-- (Read again: bids made in other servers, and what's owed to guests here.)
			for _, l in Auction.lots() do
				pcall(read, l.id)
			end
			for _, player in Players:GetPlayers() do
				pcall(Auction.claim, player)
			end
		end
	end)
end

-- For tests.
Auction.cache = cache
Auction.read = read

return Auction

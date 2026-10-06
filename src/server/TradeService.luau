--!strict
-- Trading curios between two guests in the same server. Everything is the server's: who may
-- trade, what each side offers (checked against what they hold, and whether it can be traded),
-- and the swap itself, done in one step only when both sides have locked in and then confirmed
-- the very same offers.
--
-- The steps: an invitation (from a guest's card) → both choose what to offer → each locks in
-- ("Ready") → a short countdown in which either may still change their mind → each confirms →
-- the swap. Any change to either offer, at any point, unlocks both sides and starts again, so a
-- trade can never change after someone has confirmed it: a confirmation names the offers'
-- version, and a stale one is refused. Either side may cancel at any time; leaving cancels.
-- Guests can block (no more invitations from them this visit) and report (logged for the owner).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CurioList = require(ReplicatedStorage.Shared.Curios)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Curios = require(script.Parent.Curios)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local TradeService = {}

TradeService.Settings = {
	maxKinds = 8, -- different curios on one side of a trade
	maxEach = 99, -- of one curio
	countdown = 5, -- seconds after both lock in, before confirming opens
	cooldown = 20, -- seconds after a trade before either may trade again
	inviteGap = 10, -- seconds between invitations to the same guest
	inviteLife = 30, -- an invitation lapses after this long
	history = 10, -- trades kept in each profile
}

type Offer = { [string]: number }
export type Trade = {
	id: number,
	a: Player,
	b: Player,
	offers: { [Player]: Offer },
	ready: { [Player]: boolean },
	confirmed: { [Player]: boolean },
	version: number,
	state: "open" | "countdown" | "confirm" | "done" | "cancelled",
	countdownEnds: number,
}

local curioEvent = Remotes.event("Curio")
local trades: { [Player]: Trade } = {}
local invites: { [Player]: { [Player]: number } } = {} -- invited -> inviter -> when
local lastInvite: { [Player]: { [Player]: number } } = {}
local cooldownUntil: { [Player]: number } = {}
local blocked: { [Player]: { [number]: boolean } } = {}
local nextId = 0

TradeService.reports = {} :: { { from: number, about: number, trade: number?, at: number } }
TradeService.clock = os.clock

local function other(t: Trade, p: Player): Player
	return if t.a == p then t.b else t.a
end

local function view(t: Trade, p: Player): { [string]: any }
	local o = other(t, p)
	return {
		op = "trade",
		id = t.id,
		with = o.DisplayName,
		withId = o.UserId,
		mine = table.clone(t.offers[p]),
		theirs = table.clone(t.offers[o]),
		ready = t.ready[p] == true,
		theyReady = t.ready[o] == true,
		confirmed = t.confirmed[p] == true,
		theyConfirmed = t.confirmed[o] == true,
		version = t.version,
		state = t.state,
		countdown = if t.state == "countdown" then math.max(0, math.ceil(t.countdownEnds - TradeService.clock())) else 0,
	}
end

local function send(t: Trade)
	for _, p in { t.a, t.b } do
		if p.Parent then
			curioEvent:FireClient(p, view(t, p))
		end
	end
end

local function finish(t: Trade, state: "done" | "cancelled", why: string?)
	t.state = state
	for _, p in { t.a, t.b } do
		if trades[p] == t then
			trades[p] = nil
		end
		if p.Parent then
			curioEvent:FireClient(p, { op = "tradeEnd", id = t.id, state = state, why = why or "" })
		end
	end
end

-- Any change to an offer unlocks both sides and stops the countdown.
local function unlock(t: Trade)
	t.version += 1
	t.ready = {}
	t.confirmed = {}
	t.state = "open"
end

-- Whether `data` holds everything in `offer`, and all of it can be traded.
local function holds(data: Profiles.Data, offer: Offer): (boolean, string?)
	for id, n in offer do
		local c = CurioList.byId[id]
		if not c then
			return false, "That curio isn't known."
		elseif not c.tradeable then
			return false, c.name .. " can't be traded."
		elseif Curios.count(data, id) < n then
			return false, "You don't hold enough of " .. c.name .. "."
		end
	end
	return true, nil
end

-- The swap: checked again for both, then done in one step (nothing yields in between).
local function swap(t: Trade): (boolean, string?)
	local da, db = Profiles.get(t.a), Profiles.get(t.b)
	if not da or not db or not t.a.Parent or not t.b.Parent then
		return false, "Someone left."
	end
	local okA, whyA = holds(da, t.offers[t.a])
	local okB, whyB = holds(db, t.offers[t.b])
	if not okA or not okB then
		return false, whyA or whyB
	end
	local gaveA, gaveB = {}, {}
	for id, n in t.offers[t.a] do
		Curios.take(da, id, n)
		Curios.give(t.b, db, id, n, "trade")
		table.insert(gaveA, string.format("%s ×%d", CurioList.byId[id].name, n))
	end
	for id, n in t.offers[t.b] do
		Curios.take(db, id, n)
		Curios.give(t.a, da, id, n, "trade")
		table.insert(gaveB, string.format("%s ×%d", CurioList.byId[id].name, n))
	end
	local now = os.time()
	local sides: { { any } } = { { da, t.b, gaveA, gaveB }, { db, t.a, gaveB, gaveA } }
	for _, side in sides do
		local data = side[1]
		data.trades = data.trades or {}
		table.insert(data.trades, 1, { with = side[2].DisplayName, gave = side[3], got = side[4], at = now })
		while #data.trades > TradeService.Settings.history do
			table.remove(data.trades)
		end
	end
	-- Saved straight away, both sides.
	for _, p in { t.a, t.b } do
		local profile = Profiles.profile(p)
		if profile and not Profiles.isMock() then
			pcall(function()
				profile:Save()
			end)
		end
		Analytics.custom(p, "Trade", 1, { trade = t.id })
	end
	return true, nil
end

local function start(a: Player, b: Player): Trade
	nextId += 1
	local t: Trade = {
		id = nextId,
		a = a,
		b = b,
		offers = { [a] = {}, [b] = {} },
		ready = {},
		confirmed = {},
		version = 1,
		state = "open",
		countdownEnds = 0,
	}
	trades[a] = t
	trades[b] = t
	send(t)
	return t
end

local function canTrade(p: Player): (boolean, string?)
	if trades[p] then
		return false, "Already trading."
	end
	local untilT = cooldownUntil[p]
	if untilT and TradeService.clock() < untilT then
		return false, string.format("A moment: trading again in %d seconds.", math.ceil(untilT - TradeService.clock()))
	end
	if not Profiles.get(p) then
		return false, "Your ledger is still being opened."
	end
	return true, nil
end

-- Reads an offer from a guest's screen: { [curio id] = count }, checked for shape only here.
local function readOffer(v: unknown): Offer?
	if type(v) ~= "table" then
		return nil
	end
	local out: Offer = {}
	local kinds = 0
	for k, n in v :: { [unknown]: unknown } do
		if type(k) ~= "string" or #k > 40 or type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > TradeService.Settings.maxEach then
			return nil
		end
		kinds += 1
		if kinds > TradeService.Settings.maxKinds then
			return nil
		end
		out[k] = n
	end
	return out
end

local ASK_KEYS = { op = true, userId = true, items = true, version = true }

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 4, 1)
	if not r then
		RemoteGuard.reject(player, "tradeAsk", "malformed")
		return { ok = false, why = "That isn't part of a trade." }
	end
	for k in r do
		if not ASK_KEYS[k] then
			RemoteGuard.reject(player, "tradeAsk", "malformed")
			return { ok = false, why = "That isn't part of a trade." }
		end
	end
	local op = r.op
	local now = TradeService.clock()
	local function target(): Player?
		local id = RemoteGuard.number(r.userId, 1, 1e12, true)
		local p = id and Players:GetPlayerByUserId(id)
		return if p and p ~= player then p else nil
	end
	if op == "invite" then
		local to = target()
		if not to then
			return { ok = false, why = "They aren't in the house." }
		end
		local ok, why = canTrade(player)
		if not ok then
			return { ok = false, why = why }
		end
		if (blocked[to] or {})[player.UserId] then
			return { ok = false, why = "They aren't taking trades just now." }
		end
		local last = (lastInvite[player] or {})[to]
		if last and now - last < TradeService.Settings.inviteGap then
			return { ok = false, why = "You've just asked them." }
		end
		lastInvite[player] = lastInvite[player] or {}
		lastInvite[player][to] = now
		invites[to] = invites[to] or {}
		invites[to][player] = now
		curioEvent:FireClient(to, { op = "tradeInvite", from = player.DisplayName, userId = player.UserId })
		return { ok = true }
	elseif op == "accept" then
		local from = target()
		local at = from and (invites[player] or {})[from]
		if not from or not at or now - at > TradeService.Settings.inviteLife then
			return { ok = false, why = "That invitation has lapsed." }
		end
		invites[player][from] = nil
		local ok1, why1 = canTrade(player)
		local ok2 = canTrade(from)
		if not ok1 or not ok2 then
			return { ok = false, why = if not ok1 then why1 else "They can't trade just now." }
		end
		start(from, player)
		return { ok = true }
	elseif op == "decline" then
		local from = target()
		if from and invites[player] then
			invites[player][from] = nil
			curioEvent:FireClient(from, { op = "tradeEnd", id = 0, state = "cancelled", why = player.DisplayName .. " said no thank you." })
		end
		return { ok = true }
	elseif op == "block" or op == "report" then
		local who = target()
		if not who then
			return { ok = false }
		end
		if op == "block" then
			blocked[player] = blocked[player] or {}
			blocked[player][who.UserId] = true
			if invites[player] then
				invites[player][who] = nil
			end
		else
			local t = trades[player]
			table.insert(TradeService.reports, { from = player.UserId, about = who.UserId, trade = t and t.id, at = os.time() })
			warn(string.format("[Maison] Trade report: %s (%d) reported %s (%d)", player.Name, player.UserId, who.Name, who.UserId))
		end
		return { ok = true }
	end
	-- Everything else is about the trade this guest is in.
	local t = trades[player]
	if not t then
		return { ok = false, why = "You aren't trading." }
	end
	if op == "cancel" then
		finish(t, "cancelled", player.DisplayName .. " cancelled the trade.")
		return { ok = true }
	elseif op == "offer" then
		local offer = readOffer(r.items)
		local data = Profiles.get(player)
		if not offer or not data then
			RemoteGuard.reject(player, "tradeAsk", "malformed")
			return { ok = false, why = "That offer isn't right." }
		end
		local ok, why = holds(data, offer)
		if not ok then
			return { ok = false, why = why }
		end
		t.offers[player] = offer
		unlock(t)
		send(t)
		return { ok = true, version = t.version }
	elseif op == "ready" then
		if r.version ~= t.version or t.state ~= "open" then
			return { ok = false, why = "The offers changed: have another look." }
		end
		t.ready[player] = true
		if t.ready[t.a] and t.ready[t.b] then
			t.state = "countdown"
			t.countdownEnds = now + TradeService.Settings.countdown
		end
		send(t)
		return { ok = true }
	elseif op == "unready" then
		unlock(t)
		send(t)
		return { ok = true }
	elseif op == "confirm" then
		if r.version ~= t.version or t.state ~= "confirm" then
			return { ok = false, why = "The offers changed: have another look." }
		end
		t.confirmed[player] = true
		if t.confirmed[t.a] and t.confirmed[t.b] then
			local ok, why = swap(t)
			if ok then
				cooldownUntil[t.a] = now + TradeService.Settings.cooldown
				cooldownUntil[t.b] = now + TradeService.Settings.cooldown
				finish(t, "done", "The trade is done.")
				Curios.push(t.a)
				Curios.push(t.b)
			else
				finish(t, "cancelled", why)
			end
			return { ok = ok, why = why }
		end
		send(t)
		return { ok = true }
	end
	return { ok = false, why = "That isn't part of a trade." }
end

-- The countdown: when it ends, confirming opens (and both screens hear it).
local function tick()
	local now = TradeService.clock()
	local seen: { [Trade]: boolean } = {}
	for _, t in trades do
		if not seen[t] then
			seen[t] = true
			if t.state == "countdown" and now >= t.countdownEnds then
				t.state = "confirm"
				send(t)
			end
		end
	end
end
TradeService.tick = tick

function TradeService.history(player: Player): { any }
	local data = Profiles.get(player) :: any
	return if data and type(data.trades) == "table" then data.trades else {}
end

function TradeService.start()
	RemoteGuard.invoke(Remotes.func("TradeAsk"), "tradeAsk", function(player: Player, request: unknown): any
		if type(request) == "table" and (request :: any).op == "history" then
			return { ok = true, history = TradeService.history(player) }
		end
		return onAsk(player, request)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		local t = trades[player]
		if t then
			finish(t, "cancelled", player.DisplayName .. " left the house.")
		end
		invites[player] = nil
		lastInvite[player] = nil
		cooldownUntil[player] = nil
		blocked[player] = nil
	end)
	RunService.Heartbeat:Connect(tick)
end

return TradeService

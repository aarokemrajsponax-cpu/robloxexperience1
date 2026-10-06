--!strict
-- Curios on the server (shared Curios has the list): what each guest holds, a find at the tables
-- after a banked run (with a little Gilt for it), the achievements' and the season's own curios,
-- stars, and the Cabinet, where Gems buy the exact curio you choose at its fixed price. Gems come
-- from Gem packs (Robux, through the purchase system's receipts) and are spent only here.
--
-- Everything is decided here: a guest's screen names what it wants (a curio's id, a pack's key)
-- and never sends a price, a count or a rarity.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurioList = require(ReplicatedStorage.Shared.Curios)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Rating = require(ReplicatedStorage.Shared.Rating)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Catalog = require(script.Parent.Purchases.Catalog)
local Grants = require(script.Parent.Purchases.Grants)
local Store = require(script.Parent.Purchases.Store)

local Curios = {}

local RECENT = 12 -- the latest finds kept for the "Recent" shelf
Curios.GEM_KEYS = { "gems1", "gems2", "gems3" }
local IS_GEM_KEY: { [string]: boolean } = { gems1 = true, gems2 = true, gems3 = true }

-- The random numbers for finds (a test can make them fixed).
Curios.random = Random.new()

local curioEvent = Remotes.event("Curio")

type Store = { items: { [string]: number }, favs: { [string]: boolean }, recent: { string }, found: number, given: { [string]: boolean } }

local function bag(data: Profiles.Data): Store
	local d = data :: any
	if type(d.curios) ~= "table" then
		d.curios = { items = {}, favs = {}, recent = {}, found = 0, given = {} }
	end
	local c = d.curios
	c.items = c.items or {}
	c.favs = c.favs or {}
	c.recent = c.recent or {}
	c.found = c.found or 0
	c.given = c.given or {}
	if type(d.gems) ~= "number" then
		d.gems = 0
	end
	return c
end
Curios.bag = bag

function Curios.count(data: Profiles.Data, id: string): number
	return bag(data).items[id] or 0
end

-- What the guest's screen shows: every curio they hold, their stars, the latest finds, and Gems.
function Curios.state(data: Profiles.Data): { [string]: any }
	local b = bag(data)
	return { op = "curios", items = table.clone(b.items), favs = table.clone(b.favs), recent = table.clone(b.recent), gems = data.gems, found = b.found }
end

function Curios.push(player: Player)
	local data = Profiles.get(player)
	if data then
		curioEvent:FireClient(player, Curios.state(data))
	end
end

-- Gives `n` of a curio (a find, an event, the Cabinet, a trade). Returns false for an unknown id.
function Curios.give(player: Player?, data: Profiles.Data, id: string, n: number?, source: string?): boolean
	local c = CurioList.byId[id]
	if not c then
		return false
	end
	local b = bag(data)
	b.items[id] = (b.items[id] or 0) + (n or 1)
	local i = table.find(b.recent, id)
	if i then
		table.remove(b.recent, i)
	end
	table.insert(b.recent, 1, id)
	while #b.recent > RECENT do
		table.remove(b.recent)
	end
	if player then
		Analytics.custom(player, "Curio", n or 1, { curio = id, rarity = c.rarity, source = source or "" })
	end
	return true
end

-- Takes `n` of a curio away (a trade). False if they don't hold that many.
function Curios.take(data: Profiles.Data, id: string, n: number?): boolean
	local b = bag(data)
	local have = b.items[id] or 0
	local k = n or 1
	if have < k then
		return false
	end
	local items = b.items :: { [string]: number? }
	items[id] = if have - k > 0 then have - k else nil
	if not items[id] then
		b.favs[id] = nil
		local i = table.find(b.recent, id)
		if i then
			table.remove(b.recent, i)
		end
	end
	return true
end

-- Tells a guest's screen about a curio that came to them (the big reveal).
function Curios.announce(player: Player, id: string, line: string, gilt: number?)
	local c = CurioList.byId[id]
	if c then
		curioEvent:FireClient(player, { op = "found", id = id, line = line, gilt = gilt or 0 })
	end
end

-- After a banked run: maybe a curio among the pieces, the season's Limited, the achievements.
-- Returns what was found ({ id, name, rarity, gilt }) for the run's card, or nil.
function Curios.afterRun(player: Player, data: Profiles.Data, rounds: number, accuracy: number, roomId: string, flawless: boolean): { [string]: any }?
	local b = bag(data)
	local found: { [string]: any }? = nil
	-- The Secret: a flawless run (three rounds or more) at the Midnight Room's table, once.
	if flawless and roomId == "midnight" and rounds >= 3 and (b.items.midnightOwl or 0) == 0 then
		Curios.give(player, data, "midnightOwl", 1, "secret")
		found = { id = "midnightOwl" }
	elseif Curios.random:NextNumber() < CurioList.findChance(rounds, accuracy) then
		local c = CurioList.pick(Curios.random:NextNumber(), Curios.random:NextNumber())
		Curios.give(player, data, c.id, 1, "tables")
		found = { id = c.id }
	end
	if found then
		local c = CurioList.byId[found.id]
		b.found += 1
		found.name = c.name
		found.rarity = c.rarity
		found.gilt = Gilt.pay(player, data, CurioList.RarityGilt[c.rarity] or 0, "Curio found: " .. c.id)
	end
	-- The season's Limited curio, once, for any banked run while it's on.
	local term = Rating.term().id
	for id, season in CurioList.LimitedSeason do
		if season == term and not b.given[id] and rounds > 0 then
			b.given[id] = true
			Curios.give(player, data, id, 1, "season")
			task.defer(Curios.announce, player, id, "This season's own curio, for playing this season.")
		end
	end
	-- Achievements.
	local achieved: { [string]: boolean } = {
		firstKey = data.stats.rounds >= 100,
		hallmark = data.stats.correct >= 1000,
	}
	for id, test in achieved do
		if test and not b.given[id] then
			b.given[id] = true
			Curios.give(player, data, id, 1, "achievement")
			task.defer(Curios.announce, player, id, "An achievement: " .. CurioList.byId[id].how)
		end
	end
	if found then
		local f = found
		task.defer(function()
			Curios.announce(player, f.id, "Among the pieces, a curio.", f.gilt)
			Curios.push(player)
		end)
	else
		task.defer(Curios.push, player)
	end
	return found
end

-- Gives a curio for an event (a Gilt Rain's coin...), once per event per guest.
function Curios.forEvent(player: Player, id: string, eventKey: string): boolean
	local data = Profiles.get(player)
	if not data then
		return false
	end
	local b = bag(data)
	local mark = "event:" .. eventKey
	if b.given[mark] then
		return false
	end
	b.given[mark] = true
	if not Curios.give(player, data, id, 1, "event") then
		return false
	end
	Curios.announce(player, id, "From tonight's event.")
	Curios.push(player)
	return true
end

-- The Cabinet: every curio sold for Gems, and the Gem packs with Roblox's live prices.
function Curios.cabinet(): { [string]: any }
	local items = {}
	for _, c in CurioList.List do
		if c.source == "gems" and c.gems then
			table.insert(items, { id = c.id, gems = c.gems })
		end
	end
	local packs = {}
	for _, key in Curios.GEM_KEYS do
		local e = ProductConfig.byKey[key]
		table.insert(packs, { key = key, name = e.Name, gems = e.Reward.Amount, robux = Catalog.price(key) or e.Pricing.ReferencePrice, ready = Catalog.enabled(key) })
	end
	return { items = items, packs = packs }
end

-- Buys a curio from the Cabinet for Gems.
function Curios.buy(player: Player, data: Profiles.Data, id: string): { [string]: any }
	local c = CurioList.byId[id]
	if not c or c.source ~= "gems" or not c.gems then
		return { ok = false, why = "That isn't sold in the Cabinet." }
	end
	local price = c.gems :: number
	if data.gems < price then
		return { ok = false, why = string.format("Not enough Gems yet: %d more.", price - data.gems) }
	end
	data.gems -= price
	Curios.give(player, data, id, 1, "gems")
	Analytics.sink(player, "Gems", price, data.gems, "curio_" .. id)
	Curios.push(player)
	return { ok = true, gems = data.gems }
end

local function gemsGrant(ctx: Grants.Context)
	local amount = ctx.product.Reward.Amount :: number
	local d = ctx.data :: any
	d.gems = (if type(d.gems) == "number" then d.gems else 0) + amount
	ctx:after(function()
		Curios.push(ctx.player)
		curioEvent:FireClient(ctx.player, { op = "gems", amount = amount, gems = d.gems })
	end)
end

local ASK_KEYS = { op = true, id = true, on = true, key = true }

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 4, 0)
	if not r then
		RemoteGuard.reject(player, "curioAsk", "malformed")
		return { ok = false, why = "That isn't something the Cabinet does." }
	end
	for k in r do
		if not ASK_KEYS[k] then
			RemoteGuard.reject(player, "curioAsk", "malformed")
			return { ok = false, why = "That isn't something the Cabinet does." }
		end
	end
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	if r.op == "state" then
		local s = Curios.state(data)
		s.ok = true
		s.cabinet = Curios.cabinet()
		return s
	elseif r.op == "fav" then
		local id = RemoteGuard.string(r.id, 40)
		if not id or Curios.count(data, id) <= 0 then
			return { ok = false, why = "You don't hold that one." }
		end
		local favs = bag(data).favs :: { [string]: boolean? }
		favs[id] = if r.on == true then true else nil
		return { ok = true }
	elseif r.op == "buy" then
		local id = RemoteGuard.string(r.id, 40)
		if not id then
			return { ok = false, why = "That isn't sold in the Cabinet." }
		end
		return Curios.buy(player, data, id)
	elseif r.op == "gems" then
		local key = RemoteGuard.oneOf(r.key, IS_GEM_KEY)
		if not key then
			return { ok = false, why = "That isn't a Gem pack." }
		end
		local ok, why = Store.prompt(player, key, "cabinet")
		return { ok = ok, why = why, prompted = ok }
	end
	return { ok = false, why = "That isn't something the Cabinet does." }
end

function Curios.start()
	Grants.register("gems", gemsGrant)
	RemoteGuard.invoke(Remotes.func("CurioAsk"), "curioAsk", onAsk)
	local function hello(player: Player)
		task.spawn(function()
			local data = Profiles.wait(player, 30)
			if data and player.Parent then
				curioEvent:FireClient(player, Curios.state(data))
			end
		end)
	end
	Players.PlayerAdded:Connect(hello)
	for _, p in Players:GetPlayers() do
		hello(p)
	end
end

return Curios

--!strict
-- The brainrots on the server (shared/Brainrots has the numbers): each guest's squad, the one
-- walking beside them, the best mutation of each, and the tip jar the squad fills with Gilt every
-- hour. Kept in the guest's curio page (Curios.bag(data).squad).
--
-- AFK mode: out of the game, the squad earns a fifth of its rate for up to twelve hours
-- (shared Brainrots.offline). When they were last here is saved once a minute (`seen`); the first
-- time the jar is settled in a session, the time from then to now is paid at the offline share,
-- and told to their screen as they arrive.
--
-- Everything is decided here: a guest's screen names a brainrot (its id) or a product (its key)
-- and never sends an amount, a rate, a star or a mutation. The jar is worked out from the saved
-- time it was last settled and the squad's rate since, never from anything a screen says.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local BrainrotList = require(ReplicatedStorage.Shared.Brainrots)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local Curios = require(script.Parent.Curios)
local Catalog = require(script.Parent.Purchases.Catalog)
local Grants = require(script.Parent.Purchases.Grants)
local Store = require(script.Parent.Purchases.Store)

local Brainrots = {}

-- The clock (a test can set it).
Brainrots.now = function(): number
	return os.time()
end

export type Squad = {
	ids: { string },
	walk: string?,
	mut: { [string]: string },
	held: number, -- Gilt in the jar when it was last settled
	at: number, -- when that was
	wing: boolean, -- the Brainrot Penthouse
	full: boolean?, -- told the jar is full (so it's said once)
	boostUntil: number?, -- a Meme Frenzy (or a Full Jar booster), until then
	boostMult: number?,
	boosts: { [string]: { untilAt: number, pct: number, id: string } }?, -- (Build 88) boosters on
	boostDay: number?, -- the day boostUsed is for
	boostUsed: { [string]: boolean }?, -- which brainrots have given their boost today
	seen: number?, -- the last minute the guest was known to be in the game
}

-- The profiles settled in this server since they arrived (their offline time is paid once), and
-- what that paid ({ gilt, seconds }).
local live: { [any]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local awayOf: { [any]: { gilt: number, seconds: number } } = setmetatable({}, { __mode = "k" }) :: any

local curioEvent = Remotes.event("Curio")

local function held(data: Profiles.Data, id: string): number
	return Curios.count(data, id)
end

-- The guest's squad, tidied: only brainrots they still hold, each once, never more than fit.
local function squadOf(data: Profiles.Data): Squad
	local b = Curios.bag(data) :: any
	if type(b.squad) ~= "table" then
		b.squad = {}
	end
	local s = b.squad
	s.ids = if type(s.ids) == "table" then s.ids else {}
	s.mut = if type(s.mut) == "table" then s.mut else {}
	s.held = if type(s.held) == "number" and s.held == s.held then math.max(0, s.held) else 0
	s.at = if type(s.at) == "number" then s.at else Brainrots.now()
	s.wing = s.wing == true
	local seen: { [string]: boolean } = {}
	for i = #s.ids, 1, -1 do
		local id = s.ids[i]
		if type(id) ~= "string" or seen[id] or not BrainrotList.is(id) or held(data, id) <= 0 then
			table.remove(s.ids, i)
		else
			seen[id] = true
		end
	end
	if type(s.walk) ~= "string" or not seen[s.walk] then
		s.walk = s.ids[1]
	end
	for id, m in s.mut do
		if held(data, id) <= 0 or not BrainrotList.Mutations[m] then
			s.mut[id] = nil
		end
	end
	return s :: Squad
end
Brainrots.squadOf = squadOf

-- Places in the squad: three, six with the Penthouse.
function Brainrots.slots(data: Profiles.Data): number
	return BrainrotList.SLOTS + (if squadOf(data).wing then BrainrotList.WING_SLOTS else 0)
end

-- Gilt an hour from the whole squad.
function Brainrots.rate(data: Profiles.Data): number
	local s = squadOf(data)
	local total = 0
	for i, id in s.ids do
		if i > Brainrots.slots(data) then
			break
		end
		total += BrainrotList.rate(id, held(data, id), s.mut[id])
	end
	return total
end

-- Brings the jar up to now at the squad's rate so far (before the squad or its stars change).
function Brainrots.settle(data: Profiles.Data)
	local s = squadOf(data)
	local now = Brainrots.now()
	local rate = Brainrots.rate(data)
	if not live[data] then
		-- The first settle this session: in the game (full rate) until last seen, then away.
		live[data] = true
		local seen = if type(s.seen) == "number" then s.seen else s.at
		local from = math.clamp(seen, s.at, math.max(s.at, now))
		s.held = BrainrotList.jar(s.held, rate, s.at, from, s.boostUntil, s.boostMult)
		local before = s.held
		s.held = BrainrotList.offline(s.held, rate, now - from)
		awayOf[data] = { gilt = s.held - before, seconds = math.max(0, now - from) }
	else
		s.held = BrainrotList.jar(s.held, rate, s.at, now, s.boostUntil, s.boostMult)
	end
	s.at = now
	s.seen = now
	if s.boostUntil and s.boostUntil <= now then
		s.boostUntil = nil
		s.boostMult = nil
	end
end


-- What AFK mode paid as this guest arrived ({ gilt, seconds }), or nil.
function Brainrots.away(data: Profiles.Data): { gilt: number, seconds: number }?
	return awayOf[data]
end

-- Forgets that a profile was settled this session (a test's way to leave and come back).
function Brainrots.forget(data: Profiles.Data)
	live[data] = nil
	awayOf[data] = nil
end

-- The one walking beside them, on their character for every screen to draw.
function Brainrots.dress(player: Player, data: Profiles.Data)
	local s = squadOf(data)
	local id = s.walk
	if id then
		local n = held(data, id)
		player:SetAttribute("Brainrot", id)
		player:SetAttribute("BrainrotMut", s.mut[id])
		player:SetAttribute("BrainrotStars", BrainrotList.stars(n))
		player:SetAttribute("BrainrotRate", BrainrotList.rate(id, n, s.mut[id]))
	else
		player:SetAttribute("Brainrot", nil)
		player:SetAttribute("BrainrotMut", nil)
		player:SetAttribute("BrainrotStars", nil)
		player:SetAttribute("BrainrotRate", nil)
	end
	-- (Build 105) The rest of the squad walks behind them too: every place they have (three, six
	-- with the Brainrot Penthouse), each "id:mutation:stars", for every screen to draw. Only the
	-- one beside them adds its bonus to a run; the others are there to be seen.
	local others: { string } = {}
	for i, other in s.ids do
		if i > Brainrots.slots(data) then
			break
		end
		if other ~= id then
			table.insert(others, string.format("%s:%s:%d", other, s.mut[other] or "", BrainrotList.stars(held(data, other))))
		end
	end
	player:SetAttribute("BrainrotSquad", if #others > 0 then table.concat(others, ";") else nil)
end

-- What the guest's screen shows (inside the curio state): the squad, the jar and the prices.
-- (Build 88) A booster of `kind` on now: its strength (percent), or 0.
function Brainrots.boostOf(data: Profiles.Data, kind: string): number
	local s = squadOf(data) :: any
	local b = type(s.boosts) == "table" and s.boosts[kind] or nil
	if type(b) == "table" and type(b.untilAt) == "number" and b.untilAt > Brainrots.now() then
		return tonumber(b.pct) or 0
	end
	return 0
end

-- The boosters on now, for the guest's screen: { kind, pct, id, left }.
local function boostList(data: Profiles.Data): { { [string]: any } }
	local s = squadOf(data) :: any
	local out = {}
	local now = Brainrots.now()
	for _, kind in BrainrotList.ABILITY_ORDER do
		local b = type(s.boosts) == "table" and s.boosts[kind] or nil
		if type(b) == "table" and type(b.untilAt) == "number" and b.untilAt > now then
			table.insert(out, { kind = kind, pct = b.pct, id = b.id, left = b.untilAt - now })
		end
	end
	return out
end

-- Which brainrots have given their boost today.
local function usedToday(data: Profiles.Data): { [string]: boolean }
	local s = squadOf(data) :: any
	local day = Brainrots.now() // 86400
	if s.boostDay ~= day or type(s.boostUsed) ~= "table" then
		s.boostDay = day
		s.boostUsed = {}
	end
	return s.boostUsed
end

-- What the boosters do to the guest's character: Light Feet as their "BoostFeet" attribute (the
-- house's pace reads it; the attractions never do). Called on arrival and as boosters end.
function Brainrots.applyBoosts(player: Player, data: Profiles.Data)
	local feet = Brainrots.boostOf(data, "feet")
	player:SetAttribute("BoostFeet", if feet > 0 then 1 + feet / 100 else nil)
end

-- Calls on a brainrot in the squad for its booster: once a day each, never a weaker one over a
-- stronger one of its kind.
function Brainrots.boost(player: Player, data: Profiles.Data, id: string?): { [string]: any }
	if not id or not BrainrotList.is(id) or held(data, id) <= 0 then
		return { ok = false, why = "You don't hold that brainrot." }
	end
	local s = squadOf(data) :: any
	if not table.find(s.ids, id) then
		return { ok = false, why = "Only a brainrot in your squad can boost you: put it in first." }
	end
	local used = usedToday(data)
	if used[id] then
		return { ok = false, why = "It has given its boost today. Tomorrow it can again." }
	end
	local kind, pct = BrainrotList.ability(id)
	local a = BrainrotList.Abilities[kind]
	local now = Brainrots.now()
	if type(s.boosts) ~= "table" then
		s.boosts = {}
	end
	local cur = s.boosts[kind]
	if type(cur) == "table" and type(cur.untilAt) == "number" and cur.untilAt > now and (tonumber(cur.pct) or 0) >= pct then
		return { ok = false, why = string.format("A %s as strong or stronger is on already: save this one for later.", a.name) }
	end
	if kind == "jar" then
		Brainrots.settle(data)
		local mult = 1 + pct / 100
		if s.boostUntil and s.boostUntil > now and (s.boostMult or 1) >= mult then
			return { ok = false, why = "A Meme Frenzy is filling the jar faster already: save this one for later." }
		end
		s.boostUntil = now + BrainrotList.BOOST_SECONDS
		s.boostMult = mult
	end
	s.boosts[kind] = { untilAt = now + BrainrotList.BOOST_SECONDS, pct = pct, id = id }
	used[id] = true
	Brainrots.applyBoosts(player, data)
	return { ok = true, kind = kind, pct = pct, seconds = BrainrotList.BOOST_SECONDS }
end

function Brainrots.state(data: Profiles.Data): { [string]: any }
	Brainrots.settle(data)
	local s = squadOf(data)
	local rate = Brainrots.rate(data)
	local prices = {}
	for _, key in ProductConfig.Brainrot do
		prices[key] = if Catalog.enabled(key) then Catalog.price(key) or ProductConfig.byKey[key].Pricing.ReferencePrice else nil
	end
	return {
		ids = table.clone(s.ids),
		walk = s.walk,
		mut = table.clone(s.mut),
		held = math.floor(s.held),
		rate = rate,
		cap = math.max(math.floor(s.held), rate * BrainrotList.JAR_HOURS),
		slots = Brainrots.slots(data),
		wing = s.wing,
		feast = rate * BrainrotList.JAR_HOURS,
		prices = prices,
		frenzy = if s.boostUntil then math.max(0, s.boostUntil - Brainrots.now()) else nil,
		frenzyMult = s.boostMult,
		boosts = boostList(data),
		boosted = table.clone(usedToday(data)),
	}
end

local function push(player: Player, data: Profiles.Data)
	Brainrots.dress(player, data)
	Curios.push(player)
end

-- The Meme Frenzy (a Meme Takeover just played): the squad earns double for a quarter of an hour.
-- A second one while it's on runs on from where the first ends.
function Brainrots.frenzy(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	Brainrots.settle(data)
	local s = squadOf(data)
	local now = Brainrots.now()
	-- (A frenzy runs on from another frenzy; over a weaker Full Jar it starts now.)
	local from = if (s.boostMult or 0) >= BrainrotList.FRENZY_MULT then math.max(now, s.boostUntil or now) else now
	local untilTime = from + BrainrotList.FRENZY_SECONDS
	-- (Build 96: over a stronger boost still running, a Squad Overtime, it keeps that strength.)
	local stronger = if s.boostUntil and s.boostUntil > now then s.boostMult or 0 else 0
	s.boostUntil = untilTime
	s.boostMult = math.max(BrainrotList.FRENZY_MULT, stronger)
	push(player, data)
	curioEvent:FireClient(player, { op = "frenzy", seconds = untilTime - now, mult = BrainrotList.FRENZY_MULT })
end

-- (Build 96) Squad Overtime, a Gilt booster (server/Boosters): the squad fills its jar `mult`
-- times as fast for `seconds`. Over the same strength it runs on from where that ends (at most
-- `cap` seconds ahead); over a weaker one it starts now; while a stronger one runs it's refused
-- (nil). Returns when it ends.
function Brainrots.overtime(player: Player, data: Profiles.Data, mult: number, seconds: number, cap: number): number?
	Brainrots.settle(data)
	local s = squadOf(data)
	local now = Brainrots.now()
	local running = s.boostUntil ~= nil and (s.boostUntil :: number) > now
	if running and (s.boostMult or 0) > mult then
		return nil
	end
	local from = if running and (s.boostMult or 0) == mult then s.boostUntil :: number else now
	local untilTime = math.min(now + cap, from + seconds)
	s.boostUntil = untilTime
	s.boostMult = mult
	push(player, data)
	curioEvent:FireClient(player, { op = "frenzy", seconds = untilTime - now, mult = mult, overtime = true })
	return untilTime
end

-- A brainrot just came to a guest (a find, a parade, a trade): into the squad if there's room.
function Brainrots.arrived(player: Player?, data: Profiles.Data, id: string)
	if not BrainrotList.is(id) then
		return
	end
	local s = squadOf(data)
	if not table.find(s.ids, id) and #s.ids < Brainrots.slots(data) then
		table.insert(s.ids, id)
		s.walk = s.walk or id
	end
	if player then
		Brainrots.dress(player, data)
	end
end

-- After a find at the tables: maybe a mutation (kept if it's better than the one held).
function Brainrots.mutate(data: Profiles.Data, id: string, x: number): string?
	if not BrainrotList.is(id) then
		return nil
	end
	local m = BrainrotList.roll(x)
	if not m then
		return nil
	end
	local s = squadOf(data)
	if BrainrotList.better(m, s.mut[id]) then
		Brainrots.settle(data)
		s.mut[id] = m
	end
	return m
end

-- A mutation given outright (a Lucky Box's): kept if it's better than the one held.
function Brainrots.giveMutation(data: Profiles.Data, id: string, m: string?): string?
	if not m or not BrainrotList.is(id) or not BrainrotList.Mutations[m] then
		return nil
	end
	local s = squadOf(data)
	if BrainrotList.better(m, s.mut[id]) then
		Brainrots.settle(data)
		s.mut[id] = m
	end
	return m
end

-- The walking one's bonus on a banked run's Gilt: paid on top, and what it was ({ id, gilt }).
function Brainrots.runBonus(player: Player, data: Profiles.Data, base: number): { [string]: any }?
	local s = squadOf(data)
	local id = s.walk
	if not id or base <= 0 then
		return nil
	end
	local share = BrainrotList.runBonus(id, held(data, id), s.mut[id])
	local extra = math.floor(base * share + 0.5)
	if extra <= 0 then
		return nil
	end
	local paid = Gilt.pay(player, data, extra, "Brainrot bonus: " .. id)
	return { id = id, gilt = paid, share = share }
end

-- Collects the jar: its whole Gilt, paid as it is (no boost, no daily cap: it's the squad's own).
function Brainrots.collect(player: Player, data: Profiles.Data): { [string]: any }
	Brainrots.settle(data)
	local s = squadOf(data)
	local n = math.floor(s.held)
	if n <= 0 then
		return { ok = false, why = if #s.ids == 0 then "Put a brainrot in your squad and it fills the jar every hour." else "The jar is empty: your squad fills it every hour." }
	end
	s.held -= n
	s.full = nil
	Gilt.give(player, data, n, "Brainrots")
	push(player, data)
	return { ok = true, gilt = n }
end

local function grant(ctx: Grants.Context)
	local data = ctx.data
	local reward = ctx.product.Reward
	local s = squadOf(data)
	local player = ctx.player
	if reward.Type == "BrainrotSlots" then
		Brainrots.settle(data)
		s.wing = true
		ctx:after(function()
			push(player, data)
			curioEvent:FireClient(player, { op = "penthouse", slots = Brainrots.slots(data) })
		end)
	elseif reward.Type == "BrainrotFeast" then
		Brainrots.settle(data)
		local hours = tonumber(reward.Hours) or BrainrotList.JAR_HOURS
		local amount = math.floor(Brainrots.rate(data) * hours)
		data.gilt += amount
		ctx:after(function()
			Analytics.source(player, "Gilt", amount, data.gilt, "Brainrot Feast")
			Gilt.changed(player)
			Gilt.earned(player, amount)
			push(player, data)
			curioEvent:FireClient(player, { op = "feast", gilt = amount })
		end)
	else
		error("not a brainrot product: " .. tostring(reward.Type))
	end
end

-- The squad's requests (CurioAsk): place, take out, walk, collect, and the two products.
local function onOp(player: Player, data: Profiles.Data, r: { [string]: any }): { [string]: any }
	local op = r.op
	local id = if type(r.id) == "string" and #r.id <= 40 then r.id else nil
	if op == "summon" then
		-- (Build 94) In Steal a Luxe, the Basement or the Executive Suite the brainrot and the
		-- companion step aside; this calls them back in (on = true) for this visit, or sends them
		-- away again. Only there: anywhere else they're always beside the guest.
		local a = player:GetAttribute(AttractionList.ATTRIBUTE)
		if type(a) ~= "string" or not AttractionList.HIDES_COMPANIONS[a] then
			return { ok = false, why = "Your brainrot is already beside you here." }
		end
		player:SetAttribute(AttractionList.COMPANIONS_IN, if r.on == true then a else nil)
		return { ok = true, shown = r.on == true }
	elseif op == "squadAdd" then
		if not id or not BrainrotList.is(id) or held(data, id) <= 0 then
			return { ok = false, why = "You don't hold that brainrot." }
		end
		local s = squadOf(data)
		if table.find(s.ids, id) then
			return { ok = false, why = "It's already in your squad." }
		end
		if #s.ids >= Brainrots.slots(data) then
			return { ok = false, why = "Your squad is full: take one out first.", full = true }
		end
		Brainrots.settle(data)
		table.insert(s.ids, id)
		s.walk = s.walk or id
		push(player, data)
		return { ok = true }
	elseif op == "squadRemove" then
		local s = squadOf(data)
		local i = if id then table.find(s.ids, id) else nil
		if not i then
			return { ok = false, why = "That one isn't in your squad." }
		end
		Brainrots.settle(data)
		table.remove(s.ids, i)
		if s.walk == id then
			s.walk = s.ids[1]
		end
		push(player, data)
		return { ok = true }
	elseif op == "walk" then
		local s = squadOf(data)
		if id ~= nil and not table.find(s.ids, id) then
			return { ok = false, why = "Only one in your squad can walk with you." }
		end
		s.walk = id
		push(player, data)
		return { ok = true }
	elseif op == "collect" then
		return Brainrots.collect(player, data)
	elseif op == "boost" then
		local r2 = Brainrots.boost(player, data, id)
		if r2.ok then
			push(player, data)
		end
		return r2
	elseif op == "brainrotBuy" then
		local key = if r.key == "brainrotFeast" or r.key == "brainrotPenthouse" then r.key else nil
		if not key then
			return { ok = false, why = "That isn't something the squad sells." }
		end
		local ok, why = Store.prompt(player, key, "brainrots")
		return { ok = ok, why = why, prompted = ok }
	end
	return { ok = false, why = "That isn't something the Cabinet does." }
end

function Brainrots.start()
	Grants.register("brainrot", grant)
	Store.eligibility.brainrotPenthouse = function(_player: Player, data: Profiles.Data): (boolean, string?)
		if squadOf(data).wing then
			return false, "You already have the Brainrot Penthouse."
		end
		return true, nil
	end
	Store.eligibility.brainrotFeast = function(_player: Player, data: Profiles.Data): (boolean, string?)
		if Brainrots.rate(data) <= 0 then
			return false, "Put a brainrot in your squad first: the Feast pays eight hours of what it earns."
		end
		return true, nil
	end
	for _, op in { "squadAdd", "squadRemove", "walk", "collect", "brainrotBuy", "boost", "summon" } do
		Curios.ops[op] = onOp
	end
	Curios.squadState = Brainrots.state
	-- Before a curio count changes (a find, a trade): the jar is settled at the old rate.
	Curios.changing = Brainrots.settle
	Curios.arrived = Brainrots.arrived
	Curios.mutate = Brainrots.mutate
	-- Each guest's walker on arrival, and what the squad earned while they were away.
	local function hello(player: Player)
		task.spawn(function()
			local data = Profiles.wait(player, 30)
			if not data or not player.Parent then
				return
			end
			Brainrots.settle(data)
			Brainrots.dress(player, data)
			Brainrots.applyBoosts(player, data)
			local s = squadOf(data)
			local away = Brainrots.away(data)
			local rate = Brainrots.rate(data)
			if #s.ids > 0 and s.held >= 1 then
				curioEvent:FireClient(player, {
					op = "away",
					gilt = math.floor(s.held), -- in the jar now
					offline = if away then math.floor(away.gilt) else 0, -- of it, earned in AFK mode
					seconds = if away then away.seconds else 0,
					rate = rate,
					offlineRate = BrainrotList.offlineRate(rate),
				})
			end
		end)
	end
	Players.PlayerAdded:Connect(hello)
	for _, p in Players:GetPlayers() do
		hello(p)
	end
	-- (Build 88) Boosters end on time: Light Feet comes off the character the moment it's over.
	task.spawn(function()
		while true do
			task.wait(5)
			for _, p in Players:GetPlayers() do
				local data = Profiles.get(p)
				if data and p:GetAttribute("BoostFeet") ~= nil then
					pcall(Brainrots.applyBoosts, p, data)
				end
			end
		end
	end)
	-- Once a minute: a full jar is said, once, so nothing is wasted.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = Profiles.get(player)
				if data then
					local s = squadOf(data)
					local rate = Brainrots.rate(data)
					-- Still here: the time until now was in the game (paid in full when settled).
					if live[data] then
						s.seen = Brainrots.now()
					end
					if rate > 0 and not s.full and BrainrotList.jar(s.held, rate, s.at, Brainrots.now(), s.boostUntil, s.boostMult) >= rate * BrainrotList.JAR_HOURS then
						s.full = true
						curioEvent:FireClient(player, { op = "jarFull", gilt = math.floor(rate * BrainrotList.JAR_HOURS) })
					end
				end
			end
		end
	end)
end


return Brainrots

--!strict
-- The brainrots on the server (shared/Brainrots has the numbers): each guest's squad, the one
-- walking beside them, the best mutation of each, and the tip jar the squad fills with Gilt every
-- hour, even while they're away. Kept in the guest's curio page (Curios.bag(data).squad).
--
-- Everything is decided here: a guest's screen names a brainrot (its id) or a product (its key)
-- and never sends an amount, a rate, a star or a mutation. The jar is worked out from the saved
-- time it was last settled and the squad's rate since, never from anything a screen says.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	boostUntil: number?, -- a Meme Frenzy, until then
	boostMult: number?,
}

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
	s.held = BrainrotList.jar(s.held, Brainrots.rate(data), s.at, now, s.boostUntil, s.boostMult)
	s.at = now
	if s.boostUntil and s.boostUntil <= now then
		s.boostUntil = nil
		s.boostMult = nil
	end
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
end

-- What the guest's screen shows (inside the curio state): the squad, the jar and the prices.
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
	local untilTime = math.max(now, s.boostUntil or now) + BrainrotList.FRENZY_SECONDS
	s.boostUntil = untilTime
	s.boostMult = BrainrotList.FRENZY_MULT
	push(player, data)
	curioEvent:FireClient(player, { op = "frenzy", seconds = untilTime - now, mult = BrainrotList.FRENZY_MULT })
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
	if op == "squadAdd" then
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
	for _, op in { "squadAdd", "squadRemove", "walk", "collect", "brainrotBuy" } do
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
			local s = squadOf(data)
			if #s.ids > 0 and s.held >= 1 then
				curioEvent:FireClient(player, { op = "away", gilt = math.floor(s.held), rate = Brainrots.rate(data) })
			end
		end)
	end
	Players.PlayerAdded:Connect(hello)
	for _, p in Players:GetPlayers() do
		hello(p)
	end
	-- Once a minute: a full jar is said, once, so nothing is wasted.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				local data = Profiles.get(player)
				if data then
					local s = squadOf(data)
					local rate = Brainrots.rate(data)
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

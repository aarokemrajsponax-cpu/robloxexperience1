--!strict
-- Luxury Island on the server (shared/Island has the plan; IslandBuild builds it). Everything is
-- the server's: whether a guest holds the Island Key (a wealth rank reached, and the key bought
-- for Gilt or Gems at the Jet Lounge, both shown before anyone pays), the day's pearls on the
-- lagoon's floor (the same five for everyone, each brought up once a day by a guest who is truly
-- in the water beside it), the sunset toast at the Lookout (once a day; a little more for each
-- friend toasting together, for both of them), the postcard spots, the summit path, the liveries
-- and the island's lights each guest owns and chooses, the Pearl Exchange (the island's own Suite
-- pieces, for pearls) and Island Standing. Nothing a guest's screen says is a reward, a price or
-- a place.
--
-- (Build 103) The island's rewards are fixed sums, each limited by design (a pearl once a day, the
-- toast once a day, the postcards and each Standing rank once ever), so they're paid in full as
-- prizes: what the Jet Lounge's card shows (Island.state's `rewards`) is exactly what's paid.
-- Standing counts the days flown in, not every flight. The island's waters have an unseen edge,
-- and anyone carried out past it is flown home. The summit path takes anyone up to the Sunset
-- Lookout and down again.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local FortuneRules = require(ReplicatedStorage.Shared.Fortune)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Names = require(ReplicatedStorage.Shared.Names)
local Plan = require(ReplicatedStorage.Shared.Island)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Fortune = require(script.Parent.Parent.Fortune)
local Types = require(script.Parent.Types)
local IslandRides = require(script.Parent.IslandRides)
local IslandBuild = require(script.Parent.IslandBuild)

local Island = {}

---------------------------------------------------------------------------------------------------
-- Hooks (set by Main)
---------------------------------------------------------------------------------------------------
-- Whether two guests are friends on Roblox (Friends: cached, never asked mid-toast).
Island.friends = function(_a: Player, _b: Player): boolean
	return false
end
-- The two Robux liveries: whether a livery's product is on sale, and opening its purchase window.
Island.liveryOnSale = function(_product: string): boolean
	return false
end
Island.offerLivery = function(_player: Player, _product: string): (boolean, string?)
	return false, "That isn't on sale yet."
end
-- A guest's Suite pieces changed (the Boutique tells their screen).
Island.ownedChanged = function(_player: Player) end

-- A toast raised at the Lookout in the last few minutes: who, when, and how many friends' toasts
-- it has been paid for so far (counted at most TOAST_FRIENDS_MOST).
type Toast = { player: Player, at: number, friends: number }

local built: IslandBuild.Built? = nil
local toasts: { Toast } = {}
local now = os.time
Island.now = now

local function cfg(ctx: Types.Ctx): { [string]: any }
	return ctx.cfg(Plan.ID)
end

local function num(v: any, default: number): number
	return if type(v) == "number" then v else default
end

local function keyRank(ctx: Types.Ctx): number
	return num(cfg(ctx).keyRank, Plan.KEY_RANK)
end
local function keyGilt(ctx: Types.Ctx): number
	return num(cfg(ctx).keyGilt, Plan.KEY_GILT)
end
local function keyGems(ctx: Types.Ctx): number
	return num(cfg(ctx).keyGems, Plan.KEY_GEMS)
end

-- (Build 103) The island's rewards, the very sums paid (shared/Island; Config can change them).
export type Rewards = { pearl: number, pearlSet: number, toast: number, toastFriend: number, toastFriendsMost: number, toastMinutes: number, postcards: number }
local function rewards(ctx: Types.Ctx): Rewards
	local c = cfg(ctx)
	-- (Build 104: each at the house's scale, as shown on the card and as paid.)
	local function sum(v: any, default: number): number
		return FortuneRules.scaled(math.max(0, math.floor(num(v, default))))
	end
	return {
		pearl = sum(c.pearlGilt, Plan.PEARL_GILT),
		pearlSet = sum(c.pearlSetGilt, Plan.PEARL_SET_GILT),
		toast = sum(c.toastGilt, Plan.TOAST_GILT),
		toastFriend = sum(c.toastFriendGilt, Plan.TOAST_FRIEND),
		toastFriendsMost = Plan.TOAST_FRIENDS_MOST,
		toastMinutes = math.max(1, math.floor(Plan.TOAST_WINDOW / 60 + 0.5)),
		postcards = sum(c.postcardsGilt, Plan.POSTCARDS_GILT),
	}
end
Island.rewards = rewards

-- A guest's page of the island, tidied (made on first asking). Every field has a safe default, so
-- a record from any earlier build reads the same.
local function page(ctx: Types.Ctx, data: any): { [string]: any }
	local p = ctx.saved(data, Plan.ID)
	if type(p.liveries) ~= "table" then
		p.liveries = {}
	end
	if type(p.themes) ~= "table" then
		p.themes = {}
	end
	if type(p.postcards) ~= "table" then
		p.postcards = {}
	end
	if type(p.pearlTaken) ~= "table" then
		p.pearlTaken = {}
	end
	p.liveries.ivory = true
	p.liveries.noir = true
	p.themes.golden = true
	if type(p.livery) ~= "string" or not Plan.liveryById[p.livery] then
		p.livery = "ivory"
	end
	if type(p.theme) ~= "string" or not Plan.themeById[p.theme] then
		p.theme = "golden"
	end
	p.pearls = math.max(0, num(p.pearls, 0))
	p.pearlsAll = math.max(0, num(p.pearlsAll, 0))
	p.flights = math.max(0, num(p.flights, 0))
	p.sunsetsAll = num(p.sunsetsAll, 0) -- (Build 90) sunsets toasted, all told (counted from Build 90)
	p.standingPaid = math.max(1, num(p.standingPaid, 1)) -- the highest Island Standing rank paid
	if type(p.flightDays) ~= "number" then
		-- (Build 103) Standing counts the days flown in from now on. The flights in a record from
		-- before go on counting as they always did (one each), set once here and never added to:
		-- nobody's standing, rank or Gilt paid changes for the new rule, and nothing is paid twice.
		p.flightDays = 0
		p.flightsBefore = p.flights
	end
	p.flightsBefore = math.max(0, num(p.flightsBefore, 0))
	-- (A new day: the day's pearls are new.)
	local today = Plan.day(Island.now())
	if p.pearlDay ~= today then
		p.pearlDay = today
		p.pearlTaken = {}
	end
	return p
end
Island.page = page

local function rankReached(data: any): number
	return num(Fortune.page(data).rank, 1)
end

local function publish(player: Player, p: { [string]: any })
	player:SetAttribute("JetLivery", p.livery)
	player:SetAttribute("IslandTheme", p.theme)
end

-- (Build 103) Stands a guest up from any seat (a lounger, a bench, a car) before the house moves
-- them to or from the island: a seat is joined to whoever sits in it, and would come with them.
local function unseat(player: Player)
	pcall(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local seat = humanoid.SeatPart
		if seat then
			local weld = seat:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
		end
		humanoid.Sit = false
	end)
end
Island.unseat = unseat

---------------------------------------------------------------------------------------------------
-- (Build 90) Island Standing
---------------------------------------------------------------------------------------------------
local function postcardCount(p: { [string]: any }): number
	local n = 0
	for _ in p.postcards do
		n += 1
	end
	return n
end

local function standingPoints(p: { [string]: any }): number
	return Plan.standingPoints(p.pearlsAll, p.sunsetsAll, postcardCount(p), p.flightDays + p.flightsBefore)
end

-- After any island deed: a rank reached pays its Gilt (each rank once, ever) and opens what comes
-- with it, and the guest's screen is told (the house too, from Islander up).
local function standingCheck(ctx: Types.Ctx, player: Player, p: { [string]: any })
	local rank = Plan.standingOf(standingPoints(p))
	while p.standingPaid < rank do
		p.standingPaid += 1
		local r = Plan.Standing[p.standingPaid]
		local gilt = if r.gilt > 0 then ctx.prize(player, FortuneRules.scaled(r.gilt), "Island Standing: " .. r.name) else 0
		ctx.send(player, { op = "islandStanding", rank = p.standingPaid, name = r.name, line = r.line, gilt = gilt })
		if p.standingPaid >= 3 then
			ctx.herald(player, { kind = "island", title = "ISLAND STANDING", line = "reached Island Standing: " .. r.name, glyph = "🏝️" })
		end
	end
	-- (What standing alone opens.)
	local opened = math.max(rank, p.standingPaid)
	for _, t in Plan.Themes do
		if t.standing and opened >= t.standing then
			p.themes[t.id] = true
		end
	end
	for _, l in Plan.Liveries do
		if l.standing and opened >= l.standing then
			p.liveries[l.id] = true
		end
	end
end
Island.standingCheck = standingCheck

---------------------------------------------------------------------------------------------------
-- What a guest's screen is told
---------------------------------------------------------------------------------------------------
-- Whether a guest stands in the Jet Lounge's room (where the jet boards), in no attraction.
local function inLounge(ctx: Types.Ctx, player: Player): boolean
	local def = AttractionList.byId[Plan.ID]
	local root = ctx.rootOf(player)
	return def ~= nil and root ~= nil and ctx.inside(player) == nil and (Layout.zoneAt(root.CFrame.Position) :: any) == def.room
end

function Island.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local rank = rankReached(data)
	local need = keyRank(ctx)
	local needDef = FortuneRules.Ranks[need] or FortuneRules.Ranks[#FortuneRules.Ranks]
	local today = Plan.pearlsFor(p.pearlDay)
	local taken = {}
	local got = 0
	for i, spot in today do
		taken[i] = p.pearlTaken[tostring(spot)] == true
		if taken[i] then
			got += 1
		end
	end
	local liveries = {}
	for _, l in Plan.Liveries do
		table.insert(liveries, { id = l.id, name = l.name, line = l.line, owned = p.liveries[l.id] == true, gilt = l.gilt, gems = l.gems, product = l.product, onSale = if l.product then Island.liveryOnSale(l.product) else nil, standing = if l.standing then Plan.Standing[l.standing].name else nil })
	end
	local themes = {}
	for _, t in Plan.Themes do
		table.insert(themes, { id = t.id, name = t.name, line = t.line, owned = p.themes[t.id] == true, gilt = t.gilt, gems = t.gems, standing = if t.standing then Plan.Standing[t.standing].name else nil })
	end
	local exchange = {}
	for _, e in Plan.Exchange do
		local item = Wardrobe.get(e.id)
		if item then
			table.insert(exchange, { id = e.id, name = item.name, line = item.line, pearls = e.pearls, owned = (data.owned or {})[e.id] == true })
		end
	end
	local cards = {}
	for _, c in Plan.Postcards do
		table.insert(cards, { id = c.id, name = c.name, taken = p.postcards[c.id] == true })
	end
	local fortune = 0
	local okFortune, total = pcall(Fortune.of, data)
	if okFortune and type(total) == "number" then
		fortune = total
	end
	-- (Build 90) Island Standing: never shown below a rank already reached and paid.
	local pts = standingPoints(p)
	local standingRank = math.max(Plan.standingOf(pts), math.min(p.standingPaid, #Plan.Standing))
	local nextRank = Plan.Standing[standingRank + 1]
	return {
		ok = true,
		key = p.key == true,
		keyRank = need,
		keyRankName = needDef.name,
		keyRankAt = needDef.at,
		rank = rank,
		fortune = fortune,
		keyGilt = keyGilt(ctx),
		keyGems = keyGems(ctx),
		-- (Build 103) Where they are: on the island, or in the Jet Lounge where the jet boards.
		here = ctx.inside(player) == Plan.ID,
		lounge = inLounge(ctx, player),
		rewards = rewards(ctx),
		pearlSpots = today,
		pearlTaken = taken,
		pearlsGot = got,
		pearlBalance = p.pearls,
		pearlsAll = p.pearlsAll,
		toasted = p.toastDay == Plan.day(Island.now()),
		sunsetsAll = p.sunsetsAll,
		postcards = p.postcards,
		postcardList = cards,
		postcardCount = postcardCount(p),
		postcardTotal = #Plan.Postcards,
		postcardsPaid = p.postcardsPaid == true,
		liveries = liveries,
		livery = p.livery,
		themes = themes,
		theme = p.theme,
		exchange = exchange,
		rides = IslandRides.state(p), -- (Build 104)
		flights = p.flights,
		flightDays = p.flightDays,
		standing = { points = pts, rank = standingRank, name = Plan.Standing[standingRank].name, nextAt = if nextRank then nextRank.at else nil, nextName = if nextRank then nextRank.name else nil },
	}
end

---------------------------------------------------------------------------------------------------
-- The Island Key
---------------------------------------------------------------------------------------------------
local function buyKey(ctx: Types.Ctx, player: Player, data: any, p: { [string]: any }, how: string): { [string]: any }
	if p.key then
		return { ok = false, why = "The island is already yours." }
	end
	local need = keyRank(ctx)
	if rankReached(data) < need then
		local r = FortuneRules.Ranks[need] or FortuneRules.Ranks[#FortuneRules.Ranks]
		return { ok = false, why = string.format("The Island Key is for a %s: build your Fortune to %s first.", r.name, FortuneRules.format(r.at)) }
	end
	local gilt, gems = 0, 0
	if how == "gems" then
		gems = keyGems(ctx)
	else
		gilt = keyGilt(ctx)
	end
	if not ctx.spend(player, gilt, gems, "island key") then
		return { ok = false, short = if gems > 0 then "Gems" else "Gilt", why = if gems > 0 then string.format("The Island Key is %d Gems.", gems) else string.format("The Island Key is %s Gilt.", FortuneRules.format(gilt)) }
	end
	p.key = true
	p.keyAt = Island.now()
	ctx.award(player, "islandKey")
	ctx.herald(player, { kind = "island", title = "THE ISLAND KEY", line = "has the key to Luxury Island", glyph = "🏝️" })
	return { ok = true, title = "The Island Key", line = "Luxury Island is yours: the jet boards in the Jet Lounge, here on the Terrace." }
end

---------------------------------------------------------------------------------------------------
-- The pearls, the toast, the postcards, the summit path
---------------------------------------------------------------------------------------------------
-- Where a guest stands on the island (from its origin), if they're truly on it.
local function standing(ctx: Types.Ctx, player: Player): Vector3?
	if ctx.inside(player) ~= Plan.ID or not ctx.trusted(player) then
		return nil
	end
	return ctx.at(player, Plan.ID)
end

-- Whether a guest at `at` is in the lagoon beside the pearl at `pearlAt`: near it across the water
-- (with a little allowance for where the server sees a swimmer), in the water, not above it on a
-- deck or the pier, and not far below it.
local function besidePearl(at: Vector3, pearlAt: Vector3): boolean
	local flat = Vector3.new(at.X - pearlAt.X, 0, at.Z - pearlAt.Z).Magnitude
	return flat <= Plan.PEARL_REACH + Plan.PEARL_SLACK and at.Y <= Plan.SEA + Plan.PEARL_ABOVE_SEA and at.Y >= pearlAt.Y - 6
end
Island.besidePearl = besidePearl

local function pearl(ctx: Types.Ctx, player: Player, p: { [string]: any }, n: number): { [string]: any }
	local today = Plan.pearlsFor(p.pearlDay)
	local spot = today[n]
	if not spot then
		return { ok = false, why = "There's no such pearl today." }
	end
	if p.pearlTaken[tostring(spot)] then
		return { ok = false, why = "You've brought that one up already today." }
	end
	local at = standing(ctx, player)
	if not at or not besidePearl(at, Plan.PEARL_SPOTS[spot]) then
		return { ok = false, why = "Swim down beside it first." }
	end
	p.pearlTaken[tostring(spot)] = true
	p.pearls += 1
	p.pearlsAll += 1
	local r = rewards(ctx)
	local gilt = ctx.prize(player, r.pearl, "island pearl")
	ctx.tally(player, "pearls", 1)
	ctx.progress(player, "pearl", 1)
	local got = 0
	for _, s in today do
		if p.pearlTaken[tostring(s)] then
			got += 1
		end
	end
	local set = 0
	if got >= #today then
		set = ctx.prize(player, r.pearlSet, "island pearls: all five")
	end
	standingCheck(ctx, player, p)
	return { ok = true, pearl = n, got = got, of = #today, gilt = gilt, set = set, balance = p.pearls }
end

local LOOKOUT = Plan.Places.summit.at

local function toast(ctx: Types.Ctx, player: Player, p: { [string]: any }): { [string]: any }
	local today = Plan.day(Island.now())
	if p.toastDay == today then
		return { ok = false, why = "You've toasted today's sunset already. Come back tomorrow." }
	end
	local at = standing(ctx, player)
	if not at or (Vector3.new(at.X, 0, at.Z) - Vector3.new(LOOKOUT.X, 0, LOOKOUT.Z)).Magnitude > Plan.TOAST_REACH or at.Y < LOOKOUT.Y - 6 then
		return { ok = false, why = "Raise your glass at the Sunset Lookout, on the summit." }
	end
	p.toastDay = today
	local r = rewards(ctx)
	-- (Friends who toasted in the last few minutes, still in the house.)
	local t = Island.now()
	local kept: { Toast } = {}
	local together: { Toast } = {}
	for _, e in toasts do
		if t - e.at <= Plan.TOAST_WINDOW and e.player.Parent == Players then
			table.insert(kept, e)
			if e.player ~= player and Island.friends(player, e.player) then
				table.insert(together, e)
			end
		end
	end
	local friends = math.min(#together, r.toastFriendsMost)
	table.insert(kept, { player = player, at = t, friends = friends })
	toasts = kept
	local gilt = ctx.prize(player, r.toast + friends * r.toastFriend, "island sunset")
	ctx.tally(player, "sunsets", 1)
	ctx.progress(player, "toast", 1)
	p.sunsetsAll += 1
	standingCheck(ctx, player, p)
	local name = Names.of(player)
	-- (Build 103) The friends who toasted first have a little more too, now their friend has joined
	-- them: each friend counted once, and at most TOAST_FRIENDS_MOST for any one toast.
	local told: { [Player]: boolean } = {}
	for _, e in together do
		told[e.player] = true
		if e.friends < r.toastFriendsMost and r.toastFriend > 0 then
			e.friends += 1
			local more = ctx.prize(e.player, r.toastFriend, "island sunset: a friend's toast")
			ctx.send(e.player, { op = "notice", title = "A toast together", line = string.format("%s raised a glass with you at the Lookout  ·  +%s Gilt", name, FortuneRules.format(more)) })
		end
	end
	-- Friends on the island who haven't toasted today hear of it: there's a little more for them
	-- too if they toast within the next few minutes (the window is real, and said as it is).
	for _, q in Players:GetPlayers() do
		if q ~= player and not told[q] and ctx.inside(q) == Plan.ID and Island.friends(player, q) then
			local qd = ctx.data(q)
			if qd and page(ctx, qd).toastDay ~= today then
				ctx.send(q, { op = "notice", title = "A toast at the Lookout", line = string.format("%s is raising a glass to the sunset. Toast at the Lookout within %d minutes: a little more for you both.", name, r.toastMinutes) })
			end
		end
	end
	local line = if friends > 0
		then string.format("%s Gilt, with %d friend%s toasting beside you.", FortuneRules.format(gilt), friends, if friends == 1 then "" else "s")
		else string.format("%s Gilt. Bring friends: a little more for each who toasts with you, within %d minutes.", FortuneRules.format(gilt), r.toastMinutes)
	ctx.send(player, { op = "toasted", gilt = gilt, friends = friends })
	return { ok = true, title = "To the sunset", line = line, gilt = gilt, friends = friends }
end

local function postcard(ctx: Types.Ctx, player: Player, p: { [string]: any }, id: string): { [string]: any }
	local spot = nil
	for _, c in Plan.Postcards do
		if c.id == id then
			spot = c
		end
	end
	if not spot then
		return { ok = false, why = "There's no such postcard spot." }
	end
	local at = standing(ctx, player)
	if not at or (at - spot.at).Magnitude > Plan.POSTCARD_REACH then
		return { ok = false, why = "Stand at the frame first." }
	end
	local first = p.postcards[id] ~= true
	p.postcards[id] = true
	local count = postcardCount(p)
	local paid = 0
	if count >= #Plan.Postcards and not p.postcardsPaid then
		p.postcardsPaid = true
		-- (Once ever: paid in full, as shown on the Jet Lounge's card.)
		paid = ctx.prize(player, rewards(ctx).postcards, "island postcards")
		ctx.award(player, "postcards")
	end
	ctx.send(player, { op = "postcard", id = id, name = spot.name, count = count, total = #Plan.Postcards, first = first, paid = paid })
	standingCheck(ctx, player, p)
	return { ok = true, count = count, total = #Plan.Postcards }
end

-- (Build 103) The summit path: up to the Sunset Lookout from the foot of its stair, or down again,
-- for a guest who is truly at that end.
local function path(ctx: Types.Ctx, player: Player, which: string): { [string]: any }
	local sp = Plan.SummitPath
	if which ~= "up" and which ~= "down" then
		return { ok = false, why = "That isn't something the house does." }
	end
	local from = if which == "up" then sp.foot else sp.head
	local at = standing(ctx, player)
	if not at or (at - from).Magnitude > sp.reach then
		return { ok = false, why = if which == "up" then "The path up starts at the foot of the Lookout's stair, by the gardens." else "The path down starts at the head of the Lookout's stair." }
	end
	local to = if which == "up" then sp.headArrive else sp.footArrive
	if not ctx.teleport(player, to + AttractionList.origin(Plan.ID)) then
		return { ok = false, why = "Not just now." }
	end
	return { ok = true }
end

---------------------------------------------------------------------------------------------------
-- Liveries, the island's lights, the Pearl Exchange
---------------------------------------------------------------------------------------------------
local function choose(ctx: Types.Ctx, player: Player, p: { [string]: any }, kind: string, id: string): { [string]: any }
	local def: any = if kind == "livery" then Plan.liveryById[id] else Plan.themeById[id]
	if not def then
		return { ok = false, why = "That isn't one of the island's." }
	end
	local owned = if kind == "livery" then p.liveries else p.themes
	if not owned[id] then
		if def.standing then
			-- (Earned with Island Standing only: never sold.)
			local r = Plan.Standing[def.standing]
			return { ok = false, why = string.format("%s comes with Island Standing: %s.", def.name, if r then r.name else "a higher rank") }
		end
		if def.product then
			local ok, why = Island.offerLivery(player, def.product)
			return { ok = false, prompted = ok, why = if ok then nil else why }
		end
		local gilt, gems = num(def.gilt, 0), num(def.gems, 0)
		if not ctx.spend(player, gilt, gems, if kind == "livery" then "jet livery" else "island light") then
			return { ok = false, short = if gems > 0 then "Gems" else "Gilt", why = if gems > 0 then string.format("%s is %d Gems.", def.name, gems) else string.format("%s is %s Gilt.", def.name, FortuneRules.format(gilt)) }
		end
		owned[id] = true
	end
	if kind == "livery" then
		p.livery = id
	else
		p.theme = id
	end
	publish(player, p)
	return { ok = true, title = def.name, line = if kind == "livery" then "Your jet wears it now." else "The island's light is yours to choose: it's set." }
end

local function exchange(ctx: Types.Ctx, player: Player, data: any, p: { [string]: any }, id: string): { [string]: any }
	local cost = Plan.exchangeById[id]
	local item = Wardrobe.get(id)
	if not cost or not item then
		return { ok = false, why = "The Exchange doesn't keep that." }
	end
	data.owned = data.owned or {}
	if data.owned[id] then
		return { ok = false, why = "It's in your Suite's collection already." }
	end
	if p.pearls < cost then
		return { ok = false, why = string.format("%s is %d pearls: you have %d.", item.name, cost, p.pearls) }
	end
	p.pearls -= cost
	data.owned[id] = true
	Island.ownedChanged(player)
	-- (A Suite piece counts toward the Fortune.)
	ctx.fortune(player)
	return { ok = true, title = item.name, line = "Yours: ring the bell in your Suite to put it where you like.", balance = p.pearls }
end

-- (Build 98) Closed while Config's comingSoon is on: no way in, and no key sold for it.
function Island.comingSoon(ctx: Types.Ctx): boolean
	return cfg(ctx).comingSoon == true
end
local SOON = "Luxury Island is coming soon. It isn't open yet."

function Island.ask(ctx: Types.Ctx, player: Player, r: { [string]: unknown }): any
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local act, what, n = r.act, r.what, r.n
	local result: { [string]: any }
	if act == "key" and Island.comingSoon(ctx) then
		return { ok = false, why = SOON }
	elseif act == "key" then
		result = buyKey(ctx, player, data, p, if what == "gems" then "gems" else "gilt")
	elseif act == "pearl" and type(n) == "number" and n == math.floor(n) then
		result = pearl(ctx, player, p, n :: number)
	elseif act == "toast" then
		result = toast(ctx, player, p)
	elseif act == "postcard" and type(what) == "string" then
		result = postcard(ctx, player, p, what :: string)
	elseif act == "path" and type(what) == "string" then
		result = path(ctx, player, what :: string)
	elseif (act == "livery" or act == "theme") and type(what) == "string" then
		result = choose(ctx, player, p, act :: string, what :: string)
	elseif act == "exchange" and type(what) == "string" then
		result = exchange(ctx, player, data, p, what :: string)
	-- (Build 104) The island's rides.
	elseif act == "ride" and type(what) == "string" then
		result = IslandRides.ride(ctx, player, p, what :: string)
	elseif act == "buyRide" and type(what) == "string" then
		result = IslandRides.buy(ctx, player, p, what :: string, if r.how == "robux" then "robux" else "gilt")
	elseif act == "board" and type(what) == "string" then
		result = IslandRides.board(ctx, player, what :: string)
	elseif act == "leap" then
		result = IslandRides.leap(ctx, player)
	else
		return { ok = false, why = "That isn't something the house does." }
	end
	if result.ok then
		result.state = Island.state(ctx, player)
	end
	return result
end

---------------------------------------------------------------------------------------------------
-- The attraction
---------------------------------------------------------------------------------------------------
local function prompt(parent: BasePart, kind: string, action: string, object: string, attrs: { [string]: any }, distance: number?): ProximityPrompt
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "AttractionPrompt"
	pr.ActionText = action
	pr.ObjectText = object
	pr.KeyboardKeyCode = Enum.KeyCode.E
	pr.GamepadKeyCode = Enum.KeyCode.ButtonX
	pr.HoldDuration = 0
	pr.MaxActivationDistance = distance or 12
	pr.RequiresLineOfSight = false
	pr.Style = Enum.ProximityPromptStyle.Custom
	pr:SetAttribute("Attraction", Plan.ID)
	pr:SetAttribute("Kind", kind)
	for k, v in attrs do
		pr:SetAttribute(k, v)
	end
	pr.Parent = parent
	CollectionService:AddTag(pr, "AttractionPrompt")
	return pr
end

-- An unseen part: something to hang a prompt on, or a wall.
local function unseen(parent: Instance, name: string, size: Vector3, at: Vector3, solid: boolean): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = solid
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.CFrame = CFrame.new(at)
	part.Parent = parent
	return part
end

-- (Build 103) The island's unseen edge, just inside its area, all round: nobody swims out of it.
local function edge(parent: Instance, o: Vector3)
	local b = AttractionList.BOUNDS[Plan.ID]
	if not b then
		return
	end
	local inset = Vector3.new(Plan.EDGE_INSET, 0, Plan.EDGE_INSET)
	local lo, hi = o + b.min + inset, o + b.max - inset
	local mid = (lo + hi) / 2
	local size = hi - lo
	unseen(parent, "EdgeWest", Vector3.new(2, size.Y, size.Z + 4), Vector3.new(lo.X - 1, mid.Y, mid.Z), true)
	unseen(parent, "EdgeEast", Vector3.new(2, size.Y, size.Z + 4), Vector3.new(hi.X + 1, mid.Y, mid.Z), true)
	unseen(parent, "EdgeSouth", Vector3.new(size.X + 4, size.Y, 2), Vector3.new(mid.X, mid.Y, lo.Z - 1), true)
	unseen(parent, "EdgeNorth", Vector3.new(size.X + 4, size.Y, 2), Vector3.new(mid.X, mid.Y, hi.Z + 1), true)
end

function Island.build(ctx: Types.Ctx, parent: Instance)
	local o = ctx.cfg(Plan.ID).origin
	if type(o) ~= "table" then
		return
	end
	local origin = Vector3.new(o[1], o[2], o[3])
	local b = IslandBuild.build(parent, origin)
	built = b
	if b.home then
		prompt(b.home, "home", "Fly home", "Your jet", {}, 14)
	end
	prompt(b.desk, "panel", "Liveries", "The Jet Gallery", { Panel = "liveries" })
	prompt(b.exchange, "panel", "The Exchange", "Pearls for the island's pieces", { Panel = "exchange" })
	prompt(b.toast, "act", "Raise a glass", "The sunset", { Act = "toast" }, 14)
	for _, spot in b.postcards do
		local id = spot:GetAttribute("Postcard")
		if type(id) == "string" then
			prompt(spot, "act", "Take a postcard", "The view", { Act = "postcard", What = id }, Plan.POSTCARD_PROMPT)
		end
	end
	-- (Build 103) The summit path's two ends, and the island's edge (beside the island's model,
	-- which IslandBuild keeps to itself).
	local ways = Instance.new("Model")
	ways.Name = "IslandWays"
	local sp = Plan.SummitPath
	local up = unseen(ways, "SummitPathFoot", Vector3.new(3, 5, 3), origin + sp.foot + Vector3.new(0, 2.5, 0), false)
	prompt(up, "act", "Up to the Lookout", "The summit path", { Act = "path", What = "up" }, 10)
	local down = unseen(ways, "SummitPathHead", Vector3.new(3, 5, 3), origin + sp.head + Vector3.new(0, 2.5, 0), false)
	prompt(down, "act", "Down to the gardens", "The summit path", { Act = "path", What = "down" }, 10)
	edge(ways, origin)
	ways.Parent = parent
	-- (Build 104) The rides: the Jet Ski Hire, the helicopter's pad, the Day Yacht's berth, and the
	-- moored Sovereign's gangway and its top deck's leap.
	local rb = IslandRides.build(parent, origin)
	prompt(rb.hire, "act", "Ride a jet ski", "Jet Ski Hire", { Act = "ride", What = "jetski" }, 12)
	prompt(rb.heli, "act", "Fly", "The helicopter", { Act = "ride", What = "heli" }, 14)
	prompt(rb.yachtHelm, "act", "Take the helm", "The Day Yacht", { Act = "ride", What = "yacht" }, 14)
	prompt(rb.yachtBoard, "act", "Board", "The Day Yacht", { Act = "board", What = "yacht" }, 14)
	if rb.gangway then
		prompt(rb.gangway, "act", "Board", "The Sovereign", { Act = "board", What = "sovereign" }, 14)
	end
	for _, spot in rb.leap do
		prompt(spot, "act", "Leap", "Into the sea", { Act = "leap" }, 10)
	end
end

function Island.enter(ctx: Types.Ctx, player: Player): (CFrame?, string?)
	if Island.comingSoon(ctx) then
		return nil, SOON
	end
	local data = ctx.data(player)
	if not data then
		return nil, "Your ledger is still being opened."
	end
	local p = page(ctx, data)
	if not p.key then
		return nil, "The Island Key opens it: see the card in the Jet Lounge, on the Terrace."
	end
	p.flights += 1
	-- (Build 103: Island Standing counts the first flight of each day.)
	local today = Plan.day(Island.now())
	if p.flightDay ~= today then
		p.flightDay = today
		p.flightDays += 1
	end
	ctx.tally(player, "flights", 1)
	publish(player, p)
	-- (Boarding from a seat on the Terrace: up first, so the seat stays behind.)
	unseat(player)
	-- (Island Standing once they've landed: the flight is on their screen first.)
	task.delay(Plan.FLIGHT_SECONDS, function()
		if player.Parent and ctx.inside(player) == Plan.ID then
			local d = ctx.data(player)
			if d then
				standingCheck(ctx, player, page(ctx, d))
			end
		end
	end)
	return Plan.Arrival, nil
end

-- Without the Island Key, the jet's arch opens the Jet Lounge's card instead (how to have it).
function Island.locked(ctx: Types.Ctx, player: Player): boolean
	-- (While it's closed, coming soon, the arch never opens the key's card; the way in says why.)
	if Island.comingSoon(ctx) then
		return false
	end
	local data = ctx.data(player)
	return data ~= nil and page(ctx, data).key ~= true
end

-- Its card in the Maison Directory: open with the Island Key; else what opens it (the rank, the
-- key's two prices) and the rank the guest has reached.
function Island.directory(ctx: Types.Ctx, player: Player): { [string]: any }
	local need = keyRank(ctx)
	local r = FortuneRules.Ranks[need] or FortuneRules.Ranks[#FortuneRules.Ranks]
	local out: { [string]: any } = {
		open = false,
		comingSoon = Island.comingSoon(ctx),
		keyRank = r.name,
		keyRankAt = r.at,
		keyGilt = keyGilt(ctx),
		keyGems = keyGems(ctx),
		rankReady = false,
	}
	local data = ctx.data(player)
	if data then
		local p = page(ctx, data)
		out.open = p.key == true and not out.comingSoon
		out.rankReady = rankReached(data) >= need
		out.flights = p.flights
	end
	return out
end

-- (Build 103) Leaving. Flying home: up from any seat first (a lounger, a bench, a car), so the
-- guest arrives standing. A guest carried out of the island's area while still out at sea (past
-- its edge, by anything at all) is flown home to the Jet Lounge, never left adrift with no way
-- back. Anyone the house moved elsewhere ("away" too, but nowhere near the island) is left where
-- the house put them.
function Island.leave(ctx: Types.Ctx, player: Player, why: string)
	-- (Build 104) Their own rides are put away, whatever the reason they've gone.
	pcall(function()
		IslandRides.leave(ctx, player)
	end)
	if player.Parent == nil then
		return
	end
	if why == "home" then
		unseat(player)
		return
	elseif why ~= "away" then
		return
	end
	local root = ctx.rootOf(player)
	if not root or (root.CFrame.Position - AttractionList.origin(Plan.ID)).Magnitude > Plan.ADRIFT then
		return
	end
	unseat(player)
	task.defer(function()
		if player.Parent and ctx.inside(player) == nil then
			ctx.sendHome(player, Plan.ID)
			ctx.notice(player, "Home from the island", "You'd gone out past the island's waters: the jet has brought you home to the Jet Lounge.")
		end
	end)
end

-- (Build 103) Nobody is ever on the island without having flown in (whose screen would have no
-- island card and no Fly home): someone the house set down there any other way (an owner's
-- "bring" or "go to") is flown home to the Jet Lounge after a few moments, the owner aside.
local strays: { [Player]: number } = {}
function Island.step(ctx: Types.Ctx, _dt: number)
	local okRides, whyRides = pcall(function()
		IslandRides.step(ctx)
	end)
	if not okRides then
		warn("[Maison] The island's rides stumbled: " .. tostring(whyRides))
	end
	local t = os.clock()
	for _, player in Players:GetPlayers() do
		local root = ctx.rootOf(player)
		if root and ctx.inside(player) == nil and AttractionList.areaAt(root.CFrame.Position) == Plan.ID and not ctx.isOwner(player) then
			local since = strays[player]
			if since == nil then
				strays[player] = t
			elseif since ~= math.huge and t - since >= Plan.STRAY_SECONDS then
				strays[player] = math.huge -- (on the way: not asked again until they're off the island)
				unseat(player)
				task.spawn(function()
					ctx.sendHome(player, Plan.ID)
					ctx.notice(player, "Home from the island", "Luxury Island is reached by the private jet: you're back in the Jet Lounge, where it boards.")
				end)
			end
		else
			strays[player] = nil
		end
	end
	for player in strays do
		if player.Parent == nil then
			strays[player] = nil
		end
	end
end

function Island.arrived(ctx: Types.Ctx, player: Player)
	local data = ctx.data(player)
	if data then
		publish(player, page(ctx, data))
	end
end

Island.rides = IslandRides

-- For tests.
function Island.built(): IslandBuild.Built?
	return built
end
function Island.toasts(): { Toast }
	return toasts
end

return Island

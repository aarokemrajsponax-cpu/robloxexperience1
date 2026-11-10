--!strict
-- Luxury Island on the server (shared/Island has the plan; IslandBuild builds it). Everything is
-- the server's: whether a guest holds the Island Key (a wealth rank reached, and the key bought
-- for Gilt or Gems at the Jet Lounge, both shown before anyone pays), the day's pearls on the
-- lagoon's floor (the same five for everyone, each brought up once a day by a guest who is truly
-- beside it), the sunset toast at the Lookout (once a day; a little more for each friend who
-- toasts in the same few minutes), the postcard spots, the liveries and the island's lights each
-- guest owns and chooses, and the Pearl Exchange (the island's own Suite pieces, for pearls).
-- Nothing a guest's screen says is a reward, a price or a place.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FortuneRules = require(ReplicatedStorage.Shared.Fortune)
local Plan = require(ReplicatedStorage.Shared.Island)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Fortune = require(script.Parent.Parent.Fortune)
local Types = require(script.Parent.Types)
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

local built: IslandBuild.Built? = nil
local toasts: { { player: Player, at: number } } = {} -- the last few minutes' toasts, for friends
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

-- A guest's page of the island, tidied (made on first asking).
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
	p.liveries.noir = true
	p.themes.golden = true
	if type(p.livery) ~= "string" or not Plan.liveryById[p.livery] then
		p.livery = "noir"
	end
	if type(p.theme) ~= "string" or not Plan.themeById[p.theme] then
		p.theme = "golden"
	end
	p.pearls = num(p.pearls, 0)
	p.pearlsAll = num(p.pearlsAll, 0)
	p.flights = num(p.flights, 0)
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

---------------------------------------------------------------------------------------------------
-- What a guest's screen is told
---------------------------------------------------------------------------------------------------
function Island.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local rank = rankReached(data)
	local today = Plan.pearlsFor(p.pearlDay)
	local taken = {}
	for i, spot in today do
		taken[i] = p.pearlTaken[tostring(spot)] == true
	end
	local liveries = {}
	for _, l in Plan.Liveries do
		table.insert(liveries, { id = l.id, name = l.name, line = l.line, owned = p.liveries[l.id] == true, gilt = l.gilt, gems = l.gems, product = l.product, onSale = if l.product then Island.liveryOnSale(l.product) else nil })
	end
	local themes = {}
	for _, t in Plan.Themes do
		table.insert(themes, { id = t.id, name = t.name, line = t.line, owned = p.themes[t.id] == true, gilt = t.gilt, gems = t.gems })
	end
	local exchange = {}
	for _, e in Plan.Exchange do
		local item = Wardrobe.get(e.id)
		if item then
			table.insert(exchange, { id = e.id, name = item.name, line = item.line, pearls = e.pearls, owned = (data.owned or {})[e.id] == true })
		end
	end
	local cards = 0
	for _ in p.postcards do
		cards += 1
	end
	return {
		ok = true,
		key = p.key == true,
		keyRank = keyRank(ctx),
		keyRankName = (FortuneRules.Ranks[keyRank(ctx)] or FortuneRules.Ranks[1]).name,
		rank = rank,
		keyGilt = keyGilt(ctx),
		keyGems = keyGems(ctx),
		pearlSpots = today,
		pearlTaken = taken,
		pearlBalance = p.pearls,
		pearlsAll = p.pearlsAll,
		toasted = p.toastDay == Plan.day(Island.now()),
		postcards = p.postcards,
		postcardCount = cards,
		postcardTotal = #Plan.Postcards,
		liveries = liveries,
		livery = p.livery,
		themes = themes,
		theme = p.theme,
		exchange = exchange,
		flights = p.flights,
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
		return { ok = false, why = if gems > 0 then string.format("The Island Key is %d Gems.", gems) else string.format("The Island Key is %s Gilt.", FortuneRules.format(gilt)) }
	end
	p.key = true
	p.keyAt = Island.now()
	ctx.award(player, "islandKey")
	ctx.herald(player, { kind = "island", title = "THE ISLAND KEY", line = "has the key to Luxury Island", glyph = "🏝️" })
	return { ok = true, title = "The Island Key", line = "Luxury Island is yours: the jet waits in the Jet Lounge." }
end

---------------------------------------------------------------------------------------------------
-- The pearls, the toast, the postcards
---------------------------------------------------------------------------------------------------
-- Where a guest stands on the island (from its origin), if they're truly on it.
local function standing(ctx: Types.Ctx, player: Player): Vector3?
	if ctx.inside(player) ~= Plan.ID or not ctx.trusted(player) then
		return nil
	end
	return ctx.at(player, Plan.ID)
end

local function pearl(ctx: Types.Ctx, player: Player, data: any, p: { [string]: any }, n: number): { [string]: any }
	local today = Plan.pearlsFor(p.pearlDay)
	local spot = today[n]
	if not spot then
		return { ok = false, why = "There's no such pearl today." }
	end
	if p.pearlTaken[tostring(spot)] then
		return { ok = false, why = "You've brought that one up already today." }
	end
	local at = standing(ctx, player)
	if not at or (at - Plan.PEARL_SPOTS[spot]).Magnitude > Plan.PEARL_REACH then
		return { ok = false, why = "Swim down beside it first." }
	end
	p.pearlTaken[tostring(spot)] = true
	p.pearls += 1
	p.pearlsAll += 1
	local gilt = ctx.gilt(player, num(cfg(ctx).pearlGilt, Plan.PEARL_GILT), "island pearl")
	ctx.tally(player, "pearls", 1)
	ctx.progress(player, "pearl", 1)
	local got = 0
	for _, s in today do
		if p.pearlTaken[tostring(s)] then
			got += 1
		end
	end
	local gems = 0
	if got >= #today then
		gems = ctx.gems(player, num(cfg(ctx).pearlSetGems, Plan.PEARL_SET_GEMS), "island pearls", Plan.ID)
	end
	local _ = data
	return { ok = true, pearl = n, got = got, of = #today, gilt = gilt, gems = gems, balance = p.pearls }
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
	-- (Friends who toasted in the last few minutes, still in the house.)
	local t = Island.now()
	local friends = 0
	local kept = {}
	for _, e in toasts do
		if t - e.at <= Plan.TOAST_WINDOW and e.player.Parent == Players then
			table.insert(kept, e)
			if e.player ~= player and Island.friends(player, e.player) then
				friends += 1
			end
		end
	end
	toasts = kept
	table.insert(toasts, { player = player, at = t })
	friends = math.min(friends, Plan.TOAST_FRIENDS_MOST)
	local gilt = ctx.gilt(player, Plan.TOAST_GILT + friends * Plan.TOAST_FRIEND, "island sunset")
	ctx.tally(player, "sunsets", 1)
	ctx.progress(player, "toast", 1)
	local line = if friends > 0 then string.format("%d Gilt, with %d friend%s toasting beside you.", gilt, friends, if friends == 1 then "" else "s") else string.format("%d Gilt. Bring friends tomorrow: a little more for each who toasts with you.", gilt)
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
	local count = 0
	for _ in p.postcards do
		count += 1
	end
	local paid = 0
	if count >= #Plan.Postcards and not p.postcardsPaid then
		p.postcardsPaid = true
		paid = ctx.gilt(player, Plan.POSTCARDS_GILT, "island postcards")
		ctx.award(player, "postcards")
	end
	ctx.send(player, { op = "postcard", id = id, name = spot.name, count = count, total = #Plan.Postcards, first = first, paid = paid })
	return { ok = true, count = count, total = #Plan.Postcards }
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
		if def.product then
			local ok, why = Island.offerLivery(player, def.product)
			return { ok = false, prompted = ok, why = if ok then nil else why }
		end
		local gilt, gems = num(def.gilt, 0), num(def.gems, 0)
		if not ctx.spend(player, gilt, gems, if kind == "livery" then "jet livery" else "island light") then
			return { ok = false, why = if gems > 0 then string.format("%s is %d Gems.", def.name, gems) else string.format("%s is %s Gilt.", def.name, FortuneRules.format(gilt)) }
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
	local _ = ctx
	return { ok = true, title = item.name, line = "Yours: ring the bell in your Suite to put it where you like.", balance = p.pearls }
end

function Island.ask(ctx: Types.Ctx, player: Player, r: { [string]: unknown }): any
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local act, what, n = r.act, r.what, r.n
	local result: { [string]: any }
	if act == "key" then
		result = buyKey(ctx, player, data, p, if what == "gems" then "gems" else "gilt")
	elseif act == "pearl" and type(n) == "number" and n == math.floor(n) then
		result = pearl(ctx, player, data, p, n :: number)
	elseif act == "toast" then
		result = toast(ctx, player, p)
	elseif act == "postcard" and type(what) == "string" then
		result = postcard(ctx, player, p, what :: string)
	elseif (act == "livery" or act == "theme") and type(what) == "string" then
		result = choose(ctx, player, p, act :: string, what :: string)
	elseif act == "exchange" and type(what) == "string" then
		result = exchange(ctx, player, data, p, what :: string)
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

function Island.build(ctx: Types.Ctx, parent: Instance)
	local o = ctx.cfg(Plan.ID).origin
	if type(o) ~= "table" then
		return
	end
	local b = IslandBuild.build(parent, Vector3.new(o[1], o[2], o[3]))
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
			prompt(spot, "act", "Take a postcard", "The view", { Act = "postcard", What = id }, 12)
		end
	end
end

function Island.enter(ctx: Types.Ctx, player: Player): (CFrame?, string?)
	local data = ctx.data(player)
	if not data then
		return nil, "Your ledger is still being opened."
	end
	local p = page(ctx, data)
	if not p.key then
		return nil, "The Island Key opens it: see the desk in the Jet Lounge, on the Terrace."
	end
	p.flights += 1
	ctx.tally(player, "flights", 1)
	publish(player, p)
	return Plan.Arrival, nil
end

-- Without the Island Key, the jet's arch opens the Jet Lounge's card instead (how to have it).
function Island.locked(ctx: Types.Ctx, player: Player): boolean
	local data = ctx.data(player)
	return data ~= nil and page(ctx, data).key ~= true
end

function Island.leave(_ctx: Types.Ctx, _player: Player, _why: string) end

function Island.step(_ctx: Types.Ctx, _dt: number) end

function Island.arrived(ctx: Types.Ctx, player: Player)
	local data = ctx.data(player)
	if data then
		publish(player, page(ctx, data))
	end
end

-- For tests.
function Island.built(): IslandBuild.Built?
	return built
end

return Island

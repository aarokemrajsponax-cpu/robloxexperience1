--!strict
-- The Boutique and the money (§12, Appendix I). Robux buys style, never score. Every price is
-- read live from Roblox. The rotating shelves sell through one developer product per price tier:
-- the guest chooses a piece, the server keeps that choice in their saved profile, and the receipt
-- grants it. Gifts go to another guest in the house and the Concierge hands them over. Gilt buys
-- the house's own pieces; it is earned by playing or bought in purses.
--
-- What each product is, costs and gives lives in Shared/ProductConfig; receipts, the purchase
-- ledger and prompts are server/Purchases. This module registers the grant handlers for the
-- Boutique's products (each one a transaction: see Purchases/Grants) and answers the Boutique's
-- requests (through RemoteGuard, like every remote).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boutique = require(ReplicatedStorage.Shared.Boutique)
local Config = require(ReplicatedStorage.Shared.Config)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Standing = require(ReplicatedStorage.Shared.Standing)
local Salutes = require(ReplicatedStorage.Shared.Salutes)
local Suite = require(ReplicatedStorage.Shared.Suite)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)

local Analytics = require(script.Parent.Analytics)
local BlackCard = require(script.Parent.BlackCard)
local CircleService = require(script.Parent.CircleService)
local SaluteService = require(script.Parent.SaluteService)
local Social = require(script.Parent.Social)
local Dressing = require(script.Parent.Dressing)
local Gilt = require(script.Parent.Gilt)
local LedgerService = require(script.Parent.LedgerService)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Season = require(script.Parent.Season)
local Catalog = require(script.Parent.Purchases.Catalog)
local Grants = require(script.Parent.Purchases.Grants)
local Perks = require(script.Parent.Purchases.Perks)
local PriceLevels = require(script.Parent.Purchases.PriceLevels)
local Store = require(script.Parent.Purchases.Store)

local Shop = {}

-- The Register's view of a guest (set by Main).
Shop.register = function(_data: Profiles.Data): any
	return nil
end

-- The Concierge's handover of a gift (set by Main).
Shop.handOver = function(_recipient: Player, _from: string, _itemName: string) end

-- A Golden Hour a guest bought for everyone in the house (set by Main: the owner's event).
Shop.goldenHour = function(_buyer: Player, _seconds: number) end

local shopEvent = Remotes.event("Shop")

-- Developer products are found by their names in Creator Hub (Purchases/Catalog).
Shop.discover = Catalog.discover

-- Roblox's price for a catalog key, or nil when it isn't on sale.
local function price(key: string): number?
	return Catalog.price(key)
end

local function tierKey(item: Wardrobe.Item): string?
	if not item.robux then
		return nil
	end
	return "tier" .. tostring(Wardrobe.tierFor(item.robux))
end

local function standingOf(data: Profiles.Data): string
	return (Standing.of(data.nights.count, data.stats.rounds))
end

local function inFirstWeek(data: Profiles.Data): boolean
	return data.firstVisit > 0 and os.time() - data.firstVisit <= ProductConfig.byKey.introduction.Rules.FirstDays * 86400
end

local function introductionItems(): { Wardrobe.Item }
	local out = {}
	for _, item in Wardrobe.all do
		if item.source == "introduction" then
			table.insert(out, item)
		end
	end
	return out
end

local function introductionReady(): boolean
	for _, item in introductionItems() do
		if not Wardrobe.deliverable(item) then
			return false
		end
	end
	return true
end

-- What a guest's screen needs about themselves.
local function mine(data: Profiles.Data): { [string]: any }
	local owned = {}
	for id in data.owned do
		table.insert(owned, id)
	end
	local ledger = LedgerService.view(data)
	return {
		op = "state",
		owned = owned,
		equipped = data.equipped,
		gilt = data.gilt,
		goldKey = data.goldKey,
		doubleGilt = data.doubleGilt,
		blackCard = { held = data.blackCard.active, offered = BlackCard.offered() },
		suite = data.suite,
		credits = data.credits,
		ledger = { page = ledger.page, pages = ledger.pages, progress = ledger.progress, leather = ledger.leather, term = ledger.term },
	}
end

function Shop.push(player: Player)
	local data = Profiles.get(player)
	if data then
		shopEvent:FireClient(player, mine(data))
	end
end

-- A piece as the guest's screen shows it.
local function card(item: Wardrobe.Item, data: Profiles.Data): { [string]: any }
	local key = tierKey(item)
	local robux = if key and item.source ~= "gilt" and item.source ~= "standing" then price(key) else nil
	local locked = item.standing ~= nil and not Standing.atLeast(data.nights.count, data.stats.rounds, item.standing)
	return {
		id = item.id,
		name = item.name,
		kind = item.kind,
		kindName = Wardrobe.KindNames[item.kind],
		line = item.line,
		robux = robux,
		gilt = item.gilt,
		standing = item.standing,
		locked = locked,
		owned = Dressing.canWear(data, item),
		style = item.style,
	}
end

-- One-time products a guest already holds aren't offered again.
local function holds(data: Profiles.Data, entry: ProductConfig.Entry): boolean
	if entry.Handler == "doubleGilt" then
		return data.doubleGilt
	elseif entry.Handler == "goldKey" then
		return data.goldKey
	elseif entry.Handler == "velocity" then
		return data.perks.velocity
	end
	return false
end

-- What the guest's screen shows under an offer, beyond its line (time left, a place in line).
local function status(state: { [string]: any }, entry: ProductConfig.Entry): string?
	if entry.Handler == "luck" and state.luck and state.luck.remaining > 0 then
		return string.format("Active: %d minutes of play left", math.ceil(state.luck.remaining / 60))
	elseif entry.Handler == "rain" and state.rain and state.rain.held > 0 then
		return "Your rain is waiting its turn"
	elseif entry.Handler == "decree" and state.decree and state.decree.held > 0 then
		return string.format("You hold %d decree%s", state.decree.held, if state.decree.held == 1 then "" else "s")
	end
	return nil
end

-- The offers, as the Boutique's first page and the Shop key show them: the catalog's offers
-- (ProductConfig UX.Offer) in its order, only what's on sale, never what's already held. A
-- product that can't be bought just now says why instead of hiding.
function Shop.offers(player: Player, data: Profiles.Data): { { [string]: any } }
	local out = {}
	local entries = {}
	for _, e in ProductConfig.List do
		if e.UX.Offer then
			table.insert(entries, e)
		end
	end
	table.sort(entries, function(a, b)
		return a.UX.Order < b.UX.Order
	end)
	local state = Perks.state(player, data)
	for _, e in entries do
		local sell = Store.sellable(e.Key)
		if not sell or holds(data, e) then
			continue
		end
		local o: { [string]: any } = {
			key = e.Key,
			name = e.UX.DisplayName,
			line = e.UX.Line,
			price = price(sell),
			category = e.UX.Category,
			action = e.UX.Action,
			status = status(state, e),
		}
		if e.Key == "doubleGilt" then
			o.best = true
		elseif e.Key == "giltPurse2" then
			o.best = data.doubleGilt
		end
		if e.UX.Action == "prompt" then
			local check = Store.eligibility[sell]
			if check then
				local ok, why = check(player, data)
				if not ok then
					o.disabled = true
					o.why = why
				end
			end
		end
		table.insert(out, o)
	end
	return out
end

local function shelves(player: Player, data: Profiles.Data): { [string]: any }
	local season = Season.current()
	local offers = Shop.offers(player, data)
	local shown = {}
	for _, o in offers do
		table.insert(shown, o.key)
	end
	Store.impressions(player, shown)
	local function cards(list: { Wardrobe.Item }): { { [string]: any } }
		local out = {}
		for _, item in list do
			table.insert(out, card(item, data))
		end
		return out
	end
	local seasonPieces = {}
	for _, item in Wardrobe.seasonPieces(season.id) do
		if Wardrobe.deliverable(item) then
			table.insert(seasonPieces, item)
		end
	end
	local guests = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and Profiles.get(other) then
			table.insert(guests, { userId = other.UserId, name = other.DisplayName })
		end
	end
	local ledger = LedgerService.view(data)
	local intro = nil
	if not data.introduction and inFirstWeek(data) and introductionReady() and Catalog.enabled("introduction") then
		intro = { price = price("introduction"), items = cards(introductionItems()) }
	end
	return {
		always = cards(Boutique.always()),
		salutes = (function()
			local out = {}
			for _, s in Salutes.List do
				local key = "salute_" .. s.id
				table.insert(out, { id = s.id, name = s.name, line = s.line, price = price(key), ready = Catalog.enabled(key) })
			end
			return out
		end)(),
		saluteWaiting = SaluteService.waiting(),
		today = cards(Boutique.today()),
		featured = cards(Boutique.featured()),
		season = { id = season.id, name = season.name, price = price("season"), pieces = cards(seasonPieces) },
		gilt = cards(Wardrobe.giltPool()),
		goldKey = { owned = data.goldKey, price = (function(): number?
			local sell = Store.sellable("goldKey")
			return if sell then price(sell) else nil
		end)(), giftPrice = price("goldKeyGift"), giftable = Catalog.enabled("goldKeyGift") },
		ledger = {
			view = ledger,
			price = if ledger.leather then nil else price("ledger"),
		},
		introduction = intro,
		offers = offers,
		guests = guests,
		standing = standingOf(data),
		balance = data.gilt,
		credits = data.credits,
	}
end

---------------------------------------------------------------------------------------------------
-- Granting (each handler runs inside a receipt, as one transaction: see Purchases/Grants)
---------------------------------------------------------------------------------------------------
local function own(player: Player, data: Profiles.Data, item: Wardrobe.Item)
	data.owned[item.id] = true
	-- A Suite piece goes straight into its spot when the spot is empty: bought, and there it is.
	local spotId = Suite.spotOf(item)
	local spot = if spotId then Suite.byId[spotId] else nil
	if spotId and spot and (data.suite :: { [string]: string? })[spotId] == nil and Suite.roomOpen(spot.room, data.goldKey) then
		(data.suite :: { [string]: string? })[spotId] = item.id
	end
	Analytics.custom(player, "Boutique item granted", nil, { item.id, item.kind, item.source })
end

-- A credit good for any piece at its tier or below.
local function credit(data: Profiles.Data, key: string)
	data.credits[key] = (data.credits[key] or 0) + 1
end

local function useCredit(data: Profiles.Data, item: Wardrobe.Item): boolean
	local need = Wardrobe.tierFor(item.robux or 0)
	for _, tier in Wardrobe.Tiers do
		local key = "tier" .. tostring(tier)
		if tier >= need and (data.credits[key] or 0) > 0 then
			data.credits[key] -= 1
			if data.credits[key] <= 0 then
				data.credits[key] = nil
			end
			return true
		end
	end
	return false
end

local function notice(player: Player, title: string, line: string)
	shopEvent:FireClient(player, { op = "notice", title = title, line = line })
end

-- Outside a receipt (a piece paid for with credit), the same steps as a grant, applied at once.
local function direct(player: Player, data: Profiles.Data): any
	return {
		player = player,
		data = data,
		touch = function(_self: any, other: Player): Profiles.Data?
			return Profiles.get(other)
		end,
		after = function(_self: any, fn: () -> ())
			fn()
		end,
	}
end

-- Gives a piece to another guest in the house (`ctx`: a grant's context, or `direct`). If they've
-- gone (or already have it), the buyer keeps a credit instead.
local function giftTo(ctx: any, recipientId: number, item: Wardrobe.Item, key: string): boolean
	local player, data = ctx.player :: Player, ctx.data :: Profiles.Data
	local recipient = Players:GetPlayerByUserId(recipientId)
	local present = if recipient then Profiles.get(recipient) else nil
	-- (Regional pricing: a gift only goes to a guest whose price level isn't above the giver's.)
	if not recipient or not present or present.owned[item.id] or not PriceLevels.canGift(player, recipient) then
		credit(data, key)
		ctx:after(function()
			notice(player, "The Boutique", "Your gift couldn't be handed over, so it's kept as credit.")
		end)
		return false
	end
	local rdata = ctx:touch(recipient) :: Profiles.Data
	own(recipient, rdata, item)
	table.insert(rdata.gifts, { from = player.DisplayName, item = item.id, at = os.time() })
	while #rdata.gifts > 20 do
		table.remove(rdata.gifts, 1)
	end
	ctx:after(function()
		shopEvent:FireClient(recipient, { op = "gift", from = player.DisplayName, item = card(item, rdata) })
		Shop.handOver(recipient, player.DisplayName, item.name)
		Shop.push(recipient)
		Analytics.custom(player, "Boutique gift sent", nil, { item.id })
	end)
	return true
end

-- Something a guest bought already belongs to them: it becomes Boutique credit, never lost.
local function duplicate(ctx: Grants.Context, title: string, line: string)
	credit(ctx.data, ctx.product.Rules.DuplicateCredit or "tier99")
	local player = ctx.player
	ctx:after(function()
		notice(player, title, line)
	end)
end

local function registerHandlers()
	-- A Boutique price tier: the piece the guest chose (for them, or as a gift), or credit.
	Grants.register("boutiqueTier", function(ctx: Grants.Context)
		local player, data, key = ctx.player, ctx.data, ctx.key
		local p = data.pending
		local item = if p.item ~= "" then Wardrobe.get(p.item) else nil
		if p.product == key and item and os.time() - p.at <= Config.data.Products.choiceSeconds then
			data.pending = { product = "", item = "", giftTo = 0, at = 0 }
			if p.giftTo ~= 0 then
				giftTo(ctx, p.giftTo, item, key)
			elseif data.owned[item.id] then
				credit(data, key)
			else
				own(player, data, item)
			end
		else
			-- No choice on file (it expired, or the purchase came from elsewhere): credit.
			credit(data, key)
		end
		ctx:after(function()
			Shop.push(player)
		end)
	end)

	-- The Gold Key for another guest; if they've gone (or hold it), it's the buyer's (or credit).
	Grants.register("goldKeyGift", function(ctx: Grants.Context)
		local player, data = ctx.player, ctx.data
		local p = data.pending
		local recipient = if p.product == ctx.key and p.giftTo ~= 0 then Players:GetPlayerByUserId(p.giftTo) else nil
		local present = if recipient then Profiles.get(recipient) else nil
		data.pending = { product = "", item = "", giftTo = 0, at = 0 }
		if recipient and present and not present.goldKey and PriceLevels.canGift(player, recipient) then
			local rdata = ctx:touch(recipient) :: Profiles.Data
			rdata.goldKey = true
			table.insert(rdata.gifts, { from = player.DisplayName, item = "goldKey", at = os.time() })
			while #rdata.gifts > 20 do
				table.remove(rdata.gifts, 1)
			end
			ctx:after(function()
				notice(recipient, "The Gold Key", player.DisplayName .. " gave you the Gold Key.")
				Shop.handOver(recipient, player.DisplayName, "the Gold Key")
				Dressing.nameplate(recipient)
				Shop.push(recipient)
				Analytics.custom(player, "Gold Key gifted", nil, nil)
			end)
		elseif not data.goldKey then
			data.goldKey = true
			ctx:after(function()
				notice(player, "The Gold Key", "Your gift couldn't be handed over, so the Gold Key is yours.")
				Dressing.nameplate(player)
			end)
		else
			credit(data, "tier499")
			ctx:after(function()
				notice(player, "The Gold Key", "Your gift couldn't be handed over, so it's kept as Boutique credit.")
			end)
		end
		ctx:after(function()
			Shop.push(player)
		end)
	end)

	-- A Gilt purse: its Gilt, at once.
	Grants.register("gilt", function(ctx: Grants.Context)
		local amount = ctx.product.Reward.Amount :: number
		local player, data = ctx.player, ctx.data
		data.gilt += amount
		ctx:after(function()
			Analytics.source(player, "Gilt", amount, data.gilt, "Purchase")
			notice(player, "Gilt", string.format("+%s Gilt. Thank you.", Gilt.format(amount)))
			Gilt.changed(player)
		end)
	end)

	Grants.register("doubleGilt", function(ctx: Grants.Context)
		if ctx.data.doubleGilt then
			duplicate(ctx, "Double Gilt", "Double Gilt was already yours, so this one is kept as Boutique credit.")
			return
		end
		ctx.data.doubleGilt = true
		local player = ctx.player
		ctx:after(function()
			notice(player, "Double Gilt", "Every Gilt you earn is doubled, for good.")
			Shop.push(player)
		end)
	end)

	-- A Golden Hour for the whole house: kept as a credit, started as soon as the receipt is
	-- acknowledged (and on the buyer's next arrival if this server stopped first).
	Grants.register("goldenHour", function(ctx: Grants.Context)
		Perks.add(ctx.data, "goldenHour", 1)
		local player = ctx.player
		ctx:after(function()
			Perks.tryAuto(player, "goldenHour")
		end)
	end)
	Perks.autoUse.goldenHour = function(player: Player, data: Profiles.Data): boolean
		if not Perks.use(player, data, "goldenHour", "goldenHour") then
			return false
		end
		Shop.goldenHour(player, ProductConfig.byKey.goldenHour.Reward.Minutes * 60)
		return true
	end

	-- The Gold Key as a developer product (the game pass is granted by Roblox's ownership check).
	Grants.register("goldKey", function(ctx: Grants.Context)
		if ctx.data.goldKey then
			duplicate(ctx, "The Gold Key", "The Gold Key was already yours, so this one is kept as Boutique credit.")
			return
		end
		ctx.data.goldKey = true
		local player = ctx.player
		ctx:after(function()
			notice(player, "The Gold Key", "The Gold Key is yours.")
			Dressing.nameplate(player)
			Shop.push(player)
		end)
	end)

	Grants.register("introduction", function(ctx: Grants.Context)
		if ctx.data.introduction then
			duplicate(ctx, "The Introduction", "The Introduction was already yours, so this one is kept as Boutique credit.")
			return
		end
		ctx.data.introduction = true
		for _, item in introductionItems() do
			own(ctx.player, ctx.data, item)
		end
		local player = ctx.player
		ctx:after(function()
			Shop.push(player)
		end)
	end)

	-- A salute: kept as a credit and played as soon as the receipt is acknowledged.
	Grants.register("salute", function(ctx: Grants.Context)
		local key = "salute_" .. tostring(ctx.product.Reward.Salute)
		Perks.add(ctx.data, key, 1)
		local player = ctx.player
		ctx:after(function()
			Perks.tryAuto(player, key)
		end)
	end)
	for _, salute in Salutes.List do
		local key = "salute_" .. salute.id
		Perks.autoUse[key] = function(player: Player, data: Profiles.Data): boolean
			if not Perks.use(player, data, key, key) then
				return false
			end
			SaluteService.play(player, salute.id)
			return true
		end
	end

	Grants.register("ledger", function(ctx: Grants.Context)
		if LedgerService.view(ctx.data).leather then
			duplicate(ctx, "The Ledger", "This Term's Leather-Bound Ledger was already yours, so this one is kept as Boutique credit.")
			return
		end
		LedgerService.bindLeather(ctx.player, ctx.data, true)
		local player = ctx.player
		ctx:after(function()
			LedgerService.changed(player, nil)
		end)
	end)

	Grants.register("season", function(ctx: Grants.Context)
		local granted = 0
		for _, item in Wardrobe.seasonPieces(Season.current().id) do
			if Wardrobe.deliverable(item) and not ctx.data.owned[item.id] then
				own(ctx.player, ctx.data, item)
				granted += 1
			end
		end
		if granted == 0 then
			duplicate(ctx, "The Season Collection", "The season's pieces were already yours, so this one is kept as Boutique credit.")
		end
		local player = ctx.player
		ctx:after(function()
			Shop.push(player)
		end)
	end)
end

-- Who may be shown each Boutique product's purchase window (checked on the server whenever one
-- is asked for, whatever asked).
local function registerEligibility()
	Store.eligibility.doubleGilt = function(_player: Player, data: Profiles.Data): (boolean, string?)
		return not data.doubleGilt, "Double Gilt is yours."
	end
	local function goldKey(_player: Player, data: Profiles.Data): (boolean, string?)
		return not data.goldKey, "The Gold Key is yours."
	end
	Store.eligibility.goldKey = goldKey
	Store.eligibility.goldKeyProduct = goldKey
	Store.eligibility.goldKeyGift = function(player: Player, data: Profiles.Data): (boolean, string?)
		local p = data.pending
		local recipient = if p.product == "goldKeyGift" and p.giftTo ~= 0 then Players:GetPlayerByUserId(p.giftTo) else nil
		local rdata = if recipient then Profiles.get(recipient) else nil
		if not recipient or recipient == player or not rdata then
			return false, "That guest isn't in the house just now."
		elseif rdata.goldKey then
			return false, recipient.DisplayName .. " already holds the Gold Key."
		end
		return PriceLevels.canGift(player, recipient, true)
	end
	Store.eligibility.introduction = function(_player: Player, data: Profiles.Data): (boolean, string?)
		if data.introduction or not inFirstWeek(data) or not introductionReady() then
			return false, "The Introduction is only offered in a guest's first week."
		end
		return true, nil
	end
	Store.eligibility.ledger = function(_player: Player, data: Profiles.Data): (boolean, string?)
		local view = LedgerService.view(data)
		if view.card then
			return false, "The Leather-Bound Ledger comes with your Black Card."
		elseif view.leather then
			return false, "This Term's Leather-Bound Ledger is yours."
		end
		return true, nil
	end
	Store.eligibility.season = function(_player: Player, data: Profiles.Data): (boolean, string?)
		for _, item in Wardrobe.seasonPieces(Season.current().id) do
			if Wardrobe.deliverable(item) and not data.owned[item.id] then
				return true, nil
			end
		end
		return false, "The season's pieces are already yours."
	end
	for _, salute in Salutes.List do
		Store.eligibility["salute_" .. salute.id] = function(_player: Player, _data: Profiles.Data): (boolean, string?)
			if SaluteService.full() then
				return false, "A few salutes are already waiting their turn. Try again in a minute."
			end
			return true, nil
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Requests from the Boutique
---------------------------------------------------------------------------------------------------
-- Asks the server's Store to show a purchase window, and says how it went.
local function prompt(player: Player, key: string, context: string): { [string]: any }
	local ok, why = Store.prompt(player, key, context)
	return { ok = ok, why = why, prompted = ok }
end

local function buy(player: Player, data: Profiles.Data, itemId: string, recipientId: number?): { [string]: any }
	local item = Wardrobe.get(itemId)
	if not item or not item.robux then
		return { ok = false, why = "That isn't sold here." }
	end
	if not Boutique.onSale(item.id, Season.current().id) or not Wardrobe.deliverable(item) then
		return { ok = false, why = "That piece isn't on the shelves today." }
	end
	local key = tierKey(item) :: string
	if recipientId then
		local recipient = Players:GetPlayerByUserId(recipientId)
		local rdata = recipient and Profiles.get(recipient)
		if not recipient or recipient == player or not rdata then
			return { ok = false, why = "That guest isn't in the house just now." }
		elseif rdata.owned[item.id] then
			return { ok = false, why = "They already have it." }
		end
		local allowed, why = PriceLevels.canGift(player, recipient, true)
		if not allowed then
			return { ok = false, why = why }
		end
	elseif data.owned[item.id] then
		return { ok = false, why = "It's already yours." }
	end
	-- Credit from an earlier purchase pays for it at once.
	if useCredit(data, item) then
		if recipientId then
			giftTo(direct(player, data), recipientId, item, key)
		else
			own(player, data, item)
		end
		Shop.push(player)
		return { ok = true, credited = true }
	end
	if not Catalog.enabled(key) then
		return { ok = false, why = "The Boutique isn't open for purchases yet." }
	end
	data.pending = { product = key, item = item.id, giftTo = recipientId or 0, at = os.time() }
	return prompt(player, key, if recipientId then "gift" else "shelf")
end

local function buyWithGilt(player: Player, data: Profiles.Data, itemId: string): { [string]: any }
	local item = Wardrobe.get(itemId)
	if not item or not item.gilt or (item.source ~= "gilt" and item.source ~= "standing") then
		return { ok = false, why = "That isn't sold for Gilt." }
	end
	if data.owned[item.id] then
		return { ok = false, why = "It's already yours." }
	end
	if not Wardrobe.deliverable(item) then
		return { ok = false, why = "That piece isn't ready yet." }
	end
	if item.standing and not Standing.atLeast(data.nights.count, data.stats.rounds, item.standing) then
		return { ok = false, why = "That piece is for " .. item.standing .. "s of the house." }
	end
	if data.gilt < item.gilt then
		return { ok = false, why = "Not enough Gilt yet." }
	end
	data.gilt -= item.gilt
	own(player, data, item)
	Analytics.sink(player, "Gilt", item.gilt, data.gilt, item.id)
	Shop.push(player)
	return { ok = true }
end

local onAsk: (player: Player, request: unknown) -> any
onAsk = function(player: Player, request: unknown): any
	-- (Rate-limited and type-checked by RemoteGuard before it gets here; every field is still
	-- checked below before it's used.)
	if RemoteGuard.message(request, 12, 1) == nil then
		return nil
	end
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local r = request :: { [string]: unknown }
	local op = r.op
	if op == "shelves" then
		return shelves(player, data)
	elseif op == "buy" and type(r.item) == "string" then
		local recipient = if type(r.giftTo) == "number" then r.giftTo :: number else nil
		return buy(player, data, r.item :: string, recipient)
	elseif op == "buyGilt" and type(r.item) == "string" then
		return buyWithGilt(player, data, r.item :: string)
	elseif op == "equip" and r.kind == "suite" then
		return { ok = false, why = "Suite pieces are placed from the bell in your Suite." }
	elseif op == "equip" and type(r.kind) == "string" and type(r.id) == "string" then
		local ok = Dressing.equip(player, r.kind :: string, r.id :: string)
		Shop.push(player)
		return { ok = ok }
	elseif op == "goldKey" then
		if data.goldKey then
			return { ok = false, why = "The Gold Key is yours." }
		end
		local sell = Store.sellable("goldKey")
		if not sell then
			return { ok = false, why = "The Gold Key isn't on sale yet." }
		end
		return prompt(player, sell, "goldKey")
	elseif op == "offer" and type(r.key) == "string" then
		local ok, why = Store.promptOffer(player, r.key :: string, "offers")
		return { ok = ok, why = why, prompted = ok }
	elseif op == "offers" then
		local offers = Shop.offers(player, data)
		local keys = {}
		for _, o in offers do
			table.insert(keys, o.key)
		end
		Store.impressions(player, keys)
		return { offers = offers, doubleGilt = data.doubleGilt, gilt = data.gilt }
	elseif op == "goldKeyGift" and type(r.userId) == "number" then
		local recipient = Players:GetPlayerByUserId(r.userId :: number)
		local rdata = recipient and Profiles.get(recipient)
		if not Catalog.enabled("goldKeyGift") then
			return { ok = false, why = "Giving the Gold Key isn't offered yet." }
		elseif not recipient or recipient == player or not rdata then
			return { ok = false, why = "That guest isn't in the house just now." }
		elseif rdata.goldKey then
			return { ok = false, why = recipient.DisplayName .. " already holds the Gold Key." }
		end
		local allowed, why = PriceLevels.canGift(player, recipient, true)
		if not allowed then
			return { ok = false, why = why }
		end
		data.pending = { product = "goldKeyGift", item = "", giftTo = recipient.UserId, at = os.time() }
		return prompt(player, "goldKeyGift", "gift")
	elseif op == "ledgerLeather" then
		return prompt(player, "ledger", "ledger")
	elseif op == "introduction" then
		local ok, why = Store.eligibility.introduction(player, data)
		if not ok then
			return { ok = false, why = why }
		end
		return prompt(player, "introduction", "introduction")
	elseif op == "season" then
		return prompt(player, "season", "season")
	elseif op == "ledger" then
		return LedgerService.view(data)
	elseif op == "register" then
		return Shop.register(data)
	elseif op == "salute" and type(r.id) == "string" then
		if not Salutes.byId[r.id :: string] or not Catalog.enabled("salute_" .. (r.id :: string)) then
			return { ok = false, why = "That salute isn't offered yet." }
		end
		return prompt(player, "salute_" .. (r.id :: string), "salute")
	elseif op == "notify" and (r.answer == "granted" or r.answer == "declined") then
		Analytics.custom(player, if r.answer == "granted" then "Notification opt-in granted" else "Notification opt-in declined", nil, nil)
		return { ok = true }
	elseif op == "admire" and type(r.userId) == "number" then
		return Social.admire(player, r.userId :: number)
	elseif op == "guestBook" then
		return Social.guestBook(player, data)
	elseif op == "sign" and type(r.line) == "number" then
		return Social.sign(player, data, r.line :: number)
	elseif op == "circle" then
		return CircleService.view(player, data)
	elseif op == "circleFound" then
		local result = CircleService.found(player, data, r.choice)
		Shop.push(player)
		return result
	elseif op == "circleInvite" and type(r.userId) == "number" then
		return CircleService.invite(player, data, r.userId :: number)
	elseif op == "circleRequest" and type(r.userId) == "number" then
		return CircleService.request(player, data, r.userId :: number)
	elseif op == "circleAnswer" and type(r.kind) == "string" and type(r.circle) == "string" and type(r.from) == "number" then
		return CircleService.answer(player, data, r.kind :: string, r.circle :: string, r.from :: number, r.yes == true)
	elseif op == "circleLeave" then
		return CircleService.leave(player, data)
	elseif op == "suite" then
		return Shop.suite(data)
	elseif op == "place" and type(r.spot) == "string" and type(r.id) == "string" then
		return Shop.place(player, data, r.spot :: string, r.id :: string)
	elseif op == "blackCard" then
		return { offered = BlackCard.offered(), held = data.blackCard.active, price = BlackCard.price(), look = (Wardrobe.cardholderLook() or {} :: any).name }
	elseif op == "holdCard" then
		if data.blackCard.active then
			return { ok = false, why = "You hold the Black Card." }
		elseif not BlackCard.offered() then
			return { ok = false, why = "The Black Card isn't offered yet." }
		end
		return { ok = BlackCard.offer(player), prompted = true }
	elseif op == "wardrobe" then
		local out = {}
		for _, kind in Wardrobe.Kinds do
			local pieces = {}
			for id in data.owned do
				local item = Dressing.item(id)
				if item and item.kind == kind then
					table.insert(pieces, card(item, data))
				end
			end
			for _, item in Wardrobe.all do
				if item.kind == kind and not data.owned[item.id] and ((item.source == "goldKey" and data.goldKey) or (item.source == "blackCard" and Dressing.canWear(data, item))) then
					table.insert(pieces, card(item, data))
				end
			end
			table.sort(pieces, function(a, b)
				return a.name < b.name
			end)
			out[kind] = pieces
		end
		return { kinds = out, equipped = data.equipped, names = Wardrobe.KindNames }
	end
	return nil
end

-- The Suite, spot by spot: what's there and what the guest could put there.
function Shop.suite(data: Profiles.Data): { [string]: any }
	local spots = {}
	for _, spot in Suite.Spots do
		local options = {}
		for _, item in Suite.piecesFor(spot.id) do
			local mine = Dressing.canWear(data, item)
			table.insert(options, {
				id = item.id,
				name = item.name,
				line = item.line,
				owned = mine,
				source = item.source,
				gilt = item.gilt,
				robux = item.robux,
				standing = item.standing,
				-- Robux pieces are sold from the Boutique's shelves on the days they're out.
				onSale = item.robux ~= nil and Boutique.onSale(item.id, Season.current().id) and Wardrobe.deliverable(item),
			})
		end
		table.insert(spots, {
			id = spot.id,
			name = spot.name,
			room = spot.room,
			open = Suite.roomOpen(spot.room, data.goldKey),
			house = spot.house,
			placed = data.suite[spot.id] or "",
			options = options,
		})
	end
	return { spots = spots, rooms = Suite.RoomNames, gilt = data.gilt, goldKey = data.goldKey }
end

-- Puts a piece in a spot of the guest's Suite ("" takes it away).
function Shop.place(player: Player, data: Profiles.Data, spotId: string, id: string): { [string]: any }
	local item = if id ~= "" then Wardrobe.get(id) else nil
	if id ~= "" and not item then
		return { ok = false, why = "That piece isn't known." }
	end
	local ok, why = Suite.canPlace(spotId, item, item ~= nil and Dressing.canWear(data, item), data.goldKey)
	if not ok then
		return { ok = false, why = why }
	end
	-- (An empty spot shows the house's own piece, or nothing.)
	(data.suite :: { [string]: string? })[spotId] = if id ~= "" then id else nil
	Shop.push(player)
	return { ok = true }
end

local function syncGoldKey(player: Player)
	local id = Catalog.idOf("goldKey")
	local data = Profiles.get(player)
	if id == 0 or not data then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	if ok and owns and not data.goldKey then
		data.goldKey = true
		Dressing.nameplate(player)
		Shop.push(player)
	end
end

-- Opens a panel on a guest's screen ("boutique", "wardrobe" or "ledger").
function Shop.open(player: Player, panel: string)
	shopEvent:FireClient(player, { op = "open", panel = panel })
end

-- The dress form wears the week's first featured piece; its plate names both.
local function dressTheForm()
	local featured = Boutique.featured()
	local maison = workspace:FindFirstChild("Maison")
	local room = maison and maison:FindFirstChild("Boutique")
	if not room then
		return
	end
	local first = featured[1]
	for _, d in room:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("DressForm") and first then
			local colour = first.style.felt or first.style.colour or first.style.back or first.style.frame
			if typeof(colour) == "Color3" then
				d.Color = colour
			end
		elseif d:IsA("BasePart") and d:GetAttribute("FeaturedPlate") then
			local gui = d:FindFirstChildOfClass("SurfaceGui")
			local labels = {}
			if gui then
				for _, l in gui:GetDescendants() do
					if l:IsA("TextLabel") then
						table.insert(labels, l)
					end
				end
			end
			if labels[2] and #featured > 0 then
				local names = {}
				for _, item in featured do
					table.insert(names, item.name)
				end
				labels[2].Text = table.concat(names, " · ")
			end
		end
	end
end

function Shop.start()
	registerHandlers()
	registerEligibility()
	local CollectionService = game:GetService("CollectionService")
	local panels: { [string]: string } = { BoutiqueCounter = "boutique", WardrobeMirror = "wardrobe", LedgerBook = "ledger", RegisterBook = "register", BlackCardLectern = "blackCard", SuiteFurnish = "suite", CircleBook = "circles", SaluteDesk = "salutes", GuestBook = "guestBook" }
	for tag, panel in panels do
		for _, part in CollectionService:GetTagged(tag) do
			local p = part:FindFirstChildOfClass("ProximityPrompt")
			if p then
				p.Triggered:Connect(function(player: Player)
					Shop.open(player, panel)
				end)
			end
		end
	end
	task.spawn(function()
		while true do
			dressTheForm()
			task.wait(600)
		end
	end)
	RemoteGuard.invoke(Remotes.func("ShopAsk"), "shopAsk", onAsk)
	-- The Gold Key pass bought here: confirmed with Roblox (UserOwnsGamePassAsync) before it's
	-- given, since the "purchase finished" event only says a window closed. (In Studio, where a
	-- pass "bought" is a free test purchase Roblox never records as owned, the event is enough.)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if not purchased or passId ~= Catalog.idOf("goldKey") then
			return
		end
		task.spawn(function()
			for attempt = 1, ProductConfig.Settings.PassConfirmTries do
				local data = Profiles.get(player)
				if not data or player.Parent ~= Players or data.goldKey then
					return
				end
				local ok, owns = pcall(function()
					return game:GetService("RunService"):IsStudio() or MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
				end)
				if ok and owns then
					data.goldKey = true
					Analytics.custom(player, "Gold Key bought", nil, nil)
					Dressing.nameplate(player)
					Shop.push(player)
					return
				end
				task.wait(attempt * 2)
			end
		end)
	end)
	BlackCard.changed = function(player: Player, notice: string?)
		local data = Profiles.get(player)
		if data then
			LedgerService.claim(player, data)
		end
		Dressing.nameplate(player)
		Shop.push(player)
		if notice then
			shopEvent:FireClient(player, { op = "notice", title = "The Black Card", line = notice })
		end
	end
	BlackCard.start()
	Profiles.Loaded:Connect(function(player: Player, data: Profiles.Data)
		LedgerService.claim(player, data)
		task.spawn(syncGoldKey, player)
		Shop.push(player)
	end)
	LedgerService.changed = function(player: Player, pages: { number }?)
		if pages then
			shopEvent:FireClient(player, { op = "pages", pages = pages })
		end
		Shop.push(player)
	end
	Gilt.changed = function(player: Player)
		Shop.push(player)
	end
end

return Shop

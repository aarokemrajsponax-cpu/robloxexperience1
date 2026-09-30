--!strict
-- The Boutique and the money (§12, Appendix I). Robux buys style, never score. Every price is
-- read live from Roblox. The rotating shelves sell through one developer product per price tier:
-- the guest chooses a piece, the server keeps that choice in their saved profile, and the receipt
-- grants it. Receipts are idempotent: the purchase is written into the profile, the profile is
-- saved, and only then is Roblox told it was granted. Gifts go to another guest in the house and
-- the Concierge hands them over. Gilt buys the house's own pieces and is never sold.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boutique = require(ReplicatedStorage.Shared.Boutique)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Standing = require(ReplicatedStorage.Shared.Standing)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)

local Analytics = require(script.Parent.Analytics)
local BlackCard = require(script.Parent.BlackCard)
local Dressing = require(script.Parent.Dressing)
local Gilt = require(script.Parent.Gilt)
local LedgerService = require(script.Parent.LedgerService)
local Profiles = require(script.Parent.Profiles)
local Season = require(script.Parent.Season)

local Shop = {}

-- The Register's view of a guest (set by Main).
Shop.register = function(_data: Profiles.Data): any
	return nil
end

-- The Concierge's handover of a gift (set by Main).
Shop.handOver = function(_recipient: Player, _from: string, _itemName: string) end

local shopEvent = Remotes.event("Shop")
local RECEIPTS_KEPT = 100
local PENDING_SECONDS = 3600
local PRICE_SECONDS = 300

local prices: { [number]: { price: number?, at: number } } = {}
local asks: { [Player]: { number } } = {}

local function products()
	return Config.data.Products :: any
end

-- The product a key names ("tier249", "introduction", "ledger", "season"), or 0.
local function productId(key: string): number
	local id = products()[key]
	return if type(id) == "number" then id else 0
end

local PRODUCT_KEYS = { "introduction", "ledger", "season" }
for _, tier in Wardrobe.Tiers do
	table.insert(PRODUCT_KEYS, "tier" .. tostring(tier))
end

local function keyForProduct(id: number): string?
	if id == 0 then
		return nil
	end
	for _, key in PRODUCT_KEYS do
		if productId(key) == id then
			return key
		end
	end
	return nil
end

-- A price read live from Roblox (cached for a few minutes). nil when not on sale.
local function livePrice(id: number, info: Enum.InfoType): number?
	if id == 0 then
		return nil
	end
	local cached = prices[id]
	if cached and os.clock() - cached.at < PRICE_SECONDS then
		return cached.price
	end
	local ok, result = pcall(function()
		return MarketplaceService:GetProductInfo(id, info)
	end)
	local price = if ok and type(result) == "table" and type(result.PriceInRobux) == "number" then result.PriceInRobux else nil
	prices[id] = { price = price, at = os.clock() }
	return price
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
	return data.firstVisit > 0 and os.time() - data.firstVisit <= products().introductionDays * 86400
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
		blackCard = { held = data.blackCard.active, offered = BlackCard.offered() },
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
	local price = if key and item.source ~= "gilt" and item.source ~= "standing" then livePrice(productId(key), Enum.InfoType.Product) else nil
	local locked = item.standing ~= nil and not Standing.atLeast(data.nights.count, data.stats.rounds, item.standing)
	return {
		id = item.id,
		name = item.name,
		kind = item.kind,
		kindName = Wardrobe.KindNames[item.kind],
		line = item.line,
		robux = price,
		gilt = item.gilt,
		standing = item.standing,
		locked = locked,
		owned = Dressing.canWear(data, item),
		style = item.style,
	}
end

local function shelves(player: Player, data: Profiles.Data): { [string]: any }
	local season = Season.current()
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
	if not data.introduction and inFirstWeek(data) and introductionReady() and productId("introduction") ~= 0 then
		intro = { price = livePrice(productId("introduction"), Enum.InfoType.Product), items = cards(introductionItems()) }
	end
	return {
		today = cards(Boutique.today()),
		featured = cards(Boutique.featured()),
		season = { id = season.id, name = season.name, price = livePrice(productId("season"), Enum.InfoType.Product), pieces = cards(seasonPieces) },
		gilt = cards(Wardrobe.giltPool()),
		goldKey = { owned = data.goldKey, price = livePrice(productId("goldKey"), Enum.InfoType.GamePass) },
		ledger = {
			view = ledger,
			price = if ledger.leather then nil else livePrice(productId("ledger"), Enum.InfoType.Product),
		},
		introduction = intro,
		guests = guests,
		standing = standingOf(data),
		balance = data.gilt,
		credits = data.credits,
	}
end

---------------------------------------------------------------------------------------------------
-- Granting
---------------------------------------------------------------------------------------------------
local function own(player: Player, data: Profiles.Data, item: Wardrobe.Item)
	data.owned[item.id] = true
	Analytics.custom(player, "Boutique item granted", nil, { item = item.id, kind = item.kind, source = item.source })
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

local function giftTo(player: Player, data: Profiles.Data, recipientId: number, item: Wardrobe.Item, key: string): boolean
	local recipient = Players:GetPlayerByUserId(recipientId)
	local rdata = recipient and Profiles.get(recipient)
	if not recipient or not rdata or rdata.owned[item.id] then
		-- They've gone (or already have it): the buyer keeps a credit instead.
		credit(data, key)
		shopEvent:FireClient(player, { op = "notice", title = "The Boutique", line = "Your gift couldn't be handed over, so it's kept as credit." })
		return false
	end
	own(recipient, rdata, item)
	table.insert(rdata.gifts, { from = player.DisplayName, item = item.id, at = os.time() })
	while #rdata.gifts > 20 do
		table.remove(rdata.gifts, 1)
	end
	shopEvent:FireClient(recipient, { op = "gift", from = player.DisplayName, item = card(item, rdata) })
	Shop.handOver(recipient, player.DisplayName, item.name)
	Shop.push(recipient)
	Analytics.custom(player, "Boutique gift sent", nil, { item = item.id })
	return true
end

-- Grants whatever a receipt's product buys. Runs inside the receipt, before the save.
local function grant(player: Player, data: Profiles.Data, key: string)
	if string.sub(key, 1, 4) == "tier" then
		local p = data.pending
		local item = if p.item ~= "" then Wardrobe.get(p.item) else nil
		if p.product == key and item and os.time() - p.at <= PENDING_SECONDS then
			data.pending = { product = "", item = "", giftTo = 0, at = 0 }
			if p.giftTo ~= 0 then
				giftTo(player, data, p.giftTo, item, key)
			elseif data.owned[item.id] then
				credit(data, key)
			else
				own(player, data, item)
			end
		else
			-- No choice on file (it expired, or the purchase came from elsewhere): keep it as credit.
			credit(data, key)
		end
	elseif key == "introduction" then
		data.introduction = true
		for _, item in introductionItems() do
			own(player, data, item)
		end
	elseif key == "ledger" then
		LedgerService.bindLeather(player, data)
	elseif key == "season" then
		for _, item in Wardrobe.seasonPieces(Season.current().id) do
			if Wardrobe.deliverable(item) then
				own(player, data, item)
			end
		end
	end
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = Profiles.profile(player)
	if not profile then
		Profiles.wait(player, 15)
		profile = Profiles.profile(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
	local data = profile.Data :: Profiles.Data
	local id = tostring(info.PurchaseId)
	local key = keyForProduct(info.ProductId)
	if not table.find(data.receipts, id) then
		-- Written into the profile first...
		table.insert(data.receipts, id)
		while #data.receipts > RECEIPTS_KEPT do
			table.remove(data.receipts, 1)
		end
		if key then
			grant(player, data, key)
		end
		Analytics.custom(player, "Boutique purchase", info.CurrencySpent, { product = key or tostring(info.ProductId), item = data.pending.item })
	end
	Shop.push(player)
	if Profiles.isMock() then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- ...and acknowledged only once a save holding it has gone through.
	local saved = false
	local function check(last: any)
		if type(last) == "table" and type(last.receipts) == "table" and table.find(last.receipts, id) then
			saved = true
		end
	end
	check(profile.LastSavedData)
	if not saved then
		local conn = profile.OnAfterSave:Connect(check)
		profile:Save()
		local waited = 0
		while not saved and profile:IsActive() and waited < 30 do
			task.wait(0.1)
			waited += 0.1
		end
		conn:Disconnect()
	end
	return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

---------------------------------------------------------------------------------------------------
-- Requests from the Boutique
---------------------------------------------------------------------------------------------------
local function prompt(player: Player, key: string): boolean
	local id = productId(key)
	if id == 0 then
		return false
	end
	local ok = pcall(function()
		MarketplaceService:PromptProductPurchase(player, id)
	end)
	return ok
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
	elseif data.owned[item.id] then
		return { ok = false, why = "It's already yours." }
	end
	-- Credit from an earlier purchase pays for it at once.
	if useCredit(data, item) then
		if recipientId then
			giftTo(player, data, recipientId, item, key)
		else
			own(player, data, item)
		end
		Shop.push(player)
		return { ok = true, credited = true }
	end
	if productId(key) == 0 then
		return { ok = false, why = "The Boutique isn't open for purchases yet." }
	end
	data.pending = { product = key, item = item.id, giftTo = recipientId or 0, at = os.time() }
	return { ok = prompt(player, key), prompted = true }
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

local function onAsk(player: Player, request: unknown): any
	if type(request) ~= "table" then
		return nil
	end
	-- A light limit: ten asks a second.
	local now = os.clock()
	local list = asks[player] or {}
	asks[player] = list
	table.insert(list, now)
	while #list > 0 and now - list[1] > 1 do
		table.remove(list, 1)
	end
	if #list > 10 then
		return { ok = false, why = "One moment." }
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
	elseif op == "equip" and type(r.kind) == "string" and type(r.id) == "string" then
		local ok = Dressing.equip(player, r.kind :: string, r.id :: string)
		Shop.push(player)
		return { ok = ok }
	elseif op == "goldKey" then
		local id = productId("goldKey")
		if id == 0 or data.goldKey then
			return { ok = false, why = if data.goldKey then "The Gold Key is yours." else "The Gold Key isn't on sale yet." }
		end
		pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, id)
		end)
		return { ok = true, prompted = true }
	elseif op == "ledgerLeather" then
		local view = LedgerService.view(data)
		if view.card then
			return { ok = false, why = "The Leather-Bound Ledger comes with your Black Card." }
		elseif view.leather then
			return { ok = false, why = "This Term's Leather-Bound Ledger is yours." }
		end
		return { ok = prompt(player, "ledger"), prompted = true }
	elseif op == "introduction" then
		if data.introduction or not inFirstWeek(data) or not introductionReady() then
			return { ok = false, why = "The Introduction is only offered in a guest's first week." }
		end
		return { ok = prompt(player, "introduction"), prompted = true }
	elseif op == "season" then
		return { ok = prompt(player, "season"), prompted = true }
	elseif op == "ledger" then
		return LedgerService.view(data)
	elseif op == "register" then
		return Shop.register(data)
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

local function syncGoldKey(player: Player)
	local id = productId("goldKey")
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
	MarketplaceService.ProcessReceipt = processReceipt
	local CollectionService = game:GetService("CollectionService")
	local panels: { [string]: string } = { BoutiqueCounter = "boutique", WardrobeMirror = "wardrobe", LedgerBook = "ledger", RegisterBook = "register", BlackCardLectern = "blackCard" }
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
	Remotes.func("ShopAsk").OnServerInvoke = onAsk
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		if purchased and passId == productId("goldKey") then
			local data = Profiles.get(player)
			if data then
				data.goldKey = true
				Analytics.custom(player, "Gold Key bought", nil, nil)
				Dressing.nameplate(player)
				Shop.push(player)
			end
		end
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
	Players.PlayerRemoving:Connect(function(player: Player)
		asks[player] = nil
	end)
end

return Shop

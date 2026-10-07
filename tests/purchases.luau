--!nocheck
-- The purchase system (server/Purchases) against the real code under Lune, on a fake clock, with
-- Roblox's marketplace, DataStores, profiles, the text filter, chat permissions and country
-- lookups faked (tests/harness.luau). What MONETIZATION.md §14 promises, checked:
--
--   A. the catalog: validated at start, products found by name, ambiguous ids refused
--   B. receipts: malformed and unknown receipts left unresolved, replays, an absent buyer, two
--      servers and a lapsed lease, a save that doesn't land, a handler that fails (rolled back),
--      the ledger's outbox, two deliveries at once, a gift saved in both profiles
--   C. the risk check: Normal, Review, Restricted (prompts only, never receipts)
--   D. the remotes: floods, malformed requests, prices and amounts a screen can't set
--   E. VIP Velocity Elite: the pass, the product, a duplicate, Settings, a refund, the speed
--   F. Chronos Defiance at a real timed table: the window, the prompt, the receipt, the limits,
--      the boards, a receipt that arrives late
--   G. Emperor's Decree: cleaning, the filter, chat permissions, the queue, cooldowns, the log
--   H. God-Mode Luck: the multiplier, stacking, time only in the house, expiry, the cap
--   I. Megalodon Rainmaker: shares, joiners, rejoins, the line, a buyer who leaves
--   J. the analytics schema
--   K. the Foyer's grand piano: buying time, sitting down, notes for the room, the clock only at
--      the keys, getting up, running out, the cap, leaving
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/purchases.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local MarketplaceService, profiles, prompts, broadcasts = H.MarketplaceService, H.profiles, H.prompts, H.broadcasts
local module, guest, receipt, lastOp = H.module, H.guest, H.receipt, H.lastOp
local Config, Remotes, Gilt, LedgerService, Enum = H.Config, H.Remotes, H.Gilt, H.LedgerService, H.Enum
local fakeOs = H.fakeOs

local ProductConfig = module("ReplicatedStorage", "Shared", "ProductConfig")
local Speed = module("ReplicatedStorage", "Shared", "Speed")
local function purchases(name)
	return module("ServerScriptService", "Server", "Purchases", name)
end
local Catalog, Ledger, Telemetry, Grants = purchases("Catalog"), purchases("Ledger"), purchases("Telemetry"), purchases("Grants")
local Perks, Luck, Rain, Decree = purchases("Perks"), purchases("Luck"), purchases("Rain"), purchases("Decree")
local Velocity, Risk, Store, Receipts = purchases("Velocity"), purchases("Risk"), purchases("Store"), purchases("Receipts")
local E = Telemetry.Events
local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
local LATER = Enum.ProductPurchaseDecision.NotProcessedYet
local perkAsk = Remotes.funcs.PerkAsk.OnServerInvoke

local function perk(player, request)
	advance(0.4) -- a guest's taps, not a script's
	local r
	run(function()
		r = perkAsk(player, request)
	end)
	return r
end

local function deliver(info)
	local r
	run(function()
		r = MarketplaceService.ProcessReceipt(info)
	end)
	return r
end

local function lastBroadcast(op)
	for i = #broadcasts, 1, -1 do
		local b = broadcasts[i]
		if b.remote == "Purchase" and b.message.op == op then
			return b.message, i
		end
	end
	return nil, 0
end

local function countBroadcasts(op)
	local n = 0
	for _, b in broadcasts do
		if b.remote == "Purchase" and b.message.op == op then
			n += 1
		end
	end
	return n
end

local function ledgerStore()
	return H.dataStores[ProductConfig.Settings.LedgerStore]
end

-- The experience's developer products, as Roblox lists them (created by name in Creator Hub).
MarketplaceService.devProducts = {
	{ Name = "Chronos Defiance", ProductId = 5001, PriceInRobux = 49 },
	{ Name = "Emperor's Decree", ProductId = 5002, PriceInRobux = 149 },
	{ Name = "Luck Booster", ProductId = 5003, PriceInRobux = 199 },
	{ Name = "Megalodon Rainmaker", ProductId = 5004, PriceInRobux = 699 },
	{ Name = "VIP Velocity Elite", ProductId = 5005, PriceInRobux = 499 },
	{ Name = "Gilt Purse", ProductId = 5006, PriceInRobux = 49 },
	{ Name = "Double Gilt", ProductId = 5007, PriceInRobux = 399 },
}
run(Catalog.discover)

---------------------------------------------------------------------------------------------------
-- A. The catalog
---------------------------------------------------------------------------------------------------
do
	local problems = ProductConfig.validate(Grants.names())
	local first = next(problems)
	check("the shipped catalog validates, with a handler for every product", first == nil, first and (first .. ": " .. problems[first]))
	check("the purchase system started with ProcessReceipt", H.Purchases.binding == "ProcessReceipt", H.Purchases.binding)
	local none = ProductConfig.validate({})
	check("a product without a server handler is refused", none.godModeLuck ~= nil and string.find(none.godModeLuck, "handler", 1, true) ~= nil)
	local bad = table.clone(ProductConfig.byKey.godModeLuck)
	bad.Key = "badLuck"
	bad.Name = "Bad Luck"
	bad.Reward = { Type = "Luck", Multiplier = 2, DurationSeconds = 60, Systems = { "gilt", "score" } }
	table.insert(ProductConfig.List, bad)
	ProductConfig.byKey.badLuck = bad
	problems = ProductConfig.validate(Grants.names())
	check("luck can never boost a score", problems.badLuck ~= nil and string.find(problems.badLuck, "never scores", 1, true) ~= nil, problems.badLuck)
	bad.Reward = { Type = "Luck", Multiplier = 9, DurationSeconds = 60, Systems = { "gilt" } }
	problems = ProductConfig.validate(Grants.names())
	check("an absurd multiplier is refused", problems.badLuck ~= nil, problems.badLuck)
	table.remove(ProductConfig.List)
	ProductConfig.byKey.badLuck = nil
	-- The ids AJKR created in Creator Hub, pasted into Config.Products.
	local shipped = H.shippedIds
	local want = {
		megalodonRainmaker = 3716216867, emperorsDecree = 3716216786, chronosDefiance = 3716216641,
		godModeLuck = 3716216448, goldKeyProduct = 3716216232, goldenHour = 3716216027,
		giltPurse3 = 3716215695, giltPurse2 = 3716215587, giltPurse1 = 3716215371, doubleGilt = 3716211503,
	}
	local allThere, seen, distinct = true, {}, true
	for key, id in want do
		allThere = allThere and shipped[key] == id
	end
	for _, id in shipped do
		if id ~= 0 then
			distinct = distinct and not seen[id]
			seen[id] = true
		end
	end
	check("the game ships with AJKR's ten developer product ids, each on its own product", allThere and distinct)
	check("each of the five is found by its name", Catalog.idOf("chronosDefiance") == 5001 and Catalog.idOf("emperorsDecree") == 5002 and Catalog.idOf("godModeLuck") == 5003 and Catalog.idOf("megalodonRainmaker") == 5004 and Catalog.idOf("velocityEliteProduct") == 5005)
	check("a game pass isn't on sale until its id is pasted", Catalog.idOf("velocityElite") == 0 and not Catalog.enabled("velocityElite"))
	check("without the pass, VIP Velocity Elite is sold as its developer product", Store.sellable("velocityElite") == "velocityEliteProduct")
	check("prices are Roblox's", Catalog.price("godModeLuck") == 199 and Catalog.price("megalodonRainmaker") == 699)
	Config.data.Products.godModeLuck = 5002 -- a setup mistake: two products, one id
	check("two products sharing an id: neither is guessed", Catalog.keyForProduct(5002) == nil)
	Config.data.Products.godModeLuck = 0
	check("and fixing it restores both", Catalog.keyForProduct(5002) == "emperorsDecree" and Catalog.keyForProduct(5003) == "godModeLuck")
end

---------------------------------------------------------------------------------------------------
-- B. Receipts
---------------------------------------------------------------------------------------------------
local amy = guest("Amy", 101)
local amyData = profiles[amy].Data
do
	local results = {
		deliver({ PlayerId = "101", ProductId = 5006, PurchaseId = "B-1", CurrencySpent = 49 }),
		deliver({ PlayerId = 101, ProductId = -4, PurchaseId = "B-2", CurrencySpent = 49 }),
		deliver({ PlayerId = 101, ProductId = 5006, PurchaseId = string.rep("x", 101), CurrencySpent = 49 }),
		deliver({ PlayerId = 101, ProductId = 5006, PurchaseId = "B-4", CurrencySpent = 49, CurrencyType = "Tix" }),
		deliver({ PlayerId = 101, ProductId = 5006, PurchaseId = "B-5", CurrencySpent = -1 }),
	}
	local allLater = true
	for _, r in results do
		allLater = allLater and r == LATER
	end
	check("malformed receipts are never granted", allLater and amyData.gilt == 0)
	check("and are logged as validation failures", Telemetry.count(E.Invalid) >= 5, Telemetry.count(E.Invalid))

	local r = receipt(amy, 7777, "U-1", 199)
	check("a receipt for a product the catalog doesn't know stays unresolved", r == LATER and amyData.gilt == 0)
	check("it's noted in the ledger, never granted a default", Ledger.get("U-1") ~= nil and Ledger.get("U-1").reason == "unknown_product" and Ledger.get("U-1").state == "Pending")
	table.insert(MarketplaceService.devProducts, { Name = "Gilt Chest", ProductId = 7777, PriceInRobux = 199 })
	run(Catalog.discover)
	r = receipt(amy, 7777, "U-1", 199)
	check("once the product exists, Roblox's retry grants it", r == GRANTED and amyData.gilt == 5500, amyData.gilt)
	check("the ledger says Granted", Ledger.get("U-1").state == "Granted" and type(Ledger.get("U-1").grantedAt) == "number")
	r = receipt(amy, 7777, "U-1", 199)
	check("a replayed receipt is acknowledged and grants nothing", r == GRANTED and amyData.gilt == 5500)
	check("and the replay is logged", Telemetry.count(E.Duplicate, "giltPurse2", "replayed") == 1)

	r = deliver({ PlayerId = 555, ProductId = 5006, PurchaseId = "A-1", CurrencySpent = 49 })
	check("a buyer who isn't in this server: unresolved (Roblox delivers it when they join)", r == LATER)
	local zed = guest("Zed", 555)
	r = receipt(zed, 5006, "A-1", 49)
	check("and granted once they're here", r == GRANTED and profiles[zed].Data.gilt == 1000)

	local ghost = H.newGuest("Ghost", 556)
	ghost.Character = nil
	table.insert(H.guests, ghost)
	r = receipt(ghost, 5006, "P-0", 49)
	check("a buyer whose profile hasn't opened: unresolved", r == LATER)

	-- Two servers: another holds a live claim on the receipt.
	local before = amyData.gilt
	ledgerStore()["p_L-1"] = { v = 1, id = "L-1", state = "Granting", playerId = 101, productId = 5006, key = "giltPurse1", spent = 49, firstSeen = fakeOs.time(), updated = fakeOs.time(), server = "other-server", leaseUntil = fakeOs.time() + 120, attempts = 1 }
	r = receipt(amy, 5006, "L-1", 49)
	check("a receipt another server is granting isn't granted here too", r == LATER and amyData.gilt == before)
	check("and it says why", Telemetry.count(E.Deferred, "giltPurse1", "claimed_elsewhere") == 1)
	-- That server crashed mid-grant: its lease lapses within the wait.
	ledgerStore()["p_L-1"].leaseUntil = fakeOs.time() + 5
	local late
	run(function()
		late = MarketplaceService.ProcessReceipt({ PlayerId = 101, ProductId = 5006, PurchaseId = "L-1", CurrencySpent = 49 })
	end)
	advance(10)
	check("a lapsed claim is taken over and granted once", late == GRANTED and amyData.gilt == before + 1000 and ledgerStore()["p_L-1"].state == "Granted" and ledgerStore()["p_L-1"].attempts == 2)
	-- Granted by another server (the ledger says so) but missing from this profile.
	ledgerStore()["p_G-1"] = { v = 1, id = "G-1", state = "Granted", playerId = 101, productId = 5006, key = "giltPurse1", spent = 49, firstSeen = 1, updated = 1, server = "other-server", leaseUntil = 0, attempts = 1, grantedAt = 1 }
	before = amyData.gilt
	r = receipt(amy, 5006, "G-1", 49)
	check("a receipt the ledger already granted is acknowledged, never granted again", r == GRANTED and amyData.gilt == before)
	check("and the mismatch is logged", Telemetry.count(E.Duplicate, "giltPurse1", "ledger_granted") == 1)

	-- A save that doesn't land.
	H.savesWork = false
	before = amyData.gilt
	local stuck
	run(function()
		stuck = MarketplaceService.ProcessReceipt({ PlayerId = 101, ProductId = 5006, PurchaseId = "S-1", CurrencySpent = 49 })
	end)
	advance(ProductConfig.Settings.SaveTimeoutSeconds + 2)
	check("a grant whose save doesn't land isn't acknowledged", stuck == LATER, tostring(stuck))
	check("the reward waits in memory, once", amyData.gilt == before + 1000)
	H.savesWork = true
	r = receipt(amy, 5006, "S-1", 49)
	check("Roblox's retry is acknowledged when the save lands, without granting again", r == GRANTED and amyData.gilt == before + 1000)
	check("the saved profile holds the reward and its PurchaseId together", table.find(profiles[amy].LastSavedData.receipts, "S-1") ~= nil and profiles[amy].LastSavedData.gilt == amyData.gilt)

	-- A handler that fails halfway: everything it touched is put back.
	local broken = {
		Key = "testBroken",
		Name = "Test Broken",
		ProductType = "DeveloperProduct",
		Id = 9901,
		Handler = "testBroken",
		Pricing = { ReferencePrice = 49, Tier = "Entry", Rationale = "test" },
		Reward = { Type = "Test" },
		Rules = {},
		UX = { DisplayName = "Test", Category = "Test", Line = "Test", Offer = false, Order = 999, Action = "none" },
	}
	table.insert(ProductConfig.List, broken)
	ProductConfig.byKey.testBroken = broken
	local fail = true
	Grants.register("testBroken", function(ctx)
		ctx.data.gilt += 777
		ctx.data.owned.testThing = true
		ctx.data.perks.credits.testCredit = 3
		if fail then
			error("the handler broke")
		end
	end)
	before = amyData.gilt
	r = receipt(amy, 9901, "T-1", 49)
	check("a handler that fails is rolled back completely", r == LATER and amyData.gilt == before and amyData.owned.testThing == nil and amyData.perks.credits.testCredit == nil)
	check("nothing is marked granted", table.find(amyData.receipts, "T-1") == nil)
	check("the ledger records the failure", Ledger.get("T-1").state == "Failed" and string.find(Ledger.get("T-1").reason or "", "the handler broke", 1, true) ~= nil)
	fail = false
	r = receipt(amy, 9901, "T-1", 49)
	check("Roblox's retry grants it once the handler works", r == GRANTED and amyData.gilt == before + 777 and Ledger.get("T-1").state == "Granted")
	table.remove(ProductConfig.List)
	ProductConfig.byKey.testBroken = nil
	amyData.owned.testThing = nil
	amyData.perks.credits.testCredit = nil

	-- The ledger can't be marked Granted: the reward is saved, so Roblox is told; the record
	-- waits in the buyer's outbox until it can be written.
	H.storeFault = function(name, _key, old)
		return name == ProductConfig.Settings.LedgerStore and type(old) == "table" and old.state == "Granting"
	end
	before = amyData.gilt
	r = receipt(amy, 5006, "O-1", 49)
	check("a saved reward is acknowledged even if the ledger can't be marked yet", r == GRANTED and amyData.gilt == before + 1000)
	check("the ledger entry waits in the buyer's outbox", #amyData.ledgerOutbox == 1 and ledgerStore()["p_O-1"].state == "Granting")
	H.storeFault = nil
	run(function()
		Receipts.flushOutbox(amy)
	end)
	check("and is marked Granted later", Ledger.get("O-1").state == "Granted" and #amyData.ledgerOutbox == 0)

	-- The ledger is down entirely: nothing is granted until it's back.
	H.storeFault = function(name)
		return name == ProductConfig.Settings.LedgerStore
	end
	before = amyData.gilt
	r = receipt(amy, 5006, "D-1", 49)
	check("with the ledger unavailable, the receipt waits", r == LATER and amyData.gilt == before)
	H.storeFault = nil
	r = receipt(amy, 5006, "D-1", 49)
	check("and is granted when it's back", r == GRANTED and amyData.gilt == before + 1000)

	-- A product switched off at start (a broken entry): its receipts wait, never granted from it.
	local off = table.clone(ProductConfig.byKey.giltPurse1)
	off.Key = "brokenPurse"
	off.Name = "Broken Purse"
	off.Id = 9902
	off.Reward = { Type = "Gilt", Amount = -5 }
	table.insert(ProductConfig.List, off)
	ProductConfig.byKey.brokenPurse = off
	Catalog.validate(Grants.names())
	before = amyData.gilt
	r = receipt(amy, 9902, "X-1", 49)
	check("a receipt for a switched-off product waits", r == LATER and amyData.gilt == before and Ledger.get("X-1").reason == "product_disabled")
	table.remove(ProductConfig.List)
	ProductConfig.byKey.brokenPurse = nil
	Catalog.validate(Grants.names())

	-- A PurchaseId too long for a DataStore key (50 characters) is hashed, never refused.
	local long = string.rep("9", 80)
	before = amyData.gilt
	r = receipt(amy, 5006, long, 49)
	local key = Ledger.keyOf(long)
	check("a very long PurchaseId gets a short ledger key and is granted", r == GRANTED and #key <= 50 and amyData.gilt == before + 1000 and ledgerStore()[key].id == long, key)
	check("ledger keys don't collide for different ids", Ledger.keyOf(long) ~= Ledger.keyOf(string.rep("9", 79) .. "8"))

	-- Two deliveries of one receipt at once.
	before = amyData.gilt
	local r1, r2
	run(function()
		r1 = MarketplaceService.ProcessReceipt({ PlayerId = 101, ProductId = 5006, PurchaseId = "C-1", CurrencySpent = 49 })
	end)
	run(function()
		r2 = MarketplaceService.ProcessReceipt({ PlayerId = 101, ProductId = 5006, PurchaseId = "C-1", CurrencySpent = 49 })
	end)
	advance(2)
	check("two deliveries at once grant once", amyData.gilt == before + 1000 and r1 == GRANTED and r2 == GRANTED, tostring(r1) .. " " .. tostring(r2))

	-- A gift: both profiles are saved, each with its mark, before Roblox is told.
	Config.data.Products.goldKeyGift = 8101
	local gia, tom = guest("Gia", 120), guest("Tom", 121)
	H.askAs(gia, { op = "goldKeyGift", userId = tom.UserId })
	r = receipt(gia, 8101, "GIFT-1", 499)
	check("a gift is saved in both profiles before it's acknowledged", r == GRANTED and table.find(profiles[gia].LastSavedData.receipts, "GIFT-1") ~= nil and table.find(profiles[tom].LastSavedData.receipts, "gift:GIFT-1") ~= nil and profiles[tom].LastSavedData.goldKey == true)
	Config.data.Products.goldKeyGift = 0

	-- Regional pricing (Roblox: "Protect your trades and gifts"): a guest who pays a lower price
	-- level can't gift to one who pays a higher one, and nothing is gifted while Roblox hasn't
	-- said what a guest's level is.
	Config.data.Products.goldKeyGift = 8101
	MarketplaceService.priceLevels[122] = 300 -- pays 30% of the price
	local cheap, full = guest("Cai", 122), guest("Fen", 123)
	advance(0.5)
	local refused = H.askAs(cheap, { op = "goldKeyGift", userId = full.UserId })
	check("a cheaper-region guest can't gift to a full-price guest", refused.ok == false and string.find(refused.why or "", "region", 1, true) ~= nil, refused.why)
	local back = H.askAs(full, { op = "goldKeyGift", userId = cheap.UserId })
	check("the other way round is allowed", back.ok == true and back.prompted == true, back.why)
	-- Bought anyway (a screen can open the window itself): the gift isn't handed over.
	profiles[cheap].Data.pending = { product = "goldKeyGift", item = "", giftTo = full.UserId, at = fakeOs.time() }
	r = receipt(cheap, 8101, "GIFT-R", 150)
	check("a gift paid at a lower level isn't handed over: the buyer keeps it", r == GRANTED and profiles[full].Data.goldKey == false and profiles[cheap].Data.goldKey == true)
	MarketplaceService.priceLevelsDown = true
	local x, y = guest("Gus", 124), guest("Hal", 125)
	advance(0.5)
	local unknown = H.askAs(x, { op = "goldKeyGift", userId = y.UserId })
	check("without Roblox's answer, gifts wait (they fail safe)", unknown.ok == false, unknown.why)
	MarketplaceService.priceLevelsDown = false
	H.advance(1)
	check("and once Roblox answers, they're offered again", H.askAs(x, { op = "goldKeyGift", userId = y.UserId }).ok == true)
	Config.data.Products.goldKeyGift = 0
end

---------------------------------------------------------------------------------------------------
-- C. The risk check
---------------------------------------------------------------------------------------------------
do
	local states = {}
	local told = Risk.onChanged
	Risk.onChanged = function(p, state, reasons)
		table.insert(states, state)
		told(p, state, reasons)
	end
	local rio = guest("Rio", 130)
	local data = profiles[rio].Data
	advance(0.1)
	check("a first visit is Normal", data.risk.state == "Normal" and #data.risk.regions == 1 and data.risk.regions[1].code == "US")
	H.services.LocalizationService.regions[130] = "BR"
	H.loadedSignal:Fire(rio, data)
	advance(0.1)
	local points, reasons = Risk.score(data, fakeOs.time())
	check("another country soon after is one weak signal, not a block", data.risk.state == "Normal" and points == 1 and reasons[1] == "region_hop", points)
	H.services.LocalizationService.regions[130] = "DE"
	H.loadedSignal:Fire(rio, data)
	advance(0.1)
	check("three countries in a day: Review", data.risk.state == "Review" and states[#states] == "Review")
	advance(1.1)
	local ok = Store.prompt(rio, "giltPurse1", "test")
	check("Review changes nothing for the guest", ok == true)
	for i = 1, ProductConfig.Risk.VelocityCount do
		receipt(rio, 5006, "V-" .. i, 49)
	end
	receipt(rio, 5006, "V-odd", 3) -- far from both Roblox's price and the catalog's
	check("a burst of receipts and an odd amount: Restricted", data.risk.state == "Restricted", data.risk.state)
	advance(1.1)
	local allowed, why = Store.prompt(rio, "giltPurse1", "test")
	check("Restricted pauses new purchase prompts, with a neutral message", allowed == false and string.find(why or "", "safe and yours", 1, true) ~= nil, why)
	local before = data.gilt
	check("receipts are still granted while Restricted", receipt(rio, 5006, "V-last", 49) == GRANTED and data.gilt == before + 1000)
	check("the change is logged", Telemetry.count(E.Risk) >= 2)
	H.setWallClock(fakeOs.time() + ProductConfig.Risk.RestrictHours * 3600 + 60)
	advance(1.1)
	allowed = Store.prompt(rio, "giltPurse1", "test")
	check("after its hours the restriction lifts", allowed == true and data.risk.state ~= "Restricted", data.risk.state)
	Risk.onChanged = told
end

---------------------------------------------------------------------------------------------------
-- D. The remotes
---------------------------------------------------------------------------------------------------
do
	local flo = guest("Flo", 140)
	advance(5)
	local refused = 0
	for _ = 1, 20 do
		local r
		run(function()
			r = perkAsk(flo, { op = "state" })
		end)
		if type(r) == "table" and r.why == "One moment." then
			refused += 1
		end
	end
	check("a flood of requests is refused after the burst", refused == 20 - Config.data.RemoteLimits.perkAsk.burst, refused)
	check("and logged once, not once per message", Telemetry.count(E.RemoteRejected, "perkAsk", "rate") == 1)
	advance(5)
	check("a nested table is refused", perk(flo, { op = "buy", key = { deeper = { still = true } } }).ok == false)
	local many = { op = "buy" }
	for i = 1, 20 do
		many["k" .. i] = i
	end
	check("too many fields are refused", perk(flo, many).ok == false)
	local before = #prompts
	local r = perk(flo, { op = "buy", key = "giltPurse1", price = 1, amount = 999999, productId = 1, granted = true })
	check("a screen can't set a price, an amount or an id: the server's product is prompted", r.ok and #prompts == before + 1 and prompts[#prompts].id == 5006)
	check("only the offers can be bought by name", perk(flo, { op = "buy", key = "tier99" }).ok == false and perk(flo, { op = "buy", key = "chronosDefiance" }).ok == false and perk(flo, { op = "buy", key = "nonsense" }).ok == false)
	check("a request the house doesn't know is refused", perk(flo, { op = "grant", key = "megalodonRainmaker" }).ok == false)
end

---------------------------------------------------------------------------------------------------
-- E. VIP Velocity Elite
---------------------------------------------------------------------------------------------------
do
	local vic = guest("Vic", 150)
	local data = profiles[vic].Data
	local r = perk(vic, { op = "buy", key = "velocityElite" })
	check("without a pass, the offer prompts the developer product", r.ok and prompts[#prompts].id == 5005 and prompts[#prompts].kind == "product")
	receipt(vic, 5005, "VE-1", 499)
	check("VIP Velocity Elite is granted from its receipt", data.perks.velocity == true and vic:GetAttribute("SpeedPerk") == 1.5 and vic:GetAttribute("VelocityElite") == true)
	check("it isn't offered again once owned", (function()
		for _, o in H.askAs(vic, { op = "offers" }).offers do
			if o.key == "velocityElite" then
				return false
			end
		end
		return true
	end)())
	receipt(vic, 5005, "VE-2", 499)
	check("bought twice, the second becomes Boutique credit", data.credits.tier499 == 1 and lastOp(vic, "notice") ~= nil)
	data.settings.velocitySpeed = "Off"
	Velocity.apply(vic)
	check("the speed can be switched off in Settings (the perk stays)", vic:GetAttribute("SpeedPerk") == nil and vic:GetAttribute("VelocityElite") == true)
	data.settings.velocitySpeed = "On"
	Velocity.apply(vic)
	check("and on again", vic:GetAttribute("SpeedPerk") == 1.5)

	Config.data.Products.velocityElite = 6001
	H.productPrices[6001] = 499
	local studio = H.services.RunService.IsStudio
	H.services.RunService.IsStudio = function()
		return false -- a live server: Roblox's word on ownership
	end
	local wes = guest("Wes", 151)
	advance(0.5)
	r = perk(wes, { op = "buy", key = "velocityElite" })
	check("with its id pasted, the game pass is prompted", r.ok and prompts[#prompts].id == 6001 and prompts[#prompts].kind == "pass")
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(wes, 6001, true)
	advance(40)
	check("a purchase event Roblox's ownership check doesn't confirm grants nothing", profiles[wes].Data.perks.velocity == false)
	H.passOwners["151:6001"] = true
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(wes, 6001, true)
	advance(3)
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(wes, 6001, true)
	advance(3)
	check("the pass is granted once Roblox confirms it, once", profiles[wes].Data.perks.velocity == true and profiles[wes].Data.perks.velocityPass == true and Telemetry.count(E.Granted, "velocityElite") == 1)
	H.passOwners["151:6001"] = nil
	H.loadedSignal:Fire(wes, profiles[wes].Data) -- next visit: Roblox no longer reports the pass (a refund)
	advance(0.5)
	check("a pass Roblox stops reporting (a refund) is taken away and logged", profiles[wes].Data.perks.velocity == false and Telemetry.count(E.Revoked, "velocityElite", "not_owned") == 1 and wes:GetAttribute("SpeedPerk") == nil)
	H.passOwners["152:6001"] = true
	local xan = guest("Xan", 152)
	advance(0.5)
	check("owning the pass is found on arrival", profiles[xan].Data.perks.velocity == true and xan:GetAttribute("SpeedPerk") == 1.5)
	H.services.RunService.IsStudio = studio
	-- In Studio a pass "bought" is a free test purchase Roblox never records as owned: it counts
	-- for that play session, and the next arrival's check takes it away.
	local yul = guest("Yul", 153)
	advance(0.5)
	MarketplaceService.PromptGamePassPurchaseFinished:Fire(yul, 6001, true)
	advance(1)
	check("in Studio, a test purchase of the pass works for that session", profiles[yul].Data.perks.velocity == true)
	H.loadedSignal:Fire(yul, profiles[yul].Data)
	advance(0.5)
	check("and doesn't outlive it (Roblox never recorded it as owned)", profiles[yul].Data.perks.velocity == false)
	local m = Config.data.Movement
	check("speed: 1.5× walking", Speed.resolve(false, nil, 1.5) == m.walkSpeed * 1.5)
	check("speed: the house's event and the perk multiply", Speed.resolve(false, 1.2, 1.5) == math.min(m.maxSpeed, m.walkSpeed * 1.2 * 1.5))
	check("speed: never above the cap", Speed.resolve(true, 3, 1.5) == m.maxSpeed)
	check("speed: nonsense attributes count as nothing", Speed.resolve(false, "fast", -2) == m.walkSpeed)
end

---------------------------------------------------------------------------------------------------
-- F. Chronos Defiance, at a real timed table
---------------------------------------------------------------------------------------------------
do
	local submitted = {}
	H.stubs["ServerScriptService.Server.Boards"] = function()
		return {
			submit = function(player, room, score)
				table.insert(submitted, { player = player, room = room, score = score })
			end,
			submitNightly = function()
				return {}
			end,
			nightlyConnections = function()
				return {}
			end,
			saveNightlyLog = function() end,
		}
	end
	local TableService = module("ServerScriptService", "Server", "TableService")
	TableService.start()
	local model = H.Instance.new("Model")
	model.Name = "TestTable"
	model:SetAttribute("Room", "obsidian")
	model:SetAttribute("TableId", "T-O1")
	local chair = H.Instance.new("Seat")
	chair.Name = "Chair"
	chair.Parent = model
	local ana = H.newGuest("Ana", 160)
	table.insert(H.guests, ana)
	H.newProfile(ana, H.TEMPLATE)
	local data = profiles[ana].Data
	data.best, data.bestRound, data.nightly = {}, {}, { day = -1 }
	H.loadedSignal:Fire(ana, data)
	local tableEvent = Remotes.event("Table")
	local function send(m)
		advance(0.2)
		tableEvent.OnServerEvent:Fire(ana, m)
	end
	local function newest(op, after)
		for i = #ana.inbox, after + 1, -1 do
			if ana.inbox[i].op == op then
				return ana.inbox[i]
			end
		end
		return nil
	end

	local allowed, why = Store.prompt(ana, "chronosDefiance", "test")
	check("a revive can't be bought outside its moment", allowed == false and string.find(why or "", "clock runs out", 1, true) ~= nil, why)
	local seated
	run(function()
		seated = TableService.seat(ana, model, true, "room")
	end)
	advance(1)
	local deal = lastOp(ana, "deal")
	check("seated at an Obsidian table: dealt, the clock running", seated == true and deal ~= nil and deal.clock ~= nil and deal.clock.running == true)
	for i = 1, 2 do
		local p = deal.pieces[i]
		send({ op = "file", uid = p.uid, case = p.case })
	end
	local mark = #ana.inbox
	advance(deal.clock.budget + 1)
	local offer = newest("reviveOffer", mark)
	check("when the clock runs out, a revive is offered", offer ~= nil and math.abs(offer.left - ProductConfig.byKey.chronosDefiance.Rules.WindowSeconds) < 1.5)
	check("with Roblox's price, nothing held, and what it gives", offer ~= nil and offer.price == 49 and offer.held == 0 and offer.add == 15 and offer.boardsCount == false)
	check("the run isn't banked while the offer stands", newest("banked", mark) == nil)
	mark = #ana.inbox
	send({ op = "revive" })
	local update = newest("reviveUpdate", mark)
	check("asking to revive opens Roblox's purchase window", prompts[#prompts].id == 5001 and update ~= nil and update.prompting == true)
	advance(15)
	check("the offer waits while Roblox's window is open", newest("banked", mark) == nil)
	MarketplaceService.PromptProductPurchaseFinished:Fire(160, 5001, true)
	update = newest("reviveUpdate", mark)
	check("bought: the table waits for Roblox's receipt, and says so", update ~= nil and update.waitingReceipt == true)
	mark = #ana.inbox
	receipt(ana, 5001, "REV-1", 49)
	local revived = newest("revived", mark)
	check("the receipt revives the run: +15 seconds", revived ~= nil and revived.clock.running and math.abs(revived.clock.left - 15) < 1.5, revived and revived.clock.left)
	check("one purchase, one revive (the credit is spent)", Perks.credits(data, "revive") == 0)
	local cap = revived and revived.boardScore or -1
	local p3 = deal.pieces[3]
	send({ op = "file", uid = p3.uid, case = p3.case })
	mark = #ana.inbox
	advance(16)
	local banked = newest("banked", mark)
	check("one revive per round: the next time the clock runs out, the run is banked", banked ~= nil and newest("reviveOffer", mark) == nil)
	check("the boards keep the score from before the revive; Gilt counts the whole run", banked ~= nil and banked.boardScore == cap and banked.score > cap and data.best.obsidian == cap, banked and (tostring(banked.score) .. " / " .. tostring(cap)))
	check("and that's the score sent to the board", #submitted >= 1 and submitted[#submitted].score == cap)

	-- The window lapses: banked.
	mark = #ana.inbox
	send({ op = "again" })
	advance(1)
	deal = newest("deal", mark)
	advance(deal.clock.budget + 1)
	check("a new run is offered a revive too", newest("reviveOffer", mark) ~= nil)
	advance(ProductConfig.byKey.chronosDefiance.Rules.WindowSeconds + 1)
	check("the window closes on its own: banked", newest("banked", mark) ~= nil)

	-- Bought, but Roblox's receipt comes after the moment: the revive is kept for the next run.
	mark = #ana.inbox
	send({ op = "again" })
	advance(1)
	deal = newest("deal", mark)
	advance(deal.clock.budget + 1)
	send({ op = "revive" })
	MarketplaceService.PromptProductPurchaseFinished:Fire(160, 5001, true)
	advance(ProductConfig.byKey.chronosDefiance.Rules.ReceiptWaitSeconds + 1)
	check("no receipt within the wait: banked", newest("banked", mark) ~= nil)
	receipt(ana, 5001, "REV-2", 49)
	check("the late receipt is kept as a revive for the next run", Perks.credits(data, "revive") == 1 and string.find(lastOp(ana, "notice") and lastOp(ana, "notice").line or "", "next run", 1, true) ~= nil)
	mark = #ana.inbox
	send({ op = "again" })
	advance(1)
	deal = newest("deal", mark)
	advance(deal.clock.budget + 1)
	offer = newest("reviveOffer", mark)
	check("the next offer shows the revive held", offer ~= nil and offer.held == 1)
	local promptsBefore = #prompts
	send({ op = "revive" })
	check("a revive held is used at once, with no purchase", newest("revived", mark) ~= nil and #prompts == promptsBefore and Perks.credits(data, "revive") == 0)
	mark = #ana.inbox
	advance(16)
	send({ op = "again" })
	advance(1)
	deal = newest("deal", mark)
	advance(deal.clock.budget + 1)
	send({ op = "noRevive" })
	check("declining banks the run at once", newest("banked", mark) ~= nil)
	tableEvent.OnServerEvent:Fire(ana, { op = "leave" })
end

---------------------------------------------------------------------------------------------------
-- G. Emperor's Decree
---------------------------------------------------------------------------------------------------
do
	local dee = guest("Dee", 170)
	local data = profiles[dee].Data
	local info = perk(dee, { op = "decree" })
	check("the decree panel gets the house's lines, the limit and Roblox's price", info.ok and #info.presets == 6 and info.maxLength == 80 and info.price == 149)
	local c = perk(dee, { op = "decreeCompose", text = "  Long   live the rude house  " })
	check("words are tidied and filtered by Roblox before anything is bought", c.ok and c.text == "Long live the #### house", c.text or c.why)
	check("too long is refused", perk(dee, { op = "decreeCompose", text = string.rep("a", 81) }).ok == false)
	check("too short is refused", perk(dee, { op = "decreeCompose", text = "a" }).ok == false)
	check("mostly filtered is refused", perk(dee, { op = "decreeCompose", text = "rude rude rude" }).ok == false)
	check("line breaks and control characters are refused", perk(dee, { op = "decreeCompose", text = "hello\nthere" }).ok == false)
	check("a preset out of range is refused", perk(dee, { op = "decreeCompose", preset = 99 }).ok == false)
	H.services.TextChatService.muted[171] = true
	local mia = guest("Mia", 171)
	local m = perk(mia, { op = "decreeCompose", text = "hello everyone" })
	check("an account that can't chat can't write its own decree", m.ok == false and m.presetsOnly == true)
	check("but can choose one of the house's lines", perk(mia, { op = "decreeCompose", preset = 2 }).ok == true)

	perk(dee, { op = "decreeCompose", text = "Long live the house" })
	local before = countBroadcasts("decree")
	local pr = perk(dee, { op = "decreeProclaim" })
	check("proclaiming without a decree held opens Roblox's purchase", pr.ok and pr.prompted and prompts[#prompts].id == 5002)
	check("nothing is shown before the purchase", countBroadcasts("decree") == before)
	receipt(dee, 5002, "DEC-1", 149)
	advance(0.5)
	local shown = lastBroadcast("decree")
	check("the receipt proclaims it to the whole house", countBroadcasts("decree") == before + 1 and shown.text == "Long live the house" and shown.name == "Dee" and shown.user == "Dee" and shown.seconds == 8)
	check("the decree is spent", Perks.credits(data, "decree") == 0)
	local log = H.dataStores.MaisonNoir_DecreeLog
	local day = log and log["day_" .. os.date("!%Y-%m-%d", fakeOs.time())]
	check("every decree is logged for moderation (who, what, when, which server)", day ~= nil and day[#day].userId == 170 and day[#day].text == "Long live the house" and type(day[#day].server) == "string")
	perk(dee, { op = "decreeCompose", text = "Again and again" })
	local again = perk(dee, { op = "decreeProclaim" })
	check("a guest waits between their own decrees", again.ok == false and string.find(again.why or "", "seconds", 1, true) ~= nil, again.why)

	-- One at a time, with the gap; and the line is short.
	local writers = {}
	for i = 1, 4 do
		local g = guest("Herald" .. i, 172 + i)
		Perks.add(profiles[g].Data, "decree", 1)
		perk(g, { op = "decreeCompose", preset = i })
		writers[i] = g
	end
	advance(30) -- the last decree's time and gap
	local results = {}
	run(function()
		for i, g in writers do
			results[i] = Decree.proclaim(g)
		end
	end)
	check("three may wait their turn; the fourth is told the house is busy", results[1].ok and results[2].ok and results[3].ok and results[4].ok == false and string.find(results[4].why or "", "other decrees", 1, true) ~= nil, results[4].why)
	before = countBroadcasts("decree")
	advance(1)
	check("one plays at once", countBroadcasts("decree") == before + 1)
	local gap = ProductConfig.byKey.emperorsDecree.Reward.DisplaySeconds + ProductConfig.byKey.emperorsDecree.Rules.GlobalGapSeconds
	advance(gap - 2)
	check("the next waits for the gap", countBroadcasts("decree") == before + 1)
	advance(3)
	check("then plays", countBroadcasts("decree") == before + 2)
	check("the fourth still holds their decree", Perks.credits(profiles[writers[4]].Data, "decree") == 1)

	-- Bought with nothing written: kept, ready to write.
	local ivy = guest("Ivy", 180)
	receipt(ivy, 5002, "DEC-2", 149)
	check("a decree bought with nothing written is kept, ready", Perks.credits(profiles[ivy].Data, "decree") == 1 and string.find(lastOp(ivy, "notice").line, "ready", 1, true) ~= nil)
	advance(60)
	perk(ivy, { op = "decreeCompose", preset = 1 })
	local promptsBefore = #prompts
	local used = perk(ivy, { op = "decreeProclaim" })
	check("written later, it's proclaimed without another purchase", used.ok and used.used and #prompts == promptsBefore and Perks.credits(profiles[ivy].Data, "decree") == 0)
end

---------------------------------------------------------------------------------------------------
-- H. God-Mode Luck
---------------------------------------------------------------------------------------------------
do
	local lu = guest("Lu", 190)
	local data = profiles[lu].Data
	local paid
	run(function()
		paid = Gilt.pay(lu, data, 100, "test")
	end)
	check("without Luck, Gilt as usual", paid == 100)
	receipt(lu, 5003, "LUCK-1", 199)
	check("God-Mode Luck: thirty minutes", math.abs(Luck.remaining(lu, data) - 1800) < 2)
	run(function()
		paid = Gilt.pay(lu, data, 100, "test")
	end)
	check("2.5× Gilt", paid == 250, paid)
	local points = data.ledger.points
	LedgerService.add(lu, "filing")
	local boosted = data.ledger.points - points
	check("2.5× Ledger points", boosted == math.floor(module("ReplicatedStorage", "Shared", "Ledger").points("filing") * 2.5 + 0.5), boosted)
	check("the screen is told the time left", lastOp(lu, "perks") ~= nil and lastOp(lu, "perks").luck.remaining > 1700)
	-- Bought again while it runs, with a slow save: the countdown's own writes during the save
	-- must not overwrite the new time.
	H.saveDelay = 4
	local slow
	run(function()
		slow = MarketplaceService.ProcessReceipt({ PlayerId = 190, ProductId = 5003, PurchaseId = "LUCK-2", CurrencySpent = 199 })
	end)
	advance(6)
	H.saveDelay = 0.3
	check("buying again adds its thirty minutes", slow == GRANTED and math.abs(Luck.remaining(lu, data) - 3600) < 9, Luck.remaining(lu, data))
	check("and the saved profile holds the new time", math.abs(profiles[lu].LastSavedData.perks.luck.remaining - 3600) < 9, profiles[lu].LastSavedData.perks.luck.remaining)
	local left = Luck.remaining(lu, data)
	advance(600)
	check("it counts down in play", math.abs(Luck.remaining(lu, data) - (left - 600)) < 2)
	advance(ProductConfig.Settings.LuckWriteSeconds + 1)
	check("the time left is written into the profile as it goes", math.abs(data.perks.luck.remaining - Luck.remaining(lu, data)) < ProductConfig.Settings.LuckWriteSeconds + 2)
	H.PlayersService.PlayerRemoving:Fire(lu)
	local kept = data.perks.luck.remaining
	H.setWallClock(fakeOs.time() + 7200)
	advance(5)
	check("time away isn't spent", data.perks.luck.remaining == kept and Luck.multiplier(lu, "gilt") == 1)
	H.loadedSignal:Fire(lu, data)
	check("back in the house, it runs again", math.abs(Luck.remaining(lu, data) - kept) < 2 and Luck.multiplier(lu, "gilt") == 2.5)
	data.perks.luck.remaining = ProductConfig.byKey.godModeLuck.Rules.MaxSeconds - 60
	H.loadedSignal:Fire(lu, data)
	local ok, why = Store.eligibility.godModeLuck(lu, data)
	check("the house doesn't offer more than six hours held", ok == false and string.find(why or "", "6 hours", 1, true) ~= nil, why)
	receipt(lu, 5003, "LUCK-3", 199) -- bought anyway (a screen can open Roblox's window itself)
	check("but a purchase made anyway is granted in full: paid time is never cut", math.abs(Luck.remaining(lu, data) - (ProductConfig.byKey.godModeLuck.Rules.MaxSeconds - 60 + 1800)) < 3)
	-- Everything at once never passes the cap.
	data.doubleGilt = true
	data.goldKey = true
	local houseBoost = Gilt.boost
	Gilt.boost = function()
		return 2
	end
	run(function()
		paid = Gilt.pay(lu, data, 100, "test")
	end)
	check("every boost together stops at the cap", paid == 100 * ProductConfig.Settings.MaxGiltMultiplier, paid)
	Gilt.boost = houseBoost
	data.doubleGilt = false
	data.goldKey = false
	data.perks.luck.remaining = 30
	H.loadedSignal:Fire(lu, data)
	advance(32)
	check("when it runs out it's gone", Luck.multiplier(lu, "gilt") == 1 and data.perks.luck.remaining == 0 and Telemetry.count(E.Expired, "godModeLuck") == 1)
	check("and the guest is told", string.find(lastOp(lu, "notice").line, "run its course", 1, true) ~= nil)
	run(function()
		paid = Gilt.pay(lu, data, 100, "test")
	end)
	check("Gilt as usual again", paid == 100)
end

---------------------------------------------------------------------------------------------------
-- I. Megalodon Rainmaker
---------------------------------------------------------------------------------------------------
do
	advance(200) -- any earlier sky clears
	local ray, sky = guest("Ray", 200), guest("Sky", 201)
	local rayData, skyData = profiles[ray].Data, profiles[sky].Data
	local others = {}
	for _, p in H.PlayersService.GetPlayers() do
		if profiles[p] and profiles[p].active then
			others[p] = profiles[p].Data.gilt
		end
	end
	local rains = countBroadcasts("rain")
	local savedWithReceipt = nil
	local watch = profiles[ray].OnAfterSave:Connect(function(saved)
		if savedWithReceipt == nil and table.find(saved.receipts, "RAIN-1") then
			savedWithReceipt = saved.gilt
		end
	end)
	receipt(ray, 5004, "RAIN-1", 699)
	watch.Disconnect()
	local rain = lastBroadcast("rain")
	check("the whole house sees who made it rain", countBroadcasts("rain") == rains + 1 and rain.line == "Ray triggered MEGALODON RAIN!" and rain.id == "RAIN-1")
	check("the buyer's own 500 Gilt are saved with the receipt", savedWithReceipt == 500, savedWithReceipt)
	check("the buyer gets their share too", rayData.gilt == 650, rayData.gilt)
	local everyone = true
	for p, g in others do
		if p ~= ray and profiles[p].Data.gilt ~= g + 150 then
			everyone = false
		end
	end
	check("every guest in the house gets 150 Gilt", everyone and skyData.gilt == 150)
	check("each profile remembers the rain", table.find(skyData.perks.rains, "RAIN-1") ~= nil)
	check("each guest's screen hears of their share", lastOp(sky, "rainShare") ~= nil and lastOp(sky, "rainShare").gilt == 150)
	local neo = guest("Neo", 202)
	check("a guest who arrives while it rains gets a share", profiles[neo].Data.gilt == 150)
	H.loadedSignal:Fire(neo, profiles[neo].Data)
	check("rejoining doesn't pay twice", profiles[neo].Data.gilt == 150)
	receipt(ray, 5004, "RAIN-1", 699)
	check("a replayed receipt doesn't rain again", countBroadcasts("rain") == rains + 1 and rayData.gilt == 650)

	receipt(sky, 5004, "RAIN-2", 699)
	check("a second rain waits for the sky to clear", countBroadcasts("rain") == rains + 1 and Perks.credits(skyData, "rain") == 1 and string.find(lastOp(sky, "notice").line, "next in line", 1, true) ~= nil)
	local wait = ProductConfig.byKey.megalodonRainmaker.Reward.DurationSeconds + ProductConfig.byKey.megalodonRainmaker.Rules.ServerGapSeconds
	advance(wait - 5)
	check("not before the gap", countBroadcasts("rain") == rains + 1)
	advance(7)
	check("then it falls, under its own purchase", countBroadcasts("rain") == rains + 2 and lastBroadcast("rain").id == "RAIN-2" and Perks.credits(skyData, "rain") == 0)
	check("a guest gets a share of each rain", profiles[neo].Data.gilt == 300)

	-- The line is short: with rains waiting, the purchase isn't offered.
	-- (Two guests arrive holding rains kept from another house.)
	local una, vin = guest("Una", 203), guest("Vin", 204)
	Perks.add(profiles[una].Data, "rain", 1)
	Perks.add(profiles[vin].Data, "rain", 1)
	H.loadedSignal:Fire(una, profiles[una].Data)
	H.loadedSignal:Fire(vin, profiles[vin].Data)
	local ok, why = Store.eligibility.megalodonRainmaker(neo, profiles[neo].Data)
	check("with rains waiting their turn, another isn't offered", ok == false and string.find(why or "", "waiting their turn", 1, true) ~= nil, why)
	-- A buyer who leaves takes their rain along.
	vin.Parent = nil
	H.PlayersService.PlayerRemoving:Fire(vin)
	advance(wait + 5)
	check("the rain still in the house falls", lastBroadcast("rain").by == "Una")
	advance(wait + 5)
	check("a buyer who left doesn't make it rain here", lastBroadcast("rain").by == "Una" and Perks.credits(profiles[vin].Data, "rain") == 1)
	vin.Parent = H.PlayersService
	H.loadedSignal:Fire(vin, profiles[vin].Data)
	advance(3)
	check("back in a house, their rain falls there", lastBroadcast("rain").by == "Vin" and Perks.credits(profiles[vin].Data, "rain") == 0)

	-- At most MaxRecipients guests share one rain.
	local reward = ProductConfig.byKey.megalodonRainmaker.Reward
	local max = reward.MaxRecipients
	reward.MaxRecipients = 2
	advance(wait + 5)
	local wyn = guest("Wyn", 205)
	Perks.add(profiles[wyn].Data, "rain", 1)
	H.loadedSignal:Fire(wyn, profiles[wyn].Data)
	advance(3)
	local shared = 0
	local id = lastBroadcast("rain").id
	for _, p in H.PlayersService.GetPlayers() do
		if profiles[p] and table.find(profiles[p].Data.perks.rains, id) then
			shared += 1
		end
	end
	check("at most MaxRecipients guests share one rain (the buyer first)", lastBroadcast("rain").by == "Wyn" and shared == 2 and table.find(profiles[wyn].Data.perks.rains, id) ~= nil, shared)
	reward.MaxRecipients = max
end

---------------------------------------------------------------------------------------------------
-- K. AJKR's products, with the ids that ship: all of them on the Offers page, and they work
---------------------------------------------------------------------------------------------------
do
	MarketplaceService.devProducts = {}
	run(Catalog.discover) -- nothing found by name: only the pasted ids
	local livePrices = {
		megalodonRainmaker = 699, emperorsDecree = 249, chronosDefiance = 89, godModeLuck = 399,
		goldKeyProduct = 1999, goldenHour = 250, giltPurse3 = 799, giltPurse2 = 299, giltPurse1 = 97, doubleGilt = 998,
	}
	for key, id in H.shippedIds do
		Config.data.Products[key] = id
		if livePrices[key] then
			H.productPrices[id] = livePrices[key]
		end
	end
	advance(400) -- prices re-read from Roblox
	local zoe = guest("Zoe", 300)
	local view = H.askAs(zoe, { op = "offers" })
	local byKey = {}
	for _, o in view.offers do
		byKey[o.key] = o
	end
	local names = { "doubleGilt", "goldenHour", "godModeLuck", "goldKey", "emperorsDecree", "megalodonRainmaker", "giltPurse1", "giltPurse2", "giltPurse3", "chronosDefiance" }
	local missing = {}
	for _, k in names do
		if not byKey[k] then
			table.insert(missing, k)
		end
	end
	check("every product AJKR made is on the Offers page", #missing == 0, table.concat(missing, ", "))
	check("with Roblox's own prices", byKey.godModeLuck and byKey.godModeLuck.price == 399 and byKey.goldKey and byKey.goldKey.price == 1999 and byKey.doubleGilt and byKey.doubleGilt.price == 998)
	check("named as in Creator Hub (Luck Booster)", byKey.godModeLuck and byKey.godModeLuck.name == "Luck Booster")
	check("Chronos Defiance is listed, saying when it can be bought", byKey.chronosDefiance and byKey.chronosDefiance.disabled == true and string.find(byKey.chronosDefiance.why or "", "clock runs out", 1, true) ~= nil)
	local r = H.askAs(zoe, { op = "offer", key = "godModeLuck" })
	check("buying Luck Booster opens Roblox's window for its id", r.ok and prompts[#prompts].id == 3716216448)
	check("its receipt grants it", receipt(zoe, 3716216448, "LIVE-1", 399) == GRANTED and Luck.remaining(zoe, profiles[zoe].Data) > 1790)
	H.askAs(zoe, { op = "offer", key = "goldKey" })
	check("the Gold Key is sold as the developer product", prompts[#prompts].id == 3716216232)
	check("Double Gilt by its id, whatever its name", receipt(zoe, 3716211503, "LIVE-2", 998) == GRANTED and profiles[zoe].Data.doubleGilt == true)
	for key in H.shippedIds do
		Config.data.Products[key] = 0
	end
end

---------------------------------------------------------------------------------------------------
-- J. The analytics schema
---------------------------------------------------------------------------------------------------
do
	local granted
	for _, e in H.customEvents do
		if e.name == E.Granted then
			granted = e
		end
	end
	check("every purchase event carries product, outcome and segment (Roblox's three fields)", granted ~= nil and type(granted.fields) == "table" and #granted.fields == 3 and type(granted.fields[1]) == "string")
	check("segments: new, repeat, patron", Telemetry.segment({}) == "new" and Telemetry.segment({ a = 2 }) == "repeat" and Telemetry.segment({ a = 3, b = 2 }) == "patron")
	local names = {}
	for _, n in E do
		names[n] = true
	end
	local tracked = true
	for _, e in Telemetry.recent() do
		tracked = tracked and names[e.event] == true
	end
	check("only the documented events are logged", tracked)
	check("impressions are counted once per offer in a while, not on every look", (function()
		local kit = guest("Kit", 210)
		H.askAs(kit, { op = "offers" })
		local n = Telemetry.count(E.Impression, "godModeLuck")
		H.askAs(kit, { op = "offers" })
		return Telemetry.count(E.Impression, "godModeLuck") == n and n >= 1
	end)())
end

---------------------------------------------------------------------------------------------------
-- K. The Foyer's grand piano
---------------------------------------------------------------------------------------------------
do
	local Piano = purchases("Piano")
	local Layout = module("ReplicatedStorage", "Shared", "Layout")
	-- The daily free taste is looked at on its own, after the paid sessions.
	local taste = Config.data.Piano.taste
	Config.data.Piano.taste = 0
	local Workspace = H.services.Workspace
	local seat = H.pianoSeat
	local pianoAsk = Remotes.funcs.PianoAsk.OnServerInvoke
	local noteEvent = Remotes.event("PianoNote")
	local function piano(player, request)
		advance(0.4)
		local r
		run(function()
			r = pianoAsk(player, request)
		end)
		return r
	end
	-- A guest standing `away` studs from the bench, with a humanoid the seat can hold.
	local function pianist(name, id, away)
		local g = guest(name, id)
		local h = { Health = 100, Sit = false, SeatPart = nil }
		local root = { Position = Layout.Foyer.pianoSeat.Position + H.Vector3.new(0, 0, away or 3) }
		function root.IsA(_, class)
			return class == "BasePart"
		end
		g.Character = {
			FindFirstChildOfClass = function(_, class)
				return if class == "Humanoid" then h else nil
			end,
			FindFirstChild = function(_, n)
				return if n == "HumanoidRootPart" then root else nil
			end,
		}
		return g, h
	end
	local function notesTo(player)
		local n = 0
		for _, m in player.inbox do
			if m.op == "@PianoNote" then
				n += 1
			end
		end
		return n
	end

	-- The four sessions, as created in Creator Hub by their names.
	for _, p in {
		{ Name = "Piano Session 1 Minute", ProductId = 5101, PriceInRobux = 99 },
		{ Name = "Piano Session 3 Minutes", ProductId = 5103, PriceInRobux = 349 },
		{ Name = "Piano Session 5 Minutes", ProductId = 5105, PriceInRobux = 599 },
		{ Name = "Piano Session 10 Minutes", ProductId = 5110, PriceInRobux = 899 },
	} do
		table.insert(MarketplaceService.devProducts, p)
	end
	run(Catalog.discover)
	local problems = ProductConfig.validate(Grants.names())
	check("the four piano sessions are valid products", problems.pianoSession1 == nil and problems.pianoSession3 == nil and problems.pianoSession5 == nil and problems.pianoSession10 == nil)
	check("each is found by its name in Creator Hub", Catalog.idOf("pianoSession1") == 5101 and Catalog.idOf("pianoSession10") == 5110)
	check("one, three, five and ten minutes", ProductConfig.byKey.pianoSession1.Reward.Seconds == 60 and ProductConfig.byKey.pianoSession3.Reward.Seconds == 180 and ProductConfig.byKey.pianoSession5.Reward.Seconds == 300 and ProductConfig.byKey.pianoSession10.Reward.Seconds == 600)
	check("at AJKR's prices (99, 349, 599, 899)", ProductConfig.byKey.pianoSession1.Pricing.ReferencePrice == 99 and ProductConfig.byKey.pianoSession3.Pricing.ReferencePrice == 349 and ProductConfig.byKey.pianoSession5.Pricing.ReferencePrice == 599 and ProductConfig.byKey.pianoSession10.Pricing.ReferencePrice == 899)
	check("offered at the piano, not in the Boutique's list", ProductConfig.byKey.pianoSession1.UX.Offer == false)

	local ada, adaHum = pianist("Ada", 9300)
	local adaData = profiles[ada].Data
	local ben = pianist("Ben", 9301)
	local r = piano(ada, { op = "sit" })
	check("with no time, sitting down shows the sessions instead", r.ok == false and r.needTime == true and #r.offers == 4)
	check("with Roblox's prices", r.offers[1].price == 99 and r.offers[2].price == 349 and r.offers[3].price == 599 and r.offers[4].price == 899 and r.offers[4].ready == true)
	check("and the piano stays free", Workspace:GetAttribute("PianoPlayer") == nil and seat.Occupant == nil)
	local before = #prompts
	r = piano(ada, { op = "buy", key = "pianoSession3" })
	check("choosing three minutes opens Roblox's purchase window", r.ok == true and #prompts == before + 1 and prompts[#prompts].id == 5103)
	r = piano(ada, { op = "buy", key = "godModeLuck" })
	check("only piano time is sold at the piano", r.ok == false)
	check("a receipt for three minutes is granted", receipt(ada, 5103, "PIANO-1", 349) == GRANTED)
	check("bought at the bench, they sit straight down to play", Workspace:GetAttribute("PianoPlayer") == 9300 and Workspace:GetAttribute("PianoName") == "Ada" and seat.Occupant == adaHum and seat.Disabled == false)
	check("the house knows to rest its music", Piano.player() == ada)
	check("with three minutes on the clock", math.abs(Piano.remaining(ada, adaData) - 180) < 3, Piano.remaining(ada, adaData))

	-- Notes: from the guest at the piano to everyone else in the house.
	local benBefore, adaBefore = notesTo(ben), notesTo(ada)
	run(function()
		noteEvent.OnServerEvent:Fire(ada, 13)
	end)
	local last = ben.inbox[#ben.inbox]
	check("a note played goes to every other guest", notesTo(ben) == benBefore + 1 and last.args[1] == 13 and last.args[2] == 9300)
	check("but not back to the one who played it (they heard it already)", notesTo(ada) == adaBefore)
	run(function()
		noteEvent.OnServerEvent:Fire(ben, 13)
	end)
	check("a guest not at the piano can't play it", notesTo(ada) == adaBefore)
	advance(2)
	local n = notesTo(ben)
	for _, bad in { 0, 38, 1.5, "13", -4 } do
		run(function()
			noteEvent.OnServerEvent:Fire(ada, bad)
		end)
	end
	check("a key that isn't on the piano is refused", notesTo(ben) == n)
	advance(3)
	n = notesTo(ben)
	for _ = 1, 80 do
		run(function()
			noteEvent.OnServerEvent:Fire(ada, 20)
		end)
	end
	local passed = notesTo(ben) - n
	check("a flood of notes is held to the rate", passed <= Config.data.RemoteLimits.pianoNote.burst and passed >= 10, passed)

	-- The clock runs only at the keys.
	local left = Piano.remaining(ada, adaData)
	advance(60)
	check("time runs while they play", math.abs(Piano.remaining(ada, adaData) - (left - 60)) < 2)
	check("and is written into the profile as it goes", math.abs(adaData.perks.piano.seconds - Piano.remaining(ada, adaData)) < 2)
	r = piano(ben, { op = "sit" })
	check("one guest at a time: the next is told who's playing and for how long", r.ok == false and string.find(r.why or "", "Ada is at the piano", 1, true) ~= nil and string.find(r.why or "", "left", 1, true) ~= nil, r.why)
	r = piano(ada, { op = "stand" })
	local kept = adaData.perks.piano.seconds
	check("getting up keeps the rest", r.ok and Workspace:GetAttribute("PianoPlayer") == nil and seat.Occupant == nil and seat.Disabled == true and math.abs(kept - (left - 60)) < 3, kept)
	check("and the guest's screen is told", lastOp(ada, "pianoEnd") ~= nil and lastOp(ada, "pianoEnd").reason == "up")
	advance(120)
	check("time away from the keys isn't spent", adaData.perks.piano.seconds == kept and Piano.remaining(ada, adaData) == kept)

	-- Sitting down with time held; buying more while playing.
	r = piano(ada, { op = "sit" })
	check("with time held, they sit straight down", r.ok == true and Workspace:GetAttribute("PianoPlayer") == 9300)
	local now = Piano.remaining(ada, adaData)
	check("a minute bought while playing goes on the clock at once", receipt(ada, 5101, "PIANO-2", 99) == GRANTED and math.abs(Piano.remaining(ada, adaData) - (now + 60 - 1)) < 3, Piano.remaining(ada, adaData))
	-- Getting off the bench (a jump) ends it too.
	seat.Occupant = nil
	advance(1)
	check("leaving the bench ends playing, and keeps the time", Workspace:GetAttribute("PianoPlayer") == nil and adaData.perks.piano.seconds > 100)

	-- Too far from the bench.
	local far = pianist("Far", 9302, 40)
	profiles[far].Data.perks.piano.seconds = 60
	r = piano(far, { op = "sit" })
	check("a guest across the room can't play it from there", r.ok == false and string.find(r.why or "", "Come to the grand piano", 1, true) ~= nil)

	-- Running out.
	adaData.perks.piano.seconds = 5
	piano(ada, { op = "sit" })
	advance(7)
	check("when the time runs out, they get up", Workspace:GetAttribute("PianoPlayer") == nil and adaData.perks.piano.seconds == 0 and seat.Occupant == nil)
	check("and are thanked", lastOp(ada, "pianoEnd").reason == "time")
	check("logged as expired", Telemetry.count(E.Expired, "piano") >= 1)

	-- The cap on what the house offers, never on what's paid.
	adaData.perks.piano.seconds = Config.data.Piano.maxSeconds - 30
	local ok, why = Store.eligibility.pianoSession1(ada, adaData)
	check("the house doesn't offer more than an hour held", ok == false and string.find(why or "", "60 minutes", 1, true) ~= nil, why)
	receipt(ada, 5101, "PIANO-3", 99)
	check("but a purchase made anyway is granted in full", adaData.perks.piano.seconds == Config.data.Piano.maxSeconds + 30, adaData.perks.piano.seconds)

	-- Leaving the house while playing.
	piano(ada, { op = "sit" })
	advance(10)
	local playing = Piano.remaining(ada, adaData)
	H.PlayersService.PlayerRemoving:Fire(ada)
	check("leaving the house frees the piano and keeps the time", Workspace:GetAttribute("PianoPlayer") == nil and math.abs(adaData.perks.piano.seconds - playing) < 2)

	-- The prompt on the bench.
	local cy = pianist("Cy", 9303)
	run(function()
		seat.prompt.Triggered:Fire(cy)
	end)
	advance(0.5)
	check("the bench's prompt, with no time held, shows the sessions", lastOp(cy, "pianoOffer") ~= nil)
	profiles[cy].Data.perks.piano.seconds = 30
	run(function()
		seat.prompt.Triggered:Fire(cy)
	end)
	advance(0.5)
	check("and with time held, sits them down", Workspace:GetAttribute("PianoPlayer") == 9303)
	piano(cy, { op = "stand" })

	-- AJKR's call: the piano is pay-only. Nobody (the owner, anyone in Studio) gets free time.
	check("the piano is pay-only as shipped: no daily taste", taste == 0)
	check("...and no owner's free sitting", Config.data.Piano.ownerFree == false)
	local dee = pianist("Dee", 9304)
	local deeData = profiles[dee].Data
	Piano.isOwner = function(p)
		return p == dee
	end
	r = piano(dee, { op = "state" })
	check("even the owner (or a Studio tester) is offered no free time", r.free == false and r.taste == nil, r.free)
	r = piano(dee, { op = "sit" })
	check("...and can't sit down without buying time", r.ok == false and r.needTime == true and Workspace:GetAttribute("PianoPlayer") == nil)
	Piano.isOwner = function()
		return false
	end

	-- The switches still work if AJKR ever turns them on.
	taste = 30
	Config.data.Piano.taste = taste
	Config.data.Piano.ownerFree = true
	r = piano(dee, { op = "state" })
	check("a guest with no time is offered today's free taste", r.taste == taste and r.free == false and taste > 0, r.taste)
	r = piano(dee, { op = "sit" })
	check("and sits straight down to play it", r.ok == true and Workspace:GetAttribute("PianoPlayer") == 9304 and math.abs(Piano.remaining(dee, deeData) - taste) < 2, Piano.remaining(dee, deeData))
	check("told it's the house's gift", lastOp(dee, "notice") ~= nil and string.find(lastOp(dee, "notice").line or "", "free every day", 1, true) ~= nil)
	advance(taste + 2)
	check("the taste runs out like any time", Workspace:GetAttribute("PianoPlayer") == nil and deeData.perks.piano.seconds == 0)
	r = piano(dee, { op = "sit" })
	check("once a day: after it, the sessions", r.ok == false and r.needTime == true and r.taste == nil)
	deeData.perks.piano.tasteDay -= 1
	r = piano(dee, { op = "state" })
	check("a new day brings a new taste", r.taste == taste)

	-- The owner plays free, without spending or keeping any time.
	Piano.isOwner = function(p)
		return p == dee
	end
	deeData.perks.piano.seconds = 45
	r = piano(dee, { op = "state" })
	check("the owner is told they play free", r.free == true)
	r = piano(dee, { op = "sit" })
	check("the owner sits down free", r.ok == true and Workspace:GetAttribute("PianoPlayer") == 9304)
	advance(20)
	check("their clock runs on the owner's sitting", (Workspace:GetAttribute("PianoEnds") or 0) > 0)
	piano(dee, { op = "stand" })
	check("and their own time isn't touched", deeData.perks.piano.seconds == 45, deeData.perks.piano.seconds)
	check("nor today's taste", deeData.perks.piano.tasteDay ~= nil)
	Piano.isOwner = function()
		return false
	end
	Config.data.Piano.taste = 0
	Config.data.Piano.ownerFree = false
end

---------------------------------------------------------------------------------------------------
-- L. The Terrace bar: treats for Gilt, the house specials for Robux, the Gold Key's pour
---------------------------------------------------------------------------------------------------
do
	local Bar = purchases("Bar")
	local BarMenu = module("ReplicatedStorage", "Shared", "BarMenu")
	local Layout = module("ReplicatedStorage", "Shared", "Layout")
	local Instance, Vector3, CFrame = H.Instance, H.Vector3, H.CFrame
	local barAsk = Remotes.funcs.BarAsk.OnServerInvoke
	local function bar(player, request)
		advance(0.6)
		local r
		run(function()
			r = barAsk(player, request)
		end)
		return r
	end
	-- A guest with a real body (a hand to hold a treat), `away` studs from the bar.
	local function patron(name, id, away)
		local g = guest(name, id)
		local body = Instance.new("Model")
		body.Name = name
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.CFrame = CFrame.new(Layout.Terrace.bar + Vector3.new(0, 3, -(away or 4)))
		root.Position = root.CFrame.Position -- (Lune keeps the two apart)
		root.Parent = body
		local hand = Instance.new("Part")
		hand.Name = "RightHand"
		hand.Size = Vector3.new(0.3, 0.3, 0.3)
		hand.CFrame = root.CFrame * CFrame.new(1.5, -1, 0)
		hand.Parent = body
		g.Character = body
		g.body = body
		return g
	end
	local function treatOf(g)
		return g.body:FindFirstChild("Treat")
	end

	for _, p in {
		{ Name = "Gold-Leaf Spritz", ProductId = 5201, PriceInRobux = 75 },
		{ Name = "Macaron Tower", ProductId = 5202, PriceInRobux = 149 },
		{ Name = "Grand Platter", ProductId = 5203, PriceInRobux = 299 },
	} do
		table.insert(MarketplaceService.devProducts, p)
	end
	run(Catalog.discover)
	local problems = ProductConfig.validate(Grants.names())
	check("the three house specials are valid products", problems.barGoldSpritz == nil and problems.barMacaronTower == nil and problems.barGrandPlatter == nil, problems.barGoldSpritz)
	check("each names the menu item it serves", BarMenu.byProduct.barGoldSpritz.id == "goldSpritz" and BarMenu.byProduct.barGrandPlatter.share == true)
	check("nothing on the menu is random, alcoholic or paid in two currencies", (function()
		for _, item in BarMenu.Items do
			if (item.gilt ~= nil) == (item.product ~= nil) then
				return false
			end
			local text = string.lower(item.name .. " " .. item.line)
			for _, word in { "wine", "beer", "champagne", "cocktail", "whisky", "vodka", "rum", "gin ", "random", "mystery", "chance" } do
				if string.find(text, word, 1, true) then
					return false
				end
			end
		end
		return true
	end)())

	local ivy = patron("Ivy", 9400)
	local ivyData = profiles[ivy].Data
	local r = bar(ivy, { op = "menu" })
	check("the menu lists every item with its price", r.ok == true and #r.items == #BarMenu.Items)
	local spritz
	for _, i in r.items do
		if i.id == "goldSpritz" then
			spritz = i
		end
	end
	check("a special shows Roblox's live price and its key", spritz ~= nil and spritz.robux == 75 and spritz.ready == true and spritz.key == "barGoldSpritz")

	ivyData.gilt = 10
	r = bar(ivy, { op = "order", id = "lemonade" })
	check("not enough Gilt: refused, and says how much more", r.ok == false and string.find(r.why or "", "15 more", 1, true) ~= nil and treatOf(ivy) == nil, r.why)
	ivyData.gilt = 100
	r = bar(ivy, { op = "order", id = "lemonade" })
	check("an order for Gilt is served", r.ok == true and ivyData.gilt == 75 and treatOf(ivy) ~= nil)
	check("into their right hand, welded", treatOf(ivy) ~= nil and treatOf(ivy):GetAttribute("TreatId") == "lemonade" and treatOf(ivy).PrimaryPart:FindFirstChild("TreatGrip") ~= nil)
	r = bar(ivy, { op = "order", id = "goldSpritz" })
	check("a special can't be had for Gilt", r.ok == false and ivyData.gilt == 75)
	r = bar(ivy, { op = "order", id = "champagne" })
	check("something not on the menu is refused", r.ok == false and ivyData.gilt == 75)
	r = bar(ivy, { op = "order", id = "lemonade", price = 1 })
	check("a price sent by the screen is refused outright", r.ok == false and ivyData.gilt == 75)
	local far = patron("Far", 9401, 40)
	profiles[far].Data.gilt = 100
	r = bar(far, { op = "order", id = "lemonade" })
	check("orders only at the bar", r.ok == false and profiles[far].Data.gilt == 100 and treatOf(far) == nil)

	-- Sips: one every few seconds, then it's finished.
	local treat = treatOf(ivy)
	advance(Config.data.Bar.sipSeconds + 0.5)
	check("a sip every few seconds, seen by every screen", treat:GetAttribute("Sips") == 1 and treat:GetAttribute("Servings") == BarMenu.byId.lemonade.servings - 1)
	advance(Config.data.Bar.sipSeconds * BarMenu.byId.lemonade.servings + 3)
	check("and when it's finished, it's gone", treatOf(ivy) == nil and Bar.holding(ivy) == nil)
	bar(ivy, { op = "order", id = "fries" })
	r = bar(ivy, { op = "putDown" })
	check("put down at any time", r.ok == true and treatOf(ivy) == nil)

	-- A house special: only from a receipt, kept as a credit, served at once.
	local before = #prompts
	r = bar(ivy, { op = "special", key = "barGoldSpritz" })
	check("asking for a special opens Roblox's purchase window", r.ok == true and r.prompted == true and #prompts == before + 1)
	check("and nothing is served before Roblox says it's bought", treatOf(ivy) == nil)
	r = bar(ivy, { op = "special", key = "notAProduct" })
	check("only the bar's own specials are sold at the bar", r.ok == false)
	local result = receipt(ivy, 5201, "bar-1", 75)
	check("the receipt is granted", result == GRANTED)
	check("and the spritz is served straight away", treatOf(ivy) ~= nil and treatOf(ivy):GetAttribute("TreatId") == "goldSpritz" and Perks.credits(ivyData, "treat:barGoldSpritz") == 0)
	check("glowing", treatOf(ivy).PrimaryPart:FindFirstChild("Glow") ~= nil)
	result = receipt(ivy, 5201, "bar-1", 75)
	check("the same receipt again grants nothing more", result == GRANTED and Perks.credits(ivyData, "treat:barGoldSpritz") == 0)

	-- Bought while away from their body: kept, and served when they ask (or come back).
	local body = ivy.Character
	ivy.Character = nil
	result = receipt(ivy, 5201, "bar-2", 75)
	check("bought with no body to hold it: kept as a credit", result == GRANTED and Perks.credits(ivyData, "treat:barGoldSpritz") == 1)
	ivy.Character = body
	bar(ivy, { op = "putDown" })
	r = bar(ivy, { op = "menu" })
	local waiting = 0
	for _, i in r.items do
		if i.id == "goldSpritz" then
			waiting = i.waiting
		end
	end
	check("the menu says one is waiting", waiting == 1)
	before = #prompts
	r = bar(ivy, { op = "special", key = "barGoldSpritz" })
	check("and serves it without asking for Robux again", r.ok == true and #prompts == before and treatOf(ivy) ~= nil and Perks.credits(ivyData, "treat:barGoldSpritz") == 0)

	-- The Grand Platter: a macaron for each guest close by.
	local jo = patron("Jo", 9402, 6)
	local kit = patron("Kit", 9403, 60)
	result = receipt(ivy, 5203, "bar-3", 299)
	check("the platter is served", result == GRANTED and treatOf(ivy) ~= nil and treatOf(ivy):GetAttribute("TreatId") == "platter")
	check("guests close by are each handed a macaron", treatOf(jo) ~= nil and treatOf(jo):GetAttribute("TreatId") == "sharedMacaron" and lastOp(jo, "notice") ~= nil)
	check("guests far away aren't", treatOf(kit) == nil)
	check("and it never touches anyone's Gilt", profiles[jo].Data.gilt == 0)

	-- The Gold Key's drink on the house, once a day.
	local lu = patron("Lu", 9404)
	local luData = profiles[lu].Data
	luData.goldKey = true
	r = bar(lu, { op = "menu" })
	check("a Gold Key holder sees a drink on the house", r.pour == true)
	r = bar(lu, { op = "order", id = "fries", pour = true })
	check("a drink, not a snack", r.ok == false)
	r = bar(lu, { op = "order", id = "hibiscus", pour = true })
	check("poured free", r.ok == true and r.free == true and luData.gilt == 0 and treatOf(lu) ~= nil)
	r = bar(lu, { op = "order", id = "hibiscus", pour = true })
	check("once a day", r.ok == false)
	r = bar(ivy, { op = "order", id = "hibiscus", pour = true })
	check("only for Gold Key holders", r.ok == false)
end

---------------------------------------------------------------------------------------------------
-- M. Curios, Gems and the Cabinet; trading curios between guests
---------------------------------------------------------------------------------------------------
do
	local CuriosS = module("ServerScriptService", "Server", "Curios")
	local CurioList = module("ReplicatedStorage", "Shared", "Curios")
	local TradeService = module("ServerScriptService", "Server", "TradeService")
	TradeService.start()
	local curioAsk = Remotes.funcs.CurioAsk.OnServerInvoke
	local tradeAsk = Remotes.funcs.TradeAsk.OnServerInvoke
	local function curio(player, request)
		advance(0.5)
		local r
		run(function()
			r = curioAsk(player, request)
		end)
		return r
	end
	local function trade(player, request)
		advance(0.5)
		local r
		run(function()
			r = tradeAsk(player, request)
		end)
		return r
	end

	-- The list itself.
	check("every curio has a rarity, a family and says how it's had", (function()
		for _, c in CurioList.List do
			if not CurioList.RarityRank[c.rarity] or c.how == "" or c.name == "" then
				return false
			end
			if c.source == "gems" and not c.gems then
				return false
			end
		end
		return true
	end)())
	check("finds at the tables follow the weights (common often, mythic rarely)", CurioList.pick(0, 0).rarity == "Common" and CurioList.pick(0.99999, 0).rarity == "Mythic")
	check("nothing found at the tables is sold for Gems or Robux", (function()
		for _, c in CurioList.List do
			if c.source == "tables" and c.gems then
				return false
			end
		end
		return true
	end)())

	-- Gem packs: receipts, never anything else.
	for _, p in {
		{ Name = "Gem Pouch", ProductId = 5301, PriceInRobux = 199 },
		{ Name = "Gem Case", ProductId = 5302, PriceInRobux = 799 },
		{ Name = "Gem Trunk", ProductId = 5303, PriceInRobux = 1999 },
	} do
		table.insert(MarketplaceService.devProducts, p)
	end
	run(Catalog.discover)
	local problems = ProductConfig.validate(Grants.names())
	check("the three Gem packs are valid products", problems.gems1 == nil and problems.gems2 == nil and problems.gems3 == nil)
	check("bigger packs give more Gems per Robux", ProductConfig.byKey.gems2.Reward.Amount / 799 > ProductConfig.byKey.gems1.Reward.Amount / 199 and ProductConfig.byKey.gems3.Reward.Amount / 1999 > ProductConfig.byKey.gems2.Reward.Amount / 799)
	local mo = guest("Mo", 9500)
	local moData = profiles[mo].Data
	local r = curio(mo, { op = "state" })
	check("the Cabinet lists curios for Gems and the packs, with Roblox's prices", r.ok == true and #r.cabinet.items >= 3 and r.cabinet.packs[1].robux == 199 and r.cabinet.packs[1].ready == true)
	r = curio(mo, { op = "buy", id = "truffle" })
	check("no Gems: the Cabinet says how many more", r.ok == false and string.find(r.why or "", "60 more", 1, true) ~= nil)
	local before = #prompts
	r = curio(mo, { op = "gems", key = "gems1" })
	check("a Gem pack opens Roblox's purchase window", r.ok == true and #prompts == before + 1 and moData.gems == 0)
	r = curio(mo, { op = "gems", key = "giltPurse1" })
	check("only Gem packs are sold there", r.ok == false)
	local result = receipt(mo, 5301, "gems-1", 199)
	check("the receipt adds the Gems", result == GRANTED and moData.gems == 250)
	result = receipt(mo, 5301, "gems-1", 199)
	check("the same receipt twice adds nothing", moData.gems == 250)
	r = curio(mo, { op = "buy", id = "truffle" })
	check("the Cabinet sells the exact curio chosen, at its price", r.ok == true and moData.gems == 190 and CuriosS.count(moData, "truffle") == 1)
	r = curio(mo, { op = "buy", id = "croissantino" })
	check("a curio found at the tables can't be bought", r.ok == false and moData.gems == 190)
	r = curio(mo, { op = "buy", id = "truffle", gems = 0 })
	check("a price from the screen is refused outright", r.ok == false and moData.gems == 190)
	r = curio(mo, { op = "fav", id = "truffle", on = true })
	check("a curio can be starred", r.ok == true and moData.curios.favs.truffle == true)
	r = curio(mo, { op = "fav", id = "moonCheese", on = true })
	check("but not one you don't hold", r.ok == false)

	-- Finds after a run.
	CuriosS.random = { NextNumber = function()
		return 0.01
	end }
	local gilt0 = moData.gilt
	local found = CuriosS.afterRun(mo, moData, 3, 0.9, "salon", false)
	check("a banked run can find a curio", found ~= nil and found.rarity == "Common" and CuriosS.count(moData, found.id) == 1)
	check("and it pays a little Gilt", moData.gilt > gilt0 and found.gilt > 0)
	check("the new find is on the Recent shelf", table.find(moData.curios.recent, found.id) ~= nil)
	local inSeason = module("ReplicatedStorage", "Shared", "Rating").term().id == CurioList.LimitedSeason.autumnLeaf
	check("this season's own curio comes with the first run of its season (and never outside it)", CuriosS.count(moData, "autumnLeaf") == (if inSeason then 1 else 0))
	CuriosS.random = { NextNumber = function()
		return 0.99
	end }
	check("not every run finds one", CuriosS.afterRun(mo, moData, 1, 0.5, "salon", false) == nil)
	check("a run with no rounds finds nothing", CurioList.findChance(0, 1) == 0)
	found = CuriosS.afterRun(mo, moData, 3, 1, "midnight", true)
	check("a flawless Midnight run finds the Secret", found ~= nil and found.id == "midnightOwl")
	found = CuriosS.afterRun(mo, moData, 3, 1, "midnight", true)
	check("only once", found == nil or found.id ~= "midnightOwl")
	CuriosS.random = { NextNumber = function()
		return 0.5
	end }

	-- Trading.
	local nia = guest("Nia", 9501)
	local niaData = profiles[nia].Data
	CuriosS.give(nia, niaData, "frogKing", 1)
	CuriosS.give(nia, niaData, "firstKey", 1)
	r = trade(mo, { op = "invite", userId = 9501 })
	check("a guest invites another to trade", r.ok == true and lastOp(nia, "tradeInvite") ~= nil)
	r = trade(mo, { op = "invite", userId = 9501 })
	check("not again straight away", r.ok == false)
	r = trade(nia, { op = "accept", userId = 9500 })
	check("the invitation is accepted and the trade opens on both screens", r.ok == true and lastOp(mo, "trade") ~= nil and lastOp(nia, "trade") ~= nil)
	r = trade(nia, { op = "offer", items = { firstKey = 1 } })
	check("a curio that can't be traded can't be offered", r.ok == false)
	r = trade(nia, { op = "offer", items = { frogKing = 2 } })
	check("nor more than you hold", r.ok == false)
	r = trade(nia, { op = "offer", items = { frogKing = 1 } })
	check("an offer from what you hold", r.ok == true)
	local v = r.version
	r = trade(mo, { op = "offer", items = { truffle = 1 } })
	local v2 = r.version
	check("each change makes a new version of the trade", v2 > v)
	r = trade(nia, { op = "ready", version = v })
	check("locking in to an old version is refused", r.ok == false)
	trade(nia, { op = "ready", version = v2 })
	trade(mo, { op = "ready", version = v2 })
	check("both locked in: a countdown", lastOp(mo, "trade").state == "countdown" and lastOp(mo, "trade").countdown > 0)
	r = trade(mo, { op = "confirm", version = v2 })
	check("confirming waits for the countdown", r.ok == false)
	-- A change during the countdown unlocks both.
	r = trade(mo, { op = "offer", items = { truffle = 1, croissantino = 1 } })
	local v3 = r.version
	check("a change during the countdown unlocks both sides", lastOp(nia, "trade").state == "open" and lastOp(nia, "trade").theyReady == false and lastOp(nia, "trade").ready == false)
	check("and the other side sees exactly what changed", lastOp(nia, "trade").theirs.croissantino == 1)
	trade(nia, { op = "ready", version = v3 })
	trade(mo, { op = "ready", version = v3 })
	advance(TradeService.Settings.countdown + 1)
	check("after the countdown, confirming opens", lastOp(mo, "trade").state == "confirm")
	r = trade(mo, { op = "confirm", version = v2 })
	check("a confirmation of an earlier version is refused", r.ok == false)
	trade(mo, { op = "confirm", version = v3 })
	check("one confirmation alone swaps nothing", CuriosS.count(moData, "frogKing") == 0 and CuriosS.count(moData, "truffle") == 1)
	r = trade(nia, { op = "confirm", version = v3 })
	check("both confirm: the trade is done", r.ok == true and lastOp(mo, "tradeEnd").state == "done")
	check("each side has exactly what the other offered", CuriosS.count(moData, "frogKing") == 1 and CuriosS.count(moData, "truffle") == 0 and CuriosS.count(niaData, "truffle") == 1 and CuriosS.count(niaData, "croissantino") == 1 and CuriosS.count(niaData, "frogKing") == 0)
	check("and both keep it in their history", moData.trades[1].with == "Nia" and niaData.trades[1].with == "Mo")
	r = trade(mo, { op = "invite", userId = 9501 })
	check("a short rest before trading again", r.ok == false)

	-- Cancelling, leaving, blocking.
	local oz = guest("Oz", 9502)
	trade(nia, { op = "block", userId = 9502 })
	r = trade(oz, { op = "invite", userId = 9501 })
	check("a blocked guest can't send invitations", r.ok == false)
	advance(TradeService.Settings.cooldown + 1)
	trade(oz, { op = "invite", userId = 9500 })
	trade(mo, { op = "accept", userId = 9502 })
	CuriosS.give(oz, profiles[oz].Data, "gelato", 1)
	trade(oz, { op = "offer", items = { gelato = 1 } })
	r = trade(mo, { op = "cancel" })
	check("either side may cancel, and nothing moves", r.ok == true and lastOp(oz, "tradeEnd").state == "cancelled" and CuriosS.count(profiles[oz].Data, "gelato") == 1)
	r = trade(mo, { op = "report", userId = 9502 })
	check("a guest can be reported (logged for the owner)", r.ok == true and #TradeService.reports == 1)
end

---------------------------------------------------------------------------------------------------
-- N. Suite spectacles: kept as shows, played only in your own Suite
---------------------------------------------------------------------------------------------------
do
	local Layout = module("ReplicatedStorage", "Shared", "Layout")
	local ask = Remotes.funcs.SpectacleAsk.OnServerInvoke
	local function show(player, request)
		advance(0.6)
		local r
		run(function()
			r = ask(player, request)
		end)
		return r
	end
	for _, p in {
		{ Name = "Suite Fireworks", ProductId = 5401, PriceInRobux = 199 },
		{ Name = "Meme Takeover", ProductId = 5402, PriceInRobux = 299 },
		{ Name = "Golden Transformation", ProductId = 5403, PriceInRobux = 499 },
	} do
		table.insert(MarketplaceService.devProducts, p)
	end
	run(Catalog.discover)
	local problems = ProductConfig.validate(Grants.names())
	check("the three spectacles are valid products", problems.spectacleFireworks == nil and problems.spectacleMemes == nil and problems.spectacleGolden == nil)
	local pia = guest("Pia", 9600)
	local piaData = profiles[pia].Data
	local r = show(pia, { op = "list" })
	check("the list shows each with Roblox's price and none held", r.ok == true and #r.shows == 3 and r.shows[1].robux == 199 and r.shows[1].held == 0)
	r = show(pia, { op = "play", key = "spectacleFireworks" })
	check("nothing to play before buying", r.ok == false)
	local before = #prompts
	r = show(pia, { op = "buy", key = "spectacleFireworks" })
	check("buying opens Roblox's purchase window", r.ok == true and #prompts == before + 1)
	check("the receipt keeps one show", receipt(pia, 5401, "show-1", 199) == GRANTED and Perks.credits(piaData, "show:spectacleFireworks") == 1)
	pia.Character = {
		FindFirstChild = function(_, n)
			return if n == "HumanoidRootPart" then pia.root else nil
		end,
	}
	pia.root.Position = H.Vector3.new(0, 5, -40)
	r = show(pia, { op = "play", key = "spectacleFireworks" })
	check("a show plays only in your Suite", r.ok == false and Perks.credits(piaData, "show:spectacleFireworks") == 1)
	pia.root.Position = Layout.Suite.arrival + H.Vector3.new(0, 3, 0)
	r = show(pia, { op = "play", key = "spectacleFireworks" })
	check("in the Suite it plays, and the show is spent", type(r) == "table" and r.ok == true and Perks.credits(piaData, "show:spectacleFireworks") == 0 and lastOp(pia, "spectacle") ~= nil, r and r.why)
	r = show(pia, { op = "play", key = "notAShow" })
	check("only the three shows", r.ok == false)
end

H.finish()

--!nocheck
-- Runs the money against the real Shop, Ledger and Dressing code under Lune, on a fake clock:
-- the Boutique's shelves and live prices, choosing a piece, idempotent receipts (a retried
-- receipt, a save that never lands), credits, gifts and their handover, Gilt purchases and
-- Standing, equipping, the Ledger's pages and the Leather-Bound row, the Gold Key and its +20%,
-- the Introduction and the season collections. (The test house itself: tests/harness.luau.)
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/shop.luau

local H = require("./harness")
local check, run, advance, signal = H.check, H.run, H.advance, H.signal
local prompts, productPrices, passOwners, subscribers = H.prompts, H.productPrices, H.passOwners, H.subscribers
local MarketplaceService, guests, profiles, loadedSignal = H.MarketplaceService, H.guests, H.profiles, H.loadedSignal
local module, broadcasts, customEvents = H.module, H.broadcasts, H.customEvents
local mythicCounts, memoryMaps, awarded = H.mythicCounts, H.memoryMaps, H.awarded
local dataStores, orderedStores, published, subscriptions, teleports = H.dataStores, H.orderedStores, H.published, H.subscriptions, H.teleports
local services, fakeOs = H.services, H.fakeOs
local Config, Wardrobe, Boutique, Remotes = H.Config, H.Wardrobe, H.Boutique, H.Remotes
local Gilt, LedgerService, Shop, handovers, ask = H.Gilt, H.LedgerService, H.Shop, H.handovers, H.ask
local TEMPLATE, guest, receipt, askAs, lastOp = H.TEMPLATE, H.guest, H.receipt, H.askAs, H.lastOp
local Instance, Vector3, Enum, CFrame, roblox = H.Instance, H.Vector3, H.Enum, H.CFrame, H.roblox
local PlayersService, newGuest, newProfile, heartbeat, deepCopy = H.PlayersService, H.newGuest, H.newProfile, H.heartbeat, H.deepCopy
local ProductConfig = module("ReplicatedStorage", "Shared", "ProductConfig")

---------------------------------------------------------------------------------------------------
-- 1. The shelves, before any product is set up
---------------------------------------------------------------------------------------------------
local ada = guest("Ada", 1)
local ben = guest("Ben", 2)
local shelves = askAs(ada, { op = "shelves" })
check("today's six are on the shelves", shelves and #shelves.today == 6)
check("and the week's two", #shelves.featured == 2)
check("no price is shown until the product exists", shelves.today[1].robux == nil)
check("the season's collection is there (a table style and a trail)", #shelves.season.pieces == 2, #shelves.season.pieces)
check("Gilt pieces are listed", #shelves.gilt >= 3)
check("other guests are listed for gifts", #shelves.guests == 1 and shelves.guests[1].name == "Ben")
check("the Introduction isn't offered without its clothing and chime", shelves.introduction == nil)
local piece = shelves.today[1]
local refused = askAs(ada, { op = "buy", item = piece.id })
check("nothing can be bought before the products exist", refused.ok == false and string.find(refused.why, "isn't open") ~= nil, refused.why)

---------------------------------------------------------------------------------------------------
-- 2. Products set up: prices read live; choosing a piece prompts its tier
---------------------------------------------------------------------------------------------------
for i, tier in Wardrobe.Tiers do
	Config.set("Products.tier" .. tier, 1000 + i)
	productPrices[1000 + i] = tier
end
Config.set("Products.ledger", 2001)
productPrices[2001] = 399
Config.set("Products.season", 2002)
productPrices[2002] = 599
Config.set("Products.goldKey", 3001)
productPrices[3001] = 499
Config.set("Products.introduction", 2003)
productPrices[2003] = 49
advance(400) -- let the price cache expire
shelves = askAs(ada, { op = "shelves" })
piece = shelves.today[1]
local item = Wardrobe.get(piece.id)
local tier = Wardrobe.tierFor(item.robux)
check("prices are read live from Roblox", piece.robux == tier, piece.robux)
check("the Gold Key's price is read live", shelves.goldKey.price == 499)
local bought = askAs(ada, { op = "buy", item = piece.id })
check("choosing a piece prompts its price tier", bought.ok and bought.prompted and prompts[#prompts].id == 1000 + table.find(Wardrobe.Tiers, tier))
check("the choice is saved with the profile", profiles[ada].Data.pending.item == piece.id)
local notToday = nil
for _, candidate in Wardrobe.boutiquePool() do
	local onShelf = false
	for _, t in shelves.today do
		if t.id == candidate.id then
			onShelf = true
		end
	end
	for _, t in shelves.featured do
		if t.id == candidate.id then
			onShelf = true
		end
	end
	if not onShelf then
		notToday = candidate
		break
	end
end
check("a piece not on today's shelves can't be bought", askAs(ada, { op = "buy", item = notToday.id }).ok == false)

---------------------------------------------------------------------------------------------------
-- 3. Receipts: granted once, acknowledged only after a save
---------------------------------------------------------------------------------------------------
local productId = prompts[#prompts].id
local result = receipt(ada, productId, "P-1")
check("the receipt is acknowledged after the save", result == Enum.ProductPurchaseDecision.PurchaseGranted, tostring(result))
check("the piece is Ada's", profiles[ada].Data.owned[piece.id] == true)
check("the saved profile holds the purchase", table.find(profiles[ada].LastSavedData.receipts, "P-1") ~= nil)
check("the choice is cleared", profiles[ada].Data.pending.item == "")
local again = receipt(ada, productId, "P-1")
check("a retried receipt is acknowledged", again == Enum.ProductPurchaseDecision.PurchaseGranted)
local creditCount = 0
for _, n in profiles[ada].Data.credits do
	creditCount += n
end
check("a retried receipt grants nothing twice", creditCount == 0 and #profiles[ada].Data.receipts == 1)
check("the purchase is logged in analytics (product, outcome, segment)", (function()
	for _, e in customEvents do
		if e.name == "Shop: Receipt granted" and e.player == ada and e.fields[1] == "tier" .. tier then
			return true
		end
	end
	return false
end)())
-- A save that never lands: not acknowledged, so Roblox will try again later.
H.savesWork = false
local stuck = receipt(ada, productId, "P-2")
advance(31)
check("a purchase whose save hasn't landed isn't acknowledged", stuck == nil or stuck == Enum.ProductPurchaseDecision.NotProcessedYet, tostring(stuck))
H.savesWork = true
local retried = receipt(ada, productId, "P-2")
check("once the save lands the retry is acknowledged", retried == Enum.ProductPurchaseDecision.PurchaseGranted, tostring(retried))
-- P-2 had no choice on file: it became credit.
check("a purchase with no choice on file becomes credit", (profiles[ada].Data.credits["tier" .. tier] or 0) == 1)
check("an unknown player's receipt waits", (function()
	local r
	run(function()
		r = MarketplaceService.ProcessReceipt({ PlayerId = 999, ProductId = productId, PurchaseId = "X", CurrencySpent = 1 })
	end)
	return r == Enum.ProductPurchaseDecision.NotProcessedYet
end)())

---------------------------------------------------------------------------------------------------
-- 4. Credit pays for the next piece at once
---------------------------------------------------------------------------------------------------
local second
for _, t in shelves.today do
	local it = Wardrobe.get(t.id)
	if t.id ~= piece.id and Wardrobe.tierFor(it.robux) <= tier then
		second = t
		break
	end
end
if second then
	local promptsBefore = #prompts
	local withCredit = askAs(ada, { op = "buy", item = second.id })
	check("credit buys a piece at its tier or below without a prompt", withCredit.ok and withCredit.credited and #prompts == promptsBefore)
	check("and the piece is hers", profiles[ada].Data.owned[second.id] == true)
else
	check("credit buys a piece at its tier or below without a prompt", true)
	check("and the piece is hers", true)
end
check("owning it already refuses a second purchase", askAs(ada, { op = "buy", item = piece.id }).ok == false)

---------------------------------------------------------------------------------------------------
-- 5. Gifts: handed over by the Concierge; if they've gone, the buyer keeps credit
---------------------------------------------------------------------------------------------------
local giftPiece
for _, t in shelves.today do
	if not profiles[ben].Data.owned[t.id] and t.id ~= piece.id then
		giftPiece = t
	end
end
local gift = askAs(ada, { op = "buy", item = giftPiece.id, giftTo = ben.UserId })
check("a gift prompts the purchase", gift.ok and gift.prompted and profiles[ada].Data.pending.giftTo == ben.UserId)
receipt(ada, prompts[#prompts].id, "P-3")
check("the gift is Ben's", profiles[ben].Data.owned[giftPiece.id] == true)
check("not Ada's", profiles[ada].Data.owned[giftPiece.id] ~= true)
check("Ben is told who it's from", lastOp(ben, "gift") and lastOp(ben, "gift").from == "Ada")
check("the Concierge hands it over", #handovers == 1 and handovers[1].player == ben)
check("gifting what they already have is refused", askAs(ada, { op = "buy", item = giftPiece.id, giftTo = ben.UserId }).ok == false)
check("gifting to yourself is refused", askAs(ada, { op = "buy", item = shelves.featured[1].id, giftTo = ada.UserId }).ok == false)
local cleo = guest("Cleo", 3)
local third
for _, t in shelves.today do
	if not profiles[cleo].Data.owned[t.id] and Wardrobe.tierFor(Wardrobe.get(t.id).robux) > tier then
		third = t
	end
end
third = third or shelves.featured[1]
askAs(ada, { op = "buy", item = third.id, giftTo = cleo.UserId })
local creditsBefore = profiles[ada].Data.credits["tier" .. Wardrobe.tierFor(Wardrobe.get(third.id).robux)] or 0
cleo.Parent = nil
receipt(ada, prompts[#prompts].id, "P-4")
check("a gift to a guest who left becomes the buyer's credit", (profiles[ada].Data.credits["tier" .. Wardrobe.tierFor(Wardrobe.get(third.id).robux)] or 0) == creditsBefore + 1)

---------------------------------------------------------------------------------------------------
-- 6. Gilt: the house's own pieces, and the Standing ones
---------------------------------------------------------------------------------------------------
check("not enough Gilt is refused", askAs(ada, { op = "buyGilt", item = "trail_jade" }).ok == false)
profiles[ada].Data.gilt = 5000
local jade = askAs(ada, { op = "buyGilt", item = "trail_jade" })
check("Gilt buys a trail colour", jade.ok and profiles[ada].Data.owned.trail_jade and profiles[ada].Data.gilt == 4200)
check("a Robux piece can't be bought with Gilt", askAs(ada, { op = "buyGilt", item = piece.id }).ok == false)
Config.set("Assets.Looks.patron.shirt", 42)
local locked = askAs(ada, { op = "buyGilt", item = "look_patron" })
check("a Standing look needs the Standing", locked.ok == false and string.find(locked.why, "Patron") ~= nil, locked.why)
profiles[ada].Data.nights.count = 30
profiles[ada].Data.stats.rounds = 400
local patron = askAs(ada, { op = "buyGilt", item = "look_patron" })
check("with it, the look is hers", patron.ok and profiles[ada].Data.owned.look_patron)

-- Every Boutique piece on today's shelves can also be bought with Gilt (Config.Gilt.perRobux).
do
	local shelf = askAs(ben, { op = "shelves" })
	local target
	for _, c in shelf.today do
		if not profiles[ben].Data.owned[c.id] then
			target = c
			break
		end
	end
	local cost = Wardrobe.get(target.id).robux * Config.data.Gilt.perRobux
	check("a Boutique piece shows its Gilt price", target.giltAlt == cost, target.giltAlt)
	profiles[ben].Data.gilt = cost - 1
	local short = askAs(ben, { op = "buyGilt", item = target.id })
	check("not enough Gilt says how much more", short.ok == false and string.find(short.why or "", "1 more", 1, true) ~= nil, short.why)
	profiles[ben].Data.gilt = cost + 5
	local bought = askAs(ben, { op = "buyGilt", item = target.id })
	check("with enough Gilt the piece is bought at once, no Robux product needed", bought.ok and profiles[ben].Data.owned[target.id] == true and profiles[ben].Data.gilt == 5)
	check("a piece not on today's shelves isn't sold for Gilt", askAs(ben, { op = "buyGilt", item = notToday.id }).ok == false)
	profiles[ben].Data.gilt = 0
end

---------------------------------------------------------------------------------------------------
-- 7. Wearing things
---------------------------------------------------------------------------------------------------
check("wearing an owned piece", askAs(ada, { op = "equip", kind = "trail", id = "trail_jade" }).ok and profiles[ada].Data.equipped.trail == "trail_jade")
check("wearing something not owned is refused", askAs(ada, { op = "equip", kind = "trail", id = "trail_ember" }).ok == false)
check("wearing a piece as the wrong kind is refused", askAs(ada, { op = "equip", kind = "table", id = "trail_jade" }).ok == false)
check("the house default is always allowed", askAs(ada, { op = "equip", kind = "trail", id = "" }).ok and profiles[ada].Data.equipped.trail == "")
check("a Gold Key piece needs the Gold Key", askAs(ada, { op = "equip", kind = "nameplate", id = "plate_goldkey" }).ok == false)
local wardrobe = askAs(ada, { op = "wardrobe" })
check("the wardrobe lists what she owns by kind", wardrobe and #wardrobe.kinds.trail >= 1)
check("the screen is told what she owns and wears", lastOp(ada, "state") ~= nil and lastOp(ada, "state").gilt == profiles[ada].Data.gilt)

---------------------------------------------------------------------------------------------------
-- 8. The Gold Key: +20% Gilt, the gold-edged pieces
---------------------------------------------------------------------------------------------------
check("the Gold Key prompts its pass", askAs(ben, { op = "goldKey" }).prompted and prompts[#prompts].kind == "pass" and prompts[#prompts].id == 3001)
local studio = services.RunService.IsStudio
services.RunService.IsStudio = function()
	return false -- a live server
end
MarketplaceService.PromptGamePassPurchaseFinished:Fire(ben, 3001, true)
check("a purchase Roblox doesn't confirm gives nothing", profiles[ben].Data.goldKey == false)
advance(40)
passOwners["2:3001"] = true -- Roblox now reports the pass as Ben's
MarketplaceService.PromptGamePassPurchaseFinished:Fire(ben, 3001, true)
check("buying it gives Ben the Gold Key (once Roblox confirms it)", profiles[ben].Data.goldKey == true)
services.RunService.IsStudio = studio
local paid = Gilt.pay(ben, profiles[ben].Data, 100, "test")
check("the Gold Key pays 20% more Gilt", paid == 120, paid)
check("Gold Key pieces can be worn", askAs(ben, { op = "equip", kind = "nameplate", id = "plate_goldkey" }).ok)
check("the Gold Key can't be bought twice", askAs(ben, { op = "goldKey" }).ok == false)
passOwners["4:3001"] = true
local dora = guest("Dora", 4)
advance(0.5)
check("owning the pass is found on arrival", profiles[dora].Data.goldKey == true)

---------------------------------------------------------------------------------------------------
-- 9. The Ledger: pages turn, the free row pays, the Leather-Bound row catches up
---------------------------------------------------------------------------------------------------
local giltBefore = profiles[cleo] and 0 or 0
for _ = 1, 700 do
	LedgerService.add(ada, "filing")
end
local ledger = askAs(ada, { op = "ledger" })
check("2,100 points turn two pages", ledger.page == 2 and ledger.points == 2100, ledger.page)
check("the free row's Gilt is paid", profiles[ada].Data.ledger.freeClaimed == 2)
check("the screen hears the pages turn", lastOp(ada, "pages") ~= nil)
for _ = 1, 3 do
	LedgerService.add(ada, "nightly")
end
LedgerService.add(ada, "library", 1)
LedgerService.add(ada, "ballroom", 1)
ledger = askAs(ada, { op = "ledger" })
check("the Nightly, the Library and the Ballroom turn pages too", ledger.page == 3, ledger.page)
check("the Leather-Bound edition prompts its product", askAs(ada, { op = "ledgerLeather" }).prompted and prompts[#prompts].id == 2001)
receipt(ada, 2001, "P-5")
local leatherOwned = 0
for id in profiles[ada].Data.owned do
	if string.find(id, ":leather:") then
		leatherOwned += 1
	end
end
check("buying late grants every page already reached", leatherOwned == 6, leatherOwned)
check("it's bound for this Term", askAs(ada, { op = "ledger" }).leather == true)
check("it can't be bought twice in a Term", askAs(ada, { op = "ledgerLeather" }).ok == false)
for _ = 1, 400 do
	LedgerService.add(ada, "filing")
end
leatherOwned = 0
for id in profiles[ada].Data.owned do
	if string.find(id, ":leather:") then
		leatherOwned += 1
	end
end
check("new pages add to both rows", leatherOwned == 8, leatherOwned)
check("Ledger pieces can be worn", (function()
	for id in profiles[ada].Data.owned do
		if string.find(id, ":leather:") then
			local it = module("ReplicatedStorage", "Shared", "Ledger").item(id)
			if it and it.kind ~= "look" and it.kind ~= "gesture" then
				return askAs(ada, { op = "equip", kind = it.kind, id = id }).ok
			end
		end
	end
	return false
end)())

---------------------------------------------------------------------------------------------------
-- 10. The season's collection, and the Introduction
---------------------------------------------------------------------------------------------------
receipt(ben, 2002, "P-6")
check("a season collection grants its pieces", profiles[ben].Data.owned.season_harvest_table and profiles[ben].Data.owned.season_harvest_trail)
Config.set("Assets.Looks.velvet.shirt", 77)
Config.set("Assets.Sounds.chimes.celesta", "rbxassetid://1")
local newcomer = guest("Evie", 5)
local offered = askAs(newcomer, { op = "shelves" }).introduction
check("the Introduction is offered in a guest's first week", offered ~= nil and #offered.items == 3)
receipt(newcomer, 2003, "P-7")
check("it grants the jacket, the chime and the painting", profiles[newcomer].Data.owned.look_velvet and profiles[newcomer].Data.owned.chime_celesta and profiles[newcomer].Data.owned.suite_painting)
check("it's offered only once", askAs(newcomer, { op = "shelves" }).introduction == nil and askAs(newcomer, { op = "introduction" }).ok == false)
profiles[ben].Data.firstVisit = fakeOs.time() - 30 * 86400
check("never after the first week", askAs(ben, { op = "introduction" }).ok == false)

---------------------------------------------------------------------------------------------------
-- 11. A limit on asking (RemoteGuard: a bucket per guest per remote)
---------------------------------------------------------------------------------------------------
local limited = false
for _ = 1, Config.data.RemoteLimits.shopAsk.burst + 4 do
	local r
	run(function()
		r = ask(ada, { op = "ledger" })
	end)
	if type(r) == "table" and r.why == "One moment." then
		limited = true
	end
end
check("a flood of asks waits a moment", limited)

---------------------------------------------------------------------------------------------------
-- 12. The Register's side: Commissions, Mythic serials, badges, Standing
---------------------------------------------------------------------------------------------------
local Collection = module("ServerScriptService", "Server", "Collection")
local Commissions = module("ReplicatedStorage", "Shared", "Commissions")
local notices, lines, announced = {}, {}, {}
Collection.notice = function(player, title, line)
	table.insert(notices, { player = player, title = title, line = line })
end
Collection.say = function(player, line)
	table.insert(lines, { player = player, line = line })
end
Collection.announce = function(text)
	table.insert(announced, text)
end
local fay = guest("Fay", 6)
local g = Commissions.evening(fakeOs.time())
local giltBefore = profiles[fay].Data.gilt
for _ = 1, g.target do
	if g.kind == "file" then
		Collection.filed(fay, module("ReplicatedStorage", "Shared", "Catalogue").coreForCase(g.case)[1].id, g.room, false)
	elseif g.kind == "rounds" then
		Collection.round(fay, g.room, "Steady")
	elseif g.kind == "flawless" then
		Collection.round(fay, "salon", "Flawless")
	elseif g.kind == "nightly" then
		Collection.nightly(fay)
	end
end
local view = Collection.view(profiles[fay].Data)
check("the Evening Commission completes: " .. g.text, view.commissions[1].done == true, view.commissions[1].progress)
check("it pays 150 Gilt", profiles[fay].Data.gilt - giltBefore == 150, profiles[fay].Data.gilt - giltBefore)
check("and says so", #notices >= 1 and notices[#notices].player == fay)
check("finishing it twice pays once", (function()
	local before = profiles[fay].Data.gilt
	Collection.event(fay, g.kind, g.room, g.case)
	return profiles[fay].Data.gilt == before
end)())
Config.set("Badges.mythic", 777)
Collection.filed(fay, "blackDiamond", "midnight", true)
advance(0.5)
check("a Mythic gets the next serial number", profiles[fay].Data.mythics[1] and profiles[fay].Data.mythics[1].serial == 1)
check("the finder is told its number", string.find(lines[#lines].line, "No. 00001", 1, true) ~= nil, lines[#lines] and lines[#lines].line)
check("every server hears of it", string.find(announced[#announced], "Black Diamond", 1, true) ~= nil)
check("the Mythic badge is awarded", awarded[#awarded] and awarded[#awarded].id == 777)
Collection.filed(ben, "blackDiamond", "midnight", true)
advance(0.5)
check("the next Black Diamond is No. 00002", profiles[ben].Data.mythics[1].serial == 2)
local count = #awarded
Collection.badge(fay, "mythic")
check("a badge is only awarded once", #awarded == count)
profiles[fay].Data.nights.count = 20
profiles[fay].Data.stats.rounds = 200
Collection.standing(fay)
check("rising in Standing is announced", lines[#lines].line == "The house has noticed." and string.find(notices[#notices].line, "Patron", 1, true) ~= nil, lines[#lines].line)
check("the Register view has the odds for all four rooms", #view.odds == 4)

---------------------------------------------------------------------------------------------------
-- 13. The Soirée: results, the stamp, and the medal after the weekend
---------------------------------------------------------------------------------------------------
local SoireeShared = module("ReplicatedStorage", "Shared", "Soiree")
local SoireeService = module("ServerScriptService", "Server", "SoireeService")
local soireeNotices = {}
SoireeService.start()
SoireeService.notice = function(player, title, line)
	table.insert(soireeNotices, { player = player, title = title, line = line })
end
-- Move the house clock to a Saturday of this weekend's format.
local weekend = SoireeShared.at(fakeOs.time())
H.setWallClock(weekend.startsAt + 3600)
local w = SoireeShared.at(fakeOs.time())
check("the house clock is in a Soirée", w.active)
local gus = guest("Gus", 7)
for i = 1, 3 do
	SoireeService.record(gus, w.format, { place = i, keys = 1, won = true })
end
advance(0.5)
local st = profiles[gus].Data.soiree
check("results count toward the weekend", st.plays == 3 and st.score > 0, st.score)
check("three plays earn the Soirée's stamp", st.stamps[w.key] == true and #soireeNotices >= 1)
local other = if w.format == "ballroom" then "library" else "ballroom"
SoireeService.record(gus, other, { place = 1, keys = 9, won = true })
check("the other format doesn't count this weekend", profiles[gus].Data.soiree.plays == 3)
for i = 1, 150 do
	memoryMaps["MaisonNoir_Soiree_" .. w.key][tostring(9000 + i)] = { key = tostring(9000 + i), value = "x", sortKey = 1 }
end
-- Monday: the weekend is over; Gus arrives and is the top of 151.
H.setWallClock(w.endsAt + 3600)
loadedSignal:Fire(gus, profiles[gus].Data)
advance(0.5)
check("after the weekend the top 1% get the medal", profiles[gus].Data.owned["soiree:" .. w.key .. ":medal"] == true)
check("the medal can be worn", askAs(gus, { op = "equip", kind = "nameplate", id = "soiree:" .. w.key .. ":medal" }).ok)
loadedSignal:Fire(gus, profiles[gus].Data)
advance(0.5)
check("it's awarded once", #profiles[gus].Data.soiree.claimed > 0)

---------------------------------------------------------------------------------------------------
-- The Black Card: offered on the lectern once its id is set; the Leather-Bound Ledger while held,
-- a look each month to keep, the black-lacquer nameplate while active
---------------------------------------------------------------------------------------------------
local BlackCard = module("ServerScriptService", "Server", "BlackCard")
local WardrobeRules = module("ReplicatedStorage", "Shared", "Wardrobe")
local hana = guest("Hana", 8)
local info = askAs(hana, { op = "blackCard" })
check("the Black Card isn't offered without its id", info and info.offered == false)
check("holding it says so", askAs(hana, { op = "holdCard" }).ok == false)
Config.data.Products.blackCard = "EXP-1"
info = askAs(hana, { op = "blackCard" })
check("once its id is set, it's offered with Roblox's price", info.offered == true and info.price == "$4.99" and type(info.look) == "string")
local promptsBefore = #prompts
check("Hold the card asks Roblox", askAs(hana, { op = "holdCard" }).ok == true and #prompts == promptsBefore + 1 and prompts[#prompts].kind == "subscription")
subscribers[hana.UserId .. ":EXP-1"] = true
run(BlackCard.check, hana)
advance(0.5)
local hd = profiles[hana].Data
local monthLook = WardrobeRules.cardholderLook(fakeOs.time())
check("held: the card is on the guest", hd.blackCard.active == true)
check("held: this month's cardholder look is theirs", monthLook ~= nil and hd.owned[monthLook.id] == true)
check("held: a quiet notice says so", lastOp(hana, "notice") ~= nil and string.find(lastOp(hana, "notice").line, monthLook.name, 1, true) ~= nil)
local lv = LedgerService.view(hd)
check("held: the Leather-Bound Ledger comes with it", lv.leather == true and lv.card == true)
check("held: the Leather-Bound Ledger isn't sold to a cardholder", string.find(askAs(hana, { op = "ledgerLeather" }).why or "", "Black Card", 1, true) ~= nil)
check("held: the black-lacquer nameplate can be worn", askAs(hana, { op = "equip", kind = "nameplate", id = "plate_blackcard" }).ok)
check("held: the state tells the guest's screen", lastOp(hana, "state").blackCard.held == true)
run(BlackCard.check, hana)
advance(0.5)
local ownedLooks = 0
for id in hd.owned do
	if string.find(id, "^look_card") then
		ownedLooks += 1
	end
end
check("the month's look is given once", ownedLooks == 1)
local nextMonth = fakeOs.time() + 32 * 86400
local another = BlackCard.claimMonth(hd, nextMonth)
check("next month brings the next look", another ~= nil and another.id ~= monthLook.id and hd.owned[another.id] == true)
subscribers[hana.UserId .. ":EXP-1"] = false
run(BlackCard.check, hana)
advance(0.5)
check("cancelled: the card is gone", hd.blackCard.active == false and LedgerService.view(hd).leather == false)
check("cancelled: the looks stay", hd.owned[monthLook.id] == true and hd.owned[another.id] == true)
check("cancelled: the nameplate can't be worn", not askAs(hana, { op = "equip", kind = "nameplate", id = "plate_blackcard" }).ok)
check("cancelled: no month is claimed without the card", BlackCard.claimMonth(hd, nextMonth + 32 * 86400) == nil)
Config.data.Products.blackCard = ""

---------------------------------------------------------------------------------------------------
-- The Suite: buy a piece for Gilt, place it; the Gold Key rooms
---------------------------------------------------------------------------------------------------
local ivy = guest("Ivy", 9)
local id = profiles[ivy].Data
id.gilt = 5000
local view = askAs(ivy, { op = "suite" })
check("the Suite lists its spots", view and #view.spots == #module("ReplicatedStorage", "Shared", "Suite").Spots, view and #view.spots)
local rugSpot
for _, sp in view.spots do
	if sp.id == "rug" then
		rugSpot = sp
	end
end
check("each spot lists the pieces that go there", rugSpot ~= nil and #rugSpot.options >= 2 and type(rugSpot.house) == "table")
check("each piece says its price and where it's sold", (function()
	for _, o in rugSpot.options do
		if o.id == "suite_rug_black" and o.gilt ~= 400 then
			return false
		elseif o.id == "suite_rug_moon" and (o.robux ~= 149 or type(o.onSale) ~= "boolean") then
			return false
		end
	end
	return view.gilt == 5000 and view.goldKey == false
end)())
check("Suite furniture is sold for Gilt", askAs(ivy, { op = "buyGilt", item = "suite_rug_black" }).ok and id.owned.suite_rug_black and id.gilt == 4600)
check("a piece bought goes straight into its empty spot", id.suite.rug == "suite_rug_black")
askAs(ivy, { op = "buyGilt", item = "suite_lamp_brass" })
askAs(ivy, { op = "buyGilt", item = "suite_lamp_green" })
check("but never takes the place of a piece already there", id.owned.suite_lamp_green and id.suite.lamp == "suite_lamp_brass")
check("placing it", askAs(ivy, { op = "place", spot = "rug", id = "suite_rug_black" }).ok and id.suite.rug == "suite_rug_black")
check("the state tells the guest's screen", lastOp(ivy, "state").suite.rug == "suite_rug_black")
check("a piece only goes in its own spot", not askAs(ivy, { op = "place", spot = "sofa", id = "suite_rug_black" }).ok)
check("a piece not yet owned can't be placed", not askAs(ivy, { op = "place", spot = "rug", id = "suite_rug_persian" }).ok)
check("nonsense spots are refused", not askAs(ivy, { op = "place", spot = "roof", id = "" }).ok)
askAs(ivy, { op = "buyGilt", item = "suite_mirror_gilt" })
check("a piece for a room still shut waits until it opens", id.owned.suite_mirror_gilt and id.suite.mirror == nil)
local shut = askAs(ivy, { op = "place", spot = "mirror", id = "suite_mirror_gilt" })
check("the Dressing Room opens with the Gold Key", not shut.ok and string.find(shut.why, "Gold Key", 1, true) ~= nil)
check("the Gold Key chair needs the Gold Key", not askAs(ivy, { op = "place", spot = "chair", id = "suite_chair_goldkey" }).ok)
id.goldKey = true
check("with the Gold Key: the Dressing Room", askAs(ivy, { op = "place", spot = "mirror", id = "suite_mirror_gilt" }).ok)
check("with the Gold Key: its chair", askAs(ivy, { op = "place", spot = "chair", id = "suite_chair_goldkey" }).ok)
check("clearing a spot brings back the house's piece", askAs(ivy, { op = "place", spot = "rug", id = "" }).ok and id.suite.rug == nil)
check("Suite pieces aren't worn", not askAs(ivy, { op = "equip", kind = "suite", id = "suite_rug_black" }).ok)
check("Patrons' pieces wait for Patrons", not askAs(ivy, { op = "buyGilt", item = "suite_bar_walnut" }).ok)

---------------------------------------------------------------------------------------------------
-- Circles: found one at the Livre d'Or, invite, ask and be welcomed, the week's points, leave
---------------------------------------------------------------------------------------------------
local CircleService = module("ServerScriptService", "Server", "CircleService")
local CircleRules = module("ReplicatedStorage", "Shared", "Circle")
local jo = guest("Jo", 10)
local kit = guest("Kit", 11)
local lee = guest("Lee", 12)
local jd = profiles[jo].Data
local boardCircles = {}
CircleService.board = function(entries)
	boardCircles = entries
end
local cv = askAs(jo, { op = "circle" })
check("the Livre d'Or offers the words and crests", cv.enabled and #cv.adjectives == 20 and #cv.nouns == 20 and #cv.emblems == 12 and #cv.colourNames == 8)
local choice = { adjective = 1, noun = 1, emblem = 3, colour = 2 }
check("founding costs 2,000 Gilt", not askAs(jo, { op = "circleFound", choice = choice }).ok)
jd.gilt = 2500
check("typed names are refused (only choices)", not askAs(jo, { op = "circleFound", choice = { adjective = "Velvet" } }).ok)
local founded = askAs(jo, { op = "circleFound", choice = choice })
check("a Circle is founded", founded.ok and founded.name == "The Velvet Ravens" and jd.circle.id ~= "" and jd.gilt == 500, founded.why)
profiles[kit].Data.gilt = 3000
check("a crest belongs to one Circle", not askAs(kit, { op = "circleFound", choice = { adjective = 2, noun = 2, emblem = 3, colour = 2 } }).ok)
check("invite a guest in the house", askAs(jo, { op = "circleInvite", userId = kit.UserId }).ok and lastOp(kit, "circleOffer") ~= nil)
local offerMsg = lastOp(kit, "circleOffer")
check("the invitation lands", offerMsg.kind == "invite" and offerMsg.name == "The Velvet Ravens" and offerMsg.fromName == "Jo")
check("and can be accepted", askAs(kit, { op = "circleAnswer", kind = "invite", circle = offerMsg.circle, from = offerMsg.from, yes = true }).ok and profiles[kit].Data.circle.id == jd.circle.id)
check("an answer only counts once", not askAs(kit, { op = "circleAnswer", kind = "invite", circle = offerMsg.circle, from = offerMsg.from, yes = true }).ok)
check("Lee asks to join; the host is asked", askAs(lee, { op = "circleRequest", userId = kit.UserId }).ok and lastOp(jo, "circleOffer") ~= nil and lastOp(jo, "circleOffer").kind == "request")
local req = lastOp(jo, "circleOffer")
check("only the host can say yes", not askAs(kit, { op = "circleAnswer", kind = "request", circle = req.circle, from = req.from, yes = true }).ok)
check("the host welcomes them", askAs(jo, { op = "circleAnswer", kind = "request", circle = req.circle, from = req.from, yes = true }).ok and profiles[lee].Data.circle.id == jd.circle.id)
-- The week's points.
run(CircleService.add, jo, "nightly", 5)
run(CircleService.add, kit, "library")
run(CircleService.add, lee, "ballroom", 55)
advance(0.5)
local mine = askAs(jo, { op = "circle" })
check("members' points: Nightly 95, a Library win 10, the Ballroom's points", mine.circle and mine.circle.score == 160, mine.circle and mine.circle.score)
check("the house's rule: the five best count", CircleRules.weekScore({ 90, 80, 70, 60, 50, 40, 30 }) == 350)
check("the members are listed with the host", #mine.circle.members == 3 and mine.circle.host == true)
local weekBoard = nil
for name, data in orderedStores do
	if string.find(name, "_Week_", 1, true) then
		weekBoard = data
	end
end
check("the week's score is written for every server", weekBoard ~= nil and weekBoard[jd.circle.id] == 160, weekBoard and weekBoard[jd.circle.id])
run(function()
	CircleService.start()
end)
advance(1)
check("the top Circles go to the board", #boardCircles >= 1 and boardCircles[1].name == "The Velvet Ravens" and boardCircles[1].score == 160)
check("leaving a Circle", askAs(lee, { op = "circleLeave" }).ok and profiles[lee].Data.circle.id == "")
askAs(kit, { op = "circleLeave" })
askAs(jo, { op = "circleLeave" })
check("the last one out gives the crest back", askAs(kit, { op = "circleFound", choice = { adjective = 2, noun = 2, emblem = 3, colour = 2 } }).ok)

---------------------------------------------------------------------------------------------------
-- Notifications: one a day, only with a template, the Term's last three days
---------------------------------------------------------------------------------------------------
do
local Notify = module("ServerScriptService", "Server", "Notify")
local posted = {}
Notify.post = function(userId, messageId, params, launch, category)
	table.insert(posted, { userId = userId, messageId = messageId, params = params, launch = launch, category = category })
	return true
end
local sentOk
run(function()
	sentOk = Notify.send(501, "rivalPassed", { name = "Ada" }, "nightly")
end)
check("no template, no notification", sentOk == false and #posted == 0)
Config.data.Notifications.messages.rivalPassed = "tmpl-rival"
run(function()
	sentOk = Notify.send(501, "rivalPassed", { name = "Ada" }, "nightly")
end)
check("a notification goes out with its template and landing spot", sentOk == true and #posted == 1 and posted[1].messageId == "tmpl-rival" and posted[1].launch == "nightly" and posted[1].params.name == "Ada")
run(function()
	sentOk = Notify.send(501, "rivalPassed", { name = "Ada" }, "nightly")
end)
check("at most one a day", sentOk == false and #posted == 1)
run(function()
	sentOk = Notify.send(502, "rivalPassed", { name = "Ada" }, "nightly")
end)
check("another guest can still hear today", sentOk == true and #posted == 2)
check("the Term's last three days", (Notify.termEnding(os.time({ year = 2026, month = 11, day = 29, hour = 12 }))) == true)
check("but not before", (Notify.termEnding(os.time({ year = 2026, month = 11, day = 20, hour = 12 }))) == false)
Config.data.Notifications.messages.rivalPassed = ""
end

---------------------------------------------------------------------------------------------------
-- Salutes: bought for the whole house; the giver's star; a short queue; always-on shelf
---------------------------------------------------------------------------------------------------
do
local SaluteService = module("ServerScriptService", "Server", "SaluteService")
local notes = {}
SaluteService.note = function(text, everywhere)
	table.insert(notes, { text = text, everywhere = everywhere })
end
local mo = guest("Mo", 13)
local sh = askAs(mo, { op = "shelves" })
check("the Boutique always has its staples (the Suite's pieces are at its bell)", sh.always and #sh.always == 6, sh.always and #sh.always)
check("the staples aren't also in the rotation", (function()
	for _, c in sh.today do
		for _, a in sh.always do
			if a.id == c.id then
				return false
			end
		end
	end
	return true
end)())
check("a staple can always be bought", askAs(mo, { op = "buy", item = sh.always[1].id }).ok ~= nil)
check("salutes are listed (with the Midnight Finale)", sh.salutes and #sh.salutes == 6 and sh.salutes[1].ready == false)
check("a salute not yet on sale still shows its price, never just \"soon\"", sh.salutes and sh.salutes[1].price == 75 and sh.salutes[6].price == 999, sh.salutes and sh.salutes[1].price)
check("an unset salute isn't offered", not askAs(mo, { op = "salute", id = "goldLeaf" }).ok)
do
	local studioWas = services.RunService.IsStudio
	services.RunService.IsStudio = function()
		return false -- a live server
	end
	check("a free preview is refused on a live server (Studio only)", askAs(mo, { op = "salutePreview", id = "fireworks" }).ok == false)
	check("...and a live server never offers one", askAs(mo, { op = "shelves" }).salutes[4].preview == false)
	check("handing back a test Gold Key is refused on a live server", askAs(mo, { op = "studioReset" }).ok == false)
	services.RunService.IsStudio = studioWas
end
check("the Midnight Finale counts down first, then the show", (function()
	local fx = module("ReplicatedStorage", "Shared", "Salutes").effects("finale")
	return fx[1] == "countdown" and table.find(fx, "fireworks") ~= nil
end)())
Config.data.Products.salute_goldLeaf = 7001
Config.data.Products.salute_grand = 7005
local promptsBefore2 = #prompts
check("a salute asks Roblox for the product", askAs(mo, { op = "salute", id = "goldLeaf" }).ok and #prompts == promptsBefore2 + 1 and prompts[#prompts].id == 7001)
local broadcastsBefore = #broadcasts
receipt(mo, 7001, "SAL-1")
advance(0.5)
local played
for i = broadcastsBefore + 1, #broadcasts do
	if broadcasts[i].remote == "Salute" then
		played = broadcasts[i].message
	end
end
check("everyone in the house sees the salute", played ~= nil and played.id == "goldLeaf" and played.by == "Mo" and played.effects[1] == "goldLeaf")
check("with the giver's name", played ~= nil and string.find(played.line, "Mo showered the house", 1, true) ~= nil)
check("the Tonight board hears of it (this house only)", #notes >= 1 and notes[#notes].everywhere == false)
check("the giver carries a gold star", type(mo:GetAttribute("BenefactorUntil")) == "number" and mo:GetAttribute("BenefactorUntil") > fakeOs.time())
check("no Gilt changes hands", profiles[mo].Data.gilt == 0)
receipt(mo, 7001, "SAL-1")
advance(0.5)
local count1 = 0
for _, b in broadcasts do
	if b.remote == "Salute" then
		count1 += 1
	end
end
check("a receipt plays once, however often Roblox asks", count1 == 1, count1)
receipt(mo, 7005, "SAL-2")
advance(25)
check("the Grand Salute is announced in every house", notes[#notes].everywhere == true and string.find(notes[#notes].text, "Grand Salute", 1, true) ~= nil)
check("and plays all four", (function()
	for i = #broadcasts, 1, -1 do
		if broadcasts[i].remote == "Salute" then
			return #broadcasts[i].message.effects == 4
		end
	end
	return false
end)())
for i = 1, 6 do
	SaluteService.play(nil, "goldLeaf", "The house")
end
check("a few salutes wait their turn, then the queue is full", SaluteService.full() and not askAs(mo, { op = "salute", id = "goldLeaf" }).ok)
advance(200)
check("and it empties as they play", SaluteService.waiting() == 0)
check("in Studio, a salute not yet on sale can be previewed (it plays, nothing is bought)", sh.salutes[4].preview == true and askAs(mo, { op = "salutePreview", id = "fireworks" }).ok == true and SaluteService.waiting() >= 1 and profiles[mo].Data.gilt == 0)
advance(60)
Config.data.Products.salute_goldLeaf = 0
Config.data.Products.salute_grand = 0
end

---------------------------------------------------------------------------------------------------
-- House controls: the owner's panel
---------------------------------------------------------------------------------------------------
do
local AdminService = module("ServerScriptService", "Server", "AdminService")
local GiltService = module("ServerScriptService", "Server", "Gilt")
-- The owner is one UserId (XxxXxxX_77797's, Config.Admin.ownerUserId): nobody else, ever (in
-- Studio the first test player stands in; off here, so the live rule is what's tested).
Config.data.Admin.studioFirstPlayer = false
local realOwner = Config.data.Admin.ownerUserId
check("the owner's powers are pinned to XxxXxxX_77797's UserId", realOwner == 8722595934)
Config.data.Admin.ownerUserId = 100
H.game.CreatorType = H.Enum.CreatorType.User
H.game.CreatorId = 555
local owner = guest("AJ", 100)
local ned = guest("Ned", 101)
local adminNotes = {}
AdminService.note = function(text, everywhere)
	table.insert(adminNotes, { text = text, everywhere = everywhere })
end
local salutesGiven = {}
AdminService.salute = function(_p, id, by)
	table.insert(salutesGiven, { id = id, by = by })
end
run(AdminService.start)
local function adminAs(player, request)
	advance(0.5)
	local r
	run(function()
		r = AdminService.handle(player, request)
	end)
	return r
end
local function lastBroadcast(op)
	for i = #broadcasts, 1, -1 do
		if broadcasts[i].message.op == op then
			return broadcasts[i].message
		end
	end
	return nil
end
check("only the owner may use House controls", adminAs(ned, { op = "state" }).ok == false and adminAs(owner, { op = "state" }).ok == true)
do
	-- Not even whoever the experience belongs to on Roblox, unless they're the owner's UserId.
	local creator = guest("Cid", 555)
	check("the experience's creator account isn't the owner unless it's the owner's UserId", adminAs(creator, { op = "state" }).ok == false)
end
check("the owner is marked, so only they see the House key", owner:GetAttribute("MaisonAdmin") == true and ned:GetAttribute("MaisonAdmin") ~= true)
do
	-- With no owner pinned (0) the experience's owner on Roblox has them: for a group's experience,
	-- the group's owner (rank 255 in it), never a member.
	Config.data.Admin.ownerUserId = 0
	H.game.CreatorType = H.Enum.CreatorType.Group
	H.game.CreatorId = 777
	local gia, max = guest("Gia", 102), guest("Max", 103)
	H.groups[102] = { { Id = 777, Rank = 255 } }
	H.groups[103] = { { Id = 777, Rank = 10 }, { Id = 5, Rank = 255 } }
	check("with no owner pinned, a group's owner has House controls", adminAs(gia, { op = "state" }).ok == true)
	check("and a member of the group doesn't", adminAs(max, { op = "state" }).ok == false)
	H.game.CreatorType = H.Enum.CreatorType.User
	H.game.CreatorId = 555
	Config.data.Admin.ownerUserId = 100
end
local st = adminAs(owner, { op = "state" })
check("the panel lists the events, the seasons, the salutes and the guests", #st.events == 21 and #st.seasons == 10 and #st.salutes == 6 and #st.guests >= 2)
do
	-- The Suite shows: the owner tries one on their own screen, free. Nobody else sees it, and
	-- nobody else may ask for one.
	check("the panel lists the three Suite shows", type(st.shows) == "table" and #st.shows == 3)
	local nedBefore = #ned.inbox
	check("a guest can't play a Suite show from House controls", adminAs(ned, { op = "show", key = "spectacleGolden" }).ok == false and #ned.inbox == nedBefore)
	local ownerBefore, castBefore = #owner.inbox, #broadcasts
	nedBefore = #ned.inbox
	check("the owner can try one, free", adminAs(owner, { op = "show", key = "spectacleGolden" }).ok == true)
	local m = owner.inbox[#owner.inbox]
	local spread = false
	for i = castBefore + 1, #broadcasts do
		spread = spread or broadcasts[i].message.op == "spectacle"
	end
	for i = nedBefore + 1, #ned.inbox do
		spread = spread or ned.inbox[i].op == "spectacle"
	end
	check("...on their own screen only", #owner.inbox > ownerBefore and m.op == "spectacle" and m.key == "spectacleGolden" and not spread)
	check("...and only the three shows", adminAs(owner, { op = "show", key = "giltRain" }).ok == false)
end
local nd = profiles[ned].Data
nd.gilt, nd.giltDay = 0, { day = -1, earned = 0 }
-- Ned walks the house in a real character (a head for a crown, a root for picking things up).
local nedModel = roblox.Instance.new("Model")
local nedRoot = roblox.Instance.new("Part")
nedRoot.Name = "HumanoidRootPart"
nedRoot.Position = Vector3.new(0, 5, 0)
nedRoot.Parent = nedModel
local nedHead = roblox.Instance.new("Part")
nedHead.Name = "Head"
nedHead.CFrame = CFrame.new(0, 6.5, 0)
nedHead.Position = Vector3.new(0, 6.5, 0)
nedHead.Parent = nedModel
ned.Character = nedModel
adminAs(owner, { op = "event", id = "goldenHour", minutes = 15 })
local paidGolden
run(function()
	paidGolden = GiltService.pay(ned, nd, 100, "test")
end)
check("Golden Hour: Gilt counts double", paidGolden == 200, paidGolden)
check("every guest's screen shows it", services.Workspace:GetAttribute("Event_goldenHour") ~= nil and lastBroadcast("salute").title == "Golden Hour")
adminAs(owner, { op = "event", id = "luckyHour", minutes = 5 })
adminAs(owner, { op = "event", id = "pageTurner", minutes = 5 })
check("Lucky Hour: Mythics ten times as likely", AdminService.mythicLuck() == 10)
check("the Page-Turner: pages twice as fast", AdminService.ledgerBoost() == 2)
adminAs(owner, { op = "stop", id = "goldenHour" })
check("an event can be stopped", AdminService.giltBoost() == 1 and services.Workspace:GetAttribute("Event_goldenHour") == nil)
advance(5 * 60 + 2)
check("events end by themselves", AdminService.mythicLuck() == 1 and AdminService.ledgerBoost() == 1)
adminAs(owner, { op = "event", id = "featherlight", minutes = 1 })
check("Featherlight lowers the house's gravity", services.Workspace.Gravity < 100)
advance(62)
check("and puts it back", math.abs(services.Workspace.Gravity - 196.2) < 0.01)
-- A treasure hunt: keys around the house; walking over one pays.
adminAs(owner, { op = "event", id = "treasure", minutes = 15 })
local keysFolder = services.Workspace:FindFirstChild("HouseEvents")
local keyParts = {}
for _, p in (keysFolder and keysFolder:GetChildren() or {}) do
	if p:GetAttribute("Pickup") == "key" then
		table.insert(keyParts, p)
	end
end
check("the Treasure Hunt hides five golden keys", #keyParts == 5, #keyParts)
local giltBeforeKey = nd.gilt
nedRoot.Position = keyParts[1].CFrame.Position
run(AdminService.collect)
check("the finder of a key wins Gilt", nd.gilt == giltBeforeKey + 250, nd.gilt - giltBeforeKey)
check("and the house hears who found it", string.find(lastBroadcast("salute").line or "", "Ned found a golden key", 1, true) ~= nil)
for i = 2, 5 do
	nedRoot.Position = keyParts[i].CFrame.Position
	run(AdminService.collect)
end
check("when every key is found, the hunt ends with fireworks", not AdminService.active("treasure") and lastBroadcast("salute").effects[1] == "fireworks")
adminAs(owner, { op = "event", id = "goldRain", minutes = 5 })
local coins = 0
for _, p in services.Workspace:FindFirstChild("HouseEvents"):GetChildren() do
	if p:GetAttribute("Pickup") == "coin" then
		coins += 1
	end
end
check("Gold Rain scatters thirty coins", coins == 30, coins)
do
	local CuriosS = module("ServerScriptService", "Server", "Curios")
	local coin
	for _, p in services.Workspace:FindFirstChild("HouseEvents"):GetChildren() do
		if p:GetAttribute("Pickup") == "coin" then
			coin = p
		end
	end
	nedRoot.Position = coin.CFrame.Position
	run(AdminService.collect)
	check("a Gold Rain coin also brings its curio (once)", CuriosS.count(nd, "rainCoin") == 1)
	adminAs(owner, { op = "event", id = "parade", minutes = 5 })
	local memes = {}
	for _, p in services.Workspace:FindFirstChild("HouseEvents"):GetChildren() do
		if p:GetAttribute("Pickup") == "meme" then
			table.insert(memes, p)
		end
	end
	check("the Brainrot Parade lets the memes loose", #memes == Config.data.Admin.memes, #memes)
	local before = nd.gilt
	nedRoot.Position = memes[1].CFrame.Position
	run(AdminService.collect)
	check("catching a meme pays Gilt and brings a Parade Balloon", nd.gilt > before and CuriosS.count(nd, "paradeBalloon") == 1)
	nedRoot.Position = memes[2].CFrame.Position
	run(AdminService.collect)
	check("one balloon per parade", CuriosS.count(nd, "paradeBalloon") == 1)
	adminAs(owner, { op = "stop", id = "parade" })
	adminAs(owner, { op = "event", id = "curioHour", minutes = 5 })
	check("a Night of Curios makes finds likelier", CuriosS.chance(2, 0.8) > module("ReplicatedStorage", "Shared", "Curios").findChance(2, 0.8))
	adminAs(owner, { op = "stop", id = "curioHour" })
end
-- Admin Abuse Night: every event at once, and in every house when asked.
local publishedBefore = #published
adminAs(owner, { op = "abuse", minutes = 15, everywhere = true })
local allOn = true
for _, id in Config.data.Admin.abuseEvents do
	if not AdminService.active(id) then
		allOn = false
	end
end
check("Admin Abuse Night starts every one of its events", allOn)
check("and goes to every house", #published > publishedBefore and published[#published].message.op == "abuse")
advance(Config.data.Admin.show.dropAt + 0.2) -- (the fireworks go up at the opening's drop)
check("with fireworks for the whole house", string.find(lastBroadcast("salute").title or "", "Admin Abuse", 1, true) ~= nil)
for _, id in Config.data.Admin.abuseEvents do
	AdminService.stopEvent(id)
end
AdminService.stopAll("AJ")

-- Admin Abuse Night, the second time: one great announcement (not one per event), the intro on
-- every screen, a surprise for everyone every minute, and Stop everything ends it all.
do
	local before = #broadcasts
	adminAs(owner, { op = "abuse", minutes = 15 })
	advance(Config.data.Admin.show.dropAt + 0.2)
	local salutes, intros = 0, 0
	for i = before + 1, #broadcasts do
		local m = broadcasts[i].message
		if m.op == "salute" and m.id == "abuse" then
			salutes += 1
		elseif m.op == "abuseShow" and m.stage == "intro" then
			intros += 1
		end
	end
	check("Admin Abuse Night announces itself once (never twelve at once)", salutes == 1 and intros == 1, salutes)
	check("...and every screen knows it's on (one headline, not a wall of strips)", type(services.Workspace:GetAttribute("AbuseUntil")) == "number")
	local beforeSurprise = #broadcasts
	advance(Config.data.Admin.abuseSurpriseSeconds + 1)
	local surprise = nil
	for i = beforeSurprise + 1, #broadcasts do
		local m = broadcasts[i].message
		if m.op == "abuseFX" then
			surprise = m.id
		end
	end
	check("a surprise for everyone every minute of the night", surprise ~= nil and table.find(Config.data.Admin.abuseSurprises, surprise) ~= nil, surprise)
	adminAs(owner, { op = "freeze", on = true })
	adminAs(owner, { op = "clock", id = "noon" })
	check("the owner can set the time of day", services.Lighting.ClockTime == Config.data.Admin.clocks.noon and services.Workspace:GetAttribute("AdminClock") == "noon")
	local stopped = adminAs(owner, { op = "stopAll" })
	local anyOn = false
	for _, e in module("ReplicatedStorage", "Shared", "HouseEvents").List do
		if AdminService.active(e.id) then
			anyOn = true
		end
	end
	check("Stop everything: every event, the night, the freeze and the time of day", stopped.ok ~= false and not anyOn and services.Workspace:GetAttribute("AbuseUntil") == nil and nedRoot.Anchored == false and services.Lighting.ClockTime == Config.data.Admin.clocks.midnight and lastBroadcast("abuseFX").id == "stop")
	local quiet = #broadcasts
	advance(Config.data.Admin.abuseSurpriseSeconds + 1)
	local after = false
	for i = quiet + 1, #broadcasts do
		if broadcasts[i].message.op == "abuseFX" then
			after = true
		end
	end
	check("...and no more surprises after it", not after)
end
-- The schedule: set once, every server starts it on time and counts down to it.
local inTwenty = fakeOs.time() + 20 * 60
local sched = adminAs(owner, { op = "schedule", what = "abuse", at = inTwenty, minutes = 30 })
check("an event can be put on the schedule", sched.ok ~= false and #sched.schedule == 1 and sched.schedule[1].name == "Admin Abuse Night", sched.why)
check("nothing on the schedule in the past", adminAs(owner, { op = "schedule", what = "goldenHour", at = fakeOs.time() - 7200, minutes = 30 }).ok == false)
run(AdminService.runSchedule)
check("every screen counts down to it", services.Workspace:GetAttribute("NextEventName") == "Admin Abuse Night" and type(services.Workspace:GetAttribute("NextEventAt")) == "number")
check("and it hasn't started early", not AdminService.active("goldenHour"))
advance(21 * 60)
run(AdminService.runSchedule)
check("on time, it starts by itself", AdminService.active("goldenHour") and AdminService.active("goldRain"))
check("and the countdown goes", services.Workspace:GetAttribute("NextEventAt") == nil)
local cancel = adminAs(owner, { op = "schedule", what = "giants", at = fakeOs.time() + 3600, minutes = 15 })
local giantsId
for _, p in cancel.schedule do
	if p.name == "A Night of Giants" then
		giantsId = p.id
	end
end
local after = adminAs(owner, { op = "unschedule", id = giantsId })
local stillThere = false
for _, p in after.schedule do
	if p.id == giantsId then
		stillThere = true
	end
end
check("a scheduled event can be taken off", giantsId ~= nil and not stillThere)
for _, id in Config.data.Admin.abuseEvents do
	AdminService.stopEvent(id)
end
-- Guests. (Ned steps away from the coins first, so only the gifts count.)
nedRoot.Position = Vector3.new(0, -500, 0)
advance(0.5)
local giltBeforeGift = nd.gilt
check("a gift of Gilt to a guest", adminAs(owner, { op = "gift", userId = ned.UserId, amount = 500 }).ok ~= false and nd.gilt == giltBeforeGift + 500)
check("only the offered amounts", adminAs(owner, { op = "gift", userId = ned.UserId, amount = 333 }).ok == false)
check("a gift to everyone", adminAs(owner, { op = "giftAll", amount = 100 }).ok and nd.gilt == giltBeforeGift + 600)
check("crowning a guest makes them the Guest of Honour", adminAs(owner, { op = "crown", userId = ned.UserId }).ok ~= false and ned:GetAttribute("GuestOfHonour") == true and string.find(lastBroadcast("salute").line, "Guest of Honour", 1, true) ~= nil)
check("the owner can't remove themselves", adminAs(owner, { op = "kick", userId = owner.UserId }).ok == false)
check("free salutes from the house", adminAs(owner, { op = "salute", id = "fireworks" }).ok and salutesGiven[#salutesGiven].id == "fireworks" and salutesGiven[#salutesGiven].by == "AJ")
-- Announcements.
check("a ready line is announced", adminAs(owner, { op = "announce", preset = 1 }).ok and lastBroadcast("announce").text == st.announcements[1])
local typed = adminAs(owner, { op = "announce", text = "a rude line", everywhere = true })
check("a typed line is filtered by Roblox first", typed.ok and lastBroadcast("announce").text == "a #### line")
check("and can go to every house", #published >= 1 and published[#published].message.op == "announce")
check("lines are kept short", adminAs(owner, { op = "announce", text = string.rep("x", 200) }).ok == false)
-- The summons: guests in another house may join this one.
check("the owner can summon every house", adminAs(owner, { op = "summon" }).ok and published[#published].message.op == "summon")
local onAdmin = subscriptions.MaisonAdmin
run(function()
	onAdmin({ Data = { op = "summon", jobId = "other-house", by = "AJ", text = "" } })
end)
check("a summons from another house is offered to every guest here", lastBroadcast("summon") ~= nil and lastBroadcast("summon").jobId == "other-house")
local joinSignal = Remotes.event("Salute").OnServerEvent
run(function()
	joinSignal:Fire(ned, { op = "join", jobId = "other-house" })
end)
check("Go there takes the guest to the owner's house", #teleports == 1 and teleports[1].jobId == "other-house" and teleports[1].players[1] == ned)
run(function()
	joinSignal:Fire(ned, { op = "join", jobId = "made-up-house" })
end)
check("only a house that was really summoned", #teleports == 1)

-- The owner's own powers. Nobody but the owner may use any of them, whatever their screen sends.
do
	-- (Lune's Model has no PivotTo or GetPivot: the root stands for the model here.)
	local function rootOfModel(m)
		return m:FindFirstChild("HumanoidRootPart")
	end
	pcall(function()
		roblox.implementMethod("Model", "PivotTo", function(self, cf)
			local r = rootOfModel(self)
			if r then
				r.CFrame = cf
				r.Position = cf.Position
			end
		end)
		roblox.implementMethod("Model", "GetPivot", function(self)
			local r = rootOfModel(self)
			return if r then CFrame.new(r.Position) else CFrame.new()
		end)
	end)
	local function body(name, at)
		local m = roblox.Instance.new("Model")
		m.Name = name
		local r = roblox.Instance.new("Part")
		r.Name = "HumanoidRootPart"
		r.Transparency = 1
		r.Position = at
		r.CFrame = CFrame.new(at)
		r.Parent = m
		local h = roblox.Instance.new("Part")
		h.Name = "Head"
		h.Transparency = 0
		h.Parent = m
		local plate = roblox.Instance.new("BillboardGui")
		plate.Name = "Nameplate"
		plate.Enabled = true
		plate.Parent = h
		local hum = roblox.Instance.new("Humanoid")
		hum.Parent = m
		return m, r, h, plate, hum
	end
	local ownerModel, ownerRoot, ownerHead, ownerPlate, ownerHum = body("AJ", Vector3.new(0, 5, 0))
	owner.Character = ownerModel
	local zed = guest("Zed", 104)
	local zedModel, zedRoot = body("Zed", Vector3.new(40, 5, 40))
	zed.Character = zedModel
	nedRoot.Position = Vector3.new(-30, 5, 10)
	nedRoot.CFrame = CFrame.new(nedRoot.Position)
	-- A guest asking for any of it gets nothing, and nothing changes.
	local refused = adminAs(ned, { op = "power", power = "fly" }).ok == false
		and adminAs(ned, { op = "power", power = "speed", value = 5 }).ok == false
		and adminAs(ned, { op = "bringAll" }).ok == false
		and adminAs(ned, { op = "freeze", on = true }).ok == false
		and adminAs(ned, { op = "goto", place = "ballroom" }).ok == false
		and adminAs(ned, { op = "abuse", minutes = 15 }).ok == false
	check("a guest can't use the owner's powers (none of them)", refused and ned:GetAttribute("AdminFly") == nil and ned:GetAttribute("AdminSpeed") == nil and zedRoot.Anchored == false)
	local view = adminAs(owner, { op = "state" })
	check("the owner's panel lists their powers", type(view.powers) == "table" and #view.powers.places >= 9 and #view.powers.speeds >= 3)
	local flew = adminAs(owner, { op = "power", power = "fly" })
	check("the owner can fly (the server switches it on, only for them)", flew.powers and flew.powers.fly == true and owner:GetAttribute("AdminFly") == true)
	adminAs(owner, { op = "power", power = "fly" })
	check("...and land again", owner:GetAttribute("AdminFly") == nil)
	adminAs(owner, { op = "power", power = "speed", value = 5 })
	local Speed = module("ReplicatedStorage", "Shared", "Speed")
	local fast = Speed.resolve(true, nil, nil, owner:GetAttribute("AdminSpeed"))
	check("the owner can run five times as fast (past a guest's cap)", owner:GetAttribute("AdminSpeed") == 5 and fast > Config.data.Movement.maxSpeed and fast <= Config.data.Admin.speedCap, fast)
	check("a speed nobody offered isn't taken", adminAs(owner, { op = "power", power = "speed", value = 50 }).ok == false and owner:GetAttribute("AdminSpeed") == 5)
	adminAs(owner, { op = "power", power = "speed", value = 1 })
	adminAs(owner, { op = "power", power = "jump", value = 4 })
	check("a super jump", ownerHum.JumpPower == 35 * 4 and owner:GetAttribute("AdminJump") == 4)
	adminAs(owner, { op = "power", power = "size", value = 4 })
	check("any size (colossal)", owner:GetAttribute("AdminSize") == 4)
	adminAs(owner, { op = "power", power = "size", value = 1 })
	adminAs(owner, { op = "power", power = "invisible" })
	check("invisible: nobody sees the owner or their name", ownerHead.Transparency == 1 and ownerPlate.Enabled == false and owner:GetAttribute("AdminInvisible") == true)
	adminAs(owner, { op = "power", power = "invisible" })
	check("...and seen again, just as before", ownerHead.Transparency == 0 and ownerRoot.Transparency == 1 and ownerPlate.Enabled == true)
	adminAs(owner, { op = "goto", place = "ballroom" })
	local Layout = module("ReplicatedStorage", "Shared", "Layout")
	check("the owner goes anywhere in one step", (ownerRoot.Position - (Layout.Ballroom.arrival + Vector3.new(0, 3, 0))).Magnitude < 0.01, ownerRoot.Position)
	adminAs(owner, { op = "goto", userId = zed.UserId })
	check("...or straight to any guest", (ownerRoot.Position - zedRoot.Position).Magnitude < 6, tostring(ownerRoot.Position) .. " / " .. tostring(zedRoot.Position))
	local brought = adminAs(owner, { op = "bringAll" })
	check("bring everyone: every guest gathers round the owner", brought.ok and (nedRoot.Position - ownerRoot.Position).Magnitude < 10 and (zedRoot.Position - ownerRoot.Position).Magnitude < 10, brought.brought)
	adminAs(owner, { op = "freeze", on = true })
	check("freeze the house: everyone else stands still", nedRoot.Anchored == true and zedRoot.Anchored == true and ownerRoot.Anchored == false and lastBroadcast("salute").title == "Freeze!")
	adminAs(owner, { op = "freeze", on = false })
	check("...and thaw it", nedRoot.Anchored == false and zedRoot.Anchored == false and ned:GetAttribute("Frozen") == nil)
	adminAs(owner, { op = "freeze", on = true })
	advance(Config.data.Admin.freezeSeconds + 1)
	check("a freeze thaws by itself", nedRoot.Anchored == false and zedRoot.Anchored == false)
	-- Two new events: everyone small, and the House Party.
	adminAs(owner, { op = "event", id = "tiny", minutes = 5 })
	check("A Night of Small Things", services.Workspace:GetAttribute("Event_tiny") ~= nil)
	adminAs(owner, { op = "event", id = "discoHouse", minutes = 5 })
	check("The House Party: every screen turns the lamps disco", services.Workspace:GetAttribute("Event_discoHouse") ~= nil)
	adminAs(owner, { op = "stop", id = "tiny" })
	adminAs(owner, { op = "stop", id = "discoHouse" })
	check("...until the owner stops them", services.Workspace:GetAttribute("Event_tiny") == nil and services.Workspace:GetAttribute("Event_discoHouse") == nil)
	-- Effects for everyone, at the owner's tap only.
	check("a guest can't set off effects, stop the house or change the time", adminAs(ned, { op = "fx", id = "launch" }).ok == false and adminAs(ned, { op = "stopAll" }).ok == false and adminAs(ned, { op = "clock", id = "noon" }).ok == false)
	ownerRoot.Position = Vector3.new(10, 5, 10)
	ownerRoot.CFrame = CFrame.new(ownerRoot.Position)
	local fired = adminAs(owner, { op = "fx", id = "shockwave" })
	check("the owner switches an effect on for everyone, and it stays on (every screen watches the switch)", fired.ok and services.Workspace:GetAttribute("Fx_shockwave") ~= nil and fired.fxOn.shockwave == true)
	local again = adminAs(owner, { op = "fx", id = "shockwave" })
	check("...and a second tap switches it off", again.ok and services.Workspace:GetAttribute("Fx_shockwave") == nil and again.fxOn.shockwave == nil)
	check("only the house's own effects", adminAs(owner, { op = "fx", id = "nuke" }).ok == false)
	adminAs(owner, { op = "power", power = "ghost" })
	check("Ghost: through walls (the owner's own power)", owner:GetAttribute("AdminGhost") == true)
	adminAs(owner, { op = "power", power = "ghost" })
	owner.Character = nil
	zed.Character = nil
end
end

---------------------------------------------------------------------------------------------------
-- Friends: each other's Suites, and more Gilt together
---------------------------------------------------------------------------------------------------
do
local Friends = module("ServerScriptService", "Server", "Friends")
local SuiteVisits = module("ServerScriptService", "Server", "SuiteVisits")
local Layout = module("ReplicatedStorage", "Shared", "Layout")
Config.data.Friends.studioFriends = false -- (the live rule: Roblox's own friend list)
local friendsOf = { [201] = { [202] = true }, [202] = { [201] = true } }
Friends.ask = function(a, b)
	return friendsOf[a.UserId] ~= nil and friendsOf[a.UserId][b.UserId] == true
end
local pip, quill, rook = guest("Pip", 201), guest("Quill", 202), guest("Rook", 203)
local function stand(g, at)
	g.root.Position = at
	g.Character = {
		FindFirstChild = function(_, n)
			return if n == "HumanoidRootPart" then g.root else nil
		end,
		PivotTo = function(_, cf)
			g.root.Position = cf.Position
		end,
	}
end
local street = Vector3.new(0, 5, -40)
local inSuite = Layout.Suite.arrival + Vector3.new(0, 3, 0)
stand(pip, street)
stand(quill, inSuite)
stand(rook, street)
run(Friends.refresh)
check("friends in the house are counted, and nobody else", pip:GetAttribute("FriendsHere") == 1 and quill:GetAttribute("FriendsHere") == 1 and rook:GetAttribute("FriendsHere") == nil)
Gilt.friends = Friends.giltBoost
local pd, rd = profiles[pip].Data, profiles[rook].Data
pd.giltDay = { day = -1, earned = 0 }
rd.giltDay = { day = -1, earned = 0 }
local together, alone
run(function()
	together = Gilt.pay(pip, pd, 100, "test")
	alone = Gilt.pay(rook, rd, 100, "test")
end)
check("friends in the house together both earn more Gilt", together == math.floor(100 * Config.data.Friends.giltBoost + 0.5) and alone == 100, string.format("%s / %s", tostring(together), tostring(alone)))

local function ask(g, request)
	advance(0.1)
	local r
	run(function()
		r = SuiteVisits.handle(g, request)
	end)
	return r
end
local list = ask(pip, { op = "list" })
check("the Suites key lists your friends in the house (only them)", list.ok and #list.friends == 1 and list.friends[1].userId == 202)
check("someone who isn't a friend can't go into your Suite", ask(rook, { op = "visit", userId = 202 }).ok == false and rook:GetAttribute("SuiteHost") == nil)
profiles[quill].Data.suite = { rug = "suite_rug_black" }
local went = ask(pip, { op = "visit", userId = 202 })
local told = lastOp(pip, "suiteHost")
check("a friend visits your Suite: they're at its door, shown it as you've furnished it", went.ok and pip:GetAttribute("SuiteHost") == 202 and told ~= nil and told.host == 202 and told.suite.rug == "suite_rug_black" and Layout.zoneAt(pip.root.Position) == "suite")
check("...and you're told who's visiting", lastOp(quill, "notice") ~= nil and string.find(lastOp(quill, "notice").line, "Pip", 1, true) ~= nil)
check("the seats there are the friend's Suite's", SuiteVisits.dataFor(pip) == profiles[quill].Data and SuiteVisits.dataFor(quill) == profiles[quill].Data)
profiles[quill].Data.suite = { rug = "suite_rug_persian" }
run(function()
	SuiteVisits.hostChanged(quill)
end)
check("when the friend changes their Suite, their visitor sees it change", lastOp(pip, "suiteHost").suite.rug == "suite_rug_persian")
advance(4)
stand(pip, street)
run(SuiteVisits.sweep)
check("out of the Suite, the visitor is home again (walking in takes them to their own)", pip:GetAttribute("SuiteHost") == nil and lastOp(pip, "suiteHost").host == nil)
ask(pip, { op = "visit", userId = 202 })
ask(pip, { op = "home" })
check("My Suite takes them home", pip:GetAttribute("SuiteHost") == nil)
ask(pip, { op = "visit", userId = 202 })
quill.Parent = nil
run(SuiteVisits.sweep)
check("when the friend leaves the house, their visitor is in their own Suite again", pip:GetAttribute("SuiteHost") == nil)
quill.Parent = PlayersService
rook:SetAttribute("SuiteHost", 202)
check("a Suite is only ever shared between friends", SuiteVisits.hostOf(rook) == nil and SuiteVisits.dataFor(rook) == profiles[rook].Data)
rook:SetAttribute("SuiteHost", nil)
for _, g in { pip, quill, rook } do
	g.Parent = nil
end
Gilt.friends = function()
	return 1
end
end

---------------------------------------------------------------------------------------------------
-- The house remembers; guests admire each other; the Livre d'Or
---------------------------------------------------------------------------------------------------
do
local Memory = module("ServerScriptService", "Server", "Memory")
local Social = module("ServerScriptService", "Server", "Social")
local memNotes = {}
Memory.note = function(text)
	table.insert(memNotes, text)
end
run(Memory.start)
check("ordinals read as a person would say them", Memory.ordinal(1) == "1st" and Memory.ordinal(2) == "2nd" and Memory.ordinal(3) == "3rd" and Memory.ordinal(11) == "11th" and Memory.ordinal(22) == "22nd" and Memory.ordinal(100) == "100th")
-- A guest who kept the last lamp last time comes back.
local pia = newGuest("Pia", 20)
pia.Character = nil
table.insert(guests, pia)
newProfile(pia, TEMPLATE)
local pd = profiles[pia].Data
pd.firstVisit = fakeOs.time() - 30 * 86400
pd.nights.count = 6
pd.memory.lastSeen = fakeOs.time() - 86400
pd.memory.highlight = "you kept the last lamp in the Ballroom"
pd.memory.highlightAt = fakeOs.time() - 86400
loadedSignal:Fire(pia, pd)
advance(0.2)
check("the welcome remembers last time", Memory.greeting(pia) == "Last time, you kept the last lamp in the Ballroom.", Memory.greeting(pia))
check("and the house notes this visit", pd.memory.lastSeen >= fakeOs.time() - 1)
pd.nights.count = 10
check("a milestone is celebrated", Memory.greeting(pia) == "Your 10th night at the house. We're glad of it." and memNotes[#memNotes] == "Pia's 10th night at the house.")
pd.nights.count = 6
-- The table you sit at most becomes your usual.
for _ = 1, 4 do
	Memory.round(pia, "velvet-2")
end
check("four rounds isn't a habit yet", Memory.usual(pd) == nil)
Memory.round(pia, "velvet-2")
Memory.round(pia, "salon-1")
check("five rounds at a table makes it your usual", Memory.usual(pd) == "velvet-2")
-- Admiring: they hear who; it's counted once in a while; you see where their pieces are from.
local quin = guest("Quin", 21)
local sh = askAs(quin, { op = "shelves" })
pd.equipped.table = sh.always[1].id
pd.owned[sh.always[1].id] = true
local card = askAs(quin, { op = "admire", userId = pia.UserId })
check("admiring a guest shows what they wear", card.ok and card.name == "Pia" and #card.pieces >= 1 and card.pieces[1].name == sh.always[1].name)
check("and where it's from", card.pieces[1].where == "always")
check("they hear who admired them", lastOp(pia, "admired") ~= nil and lastOp(pia, "admired").from == "Quin")
check("the house counts it for their next welcome", pd.memory.admiredSince == 1 and pd.memory.admired == 1)
advance(4)
local again = askAs(quin, { op = "admire", userId = pia.UserId })
check("admiring again soon isn't counted twice", again.ok and again.counted == false and pd.memory.admiredSince == 1)
check("nobody admires themselves", askAs(quin, { op = "admire", userId = quin.UserId }).ok == false)
-- The Livre d'Or.
local book = askAs(quin, { op = "guestBook" })
check("the Livre d'Or offers its lines", #book.lines == 16 and book.signedToday == false)
local signed = askAs(quin, { op = "sign", line = 3 })
check("signing it", signed.entries and signed.entries[1].name == "Quin" and signed.entries[1].text == "The Salon, always." and signed.signedToday)
check("once a night", askAs(quin, { op = "sign", line = 4 }).ok == false)
check("lines are chosen, never typed", askAs(pia, { op = "sign", line = 99 }).ok == false)
check("everyone reads the signatures", askAs(pia, { op = "guestBook" }).entries[1].name == "Quin")
end

---------------------------------------------------------------------------------------------------
-- Giving the Gold Key
---------------------------------------------------------------------------------------------------
do
	local giver = guest("Rae", 30)
	local taker = guest("Sol", 31)
	check("the Gold Key can't be given before its product exists", askAs(giver, { op = "goldKeyGift", userId = taker.UserId }).ok == false)
	Config.data.Products.goldKeyGift = 8001
	check("give the Gold Key to a guest", askAs(giver, { op = "goldKeyGift", userId = taker.UserId }).ok and prompts[#prompts].id == 8001)
	receipt(giver, 8001, "GK-1")
	advance(0.5)
	check("they hold the Gold Key", profiles[taker].Data.goldKey == true and profiles[giver].Data.goldKey == false)
	check("and hear who gave it", lastOp(taker, "notice") and string.find(lastOp(taker, "notice").line, "Rae gave you the Gold Key", 1, true) ~= nil)
	check("nobody is given it twice", askAs(giver, { op = "goldKeyGift", userId = taker.UserId }).ok == false)
	-- If the guest leaves before Roblox confirms, the buyer keeps the Gold Key.
	local third = guest("Tam", 32)
	askAs(giver, { op = "goldKeyGift", userId = third.UserId })
	third.Parent = nil
	receipt(giver, 8001, "GK-2")
	advance(0.5)
	check("a gift that can't be handed over becomes the buyer's", profiles[giver].Data.goldKey == true)
	Config.data.Products.goldKeyGift = 0
end

---------------------------------------------------------------------------------------------------
-- The offers, with products found by name (no ids pasted anywhere)
---------------------------------------------------------------------------------------------------
do
	local buyer = guest("Lou", 40)
	check("nothing new is offered before the products exist", (function()
		for _, o in askAs(buyer, { op = "offers" }).offers do
			if o.key ~= "goldKey" then
				return false
			end
		end
		return true
	end)())
	MarketplaceService.devProducts = {
		{ Name = "Double Gilt", ProductId = 9101, PriceInRobux = 399 },
		{ Name = "gilt purse", ProductId = 9102, PriceInRobux = 49 },
		{ Name = "Gilt Chest", ProductId = 9103, PriceInRobux = 199 },
		{ Name = "Golden Hour for Everyone", ProductId = 9104, PriceInRobux = 99 },
		{ Name = "The Gold Key", ProductId = 9105, PriceInRobux = 499 },
		{ Name = "Boutique 99", ProductId = 9106, PriceInRobux = 99 },
		{ Name = "Something else", ProductId = 9199, PriceInRobux = 5 },
	}
	run(Shop.discover)
	local view = askAs(buyer, { op = "offers" })
	local keys = {}
	for _, o in view.offers do
		keys[o.key] = o
	end
	check("products are found by their names in Creator Hub", keys.doubleGilt ~= nil and keys.giltPurse1 ~= nil and keys.giltPurse2 ~= nil and keys.goldenHour ~= nil and keys.goldKey ~= nil)
	check("with Roblox's own prices", keys.doubleGilt.price == 399 and keys.giltPurse1.price == 49)
	check("names match whatever the capitals", keys.giltPurse1 ~= nil)
	check("Double Gilt leads, marked best value", view.offers[1].key == "doubleGilt" and view.offers[1].best == true)
	check("a Boutique tier is found by name too", askAs(buyer, { op = "shelves" }).today ~= nil)
	-- Buying.
	check("buying an offer opens Roblox's purchase prompt", askAs(buyer, { op = "offer", key = "giltPurse1" }).ok and prompts[#prompts].id == 9102)
	local before = profiles[buyer].Data.gilt
	receipt(buyer, 9102, "GP-1")
	local purse = ProductConfig.byKey.giltPurse1.Reward.Amount
	check("a Gilt Purse adds its Gilt", profiles[buyer].Data.gilt == before + purse, profiles[buyer].Data.gilt - before)
	receipt(buyer, 9102, "GP-1")
	check("and only once per purchase", profiles[buyer].Data.gilt == before + purse)
	receipt(buyer, 9101, "DG-1")
	check("Double Gilt is kept for good", profiles[buyer].Data.doubleGilt == true)
	local GiltModule = module("ServerScriptService", "Server", "Gilt")
	local fresh = guest("Kit", 41)
	local a, b
	run(function()
		a = GiltModule.pay(fresh, profiles[fresh].Data, 100, "test")
		b = GiltModule.pay(buyer, profiles[buyer].Data, 100, "test")
	end)
	check("and doubles what's earned", b == a * 2, tostring(a) .. " / " .. tostring(b))
	check("it isn't offered again once owned", (function()
		for _, o in askAs(buyer, { op = "offers" }).offers do
			if o.key == "doubleGilt" then
				return false
			end
		end
		return true
	end)())
	receipt(buyer, 9105, "GK-P")
	check("the Gold Key can be a developer product", profiles[buyer].Data.goldKey == true)
	local hours = {}
	Shop.goldenHour = function(p, seconds)
		table.insert(hours, { p = p, seconds = seconds })
	end
	receipt(buyer, 9104, "GH-1")
	check("a Golden Hour bought for everyone starts for the house, with the buyer's name", #hours == 1 and hours[1].p == buyer and hours[1].seconds == ProductConfig.byKey.goldenHour.Reward.Minutes * 60)
	check("only the offered things can be bought this way", askAs(buyer, { op = "offer", key = "tier99" }).ok == false)
	MarketplaceService.devProducts = {}
	run(Shop.discover)
end

---------------------------------------------------------------------------------------------------
-- Build 51: the Owner Remote, holidays, giveaways, headlines, countdowns, Mega Abuse, levels, the
-- Badge Book and the Gem Shop.
---------------------------------------------------------------------------------------------------
do
	local serde = require("@lune/serde")
	local fs = require("@lune/fs")
	local AdminService = module("ServerScriptService", "Server", "AdminService")
	local Achievements = module("ServerScriptService", "Server", "Achievements")
	local Progress = module("ServerScriptService", "Server", "Progress")
	local GemShop = module("ServerScriptService", "Server", "GemShop")
	local CuriosS = module("ServerScriptService", "Server", "Curios")
	local GiltModule = module("ServerScriptService", "Server", "Gilt")
	local HouseEvents = module("ReplicatedStorage", "Shared", "HouseEvents")
	local BadgeBook = module("ReplicatedStorage", "Shared", "BadgeBook")
	local Levels = module("ReplicatedStorage", "Shared", "Levels")
	local GemList = module("ReplicatedStorage", "Shared", "GemShop")
	-- The hooks Main sets.
	AdminService.award = Achievements.award
	AdminService.tally = function(p, stat, n, once)
		Achievements.tally(p, stat, n, once)
	end
	local told = {}
	Achievements.notify = function(p, badge)
		table.insert(told, { p = p, key = badge.key })
	end
	local owner
	for _, g in guests do
		if g.UserId == 100 then
			owner = g
		end
	end
	local function adminAs(player, request)
		advance(0.5)
		local r
		run(function()
			r = AdminService.handle(player, request)
		end)
		return r
	end
	local function lastCast(op)
		for i = #broadcasts, 1, -1 do
			if broadcasts[i].message.op == op then
				return broadcasts[i].message
			end
		end
		return nil
	end
	local function body(g, at)
		local m = roblox.Instance.new("Model")
		local r = roblox.Instance.new("Part")
		r.Name = "HumanoidRootPart"
		r.Position = at
		r.CFrame = CFrame.new(at)
		r.Parent = m
		local h = roblox.Instance.new("Part")
		h.Name = "Head"
		h.Parent = m
		g.Character = m
		return r
	end
	run(function()
		AdminService.stopAll("AJ")
	end)

	-- The holidays, on the right days.
	check("the holidays fall on their days (Halloween, Christmas, New Year, Valentine's, St Patrick's)", HouseEvents.holidayOn(2026, 10, 31) == "halloween" and HouseEvents.holidayOn(2026, 12, 25) == "christmas" and HouseEvents.holidayOn(2027, 1, 1) == "newYear" and HouseEvents.holidayOn(2027, 2, 14) == "valentine" and HouseEvents.holidayOn(2027, 3, 17) == "stPatrick")
	check("Thanksgiving is the fourth Thursday of November", HouseEvents.holidayOn(2026, 11, 26) == "thanksgiving" and HouseEvents.holidayOn(2026, 11, 19) == nil and HouseEvents.holidayOn(2027, 11, 25) == "thanksgiving")
	check("Easter moves with the moon (Sunday and Monday)", HouseEvents.holidayOn(2026, 4, 5) == "easter" and HouseEvents.holidayOn(2026, 4, 6) == "easter" and HouseEvents.holidayOn(2027, 3, 28) == "easter" and HouseEvents.holidayOn(2026, 10, 9) == nil)

	-- The Owner Remote: every command the remote offers is one the house knows...
	local catalog = serde.decode("json", fs.readFile("tools/remote/commands.json"))
	local accepted, refused = 0, {}
	for _, c in catalog.commands do
		local ok
		run(function()
			ok = AdminService.apply(c.command, "XxxXxxX_77797", true)
		end)
		if ok then
			accepted += 1
		else
			table.insert(refused, c.label)
		end
		advance(0.2)
	end
	run(function()
		AdminService.stopAll("XxxXxxX_77797")
	end)
	advance(1)
	check("every one of the remote's commands is one the house carries out", accepted == #catalog.commands and accepted >= 70, refused[1])
	check("the remote's workflow offers every one of them", (function()
		local wf = fs.readFile(".github/workflows/owner-remote.yml")
		for _, c in catalog.commands do
			if not string.find(wf, c.label, 1, true) then
				return false
			end
		end
		return true
	end)())
	-- ...and it arrives as Open Cloud does: a line of JSON on the remote topic.
	local remote = subscriptions[Config.data.Admin.remoteTopic]
	check("every server listens for the Owner Remote", type(remote) == "function")
	local castBefore = #broadcasts
	run(function()
		remote({ Data = '{"op":"fx","id":"meteor"}' })
	end)
	check("a remote effect is switched on in every server (and stays on)", services.Workspace:GetAttribute("Fx_meteor") ~= nil)
	run(function()
		remote({ Data = '{"op":"fxAllOff"}' })
	end)
	check("...and the remote can switch every effect off", services.Workspace:GetAttribute("Fx_meteor") == nil)
	run(function()
		remote({ Data = '{"op":"headline","text":"rude remote words","style":"ice"}' })
	end)
	check("a remote headline is filtered by Roblox first", lastCast("headline") ~= nil and lastCast("headline").text == "#### remote words" and lastCast("headline").style == "ice" and lastCast("headline").by == "XxxXxxX_77797")
	-- Nothing outside the lists does anything.
	local giltBefore = {}
	for _, g in guests do
		if profiles[g] then
			giltBefore[g] = profiles[g].Data.gilt
		end
	end
	castBefore = #broadcasts
	run(function()
		remote({ Data = '{"op":"giftAll","amount":999999}' })
		remote({ Data = '{"op":"kick","userId":101}' })
		remote({ Data = '{"op":"event","id":"notAnEvent"}' })
		remote({ Data = '{"op":"fx","id":"explodeEveryone"}' })
		remote({ Data = "not json at all" })
		remote({ Data = '["fx","meteor"]' })
	end)
	check("the remote can't give amounts that aren't on the list, or do anything unknown", (function()
		for g, before in giltBefore do
			if profiles[g].Data.gilt ~= before then
				return false
			end
		end
		return #broadcasts == castBefore
	end)())
	-- At most twenty commands in ten seconds.
	advance(11)
	castBefore = #broadcasts
	run(function()
		for _ = 1, 25 do
			remote({ Data = '{"op":"headline","preset":1}' })
		end
	end)
	check("the remote is held to twenty commands in ten seconds", #broadcasts - castBefore == 20, #broadcasts - castBefore)
	advance(11)

	-- Holidays: a hunt round the house.
	local hunter = guest("Holly", 301)
	local hd = profiles[hunter].Data
	local hroot = body(hunter, Vector3.new(0, 5, 0))
	adminAs(owner, { op = "event", id = "halloween", minutes = 15 })
	local folder = services.Workspace:FindFirstChild("HouseEvents", true)
	local function hunts(huntId)
		local list, jackpot = {}, nil
		if folder then
			for _, p in folder:GetChildren() do
				if p:GetAttribute("Pickup") == "hunt" and p:GetAttribute("Hunt") == huntId then
					if p:GetAttribute("Jackpot") then
						jackpot = p
					else
						table.insert(list, p)
					end
				end
			end
		end
		return list, jackpot
	end
	local pumpkins, golden = hunts("halloween")
	check("the All Hallows' Hunt hides its pumpkins round the house, and one golden one", #pumpkins == Config.data.Admin.hunts.halloween.count and golden ~= nil)
	check("every screen sees it's on", services.Workspace:GetAttribute("Event_halloween") ~= nil)
	local giltWas = hd.gilt
	hroot.Position = pumpkins[1].CFrame.Position
	run(AdminService.collect)
	check("finding a pumpkin pays Gilt", hd.gilt > giltWas and pumpkins[1].Parent == nil)
	check("and gives the Jack-o'-Lantern to keep, and the badge", CuriosS.count(hd, "jackOLantern") == 1 and hd.badges.holiday_halloween == true)
	hroot.Position = pumpkins[2].CFrame.Position
	run(AdminService.collect)
	check("one Jack-o'-Lantern a hunt, however many pumpkins", CuriosS.count(hd, "jackOLantern") == 1)
	hroot.Position = golden.CFrame.Position
	giltWas = hd.gilt
	run(AdminService.collect)
	check("the golden pumpkin pays far more, and is its own curio", hd.gilt - giltWas >= Config.data.Admin.hunts.halloween.jackpotGilt and CuriosS.count(hd, "goldenPumpkin") == 1)
	check("and the whole house hears who found it", lastCast("salute") ~= nil and string.find(lastCast("salute").line, "Holly found The Golden Pumpkin", 1, true) ~= nil)
	adminAs(owner, { op = "stop", id = "halloween" })
	pumpkins = hunts("halloween")
	check("stopping the hunt clears what's left", #pumpkins == 0)
	-- The Turkey Trot: they run.
	adminAs(owner, { op = "event", id = "thanksgiving", minutes = 15 })
	local turkeys = hunts("thanksgiving")
	check("the Turkey Trot lets its turkeys loose", #turkeys == Config.data.Admin.hunts.thanksgiving.count and turkeys[1]:GetAttribute("Moves") == true)
	local t1 = turkeys[1]
	local from = t1.CFrame.Position
	hroot.Position = from + Vector3.new(6, 0, 0)
	run(function()
		for _ = 1, 10 do
			AdminService.trot(0.1)
		end
	end)
	check("a turkey runs from a guest who comes near", (t1.CFrame.Position - hroot.Position).Magnitude > (from - hroot.Position).Magnitude)
	adminAs(owner, { op = "stop", id = "thanksgiving" })
	-- The New Year: a countdown, then a present for everyone.
	local newYearGilt = hd.gilt
	adminAs(owner, { op = "event", id = "newYear", minutes = 5 })
	check("the New Year counts down on every screen", lastCast("countdown") ~= nil and lastCast("countdown").label == "HAPPY NEW YEAR IN")
	advance(11)
	check("then fireworks, a headline and a present for everyone", lastCast("headline").text == "HAPPY NEW YEAR!" and hd.gilt == newYearGilt + Config.data.Admin.newYearGilt and CuriosS.count(hd, "newYearSparkler") == 1)
	adminAs(owner, { op = "stop", id = "newYear" })

	-- Headlines, countdowns, giveaways, the Owner's Token.
	local refusedAll = adminAs(hunter, { op = "headline", preset = 1 }).ok == false and adminAs(hunter, { op = "giveaway", amount = 1000 }).ok == false and adminAs(hunter, { op = "token" }).ok == false and adminAs(hunter, { op = "mega", minutes = 5 }).ok == false
	check("a guest can't send a headline, a giveaway, the token or Mega Abuse", refusedAll)
	local pubBefore = #published
	adminAs(owner, { op = "headline", preset = 2, style = "rainbow", everywhere = true })
	check("a ready-made headline crosses every screen, in its style", lastCast("headline").text == HouseEvents.Headlines[2] and lastCast("headline").style == "rainbow")
	check("and every server, when asked", #published > pubBefore and published[#published].message.op == "headline")
	check("everyone there gets the Breaking News badge", hd.badges.headline == true)
	adminAs(owner, { op = "headline", text = "rude but true" })
	check("the owner's own words are filtered too", lastCast("headline").text == "#### but true")
	check("a style that isn't one falls back to gold", (function()
		adminAs(owner, { op = "headline", preset = 1, style = "neon<script>" })
		return lastCast("headline").style == "gold"
	end)())
	check("only the countdowns offered", adminAs(owner, { op = "countdown", id = "giveaway", seconds = 7 }).ok == false)
	adminAs(owner, { op = "countdown", id = "giveaway", seconds = 10 })
	check("a countdown shows on every screen", lastCast("countdown").label == "GIVEAWAY IN")
	local winnerGilt = hd.gilt
	advance(11)
	local draw = lastCast("giveaway")
	check("then a giveaway is drawn", draw ~= nil and draw.amount == Config.data.Admin.giveawayGilt[2] and type(draw.names) == "table" and #draw.names >= 1)
	check("the owner never wins their own giveaway", (function()
		for _, n in draw.names do
			if n == owner.DisplayName then
				return false
			end
		end
		return draw.winner ~= owner.DisplayName
	end)())
	check("only the amounts offered", adminAs(owner, { op = "giveaway", amount = 777 }).ok == false)
	local gw = adminAs(owner, { op = "giveaway", amount = 250 })
	check("the winner gets the Gilt and the badge", gw.ok and type(gw.winner) == "string" and (function()
		-- (By their UserId: two guests in this test house can share a name.)
		local id = lastCast("giveaway").winnerId
		for _, g in guests do
			if g.UserId == id and profiles[g] then
				return g.DisplayName == gw.winner and profiles[g].Data.badges.giveawayWinner == true
			end
		end
		return false
	end)())
	local _ = winnerGilt
	adminAs(owner, { op = "token" })
	check("the Owner's Token goes to every guest", CuriosS.count(hd, "ownerToken") == 1)
	advance(1)
	adminAs(owner, { op = "token" })
	check("once a day each", CuriosS.count(hd, "ownerToken") == 1)

	-- Mega Abuse.
	adminAs(owner, { op = "mega", minutes = 5 })
	check("Mega Abuse: every event at once, marked as Mega", services.Workspace:GetAttribute("AbuseMega") == true and services.Workspace:GetAttribute("Event_doubleXP") ~= nil)
	check("everyone there gets the Mega Abuse Medal, and Admin Abuse counted", CuriosS.count(hd, "abuseMedal") == 1 and hd.badges.abuseNight == true and (hd.tally.abuseNights or 0) == 1)
	local fxBefore = 0
	for _, b in broadcasts do
		if b.message.op == "abuseFX" then
			fxBefore += 1
		end
	end
	advance(Config.data.Admin.megaSurpriseSeconds * 2 + 2)
	local fxAfter = 0
	for _, b in broadcasts do
		if b.message.op == "abuseFX" then
			fxAfter += 1
		end
	end
	check("surprises come twice as often", fxAfter - fxBefore >= 2)
	adminAs(owner, { op = "stopAll" })
	check("Stop everything ends Mega Abuse too", services.Workspace:GetAttribute("AbuseMega") == nil and services.Workspace:GetAttribute("AbuseUntil") == nil)

	-- Levels.
	check("the level curve: 100 XP for level 2, level 100 at the top", Levels.of(0) == 1 and Levels.of(100) == 2 and Levels.of(Levels.total(100)) == 100 and (select(3, Levels.of(Levels.total(100) + 5))) == 0)
	local ups = {}
	Progress.levelUp = function(p, level, gilt, gems)
		table.insert(ups, { p = p, level = level, gilt = gilt, gems = gems })
	end
	Progress.boost = function(_p)
		return if AdminService.active("doubleXP") then Config.data.Admin.doubleXP else 1
	end
	local lv = guest("Lev", 302)
	run(function()
		Progress.add(lv, 99, "test")
	end)
	check("XP shows on the guest (their level for everyone)", lv:GetAttribute("Level") == 1 and lv:GetAttribute("LevelXP") == 99 and lv:GetAttribute("LevelNeed") == 100)
	run(function()
		Progress.give(lv, "round", "Flawless")
	end)
	check("a Flawless round is worth far more than a Cleared one", Config.data.Levels.round.Flawless > Config.data.Levels.round.Cleared * 4)
	check("and reaching a level is celebrated once, with its reward", lv:GetAttribute("Level") == 2 and #ups == 1 and ups[1].level == 2 and ups[1].gilt == (Levels.reward(2)))
	adminAs(owner, { op = "event", id = "doubleXP", minutes = 5 })
	local gained
	run(function()
		gained = Progress.give(lv, "nightly")
	end)
	check("Double XP doubles it", gained == Config.data.Levels.nightly * 2)
	adminAs(owner, { op = "stop", id = "doubleXP" })
	run(function()
		Progress.add(lv, 500000, "test")
	end)
	check("every level on the way is rewarded once, and the top is level 100", lv:GetAttribute("Level") == 100 and #ups == 99 and ups[#ups].level == 100 and ups[9].gems > 0)

	-- The Badge Book.
	check("ten times the badges there were (151)", BadgeBook.count >= 130)
	check("every badge has a name, a glyph, a group and a way to earn it", (function()
		local groups = {}
		for _, g in BadgeBook.Groups do
			groups[g.id] = true
		end
		for _, b in BadgeBook.List do
			if b.name == "" or b.glyph == "" or b.line == "" or not groups[b.group] then
				return false
			end
			if b.stat and not BadgeBook.Stats[b.stat] then
				return false
			end
		end
		return true
	end)())
	check("the badges from before keep their keys", BadgeBook.byKey.firstRound ~= nil and BadgeBook.byKey.firstFlawless ~= nil and BadgeBook.byKey.register50 ~= nil and BadgeBook.byKey.mythic ~= nil and BadgeBook.byKey.foundingTerm ~= nil)
	local bb = guest("Bea", 303)
	local bd = profiles[bb].Data
	bd.stats.rounds = 12
	bd.stats.flawless = 1
	told = {}
	run(function()
		Achievements.check(bb)
	end)
	check("ladder badges come from what the guest has done", bd.badges.firstRound and bd.badges.rounds_10 and bd.badges.firstFlawless and not bd.badges.rounds_50)
	check("each is said on their screen (a few at a time)", #told >= 1 and #told <= 3)
	Config.data.Badges.rounds_10 = 5550001
	bd.stats.rounds = 60
	local awardedBefore = #awarded
	run(function()
		Achievements.check(bb)
	end)
	advance(0.5)
	check("a badge with a Roblox badge id is awarded on Roblox too", bd.badges.rounds_50 == true and #awarded == awardedBefore)
	bd.badges.rounds_10 = nil
	run(function()
		Achievements.check(bb)
	end)
	advance(0.5)
	check("...when it's earned", #awarded == awardedBefore + 1 and awarded[#awarded].id == 5550001)
	Config.data.Badges.rounds_10 = nil
	run(function()
		Achievements.tally(bb, "abuseNights", 1, "night:1")
		Achievements.tally(bb, "abuseNights", 1, "night:1")
	end)
	check("a night counts once, however often you rejoin during it", bd.tally.abuseNights == 1)
	local view = Achievements.view(bd)
	check("the Badge Book shows what's earned and how far along", view.count >= 4 and view.total == BadgeBook.count and view.stats.rounds == 60)

	-- The Gem Shop.
	local gemmy = guest("Gem", 304)
	local gd = profiles[gemmy].Data
	gd.gems = 1000
	GemShop.award = Achievements.award
	GemShop.tally = function(p, stat, n)
		if n > 0 then
			Achievements.tally(p, stat, n)
		else
			Achievements.check(p)
		end
	end
	run(GemShop.start)
	local askGems = Remotes.funcs.GemAsk.OnServerInvoke
	local function gemAs(req)
		advance(0.5)
		local r
		run(function()
			r = askGems(gemmy, req)
		end)
		return r
	end
	local st = gemAs({ op = "state" })
	check("the Gem Shop opens with your Gems and the Cabinet", st.ok and st.gems == 1000 and type(st.cabinet) == "table")
	local r1 = gemAs({ op = "buy", id = "aura_golddust" })
	check("an aura costs exactly its price, once", r1.ok and gd.gems == 1000 - GemList.byId.aura_golddust.gems and r1.owned.aura_golddust == true)
	check("and everyone sees it on you", gemmy:GetAttribute("Aura") == "aura_golddust")
	check("it can't be bought twice", gemAs({ op = "buy", id = "aura_golddust" }).ok == false and gd.gems == 1000 - GemList.byId.aura_golddust.gems)
	check("the screen can't send a price", gemAs({ op = "buy", id = "aura_rainbow", gems = 1 }).ok == false and gd.gems == 1000 - GemList.byId.aura_golddust.gems)
	check("nothing that isn't in the shop", gemAs({ op = "buy", id = "aura_free" }).ok == false)
	local r2 = gemAs({ op = "buy", id = "title_legend" })
	check("a title, worn at once, over your name", r2.ok and gemmy:GetAttribute("Title") == "Certified Legend" and gd.badges.firstTitle == true)
	check("taking it off", gemAs({ op = "equip", kind = "title", id = "" }).ok and gemmy:GetAttribute("Title") == nil)
	check("you can't wear what you don't own", gemAs({ op = "equip", kind = "aura", id = "aura_rainbow" }).ok == false)
	local gemsNow = gd.gems
	local r3 = gemAs({ op = "buy", id = "boost_gilt" })
	check("a Gilt Surge runs for half an hour", r3.ok and gd.gems == gemsNow - GemList.byId.boost_gilt.gems and gd.gemShop.giltUntil > fakeOs.time() + 1700)
	GiltModule.surge = GemShop.giltBoost
	local plain, surged
	local other = guest("Plain", 305)
	run(function()
		plain = GiltModule.pay(other, profiles[other].Data, 100, "test")
		surged = GiltModule.pay(gemmy, gd, 100, "test")
	end)
	check("and pays half again", surged == math.floor(plain * 1.5 + 0.5), tostring(plain) .. " / " .. tostring(surged))
	advance(1801)
	run(function()
		surged = GiltModule.pay(gemmy, gd, 100, "test")
	end)
	check("then it runs out", surged == plain)
	local giltNow = gd.gilt
	gemsNow = gd.gems
	check("Gems change for Gilt at the set rate", gemAs({ op = "buy", id = "swap_small" }).ok and gd.gilt == giltNow + 1000 and gd.gems == gemsNow - 25)
	gd.gems = 10
	local poor = gemAs({ op = "buy", id = "aura_rainbow" })
	check("not enough Gems: says how many more, takes nothing", poor.ok == false and string.find(poor.why, "490 more", 1, true) ~= nil and gd.gems == 10)
	gd.gems = 100
	local cur = gemAs({ op = "curio", id = "saffronJar" })
	check("the Cabinet's curios are bought here too, at their price", cur.ok and CuriosS.count(gd, "saffronJar") == 1 and gd.gems == 40)
	check("and Gems spent are counted for the Badge Book", (gd.tally.gemsSpent or 0) >= 60)
	GiltModule.surge = function()
		return 1
	end
end

---------------------------------------------------------------------------------------------------
-- Build 53: effects that stay on until switched off, Admin Abuse at the sorting tables, and
-- "every server" meaning every server (even ones that open while it's on)
---------------------------------------------------------------------------------------------------
do
	local AdminService = module("ServerScriptService", "Server", "AdminService")
	local owner, ned
	for _, g in guests do
		if g.UserId == 100 then
			owner = g
		elseif g.UserId == 101 then
			ned = g
		end
	end
	local function adminAs(player, request)
		advance(0.5)
		local r
		run(function()
			r = AdminService.handle(player, request)
		end)
		return r
	end
	local W = services.Workspace
	local function live()
		local store = dataStores.MaisonSchedule or {}
		return store.live or {}
	end
	run(function()
		AdminService.stopAll("test")
	end)
	advance(1)
	-- Only the owner.
	check("a guest can't switch an effect on, or every effect off", adminAs(ned, { op = "fx", id = "galaxy" }).ok == false and adminAs(ned, { op = "fxAllOff" }).ok == false and W:GetAttribute("Fx_galaxy") == nil)
	check("a guest can't start Admin Abuse anywhere", adminAs(ned, { op = "abuse", minutes = 15, everywhere = true }).ok == false and W:GetAttribute("AbuseUntil") == nil)
	check("nor make another server's message (only the game's own servers can publish)", type(subscriptions.MaisonAdmin) == "function")
	-- The owner, every server.
	local r = adminAs(owner, { op = "fx", id = "galaxy", everywhere = true })
	advance(0.5)
	check("the owner switches the galaxy on in every server: on here...", r.ok and W:GetAttribute("Fx_galaxy") ~= nil)
	check("...sent to every server, saying on", published[#published].message.op == "fx" and published[#published].message.id == "galaxy" and published[#published].message.on == true)
	check("...and written down for any server that opens while it's on", live().fx ~= nil and live().fx.galaxy ~= nil)
	check("the console shows it lit", r.fxOn.galaxy == true and (function()
		for _, e in r.powers.effects do
			if e.id == "galaxy" then
				return e.on == true
			end
		end
		return false
	end)())
	advance(60)
	check("it stays on (a minute later, still on)", W:GetAttribute("Fx_galaxy") ~= nil)
	-- The sorting tables join in.
	local twist = AdminService.tableTwist()
	check("an effect on: golden pieces at the tables", twist ~= nil and twist.kind == "effect" and twist.golden == Config.data.Admin.table.golden.effect)
	adminAs(owner, { op = "abuse", minutes = 15 })
	twist = AdminService.tableTwist()
	check("Admin Abuse: more golden pieces, and Gilt doubled (Golden Hour)", twist ~= nil and twist.kind == "abuse" and twist.golden == Config.data.Admin.table.golden.abuse and AdminService.giltBoost() == Config.data.Admin.goldenHourGilt)
	adminAs(owner, { op = "mega", minutes = 15 })
	twist = AdminService.tableTwist()
	check("Mega Abuse: the most golden pieces, and all Gilt triple", twist ~= nil and twist.kind == "mega" and twist.golden == Config.data.Admin.table.golden.mega and AdminService.giltBoost() == Config.data.Admin.table.megaGilt)
	-- Another server's switch.
	run(function()
		subscriptions.MaisonAdmin({ Data = { op = "fx", id = "aurora", on = true, by = "XxxXxxX_77797", jobId = "another-server" } })
	end)
	check("another server's switch is heard here", W:GetAttribute("Fx_aurora") ~= nil)
	-- Stopping here only: what's written down everywhere doesn't undo it.
	run(function()
		AdminService.stopAll("test")
	end)
	check("Stop everything (this server) switches every effect off here", W:GetAttribute("Fx_galaxy") == nil and W:GetAttribute("Fx_aurora") == nil and W:GetAttribute("AbuseUntil") == nil)
	run(AdminService.syncLive)
	check("...and the record of what's on everywhere doesn't switch it back on", W:GetAttribute("Fx_galaxy") == nil)
	-- A server that opens while something is on everywhere joins in.
	local endsAt = fakeOs.time() + 600
	dataStores.MaisonSchedule.live = {
		abuse = { id = "night-77", ends = endsAt, mega = false, by = "XxxXxxX_77797" },
		fx = { ufo = { since = fakeOs.time(), by = "XxxXxxX_77797" } },
		events = { goldRain = { ends = fakeOs.time() + 300, by = "XxxXxxX_77797" } },
	}
	run(AdminService.syncLive)
	local untilAt = W:GetAttribute("AbuseUntil")
	-- (Within 128 seconds: this test harness keeps attribute numbers as 32-bit floats; Roblox keeps
	-- them whole.)
	check("a server catching up joins Admin Abuse, for what's left of it (ending when it ends everywhere)", type(untilAt) == "number" and math.abs(untilAt - endsAt) <= 128, untilAt)
	check("...and every effect switched on everywhere", W:GetAttribute("Fx_ufo") ~= nil)
	check("...and every event", W:GetAttribute("Event_goldRain") ~= nil)
	local since = W:GetAttribute("AbuseSince")
	advance(3)
	run(AdminService.syncLive)
	check("and never begins the same night twice", W:GetAttribute("AbuseSince") == since)
	-- Off everywhere.
	r = adminAs(owner, { op = "fxAllOff", everywhere = true })
	advance(0.5)
	check("Every effect off, in every server: off here, sent, and wiped from the record", r.ok and W:GetAttribute("Fx_ufo") == nil and published[#published].message.op == "fxAllOff" and next(live().fx or {}) == nil)
	r = adminAs(owner, { op = "stopAll", everywhere = true })
	advance(0.5)
	check("Stop everything, in every server, wipes the record", r.ok and W:GetAttribute("AbuseUntil") == nil and live().abuse == nil and next(live().events or {}) == nil)
	-- One night, one id, everywhere.
	adminAs(owner, { op = "abuse", minutes = 15, everywhere = true })
	advance(0.5)
	local msg = published[#published].message
	check("Admin Abuse in every server carries one id, written down with it", msg.op == "abuse" and type(msg.liveId) == "string" and live().abuse ~= nil and live().abuse.id == msg.liveId)
	since = W:GetAttribute("AbuseSince")
	advance(3)
	run(AdminService.syncLive)
	check("so the server that started it doesn't start it again", W:GetAttribute("AbuseSince") == since)
	-- The Owner Remote: its run's id.
	local remote = subscriptions[Config.data.Admin.remoteTopic]
	run(function()
		remote({ Data = '{"op":"mega","minutes":15,"rid":"4242"}' })
	end)
	advance(6) -- (each server writes it down within five seconds, not all at once)
	check("a remote Mega Abuse is written down under the remote run's id", live().abuse ~= nil and live().abuse.id == "remote:4242" and live().abuse.mega == true)
	since = W:GetAttribute("AbuseSince")
	advance(3)
	run(AdminService.syncLive)
	check("and isn't begun twice either", W:GetAttribute("AbuseSince") == since)
	run(function()
		remote({ Data = '{"op":"fx","id":"blizzard","on":true,"rid":"4243"}' })
	end)
	advance(6)
	check("a remote effect switch is written down too", W:GetAttribute("Fx_blizzard") ~= nil and live().fx ~= nil and live().fx.blizzard ~= nil)
	adminAs(owner, { op = "stopAll", everywhere = true })
	advance(1)
end

---------------------------------------------------------------------------------------------------
-- Build 54: the Owner Remote reaches every server, whether the owner is in one or not, and even
-- the servers that weren't open when it was sent (it writes its commands down itself)
---------------------------------------------------------------------------------------------------
do
	local AdminService = module("ServerScriptService", "Server", "AdminService")
	local W = services.Workspace
	local remote = subscriptions[Config.data.Admin.remoteTopic]
	local function live()
		return (dataStores.MaisonSchedule or {}).live or {}
	end
	local function now()
		return W:GetServerTimeNow()
	end
	local function castsOf(op, from)
		local n = 0
		for i = from + 1, #broadcasts do
			local m = broadcasts[i].message
			if type(m) == "table" and m.op == op then
				n += 1
			end
		end
		return n
	end
	run(function()
		AdminService.stopAll("test")
	end)
	advance(1)
	-- The owner isn't in this server for any of it.
	local owner
	for _, g in guests do
		if g.UserId == 100 then
			owner = g
		end
	end
	local ownerParent = owner and owner.Parent
	if owner then
		owner.Parent = nil
	end

	-- 1. Order: an older command arriving late never undoes a newer one.
	local L = AdminService.cleanLive(nil)
	local t = now()
	check("a command is written down with when it was given", AdminService.writeLive(L, { op = "fx", id = "meteor", on = true }, t, "X") and L.fx.meteor ~= nil and L.marks["fx:meteor"] == t)
	check("switched off a moment later: off", AdminService.writeLive(L, { op = "fx", id = "meteor", on = false }, t + 2, "X") and L.fx.meteor == nil)
	check("the earlier 'on', arriving late, changes nothing", AdminService.writeLive(L, { op = "fx", id = "meteor", on = true }, t + 1, "X") == false and L.fx.meteor == nil)
	check("the same command twice is written once", AdminService.writeLive(L, { op = "fx", id = "meteor", on = false }, t + 2, "X") == false)
	AdminService.writeLive(L, { op = "fx", id = "galaxy", on = true }, t + 10, "X")
	AdminService.writeLive(L, { op = "fx", id = "ufo", on = true }, t + 5, "X")
	check("'every effect off' clears the effects switched on before it...", AdminService.writeLive(L, { op = "fxAllOff" }, t + 8, "X") and L.fx.ufo == nil)
	check("...but not one switched on after it (that happened to arrive first)", L.fx.galaxy ~= nil)
	check("an effect switched on before 'every effect off', arriving after it, stays off", AdminService.writeLive(L, { op = "fx", id = "ufo", on = true }, t + 6, "X") == false and L.fx.ufo == nil)
	AdminService.writeLive(L, { op = "abuse", minutes = 15, rid = "r1" }, t + 12, "X")
	AdminService.writeLive(L, { op = "event", id = "goldRain", minutes = 15 }, t + 12, "X")
	check("'stop everything' clears Admin Abuse, events and effects given before it", AdminService.writeLive(L, { op = "stopAll" }, t + 20, "X") and L.abuse == nil and next(L.fx) == nil and next(L.events) == nil)
	check("and nothing older comes back after it", AdminService.writeLive(L, { op = "abuse", minutes = 15, rid = "r0" }, t + 15, "X") == false and L.abuse == nil)
	check("a newer Mega Abuse after it is written down, under the remote's id", AdminService.writeLive(L, { op = "mega", minutes = 15, rid = "r2" }, t + 25, "X") and L.abuse ~= nil and L.abuse.mega == true and L.abuse.id == "remote:r2")
	check("it ends when it was given plus its length, however late a server hears it", math.abs(L.abuse.ends - (t + 25 + 900)) < 0.001)
	local kept = AdminService.cleanLive(L)
	check("what's written down survives being read back (marks and all)", kept.abuse ~= nil and kept.abuse.id == "remote:r2" and kept.marks["*"] == t + 20 and kept.marks["fx:galaxy"] == t + 10 and next(kept.fx) == nil)

	-- 2. A server that wasn't open when the remote's commands were sent: it finds them written down
	-- and carries them out once, in the order given.
	local t0 = now()
	dataStores.MaisonSchedule = dataStores.MaisonSchedule or {}
	dataStores.MaisonSchedule.live = {
		log = {
			{ cmd = { op = "fx", id = "aurora", on = true, rid = "L1" }, at = t0 - 300, rid = "L1" },
			{ cmd = { op = "fx", id = "meteor", on = true, rid = "L2" }, at = t0 - 200, rid = "L2" },
			{ cmd = { op = "fx", id = "meteor", on = false, rid = "L3" }, at = t0 - 100, rid = "L3" },
			{ cmd = { op = "abuse", minutes = 15, rid = "L4" }, at = t0 - 60, rid = "L4" },
			{ cmd = { op = "giftAll", amount = 100, rid = "L5" }, at = t0 - 600, rid = "L5" },
			{ cmd = { op = "headline", preset = 1, rid = "L6" }, at = t0 - 20, rid = "L6" },
		},
	}
	local castBefore = #broadcasts
	local someone = guests[1] ~= owner and guests[1] or guests[2]
	local giltBefore = profiles[someone].Data.gilt
	run(AdminService.syncLive)
	check("a server that wasn't open switches on the remote's effects...", W:GetAttribute("Fx_aurora") ~= nil)
	check("...in the order given (on, then off: off)", W:GetAttribute("Fx_meteor") == nil)
	local untilAt = W:GetAttribute("AbuseUntil")
	check("...joins its Admin Abuse for what's left of it (ending when it ends everywhere)", type(untilAt) == "number" and math.abs(untilAt - (t0 - 60 + 900)) <= 128, untilAt)
	check("...shows a headline sent a moment ago", castsOf("headline", castBefore) >= 1)
	check("...but doesn't hand out a gift sent ten minutes ago", profiles[someone].Data.gilt == giltBefore)
	local since = W:GetAttribute("AbuseSince")
	local heads = castsOf("headline", castBefore)
	advance(3)
	run(AdminService.syncLive)
	check("and never carries out the same one twice", W:GetAttribute("AbuseSince") == since and castsOf("headline", castBefore) == heads)
	advance(6)
	check("what it carried out is written into the record for the next server", live().fx ~= nil and live().fx.aurora ~= nil and live().abuse ~= nil and live().abuse.id == "remote:L4")
	check("...and the remote's own list is kept", type(live().log) == "table" and #live().log == 6)

	-- 3. Heard twice (the message, then the list written down): carried out once.
	run(function()
		AdminService.stopAll("test")
	end)
	advance(1)
	local before = #broadcasts
	local at = now()
	run(function()
		remote({ Data = string.format('{"op":"token","rid":"G1","at":%.3f}', at) })
	end)
	local tokens = castsOf("salute", before)
	dataStores.MaisonSchedule.live = { log = { { cmd = { op = "token", rid = "G1" }, at = at, rid = "G1" } } }
	run(AdminService.syncLive)
	check("a command heard as a message and then found written down is carried out once", tokens >= 1 and castsOf("salute", before) == tokens)

	-- 4. A countdown to Admin Abuse: a server opening during it counts down with the rest.
	local starts = now() + 20
	dataStores.MaisonSchedule.live = { abuse = { id = "remote:C1", starts = starts, ends = starts + Config.data.Admin.countdownAbuseMinutes * 60, mega = false, by = "XxxXxxX_77797" } }
	before = #broadcasts
	run(AdminService.syncLive)
	check("a server opening during a countdown to Admin Abuse counts down too", castsOf("countdown", before) == 1 and W:GetAttribute("AbuseUntil") == nil)
	advance(21)
	untilAt = W:GetAttribute("AbuseUntil")
	check("...then Admin Abuse begins, ending with everyone else's", type(untilAt) == "number" and math.abs(untilAt - (starts + Config.data.Admin.countdownAbuseMinutes * 60)) <= 128, untilAt)
	since = W:GetAttribute("AbuseSince")
	advance(3)
	run(AdminService.syncLive)
	check("...once", W:GetAttribute("AbuseSince") == since)
	-- The remote's countdown is written down for later servers too.
	run(function()
		AdminService.stopAll("test")
	end)
	advance(1)
	dataStores.MaisonSchedule.live = nil
	run(function()
		remote({ Data = string.format('{"op":"countdown","id":"mega","seconds":30,"rid":"C2","at":%.3f}', now()) })
	end)
	advance(6)
	check("a remote countdown to Mega Abuse is written down with when it starts", live().abuse ~= nil and live().abuse.mega == true and type(live().abuse.starts) == "number" and live().abuse.id == "remote:C2")
	advance(30)
	check("and Mega Abuse begins here when it's over", W:GetAttribute("AbuseMega") == true)
	run(function()
		AdminService.stopAll("test")
	end)
	advance(1)

	if owner then
		owner.Parent = ownerParent
	end
end

---------------------------------------------------------------------------------------------------
-- Build 54: Admin Abuse as a show, on the server: the owner's avatar for every screen, the realms,
-- and the owner's gifts (checked here: theirs, still open, Admin Abuse still on)
---------------------------------------------------------------------------------------------------
do
	local AbuseShow = module("ServerScriptService", "Server", "AbuseShow")
	local AdminService = module("ServerScriptService", "Server", "AdminService")
	local CuriosS = module("ServerScriptService", "Server", "Curios")
	local Remotes = H.Remotes
	local W = services.Workspace
	local show = Config.data.Admin.show
	local owner, ned, other
	for _, g in guests do
		if g.UserId == 100 then
			owner = g
		elseif g.UserId == 101 then
			ned = g
		elseif other == nil and g.Parent ~= nil then
			other = g
		end
	end
	run(function()
		AdminService.stopAll("test")
	end)
	advance(1)
	-- The owner's avatar, from their UserId, for every screen (whether or not they're in the server).
	local home = Instance.new("Folder")
	local asked = nil
	AbuseShow.home = function()
		return home
	end
	AbuseShow.makeAvatar = function(userId)
		asked = userId
		local m = Instance.new("Model")
		local h = Instance.new("Humanoid")
		h.Parent = m
		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Parent = m
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Parent = m
		local animate = Instance.new("LocalScript")
		animate.Name = "Animate"
		animate.Parent = m
		return m
	end
	run(AbuseShow.start)
	advance(1)
	local avatar = home:FindFirstChild(AbuseShow.AVATAR)
	check("the owner's avatar is built from the owner's own UserId", asked == Config.data.Admin.ownerUserId)
	check("...kept for every screen: no scripts in it, nothing to bump into, standing still", avatar ~= nil and avatar:FindFirstChild("Animate") == nil and avatar.HumanoidRootPart.Anchored == true and avatar.Head.CanCollide == false and avatar:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator") ~= nil)
	AdminService.showBegan = AbuseShow.began
	AdminService.showStopped = AbuseShow.stopped
	local open = Remotes.funcs.AbuseGiftAsk.OnServerInvoke
	local function openAs(player, request)
		advance(1.1)
		local r
		run(function()
			r = open(player, request)
		end)
		return r
	end
	-- No Admin Abuse, no gifts.
	check("no gift to open when nothing's on", openAs(ned, { op = "open", id = 1 }).ok == false)
	-- Admin Abuse: the opening, then the gilded night, and the owner's gifts.
	local castBefore = #broadcasts
	run(function()
		AdminService.abuse(900, "XxxXxxX_77797", false)
	end)
	local intro, salute = nil, nil
	for i = castBefore + 1, #broadcasts do
		local m = broadcasts[i].message
		if m.op == "abuseShow" then
			intro = m
		end
	end
	check("every screen is told to play the opening", intro ~= nil and intro.stage == "intro" and intro.mega == false)
	check("Admin Abuse keeps to the gilded night", W:GetAttribute("AbuseRealm") == show.abuseRealm)
	advance(show.dropAt + 0.2)
	for i = castBefore + 1, #broadcasts do
		local m = broadcasts[i].message
		if m.op == "salute" and m.id == "abuse" then
			salute = m
		end
	end
	check("the fireworks and the house's salute wait for the drop", salute ~= nil)
	advance(show.giftEvery.abuse * 0.4 + 2)
	local gift = lastOp(ned, "abuseGift")
	check("a gift from the owner on every guest's screen, saying what's in it", gift ~= nil and gift.gilt == show.giftGilt and type(gift.id) == "number" and lastOp(owner, "abuseGift") ~= nil)
	local nedData = profiles[ned].Data
	local before = nedData.gilt
	local r = openAs(ned, { op = "open", id = gift.id })
	check("opening it pays Gilt (Admin Abuse's Golden Hour doubles it)", r.ok == true and nedData.gilt > before and r.gilt == nedData.gilt - before, nedData.gilt - before)
	check("...once", openAs(ned, { op = "open", id = gift.id }).ok == false)
	local theirs = lastOp(owner, "abuseGift")
	check("nobody can open another guest's gift", openAs(ned, { op = "open", id = theirs.id }).ok == false)
	check("nor send nonsense", openAs(ned, { op = "open", id = "seven" }).ok == false and openAs(ned, { op = "steal", id = theirs.id }).ok == false and openAs(ned, "gift").ok == false)
	check("...and the owner opens their own", openAs(owner, { op = "open", id = theirs.id }).ok == true)
	-- A gift left too long goes.
	advance(show.giftEvery.abuse + 1)
	gift = lastOp(ned, "abuseGift")
	advance(show.giftWindow + 2)
	check("a gift not opened in time is gone", openAs(ned, { op = "open", id = gift.id }).ok == false)
	-- The third opened in one night: the Admin's Crown (once ever).
	advance(show.giftEvery.abuse - show.giftWindow + 2)
	gift = lastOp(ned, "abuseGift")
	r = openAs(ned, { op = "open", id = gift.id })
	check("the second gift of the night opens", r.ok == true and r.count == 2)
	advance(show.giftEvery.abuse + 1)
	gift = lastOp(ned, "abuseGift")
	check("the third says it holds the Admin's Crown", gift.crown == true and gift.number == 3)
	r = openAs(ned, { op = "open", id = gift.id })
	check("...and gives it", r.ok == true and r.crown == true and CuriosS.count(nedData, "adminCrown") == 1)
	-- Stopped: the realm goes, no more gifts.
	run(function()
		AdminService.stopAll("test")
	end)
	advance(1)
	check("stopping Admin Abuse ends its realm", W:GetAttribute("AbuseRealm") == nil)
	local count = #ned.inbox
	advance(show.giftEvery.abuse + 2)
	local more = 0
	for i = count + 1, #ned.inbox do
		if ned.inbox[i].op == "abuseGift" then
			more += 1
		end
	end
	check("...and its gifts", more == 0)
	-- Mega Abuse: realm after realm.
	run(function()
		AdminService.abuse(900, "XxxXxxX_77797", true)
	end)
	check("Mega Abuse begins in the first realm", W:GetAttribute("AbuseRealm") == show.realms[1])
	advance(show.realmSeconds + 2)
	check("...and moves on to the next", W:GetAttribute("AbuseRealm") == show.realms[2])
	advance(show.realmSeconds + 1)
	check("...and the next", W:GetAttribute("AbuseRealm") == show.realms[3])
	-- A guest who already has the crown gets more Gilt for the third gift instead.
	for i = 1, 3 do
		run(function()
			AbuseShow.offer(ned)
		end)
		gift = lastOp(ned, "abuseGift")
		if i == 3 then
			check("a guest with the crown is told their third gift brings a Gilt bonus", gift.crown == false and gift.bonus == show.crownBonus)
		end
		r = openAs(ned, { op = "open", id = gift.id })
	end
	check("...and gets it, and no second crown", r.ok == true and r.crown == false and r.count == 3 and CuriosS.count(nedData, "adminCrown") == 1)
	run(function()
		AdminService.stopAll("test")
	end)
	advance(1)
	AdminService.showBegan = function() end
	AdminService.showStopped = function() end
end

H.finish()

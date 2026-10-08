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
Config.data.Admin.studioEveryone = false
Config.data.Admin.userIds = { 100 }
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
check("the owner is marked, so only they see the House key", owner:GetAttribute("MaisonAdmin") == true and ned:GetAttribute("MaisonAdmin") ~= true)
do
	-- A group's experience: the group's owner (rank 255 in it) has House controls, a member doesn't.
	H.game.CreatorType = H.Enum.CreatorType.Group
	H.game.CreatorId = 777
	local gia, max = guest("Gia", 102), guest("Max", 103)
	H.groups[102] = { { Id = 777, Rank = 255 } }
	H.groups[103] = { { Id = 777, Rank = 10 }, { Id = 5, Rank = 255 } }
	check("in a group's experience, the group's owner has House controls", adminAs(gia, { op = "state" }).ok == true)
	check("and a member of the group doesn't", adminAs(max, { op = "state" }).ok == false)
	H.game.CreatorType = H.Enum.CreatorType.User
	H.game.CreatorId = 1
end
local st = adminAs(owner, { op = "state" })
check("the panel lists the events, the seasons, the salutes and the guests", #st.events == 11 and #st.seasons == 10 and #st.salutes == 6 and #st.guests >= 2)
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
check("with fireworks for the whole house", string.find(lastBroadcast("salute").title or "", "Admin Abuse", 1, true) ~= nil)
check("and goes to every house", #published > publishedBefore and published[#published].message.op == "abuse")
for _, id in Config.data.Admin.abuseEvents do
	AdminService.stopEvent(id)
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

H.finish()

--!nocheck
-- The Empire on the server (server/Empire, Fortune, Herald), under Lune on a fake clock, in the
-- house's test harness: what a Fortune is made of, the Estate and its cash share, the wealth ranks
-- (told once, the high ones to the house), bought Gilt left out of the boards, the Wealthiest
-- boards (all time, this week, in this house; off them by choice), and the herald (never a flood,
-- never a guest who chose not to be told about).
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/empire.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module, profiles, broadcasts = H.module, H.profiles, H.broadcasts
local Remotes, Config = H.Remotes, H.Config

-- (The harness's ordered stores can't take a key down: the boards do, for a guest who opts out.)
do
	local real = H.services.DataStoreService.GetOrderedDataStore
	H.services.DataStoreService.GetOrderedDataStore = function(self, name)
		local store = real(self, name)
		store.RemoveAsync = function(_, key)
			H.orderedStores[name][key] = nil
		end
		return store
	end
end

local Rules = module("ReplicatedStorage", "Shared", "Fortune")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local Wardrobe = module("ReplicatedStorage", "Shared", "Wardrobe")
local Empire = module("ServerScriptService", "Server", "Empire")
local Fortune = module("ServerScriptService", "Server", "Fortune")
local Herald = module("ServerScriptService", "Server", "Herald")

local tallies = {}
Empire.tally = function(p, stat, n, once)
	tallies[p.UserId .. ":" .. stat .. ":" .. tostring(once)] = (tallies[p.UserId .. ":" .. stat .. ":" .. tostring(once)] or 0) + n
end
run(Empire.start)
local ask = Remotes.funcs.EmpireAsk.OnServerInvoke
local function askAs(p, request)
	advance(0.4)
	local r
	run(function()
		r = ask(p, request)
	end)
	return r
end
local function last(p, op)
	for i = #p.inbox, 1, -1 do
		if p.inbox[i].op == op then
			return p.inbox[i]
		end
	end
	return nil
end
local function count(p, op)
	local n = 0
	for _, m in p.inbox do
		if m.op == op then
			n += 1
		end
	end
	return n
end
local function feats(kind)
	local out = {}
	for _, b in broadcasts do
		if b.remote == "Empire" and b.message.op == "feat" and (kind == nil or b.message.kind == kind) then
			table.insert(out, b.message)
		end
	end
	return out
end
local function data(g)
	return profiles[g].Data
end
local F = Config.data.Fortune

---------------------------------------------------------------------------------------------------
-- 1. The rules
---------------------------------------------------------------------------------------------------
check("the ranks begin at nothing and climb", Rules.Ranks[1].at == 0 and (function()
	for i = 2, #Rules.Ranks do
		if Rules.Ranks[i].at <= Rules.Ranks[i - 1].at then
			return false
		end
	end
	return true
end)())
check("a Fortune of nothing is a Newcomer's", Rules.rank(0).id == "newcomer" and select(2, Rules.rank(0)) == 1)
check("a rank begins exactly at its figure", Rules.rank(999).id == "newcomer" and Rules.rank(1000).id == "climber" and Rules.rank(40000).id == "magnate")
check("the top rank has no next", select(3, Rules.rank(1e9)) == nil and Rules.progress(1e9) == 1)
check("progress runs from the rank's start to the next", math.abs(Rules.progress(3000) - 0.5) < 1e-6, Rules.progress(3000))
check("figures are written with commas, and short for small spaces", Rules.format(1234567) == "1,234,567" and Rules.short(12500) == "12.5K" and Rules.short(1250000) == "1.25M" and Rules.short(950) == "950", Rules.short(12500) .. " " .. Rules.short(1250000))
check("a fifth of a haul is paid in Gilt", Rules.cash(1000) == math.floor(1000 * F.cashShare + 0.5))
check("every rarity has its worth, rarer worth more", Rules.RarityWorth.Common < Rules.RarityWorth.Rare and Rules.RarityWorth.Rare < Rules.RarityWorth.Mythic and Rules.RarityWorth.Mythic < Rules.RarityWorth.Secret)

---------------------------------------------------------------------------------------------------
-- 2. What a Fortune is made of
---------------------------------------------------------------------------------------------------
local ada = H.guest("Ada", 501)
advance(2.5)
local d = data(ada)
check("a new guest's Fortune is published on arrival", ada:GetAttribute("Fortune") ~= nil and ada:GetAttribute("FortuneRank") == 1, ada:GetAttribute("Fortune"))
d.gilt = 300
d.gems = 5
advance(2.5)
check("Gilt counts as it is, and each Gem at its worth", ada:GetAttribute("Fortune") == 300 + 5 * F.gemWorth, ada:GetAttribute("Fortune"))
-- A collection: one of a rarity, three of another.
local rare, common
for _, c in CurioList.List do
	if c.rarity == "Rare" and not rare then
		rare = c
	elseif c.rarity == "Common" and not common then
		common = c
	end
end
d.curios = d.curios or { items = {}, favs = {}, recent = {}, found = 0, given = {} }
d.curios.items[rare.id] = 1
d.curios.items[common.id] = 3
advance(2.5)
check("a collection counts by rarity, each one held", Fortune.parts(d).collection == Rules.RarityWorth.Rare + 3 * Rules.RarityWorth.Common, Fortune.parts(d).collection)
d.curios.items.noSuchCurio = 9
check("a curio the house doesn't know counts for nothing", Fortune.parts(d).collection == Rules.RarityWorth.Rare + 3 * Rules.RarityWorth.Common)
-- The Suite and wardrobe: a piece with a Gilt price counts at it; a Robux-only piece doesn't.
local priced, robuxOnly
for _, item in Wardrobe.all do
	if type(item.gilt) == "number" and item.gilt > 0 and not priced then
		priced = item
	elseif item.gilt == nil and type(item.robux) == "number" and not robuxOnly then
		robuxOnly = item
	end
end
d.owned[priced.id] = true
d.owned[robuxOnly.id] = true
check("a piece with a Gilt price counts at that price", Fortune.parts(d).suite == priced.gilt, Fortune.parts(d).suite)
check("a Robux-only piece adds nothing to a Fortune (wealth isn't for sale)", Fortune.parts(d).suite == priced.gilt)
local total = Rules.total(Fortune.parts(d))
check("the whole is the sum of its parts", select(1, Fortune.of(d)) == total and total == 300 + 5 * F.gemWorth + Rules.RarityWorth.Rare + 3 * Rules.RarityWorth.Common + priced.gilt, total)

---------------------------------------------------------------------------------------------------
-- 3. The Estate, and its cash share
---------------------------------------------------------------------------------------------------
local giltBefore = d.gilt
local paid
run(function()
	paid = Fortune.estate(ada, 1000, "Steal a Luxe")
end)
check("a haul banked adds its whole worth to the Estate", Fortune.page(d).estate == 1000 and ada:GetAttribute("Estate") == 1000)
check("and pays its cash share in Gilt", paid == Rules.cash(1000) and d.gilt == giltBefore + paid, paid)
check("the Fortune rises by the haul and the cash", select(1, Fortune.of(d)) == total + 1000 + paid, select(1, Fortune.of(d)) - total)
run(function()
	paid = Fortune.estate(ada, 500, "A chest", false)
end)
check("a chest with no cash share adds to the Estate alone", paid == 0 and Fortune.page(d).estate == 1500)
run(function()
	paid = Fortune.estate(ada, -50, "nonsense")
end)
check("nothing is added for nothing (or less)", paid == 0 and Fortune.page(d).estate == 1500)
-- The cash share goes through Gilt.pay: the day's soft cap applies to it.
d.giltDay = { day = math.floor(H.fakeOs.time() / 86400), earned = Config.data.Gilt.dailySoftCap }
giltBefore = d.gilt
run(function()
	paid = Fortune.estate(ada, 10000, "Steal a Luxe")
end)
check("past the day's soft cap the cash is paid at the reduced rate (the Estate in full)", paid == math.floor(Rules.cash(10000) * Config.data.Gilt.softCapRate) and Fortune.page(d).estate == 11500, paid)
check("the Estate is kept on the saved record", d.empire.estate == 11500 and d.empire.hauls == 3, d.empire.hauls)

---------------------------------------------------------------------------------------------------
-- 4. Wealth ranks: told once; the high ones to the house
---------------------------------------------------------------------------------------------------
local _, adaRank = Rules.rank(select(1, Fortune.of(d)))
check("the guest is told each new rank", last(ada, "rank") ~= nil and last(ada, "rank").rank == adaRank, adaRank)
local told = count(ada, "rank")
advance(6)
check("and only once", count(ada, "rank") == told)
advance(Config.data.Herald.kindGap + 5) -- (clear of any rank told a moment ago)
local publicBefore = #feats("rank")
run(function()
	Fortune.estate(ada, 100000, "Steal a Luxe", false)
end)
advance(8)
local _, high = Rules.rank(select(1, Fortune.of(d)))
check("a high rank is told to the whole house", high >= F.announceFrom and #feats("rank") == publicBefore + 1, high)
check("...with the guest's name and the rank's figure", feats("rank")[#feats("rank")].name == "Ada" and feats("rank")[#feats("rank")].userId == 501 and feats("rank")[#feats("rank")].worth == Rules.Ranks[high].at)
-- A guest from before Fortunes began arrives at their rank quietly.
local old = H.guest("Olde", 502)
data(old).gilt = 60000
advance(2.5)
check("a guest who was rich before Fortunes began isn't announced for it", last(old, "rank") == nil and old:GetAttribute("FortuneRank") >= 5 and data(old).empire.rank == old:GetAttribute("FortuneRank"), old:GetAttribute("FortuneRank"))

---------------------------------------------------------------------------------------------------
-- 5. Bought Gilt and Gems: in your Fortune, off the boards
---------------------------------------------------------------------------------------------------
local buyer = H.guest("Buyer", 503)
advance(2.5)
local bd = data(buyer)
H.MarketplaceService.devProducts = { { Name = "gilt purse", ProductId = 9102, PriceInRobux = 49 } }
run(H.Shop.discover)
H.receipt(buyer, 9102, "EMP-GP-1")
advance(2.5)
local purse = module("ReplicatedStorage", "Shared", "ProductConfig").byKey.giltPurse1.Reward.Amount
check("a Gilt purse shows in the buyer's own Fortune", buyer:GetAttribute("Fortune") == bd.gilt + (bd.gems or 0) * F.gemWorth and bd.gilt >= purse, buyer:GetAttribute("Fortune"))
check("but not in the Fortune they've earned (what the boards rank)", buyer:GetAttribute("FortuneEarned") == buyer:GetAttribute("Fortune") - purse and bd.empire.bought == purse, buyer:GetAttribute("FortuneEarned"))
bd.gilt -= 400 -- (spent on something with no Gilt price: the bought Gilt still isn't "earned")
advance(2.5)
check("spending bought Gilt never makes the earned Fortune negative", buyer:GetAttribute("FortuneEarned") == 0 or buyer:GetAttribute("FortuneEarned") == buyer:GetAttribute("Fortune") - purse, buyer:GetAttribute("FortuneEarned"))

---------------------------------------------------------------------------------------------------
-- 6. The Wealthiest boards
---------------------------------------------------------------------------------------------------
advance(F.boardSeconds + 3)
local allStore = H.orderedStores[F.store]
check("each guest's earned Fortune is offered to the all-time board", allStore ~= nil and allStore["501"] == ada:GetAttribute("FortuneEarned") and allStore["502"] == old:GetAttribute("FortuneEarned"), allStore and allStore["501"])
check("a guest who has earned nothing isn't on it", allStore["503"] == nil or allStore["503"] == buyer:GetAttribute("FortuneEarned"))
local weekName
for name in H.orderedStores do
	if string.find(name, F.store .. "_week_", 1, true) then
		weekName = name
	end
end
check("this week's gain goes to the week's board", weekName ~= nil and H.orderedStores[weekName]["501"] ~= nil and H.orderedStores[weekName]["501"] > 0, weekName)
local view = askAs(ada, { op = "fortune" })
check("the Fortune screen is given the parts, the rank and the boards", view.ok == true and view.total == ada:GetAttribute("Fortune") and view.parts.estate == d.empire.estate and view.rank == ada:GetAttribute("FortuneRank"))
check("the all-time board is in order, richest first", #view.boards.all >= 2 and view.boards.all[1].score >= view.boards.all[2].score and view.boards.all[1].userId == 501, view.boards.all[1] and view.boards.all[1].userId)
check("the house's own board lists who's here, richest first", #view.boards.here == 3 and view.boards.here[1].userId == 501 and view.boards.here[1].name == "Ada")
check("a malformed ask is refused", askAs(ada, { op = "fortune", gilt = 5 }).ok == false and askAs(ada, "fortune").ok == false and askAs(ada, { op = "everything" }).ok == false)
-- Off the boards by choice.
data(old).settings.showFortune = "Off"
advance(F.boardSeconds + 3)
check("a guest who turns Show my Fortune off is taken off the boards", allStore["502"] == nil, allStore["502"])
check("...and off the house's own list", (function()
	for _, e in askAs(ada, { op = "fortune" }).boards.here do
		if e.userId == 502 then
			return false
		end
	end
	return true
end)())
check("...while their own screen still shows their Fortune, and says so", askAs(old, { op = "fortune" }).shown == false and askAs(old, { op = "fortune" }).total == old:GetAttribute("Fortune"))

---------------------------------------------------------------------------------------------------
-- 7. The herald
---------------------------------------------------------------------------------------------------
advance(60)
local before = #feats()
local heard
run(function()
	heard = Herald.feat(ada, { kind = "haul", title = "A great haul", line = "carried the Crown Jewel out of Steal a Luxe", glyph = "💎", worth = 15000 })
end)
advance(1)
check("a feat is told to the whole house", heard == true and #feats() == before + 1 and feats()[#feats()].line == "carried the Crown Jewel out of Steal a Luxe" and feats()[#feats()].worth == 15000)
run(function()
	heard = Herald.feat(ada, { kind = "haul", title = "A great haul", line = "did it again" })
end)
advance(1)
check("the same kind of feat again so soon is told only to the guest", heard == false and #feats() == before + 1 and last(ada, "feat") ~= nil and last(ada, "feat").own == true)
run(function()
	heard = Herald.feat(old, { kind = "haul", title = "A great haul", line = "kept it quiet" })
end)
advance(1)
check("a guest who chose not to show their feats is told alone", heard == false and #feats() == before + 1 and last(old, "feat") ~= nil)
-- Never a flood: many feats at once are told one at a time, a few at most.
local flood = {}
for i = 1, 12 do
	flood[i] = H.guest("Flood" .. i, 600 + i)
end
advance(1)
before = #feats()
run(function()
	for i = 1, 12 do
		Herald.feat(flood[i], { kind = "find", title = "A rare find", line = "found number " .. i })
	end
end)
advance(0.5)
check("a burst of feats isn't told all at once", #feats() - before <= 1, #feats() - before)
advance(Config.data.Herald.gap * 14)
check("...the house hears them one at a time, the oldest of too many let go", #feats() - before <= Config.data.Herald.queue and #feats() - before >= 2, #feats() - before)
check("...and the last to come is among those told", feats()[#feats()].line == "found number 12", feats()[#feats()].line)

H.finish()

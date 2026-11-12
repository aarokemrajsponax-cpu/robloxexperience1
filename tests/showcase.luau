--!nocheck
-- The Vault's and the Suite's displays on the server (server/Showcase, the history server/Curios
-- keeps, server/SuiteVisits' rules), under Lune in the house's test harness: the featured curios
-- (four at most, only curios really held, one traded away gone from its dome), the arrangement,
-- the acquisition history, the collection's completion, who may look round a Vault, the Suite's
-- themes (a price shown first and paid once, all of it or none; the Island Key's and Prestige's
-- for those who hold them), who may visit a Suite (friends, invited friends, nobody) and requests
-- that aren't the displays'.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/showcase.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module, profiles = H.module, H.profiles
local Remotes = H.Remotes

local Rules = module("ReplicatedStorage", "Shared", "Showcase")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local Showcase = module("ServerScriptService", "Server", "Showcase")
local Curios = module("ServerScriptService", "Server", "Curios")
local Friends = module("ServerScriptService", "Server", "Friends")
local SuiteVisits = module("ServerScriptService", "Server", "SuiteVisits")

local friendsWith = {}
Friends.are = function(a, b)
	return friendsWith[a.UserId .. ":" .. b.UserId] == true or friendsWith[b.UserId .. ":" .. a.UserId] == true
end
Friends.inServer = function(p)
	local out = {}
	for _, other in H.game:GetService("Players"):GetPlayers() do
		if other ~= p and Friends.are(p, other) then
			table.insert(out, other)
		end
	end
	return out
end

local ada = H.guest("Ada", 1201)
local bo = H.guest("Bo", 1202)
local cy = H.guest("Cy", 1203)
friendsWith["1201:1202"] = true
SuiteVisits.mayVisit = Showcase.mayVisitSuite
run(Showcase.start)
run(SuiteVisits.start)

local ask = Remotes.funcs.ShowcaseAsk.OnServerInvoke
local function askAs(g, request)
	advance(0.4)
	local r
	run(function()
		r = ask(g, request)
	end)
	return r
end
local function data(g)
	return profiles[g].Data
end

---------------------------------------------------------------------------------------------------
-- 1. The history, as curios arrive
---------------------------------------------------------------------------------------------------
local d = data(ada)
Curios.give(ada, d, "croissantino", 2, "tables")
Curios.give(ada, d, "chatCouture", 1, "trade")
Curios.give(ada, d, "baguettone", 1, "tables")
check("each curio that arrives is written in the history, newest first, with how it came", d.curios.history[1].id == "baguettone" and d.curios.history[2].id == "chatCouture" and d.curios.history[2].source == "trade" and d.curios.history[3].n == 2)
check("and when each was first had", type(d.curios.first.croissantino) == "number")
for i = 1, 45 do
	Curios.give(nil, d, "croissantino", 1, "tables")
end
check("the history keeps the last forty", #d.curios.history == Rules.HISTORY)

---------------------------------------------------------------------------------------------------
-- 2. The featured curios
---------------------------------------------------------------------------------------------------
local r = askAs(ada, { op = "feature", items = { "chatCouture", "croissantino" } })
check("two curios under the domes", r.ok == true and r.featured[1] == "chatCouture" and r.featured[2] == "croissantino", r)
check("a curio that isn't the house's is refused", askAs(ada, { op = "feature", items = { "dragonEgg" } }).ok == false)
check("a curio not held is refused", askAs(ada, { op = "feature", items = { "gelato" } }).ok == false)
Curios.give(nil, d, "pigeonetto", 1, "tables")
Curios.give(nil, d, "fromaggio", 1, "tables")
check("five is one more than the domes", askAs(ada, { op = "feature", items = { "chatCouture", "croissantino", "baguettone", "pigeonetto", "fromaggio" } }).ok == false)
r = askAs(ada, { op = "feature", items = { "chatCouture", "chatCouture", "baguettone" } })
check("the same curio twice is shown once", r.ok == true and #r.featured == 2, r.featured)
Curios.take(d, "chatCouture", 1)
check("one traded away leaves its dome empty", #Showcase.featured(d) == 1 and Showcase.featured(d)[1] == "baguettone")

---------------------------------------------------------------------------------------------------
-- 3. The arrangement, the collection's completion
---------------------------------------------------------------------------------------------------
check("an arrangement is chosen", askAs(ada, { op = "arrange", what = "newest" }).arrange == "newest")
check("one the house doesn't have is refused", askAs(ada, { op = "arrange", what = "upsideDown" }).ok == false)
local comp = Showcase.completion(d)
local memes = nil
for _, f in comp.families do
	if f.id == "meme" then
		memes = f
	end
end
check("the collection's completion: distinct curios of each family", memes ~= nil and memes.held == 4 and memes.total >= 40 and comp.total == #CurioList.List, memes and memes.held)

---------------------------------------------------------------------------------------------------
-- 4. Who may look round a Vault
---------------------------------------------------------------------------------------------------
check("everyone may, by default", askAs(cy, { op = "visit", userId = ada.UserId }).ok == true)
askAs(ada, { op = "privacy", what = "vault", value = "friends" })
check("friends only: a friend may", askAs(bo, { op = "visit", userId = ada.UserId }).ok == true)
r = askAs(cy, { op = "visit", userId = ada.UserId })
check("...nobody else", r.ok == false and tostring(r.why):find("private") ~= nil, r)
askAs(ada, { op = "privacy", what = "vault", value = "me" })
check("only me: not even a friend", askAs(bo, { op = "visit", userId = ada.UserId }).ok == false)
check("a choice the house doesn't have is refused", askAs(ada, { op = "privacy", what = "vault", value = "the world" }).ok == false)
local card = (function()
	askAs(ada, { op = "privacy", what = "vault", value = "everyone" })
	return askAs(cy, { op = "visit", userId = ada.UserId })
end)()
check("a look round: their four domes and their collection", card.ok == true and card.name == "Ada" and card.featured[1] == "baguettone" and card.completion.held >= 4)

---------------------------------------------------------------------------------------------------
-- 5. The Suite's themes
---------------------------------------------------------------------------------------------------
d.gilt = 10000
r = askAs(ada, { op = "theme", what = "ivory" })
check("a theme with a price is bought first", r.ok == false)
r = askAs(ada, { op = "buyTheme", what = "ivory" })
check("not enough Gilt: nothing taken", r.ok == false and d.gilt == 10000)
d.gilt = 20000
r = askAs(ada, { op = "buyTheme", what = "ivory" })
check("bought for exactly its price, and chosen", r.ok == true and d.gilt == 5000 and r.theme == "ivory" and ada:GetAttribute("SuiteTheme") == "ivory", d.gilt)
askAs(ada, { op = "theme", what = "noir" })
r = askAs(ada, { op = "buyTheme", what = "ivory" })
check("owned: chosen again for nothing", r.ok == true and d.gilt == 5000 and r.theme == "ivory")
r = askAs(ada, { op = "theme", what = "island" })
check("Island White comes with the Island Key", r.ok == false and tostring(r.why):find("Island Key") ~= nil)
d.attractions = d.attractions or {}
d.attractions.island = { key = true }
check("...and is chosen, free, with it", askAs(ada, { op = "theme", what = "island" }).theme == "island")
check("the Laurel Rooms come with Maison Prestige", askAs(ada, { op = "theme", what = "laurel" }).ok == false)
d.prestige = { level = 4 }
check("...and with the laurel, they're chosen", askAs(ada, { op = "theme", what = "laurel" }).theme == "laurel")
check("a theme the house doesn't have is refused", askAs(ada, { op = "theme", what = "neon" }).ok == false)
local themes = askAs(ada, { op = "state" }).themes
check("every theme is told with its price or what it comes with", #themes == #Rules.Themes and themes[2].price == "15,000 Gilt" and themes[6].price == "With the Island Key")

---------------------------------------------------------------------------------------------------
-- 6. Who may visit a Suite
---------------------------------------------------------------------------------------------------
local function visit(g, host)
	advance(0.4)
	local v
	run(function()
		v = SuiteVisits.handle(g, { op = "visit", userId = host.UserId })
	end)
	return v
end
check("friends, by default: a friend may visit", visit(bo, ada).ok == true)
run(function()
	SuiteVisits.handle(bo, { op = "home" })
end)
askAs(ada, { op = "privacy", what = "suite", value = "nobody" })
r = visit(bo, ada)
check("nobody: not even a friend", r.ok == false and tostring(r.why):find("to themselves") ~= nil, r)
askAs(ada, { op = "privacy", what = "suite", value = "invited" })
check("invited friends only: a friend uninvited may not", visit(bo, ada).ok == false)
check("only a friend can be invited", askAs(ada, { op = "invite", userId = cy.UserId }).ok == false)
r = askAs(ada, { op = "invite", userId = bo.UserId })
check("a friend invited", r.ok == true and r.invited[1] ~= nil and r.invited[1].name == "Bo", r)
check("...may visit", visit(bo, ada).ok == true)
check("someone who isn't a friend never may", visit(cy, ada).ok == false)

---------------------------------------------------------------------------------------------------
-- 7. Requests that aren't the displays'
---------------------------------------------------------------------------------------------------
check("an op the displays don't know is refused", askAs(ada, { op = "steal" }).ok == false)
check("a key that isn't the displays' is refused", askAs(ada, { op = "state", sneaky = true }).ok == false)
check("features that aren't a list are refused", askAs(ada, { op = "feature", items = "everything" }).ok == false)

---------------------------------------------------------------------------------------------------
-- 8. The daily streak (server/Streak)
---------------------------------------------------------------------------------------------------
local Streak = module("ServerScriptService", "Server", "Streak")
local day = 20400
Streak.now = function()
	return day * 86400 + 3600
end
local sd = data(cy)
local gems0 = sd.gems or 0
sd.gilt = sd.gilt or 0
Streak.arrive(cy, sd)
check("a first visit: a streak of one, no boost yet", sd.streak.count == 1 and cy:GetAttribute("Streak") == 1 and cy:GetAttribute("StreakBoost") == nil and Streak.mult(cy) == 1)
Streak.arrive(cy, sd)
check("the same day again changes nothing", sd.streak.count == 1)
day += 1
Streak.arrive(cy, sd)
check("the next day: two in a row, 5% more Gilt", sd.streak.count == 2 and math.abs(Streak.mult(cy) - 1.05) < 1e-9 and cy:GetAttribute("StreakBoost") == 5)
day += 1
local gilt0 = sd.gilt
Streak.arrive(cy, sd)
check("three in a row: a gift of Gilt from the house", sd.streak.count == 3 and sd.gilt == gilt0 + Streak.GIFTS[3], sd.gilt - gilt0)
check("...and never a Gem: those come only from Robux", (sd.gems or 0) == gems0)
local msg = nil
for i = #cy.inbox, 1, -1 do
	if cy.inbox[i].op == "streak" then
		msg = cy.inbox[i]
		break
	end
end
check("and the guest's screen is told: the streak, its boost, tomorrow's, the gift", msg ~= nil and msg.count == 3 and msg.boost == 10 and msg.next == 15 and msg.gift == Streak.GIFTS[3] and msg.gems == nil, msg)
check("...and when the next gift comes (seven days in a row)", msg ~= nil and msg.giftAt == 7 and msg.giftGilt == Streak.GIFTS[7])
check("the next gift past thirty: every thirty days", select(2, Streak.nextGift(30)) == Streak.EVERY_THIRTY and select(2, Streak.nextGift(45)) == Streak.EVERY_THIRTY)
day += 3
check("a streak from days ago is worth nothing now", Streak.mult(cy) == 1)
Streak.arrive(cy, sd)
check("a day missed: it starts again at one (the best kept)", sd.streak.count == 1 and sd.streak.best == 3)
check("never more than 30% more", Streak.boostFor(40) == 1 + Streak.MOST and Streak.boostFor(7) == 1 + Streak.MOST)
check("a gift every thirty days past thirty", Streak.gift(60) == Streak.EVERY_THIRTY and Streak.gift(31) == 0)

H.finish()

--!nocheck
-- Maison Prestige (shared/Prestige, server/Prestige), under Lune in the house's test harness: the
-- ten laurels (points by badge tier, a great deed from the fourth on, climbed in order), a guest's
-- laurel worked out and published (their title and laurel on them), told once, the highest to the
-- house; a laurel once held never taken away; the Prestige card; the Laurel Flourish (only from its
-- laurel, never a flood).
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/prestige.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module, profiles, broadcasts = H.module, H.profiles, H.broadcasts
local Remotes = H.Remotes

local Rules = module("ReplicatedStorage", "Shared", "Prestige")
local BadgeBook = module("ReplicatedStorage", "Shared", "BadgeBook")
local Empire = module("ServerScriptService", "Server", "Empire")
local Prestige = module("ServerScriptService", "Server", "Prestige")
local Achievements = module("ServerScriptService", "Server", "Achievements")

Achievements.given = function(p, _badge, quiet)
	Prestige.sync(p, quiet)
end
run(Empire.start)
local function askAs(p, request)
	advance(0.4)
	local r
	run(function()
		r = Remotes.funcs.EmpireAsk.OnServerInvoke(p, request)
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
-- Badges worth at least `points`, none of them a laurel's great deed.
local DEEDS = {}
for _, l in Rules.Levels do
	if l.milestone and l.milestone.kind == "badge" then
		DEEDS[l.milestone.key] = true
	end
end
local function badgesWorth(points)
	local out, total = {}, 0
	for _, b in BadgeBook.List do
		if total >= points then
			break
		end
		if not DEEDS[b.key] then
			out[b.key] = true
			total += Rules.POINTS[b.tier]
		end
	end
	return out, total
end

---------------------------------------------------------------------------------------------------
-- 1. The laurels
---------------------------------------------------------------------------------------------------
local all = 0
for _, b in BadgeBook.List do
	all += Rules.POINTS[b.tier] or 0
end
check("ten laurels, each asking more than the one before", #Rules.Levels == 10 and (function()
	for i = 2, #Rules.Levels do
		if Rules.Levels[i].points <= Rules.Levels[i - 1].points then
			return false
		end
	end
	return true
end)())
check("every laurel can be reached: the Badge Book holds enough points for the highest", all >= Rules.Levels[10].points, all)
local deedsReal = true
for key in DEEDS do
	if not BadgeBook.byKey[key] then
		deedsReal = false
	end
end
check("every great deed is a real badge", deedsReal)
check("the first three ask only for points; from the fourth, a great deed as well", Rules.Levels[3].milestone == nil and Rules.Levels[4].milestone ~= nil and Rules.Levels[10].milestone ~= nil)
check("every laurel says what it brings", (function()
	for _, l in Rules.Levels do
		if #l.rewards == 0 then
			return false
		end
	end
	return true
end)())
local some = badgesWorth(100)
check("points without the deed: held at the laurel below", Rules.levelOf(100, { badges = some, rank = 1 }) == 3)
local withDeed = table.clone(some)
withDeed.basementClear = true
check("...the deed done: the next laurel", Rules.levelOf(100, { badges = withDeed, rank = 1 }) == 4)
local most = badgesWorth(600)
most.basementClear, most.islandKey, most.auctionWin, most.gpWin = true, true, true, true
check("climbed in order: a deed not done holds back every laurel above it", Rules.levelOf(600, { badges = most, rank = 10 }) == 4)
most.executiveBoss = true
check("...done, and the wealth ranks reached: every laurel", Rules.levelOf(600, { badges = most, rank = 10 }) == 10)
check("the wealth-rank deeds go by the highest rank ever reached", Rules.levelOf(600, { badges = most, rank = 8 }) == 8)

---------------------------------------------------------------------------------------------------
-- 2. A guest's laurel
---------------------------------------------------------------------------------------------------
local ada = H.guest("Ada", 801)
advance(1)
check("a new guest: no laurel yet", Prestige.level(ada) == 0 and ada:GetAttribute("Prestige") == nil)
local data = profiles[ada].Data
local start, worth = badgesWorth(31)
data.badges = start
run(function()
	Prestige.sync(ada)
end)
check("enough points: the laurel, on the guest for every screen", ada:GetAttribute("Prestige") == 2 and ada:GetAttribute("PrestigeTitle") == "Bronze Laurel", worth)
check("...said on their screen, once", last(ada, "prestige") ~= nil and last(ada, "prestige").level == 2 and count(ada, "prestige") == 1)
check("...kept with the day it came", type(data.prestige.at["1"]) == "number" and type(data.prestige.at["2"]) == "number")
run(function()
	Prestige.sync(ada)
end)
check("worked out again: not said twice", count(ada, "prestige") == 1)
data.badges = {}
run(function()
	Prestige.sync(ada)
end)
check("a laurel once held is never taken away", ada:GetAttribute("Prestige") == 2 and Prestige.level(ada) == 2)
-- A badge given by the house counts at once.
data.badges = badgesWorth(88)
run(function()
	Achievements.award(ada, "basementClear")
end)
advance(0.5)
check("a badge given: counted toward Prestige at once (the deed done, the Gold Laurel)", ada:GetAttribute("Prestige") == 4 and last(ada, "prestige").level == 4, ada:GetAttribute("Prestige"))

---------------------------------------------------------------------------------------------------
-- 3. The card
---------------------------------------------------------------------------------------------------
local card = askAs(ada, { op = "prestige" })
check("the card: the laurel held, the points, every laurel", card.ok == true and card.level == 4 and #card.levels == 10 and card.levels[4].held == true and card.levels[5].held == false)
check("...the next laurel's needs: points short, and its deed not done", card.next ~= nil and card.next.level == 5 and card.next.short > 0 and card.next.milestoneMet == false and type(card.next.milestone) == "string")
check("...what each brings", type(card.levels[5].rewards) == "table" and #card.levels[5].rewards >= 2)

---------------------------------------------------------------------------------------------------
-- 4. The Laurel Flourish
---------------------------------------------------------------------------------------------------
local bo = H.guest("Bo", 802)
advance(1)
local r = askAs(bo, { op = "flourish" })
check("below the Gold Laurel: no Flourish", r.ok == false and type(r.why) == "string")
local before = #broadcasts
r = askAs(ada, { op = "flourish" })
local seen = false
for i = before + 1, #broadcasts do
	if broadcasts[i].remote == "Empire" and broadcasts[i].message.op == "flourish" and broadcasts[i].message.userId == 801 then
		seen = true
	end
end
check("from the Gold Laurel: a Flourish every screen sees", r.ok == true and seen)
r = askAs(ada, { op = "flourish" })
check("...never a flood: one every twenty seconds", r.ok == false)
advance(21)
r = askAs(ada, { op = "flourish" })
check("...and again after", r.ok == true)

---------------------------------------------------------------------------------------------------
-- 5. The highest laurels are told to the house
---------------------------------------------------------------------------------------------------
local cy = H.guest("Cy", 803)
advance(1)
local top = badgesWorth(600)
top.basementClear, top.executiveBoss, top.islandKey, top.auctionWin, top.gpWin = true, true, true, true, true
profiles[cy].Data.badges = top
local fpage = profiles[cy].Data.fortune or {}
profiles[cy].Data.fortune = fpage
fpage.rank = 8
run(function()
	Prestige.sync(cy)
end)
check("the Ruby Laurel: told to the house", cy:GetAttribute("Prestige") == 8)
local told = false
for _, b in broadcasts do
	if b.remote == "Empire" and b.message.op == "feat" and b.message.kind == "prestige" and b.message.userId == 803 then
		told = true
	end
end
check("...the house hears of it", told)

H.finish()

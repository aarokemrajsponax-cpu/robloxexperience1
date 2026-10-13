--!nocheck
-- The Evening Calendar on the server (server/Calendar), under Lune in the house's test harness:
-- one present a day, exactly the one shown; the next any later day, a missed day losing nothing;
-- the seventh with its curio (once ever: Gems after that); a new week after the seventh; the
-- Badge Book's count; a damaged page mended; and nothing a screen sends can change what it pays.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/calendar.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module, profiles, Remotes = H.module, H.profiles, H.Remotes

local Evenings = module("ReplicatedStorage", "Shared", "Evenings")
local CuriosS = module("ServerScriptService", "Server", "Curios")
local Achievements = module("ServerScriptService", "Server", "Achievements")
local Calendar = module("ServerScriptService", "Server", "Calendar")
local xpGiven, opened = 0, 0
Calendar.xp = function(_, n)
	xpGiven += n
end
Calendar.opened = function()
	opened += 1
end
run(Calendar.start)
local ask = Remotes.funcs.CalendarAsk.OnServerInvoke
local function askAs(p, request)
	advance(1.1) -- (the remote's limit: about one a second)
	local r
	run(function()
		r = ask(p, request)
	end)
	return r
end

local ivy = H.guest("Ivy", 601)
local data = profiles[ivy].Data
data.gems = data.gems or 0
local today = Evenings.today()

---------------------------------------------------------------------------------------------------
-- 1. Tonight's present
---------------------------------------------------------------------------------------------------
local s = askAs(ivy, { op = "state" })
check("a new guest: nothing opened yet, tonight's present waiting", s.ok == true and s.step == 0 and s.ready == true and s.weeks == 0 and s.total == 0)
check("...and the calendar says when the next day's comes (midnight, UTC)", type(s.nextIn) == "number" and s.nextIn > 0 and s.nextIn <= 86400)
local gilt0 = data.gilt
local r = askAs(ivy, { op = "open" })
check("opening it: the first evening's present, exactly as shown", r.ok == true and r.opened == 1 and r.gilt == Evenings.Week[1].gilt and data.gilt == gilt0 + Evenings.Week[1].gilt, data.gilt - gilt0)
check("...once a day", askAs(ivy, { op = "open" }).ok == false and data.gilt == gilt0 + Evenings.Week[1].gilt)
check("...and the calendar says it's open, and when the next is", askAs(ivy, { op = "state" }).ready == false)

---------------------------------------------------------------------------------------------------
-- 2. The week
---------------------------------------------------------------------------------------------------
-- (Another day: the last present opened before today.)
local function laterDay(days)
	data.calendar.day = today - (days or 1)
end
laterDay(1)
r = askAs(ivy, { op = "open" })
check("the next day: the second evening's present", r.ok == true and r.opened == 2 and r.gilt == Evenings.Week[2].gilt)
-- Three days away: nothing lost, the week waits.
laterDay(3)
local gems0 = data.gems
r = askAs(ivy, { op = "open" })
check("three days away and back: the third evening's, nothing lost", r.ok == true and r.opened == 3 and r.gems == Evenings.Week[3].gems and data.gems == gems0 + Evenings.Week[3].gems)
check("...its Gems on the guest's screen too", ivy:GetAttribute("Gems") == data.gems)
laterDay(1)
xpGiven = 0
r = askAs(ivy, { op = "open" })
check("the fourth: Gilt and XP", r.ok == true and r.opened == 4 and r.xp == Evenings.Week[4].xp and xpGiven == Evenings.Week[4].xp)
laterDay(1)
askAs(ivy, { op = "open" })
laterDay(1)
askAs(ivy, { op = "open" })
check("six opened", data.calendar.step == 6 and data.calendar.total == 6)
laterDay(1)
gilt0, gems0 = data.gilt, data.gems
r = askAs(ivy, { op = "open" })
local seventh = Evenings.Week[7]
check("the seventh: the best of them, with its curio", r.ok == true and r.opened == 7 and r.curio == Evenings.CURIO and CuriosS.count(data, Evenings.CURIO) == 1 and data.gilt == gilt0 + seventh.gilt and data.gems == gems0 + seventh.gems)
check("...and a new week begins", data.calendar.step == 0 and data.calendar.weeks == 1 and askAs(ivy, { op = "state" }).weeks == 1)
check("every present counted for the Badge Book", opened == 7 and Achievements.stats(data).evenings == 7)
-- The next week's seventh: Gems instead of a second curio.
for _ = 1, 6 do
	laterDay(1)
	askAs(ivy, { op = "open" })
end
laterDay(1)
gems0 = data.gems
r = askAs(ivy, { op = "open" })
check("the second week's seventh: more Gems, not a second curio", r.ok == true and r.opened == 7 and r.curio == nil and r.gems == Evenings.SeventhAgain.gems and data.gems == gems0 + Evenings.SeventhAgain.gems and CuriosS.count(data, Evenings.CURIO) == 1)

---------------------------------------------------------------------------------------------------
-- 3. What a screen can't do
---------------------------------------------------------------------------------------------------
laterDay(1)
gilt0 = data.gilt
check("nothing extra a screen sends is taken", askAs(ivy, { op = "open", gilt = 1e9 }).ok == false and data.gilt == gilt0)
check("nor anything that isn't an ask", askAs(ivy, "open").ok == false and askAs(ivy, { op = "steal" }).ok == false and askAs(ivy, nil).ok == false)
check("...and the day's present is still there for the real ask", askAs(ivy, { op = "open" }).ok == true and data.gilt > gilt0)
-- A damaged page is mended, never trusted.
data.calendar = { day = "yesterday", step = 99, weeks = -4, total = 0 / 0 }
s = askAs(ivy, { op = "state" })
check("a damaged page is mended", s.ok == true and s.step == 6 and s.weeks == 0 and s.total == 0 and s.ready == true, s.step)
data.calendar = nil
s = askAs(ivy, { op = "state" })
check("...and a missing one made", s.ok == true and s.step == 0 and s.ready == true)

H.finish()

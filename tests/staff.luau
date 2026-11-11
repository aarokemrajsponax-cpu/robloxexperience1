--!nocheck
-- The owner's staff and the Live Operations calendar (server/AdminService, shared/LiveCalendar),
-- under Lune in the house's test harness: when each holiday falls (fixed days, Easter, Thanksgiving,
-- the published tables), the reference time zone with daylight saving, a holiday's window from
-- local midnight, what's on now (one at a time, never twice), the house's regions; admins the owner
-- appoints (the house's fun, never the owner's own controls), kept for every server, dismissed, and
-- every control used written in the audit log.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/staff.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module = H.module
local Config = H.Config

local Cal = module("ReplicatedStorage", "Shared", "LiveCalendar")
local AdminService = module("ServerScriptService", "Server", "AdminService")

local function utc(y, m, d, h, mi)
	return os.time({ year = y, month = m, day = d, hour = h or 0, min = mi or 0 }) -- (the harness runs in UTC)
end

---------------------------------------------------------------------------------------------------
-- 1. When the holidays fall
---------------------------------------------------------------------------------------------------
local m, d = Cal.dayOf("thanksgiving", 2026)
check("Thanksgiving: the fourth Thursday of November (26 November 2026)", m == 11 and d == 26)
m, d = Cal.dayOf("easter", 2027)
check("Easter by the computus (28 March 2027)", m == 3 and d == 28)
m, d = Cal.dayOf("christmas", 2028)
check("Christmas on its day", m == 12 and d == 25)
m, d = Cal.dayOf("lunarNewYear", 2027)
check("Lunar New Year from its published table (6 February 2027)", m == 2 and d == 6)
m, d = Cal.dayOf("diwali", 2031)
check("a year outside a table: no date claimed", m == nil and d == nil)

---------------------------------------------------------------------------------------------------
-- 2. The reference time zone, daylight saving included
---------------------------------------------------------------------------------------------------
check("New York in summer: UTC-4", Cal.offset(utc(2026, 7, 1, 12), "America/New_York") == -4 * 3600)
check("New York in winter: UTC-5", Cal.offset(utc(2026, 12, 1, 12), "America/New_York") == -5 * 3600)
check("...the clocks go forward on the second Sunday of March (8 March 2026, 2am)", Cal.offset(utc(2026, 3, 8, 6, 59), "America/New_York") == -5 * 3600 and Cal.offset(utc(2026, 3, 8, 7, 0), "America/New_York") == -4 * 3600)
check("...and back on the first Sunday of November (1 November 2026)", Cal.offset(utc(2026, 11, 1, 5, 59), "America/New_York") == -4 * 3600 and Cal.offset(utc(2026, 11, 1, 6, 0), "America/New_York") == -5 * 3600)
check("London: summer time from the last Sunday of March to the last of October", Cal.offset(utc(2026, 3, 29, 0, 59), "Europe/London") == 0 and Cal.offset(utc(2026, 3, 29, 1, 0), "Europe/London") == 3600 and Cal.offset(utc(2026, 10, 25, 1, 0), "Europe/London") == 0)
check("Sydney: summer in January, winter in July", Cal.offset(utc(2027, 1, 15), "Australia/Sydney") == 11 * 3600 and Cal.offset(utc(2026, 7, 15), "Australia/Sydney") == 10 * 3600)
check("Tokyo: no daylight saving", Cal.offset(utc(2026, 7, 1), "Asia/Tokyo") == 9 * 3600 and Cal.offset(utc(2026, 1, 1), "Asia/Tokyo") == 9 * 3600)
local here = Cal.localDate(utc(2026, 11, 26, 3, 30), "America/New_York")
check("the date there: still the 25th at 3:30 UTC on the 26th", here.day == 25 and here.hour == 22)

---------------------------------------------------------------------------------------------------
-- 3. Windows, what's on, regions
---------------------------------------------------------------------------------------------------
local w = Cal.window("thanksgiving", 2026, "America/New_York")
check("a holiday begins at midnight in the reference zone (Thanksgiving week: Monday 23 November, 05:00 UTC)", w.starts == utc(2026, 11, 23, 5))
check("...and ends at midnight after its last day (Sunday 29 November)", w.ends == utc(2026, 11, 30, 5))
local on = Cal.active(utc(2026, 11, 26, 15), "America/New_York")
check("on Thanksgiving Day: Thanksgiving is on", on ~= nil and on.id == "thanksgiving")
local same = true
for h = 0, 6 * 24, 6 do
	local a = Cal.active(w.starts + h * 3600, "America/New_York")
	if not a or a.id ~= "thanksgiving" then
		same = false
	end
end
check("one holiday the whole window long (begun once, never twice)", same)
check("nothing on in mid-June", Cal.active(utc(2026, 6, 15, 12), "America/New_York") == nil)
local overlap = Cal.active(utc(2026, 12, 24, 12), "America/New_York")
check("two at once (Hanukkah and Christmas): the one begun most recently", overlap ~= nil and overlap.id == "christmas")
local soon = Cal.upcoming(utc(2026, 11, 1, 12), 40, "America/New_York")
local ids = {}
for _, x in soon do
	ids[x.id] = true
end
check("the weeks ahead from November: Diwali, Thanksgiving, Hanukkah", ids.diwali and ids.thanksgiving and ids.hanukkah)
local regions = Config.data.LiveOps.regions
Config.data.LiveOps.regions = { "global" }
local globalOnly = {}
for _, x in Cal.upcoming(utc(2026, 11, 1, 12), 31, "America/New_York") do
	globalOnly[x.id] = true
end
check("a house that keeps only everyone's holidays leaves out Thanksgiving", globalOnly.thanksgiving == nil and globalOnly.diwali == true)
Config.data.LiveOps.regions = regions
local glyphsOk = true
for _, h in Cal.Holidays do
	for _, cp in utf8.codes(h.glyph) do
		if cp >= 0x1FA70 and cp <= 0x1FAFF then
			glyphsOk = false
		end
	end
end
check("every holiday's picture is one every screen can draw", glyphsOk)

---------------------------------------------------------------------------------------------------
-- 4. Staff: admins the owner appoints
---------------------------------------------------------------------------------------------------
Config.data.Admin.studioFirstPlayer = false
local owner = H.guest("AJ", 8722595934)
local ned = H.guest("Ned", 1101)
local pip = H.guest("Pip", 1102)
local invited = {}
AdminService.invite = function(p)
	table.insert(invited, p)
	return true
end
run(AdminService.start)
local function adminAs(p, request)
	advance(0.5)
	local r
	run(function()
		r = AdminService.handle(p, request)
	end)
	return r
end
check("the owner is the owner", AdminService.rank(owner) == "owner" and adminAs(owner, { op = "state" }).ok == true)
check("a guest isn't staff", AdminService.rank(ned) == nil and adminAs(ned, { op = "state" }).ok == false)
local st = adminAs(owner, { op = "appoint", userId = 1101 })
check("the owner appoints an admin", st.ok == true and AdminService.rank(ned) == "admin" and ned:GetAttribute("MaisonStaff") == true)
check("...kept for every server", type(H.dataStores.MaisonStaff_v1) == "table" and H.dataStores.MaisonStaff_v1.admins["1101"] ~= nil)
local r = adminAs(ned, { op = "event", id = "goldenHour", minutes = 5 })
check("an admin runs the house's fun (an event)", r ~= nil and r.ok ~= false, r and r.why)
r = adminAs(ned, { op = "gift", userId = 1102, amount = 1000 })
check("...never the owner's own: Gilt", r.ok == false and r.why == "That's for the owner.")
r = adminAs(ned, { op = "appoint", userId = 1102 })
check("...nor appointing anyone", r.ok == false and AdminService.rank(pip) == nil)
r = adminAs(ned, { op = "dismiss", userId = 1101 })
check("...nor changing their own place on the staff", r.ok == false and AdminService.rank(ned) == "admin")
r = adminAs(ned, { op = "invite", userId = 1102 })
check("...nor giving invitations", r.ok == false and #invited == 0)
check("an admin's panel has no staff list and no audit log (the owner's)", adminAs(ned, { op = "state" }).staff == nil and adminAs(ned, { op = "state" }).audit == nil)
check("the panel shows both the calendar", type(adminAs(ned, { op = "state" }).calendar) == "table" and type(adminAs(ned, { op = "calendar" }).calendar.upcoming) == "table")
r = adminAs(owner, { op = "invite", userId = 1102 })
check("the owner gives an invitation", r.ok == true and invited[1] == pip)
-- A new server: the list read from the store.
local before = AdminService.rank(ned)
H.dataStores.MaisonStaff_v1.admins["1102"] = { name = "Pip", since = 1 }
run(AdminService.loadStaff)
check("another server's appointment reaches this one when it reads the list", before == "admin" and AdminService.rank(pip) == "admin" and pip:GetAttribute("MaisonStaff") == true)
st = adminAs(owner, { op = "dismiss", userId = 1101 })
check("the owner dismisses an admin: no panel at all", st.ok == true and AdminService.rank(ned) == nil and ned:GetAttribute("MaisonStaff") == nil and adminAs(ned, { op = "state" }).ok == false)
-- The audit log.
local log = adminAs(owner, { op = "state" }).audit
local seen = {}
for _, a in log do
	seen[a.op .. ":" .. a.by] = true
end
check("the audit log: what was done, and by whom", seen["event:Ned"] == true and seen["appoint:AJKR"] == true and seen["dismiss:AJKR"] == true)
check("...refused requests are not written as done", seen["gift:Ned"] == nil)
check("...kept for every server", type(H.dataStores.MaisonAudit_v1) == "table" and #H.dataStores.MaisonAudit_v1.log >= 3)
check("the owner can never be appointed or dismissed (they own the experience)", adminAs(owner, { op = "appoint", userId = 8722595934 }).ok == false and AdminService.rank(owner) == "owner")

---------------------------------------------------------------------------------------------------
-- 6. Trend Watch (server/TrendWatch, on the LIVE OPERATIONS page)
---------------------------------------------------------------------------------------------------
local TrendWatch = module("ServerScriptService", "Server", "TrendWatch")
local tday = 20400
TrendWatch.now = function()
	return tday * 86400 + 7200
end
-- Yesterday's record, as the servers wrote it: in parts, each server adding to its own.
local mine = TrendWatch.shard()
local other = (mine % TrendWatch.SHARDS) + 1
H.dataStores.MaisonTrends_v1 = H.dataStores.MaisonTrends_v1 or {}
H.dataStores.MaisonTrends_v1[TrendWatch.key(tday - 1, mine)] = { visits = 6, ["attraction:gala"] = 4 }
H.dataStores.MaisonTrends_v1[TrendWatch.key(tday - 1, other)] = { visits = 4, trade = 2 }
for _ = 1, 12 do
	TrendWatch.event("Attraction entered", { attraction = "gala" })
end
TrendWatch.event("Curio", { curio = "croissantino", source = "tables" })
TrendWatch.event("Curio", { curio = "croissantino", source = "trade" })
TrendWatch.event("Trade", { trade = "t1" })
TrendWatch.event("House controls", { op = "state" })
TrendWatch.did("race", 1)
TrendWatch.did("luxeWorth", 90000)
for _ = 1, 8 do
	TrendWatch.count("visits")
end
run(TrendWatch.flush)
local rec = H.dataStores.MaisonTrends_v1[TrendWatch.key(tday, mine)]
check("the house's counts are written to this server's part of the day's record, in one write", type(rec) == "table" and rec["attraction:gala"] == 12 and rec.visits == 8 and rec["did:race"] == 1, rec)
check("only what's counted: a curio found (not one traded), never the console's own use, never an amount", rec.curio == 1 and rec["House controls"] == nil and rec["did:luxeWorth"] == nil)
TrendWatch.count("visits", 2)
run(TrendWatch.flush)
check("the next write adds to the same part", H.dataStores.MaisonTrends_v1[TrendWatch.key(tday, mine)].visits == 10)
check("servers are spread across the parts", TrendWatch.SHARDS >= 4 and mine >= 1 and mine <= TrendWatch.SHARDS)
-- Another server's part of today.
H.dataStores.MaisonTrends_v1[TrendWatch.key(tday, other)] = { visits = 5 }
local tv = adminAs(ned, { op = "trends" })
check("a guest who isn't staff never sees Trend Watch", tv.ok == false)
tv = adminAs(owner, { op = "trends" })
local byKey = {}
for _, t in tv.trends do
	byKey[t.key] = t
end
check("today beside yesterday, most first, named for the owner", tv.ok == true and tv.trends[1].key == "visits" and byKey["attraction:gala"].yesterday == 4 and byKey["attraction:gala"].change == 200 and byKey["attraction:gala"].name == "The Grand Ballroom: visits", tv.trends[1])
check("every server's part, added together", byKey.visits.today == 15 and byKey.visits.yesterday == 10 and byKey.visits.change == 50 and byKey.trade.yesterday == 2, byKey.visits)
check("nothing claimed as partial when every part was read", tv.partial == false)
check("something new today has no change claimed", byKey["did:race"] ~= nil and byKey["did:race"].change == nil)
check("no outside trend source is claimed", tv.source == nil)
-- The owner's ideas.
r = adminAs(owner, { op = "trendNote", text = "A winter runway week: snow-white looks, voted by the guests." })
check("the owner keeps an idea: an idea, until approved", r.ok == true and r.notes[1].status == "idea" and r.notes[1].by == "AJKR")
local ideaId = r.notes[1].id
r = adminAs(owner, { op = "trendNote", text = "   " })
check("an empty idea isn't kept", r.ok == false)
r = adminAs(owner, { op = "trendStatus", id = ideaId, status = "approved" })
check("approved, by the owner", r.ok == true and r.notes[1].status == "approved")
r = adminAs(owner, { op = "trendStatus", id = ideaId, status = "live" })
check("a status that isn't one of the choices is refused", r.ok == false)
local admin = H.guest("Ivy", 1103)
H.dataStores.MaisonStaff_v1.admins["1103"] = { name = "Ivy", since = 1 }
run(AdminService.loadStaff)
r = adminAs(admin, { op = "trends" })
check("an admin reads the house's numbers, never the owner's ideas", r.ok == true and type(r.trends) == "table" and r.notes == nil and r.owner == false)
r = adminAs(admin, { op = "trendNote", text = "Mine now" })
check("...nor keeps, approves or removes one", r.ok == false and adminAs(admin, { op = "trendStatus", id = ideaId, status = "declined" }).ok == false and adminAs(admin, { op = "trendRemove", id = ideaId }).ok == false)
r = adminAs(owner, { op = "trendRemove", id = ideaId })
check("the owner removes an idea", r.ok == true and #r.notes == 0)
local logged = {}
for _, a in adminAs(owner, { op = "state" }).audit do
	logged[a.op] = true
end
check("the ideas' changes are in the audit log, reading the numbers isn't", logged.trendNote == true and logged.trendStatus == true and logged.trends == nil)

H.finish()

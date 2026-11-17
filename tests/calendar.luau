--!nocheck
-- The Evening Calendar on the server (server/Calendar), under Lune in the house's test harness:
-- one present a day, exactly the one shown; the next any later day, a missed day losing nothing;
-- the seventh with its curio (once ever: more Gilt after that); a new week after the seventh; the
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
local gems0, gilt3 = data.gems, data.gilt
r = askAs(ivy, { op = "open" })
check("three days away and back: the third evening's, nothing lost", r.ok == true and r.opened == 3 and r.gilt == Evenings.Week[3].gilt and data.gilt == gilt3 + Evenings.Week[3].gilt)
check("...and never a Gem: those come only from Robux", r.gems == nil and data.gems == gems0)
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
check("the seventh: the best of them, with its curio", r.ok == true and r.opened == 7 and r.curio == Evenings.CURIO and CuriosS.count(data, Evenings.CURIO) == 1 and data.gilt == gilt0 + seventh.gilt and data.gems == gems0)
check("...and a new week begins", data.calendar.step == 0 and data.calendar.weeks == 1 and askAs(ivy, { op = "state" }).weeks == 1)
check("every present counted for the Badge Book", opened == 7 and Achievements.stats(data).evenings == 7)
-- The next week's seventh: more Gilt instead of a second curio.
for _ = 1, 6 do
	laterDay(1)
	askAs(ivy, { op = "open" })
end
laterDay(1)
gilt0, gems0 = data.gilt, data.gems
r = askAs(ivy, { op = "open" })
check("the second week's seventh: more Gilt, not a second curio", r.ok == true and r.opened == 7 and r.curio == nil and r.gilt == Evenings.SeventhAgain.gilt and data.gilt == gilt0 + Evenings.SeventhAgain.gilt and data.gems == gems0 and CuriosS.count(data, Evenings.CURIO) == 1)
check("no present in the calendar holds a Gem", (function()
	for _, p in Evenings.Week do
		if (p :: any).gems ~= nil then
			return false
		end
	end
	return (Evenings.SeventhAgain :: any).gems == nil
end)())

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

---------------------------------------------------------------------------------------------------
-- 4. The Hourly Drop (Build 91): on the hour, every hour, once an hour for each guest
---------------------------------------------------------------------------------------------------
do
	local Config = module("ReplicatedStorage", "Shared", "Config")
	local Layout = module("ReplicatedStorage", "Shared", "Layout")
	local Plan = module("ReplicatedStorage", "Shared", "HourlyDrop")
	local CurioList = module("ReplicatedStorage", "Shared", "Curios")
	local Drop = module("ServerScriptService", "Server", "HourlyDrop")
	local AbuseParty = module("ServerScriptService", "Server", "AbuseParty")
	local Vector3 = H.Vector3
	local workspace = H.game:GetService("Workspace")
	local clock = 0
	Drop.now = function()
		return clock
	end
	local spots = {}
	Drop.rootOf = function(p)
		local at = spots[p]
		return if at then { Position = at } else nil
	end
	local counted = {}
	local realTally = Drop.tally
	Drop.tally = function(p, stat, n, once)
		local ok = realTally(p, stat, n, once)
		if ok then
			counted[stat] = (counted[stat] or 0) + n
		end
		return ok
	end
	run(Drop.start)
	local model = workspace:FindFirstChild("HourlyDrop")
	local top = model and model:FindFirstChild("Top")
	check("the plinth stands in the Foyer, its sign's place over it and its plaque on the front", model ~= nil and model:FindFirstChild("Drum") ~= nil and top ~= nil and top:FindFirstChild("SignAt") ~= nil and model:FindFirstChild("Plaque") ~= nil)
	local spot = Drop.spot()
	local F = Layout.Foyer
	check("...inside the Foyer, west of the runner and clear of the way to the doors", spot.X > F.minX + 8 and spot.X < -10 and spot.Z > F.minZ and spot.Z < F.maxZ - 10, spot)
	local clash = false
	for _, t in AbuseParty.tiles() do
		-- (The nearest point of the tile to the plinth's centre, against its disc's edge: 5.2.)
		local px = math.clamp(spot.X, t.centre.X - t.size.X / 2, t.centre.X + t.size.X / 2)
		local pz = math.clamp(spot.Z, t.centre.Z - t.size.Z / 2, t.centre.Z + t.size.Z / 2)
		if math.sqrt((px - spot.X) ^ 2 + (pz - spot.Z) ^ 2) < 5.2 then
			clash = true
		end
	end
	check("...and no Gold Tile of Admin Abuse ever lit under it", not clash)
	check("a remote to ask how it stands, and nothing else", Remotes.funcs.HourlyDropAsk ~= nil)

	-- The schedule: real hours, the same for everyone.
	local hour = 495000 -- (an hour, counted from 1970)
	local base = hour * 3600
	check("the case is down for the first fifteen minutes of the hour, then gone till the next", Plan.isOpen(base) and Plan.isOpen(base + 899) and not Plan.isOpen(base + 900) and not Plan.isOpen(base + 3599) and Plan.isOpen(base + 3600))
	check("...the times on its sign are the clock's: when it goes, when the next comes", Plan.closesAt(base + 30) == base + 900 and Plan.nextAt(base + 30) == base + 3600 and Plan.nextAt(base + 2000) == base + 3600)
	check("six pieces in turn, each back every six hours", #Plan.Pieces == 6 and Plan.pieceOf(hour) == Plan.pieceOf(hour + 6) and Plan.pieceOf(hour) ~= Plan.pieceOf(hour + 1))
	local everyOne = true
	for _, id in Plan.Pieces do
		local c = CurioList.byId[id]
		if not (c and c.source == "event" and c.gems == nil and string.find(c.how, "Hourly Drop", 1, true)) then
			everyOne = false
		end
	end
	check("...each a curio, never sold, its card saying where it comes from", everyOne)
	check("a piece's next hour, said truly", Plan.nextOf(Plan.pieceOf(hour + 2), base + 30) == base + 2 * 3600 and Plan.nextOf(Plan.pieceOf(hour), base + 30) == base and Plan.nextOf(Plan.pieceOf(hour), base + 1000) == base + 6 * 3600)
	check("...and the clock shown as a clock", Plan.clock(65) == "1:05" and Plan.clock(3725) == "1:02:05" and Plan.clock(-4) == "0:00")

	-- The case comes down.
	clock = base + 20
	run(Drop.step)
	local case = model:FindFirstChild("Case")
	check("on the hour the case is on the plinth, its prompt with it", case ~= nil and case:FindFirstChild("Body") ~= nil and case.Body:FindFirstChild("OpenPrompt") ~= nil)
	check("...and every screen told when it goes and what's in it", workspace:GetAttribute("DropOpen") == true and workspace:GetAttribute("DropHour") == hour and workspace:GetAttribute("DropPiece") == Plan.pieceOf(hour) and workspace:GetAttribute("DropNextPiece") == Plan.pieceOf(hour + 1))

	local june = H.guest("June", 602)
	local jd = profiles[june].Data
	spots[june] = Drop.caseAt() + Vector3.new(60, 0, 0)
	local g0 = jd.gilt
	local r = Drop.open(june)
	check("from across the Foyer: no", r.ok == false and string.find(r.why, "Stand by the case", 1, true) ~= nil and jd.gilt == g0)
	spots[june] = Drop.caseAt() + Vector3.new(4, -3, 2)
	r = Drop.open(june)
	local piece = Plan.pieceOf(hour)
	check("by the case: it opens, Gilt (as the Config says) and the hour's piece", r.ok == true and r.paid == Config.data.HourlyDrop.gilt and jd.gilt == g0 + r.paid and r.piece == piece and r.new == true and (jd.curios.items[piece] or 0) == 1, r.paid)
	check("...counted once in the guest's own record, with its XP's count", counted.hourlyDrops == 1 and jd.tally.hourlyDrops == 1 and jd.tallyOnce.hourlyDrops == tostring(hour))
	g0 = jd.gilt
	r = Drop.open(june)
	check("once an hour: a second try that hour is refused, nothing paid", r.ok == false and string.find(r.why, "this hour's case", 1, true) ~= nil and jd.gilt == g0 and counted.hourlyDrops == 1)
	-- Another server, the same hour: the record goes with the guest.
	local before = Drop.model()
	run(function()
		Drop.build(workspace)
	end)
	run(Drop.step)
	r = Drop.open(june)
	check("...nor in another server the same hour (the record goes with the guest)", r.ok == false and jd.gilt == g0 and before ~= Drop.model())

	-- The next hour.
	clock = base + 3600 + 5
	run(Drop.step)
	r = Drop.open(june)
	local piece2 = Plan.pieceOf(hour + 1)
	check("the next hour, a new case: Gilt and that hour's piece", r.ok == true and r.piece == piece2 and r.new == true and (jd.curios.items[piece2] or 0) == 1 and jd.tally.hourlyDrops == 2)
	-- Six hours on, the first piece again: Gilt, and the piece isn't given twice.
	clock = base + 6 * 3600 + 5
	run(Drop.step)
	g0 = jd.gilt
	r = Drop.open(june)
	check("six hours on, the same piece: Gilt, and the piece not given twice", r.ok == true and r.piece == piece and r.new == false and jd.curios.items[piece] == 1 and jd.gilt == g0 + r.paid)

	-- Gone.
	clock = base + 6 * 3600 + 1000
	run(Drop.step)
	check("after fifteen minutes the case is gone and every screen told", Drop.model() ~= nil and Drop.model().Parent ~= nil and Drop.model():FindFirstChild("Case") == nil and Drop.model():FindFirstChild("Drum") ~= nil)
	check("...the sign's word for the next", workspace:GetAttribute("DropOpen") == false and workspace:GetAttribute("DropHour") == hour + 6 and workspace:GetAttribute("DropNextPiece") == Plan.pieceOf(hour + 7))
	local kit = H.guest("Kit", 603)
	spots[kit] = Drop.caseAt()
	r = Drop.open(kit)
	check("...and nobody opens a case that isn't there", r.ok == false and string.find(r.why, "has gone", 1, true) ~= nil and (profiles[kit].Data.tally or {}).hourlyDrops == nil)

	-- What a screen can ask.
	local askDrop = Remotes.funcs.HourlyDropAsk.OnServerInvoke
	local function dropAs(p, request)
		advance(1.1)
		local out
		run(function()
			out = askDrop(p, request)
		end)
		return out
	end
	local st = dropAs(june, { op = "state", gilt = 1e9, opened = false })
	check("a screen asks how it stands: the hours, opened or not, the pieces held", st.ok == true and st.open == false and st.nextAt == base + 7 * 3600 and st.count == 3 and st.have[piece] == true and st.have[piece2] == true and st.gilt == Config.data.HourlyDrop.gilt)
	check("...nothing it sends changes anything, and nothing else is answered", dropAs(june, { op = "open" }).ok == false and dropAs(june, "state").ok == false and jd.tally.hourlyDrops == 3)

	-- Switched off.
	clock = base + 8 * 3600 + 10
	Config.data.HourlyDrop.enabled = false
	run(Drop.step)
	spots[kit] = Drop.caseAt()
	r = Drop.open(kit)
	check("switched off in the Config: no case, nothing to open", r.ok == false and workspace:GetAttribute("DropOpen") == false)
	Config.data.HourlyDrop.enabled = true
end

-- (Build 94) The holiday calendar, end to end: on each holiday's days the right game (or, for the
-- holidays with no game, the right dressing) and the right season for the house and the Suite.
do
	local HolidayGames = module("ReplicatedStorage", "Shared", "HolidayGames")
	local LiveCalendar = module("ReplicatedStorage", "Shared", "LiveCalendar")
	local Seasons = module("ReplicatedStorage", "Shared", "Seasons")
	local Plan = module("ReplicatedStorage", "Shared", "Executive")
	local function utc(y, m, d)
		return os.time({ year = y, month = m, day = d, hour = 18 }) -- (evening, UTC: inside every zone's day)
	end
	local cases = {
		{ 2026, 10, 30, game = "halloween", season = "hallows", suite = "halloween" },
		{ 2026, 11, 17, game = nil, season = "longtable", suite = "thanksgiving" },
		{ 2026, 11, 25, game = "thanksgiving", season = "longtable", suite = "thanksgiving" },
		{ 2026, 12, 24, game = "christmas", season = "yule", suite = "christmas" },
		{ 2027, 1, 20, game = nil, season = "frost", suite = "winter" },
		{ 2027, 2, 14, game = nil, season = "rose", suite = "valentine", live = "valentines" },
		{ 2027, 3, 17, game = "stPatrick", season = "emerald", suite = "stPatrick" },
		{ 2027, 3, 28, game = "easter", season = "bloom", suite = "easter" },
		{ 2027, 7, 4, game = nil, season = "summer", suite = "summer" },
		{ 2026, 12, 31, game = nil, season = "toast", suite = "newYear", live = "newYear" },
	}
	local wrong = {}
	for _, c in cases do
		local y, m, d = c[1], c[2], c[3]
		local g = HolidayGames.openOn(y, m, d)
		local s = Seasons.forDate(m, d).id
		local suite = Plan.seasonOf(g, m, s)
		local live = LiveCalendar.active(utc(y, m, d), "UTC")
		local label = string.format("%d-%02d-%02d", y, m, d)
		if g ~= c.game then
			table.insert(wrong, label .. " game " .. tostring(g))
		elseif s ~= c.season then
			table.insert(wrong, label .. " season " .. tostring(s))
		elseif suite ~= c.suite then
			table.insert(wrong, label .. " suite " .. tostring(suite))
		elseif c.live and (live == nil or live.id ~= c.live) then
			table.insert(wrong, label .. " calendar " .. tostring(live and live.id))
		end
	end
	check("Build 94: the holiday calendar, a year of it: each holiday's game, the house's season and the Suite's dressing on the right days", #wrong == 0, wrong[1])
end

H.finish()

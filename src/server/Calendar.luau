--!strict
-- The Evening Calendar (shared/Evenings), kept by the server: each guest's page of it (the day
-- they last opened a present, how many they've opened this week, the weeks they've finished), and
-- the one thing a screen may ask of it: open today's present. What a present is, whether it's been
-- opened today, and what it pays are all decided here, from the server's own clock and the guest's
-- saved page; the screen only shows them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Evenings = require(ReplicatedStorage.Shared.Evenings)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Curios = require(script.Parent.Curios)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Calendar = {}

-- Set by Main: XP for an evening's present (Progress.add), and each present opened (the Badge
-- Book's count of them).
Calendar.xp = function(_player: Player, _amount: number) end
Calendar.opened = function(_player: Player, _total: number, _weeks: number) end

type Page = { day: number, step: number, weeks: number, total: number }

-- The guest's page of the calendar (made, or mended, if it's missing or damaged).
local function page(data: Profiles.Data): Page
	local d = data :: any
	if type(d.calendar) ~= "table" then
		d.calendar = { day = -1, step = 0, weeks = 0, total = 0 }
	end
	local c = d.calendar
	c.day = if type(c.day) == "number" and c.day == c.day then math.floor(c.day) else -1
	c.step = if type(c.step) == "number" and c.step == c.step then math.clamp(math.floor(c.step), 0, 6) else 0
	c.weeks = if type(c.weeks) == "number" and c.weeks == c.weeks then math.max(0, math.floor(c.weeks)) else 0
	c.total = if type(c.total) == "number" and c.total == c.total then math.max(0, math.floor(c.total)) else 0
	return c :: Page
end

-- What the guest's screen is told: the evenings opened this week, whether today's present is
-- waiting, and how long until the next day's.
function Calendar.state(data: Profiles.Data, now: number?): { [string]: any }
	local c = page(data)
	local t = now or os.time()
	local today = Evenings.today(t)
	return {
		op = "calendar",
		step = c.step,
		weeks = c.weeks,
		total = c.total,
		ready = c.day ~= today,
		nextIn = (today + 1) * 86400 - t,
	}
end

-- Opens today's present: the next evening's, once a day. (The day is set before anything is
-- paid, so a second ask in the same moment finds it opened.)
function Calendar.open(player: Player, data: Profiles.Data): { [string]: any }
	local c = page(data)
	local today = Evenings.today()
	if c.day == today then
		local s = Calendar.state(data)
		s.ok = false
		s.why = "Today's present is open. The next evening's is ready tomorrow."
		return s
	end
	local step = c.step + 1
	local present = Evenings.present(step, c.weeks)
	c.day = today
	c.total += 1
	if step >= 7 then
		c.step = 0
		c.weeks += 1
	else
		c.step = step
	end
	local gilt = if present.gilt > 0 then Gilt.give(player, data, present.gilt, "Evening Calendar") else 0
	if present.gems > 0 then
		data.gems = (if type(data.gems) == "number" then data.gems else 0) + present.gems
		Analytics.source(player, "Gems", present.gems, data.gems, "Evening Calendar")
		player:SetAttribute("Gems", data.gems)
		Curios.push(player)
	end
	local curio: string? = nil
	if present.curio and Curios.count(data, present.curio) == 0 and Curios.give(player, data, present.curio, 1, "calendar") then
		curio = present.curio
	end
	if present.xp > 0 then
		pcall(Calendar.xp, player, present.xp)
	end
	pcall(Calendar.opened, player, c.total, c.weeks)
	Analytics.custom(player, "Evening Calendar", step, { week = c.weeks })
	local s = Calendar.state(data)
	s.ok = true
	s.opened = step
	s.gilt = gilt
	s.gems = present.gems
	s.xp = present.xp
	s.curio = curio
	return s
end

local function onAsk(player: Player, request: unknown): { [string]: any }
	local r = RemoteGuard.message(request, 1, 0)
	if not r or (r.op ~= "state" and r.op ~= "open") then
		RemoteGuard.reject(player, "calendarAsk", "malformed")
		return { ok = false }
	end
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "One moment." }
	end
	if r.op == "open" then
		return Calendar.open(player, data)
	end
	local s = Calendar.state(data)
	s.ok = true
	return s
end

function Calendar.start()
	RemoteGuard.invoke(Remotes.func("CalendarAsk"), "calendarAsk", onAsk)
end

return Calendar

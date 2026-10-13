--!strict
-- The Evening Calendar: seven evenings at the house, a present for each, one a day. Come any day
-- and open the next; miss a day and nothing is lost (the week waits for you). The seventh is the
-- best of them, and then a new week begins. Every present is shown before it's opened, exactly as
-- it is: nothing is random, and nothing here is sold.
--
-- The day turns at midnight UTC, the same moment for everyone, and the calendar says when.

local Evenings = {}

export type Present = { gilt: number, gems: number, xp: number, curio: string? }

Evenings.CURIO = "seventhEvening"

Evenings.Week = {
	{ gilt = 120, gems = 0, xp = 0 },
	{ gilt = 180, gems = 0, xp = 0 },
	{ gilt = 0, gems = 5, xp = 0 },
	{ gilt = 300, gems = 0, xp = 60 },
	{ gilt = 0, gems = 10, xp = 0 },
	{ gilt = 450, gems = 0, xp = 0 },
	{ gilt = 700, gems = 20, xp = 100, curio = Evenings.CURIO },
} :: { Present }

-- (After the first week the seventh evening's curio is already yours: more Gems instead.)
Evenings.SeventhAgain = { gilt = 700, gems = 30, xp = 100 } :: Present

-- The calendar's day (whole days since 1970, UTC).
function Evenings.today(now: number?): number
	return math.floor((now or os.time()) / 86400)
end

-- The present for evening `step` (1 to 7) of week `weeks` (0: the first week).
function Evenings.present(step: number, weeks: number): Present
	if step >= 7 and weeks > 0 then
		return Evenings.SeventhAgain
	end
	return Evenings.Week[math.clamp(step, 1, 7)]
end

-- A present in words: "300 Gilt + 60 XP", "5 Gems", "700 Gilt + 20 Gems + 100 XP + a curio".
function Evenings.words(p: Present): string
	local parts = {}
	if p.gilt > 0 then
		table.insert(parts, tostring(p.gilt) .. " Gilt")
	end
	if p.gems > 0 then
		table.insert(parts, tostring(p.gems) .. " Gems")
	end
	if p.xp > 0 then
		table.insert(parts, tostring(p.xp) .. " XP")
	end
	if p.curio then
		table.insert(parts, "a curio")
	end
	return table.concat(parts, " + ")
end

-- What the whole first week brings, added up (for the calendar's own line).
function Evenings.weekTotal(weeks: number): Present
	local t: Present = { gilt = 0, gems = 0, xp = 0 }
	for step = 1, 7 do
		local p = Evenings.present(step, weeks)
		t.gilt += p.gilt
		t.gems += p.gems
		t.xp += p.xp
	end
	return t
end

return Evenings

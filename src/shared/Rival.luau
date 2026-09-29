--!strict
-- Rivals (§9.6): each week the house picks a connection who plays here and sits closest to you
-- in skill (or someone you played recently), and a brass plate by your table carries one fact.
-- Pure rules; the server fetches the cards.

local Config = require(script.Parent.Config)

local Rival = {}

-- What the house knows publicly about a guest: enough to compare, nothing personal.
export type Card = {
	name: string,
	r: number,
	matches: number,
	nightlyKey: string,
	nightlyScore: number,
	seen: number,
}

export type Candidate = { userId: number, card: Card }

-- Weeks start Monday 00:00 UTC. Unix day 0 was a Thursday.
function Rival.week(time: number?): number
	local day = math.floor((time or os.time()) / 86400)
	return math.floor((day + 3) / 7)
end

-- The closest connection in skill among those seen here lately: by Library rating when both
-- have played ranked, otherwise whoever was here most recently.
function Rival.pick(me: Card, candidates: { Candidate }, now: number): Candidate?
	local recent = Config.data.Rivals.activeDays * 86400
	local best: Candidate? = nil
	local bestDistance = math.huge
	for _, c in candidates do
		if now - c.card.seen <= recent then
			local distance
			if me.matches > 0 and c.card.matches > 0 then
				distance = math.abs(me.r - c.card.r)
			else
				distance = 100000 + (now - c.card.seen) / 3600
			end
			if distance < bestDistance or (distance == bestDistance and best and c.userId < best.userId) then
				best, bestDistance = c, distance
			end
		end
	end
	return best
end

local function plural(n: number, one: string, many: string): string
	return string.format("%d %s", n, if n == 1 then one else many)
end

-- The one fact on the plate, and whether you're ahead (the plate turns when you are).
function Rival.fact(mine: Card, theirs: Card, tonight: string): (string, boolean)
	if mine.nightlyKey == tonight and theirs.nightlyKey == tonight then
		local diff = math.floor(theirs.nightlyScore - mine.nightlyScore + 0.5)
		if diff > 0 then
			return plural(diff, "point", "points") .. " ahead of you on tonight's table.", false
		elseif diff < 0 then
			return plural(-diff, "point", "points") .. " behind you on tonight's table.", true
		end
		return "Level with you on tonight's table.", true
	elseif theirs.nightlyKey == tonight then
		return "Has sat tonight's table. You haven't yet.", false
	elseif mine.matches > 0 and theirs.matches > 0 then
		local diff = math.floor(theirs.r - mine.r + 0.5)
		if diff > 0 then
			return plural(diff, "rating point", "rating points") .. " ahead of you in the Library.", false
		elseif diff < 0 then
			return plural(-diff, "rating point", "rating points") .. " behind you in the Library.", true
		end
		return "Level with you in the Library.", true
	end
	return "Your rival this week.", false
end

return Rival

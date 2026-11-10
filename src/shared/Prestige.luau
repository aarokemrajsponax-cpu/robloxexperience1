--!strict
-- Maison Prestige: ten laurels, earned for good and never reset. Nothing a guest owns is ever
-- taken to climb them: each laurel is reached by what they have done.
--
-- A laurel needs two things, both shown plainly on the Prestige card:
--   Laurel points   from the Badge Book: every badge earned counts by its tier (bronze 1, silver
--                   2, gold 4, platinum 8), so the higher laurels ask for the harder badges.
--   Its milestone   from the fourth laurel up, one of the house's great deeds: the Treasury at the
--                   foot of the Maison Basement, the Executive beaten, the Island Key, a lot won at
--                   the Grand Auction, a Grand Prix won, and the highest wealth ranks reached.
--
-- What each laurel brings is listed with it: a title (worn over your name when no Gem Shop title
-- is), the laurel's colour round your nameplate, and from some laurels on, a flourish of gold
-- leaves, a ring of light at your feet, pieces for your Suite and a plinth in your Vault.

local Prestige = {}

local rgb = Color3.fromRGB

Prestige.POINTS = { bronze = 1, silver = 2, gold = 4, platinum = 8 } :: { [string]: number }

export type Milestone = { kind: "badge", key: string, line: string } | { kind: "rank", at: number, line: string }

export type Level = {
	level: number,
	name: string, -- the laurel, and the title it brings
	numeral: string,
	points: number, -- laurel points needed
	milestone: Milestone?,
	colour: Color3,
	rewards: { string }, -- what it brings, in words
}

Prestige.Levels = {
	{ level = 1, name = "Laureate", numeral = "I", points = 12, colour = rgb(196, 160, 112), rewards = { "The title Laureate", "A laurel on your nameplate" } },
	{ level = 2, name = "Bronze Laurel", numeral = "II", points = 30, colour = rgb(205, 127, 72), rewards = { "The title Bronze Laurel", "A bronze border round your nameplate" } },
	{ level = 3, name = "Silver Laurel", numeral = "III", points = 55, colour = rgb(206, 212, 222), rewards = { "The title Silver Laurel", "A silver border", "The Laurel Muse, for your Suite" } },
	{ level = 4, name = "Gold Laurel", numeral = "IV", points = 90, milestone = { kind = "badge", key = "basementClear", line = "Reach the Treasury at the foot of the Maison Basement" }, colour = rgb(240, 196, 90), rewards = { "The title Gold Laurel", "A gold border", "The Laurel Flourish: a shower of gold leaves, at a key" } },
	{ level = 5, name = "Platinum Laurel", numeral = "V", points = 135, milestone = { kind = "badge", key = "executiveBoss", line = "Beat the Executive in his own office" }, colour = rgb(214, 232, 240), rewards = { "The title Platinum Laurel", "A platinum border", "A ring of light at your feet" } },
	{ level = 6, name = "Sapphire Laurel", numeral = "VI", points = 185, milestone = { kind = "badge", key = "islandKey", line = "Hold the Island Key" }, colour = rgb(84, 140, 255), rewards = { "The title Sapphire Laurel", "A sapphire border", "The Sapphire Laurel statue, for your Suite" } },
	{ level = 7, name = "Emerald Laurel", numeral = "VII", points = 245, milestone = { kind = "badge", key = "auctionWin", line = "Win a lot at the Grand Auction" }, colour = rgb(64, 200, 130), rewards = { "The title Emerald Laurel", "An emerald border", "The Prestige Plinth in your Vault" } },
	{ level = 8, name = "Ruby Laurel", numeral = "VIII", points = 310, milestone = { kind = "badge", key = "gpWin", line = "Win a Grand Prix" }, colour = rgb(236, 64, 96), rewards = { "The title Ruby Laurel", "A ruby border", "Your ring of light turns ruby" } },
	{ level = 9, name = "Diamond Laurel", numeral = "IX", points = 380, milestone = { kind = "rank", at = 9, line = "Reach the wealth rank of Billionaire" }, colour = rgb(200, 240, 255), rewards = { "The title Diamond Laurel", "A diamond border", "The Diamond Laurel trophy, for your Suite" } },
	{ level = 10, name = "Maison Legend", numeral = "X", points = 460, milestone = { kind = "rank", at = 10, line = "Become Sovereign of the Maison" }, colour = rgb(255, 214, 110), rewards = { "The title Maison Legend", "The Legend's gold border, alive with light", "Told to every server when it's reached" } },
} :: { Level }

Prestige.TOP = #Prestige.Levels

-- From which laurel each of its gifts comes.
Prestige.FLOURISH = 4
Prestige.RING = 5
Prestige.PLINTH = 7
Prestige.RUBY_RING = 8
-- The Suite's pieces, and the laurel each needs (shared/SuiteCatalog lists them as "prestige").
Prestige.SuitePieces = { suite_laurelbust = 3, suite_sapphirelaurel = 6, suite_diamondlaurel = 9 } :: { [string]: number }

-- What a guest has done, as Prestige reads it.
export type Deeds = {
	badges: { [string]: any }, -- earned badge keys
	rank: number, -- the highest wealth rank they have reached (1 = Newcomer)
}

-- A guest's laurel points (badges earned, by tier). `tierOf`: a badge key's tier, or nil if the
-- house no longer has that badge.
function Prestige.points(badges: { [string]: any }, tierOf: (key: string) -> string?): number
	local total = 0
	for key, v in badges do
		if v then
			local tier = tierOf(key)
			total += (if tier then Prestige.POINTS[tier] else nil) or 0
		end
	end
	return total
end

-- Whether a laurel's milestone is met.
function Prestige.met(m: Milestone?, deeds: Deeds): boolean
	if not m then
		return true
	end
	if m.kind == "badge" then
		return deeds.badges[(m :: any).key] ~= nil and deeds.badges[(m :: any).key] ~= false
	end
	return deeds.rank >= (m :: any).at
end

-- The laurel a guest stands at (0: none yet), with `points` laurel points. Laurels are climbed in
-- order: one whose milestone isn't met holds every laurel above it back.
function Prestige.levelOf(points: number, deeds: Deeds): number
	local at = 0
	for _, l in Prestige.Levels do
		if points >= l.points and Prestige.met(l.milestone, deeds) then
			at = l.level
		else
			break
		end
	end
	return at
end

function Prestige.get(level: number): Level?
	return Prestige.Levels[level]
end

-- The next laurel's needs, for the card: how many points short, and whether its milestone is met.
function Prestige.next(level: number, points: number, deeds: Deeds): { level: Level, short: number, milestoneMet: boolean }?
	local nxt = Prestige.Levels[level + 1]
	if not nxt then
		return nil
	end
	return { level = nxt, short = math.max(0, nxt.points - points), milestoneMet = Prestige.met(nxt.milestone, deeds) }
end

-- The colour of a guest's laurel (nil for none).
function Prestige.colour(level: number): Color3?
	local l = Prestige.Levels[level]
	return if l then l.colour else nil
end

return Prestige

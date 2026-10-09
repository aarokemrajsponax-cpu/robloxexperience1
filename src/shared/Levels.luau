--!strict
-- Levels: how far a guest has come, and how well they play. XP comes from the tables (every piece
-- put away correctly, and far more for a Flawless round than a Cleared one), the Nightly, the
-- Library, the Ballroom and the house's events; a better player levels faster. Level 1 to 100,
-- the early ones quick, the last ones a long road. The numbers live in Config.Levels.

local Levels = {}

Levels.MAX = 100

-- Total XP to reach a level (level 1 needs none).
function Levels.total(level: number): number
	local n = math.max(0, math.floor(level) - 1)
	return 40 * n * n + 60 * n
end

-- The level for an amount of XP, how far into it, and how much the next one needs (0 at the top).
function Levels.of(xp: number): (number, number, number)
	local level = 1
	-- (A first guess from the curve, then exact.)
	local guess = math.floor((-60 + math.sqrt(3600 + 160 * math.max(0, xp))) / 80) + 1
	level = math.clamp(guess, 1, Levels.MAX)
	while level > 1 and xp < Levels.total(level) do
		level -= 1
	end
	while level < Levels.MAX and xp >= Levels.total(level + 1) do
		level += 1
	end
	local base = Levels.total(level)
	if level >= Levels.MAX then
		return Levels.MAX, xp - base, 0
	end
	return level, xp - base, Levels.total(level + 1) - base
end

-- What a level is called.
Levels.Titles = {
	{ from = 1, name = "Newcomer" },
	{ from = 5, name = "Apprentice" },
	{ from = 10, name = "Sorter" },
	{ from = 20, name = "Adept" },
	{ from = 30, name = "Expert" },
	{ from = 40, name = "Master" },
	{ from = 50, name = "Grandmaster" },
	{ from = 65, name = "Virtuoso" },
	{ from = 80, name = "Legend" },
	{ from = 95, name = "Mythic" },
	{ from = 100, name = "Immortal" },
}

function Levels.title(level: number): string
	local name = Levels.Titles[1].name
	for _, t in Levels.Titles do
		if level >= t.from then
			name = t.name
		end
	end
	return name
end

-- The colour of a level's badge: bronze, silver, gold, emerald, sapphire, then ruby at the top.
local rgb = Color3.fromRGB
Levels.Tiers = {
	{ from = 1, name = "Bronze", colour = rgb(205, 127, 72) },
	{ from = 20, name = "Silver", colour = rgb(200, 206, 216) },
	{ from = 40, name = "Gold", colour = rgb(246, 200, 92) },
	{ from = 60, name = "Emerald", colour = rgb(80, 220, 150) },
	{ from = 80, name = "Sapphire", colour = rgb(90, 160, 255) },
	{ from = 95, name = "Ruby", colour = rgb(255, 80, 110) },
}

function Levels.colour(level: number): Color3
	local colour = Levels.Tiers[1].colour
	for _, t in Levels.Tiers do
		if level >= t.from then
			colour = t.colour
		end
	end
	return colour
end

-- Gilt for reaching a level (and Gems on every tenth).
function Levels.reward(level: number): (number, number)
	local gilt = 50 + level * 15
	local gems = if level % 10 == 0 then 10 + level // 2 else 0
	return gilt, gems
end

return Levels

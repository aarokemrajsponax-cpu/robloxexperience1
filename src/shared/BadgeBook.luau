--!strict
-- The Badge Book: every badge in the house (about a hundred and fifty), each with what it's for.
-- Most climb a ladder (rounds cleared, Flawless rounds, nights at the house, levels...) and fill
-- in by themselves from what the guest has done; the rest are moments (finding the golden egg,
-- being there when the owner arrived, a black hole overhead). Earned in the game at once; each can
-- also be a real Roblox badge once it's made in the Creator Hub and its id is put in Config.Badges
-- under the same key.

local BadgeBook = {}

export type Tier = "bronze" | "silver" | "gold" | "platinum"
export type Badge = {
	key: string,
	name: string,
	line: string, -- what it's for, in words
	glyph: string,
	group: string,
	tier: Tier,
	stat: string?, -- a count it climbs (BadgeBook.Stats), and how far
	target: number?,
}

BadgeBook.Groups = {
	{ id = "level", name = "Levels" },
	{ id = "tables", name = "The tables" },
	{ id = "nights", name = "Nights at the house" },
	{ id = "library", name = "The Library" },
	{ id = "ballroom", name = "The Ballroom" },
	{ id = "collection", name = "Your collection" },
	{ id = "wealth", name = "Gilt and Gems" },
	{ id = "events", name = "Events and Admin Abuse" },
	{ id = "holidays", name = "Holidays" },
	{ id = "social", name = "Friends" },
	{ id = "secrets", name = "Secrets" },
}

-- The counts badges climb (what each means; the server reads them from a guest's record).
BadgeBook.Stats = {
	level = "Your level",
	rounds = "Rounds cleared",
	correct = "Pieces put away correctly",
	flawless = "Flawless rounds",
	nights = "Nights at the house",
	nightlies = "Nightlies played",
	libraryWins = "Wins in the Library",
	libraryMatches = "Matches in the Library",
	ballroomEvenings = "Evenings in the Ballroom",
	lastLamps = "Last Lamps kept",
	topFive = "Top-five finishes in the Ballroom",
	register = "Pieces in your Register",
	mythics = "Mythics found",
	curiosFound = "Curios found at the tables",
	curioKinds = "Different curios held",
	gilt = "Gilt held",
	giltEarned = "Gilt earned",
	pickups = "Things picked up at events",
	abuseNights = "Admin Abuse Nights",
	trades = "Trades made",
	gemsSpent = "Gems spent",
	auras = "Auras owned",
	referrals = "Friends invited",
}

BadgeBook.List = {} :: { Badge }
BadgeBook.byKey = {} :: { [string]: Badge }

local function add(b: Badge)
	assert(BadgeBook.byKey[b.key] == nil, "two badges called " .. b.key)
	table.insert(BadgeBook.List, b)
	BadgeBook.byKey[b.key] = b
end

local function tierAt(i: number, n: number): Tier
	local f = i / n
	return if f <= 0.34 then "bronze" elseif f <= 0.67 then "silver" elseif f < 1 then "gold" else "platinum"
end

local function commas(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

-- A ladder: one badge per step of a count. Each step: { target, name, key? }. `first` is how the
-- step of 1 reads ("Clear your first round", not "Clear 1 rounds").
local function ladder(group: string, stat: string, glyph: string, line: string, steps: { { any } }, first: string?)
	for i, step in steps do
		local target = step[1] :: number
		add({
			key = (step[3] :: string?) or (stat .. "_" .. tostring(target)),
			name = step[2] :: string,
			line = if target == 1 and first then first else (string.gsub(line, "%%d", commas(target))),
			glyph = glyph,
			group = group,
			tier = tierAt(i, #steps),
			stat = stat,
			target = target,
		})
	end
end

local function moment(group: string, key: string, name: string, line: string, glyph: string, tier: Tier)
	add({ key = key, name = name, line = line, glyph = glyph, group = group, tier = tier })
end

-- Levels
ladder("level", "level", "⭐", "Reach level %d.", {
	{ 2, "First Steps" }, { 5, "Apprentice" }, { 10, "Sorter" }, { 15, "On the Rise" }, { 20, "Adept" },
	{ 25, "Quarter Century" }, { 30, "Expert" }, { 40, "Master" }, { 50, "Grandmaster" }, { 60, "Emerald" },
	{ 75, "Virtuoso" }, { 90, "Living Legend" }, { 100, "Immortal" },
})

-- The tables
ladder("tables", "rounds", "🃏", "Clear %d rounds at the tables.", {
	{ 1, "First Round", "firstRound" }, { 10, "Warming Up" }, { 50, "Getting the Hang of It" }, { 100, "Centurion" },
	{ 250, "Regular at the Felt" }, { 500, "Half a Thousand" }, { 1000, "The Thousand" }, { 2500, "Tireless" },
	{ 5000, "Unstoppable" }, { 10000, "Ten Thousand Rounds" },
}, "Clear your first round at the tables.")
ladder("tables", "correct", "✔️", "Put away %d pieces correctly.", {
	{ 100, "Neat Hands" }, { 500, "Tidy" }, { 1000, "The House Hallmark" }, { 2500, "Meticulous" },
	{ 5000, "Archivist's Pride" }, { 10000, "Ten Thousand Places" }, { 25000, "Everything in Its Case" },
	{ 50000, "The Great Sorter" }, { 100000, "A Hundred Thousand" },
})
ladder("tables", "flawless", "💎", "Play %d Flawless rounds.", {
	{ 1, "Flawless", "firstFlawless" }, { 5, "Spotless" }, { 10, "Immaculate Taste" }, { 25, "Precision" },
	{ 50, "Perfectionist" }, { 100, "A Hundred Without a Slip" }, { 250, "Untouchable" }, { 500, "Machine" },
	{ 1000, "Flawless Forever" },
}, "Play your first Flawless round.")
moment("tables", "flawless_salon", "Salon Perfect", "A Flawless round in the Salon.", "🕯️", "bronze")
moment("tables", "flawless_velvet", "Velvet Perfect", "A Flawless round in the Velvet Room.", "🍷", "silver")
moment("tables", "flawless_obsidian", "Obsidian Perfect", "A Flawless round in the Obsidian Room.", "🖤", "gold")
moment("tables", "flawless_midnight", "Midnight Perfect", "A Flawless round in the Midnight Room.", "🌑", "platinum")
moment("tables", "midnight", "After Midnight", "Open the Midnight Room.", "🕛", "gold")

-- Nights at the house
ladder("nights", "nights", "🌙", "Spend %d nights at the house.", {
	{ 1, "First Night" }, { 3, "Back Again" }, { 7, "A Week of Evenings" }, { 14, "Fortnight" },
	{ 30, "A Month at the House" }, { 60, "Two Months" }, { 100, "A Hundred Nights" }, { 200, "Part of the Furniture" },
	{ 365, "A Year at the House" },
}, "Spend your first night at the house.")
ladder("nights", "nightlies", "📜", "Play the Nightly %d times.", {
	{ 1, "Tonight's Table", "firstNightly" }, { 7, "Nightly Habit" }, { 30, "Every Night" }, { 100, "The Hundredth Night" },
}, "Play the Nightly for the first time.")

-- The Library
ladder("library", "libraryWins", "📚", "Win %d matches in the Library.", {
	{ 1, "First Win", "firstLibraryWin" }, { 10, "Ten Wins" }, { 25, "Formidable" }, { 50, "Fifty Wins" },
	{ 100, "Library Lion" }, { 250, "Unbeaten Legend" },
}, "Win your first match in the Library.")
ladder("library", "libraryMatches", "♟️", "Play %d matches in the Library.", {
	{ 5, "Pull Up a Chair" }, { 25, "Library Regular" }, { 100, "Hundred Matches" },
})
moment("library", "mark", "A Mark of Your Own", "Finish your placement evenings and earn a Mark.", "🏷️", "silver")

-- The Ballroom
ladder("ballroom", "ballroomEvenings", "💃", "Play %d evenings in the Ballroom.", {
	{ 1, "First Dance" }, { 10, "Ballroom Regular" }, { 50, "Fifty Evenings" }, { 100, "Belle of the Ball" },
}, "Play your first evening in the Ballroom.")
ladder("ballroom", "lastLamps", "🪔", "Keep the last lamp %d times.", {
	{ 1, "The Last Lamp", "firstLastLamp" }, { 5, "Lamplighter" }, { 25, "Keeper of the Light" },
}, "Keep the last lamp for the first time.")
ladder("ballroom", "topFive", "🏅", "Finish in the top five %d times.", {
	{ 1, "Top Five" }, { 10, "Always Near the Top" }, { 50, "The Ballroom's Own" },
}, "Finish in the top five for the first time.")

-- Your collection
ladder("collection", "register", "📒", "Put %d different pieces in your Register.", {
	{ 10, "The Register Opens", "register10" }, { 25, "A Growing Register", "register25" }, { 50, "Half the House", "register50" },
	{ 75, "Almost Everything" }, { 100, "The Complete Register" },
})
ladder("collection", "mythics", "🌟", "Find %d Mythics.", {
	{ 1, "A Mythic!", "mythic" }, { 3, "Mythic Hunter" }, { 10, "Mythic Collector" }, { 25, "Myth Made Real" },
}, "Find your first Mythic.")
ladder("collection", "curiosFound", "🏺", "Find %d curios at the tables.", {
	{ 1, "A Curio!" }, { 10, "Curio Hunter" }, { 50, "Cabinet of Wonders" }, { 100, "Hundred Curios" },
}, "Find your first curio at the tables.")
ladder("collection", "curioKinds", "🗃️", "Hold %d different curios.", {
	{ 5, "Five of a Kind" }, { 15, "A Shelf of Curios" }, { 30, "Curator" }, { 50, "The Whole Cabinet" },
})
moment("collection", "seasonSet", "The Full Season", "Collect every piece of a season's collection.", "🍂", "gold")

-- Gilt and Gems
ladder("wealth", "gilt", "🪙", "Hold %d Gilt at once.", {
	{ 1000, "Pocket Money" }, { 10000, "Comfortable" }, { 50000, "Well Off" }, { 100000, "Six Figures" },
	{ 500000, "Gilded" }, { 1000000, "Millionaire" },
})
ladder("wealth", "giltEarned", "💰", "Earn %d Gilt in all.", {
	{ 10000, "Earning Your Keep" }, { 100000, "A Fortune Made" }, { 1000000, "A Million Earned" },
})
ladder("wealth", "gemsSpent", "💎", "Spend %d Gems.", {
	{ 100, "First Sparkle" }, { 1000, "Gem Connoisseur" }, { 5000, "Jewel of the House" },
})
ladder("wealth", "auras", "✨", "Own %d auras.", {
	{ 1, "Aglow", "firstAura" }, { 5, "Radiant" }, { 10, "Every Colour" },
}, "Own your first aura.")
moment("wealth", "firstTitle", "Say My Name", "Wear a title under your name.", "🏷️", "bronze")
moment("wealth", "surge", "Surging", "Use a Gilt Surge or an XP Surge.", "⚡", "bronze")
moment("wealth", "exchange", "Change, Please", "Change Gems for Gilt.", "💱", "bronze")

-- Events and Admin Abuse
ladder("events", "abuseNights", "💥", "Be in the house for %d Admin Abuse Nights.", {
	{ 1, "Admin Abuse!", "abuseNight" }, { 5, "Abuse Veteran" }, { 25, "Survivor of Chaos" },
}, "Be in the house for an Admin Abuse Night.")
ladder("events", "pickups", "🎯", "Pick up %d things at the house's events.", {
	{ 1, "Finders Keepers" }, { 25, "Quick Hands" }, { 100, "Hoarder" }, { 500, "Vacuum Cleaner" },
}, "Pick up something at one of the house's events.")
moment("events", "goldenKey", "The Golden Key", "Find a golden key in a Treasure Hunt.", "🗝️", "silver")
moment("events", "paradeCatch", "Caught One!", "Catch a meme in the Brainrot Parade.", "🎈", "bronze")
moment("events", "discoNight", "Disco Fever", "Be in the Ballroom on Disco Night.", "🪩", "bronze")
moment("events", "giveawayWinner", "Winner!", "Win one of the owner's giveaways.", "🎁", "gold")
moment("events", "headline", "Breaking News", "Be in the house for one of the owner's headlines.", "📣", "bronze")
moment("events", "fx_blackHole", "Event Horizon", "Be pulled up into a black hole.", "🕳️", "silver")
moment("events", "fx_ufo", "Abducted", "Be beamed up by a flying saucer.", "🛸", "silver")
moment("events", "fx_meteor", "Impact", "Live through a meteor shower.", "☄️", "silver")
moment("events", "fx_titan", "Something Big", "See the Titan meme rise over the house.", "🗿", "silver")

-- Holidays
moment("holidays", "holiday_halloween", "All Hallows' Hunter", "Find a pumpkin in the All Hallows' Hunt.", "🎃", "silver")
moment("holidays", "holiday_thanksgiving", "Turkey Catcher", "Catch a turkey in the Turkey Trot.", "🦃", "silver")
moment("holidays", "holiday_christmas", "Present Opener", "Open a present in the Gift Drop.", "🎁", "silver")
moment("holidays", "holiday_newYear", "Happy New Year", "Be in the house when the New Year arrives.", "🎆", "silver")
moment("holidays", "holiday_valentine", "Sweetheart", "Find a love letter on Valentine's Day.", "💌", "silver")
moment("holidays", "holiday_stPatrick", "Lucky Clover", "Find a four-leaf clover on St Patrick's Day.", "🍀", "silver")
moment("holidays", "holiday_easter", "Egg Hunter", "Find a painted egg in the Egg Hunt.", "🥚", "silver")

-- Friends
ladder("social", "trades", "🤝", "Make %d trades.", {
	{ 1, "First Trade" }, { 10, "Trader" }, { 50, "Merchant of the House" },
}, "Make your first trade.")
ladder("social", "referrals", "✉️", "Invite %d friends who come to the house.", {
	{ 1, "Plus One" }, { 5, "Life of the Party" },
}, "Invite a friend who comes to the house.")
moment("social", "friendHere", "Better Together", "Be in the house with a friend.", "👯", "bronze")
moment("social", "suiteVisit", "House Call", "Visit a friend's Suite.", "🛋️", "bronze")
moment("social", "guestBook", "Signed and Dated", "Sign the Livre d'Or.", "✒️", "bronze")
moment("social", "circle", "In the Circle", "Join a Circle.", "⭕", "bronze")
moment("social", "admired", "Admirer", "Admire another guest's look.", "💐", "bronze")

-- Secrets
moment("secrets", "metOwner", "Met the Owner", "Be in the house with the owner.", "👑", "gold")
moment("secrets", "foundingTerm", "Founding Member", "Play in the house's very first Term.", "🏛️", "platinum")
moment("secrets", "nightOwl", "Night Owl", "Find the Midnight Owl.", "🦉", "platinum")

-- How many there are.
BadgeBook.count = #BadgeBook.List

return BadgeBook

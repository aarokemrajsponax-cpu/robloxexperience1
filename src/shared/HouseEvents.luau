--!strict
-- The house's events (the owner's panel): what each one is called and what it says. They change
-- Gilt, the Ledger, Mythic luck, XP and how the house feels, never a score, so the boards stay
-- fair. The numbers live in Config.Admin.
--
-- The holidays are events too: a hunt round the house (pumpkins at All Hallows', turkeys at
-- Thanksgiving, presents at Christmas, love letters on Valentine's Day, clovers on St Patrick's Day,
-- eggs at Easter: each worth Gilt, with a curio to keep and one golden prize for whoever finds it),
-- and New Year's countdown. The owner starts any of them at any time; on the real day the house
-- starts its own for a few minutes every hour (Config.Admin.holidayAuto).

local HouseEvents = {}

export type Event = { id: string, name: string, line: string, glyph: string?, holiday: boolean? }

HouseEvents.List = {
	{ id = "goldenHour", name = "Golden Hour", line = "Gilt counts double.", glyph = "🪙" },
	{ id = "luckyHour", name = "Lucky Hour", line = "Mythics are ten times as likely in the four rooms.", glyph = "🍀" },
	{ id = "doubleXP", name = "Double XP", line = "Every level comes twice as fast.", glyph = "⭐" },
	{ id = "pageTurner", name = "The Page-Turner", line = "The Ledger's pages turn twice as fast.", glyph = "📖" },
	{ id = "giants", name = "A Night of Giants", line = "Every guest walking the house stands tall.", glyph = "🦒" },
	{ id = "tiny", name = "A Night of Small Things", line = "Every guest walking the house shrinks to half size.", glyph = "🐜" },
	{ id = "quickstep", name = "The Quickstep", line = "Everyone walks and runs faster.", glyph = "👟" },
	{ id = "featherlight", name = "Featherlight", line = "The house's gravity is gentle. Jump.", glyph = "🪶" },
	{ id = "goldRain", name = "Gold Rain", line = "Gold coins are scattered through the house. Walk over them for Gilt.", glyph = "💰" },
	{ id = "treasure", name = "The Treasure Hunt", line = "Golden keys are hidden around the house. The finder of each wins Gilt.", glyph = "🗝️" },
	{ id = "parade", name = "The Brainrot Parade", line = "The meme curios are loose in the house. Catch them for Gilt, and a Parade Balloon to keep.", glyph = "🎈" },
	{ id = "disco", name = "Disco Night", line = "The Ballroom turns disco. Everyone in it gets the Disco Ball curio.", glyph = "🪩" },
	{ id = "discoHouse", name = "The House Party", line = "Every lamp in the house turns disco, colours chasing round every room.", glyph = "🕺" },
	{ id = "curioHour", name = "A Night of Curios", line = "Curios turn up among the pieces twice as often.", glyph = "🏺" },
	-- The holidays.
	{ id = "halloween", name = "The All Hallows' Hunt", line = "Pumpkins are hidden all over the house. Find them for Gilt; one is solid gold.", glyph = "🎃", holiday = true },
	{ id = "thanksgiving", name = "The Turkey Trot", line = "Turkeys are loose in the house and they run. Catch one for Gilt; one is golden.", glyph = "🦃", holiday = true },
	{ id = "christmas", name = "The Gift Drop", line = "Presents are under every tree, and snow is falling. Open them for Gilt; one rings gold.", glyph = "🎁", holiday = true },
	{ id = "newYear", name = "The New Year Countdown", line = "Ten seconds, then the biggest fireworks of the year and a present for everyone here.", glyph = "🎆", holiday = true },
	{ id = "valentine", name = "Sweethearts", line = "Love letters are hidden round the house. Find them for Gilt; one is a heart of gold.", glyph = "💌", holiday = true },
	{ id = "stPatrick", name = "The Lucky Clover", line = "Four-leaf clovers are everywhere, and a pot of gold waits at the rainbow's end.", glyph = "🍀", holiday = true },
	{ id = "easter", name = "The Egg Hunt", line = "Painted eggs are hidden all over the house. Find them for Gilt; one is golden.", glyph = "🥚", holiday = true },
} :: { Event }

HouseEvents.byId = {} :: { [string]: Event }
for _, e in HouseEvents.List do
	HouseEvents.byId[e.id] = e
end

-- The holiday hunts' pickups (Config.Admin.hunts has their numbers).
HouseEvents.Holidays = { "halloween", "thanksgiving", "christmas", "newYear", "valentine", "stPatrick", "easter" }

-- Effects for everyone, at the owner's tap (and as surprises through Admin Abuse Night). Each plays
-- on every screen round that guest (World/AbuseFX); none changes Gilt, a score or anything kept.
-- None is frightening and nobody is hurt: it's spectacle (the house is rated for everyone).
HouseEvents.Effects = {
	{ id = "launch", name = "Rocket launch", line = "Every guest shoots into the sky.", glyph = "🚀" },
	{ id = "dance", name = "Dance party", line = "Every guest dances, under disco light.", glyph = "💃" },
	{ id = "storm", name = "Lightning storm", line = "Thunder and lightning over the house.", glyph = "⚡" },
	{ id = "memeRain", name = "Brainrot storm", line = "Memes pour from the sky round every guest.", glyph = "🗿" },
	{ id = "confetti", name = "Confetti cannons", line = "Cannons of confetti round every guest.", glyph = "🎉" },
	{ id = "shockwave", name = "Shockwave", line = "A golden blast from you throws every guest near you back.", glyph = "💥" },
	{ id = "spin", name = "Spin", line = "Every guest spins like a top.", glyph = "🌀" },
	{ id = "meteor", name = "Meteor shower", line = "Blazing meteors streak down and slam round every guest.", glyph = "☄️" },
	{ id = "blackHole", name = "Black hole", line = "A black hole opens overhead and pulls everyone up into its swirl.", glyph = "🕳️" },
	{ id = "aurora", name = "Aurora", line = "Ribbons of green and violet light ripple across the sky.", glyph = "🌌" },
	{ id = "galaxy", name = "Galaxy sky", line = "The sky turns to deep space: stars, nebulae and a ringed planet.", glyph = "🪐" },
	{ id = "ufo", name = "UFO abduction", line = "A flying saucer hovers over each guest and beams them up.", glyph = "🛸" },
	{ id = "blizzard", name = "Blizzard", line = "A whiteout: snow sweeps sideways through the house.", glyph = "🌨️" },
	{ id = "earthquake", name = "Earthquake", line = "The ground rumbles and every screen shakes.", glyph = "🌋" },
	{ id = "rainbow", name = "Rainbow mode", line = "Everything turns every colour at once, with rainbow trails.", glyph = "🌈" },
	{ id = "bubbles", name = "Bubble party", line = "Thousands of bubbles float up round every guest.", glyph = "🧼" },
	{ id = "goldWave", name = "Gold wave", line = "A tidal wave of gold coins washes over every screen.", glyph = "🌊" },
	{ id = "fireIce", name = "Fire & Ice", line = "Embers and snowflakes, red and blue, at once.", glyph = "🔥" },
	{ id = "blackout", name = "Blackout", line = "The lights go out; spotlights sweep the dark, then everything blazes back.", glyph = "🔦" },
	{ id = "tornado", name = "Tornado", line = "A whirlwind spins up beside every guest and carries them round.", glyph = "🌪️" },
	{ id = "fireworks", name = "Fireworks finale", line = "The sky fills with fireworks over every guest.", glyph = "🎆" },
	{ id = "titan", name = "Titan meme", line = "A colossal meme rises over the rooftops, looks round, and sinks.", glyph = "🗿" },
	{ id = "zeroG", name = "Zero gravity", line = "Everyone floats, slowly, then drifts back down.", glyph = "🌙" },
} :: { Event }

HouseEvents.effectById = {} :: { [string]: Event }
for _, e in HouseEvents.Effects do
	HouseEvents.effectById[e.id] = e
end

-- Lines the owner can announce with one tap (anything typed is filtered by Roblox first).
HouseEvents.Announcements = {
	"The owner is in the house tonight. Come and say good evening.",
	"Everyone to the Ballroom: the next evening is a big one.",
	"Golden Hour is on. Every table pays double Gilt.",
	"A treasure hunt has begun. Look everywhere.",
	"Thank you for spending your evening at Maison Noir.",
	"The Terrace is open. Come and see the fireworks.",
}

-- Headlines: big words across the top of every screen for a few seconds, from the owner. One tap
-- each (or the owner's own words, filtered by Roblox first).
HouseEvents.Headlines = {
	"ADMIN ABUSE IN 5 MINUTES! DON'T LEAVE!",
	"THE OWNER IS IN THE SERVER! SAY HI!",
	"DOUBLE GILT FOR EVERYONE RIGHT NOW!",
	"GIVEAWAY TIME! STAY IN THE SERVER!",
	"WHO'S READY FOR CHAOS?!",
	"HOLIDAY HUNT STARTING NOW! LOOK EVERYWHERE!",
	"NEW UPDATE IS LIVE! GO EXPLORE!",
	"BIGGEST ADMIN ABUSE EVER, TONIGHT!",
	"THANK YOU FOR PLAYING MAISON NOIR!",
	"HAVING FUN? LIKE THE GAME AND TELL A FRIEND!",
}

-- How a headline looks.
HouseEvents.HeadlineStyles = { "gold", "red", "rainbow", "ice", "green" }

-- Countdowns: big numbers on every screen, then something happens.
export type Countdown = { id: string, label: string, name: string }
HouseEvents.Countdowns = {
	{ id = "abuse", label = "ADMIN ABUSE IN", name = "Admin Abuse Night" },
	{ id = "mega", label = "MEGA ABUSE IN", name = "Mega Abuse" },
	{ id = "giveaway", label = "GIVEAWAY IN", name = "A giveaway" },
	{ id = "surprise", label = "SURPRISE IN", name = "A surprise effect" },
} :: { Countdown }

HouseEvents.countdownById = {} :: { [string]: Countdown }
for _, c in HouseEvents.Countdowns do
	HouseEvents.countdownById[c.id] = c
end

-- The Workspace attribute that carries an event's end time (seconds since 1970), or nil.
function HouseEvents.attribute(id: string): string
	return "Event_" .. id
end

-- The Workspace attribute an effect the owner has switched on lives in (its value: when it was
-- switched on, os.time). Every screen watches it: the effect stays on until it's gone.
function HouseEvents.fxAttribute(id: string): string
	return "Fx_" .. id
end

-- Easter Sunday in a year (the Gregorian calendar's computus): its month and day.
function HouseEvents.easter(year: number): (number, number)
	local a = year % 19
	local b = year // 100
	local c = year % 100
	local d = b // 4
	local e = b % 4
	local f = (b + 8) // 25
	local g = (b - f + 1) // 3
	local h = (19 * a + b - d - g + 15) % 30
	local i = c // 4
	local k = c % 4
	local l = (32 + 2 * e + 2 * i - h - k) % 7
	local m = (a + 11 * h + 22 * l) // 451
	local month = (h + l - 7 * m + 114) // 31
	local day = ((h + l - 7 * m + 114) % 31) + 1
	return month, day
end

-- The day of the week of a date: 0 Sunday ... 6 Saturday (Sakamoto's method).
local OFFSETS = { 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 }
function HouseEvents.weekday(year: number, month: number, day: number): number
	local y = if month < 3 then year - 1 else year
	return (y + y // 4 - y // 100 + y // 400 + OFFSETS[month] + day) % 7
end

-- The holiday on a date (UTC), or nil: All Hallows' Eve, Thanksgiving (the fourth Thursday of
-- November), Christmas Eve to Boxing Day, New Year's Eve and Day, Valentine's Day, St Patrick's
-- Day, Easter Sunday and Monday.
function HouseEvents.holidayOn(year: number, month: number, day: number): string?
	if month == 10 and day == 31 then
		return "halloween"
	elseif month == 11 and day >= 22 and day <= 28 then
		if HouseEvents.weekday(year, month, day) == 4 then
			return "thanksgiving"
		end
	elseif month == 12 and day >= 24 and day <= 26 then
		return "christmas"
	elseif (month == 12 and day == 31) or (month == 1 and day == 1) then
		return "newYear"
	elseif month == 2 and day == 14 then
		return "valentine"
	elseif month == 3 and day == 17 then
		return "stPatrick"
	end
	local em, ed = HouseEvents.easter(year)
	if month == em and (day == ed or day == ed + 1) then
		return "easter"
	end
	-- (Easter Monday on the first of the next month.)
	if month == em + 1 and day == 1 and ed == 31 then
		return "easter"
	end
	return nil
end

return HouseEvents

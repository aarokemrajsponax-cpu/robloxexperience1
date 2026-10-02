--!strict
-- Every line the house speaks (§5). Short, specific, dry, warm. No exclamation marks.
-- Never "game", "level", "loot", "match", "battle".

local Voice = {}

Voice.Concierge = {
	speaker = "THE CONCIERGE",
	firstVisit = "Good evening. The tables are set.",
	returning = "Good to see you again, {name}.",
	rare = "Now that one I'd keep an eye on.",
	mythic = "Nobody touch anything.",
	midnightUnlocked = "The last room is open to you. Mind the dark.",
	midnightLocked = "The Midnight Room opens once you've reached round IV in Obsidian.",
	tonightLaid = "Tonight's table is laid.",
	noticed = "The house has noticed.",
	waiting = "A table is being laid for you.",
	libraryWin = "Well played. They'll want another.",
	libraryLoss = "Close. The house saw every piece of it.",
	ballroomOpens = "Twenty tables. One lamp at the end of the night.",
	lastLamp = "The last lamp in the house is yours.",
	ballroomUnderway = "An evening is under way. You'll have a chair at the next one.",
	wall = "Your name goes on the wall.",
	thisWay = "This way.",
	arrived = "The Salon. Any table you like.",
	arrivedIn = {
		salon = "The Salon. Any table you like.",
		velvet = "The Velvet Room. The clock waits for your first piece.",
		obsidian = "The Obsidian Room. Every case is open from the first deal.",
		midnight = "The Midnight Room. Mind the dark.",
	},
	whichRoom = "Which room this evening?",
	standInOffer = "Nobody's free just now. A Stand-in can sit opposite you, if you'd rather not wait.",
	standInYes = "A Stand-in, please",
	standInWait = "I'll wait",
	duelSeated = "Same pieces, both of you. First to three hands.",
	rematch = "They'll want another.",
	foundRival = "Someone is waiting for you at the other table. This way.",
	friendAway = "Your friend isn't at a table just now. Take any chair in the Library.",
	libraryWay = "Up the Grand Stair, first door on your left.",
	ballroomWay = "Up the Grand Stair, the tall doors on your right. Take any chair.",
	closedRoom = "Not tonight. The Salon is open.",
	lost = "The Salon is through there, if you'd like me to walk you.",
	goodNight = "Good night.",
	-- The house remembers you (Memory.luau).
	memory = {
		milestone = "Your {n} night at the house. We're glad of it.",
		away = "It's been a while. Your table was kept.",
		awayNoTable = "It's been a while. Nothing has moved.",
		lastTime = "Last time, {highlight}.",
		admired = "{n} guests admired you last time you were here.",
		admiredOne = "A guest admired you last time you were here.",
		usual = "Your usual table?",
	},
	choices = {
		takeMe = "Take me to a room",
		how = "How does this work",
		library = "The Library",
		ballroom = "The Ballroom",
		inviteFriend = "Invite a friend to the Library",
		thanks = "Thank you",
		fine = "I'm fine, thank you",
		bye = "Good night",
		setEvening = "Set the evening",
		tour = "Show me the house",
	},
	tourOffer = "Good evening, and welcome to Maison Noir. Shall I show you the house? It takes a minute.",
	tourYes = "Show me the house",
	tourSkip = "Straight to a table",
	tourLater = "I'll look around",
	tourLaterLine = "Of course. Speak to me any time and I'll show you round.",
	tourEnd = "Enjoy the house. I'm here if you need me.",
}

-- The Concierge's tour: one card for each part of the house, in plain words, with a gold pin
-- and a line of light to the place it describes. `place` names where it points (see Concierge).
Voice.Tour = {
	{
		title = "The idea",
		line = "Every table holds a spread of expensive things. Put each one in its case: watches, jewelry, money, keys, accessories, collectibles. Right cases build a streak, the streak builds your score, and every run you bank pays you Gilt.",
	},
	{
		title = "Sorting",
		place = "salonDoor",
		line = "Sit at any table and the table fills your screen. Drag a piece onto its case, or click the piece and then the case, or press 1 to 6. A wrong case costs your streak. Bank the run whenever you like; your best goes on the boards.",
	},
	{
		title = "The four rooms",
		place = "salonDoor",
		line = "The Salon has no clock: learn here. The Velvet Room's clock waits for your first piece. The Obsidian Room opens every case with the clock running. The Midnight Room opens once you reach round IV in Obsidian.",
	},
	{
		title = "Tonight's table",
		place = "tonightBoard",
		line = "Once a day every guest sorts the same table. One scored try each; your place goes up on the board by the door. After that you can rehearse it as often as you like.",
	},
	{
		title = "Gilt",
		line = "Gilt is the house's money. Banked runs pay it, Golden Hours double it, and the Boutique takes it for the house's own pieces. Your purse is shown in the Boutique.",
	},
	{
		title = "The Boutique",
		place = "boutique",
		line = "Through the door at the back on the right. Six new pieces every day, two for the week, the season's collection, and Salutes for the whole house. Press the gold Shop key any time for the offers.",
	},
	{
		title = "The Wardrobe",
		place = "boutique",
		line = "In the Boutique, the Tailor and the mirror. Everything you own is worn from the Wardrobe: your look, your nameplate, your table's felt, your chime. Nothing you wear changes a score.",
	},
	{
		title = "The Vault",
		place = "vault",
		line = "Through the door at the back on the left. Every piece you've ever filed sits in its cabinet, Mythics in the middle. The Archivist keeps your Register: badges, commissions and your standing in the house.",
	},
	{
		title = "The Library",
		place = "library",
		line = "Up the Grand Stair, first door on the left: Tête-à-Tête. Two guests, the same pieces, first to three hands. Ranked or friendly, or with a Stand-in if nobody's free.",
	},
	{
		title = "The Ballroom: Lights Out",
		place = "ballroom",
		line = "Up the stair, the tall doors on the right. Twenty tables, one evening. Sorting well sends parcels of extra pieces to your rivals; a table that falls behind loses its lamp. The last lamp lit wins the night. Watch from the Gallery between evenings.",
	},
	{
		title = "Your Suite",
		place = "suite",
		line = "Up the stair, through the door on the left of the hall: your own rooms. Ring the bell to furnish them with pieces from the Boutique and the Ledger. The Gold Key opens the Dressing Room and the Study.",
	},
	{
		title = "The Ledger",
		place = "ledger",
		line = "Every round you play turns pages in the Ledger, the season's book of rewards: a free piece every few pages, more with the Leather-Bound edition. A new Term begins each season.",
	},
	{
		title = "That's the house",
		line = "Settings is top right for sound and controls. Speak to me any time to be shown a room or to hear this again. Shall I walk you to a table?",
	},
}
Voice.TourKeys = { next = "Next", back = "Back", done = "End the tour", table = "Take me to a table", explore = "I'll explore" }

-- A Private Evening (a private server).
Voice.Private = {
	title = "A Private Evening",
	line = "Your own house tonight. Nothing here counts for records.",
	setEvening = "How would you like the Ballroom tonight?",
	pace = "The pace",
	standIns = "The empty chairs",
	paces = { gentle = "Gentle", house = "The house's pace", brisk = "Brisk" },
	standInChoices = { fill = "Stand-ins fill them", none = "Only our guests" },
	done = "It's arranged.",
	notOwner = "The evening is arranged by the host.",
}

Voice.Doorman = {
	speaker = "THE DOORMAN",
	evening = "Evening.",
}

Voice.Archivist = { speaker = "THE ARCHIVIST", kept = "Everything you've found is kept here." }
Voice.Tailor = { speaker = "THE TAILOR", time = "Take your time. It changes at midnight." }

Voice.HowToPlay = {
	"Pick one up",
	"Put it where it belongs",
	"The light will show you",
	"Three in a row pays",
	"Then pick your room",
}

Voice.Table = {
	sit = "Sit",
	leave = "Leave",
	nextRound = "Next round",
	bank = "Bank the run",
	straightToTable = "Straight to the table",
	clockRanOut = "The clock ran out in round {round}.",
}

-- The one line under the keys while you walk: what to do next.
Voice.Objective = {
	next = "Next",
	tonight = "Tonight",
	sit = "Take a seat at any table in the Salon",
	sitHow = {
		mouse = "Walk up to a chair and press E",
		touch = "Walk up to a chair and tap Sit",
		gamepad = "Walk up to a chair and press X",
	},
	nightly = "Tonight's table is laid: one deal, everyone on Roblox",
	nightlyHow = {
		mouse = "Press F at any table",
		touch = "Tap Tonight's table at any chair",
		gamepad = "Press Y at any table",
	},
	midnight = "Reach round IV in the Obsidian Room to open the Midnight Room",
	midnightHow = "The Concierge in the Foyer will walk you there",
	best = "Beat your best run in {room}: {points} points",
	bestHow = "Any room. The Midnight Room pays the most.",
	takeMe = "Take me there",
}

-- What a filing says back: plain enough that nobody wonders whether it went in.
Voice.Sorting = {
	correct = "Correct",
	wrong = "Wrong case",
	tryAgain = "Try again",
	streakLost = "Streak of {n} lost",
	inARow = "{n} in a row",
	multiplier = "Now ×{n}",
	objective = "Put every piece in the case where it belongs",
	hints = {
		mouse = "Drag a piece onto its case  ·  or click it, then its case  ·  keys 1 to 6",
		touch = "Drag a piece onto its case  ·  or tap it, then its case",
		gamepad = "A picks up  ·  D-pad chooses a case  ·  A puts it in",
	},
	-- Called out as a streak grows (Config.Sorting.streakMoments); the rest say "{n} in a row".
	moments = {
		[5] = "Five in a row. Lovely.",
		[8] = "Eight. The house is watching.",
		[12] = "Twelve without a slip.",
		[20] = "Twenty. Remarkable.",
	},
}

Voice.Library = {
	title = "Tête-à-Tête",
	waiting = "Waiting for a guest opposite",
	ranked = "Ranked",
	friendly = "Friendly · not ranked",
	standIn = "A Stand-in · not ranked",
	handWon = "Hand to you",
	handLost = "Hand to {name}",
	won = "The table is yours",
	lost = "{name} takes the table",
	forfeit = "{name} left the table",
	parcelIn = "A parcel is on its way",
	another = "Another",
	rematchAsked = "{name} would like another.",
	rivalAway = "Your rival's connection dropped",
	holding = "Their chair is held for {seconds} seconds. The hand waits.",
	rivalBack = "{name} is back at the table.",
	placement = "{n} more before your Mark is shown",
	rating = "Rating",
	gilt = "Gilt",
	hands = "Hands",
}

Voice.Ballroom = {
	title = "Lights Out",
	gathering = "The evening begins in {seconds} seconds. Twenty tables, one lamp at the end.",
	counted = "Twenty tables. One lamp at the end of the night.",
	notCounted = "Fewer than eight guests tonight: this evening doesn't count for records.",
	key = "A Key",
	tookKey = "Table {table}'s lamp went out on your parcel.",
	closingTime = "Closing Time",
	closingLine = "The pace tightens until someone breaks.",
	sixthCase = "The sixth case opens.",
	queued = "You'll have a chair at the next evening.",
	outTitle = "Your lamp is out",
	outBy = "{place} of {of} · a parcel from {name}",
	outPlace = "{place} of {of}",
	overCapacity = "Over sixteen. Three seconds.",
	lastLamp = "The last lamp in the house is yours.",
	place = "{place} of {of}",
	keys = "Keys",
	points = "Points this week",
	gilt = "Gilt",
	notCountedNote = "Fewer than eight guests: not counted for records.",
	nextEvening = "Next evening",
	gallery = "Watch from the Gallery",
	stay = "Stay for the next evening",
}

Voice.Foyer = {
	tonight = "TONIGHT",
	wall = "THE WALL OF NAMES",
	foundingTerm = "The Founding Term",
	livre = "LIVRE D'OR",
	stair = "THE CLUB FLOOR",
	boutique = "THE BOUTIQUE",
	closed = "Closed this evening.",
}

function Voice.fill(line: string, values: { [string]: string }): string
	return (string.gsub(line, "{(%w+)}", function(key)
		return values[key] or ("{" .. key .. "}")
	end))
end

-- Roman numerals for round cards.
function Voice.roman(n: number): string
	local numerals: { { any } } = { { 10, "X" }, { 9, "IX" }, { 5, "V" }, { 4, "IV" }, { 1, "I" } }
	local out = ""
	local value = math.max(1, math.floor(n))
	for _, pair in numerals do
		while value >= pair[1] do
			out ..= pair[2]
			value -= pair[1]
		end
	end
	return out
end

local words = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten" }

function Voice.roundLabel(n: number, style: string): string
	if style == "4" then
		return tostring(n)
	elseif style == "Four" then
		return words[n] or tostring(n)
	end
	return Voice.roman(n)
end

return Voice

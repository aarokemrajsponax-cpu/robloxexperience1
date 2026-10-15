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
	tourOffer = "Welcome to Maison Noir. Shall I show you round? It's quick.",
	tourYes = "Show me the house",
	tourSkip = "Straight to a table",
	tourLater = "I'll look around",
	tourLaterLine = "Of course. Speak to me any time and I'll show you round.",
	tourEnd = "Enjoy the house. I'm here if you need me.",
}

-- The Concierge's tour: the Concierge walks the guest round the house and stops at each place
-- (`stop`, see Layout.Tour) to explain it, with a gold pin over the thing it describes (`place`).
Voice.Tour = {
	{
		stop = "lectern",
		title = "Welcome",
		line = "Here you sort fancy things into their right cases. Right answers build a streak, and every run you bank pays you Gilt.",
	},
	{
		stop = "salon",
		place = "salonDoor",
		title = "The Salon",
		line = "Sit at a table (press E). Drag each piece to its case, or press 1 to 6. No clock in here, so take your time.",
	},
	{
		stop = "salon",
		place = "velvetDoor",
		title = "The timed rooms",
		line = "The Velvet, Obsidian and Midnight Rooms have a clock, each harder than the last. Midnight opens at round IV in Obsidian.",
	},
	{
		stop = "tonight",
		place = "tonightBoard",
		title = "Tonight's table",
		line = "Once a day, everyone plays the same table. The card at the top of your screen takes you to your one try; the best go up on this board.",
	},
	{
		stop = "tonight",
		place = "livreDOr",
		title = "The guest book",
		line = "Sign it once a night. You can start a Circle here too: a club of up to twenty friends.",
	},
	{
		stop = "vault",
		place = "vault",
		title = "The Vault",
		line = "Every piece you've ever sorted is kept here. The Archivist at the desk keeps your badges.",
	},
	{
		stop = "boutique",
		place = "counter",
		title = "The Boutique",
		line = "Spend your Gilt on new looks here. The gold Shop key at the top of your screen opens it from anywhere.",
	},
	{
		stop = "boutique",
		place = "mirror",
		title = "The Wardrobe",
		line = "Wear what you own: your look, your nameplate, your table, your lamp and your trail.",
	},
	{
		stop = "library",
		place = "libraryDoor",
		title = "Tête-à-Tête",
		line = "Two players, the same pieces, face to face. First to win three hands wins the match.",
	},
	{
		stop = "ballroom",
		place = "ballroomDoor",
		title = "The Ballroom",
		line = "Opens every 20 minutes for one big game. The last lamp still lit wins the whole pot of Gilt.",
	},
	{
		stop = "terrace",
		place = "terraceDoor",
		title = "The Terrace",
		line = "A bar, a fire pit and loungers under the stars. Sit anywhere you like.",
	},
	{
		stop = "suite",
		place = "suiteDoor",
		title = "Your Suite",
		line = "Your own private rooms. Ring the bell inside to furnish them.",
	},
	{
		stop = "suite",
		title = "Off you go",
		line = "Brainrots you find at the tables earn you Gilt every hour: see them in Collection. Shall I take you to a table?",
	},
}

-- While the Concierge walks to the next stop.
Voice.TourWalk = {
	start = "Come with me. I'll show you round.",
	salon = "This way, to the Salon.",
	tonight = "Over here, by the wall.",
	vault = "Now the Vault, at the back.",
	boutique = "Round to the Boutique.",
	library = "Up the Grand Stair. Mind the step.",
	ballroom = "Along the hall.",
	terrace = "And over here.",
	suite = "One more door.",
	waiting = "I'll wait for you.",
	lost = "The tour can wait. Speak to me in the Foyer when you'd like to carry on.",
}

-- The names on the gold pins the tour's cards put over things.
Voice.TourPlaces = {
	salonDoor = "The Salon",
	velvetDoor = "The Velvet Room",
	tonightBoard = "Tonight's table",
	livreDOr = "The Livre d'Or",
	vault = "The Vault",
	counter = "The Boutique",
	mirror = "The Wardrobe",
	ledger = "The Ledger",
	libraryDoor = "The Library",
	ballroomDoor = "The Ballroom",
	terraceDoor = "The Terrace",
	suiteDoor = "Your Suite",
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

-- A guest still new to the house: the arrow to the Concierge, his key, the card under the keys,
-- and the three steps of the game, said plainly.
Voice.StartHere = {
	title = "Start here",
	heading = "Welcome to Maison Noir",
	arrowFar = "Follow the gold arrow to him",
	arrowNear = {
		mouse = "Press E: Show me the house",
		touch = "Tap Show me the house",
		gamepad = "Press X: Show me the house",
	},
	promptAction = "Show me the house",
	goal = "Talk to the Concierge",
	goalHow = "Follow the gold arrow. He shows you the house and how to play.",
	steps = {
		{ title = "Meet the Concierge", line = "Follow the gold arrow and pick Show me the house. He walks you round and teaches you the game." },
		{ title = "Sit at a table", line = "Any table in the Salon. Walk up to a chair and take a seat." },
		{ title = "Sort the treasures", line = "Put each piece in its case: watches in Watches, rings in Jewelry, gold in Money. Every right one earns Gilt." },
	},
	after = "Spend your Gilt on your Suite, your look and more.",
	go = "Show me the way",
	table = "Straight to a table",
}

-- How to play (the key at the top right): the whole game, explained step by step in plain words,
-- on five pages: the basics, sorting (the six cases, pictured), the rooms (each with a Go key that
-- takes you there), Gilt and the Shop, and the extras.
export type GuideItem = { title: string, line: string, how: string?, win: string?, key: string?, action: string?, place: string? }
Voice.Guide = {
	key = "How to play",
	title = "How to play",
	tabs = {
		{ "basics", "Basics" },
		{ "sorting", "Sorting" },
		{ "rooms", "Rooms" },
		{ "gilt", "Gilt & Shop" },
		{ "extras", "Extras" },
	},
	basics = {
		lead = "Maison Noir is a sorting game in a grand house. You sort treasures into the right cases, earn Gilt (the house's gold coins), and spend it on things you like. That's the whole game. Everything else is a bonus.",
		heading = "Your first five minutes",
		steps = {
			{ title = "Go to a table", line = "The tables are in the Salon, through the doors on your left as you come in. Walk up to any chair and press E. On a phone, tap Sit.", key = "Take me there", action = "sit" },
			{ title = "Sort the treasures", line = "Treasures land on the table: watches, rings, gold, keys and more. Drag each one down into the case it belongs in. Every case says what goes inside.", key = "See how", action = "sorting" },
			{ title = "Earn Gilt", line = "Every piece in the right case scores points. A few right in a row is a streak, and then each one scores more. When you bank the run (or stand up), your points become Gilt." },
			{ title = "Spend it", line = "Press Shop at the top right for new looks, table styles and more. Upstairs, your own Suite is yours to furnish.", key = "Shop", action = "shop" },
		} :: { GuideItem },
		after = "Lost at any time? Press How to play at the top right, or ask the Concierge by the front door.",
	},
	sorting = {
		lead = "Every treasure belongs in one of six cases along the bottom of the table. Each case shows a piece that goes in it.",
		heading = "Good to know",
		tips = {
			{ title = "Moving a piece", line = "Drag it onto its case. On a phone you can also tap the piece, then tap the case. On a keyboard, keys 1 to 6 pick the cases." },
			{ title = "A wrong case", line = "It only breaks your streak. Shrug it off and sort the next one." },
			{ title = "Not sure where it goes?", line = "In the Salon, wait a moment and a thread of gold runs from the piece to its case." },
			{ title = "Rounds", line = "Clear the table to finish a round. Then pick Next round (more pieces, more points) or Bank the run to take your Gilt now." },
			{ title = "Clocks", line = "The Salon has no clock: take your time. The Velvet, Obsidian and Midnight Rooms do, and they pay more for it." },
		} :: { GuideItem },
		key = "Try it at a table",
	},
	rooms = {
		lead = "Every place in the house: what it is, how it works, and what you get. Go takes you straight there.",
		heading = "Where to sort",
		sort = {
			{ place = "salon", title = "The Salon", line = "The first tables, and the calmest: no clock at all.", how = "Sit at any table and sort at your own pace. The best place to learn.", win = "Gilt for every run you bank." },
			{ place = "velvet", title = "The Velvet Room", line = "Your first timed room.", how = "A clock runs every round: clear the table before it runs out.", win = "More Gilt than the Salon." },
			{ place = "obsidian", title = "The Obsidian Room", line = "Timed, and harder again.", how = "Fewer seconds and more pieces. Reach round IV here and the Midnight Room opens for you.", win = "More Gilt, and the way into Midnight." },
			{ place = "midnight", title = "The Midnight Room", line = "The hardest tables in the house.", how = "It opens once you reach round IV in the Obsidian Room.", win = "The best pay of any table." },
		} :: { GuideItem },
		heading2 = "Around the house",
		visit = {
			{ place = "concierge", title = "The Concierge", line = "Stands by the front door, ready to help.", how = "Speak to him and pick Show me the house: he walks you round every room and explains it." },
			{ place = "boutique", title = "The Boutique", line = "The house's shop for looks.", how = "Looks, table styles, lamps and trails for Gilt (a few for Robux, always with the price shown first). The Wardrobe beside it is where you wear what you own." },
			{ place = "vault", title = "The Vault", line = "Your collection, kept for good.", how = "Every piece you've ever sorted is on its shelves. The Archivist at the desk keeps your badges and records." },
			{ place = "terrace", title = "The Terrace", line = "A rooftop to relax on.", how = "A bar with treats, a fire pit and loungers under the stars. Sit anywhere, and watch the fireworks from here." },
			{ place = "suite", title = "Your Suite", line = "Your own private rooms upstairs.", how = "Ring the bell inside to furnish them. Only you can go in, unless you invite friends with the Suites key." },
		} :: { GuideItem },
	},
	gilt = {
		lead = "Gilt is the house's money. You earn it by sorting, and spend it on things you keep.",
		items = {
			{ title = "Gilt", line = "Earned at every table: the better your run, the more you get.", how = "Your Gilt is shown at the top left of the screen." },
			{ title = "Gems", line = "Rarer than Gilt.", how = "Won in races, the holiday games and the Evening Calendar's presents. Spend them in the Gems shop on auras, titles and more." },
			{ title = "The Shop", line = "Everything for sale, in one place.", how = "Looks, table styles, lamps and more for Gilt. Some special things are for Robux, always with the price shown first.", key = "Shop", action = "shop" },
			{ title = "Levels and badges", line = "Everything you do counts.", how = "Sorting, racing and playing earn XP and raise your level. Badges in the Badge Book mark what you've done." },
			{ place = "tonight", title = "Tonight's table", line = "Optional: once a day, everyone plays the same table.", how = "You get one try a day. The best scores go up on the board in the hall.", key = "Play", action = "nightly" },
		} :: { GuideItem },
	},
	extras = {
		lead = "Big games and fun on the side. All optional, all worth a try.",
		items = {
			{ place = "grandPrix", title = "The Grand Prix", line = "Ultra-luxury cars on the street outside.", how = "Walk up to any car and press E to drive (or F to ride along with a friend). Every 10 minutes a race opens: press Race, line up on the grid, wait for the five lights, then three laps. Reset puts a stuck car right.", win = "Gilt for the top three, and Gems for the winner." },
			{ place = "ballroom", title = "The Ballroom", line = "Lights Out: the big game, every 20 minutes.", how = "When it opens, sit in any chair before the countdown ends. Then everyone sorts at once. Your table holds 16 pieces: go over for 3 seconds and your lamp goes out.", win = "The last lamp still lit wins the whole pot of Gilt." },
			{ place = "library", title = "The Library", line = "Tête-à-Tête: one on one.", how = "Sit at a Library table to face another player. You both get exactly the same pieces; three in a row sends a parcel of lookalikes across to them.", win = "First to win three hands wins the match." },
			{ title = "Curios and brainrots", line = "Collectibles found as you play.", how = "They turn up at the tables. Open Collection (left of the screen) to see them, and Trade to swap with friends safely.", win = "Brainrots earn you Gilt every hour." },
			{ title = "Holiday games", line = "In their season, the house throws a party.", how = "Trick or Treat on Hallows Lane, the Turkey Round-Up, Santa's Sleigh, the Great Egg Hunt and the Luck of the Irish.", win = "Gifts, Gilt and Gems." },
			{ title = "Events", line = "Golden Hour and more.", how = "Watch the strip at the top of the screen: while an event is on, it pays extra.", win = "More Gilt while they last." },
		} :: { GuideItem },
	},
	next = "Next: ",
	go = "Go",
	tour = "Show me the house",
	arrived = "You're here",
	coach = "New here? Everything is explained in How to play, with a Go key for every room.",
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
		mouse = "Optional: one try a day. Take me there seats you at it.",
		touch = "Optional: one try a day. Take me there seats you at it.",
		gamepad = "Optional: one try a day. Take me there seats you at it.",
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
		[12] = "Twelve without a slip. You're on fire.",
		[16] = "Sixteen. Sharp as a pin.",
		[20] = "Twenty. Remarkable.",
		[30] = "Thirty. Unheard of.",
		[50] = "Fifty. A legend of the house.",
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
	gathering = "Lights Out begins in {seconds} seconds. Last call: nobody joins once it starts.",
	counted = "Twenty tables. One lamp at the end of the night.",
	notCounted = "Fewer than eight guests tonight: this evening doesn't count for records.",
	key = "A Key",
	tookKey = "Table {table}'s lamp went out on your parcel.",
	closingTime = "Closing Time",
	closingLine = "The pace tightens until someone breaks.",
	sixthCase = "The sixth case opens.",
	queued = "You'll be told the moment the Ballroom opens again.",
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
	nextEvening = "Remind me when it opens",
	gallery = "Watch from the Gallery",
	stay = "Remind me when it opens",
	pot = "The pot",
	potWent = "The pot went to {name}",
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
-- Roman numerals as far as they go (MMMCMXCIX); a run that goes further counts in figures.
function Voice.roman(n: number): string
	local numerals: { { any } } = {
		{ 1000, "M" },
		{ 900, "CM" },
		{ 500, "D" },
		{ 400, "CD" },
		{ 100, "C" },
		{ 90, "XC" },
		{ 50, "L" },
		{ 40, "XL" },
		{ 10, "X" },
		{ 9, "IX" },
		{ 5, "V" },
		{ 4, "IV" },
		{ 1, "I" },
	}
	local out = ""
	local value = math.max(1, math.floor(n))
	if value >= 4000 then
		return tostring(value)
	end
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

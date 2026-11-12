--!strict
-- Every line the house speaks (§5). Short, specific, dry, warm. No exclamation marks.
-- Never "game", "level", "loot", "match", "battle".

local Voice = {}

Voice.Concierge = {
	speaker = "THE CONCIERGE",
	firstVisit = "Good evening. Build your fortune, master the Maison, become the wealthiest.",
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
		velvet = "The Luxe Lounge. Train your Stride, then through the arch to Steal a Luxe.",
		obsidian = "The Basement Stair. Sixteen stages down to the Treasury.",
		midnight = "The Executive's Anteroom. The Quartermaster will see to your sidearm.",
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
		next = "What should I do next?",
		games = "Show me every game",
		find = "Find a place",
		ask = "I have a question",
		walk = "Walk me there",
		now = "Take me there now",
		back = "Something else",
	},
	-- Finding a place: walking (the gold arrows on the floor) unless the guest asks to be taken.
	find = {
		which = "Where would you like to go?",
		how = "{place}. Shall I show you the way, or take you there now?",
		showing = "Follow the gold arrows on the floor. They'll fade when you're there.",
		leading = "This way. I'll walk you.",
	},
	-- What to do next, from what the guest has done (server/Staff/Concierge).
	recommend = {
		luxe = "Start with Steal a Luxe, through the Luxe Lounge. It's the quickest way to grow your Estate.",
		upgrade = "Your purse could buy a bigger bag in the Luxe Lounge. More in the bag, more in the Estate.",
		basement = "Try the Maison Basement, down the Basement Stair. The Treasury pays well, and brings an invitation upstairs.",
		executive = "You hold an invitation. Take your free stun pistol from the Quartermaster, then ride his lift up: it's in the Executive's Anteroom, off the Foyer.",
		quartermaster = "The Executive Suite needs an invitation. Finish the Maison Basement, carry {inviteHaul} of loot out of Steal a Luxe in one trip, or buy one from the Quartermaster for {invitePrice} Gilt.",
		island = "You've the Fortune for Luxury Island now. The Island Key is at the Jet Lounge, on the Terrace.",
		gala = "Bring a friend to the Grand Ballroom, through the great doors at the far end of the Ballroom: trivia, the Runway, the Daily Arena and the dance floor.",
		climb = "{gap} more and you'll be {rank}. Every haul, purse and prize counts.",
	},
	-- Answers, from how the house really works (the numbers are filled in from its settings).
	questions = {
		{ id = "rich", q = "How do I get rich?", a = "Everything you own counts toward your Fortune: Gilt, Gems, your collection, your Suite and your Estate. The attractions grow your Estate fastest." },
		{ id = "estate", q = "What is my Estate?", a = "What you've banked and won in the attractions. It only ever grows, and a fifth of every haul comes to your purse in Gilt as well." },
		{ id = "invite", q = "How do I get into the Executive Suite?", a = "You need an invitation. Each of these gets you one: finish the Maison Basement; carry loot worth {inviteHaul} or more out of Steal a Luxe in a single trip; or buy one from the Quartermaster in the Anteroom for {invitePrice} Gilt. Take your free stun pistol from him too, then ride the lift up." },
		{ id = "stride", q = "What does Stride do?", a = "It makes you faster in Steal a Luxe, and only there: {stride}% a level. Walk the treadmills in the Luxe Lounge to train it." },
		{ id = "caught", q = "What if a guard catches me?", a = "Everything in your bag is lost and you're shown out to the courtyard. What you've already banked is safe." },
		{ id = "skip", q = "Can I skip a Basement stage?", a = "Yes, and the deeper the stage, the more it costs: {skipGems} Gems for the first, {skipStep} more for each stage after it. Skips bought with Robux work too, more of them further down. A skipped run isn't timed for the boards, and the stage you skip pays nothing." },
		{ id = "island", q = "How do I get to Luxury Island?", a = "By the private jet, from the Jet Lounge on the Terrace. The Island Key is for a Tycoon: {islandGilt} Gilt or {islandGems} Gems, yours for good. Five pearls lie in its lagoon every day." },
		{ id = "gala", q = "What's in the Grand Ballroom?", a = "Through the great doors at the far end of the Ballroom: the dance floor and its jukebox, Luxury Trivia, the Runway's themed shows, the Daily Arena, three photo sets, the Exchange and the Hall of Fame. A little Gilt for all of it, up to {galaGilt} a day." },
		{ id = "trade", q = "How do I trade?", a = "At the Exchange's stands in the Grand Ballroom, or the Trade key on a guest's card: Gilt, Gems, brainrots and curios. You both see every offer, and nothing changes hands until you both confirm the very same trade." },
		{ id = "boards", q = "Where are the boards?", a = "Tap your Fortune, under your Gilt: the Wealthiest in this house, this week and of all time. The Basement's best times are at the lectern on the Basement Stair." },
		{ id = "gems", q = "What are Gems for?", a = "The Gem Shop, the golden treadmill, a Basement skip and the Cabinet's curios. Gems come only from a Gem pack in the shop (Robux) or a trade with another guest: nothing in the house pays them out, so every game pays Gilt." },
	},
	whichQuestion = "Ask me anything.",
	newsOffer = "The house has changed since you were last here: your Fortune, and three new attractions. Shall I show you?",
	newsYes = "Show me",
	newsLater = "Later",
	newsLaterLine = "Of course. Ask me for the tour any time.",
	tourOffer = "Welcome to Maison Noir, where everyone is here to become the wealthiest. Shall I show you round? It's quick.",
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
		line = "Build your fortune, master the Maison, become the wealthiest. Everything you own counts: your Fortune is under your Gilt.",
	},
	{
		stop = "salon",
		place = "salonDoor",
		title = "The Salon",
		line = "Sort fine things into their cases for Gilt, at your own pace: sit at a table and press E. Tonight's table is here too.",
	},
	{
		stop = "salon",
		place = "velvetDoor",
		title = "Steal a Luxe",
		line = "Through the Luxe Lounge: slip into a great residence, carry out what you can and bank it at the car before the guards catch you. Train your Stride on the treadmills first.",
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
		line = "Your collection, kept and shown: every piece and brainrot here counts toward your Fortune. The Archivist keeps your badges.",
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
		stop = "boutique",
		place = "obsidianDoor",
		title = "The Maison Basement",
		line = "Down the Basement Stair: sixteen stages of jumps, steam and lasers to the Treasury. Each part's end pays its purse, and your best time goes on the boards.",
	},
	{
		stop = "boutique",
		place = "midnightDoor",
		title = "The Executive Suite",
		line = "By invitation only: clear the Basement or bank a great haul for one. Take your free sidearm from the Quartermaster, then beat the Executive in his office.",
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
		line = "Lights Out every 20 minutes: the last lamp still lit wins the pot. Through the great doors at the far end, the Grand Ballroom: dancing, trivia, the Runway and more, best with friends.",
	},
	{
		stop = "terrace",
		place = "terraceDoor",
		title = "The Terrace",
		line = "A bar, a fire pit and loungers under the stars, and the Jet Lounge: the private jet to Luxury Island.",
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
		line = "Earn in the attractions, grow your Estate, climb the wealth ranks and the Wealthiest boards. Ask me anything at my lectern.",
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
	velvetDoor = "The Luxe Lounge",
	obsidianDoor = "The Basement Stair",
	midnightDoor = "The Executive's Anteroom",
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
		-- (`short`: the same step in fewer words, for a phone on its side, where the three stand side by side.)
		{ title = "Meet the Concierge", line = "Follow the gold arrow and pick Show me the house. He walks you round and teaches you the game.", short = "Follow the gold arrow. He shows you the house." },
		{ title = "Sit at a table", line = "Any table in the Salon. Walk up to a chair and take a seat.", short = "Any table in the Salon. Walk up and sit." },
		{ title = "Sort the treasures", line = "Put each piece in its case: watches in Watches, rings in Jewelry, gold in Money. Every right one earns Gilt.", short = "Each piece into its case. Every right one earns Gilt." },
	},
	after = "For your first half hour, every Gilt you earn counts double. Spend it on your Suite, your look and more.",
	go = "Show me the way",
	table = "Straight to a table",
}

-- Welcome back (UI/WelcomeBack): a returning guest's one card, once they've arrived: what's waiting
-- for them (tonight's present, their brainrots' tip jar) and what's new in the house since they
-- were last here.
Voice.WelcomeBack = {
	title = "Welcome back",
	heading = "Good to see you, %s",
	night = "Your %s night at the house.",
	present = { title = "Tonight's present is waiting", line = "The Evening Calendar: a present every day you come.", key = "Open" },
	jar = { title = "Your brainrots earned %s Gilt", line = "Their tip jar filled while you were away.", key = "Collect", done = "Collected" },
	news = "New in the house",
	go = "Let's go",
}

-- What's new in this build, told once to each returning guest (Welcome back). Only shown while
-- `build` is the build that's playing, so old news never shows as new.
Voice.WhatsNew = {
	build = 78,
	lines = {
		"Steal a Luxe has three new wings: the Drop Room (a loft, and a helicopter on the roof), the Garage (the van is a way out) and a Secret Stash. Mind the cameras and the lasers.",
		"The Maison Basement turns over every five minutes: Double Time, Blackout and The Gauntlet, each with two secrets. Your run keeps its course to the Treasury.",
		"The Executive shows every attack before it comes. Beat him, then make the lift within a minute for a clean getaway.",
		"The Drop, the house's street-luxury line, is in the Boutique: neon trails, black chrome nameplates and more.",
	},
}

-- How to play (the key at the top right): the whole game, explained step by step in plain words,
-- on five pages: the basics, sorting (the six cases, pictured), the rooms (each with a Go key that
-- takes you there), Gilt and the Shop, and the extras.
export type GuideItem = { title: string, line: string, how: string?, win: string?, key: string?, action: string?, place: string? }
-- Tips: short words at the foot of the screen, one at a time and never often (UI/Hints), for the
-- new and the regular alike. `after`: seconds into the visit before it may show; `sat`: how many
-- times the guest has sat at a table first; `every`: seconds before it may show again (0: once a
-- visit). What decides each one is in UI/Hints.
export type Hint = { id: string, line: string, after: number?, sat: number?, every: number? }
Voice.Hints = {
	label = "TIP",
	list = {
		{ id = "newcomer", line = "New here? Sit at any table in the Salon to start sorting. How to play, top right, explains it all.", after = 45 },
		{ id = "keys", line = "When you're holding a piece, keys 1 to 6 drop it straight into a case.", sat = 1 },
		{ id = "tap", line = "Tap a piece, then tap its case. No need to drag.", sat = 1 },
		{ id = "streak", line = "Right pieces in a row raise your combo. One wrong case resets it.", sat = 2 },
		{ id = "rooms", line = "Steal a Luxe, the Basement and the Executive Suite grow your Fortune fastest. Press Play to see every game.", sat = 3 },
		{ id = "abuse", line = "Admin Abuse: everything pays double. Find the Gold Tile and the Piñata in the Foyer.", every = 600 },
		{ id = "grandPrix", line = "The Grand Prix is open: get in any car on the street and press Race.", every = 720 },
		{ id = "ballroom", line = "The Ballroom is open: up the Grand Stair, one winner takes the pot.", every = 900 },
		{ id = "holiday", line = "A holiday game is on. Its key is at the foot of the left dock.", every = 900 },
		{ id = "shop", line = "You have Gilt to spend: Shop, top right, has table styles, auras and more.", after = 240, every = 1200 },
		{ id = "suite", line = "Your Suite is yours to decorate. The Suites key on the left takes you there.", after = 420 },
		{ id = "collection", line = "Brainrots you find earn Gilt every hour, even while you're away. See them in Collection.", after = 600 },
		{ id = "tonight", line = "Tonight's table: one try a day, the same pieces for every guest. The card at the top of your screen seats you at it.", after = 900 },
	} :: { Hint },
}

-- A holiday hunt on the event strip (UI/EventBanner): how many are still hidden, and whether its
-- golden prize has been found.
Voice.Hunts = {
	left = "%d %s LEFT",
	hidden = "%s still hidden",
	found = "%s found",
	halloween = { one = "PUMPKIN", many = "PUMPKINS", prize = "golden pumpkin" },
	thanksgiving = { one = "TURKEY", many = "TURKEYS", prize = "golden turkey" },
	christmas = { one = "PRESENT", many = "PRESENTS", prize = "golden bell" },
	valentine = { one = "LOVE LETTER", many = "LOVE LETTERS", prize = "heart of gold" },
	stPatrick = { one = "CLOVER", many = "CLOVERS", prize = "pot of gold" },
	easter = { one = "EGG", many = "EGGS", prize = "golden egg" },
} :: { [string]: any }

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
		lead = "Maison Noir is a grand house full of games. Play them to earn Gilt (the house's gold coins), grow your Fortune and become the wealthiest guest in the house. Spend what you earn on looks, your Suite and your collection.",
		heading = "Your first five minutes",
		steps = {
			{ title = "See every game", line = "Press the gold Play key at the top right. Each game has a card: what it is, how to play it, and a key that takes you there.", key = "Open it", action = "directory" },
			{ title = "Start with Steal a Luxe", line = "Its door is the Luxe Lounge, off the Foyer. Pick up treasures, keep out of the guards' sight, and carry them to the getaway car. Every trip grows your Fortune.", place = "velvet", key = "Take me there" },
			{ title = "Or sit at a table", line = "In the Salon, sort treasures into their cases for Gilt, with no clock. Walk up to any chair and press E. On a phone, tap Sit.", key = "See how", action = "sorting" },
			{ title = "Spend it", line = "Press Shop at the top right for looks, cars and more. Upstairs, your own Suite is yours to furnish.", key = "Shop", action = "shop" },
		} :: { GuideItem },
		after = "Lost at any time? Press How to play or Play at the top right, or talk to the Concierge by the front door.",
	},
	sorting = {
		lead = "Every treasure belongs in one of six cases along the bottom of the table. Each case shows a piece that goes in it.",
		heading = "Good to know",
		tips = {
			{ title = "Moving a piece", line = "Drag it onto its case. On a phone you can also tap the piece, then tap the case. On a keyboard, keys 1 to 6 pick the cases." },
			{ title = "A wrong case", line = "It only breaks your streak. Shrug it off and sort the next one." },
			{ title = "Not sure where it goes?", line = "In the Salon, wait a moment and a thread of gold runs from the piece to its case." },
			{ title = "Rounds", line = "Clear the table to finish a round. Then pick Next round (more pieces, more points) or Bank the run to take your Gilt now." },
			{ title = "Clocks", line = "The Salon has no clock: take your time. Tonight's table has one: gentle on some nights, brisk or hard on others." },
		} :: { GuideItem },
		key = "Try it at a table",
	},
	rooms = {
		lead = "Every place in the house: what it is, how it works, and what you get. Go takes you straight there.",
		heading = "Where to sort",
		sort = {
			{ place = "salon", title = "The Salon", line = "The tables, and the calmest room: no clock at all.", how = "Sit at any table and sort at your own pace. The best place to learn.", win = "Gilt for every run you bank." },
		} :: { GuideItem },
		-- (The games: drawn from shared/Directory, the same words as the Maison Directory's cards.)
		headingGames = "The games",
		heading2 = "Around the house",
		visit = {
			{ place = "concierge", title = "The Concierge", line = "Stands by the front door, ready to help.", how = "Speak to him and pick Show me the house: he walks you round every room and explains it." },
			{ place = "boutique", title = "The Boutique", line = "The house's shop for looks.", how = "Looks, table styles, lamps and trails for Gilt (a few for Robux, always with the price shown first). The Wardrobe beside it is where you wear what you own." },
			{ place = "vault", title = "The Vault", line = "Your collection, kept for good.", how = "Every piece you've sorted stands on its shelves. The console under the four domes shows your curios, how complete your collection is, and who may look round. The Archivist at the desk keeps your badges and records." },
			{ place = "terrace", title = "The Terrace", line = "A rooftop to relax on, and the jet to the island.", how = "A bar with treats, a fire pit and loungers under the stars. The Jet Lounge's arch flies Island Key holders to Luxury Island." },
			{ place = "suite", title = "Your Suite", line = "Your own private rooms upstairs.", how = "Ring the bell inside to furnish them. Only you can go in, unless you invite friends with the Suites key." },
		} :: { GuideItem },
	},
	gilt = {
		lead = "Gilt is the house's money. You earn it in every game, and spend it on things you keep.",
		items = {
			{ title = "Gilt", line = "Earned everywhere: the tables, Steal a Luxe, the Basement, the Grand Ballroom, the island and the races.", how = "Your Gilt is shown at the top left of the screen." },
			{ title = "Gems", line = "Rarer than Gilt.", how = "Bought with Robux (a Gem pack in the shop), or traded with another guest. No game, race, present or streak pays them: those all pay Gilt. Spend Gems in the Gem Shop and the Cabinet." },
			{ title = "Your Fortune", line = "Everything you own, added up.", how = "Your Gilt, Gems, collection, Suite and your Estate (all you've banked in the games). It's under your Gilt: tap it for the Wealthiest boards, which count only what you earned, never what was bought." },
			{ title = "The Shop", line = "Everything for sale, in one place.", how = "Looks, table styles, lamps and more for Gilt. Some special things are for Robux, always with the price shown first.", key = "Shop", action = "shop" },
			{ title = "Levels and badges", line = "Everything you do counts.", how = "Sorting, racing and playing earn XP and raise your level. Badges in the Badge Book mark what you've done." },
			{ place = "tonight", title = "Tonight's table", line = "Optional: once a day, everyone plays the same table.", how = "Press Play and you're seated at a free Salon table: five rounds against tonight's clock, with the same pieces for every guest in every server. One try a day; the best scores go up on the board in the Foyer.", key = "Play", action = "nightly" },
		} :: { GuideItem },
	},
	extras = {
		lead = "Big games and fun on the side. All optional, all worth a try.",
		items = {
			{ place = "grandPrix", title = "The Grand Prix", line = "Ultra-luxury cars on the street outside.", how = "Walk up to any car and press E to drive (or F to ride along with a friend). Every 10 minutes a race opens: press Race, line up on the grid, wait for the five lights, then three laps. Reset puts a stuck car right.", win = "Gilt for the top three, the most for the winner." },
			{ place = "ballroom", title = "The Ballroom", line = "Lights Out: the big game, every 20 minutes.", how = "When it opens, sit in any chair before the countdown ends. Then everyone sorts at once. Your table holds 16 pieces: go over for 3 seconds and your lamp goes out. Guests watching can send a sabotage or a Shield to a table; nobody playing can buy either, and every table starts with one Shield, free.", win = "The last lamp still lit wins the whole pot of Gilt." },
			{ place = "library", title = "The Library", line = "Tête-à-Tête: one on one.", how = "Sit at a Library table to face another player. You both get exactly the same pieces; three in a row sends a parcel of lookalikes across to them.", win = "First to win three hands wins the match." },
			{ title = "Curios and brainrots", line = "Collectibles found as you play.", how = "They turn up at the tables. Open Collection (left of the screen) to see them, and Trade to swap with friends safely.", win = "Brainrots earn you Gilt every hour." },
			{ title = "Holiday games", line = "In their season, the house throws a party.", how = "Trick or Treat on Hallows Lane, the Turkey Round-Up, Santa's Sleigh, the Great Egg Hunt and the Luck of the Irish.", win = "Gifts, Gilt and the holiday's own curios." },
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
	-- (The house's games a guest hasn't been into yet, one at a time, in this order.)
	try = {
		{ id = "luxe", place = "velvet", line = "Play Steal a Luxe: carry out a fortune and bank it", how = "Its way in is the Luxe Lounge, off the Foyer. Press Play at the top right for every game." },
		{ id = "basement", place = "obsidian", line = "Go down the Maison Basement: sixteen stages to the Treasury", how = "Its stair is off the Foyer. Clear it for an invitation to the Executive Suite." },
		{ id = "gala", place = "ballroom", line = "Visit the Grand Ballroom: trivia, the Runway, the Daily Arena", how = "Through the great doors at the far end of the Ballroom." },
	},
	best = "Beat your best run in {room}: {points} points",
	bestHow = "Any table in the Salon.",
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

--!strict
-- Every line the house speaks (§5). Short, specific, dry, warm. No exclamation marks.
-- Never "game", "level", "loot", "match", "battle".

local Voice = {}

Voice.Concierge = {
	speaker = "THE CONCIERGE",
	firstVisit = "Good evening. Build your Fortune, master the Maison, become the richest guest.",
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
		velvet = "The Luxe Lounge. Train your Speed, then through the arch to Steal a Luxe.",
		obsidian = "The Basement Stair. Thirty-two stages down to the Treasury.",
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
	ballroomWay = "Up the Grand Stair, the tall doors on your right. Press Join for Lights Out.",
	closedRoom = "Not tonight. Steal a Luxe is open.",
	-- (Build 98: never a nudge to the Salon: the games first.)
	lost = "Steal a Luxe is through the Luxe Lounge, if you'd like me to walk you.",
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
		ballroom = "The Grand Ballroom",
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
		luxe = "Start with Steal a Luxe, through the Luxe Lounge: every piece shows the exact Gilt it pays.",
		upgrade = "Your Gilt could buy a bigger bag in the Luxe Lounge. More in the bag, more Gilt each time you bank.",
		basement = "Try the Maison Basement, down the Basement Stair. The Treasury pays well, and brings an invitation upstairs.",
		executive = "You hold an invitation. Take your free stun pistol from the Quartermaster, then ride his lift up: it's in the Executive's Anteroom, off the Foyer.",
		quartermaster = "The Executive Suite needs an invitation. Finish the Maison Basement, carry {inviteHaul} of loot out of Steal a Luxe in one trip, or buy one from the Quartermaster for {invitePrice} Gilt.",
		island = "You've the Fortune for Luxury Island now. The Island Key is at the Jet Lounge, on the Terrace.",
		gala = "Bring a friend to the Grand Ballroom, through its doors in the Club hall, up the Grand Stair: the Flex Studio, trivia, the Runway, the Daily Arena and the dance floor.",
		climb = "{gap} more and you'll be {rank}. Every haul, purse and prize counts.",
	},
	-- Answers, from how the house really works (the numbers are filled in from its settings).
	questions = {
		{ id = "rich", cat = "money", q = "How do I get rich?", a = "Everything you own counts toward your Fortune: your Gilt, Gems, collection, Suite, and all you've banked and won in the attractions. The attractions grow it fastest." },
		{ id = "estate", cat = "money", q = "What is my Fortune made of?", a = "Your Gilt, your Gems, your collection, your Suite, and the worth of all you've banked and won in the attractions (that part only ever grows). Every reward shows the exact Gilt it pays before you earn it." },
		{ id = "invite", cat = "attractions", place = "midnight", q = "How do I get into the Executive Suite?", a = "You need an invitation. Each of these gets you one: finish the Maison Basement; carry loot worth {inviteHaul} or more out of Steal a Luxe in a single trip; or buy one from the Quartermaster in the Anteroom for {invitePrice} Gilt. Take your free stun pistol from him too, then ride the lift up." },
		{ id = "stride", cat = "attractions", place = "velvet", q = "What does Speed do?", a = "It makes you faster in Steal a Luxe, and only there: {stride}% a level. Walk the treadmills in the Luxe Lounge to train it." },
		{ id = "caught", cat = "attractions", place = "velvet", q = "What if a guard catches me?", a = "Everything in your bag is lost and you're shown out to the courtyard. What you've already banked is safe." },
		{ id = "skip", cat = "attractions", place = "obsidian", q = "Can I skip a Basement stage?", a = "Yes, and the deeper the stage, the more it costs: {skipGems} Gems for the first, {skipStep} more for each stage after it. A skip bought with Robux is one stage at any depth. A skipped run isn't timed for the boards, but the stage you skip still pays its Gilt." },
		{ id = "island", cat = "house", place = "terrace", q = "How do I get to Luxury Island?", a = "By the private jet, from the Jet Lounge on the Terrace. The Island Key is for a Tycoon: {islandGilt} Gilt or {islandGems} Gems, yours for good. Every day five new pearls lie in its lagoon and the sunset is toasted at the Lookout, a little more with friends. The Jet Lounge's card shows what each pays." },
		{ id = "gala", cat = "house", place = "ballroom", q = "What's in the Grand Ballroom?", a = "Through its doors in the Club hall, up the Grand Stair: the Flex Studio (shoot a reel of something you own; guests like it on the Flex Wall), the dance floor and its jukebox, Luxury Trivia, the Runway's themed shows, the Daily Arena, three photo sets, the Exchange and the Hall of Fame. A little Gilt for all of it, up to {galaGilt} a day." },
		{ id = "trade", cat = "collection", place = "ballroom", q = "How do I trade?", a = "At the Exchange's stands in the Grand Ballroom, or the Trade key on a guest's card: Gilt, Gems, brainrots and curios. You both see every offer, and nothing changes hands until you both confirm the very same trade." },
		{ id = "boards", cat = "money", q = "Where are the boards?", a = "Tap your Fortune, under your Gilt: the Wealthiest in this house, this week and of all time. The Basement's best times are at the lectern on the Basement Stair." },
		{ id = "auction", cat = "house", place = "library", q = "What is the Grand Auction?", a = "In the Library: the week's rare lots, bid for in Gilt or Gems by guests in every server at once. A bid is held from your purse while it stands; outbid, it comes straight back. The highest bid when the week closes wins, and the piece is delivered to you wherever you are." },
		{ id = "brainrots", cat = "collection", q = "What are brainrots?", a = "The meme set of curios, each a character of its own. Put up to three in your squad (three more with the Penthouse): they fill a tip jar with Gilt every hour, and the one you choose walks beside you. Out of the game they keep earning (AFK mode): a fifth as fast, for up to 12 hours, so there's Gilt waiting when you come back. More of the same one gives it stars." },
		{ id = "afk", cat = "collection", q = "Do I earn while I'm away?", a = "Yes, with brainrots. Put them in your squad: in the house they fill their tip jar every hour, resting or not. Out of the game they keep earning a fifth as fast, for up to 12 hours. Come back and collect it from Welcome back." },
		{ id = "luckyBoxes", cat = "collection", place = "ballroom", q = "What are Luxe Lucky Boxes?", a = "Three gift boxes on a gold-lit dais in the Grand Ballroom's Entrance Hall, just inside its doors. Each opens to one brainrot: Rare or better, Epic or better, or Legendary or better. Open one for Gems (100, 250 or 565), or save up Gilt for one (25,000, 62,500 or 140,000). The odds of every brainrot are shown before you open it and add up to 100%, and a counter shows how many opens until a rarer one is certain. Everything in them is also found free at the tables. (Only where Roblox allows paid random items.)" },
		{ id = "hotbar", cat = "collection", q = "What's in my hotbar?", a = "What you carry: the stun pistol once the Quartermaster gives it you (it fires only in the Executive Suite's fight), a decoy you've packed, the brainrots in your squad and the curios you've starred. Hold a brainrot or a curio and click to flex it for everyone near you." },
		{ id = "suite", cat = "house", place = "suite", q = "How do I make my Suite mine?", a = "Ring the bell inside your Suite to furnish it, piece by piece, where you like. Its cases show off your finest curios, and friends can visit from the Suites list." },
		{ id = "trophies", cat = "house", place = "suite", q = "What are House Trophies?", a = "Six pieces for your Suite that aren't sold for Gilt, Gems or Robux: each is earned by playing one of the house's games. A crown jewel carried out of Steal a Luxe, the Treasury reached in the Basement, the Executive beaten, a Grand Prix won, the Daily Arena won, a lot won at the Grand Auction. Once earned it's yours for good: ring the bell in your Suite to place it." },
		{ id = "looks", cat = "house", place = "boutique", q = "What are looks and trails for?", a = "Style, never score: nameplates, trails, emotes and victory flourishes from the Boutique (auras and titles from the Gem Shop). Wear them at the Wardrobe. Your flourish even colours your flexes." },
		-- (Build 87: more, each from how the house really works, in five kinds; "place" is where
		-- Guide me there walks the guest.)
		{ id = "first", cat = "start", q = "What should I do first?", a = "Steal a Luxe, through the Luxe Lounge, is a good first: it grows your Fortune quickest. Or ask me what to do next, and I'll look at what you've done so far." , place = "velvet" },
		{ id = "everyGame", cat = "start", q = "How do I see every game?", a = "Press Play at the top of your screen: the Maison Directory shows every attraction, what it pays and how to get in." },
		{ id = "tourAgain", cat = "start", q = "Can I see the tour again?", a = "Any time: speak to me and choose Show me the house. I'll walk you round again, and you can end it whenever you like." },
		{ id = "collectionKey", cat = "start", q = "Where is my Collection?", a = "The gold Collection key on the left of your screen (C on a keyboard): your brainrots, every curio you own, your Gems and your trades. Fold the other keys away and the Collection keeps a key of its own." },
		{ id = "salon", cat = "house", place = "salon", q = "What happens in the Salon?", a = "Sort fine things into their cases for Gilt, at your own pace: sit at a table and press E. Right ones in a row raise your combo; bank the run for Gilt. Tonight's table is there too: one try a day, the same pieces for every guest." },
		{ id = "luxeHow", cat = "attractions", place = "velvet", q = "How do I play Steal a Luxe?", a = "Through the Luxe Lounge. Inside, hold E on a treasure to lift it: the fuller your bag, the slower you walk. Security sleeps until you lift something; then a guard comes after you. Carry it out to the getaway car to bank it for good." },
		{ id = "execChallenge", cat = "attractions", place = "midnight", q = "What's the Executive Suite's challenge?", a = "Each run of the Suite has one, the same for everyone in it, said as you go up: Ghost (beat him never seen in the hallway), Steady Hand (no wrong try of yours at the vault door), Untouchable (lose none of your health, and no revive) or Swift Takeover (beat him within three minutes of the door opening). Meet it and it pays its own Gilt when he's beaten. Each run has its own look too, and some walk his guards the other way round." },
		{ id = "islandStanding", cat = "attractions", place = "terrace", q = "What is Island Standing?", a = "Everything you do on Luxury Island, counted: a pearl is a point, a sunset toasted three, each postcard spot two, each day you fly in one. Each rank (Weekender, Islander, Patron of the Island, The Island's Own) pays its Gilt once. Islanders earn the Starlit lights and Patrons the Island Patron livery: never sold. Your standing is on the Jet Lounge's board." },
		{ id = "showtime", cat = "house", place = "ballroom", q = "What is Showtime?", a = "Every half hour, at twenty past and ten to, one of the Grand Ballroom's party games has its Showtime for eight minutes: Luxury Trivia, then the Runway, then the Daily Arena, in turn. A card on your screen says which, with a key that takes you there. Play a round of it while it's on and it pays {showtimeGilt} Gilt, once each Showtime. The games are open the rest of the time too: Showtime just brings everyone together." },
		{ id = "hourlyDrop", cat = "house", place = "hourlyDrop", q = "What is the Hourly Drop?", a = "Every hour, on the hour, a courier's case comes down onto the black marble plinth in the Foyer, west of the red runner, and stays {dropMinutes} minutes. Stand by it and open it, once each hour: {dropGilt} Gilt, and the first time you open a case holding that hour's piece, the piece is yours too. Six pieces take turns, each back every six hours. The sign over the plinth counts down to the next by the house's clock." },
		{ id = "luxeSleepers", cat = "attractions", place = "velvet", q = "Who's asleep in Steal a Luxe?", a = "The night staff: eight of them, each asleep beside a treasure, from the footman in the Garden Hall to the master of the house in his bedroom. Get close and they stir, quicker if you're moving, carrying something or lifting a piece near them; Quiet Shoes from the Luxe Lounge help. Wake one after you've lifted something and they call the guards (the master locks his bedroom down); wake one empty-handed and they only grumble. Step away and they settle again." },
		{ id = "basementHow", cat = "attractions", place = "obsidian", q = "How does the Basement work?", a = "Down the Basement Stair: thirty-two stages of jumps, steam and lasers to the Treasury. Step on every checkpoint pad; fall, and you're back at the last one. The gold chevrons on each pad point the way on. Each chamber pays at its way out, and the Treasury's chest pays the most." },
		{ id = "executiveHow", cat = "attractions", place = "midnight", q = "How does the Executive's fight work?", a = "Through the code door, in his Office: shoot the three blue generators to bring his shield down, stun his four bodyguards, then stun the Executive. A ring under him is a shockwave (jump it), a lane is his dash (step aside), a raised hand is briefcases (keep moving)." },
		{ id = "pistol", cat = "attractions", place = "midnight", q = "Where do I get the stun pistol?", a = "Free, from the Quartermaster at his desk in the Executive's Anteroom. It goes in your hotbar, and the lift up won't take you without it. It fires only in the Office's fight." },
		{ id = "gilt", cat = "money", q = "What is Gilt for?", a = "Gilt is the house's money, and every game pays it: the Boutique's boosters, brainrots and nameplates, bigger bags in the Luxe Lounge, an invitation upstairs from the Quartermaster, the Island Key and more." },
		{ id = "gems", cat = "money", q = "What are Gems for?", a = "The Gem Shop, the golden treadmill, a Basement skip and the Cabinet's curios. Gems come only from a Gem pack in the shop (Robux) or a trade with another guest: nothing in the house pays them out, so every game pays Gilt." },
	},
	whichQuestion = "Ask me anything. What's it about?",
	-- (Build 87) The kinds of question, in order.
	qaCategories = {
		{ id = "start", name = "Getting started" },
		{ id = "attractions", name = "The attractions" },
		{ id = "money", name = "Gilt, Gems and your Fortune" },
		{ id = "collection", name = "Brainrots and your collection" },
		{ id = "house", name = "Around the house" },
	},
	qaSearch = "Search every question",
	qaGuide = "Guide me there",
	qaAnother = "Another question",
	qaBack = "Back",
	newsOffer = "The house has changed since you were last here: your Fortune, and three new attractions. Shall I show you?",
	newsYes = "Show me",
	newsLater = "Later",
	newsLaterLine = "Of course. Ask me for the tour any time.",
	-- (Build 93) Before the first tour: the house's welcome gift.
	giftFirst = "Good evening, {name}, and welcome to the Maison. Before anything else, a gift from the house: choose your first brainrot. It earns you Gilt every hour from tonight on.",
	-- (Build 102) A first visit: welcomed, never pushed into a tour.
	firstWelcome = "Good evening, {name}, and welcome. I'm the Concierge: ask me anything, any time. For a walk round the house, press House Tour.",
	firstTour = "Good evening, {name}, and welcome to the Maison. I'm the Concierge. Everyone here is out to become the richest guest; let me show you round first. Follow me and the gold trail. You can end the tour whenever you like.",
	tourOffer = "Welcome to the Maison, where everyone is here to become the richest guest. Shall I show you round? It's quick.",
	tourYes = "Show me the house",
	tourSkip = "Show me the attractions",
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
		-- (Build 97: one line, read at a glance: what you do, and what for. The gold key under it
		-- goes straight into Steal a Luxe.)
		line = "Steal treasure. Bank it. Grow your Fortune. The richest guest tops the boards: start with Steal a Luxe.",
	},
	{
		stop = "salon",
		place = "salonDoor",
		title = "The Salon",
		line = "Sort fine things into their cases for Gilt, at your own pace: sit at a table and press E. Tonight's table is here too.",
	},
	{
		stop = "salon",
		place = "salonDoor",
		title = "How to sort",
		line = "Sit and press E: pieces are dealt to your felt. Drag or tap each into its case, watches in Watches, rings in Jewelry, gold in Money. Right ones in a row raise your combo; then bank the run for Gilt.",
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
		stop = "luxe",
		place = "velvetDoor",
		title = "Steal a Luxe",
		line = "Through the Luxe Lounge: slip into a great residence, carry out what you can and bank it at the car before the guards catch you. Train your Speed on the treadmills first.",
		attraction = "luxe",
		quick = true,
	},
	{
		stop = "luxe",
		place = "velvetDoor",
		title = "How to play Steal a Luxe",
		line = "Inside, hold E on a treasure to lift it: the fuller your bag, the slower you walk. Keep out of the guards' and cameras' sight, or the bag is lost. Carry it out to the getaway car to bank it for good.",
		attraction = "luxe",
		quick = true,
	},
	{
		stop = "vault",
		place = "vault",
		title = "Your private Vault",
		line = "Behind this door, your own Vault: your collection, kept and shown, and every piece in it counts toward your Fortune. Nobody else can walk in. Press E at the elevator here: 5.5 seconds up to your Vault or your Suite.",
	},
	{
		-- (Build 87: the guiding hand points at the Collection key while this card is up.)
		stop = "vault",
		place = "vault",
		title = "Your Collection",
		line = "Everything you own is a tap away too: the gold Collection key on the left of your screen. Your brainrots, every curio you own, your Gems and your trades.",
		hand = "collection",
	},
	{
		stop = "boutique",
		place = "counter",
		title = "The Boutique",
		line = "Spend your Gilt here: boosters, four new brainrots a day, nameplates that shine. The gold Shop key at the top of your screen opens it from anywhere.",
	},
	{
		stop = "boutique",
		place = "mirror",
		title = "The Wardrobe",
		line = "Wear what you own: your look, your nameplate, your table, your lamp and your trail.",
	},
	{
		stop = "basement",
		place = "obsidianDoor",
		title = "The Maison Basement",
		line = "Down the Basement Stair: thirty-two stages of jumps, steam and lasers to the Treasury. Each part's end pays its purse, and your best time goes on the boards.",
		attraction = "basement",
		quick = true,
	},
	{
		stop = "basement",
		place = "obsidianDoor",
		title = "How to play the Basement",
		line = "Jump, climb and dodge down thirty-two stages. Step on every checkpoint pad: fall, and you're back at the last one. Each chamber pays at its way out, the Treasury's chest pays the most, and clearing it earns an invitation upstairs.",
		attraction = "basement",
		quick = true,
	},
	{
		stop = "executive",
		place = "midnightDoor",
		title = "The Executive Suite",
		line = "By invitation only: clear the Basement, bank a great haul, or buy one from the Quartermaster for Gilt. Take your free stun pistol from him too: it goes in your hotbar, and fires in the Suite's fight.",
		attraction = "executive",
		quick = true,
	},
	{
		stop = "executive",
		place = "midnightDoor",
		title = "How to play the Executive Suite",
		line = "Ride the lift up. Read one digit at each of the four terminals, out of the cameras' and guards' sight, and type the code at the door. Inside, shoot the three generators, stun his bodyguards, then stun the Executive.",
		attraction = "executive",
		quick = true,
	},
	{
		-- (Build 102) Out of the front doors.
		stop = "executive",
		title = "The Grand Prix",
		line = "Out of the front doors, on the street: ultra-luxury cars at the kerb, and the Grand Prix round the block when it opens. Your best times go on the boards.",
		quick = true,
	},
	{
		stop = "library",
		place = "libraryDoor",
		title = "The Grand Auction",
		line = "Up here in the Library: the week's rare lots, bid for in Gilt or Gems by guests in every server at once. Outbid, your bid comes straight back; the highest when the week closes wins.",
		quick = true,
	},
	{
		stop = "ballroom",
		place = "ballroomDoor",
		title = "The Grand Ballroom",
		line = "Through these doors, the Grand Ballroom: the Flex Studio, the dance floor, trivia, the Runway and more, best with friends. Every 20 minutes or so, Lights Out on its dance floor: the Chairs, the dark, the Spinner's duel, and the last lamp lit takes the pot.",
		attraction = "gala",
		live = "ballroom",
		quick = true,
	},
	{
		stop = "terrace",
		place = "terraceDoor",
		title = "The Terrace",
		line = "A bar, a fire pit and loungers under the stars. The private jet to Luxury Island boards here, at the Jet Lounge.",
		quick = true,
	},
	{
		stop = "suite",
		place = "suiteDoor",
		title = "Your private Suite",
		line = "Your own rooms, high above the house: the elevator takes you up in 5.5 seconds, and nobody else can come in. Friends ride up in 6.5 seconds, only if you allow it (Suites key). Ring the bell inside to furnish it.",
	},
	{
		-- (Build 102) The Concierge himself, and how the house's money works.
		stop = "suite",
		title = "The Concierge",
		line = "I'm at my lectern in the Foyer. Press E by me any time: I'll answer anything, find any room, or take you round again. The House Tour key does the same.",
	},
	{
		stop = "suite",
		title = "Becoming the richest guest",
		line = "Gilt is what you earn and spend. Your Fortune is your Gilt and everything you own together, and the Wealthiest boards rank it (Gilt bought with Robux never counts there). Every reward shows its exact Gilt before you earn it.",
		quick = true,
	},
	{
		stop = "suite",
		title = "Off you go",
		line = "Earn Gilt in the attractions, grow your Fortune, climb the wealth ranks and the Wealthiest boards. Ask me anything at my lectern.",
		quick = true,
	},
}

-- While the Concierge walks to the next stop.
Voice.TourWalk = {
	start = "Come with me. I'll show you round.",
	salon = "This way, to the Salon.",
	tonight = "Over here, by the wall.",
	luxe = "To the Luxe Lounge: Steal a Luxe is through here.",
	basement = "Across to the Basement Stair.",
	executive = "And the Executive's Anteroom, by the front.",
	vault = "Now the Vault's door, at the back.",
	boutique = "Round to the Boutique.",
	library = "Up the Grand Stair. Mind the step.",
	ballroom = "Along the hall.",
	terrace = "And over here.",
	suite = "One more door: your Suite's.",
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
	ballroomDoor = "The Grand Ballroom",
	terraceDoor = "The Terrace",
	suiteDoor = "Your Suite",
}

-- (Build 95) The first card leads with the games (`quick`, the gold key); `whole` is the full walk
-- round every room, the first card's Next.
Voice.TourKeys = { next = "Next", back = "Back", done = "End the tour", skip = "Skip ahead", attractions = "Show me the attractions", explore = "I'll explore", quick = "Show me the games", whole = "The whole house", try = "Try it now", steal = "Play Steal a Luxe" }
-- (Build 94) The tour's live words, said with a card when they're true right now (what the house
-- says on every screen: never a guess). {t} is a clock from the server's own time.
Voice.TourLive = {
	ballroomOpen = "Right now: Lights Out is open. Go in and press Join.",
	ballroomGathering = "Right now: Lights Out is about to start. Go in and press Join before it does.",
	ballroomPlaying = "Right now: a game of Lights Out is on the dance floor.",
	ballroomClosed = "Lights Out opens again in {t}.",
	showtime = "Showtime is on in there now.",
}

-- A Private Evening (a private server).
Voice.Private = {
	title = "A Private Evening",
	line = "Your own house tonight. Nothing here counts for records.",
	setEvening = "How would you like the Grand Ballroom tonight?",
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
-- (Build 102) The HOUSE TOUR key's gold hand, on a brand-new guest's first visit only.
Voice.HouseTour = {
	handTitle = "House Tour",
	handLine = "Your guide to the whole house, whenever you like.",
	handSeconds = 14,
}

Voice.StartHere = {
	title = "Start here",
	heading = "Welcome to the Maison",
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
		{ title = "Pick an attraction", line = "Press Play, top right: Steal a Luxe, the Maison Basement, the Executive Suite, the Grand Auction and more. Steal a Luxe is a good first.", short = "Press Play, top right. Steal a Luxe is a good first." },
		{ title = "Build your fortune", line = "Every run you bank pays Gilt. Spend it on your Suite and your look, flex your brainrots, and climb to the wealthiest.", short = "Every run you bank pays Gilt. Become the wealthiest." },
	},
	after = "For your first half hour, every Gilt you earn counts double. Spend it on your Suite, your look and more.",
	-- (Build 98) The key takes the guest to the Concierge and starts the tour at once.
	go = "Show me the house",
	attractions = "Show me the attractions",
	handTitle = "Start here",
	handLine = "See the whole house first: then every game makes sense.",
	-- (Build 98) Wandered far from the Concierge before the tour: a quiet note.
	farTitle = "The Concierge is by the front door",
	farLine = "Head back to him: Show me the house starts there.",
}

-- Welcome back (UI/WelcomeBack): a returning guest's one card, once they've arrived: what's waiting
-- for them (tonight's present, their brainrots' tip jar) and what's new in the house since they
-- were last here.
Voice.WelcomeBack = {
	-- (Build 88) The reveal, when AFK mode earned something while the guest was away.
	reveal = {
		kicker = "WELCOME BACK",
		heading = "Your Fortune grew while you were away",
		earned = "YOU EARNED",
		away = "Away %s  ·  counted up to %d hours",
		rate = "Your squad away from the house: %s Gilt an hour",
		jar = "In your tip jar now: %s Gilt",
		collect = "Collect %s Gilt",
		later = "Later",
	},
	title = "Welcome back",
	heading = "Good to see you, %s",
	night = "Your %s night at the house.",
	present = { title = "Tonight's present is waiting", line = "The Evening Calendar: a present every day you come.", key = "Open" },
	jar = { title = "Your brainrots earned %s Gilt", line = "Their tip jar filled while you were away.", key = "Collect", done = "Collected" },
	news = "New in the house",
	go = "Let's go",
}

-- AFK mode (client AfkMode): the card while a guest rests, and the note in Roblox's menu.
Voice.Afk = {
	kicker = "AFK mode  ·  your brainrots are earning",
	rate = "%s Gilt an hour, into their tip jar",
	noSquad = "No brainrots earning yet",
	noSquadLine = "Put a brainrot in your squad (Curios, then Brainrots) and it earns Gilt while you rest.",
	away = "Out of the game they keep earning too: %d%% of the rate, for up to %d hours.",
	rested = "Resting for %s",
	back = "Move, or press any key, to come back.",
	rejoin = "To keep your place, the house rejoins you to this server every %d minutes.",
	note = "YOU EARN GILT OFFLINE WITH BRAINROTS",
	noteLine = "Your squad keeps earning while you're away: %s Gilt an hour, for up to %d hours. Come back tomorrow and collect it.",
	noteNone = "Put a brainrot in your squad and it keeps earning Gilt while you're away.",
	welcome = "%s of it while you were away (AFK mode, %s).",
}

-- What's new in this build, told once to each returning guest (Welcome back). Only shown while
-- `build` is the build that's playing, so old news never shows as new.
-- (Build 97) When the purse is short: what's short on top, and a nudge under it.
Voice.Short = { gilt = "Insufficient Gilt", gems = "Insufficient Gems", line = "Gotta get more lol" }

Voice.WhatsNew = {
	build = 104,
	lines = {
		-- (One short line each: read at a glance.)
		"On Luxury Island: jet skis, the Day Yacht and a helicopter to fly.",
		"Your Suite is one glass residence now, the city lit up below it.",
		"Every game pays far more Gilt: the figure shown is the figure paid.",
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
-- (Build 87) The guiding hand's notes: a ringed, gloved hand pointing at the thing on the screen.
Voice.GuideHand = {
	collection = {
		title = "Your Collection",
		line = "Your brainrots, every curio you own, your Gems and your trades, all in one place. Open it any time.",
	},
	-- (Build 90)
	fortune = {
		title = "Your Fortune",
		line = "Everything you own and earn adds up here: your Gilt, your collection and all you've banked in the games. The richest guest tops the boards. Tap it to see how yours is made.",
	},
	play = {
		title = "Every game in the house",
		line = "Steal a Luxe, the Basement, the Executive Suite and more, each on its own card. Pick one and go.",
	},
	level = {
		title = "Your level",
		line = "Everything you do in the house earns XP toward your next level. Tap it for your badges.",
	},
	boost = {
		title = "Boost",
		line = "Once a day, each brainrot in your squad can give you a quarter hour of its ability. Its card says what it does.",
	},
	menuTitle = "Show me round",
	menuLine = "The guiding hand points out the keys again.",
}

Voice.Hints = {
	label = "TIP",
	list = {
		{ id = "newcomer", line = "New here? Press Play, top right, and pick an attraction: Steal a Luxe is a good first. How to play explains it all.", after = 45 },
		{ id = "keys", line = "When you're holding a piece, keys 1 to 6 drop it straight into a case.", sat = 1 },
		{ id = "tap", line = "Tap a piece, then tap its case. No need to drag.", sat = 1 },
		{ id = "streak", line = "Right pieces in a row raise your combo. One wrong case resets it.", sat = 2 },
		{ id = "rooms", line = "Steal a Luxe, the Basement and the Executive Suite grow your Fortune fastest. Press Play to see every game.", sat = 3 },
		{ id = "abuse", line = "Admin Abuse: everything pays double. Find the Gold Tile and the Piñata in the Foyer.", every = 600 },
		{ id = "grandPrix", line = "The Grand Prix is open: get in any car on the street and press Race.", every = 720 },
		{ id = "ballroom", line = "The Grand Ballroom is open: up the Grand Stair, one winner takes the pot.", every = 900 },
		{ id = "holiday", line = "A holiday game is on. Its key is at the foot of the left dock.", every = 900 },
		{ id = "shop", line = "You have Gilt to spend: Shop, top right, has boosters, brainrots and more.", after = 240, every = 1200 },
		{ id = "suite", line = "Your Suite is yours to decorate. The Suites key on the left takes you there.", after = 420 },
		{ id = "collection", line = "Brainrots you find earn Gilt every hour. See them in Collection, and put your best in your squad.", after = 600 },
		{ id = "afk", line = "You earn Gilt offline with brainrots: your squad keeps filling its tip jar while you're away. Come back tomorrow and collect it.", after = 1200, every = 2400 },
		{ id = "tonight", line = "Tonight's table: one try a day, the same pieces for every guest. The card at the top of your screen seats you at it.", after = 900 },
		-- (Build 88) The house's one aim, and what feeds it.
		{ id = "fortune", line = "Your Fortune, under your Gilt, is everything you own and have won. Become the richest guest: tap it to see what it's made of and who's ahead.", after = 150 },
		{ id = "level", line = "Everything you do earns XP: the attractions, races, the tables. Your level is beside your Fortune; every tenth pays well.", after = 330 },
		{ id = "boosters", line = "Each brainrot in your squad has a booster: Collection, Brainrots, then Boost. Once a day each, for 15 minutes.", after = 480 },
		{ id = "badges", line = "There are over two hundred badges to earn. Tap your level to see the Badge Book and how close you are to the next.", after = 720 },
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
		lead = "Become The Richest Guest is played in the Maison, a grand house full of games. Play them to earn Gilt (the house's gold coins), grow your Fortune and become the wealthiest guest in the house. Spend what you earn on looks, your Suite and your collection.",
		heading = "Your first five minutes",
		steps = {
			{ title = "See every game", line = "Press the gold Play key at the top right. Each game has a card: what it is, how to play it, and a key that takes you there.", key = "Open it", action = "directory" },
			{ title = "Start with Steal a Luxe", line = "Its door is the Luxe Lounge, off the Foyer. Pick up treasures, keep out of the guards' sight, and carry them to the getaway car. Every trip grows your Fortune.", place = "velvet", key = "Take me there" },
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
			{ place = "boutique", title = "The Boutique", line = "The house's shop for looks.", how = "Boosters and brainrots for Gilt, nameplates, trails and emotes for Gilt or Robux (always with the price shown first). The Wardrobe beside it is where you wear what you own." },
			{ place = "vault", title = "The Vault", line = "Your collection, kept for good.", how = "Every piece you've sorted stands on its shelves. The console under the eight domes shows your curios, how complete your collection is, and who may look round. The Archivist at the desk keeps your badges and records." },
			{ place = "terrace", title = "The Terrace", line = "A rooftop to relax on, and the jet to Luxury Island.", how = "A bar with treats, a fire pit and loungers under the stars. The private jet to Luxury Island boards at the Jet Lounge: the Island Key opens it, for a Tycoon, and its card shows the price first." },
			{ place = "suite", title = "Your Suite", line = "Your own private rooms upstairs.", how = "Ring the bell inside to furnish them. Only you can go in, unless you invite friends with the Suites key." },
		} :: { GuideItem },
	},
	gilt = {
		lead = "Gilt is the house's money. You earn it in every game, and spend it on things you keep.",
		items = {
			{ title = "Gilt", line = "Earned everywhere: the tables, Steal a Luxe, the Basement, the Grand Ballroom and the races.", how = "Your Gilt is shown at the top left of the screen." },
			{ title = "Gems", line = "Rarer than Gilt.", how = "Bought with Robux (a Gem pack in the shop), or traded with another guest. No game, race, present or streak pays them: those all pay Gilt. Spend Gems in the Gem Shop and the Cabinet." },
			{ title = "Your Fortune", line = "Everything you own, added up.", how = "Your Gilt, Gems, collection, Suite and all you've banked in the games. It's under your Gilt: tap it for the Wealthiest boards, which count only what you earned, never what was bought." },
			{ title = "The Shop", line = "Everything for sale, in one place.", how = "Looks, table styles, lamps and more for Gilt. Some special things are for Robux, always with the price shown first.", key = "Shop", action = "shop" },
			{ title = "Levels and badges", line = "Everything you do counts.", how = "Sorting, racing and playing earn XP and raise your level. Badges in the Badge Book mark what you've done." },
			{ place = "tonight", title = "Tonight's table", line = "Optional: once a day, everyone plays the same table.", how = "Press Play and you're seated at a free Salon table: five rounds against tonight's clock, with the same pieces for every guest in every server. One try a day; the best scores go up on the board in the Foyer.", key = "Play", action = "nightly" },
		} :: { GuideItem },
	},
	extras = {
		lead = "Big games and fun on the side. All optional, all worth a try.",
		items = {
			{ place = "grandPrix", title = "The Grand Prix", line = "Ultra-luxury cars on the street outside.", how = "Walk up to any car and press E to drive (or F to ride along with a friend). Every 10 minutes a race opens: press Race, line up on the grid, wait for the five lights, then three laps. Reset puts a stuck car right.", win = "Gilt for the top three, the most for the winner." },
			{ place = "ballroom", title = "The Grand Ballroom", line = "Lights Out: party games on the dance floor.", how = "When it opens, press Join before the countdown ends. Then round after round: the Chairs (when the music stops, stand on a gold seat), Lights Out (be in a circle of light when it goes dark) and, at the end, the Spinner (shove the other guest out of the ring). Out of a round, your lamp goes out.", win = "The last lamp still lit wins the whole pot of Gilt." },
			{ place = "library", title = "The Library", line = "Tête-à-Tête: one on one.", how = "Sit at a Library table to face another player. You both get exactly the same pieces; three in a row sends a parcel of lookalikes across to them.", win = "First to win three hands wins the match." },
			{ title = "Curios and brainrots", line = "Collectibles found as you play.", how = "They turn up at the tables. Open Collection (left of the screen) to see them, and Trade to swap with friends safely.", win = "Brainrots earn you Gilt every hour, and a little while you're offline too (AFK mode)." },
			{ title = "Luxe Lucky Boxes", line = "Three gift boxes just inside the Grand Ballroom.", how = "Walk up and press E. Open one with Gems, or save up Gilt for one. Every box gives one brainrot; the odds of each are shown first, with a counter to a guaranteed rarer one. Only where Roblox allows paid random items.", win = "A brainrot every time, Rare or better." },
			{ title = "Holiday games", line = "In their season, the house throws a party.", how = "Trick or Treat on Hallows Lane, the Turkey Round-Up, Santa's Sleigh, the Great Egg Hunt and the Luck of the Irish.", win = "Gifts, Gilt and the holiday's own curios." },
			{ title = "Events", line = "Golden Hour and more.", how = "Watch the strip at the top of the screen: while an event is on, it pays extra.", win = "More Gilt while they last." },
		} :: { GuideItem },
	},
	next = "Next: ",
	go = "Go",
	tour = "Show me the house",
	arrived = "You're here",
	coach = "New here? Everything is explained in How to play, with a Go key for every room.",
	-- (Build 96) On a phone, where How to play is a tile in the Menu.
	coachPhone = "New here? Menu, then How to play: everything explained, with a Go key for every room.",
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
		{ id = "luxe", place = "velvet", line = "Play Steal a Luxe: grab treasure, bank it at the car", how = "Tap Take me there: it walks you in." },
		{ id = "basement", place = "obsidian", line = "Go down the Maison Basement: thirty-two stages to the Treasury", how = "Its stair is off the Foyer. Clear it for an invitation to the Executive Suite." },
		{ id = "gala", place = "ballroom", line = "Visit the Grand Ballroom: the Flex Studio, trivia, the Runway", how = "Through its doors in the Club hall, up the Grand Stair." },
	},
	-- (Build 95) Lights Out while it's open: the party games on the Grand Ballroom's dance floor
	-- (Config Ballroom.floor), joined with Join; `lightsOutTables` is the old sorting evening's.
	-- %s: the pot.
	lightsOut = {
		openTitle = "Lights Out is open",
		open = "Party games on the Grand Ballroom's dance floor",
		openHow = "Go in and press Join Lights Out: the last lamp lit wins %s Gilt or more.",
		gatheringTitle = "Lights Out · last call",
		gathering = "A game of Lights Out is about to start",
		gatheringHow = "Go in and press Join Lights Out before it starts: the last lamp lit wins %s Gilt.",
	},
	lightsOutTables = {
		openTitle = "The Grand Ballroom is open",
		open = "Lights Out: sit, sort, keep your lamp lit",
		openHow = "The last lamp wins %s Gilt or more. It closes soon.",
		gatheringTitle = "Lights Out · last call",
		gathering = "An evening in the Grand Ballroom is about to begin",
		gatheringHow = "Take any chair before it starts: the last lamp wins %s Gilt.",
	},
	best = "Beat your best run in {room}: {points} points",
	bestHow = "Any table in the Salon.",
	-- (Build 97) Every game tried: the loop that grows a Fortune.
	more = "Steal a bigger haul: every haul grows your Fortune",
	moreHow = "Tap Take me there: straight into Steal a Luxe.",
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
	queued = "You'll be told the moment the Grand Ballroom opens again.",
	outTitle = "Your lamp is out",
	outBy = "{place} of {of} · a parcel from {name}",
	outByName = "A parcel from {name} put it out.",
	outOver = "Your felt went over sixteen.",
	outPlace = "{place} of {of}",
	overCapacity = "Over sixteen. Three seconds.",
	lastLamp = "The last lamp in the house is yours.",
	lastLampCaps = "The last lamp",
	-- Lights Out on the dance floor (Build 81): its rounds, what to do in each, and why a lamp went out.
	floorJoin = "Join Lights Out",
	floorLeave = "Leave Lights Out",
	keepWatching = "Keep watching",
	remind = "Remind me",
	openNow = "Open it now",
	roundChairs = "The Chairs",
	roundLights = "Lights Out",
	roundSpinner = "The Spinner",
	chairsMusic = "Dance. When the music stops, stand on a gold seat.",
	chairsScramble = "Find a seat: one guest a seat",
	lightsWarn = "Get into a circle of light",
	lightsDark = "Stay in the light",
	duelYou = "Shove {rival} out of the ring: click or tap",
	duelWatch = "{a} against {b}: one stays in the ring",
	spinnerPicks = "The spinner picks two",
	lampsLit = "{n} of {of} lamps lit",
	youreIn = "You're in",
	startsIn = "Lights Out starts in {time}",
	safe = "Safe",
	outChairs = "No seat when the music stopped.",
	outDark = "Caught in the dark.",
	outRing = "Pushed out of the ring by {name}.",
	outBell = "{name} was nearer the middle at the bell.",
	outLeft = "You left the floor.",
	joinHow = "Press Join in the Grand Ballroom: party games on the dance floor, and the last lamp lit takes the pot.",
	-- The pad at the foot of the screen in the Ballroom: what Lights Out is, and its keys.
	padKicker = "Lights Out · on the dance floor",
	padOpen = "Musical chairs, the dark and the Spinner's duel. The last lamp lit wins {pot} Gilt.",
	padGathering = "Starts in {time}. The last lamp lit wins {pot} Gilt.",
	padJoined = "Stay in the Grand Ballroom: when it starts, you're brought onto the floor.",
	padOnKicker = "Lights Out is on",
	padPlaying = "Watch the floor. Ask to be reminded, and you'll be told when the next one opens.",
	padClosedKicker = "The Grand Ballroom is closed",
	padClosed = "It opens in {time}. Ask to be reminded, or open it now for everyone.",
	padClosedFree = "It opens in {time}. Ask to be reminded, and you'll be told when it does.",
	openHeld = "1 held",
	resultTitle = "The evening is over",
	onlyLast = "Only the last lamp is paid. Next time, it could be you.",
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

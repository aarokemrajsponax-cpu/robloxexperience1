--!strict
-- Every tunable number lives here. The server may overlay values from Roblox Configs
-- (see server/LiveConfig) and mirrors the result to clients; the code defaults below
-- are what ships when no override exists.

local Config = {}

export type RoomTuning = {
	firstDeal: number,
	dealGrowth: number,
	maxDeal: number,
	casesRound1: number,
	lookalike: number,
	clockBase: number?, -- nil = no clock
	clockPerPiece: number?,
	clockRefund: number?,
	clockPenalty: number?,
	clockStartsOnLift: boolean,
	guide: "full" | "delayed" | "none",
	guideDelay: number,
	names: boolean,
	multiplier: number,
	rareRate: number,
	mythicChance: number, -- 1 in N per piece dealt; 0 = never
	unlock: { room: string, round: number }?,
}

local defaults = {
	Rooms = {
		salon = {
			firstDeal = 8, dealGrowth = 1.3, maxDeal = 17, casesRound1 = 4, lookalike = 0,
			clockBase = nil, clockPerPiece = nil, clockRefund = nil, clockPenalty = nil, clockStartsOnLift = false,
			guide = "full", guideDelay = 0, names = true, multiplier = 1.0, rareRate = 0.012,
			mythicChance = 40000, unlock = nil,
		} :: RoomTuning,
		velvet = {
			firstDeal = 10, dealGrowth = 1.6, maxDeal = 20, casesRound1 = 5, lookalike = 0.25,
			clockBase = 14, clockPerPiece = 3.2, clockRefund = 0.8, clockPenalty = 1.5, clockStartsOnLift = true,
			guide = "full", guideDelay = 0, names = true, multiplier = 1.3, rareRate = 0.015,
			mythicChance = 30000, unlock = nil,
		} :: RoomTuning,
		obsidian = {
			firstDeal = 12, dealGrowth = 2.0, maxDeal = 24, casesRound1 = 6, lookalike = 0.55,
			clockBase = 10, clockPerPiece = 2.5, clockRefund = 0.6, clockPenalty = 2.5, clockStartsOnLift = false,
			guide = "delayed", guideDelay = 0.8, names = true, multiplier = 1.7, rareRate = 0.018,
			mythicChance = 22000, unlock = nil,
		} :: RoomTuning,
		midnight = {
			firstDeal = 14, dealGrowth = 2.4, maxDeal = 28, casesRound1 = 6, lookalike = 0.80,
			clockBase = 8, clockPerPiece = 2.0, clockRefund = 0.45, clockPenalty = 3.5, clockStartsOnLift = false,
			guide = "none", guideDelay = 0, names = false, multiplier = 2.4, rareRate = 0.020,
			mythicChance = 15000, unlock = { room = "obsidian", round = 4 },
		} :: RoomTuning,
	},

	Deal = {
		repeatCap = 2, -- no single piece more than twice in a deal
		repeatCapLargeDeal = 3, -- three times if the deal is over 18
		largeDealFrom = 19,
		seasonalShare = 0.18,
		seasonalMin = 1,
		seasonalMax = 4,
	},

	Rare = {
		base = 0.05,
		cap = 0.20,
		highValueBonus = 0.10,
		highValueFrom = 170,
	},

	Scoring = {
		streakPerStep = 2, -- multiplier = 1 + floor(streak / 2)
		maxMultiplier = 10,
		rareFactor = 2,
		seasonalFactor = 1.35,
		setBonusFrom = 3,
		setBonusCap = 6,
		setBonusPer = 40,
		perfectBase = 500,
		perfectPerRound = 100,
		bestStreakPer = 25,
		secondsLeftPer = 15,
		wrongBase = 60,
		wrongPerRound = 20,
		gradePower = 1.4,
		runStreakFloor = 6,
		mythicValue = 200, -- scored as a gilded piece of this value
	},

	Grades = { Flawless = 95, Immaculate = 84, Polished = 68, Steady = 48 },

	-- Tête-à-Tête in the Library (Appendix H2).
	Library = {
		handsToWin = 3,
		pieces = { 14, 17, 20, 23, 26 }, -- per hand
		cases = { 4, 5, 6, 6, 6 },
		lookalike = { 0.30, 0.40, 0.50, 0.60, 0.70 },
		guideDelay = 0.8,
		fumble = 0.8, -- seconds a wrong case stops your hand
		parcelRunFrom = 3, -- a same-case run this long starts sending parcels
		parcelRunMax = 3, -- at most this many parcels per run
		streakParcelAt6 = 6,
		streakParcelAt10 = 10,
		streakParcelAt15 = 15,
		parcelFuse = 2.0,
		handCap = 60,
		betweenHands = 4,
		ratingStart = 1500,
		ratingDeviation = 350,
		ratingVolatility = 0.06,
		ratingTau = 0.5,
		placementMatches = 5,
		queueWindow = 100,
		queueWiden = 50,
		queueWidenEvery = 5,
		queueWindowMax = 400,
		standInAt = 25,
		disconnectGrace = 20,
		rankedAccountDays = 3,
		standInSlowSeconds = 1.8, -- a Stand-in at rating 1000
		standInFastSeconds = 0.55, -- a Stand-in at rating 2100
		standInLowAccuracy = 0.78,
		standInHighAccuracy = 0.97,
		giltWin = 60,
		giltLoss = 25,
	},

	-- Lights Out in the Ballroom (Appendix H3). Seconds unless noted.
	Ballroom = {
		tables = 20,
		gatherSeconds = 30, -- after the first guest sits, Stand-ins fill the empty chairs
		minRealForRecords = 8, -- an evening counts for records only with this many real guests
		capacity = 16, -- pieces a felt holds
		overSeconds = 3.0, -- over capacity this long and the lamp goes out
		openingDeal = 6,
		casesOpen = 5,
		sixthCaseAt = 60,
		paceStart = 1.6, -- seconds between arrivals
		paceStep = 0.10,
		paceEvery = 20,
		paceMin = 0.60,
		closingAt = 300, -- Closing Time
		closingStep = 0.05,
		closingEvery = 10,
		closingMin = 0.35,
		lookalikeStart = 0.35,
		lookalikeStep = 0.05,
		lookalikeEvery = 30,
		lookalikeMax = 0.75,
		guideDelay = 0.6,
		fumble = 0.6,
		parcelRunMax = 4,
		parcelFuse = 2.5,
		keyWindow = 5, -- a parcel that landed this recently puts the lamp out
		keyBonus = { { 2, 0.25 }, { 4, 0.50 }, { 8, 0.75 }, { 16, 1.00 } }, -- { keys, extra parcels }
		points = { 100, 70, 55, 45, 40, 25, 25, 25, 25, 25, 10, 10, 10, 10, 10, 0, 0, 0, 0, 0 }, -- by place
		pointsPerKey = 8,
		giltBase = 20, -- Gilt for an evening: 20 + 4 × (21 − your place), 100 for the last lamp
		giltPerPlace = 4,
		afterEvening = 8, -- the winner's moment before the next evening gathers
		standInSlow = 1.35, -- a Stand-in's seconds per filing, slowest and fastest
		standInFast = 0.62,
		standInLowAccuracy = 0.82,
		standInHighAccuracy = 0.96,
	},

	-- The Ledger (Appendix I2): tune so ~30 minutes on four nights a week finishes around week 9.
	Ledger = {
		pages = 50,
		pointsPerPage = 1000,
		freeGilt = 100, -- the free row's Gilt pages
		points = {
			filing = 3, -- per correct filing, four rooms and the Nightly
			nightly = 300,
			evening = 400, -- the Evening Commission
			week = 1500, -- the Week's Commission
			library = 150, -- per Library match
			libraryWin = 100,
			ballroom = 150, -- per Ballroom evening
			ballroomPerPlace = 10, -- for each place above 11th
		},
	},

	-- Developer products and passes (Appendix I3). Developer products are found by their names
	-- (ProductConfig), so 0 is fine for them; an id here (or in Roblox Configs) overrides that.
	-- Game passes can't be found by name: paste their ids. Prices are always read live.
	Products = {
		tier49 = 0, tier79 = 0, tier99 = 0, tier149 = 0, tier199 = 0,
		tier249 = 0, tier299 = 0, tier399 = 0, tier499 = 0, tier599 = 0,
		introduction = 0, -- once per account, first 7 days, only in the Boutique
		ledger = 0, -- the Leather-Bound Ledger, per Term
		season = 0, -- a season collection
		goldKey = 0, -- a game pass
		goldKeyGift = 0, -- a developer product at the Gold Key's price: the Gold Key, for another guest
		blackCard = "", -- the Black Card subscription's id ("EXP-..."); "" means it isn't offered
		-- Salutes: one developer product each (suggested prices in Salutes.luau).
		salute_goldLeaf = 0,
		salute_encore = 0,
		salute_chandelier = 0,
		salute_fireworks = 0,
		salute_grand = 0,
		salute_finale = 0,
		-- More of what guests buy (developer products, found by their names in ProductConfig).
		-- AJKR's developer products (Creator Hub ids, pasted so nothing depends on names).
		giltPurse1 = 3716215371, -- Gilt Purse
		giltPurse2 = 3716215587, -- Gilt Chest
		giltPurse3 = 3716215695, -- Gilt Vault
		doubleGilt = 3716211503, -- Double Gilt (named "Double Glit" in Creator Hub)
		goldenHour = 3716216027, -- Golden Hour for Everyone
		goldKeyProduct = 3716216232, -- The Gold Key, as a developer product
		-- The five new products (ProductConfig). A developer product with no id here is found by
		-- its name; the VIP Velocity Elite game pass needs its id pasted here.
		velocityElite = 0, -- a game pass
		velocityEliteProduct = 0, -- the same perk as a developer product, if there's no game pass
		chronosDefiance = 3716216641, -- Chronos Defiance
		emperorsDecree = 3716216786, -- Emperor's Decree
		godModeLuck = 3716216448, -- Luck Booster
		megalodonRainmaker = 3716216867, -- Megalodon Rainmaker
		-- Time at the Foyer's grand piano (found by name until their ids are pasted here).
		pianoSession1 = 0, -- Piano Session 1 Minute
		pianoSession3 = 0, -- Piano Session 3 Minutes
		pianoSession5 = 0, -- Piano Session 5 Minutes
		pianoSession10 = 0, -- Piano Session 10 Minutes
		saluteQueue = 4, -- salutes waiting their turn in one house, at most
		benefactorMinutes = 30, -- the giver's nameplate carries a gold star this long
		choiceSeconds = 3600, -- a Boutique piece chosen (or a gift) waits this long for its purchase
	},

	-- Products' names, prices, rewards and rules: Shared/ProductConfig (the game finds each
	-- developer product by its Name there, so no ids need copying).

	-- The offers (Boutique → Offers, the Shop key, and the card after a run).
	-- (What each offer gives is in ProductConfig.)
	Offers = {
		upsellAfterRuns = 2, -- the "Double Gilt would have paid..." card, after this many banked runs
	},

	-- The Founding Term's id (for example "2026-autumn"): set it at launch; guests who play in it
	-- get the Founding Term badge and its dated rewards.
	FoundingTerm = "",

	-- The Soirée (Appendix H5).
	Soiree = {
		libraryWin = 30,
		libraryLoss = 5,
		ballroomBest = 5, -- best evenings that count
		libraryBest = 15, -- best matches that count
		medalTop = 0.01,
		invitationTop = 0.10,
		stampPlays = 3,
	},

	Staff = {
		lostAfter = 25, -- seconds a new guest lingers in the Foyer before the Concierge offers the walk
	},

	-- Every message a guest's screen sends is rate-limited (server RemoteGuard): a bucket per guest
	-- per remote that refills `rate` times a second and holds at most `burst`.
	RemoteLimits = {
		default = { rate = 4, burst = 8 },
		shopAsk = { rate = 8, burst = 16 },
		perkAsk = { rate = 3, burst = 6 },
		table = { rate = 30, burst = 45 }, -- sorting is fast: a filing and a lift per piece
		duel = { rate = 30, burst = 45 },
		ballroom = { rate = 30, burst = 45 },
		dialogueChoice = { rate = 3, burst = 6 },
		setting = { rate = 8, burst = 20 },
		funnel = { rate = 2, burst = 6 },
		quickSit = { rate = 0.5, burst = 3 },
		getBoard = { rate = 1, burst = 4 },
		tour = { rate = 1, burst = 4 },
		salute = { rate = 1, burst = 3 },
		adminAsk = { rate = 6, burst = 12 },
		pianoAsk = { rate = 3, burst = 6 },
		pianoNote = { rate = 16, burst = 24 }, -- a pianist's notes: quick runs and chords, never a flood
		sitAsk = { rate = 2, burst = 5 },
		barAsk = { rate = 3, burst = 6 }, -- (a bite each click: never faster than biteGap anyway)
		curioAsk = { rate = 3, burst = 8 },
		tradeAsk = { rate = 3, burst = 8 },
		spectacleAsk = { rate = 2, burst = 5 },
	},

	-- The Concierge's walking tour (each guest's own guide, drawn on their screen).
	Tour = {
		speed = 10, -- studs a second the Concierge walks
		waitBeyond = 16, -- a guest further behind than this: the Concierge stops and waits
		resumeWithin = 11, -- and walks on once they're this close
		arriveWithin = 15, -- at a stop, the card shows once the guest is this close
		lostBeyond = 90, -- a guest this far away for lostAfter seconds has left the tour
		lostAfter = 40,
	},

	-- Circles (§9.7, Appendix H7): clubs of up to twenty. One switch turns them off.
	Circles = {
		enabled = true,
		maxMembers = 20,
		minMembers = 2, -- a Circle hangs on the boards once it has this many
		foundGilt = 2000,
		best = 5, -- a Circle's week is its five best members' points
		libraryWin = 10,
		boardTop = 5,
		refreshSeconds = 120,
		inviteSeconds = 90, -- an invitation or a request waits this long for an answer
		storeName = "MaisonNoir_Circles",
	},

	-- Notifications (§13): Roblox experience notifications, for opted-in guests aged 13+. Asked
	-- for only after a first Nightly; at most one a day. Sent through Open Cloud with an API key kept
	-- in the experience's secrets (never in code), using message templates made on the Creator
	-- Dashboard. With no template id set, that kind isn't sent.
	Notifications = {
		enabled = true,
		secret = "OpenCloudNotifications", -- the secret's name in the experience's secrets store
		messages = { rivalPassed = "", soiree = "", termEnding = "" }, -- template ids
		recentDays = 14, -- guests seen this recently hear about the Soirée and the Term's end
		maxBatch = 500, -- per Soirée or Term, from the one server that claims the job
		checkSeconds = 600,
	},

	-- The Black Card (§12, Appendix I): a monthly subscription. The Leather-Bound Ledger while it's
	-- held, one cardholder look each month to keep, and a black-lacquer nameplate while active.
	BlackCard = {
		quietMinutes = 10, -- a guest's first minutes in the house: the card on the lectern stays hidden
	},

	-- A Private Evening (a private server, §12): the owner's house for friends. Nothing played
	-- there counts for records; the owner sets the Ballroom's pace and whether Stand-ins sit in.
	Private = {
		paces = { gentle = 1.3, house = 1.0, brisk = 0.8 }, -- × seconds between arrivals
		inStudio = false, -- true makes a Studio playtest behave as a Private Evening (for testing)
	},

	-- Music (§14). Every space has its own track (Assets.Music), crossfading as you move.
	Music = {
		level = 0.6, -- a track's volume before the guest's own Music level
		crossfade = 2.5, -- seconds
		gap = 1.5, -- seconds of quiet between one song in a playlist and the next
		intensityBase = 0.25, -- the run builds: intensity = min(1, base + round × perRound)
		intensityPerRound = 0.12,
		bandBassAt = 10, -- the Ballroom band: the whole band above this many lamps, bass and brushes down to it
		bandPianoAt = 2, -- and a single piano and a ticking clock for the final two
		pianoReach = 95, -- studs the Foyer piano carries (it leaks through the street door)
		muffled = -18, -- dB taken off the piano's highs when heard from another space
		soireeBrighter = 3, -- dB added to the piano's highs on a Soirée weekend
	},

	-- The Terrace bar (BarMenu has the menu and its prices).
	Bar = {
		reach = 16, -- studs from the bar a guest may order from
		sipSeconds = 0, -- a sip or a bite on its own this often (0: only when the guest clicks to eat)
		biteGap = 0.8, -- the quickest a guest can take another bite (seconds)
		idleSeconds = 300, -- a treat left untouched this long is set down
		shareRadius = 24, -- the Grand Platter hands a sweet to guests this close
		shareMax = 12, -- to at most this many
		goldKeyPour = true, -- Gold Key holders have one everyday drink on the house each day (UTC)
	},

	-- The Foyer's grand piano, played by a guest (time is bought in ProductConfig's piano sessions,
	-- and only runs while they sit at the keys).
	Piano = {
		lowest = 48, -- the lowest key, as a MIDI note (C3)
		keys = 37, -- C3 to C6: three octaves and the top C
		reach = 14, -- studs from the bench a guest may sit down from
		volume = 1.2, -- each note's volume
		heard = 80, -- studs a note carries from the piano (the Foyer, and faintly the street and stair)
		maxSeconds = 3600, -- the most piano time the house offers to hold at once (a purchase is never cut)
		-- Seconds anyone may play free each day (UTC). 0: the piano is pay-only (AJKR's call).
		taste = 0,
		-- Whether the owner (and anyone, in Studio) plays free. Off: the piano is pay-only for
		-- everyone. (In Studio, buying is a test purchase that charges nothing, so it can still be tried.)
		ownerFree = false,
		ownerSeconds = 1800, -- how long one free sitting lasts before the owner gets up
	},

	-- The fireworks (World/Fireworks): the Salutes' show over the house, and the Suite's.
	Fireworks = {
		rate = 3, -- shells a second through the body of a show (times the show's scale)
		finaleRate = 9, -- shells a second in the finale barrage
		finaleShare = 0.22, -- the last part of a show that is its finale
		closingWillows = 7, -- great gold willows in a row to close
		heightMin = 50, -- studs above the highest roof a shell bursts, at the least
		heightMax = 150, -- ...and at the most
		margin = 60, -- studs past the house's footprint shells may go up from
		maxLive = 70, -- shells in the sky at once, at most (kinder to slower computers)
		size = 2.6, -- how big every shell is (1: a town's show; 2.6: a Japanese festival's great shells)
		brightness = 3, -- how brightly the stars glow (ParticleEmitter.Brightness)
		screenGlow = 0.05, -- how much a big burst lights the whole screen (even from indoors)
		clearDensity = 0.06, -- the night air thins to this while a show is on
		watchDistance = 100, -- studs in front of the house the watching camera stands (over the street)
	},

	-- Suite spectacles drawn on the buyer's screen (World/MemeTakeover).
	Spectacles = {
		memeSeconds = 90, -- the Meme Takeover's length
		memeCast = 40, -- memes the portal spews
		memeRain = 140, -- little memes raining from the ceiling, at most
		bossSize = 11, -- studs across, the giant boss meme
	},

	-- Commissions (Appendix I1): Gilt for the Evening's and the Week's.
	Commissions = {
		eveningGilt = 150,
		weekGilt = 600,
	},

	-- Badges (§11): create each in the Creator Dashboard and put its id here; 0 = not awarded.
	Badges = {
		firstRound = 0,
		firstFlawless = 0,
		midnight = 0,
		seasonSet = 0,
		register10 = 0,
		register25 = 0,
		register50 = 0,
		firstNightly = 0,
		firstLibraryWin = 0,
		firstLastLamp = 0,
		mark = 0,
		mythic = 0,
		foundingTerm = 0,
	},

	Rivals = {
		activeDays = 14, -- a rival must have been here within this many days
		connectionsChecked = 20, -- connections looked up when choosing a rival (once a week)
		cardEverySeconds = 120, -- how often a guest's public card is written while they play
	},

	-- Marks: the ranked tiers (Appendix H4). Rating below each threshold is the tier before it.
	Marks = {
		silver = 1200,
		gold = 1400,
		platinum = 1600,
		diamond = 1800,
		onyx = 2000,
		termCompress = 0.6, -- at a Term's end: 1500 + (rating - 1500) * 0.6
		termMinDeviation = 150,
		noirTop = 100,
		noirMinMatches = 20,
	},

	-- House Standing thresholds (§11). Member opens ranked play. Tune in playtest.
	Standing = {
		memberNights = 3,
		memberRounds = 20,
		patronNights = 14,
		patronRounds = 150,
		connoisseurNights = 40,
		connoisseurRounds = 600,
		custodianNights = 100,
		custodianRounds = 2000,
		keeperNights = 250,
		keeperRounds = 6000,
	},

	-- The Nightly (Appendix H1). Rules by UTC weekday.
	Nightly = {
		rounds = 5,
		gilt = 120,
		boardTop = 100,
		boardHours = 72, -- how long a night's board is kept in memory
		connectionsChecked = 50,
		sunday = "obsidian",
		monday = "velvet",
		tuesday = "obsidian",
		wednesday = "velvet",
		thursday = "obsidian",
		friday = "midnight",
		saturday = "velvet",
	},

	Clock = {
		lowAt = 10, -- seconds left when the clock turns to its low state
		refundBoostFromMultiplier = 4,
		refundBoost = 1.5,
	},

	FairPlay = {
		minGap = 0.12,
		flagAverage = 0.30,
		flagAverageAfter = 40,
		flagRatePerSecond = 3,
		flagRateOver = 20,
	},

	Gilt = {
		runDivisor = 40,
		runMax = 400,
		dailySoftCap = 2500,
		softCapRate = 0.25,
		goldKeyBonus = 0.2, -- the Gold Key: +20% on all Gilt
		-- Every Boutique piece on the shelves can also be bought with Gilt: this many Gilt for
		-- each Robux of its price (a 249 piece is 9,960 Gilt).
		perRobux = 40,
	},

	FirstMinute = {
		target = 60, -- seconds from Play to the first filing
		straightToTableOfferSeconds = 12,
	},

	-- The owner's panel (House controls). The experience's owner (or the group's owner) is always
	-- allowed; add other trusted user ids to `userIds`. In Studio every tester is allowed.
	Admin = {
		userIds = {} :: { number },
		studioEveryone = true,
		minutes = { 5, 15, 30 }, -- the event lengths offered
		goldenHourGilt = 2,
		luckyHourMythic = 10,
		pageTurnerLedger = 2,
		giantsScale = 1.6,
		quickstepSpeed = 1.5,
		featherGravity = 70,
		coins = 30, -- gold coins per Gold Rain
		coinGilt = 25,
		coinSeconds = 90, -- how long the coins lie there
		keys = 5, -- golden keys per Treasure Hunt
		keyGilt = 250,
		memes = 18, -- meme curios loose in the house during the Brainrot Parade
		memeGilt = 40,
		curioHourFind = 2, -- the Night of Curios: how much likelier a find is (never above 0.95)
		giftGilt = { 100, 500, 1000 }, -- what the owner can give
		summonMinutes = 5, -- how long a summons to the owner's house stays open
		-- Admin Abuse Night: every one of these at once, with fireworks, in one tap.
		abuseEvents = { "goldenHour", "luckyHour", "pageTurner", "goldRain", "treasure", "giants", "quickstep", "parade", "disco", "curioHour" },
		abuseMinutes = { 15, 30, 60 },
		-- Scheduled events (set in the panel, kept in a DataStore, run by every server on time).
		scheduleCheck = 30, -- seconds between each server's look at the schedule
		scheduleNotice = 60, -- minutes before a scheduled event that every screen counts down to it
		scheduleMax = 20, -- events kept on the schedule at once
	},

	-- Testing in Studio (never affects the live game).
	Studio = {
		skipTitle = true, -- Play in Studio drops you straight into your own character
	},

	-- The composed title screen over the street (§15). Off: every guest is their own character
	-- from the first second, and the intro plays over the live house (any key skips it).
	Title = {
		show = false,
	},

	Movement = {
		-- (The Grand house is a third bigger again than it was drawn, so guests walk a little quicker.)
		walkSpeed = 15,
		runSpeed = 24,
		maxSpeed = 40, -- no combination of events and perks moves a guest faster than this
		npcWalkSpeed = 11,
		-- Guests and staff are drawn at this size: a touch under Roblox's own, the size the
		-- furniture was made for. (The rooms themselves are grand: Layout.SCALE.)
		guestScale = 0.8,
		-- Where guests appear: "foyer" (lit, in the middle of everything) or "street" (a first
		-- visit starts outside the doors at night).
		firstArrival = "foyer",
	},

	-- How sorting feels at the table: the camera, the hand, and what a filing says back.
	Sorting = {
		cameraFov = 46, -- the sorting camera's field of view
		wideFovExtra = 4, -- more for the Library's wide shot of both halves
		frameFill = 0.9, -- how much of the screen the table may fill (1 = edge to edge)
		enterSeconds = 1.05, -- the swing from walking into the sorting camera
		leaveSeconds = 0.95, -- and back down behind you when you stand
		focusBlur = 0.2, -- the room behind the table softly out of focus (0 = off)
		dragFollow = 26, -- how tightly a dragged piece follows the finger or mouse
		dragTilt = 14, -- the most (degrees) a dragged piece leans into its movement
		dragLift = 0.9, -- studs a held piece rises off the felt
		fileSeconds = 0.3, -- a piece's arc into its case
		returnSeconds = 0.42, -- a wrong piece's way back to its place
		punch = 0.9, -- degrees the camera leans in on a correct filing (0 = off)
		shake = 0.07, -- studs the camera shakes on a wrong case (0 = off)
		verdictSeconds = 0.95, -- how long "Correct" and "Wrong case" stay up
		streakMoments = { 3, 5, 8, 12, 16, 20, 30 }, -- streaks the house calls out
		hintFilings = 3, -- the first-seating hint goes after this many correct filings
	},

	Profiles = {
		storeName = "MaisonNoir_Profiles",
		schemaVersion = 1,
		autosaveSeconds = 60,
		lockSeconds = 90,
		loadRetries = 6,
	},

	Boards = {
		storePrefix = "MaisonNoir_Board_",
		refreshSeconds = 60,
		top = 10,
	},

	Analytics = { enabled = true },

	-- Asset ids. 0 or "" means "not set yet"; the code then plays nothing / uses a placeholder.
	Assets = {
		-- The house's own sounds and music are in the repo, ready to upload once each (assets/audio,
		-- see the README): the sound sheet and three tracks. Paste each id as "rbxassetid://<id>".
		-- Until the sheet is set the table plays Roblox's built-in stand-ins, softened.
		SoundSheet = "", -- assets/audio/maison-sounds.ogg: every table sound, several takes of each
		-- A sound set here replaces the sheet's takes for that one name ("" = use the sheet).
		Sounds = {
			chime = "", -- pitched up a step with each correct filing in a streak
			pickup = "",
			place = "", -- a piece settling into its case
			drop = "",
			deal = "",
			slide = "", -- a piece dragged quickly over the felt
			hover = "", -- a held piece over a case
			wrong = "",
			streakLost = "",
			combo = "", -- a streak called out
			shimmer = "", -- a gilded piece filed
			round = "",
			complete = "",
			low = "", -- the clock's last ten seconds
			enter = "", -- sitting down to sort
			leave = "",
			chair = "",
			door = "",
			click = "", -- a key pressed
			tick = "", -- a key under the pointer
			reward = "",
			-- Chimes sold in the Boutique. A chime is sold once its sound is set here or the sheet is.
			chimes = { harp = "", musicBox = "", celesta = "", glass = "" },
		},
		-- Until the sheet is set, the table plays real recordings from Roblox's licensed sound library
		-- (Pro Sound Effects, and Roblox's own UI set; free in any experience), each take with the
		-- pitch and level that suit it (levels measured to an even peak). Roblox's built-in sounds
		-- are the last resort.
		LibrarySounds = {
			-- The fireworks (Pro Sound Effects, free in any experience): deep booms, crackle, a barrage.
			-- Eating and drinking at the Terrace (Pro Sound Effects).
			eatBite = { { id = "rbxassetid://9113138343", pitch = 1, volume = 1.6 }, { id = "rbxassetid://9113660664", pitch = 1.1, volume = 1.4 } },
			drinkSip = { { id = "rbxassetid://9114172109", pitch = 1, volume = 1.4 }, { id = "rbxassetid://9114171855", pitch = 1, volume = 1.4 }, { id = "rbxassetid://9114171960", pitch = 1, volume = 1.4 } },
			fireworkBoom = { { id = "rbxassetid://9125484367", pitch = 1, volume = 2.2 }, { id = "rbxassetid://9125484511", pitch = 1, volume = 2.2 }, { id = "rbxassetid://9125484743", pitch = 1, volume = 2.2 }, { id = "rbxassetid://9125484526", pitch = 1, volume = 2.2 } },
			fireworkCrackle = { { id = "rbxassetid://9114447505", pitch = 1, volume = 1.6 } },
			fireworkBarrage = { { id = "rbxassetid://9114447178", pitch = 1, volume = 1.8 }, { id = "rbxassetid://9112780898", pitch = 1, volume = 1.8 } },
			chime = { { id = "rbxassetid://9119802003", pitch = 1, volume = 4.00 }, { id = "rbxassetid://9119802009", pitch = 1, volume = 4.00 } }, -- the correct chime, climbing a step with each one in a streak
			combo = { { id = "rbxassetid://9116394876", pitch = 1, volume = 4.00 } }, -- a streak called out
			shimmer = { { id = "rbxassetid://9116394876", pitch = 1.1, volume = 4.00 }, { id = "rbxassetid://9116395089", pitch = 1, volume = 4.00 } }, -- a gilded piece filed
			round = { { id = "rbxassetid://9116394756", pitch = 1, volume = 4.00 } }, -- a round begins
			complete = { { id = "rbxassetid://9116395089", pitch = 0.9, volume = 4.00 } }, -- a run banked
			reward = { { id = "rbxassetid://127645268874265", pitch = 1, volume = 0.56 } },
			pickup = { { id = "rbxassetid://9114072437", pitch = 1.3, volume = 3.24 }, { id = "rbxassetid://9114072359", pitch = 1.4, volume = 0.75 } }, -- a piece lifted off the felt
			place = { { id = "rbxassetid://9114072359", pitch = 1, volume = 0.75 }, { id = "rbxassetid://9114072437", pitch = 0.95, volume = 3.24 } }, -- a piece settling into its case
			drop = { { id = "rbxassetid://9114072359", pitch = 0.9, volume = 0.75 } }, -- a piece set back down
			deal = { { id = "rbxassetid://9114072437", pitch = 1.5, volume = 3.24 }, { id = "rbxassetid://9114072359", pitch = 1.6, volume = 0.75 } }, -- the pieces being set down
			slide = { { id = "rbxassetid://15675012262", pitch = 1.2, volume = 0.99 } },
			hover = { { id = "rbxassetid://15675059323", pitch = 1.4, volume = 0.99 } }, -- a held piece over a case
			wrong = { { id = "rbxassetid://9125654847", pitch = 1, volume = 1.00 }, { id = "rbxassetid://9125654847", pitch = 0.92, volume = 1.00 } }, -- a dull knock on the case
			streakLost = { { id = "rbxassetid://9126267420", pitch = 1, volume = 0.76 } },
			low = { { id = "rbxassetid://9119982044", pitch = 1, volume = 1.57 } }, -- the clock's last ten seconds
			enter = { { id = "rbxassetid://9116248762", pitch = 1, volume = 3.67 } }, -- sitting down on leather
			chair = { { id = "rbxassetid://9116248762", pitch = 1.05, volume = 3.67 } },
			leave = { { id = "rbxassetid://9120806410", pitch = 1, volume = 4.00 } },
			click = { { id = "rbxassetid://15675032796", pitch = 1, volume = 1.00 } },
			tick = { { id = "rbxassetid://15675032796", pitch = 1.35, volume = 1.00 } },
		},
		-- The Foyer's grand piano when a guest plays it. Roblox only lets an experience play audio
		-- its owner uploaded, or Roblox's own licensed library (APM Music, Pro Sound Effects): piano
		-- notes uploaded by other creators are refused (tested: every one on the Creator Store
		-- answers "authentication required"), which is why the piano was silent. So each key plays
		-- a slice of a licensed APM recording: one clean, sustained piano note found inside it
		-- (measured: its pitch, where it starts, how long it rings), retuned to the key from the
		-- nearest slice. `note` is the slice's pitch as a MIDI number, `start`/`length` seconds.
		PianoSlices = {
			{ id = "rbxassetid://1847254302", note = 52.97, start = 0.775, length = 2.5, gain = 1.6 }, -- F3, "Piano Short 120 B" (APM)
			{ id = "rbxassetid://1848319257", note = 72.08, start = 0.952, length = 3.0, gain = 1.3 }, -- C5, "Upright Evolution - Mnemonic" (APM)
		},
		-- Your own piano recordings, one per key from C3 (Config.Piano.lowest): upload them to your
		-- account (Creator Hub -> Development Items -> Audio) and paste their ids here; each plays
		-- once it has loaded, in place of the slices.
		PianoNotes = {},
		-- A middle-C recording of your own, retuned to every key, if the slices are ever withdrawn.
		PianoFallback = {},
		-- The house's music: three playlists of real recordings from Roblox's licensed library (APM
		-- Music, uploaded by APMOfficial, free in any experience), so the house has music the moment
		-- it opens, with nothing to upload. Each list plays through in a shuffled order, a breath
		-- between songs; `gain` evens out their loudness (measured, to about -19 dBFS).
		--   lounge: the Foyer's grand piano (solo piano), the Suite, the Vault, the Terrace
		--   table: the four sorting rooms and the Library (a cool-jazz trio)
		--   ballroom: the band (waltzes)
		Playlists = {
			lounge = {
				{ id = "rbxassetid://106960476637326", gain = 1.22 }, -- Late Night Classics · Alan Hawkshaw (Cocktail Time (BRS4)), 3:18
				{ id = "rbxassetid://72188165880204", gain = 1.41 }, -- After Hours · Alan Hawkshaw (Cocktail Time (BRS4)), 2:10
				{ id = "rbxassetid://88841226226927", gain = 1.38 }, -- Rhapsody · Alan Hawkshaw (Cocktail Time (BRS4)), 2:07
				{ id = "rbxassetid://100737560354437", gain = 1.50 }, -- Piano Music · Alan Hawkshaw (Cocktail Time (BRS4)), 4:42
				{ id = "rbxassetid://102141489095839", gain = 2.00 }, -- Quiet Impromptu · Alan Hawkshaw (Cocktail Time (BRS4)), 2:22
				{ id = "rbxassetid://76320727965632", gain = 1.40 }, -- Blues Impromptu · Alan Hawkshaw (Cocktail Time (BRS4)), 3:35
				{ id = "rbxassetid://1842182242", gain = 1.55 }, -- Piano Bar Rendezvous · KPM - FTV Media (Piano Solos), 1:46
			},
			table = {
				{ id = "rbxassetid://121473037535720", gain = 0.90 }, -- After Hours · Paul Reeves (Intimate Jazz Trio), 2:34
				{ id = "rbxassetid://134449348223060", gain = 0.89 }, -- Dawn Light · Paul Reeves (Intimate Jazz Trio), 2:49
				{ id = "rbxassetid://127701743196315", gain = 1.06 }, -- Lonely Streets · Paul Reeves (Intimate Jazz Trio), 2:45
				{ id = "rbxassetid://113393753471077", gain = 0.92 }, -- Afternoon Stroll · Paul Reeves (Intimate Jazz Trio), 2:16
				{ id = "rbxassetid://138206443676469", gain = 0.84 }, -- Breezing On By · Paul Reeves (Intimate Jazz Trio), 2:00
				{ id = "rbxassetid://97047565303583", gain = 0.84 }, -- Metropolitan Motion · Paul Reeves (Intimate Jazz Trio), 2:23
				{ id = "rbxassetid://127688638898929", gain = 0.74 }, -- Golden Hour · Paul Reeves (Intimate Jazz Trio), 3:06
			},
			ballroom = {
				{ id = "rbxassetid://1839551469", gain = 0.87 }, -- Vienna Waltz · Johann Strauss I (1800'S SALON PIANO), 2:04
				{ id = "rbxassetid://1845480542", gain = 0.72 }, -- Ballroom Waltz · Isy Geiger (ALPINE HOLIDAY), 3:02
				{ id = "rbxassetid://9047452775", gain = 1.05 }, -- Ballroom Waltz · Marvin McMahon (Wonderland), 2:07
				{ id = "rbxassetid://1839551405", gain = 0.94 }, -- Beauty Waltz · Peter Tchaikovsky (1800'S SALON PIANO), 1:35
				{ id = "rbxassetid://1838535855", gain = 0.98 }, -- Waltz Of The Flowers · Peter Tchaikovsky (POPULAR CLASSICS), 4:11
				{ id = "rbxassetid://1842365951", gain = 1.00 }, -- Skater's Waltz · KPM 1000 LP Series (FUN TIME), 4:29
			},
		},
		-- One track of your own in place of a playlist ("rbxassetid://<id>"), e.g. the house's own
		-- composed loops in assets/audio. "" plays the playlist. (A track named maison-lounge,
		-- maison-table or maison-ballroom in SoundService is used if a playlist is emptied.)
		Tracks = {
			lounge = "",
			table = "",
			ballroom = "",
		},
		Music = { street = "", foyer = "", salon = "", velvet = "", obsidian = "", midnight = "", club = "", library = "", ballroom = "", boutique = "", vault = "", suite = "", terrace = "" },
		-- A fuller layer for each room that rises as the run builds (optional).
		MusicLayers = { salon = "", velvet = "", obsidian = "", midnight = "", library = "" },
		-- The Ballroom band in stems, so it thins as lamps go out. Unset stems fall back to Music.ballroom.
		Band = { full = "", bass = "", piano = "", clock = "" },
		Ambience = { street = "", foyer = "", salon = "", velvet = "", obsidian = "", midnight = "", club = "", library = "", ballroom = "", terrace = "" },
		-- A seasonal layer under the ambience, by season id: rain on glass, a fire, crickets.
		SeasonAmbience = { frost = "", yule = "", summer = "", harvest = "", longtable = "", bloom = "" },
		Animations = {
			idle = "rbxassetid://507766666",
			walk = "rbxassetid://507777826",
			bow = "",
			gesture = "",
			applause = "",
			tipHat = "",
			term = "",
			pianist = "", -- the Pianist playing (looped); with none set they sway at the keys
		},
		-- House looks: clothing for each outfit (Shirt and Pants template ids, accessory ids
		-- comma-separated). A look is only sold once its clothing is set.
		Looks = {
			velvet = { shirt = 0, pants = 0, accessories = "" },
			gown = { shirt = 0, pants = 0, accessories = "" },
			tux = { shirt = 0, pants = 0, accessories = "" },
			cape = { shirt = 0, pants = 0, accessories = "" },
			goldKey1 = { shirt = 0, pants = 0, accessories = "" },
			goldKey2 = { shirt = 0, pants = 0, accessories = "" },
			goldKey3 = { shirt = 0, pants = 0, accessories = "" },
			patron = { shirt = 0, pants = 0, accessories = "" },
			connoisseur = { shirt = 0, pants = 0, accessories = "" },
			custodian = { shirt = 0, pants = 0, accessories = "" },
			keeper = { shirt = 0, pants = 0, accessories = "" },
			term = { shirt = 0, pants = 0, accessories = "" },
			-- The Black Card's cardholder looks, one each month in turn.
			card1 = { shirt = 0, pants = 0, accessories = "" },
			card2 = { shirt = 0, pants = 0, accessories = "" },
			card3 = { shirt = 0, pants = 0, accessories = "" },
			card4 = { shirt = 0, pants = 0, accessories = "" },
			card5 = { shirt = 0, pants = 0, accessories = "" },
			card6 = { shirt = 0, pants = 0, accessories = "" },
		},
		Concierge = { shirt = 0, pants = 0, accessories = "" },
		Doorman = { shirt = 0, pants = 0, accessories = "" },
		Pianist = { shirt = 0, pants = 0, accessories = "" },
	},
}

Config.data = defaults

-- Flattens the defaults into "A.b.c" paths so LiveConfig knows which keys to look up.
local function flatten(tree: { [string]: any }, prefix: string, out: { string })
	for key, value in tree do
		local path = if prefix == "" then key else prefix .. "." .. key
		if type(value) == "table" then
			flatten(value, path, out)
		else
			table.insert(out, path)
		end
	end
end

function Config.paths(): { string }
	local out = {}
	flatten(defaults, "", out)
	table.sort(out)
	return out
end

function Config.get(path: string): any
	local node: any = defaults
	for segment in string.gmatch(path, "[^%.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[tonumber(segment) or segment]
	end
	return node
end

-- Sets one value by path. Only existing leaves can be overridden, and the type must match.
function Config.set(path: string, value: any): boolean
	local node: any = defaults
	local segments = {}
	for segment in string.gmatch(path, "[^%.]+") do
		table.insert(segments, segment)
	end
	for i = 1, #segments - 1 do
		node = node[tonumber(segments[i]) or segments[i]]
		if type(node) ~= "table" then
			return false
		end
	end
	local leaf: any = segments[#segments]
	leaf = tonumber(leaf) or leaf
	local current = node[leaf]
	if current == nil or type(current) == "table" then
		return false
	end
	if type(current) ~= type(value) then
		return false
	end
	node[leaf] = value
	return true
end

function Config.applyOverrides(overrides: { [string]: any }): number
	local applied = 0
	for path, value in overrides do
		if Config.set(path, value) then
			applied += 1
		end
	end
	return applied
end

return Config

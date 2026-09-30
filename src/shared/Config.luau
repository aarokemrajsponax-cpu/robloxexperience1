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

	-- Developer products and passes (Appendix I3). Create them in the Creator Dashboard and put
	-- their ids here (or in Roblox Configs); 0 means not on sale yet. Prices are always read live.
	Products = {
		tier49 = 0, tier79 = 0, tier99 = 0, tier149 = 0, tier199 = 0,
		tier249 = 0, tier299 = 0, tier399 = 0, tier499 = 0, tier599 = 0,
		introduction = 0, -- once per account, first 7 days, only in the Boutique
		ledger = 0, -- the Leather-Bound Ledger, per Term
		season = 0, -- a season collection
		goldKey = 0, -- a game pass
		introductionDays = 7,
		giftTimeout = 120, -- seconds a chosen gift waits for its purchase
	},

	-- The Founding Term's id (for example "2026-autumn"): set it at launch; guests who play in it
	-- get the Founding Term badge and its dated rewards.
	FoundingTerm = "",

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
	},

	FirstMinute = {
		target = 60, -- seconds from Play to the first filing
		straightToTableOfferSeconds = 12,
	},

	Movement = {
		walkSpeed = 12,
		runSpeed = 19,
		npcWalkSpeed = 9,
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
		-- Placeholders from Roblox's built-in sounds until real ones are chosen (see README).
		-- Use "rbxassetid://<id>" for an uploaded or Creator Store sound; "" plays nothing.
		Sounds = {
			chime = "rbxasset://sounds/electronicpingshort.wav", -- pitched per streak step
			pickup = "rbxasset://sounds/action_get_up.mp3",
			drop = "rbxasset://sounds/action_jump_land.mp3",
			wrong = "rbxasset://sounds/action_jump_land.mp3", -- played low and quiet: a muted knock
			ui = "",
			round = "rbxasset://sounds/electronicpingshort.wav",
			complete = "rbxasset://sounds/electronicpingshort.wav",
			door = "",
			chair = "rbxasset://sounds/action_get_up.mp3",
			low = "rbxasset://sounds/electronicpingshort.wav", -- the clock's last ten seconds, played low
			-- Chimes sold in the Boutique: a sound each. A chime is only sold once its sound is set.
			chimes = { harp = "", musicBox = "", celesta = "", glass = "" },
		},
		Music = { street = "", foyer = "", salon = "", velvet = "", obsidian = "", midnight = "", club = "", library = "", ballroom = "" },
		Ambience = { street = "", foyer = "", salon = "", velvet = "", obsidian = "", midnight = "", club = "", library = "", ballroom = "" },
		Animations = {
			idle = "rbxassetid://507766666",
			walk = "rbxassetid://507777826",
			bow = "",
			gesture = "",
			applause = "",
			tipHat = "",
			term = "",
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
		},
		Concierge = { shirt = 0, pants = 0, accessories = "" },
		Doorman = { shirt = 0, pants = 0, accessories = "" },
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

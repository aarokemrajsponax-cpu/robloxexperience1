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
		},
		Music = { street = "", foyer = "", salon = "" },
		Ambience = { street = "", foyer = "", salon = "" },
		Animations = {
			idle = "rbxassetid://507766666",
			walk = "rbxassetid://507777826",
			bow = "",
			gesture = "",
			applause = "",
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
		node = node[segment]
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
		node = node[segments[i]]
		if type(node) ~= "table" then
			return false
		end
	end
	local leaf = segments[#segments]
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

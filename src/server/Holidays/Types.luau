--!strict
-- The shapes the holiday games share (server/Holidays and its games).

local Types = {}

-- Config.HolidayGames.
export type Cfg = {
	windows: { [string]: { lead: number, linger: number } },
	gemsPerDay: number,
	travelGap: number,
	lane: {
		origin: { number },
		gilt: number,
		gemChance: number,
		minuitGilt: number,
		fullBagGilt: number,
		fullBagGems: number,
		roundMinutes: number,
		reach: number,
		knockGap: number,
	},
	field: {
		origin: { number },
		turkeys: number,
		gilt: number,
		gemChance: number,
		goldenGilt: number,
		goldenGems: number,
		goldenEvery: number,
		speed: number,
		goldenSpeed: number,
		fear: number,
		catch: number,
		reach: number,
		tireAfter: number,
		tired: number,
		back: number,
		catchGap: number,
		freeCatches: number,
		visitGap: number,
		moreCatches: number,
	},
	pole: {
		origin: { number },
		seats: number,
		boarding: number,
		flight: number,
		stay: number,
		gifts: number,
		freeRides: number,
		carry: number,
		tripMost: number,
		dayMost: number,
		reach: number,
		loadReach: number,
		odds: { [string]: number },
		gilt: { number },
		moreGilt: { number },
		gems: { number },
		moreGems: { number },
	},
	eggs: {
		count: number,
		gilt: number,
		gemChance: number,
		goldenGilt: number,
		goldenGems: number,
		again: number,
		reach: number,
	},
	luck: { mythic: number, curioFind: number, curioRare: number },
}

-- A guest's holiday page in their saved record: today's Gems from the games (the ceiling), the
-- North Pole's gifts waiting to be opened and those loaded today, the Lane's round and the doors
-- knocked at in it, and how many sleigh rides there have been. What's been bought: turkey catches
-- held, the Turkey Hunter Pass's year, sleigh rides held and Santa's Season Pass's year; and the
-- free sleigh rides taken this year (`rideYear`, `freeTaken`).
export type Saved = {
	day: number,
	gems: number,
	gifts: number,
	loaded: number,
	round: number,
	doors: { [string]: boolean },
	trips: number,
	catches: number,
	hunterYear: number,
	rides: number,
	seasonYear: number,
	rideYear: number,
	freeTaken: number,
}

-- What every game works through (server/Holidays makes it).
export type Ctx = {
	cfg: () -> Cfg,
	rng: Random,
	folder: () -> Folder,
	rootOf: (player: Player) -> BasePart?,
	trusted: (player: Player) -> boolean,
	moved: (player: Player) -> (),
	saved: (data: any) -> Saved,
	reward: (player: Player, gilt: number, gems: number, source: string) -> (number, number),
	gemsLeft: (player: Player) -> number,
	send: (player: Player, message: { [string]: any }) -> (),
	broadcast: (message: { [string]: any }) -> (),
	teleport: (player: Player, cf: CFrame) -> boolean,
	sendHome: (player: Player, spread: number?) -> (),
	inArea: (player: Player, area: string) -> boolean,
	isSeated: (player: Player) -> boolean,
	award: (player: Player, key: string) -> (),
	tally: (player: Player, stat: string, n: number, once: string?) -> (),
	curio: (player: Player, id: string, key: string) -> boolean,
	salute: (title: string, line: string, by: Player?) -> (),
	-- The live Robux price of a holiday product (nil until Roblox says).
	price: (key: string) -> number?,
	year: () -> number,
}

-- A game: built when it opens, taken down when it closes, a beat ten times a second.
export type Game = {
	open: (ctx: Ctx) -> (),
	close: (ctx: Ctx) -> (),
	step: ((ctx: Ctx, dt: number) -> ())?,
	-- Where a guest arrives when they ask to go (nil: it's in the house, or not now).
	arrival: ((ctx: Ctx, player: Player) -> CFrame?)?,
	-- Whether a guest may go home now.
	leaving: ((ctx: Ctx, player: Player) -> boolean)?,
	-- What a guest's screen is told about their part in it.
	state: ((ctx: Ctx, player: Player) -> { [string]: any })?,
	-- A guest left the house (or respawned).
	leave: ((ctx: Ctx, player: Player) -> ())?,
}

return Types

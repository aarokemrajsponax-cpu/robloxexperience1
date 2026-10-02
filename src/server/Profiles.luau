--!strict
-- Saved profiles: session-locked with ProfileStore, schema-versioned with migrations,
-- autosaved, saved on leave and on shutdown. In Studio without API access ProfileStore
-- falls back to a mock store, so everything still works (it just isn't kept).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(ReplicatedStorage.Shared.Settings)
local ProfileStore = require(script.Parent.Vendor.ProfileStore)

local Profiles = {}

export type RegisterEntry = { first: number, count: number, best: string }
export type NightlyRecord = { day: number, key: string, score: number, grade: string, rounds: { string }, room: string, finished: boolean }
export type Opponent = { userId: number, name: string, at: number }
export type DuelRecord = { r: number, rd: number, vol: number, matches: number, wins: number, losses: number, termMatches: number, term: string, best: number, recent: { Opponent } }

export type Data = {
	schema: number,
	visits: number,
	firstVisit: number,
	nights: { count: number, lastDay: number },
	settings: { [string]: any },
	flags: { [string]: boolean },
	register: { [string]: RegisterEntry },
	stats: { runs: number, rounds: number, filings: number, correct: number, flawless: number, nightlies: number },
	nightly: NightlyRecord,
	duel: DuelRecord,
	rival: { week: number, userId: number, name: string, source: string },
	ballroom: { evenings: number, lastLamps: number, topFive: number, keys: number, bestKeys: number, week: number, weekPoints: number },
	best: { [string]: number },
	bestRound: { [string]: number },
	gilt: number,
	giltDay: { day: number, earned: number },
	purchases: { [string]: number },
	-- The Boutique (Delivery 5)
	owned: { [string]: boolean },
	equipped: { [string]: string },
	credits: { [string]: number }, -- Boutique credit by price tier, from a purchase with no choice on file
	receipts: { string }, -- the last purchase ids granted (idempotent receipts)
	pending: { product: string, item: string, giftTo: number, at: number },
	goldKey: boolean,
	doubleGilt: boolean,
	introduction: boolean,
	ledger: { term: string, points: number, freeClaimed: number, leatherClaimed: number, leather: { [string]: boolean } },
	gifts: { { from: string, item: string, at: number } },
	-- The Register and the Vault (Delivery 6)
	badges: { [string]: boolean },
	mythics: { { id: string, serial: number, at: number, room: string } },
	commissions: { evening: { key: string, progress: number, done: boolean }, week: { key: string, progress: number, done: boolean } },
	standing: string,
	-- The Black Card: held now (re-checked with Roblox every visit), and the months claimed.
	blackCard: { active: boolean, months: { [string]: boolean } },
	-- The Suite: the piece in each spot (Suite.Spots); a missing spot shows the house's own piece.
	suite: { [string]: string },
	-- Circles: the one you're in ("" for none), and your points this week.
	circle: { id: string, week: number, points: number },
	-- What the house remembers about you: the last visit, the last thing worth mentioning, the
	-- tables you sit at most, admiration, and the day you last signed the Livre d'Or.
	memory: { lastSeen: number, highlight: string, highlightAt: number, tables: { [string]: number }, admired: number, admiredSince: number, signedDay: number },
}

local TEMPLATE: Data = {
	schema = Config.data.Profiles.schemaVersion,
	visits = 0,
	firstVisit = 0,
	nights = { count = 0, lastDay = -1 },
	settings = {},
	flags = {},
	register = {},
	stats = { runs = 0, rounds = 0, filings = 0, correct = 0, flawless = 0, nightlies = 0 },
	nightly = { day = -1, key = "", score = 0, grade = "", rounds = {}, room = "", finished = false },
	rival = { week = -1, userId = 0, name = "", source = "" },
	ballroom = { evenings = 0, lastLamps = 0, topFive = 0, keys = 0, bestKeys = 0, week = -1, weekPoints = 0 },
	duel = { r = 1500, rd = 350, vol = 0.06, matches = 0, wins = 0, losses = 0, termMatches = 0, term = "", best = 0, recent = {} },
	best = { salon = 0, velvet = 0, obsidian = 0, midnight = 0 },
	bestRound = { salon = 0, velvet = 0, obsidian = 0, midnight = 0 },
	gilt = 0,
	giltDay = { day = -1, earned = 0 },
	purchases = {},
	owned = {},
	equipped = { look = "", table = "", lamp = "", chime = "", trail = "", nameplate = "", card = "", flourish = "", gesture = "" },
	credits = {},
	receipts = {},
	pending = { product = "", item = "", giftTo = 0, at = 0 },
	goldKey = false,
	doubleGilt = false,
	introduction = false,
	ledger = { term = "", points = 0, freeClaimed = 0, leatherClaimed = 0, leather = {} },
	gifts = {},
	badges = {},
	mythics = {},
	commissions = { evening = { key = "", progress = 0, done = false }, week = { key = "", progress = 0, done = false } },
	standing = "Guest",
	blackCard = { active = false, months = {} },
	suite = {},
	circle = { id = "", week = -1, points = 0 },
	memory = { lastSeen = 0, highlight = "", highlightAt = 0, tables = {}, admired = 0, admiredSince = 0, signedDay = -1 },
}

-- Each migration moves data from schema n to n + 1. Add new ones at the end.
local MIGRATIONS: { [number]: (data: any) -> () } = {
	-- [1] = function(data) ... end, -- 1 -> 2
}

local function migrate(data: any)
	local target = Config.data.Profiles.schemaVersion
	local version = if type(data.schema) == "number" then data.schema else 1
	while version < target do
		local step = MIGRATIONS[version]
		if step then
			step(data)
		end
		version += 1
	end
	data.schema = target
	data.settings = Settings.sanitize(data.settings)
end

local store = ProfileStore.New(Config.data.Profiles.storeName, TEMPLATE)
local active: { [Player]: any } = {}
local loadedEvent = Instance.new("BindableEvent")

Profiles.Loaded = loadedEvent.Event -- (player, data)

function Profiles.get(player: Player): Data?
	local profile = active[player]
	if profile and profile:IsActive() then
		return profile.Data :: Data
	end
	return nil
end

-- The live ProfileStore profile (for receipts, which must wait for a save).
function Profiles.profile(player: Player): any
	local profile = active[player]
	if profile and profile:IsActive() then
		return profile
	end
	return nil
end

function Profiles.isMock(): boolean
	return ProfileStore.DataStoreState ~= "Access"
end

-- Yields until the guest's profile is ready (or they leave / it times out).
function Profiles.wait(player: Player, timeout: number?): Data?
	local limit = os.clock() + (timeout or 30)
	while player.Parent == Players and os.clock() < limit do
		local data = Profiles.get(player)
		if data then
			return data
		end
		task.wait(0.1)
	end
	return Profiles.get(player)
end

local function load(player: Player)
	local profile = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	} :: any)
	if profile == nil then
		player:Kick("The house couldn't open your ledger just now. Please join again.")
		return
	end
	profile:AddUserId(player.UserId)
	profile:Reconcile()
	migrate(profile.Data)
	profile.OnSessionEnd:Connect(function()
		active[player] = nil
		if player.Parent == Players then
			player:Kick("You've been seated in another room of the house.")
		end
	end)
	if player.Parent == Players then
		active[player] = profile
		loadedEvent:Fire(player, profile.Data)
	else
		profile:EndSession()
	end
end

function Profiles.start()
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		local profile = active[player]
		if profile then
			active[player] = nil
			profile:EndSession()
		end
	end)
end

return Profiles

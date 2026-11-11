--!strict
-- A guest's Fortune on the server (shared/Fortune says what it is): worked out from their saved
-- record every couple of seconds and published on the player ("Fortune", "FortuneRank",
-- "FortuneEarned", "Estate"), so every screen shows the server's number and never its own.
--   * Fortune.estate adds to the Estate (a haul banked, a chest won) and pays its cash share in
--     Gilt through Gilt.pay (the house's boosts and its daily soft cap). The Estate never falls.
--   * The Wealthiest boards rank the Fortune EARNED: Gilt and Gems bought with Robux are taken off
--     (Fortune.bought is told of every purse and Gem pack), so the top of the board can't be bought.
--     All-time, and this week's gain (weeks start Monday, UTC). A guest who turns "Show my Fortune"
--     off in Settings is left off the boards and out of the house's announcements.
--   * A new wealth rank is told to the guest, and from Config.Fortune.announceFrom to the house.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local Names = require(ReplicatedStorage.Shared.Names)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Gate = require(script.Parent.Gate)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)

local Fortune = {}

---------------------------------------------------------------------------------------------------
-- Hooks (set by Main)
---------------------------------------------------------------------------------------------------
-- A guest reached a new wealth rank (`public`: told to the whole house too).
Fortune.ranked = function(_player: Player, _rank: Rules.Rank, _number: number, _public: boolean) end
-- Something was added to a guest's Estate (for the objectives and the Badge Book).
Fortune.added = function(_player: Player, _worth: number, _source: string) end

export type Page = {
	estate: number, -- everything banked from the attractions; never falls
	bought: number, -- Gilt bought with Robux (left out of the boards)
	boughtGems: number, -- Gems bought with Robux (left out of the boards)
	rank: number, -- the highest wealth rank reached (its number), so each is told once
	week: number, -- the week the weekly board's start was taken in
	weekStart: number, -- the Fortune earned as that week began
	hauls: number, -- how many times something was banked
}

local function cfg(): { [string]: any }
	return (Config.data :: any).Fortune
end

local function count(v: any): number
	return if type(v) == "number" and v == v and v > 0 then math.floor(v) else 0
end

-- Weeks start Monday 00:00 UTC (Unix day 0 was a Thursday): the same weeks as the house's boards.
local function weekIndex(): number
	return math.floor((math.floor(os.time() / 86400) + 3) / 7)
end

-- A guest's Fortune page in their saved record (made, and kept sane, on first asking).
function Fortune.page(data: Profiles.Data): Page
	local d = data :: any
	if type(d.empire) ~= "table" then
		d.empire = {}
	end
	local e = d.empire
	e.estate = count(e.estate)
	e.bought = count(e.bought)
	e.boughtGems = count(e.boughtGems)
	e.rank = math.max(1, count(e.rank))
	e.week = if type(e.week) == "number" then e.week else -1
	e.weekStart = count(e.weekStart)
	e.hauls = count(e.hauls)
	return e :: Page
end

-- What a guest owns, part by part.
function Fortune.parts(data: Profiles.Data): Rules.Parts
	local d = data :: any
	local page = Fortune.page(data)
	local collection = 0
	local items = d.curios and d.curios.items
	if type(items) == "table" then
		for id, n in items do
			local c = CurioList.byId[id]
			if c and type(n) == "number" and n > 0 then
				collection += (Rules.RarityWorth[c.rarity] or 0) * math.floor(n)
			end
		end
	end
	if type(d.mythics) == "table" then
		collection += #d.mythics * (tonumber(cfg().mythicWorth) or 0)
	end
	local suite = 0
	if type(d.owned) == "table" then
		for id, has in d.owned do
			if has == true then
				local item = Wardrobe.get(id)
				if item and type(item.gilt) == "number" then
					suite += item.gilt
				end
			end
		end
	end
	return {
		gilt = count(d.gilt),
		gems = count(d.gems) * (tonumber(cfg().gemWorth) or 0),
		collection = collection,
		suite = suite,
		estate = page.estate,
	}
end

-- A guest's Fortune, and the part of it they've earned (what the boards rank).
function Fortune.of(data: Profiles.Data): (number, number)
	local page = Fortune.page(data)
	local total = Rules.total(Fortune.parts(data))
	local earned = math.max(0, total - page.bought - page.boughtGems * (tonumber(cfg().gemWorth) or 0))
	return total, earned
end

local function shown(data: Profiles.Data): boolean
	return (data.settings :: any).showFortune ~= "Off"
end

-- Works a guest's Fortune out again and publishes it; a new rank is told once.
function Fortune.sync(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local page = Fortune.page(data)
	local total, earned = Fortune.of(data)
	local rank, number = Rules.rank(total)
	local week = weekIndex()
	if page.week ~= week then
		page.week = week
		page.weekStart = earned
	end
	player:SetAttribute("Fortune", total)
	player:SetAttribute("FortuneEarned", earned)
	player:SetAttribute("FortuneRank", number)
	player:SetAttribute("Estate", page.estate)
	if number > page.rank then
		local first = page.rank
		page.rank = number
		-- (A guest from before Fortunes began arrives at their rank quietly: only a rank reached
		-- while playing is told. `first == 1 and hauls == 0`: nothing banked yet, so it's their past.)
		local quiet = first == 1 and page.hauls == 0 and number > 2
		if not quiet then
			Fortune.ranked(player, rank, number, number >= (tonumber(cfg().announceFrom) or 99) and shown(data))
		end
	end
end

-- Adds `worth` to a guest's Estate and pays its cash share in Gilt. Returns the Gilt paid.
function Fortune.estate(player: Player, worth: number, source: string, cash: boolean?): number
	local data = Profiles.get(player)
	worth = count(worth)
	if not data or worth <= 0 then
		return 0
	end
	local page = Fortune.page(data)
	page.estate += worth
	page.hauls += 1
	local paid = 0
	if cash ~= false then
		local share = Rules.cash(worth)
		if share > 0 then
			paid = Gilt.pay(player, data, share, source)
		end
	end
	Fortune.added(player, worth, source)
	Fortune.sync(player)
	return paid
end

-- Gilt or Gems bought with Robux: counted, so the boards can leave them out.
function Fortune.bought(data: Profiles.Data, gilt: number, gems: number)
	local page = Fortune.page(data)
	page.bought += count(gilt)
	page.boughtGems += count(gems)
end

---------------------------------------------------------------------------------------------------
-- The Wealthiest boards
---------------------------------------------------------------------------------------------------
export type Entry = { userId: number, name: string, score: number }
local boards: { all: { Entry }, week: { Entry }, available: boolean, at: number } = { all = {}, week = {}, available = false, at = 0 }
local names: { [number]: string } = {}
local sent: { [Player]: { all: number, week: number } } = {}

local function allStore(): any
	return DataStoreService:GetOrderedDataStore(tostring(cfg().store))
end
local function weekStore(): any
	return DataStoreService:GetOrderedDataStore(tostring(cfg().store) .. "_week_" .. weekIndex())
end

local function nameOf(userId: number): string
	local known = names[userId]
	if known then
		return known
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then Names.of(player) else nil
	if not name then
		local ok, found = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok and type(found) == "string" then found else "A guest"
	end
	names[userId] = name :: string
	return name :: string
end

local function read(store: any, name: string): { Entry }?
	local size = math.clamp(tonumber(cfg().boardSize) or 25, 5, 100)
	local ok, page = Gate.read(name, function()
		return store:GetSortedAsync(false, size):GetCurrentPage()
	end)
	if not ok or type(page) ~= "table" then
		return nil
	end
	local out: { Entry } = {}
	for _, item in page :: { any } do
		local userId = tonumber(item.key)
		if userId and type(item.value) == "number" and item.value > 0 then
			table.insert(out, { userId = userId, name = nameOf(userId), score = item.value })
		end
	end
	return out
end

-- Reads both boards (kept until the next read; a store that doesn't answer keeps the last).
function Fortune.refreshBoards()
	local all = read(allStore(), "wealth:all")
	local week = read(weekStore(), "wealth:week")
	if all then
		boards.all = all
	end
	if week then
		boards.week = week
	end
	boards.available = all ~= nil or boards.available
	boards.at = os.time()
end

-- The Wealthiest board of all time as last read (the Grand Ballroom's Hall of Fame shows it too).
function Fortune.top(): { Entry }
	return boards.all
end

-- Offers a guest's earned Fortune (and this week's gain) to the boards, when it has changed.
function Fortune.submit(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local page = Fortune.page(data)
	local _, earned = Fortune.of(data)
	local gain = math.max(0, earned - page.weekStart)
	local last: { all: number, week: number } = sent[player] :: any
	if not last then
		last = { all = -1, week = -1 }
		sent[player] = last
	end
	local key = tostring(player.UserId)
	if not shown(data) then
		-- Off the boards: whatever was there is taken down once.
		if last.all ~= 0 or last.week ~= 0 then
			last.all, last.week = 0, 0
			Gate.write("wealth:all", function()
				allStore():RemoveAsync(key)
			end)
			Gate.write("wealth:week", function()
				weekStore():RemoveAsync(key)
			end)
		end
		return
	end
	if earned ~= last.all and earned > 0 then
		last.all = earned
		Gate.write("wealth:all", function()
			allStore():SetAsync(key, earned)
		end)
	end
	if gain ~= last.week and gain > 0 then
		last.week = gain
		Gate.write("wealth:week", function()
			weekStore():SetAsync(key, gain)
		end)
	end
end

-- What a guest's Fortune screen shows: the parts, the rank, the boards and the wealthiest here.
function Fortune.view(player: Player): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local page = Fortune.page(data)
	local parts = Fortune.parts(data)
	local total, earned = Fortune.of(data)
	local _, number = Rules.rank(total)
	local here: { Entry } = {}
	for _, p in Players:GetPlayers() do
		local d = Profiles.get(p)
		if d and shown(d) then
			local _, e = Fortune.of(d)
			table.insert(here, { userId = p.UserId, name = Names.of(p), score = e })
		end
	end
	table.sort(here, function(a, b)
		return if a.score ~= b.score then a.score > b.score else a.userId < b.userId
	end)
	return {
		ok = true,
		total = total,
		earned = earned,
		rank = number,
		parts = parts,
		hauls = page.hauls,
		week = math.max(0, earned - page.weekStart),
		shown = shown(data),
		boards = { all = boards.all, week = boards.week, here = here, available = boards.available },
	}
end

function Fortune.start()
	Profiles.Loaded:Connect(function(player: Player)
		Fortune.sync(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		pcall(Fortune.submit, player)
		sent[player] = nil
	end)
	task.spawn(function()
		local sinceBoard = math.huge
		while true do
			local dt = task.wait(math.max(0.5, tonumber(cfg().syncSeconds) or 2))
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(Fortune.sync :: any, player)
				if not ok then
					warn("[Maison] A Fortune couldn't be worked out: " .. tostring(err))
				end
			end
			sinceBoard += dt
			if sinceBoard >= (tonumber(cfg().boardSeconds) or 90) then
				sinceBoard = 0
				for _, player in Players:GetPlayers() do
					pcall(Fortune.submit, player)
				end
				pcall(Fortune.refreshBoards)
			end
		end
	end)
end

return Fortune

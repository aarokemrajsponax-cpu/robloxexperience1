--!strict
-- The Badge Book on the server: what each guest has earned. A ladder badge (rounds, levels,
-- nights...) is checked against the guest's own record whenever something might have moved it; a
-- moment badge (the golden egg, the owner's arrival) is given where it happens. Each is kept in the
-- guest's record with the day it came, said on their screen, and, when Config.Badges has a Roblox
-- badge id for it, awarded on Roblox too. Nothing a guest's screen sends can give a badge.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BadgeBook = require(ReplicatedStorage.Shared.BadgeBook)
local Config = require(ReplicatedStorage.Shared.Config)
local Levels = require(ReplicatedStorage.Shared.Levels)
local Analytics = require(script.Parent.Analytics)
local Profiles = require(script.Parent.Profiles)

local Achievements = {}

-- Tells the guest's screen (set by Main).
Achievements.notify = function(_player: Player, _badge: BadgeBook.Badge) end

local function record(data: Profiles.Data): any
	local d = data :: any
	d.badges = d.badges or {}
	d.badgeAt = d.badgeAt or {}
	d.tally = d.tally or {}
	d.tallyOnce = d.tallyOnce or {}
	return d
end
Achievements.record = record

-- The counts the ladders climb, read from the guest's record.
function Achievements.stats(data: Profiles.Data): { [string]: number }
	local d = record(data)
	local kinds = 0
	local items = if type(d.curios) == "table" and type(d.curios.items) == "table" then d.curios.items else {}
	for _, n in items do
		if type(n) == "number" and n > 0 then
			kinds += 1
		end
	end
	local register = 0
	for _ in (if type(d.register) == "table" then d.register else {}) do
		register += 1
	end
	local auras = 0
	local shop = d.gemShop
	if type(shop) == "table" and type(shop.owned) == "table" then
		for id in shop.owned do
			if string.sub(id, 1, 5) == "aura_" then
				auras += 1
			end
		end
	end
	local level = Levels.of(if type(d.level) == "table" then d.level.xp or 0 else 0)
	local t = d.tally
	-- (Every count read defensively: a record from long ago may not have them all.)
	local stats = if type(d.stats) == "table" then d.stats else {}
	local duel = if type(d.duel) == "table" then d.duel else {}
	local ballroom = if type(d.ballroom) == "table" then d.ballroom else {}
	local nights = if type(d.nights) == "table" then d.nights else {}
	local referral = if type(d.referral) == "table" then d.referral else {}
	return {
		level = level,
		rounds = stats.rounds or 0,
		correct = stats.correct or 0,
		flawless = stats.flawless or 0,
		nights = nights.count or 0,
		nightlies = stats.nightlies or 0,
		libraryWins = duel.wins or 0,
		libraryMatches = duel.matches or 0,
		ballroomEvenings = ballroom.evenings or 0,
		lastLamps = ballroom.lastLamps or 0,
		topFive = ballroom.topFive or 0,
		register = register,
		mythics = if type(d.mythics) == "table" then #d.mythics else 0,
		curiosFound = if type(d.curios) == "table" then d.curios.found or 0 else 0,
		curioKinds = kinds,
		gilt = if type(d.gilt) == "number" then d.gilt else 0,
		giltEarned = t.giltEarned or 0,
		pickups = t.pickups or 0,
		abuseNights = t.abuseNights or 0,
		trades = t.trades or 0,
		gemsSpent = t.gemsSpent or 0,
		auras = auras,
		referrals = referral.total or 0,
	}
end

local function give(player: Player, data: Profiles.Data, badge: BadgeBook.Badge, quiet: boolean?)
	local d = record(data)
	if d.badges[badge.key] then
		return
	end
	d.badges[badge.key] = true
	d.badgeAt[badge.key] = os.time()
	local id = (Config.data.Badges :: any)[badge.key]
	if type(id) == "number" and id ~= 0 then
		task.spawn(function()
			pcall(function()
				BadgeService:AwardBadge(player.UserId, id)
			end)
		end)
	end
	Analytics.custom(player, "Badge", nil, { key = badge.key })
	if not quiet then
		Achievements.notify(player, badge)
	end
end

-- A moment badge (or any badge by its key). Waits a little for the guest's record if it's still
-- being opened.
function Achievements.award(player: Player, key: string)
	local badge = BadgeBook.byKey[key]
	if not badge then
		return
	end
	local data = Profiles.get(player)
	if data then
		give(player, data, badge)
		return
	end
	task.spawn(function()
		local later = Profiles.wait(player, 30)
		if later and player.Parent == Players then
			give(player, later, badge)
		end
	end)
end

-- Every ladder badge the guest has climbed to by now. `quiet`: given without a word on screen
-- (on arrival, for what was earned before the Badge Book existed).
function Achievements.check(player: Player, quiet: boolean?)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local stats = Achievements.stats(data)
	local d = record(data)
	local told = 0
	for _, badge in BadgeBook.List do
		local stat, target = badge.stat, badge.target
		if stat and target and not d.badges[badge.key] and (stats[stat] or 0) >= target then
			-- (At most three said at once; the rest are kept just the same.)
			told += 1
			give(player, data, badge, quiet or told > 3)
		end
	end
end

-- Adds to one of the guest's own counts (things picked up at events, trades...). `once`: counted
-- only once for that key (one Admin Abuse Night, however often you rejoin during it).
function Achievements.tally(player: Player, stat: string, n: number, once: string?)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local d = record(data)
	if once then
		if d.tallyOnce[stat] == once then
			return
		end
		d.tallyOnce[stat] = once
	end
	d.tally[stat] = (d.tally[stat] or 0) + n
	Achievements.check(player)
end

-- Adds to a count without checking the ladders (for counts that change very often: Gilt earned).
function Achievements.add(player: Player, stat: string, n: number)
	local data = Profiles.get(player)
	if data then
		local d = record(data)
		d.tally[stat] = (d.tally[stat] or 0) + n
	end
end

-- The Badge Book as the guest's screen shows it: every badge, which are earned (and when), and how
-- far along each ladder they are.
function Achievements.view(data: Profiles.Data): { [string]: any }
	local d = record(data)
	local stats = Achievements.stats(data)
	local earned = {}
	local count = 0
	for key in d.badges do
		if BadgeBook.byKey[key] then
			earned[key] = d.badgeAt[key] or 0
			count += 1
		end
	end
	return { earned = earned, stats = stats, count = count, total = BadgeBook.count }
end

return Achievements

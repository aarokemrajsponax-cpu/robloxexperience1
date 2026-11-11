--!strict
-- The daily streak: a guest who comes to the house on consecutive days (UTC) keeps a streak, and
-- every Gilt they earn counts for a little more while it lasts (5% more a day, up to 30% from the
-- seventh day on); a day missed starts it again at one. At three, seven, fourteen and thirty days
-- in a row, and every thirty after, the house gives a few Gems (once each time the streak reaches
-- it). Everything is the server's own clock and record; a guest's screen is told their streak
-- (the attributes "Streak" and "StreakBoost", in whole percent) and, on their first visit of a
-- day, how it stands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Profiles = require(script.Parent.Profiles)

local Streak = {}

Streak.PER_DAY = 0.05
Streak.MOST = 0.30
Streak.GIFTS = { [3] = 5, [7] = 15, [14] = 30, [30] = 60 } :: { [number]: number }
Streak.now = os.time

-- A Gems gift was given (set by Main: the Gems on the guest's screen).
Streak.gemsGiven = function(_player: Player) end

export type Page = { day: number, count: number, best: number }

local function today(): number
	return math.floor(Streak.now() / 86400)
end

function Streak.page(data: Profiles.Data): Page
	local d = data :: any
	if type(d.streak) ~= "table" or type(d.streak.day) ~= "number" or type(d.streak.count) ~= "number" then
		d.streak = { day = -1, count = 0, best = 0 }
	end
	d.streak.best = tonumber(d.streak.best) or 0
	return d.streak :: Page
end

-- The Gems for reaching `count` days in a row (0 for none).
function Streak.gift(count: number): number
	local g = Streak.GIFTS[count]
	if g then
		return g
	end
	if count > 30 and count % 30 == 0 then
		return 60
	end
	return 0
end

-- The next day in a row that brings Gems, after `count`, and how many.
function Streak.nextGift(count: number): (number, number)
	for d = count + 1, count + 30 do
		local g = Streak.gift(d)
		if g > 0 then
			return d, g
		end
	end
	return count + 30, 60
end

-- How much more a guest's Gilt counts for (1 = none): 5% a day after the first, up to 30%.
function Streak.boostFor(count: number): number
	return 1 + math.clamp((count - 1) * Streak.PER_DAY, 0, Streak.MOST)
end

function Streak.mult(player: Player): number
	local data = Profiles.get(player)
	if not data then
		return 1
	end
	local p = Streak.page(data)
	-- (Only today's streak counts: one from days ago has lapsed.)
	if p.day < today() - 1 then
		return 1
	end
	return Streak.boostFor(p.count)
end

local function publish(player: Player, p: Page)
	player:SetAttribute("Streak", if p.count > 0 then p.count else nil)
	player:SetAttribute("StreakBoost", if p.count > 1 then math.floor((Streak.boostFor(p.count) - 1) * 100 + 0.5) else nil)
end

-- A guest arrives (or the day turns while they're here): the streak moves on a day, or starts
-- again; the day's gift, once.
function Streak.arrive(player: Player, data: Profiles.Data)
	local p = Streak.page(data)
	local now = today()
	if p.day == now then
		publish(player, p)
		return
	end
	local broke = p.count > 0 and p.day < now - 1
	if p.day == now - 1 then
		p.count += 1
	else
		p.count = 1
	end
	p.day = now
	p.best = math.max(p.best, p.count)
	local gems = Streak.gift(p.count)
	if gems > 0 then
		local d = data :: any
		d.gems = (tonumber(d.gems) or 0) + gems
		player:SetAttribute("Gems", d.gems)
		Analytics.source(player, "Gems", gems, d.gems, "Daily streak")
		Streak.gemsGiven(player)
	end
	publish(player, p)
	local giftAt, giftGems = Streak.nextGift(p.count)
	Remotes.event("Empire"):FireClient(player, {
		op = "streak",
		count = p.count,
		best = p.best,
		boost = math.floor((Streak.boostFor(p.count) - 1) * 100 + 0.5),
		next = math.floor((Streak.boostFor(p.count + 1) - 1) * 100 + 0.5),
		gems = gems,
		broke = broke,
		giftAt = giftAt,
		giftGems = giftGems,
	})
end

function Streak.start()
	Profiles.Loaded:Connect(function(player: Player, data: Profiles.Data)
		Streak.arrive(player, data)
	end)
	for _, player in Players:GetPlayers() do
		local data = Profiles.get(player)
		if data then
			Streak.arrive(player, data)
		end
	end
	-- (A guest here as the day turns: tomorrow's streak, then and there.)
	task.spawn(function()
		local seen = today()
		while true do
			task.wait(30)
			if today() ~= seen then
				seen = today()
				for _, player in Players:GetPlayers() do
					local data = Profiles.get(player)
					if data then
						Streak.arrive(player, data)
					end
				end
			end
		end
	end)
end

return Streak

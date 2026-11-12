--!strict
-- The daily streak: a guest who comes to the house on consecutive days (UTC) keeps a streak, and
-- every Gilt they earn counts for a little more while it lasts (5% more a day, up to 30% from the
-- seventh day on); a day missed starts it again at one. At three, seven, fourteen and thirty days
-- in a row, and every thirty after, the house gives a gift of Gilt (once each time the streak
-- reaches it; never Gems, which come only from Robux, the owner's gift or a trade). Everything is
-- the server's own clock and record; a guest's screen is told their streak
-- (the attributes "Streak" and "StreakBoost", in whole percent) and, on their first visit of a
-- day, how it stands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)

local Streak = {}

Streak.PER_DAY = 0.05
Streak.MOST = 0.30
-- The Gilt gifts (paid exactly, outside the day's soft cap), and every thirty days past thirty.
Streak.GIFTS = { [3] = 200, [7] = 600, [14] = 1200, [30] = 2400 } :: { [number]: number }
Streak.EVERY_THIRTY = 2400
Streak.now = os.time

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

-- The Gilt gift for reaching `count` days in a row (0 for none).
function Streak.gift(count: number): number
	local g = Streak.GIFTS[count]
	if g then
		return g
	end
	if count > 30 and count % 30 == 0 then
		return Streak.EVERY_THIRTY
	end
	return 0
end

-- The next day in a row that brings a gift, after `count`, and how much.
function Streak.nextGift(count: number): (number, number)
	for d = count + 1, count + 30 do
		local g = Streak.gift(d)
		if g > 0 then
			return d, g
		end
	end
	return count + 30, Streak.EVERY_THIRTY
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
	local gift = Streak.gift(p.count)
	local paid = if gift > 0 then Gilt.give(player, data, gift, "Daily streak") else 0
	publish(player, p)
	local giftAt, giftGilt = Streak.nextGift(p.count)
	Remotes.event("Empire"):FireClient(player, {
		op = "streak",
		count = p.count,
		best = p.best,
		boost = math.floor((Streak.boostFor(p.count) - 1) * 100 + 0.5),
		next = math.floor((Streak.boostFor(p.count + 1) - 1) * 100 + 0.5),
		gift = paid,
		broke = broke,
		giftAt = giftAt,
		giftGilt = giftGilt,
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

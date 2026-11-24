--!strict
-- Gilt, the house's currency (Appendix I1). Earned by playing (with a gentle daily soft cap),
-- or bought in purses. The Gold Key adds 20%; Double Gilt doubles everything earned; God-Mode
-- Luck multiplies it while it lasts; a friend in the house adds Config.Friends.giltBoost. Every boost together never exceeds
-- ProductConfig.Settings.MaxGiltMultiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Profiles)
local Analytics = require(script.Parent.Analytics)

local Gilt = {}

-- Called after every payment (the Ledger and the Shop tell the guest's screen).
Gilt.changed = function(_player: Player) end

-- The house's events (Golden Hour) multiply what's earned, and the day's soft cap with it.
Gilt.boost = function(): number
	return 1
end

-- A guest's own boost (God-Mode Luck; set by the purchase system), with the soft cap too.
Gilt.personal = function(_player: Player): number
	return 1
end

-- Friends in the house together: both earn more (Friends.giltBoost; set by Main).
Gilt.friends = function(_player: Player): number
	return 1
end

-- A guest's Gilt Surge from the Gem Shop (set by Main).
Gilt.surge = function(_player: Player): number
	return 1
end

-- (Build 96) A Gilt booster bought with Gilt in the Boutique (server/Boosters; set by Main).
Gilt.rush = function(_player: Player): number
	return 1
end

-- A new guest's welcome bonus for their first minutes of play (server/Newcomer; set by Main).
Gilt.welcome = function(_player: Player): number
	return 1
end

-- A guest's daily streak (server/Streak; set by Main): 5% more a day in a row, up to 30%.
Gilt.streak = function(_player: Player): number
	return 1
end

-- Every payment, counted for the Badge Book (set by Main). `fromPlay`: paid by Gilt.pay (what
-- the house's boosts multiply), not handed over as it stands (the squad's jar).
Gilt.earned = function(_player: Player, _paid: number, _fromPlay: boolean?) end

-- 12500 -> "12,500".
function Gilt.format(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

-- (Build 102) Everything that decides what earned Gilt pays a guest now: their boosts together,
-- the Gold Key's share, the day's soft cap, what they've earned today and the rate past the cap.
local function factors(player: Player, data: Profiles.Data): (number, number, number, number, number)
	local g = Config.data.Gilt
	local double = if data.doubleGilt then ProductConfig.byKey.doubleGilt.Reward.Multiplier else 1
	local key = if data.goldKey then 1 + g.goldKeyBonus else 1
	local cap = ProductConfig.Settings.MaxGiltMultiplier
	local boost = math.min(cap / key, math.max(1, Gilt.boost()) * double * math.max(1, Gilt.personal(player)) * math.max(1, Gilt.friends(player)) * math.max(1, Gilt.surge(player)) * math.max(1, Gilt.rush(player)) * math.max(1, Gilt.welcome(player)) * math.max(1, Gilt.streak(player)))
	local today = math.floor(os.time() / 86400)
	if data.giltDay.day ~= today then
		data.giltDay = { day = today, earned = 0 }
	end
	return boost, key, g.dailySoftCap, data.giltDay.earned, g.softCapRate
end

-- (Build 102) Puts those on the guest ("GiltBoost" and the rest), so their screen can show a
-- reward's exact Gilt before it's earned (shared/Fortune.quoteFor: the same sum as here).
function Gilt.publish(player: Player, data: Profiles.Data?)
	local d = data or Profiles.get(player)
	if not d then
		return
	end
	local boost, key, softCap, today, rate = factors(player, d)
	player:SetAttribute("GiltBoost", boost)
	player:SetAttribute("GiltKey", key)
	player:SetAttribute("GiltCap", softCap)
	player:SetAttribute("GiltToday", today)
	player:SetAttribute("GiltRate", rate)
end

-- (Build 102) What `earned` Gilt would pay this guest now, exactly as Gilt.pay would: nothing paid.
function Gilt.quote(player: Player, data: Profiles.Data, earned: number): number
	local boost, key, softCap, today, rate = factors(player, data)
	return Rules.giltPaid(earned, boost, key, softCap, today, rate)
end

-- Pays `earned` Gilt to a profile and returns what was actually paid (after the soft cap).
function Gilt.pay(player: Player, data: Profiles.Data, earned: number, source: string): number
	local paid = Gilt.quote(player, data, earned)
	return Gilt.payExact(player, data, paid, source)
end

-- (Build 102) Pays exactly `amount` of earned Gilt (a reward already quoted to the guest with
-- Gilt.quote and shown on their screen), counted toward the day like any earned Gilt.
function Gilt.payExact(player: Player, data: Profiles.Data, amount: number, source: string): number
	local paid = math.max(0, math.floor(amount))
	factors(player, data)
	data.giltDay.earned += paid
	data.gilt += paid
	Analytics.source(player, "Gilt", paid, data.gilt, source)
	Gilt.changed(player)
	Gilt.earned(player, paid, true)
	pcall(Gilt.publish, player, data)
	return paid
end

-- (Build 102) The figures above change with the time of day and the boosts running out: kept fresh
-- on every guest every couple of seconds (an attribute only goes out when it changes).
task.spawn(function()
	local Players = game:GetService("Players")
	while true do
		task.wait(2)
		for _, p in Players:GetPlayers() do
			pcall(Gilt.publish, p, nil)
		end
	end
end)

-- Pays `amount` exactly, with no boost and outside the daily soft cap: what the brainrot squad
-- earned on its own (server/Brainrots). Returns what was paid.
function Gilt.give(player: Player, data: Profiles.Data, amount: number, source: string): number
	local paid = math.max(0, math.floor(amount))
	if paid <= 0 then
		return 0
	end
	data.gilt += paid
	Analytics.source(player, "Gilt", paid, data.gilt, source)
	Gilt.changed(player)
	Gilt.earned(player, paid)
	return paid
end

return Gilt

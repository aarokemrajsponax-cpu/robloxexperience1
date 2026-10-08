--!strict
-- Gilt, the house's currency (Appendix I1). Earned by playing (with a gentle daily soft cap),
-- or bought in purses. The Gold Key adds 20%; Double Gilt doubles everything earned; God-Mode
-- Luck multiplies it while it lasts; a friend in the house adds Config.Friends.giltBoost. Every boost together never exceeds
-- ProductConfig.Settings.MaxGiltMultiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
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

-- 12500 -> "12,500".
function Gilt.format(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

-- Pays `earned` Gilt to a profile and returns what was actually paid (after the soft cap).
function Gilt.pay(player: Player, data: Profiles.Data, earned: number, source: string): number
	local g = Config.data.Gilt
	local double = if data.doubleGilt then ProductConfig.byKey.doubleGilt.Reward.Multiplier else 1
	local key = if data.goldKey then 1 + g.goldKeyBonus else 1
	local cap = ProductConfig.Settings.MaxGiltMultiplier
	local boost = math.min(cap / key, math.max(1, Gilt.boost()) * double * math.max(1, Gilt.personal(player)) * math.max(1, Gilt.friends(player)))
	earned = math.floor(earned * boost + 0.5)
	if data.goldKey then
		earned = math.floor(earned * key + 0.5)
	end
	local today = math.floor(os.time() / 86400)
	if data.giltDay.day ~= today then
		data.giltDay = { day = today, earned = 0 }
	end
	local full = math.max(0, math.min(earned, g.dailySoftCap * boost - data.giltDay.earned))
	local reduced = math.floor((earned - full) * g.softCapRate)
	local paid = full + reduced
	data.giltDay.earned += paid
	data.gilt += paid
	Analytics.source(player, "Gilt", paid, data.gilt, source)
	Gilt.changed(player)
	return paid
end

return Gilt

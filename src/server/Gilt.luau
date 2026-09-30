--!strict
-- Gilt, the house's earned currency (Appendix I1). Earned only by playing, never bought,
-- with a gentle daily soft cap. The Gold Key adds 20%.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(script.Parent.Profiles)
local Analytics = require(script.Parent.Analytics)

local Gilt = {}

-- Called after every payment (the Ledger and the Shop tell the guest's screen).
Gilt.changed = function(_player: Player) end

-- Pays `earned` Gilt to a profile and returns what was actually paid (after the soft cap).
function Gilt.pay(player: Player, data: Profiles.Data, earned: number, source: string): number
	local g = Config.data.Gilt
	if data.goldKey then
		earned = math.floor(earned * (1 + g.goldKeyBonus) + 0.5)
	end
	local today = math.floor(os.time() / 86400)
	if data.giltDay.day ~= today then
		data.giltDay = { day = today, earned = 0 }
	end
	local full = math.max(0, math.min(earned, g.dailySoftCap - data.giltDay.earned))
	local reduced = math.floor((earned - full) * g.softCapRate)
	local paid = full + reduced
	data.giltDay.earned += paid
	data.gilt += paid
	Analytics.source(player, "Gilt", paid, data.gilt, source)
	Gilt.changed(player)
	return paid
end

return Gilt

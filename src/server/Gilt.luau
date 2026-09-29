--!strict
-- Gilt, the house's earned currency (Appendix I1). Earned only by playing, never bought,
-- with a gentle daily soft cap. The Gold Key's +20% arrives with the Boutique (Delivery 5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(script.Parent.Profiles)
local Analytics = require(script.Parent.Analytics)

local Gilt = {}

-- Pays `earned` Gilt to a profile and returns what was actually paid (after the soft cap).
function Gilt.pay(player: Player, data: Profiles.Data, earned: number, source: string): number
	local g = Config.data.Gilt
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
	return paid
end

return Gilt

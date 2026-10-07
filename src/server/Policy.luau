--!strict
-- What Roblox's policy for each guest allows (PolicyService), asked once when they arrive. The
-- house needs one answer from it: may this guest trade things bought with Robux? (Roblox calls it
-- "paid item trading": curios bought with Gems are such things.) Until Roblox has answered, or if
-- it can't be asked, the answer is no: Gem-bought curios stay out of that guest's trades, and the
-- curios found at the tables trade as ever. Published to the guest's screen as the player
-- attribute "PaidTradingAllowed", so their trade screen shows only what they may offer.

local Players = game:GetService("Players")

local Policy = {}

local known: { [Player]: boolean } = {}

-- Asks Roblox. (Replaced in tests.)
Policy.lookup = function(player: Player): any
	return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
end

-- Asks again (it yields); the answer, or nil if Roblox couldn't say.
function Policy.refresh(player: Player): boolean?
	local ok, info = pcall(Policy.lookup, player)
	if ok and type(info) == "table" and type(info.IsPaidItemTradingAllowed) == "boolean" then
		known[player] = info.IsPaidItemTradingAllowed
		if player.Parent then
			player:SetAttribute("PaidTradingAllowed", info.IsPaidItemTradingAllowed)
		end
		return info.IsPaidItemTradingAllowed
	end
	return nil
end

-- What's known now, never yielding: false until Roblox has said yes.
function Policy.paidTradingKnown(player: Player): boolean
	return known[player] == true
end

-- Asks first if it isn't known yet (it may yield), then answers.
function Policy.paidTradingAllowed(player: Player): boolean
	if known[player] == nil then
		Policy.refresh(player)
	end
	return known[player] == true
end

function Policy.forget(player: Player)
	known[player] = nil
end

function Policy.start()
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(Policy.refresh, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(Policy.refresh, player)
	end
	Players.PlayerRemoving:Connect(Policy.forget)
end

return Policy

--!strict
-- Gifts and regional pricing. With Roblox's managed (regional) pricing, a guest in one country
-- can pay as little as 30% of what a guest elsewhere pays for the same product. A gift moves what
-- one guest paid for to another, so it could be used for price arbitrage: buying cheaply in one
-- region for players who'd pay full price. Roblox's guidance ("Protect your trades and gifts")
-- is to read each guest's relative price level with MarketplaceService:GetUsersPriceLevelsAsync
-- when they join (never cached between sessions) and regulate transfers with it.
--
-- The house's rule: a gift may go from one guest to another only if the giver's price level is
-- at least the recipient's (the giver paid at least what the recipient would have). If either
-- level isn't known (Roblox didn't answer), the gift isn't offered: it fails safe.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)

local PriceLevels = {}

local levels: { [number]: number } = {} -- UserId -> price level, this session only

-- Reads the price levels for some guests from Roblox (in one call). Unknown on failure.
function PriceLevels.fetch(players: { Player })
	local ids = {}
	for _, p in players do
		table.insert(ids, p.UserId)
	end
	if #ids == 0 then
		return
	end
	local ok, result = pcall(function()
		return MarketplaceService:GetUsersPriceLevelsAsync(ids)
	end)
	if not ok or type(result) ~= "table" then
		-- Nothing for the owner to fix (gifts simply wait, failing safe), so it isn't a warning.
		print("[Maison] Couldn't read price levels (gifts wait until Roblox answers): " .. tostring(result))
		return
	end
	for _, info in result :: { any } do
		if type(info) == "table" and type(info.UserId) == "number" and type(info.PriceLevel) == "number" then
			levels[info.UserId] = info.PriceLevel
		end
	end
end

-- A guest's price level, or nil if Roblox hasn't said.
function PriceLevels.of(player: Player): number?
	return levels[player.UserId]
end

-- May `giver` give `recipient` something bought with Robux? (And why not.) `ask`: when a level
-- isn't known yet, ask Roblox now (when a guest asks to gift; never inside a receipt, which uses
-- what was known when the gift was offered).
function PriceLevels.canGift(giver: Player, recipient: Player, ask: boolean?): (boolean, string?)
	if ask and (levels[giver.UserId] == nil or levels[recipient.UserId] == nil) then
		PriceLevels.fetch({ giver, recipient })
	end
	local from, to = levels[giver.UserId], levels[recipient.UserId]
	if from == nil or to == nil then
		return false, "Gifts can't be sent just now. Try again in a moment."
	end
	if from < to then
		return false, "Gifts to " .. Names.of(recipient) .. " aren't available from your region."
	end
	return true, nil
end

function PriceLevels.start()
	local function arrive(player: Player)
		task.spawn(PriceLevels.fetch, { player })
	end
	for _, p in Players:GetPlayers() do
		arrive(p)
	end
	Players.PlayerAdded:Connect(arrive)
	Players.PlayerRemoving:Connect(function(player: Player)
		levels[player.UserId] = nil
	end)
end

return PriceLevels

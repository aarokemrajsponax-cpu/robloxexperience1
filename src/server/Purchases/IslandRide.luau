--!strict
-- (Build 104) Luxury Island's rides for Robux (ProductConfig "islandJetSki", "islandHelicopter"):
-- each kept for good in the guest's island page (the same record a Gilt purchase writes), ridden
-- from the island. Until each product exists in Creator Hub it isn't offered: the Jet Ski Hire and
-- the island's card say so, and the ride is had for Gilt. Receipts are granted once each
-- (Purchases/Receipts); a ride already theirs is never offered again.

local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local IslandRide = {}

local NAMES = { jetski = "Jet Ski", heli = "Helicopter" }

local function islandPage(data: any): { [string]: any }
	data.attractions = if type(data.attractions) == "table" then data.attractions else {}
	local p = data.attractions.island
	if type(p) ~= "table" then
		p = {}
		data.attractions.island = p
	end
	if type(p.rides) ~= "table" then
		p.rides = {}
	end
	return p
end

function IslandRide.onSale(key: string): boolean
	return Store.sellable(key) ~= nil
end

-- Opens the purchase window (its price is in the window), or says it isn't on sale.
function IslandRide.offer(player: Player, key: string): (boolean, string?)
	local sell = Store.sellable(key)
	if not sell then
		return false, "That isn't on sale yet."
	end
	return Store.prompt(player, sell, "island")
end

local function grant(ctx: Grants.Context)
	local reward = ctx.product.Reward :: any
	if reward.Type ~= "IslandRide" or type(reward.Ride) ~= "string" or NAMES[reward.Ride] == nil then
		error("not an island ride: " .. tostring(reward.Type))
	end
	local p = islandPage(ctx.data)
	p.rides[reward.Ride] = true
	local player = ctx.player
	local name = NAMES[reward.Ride]
	ctx:after(function()
		Perks.tell(player, { op = "notice", title = "The " .. name .. " is yours", line = "Yours for good: ride it whenever you're on Luxury Island." })
	end)
end

function IslandRide.start()
	Grants.register("islandRide", grant)
end

return IslandRide

--!strict
-- Luxury Island's Robux (ProductConfig "jetAurora", "jetSovereign"): two jet liveries that are
-- only a look, kept for good in the guest's island page and worn from the Jet Gallery's desk.
-- Until each product exists in Creator Hub it isn't offered (the desk says so); every other
-- livery is had for Gilt or Gems.

local Profiles = require(script.Parent.Parent.Profiles)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local JetLivery = {}

local function islandPage(data: any): { [string]: any }
	data.attractions = if type(data.attractions) == "table" then data.attractions else {}
	local p = data.attractions.island
	if type(p) ~= "table" then
		p = {}
		data.attractions.island = p
	end
	if type(p.liveries) ~= "table" then
		p.liveries = {}
	end
	return p
end

function JetLivery.onSale(key: string): boolean
	return Store.sellable(key) ~= nil
end

-- Opens the purchase window (its price is in the window), or says it isn't on sale.
function JetLivery.offer(player: Player, key: string): (boolean, string?)
	local sell = Store.sellable(key)
	if not sell then
		return false, "That livery isn't on sale yet."
	end
	return Store.prompt(player, sell, "island")
end

local function grant(ctx: Grants.Context)
	local reward = ctx.product.Reward :: any
	if reward.Type ~= "JetLivery" or type(reward.Livery) ~= "string" then
		error("not a jet livery: " .. tostring(reward.Type))
	end
	local p = islandPage(ctx.data)
	p.liveries[reward.Livery] = true
	p.livery = reward.Livery
	local player = ctx.player
	ctx:after(function()
		player:SetAttribute("JetLivery", reward.Livery)
		Perks.tell(player, { op = "notice", title = "Your new livery", line = "Your jet wears it now: change it any time at the Jet Gallery's desk." })
	end)
end

function JetLivery.start()
	Grants.register("jetLivery", grant)
end

local _ = Profiles
return JetLivery

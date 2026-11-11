--!strict
-- The Maison Basement's Robux (ProductConfig "basementSkip"): Skip a Stage. Each purchase is one
-- skip. A stage takes more skips the deeper it is (one in the first part, then two, three, four:
-- shared/Basement.skipsNeeded), so the hard stages are never a cheap way down. With enough held,
-- a guest in the Basement moves one checkpoint on straight away; otherwise (outside it, too few
-- for this stage, the last stage, the Treasury reached) they're kept. A skipped run is never
-- timed for the boards, and a skipped stage pays nothing: it's a way past a stage someone is stuck
-- on, never a way up the boards. Until the product exists in Creator Hub it isn't offered at all
-- (Gems can always skip instead: the Basement's own price, in its HUD).

local Profiles = require(script.Parent.Parent.Profiles)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local BasementSkip = {}

BasementSkip.KEY = "basementSkip"
local CREDIT = "basement_skip"

-- Set by Main: use the skips held at once for a guest in the Basement (false: they're not there,
-- or can't; with a line when they hold too few for the stage they're on).
BasementSkip.useNow = function(_player: Player): (boolean, string?)
	return false, nil
end

function BasementSkip.held(player: Player): number
	local data = Profiles.get(player)
	return if data then Perks.credits(data, CREDIT) else 0
end

function BasementSkip.use(player: Player): boolean
	local data = Profiles.get(player)
	if not data or Perks.credits(data, CREDIT) <= 0 then
		return false
	end
	local ok = Perks.use(player, data, CREDIT, BasementSkip.KEY)
	Perks.push(player)
	return ok
end

function BasementSkip.onSale(): boolean
	return Store.sellable(BasementSkip.KEY) ~= nil
end

-- Opens the purchase window (its price is in the window), or says it isn't on sale.
function BasementSkip.offer(player: Player): (boolean, string?)
	local sell = Store.sellable(BasementSkip.KEY)
	if not sell then
		return false, "That isn't on sale yet."
	end
	return Store.prompt(player, sell, "basement")
end

local function grant(ctx: Grants.Context)
	if ctx.product.Reward.Type ~= "BasementSkip" then
		error("not a Basement product: " .. tostring(ctx.product.Reward.Type))
	end
	Perks.add(ctx.data, CREDIT, 1)
	local player = ctx.player
	ctx:after(function()
		local used, line = BasementSkip.useNow(player)
		if not used then
			Perks.tell(player, { op = "notice", title = "Skip a Stage", line = line or "Kept for your next run in the Maison Basement." })
		end
		Perks.push(player)
	end)
end

function BasementSkip.start()
	Grants.register("basementSkip", grant)
end

return BasementSkip

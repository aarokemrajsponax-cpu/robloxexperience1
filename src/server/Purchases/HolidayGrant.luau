--!strict
-- What the holiday games' products give (ProductConfig.Holiday): catches or sleigh rides held, or
-- a pass for this year's holiday, written into the buyer's saved holiday page (the same fields
-- server/Holidays reads). The game itself is told after the receipt is acknowledged (`after`, set
-- by server/Holidays), so the guest's screen moves at once.

local Grants = require(script.Parent.Grants)

local HolidayGrant = {}

-- Set by server/Holidays: the game hears a product was bought (the field's count, the sleigh).
HolidayGrant.after = function(_player: Player, _key: string) end

local function count(v: any): number
	return if type(v) == "number" and v == v then math.max(0, math.floor(v)) else 0
end

local function grant(ctx: Grants.Context)
	local d = ctx.data :: any
	if type(d.holiday) ~= "table" then
		d.holiday = {}
	end
	local h = d.holiday
	local reward = ctx.product.Reward
	local year = tonumber(os.date("!%Y")) or 0
	if reward.Type == "HolidayCatches" then
		h.catches = count(h.catches) + math.max(1, math.floor(tonumber(reward.Amount) or 1))
	elseif reward.Type == "HolidayRide" then
		h.rides = count(h.rides) + math.max(1, math.floor(tonumber(reward.Amount) or 1))
	elseif reward.Type == "HolidayPass" then
		if reward.Game == "thanksgiving" then
			h.hunterYear = year
		elseif reward.Game == "christmas" then
			h.seasonYear = year
		else
			error("a holiday pass for no holiday")
		end
	else
		error("not a holiday product: " .. tostring(reward.Type))
	end
	local player, key = ctx.player, ctx.key
	ctx:after(function()
		HolidayGrant.after(player, key)
	end)
end

function HolidayGrant.start()
	Grants.register("holiday", grant)
end

return HolidayGrant

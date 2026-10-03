--!strict
-- The purchase risk check: Normal, Review or Restricted, from signals the server can see for
-- itself. It never reads a country or a price from a guest's screen, and it never refuses or
-- swallows a receipt Roblox has already charged for: once Robux are spent, the only safe outcomes
-- are "granted" or "try again later" (Receipts). What it can do is stop *new* purchase prompts for
-- a guest in Restricted, for a while, and tell the owner about Review and Restricted.
--
-- Signals (points, ProductConfig.Risk):
--   region_hop    a different country from the last session, within a couple of hours   +1
--   many_regions  three or more countries within a day                                  +2
--   velocity      a dozen receipts within ten minutes                                   +2
--   daily_volume  sixty receipts within a day                                           +2
--   failures      repeated failed or deferred grants within the hour                    +1
--   price         a receipt far from both Roblox's live price and the catalog's         +1
-- Country comes from LocalizationService (Roblox's IP geolocation): travel and VPNs make it
-- noisy, so it's weighted low and can't reach Restricted alone.

local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Ledger = require(script.Parent.Ledger)
local Telemetry = require(script.Parent.Telemetry)

local Risk = {}

export type State = "Normal" | "Review" | "Restricted"

-- Told when a guest moves to Review or Restricted (set by Main: the owner's screen).
Risk.onChanged = function(_player: Player, _state: State, _reasons: { string }) end

local function cfg()
	return ProductConfig.Risk
end

local function keepLast(list: { any }, n: number)
	while #list > n do
		table.remove(list, 1)
	end
end

local function since(list: { number }, seconds: number, now: number): number
	local n = 0
	for _, at in list do
		if now - at <= seconds then
			n += 1
		end
	end
	return n
end

-- The points and reasons for a guest now. `price`: the receipt being granted was off-price.
function Risk.score(data: Profiles.Data, now: number, price: boolean?): (number, { string })
	local c = cfg()
	local risk = data.risk
	local points, reasons = 0, {}
	local regions = risk.regions
	if #regions >= 2 then
		local last, before = regions[#regions], regions[#regions - 1]
		if last.code ~= before.code and last.at - before.at <= c.RegionHopHours * 3600 then
			points += 1
			table.insert(reasons, "region_hop")
		end
	end
	local distinct: { [string]: boolean } = {}
	local count = 0
	for _, r in regions do
		if now - r.at <= c.RegionWindowHours * 3600 and not distinct[r.code] then
			distinct[r.code] = true
			count += 1
		end
	end
	if count >= c.ManyRegions then
		points += 2
		table.insert(reasons, "many_regions")
	end
	if since(risk.purchases, c.VelocityWindowMinutes * 60, now) >= c.VelocityCount then
		points += 2
		table.insert(reasons, "velocity")
	end
	if since(risk.purchases, 86400, now) >= c.DailyCount then
		points += 2
		table.insert(reasons, "daily_volume")
	end
	if since(risk.failures, c.FailureWindowMinutes * 60, now) >= c.FailureCount then
		points += 1
		table.insert(reasons, "failures")
	end
	if price then
		points += 1
		table.insert(reasons, "price")
	end
	return points, reasons
end

-- Works out the state now (a restriction lasts its hours once set) and reports any change.
function Risk.evaluate(player: Player, data: Profiles.Data, price: boolean?): State
	local c = cfg()
	local now = os.time()
	local points, reasons = Risk.score(data, now, price)
	local state: State = if points >= c.RestrictAt then "Restricted" elseif points >= c.ReviewAt then "Review" else "Normal"
	if state == "Restricted" then
		data.risk.restrictedUntil = math.max(data.risk.restrictedUntil, now + c.RestrictHours * 3600)
	elseif data.risk.restrictedUntil > now then
		state = "Restricted"
	end
	if state ~= data.risk.state then
		data.risk.state = state
		if state ~= "Normal" then
			Telemetry.log(player, Telemetry.Events.Risk, "account", state .. ":" .. table.concat(reasons, "+"), points)
			pcall(Risk.onChanged, player, state, reasons)
		end
	end
	return state
end

-- A guest arrived: the country Roblox sees for them (never one their screen claims).
function Risk.onJoin(player: Player, data: Profiles.Data)
	local ok, code = pcall(function()
		return LocalizationService:GetCountryRegionForPlayerAsync(player)
	end)
	if ok and type(code) == "string" and #code >= 2 and #code <= 3 then
		table.insert(data.risk.regions, { code = string.upper(code), at = os.time() })
		keepLast(data.risk.regions, cfg().RegionsKept)
	end
	Risk.evaluate(player, data, nil)
end

local function near(amount: number, price: number?): boolean
	return price ~= nil and price > 0 and math.abs(amount - price) <= price * cfg().PriceTolerance
end

-- A receipt is being granted: count it, compare what was paid, and re-evaluate. The receipt is
-- granted whatever this returns.
function Risk.onReceipt(player: Player, data: Profiles.Data, r: Ledger.Receipt, key: string): State
	local now = os.time()
	table.insert(data.risk.purchases, now)
	keepLast(data.risk.purchases, cfg().PurchasesKept)
	local entry = ProductConfig.byKey[key]
	-- Roblox's price tests can charge other amounts legitimately: only an amount far from both
	-- the live price and the catalog's counts, and only as one weak signal. (Studio's test
	-- purchases spend nothing.)
	local off = false
	if entry and r.spent > 0 then
		off = not near(r.spent, Catalog.price(key)) and not near(r.spent, entry.Pricing.ReferencePrice)
	end
	return Risk.evaluate(player, data, off)
end

-- A grant that failed or had to wait.
function Risk.noteFailure(player: Player, data: Profiles.Data)
	table.insert(data.risk.failures, os.time())
	keepLast(data.risk.failures, cfg().FailuresKept)
	Risk.evaluate(player, data, nil)
end

-- May this guest be shown a new purchase prompt? (Receipts are never affected.)
function Risk.canPrompt(player: Player, data: Profiles.Data): (boolean, string?)
	if Risk.evaluate(player, data, nil) == "Restricted" then
		return false, "Purchases are paused on this account for a little while. Anything you've bought is safe and yours."
	end
	return true, nil
end

return Risk

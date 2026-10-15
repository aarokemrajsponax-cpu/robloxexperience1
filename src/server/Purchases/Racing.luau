--!strict
-- The Grand Prix's Robux (ProductConfig.GrandPrix): "Open the Grand Prix Now" between its hours,
-- for everyone in the house, and "The Private Garage", two more cars kept for its holders.
--
-- Open Now works like the Ballroom's: a credit held opens it at once; otherwise the purchase
-- window opens, and the receipt's credit is spent straight after. If it opened by itself in the
-- meantime, the credit is kept for the next time it's closed, and the guest is told so.
--
-- The Private Garage is bought once and kept for good (a flag in the profile). Its cars drive
-- exactly like every other car: it's how you arrive, never an edge in a race. A second purchase
-- becomes Boutique credit, never lost.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local Racing = {}

Racing.KEYS = {
	open = "grandPrixOpen",
	garage = "grandPrixGarage",
} :: { [string]: string }

local OPEN_CREDIT = "grandPrix_open"

-- Set by Main (GrandPrixService): the hours, and opening it.
Racing.isClosed = function(): boolean
	return false
end
Racing.open = function(_by: string?): (boolean, string?)
	return false, "Not just now."
end
-- A line to the guest (a notice on their screen).
Racing.say = function(_player: Player, _title: string, _line: string) end

function Racing.owns(data: Profiles.Data): boolean
	return data.perks.garage == true
end

-- Whether a guest (in the house now) holds the Private Garage.
function Racing.hasGarage(player: Player): boolean
	local data = Profiles.get(player)
	return data ~= nil and Racing.owns(data)
end

-- What opening it now costs (Roblox's price, or the catalog's until Roblox says), and how many
-- the guest already holds.
function Racing.info(player: Player): { price: number, held: number }
	local key = Racing.KEYS.open
	local e = ProductConfig.byKey[key]
	local data = Profiles.get(player)
	return {
		price = Catalog.price(key) or (if e then e.Pricing.ReferencePrice else 0),
		held = if data then Perks.credits(data, OPEN_CREDIT) else 0,
	}
end

-- Opens the purchase window for the Private Garage (its price is in the window).
function Racing.offerGarage(player: Player): (boolean, string?)
	local data = Profiles.get(player)
	if data and Racing.owns(data) then
		return false, "The Private Garage is already yours."
	end
	local sell = Store.sellable(Racing.KEYS.garage)
	if not sell then
		return false, "That isn't on sale yet."
	end
	return Store.prompt(player, sell, "grandPrix")
end

-- A guest asked to open the Grand Prix now: a credit held opens it; otherwise the purchase window.
function Racing.openNow(player: Player): (boolean, string?)
	if not Racing.isClosed() then
		return false, "The Grand Prix is already open."
	end
	local data = Profiles.get(player)
	if data and Perks.credits(data, OPEN_CREDIT) > 0 then
		if Perks.use(player, data, OPEN_CREDIT, Racing.KEYS.open) then
			local ok, why = Racing.open(Names.of(player))
			if not ok then
				Perks.add(data, OPEN_CREDIT, 1)
			end
			Perks.push(player)
			return ok, why
		end
	end
	local sell = Store.sellable(Racing.KEYS.open)
	if not sell then
		return false, "That isn't on sale yet."
	end
	return Store.prompt(player, sell, "grandPrix")
end

local function grant(ctx: Grants.Context)
	local reward = ctx.product.Reward
	local player = ctx.player
	local data = ctx.data
	if reward.Type == "PrivateGarage" then
		if Racing.owns(data) then
			local creditKey = ctx.product.Rules.DuplicateCredit or "tier199"
			data.credits[creditKey] = (data.credits[creditKey] or 0) + 1
			ctx:after(function()
				Perks.tell(player, { op = "notice", title = "The Private Garage", line = "It was already yours, so this one is kept as Boutique credit." })
			end)
			return
		end
		data.perks.garage = true
		ctx:after(function()
			Perks.push(player)
			Racing.say(player, "The Private Garage", "Yours for good: the Gilded Phantom and the Imperial Violet, in their bays west of the others.")
		end)
		return
	end
	if reward.Type ~= "GrandPrixOpen" then
		error("not a Grand Prix product: " .. tostring(reward.Type))
	end
	Perks.add(data, OPEN_CREDIT, 1)
	ctx:after(function()
		if Racing.isClosed() and Perks.use(player, data, OPEN_CREDIT, Racing.KEYS.open) then
			local ok = Racing.open(Names.of(player))
			if not ok then
				Perks.add(data, OPEN_CREDIT, 1)
			end
		else
			Racing.say(player, "The Grand Prix", "It's already open, so your Open the Grand Prix Now is kept for when it's closed.")
		end
		Perks.push(player)
	end)
end

function Racing.start()
	Grants.register("grandPrix", grant)
	Store.eligibility[Racing.KEYS.open] = function(_player: Player): (boolean, string?)
		if not Racing.isClosed() then
			return false, "The Grand Prix is already open."
		end
		return true, nil
	end
	Store.eligibility[Racing.KEYS.garage] = function(_player: Player, data: Profiles.Data): (boolean, string?)
		if Racing.owns(data) then
			return false, "The Private Garage is already yours."
		end
		return true, nil
	end
	Perks.contributors.grandPrix = function(_player: Player, data: Profiles.Data): any
		return { garage = Racing.owns(data), openHeld = Perks.credits(data, OPEN_CREDIT) }
	end
end

return Racing

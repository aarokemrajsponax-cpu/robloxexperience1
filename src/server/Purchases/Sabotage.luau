--!strict
-- The Ballroom's Robux: sabotage during an evening (a Parcel Bomb, a Blackout, Butterfingers, a
-- Shield against them) and "Open the Ballroom Now" between its hours (ProductConfig.Ballroom).
--
-- A guest's screen asks for one by name and target; the Ballroom checks it can happen (an evening
-- in play, the table lit, not just hit, the guest's count for the evening) before any purchase
-- window opens. A held credit is spent at once; otherwise the purchase window opens, and the
-- receipt grants a credit that's spent on what was aimed at, straight after. If the moment has
-- passed (the lamp went out, the evening ended), the credit is kept for next time, and the guest
-- is told so: nothing paid for is lost. Every sabotage is announced to the room with its sender.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local Sabotage = {}

-- The products, by what they do.
Sabotage.KEYS = {
	bomb = "ballroomBomb",
	blackout = "ballroomBlackout",
	freeze = "ballroomFreeze",
	shield = "ballroomShield",
	open = "ballroomOpen",
} :: { [string]: string }

local function credit(kind: string): string
	return "ballroom_" .. kind
end

-- Set by Main (BallroomService): whether it can happen now, doing it, and the Ballroom's hours.
Sabotage.can = function(_player: Player, _kind: string, _seat: number): (boolean, string?)
	return false, "Not just now."
end
Sabotage.apply = function(_player: Player, _kind: string, _seat: number): (boolean, string?)
	return false, "Not just now."
end
Sabotage.isClosed = function(): boolean
	return false
end
Sabotage.open = function(_by: string?): (boolean, string?)
	return false, "Not just now."
end
-- A line to the guest (a notice on their screen).
Sabotage.say = function(_player: Player, _title: string, _line: string) end

-- What each guest last aimed at (kind, table, when): the receipt spends its credit on it.
local aims: { [Player]: { kind: string, seat: number, at: number } } = {}
local AIM_SECONDS = 90

local function spendAndApply(player: Player, kind: string, seat: number): (boolean, string?)
	local data = Profiles.get(player)
	if not data then
		return false, "Your ledger is still being opened."
	end
	local ok, why = Sabotage.can(player, kind, seat)
	if not ok then
		return false, why
	end
	if not Perks.use(player, data, credit(kind), Sabotage.KEYS[kind]) then
		return false, "Not just now."
	end
	local done, reason = Sabotage.apply(player, kind, seat)
	if not done then
		-- (It couldn't happen after all: the credit goes back.)
		Perks.add(data, credit(kind), 1)
		return false, reason
	end
	Perks.push(player)
	return true, nil
end

-- A guest asked to send `kind` at table `seat` (or a Shield): a credit held is spent now;
-- otherwise the purchase window opens.
function Sabotage.request(player: Player, kind: string, seat: number): (boolean, string?)
	local key = Sabotage.KEYS[kind]
	if not key or kind == "open" then
		return false, "That isn't something the Ballroom does."
	end
	local ok, why = Sabotage.can(player, kind, seat)
	if not ok then
		return false, why
	end
	local data = Profiles.get(player)
	if data and Perks.credits(data, credit(kind)) > 0 then
		return spendAndApply(player, kind, seat)
	end
	local sell = Store.sellable(key)
	if not sell then
		return false, "That isn't on sale yet."
	end
	aims[player] = { kind = kind, seat = seat, at = os.clock() }
	return Store.prompt(player, sell, "ballroom")
end

-- A guest asked to open the Ballroom now: a credit held opens it; otherwise the purchase window.
function Sabotage.openNow(player: Player): (boolean, string?)
	if not Sabotage.isClosed() then
		return false, "The Ballroom is already open."
	end
	local data = Profiles.get(player)
	if data and Perks.credits(data, credit("open")) > 0 then
		if Perks.use(player, data, credit("open"), Sabotage.KEYS.open) then
			local ok, why = Sabotage.open(Names.of(player))
			if not ok then
				Perks.add(data, credit("open"), 1)
			end
			Perks.push(player)
			return ok, why
		end
	end
	local sell = Store.sellable(Sabotage.KEYS.open)
	if not sell then
		return false, "That isn't on sale yet."
	end
	return Store.prompt(player, sell, "ballroom")
end

-- The prices (Roblox's own, or the catalog's until Roblox says) and the credits held.
function Sabotage.info(player: Player): { [string]: any }
	local prices, credits = {}, {}
	local data = Profiles.get(player)
	for kind, key in Sabotage.KEYS do
		local e = ProductConfig.byKey[key]
		local live = Catalog.price(key)
		prices[kind] = live or (if e then e.Pricing.ReferencePrice else 0)
		credits[kind] = if data then Perks.credits(data, credit(kind)) else 0
	end
	return { prices = prices, credits = credits }
end

local function grant(ctx: Grants.Context)
	local reward = ctx.product.Reward
	local kind = if reward.Type == "BallroomOpen" then "open" else tostring(reward.Kind)
	if not Sabotage.KEYS[kind] then
		error("not a Ballroom product: " .. tostring(reward.Kind))
	end
	Perks.add(ctx.data, credit(kind), 1)
	local player = ctx.player
	ctx:after(function()
		if kind == "open" then
			if Sabotage.isClosed() and Perks.use(player, ctx.data, credit("open"), Sabotage.KEYS.open) then
				local ok = Sabotage.open(Names.of(player))
				if not ok then
					Perks.add(ctx.data, credit("open"), 1)
				end
			else
				Sabotage.say(player, "The Ballroom", "It's already open, so your Open the Ballroom Now is kept for when it's closed.")
			end
			Perks.push(player)
			return
		end
		local aim = aims[player]
		aims[player] = nil
		if aim and aim.kind == kind and os.clock() - aim.at < AIM_SECONDS then
			local ok = spendAndApply(player, kind, aim.seat)
			if ok then
				return
			end
		end
		Perks.push(player)
		Sabotage.say(player, "The Ballroom", "The moment had passed, so it's kept: the next time you send one, it's already paid for.")
	end)
end

function Sabotage.start()
	Grants.register("ballroom", grant)
	for kind, key in Sabotage.KEYS do
		Store.eligibility[key] = function(player: Player): (boolean, string?)
			if kind == "open" then
				if not Sabotage.isClosed() then
					return false, "The Ballroom is already open."
				end
				return true, nil
			end
			local aim = aims[player]
			if not aim or aim.kind ~= kind then
				return false, "Choose a table first."
			end
			return Sabotage.can(player, kind, aim.seat)
		end
	end
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		aims[player] = nil
	end)
end

return Sabotage

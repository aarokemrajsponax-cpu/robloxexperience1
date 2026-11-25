--!strict
-- (Build 105) Mischief: two plays bought with Robux, one press each, kept until used (prepaid).
--   Midway Steal   (Steal a Luxe) snatch the finest piece out of a nearby guest's bag while
--                  they're carrying it, into yours, to bank for its Gilt yourself.
--   Basement Push  (the Maison Basement) a shove that sends a nearby guest stumbling.
-- The receipt grants one credit (durable, like every credit). The attraction spends it on the
-- server, and only when the play lands: a press that can't land (nobody near, a guest just hit,
-- no room in your bag) takes nothing. Each has its cooldown, and a guest just hit is safe from
-- another for a while, so nobody is picked on over and over. Never random, never a score.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local Mischief = {}

-- The product of each play.
Mischief.KEYS = { midway = "luxeMidwaySteal", push = "basementPush" } :: { [string]: string }
Mischief.NAMES = { midway = "Midway Steal", push = "Basement Push" } :: { [string]: string }

function Mischief.credit(kind: string): string
	return "mischief_" .. kind
end

-- How many of a play a guest holds.
function Mischief.held(player: Player, kind: string): number
	local data = Profiles.get(player)
	return if data then Perks.credits(data, Mischief.credit(kind)) else 0
end

-- Spends one (true), or false if none is held.
function Mischief.spend(player: Player, kind: string): boolean
	local data = Profiles.get(player)
	local key = Mischief.KEYS[kind]
	if not data or not key then
		return false
	end
	local ok = Perks.use(player, data, Mischief.credit(kind), key)
	if ok then
		Perks.push(player)
	end
	return ok
end

function Mischief.onSale(kind: string): boolean
	local key = Mischief.KEYS[kind]
	return key ~= nil and Catalog.enabled(key)
end

function Mischief.price(kind: string): number?
	local key = Mischief.KEYS[kind]
	return if key then Catalog.price(key) else nil
end

-- Roblox's purchase window for one more.
function Mischief.offer(player: Player, kind: string): (boolean, string?)
	local key = Mischief.KEYS[kind]
	if not key then
		return false, "There's no such thing."
	end
	return Store.prompt(player, key, "mischief")
end

local function grant(ctx: Grants.Context)
	local kind = ctx.product.Reward.Kind
	if type(kind) ~= "string" or not Mischief.KEYS[kind :: string] then
		return
	end
	Perks.add(ctx.data, Mischief.credit(kind :: string), 1)
	local player = ctx.player
	ctx:after(function()
		Perks.push(player)
		Perks.tell(player, { op = "notice", title = Mischief.NAMES[kind :: string], line = "Ready: press it when someone's in reach." })
	end)
end

function Mischief.start()
	Grants.register("mischief", grant)
	for kind, key in Mischief.KEYS do
		Store.eligibility[key] = function(_player: Player, data: Profiles.Data): (boolean, string?)
			local most = (ProductConfig.byKey[key] and ProductConfig.byKey[key].Rules.MaxHeld) or 10
			if Perks.credits(data, Mischief.credit(kind)) >= most then
				return false, string.format("You hold %d already: the most the house keeps.", most)
			end
			return true, nil
		end
	end
	Perks.contributors.mischief = function(_player: Player, data: Profiles.Data): any
		return { midway = Perks.credits(data, Mischief.credit("midway")), push = Perks.credits(data, Mischief.credit("push")) }
	end
end

return Mischief

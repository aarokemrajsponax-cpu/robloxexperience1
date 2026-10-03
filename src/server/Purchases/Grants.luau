--!strict
-- What each product gives. A handler is called once per new receipt with a context: the buyer,
-- their profile data, the product and the receipt. It may only change saved data (the buyer's,
-- or another guest's through ctx:touch, which includes theirs in the same commit) and queue work
-- for after the receipt is acknowledged (ctx:after): effects in the world, messages to screens.
--
-- Handlers run as one transaction: every profile they touch is snapshotted first, and if the
-- handler errors, all of them are put back exactly as they were, so a half-applied reward can't be
-- saved. The receipt then stays unresolved and Roblox delivers it again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)

local Grants = {}

export type Context = {
	player: Player,
	data: Profiles.Data,
	key: string,
	product: ProductConfig.Entry,
	purchaseId: string,
	spent: number,
	risk: string,
	touched: { Player },
	afters: { () -> () },
	snapshots: { [any]: any },
	touch: (self: Context, other: Player) -> Profiles.Data?,
	after: (self: Context, fn: () -> ()) -> (),
}
export type Handler = (ctx: Context) -> ()

local handlers: { [string]: Handler } = {}

function Grants.register(name: string, fn: Handler)
	handlers[name] = fn
end

-- The names of every registered handler (for validating the catalog).
function Grants.names(): { [string]: boolean }
	local out = {}
	for name in handlers do
		out[name] = true
	end
	return out
end

local function deepCopy(v: any): any
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[deepCopy(k)] = deepCopy(x)
	end
	return out
end

-- Puts a table back to a snapshot, in place (the profile object keeps its Data table).
local function restore(target: any, snapshot: any)
	for k in target do
		if snapshot[k] == nil then
			target[k] = nil
		end
	end
	for k, v in snapshot do
		target[k] = v
	end
end

function Grants.newContext(player: Player, data: Profiles.Data, key: string, purchaseId: string, spent: number, risk: string): Context
	local ctx: Context = {
		player = player,
		data = data,
		key = key,
		product = ProductConfig.byKey[key],
		purchaseId = purchaseId,
		spent = spent,
		risk = risk,
		touched = {},
		afters = {},
		snapshots = { [data] = deepCopy(data) },
		touch = function(self: Context, other: Player): Profiles.Data?
			if other == self.player then
				return self.data
			end
			local otherData = Profiles.get(other)
			if not otherData or other.Parent ~= Players then
				return nil
			end
			if self.snapshots[otherData] == nil then
				self.snapshots[otherData] = deepCopy(otherData)
				table.insert(self.touched, other)
			end
			return otherData
		end,
		after = function(self: Context, fn: () -> ())
			table.insert(self.afters, fn)
		end,
	}
	return ctx
end

-- Runs the product's handler as a transaction. Returns false and the error if it failed (and
-- everything it touched has been rolled back).
function Grants.run(ctx: Context): (boolean, string?)
	local handler = handlers[ctx.product.Handler]
	if not handler then
		return false, "no handler '" .. tostring(ctx.product.Handler) .. "'"
	end
	local ok, err = pcall(handler :: any, ctx)
	if not ok then
		for data, snapshot in ctx.snapshots do
			restore(data, snapshot)
		end
		ctx.afters = {}
		ctx.touched = {}
		return false, tostring(err)
	end
	return true, nil
end

-- The queued work, once the receipt is acknowledged. Each step is guarded on its own.
function Grants.runAfter(ctx: Context)
	for _, fn in ctx.afters do
		local ok, err = pcall(fn :: any)
		if not ok then
			warn(string.format("[Maison] After granting %s: %s", ctx.key, tostring(err)))
		end
	end
end

return Grants

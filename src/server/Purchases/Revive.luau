--!strict
-- Chronos Defiance: when the clock runs out in a timed room, +15 seconds and the run goes on; and
-- in the Executive Suite, when security catches a guest, back in the run where it stood.
-- Priced by the room (ProductConfig.RoomRevives: the Velvet Room's the cheapest, the Midnight
-- Room's the dearest), each spent only in its own room; the original Chronos Defiance stands in
-- for a room whose product isn't in Creator Hub yet, and its revives work in any room. The table (TableService) owns the moment: only the server
-- decides a run has failed and opens the offer window; a guest's screen can only ask to revive,
-- never say it's eligible.
--
-- The receipt grants a revive credit (durable, like every credit). Spending it is the table's
-- job: if the offer window is still open when the receipt arrives, the run is revived at once;
-- if the moment has passed (the receipt was slow, the guest stood up), the revive is kept for
-- their next run, and their screen says so. Nothing paid for is lost, and one credit can't revive
-- twice (spending it and reviving happen together, on the server, once).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local Revive = {}

Revive.KEY = "chronosDefiance"
Revive.CREDIT = "revive"

-- Set by the table: is this guest's run in its revive window right now?
Revive.offerOpen = function(_player: Player): boolean
	return false
end
-- Set by the table: spend a revive on the open window now, if there is one. True if revived.
Revive.applyNow = function(_player: Player): boolean
	return false
end
-- Set by the table: the purchase window for a revive closed (bought or not).
Revive.promptClosed = function(_player: Player, _purchased: boolean) end

-- Other places with a revive moment of their own, beside the table's (the Executive Suite, when
-- security catches a guest): each says whether its window is open for a guest, spends a revive on
-- it, and hears when the purchase window closed. A revive works in whichever is open.
export type Window = { open: (Player) -> boolean, apply: (Player) -> boolean, closed: (Player, boolean) -> () }
Revive.windows = {} :: { Window }

-- Whether any revive moment is open for this guest just now.
function Revive.isOpen(player: Player): boolean
	if Revive.offerOpen(player) then
		return true
	end
	for _, w in Revive.windows do
		if w.open(player) then
			return true
		end
	end
	return false
end

-- Spends a revive on whichever moment is open. True if a run was revived.
function Revive.applyAny(player: Player): boolean
	if Revive.offerOpen(player) then
		return Revive.applyNow(player)
	end
	for _, w in Revive.windows do
		if w.open(player) then
			return w.apply(player)
		end
	end
	return false
end

function Revive.entry(): ProductConfig.Entry
	return ProductConfig.byKey[Revive.KEY]
end

function Revive.credits(data: Profiles.Data): number
	return Perks.credits(data, Revive.CREDIT)
end

-- The credit a room's own revive grants.
function Revive.creditOf(room: string): string
	return Revive.CREDIT .. "_" .. room
end

-- The product sold for a revive in `room`: its own, or Chronos Defiance until that's on sale.
function Revive.keyFor(room: string?): string
	local key = if room then ProductConfig.RoomRevives[room] else nil
	if key and Catalog.enabled(key) then
		return key
	end
	return Revive.KEY
end

-- Revives a guest holds that work in `room`: that room's own, and any Chronos Defiance.
function Revive.creditsFor(data: Profiles.Data, room: string?): number
	local own = if room and ProductConfig.RoomRevives[room] then Perks.credits(data, Revive.creditOf(room)) else 0
	return own + Revive.credits(data)
end

-- Spends one revive for `room` (its own first, then a Chronos Defiance). False if there's none.
function Revive.spend(player: Player, data: Profiles.Data, room: string?): boolean
	if room and ProductConfig.RoomRevives[room] and Perks.use(player, data, Revive.creditOf(room), ProductConfig.RoomRevives[room]) then
		return true
	end
	return Perks.use(player, data, Revive.CREDIT, Revive.KEY)
end

-- A revive moment away from the tables (the Executive Suite) takes Chronos Defiance itself: the
-- revives held that work anywhere, whether it's on sale and at what price (shown on the key, never
-- hidden), spending one held, and Roblox's purchase window.
function Revive.heldAnywhere(player: Player): number
	local data = Profiles.get(player)
	return if data then Revive.credits(data) else 0
end

function Revive.onSale(): boolean
	return Catalog.enabled(Revive.KEY)
end

function Revive.price(): number?
	return Catalog.price(Revive.KEY)
end

function Revive.spendAnywhere(player: Player): boolean
	local data = Profiles.get(player)
	if not data or Revive.credits(data) <= 0 then
		return false
	end
	local ok = Perks.use(player, data, Revive.CREDIT, Revive.KEY)
	Perks.push(player)
	return ok
end

function Revive.offer(player: Player, context: string): (boolean, string?)
	return Store.prompt(player, Revive.KEY, context)
end

-- Whether `key` is one of the revives.
function Revive.isRevive(key: string): boolean
	if key == Revive.KEY then
		return true
	end
	for _, k in ProductConfig.RoomRevives do
		if k == key then
			return true
		end
	end
	return false
end

local function grant(ctx: Grants.Context)
	local room = ctx.product.Reward.Room
	Perks.add(ctx.data, if type(room) == "string" then Revive.creditOf(room :: string) else Revive.CREDIT, 1)
	local player = ctx.player
	ctx:after(function()
		if not Revive.applyAny(player) then
			Perks.push(player)
			Perks.tell(player, { op = "notice", title = "Chronos Defiance", line = "The moment had passed, so your revive is kept for your next run." })
		end
	end)
end

function Revive.start()
	Grants.register("revive", grant)
	-- A revive is only ever offered (and so only ever bought) in its window.
	local function eligible(player: Player, data: Profiles.Data): (boolean, string?)
		if not Revive.isOpen(player) then
			return false, "A revive is offered when the clock runs out at a table, or when security catches you in the Executive Suite."
		end
		if Revive.credits(data) >= (Revive.entry().Rules.MaxHeld or 5) then
			return false, "You already hold as many revives as the house keeps."
		end
		return true, nil
	end
	Store.eligibility[Revive.KEY] = eligible
	for _, key in ProductConfig.RoomRevives do
		Store.eligibility[key] = eligible
	end
	Store.whenClosed(function(player: Player, key: string, purchased: boolean)
		if Revive.isRevive(key) then
			Revive.promptClosed(player, purchased)
			for _, w in Revive.windows do
				w.closed(player, purchased)
			end
		end
	end)
	Perks.contributors.revive = function(_player: Player, data: Profiles.Data): any
		local e = Revive.entry()
		return { held = Revive.credits(data), seconds = e.Reward.Seconds, window = e.Rules.WindowSeconds, boardsCountRevived = e.Rules.BoardsCountRevivedPoints == true }
	end
end

return Revive

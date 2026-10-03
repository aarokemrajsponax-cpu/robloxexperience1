--!strict
-- What the purchase system records. One schema for every event: Roblox analytics gets the event
-- name, a value (Robux, seconds, Gilt...) and three breakdowns (CustomField01..03: the product
-- key, the outcome or reason, and the buyer's segment); the server log gets the problems; a short
-- in-memory history is kept for tests and the owner's tools. Analytics can never break a
-- purchase: every call is guarded.
--
-- Cardinality: product keys (~35), reasons (a fixed vocabulary below) and segments (3) keep well
-- inside Roblox's limit of 8,000 combinations per experience.

local Analytics = require(script.Parent.Parent.Analytics)

local Telemetry = {}

Telemetry.Events = {
	Impression = "Shop: Impression", -- an offer was shown (the server built the list)
	Prompt = "Shop: Prompt opened", -- the server asked Roblox to show a purchase prompt
	PromptClosed = "Shop: Prompt closed", -- Roblox's prompt closed (bought or not: informational only)
	PromptRefused = "Shop: Prompt refused", -- the server didn't prompt (ineligible, restricted, not set up)
	Granted = "Shop: Receipt granted", -- a receipt's reward is saved and Roblox was told
	Deferred = "Shop: Receipt deferred", -- left unresolved on purpose; Roblox will retry
	GrantFailed = "Shop: Grant failed", -- a handler error, rolled back; Roblox will retry
	Duplicate = "Shop: Duplicate prevented", -- a replayed receipt was recognised and not granted again
	Repeat = "Shop: Repeat purchase", -- the buyer had bought this product before
	Used = "Shop: Product used", -- a credit spent (a revive, a decree, a rain)
	Expired = "Shop: Product expired", -- a timed effect ran out (Luck)
	Revoked = "Shop: Entitlement revoked", -- a pass Roblox no longer reports as owned (a refund)
	Risk = "Shop: Risk signal", -- the risk check moved a guest out of Normal
	Invalid = "Shop: Validation failed", -- a malformed receipt or request
	RemoteRejected = "Shop: Remote rejected", -- rate-limited or malformed client traffic
	LedgerFailed = "Shop: Ledger write failed", -- a ledger write that will be retried
}

-- Problems that also go to the server log (and, through LogService, the owner's red panel).
local LOUD: { [string]: boolean } = {
	[Telemetry.Events.GrantFailed] = true,
	[Telemetry.Events.Invalid] = true,
}

export type Entry = { event: string, product: string, detail: string, segment: string, value: number?, userId: number, at: number }

local history: { Entry } = {}
local HISTORY_KEPT = 300

-- The buyer's segment: "new" (no purchase yet), "repeat", or "patron" (five or more).
function Telemetry.segment(purchases: { [string]: number }?): string
	local total = 0
	local counts: { [string]: number } = purchases or {}
	for _, n in counts do
		total += n
	end
	return if total == 0 then "new" elseif total < 5 then "repeat" else "patron"
end

-- Records one event. `player` may be nil for events with nobody to attribute them to.
function Telemetry.log(player: Player?, event: string, product: string, detail: string?, value: number?, segment: string?)
	local e: Entry = {
		event = event,
		product = product,
		detail = detail or "",
		segment = segment or "",
		value = value,
		userId = if player then player.UserId else 0,
		at = os.time(),
	}
	table.insert(history, e)
	if #history > HISTORY_KEPT then
		table.remove(history, 1)
	end
	if player then
		Analytics.custom(player, event, value, { product, e.detail, e.segment })
	end
	if LOUD[event] then
		warn(string.format("[Maison] %s · %s · %s (user %d)", event, product, e.detail, e.userId))
	end
end

-- The recent history (newest last), for tests and diagnostics.
function Telemetry.recent(): { Entry }
	return history
end

-- How many recent events match (tests and the risk check use this).
function Telemetry.count(event: string, product: string?, detail: string?): number
	local n = 0
	for _, e in history do
		if e.event == event and (product == nil or e.product == product) and (detail == nil or e.detail == detail) then
			n += 1
		end
	end
	return n
end

return Telemetry

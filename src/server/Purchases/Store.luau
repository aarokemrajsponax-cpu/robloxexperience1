--!strict
-- Purchase prompts. The only place the house asks Roblox to show a purchase window, always from
-- the server, always for a product the catalog knows: a guest's screen can ask for a product by
-- its key, never by an id or a price, and the server decides whether to prompt (on sale, not
-- restricted by the risk check, allowed by the product's own rules, not too soon after the last).
--
-- Roblox's "prompt closed" events are recorded and passed on (the revive window waits while a
-- prompt is open) but never grant anything: rewards come only from receipts (and, for game
-- passes, from Roblox's ownership check).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Risk = require(script.Parent.Risk)
local Telemetry = require(script.Parent.Telemetry)

local Store = {}

-- Per-product rules for prompting, by key: (player, data) -> (allowed, why).
Store.eligibility = {} :: { [string]: (player: Player, data: Profiles.Data) -> (boolean, string?) }

local closedHandlers: { (player: Player, key: string, purchased: boolean) -> () } = {}
local lastPrompt: { [Player]: { [string]: number } } = {}
local lastImpression: { [Player]: { [string]: number } } = {}
local open: { [Player]: { key: string, at: number } } = {}

local E = Telemetry.Events

-- Called with (player, key, purchased) when a prompt the house opened closes.
function Store.whenClosed(fn: (player: Player, key: string, purchased: boolean) -> ())
	table.insert(closedHandlers, fn)
end

-- The key of the prompt a guest has open, if any.
function Store.openPrompt(player: Player): string?
	local o = open[player]
	return if o then o.key else nil
end

local function refuse(player: Player, key: string, reason: string, why: string): (boolean, string?)
	Telemetry.log(player, E.PromptRefused, key, reason)
	return false, why
end

-- The key actually sold for `key`: itself when it's on sale, or else its Fallback (a game pass
-- with no id yet falls back to the same thing as a developer product). nil if neither is.
function Store.sellable(key: string): string?
	local entry = ProductConfig.byKey[key]
	if not entry then
		return nil
	end
	if Catalog.enabled(key) then
		return key
	end
	local fallback = entry.Fallback
	if fallback and Catalog.enabled(fallback) then
		return fallback
	end
	return nil
end

-- Asks Roblox to show the purchase window for `key`. Returns whether it did, and why not.
function Store.prompt(player: Player, key: string, context: string?): (boolean, string?)
	local entry = ProductConfig.byKey[key]
	if not entry then
		return false, "That isn't sold here."
	end
	if not Catalog.enabled(key) then
		return refuse(player, key, "not_on_sale", "That isn't on sale yet.")
	end
	local data = Profiles.get(player)
	if not data then
		return false, "Your ledger is still being opened."
	end
	local allowed, why = Risk.canPrompt(player, data)
	if not allowed then
		return refuse(player, key, "restricted", why or "Not just now.")
	end
	local check = Store.eligibility[key]
	if check then
		local ok, reason = check(player, data)
		if not ok then
			return refuse(player, key, "ineligible", reason or "Not just now.")
		end
	end
	-- A second window for the same product straight after the first is a double click.
	local now = os.clock()
	local mine = lastPrompt[player] or {}
	lastPrompt[player] = mine
	if mine[key] and now - mine[key] < ProductConfig.Settings.PromptDebounceSeconds then
		return false, "One moment."
	end
	mine[key] = now
	local id = Catalog.idOf(key)
	local done = pcall(function()
		if entry.ProductType == "GamePass" then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)
	if not done then
		return refuse(player, key, "prompt_failed", "The purchase window couldn't open. Try again in a moment.")
	end
	open[player] = { key = key, at = now }
	Telemetry.log(player, E.Prompt, key, context or "offer", Catalog.price(key), Telemetry.segment(data.purchases))
	return true, nil
end

-- A guest asked for one of the offers by its key (ProductConfig UX.Offer, Action "prompt"): the
-- only products a guest's screen may name directly. Everything else is bought through its own
-- request (a Boutique piece, a gift, a revive), which checks its own rules first.
function Store.promptOffer(player: Player, key: string, context: string?): (boolean, string?)
	local entry = ProductConfig.byKey[key]
	if not entry or not entry.UX.Offer or entry.UX.Action ~= "prompt" then
		return false, "That isn't offered."
	end
	local sell = Store.sellable(key)
	if not sell then
		return false, "That isn't on sale yet."
	end
	return Store.prompt(player, sell, context)
end

-- Records that offers were shown (built on the server, never reported by a screen): one
-- impression per guest per product per ProductConfig.Settings.ImpressionGapSeconds.
function Store.impressions(player: Player, keys: { string })
	local data = Profiles.get(player)
	local segment = if data then Telemetry.segment(data.purchases) else ""
	local seen = lastImpression[player] or {}
	lastImpression[player] = seen
	local now = os.clock()
	for _, key in keys do
		if not seen[key] or now - seen[key] >= ProductConfig.Settings.ImpressionGapSeconds then
			seen[key] = now
			Telemetry.log(player, E.Impression, key, "offers", nil, segment)
		end
	end
end

local function closed(player: Player, id: number, purchased: boolean, pass: boolean)
	local o = open[player]
	local key: string? = nil
	if o and Catalog.idOf(o.key) == id then
		key = o.key
	elseif not pass then
		key = Catalog.keyForProduct(id)
	end
	open[player] = nil
	if not key then
		return
	end
	Telemetry.log(player, E.PromptClosed, key, if purchased then "bought" else "closed")
	for _, fn in closedHandlers do
		local ok, err = pcall(fn :: any, player, key, purchased)
		if not ok then
			warn("[Maison] After a purchase window closed: " .. tostring(err))
		end
	end
end

function Store.start()
	pcall(function()
		MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId: number, productId: number, purchased: boolean)
			local player = Players:GetPlayerByUserId(userId)
			if player then
				closed(player, productId, purchased, false)
			end
		end)
	end)
	pcall(function()
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
			closed(player, passId, purchased, true)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPrompt[player] = nil
		lastImpression[player] = nil
		open[player] = nil
	end)
end

return Store

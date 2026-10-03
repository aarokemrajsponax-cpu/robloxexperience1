--!strict
-- The purchase system: every Robux purchase in the house goes through here.
--
--   Shared/ProductConfig   the catalog: what each product is, costs, gives and how it's shown
--   Catalog                ids in this experience (found by name), live prices, validation
--   Store                  purchase prompts (server-side only, with each product's rules)
--   Receipts               ProcessReceipt: idempotent, acknowledged only after a durable save
--   Ledger                 one DataStore record per PurchaseId (UpdateAsync claims and states)
--   Grants                 grant handlers as transactions, effects after acknowledgement
--   Perks                  credits (bought, spent later), and the perk state for guests' screens
--   Risk                   Normal / Review / Restricted, from server-side signals
--   Telemetry              one analytics schema for every purchase event
--   Velocity, Revive, Decree, Luck, Rain   the five products
--   Piano                  time at the Foyer's grand piano, and the notes played on it
--
-- The Boutique's own products (pieces, purses, the Gold Key...) register their handlers in Shop,
-- which starts first. MONETIZATION.md explains the whole design.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Gilt = require(script.Parent.Gilt)
local LedgerService = require(script.Parent.LedgerService)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Catalog = require(script.Catalog)
local Decree = require(script.Decree)
local Grants = require(script.Grants)
local Ledger = require(script.Ledger)
local Luck = require(script.Luck)
local Perks = require(script.Perks)
local Piano = require(script.Piano)
local PriceLevels = require(script.PriceLevels)
local Rain = require(script.Rain)
local Receipts = require(script.Receipts)
local Revive = require(script.Revive)
local Risk = require(script.Risk)
local Store = require(script.Store)
local Telemetry = require(script.Telemetry)
local Velocity = require(script.Velocity)

local Purchases = {}

Purchases.Revive = Revive
Purchases.Velocity = Velocity
Purchases.Rain = Rain
Purchases.Store = Store
Purchases.Piano = Piano

-- How the purchase system started (for the owner's tools and tests).
Purchases.binding = ""
Purchases.problems = {} :: { [string]: string }

-- Where a guest's screen may say an offer was bought from (analytics only).
local FROM = { offers = true, perks = true, card = true, chips = true }

local function onPerkAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 6, 0)
	if not r then
		RemoteGuard.reject(player, "perkAsk", "malformed")
		return { ok = false, why = "That isn't something the house can do." }
	end
	local op = r.op
	if op == "state" then
		local data = Profiles.get(player)
		if not data then
			return { ok = false, why = "Your ledger is still being opened." }
		end
		return Perks.state(player, data)
	elseif op == "buy" then
		local key = RemoteGuard.string(r.key, 40)
		if not key then
			return { ok = false, why = "That isn't offered." }
		end
		local ok, why = Store.promptOffer(player, key, RemoteGuard.oneOf(r.from, FROM) or "perks")
		return { ok = ok, why = why, prompted = ok }
	elseif op == "decree" then
		return Decree.info(player)
	elseif op == "decreeCompose" then
		local text: string? = nil
		if r.text ~= nil then
			text = RemoteGuard.string(r.text, 400)
			if not text then
				return { ok = false, why = "That can't be proclaimed. Try other words." }
			end
		end
		local preset = if r.preset ~= nil then RemoteGuard.number(r.preset, 1, #Decree.Presets, true) else nil
		if r.preset ~= nil and not preset then
			return { ok = false, why = "Choose one of the house's lines." }
		end
		return Decree.compose(player, text, preset)
	elseif op == "decreeProclaim" then
		return Decree.proclaim(player)
	end
	return { ok = false, why = "That isn't something the house can do." }
end

function Purchases.start()
	Ledger.mock = Profiles.isMock
	RemoteGuard.onRejected = function(player: Player, remote: string, why: string)
		Telemetry.log(player, Telemetry.Events.RemoteRejected, remote, why)
	end
	Risk.onChanged = function(player: Player, state: Risk.State, reasons: { string })
		warn(string.format("[Maison] Purchase check: %s (%d) is now %s (%s). Their receipts are still granted.", player.Name, player.UserId, state, table.concat(reasons, ", ")))
	end

	-- The five products register their handlers, rules and parts of the perk state.
	PriceLevels.start() -- regional pricing: who may gift to whom
	Velocity.start()
	Revive.start()
	Decree.start()
	Luck.start()
	Rain.start()
	Piano.start()
	Gilt.personal = function(player: Player): number
		return Luck.multiplier(player, "gilt")
	end
	LedgerService.personal = function(player: Player): number
		return Luck.multiplier(player, "ledger")
	end
	Rain.giltChanged = function(player: Player)
		Gilt.changed(player)
	end

	-- Every product checked against the handlers that exist: a broken entry is switched off.
	Purchases.problems = Catalog.validate(Grants.names())
	Catalog.discover()
	task.spawn(function()
		while true do
			task.wait(ProductConfig.Settings.DiscoverEverySeconds)
			pcall(Catalog.discover)
		end
	end)
	Purchases.binding = Receipts.bind()
	Store.start()

	Profiles.Loaded:Connect(function(player: Player, data: Profiles.Data)
		task.spawn(function()
			Risk.onJoin(player, data)
			Receipts.flushOutbox(player)
		end)
		Perks.resume(player)
		Perks.push(player)
	end)
	-- Credits that start by themselves are retried now and then (a full queue, a slow start), and
	-- ledger records still waiting to be marked Granted are written.
	task.spawn(function()
		local flushed = 0
		while true do
			task.wait(ProductConfig.Settings.AutoUseRetrySeconds)
			flushed += ProductConfig.Settings.AutoUseRetrySeconds
			for _, player in Players:GetPlayers() do
				pcall(Perks.resume, player)
			end
			if flushed >= ProductConfig.Settings.OutboxFlushSeconds then
				flushed = 0
				for _, player in Players:GetPlayers() do
					pcall(Receipts.flushOutbox, player)
				end
			end
		end
	end)

	RemoteGuard.invoke(Remotes.func("PerkAsk"), "perkAsk", onPerkAsk)
end

return Purchases

--!strict
-- Developer product receipts: the only place a Robux purchase becomes a reward.
--
-- A receipt is safe to process any number of times, on any server, at any moment:
--
--   1. Read it. A malformed receipt, or one for a product the catalog doesn't know (or two
--      products share), is never guessed at: it's logged and left unresolved, so Roblox keeps it
--      and delivers it again once the catalog is fixed.
--   2. Find the buyer and their profile (session-locked by ProfileStore: only one server can hold
--      it). Not here, or not loaded yet: unresolved, Roblox delivers it again when they join.
--   3. Already granted? The PurchaseId is saved in the profile in the same write as the reward,
--      so its presence means the reward is there: acknowledge, grant nothing.
--   4. Claim it in the ledger (UpdateAsync; one server at a time, with a lease).
--   5. Grant: the product's handler runs as a transaction (Grants), the PurchaseId is added.
--   6. Commit: save every profile the grant touched and wait until each save holds its mark. Only
--      then is Roblox told "granted". A save that doesn't land: unresolved, retried (the mark is
--      already in memory, so the retry only waits for the save; it never grants twice).
--   7. Mark the ledger Granted (kept in the buyer's outbox until that write succeeds), then run
--      the handler's after-work (effects, messages).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Ledger = require(script.Parent.Ledger)
local Risk = require(script.Parent.Risk)
local Telemetry = require(script.Parent.Telemetry)

local Receipts = {}

export type Decision = "granted" | "deferred"

local E = Telemetry.Events
local inflight: { [string]: boolean } = {}
-- Grants made on this server whose saves haven't landed yet: the profiles and their marks.
local commits: { [string]: { profiles: { any }, marks: { string } } } = {}

local function settings()
	return ProductConfig.Settings
end

-- Reads and checks a receipt from Roblox. Returns it, or nil and why it can't be used.
function Receipts.read(info: any): (Ledger.Receipt?, string?)
	if type(info) ~= "table" then
		return nil, "not_a_table"
	end
	local playerId, productId, purchaseId, spent = info.PlayerId, info.ProductId, info.PurchaseId, info.CurrencySpent
	if type(playerId) ~= "number" or playerId <= 0 or playerId ~= math.floor(playerId) then
		return nil, "bad_player_id"
	end
	if type(productId) ~= "number" or productId <= 0 or productId ~= math.floor(productId) then
		return nil, "bad_product_id"
	end
	if type(purchaseId) ~= "string" and type(purchaseId) ~= "number" then
		return nil, "bad_purchase_id"
	end
	local id = tostring(purchaseId)
	if id == "" or #id > 100 then
		return nil, "bad_purchase_id"
	end
	if spent ~= nil and (type(spent) ~= "number" or spent ~= spent or spent < 0) then
		return nil, "bad_amount"
	end
	local currency = info.CurrencyType
	if currency ~= nil and currency ~= Enum.CurrencyType.Robux then
		return nil, "not_robux"
	end
	return { id = id, playerId = playerId, productId = productId, spent = (spent :: number?) or 0 }, nil
end

local function savedHolds(profile: any, mark: string): boolean
	local last = profile.LastSavedData
	return type(last) == "table" and type(last.receipts) == "table" and table.find(last.receipts, mark) ~= nil
end

-- Saves each profile and waits until every saved copy holds its mark. True when they all do.
-- (In Studio without API access nothing is saved anywhere, so there's nothing to wait for.)
local function commit(profiles: { any }, marks: { string }): boolean
	if Profiles.isMock() then
		return true
	end
	local waiting: { number } = {}
	for i, p in profiles do
		if not savedHolds(p, marks[i]) then
			table.insert(waiting, i)
		end
	end
	if #waiting == 0 then
		return true
	end
	-- (ProfileStore sets LastSavedData from what actually landed in the DataStore, also when
	-- another server has taken the session: a mark is only "saved" if this grant's write landed.)
	for _, i in waiting do
		local p = profiles[i]
		if p:IsActive() then
			p:Save()
		end
	end
	local function allSaved(): boolean
		for _, i in waiting do
			if not savedHolds(profiles[i], marks[i]) then
				return false
			end
		end
		return true
	end
	local waited = 0
	while not allSaved() and waited < settings().SaveTimeoutSeconds do
		task.wait(0.1)
		waited += 0.1
	end
	return allSaved()
end

local function addMark(data: Profiles.Data, mark: string)
	if table.find(data.receipts, mark) then
		return
	end
	table.insert(data.receipts, mark)
	while #data.receipts > settings().ReceiptsKept do
		table.remove(data.receipts, 1)
	end
end

local function removeOutbox(data: Profiles.Data, id: string)
	for i = #data.ledgerOutbox, 1, -1 do
		if data.ledgerOutbox[i].id == id then
			table.remove(data.ledgerOutbox, i)
		end
	end
end

local function finalize(player: Player, data: Profiles.Data, r: Ledger.Receipt, key: string, risk: string?)
	if Ledger.finalize(r, key, risk) then
		removeOutbox(data, r.id)
	else
		Telemetry.log(player, E.LedgerFailed, key, "finalize", r.spent)
	end
end

-- Marks every receipt still in a guest's outbox as Granted in the ledger (on arrival, and now
-- and then): a grant is always recorded as completed in the end.
function Receipts.flushOutbox(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	for _, entry in table.clone(data.ledgerOutbox) do
		local r: Ledger.Receipt = { id = entry.id, playerId = player.UserId, productId = entry.productId, spent = entry.spent }
		if Ledger.finalize(r, entry.key, nil) then
			removeOutbox(data, entry.id)
		end
	end
end

local function grantNew(player: Player, profile: any, data: Profiles.Data, r: Ledger.Receipt, key: string): Decision
	-- The cross-server claim. Another server's live lease: wait a little for it to lapse.
	local claim, lapses = Ledger.claim(r, key)
	if claim == "busy" and lapses and lapses - os.time() <= settings().LeaseWaitSeconds then
		task.wait(math.max(0, lapses - os.time()) + 1)
		if table.find(data.receipts, r.id) then
			return if commit({ profile }, { r.id }) then "granted" else "deferred"
		end
		claim, lapses = Ledger.claim(r, key)
	end
	if claim == "granted" then
		-- Granted elsewhere, yet this profile doesn't hold it (a profile restored from a backup,
		-- or a save that never landed there). Never grant twice: the ledger's word stands.
		Telemetry.log(player, E.Duplicate, key, "ledger_granted", r.spent)
		Catalog.report(string.format("Receipt %s for %s was already granted by the ledger but isn't in %s's profile: not granted again.", r.id, key, player.Name))
		return "granted"
	end
	if claim ~= "claimed" then
		Telemetry.log(player, E.Deferred, key, if claim == "busy" then "claimed_elsewhere" else "ledger_unavailable", r.spent)
		Risk.noteFailure(player, data)
		return "deferred"
	end
	-- The risk check sees every receipt but never stops one.
	local risk = Risk.onReceipt(player, data, r, key)
	local ctx = Grants.newContext(player, data, key, r.id, r.spent, risk)
	local ok, err = Grants.run(ctx)
	if not ok then
		Ledger.fail(r, key, tostring(err))
		Telemetry.log(player, E.GrantFailed, key, "handler_error", r.spent)
		warn(string.format("[Maison] Granting %s to %s failed (rolled back; Roblox will retry): %s", key, player.Name, tostring(err)))
		Risk.noteFailure(player, data)
		return "deferred"
	end
	local before = data.purchases[key] or 0
	data.purchases[key] = before + 1
	addMark(data, r.id)
	table.insert(data.ledgerOutbox, { id = r.id, productId = r.productId, key = key, spent = r.spent, at = os.time() })
	while #data.ledgerOutbox > settings().LedgerOutboxMax do
		table.remove(data.ledgerOutbox, 1)
	end
	local profiles = { profile }
	local marks = { r.id }
	for _, other in ctx.touched do
		local otherProfile = Profiles.profile(other)
		local otherData = Profiles.get(other)
		if otherProfile and otherData then
			addMark(otherData, "gift:" .. r.id)
			table.insert(profiles, otherProfile)
			table.insert(marks, "gift:" .. r.id)
		end
	end
	if not commit(profiles, marks) then
		commits[r.id] = { profiles = profiles, marks = marks }
		Telemetry.log(player, E.Deferred, key, "save_pending", r.spent)
		return "deferred"
	end
	finalize(player, data, r, key, risk)
	local segment = Telemetry.segment(data.purchases)
	Telemetry.log(player, E.Granted, key, risk, r.spent, segment)
	if before > 0 then
		Telemetry.log(player, E.Repeat, key, tostring(math.min(before, 10)), r.spent, segment)
	end
	task.spawn(Grants.runAfter, ctx)
	return "granted"
end

-- Processes one receipt. "granted" only once the reward is durably saved.
function Receipts.process(info: any): Decision
	local r, bad = Receipts.read(info)
	if not r then
		Telemetry.log(nil, E.Invalid, "receipt", bad)
		return "deferred"
	end
	local player = Players:GetPlayerByUserId(r.playerId)
	local key = Catalog.keyForProduct(r.productId)
	if not key then
		Ledger.note(r, "?", "unknown_product")
		Telemetry.log(player, E.Deferred, "unknown", "unknown_product", r.spent)
		Catalog.report(string.format("A receipt for developer product %d isn't in the catalog: it stays unresolved until that product is added (Creator Hub name or ProductConfig).", r.productId))
		return "deferred"
	end
	local off = Catalog.disabledWhy(key)
	if off then
		-- A product switched off at start (its catalog entry is broken): never granted from a
		-- broken entry. It waits, and the owner is told, until the entry is fixed.
		Ledger.note(r, key, "product_disabled")
		Telemetry.log(player, E.Deferred, key, "product_disabled", r.spent)
		Catalog.report(string.format("A receipt for %s waits: the product is switched off (%s).", key, off))
		return "deferred"
	end
	if not player then
		return "deferred" -- Roblox delivers it again when the buyer is in a server
	end
	local profile = Profiles.profile(player)
	if not profile then
		Profiles.wait(player, settings().ProfileWaitSeconds)
		profile = Profiles.profile(player)
	end
	if not profile then
		Ledger.note(r, key, "profile_not_loaded")
		Telemetry.log(player, E.Deferred, key, "profile_not_loaded", r.spent)
		return "deferred"
	end
	local data = profile.Data :: Profiles.Data
	if table.find(data.receipts, r.id) then
		-- Granted already. If this server is still waiting for that grant's saves, finish them.
		local pending = commits[r.id]
		local saved = if pending then commit(pending.profiles, pending.marks) else commit({ profile }, { r.id })
		if not saved then
			Telemetry.log(player, E.Deferred, key, "save_pending", r.spent)
			return "deferred"
		end
		if pending then
			commits[r.id] = nil
			finalize(player, data, r, key, nil)
			Telemetry.log(player, E.Granted, key, "after_retry", r.spent, Telemetry.segment(data.purchases))
		else
			finalize(player, data, r, key, nil)
			Telemetry.log(player, E.Duplicate, key, "replayed", r.spent)
		end
		return "granted"
	end
	if inflight[r.id] then
		Telemetry.log(player, E.Deferred, key, "in_flight", r.spent)
		return "deferred"
	end
	inflight[r.id] = true
	local ok, decision = pcall(grantNew, player, profile, data, r, key)
	inflight[r.id] = nil
	if not ok then
		warn("[Maison] Receipt processing failed (Roblox will retry): " .. tostring(decision))
		Telemetry.log(player, E.GrantFailed, key, "processor_error", r.spent)
		return "deferred"
	end
	return decision :: Decision
end

-- Binds the processor to Roblox. ProcessReceipt is the long-standing, documented callback;
-- BindReceiptHandler is newer and is used only when chosen in ProductConfig.Settings and present.
function Receipts.bind(): string
	if settings().ReceiptBinding == "BindReceiptHandler" then
		local ok = pcall(function()
			(MarketplaceService :: any):BindReceiptHandler((Enum :: any).ReceiptType.DeveloperProduct, function(info: any): any
				return if Receipts.process(info) == "granted" then (Enum :: any).ReceiptDecision.Processed else (Enum :: any).ReceiptDecision.NotProcessedYet
			end)
		end)
		if ok then
			return "BindReceiptHandler"
		end
		Catalog.report("BindReceiptHandler isn't available here; receipts use ProcessReceipt.")
	end
	MarketplaceService.ProcessReceipt = function(info: any): Enum.ProductPurchaseDecision
		return if Receipts.process(info) == "granted" then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return "ProcessReceipt"
end

return Receipts

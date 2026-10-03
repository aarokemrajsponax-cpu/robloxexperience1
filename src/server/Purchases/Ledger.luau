--!strict
-- The purchase ledger: one DataStore record per receipt (keyed by its PurchaseId), moved through
--
--     (none) -> Pending -> Granting -> Granted
--                  ^          |
--                  +- Failed <+
--
-- only ever with UpdateAsync, so two servers handling the same receipt can't both win:
--
-- * claim:    takes a receipt for granting. Refused if it's Granted, or if another server holds
--             a live lease (Granting, leaseUntil in the future). An expired lease (a server that
--             crashed mid-grant) is taken over.
-- * finalize: marks it Granted once the reward is saved in the buyer's profile.
-- * fail:     a handler error; the lease is dropped so the next delivery can try again.
-- * note:     records a receipt that was seen but deferred (Pending, with the reason).
--
-- The buyer's profile is the first line of idempotency (the PurchaseId is saved in the same
-- write as the reward, under ProfileStore's session lock); the ledger is the cross-server claim
-- and the audit trail. Each record carries the buyer's UserId (UpdateAsync's userIds), so
-- Roblox's data-erasure requests reach it.
--
-- In Studio without API access there are no DataStores: the ledger keeps its records in memory
-- (Ledger.mock, set to Profiles.isMock), which is enough to test purchases there.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)

local Ledger = {}

export type State = "Pending" | "Granting" | "Granted" | "Failed"
export type Record = {
	v: number,
	id: string,
	state: State,
	playerId: number,
	productId: number,
	key: string,
	spent: number,
	firstSeen: number,
	updated: number,
	server: string,
	leaseUntil: number,
	attempts: number,
	grantedAt: number?,
	reason: string?,
	risk: string?,
}
export type Receipt = { id: string, playerId: number, productId: number, spent: number }
export type Claim = "claimed" | "granted" | "busy" | "error"

-- True when there are no DataStores to write to (set by the purchase system).
Ledger.mock = function(): boolean
	return false
end
local memory: { [string]: Record } = {}
local store: any = nil
local noted: { [string]: boolean } = {}

-- This server's name in the ledger (the JobId; in Studio, where it's empty, a made-up one).
local jobId = (game :: any).JobId
local serverId: string = if type(jobId) == "string" and jobId ~= "" then jobId else ("studio-" .. HttpService:GenerateGUID(false))
function Ledger.serverId(): string
	return serverId
end

-- FNV-1a over the id's bytes, as 32 bits.
local function fnv(text: string, seed: number): number
	local h = seed
	for i = 1, #text do
		h = bit32.bxor(h, string.byte(text, i))
		-- h * 16777619 (the FNV prime), kept to 32 bits without losing precision
		h = (bit32.lshift(h, 24) + bit32.lshift(h, 8) + bit32.band(h * 0x93, 0xFFFFFFFF)) % 4294967296
	end
	return h
end

-- The DataStore key for a PurchaseId. Keys are at most 50 characters; Roblox's PurchaseIds are
-- far shorter, but a longer one is hashed (two 32-bit hashes; the record keeps the full id)
-- rather than failing forever.
function Ledger.keyOf(id: string): string
	if #id <= 48 then
		return "p_" .. id
	end
	return string.format("h_%08x%08x", fnv(id, 2166136261), fnv(id, 16777619))
end
local keyOf = Ledger.keyOf

-- One atomic read-modify-write. `fn` gets the current record (or nil) and returns the new one,
-- or nil to leave it untouched. Returns false if the DataStore call failed.
local function update(id: string, playerId: number, fn: (old: Record?) -> Record?): boolean
	if Ledger.mock() then
		local new = fn(memory[keyOf(id)])
		if new ~= nil then
			memory[keyOf(id)] = new
		end
		return true
	end
	local ok, err = pcall(function()
		if store == nil then
			store = DataStoreService:GetDataStore(ProductConfig.Settings.LedgerStore)
		end
		store:UpdateAsync(keyOf(id), function(old: any): (any, any)
			local new = fn(if type(old) == "table" then old :: Record else nil)
			if new == nil then
				return nil -- leave the record as it is
			end
			return new, { playerId }
		end)
	end)
	if not ok then
		warn("[Maison] Purchase ledger unavailable: " .. tostring(err))
	end
	return ok
end

local function fresh(r: Receipt, key: string, now: number): Record
	return {
		v = 1,
		id = r.id,
		state = "Pending",
		playerId = r.playerId,
		productId = r.productId,
		key = key,
		spent = r.spent,
		firstSeen = now,
		updated = now,
		server = serverId,
		leaseUntil = 0,
		attempts = 0,
	}
end

-- Takes the receipt for granting on this server. Returns "claimed", "granted" (already done),
-- "busy" (another server holds a live lease; also returns when it lapses) or "error".
function Ledger.claim(r: Receipt, key: string): (Claim, number?)
	local result: Claim = "error"
	local lapses: number? = nil
	local ok = update(r.id, r.playerId, function(old: Record?): Record?
		local now = os.time()
		if old and old.state == "Granted" then
			result = "granted"
			return nil
		end
		if old and old.state == "Granting" and old.server ~= serverId and (old.leaseUntil or 0) > now then
			result = "busy"
			lapses = old.leaseUntil
			return nil
		end
		local rec = old or fresh(r, key, now)
		rec.state = "Granting"
		rec.server = serverId
		rec.leaseUntil = now + ProductConfig.Settings.LeaseSeconds
		rec.attempts = (rec.attempts or 0) + 1
		rec.updated = now
		rec.key = key
		rec.spent = r.spent
		result = "claimed"
		return rec
	end)
	if not ok then
		return "error", nil
	end
	return result, lapses
end

-- Marks the receipt Granted (the reward is saved). Returns false if the write failed; the
-- caller keeps it in the buyer's outbox and tries again later.
function Ledger.finalize(r: Receipt, key: string, risk: string?): boolean
	return update(r.id, r.playerId, function(old: Record?): Record?
		local now = os.time()
		if old and old.state == "Granted" then
			return nil
		end
		local rec = old or fresh(r, key, now)
		rec.state = "Granted"
		rec.grantedAt = now
		rec.updated = now
		rec.server = serverId
		rec.leaseUntil = 0
		rec.reason = nil
		rec.risk = risk
		return rec
	end)
end

-- A handler failed: the receipt goes back to waiting, with the reason, and its lease is dropped.
function Ledger.fail(r: Receipt, key: string, reason: string): boolean
	return update(r.id, r.playerId, function(old: Record?): Record?
		local now = os.time()
		if old and old.state == "Granted" then
			return nil
		end
		local rec = old or fresh(r, key, now)
		rec.state = "Failed"
		rec.reason = string.sub(reason, 1, 200)
		rec.updated = now
		rec.leaseUntil = 0
		return rec
	end)
end

-- A receipt seen but deferred (unknown product, buyer not ready...). Written once per server per
-- receipt and reason, so retries don't spend the DataStore budget.
function Ledger.note(r: Receipt, key: string, reason: string)
	local mark = r.id .. "|" .. reason
	if noted[mark] then
		return
	end
	noted[mark] = true
	update(r.id, r.playerId, function(old: Record?): Record?
		local now = os.time()
		if old and (old.state == "Granted" or old.state == "Granting") then
			return nil
		end
		local rec = old or fresh(r, key, now)
		rec.reason = reason
		rec.updated = now
		return rec
	end)
end

-- Reads a record (for support and tests). nil if there's none or the read failed.
function Ledger.get(id: string): Record?
	if Ledger.mock() then
		return memory[keyOf(id)]
	end
	local ok, value = pcall(function()
		if store == nil then
			store = DataStoreService:GetDataStore(ProductConfig.Settings.LedgerStore)
		end
		return store:GetAsync(keyOf(id))
	end)
	return if ok and type(value) == "table" then value :: Record else nil
end

return Ledger

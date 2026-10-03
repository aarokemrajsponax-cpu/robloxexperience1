--!strict
-- Emperor's Decree: the buyer's words in gold across every screen in the house for eight seconds
-- (ProductConfig emperorsDecree).
--
-- Words first, then the purchase. The guest writes the decree; the server checks it (length,
-- plain text, no line breaks), asks Roblox whether this guest may chat at all
-- (TextChatService:CanUserChatAsync: a guest who can't may only choose one of the house's
-- preset lines) and filters it for broadcast (TextService). Only the filtered text is kept,
-- waiting for its purchase. The receipt grants a decree credit; with a written decree waiting,
-- it's spent at once and the decree joins the house's queue.
--
-- Nobody can style, time, or sign a decree: the server sets the look, the duration and the
-- banner's heading (the buyer's display name and @username, always). Decrees play one at a time
-- with a gap between them, a guest waits between their own, and the queue is short: when it's
-- full the house doesn't offer the purchase. Every decree is logged (who, what, when, which
-- server) to a DataStore for moderation.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Profiles = require(script.Parent.Parent.Profiles)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Ledger = require(script.Parent.Ledger)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local Decree = {}

local KEY = "emperorsDecree"
local CREDIT = "decree"
local LOG_STORE = "MaisonNoir_DecreeLog"

-- The house's own lines, for guests Roblox doesn't let chat (and anyone who'd rather).
Decree.Presets = {
	"Good evening, everyone.",
	"The next round is on me.",
	"Long live the house!",
	"To the last lamp lit.",
	"Sort well, my friends.",
	"Tonight belongs to all of us.",
}

type Pending = { text: string, at: number }
type Queued = { player: Player, userId: number, name: string, user: string, text: string }

local pending: { [Player]: Pending } = {}
local queue: { Queued } = {}
local lastBy: { [number]: number } = {} -- userId -> os.clock() of their last decree
local nextAt = 0
local logStore: any = nil

local function entry(): ProductConfig.Entry
	return ProductConfig.byKey[KEY]
end

local function rules(): { [string]: any }
	return entry().Rules
end

-- Seconds before this guest may proclaim again (0 if they may).
function Decree.cooldown(player: Player): number
	local last = lastBy[player.UserId]
	if not last then
		return 0
	end
	return math.max(0, math.ceil(last + rules().PlayerCooldownSeconds - os.clock()))
end

function Decree.queueLength(): number
	return #queue
end

-- Plain text: no control characters or line breaks, spaces collapsed, trimmed.
function Decree.clean(text: string): string
	local s = string.gsub(text, "[%c]", " ")
	s = string.gsub(s, "%s+", " ")
	return (string.match(s, "^%s*(.-)%s*$") or "")
end

local function canChat(player: Player): boolean
	local ok, allowed = pcall(function()
		return (TextChatService :: any):CanUserChatAsync(player.UserId)
	end)
	return ok and allowed == true
end

local function filtered(player: Player, text: string): string?
	local ok, result = pcall(function()
		local f = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return f:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" then
		return result
	end
	return nil
end

-- Checks and filters a decree a guest wrote (or a preset they chose) and keeps it for their
-- purchase. Returns what the house would show, or why not.
function Decree.compose(player: Player, text: unknown, preset: unknown): { [string]: any }
	local chosen: string? = nil
	if type(preset) == "number" and preset == math.floor(preset) and Decree.Presets[preset] then
		chosen = Decree.Presets[preset]
	elseif type(text) == "string" then
		if not canChat(player) then
			return { ok = false, why = "Your account's chat settings allow only the house's own lines. Choose one below.", presetsOnly = true }
		end
		local clean = Decree.clean(text)
		local length = utf8.len(clean)
		if length == nil or length < 2 then
			return { ok = false, why = "Write a few words first." }
		elseif length > rules().MaxLength then
			return { ok = false, why = string.format("At most %d characters.", rules().MaxLength) }
		end
		local f = filtered(player, clean)
		if not f then
			return { ok = false, why = "The house couldn't read that just now. Try again in a moment." }
		end
		local _, hashes = string.gsub(f, "#", "#")
		if hashes > (utf8.len(f) or #f) * 0.5 then
			return { ok = false, why = "That can't be proclaimed. Try other words." }
		end
		chosen = f
	else
		return { ok = false, why = "Write your decree, or choose one of the house's." }
	end
	local words = chosen :: string
	pending[player] = { text = words, at = os.clock() }
	local data = Profiles.get(player)
	return {
		ok = true,
		text = words,
		held = if data then Perks.credits(data, CREDIT) else 0,
		price = Catalog.price(KEY),
		cooldown = Decree.cooldown(player),
		queue = #queue,
	}
end

-- What the decree panel needs when it opens.
function Decree.info(player: Player): { [string]: any }
	local data = Profiles.get(player)
	local p = pending[player]
	return {
		ok = true,
		presets = Decree.Presets,
		maxLength = rules().MaxLength,
		seconds = entry().Reward.DisplaySeconds,
		price = Catalog.price(KEY),
		onSale = Catalog.enabled(KEY),
		held = if data then Perks.credits(data, CREDIT) else 0,
		cooldown = Decree.cooldown(player),
		queue = #queue,
		queueMax = rules().QueueMax,
		written = if p then p.text else nil,
	}
end

local function waiting(player: Player): Pending?
	local p = pending[player]
	if p and os.clock() - p.at <= rules().PendingSeconds then
		return p
	end
	pending[player] = nil
	return nil
end

-- Why a guest can't proclaim now, or nil.
local function blocked(player: Player): string?
	if Decree.cooldown(player) > 0 then
		return string.format("Your next decree may be proclaimed in %d seconds.", Decree.cooldown(player))
	end
	if #queue >= rules().QueueMax then
		return "The house is hearing other decrees. Try again in a minute."
	end
	return nil
end

local function audit(q: Queued)
	local day = os.date("!%Y-%m-%d", os.time()) :: string
	local record = { userId = q.userId, name = q.name, user = q.user, text = q.text, at = os.time(), server = Ledger.serverId() }
	if Ledger.mock() then
		return
	end
	task.spawn(function()
		pcall(function()
			if logStore == nil then
				logStore = DataStoreService:GetDataStore(LOG_STORE)
			end
			logStore:UpdateAsync("day_" .. day, function(old: any)
				local list = if type(old) == "table" then old else {}
				table.insert(list, record)
				while #list > 300 do
					table.remove(list, 1)
				end
				return list
			end)
		end)
	end)
end

-- Spends a credit on the waiting decree and queues it. True if it did.
local function post(player: Player, data: Profiles.Data): boolean
	local p = waiting(player)
	if not p or blocked(player) then
		return false
	end
	if not Perks.use(player, data, CREDIT, KEY) then
		return false
	end
	pending[player] = nil
	lastBy[player.UserId] = os.clock()
	local q: Queued = { player = player, userId = player.UserId, name = player.DisplayName, user = player.Name, text = p.text }
	table.insert(queue, q)
	audit(q)
	Perks.push(player)
	Perks.tell(player, { op = "notice", title = "Emperor's Decree", line = if #queue == 1 and os.clock() >= nextAt then "Proclaimed." else "Your decree is next in line." })
	return true
end

-- The guest pressed Proclaim: spend a decree they hold, or open the purchase.
function Decree.proclaim(player: Player): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	if not waiting(player) then
		return { ok = false, why = "Write your decree first." }
	end
	local why = blocked(player)
	if why then
		return { ok = false, why = why }
	end
	if Perks.credits(data, CREDIT) > 0 then
		return { ok = post(player, data), used = true }
	end
	local ok, reason = Store.prompt(player, KEY, "compose")
	return { ok = ok, why = reason, prompted = ok }
end

local function grant(ctx: Grants.Context)
	Perks.add(ctx.data, CREDIT, 1)
	local player, data = ctx.player, ctx.data
	ctx:after(function()
		if not post(player, data) then
			-- Written but the house is busy (or the guest must wait): kept, to proclaim later.
			local why = if waiting(player) then blocked(player) else nil
			Perks.push(player)
			Perks.tell(player, {
				op = "notice",
				title = "Emperor's Decree",
				line = if why then "Your decree is kept for you. " .. why else "Your decree is ready: write it whenever you like (Boutique → Offers).",
			})
		end
	end)
end

-- Plays the queue: one decree at a time, with the gap between them.
local function play()
	while true do
		task.wait(0.25)
		if #queue > 0 and os.clock() >= nextAt then
			local q = table.remove(queue, 1) :: Queued
			local reward = entry().Reward
			Perks.tellAll({
				op = "decree",
				id = HttpService:GenerateGUID(false),
				name = q.name,
				user = q.user,
				text = q.text,
				seconds = reward.DisplaySeconds,
			})
			nextAt = os.clock() + reward.DisplaySeconds + rules().GlobalGapSeconds
		end
	end
end

function Decree.start()
	Grants.register("decree", grant)
	Store.eligibility[KEY] = function(player: Player, data: Profiles.Data): (boolean, string?)
		if not waiting(player) then
			return false, "Write your decree first."
		end
		if Perks.credits(data, CREDIT) >= (rules().MaxHeld or 5) then
			return false, "You hold as many decrees as the house keeps."
		end
		local why = blocked(player)
		return why == nil, why
	end
	Perks.contributors.decree = function(player: Player, data: Profiles.Data): any
		return { held = Perks.credits(data, CREDIT), cooldown = Decree.cooldown(player), queue = #queue, maxLength = rules().MaxLength }
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		pending[player] = nil
	end)
	task.spawn(play)
end

return Decree

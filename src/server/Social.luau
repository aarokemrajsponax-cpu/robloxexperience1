--!strict
-- Guests noticing each other. Walk up to another guest and admire them: they hear who did, the
-- house counts it for their next welcome, and you see what they're wearing and where it's from
-- (a key straight to that shelf of the Boutique), with a key to send them a gift. And the Livre
-- d'Or: sign it once a night with a chosen line; the last thirty signatures stay for everyone.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boutique = require(ReplicatedStorage.Shared.Boutique)
local GuestBook = require(ReplicatedStorage.Shared.GuestBook)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Analytics = require(script.Parent.Analytics)
local Dressing = require(script.Parent.Dressing)
local Memory = require(script.Parent.Memory)
local Profiles = require(script.Parent.Profiles)

local Social = {}

-- The season the Boutique is in (set by Main).
Social.season = function(): string
	return ""
end

local ADMIRE_AGAIN = 600 -- seconds before the same guest can admire the same guest again
local lastAdmire: { [string]: number } = {}
local lastAny: { [Player]: number } = {}

-- Which Boutique shelf an item sits on right now, or nil.
function Social.where(item: Wardrobe.Item): string?
	if item.source == "gilt" or item.source == "standing" then
		return "gilt"
	elseif item.source == "goldKey" then
		return "goldKey"
	end
	for _, a in Boutique.always() do
		if a.id == item.id then
			return "always"
		end
	end
	for _, t in Boutique.today() do
		if t.id == item.id then
			return "today"
		end
	end
	for _, f in Boutique.featured() do
		if f.id == item.id then
			return "week"
		end
	end
	if item.source == "season" and item.season == Social.season() then
		return "season"
	end
	return nil
end

-- What a guest is wearing, piece by piece, and where each is from.
function Social.outfit(data: Profiles.Data): { { [string]: any } }
	local out = {}
	for _, kind in Wardrobe.Kinds do
		local id = data.equipped[kind]
		local item = if type(id) == "string" and id ~= "" then Dressing.item(id) else nil
		if item then
			table.insert(out, { kind = kind, kindName = Wardrobe.KindNames[kind], id = item.id, name = item.name, where = Social.where(item) })
		end
	end
	if data.goldKey then
		table.insert(out, { kind = "pass", kindName = "The Gold Key", id = "goldKey", name = "The Gold Key", where = "goldKey" })
	end
	return out
end

function Social.admire(player: Player, userId: number): { [string]: any }
	local target = Players:GetPlayerByUserId(userId)
	local tdata = target and Profiles.get(target)
	if not target or not tdata or target == player then
		return { ok = false, why = "They've stepped away." }
	end
	local now = os.clock()
	if lastAny[player] and now - lastAny[player] < 3 then
		return { ok = false, why = "One moment." }
	end
	lastAny[player] = now
	local key = tostring(player.UserId) .. ":" .. tostring(userId)
	local fresh = not lastAdmire[key] or now - lastAdmire[key] >= ADMIRE_AGAIN
	if fresh then
		lastAdmire[key] = now
		Memory.admired(target)
		Remotes.event("Shop"):FireClient(target, { op = "admired", from = player.DisplayName })
		Analytics.custom(player, "Admired a guest", nil, nil)
	end
	return { ok = true, name = target.DisplayName, userId = target.UserId, pieces = Social.outfit(tdata), counted = fresh }
end

---------------------------------------------------------------------------------------------------
-- The Livre d'Or
---------------------------------------------------------------------------------------------------
export type Signature = { name: string, line: number, at: number }
local signatures: { Signature } = {}
local fetchedAt = -math.huge

local function store(): DataStore?
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore("MaisonNoir_GuestBook")
	end)
	return if ok then s else nil
end

local function refresh()
	if os.clock() - fetchedAt < 60 then
		return
	end
	fetchedAt = os.clock()
	local s = store()
	if not s then
		return
	end
	local ok, value = pcall(function()
		return (s :: DataStore):GetAsync("recent")
	end)
	if ok and type(value) == "table" then
		signatures = value :: { Signature }
	end
end

function Social.guestBook(player: Player, data: Profiles.Data): { [string]: any }
	refresh()
	local entries = {}
	for _, sig in signatures do
		local text = GuestBook.Lines[sig.line]
		if text then
			table.insert(entries, { name = sig.name, text = text, at = sig.at })
		end
	end
	return { lines = GuestBook.Lines, entries = entries, signedToday = data.memory.signedDay == math.floor(os.time() / 86400), now = os.time() }
end

function Social.sign(player: Player, data: Profiles.Data, line: number): { [string]: any }
	local today = math.floor(os.time() / 86400)
	if not GuestBook.Lines[line] or line ~= math.floor(line) then
		return { ok = false, why = "Choose a line." }
	elseif data.memory.signedDay == today then
		return { ok = false, why = "You've signed the book tonight. Come back tomorrow." }
	end
	data.memory.signedDay = today
	local entry: Signature = { name = player.DisplayName, line = line, at = os.time() }
	local s = store()
	local written = false
	if s then
		local ok, value = pcall(function()
			return (s :: DataStore):UpdateAsync("recent", function(old: any)
				local list = if type(old) == "table" then old else {}
				table.insert(list, 1, entry)
				while #list > GuestBook.keep do
					table.remove(list)
				end
				return list
			end)
		end)
		if ok and type(value) == "table" then
			signatures = value :: { Signature }
			fetchedAt = os.clock()
			written = true
		end
	end
	if not written then
		table.insert(signatures, 1, entry)
		while #signatures > GuestBook.keep do
			table.remove(signatures)
		end
	end
	Analytics.custom(player, "Signed the Livre d'Or", line, nil)
	return Social.guestBook(player, data)
end

function Social.start()
	Players.PlayerRemoving:Connect(function(player)
		lastAny[player] = nil
	end)
end

return Social

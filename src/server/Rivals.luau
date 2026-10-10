--!strict
-- Rivals (§9.6). Every guest keeps a small public card (display name, Library rating, tonight's
-- Nightly score, when they were last here). Once a week the house picks each guest a rival from
-- their Roblox connections who play here, closest in skill, or failing that someone they played
-- recently; the plate by their table carries one fact and turns when they're ahead.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)
local Config = require(ReplicatedStorage.Shared.Config)
local Nightly = require(ReplicatedStorage.Shared.Nightly)
local Rival = require(ReplicatedStorage.Shared.Rival)

local Profiles = require(script.Parent.Profiles)

local Rivals = {}

export type Info = { name: string, fact: string, ahead: boolean }

-- Tells a guest's screen about their rival (set by Guests).
Rivals.send = function(_player: Player, _info: Info?) end

local STORE = "MaisonNoir_Cards_v1"
local store: DataStore? = nil
local cardCache: { [number]: { card: Rival.Card?, at: number } } = {}
local lastWrite: { [Player]: number } = {}
local CACHE_SECONDS = 120

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, s = pcall(function()
		return DataStoreService:GetDataStore(STORE)
	end)
	if ok then
		store = s
	end
	return store
end

local function cardOf(player: Player, data: Profiles.Data): Rival.Card
	return {
		name = Names.of(player),
		r = data.duel.r,
		matches = data.duel.matches,
		nightlyKey = data.nightly.key,
		nightlyScore = data.nightly.score,
		seen = os.time(),
	}
end

local function readCard(userId: number): Rival.Card?
	local cached = cardCache[userId]
	if cached and os.clock() - cached.at < CACHE_SECONDS then
		return cached.card
	end
	-- A guest in this server: read their live data instead of the store.
	local here = Players:GetPlayerByUserId(userId)
	local data = here and Profiles.get(here)
	if here and data then
		local card = cardOf(here, data)
		cardCache[userId] = { card = card, at = os.clock() }
		return card
	end
	local s = getStore()
	if not s then
		return nil
	end
	local ok, value = pcall(function()
		return s:GetAsync(tostring(userId))
	end)
	local card: Rival.Card? = nil
	if ok and type(value) == "table" and type(value.r) == "number" and type(value.seen) == "number" then
		card = {
			name = if type(value.name) == "string" then value.name else "A guest",
			r = value.r,
			matches = if type(value.matches) == "number" then value.matches else 0,
			nightlyKey = if type(value.nightlyKey) == "string" then value.nightlyKey else "",
			nightlyScore = if type(value.nightlyScore) == "number" then value.nightlyScore else 0,
			seen = value.seen,
		}
	end
	if ok then
		cardCache[userId] = { card = card, at = os.clock() }
	end
	return card
end

-- Writes a guest's public card (at most every couple of minutes unless forced).
function Rivals.publish(player: Player, force: boolean?)
	local data = Profiles.get(player)
	local s = getStore()
	if not data or not s then
		return
	end
	local now = os.clock()
	if not force and lastWrite[player] and now - lastWrite[player] < Config.data.Rivals.cardEverySeconds then
		return
	end
	lastWrite[player] = now
	local card = cardOf(player, data)
	cardCache[player.UserId] = { card = card, at = now }
	task.spawn(function()
		pcall(function()
			s:SetAsync(tostring(player.UserId), card, { player.UserId })
		end)
	end)
end

local function connections(player: Player): { number }
	local ids: { number } = {}
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok or not pages then
		return ids
	end
	local limit = Config.data.Rivals.connectionsChecked
	pcall(function()
		while #ids < limit do
			for _, f in pages:GetCurrentPage() do
				table.insert(ids, f.Id)
				if #ids >= limit then
					break
				end
			end
			if pages.IsFinished or #ids >= limit then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	return ids
end

-- Picks this week's rival if the week has turned (or none was found yet).
local function choose(player: Player, data: Profiles.Data)
	local week = Rival.week()
	if data.rival.week == week and data.rival.userId ~= 0 then
		return
	end
	local mine = cardOf(player, data)
	local candidates: { Rival.Candidate } = {}
	for _, id in connections(player) do
		local card = readCard(id)
		if card then
			table.insert(candidates, { userId = id, card = card })
		end
	end
	local picked = Rival.pick(mine, candidates, os.time())
	local source = "connection"
	if not picked then
		-- No connections here yet: someone you played recently in the Library.
		for _, o in data.duel.recent do
			if os.time() - o.at <= Config.data.Rivals.activeDays * 86400 then
				local card = readCard(o.userId) or { name = o.name, r = 1500, matches = 0, nightlyKey = "", nightlyScore = 0, seen = o.at }
				picked = { userId = o.userId, card = card }
				source = "recent"
				break
			end
		end
	end
	if picked then
		data.rival = { week = week, userId = picked.userId, name = picked.card.name, source = source }
	else
		data.rival = { week = week, userId = 0, name = "", source = "" }
	end
end

-- The rival's plate for this guest, or nil if the house has no rival for them this week.
function Rivals.info(player: Player): Info?
	local data = Profiles.get(player)
	if not data or data.rival.userId == 0 then
		return nil
	end
	local theirs = readCard(data.rival.userId)
	if not theirs then
		return { name = data.rival.name, fact = "Your rival this week.", ahead = false }
	end
	local fact, ahead = Rival.fact(cardOf(player, data), theirs, Nightly.at().key)
	return { name = theirs.name, fact = fact, ahead = ahead }
end

-- Recomputes and sends the plate (after a Nightly, a Library evening, or on arrival).
function Rivals.refresh(player: Player)
	task.spawn(function()
		if player.Parent ~= Players then
			return
		end
		local data = Profiles.get(player)
		if not data then
			return
		end
		choose(player, data)
		Rivals.send(player, Rivals.info(player))
	end)
end

function Rivals.start()
	Profiles.Loaded:Connect(function(player: Player)
		Rivals.publish(player, true)
		Rivals.refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastWrite[player] = nil
	end)
end

return Rivals

--!strict
-- The Soirée, kept (§9.5, Appendix H5): each guest's results over the weekend (only evenings
-- that count for records, and only real opponents in the Library), their score from the best
-- ones, a board for every server, the Soirée's stamp at three plays, and after the weekend the
-- medal (top 1%) or the dated invitation card (top 10%). Its countdown is one line on the Foyer's
-- Tonight board, the only clock ever allowed in the Foyer.

local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Names = require(ReplicatedStorage.Shared.Names)
local Config = require(ReplicatedStorage.Shared.Config)
local Soiree = require(ReplicatedStorage.Shared.Soiree)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)

local Analytics = require(script.Parent.Analytics)
local Private = require(script.Parent.Private)
local Profiles = require(script.Parent.Profiles)

local SoireeService = {}

SoireeService.notice = function(_player: Player, _title: string, _line: string) end
SoireeService.board = function(_key: string, _entries: { { userId: number, name: string, score: number } }) end

local KEEP_SECONDS = 10 * 86400

local function state(data: Profiles.Data): any
	local d = data :: any
	d.soiree = d.soiree or { key = "", results = {}, plays = 0, score = 0, claimed = "", stamps = {}, medals = {}, invitations = {} }
	return d.soiree
end

local function map(key: string): MemoryStoreSortedMap?
	local ok, m = pcall(function()
		return MemoryStoreService:GetSortedMap("MaisonNoir_Soiree_" .. key)
	end)
	return if ok then m else nil
end

-- A result from the Ballroom or the Library.
function SoireeService.record(player: Player, format: "ballroom" | "library", result: { place: number?, keys: number?, won: boolean? })
	local weekend = Soiree.at()
	if not weekend.active or weekend.format ~= format or not Private.records() then
		return
	end
	local data = Profiles.get(player)
	if not data then
		return
	end
	local s = state(data)
	if s.key ~= weekend.key then
		s.key = weekend.key
		s.results = {}
		s.plays = 0
		s.score = 0
	end
	table.insert(s.results, Soiree.points(format, result))
	s.plays += 1
	s.score = Soiree.score(format, s.results)
	if s.plays == Config.data.Soiree.stampPlays and not s.stamps[weekend.key] then
		s.stamps[weekend.key] = true
		SoireeService.notice(player, weekend.name, "Three evenings: the Soirée's stamp is in your Register.")
	end
	local score = s.score
	task.spawn(function()
		local m = map(weekend.key)
		if m then
			pcall(function()
				m:UpdateAsync(tostring(player.UserId), function()
					return Names.of(player), score
				end, KEEP_SECONDS)
			end)
		end
	end)
	Analytics.custom(player, "Soirée result", score, { format = format })
end

-- After a weekend: the medal or the invitation, once.
local function claim(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local s = state(data)
	local now = Soiree.at()
	if s.key == "" or s.claimed == s.key or (now.active and now.key == s.key) or s.score <= 0 then
		return
	end
	local m = map(s.key)
	if not m then
		return
	end
	local okSize, total = pcall(function()
		return m:GetSizeAsync()
	end)
	local okAbove, above = pcall(function()
		-- How many scored higher.
		local items = m:GetRangeAsync(Enum.SortDirection.Descending, 200)
		local n = 0
		for _, item in items do
			if type(item.sortKey) == "number" and item.sortKey > s.score then
				n += 1
			end
		end
		return n
	end)
	if not okSize or not okAbove then
		return
	end
	s.claimed = s.key
	local reward = Soiree.reward(above + 1, total)
	if reward == "medal" then
		s.medals[s.key] = true
		local medal = Wardrobe.soireeMedal(s.key)
		data.owned[medal.id] = true
		SoireeService.notice(player, "The Soirée Medal", "Top 1% at the Soirée of " .. s.key .. ". It's yours to wear, and it's never sold.")
	elseif reward == "invitation" then
		s.invitations[s.key] = true
		SoireeService.notice(player, "An invitation card", "Top 10% at the Soirée of " .. s.key .. ". A dated card is in your Register.")
	end
	Analytics.custom(player, "Soirée reward", above + 1, { reward = reward or "none" })
end

local function refreshBoard()
	local weekend = Soiree.at()
	local m = map(weekend.key)
	if not m then
		return
	end
	local ok, items = pcall(function()
		return m:GetRangeAsync(Enum.SortDirection.Descending, 10)
	end)
	if ok and items then
		local entries = {}
		for _, item in items do
			table.insert(entries, { userId = tonumber(item.key) or 0, name = tostring(item.value), score = if type(item.sortKey) == "number" then item.sortKey else 0 })
		end
		SoireeService.board(weekend.key, entries)
	end
end

-- Whether a Soirée weekend is on, and which room it's in, for every screen (the music leans into
-- it). Its countdown is written on the Foyer's Tonight board (Boards).
local function drawCountdown()
	local weekend = Soiree.at()
	Workspace:SetAttribute("SoireeActive", weekend.active)
	Workspace:SetAttribute("SoireeFormat", weekend.format)
end

function SoireeService.start()
	Profiles.Loaded:Connect(function(player: Player)
		task.spawn(claim, player)
	end)
	task.spawn(function()
		while true do
			drawCountdown()
			refreshBoard()
			task.wait(30)
		end
	end)
	Players.PlayerRemoving:Connect(function() end)
end

return SoireeService

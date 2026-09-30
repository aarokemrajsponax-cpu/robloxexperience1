--!strict
-- Leaderboards: per room all-time (ordered data store) and this week (memory-store sorted map),
-- and tonight's Nightly (memory-store sorted map, ties to the earlier finish). Display names come
-- from Roblox. The Tonight board in the Foyer is drawn from the same cache.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Nightly = require(ReplicatedStorage.Shared.Nightly)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Voice = require(ReplicatedStorage.Shared.Voice)

local Boards = {}

export type Entry = { userId: number, name: string, score: number }
export type Board = { entries: { Entry }, available: boolean, count: number? }
export type Standing = { rank: number?, total: number?, percentile: number? }

local cache: { [string]: Board } = {}
for _, id in Rooms.order do
	cache[id .. ":week"] = { entries = {}, available = false }
	cache[id .. ":all"] = { entries = {}, available = false }
end
cache["nightly:tonight"] = { entries = {}, available = false, count = 0 }
cache["library:all"] = { entries = {}, available = false }
cache["ballroom:week"] = { entries = {}, available = false }
cache["ballroom:all"] = { entries = {}, available = false }
-- Lights Out results from every server, newest first (§9.8): "Table 12 kept the last lamp..."
cache["ballroom:feed"] = { entries = {}, available = true }
local FEED_TOPIC = "MaisonBallroomResults"
local FEED_KEEP = 8

local names: { [number]: string } = {}
local tonightKey = Nightly.at().key
-- Tonight's scores kept on this server too, so the board works even without memory stores.
local localNightly: { [number]: { score: number, sortKey: number } } = {}

local WEEK_SECONDS = 7 * 24 * 3600

-- Weeks start Monday 00:00 UTC. Unix day 0 was a Thursday.
local function weekIndex(): number
	local day = math.floor(os.time() / 86400)
	return math.floor((day + 3) / 7)
end

local function allTimeStore(room: string): OrderedDataStore?
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(Config.data.Boards.storePrefix .. room .. "_all")
	end)
	return if ok then store else nil
end

local function weekMap(room: string): MemoryStoreSortedMap?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(Config.data.Boards.storePrefix .. room .. "_week_" .. weekIndex())
	end)
	return if ok then map else nil
end

local function nightlyMap(key: string): MemoryStoreSortedMap?
	local ok, map = pcall(function()
		return MemoryStoreService:GetSortedMap(Config.data.Boards.storePrefix .. "nightly_" .. key)
	end)
	return if ok then map else nil
end

local function resolveNames(ids: { number })
	local missing = {}
	for _, id in ids do
		if names[id] == nil then
			local online = Players:GetPlayerByUserId(id)
			if online then
				names[id] = online.DisplayName
			else
				table.insert(missing, id)
			end
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return UserService:GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and infos then
		for _, info in infos do
			names[info.Id] = info.DisplayName
		end
	end
end

local function merge(key: string, entry: Entry, limit: number?)
	local board = cache[key]
	if not board then
		return
	end
	local found = false
	for _, e in board.entries do
		if e.userId == entry.userId then
			e.score = math.max(e.score, entry.score)
			e.name = entry.name
			found = true
		end
	end
	if not found then
		table.insert(board.entries, entry)
	end
	table.sort(board.entries, function(a, b)
		return a.score > b.score
	end)
	while #board.entries > (limit or Config.data.Boards.top) do
		table.remove(board.entries)
	end
end

local function line(parent: Instance, order: number, text: string, height: number, font: Font, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, height, 0)
	l.FontFace = font
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = parent
	return l
end

local function row(parent: Instance, order: number, rank: number, name: string, score: number, height: number)
	local r = line(parent, order, "", height, Brand.Fonts.body, Brand.Colours.bone)
	local left = Instance.new("TextLabel")
	left.BackgroundTransparency = 1
	left.Size = UDim2.new(0.72, 0, 1, 0)
	left.FontFace = Brand.Fonts.display
	left.TextScaled = true
	left.TextXAlignment = Enum.TextXAlignment.Left
	left.TextColor3 = if rank == 1 then Brand.Colours.lightGold else Brand.Colours.bone
	left.Text = Voice.roman(rank) .. "   " .. name
	left.Parent = r
	local right = Instance.new("TextLabel")
	right.BackgroundTransparency = 1
	right.Position = UDim2.new(0.72, 0, 0, 0)
	right.Size = UDim2.new(0.28, 0, 1, 0)
	right.FontFace = Brand.Fonts.bodyMedium
	right.TextScaled = true
	right.TextXAlignment = Enum.TextXAlignment.Right
	right.TextColor3 = Brand.Colours.smoke
	right.Text = string.format("%d", score)
	right.Parent = r
end

local function drawTonight()
	for _, face in CollectionService:GetTagged("MaisonBoard") do
		if face:IsA("BasePart") and face:GetAttribute("Kind") == "tonight" then
			local old = face:FindFirstChild("TonightGui")
			if old then
				old:Destroy()
			end
			local g = Instance.new("SurfaceGui")
			g.Name = "TonightGui"
			g.Face = Enum.NormalId.Front
			g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			g.PixelsPerStud = 44
			g.LightInfluence = 0.5
			g.Brightness = 1.3
			g.MaxDistance = 110
			g.Parent = face
			local list = Instance.new("UIListLayout")
			list.SortOrder = Enum.SortOrder.LayoutOrder
			list.HorizontalAlignment = Enum.HorizontalAlignment.Center
			list.Padding = UDim.new(0.01, 0)
			list.Parent = g
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0.04, 0)
			pad.PaddingLeft = UDim.new(0.07, 0)
			pad.PaddingRight = UDim.new(0.07, 0)
			pad.Parent = g
			local order = 0
			local function next(): number
				order += 1
				return order
			end
			local night = Nightly.at()
			local room = Rooms.get(night.room)
			line(g, next(), Voice.Foyer.tonight, 0.07, Brand.Fonts.display, Brand.Colours.gold)
			line(g, next(), "Tonight's table · " .. (if room then room.name else "") .. " rules", 0.04, Brand.Fonts.body, Brand.Colours.smoke)
			local nightly = cache["nightly:tonight"]
			local count = nightly.count or #nightly.entries
			line(g, next(), if count == 1 then "One guest has sat it so far" elseif count > 1 then string.format("%d guests have sat it so far", count) else "Nobody has sat it yet tonight", 0.032, Brand.Fonts.body, Brand.Colours.dim)
			for i = 1, math.min(5, #nightly.entries) do
				local e = nightly.entries[i]
				row(g, next(), i, e.name, e.score, 0.05)
			end
			local rule = Instance.new("Frame")
			rule.LayoutOrder = next()
			rule.Size = UDim2.new(0.5, 0, 0, 2)
			rule.BackgroundColor3 = Brand.Colours.deepGold
			rule.BorderSizePixel = 0
			rule.Parent = g
			local feed = cache["ballroom:feed"].entries
			if #feed > 0 then
				line(g, next(), "In the house, just now", 0.04, Brand.Fonts.body, Brand.Colours.smoke)
				for i = 1, math.min(2, #feed) do
					line(g, next(), feed[i].name, 0.036, Brand.Fonts.display, Brand.Colours.bone)
				end
				local rule2 = Instance.new("Frame")
				rule2.LayoutOrder = next()
				rule2.Size = UDim2.new(0.5, 0, 0, 2)
				rule2.BackgroundColor3 = Brand.Colours.deepGold
				rule2.BorderSizePixel = 0
				rule2.Parent = g
			end
			line(g, next(), "The Salon · this week", 0.04, Brand.Fonts.body, Brand.Colours.smoke)
			local week = cache["salon:week"]
			if #week.entries == 0 then
				line(g, next(), if week.available then "The first names of the week are still at the tables." else "Names appear here once the house is open to guests.", 0.05, Brand.Fonts.body, Brand.Colours.dim)
			else
				for i = 1, math.min(5, #week.entries) do
					local e = week.entries[i]
					row(g, next(), i, e.name, e.score, 0.05)
				end
			end
		end
	end
end

local function publish()
	drawTonight()
	Remotes.event("Board"):FireAllClients(cache)
end

local function refreshRoom(room: string)
	local all = allTimeStore(room)
	if all then
		local ok, pages = pcall(function()
			return all:GetSortedAsync(false, Config.data.Boards.top)
		end)
		if ok and pages then
			local page = pages:GetCurrentPage()
			local ids = {}
			for _, item in page do
				table.insert(ids, tonumber(item.key) or 0)
			end
			resolveNames(ids)
			local entries = {}
			for _, item in page do
				local id = tonumber(item.key) or 0
				table.insert(entries, { userId = id, name = names[id] or "A guest", score = item.value })
			end
			cache[room .. ":all"] = { entries = entries, available = true }
		end
	end
	local week = weekMap(room)
	if week then
		local ok, items = pcall(function()
			return week:GetRangeAsync(Enum.SortDirection.Descending, Config.data.Boards.top)
		end)
		if ok and items then
			local ids = {}
			for _, item in items do
				table.insert(ids, tonumber(item.key) or 0)
			end
			resolveNames(ids)
			local entries = {}
			for _, item in items do
				local id = tonumber(item.key) or 0
				local score = if type(item.sortKey) == "number" then item.sortKey else (tonumber(item.value) or 0)
				table.insert(entries, { userId = id, name = names[id] or "A guest", score = score })
			end
			cache[room .. ":week"] = { entries = entries, available = true }
		end
	end
end

local function refreshNightly()
	local night = Nightly.at()
	if night.key ~= tonightKey then
		-- Midnight UTC: a new table for everyone.
		tonightKey = night.key
		localNightly = {}
		cache["nightly:tonight"] = { entries = {}, available = false, count = 0 }
		Workspace:SetAttribute("NightlyKey", night.key)
		Workspace:SetAttribute("NightlyRoom", night.room)
	end
	local map = nightlyMap(night.key)
	if not map then
		return
	end
	local ok, items = pcall(function()
		return map:GetRangeAsync(Enum.SortDirection.Descending, Config.data.Boards.top)
	end)
	local okSize, size = pcall(function()
		return map:GetSizeAsync()
	end)
	if ok and items then
		local ids = {}
		for _, item in items do
			table.insert(ids, tonumber(item.key) or 0)
		end
		resolveNames(ids)
		local entries = {}
		for _, item in items do
			local id = tonumber(item.key) or 0
			local sortKey = if type(item.sortKey) == "number" then item.sortKey else 0
			table.insert(entries, { userId = id, name = names[id] or "A guest", score = Nightly.scoreFromSortKey(sortKey) })
		end
		cache["nightly:tonight"] = { entries = entries, available = true, count = if okSize then size else #entries }
	end
end

-- Records a banked run. Keeps each guest's best on both boards.
function Boards.submit(player: Player, room: string, score: number)
	if score <= 0 then
		return
	end
	names[player.UserId] = player.DisplayName
	local entry = { userId = player.UserId, name = player.DisplayName, score = score }
	merge(room .. ":week", entry)
	merge(room .. ":all", entry)
	publish()
	task.spawn(function()
		local all = allTimeStore(room)
		if all then
			pcall(function()
				all:UpdateAsync(tostring(player.UserId), (function(old: number?): number?
					if old and old >= score then
						return nil
					end
					return math.floor(score)
				end :: any))
			end)
		end
		local week = weekMap(room)
		if week then
			pcall(function()
				week:UpdateAsync(tostring(player.UserId), function(_old: any, oldSort: any)
					if type(oldSort) == "number" and oldSort >= score then
						return nil
					end
					return tostring(math.floor(score)), math.floor(score)
				end, WEEK_SECONDS + 86400)
			end)
		end
	end)
end

-- Records a Library rating (ratings go down as well as up, so this sets rather than keeps the best).
function Boards.submitRating(player: Player, rating: number)
	names[player.UserId] = player.DisplayName
	local value = math.floor(rating + 0.5)
	local board = cache["library:all"]
	for i = #board.entries, 1, -1 do
		if board.entries[i].userId == player.UserId then
			table.remove(board.entries, i)
		end
	end
	merge("library:all", { userId = player.UserId, name = player.DisplayName, score = value })
	publish()
	task.spawn(function()
		local store = allTimeStore("library")
		if store then
			pcall(function()
				store:SetAsync(tostring(player.UserId), value)
			end)
		end
	end)
end

-- Records a scored Nightly attempt and returns where it stands tonight. Flagged results are
-- kept off the public board until reviewed.
function Boards.submitNightly(player: Player, key: string, score: number, finishedAt: number, flagged: boolean): Standing
	names[player.UserId] = player.DisplayName
	local sortKey = Nightly.sortKey(score, finishedAt)
	localNightly[player.UserId] = { score = score, sortKey = sortKey }
	if not flagged and key == tonightKey then
		merge("nightly:tonight", { userId = player.UserId, name = player.DisplayName, score = score }, Config.data.Nightly.boardTop)
		local board = cache["nightly:tonight"]
		board.count = math.max(board.count or 0, #board.entries)
		publish()
	end
	local map = nightlyMap(key)
	local standing: Standing = {}
	if map and not flagged then
		local okSet = pcall(function()
			map:SetAsync(tostring(player.UserId), tostring(score), Config.data.Nightly.boardHours * 3600, sortKey)
		end)
		if okSet then
			local okAbove, above = pcall(function()
				return map:GetRangeAsync(Enum.SortDirection.Descending, 200, { key = tostring(player.UserId), sortKey = sortKey }, nil)
			end)
			local okSize, size = pcall(function()
				return map:GetSizeAsync()
			end)
			if okAbove and okSize and size > 0 then
				local rank = #above + 1
				standing.rank = if #above < 200 then rank else nil
				standing.total = size
				standing.percentile = math.clamp(math.ceil(rank / size * 100), 1, 100)
				local board = cache["nightly:tonight"]
				board.count = math.max(board.count or 0, size)
				return standing
			end
		end
	end
	-- Fall back to this server's own guests tonight.
	local total, above = 0, 0
	for _, e in localNightly do
		total += 1
		if e.sortKey > sortKey then
			above += 1
		end
	end
	standing.rank = above + 1
	standing.total = total
	standing.percentile = math.clamp(math.ceil((above + 1) / math.max(1, total) * 100), 1, 100)
	return standing
end

-- Your place among your Roblox connections who sat tonight's table: { place, of } or nil.
function Boards.nightlyConnections(player: Player, key: string, score: number): { place: number, of: number }?
	local ok, pages = pcall(function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not ok or not pages then
		return nil
	end
	local friends: { number } = {}
	local limit = Config.data.Nightly.connectionsChecked
	pcall(function()
		while #friends < limit do
			for _, f in pages:GetCurrentPage() do
				table.insert(friends, f.Id)
				if #friends >= limit then
					break
				end
			end
			if pages.IsFinished or #friends >= limit then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if #friends == 0 then
		return nil
	end
	local map = nightlyMap(key)
	local played, better = 0, 0
	for _, id in friends do
		local s: number? = nil
		local mine = localNightly[id]
		if mine then
			s = mine.score
		elseif map then
			local okGet, value = pcall(function()
				return map:GetAsync(tostring(id))
			end)
			if okGet and value then
				s = tonumber(value)
			end
		end
		if s then
			played += 1
			if s > score then
				better += 1
			end
		end
	end
	if played == 0 then
		return nil
	end
	return { place = better + 1, of = played + 1 }
end

-- Every scored attempt keeps its input log (seeds and timed filings) for replay and review.
function Boards.saveNightlyLog(player: Player, key: string, log: { { any } })
	pcall(function()
		local store = DataStoreService:GetDataStore("MaisonNoir_NightlyLogs")
		store:SetAsync(key .. "/" .. player.UserId, { log = log, savedAt = os.time() }, { player.UserId })
	end)
end

local WORDS = { "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve" }

-- "Table 12 kept the last lamp with nine Keys."
function Boards.resultLine(tableNumber: number, keys: number): string
	local k = if keys == 0 then "no Keys" elseif keys == 1 then "one Key" else (WORDS[keys] or tostring(keys)) .. " Keys"
	return string.format("Table %d kept the last lamp with %s.", tableNumber, k)
end

local function addFeed(text: string)
	local entries = cache["ballroom:feed"].entries
	if entries[1] and entries[1].name == text then
		return
	end
	table.insert(entries, 1, { userId = 0, name = text, score = 0 })
	while #entries > FEED_KEEP do
		table.remove(entries)
	end
	publish()
end

-- News for the Tonight board from every server (a Mythic found).
function Boards.announce(text: string)
	addFeed(text)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(FEED_TOPIC, { text = text, at = os.time() })
		end)
	end)
end

-- A Lights Out evening has ended: post it here at once and to every other server.
function Boards.ballroomResult(tableNumber: number, _name: string, keys: number)
	local text = Boards.resultLine(tableNumber, keys)
	addFeed(text)
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(FEED_TOPIC, { text = text, at = os.time() })
		end)
	end)
end

function Boards.get(): { [string]: Board }
	return cache
end

function Boards.start()
	local night = Nightly.at()
	Workspace:SetAttribute("NightlyKey", night.key)
	Workspace:SetAttribute("NightlyRoom", night.room)
	local lastAsk: { [Player]: number } = {}
	Remotes.func("GetBoard").OnServerInvoke = function(player: Player)
		local now = os.clock()
		if lastAsk[player] and now - lastAsk[player] < 1 then
			return cache
		end
		lastAsk[player] = now
		return cache
	end
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
	drawTonight()
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(FEED_TOPIC, function(message: any)
				local data = message and message.Data
				if type(data) == "table" and type(data.text) == "string" and #data.text <= 80 then
					addFeed(data.text)
				end
			end)
		end)
	end)
	task.spawn(function()
		while true do
			for _, id in Rooms.order do
				refreshRoom(id)
			end
			refreshRoom("library")
			refreshRoom("ballroom")
			refreshNightly()
			publish()
			task.wait(Config.data.Boards.refreshSeconds)
		end
	end)
	-- Midnight UTC turns the table even between refreshes.
	task.spawn(function()
		while true do
			task.wait(20)
			if Nightly.at().key ~= tonightKey then
				refreshNightly()
				publish()
			end
		end
	end)
end

return Boards

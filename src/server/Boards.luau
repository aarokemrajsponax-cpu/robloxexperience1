--!strict
-- Leaderboards: all-time in an ordered data store, this week in a memory-store sorted map.
-- Display names come from Roblox. The Tonight board in the Foyer is drawn from the same cache.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserService = game:GetService("UserService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Voice = require(ReplicatedStorage.Shared.Voice)

local Boards = {}

export type Entry = { userId: number, name: string, score: number }
export type Board = { entries: { Entry }, available: boolean }

local cache: { [string]: Board } = {
	["salon:week"] = { entries = {}, available = false },
	["salon:all"] = { entries = {}, available = false },
}
local names: { [number]: string } = {}

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

local function merge(key: string, entry: Entry)
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
	while #board.entries > Config.data.Boards.top do
		table.remove(board.entries)
	end
end

local function drawTonight()
	for _, face in CollectionService:GetTagged("MaisonBoard") do
		if face:IsA("BasePart") and face:GetAttribute("Kind") == "tonight" then
			local gui = face:FindFirstChild("TonightGui")
			if gui then
				gui:Destroy()
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
			list.Padding = UDim.new(0.012, 0)
			list.Parent = g
			local pad = Instance.new("UIPadding")
			pad.PaddingTop = UDim.new(0.05, 0)
			pad.PaddingLeft = UDim.new(0.07, 0)
			pad.PaddingRight = UDim.new(0.07, 0)
			pad.Parent = g
			local order = 0
			local function line(text: string, height: number, font: Font, color: Color3, align: Enum.TextXAlignment?)
				order += 1
				local l = Instance.new("TextLabel")
				l.LayoutOrder = order
				l.BackgroundTransparency = 1
				l.Size = UDim2.new(1, 0, height, 0)
				l.FontFace = font
				l.TextScaled = true
				l.TextColor3 = color
				l.TextXAlignment = align or Enum.TextXAlignment.Center
				l.Text = text
				l.Parent = g
				return l
			end
			line(Voice.Foyer.tonight, 0.075, Brand.Fonts.display, Brand.Colours.gold)
			line("The Salon · this week", 0.04, Brand.Fonts.body, Brand.Colours.smoke)
			local rule = Instance.new("Frame")
			order += 1
			rule.LayoutOrder = order
			rule.Size = UDim2.new(0.5, 0, 0, 2)
			rule.BackgroundColor3 = Brand.Colours.deepGold
			rule.BorderSizePixel = 0
			rule.Parent = g
			local board = cache["salon:week"]
			if #board.entries == 0 then
				line(if board.available then "The first names of the week are still at the tables." else "Names appear here once the house is open to guests.", 0.07, Brand.Fonts.body, Brand.Colours.dim)
			else
				for i, e in board.entries do
					local row = line("", 0.058, Brand.Fonts.body, Brand.Colours.bone)
					row.Text = ""
					local left = Instance.new("TextLabel")
					left.BackgroundTransparency = 1
					left.Size = UDim2.new(0.72, 0, 1, 0)
					left.FontFace = Brand.Fonts.display
					left.TextScaled = true
					left.TextXAlignment = Enum.TextXAlignment.Left
					left.TextColor3 = if i == 1 then Brand.Colours.lightGold else Brand.Colours.bone
					left.Text = Voice.roman(i) .. "   " .. e.name
					left.Parent = row
					local right = Instance.new("TextLabel")
					right.BackgroundTransparency = 1
					right.Position = UDim2.new(0.72, 0, 0, 0)
					right.Size = UDim2.new(0.28, 0, 1, 0)
					right.FontFace = Brand.Fonts.bodyMedium
					right.TextScaled = true
					right.TextXAlignment = Enum.TextXAlignment.Right
					right.TextColor3 = Brand.Colours.smoke
					right.Text = string.format("%d", e.score)
					right.Parent = row
				end
			end
		end
	end
end

local function publish()
	drawTonight()
	Remotes.event("Board"):FireAllClients(cache)
end

local function refresh(room: string)
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
				week:UpdateAsync(tostring(player.UserId), function(old: any, oldSort: any)
					if type(oldSort) == "number" and oldSort >= score then
						return nil
					end
					return tostring(math.floor(score)), math.floor(score)
				end, WEEK_SECONDS + 86400)
			end)
		end
	end)
end

function Boards.get(): { [string]: Board }
	return cache
end

function Boards.start()
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
		while true do
			refresh("salon")
			publish()
			task.wait(Config.data.Boards.refreshSeconds)
		end
	end)
end

return Boards

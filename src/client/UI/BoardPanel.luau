--!strict
-- The leaderboard: the Salon this week and all time, in engraved type. Display names only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local BoardPanel = {}

local NAME = "Leaderboard"
local cache: { [string]: any } = {}

Remotes.event("Board").OnClientEvent:Connect(function(boards: any)
	if type(boards) == "table" then
		cache = boards
	end
end)

local function fill(list: Frame, key: string)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local board = cache[key]
	local me = Players.LocalPlayer.UserId
	if not board or #board.entries == 0 then
		local text = if board and board.available then "No names yet. The first run banked here takes the top line." else "Names appear here once the house is open to guests."
		Theme.text(list, text, 15, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })
		return
	end
	for i, e in board.entries do
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 30)
		row.LayoutOrder = i
		row.Parent = list
		local mine = e.userId == me
		Theme.text(row, Voice.roman(i), 14, "display", {
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0, 44, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Brand.Colours.gold,
		})
		Theme.text(row, tostring(e.name), 17, "display", {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(46, 0),
			Size = UDim2.new(0.62, -46, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextWrapped = false,
			TextColor3 = if mine then Brand.Colours.lightGold else Brand.Colours.bone,
		})
		Theme.text(row, string.format("%d", e.score), 15, "bodyMedium", {
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.new(0.62, 0, 0, 0),
			Size = UDim2.new(0.38, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = Brand.Colours.smoke,
		})
	end
end

function BoardPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	task.spawn(function()
		local ok, boards = pcall(function()
			return Remotes.func("GetBoard"):InvokeServer()
		end)
		if ok and type(boards) == "table" then
			cache = boards
		end
	end)
	local size = Root.size()
	local w = math.min(500, size.X - 24)
	local h = math.min(560, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 10).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Salon", 26, "display", { LayoutOrder = 1 })
	Theme.hairline(content, UDim.new(0, 90), 2)

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Size = UDim2.new(1, 0, 0, 40)
	tabs.LayoutOrder = 3
	tabs.Parent = content
	Theme.list(tabs, 8, true)

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 1, -(26 + 12 + 40 + 44 + 50))
	list.LayoutOrder = 4
	list.Parent = content
	Theme.list(list, 2).VerticalAlignment = Enum.VerticalAlignment.Top

	local showing = "salon:week"
	local weekKey, allKey
	local function select(key: string)
		showing = key
		fill(list, key)
		weekKey.BackgroundTransparency = if key == "salon:week" then 0.08 else 0.3
		allKey.BackgroundTransparency = if key == "salon:all" then 0.08 else 0.3
	end
	weekKey = Theme.key(tabs, "This week", false, function()
		select("salon:week")
	end, 150)
	allKey = Theme.key(tabs, "All time", false, function()
		select("salon:all")
	end, 150)
	select(showing)
	local conn = Remotes.event("Board").OnClientEvent:Connect(function()
		task.defer(function()
			if list.Parent then
				fill(list, showing)
			end
		end)
	end)

	local close = Theme.key(content, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 5
	Root.open(NAME, group, function()
		conn:Disconnect()
	end)
end

return BoardPanel

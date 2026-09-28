--!strict
-- The leaderboard: tonight's Nightly, and every room this week and all time, in engraved type.
-- Display names only.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
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

local BOARDS = {
	{ id = "nightly", label = "Tonight" },
	{ id = "salon", label = "Salon" },
	{ id = "velvet", label = "Velvet" },
	{ id = "obsidian", label = "Obsidian" },
	{ id = "midnight", label = "Midnight" },
}

local function fill(list: Frame, key: string)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local board = cache[key]
	local me = Players.LocalPlayer.UserId
	if not board or #board.entries == 0 then
		local text = if board and board.available then "No names yet. The first result here takes the top line." else "Names appear here once the house is open to guests."
		Theme.text(list, text, 15, "body", { LayoutOrder = 1, TextColor3 = Brand.Colours.dim })
		return
	end
	for i, e in board.entries do
		if i > 10 then
			break
		end
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
	if key == "nightly:tonight" and board.count and board.count > 0 then
		Theme.text(list, string.format("%d guests have sat tonight's table", board.count), 12, "body", { LayoutOrder = 50, TextColor3 = Brand.Colours.dim })
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
	local w = math.min(540, size.X - 24)
	local h = math.min(600, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	local title = Theme.text(content, "Tonight's table", 24, "display", { LayoutOrder = 1 })
	Theme.hairline(content, UDim.new(0, 90), 2)

	local boardRow = Instance.new("ScrollingFrame")
	boardRow.BackgroundTransparency = 1
	boardRow.BorderSizePixel = 0
	boardRow.Size = UDim2.new(1, 0, 0, 44)
	boardRow.CanvasSize = UDim2.new()
	boardRow.AutomaticCanvasSize = Enum.AutomaticSize.X
	boardRow.ScrollingDirection = Enum.ScrollingDirection.X
	boardRow.ScrollBarThickness = 0
	boardRow.LayoutOrder = 3
	boardRow.Parent = content
	local rowList = Theme.list(boardRow, 6, true)
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Left

	local periodRow = Instance.new("Frame")
	periodRow.BackgroundTransparency = 1
	periodRow.Size = UDim2.new(1, 0, 0, 40)
	periodRow.LayoutOrder = 4
	periodRow.Parent = content
	Theme.list(periodRow, 8, true)

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 1, -(24 + 12 + 44 + 40 + 44 + 60))
	list.LayoutOrder = 5
	list.Parent = content
	Theme.list(list, 2).VerticalAlignment = Enum.VerticalAlignment.Top

	local board = "nightly"
	local period = "week"
	local boardKeys: { [string]: TextButton } = {}
	local weekKey: TextButton? = nil
	local allKey: TextButton? = nil

	local function key(): string
		return if board == "nightly" then "nightly:tonight" else board .. ":" .. period
	end
	local function render()
		for id, k in boardKeys do
			k.BackgroundTransparency = if id == board then 0.05 else 0.3
		end
		periodRow.Visible = board ~= "nightly"
		if weekKey and allKey then
			weekKey.BackgroundTransparency = if period == "week" then 0.05 else 0.3
			allKey.BackgroundTransparency = if period == "all" then 0.05 else 0.3
		end
		local room = Rooms.get(board)
		title.Text = if board == "nightly" then "Tonight's table" else (if room then room.name else board)
		fill(list, key())
	end
	for i, b in BOARDS do
		local k = Theme.key(boardRow, b.label, false, function()
			board = b.id
			render()
		end, 96)
		k.LayoutOrder = i
		boardKeys[b.id] = k
	end
	weekKey = Theme.key(periodRow, "This week", false, function()
		period = "week"
		render()
	end, 150)
	allKey = Theme.key(periodRow, "All time", false, function()
		period = "all"
		render()
	end, 150)
	render()
	local conn = Remotes.event("Board").OnClientEvent:Connect(function()
		task.defer(function()
			if list.Parent then
				fill(list, key())
			end
		end)
	end)

	local close = Theme.key(content, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 6
	Root.open(NAME, group, function()
		conn:Disconnect()
	end)
end

return BoardPanel

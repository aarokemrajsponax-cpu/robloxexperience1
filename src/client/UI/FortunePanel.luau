--!strict
-- The Fortune screen: the house's aim in one place. Your Fortune and wealth rank (and how far to
-- the next), what it's made of (Gilt, Gems, your collection, your Suite and wardrobe, your
-- Estate), and the Wealthiest boards: this house now, this week's gain, and all time. Every figure
-- is the server's (EmpireAsk "fortune"). The boards rank what was earned: Gilt and Gems bought with
-- Robux aren't counted there, and the screen says so.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local FortunePanel = {}

local NAME = "Fortune"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local player = Players.LocalPlayer

local PARTS = {
	{ key = "gilt", label = "Gilt in your purse" },
	{ key = "gems", label = "Gems" },
	{ key = "collection", label = "Your collection (brainrots and curios)" },
	{ key = "suite", label = "Your Suite and wardrobe" },
	{ key = "estate", label = "Your Estate (hauls, chests and auctions)" },
}

local function row(parent: Instance, order: number, left: string, right: string, strong: boolean?, colour: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 24)
	f.LayoutOrder = order
	f.Parent = parent
	local l = Theme.text(f, left, 14, if strong then "bodyBold" else "body", { Name = "Left", TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -120, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = colour or C.bone })
	l.Position = UDim2.fromOffset(0, 0)
	local r = Theme.text(f, right, 14, "bodyBold", { Name = "Right", TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(0, 116, 1, 0), AutomaticSize = Enum.AutomaticSize.None, TextWrapped = false, TextColor3 = colour or C.lightGold })
	r.AnchorPoint = Vector2.new(1, 0)
	r.Position = UDim2.new(1, 0, 0, 0)
	return f
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function FortunePanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local w = Root.panelWidth(520)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 600))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "Your Fortune", 11, "caps", { LayoutOrder = 1 })
	local total = tonumber(player:GetAttribute("Fortune")) or 0
	local figure = Theme.text(content, Rules.format(total), 34, "display", { LayoutOrder = 2 })
	local rankLine = Theme.text(content, "", 14, "bodyBold", { LayoutOrder = 3, TextColor3 = GOLD })
	local nextLine = Theme.text(content, "", 13, "body", { LayoutOrder = 4, TextColor3 = C.smoke })
	Theme.text(content, Rules.TAGLINE, 11, "caps", { LayoutOrder = 5, TextColor3 = C.lightGold })
	Theme.hairline(content, UDim.new(0, 120), 6)

	local made = Instance.new("Frame")
	made.Name = "Parts"
	made.BackgroundTransparency = 1
	made.AutomaticSize = Enum.AutomaticSize.Y
	made.Size = UDim2.new(1, 0, 0, 0)
	made.LayoutOrder = 7
	made.Parent = content
	Theme.list(made, 0).VerticalAlignment = Enum.VerticalAlignment.Top

	local board = "here"
	local boardRows = Instance.new("Frame")
	boardRows.Name = "Board"
	boardRows.BackgroundTransparency = 1
	boardRows.AutomaticSize = Enum.AutomaticSize.Y
	boardRows.Size = UDim2.new(1, 0, 0, 0)
	boardRows.LayoutOrder = 10
	boardRows.Parent = content
	Theme.list(boardRows, 0).VerticalAlignment = Enum.VerticalAlignment.Top
	local note = Theme.text(content, "The boards rank what you've earned: Gilt and Gems bought with Robux aren't counted.", 12, "body", { LayoutOrder = 11, TextColor3 = C.smoke })

	local view: { [string]: any }? = nil
	local function headline()
		local rank, _, nextRank = Rules.rank(total)
		figure.Text = Rules.format(total)
		rankLine.Text = string.upper(rank.name) .. "  ·  " .. rank.line
		nextLine.Text = if nextRank then string.format("%s more to become %s", Rules.format(nextRank.at - total), nextRank.name) else "The highest rank there is."
	end
	local function fillBoard()
		clear(boardRows)
		local v = view
		local entries = v and v.boards and v.boards[board]
		if type(entries) ~= "table" or #entries == 0 then
			Theme.text(boardRows, if v then (if board == "here" then "Nobody here is showing a Fortune yet." else "The board is being written up. Earn something and it will have you.") else "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
			return
		end
		for i, e in entries do
			if i > 10 then
				break
			end
			local mine = e.userId == player.UserId
			row(boardRows, i, string.format("%d.  %s", i, tostring(e.name)), Rules.short(tonumber(e.score) or 0), mine, if mine then GOLD else nil)
		end
	end
	local function fill()
		local v = view
		if not v then
			return
		end
		total = tonumber(v.total) or total
		headline()
		clear(made)
		for i, p in PARTS do
			local amount = tonumber(v.parts and v.parts[p.key]) or 0
			row(made, i, p.label, Rules.format(amount))
		end
		note.Text = if v.shown == false then "You've chosen not to show your Fortune: you're left off the boards (Settings, The Club)." else "The boards rank what you've earned: Gilt and Gems bought with Robux aren't counted."
		fillBoard()
	end
	headline()

	Theme.text(content, "The Wealthiest", 18, "display", { LayoutOrder = 8 })
	local tabs = Theme.tabs(content, { { "here", "In this house" }, { "week", "This week" }, { "all", "All time" } }, board, function(id: string)
		board = id
		fillBoard()
	end, 9)
	tabs.select(board)
	fillBoard()

	local close = Theme.key(content, "Close", true, function()
		Root.close(NAME)
	end, 200)
	close.LayoutOrder = 20
	Root.open(NAME, group)
	task.spawn(function()
		local ok, got = pcall(function()
			return Remotes.func("EmpireAsk"):InvokeServer({ op = "fortune" })
		end)
		if ok and type(got) == "table" and got.ok == true and group.Parent then
			view = got
			fill()
		end
	end)
end

function FortunePanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

return FortunePanel

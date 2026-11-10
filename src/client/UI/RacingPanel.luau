--!strict
-- The racing card (the Records key at the wheel, or the Racing Club's board on the street): your
-- racing rank and points and what the next rank brings; each circuit's records (your best, the
-- Lap Ace mark, and the fastest of all time, of this week, and among your friends); and Join the
-- next race, which takes you to a free car and onto the grid from anywhere. Every time and rank
-- is the server's (RacingAsk "card"); every lap was timed by the server's own clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tracks = require(ReplicatedStorage.Shared.Tracks)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local RacingPanel = {}

local NAME = "RacingCard"
local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local MINE = Color3.fromRGB(120, 220, 150)

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("RacingAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- A board's row: place, name, time (yours in green).
local function boardRow(parent: Instance, order: number, place: number, name: string, time: number, mine: boolean)
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, 22)
	f.LayoutOrder = order
	f.Parent = parent
	local colour = if mine then MINE elseif place == 1 then GOLD else C.bone
	Theme.text(f, string.format("%d.  %s", place, name), 13, if mine or place == 1 then "bodyBold" else "body", { TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = colour, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, -90, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	local t = Theme.text(f, Tracks.clock(time), 13, "bodyBold", { TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = colour, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(0, 86, 1, 0) })
	t.AnchorPoint = Vector2.new(1, 0)
	t.Position = UDim2.new(1, 0, 0, 0)
end

function RacingPanel.open()
	if Root.isOpen(NAME) then
		return
	end
	local size = Root.size()
	local w = Root.panelWidth(560)
	local h = math.min(660, size.Y - 40)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Grand Prix", 11, "caps", { LayoutOrder = 1 })
	Theme.text(content, "Records & Ranks", 26, "display", { LayoutOrder = 2 })
	local rankLine = Theme.text(content, "One moment.", 14, "bodyBold", { LayoutOrder = 3, TextColor3 = GOLD })
	local rankNote = Theme.text(content, "", 12, "body", { LayoutOrder = 4, TextColor3 = C.smoke, TextWrapped = true })
	local trackId = "boulevard"
	local boardId = "all"
	local card: { [string]: any }? = nil
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.LayoutOrder = 7
	body.Size = UDim2.new(1, 0, 0, 240)
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = C.gold
	body.Parent = content
	Theme.list(body, 4).VerticalAlignment = Enum.VerticalAlignment.Top
	local bpad = Instance.new("UIPadding")
	bpad.PaddingRight = UDim.new(0, 8)
	bpad.Parent = body

	local function fill()
		clear(body)
		local c = card
		if not c then
			Theme.text(body, "One moment.", 13, "body", { LayoutOrder = 1, TextColor3 = C.smoke })
			return
		end
		local track = nil
		for _, t in (if type(c.tracks) == "table" then c.tracks else {}) do
			if t.id == trackId then
				track = t
			end
		end
		if not track then
			return
		end
		Theme.text(body, tostring(track.line or ""), 12, "body", { LayoutOrder = 1, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
		local pb = tonumber(track.pb)
		Theme.text(body, string.format("Your best: %s  ·  Lap Ace under %s", if pb then Tracks.clock(pb) else "no timed lap yet", Tracks.clock(tonumber(track.ace) or 0)), 14, "bodyBold", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = if pb and pb < (tonumber(track.ace) or 0) then GOLD else C.bone })
		Theme.hairline(body, UDim.new(0, 120), 3)
		local list = if boardId == "week" then track.week elseif boardId == "friends" then track.friends else track.all
		if type(list) ~= "table" or #list == 0 then
			Theme.text(body, if boardId == "friends" then "None of your friends has a timed lap here yet. Be the first." else "Nobody's on this board yet. Drive a timed lap: cross the start line and keep to the road.", 13, "body", { LayoutOrder = 4, TextColor3 = C.smoke, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left })
			return
		end
		local me = (game:GetService("Players").LocalPlayer :: Player).UserId
		for i, e in list do
			boardRow(body, 3 + i, i, tostring(e.name), tonumber(e.time) or 0, e.userId == me)
		end
	end

	local trackTabs = Theme.tabs(content, { { "boulevard", "Grand Boulevard" }, { "coast", "Coastal Circuit" } }, trackId, function(id: string)
		trackId = id
		fill()
	end, 5)
	trackTabs.select(trackId)
	local boardTabs = Theme.tabs(content, { { "all", "All time" }, { "week", "This week" }, { "friends", "Friends" } }, boardId, function(id: string)
		boardId = id
		fill()
	end, 6)
	boardTabs.select(boardId)

	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 44)
	keys.LayoutOrder = 20
	keys.Parent = content
	local row = Theme.list(keys, 10, true)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local busy = false
	local join = Theme.key(keys, "Join the next race", true, function()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = ask({ op = "join" })
			busy = false
			if not r then
				Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
			elseif r.ok ~= true then
				Toast.show("The Grand Prix", tostring(r.why or "Not just now."), 3.5)
			else
				Root.close(NAME)
				Toast.show("On the grid", "You're in the next race: watch the lights over the line.", 3.5)
			end
		end)
	end, 220)
	join.LayoutOrder = 1
	local close = Theme.key(keys, "Close", false, function()
		Root.close(NAME)
	end, 140)
	close.LayoutOrder = 2
	fill()
	Theme.fillRest(body)
	Root.open(NAME, group)
	task.spawn(function()
		local r = ask({ op = "card" })
		if not group.Parent then
			return
		end
		if r and r.ok == true then
			card = r
			local next = if r.nextName then string.format("  ·  %d to %s", math.max(0, (tonumber(r.nextAt) or 0) - (tonumber(r.points) or 0)), tostring(r.nextName)) else "  ·  the highest rank"
			rankLine.Text = string.format("%s  ·  %d racing points%s", string.upper(tostring(r.rankName or "Rookie")), tonumber(r.points) or 0, next)
			rankNote.Text = string.format("%s Races: %d  ·  wins: %d. Points for every race (more on the podium), every timed lap and every new best.", tostring(r.rankLine or ""), tonumber(r.races) or 0, tonumber(r.wins) or 0)
			fill()
		else
			rankLine.Text = "The records couldn't be read just now."
			rankNote.Text = "Try again in a moment."
		end
	end)
end

function RacingPanel.isOpen(): boolean
	return Root.isOpen(NAME)
end

return RacingPanel

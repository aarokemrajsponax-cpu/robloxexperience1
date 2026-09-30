--!strict
-- The round summary (after the card lands) and the banked-run summary. The grade is drawn as a
-- stamped hallmark: a small bordered cartouche, not a font glyph.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Hallmark = require(script.Parent.Hallmark)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local State = require(script.Parent.Parent.State)
local Share = require(script.Parent.Share)

local RoundPanel = {}

local NAME = "Round"

local function line(parent: Instance, left: string, right: string, order: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.LayoutOrder = order
	row.Parent = parent
	Theme.text(row, left, 15, "body", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Brand.Colours.smoke,
	})
	Theme.text(row, right, 15, "bodyMedium", {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromScale(0.6, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Brand.Colours.bone,
	})
end

local function number(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
RoundPanel.number = number

export type Actions = { primary: string, onPrimary: () -> (), secondary: string?, onSecondary: (() -> ())?, onLeave: () -> () }

local function panel(heading: string, sub: string?, grade: string, rows: { { string } }, actions: Actions)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local size = Root.size()
	local w = math.min(420, size.X - 24)
	local h = 250 + #rows * 26 + (if actions.secondary then 54 else 0) + (if grade == "Flawless" then 52 else 0)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, h), UDim2.new(0.5, 0, 0.5, 20))
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	if sub then
		Theme.text(content, sub, 11, "caps", { LayoutOrder = 1 })
	end
	Theme.text(content, heading, 24, "display", { LayoutOrder = 2 })
	Hallmark.big(content, grade, 3)
	for i, r in rows do
		line(content, r[1], r[2], 3 + i)
	end
	local keys = Instance.new("Frame")
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 50
	keys.Parent = content
	Theme.list(keys, 8)
	Theme.key(keys, actions.primary, true, function()
		Root.close(NAME)
		actions.onPrimary()
	end, 260).LayoutOrder = 1
	if actions.secondary and actions.onSecondary then
		local onSecondary = actions.onSecondary
		Theme.key(keys, actions.secondary, false, function()
			Root.close(NAME)
			onSecondary()
		end, 260).LayoutOrder = 2
	end
	if grade == "Flawless" then
		Theme.key(keys, "Share", false, function()
			Share.moment("salon")
		end, 260).LayoutOrder = 3
	end
	Theme.key(keys, "Leave", false, function()
		Root.close(NAME)
		actions.onLeave()
	end, 260).LayoutOrder = 4
	-- Round cards don't blur the table: the felt stays in focus behind them.
	Root.open(NAME, group, nil, false)
	pcall(function()
		game:GetService("GuiService").SelectedObject = keys:FindFirstChildWhichIsA("TextButton")
	end)
end

function RoundPanel.round(message: { [string]: any }, actions: Actions)
	local rows: { { string } } = {}
	if message.bonus.perfect > 0 then
		table.insert(rows, { "No mistakes", "+" .. number(message.bonus.perfect) })
	end
	table.insert(rows, { "Best streak · " .. tostring(message.bestStreak), "+" .. number(message.bonus.streak) })
	if message.bonus.time > 0 then
		table.insert(rows, { "Time left", "+" .. number(message.bonus.time) })
	end
	table.insert(rows, { "The run so far", number(message.score) })
	local roundText = Voice.roundLabel(message.round, State.get("roundNumbers"))
	local room = Rooms.get(message.room or "salon")
	local sub = if message.mode and message.mode ~= "room" then "Tonight's table" else (if room then room.name else "")
	panel("Round " .. roundText, sub, message.grade, rows, actions)
end

function RoundPanel.banked(message: { [string]: any }, actions: Actions)
	local rows = {
		{ "The run", number(message.score) },
		{ "Rounds cleared", tostring(message.rounds) },
		{ "Accuracy", string.format("%d%%", math.floor((message.accuracy or 0) * 100 + 0.5)) },
	}
	if (message.gilt or 0) > 0 then
		table.insert(rows, { "Gilt", "+" .. number(message.gilt) })
	end
	if (message.best or 0) > 0 then
		table.insert(rows, { if message.newBest then "A new best" else "Your best here", number(message.best) })
	end
	local sub = if type(message.reason) == "string" and message.reason ~= "" then message.reason else "Banked to the board"
	panel("The run is banked", sub, message.grade, rows, actions)
end

function RoundPanel.close()
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
end

return RoundPanel

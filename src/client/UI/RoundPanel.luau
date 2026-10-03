--!strict
-- The round summary (after the card lands) and the banked-run summary. The grade is drawn as a
-- stamped hallmark: a small bordered cartouche, not a font glyph.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Hallmark = require(script.Parent.Hallmark)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local State = require(script.Parent.Parent.State)
local Share = require(script.Parent.Share)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Sound = require(script.Parent.Parent.Sound)

local RoundPanel = {}

local NAME = "Round"

local function number(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end
RoundPanel.number = number

-- One row of the tally. Rows arrive one after another, and a number counts up to its value
-- with a soft tick, so what you earned lands one thing at a time.
local function line(parent: Instance, left: string, right: string, order: number, delay: number)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.LayoutOrder = order
	row.Parent = parent
	local l = Theme.text(row, left, 15, "body", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.6, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Brand.Colours.smoke,
	})
	local r = Theme.text(row, right, 15, "bodyMedium", {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromScale(0.6, 0),
		Size = UDim2.new(0.4, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Brand.Colours.bone,
	})
	if Ease.motionScale < 0.5 then
		return
	end
	l.TextTransparency = 1
	r.TextTransparency = 1
	local sign, digits, percent = string.match(right, "^([+]?)([%d,]+)(%%?)$")
	local target = if digits then tonumber((string.gsub(digits, ",", ""))) else nil
	local before, after = sign or "", percent or ""
	if target then
		r.Text = before .. "0" .. after
	end
	task.delay(delay, function()
		if not row.Parent then
			return
		end
		Ease.play(l, Ease.info(0.25, Enum.EasingStyle.Quad), { TextTransparency = 0 })
		Ease.play(r, Ease.info(0.25, Enum.EasingStyle.Quad), { TextTransparency = 0 })
		Sound.play(if left == "Gilt" then "reward" else "tick", if left == "Gilt" then 0.3 else 0.12)
		if target then
			local value = Instance.new("NumberValue")
			value.Value = 0
			value.Changed:Connect(function(v: number)
				if r.Parent then
					r.Text = before .. number(if v >= target - 0.5 then target else v) .. after
				end
			end)
			local t = TweenService:Create(value, TweenInfo.new(math.clamp(0.25 + target / 4000, 0.25, 0.7), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
			t.Completed:Once(function()
				r.Text = right
				value:Destroy()
			end)
			t:Play()
		end
	end)
end

export type Actions = { primary: string, onPrimary: () -> (), secondary: string?, onSecondary: (() -> ())?, onLeave: () -> () }

local function panel(heading: string, sub: string?, grade: string, rows: { { string } }, actions: Actions)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local size = Root.size()
	local w = math.min(420, size.X - 24)
	-- The card grows to fit what's on it, so nothing is ever cut off at the bottom.
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 0), UDim2.new(0.5, 0, 0.5, 20))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	if sub then
		Theme.text(content, sub, 11, "caps", { LayoutOrder = 1 })
	end
	Theme.text(content, heading, 24, "display", { LayoutOrder = 2 })
	Hallmark.big(content, grade, 3)
	for i, r in rows do
		line(content, r[1], r[2], 3 + i, 0.35 + 0.14 * i)
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
	if type(message.boardScore) == "number" and message.boardScore < (message.score or 0) then
		-- After a Chronos Defiance revive the boards keep the score from before it.
		table.insert(rows, { "On the boards (before the revive)", number(message.boardScore) })
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

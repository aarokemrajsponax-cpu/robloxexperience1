--!strict
-- The round summary (after the card lands) and the banked-run summary: a card of black glass in
-- the grade's own light, with an instrument's gold brackets at its corners and a band of light
-- that reads it in; the grade as a badge of light; the tally counting up line by line.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Caps = require(ReplicatedStorage.Shared.Caps)
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

-- The grades' own light: the colours of their word (bright at the top, deeper below), of the
-- edge and glow round their badge, and the deep tint of its glass.
type Tier = { top: Color3, bottom: Color3, glow: Color3, deep: Color3 }
local TIERS: { [string]: Tier } = {
	Flawless = { top = Color3.fromRGB(255, 250, 236), bottom = Color3.fromRGB(255, 176, 214), glow = Color3.fromRGB(255, 170, 220), deep = Color3.fromRGB(58, 18, 44) },
	Immaculate = { top = Color3.fromRGB(255, 244, 206), bottom = Color3.fromRGB(240, 178, 70), glow = Color3.fromRGB(255, 196, 92), deep = Color3.fromRGB(54, 36, 8) },
	Polished = { top = Color3.fromRGB(250, 244, 230), bottom = Color3.fromRGB(214, 186, 136), glow = Color3.fromRGB(236, 210, 160), deep = Color3.fromRGB(44, 36, 24) },
	Steady = { top = Color3.fromRGB(240, 248, 255), bottom = Color3.fromRGB(140, 178, 226), glow = Color3.fromRGB(150, 196, 255), deep = Color3.fromRGB(14, 28, 50) },
	Cleared = { top = Color3.fromRGB(250, 214, 180), bottom = Color3.fromRGB(196, 120, 72), glow = Color3.fromRGB(230, 150, 100), deep = Color3.fromRGB(46, 22, 10) },
}
local function tierOf(grade: string): Tier
	return TIERS[grade] or TIERS.Cleared
end

-- A small diamond of light (drawn, not a glyph: the same in every font).
local function diamond(parent: Instance, colour: Color3, size: number, position: UDim2, z: number): Frame
	local d = Instance.new("Frame")
	d.Name = "Diamond"
	d.AnchorPoint = Vector2.new(0.5, 0.5)
	d.Position = position
	d.Size = UDim2.fromOffset(size, size)
	d.Rotation = 45
	d.BorderSizePixel = 0
	d.BackgroundColor3 = colour
	d.ZIndex = z
	d.Parent = parent
	return d
end

-- The grade, as a badge of light: a capsule of dark glass tinted with the grade's colour, a
-- bright edge, a glow round it, the word in the grade's own metal, a diamond either side. It
-- lands with a pop, and a band of light crosses it now and then.
local function badge(parent: Instance, grade: string, order: number): Frame
	local tier = tierOf(grade)
	-- (In a row of its own, with room above and below for its glow.)
	local row = Instance.new("Frame")
	row.Name = "GradeRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 68)
	row.LayoutOrder = order
	row.Parent = parent
	local holder = Instance.new("Frame")
	holder.Name = "Grade"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(300, 50)
	holder.Parent = row
	Theme.glow(holder, tier.glow, 25, 1.3)
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Size = UDim2.fromScale(1, 1)
	pill.ZIndex = 2
	pill.ClipsDescendants = true
	pill.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 25)
	corner.Parent = pill
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, tier.deep:Lerp(Color3.new(1, 1, 1), 0.08)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(10, 10, 13)),
		ColorSequenceKeypoint.new(1, tier.deep),
	})
	fill.Parent = pill
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.new(1, 1, 1)
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	local edgeLight = Instance.new("UIGradient")
	edgeLight.Rotation = 20
	edgeLight.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, tier.top),
		ColorSequenceKeypoint.new(0.5, tier.bottom),
		ColorSequenceKeypoint.new(1, tier.top),
	})
	edgeLight.Parent = edge
	edge.Parent = pill
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.AnchorPoint = Vector2.new(0.5, 0.5)
	words.Position = UDim2.fromScale(0.5, 0.5)
	words.Size = UDim2.new(1, -84, 1, -14)
	words.FontFace = Brand.Fonts.display
	words.TextScaled = true
	words.TextColor3 = Color3.new(1, 1, 1)
	words.Text = Caps(grade ~= "" and grade or "Cleared")
	words.ZIndex = 3
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 22
	fit.MinTextSize = 12
	fit.Parent = words
	local metal = Instance.new("UIGradient")
	metal.Rotation = 90
	metal.Color = ColorSequence.new(tier.top, tier.bottom)
	metal.Parent = words
	words.Parent = pill
	diamond(pill, tier.bottom, 7, UDim2.new(0, 26, 0.5, 0), 3)
	diamond(pill, tier.bottom, 7, UDim2.new(1, -26, 0.5, 0), 3)
	-- The band of light.
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.BorderSizePixel = 0
	sweep.BackgroundColor3 = Color3.new(1, 1, 1)
	sweep.Size = UDim2.fromScale(1, 1)
	sweep.ZIndex = 4
	sweep.Parent = pill
	local sg = Instance.new("UIGradient")
	sg.Rotation = 20
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.72),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	sg.Offset = Vector2.new(-1, 0)
	sg.Parent = sweep
	if Ease.motionScale >= 0.5 then
		local pop = Instance.new("UIScale")
		pop.Scale = 0.55
		pop.Parent = holder
		task.delay(0.15, function()
			if holder.Parent then
				Ease.play(pop, Ease.info(0.45, Enum.EasingStyle.Back), { Scale = 1 })
				TweenService:Create(sg, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 2.4), { Offset = Vector2.new(1, 0) }):Play()
			end
		end)
	end
	return holder
end

-- Fine gold brackets at the card's four corners (an instrument's frame), drawn just inside its
-- edge.
local function brackets(group: Frame, colour: Color3)
	local holder = Instance.new("Frame")
	holder.Name = "Brackets"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 6
	holder.Parent = group
	local ARM, INSET = 18, 7
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		for _, across in { true, false } do
			local bar = Instance.new("Frame")
			bar.BorderSizePixel = 0
			bar.BackgroundColor3 = colour
			bar.BackgroundTransparency = 0.15
			bar.AnchorPoint = corner
			bar.Size = if across then UDim2.fromOffset(ARM, 2) else UDim2.fromOffset(2, ARM)
			bar.Position = UDim2.new(corner.X, if corner.X == 0 then INSET else -INSET, corner.Y, if corner.Y == 0 then INSET else -INSET)
			bar.ZIndex = 6
			bar.Parent = holder
		end
	end
end

-- A band of light that passes down the card once as it opens (as if it were being read in).
local function scan(group: Frame)
	if Ease.motionScale < 0.5 then
		return
	end
	local band = Instance.new("Frame")
	band.Name = "Scan"
	band.BorderSizePixel = 0
	band.BackgroundColor3 = Brand.Colours.brightGold
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0)
	band.Size = UDim2.new(1, -24, 0, 2)
	band.ZIndex = 7
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = band
	band.Parent = group
	local t = TweenService:Create(band, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(0.5, 1), BackgroundTransparency = 0.6 })
	t.Completed:Once(function()
		band:Destroy()
	end)
	t:Play()
end

-- One row of the tally. Rows arrive one after another, and a number counts up to its value with
-- a soft tick, so what you earned lands one thing at a time. What was added is in gold; the
-- run's total stands large under a line of light.
local function line(parent: Instance, left: string, right: string, order: number, delay: number, total: boolean?)
	local row = Instance.new("Frame")
	row.Name = if total then "Total" else "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, if total then 44 else 27)
	row.LayoutOrder = order
	row.Parent = parent
	local l = Theme.text(row, left, if total then 13 else 15, if total then "caps" else "body", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(0.58, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if total then Brand.Colours.lightGold else Brand.Colours.smoke,
	})
	local added = string.sub(right, 1, 1) == "+"
	local r = Theme.text(row, right, if total then 30 else 17, "bodyBold", {
		AutomaticSize = Enum.AutomaticSize.None,
		Position = UDim2.fromScale(0.58, 0),
		Size = UDim2.new(0.42, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = if added then Brand.Colours.brightGold else Brand.Colours.bone,
	})
	if total then
		r.FontFace = Brand.Fonts.heavy
		r.TextColor3 = Color3.new(1, 1, 1)
		Theme.metal(r, true)
	end
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

-- The card: the room, the round in large capitals, the grade's badge, the tally, the run's total,
-- and the keys (the next round, wide and gold; banking and leaving side by side under it).
local function panel(heading: string, sub: string?, grade: string, rows: { { string } }, actions: Actions, totalLabel: string?)
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local size = Root.size()
	local w = math.min(480, size.X - 24)
	local tier = tierOf(grade)
	-- The card grows to fit what's on it, so nothing is ever cut off at the bottom.
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 0), UDim2.new(0.5, 0, 0.5, 16))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	-- (The card's own glow takes the grade's light.)
	local glow = group:FindFirstChild("Glow")
	if glow then
		for _, h in glow:GetChildren() do
			if h:IsA("Frame") then
				h.BackgroundColor3 = tier.glow
			end
		end
	end
	brackets(group, Brand.Colours.brightGold)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	if sub then
		Theme.text(content, sub, 12, "caps", { LayoutOrder = 1, TextColor3 = Brand.Colours.brightGold })
	end
	-- The heading on one line, in the display face (smaller for a longer one, never wrapped).
	local head = Theme.text(content, heading, 32, "display", {
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0, 40),
		TextScaled = true,
		TextWrapped = false,
	})
	local fit = Instance.new("UITextSizeConstraint")
	fit.Name = "Fit"
	fit.MinTextSize = 16
	fit.MaxTextSize = head.TextSize
	fit.Parent = head
	badge(content, grade, 3)
	Theme.hairline(content, UDim.new(0.9, 0), 4)
	for i, r in rows do
		local isTotal = totalLabel ~= nil and r[1] == totalLabel
		if isTotal then
			Theme.hairline(content, UDim.new(1, 0), 3 + i * 2 - 1)
		end
		line(content, r[1], r[2], 3 + i * 2, 0.45 + 0.14 * i, isTotal)
	end
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.BackgroundTransparency = 1
	keys.AutomaticSize = Enum.AutomaticSize.Y
	keys.Size = UDim2.new(1, 0, 0, 0)
	keys.LayoutOrder = 50
	keys.Parent = content
	Theme.list(keys, 10)
	local inner = w - 48
	local primary = Theme.key(keys, actions.primary, true, function()
		Root.close(NAME)
		actions.onPrimary()
	end, inner)
	primary.LayoutOrder = 1
	primary.Size = UDim2.fromOffset(inner, 48)
	-- The others, side by side.
	local pair = Instance.new("Frame")
	pair.Name = "Pair"
	pair.BackgroundTransparency = 1
	pair.Size = UDim2.new(1, 0, 0, 42)
	pair.LayoutOrder = 2
	pair.Parent = keys
	Theme.list(pair, 10, true)
	local others = 1
	if actions.secondary and actions.onSecondary then
		others += 1
	end
	if grade == "Flawless" and Share.allowed() then
		others += 1
	end
	local each = math.floor((inner - (others - 1) * 10) / others)
	if actions.secondary and actions.onSecondary then
		local onSecondary = actions.onSecondary
		Theme.key(pair, actions.secondary, false, function()
			Root.close(NAME)
			onSecondary()
		end, each).LayoutOrder = 1
	end
	if grade == "Flawless" and Share.allowed() then
		Theme.key(pair, "Share", false, function()
			Share.moment("salon")
		end, each).LayoutOrder = 2
	end
	Theme.key(pair, "Leave", false, function()
		Root.close(NAME)
		actions.onLeave()
	end, each).LayoutOrder = 3
	-- Round cards don't blur the table: the felt stays in focus behind them.
	Root.open(NAME, group, nil, false)
	scan(group)
	pcall(function()
		game:GetService("GuiService").SelectedObject = primary
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
	panel("Round " .. roundText, sub, message.grade, rows, actions, "The run so far")
end

function RoundPanel.banked(message: { [string]: any }, actions: Actions)
	local rows = {
		{ "Rounds cleared", tostring(message.rounds) },
		{ "Accuracy", string.format("%d%%", math.floor((message.accuracy or 0) * 100 + 0.5)) },
	}
	if (message.gilt or 0) > 0 then
		table.insert(rows, { "Gilt", "+" .. number(message.gilt) })
	end
	if type(message.curio) == "table" and type(message.curio.name) == "string" then
		table.insert(rows, { "A curio turned up", tostring(message.curio.name) .. " · " .. tostring(message.curio.rarity) })
	end
	if type(message.boardScore) == "number" and message.boardScore < (message.score or 0) then
		-- After a Chronos Defiance revive the boards keep the score from before it.
		table.insert(rows, { "On the boards (before the revive)", number(message.boardScore) })
	end
	if (message.best or 0) > 0 then
		table.insert(rows, { if message.newBest then "A new best" else "Your best here", number(message.best) })
	end
	table.insert(rows, { "The run", number(message.score) })
	local sub = if type(message.reason) == "string" and message.reason ~= "" then message.reason else "Banked to the board"
	panel("The run is banked", sub, message.grade, rows, actions, "The run")
end

function RoundPanel.close()
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
end

return RoundPanel

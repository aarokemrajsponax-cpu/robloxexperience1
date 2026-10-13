--!strict
-- One quiet card under the keys while you walk: what to do next, and how. A first visit is told
-- to take a seat; then tonight's table, if it's waiting (with a key that takes you there); then a
-- holiday game, while one is open (and first of all while you're playing it); then the next room
-- to open; then your best run to beat. It is never shown at a table. It comes up bright
-- when it changes and settles back after a few seconds, so it's there whenever you look for it.
-- It steps aside while something bigger holds the screen, and comes back quietly after. Its –
-- key folds it away into a small NEXT tab (and the tab brings it back); the choice is kept, like
-- a setting (The room → What-to-do-next card).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Fade = require(script.Parent.Fade)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local State = require(script.Parent.Parent.State)

local Objective = {}

export type Goal = { key: string, title: string, line: string, how: string?, go: string? }

local V = Voice.Objective
local seatedOnce = false
local seated = false
local lastRoom: string? = nil
local card: Frame? = nil
local shownKey: string? = nil
local takeMe: ((mode: string) -> ())? = nil
local started = false
-- (The card that stepped aside for a moment: the same card comes back quietly, as it was.)
local quietKey: string? = nil

-- Something bigger holding the screen for a moment (a show's big words, Admin Abuse's cards, a
-- headline, a badge coming in): the card steps aside, and comes back when it's gone.
Objective.isBusy = function(): boolean
	return false
end

-- The holiday game's goal (set by Main: World/HolidayPlay.goal). Its rank places it: "here" (in a
-- game's own place) before everything, "gifts" (gifts waiting) after a first visit's seat, "open"
-- (a game open) after tonight's table.
Objective.holiday = function(): { key: string, title: string, line: string, how: string?, rank: string }?
	return nil
end

local function byInput(t: { [string]: string }): string
	return t[State.inputKind()] or t.mouse
end

local function number(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

-- What the guest should do next, from what the house told us on arrival and since.
function Objective.current(): Goal?
	local guest = State.guest
	if guest == nil then
		return nil
	end
	local ok, h = pcall(Objective.holiday)
	local holiday: Goal? = if ok and h then { key = "holiday:" .. h.key, title = h.title, line = h.line, how = h.how } else nil
	local rank = if ok and h then h.rank else nil
	if holiday and rank == "here" then
		return holiday
	end
	if guest.firstVisit == true and not seatedOnce then
		return { key = "sit", title = V.next, line = V.sit, how = byInput(V.sitHow) }
	end
	if holiday and rank == "gifts" then
		return holiday
	end
	local nightly = guest.nightly
	if type(nightly) == "table" and nightly.played ~= true then
		return { key = "nightly", title = V.tonight, line = V.nightly, how = byInput(V.nightlyHow), go = "nightly" }
	end
	if holiday then
		return holiday
	end
	-- The Ballroom, while it's open (or counting down to an evening): a chair, and a pot to win.
	local ballroom = Workspace:GetAttribute("BallroomState")
	if ballroom == "open" or ballroom == "gathering" then
		local pot = Workspace:GetAttribute("BallroomPot")
		local potText = if type(pot) == "number" then number(pot) else "a pot of"
		if ballroom == "gathering" then
			return { key = "ballroom:gathering", title = "Lights Out · last call", line = "An evening in the Ballroom is about to begin", how = string.format("Take any chair before it starts: the last lamp wins %s Gilt.", potText), go = "ballroom" }
		end
		return { key = "ballroom:open", title = "The Ballroom is open", line = "Lights Out: sit, sort, keep your lamp lit", how = string.format("The last lamp wins %s Gilt or more. It closes soon.", potText), go = "ballroom" }
	end
	if not State.unlocked.midnight then
		return { key = "midnight", title = V.next, line = V.midnight, how = V.midnightHow }
	end
	-- The best run in any room.
	local top, where = 0, nil
	if type(guest.best) == "table" then
		for id, points in guest.best do
			if type(points) == "number" and points > top then
				top, where = points, id
			end
		end
	end
	local room = if where then Rooms.get(where) else nil
	if top > 0 and room then
		local name = string.gsub(room.name, "^The ", "the ")
		local line = string.gsub(string.gsub(V.best, "{points}", number(top)), "{room}", name)
		return { key = "best:" .. top, title = V.next, line = line, how = V.bestHow }
	end
	return nil
end

local function hide()
	local group = card
	if not group then
		return
	end
	card = nil
	shownKey = nil
	local t = Fade.to(group, Ease.info(0.35, Enum.EasingStyle.Sine), 1)
	t.Completed:Once(function()
		group:Destroy()
	end)
end

-- Folded away: a small tab where the card was (NEXT ▾), and tapping it brings the card back.
local tab: TextButton? = nil
local function folded(): boolean
	return State.get("goalCard") == "Hidden"
end
local function dropTab()
	local t = tab
	if t then
		tab = nil
		t:Destroy()
	end
end

-- Under the keys at the top right; a touch lower while the events strip reaches across to it (a
-- narrow screen), never over it.
local WIDTH = 300
local function where(): UDim2
	local right = Root.size().X - 12
	return UDim2.new(1, -12, 0, math.max(62, Root.topClearAt(right - WIDTH, right) + 8))
end

Root.TopChanged:Connect(function()
	local group = card
	if group then
		Ease.play(group, Ease.scaled(Ease.settle), { Position = where() })
	end
	local t = tab
	if t then
		t.Position = where()
	end
end)

local function showTab()
	if tab then
		return
	end
	local b = Instance.new("TextButton")
	b.Name = "ObjectiveTab"
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(1, 0)
	b.Position = where()
	b.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
	b.BackgroundTransparency = 0.08
	b.FontFace = Brand.Fonts.bodyBold
	b.TextSize = 13
	b.TextColor3 = Brand.Colours.lightGold
	b.Text = "NEXT  ▾"
	b.Size = UDim2.fromOffset(Theme.measure(b.Text, 13, Brand.Fonts.bodyBold).X + 28, 30)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = Brand.Colours.gold
	st.Transparency = 0.25
	st.Parent = b
	b.Activated:Connect(function()
		State.set("goalCard", "Shown")
	end)
	b.Parent = Root.hud
	tab = b
end

local function show(goal: Goal)
	dropTab()
	if card and shownKey == goal.key then
		return
	end
	local quiet = quietKey == goal.key
	quietKey = nil
	hide()
	local group, content = Theme.glass(Root.hud, "Objective", UDim2.fromOffset(WIDTH, 0), where(), Vector2.new(1, 0))
	Theme.fitHeight(group, content)
	local pad = content:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 40)
	end
	-- The – key in its top corner: folds the card away (to the small NEXT tab).
	local fold = Instance.new("TextButton")
	fold.Name = "Fold"
	fold.AutoButtonColor = false
	fold.AnchorPoint = Vector2.new(1, 0)
	fold.Position = UDim2.new(1, -10, 0, 10)
	fold.Size = UDim2.fromOffset(26, 26)
	fold.BackgroundColor3 = Color3.fromRGB(34, 32, 30)
	fold.BackgroundTransparency = 0.05
	fold.FontFace = Brand.Fonts.heavy
	fold.TextSize = 18
	fold.TextColor3 = Brand.Colours.lightGold
	fold.Text = "–"
	fold.ZIndex = 8
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fold
	local fs = Instance.new("UIStroke")
	fs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	fs.Color = Brand.Colours.gold
	fs.Transparency = 0.4
	fs.Parent = fold
	fold.Activated:Connect(function()
		State.set("goalCard", "Hidden")
	end)
	fold.Parent = group
	local list = Theme.list(content, 3)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(content, goal.title, 11, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	Theme.text(content, goal.line, 16, "display", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left })
	if goal.how then
		Theme.text(content, goal.how, 13, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Brand.Colours.smoke })
	end
	local go = goal.go
	local jump = takeMe
	if go and jump then
		local key = Theme.key(content, V.takeMe, false, function()
			jump(go)
		end, 160)
		key.LayoutOrder = 4
		key.Size = UDim2.fromOffset(160, 34)
	end
	card = group
	shownKey = goal.key
	Fade.set(group, 1)
	if quiet then
		-- (Back after stepping aside: no slide, no brightness, just there again, settled.)
		Fade.to(group, Ease.info(0.5, Enum.EasingStyle.Sine), 0.35)
		return
	end
	local startPos = group.Position
	group.Position = startPos + UDim2.fromOffset(12, 0)
	Fade.to(group, Ease.scaled(Ease.settle), 0, { Position = startPos })
	-- Settles back after a while, still readable.
	task.delay(9, function()
		if card == group then
			Fade.to(group, Ease.info(1.2, Enum.EasingStyle.Sine), 0.35)
		end
	end)
end

local function busy(): boolean
	local ok, yes = pcall(Objective.isBusy)
	return ok and yes == true
end

function Objective.refresh()
	if not started then
		return
	end
	local goal = if seated or State.phase ~= "play" or Root.isOpen() then nil else Objective.current()
	if goal and folded() and not busy() then
		quietKey = nil
		hide()
		showTab()
		return
	end
	dropTab()
	if goal and busy() then
		if card and shownKey == goal.key then
			quietKey = goal.key
		end
		hide()
	elseif goal then
		show(goal)
	else
		quietKey = nil
		hide()
	end
end

-- `go` takes the guest to a table of the kind named ("nightly", "room").
function Objective.start(go: (mode: string) -> ())
	if started then
		return
	end
	started = true
	takeMe = go
	State.Welcomed:Connect(Objective.refresh)
	State.Unlocked:Connect(Objective.refresh)
	State.PhaseChanged:Connect(Objective.refresh)
	Root.PanelsChanged:Connect(Objective.refresh)
	State.watch("goalCard", function()
		task.defer(Objective.refresh)
	end)
	Workspace:GetAttributeChangedSignal("BallroomState"):Connect(function()
		task.defer(Objective.refresh)
	end)
	Remotes.event("Table").OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" then
			return
		end
		local guest = State.guest
		if message.op == "seated" then
			seated = true
			seatedOnce = true
			lastRoom = if type(message.room) == "string" then message.room else lastRoom
		elseif message.op == "left" and not message.moving then
			seated = false
		elseif message.op == "nightlyCard" and guest then
			guest.nightly = { played = true, score = message.score, grade = message.grade }
		elseif message.op == "banked" and guest and type(message.best) == "number" and lastRoom then
			if type(guest.best) ~= "table" then
				guest.best = {}
			end
			guest.best[lastRoom] = math.max(guest.best[lastRoom] or 0, message.best)
		end
		task.defer(Objective.refresh)
	end)
	Objective.refresh()
	-- (Steps aside while something bigger holds the screen; back when it's gone.)
	task.spawn(function()
		local was = false
		while true do
			task.wait(0.2)
			local now = busy()
			if now ~= was then
				was = now
				Objective.refresh()
			end
		end
	end)
end

return Objective

--!strict
-- One quiet card under the keys while you walk: what to do next, and how. A first visit is told
-- to take a seat; then tonight's table, if it's waiting (with a key that takes you there); then a
-- holiday game, while one is open (and first of all while you're playing it); then the next of the
-- house's games to try (Steal a Luxe, the Basement, the Grand Ballroom); then your best run to
-- beat. It is never shown at a table, nor inside one of the house's games. It comes up bright
-- when it changes and settles back after a few seconds, so it's there whenever you look for it.
-- It steps aside while something bigger holds the screen, and comes back quietly after. Its –
-- key folds it away; the choice is kept, like a setting, and Settings brings it back (The room →
-- What-to-do-next card).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Attractions = require(ReplicatedStorage.Shared.Attractions)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
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
-- Set by Main: whether the gold arrow is leading a new guest to the Concierge.
Objective.guiding = function(): boolean
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
	-- (A guest still new to the house, while the arrow leads them: to the Concierge first.)
	local ok2, guiding = pcall(Objective.guiding)
	if ok2 and guiding == true and not seatedOnce then
		local S = Voice.StartHere
		return { key = "concierge", title = S.title, line = S.goal, how = S.goalHow }
	end
	-- (A first evening: the house's attractions first, one at a time, before any table.)
	local tried = if type(guest.tried) == "table" then guest.tried else nil
	if guest.firstVisit == true and not seatedOnce and tried then
		for _, t in V.try do
			if tried[t.id] ~= true then
				return { key = "try:" .. t.id, title = V.next, line = t.line, how = t.how, go = "try:" .. t.id }
			end
		end
	end
	-- (Build 98: never a nudge to the Salon's tables; the games are the house now.)
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
		-- (Build 95) Lights Out as it's played: party games on the Grand Ballroom's dance floor,
		-- joined with its Join key (the old sorting evening's "sit, sort" only while that's on).
		local floor = (Config.data.Ballroom :: any).floor
		local L = if type(floor) == "table" and floor.enabled == false then V.lightsOutTables else V.lightsOut
		if ballroom == "gathering" then
			return { key = "ballroom:gathering", title = L.gatheringTitle, line = L.gathering, how = string.format(L.gatheringHow, potText), go = "ballroom" }
		end
		return { key = "ballroom:open", title = L.openTitle, line = L.open, how = string.format(L.openHow, potText), go = "ballroom" }
	end
	-- The house's games not yet tried, one at a time (the server says which, and each one gone into
	-- since is crossed off here).
	if tried then
		for _, t in V.try do
			if tried[t.id] ~= true then
				return { key = "try:" .. t.id, title = V.next, line = t.line, how = t.how, go = "try:" .. t.id }
			end
		end
	end
	-- (Build 97) Every game tried: back to the house's own loop, a bigger haul in Steal a Luxe,
	-- one tap in. (It used to send them to beat a score at the Salon's sorting tables.)
	if tried then
		return { key = "more:luxe", title = V.next, line = V.more, how = V.moreHow, go = "try:luxe" }
	end
	return nil
end

-- Under the keys at the top right; a touch lower while the events strip reaches across to it (a
-- narrow screen), never over it.
local WIDTH = 300
local function where(): UDim2
	local right = Root.size().X - 12
	return UDim2.new(1, -12, 0, math.max(62, Root.topClearAt(right - WIDTH, right) + 8))
end

-- (Build 104) How far down the right-hand column the card reaches (Root.rightTop: the HOUSE TOUR
-- key in the corner below keeps clear of it); just the top keys while there's no card.
local lastHigh = 210 -- (the card's height when last shown: what it'd need back)
local function publishFoot()
	local group = card
	if not group or not group.Parent then
		Root.setRightTop(58)
		return
	end
	local high = group.Size.Y.Offset
	local ok, px = pcall(function()
		return group.AbsoluteSize.Y
	end)
	if ok and type(px) == "number" and px > 0 then
		high = math.max(high, px / math.max(0.1, Root.scale))
	end
	if high <= 0 then
		high = 210 -- (not laid out yet: as tall as a card with a two-line goal on a phone)
	end
	lastHigh = high
	Root.setRightTop(where().Y.Offset + high)
end

local function hide()
	local group = card
	if not group then
		return
	end
	card = nil
	publishFoot()
	shownKey = nil
	local t = Fade.to(group, Ease.info(0.35, Enum.EasingStyle.Sine), 1)
	t.Completed:Once(function()
		group:Destroy()
	end)
end

-- Folded away: nothing on screen (an earlier small NEXT tab is gone: it crowded the corner).
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


Root.TopChanged:Connect(function()
	local group = card
	if group then
		Ease.play(group, Ease.scaled(Ease.settle), { Position = where() })
	end
	publishFoot()
	local t = tab
	if t then
		t.Position = where()
	end
end)

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
	-- The – key in its top corner: folds the card away (Settings brings it back).
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
	-- (A holiday's goal in the holiday's own colours.)
	if string.sub(goal.key, 1, 8) == "holiday:" then
		Theme.paint(group, Theme.holidayMood())
	end
	card = group
	shownKey = goal.key
	publishFoot()
	pcall(function()
		group:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if card == group then
				publishFoot()
			end
		end)
	end)
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

-- (Build 104) The Friend Boost's big card open in the corner below, reaching up to where this
-- card stands (a phone's short screen): this one steps aside quietly until it folds.
local function crowded(): boolean
	local c = Root.corner
	if c.height <= 0 then
		return false
	end
	local top = Root.size().Y - c.up - c.height
	return top < where().Y.Offset + lastHigh + 8
end

local function busy(): boolean
	local ok, yes = pcall(Objective.isBusy)
	return (ok and yes == true) or crowded()
end

function Objective.refresh()
	if not started then
		return
	end
	-- (Build 95) Not inside one of the house's games either: there its own screen says what to do,
	-- and on a phone this card sat over it, pointing somewhere else mid-run.
	local inside = Players.LocalPlayer:GetAttribute(Attractions.ATTRIBUTE)
	local away = type(inside) == "string" and inside ~= ""
	local goal = if seated or away or State.phase ~= "play" or Root.isOpen() then nil else Objective.current()
	if goal and folded() and not busy() then
		-- (Folded: nothing at all on screen. The card comes back from Settings: The room →
		-- What-to-do-next card.)
		quietKey = nil
		hide()
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
	Root.CornerChanged:Connect(function()
		task.defer(Objective.refresh)
	end)
	State.watch("goalCard", function()
		task.defer(Objective.refresh)
	end)
	Workspace:GetAttributeChangedSignal("BallroomState"):Connect(function()
		task.defer(Objective.refresh)
	end)
	Players.LocalPlayer:GetAttributeChangedSignal(Attractions.ATTRIBUTE):Connect(function()
		task.defer(Objective.refresh)
	end)
	-- (Into one of the house's games: crossed off what's still to try.)
	Remotes.event("Attraction").OnClientEvent:Connect(function(message: any)
		local guest = State.guest
		if type(message) == "table" and message.op == "entered" and type(message.id) == "string" and guest then
			if type(guest.tried) ~= "table" then
				guest.tried = {}
			end
			guest.tried[message.id] = true
			task.defer(Objective.refresh)
		end
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

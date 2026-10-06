--!strict
-- One quiet card under the keys while you walk: what to do next, and how. A first visit is told
-- to take a seat; then tonight's table, if it's waiting (with a key that takes you there); then the
-- next room to open; then your best run to beat. It is never shown at a table. It comes up bright
-- when it changes and settles back after a few seconds, so it's there whenever you look for it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	if guest.firstVisit == true and not seatedOnce then
		return { key = "sit", title = V.next, line = V.sit, how = byInput(V.sitHow) }
	end
	local nightly = guest.nightly
	if type(nightly) == "table" and nightly.played ~= true then
		return { key = "nightly", title = V.tonight, line = V.nightly, how = byInput(V.nightlyHow), go = "nightly" }
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

local function show(goal: Goal)
	if card and shownKey == goal.key then
		return
	end
	hide()
	local group, content = Theme.glass(Root.hud, "Objective", UDim2.fromOffset(300, 0), UDim2.new(1, -12, 0, 62), Vector2.new(1, 0))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local pad = content:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.PaddingLeft = UDim.new(0, 16)
		pad.PaddingRight = UDim.new(0, 16)
	end
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

function Objective.refresh()
	if not started then
		return
	end
	local goal = if seated or State.phase ~= "play" or Root.isOpen() then nil else Objective.current()
	if goal then
		show(goal)
	else
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
end

return Objective

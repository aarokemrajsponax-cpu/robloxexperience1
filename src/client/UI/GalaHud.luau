--!strict
-- The Grand Ballroom's own screen, shown only while a guest is in the hall (the server's
-- "Attraction" attribute). Along the top, the hall at a glance: where in it they are, the record
-- playing and when the next goes on, today's Gilt from the hall (of the day's most), and the three
-- activities: Luxury Trivia, the Runway and the Daily Arena, each with what it's doing now. At the
-- foot: home to the Ballroom, Dance & music, and the key for whatever part of the hall they stand
-- in (play trivia, walk in the show, take part, trade). Over it, one live card at a time: the
-- question at the podium (four answers, the time ticking), the walk and the vote on the Runway,
-- the Arena's countdown and score, and every result. Every figure is the server's; it decides
-- nothing (an answer, a vote or a join is only asked for).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Plan = require(ReplicatedStorage.Shared.Gala)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HudCard = require(script.Parent.HudCard)
local Root = require(script.Parent.Root)
local Sound = require(script.Parent.Parent.Sound)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local GalaHud = {}

-- Set by Main: the hall's panels (Dance & music, the Exchange).
GalaHud.openPanel = function(_which: string) end

local player = Players.LocalPlayer
local C = Brand.Colours
local rgb = Color3.fromRGB
local GOLD = rgb(255, 204, 90)
local WARM = rgb(255, 196, 120)
local GOOD = rgb(120, 225, 150)
local BAD = rgb(240, 110, 110)
local CARD_W = 320
local CARD_H = 166

local card: Frame? = nil
local keys: Frame? = nil
local live: Frame? = nil
local parts: { [string]: any } = {}
local topConn: RBXScriptConnection? = nil
local zoneConn: thread? = nil
local view: { [string]: any } = {}
local zone = "entrance"
-- What the live card shows: the activity this guest is in, else the Runway for the room.
local trivia: { [string]: any } = {}
local arena: { [string]: any } = {}
local liveTick = 0

local function act(request: { [string]: any }): { [string]: any }?
	request.op = "act"
	request.id = Plan.ID
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function label(parent: Instance, name: string, text: string, size: number, font: Font, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function corner(f: GuiObject, px: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = f
end

local function stroke(f: GuiObject, colour: Color3, t: number)
	local e = Instance.new("UIStroke")
	e.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	e.Color = colour
	e.Thickness = 1.25
	e.Transparency = t
	e.Parent = f
end

-- One of the hall's activities, as a row: its name on the left, where it stands (Open, Playing,
-- Signing up...) in a small pill on the right.
local function chip(parent: Instance, name: string, order: number): (TextLabel, TextLabel)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = rgb(255, 255, 255)
	f.BackgroundTransparency = 0.96
	f.Size = UDim2.new(1, 0, 0, 28)
	f.LayoutOrder = order
	f.Parent = parent
	corner(f, 7)
	local small = label(f, "Word", "", 11, Brand.Fonts.bodyBold, C.bone)
	small.Position = UDim2.fromOffset(10, 0)
	small.Size = UDim2.new(1, -124, 1, 0)
	small.TextXAlignment = Enum.TextXAlignment.Left
	local pill = Instance.new("Frame")
	pill.Name = "State"
	pill.BackgroundColor3 = rgb(0, 0, 0)
	pill.BackgroundTransparency = 0.45
	pill.AnchorPoint = Vector2.new(1, 0.5)
	pill.Position = UDim2.new(1, -5, 0.5, 0)
	pill.Size = UDim2.fromOffset(110, 20)
	pill.Parent = f
	corner(pill, 10)
	local big = label(pill, "Figure", "", 11, Brand.Fonts.bodyBold, C.bone)
	big.Size = UDim2.fromScale(1, 1)
	big.TextXAlignment = Enum.TextXAlignment.Center
	return big, small
end

local function clock(s: number): string
	s = math.max(0, math.floor(s))
	return string.format("%d:%02d", s // 60, s % 60)
end

local function place()
	local c = card
	if not c then
		return
	end
	-- (The bottom-left corner, like every attraction's card: UI/HudCard. While a live card is up,
	-- a quiz or a show, the hall's card steps aside for it.)
	HudCard.place(c, 260)
	c.Visible = live == nil
	local k = keys
	if k then
		k.Position = UDim2.new(0.5, 0, 1, -(14 + Root.bottomClear()))
	end
	local l = live
	if l then
		l.Position = UDim2.new(0.5, 0, 1, -(70 + Root.bottomClear()))
	end
end

---------------------------------------------------------------------------------------------------
-- The card along the top
---------------------------------------------------------------------------------------------------
local PHASES = {
	trivia = { idle = "Open", lobby = "Starting", question = "Playing", reveal = "Playing", results = "Results" },
	runway = { idle = "Next show", signup = "Signing up", walk = "On the catwalk", vote = "Voting", results = "Results" },
	arena = { idle = "Open", countdown = "Starting", play = "Under way", results = "Results" },
}

local function draw()
	if not card then
		return
	end
	parts.zone.Text = string.upper(Plan.zoneName(zone))
	local juke = view.juke
	if type(juke) == "table" then
		local left = tonumber(juke.changeIn) or 0
		parts.record.Text = string.format("♪  %s  ·  the next record in %s", tostring(juke.name or "The jukebox"), clock(left))
	else
		parts.record.Text = "♪  The jukebox"
	end
	local today = view.today
	if type(today) == "table" then
		parts.gilt.Text = string.format("💰 %s / %s today", Plan.commas(tonumber(today.gilt) or 0), Plan.commas(tonumber(today.cap) or Plan.REWARDS.dailyGilt))
		parts.gilt.TextColor3 = if (tonumber(today.gilt) or 0) >= (tonumber(today.cap) or math.huge) then GOLD else C.smoke
	end
	local t = if type(view.trivia) == "table" then view.trivia else {}
	parts.trivia.Text = "🎓 " .. (PHASES.trivia[tostring(t.phase or "idle")] or "Open")
	parts.triviaWord.Text = if t.seated then "LUXURY TRIVIA · YOU'RE PLAYING" elseif (tonumber(t.seats) or 0) > 0 then string.format("TRIVIA · %d AT THE PODIUMS", tonumber(t.seats) or 0) else "LUXURY TRIVIA"
	parts.trivia.TextColor3 = if t.seated then GOLD else C.bone
	local r = if type(view.runway) == "table" then view.runway else {}
	parts.runway.Text = "👗 " .. (PHASES.runway[tostring(r.phase or "idle")] or "Next show")
	parts.runwayWord.Text = if r.mine then "THE RUNWAY · YOU'RE WALKING" elseif type(r.theme) == "string" then string.upper(r.theme) else "THE RUNWAY"
	parts.runway.TextColor3 = if r.mine then GOLD else C.bone
	local a = if type(view.arena) == "table" then view.arena else {}
	local ch = Plan.challengeById[tostring(a.challenge or "")] or Plan.challengeFor(Plan.day())
	parts.arena.Text = ch.glyph .. " " .. (PHASES.arena[tostring(a.phase or "idle")] or "Open")
	parts.arenaWord.Text = if a.mine then "THE ARENA · YOU'RE IN" else string.upper(ch.name)
	parts.arena.TextColor3 = if a.mine then GOLD else C.bone
end

---------------------------------------------------------------------------------------------------
-- The keys at the foot (home, Dance & music, and the key for the part of the hall they're in)
---------------------------------------------------------------------------------------------------
local function busy(): string?
	return if type(view.busy) == "string" then view.busy else nil
end

local function join(what: string)
	task.spawn(function()
		local r = act({ act = "join", what = what })
		if not r then
			Toast.show("Not just now", "The house couldn't be reached. Try again in a moment.", 3)
		elseif r.ok ~= true then
			Toast.show("Not just now", tostring(r.why or "Not just now."), 3)
		elseif type(r.title) == "string" then
			Toast.show(r.title, tostring(r.line or ""), 4)
		end
	end)
end

local function drawKeys()
	local k = keys
	if not k then
		return
	end
	for _, c in k:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	Theme.key(k, "Ballroom", false, function()
		task.spawn(function()
			local ok, r = pcall(function()
				return Remotes.func("AttractionAsk"):InvokeServer({ op = "home" })
			end)
			if ok and type(r) == "table" and r.ok ~= true and type(r.why) == "string" then
				Toast.show("Not just now", r.why, 3)
			end
		end)
	end, 130).LayoutOrder = 1
	Theme.key(k, "Dance & music", false, function()
		GalaHud.openPanel("dance")
	end, 170).LayoutOrder = 2
	local b = busy()
	local extra: { string }? = nil
	if zone == "trivia" and b == nil then
		extra = { "Play trivia", "trivia" }
	elseif zone == "runway" and b == nil then
		extra = { "Walk in the show", "runway" }
	elseif zone == "arena" and b == nil then
		extra = { "Take part", "arena" }
	elseif zone == "exchange" then
		extra = { "Trade", "exchange" }
	end
	if extra then
		local e = extra
		Theme.key(k, e[1], true, function()
			if e[2] == "exchange" then
				GalaHud.openPanel("exchange")
			else
				join(e[2])
			end
		end, 180).LayoutOrder = 3
	end
	-- (Build 82) The camera back behind the guest, from anywhere in the hall: after a pose at a
	-- photo set, photo mode or a reel, it's one press away.
	Theme.key(k, "Reset camera", false, function()
		GalaHud.resetCamera()
	end, 150).LayoutOrder = 4
end

-- The camera back on the guest (photo mode put away first, if it's open).
function GalaHud.resetCamera()
	pcall(function()
		local PhotoMode = require(script.Parent.PhotoMode) :: any
		if PhotoMode.isActive() then
			PhotoMode.exit()
		end
	end)
	pcall(function()
		(require(script.Parent.Parent.Camera) :: any).follow()
	end)
end

---------------------------------------------------------------------------------------------------
-- The live card
---------------------------------------------------------------------------------------------------
local function clearLive()
	local l = live
	live = nil
	if l then
		l:Destroy()
		-- (The hall's card comes back from where it stepped aside.)
		place()
	end
	liveTick += 1
end

local function liveCard(height: number, accent: Color3): (Frame, Frame)
	clearLive()
	local w = math.min(600, Root.size().X - 24)
	local f = Instance.new("Frame")
	f.Name = "GalaLive"
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Size = UDim2.fromOffset(w, height)
	f.Parent = Root.hud
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 16)
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = f
	HudCard.style(f, accent)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Size = UDim2.fromScale(1, 1)
	inner.Parent = f
	Theme.list(inner, 6).VerticalAlignment = Enum.VerticalAlignment.Top
	live = f
	place()
	return f, inner
end

-- A banner: a heading, a line, and a timer counted down here (from the server's seconds).
local function banner(heading: string, line: string, accent: Color3, seconds: number?, key: { string }?)
	local _, inner = liveCard(if key then 112 else 72, accent)
	local head = label(inner, "Heading", heading, 12, Brand.Fonts.bodyBold, accent)
	head.LayoutOrder = 1
	local body = label(inner, "Line", line, 14, Brand.Fonts.body, C.bone)
	body.LayoutOrder = 2
	body.TextWrapped = true
	body.TextTruncate = Enum.TextTruncate.None
	if seconds and seconds > 0 then
		local my = liveTick
		task.spawn(function()
			for left = math.floor(seconds), 0, -1 do
				if liveTick ~= my or not head.Parent then
					return
				end
				head.Text = string.format("%s  ·  %ds", heading, left)
				task.wait(1)
			end
		end)
	end
	if key then
		local row = Instance.new("Frame")
		row.Name = "Keys"
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 40)
		row.LayoutOrder = 3
		row.Parent = inner
		Theme.list(row, 8, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
		local k = key
		local b = Theme.key(row, k[1], false, function()
			task.spawn(function()
				act({ act = "quit", what = k[2] })
				clearLive()
			end)
		end, 170)
		b.Size = UDim2.fromOffset(170, 36)
	end
end

-- One of the four answers: dark glass, the letter in a gold disc on the left, the answer beside it.
-- Pointed at, its edge turns gold.
local function answerKey(parent: Instance, letter: string, text: string, onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = rgb(24, 24, 30)
	b.BackgroundTransparency = 0.05
	b.Text = text
	b.FontFace = Brand.Fonts.bodyBold
	b.TextSize = 15
	b.TextColor3 = C.bone
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextTruncate = Enum.TextTruncate.AtEnd
	b.Parent = parent
	corner(b, 10)
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = rgb(255, 255, 255)
	edge.Transparency = 0.84
	edge.Thickness = 1
	edge.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 48)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = b
	local disc = Instance.new("TextLabel")
	disc.Name = "Letter"
	disc.AnchorPoint = Vector2.new(0, 0.5)
	disc.Position = UDim2.new(0, -40, 0.5, 0)
	disc.Size = UDim2.fromOffset(30, 30)
	disc.BackgroundColor3 = GOLD
	disc.TextColor3 = rgb(26, 16, 4)
	disc.FontFace = Brand.Fonts.heavy
	disc.TextSize = 15
	disc.Text = letter
	disc.Parent = b
	corner(disc, 15)
	b.MouseEnter:Connect(function()
		if edge.Thickness < 2 then
			edge.Color = GOLD
			edge.Transparency = 0.3
		end
	end)
	b.MouseLeave:Connect(function()
		if edge.Thickness < 2 then
			edge.Color = rgb(255, 255, 255)
			edge.Transparency = 0.84
		end
	end)
	b.Activated:Connect(onPress)
	return b
end

-- Luxury Trivia's question at the podium: four answers, the time counted down.
local function questionCard(m: { [string]: any })
	local _, inner = liveCard(208, GOLD)
	local head = label(inner, "Heading", string.format("QUESTION %d OF %d", tonumber(m.n) or 1, tonumber(m.of) or Plan.TRIVIA_QUESTIONS), 12, Brand.Fonts.bodyBold, GOLD)
	head.LayoutOrder = 1
	local q = label(inner, "Question", tostring(m.q or ""), 18, Brand.Fonts.display, C.bone)
	q.LayoutOrder = 2
	q.Size = UDim2.new(1, 0, 0, 48)
	q.TextWrapped = true
	q.TextTruncate = Enum.TextTruncate.None
	q.TextXAlignment = Enum.TextXAlignment.Center
	local grid = Instance.new("Frame")
	grid.Name = "Answers"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 104)
	grid.LayoutOrder = 3
	grid.Parent = inner
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -5, 0, 46)
	layout.CellPadding = UDim2.fromOffset(10, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local buttons: { TextButton } = {}
	local answered = false
	for i, text in (if type(m.choices) == "table" then m.choices else {}) do
		local letter = ({ "A", "B", "C", "D" })[i]
		local b = answerKey(grid, letter, tostring(text), function()
			if answered or not m.seated then
				return
			end
			answered = true
			for j, other in buttons do
				other.TextTransparency = if j == i then 0 else 0.55
				local edge = other:FindFirstChildOfClass("UIStroke")
				if edge and j == i then
					edge.Color = GOLD
					edge.Transparency = 0
					edge.Thickness = 2
				end
			end
			task.spawn(function()
				local r = act({ act = "answer", n = i })
				if r and r.ok ~= true then
					Toast.show("Luxury Trivia", tostring(r.why or "Not just now."), 2.5)
				end
			end)
		end)
		b.Name = "Answer" .. letter
		b.LayoutOrder = i
		buttons[i] = b
	end
	trivia.buttons = buttons
	local my = liveTick
	local seconds = tonumber(m.left) or Plan.TRIVIA_ANSWER
	task.spawn(function()
		for left = math.floor(seconds), 0, -1 do
			if liveTick ~= my or not head.Parent then
				return
			end
			head.Text = string.format("QUESTION %d OF %d  ·  %ds", tonumber(m.n) or 1, tonumber(m.of) or Plan.TRIVIA_QUESTIONS, left)
			if left <= 3 and left > 0 then
				Sound.play("tick", 0.4)
			end
			task.wait(1)
		end
	end)
end

-- The Runway's vote: the models' faces and names, one vote (never your own look).
local function voteCard(m: { [string]: any })
	local models = if type(m.models) == "table" then m.models else {}
	local _, inner = liveCard(196, rgb(200, 150, 255))
	local head = label(inner, "Heading", "THE ROOM VOTES  ·  " .. string.upper(tostring(m.theme or "")), 12, Brand.Fonts.bodyBold, rgb(200, 150, 255))
	head.LayoutOrder = 1
	local line = label(inner, "Line", "Whose look wore the theme best? One vote, never for your own.", 13, Brand.Fonts.body, C.smoke)
	line.LayoutOrder = 2
	local row = Instance.new("Frame")
	row.Name = "Models"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 120)
	row.LayoutOrder = 3
	row.Parent = inner
	Theme.list(row, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local cells: { [number]: TextButton } = {}
	for i, md in models do
		local uid = tonumber(md.userId) or 0
		local cell = Instance.new("TextButton")
		cell.Name = "Model" .. i
		cell.Text = ""
		cell.AutoButtonColor = false
		cell.BackgroundColor3 = rgb(30, 24, 30)
		cell.BackgroundTransparency = 0.2
		cell.Size = UDim2.fromOffset(92, 116)
		cell.LayoutOrder = i
		cell.Parent = row
		corner(cell, 10)
		stroke(cell, rgb(200, 150, 255), 0.7)
		local face = Instance.new("ImageLabel")
		face.Name = "Face"
		face.BackgroundColor3 = rgb(50, 40, 50)
		face.Size = UDim2.fromOffset(64, 64)
		face.Position = UDim2.new(0.5, -32, 0, 8)
		face.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", uid)
		face.Parent = cell
		corner(face, 32)
		local name = label(cell, "Name", tostring(md.name or ""), 13, Brand.Fonts.bodyBold, C.bone)
		name.Position = UDim2.fromOffset(4, 78)
		name.Size = UDim2.new(1, -8, 0, 18)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local mine = uid == player.UserId
		local word = label(cell, "Word", if mine then "YOUR LOOK" else "VOTE", 10, Brand.Fonts.bodyBold, if mine then C.smoke else rgb(200, 150, 255))
		word.Position = UDim2.fromOffset(4, 96)
		word.Size = UDim2.new(1, -8, 0, 14)
		word.TextXAlignment = Enum.TextXAlignment.Center
		cells[uid] = cell
		cell.Activated:Connect(function()
			if mine then
				Toast.show("The Runway", "Vote for someone else's look.", 2.5)
				return
			end
			task.spawn(function()
				local r = act({ act = "vote", what = "runway", n = uid })
				if r and r.ok == true then
					for other, c in cells do
						local s = c:FindFirstChildOfClass("UIStroke")
						if s then
							s.Transparency = if other == uid then 0 else 0.7
							s.Color = if other == uid then GOLD else rgb(200, 150, 255)
						end
						local w = c:FindFirstChild("Word")
						if w and w:IsA("TextLabel") and other ~= player.UserId then
							w.Text = if other == uid then "YOUR VOTE" else "VOTE"
							w.TextColor3 = if other == uid then GOLD else rgb(200, 150, 255)
						end
					end
				elseif r then
					Toast.show("The Runway", tostring(r.why or "Not just now."), 2.5)
				end
			end)
		end)
	end
	local my = liveTick
	local seconds = tonumber(m.left) or Plan.RUNWAY_VOTE
	task.spawn(function()
		for left = math.floor(seconds), 0, -1 do
			if liveTick ~= my or not head.Parent then
				return
			end
			head.Text = string.format("THE ROOM VOTES  ·  %s  ·  %ds", string.upper(tostring(m.theme or "")), left)
			task.wait(1)
		end
	end)
end

local function place1(n: number): string
	local s = tostring(n)
	local last = n % 10
	local tens = n % 100
	if tens >= 11 and tens <= 13 then
		return s .. "th"
	end
	return s .. (if last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th")
end

---------------------------------------------------------------------------------------------------
-- What the server says
---------------------------------------------------------------------------------------------------
function GalaHud.on(m: { [string]: any })
	local kind = m.kind
	if kind == "juke" then
		view.juke = m
		draw()
	elseif kind == "trivia" then
		local phase = m.phase
		view.trivia = view.trivia or {}
		view.trivia.phase = phase
		if phase == "question" then
			trivia.q = m
			if m.seated then
				questionCard(m)
			end
		elseif phase == "reveal" then
			local buttons = trivia.buttons
			if live and type(buttons) == "table" then
				-- The right answer lit green and marked RIGHT; a wrong pick of this guest's, red.
				for i, b in buttons do
					local verdict: string? = nil
					if i == m.right then
						b.BackgroundColor3 = rgb(22, 74, 44)
						b.TextTransparency = 0
						verdict = "RIGHT"
					elseif i == m.mine then
						b.BackgroundColor3 = rgb(86, 24, 30)
						verdict = "YOUR ANSWER"
					end
					if verdict then
						local tag = label(b, "Verdict", verdict, 10, Brand.Fonts.heavy, if i == m.right then GOOD else BAD)
						tag.AnchorPoint = Vector2.new(1, 0.5)
						tag.Position = UDim2.new(1, 0, 0.5, 0)
						tag.Size = UDim2.fromOffset(84, 14)
						tag.TextXAlignment = Enum.TextXAlignment.Right
					end
				end
			end
			if m.correct ~= nil then
				Sound.play(if m.correct then "chime" else "wrong", 0.55)
				if m.correct and (tonumber(m.paid) or 0) > 0 then
					Toast.show("Right", string.format("+%d Gilt  ·  %s points", tonumber(m.paid) or 0, Plan.commas(tonumber(m.score) or 0)), 2.2)
				end
			end
		elseif phase == "lobby" then
			view.trivia.seats = m.seats
			if m.mine == true then
				view.busy = "trivia"
				view.trivia.seated = true
				banner("LUXURY TRIVIA", string.format("%d at the podiums. Answer on your screen: quick and right scores most.", tonumber(m.seats) or 1), GOLD, tonumber(m.left), { "Leave the podium", "trivia" })
			end
		elseif phase == "results" then
			trivia.buttons = nil
			local winners = if type(m.winners) == "table" then m.winners else {}
			local mine = m.mine
			if type(mine) == "table" then
				local won = mine.won == true
				banner(if won then "YOU WIN LUXURY TRIVIA" else "LUXURY TRIVIA", string.format("%s  ·  %s points, %d right%s", if won then "The winner" else place1(tonumber(mine.place) or 1) .. " place", Plan.commas(tonumber(mine.score) or 0), tonumber(mine.right) or 0, if #winners > 0 and not won then "  ·  " .. table.concat(winners, " & ") .. " wins" else ""), GOLD)
				if won then
					Sound.play("celebrate", 0.7)
				end
				task.delay(Plan.TRIVIA_RESULTS, function()
					if live and live.Name == "GalaLive" then
						clearLive()
					end
				end)
			end
			view.busy = nil
			view.trivia.seated = false
		elseif phase == "idle" then
			if view.busy == "trivia" then
				view.busy = nil
			end
			view.trivia.seated = false
		end
		draw()
		drawKeys()
	elseif kind == "runway" then
		local phase = m.phase
		view.runway = view.runway or {}
		view.runway.phase = phase
		if phase == "signup" then
			view.runway.theme = m.theme
			if m.mine == true then
				view.busy = "runway"
				view.runway.mine = true
				banner("THE RUNWAY  ·  " .. string.upper(tostring(m.theme or "")), string.format("%s  %s", tostring(m.line or ""), if m.waiting then "One more model and the show begins." else string.format("%d model%s signed.", tonumber(m.models) or 1, if (tonumber(m.models) or 1) == 1 then "" else "s")), rgb(200, 150, 255), tonumber(m.left), { "Leave the show", "runway" })
			end
		elseif phase == "walk" then
			if tonumber(m.userId) == player.UserId then
				banner("YOUR TURN  ·  " .. string.upper(tostring(m.theme or "")), "Walk down the catwalk to the gold mark at the end, and strike a pose (Dance & music has the moves).", GOLD, tonumber(m.left))
				Sound.play("shimmer", 0.6)
			else
				banner("NOW WALKING  ·  " .. string.upper(tostring(m.theme or "")), string.format("%s  ·  %d of %d", tostring(m.name or ""), tonumber(m.n) or 1, tonumber(m.of) or 1), rgb(200, 150, 255), tonumber(m.left))
			end
		elseif phase == "vote" then
			voteCard(m)
		elseif phase == "results" then
			local winner = m.winner
			if type(winner) == "string" then
				local mine = tonumber(m.winnerId) == player.UserId
				banner(if mine then "YOU TAKE THE SHOW" else "THE RUNWAY  ·  " .. string.upper(tostring(m.theme or "")), if mine then "The room voted your look the best of " .. tostring(m.theme or "the show") .. "." else winner .. " takes the show.", GOLD)
				if mine then
					Sound.play("celebrate", 0.7)
				end
			else
				banner("THE RUNWAY", "No votes this time: every model walked beautifully.", rgb(200, 150, 255))
			end
			task.delay(Plan.RUNWAY_RESULTS, function()
				if live and live.Name == "GalaLive" then
					clearLive()
				end
			end)
			if view.busy == "runway" then
				view.busy = nil
			end
			view.runway.mine = false
		elseif phase == "idle" then
			if view.busy == "runway" then
				view.busy = nil
			end
			view.runway.theme = nil
			view.runway.mine = false
		end
		draw()
		drawKeys()
	elseif kind == "arena" then
		local phase = m.phase
		view.arena = view.arena or {}
		view.arena.phase = phase
		view.arena.challenge = m.challenge or view.arena.challenge
		local ch = Plan.challengeById[tostring(view.arena.challenge or "")] or Plan.challengeFor(Plan.day())
		if m.mine == true and (phase == "countdown" or phase == "play") then
			view.busy = "arena"
			view.arena.mine = true
		end
		if phase == "countdown" and view.busy == "arena" then
			banner("THE DAILY ARENA  ·  " .. string.upper(ch.name), string.format("%s  %d in the next round.", ch.how, tonumber(m.players) or 1), ch.colour, tonumber(m.left), { "Leave the round", "arena" })
		elseif phase == "play" and view.busy == "arena" then
			arena.rank = nil
			banner(string.upper(ch.name), ch.how, ch.colour, tonumber(m.left))
		elseif phase == "score" and view.busy == "arena" then
			local rows = if type(m.rows) == "table" then m.rows else {}
			for i, row in rows do
				if row.userId == player.UserId then
					local l = live
					local line = l and l:FindFirstChild("Line", true)
					if line and line:IsA("TextLabel") then
						line.Text = string.format("%d points  ·  %s of %d  ·  %s", tonumber(row.points) or 0, place1(i), #rows, ch.how)
					end
				end
			end
		elseif phase == "results" then
			local rows = if type(m.rows) == "table" then m.rows else {}
			for i, row in rows do
				if row.userId == player.UserId then
					local won = row.won == true
					banner(if won then "YOU WIN THE ARENA" else "THE DAILY ARENA", string.format("%s  ·  %d points  ·  +%d Gilt", if won then "The winner" else place1(i) .. " place", tonumber(row.points) or 0, tonumber(row.paid) or 0), ch.colour)
					if won then
						Sound.play("celebrate", 0.7)
					end
					task.delay(Plan.ARENA_RESULTS, function()
						if live and live.Name == "GalaLive" then
							clearLive()
						end
					end)
				end
			end
			if view.busy == "arena" then
				view.busy = nil
			end
			view.arena.mine = false
		elseif phase == "idle" then
			if view.busy == "arena" then
				view.busy = nil
			end
			view.arena.mine = false
		end
		draw()
		drawKeys()
	elseif kind == "danced" then
		local paid = tonumber(m.paid) or 0
		Toast.show("A minute on the dance floor", string.format("%s%d of %d today", if paid > 0 then string.format("+%d Gilt  ·  ", paid) else "", tonumber(m.minutes) or 0, tonumber(m.of) or Plan.REWARDS.danceMinutes), 2.6)
	elseif kind == "pose" then
		local paid = tonumber(m.paid) or 0
		Toast.show(tostring(m.name or "A photo set"), string.format("%d of %d photo sets%s", tonumber(m.sets) or 0, tonumber(m.of) or #Plan.PhotoSets, if paid > 0 then string.format("  ·  +%d Gilt", paid) else ""), 3)
	end
end

-- The state from the server: the whole hall at once.
function GalaHud.update(st: { [string]: any })
	view = st
	draw()
	drawKeys()
end

---------------------------------------------------------------------------------------------------
-- Mount and unmount
---------------------------------------------------------------------------------------------------
function GalaHud.mounted(): boolean
	return card ~= nil
end

local function watchZone()
	local my = coroutine.running()
	zoneConn = my
	while card and zoneConn == my do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local o = ((Config.data :: any).Attractions.gala or {}).origin
		if root and root:IsA("BasePart") and type(o) == "table" then
			local z = Plan.zoneAt(root.Position - Vector3.new(o[1], o[2], o[3]))
			if z ~= zone then
				zone = z
				draw()
				drawKeys()
			end
		end
		-- (The record's clock, second by second.)
		if type(view.juke) == "table" then
			local left = tonumber(view.juke.changeIn)
			if left and left > 0 then
				view.juke.changeIn = left - 0.5
			end
			draw()
		end
		task.wait(0.5)
	end
end

function GalaHud.mount()
	if card then
		return
	end
	local c = Instance.new("Frame")
	c.Name = "GalaCard"
	c.AnchorPoint = Vector2.new(0.5, 0)
	c.Size = UDim2.fromOffset(CARD_W, CARD_H)
	c.Parent = Root.hud
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 10)
	pad.Parent = c
	HudCard.style(c, GOLD)
	local title = label(c, "Title", "THE GRAND BALLROOM", 11, Brand.Fonts.heavy, GOLD)
	title.Position = UDim2.fromOffset(0, 0)
	title.Size = UDim2.new(0.55, 0, 0, 16)
	parts.zone = label(c, "Zone", "", 10, Brand.Fonts.bodyBold, WARM)
	parts.zone.TextXAlignment = Enum.TextXAlignment.Right
	parts.zone.AnchorPoint = Vector2.new(1, 0)
	parts.zone.Position = UDim2.new(1, 0, 0, 1)
	parts.zone.Size = UDim2.new(0.45, 0, 0, 15)
	parts.record = label(c, "Record", "", 12, Brand.Fonts.body, C.bone)
	parts.record.Position = UDim2.fromOffset(0, 21)
	parts.record.Size = UDim2.new(1, 0, 0, 16)
	parts.gilt = label(c, "TodayGilt", "", 11, Brand.Fonts.bodyBold, C.smoke)
	parts.gilt.Position = UDim2.fromOffset(0, 39)
	parts.gilt.Size = UDim2.new(1, 0, 0, 15)
	local row = Instance.new("Frame")
	row.Name = "Activities"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 60)
	row.Size = UDim2.new(1, 0, 0, 28 * 3 + 8)
	row.Parent = c
	Theme.list(row, 4)
	parts.trivia, parts.triviaWord = chip(row, "Trivia", 1)
	parts.runway, parts.runwayWord = chip(row, "Runway", 2)
	parts.arena, parts.arenaWord = chip(row, "Arena", 3)
	card = c

	local k = Instance.new("Frame")
	k.Name = "GalaKeys"
	k.AnchorPoint = Vector2.new(0.5, 1)
	k.BackgroundTransparency = 1
	k.Size = UDim2.fromOffset(680, 44)
	k.Parent = Root.hud
	Theme.list(k, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	keys = k
	place()
	draw()
	drawKeys()
	topConn = Root.TopChanged:Connect(place)
	task.spawn(watchZone)
end

function GalaHud.unmount()
	if topConn then
		topConn:Disconnect()
		topConn = nil
	end
	zoneConn = nil
	clearLive()
	if card then
		card:Destroy()
		card = nil
	end
	if keys then
		keys:Destroy()
		keys = nil
	end
	parts = {}
	trivia, arena = {}, {}
end

return GalaHud

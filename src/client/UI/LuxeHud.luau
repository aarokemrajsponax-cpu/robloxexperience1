--!strict
-- Steal a Luxe's own screen, shown only while a guest is in the residence (the server's
-- "Attraction" attribute). Build 78: a card at the bottom left (lifted clear of a phone's thumbstick,
-- clear of the dock down the left): which wing they're in, the bag (a slot for each piece it holds,
-- each in its grade's colour), what it's all worth and its weight, how near a guard is to noticing
-- them, the wing's alarm (Alert, Lockdown) and the run's three side jobs. Two keys at the foot of the
-- screen: Leave and Upgrades.
-- It also does what only a screen can: each piece's prompt holds as long as its lift takes from
-- where the guest stands (shared/Luxe holdFor: the server checks the same); an empty plinth shows
-- when its piece is back; a lift, a haul banked, a guard's notice and a lockdown each have their
-- moment (a flash where the piece stood, its worth rising, a sound, the alarm's music).
-- Everything it shows is what the server last said (op "luxe"); it decides nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Plan = require(ReplicatedStorage.Shared.Luxe)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Sound = require(script.Parent.Parent.Sound)
local HudCard = require(script.Parent.HudCard)
local LuxeLift = require(script.Parent.LuxeLift)
local Sleepers = require(script.Parent.Parent.World.LuxeSleepers)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local LuxeHud = {}

-- Set by Main: open the upgrades board.
LuxeHud.openBoard = function() end

local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local RED = Color3.fromRGB(235, 70, 80)
local AMBER = Color3.fromRGB(255, 176, 60)
local GREEN = Color3.fromRGB(120, 220, 140)
-- (Build 102: a little wider on a big screen; on a phone as it was, so it never meets the keys.)
local function cardW(): number
	return if Root.phone() then 316 else 344
end
local SLOT = 34
local PAD = 14

local RARITY: { [string]: Color3 } = {}
for _, r in Plan.Rarities do
	RARITY[r.id] = r.colour
end
RARITY.Mythic = Color3.fromRGB(255, 90, 140) -- (older saves' word for the finest)
LuxeHud.RARITY = RARITY

type View = { [string]: any }

local function fresh(): View
	return { bag = {}, capacity = 3, worth = 0, bonus = 0, wing = "The courtyard", wingId = 0, watched = 0, chased = false, speed = 1, grace = false, alarm = 0, goals = {}, mass = 0, hands = 1 }
end

local card: Frame? = nil
local keys: Frame? = nil
local parts: { [string]: any } = {}
local view: View = fresh()
local beat: RBXScriptConnection? = nil
local topConn: RBXScriptConnection? = nil
local lastAlarm = 0
local backIns: { [BasePart]: BillboardGui } = {}

local function label(parent: Instance, name: string, text: string, size: number, font: Font, colour: Color3, order: number?): TextLabel
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
	l.LayoutOrder = order or 0
	l.Parent = parent
	return l
end

local function row(parent: Instance, name: string, height: number, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 0, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	return f
end

-- At the bottom left: beside the dock down the left, above whatever stands along the foot of the
-- screen, and on a phone or tablet lifted clear of the thumbstick (it lives in that corner). When
-- the screen is too short for the side jobs as well, they fold to a single line.
local function place()
	local c = card
	if not c then
		return
	end
	local size = Root.size()
	-- (The bottom-left corner, like every attraction's card: UI/HudCard.)
	HudCard.place(c, 150)
	local x = c.Position.X.Offset
	-- (Build 102) Its room: from where it wants to stand (clear of a phone's thumbstick) up to
	-- whatever is above it, the Gilt and the Fortune included; the side jobs fold when it's short.
	local bottom = math.min(HudCard.lift, Root.bottomClear() + math.max(HudCard.MARGIN, size.Y * 0.2))
	local roof = math.max(Root.topClearAt(x, x + cardW()) + 8, Root.leftTop + 6)
	local room = size.Y - bottom - roof
	local fold = (tonumber(parts.fullHeight) or 0) > room
	if fold ~= (parts.folded == true) then
		parts.folded = fold
		LuxeHud.draw()
	end
	local k = keys
	if k then
		k.Position = UDim2.new(0.5, 0, 1, -(14 + Root.bottomClear()))
	end
end

local function wingColour(id: number): Color3
	local w = Plan.Wings[id]
	return if w then w.colour else C.bone
end

-- A side job's mark: a ring, filled green once it's done.
local function tick(parent: Instance, done: boolean): Frame
	local ring = Instance.new("Frame")
	ring.Name = "Mark"
	ring.AnchorPoint = Vector2.new(0, 0.5)
	ring.Position = UDim2.new(0, 0, 0.5, 0)
	ring.Size = UDim2.fromOffset(12, 12)
	ring.BackgroundColor3 = GREEN
	ring.BackgroundTransparency = if done then 0 else 1
	ring.BorderSizePixel = 0
	ring.Parent = parent
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = ring
	local edge = Instance.new("UIStroke")
	edge.Color = if done then GREEN else Color3.fromRGB(150, 138, 118)
	edge.Thickness = 1.5
	edge.Parent = ring
	return ring
end

-- The side jobs, from `y` down: returns where they end (and, unfolded, where they would).
local function drawJobs(y: number): (number, number)
	local jobs = parts.jobs :: Frame
	for _, child in jobs:GetChildren() do
		if child:IsA("GuiObject") and child.Name ~= "JobsTitle" and child.Name ~= "JobsCount" and child.Name ~= "Rule" then
			child:Destroy()
		end
	end
	local goals = if type(view.goals) == "table" then view.goals else {}
	jobs.Visible = #goals > 0
	if #goals == 0 then
		return y, y
	end
	jobs.Position = UDim2.fromOffset(0, y)
	local done = 0
	for _, g in goals do
		if g.done then
			done += 1
		end
	end
	parts.jobsCount.Text = string.format("%d of %d", done, #goals)
	local TOP = 26 -- the rule and the title
	local ROW = 20
	local full = TOP + #goals * ROW
	local function jobRow(i: number, g: { [string]: any })
		local r = Instance.new("Frame")
		r.Name = "Job" .. i
		r.BackgroundTransparency = 1
		r.Position = UDim2.fromOffset(0, TOP + ROW * (i - 1))
		r.Size = UDim2.new(1, 0, 0, ROW)
		r.Parent = jobs
		tick(r, g.done == true)
		local line = label(r, "Line", tostring(g.line), 12, if g.done then Brand.Fonts.body else Brand.Fonts.bodyBold, if g.done then C.smoke else C.bone)
		line.Position = UDim2.fromOffset(20, 0)
		line.Size = UDim2.new(1, -78, 1, 0)
		local pay = label(r, "Pay", "+" .. Rules.format(tonumber(g.gilt) or 0), 12, Brand.Fonts.figures, if g.done then C.smoke else GOLD)
		pay.TextXAlignment = Enum.TextXAlignment.Right
		pay.Size = UDim2.new(1, 0, 1, 0)
	end
	if parts.folded then
		-- (Too little room: only the next one still to do.)
		for _, g in goals do
			if not g.done then
				jobRow(1, g)
				jobs.Size = UDim2.new(1, 0, 0, TOP + ROW)
				return y + TOP + ROW, y + full
			end
		end
		jobs.Size = UDim2.new(1, 0, 0, TOP)
		return y + TOP, y + full
	end
	for i, g in goals do
		jobRow(i, g)
	end
	jobs.Size = UDim2.new(1, 0, 0, full)
	return y + full, y + full
end

function LuxeHud.draw()
	local c = card
	if not c then
		return
	end
	local wingId = tonumber(view.wingId) or 0
	parts.wing.Text = tostring(view.wing)
	local wc = if wingId > 0 then wingColour(wingId) else C.bone
	parts.wing.TextColor3 = wc
	parts.badge.BackgroundColor3 = wc
	parts.badge.Size = UDim2.fromOffset(math.clamp(#tostring(view.wing) * 7 + 24, 90, 170), 22)
	-- The bag: a slot for each piece it can hold.
	local slots = parts.slots :: Frame
	for _, child in slots:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local capacity = math.max(1, math.floor(tonumber(view.capacity) or 3))
	local bag = if type(view.bag) == "table" then view.bag else {}
	-- (A big bag's slots are smaller, so they all fit on their row.)
	local size = math.min(SLOT, math.floor((cardW() - PAD * 2 - 56 + 6) / capacity) - 6)
	for i = 1, capacity do
		local piece = bag[i]
		local s = Instance.new("Frame")
		s.Name = "Slot" .. i
		s.Size = UDim2.fromOffset(size, size)
		s.BackgroundColor3 = if piece then Color3.fromRGB(34, 28, 20) else Color3.fromRGB(22, 21, 26)
		s.BackgroundTransparency = if piece then 0 else 0.3
		s.LayoutOrder = i
		s.Parent = slots
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = s
		local edge = Instance.new("UIStroke")
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = if piece then (RARITY[tostring(piece.rarity)] or GOLD) else Color3.fromRGB(80, 74, 66)
		edge.Thickness = if piece then 1.8 else 1
		edge.Transparency = if piece then 0 else 0.4
		edge.Parent = s
		if piece then
			-- (Lit in its rarity's colour from the top, darkening to the foot.)
			local lit = Instance.new("UIGradient")
			lit.Rotation = 90
			local rc = RARITY[tostring(piece.rarity)] or GOLD
			lit.Color = ColorSequence.new(rc:Lerp(Color3.new(0, 0, 0), 0.45), Color3.fromRGB(26, 22, 16))
			lit.Parent = s
			s.BackgroundColor3 = Color3.new(1, 1, 1)
			local g = Instance.new("TextLabel")
			g.Name = "Glyph"
			g.BackgroundTransparency = 1
			g.Size = UDim2.fromScale(1, 1)
			g.Text = tostring(piece.glyph or "✨")
			g.TextSize = 20
			g.FontFace = Brand.Fonts.body
			g.TextColor3 = Color3.new(1, 1, 1)
			g.Parent = s
		end
	end
	-- (Build 102) The bag's reward: exactly the Gilt banking it pays (each piece's, locked as it
	-- was lifted, with every boost in it). No Estate sums, nothing to work out.
	local bagGilt = tonumber(view.gilt) or 0
	parts.count.Text = string.format("%d/%d", #bag, capacity)
	if #bag == 0 then
		parts.worth.Text = "LIFT A PIECE"
		parts.worth.TextColor3 = C.smoke
		parts.worth.FontFace = Brand.Fonts.bodyBold
		parts.worth.TextSize = 13
		parts.extra.Text = "then bank it at a way out"
	else
		local mass = tonumber(view.mass) or 0
		parts.worth.Text = "+" .. Rules.format(bagGilt) .. " GILT"
		parts.worth.TextColor3 = GOLD
		parts.worth.FontFace = Brand.Fonts.display
		parts.worth.TextSize = 20
		local bits = { "when you bank it" }
		if mass >= 1 then
			table.insert(bits, if mass >= 10 then tostring(math.floor(mass + 0.5)) .. " kg" else string.format("%.1f kg", mass))
		end
		parts.extra.Text = table.concat(bits, "  ·  ")
	end
	-- The guards: one plain line with a coloured dot, and how near they are to noticing.
	local watched = math.clamp(tonumber(view.watched) or 0, 0, 1)
	parts.fill.Size = UDim2.new(watched, 0, 1, 0)
	-- (Its colour runs gold to red along the track itself.)
	local status, colour
	if view.chased then
		status, colour = "Run, a guard is after you", RED
	elseif view.grace then
		status, colour = "Nobody has noticed you yet", C.smoke
	elseif view.awake == false then
		-- (Build 82: security sleeps until they lift something.)
		status, colour = "Security asleep, look around", Color3.fromRGB(140, 220, 160)
	elseif watched > 0.05 then
		status, colour = "A guard is noticing you", Color3.fromRGB(255, 196, 80)
	else
		status, colour = "Unseen", C.smoke
	end
	parts.seen.Text = status
	parts.seen.TextColor3 = if colour == C.smoke then C.bone else colour
	parts.dot.BackgroundColor3 = colour
	local speed = tonumber(view.speed) or 1
	local pct = math.floor(speed * 100 + 0.5)
	parts.pace.Text = if pct ~= 100 then string.format("Pace %d%%", pct) else ""
	-- The wing's alarm.
	local alarm = tonumber(view.alarm) or 0
	local banner = parts.alarm :: Frame
	banner.Visible = alarm > 0
	parts.alarmText.Text = ""
	if alarm >= 2 then
		banner.BackgroundColor3 = Color3.fromRGB(70, 14, 20)
		parts.alarmText.Text = "Lockdown: more guards are coming. Get out."
		parts.alarmText.TextColor3 = Color3.fromRGB(255, 130, 130)
	elseif alarm == 1 then
		banner.BackgroundColor3 = Color3.fromRGB(60, 40, 12)
		parts.alarmText.Text = "Alert: the guards are looking for you"
		parts.alarmText.TextColor3 = AMBER
	end
	-- Laid out top to bottom (the card grows upward from its foot).
	local y = 0
	parts.head.Position = UDim2.fromOffset(0, y)
	parts.headRule.Position = UDim2.fromOffset(0, y + 25)
	y += if Root.phone() then 28 else 32
	if alarm > 0 then
		banner.Position = UDim2.fromOffset(0, y)
		y += 30
	end
	slots.Position = UDim2.fromOffset(0, y)
	parts.count.Position = UDim2.new(1, 0, 0, y)
	y += SLOT + 8
	parts.worthRow.Position = UDim2.fromOffset(0, y)
	-- (On a phone the panel is one line, no kicker: the screen is short and the side jobs come too.)
	local compact = Root.phone()
	local kick = parts.worthRow:FindFirstChild("Kicker")
	if kick then
		kick.Visible = not compact
	end
	parts.worthRow.Size = UDim2.new(1, 0, 0, if compact then 24 else 46)
	parts.worth.Position = UDim2.fromOffset(0, if compact then 0 else 18)
	parts.extra.Position = UDim2.fromOffset(0, if compact then 0 else 18)
	y += if compact then 26 else 54
	parts.seenRow.Position = UDim2.fromOffset(0, y)
	y += 22
	parts.track.Position = UDim2.fromOffset(0, y)
	y += 5 + 6
	local ends, unfolded = drawJobs(y)
	c.Size = UDim2.fromOffset(cardW(), ends + 12 + 10)
	parts.fullHeight = unfolded + 12 + 10
end

-- An empty plinth's quiet countdown: when its piece is back (its own five minutes).
local function countdowns()
	local res = Workspace:FindFirstChild("Attractions")
	local luxe = res and res:FindFirstChild("StealALuxe")
	local plinths = luxe and luxe:FindFirstChild("Plinths")
	if not plinths then
		return
	end
	local ok, serverNow = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	if not ok then
		return
	end
	for _, d in plinths:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Top" then
			local at = d:GetAttribute("BackAt")
			local gui = backIns[d]
			if type(at) == "number" and at > serverNow then
				if not gui then
					local g = Instance.new("BillboardGui")
					g.Name = "BackIn"
					g.Size = UDim2.new(3, 40, 0.5, 10)
					g.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
					g.MaxDistance = 40
					g.LightInfluence = 0
					local t = Instance.new("TextLabel")
					t.Name = "Text"
					t.BackgroundTransparency = 1
					t.Size = UDim2.fromScale(1, 1)
					t.FontFace = Brand.Fonts.figures
					t.TextScaled = true
					t.TextColor3 = Color3.fromRGB(200, 196, 190)
					t.TextTransparency = 0.25
					t.Parent = g
					g.Parent = d
					backIns[d] = g
					gui = g
				end
				local left = math.max(0, math.ceil(at - serverNow))
				local text = (gui :: BillboardGui):FindFirstChild("Text")
				if text and text:IsA("TextLabel") then
					text.Text = string.format("back in %d:%02d", left // 60, left % 60)
				end
			elseif gui then
				gui:Destroy()
				backIns[d] = nil
			end
		end
	end
end

-- Each piece's prompt holds for its lift from where the guest stands (the farther the reach, the
-- longer; Quick Hands, shorter), as the server works it out.
local function holds()
	local res = Workspace:FindFirstChild("Attractions")
	local luxe = res and res:FindFirstChild("StealALuxe")
	local pieces = luxe and luxe:FindFirstChild("Pieces")
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local cfg = (Config.data.Attractions :: any).luxe
	if not pieces or not hrp or not hrp:IsA("BasePart") or type(cfg) ~= "table" or type(cfg.hold) ~= "table" then
		return
	end
	local hands = tonumber(view.hands) or 1
	for _, d in pieces:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "Take" then
			local piece = Plan.byId[tostring(d:GetAttribute("Piece"))]
			local at = d.Parent
			if piece and at and at:IsA("BasePart") then
				local top = at.Position - Vector3.new(0, 1.675, 0)
				local distance = (hrp.Position - top).Magnitude
				if distance < (tonumber(cfg.reach) or 11) + 8 then
					local want = Plan.holdFor(piece, distance, hands, cfg.hold)
					if math.abs(d.HoldDuration - want) > 0.05 then
						d.HoldDuration = want
					end
				end
			end
		end
	end
end

-- A lift's moment where the piece stood: a flash in its grade's colour, and its worth rising.
local function flash(at: Vector3, colour: Color3, text: string)
	local folder = Workspace.CurrentCamera or Workspace
	local p = Instance.new("Part")
	p.Name = "LiftFlash"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.Neon
	p.Color = colour
	p.Transparency = 0.2
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at + Vector3.new(0, 2, 0))
	p.Parent = folder
	local g = Instance.new("BillboardGui")
	g.Name = "Worth"
	g.Size = UDim2.new(4, 60, 1, 14)
	g.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	g.AlwaysOnTop = true
	g.LightInfluence = 0
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Brand.Fonts.display
	t.TextScaled = true
	t.TextColor3 = colour
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = g
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(p, info, { Size = Vector3.new(6, 6, 6), Transparency = 1 }):Play()
	TweenService:Create(g, info, { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function()
		p:Destroy()
	end)
end

-- (Build 102) The guest's banker's bonus (each piece's Gilt includes it), for a piece's prompt.
function LuxeHud.bankerBonus(): number
	return tonumber(view.bonus) or 0
end

function LuxeHud.mounted(): boolean
	return card ~= nil
end

function LuxeHud.mount()
	if card then
		return
	end
	-- (Build 89) The lift as it happens: what's coming off the plinth, and the security round it.
	LuxeLift.mount()
	LuxeLift.alarm = function(): number
		return tonumber(view.alarm) or 0
	end
	LuxeLift.awake = function(): boolean
		return view.awake == true
	end
	LuxeLift.restless = function(): string?
		local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			return (Sleepers.restless(hrp.CFrame.Position, 20))
		end
		return nil
	end
	local c = Instance.new("Frame")
	c.Name = "LuxeCard"
	c.AnchorPoint = Vector2.new(0, 1)
	c.Size = UDim2.fromOffset(cardW(), 160)
	c.Parent = Root.hud
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD)
	pad.PaddingTop = UDim.new(0, 12)
	pad.Parent = c
	parts.edge = HudCard.style(c, GOLD)
	-- Its heading: the attraction, and the wing as a badge in the wing's colour.
	local head = row(c, "Head", 22, 1)
	local title = label(head, "Title", "STEAL A LUXE", 13, Brand.Fonts.heavy, Color3.new(1, 1, 1))
	title.Size = UDim2.new(0.5, 0, 1, 0)
	-- (Build 102) Its name in metal: ivory to deep gold, with a hairline of gold under the heading.
	local titleMetal = Instance.new("UIGradient")
	titleMetal.Rotation = 90
	titleMetal.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(214, 160, 64))
	titleMetal.Parent = title
	local headRule = Instance.new("Frame")
	headRule.Name = "HeadRule"
	headRule.BorderSizePixel = 0
	headRule.BackgroundColor3 = GOLD
	headRule.Size = UDim2.new(1, 0, 0, 1)
	headRule.Parent = c
	local ruleFade = Instance.new("UIGradient")
	ruleFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) })
	ruleFade.Parent = headRule
	parts.headRule = headRule
	local badge = Instance.new("Frame")
	badge.Name = "WingBadge"
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.Position = UDim2.new(1, 0, 0.5, 0)
	badge.Size = UDim2.fromOffset(150, 22)
	badge.BackgroundColor3 = C.bone
	badge.BackgroundTransparency = 0.88
	badge.BorderSizePixel = 0
	badge.Parent = head
	local bcr = Instance.new("UICorner")
	bcr.CornerRadius = UDim.new(1, 0)
	bcr.Parent = badge
	parts.wing = label(badge, "Wing", "The courtyard", 12, Brand.Fonts.bodyBold, C.bone)
	parts.wing.Size = UDim2.fromScale(1, 1)
	parts.wing.TextXAlignment = Enum.TextXAlignment.Center
	parts.badge = badge
	parts.head = head
	-- The wing's alarm, when there is one.
	local banner = row(c, "Alarm", 24, 2)
	banner.BackgroundTransparency = 0
	banner.BackgroundColor3 = Color3.fromRGB(60, 40, 12)
	banner.Visible = false
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 8)
	bc.Parent = banner
	parts.alarmText = label(banner, "AlarmText", "", 12, Brand.Fonts.bodyBold, AMBER)
	parts.alarmText.Size = UDim2.fromScale(1, 1)
	parts.alarmText.TextXAlignment = Enum.TextXAlignment.Center
	parts.alarm = banner
	-- The bag (a slot for each piece it holds), and how full it is at the right.
	local slots = row(c, "Bag", SLOT, 3)
	slots.Size = UDim2.new(1, -56, 0, SLOT)
	local slotList = Instance.new("UIListLayout")
	slotList.FillDirection = Enum.FillDirection.Horizontal
	slotList.Padding = UDim.new(0, 6)
	slotList.SortOrder = Enum.SortOrder.LayoutOrder
	slotList.VerticalAlignment = Enum.VerticalAlignment.Center
	slotList.Parent = slots
	parts.slots = slots
	parts.count = label(c, "Count", "0/3", 16, Brand.Fonts.display, C.bone)
	parts.count.AnchorPoint = Vector2.new(1, 0)
	parts.count.Size = UDim2.fromOffset(52, SLOT)
	parts.count.TextXAlignment = Enum.TextXAlignment.Right
	-- (Build 102) The bag's reward, in its own gold-edged panel: a small kicker, then the exact
	-- Gilt banking it pays, big; the weight beside it.
	local worthRow = row(c, "WorthRow", 46, 4)
	worthRow.BackgroundTransparency = 0.35
	worthRow.BackgroundColor3 = Color3.fromRGB(38, 30, 16)
	local wc = Instance.new("UICorner")
	wc.CornerRadius = UDim.new(0, 10)
	wc.Parent = worthRow
	local ws = Instance.new("UIStroke")
	ws.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ws.Color = GOLD
	ws.Transparency = 0.55
	ws.Parent = worthRow
	local wp = Instance.new("UIPadding")
	wp.PaddingLeft = UDim.new(0, 10)
	wp.PaddingRight = UDim.new(0, 10)
	wp.Parent = worthRow
	local kicker = label(worthRow, "Kicker", "BAG REWARD", 10, Brand.Fonts.heavy, C.smoke)
	kicker.Position = UDim2.fromOffset(0, 4)
	kicker.Size = UDim2.new(1, 0, 0, 14)
	parts.worth = label(worthRow, "Worth", "", 20, Brand.Fonts.display, GOLD)
	parts.worth.Position = UDim2.fromOffset(0, 18)
	parts.worth.Size = UDim2.new(0.6, 0, 0, 24)
	parts.extra = label(worthRow, "Extra", "", 11, Brand.Fonts.body, C.smoke)
	parts.extra.TextXAlignment = Enum.TextXAlignment.Right
	parts.extra.Position = UDim2.fromOffset(0, 18)
	parts.extra.Size = UDim2.new(1, 0, 0, 24)
	parts.worthRow = worthRow
	-- The guards: a dot in the state's colour, the state in plain words, the pace at the right.
	local seenRow = row(c, "Seen", 18, 5)
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, 0, 0.5, 0)
	dot.Size = UDim2.fromOffset(8, 8)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = C.smoke
	dot.Parent = seenRow
	local dc = Instance.new("UICorner")
	dc.CornerRadius = UDim.new(1, 0)
	dc.Parent = dot
	parts.dot = dot
	parts.seen = label(seenRow, "SeenText", "Unseen", 13, Brand.Fonts.bodyBold, C.bone)
	parts.seen.Position = UDim2.fromOffset(16, 0)
	parts.seen.Size = UDim2.new(1, -86, 1, 0)
	parts.pace = label(seenRow, "Pace", "", 11, Brand.Fonts.body, C.smoke)
	parts.pace.TextXAlignment = Enum.TextXAlignment.Right
	parts.pace.Size = UDim2.fromScale(1, 1)
	parts.seenRow = seenRow
	local track = row(c, "Track", 5, 6)
	track.BackgroundTransparency = 0
	track.BackgroundColor3 = Color3.fromRGB(44, 40, 36)
	track.BorderSizePixel = 0
	local tc = Instance.new("UICorner")
	tc.CornerRadius = UDim.new(1, 0)
	tc.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Parent = track
	local fillShade = Instance.new("UIGradient")
	fillShade.Color = ColorSequence.new(Color3.fromRGB(255, 214, 120), Color3.fromRGB(235, 70, 80))
	fillShade.Parent = fill
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(1, 0)
	fc.Parent = fill
	parts.fill = fill
	parts.track = track
	-- The run's side jobs, under a hairline.
	local jobs = Instance.new("Frame")
	jobs.Name = "Jobs"
	jobs.BackgroundTransparency = 1
	jobs.Size = UDim2.new(1, 0, 0, 0)
	jobs.Visible = false
	jobs.Parent = c
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = C.bone
	rule.BackgroundTransparency = 0.88
	rule.Position = UDim2.fromOffset(0, 4)
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.Parent = jobs
	parts.jobsTitle = label(jobs, "JobsTitle", "SIDE JOBS", 10, Brand.Fonts.heavy, C.smoke)
	parts.jobsTitle.Position = UDim2.fromOffset(0, 9)
	parts.jobsTitle.Size = UDim2.new(1, 0, 0, 14)
	parts.jobsCount = label(jobs, "JobsCount", "", 10, Brand.Fonts.bodyBold, C.smoke)
	parts.jobsCount.Position = UDim2.fromOffset(0, 9)
	parts.jobsCount.Size = UDim2.new(1, 0, 0, 14)
	parts.jobsCount.TextXAlignment = Enum.TextXAlignment.Right
	parts.jobs = jobs
	card = c

	-- Leave and Upgrades, at the foot of the screen.
	local k = Instance.new("Frame")
	k.Name = "LuxeKeys"
	k.AnchorPoint = Vector2.new(0.5, 1)
	k.BackgroundTransparency = 1
	k.Size = UDim2.fromOffset(300, 44)
	k.Parent = Root.hud
	Theme.list(k, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(k, "Leave", false, function()
		task.spawn(function()
			local ok, r = pcall(function()
				return Remotes.func("AttractionAsk"):InvokeServer({ op = "home" })
			end)
			if ok and type(r) == "table" and r.ok ~= true and type(r.why) == "string" then
				Toast.show("Not just now", r.why, 3)
			end
		end)
	end, 130)
	Theme.key(k, "Upgrades", true, function()
		LuxeHud.openBoard()
	end, 130)
	keys = k

	LuxeHud.draw()
	place()
	topConn = Root.TopChanged:Connect(place)
	-- The edge glows red while a guard is after them, amber on Alert, a pulse of red in a lockdown.
	local t = 0
	local tick = 0
	beat = RunService.Heartbeat:Connect(function(dt: number)
		t += dt
		tick += dt
		local e = parts.edge :: UIStroke
		local alarm = tonumber(view.alarm) or 0
		if view.chased or alarm >= 2 then
			e.Color = RED
			e.Transparency = 0.1 + 0.3 * (0.5 + 0.5 * math.sin(t * 9))
		elseif alarm == 1 then
			e.Color = AMBER
			e.Transparency = 0.2
		else
			e.Color = HudCard.EDGE
			e.Transparency = HudCard.EDGE_SEEN
		end
		if tick >= 0.25 then
			tick = 0
			pcall(holds)
			pcall(countdowns)
			place()
		end
	end)
end

function LuxeHud.unmount()
	LuxeLift.unmount()
	if beat then
		beat:Disconnect()
		beat = nil
	end
	if topConn then
		topConn:Disconnect()
		topConn = nil
	end
	if card then
		card:Destroy()
		card = nil
	end
	if keys then
		keys:Destroy()
		keys = nil
	end
	for _, g in backIns do
		g:Destroy()
	end
	backIns = {}
	parts = {}
	view = fresh()
	if lastAlarm >= 2 then
		Sound.setMood(nil)
	end
	lastAlarm = 0
end

-- What the server says about the guest's run.
function LuxeHud.on(m: { [string]: any })
	local op = m.op
	if op == "luxe" then
		view = m
		local alarm = tonumber(m.alarm) or 0
		if alarm ~= lastAlarm then
			-- (The alarm's music in a lockdown; the residence's own again once it cools.)
			if alarm >= 2 then
				Sound.setMood("alarm")
				Sound.play("lowHit", 0.7)
			elseif lastAlarm >= 2 then
				Sound.setMood(nil)
			end
			lastAlarm = alarm
		end
		LuxeHud.draw()
	elseif op == "took" then
		local colour = RARITY[tostring(m.rarity)] or GOLD
		local grade = Plan.rarityOf[tostring(m.rarity)]
		Sound.play("pickup", 0.8)
		if grade and grade.order >= 4 then
			Sound.play("crystal", 0.6)
		end
		if typeof(m.at) == "Vector3" then
			pcall(flash, m.at, colour, "+" .. Rules.format(tonumber(m.gilt) or 0) .. " GILT")
		end
		pcall(LuxeLift.took, m)
		Toast.show("Lifted: " .. tostring(m.name), string.format("%s  ·  %s  ·  REWARD +%s GILT when banked", tostring(m.glyph or ""), tostring(m.rarity or ""), Rules.format(tonumber(m.gilt) or 0)), 2.5)
	elseif op == "banked" then
		Sound.play("kaching", 0.8)
		-- (Build 102) The exact Gilt credited, and the getaway's own bonus when it had one.
		local line = string.format("+%s Gilt to your balance", Rules.format(tonumber(m.gilt) or 0))
		if (tonumber(m.giltBonus) or 0) > 0 then
			line ..= string.format("  ·  includes a +%s Gilt getaway bonus", Rules.format(tonumber(m.giltBonus) or 0))
		end
		if type(m.brainrots) == "table" and #m.brainrots > 0 then
			line ..= "  ·  a brainrot for your collection"
		end
		if type(m.routeName) == "string" and m.route ~= "car" then
			line ..= "  ·  away in " .. m.routeName
		end
		if type(m.finds) == "table" and #m.finds > 0 then
			line ..= "  ·  a first find: " .. table.concat(m.finds, ", ")
		end
		local fresh = tonumber(m.fresh) or 0
		if fresh > 0 and tonumber(m.total) then
			line ..= string.format("  ·  %d new for your collection (%d of %d)", fresh, tonumber(m.collected) or 0, tonumber(m.total) or 0)
		end
		-- (Build 96) A first haul, a new best, or one far above the usual: celebrated big, and the
		-- notice with its details after it, not under it.
		local Celebrate = require(script.Parent.Celebrate)
		local okC, kind = pcall(Celebrate.haul, m)
		local title = if m.record then "A record haul: +" .. Rules.format(tonumber(m.gilt) or 0) .. " Gilt" else "Banked: +" .. Rules.format(tonumber(m.gilt) or 0) .. " Gilt"
		if okC and type(kind) == "string" then
			task.delay(Celebrate.haulSeconds(kind) + 0.4, Toast.show, title, line, 5)
		else
			Toast.show(title, line, 5)
		end
		-- (Build 82) A wing's set made whole, or a new rank: said after, each on its own.
		task.delay(2.5, function()
			for _, set in (if type(m.sets) == "table" then m.sets else {}) :: { any } do
				Sound.play("crystal", 0.7)
				Toast.show("A set complete: " .. tostring(set.name), string.format("Every piece of the wing banked  ·  +%s Gilt", Rules.format(tonumber(set.gilt) or 0)), 4)
			end
			if type(m.rankUp) == "string" then
				Sound.play("notify", 0.7)
				Toast.show("A new rank: " .. m.rankUp, "For everything you've ever banked in Steal a Luxe.", 4)
			end
		end)
	elseif op == "caught" then
		local n = tonumber(m.n) or 0
		Toast.show("Caught", if n > 0 then string.format("The guards took back %d %s. You're shown out to the courtyard.", n, if n == 1 then "piece" else "pieces") else "You're shown out to the courtyard.", 5)
	elseif op == "woke" then
		-- Lifting a piece woke security: said once a trip, plainly; the card says the rest.
		view.awake = true
		view.chased = m.chased == true
		Sound.play("stinger", 0.6)
		if m.first then
			Toast.show("Security is awake", if m.chased then "A guard is coming after you. Get to a way out." else "The guards are looking for you. Get to a way out.", 3)
		end
		LuxeHud.draw()
	elseif op == "spotted" then
		view.chased = true
		Sound.play("stinger", 0.6)
		if type(m.by) == "string" and m.by ~= "a guard" then
			Toast.show("Seen", "Seen by " .. m.by .. ". The guards are on their way.", 3)
		end
		LuxeHud.draw()
	elseif op == "sleeper" then
		-- (Build 89) One of the night staff woke: what they do about it, plainly.
		local who = tostring(m.name or "someone")
		local Who = string.upper(string.sub(who, 1, 1)) .. string.sub(who, 2)
		if m.grumble then
			Sound.play("low", 0.5)
			Toast.show(Who .. " is awake", "They grumble and look round. You haven't taken anything, so they don't call anyone.", 3.5)
		else
			if Sound.has("bellStrike") then
				Sound.play("bellStrike", 0.6)
			else
				Sound.play("stinger", 0.6)
			end
			local line = if m.call == "lockdown" then "The Master Bedroom is locked down. Get to a way out."
				elseif m.call == "guard" and m.sent then "They've sent a guard straight after you. Get to a way out."
				else "They're ringing for the guards. Get to a way out."
			Toast.show(Who .. " is awake", line, 4)
		end
		LuxeHud.draw()
	elseif op == "objective" then
		Sound.play("notify", 0.7)
		Toast.show("Side job done", string.format("%s  ·  +%s Gilt", tostring(m.line), Rules.format(tonumber(m.gilt) or 0)), 3.5)
	elseif op == "alarm" then
		view.alarm = tonumber(m.level) or 0
		LuxeHud.draw()
	end
end

return LuxeHud

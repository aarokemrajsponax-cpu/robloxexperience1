--!strict
-- The Grand Prix, on this guest's screen: driving one of the house's cars, the dash, and the race
-- (the gathering, the five lights, laps and places, the result), with the house's chauffeurs
-- drawn from the same numbers the server keeps (GrandPrix.aiDistance), so every screen sees them
-- in the same places.
--
-- Driving: the car is this screen's while its guest is at the wheel (the server hands it over).
-- Each frame the throttle and steering (keys, a gamepad, or the thumbstick on a phone: Roblox
-- feeds them to the VehicleSeat) go through GrandPrix.step, and the car's two movers are set:
-- "Drive" (how fast, which way) and "Steer" (level, and turned). A wall stops it as it should.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Ease = require(ReplicatedStorage.Shared.Ease)
local GrandPrix = require(ReplicatedStorage.Shared.GrandPrix)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Parent.UI.Root)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Toast)
local HolidayMeter = require(script.Parent.Parent.UI.HolidayMeter)
local Invite = require(script.Parent.Parent.UI.Invite)
local Share = require(script.Parent.Parent.UI.Share)
local Sound = require(script.Parent.Parent.Sound)
local CircuitDress = require(script.Parent.CircuitDress)

local CarDrive = {}

local C = Brand.Colours
local player = Players.LocalPlayer
local raceEvent = Remotes.event("Race")

-- Set by Main: hide the driving screens while something else owns the screen (a table).
CarDrive.isBusy = function(): boolean
	return false
end

---------------------------------------------------------------------------------------------------
-- State
---------------------------------------------------------------------------------------------------
local driving: Model? = nil
local speed = 0
local yaw = 0
local fovBefore: number? = nil
-- The rush of it: a boost pad's surge (until when, and the pad it came from), the view's punch
-- (extra field of view, falling away), the camera's shake, and the tyres' last squeal.
local boostUntil = 0
local lastPad: number? = nil
local punch = 0
local kick = 0
local hum = 0
local skidAt = 0
CircuitDress.drivingNow = function(): Model?
	return driving
end

type Race = {
	state: string,
	id: number,
	laps: number,
	goAt: number, -- os.clock() of the start
	startAt: number, -- the server's clock at the start
	grid: { { [string]: any } },
	ai: { { [string]: any } },
	mine: boolean,
	lap: number,
	place: number,
	field: number,
	home: number?,
	gatherEnds: number,
	entrants: { string },
	door: string, -- the hours: "open" or "closed" (between races)
	doorAt: number, -- os.clock() of the next change
}
local race: Race = {
	state = "idle",
	id = 0,
	laps = 3,
	goAt = 0,
	startAt = 0,
	grid = {},
	ai = {},
	mine = false,
	lap = 0,
	place = 0,
	field = 0,
	home = nil,
	gatherEnds = 0,
	entrants = {},
	door = "open",
	doorAt = 0,
}

local ghosts: { [number]: Model } = {}
local ghostFolder: Folder? = nil

local function serverNow(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

---------------------------------------------------------------------------------------------------
-- The screens: the dash (while driving), the race line (top), the count (middle), the result
---------------------------------------------------------------------------------------------------
-- The Grand Prix's screens wear its own colours: racing red into carbon, edged in red and white.
local RACING = Theme.mood("grandPrix")

local function plate(name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.04
	f.Visible = false
	local g = Instance.new("UIGradient")
	g.Name = "Sheen"
	g.Rotation = 62
	g.Color = Theme.sequence(RACING.panel)
	g.Parent = f
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 10)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Color = Color3.new(1, 1, 1)
	s.Transparency = 0.1
	s.Thickness = 1.25
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = f
	local e = Instance.new("UIGradient")
	e.Name = "Edge"
	e.Rotation = 62
	e.Color = Theme.sequence(RACING.edge)
	e.Parent = s
	f.Parent = Root.hud
	return f
end

-- The dash: the car's name, the speed, and three keys.
local dash = plate("CarDash", UDim2.fromOffset(250, 78), UDim2.new(0.5, 0, 1, -14), Vector2.new(0.5, 1))
local dashName = Theme.text(dash, "", 12, "caps", {
	Name = "CarName",
	AutomaticSize = Enum.AutomaticSize.None,
	Size = UDim2.new(1, 0, 0, 18),
	Position = UDim2.fromOffset(0, 6),
	TextColor3 = RACING.accent,
})
local dashSpeed = Theme.text(dash, "0", 34, "display", {
	Name = "Speed",
	FontFace = Brand.Fonts.figures,
	AutomaticSize = Enum.AutomaticSize.None,
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.fromOffset(0, 22),
	TextColor3 = C.bone,
})
Theme.text(dash, "MPH", 11, "caps", {
	Name = "Unit",
	AutomaticSize = Enum.AutomaticSize.None,
	Size = UDim2.fromOffset(40, 14),
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -14, 1, -10),
	TextColor3 = RACING.plainText,
})
-- (On a boost pad's surge: the word in gold at the dash's other corner.)
local dashBoost = Theme.text(dash, "BOOST", 11, "caps", {
	Name = "Boost",
	AutomaticSize = Enum.AutomaticSize.None,
	Size = UDim2.fromOffset(60, 14),
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -10),
	TextColor3 = RACING.gold[1],
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
})

local keys = Instance.new("Frame")
keys.Name = "CarKeys"
keys.BackgroundTransparency = 1
keys.AnchorPoint = Vector2.new(0.5, 1)
keys.Position = UDim2.new(0.5, 0, 1, -100)
keys.Size = UDim2.fromOffset(380, 44)
keys.Visible = false
keys.Parent = Root.hud
local keyList = Theme.list(keys, 8, true)
keyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
local raceKey = Theme.key(keys, "Race", true, function()
	if race.state == "idle" or race.state == "results" then
		raceEvent:FireServer({ op = "race" })
	elseif race.state == "gathering" and not race.mine then
		raceEvent:FireServer({ op = "race" })
	elseif race.mine and race.state == "gathering" then
		raceEvent:FireServer({ op = "leave" })
	end
end, 140)
raceKey.Name = "RaceKey"
raceKey.LayoutOrder = 1
local resetKey = Theme.key(keys, "Reset", false, function()
	raceEvent:FireServer({ op = "reset" })
end, 104)
resetKey.Name = "ResetKey"
resetKey.LayoutOrder = 2
local outKey = Theme.key(keys, "Get out", false, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end, 110)
outKey.Name = "OutKey"
outKey.LayoutOrder = 3
Theme.paint(keys, "grandPrix")

-- The race line along the top.
local line = plate("RaceLine", UDim2.fromOffset(340, 40), UDim2.new(0.5, 0, 0, 58), Vector2.new(0.5, 0))
local lineText = Theme.text(line, "", 15, "bodyMedium", {
	Name = "Text",
	AutomaticSize = Enum.AutomaticSize.None,
	Size = UDim2.fromScale(1, 1),
	TextColor3 = C.bone,
})

-- The count, big in the middle: 3, 2, 1, GO.
local count = Theme.text(Root.hud, "", 96, "display", {
	Name = "RaceCount",
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.36),
	Size = UDim2.fromOffset(300, 120),
	TextColor3 = Color3.new(1, 1, 1),
	Visible = false,
})
-- (The count in racing red, white at its top.)
local countGradient = Instance.new("UIGradient")
countGradient.Rotation = 90
countGradient.Color = Theme.sequence({ Color3.fromRGB(255, 255, 255), RACING.gold[2], RACING.gold[3] })
countGradient.Parent = count
local countStroke = Instance.new("UIStroke")
countStroke.Color = Color3.fromRGB(10, 8, 6)
countStroke.Thickness = 2
countStroke.Transparency = 0.2
countStroke.Parent = count

-- A callout under the race line: a place won or lost, the flag. Big, brief, then gone.
local callout = Theme.text(Root.hud, "", 30, "display", {
	Name = "RaceCallout",
	AutomaticSize = Enum.AutomaticSize.None,
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 112),
	Size = UDim2.fromOffset(420, 40),
	TextColor3 = Color3.new(1, 1, 1),
	Visible = false,
})
local calloutGradient = Instance.new("UIGradient")
calloutGradient.Rotation = 90
calloutGradient.Parent = callout
local calloutStroke = Instance.new("UIStroke")
calloutStroke.Color = Color3.fromRGB(10, 8, 6)
calloutStroke.Thickness = 2
calloutStroke.Transparency = 0.25
calloutStroke.Parent = callout
local calloutScale = Instance.new("UIScale")
calloutScale.Parent = callout
local calloutAt = 0

local function say(text: string, good: boolean)
	calloutAt = os.clock()
	local stamp = calloutAt
	callout.Text = text
	calloutGradient.Color = if good
		then Theme.sequence({ Color3.fromRGB(255, 255, 255), RACING.gold[2], RACING.gold[3] })
		else Theme.sequence({ Color3.fromRGB(236, 236, 240), Color3.fromRGB(176, 176, 184) })
	callout.TextTransparency = 0
	calloutStroke.Transparency = 0.25
	callout.Visible = not CarDrive.isBusy()
	calloutScale.Scale = 1.35
	TweenService:Create(calloutScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.5, function()
		if calloutAt == stamp then
			TweenService:Create(callout, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			TweenService:Create(calloutStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			task.delay(0.45, function()
				if calloutAt == stamp then
					callout.Visible = false
				end
			end)
		end
	end)
end
CarDrive.callout = say

-- Speed lines: thin streaks at the edges of the screen, rushing outward, only when it's quick.
local streaks = Instance.new("Frame")
streaks.Name = "SpeedLines"
streaks.BackgroundTransparency = 1
streaks.Size = UDim2.fromScale(1, 1)
streaks.ZIndex = 0
streaks.Visible = false
streaks.Parent = Root.hud
type Streak = { frame: Frame, angle: number, r: number, speed: number }
local streakList: { Streak } = {}
for i = 1, 16 do
	local f = Instance.new("Frame")
	f.Name = "Streak"
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.fromRGB(255, 250, 236)
	f.BackgroundTransparency = 1
	f.ZIndex = 0
	f.Parent = streaks
	table.insert(streakList, { frame = f, angle = (i / 16) * math.pi * 2 + math.random() * 0.2, r = 0.75 + math.random() * 0.35, speed = 1.2 + math.random() * 0.8 })
end

local function drawStreaks(dt: number, rush: number)
	local show = rush > 0.02 and driving ~= nil and not CarDrive.isBusy() and Ease.motionScale >= 0.5
	streaks.Visible = show
	if not show then
		return
	end
	local size = Root.size()
	local half = Vector2.new(size.X / 2, size.Y / 2)
	for _, st in streakList do
		st.r += dt * st.speed * (0.6 + rush)
		if st.r > 1.15 then
			st.r = 0.74 + math.random() * 0.08
			st.angle = math.random() * math.pi * 2
			st.speed = 1.2 + math.random() * 0.8
		end
		local dir = Vector2.new(math.cos(st.angle), math.sin(st.angle))
		local at = half + Vector2.new(dir.X * half.X, dir.Y * half.Y) * st.r
		st.frame.Position = UDim2.fromOffset(at.X, at.Y)
		st.frame.Size = UDim2.fromOffset(40 + 90 * math.min(rush, 1), 2)
		st.frame.Rotation = math.deg(math.atan2(dir.Y * half.Y, dir.X * half.X))
		st.frame.BackgroundTransparency = 1 - math.clamp(rush, 0, 1) * 0.4 * math.clamp((st.r - 0.74) * 4, 0, 1)
	end
end

local function setDashVisible()
	local show = driving ~= nil and not CarDrive.isBusy()
	dash.Visible = show
	keys.Visible = show
	-- (At the wheel the line always says where the Grand Prix stands: open, or when it opens.)
	local showLine = (driving ~= nil or (race.state ~= "idle" and race.mine)) and not CarDrive.isBusy()
	line.Visible = showLine
	Root.setTop("RaceLine", if showLine then 58 + 40 + 6 else nil, 170)
	Root.setBottom("CarDash", if show then 150 else nil)
end

local function clockText(seconds: number): string
	local n = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", n // 60, n % 60)
end

local function fmtTime(t: number): string
	t = math.max(0, t)
	return string.format("%d:%04.1f", math.floor(t / 60), t % 60)
end

local function ordinal(n: number): string
	local last = n % 10
	local teen = n % 100 >= 11 and n % 100 <= 13
	local suffix = if teen then "th" elseif last == 1 then "st" elseif last == 2 then "nd" elseif last == 3 then "rd" else "th"
	return tostring(n) .. suffix
end

local function setRaceKey(text: string)
	local caps = Caps(text)
	if raceKey.Text ~= caps then
		raceKey.Text = caps
	end
end

local function updateLine()
	local t = os.clock()
	if race.state == "gathering" then
		local left = math.max(0, math.ceil(race.gatherEnds - t))
		local n = #race.entrants
		lineText.Text = string.format("GRAND PRIX  ·  starts in %d  ·  %d %s", left, n, if n == 1 then "driver" else "drivers")
		setRaceKey(if race.mine then "Leave race" else "Join race")
	elseif race.state == "countdown" then
		lineText.Text = if race.mine then "On the grid  ·  watch the lights" else "GRAND PRIX  ·  the cars are on the grid"
		setRaceKey("Race")
	elseif race.state == "racing" then
		local elapsed = t - race.goAt
		if race.mine and race.home then
			lineText.Text = string.format("HOME  ·  %s  ·  %s", ordinal(race.place), fmtTime(race.home))
		elseif race.mine then
			lineText.Text = string.format("LAP %d/%d   ·   %s of %d   ·   %s", math.max(1, race.lap), race.laps, ordinal(math.max(1, race.place)), math.max(1, race.field), fmtTime(elapsed))
		else
			lineText.Text = string.format("GRAND PRIX  ·  racing  ·  %s", fmtTime(elapsed))
		end
		setRaceKey("Race")
	elseif race.state == "results" then
		lineText.Text = "GRAND PRIX  ·  the results are in"
		setRaceKey("Race")
	elseif race.door == "closed" then
		local left = clockText(race.doorAt - t)
		lineText.Text = "GRAND PRIX  ·  opens in " .. left
		setRaceKey("Opens " .. left)
	else
		lineText.Text = "GRAND PRIX  ·  open  ·  press Race"
		setRaceKey("Race")
	end
end

---------------------------------------------------------------------------------------------------
-- The gantry's five lights
---------------------------------------------------------------------------------------------------
local function gantryLights(): { BasePart }
	local out = {}
	local maison = Workspace:FindFirstChild("Maison")
	local circuit = maison and maison:FindFirstChild("GrandPrix")
	local gantry = circuit and circuit:FindFirstChild("Gantry")
	local lights = gantry and gantry:FindFirstChild("Lights")
	if lights then
		for i = 1, 5 do
			local l = lights:FindFirstChild("Light" .. i)
			if l and l:IsA("BasePart") then
				table.insert(out, l)
			end
		end
	end
	return out
end

local lightsLit = -1
local function setLights(n: number)
	if n == lightsLit then
		return
	end
	lightsLit = n
	for i, l in gantryLights() do
		local on = i <= n
		l.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		l.Color = if on then Color3.fromRGB(230, 30, 30) else Color3.fromRGB(40, 12, 12)
	end
end

---------------------------------------------------------------------------------------------------
-- The house's chauffeurs, drawn here
---------------------------------------------------------------------------------------------------
local function clearGhosts()
	for _, m in ghosts do
		m:Destroy()
	end
	ghosts = {}
end

local function template(carId: string): Model?
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("CarId") == carId and d.Parent and d.Parent.Name == "GrandPrixCars" then
			return d
		end
	end
	return nil
end

local function makeGhost(entry: { [string]: any }): Model?
	local source = template(entry.carId)
	if not source then
		return nil
	end
	local ok, copy = pcall(function()
		return source:Clone()
	end)
	if not ok or not copy then
		return nil
	end
	local m = copy :: Model
	m.Name = "Chauffeur"
	for _, d in m:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("LinearVelocity") or d:IsA("AlignOrientation") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	m:SetAttribute("CarId", nil)
	m:SetAttribute("Chauffeur", entry.name)
	if not ghostFolder or not ghostFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "MaisonChauffeurs"
		f.Parent = Workspace
		ghostFolder = f
	end
	m.Parent = ghostFolder
	-- Their name over the car.
	local chassis = m:FindFirstChild("Chassis")
	if chassis then
		local board = Instance.new("BillboardGui")
		board.Name = "Plate"
		board.Size = UDim2.fromOffset(160, 26)
		board.StudsOffset = Vector3.new(0, 5.2, 0)
		board.AlwaysOnTop = false
		board.MaxDistance = 140
		board.Parent = chassis
		Theme.text(board, entry.name, 14, "bodyMedium", {
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.fromScale(1, 1),
			TextColor3 = C.lightGold,
		})
	end
	return m
end

-- Where a chauffeur is now: on the grid before the start, then round the circuit.
function CarDrive.chauffeurAt(entry: { [string]: any }, elapsed: number, laps: number): CFrame
	local slot = GrandPrix.gridSlot(entry.slot)
	if elapsed <= 0 then
		return slot
	end
	local L = GrandPrix.length()
	local d = GrandPrix.aiDistance(elapsed, entry.pace, laps + 1) - entry.behind
	local s = (d % L + L) % L
	local p, dir = GrandPrix.point(s)
	-- From the grid's lane into the middle of the road over the first stretch.
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local laneOff = (slot.Position - GrandPrix.point(L - entry.behind)):Dot(side)
	local blend = math.clamp(1 - (d + entry.behind) / 40, 0, 1)
	local at = Vector3.new(p.X, GrandPrix.RIDE, p.Z) + side * laneOff * blend
	return CFrame.lookAt(at, at + dir)
end

local function moveGhosts()
	if race.state ~= "countdown" and race.state ~= "racing" and race.state ~= "results" then
		if next(ghosts) then
			clearGhosts()
		end
		return
	end
	local elapsed = serverNow() - race.startAt
	for i, entry in race.ai do
		local m = ghosts[i]
		if not m then
			m = makeGhost(entry) :: any
			if not m then
				continue
			end
			ghosts[i] = m :: Model
		end
		local cf = CarDrive.chauffeurAt(entry, elapsed, race.laps)
		pcall(function()
			(m :: Model):PivotTo(cf)
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- The result card
---------------------------------------------------------------------------------------------------
local function showResults(list: { { [string]: any } }, mine: { [string]: any }?)
	local NAME = "RaceResults"
	if Root.isOpen(NAME) then
		Root.close(NAME)
	end
	local w = Root.panelWidth(420)
	local group, content = Theme.glass(Root.panels, NAME, UDim2.fromOffset(w, 360))
	local listLayout = Theme.list(content, 8)
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Grand Prix", 11, "caps", { LayoutOrder = 1 })
	local heading = "The results"
	if mine then
		if (mine.place or 0) == 1 then
			heading = "You won"
		elseif (mine.place or 0) > 0 then
			heading = "You came " .. ordinal(mine.place)
		else
			heading = tostring(mine.out or "You didn't finish")
		end
	end
	Theme.text(content, heading, 26, "display", { LayoutOrder = 2 })
	if mine and ((mine.gilt or 0) > 0 or (mine.gems or 0) > 0) then
		local prize = "+" .. tostring(mine.gilt) .. " Gilt"
		if (mine.gems or 0) > 0 then
			prize ..= "   ·   +" .. tostring(mine.gems) .. " Gems"
		end
		Theme.text(content, prize, 18, "bodyBold", { LayoutOrder = 3, TextColor3 = RACING.gold[1] })
	end
	-- The standings as a little table: place, driver, time (or why they didn't finish).
	for i, row in list do
		if i > 6 then
			break
		end
		local me = row.userId == player.UserId
		local colour = if me then RACING.accent elseif row.ai then C.smoke else C.bone
		local kind: "bodyBold" | "body" = if me then "bodyBold" else "body"
		local line = Instance.new("Frame")
		line.Name = "Row" .. i
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, 24)
		line.LayoutOrder = 10 + i
		line.Parent = content
		local finished = (row.place or 0) > 0
		Theme.text(line, if finished then ordinal(row.place) else "—", 15, kind, {
			Name = "Place",
			AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(0, 48, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = colour,
		})
		Theme.text(line, tostring(row.name or ""), 15, kind, {
			Name = "Driver",
			AutomaticSize = Enum.AutomaticSize.None,
			Position = UDim2.fromOffset(52, 0),
			Size = UDim2.new(1, -52 - 110, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = colour,
		})
		Theme.text(line, if finished then fmtTime(row.time or 0) else tostring(row.out or ""), 15, kind, {
			Name = "Time",
			AutomaticSize = Enum.AutomaticSize.None,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 106, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = colour,
		})
	end
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AutomaticSize = Enum.AutomaticSize.Y
	row.Size = UDim2.new(1, 0, 0, 0)
	row.LayoutOrder = 40
	row.Parent = content
	local rowList = Theme.list(row, 10, true)
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	if driving then
		Theme.key(row, "Race again", true, function()
			Root.close(NAME)
			raceEvent:FireServer({ op = "race" })
		end, 150).LayoutOrder = 1
	end
	Theme.key(row, "Close", false, function()
		Root.close(NAME)
	end, 110).LayoutOrder = 2
	-- A race is better against friends: ask one along, and share a win (where Roblox allows it).
	local social = Instance.new("Frame")
	social.Name = "Social"
	social.BackgroundTransparency = 1
	social.AutomaticSize = Enum.AutomaticSize.Y
	social.Size = UDim2.new(1, 0, 0, 0)
	social.LayoutOrder = 41
	social.Parent = content
	local socialList = Theme.list(social, 10, true)
	socialList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(social, "Invite a friend", false, function()
		Invite.race()
	end, 160).LayoutOrder = 1
	if mine and (mine.place or 0) == 1 and Share.allowed() then
		Theme.key(social, "Share", false, function()
			Share.moment("grandPrix")
		end, 110).LayoutOrder = 2
	end
	Theme.fitHeight(group, content)
	Theme.paint(group, "grandPrix")
	Root.open(NAME, group, nil, false)
end

---------------------------------------------------------------------------------------------------
-- Messages from the server
---------------------------------------------------------------------------------------------------
local lastResult: { [string]: any }? = nil

local function onMessage(m: { [string]: any })
	local op = m.op
	if op == "race" then
		local was = race.state
		race.state = m.state
		race.id = m.id or race.id
		race.laps = m.laps or race.laps
		race.entrants = m.entrants or {}
		race.gatherEnds = os.clock() + (tonumber(m.gatherLeft) or 0)
		race.goAt = os.clock() + (tonumber(m.goIn) or 0)
		race.startAt = tonumber(m.startAt) or serverNow()
		race.grid = m.grid or {}
		race.ai = m.ai or {}
		if m.door == "open" or m.door == "closed" then
			race.door = m.door
			race.doorAt = os.clock() + (tonumber(m.doorLeft) or 0)
		end
		local mine = false
		for _, g in race.grid do
			if g.userId == player.UserId then
				mine = true
			end
		end
		local name = player.DisplayName
		for _, n in race.entrants do
			if n == name or n == player.Name then
				mine = true
			end
		end
		if race.state == "idle" then
			mine = false
		end
		race.mine = mine
		if race.state == "countdown" and was ~= "countdown" then
			race.lap, race.place, race.home = 0, 0, nil
			race.field = #race.grid + #race.ai
			clearGhosts()
		end
		if race.state == "gathering" and was == "idle" and (driving ~= nil) then
			Sound.play("bellStrike", 0.35)
		end
	elseif op == "standings" then
		race.field = #(m.list or {})
		local was = race.place
		for _, row in m.list or {} do
			if row.userId == player.UserId then
				race.place = row.place
				race.lap = math.max(race.lap, row.lap or 1)
			end
		end
		-- A place won or lost, called out (not the first reading of the race).
		if race.state == "racing" and race.mine and not race.home and was > 0 and race.place > 0 and race.place ~= was then
			if race.place < was then
				say(if race.place == 1 then "INTO THE LEAD" else "UP TO " .. string.upper(ordinal(race.place)), true)
				Sound.play("combo", 0.45, 1 + (5 - math.min(race.place, 5)) * 0.06)
			else
				say("DOWN TO " .. string.upper(ordinal(race.place)), false)
			end
		end
	elseif op == "lap" then
		race.lap = m.lap
		if m.lap == race.laps then
			Toast.show("Last lap", "Bring it home.", 2)
		end
		Sound.play("tick", 0.4)
	elseif op == "home" then
		race.home = m.time
		say("CHEQUERED FLAG", true)
		Sound.play("complete", 0.5)
	elseif op == "out" then
		Toast.show("The Grand Prix", tostring(m.why or "Out of the race"), 3)
	elseif op == "yourResult" then
		lastResult = m
		if (m.place or 0) == 1 then
			Sound.play("regalFanfare", 0.5)
		elseif (m.place or 0) > 0 then
			Sound.play("reward", 0.45)
		end
	elseif op == "results" then
		local mine = if lastResult and race.mine then lastResult else nil
		if race.mine or driving then
			pcall(showResults, m.list or {}, mine)
		end
		lastResult = nil
	elseif op == "driving" then
		-- (The seat says so too; this only names the car before the seat has replicated.)
		dashName.Text = string.upper(tostring(m.name or ""))
	elseif op == "parked" then
		-- nothing more to do: the seat is empty
	elseif op == "refused" then
		Toast.show("The Grand Prix", tostring(m.why or "Not now."), 2.5)
	elseif op == "closed" then
		-- Between races: when it opens, and opening it now for everyone (Robux, price shown).
		race.door = "closed"
		race.doorAt = os.clock() + (tonumber(m.opensIn) or 0)
		pcall(HolidayMeter.offer, "The Grand Prix is closed", string.format("It opens again in %s. Drive any car as you like until then, or open it now for everyone in the house.", clockText(tonumber(m.opensIn) or 0)), {
			{
				label = "Open the Grand Prix now",
				price = if type(m.price) == "number" then m.price else nil,
				held = if type(m.held) == "number" then m.held else nil,
				press = function()
					HolidayMeter.closeOffer()
					raceEvent:FireServer({ op = "openNow" })
				end,
			},
		}, "It opens by itself ten minutes after each race.", "grandPrix")
	elseif op == "opened" then
		race.door = "open"
		race.doorAt = os.clock() + (tonumber(m.closesIn) or 0)
		if HolidayMeter.offering() then
			HolidayMeter.closeOffer()
		end
		-- (Opened by someone, the whole house sees their salute; on its own, a quiet word.)
		if not m.by and not CarDrive.isBusy() then
			Toast.show("The Grand Prix is open", "Get in any car on the street and press Race.", 4)
		end
	elseif op == "reset" then
		speed = 0
	end
	setDashVisible()
	updateLine()
end

---------------------------------------------------------------------------------------------------
-- Driving
---------------------------------------------------------------------------------------------------
local function carOf(seat: Instance?): Model?
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
		local model = seat.Parent
		if model and model:IsA("Model") and model:GetAttribute("CarId") ~= nil then
			return model
		end
	end
	return nil
end

local function enter(model: Model)
	driving = model
	speed = 0
	local chassis = model:FindFirstChild("Chassis") :: BasePart?
	if chassis then
		local look = chassis.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
	end
	dashName.Text = string.upper(tostring(model:GetAttribute("CarName") or "The car"))
	local camera = Workspace.CurrentCamera
	if camera then
		fovBefore = camera.FieldOfView
	end
	Sound.play("door", 0.35)
	setDashVisible()
	updateLine()
end

local function leave()
	local was = driving
	driving = nil
	speed = 0
	boostUntil, punch, kick, hum = 0, 0, 0, 0
	dashBoost.Visible = false
	streaks.Visible = false
	if was then
		pcall(CircuitDress.effects, was, 0, false)
	end
	local camera = Workspace.CurrentCamera
	if camera and fovBefore then
		camera.FieldOfView = fovBefore
	end
	fovBefore = nil
	setDashVisible()
end

-- Keys as well as the seat's own throttle (a fallback where the seat isn't fed).
local function keyAxis(plus: { Enum.KeyCode }, minus: { Enum.KeyCode }): number
	local v = 0
	for _, k in plus do
		if UserInputService:IsKeyDown(k) then
			v += 1
			break
		end
	end
	for _, k in minus do
		if UserInputService:IsKeyDown(k) then
			v -= 1
			break
		end
	end
	return v
end

-- One frame at the wheel (exposed for tests).
function CarDrive.step(dt: number)
	local model = driving
	if not model then
		return
	end
	local chassis = model:FindFirstChild("Chassis") :: BasePart?
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat?
	if not chassis or not seat then
		return
	end
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity?
	local steer = chassis:FindFirstChild("Steer") :: AlignOrientation?
	if not drive or not steer then
		return
	end
	if chassis.Anchored then
		-- Parked, or on the grid: still, facing as it stands.
		speed = 0
		local look = chassis.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		drive.VectorVelocity = Vector3.zero
		dashSpeed.Text = "0"
		return
	end
	local throttle = seat.ThrottleFloat
	local steering = seat.SteerFloat
	if throttle == 0 then
		throttle = keyAxis({ Enum.KeyCode.W, Enum.KeyCode.Up }, { Enum.KeyCode.S, Enum.KeyCode.Down })
	end
	if steering == 0 then
		steering = keyAxis({ Enum.KeyCode.D, Enum.KeyCode.Right }, { Enum.KeyCode.A, Enum.KeyCode.Left })
	end
	-- Into a wall: the car is as fast as it truly goes.
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local read, velocity = pcall(function()
		return chassis.AssemblyLinearVelocity
	end)
	local actual = if read and typeof(velocity) == "Vector3" then velocity:Dot(forward) else speed
	if math.abs(speed - actual) > 14 and math.abs(actual) < math.abs(speed) then
		speed = actual + (if speed > actual then 6 else -6)
	end
	-- Over a boost pad (going forward): the surge, felt in the view and heard.
	local now = os.clock()
	local pad = GrandPrix.boostAt(chassis.Position)
	if pad and pad ~= lastPad and speed > 10 then
		boostUntil = now + GrandPrix.BOOST.seconds
		punch = 10
		kick = math.max(kick, 0.35)
		Sound.play("boost", 0.7)
	end
	lastPad = pad
	local boosting = now < boostUntil
	local yawRate
	speed, yawRate = GrandPrix.step(speed, throttle, steering, dt, boosting)
	yaw += yawRate * dt
	local rot = CFrame.Angles(0, yaw, 0)
	steer.CFrame = rot
	drive.VectorVelocity = rot.LookVector * speed
	-- The tyres: smoke and a squeal when a bend is taken faster than they hold (the car runs
	-- wide), a little smoke pulling away hard.
	local car = GrandPrix.CAR
	local v = math.abs(speed)
	local frac = v / car.top
	local sliding = math.abs(steering) > 0.5 and v > 45 and car.grip / v < car.turn * math.clamp(v / car.turnAt, 0, 1)
	local smoke = 0
	if sliding then
		smoke = 0.4 + 0.6 * math.clamp((v - 45) / 45, 0, 1)
		if now > skidAt then
			skidAt = now + 1.4
			Sound.play("skid", 0.45)
		end
	elseif throttle > 0.9 and v > 1 and v < 30 then
		smoke = 0.5 * (1 - v / 30)
	end
	pcall(CircuitDress.effects, model, smoke, boosting)
	-- The figures (gold on a surge), and the view opening with the speed.
	dashSpeed.Text = tostring(math.floor(v * 1.1 + 0.5))
	dashSpeed.TextColor3 = if boosting then RACING.gold[1] else C.bone
	dashBoost.Visible = boosting
	punch = math.max(0, punch - dt * 9)
	hum = if frac > 0.82 then 0.05 * math.clamp((frac - 0.82) / 0.2, 0, 1) else 0
	local camera = Workspace.CurrentCamera
	if camera and fovBefore then
		camera.FieldOfView = fovBefore + 16 * math.clamp(frac, 0, 1.2) + punch
	end
	drawStreaks(dt, math.clamp((frac - 0.62) / 0.38, 0, 1.3) + (if boosting then 0.4 else 0))
end

-- (For tests: whether a boost pad's surge is on now.)
function CarDrive.boosting(): boolean
	return os.clock() < boostUntil
end

-- The camera's shake while driving: a kick (a boost, the start) falling away, and a fine hum at
-- the top of the speed. Laid over wherever the camera has put itself this frame.
local function shakeCamera(dt: number)
	kick = math.max(0, kick - dt * 1.6)
	local size = kick + hum
	local camera = Workspace.CurrentCamera
	if driving == nil or size <= 0.001 or not camera or Ease.motionScale < 0.5 then
		return
	end
	local t = os.clock()
	camera.CFrame *= CFrame.new(math.noise(t * 22, 0.3) * size, math.noise(0.7, t * 22) * size, 0) * CFrame.Angles(0, 0, math.noise(t * 18, 5.1) * size * 0.05)
end

function CarDrive.isDriving(): boolean
	return driving ~= nil
end

function CarDrive.race(): Race
	return race
end

function CarDrive.start()
	raceEvent.OnClientEvent:Connect(function(m: any)
		if type(m) == "table" then
			local ok, err = pcall(function()
				onMessage(m)
			end)
			if not ok then
				warn("[Maison] The Grand Prix screen: " .. tostring(err))
			end
		end
	end)
	local last = os.clock()
	RunService.Heartbeat:Connect(function(dt: number)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local model = carOf(humanoid and humanoid.SeatPart)
		if model ~= driving then
			if driving then
				leave()
			end
			if model then
				enter(model)
			end
		end
		if driving then
			local ok, err = pcall(function()
				CarDrive.step(dt)
			end)
			if not ok then
				warn("[Maison] Driving: " .. tostring(err))
			end
		end
		pcall(moveGhosts)
		-- The lights: one by one in the last 3 seconds of the count, all out at the start.
		if race.state == "countdown" then
			local left = race.goAt - os.clock()
			setLights(math.clamp(5 - math.floor(left / 0.6), 0, 5))
			local n = math.ceil(left)
			if race.mine then
				count.Visible = n <= 3 and n >= 1
				count.Text = tostring(n)
			end
		elseif race.state == "racing" and os.clock() - race.goAt < 1.2 then
			setLights(0)
			if race.mine then
				if count.Text ~= "GO" and driving then
					-- Lights out: the start felt as well as seen.
					kick = math.max(kick, 0.5)
					punch = math.max(punch, 8)
				end
				count.Visible = true
				count.Text = "GO"
			end
		else
			setLights(0)
			count.Visible = false
		end
		local t = os.clock()
		if t - last > 0.2 then
			last = t
			updateLine()
			setDashVisible()
		end
	end)
	pcall(function()
		RunService:BindToRenderStep("MaisonCarShake", Enum.RenderPriority.Camera.Value + 1, shakeCamera)
	end)
	raceEvent:FireServer({ op = "hello" })
end

return CarDrive

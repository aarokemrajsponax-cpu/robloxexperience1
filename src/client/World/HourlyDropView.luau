--!strict
-- The Hourly Drop on this screen (Build 91; server/HourlyDrop decides everything):
--   the sign      over the plinth, a black glass card ringed in gold: THE HOURLY DROP, how long
--                 the case stays (or how long to the next, by the server's clock: the same for
--                 everyone, never a made-up countdown), this hour's piece and whether it's yours.
--   the arrival   on the hour the case comes down from the ceiling in a shaft of gold light,
--                 settles on the plinth with a shimmer, then turns slowly there, breathing.
--   the opening   when this guest opens it, its lid lifts on their screen, light pours out, a
--                 burst of gold; it stays open for them until the hour's case goes.
--   the notice    a quiet line when the case comes down, and what opening it gave.
-- Nothing here is kept or decides anything.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local Plan = require(ReplicatedStorage.Shared.HourlyDrop)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sound = require(script.Parent.Parent.Sound)

local HourlyDropView = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local GOLD = rgb(232, 192, 108)
local BRIGHT = rgb(255, 226, 160)
local IVORY = rgb(236, 228, 212)
local SMOKE = rgb(170, 162, 150)
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local FALL = 2.4 -- seconds the case takes to come down
local HIGH = 18 -- studs above the plinth it comes down from
local SPIN = math.rad(9) -- its slow turn, a second

-- Set by Main: a quiet notice (UI/Toast).
HourlyDropView.toast = function(_title: string, _line: string) end

type Sign = { gui: BillboardGui, time: TextLabel, timeWord: TextLabel, piece: TextLabel, state: TextLabel, chip: Frame }

local mine = { hour = -1, opened = false, have = {} :: { [string]: boolean }, count = 0 }
local sign: Sign? = nil
local caseModel: Model? = nil
local rest: CFrame? = nil -- the case's pivot as the server put it
local arrivedAt = -math.huge
local landed = true -- (the shimmer as it settles, once)
local lidRest: CFrame? = nil
local hingeRel: CFrame? = nil
local lidOpenedAt: number? = nil
local light: PointLight? = nil
local shaft: Part? = nil
local burst: ParticleEmitter? = nil

local function now(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.time()
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return 1 - (1 - k) ^ 3
end

local function nameOf(id: string?): string
	local c = if id then CurioList.byId[id] else nil
	return if c then c.name else "a piece of the house"
end

local function glyphOf(id: string?): string
	local c = if id then CurioList.byId[id] else nil
	return if c then c.glyph else "🎁"
end

local function label(parent: Instance, name: string, font: Font, colour: Color3, y: number, h: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.fromScale(0.5, y)
	l.Size = UDim2.fromScale(0.86, h)
	l.FontFace = font
	l.TextColor3 = colour
	l.TextScaled = true
	l.Text = ""
	l.Parent = parent
	return l
end

-- The sign over the plinth (on this screen only, hung on the server's SignAt).
local function makeSign(at: Attachment): Sign
	local gui = Instance.new("BillboardGui")
	gui.Name = "HourlyDropSign"
	gui.Adornee = at
	gui.Size = UDim2.new(10.5, 0, 4.4, 0) -- in studs: it reads the same size as the plinth at any distance
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = rgb(12, 11, 14)
	card.BackgroundTransparency = 0.12
	card.Size = UDim2.fromScale(1, 1)
	card.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.14, 0)
	round.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Color = GOLD
	edge.Thickness = 2
	edge.Transparency = 0.15
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = card
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(rgb(46, 40, 34), rgb(10, 9, 12))
	sheen.Parent = card
	label(card, "Kicker", Brand.Fonts.display, GOLD, 0.07, 0.16).Text = "◆   THE HOURLY DROP   ◆"
	-- A hairline under the kicker.
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BorderSizePixel = 0
	rule.BackgroundColor3 = GOLD
	rule.BackgroundTransparency = 0.45
	rule.AnchorPoint = Vector2.new(0.5, 0)
	rule.Position = UDim2.fromScale(0.5, 0.26)
	rule.Size = UDim2.new(0.5, 0, 0, 1)
	rule.Parent = card
	local timeWord = label(card, "TimeWord", Brand.Fonts.bodyBold, SMOKE, 0.3, 0.1)
	local time = label(card, "Time", Brand.Fonts.figures, IVORY, 0.4, 0.26)
	local piece = label(card, "Piece", Brand.Fonts.body, IVORY, 0.68, 0.12)
	-- The state, in a small chip at the foot.
	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.fromScale(0.5, 0.83)
	chip.Size = UDim2.fromScale(0.62, 0.12)
	chip.BackgroundColor3 = GOLD
	chip.BackgroundTransparency = 0.8
	chip.Parent = card
	local chipRound = Instance.new("UICorner")
	chipRound.CornerRadius = UDim.new(1, 0)
	chipRound.Parent = chip
	local state = label(chip, "State", Brand.Fonts.bodyBold, BRIGHT, 0.1, 0.8)
	state.Size = UDim2.fromScale(0.92, 0.8)
	return { gui = gui, time = time, timeWord = timeWord, piece = piece, state = state, chip = chip }
end

-- What the sign says now.
function HourlyDropView.words(t: number, open: boolean, closes: number?, nextAt: number?, piece: string?, nextPiece: string?, opened: boolean, have: { [string]: boolean }): { [string]: string }
	if open then
		local left = (closes or Plan.closesAt(t)) - t
		local shown = piece or Plan.pieceOf(Plan.hourOf(t))
		return {
			timeWord = "THE CASE IS DOWN  ·  IT GOES IN",
			time = Plan.clock(left),
			piece = glyphOf(shown) .. "  This hour: " .. nameOf(shown),
			state = if opened then "Opened  ·  the next at the top of the hour" elseif have[shown] then "Open it for Gilt  ·  piece already yours" else "Open it for Gilt and the piece",
		}
	end
	local upcoming = nextPiece or Plan.pieceOf(Plan.hourOf(t) + 1)
	return {
		timeWord = "THE NEXT CASE COMES DOWN IN",
		time = Plan.clock((nextAt or Plan.nextAt(t)) - t),
		piece = glyphOf(upcoming) .. "  Next: " .. nameOf(upcoming),
		state = if have[upcoming] then "Already in your collection" else "Every hour, on the hour",
	}
end

local function lid(): BasePart?
	local c = caseModel
	local l = c and c:FindFirstChild("Lid")
	return if l and l:IsA("BasePart") then l else nil
end

local function body(): BasePart?
	local c = caseModel
	local b = c and c.PrimaryPart
	return b
end

local function setGlow(on: boolean)
	local c = caseModel
	local g = c and c:FindFirstChild("Glow")
	if g and g:IsA("BasePart") then
		g.Transparency = if on then 0.1 else 1
	end
	local l = light
	if l then
		l.Enabled = on
	end
end

local function emit(n: number)
	local b = burst
	if b then
		pcall(function()
			b:Emit(n)
		end)
	end
end

-- The case came down (or was there when this screen arrived).
local function caseArrived(c: Model, fresh: boolean)
	caseModel = c
	rest = c:GetPivot()
	arrivedAt = if fresh then os.clock() else -math.huge
	landed = not fresh
	lidOpenedAt = nil
	local b, l = c.PrimaryPart, c:FindFirstChild("Lid")
	if b and l and l:IsA("BasePart") then
		lidRest = b.CFrame:ToObjectSpace(l.CFrame)
		local hinge = l:GetAttribute("Hinge")
		hingeRel = if typeof(hinge) == "CFrame" then b.CFrame:ToObjectSpace(hinge) else nil
	end
	-- Its own light inside (lit when its lid lifts) and a burst of gold.
	if b then
		local pl = Instance.new("PointLight")
		pl.Name = "Inside"
		pl.Color = rgb(255, 210, 130)
		pl.Brightness = 2.4
		pl.Range = 14
		pl.Enabled = false
		pl.Parent = b
		light = pl
		local e = Instance.new("ParticleEmitter")
		e.Name = "Burst"
		e.Texture = SPARK
		e.Color = ColorSequence.new(BRIGHT, GOLD)
		e.LightEmission = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(4, 10)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 2.5
		e.Rate = 0
		e.Parent = b
		burst = e
	end
	if mine.opened and mine.hour == Plan.hourOf(now()) then
		lidOpenedAt = os.clock() - 10
		setGlow(true)
	end
	if fresh then
		-- The shaft of light it comes down in.
		local p = Instance.new("Part")
		p.Name = "DropShaft"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = rgb(255, 214, 140)
		p.Transparency = 0.82
		p.Shape = Enum.PartType.Cylinder
		local base = (rest :: CFrame).Position
		p.Size = Vector3.new(HIGH + 6, 3.2, 3.2)
		p.CFrame = CFrame.new(base + Vector3.new(0, (HIGH + 6) / 2 - 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
		p.Parent = Workspace
		shaft = p
		pcall(Sound.chime, 3)
	end
end

local function caseGone()
	caseModel = nil
	rest = nil
	lidRest, hingeRel, lidOpenedAt = nil, nil, nil
	light, burst = nil, nil
	if shaft then
		shaft:Destroy()
		shaft = nil
	end
end

-- One frame: the case's fall and slow turn, its lid, the shaft fading, the sign's words.
function HourlyDropView.step()
	local c, r = caseModel, rest
	if c and r and c.Parent then
		local clock = os.clock()
		local k = (clock - arrivedAt) / FALL
		local drop = HIGH * (1 - ease(k))
		local bob = 0.12 * math.sin(clock * 1.3)
		local yaw = SPIN * clock
		c:PivotTo(r * CFrame.new(0, drop + 0.15 + bob, 0) * CFrame.Angles(0, yaw, 0))
		if k >= 1 and not landed then
			landed = true
			emit(40)
			pcall(Sound.shimmer)
		end
		local s = shaft
		if s then
			s.Transparency = 0.82 + 0.18 * math.clamp((k - 1) / 0.6, 0, 1)
			if k > 1.6 then
				s:Destroy()
				shaft = nil
			end
		end
		local b, l, lr, hr = body(), lid(), lidRest, hingeRel
		if b and l and lr then
			local a = 0
			if lidOpenedAt then
				a = math.rad(108) * ease((clock - lidOpenedAt) / 0.9)
			end
			if hr then
				l.CFrame = b.CFrame * hr * CFrame.Angles(a, 0, 0) * hr:Inverse() * lr
			else
				l.CFrame = b.CFrame * lr
			end
		end
	elseif c and not c.Parent then
		caseGone()
	end
	local sg = sign
	if sg then
		local t = now()
		local open = Workspace:GetAttribute("DropOpen") == true
		local hour = Plan.hourOf(t)
		local w = HourlyDropView.words(t, open, nil, nil, Workspace:GetAttribute("DropPiece") :: string?, Workspace:GetAttribute("DropNextPiece") :: string?, mine.opened and mine.hour == hour, mine.have)
		for key, text in w do
			local lab = (sg :: any)[key] :: TextLabel?
			if lab and lab.Text ~= text then
				lab.Text = text
			end
		end
		sg.time.TextColor3 = if open then BRIGHT else IVORY
		sg.chip.BackgroundTransparency = if open and not (mine.opened and mine.hour == hour) then 0.62 else 0.84
	end
end

-- This guest opened it (the server said): the lid lifts, the light, the burst.
local function openedHere()
	if caseModel and not lidOpenedAt then
		lidOpenedAt = os.clock()
		setGlow(true)
		emit(90)
	end
	local b = body()
	local prompt = b and b:FindFirstChild("OpenPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = false
	end
end

-- What the server told this screen.
function HourlyDropView.told(m: { [string]: any })
	if m.stage == "down" then
		HourlyDropView.toast("The Hourly Drop", string.format("The courier's case is down in the Foyer: %s inside, for %d minutes.", nameOf(m.piece), math.floor(Plan.window() / 60)))
	elseif m.stage == "opened" then
		mine.hour = Plan.hourOf(now())
		mine.opened = true
		mine.count = tonumber(m.count) or mine.count
		if type(m.have) == "table" then
			mine.have = m.have
		end
		openedHere()
		pcall(Sound.shimmer)
		local paid = tonumber(m.paid) or 0
		local line = if m.new then string.format("+%d Gilt, and %s for your collection.", paid, nameOf(m.piece)) else string.format("+%d Gilt. %s is already yours.", paid, nameOf(m.piece))
		HourlyDropView.toast("The Hourly Drop", line)
	end
end

-- Asks the server how things stand for this guest (on arrival, and when an hour turns).
function HourlyDropView.ask()
	local ok, r = pcall(function()
		return Remotes.func("HourlyDropAsk"):InvokeServer({ op = "state" })
	end)
	if ok and type(r) == "table" and r.ok == true then
		mine.hour = tonumber(r.hour) or -1
		mine.opened = r.opened == true
		mine.count = tonumber(r.count) or 0
		mine.have = if type(r.have) == "table" then r.have else {}
		if mine.opened then
			openedHere()
		end
	end
end

-- (For tests: how things stand on this screen.)
function HourlyDropView.mine(): { [string]: any }
	return { hour = mine.hour, opened = mine.opened, count = mine.count, lidOpen = lidOpenedAt ~= nil, sign = sign ~= nil, case = caseModel ~= nil }
end

local function watch(m: Instance)
	if not m:IsA("Model") or m.Name ~= "HourlyDrop" then
		return
	end
	local top = m:WaitForChild("Top", 10)
	local at = top and top:FindFirstChild("SignAt")
	if at and at:IsA("Attachment") and not sign then
		sign = makeSign(at)
	end
	local existing = m:FindFirstChild("Case")
	if existing and existing:IsA("Model") then
		caseArrived(existing, false)
	end
	m.ChildAdded:Connect(function(child)
		if child.Name == "Case" and child:IsA("Model") then
			-- (A new hour: what this guest opened is last hour's.)
			if mine.hour ~= Plan.hourOf(now()) then
				mine.opened = false
			end
			caseArrived(child, true)
		end
	end)
	m.ChildRemoved:Connect(function(child)
		if child == caseModel then
			caseGone()
		end
	end)
end

function HourlyDropView.start()
	Remotes.event("Salute").OnClientEvent:Connect(function(m)
		if type(m) == "table" and m.op == "hourlyDrop" then
			pcall(HourlyDropView.told, m)
		end
	end)
	local found = Workspace:FindFirstChild("HourlyDrop")
	if found then
		task.spawn(watch, found)
	end
	Workspace.ChildAdded:Connect(function(child)
		if child.Name == "HourlyDrop" then
			task.spawn(watch, child)
		end
	end)
	task.spawn(HourlyDropView.ask)
	RunService.Heartbeat:Connect(function()
		pcall(HourlyDropView.step)
	end)
end

return HourlyDropView

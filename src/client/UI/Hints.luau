--!strict
-- Tips at the foot of the screen: one short line at a time and never often, for the new guest and
-- the regular alike (Voice.Hints): how to start, quicker ways to sort, what's on right now (Admin
-- Abuse's games, the Grand Prix, the Ballroom, a holiday's game), what Gilt can buy. Each shows
-- when it fits and not again for a while (or once a visit); none while sorting, sitting, driving,
-- with a panel open or while a show has the screen. A tap puts it away.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local Hints = {}

-- Set by Main: whether a show or the table has the screen.
Hints.isBusy = function(): boolean
	return false
end

local GAP = 75 -- seconds at least between two tips
local SHOW = 8 -- seconds a tip stays
local MAX_W = 620

local C = Brand.Colours
local started = os.clock()
local sat = 0
local shownAt: { [string]: number } = {}
local lastShown = -math.huge
local current: GuiObject? = nil

-- A sitting at a table (Main, from TableClient): some tips wait for the first few.
function Hints.noteSat()
	sat += 1
end

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function abusing(): boolean
	local ends = Workspace:GetAttribute("AbuseUntil")
	return type(ends) == "number" and ends > now()
end

local function holidayOn(): boolean
	for _, id in HouseEvents.Holidays do
		local ends = Workspace:GetAttribute(HouseEvents.attribute(id))
		if type(ends) == "number" and ends > now() then
			return true
		end
	end
	return false
end

-- Whether the guest is in a seat (a chair, a bench, a car): no tips then.
local function seated(): boolean
	local ok, yes = pcall(function(): boolean
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local seat = humanoid and (humanoid :: any).SeatPart
		return seat ~= nil and seat.Parent ~= nil
	end)
	return ok and yes
end

-- Whether a tip fits right now (beyond its time into the visit and the sittings it waits for).
local function fits(id: string): boolean
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if id == "newcomer" then
		return sat == 0
	elseif id == "keys" then
		return not touch
	elseif id == "tap" then
		return touch
	elseif id == "abuse" then
		return abusing()
	elseif id == "grandPrix" then
		return Workspace:GetAttribute("GrandPrixDoor") == "open" and not abusing()
	elseif id == "ballroom" then
		return Workspace:GetAttribute("BallroomState") == "open"
	elseif id == "holiday" then
		return holidayOn()
	elseif id == "shop" then
		return (tonumber(Players.LocalPlayer:GetAttribute("Gilt")) or 0) >= 1500
	end
	return true
end

-- What's on comes first, then the first steps, then the rest.
local ORDER = { abuse = 1, grandPrix = 2, ballroom = 3, holiday = 4, newcomer = 5, tap = 6, keys = 6, streak = 7, rooms = 8 }

-- The tip to show now, if any.
function Hints.pick(): Voice.Hint?
	local t = os.clock()
	local best: Voice.Hint? = nil
	local bestRank = math.huge
	for i, h in Voice.Hints.list do
		local last = shownAt[h.id]
		local again = h.every or 0
		local fresh = last == nil or (again > 0 and t - last >= again)
		if fresh and t - started >= (h.after or 0) and sat >= (h.sat or 0) and fits(h.id) then
			local rank = (ORDER[h.id] or 20) * 100 + i
			if rank < bestRank then
				best, bestRank = h, rank
			end
		end
	end
	return best
end

local function hide()
	local f = current
	current = nil
	if not f then
		return
	end
	for _, d in f:GetDescendants() do
		if d:IsA("TextLabel") then
			Ease.play(d, Ease.info(0.25, Enum.EasingStyle.Sine), { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			Ease.play(d, Ease.info(0.25, Enum.EasingStyle.Sine), { Transparency = 1 })
		end
	end
	Ease.play(f, Ease.info(0.25, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 })
	task.delay(0.3, function()
		f:Destroy()
	end)
end

-- A tip on screen: a slim slip of dark glass at the foot of the screen, a gold TIP chip at its
-- start and the line beside it (on two lines if it must).
function Hints.show(line: string)
	hide()
	local size = 15
	local chipW = 42
	local pad = 14
	local text = Theme.measure(line, size, Brand.Fonts.bodyMedium)
	local room = math.min(MAX_W, Root.size().X - 40)
	local inner = room - chipW - pad * 3
	local width = math.min(room, math.ceil(text.X) + chipW + pad * 3)
	local lines = if text.X > inner then 2 else 1
	local height = if lines == 2 then 56 else 38
	local slip = Instance.new("TextButton")
	slip.Name = "Tip"
	slip.AutoButtonColor = false
	slip.Text = ""
	slip.AnchorPoint = Vector2.new(0.5, 1)
	slip.Position = UDim2.new(0.5, 0, 1, -14)
	slip.Size = UDim2.fromOffset(width, height)
	slip.BackgroundColor3 = Color3.new(1, 1, 1)
	slip.BackgroundTransparency = 0.04
	slip.ZIndex = 30
	local fill = Instance.new("UIGradient")
	fill.Rotation = 20
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(58, 46, 30)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(26, 23, 21)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(14, 13, 15)),
	})
	fill.Parent = slip
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = slip
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = C.gold
	edge.Transparency = 0.35
	edge.Parent = slip
	local chip = Theme.text(slip, Voice.Hints.label, 11, "caps", {
		Name = "Chip",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, pad, 0.5, 0),
		Size = UDim2.fromOffset(chipW, 20),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.gold,
		TextColor3 = Color3.fromRGB(34, 24, 8),
		ZIndex = 31,
	})
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = chip
	Theme.text(slip, line, size, "bodyMedium", {
		Name = "Line",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, pad * 2 + chipW, 0.5, 0),
		Size = UDim2.new(1, -(pad * 3 + chipW), 1, -8),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		TextColor3 = C.bone,
		ZIndex = 31,
	})
	slip.Parent = Root.hud
	current = slip
	slip.Activated:Connect(function()
		if current == slip then
			hide()
		end
	end)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.94
	scale.Parent = slip
	Ease.play(scale, Ease.info(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	task.delay(SHOW, function()
		if current == slip then
			hide()
		end
	end)
end

-- Looks now: shows the tip that fits, if the screen is free and it's been a while.
function Hints.check()
	local t = os.clock()
	if t - lastShown < GAP or current ~= nil then
		return
	end
	if Hints.isBusy() or seated() or Root.top() ~= nil then
		return
	end
	local h = Hints.pick()
	if not h then
		return
	end
	shownAt[h.id] = t
	lastShown = t
	Hints.show(h.line)
end

-- (For tests: as though `seconds` more of the visit had gone by, and nothing shown yet.)
function Hints.reset(seconds: number?)
	started = os.clock() - (seconds or 0)
	lastShown = -math.huge
	table.clear(shownAt)
	hide()
end

function Hints.start()
	task.spawn(function()
		while true do
			task.wait(5)
			pcall(Hints.check)
		end
	end)
end

return Hints

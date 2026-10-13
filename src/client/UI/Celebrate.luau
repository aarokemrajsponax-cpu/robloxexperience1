--!strict
-- Moments worth celebrating on a guest's own screen:
--   levelUp  LEVEL UP! in the middle of the screen, the new level in its tier's colour, its name,
--            what it brought (Gilt, and Gems every tenth level), with confetti and a fanfare
--   badge    a card sliding in from the right: the badge's glyph in its tier's colour, its name
--            and what it was for (several in a row wait their turn)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Levels = require(ReplicatedStorage.Shared.Levels)
local Flakes = require(script.Parent.Parent.World.Flakes)
local NeoFX = require(script.Parent.Parent.World.NeoFX)
local Sound = require(script.Parent.Parent.Sound)

local Celebrate = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local HEAVY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BODY = Font.fromEnum(Enum.Font.GothamMedium)
-- (The big words: the house's sans at its heaviest, cut clean.)
local IMPACT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

local TIER: { [string]: Color3 } = {
	bronze = rgb(205, 127, 72),
	silver = rgb(200, 206, 216),
	gold = rgb(246, 200, 92),
	platinum = rgb(150, 230, 255),
}

local function screen(): ScreenGui
	local gui = player:FindFirstChild("PlayerGui")
	local existing = gui and gui:FindFirstChild("MaisonCelebrate")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonCelebrate"
	s.ResetOnSpawn = false
	s.IgnoreGuiInset = false
	s.DisplayOrder = 66
	s.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	s.Parent = gui
	return s
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function sound(name: string, volume: number?, pitch: number?)
	pcall(Sound.play, name, volume or 0.8, pitch)
end

local function format(n: number): string
	local text = tostring(math.floor(n))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

function Celebrate.levelUp(level: number, title: string, gilt: number, gems: number)
	local gui = screen()
	local old = gui:FindFirstChild("LevelUp")
	if old then
		old:Destroy()
	end
	local colour = Levels.colour(level)
	local box = Instance.new("Frame")
	box.Name = "LevelUp"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.38)
	box.Size = UDim2.fromOffset(520, 260)
	box.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = box
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 56)
	head.FontFace = IMPACT
	head.TextScaled = true
	head.TextColor3 = Color3.new(1, 1, 1)
	head.TextStrokeTransparency = 0.25
	head.TextStrokeColor3 = rgb(36, 22, 4)
	head.Text = "LEVEL UP!"
	-- (In gold metal: bright at the top, deep at the foot.)
	local metal = Instance.new("UIGradient")
	metal.Rotation = 90
	metal.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(255, 250, 226)),
		ColorSequenceKeypoint.new(0.5, rgb(255, 214, 120)),
		ColorSequenceKeypoint.new(1, rgb(214, 150, 50)),
	})
	metal.Parent = head
	head.Parent = box
	local disc = Instance.new("TextLabel")
	disc.Name = "Level"
	disc.AnchorPoint = Vector2.new(0.5, 0)
	disc.Position = UDim2.new(0.5, 0, 0, 62)
	disc.Size = UDim2.fromOffset(110, 110)
	disc.BackgroundColor3 = rgb(20, 16, 12)
	disc.FontFace = HEAVY
	disc.TextScaled = true
	disc.TextColor3 = colour
	disc.Text = tostring(level)
	disc.Parent = box
	corner(disc, 55)
	local ring = Instance.new("UIStroke")
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Thickness = 5
	ring.Color = colour
	ring.Parent = disc
	local dp = Instance.new("UIPadding")
	dp.PaddingTop = UDim.new(0, 22)
	dp.PaddingBottom = UDim.new(0, 22)
	dp.PaddingLeft = UDim.new(0, 18)
	dp.PaddingRight = UDim.new(0, 18)
	dp.Parent = disc
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(0, 180)
	name.Size = UDim2.new(1, 0, 0, 34)
	name.FontFace = HEAVY
	name.TextScaled = true
	name.TextColor3 = colour
	name.TextStrokeTransparency = 0.3
	name.Text = string.upper(title)
	name.Parent = box
	local reward = Instance.new("TextLabel")
	reward.BackgroundTransparency = 1
	reward.Position = UDim2.fromOffset(0, 220)
	reward.Size = UDim2.new(1, 0, 0, 26)
	reward.FontFace = HEAVY
	reward.TextScaled = true
	reward.TextColor3 = rgb(255, 230, 150)
	reward.TextStrokeTransparency = 0.4
	reward.Text = "+" .. format(gilt) .. " Gilt" .. (if gems > 0 then "  ·  +" .. format(gems) .. " Gems" else "")
	reward.Parent = box
	TweenService:Create(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	sound("regalFanfare", 0.9)
	task.delay(0.15, sound, "shimmerFall", 0.8)
	Flakes.fall({
		seconds = 3.5,
		centre = function(): Vector3?
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			return if r and r:IsA("BasePart") then r.Position else nil
		end,
		colours = { colour, rgb(255, 240, 200), rgb(255, 214, 110) },
		material = Enum.Material.SmoothPlastic,
		size = Vector3.new(0.34, 0.02, 0.18),
		count = 60,
		radius = 9,
		height = 10,
		fall = 3,
		flutter = 3,
		burst = true,
	})
	task.delay(3.4, function()
		if box.Parent then
			local t = TweenService:Create(scale, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.01 })
			t:Play()
			t.Completed:Once(function()
				box:Destroy()
			end)
		end
	end)
end

-- Badges wait their turn, one card at a time.
local queue: { { [string]: any } } = {}
local showing = false

local function nextBadge()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local b = table.remove(queue, 1) :: { [string]: any }
	local colour = TIER[tostring(b.tier)] or rgb(246, 200, 92)
	local neo = { a = colour:Lerp(Color3.new(1, 1, 1), 0.25), b = colour, core = Color3.new(1, 1, 1) }
	local hasNext = type(b.nextName) == "string" and type(b.nextTarget) == "number"
	local gui = screen()
	-- A pane of dark glass at the side: the medal in a turning ring of its tier's light, the
	-- badge resolving in, how many the guest has now, and the next on the same ladder.
	local card = Instance.new("Frame")
	card.Name = "Badge"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, 380, 0.3, 0)
	card.Size = UDim2.fromOffset(350, if hasNext then 122 else 96)
	card.BackgroundColor3 = Color3.new(1, 1, 1)
	card.BackgroundTransparency = 0.04
	card.Parent = gui
	corner(card, 14)
	local fill = Instance.new("UIGradient")
	fill.Rotation = 90
	fill.Color = ColorSequence.new(rgb(24, 24, 32):Lerp(colour, 0.12), rgb(8, 8, 12))
	fill.Parent = card
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Thickness = 1.5
	edge.Color = Color3.new(1, 1, 1)
	edge.Parent = card
	NeoFX.shimmer(edge, neo, 30)
	-- The medal.
	local medal = Instance.new("Frame")
	medal.Name = "Medal"
	medal.BackgroundColor3 = colour
	medal.BackgroundTransparency = 0.82
	medal.Position = UDim2.fromOffset(14, 16)
	medal.Size = UDim2.fromOffset(64, 64)
	medal.Parent = card
	corner(medal, 32)
	local ring = Instance.new("UIStroke")
	ring.Color = Color3.new(1, 1, 1)
	ring.Thickness = 2
	ring.Parent = medal
	local sweep = Instance.new("UIGradient")
	sweep.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, colour), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(1, colour) })
	sweep.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 0.9) })
	sweep.Parent = ring
	TweenService:Create(sweep, TweenInfo.new(2.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 }):Play()
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(0.66, 0.66)
	glyph.TextScaled = true
	glyph.Text = tostring(b.glyph or "🏅")
	glyph.Parent = medal
	local top = Instance.new("TextLabel")
	top.BackgroundTransparency = 1
	top.Position = UDim2.fromOffset(92, 12)
	top.Size = UDim2.new(1, -104, 0, 14)
	top.FontFace = NeoFX.MONO_BOLD
	top.TextSize = 11
	top.TextXAlignment = Enum.TextXAlignment.Left
	top.TextColor3 = neo.a
	top.Text = "BADGE EARNED  ·  " .. string.upper(tostring(b.tier or ""))
	top.Parent = card
	if type(b.count) == "number" and type(b.total) == "number" then
		-- (How many now, of how many.)
		local tally = Instance.new("TextLabel")
		tally.Name = "Tally"
		tally.BackgroundTransparency = 1
		tally.AnchorPoint = Vector2.new(1, 0)
		tally.Position = UDim2.new(1, -12, 0, 12)
		tally.Size = UDim2.fromOffset(90, 14)
		tally.FontFace = NeoFX.MONO
		tally.TextSize = 11
		tally.TextXAlignment = Enum.TextXAlignment.Right
		tally.TextColor3 = rgb(200, 196, 188)
		tally.Text = string.format("%d / %d", b.count, b.total)
		tally.Parent = card
		top.Size = UDim2.new(1, -200, 0, 14)
	end
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(92, 28)
	name.Size = UDim2.new(1, -104, 0, 24)
	name.FontFace = HEAVY
	name.TextSize = 19
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = rgb(250, 244, 230)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Text = tostring(b.name)
	name.Parent = card
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromOffset(92, 54)
	line.Size = UDim2.new(1, -104, 0, 28)
	line.FontFace = BODY
	line.TextSize = 11
	line.TextWrapped = true
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextColor3 = rgb(190, 184, 172)
	line.Text = tostring(b.line or "")
	line.Parent = card
	if hasNext then
		-- The next on the ladder, and how far along: a thin bar of the tier's light.
		local have = math.max(0, tonumber(b.nextHave) or 0)
		local target = math.max(1, tonumber(b.nextTarget) or 1)
		local nextLine = Instance.new("TextLabel")
		nextLine.Name = "Next"
		nextLine.BackgroundTransparency = 1
		nextLine.Position = UDim2.fromOffset(14, 88)
		nextLine.Size = UDim2.new(1, -28, 0, 14)
		nextLine.FontFace = NeoFX.MONO
		nextLine.TextSize = 11
		nextLine.TextXAlignment = Enum.TextXAlignment.Left
		nextLine.TextTruncate = Enum.TextTruncate.AtEnd
		nextLine.TextColor3 = rgb(214, 208, 198)
		nextLine.Text = string.format("NEXT:  %s  ·  %s / %s", string.upper(tostring(b.nextName)), format(math.min(have, target)), format(target))
		nextLine.Parent = card
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.BorderSizePixel = 0
		track.BackgroundColor3 = Color3.new(1, 1, 1)
		track.BackgroundTransparency = 0.88
		track.Position = UDim2.fromOffset(14, 106)
		track.Size = UDim2.new(1, -28, 0, 4)
		track.Parent = card
		corner(track, 2)
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = colour
		bar.Size = UDim2.fromScale(0, 1)
		bar.Parent = track
		corner(bar, 2)
		task.delay(0.5, function()
			if bar.Parent then
				TweenService:Create(bar, TweenInfo.new(0.8, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = UDim2.fromScale(math.clamp(have / target, 0.02, 1), 1) }):Play()
			end
		end)
	end
	TweenService:Create(card, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(1, -14, 0.3, 0) }):Play()
	task.delay(0.12, function()
		if card.Parent and name.Parent then
			NeoFX.decode(name, name.Text, 0.35)
		end
	end)
	sound(if b.tier == "gold" or b.tier == "platinum" then "regalFanfare" else "shimmer", 0.7)
	task.delay(4.2, function()
		local out = TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(1, 380, 0.3, 0) })
		out:Play()
		out.Completed:Once(function()
			card:Destroy()
			showing = false
			nextBadge()
		end)
	end)
end

-- Whether a badge is coming in at the side (the objective card steps aside for it).
function Celebrate.badgeUp(): boolean
	return showing
end

function Celebrate.badge(b: { [string]: any })
	table.insert(queue, b)
	nextBadge()
end

return Celebrate

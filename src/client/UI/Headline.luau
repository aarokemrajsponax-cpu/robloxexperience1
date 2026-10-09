--!strict
-- What the owner says to the whole house, on every guest's screen:
--   headline    big words across the top of the screen for a few seconds (gold, red, rainbow,
--               ice or green), with the owner's name on them
--   countdown   big numbers counting down in the middle of the screen ("ADMIN ABUSE IN 10"),
--               then GO!
--   giveaway    the guests' names turning over fast, slowing, and landing on the winner (free: the
--               owner's gift; nobody pays or stakes anything), with confetti
--   levelPublic a guest reached a big level (every tenth): a line for everyone
-- The server sends them (only the owner can ask it to); the words were checked by Roblox's filter
-- before they got here. Shown above every panel, so nobody misses one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Flakes = require(script.Parent.Parent.World.Flakes)
local Sound = require(script.Parent.Parent.Sound)
local Root = require(script.Parent.Root)
local Toast = require(script.Parent.Toast)

local Headline = {}

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local HEAVY = Font.fromEnum(Enum.Font.GothamBlack)
local IMPACT = Font.fromEnum(Enum.Font.LuckiestGuy)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, rgb(255, 70, 120)),
	ColorSequenceKeypoint.new(0.2, rgb(255, 170, 60)),
	ColorSequenceKeypoint.new(0.4, rgb(255, 236, 90)),
	ColorSequenceKeypoint.new(0.6, rgb(90, 240, 140)),
	ColorSequenceKeypoint.new(0.8, rgb(80, 170, 255)),
	ColorSequenceKeypoint.new(1, rgb(190, 100, 255)),
})

export type Style = { bg: Color3, bg2: Color3, edge: Color3, text: Color3 }
Headline.Styles = {
	gold = { bg = rgb(34, 24, 6), bg2 = rgb(70, 48, 10), edge = rgb(255, 204, 90), text = rgb(255, 226, 150) },
	red = { bg = rgb(70, 8, 14), bg2 = rgb(140, 20, 30), edge = rgb(255, 110, 110), text = rgb(255, 240, 240) },
	rainbow = { bg = rgb(16, 10, 30), bg2 = rgb(40, 20, 70), edge = rgb(255, 255, 255), text = rgb(255, 255, 255) },
	ice = { bg = rgb(8, 24, 48), bg2 = rgb(20, 60, 110), edge = rgb(170, 220, 255), text = rgb(225, 245, 255) },
	green = { bg = rgb(6, 34, 18), bg2 = rgb(14, 80, 40), edge = rgb(120, 255, 170), text = rgb(220, 255, 230) },
} :: { [string]: Style }

local function screen(): ScreenGui
	local gui = player:FindFirstChild("PlayerGui")
	local existing = gui and gui:FindFirstChild("MaisonHeadlines")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonHeadlines"
	s.ResetOnSpawn = false
	s.IgnoreGuiInset = false
	s.DisplayOrder = 70
	s.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	s.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	s.Parent = gui
	return s
end

local function sound(name: string, volume: number?, pitch: number?)
	pcall(Sound.play, name, volume or 0.8, pitch)
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

---------------------------------------------------------------------------------------------------
-- Headlines
---------------------------------------------------------------------------------------------------
local current: Frame? = nil

-- How tall the words will stand at a width (measured by the engine; a fair guess if it can't).
local function wordsHeight(text: string, size: number, width: number): number
	local ok, bounds = pcall(function()
		return game:GetService("TextService"):GetTextSize(text, size, Enum.Font.GothamBlack, Vector2.new(width, 10000))
	end)
	if ok and typeof(bounds) == "Vector2" and bounds.Y > 0 then
		return math.ceil(bounds.Y) + 4
	end
	local perLine = math.max(1, math.floor(width / (size * 0.66)))
	local lines = math.max(1, math.ceil((utf8.len(text) or #text) / perLine))
	return lines * math.ceil(size * 1.2) + 4
end

function Headline.show(text: string, by: string, style: string?, seconds: number?)
	local look = Headline.Styles[style or "gold"] or Headline.Styles.gold
	local old = current
	if old then
		old:Destroy()
	end
	local gui = screen()
	local view = Root.viewport()
	local width = math.clamp(view.X - 24, 280, 940)
	local size = if view.X < 600 then 22 else 30
	local textHeight = wordsHeight(text, size, width - 32)
	local bar = Instance.new("Frame")
	bar.Name = "Headline"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, -(textHeight + 80))
	bar.Size = UDim2.fromOffset(width, 10 + 22 + 6 + textHeight + 12)
	-- (White under the gradient, so the gradient's colours are the colours seen.)
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	corner(bar, 10)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(look.bg, look.bg2)
	grad.Rotation = 90
	grad.Parent = bar
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Thickness = 3
	edge.Color = look.edge
	edge.Parent = bar
	if style == "rainbow" then
		local eg = Instance.new("UIGradient")
		eg.Color = RAINBOW
		eg.Parent = edge
	end
	-- Who's speaking: a small chip, centred at the top. (Placed by hand rather than by a list
	-- layout, so the glint below can sweep freely.)
	local chip = Instance.new("TextLabel")
	chip.Name = "From"
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0, 10)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.fromOffset(0, 22)
	chip.BackgroundColor3 = look.edge
	chip.BackgroundTransparency = 0.1
	chip.FontFace = HEAVY
	chip.TextSize = 13
	chip.TextColor3 = look.bg
	chip.Text = "📣  " .. (if by ~= "" then by else "The owner")
	chip.Parent = bar
	corner(chip, 11)
	local cp = Instance.new("UIPadding")
	cp.PaddingLeft = UDim.new(0, 10)
	cp.PaddingRight = UDim.new(0, 10)
	cp.Parent = chip
	-- The words.
	local words = Instance.new("TextLabel")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(16, 38)
	words.Size = UDim2.new(1, -32, 0, textHeight)
	words.FontFace = HEAVY
	words.TextSize = size
	words.TextWrapped = true
	words.TextColor3 = look.text
	words.TextStrokeTransparency = 0.5
	words.Text = text
	words.Parent = bar
	local textGrad: UIGradient? = nil
	if style == "rainbow" then
		local tg = Instance.new("UIGradient")
		tg.Color = RAINBOW
		tg.Parent = words
		textGrad = tg
	end
	-- A glint sweeping across it.
	local glint = Instance.new("Frame")
	glint.Name = "Glint"
	glint.BackgroundColor3 = Color3.new(1, 1, 1)
	glint.BackgroundTransparency = 0.82
	glint.BorderSizePixel = 0
	glint.Size = UDim2.new(0, 60, 1, 30)
	glint.Position = UDim2.new(0, -80, 0, -15)
	glint.Rotation = 18
	glint.ZIndex = 3
	glint.Parent = bar
	bar.ClipsDescendants = true
	current = bar
	TweenService:Create(bar, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 0, 8) }):Play()
	sound("regalFanfare", 0.7)
	if style == "rainbow" or style == "red" then
		task.delay(0.2, sound, "airHorn", 0.8)
	end
	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if current ~= bar or not bar.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		local t = os.clock() - started
		glint.Position = UDim2.new((t * 0.6) % 1.4 - 0.2, 0, 0, -15)
		local g = textGrad
		if g then
			g.Offset = Vector2.new(math.sin(t * 2) * 0.4, 0)
		end
	end)
	task.delay(seconds or 6, function()
		if current == bar then
			current = nil
			local out = TweenService:Create(bar, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0, -(textHeight + 80)) })
			out:Play()
			out.Completed:Once(function()
				bar:Destroy()
			end)
		end
	end)
end

---------------------------------------------------------------------------------------------------
-- Countdowns
---------------------------------------------------------------------------------------------------
local countdown: Frame? = nil
local countToken = 0

function Headline.stopCountdown()
	countToken += 1
	local c = countdown
	countdown = nil
	if c then
		c:Destroy()
	end
end

function Headline.countdown(label: string, endsAt: number)
	Headline.stopCountdown()
	local my = countToken
	local gui = screen()
	local box = Instance.new("Frame")
	box.Name = "Countdown"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.36)
	box.Size = UDim2.fromOffset(520, 220)
	box.Parent = gui
	countdown = box
	local top = Instance.new("TextLabel")
	top.Name = "Label"
	top.BackgroundTransparency = 1
	top.Size = UDim2.new(1, 0, 0, 40)
	top.FontFace = HEAVY
	top.TextScaled = true
	top.TextColor3 = rgb(255, 226, 150)
	top.TextStrokeTransparency = 0.2
	top.TextStrokeColor3 = rgb(40, 24, 4)
	top.Text = label
	top.Parent = box
	local number = Instance.new("TextLabel")
	number.Name = "Number"
	number.BackgroundTransparency = 1
	number.AnchorPoint = Vector2.new(0.5, 0)
	number.Position = UDim2.new(0.5, 0, 0, 44)
	number.Size = UDim2.new(1, 0, 0, 170)
	number.FontFace = IMPACT
	number.TextScaled = true
	number.TextColor3 = rgb(255, 214, 110)
	number.TextStrokeTransparency = 0
	number.TextStrokeColor3 = rgb(40, 24, 4)
	number.Parent = box
	local scale = Instance.new("UIScale")
	scale.Parent = number
	task.spawn(function()
		local last = -1
		while countToken == my and box.Parent do
			local left = math.ceil(endsAt - Workspace:GetServerTimeNow())
			if left <= 0 then
				break
			end
			if left ~= last then
				last = left
				number.Text = tostring(left)
				number.TextColor3 = if left <= 3 then rgb(255, 90, 80) else rgb(255, 214, 110)
				scale.Scale = 1.7
				TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
				sound("chime", 0.7, if left <= 3 then 1.5 else 1)
			end
			task.wait(0.05)
		end
		if countToken ~= my or not box.Parent then
			return
		end
		top.Text = ""
		number.Text = "GO!"
		number.TextColor3 = rgb(120, 255, 140)
		scale.Scale = 2.2
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		sound("airHorn", 1)
		task.wait(1.4)
		if countdown == box then
			countdown = nil
		end
		box:Destroy()
	end)
end

---------------------------------------------------------------------------------------------------
-- Giveaways
---------------------------------------------------------------------------------------------------
function Headline.giveaway(names: { string }, winner: string, winnerId: number?, amount: number, by: string)
	local gui = screen()
	local old = gui:FindFirstChild("Giveaway")
	if old then
		old:Destroy()
	end
	local card = Instance.new("Frame")
	card.Name = "Giveaway"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.42)
	card.Size = UDim2.fromOffset(math.min(460, Root.viewport().X - 24), 190)
	card.BackgroundColor3 = rgb(24, 16, 6)
	card.BackgroundTransparency = 0.05
	card.Parent = gui
	corner(card, 14)
	local edge = Instance.new("UIStroke")
	edge.Thickness = 3
	edge.Color = rgb(255, 204, 90)
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = card
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Position = UDim2.fromOffset(0, 14)
	head.Size = UDim2.new(1, 0, 0, 30)
	head.FontFace = HEAVY
	head.TextScaled = true
	head.TextColor3 = rgb(255, 214, 110)
	head.Text = string.format("🎁 GIVEAWAY · %s GILT", tostring(amount))
	head.Parent = card
	local reel = Instance.new("TextLabel")
	reel.Name = "Reel"
	reel.BackgroundTransparency = 1
	reel.Position = UDim2.fromOffset(12, 56)
	reel.Size = UDim2.new(1, -24, 0, 64)
	reel.FontFace = IMPACT
	reel.TextScaled = true
	reel.TextColor3 = rgb(255, 255, 255)
	reel.Text = names[1] or winner
	reel.Parent = card
	local foot = Instance.new("TextLabel")
	foot.BackgroundTransparency = 1
	foot.Position = UDim2.new(0, 0, 1, -44)
	foot.Size = UDim2.new(1, 0, 0, 26)
	foot.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	foot.TextScaled = true
	foot.TextColor3 = rgb(236, 216, 166)
	foot.Text = "From " .. by .. " · free for everyone in the house"
	foot.Parent = card
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = card
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	sound("partyHorn", 0.8)
	task.spawn(function()
		-- The names turn over, quickly at first, then slower, then stop on the winner.
		local list = if #names > 0 then names else { winner }
		local delay = 0.05
		local i = math.random(1, #list)
		while delay < 0.32 and card.Parent do
			i = i % #list + 1
			reel.Text = list[i]
			sound("hover", 0.5, 1.2)
			task.wait(delay)
			delay *= 1.12
		end
		if not card.Parent then
			return
		end
		local mine = winnerId == player.UserId
		reel.Text = if mine then "YOU WON!" else winner
		reel.TextColor3 = rgb(255, 214, 110)
		foot.Text = if mine then string.format("+%s Gilt, from %s", tostring(amount), by) else winner .. " wins " .. tostring(amount) .. " Gilt!"
		sound("crowdCheer", 0.9)
		sound("regalFanfare", 0.7)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and mine then
			Flakes.fall({
				seconds = 5,
				centre = function(): Vector3?
					local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					return if r and r:IsA("BasePart") then r.Position else nil
				end,
				colours = { rgb(255, 214, 110), rgb(255, 240, 200), rgb(255, 120, 160), rgb(120, 200, 255) },
				material = Enum.Material.SmoothPlastic,
				size = Vector3.new(0.34, 0.02, 0.18),
				count = 80,
				radius = 10,
				height = 12,
				fall = 3,
				flutter = 3,
				burst = true,
			})
		end
		task.wait(3.5)
		if card.Parent then
			local t = TweenService:Create(scale, TweenInfo.new(0.25), { Scale = 0.01 })
			t:Play()
			t.Completed:Once(function()
				card:Destroy()
			end)
		end
	end)
end

function Headline.start()
	Remotes.event("Salute").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "headline" and type(m.text) == "string" then
			Headline.show(m.text, tostring(m.by or ""), if type(m.style) == "string" then m.style else nil, if type(m.seconds) == "number" then m.seconds else nil)
		elseif m.op == "countdown" then
			if m.stop == true then
				Headline.stopCountdown()
			elseif type(m.label) == "string" and type(m.endsAt) == "number" then
				Headline.countdown(m.label, m.endsAt)
			end
		elseif m.op == "giveaway" and type(m.winner) == "string" then
			local names = {}
			if type(m.names) == "table" then
				for _, n in m.names do
					if type(n) == "string" then
						table.insert(names, n)
					end
				end
			end
			Headline.giveaway(names, m.winner, if type(m.winnerId) == "number" then m.winnerId else nil, if type(m.amount) == "number" then m.amount else 0, tostring(m.by or "The owner"))
		elseif m.op == "levelPublic" and type(m.name) == "string" and m.userId ~= player.UserId then
			Toast.show("Level " .. tostring(m.level), string.format("%s reached level %s: %s.", m.name, tostring(m.level), tostring(m.title or "")), 4)
		end
	end)
end

return Headline

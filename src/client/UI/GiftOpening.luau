--!strict
-- Opening the gifts from the North Pole: a screen of its own. The gift stands in the middle in its
-- wrapping and ribbon, a bow on top; OPEN, and it shakes, the lid flies off in a burst of light, and
-- what was inside rises out of it: Gilt, a heap of Gilt, Gems, or (rarely) a trove of Gems. OPEN
-- ALL opens the rest, each one appearing in turn, with the totals. What each holds is decided on the
-- server when it's opened; this screen only shows it. The odds are written at the foot, as they
-- are, and so is that the gifts are free: nothing about them is ever sold.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local HolidayMeter = require(script.Parent.HolidayMeter)
local Sound = require(script.Parent.Parent.Sound)

local GiftOpening = {}

local C = Brand.Colours
local NAME = "GiftOpening"
local GEM = Color3.fromRGB(120, 210, 255)

-- Set by World/HolidayPlay: the guest's gifts waiting changed (after opening some), and Ride
-- again (board Santa's sleigh).
GiftOpening.changed = function(_left: number) end
GiftOpening.ride = function() end

local GLYPH = { gilt = "💰", moreGilt = "🏆", gems = "💎", moreGems = "👑" }
local SAYS = { gilt = "Gilt!", moreGilt = "A heap of Gilt!", gems = "Gems!", moreGems = "A trove of Gems!" }

local function ask(request: { [string]: any }): any
	local ok, r = pcall(function()
		return Remotes.func("HolidayAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else { ok = false, why = "The house couldn't open it just now." }
end

local function number(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

local function corner(f: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = f
end

local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, colour: Color3, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

-- The gift, drawn: a box in its wrapping, a ribbon down the middle, a lid, a bow.
local function drawGift(parent: Instance, wrap: Color3, ribbon: Color3): (Frame, Frame)
	local gift = frame(parent, "Gift", UDim2.fromOffset(240, 250), UDim2.fromScale(0.5, 0.5), Color3.new(), Vector2.new(0.5, 0.5))
	gift.BackgroundTransparency = 1
	local box = frame(gift, "Box", UDim2.fromOffset(220, 170), UDim2.new(0.5, 0, 1, 0), wrap, Vector2.new(0.5, 1))
	corner(box, 14)
	local bg = Instance.new("UIGradient")
	bg.Rotation = 90
	bg.Color = ColorSequence.new(wrap:Lerp(Color3.new(1, 1, 1), 0.18), wrap:Lerp(Color3.new(0, 0, 0), 0.32))
	bg.Parent = box
	local band = frame(box, "Ribbon", UDim2.new(0, 38, 1, 0), UDim2.fromScale(0.5, 0.5), ribbon)
	local rg = Instance.new("UIGradient")
	rg.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, ribbon:Lerp(Color3.new(1, 1, 1), 0.3)),
		ColorSequenceKeypoint.new(0.5, ribbon),
		ColorSequenceKeypoint.new(1, ribbon:Lerp(Color3.new(0, 0, 0), 0.2)),
	})
	rg.Parent = band
	local lid = frame(gift, "Lid", UDim2.fromOffset(246, 54), UDim2.new(0.5, 0, 1, -164), wrap:Lerp(Color3.new(1, 1, 1), 0.08), Vector2.new(0.5, 1))
	corner(lid, 12)
	local lg = Instance.new("UIGradient")
	lg.Rotation = 90
	lg.Color = ColorSequence.new(wrap:Lerp(Color3.new(1, 1, 1), 0.28), wrap:Lerp(Color3.new(0, 0, 0), 0.15))
	lg.Parent = lid
	frame(lid, "Ribbon", UDim2.new(0, 40, 1, 0), UDim2.fromScale(0.5, 0.5), ribbon)
	-- The bow: two loops and a knot, on the lid.
	for _, sx in { -1, 1 } do
		local loop = frame(lid, "Loop", UDim2.fromOffset(64, 40), UDim2.new(0.5, sx * 34, 0, -14), ribbon)
		loop.Rotation = sx * -24
		corner(loop, 20)
		local inner = frame(loop, "Inner", UDim2.fromOffset(34, 16), UDim2.fromScale(0.5, 0.5), ribbon:Lerp(Color3.new(0, 0, 0), 0.35))
		corner(inner, 8)
	end
	local knot = frame(lid, "Knot", UDim2.fromOffset(30, 30), UDim2.new(0.5, 0, 0, -12), ribbon:Lerp(Color3.new(0, 0, 0), 0.1))
	corner(knot, 15)
	return gift, lid
end

-- A soft fan of light turning slowly behind the gift (and behind what came out of it).
local function halo(parent: Instance, colour: Color3, size: number)
	local holder = frame(parent, "Halo", UDim2.fromOffset(size, size), UDim2.fromScale(0.5, 0.46), colour)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 0
	-- (Each ray a bar right across, centred: a frame turns about its own middle.)
	for k = 1, 6 do
		local ray = frame(holder, "Ray", UDim2.new(0, 24, 1, 0), UDim2.fromScale(0.5, 0.5), colour)
		ray.Rotation = k * 30
		ray.BackgroundTransparency = 0.8
		ray.ZIndex = 0
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = ray
	end
	local glow = frame(holder, "Glow", UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.5, 0.5), colour)
	glow.BackgroundTransparency = 0.86
	glow.ZIndex = 0
	corner(glow, size)
	TweenService:Create(holder, TweenInfo.new(36, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
end

-- Little stars twinkling round the gift.
local function twinkles(parent: Instance, colour: Color3)
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + 0.4
		local star = Instance.new("TextLabel")
		star.Name = "Twinkle"
		star.BackgroundTransparency = 1
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.new(0.5, math.cos(a) * (150 + (k % 3) * 18), 0.46, math.sin(a) * (110 + (k % 2) * 16))
		star.Size = UDim2.fromOffset(22, 22)
		star.FontFace = Brand.Fonts.heavy
		star.TextScaled = true
		star.Text = "✦"
		star.TextColor3 = colour
		star.TextTransparency = 0.2
		star.ZIndex = 0
		star.Parent = parent
		TweenService:Create(star, TweenInfo.new(0.9 + (k % 4) * 0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, k * 0.13), { TextTransparency = 0.9, Rotation = 45 }):Play()
	end
end

-- A burst of light behind something: rays turning, and a flash.
local function burst(parent: Instance, colour: Color3)
	local holder = frame(parent, "Burst", UDim2.fromOffset(10, 10), UDim2.fromScale(0.5, 0.42), colour)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 0
	for k = 1, 5 do
		local ray = frame(holder, "Ray", UDim2.fromOffset(18, 20), UDim2.fromScale(0.5, 0.5), colour)
		ray.Rotation = k * 36
		ray.BackgroundTransparency = 0.25
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = ray
		TweenService:Create(ray, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(26, 840), BackgroundTransparency = 1 }):Play()
	end
	TweenService:Create(holder, TweenInfo.new(1.4, Enum.EasingStyle.Linear), { Rotation = 60 }):Play()
	local flash = frame(parent, "Flash", UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Color3.new(1, 1, 1))
	flash.BackgroundTransparency = 0.35
	TweenService:Create(flash, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	task.delay(1.5, function()
		holder:Destroy()
		flash:Destroy()
	end)
end

-- Confetti out of the gift.
local function confetti(parent: Instance, colours: { Color3 })
	for k = 1, 36 do
		local c = frame(parent, "Confetto", UDim2.fromOffset(8, 14), UDim2.fromScale(0.5, 0.45), colours[(k % #colours) + 1])
		c.Rotation = math.random(0, 360)
		local a = math.random() * math.pi * 2
		local r = 160 + math.random() * 260
		local to = UDim2.new(0.5, math.cos(a) * r, 0.45, math.sin(a) * r * 0.7 + 120)
		TweenService:Create(c, TweenInfo.new(1.2 + math.random() * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = to, Rotation = c.Rotation + math.random(-400, 400), BackgroundTransparency = 1 }):Play()
		task.delay(1.8, function()
			c:Destroy()
		end)
	end
end

type Ui = { group: Frame, stage: Frame, count: TextLabel, keys: Frame, left: number, busy: boolean, scale: number }
local ui: Ui? = nil

local function setCount(u: Ui)
	u.count.Text = if u.left == 1 then "1 gift to open" elseif u.left > 1 then number(u.left) .. " gifts to open" else "Every gift opened"
end

local refreshKeys: (u: Ui) -> ()

local function clearStage(u: Ui)
	for _, d in u.stage:GetChildren() do
		if not d:IsA("UIScale") then
			d:Destroy()
		end
	end
end

local function showGift(u: Ui)
	clearStage(u)
	if u.left <= 0 then
		local done = Instance.new("TextLabel")
		done.BackgroundTransparency = 1
		done.AnchorPoint = Vector2.new(0.5, 0.5)
		done.Position = UDim2.fromScale(0.5, 0.45)
		done.Size = UDim2.new(1, -40, 0, 120)
		done.FontFace = Brand.Fonts.displayItalic
		done.TextSize = 26
		done.TextWrapped = true
		done.TextColor3 = C.bone
		done.Text = if Workspace:GetAttribute(HolidayGames.ATTRIBUTE) == "christmas" then "That's every gift. Santa's sleigh brings more from the North Pole." else "That's every gift. Merry Christmas!"
		done.Parent = u.stage
		return
	end
	local w = HolidayProps.WRAPS[math.random(1, #HolidayProps.WRAPS)]
	halo(u.stage, w[2]:Lerp(C.brightGold, 0.5), 420)
	twinkles(u.stage, C.brightGold)
	local gift = drawGift(u.stage, w[1], w[2])
	gift.Position = UDim2.fromScale(0.5, 0.5)
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6 * u.scale
	scale.Parent = gift
	TweenService:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = u.scale }):Play()
	-- It breathes, waiting.
	TweenService:Create(gift, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Rotation = 2 }):Play()
end

-- What came out of one gift, risen out of the box.
local function reveal(u: Ui, r: { [string]: any })
	clearStage(u)
	local kind = tostring(r.kind)
	local gems = if type(r.gems) == "number" then r.gems else 0
	local gilt = if type(r.gilt) == "number" then r.gilt else 0
	local colour = if gems > 0 then GEM else C.brightGold
	halo(u.stage, colour, 380)
	burst(u.stage, colour)
	confetti(u.stage, if gems > 0 then { GEM, Color3.new(1, 1, 1), Color3.fromRGB(180, 140, 255) } else { C.brightGold, Color3.new(1, 1, 1), Color3.fromRGB(255, 120, 110) })
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Prize"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.4)
	glyph.Size = UDim2.fromOffset(150 * u.scale, 150 * u.scale)
	glyph.TextScaled = true
	glyph.Text = GLYPH[kind] or "🎁"
	glyph.Parent = u.stage
	local gs = Instance.new("UIScale")
	gs.Scale = 0
	gs.Parent = glyph
	TweenService:Create(gs, TweenInfo.new(0.55, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local says = Instance.new("TextLabel")
	says.Name = "Says"
	says.BackgroundTransparency = 1
	says.AnchorPoint = Vector2.new(0.5, 0)
	says.Position = UDim2.fromScale(0.5, 0.64)
	says.Size = UDim2.new(1, 0, 0, 34)
	says.FontFace = Brand.Fonts.displayItalic
	says.TextSize = 30
	says.TextColor3 = C.bone
	says.Text = SAYS[kind] or "A gift!"
	says.Parent = u.stage
	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.BackgroundTransparency = 1
	amount.AnchorPoint = Vector2.new(0.5, 0)
	amount.Position = UDim2.new(0.5, 0, 0.64, 36)
	amount.Size = UDim2.new(1, 0, 0, 52)
	amount.FontFace = Brand.Fonts.figures
	amount.TextSize = 46
	amount.TextColor3 = colour
	amount.Text = if gems > 0 then "+" .. number(gems) .. (if gems == 1 then " GEM" else " GEMS") else "+" .. number(gilt) .. " GILT"
	amount.Parent = u.stage
	if r.converted == true then
		local note = Instance.new("TextLabel")
		note.Name = "Note"
		note.BackgroundTransparency = 1
		note.AnchorPoint = Vector2.new(0.5, 0)
		note.Position = UDim2.new(0.5, 0, 0.64, 92)
		note.Size = UDim2.new(1, 0, 0, 20)
		note.FontFace = Brand.Fonts.body
		note.TextSize = 14
		note.TextColor3 = C.smoke
		note.Text = "Today's Gems are all given out, so it came as Gilt."
		note.Parent = u.stage
	end
	if kind == "moreGems" then
		Sound.play("regalFanfare", 0.7)
		Sound.play("celebrate", 0.5)
	elseif gems > 0 then
		Sound.play("crystal", 0.8)
	else
		Sound.play("coinDrop", 0.7)
	end
	Sound.play("reward", 0.6)
end

local function openOne(u: Ui)
	if u.busy or u.left <= 0 then
		return
	end
	u.busy = true
	refreshKeys(u)
	local gift = u.stage:FindFirstChild("Gift") :: Frame?
	-- It shakes; the lid comes off.
	if gift then
		for k = 1, 6 do
			TweenService:Create(gift, TweenInfo.new(0.07), { Rotation = if k % 2 == 0 then 7 else -7 }):Play()
			Sound.play("deal", 0.5, 0.9 + k * 0.06)
			task.wait(0.08)
		end
		gift.Rotation = 0
		local lid = gift:FindFirstChild("Lid") :: Frame?
		if lid then
			TweenService:Create(lid, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = lid.Position - UDim2.fromOffset(-60, 220), Rotation = 28, BackgroundTransparency = 1 }):Play()
		end
		Sound.play("place", 0.6, 1.3)
		task.wait(0.25)
	end
	local r = ask({ op = "open", n = 1 })
	if r.ok and type(r.results) == "table" and r.results[1] then
		u.left = if type(r.gifts) == "number" then r.gifts else math.max(0, u.left - 1)
		GiftOpening.changed(u.left)
		reveal(u, r.results[1])
		setCount(u)
		task.wait(1.4)
	else
		clearStage(u)
		local why = Instance.new("TextLabel")
		why.BackgroundTransparency = 1
		why.AnchorPoint = Vector2.new(0.5, 0.5)
		why.Position = UDim2.fromScale(0.5, 0.45)
		why.Size = UDim2.new(1, -40, 0, 80)
		why.FontFace = Brand.Fonts.body
		why.TextSize = 18
		why.TextWrapped = true
		why.TextColor3 = C.bone
		why.Text = tostring(r.why or "Not just now.")
		why.Parent = u.stage
		if type(r.gifts) == "number" then
			u.left = r.gifts
		end
		task.wait(1.4)
	end
	u.busy = false
	refreshKeys(u)
end

local function openAll(u: Ui)
	if u.busy or u.left <= 0 then
		return
	end
	u.busy = true
	refreshKeys(u)
	clearStage(u)
	local grid = Instance.new("Frame")
	grid.Name = "All"
	grid.BackgroundTransparency = 1
	grid.AnchorPoint = Vector2.new(0.5, 0)
	grid.Position = UDim2.fromScale(0.5, 0.04)
	grid.Size = UDim2.new(1, -20, 0.78, 0)
	grid.Parent = u.stage
	local layout = Instance.new("UIGridLayout")
	-- (Twenty to a screen at full size; smaller tiles when there are more, so they all fit.)
	local many = u.left > 20
	layout.CellSize = if many then UDim2.fromOffset(66, 44) else UDim2.fromOffset(100, 66)
	layout.CellPadding = if many then UDim2.fromOffset(6, 6) else UDim2.fromOffset(8, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local totalGilt, totalGems, n = 0, 0, 0
	while u.left > 0 and n < 40 do
		local r = ask({ op = "open", n = math.min(10, u.left) })
		if not r.ok or type(r.results) ~= "table" then
			break
		end
		u.left = if type(r.gifts) == "number" then r.gifts else 0
		for _, x in r.results do
			n += 1
			local gems = if type(x.gems) == "number" then x.gems else 0
			local gilt = if type(x.gilt) == "number" then x.gilt else 0
			totalGilt += gilt
			totalGems += gems
			local tile = Instance.new("Frame")
			tile.Name = "Tile"
			tile.LayoutOrder = n
			tile.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
			tile.BackgroundTransparency = 0.05
			corner(tile, 12)
			local s = Instance.new("UIStroke")
			s.Color = if gems > 0 then GEM else C.gold
			s.Thickness = if x.kind == "moreGems" or x.kind == "moreGilt" then 2.5 else 1.2
			s.Parent = tile
			local g = Instance.new("TextLabel")
			g.BackgroundTransparency = 1
			g.Size = UDim2.new(1, 0, 0.55, 0)
			g.TextScaled = true
			g.Text = GLYPH[tostring(x.kind)] or "🎁"
			g.Parent = tile
			local t = Instance.new("TextLabel")
			t.BackgroundTransparency = 1
			t.Position = UDim2.fromScale(0, 0.55)
			t.Size = UDim2.new(1, 0, 0.4, 0)
			t.FontFace = Brand.Fonts.heavy
			t.TextScaled = true
			t.TextColor3 = if gems > 0 then GEM else C.brightGold
			t.Text = if gems > 0 then "+" .. gems .. " 💎" else "+" .. number(gilt)
			t.Parent = tile
			local sc = Instance.new("UIScale")
			sc.Scale = 0.4
			sc.Parent = tile
			tile.Parent = grid
			TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			Sound.play(if gems > 0 then "crystal" else "coinDrop", 0.4, 1 + (n % 5) * 0.05)
			task.wait(0.12)
		end
		GiftOpening.changed(u.left)
	end
	local sum = Instance.new("TextLabel")
	sum.Name = "Totals"
	sum.BackgroundTransparency = 1
	sum.AnchorPoint = Vector2.new(0.5, 1)
	sum.Position = UDim2.new(0.5, 0, 1, -6)
	sum.Size = UDim2.new(1, 0, 0, 40)
	sum.FontFace = Brand.Fonts.figures
	sum.TextSize = 30
	sum.TextColor3 = C.brightGold
	sum.Text = "+" .. number(totalGilt) .. " GILT" .. (if totalGems > 0 then "   +" .. number(totalGems) .. (if totalGems == 1 then " GEM" else " GEMS") else "")
	sum.Parent = u.stage
	Sound.play("reward", 0.7)
	setCount(u)
	u.busy = false
	refreshKeys(u)
end

function refreshKeys(u: Ui)
	for _, d in u.keys:GetChildren() do
		if d:IsA("GuiObject") then
			d:Destroy()
		end
	end
	if u.busy then
		return
	end
	if u.left > 0 then
		local k = Theme.key(u.keys, if u.stage:FindFirstChild("Gift") then "Open" else "Open the next", true, function()
			if u.stage:FindFirstChild("Gift") then
				task.spawn(openOne, u)
			else
				showGift(u)
				refreshKeys(u)
			end
		end, 200)
		k.LayoutOrder = 1
		if u.left > 1 then
			local all = Theme.key(u.keys, "Open all", false, function()
				task.spawn(openAll, u)
			end, 180)
			all.LayoutOrder = 2
		end
	else
		-- (While Santa's sleigh still comes: gifts keep after Christmas, the rides don't.)
		if Workspace:GetAttribute(HolidayGames.ATTRIBUTE) == "christmas" then
			local ride = Theme.key(u.keys, "Ride again", true, function()
				Root.close(NAME)
				GiftOpening.ride()
			end, 200)
			ride.LayoutOrder = 1
		end
	end
	local close = Theme.key(u.keys, "Close", false, function()
		Root.close(NAME)
	end, 150)
	close.LayoutOrder = 3
	Theme.paint(u.keys, "christmas")
end

-- What a gift may hold, how much, and its chance (exact, from the house's own numbers).
local function oddsLine(): string
	local parts = {}
	local pole = Config.data.HolidayGames.pole :: any
	for _, o in HolidayGames.giftOdds() do
		local range = pole[o.id]
		local unit = if o.id == "gems" or o.id == "moreGems" then "Gems" else "Gilt"
		local amount = if type(range) == "table" then string.format("%s–%s %s", number(range[1]), number(range[2]), unit) else o.name
		table.insert(parts, o.glyph .. " " .. amount .. " " .. o.odds)
	end
	return "What a gift holds: " .. table.concat(parts, "  ·  ") .. ". Free from Santa's sleigh; never sold."
end

-- Opens the screen with `waiting` gifts to open: its heading, the stage, the keys and the odds,
-- one under another (so nothing overlaps, on a phone or a wide screen).
function GiftOpening.open(waiting: number)
	if Root.isOpen(NAME) then
		return
	end
	-- (The sleigh's meter has done its job: the gifts have the screen to themselves.)
	HolidayMeter.hide()
	local room = Root.size()
	local group = Instance.new("Frame")
	group.Name = NAME
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(1, 1)
	-- (White under the gradient, so its colours are its own: Christmas red, the night, pine.)
	group.BackgroundColor3 = Color3.new(1, 1, 1)
	group.BackgroundTransparency = 0.12
	group.Parent = Root.panels
	local vignette = Instance.new("UIGradient")
	vignette.Rotation = 90
	vignette.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(86, 16, 30)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 11, 16)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 64, 40)),
	})
	vignette.Parent = group
	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Size = UDim2.new(1, -32, 1, -24)
	column.Parent = group
	local list = Theme.list(column, 12)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local title = Theme.text(column, "Gifts from the North Pole", 34, "display", { LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 0) })
	title.Name = "Title"
	local count = Theme.text(column, "", 18, "body", { LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), TextColor3 = C.smoke })
	count.Name = "Count"
	-- The stage: as tall as the screen allows round the heading, keys and odds.
	local stageW = math.clamp(room.X - 40, 300, 640)
	local stageH = math.clamp(room.Y - 300, 230, 420)
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.LayoutOrder = 3
	stage.BackgroundTransparency = 1
	stage.Size = UDim2.fromOffset(stageW, stageH)
	stage.ClipsDescendants = false
	stage.Parent = column
	local keys = Instance.new("Frame")
	keys.Name = "Keys"
	keys.LayoutOrder = 4
	keys.BackgroundTransparency = 1
	keys.Size = UDim2.new(1, 0, 0, 48)
	keys.Parent = column
	local row = Theme.list(keys, 12, true)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	-- The odds, as they are, and that it's free.
	local odds = Theme.text(column, oddsLine(), 13, "body", {
		LayoutOrder = 5,
		Size = UDim2.new(1, 0, 0, 0),
		TextColor3 = C.smoke,
	})
	odds.Name = "Odds"
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(760, math.huge)
	limit.Parent = odds
	local u: Ui = { group = group, stage = stage, count = count, keys = keys, left = math.max(0, waiting), busy = false, scale = math.clamp(stageH / 360, 0.66, 1) }
	ui = u
	setCount(u)
	showGift(u)
	refreshKeys(u)
	Root.open(NAME, group, function()
		ui = nil
	end, true)
	Sound.play("bellTree", 0.5)
end

-- For tests: the screen, if it's open.
function GiftOpening.isOpen(): boolean
	return ui ~= nil and Root.isOpen(NAME)
end

return GiftOpening

--!strict
-- What a holiday game gives you, said with a flourish: a card that pops up low in the middle of
-- the screen (a treat from a host, a turkey caught, an egg found, gifts loaded on the sleigh): the
-- thing itself, big, in a glow of its colour; who gave it or what it is; and what it paid, Gilt in
-- gold and Gems in blue. It pops in, glows, then rises and fades; a second one stacks above the
-- first. The numbers are the server's own (what was paid), never worked out here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Sound = require(script.Parent.Parent.Sound)

local HolidayPop = {}

local C = Brand.Colours
local GEM = Color3.fromRGB(120, 210, 255)

export type Pop = {
	glyph: string,
	title: string, -- small capitals over it (who, or what)
	line: string?, -- what it is
	gilt: number?,
	gems: number?,
	colour: Color3?, -- its glow
	big: boolean?, -- the golden ones: bigger, brighter, longer
	extra: string?, -- one more line under the chips (small)
}

local live: { Frame } = {}
-- (Above the notices that come in at the foot of the screen while the events strip is up.)
local BASE = 196

local function corner(f: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = f
end

local function number(n: number): string
	local s = tostring(math.floor(n + 0.5))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return if out:sub(1, 1) == "," then out:sub(2) else out
end

local function chip(parent: Instance, text: string, colour: Color3, order: number)
	local f = Instance.new("Frame")
	f.Name = "Chip"
	f.LayoutOrder = order
	-- (Sized to its words: heavy capitals at 15 run about 10 wide each.)
	f.Size = UDim2.fromOffset(math.ceil((utf8.len(text) or #text) * 10.2) + 24, 26)
	f.BackgroundColor3 = colour:Lerp(Color3.new(0, 0, 0), 0.72)
	f.BackgroundTransparency = 0.1
	corner(f, 13)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = 1.5
	stroke.Transparency = 0.15
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = f
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = Brand.Fonts.heavy
	t.TextSize = 15
	t.TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.35)
	t.Text = text
	t.Parent = f
	f.Parent = parent
end

local function restack()
	-- The newest at the foot, the older ones above it.
	-- (Measured by the size each was made at: one still popping in is drawn smaller for a moment.)
	local y = 0
	for i = #live, 1, -1 do
		local f = live[i]
		if f.Parent then
			TweenService:Create(f, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, -BASE - y) }):Play()
			y += f.Size.Y.Offset + 10
		end
	end
end

function HolidayPop.show(p: Pop)
	local colour = p.colour or C.glow
	local hold = if p.big then 4.6 else 3.2
	local holder = Instance.new("Frame")
	holder.Name = "HolidayPop"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -BASE)
	-- As tall as its words need: a line that wraps makes the card taller, never spills out of it.
	local cardW = if p.big then 440 else 380
	local medalSize = if p.big then 96 else 80
	local wordsW = cardW - (medalSize + 38)
	local lineH = if p.line then math.max(22, Theme.measure(p.line, 19, Brand.Fonts.displayItalic, wordsW).Y + 2) else 0
	local extraH = if p.extra then math.max(16, Theme.measure(p.extra, 13, Brand.Fonts.body, wordsW).Y) else 0
	local need = 16 + (if p.line then 4 + lineH else 0) + 4 + 26 + (if p.extra then 4 + extraH else 0) + 22
	holder.Size = UDim2.fromOffset(cardW, math.max(if p.big then 124 else 104, need))
	holder.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
	holder.BackgroundTransparency = 0.08
	corner(holder, 18)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = if p.big then 2.5 else 1.8
	stroke.Transparency = 0.1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = holder
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.fromRGB(34, 32, 40), Color3.fromRGB(10, 10, 14))
	sheen.Parent = holder
	local scale = Instance.new("UIScale")
	scale.Scale = 0.6
	scale.Parent = holder
	-- The thing itself, in its glow.
	local size = if p.big then 96 else 80
	local medal = Instance.new("Frame")
	medal.Name = "Medal"
	medal.AnchorPoint = Vector2.new(0, 0.5)
	medal.Position = UDim2.new(0, 12, 0.5, 0)
	medal.Size = UDim2.fromOffset(size, size)
	medal.BackgroundColor3 = colour
	medal.BackgroundTransparency = 0.55
	corner(medal, size // 2)
	local mg = Instance.new("UIGradient")
	mg.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.4), colour:Lerp(Color3.new(0, 0, 0), 0.4))
	mg.Rotation = 120
	mg.Parent = medal
	local ring = Instance.new("UIStroke")
	ring.Color = colour:Lerp(Color3.new(1, 1, 1), 0.5)
	ring.Thickness = 2
	ring.Parent = medal
	medal.Parent = holder
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Size = UDim2.fromScale(0.78, 0.78)
	glyph.TextScaled = true
	glyph.Text = p.glyph
	glyph.Parent = medal
	-- Who, what, and what it paid.
	local text = Instance.new("Frame")
	text.Name = "Words"
	text.BackgroundTransparency = 1
	text.Position = UDim2.new(0, size + 26, 0, 0)
	text.Size = UDim2.new(1, -(size + 38), 1, 0)
	text.Parent = holder
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = text
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.LayoutOrder = 1
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 16)
	title.FontFace = Brand.Fonts.bodyBold
	title.TextSize = 13
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.25)
	title.Text = Caps(p.title)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Parent = text
	if p.line then
		local line = Instance.new("TextLabel")
		line.Name = "Line"
		line.LayoutOrder = 2
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, lineH)
		line.FontFace = Brand.Fonts.displayItalic
		line.TextSize = 19
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextColor3 = C.bone
		line.TextWrapped = true
		line.TextYAlignment = Enum.TextYAlignment.Top
		line.Text = p.line
		line.Parent = text
	end
	local chips = Instance.new("Frame")
	chips.Name = "Chips"
	chips.LayoutOrder = 3
	chips.BackgroundTransparency = 1
	chips.Size = UDim2.new(1, 0, 0, 26)
	chips.Parent = text
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = chips
	local gilt = p.gilt or 0
	local gems = p.gems or 0
	if gilt > 0 then
		chip(chips, "+" .. number(gilt) .. " GILT", C.gold, 1)
	end
	if gems > 0 then
		chip(chips, "+" .. number(gems) .. (if gems == 1 then " GEM" else " GEMS"), GEM, 2)
	end
	if p.extra then
		local extra = Instance.new("TextLabel")
		extra.Name = "Extra"
		extra.LayoutOrder = 4
		extra.BackgroundTransparency = 1
		extra.Size = UDim2.new(1, 0, 0, extraH)
		extra.FontFace = Brand.Fonts.body
		extra.TextSize = 13
		extra.TextXAlignment = Enum.TextXAlignment.Left
		extra.TextColor3 = C.smoke
		extra.TextWrapped = true
		extra.Text = p.extra
		extra.Parent = text
	end
	holder.Parent = Root.toasts
	table.insert(live, holder)
	restack()
	-- In: a pop; the glow breathing while it stays; then up and away.
	TweenService:Create(scale, Ease.scaled(TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)), { Scale = 1 }):Play()
	TweenService:Create(medal, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.25 }):Play()
	if gems > 0 then
		Sound.play("crystal", 0.7)
	end
	if gilt > 0 then
		Sound.play("coinDrop", 0.55)
	end
	Sound.play(if p.big then "regalFanfare" else "reward", if p.big then 0.6 else 0.5)
	task.delay(hold, function()
		local fade = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		TweenService:Create(scale, fade, { Scale = 0.92 }):Play()
		TweenService:Create(holder, fade, { BackgroundTransparency = 1, Position = holder.Position - UDim2.fromOffset(0, 40) }):Play()
		TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
		for _, d in holder:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, fade, { TextTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, fade, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, fade, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.65, function()
			local i = table.find(live, holder)
			if i then
				table.remove(live, i)
			end
			holder:Destroy()
			restack()
		end)
	end)
	-- (Never more than three at once: the oldest goes.)
	while #live > 3 do
		local old = table.remove(live, 1)
		if old then
			old:Destroy()
		end
	end
end

-- For tests: how many are showing.
function HolidayPop.count(): number
	return #live
end

return HolidayPop

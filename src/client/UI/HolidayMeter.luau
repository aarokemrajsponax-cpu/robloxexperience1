--!strict
-- The holiday games' count, always in sight at the foot of the screen while you play one: in the
-- Harvest Field, your free catches this visit (🦃 3 / 5, a pip each), then the catches you've
-- bought, or UNLIMITED with the Turkey Hunter Pass; at the North Pole, the gifts in your arms
-- (2 / 5) and on the sleigh this trip (7 / 15), with a bar that fills.
--
-- And the offer, when the free ones are used up: what more costs, in Robux, said plainly (the
-- price on the key, what you get for it), with the wait for the free ones beside it. Nothing here
-- decides a count or a price: the server's messages say both, and the server asks Roblox for the
-- purchase window.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Fade = require(script.Parent.Fade)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local HolidayMeter = {}

local C = Brand.Colours
local ROBUX = utf8.char(0xE002)
local rgb = Color3.fromRGB

-- Set by HolidayPlay: ask the server to show the purchase window for holiday product `n`
-- (ProductConfig.Holiday: 1 10 More, 2 the Hunter Pass, 3 a sleigh ride, 4 the Season Pass).
HolidayMeter.buy = function(_n: number) end

export type Section = {
	label: string, -- small capitals over the count ("FREE CATCHES")
	value: string, -- the count ("3 / 5", "UNLIMITED")
	pips: number?, -- how many pips (up to 6), with `lit` of them lit
	lit: number?,
	bar: number?, -- or a bar, filled this far (0..1)
	colour: Color3?,
}

local meter: Frame? = nil
local spec = ""
local offerCard: Frame? = nil
local OFFER = "HolidayOffer"

local function corner(f: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = f
end

local function label(parent: Instance, text: string, size: number, font: Font, colour: Color3, x: number, y: number, w: number): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = size
	l.FontFace = font
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, math.ceil(size * 1.2))
	l.Parent = parent
	return l
end

local PIP, PIP_GAP, BAR_W = 12, 5, 96

-- One count: its small capitals, and under them the number with its pips or bar. Returns its
-- width (exactly what its words and pips need).
local function section(parent: Instance, s: Section, x: number): number
	local accent = s.colour or C.brightGold
	local cap = Caps(s.label)
	local capW = Theme.measure(cap, 12, Brand.Fonts.bodyBold).X
	local valueW = Theme.measure(s.value, 22, Brand.Fonts.heavy).X
	local extra = 0
	if s.pips and s.pips > 0 then
		extra = 10 + s.pips * PIP + (s.pips - 1) * PIP_GAP
	elseif s.bar then
		extra = 10 + BAR_W
	end
	local w = math.max(capW, valueW + extra)
	label(parent, cap, 12, Brand.Fonts.bodyBold, C.lightGold, x, 8, w)
	label(parent, s.value, 22, Brand.Fonts.heavy, Color3.new(1, 1, 1), x, 24, valueW)
	local px = x + valueW + 10
	if s.pips and s.pips > 0 then
		for k = 1, s.pips do
			local p = Instance.new("Frame")
			p.Name = "Pip"
			p.BorderSizePixel = 0
			p.Size = UDim2.fromOffset(PIP, PIP)
			p.Position = UDim2.fromOffset(px + (k - 1) * (PIP + PIP_GAP), 31)
			local on = k <= (s.lit or 0)
			p.BackgroundColor3 = if on then accent else rgb(60, 58, 64)
			p.BackgroundTransparency = if on then 0 else 0.2
			corner(p, 4)
			p.Parent = parent
		end
	elseif s.bar then
		local track = Instance.new("Frame")
		track.Name = "Bar"
		track.BorderSizePixel = 0
		track.BackgroundColor3 = rgb(50, 48, 56)
		track.Size = UDim2.fromOffset(BAR_W, 10)
		track.Position = UDim2.fromOffset(px, 32)
		corner(track, 5)
		track.Parent = parent
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = accent
		fill.Size = UDim2.new(math.clamp(s.bar, 0, 1), 0, 1, 0)
		corner(fill, 5)
		fill.Parent = track
	end
	return w
end

-- Shows the meter: `glyph` in its round badge, then each count, side by side, divided.
function HolidayMeter.show(glyph: string, colour: Color3, sections: { Section })
	local key = glyph
	for _, s in sections do
		key ..= "|" .. s.label .. "|" .. s.value .. "|" .. tostring(s.lit) .. "|" .. tostring(s.bar)
	end
	if key == spec and meter and meter.Parent then
		return
	end
	local fresh = meter == nil or meter.Parent == nil
	spec = key
	if meter then
		meter:Destroy()
	end
	local f = Instance.new("Frame")
	f.Name = "HolidayMeter"
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Position = UDim2.new(0.5, 0, 1, -18)
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.BackgroundTransparency = 0.04
	f.BorderSizePixel = 0
	corner(f, 29)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = colour
	stroke.Thickness = 2
	stroke.Transparency = 0.1
	stroke.Parent = f
	-- (In the holiday's own colours, from its glow at the top corner down to the foot.)
	local g = Instance.new("UIGradient")
	g.Rotation = 62
	g.Color = Theme.sequence(Theme.mood(Theme.holidayMood()).panel)
	g.Parent = f
	-- The badge.
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.Size = UDim2.fromOffset(44, 44)
	badge.Position = UDim2.fromOffset(7, 7)
	badge.BackgroundColor3 = colour
	badge.BorderSizePixel = 0
	corner(badge, 22)
	badge.Parent = f
	local icon = Instance.new("TextLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Text = glyph
	icon.TextSize = 26
	icon.Parent = badge
	local x = 64
	for i, s in sections do
		if i > 1 then
			local line = Instance.new("Frame")
			line.Name = "Divider"
			line.BorderSizePixel = 0
			line.BackgroundColor3 = rgb(80, 76, 84)
			line.Size = UDim2.fromOffset(1, 34)
			line.Position = UDim2.fromOffset(x + 4, 12)
			line.Parent = f
			x += 18
		end
		x += section(f, s, x)
	end
	f.Size = UDim2.fromOffset(x + 20, 58)
	f.Parent = Root.hud
	meter = f
	if fresh then
		f.Position = UDim2.new(0.5, 0, 1, 40)
		Ease.play(f, Ease.scaled(Ease.settle), { Position = UDim2.new(0.5, 0, 1, -18) })
	end
end

function HolidayMeter.hide()
	spec = ""
	local f = meter
	meter = nil
	if f then
		f:Destroy()
	end
	HolidayMeter.closeOffer()
end

function HolidayMeter.showing(): boolean
	return meter ~= nil and meter.Parent ~= nil
end

---------------------------------------------------------------------------------------------------
-- The offer
---------------------------------------------------------------------------------------------------
export type Choice = { label: string, price: number?, best: boolean?, held: number?, press: () -> () }

function HolidayMeter.closeOffer()
	if offerCard then
		offerCard = nil
		Root.close(OFFER)
	end
end

-- The offer: a heading, a line, a key for each choice (its price on it, or how many are already
-- held), and a quiet line about the free way (`free`, said honestly: waiting, or another day).
-- Used by the holiday games and the Ballroom alike.
-- `mood`: the colours it wears (Theme.moods: a holiday's own, the Grand Prix's; the house's by
-- default).
function HolidayMeter.offer(title: string, line: string, choices: { Choice }, free: string?, mood: string?)
	if Root.isOpen(OFFER) then
		Root.close(OFFER)
	end
	local w = Root.panelWidth(420)
	local group, content = Theme.glass(Root.panels, OFFER, UDim2.fromOffset(w, 0), UDim2.new(0.5, 0, 1, -92), Vector2.new(0.5, 1))
	Theme.fitHeight(group, content)
	local pad = content:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingTop = UDim.new(0, 18)
		pad.PaddingBottom = UDim.new(0, 16)
		pad.PaddingLeft = UDim.new(0, 20)
		pad.PaddingRight = UDim.new(0, 20)
	end
	Theme.list(content, 8)
	Theme.text(content, title, 22, "display", { LayoutOrder = 1 })
	Theme.text(content, line, 14, "body", { LayoutOrder = 2, TextColor3 = C.smoke })
	for i, ch in choices do
		local cost = if ch.held and ch.held > 0 then string.format("%d held", ch.held) elseif ch.price then ROBUX .. " " .. tostring(ch.price) else "not on sale yet"
		local text = ch.label .. "  ·  " .. cost
		local press = ch.press
		local k = Theme.key(content, text, ch.best ~= true or #choices == 1, function()
			press()
		end, w - 40)
		k.LayoutOrder = 2 + i
		k.Size = UDim2.fromOffset(w - 40, 46)
		if ch.best and #choices > 1 then
			-- (The better value marked as such: it is.)
			local tag = Instance.new("TextLabel")
			tag.Name = "BestValue"
			tag.AnchorPoint = Vector2.new(1, 0.5)
			tag.Position = UDim2.new(1, -6, 0, 0)
			tag.Text = "BEST VALUE"
			tag.FontFace = Brand.Fonts.heavy
			tag.TextSize = 11
			tag.TextColor3 = rgb(24, 18, 8)
			tag.BackgroundColor3 = C.brightGold
			tag.Size = UDim2.fromOffset(Theme.measure("BEST VALUE", 11, Brand.Fonts.heavy).X + 14, 18)
			tag.ZIndex = k.ZIndex + 3
			corner(tag, 9)
			tag.Parent = k
		end
	end
	if free then
		Theme.text(content, free, 13, "body", { LayoutOrder = 50, TextColor3 = C.dim })
	end
	local close = Theme.key(content, "Not now", false, function()
		HolidayMeter.closeOffer()
	end, 160)
	close.LayoutOrder = 60
	close.Size = UDim2.fromOffset(160, 38)
	offerCard = group
	Theme.paint(group, mood or "house")
	Root.open(OFFER, group)
	Fade.set(group, 1)
	Fade.to(group, Ease.scaled(Ease.settle), 0)
end

function HolidayMeter.offering(): boolean
	return Root.isOpen(OFFER)
end

return HolidayMeter

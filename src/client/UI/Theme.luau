--!strict
-- The look of every panel (Build 65, natural): dark lacquer with rounded corners, a fine still edge
-- of gold, and a soft shadow beneath (no glow, no turning light); headings in heavy Gotham capitals
-- in warm ivory-gold, everything else in lighter Gotham SSm; gold keys that press in. Text follows
-- the Text size and Lettering settings live.
--
-- Typography: every size is set on one scale (Theme.Scale), with line spacing by kind; keys set
-- their words at a fixed size (never TextScaled, which squeezes letters), a step smaller only if
-- they'd not fit; and panels are plain Frames faded by Fade, never CanvasGroups (which draw text
-- into a texture and soften it).

local ContentProvider = game:GetService("ContentProvider")
local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Settings = require(ReplicatedStorage.Shared.Settings)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)

local Theme = {}

local C = Brand.Colours

---------------------------------------------------------------------------------------------------
-- Moods: the colours a panel and its keys are painted in. Everyday, the house's black and gold (a
-- warm glow of bronze down into deep black, edged in gold, with gold keys). Some places and every
-- holiday have their own: the Grand Prix in racing red and carbon, Halloween in violet and
-- pumpkin, Christmas in pine and crimson, the Harvest in amber, Easter in pastels, St Patrick's in
-- emerald. A panel's own words stay as they are; only the glass and the keys change.
---------------------------------------------------------------------------------------------------
export type Mood = {
	panel: { Color3 }, -- the glass, from its top corner down to its foot
	edge: { Color3 }, -- its outline, round from the light
	line: Color3, -- the line of light along its top
	gold: { Color3 }, -- a bright key, top to foot (its words are dark)
	goldText: Color3,
	goldEdge: Color3,
	plain: Color3, -- a plain key
	plainGlow: Color3, -- the glow at its top, fading down into it
	plainText: Color3,
	accent: Color3, -- the small capitals over a heading
}
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end
Theme.moods = {
	house = {
		panel = { rgb(62, 48, 28), rgb(26, 22, 20), rgb(13, 13, 16), rgb(24, 18, 11) },
		edge = { rgb(255, 232, 168), rgb(206, 166, 86), rgb(120, 90, 38) },
		line = C.lightGold,
		gold = { rgb(255, 242, 200), rgb(240, 204, 120), rgb(198, 148, 64) },
		goldText = rgb(28, 20, 6),
		goldEdge = rgb(255, 226, 150),
		plain = rgb(20, 18, 16),
		plainGlow = rgb(206, 166, 86),
		plainText = C.lightGold,
		accent = C.gold,
	},
	grandPrix = {
		panel = { rgb(104, 16, 26), rgb(40, 12, 18), rgb(13, 13, 15), rgb(30, 30, 34) },
		edge = { rgb(255, 255, 255), rgb(232, 44, 54), rgb(120, 12, 22) },
		line = rgb(255, 150, 150),
		gold = { rgb(255, 140, 116), rgb(232, 58, 58), rgb(166, 22, 32) },
		goldText = rgb(20, 6, 6),
		goldEdge = rgb(255, 176, 166),
		plain = rgb(22, 14, 16),
		plainGlow = rgb(232, 44, 54),
		plainText = rgb(255, 236, 234),
		accent = rgb(255, 104, 100),
	},
	halloween = {
		panel = { rgb(96, 36, 124), rgb(38, 16, 48), rgb(12, 10, 14), rgb(68, 30, 8) },
		edge = { rgb(255, 180, 84), rgb(200, 112, 255), rgb(90, 30, 120) },
		line = rgb(255, 186, 110),
		gold = { rgb(255, 218, 146), rgb(255, 152, 52), rgb(214, 92, 20) },
		goldText = rgb(24, 10, 4),
		goldEdge = rgb(255, 204, 128),
		plain = rgb(22, 14, 26),
		plainGlow = rgb(255, 140, 40),
		plainText = rgb(255, 222, 176),
		accent = rgb(255, 164, 74),
	},
	thanksgiving = {
		panel = { rgb(126, 62, 18), rgb(46, 28, 14), rgb(14, 11, 9), rgb(70, 42, 12) },
		edge = { rgb(255, 220, 146), rgb(228, 142, 52), rgb(120, 60, 20) },
		line = rgb(255, 214, 146),
		gold = { rgb(255, 226, 156), rgb(242, 168, 72), rgb(192, 108, 36) },
		goldText = rgb(28, 14, 4),
		goldEdge = rgb(255, 222, 164),
		plain = rgb(24, 16, 10),
		plainGlow = rgb(236, 152, 60),
		plainText = rgb(255, 232, 194),
		accent = rgb(242, 172, 84),
	},
	christmas = {
		panel = { rgb(20, 96, 58), rgb(14, 36, 26), rgb(12, 12, 14), rgb(92, 14, 28) },
		edge = { rgb(255, 255, 255), rgb(234, 198, 112), rgb(204, 40, 54) },
		line = rgb(255, 255, 255),
		gold = { rgb(255, 156, 156), rgb(228, 62, 72), rgb(166, 22, 38) },
		goldText = rgb(18, 6, 6),
		goldEdge = rgb(255, 222, 222),
		plain = rgb(14, 22, 18),
		plainGlow = rgb(62, 204, 124),
		plainText = rgb(242, 250, 244),
		accent = rgb(242, 212, 142),
	},
	easter = {
		panel = { rgb(110, 86, 148), rgb(42, 36, 58), rgb(16, 16, 22), rgb(38, 80, 70) },
		edge = { rgb(255, 212, 238), rgb(202, 182, 255), rgb(152, 232, 204) },
		line = rgb(255, 222, 242),
		gold = { rgb(255, 238, 248), rgb(248, 194, 230), rgb(192, 168, 250) },
		goldText = rgb(32, 18, 42),
		goldEdge = rgb(255, 242, 250),
		plain = rgb(24, 20, 32),
		plainGlow = rgb(242, 172, 222),
		plainText = rgb(255, 238, 250),
		accent = rgb(248, 188, 228),
	},
	stPatrick = {
		panel = { rgb(24, 116, 58), rgb(14, 42, 26), rgb(10, 14, 12), rgb(64, 54, 14) },
		edge = { rgb(255, 232, 152), rgb(92, 222, 124), rgb(20, 90, 46) },
		line = rgb(194, 255, 204),
		gold = { rgb(206, 255, 206), rgb(94, 222, 124), rgb(32, 152, 72) },
		goldText = rgb(6, 22, 10),
		goldEdge = rgb(214, 255, 214),
		plain = rgb(12, 24, 16),
		plainGlow = rgb(92, 222, 124),
		plainText = rgb(222, 255, 228),
		accent = rgb(124, 232, 144),
	},
} :: { [string]: Mood }

function Theme.mood(name: string?): Mood
	return Theme.moods[name or "house"] or Theme.moods.house
end

-- The holiday whose game is on, if it has its own colours ("house" otherwise).
function Theme.holidayMood(): string
	local id = Workspace:GetAttribute("HolidayGame")
	return if type(id) == "string" and Theme.moods[id] then id else "house"
end

-- Evenly spaced stops through `colours`.
function Theme.sequence(colours: { Color3 }): ColorSequence
	local n = #colours
	if n == 1 then
		return ColorSequence.new(colours[1])
	end
	local points = {}
	for i, c in colours do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (n - 1), c))
	end
	return ColorSequence.new(points)
end

Theme.colours = {
	glass = Color3.fromRGB(8, 9, 12),
	bone = C.bone,
	smoke = C.smoke,
	dim = C.dim,
	gold = C.gold,
	lightGold = C.lightGold,
	deepGold = C.deepGold,
	accent = C.gold,
	base = C.room,
}

type TextKind = "display" | "italic" | "body" | "light" | "bodyMedium" | "bodyBold" | "caps"

-- The house's type scale. Every piece of text on every panel is set at one of these sizes (a size
-- asked for in between is moved to the nearest), so headings, lines and captions read as one
-- family on every screen instead of a scatter of near-misses:
--   13 captions and small capitals · 14 secondary lines · 16 running text and keys ·
--   18 emphasis · 20 small headings · 24 panel titles · 28, 34, 40 display.
Theme.Scale = { 13, 14, 16, 18, 20, 24, 28, 34, 40 }

function Theme.snap(size: number): number
	local best = Theme.Scale[1]
	for _, step in Theme.Scale do
		if math.abs(step - size) <= math.abs(best - size) then
			best = step
		end
	end
	return if size > Theme.Scale[#Theme.Scale] then size else best
end

-- Line spacing by kind: running text opens up a little, display type sits tight (its heavy capitals
-- stand tall: a touch more room between their lines).
local LINE_HEIGHT: { [string]: number } = { display = 1.12, italic = 1.04, caps = 1.1 }
type Registered = { label: TextLabel | TextButton, size: number, kind: TextKind }

local registry: { Registered } = {}
local textScale = 1
local displayFont = Brand.Fonts.display

local clickSound: (() -> ())? = nil
function Theme.onClick(fn: () -> ())
	clickSound = fn
end

local hoverSound: (() -> ())? = nil
function Theme.onHover(fn: () -> ())
	hoverSound = fn
end

local function fontFor(kind: TextKind): Font
	if kind == "display" then
		return displayFont
	elseif kind == "italic" then
		return Brand.Fonts.displayItalic
	elseif kind == "light" then
		return Brand.Fonts.light
	elseif kind == "bodyMedium" or kind == "caps" then
		return Brand.Fonts.bodyMedium
	elseif kind == "bodyBold" then
		return Brand.Fonts.bodyBold
	end
	return Brand.Fonts.body
end

-- The smallest a kind of text is ever set (before the guest's text size setting), so no label
-- is too small to read at a glance: small capitals are a touch smaller than running text. When
-- the whole screen is scaled down (a phone, a small Studio window), small text is set larger so
-- it still comes out at least MIN_PX pixels tall, up to FLOOR_MAX.
local FLOOR: { [string]: number } = { caps = 13 }
local FLOOR_TEXT = 14
local MIN_PX: { [string]: number } = { caps = 13 }
local MIN_PX_TEXT = 14
local FLOOR_MAX = 19
local uiScale = Root.scale

local function applyText(r: Registered)
	local label = r.label :: any
	-- The display face is for headings: below heading size it runs too wide, so small "display"
	-- text (a line of dialogue, a caption) is set in the clean sans instead.
	label.FontFace = if r.kind == "display" and r.size < 22 then Brand.Fonts.bodyBold else fontFor(r.kind)
	local floor = math.max(FLOOR[r.kind] or FLOOR_TEXT, math.min(FLOOR_MAX, (MIN_PX[r.kind] or MIN_PX_TEXT) / uiScale))
	local size = math.floor(math.max(Theme.snap(r.size), floor) * textScale + 0.5)
	label.TextSize = size
	pcall(function()
		label.LineHeight = LINE_HEIGHT[r.kind] or 1.18
	end)
	-- Keys shrink their words to fit rather than spill over their edges.
	local fit = label:FindFirstChild("Fit")
	if fit and fit:IsA("UITextSizeConstraint") then
		fit.MaxTextSize = size
	end
end

function Theme.refresh()
	for i = #registry, 1, -1 do
		local r = registry[i]
		if r.label.Parent == nil then
			table.remove(registry, i)
		else
			applyText(r)
		end
	end
end

table.insert(Root.rescaled, function(scale: number)
	uiScale = scale
	Theme.refresh()
end)
State.watch("textSize", function(value)
	textScale = Settings.textScale(value)
	Theme.refresh()
end)
State.watch("lettering", function(value)
	displayFont = Brand.Lettering[value] or Brand.Fonts.display
	Theme.refresh()
end)
State.watch("houseStyle", function(value)
	local style = Brand.HouseStyles[value]
	if style then
		Theme.colours.accent = style.accent
		Theme.colours.base = style.base
	end
end)

-- The house fonts come from the Creator Store: fetch them as the guest arrives so the first
-- panel is already set in them.
function Theme.preloadFonts()
	local labels = {}
	for _, font in Brand.Fonts do
		local l = Instance.new("TextLabel")
		l.FontFace = font :: Font
		l.Text = "Maison Noir 0123456789"
		table.insert(labels, l)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(labels)
		end)
		for _, l in labels do
			l:Destroy()
		end
	end)
end

function Theme.text(parent: Instance, text: string, size: number, kind: TextKind?, props: { [string]: any }?): TextLabel
	local k: TextKind = kind or "body"
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = if k == "caps" then Caps(text) else text
	label.TextColor3 = if k == "display" then C.bone elseif k == "caps" then C.gold else C.bone
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.RichText = false
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	-- (Set on the house's type scale; never smaller than its captions.)
	local r = { label = label, size = size, kind = k }
	applyText(r)
	table.insert(registry, r)
	-- Headings: in capitals (whatever they're changed to later), and in the house's own colour, a
	-- sheen of light gold down through deep gold, like lettering cut in metal.
	if k == "display" and size >= 22 then
		label.Text = Caps(label.Text)
		label:GetPropertyChangedSignal("Text"):Connect(function()
			local up = Caps(label.Text)
			if up ~= label.Text then
				label.Text = up
			end
		end)
		if label.TextColor3 == C.bone then
			Theme.metal(label)
		end
	end
	label.Parent = parent
	return label
end

-- How wide (and tall) `text` is set at `size` in `font` (the house's Gotham faces by default),
-- in the HUD's own units, wrapped at `width` if given: measured by the engine (Gotham, the face
-- Gotham SSm is drawn from, a touch narrower: allowed for), or a fair guess if it can't. For boxes
-- that should be exactly as wide as their words.
local TextService = game:GetService("TextService")
local function enumFor(font: Font): Enum.Font
	local w = font.Weight.Value
	if w >= Enum.FontWeight.Heavy.Value then
		return Enum.Font.GothamBlack
	elseif w >= Enum.FontWeight.SemiBold.Value then
		return Enum.Font.GothamBold
	elseif w >= Enum.FontWeight.Medium.Value then
		return Enum.Font.GothamMedium
	end
	return Enum.Font.Gotham
end
function Theme.measure(text: string, size: number, font: Font?, width: number?): Vector2
	local f = font or Brand.Fonts.body
	local wide = 1.06
	if not string.find(f.Family, "Gotham", 1, true) then
		-- (Another face: wider for Michroma's capitals, about the same for the serifs.)
		wide = if string.find(f.Family, "Michroma", 1, true) then 1.45 else 1
	end
	local limit = width or 100000
	local ok, v = pcall(function()
		return TextService:GetTextSize(text, size, enumFor(f), Vector2.new(limit / wide, 100000))
	end)
	if ok and typeof(v) == "Vector2" and v.X > 0 then
		return Vector2.new(math.ceil(v.X * wide) + 2, math.ceil(v.Y))
	end
	-- (A fair guess: Gotham's letters run about 0.6 of their size wide, a little more when heavy.)
	local per = (if f.Weight.Value >= Enum.FontWeight.Heavy.Value then 0.7 elseif f.Weight.Value >= Enum.FontWeight.SemiBold.Value then 0.64 else 0.58) * wide
	local longest, lines = 0, 0
	for _, line in string.split(text, "\n") do
		local w = (utf8.len(line) or #line) * size * per
		local rows = math.max(1, math.ceil(w / limit))
		lines += rows
		longest = math.max(longest, math.min(w, limit))
	end
	return Vector2.new(math.ceil(longest) + 2, math.ceil(lines * size * 1.2))
end

-- How wide a label's own words are, as it's set now (its face, its size).
function Theme.wordsWidth(label: TextLabel | TextButton): number
	return Theme.measure(label.Text, label.TextSize, label.FontFace).X
end

-- A gold sheen on text or a fill: bright at the top through the house's gold to a deeper gold.
function Theme.metal(target: GuiObject, bright: boolean?): UIGradient
	local g = Instance.new("UIGradient")
	g.Name = "Metal"
	g.Rotation = 90
	-- (Build 65: a gentle warmth from ivory to light gold, not a chrome sheen.)
	-- (Build 68: a bright fill is real gold, light at the top through to a deep gold foot.)
	g.Color = if bright
		then Theme.sequence(Theme.moods.house.gold)
		else ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(246, 238, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(232, 214, 170)),
		})
	g.Parent = target
	return g
end

-- A gold edge that catches the light: bright at two corners, fading between, slowly turning (as
-- if the light moved round the glass; still for a guest whose Movement setting is Still). On a
-- UIStroke or any frame's outline.
function Theme.edge(stroke: UIStroke, strength: number?): UIGradient
	local k = strength or 1
	local g = Instance.new("UIGradient")
	g.Name = "Edge"
	g.Rotation = 35
	-- (Build 65: still, and quiet: a little lighter along the top, as if lit from above, and no
	-- light turning round it.)
	g.Rotation = 62
	g.Color = Theme.sequence(Theme.moods.house.edge)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, math.clamp(0.35 + 0.25 * k, 0, 0.9)),
	})
	g.Parent = stroke
	return g
end

-- A soft glow round a frame (two widening haloes of its colour behind everything else in it), for
-- what should catch the eye: a panel, a key on the dock, the result of a round. `target` is a
-- holder (its own fill drawn by its children): a child is always drawn over its parent's own
-- fill and words. Returns the haloes' holder.
function Theme.glow(target: GuiObject, colour: Color3?, radius: number?, strength: number?): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Glow"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 0
	-- (Build 65: a soft shadow beneath, a little lower, rather than a halo of colour: things sit on
	-- the screen, they don't shine. The colour asked for is no longer used.)
	local _ = colour
	local c = Color3.new(0, 0, 0)
	local base = radius or 14
	local k = strength or 1
	for i, spread in { 4, 10 } do
		local h = Instance.new("Frame")
		h.Name = "Halo" .. i
		h.BorderSizePixel = 0
		h.BackgroundColor3 = c
		h.BackgroundTransparency = 1 - (if i == 1 then 0.3 else 0.14) * math.max(0.6, k)
		h.AnchorPoint = Vector2.new(0.5, 0.5)
		h.Position = UDim2.new(0.5, 0, 0.5, 4)
		h.Size = UDim2.new(1, spread * 2, 1, spread * 2)
		h.ZIndex = holder.ZIndex
		local hc = Instance.new("UICorner")
		hc.CornerRadius = UDim.new(0, base + spread)
		hc.Parent = h
		h.Parent = holder
	end
	holder.Parent = target
	return holder
end

function Theme.hairline(parent: Instance, width: UDim?, order: number?): Frame
	local line = Instance.new("Frame")
	line.Name = "Hairline"
	line.BorderSizePixel = 0
	line.BackgroundColor3 = C.gold
	line.BackgroundTransparency = 0
	line.Size = UDim2.new(width or UDim.new(0.4, 0), UDim.new(0, 1))
	line.LayoutOrder = order or 0
	-- (A line of light, brightest in the middle, gone at its ends.)
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = line
	line.Parent = parent
	return line
end

-- A smoked-glass panel. Returns the panel (a plain Frame, so its text is drawn crisp; fade it
-- with Fade) and the content frame.
-- Paints a glass panel's fill, outline and line of light in `mood`.
local function paintGlass(fill: Frame, mood: Mood)
	local sheen = fill:FindFirstChild("Sheen")
	if sheen and sheen:IsA("UIGradient") then
		sheen.Color = Theme.sequence(mood.panel)
	end
	local stroke = fill:FindFirstChildOfClass("UIStroke")
	local edge = stroke and stroke:FindFirstChild("Edge")
	if edge and edge:IsA("UIGradient") then
		edge.Color = Theme.sequence(mood.edge)
	end
	local group = fill.Parent
	local highlight = group and group:FindFirstChild("Highlight")
	if highlight and highlight:IsA("Frame") then
		highlight.BackgroundColor3 = mood.line
	end
end

function Theme.glass(parent: Instance, name: string, size: UDim2, position: UDim2?, anchor: Vector2?, mood: string?): (Frame, Frame)
	local group = Instance.new("Frame")
	group.Name = name
	group.BackgroundTransparency = 1
	-- (What's on the glass is kept to it by its content frame; the glow is let out round it.)
	group.ClipsDescendants = false
	group.Size = size
	group.Position = position or UDim2.fromScale(0.5, 0.5)
	group.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	-- A centred panel sits below the keys at the top of the screen (Shop, Menu, Settings), never
	-- over them: it's centred in the space beneath, and no taller than that space.
	if position == nil and size.Y.Scale == 0 and size.Y.Offset > 0 then
		local top = 66
		local avail = math.max(160, Root.size().Y - top - 12)
		group.Size = UDim2.new(size.X, UDim.new(0, math.min(size.Y.Offset, avail)))
		group.Position = UDim2.new(0.5, 0, 0, top + avail / 2)
	end
	group.Parent = parent

	-- A soft shadow beneath the panel.
	Theme.glow(group, nil, 16, 0.8)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	-- Solid: name tags, prompts and the table's own words never show through a panel.
	fill.BackgroundTransparency = 0
	fill.BorderSizePixel = 0
	fill.Parent = group
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = fill
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.05
	stroke.Thickness = 1.25
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = fill
	Theme.edge(stroke)
	-- The glass in its mood's colours: a warm glow at its top corner, deepest in the middle, a
	-- touch of colour again at the foot. Solid all the way, so what's behind a panel never shows
	-- through its words.
	local sheen = Instance.new("UIGradient")
	sheen.Name = "Sheen"
	sheen.Rotation = 62
	sheen.Parent = fill
	fill:SetAttribute("Glass", true)
	-- A line of light along the top edge.
	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BorderSizePixel = 0
	highlight.BackgroundColor3 = C.lightGold
	highlight.BackgroundTransparency = 0.55
	highlight.Size = UDim2.new(0.7, 0, 0, 1)
	highlight.AnchorPoint = Vector2.new(0.5, 0)
	highlight.Position = UDim2.new(0.5, 0, 0, 1)
	highlight.Parent = group
	local hg = Instance.new("UIGradient")
	hg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	hg.Parent = highlight

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.ClipsDescendants = true -- (nothing spills past the glass)
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = group
	paintGlass(fill, Theme.mood(mood))
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 22)
	pad.PaddingBottom = UDim.new(0, 22)
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = content
	return group, content
end

-- How many screen pixels make one of a panel's own units just now (the screen's scale, and the
-- panel's own opening scale while it opens), read off the panel's width.
local function pxPerUnit(group: GuiObject): number
	local units = group.Size.X.Offset
	local limit = group:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		units = math.clamp(units, limit.MinSize.X, limit.MaxSize.X)
	end
	local ok, px = pcall(function()
		return group.AbsoluteSize.X
	end)
	if ok and group.Size.X.Scale == 0 and units > 0 and type(px) == "number" and px > 0 then
		return px / units
	end
	return math.max(0.05, Root.scale)
end

-- A glass panel exactly as tall as what's on it, grown or shrunk as that changes (so nothing is
-- ever cut off at the bottom, and there's never a stretch of empty glass under the words). The
-- panel's height is set from its content's: the engine's automatic sizing isn't asked to size
-- the glass itself, because the glass's fill and glow are sized to it and would hold it at the
-- tallest it had ever been. (Where the engine can't report sizes, it sizes the glass itself.)
function Theme.fitHeight(group: Frame, content: Frame)
	group.Size = UDim2.new(group.Size.X, UDim.new(0, 0))
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local readable = pcall(function()
		return content.AbsoluteSize
	end)
	if not readable then
		group.AutomaticSize = Enum.AutomaticSize.Y
		return
	end
	local function sync()
		if not group.Parent then
			return
		end
		local high = math.ceil(content.AbsoluteSize.Y / pxPerUnit(group) - 0.01)
		if high > 0 and group.Size.Y.Offset ~= high then
			group.Size = UDim2.new(group.Size.X, UDim.new(0, high))
		end
	end
	content:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
	group:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
	sync()
end

function Theme.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, padding or 10)
	list.Parent = parent
	return list
end

function Theme.haptic()
	if State.get("vibration") ~= "On" then
		return
	end
	pcall(function()
		local effect = Instance.new("HapticEffect")
		effect.Type = Enum.HapticEffectType.UIClick
		effect.Parent = workspace
		effect:Play()
		task.delay(0.3, function()
			effect:Destroy()
		end)
	end)
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.25)
		task.delay(0.05, function()
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
		end)
	end)
end

-- A layout-computed size or position (zero until Roblox has laid the frame out).
local function measured(inst: Instance, prop: string): Vector2
	local ok, v = pcall(function()
		return (inst :: any)[prop]
	end)
	return if ok and typeof(v) == "Vector2" then v else Vector2.zero
end

-- The gold outline a gamepad's selection draws around a key (instead of Roblox's default).
local function selectionRing(): Frame
	local ring = Instance.new("Frame")
	ring.Name = "Selection"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, 8, 1, 8)
	ring.Position = UDim2.fromOffset(-4, -4)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.lightGold
	stroke.Thickness = 2
	stroke.Parent = ring
	return ring
end

-- A brass key. Under the pointer (or a gamepad's selection) it lifts a touch and its edge
-- brightens; pressed, it sinks; let go, it springs back with a soft click and a brief glint to
-- say it was taken; a tiny vibration on phones.
-- How each key is lit (its colour at rest and under the pointer, and how solid), by key.
type KeyLook = { base: Color3, hover: Color3, fill: number }
local keyLooks: { [Instance]: KeyLook } = setmetatable({}, { __mode = "k" }) :: any

-- Paints a key in `mood`. Gold keys: a gradient of the mood's bright colour, top to foot, with dark
-- words (a gradient tints a key's words too, and dark stays dark). Plain keys: the mood's dark
-- colour with its glow at the top, fading down behind the words.
local function paintKey(button: TextButton, primary: boolean, mood: Mood)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	local look: KeyLook
	if primary then
		local g = button:FindFirstChild("Metal") :: UIGradient?
		if not g then
			local made = Instance.new("UIGradient")
			made.Name = "Metal"
			made.Rotation = 90
			made.Parent = button
			g = made
		end
		(g :: UIGradient).Color = Theme.sequence(mood.gold)
		button.TextColor3 = mood.goldText
		if stroke then
			stroke.Color = mood.goldEdge
		end
		look = { base = Color3.fromRGB(238, 238, 238), hover = Color3.new(1, 1, 1), fill = 0 }
	else
		local glow = button:FindFirstChild("KeyGlow") :: Frame?
		if not glow then
			local f = Instance.new("Frame")
			f.Name = "KeyGlow"
			f.BorderSizePixel = 0
			-- (Out past the key's own padding, whatever it's set to, so the glow is always the key's
			-- whole shape.)
			local function fit()
				local pad = button:FindFirstChildOfClass("UIPadding")
				local l = if pad then pad.PaddingLeft.Offset else 0
				local r = if pad then pad.PaddingRight.Offset else 0
				local t = if pad then pad.PaddingTop.Offset else 0
				local b = if pad then pad.PaddingBottom.Offset else 0
				f.Position = UDim2.fromOffset(-l, -t)
				f.Size = UDim2.new(1, l + r, 1, t + b)
			end
			fit()
			local pad = button:FindFirstChildOfClass("UIPadding")
			if pad then
				for _, prop in { "PaddingLeft", "PaddingRight", "PaddingTop", "PaddingBottom" } do
					pad:GetPropertyChangedSignal(prop):Connect(fit)
				end
			end
			f.ZIndex = button.ZIndex
			local fc = Instance.new("UICorner")
			fc.CornerRadius = UDim.new(0, 12)
			fc.Parent = f
			local fg = Instance.new("UIGradient")
			fg.Rotation = 90
			-- (The key's own shape, its glow fading out by two thirds of the way down: no edge.)
			fg.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.5),
				NumberSequenceKeypoint.new(0.68, 1),
				NumberSequenceKeypoint.new(1, 1),
			})
			fg.Parent = f
			f.Parent = button
			glow = f
		end
		(glow :: Frame).BackgroundColor3 = mood.plainGlow
		button.TextColor3 = mood.plainText
		local edge = stroke and stroke:FindFirstChild("Edge")
		if edge and edge:IsA("UIGradient") then
			edge.Color = Theme.sequence(mood.edge)
		end
		look = { base = mood.plain, hover = mood.plain:Lerp(mood.plainGlow, 0.24), fill = 0.03 }
	end
	keyLooks[button] = look
	button:SetAttribute("KeyKind", if primary then "gold" else "plain")
	button.BackgroundColor3 = look.base
	button.BackgroundTransparency = look.fill
end

-- Sets a key's inner margins (room for a swatch or an icon beside its words), keeping its glow the
-- key's whole shape.
function Theme.keyPadding(button: TextButton, left: number, right: number)
	local pad = button:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingLeft = UDim.new(0, left)
		pad.PaddingRight = UDim.new(0, right)
	end
	local glow = button:FindFirstChild("KeyGlow")
	if glow and glow:IsA("Frame") then
		local t = if pad then pad.PaddingTop.Offset else 0
		local b = if pad then pad.PaddingBottom.Offset else 0
		glow.Position = UDim2.fromOffset(-left, -t)
		glow.Size = UDim2.new(1, left + right, 1, t + b)
	end
end

-- Repaints a panel (or any holder) and every key and small heading on it in mood `name`.
function Theme.paint(root: Instance, name: string)
	local mood = Theme.mood(name)
	local house = Theme.moods.house
	local function one(d: Instance)
		if d:IsA("Frame") and d:GetAttribute("Glass") == true then
			paintGlass(d, mood)
		elseif d:IsA("TextButton") and d:GetAttribute("KeyKind") ~= nil then
			paintKey(d, d:GetAttribute("KeyKind") == "gold", mood)
		elseif d:IsA("TextLabel") and (d.TextColor3 == house.accent or d:GetAttribute("Accent") == true) then
			d:SetAttribute("Accent", true)
			d.TextColor3 = mood.accent
		end
	end
	one(root)
	for _, d in root:GetDescendants() do
		one(d)
	end
	root:SetAttribute("Mood", name)
end

function Theme.key(parent: Instance, text: string, primary: boolean?, onPress: () -> (), width: number?, mood: string?): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Key_" .. text
	button.AutoButtonColor = false
	-- Gold keys are gold leaf (a sheen from light to deep gold, brightening under the pointer); the
	-- others are black glass with a warm glow at the top and the gold edge that catches the light.
	button.BorderSizePixel = 0
	button.Size = UDim2.new(0, width or 200, 0, 44)
	button.Text = Caps(text)
	button.Selectable = true
	button.SelectionImageObject = selectionRing()
	-- Never TextScaled (it squeezes letters to odd sizes, a different size on every key): the
	-- words are set at the scale's 16, a step smaller (14, then 13) only when they'd not fit the
	-- key's width, and on two lines past that.
	button.TextScaled = false
	button.TextWrapped = true
	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = UDim.new(0, 10)
	inner.PaddingRight = UDim.new(0, 10)
	inner.PaddingTop = UDim.new(0, 6)
	inner.PaddingBottom = UDim.new(0, 6)
	inner.Parent = button
	local r = { label = button, size = 16, kind = "caps" :: TextKind }
	local function fitWords()
		-- The key's width: its offset, or (sized by scale) its laid-out width once known.
		local width = button.Size.X.Offset - 20
		if button.Size.X.Scale > 0 then
			local laid = measured(button, "AbsoluteSize").X / math.max(0.1, uiScale)
			width = if laid > 0 then laid - 20 else math.huge
		end
		local chars = utf8.len(button.Text) or #button.Text
		local size = 16
		-- Gotham SSm Bold capitals run about 0.74 of their size wide.
		while size > 13 and chars * size * 0.74 > width do
			size = if size == 16 then 14 else 13
		end
		r.size = size
		applyText(r)
	end
	fitWords()
	task.defer(function() -- (again once the caller has set the key's final size)
		if button.Parent then
			fitWords()
		end
	end)
	table.insert(registry, r)
	button:GetPropertyChangedSignal("Size"):Connect(fitWords)
	pcall(function()
		button:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitWords)
	end)
	button:GetPropertyChangedSignal("Text"):Connect(fitWords)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = if primary then C.brightGold else Color3.new(1, 1, 1)
	stroke.Thickness = if primary then 1 else 1.5
	stroke.Transparency = if primary then 0.2 else 0.35
	stroke.Parent = button
	if not primary then
		Theme.edge(stroke, 0.8)
	end
	paintKey(button, primary == true, Theme.mood(mood))
	local scale = Instance.new("UIScale")
	scale.Parent = button
	-- The glint: a band of light across the key when it is taken.
	local glint = Instance.new("Frame")
	glint.Name = "Glint"
	glint.BackgroundColor3 = C.lightGold
	glint.BackgroundTransparency = 1
	glint.BorderSizePixel = 0
	glint.Size = UDim2.fromScale(1, 1)
	glint.ZIndex = button.ZIndex + 1
	glint.Parent = button
	local glintCorner = Instance.new("UICorner")
	glintCorner.CornerRadius = UDim.new(0, 12)
	glintCorner.Parent = glint

	local over = false
	local function lit(on: boolean)
		over = on
		Ease.play(stroke, Ease.quick, { Transparency = if on then 0 else (if primary then 0.2 else 0.35) })
		Ease.play(scale, Ease.info(0.16, Enum.EasingStyle.Quad), { Scale = if on then 1.025 else 1 })
		local look = keyLooks[button]
		if look then
			Ease.play(button, Ease.quick, {
				BackgroundColor3 = if on then look.hover else look.base,
				BackgroundTransparency = if on then math.max(0, look.fill - 0.1) else look.fill,
			})
		end
	end
	button.MouseEnter:Connect(function()
		if not over and hoverSound then
			hoverSound()
		end
		lit(true)
	end)
	button.MouseLeave:Connect(function()
		lit(false)
	end)
	button.SelectionGained:Connect(function()
		if hoverSound then
			hoverSound()
		end
		lit(true)
	end)
	button.SelectionLost:Connect(function()
		lit(false)
	end)
	button.MouseButton1Down:Connect(function()
		Ease.play(scale, Ease.info(0.08, Enum.EasingStyle.Quad), { Scale = 0.965 })
	end)
	button.MouseButton1Up:Connect(function()
		Ease.play(scale, Ease.info(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if over then 1.025 else 1 })
	end)
	button.Activated:Connect(function()
		if clickSound then
			clickSound()
		end
		Theme.haptic()
		glint.BackgroundTransparency = 0.55
		Ease.play(glint, Ease.info(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		onPress()
	end)
	button.Parent = parent
	return button
end

-- A row of section tabs that never cuts a heading short: each tab is as wide as its words (the
-- words are never shrunk), the row scrolls sideways when there are more than fit (drag it, use the
-- wheel, or the arrows that appear at whichever end has more), and the chosen tab glides to the
-- middle. `specs` is { { id, label } } in order.
export type Tabs = {
	frame: Frame,
	keys: { [string]: TextButton },
	select: (id: string) -> (),
	show: (id: string, on: boolean) -> (),
}


function Theme.tabs(parent: Instance, specs: { { string } }, current: string, onSelect: (id: string) -> (), order: number?): Tabs
	local holder = Instance.new("Frame")
	holder.Name = "Tabs"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 46)
	holder.LayoutOrder = order or 0
	holder.ClipsDescendants = true
	holder.Parent = parent

	local strip = Instance.new("ScrollingFrame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.Size = UDim2.fromScale(1, 1)
	strip.CanvasSize = UDim2.new()
	strip.AutomaticCanvasSize = Enum.AutomaticSize.X
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.ScrollBarThickness = 0
	strip.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
	strip.Parent = holder
	local row = Theme.list(strip, 8, true)
	row.HorizontalAlignment = Enum.HorizontalAlignment.Left
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 4)
	inset.PaddingRight = UDim.new(0, 4)
	inset.Parent = strip

	local keys: { [string]: TextButton } = {}
	local chosen = current

	local function paint()
		for id, k in keys do
			local on = id == chosen
			-- The chosen tab is gold leaf; the rest black glass, their words in pale gold.
			k.BackgroundColor3 = if on then Color3.new(1, 1, 1) else Color3.fromRGB(18, 19, 24)
			k.BackgroundTransparency = if on then 0 else 0.1
			k.TextColor3 = if on then Color3.fromRGB(28, 20, 6) else C.lightGold
			local sheen = k:FindFirstChild("Metal")
			if on and not sheen then
				Theme.metal(k, true)
			elseif not on and sheen then
				sheen:Destroy()
			end
			local stroke = k:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = if on then 0.1 else 0.6
			end
		end
	end

	-- Glides the row so tab `id` sits in the middle (as near as the ends allow).
	local function centre(id: string, instant: boolean?)
		local k = keys[id]
		local view = measured(strip, "AbsoluteWindowSize").X
		local canvas = measured(strip, "AbsoluteCanvasSize").X
		if not k or view <= 0 or canvas <= view + 1 then
			return
		end
		local x = measured(k, "AbsolutePosition").X - measured(strip, "AbsolutePosition").X + strip.CanvasPosition.X + measured(k, "AbsoluteSize").X / 2
		local goal = Vector2.new(math.clamp(x - view / 2, 0, canvas - view), 0)
		if instant then
			strip.CanvasPosition = goal
		else
			Ease.play(strip, Ease.info(0.35, Enum.EasingStyle.Quint), { CanvasPosition = goal })
		end
	end

	for i, spec in specs do
		local id, label = spec[1], spec[2]
		local k = Instance.new("TextButton")
		k.Name = "Tab_" .. id
		k.AutoButtonColor = false
		k.Text = Caps(label)
		k.TextWrapped = false
		k.TextScaled = false
		k.AutomaticSize = Enum.AutomaticSize.X
		k.Size = UDim2.new(0, 0, 0, 38)
		k.BorderSizePixel = 0
		k.LayoutOrder = i
		k.Selectable = true
		k.SelectionImageObject = selectionRing()
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 16)
		padding.PaddingRight = UDim.new(0, 16)
		padding.Parent = k
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 19)
		corner.Parent = k
		local stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = C.gold
		stroke.Parent = k
		local r = { label = k, size = 14, kind = "caps" :: TextKind }
		applyText(r)
		table.insert(registry, r)
		k.MouseEnter:Connect(function()
			if hoverSound then
				hoverSound()
			end
			if id ~= chosen then
				Ease.play(stroke, Ease.quick, { Transparency = 0.1 })
			end
		end)
		k.MouseLeave:Connect(function()
			Ease.play(stroke, Ease.quick, { Transparency = if id == chosen then 0.15 else 0.55 })
		end)
		k.SelectionGained:Connect(function()
			centre(id)
		end)
		k.Activated:Connect(function()
			if clickSound then
				clickSound()
			end
			Theme.haptic()
			chosen = id
			paint()
			centre(id)
			onSelect(id)
		end)
		k.Parent = strip
		keys[id] = k
	end
	paint()

	-- The arrows at either end: shown only where there's more to see, over a fade into the glass.
	local function arrow(side: number): Frame
		local fade = Instance.new("Frame")
		fade.Name = if side < 0 then "FadeLeft" else "FadeRight"
		fade.BackgroundColor3 = Theme.colours.glass
		fade.BorderSizePixel = 0
		fade.AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0)
		fade.Position = UDim2.fromScale(if side < 0 then 0 else 1, 0)
		fade.Size = UDim2.new(0, 56, 1, 0)
		fade.ZIndex = 5
		fade.Visible = false
		fade.Parent = holder
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, if side < 0 then 0 else 1),
			NumberSequenceKeypoint.new(0.55, if side < 0 then 0.05 else 0.95),
			NumberSequenceKeypoint.new(1, if side < 0 then 1 else 0),
		})
		g.Parent = fade
		local b = Instance.new("TextButton")
		b.Name = if side < 0 then "Left" else "Right"
		b.AutoButtonColor = false
		b.AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5)
		b.Position = UDim2.fromScale(if side < 0 then 0 else 1, 0.5)
		b.Size = UDim2.fromOffset(30, 30)
		b.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
		b.BackgroundTransparency = 0.1
		b.Text = if side < 0 then "‹" else "›"
		b.FontFace = Brand.Fonts.bodyBold
		b.TextSize = 22
		b.TextColor3 = C.lightGold
		b.ZIndex = 6
		b.Parent = fade
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(1, 0)
		bc.Parent = b
		local bs = Instance.new("UIStroke")
		bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		bs.Color = C.gold
		bs.Transparency = 0.35
		bs.Parent = b
		b.Activated:Connect(function()
			if clickSound then
				clickSound()
			end
			local view = measured(strip, "AbsoluteWindowSize").X
			local canvas = measured(strip, "AbsoluteCanvasSize").X
			local goal = math.clamp(strip.CanvasPosition.X + side * view * 0.7, 0, math.max(0, canvas - view))
			Ease.play(strip, Ease.info(0.35, Enum.EasingStyle.Quint), { CanvasPosition = Vector2.new(goal, 0) })
		end)
		return fade
	end
	local fl, fr = arrow(-1), arrow(1)
	local function arrows()
		-- (A signal can still arrive just after the panel closed: nothing left to show then.)
		if holder.Parent == nil then
			return
		end
		local view = measured(strip, "AbsoluteWindowSize").X
		local canvas = measured(strip, "AbsoluteCanvasSize").X
		local at = strip.CanvasPosition.X
		local more = canvas > view + 1 and view > 0
		fl.Visible = more and at > 2
		fr.Visible = more and at < canvas - view - 2
	end
	strip:GetPropertyChangedSignal("CanvasPosition"):Connect(arrows)
	strip:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
		arrows()
		centre(chosen, true)
	end)
	strip:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(arrows)
	task.defer(function()
		arrows()
		centre(chosen, true)
	end)

	local tabs: Tabs = {
		frame = holder,
		keys = keys,
		select = function(id: string)
			chosen = id
			paint()
			centre(id)
		end,
		show = function(id: string, on: boolean)
			local k = keys[id]
			if k then
				k.Visible = on
			end
			task.defer(arrows)
		end,
	}
	return tabs
end

return Theme

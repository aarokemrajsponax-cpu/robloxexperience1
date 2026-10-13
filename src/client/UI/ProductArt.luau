--!strict
-- A picture of each piece the house sells, drawn from what it is (its kind and its style), for the
-- Boutique's shelves, the Wardrobe and gifts: a little felt table in its felt and rims, a lamp
-- glowing in its colour, a trail of sparks in its colour, a nameplate in its frame and fill, the
-- back of a card in its pattern, a flourish's drift, a gesture and an outfit on a hanger, each on
-- a softly lit backdrop with the piece's own colour behind it. All drawn with the interface's own
-- shapes: nothing to upload, nothing to load.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)

local ProductArt = {}

local rgb = Color3.fromRGB
local C = Brand.Colours

local function corner(f: GuiObject, r: number | UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = if typeof(r) == "UDim" then r else UDim.new(0, r :: number)
	c.Parent = f
end

local function box(parent: Instance, name: string, colour: Color3, x: number, y: number, w: number, h: number, round: number?, z: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(x, y)
	f.Size = UDim2.fromScale(w, h)
	f.ZIndex = z or 3
	if round then
		corner(f, UDim.new(round, 0))
	end
	f.Parent = parent
	return f
end

local function shade(target: GuiObject, top: Color3, bottom: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation or 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = target
end

local function glyph(parent: Instance, text: string, x: number, y: number, size: number, z: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = "Glyph"
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(x, y)
	l.Size = UDim2.fromScale(size, size)
	l.TextScaled = true
	l.Text = text
	l.ZIndex = z or 4
	l.Parent = parent
	return l
end

local function colourOf(style: { [string]: any }?, fallback: Color3): Color3
	if style then
		for _, k in { "colour", "felt", "back", "frame" } do
			local c = style[k]
			if typeof(c) == "Color3" then
				return c
			end
		end
	end
	return fallback
end

local OUTFITS: { [string]: string } = { velvet = "🧥", gown = "👗", tux = "🤵", cape = "🦸" }
local GESTURES: { [string]: string } = { tipHat = "🎩", applause = "👏", bow = "🙇" }
local FLOURISH: { [string]: string } = { leaf = "✨", snuff = "🕯️", spray = "🍾" }

-- The backdrop: a rounded tile lit from above, the piece's colour glowing in its middle.
local function backdrop(parent: Instance, accent: Color3, size: number): Frame
	local tile = Instance.new("Frame")
	tile.Name = "ProductArt"
	tile.BorderSizePixel = 0
	tile.Size = UDim2.fromOffset(size, size)
	tile.BackgroundColor3 = Color3.new(1, 1, 1)
	tile.ClipsDescendants = true
	tile.ZIndex = 2
	corner(tile, math.floor(size * 0.18))
	shade(tile, rgb(44, 42, 50), rgb(12, 12, 16))
	local glow = box(tile, "Glow", accent, 0.5, 0.55, 0.95, 0.95, 1, 2)
	glow.BackgroundTransparency = 0.55
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.85),
		NumberSequenceKeypoint.new(1, 1),
	})
	gg.Parent = glow
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = C.gold
	edge.Transparency = 0.25
	edge.Thickness = 1.5
	edge.Parent = tile
	tile.Parent = parent
	return tile
end

-- Draws the picture for a piece (`kind`, `style`) at `size` pixels square into `parent`.
function ProductArt.draw(parent: Instance, kind: string?, style: { [string]: any }?, size: number?): Frame
	local s: { [string]: any } = style or {}
	local px = size or 64
	local accent = colourOf(s, C.gold)
	local tile = backdrop(parent, accent, px)
	if kind == "table" then
		-- A felt card table seen from a little above: its shadow, two legs, the rim in its wood, the
		-- felt inside with a fine gold line, and a hand of cards fanned on it.
		local rim = if typeof(s.rim) == "Color3" then s.rim else rgb(92, 58, 34)
		local dark = rim:Lerp(Color3.new(0, 0, 0), 0.45)
		local shadow = box(tile, "Shadow", Color3.new(0, 0, 0), 0.5, 0.86, 0.78, 0.12, 1, 2)
		shadow.BackgroundTransparency = 0.55
		for i, x in { 0.27, 0.73 } do
			local leg = box(tile, "Leg" .. i, Color3.new(1, 1, 1), x, 0.72, 0.07, 0.28, 0.3, 3)
			shade(leg, rim, dark, 0)
		end
		local apron = box(tile, "Apron", dark, 0.5, 0.6, 0.86, 0.2, 0.5, 4)
		apron.BackgroundTransparency = 0
		local top = box(tile, "Rim", Color3.new(1, 1, 1), 0.5, 0.5, 0.88, 0.46, 0.5, 5)
		shade(top, rim:Lerp(Color3.new(1, 1, 1), 0.35), rim:Lerp(Color3.new(0, 0, 0), 0.2))
		local felt = box(tile, "Felt", Color3.new(1, 1, 1), 0.5, 0.5, 0.72, 0.32, 0.5, 6)
		shade(felt, accent:Lerp(Color3.new(1, 1, 1), 0.22), accent:Lerp(Color3.new(0, 0, 0), 0.3))
		local line = Instance.new("UIStroke")
		line.Color = C.lightGold
		line.Thickness = 1
		line.Transparency = 0.35
		line.Parent = felt
		for i, turn in { -16, 0, 16 } do
			local card = box(tile, "Card" .. i, rgb(250, 246, 236), 0.44 + i * 0.04, 0.49, 0.1, 0.15, 0.15, 7 + i)
			card.Rotation = turn
			local ce = Instance.new("UIStroke")
			ce.Color = C.gold
			ce.Thickness = 1
			ce.Parent = card
		end
	elseif kind == "lamp" then
		-- A hanging lamp: the cord, a shade in the lamp's colour, the bulb, and its light widening
		-- down to a warm pool on the floor.
		for i = 1, 6 do
			local t = i / 6
			local beam = box(tile, "Beam" .. i, accent:Lerp(Color3.new(1, 1, 1), 0.35), 0.5, 0.5 + t * 0.34, 0.26 + t * 0.5, 0.08, 0.5, 2)
			beam.BackgroundTransparency = 0.55 + t * 0.35
		end
		local pool = box(tile, "Pool", accent:Lerp(Color3.new(1, 1, 1), 0.4), 0.5, 0.88, 0.78, 0.12, 1, 3)
		pool.BackgroundTransparency = 0.45
		local cord = box(tile, "Cord", rgb(200, 170, 110), 0.5, 0.13, 0.025, 0.26, nil, 4)
		cord.BackgroundTransparency = 0.1
		local cap = box(tile, "Cap", C.gold, 0.5, 0.27, 0.12, 0.05, 1, 5)
		cap.BackgroundTransparency = 0
		local crown = box(tile, "Crown", Color3.new(1, 1, 1), 0.5, 0.33, 0.3, 0.1, 0.4, 5)
		shade(crown, accent:Lerp(Color3.new(1, 1, 1), 0.55), accent:Lerp(Color3.new(1, 1, 1), 0.2))
		local shade_ = box(tile, "Shade", Color3.new(1, 1, 1), 0.5, 0.42, 0.56, 0.16, 0.45, 5)
		shade(shade_, accent:Lerp(Color3.new(1, 1, 1), 0.3), accent:Lerp(Color3.new(0, 0, 0), 0.25))
		local trim = box(tile, "Trim", C.lightGold, 0.5, 0.5, 0.56, 0.025, 1, 6)
		trim.BackgroundTransparency = 0.15
		local bulb = box(tile, "Bulb", rgb(255, 250, 230), 0.5, 0.53, 0.12, 0.08, 1, 6)
		bulb.BackgroundTransparency = 0
	elseif kind == "trail" then
		-- A streak of sparks curving across, brightest at its head.
		for i = 1, 7 do
			local t = i / 7
			local x = 0.18 + t * 0.62
			local y = 0.72 - math.sin(t * math.pi * 0.85) * 0.42
			local r = 0.06 + t * 0.1
			local dot = box(tile, "Spark" .. i, accent:Lerp(Color3.new(1, 1, 1), t * 0.4), x, y, r, r, 1, 3 + i)
			dot.BackgroundTransparency = 0.6 - t * 0.6
		end
		glyph(tile, "✨", 0.8, 0.26, 0.3, 12)
	elseif kind == "nameplate" then
		-- A small plate in its frame and fill, a name in its line colour.
		local frameC = if typeof(s.frame) == "Color3" then s.frame else C.gold
		local fillC = if typeof(s.fill) == "Color3" then s.fill else rgb(20, 18, 14)
		local lineC = if typeof(s.line) == "Color3" then s.line else C.lightGold
		local plate = box(tile, "Plate", fillC, 0.5, 0.5, 0.82, 0.38, 0.4)
		local pe = Instance.new("UIStroke")
		pe.Color = frameC
		pe.Thickness = 2
		pe.Parent = plate
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.fromScale(1, 1)
		name.Text = "YOU"
		name.TextScaled = true
		name.FontFace = Brand.Fonts.heavy
		name.TextColor3 = lineC
		name.ZIndex = 5
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.2, 0)
		pad.PaddingBottom = UDim.new(0.2, 0)
		pad.Parent = name
		name.Parent = plate
	elseif kind == "card" then
		-- The back of a card in its colour and pattern, tilted, another behind it.
		local back = accent
		local behind = box(tile, "Behind", back:Lerp(Color3.new(0, 0, 0), 0.4), 0.42, 0.5, 0.44, 0.64, 0.12)
		behind.Rotation = -12
		local card = box(tile, "Card", back, 0.56, 0.5, 0.44, 0.64, 0.12, 4)
		card.Rotation = 8
		local ce = Instance.new("UIStroke")
		ce.Color = C.lightGold
		ce.Thickness = 1.5
		ce.Parent = card
		local pattern = tostring(s.pattern or "")
		local mark = if pattern == "monogram" then "MN" elseif pattern == "pinstripe" then "║" else "❖"
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Text = mark
		l.TextScaled = true
		l.FontFace = Brand.Fonts.heavy
		l.TextColor3 = C.lightGold
		l.TextTransparency = 0.15
		l.ZIndex = 5
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0.25, 0)
		pad.PaddingBottom = UDim.new(0.25, 0)
		pad.PaddingLeft = UDim.new(0.15, 0)
		pad.PaddingRight = UDim.new(0.15, 0)
		pad.Parent = l
		l.Parent = card
	elseif kind == "chime" then
		glyph(tile, "🔔", 0.46, 0.54, 0.56)
		for i = 1, 2 do
			local ring = box(tile, "Wave" .. i, Color3.new(1, 1, 1), 0.7 + i * 0.06, 0.4, 0.12 + i * 0.12, 0.24 + i * 0.16, 1, 3)
			ring.BackgroundTransparency = 1
			local st = Instance.new("UIStroke")
			st.Color = C.lightGold
			st.Thickness = 1.5
			st.Transparency = 0.2 + i * 0.25
			st.Parent = ring
		end
	elseif kind == "flourish" then
		glyph(tile, FLOURISH[tostring(s.kind)] or "✨", 0.5, 0.52, 0.62)
	elseif kind == "gesture" then
		glyph(tile, GESTURES[tostring(s.animation)] or "👋", 0.5, 0.52, 0.62)
	elseif kind == "look" then
		-- On a hanger.
		local hook = box(tile, "Hook", C.lightGold, 0.5, 0.14, 0.04, 0.12, 1, 4)
		hook.BackgroundTransparency = 0.1
		local bar = box(tile, "Hanger", C.lightGold, 0.5, 0.22, 0.56, 0.04, 1, 4)
		bar.BackgroundTransparency = 0.1
		glyph(tile, OUTFITS[tostring(s.outfit)] or "👔", 0.5, 0.6, 0.6, 5)
	else
		glyph(tile, "🎁", 0.5, 0.52, 0.58)
	end
	return tile
end

return ProductArt

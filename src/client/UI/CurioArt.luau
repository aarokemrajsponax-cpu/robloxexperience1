--!strict
-- How a curio looks on screen: a round medallion in its own colour, rimmed in its rarity's colour,
-- with its big glyph in the middle and a small accent at the shoulder; and the rarity's ribbon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)

local CurioArt = {}

-- A medallion `px` across for curio `id`. `locked` draws it as a dark silhouette (not yet held).
function CurioArt.medallion(parent: Instance, id: string, px: number, locked: boolean?): Frame
	local c = Curios.byId[id]
	local f = Instance.new("Frame")
	f.Name = "Medallion"
	f.Size = UDim2.fromOffset(px, px)
	f.BackgroundColor3 = if c then c.colour else Color3.fromRGB(40, 40, 40)
	f.BorderSizePixel = 0
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = f
	local rim = Instance.new("UIStroke")
	rim.Color = if c then Curios.RarityColour[c.rarity] else Brand.Colours.dim
	rim.Thickness = math.max(2, math.floor(px / 22))
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = f
	local shine = Instance.new("UIGradient")
	shine.Rotation = 120
	shine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 110))
	shine.Parent = f
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.52)
	glyph.Size = UDim2.fromScale(0.78, 0.78)
	glyph.Text = if locked or not c then "?" else c.glyph
	glyph.TextScaled = true
	glyph.Font = Enum.Font.GothamBold
	glyph.TextColor3 = if locked then Color3.fromRGB(120, 116, 110) else Color3.new(1, 1, 1)
	glyph.Parent = f
	if c and c.accent ~= "" and not locked then
		local accent = Instance.new("TextLabel")
		accent.Name = "Accent"
		accent.BackgroundTransparency = 1
		accent.AnchorPoint = Vector2.new(0.5, 0.5)
		accent.Position = UDim2.fromScale(0.84, 0.2)
		accent.Size = UDim2.fromScale(0.38, 0.38)
		accent.Text = c.accent
		accent.TextScaled = true
		accent.Parent = f
	end
	if locked then
		f.BackgroundColor3 = Color3.fromRGB(26, 24, 24)
		rim.Transparency = 0.5
	end
	return f
end

-- The rarity's small ribbon (text in the rarity's colour).
function CurioArt.rarity(parent: Instance, rarity: string, size: number): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = "Rarity"
	t.BackgroundTransparency = 1
	t.AutomaticSize = Enum.AutomaticSize.XY
	t.Size = UDim2.new()
	t.Text = string.upper(rarity)
	t.FontFace = Brand.Fonts.bodyBold
	t.TextSize = size
	t.TextColor3 = if rarity == "Secret" then Color3.fromRGB(200, 196, 220) else Curios.RarityColour[rarity] or Brand.Colours.gold
	t.Parent = parent
	return t
end

return CurioArt

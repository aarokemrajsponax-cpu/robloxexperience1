--!strict
-- How a curio looks on screen: a round medallion in its own colour, rimmed in its rarity's colour,
-- with its big glyph in the middle and a small accent at the shoulder; and the rarity's ribbon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brainrots = require(ReplicatedStorage.Shared.Brainrots)
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

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 210, 70)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 240, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 100, 255)),
})
CurioArt.RAINBOW = RAINBOW

-- A brainrot's mutation on its medallion: a thicker rim in Gold or Diamond (every colour for
-- Rainbow), the medallion washed in it, and a sparkle at its foot.
function CurioArt.mutate(medal: Frame, mut: string?)
	local info = if mut then Brainrots.Mutations[mut] else nil
	if not info then
		return
	end
	local rim = medal:FindFirstChildOfClass("UIStroke")
	if rim then
		rim.Thickness += 2
		rim.Color = if mut == "rainbow" then Color3.new(1, 1, 1) else info.colour
		if mut == "rainbow" then
			local g = Instance.new("UIGradient")
			g.Color = RAINBOW
			g.Parent = rim
		end
	end
	medal.BackgroundColor3 = medal.BackgroundColor3:Lerp(info.colour, 0.5)
	local spark = Instance.new("TextLabel")
	spark.Name = "Mutation"
	spark.BackgroundTransparency = 1
	spark.AnchorPoint = Vector2.new(0.5, 0.5)
	spark.Position = UDim2.fromScale(0.16, 0.82)
	spark.Size = UDim2.fromScale(0.34, 0.34)
	spark.Text = if mut == "diamond" then "💎" elseif mut == "rainbow" then "🌈" else "✨"
	spark.TextScaled = true
	spark.ZIndex = medal.ZIndex + 1
	spark.Parent = medal
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

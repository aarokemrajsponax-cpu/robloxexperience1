--!strict
-- Hallmarks: grades drawn as tiny stamped marks, like the marks on real silver. Drawn from
-- frames and strokes, never font symbols.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Theme = require(script.Parent.Theme)

local Hallmark = {}

local function cartouche(parent: Instance, size: Vector2, order: number, empty: boolean?): (Frame, Frame)
	local mark = Instance.new("Frame")
	mark.Name = "Hallmark"
	mark.BackgroundColor3 = Color3.fromRGB(20, 18, 14)
	mark.BackgroundTransparency = if empty then 0.7 else 0.2
	mark.Size = UDim2.fromOffset(size.X, size.Y)
	mark.LayoutOrder = order
	mark.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = mark
	local outer = Instance.new("UIStroke")
	outer.Color = if empty then Brand.Colours.deepGold else Brand.Colours.gold
	outer.Thickness = 1.5
	outer.Transparency = if empty then 0.4 else 0
	outer.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	outer.Parent = mark
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.Parent = mark
	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0.5, 0)
	innerCorner.Parent = inner
	if not empty then
		local innerStroke = Instance.new("UIStroke")
		innerStroke.Color = Brand.Colours.deepGold
		innerStroke.Thickness = 1
		innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		innerStroke.Parent = inner
	end
	return mark, inner
end

-- The grade of a round or run.
function Hallmark.big(parent: Instance, grade: string, order: number): Frame
	local mark, inner = cartouche(parent, Vector2.new(190, 46), order)
	Theme.text(inner, string.upper(grade), 15, "caps", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.fromScale(1, 1),
		TextColor3 = Brand.Colours.lightGold,
	})
	return mark
end

-- One round of five on the Nightly card: the round's numeral over its grade, the grade's whole
-- name (shrunk a touch to fit the stamp rather than cut short). An empty grade draws an empty
-- mark (a round the clock ended).
function Hallmark.small(parent: Instance, numeral: string, grade: string, order: number): Frame
	local empty = grade == ""
	local mark, inner = cartouche(parent, Vector2.new(78, 50), order, empty)
	local list = Theme.list(inner, 0)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	Theme.text(inner, numeral, 14, "display", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0.48, 0),
		LayoutOrder = 1,
		TextColor3 = if empty then Brand.Colours.dim else Brand.Colours.lightGold,
	})
	local word = Theme.text(inner, if empty then "—" else grade, 13, "bodyMedium", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, -4, 0.4, 0),
		LayoutOrder = 2,
		TextScaled = true,
		TextColor3 = if empty then Brand.Colours.dim else Brand.Colours.gold,
	})
	local fit = Instance.new("UITextSizeConstraint")
	fit.Name = "Fit"
	fit.MinTextSize = 9
	fit.MaxTextSize = word.TextSize
	fit.Parent = word
	return mark
end

return Hallmark

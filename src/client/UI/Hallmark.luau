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

-- One round of five on the Nightly card: the round's numeral over its grade. An empty grade
-- draws an empty mark (a round the clock ended).
function Hallmark.small(parent: Instance, numeral: string, grade: string, order: number): Frame
	local empty = grade == ""
	local mark, inner = cartouche(parent, Vector2.new(62, 40), order, empty)
	local list = Theme.list(inner, 0)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	Theme.text(inner, numeral, 13, "display", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0.5, 0),
		LayoutOrder = 1,
		TextColor3 = if empty then Brand.Colours.dim else Brand.Colours.lightGold,
	})
	Theme.text(inner, if empty then "—" else string.upper(string.sub(grade, 1, 4)), 9, "bodyMedium", {
		AutomaticSize = Enum.AutomaticSize.None,
		Size = UDim2.new(1, 0, 0.4, 0),
		LayoutOrder = 2,
		TextColor3 = if empty then Brand.Colours.dim else Brand.Colours.gold,
	})
	return mark
end

return Hallmark

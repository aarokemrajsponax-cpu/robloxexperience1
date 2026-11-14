--!strict
-- The attractions' status cards (Steal a Luxe, the Grand Ballroom, the Executive Suite, the
-- Basement's stage): one look and one place for all of them.
--
-- The look: deep smoked glass, a hairline edge, a faint light along the top, and a short bar of
-- the attraction's own colour down the left. No thick frames, no glow.
--
-- The place: the bottom-left corner, out of the way of the guest's own figure in the middle of the
-- screen. Under the keys down the left when there's room for it there, beside them otherwise;
-- lifted above the keys along the foot of the screen when it would reach across to them; and on
-- a phone or tablet lifted clear of the thumbstick, which lives in that corner.

local UserInputService = game:GetService("UserInputService")

local Root = require(script.Parent.Root)

local HudCard = {}

HudCard.BACKGROUND = Color3.fromRGB(12, 12, 15)
HudCard.EDGE = Color3.fromRGB(255, 255, 255)
HudCard.EDGE_SEEN = 0.86 -- the hairline's transparency
HudCard.MARGIN = 16

-- Dresses `f` as a status card in `accent`. Returns its edge (a card may tint it for an alarm).
function HudCard.style(f: Frame, accent: Color3): UIStroke
	f.BackgroundColor3 = HudCard.BACKGROUND
	f.BackgroundTransparency = 0.06
	f.BorderSizePixel = 0
	local corner = f:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	-- A faint light along the top, the glass darkening to the foot.
	local found = f:FindFirstChild("Depth")
	local depth: UIGradient = if found and found:IsA("UIGradient") then found else Instance.new("UIGradient")
	depth.Name = "Depth"
	depth.Rotation = 90
	depth.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(176, 176, 184))
	depth.Parent = f
	local edge = f:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = HudCard.EDGE
	edge.Thickness = 1
	edge.Transparency = HudCard.EDGE_SEEN
	edge.Parent = f
	-- The attraction's colour: a short bar down the left, inside the padding's margin.
	local pad = f:FindFirstChildOfClass("UIPadding")
	local inset = if pad then pad.PaddingLeft.Offset else 0
	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = accent
	bar.AnchorPoint = Vector2.new(0, 0)
	bar.Position = UDim2.new(0, 6 - inset, 0, 4)
	bar.Size = UDim2.new(0, 3, 0, 22)
	bar.ZIndex = f.ZIndex + 1
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(1, 0)
	bc.Parent = bar
	bar.Parent = f
	return edge
end

-- Puts `f` in the bottom-left corner (see above). `keysHalf`: half the width of the keys centred
-- along the foot of the screen while the card is up (the attraction's Leave key and its friends).
-- `above`: the height of anything that stands on top of the card (the Suite's code), kept clear
-- of the keys down the left with it.
function HudCard.place(f: Frame, keysHalf: number?, above: number?)
	local size = Root.size()
	local w = f.Size.X.Offset
	local h = f.Size.Y.Offset + (above or 0)
	local touch = UserInputService.TouchEnabled
	local x = HudCard.MARGIN
	local bottom = Root.bottomClear() + HudCard.MARGIN
	if touch then
		bottom = Root.bottomClear() + math.clamp(size.Y * 0.34, 120, 210)
	elseif x + w > size.X / 2 - (keysHalf or 150) - 8 then
		-- (It would reach across to the keys along the foot: above them.)
		bottom = Root.bottomClear() + 14 + 44 + 12
	end
	-- Under the keys down the left only when it fits below them; beside them otherwise.
	local dockFoot = if Root.leftBottom > 0 then Root.leftBottom else size.Y
	if size.Y - bottom - h < dockFoot + 10 then
		x = Root.left + 12
		if not touch and x + w > size.X / 2 - (keysHalf or 150) - 8 then
			bottom = Root.bottomClear() + 14 + 44 + 12
		end
	end
	f.AnchorPoint = Vector2.new(0, 1)
	f.Position = UDim2.new(0, x, 1, -bottom)
end

return HudCard

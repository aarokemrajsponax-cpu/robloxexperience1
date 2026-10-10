--!strict
-- Quiet notices at the top of the screen (a season turning, a table being taken), or in the
-- bottom-right corner while a panel is open, clear of it (and of the keys down the left). Nothing
-- pops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ease = require(ReplicatedStorage.Shared.Ease)
local Fade = require(script.Parent.Fade)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local Toast = {}

local current: Frame? = nil

-- How wide a notice may be: at the top, up to 420; with a panel open, as wide as the room beside
-- the panel allows (and no wider than 250), so it never sits over the panel itself. (On a screen
-- the panel fills, there is no room beside it: 250, over the panel's foot.)
local function widest(low: boolean): number
	local room = Root.size().X - 24
	if not low then
		return math.min(420, room)
	end
	local beside = Root.rightOfTop() - 14 - 10
	return math.min(if beside >= 150 then math.min(250, beside) else 250, room)
end

function Toast.show(title: string, line: string?, seconds: number?)
	if current then
		current:Destroy()
		current = nil
	end
	-- At the top; with a panel open, at the foot of the screen instead, clear of its heading.
	local low = Root.isOpen()
	local group, content = Theme.glass(
		Root.toasts,
		"Toast",
		UDim2.fromOffset(420, 0),
		if low then UDim2.new(1, -14, 1, -34) else UDim2.new(0.5, 0, 0, 58),
		if low then Vector2.new(1, 1) else Vector2.new(0.5, 0)
	)
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(widest(low), math.huge)
	limit.Parent = group
	Theme.list(content, 4)
	Theme.text(content, title, 12, "caps", { LayoutOrder = 1 })
	if line then
		Theme.text(content, line, 16, "display", { LayoutOrder = 2 })
	end
	current = group
	Fade.set(group, 1)
	Fade.to(group, Ease.scaled(Ease.settle), 0)
	task.delay(seconds or 4, function()
		if current == group then
			current = nil
			local t = Fade.to(group, Ease.info(0.8, Enum.EasingStyle.Sine), 1)
			t.Completed:Once(function()
				group:Destroy()
			end)
		end
	end)
end

-- A notice already showing moves out of the way when a panel opens (and back when it closes).
Root.PanelsChanged:Connect(function()
	local g = current
	if not g then
		return
	end
	local low = Root.isOpen()
	g.AnchorPoint = if low then Vector2.new(1, 1) else Vector2.new(0.5, 0)
	g.Position = if low then UDim2.new(1, -14, 1, -34) else UDim2.new(0.5, 0, 0, 58)
	local limit = g:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(widest(low), math.huge)
	end
end)

return Toast

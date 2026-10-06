--!strict
-- Quiet notices at the top of the screen (a season turning, a table being taken), or in the
-- bottom-left corner while a panel is open, clear of it. Nothing pops.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ease = require(ReplicatedStorage.Shared.Ease)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local Toast = {}

local current: CanvasGroup? = nil

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
		if low then UDim2.new(0, 14, 1, -34) else UDim2.new(0.5, 0, 0, 58),
		if low then Vector2.new(0, 1) else Vector2.new(0.5, 0)
	)
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(math.min(if low then 250 else 420, Root.size().X - 24), math.huge)
	limit.Parent = group
	Theme.list(content, 4)
	Theme.text(content, title, 12, "caps", { LayoutOrder = 1 })
	if line then
		Theme.text(content, line, 16, "display", { LayoutOrder = 2 })
	end
	current = group
	group.GroupTransparency = 1
	Ease.play(group, Ease.scaled(Ease.settle), { GroupTransparency = 0 })
	task.delay(seconds or 4, function()
		if current == group then
			current = nil
			local t = Ease.play(group, Ease.info(0.8, Enum.EasingStyle.Sine), { GroupTransparency = 1 })
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
	g.AnchorPoint = if low then Vector2.new(0, 1) else Vector2.new(0.5, 0)
	g.Position = if low then UDim2.new(0, 14, 1, -34) else UDim2.new(0.5, 0, 0, 58)
	local limit = g:FindFirstChildOfClass("UISizeConstraint")
	if limit then
		limit.MaxSize = Vector2.new(math.min(if low then 250 else 420, Root.size().X - 24), math.huge)
	end
end)

return Toast

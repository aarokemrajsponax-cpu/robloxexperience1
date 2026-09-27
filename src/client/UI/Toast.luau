--!strict
-- Quiet notices at the top of the screen (a season turning, a table being taken). Nothing pops.

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
	local group, content = Theme.glass(Root.hud, "Toast", UDim2.fromOffset(420, 0), UDim2.new(0.5, 0, 0, 58), Vector2.new(0.5, 0))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(math.min(420, Root.size().X - 24), math.huge)
	limit.Parent = group
	Theme.list(content, 4)
	Theme.text(content, title, 11, "caps", { LayoutOrder = 1 })
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

return Toast

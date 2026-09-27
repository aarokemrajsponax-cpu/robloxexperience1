--!strict
-- Staff lines in a glass panel: the speaker's name in small gold capitals, the line in serif,
-- and two or three short replies when there's a choice. Never the default Roblox bubble.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)

local Dialogue = {}

local current: CanvasGroup? = nil
local serial = 0

local function dismiss(group: CanvasGroup)
	if current == group then
		current = nil
	end
	local t = Ease.play(group, Ease.quick, { GroupTransparency = 1 })
	t.Completed:Once(function()
		group:Destroy()
	end)
end

export type Choice = { id: string, text: string }

function Dialogue.show(speaker: string, line: string, choices: { Choice }?, onChoice: ((id: string) -> ())?, hold: number?)
	serial += 1
	local mine = serial
	if current then
		dismiss(current)
	end
	local hasChoices = choices ~= nil and #choices > 0
	local group, content = Theme.glass(Root.dialogue, "Dialogue", UDim2.fromOffset(460, 0), UDim2.new(0.5, 0, 1, -34), Vector2.new(0.5, 1))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
	local fill = group:FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(1, 1)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(math.min(460, Root.size().X - 24), math.huge)
	limit.Parent = group
	local list = Theme.list(content, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(content, speaker, 11, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	Theme.text(content, line, 19, "display", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left })
	if hasChoices then
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.Size = UDim2.new(1, 0, 0, 0)
		row.LayoutOrder = 3
		row.Parent = content
		local rowList = Theme.list(row, 6)
		rowList.HorizontalAlignment = Enum.HorizontalAlignment.Left
		local first: TextButton? = nil
		for i, c in choices :: { Choice } do
			local key = Theme.key(row, c.text, i == 1, function()
				if current == group then
					dismiss(group)
				end
				if onChoice then
					onChoice(c.id)
				end
			end, 300)
			key.LayoutOrder = i
			key.TextXAlignment = Enum.TextXAlignment.Left
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 14)
			pad.Parent = key
			first = first or key
		end
		task.defer(function()
			if first and first.Parent then
				pcall(function()
					GuiService.SelectedObject = first
				end)
			end
		end)
	end
	current = group
	group.GroupTransparency = 1
	group.Position = UDim2.new(0.5, 0, 1, -26)
	Ease.play(group, Ease.scaled(Ease.panel), { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 1, -34) })
	if not hasChoices then
		task.delay(hold or 3.2, function()
			if serial == mine and current == group then
				dismiss(group)
			end
		end)
	else
		task.delay(20, function()
			if serial == mine and current == group then
				dismiss(group)
			end
		end)
	end
end

function Dialogue.close()
	if current then
		dismiss(current)
	end
end

function Dialogue.start()
	local choiceEvent = Remotes.event("DialogueChoice")
	Remotes.event("Dialogue").OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" then
			return
		end
		if message.close then
			Dialogue.close()
			return
		end
		local token = message.token
		Dialogue.show(tostring(message.speaker or ""), tostring(message.line or ""), message.choices, function(id)
			choiceEvent:FireServer(token, id)
		end, message.hold)
	end)
end

return Dialogue

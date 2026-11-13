--!strict
-- Staff lines in a glass panel: the speaker's name in small gold capitals, the line in serif,
-- and two or three short replies when there's a choice. Never the default Roblox bubble.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ease = require(ReplicatedStorage.Shared.Ease)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Fade = require(script.Parent.Fade)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Waypoint = require(script.Parent.Parent.World.Waypoint)

local Dialogue = {}

-- Set while the Concierge's tour runs: other staff lines arrive as small notices instead, so
-- nothing knocks a tour card off the screen.
Dialogue.isBusy = function(): boolean
	return false
end

local current: Frame? = nil
local serial = 0

local function dismiss(group: Frame)
	if current == group then
		current = nil
	end
	local t = Fade.to(group, Ease.quick, 1)
	t.Completed:Once(function()
		group:Destroy()
	end)
end

export type Choice = { id: string, text: string }

export type Extra = { title: string?, step: string?, point: Vector3?, pointName: string?, sticky: boolean? }

function Dialogue.show(speaker: string, line: string, choices: { Choice }?, onChoice: ((id: string) -> ())?, hold: number?, extra: Extra?)
	serial += 1
	-- The tour points at the place it's describing; anything else clears the pin.
	local x: Extra = extra or ({} :: Extra)
	if typeof(x.point) == "Vector3" then
		Waypoint.show(x.point :: Vector3, x.pointName or "")
	else
		Waypoint.clear()
	end
	local mine = serial
	if current then
		dismiss(current)
	end
	local hasChoices = choices ~= nil and #choices > 0
	local wide = x.title ~= nil
	local panelWidth = if wide then 540 else 460
	local group, content = Theme.glass(Root.dialogue, "Dialogue", UDim2.fromOffset(panelWidth, 0), UDim2.new(0.5, 0, 1, -34), Vector2.new(0.5, 1))
	Theme.fitHeight(group, content)
	local fill = group:FindFirstChild("Fill") :: Frame
	fill.Size = UDim2.fromScale(1, 1)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(math.min(panelWidth, Root.size().X - 24), math.huge)
	limit.Parent = group
	local list = Theme.list(content, 8)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Theme.text(content, speaker .. (if x.step then "   ·   " .. x.step else ""), 11, "caps", { LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Left })
	if x.title then
		Theme.text(content, x.title, 26, "display", { LayoutOrder = 2, TextXAlignment = Enum.TextXAlignment.Left })
	end
	Theme.text(content, line, 17, "body", { LayoutOrder = 3, TextXAlignment = Enum.TextXAlignment.Left })
	if hasChoices then
		-- (A long list, the Concierge's questions or his places, scrolls: the card never runs off
		-- the top of the screen, on a phone least of all.)
		local room = math.max(150, math.floor(Root.size().Y * 0.45))
		local row: GuiObject
		if not wide and #(choices :: { Choice }) * 50 > room then
			local scroll = Instance.new("ScrollingFrame")
			scroll.Name = "Choices"
			scroll.BackgroundTransparency = 1
			scroll.BorderSizePixel = 0
			scroll.Size = UDim2.new(1, 0, 0, room)
			scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
			scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
			scroll.ScrollingDirection = Enum.ScrollingDirection.Y
			scroll.ScrollBarThickness = 4
			scroll.ScrollBarImageColor3 = Color3.fromRGB(206, 166, 86)
			row = scroll
		else
			local f = Instance.new("Frame")
			f.BackgroundTransparency = 1
			f.AutomaticSize = Enum.AutomaticSize.Y
			f.Size = UDim2.new(1, 0, 0, 0)
			row = f
		end
		row.LayoutOrder = 4
		row.Parent = content
		local rowList = Theme.list(row, 6, wide)
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
			end, if wide then math.clamp(#c.text * 13 + 48, 150, 280) else 300)
			key.LayoutOrder = i
			key.TextXAlignment = if wide then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 14)
			pad.Parent = key
			first = first or key
		end
		task.defer(function()
			if first and first.Parent then
				pcall(function()
					Theme.select(first)
				end)
			end
		end)
	end
	current = group
	Fade.set(group, 1)
	group.Position = UDim2.new(0.5, 0, 1, -26)
	Fade.to(group, Ease.scaled(Ease.panel), 0, { Position = UDim2.new(0.5, 0, 1, -34) })
	if not hasChoices then
		task.delay(hold or 3.2, function()
			if serial == mine and current == group then
				dismiss(group)
			end
		end)
	elseif not x.sticky then
		task.delay(if wide then 90 else 20, function()
			if serial == mine and current == group then
				dismiss(group)
				Waypoint.clear()
			end
		end)
	end
end

-- Whether a line is on screen.
function Dialogue.isOpen(): boolean
	return current ~= nil and current.Parent ~= nil
end

function Dialogue.close()
	Waypoint.clear()
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
		if Dialogue.isBusy() then
			-- On the tour: a staff line becomes a notice; a question is let go (the guest is
			-- already being shown round, and can ask again after).
			if not message.close and type(message.line) == "string" and message.line ~= "" and not message.choices then
				Toast.show(tostring(message.speaker or ""), message.line, 4)
			end
			return
		end
		if message.close then
			Dialogue.close()
			return
		end
		local token = message.token
		Dialogue.show(tostring(message.speaker or ""), tostring(message.line or ""), message.choices, function(id)
			choiceEvent:FireServer(token, id)
		end, message.hold, {
			title = if type(message.title) == "string" then message.title else nil,
			step = if type(message.step) == "string" then message.step else nil,
			point = if typeof(message.point) == "Vector3" then message.point else nil,
			pointName = if type(message.pointName) == "string" then message.pointName else nil,
		})
	end)
end

return Dialogue

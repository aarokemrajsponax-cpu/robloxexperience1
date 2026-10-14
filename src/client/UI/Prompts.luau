--!strict
-- The world's prompts (ProximityPrompts), restyled and kept tidy: one neat column of glass cards
-- just right of the guest's own figure, each with the key to press (or "Tap" on phones), the
-- action in small capitals and what it's for underneath. Tapping or clicking a card triggers it.
-- In a column on the screen rather than a card floating over each thing, two things side by
-- side (the piano and the salute beside it) never pile their cards on each other, nor on anyone's
-- name. Every card in the column is the same width, so their edges line up.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Caps = require(ReplicatedStorage.Shared.Caps)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Fade = require(script.Parent.Fade)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)

local Prompts = {}

-- Set by Main: other words for a prompt's action on this guest's screen (the Concierge's "Show me
-- the house" for a guest still new to the house), or nil for its own.
Prompts.actionFor = function(_prompt: ProximityPrompt): string?
	return nil
end

local shown: { [ProximityPrompt]: TextButton } = {}
local column: Frame? = nil
local serial = 0

-- (Four at most at once: the nearest.)
local MOST = 4
local LEAST_W = 190
local ACTION, OBJECT = 15, 13

local function keyLabel(prompt: ProximityPrompt): string
	local kind = State.inputKind()
	if kind == "touch" then
		return "TAP"
	elseif kind == "gamepad" then
		local name = prompt.GamepadKeyCode.Name
		return (string.gsub(name, "^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

-- The column: right of the middle of the screen, where the guest's figure stands, a little below
-- their name.
local function stack(): Frame
	local c = column
	if c and c.Parent then
		return c
	end
	local f = Instance.new("Frame")
	f.Name = "PromptColumn"
	f.BackgroundTransparency = 1
	f.AnchorPoint = Vector2.new(0, 0)
	f.Position = UDim2.new(0.5, 64, 0.5, -16)
	f.Size = UDim2.fromOffset(LEAST_W, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Parent = Root.prompts
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = f
	column = f
	return f
end

-- Every card as wide as the widest of them (its key, its longer line, its margins).
local function align()
	local widest = LEAST_W
	for _, card in shown do
		widest = math.max(widest, card:GetAttribute("Wants") :: number? or LEAST_W)
	end
	widest = math.min(widest, math.max(LEAST_W, Root.size().X / 2 - 64 - 16))
	for _, card in shown do
		card.Size = UDim2.fromOffset(widest, card.Size.Y.Offset)
	end
	local c = column
	if c then
		c.Size = UDim2.fromOffset(widest, 0)
	end
end

local function build(prompt: ProximityPrompt): TextButton
	serial += 1
	local button = Instance.new("TextButton")
	button.Name = "Pill"
	button.LayoutOrder = serial
	button.AutoButtonColor = false
	button.Text = ""
	button.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	button.BackgroundTransparency = 0.12
	button.ClipsDescendants = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Brand.Colours.gold
	stroke.Transparency = 0.35
	stroke.Parent = button

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.BackgroundColor3 = Brand.Colours.gold
	key.BackgroundTransparency = 0.05
	key.AnchorPoint = Vector2.new(0, 0.5)
	key.Position = UDim2.new(0, 8, 0.5, 0)
	key.FontFace = Brand.Fonts.bodyBold
	key.TextSize = 14
	key.TextColor3 = Color3.fromRGB(24, 18, 8)
	key.Parent = button
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 6)
	keyCorner.Parent = key

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.BackgroundTransparency = 1
	action.FontFace = Brand.Fonts.bodyMedium
	action.TextSize = ACTION
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextYAlignment = Enum.TextYAlignment.Center
	action.TextTruncate = Enum.TextTruncate.AtEnd
	action.TextColor3 = Brand.Colours.lightGold
	action.Parent = button

	local object = Instance.new("TextLabel")
	object.Name = "Object"
	object.BackgroundTransparency = 1
	object.FontFace = Brand.Fonts.body
	object.TextSize = OBJECT
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextYAlignment = Enum.TextYAlignment.Center
	object.TextTruncate = Enum.TextTruncate.AtEnd
	object.TextColor3 = Brand.Colours.smoke
	object.Parent = button

	-- The card laid out round its words: the key square (wider for "TAP"), then the words.
	local function fit()
		key.Text = keyLabel(prompt)
		action.Text = Caps(Prompts.actionFor(prompt) or prompt.ActionText)
		object.Text = prompt.ObjectText
		local keyW = math.max(30, Theme.measure(key.Text, 14, Brand.Fonts.bodyBold).X + 12)
		key.Size = UDim2.fromOffset(keyW, 30)
		local left = 8 + keyW + 12
		local alone = object.Text == ""
		local high = if alone then 44 else 50
		action.Position = UDim2.fromOffset(left, if alone then 0 else 6)
		action.Size = UDim2.new(1, -(left + 12), if alone then 1 else 0, if alone then 0 else 20)
		object.Position = UDim2.fromOffset(left, 26)
		object.Size = UDim2.new(1, -(left + 12), 0, 17)
		object.Visible = not alone
		local words = math.max(Theme.measure(action.Text, ACTION, Brand.Fonts.bodyMedium).X, if alone then 0 else Theme.measure(object.Text, OBJECT, Brand.Fonts.body).X)
		button:SetAttribute("Wants", math.ceil(left + words + 16))
		button.Size = UDim2.fromOffset(button.Size.X.Offset, high)
		align()
	end
	button:SetAttribute("Wants", LEAST_W)
	button.Size = UDim2.fromOffset(LEAST_W, 50)
	prompt:GetPropertyChangedSignal("ActionText"):Connect(fit)
	prompt:GetPropertyChangedSignal("ObjectText"):Connect(fit)

	button.Activated:Connect(function()
		prompt:InputHoldBegin()
		task.wait()
		prompt:InputHoldEnd()
	end)
	button.Parent = stack()
	shown[prompt] = button
	fit()
	return button
end

-- Anything else that puts the world's prompts aside for a while (the piano's keyboard), by name.
local holds: { [string]: true } = {}

local function hidden(): boolean
	return Root.isOpen() or next(holds) ~= nil
end

local function refresh()
	local hide = hidden()
	ProximityPromptService.Enabled = not hide
	local c = column
	if c then
		c.Visible = not hide
	end
end

function Prompts.hold(name: string, on: boolean)
	if on then
		holds[name] = true
	else
		holds[name] = nil
	end
	refresh()
end

local function drop(prompt: ProximityPrompt)
	local card = shown[prompt]
	if card then
		shown[prompt] = nil
		card:Destroy()
		align()
	end
end

function Prompts.start()
	pcall(function()
		ProximityPromptService.MaxPromptsVisible = MOST
	end)
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, _inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		if State.seated then
			return
		end
		drop(prompt)
		local card = build(prompt)
		refresh()
		-- (In softly.)
		Fade.set(card, 1)
		Fade.to(card, Ease.panel, 0)
	end)
	-- Every interaction answers with a sound the moment it's pressed (the object's own sound,
	-- where it has one, plays on top when the server answers).
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local own = prompt:GetAttribute("Sound")
		if type(own) == "string" and Sound.has(own) then
			Sound.play(own, 0.5)
		else
			Sound.ui()
		end
		local pill = shown[prompt]
		if pill then
			-- A press: the pill dips and brightens for a beat.
			local stroke = pill:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Transparency = 0
				Ease.play(stroke, Ease.info(0.35, Enum.EasingStyle.Quad), { Transparency = 0.35 })
			end
		end
	end)
	ProximityPromptService.PromptHidden:Connect(drop)
	-- While a panel is open the guest is in a menu: the prompts in the world step aside, and
	-- can't be set off behind it.
	Root.PanelsChanged:Connect(refresh)
	UserInputService.LastInputTypeChanged:Connect(function()
		for prompt, card in shown do
			local key = card:FindFirstChild("Key")
			if key and key:IsA("TextLabel") then
				key.Text = keyLabel(prompt)
			end
		end
	end)
end

function Prompts.clear()
	for prompt, card in shown do
		card:Destroy()
		shown[prompt] = nil
	end
	align()
end

-- The cards showing now, for the tests.
function Prompts.cards(): { TextButton }
	local out = {}
	for _, card in shown do
		table.insert(out, card)
	end
	return out
end

return Prompts

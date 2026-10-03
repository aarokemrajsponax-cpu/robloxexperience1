--!strict
-- A restyled ProximityPrompt: a small glass pill with the action in small capitals and the key
-- to press (or "Tap" on phones). Tapping or clicking the pill triggers it.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Root = require(script.Parent.Root)
local State = require(script.Parent.Parent.State)

local Prompts = {}

local shown: { [ProximityPrompt]: BillboardGui } = {}

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

local function build(prompt: ProximityPrompt): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompt"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(210, 46)
	local offset = prompt:GetAttribute("Offset")
	gui.StudsOffset = Vector3.new(0, if type(offset) == "number" then offset else 2.2, 0)
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Active = true
	gui.Adornee = prompt.Parent :: any

	local button = Instance.new("TextButton")
	button.Name = "Pill"
	button.AutoButtonColor = false
	button.Text = ""
	button.Size = UDim2.fromScale(1, 1)
	button.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	button.BackgroundTransparency = 0.2
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Brand.Colours.gold
	stroke.Transparency = 0.35
	stroke.Parent = button

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.BackgroundColor3 = Brand.Colours.gold
	key.BackgroundTransparency = 0.1
	key.Size = UDim2.new(0, 38, 1, -14)
	key.Position = UDim2.fromOffset(7, 7)
	key.FontFace = Brand.Fonts.bodyBold
	key.TextSize = 13
	key.TextColor3 = Color3.fromRGB(24, 18, 8)
	key.Text = keyLabel(prompt)
	key.Parent = button
	local keyCorner = Instance.new("UICorner")
	keyCorner.CornerRadius = UDim.new(0, 2)
	keyCorner.Parent = key

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.BackgroundTransparency = 1
	action.Position = UDim2.fromOffset(54, 5)
	action.Size = UDim2.new(1, -60, 0.55, -2)
	action.FontFace = Brand.Fonts.bodyMedium
	action.TextSize = 15
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextColor3 = Brand.Colours.lightGold
	action.Text = string.upper(prompt.ActionText)
	action.Parent = button

	local object = Instance.new("TextLabel")
	object.Name = "Object"
	object.BackgroundTransparency = 1
	object.Position = UDim2.new(0, 54, 0.55, 0)
	object.Size = UDim2.new(1, -60, 0.4, -4)
	object.FontFace = Brand.Fonts.bodyMedium
	object.TextSize = 13
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextColor3 = Brand.Colours.smoke
	object.Text = prompt.ObjectText
	object.Parent = button

	button.Activated:Connect(function()
		prompt:InputHoldBegin()
		task.wait()
		prompt:InputHoldEnd()
	end)
	gui.Parent = Root.prompts
	return gui
end

function Prompts.start()
	ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt, _inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		if State.seated then
			return
		end
		local gui = shown[prompt]
		if gui then
			gui:Destroy()
		end
		gui = build(prompt)
		gui.Enabled = not Root.isOpen()
		shown[prompt] = gui
		local pill = gui:FindFirstChild("Pill") :: TextButton
		pill.BackgroundTransparency = 1
		Ease.play(pill, Ease.panel, { BackgroundTransparency = 0.2 })
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt: ProximityPrompt)
		local gui = shown[prompt]
		if gui then
			shown[prompt] = nil
			gui:Destroy()
		end
	end)
	-- While a panel is open the guest is in a menu: the prompts in the world step aside, and
	-- can't be set off behind it.
	Root.PanelsChanged:Connect(function()
		local open = Root.isOpen()
		ProximityPromptService.Enabled = not open
		for _, gui in shown do
			gui.Enabled = not open
		end
	end)
	UserInputService.LastInputTypeChanged:Connect(function()
		for prompt, gui in shown do
			local pill = gui:FindFirstChild("Pill")
			local key = pill and pill:FindFirstChild("Key")
			if key and key:IsA("TextLabel") then
				key.Text = keyLabel(prompt)
			end
		end
	end)
end

function Prompts.clear()
	for prompt, gui in shown do
		gui:Destroy()
		shown[prompt] = nil
	end
end

return Prompts

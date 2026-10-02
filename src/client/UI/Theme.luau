--!strict
-- The look of every panel: smoked liquid glass with a gold hairline, serif display type,
-- a clean sans for everything else, brass keys that press in. Text follows the Text size
-- and Lettering settings live.

local ContentProvider = game:GetService("ContentProvider")
local HapticService = game:GetService("HapticService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Settings = require(ReplicatedStorage.Shared.Settings)
local State = require(script.Parent.Parent.State)

local Theme = {}

local C = Brand.Colours

Theme.colours = {
	glass = Color3.fromRGB(12, 13, 16),
	bone = C.bone,
	smoke = C.smoke,
	dim = C.dim,
	gold = C.gold,
	lightGold = C.lightGold,
	deepGold = C.deepGold,
	accent = C.gold,
	base = C.room,
}

type TextKind = "display" | "italic" | "body" | "light" | "bodyMedium" | "bodyBold" | "caps"
type Registered = { label: TextLabel | TextButton, size: number, kind: TextKind }

local registry: { Registered } = {}
local textScale = 1
local displayFont = Brand.Fonts.display

local clickSound: (() -> ())? = nil
function Theme.onClick(fn: () -> ())
	clickSound = fn
end

local hoverSound: (() -> ())? = nil
function Theme.onHover(fn: () -> ())
	hoverSound = fn
end

local function fontFor(kind: TextKind): Font
	if kind == "display" then
		return displayFont
	elseif kind == "italic" then
		return Brand.Fonts.displayItalic
	elseif kind == "light" then
		return Brand.Fonts.light
	elseif kind == "bodyMedium" or kind == "caps" then
		return Brand.Fonts.bodyMedium
	elseif kind == "bodyBold" then
		return Brand.Fonts.bodyBold
	end
	return Brand.Fonts.body
end

local function applyText(r: Registered)
	local label = r.label :: any
	-- The serif is for headings: below heading size it reads as wiry, so small "display" text
	-- (a line of dialogue, a caption) is set in the clean sans instead.
	label.FontFace = if r.kind == "display" and r.size < 22 then Brand.Fonts.body else fontFor(r.kind)
	local size = math.floor(r.size * textScale + 0.5)
	label.TextSize = size
	-- Keys shrink their words to fit rather than spill over their edges.
	local fit = label:FindFirstChild("Fit")
	if fit and fit:IsA("UITextSizeConstraint") then
		fit.MaxTextSize = size
	end
end

function Theme.refresh()
	for i = #registry, 1, -1 do
		local r = registry[i]
		if r.label.Parent == nil then
			table.remove(registry, i)
		else
			applyText(r)
		end
	end
end

State.watch("textSize", function(value)
	textScale = Settings.textScale(value)
	Theme.refresh()
end)
State.watch("lettering", function(value)
	displayFont = Brand.Lettering[value] or Brand.Fonts.display
	Theme.refresh()
end)
State.watch("houseStyle", function(value)
	local style = Brand.HouseStyles[value]
	if style then
		Theme.colours.accent = style.accent
		Theme.colours.base = style.base
	end
end)

-- The house fonts come from the Creator Store: fetch them as the guest arrives so the first
-- panel is already set in them.
function Theme.preloadFonts()
	local labels = {}
	for _, font in Brand.Fonts do
		local l = Instance.new("TextLabel")
		l.FontFace = font :: Font
		l.Text = "Maison Noir 0123456789"
		table.insert(labels, l)
	end
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync(labels)
		end)
		for _, l in labels do
			l:Destroy()
		end
	end)
end

-- Spaces capitals for small labels.
function Theme.track(text: string): string
	local out = {}
	for _, cp in utf8.codes(text) do
		local ch = utf8.char(cp)
		table.insert(out, if ch == " " then "  " else ch)
	end
	return table.concat(out, " ")
end

function Theme.text(parent: Instance, text: string, size: number, kind: TextKind?, props: { [string]: any }?): TextLabel
	local k: TextKind = kind or "body"
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = if k == "caps" then Theme.track(string.upper(text)) else text
	label.TextColor3 = if k == "display" then C.bone elseif k == "caps" then C.gold else C.bone
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.Size = UDim2.new(1, 0, 0, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.RichText = false
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	local r = { label = label, size = size, kind = k }
	applyText(r)
	table.insert(registry, r)
	label.Parent = parent
	return label
end

function Theme.hairline(parent: Instance, width: UDim?, order: number?): Frame
	local line = Instance.new("Frame")
	line.Name = "Hairline"
	line.BorderSizePixel = 0
	line.BackgroundColor3 = C.gold
	line.BackgroundTransparency = 0.25
	line.Size = UDim2.new(width or UDim.new(0.4, 0), UDim.new(0, 1))
	line.LayoutOrder = order or 0
	line.Parent = parent
	return line
end

-- A smoked-glass panel. Returns the CanvasGroup (for fades) and the content frame.
function Theme.glass(parent: Instance, name: string, size: UDim2, position: UDim2?, anchor: Vector2?): (CanvasGroup, Frame)
	local group = Instance.new("CanvasGroup")
	group.Name = name
	group.BackgroundTransparency = 1
	group.Size = size
	group.Position = position or UDim2.fromScale(0.5, 0.5)
	group.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	group.GroupTransparency = 0
	group.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.colours.glass
	-- Nearly solid: name tags and prompts in the world never show through a panel.
	fill.BackgroundTransparency = 0.04
	fill.BorderSizePixel = 0
	fill.Parent = group
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = fill
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.gold
	stroke.Transparency = 0.45
	stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = fill
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.fromRGB(46, 46, 52), Theme.colours.glass)
	sheen.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.18, 0.1),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	sheen.Parent = fill
	-- A soft highlight along the top edge
	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BorderSizePixel = 0
	highlight.BackgroundColor3 = C.lightGold
	highlight.BackgroundTransparency = 0.7
	highlight.Size = UDim2.new(1, -12, 0, 1)
	highlight.Position = UDim2.new(0, 6, 0, 1)
	highlight.Parent = group

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(1, 1)
	content.Parent = group
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 22)
	pad.PaddingBottom = UDim.new(0, 22)
	pad.PaddingLeft = UDim.new(0, 24)
	pad.PaddingRight = UDim.new(0, 24)
	pad.Parent = content
	return group, content
end

-- A glass panel that grows to fit what's on it (so nothing is ever cut off at the bottom).
function Theme.fitHeight(group: CanvasGroup, content: Frame)
	group.Size = UDim2.new(group.Size.X, UDim.new(0, 0))
	group.AutomaticSize = Enum.AutomaticSize.Y
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 0, 0)
end

function Theme.list(parent: Instance, padding: number?, horizontal: boolean?): UIListLayout
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, padding or 10)
	list.Parent = parent
	return list
end

function Theme.haptic()
	if State.get("vibration") ~= "On" then
		return
	end
	pcall(function()
		local effect = Instance.new("HapticEffect")
		effect.Type = Enum.HapticEffectType.UIClick
		effect.Parent = workspace
		effect:Play()
		task.delay(0.3, function()
			effect:Destroy()
		end)
	end)
	pcall(function()
		HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.25)
		task.delay(0.05, function()
			HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
		end)
	end)
end

-- The gold outline a gamepad's selection draws around a key (instead of Roblox's default).
local function selectionRing(): Frame
	local ring = Instance.new("Frame")
	ring.Name = "Selection"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.new(1, 8, 1, 8)
	ring.Position = UDim2.fromOffset(-4, -4)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.lightGold
	stroke.Thickness = 2
	stroke.Parent = ring
	return ring
end

-- A brass key. Under the pointer (or a gamepad's selection) it lifts a touch and its edge
-- brightens; pressed, it sinks; let go, it springs back with a soft click and a brief glint to
-- say it was taken; a tiny vibration on phones.
function Theme.key(parent: Instance, text: string, primary: boolean?, onPress: () -> (), width: number?): TextButton
	local button = Instance.new("TextButton")
	button.Name = "Key_" .. text
	button.AutoButtonColor = false
	local baseColour = if primary then C.gold else Color3.fromRGB(20, 20, 24)
	local hoverColour = if primary then C.lightGold else Color3.fromRGB(34, 32, 30)
	local baseFill = if primary then 0.08 else 0.3
	button.BackgroundColor3 = baseColour
	button.BackgroundTransparency = baseFill
	button.BorderSizePixel = 0
	button.Size = UDim2.new(0, width or 200, 0, 44)
	button.Text = Theme.track(string.upper(text))
	button.TextColor3 = if primary then Color3.fromRGB(24, 18, 8) else C.lightGold
	button.Selectable = true
	button.SelectionImageObject = selectionRing()
	button.TextScaled = true
	local fit = Instance.new("UITextSizeConstraint")
	fit.Name = "Fit"
	fit.MinTextSize = 9
	fit.MaxTextSize = 15
	fit.Parent = button
	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = UDim.new(0, 10)
	inner.PaddingRight = UDim.new(0, 10)
	inner.PaddingTop = UDim.new(0, 6)
	inner.PaddingBottom = UDim.new(0, 6)
	inner.Parent = button
	local r = { label = button, size = 15, kind = "caps" :: TextKind }
	applyText(r)
	table.insert(registry, r)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = C.gold
	stroke.Transparency = if primary then 0.2 else 0.5
	stroke.Parent = button
	local scale = Instance.new("UIScale")
	scale.Parent = button
	-- The glint: a band of light across the key when it is taken.
	local glint = Instance.new("Frame")
	glint.Name = "Glint"
	glint.BackgroundColor3 = C.lightGold
	glint.BackgroundTransparency = 1
	glint.BorderSizePixel = 0
	glint.Size = UDim2.fromScale(1, 1)
	glint.ZIndex = button.ZIndex + 1
	glint.Parent = button
	local glintCorner = Instance.new("UICorner")
	glintCorner.CornerRadius = UDim.new(0, 2)
	glintCorner.Parent = glint

	local over = false
	local function lit(on: boolean)
		over = on
		Ease.play(stroke, Ease.quick, { Transparency = if on then 0 else (if primary then 0.2 else 0.5) })
		Ease.play(scale, Ease.info(0.16, Enum.EasingStyle.Quad), { Scale = if on then 1.025 else 1 })
		Ease.play(button, Ease.quick, {
			BackgroundColor3 = if on then hoverColour else baseColour,
			BackgroundTransparency = if on then math.max(0, baseFill - 0.1) else baseFill,
		})
	end
	button.MouseEnter:Connect(function()
		if not over and hoverSound then
			hoverSound()
		end
		lit(true)
	end)
	button.MouseLeave:Connect(function()
		lit(false)
	end)
	button.SelectionGained:Connect(function()
		if hoverSound then
			hoverSound()
		end
		lit(true)
	end)
	button.SelectionLost:Connect(function()
		lit(false)
	end)
	button.MouseButton1Down:Connect(function()
		Ease.play(scale, Ease.info(0.08, Enum.EasingStyle.Quad), { Scale = 0.965 })
	end)
	button.MouseButton1Up:Connect(function()
		Ease.play(scale, Ease.info(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = if over then 1.025 else 1 })
	end)
	button.Activated:Connect(function()
		if clickSound then
			clickSound()
		end
		Theme.haptic()
		glint.BackgroundTransparency = 0.55
		Ease.play(glint, Ease.info(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
		onPress()
	end)
	button.Parent = parent
	return button
end

return Theme

--!strict
-- The brass counter set into each table's near edge. Its digits roll like an odometer and never
-- jitter; the enamel dial beside it shows the multiplier. Every table's counter is visible to
-- everyone (from the table's Score attribute); the guest's own table follows their predicted score.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)

local Counter = {}

local DIGITS = 7
local ENGRAVED = Color3.fromRGB(34, 26, 10)

type Wheel = { strip: Frame, value: number }
type Display = { wheels: { Wheel }, dial: TextLabel?, value: number, own: boolean }

local displays: { [Model]: Display } = {}

local function build(model: Model): Display?
	local part = model:FindFirstChild("Counter")
	if not part or not part:IsA("BasePart") then
		return nil
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "CounterGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 110
	gui.LightInfluence = 0.5
	gui.Brightness = 1.2
	gui.MaxDistance = 60
	gui.ClipsDescendants = true
	gui.Parent = part

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.5)
	row.Size = UDim2.fromScale(0.94, 0.78)
	row.Parent = gui
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0.012, 0)
	list.Parent = row

	local wheels: { Wheel } = {}
	for i = 1, DIGITS do
		local window = Instance.new("Frame")
		window.Name = "Wheel" .. i
		window.LayoutOrder = i
		window.BackgroundColor3 = Color3.fromRGB(22, 18, 12)
		window.BackgroundTransparency = 0.05
		window.Size = UDim2.new(1 / DIGITS - 0.014, 0, 1, 0)
		window.ClipsDescendants = true
		window.Parent = row
		local stroke = Instance.new("UIStroke")
		stroke.Color = Brand.Colours.deepGold
		stroke.Thickness = 1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = window
		local strip = Instance.new("Frame")
		strip.Name = "Strip"
		strip.BackgroundTransparency = 1
		strip.Size = UDim2.fromScale(1, 10)
		strip.Position = UDim2.fromScale(0, 0)
		strip.Parent = window
		for d = 0, 9 do
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 0.1)
			l.Position = UDim2.fromScale(0, d * 0.1)
			l.FontFace = Brand.Fonts.figures
			l.TextScaled = true
			l.TextColor3 = Brand.Colours.lightGold
			l.Text = tostring(d)
			l.Parent = strip
		end
		table.insert(wheels, { strip = strip, value = 0 })
	end

	local dialLabel: TextLabel? = nil
	local dialPart = model:FindFirstChild("Dial")
	if dialPart and dialPart:IsA("BasePart") then
		local dg = Instance.new("SurfaceGui")
		dg.Name = "DialGui"
		dg.Face = Enum.NormalId.Right
		dg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		dg.PixelsPerStud = 160
		dg.LightInfluence = 0.5
		dg.MaxDistance = 60
		dg.Parent = dialPart
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, 0.5)
		l.Size = UDim2.fromScale(0.62, 0.5)
		l.FontFace = Brand.Fonts.figures
		l.TextScaled = true
		l.TextColor3 = ENGRAVED
		l.Text = "×1"
		l.Parent = dg
		dialLabel = l
	end
	return { wheels = wheels, dial = dialLabel, value = 0, own = false }
end

local function show(d: Display, value: number, instant: boolean?)
	value = math.clamp(math.floor(value), 0, 10 ^ DIGITS - 1)
	d.value = value
	local digits = string.format("%0" .. DIGITS .. "d", value)
	for i, wheel in d.wheels do
		local digit = tonumber(string.sub(digits, i, i)) or 0
		if digit ~= wheel.value or instant then
			wheel.value = digit
			local goal = { Position = UDim2.fromScale(0, -digit) }
			if instant then
				wheel.strip.Position = goal.Position
			else
				local delay = (DIGITS - i) * 0.03
				TweenService:Create(wheel.strip, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out, 0, false, delay), goal):Play()
			end
		end
	end
end

local function attach(model: Model)
	if displays[model] then
		return
	end
	local d = build(model)
	if not d then
		return
	end
	displays[model] = d
	local score = model:GetAttribute("Score")
	show(d, if type(score) == "number" then score else 0, true)
	model:GetAttributeChangedSignal("Score"):Connect(function()
		if not d.own then
			local s = model:GetAttribute("Score")
			show(d, if type(s) == "number" then s else 0)
		end
	end)
	model:GetAttributeChangedSignal("Multiplier"):Connect(function()
		if not d.own and d.dial then
			d.dial.Text = "×" .. tostring(model:GetAttribute("Multiplier") or 1)
		end
	end)
end

function Counter.start()
	for _, m in CollectionService:GetTagged("MaisonTable") do
		if m:IsA("Model") then
			attach(m)
		end
	end
	CollectionService:GetInstanceAddedSignal("MaisonTable"):Connect(function(m)
		if m:IsA("Model") then
			task.defer(attach, m)
		end
	end)
end

-- The guest's own table: drive it from the predicted score.
function Counter.own(model: Model, isOwn: boolean)
	local d = displays[model]
	if d then
		d.own = isOwn
	end
end

function Counter.set(model: Model, value: number, instant: boolean?)
	local d = displays[model]
	if d then
		show(d, value, instant)
	end
end

function Counter.setMultiplier(model: Model, m: number)
	local d = displays[model]
	if d and d.dial then
		d.dial.Text = "×" .. tostring(m)
		if m > 1 then
			local l = d.dial
			l.TextColor3 = Brand.Colours.deepGold
			TweenService:Create(l, TweenInfo.new(0.5), { TextColor3 = ENGRAVED }):Play()
		end
	end
end

-- The dial's own words (in the Library it shows the hands won, yours to theirs).
function Counter.setDialText(model: Model, text: string)
	local d = displays[model]
	if d and d.dial then
		d.dial.Text = text
		d.dial.TextColor3 = Brand.Colours.deepGold
		TweenService:Create(d.dial, TweenInfo.new(0.8), { TextColor3 = ENGRAVED }):Play()
	end
end

return Counter

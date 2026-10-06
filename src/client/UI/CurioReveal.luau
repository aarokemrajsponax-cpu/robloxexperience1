--!strict
-- The moment a curio comes to you: its medallion rises in the middle of the screen in a ring of
-- its rarity's light, with its name, its rarity and why it came. The rarer it is, the bigger the
-- moment: a Common is a quick card; a Rare adds a burst of sparks; an Epic and up add rays that
-- turn behind it and a chord; a Mythic or a Secret holds a little longer, with a shimmer of
-- gold across the screen. Tapping anywhere puts it away early. Finds that come together queue.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Curios = require(ReplicatedStorage.Shared.Curios)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Root = require(script.Parent.Root)
local CurioArt = require(script.Parent.CurioArt)
local Sound = require(script.Parent.Parent.Sound)

local CurioReveal = {}

local C = Brand.Colours
local queue: { { id: string, line: string, gilt: number } } = {}
local showing = false

-- How big each rarity's moment is: 1 (a card) to 4 (the lot).
local TIER = { Common = 1, Uncommon = 1, Rare = 2, Epic = 3, Limited = 3, Legendary = 3, Mythic = 4, Secret = 4 }

local function sparks(parent: Instance, colour: Color3, count: number)
	for i = 1, count do
		local s = Instance.new("Frame")
		s.Name = "Spark"
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.5, 0.42)
		s.Size = UDim2.fromOffset(6, 6)
		s.Rotation = 45
		s.BackgroundColor3 = colour
		s.BorderSizePixel = 0
		s.ZIndex = 2
		s.Parent = parent
		local a = (i / count) * math.pi * 2
		local r = 140 + (i % 3) * 40
		Ease.play(s, Ease.info(0.9, Enum.EasingStyle.Quint), {
			Position = UDim2.new(0.5, math.cos(a) * r, 0.42, math.sin(a) * r),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2),
		})
	end
end

local function showNext()
	local item = table.remove(queue, 1)
	if not item then
		showing = false
		return
	end
	showing = true
	local c = Curios.byId[item.id]
	if not c then
		showNext()
		return
	end
	local tier = TIER[c.rarity] or 1
	local colour = Curios.RarityColour[c.rarity] or C.gold
	if c.rarity == "Secret" then
		colour = Color3.fromRGB(200, 196, 230)
	end
	local layer = Instance.new("TextButton")
	layer.Name = "CurioReveal"
	layer.Text = ""
	layer.AutoButtonColor = false
	layer.BackgroundColor3 = Color3.new(0, 0, 0)
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 50
	layer.Parent = Root.toasts
	Ease.play(layer, Ease.info(0.3), { BackgroundTransparency = if tier >= 3 then 0.35 else 0.55 })
	-- The ring of light, and (Epic and up) the turning rays.
	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.42)
	glow.Size = UDim2.fromOffset(40, 40)
	glow.BackgroundColor3 = colour
	glow.BackgroundTransparency = 0.6
	glow.ZIndex = 51
	glow.Parent = layer
	local gc = Instance.new("UICorner")
	gc.CornerRadius = UDim.new(1, 0)
	gc.Parent = glow
	Ease.play(glow, Ease.info(0.6, Enum.EasingStyle.Quint), { Size = UDim2.fromOffset(260, 260), BackgroundTransparency = 0.82 })
	if tier >= 3 then
		for i = 0, 7 do
			local ray = Instance.new("Frame")
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.42)
			ray.Size = UDim2.fromOffset(420, 10)
			ray.Rotation = i * 22.5
			ray.BackgroundColor3 = colour
			ray.BackgroundTransparency = 0.86
			ray.BorderSizePixel = 0
			ray.ZIndex = 50
			ray.Parent = layer
			Ease.play(ray, Ease.info(4, Enum.EasingStyle.Linear), { Rotation = i * 22.5 + 60 })
		end
	end
	local medal = CurioArt.medallion(layer, c.id, 150)
	medal.AnchorPoint = Vector2.new(0.5, 0.5)
	medal.Position = UDim2.fromScale(0.5, 0.42)
	medal.ZIndex = 53
	for _, d in medal:GetDescendants() do
		if d:IsA("GuiObject") then
			d.ZIndex = 54
		end
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 0.2
	scale.Parent = medal
	Ease.play(scale, Ease.info(0.55, Enum.EasingStyle.Back), { Scale = 1 })
	local function line(text: string, size: number, font: Font, y: number, tint: Color3)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0)
		t.Position = UDim2.new(0.5, 0, 0.42, y)
		t.Size = UDim2.new(0.9, 0, 0, size + 8)
		t.Text = text
		t.TextWrapped = true
		t.FontFace = font
		t.TextSize = size
		t.TextColor3 = tint
		t.TextTransparency = 1
		t.ZIndex = 55
		t.Parent = layer
		Ease.play(t, Ease.info(0.4), { TextTransparency = 0 })
	end
	line(string.upper(c.rarity), 15, Brand.Fonts.bodyBold, 92, colour)
	line(c.name, 30, Brand.Fonts.display, 114, C.bone)
	line(item.line .. (if item.gilt > 0 then string.format("  +%d Gilt", item.gilt) else ""), 15, Brand.Fonts.body, 156, C.smoke)
	if tier >= 2 then
		sparks(layer, colour, 10 + tier * 6)
	end
	if tier >= 4 then
		local sheen = Instance.new("Frame")
		sheen.BackgroundColor3 = C.lightGold
		sheen.BackgroundTransparency = 0.7
		sheen.Size = UDim2.new(0.25, 0, 1, 0)
		sheen.Position = UDim2.fromScale(-0.3, 0)
		sheen.ZIndex = 52
		sheen.Parent = layer
		Ease.play(sheen, Ease.info(1.2, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1.1, 0), BackgroundTransparency = 1 })
	end
	pcall(function()
		if tier >= 3 then
			Sound.chime(6)
		elseif tier >= 2 then
			Sound.shimmer()
		else
			Sound.play("reward", 0.5)
		end
	end)
	local done = false
	local function close()
		if done then
			return
		end
		done = true
		Ease.play(layer, Ease.info(0.35), { BackgroundTransparency = 1 })
		for _, d in layer:GetDescendants() do
			if d:IsA("TextLabel") then
				Ease.play(d, Ease.info(0.3), { TextTransparency = 1 })
			elseif d:IsA("Frame") then
				Ease.play(d, Ease.info(0.3), { BackgroundTransparency = 1 })
			end
		end
		task.delay(0.4, function()
			layer:Destroy()
			showNext()
		end)
	end
	layer.Activated:Connect(close)
	task.delay(if tier >= 4 then 4.5 elseif tier >= 3 then 3.6 else 2.6, close)
end

-- Shows (or queues) a curio coming to this guest.
function CurioReveal.show(id: string, line: string?, gilt: number?)
	table.insert(queue, { id = id, line = line or "", gilt = gilt or 0 })
	if not showing then
		showNext()
	end
end

return CurioReveal

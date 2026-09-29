--!strict
-- The sealed parcel (Library and Ballroom): a small leather box tied in gold ribbon with a wax
-- seal, a count, and a short fuse that burns down to the seal before it opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Brand = require(ReplicatedStorage.Shared.Brand)

local State = require(script.Parent.Parent.State)

local Parcels = {}

export type Built = { model: Model, fuse: BasePart, label: TextLabel, spark: ParticleEmitter }

function Parcels.build(count: number): Built
	local m = Instance.new("Model")
	m.Name = "Parcel"
	local box = Instance.new("Part")
	box.Name = "Box"
	box.Size = Vector3.new(0.72, 0.5, 0.6)
	box.Color = Color3.fromRGB(26, 22, 20)
	box.Material = Enum.Material.Leather
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.Parent = m
	m.PrimaryPart = box
	-- Gold ribbon, both ways round the box.
	local ribbons: { Vector3 } = { Vector3.new(0.1, 0.52, 0.62), Vector3.new(0.74, 0.52, 0.1) }
	for _, size in ribbons do
		local ribbon = Instance.new("Part")
		ribbon.Name = "Ribbon"
		ribbon.Size = size
		ribbon.Color = Brand.Colours.gold
		ribbon.Material = Enum.Material.Metal
		ribbon.Anchored = true
		ribbon.CanCollide = false
		ribbon.CanQuery = false
		ribbon.CanTouch = false
		ribbon.CFrame = box.CFrame
		ribbon.Parent = m
	end
	local seal = Instance.new("Part")
	seal.Name = "Seal"
	seal.Shape = Enum.PartType.Cylinder
	seal.Size = Vector3.new(0.05, 0.22, 0.22)
	seal.Color = Color3.fromRGB(128, 22, 30)
	seal.Material = Enum.Material.SmoothPlastic
	seal.Anchored = true
	seal.CanCollide = false
	seal.CanQuery = false
	seal.CFrame = box.CFrame * CFrame.new(0, 0.27, 0) * CFrame.Angles(0, 0, math.rad(90))
	seal.Parent = m
	-- The fuse: a short cord from the seal that burns down.
	local fuse = Instance.new("Part")
	fuse.Name = "Fuse"
	fuse.Size = Vector3.new(0.05, 0.05, 0.6)
	fuse.Color = Color3.fromRGB(214, 190, 150)
	fuse.Material = Enum.Material.Fabric
	fuse.Anchored = true
	fuse.CanCollide = false
	fuse.CanQuery = false
	fuse.CFrame = box.CFrame * CFrame.new(0, 0.3, -0.3 - 0.3)
	fuse.Parent = m
	local tip = Instance.new("Attachment")
	tip.Name = "Tip"
	tip.Position = Vector3.new(0, 0, -0.3)
	tip.Parent = fuse
	local spark = Instance.new("ParticleEmitter")
	spark.Rate = 40
	spark.Lifetime = NumberRange.new(0.15, 0.3)
	spark.Speed = NumberRange.new(1, 2.5)
	spark.SpreadAngle = Vector2.new(180, 180)
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07), NumberSequenceKeypoint.new(1, 0) })
	spark.Color = ColorSequence.new(Color3.fromRGB(255, 200, 110), Color3.fromRGB(255, 120, 60))
	spark.LightEmission = 1
	spark.Enabled = false
	spark.Parent = tip
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 170, 90)
	glow.Brightness = 1.2
	glow.Range = 3
	glow.Parent = tip
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(44, 26)
	gui.StudsOffset = Vector3.new(0, 0.7, 0)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.Adornee = box
	gui.Parent = m
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(12, 13, 16)
	label.BackgroundTransparency = 0.2
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Brand.Fonts.display
	label.TextScaled = true
	label.TextColor3 = Brand.Colours.lightGold
	label.Text = "×" .. tostring(count)
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = label
	return { model = m, fuse = fuse, label = label, spark = spark }
end

-- Lights the fuse: it burns toward the seal over `seconds`, following the box if it moves.
function Parcels.burn(b: Built, seconds: number)
	local model, fuse, spark = b.model, b.fuse, b.spark
	spark.Enabled = true
	local burn = math.max(0.1, seconds)
	local tip = fuse:FindFirstChild("Tip") :: Attachment?
	local value = Instance.new("NumberValue")
	value.Value = 1
	value.Changed:Connect(function(v)
		local box = model.PrimaryPart
		if fuse.Parent and box then
			local length = math.max(0.02, 0.6 * v)
			fuse.Size = Vector3.new(0.05, 0.05, length)
			fuse.CFrame = box.CFrame * CFrame.new(0, 0.3, -0.3 - length / 2)
			if tip then
				tip.Position = Vector3.new(0, 0, -length / 2)
			end
		end
	end)
	local t = TweenService:Create(value, TweenInfo.new(burn, Enum.EasingStyle.Linear), { Value = 0 })
	t.Completed:Once(function()
		value:Destroy()
	end)
	t:Play()
end

function Parcels.setCount(b: Built, count: number)
	b.label.Text = "×" .. tostring(count)
end

-- Opens (or cancels) with a burst of gold, fades and is gone.
function Parcels.burst(model: Model)
	local box = model.PrimaryPart
	if box then
		local a = Instance.new("Attachment")
		a.Parent = box
		local e = Instance.new("ParticleEmitter")
		e.Rate = 0
		e.Color = ColorSequence.new(Brand.Colours.lightGold)
		e.LightEmission = 1
		e.Lifetime = NumberRange.new(0.3, 0.6)
		e.Speed = NumberRange.new(2, 4)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 0) })
		e.Parent = a
		e:Emit(if State.get("glow") == "Off" then 4 else 16)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(0.35), { Transparency = 1 }):Play()
		elseif d:IsA("ParticleEmitter") and d.Rate > 0 then
			d.Enabled = false
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		elseif d:IsA("PointLight") then
			d.Enabled = false
		end
	end
	task.delay(0.8, function()
		model:Destroy()
	end)
end

return Parcels

-- Temporary sign that proves GitHub -> your computer -> Studio is linked.
local Workspace = game:GetService("Workspace")

local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
local spawnPosition = if spawn then spawn.Position else Vector3.new(0, 0, 0)

local sign = Instance.new("Part")
sign.Name = "ClaudeConnectionSign"
sign.Anchored = true
sign.CanCollide = false
sign.Transparency = 1
sign.Size = Vector3.new(1, 1, 1)
sign.Position = spawnPosition + Vector3.new(0, 10, -12)
sign.Parent = Workspace

local billboard = Instance.new("BillboardGui")
billboard.Size = UDim2.fromScale(24, 6)
billboard.AlwaysOnTop = true
billboard.Parent = sign

local label = Instance.new("TextLabel")
label.Size = UDim2.fromScale(1, 1)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
label.BackgroundTransparency = 0.2
label.TextColor3 = Color3.fromRGB(80, 255, 120)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = "✅ Claude is connected!"
label.Parent = billboard

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0.2, 0)
corner.Parent = label

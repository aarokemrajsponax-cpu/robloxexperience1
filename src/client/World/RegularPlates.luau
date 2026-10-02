--!strict
-- A regular's usual table carries their name while they're in the house: a small brass plate
-- above it ("Ada's usual table"), so guests see who belongs here.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Brand = require(ReplicatedStorage.Shared.Brand)

local RegularPlates = {}

local function plate(m: Instance)
	if not m:IsA("Model") then
		return
	end
	local function draw()
		local old = m:FindFirstChild("RegularPlate")
		if old then
			old:Destroy()
		end
		local name = m:GetAttribute("Regular")
		local anchor = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
		if type(name) ~= "string" or name == "" or not anchor then
			return
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "RegularPlate"
		gui.Size = UDim2.fromOffset(170, 24)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 7.2, 0)
		gui.MaxDistance = 40
		gui.LightInfluence = 0
		gui.Adornee = anchor
		local label = Instance.new("TextLabel")
		label.BackgroundColor3 = Color3.fromRGB(40, 30, 14)
		label.BackgroundTransparency = 0.25
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = Brand.Fonts.bodyMedium
		label.TextScaled = true
		label.TextColor3 = Brand.Colours.lightGold
		label.Text = name .. "'s usual table"
		label.Parent = gui
		local stroke = Instance.new("UIStroke")
		stroke.Color = Brand.Colours.gold
		stroke.Transparency = 0.3
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = label
		gui.Parent = m
	end
	m:GetAttributeChangedSignal("Regular"):Connect(draw)
	draw()
end

function RegularPlates.start()
	for _, m in CollectionService:GetTagged("MaisonTable") do
		plate(m)
	end
	CollectionService:GetInstanceAddedSignal("MaisonTable"):Connect(plate)
end

return RegularPlates

--!strict
-- (Build 102) The first thing anyone sees while the game loads: the whole screen, the house at
-- night (Shared/Skyline), the game's name, and how far along it really is (what Roblox still has
-- queued to fetch, then the house itself saying it's up). It replaces Roblox's own loading screen
-- straight away, and goes the moment the Home Screen (or play) is ready underneath: never later
-- than a firm limit, so nobody is ever left on it.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "HouseLoadScreen"
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local base = Instance.new("Frame")
base.Name = "Base"
base.Size = UDim2.fromScale(1, 1)
base.BackgroundColor3 = Color3.fromRGB(6, 4, 12)
base.BorderSizePixel = 0
base.Active = true
base.Parent = gui

pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local started = os.clock()
local camera = Workspace.CurrentCamera
local pixels = if camera then camera.ViewportSize else Vector2.new(1280, 720)
if pixels.X < 10 then
	pixels = Vector2.new(1280, 720)
end
local short = math.min(pixels.X, pixels.Y)

-- The scene, as soon as the shared code has arrived (a second or two at most, usually at once).
local step: ((t: number) -> ())? = nil
local name = "BECOME THE RICHEST GUEST"
local display: Font = Font.fromEnum(Enum.Font.GothamBlack)
local body: Font = Font.fromEnum(Enum.Font.GothamMedium)
pcall(function()
	local shared = ReplicatedStorage:WaitForChild("Shared", 8)
	local sky = shared and shared:WaitForChild("Skyline", 8)
	if sky and sky:IsA("ModuleScript") then
		local Skyline = (require :: any)(sky)
		local scene = Skyline.build(base, "house", pixels, short < 500, true)
		step = scene.step
	end
	local brand = shared and shared:FindFirstChild("Brand")
	if brand and brand:IsA("ModuleScript") then
		local Brand = (require :: any)(brand)
		name = Brand.Name or name
		display = Brand.Fonts and Brand.Fonts.display or display
		body = Brand.Fonts and Brand.Fonts.bodyBold or body
	end
end)

-- A shade along the foot so the words read over the water.
local shade = Instance.new("Frame")
shade.Name = "Shade"
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BorderSizePixel = 0
shade.ZIndex = 30
shade.Parent = base
local sg = Instance.new("UIGradient")
sg.Rotation = 90
sg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.3, 1), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 0.25) })
sg.Parent = shade

local function text(label: string, words: string, size: number, font: Font, colour: Color3, y: number, height: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = label
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0)
	l.Position = UDim2.new(0.5, 0, 0, y)
	l.Size = UDim2.new(1, -48, 0, height)
	l.Text = words
	l.TextSize = size
	l.FontFace = font
	l.TextColor3 = colour
	l.TextWrapped = true
	l.ZIndex = 40
	l.Parent = base
	return l
end

-- The name, large, in light gold; under it how far along, and a line of what's happening.
local titleSize = math.floor(math.clamp(short * 0.085, 26, 68))
text("Kicker", "WELCOME TO", math.floor(math.clamp(short * 0.026, 11, 18)), body, Color3.fromRGB(255, 214, 150), pixels.Y * 0.2, titleSize * 0.5)
local title = text("Title", name, titleSize, display, Color3.new(1, 1, 1), pixels.Y * 0.2 + titleSize * 0.55, titleSize * 2.4)
local metal = Instance.new("UIGradient")
metal.Rotation = 90
metal.Color = ColorSequence.new(Color3.fromRGB(255, 250, 236), Color3.fromRGB(240, 196, 110))
metal.Parent = title

local barW = math.min(pixels.X - 64, 520)
local barY = pixels.Y * 0.8
local track = Instance.new("Frame")
track.Name = "Track"
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0, barY)
track.Size = UDim2.fromOffset(barW, 4)
track.BackgroundColor3 = Color3.new(1, 1, 1)
track.BackgroundTransparency = 0.82
track.BorderSizePixel = 0
track.ZIndex = 40
track.Parent = base
local tc = Instance.new("UICorner")
tc.CornerRadius = UDim.new(1, 0)
tc.Parent = track
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(255, 206, 120)
fill.BorderSizePixel = 0
fill.ZIndex = 41
fill.Parent = track
local fc = Instance.new("UICorner")
fc.CornerRadius = UDim.new(1, 0)
fc.Parent = fill
local small = math.floor(math.clamp(short * 0.024, 11, 16))
local status = text("Status", "Opening the doors", small, body, Color3.fromRGB(244, 232, 214), barY + 14, small + 6)
local percent = text("Percent", "0%", small, body, Color3.fromRGB(255, 206, 120), barY - small - 10, small + 4)

-- Real progress: what's still queued to fetch (the most seen counts as the whole), then the house
-- itself saying it's up.
local most = 1
local shown = 0
local leaving = false
local beat: RBXScriptConnection? = nil

local function goal(): (number, string)
	if ReplicatedFirst:GetAttribute("HouseReady") == true then
		return 1, "Welcome"
	end
	local queued = ContentProvider.RequestQueueSize
	most = math.max(most, queued)
	local fetched = 1 - queued / math.max(1, most)
	if not game:IsLoaded() then
		return 0.05 + 0.6 * fetched, "Opening the doors"
	end
	return 0.65 + 0.25 * fetched, "Lighting the rooms"
end

local function leave()
	if leaving then
		return
	end
	leaving = true
	local info = TweenInfo.new(0.8, Enum.EasingStyle.Quad)
	for _, d in base:GetDescendants() do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		end
	end
	TweenService:Create(base, info, { BackgroundTransparency = 1 }):Play()
	task.delay(0.85, function()
		if beat then
			beat:Disconnect()
		end
		gui:Destroy()
	end)
end

beat = RunService.RenderStepped:Connect(function(dt: number)
	local g, words = goal()
	shown += (g - shown) * math.min(1, dt * 5)
	fill.Size = UDim2.fromScale(shown, 1)
	percent.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
	status.Text = words
	local s = step
	if s then
		pcall(s, os.clock() - started)
	end
	if g >= 1 and shown > 0.97 then
		leave()
	end
end)

-- Never left on it: gone 20 seconds after the game has loaded, whatever else.
task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	task.wait(20)
	leave()
end)

--!strict
-- Photo mode (§4): a free camera within a few steps of your avatar, depth of field on whoever is
-- in front of it, three film grades, the house gestures, and a clean capture (no interface, only a
-- tiny MAISON NOIR hairline mark in the corner) shared through Roblox's own capture sharing.
-- Keyboard: W A S D to move, Q and E down and up, right mouse to look. Gamepad: the sticks, and
-- the shoulder buttons for down and up. Touch: drag to look.

local CaptureService = game:GetService("CaptureService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Root)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local PhotoMode = {}

local player = Players.LocalPlayer
local REACH = 28 -- studs from your avatar the camera may wander
local SPEED = 14

-- Set by Main.
PhotoMode.onEnter = function() end
PhotoMode.onExit = function() end
PhotoMode.gesture = function() end
PhotoMode.canEnter = function(): boolean
	return true
end

export type Grade = { name: string, saturation: number, contrast: number, brightness: number, tint: Color3 }
PhotoMode.Grades = {
	{ name = "As it is", saturation = 0, contrast = 0, brightness = 0, tint = Color3.new(1, 1, 1) },
	{ name = "Noir", saturation = -1, contrast = 0.28, brightness = -0.02, tint = Color3.new(1, 1, 1) },
	{ name = "Gilded", saturation = 0.1, contrast = 0.12, brightness = 0.02, tint = Color3.fromRGB(255, 236, 200) },
	{ name = "Velvet", saturation = -0.1, contrast = 0.1, brightness = 0, tint = Color3.fromRGB(255, 220, 226) },
} :: { Grade }

local active = false
local yaw, pitch = 0, 0
local position = Vector3.zero
local grade = 1
local look = Vector2.zero
local move = Vector3.zero
local connections: { RBXScriptConnection } = {}
local bar: Frame? = nil
local mark: Frame? = nil
local gradeLabel: TextLabel? = nil
local dof: DepthOfFieldEffect? = nil
local cc: ColorCorrectionEffect? = nil
local hudWas = true

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function applyGrade()
	local g = PhotoMode.Grades[grade]
	local e = cc
	if e then
		e.Saturation = g.saturation
		e.Contrast = g.contrast
		e.Brightness = g.brightness
		e.TintColor = g.tint
	end
	local label = gradeLabel
	if label then
		label.Text = Theme.track(string.upper(g.name))
	end
end

local function key(parent: Instance, text: string, primary: boolean, fn: () -> (), order: number): TextButton
	local k = Theme.key(parent, text, primary, fn, 120)
	k.Size = UDim2.fromOffset(120, 38)
	k.LayoutOrder = order
	return k
end

function PhotoMode.capture()
	local b, m = bar, mark
	if b then
		b.Visible = false
	end
	if m then
		m.Visible = true
	end
	task.wait(0.15)
	local ok = pcall(function()
		CaptureService:CaptureScreenshot(function(contentId: any)
			pcall(function()
				CaptureService:PromptShareCapture(Content.fromUri(tostring(contentId)), "salon", function() end, function() end)
			end)
		end)
	end)
	task.wait(0.3)
	if m then
		m.Visible = false
	end
	if b then
		b.Visible = true
	end
	if not ok then
		Toast.show("Photo", "Capturing isn't available on this device.", 3)
	end
end

local function buildOverlay()
	local b = Instance.new("Frame")
	b.Name = "PhotoBar"
	b.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	b.BackgroundTransparency = 0.25
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 1, -16)
	b.Size = UDim2.fromOffset(620, 54)
	b.Parent = Root.panels
	local stroke = Instance.new("UIStroke")
	stroke.Color = Brand.Colours.gold
	stroke.Transparency = 0.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local list = Theme.list(b, 8, true)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	key(b, "‹ Grade", false, function()
		grade = (grade - 2) % #PhotoMode.Grades + 1
		applyGrade()
	end, 1)
	gradeLabel = Theme.text(b, "", 13, "caps", { LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.fromOffset(90, 38) })
	key(b, "Grade ›", false, function()
		grade = grade % #PhotoMode.Grades + 1
		applyGrade()
	end, 3)
	key(b, "Gesture", false, function()
		PhotoMode.gesture()
	end, 4)
	key(b, "Capture", true, function()
		task.spawn(PhotoMode.capture)
	end, 5)
	key(b, "Done", false, function()
		PhotoMode.exit()
	end, 6)
	bar = b
	-- The mark on a capture: a hairline and MAISON NOIR, tiny, bottom right.
	local m = Instance.new("Frame")
	m.Name = "PhotoMark"
	m.BackgroundTransparency = 1
	m.AnchorPoint = Vector2.new(1, 1)
	m.Position = UDim2.new(1, -18, 1, -14)
	m.Size = UDim2.fromOffset(160, 26)
	m.Visible = false
	m.Parent = Root.panels
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = Brand.Colours.gold
	rule.BorderSizePixel = 0
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.Parent = m
	Theme.text(m, Theme.track("MAISON NOIR"), 11, "caps", { Position = UDim2.fromOffset(0, 5), AutomaticSize = Enum.AutomaticSize.None, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Brand.Colours.lightGold })
	mark = m
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local anchor = rootPosition()
	if not camera or not anchor then
		return
	end
	-- Look: right mouse drag, the right stick, or a touch drag.
	yaw -= look.X * dt * 2.2
	pitch = math.clamp(pitch - look.Y * dt * 2.2, -1.3, 1.3)
	look = look * (if UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad1 then 1 else 0)
	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	-- Move: W A S D / Q E, or the left stick and the shoulders.
	local input = move
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		input += Vector3.new(0, 0, -1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		input += Vector3.new(0, 0, 1)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		input += Vector3.new(-1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		input += Vector3.new(1, 0, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.E) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonR1) then
		input += Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL1) then
		input += Vector3.new(0, -1, 0)
	end
	local worldMove = rot:VectorToWorldSpace(Vector3.new(input.X, 0, input.Z)) + Vector3.new(0, input.Y, 0)
	position += worldMove * SPEED * dt
	-- Stay within reach of your avatar (a free camera within the room, not the whole world).
	local offset = position - anchor
	if offset.Magnitude > REACH then
		position = anchor + offset.Unit * REACH
	end
	camera.CFrame = CFrame.new(position) * rot
	-- Focus on your avatar.
	local e = dof
	if e then
		e.FocusDistance = (anchor - position).Magnitude
	end
end

function PhotoMode.enter()
	if active then
		return
	end
	local camera = Workspace.CurrentCamera
	local anchor = rootPosition()
	if not camera or not anchor then
		Toast.show("Photo", "Step into the house first.", 2.5)
		return
	end
	if not PhotoMode.canEnter() then
		Toast.show("Photo", "Leave the table first; photo mode is for walking the house.", 3)
		return
	end
	active = true
	Root.close()
	PhotoMode.onEnter()
	hudWas = Root.hud.Enabled
	Root.hud.Enabled = false
	camera.CameraType = Enum.CameraType.Scriptable
	position = camera.CFrame.Position
	local x, y, _ = camera.CFrame:ToEulerAnglesYXZ()
	pitch, yaw = x, y
	local d = Instance.new("DepthOfFieldEffect")
	d.Name = "MaisonPhotoFocus"
	d.InFocusRadius = 6
	d.FarIntensity = 0.45
	d.NearIntensity = 0.3
	d.Parent = Lighting
	dof = d
	local c = Instance.new("ColorCorrectionEffect")
	c.Name = "MaisonPhotoGrade"
	c.Parent = Lighting
	cc = c
	buildOverlay()
	applyGrade()
	table.insert(connections, RunService.RenderStepped:Connect(step))
	table.insert(connections, UserInputService.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			look = Vector2.new(input.Delta.X, input.Delta.Y) * 6
		elseif input.UserInputType == Enum.UserInputType.Touch then
			look = Vector2.new(input.Delta.X, input.Delta.Y) * 4
		elseif input.KeyCode == Enum.KeyCode.Thumbstick2 then
			look = Vector2.new(input.Position.X, -input.Position.Y) * 1.2
		elseif input.KeyCode == Enum.KeyCode.Thumbstick1 then
			local p = input.Position
			move = if p.Magnitude > 0.15 then Vector3.new(p.X, 0, -p.Y) else Vector3.zero
		end
	end))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.KeyCode == Enum.KeyCode.ButtonB then
			PhotoMode.exit()
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			look = Vector2.zero
		elseif input.UserInputType == Enum.UserInputType.Touch then
			look = Vector2.zero
		end
	end))
	Toast.show("Photo", "W A S D to move, Q and E for height, right mouse to look.", 3)
end

function PhotoMode.exit()
	if not active then
		return
	end
	active = false
	for _, c in connections do
		c:Disconnect()
	end
	connections = {}
	for _, inst in { bar, mark, dof, cc } :: { Instance? } do
		if inst then
			inst:Destroy()
		end
	end
	bar, mark, dof, cc, gradeLabel = nil, nil, nil, nil, nil
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	look, move = Vector2.zero, Vector3.zero
	Root.hud.Enabled = hudWas
	PhotoMode.onExit()
end

function PhotoMode.isActive(): boolean
	return active
end

return PhotoMode

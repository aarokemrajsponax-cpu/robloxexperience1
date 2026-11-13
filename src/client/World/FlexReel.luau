--!strict
-- A flex reel, shot on this guest's own screen (Build 81): seven seconds, framed upright like a
-- phone held up (the rest of the screen dark), three moves of the camera round them on the Flex
-- Studio's stage (a push in, a slide past, a low hero shot), the set built round them for those
-- seconds only (the private jet, the penthouse at night, the supercar garage, the yacht at sunset),
-- the thing they're flexing on a gold card beside them, their caption along the foot, and at the
-- end the card that says it's up on the Flex Wall. Its likes are the real ones (none yet); nothing
-- here is counted or paid: the server did that when the reel was shot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Plan = require(ReplicatedStorage.Shared.Flex)

local FlexReel = {}

local rgb = Color3.fromRGB
local PINK = rgb(255, 90, 180)
local GOLD = rgb(255, 204, 90)

local playing = false

local function root(): BasePart?
	local character = Players.LocalPlayer.Character
	local r = character and character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- The reel's own layer over the whole screen (the top inset too), as the jet's flight has.
local function layer(): ScreenGui
	local s = Instance.new("ScreenGui")
	s.Name = "MaisonReel"
	s.IgnoreGuiInset = true
	s.DisplayOrder = 80
	s.ResetOnSpawn = false
	s.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	return s
end

local function viewport(): Vector2
	local camera = Workspace.CurrentCamera
	local v = camera and camera.ViewportSize
	return if typeof(v) == "Vector2" and v.X > 0 and v.Y > 0 then v else Vector2.new(1280, 720)
end

local function sound(name: string, volume: number)
	pcall(function()
		(require(script.Parent.Parent.Sound) :: any).play(name, volume)
	end)
end

-- A part of the set: anchored, never in anyone's way, gone with the reel.
local function piece(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = parent
	return p
end

local function wheel(parent: Instance, name: string, at: CFrame, diameter: number, colour: Color3)
	local w = piece(parent, name, Vector3.new(0.6, diameter, diameter), at, colour, Enum.Material.SmoothPlastic)
	w.Shape = Enum.PartType.Cylinder
end

-- The set, built round the mark (`m`: on the stage, facing the camera down the nave).
local function dress(parent: Instance, setId: string, m: CFrame)
	local back = function(x: number, y: number, z: number): CFrame
		return m * CFrame.new(x, y, z)
	end
	if setId == "jet" then
		-- Cream leather and walnut, three windows full of sky, a seat and a flute of champagne.
		piece(parent, "CabinWall", Vector3.new(14, 9, 0.4), back(0, 4.5, 5), rgb(236, 226, 206))
		piece(parent, "CabinTrim", Vector3.new(14, 0.3, 0.5), back(0, 2.2, 4.9), rgb(96, 60, 34), Enum.Material.Wood)
		for _, x in { -4.5, 0, 4.5 } do
			local win = piece(parent, "Window", Vector3.new(0.2, 2.4, 1.7), back(x, 5.2, 4.75) * CFrame.Angles(0, math.rad(90), 0), rgb(160, 206, 250), Enum.Material.Neon)
			win.Shape = Enum.PartType.Cylinder
			win.Size = Vector3.new(0.2, 2, 2)
		end
		piece(parent, "Seat", Vector3.new(3, 1.6, 3), back(4.6, 0.8, 1.5), rgb(222, 206, 176), Enum.Material.Leather)
		piece(parent, "SeatBack", Vector3.new(3, 3.6, 0.8), back(4.6, 2.6, 2.8), rgb(222, 206, 176), Enum.Material.Leather)
		piece(parent, "SideTable", Vector3.new(1.4, 2.6, 1.4), back(-4.2, 1.3, 1.6), rgb(96, 60, 34), Enum.Material.Wood)
		piece(parent, "Flute", Vector3.new(0.25, 1, 0.25), back(-4.2, 3.1, 1.6), rgb(255, 230, 160), Enum.Material.Glass, 0.3)
	elseif setId == "penthouse" then
		-- Black glass on the skyline at night, a gold sofa, a lamp.
		piece(parent, "Glass", Vector3.new(16, 10, 0.3), back(0, 5, 5.5), rgb(10, 14, 30), Enum.Material.Glass, 0.15)
		for i = 0, 27 do
			local x = -7 + (i % 7) * 2.3 + ((i * 37) % 5) * 0.12
			local y = 1.6 + (i // 7) * 2 + ((i * 13) % 3) * 0.3
			piece(parent, "CityLight", Vector3.new(0.5, 0.35, 0.1), back(x, y, 5.3), if i % 3 == 0 then rgb(170, 210, 255) else rgb(255, 214, 150), Enum.Material.Neon)
		end
		piece(parent, "Sofa", Vector3.new(5, 1.4, 2.2), back(-4.2, 0.7, 2.4), rgb(40, 34, 30), Enum.Material.Leather)
		piece(parent, "SofaBack", Vector3.new(5, 2, 0.6), back(-4.2, 1.8, 3.3), rgb(40, 34, 30), Enum.Material.Leather)
		piece(parent, "SofaTrim", Vector3.new(5.2, 0.2, 2.4), back(-4.2, 1.45, 2.4), GOLD, Enum.Material.Metal)
		piece(parent, "LampPole", Vector3.new(0.2, 6, 0.2), back(4.6, 3, 2.6), GOLD, Enum.Material.Metal)
		piece(parent, "LampShade", Vector3.new(1.4, 1, 1.4), back(4.6, 6.2, 2.6), rgb(255, 226, 180), Enum.Material.Neon, 0.1)
	elseif setId == "garage" then
		-- Polished concrete, strips of pink neon, the car.
		piece(parent, "Wall", Vector3.new(16, 10, 0.4), back(0, 5, 5.5), rgb(30, 30, 34), Enum.Material.Concrete)
		for _, x in { -6, -2, 2, 6 } do
			piece(parent, "NeonStrip", Vector3.new(0.3, 8, 0.2), back(x, 5, 5.25), if x < 0 then PINK else rgb(120, 220, 255), Enum.Material.Neon)
		end
		local car = back(5.2, 0, 1.8) * CFrame.Angles(0, math.rad(-20), 0)
		piece(parent, "CarBody", Vector3.new(3.6, 1.2, 8), car * CFrame.new(0, 1, 0), rgb(220, 30, 60), Enum.Material.SmoothPlastic)
		piece(parent, "CarCabin", Vector3.new(3.1, 1, 3.6), car * CFrame.new(0, 2.05, 0.4), rgb(20, 20, 26), Enum.Material.Glass, 0.1)
		piece(parent, "TailLights", Vector3.new(3.2, 0.2, 0.1), car * CFrame.new(0, 1.3, 4.02), rgb(255, 40, 60), Enum.Material.Neon)
		piece(parent, "HeadLights", Vector3.new(3.2, 0.2, 0.1), car * CFrame.new(0, 1.3, -4.02), rgb(255, 250, 230), Enum.Material.Neon)
		for _, w in { { -1.8, -2.6 }, { 1.8, -2.6 }, { -1.8, 2.6 }, { 1.8, 2.6 } } do
			wheel(parent, "Wheel", car * CFrame.new(w[1], 0.75, w[2]), 1.5, rgb(16, 16, 18))
		end
	elseif setId == "yacht" then
		-- Teak decks, chrome rails, the sun going down behind.
		piece(parent, "Deck", Vector3.new(16, 0.2, 9), back(0, 0.1, 1.5), rgb(150, 96, 52), Enum.Material.WoodPlanks)
		for k, colour in { rgb(255, 120, 70), rgb(255, 150, 90), rgb(255, 190, 120), rgb(250, 120, 140) } do
			piece(parent, "Sunset", Vector3.new(18, 2.6, 0.2), back(0, k * 2.4 - 0.6, 6.2), colour, Enum.Material.Neon)
		end
		local sun = piece(parent, "Sun", Vector3.new(0.3, 4, 4), back(-3, 4.2, 6) * CFrame.Angles(0, math.rad(90), 0), rgb(255, 236, 170), Enum.Material.Neon)
		sun.Shape = Enum.PartType.Cylinder
		for _, h in { 2.4, 3.6 } do
			piece(parent, "Rail", Vector3.new(16, 0.15, 0.15), back(0, h, 5.4), rgb(220, 224, 232), Enum.Material.Metal)
		end
		piece(parent, "Lounger", Vector3.new(2, 0.8, 5), back(-4.8, 0.6, 2.2), rgb(244, 240, 232), Enum.Material.Fabric)
	end
end

-- What's being flexed, on a gold card beside them.
local function card(parent: Instance, at: CFrame, item: { [string]: any })
	local anchor = piece(parent, "FlexCard", Vector3.new(1, 1, 1), at, GOLD, Enum.Material.Neon, 1)
	local gui = Instance.new("BillboardGui")
	gui.Name = "FlexCardGui"
	gui.Size = UDim2.fromScale(4.6, 3.4)
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = rgb(20, 16, 10)
	f.BackgroundTransparency = 0.1
	f.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = f
	local edge = Instance.new("UIStroke")
	edge.Color = GOLD
	edge.Thickness = 3
	edge.Parent = f
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.BackgroundTransparency = 1
	glyph.Size = UDim2.fromScale(1, 0.55)
	glyph.TextScaled = true
	glyph.Text = tostring(item.glyph or "✨")
	glyph.Parent = f
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0.05, 0.56)
	name.Size = UDim2.fromScale(0.9, 0.26)
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = GOLD
	name.Text = tostring(item.name or "")
	name.Parent = f
	local small = Instance.new("TextLabel")
	small.Name = "Rarity"
	small.BackgroundTransparency = 1
	small.Position = UDim2.fromScale(0.05, 0.82)
	small.Size = UDim2.fromScale(0.9, 0.13)
	small.TextScaled = true
	small.Font = Enum.Font.GothamBold
	small.TextColor3 = rgb(236, 226, 206)
	small.Text = string.upper(tostring(item.rarity or (Plan.KindNames[tostring(item.kind)] or "")))
	small.Parent = f
end

-- The frame on the screen: upright like a phone, the rest dark; REC and the time at the top, the
-- name and caption along the foot, its likes (the real count) at the side.
local function overlay(reel: { [string]: any }, screen: ScreenGui): (Frame, TextLabel)
	local size = viewport()
	local phoneW = math.min(size.X, math.floor(size.Y * 9 / 16))
	local side = math.max(0, (size.X - phoneW) / 2)
	local f = Instance.new("Frame")
	f.Name = "FlexReelFrame"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 50
	f.Parent = screen
	for i, x in { 0, side + phoneW } do
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. i
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromOffset(x, 0)
		bar.Size = UDim2.new(0, side, 1, 0)
		bar.ZIndex = 50
		bar.Parent = f
	end
	local window = Instance.new("Frame")
	window.Name = "Phone"
	window.BackgroundTransparency = 1
	window.Position = UDim2.fromOffset(side, 0)
	window.Size = UDim2.new(0, phoneW, 1, 0)
	window.ZIndex = 51
	window.Parent = f
	local function label(name: string, text: string, pos: UDim2, sz: UDim2, colour: Color3, bold: boolean, align: Enum.TextXAlignment?): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = pos
		l.Size = sz
		l.Text = text
		l.TextColor3 = colour
		l.TextScaled = true
		l.TextWrapped = true
		l.Font = if bold then Enum.Font.GothamBlack else Enum.Font.GothamMedium
		l.TextXAlignment = align or Enum.TextXAlignment.Left
		l.TextStrokeTransparency = 0.5
		l.ZIndex = 52
		l.Parent = window
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 30
		cap.Parent = l
		return l
	end
	local clock = label("Rec", "●  REC  0:00", UDim2.new(0.05, 0, 0.04, 0), UDim2.new(0.5, 0, 0.035, 0), rgb(255, 70, 80), true)
	label("Brand", "THE MAISON", UDim2.new(0.5, 0, 0.04, 0), UDim2.new(0.45, 0, 0.035, 0), rgb(255, 255, 255), true, Enum.TextXAlignment.Right)
	label("Likes", "♥\n" .. tostring(reel.likes or 0), UDim2.new(0.84, 0, 0.55, 0), UDim2.new(0.12, 0, 0.09, 0), rgb(255, 255, 255), true, Enum.TextXAlignment.Center)
	label("Name", "@" .. tostring(reel.by or ""), UDim2.new(0.05, 0, 0.78, 0), UDim2.new(0.75, 0, 0.04, 0), rgb(255, 255, 255), true)
	label("Caption", tostring(reel.text or ""), UDim2.new(0.05, 0, 0.83, 0), UDim2.new(0.78, 0, 0.09, 0), rgb(255, 255, 255), false)
	label("Sound", "♫  original sound  ·  the Grand Ballroom", UDim2.new(0.05, 0, 0.93, 0), UDim2.new(0.8, 0, 0.03, 0), rgb(230, 230, 230), false)
	return f, clock
end

local function flash(f: Frame)
	local white = Instance.new("Frame")
	white.Name = "Flash"
	white.BackgroundColor3 = Color3.new(1, 1, 1)
	white.BackgroundTransparency = 0.2
	white.Size = UDim2.fromScale(1, 1)
	white.ZIndex = 60
	white.Parent = f
	TweenService:Create(white, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	task.delay(0.4, function()
		white:Destroy()
	end)
end

function FlexReel.playing(): boolean
	return playing
end

-- Shoots the reel the server just put up (its id, who, the item, the set, the caption).
function FlexReel.play(reel: { [string]: any })
	if playing then
		return
	end
	local r = root()
	local camera = Workspace.CurrentCamera
	if not r or not camera then
		return
	end
	playing = true
	local origin = AttractionList.origin("gala")
	local mark = CFrame.new(origin + Plan.MARK.Position) * (Plan.MARK - Plan.MARK.Position)
	local folder = Instance.new("Folder")
	folder.Name = "FlexReelSet"
	folder.Parent = Workspace
	pcall(dress, folder, tostring(reel.set or ""), mark)
	local p = r.CFrame.Position
	local item = if type(reel.item) == "table" then reel.item else {}
	pcall(card, folder, CFrame.new(p + Vector3.new(-3.2, 1.2, -0.6)), item)
	-- (The house's own keys step aside for the seven seconds, as for the jet's flight.)
	local hudGui: any = nil
	local hudWas = true
	pcall(function()
		local Root = require(script.Parent.Parent.UI.Root) :: any
		Root.close()
		hudGui = Root.hud
		hudWas = hudGui.Enabled
		hudGui.Enabled = false
	end)
	local screen = layer()
	local frame, clock = overlay(reel, screen)
	local previous = camera.CameraType
	camera.CameraType = Enum.CameraType.Scriptable
	local started = os.clock()
	local function shot(from: Vector3, to: Vector3, look: Vector3, seconds: number)
		camera.CFrame = CFrame.lookAt(from, look)
		TweenService:Create(camera, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { CFrame = CFrame.lookAt(to, look) }):Play()
	end
	sound("shimmer", 0.8)
	task.spawn(function()
		local ok, err = pcall(function()
			-- 1: a push in.
			shot(p + Vector3.new(0, 2.2, -14), p + Vector3.new(0, 1.6, -9), p + Vector3.new(0, 0.6, 0), 2.4)
			for s = 1, 2 do
				task.wait(1.2)
				clock.Text = string.format("●  REC  0:%02d", s)
			end
			-- 2: a slide past, the card in the frame.
			flash(frame)
			sound("place", 0.6)
			shot(p + Vector3.new(-6, 1.2, -5), p + Vector3.new(6, 1.2, -5), p + Vector3.new(0, 0.4, 0), 2.4)
			for s = 3, 4 do
				task.wait(1.2)
				clock.Text = string.format("●  REC  0:%02d", s)
			end
			-- 3: the low hero shot.
			flash(frame)
			sound("celebrate", 0.7)
			shot(p + Vector3.new(2.5, -1.8, -6), p + Vector3.new(1.5, -1.6, -4.5), p + Vector3.new(0, 1.2, 0), 2.2)
			for s = 5, 7 do
				task.wait(0.75)
				clock.Text = string.format("●  REC  0:%02d", s)
			end
			-- Posted.
			local done = Instance.new("TextLabel")
			done.Name = "Posted"
			done.BackgroundColor3 = rgb(10, 10, 14)
			done.BackgroundTransparency = 0.15
			done.AnchorPoint = Vector2.new(0.5, 0.5)
			done.Position = UDim2.fromScale(0.5, 0.45)
			done.Size = UDim2.fromOffset(420, 96)
			done.Font = Enum.Font.GothamBlack
			done.TextScaled = true
			done.TextColor3 = PINK
			done.Text = "POSTED TO THE FLEX WALL\nEveryone in the Grand Ballroom can like it"
			done.ZIndex = 70
			done.Parent = frame
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 14)
			c.Parent = done
			task.wait(1.6)
		end)
		if not ok then
			warn("[Maison] A flex reel: " .. tostring(err))
		end
		screen:Destroy()
		folder:Destroy()
		pcall(function()
			if hudGui then
				hudGui.Enabled = hudWas
			end
		end)
		pcall(function()
			camera.CameraType = if previous == Enum.CameraType.Scriptable then Enum.CameraType.Custom else previous
			local character = Players.LocalPlayer.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end)
		local _ = started
		playing = false
	end)
end

return FlexReel

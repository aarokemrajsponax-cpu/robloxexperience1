--!strict
-- On a guest's first evening: a gold arrow to the Concierge, who shows new guests round the house
-- and teaches them the game. Drawn on the guest's own screen only (nobody else sees any of it):
--   over the Concierge     THE CONCIERGE · "Talk to learn the game", with a gold chevron bobbing
--                          under it (seen through walls, from anywhere in the house)
--   on the floor           three gold chevrons in front of the guest, pointing the way, lit in turn
--   at the screen's edge   a gold arrow when the Concierge is out of view (behind the camera, say)
-- Close to the Concierge the floor arrows go and the line says how to talk ("Press E to talk").
-- It's done when the guest speaks to the Concierge, starts the tour or sits at a table, and it goes
-- by itself after a few minutes (Config.Welcome.guideMinutes).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)

local ConciergeGuide = {}

-- Set by Main: whether the guest is busy (at a table, on the Concierge's tour): the guide is done.
ConciergeGuide.isBusy = function(): boolean
	return false
end

local player = Players.LocalPlayer
local C = Brand.Colours
local CHEVRONS = 3
local ARM = 1.6 -- studs, each arm of a floor chevron
local S45 = math.sin(math.rad(45))

local active = false
local finished = false
local since = 0
local near = false
local concierge: Model? = nil
local folder: Folder? = nil
local billboard: BillboardGui? = nil
local edge: ScreenGui? = nil
local floorArrows: { { BasePart } } = {}
local connections: { RBXScriptConnection } = {}
local floorY: number? = nil
local floorAt = 0
local rayParams: RaycastParams? = nil

local function cfg(): { [string]: any }
	return Config.data.Welcome
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function guestRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function findConcierge(): Model?
	for _, d in Workspace:GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Staff") == "Concierge" then
			return d
		end
	end
	return nil
end

-- Where the Concierge stands (their middle), or nil while they aren't in the house on this screen.
local function conciergeAt(model: Model): Vector3?
	if model.Parent == nil then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.CFrame.Position
	end
	local ok, pivot = pcall(function()
		return model:GetPivot()
	end)
	return if ok then pivot.Position else nil
end

local function talkLine(): string
	local kind = State.inputKind()
	if kind == "touch" then
		return "Tap Speak to talk"
	elseif kind == "gamepad" then
		return "Press X to talk"
	end
	return "Press E to talk"
end

local function bar(parent: Instance, name: string, length: number, thickness: number, centre: Vector2, rotation: number): Frame
	local b = Instance.new("Frame")
	b.Name = name
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = UDim2.fromOffset(centre.X, centre.Y)
	b.Size = UDim2.fromOffset(length, thickness)
	b.Rotation = rotation
	b.BorderSizePixel = 0
	b.BackgroundColor3 = C.brightGold
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, math.floor(thickness / 2))
	corner.Parent = b
	b.Parent = parent
	return b
end

---------------------------------------------------------------------------------------------------
-- Over the Concierge
---------------------------------------------------------------------------------------------------
local function buildBillboard(model: Model): BillboardGui?
	local head = model:FindFirstChild("Head")
	local adornee: BasePart? = if head and head:IsA("BasePart") then head else model.PrimaryPart
	local playerGui = player:FindFirstChild("PlayerGui")
	if not adornee or not playerGui then
		return nil
	end
	local b = Instance.new("BillboardGui")
	b.Name = "MaisonConciergeGuide"
	b.Adornee = adornee
	b.AlwaysOnTop = true
	b.LightInfluence = 0
	b.MaxDistance = 2000
	b.ResetOnSpawn = false
	b.Size = UDim2.fromOffset(260, 112)
	b.StudsOffset = Vector3.new(0, 3.8, 0)
	b.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.fromScale(0.5, 0)
	pill.Size = UDim2.fromOffset(236, 58)
	pill.BackgroundColor3 = C.nearBlack
	pill.BackgroundTransparency = 0.08
	pill.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 29)
	corner.Parent = pill
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.gold
	stroke.Thickness = 1.5
	stroke.Transparency = 0.1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = pill
	pill.Parent = b
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0)
	title.Position = UDim2.new(0.5, 0, 0, 9)
	title.Size = UDim2.new(1, -24, 0, 18)
	title.FontFace = Brand.Fonts.display
	title.TextSize = 15
	title.Text = "THE CONCIERGE"
	title.TextColor3 = Color3.new(1, 1, 1)
	local metal = Instance.new("UIGradient")
	metal.Rotation = 90
	metal.Color = ColorSequence.new(Color3.fromRGB(255, 248, 225), C.gold)
	metal.Parent = title
	title.Parent = pill
	local line = Instance.new("TextLabel")
	line.Name = "Line"
	line.BackgroundTransparency = 1
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.new(0.5, 0, 0, 31)
	line.Size = UDim2.new(1, -24, 0, 17)
	line.FontFace = Brand.Fonts.body
	line.TextSize = 14
	line.Text = "Talk to learn the game"
	line.TextColor3 = C.bone
	line.Parent = pill
	-- The chevron under it, pointing down at the Concierge.
	local chevron = Instance.new("Frame")
	chevron.Name = "Chevron"
	chevron.AnchorPoint = Vector2.new(0.5, 0)
	chevron.Position = UDim2.new(0.5, 0, 0, 68)
	chevron.Size = UDim2.fromOffset(36, 28)
	chevron.BackgroundTransparency = 1
	chevron.Parent = b
	local off = 12 * S45
	bar(chevron, "Left", 24, 6, Vector2.new(18 - off, 25 - off), 45)
	bar(chevron, "Right", 24, 6, Vector2.new(18 + off, 25 - off), -45)
	b.Parent = playerGui
	return b
end

---------------------------------------------------------------------------------------------------
-- On the floor, in front of the guest
---------------------------------------------------------------------------------------------------
local function buildFloor(parent: Instance)
	for i = 1, CHEVRONS do
		local pair: { BasePart } = {}
		for side = 1, 2 do
			local p = Instance.new("Part")
			p.Name = "GuideChevron" .. i .. (if side == 1 then "R" else "L")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Material = Enum.Material.Neon
			p.Color = C.brightGold
			p.Transparency = 1
			p.Size = Vector3.new(0.42, 0.08, ARM)
			p.Parent = parent
			table.insert(pair, p)
		end
		table.insert(floorArrows, pair)
	end
end

local function hideFloor()
	for _, pair in floorArrows do
		for _, p in pair do
			p.Transparency = 1
		end
	end
end

-- The floor under the guest (a ray straight down, now and then; their feet if nothing's found).
local function floorUnder(root: BasePart): number
	local now = os.clock()
	if floorY ~= nil and now - floorAt < 0.25 then
		return floorY :: number
	end
	floorAt = now
	local character = player.Character
	local y: number? = nil
	pcall(function()
		local params = rayParams or RaycastParams.new()
		rayParams = params
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip: { Instance } = {}
		if character then
			table.insert(skip, character)
		end
		if folder then
			table.insert(skip, folder)
		end
		params.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(root.CFrame.Position, Vector3.new(0, -14, 0), params)
		if hit then
			y = hit.Position.Y
		end
	end)
	if y == nil then
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local hip = if humanoid then humanoid.HipHeight else 2
		y = root.CFrame.Position.Y - hip - root.Size.Y / 2
	end
	floorY = y
	return y :: number
end

local function placeFloor(root: BasePart, direction: Vector3, t: number, still: boolean)
	local y = floorUnder(root) + 0.06
	local at = root.CFrame.Position
	local from = Vector3.new(at.X, y, at.Z)
	local base = CFrame.lookAt(from, from + direction)
	for i, pair in floorArrows do
		local tip = base * CFrame.new(0, 0, -(2.6 + (i - 1) * 1.5))
		local half = ARM / 2
		pair[1].CFrame = tip * CFrame.new(half * S45, 0, half * S45) * CFrame.Angles(0, math.rad(45), 0)
		pair[2].CFrame = tip * CFrame.new(-half * S45, 0, half * S45) * CFrame.Angles(0, math.rad(-45), 0)
		-- (Lit in turn, nearest first, like lights along a runway; steady with Movement: Still.)
		local glow = if still then 0.65 else 0.5 + 0.5 * math.sin(t * 5 - i * 1.2)
		for _, p in pair do
			p.Transparency = 0.62 - 0.5 * glow
		end
	end
end

---------------------------------------------------------------------------------------------------
-- At the screen's edge
---------------------------------------------------------------------------------------------------
local function buildEdge(): ScreenGui?
	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return nil
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MaisonGuideEdge"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 19
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local arrow = Instance.new("Frame")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(56, 56)
	arrow.BackgroundTransparency = 1
	arrow.Visible = false
	arrow.Parent = gui
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromOffset(48, 48)
	disc.BackgroundColor3 = C.nearBlack
	disc.BackgroundTransparency = 0.15
	disc.BorderSizePixel = 0
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = disc
	local ring = Instance.new("UIStroke")
	ring.Color = C.gold
	ring.Thickness = 2
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = disc
	disc.Parent = arrow
	-- A chevron pointing right; the whole arrow turns towards the Concierge.
	local off = 9 * S45
	bar(arrow, "Upper", 18, 5, Vector2.new(34 - off, 28 - off), 45)
	bar(arrow, "Lower", 18, 5, Vector2.new(34 - off, 28 + off), -45)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Size = UDim2.fromOffset(150, 14)
	label.BackgroundTransparency = 1
	label.FontFace = Brand.Fonts.display
	label.TextSize = 11
	label.Text = "THE CONCIERGE"
	label.TextColor3 = C.lightGold
	label.TextStrokeTransparency = 0.5
	label.Visible = false
	label.Parent = gui
	gui.Parent = playerGui
	return gui
end

local function placeEdge(target: Vector3)
	local gui = edge
	local camera = Workspace.CurrentCamera
	if not gui or not camera then
		return
	end
	local arrow = gui:FindFirstChild("Arrow") :: Frame?
	local label = gui:FindFirstChild("Label") :: TextLabel?
	if not arrow or not label then
		return
	end
	local ok, point, visible = pcall(function()
		local p, v = camera:WorldToViewportPoint(target)
		return p, v
	end)
	if not ok or typeof(point) ~= "Vector3" then
		arrow.Visible = false
		label.Visible = false
		return
	end
	local behind = point.Z < 0
	if visible and not behind then
		-- (In view: the chevron over the Concierge shows the way.)
		arrow.Visible = false
		label.Visible = false
		return
	end
	local vp = camera.ViewportSize
	local centre = vp / 2
	local d = Vector2.new(point.X, point.Y) - centre
	if behind then
		d = -d
	end
	if d.Magnitude < 1 then
		d = Vector2.new(0, 1)
	end
	local margin = 70
	local kx = if math.abs(d.X) > 1e-3 then (centre.X - margin) / math.abs(d.X) else math.huge
	local ky = if math.abs(d.Y) > 1e-3 then (centre.Y - margin) / math.abs(d.Y) else math.huge
	local at = centre + d * math.min(kx, ky)
	arrow.Position = UDim2.fromOffset(at.X, at.Y)
	arrow.Rotation = math.deg(math.atan2(d.Y, d.X))
	arrow.Visible = true
	label.Position = UDim2.fromOffset(at.X, at.Y + 32)
	label.Visible = true
end

---------------------------------------------------------------------------------------------------
-- Start and stop
---------------------------------------------------------------------------------------------------
local function setNear(isNear: boolean)
	near = isNear
	local b = billboard
	local pill = b and b:FindFirstChild("Pill")
	local line = pill and pill:FindFirstChild("Line")
	if line and line:IsA("TextLabel") then
		line.Text = if isNear then talkLine() else "Talk to learn the game"
	end
	if isNear then
		hideFloor()
	end
end

local function step(_dt: number)
	if not active then
		return
	end
	if ConciergeGuide.isBusy() then
		ConciergeGuide.stop("busy")
		return
	end
	if os.clock() - since > (tonumber(cfg().guideMinutes) or 3) * 60 then
		ConciergeGuide.stop("time")
		return
	end
	local model = concierge
	local target = model and conciergeAt(model)
	local root = guestRoot()
	if not target then
		hideFloor()
		return
	end
	local t = os.clock()
	local still = State.get("movement") == "Still"
	local b = billboard
	local chevron = b and b:FindFirstChild("Chevron")
	if chevron and chevron:IsA("Frame") then
		chevron.Position = UDim2.new(0.5, 0, 0, 68 + (if still then 0 else math.sin(t * 4) * 5))
	end
	placeEdge(target)
	if not root then
		hideFloor()
		return
	end
	local apart = flat(target - root.CFrame.Position)
	local isNear = apart.Magnitude <= (tonumber(cfg().guideNearStuds) or 16)
	if isNear ~= near then
		setNear(isNear)
	end
	if not isNear and apart.Magnitude > 0.1 then
		placeFloor(root, apart.Unit, t, still)
	end
end

function ConciergeGuide.active(): boolean
	return active
end

-- Starts the guide (once a session). Returns whether it started.
function ConciergeGuide.start(): boolean
	if active or finished or cfg().guide ~= true or ConciergeGuide.isBusy() then
		return false
	end
	local model = findConcierge()
	if not model then
		-- (The Concierge may not be in the house on this screen yet: a few more looks.)
		task.spawn(function()
			for _ = 1, 15 do
				task.wait(1)
				if active or finished then
					return
				end
				if findConcierge() then
					ConciergeGuide.start()
					return
				end
			end
		end)
		return false
	end
	active = true
	since = os.clock()
	near = false
	concierge = model
	local f = Instance.new("Folder")
	f.Name = "MaisonConciergeGuide"
	f.Parent = Workspace.CurrentCamera or Workspace
	folder = f
	buildFloor(f)
	billboard = buildBillboard(model)
	edge = buildEdge()
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt: number)
			-- (Anything wrong with it: the arrow goes, said once, never a fault every frame.)
			local message = ""
			local ok = xpcall(step, function(e: any)
				message = tostring(e)
			end, dt)
			if not ok then
				warn("[Maison] The arrow to the Concierge stopped: " .. message)
				ConciergeGuide.stop()
			end
		end)
	)
	-- Speaking to the Concierge: that's what the arrow was for.
	local ok, conn = pcall(function()
		return ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
			local m = concierge
			if active and m and prompt:IsDescendantOf(m) then
				ConciergeGuide.stop("spoke")
			end
		end)
	end)
	if ok and conn then
		table.insert(connections, conn)
	end
	return true
end

-- Ends the guide: "spoke" (the guest spoke to the Concierge: a little flourish), "busy" (at a
-- table, on the tour), "time", or nil (quietly).
function ConciergeGuide.stop(reason: string?)
	if not active then
		return
	end
	active = false
	finished = true
	for _, c in connections do
		c:Disconnect()
	end
	table.clear(connections)
	local f = folder
	folder = nil
	if f then
		f:Destroy()
	end
	table.clear(floorArrows)
	local e = edge
	edge = nil
	if e then
		e:Destroy()
	end
	local b = billboard
	billboard = nil
	if b then
		if reason == "spoke" or reason == "time" then
			for _, d in b:GetDescendants() do
				if d:IsA("TextLabel") then
					tween(d, 0.4, { TextTransparency = 1 })
				elseif d:IsA("Frame") then
					tween(d, 0.4, { BackgroundTransparency = 1 })
				elseif d:IsA("UIStroke") then
					tween(d, 0.4, { Transparency = 1 })
				end
			end
			if reason == "spoke" then
				tween(b, 0.4, { Size = UDim2.fromOffset(300, 130) }, Enum.EasingStyle.Back)
				pcall(Sound.play, "chime", 0.3, 1.5)
			end
			task.delay(0.5, function()
				b:Destroy()
			end)
		else
			b:Destroy()
		end
	end
	concierge = nil
	floorY = nil
end

return ConciergeGuide

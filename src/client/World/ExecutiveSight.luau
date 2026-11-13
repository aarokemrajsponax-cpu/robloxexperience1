--!strict
-- The Executive Suite's eyes, on this guest's screen (Build 81): where every camera and every guard
-- in the hallway is looking, drawn exactly as the server judges it (shared/Executive.inSight: in
-- range, inside the angle, and no wall between; only the hallway's walls, the maze's partitions and
-- the vault door block sight). From each eye a red laser, and on the floor what it sees, cut off
-- by the walls; the cameras' heads turned where they look. While a decoy is out, every eye is on
-- the decoy. The Scanner (gear) marks every guard and every code terminal through the walls.
-- Drawn only while this guest is in the hallway, and only near them. Nothing here decides anything:
-- the server alone says who is seen.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Config = require(ReplicatedStorage.Shared.Config)
local Plan = require(ReplicatedStorage.Shared.Executive)

local ExecutiveSight = {}

local RAYS = 7
local RED = Color3.fromRGB(255, 52, 60)
local HOT = Color3.fromRGB(255, 150, 110)
local MARK = Color3.fromRGB(90, 255, 180)
local FLOOR_Y = 0.14 -- (just over the floor and its runner)
local RAY_Y = 2.6 -- (where the floor's sight is cut by the walls: under every partition's top)
local NEAR = 90 -- drawn only this near the guest
local STEP = 1 / 30
local FLOOR_FADE = 0.8
local LASER_FADE = 0.25

type Eye = { laser: Part, wedges: { WedgePart }, shown: boolean }

local folder: Folder? = nil
local eyes: { [string]: Eye } = {}
local status: { [string]: any } = {}
local decoy: { at: Vector3, untilAt: number }? = nil
local read: { [number]: boolean } = {}
local marks: { Instance } = {}
local marked = false
local acc = 0

local function now(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

local function player(): Player
	return Players.LocalPlayer
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function holder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "ExecutiveSight"
	made.Parent = Workspace
	folder = made
	return made
end

local function bare(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = RED
end

local function eyeFor(id: string): Eye
	local e = eyes[id]
	if e then
		return e
	end
	local laser = Instance.new("Part")
	laser.Name = id .. "Laser"
	bare(laser)
	laser.Size = Vector3.new(0.12, 0.12, 1)
	laser.Transparency = 1
	laser.Parent = holder()
	local wedges = {}
	for i = 1, (RAYS - 1) * 2 do
		local w = Instance.new("WedgePart")
		w.Name = id .. "Sight"
		bare(w)
		w.Transparency = 1
		w.Parent = holder()
		wedges[i] = w
	end
	local made: Eye = { laser = laser, wedges = wedges, shown = false }
	eyes[id] = made
	return made
end

local function hide(e: Eye)
	if not e.shown then
		return
	end
	e.shown = false
	e.laser.Transparency = 1
	for _, w in e.wedges do
		w.Transparency = 1
	end
end

-- The suite on this screen: its model, what blocks sight, and how far and wide its eyes see.
local function suite(): Model?
	for _, lens in CollectionService:GetTagged("ExecCamera") do
		local m = lens:FindFirstAncestor("ExecutiveSuite")
		if m and m:IsA("Model") then
			return m
		end
	end
	return nil
end

local function figure(model: Model, name: string, fallback: number): number
	local v = model:GetAttribute(name)
	if type(v) == "number" then
		return v
	end
	local c = (Config.data :: any).Attractions
	local e = c and c.executive
	local key = string.lower(string.sub(name, 1, 1)) .. string.sub(name, 2)
	return if e and type(e[key]) == "number" then e[key] else fallback
end

-- One eye drawn: its laser, and its sight on the floor (cut off at the walls).
local function draw(e: Eye, eye: Vector3, look: Vector3, range: number, angle: number, params: RaycastParams, floorY: number, me: Vector3?)
	local from = Vector3.new(eye.X, floorY + RAY_Y, eye.Z)
	local function reach(dir: Vector3): number
		local hit = Workspace:Raycast(from, dir * range, params)
		return if hit then (hit.Position - from).Magnitude else range
	end
	local pts = Plan.sightFan(look, range, angle, RAYS, reach)
	local centre = Vector3.new(eye.X, floorY + FLOOR_Y, eye.Z)
	-- Hotter when it's this guest it has in sight (as the server says).
	local onMe = false
	if me and status.seen ~= nil and Plan.inSight(eye, look, range, angle, me) then
		local hit = Workspace:Raycast(eye, me - eye, params)
		onMe = hit == nil
	end
	local colour = if onMe then HOT else RED
	for k = 1, RAYS - 1 do
		local w1, w2 = e.wedges[k * 2 - 1], e.wedges[k * 2]
		local cf1, s1, cf2, s2 = Plan.wedges(centre, centre + pts[k], centre + pts[k + 1], 0.05)
		if cf1 and s1 and cf2 and s2 then
			w1.CFrame, w1.Size = cf1, s1
			w2.CFrame, w2.Size = cf2, s2
			w1.Transparency, w2.Transparency = FLOOR_FADE, FLOOR_FADE
			w1.Color, w2.Color = colour, colour
		else
			w1.Transparency, w2.Transparency = 1, 1
		end
	end
	-- The laser: from the eye to where its middle ray meets the floor or a wall.
	local mid = pts[(RAYS + 1) // 2]
	local target = centre + mid
	local length = (target - eye).Magnitude
	if length > 0.5 then
		e.laser.Size = Vector3.new(0.12, 0.12, length)
		e.laser.CFrame = CFrame.lookAt((eye + target) / 2, target)
		e.laser.Transparency = LASER_FADE
		e.laser.Color = colour
	else
		e.laser.Transparency = 1
	end
	e.shown = true
end

local function clearMarks()
	for _, m in marks do
		m:Destroy()
	end
	marks = {}
	marked = false
end

-- The Scanner: every guard and every terminal marked through the walls.
local function scanner(model: Model)
	local gear = status.gear
	local want = type(gear) == "table" and gear.scanner == true
	if not want then
		if marked then
			clearMarks()
		end
		return
	end
	if marked then
		-- (The terminals' marks follow what's been read.)
		for _, m in marks do
			if m:IsA("BillboardGui") then
				local n = m:GetAttribute("Terminal")
				local label = m:FindFirstChild("Number")
				if type(n) == "number" and label and label:IsA("TextLabel") then
					label.Text = if read[n] then "✓" else tostring(n)
				end
			end
		end
		return
	end
	marked = true
	local actors = model:FindFirstChild("Actors")
	local figures: { Instance } = if actors then actors:GetChildren() else {}
	for _, a in figures do
		if a:IsA("Model") and string.sub(a.Name, 1, 9) == "HallGuard" then
			local h = Instance.new("Highlight")
			h.Name = "ScannerMark"
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.FillColor = RED
			h.FillTransparency = 0.65
			h.OutlineColor = HOT
			h.OutlineTransparency = 0
			h.Parent = a
			table.insert(marks, h)
		end
	end
	for _, screen in CollectionService:GetTagged("ExecTerminal") do
		if screen:IsA("BasePart") and screen:IsDescendantOf(model) then
			local n = screen:GetAttribute("Terminal")
			local b = Instance.new("BillboardGui")
			b.Name = "ScannerMark"
			b.AlwaysOnTop = true
			b.LightInfluence = 0
			b.Size = UDim2.fromOffset(44, 44)
			b.StudsOffset = Vector3.new(0, 2.6, 0)
			b.Adornee = screen
			b:SetAttribute("Terminal", n)
			local label = Instance.new("TextLabel")
			label.Name = "Number"
			label.BackgroundColor3 = Color3.fromRGB(10, 16, 14)
			label.BackgroundTransparency = 0.2
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = MARK
			label.Text = if type(n) == "number" and read[n] then "✓" else tostring(n or "")
			label.Parent = b
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.5, 0)
			corner.Parent = label
			local stroke = Instance.new("UIStroke")
			stroke.Color = MARK
			stroke.Thickness = 2
			stroke.Parent = label
			b.Parent = player():FindFirstChildOfClass("PlayerGui") or holder()
			table.insert(marks, b)
		end
	end
end

local function hideAll()
	for _, e in eyes do
		hide(e)
	end
end

function ExecutiveSight.step()
	local character = player().Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local origin = AttractionList.origin("executive")
	local here = root and root:IsA("BasePart") and AttractionList.areaAt(root.CFrame.Position) == "executive" and Plan.inHall(root.CFrame.Position - origin)
	local model = if here then suite() else nil
	if not model or not root or not root:IsA("BasePart") then
		hideAll()
		if marked then
			clearMarks()
		end
		return
	end
	local me = root.CFrame.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local blockers: { Instance } = {}
	local walls = model:FindFirstChild("SightWalls")
	if walls then
		table.insert(blockers, walls)
	end
	local arch = model:FindFirstChild("Architecture")
	local door = arch and arch:FindFirstChild("CodeDoor")
	if door then
		table.insert(blockers, door)
	end
	params.FilterDescendantsInstances = blockers
	local t = now()
	local d = decoy
	local onDecoy = d ~= nil and t < d.untilAt
	local floorY = origin.Y
	-- The cameras: their heads turned where they look, and their sight.
	local camRange, camAngle = figure(model, "CameraRange", 40), figure(model, "CameraAngle", 30)
	for _, lens in CollectionService:GetTagged("ExecCamera") do
		local i = lens:GetAttribute("Camera")
		local plan = if type(i) == "number" then Plan.Cameras[i] else nil
		if plan and lens:IsA("BasePart") and lens:IsDescendantOf(model) then
			local eye = lens.CFrame.Position
			local look = if onDecoy and d then flat(d.at - eye) else Plan.cameraLook(plan, t)
			if look.Magnitude > 1e-3 then
				lens.CFrame = CFrame.lookAt(eye, eye + look.Unit)
				local red = lens:FindFirstChild("Eye")
				if red and red:IsA("BasePart") then
					red.CFrame = lens.CFrame * CFrame.new(0, 0, -0.8)
				end
			end
			local e = eyeFor("camera" .. tostring(i))
			if (flat(eye - me)).Magnitude > NEAR then
				hide(e)
			else
				draw(e, eye, look, camRange, camAngle, params, floorY, me)
			end
		end
	end
	-- The guards: from their eyes, where they face.
	local guardRange, guardAngle = figure(model, "GuardRange", 26), figure(model, "GuardAngle", 55)
	local actors = model:FindFirstChild("Actors")
	local figures: { Instance } = if actors then actors:GetChildren() else {}
	for _, a in figures do
		if a:IsA("Model") and string.sub(a.Name, 1, 9) == "HallGuard" then
			local groot = a:FindFirstChild("HumanoidRootPart") or a.PrimaryPart
			if groot and groot:IsA("BasePart") then
				local eye = groot.CFrame.Position + Vector3.new(0, 1.5, 0)
				local look = if onDecoy and d then flat(d.at - eye) else groot.CFrame.LookVector
				local e = eyeFor(a.Name)
				if (flat(eye - me)).Magnitude > NEAR then
					hide(e)
				else
					draw(e, eye, look, guardRange, guardAngle, params, floorY, me)
				end
			end
		end
	end
	scanner(model)
end

-- What the server last said of this guest's run (UI/ExecutiveHud passes it on).
function ExecutiveSight.status(m: { [string]: any })
	status = m
end

-- A decoy thrown: every eye on it while it lasts.
function ExecutiveSight.decoy(at: Vector3, seconds: number)
	decoy = { at = at, untilAt = now() + seconds }
end

-- A terminal read (the Scanner's mark shows it).
function ExecutiveSight.digit(n: number)
	read[n] = true
end

-- Leaving the Suite: nothing left drawn, nothing remembered for the next run.
function ExecutiveSight.reset()
	status = {}
	decoy = nil
	read = {}
	clearMarks()
	hideAll()
end

function ExecutiveSight.start()
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < STEP then
			return
		end
		acc = 0
		local ok, err = pcall(function()
			ExecutiveSight.step()
		end)
		if not ok then
			warn("[Maison] The Suite's eyes: " .. tostring(err))
		end
	end)
end

return ExecutiveSight

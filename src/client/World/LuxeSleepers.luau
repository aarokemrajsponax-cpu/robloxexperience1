--!strict
-- Steal a Luxe's night staff on this screen (Build 89): each posed as the server says they are
-- (asleep, stirring, waking, awake, dozing: the "Sleep" attribute, from "SleepAt" by the server's
-- clock), every frame, by turning the rig's own joints (Motor6D.Transform: what an animation turns)
-- to shared/SleepPose's pose, so they really sit, slump and lie, breathe, turn over, sit up,
-- stretch, get to their feet, look round and settle back down, smoothly. How far each is let down
-- onto their chair or bed is measured from the rig itself the first time it's seen standing.
-- Over each head: a slow "z z z" while asleep (amber while they stir), a bell while they call
-- for the guards. Only near the camera; nothing here decides anything.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local SleepPose = require(ReplicatedStorage.Shared.SleepPose)

local LuxeSleepers = {}

local NEAR = 160 -- studs from the camera: further off, left as they are
local MOTORS = { "Root", "Waist", "Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow", "LeftHip", "RightHip", "LeftKnee", "RightKnee" }

type Tracked = { model: Model, motors: { [string]: Motor6D }, drops: SleepPose.Drops?, mark: BillboardGui?, label: TextLabel?, was: string? }
local tracked: { [Model]: Tracked } = {}

local function now(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

local function motorsOf(model: Model): { [string]: Motor6D }
	local out: { [string]: Motor6D } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and table.find(MOTORS, d.Name) then
			out[d.Name] = d
		end
	end
	return out
end

local function yOf(m: Motor6D): number?
	local p0 = m.Part0
	if not p0 then
		return nil
	end
	return (p0.CFrame * m.C0).Position.Y
end

-- How far this rig is let down for each seat and the bed, from its own size, measured standing.
function LuxeSleepers.measure(model: Model, motors: { [string]: Motor6D }): SleepPose.Drops?
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local hip = motors.LeftHip
	local rootJoint = motors.Root
	if not (root and root:IsA("BasePart") and humanoid and hip and rootJoint) then
		return nil
	end
	local thigh = hip.Part1
	local lower = rootJoint.Part1
	local hipY, rootY = yOf(hip), yOf(rootJoint)
	if not (thigh and lower and hipY and rootY) then
		return nil
	end
	local ground = root.CFrame.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local thighHalf = thigh.Size.Z / 2
	local drops: SleepPose.Drops = {}
	for seat, top in SleepPose.SEAT do
		drops[seat] = math.max(0, hipY - (ground + top + thighHalf))
	end
	drops.lie = math.max(0, rootY - (ground + SleepPose.BED_TOP + lower.Size.Z / 2 + 0.05))
	drops.bedSit = math.max(0, hipY - (ground + SleepPose.BED_TOP + thighHalf))
	return drops
end

local function markOver(t: Tracked)
	local head = t.model:FindFirstChild("Head")
	if not (head and head:IsA("BasePart")) or t.mark then
		return
	end
	local b = Instance.new("BillboardGui")
	b.Name = "SleepMark"
	b.Size = UDim2.fromOffset(70, 34)
	b.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	b.MaxDistance = 60
	b.LightInfluence = 0
	b.AlwaysOnTop = false
	b.Parent = head
	local l = Instance.new("TextLabel")
	l.Name = "Mark"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.FontFace = Brand.Fonts.display
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(220, 230, 255)
	l.TextStrokeTransparency = 0.6
	l.Text = "z z z"
	l.Parent = b
	t.mark, t.label = b, l
end

local function add(model: Instance)
	if not model:IsA("Model") or tracked[model] then
		return
	end
	local t: Tracked = { model = model, motors = motorsOf(model), drops = nil, mark = nil, label = nil, was = nil }
	tracked[model] = t
	pcall(markOver, t)
end

-- (For tests, and the start: one more to pose.)
LuxeSleepers.add = add

local function remove(model: Instance)
	if model:IsA("Model") then
		tracked[model] = nil
	end
end

local lastScan = -math.huge

-- One frame: every sleeper near the camera, posed.
function LuxeSleepers.step(at: Vector3?)
	local t0 = now()
	-- (Every couple of seconds, any streamed in since that no signal told of.)
	if os.clock() - lastScan > 2 then
		lastScan = os.clock()
		for _, m in CollectionService:GetTagged("LuxeSleeper") do
			add(m)
		end
	end
	for model, t in tracked do
		if not model.Parent then
			tracked[model] = nil
			continue
		end
		local root = model:FindFirstChild("HumanoidRootPart")
		if not (root and root:IsA("BasePart")) then
			continue
		end
		if at and (root.CFrame.Position - at).Magnitude > NEAR then
			continue
		end
		if next(t.motors) == nil then
			t.motors = motorsOf(model)
		end
		if not t.drops and next(t.motors) ~= nil then
			t.drops = LuxeSleepers.measure(model, t.motors)
		end
		local state = tostring(model:GetAttribute("Sleep") or "asleep")
		local since = math.max(0, t0 - (tonumber(model:GetAttribute("SleepAt")) or t0))
		local lasts = tonumber(model:GetAttribute("SleepFor")) or (if state == "waking" then 1.6 else 2.4)
		local stir = tonumber(model:GetAttribute("Stir")) or 0
		local calling = model:GetAttribute("Calling") ~= nil
		local drops = t.drops or {}
		local pose = SleepPose.pose(tostring(model:GetAttribute("Pose") or "chair"), state, since, lasts, stir, calling and state == "awake", drops)
		for name, motor in t.motors do
			if name == "Root" then
				motor.Transform = SleepPose.root(pose, drops)
			else
				local turn = pose.j[name]
				motor.Transform = if turn then SleepPose.turn(turn) else CFrame.identity
			end
		end
		-- (Over the head: z z z asleep, amber while stirring, a bell while calling.)
		local l = t.label
		if l then
			local show = if state == "asleep" or state == "stirring" then "z z z" elseif calling and state == "awake" then "🔔" else ""
			if l.Text ~= show then
				l.Text = show
			end
			l.TextColor3 = if state == "stirring" then Color3.fromRGB(255, 196, 90) else Color3.fromRGB(220, 230, 255)
			l.TextTransparency = if show == "z z z" then 0.25 + 0.35 * (0.5 + 0.5 * math.sin(t0 * 1.6)) else 0
		end
		t.was = state
	end
end

-- Who's nearest this point and stirring (for the HUD's warning): their name and how stirred.
function LuxeSleepers.restless(at: Vector3, within: number): (string?, number)
	local best, bestStir, bestGap = nil, 0, within
	for model in tracked do
		local root = model:FindFirstChild("HumanoidRootPart")
		local state = model:GetAttribute("Sleep")
		if root and root:IsA("BasePart") and (state == "stirring" or state == "waking") then
			local gap = (root.CFrame.Position - at).Magnitude
			if gap < bestGap then
				best, bestStir, bestGap = tostring(model:GetAttribute("Who") or "someone"), tonumber(model:GetAttribute("Stir")) or 0, gap
			end
		end
	end
	return best, bestStir
end

function LuxeSleepers.start()
	for _, m in CollectionService:GetTagged("LuxeSleeper") do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("LuxeSleeper"):Connect(add)
	CollectionService:GetInstanceRemovedSignal("LuxeSleeper"):Connect(remove)
	-- (After the frame's animations: what this sets is what's drawn.)
	RunService.Stepped:Connect(function()
		local cam = Workspace.CurrentCamera
		pcall(LuxeSleepers.step, if cam then cam.CFrame.Position else nil)
	end)
end

return LuxeSleepers

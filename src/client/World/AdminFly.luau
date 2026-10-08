--!strict
-- The owner's flight (House controls → Powers → Fly). Only the server switches it on, and only
-- for the owner (the attribute "AdminFly"); this screen does the flying: the way the camera looks,
-- at Config.Admin.flySpeed, with Space (or E) to rise and Q (or Ctrl) to sink. On a phone, the
-- thumbstick flies where the camera points.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local AdminFly = {}

local player = Players.LocalPlayer

type Flight = { att: Attachment, vel: LinearVelocity, align: AlignOrientation, humanoid: Humanoid }
local flight: Flight? = nil

local function stop()
	local f = flight
	if not f then
		return
	end
	flight = nil
	f.vel:Destroy()
	f.align:Destroy()
	f.att:Destroy()
	pcall(function()
		f.humanoid.PlatformStand = false
		f.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end)
end

local function start()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return
	end
	stop()
	local att = Instance.new("Attachment")
	att.Name = "AdminFly"
	att.Parent = root
	local vel = Instance.new("LinearVelocity")
	vel.Name = "AdminFlyVelocity"
	vel.Attachment0 = att
	vel.MaxForce = math.huge
	vel.RelativeTo = Enum.ActuatorRelativeTo.World
	vel.VectorVelocity = Vector3.zero
	vel.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "AdminFlyAlign"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = att
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.CFrame = root.CFrame
	align.Parent = root
	humanoid.PlatformStand = true
	flight = { att = att, vel = vel, align = align, humanoid = humanoid }
end

-- The stick or keys, as a direction: x right, z back (the player's controls, else the humanoid's).
local controls: any = nil
local function moveVector(f: Flight): Vector3
	if controls == nil then
		local ok, c = pcall(function()
			local module = player:FindFirstChild("PlayerScripts") and (player :: any).PlayerScripts:FindFirstChild("PlayerModule")
			return if module then (require(module) :: any):GetControls() else false
		end)
		controls = if ok and c then c else false
	end
	if controls then
		local ok, v = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(v) == "Vector3" then
			return v
		end
	end
	-- (The humanoid's own direction, turned into the camera's frame.)
	local camera = Workspace.CurrentCamera
	local d = f.humanoid.MoveDirection
	return Vector3.new(d:Dot(camera.CFrame.RightVector), 0, -d:Dot(camera.CFrame.LookVector))
end

local function step()
	local f = flight
	if not f then
		return
	end
	local camera = Workspace.CurrentCamera
	local move = moveVector(f)
	local v = camera.CFrame.LookVector * -move.Z + camera.CFrame.RightVector * move.X
	local up = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
		up += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.Q) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
		up -= 1
	end
	v += Vector3.new(0, up, 0)
	local speed = Config.data.Admin.flySpeed
	f.vel.VectorVelocity = if v.Magnitude > 1e-3 then v.Unit * speed * math.min(1, v.Magnitude) else Vector3.zero
	local flat = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if flat.Magnitude > 1e-3 then
		f.align.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
	end
end

local function refresh()
	if player:GetAttribute("AdminFly") == true then
		if not flight then
			start()
		end
	else
		stop()
	end
end

function AdminFly.flying(): boolean
	return flight ~= nil
end

function AdminFly.start()
	player:GetAttributeChangedSignal("AdminFly"):Connect(refresh)
	player.CharacterAdded:Connect(function()
		flight = nil
		task.delay(1, refresh)
	end)
	RunService.RenderStepped:Connect(function()
		if flight then
			pcall(step)
		end
	end)
	refresh()
end

return AdminFly

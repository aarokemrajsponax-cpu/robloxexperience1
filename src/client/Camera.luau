--!strict
-- The camera composes shots: a slow drift along the façade under the title, an eased handoff
-- behind your avatar, a composed three-quarter view of the table, and back again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)

local CameraRig = {}

local player = Players.LocalPlayer
local driftTween: Tween? = nil
local moveTween: Tween? = nil
local tableCentre: Vector3? = nil
local viewportConn: RBXScriptConnection? = nil

local function cam(): Camera
	return Workspace.CurrentCamera :: Camera
end

local function stopTweens()
	if driftTween then
		driftTween:Cancel()
		driftTween = nil
	end
	if moveTween then
		moveTween:Cancel()
		moveTween = nil
	end
end

-- Tweens the camera's CFrame through a proxy value (Camera.CFrame can be tweened directly,
-- but a proxy lets the movement setting shorten every glide in one place).
local function glide(goal: CFrame, info: TweenInfo): Tween
	local c = cam()
	c.CameraType = Enum.CameraType.Scriptable
	local t = TweenService:Create(c, Ease.scaled(info), { CFrame = goal })
	moveTween = t
	t:Play()
	return t
end

function CameraRig.titleDrift()
	stopTweens()
	local shot = Layout.Street.titleShot
	local c = cam()
	c.CameraType = Enum.CameraType.Scriptable
	c.FieldOfView = 60
	c.CFrame = shot.from
	local t = TweenService:Create(c, TweenInfo.new(shot.seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { CFrame = shot.to })
	driftTween = t
	t:Play()
end

local function behindAvatar(): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.01 then
		flat = Vector3.new(0, 0, 1)
	end
	flat = flat.Unit
	local focus = root.Position + Vector3.new(0, 2, 0)
	local eye = focus - flat * 12 + Vector3.new(0, 4, 0)
	return CFrame.lookAt(eye, focus + flat * 2)
end

-- Eases down behind the avatar, then hands the camera back to Roblox's follow camera.
function CameraRig.handoff(seconds: number?): ()
	stopTweens()
	local c = cam()
	c.FieldOfView = 70
	local goal = behindAvatar()
	if goal then
		local t = glide(goal, TweenInfo.new(seconds or 1.6, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut))
		t.Completed:Wait()
	end
	CameraRig.follow()
end

function CameraRig.follow()
	stopTweens()
	local c = cam()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	c.CameraType = Enum.CameraType.Custom
	c.FieldOfView = 70
	if humanoid then
		c.CameraSubject = humanoid
	end
	player.CameraMinZoomDistance = 6
	player.CameraMaxZoomDistance = 20
end

-- A composed view of the table that fits the felt and all six cases on any screen shape.
local function tableShot(centre: Vector3): CFrame
	local c = cam()
	local vp = c.ViewportSize
	local aspect = if vp.Y > 0 then vp.X / vp.Y else 16 / 9
	local vfov = math.rad(c.FieldOfView)
	local hfov = 2 * math.atan(math.tan(vfov / 2) * aspect)
	local T = Layout.Table
	local focus = centre + Vector3.new(0, T.topY, 0.1)
	local halfW = T.width / 2 + 0.2
	local halfD = T.depth / 2 + 0.3
	local dir = Vector3.new(0, 0.9, -0.42).Unit
	-- Depth seen by the camera shrinks with the tilt.
	local projectedHalfD = halfD * math.abs(dir.Y)
	local distance = math.max(halfW / math.tan(hfov / 2), projectedHalfD / math.tan(vfov / 2)) * 1.08
	distance = math.clamp(distance, 9, 34)
	local eye = focus + dir * distance
	return CFrame.lookAt(eye, focus, Vector3.new(0, 0, 1))
end

function CameraRig.toTable(centre: Vector3)
	stopTweens()
	tableCentre = centre
	local c = cam()
	c.FieldOfView = 50
	glide(tableShot(centre), TweenInfo.new(1.3, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut))
	if viewportConn then
		viewportConn:Disconnect()
	end
	viewportConn = c:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if tableCentre and c.CameraType == Enum.CameraType.Scriptable then
			c.CFrame = tableShot(tableCentre)
		end
	end)
end

function CameraRig.leaveTable()
	tableCentre = nil
	if viewportConn then
		viewportConn:Disconnect()
		viewportConn = nil
	end
	CameraRig.handoff(1.1)
end

function CameraRig.isAtTable(): boolean
	return tableCentre ~= nil
end

-- A gentle camera that follows the avatar with a little weight while walking.
local lagged: CFrame? = nil
RunService:BindToRenderStep("MaisonCameraWeight", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local c = cam()
	if c.CameraType ~= Enum.CameraType.Custom then
		lagged = nil
		return
	end
	local target = c.CFrame
	if lagged == nil then
		lagged = target
		return
	end
	-- Only smooth position, and only a touch, so it never feels floaty or clips.
	local alpha = 1 - math.exp(-dt * 22)
	local pos = (lagged :: CFrame).Position:Lerp(target.Position, alpha)
	if (pos - target.Position).Magnitude > 2 then
		pos = target.Position
	end
	lagged = CFrame.new(pos) * target.Rotation
	c.CFrame = lagged :: CFrame
end)

return CameraRig

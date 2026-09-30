--!strict
-- The camera composes shots: a slow drift along the façade under the title, an eased handoff
-- behind your avatar, a composed three-quarter view of the table, and back again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)

local CameraRig = {}

local player = Players.LocalPlayer
local driftTween: Tween? = nil
local moveTween: Tween? = nil
local tableCentre: CFrame? = nil
local tableWide = false
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
	-- Roblox's usual freedom: zoom right in to first person, or out to see the room.
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 40
end

-- A composed view of the table that fits the felt and all six cases on any screen shape. The
-- wide shot (the Library) also takes in the rival's cases and the near edge of their felt.
local function tableShot(frame: CFrame, wide: boolean?): CFrame
	local c = cam()
	local vp = c.ViewportSize
	local aspect = if vp.Y > 0 then vp.X / vp.Y else 16 / 9
	local vfov = math.rad(c.FieldOfView)
	local hfov = 2 * math.atan(math.tan(vfov / 2) * aspect)
	local T = Layout.Table
	local focus = frame:PointToWorldSpace(Vector3.new(0, T.topY, if wide then 1.3 else 0.1))
	local halfW = T.width / 2 + 0.2
	local halfD = T.depth / 2 + (if wide then 1.8 else 0.3)
	local dir = frame:VectorToWorldSpace(Vector3.new(0, 0.9, -0.42).Unit)
	-- Depth seen by the camera shrinks with the tilt.
	local projectedHalfD = halfD * math.abs(dir.Y)
	local distance = math.max(halfW / math.tan(hfov / 2), projectedHalfD / math.tan(vfov / 2)) * 1.08
	distance = math.clamp(distance, 9, 34)
	local eye = focus + dir * distance
	return CFrame.lookAt(eye, focus, frame:VectorToWorldSpace(Vector3.new(0, 0, 1)))
end

function CameraRig.toTable(frame: CFrame, wide: boolean?)
	stopTweens()
	tableCentre = frame
	tableWide = wide == true
	local c = cam()
	c.FieldOfView = 50
	glide(tableShot(frame, tableWide), TweenInfo.new(1.3, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut))
	if viewportConn then
		viewportConn:Disconnect()
	end
	viewportConn = c:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if tableCentre and c.CameraType == Enum.CameraType.Scriptable then
			c.CFrame = tableShot(tableCentre, tableWide)
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

-- A held shot (the Ballroom's last lamp from the Gallery): glide there, hold, then glide back to
-- where the camera was (the table, or the follow camera).
local momentId = 0
function CameraRig.moment(shot: CFrame, hold: number)
	momentId += 1
	local id = momentId
	local wasTable = tableCentre
	local wasWide = tableWide
	stopTweens()
	local c = cam()
	c.FieldOfView = 55
	glide(shot, TweenInfo.new(1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut))
	task.delay(1.4 + hold, function()
		if id ~= momentId then
			return
		end
		if wasTable and tableCentre == wasTable then
			CameraRig.toTable(wasTable, wasWide)
		elseif tableCentre == nil then
			CameraRig.handoff(1.2)
		end
	end)
end

-- Watching from the Gallery: a slow drift from one composed shot to the next.
local watchId = 0
function CameraRig.watch(nextShot: () -> CFrame?, every: number)
	watchId += 1
	local id = watchId
	task.spawn(function()
		while id == watchId do
			local shot = nextShot()
			if shot then
				cam().FieldOfView = 50
				glide(shot, TweenInfo.new(math.min(3, every * 0.5), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
			end
			task.wait(every)
		end
	end)
end

function CameraRig.stopWatching()
	watchId += 1
	if tableCentre == nil then
		task.spawn(CameraRig.handoff, 1)
	end
end

-- While walking, the camera is Roblox's own follow camera, untouched: it handles mouse, touch
-- and gamepad, zoom and walls, and stays exactly in step with the avatar.

return CameraRig

--!strict
-- The camera composes shots: a slow drift along the façade under the title, an eased handoff
-- behind your avatar, the sorting camera (a composed, front-on view of the table that fits the
-- felt, every case and the counter on any screen), and back again. Every move eases the field of
-- view with it, so nothing snaps; the way into the sorting camera swings over the chair instead of
-- cutting through the room.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)

local CameraRig = {}

-- Roblox's own follow camera's field of view, which walking always returns to.
local WALK_FOV = 70

local player = Players.LocalPlayer
local driftTween: Tween? = nil
local moveTween: Tween? = nil
local moving = false
local pathValue: NumberValue? = nil
local tableCentre: CFrame? = nil
local tableWide = false
local tableIgnore: { Instance } = {}
local restShot: CFrame? = nil -- where the sorting camera sits between nudges
local restFov = 46
local viewportConn: RBXScriptConnection? = nil
local handoffId = 0
local punchTween: Tween? = nil
local shake = { size = 0, length = 1, untilAt = 0 }

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
	if punchTween then
		punchTween:Cancel()
		punchTween = nil
	end
	local value = pathValue
	pathValue = nil
	if value then
		value:Destroy()
	end
	moving = false
	shake.size = 0
end

local function track(t: Tween)
	moveTween = t
	moving = true
	t.Completed:Once(function()
		if moveTween == t then
			moving = false
		end
	end)
end

-- Tweens the camera's CFrame, and its field of view with it (the movement setting shortens every
-- glide in one place).
local function glide(goal: CFrame, info: TweenInfo, fov: number?): Tween
	local c = cam()
	c.CameraType = Enum.CameraType.Scriptable
	local props: { [string]: any } = { CFrame = goal }
	if fov then
		props.FieldOfView = fov
	end
	local t = TweenService:Create(c, Ease.scaled(info), props)
	track(t)
	t:Play()
	return t
end

-- A move along a gentle curve that keeps its eye on `target` the whole way: the way into the
-- sorting camera. The curve bends up, so the camera rises over the chair and never dips through
-- the furniture between wherever it was and the table.
local function swing(goal: CFrame, target: Vector3, fov: number, seconds: number): Tween
	local c = cam()
	c.CameraType = Enum.CameraType.Scriptable
	local from = c.CFrame
	local fromFov = c.FieldOfView
	local p0, p2 = from.Position, goal.Position
	local fromLook = p0 + from.LookVector * math.max((target - p0).Magnitude, 1)
	local mid = p0:Lerp(p2, 0.5)
	local via = Vector3.new(mid.X, math.max(p0.Y, p2.Y) + 1.5, mid.Z)
	local value = Instance.new("NumberValue")
	value.Value = 0
	pathValue = value
	value.Changed:Connect(function(a: number)
		if pathValue ~= value then
			return
		end
		if a >= 1 then
			c.CFrame = goal
			c.FieldOfView = fov
			return
		end
		local u = 1 - a
		local pos = p0 * (u * u) + via * (2 * u * a) + p2 * (a * a)
		c.CFrame = CFrame.lookAt(pos, fromLook:Lerp(target, a))
		c.FieldOfView = fromFov + (fov - fromFov) * a
	end)
	local t = TweenService:Create(value, Ease.scaled(TweenInfo.new(seconds, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)), { Value = 1 })
	track(t)
	t.Completed:Once(function()
		if pathValue == value then
			pathValue = nil
		end
		value:Destroy()
	end)
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

-- Eases down behind the avatar (the field of view opening back out as it goes), then hands the
-- camera back to Roblox's follow camera.
function CameraRig.handoff(seconds: number?): ()
	stopTweens()
	handoffId += 1
	local id = handoffId
	local goal = behindAvatar()
	if goal then
		local t = glide(goal, TweenInfo.new(seconds or 1.6, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), WALK_FOV)
		t.Completed:Wait()
		if id ~= handoffId or tableCentre ~= nil then
			return -- something else took the camera meanwhile (a table, a moment)
		end
	end
	CameraRig.follow()
end

function CameraRig.follow()
	stopTweens()
	handoffId += 1
	local c = cam()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	c.CameraType = Enum.CameraType.Custom
	if math.abs(c.FieldOfView - WALK_FOV) > 0.5 then
		TweenService:Create(c, Ease.scaled(TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)), { FieldOfView = WALK_FOV }):Play()
	else
		c.FieldOfView = WALK_FOV
	end
	if humanoid then
		c.CameraSubject = humanoid
	end
	-- Roblox's usual freedom: zoom right in to first person, or out to see the room.
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = Config.data.Movement.cameraMaxZoom
end

-- The sorting camera. It looks down the table from above the chair at Layout's camera angle and
-- sits exactly as far back as it needs to for these points to fit the screen with a margin: the
-- felt's corners, the tops of the far cases, and the counter on the near edge. In the Library
-- the wide shot also takes in the rival's cases and the near edge of their felt.
local T = Layout.Table
local FIT_POINTS = {
	Vector3.new(-T.width / 2 + 0.35, T.topY, -T.depth / 2 + 0.35),
	Vector3.new(T.width / 2 - 0.35, T.topY, -T.depth / 2 + 0.35),
	Vector3.new(-T.width / 2 + 0.35, T.topY, T.depth / 2 - 0.35),
	Vector3.new(T.width / 2 - 0.35, T.topY, T.depth / 2 - 0.35),
	Vector3.new(-T.width / 2 + 0.9, T.topY + 0.55, T.caseRowZ + T.caseDepth / 2),
	Vector3.new(T.width / 2 - 0.9, T.topY + 0.55, T.caseRowZ + T.caseDepth / 2),
	Vector3.new(-1.7, T.topY + 0.5, T.counterZ),
	Vector3.new(2.55, T.topY + 0.5, T.counterZ),
}
local WIDE_POINTS = table.clone(FIT_POINTS)
table.insert(WIDE_POINTS, Vector3.new(-T.width / 2 + 0.9, T.topY + 0.55, T.depth - T.caseRowZ + T.caseDepth / 2))
table.insert(WIDE_POINTS, Vector3.new(T.width / 2 - 0.9, T.topY + 0.55, T.depth - T.caseRowZ + T.caseDepth / 2))
table.insert(WIDE_POINTS, Vector3.new(-T.width / 2 + 0.35, T.topY, T.depth - T.feltMaxZ + 0.2))
table.insert(WIDE_POINTS, Vector3.new(T.width / 2 - 0.35, T.topY, T.depth - T.feltMaxZ + 0.2))

local function fitDistance(focusLocal: Vector3, dir: Vector3, points: { Vector3 }, fov: number): number
	local vp = cam().ViewportSize
	local aspect = if vp.Y > 0 then vp.X / vp.Y else 16 / 9
	local ty = math.tan(math.rad(fov) / 2)
	local tx = ty * aspect
	local limit = Config.data.Sorting.frameFill
	-- Worked in the table's own space, where the camera looks straight back along -dir.
	local forward = -dir
	local right = forward:Cross(Vector3.new(0, 1, 0)).Unit
	local up = right:Cross(forward)
	for d = 8, 34, 0.25 do
		local eye = focusLocal + dir * d
		local fits = true
		for _, p in points do
			local v = p - eye
			local z = v:Dot(forward)
			if z <= 0.1 or math.abs(v:Dot(right) / z) > limit * tx or math.abs(v:Dot(up) / z) > limit * ty then
				fits = false
				break
			end
		end
		if fits then
			return d
		end
	end
	return 34
end

-- Pulls the eye in under a low ceiling or in front of a wall (small things, like the next table's
-- lamp, are looked past).
local function clearEye(focus: Vector3, eye: Vector3): Vector3
	local offset = eye - focus
	if offset.Magnitude < 2 then
		return eye
	end
	local unit = offset.Unit
	local ignore = table.clone(tableIgnore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	for _ = 1, 4 do
		local hit = Workspace:Raycast(focus + unit, offset - unit, params)
		if not hit then
			return eye
		end
		local part = hit.Instance
		if part:IsA("BasePart") and part.Size.Magnitude >= 14 then
			return hit.Position - unit * 0.75
		end
		table.insert(ignore, part)
		params.FilterDescendantsInstances = ignore
	end
	return eye
end

-- The shot for the table the guest is seated at: the camera's CFrame, the point it looks at, and
-- how far that is (for the focus).
local function tableShot(frame: CFrame, wide: boolean, fov: number): (CFrame, Vector3, number)
	local focusLocal = Vector3.new(0, T.topY, if wide then 1.6 else 0.3)
	local dir = Layout.towardCamera()
	local distance = fitDistance(focusLocal, dir, if wide then WIDE_POINTS else FIT_POINTS, fov)
	local focus = frame:PointToWorldSpace(focusLocal)
	local eye = clearEye(focus, frame:PointToWorldSpace(focusLocal + dir * distance))
	return CFrame.lookAt(eye, focus, frame:VectorToWorldSpace(Vector3.new(0, 0, 1))), focus, (eye - focus).Magnitude
end

-- Into the sorting camera. From walking it swings round over the chair; from another shot (a
-- moment, a move between tables) it glides. Returns how far the camera sits from the felt.
function CameraRig.toTable(frame: CFrame, wide: boolean?, ignore: { Instance }?): number
	local fromWalking = tableCentre == nil and cam().CameraType ~= Enum.CameraType.Scriptable
	stopTweens()
	handoffId += 1
	local S = Config.data.Sorting
	tableCentre = frame
	tableWide = wide == true
	if ignore then
		tableIgnore = ignore
	end
	restFov = S.cameraFov + (if tableWide then S.wideFovExtra else 0)
	local shot, focus, distance = tableShot(frame, tableWide, restFov)
	restShot = shot
	if fromWalking then
		swing(shot, focus, restFov, S.enterSeconds)
	else
		glide(shot, TweenInfo.new(S.enterSeconds, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), restFov)
	end
	local c = cam()
	if viewportConn then
		viewportConn:Disconnect()
	end
	viewportConn = c:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local centre = tableCentre
		if centre and c.CameraType == Enum.CameraType.Scriptable then
			local again = tableShot(centre, tableWide, restFov)
			restShot = again
			if not moving then
				c.CFrame = again
			end
		end
	end)
	return distance
end

function CameraRig.leaveTable()
	tableCentre = nil
	restShot = nil
	if viewportConn then
		viewportConn:Disconnect()
		viewportConn = nil
	end
	CameraRig.handoff(Config.data.Sorting.leaveSeconds)
end

function CameraRig.isAtTable(): boolean
	return tableCentre ~= nil
end

-- A tiny lean in on a correct filing: the field of view narrows a touch and eases back. Never
-- while the camera is moving, and not with the movement setting turned down.
function CameraRig.punch(degrees: number)
	if tableCentre == nil or moving or degrees <= 0 or Ease.motionScale < 0.5 then
		return
	end
	local c = cam()
	if punchTween then
		punchTween:Cancel()
	end
	local inward = TweenService:Create(c, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = restFov - degrees })
	punchTween = inward
	inward.Completed:Once(function()
		if punchTween ~= inward then
			return
		end
		local back = TweenService:Create(c, TweenInfo.new(0.34, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { FieldOfView = restFov })
		punchTween = back
		back:Play()
	end)
	inward:Play()
end

-- A small, quick shake on a wrong case: felt more than seen. Same rules as the punch.
function CameraRig.shake(size: number, seconds: number)
	if tableCentre == nil or moving or size <= 0 or Ease.motionScale < 0.5 then
		return
	end
	shake.size = size
	shake.length = math.max(seconds, 0.05)
	shake.untilAt = os.clock() + shake.length
end

RunService.RenderStepped:Connect(function()
	if shake.size <= 0 then
		return
	end
	local rest = restShot
	local c = cam()
	if not rest or moving or c.CameraType ~= Enum.CameraType.Scriptable then
		shake.size = 0
		return
	end
	local left = shake.untilAt - os.clock()
	if left <= 0 then
		shake.size = 0
		c.CFrame = rest
		return
	end
	local k = left / shake.length
	local a = shake.size * k * k
	local t = os.clock() * 60
	c.CFrame = rest * CFrame.new(math.sin(t * 1.3) * a, math.cos(t * 1.7) * a * 0.6, 0)
end)

-- A held shot (the Ballroom's last lamp from the Gallery): glide there, hold, then glide back to
-- where the camera was (the table, or the follow camera).
local momentId = 0
function CameraRig.moment(shot: CFrame, hold: number)
	momentId += 1
	local id = momentId
	local wasTable = tableCentre
	local wasWide = tableWide
	stopTweens()
	glide(shot, TweenInfo.new(1.4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), 55)
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
				glide(shot, TweenInfo.new(math.min(3, every * 0.5), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), 50)
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

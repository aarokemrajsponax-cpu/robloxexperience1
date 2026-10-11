--!strict
-- Stagecraft: what the shows on this screen share to be staged like a film. Black bars closing in
-- at the top and foot of the screen; the camera quaking on the big hits (through the humanoid's
-- camera offset, so the walking camera stays Roblox's own); a held film shot that glides back to
-- the guest after; and the room of the Suite the guest stands in. The quake and the shots keep
-- still when the movement setting is turned down, and never at a table.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Ease = require(ReplicatedStorage.Shared.Ease)
local Layout = require(ReplicatedStorage.Shared.Layout)
local CameraRig = require(script.Parent.Parent.Camera)

local Stagecraft = {}

export type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

-- The room of the Suite the guest stands in (the drawing room if we can't tell).
function Stagecraft.roomOf(at: Vector3): Box
	local S = Layout.Suite :: any
	for _, key in { "main", "bedroom", "kitchen", "spa", "screening", "gym", "dressing", "study", "terrace" } do
		local b = S[key]
		if b and at.X >= b.minX and at.X <= b.maxX and at.Z >= b.minZ and at.Z <= b.maxZ then
			return b
		end
	end
	return S.main
end

-- The movement setting turned down: nothing shakes and the camera isn't taken.
function Stagecraft.still(): boolean
	if Ease.motionScale < 0.5 then
		return true
	end
	local ok, still = pcall(function()
		return require(script.Parent.Parent.State).get("movement") == "Still"
	end)
	return ok and still == true
end

-- Black bars closing in at the top and foot of the screen (or drawing back): a film's frame.
function Stagecraft.letterbox(gui: ScreenGui, on: boolean, depth: number?)
	for _, side in { "Top", "Bottom" } do
		local bar = gui:FindFirstChild("Bar" .. side)
		if not bar then
			if not on then
				continue
			end
			local f = Instance.new("Frame")
			f.Name = "Bar" .. side
			f.BorderSizePixel = 0
			f.BackgroundColor3 = Color3.new(0, 0, 0)
			f.AnchorPoint = Vector2.new(0, if side == "Top" then 1 else 0)
			f.Position = UDim2.fromScale(0, if side == "Top" then 0 else 1)
			f.Size = UDim2.fromScale(1, depth or 0.1)
			f.ZIndex = 20
			f.Parent = gui
			bar = f
		end
		local f = bar :: Frame
		TweenService:Create(f, TweenInfo.new(0.7, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			AnchorPoint = Vector2.new(0, if side == "Top" then (if on then 0 else 1) else (if on then 1 else 0)),
		}):Play()
	end
end

-- The camera quakes for `seconds`, `size` studs at most, easing out at the end.
local quakeUntil, quakeSize, quakeConn = 0, 0, nil :: RBXScriptConnection?
function Stagecraft.quake(size: number, seconds: number)
	if Stagecraft.still() then
		return
	end
	quakeSize = math.max(if os.clock() < quakeUntil then quakeSize else 0, size)
	quakeUntil = math.max(quakeUntil, os.clock() + seconds)
	if quakeConn then
		return
	end
	quakeConn = RunService.RenderStepped:Connect(function()
		local me = Players.LocalPlayer.Character
		local hum = me and me:FindFirstChildOfClass("Humanoid")
		local left = quakeUntil - os.clock()
		if left <= 0 or not hum then
			if hum then
				hum.CameraOffset = Vector3.zero
			end
			local c = quakeConn
			quakeConn = nil
			if c then
				c:Disconnect()
			end
			return
		end
		local a = quakeSize * math.min(1, left / 0.35)
		local t = os.clock() * 50
		hum.CameraOffset = Vector3.new(math.sin(t * 1.3) * a, math.cos(t * 1.7) * a * 0.7, math.sin(t * 0.9) * a * 0.4)
	end)
end

-- Any quake stops now, the camera back where it belongs.
function Stagecraft.calm()
	quakeUntil = 0
	local me = Players.LocalPlayer.Character
	local hum = me and me:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.CameraOffset = Vector3.zero
	end
end

-- A held film shot: the camera glides to `eye` looking at `focus`, holds, and glides back to the
-- guest. The eye is brought in short of any wall between it and the focus. Not at a table, and not
-- with the movement setting turned down (then nothing happens and it says so).
function Stagecraft.shot(focus: Vector3, eye: Vector3, hold: number, ignore: { Instance }?): boolean
	if Stagecraft.still() or CameraRig.isAtTable() then
		return false
	end
	local list: { Instance } = if ignore then table.clone(ignore) else {}
	local me = Players.LocalPlayer.Character
	if me then
		table.insert(list, me)
	end
	local params = RaycastParams.new()
	pcall(function()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = list
	end)
	local reach = eye - focus
	local ok, hit = pcall(function()
		return Workspace:Raycast(focus, reach, params)
	end)
	if ok and hit then
		local back = math.max(1.5, (hit.Position - focus).Magnitude - 0.8)
		eye = focus + reach.Unit * back
	end
	pcall(CameraRig.moment, CFrame.lookAt(eye, focus), hold)
	return true
end

return Stagecraft

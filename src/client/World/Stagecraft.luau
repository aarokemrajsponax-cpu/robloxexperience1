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

local Brand = require(ReplicatedStorage.Shared.Brand)
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

-- How a title card is coloured: its words shade from `deep` through `mid` to a shine of `light`,
-- edged in `ink`; the small line over them is in `kicker`.
export type TitleLook = { deep: Color3, mid: Color3, light: Color3, ink: Color3, kicker: Color3 }

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

-- A title card across the upper screen: a line in the house's display letters (a shine running
-- through them) under a smaller italic line, a fine rule and a small diamond between the two, and
-- (if given) a plain line of words under it. It settles in, holds and fades; a new one replaces
-- the last at once. (Under the bar at the top and clear of the keys down the left; the card of what
-- to do next steps aside while a show is on.)
local lastTitle: Frame? = nil
function Stagecraft.title(gui: ScreenGui, kicker: string?, words: string, hold: number, look: TitleLook, line: string?)
	if gui.Parent == nil then
		return
	end
	local prev = lastTitle
	if prev and prev.Parent then
		prev:Destroy()
	end
	local frame = Instance.new("Frame")
	frame.Name = "Caption"
	frame.BackgroundTransparency = 1
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.3)
	frame.Size = UDim2.fromScale(0.8, 0.11)
	frame.Parent = gui
	lastTitle = frame
	local texts: { TextLabel } = {}
	local strokes: { UIStroke } = {}
	local function label(name: string, font: Font, text: string): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.FontFace = font
		l.TextScaled = true
		l.Text = text
		l.TextTransparency = 1
		l.Parent = frame
		table.insert(texts, l)
		return l
	end
	local shadow = label("Shadow", Brand.Fonts.display, words)
	shadow.Position = UDim2.new(0, 0, 0, 3)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.TextColor3 = Color3.new(0, 0, 0)
	local main = label("Words", Brand.Fonts.display, words)
	main.Size = UDim2.fromScale(1, 1)
	main.TextColor3 = Color3.new(1, 1, 1)
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 64
	cap.Parent = main
	cap:Clone().Parent = shadow
	local fill = Instance.new("UIGradient")
	fill.Rotation = 12
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, look.deep),
		ColorSequenceKeypoint.new(0.42, look.mid),
		ColorSequenceKeypoint.new(0.5, look.light),
		ColorSequenceKeypoint.new(0.58, look.mid),
		ColorSequenceKeypoint.new(1, look.deep),
	})
	fill.Offset = Vector2.new(-0.6, 0)
	fill.Parent = main
	local edge = Instance.new("UIStroke")
	edge.Color = look.ink
	edge.Thickness = 2
	edge.Transparency = 1
	edge.Parent = main
	table.insert(strokes, edge)
	if kicker then
		local k = label("Kicker", Brand.Fonts.displayItalic, kicker)
		k.AnchorPoint = Vector2.new(0.5, 1)
		k.Position = UDim2.new(0.5, 0, 0, -12)
		k.Size = UDim2.new(0.5, 0, 0.42, 0)
		k.TextColor3 = look.kicker
		local kEdge = Instance.new("UIStroke")
		kEdge.Color = look.ink
		kEdge.Thickness = 1.5
		kEdge.Transparency = 1
		kEdge.Parent = k
		table.insert(strokes, kEdge)
		-- A fine rule between the two lines, fading at its ends, with a small diamond at its middle.
		local rule = Instance.new("Frame")
		rule.Name = "Rule"
		rule.BorderSizePixel = 0
		rule.BackgroundColor3 = look.mid
		rule.BackgroundTransparency = 1
		rule.AnchorPoint = Vector2.new(0.5, 0.5)
		rule.Position = UDim2.new(0.5, 0, 0, -6)
		rule.Size = UDim2.new(0.34, 0, 0, 2)
		rule.Parent = frame
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		fade.Parent = rule
		local gem = Instance.new("Frame")
		gem.Name = "Diamond"
		gem.BorderSizePixel = 0
		gem.BackgroundColor3 = look.light
		gem.BackgroundTransparency = 1
		gem.AnchorPoint = Vector2.new(0.5, 0.5)
		gem.Position = UDim2.new(0.5, 0, 0, -6)
		gem.Size = UDim2.fromOffset(8, 8)
		gem.Rotation = 45
		gem.Parent = frame
		for _, f in { rule, gem } do
			TweenService:Create(f, TweenInfo.new(0.7), { BackgroundTransparency = 0.05 }):Play()
		end
	end
	if line and line ~= "" then
		local under = label("Line", Brand.Fonts.body, line)
		under.AnchorPoint = Vector2.new(0.5, 0)
		under.Position = UDim2.new(0.5, 0, 1, 8)
		under.Size = UDim2.new(0.9, 0, 0.3, 0)
		under.TextColor3 = Color3.new(1, 1, 1)
		under.TextWrapped = true
		local lc = Instance.new("UITextSizeConstraint")
		lc.MaxTextSize = 20
		lc.MinTextSize = 11
		lc.Parent = under
		local uEdge = Instance.new("UIStroke")
		uEdge.Color = look.ink
		uEdge.Thickness = 1.2
		uEdge.Transparency = 1
		uEdge.Parent = under
		table.insert(strokes, uEdge)
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 1.18
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	for _, l in texts do
		TweenService:Create(l, TweenInfo.new(0.7), { TextTransparency = if l.Name == "Shadow" then 0.6 else 0 }):Play()
	end
	for _, s in strokes do
		TweenService:Create(s, TweenInfo.new(0.7), { Transparency = 0.15 }):Play()
	end
	TweenService:Create(fill, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Offset = Vector2.new(0.6, 0) }):Play()
	task.delay(hold, function()
		if frame.Parent == nil then
			return
		end
		for _, d in frame:GetDescendants() do
			if d:IsA("TextLabel") then
				TweenService:Create(d, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.wait(0.65)
		if lastTitle == frame then
			lastTitle = nil
		end
		frame:Destroy()
	end)
end

-- A title card is up (for the card of what to do next, which steps aside for it).
function Stagecraft.titleUp(): boolean
	local t = lastTitle
	return t ~= nil and t.Parent ~= nil
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

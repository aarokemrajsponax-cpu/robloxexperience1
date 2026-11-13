--!strict
-- The Executive Suite's own screen, shown only while a guest is up there: in the hallway, the alert
-- (how near security is to showing you out) and the door's code as you've found it; in the Office,
-- the phase, what's left of it (the generators, the bodyguards, the Executive's own bar) and your
-- composure. Keys: Leave, the Decoy (once, if packed), and Fire (or click) in the Office. The keypad
-- at the door. What's thrown, the shockwave and the shots are drawn here, where the server says.
-- Everything shown is what the server last said; the server decides every hit.
-- Build 78: the Executive's wind-ups drawn where everyone can see them (a ring for a shockwave, a
-- lane for his dash, a ring under him for briefcases) and said plainly while they last; his lines
-- as captions; the way into the Office a moment's look at him (letterboxed); his finale in a red
-- grade; and after he's beaten, the extraction's minute counting down to the lift.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Plan = require(ReplicatedStorage.Shared.Executive)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Root = require(script.Parent.Root)
local Sound = require(script.Parent.Parent.Sound)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)

local ExecutiveHud = {}

local C = Brand.Colours
local GOLD = Color3.fromRGB(255, 204, 90)
local RED = Color3.fromRGB(235, 70, 80)
local BLUE = Color3.fromRGB(120, 200, 255)
local CARD_W = 340
local CARD_H = 96
local KEYPAD = "ExecutiveKeypad"

local card: Frame? = nil
local keys: Frame? = nil
local parts: { [string]: any } = {}
local view: { [string]: any } = {}
local conns: { RBXScriptConnection } = {}
local effects: { Instance } = {}
-- (Build 78) the wind-up on show and when it ends; the intro's camera; the finale's grade.
local windup: { line: string, untilAt: number }? = nil
local introBusy = false
local cinematic: { [string]: any } = {}

-- The Suite's eyes on this screen (World/ExecutiveSight): told what the server says.
local function sight(fn: string, ...: any)
	local args = table.pack(...)
	pcall(function()
		local S = require(script.Parent.Parent.World.ExecutiveSight) :: any
		S[fn](table.unpack(args, 1, args.n))
	end)
end

local function ask(request: { [string]: any }): { [string]: any }?
	local ok, r = pcall(function()
		return Remotes.func("AttractionAsk"):InvokeServer(request)
	end)
	return if ok and type(r) == "table" then r else nil
end

local function now(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

local function fighting(): boolean
	local p = view.phase
	return p == "shield" or p == "detail" or p == "boss"
end
ExecutiveHud.fighting = fighting

-- The stun pistol from the guest's inventory (the Satchel), if it's in their hand.
local function pistolInHand(): Tool?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	for _, t in character:GetChildren() do
		if t:IsA("Tool") and t:GetAttribute("SatchelId") == "sidearm" then
			return t
		end
	end
	return nil
end

local function label(parent: Instance, name: string, text: string, size: number, font: Font, colour: Color3, y: number, align: Enum.TextXAlignment?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 6)
	l.Position = UDim2.fromOffset(0, y)
	l.FontFace = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = text
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function bar(parent: Instance, name: string, y: number, colour: Color3): Frame
	local track = Instance.new("Frame")
	track.Name = name
	track.Position = UDim2.fromOffset(0, y)
	track.Size = UDim2.new(1, 0, 0, 6)
	track.BackgroundColor3 = Color3.fromRGB(48, 42, 36)
	track.BorderSizePixel = 0
	track.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = colour
	fill.BorderSizePixel = 0
	fill.Parent = track
	return fill
end

local STRIP_H = 70

local function place()
	local c = card
	if not c then
		return
	end
	local y = math.max(Root.topClear("Executive") + 6, 126)
	c.Position = UDim2.new(0.5, 0, 0, y)
	local strip = parts.strip :: Frame?
	local below = 0
	if strip then
		strip.Position = UDim2.new(0.5, 0, 0, y + CARD_H + 8)
		if strip.Visible then
			below = STRIP_H + 8
		end
	end
	Root.setTop("Executive", y + CARD_H + 4 + below, CARD_W / 2)
	local k = keys
	if k then
		k.Position = UDim2.new(0.5, 0, 1, -(14 + Root.bottomClear()))
	end
end

local PHASE_NAMES: { [string]: string } = { hall = "The hallway", won = "The Executive, beaten" }
for _, p in Plan.Phases do
	PHASE_NAMES[p.id] = p.name
end

local function draw()
	if not card then
		return
	end
	local phase = tostring(view.phase or "hall")
	parts.phase.Text = string.upper(PHASE_NAMES[phase] or phase)
	-- (The Executive's own score while he's on his feet; the Suite's again after.)
	Sound.setMood(if phase == "boss" then "boss" else nil)
	-- The code, big, in its four slots until the door opens.
	local strip = parts.strip :: Frame?
	if strip then
		local want = phase == "hall" and not view.open
		local known = string.split(tostring(view.digits or "_ _ _ _"), " ")
		for k, slot in parts.slots :: { TextLabel } do
			local d = known[k]
			local has = type(d) == "string" and d ~= "_" and d ~= ""
			slot.Text = if has then d else "?"
			slot.TextColor3 = if has then GOLD else C.smoke
		end
		if strip.Visible ~= want then
			strip.Visible = want
			place()
		end
	end
	if phase == "won" and tonumber(view.extractUntil) then
		-- The extraction's minute, counting down to the lift.
		local left = math.max(0, math.ceil((tonumber(view.extractUntil) :: number) - now()))
		parts.top.Text = if left > 0 then string.format("EXTRACTION  ·  THE LIFT DOWN  %d:%02d", left // 60, left % 60) else "THE LIFT DOWN IS OPEN"
		parts.under.Text = if left > 0 then "A CLEAN GETAWAY PAYS A BONUS  ·  THE SAFE IS OPEN" else ""
		parts.under.TextColor3 = if left > 0 then GOLD else C.smoke
		parts.fill.Size = UDim2.new(0, 0, 1, 0)
		parts.second.Size = UDim2.new(0, 0, 1, 0)
		parts.label2.Text = ""
	elseif phase == "hall" then
		parts.top.Text = "CODE  " .. tostring(view.digits or "_ _ _ _")
		local found = not string.find(tostring(view.digits or "_"), "_", 1, true)
		parts.under.Text = if view.open then "THE DOOR IS OPEN"
			elseif found then "ALL FOUR DIGITS · THE KEYPAD IS BY THE VAULT DOOR"
			else "STAY OUT OF THE RED LIGHT · READ THE FOUR TERMINALS"
		parts.under.TextColor3 = C.smoke
		local alert = math.clamp(tonumber(view.alert) or 0, 0, 1)
		parts.fill.Size = UDim2.new(alert, 0, 1, 0)
		parts.fill.BackgroundColor3 = Color3.fromRGB(255, 196, 80):Lerp(RED, alert)
		parts.second.Size = UDim2.new(0, 0, 1, 0)
		-- (Who has eyes on them right now, as the server says; then the alert, falling.)
		local seen = view.seen
		parts.label2.Text = if seen == "guard" then "A GUARD SEES YOU"
			elseif seen == "camera" then "A CAMERA SEES YOU"
			elseif alert > 0.05 then string.format("ALERT %d%%", math.floor(alert * 100 + 0.5))
			else "UNSEEN"
		parts.label2.TextColor3 = if seen then RED else C.smoke
	else
		local left = ""
		if phase == "shield" then
			left = string.format("GENERATORS LEFT  %d", tonumber(view.generators) or 0)
		elseif phase == "detail" then
			left = string.format("BODYGUARDS LEFT  %d", tonumber(view.guards) or 0)
		elseif phase == "boss" then
			left = "THE EXECUTIVE"
		else
			left = "THE SAFE AND THE LIFT DOWN ARE OPEN"
		end
		parts.top.Text = left
		-- (What he's winding up, said plainly while it lasts.)
		local w = windup
		if w and now() < w.untilAt then
			parts.under.Text = w.line
			parts.under.TextColor3 = RED
		else
			parts.under.Text = if view.finale then "HIS FINALE  ·  HE'S QUICKER NOW" else ""
			parts.under.TextColor3 = if view.finale then RED else C.smoke
		end
		local boss = if phase == "boss" then math.clamp((tonumber(view.boss) or 0) / math.max(1, tonumber(view.bossMax) or 1), 0, 1) else 0
		parts.fill.Size = UDim2.new(boss, 0, 1, 0)
		parts.fill.BackgroundColor3 = RED
		local comp = math.clamp((tonumber(view.composure) or 0) / math.max(1, tonumber(view.max) or 100), 0, 1)
		parts.second.Size = UDim2.new(comp, 0, 1, 0)
		parts.label2.Text = string.format("COMPOSURE %d", tonumber(view.composure) or 0)
		parts.label2.TextColor3 = C.smoke
	end
	local fire = parts.fireKey :: TextButton?
	if fire then
		fire.Visible = fighting()
	end
	local decoy = parts.decoyKey :: TextButton?
	if decoy then
		decoy.Visible = view.decoy == true and phase == "hall"
	end
	local cross = parts.cross :: Frame?
	if cross then
		cross.Visible = fighting()
	end
end

-- A shot from this guest's sidearm, toward where they aim (the server decides what it hits).
local function shoot(direction: Vector3)
	if not fighting() then
		return
	end
	pcall(function()
		Remotes.event("AttractionFire"):FireServer(direction.Unit)
	end)
end
ExecutiveHud.shoot = shoot

local aimFromScreen: (position: Vector2?) -> Vector3

-- The pistol used from the hotbar: aimed at the mouse (or the middle of a touch screen). False
-- when there's no fight to fire in.
function ExecutiveHud.fireFromTool(): boolean
	if not fighting() then
		return false
	end
	local at: Vector2? = nil
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local ok, m = pcall(function()
			return UserInputService:GetMouseLocation()
		end)
		at = if ok and typeof(m) == "Vector2" then m else nil
	end
	shoot(aimFromScreen(at))
	return true
end

-- The decoy, thrown (the HUD's key and the hotbar's Decoy both come here).
local function throwDecoy()
	task.spawn(function()
		local r = ask({ op = "act", id = "executive", act = "decoy" })
		if r and r.ok ~= true and type(r.why) == "string" then
			Toast.show("The decoy", r.why, 3)
		end
	end)
end
ExecutiveHud.throwDecoy = throwDecoy

function aimFromScreen(position: Vector2?): Vector3
	local ok, direction = pcall(function()
		local camera = Workspace.CurrentCamera :: Camera
		local at = position or (camera.ViewportSize / 2)
		return camera:ViewportPointToRay(at.X, at.Y).Direction
	end)
	if ok and typeof(direction) == "Vector3" and direction.Magnitude > 0.5 then
		return direction
	end
	-- (No camera to aim with: straight ahead of the guest.)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.CFrame.LookVector
	end
	return Vector3.new(0, 0, 1)
end

function ExecutiveHud.openKeypad()
	if Root.isOpen(KEYPAD) then
		return
	end
	local w = Root.panelWidth(300)
	local group, content = Theme.glass(Root.panels, KEYPAD, UDim2.fromOffset(w, 420))
	Theme.fitHeight(group, content)
	Theme.list(content, 8).VerticalAlignment = Enum.VerticalAlignment.Top
	Theme.text(content, "The Executive's door", 11, "caps", { LayoutOrder = 1 })
	local entered = ""
	local shown = Theme.text(content, "_ _ _ _", 30, "display", { LayoutOrder = 2 })
	-- What the terminals told this guest, big enough to read at a glance; with all four read,
	-- the code is filled in and Enter is all it takes.
	local known = tostring(view.digits or "_ _ _ _")
	Theme.text(content, "From the terminals:  " .. known, 18, "display", { LayoutOrder = 3, TextColor3 = GOLD })
	if not string.find(known, "_", 1, true) then
		entered = string.gsub(known, " ", "")
	end
	local function show()
		local out = {}
		for k = 1, 4 do
			out[k] = if k <= #entered then string.sub(entered, k, k) else "_"
		end
		shown.Text = table.concat(out, " ")
	end
	show()
	local grid = Instance.new("Frame")
	grid.Name = "Keys"
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 200)
	grid.LayoutOrder = 4
	grid.Parent = content
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(64, 44)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for i, k in { "1", "2", "3", "4", "5", "6", "7", "8", "9", "Clear", "0", "Enter" } do
		local key = Theme.key(grid, k, k == "Enter", function()
			if k == "Clear" then
				entered = ""
			elseif k == "Enter" then
				local code = entered
				task.spawn(function()
					local r = ask({ op = "act", id = "executive", act = "code", code = code })
					if r and r.ok == true then
						Root.close(KEYPAD)
					else
						Toast.show("The door", if r and type(r.why) == "string" then r.why else "Not just now.", 3)
						entered = ""
						show()
					end
				end)
			elseif #entered < 4 then
				entered ..= k
			end
			show()
		end, 64)
		key.LayoutOrder = i
	end
	local close = Theme.key(content, "Close", false, function()
		Root.close(KEYPAD)
	end, 160)
	close.LayoutOrder = 10
	Root.open(KEYPAD, group)
end

-- A line of the Executive's, as a caption at the foot of the screen (over the keys).
function ExecutiveHud.caption(say: string?)
	if type(say) ~= "string" or say == "" then
		return
	end
	local old = cinematic.caption :: Instance?
	if old then
		old:Destroy()
	end
	local l = Instance.new("TextLabel")
	l.Name = "ExecutiveCaption"
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.Position = UDim2.new(0.5, 0, 1, -(78 + Root.bottomClear()))
	l.Size = UDim2.fromOffset(math.min(620, Root.size().X - 40), 30)
	l.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	l.BackgroundTransparency = 0.25
	l.FontFace = Brand.Fonts.body
	l.TextSize = 17
	l.TextColor3 = Color3.fromRGB(240, 232, 214)
	l.Text = "“" .. say .. "”  — The Executive"
	l.TextWrapped = true
	l.Parent = Root.hud
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = l
	cinematic.caption = l
	task.delay(4, function()
		if cinematic.caption == l then
			cinematic.caption = nil
			l:Destroy()
		end
	end)
end

local function letterbox(on: boolean)
	for _, key in { "barTop", "barFoot" } do
		local f = cinematic[key] :: Instance?
		if f then
			f:Destroy()
			cinematic[key] = nil
		end
	end
	if not on then
		return
	end
	for i, key in { "barTop", "barFoot" } do
		local f = Instance.new("Frame")
		f.Name = "Letterbox"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.Size = UDim2.new(1, 0, 0.09, 0)
		f.AnchorPoint = Vector2.new(0, if i == 1 then 0 else 1)
		f.Position = UDim2.fromScale(0, if i == 1 then 0 else 1)
		f.ZIndex = 50
		f.Parent = Root.hud
		cinematic[key] = f
	end
end

-- The way into the Office: a moment's look at the man behind the desk, then back to the guest.
function ExecutiveHud.intro(m: { [string]: any })
	ExecutiveHud.caption(m.say)
	local cam = Workspace.CurrentCamera
	if introBusy or not cam or typeof(m.at) ~= "Vector3" then
		return
	end
	introBusy = true
	letterbox(true)
	local from = cam.CFrame
	local ok = pcall(function()
		cam.CameraType = Enum.CameraType.Scriptable
		local look = CFrame.lookAt(m.at + Vector3.new(0, 1.2, -13), m.at)
		TweenService:Create(cam, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = look }):Play()
	end)
	task.delay(if ok then 2.6 else 0, function()
		pcall(function()
			TweenService:Create(cam, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = from }):Play()
		end)
		task.delay(0.65, function()
			pcall(function()
				cam.CameraType = Enum.CameraType.Custom
			end)
			letterbox(false)
			introBusy = false
		end)
	end)
end

-- His finale's red grade over everything (and gone again once it's over).
local function grade(on: boolean)
	local g = cinematic.grade :: Instance?
	if on and not g then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ExecutiveFinale"
		cc.TintColor = Color3.fromRGB(255, 205, 205)
		cc.Contrast = 0.08
		cc.Saturation = 0.12
		cc.Parent = Lighting
		cinematic.grade = cc
	elseif not on and g then
		g:Destroy()
		cinematic.grade = nil
	end
end
ExecutiveHud.grade = grade

-- A wind-up, drawn where the server says, for as long as it lasts: a ring where a shockwave will
-- start, a lane where he'll dash, a ring under him for his briefcases.
local function warn(m: { [string]: any })
	local seconds = math.max(0.2, tonumber(m.seconds) or 1)
	windup = { line = tostring(m.line or ""), untilAt = now() + seconds }
	local floorY = AttractionList.origin("executive").Y + 0.12
	local made: { BasePart } = {}
	local function piece(name: string, size: Vector3, cf: CFrame, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = RED
		p.Transparency = 0.3
		if shape then
			p.Shape = shape
		end
		p.Size = size
		p.CFrame = cf
		p.Parent = Workspace
		table.insert(made, p)
		table.insert(effects, p)
		return p
	end
	local kind = tostring(m.kind)
	if kind == "wave" and typeof(m.at) == "Vector3" then
		piece("WaveWarning", Vector3.new(0.12, 9, 9), CFrame.new(Vector3.new(m.at.X, floorY, m.at.Z)) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	elseif kind == "dash" and typeof(m.from) == "Vector3" and typeof(m.to) == "Vector3" then
		local a = Vector3.new(m.from.X, floorY, m.from.Z)
		local b = Vector3.new(m.to.X, floorY, m.to.Z)
		local length = math.max(1, (b - a).Magnitude)
		piece("DashLane", Vector3.new(6.4, 0.1, length), CFrame.lookAt((a + b) / 2, b))
	elseif typeof(m.from) == "Vector3" then
		piece("VolleyWarning", Vector3.new(0.12, 6, 6), CFrame.new(Vector3.new(m.from.X, floorY, m.from.Z)) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	end
	for _, p in made do
		pcall(function()
			TweenService:Create(p, TweenInfo.new(seconds / 3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.75 }):Play()
		end)
	end
	Sound.play("low", 0.45)
	task.delay(seconds, function()
		for _, p in made do
			p:Destroy()
		end
	end)
	draw()
end

function ExecutiveHud.mounted(): boolean
	return card ~= nil
end

function ExecutiveHud.mount()
	if card then
		return
	end
	local c = Instance.new("Frame")
	c.Name = "ExecutiveCard"
	c.AnchorPoint = Vector2.new(0.5, 0)
	c.Size = UDim2.fromOffset(CARD_W, CARD_H)
	c.BackgroundColor3 = Color3.fromRGB(12, 14, 22)
	c.BackgroundTransparency = 0.08
	c.Parent = Root.hud
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = c
	local edge = Instance.new("UIStroke")
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Color = BLUE
	edge.Thickness = 1.25
	edge.Transparency = 0.3
	edge.Parent = c
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = c
	label(c, "Title", "THE EXECUTIVE SUITE", 11, Brand.Fonts.bodyBold, GOLD, 0)
	parts.phase = label(c, "Phase", "", 11, Brand.Fonts.bodyBold, C.bone, 0, Enum.TextXAlignment.Right)
	parts.top = label(c, "Top", "", 15, Brand.Fonts.bodyBold, C.bone, 20)
	parts.under = label(c, "Under", "", 10, Brand.Fonts.bodyBold, C.smoke, 40)
	parts.fill = bar(c, "MainBar", 58, Color3.fromRGB(255, 196, 80))
	parts.second = bar(c, "SecondBar", 70, BLUE)
	parts.label2 = label(c, "Second", "", 10, Brand.Fonts.bodyBold, C.smoke, 76, Enum.TextXAlignment.Right)
	-- A crosshair in the middle while there's something to stun.
	local cross = Instance.new("Frame")
	cross.Name = "Crosshair"
	cross.AnchorPoint = Vector2.new(0.5, 0.5)
	cross.Position = UDim2.fromScale(0.5, 0.5)
	cross.Size = UDim2.fromOffset(18, 18)
	cross.BackgroundTransparency = 1
	cross.Visible = false
	cross.Parent = Root.hud
	for _, s in { UDim2.fromOffset(18, 2), UDim2.fromOffset(2, 18) } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = s
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.Parent = cross
	end
	parts.cross = cross
	card = c

	-- The code's four slots, under the card while the door is shut.
	local strip = Instance.new("Frame")
	strip.Name = "CodeStrip"
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(4 * 58 + 3 * 10, STRIP_H)
	strip.Visible = false
	strip.Parent = Root.hud
	local slots: { TextLabel } = {}
	for k = 1, 4 do
		local s = Instance.new("TextLabel")
		s.Name = "Slot" .. k
		s.Size = UDim2.fromOffset(58, STRIP_H)
		s.Position = UDim2.fromOffset((k - 1) * 68, 0)
		s.BackgroundColor3 = Color3.fromRGB(10, 12, 16)
		s.BackgroundTransparency = 0.06
		s.FontFace = Brand.Fonts.display
		s.TextSize = 44
		s.TextColor3 = C.smoke
		s.Text = "?"
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0, 10)
		sc.Parent = s
		local ss = Instance.new("UIStroke")
		ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ss.Color = BLUE
		ss.Thickness = 1.5
		ss.Transparency = 0.35
		ss.Parent = s
		s.Parent = strip
		slots[k] = s
	end
	parts.strip = strip
	parts.slots = slots

	local k = Instance.new("Frame")
	k.Name = "ExecutiveKeys"
	k.AnchorPoint = Vector2.new(0.5, 1)
	k.BackgroundTransparency = 1
	k.Size = UDim2.fromOffset(420, 44)
	k.Parent = Root.hud
	Theme.list(k, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Theme.key(k, "Leave", false, function()
		task.spawn(function()
			local r = ask({ op = "home" })
			if r and r.ok ~= true and type(r.why) == "string" then
				Toast.show("Not just now", r.why, 3)
			end
		end)
	end, 120)
	parts.decoyKey = Theme.key(k, "Decoy", false, throwDecoy, 120)
	parts.fireKey = Theme.key(k, "Fire", true, function()
		shoot(aimFromScreen(nil))
	end, 120)
	keys = k
	place()
	draw()
	table.insert(conns, Root.TopChanged:Connect(place))
	-- (The wind-up's line and the extraction's minute kept up to the moment.)
	local tick = 0
	table.insert(conns, RunService.Heartbeat:Connect(function(dt: number)
		tick += dt
		if tick >= 0.2 then
			tick = 0
			if windup or view.phase == "won" then
				draw()
				local w = windup
				if w and now() >= w.untilAt then
					windup = nil
				end
			end
		end
	end))
	-- A click aims where it lands (a tap on the Fire key aims at the middle).
	table.insert(conns, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not fighting() then
			return
		end
		-- (With the pistol in hand, the click is the pistol's own: it fires once, from there.)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not pistolInHand() then
			shoot(aimFromScreen(Vector2.new(input.Position.X, input.Position.Y)))
		end
	end))
end

function ExecutiveHud.unmount()
	Sound.setMood(nil)
	grade(false)
	letterbox(false)
	local cap = cinematic.caption :: Instance?
	if cap then
		cap:Destroy()
	end
	cinematic = {}
	windup = nil
	if introBusy then
		pcall(function()
			(Workspace.CurrentCamera :: Camera).CameraType = Enum.CameraType.Custom
		end)
		introBusy = false
	end
	for _, c in conns do
		c:Disconnect()
	end
	conns = {}
	for _, e in effects do
		e:Destroy()
	end
	effects = {}
	if card then
		card:Destroy()
		card = nil
	end
	if keys then
		keys:Destroy()
		keys = nil
	end
	local cross = parts.cross :: Frame?
	if cross then
		cross:Destroy()
	end
	local strip = parts.strip :: Frame?
	if strip then
		strip:Destroy()
		parts.strip = nil
		parts.slots = nil
	end
	if Root.isOpen(KEYPAD) then
		Root.close(KEYPAD)
	end
	parts = {}
	view = {}
	Root.setTop("Executive", nil)
	sight("reset")
end

-- Something thrown or sent out, drawn where the server says, for as long as it flies.
local function fly(m: { [string]: any }, kind: string)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	if kind == "throw" then
		part.Name = "Briefcase"
		part.Size = Vector3.new(2, 1.4, 0.6)
		part.Color = Color3.fromRGB(90, 56, 30)
		part.Material = Enum.Material.Leather
	else
		part.Name = "Shockwave"
		part.Shape = Enum.PartType.Cylinder
		part.Color = Color3.fromRGB(255, 200, 80)
		part.Material = Enum.Material.Neon
		part.Transparency = 0.45
	end
	part.Parent = Workspace
	table.insert(effects, part)
	local born, life = tonumber(m.born) or now(), tonumber(m.life) or 2
	local conn: RBXScriptConnection? = nil
	conn = RunService.Heartbeat:Connect(function()
		local age = now() - born
		if age > life or not part.Parent then
			if conn then
				conn:Disconnect()
			end
			part:Destroy()
			return
		end
		if kind == "throw" and typeof(m.from) == "Vector3" and typeof(m.dir) == "Vector3" then
			part.CFrame = CFrame.new(m.from + m.dir * (tonumber(m.speed) or 40) * age) * CFrame.Angles(age * 9, age * 5, 0)
		elseif typeof(m.at) == "Vector3" then
			local r = math.max(0.5, (tonumber(m.speed) or 26) * age)
			part.Size = Vector3.new(0.3, r * 2, r * 2)
			part.CFrame = CFrame.new(m.at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
		end
	end)
end

local function tracer(m: { [string]: any })
	if typeof(m.from) ~= "Vector3" or typeof(m.dir) ~= "Vector3" then
		return
	end
	local length = 60
	local beam = Instance.new("Part")
	beam.Name = "Tracer"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = BLUE
	beam.Size = Vector3.new(0.12, 0.12, length)
	beam.CFrame = CFrame.lookAt(m.from + m.dir * length / 2, m.from + m.dir * length)
	beam.Parent = Workspace
	task.delay(0.08, function()
		beam:Destroy()
	end)
end

function ExecutiveHud.on(m: { [string]: any })
	local op = m.op
	if op == "executive" then
		local before = fighting()
		view = m
		sight("status", m)
		draw()
		-- The fight starts: the stun pistol comes out of the inventory, into the guest's hand.
		if fighting() and not before and not pistolInHand() then
			pcall(function()
				local player = Players.LocalPlayer
				local backpack = player:FindFirstChildOfClass("Backpack")
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if backpack and humanoid then
					for _, t in backpack:GetChildren() do
						if t:IsA("Tool") and t:GetAttribute("SatchelId") == "sidearm" then
							humanoid:EquipTool(t)
							break
						end
					end
				end
			end)
		end
	elseif op == "digit" then
		local n = tonumber(m.n) or 0
		sight("digit", n)
		local slot = (parts.slots or {})[n] :: TextLabel?
		if slot then
			-- (The slot lights up with its digit, then settles: there until the door opens. No
			-- notice over the hallway as well: nothing pops up in the way while the guards walk.)
			slot.Text = tostring(m.digit)
			slot.TextColor3 = GOLD
			slot.BackgroundColor3 = Color3.fromRGB(70, 56, 20)
			Ease.play(slot, Ease.info(0.9, Enum.EasingStyle.Quad), { BackgroundColor3 = Color3.fromRGB(10, 12, 16) })
		end
		pcall(function()
			Sound.play("chime", 0.7)
		end)
	elseif op == "keypad" then
		ExecutiveHud.openKeypad()
	elseif op == "doorOpen" then
		Toast.show("The door is open", "The Executive's Office, straight ahead.", 3)
	elseif op == "phase" then
		if type(m.name) == "string" then
			Toast.show(m.name, tostring(m.line or ""), 4)
		end
		if m.phase ~= "shield" then
			ExecutiveHud.caption(m.say)
		end
		if m.phase == "won" or m.phase == "hall" then
			grade(false)
			windup = nil
		end
	elseif op == "intro" then
		ExecutiveHud.intro(m)
	elseif op == "windup" then
		warn(m)
	elseif op == "finale" then
		view.finale = true
		grade(true)
		ExecutiveHud.caption(m.say)
		Sound.play("lowHit", 0.7)
		draw()
	elseif op == "extract" then
		view.extractUntil = tonumber(m.untilAt)
		Toast.show("Security is on its way", string.format("The lift down within %d seconds is a clean getaway: +%s Gilt. The safe is open too.", tonumber(m.seconds) or 60, Rules.format(tonumber(m.gilt) or 0)), 5)
		draw()
	elseif op == "extracted" then
		Toast.show("A clean getaway", "+" .. Rules.format(tonumber(m.gilt) or 0) .. " Gilt", 4)
	elseif op == "alarm" then
		Toast.show("Security", "You were seen too long: you've been shown out. The invitation is spent.", 5)
	elseif op == "escorted" then
		Toast.show("Escorted out", "No composure left. Try again with another invitation.", 5)
	elseif op == "won" then
		local line = string.format("%s to your Estate  ·  +%s Gilt", Rules.format(tonumber(m.worth) or 0), Rules.format(tonumber(m.gilt) or 0))
		if m.brainrot then
			line ..= "  ·  Il Dirigente Supremo for your collection"
		end
		Toast.show("The Executive, beaten", line .. ". The safe is open, and the lift down.", 6)
	elseif op == "safe" then
		Toast.show("The safe", Rules.format(tonumber(m.worth) or 0) .. " to your Estate.", 3)
	elseif op == "throw" then
		fly(m, "throw")
	elseif op == "wave" then
		fly(m, "wave")
	elseif op == "shot" then
		tracer(m)
	elseif op == "decoy" then
		if typeof(m.at) == "Vector3" then
			sight("decoy", m.at, tonumber(m.seconds) or 8)
		end
		Toast.show("A decoy", string.format("Every eye in the hallway is on it for %d seconds.", tonumber(m.seconds) or 8), 2.5)
	end
end

return ExecutiveHud

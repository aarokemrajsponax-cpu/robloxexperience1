--!strict
-- The Executive Suite's own screen, shown only while a guest is up there: in the hallway, the alert
-- (how near security is to showing you out) and the door's code as you've found it; in the Office,
-- the phase, what's left of it (the generators, the bodyguards, the Executive's own bar) and your
-- composure. Keys: Leave and the Decoy (once, if packed); in the Office a click or a tap fires (Build 94: no Fire key). The keypad
-- at the door. What's thrown, the shockwave and the shots are drawn here, where the server says.
-- Everything shown is what the server last said; the server decides every hit.
-- Build 78: the Executive's wind-ups drawn where everyone can see them (a ring for a shockwave, a
-- lane for his dash, a ring under him for briefcases) and said plainly while they last; his lines
-- as captions; the way into the Office a moment's look at him (letterboxed); his finale in a red
-- grade; and after he's beaten, the extraction's minute counting down to the lift.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Config = require(ReplicatedStorage.Shared.Config)
local Ease = require(ReplicatedStorage.Shared.Ease)
local Plan = require(ReplicatedStorage.Shared.Executive)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local HudCard = require(script.Parent.HudCard)
local Root = require(script.Parent.Root)
local Sound = require(script.Parent.Parent.Sound)
local Theme = require(script.Parent.Theme)
local Toast = require(script.Parent.Toast)
local Moment = require(script.Parent.Moment)

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
	-- (The bottom-left corner, like every attraction's card: UI/HudCard. The code's slots sit just
	-- above it while the door is shut.)
	local strip = parts.strip :: Frame?
	HudCard.place(c, 210, if strip and strip.Visible then STRIP_H + 8 else 0)
	if strip then
		strip.AnchorPoint = Vector2.new(0, 1)
		strip.Position = UDim2.new(0, c.Position.X.Offset, 1, c.Position.Y.Offset - CARD_H - 8)
	end
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
	-- (The fight's own score from the moment the Office's fight begins, through all three of its
	-- phases; the Suite's again after.)
	Sound.setMood(if fighting() then "boss" else nil)
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
			-- (Build 87: what to do now, plainly, whenever he isn't winding up.)
			parts.under.Text = if view.finale then "HIS FINALE  ·  HE'S QUICKER NOW"
				elseif phase == "shield" then "SHOOT THE BLUE GENERATORS  ·  THEY POWER HIS SHIELD"
				elseif phase == "detail" then "THE SHIELD IS DOWN  ·  STUN HIS BODYGUARDS"
				elseif phase == "boss" then "STUN THE EXECUTIVE  ·  WATCH FOR HIS WIND-UPS"
				else ""
			parts.under.TextColor3 = if view.finale then RED else GOLD
		end
		local boss = if phase == "boss" then math.clamp((tonumber(view.boss) or 0) / math.max(1, tonumber(view.bossMax) or 1), 0, 1) else 0
		parts.fill.Size = UDim2.new(boss, 0, 1, 0)
		parts.fill.BackgroundColor3 = RED
		local comp = math.clamp((tonumber(view.composure) or 0) / math.max(1, tonumber(view.max) or 100), 0, 1)
		parts.second.Size = UDim2.new(comp, 0, 1, 0)
		parts.label2.Text = string.format("YOUR HEALTH %d", tonumber(view.composure) or 0)
		parts.label2.TextColor3 = C.smoke
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

-- (Build 87) A health bar over each thing this phase is about (the generators, the bodyguards, the
-- Executive), filled to what the server says is left of it (its "Hp" and "HpMax"), with its name and
-- a small gold marker over it that bobs: what to shoot, at a glance. Only in the fight, only over
-- what this phase is about; gone with it.
local bars: { [Instance]: BillboardGui } = {}
local function barColour(id: string): Color3
	if string.sub(id, 1, 3) == "gen" then
		return BLUE
	elseif id == "boss" then
		return RED
	end
	return Color3.fromRGB(255, 150, 70)
end
local function barName(id: string): string
	if string.sub(id, 1, 3) == "gen" then
		return "GENERATOR " .. string.sub(id, 4)
	elseif id == "boss" then
		return "THE EXECUTIVE"
	end
	return "BODYGUARD"
end
function ExecutiveHud.clearBars()
	for _, b in bars do
		b:Destroy()
	end
	bars = {}
end
function ExecutiveHud.bars()
	local phase = tostring(view.phase or "hall")
	local want = if phase == "shield" then "gen" elseif phase == "detail" then "guard" elseif phase == "boss" then "boss" else nil
	local seen: { [Instance]: boolean } = {}
	if want then
		for _, inst in CollectionService:GetTagged("ExecHp") do
			local id = inst:GetAttribute("ExecTarget")
			local hp = tonumber(inst:GetAttribute("Hp")) or 0
			local most = math.max(1, tonumber(inst:GetAttribute("HpMax")) or 1)
			if type(id) == "string" and string.sub(id, 1, #want) == want and hp > 0 and inst.Parent then
				seen[inst] = true
				local b = bars[inst]
				if not b then
					local big = id == "boss"
					local g = Instance.new("BillboardGui")
					g.Name = "MaisonHpBar"
					g.Size = UDim2.fromOffset(if big then 200 else 130, 44)
					g.StudsOffset = Vector3.new(0, if string.sub(id, 1, 3) == "gen" then 5 else 4, 0)
					g.AlwaysOnTop = true
					g.MaxDistance = 200
					g.LightInfluence = 0
					local adornee: Instance? = inst
					if inst:IsA("Model") then
						adornee = inst:FindFirstChild("Head") or inst:FindFirstChild("HumanoidRootPart") or inst.PrimaryPart
					end
					g.Adornee = adornee :: any
					local marker = Instance.new("TextLabel")
					marker.Name = "Marker"
					marker.BackgroundTransparency = 1
					marker.AnchorPoint = Vector2.new(0.5, 0)
					marker.Position = UDim2.fromScale(0.5, 0)
					marker.Size = UDim2.fromOffset(20, 14)
					marker.FontFace = Brand.Fonts.heavy
					marker.TextSize = 14
					marker.TextColor3 = GOLD
					marker.Text = "▼"
					marker.Parent = g
					local name = Instance.new("TextLabel")
					name.Name = "Name"
					name.BackgroundTransparency = 1
					name.Position = UDim2.fromOffset(0, 13)
					name.Size = UDim2.new(1, 0, 0, 13)
					name.FontFace = Brand.Fonts.heavy
					name.TextSize = 11
					name.TextColor3 = Color3.fromRGB(240, 232, 218)
					name.TextStrokeTransparency = 0.4
					name.Text = barName(id)
					name.Parent = g
					local track = Instance.new("Frame")
					track.Name = "Track"
					track.Position = UDim2.fromOffset(0, 29)
					track.Size = UDim2.new(1, 0, 0, if big then 12 else 9)
					track.BackgroundColor3 = Color3.fromRGB(16, 14, 18)
					track.BackgroundTransparency = 0.15
					track.Parent = g
					local tc = Instance.new("UICorner")
					tc.CornerRadius = UDim.new(1, 0)
					tc.Parent = track
					local ts = Instance.new("UIStroke")
					ts.Color = Color3.fromRGB(0, 0, 0)
					ts.Transparency = 0.3
					ts.Parent = track
					local fill = Instance.new("Frame")
					fill.Name = "Fill"
					fill.BackgroundColor3 = barColour(id)
					fill.Size = UDim2.fromScale(1, 1)
					fill.Parent = track
					local fc = Instance.new("UICorner")
					fc.CornerRadius = UDim.new(1, 0)
					fc.Parent = fill
					g.Parent = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui") or Root.hud
					bars[inst] = g
					b = g
				end
				local bar = b :: BillboardGui
				local fill = bar:FindFirstChild("Track") and (bar :: any).Track:FindFirstChild("Fill")
				if fill then
					fill.Size = UDim2.fromScale(math.clamp(hp / most, 0, 1), 1)
				end
				local marker = bar:FindFirstChild("Marker")
				if marker and marker:IsA("TextLabel") then
					marker.Position = UDim2.new(0.5, 0, 0, math.floor(math.abs(math.sin(os.clock() * 4)) * 3))
				end
			end
		end
	end
	for inst, b in bars do
		if not seen[inst] then
			b:Destroy()
			bars[inst] = nil
		end
	end
end
ExecutiveHud.barsFor = function(): { [Instance]: BillboardGui }
	return bars
end

-- A shot from this guest's sidearm, toward where they aim (the server decides what it hits).
-- (Build 87) The shot on the guest's own body: the arm kicks up and back, a flash at the muzzle.
local function recoil()
	pcall(function()
		local character = Players.LocalPlayer.Character
		if not character then
			return
		end
		local shoulder = character:FindFirstChild("RightShoulder", true) or character:FindFirstChild("Right Shoulder", true)
		if shoulder and shoulder:IsA("Motor6D") then
			local base = shoulder:GetAttribute("BaseC0") or shoulder.C0
			shoulder:SetAttribute("BaseC0", base)
			shoulder.C0 = (base :: CFrame) * CFrame.Angles(math.rad(14), 0, 0)
			TweenService:Create(shoulder, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = base }):Play()
		end
		local tool = character:FindFirstChildOfClass("Tool")
		local muzzle = tool and tool:FindFirstChild("Muzzle", true)
		if muzzle and muzzle:IsA("BasePart") then
			local flash = Instance.new("PointLight")
			flash.Color = BLUE
			flash.Brightness = 6
			flash.Range = 8
			flash.Parent = muzzle
			local was = muzzle.Transparency
			muzzle.Transparency = 0
			task.delay(0.07, function()
				flash:Destroy()
				muzzle.Transparency = was
			end)
		end
	end)
end

local function shoot(direction: Vector3)
	if not fighting() then
		return
	end
	recoil()
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
	-- (Build 87: the shot leaves from the guest's head, as the server fires it, toward the point
	-- under the aim: the camera's own ray started behind the guest, so a shot along it from the
	-- head passed beside what was aimed at, wider the nearer it was.)
	local ok, direction = pcall(function()
		local camera = Workspace.CurrentCamera :: Camera
		local at = position or (camera.ViewportSize / 2)
		local ray = camera:ViewportPointToRay(at.X, at.Y)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") then
			return ray.Direction
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local skip: { Instance } = {}
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(skip, p.Character)
			end
		end
		params.FilterDescendantsInstances = skip
		local hit = Workspace:Raycast(ray.Origin, ray.Direction * 400, params)
		local point = if hit then hit.Position else ray.Origin + ray.Direction * 400
		local head = root.Position + Vector3.new(0, 1.5, 0)
		local d = point - head
		return if d.Magnitude > 1 then d.Unit else ray.Direction
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

-- (Build 98) What a shot fired now would stun, boxed in the world before the click: the same line
-- the shot takes (from the head toward the point under the aim, past every guest, as far as the
-- pistol reaches), then the same near-miss allowance the server gives. Gold around a target this
-- phase is about; red around anything else in the way (a wall, his shield, a briefcase), so a shot
-- that would land on the wrong thing is seen as wrong before it's fired. The server still decides.
local aimBox: SelectionBox? = nil
local function want(): string?
	local phase = tostring(view.phase or "")
	return if phase == "shield" then "gen" elseif phase == "detail" then "guard" elseif phase == "boss" then "boss" else nil
end
local function taggedOf(inst: Instance?): (Instance?, string?)
	local at = inst
	while at and at ~= Workspace do
		local tag = at:GetAttribute("ExecTarget")
		if type(tag) == "string" then
			-- (The whole figure, not the one limb: its model when it has one.)
			local model = at:FindFirstAncestorWhichIsA("Model")
			if model and model:GetAttribute("ExecTarget") == tag then
				return model, tag
			end
			return at, tag
		end
		at = at.Parent
	end
	return nil, nil
end
function ExecutiveHud.aimAt(position: Vector2?): (Instance?, boolean)
	local wanted = want()
	if not wanted then
		return nil, false
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil, false
	end
	local head = root.Position + Vector3.new(0, 1.5, 0)
	local dir = aimFromScreen(position)
	local range = tonumber((((Config.data :: any).Attractions or {}).executive or {}).range) or 140
	local skip: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	if aimBox then
		table.insert(skip, aimBox)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = skip
	local hit = Workspace:Raycast(head, dir * range, params)
	if hit then
		local thing, tag = taggedOf(hit.Instance)
		if thing and tag and string.sub(tag, 1, #wanted) == wanted then
			return thing, true
		end
	end
	-- (Nothing tagged on the line: the near miss the server allows, on what this phase is about.)
	local best, bestAlong = nil, math.huge
	for _, inst in CollectionService:GetTagged("ExecHp") do
		local id = inst:GetAttribute("ExecTarget")
		local hp = tonumber(inst:GetAttribute("Hp")) or 0
		if type(id) == "string" and string.sub(id, 1, #wanted) == wanted and hp > 0 and inst.Parent then
			local at: Vector3? = nil
			local radius = 2.5
			if inst:IsA("BasePart") then
				at = inst.Position
				if wanted == "gen" then
					radius = math.max(inst.Size.X, inst.Size.Z) / 2 + 1.5
				end
			elseif inst:IsA("Model") then
				at = inst:GetPivot().Position
			end
			if at then
				local rel = at - head
				local along = rel:Dot(dir)
				local blocked = hit ~= nil and (hit.Position - head).Magnitude < along - radius
				if along > 0 and along <= range and not blocked and (rel - dir * along).Magnitude <= radius + along * 0.02 and along < bestAlong then
					best, bestAlong = inst, along
				end
			end
		end
	end
	if best then
		local thing = taggedOf(best)
		return thing or best, true
	end
	if hit and hit.Instance and (hit.Position - head).Magnitude < range then
		return hit.Instance, false
	end
	return nil, false
end
local function aimPoint(): Vector2?
	if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
		local ok, m = pcall(function()
			return UserInputService:GetMouseLocation()
		end)
		return if ok and typeof(m) == "Vector2" then m else nil
	end
	return nil
end
function ExecutiveHud.updateAim()
	local ok, thing, good = pcall(ExecutiveHud.aimAt, aimPoint())
	if not ok or not thing or not fighting() then
		local was = aimBox
		if was then
			was.Visible = false
			pcall(function()
				was.Adornee = nil
			end)
		end
		local cross = parts.cross :: Frame?
		if cross then
			for _, line in cross:GetChildren() do
				if line:IsA("Frame") then
					line.BackgroundColor3 = Color3.new(1, 1, 1)
				end
			end
		end
		return
	end
	local box: SelectionBox = aimBox or (function()
		local b = Instance.new("SelectionBox")
		b.Name = "MaisonAimBox"
		b.LineThickness = 0.09
		b.SurfaceTransparency = 0.86
		b.Parent = Root.hud
		return b
	end)()
	aimBox = box
	local colour = if good then GOLD else RED
	box.Adornee = thing :: any
	box.Color3 = colour
	box.SurfaceColor3 = colour
	box.Visible = true
	local cross = parts.cross :: Frame?
	if cross then
		for _, line in cross:GetChildren() do
			if line:IsA("Frame") then
				line.BackgroundColor3 = if good then GOLD else Color3.new(1, 1, 1)
			end
		end
	end
end
function ExecutiveHud.aimBox(): SelectionBox?
	return aimBox
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

-- Caught (Build 82): the moment for Chronos Defiance, over the middle of the screen. What happened
-- and where a revive puts you back, the moment's countdown (paused while Roblox's purchase window
-- is open), and the keys: a revive held, or one bought (its Robux price on the key), or Leave.
-- Everything on it is what the server said; the server alone decides whether you're back in.
local ROBUX = utf8.char(0xE002)
local CAUGHT = "ExecutiveCaught"
local caughtCard: Frame? = nil
local caughtView: { [string]: any } = {}

local function hideCaught()
	local c = caughtCard
	if c then
		local shade = c.Parent
		c:Destroy()
		if shade and shade:IsA("Frame") and shade.Name == CAUGHT then
			shade:Destroy()
		end
	end
	caughtCard = nil
	caughtView = {}
end

local function caughtKeys()
	local c = caughtCard
	local m = caughtView
	if not c then
		return
	end
	local row = c:FindFirstChild("Keys") :: Frame?
	if not row then
		return
	end
	for _, k in row:GetChildren() do
		if k:IsA("GuiButton") or k:IsA("TextLabel") then
			k:Destroy()
		end
	end
	local held = tonumber(m.held) or 0
	local busy = false
	local function askRevive()
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local r = ask({ op = "act", id = "executive", act = "revive" })
			busy = false
			if not r or r.ok ~= true then
				Toast.show("Chronos Defiance", if r and type(r.why) == "string" then r.why else "Not just now.", 3)
			end
		end)
	end
	local w = math.floor((c.Size.X.Offset - 36 - 10) / 2)
	if m.prompting then
		Theme.text(row, "The purchase window is open", 13, "body", { LayoutOrder = 1, Size = UDim2.fromOffset(w, 44), TextColor3 = C.smoke })
	elseif held > 0 then
		local k = Theme.key(row, string.format("Use a revive (%d)", held), true, askRevive, w)
		k.LayoutOrder = 1
	elseif m.onSale and tonumber(m.price) then
		local k = Theme.key(row, string.format("Revive  %s %d", ROBUX, tonumber(m.price) :: number), true, askRevive, w)
		k.LayoutOrder = 1
	end
	local leave = Theme.key(row, "Leave", false, function()
		task.spawn(function()
			ask({ op = "act", id = "executive", act = "leaveCaught" })
		end)
	end, w)
	leave.LayoutOrder = 2
end

local function showCaught(m: { [string]: any })
	caughtView = m
	caughtView.endsAt = os.clock() + (tonumber(m.left) or 0)
	if caughtCard then
		caughtKeys()
		return
	end
	local size = Root.size()
	local shade = Instance.new("Frame")
	shade.Name = CAUGHT
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.5
	shade.BorderSizePixel = 0
	shade.ZIndex = 20
	shade.Active = true
	shade.Parent = Root.hud
	local w = math.min(380, math.max(280, size.X - 32))
	local c = Instance.new("Frame")
	c.Name = "Card"
	c.AnchorPoint = Vector2.new(0.5, 0.5)
	c.Position = UDim2.fromScale(0.5, 0.5)
	c.Size = UDim2.fromOffset(w, 236)
	c.ZIndex = 21
	c.Parent = shade
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 18)
	pad.PaddingRight = UDim.new(0, 18)
	pad.PaddingTop = UDim.new(0, 16)
	pad.Parent = c
	HudCard.style(c, RED)
	local office = m.where == "office"
	label(c, "Kicker", "SECURITY", 11, Brand.Fonts.heavy, RED, 0).ZIndex = 22
	label(c, "Title", if office then "Out of health" else "You've been seen", 24, Brand.Fonts.display, C.bone, 18).ZIndex = 22
	local line = label(c, "Line", if office then "A revive puts you back just inside the Office, health full." else "A revive puts you back at the lift, with every digit you've read.", 13, Brand.Fonts.body, C.smoke, 54)
	line.TextWrapped = true
	line.TextTruncate = Enum.TextTruncate.None
	line.Size = UDim2.new(1, 0, 0, 36)
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.ZIndex = 22
	-- The moment's countdown: a bar running down and the seconds left.
	local fill = bar(c, "Moment", 104, RED)
	fill.Size = UDim2.fromScale(1, 1)
	local track = fill.Parent :: Frame
	track.ZIndex = 22
	fill.ZIndex = 23
	label(c, "Left", "", 12, Brand.Fonts.figures, C.bone, 114, Enum.TextXAlignment.Right).ZIndex = 22
	label(c, "Uses", "", 12, Brand.Fonts.bodyBold, C.smoke, 114).ZIndex = 22
	local row = Instance.new("Frame")
	row.Name = "Keys"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 142)
	row.Size = UDim2.new(1, 0, 0, 44)
	row.ZIndex = 22
	row.Parent = c
	Theme.list(row, 10, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local note = label(c, "Note", "Leave, or let the moment pass, and security shows you out.", 11, Brand.Fonts.body, C.dim, 196)
	note.TextWrapped = true
	note.TextTruncate = Enum.TextTruncate.None
	note.ZIndex = 22
	caughtCard = c
	caughtKeys()
	pcall(function()
		Sound.play("lowHit", 0.6)
	end)
end

-- Kept up to the moment (from the card's heartbeat).
local function tickCaught()
	local c = caughtCard
	if not c then
		return
	end
	local m = caughtView
	local total = math.max(1, tonumber(m.left) or 1)
	local remaining = if m.prompting then total else math.max(0, (m.endsAt or 0) - os.clock())
	local track = c:FindFirstChild("Moment") :: Frame?
	local fill = track and track:FindFirstChild("Fill") :: Frame?
	if fill then
		fill.Size = UDim2.fromScale(math.clamp(remaining / total, 0, 1), 1)
	end
	local left = c:FindFirstChild("Left") :: TextLabel?
	if left then
		left.Text = if m.prompting then "Paused" else string.format("%ds", math.ceil(remaining))
	end
	local uses = c:FindFirstChild("Uses") :: TextLabel?
	if uses then
		local n = tonumber(m.usesLeft) or 0
		uses.Text = string.format("%d revive%s left this run", n, if n == 1 then "" else "s")
	end
end
ExecutiveHud.tickCaught = tickCaught
ExecutiveHud.caughtCard = function(): Frame?
	return caughtCard
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
	c.Size = UDim2.fromOffset(CARD_W, CARD_H)
	c.Parent = Root.hud
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 9)
	pad.Parent = c
	HudCard.style(c, BLUE)
	label(c, "Title", "THE EXECUTIVE SUITE", 11, Brand.Fonts.heavy, GOLD, 0)
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
	strip.AnchorPoint = Vector2.new(0, 1)
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(4 * 52 + 3 * 8, STRIP_H)
	strip.Visible = false
	strip.Parent = Root.hud
	local slots: { TextLabel } = {}
	for k = 1, 4 do
		local s = Instance.new("TextLabel")
		s.Name = "Slot" .. k
		s.Size = UDim2.fromOffset(52, STRIP_H)
		s.Position = UDim2.fromOffset((k - 1) * 60, 0)
		s.BackgroundColor3 = HudCard.BACKGROUND
		s.BackgroundTransparency = 0.06
		s.FontFace = Brand.Fonts.display
		s.TextSize = 36
		s.TextColor3 = C.smoke
		s.Text = "?"
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(0, 10)
		sc.Parent = s
		local ss = Instance.new("UIStroke")
		ss.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		ss.Color = BLUE
		ss.Thickness = 1
		ss.Transparency = 0.5
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
	keys = k
	place()
	draw()
	table.insert(conns, Root.TopChanged:Connect(place))
	-- (The wind-up's line and the extraction's minute kept up to the moment.)
	local tick = 0
	table.insert(conns, RunService.Heartbeat:Connect(function(dt: number)
		tick += dt
		if fighting() or aimBox then
			ExecutiveHud.updateAim()
		end
		if tick >= 0.2 then
			tick = 0
			pcall(ExecutiveHud.bars)
			tickCaught()
			if windup or view.phase == "won" then
				draw()
				local w = windup
				if w and now() >= w.untilAt then
					windup = nil
				end
			end
		end
	end))
	-- A click aims where it lands; so does a tap on a touch screen (a tap, not a drag of the
	-- camera or the thumbstick: Roblox says which).
	table.insert(conns, UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed or not fighting() then
			return
		end
		-- (With the pistol in hand, the click is the pistol's own: it fires once, from there.)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and not pistolInHand() then
			shoot(aimFromScreen(Vector2.new(input.Position.X, input.Position.Y)))
		end
	end))
	table.insert(conns, UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processedByUI: boolean)
		if processedByUI or not fighting() then
			return
		end
		shoot(aimFromScreen(position))
	end))
end

function ExecutiveHud.unmount()
	ExecutiveHud.clearBars()
	if aimBox then
		aimBox:Destroy()
		aimBox = nil
	end
	hideCaught()
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
		-- (Build 94) A gold streak behind each one, so it reads from across the room.
		pcall(function()
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(-0.9, 0, 0)
			a0.Parent = part
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0.9, 0, 0)
			a1.Parent = part
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.25
			trail.LightEmission = 0.8
			trail.Color = ColorSequence.new(GOLD, RED)
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = part
			local glow = Instance.new("PointLight")
			glow.Color = GOLD
			glow.Brightness = 1.5
			glow.Range = 6
			glow.Parent = part
		end)
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
			-- (Build 94) It thins as it goes, and the room shakes as it passes.
			part.Transparency = 0.35 + 0.55 * math.clamp(age / life, 0, 1)
		end
	end)
end

-- (Build 87) A hit: a small gold X on the crosshair for a moment (the shooter's own only).
local function hitMark(target: string)
	local layer = Root.hud
	local mark = Instance.new("TextLabel")
	mark.Name = "HitMark"
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.Size = UDim2.fromOffset(44, 44)
	mark.BackgroundTransparency = 1
	mark.FontFace = Brand.Fonts.heavy
	mark.TextSize = 30
	mark.TextColor3 = if string.sub(target, 1, 4) == "boss" then RED else GOLD
	mark.Text = "✕"
	mark.ZIndex = 40
	mark.Parent = layer
	TweenService:Create(mark, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { TextTransparency = 1, Size = UDim2.fromOffset(60, 60) }):Play()
	task.delay(0.4, function()
		mark:Destroy()
	end)
	pcall(Sound.play, "chime", 0.25)
end

-- (Build 94) The fight's effects, all on this screen only and all where the server said: sparks,
-- a puff of smoke, a number off what was hit, the room shaking, a red edge when you're hurt.
local function spark(at: Vector3, colour: Color3, count: number, speed: number?, size: number?)
	local go = speed or 22
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Name = "Spark"
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = colour
		local z = (size or 0.35) * (0.6 + math.random() * 0.8)
		p.Size = Vector3.new(z, z, z * 2.2)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8, math.random() - 0.5)
		dir = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.yAxis
		p.CFrame = CFrame.lookAt(at, at + dir)
		p.Parent = Workspace
		table.insert(effects, p)
		local life = 0.25 + math.random() * 0.3
		TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(at + dir * go * life, at + dir * (go * life + 1)),
			Size = Vector3.new(0.05, 0.05, 0.05),
			Transparency = 1,
		}):Play()
		task.delay(life + 0.05, function()
			p:Destroy()
		end)
	end
end
ExecutiveHud.spark = spark

local function puff(at: Vector3, colour: Color3, radius: number, life: number?)
	local p = Instance.new("Part")
	p.Name = "Puff"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.SmoothPlastic
	p.Color = colour
	p.Transparency = 0.25
	p.Size = Vector3.new(1, 1, 1)
	p.CFrame = CFrame.new(at)
	p.Parent = Workspace
	table.insert(effects, p)
	local t = life or 0.6
	TweenService:Create(p, TweenInfo.new(t, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(radius * 2, radius * 2, radius * 2), Transparency = 1 }):Play()
	task.delay(t + 0.05, function()
		p:Destroy()
	end)
end

-- The camera shaken for a moment (by the guest's own camera offset, so it's never left moved).
local shakeUntil = 0
local shakeHard = 0
local function shake(strength: number, seconds: number)
	shakeHard = math.max(if os.clock() < shakeUntil then shakeHard else 0, strength)
	local was = shakeUntil
	shakeUntil = math.max(shakeUntil, os.clock() + seconds)
	if was > os.clock() then
		return
	end
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local left = shakeUntil - os.clock()
		if left <= 0 or not humanoid then
			if humanoid then
				humanoid.CameraOffset = Vector3.zero
			end
			if conn then
				conn:Disconnect()
			end
			return
		end
		local k = shakeHard * math.clamp(left / 0.25, 0, 1)
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, 0)
	end)
	table.insert(conns, conn :: RBXScriptConnection)
end
ExecutiveHud.shake = shake

-- A red edge round the screen, gone in a moment: you've been hit.
local function flash(colour: Color3, strength: number)
	local f = Instance.new("Frame")
	f.Name = "HurtFlash"
	f.BackgroundTransparency = 1
	f.Size = UDim2.fromScale(1, 1)
	f.ZIndex = 30
	f.Parent = Root.hud
	local edge = Instance.new("UIStroke")
	edge.Color = colour
	edge.Thickness = 28
	edge.Transparency = 1 - strength
	edge.Parent = f
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = colour
	fill.BackgroundTransparency = 1 - strength * 0.3
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = f
	TweenService:Create(edge, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
	TweenService:Create(fill, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	task.delay(0.55, function()
		f:Destroy()
	end)
end

-- Where a target stands now, from what the server tagged (its "ExecTarget").
local function targetAt(target: string): Vector3?
	for _, inst in CollectionService:GetTagged("ExecHp") do
		if inst:GetAttribute("ExecTarget") == target or (inst:IsA("Model") and target == "boss" and inst.Name == "TheExecutive") then
			if inst:IsA("BasePart") then
				return inst.Position
			elseif inst:IsA("Model") then
				local ok, cf = pcall(function()
					return inst:GetPivot()
				end)
				if ok then
					return cf.Position
				end
			end
		end
	end
	return nil
end

-- A number off what was hit, rising and fading where it was hit.
local function popNumber(at: Vector3, text: string, colour: Color3)
	local anchor = Instance.new("Part")
	anchor.Name = "HitNumber"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(at + Vector3.new((math.random() - 0.5) * 2, 3, 0))
	anchor.Parent = Workspace
	table.insert(effects, anchor)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 44)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Brand.Fonts.heavy
	label.TextSize = 30
	label.TextColor3 = colour
	label.TextStrokeTransparency = 0.2
	label.Text = text
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.85, function()
		anchor:Destroy()
	end)
end

local function damage(): number
	local c = (((Config.data :: any).Attractions or {}).executive or {}) :: { [string]: any }
	return math.floor(tonumber(c.damage) or 10)
end

local function tracer(m: { [string]: any })
	if typeof(m.from) ~= "Vector3" or typeof(m.dir) ~= "Vector3" then
		return
	end
	local mine = m.by == Players.LocalPlayer.UserId
	if mine and type(m.hit) == "string" then
		hitMark(m.hit)
	end
	-- (Build 94) How far it went: to what it hit, or its full range.
	local length = 80
	local hitAt = if type(m.hit) == "string" then targetAt(m.hit) else nil
	if hitAt then
		length = math.clamp((hitAt - m.from):Dot(m.dir), 4, 160)
	end
	local tip = m.from + m.dir * length
	local function bolt(width: number, colour: Color3, transparency: number, life: number)
		local beam = Instance.new("Part")
		beam.Name = "Tracer"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = colour
		beam.Transparency = transparency
		beam.Size = Vector3.new(width, width, length)
		beam.CFrame = CFrame.lookAt(m.from + m.dir * length / 2, tip)
		beam.Parent = Workspace
		table.insert(effects, beam)
		TweenService:Create(beam, TweenInfo.new(life, Enum.EasingStyle.Quad), { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, length) }):Play()
		task.delay(life + 0.02, function()
			beam:Destroy()
		end)
	end
	-- A white-hot core inside a blue glow, and a flash where it left the muzzle.
	bolt(0.14, Color3.fromRGB(235, 248, 255), 0, 0.09)
	bolt(0.5, BLUE, 0.55, 0.16)
	puff(m.from + m.dir * 2, BLUE, 1.2, 0.12)
	if hitAt then
		-- On target: a burst of sparks, a ring of light, the stun's number off it.
		local colour = if string.sub(m.hit, 1, 4) == "boss" then RED elseif string.sub(m.hit, 1, 3) == "gen" then BLUE else GOLD
		spark(tip, colour, if mine then 10 else 5, 24, 0.35)
		spark(tip, Color3.fromRGB(255, 255, 255), 3, 14, 0.25)
		puff(tip, colour, 2.2, 0.25)
		if mine then
			popNumber(tip, "-" .. damage(), colour)
			shake(0.12, 0.08)
		end
	else
		spark(tip, BLUE, 3, 10, 0.2)
	end
end

-- (Build 90) Tonight's look and challenge, said once a run; a challenge missed, said once.
local toldRun: string? = nil
local toldMissed = false

function ExecutiveHud.on(m: { [string]: any })
	local op = m.op
	if op == "executive" then
		local before = fighting()
		local key = tostring(m.look) .. ":" .. tostring(m.challenge)
		if type(m.challengeName) == "string" and m.phase == "hall" and toldRun ~= key then
			toldRun = key
			toldMissed = false
			Toast.show("Tonight: " .. tostring(m.lookName or "the Suite"), string.format("Challenge: %s. %s +%s Gilt.", m.challengeName, tostring(m.challengeLine or ""), Rules.format(tonumber(m.challengeGilt) or 0)), 6)
		elseif type(m.challengeName) == "string" and m.onCourse == false and not toldMissed and m.phase ~= "won" then
			toldMissed = true
			Toast.show("Challenge missed", string.format("%s is out of reach this run. Beat him all the same.", m.challengeName), 3.5)
		end
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
			Moment.show({ kicker = "The Executive Suite", title = m.name, line = tostring(m.line or ""), tone = Color3.fromRGB(236, 104, 92), seconds = 4 })
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
		Moment.show({ kicker = "The Executive Suite", title = "A clean getaway", line = "+" .. Rules.format(tonumber(m.gilt) or 0) .. " Gilt", tone = GOLD, seconds = 4, sound = "chime", volume = 0.6 })
	elseif op == "alarm" then
		if not m.revive then
			Toast.show("Security", "You were seen too long: you've been shown out. The invitation is spent.", 5)
		end
	elseif op == "escorted" then
		if not m.revive then
			Toast.show("Escorted out", "No health left. Try again with another invitation.", 5)
		end
	elseif op == "caught" or op == "caughtUpdate" then
		showCaught(m)
		tickCaught()
	elseif op == "revived" then
		hideCaught()
		Toast.show("Back in", if m.where == "office" then "Health full. He's still waiting." else "The alert is down, and your digits are kept.", 3)
		pcall(function()
			Sound.play("chime", 0.8)
		end)
	elseif op == "caughtEnd" then
		hideCaught()
		Toast.show("Security", "The moment passed: you've been shown out.", 4)
	elseif op == "won" then
		-- (Build 102) The Gilt to your balance first, then how much richer it makes you: no Estate.
		local line = string.format("+%s Gilt  ·  your Fortune +%s", Rules.format(tonumber(m.gilt) or 0), Rules.format(tonumber(m.worth) or 0))
		if m.brainrot then
			line ..= "  ·  Il Dirigente Supremo for your collection"
		end
		-- (Build 103) The boss beaten: the house's biggest moment in the Suite, standing a while.
		Moment.burst(GOLD, true)
		Moment.show({ kicker = "The Executive Suite", title = "The Executive, beaten", line = line .. ". The safe is open, and the lift down.", tone = GOLD, seconds = 6, big = true, value = tonumber(m.gilt), sound = "shimmerFall", volume = 0.7 })
		if type(m.challenge) == "string" and m.challengeMet then
			task.delay(2, function()
				Sound.play("crystal", 0.7)
				Toast.show("Challenge met: " .. m.challenge, "+" .. Rules.format(tonumber(m.challengeGilt) or 0) .. " Gilt", 4)
			end)
		end
	elseif op == "safe" then
		Toast.show("The safe", "Your Fortune +" .. Rules.format(tonumber(m.worth) or 0) .. ".", 3)
		pcall(Sound.play, "crystal", 0.7)
	elseif op == "loot" then
		local line = "Your Fortune +" .. Rules.format(tonumber(m.worth) or 0)
		if (tonumber(m.gilt) or 0) > 0 then
			line = "+" .. Rules.format(tonumber(m.gilt) or 0) .. " Gilt  ·  your Fortune +" .. Rules.format(tonumber(m.worth) or 0)
		end
		Toast.show(tostring(m.name or "Loot"), line .. ".", 3)
		pcall(Sound.play, "crystal", 0.6)
		local spot = Plan.lootById[tostring(m.loot)]
		if spot then
			local at = AttractionList.origin("executive") + spot.at + Vector3.new(0, 3, 0)
			spark(at, GOLD, 16, 16, 0.4)
			puff(at, GOLD, 3, 0.4)
		end
	elseif op == "hurt" then
		-- (Build 94) Hit: the screen's edge flashes red and the room jolts, harder for a bigger hit.
		local amount = tonumber(m.amount) or 10
		flash(RED, math.clamp(0.35 + amount / 50, 0.35, 0.8))
		shake(math.clamp(amount / 12, 0.6, 2.2), 0.3)
		pcall(Sound.play, "lowHit", 0.5)
	elseif op == "attack" then
		-- (Build 94) His attacks land with weight: the room shakes, the dash leaves a streak.
		local kind = tostring(m.kind)
		shake(if kind == "dash" then 1.2 elseif kind == "spin" then 0.9 else 0.5, 0.35)
		local at = targetAt("boss")
		if at then
			spark(at, if kind == "dash" then RED else GOLD, if kind == "spin" then 18 else 10, 26, 0.4)
			if kind == "dash" or kind == "spin" then
				puff(at, RED, 4, 0.35)
			end
		end
		pcall(Sound.play, "lowHit", 0.45)
	elseif op == "bossGone" then
		-- (Build 94) Through the door and gone: a puff of smoke where he went, a door slammed.
		local at = if typeof(m.door) == "Vector3" then m.door elseif typeof(m.at) == "Vector3" then m.at else nil
		if at then
			puff(at + Vector3.new(0, 3, 0), Color3.fromRGB(70, 70, 76), 5, 0.9)
			spark(at + Vector3.new(0, 3, 0), GOLD, 12, 14, 0.3)
		end
		shake(0.6, 0.25)
		pcall(Sound.play, "lowHit", 0.6)
		Toast.show("He's gone", "Out through his bodyguards' door. The Office is yours to raid: the safe, the drawers, the bullion, the watches, his briefcase.", 5)
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

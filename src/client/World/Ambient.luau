--!strict
-- The house around you, on your screen: doors that swing open as you approach, room names that
-- fade in and out in each doorway, the Doorman's "Evening.", staff who turn to look at you,
-- the fire's flicker, weather in the street air, and the acoustics of each space.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Layout = require(ReplicatedStorage.Shared.Layout)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Voice = require(ReplicatedStorage.Shared.Voice)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Dialogue = require(script.Parent.Parent.UI.Dialogue)
local Toast = require(script.Parent.Parent.UI.Toast)

local Ambient = {}

local player = Players.LocalPlayer

type Door = { leaves: { BasePart }, hinges: { CFrame }, open: boolean, centre: Vector3, radius: number, value: NumberValue }

local doors: { Door } = {}
local names: { { gui: SurfaceGui, position: Vector3 } } = {}
local zoneChanged = Instance.new("BindableEvent")
Ambient.ZoneChanged = zoneChanged.Event
Ambient.zone = "none"

local function rootPosition(): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function addDoor(model: Model, radius: number)
	local leaves: { BasePart } = {}
	local hinges: { CFrame } = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d:GetAttribute("Hinge") ~= nil then
			table.insert(leaves, d)
			table.insert(hinges, d:GetAttribute("Hinge") :: CFrame)
		end
	end
	if #leaves == 0 then
		return
	end
	local centre = (hinges[1].Position + (hinges[2] or hinges[1]).Position) / 2
	local value = Instance.new("NumberValue")
	value.Value = 0
	local door: Door = { leaves = leaves, hinges = hinges, open = false, centre = centre, radius = radius, value = value }
	-- Each leaf keeps its offset from its hinge; the angle swings it inward (away from the viewer).
	local offsets: { CFrame } = {}
	for i, leaf in leaves do
		offsets[i] = hinges[i]:ToObjectSpace(leaf.CFrame)
	end
	-- The panel insets ride along with their leaf.
	local riders: { { part: BasePart, leaf: number, offset: CFrame } } = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Inset" or d.Name == "Knob") then
			local nearest, bestDistance = 1, math.huge
			for i, leaf in leaves do
				local distance = (leaf.Position - d.Position).Magnitude
				if distance < bestDistance then
					nearest, bestDistance = i, distance
				end
			end
			table.insert(riders, { part = d, leaf = nearest, offset = leaves[nearest].CFrame:ToObjectSpace(d.CFrame) })
		end
	end
	value.Changed:Connect(function(angle)
		for i, leaf in leaves do
			local side = (leaf:GetAttribute("Side") :: number?) or 1
			leaf.CFrame = hinges[i] * CFrame.Angles(0, math.rad(angle * side), 0) * offsets[i]
		end
		for _, r in riders do
			r.part.CFrame = leaves[r.leaf].CFrame * r.offset
		end
	end)
	table.insert(doors, door)
end

local wired: { [Instance]: boolean } = {}
local gated: { [string]: Model } = {}

-- An earned door (the Midnight Room): on this guest's screen only, the rope comes down and the
-- doors open. The server still checks the unlock before anyone can sit.
local function openGate(model: Model)
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			if d:GetAttribute("Gated") then
				d.CanCollide = false
			elseif d.Name == "Stanchion" or d.Name == "StanchionTop" or d.Name == "Rope" then
				d.LocalTransparencyModifier = 1
				d.CanCollide = false
			end
		end
	end
	addDoor(model, 11)
end

local function wire(tag: string, instance: Instance)
	if wired[instance] then
		return
	end
	wired[instance] = true
	if tag == "FrontDoors" and instance:IsA("Model") then
		addDoor(instance, 16)
	elseif tag == "RoomDoor" and instance:IsA("Model") and instance:GetAttribute("Open") == true then
		addDoor(instance, 11)
	elseif tag == "RoomDoor" and instance:IsA("Model") then
		local room = instance:GetAttribute("Room")
		if type(room) == "string" then
			gated[room] = instance
			if State.unlocked[room] then
				openGate(instance)
			end
		end
	elseif tag == "RoomName" and instance:IsA("BasePart") then
		local gui = instance:FindFirstChildOfClass("SurfaceGui") or instance:WaitForChild("SurfaceGui", 5)
		if gui and gui:IsA("SurfaceGui") then
			for _, l in gui:GetDescendants() do
				if l:IsA("TextLabel") then
					l.TextTransparency = 1
				end
			end
			table.insert(names, { gui = gui, position = instance.Position })
		end
	end
end

State.Unlocked:Connect(function(room: string)
	local model = gated[room]
	if model then
		gated[room] = nil
		openGate(model)
	end
end)

-- The Velvet Room's case clock keeps the guest's own time; its pendulum swings.
local clockModel: Model? = nil
local function stepCaseClock(t: number)
	local model = clockModel
	if not model or not model.Parent then
		local maison = Workspace:FindFirstChild("Maison")
		local velvet = maison and maison:FindFirstChild("Velvet")
		local found = velvet and velvet:FindFirstChild("CaseClock")
		clockModel = if found and found:IsA("Model") then found else nil
		model = clockModel
		if not model then
			return
		end
	end
	local now = os.date("*t")
	local minuteAngle = (now.min + now.sec / 60) / 60 * math.pi * 2
	local hourAngle = ((now.hour % 12) + now.min / 60) / 12 * math.pi * 2
	local hands: { { name: string, angle: number, reach: number } } = {
		{ name = "HourHand", angle = hourAngle, reach = 0.25 },
		{ name = "MinuteHand", angle = minuteAngle, reach = 0.4 },
	}
	for _, spec in hands do
		local hand = (model :: Model):FindFirstChild(spec.name)
		if hand and hand:IsA("BasePart") then
			local pivot = hand:GetAttribute("Pivot")
			if typeof(pivot) == "CFrame" then
				hand.CFrame = pivot * CFrame.Angles(0, 0, spec.angle) * CFrame.new(0, spec.reach, 0)
			end
		end
	end
	local swing = math.sin(t * math.pi) * 0.16
	local pendulum = (model :: Model):FindFirstChild("Pendulum")
	local bob = (model :: Model):FindFirstChild("Bob")
	if pendulum and pendulum:IsA("BasePart") then
		local pivot = pendulum:GetAttribute("Pivot")
		if typeof(pivot) == "CFrame" then
			local swung = pivot * CFrame.Angles(0, 0, swing)
			pendulum.CFrame = swung * CFrame.new(0, -1.5, 0)
			if bob and bob:IsA("BasePart") then
				bob.CFrame = swung * CFrame.new(0, -3, 0)
			end
		end
	end
end

local function setupDoors()
	for _, tag in { "FrontDoors", "RoomDoor", "RoomName" } do
		for _, instance in CollectionService:GetTagged(tag) do
			task.spawn(wire, tag, instance)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			-- Give the model's children a moment to arrive with it.
			task.delay(0.5, wire, tag, instance)
		end)
	end
end

local function updateDoors(pos: Vector3)
	for _, door in doors do
		local near = (pos - door.centre).Magnitude < door.radius
		if near ~= door.open then
			door.open = near
			TweenService:Create(door.value, TweenInfo.new(if near then 1.1 else 1.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = if near then 82 else 0 }):Play()
			if near then
				Sound.play("door", 0.25, 0.9)
			end
		end
	end
end

local nameShown: { [SurfaceGui]: boolean } = {}
local function updateNames(pos: Vector3)
	for _, n in names do
		local d = (pos - n.position).Magnitude
		-- Shown as you approach, faded once you're through.
		local show = d < 20 and d > 3.5
		if nameShown[n.gui] ~= show then
			nameShown[n.gui] = show
			for _, l in n.gui:GetDescendants() do
				if l:IsA("TextLabel") then
					TweenService:Create(l, TweenInfo.new(if show then 0.9 else 1.4, Enum.EasingStyle.Sine), { TextTransparency = if show then 0 else 1 }):Play()
				end
			end
		end
	end
end

-- Staff turn their heads to look at you when you come near.
local function staffLook(pos: Vector3)
	local folder = Workspace:FindFirstChild("Maison")
	local staff = folder and folder:FindFirstChild("Staff")
	if not staff then
		return
	end
	for _, npc in staff:GetChildren() do
		local head = npc:FindFirstChild("Head")
		local neck = head and head:FindFirstChild("Neck")
		local root = npc:FindFirstChild("HumanoidRootPart")
		if neck and neck:IsA("Motor6D") and root and root:IsA("BasePart") then
			local base = neck:GetAttribute("BaseC0")
			if typeof(base) ~= "CFrame" then
				neck:SetAttribute("BaseC0", neck.C0)
				base = neck.C0
			end
			local toMe = pos - root.Position
			local flat = Vector3.new(toMe.X, 0, toMe.Z)
			local goal = base :: CFrame
			if flat.Magnitude < 16 and flat.Magnitude > 0.5 then
				local localDir = root.CFrame:VectorToObjectSpace(flat.Unit)
				local yaw = math.atan2(-localDir.X, -localDir.Z)
				yaw = math.clamp(yaw, math.rad(-60), math.rad(60))
				goal = (base :: CFrame) * CFrame.Angles(0, yaw, 0)
			end
			neck.C0 = neck.C0:Lerp(goal, 0.08)
		end
	end
end

local greetedByDoorman = false
local function doorman(pos: Vector3)
	if greetedByDoorman or State.phase ~= "play" then
		return
	end
	local d = (pos - Vector3.new(Layout.Door.width / 2 + 1.8, 3, Layout.Street.facadeZ - 1.1)).Magnitude
	if d < 11 then
		greetedByDoorman = true
		Dialogue.show(Voice.Doorman.speaker, Voice.Doorman.evening, nil, nil, 2.2)
	end
end

-- Weather: small pooled pieces falling at two depths (a far layer and a nearer, bigger, fainter one).
type Flake = { part: Part, velocity: Vector3, sway: number, phase: number, near: boolean }
local flakes: { Flake } = {}
local weatherKind = ""
local rng = Random.new()

local function flakeShape(kind: string, near: boolean): (Vector3, Enum.Material, Enum.PartType)
	local s = if near then 1.6 else 1
	if kind == "snow" then
		return Vector3.new(0.14, 0.14, 0.14) * s, Enum.Material.SmoothPlastic, Enum.PartType.Ball
	elseif kind == "embers" or kind == "fireflies" then
		return Vector3.new(0.1, 0.1, 0.1) * s, Enum.Material.Neon, Enum.PartType.Ball
	elseif kind == "confetti" then
		return Vector3.new(0.18, 0.02, 0.1) * s, Enum.Material.SmoothPlastic, Enum.PartType.Block
	end
	-- leaves, petals, clover
	return Vector3.new(0.26, 0.02, 0.18) * s, Enum.Material.SmoothPlastic, Enum.PartType.Block
end

-- Weather falls for real in the street and on the Terrace.
local onTerrace = false
local function spawnPoint(camPos: Vector3): Vector3
	if onTerrace then
		local T = Layout.Terrace
		return Vector3.new(rng:NextNumber(T.minX, T.maxX), rng:NextNumber(T.floorY + 6, T.floorY + 22), rng:NextNumber(T.minZ, T.maxZ))
	end
	local x = math.clamp(camPos.X + rng:NextNumber(-45, 45), -75, 75)
	local z = rng:NextNumber(-64, -12)
	return Vector3.new(x, rng:NextNumber(12, 32), z)
end

local function resetFlake(f: Flake, camPos: Vector3, colours: { Color3 }, kind: string)
	f.part.Position = spawnPoint(camPos)
	f.part.Color = colours[rng:NextInteger(1, #colours)]
	local fall = if kind == "embers" or kind == "fireflies" then rng:NextNumber(-0.6, 0.8) else -rng:NextNumber(2.2, 4)
	if kind == "snow" then
		fall = -rng:NextNumber(1.6, 2.8)
	end
	f.velocity = Vector3.new(rng:NextNumber(-0.6, 0.6), fall * (if f.near then 1.35 else 1), rng:NextNumber(-0.4, 0.4))
	f.sway = rng:NextNumber(0.5, 1.6)
	f.phase = rng:NextNumber(0, math.pi * 2)
end

local function setupWeather()
	local folder = Instance.new("Folder")
	folder.Name = "Weather"
	folder.Parent = Workspace:FindFirstChild("MaisonLocal") or Workspace
	local function rebuild()
		local id = tostring(Workspace:GetAttribute("Season") or "")
		local season = Seasons.byId[id]
		if not season then
			return
		end
		weatherKind = season.weather
		for _, f in flakes do
			f.part:Destroy()
		end
		flakes = {}
		local density = State.get("atmosphere")
		local count = if density == "Off" then 0 elseif density == "Light" then 40 else 90
		for i = 1, count do
			local near = i % 3 == 0
			local size, material, shape = flakeShape(weatherKind, near)
			local p = Instance.new("Part")
			p.Shape = shape
			p.Size = size
			p.Material = material
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = if near then 0.35 else 0.1
			p.Parent = folder
			local f: Flake = { part = p, velocity = Vector3.zero, sway = 1, phase = 0, near = near }
			resetFlake(f, Vector3.new(0, 0, -30), season.weatherColours, weatherKind)
			f.part.Position = Vector3.new(f.part.Position.X, rng:NextNumber(0, 30), f.part.Position.Z)
			table.insert(flakes, f)
		end
	end
	rebuild()
	Workspace:GetAttributeChangedSignal("Season"):Connect(function()
		rebuild()
		local name = tostring(Workspace:GetAttribute("SeasonName") or "")
		local line = tostring(Workspace:GetAttribute("SeasonLine") or "")
		if name ~= "" and State.phase == "play" then
			Toast.show(name, line, 5)
		end
	end)
	State.SettingChanged:Connect(function(key)
		if key == "atmosphere" then
			rebuild()
		end
	end)
end

local weatherClock = 0
local function stepWeather(dt: number, camPos: Vector3)
	if #flakes == 0 then
		return
	end
	-- Only while the street is in view (from the street, or looking out from the doorway), or
	-- out on the Terrace.
	local terrace = Layout.inBox(Layout.Terrace.zone, camPos)
	if terrace ~= onTerrace then
		onTerrace = terrace
		for _, f in flakes do
			f.part.Position = spawnPoint(camPos)
		end
	end
	local inStreet = (camPos.Z < -4 and camPos.Z > -80) or terrace
	for _, f in flakes do
		f.part.LocalTransparencyModifier = if inStreet then 0 else 1
	end
	if not inStreet then
		return
	end
	weatherClock += dt
	local season = Seasons.byId[tostring(Workspace:GetAttribute("Season") or "")]
	local colours = if season then season.weatherColours else { Color3.new(1, 1, 1) }
	for _, f in flakes do
		local swayX = math.sin(weatherClock * f.sway + f.phase) * 0.6
		local p = f.part.Position + (f.velocity + Vector3.new(swayX, 0, 0)) * dt
		local T = Layout.Terrace
		local gone = if onTerrace
			then p.Y < T.floorY + 0.1 or p.Y > T.floorY + 30 or p.X < T.minX or p.X > T.maxX or p.Z < T.minZ or p.Z > T.maxZ
			else p.Y < 0.1 or p.Y > 40 or p.Z > -10.5
		if gone then
			resetFlake(f, camPos, colours, weatherKind)
		else
			if weatherKind == "leaves" or weatherKind == "petals" or weatherKind == "confetti" or weatherKind == "clover" then
				f.part.CFrame = CFrame.new(p) * CFrame.Angles(weatherClock * f.sway + f.phase, f.phase, weatherClock * 0.7)
			else
				f.part.Position = p
			end
		end
	end
end

-- The fire's flicker.
local function stepFlicker(t: number)
	for _, light in CollectionService:GetTagged("Flicker") do
		if light:IsA("PointLight") then
			local base = (light:GetAttribute("BaseBrightness") :: number?) or 2
			light.Brightness = base * (0.85 + 0.15 * math.noise(t * 3.1, light.Range) + 0.08 * math.sin(t * 11))
		end
	end
end

function Ambient.start()
	setupDoors()
	setupWeather()
	local t = 0
	RunService.Heartbeat:Connect(function(dt)
		t += dt
		local camera = Workspace.CurrentCamera
		if camera then
			stepWeather(dt, camera.CFrame.Position)
		end
		stepFlicker(t)
		stepCaseClock(t)
		local pos = rootPosition()
		if not pos then
			return
		end
		updateDoors(pos)
		updateNames(pos)
		staffLook(pos)
		doorman(pos)
		local zone = Layout.zoneAt(pos)
		if zone ~= Ambient.zone then
			Ambient.zone = zone
			Sound.enterZone(zone)
			zoneChanged:Fire(zone)
		end
	end)
end

return Ambient

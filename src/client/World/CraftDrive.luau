--!strict
-- (Build 104) At the helm of one of Luxury Island's rides (server/Attractions/IslandRides; the
-- rules are shared/IslandCraft): the server sits the guest at the helm and hands the ride to this
-- screen, which steers it with the same numbers the server checks it by.
--   Throttle and wheel   Roblox's own vehicle seat (W A S D, the thumbstick, a gamepad), or the
--                        keys read here when Roblox's controls aren't there to feed it
--   Up and down          (the helicopter) E and Q, R1 and L1, or the two keys on a touch screen
--   Getting off          jump, as from any seat: the server puts the ride away after a while
-- On the water a ride rides the sea's surface, rocking a little with its speed, and stops at the
-- shore; in the air it banks into its turns and leans into its speed. A small dash shows its
-- speed and how to get off.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Craft = require(ReplicatedStorage.Shared.IslandCraft)
local Ground = require(ReplicatedStorage.Shared.IslandGround)
local Config = require(ReplicatedStorage.Shared.Config)
local Brand = require(ReplicatedStorage.Shared.Brand)
local Root = require(script.Parent.Parent.UI.Root)

local CraftDrive = {}

local player = Players.LocalPlayer
local model: Model? = nil
local kind: Craft.Kind? = nil
local speed = 0
local yaw = 0
local lift = 0 -- (touch keys: -1, 0, 1)
local dash: Frame? = nil
local dashSpeed: TextLabel? = nil
local started = false

local function origin(): Vector3
	local o = ((Config.data :: any).Attractions.island or {}).origin
	if type(o) == "table" then
		return Vector3.new(o[1], o[2], o[3])
	end
	return Vector3.zero
end

local function keyAxis(plus: { Enum.KeyCode }, minus: { Enum.KeyCode }): number
	local v = 0
	local ok = pcall(function()
		for _, k in plus do
			if UserInputService:IsKeyDown(k) then
				v += 1
				break
			end
		end
		for _, k in minus do
			if UserInputService:IsKeyDown(k) then
				v -= 1
				break
			end
		end
	end)
	return if ok then v else 0
end

-- The dash: the ride's name, its speed, how to get off; up and down keys for a helicopter on a
-- touch screen.
local function key(parent: Instance, text: string, x: number, value: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = "Lift" .. (if value > 0 then "Up" else "Down")
	b.AutoButtonColor = true
	b.BackgroundColor3 = Color3.fromRGB(20, 16, 10)
	b.BackgroundTransparency = 0.1
	b.Size = UDim2.fromOffset(64, 64)
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, x, 0, -10)
	b.Text = text
	b.TextSize = 28
	b.FontFace = Brand.Fonts.heavy
	b.TextColor3 = Brand.Colours.lightGold
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = b
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = Brand.Colours.gold
	st.Parent = b
	b.MouseButton1Down:Connect(function()
		lift = value
	end)
	b.MouseButton1Up:Connect(function()
		lift = 0
	end)
	b.MouseLeave:Connect(function()
		lift = 0
	end)
	b.Parent = parent
	return b
end

local function showDash(k: Craft.Kind)
	local old = dash
	if old then
		old:Destroy()
	end
	local touch = UserInputService.TouchEnabled
	local f = Instance.new("Frame")
	f.Name = "CraftDash"
	f.AnchorPoint = Vector2.new(0.5, 1)
	f.Position = UDim2.new(0.5, 0, 1, -(Root.bottomClear() + 96))
	f.Size = UDim2.fromOffset(300, 58)
	f.BackgroundColor3 = Color3.fromRGB(14, 12, 10)
	f.BackgroundTransparency = 0.12
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = f
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = Brand.Colours.gold
	st.Transparency = 0.35
	st.Parent = f
	local name = Instance.new("TextLabel")
	name.Name = "RideName"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromOffset(16, 8)
	name.Size = UDim2.new(1, -110, 0, 20)
	name.FontFace = Brand.Fonts.heavy
	name.TextSize = 15
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextColor3 = Brand.Colours.lightGold
	name.Text = string.upper(k.name)
	name.Parent = f
	local how = Instance.new("TextLabel")
	how.Name = "RideHow"
	how.BackgroundTransparency = 1
	how.Position = UDim2.fromOffset(16, 30)
	how.Size = UDim2.new(1, -110, 0, 18)
	how.FontFace = Brand.Fonts.body
	how.TextSize = 12
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextColor3 = Color3.fromRGB(226, 218, 204)
	how.TextTruncate = Enum.TextTruncate.AtEnd
	how.Text = if k.water then "Jump to get off" elseif touch then "▲ ▼ to climb and descend · jump to get off" else "E up · Q down · jump to get off"
	how.Parent = f
	local sp = Instance.new("TextLabel")
	sp.Name = "RideSpeed"
	sp.BackgroundTransparency = 1
	sp.AnchorPoint = Vector2.new(1, 0)
	sp.Position = UDim2.new(1, -16, 0, 6)
	sp.Size = UDim2.fromOffset(84, 46)
	sp.FontFace = Brand.Fonts.display
	sp.TextSize = 32
	sp.TextXAlignment = Enum.TextXAlignment.Right
	sp.TextColor3 = Color3.fromRGB(250, 244, 230)
	sp.Text = "0"
	sp.Parent = f
	if not k.water and touch then
		key(f, "▲", 74, 1)
		key(f, "▼", 144, -1)
	end
	f.Parent = Root.hud
	dash = f
	dashSpeed = sp
end

local function hideDash()
	local d = dash
	if d then
		d:Destroy()
	end
	dash = nil
	dashSpeed = nil
	lift = 0
end

-- One frame at the helm (exposed for tests).
function CraftDrive.step(dt: number)
	local m = model
	local k = kind
	if not m or not k then
		return
	end
	local chassis = m:FindFirstChild("Chassis") :: BasePart?
	local seat = m:FindFirstChild("HelmSeat") :: VehicleSeat?
	if not chassis or not seat then
		return
	end
	local drive = chassis:FindFirstChild("Drive") :: LinearVelocity?
	local steer = chassis:FindFirstChild("Steer") :: AlignOrientation?
	if not drive or not steer then
		return
	end
	if chassis.Anchored then
		speed = 0
		local look = chassis.CFrame.LookVector
		yaw = math.atan2(-look.X, -look.Z)
		drive.VectorVelocity = Vector3.zero
		return
	end
	local throttle = seat.ThrottleFloat
	local wheel = seat.SteerFloat
	if throttle == 0 then
		throttle = keyAxis({ Enum.KeyCode.W, Enum.KeyCode.Up }, { Enum.KeyCode.S, Enum.KeyCode.Down })
	end
	if wheel == 0 then
		wheel = keyAxis({ Enum.KeyCode.D, Enum.KeyCode.Right }, { Enum.KeyCode.A, Enum.KeyCode.Left })
	end
	local yawRate
	speed, yawRate = Craft.step(k, speed, throttle, wheel, dt)
	yaw += yawRate * dt
	local o = origin()
	local here = chassis.CFrame.Position - o
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local want = here + forward * speed * dt
	local kept, stopped = Craft.keep(k, here, want)
	if stopped then
		-- (The shore, or the edge: stopped, and nudged back the way it came.)
		speed = -math.sign(speed) * math.min(4, math.abs(speed))
		kept = here
	end
	local _ = kept
	local vy = 0
	local bank, pitch = 0, 0
	if k.water then
		local t = os.clock()
		local frac = math.clamp(math.abs(speed) / k.top, 0, 1)
		local bob = math.sin(t * 2.1) * 0.12 * (1 - frac) + math.sin(t * 7) * 0.05 * frac
		local targetY = Craft.KINDS[k.id].ride + bob
		vy = math.clamp((targetY - here.Y) * 6, -20, 20)
		bank = -wheel * 0.18 * frac
		pitch = 0.05 * frac
	else
		local up = lift
		if up == 0 then
			up = keyAxis({ Enum.KeyCode.E, Enum.KeyCode.ButtonR1, Enum.KeyCode.PageUp }, { Enum.KeyCode.Q, Enum.KeyCode.ButtonL1, Enum.KeyCode.PageDown })
		end
		local ground = Ground.groundAt(here.X, here.Z)
		vy = Craft.vertical(k, here.Y, math.max(ground, 0), up)
		bank = -wheel * 0.25 * math.clamp(math.abs(speed) / k.top, 0, 1)
		pitch = -0.18 * math.clamp(speed / k.top, -1, 1)
	end
	steer.CFrame = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, bank)
	drive.VectorVelocity = forward * speed + Vector3.new(0, vy, 0)
	local sp = dashSpeed
	if sp then
		sp.Text = tostring(math.floor(math.abs(speed) * 1.1 + 0.5))
	end
end

-- Whether this screen is at a ride's helm (for tests and the HUD).
function CraftDrive.riding(): string?
	return if kind then (kind :: Craft.Kind).id else nil
end

local function onSeat(seatPart: Instance?)
	local seat = seatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "HelmSeat" and seat.Parent and CollectionService:HasTag(seat.Parent, "IslandCraft") then
		local m = seat.Parent :: Model
		local k = Craft.KINDS[tostring(m:GetAttribute("CraftKind"))]
		if k then
			model = m
			kind = k
			speed = 0
			local chassis = m:FindFirstChild("Chassis")
			if chassis and chassis:IsA("BasePart") then
				local look = chassis.CFrame.LookVector
				yaw = math.atan2(-look.X, -look.Z)
			end
			showDash(k)
			return
		end
	end
	if model then
		model = nil
		kind = nil
		speed = 0
		hideDash()
	end
end

-- Taken at the helm when the character sits there (any character this guest has).
function CraftDrive.watch(humanoid: Humanoid)
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		onSeat(humanoid.SeatPart)
	end)
	onSeat(humanoid.SeatPart)
end

function CraftDrive.start()
	if started then
		return
	end
	started = true
	local function hook(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			CraftDrive.watch(humanoid)
		end
	end
	if player.Character then
		task.spawn(hook, player.Character)
	end
	player.CharacterAdded:Connect(function(c)
		onSeat(nil)
		hook(c)
	end)
	RunService.Heartbeat:Connect(function(dt)
		if model then
			CraftDrive.step(dt)
		end
	end)
	-- The aura spot at the Sovereign's top deck: standing in it, a drift of gold and the wind
	-- about the guest (on this screen; a look, nothing more).
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.3 then
			return
		end
		acc = 0
		pcall(CraftDrive.aura)
	end)
end

-- (Exposed for tests.) Whether the guest stands in an aura spot now, and its look on them.
function CraftDrive.aura(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local inside = false
	for _, spot in CollectionService:GetTagged("IslandAuraSpot") do
		if spot:IsA("BasePart") then
			local rel = spot.CFrame:PointToObjectSpace(root.CFrame.Position)
			local half = spot.Size / 2 + Vector3.new(0.5, 2, 0.5)
			if math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z then
				inside = true
			end
		end
	end
	local fx = root:FindFirstChild("IslandAura")
	if inside and not fx then
		local a = Instance.new("Attachment")
		a.Name = "IslandAura"
		a.Parent = root
		local gold = Instance.new("ParticleEmitter")
		gold.Name = "Gold"
		gold.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		gold.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150), Color3.fromRGB(214, 160, 60))
		gold.LightEmission = 0.8
		gold.Size = NumberSequence.new(0.35, 0)
		gold.Lifetime = NumberRange.new(0.9, 1.6)
		gold.Rate = 18
		gold.Speed = NumberRange.new(1, 3)
		gold.SpreadAngle = Vector2.new(180, 180)
		gold.Parent = a
		local wind = Instance.new("ParticleEmitter")
		wind.Name = "Wind"
		wind.Texture = "rbxasset://textures/particles/smoke_main.dds"
		wind.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		wind.Transparency = NumberSequence.new(0.85, 1)
		wind.Size = NumberSequence.new(1.5, 3)
		wind.Lifetime = NumberRange.new(0.6, 1)
		wind.Rate = 10
		wind.Speed = NumberRange.new(10, 16)
		wind.EmissionDirection = Enum.NormalId.Back
		wind.Parent = a
	elseif not inside and fx then
		fx:Destroy()
	end
	return inside
end

return CraftDrive

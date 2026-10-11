--!strict
-- Santa's sleigh in the air, on this screen. The server says when it left and how long the flight
-- takes (Workspace: SleighState, SleighT0, SleighFlight); every screen flies its own copy of the
-- sleigh (reindeer, Santa, and the riders as they sat) along the same way (shared/HolidayGames'
-- flight points), in step: off along the street, up over the house, through the clouds and the
-- northern lights, down onto the North Pole's pad, or back. The reindeer gallop on the air, a trail
-- of gold dust runs behind. The parked sleigh hides meanwhile (the server moves it when it lands).
--
-- A rider sees it as a film: the camera rides with the sleigh in four shots (close behind on the
-- street, wide beside it over the house, high behind above the clouds, ahead of it coming in to
-- land), between black bars, with the place's name as it nears. With the movement setting turned
-- down, the camera is left alone. The sleigh itself and its riders are the server's to move.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local Quality = require(script.Parent.Parent.Quality)
local Sound = require(script.Parent.Parent.Sound)
local CameraRig = require(script.Parent.Parent.Camera)
local HolidayKit = require(script.Parent.HolidayKit)
local Stagecraft = require(script.Parent.Stagecraft)

local SleighRide = {}

local rgb = Color3.fromRGB
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local BIND = "MaisonSleighRide"

local TITLE: Stagecraft.TitleLook = {
	deep = rgb(150, 16, 30),
	mid = rgb(230, 70, 70),
	light = rgb(255, 236, 200),
	ink = rgb(40, 6, 10),
	kicker = rgb(255, 222, 140),
}

type Leg = { part: BasePart, hip: CFrame, inDeer: CFrame, front: boolean }
type Deer = { root: CFrame, phase: number, parts: { BasePart }, offsets: { CFrame }, legs: { Leg } }
type Flight = {
	copy: Model,
	parts: { BasePart }, -- everything but the reindeer
	offsets: { CFrame },
	deer: { Deer },
	points: { Vector3 },
	t0: number,
	seconds: number,
	toPole: boolean,
	riders: { [number]: boolean }, -- whose copies are aboard (by UserId)
	forward: Vector3,
	rider: boolean, -- this guest is aboard
	titled: boolean,
	bells: number,
	clouds: Folder?,
}

local flight: Flight? = nil
local camera: () -> ()
local parked: Model? = nil
local hiddenOn: { [Instance]: boolean } = {}
local gui: ScreenGui? = nil

local function serverNow(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.time()
end

local function screen(): ScreenGui?
	local g = gui
	if g and g.Parent then
		return g
	end
	local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not pg then
		return nil
	end
	local ng = Instance.new("ScreenGui")
	ng.Name = "SleighRide"
	ng.IgnoreGuiInset = true
	ng.ResetOnSpawn = false
	ng.DisplayOrder = 32
	ng.Parent = pg
	gui = ng
	return ng
end

-- The parked sleigh out of sight (or back) on this screen.
local function hideParked(m: Model, on: boolean)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if on then 1 else 0
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("BillboardGui") then
			local e = d :: any -- each of these has Enabled
			if on then
				if hiddenOn[d] == nil then
					hiddenOn[d] = e.Enabled
				end
				e.Enabled = false
			elseif hiddenOn[d] ~= nil then
				e.Enabled = hiddenOn[d]
				hiddenOn[d] = nil
			end
		end
	end
end

-- Adds the riders' copies (they reach this screen a moment after the sleigh leaves).
local function takePassengers(f: Flight, from: Model, rootCF: CFrame)
	for _, p in from:GetChildren() do
		local id = p:GetAttribute("UserId")
		if p:IsA("Model") and p.Name == "Passenger" and type(id) == "number" and not f.riders[id] then
			local ok, c = pcall(function()
				return p:Clone()
			end)
			if ok and c then
				f.riders[id] = true
				c.Parent = f.copy
				for _, d in c:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.LocalTransparencyModifier = 0
						table.insert(f.parts, d)
						table.insert(f.offsets, rootCF:ToObjectSpace(d.CFrame))
					end
				end
			end
		end
	end
end

local function build(m: Model, state: string, t0: number, seconds: number): Flight?
	local root = m.PrimaryPart
	if not root then
		return nil
	end
	local rootCF = root.CFrame
	local copy = Instance.new("Model")
	copy.Name = "SleighInFlight"
	local f: Flight = {
		copy = copy,
		parts = {},
		offsets = {},
		deer = {},
		points = HolidayGames.flightPoints(state == "toPole"),
		t0 = t0,
		seconds = math.max(2, seconds),
		toPole = state == "toPole",
		riders = {},
		forward = rootCF.LookVector,
		rider = Players.LocalPlayer:GetAttribute("SleighRide") ~= nil,
		titled = false,
		bells = 0,
		clouds = nil,
	}
	for _, child in m:GetChildren() do
		if child:IsA("Seat") or child.Name == "BoardHere" or child.Name == "Passenger" or child:IsA("BillboardGui") then
			continue
		end
		local ok, c = pcall(function()
			return child:Clone()
		end)
		if ok and c then
			c.Parent = copy
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("ProximityPrompt") or d:IsA("BaseScript") or d:IsA("BillboardGui") then
			d:Destroy()
		end
	end
	-- The reindeer, each moved on its own (galloping); everything else with the sleigh.
	local herd = copy:FindFirstChild("Reindeer")
	local inDeer: { [BasePart]: boolean } = {}
	if herd then
		for k, deer in herd:GetChildren() do
			local droot = if deer:IsA("Model") then deer.PrimaryPart else nil
			if droot then
				local dcf = droot.CFrame
				local entry: Deer = { root = rootCF:ToObjectSpace(dcf), phase = k * 0.7, parts = {}, offsets = {}, legs = {} }
				for _, d in deer:GetDescendants() do
					if d:IsA("BasePart") then
						d.Anchored = true
						d.CanCollide = false
						d.LocalTransparencyModifier = 0
						inDeer[d] = true
						local n = tonumber(string.match(d.Name, "^Leg(%d)$") or string.match(d.Name, "^Hoof(%d)$"))
						if n then
							local front = n <= 2
							local x = if n % 2 == 1 then -0.62 else 0.62
							local z = if front then -1.45 else 1.45
							table.insert(entry.legs, { part = d, hip = CFrame.new(x, 2.75, z), inDeer = dcf:ToObjectSpace(d.CFrame), front = front })
						else
							table.insert(entry.parts, d)
							table.insert(entry.offsets, dcf:ToObjectSpace(d.CFrame))
						end
					end
				end
				table.insert(f.deer, entry)
			end
		end
	end
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") and not inDeer[d] then
			d.Anchored = true
			d.CanCollide = false
			d.LocalTransparencyModifier = 0
			table.insert(f.parts, d)
			table.insert(f.offsets, rootCF:ToObjectSpace(d.CFrame))
		end
	end
	takePassengers(f, m, rootCF)
	-- Gold dust behind it, and a trail from each runner.
	local copyRoot = copy:FindFirstChild("SleighRoot")
	if copyRoot and copyRoot:IsA("BasePart") then
		copy.PrimaryPart = copyRoot
		local dust = Instance.new("ParticleEmitter")
		dust.Name = "GoldDust"
		dust.Texture = SPARK
		dust.Color = ColorSequence.new(rgb(255, 236, 170), rgb(255, 196, 90))
		dust.LightEmission = 1
		dust.Rate = 50 * Quality.level()
		dust.Lifetime = NumberRange.new(1.2, 2.2)
		dust.Speed = NumberRange.new(0, 1)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Acceleration = Vector3.new(0, -2, 0)
		dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		dust.Transparency = NumberSequence.new(0.1, 1)
		dust.Parent = copyRoot
		for _, sx in { -1, 1 } do
			local a0 = Instance.new("Attachment")
			a0.Position = Vector3.new(sx * 3.7, 0.2, 7.2)
			a0.Parent = copyRoot
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(sx * 3.7, 1.2, 7.2)
			a1.Parent = copyRoot
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Texture = SPARK
			trail.TextureMode = Enum.TextureMode.Wrap
			trail.TextureLength = 4
			trail.LightEmission = 1
			trail.Lifetime = 1.6
			trail.Color = ColorSequence.new(rgb(255, 236, 170), rgb(255, 180, 80))
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.WidthScale = NumberSequence.new(1, 0.2)
			trail.Parent = copyRoot
		end
	end
	copy.Parent = HolidayKit.folder("HolidaySleigh")
	return f
end

-- Clouds along the way (for a rider: the sleigh flies through them).
local function clouds(f: Flight)
	local folder = Instance.new("Folder")
	folder.Name = "Clouds"
	folder.Parent = f.copy
	f.clouds = folder
	local rng = Random.new(31)
	for k = 1, Quality.count(16, 6) do
		local u = 0.3 + (k - 0.5) / 16 * 0.45
		local at, way = HolidayGames.along(f.points, HolidayGames.ease(u))
		local side = Vector3.new(-way.Z, 0, way.X)
		side = if side.Magnitude > 0.01 then side.Unit else Vector3.new(1, 0, 0)
		local centre = at + side * rng:NextNumber(-120, 120) + Vector3.new(0, rng:NextNumber(-30, 10), 0)
		for j = 1, 3 do
			local s = rng:NextNumber(50, 110)
			local p = Instance.new("Part")
			p.Name = "Cloud"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Size = Vector3.new(s * 1.6, s * 0.55, s)
			p.CFrame = CFrame.new(centre + Vector3.new(rng:NextNumber(-40, 40), rng:NextNumber(-8, 8), rng:NextNumber(-40, 40))) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			p.Color = rgb(214, 220, 238)
			p.Material = Enum.Material.SmoothPlastic
			p.Transparency = 0.42 + j * 0.1
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
			p.Parent = folder
		end
	end
end

-- The rider's camera: four shots, blended.
local SHOTS = {
	{ to = 0.14, eye = Vector3.new(-9, 6, 22), look = Vector3.new(0, 4, -24) },
	{ to = 0.42, eye = Vector3.new(42, 16, 8), look = Vector3.new(0, 4, -12) },
	{ to = 0.78, eye = Vector3.new(0, 18, 38), look = Vector3.new(0, 2, -46) },
	{ to = 1.01, eye = Vector3.new(-26, 9, -46), look = Vector3.new(0, 3, 0) },
}

local function shotAt(flat: CFrame, u: number): (Vector3, Vector3)
	local i = 1
	while i < #SHOTS and u > SHOTS[i].to do
		i += 1
	end
	local s = SHOTS[i]
	local eye = (flat * CFrame.new(s.eye)).Position
	local look = (flat * CFrame.new(s.look)).Position
	if i > 1 then
		local w = math.clamp((u - SHOTS[i - 1].to) / 0.06, 0, 1)
		w = w * w * (3 - 2 * w)
		if w < 1 then
			local p = SHOTS[i - 1]
			eye = (flat * CFrame.new(p.eye)).Position:Lerp(eye, w)
			look = (flat * CFrame.new(p.look)).Position:Lerp(look, w)
		end
	end
	return eye, look
end

local function finish()
	local f = flight
	flight = nil
	if f then
		f.copy:Destroy()
		if f.rider then
			pcall(function()
				RunService:UnbindFromRenderStep(BIND)
			end)
			local g = screen()
			if g then
				Stagecraft.letterbox(g, false)
			end
			task.spawn(CameraRig.handoff, 1.2)
		end
	end
	if parked then
		hideParked(parked, false)
	end
end

local function frameAt(f: Flight, u: number): (CFrame, CFrame)
	local e = HolidayGames.ease(u)
	local at, way = HolidayGames.along(f.points, e)
	if way.Magnitude > 0.05 then
		f.forward = way.Unit
	end
	local _, ahead = HolidayGames.along(f.points, math.min(1, e + 0.012))
	local turn = if ahead.Magnitude > 0.05 then f.forward:Cross(ahead.Unit).Y else 0
	local flat = CFrame.lookAt(at, at + f.forward)
	local roll = math.clamp(-turn * 22, -0.55, 0.55)
	return flat * CFrame.Angles(0, 0, roll), flat
end

local function stepFlight(f: Flight, dt: number, t: number)
	local u = (serverNow() - f.t0) / f.seconds
	if u >= 1.02 then
		finish()
		return
	end
	u = math.clamp(u, 0, 1)
	if parked and u < 0.5 then
		takePassengers(f, parked, (parked.PrimaryPart :: BasePart).CFrame)
	end
	local cf = frameAt(f, u)
	-- (Aboard after all: the server's word on who rides can reach this screen a moment late.)
	if not f.rider and u < 0.3 and Players.LocalPlayer:GetAttribute("SleighRide") ~= nil then
		f.rider = true
		clouds(f)
		if not Stagecraft.still() then
			local g = screen()
			if g then
				Stagecraft.letterbox(g, true)
			end
			pcall(function()
				RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, camera)
			end)
		end
	end
	-- In the air the reindeer gallop; on the snow and the street they trot.
	local air = math.clamp(math.min(u, 1 - u) * 10, 0, 1)
	local cfs = table.create(#f.parts)
	for j, o in f.offsets do
		cfs[j] = cf * o
	end
	local list = table.clone(f.parts)
	for _, d in f.deer do
		local w = t * (7 + air * 5) + d.phase
		local bob = CFrame.new(0, math.sin(w) * (0.15 + air * 0.5), 0) * CFrame.Angles(math.sin(w + 1) * 0.08 * air, 0, 0)
		local base = cf * d.root * bob
		for j, o in d.offsets do
			table.insert(list, d.parts[j])
			table.insert(cfs, base * o)
		end
		for _, leg in d.legs do
			local swing = math.sin(w + (if leg.front then 0 else math.pi)) * (0.35 + air * 0.45)
			table.insert(list, leg.part)
			table.insert(cfs, base * leg.hip * CFrame.Angles(swing, 0, 0) * leg.hip:Inverse() * leg.inDeer)
		end
	end
	pcall(function()
		Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	-- Bells as it goes (near enough to hear).
	f.bells -= dt
	if f.bells <= 0 then
		f.bells = 2.4
		local cam = Workspace.CurrentCamera
		if f.rider or (cam and (cam.CFrame.Position - cf.Position).Magnitude < 260) then
			Sound.play("bellTree", if f.rider then 0.45 else 0.3)
		end
	end
	if f.rider then
		if not f.titled and u >= 0.5 then
			f.titled = true
			local g = screen()
			if g then
				if f.toPole then
					Stagecraft.title(g, "Next stop", "THE NORTH POLE", 3.6, TITLE, "Gather the gifts in the snow. Load them before the sleigh leaves.")
				else
					Stagecraft.title(g, "Back to the Maison", "HOME FOR CHRISTMAS", 3.6, TITLE, "Your gifts are waiting to be opened.")
				end
			end
		end
	end
end

function camera()
	local f = flight
	local cam = Workspace.CurrentCamera
	if not f or not cam then
		return
	end
	local u = math.clamp((serverNow() - f.t0) / f.seconds, 0, 1)
	local _, flat = frameAt(f, u)
	local eye, look = shotAt(flat, u)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = CFrame.lookAt(eye, look)
	cam.FieldOfView = 62 + math.sin(u * math.pi) * 10
end

-- The sleigh's state changed (or arrived on this screen): start, keep or end a flight.
function SleighRide.update(m: Model?)
	if m ~= parked then
		if parked then
			hideParked(parked, false)
		end
		parked = m
	end
	local state = Workspace:GetAttribute("SleighState")
	local t0 = Workspace:GetAttribute("SleighT0")
	local seconds = Workspace:GetAttribute("SleighFlight")
	local flying = (state == "toPole" or state == "toHome") and type(t0) == "number" and type(seconds) == "number"
	if not flying or not m then
		if flight then
			finish()
		end
		return
	end
	if flight and flight.t0 == t0 then
		return
	end
	if flight then
		finish()
	end
	local f = build(m, state :: string, t0 :: number, seconds :: number)
	if not f then
		return
	end
	flight = f
	hideParked(m, true)
	Sound.play("bellTree", 0.6)
	Sound.play("bellStrike", 0.35, 1.3)
	if f.rider then
		clouds(f)
		if not Stagecraft.still() then
			local g = screen()
			if g then
				Stagecraft.letterbox(g, true)
			end
			pcall(function()
				RunService:BindToRenderStep(BIND, Enum.RenderPriority.Camera.Value + 1, camera)
			end)
		end
	end
end

function SleighRide.step(dt: number, t: number)
	local f = flight
	if f then
		stepFlight(f, dt, t)
	end
end

-- Whether the sleigh is in the air on this screen, and whether this guest is aboard.
function SleighRide.flying(): boolean
	return flight ~= nil
end
function SleighRide.riding(): boolean
	local f = flight
	return f ~= nil and f.rider
end

-- For tests: the copy in the air, and where it is.
function SleighRide.copy(): Model?
	local f = flight
	return if f then f.copy else nil
end

return SleighRide

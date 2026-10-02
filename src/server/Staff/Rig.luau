--!strict
-- House staff as R15 rigs. Every look is data (a HumanoidDescription built from Config ids),
-- so a look changes by changing ids. With no ids set, the rig is dressed from body colours:
-- black tailcoat and trousers, white gloves, and a small gold key on the lapel.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Brand = require(ReplicatedStorage.Shared.Brand)

local Rig = {}

export type LookSpec = {
	shirt: number,
	pants: number,
	accessories: string, -- comma-separated accessory ids
	skin: Color3,
	coat: Color3,
	gloves: Color3,
	heightScale: number,
	lapelKey: boolean,
	tails: boolean,
}

export type Staff = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: CFrame,
	busy: boolean,
	idle: AnimationTrack?,
	walk: AnimationTrack?,
}

local function weldTo(part: BasePart, to: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function describe(spec: LookSpec): HumanoidDescription
	local d = Instance.new("HumanoidDescription")
	d.HeadColor = spec.skin
	d.TorsoColor = spec.coat
	d.LeftArmColor = spec.coat
	d.RightArmColor = spec.coat
	d.LeftLegColor = spec.coat
	d.RightLegColor = spec.coat
	d.HeightScale = spec.heightScale
	d.BodyTypeScale = 0.3
	d.ProportionScale = 0.4
	d.WidthScale = 0.92
	if spec.shirt > 0 then
		d.Shirt = spec.shirt
	end
	if spec.pants > 0 then
		d.Pants = spec.pants
	end
	if spec.accessories ~= "" then
		d.HatAccessory = spec.accessories
	end
	return d
end

-- A fallback figure made of parts, used only if Roblox can't build a rig (for example, offline).
local function mannequin(spec: LookSpec): Model
	local m = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = m
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(1.8, 4.6, 1)
	body.Color = spec.coat
	body.Parent = m
	weldTo(body, root)
	body.CFrame = root.CFrame * CFrame.new(0, 0.3, 0)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.2, 1.2, 1.2)
	head.Color = spec.skin
	head.Parent = m
	weldTo(head, root)
	head.CFrame = root.CFrame * CFrame.new(0, 3.2, 0)
	local hum = Instance.new("Humanoid")
	hum.Parent = m
	m.PrimaryPart = root
	return m
end

local function dress(model: Model, spec: LookSpec)
	-- White gloves: R15 hands are separate parts.
	if spec.shirt == 0 then
		for _, name in { "LeftHand", "RightHand" } do
			local hand = model:FindFirstChild(name)
			if hand and hand:IsA("BasePart") then
				hand.Color = spec.gloves
			end
		end
	end
	local upper = model:FindFirstChild("UpperTorso")
	local lower = model:FindFirstChild("LowerTorso")
	if spec.shirt == 0 and upper and upper:IsA("BasePart") then
		-- A white shirt front and a black tie under the coat.
		local shirt = Instance.new("Part")
		shirt.Name = "ShirtFront"
		shirt.Size = Vector3.new(0.5, upper.Size.Y * 0.8, 0.05)
		shirt.Color = Color3.fromRGB(236, 232, 224)
		shirt.Material = Enum.Material.SmoothPlastic
		shirt.CFrame = upper.CFrame * CFrame.new(0, upper.Size.Y * 0.08, -upper.Size.Z / 2 - 0.01)
		shirt.Parent = model
		weldTo(shirt, upper)
		local tie = Instance.new("Part")
		tie.Name = "Tie"
		tie.Size = Vector3.new(0.3, 0.14, 0.06)
		tie.Color = Color3.fromRGB(10, 10, 12)
		tie.Material = Enum.Material.SmoothPlastic
		tie.CFrame = upper.CFrame * CFrame.new(0, upper.Size.Y * 0.4, -upper.Size.Z / 2 - 0.04)
		tie.Parent = model
		weldTo(tie, upper)
	end
	if spec.lapelKey and upper and upper:IsA("BasePart") then
		local key = Instance.new("Part")
		key.Name = "LapelKey"
		key.Size = Vector3.new(0.12, 0.34, 0.06)
		key.Color = Brand.Colours.gold
		key.Material = Enum.Material.Metal
		key.Reflectance = 0.4
		key.CFrame = upper.CFrame * CFrame.new(-upper.Size.X * 0.3, upper.Size.Y * 0.22, -upper.Size.Z / 2 - 0.04) * CFrame.Angles(0, 0, math.rad(-20))
		key.Parent = model
		weldTo(key, upper)
		local bow = Instance.new("Part")
		bow.Name = "LapelKeyBow"
		bow.Shape = Enum.PartType.Cylinder
		bow.Size = Vector3.new(0.05, 0.16, 0.16)
		bow.Color = Brand.Colours.gold
		bow.Material = Enum.Material.Metal
		bow.Reflectance = 0.4
		bow.CFrame = key.CFrame * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, math.rad(90), 0)
		bow.Parent = model
		weldTo(bow, upper)
	end
	if spec.tails and lower and lower:IsA("BasePart") then
		-- The tails of a tailcoat, hanging behind the legs.
		local tails = Instance.new("WedgePart")
		tails.Name = "CoatTails"
		tails.Size = Vector3.new(lower.Size.X * 0.9, 2.2, 0.35)
		tails.Color = spec.coat
		tails.Material = Enum.Material.Fabric
		tails.CFrame = lower.CFrame * CFrame.new(0, -1.1, lower.Size.Z / 2 + 0.1) * CFrame.Angles(0, math.rad(180), 0)
		tails.Parent = model
		weldTo(tails, lower)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Staff"
			if d.Name ~= "HumanoidRootPart" and d.Material == Enum.Material.Plastic then
				d.Material = Enum.Material.SmoothPlastic
			end
		end
	end
end

function Rig.look(kind: string): LookSpec
	local assets = (Config.data.Assets :: any)[kind] or { shirt = 0, pants = 0, accessories = "" }
	local isConcierge = kind == "Concierge"
	return {
		shirt = assets.shirt,
		pants = assets.pants,
		accessories = assets.accessories,
		skin = if isConcierge then Color3.fromRGB(196, 150, 116) else Color3.fromRGB(120, 84, 62),
		coat = Color3.fromRGB(14, 14, 17),
		gloves = Color3.fromRGB(240, 238, 232),
		heightScale = if isConcierge then 1.08 else 1.0,
		lapelKey = isConcierge,
		tails = isConcierge,
	}
end

function Rig.build(name: string, spec: LookSpec, home: CFrame, parent: Instance): Staff
	local model: Model
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(describe(spec), Enum.HumanoidRigType.R15)
	end)
	if ok and result then
		model = result
	else
		warn("[Maison] Staff rig fell back to a mannequin:", result)
		model = mannequin(spec)
	end
	model.Name = name
	dress(model, spec)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.NameDisplayDistance = 0
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = Config.data.Movement.npcWalkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	-- The staff are drawn at the guests' size (Movement.guestScale), so nobody towers.
	local scale = Config.data.Movement.guestScale
	if scale ~= 1 then
		pcall(function()
			model:ScaleTo(scale)
		end)
	end
	model:PivotTo(home + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	model.Parent = parent
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local staff: Staff = { model = model, humanoid = humanoid, root = root, home = home, busy = false, idle = nil, walk = nil }

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = humanoid
		animator = a
	end
	local anims = Config.data.Assets.Animations
	local function load(id: string, priority: Enum.AnimationPriority): AnimationTrack?
		if id == "" then
			return nil
		end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local okLoad, track = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if okLoad and track then
			track.Priority = priority
			track.Looped = true
			return track
		end
		return nil
	end
	staff.idle = load(anims.idle, Enum.AnimationPriority.Idle)
	staff.walk = load(anims.walk, Enum.AnimationPriority.Movement)
	if staff.idle then
		staff.idle:Play(0.3)
	end
	humanoid.Running:Connect(function(speed: number)
		local walk = staff.walk
		if not walk then
			return
		end
		if speed > 0.5 then
			if not walk.IsPlaying then
				walk:Play(0.25)
			end
			walk:AdjustSpeed(math.clamp(speed / 12, 0.5, 1.2))
		elseif walk.IsPlaying then
			walk:Stop(0.3)
		end
	end)
	return staff
end

function Rig.face(staff: Staff, point: Vector3)
	local pos = staff.root.Position
	local flat = Vector3.new(point.X, pos.Y, point.Z)
	if (flat - pos).Magnitude < 0.1 then
		return
	end
	staff.root.CFrame = CFrame.lookAt(pos, flat)
end

-- Walks along a computed path. `shouldPause` is polled at each step; `shouldStop` aborts.
function Rig.walkTo(staff: Staff, goal: Vector3, shouldPause: (() -> boolean)?, shouldStop: (() -> boolean)?): boolean
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.6,
		AgentHeight = 5.5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})
	local ok = pcall(function()
		path:ComputeAsync(staff.root.Position, goal)
	end)
	local waypoints: { Vector3 } = {}
	if ok and path.Status == Enum.PathStatus.Success then
		for _, w in path:GetWaypoints() do
			table.insert(waypoints, w.Position)
		end
	else
		table.insert(waypoints, goal) -- the rooms are open; a straight line is a fair fallback
	end
	for _, target in waypoints do
		local started = os.clock()
		staff.humanoid:MoveTo(target)
		while true do
			if shouldStop and shouldStop() then
				staff.humanoid:MoveTo(staff.root.Position)
				return false
			end
			if shouldPause and shouldPause() then
				staff.humanoid:MoveTo(staff.root.Position)
				local waited = os.clock()
				while shouldPause() and os.clock() - waited < 25 do
					if shouldStop and shouldStop() then
						return false
					end
					task.wait(0.25)
				end
				if shouldPause() then
					return false
				end
				staff.humanoid:MoveTo(target)
				started = os.clock()
			end
			local flat = Vector3.new(target.X, staff.root.Position.Y, target.Z)
			if (staff.root.Position - flat).Magnitude < 2 then
				break
			end
			if os.clock() - started > 6 then
				break
			end
			task.wait(0.1)
		end
	end
	return true
end

function Rig.goHome(staff: Staff)
	Rig.walkTo(staff, staff.home.Position)
	Rig.face(staff, staff.home.Position + staff.home.LookVector * 10)
end

return Rig

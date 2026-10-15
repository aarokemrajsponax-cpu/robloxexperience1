--!strict
-- One of the Grand Prix's cars: an open two-seater (you see who's driving), long and low, in its
-- own paint with its trim, chrome-rimmed wheels, light bars front and back, and on the hypercars
-- a wing. Underneath, an invisible chassis does all the work: it rests on the road, slides on it
-- (it hardly grips: the driver's screen moves it, GrandPrix.step), and carries the two movers
-- the driver's screen sets, "Drive" (a LinearVelocity, along the road only: gravity keeps the
-- car down) and "Steer" (an AlignOrientation that keeps it level and turns it).
--
-- Everything else is welded to the chassis and weighs nothing; only the chassis collides, in the
-- "Cars" group (cars pass through guests and each other; walls of the "CarWalls" group stop them).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrandPrix = require(ReplicatedStorage.Shared.GrandPrix)

local Motorcar = {}

local LENGTH, WIDTH = 15, 7.2

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- Builds a car of `def` (GrandPrix.CARS) resting at `at` (its chassis's centre). Anchored: the
-- service lets it go when someone drives.
function Motorcar.build(parent: Instance, def: { [string]: any }, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Car_" .. def.id
	model:SetAttribute("CarId", def.id)
	model:SetAttribute("CarName", def.name)
	if def.private then
		model:SetAttribute("Private", true)
	end

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(WIDTH - 0.4, 1.6, LENGTH - 0.4)
	chassis.CFrame = at
	chassis.Transparency = 1
	chassis.Anchored = true
	chassis.CanQuery = false
	chassis.CanTouch = false
	chassis.CollisionGroup = "Cars"
	-- Slides on the road (the screen drives it); heavy enough not to be nudged about.
	pcall(function()
		chassis.CustomPhysicalProperties = PhysicalProperties.new(1.2, 0.02, 0, 100, 1)
	end)
	chassis.Parent = model
	model.PrimaryPart = chassis

	-- `put`: a piece at (x, y, z) from the chassis's centre, y measured from the road (the chassis's
	-- centre is GrandPrix.RIDE above it); z negative is the front.
	local function put(name: string, size: Vector3, x: number, y: number, z: number, color: Color3, material: Enum.Material, opts: { [string]: any }?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		local cf = at * CFrame.new(x, y - GrandPrix.RIDE, z)
		if opts and opts.rotate then
			cf *= opts.rotate
		end
		if opts and opts.shape then
			p.Shape = opts.shape
			p.Size = size
		end
		p.CFrame = cf
		p.Color = color
		p.Material = material
		p.Reflectance = if opts and opts.reflectance then opts.reflectance else 0
		p.Transparency = if opts and opts.transparency then opts.transparency else 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = not (opts and opts.noShadow)
		p.Parent = model
		weld(chassis, p)
		return p
	end

	local paint, trim, glass = def.paint :: Color3, def.trim :: Color3, def.glass :: Color3
	local glossy = Enum.Material.SmoothPlastic
	local leather = Color3.fromRGB(66, 34, 24)
	local hyper = def.style == "hyper"
	local saloon = def.style == "saloon"

	-- The body: a long low hull, the bonnet sloping to the nose, the tail deck, the sills.
	put("Hull", Vector3.new(WIDTH, 1.3, LENGTH), 0, 1.55, 0, paint, glossy, { reflectance = 0.14 })
	put("Bonnet", Vector3.new(WIDTH - 0.5, 0.5, 5.4), 0, 2.4, -4.7, paint, glossy, { reflectance = 0.16, rotate = CFrame.Angles(math.rad(-5), 0, 0) })
	put("Tail", Vector3.new(WIDTH - 0.5, 0.6, 4.4), 0, 2.45, 5.1, paint, glossy, { reflectance = 0.16 })
	put("Nose", Vector3.new(WIDTH - 0.8, 0.8, 0.6), 0, 1.45, -7.6, paint, glossy, { reflectance = 0.14 })
	for _, side in { -1, 1 } do
		put("Sill", Vector3.new(0.16, 0.22, LENGTH - 2), side * (WIDTH / 2 + 0.05), 1.05, 0, trim, Enum.Material.Metal, { reflectance = 0.35 })
		put("Arch", Vector3.new(0.4, 0.9, 3.6), side * (WIDTH / 2 - 0.1), 2.0, -4.8, paint, glossy, { reflectance = 0.14 })
		put("Arch", Vector3.new(0.4, 0.9, 3.6), side * (WIDTH / 2 - 0.1), 2.0, 4.8, paint, glossy, { reflectance = 0.14 })
	end
	-- The cabin: a leather floor, two seat backs, a gold line round the cockpit, the windscreen.
	put("Cockpit", Vector3.new(WIDTH - 1, 0.3, 4.6), 0, 2.25, 0.4, leather, Enum.Material.Leather)
	for _, side in { -1, 1 } do
		put("SeatBack", Vector3.new(2.4, 1.9, 0.45), side * 1.65, 3.15, 2.45, leather, Enum.Material.Leather, { rotate = CFrame.Angles(math.rad(-12), 0, 0) })
	end
	put("Coaming", Vector3.new(WIDTH - 0.6, 0.12, 0.2), 0, 2.72, 2.85, trim, Enum.Material.Metal, { reflectance = 0.3 })
	put("Windscreen", Vector3.new(WIDTH - 1.2, 1.5, 0.12), 0, 3.25, -1.95, glass, Enum.Material.Glass, { transparency = 0.45, reflectance = 0.25, rotate = CFrame.Angles(math.rad(-32), 0, 0) })
	put("ScreenFrame", Vector3.new(WIDTH - 1.1, 0.14, 0.18), 0, 3.9, -1.55, trim, Enum.Material.Metal, { reflectance = 0.3 })
	-- The face: a grille in trim, light bars, a badge.
	put("Grille", Vector3.new(2.6, 0.7, 0.14), 0, 1.6, -7.95, if saloon then trim else Color3.fromRGB(14, 14, 16), Enum.Material.Metal, { reflectance = 0.3 })
	for _, side in { -1, 1 } do
		put("Headlight", Vector3.new(1.9, 0.22, 0.12), side * 2.3, 2.05, -7.85, Color3.fromRGB(255, 246, 228), Enum.Material.Neon, { noShadow = true })
		put("Taillight", Vector3.new(2.2, 0.22, 0.12), side * 2.3, 2.3, 7.55, Color3.fromRGB(200, 20, 30), Enum.Material.Neon, { noShadow = true })
	end
	if saloon then
		put("Mascot", Vector3.new(0.35, 0.6, 0.35), 0, 2.85, -6.9, trim, Enum.Material.Metal, { reflectance = 0.4 })
	end
	if hyper then
		put("Wing", Vector3.new(WIDTH - 0.6, 0.16, 1.3), 0, 3.85, 6.7, Color3.fromRGB(16, 16, 18), glossy, { reflectance = 0.1 })
		for _, side in { -1, 1 } do
			put("Strut", Vector3.new(0.18, 1.1, 0.5), side * 2.2, 3.25, 6.7, trim, Enum.Material.Metal)
		end
		put("Splitter", Vector3.new(WIDTH - 0.4, 0.12, 0.8), 0, 0.85, -7.7, Color3.fromRGB(16, 16, 18), glossy)
	end
	-- The Private Garage's cars: a fine coachline in trim along each flank.
	if def.private then
		for _, side in { -1, 1 } do
			put("Coachline", Vector3.new(0.06, 0.1, LENGTH - 3), side * (WIDTH / 2 + 0.02), 2.05, 0, trim, Enum.Material.Metal, { reflectance = 0.35, noShadow = true })
		end
	end
	-- Wheels: black tyres, rims in trim.
	for _, side in { -1, 1 } do
		for _, z in { -4.8, 4.8 } do
			local tyre = put("Tyre", Vector3.new(1.25, 2.9, 2.9), side * (WIDTH / 2 - 0.35), 1.45, z, Color3.fromRGB(18, 18, 20), Enum.Material.Rubber, { shape = Enum.PartType.Cylinder })
			tyre:SetAttribute("Wheel", true)
			put("Rim", Vector3.new(0.2, 1.7, 1.7), side * (WIDTH / 2 + 0.3), 1.45, z, trim, Enum.Material.Metal, { shape = Enum.PartType.Cylinder, reflectance = 0.4 })
		end
	end

	-- The seats: the driver's (left) works the car; a friend may ride on the right.
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2.2, 0.4, 2.2)
	seat.CFrame = at * CFrame.new(-1.65, 2.55 - GrandPrix.RIDE, 1.3)
	seat.Color = leather
	seat.Material = Enum.Material.Leather
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Anchored = false
	seat.Massless = true
	seat.CanCollide = false
	seat.CanQuery = true
	seat.CanTouch = false -- (sit by the prompt, never by walking into it)
	seat.Parent = model
	weld(chassis, seat)
	local passenger = Instance.new("Seat")
	passenger.Name = "PassengerSeat"
	passenger.Size = Vector3.new(2.2, 0.4, 2.2)
	passenger.CFrame = at * CFrame.new(1.65, 2.55 - GrandPrix.RIDE, 1.3)
	passenger.Color = leather
	passenger.Material = Enum.Material.Leather
	passenger.Anchored = false
	passenger.Massless = true
	passenger.CanCollide = false
	passenger.CanTouch = false
	passenger.Parent = model
	weld(chassis, passenger)

	-- The movers (the driver's screen sets them; nothing moves while the chassis is anchored).
	local attach = Instance.new("Attachment")
	attach.Name = "Centre"
	attach.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = attach
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drive.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	drive.MaxAxesForce = Vector3.new(4e5, 0, 4e5)
	drive.VectorVelocity = Vector3.zero
	drive.Parent = chassis
	local steer = Instance.new("AlignOrientation")
	steer.Name = "Steer"
	steer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	steer.Attachment0 = attach
	steer.MaxTorque = 4e6
	steer.Responsiveness = 40
	steer.CFrame = at.Rotation
	steer.Parent = chassis

	-- Get in.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Drive"
	prompt.ObjectText = if def.private then def.name .. "  ·  Private Garage" else def.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	local ride = Instance.new("ProximityPrompt")
	ride.Name = "RidePrompt"
	ride.ActionText = "Ride along"
	ride.ObjectText = def.name
	ride.KeyboardKeyCode = Enum.KeyCode.F
	ride.GamepadKeyCode = Enum.KeyCode.ButtonY
	ride.HoldDuration = 0
	ride.MaxActivationDistance = 12
	ride.RequiresLineOfSight = false
	ride.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	ride.Parent = passenger

	-- (Every screen keeps the cars: they move, and each screen draws the chauffeurs from them.)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	CollectionService:AddTag(model, "MaisonCar")
	model.Parent = parent
	return model
end

return Motorcar

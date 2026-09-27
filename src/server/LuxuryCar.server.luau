-- Builds a drivable luxury car near the spawn.
-- Sit in the driver's seat and drive with W/A/S/D (or the arrow keys).

local Workspace = game:GetService("Workspace")

local TOP_SPEED = 70 -- studs per second
local MAX_STEER_ANGLE = 30 -- degrees
local WHEEL_RADIUS = 1.4
local WHEEL_WIDTH = 1.2

local PAINT = Color3.fromRGB(12, 12, 16)
local GOLD = Color3.fromRGB(212, 175, 55)
local CHROME = Color3.fromRGB(220, 220, 225)
local LEATHER = Color3.fromRGB(120, 72, 40)

local car = Instance.new("Model")
car.Name = "LuxuryCar"

-- Find the ground in front of the spawn so the car lands on it.
local function findSpawnCFrame(): CFrame
	local origin = Vector3.new(0, 200, -30)
	local result = Workspace:Raycast(origin, Vector3.new(0, -400, 0))
	local groundY = if result then result.Position.Y else 0
	return CFrame.new(0, groundY + WHEEL_RADIUS + 0.5, -30)
end

local base = findSpawnCFrame()

local function makePart(props: { [string]: any }): BasePart
	local part = Instance.new(props.ClassName or "Part")
	props.ClassName = nil
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	-- Shape goes first so it can't override the Size set below.
	if props.Shape then
		(part :: Part).Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Offset" and key ~= "Shape" then
			(part :: any)[key] = value
		end
	end
	part.CFrame = base * (props.Offset or CFrame.new())
	part.Parent = car
	return part
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = a
end

local function attachment(parent: BasePart, worldCFrame: CFrame): Attachment
	local att = Instance.new("Attachment")
	att.CFrame = parent.CFrame:ToObjectSpace(worldCFrame)
	att.Parent = parent
	return att
end

-- Chassis: the one solid part everything else is welded to.
local chassis = makePart({
	Name = "Chassis",
	Size = Vector3.new(6, 1, 13),
	Offset = CFrame.new(0, 0.6, 0),
	Color = PAINT,
	Material = Enum.Material.SmoothPlastic,
	Reflectance = 0.2,
})
car.PrimaryPart = chassis

-- Decorative body parts: no collision and no mass, so they don't affect driving.
local function bodyPart(props: { [string]: any }): BasePart
	props.CanCollide = false
	props.Massless = true
	local part = makePart(props)
	weld(chassis, part)
	return part
end

-- Main body
bodyPart({ Name = "Body", Size = Vector3.new(6, 1.4, 13.4), Offset = CFrame.new(0, 1.7, 0),
	Color = PAINT, Material = Enum.Material.SmoothPlastic, Reflectance = 0.3 })
bodyPart({ Name = "Hood", Size = Vector3.new(5.8, 0.3, 4), Offset = CFrame.new(0, 2.5, -4.5),
	Color = PAINT, Material = Enum.Material.SmoothPlastic, Reflectance = 0.35 })
bodyPart({ Name = "Trunk", Size = Vector3.new(5.8, 0.3, 2.6), Offset = CFrame.new(0, 2.5, 5.3),
	Color = PAINT, Material = Enum.Material.SmoothPlastic, Reflectance = 0.35 })

-- Cabin with tinted glass
bodyPart({ Name = "Windshield", Size = Vector3.new(5.4, 0.2, 2.6),
	Offset = CFrame.new(0, 3.3, -1.9) * CFrame.Angles(math.rad(35), 0, 0),
	Color = Color3.fromRGB(20, 30, 40), Material = Enum.Material.Glass, Transparency = 0.4 })
bodyPart({ Name = "Roof", Size = Vector3.new(5.4, 0.25, 3.6), Offset = CFrame.new(0, 4.1, 0.9),
	Color = PAINT, Material = Enum.Material.SmoothPlastic, Reflectance = 0.3 })
bodyPart({ Name = "RearWindow", Size = Vector3.new(5.4, 0.2, 1.9),
	Offset = CFrame.new(0, 3.3, 3.4) * CFrame.Angles(math.rad(-40), 0, 0),
	Color = Color3.fromRGB(20, 30, 40), Material = Enum.Material.Glass, Transparency = 0.4 })
for _, side in { -1, 1 } do
	bodyPart({ Name = "SideWindow", Size = Vector3.new(0.2, 1.5, 3.8), Offset = CFrame.new(side * 2.75, 3.3, 0.8),
		Color = Color3.fromRGB(20, 30, 40), Material = Enum.Material.Glass, Transparency = 0.5 })
	bodyPart({ Name = "Pillar", Size = Vector3.new(0.3, 1.6, 0.3), Offset = CFrame.new(side * 2.7, 3.3, 2.8),
		Color = PAINT, Material = Enum.Material.SmoothPlastic })
end

-- Gold trim
for _, side in { -1, 1 } do
	bodyPart({ Name = "GoldStripe", Size = Vector3.new(0.1, 0.2, 13.4), Offset = CFrame.new(side * 3.05, 1.9, 0),
		Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.4 })
end
bodyPart({ Name = "Grille", Size = Vector3.new(3, 0.9, 0.2), Offset = CFrame.new(0, 1.6, -6.75),
	Color = CHROME, Material = Enum.Material.DiamondPlate, Reflectance = 0.5 })
bodyPart({ Name = "HoodOrnament", Size = Vector3.new(0.3, 0.6, 0.3), Offset = CFrame.new(0, 2.95, -6.2),
	Color = GOLD, Material = Enum.Material.Metal, Reflectance = 0.5 })

-- Lights
for _, side in { -1, 1 } do
	local headlight = bodyPart({ Name = "Headlight", Size = Vector3.new(1.2, 0.5, 0.2),
		Offset = CFrame.new(side * 2.1, 1.9, -6.75), Color = Color3.fromRGB(255, 250, 230),
		Material = Enum.Material.Neon })
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 40
	beam.Brightness = 3
	beam.Angle = 60
	beam.Parent = headlight

	bodyPart({ Name = "Taillight", Size = Vector3.new(1.4, 0.4, 0.2), Offset = CFrame.new(side * 2.1, 1.9, 6.75),
		Color = Color3.fromRGB(200, 0, 0), Material = Enum.Material.Neon })
end

-- Leather seats
local driverSeat = makePart({
	ClassName = "VehicleSeat",
	Name = "DriverSeat",
	Size = Vector3.new(2, 0.6, 2),
	Offset = CFrame.new(-1.2, 2.5, 0.8),
	Color = LEATHER,
	Material = Enum.Material.Fabric,
}) :: VehicleSeat
driverSeat.MaxSpeed = 0 -- the wheel motors below do the driving
driverSeat.HeadsUpDisplay = true
weld(chassis, driverSeat)

local passengerSeat = makePart({
	ClassName = "Seat",
	Name = "PassengerSeat",
	Size = Vector3.new(2, 0.6, 2),
	Offset = CFrame.new(1.2, 2.5, 0.8),
	Color = LEATHER,
	Material = Enum.Material.Fabric,
})
weld(chassis, passengerSeat)

-- Wheels
local grip = PhysicalProperties.new(0.7, 2, 0.1, 100, 1)
local driveMotors: { HingeConstraint } = {}
local steeringServos: { HingeConstraint } = {}

local function makeWheel(x: number, z: number, steerable: boolean)
	local wheelCFrame = base * CFrame.new(x, 0, z)

	local tire = makePart({
		Name = "Wheel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(WHEEL_WIDTH, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2),
		Offset = CFrame.new(x, 0, z),
		Color = Color3.fromRGB(25, 25, 25),
		Material = Enum.Material.Rubber,
		CustomPhysicalProperties = grip,
	})

	local rim = makePart({
		Name = "Rim",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(WHEEL_WIDTH + 0.1, WHEEL_RADIUS * 1.2, WHEEL_RADIUS * 1.2),
		Offset = CFrame.new(x, 0, z),
		Color = CHROME,
		Material = Enum.Material.Metal,
		Reflectance = 0.5,
		CanCollide = false,
		Massless = true,
	})
	weld(tire, rim)

	-- What the wheel spins on: the chassis for rear wheels, a steering knuckle for front wheels.
	local mount: BasePart = chassis
	if steerable then
		local knuckle = makePart({
			Name = "Knuckle",
			Size = Vector3.new(0.4, 0.4, 0.4),
			Offset = CFrame.new(x, 0, z),
			Transparency = 1,
			CanCollide = false,
		})
		-- Hinges turn around an attachment's X axis, so point X straight up to steer.
		local upright = CFrame.fromMatrix(wheelCFrame.Position, Vector3.yAxis, Vector3.xAxis)
		local steer = Instance.new("HingeConstraint")
		steer.ActuatorType = Enum.ActuatorType.Servo
		steer.ServoMaxTorque = 50000
		steer.AngularSpeed = 4
		steer.LimitsEnabled = true
		steer.LowerAngle = -MAX_STEER_ANGLE
		steer.UpperAngle = MAX_STEER_ANGLE
		steer.Attachment0 = attachment(chassis, upright)
		steer.Attachment1 = attachment(knuckle, upright)
		steer.Parent = knuckle
		table.insert(steeringServos, steer)
		mount = knuckle
	end

	local axle = Instance.new("HingeConstraint")
	axle.Attachment0 = attachment(mount, wheelCFrame)
	axle.Attachment1 = attachment(tire, wheelCFrame)
	if not steerable then
		axle.ActuatorType = Enum.ActuatorType.Motor
		axle.MotorMaxTorque = 30000
		axle.MotorMaxAcceleration = 60
		table.insert(driveMotors, axle)
	end
	axle.Parent = tire
end

local wheelX = 3 + WHEEL_WIDTH / 2 + 0.2
makeWheel(-wheelX, -4.3, true)
makeWheel(wheelX, -4.3, true)
makeWheel(-wheelX, 4.3, false)
makeWheel(wheelX, 4.3, false)

-- Driving: the car faces -Z, so forward means spinning the wheels backwards around X.
local function updateControls()
	local wheelSpeed = TOP_SPEED / WHEEL_RADIUS
	for _, motor in driveMotors do
		motor.AngularVelocity = -driverSeat.ThrottleFloat * wheelSpeed
		-- Hold the wheels still when there's no throttle so the car doesn't roll away.
		motor.MotorMaxTorque = if driverSeat.ThrottleFloat == 0 then 3000 else 30000
	end
	for _, servo in steeringServos do
		servo.TargetAngle = -driverSeat.SteerFloat * MAX_STEER_ANGLE
	end
end

driverSeat:GetPropertyChangedSignal("ThrottleFloat"):Connect(updateControls)
driverSeat:GetPropertyChangedSignal("SteerFloat"):Connect(updateControls)
updateControls()

car.Parent = Workspace
for _, part in car:GetDescendants() do
	if part:IsA("BasePart") then
		part.Anchored = false
	end
end

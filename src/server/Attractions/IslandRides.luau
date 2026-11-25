--!strict
-- (Build 104) Luxury Island's rides (shared/IslandCraft has the rules): the jet skis, the Day
-- Yacht and the helicopter, all the server's. It builds them, sells the two that are sold (Gilt
-- at the price shown, or Robux through Roblox's own window), sits a rider at the helm, hands the
-- ride to the rider's screen to steer (network ownership, as the house's cars), and checks every
-- ride every few beats: one that's somewhere its kind can't be (on the sand, out past the edge,
-- a helicopter over the ceiling) is taken back and set down where it last was fine. A guest's
-- own ride left empty is put away after a while, and at once when they leave the island or the
-- house; the Day Yacht with nobody at its helm goes back to its berth.
--
-- And on the moored superyacht Sovereign: the bow (stand there in the wind) and the top deck's
-- edge, where "Leap" sends a guest out in a long arc into the sea (asked of the server, which
-- lets the movement watch know first: the leap is the house's, not a cheat).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Craft = require(ReplicatedStorage.Shared.IslandCraft)
local Plan = require(ReplicatedStorage.Shared.Island)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local IslandBuild = require(script.Parent.IslandBuild)
local Types = require(script.Parent.Types)

local Rides = {}

-- Set by Main: Roblox's purchase window for a ride (Purchases.IslandRide), and whether one is on
-- sale (its product made in Creator Hub).
Rides.offer = function(_player: Player, _product: string): (boolean, string?)
	return false, "That isn't on sale yet."
end
Rides.onSale = function(_product: string): boolean
	return false
end

type Ride = {
	kind: Craft.Kind,
	model: Model,
	chassis: BasePart,
	seat: VehicleSeat,
	owner: Player?, -- a guest's own (nil: the Day Yacht)
	spot: number, -- which launch spot it came out at
	good: Vector3, -- (local) where it last was fine
	emptySince: number?,
	captain: Player?,
}

local origin = Vector3.zero
local folder: Instance? = nil
local rides: { [string]: Ride } = {} -- by key: "<kind>:<userId>", or "yacht"
local padDisplay: Model? = nil
local leapSpots: { BasePart } = {}
local clock = os.clock

local function key(kind: string, player: Player?): string
	return if player then kind .. ":" .. tostring(player.UserId) else kind
end

-- The guest's island page's rides (kept for good).
local function owned(p: { [string]: any }): { [string]: boolean }
	if type(p.rides) ~= "table" then
		p.rides = {}
	end
	return p.rides
end

function Rides.owns(p: { [string]: any }, id: string): boolean
	local k = Craft.KINDS[id]
	if not k then
		return false
	end
	return k.free == true or owned(p)[id] == true
end

-- What a guest's screen shows of the rides: each one's price, whether it's theirs, whether its
-- Robux window can open.
function Rides.state(p: { [string]: any }): { [string]: any }
	local out = {}
	for _, id in Craft.ORDER do
		local k = Craft.KINDS[id]
		out[id] = {
			owned = Rides.owns(p, id),
			gilt = k.gilt,
			robux = if k.product then Rides.onSale(k.product) else false,
			free = k.free == true,
		}
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Building a ride
---------------------------------------------------------------------------------------------------
local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A jet ski: a white hull with a raked bow, a deep blue deck, a gold line, a padded saddle, black
-- bars, a light bar at the stern; its saddle is its helm.
local function jetski(parent: Instance, cf: CFrame): (Model, CFrame)
	local m = Instance.new("Model")
	m.Name = "JetSki"
	local white, navy, gold = Color3.fromRGB(246, 246, 242), Color3.fromRGB(22, 40, 78), Color3.fromRGB(214, 176, 92)
	part(m, "Hull", Vector3.new(3.2, 1.1, 7), cf * CFrame.new(0, 0.2, 0.6), white, Enum.Material.SmoothPlastic)
	local bow = Instance.new("WedgePart")
	bow.Name = "Bow"
	bow.Size = Vector3.new(3.2, 1.1, 2.6)
	bow.CFrame = cf * CFrame.new(0, 0.2, -4.2) * CFrame.Angles(0, math.pi, 0)
	bow.Color = white
	bow.Material = Enum.Material.SmoothPlastic
	bow.Anchored = true
	bow.CanCollide = false
	bow.Parent = m
	part(m, "Deck", Vector3.new(2.9, 0.35, 6.6), cf * CFrame.new(0, 0.9, 0.6), navy, Enum.Material.SmoothPlastic)
	for _, side in { -1, 1 } do
		part(m, "GoldLine", Vector3.new(0.08, 0.16, 6.8), cf * CFrame.new(side * 1.62, 0.55, 0.5), gold, Enum.Material.Metal)
	end
	part(m, "Saddle", Vector3.new(1.4, 0.6, 3.2), cf * CFrame.new(0, 1.35, 1.1), Color3.fromRGB(26, 26, 30), Enum.Material.Leather)
	part(m, "Console", Vector3.new(1.8, 0.9, 1.2), cf * CFrame.new(0, 1.35, -1.4), white, Enum.Material.SmoothPlastic)
	part(m, "Bars", Vector3.new(2.6, 0.18, 0.18), cf * CFrame.new(0, 2.05, -1.3), Color3.fromRGB(18, 18, 20), Enum.Material.Metal)
	part(m, "Screen", Vector3.new(1.2, 0.5, 0.08), cf * CFrame.new(0, 1.95, -1.95) * CFrame.Angles(math.rad(-25), 0, 0), Color3.fromRGB(20, 26, 34), Enum.Material.Glass)
	local light = part(m, "LightBar", Vector3.new(2.6, 0.18, 0.12), cf * CFrame.new(0, 0.75, 4.15), Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
	light:SetAttribute("CraftGlow", true)
	return m, cf * CFrame.new(0, 1.55, 1.1)
end

-- The parts of a built ride come loose and ride on an unseen chassis: every one welded to it,
-- weightless; only the chassis (and, on the yacht, its decks, so guests can stand aboard) touches
-- anything.
local SOLID = { Deck = true, Flybridge = true, SwimPlatform = true, Hull = true, Bow = true, Boot = true }
local function rig(model: Model, kind: Craft.Kind, base: CFrame, helm: CFrame, owner: Player?): (BasePart, VehicleSeat)
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = kind.size
	chassis.CFrame = base * CFrame.new(0, kind.ride, 0)
	chassis.Transparency = 1
	chassis.CanCollide = true
	chassis.CanQuery = false
	chassis.CanTouch = false
	chassis.Anchored = true
	pcall(function()
		chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.05, 0, 1, 1)
	end)
	chassis.Parent = model
	model.PrimaryPart = chassis
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= chassis then
			d.Anchored = false
			d.Massless = true
			d.CanCollide = kind.id == "yacht" and SOLID[d.Name] == true
			d.CanTouch = false
			weld(chassis, d)
		end
	end
	local seat = Instance.new("VehicleSeat")
	seat.Name = "HelmSeat"
	seat.Size = Vector3.new(2, 0.3, 2)
	seat.CFrame = helm
	seat.Transparency = 1
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.Massless = true
	seat.CanCollide = false
	seat.CanTouch = false -- (sat in by the house, never by walking into it)
	seat.Anchored = false
	seat.Parent = model
	weld(chassis, seat)
	local attach = Instance.new("Attachment")
	attach.Name = "Centre"
	attach.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = attach
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drive.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	drive.MaxAxesForce = Vector3.new(6e5, 6e5, 6e5)
	drive.VectorVelocity = Vector3.zero
	drive.Parent = chassis
	local steer = Instance.new("AlignOrientation")
	steer.Name = "Steer"
	steer.Mode = Enum.OrientationAlignmentMode.OneAttachment
	steer.Attachment0 = attach
	steer.MaxTorque = 6e6
	steer.Responsiveness = 30
	steer.CFrame = base.Rotation
	steer.Parent = chassis
	model:SetAttribute("CraftKind", kind.id)
	model:SetAttribute("CraftName", kind.name)
	model:SetAttribute("Owner", if owner then owner.UserId else 0)
	pcall(function()
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end)
	CollectionService:AddTag(model, "IslandCraft")
	return chassis, seat
end

local function build(kind: Craft.Kind, at: CFrame, owner: Player?): (Model, BasePart, VehicleSeat)
	local world = CFrame.new(origin) * at
	local model: Model
	local helm: CFrame
	if kind.id == "jetski" then
		model, helm = jetski(folder :: Instance, world * CFrame.new(0, kind.ride - 0.2, 0))
	elseif kind.id == "yacht" then
		model = IslandBuild.yachtModel(folder :: Instance, world, 44, "Aurelia", "DayYacht")
		local k = 44 / 50
		helm = world * CFrame.new(0, 12.1 * k, -2 * k) -- (on the flybridge, looking forward)
	else
		model = IslandBuild.helicopterModel(folder :: Instance, world)
		model.Name = "IslandHelicopter"
		helm = world * CFrame.new(-1, 3.2, -1.6)
	end
	model.Name = if owner then model.Name .. "_" .. owner.Name else model.Name
	local chassis, seat = rig(model, kind, world, helm, owner)
	model.Parent = folder
	return model, chassis, seat
end

-- A part on the island to hang a prompt on, unseen.
local function anchor(parent: Instance, name: string, at: Vector3, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size or Vector3.new(3, 5, 3)
	p.CFrame = CFrame.new(origin + at)
	p.Parent = parent
	return p
end

-- The Jet Ski Hire on the sand: a teak booth under a white canopy, its sign, and a ski on a
-- stand beside it, in the island's blue and gold.
local function hire(parent: Instance): BasePart
	local m = Instance.new("Model")
	m.Name = "JetSkiHire"
	local at = Craft.Places.jetski.ask
	local base = IslandBuild.groundAt(at.X, at.Z)
	local cf = CFrame.lookAt(origin + Vector3.new(at.X, base, at.Z), origin + Vector3.new(at.X, base, at.Z + 10))
	local teak, white, gold = Color3.fromRGB(150, 98, 58), Color3.fromRGB(246, 242, 232), Color3.fromRGB(214, 176, 92)
	local deck = part(m, "HireDeck", Vector3.new(12, 0.6, 8), cf * CFrame.new(0, 0.3, 0), teak, Enum.Material.WoodPlanks)
	deck.CanCollide = true
	local counter = part(m, "Counter", Vector3.new(6, 3.4, 1.6), cf * CFrame.new(-2, 2.3, -2), white, Enum.Material.SmoothPlastic)
	counter.CanCollide = true
	part(m, "CounterTop", Vector3.new(6.4, 0.2, 2), cf * CFrame.new(-2, 4.1, -2), gold, Enum.Material.Metal)
	for _, x in { -5.6, 5.6 } do
		for _, z in { -3.6, 3.6 } do
			part(m, "Post", Vector3.new(0.35, 8, 0.35), cf * CFrame.new(x, 4.6, z), teak, Enum.Material.Wood)
		end
	end
	part(m, "Canopy", Vector3.new(12.6, 0.3, 8.6), cf * CFrame.new(0, 8.7, 0), white, Enum.Material.Fabric)
	part(m, "CanopyBand", Vector3.new(12.7, 0.6, 8.7), cf * CFrame.new(0, 8.3, 0), Color3.fromRGB(22, 40, 78), Enum.Material.Fabric)
	local sign = part(m, "HireSign", Vector3.new(7, 1.4, 0.2), cf * CFrame.new(0, 7.2, -4.4), Color3.fromRGB(18, 18, 22), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = sign
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = gold
	t.Text = "JET SKI HIRE"
	t.Parent = gui
	-- A ski on its stand, to show what's had here.
	local show, _ = jetski(m, cf * CFrame.new(4, 1.6, 0.6) * CFrame.Angles(0, math.rad(25), 0))
	show.Name = "JetSkiShown"
	m.Parent = parent
	return anchor(parent, "JetSkiHirePrompt", at + Vector3.new(0, 2.5, 0))
end

-- On the moored Sovereign: a Leap spot at its upper deck's seaward rail, and an aura spot at its
-- bow (a tag each screen dresses in the wind).
local function sovereign(parent: Instance)
	local yachtAt = CFrame.new(-284, Plan.SEA, 103) * CFrame.Angles(0, math.rad(90), 0)
	local k = 62 / 50
	-- (Its flybridge, the top deck: boarding sets a guest on it, its view the whole bay.)
	local top = yachtAt * CFrame.new(0, 11.9 * k, 2 * k)
	local leap = anchor(parent, "YachtLeap", (top * CFrame.new(0, 0, 4 * k)).Position + Vector3.new(0, 2.5, 0))
	table.insert(leapSpots, leap)
	local aura = anchor(parent, "YachtAura", (top * CFrame.new(0, 0, -3.5 * k)).Position + Vector3.new(0, 2.5, 0), Vector3.new(6, 5, 5))
	CollectionService:AddTag(aura, "IslandAuraSpot")
	-- The Sovereign's decks, from the pier.
	local foot = anchor(parent, "SovereignGangway", Vector3.new(-284, Plan.GROUND, 86))
	foot:SetAttribute("BoardTo", origin + top.Position + Vector3.new(0, 3, 0))
end

-- The prompts' parts, by what they do (for Island.build to put the house's prompts on).
export type Built = { hire: BasePart, heli: BasePart, yachtHelm: BasePart, yachtBoard: BasePart, leap: { BasePart }, gangway: BasePart? }

function Rides.build(parent: Instance, o: Vector3): Built
	origin = o
	local f = Instance.new("Folder")
	f.Name = "IslandRides"
	f.Parent = parent
	folder = f
	local isl = parent:FindFirstChild("LuxuryIsland", true)
	local pad = isl and isl:FindFirstChild("PadHelicopter", true)
	padDisplay = if pad and pad:IsA("Model") then pad else nil
	local hirePrompt = hire(f)
	local heli = anchor(f, "HelicopterPrompt", Craft.Places.heli.ask + Vector3.new(6, 2.5, 6))
	local yb = Craft.Places.yacht.ask
	local board = anchor(f, "DayYachtBoard", yb + Vector3.new(0, 2.5, 0))
	local helm = anchor(f, "DayYachtHelm", yb + Vector3.new(4, 2.5, -2))
	sovereign(f)
	-- The Day Yacht waits at its berth from the start.
	local yacht = Craft.KINDS.yacht
	local model, chassis, seat = build(yacht, Craft.Places.yacht.launch[1], nil)
	rides.yacht = { kind = yacht, model = model, chassis = chassis, seat = seat, owner = nil, spot = 1, good = Craft.Places.yacht.launch[1].Position + Vector3.new(0, yacht.ride, 0) }
	local gangway = f:FindFirstChild("SovereignGangway")
	return { hire = hirePrompt, heli = heli, yachtHelm = helm, yachtBoard = board, leap = leapSpots, gangway = if gangway and gangway:IsA("BasePart") then gangway else nil }
end

---------------------------------------------------------------------------------------------------
-- Buying, riding, boarding, leaping
---------------------------------------------------------------------------------------------------
local function near(ctx: Types.Ctx, player: Player, at: Vector3, reach: number?): boolean
	local root = ctx.rootOf(player)
	if not root then
		return false
	end
	return (root.CFrame.Position - (origin + at)).Magnitude <= (reach or Craft.REACH)
end

-- Bought with Gilt (exactly the price shown, once: a ride already theirs is never charged for
-- again), or Roblox's window opened for Robux (the receipt grants it: Purchases/IslandRide).
function Rides.buy(ctx: Types.Ctx, player: Player, p: { [string]: any }, id: string, how: string): { [string]: any }
	local k = Craft.KINDS[id]
	if not k or k.free then
		return { ok = false, why = "That isn't something the house sells." }
	end
	if Rides.owns(p, id) then
		return { ok = false, why = "The " .. k.name .. " is yours already." }
	end
	if how == "robux" then
		if not k.product or not Rides.onSale(k.product) then
			return { ok = false, why = "The " .. k.name .. " isn't on sale for Robux yet: it's yours for Gilt." }
		end
		local opened, why = Rides.offer(player, k.product)
		if not opened then
			return { ok = false, why = why or "The purchase window couldn't open." }
		end
		return { ok = false, prompted = true } -- (the purchase window is open; its price is in it)
	end
	local price = k.gilt or 0
	if price <= 0 then
		return { ok = false, why = "That isn't something the house sells." }
	end
	if not ctx.spend(player, price, 0, "island_" .. id) then
		return { ok = false, short = "Gilt", why = string.format("The %s is %s Gilt.", k.name, Fortune.format(price)) }
	end
	owned(p)[id] = true
	return { ok = true, title = "The " .. k.name .. " is yours", line = "Yours for good: ride it whenever you're on the island." }
end

-- (Purchases/IslandRide: a Robux receipt's grant.)
function Rides.grant(p: { [string]: any }, id: string): boolean
	if not Craft.KINDS[id] then
		return false
	end
	owned(p)[id] = true
	return true
end

local function sit(player: Player, seat: VehicleSeat): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	pcall(function()
		local old = humanoid.SeatPart
		if old and old ~= seat then
			local w = old:FindFirstChild("SeatWeld")
			if w then
				w:Destroy()
			end
			humanoid.Sit = false
		end
	end)
	seat:Sit(humanoid)
	return true
end

local function letGo(r: Ride, player: Player?)
	r.chassis.Anchored = false
	if player then
		pcall(function()
			(r.chassis :: any):SetNetworkOwner(player)
		end)
	end
end

local function freeSpot(id: string): number
	local spots = Craft.Places[id].launch
	for i, at in spots do
		local clear = true
		for _, r in rides do
			if (r.chassis.CFrame.Position - (origin + at.Position)).Magnitude < (if id == "jetski" then 6 else 14) then
				clear = false
			end
		end
		if clear then
			return i
		end
	end
	return 1
end

local function showPad(on: boolean)
	local m = padDisplay
	if not m then
		return
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			if on then
				local t = d:GetAttribute("ShownT")
				if type(t) == "number" then
					d.Transparency = t
					d:SetAttribute("ShownT", nil)
				end
				d.CanCollide = d:GetAttribute("ShownC") == true
			else
				if d:GetAttribute("ShownT") == nil then
					d:SetAttribute("ShownT", d.Transparency)
					d:SetAttribute("ShownC", d.CanCollide)
				end
				d.Transparency = 1
				d.CanCollide = false
			end
		end
	end
end

-- Puts a ride away (a guest's own: gone; the Day Yacht: back at its berth, anyone aboard set on
-- the pier first).
local function putAway(ctx: Types.Ctx, keyName: string)
	local r = rides[keyName]
	if not r then
		return
	end
	if r.kind.id == "yacht" then
		local berth = Craft.Places.yacht.launch[1]
		-- (Whoever's aboard is set on the pier, not left in the sea.)
		local box = r.model:GetExtentsSize()
		for _, player in Players:GetPlayers() do
			local root = ctx.rootOf(player)
			if root then
				local rel = r.chassis.CFrame:PointToObjectSpace(root.CFrame.Position)
				if math.abs(rel.X) <= box.X / 2 + 2 and math.abs(rel.Z) <= box.Z / 2 + 2 and rel.Y > -3 and rel.Y < box.Y + 4 then
					pcall(function()
						local humanoid = (player.Character :: Model):FindFirstChildOfClass("Humanoid")
						if humanoid and humanoid.SeatPart == r.seat then
							local w = r.seat:FindFirstChild("SeatWeld")
							if w then
								w:Destroy()
							end
							humanoid.Sit = false
						end
					end)
					ctx.teleport(player, CFrame.new(origin + Craft.Places.yacht.ask + Vector3.new(0, 0.5, 0)))
				end
			end
		end
		r.chassis.Anchored = true
		r.model:PivotTo(CFrame.new(origin) * berth * CFrame.new(0, r.kind.ride, 0))
		r.good = berth.Position + Vector3.new(0, r.kind.ride, 0)
		r.emptySince = nil
		r.captain = nil
		return
	end
	rides[keyName] = nil
	pcall(function()
		local w = r.seat:FindFirstChild("SeatWeld")
		if w then
			w:Destroy()
		end
	end)
	r.model:Destroy()
	if r.kind.id == "heli" and r.spot == 1 then
		showPad(true)
	end
end

-- Takes the helm: of the guest's own jet ski or helicopter (out at its launch spot, or the one
-- they have out already), or of the Day Yacht (if nobody else has it).
function Rides.ride(ctx: Types.Ctx, player: Player, p: { [string]: any }, id: string): { [string]: any }
	local k = Craft.KINDS[id]
	if not k then
		return { ok = false, why = "That isn't a ride the island has." }
	end
	if not near(ctx, player, Craft.Places[id].ask, Craft.REACH + (if id == "yacht" then 8 else 0)) then
		return { ok = false, why = "Come a little closer." }
	end
	if not Rides.owns(p, id) then
		return { ok = false, panel = "rides", why = string.format("The %s is yours for %s Gilt%s.", k.name, Fortune.format(k.gilt or 0), if k.product and Rides.onSale(k.product) then " or Robux" else "") }
	end
	if id == "yacht" then
		local r = rides.yacht
		if not r then
			return { ok = false, why = "The Day Yacht isn't at its berth just now." }
		end
		local cap = r.captain
		if cap and cap ~= player and cap.Parent then
			local character = cap.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.SeatPart == r.seat then
				return { ok = false, why = cap.DisplayName .. " has the helm just now: step aboard with Board." }
			end
		end
		r.captain = player
		r.emptySince = nil
		sit(player, r.seat)
		letGo(r, player)
		return { ok = true }
	end
	-- One of their own at a time: the one out already, if there is one.
	local keyName = key(id, player)
	local r = rides[keyName]
	if not r then
		local spot = freeSpot(id)
		local at = Craft.Places[id].launch[spot]
		local model, chassis, seat = build(k, at, player)
		r = { kind = k, model = model, chassis = chassis, seat = seat, owner = player, spot = spot, good = at.Position + Vector3.new(0, k.ride, 0) }
		rides[keyName] = r
		if id == "heli" and spot == 1 then
			showPad(false)
		end
	end
	local mine = r :: Ride
	mine.emptySince = nil
	ctx.moved(player)
	sit(player, mine.seat)
	letGo(mine, player)
	return { ok = true }
end

-- Aboard the Day Yacht as a guest, or the moored Sovereign (from the pier, near the gangway).
function Rides.board(ctx: Types.Ctx, player: Player, which: string): { [string]: any }
	if which == "sovereign" then
		local g = folder and folder:FindFirstChild("SovereignGangway")
		local to = g and g:GetAttribute("BoardTo")
		if not g or typeof(to) ~= "Vector3" or not near(ctx, player, (g :: BasePart).CFrame.Position - origin) then
			return { ok = false, why = "Come a little closer." }
		end
		ctx.moved(player)
		ctx.teleport(player, CFrame.new(to))
		return { ok = true }
	end
	local r = rides.yacht
	if not r then
		return { ok = false, why = "The Day Yacht isn't at its berth just now." }
	end
	local deckAt = (r.chassis.CFrame * CFrame.new(0, 3.2, 8)).Position
	if not near(ctx, player, Craft.Places.yacht.ask, Craft.REACH + 8) and not near(ctx, player, deckAt - origin, 30) then
		return { ok = false, why = "Come a little closer." }
	end
	ctx.moved(player)
	ctx.teleport(player, CFrame.new(deckAt))
	return { ok = true }
end

-- The leap off the Sovereign's top deck: the server lets the movement watch know (a few moments
-- of moving freely), and the guest's screen sends them out over the water.
function Rides.leap(ctx: Types.Ctx, player: Player): { [string]: any }
	for _, spot in leapSpots do
		if near(ctx, player, spot.CFrame.Position - origin, 10) then
			ctx.moved(player, 6)
			return { ok = true, send = { op = "island", what = "leap", dir = Vector3.new(0, 0, 1) } }
		end
	end
	return { ok = false, why = "Leap from the Sovereign's top deck, at its rail." }
end

---------------------------------------------------------------------------------------------------
-- Every beat: rides where they may be, empty ones put away
---------------------------------------------------------------------------------------------------
-- Who's at a ride's helm: its owner (or the Day Yacht's captain), sat in its helm seat.
local function riderOf(r: Ride): Player?
	local who = r.owner or r.captain
	if who and who.Parent then
		local character = who.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart == r.seat then
			return who
		end
	end
	return nil
end

local lastCheck = 0
function Rides.step(ctx: Types.Ctx)
	local t = clock()
	if t - lastCheck < 0.25 then
		return
	end
	lastCheck = t
	for keyName, r in rides do
		if r.model.Parent == nil then
			rides[keyName] = nil
			continue
		end
		local rider = riderOf(r)
		-- The owner gone from the house: their ride with them.
		if r.owner and r.owner.Parent == nil then
			putAway(ctx, keyName)
			continue
		end
		if rider then
			r.emptySince = nil
			-- Somewhere its kind can't be: taken back, set down where it last was fine.
			local here = r.chassis.CFrame.Position - origin
			if Craft.allowedAt(r.kind, here) then
				r.good = here
			else
				r.chassis.Anchored = true
				r.model:PivotTo(CFrame.new(origin + r.good) * r.chassis.CFrame.Rotation)
				ctx.notice(rider, r.kind.name, if r.kind.water then "That's as far as the water goes." else "That's as far as the island's sky goes.")
				task.delay(0.3, function()
					if r.model.Parent and riderOf(r) == rider then
						letGo(r, rider)
					end
				end)
			end
		else
			r.emptySince = r.emptySince or t
			local wait = if r.kind.id == "yacht" then Craft.RETURN_SECONDS else Craft.IDLE_SECONDS
			if t - (r.emptySince :: number) >= wait then
				if r.kind.id ~= "yacht" or (r.chassis.CFrame.Position - (origin + Craft.Places.yacht.launch[1].Position)).Magnitude > 4 then
					putAway(ctx, keyName)
				else
					r.emptySince = nil
				end
			elseif not r.chassis.Anchored and t - (r.emptySince :: number) > 1 then
				-- (Nobody at the helm: it stops where it is, on the water or the ground.)
				r.chassis.Anchored = true
				if r.kind.water then
					local p = r.chassis.CFrame.Position
					r.model:PivotTo(CFrame.new(Vector3.new(p.X, origin.Y + Plan.SEA + r.kind.ride, p.Z)) * r.chassis.CFrame.Rotation)
				else
					-- (A helicopter left in the air settles on the ground under it.)
					local p = r.chassis.CFrame.Position - origin
					local ground = math.max(IslandBuild.groundAt(p.X, p.Z), Plan.SEA)
					r.model:PivotTo(CFrame.new(origin + Vector3.new(p.X, ground + 0.4, p.Z)) * r.chassis.CFrame.Rotation)
				end
			end
		end
	end
end

-- A guest gone from the island (home, or the house): their own rides put away, the Day Yacht's
-- helm let go.
function Rides.leave(ctx: Types.Ctx, player: Player)
	for _, id in Craft.ORDER do
		if rides[key(id, player)] then
			putAway(ctx, key(id, player))
		end
	end
	local y = rides.yacht
	if y and y.captain == player then
		y.captain = nil
	end
end

-- For tests.
function Rides.rides(): { [string]: any }
	return rides
end
function Rides.setClock(fn: () -> number)
	clock = fn
end

return Rides

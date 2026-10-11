--!strict
-- Santa's Sleigh (Christmas): the ride to the North Pole and the gifts.
--
-- The sleigh waits at the Maison's kerb: red lacquer and gold, eight velvet seats, a sack of gifts,
-- nine reindeer in harness with Rudolph leading, and Father Christmas at the reins. Guests board
-- it (its prompt, or the Sleigh key in the dock); once someone has sat down it leaves after a few
-- seconds (sooner when it's full). The flight is drawn on every screen from the time it left (the
-- sleigh lifting off along the street, over the house, through the clouds and the northern lights,
-- down onto the North Pole's pad); the riders themselves are carried there by the server.
--
-- At the North Pole: a snowfield round Santa's Workshop, the great tree, the elves' cottages, and
-- gifts lying in the snow. Run to pick them up (a few at a time in your arms) and carry them back to
-- the sleigh to load them before it leaves; anything still in your arms when it goes is left
-- behind. Everyone at the Pole flies home with it. Loaded gifts are kept (in the guest's saved
-- record) and opened at the Maison: Gilt, a heap of Gilt, Gems, or once in a while a trove of Gems,
-- chosen by the server when each is opened, with the odds shown on the screen that opens them.
-- They're free: no gift, and nothing that makes more of them, is ever sold.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Brand = require(ReplicatedStorage.Shared.Brand)
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local HolidayProps = require(ReplicatedStorage.Shared.HolidayProps)
local Kit = require(script.Parent.Parent.World.Kit)
local Profiles = require(script.Parent.Parent.Profiles)
local Rig = require(script.Parent.Parent.Staff.Rig)
local Dress = require(script.Parent.Dress)
local Types = require(script.Parent.Types)

local Pole = {}

local rgb = Color3.fromRGB
local L = Kit.Looks
type Look = Kit.Look
local function look(colour: Color3, material: Enum.Material, reflectance: number?, transparency: number?): Look
	return { color = colour, material = material, reflectance = reflectance, transparency = transparency }
end
local TRIM = { collide = false, query = false, shadow = false }
local GOLD = HolidayProps.GOLD

-- The sleigh's own frame: +x to the right, -z ahead, the ground at y 0.
Pole.SEATS = {
	CFrame.new(-2.85, 3.9, -0.4),
	CFrame.new(-0.95, 3.9, -0.4),
	CFrame.new(0.95, 3.9, -0.4),
	CFrame.new(2.85, 3.9, -0.4),
	CFrame.new(-2.85, 4.7, 4.6),
	CFrame.new(-0.95, 4.7, 4.6),
	CFrame.new(0.95, 4.7, 4.6),
	CFrame.new(2.85, 4.7, 4.6),
}
Pole.CARGO = CFrame.new(0, 3, 9.8) -- where gifts are loaded: the sack at the back
Pole.DRIVER = CFrame.new(0, 4.2, -4.8)

export type State = "home" | "boarding" | "toPole" | "pole" | "toHome"

local sleigh: Model? = nil
local santa: Model? = nil
local boardPrompt: ProximityPrompt? = nil
local area: Model? = nil
local giftFolder: Folder? = nil
local state: State = "home"
local stateAt = 0 -- os.clock when the state began
local leaveAt = 0 -- os.clock when it leaves (boarding, or at the Pole)
local gathered = false
local opened = false
local seats: { [number]: { player: Player, seat: Seat } } = {}
local riders: { [Player]: number } = {} -- in the air: their seat (0: none)
local carrying: { [Player]: number } = {}
local loadedTrip: { [Player]: number } = {}
local lastFull: { [Player]: number } = {}

type Gift = { id: number, part: Part }
local gifts: { Gift } = {}
local nextGift = 0

local function cfgPole(ctx: Types.Ctx)
	return ctx.cfg().pole
end

local function serverNow(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.time()
end

local function frame(): CFrame
	local s = sleigh
	return if s and s.PrimaryPart then s.PrimaryPart.CFrame else HolidayGames.HOME_SLEIGH
end

local function setState(ctx: Types.Ctx, s: State)
	state = s
	stateAt = os.clock()
	Workspace:SetAttribute("SleighState", s)
	if s == "toPole" or s == "toHome" then
		Workspace:SetAttribute("SleighT0", serverNow())
		Workspace:SetAttribute("SleighFlight", cfgPole(ctx).flight)
	end
	if s == "boarding" or s == "pole" then
		Workspace:SetAttribute("SleighLeaves", serverNow() + (leaveAt - os.clock()))
	else
		Workspace:SetAttribute("SleighLeaves", nil)
	end
	local prompt = boardPrompt
	if prompt then
		prompt.Enabled = s == "home" or s == "boarding" or s == "pole"
		prompt.ActionText = if s == "pole" then "Take a seat for home" else "Board the sleigh"
	end
	ctx.broadcast({ op = "sleigh", state = s })
end

---------------------------------------------------------------------------------------------------
-- The sleigh
---------------------------------------------------------------------------------------------------
local function buildSleigh(): Model
	local m = Instance.new("Model")
	m.Name = "SantasSleigh"
	local S = HolidayGames.HOME_SLEIGH
	local root = Kit.part(m, "SleighRoot", Vector3.new(1, 1, 1), S, look(rgb(255, 255, 255), Enum.Material.SmoothPlastic, 0, 1), TRIM)
	m.PrimaryPart = root
	local red = look(rgb(176, 16, 30), Enum.Material.SmoothPlastic, 0.12)
	local deep = look(rgb(120, 10, 22), Enum.Material.SmoothPlastic, 0.08)
	local gold = look(GOLD, Enum.Material.Metal, 0.25)
	local velvet = look(rgb(24, 86, 54), Enum.Material.Fabric)
	local function box(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, lk: Look, opts: { [string]: any }?): Part
		local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
		return Kit.part(m, name, size, S * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), lk, opts or TRIM)
	end
	local function local3(x: number, y: number, z: number): Vector3
		return (S * CFrame.new(x, y, z)).Position
	end
	-- The runners: gold, flat along the snow, curling up and back at the front.
	local curl = { { 7.6, 0.45 }, { -6, 0.45 }, { -8.4, 0.9 }, { -10.2, 2.2 }, { -11, 3.9 }, { -10.7, 5.4 }, { -9.7, 6.1 }, { -8.8, 5.7 }, { -8.6, 4.9 } }
	for _, sx in { -1, 1 } do
		for k = 1, #curl - 1 do
			local a, b = curl[k], curl[k + 1]
			HolidayProps.rod(m, "Runner", local3(sx * 3.7, a[2], a[1]), local3(sx * 3.7, b[2], b[1]), 0.5, GOLD, Enum.Material.Metal)
		end
		for _, z in { -4.5, -0.5, 3.5, 7 } do
			HolidayProps.rod(m, "Strut", local3(sx * 3.7, 0.5, z), local3(sx * 3.6, 2.3, z), 0.3, GOLD, Enum.Material.Metal)
		end
	end
	-- The body: a floor, high sides with gold edges, a raked bow, a swan's-neck dash with a curl.
	box("Floor", -4.2, 2.2, -6.4, 4.2, 2.9, 10.8, deep)
	for _, sx in { -1, 1 } do
		box("Side", sx * 4.0, 2.2, -6.4, sx * 4.4, 5.6, 8.2, red)
		box("SideLow", sx * 4.0, 2.2, 8.2, sx * 4.4, 4.2, 10.8, red)
		HolidayProps.rod(m, "Edge", local3(sx * 4.25, 5.65, -6.4), local3(sx * 4.25, 5.65, 8.2), 0.32, GOLD, Enum.Material.Metal)
		HolidayProps.rod(m, "Edge", local3(sx * 4.25, 4.25, 8.2), local3(sx * 4.25, 4.25, 10.8), 0.3, GOLD, Enum.Material.Metal)
		-- A gold scroll on each side.
		for k = 0, 2 do
			HolidayProps.ellipsoid(m, "Scroll", Vector3.new(0.18, 1.3 - k * 0.3, 2.4 - k * 0.5), S * CFrame.new(sx * 4.45, 3.9, -2 + k * 3.4) * CFrame.Angles(math.rad(20 * (k - 1)), 0, 0), GOLD, Enum.Material.Metal)
		end
		for k = 0, 5 do
			HolidayProps.ball(m, "Bell", 0.42, local3(sx * 4.55, 5.2, -5 + k * 2.5), GOLD, Enum.Material.Metal).Reflectance = 0.3
		end
	end
	box("Back", -4.2, 2.2, 10.4, 4.2, 4.2, 10.8, red)
	box("Dash", -4.2, 2.2, -6.8, 4.2, 6.6, -6.2, red)
	local bow = Instance.new("WedgePart")
	bow.Name = "Bow"
	bow.Anchored = true
	bow.CanCollide = false
	bow.Size = Vector3.new(8.4, 4.4, 2.6)
	-- (A wedge is tall at its back: here at the dash, sloping down to the front.)
	bow.CFrame = S * CFrame.new(0, 4.4, -8.1)
	bow.Color = red.color
	bow.Material = red.material
	bow.Reflectance = 0.12
	bow.Parent = m
	Kit.part(m, "DashCurl", Vector3.new(8.8, 2.4, 2.4), S * CFrame.new(0, 7.2, -6.8), red, { shape = Enum.PartType.Cylinder, collide = false, query = false })
	for _, sx in { -1, 1 } do
		Kit.part(m, "CurlCap", Vector3.new(0.3, 2.6, 2.6), S * CFrame.new(sx * 4.5, 7.2, -6.8), gold, { shape = Enum.PartType.Cylinder, collide = false, query = false, shadow = false })
		-- Lanterns on gold posts at the front corners.
		HolidayProps.rod(m, "LanternPost", local3(sx * 4.6, 5.6, -6.2), local3(sx * 4.9, 8.6, -6.4), 0.2, GOLD, Enum.Material.Metal)
		local glass = Kit.part(m, "Lantern", Vector3.new(0.9, 1.3, 0.9), S * CFrame.new(sx * 4.9, 9.2, -6.4), L.glassWarm, TRIM)
		Kit.part(m, "LanternCap", Vector3.new(1.1, 0.3, 1.1), S * CFrame.new(sx * 4.9, 10, -6.4), gold, TRIM)
		Kit.pointLight(glass, 1.6, 16, rgb(255, 196, 120))
	end
	-- The seats: the driver's perch at the front, two velvet benches, the high back of the rear.
	box("Perch", -1.6, 2.9, -5.9, 1.6, 4, -3.8, deep)
	box("PerchCushion", -1.5, 4, -5.8, 1.5, 4.3, -3.9, velvet)
	box("FrontSeat", -3.9, 2.9, -1.6, 3.9, 3.6, 0.8, deep)
	box("FrontCushion", -3.8, 3.6, -1.5, 3.8, 3.95, 0.7, velvet)
	box("FrontBack", -3.9, 3.6, 0.8, 3.9, 6.4, 1.4, red)
	box("FrontBackCushion", -3.7, 3.9, 0.66, 3.7, 6.1, 0.8, velvet)
	box("RearSeat", -3.9, 2.9, 3.4, 3.9, 4.4, 5.8, deep)
	box("RearCushion", -3.8, 4.4, 3.5, 3.8, 4.75, 5.7, velvet)
	box("RearBack", -4.2, 4.4, 5.8, 4.2, 8.6, 6.6, red)
	box("RearBackCushion", -3.8, 4.8, 5.66, 3.8, 8.2, 5.8, velvet)
	HolidayProps.rod(m, "BackEdge", local3(-4.2, 8.65, 6.2), local3(4.2, 8.65, 6.2), 0.36, GOLD, Enum.Material.Metal)
	Kit.part(m, "Crest", Vector3.new(0.3, 1.6, 1.6), S * CFrame.new(0, 9.4, 6.2) * CFrame.Angles(0, math.pi / 2, 0), gold, { shape = Enum.PartType.Cylinder, collide = false, query = false, shadow = false })
	-- The sack of gifts at the back, a few poking out.
	HolidayProps.ellipsoid(m, "Sack", Vector3.new(5.6, 5.2, 4), S * CFrame.new(0, 5.2, 8.8), rgb(150, 30, 34), Enum.Material.Fabric)
	Kit.part(m, "SackTie", Vector3.new(0.5, 1.8, 1.8), S * CFrame.new(0, 7.8, 8.8) * CFrame.Angles(0, 0, math.pi / 2), gold, { shape = Enum.PartType.Cylinder, collide = false, query = false, shadow = false })
	for k, w in HolidayProps.WRAPS do
		if k > 3 then
			break
		end
		HolidayProps.gift(m, S * CFrame.new(-1.4 + (k - 1) * 1.4, 7.4, 8.6 + (k % 2) * 0.6) * CFrame.Angles(0.2 * k, 0.6 * k, 0.15), Vector3.new(1.4, 1.3, 1.4), w[1], w[2])
	end
	-- The reindeer, two by two, Rudolph leading; their traces and the reins.
	local deer = Kit.model(m, "Reindeer")
	local rows = { -16, -23, -30, -37 }
	for _, z in rows do
		for _, sx in { -1, 1 } do
			HolidayProps.reindeer(deer, S * CFrame.new(sx * 2.6, 0, z), false)
		end
	end
	HolidayProps.reindeer(deer, S * CFrame.new(0, 0, -44.5), true)
	HolidayProps.rod(m, "Trace", local3(0, 3.6, -6.8), local3(0, 3.6, -42.4), 0.24, rgb(170, 22, 36), Enum.Material.Leather)
	for _, z in rows do
		HolidayProps.rod(m, "Bar", local3(-2.6, 3.4, z - 0.6), local3(2.6, 3.4, z - 0.6), 0.22, rgb(170, 22, 36), Enum.Material.Leather)
	end
	for _, sx in { -1, 1 } do
		HolidayProps.rod(m, "Rein", local3(sx * 0.4, 5.6, -5.4), local3(sx * 2.6, 5.4, -15.2), 0.08, rgb(240, 214, 120), Enum.Material.Fabric)
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	-- Something to stand beside and walk round: the body's floor and sides are solid.
	for _, name in { "Floor", "Side", "Dash", "Back", "RearBack", "FrontSeat", "RearSeat" } do
		for _, d in m:GetChildren() do
			if d.Name == name and d:IsA("BasePart") then
				d.CanCollide = true
			end
		end
	end
	Kit.persist(m)
	return m
end

---------------------------------------------------------------------------------------------------
-- The North Pole
---------------------------------------------------------------------------------------------------

-- A fir for the distance: stacked rounds of dark green, snow on every tier.
local function stackFir(parent: Instance, base: Vector3, height: number)
	local tiers = 4
	for i = 0, tiers - 1 do
		local f = i / tiers
		local d = height * 0.42 * (1 - f * 0.78)
		local h = height * 0.24
		local y = base.Y + height * 0.12 + i * height * 0.2
		Kit.part(parent, "Fir", Vector3.new(h, d, d), CFrame.new(base.X, y + h / 2, base.Z) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(24, 66, 46), Enum.Material.Grass), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
		Kit.part(parent, "FirSnow", Vector3.new(h * 0.18, d * 0.86, d * 0.86), CFrame.new(base.X, y + h + 0.02, base.Z) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(226, 232, 244), Enum.Material.Snow), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
	end
	Kit.post(parent, "FirTrunk", height * 0.14, height * 0.06, base, look(rgb(70, 48, 34), Enum.Material.Wood), { shadow = false })
end

-- A lamp post striped like a candy cane, a lantern on its crook.
local function caneLamp(parent: Instance, base: Vector3, facing: Vector3, lit: boolean)
	HolidayProps.candyCane(parent, base, 10, facing)
	local dir = Vector3.new(facing.X, 0, facing.Z)
	dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.new(1, 0, 0)
	local hang = base + dir * 2.6 + Vector3.new(0, 7.4, 0)
	local glass = Kit.part(parent, "Lantern", Vector3.new(0.9, 1.3, 0.9), CFrame.new(hang), L.glassWarm, TRIM)
	Kit.part(parent, "LanternCap", Vector3.new(1.1, 0.3, 1.1), CFrame.new(hang + Vector3.new(0, 0.8, 0)), L.blackLacquer, TRIM)
	if lit then
		Kit.pointLight(glass, 1.6, 26, rgb(255, 200, 140))
	end
end

-- Santa's Workshop: red planks and white timbers, a steep snowy roof, its doors open on a warm
-- room full of toys, a wreath, its name over the door, a chimney.
local function workshop(parent: Instance, centre: Vector3)
	local m = Kit.model(parent, "Workshop")
	local red = look(rgb(150, 28, 34), Enum.Material.WoodPlanks)
	local white = look(rgb(240, 236, 228), Enum.Material.WoodPlanks)
	local snow = look(rgb(228, 234, 246), Enum.Material.Snow)
	local hw, hd, wall = 34, 18, 20
	local function box(name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, lk: Look, opts: { [string]: any }?): Part
		return Kit.span(m, name, centre + Vector3.new(x0, y0, z0), centre + Vector3.new(x1, y1, z1), lk, opts)
	end
	box("Back", -hw, 0, hd - 1, hw, wall, hd, red)
	box("West", -hw, 0, -hd, -hw + 1, wall, hd, red)
	box("East", hw - 1, 0, -hd, hw, wall, hd, red)
	box("FrontW", -hw, 0, -hd, -7, wall, -hd + 1, red)
	box("FrontE", 7, 0, -hd, hw, wall, -hd + 1, red)
	box("OverDoor", -7, 15, -hd, 7, wall, -hd + 1, red)
	box("Floor", -hw, -0.4, -hd, hw, 0.2, hd, look(rgb(140, 100, 64), Enum.Material.WoodPlanks))
	box("Ceiling", -hw, wall - 0.4, -hd, hw, wall, hd, look(rgb(120, 80, 50), Enum.Material.WoodPlanks))
	-- The white timbers: posts and beams across the front.
	for x = -hw, hw, 8.5 do
		box("Timber", x - 0.5, 0, -hd - 0.35, x + 0.5, wall, -hd + 0.1, white, TRIM)
	end
	for _, y in { 0.6, 10, wall - 0.4 } do
		box("Beam", -hw, y - 0.45, -hd - 0.4, hw, y + 0.45, -hd + 0.1, white, TRIM)
	end
	-- Windows, lit.
	for _, x in { -26, -17, 17, 26 } do
		box("Window", x - 2.4, 4, -hd - 0.3, x + 2.4, 8.4, -hd + 0.2, look(rgb(255, 196, 120), Enum.Material.Neon, 0, 0.25), TRIM)
		box("Mullion", x - 0.12, 4, -hd - 0.45, x + 0.12, 8.4, -hd - 0.25, white, TRIM)
		box("WindowBox", x - 2.8, 3.4, -hd - 1.2, x + 2.8, 4.1, -hd - 0.2, white, TRIM)
		box("Snow", x - 2.8, 4.1, -hd - 1.2, x + 2.8, 4.4, -hd - 0.3, snow, TRIM)
	end
	-- The doors, open, a wreath above, the sign.
	for _, sx in { -1, 1 } do
		box("Door", sx * 7.2, 0, -hd - 7.2, sx * 7.8, 15, -hd, look(rgb(30, 90, 56), Enum.Material.WoodPlanks))
	end
	local wreath = centre + Vector3.new(0, 17.4, -hd - 0.6)
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2
		HolidayProps.ball(m, "Wreath", 0.9, wreath + Vector3.new(math.cos(a) * 1.6, math.sin(a) * 1.6, 0), rgb(30, 100, 54), Enum.Material.Grass)
	end
	HolidayProps.ball(m, "Berry", 0.5, wreath + Vector3.new(0, -1.6, -0.3), rgb(210, 30, 40), Enum.Material.SmoothPlastic)
	local board = Kit.part(m, "Sign", Vector3.new(16, 2.6, 0.4), CFrame.new(centre + Vector3.new(0, 21.4, -hd - 0.6)), look(rgb(150, 20, 30), Enum.Material.SmoothPlastic, 0.1), { collide = false })
	Kit.engrave(board, Enum.NormalId.Front, {
		{ text = "SANTA'S WORKSHOP", size = 0.62, font = Brand.Fonts.display, color = rgb(255, 222, 140) },
		{ text = "North Pole", size = 0.26, font = Brand.Fonts.displayItalic, color = rgb(250, 244, 230) },
	}, { ppu = 60, lit = false, brightness = 1.6, maxDistance = 260 })
	-- Inside: a warm room, shelves of gifts.
	box("InsideWall", -hw + 1, 0, hd - 1.4, hw - 1, wall - 0.4, hd - 1, look(rgb(230, 190, 140), Enum.Material.Plaster), TRIM)
	local lamp = Kit.part(m, "InsideLamp", Vector3.new(1, 1, 1), CFrame.new(centre + Vector3.new(0, 15, 0)), look(rgb(255, 214, 160), Enum.Material.Neon), TRIM)
	Kit.pointLight(lamp, 2.6, 40, rgb(255, 200, 140))
	for k = 1, 6 do
		local w = HolidayProps.WRAPS[(k % #HolidayProps.WRAPS) + 1]
		HolidayProps.gift(m, CFrame.new(centre + Vector3.new(-8 + k * 2.6, 0.2, hd - 4)) * CFrame.Angles(0, k, 0), Vector3.new(2, 1.8, 2), w[1], w[2])
	end
	-- The roof: steep, snowed on, a chimney at one end.
	local rise = 16
	for _, front in { true, false } do
		local w = Instance.new("WedgePart")
		w.Name = "Roof"
		w.Anchored = true
		w.Size = Vector3.new(2 * hw + 4, rise, hd + 2.5)
		-- (Tall at its back: the front slope rises toward the ridge; the back one turned round.)
		w.CFrame = CFrame.new(centre + Vector3.new(0, wall + rise / 2, (if front then -1 else 1) * (hd + 2.5) / 2)) * (if front then CFrame.identity else CFrame.Angles(0, math.pi, 0))
		w.Color = rgb(90, 40, 36)
		w.Material = Enum.Material.Slate
		w.Parent = m
		local s = w:Clone()
		s.Name = "RoofSnow"
		s.Size = w.Size + Vector3.new(0.4, 0, 0)
		s.CFrame = w.CFrame * CFrame.new(0, 0.5, -0.25)
		s.Color = snow.color
		s.Material = snow.material
		s.CanCollide = false
		s.Parent = m
	end
	for _, sx in { -1, 1 } do
		for _, half in { -1, 1 } do
			local g = Instance.new("WedgePart")
			g.Name = "Gable"
			g.Anchored = true
			g.Size = Vector3.new(1, rise - 0.6, hd)
			g.CFrame = CFrame.new(centre + Vector3.new(sx * (hw - 0.5), wall + (rise - 0.6) / 2, half * hd / 2)) * (if half < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0))
			g.Color = red.color
			g.Material = red.material
			g.Parent = m
		end
	end
	box("Chimney", hw - 12, wall, 4, hw - 7, wall + rise + 6, 9, look(rgb(120, 60, 50), Enum.Material.Brick))
	box("ChimneySnow", hw - 12.3, wall + rise + 6, 3.7, hw - 6.7, wall + rise + 6.6, 9.3, snow, TRIM)
	local smoke = box("Smoke", hw - 10, wall + rise + 6.6, 6, hw - 9, wall + rise + 7, 7, look(Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 0, 1), TRIM)
	smoke:SetAttribute("Smoke", true)
	-- Candy-cane columns at the door, lanterns, light on the snow.
	for _, sx in { -1, 1 } do
		HolidayProps.candyCane(m, centre + Vector3.new(sx * 10, 0, -hd - 2), 15, Vector3.new(-sx, 0, 0))
	end
	local over = Kit.part(m, "DoorLamp", Vector3.new(1.2, 0.8, 1.2), CFrame.new(centre + Vector3.new(0, 16, -hd - 1.6)), L.blackLacquer, TRIM)
	Kit.spotLight(over, Enum.NormalId.Bottom, 3, 40, 90, rgb(255, 210, 160), false)
	return m
end

-- An elves' cottage: gingerbread walls, an iced roof, gumdrops, a round lit window.
local function cottage(parent: Instance, base: Vector3, facing: Vector3)
	local m = Kit.model(parent, "Cottage")
	local f = CFrame.lookAt(base, base + facing)
	local bread = look(rgb(150, 92, 50), Enum.Material.Plaster)
	local icing = look(rgb(250, 248, 244), Enum.Material.SmoothPlastic)
	Kit.part(m, "Walls", Vector3.new(14, 10, 12), f * CFrame.new(0, 5, 0), bread)
	for _, sx in { -1, 1 } do
		local w = Instance.new("WedgePart")
		w.Name = "Roof"
		w.Anchored = true
		w.Size = Vector3.new(13.2, 7, 8)
		w.CFrame = f * CFrame.new(sx * 3.9, 13.5, 0) * CFrame.Angles(0, sx * math.pi / 2, 0)
		w.Color = icing.color
		w.Material = Enum.Material.Snow
		w.Parent = m
	end
	Kit.part(m, "Door", Vector3.new(3.4, 6, 0.3), f * CFrame.new(0, 3, -6.1), look(rgb(200, 30, 40), Enum.Material.SmoothPlastic), TRIM)
	local win = Kit.part(m, "Window", Vector3.new(0.3, 3, 3), f * CFrame.new(4, 6, -6.1) * CFrame.Angles(0, math.pi / 2, 0), look(rgb(255, 200, 130), Enum.Material.Neon, 0, 0.2), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
	Kit.pointLight(win, 1.2, 16, rgb(255, 190, 120))
	Kit.part(m, "Icing", Vector3.new(14.4, 0.5, 0.5), f * CFrame.new(0, 10, -6.1), icing, TRIM)
	local drops = { rgb(240, 60, 70), rgb(90, 200, 90), rgb(255, 200, 60), rgb(120, 140, 255) }
	for k = -3, 3 do
		HolidayProps.ball(m, "Gumdrop", 0.9, (f * CFrame.new(k * 1.8, 10.5, -6.3)).Position, drops[(k + 4) % #drops + 1], Enum.Material.Glass)
	end
	HolidayProps.candyCane(m, (f * CFrame.new(-3, 0, -7.2)).Position, 6, -facing)
end

local function buildPole(): Model
	local O = HolidayGames.origin("pole")
	local P = HolidayGames.Pole
	local rng = Random.new(2512)
	local root = Instance.new("Model")
	root.Name = "NorthPole"
	root:SetAttribute("Area", "pole")
	local function at(x: number, y: number, z: number): Vector3
		return O + Vector3.new(x, y, z)
	end
	local snow = look(rgb(214, 222, 238), Enum.Material.Snow)
	Kit.span(root, "Snowfield", at(-520, -2, -520), at(520, 0, 520), snow)
	-- The plaza of packed snow, and the pad where the sleigh lands, ringed with lamps.
	Kit.part(root, "Plaza", Vector3.new(0.3, 70, 70), CFrame.new(at(0, 0.05, 0)) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(196, 204, 222), Enum.Material.Snow), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
	Kit.part(root, "Pad", Vector3.new(0.3, 50, 50), CFrame.new(at(P.pad.X, 0.06, P.pad.Z)) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(186, 194, 214), Enum.Material.Snow), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + math.pi / 8
		local p = at(P.pad.X + math.cos(a) * 26, 0, P.pad.Z + math.sin(a) * 26)
		caneLamp(root, p, Vector3.new(-math.cos(a), 0, -math.sin(a)), k % 2 == 0)
	end
	local padSign = Kit.part(root, "PadSign", Vector3.new(10, 2.2, 0.4), CFrame.lookAt(at(P.pad.X - 30, 4.2, P.pad.Z + 6), at(P.pad.X, 4.2, P.pad.Z + 6)), look(rgb(150, 20, 30), Enum.Material.SmoothPlastic), { collide = false })
	Kit.engrave(padSign, Enum.NormalId.Front, { { text = "LOAD YOUR GIFTS HERE", size = 0.6, font = Brand.Fonts.heavy, color = rgb(255, 230, 160) } }, { ppu = 60, lit = false, brightness = 1.5 })
	-- Santa's Workshop, the great tree, the cottages, a frozen pond.
	workshop(root, at(P.workshop.X, 0, P.workshop.Z))
	HolidayProps.fir(root, at(P.tree.X, 0, P.tree.Z), 58, true)
	root:SetAttribute("Tree", at(P.tree.X, 0, P.tree.Z))
	for _, c in { { -112, 64 }, { 112, 64 }, { -134, -46 }, { 134, -46 } } do
		cottage(root, at(c[1], 0, c[2]), Vector3.new(-c[1], 0, -c[2]))
	end
	Kit.part(root, "Pond", Vector3.new(0.4, 54, 54), CFrame.new(at(96, 0.1, 150)) * CFrame.Angles(0, 0, math.pi / 2), look(rgb(170, 206, 236), Enum.Material.Ice, 0.3), { shape = Enum.PartType.Cylinder, collide = false, shadow = false })
	-- Snowmen about the place.
	for _, s in { { 40, -20 }, { -40, -60 }, { 70, 50 }, { -150, 140 } } do
		HolidayProps.snowman(root, at(s[1], 0, s[2]), 7, Vector3.new(-s[1], 0, -s[2]))
	end
	-- Firs all round, and the mountains beyond.
	for k = 1, 30 do
		local a = k / 30 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local r = rng:NextNumber(212, 250)
		stackFir(root, at(math.cos(a) * r, 0, math.sin(a) * r), rng:NextNumber(26, 44))
	end
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2 + 0.3
		local r = rng:NextNumber(650, 820)
		local base = at(math.cos(a) * r, -10, math.sin(a) * r)
		local height = rng:NextNumber(280, 460)
		local d = height * 1.4
		for i = 0, 5 do
			local f = i / 6
			local h = height / 6
			local snowy = i >= 3
			Kit.part(root, "Mountain", Vector3.new(h + 1, d * (1 - f * 0.92), d * (1 - f * 0.92)), CFrame.new(base + Vector3.new(0, h * (i + 0.5), 0)) * CFrame.Angles(0, 0, math.pi / 2), if snowy then look(rgb(220, 228, 242), Enum.Material.Snow) else look(rgb(84, 92, 110), Enum.Material.Rock), { shape = Enum.PartType.Cylinder, collide = false, shadow = false, query = false })
		end
	end
	-- Elves at the workshop doors (they wave the guests in).
	for _, sx in { -1, 1 } do
		local home = CFrame.lookAt(at(P.workshop.X + sx * 13, 0, P.workshop.Z - 24), at(P.workshop.X + sx * 13, 0, P.workshop.Z - 60))
		task.spawn(function()
			local spec: Rig.LookSpec = { shirt = 0, pants = 0, accessories = "", skin = if sx < 0 then rgb(240, 200, 170) else rgb(160, 110, 80), coat = rgb(30, 120, 60), gloves = rgb(200, 30, 40), heightScale = 0.75, lapelKey = false, tails = false }
			local ok, staff = pcall(Rig.build, "Elf", spec, home, root)
			if ok and staff then
				staff.root.Anchored = true
				pcall(Dress.elf, staff.model)
			end
		end)
	end
	-- The edges.
	local barrier = look(Color3.new(0, 0, 0), Enum.Material.SmoothPlastic, 0, 1)
	local H = P.half
	for _, e in { { -H - 1, -H, -H, H }, { H, -H, H + 1, H }, { -H, -H - 1, H, -H }, { -H, H, H, H + 1 } } do
		Kit.span(root, "Edge", at(e[1], -2, e[2]), at(e[3], 60, e[4]), barrier, { shadow = false, query = false })
	end
	Kit.persist(root)
	return root
end

---------------------------------------------------------------------------------------------------
-- Gifts in the snow
---------------------------------------------------------------------------------------------------
local AVOID = {
	{ at = Vector3.new(0, 0, 104), r = 44 }, -- the workshop
	{ at = Vector3.new(-72, 0, 12), r = 18 }, -- the tree
	{ at = Vector3.new(0, 0, -96), r = 30 }, -- the pad
	{ at = Vector3.new(96, 0, 150), r = 30 }, -- the pond
	{ at = Vector3.new(-112, 0, 64), r = 12 },
	{ at = Vector3.new(112, 0, 64), r = 12 },
	{ at = Vector3.new(-134, 0, -46), r = 12 },
	{ at = Vector3.new(134, 0, -46), r = 12 },
}

local function giftSpot(ctx: Types.Ctx): Vector3
	local P = HolidayGames.Pole
	for _ = 1, 30 do
		local a = ctx.rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(ctx.rng:NextNumber(P.giftsFrom ^ 2, P.giftsTo ^ 2))
		local p = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = true
		for _, z in AVOID do
			if (Vector3.new(p.X - z.at.X, 0, p.Z - z.at.Z)).Magnitude < z.r then
				ok = false
				break
			end
		end
		if ok then
			return p
		end
	end
	return Vector3.new(ctx.rng:NextNumber(-60, 60), 0, ctx.rng:NextNumber(-40, 40))
end

local function spawnGift(ctx: Types.Ctx)
	local f = giftFolder
	if not f or not f.Parent then
		return
	end
	nextGift += 1
	local spot = HolidayGames.origin("pole") + giftSpot(ctx)
	local p = Instance.new("Part")
	p.Name = "Gift"
	p.Size = Vector3.new(2.4, 2.4, 2.4)
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(spot + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, ctx.rng:NextNumber(0, math.pi * 2), 0)
	p:SetAttribute("Id", nextGift)
	p:SetAttribute("Wrap", ctx.rng:NextInteger(1, #HolidayProps.WRAPS))
	p:SetAttribute("Size", ctx.rng:NextInteger(1, 3))
	p.Parent = f
	table.insert(gifts, { id = nextGift, part = p })
end

local function setCarrying(player: Player, n: number)
	if n > 0 then
		carrying[player] = n
		player:SetAttribute("GiftsCarried", n)
	else
		carrying[player] = nil
		player:SetAttribute("GiftsCarried", nil)
	end
end

---------------------------------------------------------------------------------------------------
-- Seats and riders
---------------------------------------------------------------------------------------------------
local function seatOf(player: Player): number?
	for i, s in seats do
		if s.player == player then
			return i
		end
	end
	return nil
end

local function release(i: number)
	local s = seats[i]
	if not s then
		return
	end
	seats[i] = nil
	local weld = s.seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	s.seat:Destroy()
end

local function sit(ctx: Types.Ctx, player: Player, i: number): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local m = sleigh
	if not humanoid or not m then
		return false
	end
	local seat = Instance.new("Seat")
	seat.Name = "SleighSeat"
	seat.Size = Vector3.new(1.8, 0.2, 1.8)
	seat.CFrame = frame() * Pole.SEATS[i]
	seat.Anchored = true
	seat.CanCollide = false
	seat.CanTouch = false
	seat.CanQuery = false
	seat.Transparency = 1
	seat:SetAttribute("UserId", player.UserId)
	seat.Parent = m
	seats[i] = { player = player, seat = seat }
	ctx.moved(player)
	seat:Sit(humanoid)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == nil then
			task.defer(function()
				local s = seats[i]
				if s and s.seat == seat and riders[player] == nil then
					release(i)
					-- Everyone got off before it left: it waits at the kerb again.
					if state == "boarding" and next(seats) == nil then
						setState(ctx, "home")
					end
				end
			end)
		end
	end)
	return true
end

-- A copy of a rider, sitting where they sit, to fly in the sleigh on every screen.
local function passenger(player: Player, seatIndex: number): Model?
	local character = player.Character
	local m = sleigh
	if not character or not m then
		return nil
	end
	local ok, copy = pcall(function()
		character.Archivable = true
		local c = character:Clone()
		character.Archivable = false
		return c
	end)
	if not ok or not copy then
		return nil
	end
	local clone = copy :: Model
	for _, d in clone:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ForceField") or d:IsA("ProximityPrompt") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			-- (Anchored before it's placed, so it keeps the pose it was copied in: sitting.)
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	clone.Name = "Passenger"
	clone:SetAttribute("UserId", player.UserId)
	local root = clone:FindFirstChild("HumanoidRootPart")
	local seated = character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and not (seated and seated.SeatPart) then
		-- (Not in the seat just now: stood in its place.)
		clone:PivotTo(frame() * Pole.SEATS[seatIndex] * CFrame.new(0, 2.2, 0))
	end
	clone.Parent = m
	return clone
end

local function clearPassengers()
	local m = sleigh
	if not m then
		return
	end
	for _, d in m:GetChildren() do
		if d.Name == "Passenger" then
			d:Destroy()
		end
	end
end

-- Where a rider waits while the sleigh is in the air: high over where it's going, out of sight.
local function hold(ctx: Types.Ctx, player: Player, over: CFrame, k: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root or not root:IsA("BasePart") then
		return
	end
	ctx.moved(player)
	character:PivotTo(over * CFrame.new(k * 3, 320, 0))
	root.Anchored = true
end

local function landAt(ctx: Types.Ctx, player: Player, cf: CFrame)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	ctx.teleport(player, cf)
	if root and root:IsA("BasePart") then
		root.Anchored = false
	end
	player:SetAttribute("SleighRide", nil)
end

-- Takes off with everyone aboard (and, at the Pole, everyone there).
local function depart(ctx: Types.Ctx, toPole: boolean)
	local list: { Player } = {}
	local seatIndex: { [Player]: number } = {}
	for i = 1, #Pole.SEATS do
		local s = seats[i]
		if s and s.player.Parent == Players then
			table.insert(list, s.player)
			seatIndex[s.player] = i
		end
	end
	if not toPole then
		for _, player in Players:GetPlayers() do
			if not seatIndex[player] and ctx.inArea(player, "pole") then
				table.insert(list, player)
				seatIndex[player] = 0
			end
		end
	end
	if toPole and #list == 0 then
		setState(ctx, "home")
		return
	end
	clearPassengers()
	local over = if toPole then HolidayGames.poleSleigh() else HolidayGames.HOME_SLEIGH
	for _, player in list do
		local i = seatIndex[player]
		if i > 0 then
			passenger(player, i)
		end
		riders[player] = i
		player:SetAttribute("SleighRide", if toPole then "toPole" else "toHome")
		-- Anything still in their arms is left in the snow.
		local held = carrying[player] or 0
		if held > 0 then
			setCarrying(player, 0)
			ctx.send(player, { op = "dropped", n = held })
		end
	end
	for i in seats do
		release(i)
	end
	for k, player in list do
		hold(ctx, player, over, k)
	end
	setState(ctx, if toPole then "toPole" else "toHome")
end

-- Lands: the sleigh is where it flew to, and its riders step out beside it.
local function arrive(ctx: Types.Ctx, atPole: boolean)
	local m = sleigh
	local to = if atPole then HolidayGames.poleSleigh() else HolidayGames.HOME_SLEIGH
	if m then
		m:PivotTo(to)
	end
	clearPassengers()
	local list = {}
	for player in riders do
		if player.Parent == Players then
			table.insert(list, player)
		end
	end
	table.clear(riders)
	for k, player in list do
		-- Beside the sleigh: at the Pole on the pad; at home, on the pavement before the door.
		local spot: CFrame
		if atPole then
			-- (The sleigh faces east: its right, the plaza's side, is north.)
			local at = to * CFrame.new(7 + (k % 2) * 2.5, 0, -6 + k * 2.4)
			spot = CFrame.lookAt(at.Position, at.Position + Vector3.new(0, 0, 1))
		else
			local at = Vector3.new(-14 + k * 3, 0.1, -48)
			spot = CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
		end
		landAt(ctx, player, spot)
		player:SetAttribute("HolidayArea", if atPole then "pole" else nil)
		local data = Profiles.get(player)
		if atPole then
			loadedTrip[player] = 0
			ctx.award(player, "northPole")
			ctx.curio(player, "sleighBell", "pole:" .. os.date("!%Y"))
			if data then
				ctx.saved(data).trips += 1
			end
			ctx.send(player, { op = "arrived", place = "pole" })
		else
			loadedTrip[player] = nil
			ctx.send(player, { op = "arrived", place = "home", gifts = if data then ctx.saved(data).gifts else 0 })
		end
	end
	if atPole then
		leaveAt = os.clock() + cfgPole(ctx).stay
		gathered = false
		setState(ctx, "pole")
	else
		setState(ctx, "home")
	end
end

---------------------------------------------------------------------------------------------------
-- What guests do
---------------------------------------------------------------------------------------------------

-- A guest boards the sleigh (its prompt, or the Sleigh key): at the kerb, or at the Pole to wait
-- for home.
function Pole.board(ctx: Types.Ctx, player: Player): { [string]: any }
	if not opened or not sleigh then
		return { ok = false, why = "Santa's sleigh comes at Christmas." }
	end
	if seatOf(player) then
		return { ok = true }
	end
	if ctx.isSeated(player) then
		return { ok = false, why = "Leave your table first." }
	end
	local root = ctx.rootOf(player)
	if not root then
		return { ok = false, why = "Not just now." }
	end
	local atPole = ctx.inArea(player, "pole")
	if state == "toPole" or state == "toHome" then
		return { ok = false, why = "The sleigh is in the air. It lands in a moment." }
	end
	if state == "pole" and not atPole then
		local left = math.max(0, math.ceil(leaveAt - os.clock() + cfgPole(ctx).flight))
		return { ok = false, why = string.format("Santa's sleigh is at the North Pole: back in %d:%02d.", left // 60, left % 60) }
	end
	if (state == "home" or state == "boarding") and atPole then
		return { ok = false, why = "Not just now." }
	end
	local free: number? = nil
	for i = 1, math.min(#Pole.SEATS, cfgPole(ctx).seats) do
		if not seats[i] then
			free = i
			break
		end
	end
	if not free then
		return { ok = false, why = "The sleigh is full. It'll be back soon." }
	end
	-- From anywhere in the house: brought to the kerb first.
	local here = frame().Position
	if (root.CFrame.Position - here).Magnitude > 30 then
		if atPole then
			return { ok = false, why = "Walk over to the sleigh." }
		end
		ctx.teleport(player, CFrame.lookAt(here + Vector3.new(0, 0, 10), here))
	end
	if not sit(ctx, player, free) then
		return { ok = false, why = "Not just now." }
	end
	if state == "home" then
		leaveAt = os.clock() + cfgPole(ctx).boarding
		setState(ctx, "boarding")
	elseif state == "boarding" then
		local full = true
		for i = 1, math.min(#Pole.SEATS, cfgPole(ctx).seats) do
			if not seats[i] then
				full = false
			end
		end
		if full then
			leaveAt = math.min(leaveAt, os.clock() + 3)
			setState(ctx, "boarding")
		end
	end
	return { ok = true }
end

local function load(ctx: Types.Ctx, player: Player)
	local held = carrying[player] or 0
	local data = Profiles.get(player)
	if held <= 0 or not data then
		return
	end
	local c = cfgPole(ctx)
	local h = ctx.saved(data)
	local trip = loadedTrip[player] or 0
	local n = math.min(held, c.tripMost - trip, c.dayMost - h.loaded)
	if n <= 0 then
		if (lastFull[player] or -math.huge) + 4 < os.clock() then
			lastFull[player] = os.clock()
			ctx.send(player, { op = "full", why = if h.loaded >= c.dayMost then "That's all the gifts for today: come back tomorrow." else "That's all the sleigh can carry for you this trip." })
		end
		return
	end
	loadedTrip[player] = trip + n
	h.loaded += n
	h.gifts += n
	setCarrying(player, held - n)
	ctx.broadcast({ op = "loaded", by = player.UserId, n = n })
	ctx.send(player, { op = "gifts", carrying = held - n, loaded = trip + n, gifts = h.gifts })
	ctx.award(player, "holiday_christmas")
	if trip + n >= 10 and trip < 10 then
		ctx.award(player, "santasHelper")
		ctx.curio(player, "snowGlobe", "pole:ten:" .. os.date("!%Y"))
	end
end

-- Opens up to `n` of a guest's gifts from the North Pole (kept until opened, at the Maison).
function Pole.openGifts(ctx: Types.Ctx, player: Player, n: number): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	if ctx.inArea(player, "pole") then
		return { ok = false, why = "Open them at home: they're for the fireside." }
	end
	local h = ctx.saved(data)
	if h.gifts <= 0 then
		return { ok = false, why = "No gifts to open. Ride Santa's sleigh to the North Pole for some." }
	end
	local c = cfgPole(ctx)
	local order = { "gilt", "moreGilt", "gems", "moreGems" }
	local total = 0
	for _, k in order do
		total += math.max(0, c.odds[k] or 0)
	end
	local results = {}
	for _ = 1, math.min(n, h.gifts) do
		h.gifts -= 1
		local x = ctx.rng:NextNumber() * total
		local kind = "gilt"
		for _, k in order do
			local w = math.max(0, c.odds[k] or 0)
			if x < w then
				kind = k
				break
			end
			x -= w
		end
		local range = (c :: any)[kind] :: { number }
		local amount = ctx.rng:NextInteger(range[1], range[2])
		local gilt, gems = 0, 0
		if kind == "gems" or kind == "moreGems" then
			gems = amount
		else
			gilt = amount
		end
		-- Today's Gems all given: the rest in Gilt, at the Gem Shop's own rate, and said so.
		local left = ctx.gemsLeft(player)
		local converted = 0
		if gems > left then
			converted = (gems - left) * 40
			gems = left
		end
		local paidGilt, paidGems = ctx.reward(player, gilt + converted, gems, "A gift from the North Pole")
		table.insert(results, { kind = kind, gilt = paidGilt, gems = paidGems, converted = converted > 0 })
		if kind == "moreGems" and paidGems > 0 then
			ctx.salute("A gift from the North Pole", player.DisplayName .. " found a trove of " .. paidGems .. " Gems in a gift!", player)
		end
	end
	ctx.award(player, "holiday_christmas")
	return { ok = true, results = results, gifts = h.gifts }
end

---------------------------------------------------------------------------------------------------
-- The game
---------------------------------------------------------------------------------------------------

function Pole.open(ctx: Types.Ctx)
	if area then
		area:Destroy()
	end
	if sleigh then
		sleigh:Destroy()
	end
	local a = buildPole()
	local f = Instance.new("Folder")
	f.Name = "Gifts"
	f.Parent = a
	giftFolder = f
	a.Parent = ctx.folder()
	area = a
	local s = buildSleigh()
	s.Parent = ctx.folder()
	sleigh = s
	-- Its prompt, on the side by the seats.
	-- (Its right side: toward the house at the kerb, toward the plaza at the Pole.)
	local side = Kit.part(s, "BoardHere", Vector3.new(1, 4, 12), HolidayGames.HOME_SLEIGH * CFrame.new(4.8, 4.4, 2), look(Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 0, 1), TRIM)
	side.CanQuery = true
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Board"
	prompt.ActionText = "Board the sleigh"
	prompt.ObjectText = "Santa's Sleigh"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.Parent = side
	prompt.Triggered:Connect(function(player: Player)
		local r = Pole.board(ctx, player)
		if not r.ok and r.why then
			ctx.send(player, { op = "say", text = r.why })
		end
	end)
	boardPrompt = prompt
	-- Father Christmas at the reins.
	task.spawn(function()
		local spec: Rig.LookSpec = { shirt = 0, pants = 0, accessories = "", skin = rgb(240, 196, 170), coat = rgb(196, 24, 36), gloves = rgb(20, 18, 18), heightScale = 1.05, lapelKey = false, tails = false }
		local ok, staff = pcall(Rig.build, "Santa", spec, HolidayGames.HOME_SLEIGH * Pole.DRIVER, s)
		if ok and staff then
			pcall(Dress.santa, staff.model)
			pcall(Dress.sit, staff.model)
			staff.root.Anchored = true
			staff.model:PivotTo(frame() * Pole.DRIVER * CFrame.new(0, 1.3, 0))
			santa = staff.model
		end
	end)
	opened = true
	gifts = {}
	for _ = 1, cfgPole(ctx).gifts do
		spawnGift(ctx)
	end
	setState(ctx, "home")
end

function Pole.close(ctx: Types.Ctx)
	opened = false
	-- Anyone in the air comes down at home.
	local k = 0
	for player in riders do
		k += 1
		if player.Parent == Players then
			local at = Vector3.new(-14 + k * 3, 0.1, -48)
			landAt(ctx, player, CFrame.lookAt(at, at + Vector3.new(0, 0, 1)))
		end
	end
	table.clear(riders)
	for i in seats do
		release(i)
	end
	for player in carrying do
		if player.Parent == Players then
			player:SetAttribute("GiftsCarried", nil)
		end
	end
	table.clear(carrying)
	table.clear(loadedTrip)
	if area then
		area:Destroy()
		area = nil
	end
	if sleigh then
		sleigh:Destroy()
		sleigh = nil
	end
	santa = nil
	boardPrompt = nil
	giftFolder = nil
	gifts = {}
	for _, key in { "SleighState", "SleighT0", "SleighFlight", "SleighLeaves" } do
		Workspace:SetAttribute(key, nil)
	end
end

function Pole.step(ctx: Types.Ctx, _dt: number)
	if not opened then
		return
	end
	local c = cfgPole(ctx)
	local now = os.clock()
	-- The sleigh keeps its time.
	if state == "boarding" and now >= leaveAt then
		depart(ctx, true)
	elseif state == "toPole" and now >= stateAt + c.flight then
		arrive(ctx, true)
	elseif state == "pole" then
		if not gathered and now >= leaveAt - 1.5 then
			-- Everyone at the Pole into a seat, for the flight home.
			gathered = true
			local i = 1
			for _, player in Players:GetPlayers() do
				if ctx.inArea(player, "pole") and not seatOf(player) then
					while seats[i] and i <= #Pole.SEATS do
						i += 1
					end
					if i <= #Pole.SEATS then
						sit(ctx, player, i)
					end
				end
			end
		end
		if now >= leaveAt then
			depart(ctx, false)
		end
	elseif state == "toHome" and now >= stateAt + c.flight then
		arrive(ctx, false)
	end
	-- Gifts: picked up in the snow, loaded at the sleigh.
	if state ~= "pole" then
		return
	end
	local cargo = (frame() * Pole.CARGO).Position
	for _, player in Players:GetPlayers() do
		local root = ctx.rootOf(player)
		if not root or riders[player] ~= nil then
			continue
		end
		local p = root.CFrame.Position
		if HolidayGames.areaAt(p) ~= "pole" or not ctx.trusted(player) then
			continue
		end
		local held = carrying[player] or 0
		if held < c.carry then
			for k = #gifts, 1, -1 do
				local g = gifts[k]
				local at = g.part.CFrame.Position
				if Vector3.new(at.X - p.X, 0, at.Z - p.Z).Magnitude <= c.reach and math.abs(at.Y - p.Y) < 6 then
					table.remove(gifts, k)
					g.part:Destroy()
					held += 1
					setCarrying(player, held)
					ctx.broadcast({ op = "picked", id = g.id, by = player.UserId })
					task.delay(4, function()
						if opened then
							spawnGift(ctx)
						end
					end)
					if held >= c.carry then
						break
					end
				end
			end
		end
		if held > 0 and Vector3.new(cargo.X - p.X, 0, cargo.Z - p.Z).Magnitude <= c.loadReach then
			load(ctx, player)
		end
	end
end

function Pole.arrival(_ctx: Types.Ctx, _player: Player): CFrame?
	if not opened then
		return nil
	end
	-- To the kerb by the sleigh (the Pole is reached by sleigh alone).
	local here = HolidayGames.HOME_SLEIGH.Position
	return CFrame.lookAt(here + Vector3.new(0, 0, 10), here)
end

function Pole.leaving(_ctx: Types.Ctx, player: Player): boolean
	return riders[player] == nil
end

function Pole.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local leaves = Workspace:GetAttribute("SleighLeaves")
	return {
		sleigh = state,
		leaves = leaves,
		carrying = carrying[player] or 0,
		loaded = loadedTrip[player] or 0,
		seated = seatOf(player) ~= nil,
		carry = cfgPole(ctx).carry,
	}
end

function Pole.leave(_ctx: Types.Ctx, player: Player)
	local i = seatOf(player)
	if i then
		release(i)
	end
	if riders[player] ~= nil then
		riders[player] = nil
		player:SetAttribute("SleighRide", nil)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = false
		end
	end
	carrying[player] = nil
	loadedTrip[player] = nil
	lastFull[player] = nil
	if player.Parent == Players then
		player:SetAttribute("GiftsCarried", nil)
	end
end

-- For tests.
function Pole.status(): (State, number)
	return state, leaveAt
end
function Pole.gifts(): { Part }
	local list = {}
	for _, g in gifts do
		table.insert(list, g.part)
	end
	return list
end
function Pole.sleigh(): Model?
	return sleigh
end

function Pole.santa(): Model?
	return santa
end

return Pole

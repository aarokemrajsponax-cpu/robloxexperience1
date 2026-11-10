--!strict
-- Steal a Luxe on the server: the residence (LuxeBuild), its pieces on their plinths, its guards,
-- and every guest's run. Everything is decided here from what the server sees: where each guest
-- and each guard stands, what this module put on the plinths, and the guest's saved record.
--
--   Taking a piece   the prompt on it (or AttractionAsk "take"): only within reach, only with room
--                    in the bag, never just after a move nobody could make. It's gone from its
--                    plinth for everyone, and back (another piece of its wing) a while later.
--   The bag          each piece in it slows you a little (Config luxe.weight); Stride from the
--                    treadmills makes you faster here, and only here. Both through "SpeedTrained".
--   The guards       walk their rounds. In sight (in front of him, near enough, nothing between)
--                    a guard's suspicion fills (faster the nearer you are); full, he gives chase.
--                    Out of his sight long enough, or out of his wing, and he gives up. Within
--                    reach: caught. Everything in the bag is lost and you're shown out to the
--                    courtyard (unnoticed for a few seconds).
--   Banking          walk up to the getaway car with the bag: its whole worth (with the banker's
--                    cut) goes to your Estate, a fifth of it to your purse in Gilt, a brainrot piece
--                    is yours to keep as a brainrot, and the rarest pay a few Gems (a day's cap).
--   Upgrades         a bigger bag, quiet shoes, the banker's cut: for Gilt, at the Luxe Lounge's
--                    board. Stride: by running the treadmills in the Lounge.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Plan = require(ReplicatedStorage.Shared.Luxe)
local LuxeBuild = require(script.Parent.LuxeBuild)
local Types = require(script.Parent.Types)

local Luxe = {}

local ID = "luxe"

-- How a guard walks toward a point (set by tests; in the game, his Humanoid walks him there).
Luxe.walk = function(guard: any, target: Vector3, speed: number)
	local h = guard.humanoid
	if h then
		h.WalkSpeed = speed
		h:MoveTo(target)
	end
end

-- Whether nothing stands between two points (walls hide a guest from a guard).
Luxe.clear = function(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		return Workspace:Raycast(from, to - from, params)
	end)
	if not ok then
		return true
	end
	return hit == nil
end

-- How a guard is made (set by tests; in the game, a dressed rig the house's staff are made like).
Luxe.makeGuard = function(parent: Instance, name: string, at: CFrame): (Model, BasePart, Humanoid?)
	local ok, staff = pcall(function()
		local Rig = require(script.Parent.Parent.Staff.Rig) :: any
		local spec = Rig.look("Guard")
		spec.coat = Color3.fromRGB(18, 18, 22)
		spec.gloves = Color3.fromRGB(18, 18, 22)
		return Rig.build(name, spec, at, parent)
	end)
	if ok and staff then
		return staff.model, staff.root, staff.humanoid
	end
	-- (A plain figure when no rig can be built: the round goes on.)
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = at + Vector3.new(0, 3, 0)
	root.Color = Color3.fromRGB(18, 18, 22)
	root.Parent = m
	m.PrimaryPart = root
	m.Parent = parent
	return m, root, nil
end

type Guard = {
	id: number,
	wing: number,
	points: { Vector3 }, -- in the world
	index: number,
	model: Model,
	root: BasePart,
	humanoid: Humanoid?,
	state: string, -- "patrol", "chase", "return"
	target: Player?,
	lastSeen: number,
	suspicion: { [Player]: number },
	speed: number,
}
type Spot = { spot: Plan.Spot, top: BasePart, piece: Plan.Piece?, model: Model?, back: number }
type Run = { bag: { Plan.Piece }, from: { number }, grace: number, since: number, sent: string, sentAt: number, watched: number, chasedBy: number }

local origin = Vector3.zero
local spots: { [number]: Spot } = {}
local guards: { Guard } = {}
local runs: { [Player]: Run } = {}
local built: LuxeBuild.Built? = nil
local now = 0 -- the residence's clock (seconds, from its steps)
local rng = Random.new()

local function cfg(ctx: Types.Ctx): { [string]: any }
	return ctx.cfg(ID)
end

local function page(ctx: Types.Ctx, data: any): { [string]: any }
	local p = ctx.saved(data, ID)
	local function level(v: any, top: number): number
		return if type(v) == "number" and v == v then math.clamp(math.floor(v), 1, top) else 1
	end
	local c = cfg(ctx)
	p.bag = level(p.bag, #c.bag)
	p.quiet = level(p.quiet, #c.quiet)
	p.banker = level(p.banker, #c.banker)
	p.stride = if type(p.stride) == "number" and p.stride == p.stride then math.max(0, p.stride) else 0
	p.hauls = if type(p.hauls) == "number" then p.hauls else 0
	p.banked = if type(p.banked) == "number" then p.banked else 0
	p.best = if type(p.best) == "number" then p.best else 0
	p.caught = if type(p.caught) == "number" then p.caught else 0
	p.golden = p.golden == true
	return p
end

local function strideLevel(ctx: Types.Ctx, p: { [string]: any }): (number, number?)
	return Plan.strideLevel(p.stride, cfg(ctx).stride)
end

-- How fast a guest moves in the residence: their Stride, less the weight of the bag.
local function speedOf(ctx: Types.Ctx, p: { [string]: any }, carried: number): number
	local c = cfg(ctx)
	local level = strideLevel(ctx, p)
	local trained = 1 + (level - 1) * c.stridePerLevel
	local weight = math.max(c.slowest, 1 - carried * c.weight)
	return trained * weight
end

local function worthOf(bag: { Plan.Piece }): number
	local n = 0
	for _, piece in bag do
		n += piece.worth
	end
	return n
end

---------------------------------------------------------------------------------------------------
-- The pieces on their plinths
---------------------------------------------------------------------------------------------------
local function place(ctx: Types.Ctx, s: Spot)
	local b = built
	if not b then
		return
	end
	local piece = if s.spot.fixed then Plan.byId[s.spot.fixed] else Plan.pick(s.spot.wing, rng:NextNumber())
	s.piece = piece
	local model = LuxeBuild.piece(b.pieces, s.top, piece, s.spot.id)
	s.model = model
	local prompt = model:FindFirstChild("Take", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		local spotId = s.spot.id
		prompt.Triggered:Connect(function(player: Player)
			local r = Luxe.take(ctx, player, spotId)
			if r.ok ~= true and type(r.why) == "string" then
				ctx.notice(player, "Not that", r.why)
			end
		end)
	end
end

local function clearSpot(s: Spot, backIn: number)
	if s.model then
		s.model:Destroy()
	end
	s.model = nil
	s.piece = nil
	s.back = now + backIn
end

---------------------------------------------------------------------------------------------------
-- Telling a guest's screen
---------------------------------------------------------------------------------------------------
local function summary(ctx: Types.Ctx, player: Player, run: Run): { [string]: any }
	local data = ctx.data(player)
	local p = if data then page(ctx, data) else nil
	local bag = {}
	for _, piece in run.bag do
		table.insert(bag, { id = piece.id, name = piece.name, glyph = piece.glyph, rarity = piece.rarity, worth = piece.worth })
	end
	local at = ctx.at(player, ID)
	local wing = if at then Plan.wingAt(at) else nil
	local c = cfg(ctx)
	return {
		op = "luxe",
		bag = bag,
		capacity = if p then c.bag[p.bag] else c.bag[1],
		worth = worthOf(run.bag),
		bonus = if p then c.banker[p.banker] else 0,
		wing = if wing then Plan.Wings[wing].name else "The courtyard",
		watched = math.floor(run.watched * 20 + 0.5) / 20,
		chased = run.chasedBy > 0,
		speed = if p then math.floor(speedOf(ctx, p, #run.bag) * 100 + 0.5) / 100 else 1,
		grace = run.grace > now,
	}
end

local function push(ctx: Types.Ctx, player: Player, run: Run, force: boolean?)
	local s = summary(ctx, player, run)
	local key = string.format("%d|%d|%s|%.2f|%s|%s|%s", #s.bag, s.worth, s.wing, s.watched, tostring(s.chased), tostring(s.speed), tostring(s.grace))
	if force or key ~= run.sent or now - run.sentAt > 2 then
		run.sent = key
		run.sentAt = now
		ctx.send(player, s)
	end
end

local function resetSpeed(ctx: Types.Ctx, player: Player, run: Run)
	local data = ctx.data(player)
	if data then
		ctx.setSpeed(player, speedOf(ctx, page(ctx, data), #run.bag))
	end
end

---------------------------------------------------------------------------------------------------
-- Taking, losing and banking
---------------------------------------------------------------------------------------------------

-- A guest takes the piece on plinth `spotId`. Returns { ok, why }.
function Luxe.take(ctx: Types.Ctx, player: Player, spotId: number): { [string]: any }
	local run = runs[player]
	local s = spots[spotId]
	if not run then
		return { ok = false, why = "You're not in the residence." }
	end
	if not s or not s.piece or not s.model then
		return { ok = false, why = "Someone has been here before you." }
	end
	if not ctx.trusted(player) then
		return { ok = false, why = "Not just now." }
	end
	local root = ctx.rootOf(player)
	local top = s.top.CFrame.Position
	if not root or (root.CFrame.Position - top).Magnitude > cfg(ctx).reach then
		return { ok = false, why = "Get closer to it." }
	end
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local capacity = cfg(ctx).bag[p.bag]
	if #run.bag >= capacity then
		return { ok = false, why = string.format("Your bag is full (%d). Bank it at the car, or a bigger bag in the Luxe Lounge.", capacity) }
	end
	local piece = s.piece :: Plan.Piece
	table.insert(run.bag, piece)
	table.insert(run.from, spotId)
	clearSpot(s, if s.spot.fixed then cfg(ctx).respawn * 4 else cfg(ctx).respawn)
	resetSpeed(ctx, player, run)
	ctx.send(player, { op = "took", piece = piece.id, name = piece.name, glyph = piece.glyph, rarity = piece.rarity, worth = piece.worth })
	ctx.tally(player, "luxeTaken", 1)
	push(ctx, player, run, true)
	return { ok = true, piece = piece.id }
end

-- Everything in the bag goes back (its plinths fill again soon).
local function drop(ctx: Types.Ctx, run: Run)
	for _, spotId in run.from do
		local s = spots[spotId]
		if s and not s.piece then
			s.back = math.min(s.back, now + 8)
		end
	end
	run.bag = {}
	run.from = {}
end

local function stopChasing(player: Player)
	for _, g in guards do
		g.suspicion[player] = nil
		if g.target == player then
			g.target = nil
			g.state = "return"
		end
	end
end

-- A guard caught a guest: the bag is lost and they're shown out to the courtyard.
local function caught(ctx: Types.Ctx, player: Player, run: Run)
	local lost = worthOf(run.bag)
	local n = #run.bag
	drop(ctx, run)
	stopChasing(player)
	run.chasedBy = 0
	run.watched = 0
	run.grace = now + cfg(ctx).caughtGrace
	local data = ctx.data(player)
	if data then
		local p = page(ctx, data)
		p.caught += 1
	end
	resetSpeed(ctx, player, run)
	ctx.teleport(player, Plan.Arrival + origin)
	ctx.send(player, { op = "caught", lost = lost, n = n })
	ctx.tally(player, "luxeCaught", 1)
	push(ctx, player, run, true)
end

-- A guest walked up to the car with the bag: everything in it is banked.
local function bank(ctx: Types.Ctx, player: Player, run: Run)
	if #run.bag == 0 then
		return
	end
	local data = ctx.data(player)
	if not data then
		return
	end
	local p = page(ctx, data)
	local c = cfg(ctx)
	local bonus = c.banker[p.banker] or 0
	local base = worthOf(run.bag)
	local worth = math.floor(base * (1 + bonus) + 0.5)
	local pieces = {}
	local gems = 0
	local crown = false
	local brainrots = {}
	for _, piece in run.bag do
		table.insert(pieces, { id = piece.id, name = piece.name, glyph = piece.glyph, rarity = piece.rarity, worth = piece.worth })
		gems += piece.gems or 0
		if piece.id == "crownJewel" then
			crown = true
		end
		if piece.curio and ctx.curio(player, piece.curio, "Steal a Luxe") then
			table.insert(brainrots, piece.curio)
		end
	end
	local count = #run.bag
	run.bag = {}
	run.from = {}
	stopChasing(player)
	run.chasedBy = 0
	local gilt = ctx.estate(player, worth, "Steal a Luxe")
	local given = if gems > 0 then ctx.gems(player, gems, "Steal a Luxe", ID) else 0
	local record = worth > p.best
	p.hauls += 1
	p.banked += worth
	p.best = math.max(p.best, worth)
	resetSpeed(ctx, player, run)
	ctx.send(player, { op = "banked", worth = worth, base = base, bonus = bonus, gilt = gilt, gems = given, pieces = pieces, brainrots = brainrots, record = record })
	ctx.tally(player, "luxeHauls", 1)
	ctx.tally(player, "luxeWorth", worth)
	if crown then
		ctx.tally(player, "crownJewels", 1)
		ctx.award(player, "crownJewel")
	end
	ctx.progress(player, "luxeBank", 1)
	ctx.progress(player, "luxeWorth", worth)
	if crown then
		ctx.herald(player, { kind = "haul", title = "The Crown Jewel", line = "carried the Crown Jewel out of Steal a Luxe", glyph = "💎", worth = worth })
	elseif worth >= (tonumber(c.greatHaul) or math.huge) then
		ctx.herald(player, { kind = "haul", title = "A great haul", line = string.format("banked %d pieces from Steal a Luxe", count), glyph = "💰", worth = worth })
	end
	push(ctx, player, run, true)
end

---------------------------------------------------------------------------------------------------
-- The guards
---------------------------------------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- How far a guard sees `player` this moment (0: not at all), and how near (0 to 1).
local function sees(ctx: Types.Ctx, g: Guard, player: Player, run: Run): (boolean, number)
	if run.grace > now then
		return false, 0
	end
	local root = ctx.rootOf(player)
	if not root then
		return false, 0
	end
	local at = root.CFrame.Position
	local wing = Plan.wingAt(at - origin)
	if wing ~= g.wing then
		return false, 0
	end
	local c = cfg(ctx)
	local data = ctx.data(player)
	local quiet = if data then c.quiet[page(ctx, data).quiet] or 1 else 1
	local sharp = Plan.Wings[g.wing].sharp
	local range = c.seeRange * sharp * quiet
	local eye = g.root.CFrame.Position + Vector3.new(0, 1.5, 0)
	local to = at - eye
	local dist = flat(to).Magnitude
	if dist > range then
		return false, 0
	end
	if dist > 3 then
		local look = flat(g.root.CFrame.LookVector)
		if look.Magnitude < 1e-3 then
			return false, 0
		end
		local cos = look.Unit:Dot(flat(to).Unit)
		if cos < math.cos(math.rad(c.seeAngle)) then
			return false, 0
		end
	end
	local ignore: { Instance } = { g.model }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	if not Luxe.clear(eye, at + Vector3.new(0, 1, 0), ignore) then
		return false, 0
	end
	return true, 1 - dist / range
end

local function guardStep(ctx: Types.Ctx, g: Guard, dt: number)
	local c = cfg(ctx)
	local sharp = Plan.Wings[g.wing].sharp
	-- Who he can see, and his suspicion of each.
	for player, run in runs do
		local seen, near = sees(ctx, g, player, run)
		local s = g.suspicion[player] or 0
		if seen then
			g.lastSeen = if g.target == player then now else g.lastSeen
			s = math.min(1, s + dt / c.noticeSeconds * (1 + near))
			if s >= 1 and g.state ~= "chase" then
				g.state = "chase"
				g.target = player
				g.lastSeen = now
				ctx.send(player, { op = "spotted", wing = g.wing })
			end
		else
			s = math.max(0, s - dt * 0.6)
		end
		g.suspicion[player] = (if s > 0 then s else nil) :: any
		run.watched = math.max(run.watched or 0, s)
	end
	if g.state == "chase" then
		local target = g.target
		local run = target and runs[target]
		local root = target and ctx.rootOf(target)
		if not target or not run or not root or run.grace > now then
			g.state, g.target = "return", nil
		else
			local at = root.CFrame.Position
			local inWing = Plan.wingAt(at - origin) == g.wing
			if not inWing or now - g.lastSeen > c.chaseGiveUp then
				g.state, g.target = "return", nil
				g.suspicion[target] = 0.4
			else
				run.chasedBy += 1
				local gap = flat(at - g.root.CFrame.Position).Magnitude
				if gap <= c.catchReach and math.abs(at.Y - g.root.CFrame.Position.Y) < 7 then
					g.state, g.target = "return", nil
					caught(ctx, target, run)
				else
					Luxe.walk(g, at, math.min(c.chaseSpeed * sharp, 30))
				end
			end
		end
	end
	if g.state == "return" or g.state == "patrol" then
		local goal = g.points[g.index]
		if flat(goal - g.root.CFrame.Position).Magnitude < 2.5 then
			g.state = "patrol"
			g.index = g.index % #g.points + 1
			goal = g.points[g.index]
		end
		Luxe.walk(g, goal, c.patrolSpeed * sharp)
	end
end

---------------------------------------------------------------------------------------------------
-- The treadmills (in the Luxe Lounge, the Velvet Room): Stride
---------------------------------------------------------------------------------------------------
local stridePushed: { [Player]: number } = {}

local function onTreadmill(root: BasePart): BasePart?
	for _, belt in CollectionService:GetTagged("LuxeTreadmill") do
		if belt:IsA("BasePart") then
			local rel = belt.CFrame:PointToObjectSpace(root.CFrame.Position)
			local half = belt.Size / 2
			if math.abs(rel.X) <= half.X + 0.5 and math.abs(rel.Z) <= half.Z + 0.5 and rel.Y >= 0 and rel.Y <= 7 then
				return belt
			end
		end
	end
	return nil
end

local function trainStep(ctx: Types.Ctx, dt: number)
	local c = cfg(ctx)
	for _, player in Players:GetPlayers() do
		local root = ctx.rootOf(player)
		if not root or ctx.inside(player) ~= nil or Layout.zoneAt(root.CFrame.Position) ~= "velvet" then
			continue
		end
		local belt = onTreadmill(root)
		local data = belt and ctx.data(player)
		if not belt or not data or not ctx.trusted(player) then
			continue
		end
		local p = page(ctx, data)
		local golden = belt:GetAttribute("Golden") == true
		if golden and not p.golden then
			continue
		end
		local before = strideLevel(ctx, p)
		p.stride += dt * c.stridePerSecond * (if golden then 2 else 1)
		local level, nextAt = strideLevel(ctx, p)
		local shown = stridePushed[player] or -1
		if math.floor(p.stride) ~= shown then
			stridePushed[player] = math.floor(p.stride)
			ctx.send(player, { op = "stride", level = level, points = math.floor(p.stride), next = nextAt, from = c.stride[level], golden = golden })
		end
		if level > before then
			ctx.send(player, { op = "strideUp", level = level, faster = math.floor((level - 1) * c.stridePerLevel * 100 + 0.5) })
			ctx.tally(player, "stride", level - before)
			ctx.progress(player, "stride", level - before)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The attraction
---------------------------------------------------------------------------------------------------
function Luxe.build(ctx: Types.Ctx, parent: Instance)
	origin = AttractionList.origin(ID)
	built = LuxeBuild.build(parent, origin, function(player: Player)
		if ctx.inside(player) == ID then
			ctx.sendHome(player, ID)
		end
	end)
	local b = built :: LuxeBuild.Built
	for _, spot in Plan.Spots do
		local s: Spot = { spot = spot, top = b.tops[spot.id], piece = nil, model = nil, back = 0 }
		spots[spot.id] = s
		place(ctx, s)
	end
	for i, patrol in Plan.Patrols do
		local points = {}
		for _, p in patrol.points do
			table.insert(points, origin + p)
		end
		local start = CFrame.lookAt(points[1], points[2] or points[1] + Vector3.new(0, 0, 1))
		local model, root, humanoid = Luxe.makeGuard(b.guards, "Guard" .. i, start)
		model:SetAttribute("Wing", patrol.wing)
		-- His torch: where he looks, every screen can see.
		local head = model:FindFirstChild("Head")
		local torchOn: BasePart = if head and head:IsA("BasePart") then head else root
		local torch = Instance.new("SpotLight")
		torch.Name = "Torch"
		torch.Face = Enum.NormalId.Front
		torch.Angle = cfg(ctx).seeAngle * 2
		torch.Range = cfg(ctx).seeRange * Plan.Wings[patrol.wing].sharp
		torch.Brightness = 2
		torch.Color = Color3.fromRGB(255, 244, 214)
		torch.Shadows = false
		torch.Parent = torchOn
		table.insert(guards, {
			id = i,
			wing = patrol.wing,
			points = points,
			index = math.min(2, #points),
			model = model,
			root = root,
			humanoid = humanoid,
			state = "patrol",
			target = nil,
			lastSeen = 0,
			suspicion = {},
			speed = cfg(ctx).patrolSpeed,
		})
	end
end

function Luxe.enter(ctx: Types.Ctx, player: Player): (CFrame?, string?)
	local data = ctx.data(player)
	if not data then
		return nil, "Your ledger is still being opened."
	end
	local p = page(ctx, data)
	runs[player] = { bag = {}, from = {}, grace = now + 2, since = now, sent = "", sentAt = -math.huge, watched = 0, chasedBy = 0 }
	ctx.setSpeed(player, speedOf(ctx, p, 0))
	task.defer(function()
		local run = runs[player]
		if run then
			push(ctx, player, run, true)
		end
	end)
	ctx.tally(player, "luxeVisits", 1)
	return Plan.Arrival, nil
end

function Luxe.leave(ctx: Types.Ctx, player: Player, why: string)
	local run = runs[player]
	if run then
		local lost = worthOf(run.bag)
		drop(ctx, run)
		stopChasing(player)
		runs[player] = nil
		if lost > 0 and player.Parent and why ~= "gone" then
			ctx.send(player, { op = "lostOnLeaving", lost = lost })
		end
	end
	if why == "gone" then
		stridePushed[player] = nil
	end
end

function Luxe.step(ctx: Types.Ctx, dt: number)
	now += dt
	if not built then
		return
	end
	for _, s in spots do
		if not s.piece and now >= s.back then
			place(ctx, s)
		end
	end
	for _, run in runs do
		run.watched = 0
		run.chasedBy = 0
	end
	for _, g in guards do
		guardStep(ctx, g, dt)
	end
	for player, run in runs do
		local at = ctx.at(player, ID)
		if at and #run.bag > 0 and Plan.inBank(at) then
			bank(ctx, player, run)
		end
		if runs[player] then
			push(ctx, player, run)
		end
	end
	trainStep(ctx, dt)
end

-- The upgrades a guest can buy, and what each costs (for the Lounge's board and the HUD).
local function upgrades(ctx: Types.Ctx, p: { [string]: any }): { [string]: any }
	local c = cfg(ctx)
	local function row(kind: string, levels: { number }, prices: { number }, describe: (number) -> string)
		local at = p[kind]
		return {
			level = at,
			top = #levels,
			now = describe(at),
			nextLine = if at < #levels then describe(at + 1) else nil,
			price = if at < #levels then prices[at + 1] else nil,
		}
	end
	local level, nextAt = strideLevel(ctx, p)
	return {
		bag = row("bag", c.bag, c.bagPrice, function(l)
			return string.format("carries %d pieces", c.bag[l])
		end),
		quiet = row("quiet", c.quiet, c.quietPrice, function(l)
			return if l == 1 then "ordinary shoes" else string.format("guards see you %d%% less far", math.floor((1 - c.quiet[l]) * 100 + 0.5))
		end),
		banker = row("banker", c.banker, c.bankerPrice, function(l)
			return if l == 1 then "no cut" else string.format("+%d%% on everything banked", math.floor(c.banker[l] * 100 + 0.5))
		end),
		stride = { level = level, points = math.floor(p.stride), next = nextAt, from = c.stride[level], faster = math.floor((level - 1) * c.stridePerLevel * 100 + 0.5), top = #c.stride },
		golden = p.golden,
		goldenGems = tonumber(c.goldenGems) or 150,
		hauls = p.hauls,
		banked = p.banked,
		best = p.best,
	}
end

function Luxe.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	if not data then
		return {}
	end
	local p = page(ctx, data)
	local out: { [string]: any } = { upgrades = upgrades(ctx, p) }
	local run = runs[player]
	if run then
		out.run = summary(ctx, player, run)
	end
	return out
end

function Luxe.ask(ctx: Types.Ctx, player: Player, r: { [string]: unknown }): any
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local c = cfg(ctx)
	if r.act == "take" then
		local n = tonumber(r.n)
		if not n or n ~= math.floor(n) then
			return { ok = false, why = "Not that." }
		end
		return Luxe.take(ctx, player, n)
	elseif r.act == "upgrade" then
		local kind = r.what
		local prices = if kind == "bag" then c.bagPrice elseif kind == "quiet" then c.quietPrice elseif kind == "banker" then c.bankerPrice else nil
		if type(kind) ~= "string" or not prices then
			return { ok = false, why = "There's no such upgrade." }
		end
		local at = p[kind]
		local price = prices[at + 1]
		if not price then
			return { ok = false, why = "That's as good as it gets." }
		end
		if not ctx.spend(player, price, 0, "luxe_" .. kind) then
			return { ok = false, why = string.format("That's %s Gilt.", Fortune.format(price)) }
		end
		p[kind] = at + 1
		ctx.tally(player, "luxeUpgrades", 1)
		local run = runs[player]
		if run then
			resetSpeed(ctx, player, run)
			push(ctx, player, run, true)
		end
		return { ok = true, upgrades = upgrades(ctx, p) }
	elseif r.act == "golden" then
		if p.golden then
			return { ok = false, why = "The golden treadmill is already yours." }
		end
		local gems = tonumber(c.goldenGems) or 150
		if not ctx.spend(player, 0, gems, "luxe_golden") then
			return { ok = false, why = string.format("That's %d Gems.", gems) }
		end
		p.golden = true
		return { ok = true, upgrades = upgrades(ctx, p) }
	end
	return { ok = false, why = "That isn't something the house does." }
end

-- For tests.
Luxe.spots = spots
Luxe.guards = guards
Luxe.runs = runs
Luxe.origin = function(): Vector3
	return origin
end
Luxe.page = page
Luxe.speedOf = speedOf

return Luxe

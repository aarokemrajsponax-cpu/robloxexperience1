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
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
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

-- A haul was banked (set by the attractions: a great one brings an invitation to the Executive Suite).
Luxe.banked = function(_player: Player, _worth: number) end

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
	state: string, -- "patrol", "chase", "search", "return"
	target: Player?,
	lastSeen: number,
	suspicion: { [Player]: number },
	speed: number,
	searchAt: Vector3?, -- where to look (in the world)
	searchUntil: number,
	extra: boolean?, -- one of a lockdown's reinforcements (gone when it ends)
}
type Spot = { spot: Plan.Spot, top: BasePart, piece: Plan.Piece?, model: Model?, back: number, last: Plan.Piece? }
type Goal = { id: string, done: boolean }
type Run = {
	bag: { Plan.Piece },
	from: { number },
	grace: number,
	since: number,
	sent: string,
	sentAt: number,
	watched: number,
	chasedBy: number,
	near: { [number]: number }, -- spot -> since when the guest has stood within reach of it
	goals: { Goal },
	spotted: boolean, -- seen (by a camera or a guard) since the last time they banked
	wings: { [number]: boolean }, -- every wing they've been in this run
	exposure: { [number]: number }, -- camera -> how long it's had them in view
	quietUntil: { [number]: number }, -- camera -> it won't spot them again before this
}
type Alarm = { level: number, untilAt: number, at: Vector3? }
type Cam = { def: Plan.Camera, head: BasePart?, world: Vector3 }

local origin = Vector3.zero
local spots: { [number]: Spot } = {}
local guards: { Guard } = {}
local runs: { [Player]: Run } = {}
local built: LuxeBuild.Built? = nil
local now = 0 -- the residence's clock (seconds, from its steps)
local rng = Random.new()
local alarms: { [number]: Alarm } = {}
local cams: { Cam } = {}
local stashOpenUntil = 0
local Analytics: any = nil
pcall(function()
	Analytics = require(script.Parent.Parent.Analytics) :: any
end)
local function note(player: Player, name: string, props: { [string]: any }?)
	if Analytics and Analytics.custom then
		pcall(Analytics.custom, player, name, 1, props)
	end
end

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
	p.hands = level(p.hands, #(c.hands or { 1 }))
	if type(p.discoveries) ~= "table" then
		p.discoveries = {} -- piece id -> true: the Exclusive and Limited pieces this guest has banked
	end
	-- Plinth -> when (the wall clock) this guest may lift from it again: a piece they banked is
	-- theirs again only after its five minutes, in this server or any other (saved with the ledger,
	-- so hopping servers or a restart never hands it back sooner).
	if type(p.lifted) ~= "table" then
		p.lifted = {}
	end
	local wall = os.time()
	for k, v in p.lifted do
		if type(k) ~= "string" or type(v) ~= "number" or v <= wall then
			p.lifted[k] = nil
		end
	end
	return p
end

local function strideLevel(ctx: Types.Ctx, p: { [string]: any }): (number, number?)
	return Plan.strideLevel(p.stride, cfg(ctx).stride)
end

-- How fast a guest moves in the residence: their Stride, less the weight of the bag.
local function speedOf(ctx: Types.Ctx, p: { [string]: any }, carried: number, mass: number?): number
	local c = cfg(ctx)
	local level = strideLevel(ctx, p)
	local trained = 1 + (level - 1) * c.stridePerLevel
	local weight = math.max(c.slowest, 1 - carried * c.weight - (mass or 0) * (tonumber(c.massSlow) or 0))
	return trained * weight
end

local function massOf(bag: { Plan.Piece }): number
	local n = 0
	for _, piece in bag do
		n += piece.mass or 0
	end
	return n
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
	-- The same piece comes back to its own plinth (Build 78); a fresh one only the first time, or
	-- when a Limited piece's holiday has closed.
	local open = HolidayGames.byCalendar()
	local piece: Plan.Piece
	if s.spot.fixed then
		piece = Plan.byId[s.spot.fixed]
	elseif s.last and (s.last.limited == nil or s.last.limited == open) then
		piece = s.last
	else
		piece = Plan.pick(s.spot.wing, rng:NextNumber())
	end
	-- (While a holiday is open on the house's calendar, a Drop Room plinth may set out its Limited
	-- piece instead: only then, never sold, never made scarce for show.)
	if s.spot.wing == 4 and not s.spot.fixed and open and piece.limited == nil and rng:NextNumber() < 0.2 then
		for _, l in Plan.Pieces do
			if l.limited == open then
				piece = l
			end
		end
	end
	s.piece = piece
	s.last = piece
	s.top:SetAttribute("BackAt", nil)
	local model = LuxeBuild.piece(b.pieces, s.top, piece, s.spot.id)
	s.model = model
	local prompt = model:FindFirstChild("Take", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		-- (Its hold right up close, unhurried: each screen lengthens it with the reach, and
		-- shortens it with Quick Hands, as Plan.holdFor says.)
		prompt.HoldDuration = Plan.holdFor(piece, 0, 1, cfg(ctx).hold)
		prompt:SetAttribute("Piece", piece.id)
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
	-- (When it's back, for the screens' quiet countdown on the empty plinth.)
	local okTime, serverNow = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	s.top:SetAttribute("BackAt", (if okTime then serverNow else os.time()) + backIn)
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
	local goals = {}
	for _, g in run.goals do
		local o = Plan.objectiveOf[g.id]
		if o then
			table.insert(goals, { id = g.id, line = o.line, gilt = o.gilt, done = g.done })
		end
	end
	local alarm = if wing and alarms[wing] then alarms[wing].level else 0
	return {
		op = "luxe",
		goals = goals,
		alarm = alarm,
		wingId = wing or 0,
		mass = math.floor(massOf(run.bag) * 10 + 0.5) / 10,
		bag = bag,
		capacity = if p then c.bag[p.bag] else c.bag[1],
		worth = worthOf(run.bag),
		bonus = if p then c.banker[p.banker] else 0,
		wing = if wing then Plan.Wings[wing].name else "The courtyard",
		watched = math.floor(run.watched * 20 + 0.5) / 20,
		chased = run.chasedBy > 0,
		speed = if p then math.floor(speedOf(ctx, p, #run.bag, massOf(run.bag)) * 100 + 0.5) / 100 else 1,
		grace = run.grace > now,
		hands = if p then (c.hands or { 1 })[p.hands] or 1 else 1, -- (each screen times its prompts' holds with it)
	}
end

local function push(ctx: Types.Ctx, player: Player, run: Run, force: boolean?)
	local s = summary(ctx, player, run)
	local doneCount = 0
	for _, g in s.goals do
		if g.done then
			doneCount += 1
		end
	end
	local key = string.format("%d|%d|%s|%.2f|%s|%s|%s|%d|%d", #s.bag, s.worth, s.wing, s.watched, tostring(s.chased), tostring(s.speed), tostring(s.grace), s.alarm, doneCount)
	if force or key ~= run.sent or now - run.sentAt > 2 then
		run.sent = key
		run.sentAt = now
		ctx.send(player, s)
	end
end

local function resetSpeed(ctx: Types.Ctx, player: Player, run: Run)
	local data = ctx.data(player)
	if data then
		ctx.setSpeed(player, speedOf(ctx, page(ctx, data), #run.bag, massOf(run.bag)))
	end
end

---------------------------------------------------------------------------------------------------
-- Side jobs (a run's three objectives)
---------------------------------------------------------------------------------------------------
local function complete(ctx: Types.Ctx, player: Player, run: Run, id: string)
	for _, g in run.goals do
		if g.id == id and not g.done then
			g.done = true
			local o = Plan.objectiveOf[id]
			local paid = if o then ctx.gilt(player, o.gilt, "Steal a Luxe: " .. o.line) else 0
			ctx.send(player, { op = "objective", id = id, line = if o then o.line else id, gilt = paid })
			ctx.tally(player, "luxeObjectives", 1)
			ctx.progress(player, "luxeJob", 1)
			note(player, "Luxe objective", { objective = id })
			return
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Security: the wings' alarms
---------------------------------------------------------------------------------------------------
local raise: (ctx: Types.Ctx, wing: number, toLevel: number, at: Vector3?) -> ()

local function setAlarmAttr(wing: number)
	local b = built
	if b then
		b.root:SetAttribute("Alarm" .. wing, alarms[wing].level)
	end
end

-- A guest was seen (by a camera, or by a guard who gave chase): the wing is put on Alert, or
-- locked down if it already was; its guards come to look where they were seen.
local function spotted(ctx: Types.Ctx, player: Player, run: Run, wing: number, at: Vector3, by: string)
	run.spotted = true
	local a = alarms[wing]
	raise(ctx, wing, if a and a.level >= 1 then 2 else 1, at)
	ctx.send(player, { op = "spotted", wing = wing, by = by })
	note(player, "Luxe spotted", { wing = wing, by = by })
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
	local c = cfg(ctx)
	local distance = if root then (root.CFrame.Position - top).Magnitude else math.huge
	if not root or distance > c.reach then
		return { ok = false, why = "Get closer to it." }
	end
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local capacity = c.bag[p.bag]
	if #run.bag >= capacity then
		return { ok = false, why = string.format("Your bag is full (%d). Bank it at a way out, or a bigger bag in the Luxe Lounge.", capacity) }
	end
	local again = p.lifted[tostring(spotId)]
	if type(again) == "number" and again > os.time() then
		local left = math.max(1, again - os.time())
		return { ok = false, why = string.format("You banked this one not long ago. It's yours to lift again in %d:%02d.", left // 60, left % 60) }
	end
	local piece = s.piece :: Plan.Piece
	-- (Lifted no quicker than it can be: they've stood within reach of it for its hold, give or
	-- take the network's lag. A screen can't hurry it.)
	local hold = c.hold
	if hold then
		local need = Plan.holdFor(piece, distance, (c.hands or { 1 })[p.hands] or 1, hold) * (tonumber(hold.slack) or 0.75) - 0.1
		local since = run.near[spotId]
		if need > 0 and (since == nil or now - since < need) then
			return { ok = false, why = "Hold it a moment longer." }
		end
	end
	table.insert(run.bag, piece)
	table.insert(run.from, spotId)
	clearSpot(s, c.respawn)
	resetSpeed(ctx, player, run)
	ctx.send(player, { op = "took", piece = piece.id, name = piece.name, glyph = piece.glyph, rarity = piece.rarity, worth = piece.worth, at = top, mass = piece.mass or 0 })
	ctx.tally(player, "luxeTaken", 1)
	note(player, "Luxe taken", { piece = piece.id, rarity = piece.rarity, wing = s.spot.wing })
	local wing = s.spot.wing
	if wing == 4 then
		complete(ctx, player, run, "dropRoom")
		if s.spot.at.Y >= Plan.LOFT - 1 then
			complete(ctx, player, run, "loft")
		end
	elseif wing == 5 then
		complete(ctx, player, run, "garage")
	end
	-- The great pieces are watched: lifting a Legendary or better puts its wing on Alert, and the
	-- Crown Jewel locks the Strongroom down.
	if piece.id == "crownJewel" then
		complete(ctx, player, run, "crown")
		spotted(ctx, player, run, wing, root.CFrame.Position, "the Crown Jewel's plinth")
		raise(ctx, wing, 2, root.CFrame.Position)
	elseif (Plan.rarityOf[piece.rarity] and Plan.rarityOf[piece.rarity].order or 0) >= 5 then
		raise(ctx, wing, 1, root.CFrame.Position)
	end
	push(ctx, player, run, true)
	return { ok = true, piece = piece.id }
end

-- Everything in the bag goes back (its plinths fill again soon).
local function drop(ctx: Types.Ctx, run: Run)
	for _, spotId in run.from do
		local s = spots[spotId]
		if s and not s.piece then
			s.back = math.min(s.back, now + (tonumber(cfg(ctx).dropBack) or 20))
			local okTime, serverNow = pcall(function()
				return Workspace:GetServerTimeNow()
			end)
			s.top:SetAttribute("BackAt", (if okTime then serverNow else os.time()) + (s.back - now))
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
	run.spotted = false
	run.grace = now + cfg(ctx).caughtGrace
	local caughtAt = ctx.at(player, ID)
	note(player, "Luxe caught", { wing = if caughtAt then Plan.wingAt(caughtAt) or 0 else 0, lost = lost })
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
local function bank(ctx: Types.Ctx, player: Player, run: Run, way: Plan.Bank?)
	if #run.bag == 0 then
		return
	end
	local data = ctx.data(player)
	if not data then
		return
	end
	local p = page(ctx, data)
	local c = cfg(ctx)
	local route = way or Plan.Banks[1]
	local bonus = (c.banker[p.banker] or 0) + (route.bonus or 0)
	local base = worthOf(run.bag)
	local worth = math.floor(base * (1 + bonus) + 0.5)
	local pieces = {}
	local crown = false
	local brainrots = {}
	local finds = {}
	local bestOrder = 0
	for _, piece in run.bag do
		table.insert(pieces, { id = piece.id, name = piece.name, glyph = piece.glyph, rarity = piece.rarity, worth = piece.worth })
		if piece.id == "crownJewel" then
			crown = true
		end
		local order = if Plan.rarityOf[piece.rarity] then Plan.rarityOf[piece.rarity].order else 0
		bestOrder = math.max(bestOrder, order)
		-- An Exclusive or a Limited piece, banked for the first time: a discovery, kept for good
		-- and told to the house.
		if (piece.rarity == "Exclusive" or piece.rarity == "Limited") and not p.discoveries[piece.id] then
			p.discoveries[piece.id] = true
			table.insert(finds, piece.name)
		end
		if piece.curio and ctx.curio(player, piece.curio, "Steal a Luxe") then
			table.insert(brainrots, piece.curio)
		end
	end
	local count = #run.bag
	local unseen = not run.spotted
	local wall = os.time()
	for _, spotId in run.from do
		p.lifted[tostring(spotId)] = wall + c.respawn
	end
	run.bag = {}
	run.from = {}
	stopChasing(player)
	run.chasedBy = 0
	run.spotted = false
	local gilt = ctx.estate(player, worth, "Steal a Luxe")
	local record = worth > p.best
	p.hauls += 1
	p.banked += worth
	p.best = math.max(p.best, worth)
	resetSpeed(ctx, player, run)
	ctx.send(player, { op = "banked", worth = worth, base = base, bonus = bonus, gilt = gilt, pieces = pieces, brainrots = brainrots, record = record, route = route.id, routeName = route.name, finds = finds })
	note(player, "Luxe banked", { route = route.id, worth = worth, pieces = count })
	if route.id == "van" then
		complete(ctx, player, run, "van")
	elseif route.id == "heli" then
		complete(ctx, player, run, "heli")
	end
	if route.id ~= "car" then
		ctx.progress(player, "luxeEscape", 1)
	end
	if bestOrder >= 3 then
		complete(ctx, player, run, "bankRare")
	end
	if worth >= 6000 then
		complete(ctx, player, run, "big")
	end
	if unseen and count >= 3 then
		complete(ctx, player, run, "unseen")
	end
	-- (A first find told to the house, unless the Crown Jewel is in the same haul: it has its own.)
	if not crown then
		for _, name in finds do
			ctx.herald(player, { kind = "haul", title = "A rare find", line = "found " .. name .. " in Steal a Luxe", glyph = "✦", worth = worth })
		end
	end
	ctx.tally(player, "luxeHauls", 1)
	Luxe.banked(player, worth)
	ctx.tally(player, "luxeWorth", worth)
	if crown then
		ctx.tally(player, "crownJewels", 1)
		ctx.award(player, "crownJewel")
	end
	ctx.progress(player, "luxeBank", 1)
	ctx.progress(player, "luxeWorth", worth)
	if crown then
		ctx.herald(player, { kind = "haul", title = "The Crown Jewel", line = "carried the Crown Jewel out of Steal a Luxe", glyph = "💎", worth = worth, everywhere = true })
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
	local alarm = alarms[g.wing]
	local alert = if alarm and alarm.level >= 1 then (tonumber(c.alertSight) or 1) else 1
	local range = c.seeRange * sharp * quiet * alert
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
	local alarm = alarms[g.wing]
	local hurry = if alarm and alarm.level >= 1 then (tonumber(c.alertSpeed) or 1) else 1
	local sharp = Plan.Wings[g.wing].sharp * hurry
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
				local root = ctx.rootOf(player)
				spotted(ctx, player, run, g.wing, if root then root.CFrame.Position else g.root.CFrame.Position, "a guard")
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
				-- (Lost them: he goes to look where they were last, a while, then back to his round.)
				g.state, g.target = "search", nil
				g.searchAt = at
				g.searchUntil = 0
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
	if g.state == "search" then
		local goal = g.searchAt
		if not goal then
			g.state = "return"
		elseif g.searchUntil > 0 then
			if now >= g.searchUntil then
				g.state, g.searchAt, g.searchUntil = "return", nil, 0
			end
		elseif flat(goal - g.root.CFrame.Position).Magnitude < 3 then
			g.searchUntil = now + (tonumber(c.searchSeconds) or 4)
		else
			Luxe.walk(g, goal, c.patrolSpeed * sharp * 1.25)
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

-- A wing's alarm goes up to `toLevel` (1 Alert, 2 Lockdown), or stays where it is if it's higher;
-- its guards (not chasing anyone) come to look at `at`.
raise = function(ctx: Types.Ctx, wing: number, toLevel: number, at: Vector3?)
	local c = cfg(ctx)
	local a = alarms[wing]
	if not a then
		a = { level = 0, untilAt = 0, at = nil }
		alarms[wing] = a
	end
	local was = a.level
	if toLevel >= a.level then
		a.level = toLevel
		a.untilAt = now + (if toLevel >= 2 then (tonumber(c.lockdownFor) or 30) else (tonumber(c.alertFor) or 25))
	else
		a.untilAt = math.max(a.untilAt, now + (tonumber(c.alertFor) or 25))
	end
	a.at = at or a.at
	if at then
		for _, g in guards do
			if g.wing == wing and g.state ~= "chase" then
				g.state, g.searchAt, g.searchUntil = "search", at, 0
			end
		end
	end
	if a.level ~= was then
		setAlarmAttr(wing)
		-- A lockdown brings reinforcements to the wing's doorway, looking where the trouble was.
		if a.level >= 2 and was < 2 then
			local b = built
			local w = Plan.Wings[wing]
			for i = 1, (tonumber(c.reinforcements) or 2) do
				local door = origin + Vector3.new((w.minX + w.maxX) / 2 + (i - 1.5) * 6, 0, w.minZ + 4)
				if b then
					local model, root, humanoid = Luxe.makeGuard(b.guards, "Reinforcement" .. wing .. "_" .. i, CFrame.new(door))
					model:SetAttribute("Wing", wing)
					model:SetAttribute("Reinforcement", true)
					table.insert(guards, {
						id = 1000 + wing * 10 + i,
						wing = wing,
						points = { door, at or door },
						index = 2,
						model = model,
						root = root,
						humanoid = humanoid,
						state = "search",
						target = nil,
						lastSeen = 0,
						suspicion = {},
						speed = c.patrolSpeed,
						searchAt = at or door,
						searchUntil = 0,
						extra = true,
					})
				end
			end
		end
		for player, run in runs do
			local here = ctx.at(player, ID)
			if here and Plan.wingAt(here) == wing then
				ctx.send(player, { op = "alarm", wing = wing, level = a.level })
				push(ctx, player, run, true)
			end
		end
	end
end

-- The alarms cool: a lockdown to Alert, Alert to calm; a lockdown's reinforcements go.
local function alarmStep(ctx: Types.Ctx)
	local c = cfg(ctx)
	for wing, a in alarms do
		if a.level > 0 and now >= a.untilAt then
			local was = a.level
			a.level -= 1
			a.untilAt = now + (tonumber(c.alertFor) or 25)
			setAlarmAttr(wing)
			if was >= 2 then
				for i = #guards, 1, -1 do
					local g = guards[i]
					if g.extra and g.wing == wing and g.state ~= "chase" then
						g.model:Destroy()
						table.remove(guards, i)
					end
				end
			end
			for player, run in runs do
				local here = ctx.at(player, ID)
				if here and Plan.wingAt(here) == wing then
					ctx.send(player, { op = "alarm", wing = wing, level = a.level })
					push(ctx, player, run, true)
				end
			end
		end
	end
end

-- The cameras sweep; one that has a guest in view long enough spots them.
local function cameraStep(ctx: Types.Ctx, dt: number)
	local c = cfg(ctx)
	local range = tonumber(c.cameraRange) or 38
	local cosAngle = math.cos(math.rad(tonumber(c.cameraAngle) or 24))
	local need = tonumber(c.cameraSeconds) or 0.9
	for i, cam in cams do
		local look = Plan.cameraLook(cam.def, now)
		local head = cam.head
		if head then
			head.CFrame = CFrame.lookAt(cam.world, cam.world + look + Vector3.new(0, -0.35, 0))
		end
		for player, run in runs do
			local root = ctx.rootOf(player)
			local inView = false
			if root and run.grace <= now and (run.quietUntil[i] or 0) <= now then
				local at = root.CFrame.Position
				if Plan.wingAt(at - origin) == cam.def.wing then
					local to = at - cam.world
					local dist = to.Magnitude
					if dist <= range and dist > 0.5 then
						local flatTo = flat(to)
						if flatTo.Magnitude < 1e-3 or look:Dot(flatTo.Unit) >= cosAngle then
							local ignore: { Instance } = {}
							if player.Character then
								table.insert(ignore, player.Character)
							end
							if head then
								table.insert(ignore, head)
							end
							inView = Luxe.clear(cam.world, at, ignore)
						end
					end
				end
			end
			if inView then
				local e = (run.exposure[i] or 0) + dt
				if e >= need then
					run.exposure[i] = 0
					run.quietUntil[i] = now + 4
					local here = (root :: BasePart).CFrame.Position
					spotted(ctx, player, run, cam.def.wing, here, "a camera")
				else
					run.exposure[i] = e
				end
				run.watched = math.max(run.watched, math.min(0.95, e / need))
			else
				run.exposure[i] = nil
			end
		end
	end
end

-- The laser grid: crossing a lit beam locks the Strongroom down.
local function laserStep(ctx: Types.Ctx)
	for player, run in runs do
		local root = ctx.rootOf(player)
		if root and run.grace <= now then
			local at = root.CFrame.Position - origin
			if Plan.wingAt(at) == 3 then
				for _, l in Plan.Lasers do
					if Plan.laserOn(l, now) and math.abs(at.Z - l.z) < 0.9 and at.X >= l.minX and at.X <= l.maxX and at.Y < l.y + 3.5 then
						spotted(ctx, player, run, 3, root.CFrame.Position, "the laser grid")
						raise(ctx, 3, 2, root.CFrame.Position)
						run.grace = now + 1.5 -- (one beam, one alarm)
						break
					end
				end
			end
		end
	end
	local b = built
	if b and b.lasers then
		for i, beam in b.lasers do
			local on = Plan.laserOn(Plan.Lasers[i], now)
			beam.Transparency = if on then 0.15 else 1
		end
	end
end

-- The Secret Stash's panel: opened by the loose bar, shut again when nobody is in the doorway.
function Luxe.openStash(ctx: Types.Ctx, player: Player?): boolean
	local b = built
	if not b or not b.stashDoor then
		return false
	end
	stashOpenUntil = now + Plan.Stash.openFor
	b.stashDoor.CanCollide = false
	b.stashDoor.CanQuery = false -- (guards and cameras see through the open doorway)
	b.stashDoor.Transparency = 1
	if player then
		ctx.notice(player, "Something gave", "A panel slid open at the back of the Strongroom.")
		note(player, "Luxe stash opened", nil)
	end
	return true
end

local function stashStep(ctx: Types.Ctx)
	local b = built
	if not b or not b.stashDoor or stashOpenUntil == 0 or now < stashOpenUntil then
		return
	end
	-- (Never shut on anyone: while someone is inside or in the doorway, it waits.)
	for player in runs do
		local at = ctx.at(player, ID)
		if at and at.Z > Plan.Stash.door.z - 4 and math.abs(at.X) < 18 then
			stashOpenUntil = now + 3
			return
		end
	end
	stashOpenUntil = 0
	b.stashDoor.CanCollide = true
	b.stashDoor.CanQuery = true
	b.stashDoor.Transparency = 0
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
	for i, def in Plan.Cameras do
		table.insert(cams, { def = def, head = b.cameras and b.cameras[i] or nil, world = origin + def.at })
	end
	for wing = 1, #Plan.Wings do
		alarms[wing] = { level = 0, untilAt = 0, at = nil }
		setAlarmAttr(wing)
	end
	if b.stashLever then
		b.stashLever.Triggered:Connect(function(player: Player)
			if runs[player] then
				Luxe.openStash(ctx, player)
			end
		end)
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
			searchAt = nil,
			searchUntil = 0,
			extra = false,
		})
	end
end

function Luxe.enter(ctx: Types.Ctx, player: Player): (CFrame?, string?)
	local data = ctx.data(player)
	if not data then
		return nil, "Your ledger is still being opened."
	end
	local p = page(ctx, data)
	-- Three side jobs for this run, at random.
	local pool = table.clone(Plan.Objectives)
	local goals: { Goal } = {}
	for _ = 1, math.min(tonumber(cfg(ctx).objectives) or 3, #pool) do
		local o = table.remove(pool, rng:NextInteger(1, #pool)) :: Plan.Objective
		table.insert(goals, { id = o.id, done = false })
	end
	runs[player] = { bag = {}, from = {}, grace = now + 2, since = now, sent = "", sentAt = -math.huge, watched = 0, chasedBy = 0, near = {}, goals = goals, spotted = false, wings = {}, exposure = {}, quietUntil = {} }
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
		local here = ctx.at(player, ID)
		local n = 0
		for _ in run.wings do
			n += 1
		end
		note(player, "Luxe left", { why = why, wing = if here then Plan.wingAt(here) or 0 else 0, wings = n, carrying = lost })
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
	local reach = cfg(ctx).reach
	for player, run in runs do
		run.watched = 0
		run.chasedBy = 0
		-- How long they've stood within reach of each piece (a lift is held that long).
		local root = ctx.rootOf(player)
		local here = if root then root.CFrame.Position else nil
		for id, s in spots do
			if here and s.piece and (here - s.top.CFrame.Position).Magnitude <= reach then
				run.near[id] = run.near[id] or now
			else
				run.near[id] = nil
			end
		end
		local at = ctx.at(player, ID)
		local wing = if at then Plan.wingAt(at) else nil
		if wing and not run.wings[wing] then
			run.wings[wing] = true
			note(player, "Luxe wing", { wing = wing })
		end
		if wing == 6 then
			complete(ctx, player, run, "stash")
		end
	end
	for _, g in guards do
		guardStep(ctx, g, dt)
	end
	cameraStep(ctx, dt)
	laserStep(ctx)
	alarmStep(ctx)
	stashStep(ctx)
	for player, run in runs do
		local at = ctx.at(player, ID)
		local way = if at and #run.bag > 0 then Plan.bankAt(at) else nil
		if way then
			bank(ctx, player, run, way)
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
		hands = row("hands", c.hands or { 1 }, c.handsPrice or { 0 }, function(l)
			return if l == 1 then "ordinary hands" else string.format("lift %d%% quicker", math.floor((1 - (c.hands or { 1 })[l]) * 100 + 0.5))
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

-- Its card in the Maison Directory: always open; the guest's hauls, their best and their Stride.
function Luxe.directory(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	if not data then
		return { open = true }
	end
	local p = page(ctx, data)
	local level = strideLevel(ctx, p)
	local finds = 0
	for _ in p.discoveries do
		finds += 1
	end
	return { open = true, hauls = p.hauls, best = p.best, banked = p.banked, stride = level, finds = finds }
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
		local prices = if kind == "bag" then c.bagPrice elseif kind == "quiet" then c.quietPrice elseif kind == "banker" then c.bankerPrice elseif kind == "hands" then c.handsPrice else nil
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
Luxe.alarms = alarms
Luxe.cams = cams
Luxe.raise = function(ctx: Types.Ctx, wing: number, level: number, at: Vector3?)
	raise(ctx, wing, level, at)
end
Luxe.now = function(): number
	return now
end

return Luxe

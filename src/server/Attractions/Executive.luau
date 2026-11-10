--!strict
-- The Executive Suite on the server: invitations, the Quartermaster's gear, and the run (shared by
-- everyone up there at once). Everything is judged here: where the server sees each guest, where
-- its own cameras, guards and the Executive look and stand, and what each shot hits (a ray from the
-- guest's own head, never a hit a screen claims).
--
--   Invitations   one is spent going up. Earned: the Maison Basement cleared (one), a haul of
--                 Config executive.inviteHaul or more banked in Steal a Luxe (one); bought for
--                 Gilt at the Quartermaster's desk; or given by the owner. A guest holds a few at
--                 most. No chance, no Robux.
--   Gear          the sidearm, free, taken before going up (no sidearm, no lift). The rest, for
--                 Gilt, is packed for the next run and works only in the Suite.
--   The hallway   seen by a camera or a guard, the alert rises (slower in a disguise; nobody looks
--                 at anyone while a decoy is out); full, security shows you out. Four terminals:
--                 a digit of the door's code each, to whoever reads it.
--   The door      its code, made new each run, at the keypad; three wrong tries, and the alert
--                 jumps. Right, it opens for everyone up there.
--   The Office    the Executive's three phases (shared/Executive.Phases). His briefcases and the
--                 bodyguards' fists take composure; none left, and you're escorted out. Beaten:
--                 everyone in the Office is paid (the Estate, Gems within the day's cap, his brainrot
--                 the first time), the safe opens (once each) and the lift down.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local Plan = require(ReplicatedStorage.Shared.Executive)
local RemoteGuard = require(script.Parent.Parent.RemoteGuard)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ExecutiveBuild = require(script.Parent.ExecutiveBuild)
local Types = require(script.Parent.Types)

local Executive = {}

local ID = "executive"

-- The server's clock (set by tests).
Executive.clock = function(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end
-- What a shot hits: the ExecTarget of the first thing in its way, or nil (set by tests).
Executive.ray = function(from: Vector3, toward: Vector3, ignore: { Instance }): string?
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		return Workspace:Raycast(from, toward, params)
	end)
	if not ok or not hit then
		return nil
	end
	local part: Instance? = (hit :: RaycastResult).Instance
	while part and part ~= Workspace do
		local tag = part:GetAttribute("ExecTarget")
		if type(tag) == "string" then
			return tag
		end
		part = part.Parent
	end
	return nil
end
-- Whether nothing stands between two points (set by tests).
Executive.clear = function(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	local ok, hit = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		return Workspace:Raycast(from, to - from, params)
	end)
	return not ok or hit == nil
end
-- How a guard or the Executive walks (set by tests).
Executive.walk = function(actor: any, target: Vector3, speed: number)
	local h = actor.humanoid
	if h then
		h.WalkSpeed = speed
		h:MoveTo(target)
	end
end
-- How a figure is made (set by tests).
Executive.makeFigure = function(parent: Instance, name: string, at: CFrame, kind: string): (Model, BasePart, Humanoid?)
	local ok, staff = pcall(function()
		local Rig = require(script.Parent.Parent.Staff.Rig) :: any
		local spec = Rig.look(if kind == "boss" then "Concierge" else "Guard")
		spec.coat = if kind == "boss" then Color3.fromRGB(20, 22, 40) else Color3.fromRGB(14, 14, 16)
		return Rig.build(name, spec, at, parent)
	end)
	if ok and staff then
		return staff.model, staff.root, staff.humanoid
	end
	local m = Instance.new("Model")
	m.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = if kind == "boss" then Vector3.new(3, 4, 2) else Vector3.new(2, 3, 1)
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = at + Vector3.new(0, 3, 0)
	root.Color = if kind == "boss" then Color3.fromRGB(20, 22, 40) else Color3.fromRGB(14, 14, 16)
	root.Parent = m
	m.PrimaryPart = root
	m.Parent = parent
	return m, root, nil
end

type Actor = { id: string, kind: string, model: Model, root: BasePart, humanoid: Humanoid?, hp: number, max: number, index: number, lastHit: number, points: { Vector3 }? }
type Guest = {
	alert: number,
	composure: number,
	max: number,
	gear: { [string]: boolean },
	decoyUsed: boolean,
	digits: { [number]: boolean },
	tries: number,
	lastShot: number,
	paid: boolean,
	safe: boolean,
	hits: { [string]: boolean },
	out: boolean,
}
type Shot = { id: string, from: Vector3, dir: Vector3, speed: number, born: number, radius: number, damage: number, life: number }
type Wave = { id: string, at: Vector3, born: number, speed: number, width: number, damage: number, life: number }

local origin = Vector3.zero
local built: ExecutiveBuild.Built? = nil
local guests: { [Player]: Guest } = {}
local run = {
	code = "0000",
	open = false,
	phase = "hall" :: string, -- "hall", "shield", "detail", "boss", "won"
	generators = {} :: { [string]: number },
	actors = {} :: { [string]: Actor },
	shots = {} :: { Shot },
	waves = {} :: { Wave },
	nextAttack = 0,
	attackIndex = 0,
	decoyUntil = -math.huge,
	decoyAt = Vector3.zero,
	wonAt = 0,
	serial = 0,
	hallGuards = {} :: { Actor },
}
local rng = Random.new()

local function cfg(ctx: Types.Ctx): { [string]: any }
	return ctx.cfg(ID)
end

local function page(ctx: Types.Ctx, data: any): { [string]: any }
	local p = ctx.saved(data, ID)
	p.invites = if type(p.invites) == "number" then math.max(0, math.floor(p.invites)) else 0
	p.sidearm = p.sidearm == true
	p.kit = if type(p.kit) == "table" then p.kit else {}
	p.wins = if type(p.wins) == "number" then p.wins else 0
	p.firstWin = p.firstWin == true
	return p
end

local function scale(): number
	local n = 0
	for _, g in guests do
		if not g.out then
			n += 1
		end
	end
	return 1 + 0.5 * math.max(0, n - 1)
end

local function broadcast(ctx: Types.Ctx, message: { [string]: any })
	for player in guests do
		ctx.send(player, message)
	end
end

local function status(ctx: Types.Ctx, player: Player): { [string]: any }
	local g = guests[player]
	local bossHp, bossMax = 0, 1
	local boss = run.actors.boss
	if boss then
		bossHp, bossMax = boss.hp, boss.max
	end
	local gens, guardsLeft = 0, 0
	for _, hp in run.generators do
		if hp > 0 then
			gens += 1
		end
	end
	for _, a in run.actors do
		if a.kind == "guard" and a.hp > 0 then
			guardsLeft += 1
		end
	end
	local digits = {}
	if g then
		for k = 1, 4 do
			digits[k] = if g.digits[k] then string.sub(run.code, k, k) else "_"
		end
	end
	return {
		op = "executive",
		phase = run.phase,
		open = run.open,
		alert = if g then math.floor(g.alert * 100 + 0.5) / 100 else 0,
		composure = if g then g.composure else 0,
		max = if g then g.max else 100,
		gear = if g then g.gear else {},
		decoy = if g then not g.decoyUsed and g.gear.decoy == true else false,
		digits = table.concat(digits, " "),
		generators = gens,
		guards = guardsLeft,
		boss = bossHp,
		bossMax = bossMax,
	}
end

local function push(ctx: Types.Ctx, player: Player)
	ctx.send(player, status(ctx, player))
end

local function pushAll(ctx: Types.Ctx)
	for player in guests do
		push(ctx, player)
	end
end

---------------------------------------------------------------------------------------------------
-- The run: made new when the Suite is empty
---------------------------------------------------------------------------------------------------
local function clearActors()
	for _, a in run.actors do
		if a.model then
			a.model:Destroy()
		end
	end
	run.actors = {}
end

local function fresh(_ctx: Types.Ctx)
	local b = built
	if not b then
		return
	end
	run.code = string.format("%04d", rng:NextInteger(0, 9999))
	run.open = false
	run.phase = "hall"
	run.shots, run.waves = {}, {}
	run.decoyUntil = -math.huge
	run.wonAt = 0
	clearActors()
	run.generators = {}
	for i, part in b.generators do
		run.generators["gen" .. i] = 100
		part.Transparency = 0
	end
	b.door.CanCollide = true
	b.door.Transparency = 0
	b.shield.CanCollide = true
	b.shield.Transparency = 0.3
	b.safe.Enabled = false
	b.liftDown.Enabled = false
	-- The hallway's guards, on their rounds.
	for _, a in run.hallGuards do
		if a.model then
			a.model:Destroy()
		end
	end
	run.hallGuards = {}
	for i, round in Plan.GuardRounds do
		local points = {}
		for _, p in round do
			table.insert(points, origin + p)
		end
		local model, root, humanoid = Executive.makeFigure(b.actors, "HallGuard" .. i, CFrame.lookAt(points[1], points[2]), "guard")
		table.insert(run.hallGuards, { id = "hall" .. i, kind = "hallGuard", model = model, root = root, humanoid = humanoid, hp = 1, max = 1, index = 2, lastHit = 0, points = points })
	end
	-- The Executive at his desk, behind the shield.
	local model, root, humanoid = Executive.makeFigure(b.actors, "TheExecutive", CFrame.lookAt(origin + Plan.Desk + Vector3.new(0, 0, 3), origin + Plan.Desk + Vector3.new(0, 0, -10)), "boss")
	-- (Tagged on the whole figure: a shot hits his body, not just his middle.)
	root:SetAttribute("ExecTarget", "boss")
	model:SetAttribute("ExecTarget", "boss")
	run.actors.boss = { id = "boss", kind = "boss", model = model, root = root, humanoid = humanoid, hp = 1, max = 1, index = 1, lastHit = 0 }
end

---------------------------------------------------------------------------------------------------
-- Damage and phases
---------------------------------------------------------------------------------------------------
local function hurt(ctx: Types.Ctx, player: Player, g: Guest, amount: number, why: string)
	if g.out then
		return
	end
	g.composure = math.max(0, g.composure - amount)
	ctx.send(player, { op = "hurt", amount = amount, why = why, composure = g.composure })
	if g.composure <= 0 then
		g.out = true
		ctx.send(player, { op = "escorted" })
		ctx.sendHome(player, ID)
	end
end

local function startPhase(ctx: Types.Ctx, phase: string)
	run.phase = phase
	local b = built :: ExecutiveBuild.Built
	local s = scale()
	if phase == "shield" then
		for id in run.generators do
			run.generators[id] = math.floor(100 * s)
		end
		run.nextAttack = Executive.clock() + 3
	elseif phase == "detail" then
		b.shield.CanCollide = false
		b.shield.Transparency = 1
		for i, at in Plan.GuardDoors do
			local model, root, humanoid = Executive.makeFigure(b.actors, "Bodyguard" .. i, CFrame.new(origin + at), "guard")
			root:SetAttribute("ExecTarget", "guard" .. i)
			model:SetAttribute("ExecTarget", "guard" .. i)
			run.actors["guard" .. i] = { id = "guard" .. i, kind = "guard", model = model, root = root, humanoid = humanoid, hp = math.floor(60 * s), max = math.floor(60 * s), index = 1, lastHit = 0 }
		end
	elseif phase == "boss" then
		local boss = run.actors.boss
		if boss then
			boss.hp = math.floor(400 * s)
			boss.max = boss.hp
		end
		run.nextAttack = Executive.clock() + 2
		run.attackIndex = 0
	elseif phase == "won" then
		run.wonAt = Executive.clock()
		b.safe.Enabled = true
		b.liftDown.Enabled = true
	end
	local def = nil
	for _, p in Plan.Phases do
		if p.id == phase then
			def = p
		end
	end
	broadcast(ctx, { op = "phase", phase = phase, name = def and def.name, line = def and def.line })
	pushAll(ctx)
end

local function win(ctx: Types.Ctx)
	local c = cfg(ctx)
	for player, g in guests do
		local at = ctx.at(player, ID)
		if not g.out and at and Plan.inOffice(at) and not g.paid then
			g.paid = true
			local data = ctx.data(player)
			if data then
				local p = page(ctx, data)
				p.wins += 1
				local worth = tonumber(c.prize) or 25000
				ctx.estate(player, worth, "The Executive Suite")
				local gems = ctx.gems(player, tonumber(c.prizeGems) or 15, "The Executive Suite", ID)
				local brainrot = nil
				local first = not p.firstWin
				if first then
					p.firstWin = true
					if ctx.curio(player, "dirigenteSupremo", "The Executive Suite") then
						brainrot = "dirigenteSupremo"
					end
					ctx.herald(player, { kind = "executive", title = "The Executive beaten", line = "beat the Executive in his own office", glyph = "🕴️", worth = worth, everywhere = true })
				end
				ctx.award(player, "executiveBoss")
				ctx.tally(player, "executiveWins", 1)
				ctx.progress(player, "executiveWin", 1)
				ctx.send(player, { op = "won", worth = worth, gems = gems, brainrot = brainrot, first = first })
			end
		end
	end
	startPhase(ctx, "won")
end

-- A target is hit (by a guest's shot).
local function strike(ctx: Types.Ctx, target: string, damage: number)
	if string.sub(target, 1, 3) == "gen" then
		if run.phase ~= "shield" then
			return
		end
		local hp = run.generators[target]
		if not hp or hp <= 0 then
			return
		end
		run.generators[target] = math.max(0, hp - damage)
		if run.generators[target] <= 0 then
			local b = built :: ExecutiveBuild.Built
			local part = b.generators[tonumber(string.sub(target, 4)) or 0]
			if part then
				part.Transparency = 0.85
			end
			broadcast(ctx, { op = "down", target = target })
			local left = 0
			for _, v in run.generators do
				if v > 0 then
					left += 1
				end
			end
			if left == 0 then
				startPhase(ctx, "detail")
			end
		end
		pushAll(ctx)
	else
		local a = run.actors[target]
		if not a or a.hp <= 0 then
			return
		end
		local wanted = if a.kind == "guard" then "detail" elseif a.kind == "boss" then "boss" else nil
		if wanted and run.phase ~= wanted then
			return
		end
		a.hp = math.max(0, a.hp - damage)
		if a.hp <= 0 then
			broadcast(ctx, { op = "down", target = target })
			if a.kind == "guard" then
				if a.model then
					a.model:Destroy()
				end
				local left = 0
				for _, other in run.actors do
					if other.kind == "guard" and other.hp > 0 then
						left += 1
					end
				end
				if left == 0 then
					startPhase(ctx, "boss")
				end
			elseif a.kind == "boss" then
				win(ctx)
			end
		end
		pushAll(ctx)
	end
end

-- A guest fires their sidearm toward `dir` (from their own head, as the server sees it).
function Executive.fire(ctx: Types.Ctx, player: Player, dir: unknown): boolean
	local g = guests[player]
	if not g or g.out or not g.gear.sidearm then
		return false
	end
	if run.phase ~= "shield" and run.phase ~= "detail" and run.phase ~= "boss" then
		return false
	end
	if typeof(dir) ~= "Vector3" then
		return false
	end
	local d = dir :: Vector3
	if d.Magnitude < 0.5 or d.Magnitude > 1.5 or d.X ~= d.X or d.Y ~= d.Y or d.Z ~= d.Z then
		return false
	end
	local now = os.clock()
	if now - g.lastShot < (tonumber(cfg(ctx).fireGap) or 0.3) then
		return false
	end
	local at = ctx.at(player, ID)
	local root = ctx.rootOf(player)
	if not at or not root or not Plan.inOffice(at) then
		return false
	end
	g.lastShot = now
	local from = root.CFrame.Position + Vector3.new(0, 1.5, 0)
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local target = Executive.ray(from, d.Unit * (tonumber(cfg(ctx).range) or 140), ignore)
	broadcast(ctx, { op = "shot", from = from, dir = d.Unit, by = player.UserId, hit = target })
	if target then
		strike(ctx, target, tonumber(cfg(ctx).damage) or 10)
	end
	return target ~= nil
end

---------------------------------------------------------------------------------------------------
-- The hallway
---------------------------------------------------------------------------------------------------
local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function seenFrom(eye: Vector3, look: Vector3, range: number, angle: number, at: Vector3, ignore: { Instance }): boolean
	local to = flat(at - eye)
	if to.Magnitude > range or to.Magnitude < 1e-3 then
		return to.Magnitude < 1e-3
	end
	if look.Magnitude < 1e-3 then
		return false
	end
	if flat(look).Unit:Dot(to.Unit) < math.cos(math.rad(angle)) then
		return false
	end
	return Executive.clear(eye, at, ignore)
end

local function hallStep(ctx: Types.Ctx, dt: number, t: number)
	local c = cfg(ctx)
	-- The guards walk their rounds.
	for _, a in run.hallGuards do
		local points = a.points :: { Vector3 }
		local goal = points[a.index]
		if flat(goal - a.root.CFrame.Position).Magnitude < 2 then
			a.index = a.index % #points + 1
			goal = points[a.index]
		end
		Executive.walk(a, if t < run.decoyUntil then run.decoyAt else goal, tonumber(c.guardSpeed) or 9)
	end
	for player, g in guests do
		local at = ctx.at(player, ID)
		if g.out or not at or not Plan.inHall(at) then
			continue
		end
		local world = origin + at
		local seen = false
		if t >= run.decoyUntil then
			local ignore: { Instance } = {}
			if player.Character then
				table.insert(ignore, player.Character)
			end
			for _, cam in Plan.Cameras do
				if seenFrom(origin + cam.at, Plan.cameraLook(cam, t), tonumber(c.cameraRange) or 40, tonumber(c.cameraAngle) or 30, world, ignore) then
					seen = true
				end
			end
			for _, a in run.hallGuards do
				local look = a.root.CFrame.LookVector
				if seenFrom(a.root.CFrame.Position + Vector3.new(0, 1.5, 0), look, tonumber(c.guardRange) or 26, tonumber(c.guardAngle) or 55, world, ignore) then
					seen = true
				end
			end
		end
		local before = g.alert
		if seen then
			local rate = 1 / (tonumber(c.noticeSeconds) or 2.2)
			if g.gear.disguise then
				rate *= tonumber(c.disguise) or 0.6
			end
			g.alert = math.min(1, g.alert + dt * rate)
		else
			g.alert = math.max(0, g.alert - dt * (tonumber(c.alertFade) or 0.1))
		end
		if g.alert >= 1 then
			g.out = true
			ctx.send(player, { op = "alarm" })
			ctx.tally(player, "executiveCaught", 1)
			ctx.sendHome(player, ID)
		elseif math.abs(g.alert - before) > 0.04 or (seen and before == 0) then
			push(ctx, player)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The Office
---------------------------------------------------------------------------------------------------
local function playersInOffice(ctx: Types.Ctx): { { player: Player, g: Guest, at: Vector3 } }
	local out = {}
	for player, g in guests do
		local at = ctx.at(player, ID)
		if not g.out and at and Plan.inOffice(at) then
			table.insert(out, { player = player, g = g, at = at })
		end
	end
	return out
end

local function throw(ctx: Types.Ctx, from: Vector3, toward: Vector3, damage: number, t: number)
	run.serial += 1
	local dir = flat(toward - from)
	if dir.Magnitude < 1e-3 then
		dir = Vector3.new(0, 0, -1)
	end
	local shot: Shot = { id = "s" .. run.serial, from = from, dir = dir.Unit, speed = 42, born = t, radius = 2.6, damage = damage, life = 3 }
	table.insert(run.shots, shot)
	broadcast(ctx, { op = "throw", id = shot.id, from = origin + shot.from, dir = shot.dir, speed = shot.speed, born = shot.born, life = shot.life })
end

local function officeStep(ctx: Types.Ctx, _dt: number, t: number)
	local c = cfg(ctx)
	local here = playersInOffice(ctx)
	if #here == 0 then
		return
	end
	local boss = run.actors.boss
	-- Thrown things: each hits each guest once.
	for k = #run.shots, 1, -1 do
		local s = run.shots[k]
		local age = t - s.born
		if age > s.life then
			table.remove(run.shots, k)
			continue
		end
		local pos = s.from + s.dir * s.speed * age
		for _, h in here do
			if not h.g.hits[s.id] and flat(h.at - pos).Magnitude <= s.radius and h.at.Y < 6 then
				h.g.hits[s.id] = true
				hurt(ctx, h.player, h.g, s.damage, "briefcase")
			end
		end
	end
	-- Shockwaves: jump them (in the air as it passes, it misses).
	for k = #run.waves, 1, -1 do
		local w = run.waves[k]
		local age = t - w.born
		if age > w.life then
			table.remove(run.waves, k)
			continue
		end
		local r = w.speed * age
		for _, h in here do
			local d = flat(h.at - w.at).Magnitude
			if not h.g.hits[w.id] and math.abs(d - r) <= w.width / 2 and h.at.Y < 4.2 then
				h.g.hits[w.id] = true
				hurt(ctx, h.player, h.g, w.damage, "shockwave")
			end
		end
	end
	if run.phase == "shield" and boss then
		if t >= run.nextAttack then
			run.nextAttack = t + 3
			local h = here[rng:NextInteger(1, #here)]
			throw(ctx, Plan.Desk + Vector3.new(0, 3, -4), h.at, tonumber(c.memoDamage) or 8, t)
		end
	elseif run.phase == "detail" then
		for _, a in run.actors do
			if a.kind ~= "guard" or a.hp <= 0 then
				continue
			end
			local pos = a.root.CFrame.Position - origin
			local nearest, best = nil, math.huge
			for _, h in here do
				local d = flat(h.at - pos).Magnitude
				if d < best then
					nearest, best = h, d
				end
			end
			if nearest then
				if best <= 4.5 then
					if t - a.lastHit >= 1.2 then
						a.lastHit = t
						hurt(ctx, nearest.player, nearest.g, tonumber(c.punch) or 12, "bodyguard")
					end
				else
					Executive.walk(a, origin + nearest.at, tonumber(c.bodyguardSpeed) or 14)
				end
			end
		end
	elseif run.phase == "boss" and boss then
		local enraged = boss.hp < boss.max / 2
		if t >= run.nextAttack then
			run.nextAttack = t + (if enraged then 1.8 else 2.6)
			run.attackIndex += 1
			local kind = run.attackIndex % 3
			local bpos = boss.root.CFrame.Position - origin
			if kind == 1 then
				-- A volley of briefcases, one at each of up to three guests.
				for i = 1, math.min(3, #here) do
					throw(ctx, bpos + Vector3.new(0, 2, 0), here[i].at, tonumber(c.briefcase) or 15, t)
				end
				broadcast(ctx, { op = "attack", kind = "volley" })
			elseif kind == 2 then
				run.serial += 1
				local w: Wave = { id = "w" .. run.serial, at = Vector3.new(bpos.X, 0, bpos.Z), born = t, speed = 26, width = 3, damage = tonumber(c.shockwave) or 20, life = 2.2 }
				table.insert(run.waves, w)
				broadcast(ctx, { op = "wave", id = w.id, at = origin + w.at, born = w.born, speed = w.speed, width = w.width, life = w.life })
			else
				-- His dash, to another spot.
				local spot = Plan.BossSpots[rng:NextInteger(1, #Plan.BossSpots)]
				Executive.walk(boss, origin + spot, 40)
				broadcast(ctx, { op = "attack", kind = "dash" })
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The attraction
---------------------------------------------------------------------------------------------------
function Executive.build(ctx: Types.Ctx, parent: Instance)
	origin = AttractionList.origin(ID)
	built = ExecutiveBuild.build(parent, origin, function(player: Player)
		if ctx.inside(player) == ID then
			ctx.sendHome(player, ID)
		end
	end)
	local b = built :: ExecutiveBuild.Built
	for i, p in b.terminals do
		p.Triggered:Connect(function(player: Player)
			Executive.ask(ctx, player, { act = "terminal", n = i })
		end)
	end
	b.keypad.Triggered:Connect(function(player: Player)
		if guests[player] and not run.open then
			ctx.send(player, { op = "keypad" })
		end
	end)
	b.safe.Triggered:Connect(function(player: Player)
		Executive.ask(ctx, player, { act = "safe" })
	end)
	b.liftDown.Triggered:Connect(function(player: Player)
		if ctx.inside(player) == ID and run.phase == "won" then
			ctx.sendHome(player, ID)
		end
	end)
	-- The sidearm: a guest's screen sends where they aimed; the server decides what was hit.
	RemoteGuard.event(Remotes.event("AttractionFire"), "attractionFire", function(player: Player, dir: unknown)
		Executive.fire(ctx, player, dir)
	end)
	fresh(ctx)
end

function Executive.enter(ctx: Types.Ctx, player: Player): (CFrame?, string?)
	local data = ctx.data(player)
	if not data then
		return nil, "Your ledger is still being opened."
	end
	local p = page(ctx, data)
	if not p.sidearm then
		return nil, "Take your sidearm from the Quartermaster first: every guest carries one up."
	end
	if p.invites <= 0 then
		return nil, "The Executive Suite is by invitation only. Clear the Maison Basement, bank a great haul in Steal a Luxe, or ask the Quartermaster."
	end
	if run.phase == "won" then
		return nil, "The Executive has just been beaten: the Suite opens again in a moment."
	end
	p.invites -= 1
	local gear: { [string]: boolean } = { sidearm = true }
	for id, on in p.kit do
		if on == true and Plan.byGear[id] then
			gear[id] = true
		end
	end
	p.kit = {}
	local max = if gear.vest then 150 else 100
	guests[player] = { alert = 0, composure = max, max = max, gear = gear, decoyUsed = false, digits = {}, tries = 0, lastShot = -math.huge, paid = false, safe = false, hits = {}, out = false }
	task.defer(function()
		if guests[player] then
			push(ctx, player)
		end
	end)
	ctx.tally(player, "executiveVisits", 1)
	return CFrame.new(Plan.Arrival), nil
end

function Executive.leave(ctx: Types.Ctx, player: Player, _why: string)
	guests[player] = nil
	-- The Suite empty: a new run for whoever comes up next.
	if next(guests) == nil then
		fresh(ctx)
	end
end

function Executive.step(ctx: Types.Ctx, dt: number)
	if not built then
		return
	end
	local t = Executive.clock()
	hallStep(ctx, dt, t)
	-- Into the Office through the open door: the Executive is waiting.
	if run.phase == "hall" and run.open and #playersInOffice(ctx) > 0 then
		startPhase(ctx, "shield")
	end
	if run.phase ~= "hall" and run.phase ~= "won" then
		officeStep(ctx, dt, t)
	end
end

-- The Quartermaster and the Suite's own requests.
function Executive.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	if not data then
		return {}
	end
	local p = page(ctx, data)
	local c = cfg(ctx)
	local gear = {}
	for _, g in Plan.Gear do
		table.insert(gear, { id = g.id, name = g.name, line = g.line, price = g.price, glyph = g.glyph, free = g.free == true, packed = if g.id == "sidearm" then p.sidearm else p.kit[g.id] == true })
	end
	local out: { [string]: any } = {
		invites = p.invites,
		most = tonumber(c.maxInvites) or 5,
		invitePrice = tonumber(c.invitePrice) or 25000,
		inviteHaul = tonumber(c.inviteHaul) or 8000,
		sidearm = p.sidearm,
		gear = gear,
		wins = p.wins,
	}
	if guests[player] then
		out.run = status(ctx, player)
	end
	return out
end

function Executive.ask(ctx: Types.Ctx, player: Player, r: { [string]: unknown }): any
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(ctx, data)
	local c = cfg(ctx)
	local act = r.act
	if act == "sidearm" then
		p.sidearm = true
		return { ok = true, state = Executive.state(ctx, player) }
	elseif act == "gear" then
		local id = r.what
		local g = if type(id) == "string" then Plan.byGear[id] else nil
		if not g or g.free then
			return { ok = false, why = "There's no such gear." }
		end
		if p.kit[g.id] then
			return { ok = false, why = "That's already packed for your next run." }
		end
		if not ctx.spend(player, g.price, 0, "executive_" .. g.id) then
			return { ok = false, why = string.format("That's %s Gilt.", Fortune.format(g.price)) }
		end
		p.kit[g.id] = true
		return { ok = true, state = Executive.state(ctx, player) }
	elseif act == "invite" then
		local most = tonumber(c.maxInvites) or 5
		if p.invites >= most then
			return { ok = false, why = string.format("You hold %d invitations: the most there is.", most) }
		end
		local price = tonumber(c.invitePrice) or 25000
		if not ctx.spend(player, price, 0, "executive_invite") then
			return { ok = false, why = string.format("An invitation is %s Gilt.", Fortune.format(price)) }
		end
		p.invites += 1
		return { ok = true, state = Executive.state(ctx, player) }
	end
	-- In the Suite.
	local g = guests[player]
	if not g or g.out or ctx.inside(player) ~= ID then
		return { ok = false, why = "You're not in the Executive Suite." }
	end
	local at = ctx.at(player, ID)
	if act == "terminal" then
		local n = tonumber(r.n)
		local spot = n and Plan.Terminals[n]
		if not spot or not at then
			return { ok = false, why = "Not that." }
		end
		if (flat(at - spot)).Magnitude > 9 then
			return { ok = false, why = "Get closer to it." }
		end
		g.digits[n :: number] = true
		ctx.send(player, { op = "digit", n = n, digit = string.sub(run.code, n :: number, n :: number) })
		push(ctx, player)
		return { ok = true }
	elseif act == "code" then
		if run.open then
			return { ok = true }
		end
		if not at or flat(at - Vector3.new(0, 0, Plan.Door.z)).Magnitude > 12 then
			return { ok = false, why = "Enter it at the keypad by the door." }
		end
		local code = r.code
		if type(code) ~= "string" or #code ~= 4 or not string.match(code, "^%d%d%d%d$") then
			return { ok = false, why = "Four digits." }
		end
		if code ~= run.code then
			g.tries += 1
			if g.tries >= 3 then
				g.tries = 0
				g.alert = math.min(0.99, g.alert + 0.5)
				push(ctx, player)
				return { ok = false, why = "Wrong, and the alarm is close: careful." }
			end
			return { ok = false, why = "That's not the code." }
		end
		run.open = true
		local b = built :: ExecutiveBuild.Built
		b.door.CanCollide = false
		b.door.Transparency = 1
		broadcast(ctx, { op = "doorOpen" })
		pushAll(ctx)
		return { ok = true }
	elseif act == "decoy" then
		if not g.gear.decoy or g.decoyUsed then
			return { ok = false, why = "You've no decoy left." }
		end
		if not at or not Plan.inHall(at) then
			return { ok = false, why = "A decoy works in the hallway." }
		end
		g.decoyUsed = true
		run.decoyUntil = Executive.clock() + (tonumber(c.decoySeconds) or 8)
		run.decoyAt = origin + at
		broadcast(ctx, { op = "decoy", at = origin + at, seconds = tonumber(c.decoySeconds) or 8 })
		push(ctx, player)
		return { ok = true }
	elseif act == "safe" then
		if run.phase ~= "won" then
			return { ok = false, why = "Not while the Executive is watching." }
		end
		if g.safe then
			return { ok = false, why = "You've had your share of the safe." }
		end
		if not at or flat(at - Plan.Safe).Magnitude > 10 then
			return { ok = false, why = "Get closer to it." }
		end
		g.safe = true
		local worth = tonumber(c.safe) or 6000
		ctx.estate(player, worth, "The Executive Suite")
		ctx.send(player, { op = "safe", worth = worth })
		return { ok = true, worth = worth }
	end
	return { ok = false, why = "That isn't something the house does." }
end

-- An invitation, earned (the Basement, a great haul) or given (the owner). Returns whether it fit.
function Executive.invite(ctx: Types.Ctx, player: Player, why: string): boolean
	local data = ctx.data(player)
	if not data then
		return false
	end
	local p = page(ctx, data)
	local most = tonumber(cfg(ctx).maxInvites) or 5
	if p.invites >= most then
		return false
	end
	p.invites += 1
	ctx.send(player, { op = "invited", why = why, invites = p.invites })
	return true
end

-- For tests.
Executive.guests = guests
Executive.run = run
Executive.page = page
Executive.origin = function(): Vector3
	return origin
end
Executive.built = function(): ExecutiveBuild.Built?
	return built
end
Executive.fresh = fresh

return Executive

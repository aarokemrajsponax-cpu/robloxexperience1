--!strict
-- The Maison Basement on the server: the course (BasementBuild), every guest's run, and the boards.
-- Everything is judged here from where the server sees each guest and the plan's own sums of the
-- machinery (shared/Basement), by the server's clock.
--
--   Checkpoints   reached in order, standing on each one's pad: the first time in a run, a little
--                 Gilt; at the end of each of the eight parts, its purse to the Estate. Leave by a lift
--                 or the arch at any time: everything already paid is yours.
--   Falling       into a pit, or caught in steam, a laser or the valve's sweep (a moment's touch, so a
--                 screen a little behind the server is never sent back for nothing): back to the last
--                 checkpoint, and a few seconds' grace.
--   The Treasury  the last checkpoint: the chest pays its Gilt (more the first time each day), the
--                 last purse, the brainrot Topo Tesoriere the first time ever, and the run's time.
--   Times         from leaving the start to the Treasury. The best is kept, and goes to the boards
--                 (all time and this week); a run with a skipped stage is never timed for them.
--   Skips         one stage on, for skips held (Robux, ProductConfig "basementSkip") or for Gems;
--                 the deeper the stage, the more it costs (shared/Basement's skipGems, skipsNeeded).
--                 Never the Treasury itself, never a stage's Gilt; the run is marked as skipped.
--   Courses       (Build 78) the course turns over every five minutes (shared/Basement Variants):
--                 a run keeps the version it started on to the Treasury (a run not yet begun
--                 takes the new one); every guest down here is told a turn is coming, and when it
--                 comes. Its machinery runs at its own pace, by its own sums; each version keeps
--                 its own best time; its secrets pay once each, for good; its launch pad tells the
--                 movement watch it's the house throwing them up.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local okAnalytics, Analytics = pcall(function()
	return require(script.Parent.Parent.Analytics) :: any
end)
local Names = require(ReplicatedStorage.Shared.Names)
local Plan = require(ReplicatedStorage.Shared.Basement)
local FortuneRules = require(ReplicatedStorage.Shared.Fortune)
local BasementBuild = require(script.Parent.BasementBuild)
local Types = require(script.Parent.Types)

local Basement = {}

local ID = "basement"
local CREDIT = "basement_skip"

-- The server's clock, as every screen reads it (set by tests).
Basement.clock = function(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

-- Skips held and used (set by Main: the purchase system's held credits), and the purchase window.
Basement.skipsHeld = function(_player: Player): number
	return 0
end
Basement.useSkip = function(_player: Player): boolean
	return false
end
Basement.offerSkip = function(_player: Player): (boolean, string?)
	return false, "That isn't on sale yet."
end
Basement.skipOnSale = function(): boolean
	return false
end

-- A guest reached the Treasury (set by the attractions: an invitation to the Executive Suite).
Basement.cleared = function(_player: Player) end

-- The version of the course up at time t (set by tests).
Basement.variantNow = function(t: number): number
	return Plan.variantAt(t)
end

-- The boards' stores (set by tests).
Basement.store = function(name: string): any
	return DataStoreService:GetOrderedDataStore(name)
end
-- Whether two guests are friends (asked of Roblox; set by tests).
Basement.friends = function(player: Player, userId: number): boolean
	local ok, yes = pcall(function()
		return player:IsFriendsWithAsync(userId)
	end)
	return ok and yes == true
end

type Run = {
	checkpoint: number,
	started: number?, -- the server's clock when they left the start
	assisted: boolean, -- a stage was skipped
	paid: { [number]: boolean },
	falls: number,
	grace: number,
	touching: { [number]: number }, -- an element's number: how many beats in a row they've touched it
	done: boolean,
	variant: number, -- the version of the course this run is on (Build 78)
	launchGrace: number, -- (os.clock) the movement watch was last told of a launch pad
	lastAt: Vector3?, -- (Build 87) where they were at the last look, and the course's time then
	lastTv: number?,
}

local origin = Vector3.zero
local built: BasementBuild.Built? = nil
local runs: { [Player]: Run } = {}
local byStage: { [number]: { { i: number, e: Plan.El } } } = {}
local boards: { [string]: any } = { all = {}, week = {}, available = false }
local names: { [number]: string } = {}
local lastRefresh = -math.huge
local announced = { period = -1, warned = -1 } -- (the turns of the course told to everyone down here)
local secretIds: { [string]: Plan.El } = {}
for _, e in Plan.Secrets do
	if e.id then
		secretIds[e.id] = e
	end
end

local function note(player: Player, name: string, props: { [string]: any }?)
	if okAnalytics and Analytics and Analytics.custom then
		pcall(Analytics.custom, player, name, 1, props)
	end
end

local function cfg(ctx: Types.Ctx): { [string]: any }
	return ctx.cfg(ID)
end

-- What skipping `stage` costs in Gems (Config can change the first stage's price and the step).
local function skipGems(ctx: Types.Ctx, stage: number): number
	return Plan.skipGems(stage, tonumber(cfg(ctx).skipGems), tonumber(cfg(ctx).skipGemsStep))
end

local function weekIndex(): number
	return math.floor((math.floor(os.time() / 86400) + 3) / 7)
end

local function page(ctx: Types.Ctx, data: any): { [string]: any }
	local p = ctx.saved(data, ID)
	p.best = if type(p.best) == "number" and p.best > 0 then p.best else nil
	p.weekBest = if type(p.weekBest) == "number" and p.weekBest > 0 then p.weekBest else nil
	if p.week ~= weekIndex() then
		p.week = weekIndex()
		p.weekBest = nil
	end
	p.clears = if type(p.clears) == "number" then p.clears else 0
	p.deepest = if type(p.deepest) == "number" then p.deepest else 0
	p.firstClear = p.firstClear == true
	if type(p.bests) ~= "table" then
		p.bests = {} -- a course's id -> its best time (Build 78)
	end
	if type(p.secrets) ~= "table" then
		p.secrets = {} -- a secret's id -> true, once found
	end
	-- (Build 82) The course more than doubled: times on the old one are kept as they were, under
	-- their own names, and the new course's bests start afresh. (Build 89: and again, sixteen
	-- stages to thirty-two: the sixteen's times kept as bestV2, the new course's fresh.)
	if type(p.course) ~= "number" or p.course < 2 then
		if p.best or next(p.bests) ~= nil then
			p.bestV1 = p.best
			p.bestsV1 = p.bests
		end
		p.best = nil
		p.weekBest = nil
		p.bests = {}
		p.course = 2
	end
	if p.course == 2 then
		if p.best or next(p.bests) ~= nil then
			p.bestV2 = p.best
			p.bestsV2 = p.bests
		end
		p.best = nil
		p.weekBest = nil
		p.bests = {}
		p.course = 3
	end
	return p
end

---------------------------------------------------------------------------------------------------
-- The boards
---------------------------------------------------------------------------------------------------
local function storeName(ctx: Types.Ctx, which: string): string
	local base = tostring(cfg(ctx).store or "Basement_v1")
	return if which == "week" then base .. "_week_" .. weekIndex() else base
end

local function nameOf(userId: number): string
	local known = names[userId]
	if known then
		return known
	end
	local player = Players:GetPlayerByUserId(userId)
	local name = if player then Names.of(player) else nil
	if not name then
		local ok, found = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		name = if ok and type(found) == "string" then found else "A guest"
	end
	names[userId] = name :: string
	return name :: string
end

local function readBoard(ctx: Types.Ctx, which: string): { any }?
	local ok, got = pcall(function()
		return Basement.store(storeName(ctx, which)):GetSortedAsync(true, 50):GetCurrentPage()
	end)
	if not ok or type(got) ~= "table" then
		return nil
	end
	local out = {}
	for _, item in got :: { any } do
		local userId = tonumber(item.key)
		if userId and type(item.value) == "number" and item.value > 0 then
			table.insert(out, { userId = userId, name = nameOf(userId), score = item.value / 100 })
		end
	end
	return out
end

function Basement.refreshBoards(ctx: Types.Ctx)
	lastRefresh = os.clock()
	local all, week = readBoard(ctx, "all"), readBoard(ctx, "week")
	if all then
		boards.all = all
		boards.available = true
	end
	if week then
		boards.week = week
	end
end

local function submit(ctx: Types.Ctx, player: Player, which: string, seconds: number)
	local cs = math.floor(seconds * 100 + 0.5)
	pcall(function()
		Basement.store(storeName(ctx, which)):SetAsync(tostring(player.UserId), cs)
	end)
	-- (On the board here at once, without waiting for the next read.)
	local list = boards[which]
	if type(list) == "table" then
		for k = #list, 1, -1 do
			if list[k].userId == player.UserId then
				table.remove(list, k)
			end
		end
		table.insert(list, { userId = player.UserId, name = Names.of(player), score = cs / 100 })
		table.sort(list, function(a, b)
			return a.score < b.score
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Telling a guest's screen
---------------------------------------------------------------------------------------------------
local function secretsFound(p: { [string]: any }?): (number, { string })
	local n, ids = 0, {}
	if p then
		for id in p.secrets do
			if secretIds[id] then
				n += 1
				table.insert(ids, id)
			end
		end
	end
	return n, ids
end

local function summary(ctx: Types.Ctx, player: Player, run: Run): { [string]: any }
	local data = ctx.data(player)
	local p = if data then page(ctx, data) else nil
	local next = math.min(Plan.STAGES, run.checkpoint + 1)
	local t = Basement.clock()
	local up = Basement.variantNow(t)
	local course = Plan.Variants[run.variant] or Plan.Variants[1]
	local found, ids = secretsFound(p)
	return {
		course = course.name,
		courseId = course.id,
		courseLine = course.line,
		variant = run.variant,
		upNow = Plan.Variants[up].name, -- (the version up just now: the next run's)
		turnsAt = Plan.variantEnds(t),
		nextCourse = Plan.Variants[up % #Plan.Variants + 1].name,
		coursePb = if p then p.bests[course.id] else nil,
		secrets = found,
		secretsOf = #Plan.Secrets,
		secretIds = ids,
		op = "basement",
		checkpoint = run.checkpoint,
		stage = next,
		stageName = Plan.StageNames[next],
		zone = Plan.Zones[Plan.zoneOf(next)].name,
		started = run.started,
		assisted = run.assisted,
		falls = run.falls,
		best = if p then p.best else nil,
		done = run.done,
		skips = Basement.skipsHeld(player),
		skipGems = skipGems(ctx, next),
		skipNeed = Plan.skipsNeeded(next),
		skipOnSale = Basement.skipOnSale(),
		-- (Build 102) What the next checkpoint pays, as raw Gilt (and a part's purse when it ends a
		-- part): the guest's screen shows it with their boosts, the same sum the server pays with.
		nextRaw = Basement.stageRaw(next),
	}
end

local function push(ctx: Types.Ctx, player: Player, run: Run)
	ctx.send(player, summary(ctx, player, run))
end

---------------------------------------------------------------------------------------------------
-- The course
---------------------------------------------------------------------------------------------------
local function checkpointFrame(n: number): CFrame
	local c = Plan.Checkpoints[n]
	return CFrame.new(origin + c.at + Vector3.new(0, 0, -c.size.Z / 2 + 2))
end

-- Back to the last checkpoint.
local function fall(ctx: Types.Ctx, player: Player, run: Run, why: string)
	note(player, "Basement fall", { stage = run.checkpoint + 1, why = why, course = (Plan.Variants[run.variant] or Plan.Variants[1]).id })
	run.falls += 1
	run.grace = os.clock() + (tonumber(cfg(ctx).fallGrace) or 1.5)
	run.touching = {}
	run.lastAt, run.lastTv = nil, nil
	ctx.teleport(player, checkpointFrame(run.checkpoint))
	ctx.send(player, { op = "fell", why = why, checkpoint = run.checkpoint })
	push(ctx, player, run)
end

local function finish(ctx: Types.Ctx, player: Player, run: Run, data: any, p: { [string]: any })
	run.done = true
	local c = cfg(ctx)
	local now = Basement.clock()
	local seconds = if run.started then now - run.started else nil
	local today = math.floor(os.time() / 86400)
	local firstToday = p.lastClearDay ~= today
	p.lastClearDay = today
	p.clears += 1
	-- (The day's first chest in full; the rest, which can be run again and again, as all Gilt is.)
	local chest = if firstToday
		then ctx.prize(player, FortuneRules.scaled(tonumber(c.chestGilt) or 400), "The Maison Basement: the Treasury's chest")
		else ctx.gilt(player, tonumber(c.chestGiltAgain) or 120, "The Maison Basement: the Treasury's chest")
	local first = not p.firstClear
	local brainrot = nil
	if first then
		p.firstClear = true
		if ctx.curio(player, "topoTesoriere", "The Maison Basement") then
			brainrot = "topoTesoriere"
		end
	end
	local record, weekRecord = false, false
	local course = Plan.Variants[run.variant] or Plan.Variants[1]
	local courseRecord = false
	if seconds and not run.assisted then
		local was = p.bests[course.id]
		if type(was) ~= "number" or seconds < was then
			courseRecord = type(was) == "number"
			p.bests[course.id] = seconds
		end
		if not p.best or seconds < p.best then
			record = p.best ~= nil
			p.best = seconds
			submit(ctx, player, "all", seconds)
		end
		if not p.weekBest or seconds < p.weekBest then
			weekRecord = true
			p.weekBest = seconds
			submit(ctx, player, "week", seconds)
		end
	end
	ctx.award(player, "basementClear")
	Basement.cleared(player)
	if seconds and not run.assisted and seconds <= (tonumber(c.quick) or 240) then
		ctx.award(player, "basementQuick")
	end
	ctx.tally(player, "basementClears", 1)
	ctx.progress(player, "basementClear", 1)
	local found = secretsFound(p)
	ctx.send(player, {
		op = "treasury",
		seconds = seconds,
		timed = seconds ~= nil and not run.assisted,
		record = record,
		weekRecord = weekRecord,
		best = p.best,
		chest = chest,
		brainrot = brainrot,
		first = first,
		falls = run.falls,
		course = course.name,
		coursePb = p.bests[course.id],
		courseRecord = courseRecord,
		secrets = found,
		secretsOf = #Plan.Secrets,
	})
	note(player, "Basement cleared", { course = course.id, seconds = if seconds then math.floor(seconds) else -1, falls = run.falls })
	if first then
		ctx.herald(player, { kind = "basement", title = "The Basement beaten", line = "reached the Treasury at the foot of the Maison Basement", glyph = "🗝️" })
	elseif seconds and not run.assisted and seconds <= (tonumber(c.heraldUnder) or 180) and record then
		ctx.herald(player, { kind = "basement", title = "A Basement record", line = "ran the Maison Basement in " .. Plan.clock(seconds), glyph = "⏱️" })
	end
	push(ctx, player, run)
end

-- (Build 102) What checkpoint `n` pays in raw Gilt before boosts: its own Gilt, and the purse's
-- Gilt share when it ends a part of the course. One sum for the screen and the payment.
function Basement.stageRaw(n: number): number
	local zone = Plan.Zones[Plan.zoneOf(math.clamp(n, 1, Plan.STAGES))]
	local raw = 15 + 5 * n
	if zone and zone.to == n then
		raw += FortuneRules.cash(zone.purse)
	end
	return raw
end

-- A guest stands on checkpoint `n` (the next in order).
local function reach(ctx: Types.Ctx, player: Player, run: Run, n: number, skipped: boolean?)
	run.checkpoint = n
	local data = ctx.data(player)
	if not data then
		return
	end
	local p = page(ctx, data)
	p.deepest = math.max(p.deepest, n)
	local gilt = 0
	if not run.paid[n] then
		run.paid[n] = true
		if not skipped then
			-- (Build 102: the checkpoint and, at a part's end, the purse's Gilt, paid as one sum:
			-- exactly what the screen showed for this checkpoint.)
			gilt = ctx.gilt(player, Basement.stageRaw(n), "The Maison Basement")
		else
			-- (Build 100) A skipped stage pays its Gilt too. The skip was bought (Gems or Robux),
			-- so that Gilt is marked as bought and never lifts anyone up the Wealthiest board.
			gilt = ctx.gilt(player, 15 + 5 * n, "The Maison Basement: a skipped stage")
			if gilt > 0 then
				pcall(function()
					require(script.Parent.Parent.Fortune).bought(data, gilt, 0)
				end)
			end
		end
	end
	local zone = Plan.Zones[Plan.zoneOf(n)]
	local purse = 0
	-- (Build 89: a stage skipped, a bought way past it, pays no purse and counts no checkpoint: the
	-- Estate and XP are only ever for what the guest did.)
	if zone.to == n and not skipped then
		purse = zone.purse
		-- (Its Gilt is already in this checkpoint's pay above: the Estate takes the worth alone.)
		ctx.estate(player, purse, "The Maison Basement", false)
	end
	if not skipped then
		ctx.tally(player, "basementCheckpoints", 1)
	end
	ctx.send(player, { op = "checkpoint", n = n, gilt = gilt, purse = purse, zone = zone.name, skipped = skipped == true })
	if n >= Plan.STAGES then
		finish(ctx, player, run, data, p)
	else
		push(ctx, player, run)
	end
end

-- Whether a guest's body (feet to head) is in a box.
local function bodyIn(at: Vector3, centre: Vector3, size: Vector3, cf: CFrame?): boolean
	for _, dy in { -1.6, 0, 1.2 } do
		if Plan.inBox(at + Vector3.new(0, dy, 0), centre, size, 0.4, cf) then
			return true
		end
	end
	return false
end

-- A secret found: paid once, kept for good.
local function findSecret(ctx: Types.Ctx, player: Player, run: Run, e: Plan.El)
	local data = ctx.data(player)
	if not data or not e.id then
		return
	end
	local p = page(ctx, data)
	if p.secrets[e.id] then
		return
	end
	p.secrets[e.id] = true
	local found = secretsFound(p)
	local gilt = ctx.gilt(player, tonumber(cfg(ctx).secretGilt) or 300, "The Maison Basement: a secret")
	ctx.send(player, { op = "secret", id = e.id, name = e.name, gilt = gilt, found = found, of = #Plan.Secrets })
	ctx.tally(player, "basementSecrets", 1)
	note(player, "Basement secret", { secret = e.id, course = (Plan.Variants[run.variant] or Plan.Variants[1]).id })
	if found >= #Plan.Secrets then
		ctx.award(player, "basementSecrets")
	end
	push(ctx, player, run)
end

local function judge(ctx: Types.Ctx, player: Player, run: Run, at: Vector3, t: number)
	if run.done then
		return
	end
	-- (A run not yet begun takes whichever version is up: the course they'll run is the one in
	-- front of them.)
	if not run.started and run.checkpoint == 0 then
		local up = Basement.variantNow(t)
		if up ~= run.variant then
			run.variant = up
			player:SetAttribute("BasementVariant", up)
			push(ctx, player, run)
		end
	end
	-- The machinery's time on this run's course.
	local tv = Plan.paced(run.variant, t)
	-- Leaving the start: the clock starts.
	if not run.started and run.checkpoint == 0 and at.Z > Plan.Checkpoints[0].at.Z + Plan.Checkpoints[0].size.Z / 2 then
		run.started = t
		push(ctx, player, run)
	end
	-- The next checkpoint, in order.
	local on = Plan.checkpointAt(at)
	if on and on == run.checkpoint + 1 and ctx.trusted(player) then
		reach(ctx, player, run, on)
		return
	end
	-- Secrets, and a launch pad (the movement watch is told it's the house throwing them up).
	for _, n in { run.checkpoint + 1, run.checkpoint } do
		local near: { { i: number, e: Plan.El } } = byStage[n] or {}
		for _, item in near do
			local e: Plan.El = item.e
			local kind: string = e.kind
			if kind == "secret" and Plan.inVariant(e, run.variant) then
				if (at - e.at).Magnitude <= 3.6 then
					findSecret(ctx, player, run, e)
				end
			elseif kind == "bouncer" and Plan.inVariant(e, run.variant) then
				local rel = at - e.at
				if math.abs(rel.X) <= e.size.X / 2 + 1.5 and math.abs(rel.Z) <= e.size.Z / 2 + 1.5 and rel.Y > -1 and rel.Y < 24 and os.clock() >= run.launchGrace then
					run.launchGrace = os.clock() + 0.5
					ctx.moved(player)
				end
			end
		end
	end
	if os.clock() < run.grace then
		run.lastAt, run.lastTv = nil, nil -- (a teleport: the way from before it is no way at all)
		return
	end
	-- (Build 82) Well below their stage's floor: fallen, wherever to (a pit, the hall's floor, or a
	-- later stage's platforms below: nobody skips a stage by dropping onto the ones ahead).
	local floor = Plan.Floors[math.clamp(run.checkpoint + 1, 1, Plan.STAGES)]
	if floor and at.Y < floor - Plan.FALL_BELOW then
		fall(ctx, player, run, "fall")
		return
	end
	-- (Build 87) The way they came since the last look (a tenth of a second ago): a running guest
	-- covers two studs or more in that time, more than a laser is thick, so the path between is
	-- checked too, each point against the hazard as it was at that moment. Until now only where
	-- they stood was checked, twice running: walking into a laser or steam already burning was
	-- seldom caught, while standing still as it lit always was.
	local prev, prevT = run.lastAt, run.lastTv
	run.lastAt, run.lastTv = at, tv
	local samples: { { p: Vector3, t: number } } = { { p = at, t = tv } }
	if prev and prevT and (at - prev).Magnitude < 14 then
		local n = math.clamp(math.ceil((at - prev).Magnitude / 0.5), 1, 28)
		local top = math.max(prev.Y, at.Y) -- (in between, the higher of the two: a jump is given the benefit)
		for k = 0, n - 1 do
			local f = k / n
			local flat = prev:Lerp(at, f)
			table.insert(samples, { p = if k == 0 then prev else Vector3.new(flat.X, top, flat.Z), t = prevT + (tv - prevT) * f })
		end
	end
	-- Where the guest's own screen showed them is a beat behind the server: each hazard is judged as
	-- it was then (LAG), and only once it had been burning a moment (so the very start of a burn,
	-- or its very end, never catches someone the screen showed clear of it).
	local LAG = 0.1
	-- What can send them back: in the stage they're on, and the one behind (on this run's course).
	for _, n in { run.checkpoint + 1, run.checkpoint } do
		local list = byStage[n]
		if not list then
			continue
		end
		for _, item in list do
			local e = item.e
			if not Plan.inVariant(e, run.variant) then
				continue
			end
			if e.kind == "pit" then
				if Plan.inBox(at, e.at + Vector3.new(0, 3, 0), e.size + Vector3.new(0, 6, 0), 0) then
					fall(ctx, player, run, "fall")
					return
				end
			elseif e.kind == "steam" or e.kind == "laser" or e.kind == "crusher" then
				for _, sm in samples do
					local when = sm.t - LAG
					if Plan.burning(e, when) and Plan.burning(e, when - 0.15) and bodyIn(sm.p, e.at, e.size) then
						fall(ctx, player, run, e.kind)
						return
					end
				end
			elseif e.kind == "spinner" then
				for _, sm in samples do
					if bodyIn(sm.p, e.at, e.size, Plan.spinnerFrame(e, sm.t - LAG)) then
						fall(ctx, player, run, "valve")
						return
					end
				end
			end
		end
	end
	-- Below everything (the pits should catch everyone; this catches the rest).
	local pit = Plan.Pits[math.max(1, math.min(Plan.STAGES, run.checkpoint + 1))]
	if at.Y < pit.at.Y - 20 then
		fall(ctx, player, run, "fall")
	end
end

---------------------------------------------------------------------------------------------------
-- The attraction
---------------------------------------------------------------------------------------------------
function Basement.build(ctx: Types.Ctx, parent: Instance)
	origin = AttractionList.origin(ID)
	for i, e in Plan.Elements do
		local n = e.stage
		byStage[n] = byStage[n] or {}
		table.insert(byStage[n], { i = i, e = e })
	end
	built = BasementBuild.build(parent, origin, function(player: Player)
		if ctx.inside(player) == ID then
			ctx.sendHome(player, ID)
		end
	end)
	local b = built :: BasementBuild.Built
	for _, lift in b.lifts do
		lift.Triggered:Connect(function(player: Player)
			if ctx.inside(player) == ID then
				ctx.sendHome(player, ID)
			end
		end)
	end
	task.spawn(function()
		Basement.refreshBoards(ctx)
	end)
end

function Basement.enter(ctx: Types.Ctx, player: Player): (CFrame?, string?)
	local data = ctx.data(player)
	if not data then
		return nil, "Your ledger is still being opened."
	end
	page(ctx, data)
	local up = Basement.variantNow(Basement.clock())
	runs[player] = { checkpoint = 0, started = nil, assisted = false, paid = {}, falls = 0, grace = os.clock() + 2, touching = {}, done = false, variant = up, launchGrace = 0 }
	player:SetAttribute("BasementVariant", up)
	note(player, "Basement entered", { course = Plan.Variants[up].id })
	task.defer(function()
		local run = runs[player]
		if run then
			push(ctx, player, run)
		end
	end)
	ctx.tally(player, "basementVisits", 1)
	return CFrame.new(Plan.ARRIVAL_AT) * CFrame.Angles(0, math.pi, 0), nil
end

function Basement.leave(_ctx: Types.Ctx, player: Player, why: string)
	local run = runs[player]
	if run then
		note(player, "Basement left", { stage = run.checkpoint, why = why, done = run.done })
	end
	runs[player] = nil
	player:SetAttribute("BasementVariant", nil)
end

function Basement.step(ctx: Types.Ctx, _dt: number)
	if not built then
		return
	end
	local t = Basement.clock()
	for player, run in runs do
		local at = ctx.at(player, ID)
		if at then
			judge(ctx, player, run, at, t)
		end
	end
	-- The course's turns, told to everyone down here: thirty seconds before, and as it comes.
	local period = math.floor(t / Plan.VARIANT_SECONDS)
	local left = Plan.variantEnds(t) - t
	local up = Basement.variantNow(t)
	if announced.period ~= period then
		local first = announced.period == -1
		announced.period = period
		if not first then
			for player, run in runs do
				local var = Plan.Variants[up]
				ctx.send(player, { op = "course", now = var.name, line = var.line, keeps = if run.started and not run.done then (Plan.Variants[run.variant] or Plan.Variants[1]).name else nil })
				push(ctx, player, run)
			end
		end
	elseif left <= 30 and announced.warned ~= period then
		announced.warned = period
		local nextVar = Plan.Variants[up % #Plan.Variants + 1]
		for player in runs do
			ctx.send(player, { op = "course", soon = nextVar.name, line = nextVar.line, seconds = math.floor(left + 0.5) })
		end
	end
	if os.clock() - lastRefresh > (tonumber(cfg(ctx).boardSeconds) or 120) then
		lastRefresh = os.clock()
		task.spawn(function()
			Basement.refreshBoards(ctx)
		end)
	end
end

-- Uses `need` skips held, all of them or none.
local function useSkips(player: Player, need: number): boolean
	if Basement.skipsHeld(player) < need then
		return false
	end
	for _ = 1, need do
		if not Basement.useSkip(player) then
			return false
		end
	end
	return true
end

-- Moves a guest one checkpoint on (skips held or Gems). Never onto the Treasury.
local function skip(ctx: Types.Ctx, player: Player, run: Run, how: string): { [string]: any }
	local n = run.checkpoint + 1
	run.assisted = true
	run.touching = {}
	run.lastAt, run.lastTv = nil, nil
	run.grace = os.clock() + 2
	ctx.teleport(player, checkpointFrame(n))
	reach(ctx, player, run, n, true)
	ctx.tally(player, "basementSkips", 1)
	return { ok = true, checkpoint = n, how = how }
end

-- A skip that arrived by receipt for a guest in the Basement: used at once (set as the purchase
-- system's hook by Main).
-- (Not used: false, and for a guest in the Basement who holds too few for this stage, a line
-- saying how many it takes.)
function Basement.useHeldSkip(ctx: Types.Ctx, player: Player): (boolean, string?)
	local run = runs[player]
	if not run or run.done or run.checkpoint + 1 >= Plan.STAGES then
		return false, nil
	end
	local stage = run.checkpoint + 1
	local need = Plan.skipsNeeded(stage)
	if not useSkips(player, need) then
		local held = Basement.skipsHeld(player)
		return false, string.format("Kept. Stage %d takes %d skips, and you hold %d.", stage, need, held)
	end
	skip(ctx, player, run, "held")
	return true, nil
end

function Basement.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	if not data then
		return {}
	end
	local p = page(ctx, data)
	local out: { [string]: any } = {
		best = p.best,
		weekBest = p.weekBest,
		clears = p.clears,
		deepest = p.deepest,
		skips = Basement.skipsHeld(player),
		skipGems = skipGems(ctx, 1),
		skipNeed = Plan.skipsNeeded(1),
		skipOnSale = Basement.skipOnSale(),
	}
	local run = runs[player]
	if run then
		out.run = summary(ctx, player, run)
	end
	return out
end

-- Its card in the Maison Directory: always open; the deepest stage reached, clears, the best time.
function Basement.directory(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	if not data then
		return { open = true, stages = Plan.STAGES }
	end
	local p = page(ctx, data)
	local up = Plan.Variants[Basement.variantNow(Basement.clock())]
	return { open = true, stages = Plan.STAGES, deepest = p.deepest, clears = p.clears, bestTime = p.best, course = up.name, secrets = (secretsFound(p)), secretsOf = #Plan.Secrets }
end

---------------------------------------------------------------------------------------------------
-- (Build 105) Basement Push: a prepaid play (server/Purchases/Mischief, 19 Robux each). Pressed
-- near another guest in the Basement, it shoves them away from you (their own screen gives the
-- shove: a guest's character moves on their own screen). A fall only ever sends them back to their
-- checkpoint, as any fall does: nothing they've reached is lost. Spent only when it lands: they
-- must be in reach and not shoved a moment ago (a grace each time); there's a pause between your
-- own. With none held, Roblox's window offers one.
---------------------------------------------------------------------------------------------------
Basement.mischief = {
	held = function(_player: Player): number
		return 0
	end,
	spend = function(_player: Player): boolean
		return false
	end,
	onSale = function(): boolean
		return false
	end,
	offer = function(_player: Player): (boolean, string?)
		return false, "Basement Push isn't on sale yet."
	end,
}
Basement.PUSH = { reach = 12, cooldown = 8, safe = 25, power = 55, lift = 28 }
local lastPush: { [Player]: number } = {}
local pushedAt: { [Player]: number } = {}

function Basement.push(ctx: Types.Ctx, player: Player, victimId: number): { [string]: any }
	if not runs[player] or ctx.inside(player) ~= ID then
		return { ok = false, why = "Basement Push works in the Maison Basement." }
	end
	local victim = Players:GetPlayerByUserId(victimId)
	if not victim or victim == player or not runs[victim] or ctx.inside(victim) ~= ID then
		return { ok = false, why = "They aren't in the Basement." }
	end
	local now = os.clock()
	local safe = pushedAt[victim]
	if safe and now - safe < Basement.PUSH.safe then
		return { ok = false, why = string.format("%s was pushed a moment ago: safe for %d more seconds.", victim.DisplayName, math.ceil(Basement.PUSH.safe - (now - safe))) }
	end
	local last = lastPush[player]
	if last and now - last < Basement.PUSH.cooldown then
		return { ok = false, why = string.format("Catch your breath: %d seconds.", math.ceil(Basement.PUSH.cooldown - (now - last))) }
	end
	local a, b = ctx.rootOf(player), ctx.rootOf(victim)
	if not a or not b then
		return { ok = false, why = "Not just now." }
	end
	local gap = b.CFrame.Position - a.CFrame.Position
	if gap.Magnitude > Basement.PUSH.reach then
		return { ok = false, why = "Get closer: within a few steps of them." }
	end
	if Basement.mischief.held(player) <= 0 then
		if not Basement.mischief.onSale() then
			return { ok = false, why = "Basement Push isn't on sale yet." }
		end
		local opened, why = Basement.mischief.offer(player)
		return { ok = false, prompted = opened, why = if opened then nil else why }
	end
	if not Basement.mischief.spend(player) then
		return { ok = false, why = "That couldn't be used just now. Nothing was taken." }
	end
	local flat = Vector3.new(gap.X, 0, gap.Z)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else a.CFrame.LookVector
	lastPush[player] = now
	pushedAt[victim] = now
	ctx.send(victim, { op = "pushed", by = player.DisplayName, x = dir.X * Basement.PUSH.power, y = Basement.PUSH.lift, z = dir.Z * Basement.PUSH.power })
	ctx.send(player, { op = "notice", title = "Basement Push", line = "Shoved " .. victim.DisplayName .. "." })
	ctx.tally(player, "basementPush", 1)
	return { ok = true }
end

function Basement.ask(ctx: Types.Ctx, player: Player, r: { [string]: unknown }): any
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	if r.act == "push" then
		local id = tonumber(r.n)
		if not id or id ~= math.floor(id) then
			return { ok = false, why = "Not that." }
		end
		return Basement.push(ctx, player, id)
	end
	if r.act == "skip" then
		local run = runs[player]
		if not run or ctx.inside(player) ~= ID then
			return { ok = false, why = "You're not in the Basement." }
		end
		if run.done then
			return { ok = false, why = "You've reached the Treasury." }
		end
		if run.checkpoint + 1 >= Plan.STAGES then
			return { ok = false, why = "The last stage is yours to run: the Treasury can't be skipped to." }
		end
		local how = r.what
		-- (The price is this stage's, worked out here: the deeper the stage, the more it costs.)
		local stage = run.checkpoint + 1
		if how == "gems" then
			local price = skipGems(ctx, stage)
			if not ctx.spend(player, 0, price, "basement_skip") then
				return { ok = false, short = "Gems", why = string.format("That's %d Gems.", price) }
			end
			return skip(ctx, player, run, "gems")
		end
		-- Skips held (enough for this stage), or the purchase window for one more.
		local need = Plan.skipsNeeded(stage)
		if useSkips(player, need) then
			return skip(ctx, player, run, "held")
		end
		local ok, why = Basement.offerSkip(player)
		return { ok = false, prompted = ok, need = need, held = Basement.skipsHeld(player), why = if ok then nil else why }
	elseif r.act == "boards" then
		local which = if r.what == "week" or r.what == "friends" then r.what else "all"
		local list: { any } = {}
		if which == "friends" then
			for _, entry in boards.all do
				if entry.userId == player.UserId or Basement.friends(player, entry.userId) then
					table.insert(list, entry)
				end
			end
		else
			list = boards[which] or {}
		end
		local top = {}
		for k = 1, math.min(25, #list) do
			table.insert(top, list[k])
		end
		local p = page(ctx, data)
		return { ok = true, which = which, entries = top, available = boards.available, best = p.best, weekBest = p.weekBest }
	end
	return { ok = false, why = "That isn't something the house does." }
end

-- For tests.
Basement.runs = runs
Basement.origin = function(): Vector3
	return origin
end
Basement.page = page
Basement.boards = boards
Basement.CREDIT = CREDIT
Basement.built = function(): BasementBuild.Built?
	return built
end

return Basement

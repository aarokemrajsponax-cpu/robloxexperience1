--!strict
-- The Maison Basement on the server: the course (BasementBuild), every guest's run, and the boards.
-- Everything is judged here from where the server sees each guest and the plan's own sums of the
-- machinery (shared/Basement), by the server's clock.
--
--   Checkpoints   reached in order, standing on each one's pad: the first time in a run, a little
--                 Gilt; at the end of each of the four parts, its purse to the Estate. Leave by a lift
--                 or the arch at any time: everything already paid is yours.
--   Falling       into a pit, or caught in steam, a laser or the valve's sweep (a moment's touch, so a
--                 screen a little behind the server is never sent back for nothing): back to the last
--                 checkpoint, and a few seconds' grace.
--   The Treasury  the last checkpoint: the chest pays its Gems (more the first time each day), the
--                 last purse, the brainrot Topo Tesoriere the first time ever, and the run's time.
--   Times         from leaving the start to the Treasury. The best is kept, and goes to the boards
--                 (all time and this week); a run with a skipped stage is never timed for them.
--   Skips         one stage on, for a skip held (Robux, ProductConfig "basementSkip") or for Gems.
--                 Never the Treasury itself, never a stage's Gilt; the run is marked as skipped.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Names = require(ReplicatedStorage.Shared.Names)
local Plan = require(ReplicatedStorage.Shared.Basement)
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
}

local origin = Vector3.zero
local built: BasementBuild.Built? = nil
local runs: { [Player]: Run } = {}
local byStage: { [number]: { { i: number, e: Plan.El } } } = {}
local boards: { [string]: any } = { all = {}, week = {}, available = false }
local names: { [number]: string } = {}
local lastRefresh = -math.huge

local function cfg(ctx: Types.Ctx): { [string]: any }
	return ctx.cfg(ID)
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
local function summary(ctx: Types.Ctx, player: Player, run: Run): { [string]: any }
	local data = ctx.data(player)
	local p = if data then page(ctx, data) else nil
	local next = math.min(Plan.STAGES, run.checkpoint + 1)
	return {
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
		skipGems = tonumber(cfg(ctx).skipGems) or 25,
		skipOnSale = Basement.skipOnSale(),
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
	run.falls += 1
	run.grace = os.clock() + (tonumber(cfg(ctx).fallGrace) or 1.5)
	run.touching = {}
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
	local gems = ctx.gems(player, if firstToday then (tonumber(c.chestGems) or 10) else (tonumber(c.chestGemsAgain) or 3), "The Maison Basement", ID)
	local first = not p.firstClear
	local brainrot = nil
	if first then
		p.firstClear = true
		if ctx.curio(player, "topoTesoriere", "The Maison Basement") then
			brainrot = "topoTesoriere"
		end
	end
	local record, weekRecord = false, false
	if seconds and not run.assisted then
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
	ctx.send(player, {
		op = "treasury",
		seconds = seconds,
		timed = seconds ~= nil and not run.assisted,
		record = record,
		weekRecord = weekRecord,
		best = p.best,
		gems = gems,
		brainrot = brainrot,
		first = first,
		falls = run.falls,
	})
	if first then
		ctx.herald(player, { kind = "basement", title = "The Basement beaten", line = "reached the Treasury at the foot of the Maison Basement", glyph = "🗝️" })
	elseif seconds and not run.assisted and seconds <= (tonumber(c.heraldUnder) or 180) and record then
		ctx.herald(player, { kind = "basement", title = "A Basement record", line = "ran the Maison Basement in " .. Plan.clock(seconds), glyph = "⏱️" })
	end
	push(ctx, player, run)
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
			gilt = ctx.gilt(player, 15 + 5 * n, "The Maison Basement")
		end
	end
	local zone = Plan.Zones[Plan.zoneOf(n)]
	local purse = 0
	if zone.to == n then
		purse = zone.purse
		ctx.estate(player, purse, "The Maison Basement")
	end
	ctx.tally(player, "basementCheckpoints", 1)
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

local function judge(ctx: Types.Ctx, player: Player, run: Run, at: Vector3, t: number)
	if run.done then
		return
	end
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
	if os.clock() < run.grace then
		return
	end
	-- What can send them back: in the stage they're on, and the one behind.
	for _, n in { run.checkpoint + 1, run.checkpoint } do
		local list = byStage[n]
		if not list then
			continue
		end
		for _, item in list do
			local e, i = item.e, item.i
			local hit = false
			if e.kind == "pit" then
				if Plan.inBox(at, e.at + Vector3.new(0, 3, 0), e.size + Vector3.new(0, 6, 0), 0) then
					fall(ctx, player, run, "fall")
					return
				end
			elseif e.kind == "steam" or e.kind == "laser" then
				-- (Burning a moment already, so a screen a beat behind isn't caught by its start.)
				hit = Plan.burning(e, t) and Plan.burning(e, t - 0.15) and bodyIn(at, e.at, e.size)
			elseif e.kind == "spinner" then
				hit = bodyIn(at, e.at, e.size, Plan.spinnerFrame(e, t))
			end
			if hit then
				local k = (run.touching[i] or 0) + 1
				run.touching[i] = k
				if k >= 2 then
					fall(ctx, player, run, if e.kind == "spinner" then "valve" else e.kind)
					return
				end
			else
				run.touching[i] = nil
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
	runs[player] = { checkpoint = 0, started = nil, assisted = false, paid = {}, falls = 0, grace = os.clock() + 2, touching = {}, done = false }
	task.defer(function()
		local run = runs[player]
		if run then
			push(ctx, player, run)
		end
	end)
	ctx.tally(player, "basementVisits", 1)
	return CFrame.new(Plan.ARRIVAL_AT) * CFrame.Angles(0, math.pi, 0), nil
end

function Basement.leave(_ctx: Types.Ctx, player: Player, _why: string)
	runs[player] = nil
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
	if os.clock() - lastRefresh > (tonumber(cfg(ctx).boardSeconds) or 120) then
		lastRefresh = os.clock()
		task.spawn(function()
			Basement.refreshBoards(ctx)
		end)
	end
end

-- Moves a guest one checkpoint on (a skip held or bought for Gems). Never onto the Treasury.
local function skip(ctx: Types.Ctx, player: Player, run: Run, how: string): { [string]: any }
	local n = run.checkpoint + 1
	run.assisted = true
	run.touching = {}
	run.grace = os.clock() + 2
	ctx.teleport(player, checkpointFrame(n))
	reach(ctx, player, run, n, true)
	ctx.tally(player, "basementSkips", 1)
	return { ok = true, checkpoint = n, how = how }
end

-- A skip that arrived by receipt for a guest in the Basement: used at once (set as the purchase
-- system's hook by Main).
function Basement.useHeldSkip(ctx: Types.Ctx, player: Player): boolean
	local run = runs[player]
	if not run or run.done or run.checkpoint + 1 >= Plan.STAGES then
		return false
	end
	if not Basement.useSkip(player) then
		return false
	end
	skip(ctx, player, run, "held")
	return true
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
		skipGems = tonumber(cfg(ctx).skipGems) or 25,
		skipOnSale = Basement.skipOnSale(),
	}
	local run = runs[player]
	if run then
		out.run = summary(ctx, player, run)
	end
	return out
end

function Basement.ask(ctx: Types.Ctx, player: Player, r: { [string]: unknown }): any
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
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
		if how == "gems" then
			local price = tonumber(cfg(ctx).skipGems) or 25
			if not ctx.spend(player, 0, price, "basement_skip") then
				return { ok = false, why = string.format("That's %d Gems.", price) }
			end
			return skip(ctx, player, run, "gems")
		end
		-- A skip held, or the purchase window.
		if Basement.skipsHeld(player) > 0 and Basement.useSkip(player) then
			return skip(ctx, player, run, "held")
		end
		local ok, why = Basement.offerSkip(player)
		return { ok = false, prompted = ok, why = if ok then nil else why }
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

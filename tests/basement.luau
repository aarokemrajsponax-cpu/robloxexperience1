--!nocheck
-- The Maison Basement on the server (server/Attractions/Basement, BasementBuild, World/Lobbies),
-- under Lune on a fake clock, in the house's test harness: a course that can be run (every jump
-- within a guest's reach, a pit under every stage), going down from the Basement Stair, checkpoints
-- in order (and only in order), the Gilt at each and each part's purse, falling and the machinery
-- sending you back (never on a moment's brush), the Treasury (its Gilt, the brainrot, the time,
-- the boards), skipping a stage (never timed, never the Treasury), and the lifts home.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/basement.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles, broadcasts = H.module, H.profiles, H.broadcasts
local Remotes, Config = H.Remotes, H.Config

H.stubs["ServerScriptService.Server.Staff.Rig"] = function()
	return {
		build = function()
			error("no rigs under Lune")
		end,
		look = function()
			return {}
		end,
	}
end

local Layout = module("ReplicatedStorage", "Shared", "Layout")
local AttractionList = module("ReplicatedStorage", "Shared", "Attractions")
local Plan = module("ReplicatedStorage", "Shared", "Basement")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local BadgeBook = module("ReplicatedStorage", "Shared", "BadgeBook")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Game = module("ServerScriptService", "Server", "Attractions", "Basement")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Fortune = module("ServerScriptService", "Server", "Fortune")
local Herald = module("ServerScriptService", "Server", "Herald")
local C = Config.data.Attractions.basement

-- The server's clock: the tests move it.
local T = 1000
Game.clock = function()
	return T
end
-- Skips held: a count the tests set.
local held = {}
local offered = 0
Game.skipsHeld = function(p)
	return held[p] or 0
end
Game.useSkip = function(p)
	if (held[p] or 0) > 0 then
		held[p] -= 1
		return true
	end
	return false
end
Game.offerSkip = function()
	offered += 1
	return true
end
Game.skipOnSale = function()
	return true
end
Game.friends = function(_, userId)
	return userId == 777
end
-- (The House Course for the tests of the course itself; section 8 lets it turn over.)
Game.variantNow = function()
	return 1
end

local awards, tallies = {}, {}
Attractions.award = function(p, key)
	table.insert(awards, { p = p, key = key })
end
Attractions.tally = function(p, stat, n)
	tallies[p.UserId .. ":" .. stat] = (tallies[p.UserId .. ":" .. stat] or 0) + n
end

local workspace = H.game:GetService("Workspace")
Lobbies.build(workspace)
local ada = H.guest("Ada", 601)
local bo = H.guest("Bo", 602)
run(Herald.start)
run(Attractions.start)
local O = Game.origin()

local ask = Remotes.funcs.AttractionAsk.OnServerInvoke
local function askAs(g, request)
	advance(0.4)
	local r
	run(function()
		r = ask(g, request)
	end)
	return r
end
local function last(g, op)
	for i = #g.inbox, 1, -1 do
		if g.inbox[i].op == op then
			return g.inbox[i]
		end
	end
	return nil
end
local function count(g, op)
	local n = 0
	for _, m in g.inbox do
		if m.op == op then
			n += 1
		end
	end
	return n
end
local function data(g)
	return profiles[g].Data
end
local function stand(g, at)
	g.Character = g.body
	g.root.CFrame = CFrame.new(at + Vector3.new(0, 3, 0))
end
local function standIn(g, v)
	stand(g, O + v)
end
local function steps(n)
	for _ = 1, n do
		advance(0.1)
	end
end
-- On checkpoint n's pad (its middle).
local function onCheckpoint(g, n)
	standIn(g, Plan.Checkpoints[n].at)
	steps(1)
end

---------------------------------------------------------------------------------------------------
-- 1. The course can be run
---------------------------------------------------------------------------------------------------
check("sixteen stages in four parts, a checkpoint after each", Plan.STAGES == 16 and #Plan.Zones == 4 and Plan.Checkpoints[0] ~= nil and Plan.Checkpoints[16] ~= nil)
do
	local covered = {}
	for _, z in Plan.Zones do
		for n = z.from, z.to do
			covered[n] = (covered[n] or 0) + 1
		end
	end
	local ok = true
	for n = 1, 16 do
		if covered[n] ~= 1 then
			ok = false
		end
	end
	check("every stage is in exactly one part", ok)
	check("each part's purse is bigger than the last", Plan.Zones[1].purse < Plan.Zones[2].purse and Plan.Zones[2].purse < Plan.Zones[3].purse and Plan.Zones[3].purse < Plan.Zones[4].purse)
	local downhill = true
	for n = 1, 16 do
		if Plan.Checkpoints[n].at.Y > Plan.Checkpoints[n - 1].at.Y + 0.01 then
			downhill = false
		end
	end
	check("the course only goes down, checkpoint to checkpoint", downhill)
	check("the Treasury is far below the start", Plan.Checkpoints[16].at.Y < -30)
	-- Every jump within reach: from each thing to stand on to the next (in the order of the run),
	-- the gap across is at most 5 studs and the step up at most 2 (the truss is climbed).
	local worst, worstWhere, rise, riseWhere = 0, "", 0, ""
	for n = 1, 16 do
		local list = { { at = Plan.Checkpoints[n - 1].at - Vector3.new(0, 0.5, 0), size = Vector3.new(12, 1, 8), kind = "pad" } }
		for _, e in Plan.Elements do
			if e.stage == n and e.variant == nil and (e.kind == "pad" or e.kind == "beam" or e.kind == "vanish" or e.kind == "mover" or e.kind == "conveyor") then
				table.insert(list, e)
			end
		end
		table.insert(list, { at = Plan.Checkpoints[n].at - Vector3.new(0, 0.5, 0), size = Plan.Checkpoints[n].size * Vector3.new(1, 0, 1) + Vector3.new(0, 1, 0), kind = "pad" })
		for k = 1, #list - 1 do
			local a, b = list[k], list[k + 1]
			-- (A mover's x runs between its two ends: across from wherever it comes nearest.)
			local function span(e, axis)
				local lo = e.at[axis] - e.size[axis] / 2
				local hi = e.at[axis] + e.size[axis] / 2
				if e.kind == "mover" and e.b then
					lo = math.min(lo, e.b[axis] - e.size[axis] / 2)
					hi = math.max(hi, e.b[axis] + e.size[axis] / 2)
				end
				return lo, hi
			end
			local ax0, ax1 = span(a, "X")
			local bx0, bx1 = span(b, "X")
			local az0, az1 = span(a, "Z")
			local bz0, bz1 = span(b, "Z")
			local gx = math.max(0, math.max(ax0, bx0) - math.min(ax1, bx1))
			local gz = math.max(0, math.max(az0, bz0) - math.min(az1, bz1))
			local gap = math.sqrt(gx * gx + gz * gz)
			local up = (b.at.Y + b.size.Y / 2) - (a.at.Y + a.size.Y / 2)
			if gap > worst then
				worst, worstWhere = gap, string.format("stage %d, step %d", n, k)
			end
			if up > rise and n ~= 10 then
				rise, riseWhere = up, string.format("stage %d, step %d", n, k)
			end
		end
	end
	check("no gap anywhere wider than 5 studs (a guest jumps about 8 at a walk)", worst <= 5.01, string.format("%.2f at %s", worst, worstWhere))
	-- (Each course's own ledges: a short hop from the way through, or the launch pad's throw.)
	local farLedge = ""
	for _, e in Plan.Elements do
		if e.variant and e.kind == "pad" then
			local best, bestUp = math.huge, 0
			for _, f in Plan.Elements do
				if f.stage == e.stage and f.variant == nil and (f.kind == "pad" or f.kind == "beam" or f.kind == "vanish" or f.kind == "mover" or f.kind == "conveyor") then
					local function span(x, axis)
						local lo, hi = x.at[axis] - x.size[axis] / 2, x.at[axis] + x.size[axis] / 2
						if x.kind == "mover" and x.b then
							lo, hi = math.min(lo, x.b[axis] - x.size[axis] / 2), math.max(hi, x.b[axis] + x.size[axis] / 2)
						end
						return lo, hi
					end
					local a0, a1 = span(e, "X")
					local b0, b1 = span(f, "X")
					local c0, c1 = span(e, "Z")
					local d0, d1 = span(f, "Z")
					local gx = math.max(0, math.max(a0, b0) - math.min(a1, b1))
					local gz = math.max(0, math.max(c0, d0) - math.min(c1, d1))
					local gap = math.sqrt(gx * gx + gz * gz)
					if gap < best then
						best, bestUp = gap, (e.at.Y + e.size.Y / 2) - (f.at.Y + f.size.Y / 2)
					end
				end
			end
			local thrown = false
			for _, b in Plan.Elements do
				if b.kind == "bouncer" and b.variant == e.variant and b.stage == e.stage then
					local apex = (b.bounce or 0) ^ 2 / (2 * 196.2)
					thrown = (Vector3.new(e.at.X, 0, e.at.Z) - Vector3.new(b.at.X, 0, b.at.Z)).Magnitude < 6 and (e.at.Y - b.at.Y) < apex
				end
			end
			if not thrown and (best > 3 or bestUp > 1) then
				farLedge ..= string.format("stage %d (%.1f across, %.1f up) ", e.stage, best, bestUp)
			end
		end
	end
	check("each course's own ledges are a short hop from the way through (or the launch pad throws you there)", farLedge == "", farLedge)
	check("no step up higher than 2 studs (a guest jumps about 3)", rise <= 2.01, string.format("%.2f at %s", rise, riseWhere))
	local truss = nil
	for _, e in Plan.Elements do
		if e.kind == "truss" then
			truss = e
		end
	end
	check("the one climb is up a truss", truss ~= nil and truss.stage == 10)
	local under = true
	for n = 1, 16 do
		local pit = Plan.Pits[n]
		for _, e in Plan.Elements do
			if e.stage == n and e.kind ~= "pit" and e.at.Y - e.size.Y / 2 < pit.at.Y + pit.size.Y / 2 + 4 then
				under = false
			end
		end
	end
	check("a pit under every stage, well below everything in it", under)
	local inside = true
	local b = AttractionList.BOUNDS.basement
	for _, e in Plan.Elements do
		local p = e.at
		if p.X < b.min.X or p.X > b.max.X or p.Y < b.min.Y or p.Y > b.max.Y or p.Z < b.min.Z or p.Z > b.max.Z then
			inside = false
		end
	end
	check("the whole course is inside the Basement's own place", inside)
	check("the Basement's place is nowhere near the Maison, nor Steal a Luxe", AttractionList.areaAt(Layout.Foyer.spawn.Position) == nil and AttractionList.areaAt(O + Vector3.new(0, 3, 300)) == "basement" and AttractionList.areaAt(AttractionList.origin("luxe") + Vector3.new(0, 3, 0)) == "luxe")
	-- The machinery's sums.
	local tile
	for _, e in Plan.Elements do
		if e.kind == "vanish" then
			tile = tile or e
		end
	end
	local solid, gone = 0, 0
	for k = 0, 99 do
		if Plan.solid(tile, k * tile.period / 100) then
			solid += 1
		else
			gone += 1
		end
	end
	check("a sinking tile is there most of the time, and gone for a while", solid > 50 and gone > 25, solid .. "/" .. gone)
	local m
	for _, e in Plan.Elements do
		if e.kind == "mover" then
			m = m or e
		end
	end
	local a0 = Plan.moverAt(m, -(m.phase or 0) * m.period)
	local a1 = Plan.moverAt(m, (0.5 - (m.phase or 0)) * m.period)
	check("a piston runs from one end to the other and back", (a0 - m.at).Magnitude < 1e-3 and (a1 - m.b).Magnitude < 1e-3)
	check("a time reads as minutes, seconds and hundredths", Plan.clock(185.456) == "3:05.46" and Plan.clock(59.999) == "1:00.00")
	check("Topo Tesoriere is a real brainrot", CurioList.byId.topoTesoriere ~= nil)
	check("the Basement's badges are in the Badge Book", BadgeBook.byKey.basementClear ~= nil and BadgeBook.byKey.basementQuick ~= nil and BadgeBook.byKey.crownJewel ~= nil)
end

---------------------------------------------------------------------------------------------------
-- 2. What's built
---------------------------------------------------------------------------------------------------
do
	local built = Game.built()
	check("the Basement is built at its own place", built ~= nil and workspace.Attractions:FindFirstChild("MaisonBasement") ~= nil)
	local n = 0
	for _ in built.checkpoints do
		n += 1
	end
	check("seventeen checkpoints (the start, fifteen, the Treasury)", n == 17, n)
	check("a lift up at the end of the first three parts", built.lifts[4] ~= nil and built.lifts[8] ~= nil and built.lifts[12] ~= nil and built.lifts[16] == nil)
	check("the Treasury's chest", built.chest ~= nil)
	local kinds = {}
	for _, tag in { "BasementMover", "BasementVanish", "BasementSteam", "BasementLaser", "BasementSpinner" } do
		kinds[tag] = #(H.tagged[tag] or {})
	end
	check("its machinery is tagged for every screen to move: pistons, tiles, steam, lasers, valves", kinds.BasementMover == 4 and kinds.BasementVanish == 12 and kinds.BasementSteam == 5 and kinds.BasementLaser == 4 and kinds.BasementSpinner == 4, kinds)
	check("and the courses' own: three crushers, a launch pad, eight secrets, every edge's glow", #(H.tagged.BasementCrusher or {}) == 3 and #(H.tagged.BasementBouncer or {}) == 1 and #(H.tagged.BasementSecret or {}) == 8 and #(H.tagged.BasementGuide or {}) > 60)
	local versions = H.tagged.BasementVariant or {}
	local each = {}
	for _, m in versions do
		each[m:GetAttribute("Variant")] = true
	end
	check("each course's own pieces are kept together, for each screen to show only its run's", #versions == 4 and each[1] and each[2] and each[3] and each[4])
	local belts = 0
	for _, d in workspace.Attractions.MaisonBasement:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Belt" and d.AssemblyLinearVelocity.Magnitude > 5 then
			belts += 1
		end
	end
	check("its belts really run", belts == 2, belts)
	local trusses = 0
	for _, d in workspace.Attractions.MaisonBasement:GetDescendants() do
		if d:IsA("TrussPart") then
			trusses += 1
		end
	end
	check("a truss to climb", trusses == 1)
	local kindsHere = {}
	for _, p in H.tagged.AttractionPrompt or {} do
		kindsHere[p:GetAttribute("Kind") .. ":" .. p:GetAttribute("Attraction")] = p
	end
	local veil = kindsHere["go:basement"] and kindsHere["go:basement"].Parent
	check("the Basement Stair, in the Obsidian Room: the way down", veil ~= nil and Layout.zoneAt(veil.CFrame.Position) == "obsidian")
	check("...and the best times at its lectern", kindsHere["panel:basement"] ~= nil)
end

---------------------------------------------------------------------------------------------------
-- 3. Down the Basement
---------------------------------------------------------------------------------------------------
data(ada).gilt = 0
data(ada).gems = 0
stand(ada, Layout.Velvet.arrival)
local r = askAs(ada, { op = "go", id = "basement" })
check("from another room, the way down is refused: it's in the Basement Stair", r.ok == false and r.why == "Its entrance is in The Basement Stair, off the Foyer.", r.why)
stand(ada, Layout.Obsidian.arrival)
r = askAs(ada, { op = "go", id = "basement" })
check("from the Basement Stair, down they go", r.ok == true and Attractions.inside(ada) == "basement" and ada:GetAttribute("Attraction") == "basement", r.why)
check("they arrive on the start", Plan.checkpointAt(ada.root.CFrame.Position - O) == 0)
steps(2)
local hud = last(ada, "basement")
check("their screen is told the stage, its part and that the clock hasn't started", hud ~= nil and hud.stage == 1 and hud.stageName == "The Cellar Steps" and hud.zone == "The Wine Cellar" and hud.started == nil)
-- Off the start: the clock starts.
standIn(ada, Vector3.new(0, -1, 10.5))
T = 1000
steps(1)
check("stepping off the start starts the clock", Game.runs[ada].started == 1000)
-- Out of order: nothing.
onCheckpoint(ada, 3)
check("a checkpoint out of order counts for nothing", Game.runs[ada].checkpoint == 0)
-- In order.
local giltWas = data(ada).gilt
onCheckpoint(ada, 1)
local cp = last(ada, "checkpoint")
check("the next checkpoint, in order: reached", Game.runs[ada].checkpoint == 1 and cp ~= nil and cp.n == 1)
check("...with a little Gilt", cp.gilt > 0 and data(ada).gilt == giltWas + cp.gilt, cp.gilt)
steps(3)
check("standing on it again pays nothing more", count(ada, "checkpoint") == 1)
local estateWas = Fortune.page(data(ada)).estate
for n = 2, 4 do
	onCheckpoint(ada, n)
end
check("the end of the Wine Cellar: its purse to the Estate", last(ada, "checkpoint").n == 4 and last(ada, "checkpoint").purse == Plan.Zones[1].purse and Fortune.page(data(ada)).estate == estateWas + Plan.Zones[1].purse)

-- Falling into a pit: back to the checkpoint.
steps(25) -- (past the moment's grace after coming in)
local pit = Plan.Pits[5]
standIn(ada, pit.at + Vector3.new(0, pit.size.Y / 2, 0))
steps(1)
local fell = last(ada, "fell")
check("into the pit: back at the last checkpoint", fell ~= nil and fell.why == "fall" and fell.checkpoint == 4 and Plan.checkpointAt(ada.root.CFrame.Position - O - Vector3.new(0, 3, 0)) == 4)
check("...and the run goes on from there", Game.runs[ada].checkpoint == 4 and Game.runs[ada].falls == 1)
-- Steam: only while it burns, and only for more than a moment.
onCheckpoint(ada, 5) -- (cheating the stage for the test: it's the next in order)
check("(on to the Pipes' end)", Game.runs[ada].checkpoint == 5)
steps(20) -- (past the grace after the fall)
local steamEl
for _, e in Plan.Elements do
	if e.kind == "steam" and e.stage == 8 then
		steamEl = e
	end
end
for n = 6, 7 do
	onCheckpoint(ada, n)
end
check("(at the Great Valve's end)", Game.runs[ada].checkpoint == 7)
steps(20)
local fallsWas = Game.runs[ada].falls
-- A moment when it isn't burning.
local period = steamEl.period
local base = math.ceil(T / period) * period - steamEl.phase * period -- (the start of a cycle)
T = base + period * (steamEl.on + 0.1)
standIn(ada, steamEl.at - Vector3.new(0, steamEl.size.Y / 2 - 0.2, 0))
steps(3)
check("over a vent while it isn't burning: nothing", Game.runs[ada].falls == fallsWas)
T = base + period + 0.2
steps(1)
check("a moment's brush with the steam: nothing yet", Game.runs[ada].falls == fallsWas)
T += 0.1
steps(1)
check("caught in it: back to the checkpoint", Game.runs[ada].falls == fallsWas + 1 and last(ada, "fell").why == "steam")
steps(1)
check("...and for a moment after, nothing sends them back again", Game.runs[ada].falls == fallsWas + 1)
-- The valve's bar.
steps(20)
local bar
for _, e in Plan.Elements do
	if e.kind == "spinner" and e.stage == 7 and e.variant == nil then
		bar = e
	end
end
-- (Back to the valve's stage: their checkpoint is 7, so the stage behind is judged too.)
fallsWas = Game.runs[ada].falls
local frame = Plan.spinnerFrame(bar, T)
standIn(ada, (frame * CFrame.new(bar.size.X / 2 - 1, 0, 0)).Position - Vector3.new(0, 3, 0))
steps(2)
check("swept by the valve's bar: back to the checkpoint", Game.runs[ada].falls == fallsWas + 1 and last(ada, "fell").why == "valve")

-- On down: the parts' purses, the lasers' hall, to the Treasury.
steps(20)
for n = 8, 15 do
	onCheckpoint(ada, n)
end
check("(at the Falling Coins' end)", Game.runs[ada].checkpoint == 15)
check("each part's purse paid at its end", Fortune.page(data(ada)).estate == estateWas + Plan.Zones[1].purse + Plan.Zones[2].purse + Plan.Zones[3].purse)
local gemsWas, giltWas = data(ada).gems, data(ada).gilt
-- (The day's soft cap set aside, to see the chest's own amount.)
data(ada).giltDay.earned = 0
T = 1000 + 205.5
onCheckpoint(ada, 16)
local tr = last(ada, "treasury")
check("the Treasury: the run's time, from leaving the start", tr ~= nil and math.abs(tr.seconds - 205.5) < 1e-6 and tr.timed == true, tr and tr.seconds)
check("...the last purse", Fortune.page(data(ada)).estate == estateWas + Plan.Zones[1].purse + Plan.Zones[2].purse + Plan.Zones[3].purse + Plan.Zones[4].purse)
check("...the chest's Gilt, the first clear of the day", tr.chest == C.chestGilt and data(ada).gilt >= giltWas + C.chestGilt, tr.chest)
check("...and the chests after it are Gilt as everywhere in the house: under the day's soft cap", (function()
	local was = data(ada).gilt
	data(ada).giltDay.earned = 100000
	local paid = Attractions.ctx.gilt(ada, C.chestGilt, "test")
	data(ada).gilt = was
	return paid > 0 and paid < C.chestGilt
end)())
check("...and never a Gem: those come only from Robux", tr.gems == nil and data(ada).gems == gemsWas)
check("...Topo Tesoriere, the first time ever", tr.first == true and tr.brainrot == "topoTesoriere" and (data(ada).curios.items.topoTesoriere or 0) == 1)
check("...the badges: the Treasury, and under four minutes", (function()
	local got = {}
	for _, a in awards do
		if a.p == ada then
			got[a.key] = true
		end
	end
	return got.basementClear == true and got.basementQuick == true
end)())
check("...the best time kept", Game.page(Attractions.ctx, data(ada)).best == 205.5)
check("...and on the boards", Game.boards.all[1] ~= nil and Game.boards.all[1].userId == 601 and math.abs(Game.boards.all[1].score - 205.5) < 1e-6)
steps(80)
local told = false
for _, b in broadcasts do
	if b.remote == "Empire" and b.message.op == "feat" and b.message.kind == "basement" then
		told = true
	end
end
check("the first time down to the Treasury is told to the house", told)
check("the run is over: nothing more is judged", (function()
	local was = Game.runs[ada].falls
	standIn(ada, Plan.Pits[16].at + Vector3.new(0, 1, 0))
	steps(2)
	return Game.runs[ada].falls == was
end)())

---------------------------------------------------------------------------------------------------
-- 4. A second run: a slower time isn't a record; the day's second chest pays less
---------------------------------------------------------------------------------------------------
r = askAs(ada, { op = "home" })
check("home from the Treasury", r.ok == true and Attractions.inside(ada) == nil and Layout.zoneAt(ada.root.CFrame.Position) == "obsidian")
advance(3)
r = askAs(ada, { op = "go", id = "basement" })
check("(down again)", r.ok == true)
T = 5000
standIn(ada, Vector3.new(0, -1, 10.5))
steps(1)
for n = 1, 15 do
	onCheckpoint(ada, n)
end
T = 5000 + 300
gemsWas = data(ada).gems
data(ada).giltDay.earned = 0
onCheckpoint(ada, 16)
tr = last(ada, "treasury")
check("a slower run isn't a record, and the best stands", tr.record == false and Game.page(Attractions.ctx, data(ada)).best == 205.5)
check("the day's second chest pays its smaller Gilt (no Gems)", tr.chest == C.chestGiltAgain and data(ada).gems == gemsWas, tr.chest)
check("no second Topo Tesoriere", tr.brainrot == nil and (data(ada).curios.items.topoTesoriere or 0) == 1)

---------------------------------------------------------------------------------------------------
-- 5. Skipping a stage
---------------------------------------------------------------------------------------------------
advance(3)
askAs(ada, { op = "home" })
advance(3)
askAs(ada, { op = "go", id = "basement" })
T = 9000
standIn(ada, Vector3.new(0, -1, 10.5))
steps(1)
data(ada).gems = 10
giltWas = data(ada).gilt
r = askAs(ada, { op = "act", id = "basement", act = "skip", what = "gems" })
check("a skip for Gems without them is refused, with its price", r.ok == false and r.why == "That's " .. C.skipGems .. " Gems.", r.why)
data(ada).gems = C.skipGems + 3
r = askAs(ada, { op = "act", id = "basement", act = "skip", what = "gems" })
check("with them: on to the next checkpoint, for exactly its price", r.ok == true and Game.runs[ada].checkpoint == 1 and data(ada).gems == 3)
check("...the stage skipped pays nothing", data(ada).gilt == giltWas and last(ada, "checkpoint").skipped == true and last(ada, "checkpoint").gilt == 0)
check("...and the guest is moved there", Plan.checkpointAt(ada.root.CFrame.Position - O - Vector3.new(0, 3, 0)) == 1)
r = askAs(ada, { op = "act", id = "basement", act = "skip" })
check("with no skip held, the purchase window (never a skip given)", r.ok == false and r.prompted == true and offered == 1 and Game.runs[ada].checkpoint == 1)
held[ada] = 1
r = askAs(ada, { op = "act", id = "basement", act = "skip" })
check("a skip held is used", r.ok == true and Game.runs[ada].checkpoint == 2 and held[ada] == 0)
-- The deeper the stage, the more a skip costs.
check("the price rises with every stage: 25 Gems at the first, 15 more each stage after", Plan.skipGems(1) == C.skipGems and Plan.skipGems(2) == C.skipGems + C.skipGemsStep and Plan.skipGems(15) == C.skipGems + 14 * C.skipGemsStep and Plan.skipGems(15) == 235)
check("...and skips held: one in the first part, then two, three and four", Plan.skipsNeeded(1) == 1 and Plan.skipsNeeded(4) == 1 and Plan.skipsNeeded(5) == 2 and Plan.skipsNeeded(9) == 3 and Plan.skipsNeeded(13) == 4 and Plan.skipsNeeded(15) == 4)
check("the guest's screen is told this stage's price", last(ada, "basement").stage == 3 and last(ada, "basement").skipGems == Plan.skipGems(3) and last(ada, "basement").skipNeed == 1)
for n = 3, 8 do
	onCheckpoint(ada, n)
end
-- (Stage 9, in the third part: 145 Gems, or three skips.)
data(ada).gems = Plan.skipGems(9) - 1
r = askAs(ada, { op = "act", id = "basement", act = "skip", what = "gems" })
check("a deep stage for the first stage's price is refused, with its own price", r.ok == false and r.why == "That's 145 Gems." and Game.runs[ada].checkpoint == 8 and data(ada).gems == 144, r.why)
held[ada] = 2
offered = 0
r = askAs(ada, { op = "act", id = "basement", act = "skip" })
check("too few skips held for a deep stage: none used, the purchase window for one more", r.ok == false and r.prompted == true and r.need == 3 and r.held == 2 and held[ada] == 2 and offered == 1 and Game.runs[ada].checkpoint == 8, r)
local usedNow, kept = Game.useHeldSkip(Attractions.ctx, ada)
check("...and one arriving by receipt that still isn't enough is kept, saying how many it takes", usedNow == false and kept == "Kept. Stage 9 takes 3 skips, and you hold 2." and held[ada] == 2, kept)
held[ada] = 3
r = askAs(ada, { op = "act", id = "basement", act = "skip" })
check("with enough: all three used, one stage on", r.ok == true and Game.runs[ada].checkpoint == 9 and held[ada] == 0)
data(ada).gems = Plan.skipGems(10)
r = askAs(ada, { op = "act", id = "basement", act = "skip", what = "gems" })
check("...or Gems, for exactly that stage's price", r.ok == true and Game.runs[ada].checkpoint == 10 and data(ada).gems == 0)
for n = 11, 15 do
	onCheckpoint(ada, n)
end
held[ada] = 1
r = askAs(ada, { op = "act", id = "basement", act = "skip" })
check("the Treasury can never be skipped to", r.ok == false and Game.runs[ada].checkpoint == 15 and held[ada] == 1, r.why)
T = 9000 + 100
onCheckpoint(ada, 16)
tr = last(ada, "treasury")
check("a run with a skip isn't timed for the boards (even a fast one)", tr.timed == false and Game.page(Attractions.ctx, data(ada)).best == 205.5)
r = askAs(ada, { op = "act", id = "basement", act = "skip", what = "gems", price = 0 })
check("a screen can't name its own price", r.ok == false)
-- A skip that arrives by receipt while in the Basement is used at once.
advance(3)
askAs(ada, { op = "home" })
advance(3)
askAs(ada, { op = "go", id = "basement" })
held[ada] = 1
local used = Game.useHeldSkip(Attractions.ctx, ada)
check("a skip bought in the Basement is used at once", used == true and Game.runs[ada].checkpoint == 1 and held[ada] == 0)

---------------------------------------------------------------------------------------------------
-- 6. The lifts, and leaving early
---------------------------------------------------------------------------------------------------
for n = 2, 4 do
	onCheckpoint(ada, n)
end
local estateBefore = Fortune.page(data(ada)).estate
local lift = Game.built().lifts[4]
advance(3)
lift.Triggered:Fire(ada)
check("the lift up takes them home", Attractions.inside(ada) == nil and Layout.zoneAt(ada.root.CFrame.Position) == "obsidian")
check("...with everything already paid kept", Fortune.page(data(ada)).estate == estateBefore and Game.runs[ada] == nil)

---------------------------------------------------------------------------------------------------
-- 7. The boards
---------------------------------------------------------------------------------------------------
H.orderedStores[C.store] = H.orderedStores[C.store] or {}
H.orderedStores[C.store]["777"] = 19000
H.orderedStores[C.store]["888"] = 15000
H.orderedStores[C.store]["999"] = 40000
run(function()
	Game.refreshBoards(Attractions.ctx)
end)
local bd = askAs(ada, { op = "act", id = "basement", act = "boards", what = "all" })
check("all time: the fastest first", bd.ok == true and bd.entries[1].userId == 888 and bd.entries[2].userId == 777 and bd.entries[3].userId == 601 and bd.entries[4].userId == 999, bd.entries[1] and bd.entries[1].userId)
check("...in seconds", math.abs(bd.entries[1].score - 150) < 1e-6)
bd = askAs(ada, { op = "act", id = "basement", act = "boards", what = "friends" })
check("friends: only their friends, and themselves", #bd.entries == 2 and bd.entries[1].userId == 777 and bd.entries[2].userId == 601)
bd = askAs(ada, { op = "act", id = "basement", act = "boards", what = "week" })
check("this week: their week's best", bd.ok == true and bd.weekBest == 205.5)
local st = askAs(ada, { op = "state", id = "basement" })
check("the board is told their best, clears and deepest", st.ok == true and st.best == 205.5 and st.clears == 3 and st.deepest == 16)

---------------------------------------------------------------------------------------------------
-- 8. Build 78: the course turns over every five minutes; a run keeps its own course
---------------------------------------------------------------------------------------------------
Game.variantNow = function(t)
	return Plan.variantAt(t)
end
check("four courses, each up for five minutes in turn by the server's clock", #Plan.Variants == 4 and Plan.variantAt(0) == 1 and Plan.variantAt(299) == 1 and Plan.variantAt(300) == 2 and Plan.variantAt(600) == 3 and Plan.variantAt(900) == 4 and Plan.variantAt(1200) == 1 and Plan.variantEnds(10) == 300)
check("each course's machinery runs at its own pace", Plan.paced(1, 100) == 100 and math.abs(Plan.paced(2, 100) - 140) < 1e-9 and Plan.paced(3, 100) < 100)
local perCourse = true
for n = 1, #Plan.Variants do
	if Plan.secretsIn(n) ~= 2 then
		perCourse = false
	end
end
check("two secrets on each course, eight in all", #Plan.Secrets == 8 and perCourse)
local guestsDown = {}
-- A run on Double Time (up at 9000 + 300 * k: 9300 is period 31, the 4th course... found here).
local function periodOf(n)
	local p = 40
	while Plan.variantAt(p * Plan.VARIANT_SECONDS) ~= n do
		p += 1
	end
	return p * Plan.VARIANT_SECONDS
end
local dt0 = periodOf(2)
T = dt0 + 10
data(bo).gilt = 0
advance(3)
stand(bo, Layout.Obsidian.arrival)
r = askAs(bo, { op = "go", id = "basement" })
check("(Bo goes down)", r.ok == true, r.why)
steps(2)
check("a run takes the course that's up: told to the screen, in the guest's own attribute", Game.runs[bo].variant == 2 and bo:GetAttribute("BasementVariant") == 2 and last(bo, "basement").course == "Double Time")
-- Not yet begun: the course turns, and the run takes the new one.
T = dt0 + Plan.VARIANT_SECONDS + 1
steps(1)
check("a run not yet begun takes the next course when it turns", Game.runs[bo].variant == 3 and bo:GetAttribute("BasementVariant") == 3)
-- Begun: the run keeps its course.
standIn(bo, Vector3.new(0, -1, 10.5))
steps(1)
check("(off the start: the clock runs)", Game.runs[bo].started ~= nil)
T = dt0 + 2 * Plan.VARIANT_SECONDS - 25
steps(1)
local soon = last(bo, "course")
check("thirty seconds before a turn, everyone down here is told what's next", soon ~= nil and soon.soon == Plan.Variants[4].name and soon.seconds == 25)
T = dt0 + 2 * Plan.VARIANT_SECONDS + 1
steps(1)
local turned = last(bo, "course")
check("when it turns, they're told, and a run under way keeps its own course to the Treasury", turned ~= nil and turned.now == Plan.Variants[4].name and turned.keeps == Plan.Variants[3].name and Game.runs[bo].variant == 3)
check("its screen says which course the run is on and which is up", last(bo, "basement").course == "Blackout" and last(bo, "basement").upNow == "The Gauntlet")
-- A crusher: of the Gauntlet only.
local crush
for _, e in Plan.Elements do
	if e.kind == "crusher" and e.stage == 2 then
		crush = e
	end
end
local function downAt(e, n, from)
	local t = from
	while not (Plan.burning(e, Plan.paced(n, t)) and Plan.burning(e, Plan.paced(n, t - 0.15))) do
		t += 0.05
	end
	return t
end
Game.runs[bo].checkpoint = 1
Game.runs[bo].grace = 0
local fallsWas = Game.runs[bo].falls
T = downAt(crush, 3, T)
standIn(bo, crush.at - Vector3.new(0, crush.size.Y / 2 - 0.5, 0))
steps(3)
check("on another course, the Gauntlet's crusher isn't there: nothing", Game.runs[bo].falls == fallsWas)
Game.runs[bo].variant = 4
Game.runs[bo].grace = 0
T = downAt(crush, 4, T + 0.5)
standIn(bo, crush.at - Vector3.new(0, crush.size.Y / 2 - 0.5, 0))
steps(1)
T += 0.1
steps(1)
check("on the Gauntlet, caught under a crusher as it comes down: back to the checkpoint", Game.runs[bo].falls == fallsWas + 1 and last(bo, "fell").why == "crusher", last(bo, "fell") and last(bo, "fell").why)
local up = T
while Plan.burning(crush, Plan.paced(4, up)) or Plan.burning(crush, Plan.paced(4, up - 0.15)) or Plan.crusherLift(crush, Plan.paced(4, up)) < 6.5 do
	up += 0.05
end
check("its warning comes before it drops", (function()
	local t = up
	while not Plan.crusherWarns(crush, Plan.paced(4, t)) do
		t += 0.05
	end
	return not Plan.burning(crush, Plan.paced(4, t))
end)())
-- The launch pad tells the movement watch it's the house throwing them up.
local moves = 0
local movedWas = Attractions.ctx.moved
Attractions.ctx.moved = function(p)
	moves += 1
	return movedWas(p)
end
local pad
for _, e in Plan.Elements do
	if e.kind == "bouncer" then
		pad = e
	end
end
Game.runs[bo].checkpoint = 9
Game.runs[bo].grace = 0
standIn(bo, pad.at + Vector3.new(0, pad.size.Y / 2, 0))
steps(2)
check("standing on the Gauntlet's launch pad, the movement watch is told the house is throwing them up", moves >= 1)
Attractions.ctx.moved = movedWas
-- Secrets: each paid once, for good; another course's isn't there.
local key, other
for _, e in Plan.Secrets do
	if e.variant == 4 and e.stage == 10 then
		key = e
	elseif e.variant == 1 and not other then
		other = e
	end
end
local giltWas = data(bo).gilt
standIn(bo, key.at - Vector3.new(0, 3, 0))
steps(2)
local found = last(bo, "secret")
check("a secret of this run's course, touched: found, and its Gilt paid", found ~= nil and found.id == "trussKey" and found.found == 1 and found.of == 8 and data(bo).gilt - giltWas == found.gilt and found.gilt > 0)
check("...kept with their ledger, for good", Game.page(Attractions.ctx, data(bo)).secrets.trussKey == true)
steps(5)
check("...and paid only once", count(bo, "secret") == 1)
Game.runs[bo].checkpoint = other.stage - 1
standIn(bo, other.at - Vector3.new(0, 3, 0))
steps(2)
check("another course's secret isn't there to find", count(bo, "secret") == 1)
-- Each course keeps its own best.
Game.runs[bo].checkpoint = 15
Game.runs[bo].started = T - 222.5
onCheckpoint(bo, 16)
local tr = last(bo, "treasury")
check("at the Treasury: the course it was run on, and that course's own best", tr ~= nil and tr.course == "The Gauntlet" and math.abs(tr.coursePb - 222.5) < 1e-6 and Game.page(Attractions.ctx, data(bo)).bests.gauntlet ~= nil and tr.secretsOf == 8)
local dir = Game.directory(Attractions.ctx, bo)
check("the Directory's card says which course is up, and the secrets found", dir.course == Plan.Variants[Plan.variantAt(T)].name and dir.secrets == 1 and dir.secretsOf == 8)

H.finish()

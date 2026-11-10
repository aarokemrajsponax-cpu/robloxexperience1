--!strict
-- Timed laps and racing ranks (shared/Tracks). A guest at the wheel of any car, on a track and not
-- in a race, is timed lap by lap by the server's own clock: a lap starts as they cross the start
-- line, counts only if every gate is passed in order on the road, never faster than any car could
-- go (the same check as the races), and ends at the line. Their best lap on each track is kept,
-- and goes on the track's boards (all time, and this week: the same in every server); their
-- friends' bests are shown beside it. Every lap (up to twenty a day), every new best and every
-- race result earns racing points, which climb the racing ranks: from Club Racer, the stripes of
-- whatever car they drive are painted in their rank's colour for everyone to see.
--
-- Also here: "Join the next race" (from the Racing Club's board, or the racing card): the guest is
-- taken to a free car on the street and put on the next race's grid, wherever they were.

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GrandPrix = require(ReplicatedStorage.Shared.GrandPrix)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Tracks = require(ReplicatedStorage.Shared.Tracks)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Service = require(script.Parent.GrandPrixService)

local TimeTrials = {}

---------------------------------------------------------------------------------------------------
-- Hooks (set by Main)
---------------------------------------------------------------------------------------------------
TimeTrials.award = function(_player: Player, _key: string) end
TimeTrials.tally = function(_player: Player, _stat: string, _n: number) end
TimeTrials.progress = function(_player: Player, _kind: string, _n: number) end
TimeTrials.herald = function(_player: Player, _feat: { [string]: any }) end
-- Moves a guest (the house's own move: never taken for a jump of theirs).
TimeTrials.teleport = function(_player: Player, _cf: CFrame): boolean
	return false
end
-- A guest's Roblox friends (their user ids), for the friends' records.
TimeTrials.friendIds = function(player: Player): { number }
	local out: { number } = {}
	pcall(function()
		local pages = Players:GetFriendsAsync(player.UserId)
		while #out < 40 do
			for _, f in pages:GetCurrentPage() do
				table.insert(out, f.Id)
				if #out >= 40 then
					break
				end
			end
			if pages.IsFinished or #out >= 40 then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	return out
end
TimeTrials.now = function(): number
	return os.time()
end

type Lap = { track: string, gate: number, startAt: number?, passed: number, history: { { at: Vector3, t: number } } }
local laps: { [Player]: Lap } = {}

local function send(player: Player, message: { [string]: any })
	Remotes.event("Race"):FireClient(player, message)
end

local function serverTime(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.time()
end

-- A guest's racing page (with what the Grand Prix keeps there: races, wins, the best race).
local function page(data: any): { [string]: any }
	if type(data.racing) ~= "table" then
		data.racing = { day = -1, gems = 0, races = 0, wins = 0, best = 0 }
	end
	local r = data.racing
	if type(r.pb) ~= "table" then
		r.pb = {}
	end
	r.points = tonumber(r.points) or 0
	r.lapsToday = tonumber(r.lapsToday) or 0
	return r
end
TimeTrials.page = page

local function publish(player: Player, r: { [string]: any })
	local _, number = Tracks.rank(r.points)
	player:SetAttribute("RacingRank", number)
	player:SetAttribute("RacingPoints", r.points)
end

-- Racing points for a guest (a lap, a new best, a race); a new rank is told.
function TimeTrials.addPoints(player: Player, n: number, why: string)
	local data = Profiles.get(player)
	if not data or n <= 0 then
		return
	end
	local r = page(data)
	local _, before = Tracks.rank(r.points)
	r.points += math.floor(n)
	publish(player, r)
	local rank, after = Tracks.rank(r.points)
	if after > before then
		send(player, { op = "racingRank", number = after, name = rank.name, line = rank.line })
		if after >= 5 then
			TimeTrials.herald(player, { kind = "racing", title = "A NEW " .. string.upper(rank.name), line = "has raced their way to " .. rank.name, glyph = "🏁" })
		end
		-- (The stripes of the car they're in change at once.)
		local car = Service.carOf(player)
		if car then
			Service.stripes(car :: any, player)
		end
	end
	local _ = why
end

---------------------------------------------------------------------------------------------------
-- The boards
---------------------------------------------------------------------------------------------------
type Entry = { userId: number, name: string, time: number }
local boards: { [string]: { all: { Entry }, week: { Entry }, at: number } } = {}
local names: { [number]: string } = {}

local function weekNumber(): number
	return math.floor((math.floor(TimeTrials.now() / 86400) + 3) / 7)
end

local function ods(track: string): any
	return DataStoreService:GetOrderedDataStore("Laps_" .. track)
end

local function weekMap(track: string): any
	return MemoryStoreService:GetSortedMap("LapsWeek_" .. track .. "_" .. weekNumber())
end

local function nameOf(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	if p then
		return Names.of(p)
	end
	local known = names[userId]
	if known then
		return known
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok and type(n) == "string" then n else "A racer"
	names[userId] = name
	return name
end

-- Reads a track's boards again (at most once a minute, unless `force`).
local function refresh(track: string, force: boolean?): { all: { Entry }, week: { Entry }, at: number }
	local b = boards[track]
	local t = os.clock()
	if b and not force and t - b.at < 60 then
		return b
	end
	local fresh = { all = {} :: { Entry }, week = {} :: { Entry }, at = t }
	pcall(function()
		local pages = ods(track):GetSortedAsync(true, 10)
		for _, e in pages:GetCurrentPage() do
			local id = tonumber(e.key)
			if id and type(e.value) == "number" then
				table.insert(fresh.all, { userId = id, name = nameOf(id), time = e.value / 1000 })
			end
		end
	end)
	pcall(function()
		local list = weekMap(track):GetRangeAsync(Enum.SortDirection.Descending, 10)
		for _, e in list do
			local id = tonumber(e.key)
			if id and type(e.value) == "number" then
				table.insert(fresh.week, { userId = id, name = nameOf(id), time = e.value / 1000 })
			end
		end
	end)
	boards[track] = fresh
	return fresh
end

-- A new best on the boards (only ever a better time replaces one).
local function submit(player: Player, track: string, seconds: number)
	local ms = math.floor(seconds * 1000 + 0.5)
	local key = tostring(player.UserId)
	local before = refresh(track)
	local record = before.all[1]
	task.spawn(function()
		pcall(function()
			ods(track):UpdateAsync(key, function(old: number?): number?
				if type(old) == "number" and old <= ms then
					return nil
				end
				return ms
			end)
		end)
		pcall(function()
			weekMap(track):UpdateAsync(key, function(old: any, _sortKey: any): (any, any)
				if type(old) == "number" and old <= ms then
					return nil, nil
				end
				return ms, -ms
			end, 8 * 86400)
		end)
		refresh(track, true)
	end)
	-- A track record: the whole house hears of it.
	if record == nil or seconds < record.time then
		local def = Tracks.byId[track]
		TimeTrials.herald(player, { kind = "trackRecord", title = "A TRACK RECORD", line = string.format("set a new record on %s: %s", if def then def.name else track, Tracks.clock(seconds)), glyph = "⏱️" })
	end
end

---------------------------------------------------------------------------------------------------
-- Timing
---------------------------------------------------------------------------------------------------
local function finishLap(player: Player, track: string, seconds: number)
	local def = Tracks.byId[track]
	if seconds < Tracks.quickest(track) * 0.95 then
		send(player, { op = "trialVoid", why = "A lap quicker than any car can drive: it doesn't count." })
		return
	end
	local data = Profiles.get(player)
	if not data or not def then
		return
	end
	local r = page(data)
	local time = math.floor(seconds * 1000 + 0.5) / 1000
	local old = tonumber(r.pb[track])
	local best = old == nil or time < old
	if best then
		r.pb[track] = time
	end
	local today = math.floor(TimeTrials.now() / 86400)
	if r.lapsDay ~= today then
		r.lapsDay = today
		r.lapsToday = 0
	end
	local points = 0
	if r.lapsToday < Tracks.POINTS.lapsADay then
		r.lapsToday += 1
		points += Tracks.POINTS.lap
	end
	if best then
		points += Tracks.POINTS.best
	end
	TimeTrials.addPoints(player, points, "lap")
	TimeTrials.tally(player, "trialLaps", 1)
	TimeTrials.progress(player, "lap", 1)
	if time < def.ace then
		TimeTrials.award(player, def.badge)
	end
	send(player, { op = "trialLap", track = track, time = time, pb = r.pb[track], best = best, previous = old })
	if best then
		submit(player, track, time)
	end
end

-- One beat of the circuits: every driver who isn't racing is timed.
function TimeTrials.tick(t: number)
	for _, player in Players:GetPlayers() do
		local car = Service.carOf(player)
		local st = laps[player]
		local track = if car then (car :: any).track else nil
		if not car or not track or Service.inRace(player) or (track == "boulevard" and Service.racing()) then
			if st then
				laps[player] = nil
				if st.startAt then
					send(player, { op = "trialEnd" })
				end
			end
			continue
		end
		local def = Tracks.byId[track]
		local pos = (car :: any).chassis.CFrame.Position
		local s, off = Tracks.progress(track, pos)
		if not st or st.track ~= track then
			st = { track = track, gate = Tracks.gate(track, s), passed = 0, history = { { at = pos, t = t } } }
			laps[player] = st :: Lap
			continue
		end
		local lap = st :: Lap
		-- Nobody moves faster than a car can, over the last second and a half.
		table.insert(lap.history, { at = pos, t = t })
		while #lap.history > 2 and t - lap.history[1].t > 1.5 do
			table.remove(lap.history, 1)
		end
		local oldest = lap.history[1]
		local span = t - oldest.t
		local flat = Vector3.new(pos.X - oldest.at.X, 0, pos.Z - oldest.at.Z).Magnitude
		if span > 0 and flat > GrandPrix.limit() * span + 18 then
			if lap.startAt then
				send(player, { op = "trialVoid", why = "Faster than any car can go: that lap doesn't count." })
			end
			lap.startAt = nil
			lap.passed = 0
			lap.history = { { at = pos, t = t } }
			lap.gate = Tracks.gate(track, s)
			continue
		end
		if off > def.width / 2 + 6 then
			continue -- (off the road: no gate is passed out there)
		end
		local g = Tracks.gate(track, s)
		if g == lap.gate then
			continue
		end
		if g == (lap.gate + 1) % def.gates then
			lap.gate = g
			if g == 0 then
				if lap.startAt and lap.passed >= def.gates - 1 then
					finishLap(player, track, t - lap.startAt)
				end
				lap.startAt = t
				lap.passed = 0
				send(player, { op = "trialStart", track = track, at = serverTime() })
			elseif lap.startAt then
				lap.passed += 1
			end
		else
			-- Out of order (backwards, or across the infield): the lap so far doesn't count.
			if lap.startAt then
				send(player, { op = "trialVoid", why = "Off the circuit's line: that lap doesn't count. Cross the start line to begin another." })
			end
			lap.startAt = nil
			lap.passed = 0
			lap.gate = g
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The racing card: the boards, your bests and your friends', your rank; joining the next race
---------------------------------------------------------------------------------------------------
local friendCache: { [Player]: { ids: { number }, at: number } } = {}
local friendTimes: { [string]: { time: number?, at: number } } = {}

local function friendsBoard(player: Player, track: string): { Entry }
	local cached = friendCache[player]
	if not cached or os.clock() - cached.at > 600 then
		local fresh = { ids = TimeTrials.friendIds(player), at = os.clock() }
		friendCache[player] = fresh
		cached = fresh
	end
	local out: { Entry } = {}
	for _, id in (cached :: { ids: { number }, at: number }).ids do
		local t: number? = nil
		local here = Players:GetPlayerByUserId(id)
		local data = here and Profiles.get(here)
		if data then
			t = tonumber(page(data).pb[track])
		else
			local key = track .. ":" .. id
			local c = friendTimes[key]
			if not c or os.clock() - c.at > 120 then
				local got: number? = nil
				pcall(function()
					local v = ods(track):GetAsync(tostring(id))
					got = if type(v) == "number" then v / 1000 else nil
				end)
				c = { time = got, at = os.clock() }
				friendTimes[key] = c :: any
			end
			t = (c :: any).time
		end
		if t then
			table.insert(out, { userId = id, name = nameOf(id), time = t })
		end
	end
	local mine = Profiles.get(player)
	local myBest = mine and tonumber(page(mine).pb[track])
	if myBest then
		table.insert(out, { userId = player.UserId, name = Names.of(player), time = myBest })
	end
	table.sort(out, function(a, b)
		return a.time < b.time
	end)
	while #out > 10 do
		table.remove(out)
	end
	return out
end

function TimeTrials.card(player: Player): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local r = page(data)
	local rank, number, nextRank = Tracks.rank(r.points)
	local tracks = {}
	for _, def in Tracks.List do
		local b = refresh(def.id)
		table.insert(tracks, {
			id = def.id,
			name = def.name,
			line = def.line,
			ace = def.ace,
			pb = tonumber(r.pb[def.id]),
			all = b.all,
			week = b.week,
			friends = friendsBoard(player, def.id),
		})
	end
	return {
		ok = true,
		points = r.points,
		rank = number,
		rankName = rank.name,
		rankLine = rank.line,
		nextName = if nextRank then nextRank.name else nil,
		nextAt = if nextRank then nextRank.at else nil,
		races = tonumber(r.races) or 0,
		wins = tonumber(r.wins) or 0,
		tracks = tracks,
	}
end

-- "Join the next race": a free car on the street, and a place on the grid.
function TimeTrials.joinNext(player: Player): { [string]: any }
	local car = Service.carOf(player)
	if not car then
		local free = nil
		for _, c in Service.cars() do
			local cc = c :: any
			if not cc.driver and cc.track == "boulevard" and not cc.def.private then
				free = cc
				break
			end
		end
		if not free then
			return { ok = false, why = "Every car is out just now. Try again in a moment." }
		end
		local home = free.chassis.CFrame
		if not TimeTrials.teleport(player, home * CFrame.new(-6, 2, 0)) then
			return { ok = false, why = "Not just now." }
		end
		local ok, why = Service.drive(player, free.def.id)
		if not ok then
			return { ok = false, why = why }
		end
	end
	local ok, why, closed = Service.join(player)
	return { ok = ok, why = why, closed = closed }
end

local ASK_KEYS = { op = true }
local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 2, 0)
	if not r then
		RemoteGuard.reject(player, "racingAsk", "malformed")
		return { ok = false, why = "That isn't something the house does." }
	end
	for k in r do
		if not ASK_KEYS[k] then
			RemoteGuard.reject(player, "racingAsk", "malformed")
			return { ok = false, why = "That isn't something the house does." }
		end
	end
	if r.op == "card" then
		return TimeTrials.card(player)
	elseif r.op == "join" then
		return TimeTrials.joinNext(player)
	end
	return { ok = false, why = "That isn't something the house does." }
end

function TimeTrials.start()
	Service.onTick = TimeTrials.tick
	Service.points = TimeTrials.addPoints
	RemoteGuard.invoke(Remotes.func("RacingAsk"), "racingAsk", onAsk)
	Profiles.Loaded:Connect(function(player: Player)
		local data = Profiles.get(player)
		if data then
			publish(player, page(data))
		end
	end)
	for _, player in Players:GetPlayers() do
		local data = Profiles.get(player)
		if data then
			publish(player, page(data))
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		laps[player] = nil
		friendCache[player] = nil
	end)
	-- The Racing Club's board on the street opens the racing card.
	local function hook(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player: Player)
				send(player, { op = "card" })
			end)
		end
	end
	for _, prompt in CollectionService:GetTagged("RacingClubPrompt") do
		hook(prompt)
	end
	CollectionService:GetInstanceAddedSignal("RacingClubPrompt"):Connect(hook)
end

-- For tests.
TimeTrials.laps = laps
TimeTrials.refresh = refresh

return TimeTrials

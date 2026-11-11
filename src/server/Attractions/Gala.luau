--!strict
-- The Grand Ballroom on the server (shared/Gala has the plan; GalaBuild builds it). Everything is
-- the server's: where each guest stands (the dance floor's minutes, the Arena's points, the
-- Runway's end mark), every trivia question and its right answer (a screen is told the right one
-- only once the time is up), every vote, every reward and the day's cap on them. The activities:
--   The jukebox     a record plays a while, then the most-voted goes on (one vote a guest)
--   Luxury Trivia   up to eight at the podiums; seven questions; the quickest right answer scores
--                   most; Gilt for every right answer and more for the winner
--   The Runway      a themed show for two to six models: each walks the catwalk in turn and
--                   poses on the end mark; then everyone in the hall votes for the look they liked
--                   (never their own); the most votes wins
--   The Daily Arena today's challenge for up to twelve, forty-five seconds a round
--   The photo sets  a pose at each (a little Gilt the first time each day; all three for a badge)
--   The dance floor a minute on the floor pays a little, ten minutes a day
-- A guest takes part in one of Trivia, the Runway and the Arena at a time; leaving the hall, any
-- way, lets go of them at once. Nothing a guest's screen says is a reward, an answer or a place.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Names = require(ReplicatedStorage.Shared.Names)
local Plan = require(ReplicatedStorage.Shared.Gala)
local Types = require(script.Parent.Types)
local GalaBuild = require(script.Parent.GalaBuild)

local Gala = {}

-- The clocks (tests set them): phases run on `now`, the day on `time`.
Gala.now = os.clock
Gala.time = os.time

local built: GalaBuild.Built? = nil

local function cfg(ctx: Types.Ctx): { [string]: any }
	return ctx.cfg(Plan.ID)
end

local function num(v: any, default: number): number
	return if type(v) == "number" and v == v then v else default
end

-- A reward's size: Config's, else the plan's.
local function R(ctx: Types.Ctx, key: string): number
	return num(cfg(ctx)[key], (Plan.REWARDS :: any)[key] or 0)
end

local function serverNow(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

-- A guest's page of the hall, tidied, with the day's counts new each day.
local function page(ctx: Types.Ctx, data: any): { [string]: any }
	local p = ctx.saved(data, Plan.ID)
	local today = Plan.day(Gala.time())
	if p.day ~= today then
		p.day = today
		p.gilt = 0
		p.minutes = 0
		p.photos = {}
	end
	if type(p.photos) ~= "table" then
		p.photos = {}
	end
	if type(p.sets) ~= "table" then
		p.sets = {}
	end
	p.gilt = num(p.gilt, 0)
	p.minutes = num(p.minutes, 0)
	return p
end
Gala.page = page

-- Pays Gilt within the day's cap for the hall. Returns what was paid.
local function pay(ctx: Types.Ctx, player: Player, amount: number, source: string): number
	local data = ctx.data(player)
	amount = math.floor(amount)
	if not data or amount <= 0 then
		return 0
	end
	local p = page(ctx, data)
	local give = math.max(0, math.min(amount, R(ctx, "dailyGilt") - p.gilt))
	if give <= 0 then
		return 0
	end
	local paid = ctx.gilt(player, give, source)
	p.gilt += paid
	return paid
end

-- The guests in the hall now.
local function here(ctx: Types.Ctx): { Player }
	local out = {}
	for _, p in Players:GetPlayers() do
		if ctx.inside(p) == Plan.ID then
			table.insert(out, p)
		end
	end
	return out
end

local function tell(ctx: Types.Ctx, m: { [string]: any })
	m.op = "gala"
	for _, p in here(ctx) do
		ctx.send(p, m)
	end
end

-- The same, saying to each guest whether it's about them (they're in it).
local function tellMine(ctx: Types.Ctx, m: { [string]: any }, mine: (Player) -> boolean)
	m.op = "gala"
	for _, p in here(ctx) do
		local each = table.clone(m)
		each.mine = mine(p)
		ctx.send(p, each)
	end
end

local function at(ctx: Types.Ctx, player: Player): Vector3?
	return ctx.at(player, Plan.ID)
end

local function origin(ctx: Types.Ctx): Vector3
	local o = cfg(ctx).origin
	if type(o) == "table" then
		return Vector3.new(num(o[1], 0), num(o[2], 0), num(o[3], 0))
	end
	return Vector3.zero
end

local function moveTo(ctx: Types.Ctx, player: Player, cf: CFrame)
	ctx.teleport(player, cf + origin(ctx))
end

local function setLabel(board: GalaBuild.Board?, name: string, text: string, colour: Color3?)
	local l = board and board.labels[name]
	if l then
		l.Text = text
		if colour then
			l.TextColor3 = colour
		end
	end
end

local rgb = Color3.fromRGB
local BONE = rgb(236, 226, 206)
local GOOD = rgb(120, 230, 150)
local BAD = rgb(240, 110, 110)
local GOLD = rgb(255, 214, 120)

---------------------------------------------------------------------------------------------------
-- The jukebox
---------------------------------------------------------------------------------------------------
type Juke = { track: number, startedAt: number, changeAt: number, votes: { [Player]: number } }
local juke: Juke = { track = 1, startedAt = 0, changeAt = 0, votes = {} }

local function records(): { any }
	local m = (Config.data :: any).Assets.AbuseMusic
	return if type(m) == "table" and type(m.abuse) == "table" then m.abuse else {}
end

local function recordName(i: number): string
	return Plan.TRACK_NAMES[i] or ("Record " .. i)
end

local function jukeView(player: Player?): { [string]: any }
	local tally: { [number]: number } = {}
	for voter, t in juke.votes do
		if voter.Parent then
			tally[t] = (tally[t] or 0) + 1
		end
	end
	local list = {}
	for i, r in records() do
		table.insert(list, { n = i, name = recordName(i), id = r.id, gain = r.gain, bpm = r.bpm, beat = r.beat, votes = tally[i] or 0 })
	end
	return {
		track = juke.track,
		name = recordName(juke.track),
		startedAt = juke.startedAt,
		changeIn = math.max(0, math.ceil(juke.changeAt - Gala.now())),
		records = list,
		mine = if player then juke.votes[player] else nil,
	}
end

local function jukeNext(ctx: Types.Ctx)
	local n = #records()
	if n == 0 then
		return
	end
	local tally: { [number]: number } = {}
	for voter, t in juke.votes do
		if voter.Parent and ctx.inside(voter) == Plan.ID then
			tally[t] = (tally[t] or 0) + 1
		end
	end
	-- The most-voted (ties go to the next one round from this record); none: the next in turn.
	local best, bestVotes = (juke.track % n) + 1, 0
	for k = 1, n do
		local i = ((juke.track + k - 1) % n) + 1
		local v = tally[i] or 0
		if v > bestVotes then
			best, bestVotes = i, v
		end
	end
	juke.track = best
	juke.startedAt = serverNow()
	juke.changeAt = Gala.now() + num(cfg(ctx).trackSeconds, Plan.TRACK_SECONDS)
	juke.votes = {}
	local view = jukeView(nil)
	view.kind = "juke"
	tell(ctx, view)
end

---------------------------------------------------------------------------------------------------
-- Who's taking part in what
---------------------------------------------------------------------------------------------------
type Seat = { player: Player, podium: number, score: number, right: number, answer: number?, answeredAt: number?, joined: number }
type Trivia = { phase: string, seats: { [Player]: Seat }, endsAt: number, q: number, set: { { q: string, choices: { string }, right: number } }, recent: { number }, askedAt: number }
local trivia: Trivia = { phase = "idle", seats = {}, endsAt = 0, q = 0, set = {}, recent = {}, askedAt = 0 }

type Model = { player: Player, order: number, walked: boolean, posed: boolean }
type Runway = { phase: string, theme: number, lastTheme: number, models: { Model }, walking: number, endsAt: number, extended: boolean, votes: { [Player]: number }, posedAt: number }
local runway: Runway = { phase = "idle", theme = 1, lastTheme = 0, models = {}, walking = 0, endsAt = 0, extended = false, votes = {}, posedAt = 0 }

type Contender = { player: Player, points: number, joined: number }
type Coin = { pos: Vector3, back: number }
type Arena = { phase: string, players: { [Player]: Contender }, endsAt: number, startedAt: number, serverStart: number, challenge: string, coins: { Coin }, lastScore: number }
local arena: Arena = { phase = "idle", players = {}, endsAt = 0, startedAt = 0, serverStart = 0, challenge = "spotlight", coins = {}, lastScore = 0 }

local floorTime: { [Player]: number } = {}

local function modelOf(player: Player): Model?
	for _, m in runway.models do
		if m.player == player then
			return m
		end
	end
	return nil
end

-- What a guest is taking part in, if anything.
local function busy(player: Player): string?
	if trivia.seats[player] then
		return "trivia"
	elseif modelOf(player) then
		return "runway"
	elseif arena.players[player] then
		return "arena"
	end
	return nil
end
Gala.busy = busy

local ACTIVITY = { trivia = "Luxury Trivia", runway = "the Runway", arena = "the Daily Arena" }

local function count(t: { [any]: any }): number
	local n = 0
	for _ in t do
		n += 1
	end
	return n
end

---------------------------------------------------------------------------------------------------
-- Luxury Trivia
---------------------------------------------------------------------------------------------------
local function screenIdle()
	local b = built and built.screen
	setLabel(b, "Question", "Seven questions. Eight podiums. The quickest right answer wins.", BONE)
	for _, k in { "A", "B", "C", "D" } do
		setLabel(b, k, "", BONE)
	end
	setLabel(b, "Foot", "Take any podium to play.")
end

local function glow(podium: number, colour: Color3, transparency: number)
	local g = built and built.podiums[podium]
	if g then
		g.Color = colour
		g.Transparency = transparency
	end
end

local function triviaReset()
	for _, s in trivia.seats do
		glow(s.podium, rgb(255, 214, 140), 0.5)
	end
	trivia.phase = "idle"
	trivia.seats = {}
	trivia.q = 0
	trivia.set = {}
	screenIdle()
end

local function freePodium(near: Vector3): number?
	local taken: { [number]: boolean } = {}
	for _, s in trivia.seats do
		taken[s.podium] = true
	end
	local best, bestD = nil, math.huge
	for i = 1, Plan.PODIUMS do
		if not taken[i] then
			local d = Plan.flat(Plan.podiumStand(i).Position, near)
			if d < bestD then
				best, bestD = i, d
			end
		end
	end
	return best
end

-- Seven questions, none asked in the last few rounds, each with its answers shuffled.
local function pickQuestions(ctx: Types.Ctx)
	local bank = Plan.Questions
	local recent: { [number]: boolean } = {}
	for _, i in trivia.recent do
		recent[i] = true
	end
	local pool = {}
	for i = 1, #bank do
		if not recent[i] then
			table.insert(pool, i)
		end
	end
	if #pool < Plan.TRIVIA_QUESTIONS then
		pool = {}
		for i = 1, #bank do
			table.insert(pool, i)
		end
		trivia.recent = {}
	end
	trivia.set = {}
	for _ = 1, Plan.TRIVIA_QUESTIONS do
		local k = ctx.rng:NextInteger(1, #pool)
		local i = table.remove(pool, k) :: number
		table.insert(trivia.recent, i)
		local item = bank[i]
		local order = { 1, 2, 3, 4 }
		for a = 4, 2, -1 do
			local b = ctx.rng:NextInteger(1, a)
			order[a], order[b] = order[b], order[a]
		end
		local choices = {}
		local right = 1
		for slot, from in order do
			choices[slot] = item.a[from]
			if from == 1 then
				right = slot
			end
		end
		table.insert(trivia.set, { q = item.q, choices = choices, right = right })
	end
	while #trivia.recent > 35 do
		table.remove(trivia.recent, 1)
	end
end

local LETTERS = { "A", "B", "C", "D" }

local function ask(ctx: Types.Ctx)
	trivia.q += 1
	local item = trivia.set[trivia.q]
	trivia.phase = "question"
	trivia.askedAt = Gala.now()
	trivia.endsAt = trivia.askedAt + Plan.TRIVIA_ANSWER
	for _, s in trivia.seats do
		s.answer = nil
		s.answeredAt = nil
		glow(s.podium, rgb(255, 214, 140), 0.5)
	end
	local b = built and built.screen
	setLabel(b, "Question", item.q, BONE)
	for i, k in LETTERS do
		setLabel(b, k, k .. "   " .. item.choices[i], BONE)
	end
	setLabel(b, "Foot", string.format("Question %d of %d  ·  %d seconds", trivia.q, Plan.TRIVIA_QUESTIONS, Plan.TRIVIA_ANSWER))
	for _, p in here(ctx) do
		ctx.send(p, { op = "gala", kind = "trivia", phase = "question", n = trivia.q, of = Plan.TRIVIA_QUESTIONS, q = item.q, choices = item.choices, left = Plan.TRIVIA_ANSWER, seated = trivia.seats[p] ~= nil })
	end
end

local function reveal(ctx: Types.Ctx)
	local item = trivia.set[trivia.q]
	trivia.phase = "reveal"
	trivia.endsAt = Gala.now() + Plan.TRIVIA_REVEAL
	local b = built and built.screen
	for i, k in LETTERS do
		setLabel(b, k, (if i == item.right then "✓  " else "") .. k .. "   " .. item.choices[i], if i == item.right then GOOD else rgb(150, 140, 130))
	end
	setLabel(b, "Foot", "The answer: " .. item.choices[item.right])
	local results: { [Player]: { [string]: any } } = {}
	for player, s in trivia.seats do
		local right = s.answer == item.right
		local paid = 0
		if right then
			s.right += 1
			s.score += Plan.triviaScore(true, trivia.askedAt + Plan.TRIVIA_ANSWER - (s.answeredAt or trivia.askedAt + Plan.TRIVIA_ANSWER))
			paid = pay(ctx, player, R(ctx, "triviaCorrect"), "Luxury Trivia")
		end
		glow(s.podium, if right then GOOD else BAD, 0.2)
		results[player] = { mine = s.answer, correct = right, score = s.score, paid = paid }
	end
	for _, p in here(ctx) do
		local m: { [string]: any } = { op = "gala", kind = "trivia", phase = "reveal", right = item.right, answer = item.choices[item.right], n = trivia.q, of = Plan.TRIVIA_QUESTIONS }
		local mine = results[p]
		if mine then
			for k, v in mine do
				m[k] = v
			end
		end
		ctx.send(p, m)
	end
end

local function triviaResults(ctx: Types.Ctx)
	trivia.phase = "results"
	trivia.endsAt = Gala.now() + Plan.TRIVIA_RESULTS
	local list: { Seat } = {}
	for _, s in trivia.seats do
		table.insert(list, s)
	end
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		if a.right ~= b.right then
			return a.right > b.right
		end
		return a.joined < b.joined
	end)
	local top = if list[1] then list[1].score else 0
	local contest = #list >= 2 and top > 0
	local standings = {}
	local winners = {}
	for i, s in list do
		local won = contest and s.score == top
		table.insert(standings, { name = Names.of(s.player), userId = s.player.UserId, score = s.score, right = s.right, won = won, place = i })
		ctx.progress(s.player, "trivia", 1)
		if won then
			table.insert(winners, Names.of(s.player))
			pay(ctx, s.player, R(ctx, "triviaWin"), "Luxury Trivia win")
			ctx.tally(s.player, "triviaWins", 1)
			ctx.gems(s.player, R(ctx, "winGems"), "Luxury Trivia win", Plan.ID)
			if s.right == Plan.TRIVIA_QUESTIONS then
				ctx.herald(s.player, { kind = "gala", title = "LUXURY TRIVIA", line = "answered all seven, and won Luxury Trivia", glyph = "🎓" })
			end
		end
	end
	local b = built and built.screen
	setLabel(b, "Question", if #winners > 0 then table.concat(winners, " & ") .. " wins Luxury Trivia" else "The round is over", GOLD)
	for i, k in LETTERS do
		local s = standings[i]
		setLabel(b, k, if s then string.format("%d.  %s  ·  %s points  ·  %d right", i, s.name, Plan.commas(s.score), s.right) else "", BONE)
	end
	setLabel(b, "Foot", "The next round opens in a moment. Take a podium to play.")
	for _, p in here(ctx) do
		local mine = nil
		for _, s in standings do
			if s.userId == p.UserId then
				mine = s
			end
		end
		ctx.send(p, { op = "gala", kind = "trivia", phase = "results", standings = standings, winners = winners, mine = mine })
	end
end

local function triviaJoin(ctx: Types.Ctx, player: Player): { [string]: any }
	local pos = at(ctx, player)
	if not pos then
		return { ok = false, why = "Come into the Grand Ballroom first." }
	end
	if trivia.seats[player] then
		return { ok = false, why = "You're at a podium already." }
	end
	local other = busy(player)
	if other then
		return { ok = false, why = "You're in " .. ACTIVITY[other] .. " just now." }
	end
	if trivia.phase ~= "idle" and trivia.phase ~= "lobby" then
		return { ok = false, why = "A round is being played: the next one opens as it ends." }
	end
	if Plan.zoneAt(pos) ~= "trivia" then
		return { ok = false, why = "Luxury Trivia is played at the podiums in the Salon of Wits." }
	end
	local podium = freePodium(pos)
	if not podium then
		return { ok = false, why = "Every podium is taken: the next round soon." }
	end
	local now = Gala.now()
	trivia.seats[player] = { player = player, podium = podium, score = 0, right = 0, joined = now }
	moveTo(ctx, player, Plan.podiumStand(podium))
	glow(podium, GOLD, 0.15)
	if trivia.phase == "idle" then
		trivia.phase = "lobby"
		trivia.endsAt = now + Plan.TRIVIA_LOBBY
	end
	local left = math.max(0, math.ceil(trivia.endsAt - now))
	setLabel(built and built.screen, "Foot", string.format("%d at the podiums  ·  the first question in %d seconds", count(trivia.seats), left))
	tellMine(ctx, { kind = "trivia", phase = "lobby", seats = count(trivia.seats), left = left }, function(p: Player): boolean
		return trivia.seats[p] ~= nil
	end)
	return { ok = true, title = "Luxury Trivia", line = string.format("Podium %d. The first question in %d seconds: answer on your screen, quick and right.", podium, left) }
end

local function triviaStep(ctx: Types.Ctx)
	local now = Gala.now()
	for p in trivia.seats do
		if not p.Parent or ctx.inside(p) ~= Plan.ID then
			glow(trivia.seats[p].podium, rgb(255, 214, 140), 0.5)
			trivia.seats[p] = nil
		end
	end
	local phase: string = trivia.phase
	if phase == "idle" then
		return
	end
	local finishing = phase == "results"
	if next(trivia.seats) == nil and not finishing then
		triviaReset()
		return
	end
	if phase == "lobby" then
		if now >= trivia.endsAt then
			pickQuestions(ctx)
			trivia.q = 0
			ask(ctx)
		end
	elseif phase == "question" then
		local all = true
		for _, s in trivia.seats do
			if s.answer == nil then
				all = false
			end
		end
		if now >= trivia.endsAt or all then
			reveal(ctx)
		end
	elseif phase == "reveal" then
		if now >= trivia.endsAt then
			if trivia.q < Plan.TRIVIA_QUESTIONS then
				ask(ctx)
			else
				triviaResults(ctx)
			end
		end
	elseif phase == "results" then
		if now >= trivia.endsAt then
			triviaReset()
			tell(ctx, { kind = "trivia", phase = "idle" })
		end
	end
end

local function triviaAnswer(player: Player, n: unknown): { [string]: any }
	local s = trivia.seats[player]
	if not s then
		return { ok = false, why = "Take a podium to play." }
	end
	if trivia.phase ~= "question" then
		return { ok = false, why = "Not just now." }
	end
	if s.answer ~= nil then
		return { ok = false, why = "Your answer is in." }
	end
	if type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > 4 then
		return { ok = false, why = "That isn't one of the answers." }
	end
	s.answer = n
	s.answeredAt = Gala.now()
	glow(s.podium, rgb(255, 236, 190), 0.05)
	return { ok = true }
end

---------------------------------------------------------------------------------------------------
-- The Runway
---------------------------------------------------------------------------------------------------
local function theme(): Plan.Theme
	return Plan.Themes[runway.theme] or Plan.Themes[1]
end

local function runwayBoard(state: string)
	local b = built and built.runwayBoard
	if runway.phase == "idle" then
		setLabel(b, "Theme", "The next show")
		setLabel(b, "State", "Sign the models' book backstage to walk.")
	else
		setLabel(b, "Theme", theme().name, theme().colour)
		setLabel(b, "State", state)
	end
end

local function runwayReset(ctx: Types.Ctx)
	for _, m in runway.models do
		if m.player.Parent then
			m.player:SetAttribute("RunwayModel", nil)
		end
	end
	runway.phase = "idle"
	runway.models = {}
	runway.walking = 0
	runway.votes = {}
	runwayBoard("")
	tell(ctx, { kind = "runway", phase = "idle" })
end

local function walkers(): { Model }
	local out = {}
	for _, m in runway.models do
		if m.walked and m.player.Parent then
			table.insert(out, m)
		end
	end
	return out
end

local function nextWalk(ctx: Types.Ctx)
	runway.walking += 1
	local m = runway.models[runway.walking]
	while m and (not m.player.Parent or ctx.inside(m.player) ~= Plan.ID) do
		runway.walking += 1
		m = runway.models[runway.walking]
	end
	if not m then
		-- Everyone has walked: the room votes.
		local list = walkers()
		if #list < 2 then
			runwayReset(ctx)
			return
		end
		runway.phase = "vote"
		runway.endsAt = Gala.now() + Plan.RUNWAY_VOTE
		runway.votes = {}
		local models = {}
		for _, w in list do
			table.insert(models, { userId = w.player.UserId, name = Names.of(w.player) })
		end
		runwayBoard("The room votes: who wore the theme best?")
		tell(ctx, { kind = "runway", phase = "vote", theme = theme().name, models = models, left = Plan.RUNWAY_VOTE })
		return
	end
	runway.phase = "walk"
	runway.endsAt = Gala.now() + Plan.RUNWAY_WALK
	m.posed = false
	m.player:SetAttribute("RunwayModel", true)
	moveTo(ctx, m.player, Plan.RUNWAY.start)
	runwayBoard(string.format("Now walking: %s  ·  %d of %d", Names.of(m.player), runway.walking, #runway.models))
	tell(ctx, { kind = "runway", phase = "walk", userId = m.player.UserId, name = Names.of(m.player), theme = theme().name, n = runway.walking, of = #runway.models, left = Plan.RUNWAY_WALK })
end

local function runwayStart(ctx: Types.Ctx)
	runway.walking = 0
	for _, m in runway.models do
		moveTo(ctx, m.player, Plan.RUNWAY.wait)
	end
	nextWalk(ctx)
end

local function runwayResults(ctx: Types.Ctx)
	runway.phase = "results"
	runway.endsAt = Gala.now() + Plan.RUNWAY_RESULTS
	local list = walkers()
	local tally: { [number]: number } = {}
	for voter, uid in runway.votes do
		if voter.Parent then
			tally[uid] = (tally[uid] or 0) + 1
		end
	end
	local winner: Model? = nil
	local best = 0
	for _, m in list do
		local v = tally[m.player.UserId] or 0
		if v > best then
			winner, best = m, v
		end
	end
	local th = theme()
	local rows = {}
	for _, m in list do
		table.insert(rows, { name = Names.of(m.player), userId = m.player.UserId, votes = tally[m.player.UserId] or 0, won = m == winner })
		pay(ctx, m.player, R(ctx, "runwayWalk"), "The Runway")
		ctx.progress(m.player, "runway", 1)
	end
	table.sort(rows, function(a, b)
		return a.votes > b.votes
	end)
	for voter in runway.votes do
		if voter.Parent then
			pay(ctx, voter, R(ctx, "runwayVote"), "The Runway vote")
		end
	end
	if winner then
		local w = winner :: Model
		pay(ctx, w.player, R(ctx, "runwayWin"), "The Runway win")
		ctx.tally(w.player, "runwayWins", 1)
		ctx.gems(w.player, R(ctx, "winGems"), "The Runway win", Plan.ID)
		ctx.herald(w.player, { kind = "gala", title = "THE RUNWAY", line = "won the Runway: " .. th.name, glyph = "👗", colour = th.colour })
		runwayBoard(string.format("%s takes the show  ·  %d vote%s", Names.of(w.player), best, if best == 1 then "" else "s"))
	else
		runwayBoard("No votes this time: every model walked beautifully.")
	end
	for _, m in runway.models do
		if m.player.Parent then
			m.player:SetAttribute("RunwayModel", nil)
		end
	end
	tell(ctx, { kind = "runway", phase = "results", theme = th.name, winner = if winner then Names.of(winner.player) else nil, winnerId = if winner then winner.player.UserId else nil, rows = rows })
end

local function runwayJoin(ctx: Types.Ctx, player: Player): { [string]: any }
	local pos = at(ctx, player)
	if not pos then
		return { ok = false, why = "Come into the Grand Ballroom first." }
	end
	if modelOf(player) then
		return { ok = false, why = "You're in the next show already." }
	end
	local other = busy(player)
	if other then
		return { ok = false, why = "You're in " .. ACTIVITY[other] .. " just now." }
	end
	if runway.phase ~= "idle" and runway.phase ~= "signup" then
		return { ok = false, why = "A show is on: sign up for the next one as it ends." }
	end
	if Plan.zoneAt(pos) ~= "runway" then
		return { ok = false, why = "Sign the models' book backstage at the Runway." }
	end
	if #runway.models >= Plan.RUNWAY_MODELS then
		return { ok = false, why = "The show is full: the next one soon." }
	end
	local now = Gala.now()
	if runway.phase == "idle" then
		local n = #Plan.Themes
		local pick = ctx.rng:NextInteger(1, n)
		if pick == runway.lastTheme then
			pick = pick % n + 1
		end
		runway.theme = pick
		runway.lastTheme = pick
		runway.phase = "signup"
		runway.endsAt = now + Plan.RUNWAY_SIGNUP
		runway.extended = false
		runway.votes = {}
	end
	table.insert(runway.models, { player = player, order = #runway.models + 1, walked = false, posed = false })
	moveTo(ctx, player, Plan.RUNWAY.wait)
	local left = math.max(0, math.ceil(runway.endsAt - now))
	runwayBoard(string.format("%d model%s signed  ·  the show in %ds", #runway.models, if #runway.models == 1 then "" else "s", left))
	tellMine(ctx, { kind = "runway", phase = "signup", theme = theme().name, line = theme().line, models = #runway.models, left = left }, function(p: Player): boolean
		return modelOf(p) ~= nil
	end)
	return { ok = true, title = "The Runway: " .. theme().name, line = theme().line .. " Wait backstage: when it's your turn, walk to the gold mark at the end and strike a pose." }
end

local function runwayStep(ctx: Types.Ctx)
	local now = Gala.now()
	if runway.phase == "idle" then
		return
	end
	if runway.phase == "signup" then
		for i = #runway.models, 1, -1 do
			local m = runway.models[i]
			if not m.player.Parent or ctx.inside(m.player) ~= Plan.ID then
				table.remove(runway.models, i)
			end
		end
		if #runway.models == 0 then
			runwayReset(ctx)
			return
		end
		if #runway.models >= Plan.RUNWAY_MODELS then
			runwayStart(ctx)
		elseif now >= runway.endsAt then
			if #runway.models >= 2 then
				runwayStart(ctx)
			elseif not runway.extended then
				runway.extended = true
				runway.endsAt = now + Plan.RUNWAY_EXTRA
				runwayBoard("One more model and the show begins")
				tellMine(ctx, { kind = "runway", phase = "signup", theme = theme().name, line = theme().line, models = #runway.models, left = Plan.RUNWAY_EXTRA, waiting = true }, function(p: Player): boolean
					return modelOf(p) ~= nil
				end)
			else
				for _, m in runway.models do
					ctx.notice(m.player, "The Runway", "The show needs two models: try again when the hall is fuller.")
				end
				runwayReset(ctx)
			end
		end
	elseif runway.phase == "walk" then
		local m = runway.models[runway.walking]
		if not m or not m.player.Parent or ctx.inside(m.player) ~= Plan.ID then
			nextWalk(ctx)
			return
		end
		local pos = at(ctx, m.player)
		if not m.posed and pos and Plan.atFinish(pos) then
			m.posed = true
			runway.posedAt = now
			tell(ctx, { kind = "runway", phase = "posed", userId = m.player.UserId, name = Names.of(m.player) })
		end
		if now >= runway.endsAt or (m.posed and now >= runway.posedAt + 3.5) then
			m.walked = true
			m.player:SetAttribute("RunwayModel", nil)
			moveTo(ctx, m.player, Plan.RUNWAY.wait)
			nextWalk(ctx)
		end
	elseif runway.phase == "vote" then
		if now >= runway.endsAt then
			runwayResults(ctx)
		end
	elseif runway.phase == "results" then
		if now >= runway.endsAt then
			runwayReset(ctx)
		end
	end
end

local function runwayVote(player: Player, n: unknown): { [string]: any }
	if runway.phase ~= "vote" then
		return { ok = false, why = "The voting isn't open." }
	end
	if type(n) ~= "number" or n ~= math.floor(n) then
		return { ok = false, why = "Choose one of the models." }
	end
	if n == player.UserId then
		return { ok = false, why = "Vote for someone else's look." }
	end
	for _, m in walkers() do
		if m.player.UserId == n then
			runway.votes[player] = n
			return { ok = true }
		end
	end
	return { ok = false, why = "Choose one of the models." }
end

---------------------------------------------------------------------------------------------------
-- The Daily Arena
---------------------------------------------------------------------------------------------------
local function challenge(): Plan.Challenge
	return Plan.challengeById[arena.challenge] or Plan.Challenges[1]
end

local function arenaBoard(state: string, leader: string?)
	local b = built and built.arenaBoard
	local c = challenge()
	setLabel(b, "Name", c.glyph .. "  " .. c.name, c.colour)
	setLabel(b, "How", c.how)
	setLabel(b, "State", state)
	setLabel(b, "Leader", leader or "")
end

local function hideCoins(ctx: Types.Ctx)
	local folder = built and built.coins
	if folder then
		for _, c in folder:GetChildren() do
			if c:IsA("BasePart") then
				c.Transparency = 1
				c.CFrame = CFrame.new(origin(ctx) + Plan.ARENA.centre - Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end
	arena.coins = {}
end

local function coinSpot(ctx: Types.Ctx): Vector3
	local a = ctx.rng:NextNumber(0, math.pi * 2)
	local r = math.sqrt(ctx.rng:NextNumber(0.05, 1)) * (Plan.ARENA.radius - 3)
	local p = Plan.ARENA.centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	-- (Never on the dais.)
	if Plan.flat(p, Plan.ARENA.centre) < Plan.ARENA.dais + 1.5 then
		p = Plan.ARENA.centre + Vector3.new(Plan.ARENA.dais + 3, 0, 0)
	end
	return p
end

local function showCoin(ctx: Types.Ctx, i: number)
	local folder = built and built.coins
	local part = folder and folder:GetChildren()[i]
	local c = arena.coins[i]
	if part and part:IsA("BasePart") and c then
		part.CFrame = CFrame.new(origin(ctx) + c.pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
		part.Transparency = if c.back > 0 then 1 else 0
	end
end

local function arenaReset(ctx: Types.Ctx)
	arena.phase = "idle"
	arena.players = {}
	hideCoins(ctx)
	arena.challenge = Plan.challengeFor(Plan.day(Gala.time())).id
	arenaBoard("Join at the gate: up to twelve a round.")
	tell(ctx, { kind = "arena", phase = "idle", challenge = arena.challenge })
end

local function standings(): { { [string]: any } }
	local list: { Contender } = {}
	for _, c in arena.players do
		table.insert(list, c)
	end
	table.sort(list, function(a, b)
		if math.floor(a.points) ~= math.floor(b.points) then
			return a.points > b.points
		end
		return a.joined < b.joined
	end)
	local out = {}
	for i, c in list do
		table.insert(out, { name = Names.of(c.player), userId = c.player.UserId, points = math.floor(c.points), place = i })
	end
	return out
end

local function arenaPlay(ctx: Types.Ctx)
	arena.phase = "play"
	arena.startedAt = Gala.now()
	arena.serverStart = serverNow()
	arena.endsAt = arena.startedAt + Plan.ARENA_PLAY
	arena.lastScore = 0
	local n = count(arena.players)
	local k = 0
	for player in arena.players do
		k += 1
		local a = k / math.max(n, 1) * math.pi * 2
		local p = Plan.ARENA.centre + Vector3.new(math.cos(a) * (Plan.ARENA.radius - 4), 0, math.sin(a) * (Plan.ARENA.radius - 4))
		moveTo(ctx, player, CFrame.lookAt(p, Plan.ARENA.centre))
	end
	if arena.challenge == "coins" then
		arena.coins = {}
		for i = 1, Plan.ARENA_COINS do
			arena.coins[i] = { pos = coinSpot(ctx), back = 0 }
			showCoin(ctx, i)
		end
	end
	arenaBoard(string.format("%s  ·  %d in the ring", "Under way", n))
	tellMine(ctx, { kind = "arena", phase = "play", challenge = arena.challenge, serverStart = arena.serverStart, left = Plan.ARENA_PLAY, players = n }, function(p: Player): boolean
		return arena.players[p] ~= nil
	end)
end

local function arenaResults(ctx: Types.Ctx)
	arena.phase = "results"
	arena.endsAt = Gala.now() + Plan.ARENA_RESULTS
	hideCoins(ctx)
	local rows = standings()
	local top = if rows[1] then rows[1].points else 0
	local contest = #rows >= 2 and top > 0
	local winners = {}
	for _, row in rows do
		local c = nil
		for p, x in arena.players do
			if p.UserId == row.userId then
				c = x
			end
		end
		if c then
			local player = c.player
			local points = math.min(row.points, R(ctx, "arenaPoints"))
			row.paid = pay(ctx, player, R(ctx, "arenaTakePart") + points * R(ctx, "arenaPoint"), "The Daily Arena")
			ctx.progress(player, "arena", 1)
			if contest and row.points == top then
				row.won = true
				table.insert(winners, row.name)
				row.paid += pay(ctx, player, R(ctx, "arenaWin"), "The Daily Arena win")
				ctx.tally(player, "arenaWins", 1)
				ctx.gems(player, R(ctx, "winGems"), "The Daily Arena win", Plan.ID)
			end
		end
	end
	arenaBoard(if #winners > 0 then table.concat(winners, " & ") .. " wins" else "Round over", if rows[1] then string.format("Top score: %d", top) else nil)
	tellMine(ctx, { kind = "arena", phase = "results", challenge = arena.challenge, rows = rows, winners = winners }, function(p: Player): boolean
		return arena.players[p] ~= nil
	end)
end

local function arenaJoin(ctx: Types.Ctx, player: Player): { [string]: any }
	local pos = at(ctx, player)
	if not pos then
		return { ok = false, why = "Come into the Grand Ballroom first." }
	end
	if arena.players[player] then
		return { ok = false, why = "You're in this round already." }
	end
	local other = busy(player)
	if other then
		return { ok = false, why = "You're in " .. ACTIVITY[other] .. " just now." }
	end
	if arena.phase ~= "idle" and arena.phase ~= "countdown" then
		return { ok = false, why = "A round is under way: join the next one at the gate." }
	end
	if Plan.zoneAt(pos) ~= "arena" then
		return { ok = false, why = "Join at the Daily Arena's gate." }
	end
	if count(arena.players) >= Plan.ARENA_PLAYERS then
		return { ok = false, why = "This round is full: the next one soon." }
	end
	local now = Gala.now()
	if arena.phase == "idle" then
		arena.phase = "countdown"
		arena.endsAt = now + Plan.ARENA_COUNTDOWN
		arena.challenge = Plan.challengeFor(Plan.day(Gala.time())).id
	end
	arena.players[player] = { player = player, points = 0, joined = now }
	local left = math.max(0, math.ceil(arena.endsAt - now))
	arenaBoard(string.format("%d in the next round  ·  it starts in %ds", count(arena.players), left))
	tellMine(ctx, { kind = "arena", phase = "countdown", challenge = arena.challenge, players = count(arena.players), left = left }, function(p: Player): boolean
		return arena.players[p] ~= nil
	end)
	local c = challenge()
	return { ok = true, title = c.name, line = c.how .. string.format(" The round starts in %d seconds.", left) }
end

local function arenaStep(ctx: Types.Ctx, dt: number)
	local now = Gala.now()
	for p in arena.players do
		if not p.Parent or ctx.inside(p) ~= Plan.ID then
			arena.players[p] = nil
		end
	end
	local phase: string = arena.phase
	if phase == "idle" then
		return
	end
	local finishing = phase == "results"
	if next(arena.players) == nil and not finishing then
		arenaReset(ctx)
		return
	end
	if phase == "countdown" then
		if now >= arena.endsAt then
			arenaPlay(ctx)
		end
	elseif phase == "play" then
		local t = now - arena.startedAt
		local onDais: { Contender } = {}
		for player, c in arena.players do
			local pos = at(ctx, player)
			if pos and Plan.inArena(pos) then
				if arena.challenge == "spotlight" then
					if Plan.flat(pos, Plan.spotlightAt(t)) <= Plan.SPOT_RADIUS then
						c.points += 2 * dt
					end
				elseif arena.challenge == "coins" then
					for i, coin in arena.coins do
						if coin.back == 0 and Plan.flat(pos, coin.pos) <= 3.2 and pos.Y < 7 then
							c.points += 1
							coin.back = now + 0.6
							showCoin(ctx, i)
						end
					end
				elseif arena.challenge == "dais" then
					if Plan.flat(pos, Plan.ARENA.centre) <= Plan.ARENA.dais and pos.Y > 0.6 then
						table.insert(onDais, c)
					end
				end
			end
		end
		if #onDais == 1 then
			onDais[1].points += dt
		end
		for i, coin in arena.coins do
			if coin.back > 0 and now >= coin.back then
				coin.back = 0
				coin.pos = coinSpot(ctx)
				showCoin(ctx, i)
			end
		end
		if now - arena.lastScore >= 1 then
			arena.lastScore = now
			local rows = standings()
			if rows[1] then
				arenaBoard(string.format("%d seconds left", math.max(0, math.ceil(arena.endsAt - now))), string.format("Leading: %s  ·  %d", rows[1].name, rows[1].points))
			end
			tellMine(ctx, { kind = "arena", phase = "score", rows = rows, left = math.max(0, math.ceil(arena.endsAt - now)) }, function(p: Player): boolean
				return arena.players[p] ~= nil
			end)
		end
		if now >= arena.endsAt then
			arenaResults(ctx)
		end
	elseif phase == "results" then
		if now >= arena.endsAt then
			arenaReset(ctx)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The photo sets and the dance floor
---------------------------------------------------------------------------------------------------
local function pose(ctx: Types.Ctx, player: Player, id: unknown): { [string]: any }
	local set = if type(id) == "string" then Plan.photoById[id] else nil
	if not set then
		return { ok = false, why = "That isn't one of the photo sets." }
	end
	local pos = at(ctx, player)
	if not pos or Plan.flat(pos, set.mark.Position) > 16 then
		return { ok = false, why = "Step up to " .. set.name .. " to pose there." }
	end
	if busy(player) then
		return { ok = false, why = "You're in " .. ACTIVITY[busy(player) :: string] .. " just now." }
	end
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	moveTo(ctx, player, set.mark)
	local p = page(ctx, data)
	local paid = 0
	if not p.photos[set.id] then
		p.photos[set.id] = true
		paid = pay(ctx, player, R(ctx, "photoSet"), "A photo set")
	end
	if not p.sets[set.id] then
		p.sets[set.id] = true
		local all = true
		for _, s in Plan.PhotoSets do
			if not p.sets[s.id] then
				all = false
			end
		end
		if all then
			ctx.award(player, "photoSets")
		end
	end
	local got = 0
	for _, s in Plan.PhotoSets do
		if p.sets[s.id] then
			got += 1
		end
	end
	ctx.send(player, { op = "gala", kind = "pose", set = set.id, name = set.name, paid = paid, sets = got, of = #Plan.PhotoSets })
	return { ok = true, title = set.name, line = string.format("Choose a pose and take your photograph.%s", if paid > 0 then string.format("  +%d Gilt", paid) else "") }
end

local function danceStep(ctx: Types.Ctx, dt: number)
	for player in floorTime do
		if not player.Parent or ctx.inside(player) ~= Plan.ID then
			floorTime[player] = nil
		end
	end
	for _, player in here(ctx) do
		local pos = at(ctx, player)
		if pos and Plan.onFloor(pos) then
			local before = floorTime[player] or 0
			local after = before + dt
			floorTime[player] = after
			local data = ctx.data(player)
			if data then
				local p = page(ctx, data)
				if before < 8 and after >= 8 and not p.danced then
					p.danced = true
					ctx.award(player, "firstDance")
				end
				if after >= 60 then
					floorTime[player] = after - 60
					p.minutes += 1
					if p.minutes <= R(ctx, "danceMinutes") then
						local paid = pay(ctx, player, R(ctx, "danceMinute"), "The Dance Floor")
						ctx.send(player, { op = "gala", kind = "danced", minutes = p.minutes, of = R(ctx, "danceMinutes"), paid = paid })
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- The attraction
---------------------------------------------------------------------------------------------------
function Gala.build(ctx: Types.Ctx, parent: Instance)
	built = GalaBuild.build(parent, origin(ctx))
	juke.track = 1
	juke.startedAt = serverNow()
	juke.changeAt = Gala.now() + num(cfg(ctx).trackSeconds, Plan.TRACK_SECONDS)
	arena.challenge = Plan.challengeFor(Plan.day(Gala.time())).id
	arenaBoard("Join at the gate: up to twelve a round.")
	screenIdle()
	runwayBoard("")
end

function Gala.enter(_ctx: Types.Ctx, _player: Player): (CFrame?, string?)
	return Plan.ARRIVAL, nil
end

function Gala.leave(_ctx: Types.Ctx, player: Player, _why: string)
	local s = trivia.seats[player]
	if s then
		glow(s.podium, rgb(255, 214, 140), 0.5)
		trivia.seats[player] = nil
	end
	for i = #runway.models, 1, -1 do
		if runway.models[i].player == player and runway.phase == "signup" then
			table.remove(runway.models, i)
		end
	end
	if player.Parent then
		player:SetAttribute("RunwayModel", nil)
	end
	arena.players[player] = nil
	juke.votes[player] = nil
	runway.votes[player] = nil
	floorTime[player] = nil
end

function Gala.step(ctx: Types.Ctx, dt: number)
	if not built then
		return
	end
	if Gala.now() >= juke.changeAt then
		jukeNext(ctx)
	end
	danceStep(ctx, dt)
	triviaStep(ctx)
	runwayStep(ctx)
	arenaStep(ctx, dt)
end

function Gala.state(ctx: Types.Ctx, player: Player): { [string]: any }
	local data = ctx.data(player)
	local p = if data then page(ctx, data) else nil
	local now = Gala.now()
	local th = theme()
	local sets = {}
	for _, s in Plan.PhotoSets do
		sets[s.id] = p ~= nil and p.sets[s.id] == true
	end
	return {
		juke = jukeView(player),
		trivia = { phase = trivia.phase, seats = count(trivia.seats), left = math.max(0, math.ceil(trivia.endsAt - now)), seated = trivia.seats[player] ~= nil },
		runway = { phase = runway.phase, theme = if runway.phase ~= "idle" then th.name else nil, line = if runway.phase ~= "idle" then th.line else nil, models = #runway.models, left = math.max(0, math.ceil(runway.endsAt - now)), mine = modelOf(player) ~= nil },
		arena = { phase = arena.phase, challenge = arena.challenge, players = count(arena.players), left = math.max(0, math.ceil(arena.endsAt - now)), mine = arena.players[player] ~= nil, serverStart = arena.serverStart },
		busy = busy(player),
		today = {
			gilt = if p then p.gilt else 0,
			cap = R(ctx, "dailyGilt"),
			minutes = if p then math.min(p.minutes, R(ctx, "danceMinutes")) else 0,
			minutesCap = R(ctx, "danceMinutes"),
			sets = sets,
		},
	}
end

function Gala.ask(ctx: Types.Ctx, player: Player, r: { [string]: unknown }): { [string]: any }
	local act = r.act
	local what = r.what
	if act == "join" then
		if what == "trivia" then
			return triviaJoin(ctx, player)
		elseif what == "runway" then
			return runwayJoin(ctx, player)
		elseif what == "arena" then
			return arenaJoin(ctx, player)
		end
	elseif act == "quit" then
		if what == "trivia" and trivia.seats[player] then
			glow(trivia.seats[player].podium, rgb(255, 214, 140), 0.5)
			trivia.seats[player] = nil
			return { ok = true }
		elseif what == "runway" and runway.phase == "signup" and modelOf(player) then
			for i = #runway.models, 1, -1 do
				if runway.models[i].player == player then
					table.remove(runway.models, i)
				end
			end
			return { ok = true }
		elseif what == "arena" and arena.players[player] and arena.phase == "countdown" then
			arena.players[player] = nil
			return { ok = true }
		end
		return { ok = false, why = "Not just now." }
	elseif act == "answer" then
		return triviaAnswer(player, r.n)
	elseif act == "vote" then
		if what == "runway" then
			return runwayVote(player, r.n)
		elseif what == "juke" then
			local n = r.n
			if ctx.inside(player) ~= Plan.ID then
				return { ok = false, why = "Come into the Grand Ballroom first." }
			end
			if type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > #records() then
				return { ok = false, why = "That record isn't in the jukebox." }
			end
			juke.votes[player] = n
			local view = jukeView(player)
			view.ok = true
			return view
		end
	elseif act == "pose" then
		return pose(ctx, player, what)
	elseif act == "state" then
		local s = Gala.state(ctx, player)
		s.ok = true
		return s
	end
	return { ok = false, why = "That isn't something the house does." }
end

-- For tests.
function Gala.internals(): { [string]: any }
	return { trivia = trivia, runway = runway, arena = arena, juke = juke, floorTime = floorTime, built = built }
end

return Gala

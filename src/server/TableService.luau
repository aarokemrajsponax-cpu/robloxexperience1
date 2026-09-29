--!strict
-- The server owns every table: it deals from a seed, checks every filing, keeps the score and
-- the clock, and banks the run. Clients only predict, for feel.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Clock = require(ReplicatedStorage.Shared.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Deal = require(ReplicatedStorage.Shared.Deal)
local Nightly = require(ReplicatedStorage.Shared.Nightly)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Scoring = require(ReplicatedStorage.Shared.Scoring)
local Seed = require(ReplicatedStorage.Shared.Seed)
local Voice = require(ReplicatedStorage.Shared.Voice)

local Analytics = require(script.Parent.Analytics)
local Boards = require(script.Parent.Boards)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local Season = require(script.Parent.Season)

local TableService = {}

type SessionPiece = Deal.DealtPiece & { uid: number, filed: boolean }

export type Mode = "room" | "nightly" | "rehearsal"

type Session = {
	player: Player,
	model: Model,
	seat: Seat,
	room: Rooms.Room,
	mode: Mode,
	night: Nightly.Night?,
	roundGrades: { string },
	paused: boolean,
	finished: boolean,
	startedAt: number,
	state: "playing" | "roundEnd" | "banked" | "ended",
	round: number,
	seed: number,
	cases: { string },
	pieces: { [number]: SessionPiece },
	dealSize: number,
	remaining: number,
	nextUid: number,
	score: number,
	streak: number,
	runLength: number,
	lastCase: string?,
	runBestStreak: number,
	runFilings: number,
	runCorrect: number,
	roundsCleared: number,
	roundMistakes: number,
	roundBestStreak: number,
	roundFilings: number,
	roundCorrect: number,
	clock: { budget: number, left: number, running: boolean }?,
	lastFileAt: number,
	fileTimes: { number },
	flagged: boolean,
	lifted: boolean,
	log: { { any } },
	connections: { RBXScriptConnection },
}

local sessions: { [Player]: Session } = {}
local occupants: { [Model]: Player } = {}
local tableEvent = Remotes.event("Table")
local lastMessage: { [Player]: number } = {}

-- Hooks the rest of the server can set.
TableService.onSeated = function(_player: Player) end
TableService.say = function(_player: Player, _line: string) end
TableService.onUnlock = function(_player: Player, _room: string) end
-- Called after a scored Nightly is on the board (for Rivals).
TableService.onNightlyFinished = function(_player: Player) end
-- Set by the server: is the guest busy elsewhere (a Library duel)?
TableService.isBusy = function(_player: Player): boolean
	return false
end

local function send(player: Player, message: { [string]: any })
	tableEvent:FireClient(player, message)
end

local function tables(): { Model }
	local out = {}
	for _, m in CollectionService:GetTagged("MaisonTable") do
		if m:IsA("Model") then
			table.insert(out, m)
		end
	end
	table.sort(out, function(a, b)
		return tostring(a:GetAttribute("TableId")) < tostring(b:GetAttribute("TableId"))
	end)
	return out
end

local function chairOf(model: Model): Seat?
	local seat = model:FindFirstChild("Chair")
	return if seat and seat:IsA("Seat") then seat else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	local h = character:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		return h
	end
	return nil
end

local function setLids(model: Model, open: { string })
	local isOpen = {}
	for _, c in open do
		isOpen[c] = true
	end
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and string.find(d.Name, "^CaseLid") then
			local caseId = d:GetAttribute("CaseId")
			d.Transparency = if caseId and isOpen[caseId :: string] then 1 else 0.3
		end
	end
	model:SetAttribute("OpenCases", table.concat(open, ","))
end

local function publicPiece(p: SessionPiece): { [string]: any }
	return {
		uid = p.uid,
		id = p.id,
		name = p.name,
		case = p.case,
		value = p.value,
		rare = p.rare,
		seasonal = p.seasonal,
		mythic = p.mythic,
	}
end

local function clockState(s: Session): { [string]: any }?
	local c = s.clock
	if not c then
		return nil
	end
	return { budget = c.budget, left = c.left, running = c.running }
end

local function unlockMidnight(s: Session)
	local data = Profiles.get(s.player)
	if not data or data.flags.midnight then
		return
	end
	data.flags.midnight = true
	task.delay(2.4, TableService.say, s.player, Voice.Concierge.midnightUnlocked)
	TableService.onUnlock(s.player, "midnight")
	Analytics.custom(s.player, "Midnight unlocked", s.round)
end

local function dealRound(s: Session)
	local night = s.night
	local result
	if s.mode ~= "room" and night then
		-- The Nightly: the date decides every piece, identical on every server. Never Mythics.
		s.seed = Nightly.seed(night.key, s.round)
		result = Deal.generate(s.seed, s.room, s.round, Season.current().id, { allowMythic = false })
		if s.mode == "nightly" and s.round == 1 then
			-- Seeing the deal is the attempt: leaving now still counts.
			local data = Profiles.get(s.player)
			if data then
				data.nightly = { day = night.day, key = night.key, score = 0, grade = "Cleared", rounds = {}, room = night.room, finished = false }
			end
		end
	else
		s.seed = Seed.fresh()
		result = Deal.generate(s.seed, s.room, s.round, Season.current().id, { allowMythic = true })
		if s.room.id == "obsidian" and s.round >= 4 then
			unlockMidnight(s)
		end
	end
	s.cases = result.cases
	s.pieces = {}
	s.dealSize = #result.pieces
	s.remaining = #result.pieces
	s.roundMistakes = 0
	s.roundBestStreak = 0
	s.roundFilings = 0
	s.roundCorrect = 0
	local list = {}
	for _, p in result.pieces do
		s.nextUid += 1
		local sp: SessionPiece = table.clone(p) :: any
		sp.uid = s.nextUid
		sp.filed = false
		s.pieces[sp.uid] = sp
		table.insert(list, publicPiece(sp))
	end
	local budget = Clock.budget(s.room, s.dealSize)
	if budget then
		s.clock = { budget = budget, left = budget, running = not s.room.tuning.clockStartsOnLift }
	else
		s.clock = nil
	end
	s.state = "playing"
	table.insert(s.log, { "deal", s.round, s.seed, os.clock() } :: { any })
	setLids(s.model, s.cases)
	send(s.player, {
		op = "deal",
		mode = s.mode,
		night = if night then night.key else nil,
		round = s.round,
		room = s.room.id,
		cases = s.cases,
		pieces = list,
		score = s.score,
		clock = clockState(s),
	})

	-- The Concierge notices the first gilded piece a guest ever sees, and any Mythic.
	local data = Profiles.get(s.player)
	for _, p in s.pieces do
		if p.mythic then
			task.delay(1.4, TableService.say, s.player, Voice.Concierge.mythic)
			break
		end
	end
	if data and not data.flags.seenRare then
		for _, p in s.pieces do
			if p.rare then
				data.flags.seenRare = true
				task.delay(2.2, TableService.say, s.player, Voice.Concierge.rare)
				break
			end
		end
	end
end

local function newSession(player: Player, model: Model, seat: Seat, mode: Mode): Session
	local night: Nightly.Night? = if mode ~= "room" then Nightly.at() else nil
	local roomId = if night then night.room else tostring(model:GetAttribute("Room") or "salon")
	local room = Rooms.get(roomId) or (Rooms.get("salon") :: Rooms.Room)
	return {
		player = player,
		model = model,
		seat = seat,
		room = room,
		mode = mode,
		night = night,
		roundGrades = {},
		paused = false,
		finished = false,
		startedAt = os.time(),
		state = "playing",
		round = 1,
		seed = 0,
		cases = {},
		pieces = {},
		dealSize = 0,
		remaining = 0,
		nextUid = 0,
		score = 0,
		streak = 0,
		runLength = 0,
		lastCase = nil,
		runBestStreak = 0,
		runFilings = 0,
		runCorrect = 0,
		roundsCleared = 0,
		roundMistakes = 0,
		roundBestStreak = 0,
		roundFilings = 0,
		roundCorrect = 0,
		clock = nil,
		lastFileAt = 0,
		fileTimes = {},
		flagged = false,
		lifted = false,
		log = {},
		connections = {},
	}
end

local function resetRun(s: Session)
	s.round = 1
	s.score = 0
	s.streak = 0
	s.runLength = 0
	s.lastCase = nil
	s.runBestStreak = 0
	s.runFilings = 0
	s.runCorrect = 0
	s.roundsCleared = 0
	s.lifted = false
	s.fileTimes = {}
	s.flagged = false
	s.log = {}
	s.roundGrades = {}
	s.finished = false
	s.startedAt = os.time()
	s.model:SetAttribute("Score", 0)
	s.model:SetAttribute("Multiplier", 1)
end

-- Banks the run: records it, pays Gilt, and posts it to the boards. Returns the summary.
local function bank(s: Session, reason: string?): { [string]: any }
	local player = s.player
	local accuracy = if s.runFilings > 0 then s.runCorrect / s.runFilings else 0
	local gradePoints, grade = Scoring.runGrade(accuracy, s.runBestStreak, s.runCorrect)
	local summary: { [string]: any } = {
		op = "banked",
		score = s.score,
		grade = grade,
		gradePoints = gradePoints,
		rounds = s.roundsCleared,
		reachedRound = s.round,
		accuracy = accuracy,
		bestStreak = s.runBestStreak,
		reason = reason,
		gilt = 0,
		best = 0,
		newBest = false,
	}
	if s.score <= 0 and s.runCorrect == 0 then
		return summary
	end
	local data = Profiles.get(player)
	if data then
		data.stats.runs += 1
		local roomId = s.room.id
		local previous = data.best[roomId] or 0
		if s.score > previous then
			data.best[roomId] = s.score
			summary.newBest = previous > 0
		end
		summary.best = data.best[roomId]
		local paid = Gilt.pay(player, data, Scoring.giltForRun(s.score), "Banked run: " .. roomId)
		summary.gilt = paid
		summary.giltTotal = data.gilt
	end
	if not s.flagged then
		Boards.submit(player, s.room.id, s.score)
	end
	Analytics.step(player, 10)
	Analytics.custom(player, "Run banked", s.score, { room = s.room.id, rounds = s.roundsCleared, grade = grade })
	return summary
end

-- The end of a Nightly attempt (or rehearsal): the Nightly card, the board, the log.
local function finishNightly(s: Session, reason: string?, notify: boolean)
	if s.finished then
		return
	end
	s.finished = true
	s.state = "banked"
	if s.clock then
		s.clock.running = false
	end
	local night = s.night :: Nightly.Night
	local player = s.player
	local accuracy = if s.runFilings > 0 then s.runCorrect / s.runFilings else 0
	local _, grade = Scoring.runGrade(accuracy, s.runBestStreak, s.runCorrect)
	local rounds = table.clone(s.roundGrades)
	for i = #rounds + 1, Config.data.Nightly.rounds do
		rounds[i] = "" -- an empty mark for a round the clock ended
	end
	local scored = s.mode == "nightly"
	local card: { [string]: any } = {
		op = "nightlyCard",
		key = night.key,
		room = s.room.id,
		score = s.score,
		grade = grade,
		rounds = rounds,
		scored = scored,
		reason = reason,
		gilt = 0,
	}
	local data = Profiles.get(player)
	if scored and data then
		data.nightly = { day = night.day, key = night.key, score = s.score, grade = grade, rounds = rounds, room = night.room, finished = true }
		data.stats.nightlies += 1
		card.gilt = Gilt.pay(player, data, Config.data.Nightly.gilt, "The Nightly")
	end
	local finishedAt = os.time()
	local log = s.log
	local flagged = s.flagged
	local score = s.score
	task.spawn(function()
		if scored then
			local standing = Boards.submitNightly(player, night.key, score, finishedAt, flagged)
			card.rank = standing.rank
			card.total = standing.total
			card.percentile = standing.percentile
			card.connections = Boards.nightlyConnections(player, night.key, score)
			Boards.saveNightlyLog(player, night.key, log)
			Analytics.custom(player, "Nightly attempt", score, {
				room = night.room,
				grade = grade,
				percentile = standing.percentile,
				seconds = finishedAt - s.startedAt,
			})
			TableService.onNightlyFinished(player)
		end
		if notify and player.Parent == Players then
			send(player, card)
		end
	end)
end

local function endSession(player: Player, why: string)
	local s = sessions[player]
	if not s then
		return
	end
	sessions[player] = nil
	s.state = "ended"
	for _, c in s.connections do
		c:Disconnect()
	end
	if occupants[s.model] == player then
		occupants[s.model] = nil
	end
	s.model:SetAttribute("Occupant", nil)
	s.model:SetAttribute("Score", 0)
	s.model:SetAttribute("Multiplier", 1)
	setLids(s.model, { "watches", "jewelry", "money", "keys", "accessories", "collectibles" })
	local summary: { [string]: any }? = nil
	if s.mode == "nightly" and not s.finished and s.state ~= "banked" then
		-- Leaving a scored Nightly still counts: the attempt is recorded as it stands.
		finishNightly(s, "left", false)
	elseif s.mode == "room" and s.score > 0 and why ~= "banked" then
		summary = bank(s, why)
		if s.remaining > 0 and s.remaining < s.dealSize then
			Analytics.custom(player, "Left mid-round", s.round, { room = s.room.id })
		end
	end
	local weld = s.seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	if player.Parent == Players then
		send(player, { op = "left", summary = summary })
	end
end

local function roundComplete(s: Session)
	s.state = "roundEnd"
	if s.clock then
		s.clock.running = false
	end
	local accuracy = if s.roundFilings > 0 then s.roundCorrect / s.roundFilings else 1
	local clockFraction = if s.clock then s.clock.left / s.clock.budget else nil
	local gradePoints, grade = Scoring.grade(accuracy, s.roundBestStreak, s.dealSize, clockFraction)
	local bonus = Scoring.roundEnd(s.round, s.roundMistakes, s.roundBestStreak, if s.clock then s.clock.left else nil, s.room.tuning.multiplier)
	s.score += bonus.total
	s.roundsCleared += 1
	s.model:SetAttribute("Score", s.score)

	table.insert(s.roundGrades, grade)
	local data = Profiles.get(s.player)
	if data then
		data.stats.rounds += 1
		if grade == "Flawless" then
			data.stats.flawless += 1
		end
		local roomId = s.room.id
		if s.mode == "room" and s.round > (data.bestRound[roomId] or 0) then
			data.bestRound[roomId] = s.round
		end
	end
	local last = s.mode ~= "room" and s.round >= Config.data.Nightly.rounds
	if s.round == 1 then
		Analytics.step(s.player, 8)
	elseif s.round == 3 then
		Analytics.step(s.player, 9)
	end
	send(s.player, {
		op = "roundEnd",
		round = s.round,
		grade = grade,
		gradePoints = gradePoints,
		bonus = bonus,
		score = s.score,
		accuracy = accuracy,
		bestStreak = s.roundBestStreak,
		mistakes = s.roundMistakes,
		mode = s.mode,
		room = s.room.id,
		last = last,
	})
	if last then
		finishNightly(s, nil, true)
	end
end

local function register(player: Player, piece: SessionPiece, roomId: string)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local entry = data.register[piece.id]
	if entry then
		entry.count += 1
		local order = { salon = 1, velvet = 2, obsidian = 3, midnight = 4 }
		if (order[roomId] or 0) > (order[entry.best] or 0) then
			entry.best = roomId
		end
	else
		data.register[piece.id] = { first = os.time(), count = 1, best = roomId }
	end
	data.stats.correct += 1
end

local function checkFairPlay(s: Session, now: number)
	local fp = Config.data.FairPlay
	table.insert(s.fileTimes, now)
	local n = #s.fileTimes
	if n >= fp.flagAverageAfter then
		local span = s.fileTimes[n] - s.fileTimes[n - fp.flagAverageAfter + 1]
		if span / (fp.flagAverageAfter - 1) < fp.flagAverage then
			s.flagged = true
		end
	end
	if n > fp.flagRateOver then
		local span = s.fileTimes[n] - s.fileTimes[n - fp.flagRateOver]
		if span > 0 and fp.flagRateOver / span > fp.flagRatePerSecond then
			s.flagged = true
		end
	end
	if n > 200 then
		table.remove(s.fileTimes, 1)
	end
end

local function file(s: Session, uid: number, caseId: string)
	if s.state ~= "playing" then
		return
	end
	local piece = s.pieces[uid]
	if not piece or piece.filed then
		return
	end
	if not table.find(s.cases, caseId) then
		return
	end
	local now = os.clock()
	if now - s.lastFileAt < Config.data.FairPlay.minGap then
		send(s.player, { op = "rejected", uid = uid })
		return
	end
	s.lastFileAt = now
	checkFairPlay(s, now)
	table.insert(s.log, { "file", now, uid, caseId } :: { any })

	local data = Profiles.get(s.player)
	if data then
		data.stats.filings += 1
	end
	s.runFilings += 1
	s.roundFilings += 1
	local mult = s.room.tuning.multiplier
	local correct = piece.case == caseId
	local points, setBonus, penalty = 0, 0, 0
	if correct then
		piece.filed = true
		s.remaining -= 1
		s.runCorrect += 1
		s.roundCorrect += 1
		s.streak += 1
		s.roundBestStreak = math.max(s.roundBestStreak, s.streak)
		s.runBestStreak = math.max(s.runBestStreak, s.streak)
		if s.lastCase == caseId then
			s.runLength += 1
		else
			s.runLength = 1
		end
		s.lastCase = caseId
		points = Scoring.filingPoints(piece, s.streak, mult)
		setBonus = Scoring.setBonus(s.runLength)
		s.score += points + setBonus
		if s.clock then
			s.clock.left = Clock.refund(s.room, Scoring.multiplier(s.streak), s.clock.left, s.clock.budget)
		end
		register(s.player, piece, s.room.id)
		if s.runCorrect == 1 then
			Analytics.step(s.player, 7)
			local pressed = Analytics.stamp(s.player, "Play pressed")
			if pressed then
				Analytics.custom(s.player, "Seconds from Play to first filing", now - pressed)
			end
		end
	else
		s.streak = 0
		s.runLength = 0
		s.lastCase = nil
		s.roundMistakes += 1
		local wrongSetting = if data then data.settings.wrongCase else nil
		if wrongSetting == "Costs points too" and s.mode == "room" then
			penalty = math.min(s.score, Scoring.wrongPenalty(s.round))
			s.score -= penalty
		end
		if s.clock then
			s.clock.left = Clock.penalty(s.room, s.clock.left)
		end
	end
	local multiplier = Scoring.multiplier(s.streak)
	s.model:SetAttribute("Score", s.score)
	s.model:SetAttribute("Multiplier", multiplier)
	send(s.player, {
		op = "filed",
		uid = uid,
		case = caseId,
		correct = correct,
		points = points,
		setBonus = setBonus,
		penalty = penalty,
		score = s.score,
		streak = s.streak,
		multiplier = multiplier,
		runLength = s.runLength,
		remaining = s.remaining,
		clock = clockState(s),
	})
	if s.remaining == 0 then
		roundComplete(s)
	end
end

local function clockRanOut(s: Session)
	if s.mode ~= "room" then
		-- In the Nightly the run ends where the clock stops, and still counts.
		finishNightly(s, Voice.fill(Voice.Table.clockRanOut, { round = Voice.roman(s.round) }), true)
		return
	end
	s.state = "banked"
	if s.clock then
		s.clock.running = false
		s.clock.left = 0
	end
	local summary = bank(s, Voice.fill(Voice.Table.clockRanOut, { round = Voice.roman(s.round) }))
	send(s.player, summary)
	resetRun(s)
end

-- Seats a guest at a table. `teleport` walks them there instantly (Straight to the table).
function TableService.seat(player: Player, model: Model, teleport: boolean?, wanted: Mode?): (boolean, string?)
	if sessions[player] or TableService.isBusy(player) then
		return false, "seated"
	end
	local data = Profiles.get(player)
	local mode: Mode = wanted or "room"
	if mode == "nightly" then
		-- One scored attempt per UTC day; after that, unlimited unscored rehearsals.
		local night = Nightly.at()
		if data and data.nightly.day == night.day then
			mode = "rehearsal"
		end
	elseif model:GetAttribute("Room") == "midnight" and not (data and data.flags.midnight) then
		return false, "locked"
	end
	if occupants[model] then
		return false, "taken"
	end
	local seat = chairOf(model)
	local humanoid = humanoidOf(player)
	if not seat or not humanoid then
		return false, "unavailable"
	end
	local character = player.Character :: Model
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false, "unavailable"
	end
	if teleport then
		character:PivotTo(seat.CFrame * CFrame.new(0, 3, 1.5))
	elseif (root.Position - seat.Position).Magnitude > 12 then
		return false, "far"
	end
	occupants[model] = player
	seat:Sit(humanoid)
	local waited = 0
	while humanoid.SeatPart ~= seat and waited < 1.5 do
		task.wait(0.05)
		waited += 0.05
	end
	if humanoid.SeatPart ~= seat then
		occupants[model] = nil
		return false, "unavailable"
	end
	local s = newSession(player, model, seat, mode)
	sessions[player] = s
	model:SetAttribute("Occupant", player.UserId)
	table.insert(s.connections, humanoid.Seated:Connect(function(active: boolean, part: BasePart?)
		if not active or part ~= seat then
			endSession(player, "stood")
		end
	end))
	table.insert(s.connections, humanoid.Died:Connect(function()
		endSession(player, "died")
	end))
	send(player, { op = "seated", table = model:GetAttribute("TableId"), room = s.room.id, mode = s.mode, centre = model:GetAttribute("Centre") })
	Analytics.step(player, 5)
	TableService.onSeated(player)
	task.delay(0.6, function()
		if sessions[player] == s then
			dealRound(s)
		end
	end)
	return true, nil
end

function TableService.isSeated(player: Player): boolean
	return sessions[player] ~= nil
end

-- The nearest free table in a room, for Straight to the table.
function TableService.freeTable(roomId: string, near: Vector3?): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, m in tables() do
		local r = m:GetAttribute("Room")
		if (roomId == "any" or r == roomId) and r ~= "midnight" and r ~= "library" and r ~= "ballroom" and not occupants[m] then
			local centre = m:GetAttribute("Centre")
			local d = if near and typeof(centre) == "Vector3" then (centre - near).Magnitude else 0
			if d < bestDistance then
				best = m
				bestDistance = d
			end
		end
	end
	return best
end

local function onMessage(player: Player, message: unknown)
	if type(message) ~= "table" then
		return
	end
	local now = os.clock()
	if lastMessage[player] and now - lastMessage[player] < 0.03 then
		return
	end
	lastMessage[player] = now
	local m = message :: { [string]: unknown }
	local op = m.op
	local s = sessions[player]
	if not s then
		return
	end
	if op == "lift" then
		local uid = m.uid
		if type(uid) ~= "number" or not s.pieces[uid] then
			return
		end
		if not s.lifted then
			s.lifted = true
			Analytics.step(player, 6)
		end
		if s.clock and not s.clock.running and s.state == "playing" then
			s.clock.running = true
			send(player, { op = "clock", clock = clockState(s) })
		end
	elseif op == "file" then
		local uid, caseId = m.uid, m.case
		if type(uid) ~= "number" or type(caseId) ~= "string" or Catalogue.caseById[caseId] == nil then
			return
		end
		file(s, uid, caseId)
	elseif op == "next" then
		if s.state == "roundEnd" then
			s.round += 1
			dealRound(s)
		end
	elseif op == "pause" then
		-- The clock freezes while a panel is open, except in the Nightly (nobody pauses to think).
		if s.mode == "room" then
			s.paused = m.on == true
		end
	elseif op == "bank" then
		if s.mode == "room" and (s.state == "roundEnd" or s.state == "playing") then
			s.state = "banked"
			local summary = bank(s, nil)
			send(player, summary)
			resetRun(s)
		end
	elseif op == "again" then
		if s.state == "banked" then
			if s.mode ~= "room" then
				-- After the card: another go at tonight's table, scored only if it's a new night.
				local night = Nightly.at()
				local data = Profiles.get(player)
				s.mode = if data and data.nightly.day == night.day then "rehearsal" else "nightly"
				s.night = night
				s.room = Rooms.get(night.room) or s.room
			end
			resetRun(s)
			dealRound(s)
		end
	elseif op == "leave" then
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Sit = false
		end
		endSession(player, "left")
	end
end

function TableService.start()
	tableEvent.OnServerEvent:Connect(onMessage)
	for _, m in tables() do
		if m:GetAttribute("Duel") ~= nil or m:GetAttribute("Ballroom") then
			continue -- the Library's and the Ballroom's tables have their own services
		end
		local seat = chairOf(m)
		local prompt = seat and seat:FindFirstChild("SitPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player: Player)
				local ok, why = TableService.seat(player, m, false, "room")
				if not ok and why == "taken" then
					TableService.say(player, "That table is taken. Another is free.")
				elseif not ok and why == "locked" then
					TableService.say(player, Voice.Concierge.midnightLocked)
				end
			end)
		end
		local nightly = seat and seat:FindFirstChild("NightlyPrompt")
		if nightly and nightly:IsA("ProximityPrompt") then
			nightly.Triggered:Connect(function(player: Player)
				local ok, why = TableService.seat(player, m, false, "nightly")
				if not ok and why == "taken" then
					TableService.say(player, "That table is taken. Another is free.")
				end
			end)
		end
	end
	-- Timed rooms: the server owns the clock.
	RunService.Heartbeat:Connect(function(dt: number)
		for _, s in sessions do
			local c = s.clock
			if c and c.running and s.state == "playing" and not s.paused then
				c.left -= dt
				if c.left <= 0 then
					clockRanOut(s)
				end
			end
		end
	end)
	-- Hide the Sit prompt on occupied tables for everyone.
	task.spawn(function()
		while true do
			for _, m in tables() do
				if m:GetAttribute("Duel") ~= nil or m:GetAttribute("Ballroom") then
					continue
				end
				local seat = chairOf(m)
				local prompt = seat and seat:FindFirstChild("SitPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Enabled = not occupants[m]
				end
				local nightly = seat and seat:FindFirstChild("NightlyPrompt")
				if nightly and nightly:IsA("ProximityPrompt") then
					nightly.Enabled = not occupants[m]
				end
			end
			task.wait(0.5)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		endSession(player, "left")
		lastMessage[player] = nil
	end)
	-- Every table starts with all cases open (lids hidden).
	for _, m in tables() do
		setLids(m, { "watches", "jewelry", "money", "keys", "accessories", "collectibles" })
	end
end

return TableService

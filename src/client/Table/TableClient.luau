--!strict
-- The table, on the guest's screen. Sitting down opens the sorting screen (SortScreen): the deal
-- is laid out on the tray, pieces are dragged or tapped into their cases, right and wrong are
-- shown at once, the score and the clock run in the header. The phone predicts right or wrong
-- instantly; the server confirms every filing and its answer always wins.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Config = require(ReplicatedStorage.Shared.Config)
local Duel = require(ReplicatedStorage.Shared.Duel)
local Layout = require(ReplicatedStorage.Shared.Layout)
local LightsOut = require(ReplicatedStorage.Shared.LightsOut)
local Music = require(ReplicatedStorage.Shared.Music)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rooms = require(ReplicatedStorage.Shared.Rooms)
local Scoring = require(ReplicatedStorage.Shared.Scoring)
local Voice = require(ReplicatedStorage.Shared.Voice)

local CameraRig = require(script.Parent.Parent.Camera)
local Sound = require(script.Parent.Parent.Sound)
local State = require(script.Parent.Parent.State)
local Root = require(script.Parent.Parent.UI.Root)
local Hud = require(script.Parent.Parent.UI.Hud)
local RoundPanel = require(script.Parent.Parent.UI.RoundPanel)
local RevivePanel = require(script.Parent.Parent.UI.RevivePanel)
local NightlyCard = require(script.Parent.Parent.UI.NightlyCard)
local DuelPanel = require(script.Parent.Parent.UI.DuelPanel)
local Dialogue = require(script.Parent.Parent.UI.Dialogue)
local BallroomPanel = require(script.Parent.Parent.UI.BallroomPanel)
local Invite = require(script.Parent.Parent.UI.Invite)
local Toast = require(script.Parent.Parent.UI.Toast)
local Counter = require(script.Parent.Counter)
local DuelView = require(script.Parent.DuelView)
local BallroomView = require(script.Parent.BallroomView)
local RivalPlate = require(script.Parent.RivalPlate)
local Flourish = require(script.Parent.Flourish)
local SortScreen = require(script.Parent.SortScreen)

local TableClient = {}

local player = Players.LocalPlayer
local tableEvent = Remotes.event("Table")
local T = Layout.Table

type Piece = {
	uid: number,
	id: string,
	name: string,
	case: string,
	value: number,
	rare: boolean,
	seasonal: boolean,
	mythic: boolean,
	filed: boolean,
	pending: boolean,
}

type Snapshot = { score: number, streak: number, runLength: number, lastCase: string?, multiplier: number }

local seatedModel: Model? = nil
local centre = Vector3.zero
local tableFrame = CFrame.new() -- the table's own frame: +Z toward the cases
local roomId = "salon"
local tableMode = "room" -- "room", "nightly", "rehearsal", "duel" or "ballroom"
local clockBudget: number? = nil
local lowPlayed = false
local round = 1
local openCases: { string } = {}
local pieces: { [number]: Piece } = {}
local playing = false
local server: Snapshot = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
local local_: Snapshot = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
local clockLeft: number? = nil
local clockRunning = false
local paused = false
local controls: any = nil
local toTableCallbacks: { () -> () } = {}
local seatings = 0
local hintPending = false

-- The Library and the Ballroom count pieces, not points.
local duelRemaining = 0
local fumbleUntil = 0
local awayPaused = false
local ballroomKeys = 0

TableClient.Seated = Instance.new("BindableEvent")
TableClient.Left = Instance.new("BindableEvent")
-- A run was banked (with the Gilt it paid): for the offer after a run.
TableClient.Banked = Instance.new("BindableEvent")

local function localFolder(): Folder
	local f = Workspace:FindFirstChild("MaisonLocal")
	if f and f:IsA("Folder") then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "MaisonLocal"
	nf.Parent = Workspace
	return nf
end

localFolder()

-- Runs one step of the table's setup or a message's handling; if it fails, it says so in the
-- Output (and on screen in Studio) and the rest carries on. Sorting must never be blocked by
-- something decorative failing.
local function safely(what: string, fn: (...any) -> (), ...: any): boolean
	local args = table.pack(...)
	local message = ""
	local ok = xpcall(function()
		fn(table.unpack(args, 1, args.n))
	end, function(e: any)
		message = debug.traceback(tostring(e))
	end)
	if not ok then
		warn(string.format("[Maison] Table: %s failed: %s", what, message))
	end
	return ok
end

-- Whether you're at a table (the 2D sorting screen doesn't need the 3D table to be streamed in).
local seatedNow = false

local function getControls(): any
	if controls then
		return controls
	end
	local ok, module = pcall(function()
		return require((player:WaitForChild("PlayerScripts") :: any):WaitForChild("PlayerModule") :: ModuleScript) :: any
	end)
	if ok and module then
		controls = module:GetControls()
	end
	return controls
end

local function room(): Rooms.Room
	if roomId == "library" then
		return Duel.room(round)
	elseif roomId == "ballroom" then
		return LightsOut.room(0)
	end
	return Rooms.get(roomId) or (Rooms.get("salon") :: Rooms.Room)
end

local function isOpen(caseId: string): boolean
	return table.find(openCases, caseId) ~= nil
end

local function counting(): boolean
	return tableMode == "duel" or tableMode == "ballroom"
end

local function namesAllowed(): boolean
	return room().tuning.names and State.get("pieceNames") ~= "Never"
end

local function roomTitle(): string
	if tableMode == "duel" then
		return Voice.Library.title
	elseif tableMode == "ballroom" then
		return Voice.Ballroom.title
	elseif tableMode == "nightly" or tableMode == "rehearsal" then
		-- Tonight's table is played under its room's rules (and clock); say which.
		return "Tonight's table · " .. room().name
	end
	return room().name
end

local function roundTitle(): string
	if tableMode == "duel" then
		return "Hand " .. tostring(round)
	elseif tableMode == "ballroom" then
		return "Lights Out"
	end
	return "Round " .. Voice.roundLabel(round, State.get("roundNumbers"))
end

-- The header: points and multiplier in the rooms; pieces left in the Library and the Ballroom.
local function updateHeader()
	if tableMode == "duel" then
		local rival = DuelView.rivalRemaining()
		SortScreen.setLine(string.format("%d left", duelRemaining), if rival then string.format("Rival · %d left", rival) else "Your felt")
		Hud.setDuelLine(duelRemaining, rival, clockLeft)
	elseif tableMode == "ballroom" then
		local cap = Config.data.Ballroom.capacity
		SortScreen.setLine(string.format("%d of %d", duelRemaining, cap), string.format("On your felt · %d Keys", ballroomKeys))
		Hud.setTextLine(string.format("felt %d of %d   ·   %d Keys", duelRemaining, cap, ballroomKeys))
		BallroomView.setFelt(duelRemaining, ballroomKeys)
	else
		SortScreen.setScore(local_.score, local_.multiplier)
		Hud.setLine(RoundPanel.number(local_.score), local_.multiplier, clockLeft)
	end
	SortScreen.setClock(if clockLeft and clockBudget then clockLeft else nil, clockBudget)
end

local function setScore(value: number, multiplier: number)
	local model = seatedModel
	if model then
		if counting() then
			Counter.set(model, duelRemaining)
		else
			Counter.set(model, value)
			Counter.setMultiplier(model, multiplier)
		end
	end
	updateHeader()
end

local function updateClock()
	if clockLeft and clockBudget then
		SortScreen.setClock(clockLeft, clockBudget)
		if (clockLeft :: number) <= 10 and not lowPlayed and clockRunning then
			lowPlayed = true
			Sound.play("low", 0.4)
		end
	end
end

-- Everything that follows a filing, predicted locally before the server answers.
local function predict(p: Piece, caseId: string): boolean
	local correct = p.case == caseId
	if correct then
		local_.streak += 1
		if local_.lastCase == caseId then
			local_.runLength += 1
		else
			local_.runLength = 1
		end
		local_.lastCase = caseId
		if counting() then
			duelRemaining = math.max(0, duelRemaining - 1)
			return correct
		end
		local mult = room().tuning.multiplier
		local_.score += Scoring.filingPoints(p, local_.streak, mult) + Scoring.setBonus(local_.runLength)
		local_.multiplier = Scoring.multiplier(local_.streak)
	else
		local_.streak = 0
		local_.runLength = 0
		local_.lastCase = nil
		local_.multiplier = 1
		if counting() then
			-- A wrong case costs a short fumble: the hand can't lift for a moment.
			fumbleUntil = os.clock() + (if tableMode == "ballroom" then Config.data.Ballroom.fumble else Config.data.Library.fumble)
			return correct
		end
		if State.get("wrongCase") == "Costs points too" then
			local_.score = math.max(0, local_.score - Scoring.wrongPenalty(round))
		end
	end
	return correct
end

local function file(uid: number, caseId: string)
	local p = pieces[uid]
	if not p or p.filed or p.pending or not playing then
		return
	end
	if not isOpen(caseId) then
		SortScreen.home(uid)
		return
	end
	p.pending = true
	local before = table.clone(local_)
	local correct = predict(p, caseId)
	if correct then
		p.filed = true
		SortScreen.correct(uid, caseId, if counting() then nil else local_.score - before.score, local_.multiplier)
		SortScreen.filed(true)
		Sound.chime(local_.streak)
		if p.rare or p.mythic then
			Sound.shimmer()
		end
		task.delay(0.28, function()
			Sound.play("place", 0.4)
		end)
		if not counting() and table.find(Config.data.Sorting.streakMoments, local_.streak) then
			local n, m = local_.streak, local_.multiplier
			task.delay(0.15, function()
				SortScreen.streak(n, m)
				Sound.play("combo", 0.45)
			end)
		end
	else
		SortScreen.wrong(uid, caseId, before.streak, if counting() then nil else before.score - local_.score)
		SortScreen.filed(false)
		Sound.wrong()
		if before.streak >= 3 then
			Sound.play("streakLost", 0.3)
		end
	end
	setScore(local_.score, local_.multiplier)
	tableEvent:FireServer({ op = "file", uid = uid, case = caseId })
end

-- Whether a piece may be lifted now; a fumble in the Library or the Ballroom says no.
local function canLift(uid: number): boolean
	local p = pieces[uid]
	if not p or p.filed or p.pending or not playing or Root.isOpen() then
		return false
	end
	if os.clock() < fumbleUntil then
		SortScreen.refuse(uid)
		return false
	end
	return true
end

local function onLift(uid: number, _mode: string)
	Sound.play("pickup", 0.4)
	tableEvent:FireServer({ op = "lift", uid = uid })
end

local function infoFor(data: { [string]: any }): Piece
	return {
		uid = data.uid,
		id = data.id,
		name = data.name,
		case = data.case,
		value = data.value,
		rare = data.rare == true,
		seasonal = data.seasonal == true,
		mythic = data.mythic == true,
	} :: any
end

-- A new deal: the tray is laid with it.
-- (defined below: the whole of sitting down)
local onSeated: (message: { [string]: any }) -> ()

local function renderDeal(message: { [string]: any })
	if not seatedNow or not SortScreen.isOpen() then
		-- The deal is the proof you're at a table: if the "seated" message never landed, sit down
		-- properly now (keys, camera, controls), so nobody ever sorts on a half-set table.
		warn("[Maison] Table: a deal arrived before the seat was set up; setting it up now.")
		safely("sitting down from the deal", onSeated, { table = message.table, room = message.room, mode = message.mode })
		if not SortScreen.isOpen() then
			SortScreen.open(roomTitle(), roundTitle())
		end
	end
	pieces = {}
	round = message.round
	roomId = message.room or roomId
	tableMode = message.mode or "room"
	Sound.setIntensity(Music.intensity(round))
	openCases = message.cases
	local r = room()
	SortScreen.setRound(roomTitle(), roundTitle())
	SortScreen.setRules(namesAllowed(), r.tuning.guide, r.tuning.guideDelay)
	SortScreen.setCases(openCases)
	local list = {}
	for _, data in message.pieces :: { { [string]: any } } do
		local p = infoFor(data)
		p.filed = false
		p.pending = false
		pieces[p.uid] = p
		table.insert(list, p)
	end
	SortScreen.deal(list :: any)
	for i = 1, #list, 3 do
		task.delay((i - 1) * 0.045, function()
			Sound.play("deal", 0.16)
		end)
	end
	playing = true
	SortScreen.setPlaying(true)
	if hintPending then
		hintPending = false
		task.delay(0.6, function()
			if playing and seatedNow then
				SortScreen.hint(true)
			end
		end)
	end
	lowPlayed = false
	if message.clock then
		clockLeft = message.clock.left
		clockRunning = message.clock.running
		clockBudget = message.clock.budget
	else
		clockLeft = nil
		clockRunning = false
		clockBudget = nil
	end
	if counting() then
		duelRemaining = #list
		fumbleUntil = 0
		-- Every hand starts clean; in the rooms the streak carries from round to round.
		local_ = { score = message.score, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
		server = table.clone(local_)
	else
		server.score = message.score
		local_.score = message.score
	end
	setScore(local_.score, local_.multiplier)
	for _, p in list do
		if p.mythic then
			Sound.shimmer()
			break
		end
	end
end

-- Pieces arriving mid-hand (a parcel, the Ballroom's dumbwaiter).
local function addPieces(list: { { [string]: any } }, remaining: number?)
	if not playing then
		return
	end
	local fresh = {}
	for _, data in list do
		local p = infoFor(data)
		p.filed = false
		p.pending = false
		pieces[p.uid] = p
		table.insert(fresh, p)
	end
	SortScreen.add(fresh :: any)
	duelRemaining = if remaining then remaining else duelRemaining + #list
	setScore(local_.score, local_.multiplier)
end

local function onFiled(message: { [string]: any })
	local p = pieces[message.uid]
	server.score = message.score
	server.streak = message.streak
	server.runLength = message.runLength
	server.multiplier = message.multiplier
	server.lastCase = if message.correct then message.case else nil
	if p then
		p.pending = false
		-- A quiet correction if the prediction disagreed.
		if message.correct and not p.filed then
			p.filed = true
			SortScreen.intoCase(p.uid, message.case)
		elseif not message.correct and p.filed then
			p.filed = false
			SortScreen.home(p.uid)
		end
	end
	local_.score = server.score
	local_.streak = server.streak
	local_.runLength = server.runLength
	local_.multiplier = server.multiplier
	local_.lastCase = server.lastCase
	if message.clock then
		clockLeft = message.clock.left
		clockRunning = message.clock.running
	end
	if counting() then
		if type(message.remaining) == "number" then
			duelRemaining = message.remaining
		end
		if type(message.keys) == "number" then
			ballroomKeys = message.keys
		end
		if type(message.fumble) == "number" then
			fumbleUntil = math.max(fumbleUntil, os.clock() + message.fumble)
		end
	end
	setScore(local_.score, local_.multiplier)
end

local function stopPlay()
	playing = false
	SortScreen.setPlaying(false)
end

local function clearTray()
	pieces = {}
	SortScreen.clear()
end

local function sendNext()
	tableEvent:FireServer({ op = "next" })
end

local function sendBank()
	tableEvent:FireServer({ op = "bank" })
end

function TableClient.leave()
	RoundPanel.close()
	tableEvent:FireServer({ op = "leave" })
end

local function onRoundEnd(message: { [string]: any })
	stopPlay()
	local_.score = message.score
	server.score = message.score
	setScore(local_.score, local_.multiplier)
	Sound.play("round", 0.4)
	Sound.briefDip(3)
	if message.last then
		return -- the Nightly card follows
	end
	task.delay(0.8, function()
		if not seatedNow then
			return
		end
		local inRoom = tableMode == "room"
		RoundPanel.round(message, {
			primary = Voice.Table.nextRound,
			onPrimary = sendNext,
			secondary = if inRoom then Voice.Table.bank else nil,
			onSecondary = if inRoom then sendBank else nil,
			onLeave = TableClient.leave,
		})
	end)
end

local function onBanked(message: { [string]: any })
	RevivePanel.close()
	TableClient.Banked:Fire(tonumber(message.gilt) or 0)
	stopPlay()
	clearTray()
	Sound.play("complete", 0.4)
	local_ = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
	server = table.clone(local_)
	updateHeader()
	task.delay(0.6, function()
		if not seatedNow then
			return
		end
		RoundPanel.banked(message, {
			primary = "Another run",
			onPrimary = function()
				tableEvent:FireServer({ op = "again" })
			end,
			onLeave = TableClient.leave,
		})
	end)
end

local function onNightlyCard(message: { [string]: any })
	stopPlay()
	clearTray()
	clockLeft = nil
	clockBudget = nil
	Sound.play("complete", 0.4)
	local_ = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
	server = table.clone(local_)
	updateHeader()
	task.delay(0.6, function()
		if not seatedNow then
			return
		end
		NightlyCard.show(message, {
			rehearse = function()
				tableEvent:FireServer({ op = "again" })
			end,
			leave = TableClient.leave,
		})
	end)
end

-- The Library: a hand won or lost. The pieces clear and the next hand is dealt shortly.
local function onHandEnd(message: { [string]: any })
	stopPlay()
	clockRunning = false
	local won = message.winner == DuelView.mySide()
	Sound.play(if won then "round" else "low", 0.4)
	Toast.show(Voice.Library.title, if won then Voice.Library.handWon else (string.gsub(Voice.Library.handLost, "{name}", "your rival")), 2.2)
	task.delay(0.9, function()
		if seatedNow and not playing then
			clearTray()
		end
	end)
end

local function onDuelEnd(message: { [string]: any })
	stopPlay()
	clearTray()
	clockLeft = nil
	clockBudget = nil
	updateHeader()
	Sound.play("complete", 0.4)
	if message.won then
		Flourish.play(tableFrame:PointToWorldSpace(Vector3.new(0, T.topY + 1, 0)))
	end
	task.delay(1.2, function()
		if not seatedNow then
			return
		end
		DuelPanel.show(message, {
			side = DuelView.mySide(),
			again = function()
				tableEvent:FireServer({ op = "again" })
			end,
			leave = TableClient.leave,
		})
	end)
end

local function findTable(id: any): Model?
	for _, m in CollectionService:GetTagged("MaisonTable") do
		if m:IsA("Model") and m:GetAttribute("TableId") == id then
			return m
		end
	end
	return nil
end

-- The 3D side of sitting down: the counter, the plates, the camera. Every step is optional;
-- the sorting screen is already up by the time this runs.
local function seatIn3D(model: Model?, message: { [string]: any })
	local c = if model then model:GetAttribute("Centre") else message.centre
	centre = if typeof(c) == "Vector3" then c elseif model then model:GetPivot().Position else Vector3.zero
	local f = if model then model:GetAttribute("Frame") else nil
	tableFrame = if typeof(f) == "CFrame" then f else CFrame.new(centre)
	safely("the table's view", function()
		if tableMode == "duel" and model then
			DuelView.seated(model, tableFrame)
		elseif tableMode == "ballroom" and model then
			BallroomView.seated(model, tableFrame, message.seat)
		else
			RivalPlate.show(tableFrame)
		end
	end)
	if model then
		safely("the counter", function()
			Counter.own(model, true)
			Counter.set(model, 0, true)
			Counter.setMultiplier(model, 1)
		end)
	end
	safely("the controls", function()
		local ctl = getControls()
		if ctl then
			ctl:Disable()
		end
	end)
	safely("the camera", function()
		local ignore: { Instance } = { localFolder() }
		if model then
			table.insert(ignore, model)
		end
		if player.Character then
			table.insert(ignore, player.Character)
		end
		CameraRig.toTable(tableFrame, tableMode == "duel", ignore)
	end)
end

onSeated = function(message: { [string]: any })
	local wasSeated = seatedNow or CameraRig.isAtTable()
	local model = findTable(message.table)
	seatedModel = model
	seatedNow = true
	roomId = message.room or "salon"
	tableMode = message.mode or "room"
	round = 1
	State.seated = true
	local_ = { score = 0, streak = 0, runLength = 0, lastCase = nil, multiplier = 1 }
	server = table.clone(local_)
	duelRemaining = 0
	fumbleUntil = 0
	ballroomKeys = 0
	-- The sorting screen first: it's the game, and it needs nothing from the 3D table.
	safely("the sorting screen", function()
		Dialogue.close()
		SortScreen.open(roomTitle(), if tableMode == "duel" or tableMode == "ballroom" then roundTitle() else "")
		-- Until the deal says otherwise, every case is open.
		local all = {}
		for _, case in Catalogue.Cases do
			table.insert(all, case.id)
		end
		SortScreen.setCases(all)
	end)
	safely("the keys", Hud.setSeated, true)
	safely("the header", updateHeader)
	seatIn3D(model, message)
	if not model then
		-- The table hasn't streamed in yet: pick it up as soon as it does.
		task.spawn(function()
			for _ = 1, 40 do
				task.wait(0.25)
				if not seatedNow then
					return
				end
				local found = findTable(message.table)
				if found then
					seatedModel = found
					seatIn3D(found, message)
					return
				end
			end
		end)
	end
	if not wasSeated then
		seatings += 1
		hintPending = seatings <= 2
		Sound.play("enter", 0.35)
	end
	Sound.play("chair", 0.3)
	TableClient.Seated:Fire()
	for _, cb in toTableCallbacks do
		task.spawn(cb)
	end
end

local function onLeft(message: { [string]: any })
	if Root.isOpen("NightlyCard") then
		Root.close("NightlyCard")
	end
	local model = seatedModel
	seatedModel = nil
	seatedNow = false
	stopPlay()
	State.seated = false
	safely("clearing the table", function()
		clearTray()
		RoundPanel.close()
		RevivePanel.close()
		DuelPanel.close()
		DuelView.clear()
		BallroomPanel.close()
		BallroomView.clear()
		RivalPlate.hide()
	end)
	Sound.setIntensity(nil)
	tableMode = "room"
	paused = false
	clockLeft = nil
	clockBudget = nil
	if model then
		safely("the counter", Counter.own, model, false)
	end
	Hud.setSeated(false)
	Hud.setExtraKey(nil, nil)
	if message.moving then
		-- Being shown across to another table: the next "seated" follows at once.
		return
	end
	safely("closing the sorting screen", SortScreen.close)
	local ctl = getControls()
	if ctl then
		ctl:Enable()
	end
	hintPending = false
	Sound.play("leave", 0.3)
	safely("the camera", CameraRig.leaveTable)
	local summary = message.summary
	if type(summary) == "table" and (summary.score or 0) > 0 then
		Toast.show("The run is banked", string.format("%s points · %s", RoundPanel.number(summary.score), summary.grade), 4.5)
	end
	TableClient.Left:Fire()
end

-- Lights Out: messages only the Ballroom sends (its parcels carry seat numbers, not sides).
local BALLROOM_OPS = {
	gathering = true,
	eveningStart = true,
	eveningBegins = true,
	tab = true,
	parcelLanded = true,
	lampOut = true,
	closingTime = true,
	cases = true,
	eveningEnd = true,
	eveningResult = true,
	queued = true,
	arrive = true,
	flicker = true,
	out = true,
}
local function isBallroom(message: { [string]: any }): boolean
	local op = message.op
	if BALLROOM_OPS[op] then
		return true
	end
	local parcelOp = op == "parcel" or op == "parcelShrink" or op == "parcelCancel" or op == "parcelOpen"
	return parcelOp and type(message.id) == "number" and (type(message.to) == "number" or type(message.seat) == "number")
end

local ballroomActions = {
	gallery = function()
		tableEvent:FireServer({ op = "gallery" })
	end,
	stay = function() end, -- still in the chair: the next evening gathers around you
	leave = function()
		TableClient.leave()
	end,
}

local function onBallroom(message: { [string]: any })
	local op = message.op
	if not seatedNow or tableMode ~= "ballroom" then
		-- Watching from the Gallery or the floor: only the room's moments.
		BallroomView.handle(message)
		return
	end
	if op == "arrive" then
		addPieces(message.pieces, message.remaining)
		Sound.play("deal", 0.2)
	elseif op == "parcelOpen" then
		BallroomView.handle(message)
		addPieces(message.pieces, message.remaining)
	elseif op == "cases" then
		openCases = message.cases
		SortScreen.setCases(openCases)
		BallroomView.handle(message)
	elseif op == "flicker" then
		if message.on then
			clockBudget = message.seconds
			clockLeft = message.seconds
			clockRunning = true
			lowPlayed = false
			Toast.show(Voice.Ballroom.title, Voice.Ballroom.overCapacity, 1.5)
			Sound.play("low", 0.5)
		else
			clockLeft = nil
			clockBudget = nil
			clockRunning = false
		end
	elseif op == "out" then
		stopPlay()
		clearTray()
		clockLeft = nil
		clockBudget = nil
		BallroomView.handle(message)
		Sound.play("low", 0.5)
		task.delay(0.9, function()
			if TableClient.isSeated() and tableMode == "ballroom" then
				BallroomPanel.out(message, ballroomActions)
			end
		end)
	elseif op == "eveningEnd" then
		stopPlay()
		clearTray()
		clockLeft = nil
		clockBudget = nil
		BallroomPanel.close()
		BallroomView.handle(message)
	elseif op == "eveningResult" then
		-- After the last lamp's moment.
		task.delay(6, function()
			if TableClient.isSeated() and tableMode == "ballroom" then
				BallroomPanel.result(message, ballroomActions)
			end
		end)
	elseif op == "gathering" then
		BallroomPanel.close()
		BallroomView.handle(message)
	elseif op == "eveningStart" then
		ballroomKeys = 0
		BallroomPanel.close()
		BallroomView.handle(message)
	elseif op == "lampOut" then
		BallroomView.handle(message)
		if message.by == BallroomView.mySeat() and type(message.keys) == "number" then
			ballroomKeys = message.keys
			local model = seatedModel
			if model then
				Counter.setDialText(model, tostring(ballroomKeys))
			end
		end
	else
		BallroomView.handle(message)
	end
	updateHeader()
end

function TableClient.onSeated(cb: () -> ())
	table.insert(toTableCallbacks, cb)
end

function TableClient.isSeated(): boolean
	return seatedNow
end

function TableClient.start()
	SortScreen.canLift = canLift
	SortScreen.onLift = onLift
	SortScreen.onFile = file
	SortScreen.onCancel = TableClient.leave
	SortScreen.keysWidth = Hud.width
	safely("starting the sorting screen", SortScreen.start)
	local handle: (message: any) -> ()
	tableEvent.OnClientEvent:Connect(function(message: any)
		if type(message) ~= "table" then
			return
		end
		safely("handling '" .. tostring(message.op) .. "'", handle, message)
	end)
	handle = function(message: any)
		local op = message.op
		if (tableMode == "ballroom" or tableMode ~= "duel") and isBallroom(message) then
			onBallroom(message)
			return
		end
		if op == "seated" then
			onSeated(message)
		elseif op == "deal" then
			RoundPanel.close()
			renderDeal(message)
		elseif op == "filed" then
			onFiled(message)
		elseif op == "rejected" then
			local p = pieces[message.uid]
			if p then
				p.pending = false
				p.filed = false
				SortScreen.home(p.uid)
			end
			local_ = table.clone(server)
			setScore(local_.score, local_.multiplier)
		elseif op == "roundEnd" then
			onRoundEnd(message)
		elseif op == "banked" then
			onBanked(message)
		elseif op == "reviveOffer" then
			-- Chronos Defiance: the clock ran out in a timed room; the server holds the run open
			-- for its window. Nothing can be filed until it's revived or banked.
			stopPlay()
			clockRunning = false
			clockLeft = 0
			updateClock()
			RevivePanel.open(message, {
				onRevive = function()
					tableEvent:FireServer({ op = "revive" })
				end,
				onBank = function()
					tableEvent:FireServer({ op = "noRevive" })
				end,
			})
		elseif op == "reviveUpdate" then
			RevivePanel.update(message)
		elseif op == "revived" then
			RevivePanel.close()
			if message.clock then
				clockLeft = message.clock.left
				clockRunning = message.clock.running
				clockBudget = message.clock.budget
			end
			lowPlayed = false
			playing = true
			SortScreen.setPlaying(true)
			updateClock()
			Sound.play("complete", 0.4)
			Toast.show("Chronos Defiance", "The clock is yours again. Go on.", 2.5)
		elseif op == "nightlyCard" then
			onNightlyCard(message)
		elseif op == "clock" then
			if message.clock then
				clockLeft = message.clock.left
				clockRunning = message.clock.running
				clockBudget = message.clock.budget
				updateClock()
			end
		elseif op == "left" then
			onLeft(message)
		elseif op == "handEnd" then
			onHandEnd(message)
			DuelView.handle(message)
		elseif op == "duelEnd" then
			DuelView.handle(message)
			onDuelEnd(message)
		elseif op == "duelStart" or op == "duelWaiting" then
			DuelPanel.close()
			DuelView.handle(message)
			if op == "duelWaiting" then
				Hud.setExtraKey("Invite a friend", Invite.library)
			else
				Hud.setExtraKey(nil, nil)
			end
			updateHeader()
		elseif op == "rivalAway" then
			-- The hand pauses while their chair is held.
			awayPaused = playing
			stopPlay()
			clockRunning = false
			DuelView.handle(message)
		elseif op == "rivalBack" then
			if awayPaused then
				playing = true
				SortScreen.setPlaying(true)
				clockRunning = true
			end
			awayPaused = false
			DuelView.handle(message)
		elseif op == "parcelOpen" then
			DuelView.handle(message)
			if message.side == DuelView.mySide() then
				addPieces(message.pieces, message.remaining)
			end
			updateHeader()
		else
			DuelView.handle(message)
			updateHeader()
		end
	end
	-- The clock freezes while a panel is open in the four rooms (never in the Nightly).
	Root.PanelsChanged:Connect(function()
		if not seatedNow then
			return
		end
		local open = Root.isOpen() and Root.top() ~= "Round" and Root.top() ~= "Revive"
		if tableMode == "room" and open ~= paused then
			paused = open
			tableEvent:FireServer({ op = "pause", on = open })
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		if clockLeft and clockRunning and playing then
			if not paused then
				clockLeft = math.max(0, (clockLeft :: number) - dt)
			end
			updateClock()
			if tableMode == "duel" then
				Hud.setDuelLine(duelRemaining, DuelView.rivalRemaining(), clockLeft)
			elseif not counting() then
				Hud.setLine(RoundPanel.number(local_.score), local_.multiplier, clockLeft)
			end
		end
	end)
	-- Settings that change the table apply at once.
	State.SettingChanged:Connect(function(key)
		if (key == "pieceNames" or key == "pieceSize" or key == "textSize" or key == "caseStyle") and seatedNow then
			SortScreen.refresh(namesAllowed())
		end
	end)
	-- The rival's line, at the foot of the tray.
	State.RivalChanged:Connect(function()
		local r = State.rival
		SortScreen.setRival(if r then r.name .. "  ·  " .. r.fact else nil, if r then r.ahead else false)
	end)
end

return TableClient

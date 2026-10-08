--!strict
-- Lights Out in the Ballroom (§9.3, Appendix H3). Twenty tables in a ring; pieces arrive on
-- every felt from the dumbwaiters, identical for everyone, steadily and then faster. A felt holds
-- sixteen: go over and the lamp flickers; three seconds later it goes out. Parcels of lookalikes
-- go where your tab points; putting a lamp out takes a Key and every Key they held. The last lamp
-- burning wins. The server owns the dumbwaiter, every felt, every parcel and every lamp.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Config = require(ReplicatedStorage.Shared.Config)
local Deal = require(ReplicatedStorage.Shared.Deal)
local Duel = require(ReplicatedStorage.Shared.Duel)
local Layout = require(ReplicatedStorage.Shared.Layout)
local LightsOut = require(ReplicatedStorage.Shared.LightsOut)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Seed = require(ReplicatedStorage.Shared.Seed)
local Voice = require(ReplicatedStorage.Shared.Voice)

local Analytics = require(script.Parent.Analytics)
local Private = require(script.Parent.Private)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Season = require(script.Parent.Season)
local Rig = require(script.Parent.Staff.Rig)

local BallroomService = {}

type Piece = { uid: number, id: string, name: string, case: string, value: number, rare: boolean, seasonal: boolean }
type Parcel = { id: number, from: number, count: number, opensAt: number }
type Bot = { seconds: number, accuracy: number, nextAt: number }

type SeatState = {
	index: number,
	model: Model,
	chair: Seat,
	player: Player?,
	bot: Bot?,
	name: string,
	alive: boolean,
	pieces: { [number]: Piece },
	count: number,
	overSince: number?,
	keys: number,
	streak: number,
	runLength: number,
	lastCase: string?,
	runParcels: number,
	carry: number,
	fumbleUntil: number,
	lastFileAt: number,
	waiting: { Parcel },
	lastSender: number?,
	lastHitBy: number?,
	lastHitAt: number,
	tab: string,
	place: number?,
	filings: number,
	correct: number,
}

type Evening = {
	id: string,
	state: "gathering" | "playing" | "after",
	gatherEndsAt: number,
	startedAt: number,
	nextArrivalAt: number,
	batch: number,
	queue: { Deal.DealtPiece },
	cases: { string },
	closing: boolean,
	pace: number,
	alive: number,
	real: number,
	of: number, -- tables lit at the start (fewer on a Private Evening without Stand-ins)
	counts: boolean,
	rng: Random,
	nextUid: number,
	nextParcel: number,
	winner: number?,
}

local tableEvent = Remotes.event("Table")
local seats: { [number]: SeatState } = {}
local seatOf: { [Player]: number } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}
local nextEvening: { [Player]: boolean } = {} -- guests waiting for a chair at the next evening
local evening: Evening? = nil
local ambient: { { light: Light, base: number } } = {}
local board: BasePart? = nil

-- Hooks set by Main.
BallroomService.say = function(_player: Player, _line: string) end
BallroomService.onFinished = function(_player: Player, _place: number, _keys: number, _counted: boolean) end
BallroomService.onResult = function(_tableNumber: number, _name: string, _keys: number) end

local function cfg()
	return Config.data.Ballroom
end

-- Letter-spaced capitals, as the house engraves them.
local function track(text: string): string
	return (string.sub((string.gsub(text, "(.)", "%1 ")), 1, -2))
end

-- The evening's board: a title and two lines.
local IDLE_LINES = { "Take any chair.", "The evening begins when a guest sits." }
local LAST_LAMP = "The last lamp still lit wins the night."

local function send(player: Player?, message: { [string]: any })
	if player and player.Parent == Players then
		tableEvent:FireClient(player, message)
	end
end

-- Everyone at a table and everyone watching from the Gallery or the floor.
local function inRoom(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if seatOf[player] or (root and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "ballroom") then
			table.insert(out, player)
		end
	end
	return out
end

local function broadcast(message: { [string]: any })
	for _, player in inRoom() do
		send(player, message)
	end
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	return if h and h.Health > 0 then h else nil
end

local function lampOf(s: SeatState): SpotLight?
	local bulb = s.model:FindFirstChild("Bulb")
	local light = bulb and bulb:FindFirstChild("TableLight")
	return if light and light:IsA("SpotLight") then light else nil
end

local function setLamp(s: SeatState, brightness: number, seconds: number)
	local light = lampOf(s)
	if light then
		TweenService:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Brightness = brightness }):Play()
	end
end

-- The room darkens as lamps go out.
local function dimRoom(fraction: number)
	for _, a in ambient do
		TweenService:Create(a.light, TweenInfo.new(1.5, Enum.EasingStyle.Sine), { Brightness = a.base * fraction }):Play()
	end
end

local function writeBoard(lines: { string })
	local part = board
	if not part then
		return
	end
	local gui = part:FindFirstChildOfClass("SurfaceGui")
	if not gui then
		return
	end
	local labels = {}
	for _, d in gui:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(labels, d)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i, label in labels do
		if lines[i] then
			label.Text = lines[i]
		end
	end
end

local function realAlive(): number
	local n = 0
	for _, s in seats do
		if s.alive and s.player then
			n += 1
		end
	end
	return n
end

local function resetSeat(s: SeatState)
	s.alive = false
	s.pieces = {}
	s.count = 0
	s.overSince = nil
	s.keys = 0
	s.streak = 0
	s.runLength = 0
	s.lastCase = nil
	s.runParcels = 0
	s.carry = 0
	s.fumbleUntil = 0
	s.lastFileAt = 0
	s.waiting = {}
	s.lastSender = nil
	s.lastHitBy = nil
	s.lastHitAt = 0
	s.place = nil
	s.filings = 0
	s.correct = 0
	s.model:SetAttribute("Score", 0)
	s.model:SetAttribute("Flicker", false)
	s.model:SetAttribute("Out", false)
	s.model:SetAttribute("Keys", 0)
	s.model:SetAttribute("KeyLeader", false)
end

local function publicPiece(p: Piece): { [string]: any }
	return { uid = p.uid, id = p.id, name = p.name, case = p.case, value = p.value, rare = p.rare, seasonal = p.seasonal, mythic = false }
end

local function setCount(s: SeatState)
	local n = 0
	for _ in s.pieces do
		n += 1
	end
	s.count = n
	s.model:SetAttribute("Score", n)
end

-- The next piece from the dumbwaiter: batches from the evening's seed, the same for everyone.
local function nextPiece(e: Evening, t: number): Deal.DealtPiece
	if #e.queue == 0 then
		e.batch += 1
		local result = Deal.generate(Seed.hash(e.id .. ":" .. e.batch), LightsOut.room(t), 1, Season.current().id, { allowMythic = false })
		for _, p in result.pieces do
			table.insert(e.queue, p)
		end
	end
	return table.remove(e.queue, 1) :: Deal.DealtPiece
end

local function give(e: Evening, s: SeatState, dealt: Deal.DealtPiece): Piece
	e.nextUid += 1
	local p: Piece = { uid = e.nextUid, id = dealt.id, name = dealt.name, case = dealt.case, value = dealt.value, rare = dealt.rare, seasonal = dealt.seasonal }
	s.pieces[p.uid] = p
	return p
end

local function keyLeader()
	local best, bestKeys = nil, 0
	for i, s in seats do
		if s.alive and s.keys > bestKeys then
			best, bestKeys = i, s.keys
		end
	end
	for i, s in seats do
		s.model:SetAttribute("KeyLeader", i == best)
	end
	return best
end

local finish: (e: Evening) -> ()

local function standUp(s: SeatState)
	local weld = s.chair:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	local player = s.player
	if player then
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Sit = false
		end
	end
end

local function clearBot(s: SeatState)
	s.bot = nil
	local folder = s.model:FindFirstChild("StandIn")
	if folder then
		folder:Destroy()
	end
end

-- A lamp goes out: the place, the Key for whoever's parcel did it, and the room grows darker.
local function lampOut(e: Evening, s: SeatState, now: number, reason: string)
	if not s.alive then
		return
	end
	s.alive = false
	s.place = e.alive
	e.alive -= 1
	s.overSince = nil
	s.model:SetAttribute("Flicker", false)
	s.model:SetAttribute("Out", true)
	setLamp(s, 0, 0.6)
	local by: SeatState? = nil
	if s.lastHitBy and now - s.lastHitAt <= cfg().keyWindow then
		local hitter = seats[s.lastHitBy]
		if hitter and hitter.alive then
			by = hitter
			hitter.keys += 1 + s.keys
			hitter.model:SetAttribute("Keys", hitter.keys)
		end
	end
	local keysHeld = s.keys
	s.keys = 0
	s.model:SetAttribute("Keys", 0)
	local leader = keyLeader()
	dimRoom(0.25 + 0.75 * e.alive / e.of)
	broadcast({
		op = "lampOut",
		seat = s.index,
		place = s.place,
		by = if by then by.index else nil,
		byName = if by then by.name else nil,
		keys = if by then by.keys else nil,
		leader = leader,
		alive = e.alive,
	})
	if s.player then
		send(s.player, { op = "out", place = s.place, keys = keysHeld, by = if by then by.name else nil, reason = reason, of = e.of })
		Analytics.custom(s.player, "Ballroom lamp out", s.place, { reason = reason })
	end
	if e.alive <= 1 or realAlive() == 0 then
		finish(e)
	end
end

local function sendParcels(e: Evening, from: SeatState, count: number, now: number)
	local n = count
	-- Your own parcels first cancel any waiting on your felt.
	while n > 0 and #from.waiting > 0 do
		local parcel = from.waiting[1]
		parcel.count -= 1
		n -= 1
		if parcel.count <= 0 then
			table.remove(from.waiting, 1)
			broadcast({ op = "parcelCancel", seat = from.index, id = parcel.id })
		else
			broadcast({ op = "parcelShrink", seat = from.index, id = parcel.id, count = parcel.count })
		end
	end
	if n <= 0 then
		return
	end
	local list: { LightsOut.Seat } = {}
	for _, s in seats do
		table.insert(list, { index = s.index, alive = s.alive, keys = s.keys, felt = s.count, lastSender = s.lastSender })
	end
	local me: LightsOut.Seat = { index = from.index, alive = true, keys = from.keys, felt = from.count, lastSender = from.lastSender }
	local targetIndex = LightsOut.target(from.tab, me, list, e.rng)
	if not targetIndex then
		return
	end
	local to = seats[targetIndex]
	e.nextParcel += 1
	local parcel: Parcel = { id = e.nextParcel, from = from.index, count = n, opensAt = now + cfg().parcelFuse }
	table.insert(to.waiting, parcel)
	to.lastSender = from.index
	broadcast({ op = "parcel", from = from.index, to = to.index, id = parcel.id, count = n, fuse = cfg().parcelFuse })
end

local function openParcels(e: Evening, s: SeatState, now: number)
	local i = 1
	while i <= #s.waiting do
		local parcel = s.waiting[i]
		if now >= parcel.opensAt then
			table.remove(s.waiting, i)
			local added = {}
			for _, id in Duel.lookalikes(e.cases, parcel.count, e.rng) do
				local c = Catalogue.byId[id]
				local p = give(e, s, { id = c.id, name = c.name, case = c.case, value = c.value, rare = false, seasonal = false, mythic = false })
				table.insert(added, publicPiece(p))
			end
			setCount(s)
			s.lastHitBy = parcel.from
			s.lastHitAt = now
			send(s.player, { op = "parcelOpen", side = "mine", seat = s.index, id = parcel.id, pieces = added, remaining = s.count })
			broadcast({ op = "parcelLanded", seat = s.index, id = parcel.id, count = #added, felt = s.count })
		else
			i += 1
		end
	end
end

local function file(e: Evening, s: SeatState, uid: number, caseId: string)
	if e.state ~= "playing" or not s.alive then
		return
	end
	local piece = s.pieces[uid]
	if not piece or not table.find(e.cases, caseId) then
		return
	end
	local now = os.clock()
	if now < s.fumbleUntil or (s.player and now - s.lastFileAt < Config.data.FairPlay.minGap) then
		send(s.player, { op = "rejected", uid = uid })
		return
	end
	s.lastFileAt = now
	s.filings += 1
	local correct = piece.case == caseId
	local parcels = 0
	if correct then
		s.pieces[uid] = nil
		s.correct += 1
		s.streak += 1
		if s.lastCase == caseId then
			s.runLength += 1
		else
			s.runLength = 1
			s.runParcels = 0
		end
		s.lastCase = caseId
		local whole, fromRun, carry = LightsOut.parcels(s.runLength, s.runParcels, s.streak, s.keys, s.carry)
		s.runParcels += fromRun
		s.carry = carry
		parcels = whole
		setCount(s)
	else
		s.streak = 0
		s.runLength = 0
		s.runParcels = 0
		s.lastCase = nil
		s.fumbleUntil = now + cfg().fumble
	end
	send(s.player, {
		op = "filed",
		uid = uid,
		case = caseId,
		correct = correct,
		points = 0,
		setBonus = 0,
		penalty = 0,
		score = s.count,
		streak = s.streak,
		multiplier = 1,
		runLength = s.runLength,
		remaining = s.count,
		keys = s.keys,
		fumble = if correct then nil else cfg().fumble,
	})
	if parcels > 0 then
		sendParcels(e, s, parcels, now)
	end
end

local function botStep(e: Evening, s: SeatState, now: number)
	local bot = s.bot
	if not bot or not s.alive or now < bot.nextAt or now < s.fumbleUntil then
		return
	end
	local oldest: Piece? = nil
	for _, p in s.pieces do
		if not oldest or p.uid < oldest.uid then
			oldest = p
		end
	end
	bot.nextAt = now + bot.seconds * e.rng:NextNumber(0.75, 1.3)
	if not oldest then
		return
	end
	local caseId = oldest.case
	if e.rng:NextNumber() > bot.accuracy then
		for _, c in e.cases do
			if c ~= oldest.case then
				caseId = c
				break
			end
		end
	end
	file(e, s, oldest.uid, caseId)
end

local function standInRig(s: SeatState)
	local existing = s.model:FindFirstChild("StandIn")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "StandIn"
	folder.Parent = s.model
	local look = Rig.look("Doorman")
	look.coat = Color3.fromRGB(40, 42, 48)
	look.skin = Color3.fromRGB(150, 150, 156)
	local staff = Rig.build("Stand-in", look, s.chair.CFrame * CFrame.new(0, 0, 2), folder)
	staff.model:SetAttribute("StandIn", true)
	for _, d in staff.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if d.Name == "HumanoidRootPart" then 1 else 0.35
		end
	end
	s.chair:Sit(staff.humanoid)
end

local function results(): { { index: number, name: string, place: number, keys: number } }
	local list = {}
	for i, s in seats do
		table.insert(list, { index = i, name = s.name, place = s.place or 1, keys = s.keys })
	end
	table.sort(list, function(a, b)
		return a.place < b.place
	end)
	return list
end

local gather: (now: number) -> ()

finish = function(e: Evening)
	if e.state ~= "playing" then
		return
	end
	e.state = "after"
	-- Whoever is still lit: the fewest pieces on the felt keeps the last lamp.
	local standing: { SeatState } = {}
	for _, s in seats do
		if s.alive then
			table.insert(standing, s)
		end
	end
	table.sort(standing, function(a, b)
		if a.count ~= b.count then
			return a.count < b.count
		end
		return a.index < b.index
	end)
	for rank, s in standing do
		s.place = rank
	end
	local winner = standing[1]
	e.winner = if winner then winner.index else nil
	for _, s in standing do
		s.alive = false
		s.model:SetAttribute("Flicker", false)
	end
	-- The whole Ballroom goes dark except the last lamp.
	dimRoom(0)
	for _, s in seats do
		if s ~= winner then
			setLamp(s, 0, 1.2)
		end
	end
	if winner then
		setLamp(winner, 3.2, 1.2)
		winner.model:SetAttribute("Out", false)
		winner.model:SetAttribute("LastLamp", true)
	end
	local seconds = os.clock() - e.startedAt
	broadcast({
		op = "eveningEnd",
		winner = if winner then winner.index else nil,
		winnerName = if winner then winner.name else nil,
		keys = if winner then winner.keys else 0,
		seconds = seconds,
		counted = e.counts,
		results = results(),
	})
	for _, s in seats do
		local player = s.player
		if player then
			local place = s.place or e.of
			local data = Profiles.get(player)
			local gilt = 0
			if data then
				gilt = Gilt.pay(player, data, LightsOut.gilt(place), "Lights Out")
			end
			send(player, {
				op = "eveningResult",
				place = place,
				of = e.of,
				keys = s.keys,
				points = LightsOut.points(place, s.keys),
				gilt = gilt,
				counted = e.counts,
				won = place == 1,
			})
			if place == 1 then
				BallroomService.say(player, Voice.Concierge.lastLamp)
			end
			BallroomService.onFinished(player, place, s.keys, e.counts)
			Analytics.custom(player, "Ballroom evening finished", place, { keys = s.keys, counted = e.counts, seconds = seconds })
		end
	end
	if winner then
		BallroomService.onResult(winner.index, winner.name, winner.keys)
	end
	task.delay(cfg().afterEvening, function()
		if evening ~= e then
			return
		end
		evening = nil
		for _, s in seats do
			clearBot(s)
			s.model:SetAttribute("LastLamp", false)
			resetSeat(s)
			setLamp(s, 1.8, 1.5)
		end
		dimRoom(1)
		-- The winner (and anyone still seated) and everyone who asked for the next evening.
		gather(os.clock())
	end)
end

local function eveningStart(e: Evening, now: number)
	e.state = "playing"
	e.startedAt = now
	e.pace = LightsOut.pace(0) * Private.paceScale()
	e.nextArrivalAt = now + e.pace
	e.cases = Deal.casesOpen(LightsOut.room(0), 1)
	-- Stand-ins fill the empty chairs, their pace spread across the room. On a Private Evening
	-- the host may leave them empty, once at least two guests are seated.
	local names: { [string]: { name: string, standIn: boolean } } = {}
	local real = 0
	for _, s in seats do
		if s.player then
			real += 1
		end
	end
	local fill = Private.standIns() or real < 2
	local lit = 0
	for i, s in seats do
		resetSeat(s)
		s.alive = s.player ~= nil or fill
		if s.alive then
			lit += 1
		end
		if not s.player and not fill then
			s.model:SetAttribute("Out", true)
			setLamp(s, 0, 0.6)
			continue
		elseif not s.player then
			local t = e.rng:NextNumber()
			s.bot = {
				seconds = cfg().standInFast + (cfg().standInSlow - cfg().standInFast) * t,
				accuracy = cfg().standInHighAccuracy - (cfg().standInHighAccuracy - cfg().standInLowAccuracy) * t,
				nextAt = now + 1.5,
			}
			s.name = "Stand-in"
			s.tab = LightsOut.Tabs[e.rng:NextInteger(1, #LightsOut.Tabs)]
			standInRig(s)
		end
		names[tostring(i)] = { name = s.name, standIn = s.player == nil }
	end
	e.real = real
	e.alive = lit
	e.of = lit
	e.counts = real >= cfg().minRealForRecords and Private.records()
	-- The opening deal: the same six pieces on every felt.
	local opening: { Deal.DealtPiece } = {}
	for _ = 1, cfg().openingDeal do
		table.insert(opening, nextPiece(e, 0))
	end
	for _, s in seats do
		if not s.alive then
			continue
		end
		local list = {}
		for _, dealt in opening do
			table.insert(list, publicPiece(give(e, s, dealt)))
		end
		setCount(s)
		setLamp(s, 2.4, 1)
		local player = s.player
		if player then
			send(player, { op = "eveningStart", seat = s.index, names = names, capacity = cfg().capacity, tab = s.tab, counted = e.counts, real = real })
			send(player, { op = "deal", mode = "ballroom", room = "ballroom", round = 1, cases = e.cases, pieces = list, score = s.count })
			Analytics.custom(player, "Ballroom evening started", real, nil)
		end
	end
	broadcast({ op = "eveningBegins", alive = e.alive, real = real, counted = e.counts })
	writeBoard({ track("LIGHTS OUT"), string.format("%d lamps lit · %d guests", e.alive, real), LAST_LAMP })
end

gather = function(now: number)
	local id = "ballroom:" .. tostring(Seed.fresh())
	local e: Evening = {
		id = id,
		state = "gathering",
		gatherEndsAt = now + cfg().gatherSeconds,
		startedAt = 0,
		nextArrivalAt = 0,
		batch = 0,
		queue = {},
		cases = {},
		closing = false,
		pace = cfg().paceStart,
		alive = 0,
		real = 0,
		of = cfg().tables,
		counts = false,
		rng = Random.new(Seed.hash(id)),
		nextUid = 0,
		nextParcel = 0,
		winner = nil,
	}
	evening = e
	-- Seat the guests who asked for a chair at the next evening.
	local queued = {}
	for player in nextEvening do
		if player.Parent == Players and not seatOf[player] then
			table.insert(queued, player)
		end
	end
	nextEvening = {}
	for _, player in queued do
		for i, s in seats do
			if not s.player and not s.bot then
				local character = player.Character
				if character and humanoidOf(player) then
					character:PivotTo(s.chair.CFrame * CFrame.new(0, 3, 2.5))
					BallroomService.seatGuest(player, i)
				end
				break
			end
		end
	end
	local anyone = false
	for _, s in seats do
		if s.player then
			anyone = true
		end
	end
	if not anyone then
		if evening == e then
			evening = nil
		end
		writeBoard({ track("LIGHTS OUT"), IDLE_LINES[1], IDLE_LINES[2] })
		return
	end
	for _, s in seats do
		send(s.player, { op = "gathering", startsIn = math.max(0, e.gatherEndsAt - os.clock()) })
	end
end

local function unseat(player: Player, reason: string)
	local index = seatOf[player]
	if not index then
		return
	end
	seatOf[player] = nil
	local conns = connections[player]
	if conns then
		for _, c in conns do
			c:Disconnect()
		end
	end
	connections[player] = nil
	local s = seats[index]
	local e = evening
	if e and e.state == "playing" and s.alive then
		lampOut(e, s, os.clock(), reason)
	end
	standUp(s)
	s.model:SetAttribute("Occupant", nil)
	s.player = nil
	s.name = ""
	send(player, { op = "left" })
	-- A gathering with nobody left in it stops.
	if e and e.state == "gathering" then
		local anyone = false
		for _, other in seats do
			if other.player then
				anyone = true
			end
		end
		if not anyone then
			evening = nil
			writeBoard({ track("LIGHTS OUT"), IDLE_LINES[1], IDLE_LINES[2] })
		end
	end
end

-- Seats a guest who is already beside chair `index`. Yields briefly.
function BallroomService.seatGuest(player: Player, index: number): boolean
	local s = seats[index]
	local humanoid = humanoidOf(player)
	if not s or not humanoid or s.player or s.bot then
		return false
	end
	s.player = player
	s.chair:Sit(humanoid)
	local waited = 0
	while humanoid.SeatPart ~= s.chair and waited < 1.5 do
		task.wait(0.05)
		waited += 0.05
	end
	if humanoid.SeatPart ~= s.chair or player.Parent ~= Players then
		if s.player == player then
			s.player = nil
		end
		return false
	end
	seatOf[player] = index
	s.name = player.DisplayName
	s.model:SetAttribute("Occupant", player.UserId)
	-- The guest's own default tab (Settings: "Ballroom parcels go to").
	local data = Profiles.get(player)
	local wanted = data and data.settings and data.settings.parcelsTo
	s.tab = if wanted == "Rivals" then "rivals" elseif wanted == "Leader" then "leader" elseif wanted == "Nearly out" then "nearlyOut" else "random"
	nextEvening[player] = nil
	connections[player] = {
		humanoid.Seated:Connect(function(active: boolean, part: BasePart?)
			if not active or part ~= s.chair then
				unseat(player, "left")
			end
		end),
		humanoid.Died:Connect(function()
			unseat(player, "left")
		end),
	}
	send(player, { op = "seated", table = s.model:GetAttribute("TableId"), room = "ballroom", mode = "ballroom", seat = index })
	Analytics.custom(player, "Ballroom seated", nil, nil)
	local e = evening
	if not e then
		gather(os.clock())
	elseif e.state == "gathering" then
		send(player, { op = "gathering", startsIn = math.max(0, e.gatherEndsAt - os.clock()) })
		local full = true
		for _, other in seats do
			if not other.player then
				full = false
			end
		end
		if full then
			eveningStart(e, os.clock())
		end
	end
	return true
end

function BallroomService.isSeated(player: Player): boolean
	return seatOf[player] ~= nil
end

function BallroomService.sit(player: Player, model: Model, isSeatedElsewhere: (Player) -> boolean): (boolean, string?)
	if seatOf[player] or isSeatedElsewhere(player) then
		return false, "seated"
	end
	local index = model:GetAttribute("Seat")
	if type(index) ~= "number" or not seats[index] then
		return false, "unavailable"
	end
	local s = seats[index]
	local e = evening
	if e and e.state ~= "gathering" then
		-- Mid-evening: a chair at the next one.
		nextEvening[player] = true
		send(player, { op = "queued" })
		return false, "underway"
	end
	if s.player or s.bot then
		return false, "taken"
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - s.chair.Position).Magnitude > 12 then
		return false, "far"
	end
	if not BallroomService.seatGuest(player, index) then
		return false, "unavailable"
	end
	return true, nil
end

-- "Next evening" from the out card or the Gallery: a chair when the next one gathers, or at once
-- if one is gathering now.
function BallroomService.nextEvening(player: Player)
	if seatOf[player] then
		return
	end
	local e = evening
	if not e or e.state == "gathering" then
		for i, s in seats do
			if not s.player and not s.bot then
				local character = player.Character
				if character then
					character:PivotTo(s.chair.CFrame * CFrame.new(0, 3, 2.5))
					task.spawn(BallroomService.seatGuest, player, i)
				end
				return
			end
		end
	end
	nextEvening[player] = true
	send(player, { op = "queued" })
end

-- Up to the Gallery to watch.
function BallroomService.toGallery(player: Player)
	if seatOf[player] then
		unseat(player, "left")
	end
	local character = player.Character
	if character then
		local B = Layout.Ballroom
		character:PivotTo(CFrame.lookAt(B.galleryArrival + Vector3.new(0, 3, 0), Vector3.new(B.centre.X, B.galleryArrival.Y + 3, B.centre.Z)))
	end
end

local function onMessage(player: Player, message: unknown)
	if type(message) ~= "table" then
		return
	end
	local m = message :: { [string]: unknown }
	if m.op == "nextEvening" then
		BallroomService.nextEvening(player)
		return
	elseif m.op == "gallery" then
		BallroomService.toGallery(player)
		return
	end
	local index = seatOf[player]
	if not index then
		return
	end
	local s = seats[index]
	local e = evening
	if m.op == "file" then
		if e and type(m.uid) == "number" and type(m.case) == "string" then
			file(e, s, m.uid :: number, m.case :: string)
		end
	elseif m.op == "tab" then
		if type(m.tab) == "string" and LightsOut.TabNames[m.tab :: string] then
			s.tab = m.tab :: string
			send(player, { op = "tab", tab = s.tab })
		end
	elseif m.op == "leave" then
		unseat(player, "left")
	end
end

local function tick(now: number)
	local e = evening
	if not e then
		return
	end
	if e.state == "gathering" then
		if now >= e.gatherEndsAt then
			eveningStart(e, now)
		end
		return
	end
	if e.state ~= "playing" then
		return
	end
	local t = now - e.startedAt
	-- The sixth case opens at 1:00; Closing Time at 5:00.
	if #e.cases < LightsOut.casesOpen(t) then
		e.cases = Deal.casesOpen(LightsOut.room(t), 1)
		broadcast({ op = "cases", cases = e.cases })
	end
	if not e.closing and LightsOut.isClosingTime(t) then
		e.closing = true
		broadcast({ op = "closingTime" })
	end
	-- The dumbwaiters: one piece on every lit felt, at the evening's pace.
	while now >= e.nextArrivalAt and e.state == "playing" do
		local dealt = nextPiece(e, t)
		for _, s in seats do
			if s.alive then
				local p = give(e, s, dealt)
				setCount(s)
				send(s.player, { op = "arrive", pieces = { publicPiece(p) }, remaining = s.count })
			end
		end
		e.pace = LightsOut.pace(t) * Private.paceScale()
		e.nextArrivalAt += e.pace
	end
	for _, s in seats do
		if s.alive then
			openParcels(e, s, now)
			if s.bot then
				botStep(e, s, now)
			end
		end
	end
	-- Over sixteen: the lamp flickers; three seconds later it goes out.
	for _, s in seats do
		if s.alive and e.state == "playing" then
			if s.count > cfg().capacity then
				if not s.overSince then
					s.overSince = now
					s.model:SetAttribute("Flicker", true)
					send(s.player, { op = "flicker", on = true, seconds = cfg().overSeconds })
				elseif now - s.overSince >= cfg().overSeconds then
					lampOut(e, s, now, "over")
				end
			elseif s.overSince then
				s.overSince = nil
				s.model:SetAttribute("Flicker", false)
				send(s.player, { op = "flicker", on = false })
			end
		end
	end
end

function BallroomService.start(isSeatedElsewhere: (Player) -> boolean)
	for _, model in CollectionService:GetTagged("BallroomTable") do
		if model:IsA("Model") then
			local index = model:GetAttribute("Seat")
			local chair = model:FindFirstChild("Chair")
			if type(index) == "number" and chair and chair:IsA("Seat") then
				local s: SeatState = {
					index = index,
					model = model,
					chair = chair,
					player = nil,
					bot = nil,
					name = "",
					alive = false,
					pieces = {},
					count = 0,
					overSince = nil,
					keys = 0,
					streak = 0,
					runLength = 0,
					lastCase = nil,
					runParcels = 0,
					carry = 0,
					fumbleUntil = 0,
					lastFileAt = 0,
					waiting = {},
					lastSender = nil,
					lastHitBy = nil,
					lastHitAt = 0,
					tab = "random",
					place = nil,
					filings = 0,
					correct = 0,
				}
				seats[index] = s
				resetSeat(s)
				local prompt = chair:FindFirstChild("SitPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Triggered:Connect(function(player: Player)
						local ok, why = BallroomService.sit(player, model, isSeatedElsewhere)
						if not ok and why == "underway" then
							BallroomService.say(player, Voice.Concierge.ballroomUnderway)
						elseif not ok and why == "taken" then
							BallroomService.say(player, "That chair is taken. Another is free.")
						end
					end)
				end
			end
		end
	end
	local ballroom = nil
	for _, d in CollectionService:GetTagged("MaisonTable") do
		if d:GetAttribute("Ballroom") then
			ballroom = d.Parent and d.Parent.Parent
			break
		end
	end
	if ballroom then
		for _, d in ballroom:GetDescendants() do
			if d:IsA("Light") and type(d:GetAttribute("BallroomAmbient")) == "number" then
				table.insert(ambient, { light = d, base = d:GetAttribute("BallroomAmbient") :: number })
			elseif d:IsA("BasePart") and d:GetAttribute("EveningBoard") then
				board = d
			end
		end
	end
	RemoteGuard.event(tableEvent, "ballroom", onMessage)
	RunService.Heartbeat:Connect(function()
		tick(os.clock())
	end)
	-- Chairs show their prompt only while an evening is gathering or the room is quiet.
	task.spawn(function()
		while true do
			local e = evening
			for _, s in seats do
				local prompt = s.chair:FindFirstChild("SitPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Enabled = s.player == nil and s.bot == nil
					prompt.ObjectText = if e and e.state ~= "gathering" then "The next evening" else "Lights Out"
				end
			end
			if e and e.state == "gathering" then
				writeBoard({ track("LIGHTS OUT"), string.format("The evening begins in %d s", math.max(0, math.ceil(e.gatherEndsAt - os.clock()))), "Take any chair." })
			elseif e and e.state == "playing" then
				writeBoard({ track(if e.closing then "CLOSING TIME" else "LIGHTS OUT"), string.format("%d of %d lamps lit", e.alive, cfg().tables), LAST_LAMP })
			end
			task.wait(0.5)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		unseat(player, "left")
		nextEvening[player] = nil
	end)
end

-- For tests: the live evening.
function BallroomService.evening(): Evening?
	return evening
end

return BallroomService

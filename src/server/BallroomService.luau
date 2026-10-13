--!strict
-- Lights Out in the Ballroom (§9.3, Appendix H3). Twenty tables in a ring; pieces arrive on
-- every felt from the dumbwaiters, identical for everyone, steadily and then faster. A felt holds
-- sixteen: go over and the lamp flickers; three seconds later it goes out. Parcels of lookalikes
-- go where your tab points; putting a lamp out takes a Key and every Key they held. The last lamp
-- burning wins, and takes the whole pot (more for every real guest who sat down); nobody else is
-- paid Gilt. The server owns the dumbwaiter, every felt, every parcel and every lamp.
--
-- The Ballroom keeps hours (Config.Ballroom): open for five minutes; the first guest to sit starts
-- a 100-second countdown (others may sit until it ends, never after); then closed for twenty
-- minutes, after an evening or when nobody came. It opens early for everyone when a guest buys
-- "Open the Ballroom Now", or the owner says so. And during an evening, any guest in the room may
-- sabotage a table (Robux, through Purchases/Sabotage): a Parcel Bomb, a Blackout, Butterfingers,
-- or a Shield against them; every one is announced to the room, with who sent it.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Names = require(ReplicatedStorage.Shared.Names)
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
	shield: number, -- sabotages it will stop
	hitAt: number, -- when it was last sabotaged (os.clock)
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
	sabotages: { [Player]: number }, -- sent this evening, by guest
	pot: number,
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
-- A win against three or more real guests: the Ballroom's Secret brainrot (set by Main).
BallroomService.secret = function(_player: Player) end
-- A guest asked to sabotage a table (Main: Purchases/Sabotage.request, which spends a credit or
-- asks Roblox for the purchase window). The default applies it at once (tests, and before Main).
BallroomService.requestSabotage = function(player: Player, kind: string, seat: number): (boolean, string?)
	return (BallroomService :: any).sabotage(player, kind, seat)
end
-- A guest asked to open the Ballroom early (Main: Purchases/Sabotage.openNow, the purchase).
BallroomService.requestOpen = function(_player: Player): (boolean, string?)
	return false, "Not just now."
end
-- The prices and credits a guest's screen shows for sabotage (Main: Purchases/Sabotage.info).
BallroomService.sabotageInfo = function(_player: Player): { [string]: any }
	return { prices = {}, credits = {} }
end

-- The Ballroom's hours: open (an evening may start) or closed, and until when (os.clock).
local doorState: "open" | "closed" = "open"
local doorUntil = 0

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

local function serverNow(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

-- Everyone in the house: the Ballroom opening is news for all of them.
local function broadcastAll(message: { [string]: any })
	for _, player in Players:GetPlayers() do
		send(player, message)
	end
end

local function realSeated(): number
	local n = 0
	for _, s in seats do
		if s.player then
			n += 1
		end
	end
	return n
end

-- The winner's pot for an evening with `real` guests.
local function potFor(real: number): number
	return cfg().potBase + cfg().potPerGuest * math.max(1, real)
end

local function clockText(seconds: number): string
	local t = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", t // 60, t % 60)
end

-- What every screen reads (Workspace attributes): the Ballroom's state ("closed", "open",
-- "gathering", "playing", "after"), when it next changes (server time), and the pot.
local function publish()
	local e = evening
	local state: string = doorState
	local untilClock = doorUntil
	if e then
		state = e.state
		untilClock = if e.state == "gathering" then e.gatherEndsAt else 0
	end
	Workspace:SetAttribute("BallroomState", state)
	Workspace:SetAttribute("BallroomAt", if untilClock > 0 then serverNow() + (untilClock - os.clock()) else nil)
	Workspace:SetAttribute("BallroomPot", if e and e.state ~= "gathering" then e.pot else potFor(realSeated()))
end

local function openDoor(now: number, by: string?)
	doorState = "open"
	doorUntil = now + cfg().openSeconds
	publish()
	writeBoard({ track("LIGHTS OUT"), "Open now · take any chair", string.format("The last lamp wins %d Gilt or more", potFor(1)) })
	broadcastAll({ op = "ballroomOpen", by = by, closesIn = cfg().openSeconds, pot = potFor(1), perGuest = cfg().potPerGuest, countdown = cfg().countdown })
end

local function closeDoor(now: number)
	doorState = "closed"
	doorUntil = now + cfg().closedSeconds
	publish()
	writeBoard({ track("CLOSED"), "Opens in " .. clockText(cfg().closedSeconds), "Or open it now from any chair" })
	broadcast({ op = "ballroomClosed", opensIn = cfg().closedSeconds })
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
	s.shield = 0
	s.hitAt = -math.huge
	s.model:SetAttribute("Score", 0)
	s.model:SetAttribute("Shield", false)
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
local unseatFn: (player: Player, reason: string) -> ()

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
			-- One winner takes the whole pot; nobody else is paid Gilt.
			if data and place == 1 then
				gilt = Gilt.pay(player, data, e.pot, "Lights Out")
			end
			send(player, {
				op = "eveningResult",
				place = place,
				of = e.of,
				keys = s.keys,
				points = LightsOut.points(place, s.keys),
				gilt = gilt,
				pot = e.pot,
				counted = e.counts,
				won = place == 1,
			})
			if place == 1 then
				BallroomService.say(player, Voice.Concierge.lastLamp)
				-- The Ballroom's own Secret brainrot, for a win against three or more guests.
				if (e.real or 0) >= 4 then
					BallroomService.secret(player)
				end
			end
			BallroomService.onFinished(player, place, s.keys, e.counts)
			Analytics.custom(player, "Ballroom evening finished", place, { keys = s.keys, counted = e.counts, seconds = seconds })
		end
	end
	if winner then
		BallroomService.onResult(winner.index, winner.name, winner.keys)
	end
	broadcastAll({ op = "ballroomWinner", name = if winner then winner.name else nil, standIn = winner ~= nil and winner.player == nil, pot = e.pot })
	publish()
	task.delay(cfg().afterEvening, function()
		if evening ~= e then
			return
		end
		evening = nil
		-- Everyone stands; the lamps come back up; the Ballroom closes until its next hour.
		for _, s in seats do
			if s.player then
				unseatFn(s.player, "closed")
			end
		end
		for _, s in seats do
			clearBot(s)
			s.model:SetAttribute("LastLamp", false)
			resetSeat(s)
			setLamp(s, 1.8, 1.5)
		end
		dimRoom(1)
		closeDoor(os.clock())
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
	e.pot = potFor(real)
	e.sabotages = {}
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
			send(player, { op = "eveningStart", seat = s.index, names = names, capacity = cfg().capacity, tab = s.tab, counted = e.counts, real = real, pot = potFor(real) })
			send(player, { op = "deal", mode = "ballroom", room = "ballroom", round = 1, cases = e.cases, pieces = list, score = s.count })
			Analytics.custom(player, "Ballroom evening started", real, nil)
		end
	end
	broadcast({ op = "eveningBegins", alive = e.alive, real = real, counted = e.counts, pot = e.pot })
	publish()
	writeBoard({ track("LIGHTS OUT"), string.format("%d lamps lit · %d guests", e.alive, real), LAST_LAMP })
end

gather = function(now: number)
	local id = "ballroom:" .. tostring(Seed.fresh())
	local e: Evening = {
		id = id,
		state = "gathering",
		gatherEndsAt = now + cfg().countdown,
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
		sabotages = {},
		pot = 0,
	}
	evening = e
	publish()
	for _, s in seats do
		send(s.player, { op = "gathering", startsIn = math.max(0, e.gatherEndsAt - os.clock()), pot = potFor(realSeated()) })
	end
	-- The room hears the countdown has begun (anyone may still take a chair until it ends).
	broadcastAll({ op = "ballroomCountdown", startsIn = cfg().countdown, pot = potFor(realSeated()) })
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
	-- A countdown with nobody left in it stops; the Ballroom stays open a little longer.
	if e and e.state == "gathering" then
		local anyone = false
		for _, other in seats do
			if other.player then
				anyone = true
			end
		end
		if not anyone then
			evening = nil
			doorState = "open"
			doorUntil = math.max(doorUntil, os.clock() + 60)
			writeBoard({ track("LIGHTS OUT"), IDLE_LINES[1], IDLE_LINES[2] })
		end
	end
	publish()
end
unseatFn = unseat

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
	s.name = Names.of(player)
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
		publish()
		send(player, { op = "gathering", startsIn = math.max(0, e.gatherEndsAt - os.clock()), pot = potFor(realSeated()) })
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
		-- Mid-evening: nobody joins late. They're told when it next opens.
		nextEvening[player] = true
		send(player, { op = "queued", opensIn = cfg().closedSeconds })
		return false, "underway"
	end
	if not e and doorState == "closed" then
		local info = BallroomService.sabotageInfo(player)
		send(player, {
			op = "ballroomClosed",
			opensIn = math.max(0, doorUntil - os.clock()),
			canOpen = true,
			price = if type(info.prices) == "table" then info.prices.open else nil,
			held = if type(info.credits) == "table" then info.credits.open else nil,
		})
		return false, "closed"
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
	if (not e and doorState == "open") or (e and e.state == "gathering") then
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
	send(player, { op = "queued", opensIn = if not e and doorState == "closed" then math.max(0, doorUntil - os.clock()) else cfg().closedSeconds })
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

---------------------------------------------------------------------------------------------------
-- Sabotage, and opening early
---------------------------------------------------------------------------------------------------
local SABOTAGE = { bomb = true, blackout = true, freeze = true, shield = true }
BallroomService.SABOTAGE = SABOTAGE

local function inBallroom(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "ballroom"
end

-- Whether `player` may send `kind` at table `seat` now, and why not: an evening in play, the
-- guest in the Ballroom (a chair or the Gallery), the table lit and not their own, not hit within
-- the last few seconds, and their own count for the evening not used up. A Shield is for their
-- own lit table. Checked before any purchase window opens, and again when it's applied.
function BallroomService.canSabotage(player: Player, kind: string, seat: number): (boolean, string?)
	local e = evening
	if not SABOTAGE[kind] then
		return false, "That isn't something the Ballroom does."
	end
	if not e or e.state ~= "playing" then
		return false, "Sabotage is only for an evening in play."
	end
	local mine = seatOf[player]
	if kind == "shield" then
		local s = if mine then seats[mine] else nil
		if not s or not s.alive then
			return false, "A Shield is for a guest whose lamp is still lit."
		end
		if s.shield > 0 then
			return false, "Your Shield is already up."
		end
		return true, nil
	end
	if not mine and not inBallroom(player) then
		return false, "Come up to the Ballroom to send one."
	end
	local target = seats[seat]
	if not target or not target.alive then
		return false, "That lamp is already out."
	end
	if mine == seat then
		return false, "Not at your own table!"
	end
	if os.clock() - target.hitAt < cfg().sabotage.gap then
		return false, "That table was hit a moment ago. Try another, or wait a few seconds."
	end
	if (e.sabotages[player] or 0) >= cfg().sabotage.perEvening then
		return false, "That's all the sabotage one guest may send in an evening."
	end
	return true, nil
end

-- Sends it (the purchase is already made, or a credit spent): the effect on the table, and the
-- whole room told who sent what to whom. A Shield on the table stops it (and is used up).
function BallroomService.sabotage(player: Player, kind: string, seat: number): (boolean, string?)
	local ok, why = BallroomService.canSabotage(player, kind, seat)
	if not ok then
		return false, why
	end
	local e = evening :: Evening
	local now = os.clock()
	local from = Names.of(player)
	local c = cfg().sabotage
	if kind == "shield" then
		local s = seats[seatOf[player] :: number]
		s.shield += 1
		s.model:SetAttribute("Shield", true)
		broadcast({ op = "sabotage", kind = "shield", by = from, seat = s.index, toName = s.name })
		return true, nil
	end
	e.sabotages[player] = (e.sabotages[player] or 0) + 1
	local target = seats[seat]
	target.hitAt = now
	if target.shield > 0 then
		target.shield -= 1
		target.model:SetAttribute("Shield", target.shield > 0)
		broadcast({ op = "sabotage", kind = kind, by = from, seat = seat, toName = target.name, blocked = true })
		send(target.player, { op = "sabotaged", kind = kind, by = from, blocked = true })
		return true, nil
	end
	local fromSeat = seatOf[player] or 0
	if kind == "bomb" then
		e.nextParcel += 1
		local parcel: Parcel = { id = e.nextParcel, from = fromSeat, count = c.bombPieces, opensAt = now + c.bombFuse }
		table.insert(target.waiting, parcel)
		broadcast({ op = "parcel", from = fromSeat, to = seat, id = parcel.id, count = c.bombPieces, fuse = c.bombFuse, bomb = true })
	elseif kind == "freeze" then
		target.fumbleUntil = math.max(target.fumbleUntil, now + c.freeze)
	elseif kind == "blackout" and target.bot then
		-- (A Stand-in can't be blinded: it slows instead.)
		target.fumbleUntil = math.max(target.fumbleUntil, now + c.blackout * 0.5)
	end
	broadcast({ op = "sabotage", kind = kind, by = from, seat = seat, toName = target.name })
	send(target.player, { op = "sabotaged", kind = kind, by = from, seconds = if kind == "blackout" then c.blackout elseif kind == "freeze" then c.freeze else c.bombFuse })
	return true, nil
end

-- What a guest's sabotage panel lists: the tables still lit (name, felt, Shield), their own, and
-- how many more they may send.
local function sabotageTargets(player: Player): { [string]: any }
	local list = {}
	for i, s in seats do
		if s.alive then
			table.insert(list, { seat = i, name = s.name, felt = s.count, shield = s.shield > 0, standIn = s.player == nil })
		end
	end
	table.sort(list, function(a, b)
		return a.seat < b.seat
	end)
	local e = evening
	local used = if e then e.sabotages[player] or 0 else 0
	return { op = "sabotageInfo", targets = list, mine = seatOf[player], left = math.max(0, cfg().sabotage.perEvening - used), playing = e ~= nil and e.state == "playing" }
end

-- Opens the Ballroom now, for everyone (bought, or the owner's word). False if it's already
-- open or an evening is on.
function BallroomService.openNow(by: string?): (boolean, string?)
	if evening then
		return false, "An evening is already on."
	end
	if doorState == "open" then
		return false, "The Ballroom is already open."
	end
	openDoor(os.clock(), by)
	return true, nil
end

-- Whether the Ballroom is shut just now (no evening, between its hours).
function BallroomService.isClosed(): boolean
	return evening == nil and doorState == "closed"
end

-- The Ballroom's state, for the owner's tools and tests.
function BallroomService.door(): (string, number)
	return doorState, doorUntil
end

local seatedElsewhere: (Player) -> boolean = function()
	return false
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
	elseif m.op == "sabotage" then
		local kind = if type(m.kind) == "string" and SABOTAGE[m.kind :: string] then m.kind :: string else nil
		local seat = if type(m.seat) == "number" and m.seat == math.floor(m.seat :: number) and seats[m.seat :: number] then m.seat :: number else 0
		if not kind then
			return
		end
		local ok, why = BallroomService.requestSabotage(player, kind, seat)
		if not ok then
			send(player, { op = "sabotageRefused", why = why or "Not just now." })
		end
		return
	elseif m.op == "sabotageInfo" then
		local info = sabotageTargets(player)
		local extra = BallroomService.sabotageInfo(player)
		info.prices = extra.prices
		info.credits = extra.credits
		send(player, info)
		return
	elseif m.op == "openNow" then
		local ok, why = BallroomService.requestOpen(player)
		if not ok then
			send(player, { op = "ballroomRefused", why = why or "Not just now." })
		end
		return
	elseif m.op == "goBallroom" then
		-- From anywhere in the house to the Ballroom's door, while it's open or counting down.
		local e = evening
		local character = player.Character
		if seatOf[player] or seatedElsewhere(player) or not character then
			return
		end
		if (e and e.state ~= "gathering") or (not e and doorState ~= "open") then
			send(player, { op = "ballroomRefused", why = if e then "The evening is under way: no late joins." else "The Ballroom is closed just now." })
			return
		end
		character:PivotTo(CFrame.lookAt(Layout.Ballroom.arrival + Vector3.new(0, 3, 0), Vector3.new(Layout.Ballroom.centre.X, Layout.Ballroom.arrival.Y + 3, Layout.Ballroom.centre.Z)))
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
		-- The Ballroom's hours: open for a while, then closed for a while.
		if doorState == "open" and now >= doorUntil then
			closeDoor(now)
		elseif doorState == "closed" and now >= doorUntil then
			openDoor(now)
		end
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
	seatedElsewhere = isSeatedElsewhere
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
					shield = 0,
					hitAt = -math.huge,
				}
				seats[index] = s
				resetSeat(s)
				local prompt = chair:FindFirstChild("SitPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Triggered:Connect(function(player: Player)
						local ok, why = BallroomService.sit(player, model, isSeatedElsewhere)
						if not ok and why == "underway" then
							BallroomService.say(player, "The evening is under way: nobody joins late. The Ballroom opens again after it.")
						elseif not ok and why == "closed" then
							BallroomService.say(player, string.format("The Ballroom is closed. It opens in %s.", clockText(doorUntil - os.clock())))
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
	-- The chairs and the board keep the Ballroom's hours: open (sit to begin), the countdown (last
	-- call), the evening (no late joins), closed (when it opens, or open it now).
	openDoor(os.clock())
	task.spawn(function()
		while true do
			local e = evening
			local now = os.clock()
			for _, s in seats do
				local prompt = s.chair:FindFirstChild("SitPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					local free = s.player == nil and s.bot == nil
					if e and e.state ~= "gathering" then
						prompt.Enabled = false
					elseif not e and doorState == "closed" then
						prompt.Enabled = free
						prompt.ActionText = "Ballroom closed"
						prompt.ObjectText = "Opens in " .. clockText(doorUntil - now)
					else
						prompt.Enabled = free
						prompt.ActionText = "Sit"
						prompt.ObjectText = if e then string.format("Begins in %s", clockText(e.gatherEndsAt - now)) else "Lights Out"
					end
				end
			end
			if e and e.state == "gathering" then
				writeBoard({ track("LIGHTS OUT"), string.format("Begins in %s · last call", clockText(e.gatherEndsAt - now)), string.format("The last lamp wins %d Gilt", potFor(realSeated())) })
			elseif e and e.state == "playing" then
				writeBoard({ track(if e.closing then "CLOSING TIME" else "LIGHTS OUT"), string.format("%d of %d lamps lit · no late joins", e.alive, e.of), string.format("The last lamp wins %d Gilt", e.pot) })
			elseif not e and doorState == "open" then
				writeBoard({ track("LIGHTS OUT"), string.format("Open · closes in %s", clockText(doorUntil - now)), string.format("Sit to begin · the last lamp wins %d+ Gilt", potFor(1)) })
			elseif not e then
				writeBoard({ track("CLOSED"), "Opens in " .. clockText(doorUntil - now), "Or open it now from any chair" })
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

--!strict
-- Tête-à-Tête in the Library (§9.2, Appendix H2). Two guests at opposite ends of a long table,
-- the identical deal on both felts, first to three hands. Three into one case sends a sealed
-- parcel of lookalikes across the table; your own parcels cancel the ones waiting for you.
-- The server decides every deal, checks every filing and keeps every rating.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalogue = require(ReplicatedStorage.Shared.Catalogue)
local Config = require(ReplicatedStorage.Shared.Config)
local Deal = require(ReplicatedStorage.Shared.Deal)
local Duel = require(ReplicatedStorage.Shared.Duel)
local Rating = require(ReplicatedStorage.Shared.Rating)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Seed = require(ReplicatedStorage.Shared.Seed)
local Standing = require(ReplicatedStorage.Shared.Standing)
local Voice = require(ReplicatedStorage.Shared.Voice)

local Analytics = require(script.Parent.Analytics)
local Boards = require(script.Parent.Boards)
local Dialogue = require(script.Parent.Dialogue)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local Season = require(script.Parent.Season)
local Rig = require(script.Parent.Staff.Rig)

local DuelService = {}

type Piece = { uid: number, id: string, name: string, case: string, value: number, rare: boolean, seasonal: boolean, mythic: boolean, filed: boolean }
type Parcel = { id: number, count: number, opensAt: number }
type Bot = { seconds: number, accuracy: number, nextAt: number, rig: Model? }

type Side = {
	key: string,
	player: Player?,
	bot: Bot?,
	name: string,
	model: Model,
	seat: Seat,
	pieces: { [number]: Piece },
	remaining: number,
	streak: number,
	runLength: number,
	lastCase: string?,
	runParcels: number,
	filings: number,
	correct: number,
	lastFilingAt: number,
	lastFileAt: number,
	fumbleUntil: number,
	waiting: { Parcel },
	rating: Rating.Record,
	eligible: boolean,
	again: boolean,
}

type Match = {
	id: string,
	seed: number,
	hand: number,
	sides: { [string]: Side },
	wins: { [string]: number },
	state: "starting" | "hand" | "between" | "over",
	handStarted: number,
	ranked: boolean,
	standIn: boolean,
	nextUid: number,
	nextParcel: number,
	cases: { string },
	rng: Random,
}

type DuelTable = {
	id: string,
	halves: { [string]: Model },
	seated: { [string]: Player? },
	since: { [string]: number },
	offered: { [string]: boolean },
	match: Match?,
}

local tableEvent = Remotes.event("Table")
local duels: { [string]: DuelTable } = {}
local seatedAt: { [Player]: { duel: DuelTable, side: string } } = {}
local connections: { [Player]: { RBXScriptConnection } } = {}

DuelService.say = function(_player: Player, _line: string) end

local function other(key: string): string
	return if key == "a" then "b" else "a"
end

local function send(player: Player?, message: { [string]: any })
	if player and player.Parent == Players then
		tableEvent:FireClient(player, message)
	end
end

local function sendBoth(match: Match, message: { [string]: any })
	for _, side in match.sides do
		send(side.player, message)
	end
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	local h = character and character:FindFirstChildOfClass("Humanoid")
	return if h and h.Health > 0 then h else nil
end

local function ratingOf(player: Player): Rating.Record
	local data = Profiles.get(player)
	if not data then
		return Rating.new()
	end
	-- A new Term eases every rating toward the middle (once, at the first ranked match of it).
	local term = Rating.term()
	if data.duel.term ~= "" and data.duel.term ~= term.id then
		local eased = Rating.newTerm({ r = data.duel.r, rd = data.duel.rd, vol = data.duel.vol })
		data.duel.r, data.duel.rd, data.duel.vol = eased.r, eased.rd, eased.vol
		data.duel.termMatches = 0
		data.duel.term = term.id
	end
	return { r = data.duel.r, rd = data.duel.rd, vol = data.duel.vol }
end

-- Ranked opens at the Member standing, for accounts at least three days old.
local function eligible(player: Player): boolean
	local data = Profiles.get(player)
	if not data then
		return false
	end
	if player.AccountAge < Config.data.Library.rankedAccountDays then
		return false
	end
	return Standing.atLeast(data.nights.count, data.stats.rounds, "Member")
end

local function markLabel(player: Player?): string?
	if not player then
		return nil
	end
	local data = Profiles.get(player)
	if not data or data.duel.matches < Config.data.Library.placementMatches then
		return nil
	end
	return Rating.mark(data.duel.r).label
end

local function publicPiece(p: Piece): { [string]: any }
	return { uid = p.uid, id = p.id, name = p.name, case = p.case, value = p.value, rare = p.rare, seasonal = p.seasonal, mythic = false }
end

local function newSide(key: string, model: Model, player: Player?, bot: Bot?, name: string, rating: Rating.Record): Side
	return {
		key = key,
		player = player,
		bot = bot,
		name = name,
		model = model,
		seat = model:FindFirstChild("Chair") :: Seat,
		pieces = {},
		remaining = 0,
		streak = 0,
		runLength = 0,
		lastCase = nil,
		runParcels = 0,
		filings = 0,
		correct = 0,
		lastFilingAt = 0,
		lastFileAt = 0,
		fumbleUntil = 0,
		waiting = {},
		rating = rating,
		eligible = if player then eligible(player) else false,
		again = false,
	}
end

-- A Stand-in: an opponent played by a model fitted to your level. Clearly marked, never ranked.
local function standInRig(model: Model): Model?
	local seat = model:FindFirstChild("Chair")
	if not seat or not seat:IsA("Seat") then
		return nil
	end
	local look = Rig.look("Doorman")
	look.coat = Color3.fromRGB(40, 42, 48)
	look.skin = Color3.fromRGB(150, 150, 156)
	local existing = model:FindFirstChild("StandIn")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "StandIn"
	folder.Parent = model
	local staff = Rig.build("Stand-in", look, seat.CFrame * CFrame.new(0, 0, 2), folder)
	staff.model:SetAttribute("StandIn", true)
	for _, d in staff.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = if d.Name == "HumanoidRootPart" then 1 else 0.35 -- a hollow figure
		end
	end
	local head = staff.model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local tag = Instance.new("BillboardGui")
		tag.Name = "HollowPlate"
		tag.Size = UDim2.fromOffset(160, 30)
		tag.StudsOffset = Vector3.new(0, 2, 0)
		tag.LightInfluence = 0
		tag.MaxDistance = 60
		tag.Parent = head
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.Bodoni
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(198, 160, 82)
		label.TextTransparency = 0.55
		label.TextStrokeColor3 = Color3.fromRGB(236, 216, 166)
		label.TextStrokeTransparency = 0.2
		label.Text = "Stand-in"
		label.Parent = tag
	end
	seat:Sit(staff.humanoid)
	return staff.model
end

local startHand: (match: Match, hand: number) -> ()
local matchEnd: (match: Match, winner: string, reason: string, leaver: string?) -> ()

local function deal(match: Match, side: Side, pieces: { any })
	side.pieces = {}
	for _, p in pieces do
		match.nextUid += 1
		local piece: Piece = {
			uid = match.nextUid,
			id = p.id,
			name = p.name,
			case = p.case,
			value = p.value,
			rare = p.rare,
			seasonal = p.seasonal,
			mythic = false,
			filed = false,
		}
		side.pieces[piece.uid] = piece
	end
	side.remaining = #pieces
	-- The brass counter on each half shows the pieces left, for the room to follow.
	side.model:SetAttribute("Score", side.remaining)
	side.streak = 0
	side.runLength = 0
	side.lastCase = nil
	side.runParcels = 0
	side.filings = 0
	side.correct = 0
	side.lastFilingAt = 0
	side.fumbleUntil = 0
	side.waiting = {}
end

local function list(side: Side): { { [string]: any } }
	local out = {}
	for _, p in side.pieces do
		if not p.filed then
			table.insert(out, publicPiece(p))
		end
	end
	table.sort(out, function(a, b)
		return a.uid < b.uid
	end)
	return out
end

startHand = function(match: Match, hand: number)
	if match.state == "over" then
		return
	end
	match.state = "hand"
	match.hand = hand
	local room = Duel.room(hand)
	local result = Deal.generate(Seed.hash(match.id .. ":" .. hand), room, 1, Season.current().id, { allowMythic = false })
	match.cases = result.cases
	for _, side in match.sides do
		deal(match, side, result.pieces)
		if side.bot then
			side.bot.nextAt = os.clock() + 1.2 + side.bot.seconds
		end
	end
	match.handStarted = os.clock()
	for key, side in match.sides do
		local rival = match.sides[other(key)]
		send(side.player, {
			op = "deal",
			mode = "duel",
			room = "library",
			side = key,
			round = hand,
			cases = match.cases,
			pieces = list(side),
			score = side.remaining,
			wins = match.wins,
			-- The hand's cap drains the clock rail; at the end, fewer pieces left takes it.
			clock = { left = Config.data.Library.handCap, running = true, budget = Config.data.Library.handCap },
		})
		send(side.player, { op = "rivalDeal", side = other(key), cases = match.cases, pieces = list(rival) })
	end
end

local function openParcels(match: Match, side: Side, now: number)
	local i = 1
	while i <= #side.waiting do
		local parcel = side.waiting[i]
		if now >= parcel.opensAt then
			table.remove(side.waiting, i)
			local added = {}
			for _, id in Duel.lookalikes(match.cases, parcel.count, match.rng) do
				local p = Catalogue.byId[id]
				match.nextUid += 1
				local piece: Piece = { uid = match.nextUid, id = p.id, name = p.name, case = p.case, value = p.value, rare = false, seasonal = false, mythic = false, filed = false }
				side.pieces[piece.uid] = piece
				table.insert(added, publicPiece(piece))
			end
			side.remaining += #added
			side.model:SetAttribute("Score", side.remaining)
			sendBoth(match, { op = "parcelOpen", side = side.key, id = parcel.id, pieces = added, remaining = side.remaining })
		else
			i += 1
		end
	end
end

local function sendParcels(match: Match, from: Side, count: number)
	local n = count
	-- Your own parcels first cancel any waiting on your side.
	while n > 0 and #from.waiting > 0 do
		local parcel = from.waiting[1]
		parcel.count -= 1
		n -= 1
		if parcel.count <= 0 then
			table.remove(from.waiting, 1)
			sendBoth(match, { op = "parcelCancel", side = from.key, id = parcel.id })
		else
			sendBoth(match, { op = "parcelShrink", side = from.key, id = parcel.id, count = parcel.count })
		end
	end
	if n <= 0 then
		return
	end
	local to = match.sides[other(from.key)]
	match.nextParcel += 1
	local fuse = Config.data.Library.parcelFuse
	local parcel: Parcel = { id = match.nextParcel, count = n, opensAt = os.clock() + fuse }
	table.insert(to.waiting, parcel)
	sendBoth(match, { op = "parcel", from = from.key, to = to.key, id = parcel.id, count = n, fuse = fuse })
end

local function handEnd(match: Match, winner: string)
	if match.state ~= "hand" then
		return
	end
	match.state = "between"
	match.wins[winner] += 1
	for _, side in match.sides do
		side.waiting = {}
	end
	sendBoth(match, { op = "handEnd", winner = winner, wins = match.wins, hand = match.hand })
	if match.wins[winner] >= Config.data.Library.handsToWin then
		task.delay(1.5, matchEnd, match, winner, "won")
	else
		task.delay(Config.data.Library.betweenHands, function()
			if (match.state :: string) == "between" then
				startHand(match, match.hand + 1)
			end
		end)
	end
end

local function file(match: Match, side: Side, uid: number, caseId: string)
	if match.state ~= "hand" then
		return
	end
	local piece = side.pieces[uid]
	if not piece or piece.filed or not table.find(match.cases, caseId) then
		return
	end
	local now = os.clock()
	if now < side.fumbleUntil or now - side.lastFileAt < Config.data.FairPlay.minGap then
		send(side.player, { op = "rejected", uid = uid })
		return
	end
	side.lastFileAt = now
	side.filings += 1
	side.lastFilingAt = now
	local correct = piece.case == caseId
	local parcels = 0
	if correct then
		piece.filed = true
		side.remaining -= 1
		side.model:SetAttribute("Score", side.remaining)
		side.correct += 1
		side.streak += 1
		if side.lastCase == caseId then
			side.runLength += 1
		else
			side.runLength = 1
			side.runParcels = 0
		end
		side.lastCase = caseId
		local fromRun, fromStreak = Duel.parcels(side.runLength, side.runParcels, side.streak)
		side.runParcels += fromRun
		parcels = fromRun + fromStreak
	else
		side.streak = 0
		side.runLength = 0
		side.runParcels = 0
		side.lastCase = nil
		side.fumbleUntil = now + Config.data.Library.fumble
	end
	send(side.player, {
		op = "filed",
		uid = uid,
		case = caseId,
		correct = correct,
		points = 0,
		setBonus = 0,
		penalty = 0,
		score = side.remaining,
		streak = side.streak,
		multiplier = 1,
		runLength = side.runLength,
		remaining = side.remaining,
		fumble = if correct then nil else Config.data.Library.fumble,
	})
	send(match.sides[other(side.key)].player, { op = "rivalFiled", uid = uid, case = caseId, correct = correct, remaining = side.remaining })
	if parcels > 0 then
		sendParcels(match, side, parcels)
	end
	if side.remaining == 0 then
		handEnd(match, side.key)
	end
end

local function botStep(match: Match, side: Side, now: number)
	local bot = side.bot
	if not bot or now < bot.nextAt or now < side.fumbleUntil then
		return
	end
	local open = {}
	for _, p in side.pieces do
		if not p.filed then
			table.insert(open, p)
		end
	end
	if #open == 0 then
		return
	end
	table.sort(open, function(a, b)
		return a.uid < b.uid
	end)
	local piece = open[match.rng:NextInteger(1, #open)]
	local caseId = piece.case
	if match.rng:NextNumber() > bot.accuracy then
		local wrong = {}
		for _, c in match.cases do
			if c ~= piece.case then
				table.insert(wrong, c)
			end
		end
		if #wrong > 0 then
			caseId = wrong[match.rng:NextInteger(1, #wrong)]
		end
	end
	bot.nextAt = now + bot.seconds * match.rng:NextNumber(0.7, 1.35)
	side.lastFileAt = 0 -- the Stand-in paces itself
	file(match, side, piece.uid, caseId)
end

matchEnd = function(match: Match, winner: string, reason: string, leaver: string?)
	if match.state == "over" then
		return
	end
	match.state = "over"
	local a, b = match.sides.a, match.sides.b
	local records: { [string]: { before: number, after: number, markBefore: string, markAfter: string } } = {}
	if match.ranked and a.player and b.player then
		for key, side in match.sides do
			local rival = match.sides[other(key)]
			local score = if key == winner then 1 else 0
			local updated = Rating.update(side.rating, { rival.rating }, { score })
			local data = Profiles.get(side.player :: Player)
			local before = side.rating.r
			if data then
				data.duel.r, data.duel.rd, data.duel.vol = updated.r, updated.rd, updated.vol
				data.duel.term = Rating.term().id
				data.duel.termMatches += 1
				data.duel.best = math.max(data.duel.best, updated.r)
				Boards.submitRating(side.player :: Player, updated.r)
			end
			records[key] = { before = before, after = updated.r, markBefore = Rating.mark(before).label, markAfter = Rating.mark(updated.r).label }
		end
	end
	for key, side in match.sides do
		local player = side.player
		if player and key ~= leaver then
			local won = key == winner
			local data = Profiles.get(player)
			local gilt = 0
			local placementLeft = nil
			if data then
				data.duel.matches += if match.ranked then 1 else 0
				if won then
					data.duel.wins += 1
				else
					data.duel.losses += 1
				end
				gilt = Gilt.pay(player, data, if won then Config.data.Library.giltWin else Config.data.Library.giltLoss, "Tête-à-Tête")
				if match.ranked then
					placementLeft = math.max(0, Config.data.Library.placementMatches - data.duel.matches)
				end
			end
			local record = records[key]
			send(player, {
				op = "duelEnd",
				won = won,
				wins = match.wins,
				reason = reason,
				ranked = match.ranked,
				standIn = match.standIn,
				rival = match.sides[other(key)].name,
				before = if record then record.before else nil,
				after = if record then record.after else nil,
				markBefore = if record and placementLeft == 0 then record.markBefore else nil,
				markAfter = if record and placementLeft == 0 then record.markAfter else nil,
				placementLeft = placementLeft,
				gilt = gilt,
			})
			DuelService.say(player, if won then Voice.Concierge.libraryWin else Voice.Concierge.libraryLoss)
			Analytics.custom(player, "Library match finished", if won then 1 else 0, {
				ranked = match.ranked,
				standIn = match.standIn,
				hands = match.hand,
				reason = reason,
			})
		end
	end
end

local function startMatch(tbl: DuelTable, standIn: boolean)
	local sides: { [string]: Side } = {}
	local id = tbl.id .. ":" .. tostring(Seed.fresh())
	for _, key in { "a", "b" } do
		local player = tbl.seated[key]
		if player then
			sides[key] = newSide(key, tbl.halves[key], player, nil, player.DisplayName, ratingOf(player))
		end
	end
	if standIn then
		-- The empty side gets a Stand-in fitted to the waiting guest's rating.
		local emptyKey = if sides.a then "b" else "a"
		local guest = sides[other(emptyKey)]
		local rating = if guest then guest.rating else Rating.new()
		local seconds, accuracy = Duel.standInPace(rating.r)
		local bot: Bot = { seconds = seconds, accuracy = accuracy, nextAt = 0, rig = nil }
		bot.rig = standInRig(tbl.halves[emptyKey])
		sides[emptyKey] = newSide(emptyKey, tbl.halves[emptyKey], nil, bot, "Stand-in", { r = rating.r, rd = 80, vol = 0.06 })
	end
	if not sides.a or not sides.b then
		return
	end
	local ranked = not standIn and sides.a.eligible and sides.b.eligible
	local match: Match = {
		id = id,
		seed = Seed.hash(id),
		hand = 0,
		sides = sides,
		wins = { a = 0, b = 0 },
		state = "starting",
		handStarted = 0,
		ranked = ranked,
		standIn = standIn,
		nextUid = 0,
		nextParcel = 0,
		cases = {},
		rng = Random.new(Seed.hash(id .. ":parcels")),
	}
	tbl.match = match
	tbl.offered = {}
	for key, side in sides do
		local rival = sides[other(key)]
		send(side.player, {
			op = "duelStart",
			side = key,
			rival = rival.name,
			ranked = ranked,
			standIn = standIn,
			mark = markLabel(side.player),
			rivalMark = markLabel(rival.player),
			eligible = side.eligible,
		})
		if side.player then
			DuelService.say(side.player, Voice.Concierge.duelSeated)
		end
	end
	task.delay(2.5, startHand, match, 1)
end

local function clearStandIn(tbl: DuelTable)
	for _, half in tbl.halves do
		half:SetAttribute("Score", 0)
		local folder = half:FindFirstChild("StandIn")
		if folder then
			folder:Destroy()
		end
	end
end

local function unseat(player: Player)
	local at = seatedAt[player]
	if not at then
		return
	end
	seatedAt[player] = nil
	local tbl = at.duel
	tbl.seated[at.side] = nil
	tbl.since[at.side] = nil
	local conns = connections[player]
	if conns then
		for _, c in conns do
			c:Disconnect()
		end
	end
	connections[player] = nil
	local match = tbl.match
	if match and match.state ~= "over" then
		-- Leaving mid-match counts as a loss.
		matchEnd(match, other(at.side), "forfeit", at.side)
		-- The leaver's result still counts: a loss.
		local data = Profiles.get(player)
		if data then
			data.duel.losses += 1
		end
	end
	if match then
		tbl.match = nil
		clearStandIn(tbl)
		-- The guest left behind waits for a new opponent.
		local stayKey = other(at.side)
		if tbl.seated[stayKey] then
			tbl.since[stayKey] = os.clock()
			send(tbl.seated[stayKey], { op = "duelWaiting" })
		end
	end
	local seat = tbl.halves[at.side]:FindFirstChild("Chair")
	local weld = seat and seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	send(player, { op = "left" })
end

function DuelService.isSeated(player: Player): boolean
	return seatedAt[player] ~= nil
end

function DuelService.sit(player: Player, model: Model, isSeatedElsewhere: (Player) -> boolean): (boolean, string?)
	if seatedAt[player] or isSeatedElsewhere(player) then
		return false, "seated"
	end
	local duelId = model:GetAttribute("Duel")
	local sideKey = model:GetAttribute("Side")
	if type(duelId) ~= "string" or (sideKey ~= "a" and sideKey ~= "b") then
		return false, "unavailable"
	end
	local tbl = duels[duelId]
	if not tbl then
		return false, "unavailable"
	end
	local key = sideKey :: string
	if tbl.seated[key] or (tbl.match and tbl.match.sides[key] and tbl.match.sides[key].bot) then
		return false, "taken"
	end
	local humanoid = humanoidOf(player)
	local seat = model:FindFirstChild("Chair")
	if not humanoid or not seat or not seat:IsA("Seat") then
		return false, "unavailable"
	end
	local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or (root.Position - seat.Position).Magnitude > 12 then
		return false, "far"
	end
	tbl.seated[key] = player
	seat:Sit(humanoid)
	local waited = 0
	while humanoid.SeatPart ~= seat and waited < 1.5 do
		task.wait(0.05)
		waited += 0.05
	end
	if humanoid.SeatPart ~= seat then
		tbl.seated[key] = nil
		return false, "unavailable"
	end
	seatedAt[player] = { duel = tbl, side = key }
	tbl.since[key] = os.clock()
	connections[player] = {
		humanoid.Seated:Connect(function(active: boolean, part: BasePart?)
			if not active or part ~= seat then
				unseat(player)
			end
		end),
		humanoid.Died:Connect(function()
			unseat(player)
		end),
	}
	send(player, { op = "seated", table = model:GetAttribute("TableId"), room = "library", mode = "duel", centre = model:GetAttribute("Centre") })
	Analytics.custom(player, "Library seated", nil, nil)
	local otherKey = other(key)
	if tbl.seated[otherKey] and not tbl.match then
		startMatch(tbl, false)
	else
		send(player, { op = "duelWaiting" })
		DuelService.say(player, Voice.Concierge.waiting)
	end
	return true, nil
end

local function offerStandIn(tbl: DuelTable, key: string)
	local player = tbl.seated[key]
	if not player or tbl.match or tbl.offered[key] then
		return
	end
	tbl.offered[key] = true
	local data = Profiles.get(player)
	if data and data.settings.offerStandIn == "No" then
		return
	end
	Dialogue.say(player, "THE CONCIERGE", Voice.Concierge.standInOffer, {
		{ id = "standin", text = Voice.Concierge.standInYes },
		{ id = "wait", text = Voice.Concierge.standInWait },
	}, function(choice)
		if choice == "standin" and tbl.seated[key] == player and not tbl.match and not tbl.seated[other(key)] then
			startMatch(tbl, true)
		end
	end)
end

local function onMessage(player: Player, message: unknown)
	local at = seatedAt[player]
	if not at or type(message) ~= "table" then
		return
	end
	local m = message :: { [string]: unknown }
	local tbl = at.duel
	local match = tbl.match
	if m.op == "file" then
		if match and type(m.uid) == "number" and type(m.case) == "string" then
			file(match, match.sides[at.side], m.uid :: number, m.case :: string)
		end
	elseif m.op == "leave" then
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.Sit = false
		end
		unseat(player)
	elseif m.op == "again" then
		if match and match.state == "over" then
			local mine = match.sides[at.side]
			mine.again = true
			local rival = match.sides[other(at.side)]
			if rival.bot then
				clearStandIn(tbl)
				tbl.match = nil
				startMatch(tbl, true)
			elseif rival.again then
				tbl.match = nil
				startMatch(tbl, false)
			else
				send(rival.player, { op = "rematchAsked", by = player.DisplayName })
			end
		end
	end
end

function DuelService.start(isSeatedElsewhere: (Player) -> boolean)
	for _, half in CollectionService:GetTagged("DuelHalf") do
		if half:IsA("Model") then
			local id = half:GetAttribute("Duel")
			local side = half:GetAttribute("Side")
			if type(id) == "string" and type(side) == "string" then
				local tbl = duels[id]
				if not tbl then
					tbl = { id = id, halves = {}, seated = {}, since = {}, offered = {}, match = nil }
					duels[id] = tbl
				end
				tbl.halves[side] = half
				local seat = half:FindFirstChild("Chair")
				local prompt = seat and seat:FindFirstChild("SitPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Triggered:Connect(function(player: Player)
						local ok, why = DuelService.sit(player, half, isSeatedElsewhere)
						if not ok and why == "taken" then
							DuelService.say(player, "That chair is taken. The other table may be free.")
						end
					end)
				end
			end
		end
	end
	tableEvent.OnServerEvent:Connect(onMessage)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, tbl in duels do
			local match = tbl.match
			if match and match.state == "hand" then
				for _, side in match.sides do
					openParcels(match, side, now)
					if side.bot then
						botStep(match, side, now)
					end
				end
				if match.state == "hand" and now - match.handStarted >= Config.data.Library.handCap then
					local function result(side: Side): Duel.SideResult
						return {
							remaining = side.remaining,
							accuracy = if side.filings > 0 then side.correct / side.filings else 0,
							lastFilingAt = if side.lastFilingAt > 0 then side.lastFilingAt else math.huge,
						}
					end
					handEnd(match, Duel.capWinner(result(match.sides.a), result(match.sides.b)))
				end
			elseif not match then
				-- A guest waiting alone is offered a Stand-in after a while.
				for key, since in tbl.since do
					if tbl.seated[key] and now - since >= Config.data.Library.standInAt then
						offerStandIn(tbl, key)
					end
				end
			end
		end
	end)
	-- Hide a chair's prompt while it's occupied.
	task.spawn(function()
		while true do
			for _, tbl in duels do
				for key, half in tbl.halves do
					local seat = half:FindFirstChild("Chair")
					local prompt = seat and seat:FindFirstChild("SitPrompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						local match = tbl.match
						local botHere = match ~= nil and match.sides[key] ~= nil and match.sides[key].bot ~= nil
						prompt.Enabled = tbl.seated[key] == nil and not botHere
					end
				end
			end
			task.wait(0.5)
		end
	end)
	Players.PlayerRemoving:Connect(unseat)
end

return DuelService

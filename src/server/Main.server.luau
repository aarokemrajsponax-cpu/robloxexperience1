--!strict
-- Maison Noir: server boot. Guests come first: nobody spawns until the house is built, and then
-- everyone is placed where they belong. Every other part of the house starts on its own, so a
-- part that fails (a Roblox service unavailable in Studio, say) is reported and never stops
-- anyone from walking in.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Before anything else: Roblox must not spawn anyone by itself. (In Studio the Baseplate
-- template's SpawnLocation sits in the middle of the Foyer, just behind the front doors.)
Players.CharacterAutoLoads = false
for _, name in { "Baseplate", "SpawnLocation" } do
	local item = Workspace:FindFirstChild(name)
	if item and item:IsA("BasePart") then
		item:Destroy()
	end
end

local Build = require(ReplicatedStorage.Shared.Build)
print(string.format("[Maison] %s (server)", Build.label))

local failed: { string } = {}
local bootStarted = os.clock()
-- Runs one part of the house's start; a failure is reported (with where it happened) and the
-- rest of the house carries on. The step under way is published (MaisonBoot), and any step that
-- takes a while says so in Output, so a slow start can always be pinned on its cause.
local function boot(name: string, fn: () -> ())
	local message = ""
	local began = os.clock()
	Workspace:SetAttribute("MaisonBoot", name)
	local ok = xpcall(fn, function(e: any)
		message = debug.traceback(tostring(e))
	end)
	local took = os.clock() - began
	if took > 1 then
		print(string.format("[Maison] %s took %.1f s (%.1f s since the server started).", name, took, os.clock() - bootStarted))
	end
	if not ok then
		table.insert(failed, name)
		warn(string.format("[Maison] %s didn't start: %s", name, message))
	end
end

local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.event("Guest") -- creates every remote before any client asks for one

-- The owner sees anything that breaks on the server, on their own screen (ErrorNotice): a
-- screenshot is then enough to say what went wrong. (Listening from the very start, so a problem
-- while the house is still being built shows too.)
do
	local LogService = game:GetService("LogService")
	local RunService = game:GetService("RunService")
	local errors = Remotes.event("Errors")
	local sent = 0
	local window = os.clock()
	LogService.MessageOut:Connect(function(message: string, kind: Enum.MessageType)
		local important = kind == Enum.MessageType.MessageError or (kind == Enum.MessageType.MessageWarning and string.find(message, "[Maison]", 1, true) ~= nil)
		if not important then
			return
		end
		if os.clock() - window > 10 then
			window = os.clock()
			sent = 0
		end
		sent += 1
		if sent > 6 then
			return
		end
		for _, p in Players:GetPlayers() do
			if RunService:IsStudio() or p:GetAttribute("MaisonAdmin") == true then
				pcall(function()
					errors:FireClient(p, "Server: " .. message)
				end)
			end
		end
	end)
end

-- The dashboard's Configs load while the house builds (nobody waits for one, then the other).
local LiveConfig = require(script.Parent.LiveConfig)
local configsLoaded: (number) -> () = function() end
boot("Live Configs", function()
	configsLoaded = LiveConfig.begin()
end)

-- The house goes up in one piece, in about a second, and guests spawn straight after; the last
-- polish (the flicker fix) finishes a moment later while they look around.
local World = require(script.Parent.World.Build)
local maison: Instance = Workspace
local began = os.clock()
boot("The house", function()
	maison = World.run({ polishLater = true })
end)
print(string.format("[Maison] The house stands (%.1f s).", os.clock() - began))
Workspace:SetAttribute("MaisonReady", true)

-- Guests next, before anything else can go wrong: characters, placing, the welcome.
local Guests = require(script.Parent.Guests)
boot("Guests", Guests.start)
boot("Live Configs", function()
	configsLoaded(3)
end)

-- Seats everywhere (the sofas, the loungers, your Suite's furniture).
boot("Seating", require(script.Parent.Seating).start)

-- The Vault's door (it opens as you come near) and the lift between the Suite and the Vault.
local VaultAccess = require(script.Parent.VaultAccess)
boot("The Vault door and the lift", VaultAccess.start)

local Season = require(script.Parent.Season)
Season.dress = require(script.Parent.World.SeasonDress).apply
boot("Seasons", Season.start)

local Dialogue = require(script.Parent.Dialogue)
boot("Dialogue", Dialogue.start)

-- A Private Evening (a private server): records off, the host arranges the Ballroom.
boot("Private Evening", require(script.Parent.Private).publish)

-- Notifications (Open Cloud; the key lives in the experience's secrets).
local Notify = require(script.Parent.Notify)
boot("Notifications", Notify.start)

-- Circles: the week's top Circles on the boards, the crest on nameplates.
local CircleService = require(script.Parent.CircleService)

local staffFolder = Instance.new("Folder")
staffFolder.Name = "Staff"
staffFolder.Parent = maison
local Concierge = require(script.Parent.Staff.Concierge)
local Doorman = require(script.Parent.Staff.Doorman)
local Tailor = require(script.Parent.Staff.Tailor)
local Archivist = require(script.Parent.Staff.Archivist)
local Pianist = require(script.Parent.Staff.Pianist)
task.spawn(Archivist.spawn, staffFolder)
task.spawn(Concierge.spawn, staffFolder)
task.spawn(Doorman.spawn, staffFolder)
task.spawn(Tailor.spawn, staffFolder)
task.spawn(Pianist.spawn, staffFolder)

local Analytics = require(script.Parent.Analytics)
boot("Analytics", Analytics.start)

local Boards = require(script.Parent.Boards)
local Memory = require(script.Parent.Memory)
boot("Boards", Boards.start)

local LedgerService = require(script.Parent.LedgerService)
local Collection = require(script.Parent.Collection)
local SoireeService = require(script.Parent.SoireeService)
SoireeService.notice = function(player, title, line)
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = title, line = line })
end
SoireeService.board = Boards.setSoiree
boot("The Soirée", SoireeService.start)

local TableService = require(script.Parent.TableService)
TableService.say = function(player, line)
	Concierge.line(player, line, 3)
end
Concierge.isSeated = TableService.isSeated
Concierge.canEnter = function(player, room)
	if room ~= "midnight" then
		return true
	end
	local data = require(script.Parent.Profiles).get(player)
	return data ~= nil and data.flags.midnight == true
end
Concierge.openHowTo = function(player)
	Remotes.event("Guest"):FireClient(player, { op = "howto" })
end
Concierge.inviteToLibrary = function(player)
	Remotes.event("Guest"):FireClient(player, { op = "inviteLibrary" })
end
boot("Tables", TableService.start)

local DuelService = require(script.Parent.DuelService)
DuelService.say = function(player, line)
	Concierge.line(player, line, 3)
end
local BallroomService = require(script.Parent.BallroomService)
boot("The Library", function()
	DuelService.start(function(player)
		return TableService.isSeated(player) or BallroomService.isSeated(player)
	end)
end)
BallroomService.say = function(player, line)
	Concierge.line(player, line, 4)
end
boot("The Ballroom", function()
	BallroomService.start(function(player)
		return TableService.isSeated(player) or DuelService.isSeated(player)
	end)
end)
TableService.isBusy = function(player)
	return DuelService.isSeated(player) or BallroomService.isSeated(player)
end
Concierge.isSeated = function(player)
	return TableService.isSeated(player) or DuelService.isSeated(player) or BallroomService.isSeated(player)
end
VaultAccess.isSeated = Concierge.isSeated
-- Lights Out records: Last Lamps, top-five finishes and Keys (only evenings with enough real
-- guests count), and the weekly board of points.
BallroomService.onFinished = function(player, place, keys, counted)
	if place == 1 then
		Memory.highlight(player, "you kept the last lamp in the Ballroom")
	end
	LedgerService.add(player, "ballroom", place)
	if counted then
		SoireeService.record(player, "ballroom", { place = place, keys = keys })
	end
	Collection.ballroom(player, place)
	local data = require(script.Parent.Profiles).get(player)
	if not data or not counted then
		return
	end
	CircleService.add(player, "ballroom", require(ReplicatedStorage.Shared.LightsOut).points(place, keys))
	local b = data.ballroom
	b.evenings += 1
	b.keys += keys
	b.bestKeys = math.max(b.bestKeys, keys)
	if place == 1 then
		b.lastLamps += 1
	end
	if place <= 5 then
		b.topFive += 1
	end
	local week = require(ReplicatedStorage.Shared.Rival).week()
	if b.week ~= week then
		b.week = week
		b.weekPoints = 0
	end
	b.weekPoints += require(ReplicatedStorage.Shared.LightsOut).points(place, keys)
	Boards.submit(player, "ballroom", b.weekPoints)
end
BallroomService.onResult = function(tableNumber, name, keys)
	Boards.ballroomResult(tableNumber, name, keys)
end

local Dressing = require(script.Parent.Dressing)
Dressing.crestOf = CircleService.crest
boot("Dressing", Dressing.start)
local Shop = require(script.Parent.Shop)
CircleService.board = Boards.setCircles
local SaluteService = require(script.Parent.SaluteService)
SaluteService.note = Boards.note
SaluteService.benefactor = Dressing.nameplate

-- House controls: the owner's panel (events, spectacle, gifts, announcements).
local AdminService = require(script.Parent.AdminService)
AdminService.salute = SaluteService.play
AdminService.season = Season.force
AdminService.note = Boards.note
AdminService.isSeated = function(player)
	return TableService.isSeated(player) or DuelService.isSeated(player) or BallroomService.isSeated(player)
end
LedgerService.boost = AdminService.ledgerBoost
TableService.mythicLuck = AdminService.mythicLuck
boot("House controls", AdminService.start)
CircleService.changed = function(player)
	Dressing.nameplate(player)
	Shop.push(player)
end
boot("Circles", CircleService.start)
Shop.handOver = function(player, from, itemName)
	Concierge.line(player, string.format("A gift for you, from %s: %s.", from, itemName), 4)
end
-- A guest bought a Golden Hour for everyone: the house's own event, with their name on it. A
-- second one bought while the first runs adds its time (nobody's purchase cuts another's short).
Shop.goldenHour = function(buyer, seconds)
	local ends = Workspace:GetAttribute(require(ReplicatedStorage.Shared.HouseEvents).attribute("goldenHour"))
	local left = if type(ends) == "number" then math.max(0, ends - os.time()) else 0
	AdminService.startEvent("goldenHour", left + seconds, buyer.DisplayName)
	Remotes.event("Salute"):FireAllClients({ op = "salute", id = "goldenHourGift", by = buyer.DisplayName, effects = { "goldLeaf", "fireworks" }, seconds = 10, title = "Golden Hour", line = buyer.DisplayName .. " bought a Golden Hour for everyone: double Gilt for every guest!" })
end
boot("The Boutique", Shop.start)
-- Every Robux purchase: receipts, the purchase ledger, prompts, and the five products. After the
-- Boutique (whose handlers it validates), before Profiles (it listens for arrivals).
local Purchases = require(script.Parent.Purchases)
boot("Purchases", Purchases.start)
-- A guest at the Foyer's piano: the Pianist gets up for them, and sits back down after.
Purchases.Piano.onSession = function(playing: boolean)
	Pianist.stepAside(playing)
end
-- The owner plays free (and anyone testing in Studio).
Purchases.Piano.isOwner = function(player: Player): boolean
	return game:GetService("RunService"):IsStudio() or AdminService.isAdmin(player)
end
-- Trading curios between guests (the curios and Gems themselves start with Purchases).
boot("Guest policies", require(script.Parent.Policy).start)
boot("Trading", require(script.Parent.TradeService).start)
boot("Remote limits", require(script.Parent.RemoteGuard).start)
-- Friends on Roblox in the house together: each may visit the other's Suite, and both earn more
-- Gilt while they're here.
local Friends = require(script.Parent.Friends)
local SuiteVisits = require(script.Parent.SuiteVisits)
require(script.Parent.Gilt).friends = Friends.giltBoost
Friends.arrived = function(player: Player, friend: Player)
	local more = math.floor((require(ReplicatedStorage.Shared.Config).data.Friends.giltBoost - 1) * 100 + 0.5)
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = "A friend is here", line = string.format("%s is in the house: friends together earn %d%% more Gilt, and you can visit each other's Suites.", friend.DisplayName, more) })
end
SuiteVisits.isSeated = AdminService.isSeated
require(script.Parent.Seating).suiteData = SuiteVisits.dataFor
Shop.pushed = SuiteVisits.hostChanged
boot("Friends", Friends.start)
boot("Suite visits", SuiteVisits.start)
Archivist.onSpeak = function(player)
	local V = require(ReplicatedStorage.Shared.Voice)
	Dialogue.say(player, V.Archivist.speaker, V.Archivist.kept, nil, nil, 2.5)
	Shop.open(player, "register")
end
Tailor.onSpeak = function(player)
	Dialogue.say(player, require(ReplicatedStorage.Shared.Voice).Tailor.speaker, require(ReplicatedStorage.Shared.Voice).Tailor.time, nil, nil, 2.5)
	Shop.open(player, "boutique")
end
Collection.say = function(player, line)
	Concierge.line(player, line, 4)
end
Collection.notice = function(player, title, line)
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = title, line = line })
end
Collection.announce = function(text)
	Boards.announce(text)
end
Collection.ledger = function(player, source)
	LedgerService.add(player, source)
end
Shop.register = Collection.view
TableService.onRegister = Collection.filed
-- The house remembers: your usual table, and the last thing worth mentioning.
Memory.note = function(text)
	Boards.note(text, false)
end
boot("Memory", Memory.start)
local Social = require(script.Parent.Social)
Social.season = function()
	return Season.current().id
end
boot("Social", Social.start)
-- Friends invited to the house (Roblox's friend referrals): both thanked once, in Gilt.
local Referral = require(script.Parent.Referral)
Referral.notice = function(player, title, line)
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = title, line = line })
end
boot("Friend invitations", Referral.start)
Concierge.usualRoom = Memory.usualRoom
TableService.onRound = function(player, roomId, grade, tableId)
	Collection.round(player, roomId, grade)
	Memory.round(player, tableId)
	if grade == "Flawless" then
		local room = require(ReplicatedStorage.Shared.Rooms).get(roomId)
		Memory.highlight(player, "a Flawless round in " .. (if room then room.name else "the house"))
	end
end
TableService.onFiling = function(player, correct)
	if correct then
		LedgerService.add(player, "filing")
	end
end

local Rivals = require(script.Parent.Rivals)
Rivals.send = function(player, info)
	Remotes.event("Guest"):FireClient(player, { op = "rival", rival = info })
end
local function rivalsAfter(player: Player?)
	if player then
		Rivals.publish(player, true)
		Rivals.refresh(player)
	end
end
TableService.onNightlyFinished = function(player, percentile)
	rivalsAfter(player)
	-- Notifications: the rival hears if they've been passed; a first Nightly is the moment to ask.
	task.spawn(function()
		local data = require(script.Parent.Profiles).get(player)
		if not data then
			return
		end
		local info = Rivals.info(player)
		Notify.rivalPassed(player, data.rival.userId, info ~= nil and info.ahead)
		if not data.flags.notifyAsked then
			data.flags.notifyAsked = true
			Remotes.event("Shop"):FireClient(player, { op = "askNotify" })
			Analytics.custom(player, "Notification opt-in asked", nil, nil)
		end
	end)
	CircleService.add(player, "nightly", percentile)
	LedgerService.add(player, "nightly")
	Collection.nightly(player)
end
DuelService.onFinished = function(a, b, winner, ranked, standIn)
	local winnerPlayer = if winner == "a" then a elseif winner == "b" then b else nil
	if winnerPlayer and not standIn then
		Memory.highlight(winnerPlayer, "you won at a table in the Library")
	end
	-- Circles count ranked wins only (a friendly between two members can't be farmed).
	if ranked and not standIn then
		local won = if winner == "a" then a elseif winner == "b" then b else nil
		if won then
			CircleService.add(won, "library")
		end
	end
	if not standIn then
		if a then
			SoireeService.record(a, "library", { won = winner == "a" })
		end
		if b then
			SoireeService.record(b, "library", { won = winner == "b" })
		end
	end
	rivalsAfter(a)
	rivalsAfter(b)
	if a then
		LedgerService.add(a, "library", if winner == "a" then 1 else 0)
		Collection.library(a, winner == "a")
	end
	if b then
		LedgerService.add(b, "library", if winner == "b" then 1 else 0)
		Collection.library(b, winner == "b")
	end
	local _ = standIn
end
boot("Rivals", Rivals.start)

Guests.joinLibrary = DuelService.joinFriend
Guests.onSettingChanged = function(player, key)
	if key == "showMark" or key == "showCrest" then
		Dressing.nameplate(player)
	elseif key == "velocitySpeed" or key == "velocityAura" then
		Purchases.Velocity.apply(player)
	end
end
local guestsUnlock = TableService.onUnlock
TableService.onUnlock = function(player, room)
	guestsUnlock(player, room)
	if room == "midnight" then
		Collection.badge(player, "midnight")
	end
end
require(script.Parent.Profiles).Loaded:Connect(function(player)
	Collection.arrived(player)
end)

-- Last: saved profiles (everything listening for them is connected by now).
local Profiles = require(script.Parent.Profiles)
boot("Profiles", Profiles.start)

Workspace:SetAttribute("MaisonBoot", "open")
if #failed == 0 then
	print(string.format("[Maison] The house is open (%.1f s).", os.clock() - bootStarted))
else
	warn("[Maison] The house is open, but these parts didn't start: " .. table.concat(failed, ", "))
end

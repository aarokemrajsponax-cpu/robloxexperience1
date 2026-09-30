--!strict
-- Maison Noir: server boot. Order matters: config, world, lighting, staff, then guests.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
Remotes.event("Guest") -- creates every remote before any client asks for one

local LiveConfig = require(script.Parent.LiveConfig)
LiveConfig.start(3)

local Build = require(script.Parent.World.Build)
local maison = Build.run()

local Season = require(script.Parent.Season)
Season.dress = require(script.Parent.World.SeasonDress).apply
Season.start()

local Dialogue = require(script.Parent.Dialogue)
Dialogue.start()

-- A Private Evening (a private server): records off, the host arranges the Ballroom.
require(script.Parent.Private).publish()

-- Notifications (Open Cloud; the key lives in the experience's secrets).
local Notify = require(script.Parent.Notify)
Notify.start()

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
Analytics.start()

local Boards = require(script.Parent.Boards)
local Memory = require(script.Parent.Memory)
Boards.start()

local LedgerService = require(script.Parent.LedgerService)
local Collection = require(script.Parent.Collection)
local SoireeService = require(script.Parent.SoireeService)
SoireeService.notice = function(player, title, line)
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = title, line = line })
end
SoireeService.board = Boards.setSoiree
SoireeService.start()

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
TableService.start()

local DuelService = require(script.Parent.DuelService)
DuelService.say = function(player, line)
	Concierge.line(player, line, 3)
end
local BallroomService = require(script.Parent.BallroomService)
DuelService.start(function(player)
	return TableService.isSeated(player) or BallroomService.isSeated(player)
end)
BallroomService.say = function(player, line)
	Concierge.line(player, line, 4)
end
BallroomService.start(function(player)
	return TableService.isSeated(player) or DuelService.isSeated(player)
end)
TableService.isBusy = function(player)
	return DuelService.isSeated(player) or BallroomService.isSeated(player)
end
Concierge.isSeated = function(player)
	return TableService.isSeated(player) or DuelService.isSeated(player) or BallroomService.isSeated(player)
end
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
Dressing.start()
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
AdminService.start()
CircleService.changed = function(player)
	Dressing.nameplate(player)
	Shop.push(player)
end
CircleService.start()
Shop.handOver = function(player, from, itemName)
	Concierge.line(player, string.format("A gift for you, from %s: %s.", from, itemName), 4)
end
Shop.start()
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
Memory.start()
local Social = require(script.Parent.Social)
Social.season = function()
	return Season.current().id
end
Social.start()
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
Rivals.start()

local Guests = require(script.Parent.Guests)
Guests.joinLibrary = DuelService.joinFriend
Guests.onSettingChanged = function(player, key)
	if key == "showMark" then
		Dressing.nameplate(player)
	end
end
Guests.start()
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

local Profiles = require(script.Parent.Profiles)
Profiles.start()

Workspace:SetAttribute("MaisonReady", true)

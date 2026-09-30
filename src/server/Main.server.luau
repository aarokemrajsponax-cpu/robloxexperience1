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
Season.start()

local Dialogue = require(script.Parent.Dialogue)
Dialogue.start()

local staffFolder = Instance.new("Folder")
staffFolder.Name = "Staff"
staffFolder.Parent = maison
local Concierge = require(script.Parent.Staff.Concierge)
local Doorman = require(script.Parent.Staff.Doorman)
local Tailor = require(script.Parent.Staff.Tailor)
task.spawn(Concierge.spawn, staffFolder)
task.spawn(Doorman.spawn, staffFolder)
task.spawn(Tailor.spawn, staffFolder)

local Analytics = require(script.Parent.Analytics)
Analytics.start()

local Boards = require(script.Parent.Boards)
Boards.start()

local LedgerService = require(script.Parent.LedgerService)

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
	LedgerService.add(player, "ballroom", place)
	local data = require(script.Parent.Profiles).get(player)
	if not data or not counted then
		return
	end
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
Dressing.start()
local Shop = require(script.Parent.Shop)
Shop.handOver = function(player, from, itemName)
	Concierge.line(player, string.format("A gift for you, from %s: %s.", from, itemName), 4)
end
Shop.start()
Tailor.onSpeak = function(player)
	Dialogue.say(player, require(ReplicatedStorage.Shared.Voice).Tailor.speaker, require(ReplicatedStorage.Shared.Voice).Tailor.time, nil, nil, 2.5)
	Shop.open(player, "boutique")
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
TableService.onNightlyFinished = function(player)
	rivalsAfter(player)
	LedgerService.add(player, "nightly")
end
DuelService.onFinished = function(a, b, winner, _ranked, standIn)
	rivalsAfter(a)
	rivalsAfter(b)
	if a then
		LedgerService.add(a, "library", if winner == "a" then 1 else 0)
	end
	if b then
		LedgerService.add(b, "library", if winner == "b" then 1 else 0)
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

local Profiles = require(script.Parent.Profiles)
Profiles.start()

Workspace:SetAttribute("MaisonReady", true)

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
task.spawn(Concierge.spawn, staffFolder)
task.spawn(Doorman.spawn, staffFolder)

local Analytics = require(script.Parent.Analytics)
Analytics.start()

local Boards = require(script.Parent.Boards)
Boards.start()

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
TableService.start()

local Guests = require(script.Parent.Guests)
Guests.start()

local Profiles = require(script.Parent.Profiles)
Profiles.start()

Workspace:SetAttribute("MaisonReady", true)

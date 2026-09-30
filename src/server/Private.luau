--!strict
-- A Private Evening (§12): a private server bought by a guest as their own house for friends.
-- Nothing played there counts for records: no boards, no ranked Library, no counted Ballroom
-- evenings, no Soirée, and the Nightly plays as a rehearsal. The host (the server's owner)
-- sets the Ballroom's pace and whether Stand-ins fill the empty chairs. Workspace attributes
-- tell every guest's screen: PrivateEvening, PrivatePace, PrivateStandIns.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Private = {}

export type Pace = "gentle" | "house" | "brisk"
export type StandIns = "fill" | "none"

local settings = { pace = "house" :: Pace, standIns = "fill" :: StandIns }

local function studioTest(): boolean
	return Config.data.Private.inStudio == true and RunService:IsStudio()
end

-- Is this server a Private Evening? A reserved match server has no owner, so it isn't one.
function Private.evening(): boolean
	if studioTest() then
		return true
	end
	local ok, yes = pcall(function()
		local id, owner = game.PrivateServerId, game.PrivateServerOwnerId
		return type(id) == "string" and id ~= "" and type(owner) == "number" and owner ~= 0
	end)
	return ok and yes == true
end

-- May records be written here?
function Private.records(): boolean
	return not Private.evening()
end

function Private.isHost(player: Player): boolean
	if not Private.evening() then
		return false
	end
	-- In a Studio test every guest plays the host.
	if studioTest() then
		return true
	end
	local ok, owner = pcall(function()
		return game.PrivateServerOwnerId
	end)
	return ok and owner == player.UserId
end

-- × the seconds between Ballroom arrivals.
function Private.paceScale(): number
	if not Private.evening() then
		return 1
	end
	return (Config.data.Private.paces :: any)[settings.pace] or 1
end

-- Do Stand-ins fill the empty chairs tonight?
function Private.standIns(): boolean
	return not Private.evening() or settings.standIns == "fill"
end

function Private.set(player: Player, key: string, value: string): boolean
	if not Private.isHost(player) then
		return false
	end
	if key == "pace" and (Config.data.Private.paces :: any)[value] ~= nil then
		settings.pace = value :: Pace
	elseif key == "standIns" and (value == "fill" or value == "none") then
		settings.standIns = value :: StandIns
	else
		return false
	end
	Private.publish()
	return true
end

function Private.get(): { pace: Pace, standIns: StandIns }
	return { pace = settings.pace, standIns = settings.standIns }
end

function Private.publish()
	local Workspace = game:GetService("Workspace")
	local on = Private.evening()
	Workspace:SetAttribute("PrivateEvening", on)
	Workspace:SetAttribute("PrivatePace", if on then settings.pace else nil)
	Workspace:SetAttribute("PrivateStandIns", if on then settings.standIns else nil)
end

return Private

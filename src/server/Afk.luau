--!strict
-- AFK mode on the server. A guest idle for a long while (their screen counts it: client AfkMode)
-- asks to be rejoined, every eighteen minutes, so Roblox's twenty-minute idle kick never comes:
-- they're teleported back into this same server (or, if it's full, any server of the house), with
-- the note that they were AFK so their screen goes straight back to the AFK card. Their brainrots
-- keep earning at the full in-game rate meanwhile (server/Brainrots); only out of the game is it
-- the smaller AFK share.
--
-- All a screen can ask is to be rejoined itself: never anyone else, never another place, and at
-- most once every few minutes. Nothing is ever given for it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Curios = require(script.Parent.Curios)
local Profiles = require(script.Parent.Profiles)

local Afk = {}

local GAP = 5 * 60 -- seconds: a guest is rejoined at most this often
local last: { [Player]: number } = {}

-- Whether rejoining can happen here (never in Studio, where there's nothing to teleport to).
Afk.canTeleport = function(): boolean
	return not RunService:IsStudio() and game.PlaceId ~= 0
end

-- The teleport itself (replaced in tests). Back to this server first; any server if that fails.
Afk.teleport = function(player: Player): (boolean, string?)
	local data = { afk = true, from = game.JobId }
	local ok, err = pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = game.JobId
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if ok then
		return true, nil
	end
	local ok2, err2 = pcall(function()
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData(data)
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	return ok2, if ok2 then nil else tostring(err2 or err)
end

function Afk.rejoin(player: Player): { [string]: any }
	local cfg = (Config.data :: any).Afk or {}
	if cfg.rejoin == false then
		return { ok = false, why = "Rejoining is off." }
	end
	if not Afk.canTeleport() then
		return { ok = false, why = "Rejoining only works in a live server." }
	end
	local now = os.clock()
	if last[player] and now - last[player] < GAP then
		return { ok = false, why = "Rejoined a moment ago." }
	end
	last[player] = now
	local ok, why = Afk.teleport(player)
	return { ok = ok, why = why }
end

function Afk.start()
	Curios.ops.afkRejoin = function(player: Player, _data: Profiles.Data, _r: { [string]: any }): { [string]: any }
		return Afk.rejoin(player)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		last[player] = nil
	end)
end

return Afk

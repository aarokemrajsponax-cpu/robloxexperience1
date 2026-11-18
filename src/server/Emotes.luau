--!strict
-- (Build 96) Money moves: the Boutique's emotes (Wardrobe gestures with an `fx`). A guest's
-- screen asks to play "the one I wear" and says nothing else: the server checks they own it and
-- wear it, holds them to one every few seconds, and tells every screen near them which effect to
-- draw round them (client World/EmoteFX). The animation itself is one of Roblox's own emotes,
-- played by the guest's own screen (it shows to everyone, as every avatar's animations do).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Emotes = {}

Emotes.GAP = 6 -- seconds between one guest's money moves
Emotes.RANGE = 160 -- studs: who's near enough to see it
Emotes.now = function(): number
	return os.clock()
end

local last: { [Player]: number } = {}

-- The money move a guest wears and owns, or nil.
function Emotes.worn(data: Profiles.Data): Wardrobe.Item?
	local id = (data.equipped :: any).gesture
	local item = if type(id) == "string" then Wardrobe.get(id) else nil
	if not item or item.kind ~= "gesture" or type(item.style.fx) ~= "string" or data.owned[item.id] ~= true then
		return nil
	end
	return item
end

-- Plays it (true), or says why not (false).
function Emotes.play(player: Player): boolean
	local data = Profiles.get(player)
	local item = data and Emotes.worn(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not item or not root or not root:IsA("BasePart") then
		return false
	end
	local t = Emotes.now()
	if last[player] and t - last[player] < Emotes.GAP then
		return false
	end
	last[player] = t
	local message = { op = "emote", userId = player.UserId, id = item.id }
	local remote = Remotes.event("Emote")
	for _, other in Players:GetPlayers() do
		local c = other.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if other == player or (r and r:IsA("BasePart") and (r.Position - root.Position).Magnitude <= Emotes.RANGE) then
			remote:FireClient(other, message)
		end
	end
	return true
end

function Emotes.start()
	RemoteGuard.event(Remotes.event("Emote"), "emote", function(player: Player, message: unknown)
		if type(message) ~= "table" or (message :: any).op ~= "play" then
			RemoteGuard.reject(player, "emote", "malformed")
			return
		end
		Emotes.play(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		last[p] = nil
	end)
end

return Emotes

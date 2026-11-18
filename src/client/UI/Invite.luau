--!strict
-- Invitations through Roblox's own invite prompt. A friend who follows one lands where the
-- invite points: tonight's table, or the chair opposite you in the Library.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Toast = require(script.Parent.Toast)

local Invite = {}

local function prompt(launch: string, message: string): boolean
	local ok = pcall(function()
		local options = Instance.new("ExperienceInviteOptions")
		options.LaunchData = launch
		options.PromptMessage = message
		SocialService:PromptGameInvite(Players.LocalPlayer, options)
	end)
	if not ok then
		Toast.show("Invite", "Invites aren't available here.", 3)
	end
	return ok
end

-- "Invite to the Library": a friendly Tête-à-Tête, never ranked.
function Invite.library()
	if prompt("library:" .. tostring(Players.LocalPlayer.UserId), "A friendly Tête-à-Tête in the Library. Same pieces, first to three.") then
		-- Your chair is kept for them for two minutes (no queue, no Stand-in).
		Remotes.event("Table"):FireServer({ op = "inviting" })
	end
end

-- "Invite a friend" (the quick dock): to the house. A friend who comes for the first time is
-- welcomed with a little Gilt, and you're thanked too if you're here when they arrive (Roblox's
-- friend referrals: server/Referral).
function Invite.house()
	-- (Build 95: the house as it is now, its games first; it read "sorting tables, a Ballroom".)
	prompt("house", "Come and become the richest guest with me: Steal a Luxe, the Basement obby, the Executive's fight and the Grand Ballroom.")
end

-- "Invite a friend" after a Grand Prix: to the house, to race on the street out front.
function Invite.race()
	prompt("grandPrix", "Race me in the Maison Grand Prix: ultra-luxury cars, three laps, the winner takes the purse.")
end

-- "Come and play": a friend lands at the Grand Ballroom's doors (server Guests: the old Gallery
-- isn't built since Build 94), where Lights Out is played on the dance floor.
function Invite.ballroom()
	prompt("ballroom", "Lights Out in the Grand Ballroom: come and play the next game on the dance floor with me.")
end

return Invite

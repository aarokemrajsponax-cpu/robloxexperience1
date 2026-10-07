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
	prompt("house", "Come to the Maison: a luxury house of sorting tables, a Ballroom, and your own Suite.")
end

-- "Come and watch": a friend lands in the Ballroom's Gallery (§9.8).
function Invite.ballroom()
	prompt("ballroom", "Lights Out in the Ballroom. Come and watch from the Gallery, or take a chair.")
end

return Invite

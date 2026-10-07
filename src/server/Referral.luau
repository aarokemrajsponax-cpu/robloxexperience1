--!strict
-- Friends invited to the house, through Roblox's own friend referrals. A guest invites a friend
-- (the quick dock's Invite key opens Roblox's invite prompt on their screen); when that friend
-- arrives for the first time through the invitation, Roblox says who invited them
-- (Player:GetJoinData().ReferredByPlayerId) and the house thanks both, once:
--   the friend: Config.Referral.welcomeGilt Gilt, on their first visit only, ever;
--   the guest who invited them, if they're in the house just then (this server or another):
--   thankGilt Gilt, at most dailyThanks times a day and lifetimeThanks ever, once per friend,
--   and only for a friend whose Roblox account is at least minAccountAgeDays old (so accounts
--   made to farm it earn nothing).
-- Everything is decided here, from what Roblox says; nothing a screen sends is trusted. (In the
-- Creator Hub, Engagement > Referral Rewards publishes the banner that says so: see LAUNCH.md.)

local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Analytics = require(script.Parent.Analytics)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)

local Referral = {}

local TOPIC = "MaisonReferral"
local FRIENDS_KEPT = 200

-- Set by Main: a toast on the guest's screen. (Their Gilt is shown again through Gilt.changed.)
Referral.notice = function(_player: Player, _title: string, _line: string) end
Referral.giltChanged = function(player: Player)
	Gilt.changed(player)
end

-- Roblox's cross-server messages. (Replaced in tests.)
Referral.publish = function(message: { [string]: any })
	MessagingService:PublishAsync(TOPIC, message)
end
Referral.subscribe = function(handler: (message: any) -> ())
	MessagingService:SubscribeAsync(TOPIC, handler)
end
Referral.joinData = function(player: Player): any
	return player:GetJoinData()
end
Referral.clock = os.time

local function day(): number
	return math.floor(Referral.clock() / 86400)
end

-- Thanks the guest who invited `friendId`, if they're in this server. True if paid.
function Referral.thank(inviter: Player, friendId: number, friendName: string): boolean
	local data = Profiles.get(inviter)
	if not data then
		return false
	end
	local cfg = Config.data.Referral
	local r = data.referral
	if table.find(r.friends, friendId) then
		return false -- once per friend
	end
	if r.day ~= day() then
		r.day = day()
		r.today = 0
	end
	if r.today >= cfg.dailyThanks or r.total >= cfg.lifetimeThanks then
		return false
	end
	r.today += 1
	r.total += 1
	table.insert(r.friends, friendId)
	while #r.friends > FRIENDS_KEPT do
		table.remove(r.friends, 1)
	end
	data.gilt += cfg.thankGilt
	Analytics.source(inviter, "Gilt", cfg.thankGilt, data.gilt, "Referral")
	Referral.notice(inviter, "A friend arrived", string.format("%s came because you invited them. +%s Gilt, with the house's thanks.", friendName, Gilt.format(cfg.thankGilt)))
	Referral.giltChanged(inviter)
	return true
end

-- A guest's profile is open: were they invited, and is this their first visit?
function Referral.arrived(player: Player, data: Profiles.Data)
	local ok, join = pcall(Referral.joinData, player)
	local by = if ok and type(join) == "table" then join.ReferredByPlayerId else nil
	if type(by) ~= "number" or by <= 0 or by ~= math.floor(by) or by == player.UserId then
		return
	end
	local r = data.referral
	if r.by ~= 0 then
		return -- a guest is welcomed as someone's friend only once
	end
	-- Their first visit (whether or not the visit has been counted yet).
	local fresh = data.visits == 0 or (data.visits == 1 and Referral.clock() - data.firstVisit < 600)
	if not fresh then
		return
	end
	local cfg = Config.data.Referral
	r.by = by
	data.gilt += cfg.welcomeGilt
	Analytics.source(player, "Gilt", cfg.welcomeGilt, data.gilt, "Referral")
	Referral.notice(player, "Welcome to the Maison", string.format("A friend invited you: +%s Gilt to begin.", Gilt.format(cfg.welcomeGilt)))
	Referral.giltChanged(player)
	-- The inviter's thanks: only for a Roblox account old enough.
	if player.AccountAge < cfg.minAccountAgeDays then
		return
	end
	local inviter = Players:GetPlayerByUserId(by)
	if inviter then
		Referral.thank(inviter, player.UserId, player.DisplayName)
	else
		pcall(Referral.publish, { inviter = by, friend = player.UserId, name = string.sub(player.DisplayName, 1, 40) })
	end
end

-- Another server says a friend of one of our guests arrived there.
function Referral.heard(message: any)
	local d = if type(message) == "table" then message.Data else nil
	if type(d) ~= "table" or type(d.inviter) ~= "number" or type(d.friend) ~= "number" or type(d.name) ~= "string" then
		return
	end
	local inviter = Players:GetPlayerByUserId(d.inviter)
	if inviter then
		Referral.thank(inviter, d.friend, string.sub(d.name, 1, 40))
	end
end

function Referral.start()
	Profiles.Loaded:Connect(Referral.arrived)
	for _, player in Players:GetPlayers() do
		local data = Profiles.get(player)
		if data then
			Referral.arrived(player, data)
		end
	end
	task.spawn(function()
		local ok, err = pcall(function()
			Referral.subscribe(Referral.heard)
		end)
		if not ok then
			warn("[Maison] Friend invitations: thanks across servers aren't available: " .. tostring(err))
		end
	end)
end

return Referral

--!strict
-- A new guest's welcome: for their first minutes of play (Config.Newcomer), every Gilt they earn
-- counts double, so the first rounds feel generous and the first things in the Shop are close.
-- Only a guest whose first visit is this one gets it (never one from before it began); the time
-- runs only while they're in the house, and their screen shows what's left (the attribute
-- "WelcomeBonusLeft", in seconds: UI/PerkChips).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Profiles = require(script.Parent.Profiles)

local Newcomer = {}

local function cfg(): { minutes: number, gilt: number }
	return (Config.data :: any).Newcomer
end

local function page(data: Profiles.Data): { left: number }
	local d = data :: any
	if type(d.welcomeBonus) ~= "table" or type(d.welcomeBonus.left) ~= "number" or d.welcomeBonus.left ~= d.welcomeBonus.left then
		d.welcomeBonus = { left = -1 }
	end
	return d.welcomeBonus
end

-- Sets up a guest's welcome as their page loads: a first visit starts it; anyone else keeps
-- whatever they had left (none, for a guest from before it began).
function Newcomer.arrive(player: Player, data: Profiles.Data)
	local w = page(data)
	if w.left < 0 then
		local fresh = data.visits <= 1 and (data.firstVisit == 0 or os.time() - data.firstVisit < 300)
		w.left = if fresh then cfg().minutes * 60 else 0
	end
	player:SetAttribute("WelcomeBonusLeft", if w.left > 0 then math.floor(w.left) else nil)
end

-- What a guest's Gilt counts for now (Gilt.welcome).
function Newcomer.mult(player: Player): number
	local data = Profiles.get(player)
	if not data then
		return 1
	end
	return if page(data).left > 0 then math.max(1, cfg().gilt) else 1
end

-- `seconds` of play gone by for everyone here.
function Newcomer.tick(seconds: number)
	for _, player in Players:GetPlayers() do
		local data = Profiles.get(player)
		if data then
			local w = page(data)
			if w.left > 0 then
				w.left = math.max(0, w.left - seconds)
				player:SetAttribute("WelcomeBonusLeft", if w.left > 0 then math.floor(w.left) else nil)
			end
		end
	end
end

function Newcomer.start()
	Profiles.Loaded:Connect(function(player: Player, data: Profiles.Data)
		Newcomer.arrive(player, data)
	end)
	for _, player in Players:GetPlayers() do
		local data = Profiles.get(player)
		if data then
			Newcomer.arrive(player, data)
		end
	end
	task.spawn(function()
		while true do
			local dt = task.wait(5)
			Newcomer.tick(dt)
		end
	end)
end

return Newcomer

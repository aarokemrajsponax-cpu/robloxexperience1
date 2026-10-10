--!strict
-- Who in this server is friends with whom, on Roblox (asked by the server, once a pair, never told
-- by a guest's screen). Two things use it: friends may visit each other's Suites (SuiteVisits), and
-- the Friend Booster: friends in the house together both earn more Gilt, more again for each
-- further friend (Config.Friends: +25% with one, +10% for each more, up to +55%), and more XP.
-- Each guest carries the number of their friends here as the attribute "FriendsHere", and their
-- own screen is told who they are (the Friend Booster card shows them); nobody else is told.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Friends = {}

-- The question put to Roblox (replaced in tests).
Friends.ask = function(a: Player, b: Player): boolean
	local ok, yes = pcall(function()
		return a:IsFriendsWithAsync(b.UserId)
	end)
	if not ok then
		-- (The older name of the same question.)
		ok, yes = pcall(function()
			return (a :: any):IsFriendsWith(b.UserId)
		end)
	end
	return ok and yes == true
end

-- Called when a guest's friends in the house change (set by Main: a word on their screen).
Friends.arrived = function(_player: Player, _friend: Player) end

local known: { [string]: boolean } = {}

local function key(a: number, b: number): string
	if a > b then
		a, b = b, a
	end
	return tostring(a) .. ":" .. tostring(b)
end

local function cfg()
	return Config.data.Friends
end

-- Whether two guests are friends on Roblox. (In Studio, test players are counted as friends so
-- visits and the boost can be tried with Test → Clients and Servers; never in the live game.)
function Friends.are(a: Player, b: Player): boolean
	if a == b then
		return false
	end
	local k = key(a.UserId, b.UserId)
	local cached = known[k]
	if cached ~= nil then
		return cached
	end
	local yes = if RunService:IsStudio() and cfg().studioFriends then true else Friends.ask(a, b)
	known[k] = yes
	return yes
end

-- This guest's friends in this server.
function Friends.inServer(player: Player): { Player }
	local out = {}
	for _, other in Players:GetPlayers() do
		if other ~= player and other.Parent == Players and Friends.are(player, other) then
			table.insert(out, other)
		end
	end
	return out
end

-- The Gilt boost for `n` friends in the house: +25% with one, +10% for each more, never past
-- the cap (Config.Friends).
function Friends.boostFor(n: number): number
	local c = cfg()
	if n <= 0 then
		return 1
	end
	return math.min(c.maxBoost, c.giltBoost + c.perFriend * (n - 1))
end

-- The Gilt boost for this guest (the server's own count of their friends here).
function Friends.giltBoost(player: Player): number
	local n = player:GetAttribute("FriendsHere")
	return Friends.boostFor(if type(n) == "number" then n else 0)
end

-- The XP boost for this guest: Config.Friends.xpBoost while a friend is in the house.
function Friends.xpBoost(player: Player): number
	local n = player:GetAttribute("FriendsHere")
	return if type(n) == "number" and n > 0 then cfg().xpBoost else 1
end

-- What each guest's screen was last told, so it's told again only when it changes.
local told: { [Player]: string } = {}

-- Tells a guest's own screen who of their friends is here and what the boost is.
local function tell(player: Player, friends: { Player })
	local list = {}
	local ids = {}
	for _, f in friends do
		table.insert(list, { userId = f.UserId, name = Names.of(f), owner = Names.isOwner(f) })
		table.insert(ids, tostring(f.UserId))
	end
	local key = table.concat(ids, ",")
	if told[player] == key then
		return
	end
	told[player] = key
	pcall(function()
		Remotes.event("Guest"):FireClient(player, {
			op = "friends",
			friends = list,
			gilt = Friends.boostFor(#friends),
			xp = if #friends > 0 then cfg().xpBoost else 1,
			perFriend = cfg().perFriend,
			first = cfg().giltBoost,
			max = cfg().maxBoost,
		})
	end)
end

local function refresh()
	for _, p in Players:GetPlayers() do
		local before = p:GetAttribute("FriendsHere")
		local friends = Friends.inServer(p)
		local n = #friends
		p:SetAttribute("FriendsHere", if n > 0 then n else nil)
		if n > (if type(before) == "number" then before else 0) then
			Friends.arrived(p, friends[#friends])
		end
		tell(p, friends)
	end
end
Friends.refresh = refresh

function Friends.start()
	Players.PlayerAdded:Connect(function()
		task.spawn(refresh)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		told[player] = nil
		-- Asked afresh next time (friendships change).
		for k in known do
			local a, b = string.match(k, "^(%-?%d+):(%-?%d+)$")
			if tonumber(a) == player.UserId or tonumber(b) == player.UserId then
				known[k] = nil
			end
		end
		task.delay(0.5, refresh)
	end)
	task.spawn(refresh)
end

return Friends

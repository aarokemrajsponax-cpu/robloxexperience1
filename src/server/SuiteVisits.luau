--!strict
-- Visiting a friend's Suite. Every guest's Suite is their own, private place; friends on Roblox
-- may also go into each other's, from the Suites key on the left of the screen. The server checks
-- the friendship itself (Friends), remembers whose Suite each guest is in (the attribute
-- "SuiteHost": a user id, or none for their own), sends the visitor that Suite as its owner has
-- furnished it, and brings them to its door. Guests in the same Suite see each other there; anyone
-- in any other Suite stays unseen (World/SuiteView). Out of the Suite, a visitor is home again:
-- walking in later takes them to their own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Friends = require(script.Parent.Friends)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local SuiteVisits = {}

-- A guest has just walked into a friend's Suite (set by Main: the Badge Book).
SuiteVisits.visited = function(_player: Player, _host: Player) end
-- Whether a guest may walk into a host's Suite now, as the host has chosen (set by Main:
-- server/Showcase: friends, only invited friends, or nobody).
SuiteVisits.mayVisit = function(_host: Player, _visitor: Player): (boolean, string?)
	return true, nil
end

-- Set by Main: whether a guest is seated at a table (they get up first).
SuiteVisits.isSeated = function(_player: Player): boolean
	return false
end

-- (Build 102) Set by Main: the elevator (server/Wings), the only way into a Suite now: a ride to
-- the guest's own Suite, or to a friend's. Returns whether it began, and why not.
SuiteVisits.ride = function(_player: Player, _to: string, _host: Player?): (boolean, string?)
	return false, "Not just now."
end
-- Set by Main: whose Suite the elevator has let this guest into (server/Wings), or nil.
SuiteVisits.wingHost = function(_player: Player): Player?
	return nil
end

local began: { [Player]: number } = {}


-- The friend whose Suite this guest is in, or nil (their own).
function SuiteVisits.hostOf(player: Player): Player?
	local id = player:GetAttribute("SuiteHost")
	if type(id) ~= "number" or id == player.UserId then
		return nil
	end
	local host = Players:GetPlayerByUserId(id)
	if host and host.Parent == Players and Friends.are(player, host) and (SuiteVisits.mayVisit(host, player)) then
		return host
	end
	return nil
end

-- The profile of the Suite this guest stands in: their host's when visiting, else their own
-- (Seating works out a Suite seat from it).
function SuiteVisits.dataFor(player: Player): Profiles.Data?
	return Profiles.get(SuiteVisits.hostOf(player) or player)
end

-- Tells a guest's screen whose Suite they're in, and how it's furnished.
local function tell(player: Player, host: Player?)
	local data = if host then Profiles.get(host) else nil
	Remotes.event("Shop"):FireClient(player, {
		op = "suiteHost",
		host = if host then host.UserId else nil,
		name = if host then Names.of(host) else nil,
		suite = if data then data.suite else nil,
		goldKey = if data then data.goldKey == true else nil,
	})
end

local function setHost(player: Player, host: Player?)
	player:SetAttribute("SuiteHost", if host then host.UserId else nil)
	if host then
		began[player] = os.clock()
	else
		began[player] = nil
	end
	tell(player, host)
end

-- (Build 102) The elevator has let this guest into a friend's Suite (or taken them home).
function SuiteVisits.setHost(player: Player, host: Player?)
	if host == nil and player:GetAttribute("SuiteHost") == nil then
		return
	end
	setHost(player, host)
end

-- Goes home: the guest's own Suite again.
function SuiteVisits.home(player: Player)
	if player:GetAttribute("SuiteHost") ~= nil then
		setHost(player, nil)
	end
end

-- The host changed their Suite: their visitors see it change too.
function SuiteVisits.hostChanged(host: Player)
	for _, p in Players:GetPlayers() do
		if p:GetAttribute("SuiteHost") == host.UserId then
			tell(p, host)
		end
	end
end

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 2, 0)
	if not r then
		RemoteGuard.reject(player, "suiteAsk", "malformed")
		return { ok = false }
	end
	if r.op == "list" then
		local friends = {}
		for _, f in Friends.inServer(player) do
			table.insert(friends, { userId = f.UserId, name = Names.of(f) })
		end
		local host = SuiteVisits.hostOf(player)
		return { ok = true, friends = friends, visiting = if host then host.UserId else nil }
	end
	if SuiteVisits.isSeated(player) then
		return { ok = false, why = "Get up from the table first." }
	end
	if r.op == "home" then
		local ok, why = SuiteVisits.ride(player, "suite", nil)
		return { ok = ok, why = why }
	elseif r.op == "visit" then
		local id = RemoteGuard.number(r.userId, -1e15, 1e15, true)
		local host = if id then Players:GetPlayerByUserId(id) else nil
		if not host or host.Parent ~= Players then
			return { ok = false, why = "That guest has left the house." }
		end
		if host == player then
			local ok, why = SuiteVisits.ride(player, "suite", nil)
			return { ok = ok, why = why }
		end
		if not Friends.are(player, host) then
			return { ok = false, why = "Only friends on Roblox may visit each other's Suites." }
		end
		local may, why = SuiteVisits.mayVisit(host, player)
		if not may then
			return { ok = false, why = why or "Their Suite isn't open just now." }
		end
		-- (Build 102) Up in the elevator, 6.5 seconds; the server lets them in at the door.
		local ok, whyNot = SuiteVisits.ride(player, "friend", host)
		return { ok = ok, why = whyNot }
	end
	return { ok = false }
end

-- Visitors who have left the Suite (or whose host has gone) are home again.
local function sweep()
	for _, p in Players:GetPlayers() do
		local id = p:GetAttribute("SuiteHost")
		if id ~= nil then
			-- (Build 102: the elevator lets visitors in and out; a visitor it no longer counts as
			-- one, or whose host has closed their Suite or gone, is home again.)
			local host = SuiteVisits.hostOf(p)
			if not host or SuiteVisits.wingHost(p) ~= host then
				setHost(p, nil)
			end
		end
	end
end
SuiteVisits.sweep = sweep

function SuiteVisits.start()
	RemoteGuard.invoke(Remotes.func("SuiteAsk"), "suiteAsk", onAsk)
	Players.PlayerRemoving:Connect(function(player: Player)
		began[player] = nil
		task.defer(sweep)
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(sweep)
		end
	end)
end

-- For tests.
SuiteVisits.handle = onAsk

return SuiteVisits

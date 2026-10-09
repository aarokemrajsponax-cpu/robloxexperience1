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

local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Friends = require(script.Parent.Friends)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local SuiteVisits = {}

-- A guest has just walked into a friend's Suite (set by Main: the Badge Book).
SuiteVisits.visited = function(_player: Player, _host: Player) end

-- Set by Main: whether a guest is seated at a table (they get up first).
SuiteVisits.isSeated = function(_player: Player): boolean
	return false
end

local GRACE = 3 -- seconds after a visit begins before leaving the Suite counts (the move in)
local began: { [Player]: number } = {}

local function notice(player: Player, title: string, line: string)
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = title, line = line })
end

local function inSuite(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "suite"
end

-- The friend whose Suite this guest is in, or nil (their own).
function SuiteVisits.hostOf(player: Player): Player?
	local id = player:GetAttribute("SuiteHost")
	if type(id) ~= "number" or id == player.UserId then
		return nil
	end
	local host = Players:GetPlayerByUserId(id)
	if host and host.Parent == Players and Friends.are(player, host) then
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
		name = if host then host.DisplayName else nil,
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

local function moveIn(player: Player)
	local character = player.Character
	if character then
		local at = Layout.Suite.arrival + Vector3.new(0, 3, 0)
		character:PivotTo(CFrame.new(at))
	end
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
			table.insert(friends, { userId = f.UserId, name = f.DisplayName })
		end
		local host = SuiteVisits.hostOf(player)
		return { ok = true, friends = friends, visiting = if host then host.UserId else nil }
	end
	if SuiteVisits.isSeated(player) then
		return { ok = false, why = "Get up from the table first." }
	end
	if r.op == "home" then
		setHost(player, nil)
		moveIn(player)
		return { ok = true }
	elseif r.op == "visit" then
		local id = RemoteGuard.number(r.userId, -1e15, 1e15, true)
		local host = if id then Players:GetPlayerByUserId(id) else nil
		if not host or host.Parent ~= Players then
			return { ok = false, why = "That guest has left the house." }
		end
		if host == player then
			setHost(player, nil)
			moveIn(player)
			return { ok = true }
		end
		if not Friends.are(player, host) then
			return { ok = false, why = "Only friends on Roblox may visit each other's Suites." }
		end
		setHost(player, host)
		moveIn(player)
		notice(host, "A visitor", player.DisplayName .. " is visiting your Suite.")
		SuiteVisits.visited(player, host)
		return { ok = true }
	end
	return { ok = false }
end

-- Visitors who have left the Suite (or whose host has gone) are home again.
local function sweep()
	for _, p in Players:GetPlayers() do
		local id = p:GetAttribute("SuiteHost")
		if id ~= nil then
			local host = SuiteVisits.hostOf(p)
			if not host then
				setHost(p, nil)
				if inSuite(p) then
					notice(p, "Your Suite", "Your friend has gone, so this is your own Suite again.")
				end
			elseif not inSuite(p) and os.clock() - (began[p] or 0) > GRACE then
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

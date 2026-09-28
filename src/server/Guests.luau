--!strict
-- Guests arriving and leaving: where they spawn, what the client is told, settings,
-- Nights attended, zone tracking (the Concierge's greeting), and Straight to the table.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Nightly = require(ReplicatedStorage.Shared.Nightly)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Settings = require(ReplicatedStorage.Shared.Settings)

local Analytics = require(script.Parent.Analytics)
local LiveConfig = require(script.Parent.LiveConfig)
local Profiles = require(script.Parent.Profiles)
local TableService = require(script.Parent.TableService)
local Concierge = require(script.Parent.Staff.Concierge)

local Guests = {}

type Visit = {
	firstVisit: boolean,
	spawnedOnce: boolean,
	greeted: boolean,
	zone: string,
	settingTimes: { number },
	funnel: { [number]: boolean },
	launch: string?,
}

local visits: { [Player]: Visit } = {}
local guestEvent = Remotes.event("Guest")

local function setupCollisionGroups()
	pcall(function()
		PhysicsService:RegisterCollisionGroup("Guests")
		PhysicsService:RegisterCollisionGroup("Staff")
	end)
	PhysicsService:CollisionGroupSetCollidable("Guests", "Guests", false)
	PhysicsService:CollisionGroupSetCollidable("Guests", "Staff", false)
end

local function payload(player: Player, data: Profiles.Data, visit: Visit): { [string]: any }
	local registered = 0
	for _ in data.register do
		registered += 1
	end
	return {
		op = "welcome",
		firstVisit = visit.firstVisit,
		displayName = player.DisplayName,
		settings = data.settings,
		overrides = LiveConfig.overrides,
		nights = data.nights.count,
		gilt = data.gilt,
		best = data.best,
		registered = registered,
		saved = not Profiles.isMock(),
		unlocked = { midnight = data.flags.midnight == true },
		nightly = { played = data.nightly.day == Nightly.at().day, score = data.nightly.score, grade = data.nightly.grade },
		launch = visit.launch,
	}
end

local function place(player: Player, character: Model, visit: Visit)
	-- First-ever visit, first spawn: the Street. Everyone else arrives in the Foyer.
	local toStreet = visit.firstVisit and not visit.spawnedOnce
	visit.spawnedOnce = true
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Guests"
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Guests"
		end
	end)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid.WalkSpeed = Config.data.Movement.walkSpeed
		humanoid.JumpPower = 35
		humanoid.Died:Connect(function()
			task.delay(3, function()
				if player.Parent == Players then
					player:LoadCharacterAsync()
				end
			end)
		end)
	end
	local target = if toStreet then Layout.Street.spawn else Layout.Foyer.spawn
	character:PivotTo(target + Vector3.new(0, 1, 0))
	player:SetAttribute("Arrived", if toStreet then "street" else "foyer")
end

local function welcome(player: Player, data: Profiles.Data)
	local visit: Visit = {
		firstVisit = data.visits == 0,
		spawnedOnce = false,
		greeted = false,
		zone = "none",
		settingTimes = {},
		funnel = {},
		launch = nil,
	}
	-- Invites carry launch data so a friend lands where you are (§13).
	local okJoin, join = pcall(function()
		return player:GetJoinData()
	end)
	if okJoin and join and type(join.LaunchData) == "string" and #join.LaunchData <= 40 then
		visit.launch = join.LaunchData
	end
	visits[player] = visit
	if data.visits == 0 then
		data.firstVisit = os.time()
	end
	data.visits += 1
	-- Nights attended: every UTC day with a visit counts. It never resets.
	local today = math.floor(os.time() / 86400)
	if data.nights.lastDay ~= today then
		data.nights.lastDay = today
		data.nights.count += 1
	end
	player:SetAttribute("FirstVisit", visit.firstVisit)
	-- Shift means run in the house, so Shift Lock stays off.
	player.DevEnableMouseLock = false
	player.CharacterAdded:Connect(function(character)
		place(player, character, visit)
	end)
	guestEvent:FireClient(player, payload(player, data, visit))
	player:LoadCharacterAsync()
end

local function trackZones()
	while true do
		for player, visit in visits do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			-- Nothing happens to a guest still looking at the title.
			if root and root:IsA("BasePart") and visit.funnel[3] then
				local zone = Layout.zoneAt(root.Position)
				if zone ~= visit.zone then
					visit.zone = zone
					if zone == "foyer" then
						Analytics.step(player, 4)
						if not visit.greeted then
							visit.greeted = true
							local data = Profiles.get(player)
							local pending = data ~= nil and data.nightly.day ~= Nightly.at().day
							Concierge.greet(player, visit.firstVisit, pending)
						end
					end
				end
			end
		end
		task.wait(0.4)
	end
end

local function onSetting(player: Player, key: unknown, value: unknown)
	if type(key) ~= "string" then
		return
	end
	local visit = visits[player]
	if not visit then
		return
	end
	local now = os.clock()
	table.insert(visit.settingTimes, now)
	while #visit.settingTimes > 0 and now - visit.settingTimes[1] > 1 do
		table.remove(visit.settingTimes, 1)
	end
	if #visit.settingTimes > 20 then
		return
	end
	if not Settings.validate(key, value) then
		return
	end
	local data = Profiles.get(player)
	if data then
		data.settings[key] = value
		Analytics.custom(player, "Setting changed", nil, { key = key, value = tostring(value) })
	end
end

local function onFunnel(player: Player, step: unknown)
	if type(step) ~= "number" or not Analytics.ClientSteps[step] then
		return
	end
	local visit = visits[player]
	if not visit or visit.funnel[step] then
		return
	end
	visit.funnel[step] = true
	Analytics.step(player, step)
end

function Guests.start()
	Players.CharacterAutoLoads = false
	setupCollisionGroups()
	-- The Baseplate template's own floor and spawn would sit in the street; hide them while playing.
	for _, name in { "Baseplate", "SpawnLocation" } do
		local item = Workspace:FindFirstChild(name)
		if item and item:IsA("BasePart") then
			item:Destroy()
		end
	end
	Profiles.Loaded:Connect(welcome)
	Remotes.event("Setting").OnServerEvent:Connect(onSetting)
	Remotes.event("Funnel").OnServerEvent:Connect(onFunnel)
	Remotes.func("QuickSit").OnServerInvoke = function(player: Player, wanted: unknown)
		if TableService.isSeated(player) then
			return true
		end
		local mode: TableService.Mode = if wanted == "nightly" then "nightly" else "room"
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local near = if root and root:IsA("BasePart") then root.Position else nil
		local model = TableService.freeTable(if mode == "nightly" then "any" else "salon", near)
		if not model then
			return false
		end
		local ok = TableService.seat(player, model, true, mode)
		return ok
	end
	TableService.onUnlock = function(player: Player, room: string)
		guestEvent:FireClient(player, { op = "unlock", room = room })
	end
	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil
	end)
	task.spawn(trackZones)
end

return Guests

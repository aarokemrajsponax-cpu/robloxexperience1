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
local Speed = require(ReplicatedStorage.Shared.Speed)

local Analytics = require(script.Parent.Analytics)
local LiveConfig = require(script.Parent.LiveConfig)
local Memory = require(script.Parent.Memory)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local TableService = require(script.Parent.TableService)
local Concierge = require(script.Parent.Staff.Concierge)
local Voice = require(ReplicatedStorage.Shared.Voice)

local Guests = {}

-- Called after a guest changes a setting (set by Main: the nameplate redraws for showMark).
Guests.onSettingChanged = function(_player: Player, _key: string) end

-- Seats a friend opposite the guest who invited them to the Library (set by Main).
Guests.joinLibrary = function(_player: Player, _inviterId: number): boolean
	return false
end

type Visit = {
	firstVisit: boolean,
	spawnedOnce: boolean,
	greeted: boolean,
	zone: string,
	settingTimes: { number },
	funnel: { [number]: boolean },
	launch: string?,
	foyerSince: number?,
	offered: boolean,
	clubShown: boolean,
}

local visits: { [Player]: Visit } = {}
local guestEvent = Remotes.event("Guest")

local function setupCollisionGroups()
	-- Guests pass through each other and through the staff (never through the house).
	for _, name in { "Guests", "Staff" } do
		pcall(function()
			if not PhysicsService:IsCollisionGroupRegistered(name) then
				PhysicsService:RegisterCollisionGroup(name)
			end
		end)
	end
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("Guests", "Guests", false)
		PhysicsService:CollisionGroupSetCollidable("Guests", "Staff", false)
	end)
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

-- Gives a guest their character, once (defined below).
local spawnCharacter: (player: Player, respawn: boolean?) -> ()

local function place(player: Player, character: Model, visit: Visit)
	-- Everyone arrives in the lit Foyer (or, with Movement.firstArrival = "street", a first-ever
	-- visit starts outside the doors).
	local toStreet = Config.data.Movement.firstArrival == "street" and visit.firstVisit and not visit.spawnedOnce
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
		humanoid.WalkSpeed = Speed.resolve(false, Workspace:GetAttribute("SpeedBoost"), player:GetAttribute("SpeedPerk"), player:GetAttribute("AdminSpeed"))
		humanoid.JumpPower = 35
		humanoid.Died:Connect(function()
			task.delay(3, function()
				if player.Parent == Players and player.Character == character then
					spawnCharacter(player, true)
				end
			end)
		end)
	end
	local target = if toStreet then Layout.Street.spawn else Layout.Foyer.spawn
	character:PivotTo(target + Vector3.new(0, 1, 0))
	player:SetAttribute("Arrived", if toStreet then "street" else "foyer")
	-- Drawn a little smaller than Roblox's default, so the house is roomier around everyone
	-- (once their look has loaded, so hats and hair scale with them).
	local scale = Config.data.Movement.guestScale
	if scale ~= 1 then
		task.spawn(function()
			local waited = 0
			while waited < 6 do
				local ok, loaded = pcall(function()
					return player:HasAppearanceLoaded()
				end)
				if not ok or loaded then
					break
				end
				task.wait(0.1)
				waited += 0.1
			end
			if player.Character == character then
				pcall(function()
					character:ScaleTo(scale)
				end)
			end
		end)
	end
end

-- Every guest gets a visit record (and a character) the moment they arrive, whether or not
-- their saved profile has loaded yet; the profile fills in the details when it does.
local function provisional(player: Player): Visit
	local visit = visits[player]
	if visit then
		return visit
	end
	local v: Visit = {
		firstVisit = false,
		spawnedOnce = false,
		greeted = false,
		zone = "none",
		settingTimes = {},
		funnel = {},
		launch = nil,
		foyerSince = nil,
		offered = false,
		clubShown = false,
	}
	visits[player] = v
	return v
end

-- The saved profile and the fallback timer may both ask; the character comes once.
local loading: { [Player]: boolean } = {}
spawnCharacter = function(player: Player, respawn: boolean?)
	if loading[player] or player.Parent ~= Players or (player.Character ~= nil and not respawn) then
		return
	end
	loading[player] = true
	local ok, err = pcall(function()
		player:LoadCharacterAsync()
	end)
	loading[player] = nil
	if not ok then
		warn("[Maison] Couldn't give " .. player.Name .. " a character:", err)
	end
end

local function arrive(player: Player)
	local visit = provisional(player)
	-- Invites carry launch data so a friend lands where you are (§13).
	local okJoin, join = pcall(function()
		return player:GetJoinData()
	end)
	if okJoin and join and type(join.LaunchData) == "string" and #join.LaunchData <= 40 then
		visit.launch = join.LaunchData
	end
	player.CharacterAdded:Connect(function(character)
		place(player, character, provisional(player))
	end)
	-- A character Roblox spawned before the house was ready (in Studio, at the Baseplate
	-- template's spawn, which sits inside the Foyer): put it where it belongs, now.
	local existing = player.Character
	if existing then
		task.spawn(place, player, existing, visit)
	end
	-- Shift means run in the house, so Shift Lock stays off.
	player.DevEnableMouseLock = false
	-- If the profile is slow (another server still holds it, or the data store is busy), the
	-- guest still gets a character to walk around in.
	task.delay(1, spawnCharacter, player)
end

local function welcome(player: Player, data: Profiles.Data)
	local visit = provisional(player)
	visit.firstVisit = data.visits == 0
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
	guestEvent:FireClient(player, payload(player, data, visit))
	spawnCharacter(player)
end

local function trackZones()
	while true do
		for player, visit in visits do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			-- Nothing happens to a guest still looking at the title.
			if root and root:IsA("BasePart") and visit.funnel[3] then
				local zone = Layout.zoneAt(root.Position)
				-- A new guest lingering in the Foyer for a while is offered the walk.
				if zone == "foyer" and visit.firstVisit and not visit.offered and not TableService.isSeated(player) then
					visit.foyerSince = visit.foyerSince or os.clock()
					if os.clock() - (visit.foyerSince :: number) > Config.data.Staff.lostAfter and not Concierge.isLeading(player) and not Concierge.isTouring(player) then
						visit.offered = true
						Concierge.offerHelp(player)
					end
				elseif zone ~= "foyer" then
					visit.foyerSince = nil
				end
				-- The first climb to the Club Floor gets its own three steps.
				if zone == "club" and not visit.clubShown then
					visit.clubShown = true
					local data = Profiles.get(player)
					if data and not data.flags.clubHowTo then
						data.flags.clubHowTo = true
						guestEvent:FireClient(player, { op = "clubHowTo" })
					end
				end
				if zone ~= visit.zone then
					visit.zone = zone
					if zone == "foyer" then
						Analytics.step(player, 4)
						if not visit.greeted then
							visit.greeted = true
							local data = Profiles.get(player)
							local pending = data ~= nil and data.nightly.day ~= Nightly.at().day
							Concierge.greet(player, visit.firstVisit, pending, if visit.firstVisit then nil else Memory.greeting(player))
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
		Guests.onSettingChanged(player, key)
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
	for _, player in Players:GetPlayers() do
		task.spawn(arrive, player)
	end
	Players.PlayerAdded:Connect(arrive)
	Profiles.Loaded:Connect(welcome)
	RemoteGuard.event(Remotes.event("Setting"), "setting", onSetting)
	RemoteGuard.event(Remotes.event("Funnel"), "funnel", onFunnel)
	RemoteGuard.invoke(Remotes.func("QuickSit"), "quickSit", function(player: Player, wanted: unknown): any
		if TableService.isSeated(player) then
			return true
		end
		-- An invite to watch Lights Out: straight up to the Ballroom's Gallery.
		if wanted == "ballroom" then
			local character = player.Character
			if character then
				local B = Layout.Ballroom
				character:PivotTo(CFrame.lookAt(B.galleryArrival + Vector3.new(0, 3, 0), Vector3.new(B.centre.X, B.galleryArrival.Y + 3, B.centre.Z)))
			end
			return true
		end
		-- An invite to the Library: the Concierge shows the friend straight upstairs.
		if type(wanted) == "string" and string.sub(wanted, 1, 7) == "library" then
			local character = player.Character
			if character then
				character:PivotTo(CFrame.new(Layout.Library.arrival + Vector3.new(0, 2, 0)))
			end
			local inviter = tonumber(string.match(wanted, "^library:(%d+)$"))
			if inviter and Guests.joinLibrary(player, inviter) then
				return true
			end
			-- (Plain "library" is a Soirée weekend's notification: just shown upstairs.)
			if inviter then
				Concierge.line(player, Voice.Concierge.friendAway, 4)
			end
			return true
		end
		local mode: TableService.Mode = if wanted == "nightly" then "nightly" else "room"
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local near = if root and root:IsA("BasePart") then root.Position else nil
		local model = if mode == "nightly" then TableService.nightlyTable(near) else TableService.freeTable("salon", near)
		if not model then
			return false
		end
		local ok = TableService.seat(player, model, true, mode)
		return ok
	end, function(_player: Player): any
		return false
	end)
	TableService.onUnlock = function(player: Player, room: string)
		guestEvent:FireClient(player, { op = "unlock", room = room })
	end
	Players.PlayerRemoving:Connect(function(player)
		visits[player] = nil
	end)
	task.spawn(trackZones)
end

return Guests

--!strict
-- Guests arriving and leaving: where they spawn, what the client is told, settings,
-- Nights attended, zone tracking (the Concierge's greeting), and Straight to the table.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Names = require(ReplicatedStorage.Shared.Names)
local Build = require(ReplicatedStorage.Shared.Build)
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
local Integrity = require(script.Parent.Integrity)

local Guests = {}

-- Called after a guest changes a setting (set by Main: the nameplate redraws for showMark).
Guests.onSettingChanged = function(_player: Player, _key: string) end
-- (Build 94) Told when a night at the house has just been counted (set by Main: the badges are
-- checked then, so the welcome badge comes on the very first visit, whichever arrival step runs first).
Guests.nightCounted = function(_player: Player) end

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
	known: boolean?, -- (Build 101) the saved profile has said whether this is a first visit
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

-- Which of the house's games a guest has been into (the objective card suggests the next one to
-- try): the first-time note each one leaves (server/Attractions), or, for a guest from before it,
-- what their record already shows of it.
function Guests.tried(data: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local flags = if type(data.flags) == "table" then data.flags else {}
	local pages = if type(data.attractions) == "table" then data.attractions else {}
	local function num(v: any): number
		return if type(v) == "number" then v else 0
	end
	for _, id in { "luxe", "basement", "executive", "gala", "island" } do
		local p = pages[id]
		local before = type(p) == "table" and (num(p.hauls) > 0 or num(p.caught) > 0 or num(p.deepest) > 0 or num(p.clears) > 0 or num(p.wins) > 0 or num(p.flights) > 0 or num(p.minutes) > 0 or num(p.gilt) > 0)
		out[id] = flags["guide_" .. id] == true or before == true
	end
	return out
end

-- Whether a guest is still new to the house: no tour from the Concierge yet, fewer than two rounds
-- at the tables and no attraction played. Until then the gold arrow leads them to the Concierge,
-- and the Concierge offers the tour before anything else.
function Guests.needsGuide(data: Profiles.Data): boolean
	-- (Read with care: a page missing a part never stops the welcome going out.)
	local d = data :: any
	local flags = if type(d.flags) == "table" then d.flags else {}
	local stats = if type(d.stats) == "table" then d.stats else {}
	local rounds = if type(stats.rounds) == "number" then stats.rounds else 0
	-- (Build 87: and once a guest has been through the first evening's welcome, or been shown the
	-- way once on a later one, they're never sent to it again: flags.onboarded, saved.)
	if flags.toured == true or flags.onboarded == true or rounds >= 2 then
		return false
	end
	-- (Nor is a guest who has played an attraction: the house is no longer only its tables.)
	for _, played in Guests.tried(d) do
		if played then
			return false
		end
	end
	return true
end

-- (Build 87) Whether the Concierge starts the tour himself for this guest when they come into the
-- Foyer: only a guest whose very first evening began on Build 87 or later (flags.newcomer, set
-- then) and who hasn't had it yet (flags.onboarded, set the moment it starts: a guest who leaves
-- halfway, skips it or ends it is never sent round again; the tour is always at the Concierge).
-- A guest who left before reaching the Foyer still has it next time.
function Guests.autoTourDue(data: Profiles.Data): boolean
	local flags = (data :: any).flags
	return type(flags) == "table" and flags.newcomer == true and flags.onboarded ~= true and Guests.needsGuide(data)
end

-- (Called as the tour starts by itself: never again, on any server.)
function Guests.markOnboarded(data: Profiles.Data)
	local flags = (data :: any).flags
	if type(flags) == "table" then
		flags.onboarded = true
	end
end

local function payload(player: Player, data: Profiles.Data, visit: Visit): { [string]: any }
	local registered = 0
	for _ in data.register do
		registered += 1
	end
	local guide = Guests.needsGuide(data)
	local auto = Guests.autoTourDue(data)
	if guide and not auto and type(data.flags) == "table" then
		-- (A guest from before Build 87 who never had the tour: shown the way this evening, once;
		-- after that they come in like anyone else. The tour is always at the Concierge.)
		data.flags.onboarded = true
	end
	return {
		op = "welcome",
		firstVisit = visit.firstVisit,
		guide = guide,
		autoTour = auto,
		displayName = Names.of(player),
		settings = data.settings,
		overrides = LiveConfig.overrides,
		nights = data.nights.count,
		gilt = data.gilt,
		best = data.best,
		registered = registered,
		saved = not Profiles.isMock(),
		unlocked = { midnight = data.flags.midnight == true },
		tried = Guests.tried(data),
		nightly = { played = data.nightly.day == Nightly.at().day, score = data.nightly.score, grade = data.nightly.grade },
		launch = visit.launch,
		-- (A returning guest who hasn't seen this build's news yet: Welcome back shows it, once.)
		news = not visit.firstVisit and (tonumber((data :: any).seenBuild) or 0) < Build.number,
	}
end

-- Gives a guest their character, once (defined below).
local spawnCharacter: (player: Player, respawn: boolean?) -> ()

-- (Build 101) Where a returning guest arrives: inside their Suite, facing into the drawing room.
local function suiteSpawn(): CFrame
	local at = Layout.Suite.arrival
	return CFrame.lookAt(at, at + Vector3.new(-10, 0, 0)) + Vector3.new(0, 2, 0)
end

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
		humanoid.WalkSpeed = Speed.resolve(false, Workspace:GetAttribute("SpeedBoost"), Speed.perkOf(player), player:GetAttribute("AdminSpeed"), player:GetAttribute("SpeedTrained"), player:GetAttribute("Attraction"))
		humanoid.JumpPower = 35
		humanoid.Died:Connect(function()
			task.delay(3, function()
				if player.Parent == Players and player.Character == character then
					spawnCharacter(player, true)
				end
			end)
		end)
	end
	-- (Build 101) New guests arrive by the Concierge (his tour is for them); a guest who has been
	-- before arrives in their own Suite, with no tour. Unknown yet (a slow profile): the Foyer,
	-- and welcome() moves a returning guest up once it knows.
	local toSuite = not toStreet and visit.known == true and not visit.firstVisit
	local target = if toStreet then Layout.Street.spawn elseif toSuite then suiteSpawn() else Layout.Foyer.spawn
	Integrity.teleport(player, character, target + Vector3.new(0, 1, 0))
	player:SetAttribute("Arrived", if toStreet then "street" elseif toSuite then "suite" else "foyer")
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
	visit.known = true
	if data.visits == 0 then
		data.firstVisit = os.time()
		-- (Build 87: a brand-new guest, whom the Concierge will show round by himself.)
		if type(data.flags) == "table" then
			data.flags.newcomer = true
		end
	end
	data.visits += 1
	-- Nights attended: every UTC day with a visit counts. It never resets.
	local today = math.floor(os.time() / 86400)
	if data.nights.lastDay ~= today then
		data.nights.lastDay = today
		data.nights.count += 1
		task.defer(function()
			pcall(Guests.nightCounted, player)
		end)
	end
	-- (Build 93) The funnel's last step: a new guest back on a later day than their first.
	if not visit.firstVisit and (tonumber(data.firstVisit) or 0) > 0 and today > math.floor(data.firstVisit / 86400) then
		Analytics.step(player, 10)
	end
	player:SetAttribute("FirstVisit", visit.firstVisit)
	guestEvent:FireClient(player, payload(player, data, visit))
	;(data :: any).seenBuild = Build.number
	-- (Build 101) A returning guest whose character came before their profile (it stood in the
	-- Foyer meanwhile) is taken up to their Suite now.
	local early = player.Character
	if not visit.firstVisit and early and player:GetAttribute("Arrived") == "foyer" and not TableService.isSeated(player) then
		Integrity.teleport(player, early, suiteSpawn() + Vector3.new(0, 1, 0))
		player:SetAttribute("Arrived", "suite")
	end
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
		-- An invite to Lights Out (or a Soirée's notification): straight up to it. With the old
		-- Ballroom room built (its tests), its Gallery; otherwise (Build 94 on: that room isn't built,
		-- and its Gallery is empty air) the Grand Ballroom's doors in the Club hall, where the house's
		-- own "Take me there" leads.
		if wanted == "ballroom" then
			local character = player.Character
			if character then
				if (Config.data.Ballroom :: any).room ~= false then
					local B = Layout.Ballroom
					Integrity.teleport(player, character, CFrame.lookAt(B.galleryArrival + Vector3.new(0, 3, 0), Vector3.new(B.centre.X, B.galleryArrival.Y + 3, B.centre.Z)))
				else
					local doors = require(script.Parent.Travel).places().ballroom
					if doors then
						Integrity.teleport(player, character, doors.at + Vector3.new(0, 1, 0))
					end
				end
			end
			return true
		end
		-- An invite to the Library: the Concierge shows the friend straight upstairs.
		if type(wanted) == "string" and string.sub(wanted, 1, 7) == "library" then
			local character = player.Character
			if character then
				Integrity.teleport(player, character, CFrame.new(Layout.Library.arrival + Vector3.new(0, 2, 0)))
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

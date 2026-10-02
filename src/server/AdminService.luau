--!strict
-- House controls: the owner's panel for keeping the house lively (the "admin abuse" evenings
-- other Roblox games are known for, in the house's own manner). Only the experience's owner (or
-- the group's owner, or a user id in Config.Admin.userIds) may use it; every request is checked
-- here, never on the guest's screen.
--
-- What it can do: events that boost Gilt, the Ledger and Mythic luck (never a score), giants,
-- a quickstep, featherlight gravity, gold coins scattered through the house, a treasure hunt of
-- golden keys, any Salute for free, dressing the house in another season for a while, crowning
-- or spotlighting a guest, gifts of Gilt, announcements (typed ones are filtered by Roblox), a
-- summons that lets guests in every other house join this one, and removing a guest.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HouseEvents = require(ReplicatedStorage.Shared.HouseEvents)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Salutes = require(ReplicatedStorage.Shared.Salutes)
local Seasons = require(ReplicatedStorage.Shared.Seasons)
local Analytics = require(script.Parent.Analytics)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)

local AdminService = {}

local TOPIC = "MaisonAdmin"
local DEFAULT_GRAVITY = 196.2

local function cfg()
	return Config.data.Admin
end

-- Hooks (set by Main).
AdminService.isSeated = function(_player: Player): boolean
	return false
end
AdminService.salute = function(_player: Player?, _id: string, _byName: string?) end
AdminService.season = function(_id: string, _seconds: number): boolean
	return false
end
AdminService.note = function(_text: string, _everywhere: boolean) end

---------------------------------------------------------------------------------------------------
-- Who may use it
---------------------------------------------------------------------------------------------------
local ownerCache: { [Player]: boolean } = {}

function AdminService.isAdmin(player: Player): boolean
	local cached = ownerCache[player]
	if cached ~= nil then
		return cached
	end
	local yes = false
	if table.find(cfg().userIds, player.UserId) then
		yes = true
	elseif RunService:IsStudio() and cfg().studioEveryone then
		yes = true
	else
		local ok, result = pcall(function()
			if game.CreatorType == Enum.CreatorType.User then
				return game.CreatorId == player.UserId
			end
			return player:GetRankInGroupAsync(game.CreatorId) >= 255
		end)
		yes = ok and result == true
	end
	ownerCache[player] = yes
	return yes
end

---------------------------------------------------------------------------------------------------
-- Timed events
---------------------------------------------------------------------------------------------------
local active: { [string]: number } = {} -- id -> ends at (os.time)

function AdminService.active(id: string): boolean
	local ends = active[id]
	return ends ~= nil and ends > os.time()
end

function AdminService.giltBoost(): number
	return if AdminService.active("goldenHour") then cfg().goldenHourGilt else 1
end
function AdminService.ledgerBoost(): number
	return if AdminService.active("pageTurner") then cfg().pageTurnerLedger else 1
end
function AdminService.mythicLuck(): number
	return if AdminService.active("luckyHour") then cfg().luckyHourMythic else 1
end

local function scale(character: Model, factor: number)
	pcall(function()
		character:ScaleTo(factor)
	end)
end

local function applyGiants(on: boolean)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and not AdminService.isSeated(player) then
			local base = Config.data.Movement.guestScale
			scale(character, if on then base * cfg().giantsScale else base)
		end
	end
end

local coinsFolder: Folder? = nil
local function eventsFolder(): Folder
	local f = coinsFolder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "HouseEvents"
	local maison = Workspace:FindFirstChild("Maison")
	nf.Parent = maison or Workspace
	coinsFolder = nf
	return nf
end

-- Places a pickup (a gold coin or a golden key) at a point on a floor.
local function pickup(kind: "coin" | "key", at: Vector3, gilt: number): BasePart
	local p = Instance.new("Part")
	p.Name = if kind == "coin" then "GoldCoin" else "GoldenKey"
	p.Shape = if kind == "coin" then Enum.PartType.Cylinder else Enum.PartType.Block
	p.Size = if kind == "coin" then Vector3.new(0.25, 1.6, 1.6) else Vector3.new(0.5, 0.5, 2)
	p.Color = Color3.fromRGB(236, 196, 98)
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(at + Vector3.new(0, 2, 0)) * (if kind == "coin" then CFrame.Angles(0, 0, math.rad(90)) else CFrame.identity)
	p:SetAttribute("Gilt", gilt)
	p:SetAttribute("Pickup", kind)
	local glow = Instance.new("PointLight")
	glow.Brightness = if kind == "key" then 2 else 0.8
	glow.Range = if kind == "key" then 12 else 6
	glow.Color = Color3.fromRGB(255, 214, 140)
	glow.Parent = p
	p.Parent = eventsFolder()
	return p
end

-- Points on the house's floors a guest can walk to (for coins and keys).
local function walkable(): { Vector3 }
	local F = Layout.FLOOR
	local points = {
		Layout.Street.spawn.Position,
		Vector3.new(-12, F, 8), Vector3.new(12, F, 12), Vector3.new(-20, F, 30), Vector3.new(0, F, 2),
		Layout.Boutique.arrival, Layout.Vault.arrival,
		Layout.Salon.arrival, Layout.Velvet.arrival, Layout.Obsidian.arrival,
		Vector3.new(0, Layout.CLUB, 54), Vector3.new(-12, Layout.CLUB, 50), Vector3.new(16, Layout.CLUB, 58),
		Layout.Library.arrival, Layout.Ballroom.arrival, Layout.Ballroom.galleryArrival,
	}
	if Workspace:GetAttribute("TerraceOpen") == true then
		table.insert(points, Layout.Terrace.arrival)
		table.insert(points, Vector3.new(60, Layout.Terrace.floorY, 44))
	end
	return points
end

local function scatter(kind: "coin" | "key", count: number, gilt: number, around: Vector3?)
	local rng = Random.new()
	local points = walkable()
	-- Keys go to different spots around the house; coins fall around the owner (or anywhere).
	local order = {}
	for i = 1, #points do
		table.insert(order, i)
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for i = 1, count do
		local base: Vector3
		if kind == "key" then
			base = points[order[((i - 1) % #order) + 1]] + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		elseif around then
			base = Vector3.new(around.X + rng:NextNumber(-22, 22), around.Y - 2.5, around.Z + rng:NextNumber(-22, 22))
		else
			base = points[rng:NextInteger(1, #points)] + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
		end
		pickup(kind, base, gilt)
	end
end

local function clearPickups(kind: string)
	for _, p in eventsFolder():GetChildren() do
		if p:GetAttribute("Pickup") == kind then
			p:Destroy()
		end
	end
end

local function broadcast(message: { [string]: any })
	Remotes.event("Salute"):FireAllClients(message)
end

-- Starts an event in this house (and, from the owner's panel, optionally in every house).
function AdminService.startEvent(id: string, seconds: number, byName: string)
	if not HouseEvents.byId[id] then
		return
	end
	local ends = os.time() + seconds
	active[id] = ends
	Workspace:SetAttribute(HouseEvents.attribute(id), ends)
	if id == "giants" then
		applyGiants(true)
	elseif id == "quickstep" then
		Workspace:SetAttribute("SpeedBoost", cfg().quickstepSpeed)
	elseif id == "featherlight" then
		Workspace.Gravity = cfg().featherGravity
	elseif id == "goldRain" then
		clearPickups("coin")
		local owner = nil
		for _, p in Players:GetPlayers() do
			if p.DisplayName == byName then
				owner = p
			end
		end
		local root = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
		scatter("coin", cfg().coins, cfg().coinGilt, if root and root:IsA("BasePart") then root.Position else nil)
	elseif id == "treasure" then
		clearPickups("key")
		scatter("key", cfg().keys, cfg().keyGilt, nil)
	end
	local e = HouseEvents.byId[id]
	broadcast({ op = "salute", id = id, by = byName, effects = { "goldLeaf" }, seconds = 8, title = e.name, line = e.name .. ": " .. e.line })
	AdminService.note(e.name .. " has begun: " .. e.line, false)
	task.delay(seconds, function()
		if active[id] == ends then
			AdminService.stopEvent(id)
		end
	end)
end

function AdminService.stopEvent(id: string)
	active[id] = nil
	Workspace:SetAttribute(HouseEvents.attribute(id), nil)
	if id == "giants" then
		applyGiants(false)
	elseif id == "quickstep" then
		Workspace:SetAttribute("SpeedBoost", nil)
	elseif id == "featherlight" then
		Workspace.Gravity = DEFAULT_GRAVITY
	elseif id == "goldRain" then
		clearPickups("coin")
	elseif id == "treasure" then
		clearPickups("key")
	end
end

-- Guests walking over a coin or a key pick it up.
local function collect()
	local folder = coinsFolder
	if not folder or not folder.Parent then
		return
	end
	local items = folder:GetChildren()
	if #items == 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			for _, item in items do
				if item.Parent and item:IsA("BasePart") and (item.CFrame.Position - root.Position).Magnitude < 4.5 then
					local gilt = (item:GetAttribute("Gilt") :: number?) or 0
					local kind = item:GetAttribute("Pickup")
					item:Destroy()
					local data = Profiles.get(player)
					local paid = if data then Gilt.pay(player, data, gilt, if kind == "key" then "Treasure Hunt" else "Gold Rain") else 0
					Remotes.event("Shop"):FireClient(player, { op = "notice", title = if kind == "key" then "A golden key" else "Gold", line = string.format("+%d Gilt", paid) })
					if kind == "key" then
						broadcast({ op = "salute", id = "key", by = player.DisplayName, effects = {}, seconds = 4, title = "The Treasure Hunt", line = player.DisplayName .. " found a golden key." })
						local left = 0
						for _, other in folder:GetChildren() do
							if other:GetAttribute("Pickup") == "key" then
								left += 1
							end
						end
						if left == 0 and AdminService.active("treasure") then
							AdminService.stopEvent("treasure")
							broadcast({ op = "salute", id = "keysFound", by = "", effects = { "fireworks" }, seconds = 10, title = "The Treasure Hunt", line = "Every golden key has been found." })
						end
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Guests
---------------------------------------------------------------------------------------------------
local function crown(target: Player)
	local character = target.Character
	local head = character and character:FindFirstChild("Head")
	if not character or not head or not head:IsA("BasePart") then
		return
	end
	local old = character:FindFirstChild("HouseCrown")
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "HouseCrown"
	local function piece(size: Vector3, offset: CFrame, shape: Enum.PartType?, colour: Color3?)
		local p = Instance.new("Part")
		p.Size = size
		if shape then
			p.Shape = shape
		end
		p.Color = colour or Color3.fromRGB(236, 196, 98)
		p.Material = Enum.Material.Metal
		p.Reflectance = 0.3
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = (head :: BasePart).CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0 = head :: BasePart
		w.Part1 = p
		w.Parent = p
		p.Parent = model
	end
	piece(Vector3.new(0.35, 1.3, 1.3), CFrame.new(0, 0.85, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		piece(Vector3.new(0.18, 0.45, 0.18), CFrame.new(math.cos(a) * 0.55, 1.2, math.sin(a) * 0.55))
	end
	piece(Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 1.05, -0.62), Enum.PartType.Ball, Color3.fromRGB(150, 22, 32))
	model.Parent = character
	target:SetAttribute("GuestOfHonour", true)
end

local function giftGilt(target: Player, amount: number, byName: string)
	local data = Profiles.get(target)
	if not data then
		return
	end
	-- A gift from the house isn't softly capped: it's a present, not earnings.
	data.gilt += amount
	Analytics.source(target, "Gilt", amount, data.gilt, "House gift")
	Gilt.changed(target)
	Remotes.event("Shop"):FireClient(target, { op = "notice", title = "A gift from the house", line = string.format("%s gave you %d Gilt.", byName, amount) })
end

---------------------------------------------------------------------------------------------------
-- Announcements and the summons
---------------------------------------------------------------------------------------------------
local summons: { [string]: number } = {} -- job id -> open until

local function filtered(text: string, from: Player): string?
	local ok, result = pcall(function()
		local r = TextService:FilterStringAsync(text, from.UserId, Enum.TextFilterContext.PublicChat)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(result) == "string" then result else nil
end

local function publish(message: { [string]: any })
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(TOPIC, message)
		end)
	end)
end

local function announce(text: string, byName: string)
	broadcast({ op = "announce", text = text, by = byName })
end

local function onMessage(message: any)
	local m = if type(message) == "table" then message.Data else nil
	if type(m) ~= "table" or m.jobId == game.JobId then
		return
	end
	if m.op == "announce" and type(m.text) == "string" then
		announce(m.text, tostring(m.by))
	elseif m.op == "event" and type(m.id) == "string" and type(m.seconds) == "number" then
		AdminService.startEvent(m.id, math.clamp(m.seconds, 60, 3600), tostring(m.by))
	elseif m.op == "abuse" and type(m.seconds) == "number" then
		AdminService.abuse(math.clamp(m.seconds, 60, 3600), tostring(m.by))
	elseif m.op == "summon" and type(m.jobId) == "string" then
		summons[m.jobId] = os.time() + cfg().summonMinutes * 60
		broadcast({ op = "summon", jobId = m.jobId, by = tostring(m.by), text = tostring(m.text or "") })
	end
end

-- A guest in another house accepted the summons: send them to the owner's house.
local function join(player: Player, jobId: unknown)
	if type(jobId) ~= "string" or (summons[jobId] or 0) < os.time() then
		return
	end
	pcall(function()
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = jobId
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
end

---------------------------------------------------------------------------------------------------
-- Admin Abuse Night, and the schedule
---------------------------------------------------------------------------------------------------
-- Every event at once, a burst of fireworks and a line for the whole house.
function AdminService.abuse(seconds: number, byName: string)
	for _, id in cfg().abuseEvents do
		if HouseEvents.byId[id] then
			AdminService.startEvent(id, seconds, byName)
		end
	end
	broadcast({ op = "salute", id = "abuse", by = byName, effects = { "fireworks", "goldLeaf", "chandelier" }, seconds = 12, title = "Admin Abuse Night", line = "Admin Abuse Night: double Gilt, Mythic luck, gold rain, a treasure hunt, giants. Go!" })
	AdminService.note("Admin Abuse Night has begun in the house.", false)
end

export type Planned = { id: string, at: number, what: string, minutes: number, by: string }

local scheduleStore: DataStore? = nil
pcall(function()
	scheduleStore = DataStoreService:GetDataStore("MaisonSchedule")
end)
local planned: { Planned } = {}
local begun: { [string]: boolean } = {}

local function whatName(what: string): string
	if what == "abuse" then
		return "Admin Abuse Night"
	end
	local e = HouseEvents.byId[what]
	return if e then e.name else what
end

local function readSchedule(): { Planned }
	local store = scheduleStore
	if not store then
		return planned
	end
	local ok, value = pcall(function()
		return store:GetAsync("schedule")
	end)
	if ok and type(value) == "table" then
		local out: { Planned } = {}
		for _, p in value do
			if type(p) == "table" and type(p.id) == "string" and type(p.at) == "number" and type(p.what) == "string" and type(p.minutes) == "number" then
				table.insert(out, { id = p.id, at = p.at, what = p.what, minutes = p.minutes, by = tostring(p.by or "") })
			end
		end
		table.sort(out, function(a, b)
			return a.at < b.at
		end)
		planned = out
	end
	return planned
end

-- Changes the schedule (in the DataStore when there is one, so every server sees it).
local function changeSchedule(change: ({ Planned }) -> { Planned }): boolean
	local store = scheduleStore
	if not store then
		planned = change(planned)
		return true
	end
	local ok = pcall(function()
		store:UpdateAsync("schedule", function(old: any)
			local list: { Planned } = if type(old) == "table" then old else {}
			return change(list)
		end)
	end)
	readSchedule()
	return ok
end

-- Every server looks at the schedule now and then: an event whose time has come starts here (for
-- what's left of it), and the next one coming up is counted down to on every screen.
local function runSchedule()
	local now = os.time()
	local soonest: Planned? = nil
	for _, p in readSchedule() do
		local ends = p.at + p.minutes * 60
		if p.at <= now and now < ends and not begun[p.id] then
			begun[p.id] = true
			local left = ends - now
			if p.what == "abuse" then
				AdminService.abuse(left, p.by)
			elseif HouseEvents.byId[p.what] then
				AdminService.startEvent(p.what, left, p.by)
			end
		elseif p.at > now and (soonest == nil or p.at < (soonest :: Planned).at) then
			soonest = p
		end
	end
	local next_ = soonest
	if next_ and next_.at - now <= cfg().scheduleNotice * 60 then
		Workspace:SetAttribute("NextEventAt", next_.at)
		Workspace:SetAttribute("NextEventName", whatName(next_.what))
	else
		Workspace:SetAttribute("NextEventAt", nil)
		Workspace:SetAttribute("NextEventName", nil)
	end
	-- Past ones are tidied away now and then.
	local stale = false
	for _, p in planned do
		if p.at + p.minutes * 60 < now - 3600 then
			stale = true
		end
	end
	if stale then
		changeSchedule(function(list)
			local keep = {}
			for _, p in list do
				if p.at + p.minutes * 60 >= now - 3600 then
					table.insert(keep, p)
				end
			end
			return keep
		end)
	end
end

local function scheduleView(): { { [string]: any } }
	local out = {}
	for _, p in planned do
		if p.at + p.minutes * 60 > os.time() then
			table.insert(out, { id = p.id, at = p.at, name = whatName(p.what), minutes = p.minutes })
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- The panel's requests
---------------------------------------------------------------------------------------------------
local lastAsk: { [Player]: number } = {}

local function state(): { [string]: any }
	local guests = {}
	for _, p in Players:GetPlayers() do
		table.insert(guests, { userId = p.UserId, name = p.DisplayName, crowned = p:GetAttribute("GuestOfHonour") == true })
	end
	local events = {}
	for _, e in HouseEvents.List do
		table.insert(events, { id = e.id, name = e.name, line = e.line, endsAt = active[e.id] })
	end
	local seasons = {}
	for _, s in Seasons.List do
		table.insert(seasons, { id = s.id, name = s.name })
	end
	local salutes = {}
	for _, s in Salutes.List do
		table.insert(salutes, { id = s.id, name = s.name })
	end
	return {
		ok = true,
		guests = guests,
		events = events,
		seasons = seasons,
		salutes = salutes,
		minutes = cfg().minutes,
		giftGilt = cfg().giftGilt,
		announcements = HouseEvents.Announcements,
		abuseMinutes = cfg().abuseMinutes,
		schedule = scheduleView(),
		now = os.time(),
	}
end

local function handle(player: Player, request: unknown): any
	if not AdminService.isAdmin(player) then
		return { ok = false, why = "House controls are for the owner." }
	end
	if type(request) ~= "table" then
		return nil
	end
	local now = os.clock()
	if lastAsk[player] and now - lastAsk[player] < 0.4 then
		return { ok = false, why = "One moment." }
	end
	lastAsk[player] = now
	local r = request :: { [string]: any }
	local op = r.op
	local byName = player.DisplayName
	Analytics.custom(player, "House controls", nil, { op = tostring(op) })
	if op == "state" then
		return state()
	elseif op == "event" and type(r.id) == "string" and HouseEvents.byId[r.id] then
		local minutes = if type(r.minutes) == "number" then math.clamp(r.minutes, 1, 60) else 15
		AdminService.startEvent(r.id, minutes * 60, byName)
		if r.everywhere == true then
			publish({ op = "event", id = r.id, seconds = minutes * 60, by = byName, jobId = game.JobId })
		end
		return state()
	elseif op == "abuse" then
		local minutes = if type(r.minutes) == "number" then math.clamp(r.minutes, 5, 60) else 30
		AdminService.abuse(minutes * 60, byName)
		if r.everywhere == true then
			publish({ op = "abuse", seconds = minutes * 60, by = byName, jobId = game.JobId })
		end
		return state()
	elseif op == "schedule" then
		local what = if type(r.what) == "string" and (r.what == "abuse" or HouseEvents.byId[r.what]) then r.what else nil
		local at = if type(r.at) == "number" then math.floor(r.at) else nil
		local minutes = if type(r.minutes) == "number" then math.clamp(math.floor(r.minutes), 5, 180) else 30
		if not what or not at or at < os.time() - 60 or at > os.time() + 60 * 86400 then
			return { ok = false, why = "Choose what, and a time in the next two months." }
		end
		local ok = changeSchedule(function(list)
			if #list >= cfg().scheduleMax then
				return list
			end
			table.insert(list, { id = HttpService:GenerateGUID(false), at = at, what = what, minutes = minutes, by = byName })
			return list
		end)
		if not ok then
			return { ok = false, why = "The schedule couldn't be saved just now (in Studio: turn on API access)." }
		end
		task.spawn(runSchedule)
		return state()
	elseif op == "unschedule" and type(r.id) == "string" then
		changeSchedule(function(list)
			local keep = {}
			for _, p in list do
				if p.id ~= r.id then
					table.insert(keep, p)
				end
			end
			return keep
		end)
		task.spawn(runSchedule)
		return state()
	elseif op == "stop" and type(r.id) == "string" and HouseEvents.byId[r.id] then
		AdminService.stopEvent(r.id)
		return state()
	elseif op == "salute" and type(r.id) == "string" and Salutes.byId[r.id] then
		AdminService.salute(nil, r.id, byName)
		return { ok = true }
	elseif op == "season" and type(r.id) == "string" then
		local minutes = if type(r.minutes) == "number" then math.clamp(r.minutes, 1, 60) else 15
		return { ok = AdminService.season(r.id, minutes * 60) }
	elseif op == "crown" or op == "spotlight" or op == "gift" or op == "kick" or op == "bring" then
		local target = if type(r.userId) == "number" then Players:GetPlayerByUserId(r.userId) else nil
		if not target then
			return { ok = false, why = "That guest has left." }
		end
		if op == "crown" then
			crown(target)
			broadcast({ op = "salute", id = "crown", by = byName, userId = target.UserId, effects = { "encore", "goldLeaf" }, seconds = 20, title = "A Guest of Honour", line = target.DisplayName .. " is tonight's Guest of Honour." })
			AdminService.note(target.DisplayName .. " is tonight's Guest of Honour.", false)
		elseif op == "spotlight" then
			broadcast({ op = "salute", id = "spotlight", by = byName, userId = target.UserId, effects = { "encore" }, seconds = 20, title = "The spotlight", line = "The spotlight finds " .. target.DisplayName .. "." })
		elseif op == "gift" then
			local amount = if type(r.amount) == "number" and table.find(cfg().giftGilt, r.amount) then r.amount else nil
			if not amount then
				return { ok = false, why = "Choose an amount." }
			end
			giftGilt(target, amount, byName)
		elseif op == "bring" then
			local mine = player.Character
			local theirs = target.Character
			if mine and theirs and not AdminService.isSeated(target) then
				theirs:PivotTo(mine:GetPivot() * CFrame.new(3, 0, 0))
			end
		elseif op == "kick" then
			if target == player then
				return { ok = false, why = "Not yourself." }
			end
			target:Kick("The house has asked you to leave for tonight.")
		end
		return state()
	elseif op == "giftAll" then
		local amount = if type(r.amount) == "number" and table.find(cfg().giftGilt, r.amount) then r.amount else nil
		if not amount then
			return { ok = false, why = "Choose an amount." }
		end
		for _, p in Players:GetPlayers() do
			giftGilt(p, amount, byName)
		end
		AdminService.note(string.format("The house gave every guest %d Gilt.", amount), false)
		return { ok = true }
	elseif op == "announce" then
		local text: string? = nil
		if type(r.preset) == "number" then
			text = HouseEvents.Announcements[r.preset]
		elseif type(r.text) == "string" and #r.text > 0 and #r.text <= 140 then
			text = filtered(r.text, player)
			if not text then
				return { ok = false, why = "Roblox's filter couldn't check that just now." }
			end
		end
		if not text then
			return { ok = false, why = "Choose or write a line." }
		end
		announce(text, byName)
		if r.everywhere == true then
			publish({ op = "announce", text = text, by = byName, jobId = game.JobId })
		end
		return { ok = true, text = text }
	elseif op == "summon" then
		publish({ op = "summon", jobId = game.JobId, by = byName, text = tostring(r.text or "") })
		announce("Guests from every house have been invited here.", byName)
		return { ok = true }
	end
	return { ok = false, why = "Unknown." }
end

function AdminService.start()
	Gilt.boost = AdminService.giltBoost
	local function mark(player: Player)
		task.spawn(function()
			if AdminService.isAdmin(player) then
				player:SetAttribute("MaisonAdmin", true)
			end
		end)
		-- New arrivals join a Night of Giants in progress.
		player.CharacterAdded:Connect(function(character)
			if AdminService.active("giants") then
				task.wait(1)
				scale(character, Config.data.Movement.guestScale * cfg().giantsScale)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	Players.PlayerAdded:Connect(mark)
	Players.PlayerRemoving:Connect(function(player)
		ownerCache[player] = nil
		lastAsk[player] = nil
	end)
	Remotes.func("AdminAsk").OnServerInvoke = handle
	Remotes.event("Salute").OnServerEvent:Connect(function(player: Player, m: any)
		if type(m) == "table" and m.op == "join" then
			join(player, m.jobId)
		end
	end)
	pcall(function()
		MessagingService:SubscribeAsync(TOPIC, onMessage)
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			collect()
		end
	end)
	task.spawn(function()
		while true do
			pcall(runSchedule)
			task.wait(cfg().scheduleCheck)
		end
	end)
end

-- For tests: the panel's handler and the schedule's tick.
AdminService.handle = handle
AdminService.runSchedule = runSchedule
AdminService.collect = collect

return AdminService

--!strict
-- House controls: the owner's panel for keeping the house lively (the "admin abuse" evenings
-- other Roblox games are known for, in the house's own manner), and the owner's own powers. Only
-- the experience's owner (or, for a group's experience, the group's owner) may use any of it:
-- nobody else, whatever their screen sends. Every request is checked here, never on the guest's
-- screen; the powers the owner's screen carries out (flying) are switched on by the server.
--
-- What it can do: events that boost Gilt, the Ledger and Mythic luck (never a score), giants,
-- a quickstep, featherlight gravity, gold coins scattered through the house, a treasure hunt of
-- golden keys, any Salute for free, dressing the house in another season for a while, crowning
-- or spotlighting a guest, gifts of Gilt, announcements (typed ones are filtered by Roblox), a
-- summons that lets guests in every other house join this one, and removing a guest. The owner's
-- powers: flying, speed, a super jump, any size, invisibility, going anywhere or to any guest,
-- bringing everyone, freezing everyone; a Night of Small Things and the House Party.

local DataStoreService = game:GetService("DataStoreService")
local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
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
local Curios = require(script.Parent.Curios)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Spectacles = require(script.Parent.Purchases.Spectacles)

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
local studioOwner: Player? = nil -- Studio only: the first test player, standing in for the owner

function AdminService.isAdmin(player: Player): boolean
	local cached = ownerCache[player]
	if cached ~= nil then
		return cached
	end
	local yes = false
	if RunService:IsStudio() and cfg().studioFirstPlayer and (studioOwner == nil or studioOwner == player or studioOwner.Parent ~= Players) then
		-- (Testing in Studio: one owner, the first player in. Never in the live game.)
		studioOwner = player
		yes = true
	else
		local ok, result = pcall(function()
			if game.CreatorType == Enum.CreatorType.User then
				return game.CreatorId == player.UserId
			end
			-- The group's owner holds rank 255 in it.
			for _, group in GroupService:GetGroupsAsync(player.UserId) do
				if type(group) == "table" and group.Id == game.CreatorId then
					return (tonumber(group.Rank) or 0) >= 255
				end
			end
			return false
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

-- A guest's size while the house's events say so (giants, small things), else their own.
local function eventScale(): number
	if AdminService.active("tiny") then
		return cfg().tinyScale
	elseif AdminService.active("giants") then
		return cfg().giantsScale
	end
	return 1
end

local function applyGiants(_on: boolean)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and not AdminService.isSeated(player) and player:GetAttribute("AdminSize") == nil then
			scale(character, Config.data.Movement.guestScale * eventScale())
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

-- Places a pickup (a gold coin, a golden key, or a meme curio from the parade) on a floor.
local function pickup(kind: "coin" | "key" | "meme", at: Vector3, gilt: number): BasePart
	local p = Instance.new("Part")
	p.Name = if kind == "coin" then "GoldCoin" elseif kind == "meme" then "ParadeMeme" else "GoldenKey"
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
	if kind == "meme" then
		-- A meme curio bobbing at head height: its glyph on a billboard, the part itself unseen.
		local memes = {}
		for _, c in CurioList.List do
			if c.family == "meme" and c.source == "tables" then
				table.insert(memes, c)
			end
		end
		local c = memes[math.random(1, #memes)]
		p.Transparency = 1
		p.Size = Vector3.new(2, 2, 2)
		p.CFrame = CFrame.new(at + Vector3.new(0, 3.2, 0))
		p:SetAttribute("Curio", c.id)
		glow.Color = Color3.fromRGB(255, 160, 200)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(3.2, 3.2)
		bb.AlwaysOnTop = false
		bb.LightInfluence = 0
		bb.MaxDistance = 90
		bb.Parent = p
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = c.glyph .. c.accent
		t.TextScaled = true
		t.Parent = bb
		pcall(function()
			game:GetService("CollectionService"):AddTag(p, "ParadeMeme")
		end)
	end
	p.Parent = eventsFolder()
	return p
end

-- Points on the house's floors a guest can walk to (for coins and keys).
local function walkable(): { Vector3 }
	-- (Spots in the house as drawn, scaled into the Grand house.)
	local S = Layout.SCALE
	local F = Layout.FLOOR
	local points = {
		Layout.Street.spawn.Position,
		Vector3.new(-12 * S, F, 8 * S), Vector3.new(12 * S, F, 12 * S), Vector3.new(-20 * S, F, 30 * S), Vector3.new(0, F, 2 * S),
		Layout.Boutique.arrival, Layout.Vault.arrival,
		Layout.Salon.arrival, Layout.Velvet.arrival, Layout.Obsidian.arrival,
		Vector3.new(0, Layout.CLUB, 54 * S), Vector3.new(-12 * S, Layout.CLUB, 50 * S), Vector3.new(16 * S, Layout.CLUB, 58 * S),
		Layout.Library.arrival, Layout.Ballroom.arrival, Layout.Ballroom.galleryArrival,
	}
	if Workspace:GetAttribute("TerraceOpen") == true then
		table.insert(points, Layout.Terrace.arrival)
		table.insert(points, Vector3.new(60 * S, Layout.Terrace.floorY, 44 * S))
	end
	return points
end

local function scatter(kind: "coin" | "key" | "meme", count: number, gilt: number, around: Vector3?)
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
		if kind == "key" or kind == "meme" then
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
-- `quiet`: no announcement of its own (Admin Abuse Night announces itself once, for all of them).
function AdminService.startEvent(id: string, seconds: number, byName: string, quiet: boolean?)
	if not HouseEvents.byId[id] then
		return
	end
	local ends = os.time() + seconds
	active[id] = ends
	Workspace:SetAttribute(HouseEvents.attribute(id), ends)
	if id == "giants" or id == "tiny" then
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
	elseif id == "parade" then
		clearPickups("meme")
		scatter("meme", cfg().memes, cfg().memeGilt, nil)
	elseif id == "disco" then
		task.spawn(function()
			-- Everyone in the Ballroom while it's on gets the Disco Ball (once each).
			while active[id] == ends do
				for _, p in Players:GetPlayers() do
					local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "ballroom" then
						Curios.forEvent(p, "discoBall", "disco:" .. tostring(ends))
					end
				end
				task.wait(5)
			end
		end)
	end
	local e = HouseEvents.byId[id]
	if not quiet then
		broadcast({ op = "salute", id = id, by = byName, effects = { "goldLeaf" }, seconds = 8, title = e.name, line = e.name .. ": " .. e.line })
		AdminService.note(e.name .. " has begun: " .. e.line, false)
	end
	task.delay(seconds, function()
		if active[id] == ends then
			AdminService.stopEvent(id)
		end
	end)
end

function AdminService.stopEvent(id: string)
	active[id] = nil
	Workspace:SetAttribute(HouseEvents.attribute(id), nil)
	if id == "giants" or id == "tiny" then
		applyGiants(false)
	elseif id == "quickstep" then
		Workspace:SetAttribute("SpeedBoost", nil)
	elseif id == "featherlight" then
		Workspace.Gravity = DEFAULT_GRAVITY
	elseif id == "goldRain" then
		clearPickups("coin")
	elseif id == "treasure" then
		clearPickups("key")
	elseif id == "parade" then
		clearPickups("meme")
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
					local curioId = item:GetAttribute("Curio")
					item:Destroy()
					local data = Profiles.get(player)
					local source = if kind == "key" then "Treasure Hunt" elseif kind == "meme" then "The Brainrot Parade" else "Gold Rain"
					local paid = if data then Gilt.pay(player, data, gilt, source) else 0
					local caught = if kind == "meme" then CurioList.byId[tostring(curioId)] else nil
					local title = if kind == "key" then "A golden key" elseif caught then "You caught " .. caught.name else "Gold"
					Remotes.event("Shop"):FireClient(player, { op = "notice", title = title, line = string.format("+%d Gilt", paid) })
					-- A curio to keep from the event, once each.
					if kind == "coin" then
						Curios.forEvent(player, "rainCoin", "rain:" .. tostring(active.goldRain))
					elseif kind == "meme" then
						Curios.forEvent(player, "paradeBalloon", "parade:" .. tostring(active.parade))
						local left = 0
						for _, other in folder:GetChildren() do
							if other:GetAttribute("Pickup") == "meme" then
								left += 1
							end
						end
						if left == 0 and AdminService.active("parade") then
							AdminService.stopEvent("parade")
							broadcast({ op = "salute", id = "paradeDone", by = "", effects = { "fireworks" }, seconds = 8, title = "The Brainrot Parade", line = "Every meme has been caught. What a night." })
						end
					end
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
	elseif m.op == "fx" and type(m.id) == "string" and HouseEvents.effectById[m.id] then
		AdminService.fx(m.id, tostring(m.by), nil)
	elseif m.op == "stopAll" then
		AdminService.stopAll(tostring(m.by))
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
-- An effect for everyone (HouseEvents.Effects): every screen plays it round its own guest. From
-- the owner's spot when there is one (a shockwave blasts out from there).
function AdminService.fx(id: string, byName: string, origin: Vector3?)
	if not HouseEvents.effectById[id] and id ~= "intro" and id ~= "stop" then
		return
	end
	broadcast({ op = "abuseFX", id = id, by = byName, origin = origin, seconds = cfg().fxSeconds[id] or 6 })
end

local surpriseToken = 0

-- Everything at once: every event (quietly, then one great announcement), the whole house's
-- intro, fireworks, and a surprise for everyone every minute or so until it ends.
function AdminService.abuse(seconds: number, byName: string)
	for _, id in cfg().abuseEvents do
		if HouseEvents.byId[id] then
			AdminService.startEvent(id, seconds, byName, true)
		end
	end
	local ends = os.time() + seconds
	Workspace:SetAttribute("AbuseUntil", ends)
	AdminService.fx("intro", byName, nil)
	broadcast({ op = "salute", id = "abuse", by = byName, effects = { "fireworks", "goldLeaf", "chandelier" }, seconds = 12, title = "Admin Abuse Night", line = "ADMIN ABUSE NIGHT: double Gilt, Mythic luck, gold rain, a treasure hunt, giants, low gravity, a house party, and surprises all night. Go!" })
	AdminService.note("Admin Abuse Night has begun in the house.", false)
	surpriseToken += 1
	local token = surpriseToken
	task.spawn(function()
		local last = ""
		while surpriseToken == token and os.time() < ends do
			task.wait(cfg().abuseSurpriseSeconds)
			if surpriseToken ~= token or os.time() >= ends then
				break
			end
			-- A different surprise each time.
			local pool = {}
			for _, id in cfg().abuseSurprises do
				if id ~= last and HouseEvents.effectById[id] then
					table.insert(pool, id)
				end
			end
			if #pool > 0 then
				last = pool[math.random(1, #pool)]
				AdminService.fx(last, byName, nil)
			end
		end
		if surpriseToken == token and Workspace:GetAttribute("AbuseUntil") == ends then
			Workspace:SetAttribute("AbuseUntil", nil)
		end
	end)
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
-- The owner's own powers
---------------------------------------------------------------------------------------------------
-- Where the owner can go in one tap.
local PLACES = { "street", "foyer", "salon", "boutique", "vault", "library", "ballroom", "terrace", "suite" }

local function placeAt(name: string): Vector3?
	if name == "street" then
		return Layout.Street.spawn.Position
	elseif name == "foyer" then
		return Layout.Foyer.spawn.Position
	elseif name == "salon" then
		return Layout.Salon.arrival
	elseif name == "boutique" then
		return Layout.Boutique.arrival
	elseif name == "vault" then
		return Layout.Vault.arrival
	elseif name == "library" then
		return Layout.Library.arrival
	elseif name == "ballroom" then
		return Layout.Ballroom.arrival
	elseif name == "terrace" then
		return Layout.Terrace.arrival
	elseif name == "suite" then
		return Layout.Suite.arrival
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local BASE_JUMP = 35 -- a guest's jump (Guests)

local function setInvisible(player: Player, on: boolean)
	local character = player.Character
	if character then
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				local thing = d :: any
				local was = d:GetAttribute("AdminWas")
				if on then
					if was == nil then
						d:SetAttribute("AdminWas", thing.Transparency)
					end
					thing.Transparency = 1
				elseif type(was) == "number" then
					thing.Transparency = was
					d:SetAttribute("AdminWas", nil)
				end
			elseif d:IsA("BillboardGui") then
				d.Enabled = not on
			end
		end
	end
	player:SetAttribute("AdminInvisible", if on then true else nil)
end

local function power(player: Player, which: string, value: unknown): { [string]: any }
	local function pick(list: { number }): number?
		return if type(value) == "number" and table.find(list, value) then value else nil
	end
	if which == "fly" then
		local on = player:GetAttribute("AdminFly") ~= true
		player:SetAttribute("AdminFly", if on then true else nil)
		return { ok = true, on = on }
	elseif which == "ghost" then
		-- Through walls (the owner's screen moves them; it only does so when the server says).
		local on = player:GetAttribute("AdminGhost") ~= true
		player:SetAttribute("AdminGhost", if on then true else nil)
		return { ok = true, on = on }
	elseif which == "speed" then
		local v = pick(cfg().speeds)
		if not v then
			return { ok = false, why = "Choose a speed." }
		end
		player:SetAttribute("AdminSpeed", if v == 1 then nil else v)
		return { ok = true }
	elseif which == "jump" then
		local v = pick(cfg().jumps)
		if not v then
			return { ok = false, why = "Choose a jump." }
		end
		player:SetAttribute("AdminJump", if v == 1 then nil else v)
		local humanoid = humanoidOf(player)
		if humanoid then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = BASE_JUMP * v
		end
		return { ok = true }
	elseif which == "size" then
		local v = pick(cfg().sizes)
		local character = player.Character
		if not v or not character then
			return { ok = false, why = "Choose a size." }
		end
		if AdminService.isSeated(player) then
			return { ok = false, why = "Get up from the table first." }
		end
		player:SetAttribute("AdminSize", if v == 1 then nil else v)
		scale(character, Config.data.Movement.guestScale * v)
		return { ok = true }
	elseif which == "invisible" then
		local on = player:GetAttribute("AdminInvisible") ~= true
		setInvisible(player, on)
		return { ok = true, on = on }
	end
	return { ok = false, why = "Unknown." }
end

-- Everyone else, frozen where they stand (and thawed again, by the owner or by itself).
local frozen: { [Player]: boolean } = {}
local freezeToken = 0

local function setFrozen(on: boolean, owner: Player?)
	freezeToken += 1
	local token = freezeToken
	for _, p in Players:GetPlayers() do
		local root = rootOf(p)
		if p ~= owner and root then
			if on and not AdminService.isSeated(p) and not frozen[p] then
				root.Anchored = true
				frozen[p] = true
				p:SetAttribute("Frozen", true)
			elseif not on and frozen[p] then
				root.Anchored = false
				frozen[p] = nil
				p:SetAttribute("Frozen", nil)
			end
		end
	end
	if not on then
		-- (Anyone frozen who has since left, or lost their character.)
		for p in frozen do
			frozen[p] = nil
			if p.Parent == Players then
				p:SetAttribute("Frozen", nil)
			end
		end
	else
		task.delay(cfg().freezeSeconds, function()
			if freezeToken == token then
				setFrozen(false, owner)
			end
		end)
	end
end

-- The time of day (the house's own is midnight).
local CLOCK_ORDER = { "midnight", "dawn", "noon", "sunset" }

local function setClock(name: string): boolean
	local t = cfg().clocks[name]
	if type(t) ~= "number" then
		return false
	end
	Lighting.ClockTime = t
	Workspace:SetAttribute("AdminClock", if name == "midnight" then nil else name)
	return true
end

-- Everything stops at once: every event, Admin Abuse Night and its surprises, a freeze, the time
-- of day, and the effects playing on every screen.
function AdminService.stopAll(byName: string)
	for _, e in HouseEvents.List do
		if active[e.id] then
			AdminService.stopEvent(e.id)
		end
	end
	surpriseToken += 1
	Workspace:SetAttribute("AbuseUntil", nil)
	setFrozen(false, nil)
	if Workspace:GetAttribute("AdminClock") ~= nil then
		setClock("midnight")
	end
	AdminService.fx("stop", byName, nil)
end

local function powersView(player: Player): { [string]: any }
	local anyFrozen = false
	for _ in frozen do
		anyFrozen = true
	end
	local effects = {}
	for _, e in HouseEvents.Effects do
		table.insert(effects, { id = e.id, name = e.name, line = e.line })
	end
	return {
		ghost = player:GetAttribute("AdminGhost") == true,
		clock = Workspace:GetAttribute("AdminClock") or "midnight",
		clocks = CLOCK_ORDER,
		effects = effects,
		abuseOn = Workspace:GetAttribute("AbuseUntil") ~= nil,
		fly = player:GetAttribute("AdminFly") == true,
		speed = player:GetAttribute("AdminSpeed") or 1,
		jump = player:GetAttribute("AdminJump") or 1,
		size = player:GetAttribute("AdminSize") or 1,
		invisible = player:GetAttribute("AdminInvisible") == true,
		frozen = anyFrozen,
		speeds = cfg().speeds,
		jumps = cfg().jumps,
		sizes = cfg().sizes,
		places = PLACES,
	}
end

---------------------------------------------------------------------------------------------------
-- The panel's requests
---------------------------------------------------------------------------------------------------
local lastAsk: { [Player]: number } = {}

local function state(player: Player?): { [string]: any }
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
		shows = Spectacles.names(),
		minutes = cfg().minutes,
		giftGilt = cfg().giftGilt,
		announcements = HouseEvents.Announcements,
		abuseMinutes = cfg().abuseMinutes,
		schedule = scheduleView(),
		powers = if player then powersView(player) else nil,
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
	if lastAsk[player] and now - lastAsk[player] < 0.25 then
		return { ok = false, why = "One moment." }
	end
	lastAsk[player] = now
	local r = request :: { [string]: any }
	local op = r.op
	local byName = player.DisplayName
	Analytics.custom(player, "House controls", nil, { op = tostring(op) })
	if op == "state" then
		return state(player)
	elseif op == "event" and type(r.id) == "string" and HouseEvents.byId[r.id] then
		local minutes = if type(r.minutes) == "number" then math.clamp(r.minutes, 1, 60) else 15
		AdminService.startEvent(r.id, minutes * 60, byName)
		if r.everywhere == true then
			publish({ op = "event", id = r.id, seconds = minutes * 60, by = byName, jobId = game.JobId })
		end
		return state(player)
	elseif op == "abuse" then
		local minutes = if type(r.minutes) == "number" then math.clamp(r.minutes, 5, 60) else 30
		AdminService.abuse(minutes * 60, byName)
		if r.everywhere == true then
			publish({ op = "abuse", seconds = minutes * 60, by = byName, jobId = game.JobId })
		end
		return state(player)
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
		return state(player)
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
		return state(player)
	elseif op == "stop" and type(r.id) == "string" and HouseEvents.byId[r.id] then
		AdminService.stopEvent(r.id)
		return state(player)
	elseif op == "salute" and type(r.id) == "string" and Salutes.byId[r.id] then
		AdminService.salute(nil, r.id, byName)
		return { ok = true }
	elseif op == "show" and type(r.key) == "string" then
		-- A Suite show on the owner's own screen, free, to try it.
		return { ok = Spectacles.preview(player, r.key) }
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
		return state(player)
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
	elseif op == "power" and type(r.power) == "string" then
		local result = power(player, r.power, r.value)
		if result.ok then
			return state(player)
		end
		return result
	elseif op == "goto" then
		if AdminService.isSeated(player) then
			return { ok = false, why = "Get up from the table first." }
		end
		local at: Vector3? = nil
		if type(r.userId) == "number" then
			local target = Players:GetPlayerByUserId(r.userId)
			local root = if target then rootOf(target) else nil
			if root then
				at = root.Position + Vector3.new(4, 0, 0)
			end
		elseif type(r.place) == "string" and table.find(PLACES, r.place) then
			at = placeAt(r.place)
		end
		local character = player.Character
		if not at or not character then
			return { ok = false, why = "Nowhere to go just now." }
		end
		character:PivotTo(CFrame.new(at + Vector3.new(0, 3, 0)))
		return { ok = true }
	elseif op == "bringAll" then
		local mine = player.Character
		if not mine then
			return { ok = false, why = "Nowhere to bring them." }
		end
		local base = mine:GetPivot()
		local others = {}
		for _, p in Players:GetPlayers() do
			if p ~= player and p.Character and not AdminService.isSeated(p) then
				table.insert(others, p)
			end
		end
		for i, p in others do
			local a = i / #others * math.pi * 2
			local character = p.Character :: Model
			character:PivotTo(base * CFrame.new(math.cos(a) * 7, 0, math.sin(a) * 7))
		end
		broadcast({ op = "salute", id = "bringAll", by = byName, effects = { "goldLeaf" }, seconds = 6, title = "Everyone, gather round", line = byName .. " has called every guest together." })
		return { ok = true, brought = #others }
	elseif op == "fx" and type(r.id) == "string" and HouseEvents.effectById[r.id] then
		local root = rootOf(player)
		AdminService.fx(r.id, byName, if root then root.Position else nil)
		if r.everywhere == true then
			publish({ op = "fx", id = r.id, by = byName, jobId = game.JobId })
		end
		return { ok = true }
	elseif op == "stopAll" then
		AdminService.stopAll(byName)
		if r.everywhere == true then
			publish({ op = "stopAll", by = byName, jobId = game.JobId })
		end
		broadcast({ op = "salute", id = "halt", by = byName, effects = {}, seconds = 5, title = "That's all", line = byName .. " called a halt: the house is back to normal." })
		return state(player)
	elseif op == "clock" and type(r.id) == "string" then
		if not setClock(r.id) then
			return { ok = false, why = "Choose a time of day." }
		end
		return state(player)
	elseif op == "freeze" then
		local on = r.on == true
		setFrozen(on, player)
		if on then
			broadcast({ op = "salute", id = "freeze", by = byName, effects = {}, seconds = 6, title = "Freeze!", line = byName .. " froze the house. Nobody move." })
		else
			broadcast({ op = "salute", id = "thaw", by = byName, effects = { "goldLeaf" }, seconds = 5, title = "Thawed", line = "The house moves again." })
		end
		return state(player)
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
		-- New arrivals join a Night of Giants (or of Small Things) in progress; the owner keeps
		-- the size they chose.
		player.CharacterAdded:Connect(function(character)
			-- The owner's jump comes back with a new character; invisibility doesn't.
			player:SetAttribute("AdminInvisible", nil)
			local jump = player:GetAttribute("AdminJump")
			if type(jump) == "number" then
				task.delay(1, function()
					local humanoid = character:FindFirstChildOfClass("Humanoid")
					if humanoid then
						humanoid.UseJumpPower = true
						humanoid.JumpPower = BASE_JUMP * jump
					end
				end)
			end
			local own = player:GetAttribute("AdminSize")
			if AdminService.active("giants") or AdminService.active("tiny") or type(own) == "number" then
				task.wait(1)
				scale(character, Config.data.Movement.guestScale * (if type(own) == "number" then own else eventScale()))
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
		if studioOwner == player then
			studioOwner = nil
		end
	end)
	RemoteGuard.invoke(Remotes.func("AdminAsk"), "adminAsk", handle)
	RemoteGuard.event(Remotes.event("Salute"), "salute", function(player: Player, m: any)
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

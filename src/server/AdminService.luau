--!strict
-- House controls: the owner's panel for keeping the house lively (the "admin abuse" evenings
-- other Roblox games are known for, in the house's own manner), and the owner's own powers. Only
-- the owner, AJKR (the Roblox account XxxXxxX_77797, UserId 8722595934: Config.Admin.ownerUserId),
-- may use any of it: nobody else, whatever their screen sends. Every request is checked here, never on the guest's screen; the powers the
-- owner's screen carries out (flying) are switched on by the server.
--
-- Three ways in, one set of rules: the Owner Console in the game (AdminAsk, owner only), the other
-- servers of the game (MessagingService, when the owner chose "every server"), and the Owner Remote
-- outside the game (Open Cloud messages on Config.Admin.remoteTopic, which only someone holding the
-- owner's Open Cloud key can send). Whatever arrives is checked against the same lists (an effect,
-- an event, a headline, an amount...) before anything happens.
--
-- What it can do: events that boost Gilt, the Ledger and Mythic luck (never a score), giants,
-- a quickstep, featherlight gravity, gold coins scattered through the house, a treasure hunt of
-- golden keys, any Salute for free, dressing the house in another season for a while, crowning
-- or spotlighting a guest, gifts of Gilt, announcements (typed ones are filtered by Roblox), a
-- summons that lets guests in every other house join this one, and removing a guest. The owner's
-- powers: flying, speed, a super jump, any size, invisibility, going anywhere or to any guest,
-- bringing everyone, freezing everyone; a Night of Small Things and the House Party. And: twenty-
-- three effects for everyone, the holiday hunts, Double XP, headlines across every screen,
-- countdowns, giveaways, the Owner's Token, and Mega Abuse.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Names = require(ReplicatedStorage.Shared.Names)
local AbuseNights = require(ReplicatedStorage.Shared.AbuseNights)
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
-- A badge for a guest (set by Main: Achievements.award), and a count of what they've picked up at
-- events (Achievements.tally).
AdminService.award = function(_player: Player, _key: string) end
AdminService.tally = function(_player: Player, _stat: string, _n: number, _once: string?) end
-- Admin Abuse's show (set by Main: AbuseShow): it began (the realms, the gifts), or was stopped.
AdminService.showBegan = function(_mega: boolean, _plan: AbuseNights.Plan?, _since: number?) end
AdminService.showStopped = function() end

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
	-- The owner, by their UserId: XxxXxxX_77797's, AJKR (never a name: a username can change, and a
	-- display name anyone can copy). Nothing else counts: not the account or group the experience
	-- belongs to, not a group rank, not a Studio collaborator. No UserId set, nobody has them.
	local owner = cfg().ownerUserId
	local yes = type(owner) == "number" and owner > 0 and player.UserId == owner
	if not yes and RunService:IsStudio() and cfg().studioFirstPlayer and player.UserId <= 0 and (studioOwner == nil or studioOwner == player or studioOwner.Parent ~= Players) then
		-- (Testing in Studio with its pretend players, Player1 and Player2, who have no real
		-- account: the first one in plays the owner. A real account never stands in, even in
		-- Studio; on a live server there are no pretend players.)
		studioOwner = player
		yes = true
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

-- Effects the owner has switched on (they stay on until switched off): id -> when.
local fxOn: { [string]: number } = {}

local function abusing(): boolean
	local ends = Workspace:GetAttribute("AbuseUntil")
	return type(ends) == "number" and ends > os.time()
end

-- All Gilt: Admin Abuse's Golden Hour doubles it; Mega Abuse makes it triple.
function AdminService.giltBoost(): number
	local b = if AdminService.active("goldenHour") then cfg().goldenHourGilt else 1
	if abusing() and Workspace:GetAttribute("AbuseMega") == true then
		b = math.max(b, cfg().table.megaGilt)
	end
	return b
end

-- What the sorting tables get while the house is in uproar: how many golden pieces in each deal,
-- and why (Mega Abuse, Admin Abuse, or an effect switched on). Nil when nothing is on.
function AdminService.tableTwist(): { golden: number, kind: string }?
	local t = cfg().table
	if abusing() then
		local mega = Workspace:GetAttribute("AbuseMega") == true
		return { golden = if mega then t.golden.mega else t.golden.abuse, kind = if mega then "mega" else "abuse" }
	end
	if next(fxOn) ~= nil then
		return { golden = t.golden.effect, kind = "effect" }
	end
	return nil
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

local function clearPickups(kind: string, hunt: string?)
	for _, p in eventsFolder():GetChildren() do
		if p:GetAttribute("Pickup") == kind and (hunt == nil or p:GetAttribute("Hunt") == hunt) then
			p:Destroy()
		end
	end
end

-- A holiday hunt's pickup: its glyph bobbing at head height (a pumpkin, a turkey, a present...),
-- or the one golden prize, bigger and gold. The part itself is never seen.
local function huntPickup(huntId: string, at: Vector3, glyph: string, gilt: number, jackpot: boolean, moves: boolean): BasePart
	local p = Instance.new("Part")
	p.Name = if jackpot then "HuntJackpot" else "HuntPickup"
	p.Transparency = 1
	p.Size = Vector3.new(2, 2, 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CFrame = CFrame.new(at + Vector3.new(0, 3.2, 0))
	p:SetAttribute("Gilt", gilt)
	p:SetAttribute("Pickup", "hunt")
	p:SetAttribute("Hunt", huntId)
	if jackpot then
		p:SetAttribute("Jackpot", true)
	end
	if moves then
		-- (Moved by the server: a guest's screen doesn't bob it.)
		p:SetAttribute("Moves", true)
		p:SetAttribute("Home", at)
	end
	local glow = Instance.new("PointLight")
	glow.Brightness = if jackpot then 3 else 1
	glow.Range = if jackpot then 16 else 7
	glow.Color = if jackpot then Color3.fromRGB(255, 214, 120) else Color3.fromRGB(255, 236, 200)
	glow.Parent = p
	local bb = Instance.new("BillboardGui")
	bb.Size = if jackpot then UDim2.fromScale(5, 5) else UDim2.fromScale(3.4, 3.4)
	bb.LightInfluence = 0
	bb.MaxDistance = if jackpot then 160 else 90
	bb.Parent = p
	if jackpot then
		local halo = Instance.new("TextLabel")
		halo.Name = "Halo"
		halo.BackgroundTransparency = 1
		halo.Size = UDim2.fromScale(1.5, 1.5)
		halo.Position = UDim2.fromScale(-0.25, -0.25)
		halo.TextScaled = true
		halo.Text = "✨"
		halo.TextTransparency = 0.2
		halo.Parent = bb
	end
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = glyph
	t.TextScaled = true
	t.Parent = bb
	pcall(function()
		game:GetService("CollectionService"):AddTag(p, if jackpot then "HuntJackpot" else "HuntPickup")
	end)
	p.Parent = eventsFolder()
	return p
end

-- Hides a holiday's pickups round the house, and its one golden prize somewhere harder.
local function scatterHunt(huntId: string)
	local h = (cfg().hunts :: any)[huntId]
	if type(h) ~= "table" then
		return
	end
	clearPickups("hunt", huntId)
	local rng = Random.new()
	local points = walkable()
	for i = 1, h.count do
		local base = points[((i - 1) % #points) + 1] + Vector3.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-9, 9))
		huntPickup(huntId, base, h.glyph, h.gilt, false, h.moves == true)
	end
	local prize = CurioList.byId[h.jackpot]
	if prize then
		local base = points[rng:NextInteger(1, #points)] + Vector3.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-12, 12))
		huntPickup(huntId, base, prize.glyph, h.jackpotGilt, true, h.moves == true)
	end
end

-- The Turkey Trot: the turkeys wander, and run from a guest who comes close.
local function trot(dt: number)
	local folder = coinsFolder
	if not folder or not folder.Parent then
		return
	end
	local roots: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			table.insert(roots, root.Position)
		end
	end
	for _, p in folder:GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Moves") == true then
			local home = p:GetAttribute("Home")
			if typeof(home) ~= "Vector3" then
				continue
			end
			local at = p.CFrame.Position
			local target = p:GetAttribute("Target")
			-- Away from the nearest guest within reach, else on to a spot near home.
			local flee: Vector3? = nil
			for _, r in roots do
				local away = Vector3.new(at.X - r.X, 0, at.Z - r.Z)
				if away.Magnitude < 14 then
					flee = if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)
				end
			end
			local dir: Vector3
			local speed = cfg().turkeySpeed
			if flee then
				dir = flee
			else
				if typeof(target) ~= "Vector3" or Vector3.new(target.X - at.X, 0, target.Z - at.Z).Magnitude < 1.5 then
					target = home + Vector3.new(math.random(-16, 16), 3.2, math.random(-16, 16))
					p:SetAttribute("Target", target)
				end
				local to = Vector3.new((target :: Vector3).X - at.X, 0, (target :: Vector3).Z - at.Z)
				dir = if to.Magnitude > 0.1 then to.Unit else Vector3.zero
				speed *= 0.45
			end
			local nextAt = at + dir * speed * dt
			-- Never too far from home (so a turkey stays in the house).
			local fromHome = Vector3.new(nextAt.X - home.X, 0, nextAt.Z - home.Z)
			if fromHome.Magnitude > 26 then
				nextAt = Vector3.new(home.X, nextAt.Y, home.Z) + fromHome.Unit * 26
			end
			p.CFrame = CFrame.new(Vector3.new(nextAt.X, home.Y + 3.2, nextAt.Z))
		end
	end
end
AdminService.trot = trot

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
			if Names.of(p) == byName then
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
	elseif (cfg().hunts :: any)[id] then
		scatterHunt(id)
	elseif id == "newYear" then
		AdminService.newYear(ends, byName)
	elseif id == "disco" then
		task.spawn(function()
			-- Everyone in the Ballroom while it's on gets the Disco Ball (once each).
			while active[id] == ends do
				for _, p in Players:GetPlayers() do
					local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "ballroom" then
						Curios.forEvent(p, "discoBall", "disco:" .. tostring(ends))
						AdminService.award(p, "discoNight")
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
	elseif (cfg().hunts :: any)[id] then
		clearPickups("hunt", id)
	end
end

-- A guest found one of a holiday hunt's pickups (or its golden prize).
local function collectHunt(player: Player, item: BasePart, gilt: number)
	local huntId = tostring(item:GetAttribute("Hunt"))
	local jackpot = item:GetAttribute("Jackpot") == true
	local h = (cfg().hunts :: any)[huntId]
	local event = HouseEvents.byId[huntId]
	local folder = item.Parent
	item:Destroy()
	local data = Profiles.get(player)
	local eventName = if event then event.name else "A holiday hunt"
	local paid = if data then Gilt.pay(player, data, gilt, eventName) else 0
	local curioId = if type(h) == "table" then (if jackpot then h.jackpot else h.curio) else nil
	if type(curioId) == "string" then
		-- The curio for finding one (once a hunt), and the golden prize's own.
		Curios.forEvent(player, curioId, huntId .. (if jackpot then ":gold:" else ":") .. tostring(active[huntId]))
	end
	AdminService.award(player, "holiday_" .. huntId)
	AdminService.tally(player, "pickups", 1)
	local prize = if jackpot and type(h) == "table" then CurioList.byId[h.jackpot] else nil
	Remotes.event("Shop"):FireClient(player, { op = "notice", title = if prize then "You found " .. prize.name .. "!" else eventName, line = string.format("+%d Gilt", paid) })
	if prize then
		broadcast({ op = "salute", id = "jackpot", by = Names.of(player), effects = { "fireworks", "goldLeaf" }, seconds = 8, title = eventName, line = Names.of(player) .. " found " .. prize.name .. "!" })
	end
	local left = 0
	if folder then
		for _, other in folder:GetChildren() do
			if other:GetAttribute("Pickup") == "hunt" and other:GetAttribute("Hunt") == huntId then
				left += 1
			end
		end
	end
	if left == 0 and AdminService.active(huntId) then
		AdminService.stopEvent(huntId)
		broadcast({ op = "salute", id = "huntDone", by = "", effects = { "fireworks" }, seconds = 8, title = eventName, line = "Every one has been found. What a hunt." })
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
					if kind == "hunt" then
						collectHunt(player, item, gilt)
						continue
					end
					local curioId = item:GetAttribute("Curio")
					item:Destroy()
					local data = Profiles.get(player)
					AdminService.tally(player, "pickups", 1)
					if kind == "key" then
						AdminService.award(player, "goldenKey")
					elseif kind == "meme" then
						AdminService.award(player, "paradeCatch")
					end
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
						broadcast({ op = "salute", id = "key", by = Names.of(player), effects = {}, seconds = 4, title = "The Treasure Hunt", line = Names.of(player) .. " found a golden key." })
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

-- Text the owner typed, through Roblox's filter (for everyone to read), or nil if it couldn't be
-- checked just now (then nothing is shown).
local function ownerText(text: string): string?
	local ok, result = pcall(function()
		local r = TextService:FilterStringAsync(text, cfg().ownerUserId, Enum.TextFilterContext.PublicChat)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	return if ok and type(result) == "string" then result else nil
end

-- A headline: big words across the top of every screen in this house, for a few seconds.
function AdminService.headline(text: string, byName: string, style: string?, seconds: number?)
	local look = if style and table.find(HouseEvents.HeadlineStyles, style) then style else "gold"
	local secs = math.clamp(if type(seconds) == "number" then seconds else cfg().headlineSeconds, 3, 15)
	broadcast({ op = "headline", text = string.sub(text, 1, 160), by = byName, style = look, seconds = secs })
	for _, p in Players:GetPlayers() do
		AdminService.award(p, "headline")
	end
end

-- A giveaway: one guest in this house (never the owner) wins Gilt, drawn in front of everyone.
function AdminService.giveaway(amount: number, byName: string): Player?
	local pool: { Player } = {}
	for _, p in Players:GetPlayers() do
		if not AdminService.isAdmin(p) and Profiles.get(p) then
			table.insert(pool, p)
		end
	end
	if #pool == 0 then
		return nil
	end
	local names = {}
	for _, p in pool do
		table.insert(names, Names.of(p))
	end
	local winner = pool[math.random(1, #pool)]
	giftGilt(winner, amount, byName)
	AdminService.award(winner, "giveawayWinner")
	broadcast({ op = "giveaway", names = names, winner = Names.of(winner), winnerId = winner.UserId, amount = amount, by = byName })
	AdminService.note(string.format("%s won %d Gilt in a giveaway.", Names.of(winner), amount), false)
	return winner
end

-- The Owner's Token: a curio for every guest in the house (once a day each).
function AdminService.token(byName: string): number
	local key = "token:" .. (if cfg().tokenDay then os.date("!%Y%m%d") else tostring(os.time()))
	local given = 0
	for _, p in Players:GetPlayers() do
		if Curios.forEvent(p, "ownerToken", key) then
			given += 1
		end
	end
	broadcast({ op = "salute", id = "token", by = byName, effects = { "goldLeaf", "fireworks" }, seconds = 8, title = "The Owner's Token", line = byName .. " handed every guest the Owner's Token." })
	return given
end

-- A countdown on every screen, then what it was counting down to. `options`: the night's (a
-- countdown to Admin Abuse) or the surprise's seed, so every server has the same.
local countdownToken = 0
function AdminService.countdown(id: string, seconds: number, byName: string, options: AbuseOptions?)
	local c = HouseEvents.countdownById[id]
	if not c then
		return
	end
	countdownToken += 1
	local my = countdownToken
	broadcast({ op = "countdown", id = id, label = c.label, seconds = seconds, endsAt = Workspace:GetServerTimeNow() + seconds, by = byName })
	task.delay(seconds, function()
		if countdownToken ~= my then
			return
		end
		local o: AbuseOptions = options or {}
		if id == "abuse" or id == "mega" then
			AdminService.abuse(cfg().countdownAbuseMinutes * 60, byName, id == "mega", o)
		elseif id == "giveaway" then
			AdminService.giveaway(cfg().giveawayGilt[2] or 1000, byName)
		elseif id == "surprise" then
			local r = AbuseNights.rng(AbuseNights.cleanSeed(o.seed) or AbuseNights.newSeed())
			local e = AbuseNights.pick(r, HouseEvents.Effects)
			AdminService.fx(e.id, byName, nil, AbuseNights.int(r, 1, math.max(1, AbuseNights.variantCount(e.id))), AbuseNights.quip(e.id, r))
		end
	end)
end

-- The New Year: ten seconds counted down on every screen, then the year's biggest fireworks, a
-- present of Gilt and the New Year Sparkler for everyone in the house.
function AdminService.newYear(ends: number, byName: string)
	local seconds = 10
	broadcast({ op = "countdown", id = "newYear", label = "HAPPY NEW YEAR IN", seconds = seconds, endsAt = Workspace:GetServerTimeNow() + seconds, by = byName })
	task.delay(seconds, function()
		if active.newYear ~= ends then
			return
		end
		AdminService.fx("fireworks", byName, nil)
		AdminService.fx("confetti", byName, nil)
		broadcast({ op = "headline", text = "HAPPY NEW YEAR!", by = byName, style = "rainbow", seconds = 8 })
		broadcast({ op = "salute", id = "newYear", by = byName, effects = { "fireworks", "goldLeaf", "chandelier" }, seconds = 14, title = "Happy New Year!", line = "Happy New Year from Maison Noir! A present for everyone here." })
		for _, p in Players:GetPlayers() do
			giftGilt(p, cfg().newYearGilt, "The house")
			Curios.forEvent(p, "newYearSparkler", "newYear:" .. tostring(ends))
			AdminService.award(p, "holiday_newYear")
		end
	end)
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
-- (The effects a guest gets a badge for having been there for.)
local WITNESSED: { [string]: boolean } = { blackHole = true, ufo = true, meteor = true, titan = true }

-- `v`: which of its looks (shared/AbuseNights' Variants; the same on every screen in every server);
-- `line`: what AJKR says as it lands.
function AdminService.fx(id: string, byName: string, origin: Vector3?, v: number?, line: string?)
	if not HouseEvents.effectById[id] and id ~= "intro" and id ~= "stop" then
		return
	end
	broadcast({ op = "abuseFX", id = id, by = byName, origin = origin, seconds = cfg().fxSeconds[id] or 6, v = v, line = line })
	if WITNESSED[id] then
		for _, p in Players:GetPlayers() do
			AdminService.award(p, "fx_" .. id)
		end
	end
end

-- Switches an effect on (it stays on, for every guest, until it's switched off) or off. Every
-- screen watches Workspace's Fx_<id> (so a guest arriving later joins in) and plays it round its
-- own guest: the gentle ones simply stay; the ones that move guests come in waves (fxWaves).
-- `v`: which of its looks (given by the server the owner switched it in, so it's the same
-- everywhere; a fresh one if not given).
local fxVariant: { [string]: number } = {}
local function cleanVariant(id: string, v: any): number?
	local count = AbuseNights.variantCount(id)
	if type(v) == "number" and v == v and v >= 1 and v <= count then
		return math.floor(v)
	end
	return nil
end

function AdminService.setFx(id: string, on: boolean, _byName: string, v: number?): boolean
	if not HouseEvents.effectById[id] then
		return false
	end
	if on then
		if fxOn[id] == nil then
			fxOn[id] = os.time()
			local variant = cleanVariant(id, v) or math.random(1, math.max(1, AbuseNights.variantCount(id)))
			fxVariant[id] = variant
			-- (Its looks first: a screen seeing the switch go on already knows which.)
			Workspace:SetAttribute(HouseEvents.fxVariantAttribute(id), variant)
			Workspace:SetAttribute(HouseEvents.fxAttribute(id), fxOn[id])
			if WITNESSED[id] then
				for _, p in Players:GetPlayers() do
					AdminService.award(p, "fx_" .. id)
				end
			end
		end
	elseif fxOn[id] ~= nil then
		fxOn[id] = nil
		fxVariant[id] = nil
		Workspace:SetAttribute(HouseEvents.fxAttribute(id), nil)
		Workspace:SetAttribute(HouseEvents.fxVariantAttribute(id), nil)
	end
	return true
end

function AdminService.isFxOn(id: string): boolean
	return fxOn[id] ~= nil
end

-- Which looks a switched-on effect has here (nil when it's off).
function AdminService.fxVariant(id: string): number?
	return fxVariant[id]
end

-- Every effect off.
function AdminService.allFxOff(byName: string)
	local ids = {}
	for id in fxOn do
		table.insert(ids, id)
	end
	for _, id in ids do
		AdminService.setFx(id, false, byName)
	end
end

local surpriseToken = 0
local openingCount = 0 -- (each Admin Abuse's opening: its fireworks wait for the drop)
local recentNights: { string } = {} -- (the nights this server began lately: a fresh seed avoids them)

-- What Admin Abuse keeps on the Workspace for every screen: when it ends (and whether it's Mega
-- Abuse), when it began, its seed and night (every screen works out the same show from them),
-- its music, and whether AJKR's giant stands over the house.
local ABUSE_ATTRIBUTES = { "AbuseUntil", "AbuseMega", "AbuseSince", "AbuseSeed", "AbuseNight", "AbuseMusic", "AbuseTrack", "AbuseGiant" }
local function clearAbuse()
	for _, name in ABUSE_ATTRIBUTES do
		Workspace:SetAttribute(name, nil)
	end
end

-- A seed for a new night that isn't one of the last few played here.
function AdminService.freshSeed(): number
	local seed = AbuseNights.newSeed()
	for _ = 1, 16 do
		if not table.find(recentNights, AbuseNights.nightFor(seed).id) then
			break
		end
		seed = AbuseNights.newSeed()
	end
	return seed
end

-- The words for a night's twist and hunts (for its announcement).
local BODY_WORDS = { classic = "giants, quick feet and low gravity", giants = "giants and quick feet", tiny = "tiny guests and low gravity", moon = "moon gravity", speed = "quick feet" }
local HUNT_WORDS = { all = "gold rain, a treasure hunt and the meme parade", gold = "gold rain", keys = "a treasure hunt", memes = "the meme parade", goldKeys = "gold rain and a treasure hunt" }
-- (Two twists that can't both be on: a guest is either a giant or tiny.)
local CONFLICTS = { giants = "tiny", tiny = "giants" }

export type AbuseOptions = { seed: number?, night: string?, since: number? }

-- Admin Abuse: one of the house's nights (shared/AbuseNights), worked out from its seed, the same
-- in every server: its boosts, its twist and its hunts, its opening on every screen, its realm (in
-- Mega Abuse, one realm after another), its surprises in its own order at its own moments (two at
-- once, now and then), AJKR's gifts, and the music. `mega`: Mega Abuse (more surprises, faster,
-- giveaways all night, triple Gilt and the Mega Abuse Medal). `options`: the night's seed (else
-- a fresh one), the night asked for (else the seed's), and when it began (a server joining in late
-- keeps to the same moments as the rest).
function AdminService.abuse(seconds: number, byName: string, mega: boolean?, options: AbuseOptions?)
	local o: AbuseOptions = options or {}
	-- (When it ends is settled first: starting every event takes a moment.)
	local now = os.time()
	local ends = now + seconds
	local since = if type(o.since) == "number" and o.since <= now and o.since > now - 7200 then math.floor(o.since) else now
	local seed = AbuseNights.cleanSeed(o.seed) or AdminService.freshSeed()
	local show = (cfg() :: any).show
	local plan = AbuseNights.plan(seed, mega == true, ends - since, o.night, {
		realms = show.realms,
		giant = show.giant,
		giftEvery = show.giftEvery,
		realmSeconds = show.realmSeconds,
	})
	local night = plan.night
	table.insert(recentNights, night.id)
	while #recentNights > 8 do
		table.remove(recentNights, 1)
	end
	for _, id in plan.events do
		if HouseEvents.byId[id] then
			local other = CONFLICTS[id]
			if other and active[other] then
				AdminService.stopEvent(other)
			end
			AdminService.startEvent(id, math.max(1, ends - os.time()), byName, true)
		end
	end
	Workspace:SetAttribute("AbuseMega", if mega then true else nil)
	Workspace:SetAttribute("AbuseSince", since)
	Workspace:SetAttribute("AbuseSeed", seed)
	Workspace:SetAttribute("AbuseNight", night.id)
	Workspace:SetAttribute("AbuseMusic", plan.music)
	Workspace:SetAttribute("AbuseTrack", plan.track)
	Workspace:SetAttribute("AbuseGiant", if plan.giant then true else nil)
	-- (Last: every screen begins the night when this changes, and reads the rest then.)
	Workspace:SetAttribute("AbuseUntil", ends)
	-- The opening on every screen (World/AbuseShow): the night's own (a transmission, a countdown,
	-- a vault door...), then the drop, when the fireworks go up and the music starts.
	broadcast({ op = "abuseShow", stage = "intro", mega = mega == true, by = byName, seed = seed, night = night.id })
	openingCount += 1
	local opening = openingCount
	local dropAt = show.dropAt
	task.delay(dropAt, function()
		if openingCount ~= opening or not abusing() then
			return
		end
		if mega then
			broadcast({ op = "salute", id = "abuse", by = byName, effects = { "fireworks", "goldLeaf", "chandelier" }, seconds = 12, title = "MEGA ABUSE", line = string.format("MEGA ABUSE · %s: every event at once, a new realm every minute or so, triple Gilt, gifts from %s, giveaways all night. Don't leave!", night.name, byName) })
		else
			local extras = {}
			for _, words in { HUNT_WORDS[night.hunts], BODY_WORDS[night.body] } do
				if words then
					table.insert(extras, words)
				end
			end
			broadcast({ op = "salute", id = "abuse", by = byName, effects = { "fireworks", "goldLeaf", "chandelier" }, seconds = 12, title = "Admin Abuse Night", line = string.format("ADMIN ABUSE · %s: double Gilt, double XP, Mythic luck, %s, gifts from %s and surprises all night. Go!", night.name, table.concat(extras, ", "), byName) })
		end
	end)
	AdminService.note(string.format("%s has begun in the house: %s.", if mega then "Mega Abuse" else "Admin Abuse Night", night.name), false)
	AdminService.showBegan(mega == true, plan, since)
	for _, p in Players:GetPlayers() do
		AdminService.award(p, "abuseNight")
		AdminService.tally(p, "abuseNights", 1, "night:" .. tostring(ends))
		if mega then
			Curios.forEvent(p, "abuseMedal", "mega:" .. tostring(ends))
		end
	end
	-- The surprises, at the night's own moments (counted from when it began, so every server lands
	-- each one together; a server joining in late skips those already past).
	surpriseToken += 1
	local token = surpriseToken
	task.spawn(function()
		local nextGiveaway = since + cfg().megaGiveawaySeconds
		while nextGiveaway < os.time() do
			nextGiveaway += cfg().megaGiveawaySeconds
		end
		local i = 1
		while i <= #plan.beats and since + plan.beats[i].at < os.time() - 2 do
			i += 1
		end
		while surpriseToken == token and os.time() < ends do
			local beat = plan.beats[i]
			local wake = if beat then since + beat.at else ends
			if mega then
				wake = math.min(wake, nextGiveaway)
			end
			wake = math.min(wake, ends)
			while surpriseToken == token and os.time() < wake do
				task.wait(math.clamp(wake - os.time(), 0.25, 1))
			end
			if surpriseToken ~= token or os.time() >= ends then
				break
			end
			if beat and os.time() >= since + beat.at then
				AdminService.fx(beat.id, byName, nil, beat.v, beat.line)
				if beat.also then
					AdminService.fx(beat.also, byName, nil, beat.alsoV, nil)
				end
				i += 1
			end
			if mega and os.time() >= nextGiveaway then
				nextGiveaway += cfg().megaGiveawaySeconds
				AdminService.giveaway(cfg().megaGiveawayGilt, byName)
			end
		end
		if surpriseToken == token and Workspace:GetAttribute("AbuseUntil") == ends then
			clearAbuse()
		end
	end)
end

function AdminService.mega(seconds: number, byName: string, options: AbuseOptions?)
	AdminService.abuse(seconds, byName, true, options)
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
				-- (Its seed from its own id: the same night, at the same moments, in every server.)
				AdminService.abuse(left, p.by, false, { seed = AbuseNights.seedOf(p.id), since = p.at })
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

---------------------------------------------------------------------------------------------------
-- What's on everywhere (for servers that open while it's on)
---------------------------------------------------------------------------------------------------
-- When the owner starts something in every server, the other servers hear at once
-- (MessagingService), and it's also written down here (the schedule's DataStore, key "live"), so a
-- server that opens while it's still on joins in: Admin Abuse or Mega Abuse for what's left of it
-- (a countdown to it too), every effect switched on, every event for what's left of it. Each server
-- looks every liveCheck seconds.
--
-- Every command carries when it was given (`at`: the owner's server's clock, or the Owner
-- Remote's), and the record keeps, for each thing, when the latest command about it was given
-- (`marks`: "abuse", "fx:galaxy", every effect "fx:*", "event:goldRain", everything "*"). So an
-- older command arriving late (two servers writing at once, a message held up) never undoes a newer
-- one. The Owner Remote also writes its commands down itself (`log`), so they reach the servers
-- that weren't open to hear them, even when no server at all was open: each server carries out the
-- ones it hasn't (in the order given, skipping any a newer command has overtaken; a giveaway or a
-- headline only within a minute and a half), then writes what they did into the record.
-- (An Admin Abuse night: its id, when it began (or begins, after a countdown) and ends, its seed
-- and the night asked for, so a server joining in plays the very same night.)
type LiveAbuse = { id: string, starts: number?, since: number?, ends: number, mega: boolean, by: string, seed: number?, night: string? }
type LogEntry = { cmd: { [string]: any }, at: number, rid: string }
type Live = {
	abuse: LiveAbuse?,
	fx: { [string]: { since: number, by: string, v: number? } },
	events: { [string]: { ends: number, by: string } },
	marks: { [string]: number },
	log: { LogEntry },
	-- The Owner Remote's test: which test, when, and how many servers have said they heard it.
	pong: { rid: string, at: number, servers: number }?,
}
local LIVE_KEY = "live"
local LOG_MAX = 40 -- the Owner Remote's commands kept written down
local KEEP_SECONDS = 86400 -- a day: older marks and commands are let go
local ONE_SHOT_SECONDS = 90 -- a giveaway or a headline a server missed: carried out this late at most
local liveBegun: { [string]: boolean } = {} -- Admin Abuse nights (by id) this server has begun
local fxFromLive: { [string]: boolean } = {} -- effects on here because they're on everywhere
local eventFromLive: { [string]: boolean } = {}
-- Each thing written down that this server has already acted on (or wrote itself): it joins
-- only what it hasn't, so stopping something in this server alone isn't undone a minute later.
local seenLive: { [string]: boolean } = {}
local seenRemote: { [string]: boolean } = {} -- the Owner Remote's commands (by id) carried out here
local function liveKey(kind: string, id: string, stamp: number): string
	return kind .. ":" .. id .. ":" .. tostring(math.floor(stamp))
end

local function nameOf(v: any): string
	return string.sub(tostring(v or "The owner"), 1, 40)
end

local function cleanLive(v: any): Live
	local now = os.time()
	local out: Live = { fx = {}, events = {}, marks = {}, log = {} }
	if type(v) ~= "table" then
		return out
	end
	local a = v.abuse
	if type(a) == "table" and type(a.id) == "string" and type(a.ends) == "number" and a.ends > now then
		out.abuse = {
			id = string.sub(a.id, 1, 80),
			starts = if type(a.starts) == "number" then a.starts else nil,
			since = if type(a.since) == "number" then a.since else nil,
			ends = a.ends,
			mega = a.mega == true,
			by = nameOf(a.by),
			seed = AbuseNights.cleanSeed(a.seed),
			night = if type(a.night) == "string" and AbuseNights.byId[a.night] then a.night else nil,
		}
	end
	if type(v.fx) == "table" then
		for id, f in v.fx do
			if type(id) == "string" and HouseEvents.effectById[id] and type(f) == "table" then
				out.fx[id] = { since = tonumber(f.since) or now, by = nameOf(f.by), v = cleanVariant(id, f.v) }
			end
		end
	end
	if type(v.events) == "table" then
		for id, e in v.events do
			if type(id) == "string" and HouseEvents.byId[id] and type(e) == "table" and type(e.ends) == "number" and e.ends > now then
				out.events[id] = { ends = e.ends, by = nameOf(e.by) }
			end
		end
	end
	if type(v.marks) == "table" then
		for k, at in v.marks do
			if type(k) == "string" and #k <= 48 and type(at) == "number" and at > now - KEEP_SECONDS then
				out.marks[k] = at
			end
		end
	end
	local pong = v.pong
	if type(pong) == "table" and (type(pong.rid) == "string" or type(pong.rid) == "number") and type(pong.at) == "number" and pong.at > now - KEEP_SECONDS then
		out.pong = { rid = string.sub(tostring(pong.rid), 1, 64), at = pong.at, servers = math.clamp(math.floor(tonumber(pong.servers) or 0), 0, 100000) }
	end
	if type(v.log) == "table" then
		for _, e in v.log do
			if type(e) == "table" and type(e.cmd) == "table" and type(e.cmd.op) == "string" and type(e.at) == "number" and e.at > now - KEEP_SECONDS and (type(e.rid) == "string" or type(e.rid) == "number") then
				table.insert(out.log, { cmd = e.cmd, at = e.at, rid = string.sub(tostring(e.rid), 1, 64) })
			end
		end
		table.sort(out.log, function(x: LogEntry, y: LogEntry): boolean
			return x.at < y.at
		end)
		while #out.log > LOG_MAX do
			table.remove(out.log, 1)
		end
	end
	return out
end

-- How long a command's Admin Abuse or event runs (the same bounds whichever way it came).
local function abuseSeconds(m: { [string]: any }): number
	return math.clamp(if type(m.seconds) == "number" then m.seconds elseif type(m.minutes) == "number" then m.minutes * 60 else 1800, 60, 3600)
end
local function eventSeconds(m: { [string]: any }): number
	return math.clamp(if type(m.seconds) == "number" then m.seconds elseif type(m.minutes) == "number" then m.minutes * 60 else 900, 60, 3600)
end

-- A command's seed (a night's, a surprise's): the one it carries, else one from its own id, so
-- every server works out the same.
local function seedFor(m: { [string]: any }, at: number): number
	local given = AbuseNights.cleanSeed(m.seed)
	if given then
		return given
	elseif type(m.rid) == "string" or type(m.rid) == "number" then
		return AbuseNights.seedOf("rid:" .. tostring(m.rid))
	elseif type(m.liveId) == "string" then
		return AbuseNights.seedOf(m.liveId)
	end
	return AbuseNights.seedOf("at:" .. tostring(math.floor(at)))
end
local function nightOf(m: { [string]: any }): string?
	return if type(m.night) == "string" and AbuseNights.byId[m.night] then m.night else nil
end
-- Which looks a switched-on effect has: the command's, else one from its seed.
local function variantFor(m: { [string]: any }, at: number): number?
	if type(m.id) ~= "string" then
		return nil
	end
	local given = cleanVariant(m.id, m.v)
	if given then
		return given
	end
	local count = AbuseNights.variantCount(m.id)
	return if count > 0 then 1 + seedFor(m, at) % count else nil
end

-- The one id an Admin Abuse night is known by in every server (so none begins it twice).
local function liveIdOf(m: { [string]: any }, at: number): string
	if type(m.liveId) == "string" then
		return string.sub(m.liveId, 1, 80)
	elseif type(m.rid) == "string" or type(m.rid) == "number" then
		return "remote:" .. string.sub(tostring(m.rid), 1, 64)
	end
	return "at:" .. tostring(math.floor(at))
end

-- What a command changes in the record, or nil for one that changes nothing lasting (a giveaway,
-- a headline, a countdown to a surprise).
local function targetOf(m: { [string]: any }): string?
	local op = m.op
	if op == "abuse" or op == "mega" or (op == "countdown" and (m.id == "abuse" or m.id == "mega")) then
		return "abuse"
	elseif op == "fx" and type(m.id) == "string" and HouseEvents.effectById[m.id] then
		return "fx:" .. m.id
	elseif op == "fxAllOff" then
		return "fx:*"
	elseif (op == "event" or op == "stop") and type(m.id) == "string" and HouseEvents.byId[m.id] then
		return "event:" .. m.id
	elseif op == "stopAll" then
		return "*"
	end
	return nil
end

-- Whether a newer command has already changed this thing (or everything).
local function overtaken(live: Live, target: string, at: number): boolean
	local function after(k: string): boolean
		local mark = live.marks[k]
		return mark ~= nil and mark > at
	end
	return after(target) or after("*") or (string.sub(target, 1, 3) == "fx:" and after("fx:*"))
end

-- Writes one command into the record. False when that changes nothing (it's there already, or a
-- newer command has overtaken it).
local function writeLive(live: Live, m: { [string]: any }, at: number, byName: string): boolean
	local target = targetOf(m)
	if not target or live.marks[target] == at or overtaken(live, target, at) then
		return false
	end
	local function markOf(key: string, fallback: number): number
		return live.marks[key] or fallback
	end
	local op = m.op
	if op == "abuse" or op == "mega" then
		live.abuse = { id = liveIdOf(m, at), since = math.floor(at), ends = at + abuseSeconds(m), mega = op == "mega", by = byName, seed = seedFor(m, at), night = nightOf(m) }
	elseif op == "countdown" then
		local starts = at + (if type(m.seconds) == "number" then m.seconds else 10)
		live.abuse = { id = liveIdOf(m, at), starts = starts, since = math.floor(starts), ends = starts + cfg().countdownAbuseMinutes * 60, mega = m.id == "mega", by = byName, seed = seedFor(m, at), night = nightOf(m) }
	elseif op == "fx" then
		if m.on ~= false then
			live.fx[m.id] = { since = at, by = byName, v = variantFor(m, at) }
		else
			live.fx[m.id] = nil
		end
	elseif op == "fxAllOff" or op == "stopAll" then
		-- (Only what was given before it: an effect switched on after, arriving first, stays on.)
		for id, f in live.fx do
			if markOf("fx:" .. id, f.since) <= at then
				live.fx[id] = nil
			end
		end
		if op == "stopAll" then
			if live.abuse and markOf("abuse", 0) <= at then
				live.abuse = nil
			end
			for id in live.events do
				if markOf("event:" .. id, 0) <= at then
					live.events[id] = nil
				end
			end
		end
	elseif op == "event" then
		live.events[m.id] = { ends = at + eventSeconds(m), by = byName }
	elseif op == "stop" then
		live.events[m.id] = nil
	end
	live.marks[target] = at
	return true
end

-- Changes what's written down (never waits: the owner's tap isn't held up by the DataStore).
-- `change` says whether it changed anything (if not, nothing is written). `spread`: wait up to
-- that many seconds first (every server writing the same thing doesn't all write at once).
local function changeLive(change: (Live) -> boolean, spread: number?)
	local store = scheduleStore
	if not store then
		return
	end
	task.spawn(function()
		if spread and spread > 0 then
			task.wait(math.random() * spread)
		end
		pcall(function()
			store:UpdateAsync(LIVE_KEY, function(old: any): any
				local live = cleanLive(old)
				if not change(live) then
					return nil -- (nothing new: no write)
				end
				return live
			end)
		end)
	end)
end
AdminService.changeLive = changeLive

-- What this server has just carried out itself, so catching up never carries it out again.
local function markSeen(m: { [string]: any }, at: number)
	local op = m.op
	if op == "fx" and m.on ~= false and type(m.id) == "string" then
		seenLive[liveKey("fx", m.id, at)] = true
	elseif op == "event" and type(m.id) == "string" then
		seenLive[liveKey("event", m.id, at + eventSeconds(m))] = true
	elseif op == "abuse" or op == "mega" or (op == "countdown" and (m.id == "abuse" or m.id == "mega")) then
		liveBegun[liveIdOf(m, at)] = true
	end
end

-- When a command was given: the stamp it carries (if it's a sensible one), else now.
local function stampOf(m: { [string]: any }): number
	local now = Workspace:GetServerTimeNow()
	local at = tonumber(m.at)
	if at and at == at and math.abs(at - now) < 600 then
		return at
	end
	return now
end

-- (Set below: carries out one command in this house.)
local applyCommand: (m: { [string]: any }, byName: string, remote: boolean, at: number?) -> boolean = function()
	return false
end

-- This server catches up with what's on everywhere.
local function syncLive()
	local store = scheduleStore
	if not store then
		return
	end
	local ok, value = pcall(function()
		return store:GetAsync(LIVE_KEY)
	end)
	if not ok then
		return
	end
	local live = cleanLive(value)
	local now = os.time()
	-- The Owner Remote's commands this server hasn't carried out, in the order given.
	local ownerName = nameOf(cfg().ownerName)
	for _, e in live.log do
		if not seenRemote[e.rid] then
			seenRemote[e.rid] = true
			local target = targetOf(e.cmd)
			if target then
				-- (Already in the record, or overtaken by something newer: the record below has it.)
				local mark = live.marks[target]
				if (mark == nil or mark < e.at) and not overtaken(live, target, e.at) then
					applyCommand(e.cmd, ownerName, true, e.at)
					writeLive(live, e.cmd, e.at, ownerName)
				end
			elseif now - e.at <= ONE_SHOT_SECONDS then
				applyCommand(e.cmd, ownerName, true, e.at)
			end
		end
	end
	local a = live.abuse
	if a and not liveBegun[a.id] then
		-- (The same night as everywhere else: its seed, and its moments counted from when it began.)
		local options = { seed = a.seed or AbuseNights.seedOf(a.id), night = a.night, since = a.since or a.starts }
		if a.starts and a.starts > now then
			-- (Opening during the countdown to it: the rest of the countdown, then it.)
			if a.starts - now >= 3 then
				liveBegun[a.id] = true
				AdminService.countdown(if a.mega then "mega" else "abuse", a.starts - now, a.by, options)
			end
		else
			liveBegun[a.id] = true
			AdminService.abuse(a.ends - now, a.by, a.mega, options)
		end
	end
	for id, f in live.fx do
		local key = liveKey("fx", id, f.since)
		if not seenLive[key] then
			seenLive[key] = true
			if fxOn[id] == nil then
				AdminService.setFx(id, true, f.by, f.v)
			end
			fxFromLive[id] = true
		end
	end
	-- Switched off everywhere since (the message may have been missed): off here too. (Not one
	-- switched on in the last minute: it may not have been written down yet.)
	for id in fxFromLive do
		if not live.fx[id] then
			fxFromLive[id] = nil
			local since = fxOn[id]
			if since and now - since > 60 then
				AdminService.setFx(id, false, "The owner")
			end
		end
	end
	for id, e in live.events do
		local key = liveKey("event", id, e.ends)
		if not seenLive[key] then
			seenLive[key] = true
			local mine = active[id]
			if not mine or mine < e.ends - 30 then
				AdminService.startEvent(id, e.ends - now, e.by)
			end
			eventFromLive[id] = true
		end
	end
	for id in eventFromLive do
		if not live.events[id] then
			eventFromLive[id] = nil
		end
	end
end
AdminService.syncLive = syncLive
-- (For tests.)
AdminService.cleanLive = cleanLive
AdminService.writeLive = writeLive

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
	countdownToken += 1
	clearAbuse()
	AdminService.showStopped()
	AdminService.allFxOff(byName)
	broadcast({ op = "countdown", id = "", stop = true })
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
		table.insert(effects, { id = e.id, name = e.name, line = e.line, glyph = e.glyph, on = fxOn[e.id] ~= nil })
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
		table.insert(guests, { userId = p.UserId, name = Names.of(p), crowned = p:GetAttribute("GuestOfHonour") == true })
	end
	local events = {}
	for _, e in HouseEvents.List do
		table.insert(events, { id = e.id, name = e.name, line = e.line, endsAt = active[e.id], glyph = e.glyph, holiday = e.holiday == true })
	end
	local countdowns = {}
	for _, c in HouseEvents.Countdowns do
		table.insert(countdowns, { id = c.id, name = c.name, label = c.label })
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
		-- The Owner Console's own lists.
		headlines = HouseEvents.Headlines,
		headlineStyles = HouseEvents.HeadlineStyles,
		countdowns = countdowns,
		countdownSeconds = cfg().countdowns,
		giveawayGilt = cfg().giveawayGilt,
		mega = Workspace:GetAttribute("AbuseMega") == true,
		abuseUntil = Workspace:GetAttribute("AbuseUntil"),
		abuseNight = Workspace:GetAttribute("AbuseNight"),
		guestsHere = #Players:GetPlayers(),
		fxOn = (function()
			local on = {}
			for id in fxOn do
				on[id] = true
			end
			return on
		end)(),
	}
end

---------------------------------------------------------------------------------------------------
-- Commands from the other servers of the game and from the Owner Remote
---------------------------------------------------------------------------------------------------
-- One command, checked against the same lists as the console's, then carried out in this house.
-- `remote`: it came from outside the game (the Owner Remote), so typed words are filtered here and
-- what lasts is written down by this server too (the remote may not have been able to). `at`: when
-- it was given (an Admin Abuse night or an event ends the same moment in every server, however late
-- the message came).
local function apply(m: { [string]: any }, byName: string, remote: boolean, given: number?): boolean
	local op = m.op
	local now = os.time()
	local at: number = given or Workspace:GetServerTimeNow()
	local function words(): string?
		if type(m.preset) == "number" then
			return HouseEvents.Headlines[m.preset]
		elseif type(m.text) == "string" and #m.text > 0 and #m.text <= 160 then
			-- (From another server the words were filtered there; from outside, here.)
			return if remote then ownerText(m.text) else m.text
		end
		return nil
	end
	-- What lasts, written down by this server too (only for the Owner Remote's: another server's
	-- command was written down by the owner's own server).
	local function writeDown()
		if remote then
			changeLive(function(live: Live): boolean
				return writeLive(live, m, at, byName)
			end, 5)
		end
	end
	if op == "announce" then
		local text = words()
		if text then
			announce(text, byName)
		end
		return text ~= nil
	elseif op == "headline" then
		local text = words()
		if text then
			AdminService.headline(text, byName, m.style, m.seconds)
		end
		return text ~= nil
	elseif op == "event" and type(m.id) == "string" and HouseEvents.byId[m.id] then
		local id = m.id
		local left = math.floor(at + eventSeconds(m) - now)
		if left > 0 then
			AdminService.startEvent(id, left, byName)
			eventFromLive[id] = true
		end
		markSeen(m, at)
		writeDown()
		return true
	elseif op == "stop" and type(m.id) == "string" and HouseEvents.byId[m.id] then
		local id = m.id
		AdminService.stopEvent(id)
		eventFromLive[id] = nil
		writeDown()
		return true
	elseif op == "abuse" or op == "mega" then
		-- The same night, known by one id in every server (so a server catching up later doesn't
		-- begin it twice): the owner's server gave it one; the Owner Remote sends its run's.
		local liveId = liveIdOf(m, at)
		local left = math.floor(at + abuseSeconds(m) - now)
		if not liveBegun[liveId] and left > 0 then
			liveBegun[liveId] = true
			-- (The same night as every other server: its seed, its moments counted from `at`.)
			AdminService.abuse(left, byName, op == "mega", { seed = seedFor(m, at), night = nightOf(m), since = math.floor(at) })
		end
		writeDown()
		return true
	elseif op == "fx" and type(m.id) == "string" and HouseEvents.effectById[m.id] then
		-- On (it stays on) unless the message says off; its looks the command's (or its seed's).
		local id, on = m.id, m.on ~= false
		if on then
			m.v = variantFor(m, at)
		end
		AdminService.setFx(id, on, byName, m.v)
		if on then
			fxFromLive[id] = true
		else
			fxFromLive[id] = nil
		end
		markSeen(m, at)
		writeDown()
		return true
	elseif op == "fxAllOff" then
		AdminService.allFxOff(byName)
		table.clear(fxFromLive)
		writeDown()
		return true
	elseif op == "stopAll" then
		AdminService.stopAll(byName)
		table.clear(fxFromLive)
		table.clear(eventFromLive)
		writeDown()
		return true
	elseif op == "countdown" and type(m.id) == "string" and HouseEvents.countdownById[m.id] and type(m.seconds) == "number" and table.find(cfg().countdowns, m.seconds) then
		local id = m.id
		local left = at + m.seconds - now
		local options = { seed = seedFor(m, at), night = nightOf(m), since = math.floor(at + m.seconds) }
		if id == "abuse" or id == "mega" then
			local liveId = liveIdOf(m, at)
			if not liveBegun[liveId] then
				liveBegun[liveId] = true
				if left >= 3 then
					AdminService.countdown(id, left, byName, options)
				else
					-- (Heard after the countdown was over: Admin Abuse for what's left of it.)
					local rest = math.floor(at + m.seconds + cfg().countdownAbuseMinutes * 60 - now)
					if rest > 0 then
						AdminService.abuse(rest, byName, id == "mega", options)
					end
				end
			end
			writeDown()
		else
			AdminService.countdown(id, math.max(3, left), byName, options)
		end
		return true
	elseif op == "giftAll" and type(m.amount) == "number" and table.find(cfg().giftGilt, m.amount) then
		for _, p in Players:GetPlayers() do
			giftGilt(p, m.amount, byName)
		end
		return true
	elseif op == "giveaway" and type(m.amount) == "number" and table.find(cfg().giveawayGilt, m.amount) then
		AdminService.giveaway(m.amount, byName)
		return true
	elseif op == "token" then
		AdminService.token(byName)
		return true
	elseif op == "clock" and type(m.id) == "string" then
		return setClock(m.id)
	elseif op == "salute" and type(m.id) == "string" and Salutes.byId[m.id] then
		AdminService.salute(nil, m.id, byName)
		return true
	elseif op == "ping" and remote then
		-- The Owner Remote's test: nothing happens in the house. This server says it heard it, in
		-- the record the remote reads back ("3 servers heard it").
		local rid = if type(m.rid) == "string" or type(m.rid) == "number" then string.sub(tostring(m.rid), 1, 64) else nil
		if rid then
			changeLive(function(live: Live): boolean
				local p = live.pong
				if p and p.rid == rid then
					p.servers += 1
				else
					live.pong = { rid = rid, at = at, servers = 1 }
				end
				return true
			end)
		end
		print("[Maison] The Owner Remote's test arrived in this server.")
		return true
	elseif op == "summon" and not remote and type(m.jobId) == "string" then
		summons[m.jobId] = os.time() + cfg().summonMinutes * 60
		broadcast({ op = "summon", jobId = m.jobId, by = byName, text = tostring(m.text or "") })
		return true
	end
	return false
end
AdminService.apply = apply
applyCommand = apply

-- Another server of the game, where the owner chose "every server".
local function onMessage(message: any)
	local m = if type(message) == "table" then message.Data else nil
	if type(m) ~= "table" or m.jobId == game.JobId then
		return
	end
	apply(m, nameOf(m.by), false, stampOf(m))
end

-- The Owner Remote, outside the game: a line of JSON on the remote topic (Open Cloud), at most a
-- few a second. (The same command is also written down by the remote when it can, for servers that
-- weren't open: carried out once here, whichever way it arrives first.)
local remoteTimes: { number } = {}
local function onRemote(message: any)
	local raw = if type(message) == "table" then message.Data else nil
	local m: any = raw
	if type(raw) == "string" then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		m = if ok then decoded else nil
	end
	if type(m) ~= "table" then
		warn("[Maison] The Owner Remote sent something that isn't a command.")
		return
	end
	local rid = if type(m.rid) == "string" or type(m.rid) == "number" then string.sub(tostring(m.rid), 1, 64) else nil
	if rid then
		if seenRemote[rid] then
			return
		end
		seenRemote[rid] = true
	end
	local now = os.clock()
	while #remoteTimes > 0 and now - remoteTimes[1] > 10 do
		table.remove(remoteTimes, 1)
	end
	if #remoteTimes >= 20 then
		return
	end
	table.insert(remoteTimes, now)
	if not apply(m, nameOf(cfg().ownerName), true, stampOf(m)) then
		warn("[Maison] The Owner Remote's command wasn't one the house knows: " .. tostring(m.op))
	end
end
AdminService.onRemote = onRemote

-- The owner chose "every server" in the console: the other servers hear it at once, and what lasts
-- is written down (by this server alone) for any server that opens while it's on.
local function everywhere(m: { [string]: any }, byName: string)
	local at = Workspace:GetServerTimeNow()
	m.at = at
	m.by = byName
	m.jobId = game.JobId
	markSeen(m, at)
	publish(m)
	if targetOf(m) then
		changeLive(function(live: Live): boolean
			return writeLive(live, m, at, byName)
		end)
	end
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
	local byName = Names.of(player)
	Analytics.custom(player, "House controls", nil, { op = tostring(op) })
	if op == "state" then
		return state(player)
	elseif op == "event" and type(r.id) == "string" and HouseEvents.byId[r.id] then
		local id = r.id
		local minutes = if type(r.minutes) == "number" then math.clamp(r.minutes, 1, 60) else 15
		AdminService.startEvent(id, minutes * 60, byName)
		if r.everywhere == true then
			everywhere({ op = "event", id = id, seconds = minutes * 60 }, byName)
		end
		return state(player)
	elseif op == "abuse" or op == "mega" then
		local minutes = if type(r.minutes) == "number" then math.clamp(r.minutes, 5, 60) else 30
		local mega = op == "mega"
		-- The night: the one the owner chose, else one of the house's nights by a fresh seed.
		local night = if type(r.night) == "string" and AbuseNights.byId[r.night] then r.night else nil
		local seed = AdminService.freshSeed()
		AdminService.abuse(minutes * 60, byName, mega, { seed = seed, night = night })
		if r.everywhere == true then
			-- Every server now, and any server that opens while it's still on (one id for the night;
			-- its seed, so every server plays the very same night).
			everywhere({ op = op, seconds = minutes * 60, liveId = HttpService:GenerateGUID(false), seed = seed, night = night }, byName)
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
		local id = r.id
		AdminService.stopEvent(id)
		if r.everywhere == true then
			everywhere({ op = "stop", id = id }, byName)
		end
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
			broadcast({ op = "salute", id = "crown", by = byName, userId = target.UserId, effects = { "encore", "goldLeaf" }, seconds = 20, title = "A Guest of Honour", line = Names.of(target) .. " is tonight's Guest of Honour." })
			AdminService.note(Names.of(target) .. " is tonight's Guest of Honour.", false)
		elseif op == "spotlight" then
			broadcast({ op = "salute", id = "spotlight", by = byName, userId = target.UserId, effects = { "encore" }, seconds = 20, title = "The spotlight", line = "The spotlight finds " .. Names.of(target) .. "." })
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
		if r.everywhere == true then
			everywhere({ op = "giftAll", amount = amount }, byName)
		end
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
			everywhere({ op = "announce", text = text }, byName)
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
		-- Switched on (it stays on until switched off) or off; a tap on a lit one switches it off.
		local id = r.id
		local on = if type(r.on) == "boolean" then r.on else not AdminService.isFxOn(id)
		AdminService.setFx(id, on, byName)
		if r.everywhere == true then
			-- (Its looks too: the same in every server.)
			everywhere({ op = "fx", id = id, on = on, v = if on then AdminService.fxVariant(id) else nil }, byName)
		end
		return state(player)
	elseif op == "fxAllOff" then
		AdminService.allFxOff(byName)
		if r.everywhere == true then
			everywhere({ op = "fxAllOff" }, byName)
		end
		return state(player)
	elseif op == "stopAll" then
		AdminService.stopAll(byName)
		if r.everywhere == true then
			everywhere({ op = "stopAll" }, byName)
		end
		broadcast({ op = "salute", id = "halt", by = byName, effects = {}, seconds = 5, title = "That's all", line = byName .. " called a halt: the house is back to normal." })
		return state(player)
	elseif op == "clock" and type(r.id) == "string" then
		if not setClock(r.id) then
			return { ok = false, why = "Choose a time of day." }
		end
		return state(player)
	elseif op == "headline" then
		local text: string? = nil
		if type(r.preset) == "number" then
			text = HouseEvents.Headlines[r.preset]
		elseif type(r.text) == "string" and #r.text > 0 and #r.text <= 140 then
			text = filtered(r.text, player)
			if not text then
				return { ok = false, why = "Roblox's filter couldn't check that just now." }
			end
		end
		if not text then
			return { ok = false, why = "Choose or write a headline." }
		end
		local style = if type(r.style) == "string" and table.find(HouseEvents.HeadlineStyles, r.style) then r.style else "gold"
		local seconds = if type(r.seconds) == "number" then math.clamp(r.seconds, 3, 15) else cfg().headlineSeconds
		AdminService.headline(text, byName, style, seconds)
		if r.everywhere == true then
			everywhere({ op = "headline", text = text, style = style, seconds = seconds }, byName)
		end
		return { ok = true, text = text }
	elseif op == "countdown" and type(r.id) == "string" and HouseEvents.countdownById[r.id] then
		local seconds = if type(r.seconds) == "number" and table.find(cfg().countdowns, r.seconds) then r.seconds else nil
		if not seconds then
			return { ok = false, why = "Choose how long." }
		end
		local night = if type(r.night) == "string" and AbuseNights.byId[r.night] then r.night else nil
		local seed = if r.id == "abuse" or r.id == "mega" then AdminService.freshSeed() else AbuseNights.newSeed()
		AdminService.countdown(r.id, seconds, byName, { seed = seed, night = night })
		if r.everywhere == true then
			-- (A countdown to Admin Abuse: written down too, so a server opening meanwhile counts down
			-- with the rest, and one opening after joins in.)
			everywhere({ op = "countdown", id = r.id, seconds = seconds, liveId = HttpService:GenerateGUID(false), seed = seed, night = night }, byName)
		end
		return { ok = true }
	elseif op == "giveaway" then
		local amount = if type(r.amount) == "number" and table.find(cfg().giveawayGilt, r.amount) then r.amount else nil
		if not amount then
			return { ok = false, why = "Choose an amount." }
		end
		local winner = AdminService.giveaway(amount, byName)
		if r.everywhere == true then
			everywhere({ op = "giveaway", amount = amount }, byName)
		end
		if not winner and r.everywhere ~= true then
			return { ok = false, why = "Nobody else is in this house to win it." }
		end
		return { ok = true, winner = if winner then Names.of(winner) else nil }
	elseif op == "token" then
		local given = AdminService.token(byName)
		if r.everywhere == true then
			everywhere({ op = "token" }, byName)
		end
		return { ok = true, given = given }
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
				-- The owner is here: the whole house hears it (and everyone here has met them).
				if cfg().announceOwner then
					task.delay(4, function()
						if player.Parent == Players then
							AdminService.headline("👑 " .. string.upper(Names.owner()) .. " IS IN THE SERVER! 👑", Names.owner(), "rainbow", 7)
						end
					end)
				end
				for _, p in Players:GetPlayers() do
					AdminService.award(p, "metOwner")
				end
			else
				-- Arriving where the owner already is.
				for _, p in Players:GetPlayers() do
					if p ~= player and p:GetAttribute("MaisonAdmin") == true then
						AdminService.award(player, "metOwner")
					end
				end
				-- Arriving in the middle of Admin Abuse Night.
				local until_ = Workspace:GetAttribute("AbuseUntil")
				if type(until_) == "number" and until_ > os.time() then
					AdminService.award(player, "abuseNight")
					AdminService.tally(player, "abuseNights", 1, "night:" .. tostring(until_))
				end
				-- Arriving while a black hole (say) is switched on: they're there for it too.
				for id in fxOn do
					if WITNESSED[id] then
						AdminService.award(player, "fx_" .. id)
					end
				end
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
	-- The Owner Remote (Open Cloud, from outside the game).
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(cfg().remoteTopic, onRemote)
		end)
		if not ok and not RunService:IsStudio() then
			warn("[Maison] The Owner Remote couldn't be heard in this server: " .. tostring(err))
		end
	end)
	-- The Turkey Trot's turkeys run (only while it's on).
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			if active.thanksgiving then
				pcall(trot, dt)
			end
		end
	end)
	-- On the real holiday, the house starts its own hunt for the first minutes of every hour.
	task.spawn(function()
		local begun: { [string]: boolean } = {}
		while true do
			pcall(function()
				local auto = cfg().holidayAuto
				if not auto or not auto.enabled then
					return
				end
				local t = os.date("!*t") :: any
				local id = HouseEvents.holidayOn(t.year, t.month, t.day)
				-- (Not with under a minute left: a server opening at :09:50 waits for the next hour.)
				local left = (auto.minutes - t.min) * 60 - t.sec
				if id and t.min < auto.minutes and left >= 60 then
					local key = string.format("%s:%d:%d", id, t.yday, t.hour)
					if not begun[key] and not AdminService.active(id) then
						begun[key] = true
						AdminService.startEvent(id, left, "The house")
					end
				end
			end)
			task.wait(20)
		end
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
	-- What's on everywhere: at once (a server opening mid-abuse joins in), then now and then.
	task.spawn(function()
		while true do
			pcall(syncLive)
			task.wait(cfg().liveCheck)
		end
	end)
end

-- For tests: the panel's handler and the schedule's tick.
AdminService.handle = handle
AdminService.runSchedule = runSchedule
AdminService.collect = collect

return AdminService

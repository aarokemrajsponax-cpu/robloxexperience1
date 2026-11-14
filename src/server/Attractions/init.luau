--!strict
-- The attractions on the server (shared/Attractions says what they are). Each is built once, in its
-- own place well away from the Maison, when the house opens; this takes guests in (from its room
-- off the Foyer: the entrance there, or AttractionAsk "go" while standing in that room) and home,
-- keeps the "Attraction" attribute on each guest who is in one (their screen shows its HUD then,
-- and only then), runs every attraction ten times a second, and passes each its own requests.
--
-- A guest who leaves an attraction any way at all (home, a respawn, quitting, the house moving
-- them somewhere else) is let go of by it at once: what it holds for them that isn't banked is
-- lost, as each attraction's own screen says plainly.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Analytics = require(script.Parent.Analytics)
local AttractionList = require(ReplicatedStorage.Shared.Attractions)
local Config = require(ReplicatedStorage.Shared.Config)
local Curios = require(script.Parent.Curios)
local Directory = require(ReplicatedStorage.Shared.Directory)
local Fortune = require(script.Parent.Fortune)
local Gilt = require(script.Parent.Gilt)
local Herald = require(script.Parent.Herald)
local Integrity = require(script.Parent.Integrity)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Types = require(script.Types)
local Luxe = require(script.Luxe)
local Basement = require(script.Basement)
local ExecutiveGame = require(script.Executive)
local IslandGame = require(script.Island)
local GalaGame = require(script.Gala)

local Attractions = {}

---------------------------------------------------------------------------------------------------
-- Hooks (set by Main, through the Empire)
---------------------------------------------------------------------------------------------------
Attractions.isSeated = function(_player: Player): boolean
	return false
end
Attractions.award = function(_player: Player, _key: string) end
Attractions.tally = function(_player: Player, _stat: string, _n: number, _once: string?) end
Attractions.progress = function(_player: Player, _kind: string, _n: number) end
Attractions.isOwner = function(_player: Player): boolean
	return false
end

local GAMES: { [string]: Types.Game } = {
	luxe = Luxe :: any,
	basement = Basement :: any,
	executive = ExecutiveGame :: any,
	island = IslandGame :: any,
	gala = GalaGame :: any,
}

local event = Remotes.event("Attraction")
local inside: { [Player]: string } = {}
local lastTravel: { [Player]: number } = {}
-- When each guest arrived (and where they were put), and since when they've been seen outside the
-- place they're in. Right after the way in, the server can still be seeing where the guest stood
-- before (their own computer moves their character, and the new place takes a moment to come
-- back), so a guest is never let go of in their first moments, nor for a moment's odd reading:
-- only once they've really been out of the place for a while.
local arrived: { [Player]: { at: number, frame: CFrame, again: boolean } } = {}
local awaySince: { [Player]: number } = {}
local ARRIVAL_GRACE = 4 -- seconds after arriving when "outside" is never believed
-- (Build 82) Held on arrival in the tuned attractions (Config.Movement.tuned) while the guest's
-- screen makes the place ready: until when at least, at most, and whether their screen is ready.
local held: { [Player]: { from: number, least: number, most: number, ready: boolean, root: BasePart? } } = {}
local AWAY_SECONDS = 1.5 -- seconds out of the place before a guest is let go of
local folder: Folder? = nil
local rng = Random.new()

local function cfg(id: string): { [string]: any }
	local all = (Config.data :: any).Attractions
	return all[id] or {}
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function holder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "Attractions"
	nf.Parent = Workspace
	folder = nf
	return nf
end

-- The guest's saved record's page for an attraction (made on first asking).
local function saved(data: any, id: string): { [string]: any }
	if type(data.attractions) ~= "table" then
		data.attractions = {}
	end
	local page = data.attractions[id]
	if type(page) ~= "table" then
		page = {}
		data.attractions[id] = page
	end
	return page
end

local function teleport(player: Player, cf: CFrame): boolean
	local character = player.Character
	if not character or not rootOf(player) then
		return false
	end
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 4)
	end)
	if player.Character ~= character then
		return false
	end
	Integrity.teleport(player, character, cf + Vector3.new(0, 3, 0))
	return true
end

-- Where a guest comes back to: just inside the attraction's room, facing into it.
local function lobbyFrame(id: string): CFrame
	local def = AttractionList.byId[id]
	local room = def and (Layout :: any)[string.upper(string.sub(def.room, 1, 1)) .. string.sub(def.room, 2)]
	-- (A room may say where a guest comes home to from its attraction: the Ballroom's great doors.)
	local home = room and def and room[def.id .. "Home"]
	if typeof(home) == "Vector3" then
		local centre = if typeof(room.centre) == "Vector3" then room.centre else home
		return CFrame.lookAt(home, Vector3.new(centre.X, home.Y, centre.Z))
	end
	local at: Vector3 = if room and typeof(room.arrival) == "Vector3" then room.arrival else Layout.Foyer.spawn.Position
	local door = def and (Layout.RoomDoors :: any)[def.room]
	local inward = if door then -door.facing else Vector3.new(0, 0, 1)
	return CFrame.lookAt(at, at + inward * 10)
end

local function setSpeed(player: Player, multiplier: number?)
	if multiplier == nil or math.abs(multiplier - 1) < 1e-3 then
		player:SetAttribute("SpeedTrained", nil)
	else
		player:SetAttribute("SpeedTrained", math.floor(multiplier * 1000 + 0.5) / 1000)
	end
end

-- Lets a held guest move (their root unanchored, and their screen told).
local function unhold(player: Player)
	local h = held[player]
	if not h then
		return
	end
	held[player] = nil
	local root = h.root
	if root then
		pcall(function()
			root.Anchored = false
		end)
	end
	if player.Parent then
		event:FireClient(player, { op = "unheld" })
	end
end

-- Lets go of a guest who was in an attraction (`why`: home, respawn, quit, away).
local function release(player: Player, why: string)
	local id = inside[player]
	if not id then
		return
	end
	inside[player] = nil
	arrived[player] = nil
	awaySince[player] = nil
	unhold(player)
	local g = GAMES[id]
	if g then
		local ok, err = pcall(g.leave :: any, Attractions.ctx, player, why)
		if not ok then
			warn("[Maison] Leaving " .. id .. " stumbled: " .. tostring(err))
		end
	end
	setSpeed(player, nil)
	if player.Parent then
		player:SetAttribute(AttractionList.ATTRIBUTE, nil)
		event:FireClient(player, { op = "left", id = id, why = why })
	end
end

local function sendHome(player: Player, id: string)
	release(player, "home")
	teleport(player, lobbyFrame(id))
end

-- Pays a price from a guest's purse: Gilt and/or Gems, all of it or none of it.
local function spend(player: Player, gilt: number, gemPrice: number, sink: string): boolean
	local data = Profiles.get(player)
	if not data then
		return false
	end
	local d = data :: any
	gilt, gemPrice = math.max(0, math.floor(gilt)), math.max(0, math.floor(gemPrice))
	if (d.gilt or 0) < gilt or (d.gems or 0) < gemPrice then
		return false
	end
	if gilt > 0 then
		d.gilt -= gilt
		Analytics.sink(player, "Gilt", gilt, d.gilt, sink)
		Gilt.changed(player)
	end
	if gemPrice > 0 then
		d.gems -= gemPrice
		player:SetAttribute("Gems", d.gems)
		Analytics.sink(player, "Gems", gemPrice, d.gems, sink)
		Curios.push(player)
	end
	Fortune.sync(player)
	return true
end

local ctx: Types.Ctx = {
	cfg = cfg,
	rng = rng,
	folder = holder,
	rootOf = rootOf,
	trusted = function(player: Player): boolean
		return Integrity.trusted(player)
	end,
	moved = function(player: Player)
		Integrity.moved(player)
	end,
	teleport = teleport,
	sendHome = sendHome,
	inside = function(player: Player): string?
		return inside[player]
	end,
	at = function(player: Player, id: string): Vector3?
		local root = rootOf(player)
		if not root then
			return nil
		end
		local p = root.CFrame.Position
		if AttractionList.areaAt(p) ~= id then
			return nil
		end
		return p - AttractionList.origin(id)
	end,
	data = function(player: Player): any?
		return Profiles.get(player)
	end,
	saved = saved,
	estate = function(player: Player, worth: number, source: string, cash: boolean?): number
		return Fortune.estate(player, worth, source, cash)
	end,
	gilt = function(player: Player, amount: number, source: string): number
		local data = Profiles.get(player)
		if not data or amount <= 0 then
			return 0
		end
		return Gilt.pay(player, data, math.floor(amount), source)
	end,
	-- A prize paid in full, outside the day's soft cap: only for what's limited by design (once a
	-- day, or once an invitation), never for what can be repeated at will.
	prize = function(player: Player, amount: number, source: string): number
		local data = Profiles.get(player)
		if not data or amount <= 0 then
			return 0
		end
		return Gilt.give(player, data, math.floor(amount), source)
	end,
	spend = spend,
	curio = function(player: Player, id: string, source: string): boolean
		local data = Profiles.get(player)
		if not data then
			return false
		end
		local ok = Curios.give(player, data, id, 1, source)
		if ok then
			Curios.push(player)
		end
		return ok
	end,
	herald = function(player: Player, feat: Types.Feat): boolean
		return Herald.feat(player, feat)
	end,
	send = function(player: Player, message: { [string]: any })
		event:FireClient(player, message)
	end,
	broadcast = function(message: { [string]: any })
		event:FireAllClients(message)
	end,
	notice = function(player: Player, title: string, line: string)
		event:FireClient(player, { op = "notice", title = title, line = line })
	end,
	tally = function(player: Player, stat: string, n: number, once: string?)
		Attractions.tally(player, stat, n, once)
	end,
	award = function(player: Player, key: string)
		Attractions.award(player, key)
	end,
	progress = function(player: Player, kind: string, n: number)
		Attractions.progress(player, kind, n)
	end,
	setSpeed = setSpeed,
	isOwner = function(player: Player): boolean
		return Attractions.isOwner(player)
	end,
	fortune = function(player: Player)
		Fortune.sync(player)
	end,
}
Attractions.ctx = ctx

-- Invitations to the Executive Suite, earned in the others: the Maison Basement cleared, a great
-- haul banked in Steal a Luxe.
Basement.cleared = function(player: Player)
	ExecutiveGame.invite(ctx, player, "basement")
end
Luxe.banked = function(player: Player, worth: number)
	if worth >= (tonumber(cfg("executive").inviteHaul) or 8000) then
		ExecutiveGame.invite(ctx, player, "haul")
	end
end

-- An invitation from the owner (House controls).
function Attractions.invite(player: Player): boolean
	return ExecutiveGame.invite(ctx, player, "owner")
end

---------------------------------------------------------------------------------------------------
-- In and out
---------------------------------------------------------------------------------------------------

-- Whether a guest stands in an attraction's room off the Foyer (where its entrance is).
local function inLobby(player: Player, id: string): boolean
	local def = AttractionList.byId[id]
	local root = rootOf(player)
	return def ~= nil and root ~= nil and Layout.zoneAt(root.CFrame.Position) == def.room
end

-- Whether this is a guest's first look at one of the house's guide cards (shared/Directory: an
-- attraction's, the Grand Auction's, the Vault's), and a note that it's been shown: once, ever, in
-- their record's one-time flags. Nothing is paid for it.
local function firstLook(data: any, what: string): boolean
	if type(data) ~= "table" then
		return false
	end
	if type(data.flags) ~= "table" then
		data.flags = {}
	end
	local key = "guide_" .. what
	if data.flags[key] == true then
		return false
	end
	data.flags[key] = true
	return true
end
Attractions.firstLook = firstLook
-- (For tests: who is held on arrival.)
Attractions.held = held

-- Takes a guest into an attraction. Returns { ok, why }.
function Attractions.go(player: Player, id: string): { [string]: any }
	local g = GAMES[id]
	local def = AttractionList.byId[id]
	if not g or not def then
		return { ok = false, why = "There's no such place." }
	end
	if inside[player] then
		return { ok = false, why = "You're already in " .. (AttractionList.byId[inside[player]] or def).name .. "." }
	end
	if Attractions.isSeated(player) then
		return { ok = false, why = "Leave your table first." }
	end
	if not Profiles.get(player) then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	if not inLobby(player, id) then
		return { ok = false, why = "Its entrance is in " .. def.roomName .. ", off the Foyer." }
	end
	local now = os.clock()
	if (lastTravel[player] or -math.huge) + (tonumber((Config.data :: any).Attractions.travelGap) or 2) > now then
		return { ok = false, why = "One moment." }
	end
	local at, why = g.enter(ctx, player)
	if not at then
		return { ok = false, why = why or "Not just now." }
	end
	lastTravel[player] = now
	inside[player] = id
	local frame = (at :: CFrame) + AttractionList.origin(id)
	arrived[player] = { at = now, frame = frame, again = false }
	awaySince[player] = nil
	player:SetAttribute(AttractionList.ATTRIBUTE, id)
	if not teleport(player, frame) then
		release(player, "away")
		return { ok = false, why = "Not just now." }
	end
	Analytics.custom(player, "Attraction entered", 1, { attraction = id })
	-- (Build 82) The tuned attractions: held still on arrival while the place is made ready (their
	-- root anchored here, so nobody walks off a floor that isn't there yet on their screen).
	local hold: number? = nil
	local movement = (Config.data :: any).Movement
	if type(movement.tuned) == "table" and movement.tuned[id] == true then
		local c = (Config.data :: any).Attractions
		local least = tonumber(c.loadIn) or 6.5
		local root = rootOf(player)
		if root then
			root.Anchored = true
		end
		held[player] = { from = now, least = now + least, most = now + math.max(least, tonumber(c.loadInMost) or 15), ready = false, root = root }
		hold = least
	end
	-- (The first time ever: their screen shows how it works, once.)
	event:FireClient(player, { op = "entered", id = id, first = firstLook(Profiles.get(player), id), hold = hold })
	return { ok = true }
end

-- Takes a guest home from the attraction they're in (to its room off the Foyer).
function Attractions.home(player: Player): { [string]: any }
	local id = inside[player]
	if not id then
		return { ok = false, why = "You're in the Maison." }
	end
	local now = os.clock()
	if (lastTravel[player] or -math.huge) + (tonumber((Config.data :: any).Attractions.travelGap) or 2) > now then
		return { ok = false, why = "One moment." }
	end
	lastTravel[player] = now
	sendHome(player, id)
	return { ok = true }
end

function Attractions.inside(player: Player): string?
	return inside[player]
end

-- The Maison Directory's cards (UI/DirectoryPanel): for each attraction, whether it's open to this
-- guest, the house's own figures for its words, and how far they've come in it (each attraction's
-- own `directory`, else whether it's `locked`); which one they're in, and which one's way in is in
-- the room they stand in (that one can be gone into from the card at once). Only what the server
-- sees: nothing a screen says opens a door.
function Attractions.directory(player: Player): { [string]: any }
	if not Profiles.get(player) then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local cards: { [string]: any } = {}
	for id, g in GAMES do
		local card: { [string]: any } = { open = true }
		if g.directory then
			local ok, got = pcall(g.directory :: any, ctx, player)
			if ok and type(got) == "table" then
				for k, v in got do
					card[k] = v
				end
			end
		elseif g.locked then
			local ok, shut = pcall(g.locked :: any, ctx, player)
			card.open = not (ok and shut == true)
		end
		card.open = card.open == true
		cards[id] = card
	end
	local here: string? = nil
	local root = rootOf(player)
	if root then
		local zone = Layout.zoneAt(root.CFrame.Position)
		local def = if zone then AttractionList.byRoom[zone] else nil
		here = if def then def.id else nil
	end
	return { ok = true, cards = cards, inside = inside[player], here = here, seated = Attractions.isSeated(player) }
end

---------------------------------------------------------------------------------------------------
-- Requests from a guest's screen
---------------------------------------------------------------------------------------------------
-- (`item`, `set` and `line`: the Flex Studio's picks, a guest's own thing, a set, a caption.)
local ASK_KEYS = { op = true, id = true, act = true, what = true, n = true, code = true, item = true, set = true, line = true }

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 8, 0)
	if not r then
		RemoteGuard.reject(player, "attractionAsk", "malformed")
		return { ok = false, why = "That isn't something the house does." }
	end
	for k in r do
		if not ASK_KEYS[k] then
			RemoteGuard.reject(player, "attractionAsk", "malformed")
			return { ok = false, why = "That isn't something the house does." }
		end
	end
	local op = r.op
	local id = if type(r.id) == "string" and GAMES[r.id :: string] then r.id :: string else nil
	if op == "go" then
		if not id then
			return { ok = false, why = "There's no such place." }
		end
		return Attractions.go(player, id)
	elseif op == "home" then
		return Attractions.home(player)
	elseif op == "ready" then
		-- (Their screen has the place ready: let go once the least wait is over.)
		local h = held[player]
		if h then
			h.ready = true
		end
		return { ok = true }
	elseif op == "state" then
		local which = id or inside[player]
		local g = which and GAMES[which]
		local s: { [string]: any } = { ok = true, inside = inside[player] }
		if g and g.state then
			for k, v in g.state(ctx, player) do
				s[k] = v
			end
		end
		return s
	elseif op == "directory" then
		return Attractions.directory(player)
	elseif op == "guide" then
		-- (A room's or the Grand Auction's guide card, the first time a guest is there.)
		local what = r.what
		if type(what) ~= "string" or #what > 24 or not Directory.isGuide(what) then
			return { ok = false, why = "That isn't something the house does." }
		end
		local data = Profiles.get(player)
		if not data then
			return { ok = false, why = "Your ledger is still being opened." }
		end
		return { ok = true, first = firstLook(data, what) }
	elseif op == "act" then
		local g = id and GAMES[id]
		if not g or not g.ask then
			return { ok = false, why = "That isn't something the house does." }
		end
		return g.ask(ctx, player, r)
	end
	return { ok = false, why = "That isn't something the house does." }
end

---------------------------------------------------------------------------------------------------
-- Walk-through ways in
---------------------------------------------------------------------------------------------------
-- Every entrance's glowing arch has an entry zone just in front of it (World/Lobbies, tagged
-- AttractionPortal). Walking into an open one takes a guest in, on any device: once per walk-in
-- (the zone must be left before it can take them again; the usual travel gap stands too). A
-- locked one shows what opens it, once per walk-in. The zone stands inside the attraction's own
-- room and Attractions.go checks the room as well, so nothing reaches it through a wall. The
-- arch's prompt (E, or a tap) still works the same.
local portals: { BasePart } = {}
local inZone: { [Player]: BasePart } = {}

local function within(part: BasePart, at: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(at)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

local function addPortal(z: Instance)
	if z:IsA("BasePart") and type(z:GetAttribute("Attraction")) == "string" and not table.find(portals, z) then
		table.insert(portals, z)
	end
end

-- The way in, walked into: in (true), or not (and the guest has been told why, when it's worth
-- saying). Returns false without a word only for a moment's wait (the zone tries again).
local function walkedIn(player: Player, id: string): boolean
	local g = GAMES[id]
	if g and g.locked and g.locked(ctx, player) then
		event:FireClient(player, { op = "panel", id = id })
		return true
	end
	local result = Attractions.go(player, id)
	if result.ok == true then
		return true
	end
	if result.why == "One moment." then
		return false
	end
	if type(result.why) == "string" then
		event:FireClient(player, { op = "notice", title = "Not just now", line = result.why })
	end
	return true
end

function Attractions.portals()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local hit: BasePart? = nil
		if root and not inside[player] then
			local at = root.CFrame.Position
			for _, z in portals do
				if z.Parent and within(z, at) then
					hit = z
					break
				end
			end
		end
		if hit == nil then
			inZone[player] = nil
		elseif inZone[player] ~= hit then
			local id = hit:GetAttribute("Attraction") :: string
			if walkedIn(player, id) then
				inZone[player] = hit
			end
		end
	end
	for player in inZone do
		if player.Parent == nil then
			inZone[player] = nil
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------------------------------

-- One beat of every attraction: guests who have left one (any way at all) are let go of first.
function Attractions.step(dt: number)
	local okPortals, whyPortals = pcall(Attractions.portals :: any)
	if not okPortals then
		warn("[Maison] A way in stumbled: " .. tostring(whyPortals))
	end
	local now = os.clock()
	for player, h in held do
		if player.Parent == nil or not inside[player] then
			unhold(player)
		elseif (h.ready and now >= h.least) or now >= h.most then
			unhold(player)
		end
	end
	for player, id in inside do
		local root = rootOf(player)
		if player.Parent == nil then
			release(player, "quit")
		elseif root and AttractionList.areaAt(root.CFrame.Position) ~= id then
			local came = arrived[player]
			if came and now - came.at < ARRIVAL_GRACE then
				-- (Still being seen where they were: put them in once more, once.)
				if not came.again and now - came.at > 1 then
					came.again = true
					teleport(player, came.frame)
				end
			else
				local since = awaySince[player] or now
				awaySince[player] = since
				if now - since >= AWAY_SECONDS then
					release(player, "away")
				end
			end
		else
			awaySince[player] = nil
		end
	end
	for id, g in GAMES do
		local ok, err = pcall(g.step :: any, ctx, dt)
		if not ok then
			warn("[Maison] " .. id .. " stumbled: " .. tostring(err))
		end
	end
end

-- Connects a prompt the builders tagged: an attraction's entrance in its room, or a way home.
local function hookPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local id = prompt:GetAttribute("Attraction")
	local kind = prompt:GetAttribute("Kind")
	if type(id) ~= "string" then
		return
	end
	(prompt :: ProximityPrompt).Triggered:Connect(function(player: Player)
		if kind == "panel" then
			event:FireClient(player, { op = "panel", id = id, which = prompt:GetAttribute("Panel") })
			return
		elseif kind == "act" then
			-- (Something done on the spot: the attraction decides, and says so.)
			local game_ = GAMES[id]
			if game_ and game_.ask then
				local ok, r = pcall(game_.ask :: any, ctx, player, { op = "act", id = id, act = prompt:GetAttribute("Act"), what = prompt:GetAttribute("What") })
				if ok and type(r) == "table" then
					if r.ok == true and type(r.title) == "string" then
						event:FireClient(player, { op = "notice", title = r.title, line = tostring(r.line or "") })
					elseif r.ok ~= true and type(r.why) == "string" then
						event:FireClient(player, { op = "notice", title = "Not just now", line = r.why })
					end
				end
			end
			return
		end
		local g = GAMES[id]
		if kind ~= "home" and g and g.locked and g.locked(ctx, player) and not inside[player] then
			event:FireClient(player, { op = "panel", id = id })
			return
		end
		local result = if kind == "home" then Attractions.home(player) else Attractions.go(player, id)
		if result.ok ~= true and type(result.why) == "string" then
			event:FireClient(player, { op = "notice", title = "Not just now", line = result.why })
		end
	end)
end

-- (Build 82) Invisible walls round the edge of each tuned attraction's place (its BOUNDS), so
-- nobody walks or jumps out of it into the night: the ways out are its arches and its lifts.
local function bounds(parent: Instance)
	local movement = (Config.data :: any).Movement
	local tuned = if type(movement.tuned) == "table" then movement.tuned else {}
	for id in tuned do
		local b = AttractionList.BOUNDS[id]
		if b and GAMES[id] then
			local m = Instance.new("Model")
			m.Name = "Bounds_" .. id
			local o = AttractionList.origin(id)
			local lo, hi = o + b.min, o + b.max
			local mid = (lo + hi) / 2
			local size = hi - lo
			local function wall(name: string, at: Vector3, s: Vector3)
				local p = Instance.new("Part")
				p.Name = name
				p.Anchored = true
				p.CanCollide = true
				p.CanQuery = false
				p.CanTouch = false
				p.Transparency = 1
				p.CastShadow = false
				p.Size = s
				p.CFrame = CFrame.new(at)
				p.Parent = m
			end
			wall("West", Vector3.new(lo.X - 1, mid.Y, mid.Z), Vector3.new(2, size.Y, size.Z + 4))
			wall("East", Vector3.new(hi.X + 1, mid.Y, mid.Z), Vector3.new(2, size.Y, size.Z + 4))
			wall("South", Vector3.new(mid.X, mid.Y, lo.Z - 1), Vector3.new(size.X + 4, size.Y, 2))
			wall("North", Vector3.new(mid.X, mid.Y, hi.Z + 1), Vector3.new(size.X + 4, size.Y, 2))
			wall("Ceiling", Vector3.new(mid.X, hi.Y + 1, mid.Z), Vector3.new(size.X + 4, 2, size.Z + 4))
			m.Parent = parent
		end
	end
end

function Attractions.start()
	local parent = holder()
	for id, g in GAMES do
		local ok, err = pcall(g.build :: any, ctx, parent)
		if not ok then
			warn("[Maison] Building " .. id .. " failed: " .. tostring(err))
		end
	end
	local okBounds, whyBounds = pcall(bounds :: any, parent)
	if not okBounds then
		warn("[Maison] The attractions' edges couldn't be built: " .. tostring(whyBounds))
	end
	for _, prompt in CollectionService:GetTagged("AttractionPrompt") do
		hookPrompt(prompt)
	end
	CollectionService:GetInstanceAddedSignal("AttractionPrompt"):Connect(hookPrompt)
	for _, z in CollectionService:GetTagged("AttractionPortal") do
		addPortal(z)
	end
	CollectionService:GetInstanceAddedSignal("AttractionPortal"):Connect(addPortal)
	RemoteGuard.invoke(Remotes.func("AttractionAsk"), "attractionAsk", onAsk)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			release(player, "respawn")
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player: Player)
		release(player, "quit")
		held[player] = nil
		lastTravel[player] = nil
		arrived[player] = nil
		awaySince[player] = nil
		for _, g in GAMES do
			pcall(g.leave :: any, ctx, player, "gone")
		end
	end)
	Profiles.Loaded:Connect(function(player: Player)
		for _, g in GAMES do
			if g.arrived then
				pcall(g.arrived :: any, ctx, player)
			end
		end
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			local ok, err = pcall(Attractions.step :: any, dt)
			if not ok then
				warn("[Maison] The attractions stumbled: " .. tostring(err))
			end
		end
	end)
end

-- For tests.
Attractions.GAMES = GAMES
Attractions.release = release
Attractions.lobbyFrame = lobbyFrame

return Attractions

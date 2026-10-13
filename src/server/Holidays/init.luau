--!strict
-- The holiday games on the server (shared/HolidayGames says what they are; World/HolidayGames
-- draws them on every screen). This opens the holiday's game when its days come (or when its
-- holiday event is on), builds its place away from the Maison and takes it down after, takes
-- guests there and home, and pays what they find. The games themselves: Lane (trick or treat),
-- Field (the turkeys), Pole (Santa's sleigh and the gifts) and Eggs (the Great Egg Hunt); St
-- Patrick's luck is only odds (`mythicLuck`, `curioLuck`).
--
-- Every reward is decided here, from what the server sees: where a guest's character stands, what
-- this module put in the world, and the guest's saved record. Nothing a screen says is a reward,
-- a price, an amount or a place. Each guest gets at most Config.HolidayGames.gemsPerDay Gems a
-- day from all of them together; Gilt goes through Gilt.pay (its boosts and its daily soft cap).
-- A character that moves faster than anyone can (a teleport the server didn't make) finds nothing
-- for a few seconds. And every game has its own limits (a door once a round, a catch a second,
-- so many gifts a trip and a day).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local HolidayGames = require(ReplicatedStorage.Shared.HolidayGames)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Curios = require(script.Parent.Curios)
local Gilt = require(script.Parent.Gilt)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Catalog = require(script.Parent.Purchases.Catalog)
local HolidayGrant = require(script.Parent.Purchases.HolidayGrant)
local Store = require(script.Parent.Purchases.Store)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Integrity = require(script.Parent.Integrity)

local Types = require(script.Types)
local Lane = require(script.Lane)
local Field = require(script.Field)
local Pole = require(script.Pole)
local Eggs = require(script.Eggs)

local Holidays = {}

---------------------------------------------------------------------------------------------------
-- Hooks (set by Main)
---------------------------------------------------------------------------------------------------
-- Whether a house event (the holiday's own) is on now: AdminService.active.
Holidays.eventOn = function(_id: string): boolean
	return false
end
-- Whether a guest is busy at a table (the Salon, a duel, the Ballroom).
Holidays.isSeated = function(_player: Player): boolean
	return false
end
-- A badge (Achievements.award) and a count for the Badge Book and XP (AdminService.tally).
Holidays.award = function(_player: Player, _key: string) end
Holidays.tally = function(_player: Player, _stat: string, _n: number, _once: string?) end
-- What day it is by the calendar (a test sets it).
Holidays.calendar = function(): string?
	return HolidayGames.byCalendar()
end

local function cfg(): Types.Cfg
	return Config.data.HolidayGames :: any
end

local GAMES: { [string]: Types.Game } = {
	halloween = Lane :: any,
	thanksgiving = Field :: any,
	christmas = Pole :: any,
	easter = Eggs :: any,
}

local holidayEvent = Remotes.event("Holiday")
local current: string? = nil -- the game open now
local folder: Folder? = nil
local rng = Random.new()

---------------------------------------------------------------------------------------------------
-- Guests: where they are, and how fast they've moved
---------------------------------------------------------------------------------------------------
-- (How each guest moves is watched by the house itself: server/Integrity. A guest who moved as
-- nobody can is put back, and finds nothing for a moment.)
local lastTravel: { [Player]: number } = {}

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- The server moved this guest (a trip, a ride): their next step isn't a teleport of their own.
local function moved(player: Player)
	Integrity.moved(player)
end

-- Whether a guest may find things now (not just after a jump nobody could make).
local function trusted(player: Player): boolean
	return Integrity.trusted(player)
end

---------------------------------------------------------------------------------------------------
-- What a guest keeps (their saved record's holiday page)
---------------------------------------------------------------------------------------------------
local function today(): number
	return math.floor(os.time() / 86400)
end

-- The year by the calendar (UTC): a holiday pass lasts its holiday, this year.
local function year(): number
	return tonumber(os.date("!%Y")) or 0
end

local function saved(data: Profiles.Data): Types.Saved
	local d = data :: any
	if type(d.holiday) ~= "table" then
		d.holiday = {}
	end
	local h = d.holiday
	h.day = if type(h.day) == "number" then h.day else -1
	h.gems = if type(h.gems) == "number" then h.gems else 0
	h.gifts = if type(h.gifts) == "number" then math.max(0, math.floor(h.gifts)) else 0
	h.loaded = if type(h.loaded) == "number" then h.loaded else 0
	h.round = if type(h.round) == "number" then h.round else -1
	h.doors = if type(h.doors) == "table" then h.doors else {}
	h.trips = if type(h.trips) == "number" then h.trips else 0
	-- What's been bought (and the free sleigh rides taken this year).
	local function count(v: any): number
		return if type(v) == "number" and v == v then math.max(0, math.floor(v)) else 0
	end
	h.catches = count(h.catches)
	h.hunterYear = count(h.hunterYear)
	h.rides = count(h.rides)
	h.seasonYear = count(h.seasonYear)
	h.rideYear = count(h.rideYear)
	h.freeTaken = count(h.freeTaken)
	if h.rideYear ~= year() then
		h.rideYear = year()
		h.freeTaken = 0
	end
	if h.day ~= today() then
		h.day = today()
		h.gems = 0
		h.loaded = 0
	end
	return h :: Types.Saved
end

---------------------------------------------------------------------------------------------------
-- The context every game works through
---------------------------------------------------------------------------------------------------
local ctx: Types.Ctx

local function send(player: Player, message: { [string]: any })
	holidayEvent:FireClient(player, message)
end

local function broadcast(message: { [string]: any })
	holidayEvent:FireAllClients(message)
end

-- Pays a guest for something found in a holiday game: Gilt through Gilt.pay, Gems up to the day's
-- ceiling. Returns what was paid (Gilt, Gems).
local function reward(player: Player, gilt: number, gems: number, source: string): (number, number)
	local data = Profiles.get(player)
	if not data then
		return 0, 0
	end
	local paid = if gilt > 0 then Gilt.pay(player, data, math.floor(gilt), source) else 0
	local given = 0
	if gems > 0 then
		local h = saved(data)
		given = math.max(0, math.min(math.floor(gems), cfg().gemsPerDay - h.gems))
		if given > 0 then
			local d = data :: any
			h.gems += given
			d.gems = (if type(d.gems) == "number" then d.gems else 0) + given
			Analytics.source(player, "Gems", given, d.gems, source)
			Curios.push(player)
		end
	end
	Holidays.tally(player, "pickups", 1)
	return paid, given
end

-- Gems for today are all given: what's left of them, for the screens that say so.
local function gemsLeft(player: Player): number
	local data = Profiles.get(player)
	if not data then
		return 0
	end
	return math.max(0, cfg().gemsPerDay - saved(data).gems)
end

local function teleport(player: Player, cf: CFrame): boolean
	local character = player.Character
	local root = rootOf(player)
	if not character or not root then
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

-- Back to the Maison: on the pavement before its steps, facing the door.
local function homeFrame(spread: number?): CFrame
	local at = Layout.Street.spawn.Position + Vector3.new((spread or 0) * 3.2, 0, 0)
	return CFrame.lookAt(at, at + Vector3.new(0, 0, 1))
end

local function sendHome(player: Player, spread: number?)
	teleport(player, homeFrame(spread))
	player:SetAttribute("HolidayArea", nil)
end

local function inArea(player: Player, area: string): boolean
	local root = rootOf(player)
	return root ~= nil and HolidayGames.areaAt(root.CFrame.Position) == area
end

local function holder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "HolidayGames"
	nf.Parent = Workspace
	folder = nf
	return nf
end

ctx = {
	cfg = cfg,
	rng = rng,
	folder = holder,
	rootOf = rootOf,
	trusted = trusted,
	moved = moved,
	saved = saved,
	reward = reward,
	gemsLeft = gemsLeft,
	send = send,
	broadcast = broadcast,
	teleport = teleport,
	sendHome = sendHome,
	inArea = inArea,
	isSeated = function(player: Player): boolean
		return Holidays.isSeated(player)
	end,
	award = function(player: Player, key: string)
		Holidays.award(player, key)
	end,
	tally = function(player: Player, stat: string, n: number, once: string?)
		Holidays.tally(player, stat, n, once)
	end,
	curio = function(player: Player, id: string, key: string): boolean
		return Curios.forEvent(player, id, key)
	end,
	salute = function(title: string, line: string, by: Player?)
		Remotes.event("Salute"):FireAllClients({ op = "salute", id = "holidayGame", by = if by then Names.of(by) else "", effects = { "fireworks" }, seconds = 7, title = title, line = line })
	end,
	price = function(key: string): number?
		local ok, p = pcall(Catalog.price, key)
		return if ok and type(p) == "number" then p else nil
	end,
	year = year,
}

---------------------------------------------------------------------------------------------------
-- Open and close
---------------------------------------------------------------------------------------------------

-- The game that should be open now: the holiday whose event is on, else the calendar's.
local function wanted(): string?
	for _, g in HolidayGames.List do
		if Holidays.eventOn(g.id) then
			return g.id
		end
	end
	return Holidays.calendar()
end

local function close(id: string)
	local g = GAMES[id]
	Workspace:SetAttribute(HolidayGames.ATTRIBUTE, nil)
	current = nil
	if g then
		local ok, err = pcall(g.close :: any, ctx)
		if not ok then
			warn("[Maison] Closing the holiday game failed: " .. tostring(err))
		end
	end
	-- Anyone still in a holiday place comes home.
	local def = HolidayGames.byId[id]
	if def and def.area then
		local k = 0
		for _, player in Players:GetPlayers() do
			if inArea(player, def.area) then
				k += 1
				sendHome(player, k % 5 - 2)
			end
			player:SetAttribute("HolidayArea", nil)
		end
	end
	broadcast({ op = "closed", game = id })
end

local function open(id: string)
	current = id
	local g = GAMES[id]
	if g then
		local ok, err = pcall(g.open :: any, ctx)
		if not ok then
			warn("[Maison] Opening the holiday game failed: " .. tostring(err))
		end
	end
	Workspace:SetAttribute(HolidayGames.ATTRIBUTE, id)
	broadcast({ op = "opened", game = id })
end

-- Opens the game that should be open (and closes another). Called on a timer and whenever a
-- house event starts or stops.
function Holidays.refresh()
	local want = wanted()
	if want == current then
		return
	end
	local was = current
	if was then
		close(was)
	end
	if want then
		open(want)
	end
end

function Holidays.open(): string?
	return current
end

function Holidays.isOpen(id: string): boolean
	return current == id
end

-- Whether the holiday game runs a holiday's hunt itself (the eggs, the turkeys): the house event's
-- own pickups then stay away.
function Holidays.ownsHunt(id: string): boolean
	return id == "easter" or id == "thanksgiving"
end

-- St Patrick's: Mythics likelier at the tables.
function Holidays.mythicLuck(): number
	return if current == "stPatrick" then math.max(1, cfg().luck.mythic) else 1
end

-- St Patrick's: curios found more often, the rarer ones likelier.
function Holidays.curioLuck(): (number, number)
	if current == "stPatrick" then
		return math.max(1, cfg().luck.curioFind), math.max(1, cfg().luck.curioRare)
	end
	return 1, 1
end

---------------------------------------------------------------------------------------------------
-- What guests ask
---------------------------------------------------------------------------------------------------
local ASK_KEYS = { op = true, n = true }

-- Which holiday products may be asked for now, and why not: the turkeys' only while the field is
-- open (and not already unlimited), the sleigh's only at Christmas.
local function buyable(player: Player, key: string): (boolean, string?)
	local data = Profiles.get(player)
	if not data then
		return false, "Your ledger is still being opened."
	end
	local h = saved(data)
	if key == "turkeyMore" or key == "turkeyHunter" then
		if current ~= "thanksgiving" then
			return false, "The turkeys are out at Thanksgiving."
		end
		if h.hunterYear == year() then
			return false, "Your Turkey Hunter Pass already catches as many as you like."
		end
	elseif key == "sleighRide" or key == "sleighSeason" then
		if current ~= "christmas" then
			return false, "Santa's sleigh comes at Christmas."
		end
		if h.seasonYear == year() then
			return false, "Your Season Pass already rides free."
		end
	end
	return true, nil
end

local function buy(player: Player, n: number): { [string]: any }
	local key = ProductConfig.Holiday[n]
	if not key then
		return { ok = false, why = "That isn't sold here." }
	end
	local fine, why = buyable(player, key)
	if not fine then
		return { ok = false, why = why }
	end
	local sell = Store.sellable(key)
	if not sell then
		return { ok = false, why = "That isn't on sale yet." }
	end
	local ok, reason = Store.prompt(player, sell, "holiday")
	return { ok = ok, why = reason, prompted = ok }
end

-- The holiday products' prices now, for the offer on a guest's screen (Roblox's own, or the
-- catalog's reference price until Roblox says).
local function prices(): { [string]: number }
	local out = {}
	for _, key in ProductConfig.Holiday do
		local live = ctx.price(key)
		local e = ProductConfig.byKey[key]
		out[key] = live or (if e then e.Pricing.ReferencePrice else 0)
	end
	return out
end

-- Takes a guest to the open game's place (the Lane, the Field, or the kerb by Santa's sleigh).
local function go(player: Player): { [string]: any }
	local id = current
	local def = id and HolidayGames.byId[id]
	if not id or not def then
		return { ok = false, why = "No holiday game is on just now." }
	end
	if Holidays.isSeated(player) then
		return { ok = false, why = "Leave your table first." }
	end
	local now = os.clock()
	if (lastTravel[player] or -math.huge) + cfg().travelGap > now then
		return { ok = false, why = "One moment." }
	end
	local g = GAMES[id]
	if not g or not g.arrival then
		return { ok = false, why = "That one is here in the house." }
	end
	local at = g.arrival(ctx, player)
	if not at then
		return { ok = false, why = "Not just now." }
	end
	lastTravel[player] = now
	if not teleport(player, at) then
		return { ok = false, why = "Not just now." }
	end
	player:SetAttribute("HolidayArea", def.area)
	return { ok = true }
end

local function home(player: Player): { [string]: any }
	local root = rootOf(player)
	if not root or HolidayGames.areaAt(root.CFrame.Position) == nil then
		return { ok = false, why = "You're at the Maison." }
	end
	local now = os.clock()
	if (lastTravel[player] or -math.huge) + cfg().travelGap > now then
		return { ok = false, why = "One moment." }
	end
	local id = current
	local g = id and GAMES[id]
	if g and g.leaving and not g.leaving(ctx, player) then
		return { ok = false, why = "Not while the sleigh is in the air." }
	end
	lastTravel[player] = now
	sendHome(player)
	return { ok = true }
end

local function state(player: Player): { [string]: any }
	local data = Profiles.get(player)
	local s: { [string]: any } = { ok = true, game = current, gemsLeft = gemsLeft(player), prices = prices() }
	if data then
		local h = saved(data)
		s.gifts = h.gifts
	end
	local id = current
	local g = id and GAMES[id]
	if g and g.state then
		for k, v in g.state(ctx, player) do
			s[k] = v
		end
	end
	return s
end

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 4, 0)
	if not r then
		RemoteGuard.reject(player, "holidayAsk", "malformed")
		return { ok = false, why = "That isn't something the house does." }
	end
	for k in r do
		if not ASK_KEYS[k] then
			RemoteGuard.reject(player, "holidayAsk", "malformed")
			return { ok = false, why = "That isn't something the house does." }
		end
	end
	local op = r.op
	if op == "state" then
		return state(player)
	elseif op == "go" then
		return go(player)
	elseif op == "home" then
		return home(player)
	elseif op == "board" then
		if current ~= "christmas" then
			return { ok = false, why = "Santa's sleigh comes at Christmas." }
		end
		return Pole.board(ctx, player)
	elseif op == "open" then
		-- Opening gifts from the North Pole: they keep after Christmas, until they're opened.
		local n = RemoteGuard.number(r.n, 1, 10, true) or 1
		return Pole.openGifts(ctx, player, n)
	elseif op == "buy" then
		local n = RemoteGuard.number(r.n, 1, #ProductConfig.Holiday, true)
		if not n then
			return { ok = false, why = "That isn't sold here." }
		end
		return buy(player, n)
	end
	return { ok = false, why = "That isn't something the house does." }
end

---------------------------------------------------------------------------------------------------
-- Start
---------------------------------------------------------------------------------------------------

-- One beat of every game (ten a second): the turkeys run, the gifts are picked up, the sleigh
-- keeps its time.
function Holidays.step(dt: number)
	local id = current
	local g = id and GAMES[id]
	if g and g.step then
		g.step(ctx, dt)
	end
end

function Holidays.start()
	Integrity.start()
	-- A holiday product bought (Purchases/HolidayGrant wrote it down): the game is told at once.
	HolidayGrant.after = function(player: Player, key: string)
		send(player, { op = "bought", key = key })
		if key == "turkeyMore" or key == "turkeyHunter" then
			Field.bought(ctx, player)
		else
			Pole.bought(ctx, player)
		end
	end
	for _, key in ProductConfig.Holiday do
		Store.eligibility[key] = function(player: Player): (boolean, string?)
			return buyable(player, key)
		end
	end
	RemoteGuard.invoke(Remotes.func("HolidayAsk"), "holidayAsk", onAsk)
	Players.PlayerRemoving:Connect(function(player)
		local id = current
		local g = id and GAMES[id]
		if g and g.leave then
			pcall(g.leave, ctx, player)
		end
		lastTravel[player] = nil
	end)
	-- A guest whose character comes back (a respawn) is home again: nothing is carried.
	local function watchCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			local id = current
			local g = id and GAMES[id]
			if g and g.leave then
				pcall(g.leave, ctx, player)
			end
			player:SetAttribute("HolidayArea", nil)
		end)
	end
	for _, player in Players:GetPlayers() do
		watchCharacter(player)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	Holidays.refresh()
	task.spawn(function()
		local since = 0
		while true do
			local dt = task.wait(0.1)
			local ok, err = pcall(Holidays.step :: any, dt)
			if not ok then
				warn("[Maison] The holiday games stumbled: " .. tostring(err))
			end
			since += dt
			if since >= 5 then
				since = 0
				pcall(Holidays.refresh)
			end
		end
	end)
end

-- For tests.
Holidays.ctx = ctx
Holidays.GAMES = GAMES
Holidays.saved = saved
Holidays.watch = Integrity.step

return Holidays

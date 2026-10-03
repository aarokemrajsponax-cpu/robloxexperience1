--!strict
-- The Foyer's grand piano, played by a guest (ProductConfig pianoSession1/3/5/10). Sit at the keys
-- and play for the whole Foyer; the house's own music rests while you do.
--
-- Time is bought in sessions and kept in the profile (perks.piano.seconds), so it survives
-- leaving and rejoining. It only runs while the guest sits at the keys, on the server's clock;
-- getting up keeps the rest. One guest plays at a time; anyone else's time waits for them.
--
-- The notes: the player's screen sends each note it plays (a key number, nothing else). The
-- server checks it comes from the guest at the piano, holds them to a rate (RemoteGuard,
-- Config.RemoteLimits.pianoNote), and passes it to every other screen, which plays it from the
-- piano itself. The player's own screen has already played it, so they hear no delay.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Profiles = require(script.Parent.Parent.Profiles)
local RemoteGuard = require(script.Parent.Parent.RemoteGuard)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)
local Telemetry = require(script.Parent.Telemetry)

local Piano = {}

-- The four ways to buy time, shortest first.
Piano.KEYS = { "pianoSession1", "pianoSession3", "pianoSession5", "pianoSession10" }
local IS_PIANO: { [string]: boolean } = {}
for _, key in Piano.KEYS do
	IS_PIANO[key] = true
end

-- Told when a guest sits down to play or gets up (Main moves the Pianist aside and back).
Piano.onSession = function(_playing: boolean) end

type Session = { player: Player, data: Profiles.Data, ends: number, humanoid: Humanoid, seat: Seat, wrote: number }
local session: Session? = nil
-- A guest who asked to play with no time left: once a purchase lands, they sit straight down.
local waiting: { [Player]: number } = {}

local function bank(data: Profiles.Data): { seconds: number }
	local perks = data.perks :: any
	if type(perks.piano) ~= "table" then
		perks.piano = { seconds = 0 }
	end
	return perks.piano
end

local function clock(seconds: number): string
	local s = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- Seconds of piano time a guest has (counting down live while they play).
function Piano.remaining(player: Player, data: Profiles.Data?): number
	local s = session
	if s and s.player == player then
		return math.max(0, s.ends - os.clock())
	end
	return if data then math.max(0, bank(data).seconds) else 0
end

-- Who is playing, or nil.
function Piano.player(): Player?
	local s = session
	return if s then s.player else nil
end

local function seatPart(): Seat?
	for _, s in CollectionService:GetTagged("PianoSeat") do
		if s:IsA("Seat") then
			return s
		end
	end
	return nil
end

local function characterOf(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function near(player: Player): boolean
	local _, root = characterOf(player)
	return root ~= nil and (root.Position - Layout.Foyer.pianoSeat.Position).Magnitude <= Config.data.Piano.reach
end

local function publish()
	local s = session
	Workspace:SetAttribute("PianoPlayer", if s then s.player.UserId else nil)
	Workspace:SetAttribute("PianoName", if s then s.player.DisplayName else nil)
	Workspace:SetAttribute("PianoEnds", if s then Workspace:GetServerTimeNow() + math.max(0, s.ends - os.clock()) else nil)
end

-- Gets the guest at the piano up (out of time, by choice, or gone), keeping what's left.
function Piano.stand(reason: string)
	local s = session
	if not s then
		return
	end
	session = nil
	local left = math.max(0, math.floor(s.ends - os.clock()))
	bank(s.data).seconds = left
	s.seat.Disabled = true
	local weld = s.seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	if s.humanoid.Parent then
		s.humanoid.Sit = false
	end
	publish()
	Piano.onSession(false)
	if s.player.Parent then
		Perks.push(s.player)
		Perks.tell(s.player, { op = "pianoEnd", reason = reason, left = left })
		if reason == "time" then
			Telemetry.log(s.player, Telemetry.Events.Expired, "piano", "time_up")
		end
	end
end

-- Sits a guest down at the piano to play. Returns whether they're playing, and why not.
function Piano.sit(player: Player): (boolean, string?)
	local s = session
	if s then
		if s.player == player then
			return true, nil
		end
		return false, string.format("%s is at the piano (%s left). Your time waits for you.", s.player.DisplayName, clock(s.ends - os.clock()))
	end
	local data = Profiles.get(player)
	if not data then
		return false, "Your ledger is still being opened."
	end
	local left = Piano.remaining(player, data)
	if left < 1 then
		return false, "no_time"
	end
	local humanoid = characterOf(player)
	if not humanoid or not near(player) then
		return false, "Come to the grand piano in the Foyer to play."
	end
	local seat = seatPart()
	if not seat or seat.Occupant ~= nil then
		return false, "The piano isn't free just now."
	end
	waiting[player] = nil
	seat.Disabled = false
	seat:Sit(humanoid)
	session = { player = player, data = data, ends = os.clock() + left, humanoid = humanoid, seat = seat, wrote = os.clock() }
	publish()
	Piano.onSession(true)
	Telemetry.log(player, Telemetry.Events.Used, "piano", string.format("%ds held", math.floor(left)))
	Perks.push(player)
	return true, nil
end

-- What the guest's screen shows: their time, who's playing, and the four sessions' live prices.
function Piano.info(player: Player): { [string]: any }
	local data = Profiles.get(player)
	local s = session
	local offers = {}
	for _, key in Piano.KEYS do
		local entry = ProductConfig.byKey[key]
		table.insert(offers, {
			key = key,
			name = entry.UX.DisplayName,
			seconds = entry.Reward.Seconds,
			price = Catalog.price(key),
			ready = Catalog.enabled(key),
		})
	end
	return {
		ok = true,
		seconds = math.floor(Piano.remaining(player, data)),
		playing = s ~= nil and s.player == player,
		busy = if s and s.player ~= player then s.player.DisplayName else nil,
		busyLeft = if s and s.player ~= player then math.floor(s.ends - os.clock()) else nil,
		offers = offers,
	}
end

local function grant(ctx: Grants.Context)
	local player, data = ctx.player, ctx.data
	local add = ctx.product.Reward.Seconds :: number
	-- Paid time is never cut: every purchase adds its full length, even beyond what the house
	-- offers to hold (Config.Piano.maxSeconds stops the offer, never the grant).
	local total = Piano.remaining(player, data) + add
	bank(data).seconds = math.floor(total)
	-- Playing now: the clock moves with it, in the same step (so the next write can't undo it).
	local s = session
	if s and s.player == player and s.data == data then
		s.ends = os.clock() + total
	end
	ctx:after(function()
		publish()
		Perks.push(player)
		Perks.tell(player, { op = "notice", title = "The Grand Piano", line = string.format("%s of piano time. It only runs while you play.", clock(Piano.remaining(player, data))) })
		-- Bought at the piano: sit straight down if it's free.
		if waiting[player] and session == nil then
			Piano.sit(player)
		end
	end)
end

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 4, 0)
	if not r then
		RemoteGuard.reject(player, "pianoAsk", "malformed")
		return { ok = false, why = "That isn't something the piano can do." }
	end
	local op = r.op
	if op == "state" then
		return Piano.info(player)
	elseif op == "sit" then
		local ok, why = Piano.sit(player)
		if not ok and why == "no_time" then
			waiting[player] = os.clock()
			local info = Piano.info(player)
			info.ok = false
			info.needTime = true
			return info
		end
		return { ok = ok, why = why }
	elseif op == "stand" then
		local s = session
		if s and s.player == player then
			Piano.stand("up")
		end
		waiting[player] = nil
		return { ok = true }
	elseif op == "buy" then
		local key = RemoteGuard.oneOf(r.key, IS_PIANO)
		if not key then
			return { ok = false, why = "That isn't sold at the piano." }
		end
		waiting[player] = os.clock()
		local ok, why = Store.prompt(player, key, "piano")
		return { ok = ok, why = why, prompted = ok }
	end
	return { ok = false, why = "That isn't something the piano can do." }
end

local function onNote(player: Player, note: unknown, ...: unknown)
	local s = session
	if not s or s.player ~= player then
		RemoteGuard.reject(player, "pianoNote", "not_playing")
		return
	end
	local key = RemoteGuard.number(note, 1, Config.data.Piano.keys, true)
	if not key then
		RemoteGuard.reject(player, "pianoNote", "malformed")
		return
	end
	for _, other in Players:GetPlayers() do
		if other ~= player then
			Remotes.event("PianoNote"):FireClient(other, key, player.UserId)
		end
	end
end

local function tick()
	local s = session
	if not s then
		return
	end
	local now = os.clock()
	if not s.player.Parent or s.seat.Occupant ~= s.humanoid or s.humanoid.Health <= 0 then
		Piano.stand("up")
	elseif now >= s.ends then
		s.ends = now
		Piano.stand("time")
	elseif now - s.wrote >= 1 then
		-- The time left goes into the profile as it runs, so a crash or a leave keeps it.
		s.wrote = now
		bank(s.data).seconds = math.floor(s.ends - now)
	end
end

function Piano.start()
	Grants.register("piano", grant)
	for _, key in Piano.KEYS do
		Store.eligibility[key] = function(player: Player, data: Profiles.Data): (boolean, string?)
			local entry = ProductConfig.byKey[key]
			if Piano.remaining(player, data) + entry.Reward.Seconds > Config.data.Piano.maxSeconds then
				return false, string.format("You hold as much piano time as the house allows (%d minutes).", math.floor(Config.data.Piano.maxSeconds / 60))
			end
			return true, nil
		end
	end
	Perks.contributors.piano = function(player: Player, data: Profiles.Data): any
		local s = session
		return { seconds = math.floor(Piano.remaining(player, data)), playing = s ~= nil and s.player == player }
	end
	RemoteGuard.invoke(Remotes.func("PianoAsk"), "pianoAsk", onAsk)
	RemoteGuard.event(Remotes.event("PianoNote"), "pianoNote", onNote)
	Players.PlayerRemoving:Connect(function(player: Player)
		local s = session
		if s and s.player == player then
			Piano.stand("left")
		end
		waiting[player] = nil
	end)
	RunService.Heartbeat:Connect(tick)
	-- The prompt on the bench: sit down to play, or (with no time) see the sessions.
	task.spawn(function()
		local seat = seatPart()
		for _ = 1, 30 do
			if seat then
				break
			end
			task.wait(1)
			seat = seatPart()
		end
		local prompt = seat and seat:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player: Player)
				local result = onAsk(player, { op = "sit" })
				if type(result) == "table" and result.needTime then
					Perks.tell(player, { op = "pianoOffer" })
				elseif type(result) == "table" and not result.ok and type(result.why) == "string" then
					Perks.tell(player, { op = "notice", title = "The Grand Piano", line = result.why })
				end
			end)
		end
	end)
end

return Piano

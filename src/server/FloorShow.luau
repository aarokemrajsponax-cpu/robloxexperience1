--!strict
-- Lights Out (Build 81): the Ballroom's evening as party games on the dance floor, no sorting.
-- While the Ballroom is open a guest presses Join; the first to join starts the countdown. Then
-- everyone who joined is brought onto the marble floor inside the ring of twenty tables, each with
-- their own lamp lit at a table, and the rounds begin, one after another:
--   THE CHAIRS   music plays; when it stops, gold seats light up on the floor, fewer than there are
--                guests: stand on one (one guest a seat) before the time's up, or your lamp goes out.
--   LIGHTS OUT   the room goes dark but for a few circles of light: be inside one when the lights
--                come back, or you're out (and if everyone made it, one circle fails).
--   THE SPINNER  with three lamps or fewer left, all of them guests, the spinner picks two to face
--                off in the ring at the middle: shove (click or tap) to push the other out. The one
--                still in the ring stays; at the bell, the one nearer the middle.
-- The last lamp lit takes the pot (low on the Gilt ladder: it's a party game). On a quiet night,
-- stand-ins (the house's regulars, played by the house) make up the numbers; they never take the
-- pot. The server decides every seat, circle, shove and lamp: a screen only asks to join, to leave,
-- to shove, or to open the Ballroom early (the Robux product, through Purchases).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local LightsOut = require(ReplicatedStorage.Shared.LightsOut)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Analytics = require(script.Parent.Analytics)
local Gilt = require(script.Parent.Gilt)
local Integrity = require(script.Parent.Integrity)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local FloorShow = {}

-- Hooks (set by Main), as the sorting evening had them.
FloorShow.say = function(_player: Player, _line: string) end
FloorShow.onFinished = function(_player: Player, _place: number, _keys: number, _counted: boolean) end
FloorShow.onResult = function(_tableNumber: number, _name: string, _keys: number) end
FloorShow.secret = function(_player: Player) end
-- Opening early (Main: Purchases/Sabotage.openNow, the purchase window).
FloorShow.requestOpen = function(_player: Player): (boolean, string?)
	return false, "Not just now."
end
-- What opening it now costs this guest (Main: Purchases/Sabotage.openOffer): its price in Robux
-- (nil while it isn't on sale), and how many credits they hold. Shown on the key, never hidden.
FloorShow.openOffer = function(_player: Player): (number?, number)
	return nil, 0
end
-- Whether a guest is busy elsewhere (at a table, in an attraction): they can't join then.
FloorShow.isBusy = function(_player: Player): boolean
	return false
end

-- The clock and the dice (a test sets them).
FloorShow.clock = function(): number
	return os.clock()
end
FloorShow.rng = Random.new()

-- The house's regulars, who stand in on a quiet night.
local STAND_INS = { "The Countess", "Monsieur Vane", "Lady Ashby", "The Baron", "Miss Calloway", "Sir Reginald", "Madame Noor", "Count Orsini", "Lady Sable", "The Marquis" }

type Spot = { n: number, at: Vector3, radius: number, part: BasePart?, by: Guest? }
export type Guest = {
	player: Player?,
	name: string,
	userId: number,
	seat: number,
	alive: boolean,
	place: number?,
	standIn: boolean,
	skill: number,
	holding: Spot?,
	react: number?,
	lastShove: number,
}
type Show = {
	id: string,
	state: "gathering" | "playing" | "after",
	gatherEndsAt: number,
	startedAt: number,
	guests: { Guest },
	byPlayer: { [Player]: Guest },
	alive: number,
	of: number,
	real: number,
	pot: number,
	counts: boolean,
	round: number,
	kind: string,
	phase: string,
	phaseStart: number,
	phaseEnds: number,
	spots: { Spot },
	duel: { a: Guest, b: Guest }?,
	ending: boolean,
	afterUntil: number,
}

local event = Remotes.event("LightsOut")
local doorState: "open" | "closed" = "open"
local doorUntil = 0
local show: Show? = nil
local queued: { [Player]: boolean } = {}
local tables: { [number]: Model } = {}
local folder: Folder? = nil
local started = false

local function cfg(): { [string]: any }
	return (Config.data :: any).Ballroom
end
local function floor(): { [string]: any }
	return cfg().floor
end

local function serverNow(): number
	local ok, t = pcall(function()
		return Workspace:GetServerTimeNow()
	end)
	return if ok and type(t) == "number" then t else os.clock()
end

-- A clock time (FloorShow.clock) as the screens' server time.
local function at(t: number): number
	return serverNow() + (t - FloorShow.clock())
end

local function send(player: Player?, message: { [string]: any })
	if player and player.Parent == Players then
		event:FireClient(player, message)
	end
end

local function rootOf(player: Player?): BasePart?
	local character = player and player.Character
	local root = character and (character :: any):FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function inBallroom(player: Player): boolean
	local root = rootOf(player)
	return root ~= nil and Layout.zoneAt(root.Position) == "ballroom"
end

-- Everyone in the show, and everyone in the room watching it.
local function audience(): { Player }
	local out: { Player } = {}
	local seen: { [Player]: boolean } = {}
	local s = show
	if s then
		for _, g in s.guests do
			local p = g.player
			if p and not seen[p] then
				seen[p] = true
				table.insert(out, p)
			end
		end
	end
	for _, p in Players:GetPlayers() do
		if not seen[p] and inBallroom(p) then
			seen[p] = true
			table.insert(out, p)
		end
	end
	return out
end

local function broadcast(message: { [string]: any })
	for _, p in audience() do
		send(p, message)
	end
end

local function broadcastAll(message: { [string]: any })
	for _, p in Players:GetPlayers() do
		send(p, message)
	end
end

-- The dance floor: the middle of the ring, and how far from it the games are played.
function FloorShow.arena(): (Vector3, number)
	local B = Layout.Ballroom
	return B.centre, math.min(B.radius * 0.62, 60)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

function FloorShow.potFor(real: number): number
	local p = floor().pot
	return math.min(p.most, p.base + p.perGuest * math.max(1, real))
end

local function clockText(seconds: number): string
	local t = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", t // 60, t % 60)
end

-- What every screen reads: the Ballroom's state, when it next changes and the pot.
local function publish()
	local s = show
	local state: string = doorState
	local untilClock = doorUntil
	if s then
		state = s.state
		untilClock = if s.state == "gathering" then s.gatherEndsAt else 0
	end
	Workspace:SetAttribute("BallroomState", state)
	Workspace:SetAttribute("BallroomAt", if untilClock > 0 then at(untilClock) else nil)
	Workspace:SetAttribute("BallroomPot", if s and s.state ~= "gathering" then s.pot else FloorShow.potFor(if s then s.real else 1))
	Workspace:SetAttribute("LightsOutFloor", true)
end

---------------------------------------------------------------------------------------------------
-- Lamps: one a guest, at a table round the ring
---------------------------------------------------------------------------------------------------

local function lampOf(seat: number): SpotLight?
	local model = tables[seat]
	local bulb = model and model:FindFirstChild("Bulb")
	local light = bulb and bulb:FindFirstChild("TableLight")
	return if light and light:IsA("SpotLight") then light else nil
end

local function setLamp(seat: number, on: boolean, seconds: number)
	local light = lampOf(seat)
	if light then
		local base = light:GetAttribute("FloorBase")
		if type(base) ~= "number" then
			base = light.Brightness
			light:SetAttribute("FloorBase", base)
		end
		TweenService:Create(light, TweenInfo.new(seconds, Enum.EasingStyle.Sine), { Brightness = if on then base :: number else 0 }):Play()
	end
	local model = tables[seat]
	if model then
		model:SetAttribute("Out", not on)
	end
end

local function allLamps(on: boolean)
	for seat in tables do
		setLamp(seat, on, 0.8)
	end
end

---------------------------------------------------------------------------------------------------
-- The floor's own pieces: seats and circles of light (everyone sees them)
---------------------------------------------------------------------------------------------------

local function holder(): Folder
	local f = folder
	if f and f.Parent then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "LightsOutFloor"
	made.Parent = Workspace
	folder = made
	return made
end

local function disc(name: string, position: Vector3, radius: number, colour: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder
	p.Material = Enum.Material.Neon
	p.Color = colour
	p.Transparency = transparency
	p.Size = Vector3.new(0.3, radius * 2, radius * 2)
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = holder()
	return p
end

local function clearSpots(s: Show)
	for _, spot in s.spots do
		if spot.part then
			spot.part:Destroy()
		end
	end
	table.clear(s.spots)
	for _, g in s.guests do
		g.holding = nil
		g.react = nil
	end
end

-- `n` places on the floor, at least `gap` apart, within `within` of the middle.
local function scatter(n: number, within: number, gap: number): { Vector3 }
	local centre = FloorShow.arena()
	local out: { Vector3 } = {}
	local rng = FloorShow.rng
	local tries = 0
	while #out < n and tries < 400 do
		tries += 1
		local angle = rng:NextNumber() * math.pi * 2
		local r = math.sqrt(rng:NextNumber()) * within
		local p = centre + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
		local ok = true
		for _, q in out do
			if flatDistance(p, q) < gap then
				ok = false
				break
			end
		end
		if ok or tries > 300 then
			table.insert(out, p)
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- The show
---------------------------------------------------------------------------------------------------

local function realAlive(s: Show): number
	local n = 0
	for _, g in s.guests do
		if g.alive and not g.standIn then
			n += 1
		end
	end
	return n
end

local function aliveGuests(s: Show): { Guest }
	local out: { Guest } = {}
	for _, g in s.guests do
		if g.alive then
			table.insert(out, g)
		end
	end
	return out
end

local function setPhase(s: Show, phase: string, seconds: number, extra: { [string]: any }?)
	local now = FloorShow.clock()
	s.phase = phase
	s.phaseStart = now
	s.phaseEnds = now + seconds
	local message = { op = "round", round = s.round, kind = s.kind, phase = phase, ends = at(s.phaseEnds), alive = s.alive, of = s.of }
	if extra then
		for k, v in extra do
			(message :: any)[k] = v
		end
	end
	broadcast(message)
end

-- A guest's lamp goes out: their place, the room told, their own card.
local function out(s: Show, g: Guest, reason: string, by: Guest?)
	if not g.alive then
		return
	end
	g.alive = false
	g.place = s.alive
	s.alive -= 1
	g.holding = nil
	setLamp(g.seat, false, 0.6)
	broadcast({ op = "lampOut", seat = g.seat, name = g.name, standIn = g.standIn, alive = s.alive, reason = reason })
	if g.player then
		send(g.player, { op = "out", place = g.place, of = s.of, reason = reason, by = if by then by.name else nil, keys = 0 })
		Analytics.custom(g.player, "Lights Out lamp out", g.place or 0, { reason = reason, round = s.round })
	end
	if s.alive <= 1 or realAlive(s) == 0 then
		s.ending = true
	end
end

local function nextKind(s: Show): string
	local alive = s.alive
	local real = realAlive(s)
	if real >= 2 and alive == real and alive <= floor().duelAt then
		return "spinner"
	end
	return if s.round % 2 == 1 then "chairs" else "lights"
end

local function finish(s: Show)
	if s.state ~= "playing" then
		return
	end
	s.state = "after"
	clearSpots(s)
	local winner: Guest? = nil
	for _, g in s.guests do
		if g.alive then
			g.place = 1
			winner = g
		end
	end
	-- (Everyone still lit when the last real guest went out shares the places above them.)
	local results = {}
	for _, g in s.guests do
		table.insert(results, { name = g.name, place = g.place or s.of, standIn = g.standIn, seat = g.seat, keys = 0 })
	end
	table.sort(results, function(a, b)
		return a.place < b.place
	end)
	local w = winner
	local paid = 0
	if w and w.player then
		local data = Profiles.get(w.player)
		if data then
			paid = Gilt.pay(w.player, data, s.pot, "Lights Out")
		end
		FloorShow.say(w.player, "The last lamp in the house is yours.")
		if s.real >= 4 then
			FloorShow.secret(w.player)
		end
	end
	for _, g in s.guests do
		local p = g.player
		if p then
			local place = g.place or s.of
			send(p, {
				op = "showResult",
				place = place,
				of = s.of,
				keys = 0,
				points = LightsOut.points(place, 0),
				gilt = if g == w then paid else 0,
				pot = s.pot,
				counted = s.counts,
				won = g == w,
			})
			FloorShow.onFinished(p, place, 0, s.counts)
			Analytics.custom(p, "Lights Out finished", place, { of = s.of, real = s.real })
		end
		if g.place == 1 then
			FloorShow.onResult(g.seat, g.name, 0)
		end
	end
	broadcastAll({ op = "showEnd", winner = if w then w.name else nil, standIn = w ~= nil and w.standIn, pot = s.pot, results = results })
	s.afterUntil = FloorShow.clock() + 8
	publish()
end

local function startRound(s: Show)
	clearSpots(s)
	s.round += 1
	s.kind = nextKind(s)
	s.duel = nil
	setPhase(s, "intro", floor().intro)
end

-- The Chairs: seats for fewer than everyone.
local function openChairs(s: Show)
	local _, radius = FloorShow.arena()
	local guests = aliveGuests(s)
	local n = math.clamp(math.floor(#guests * floor().seatShare), 1, math.max(1, #guests - 1))
	local where = scatter(n, radius * 0.8, floor().seatRadius * 2 + 3)
	for i, p in where do
		local spot: Spot = { n = i, at = p, radius = floor().seatRadius, part = nil, by = nil }
		spot.part = disc("Seat", p + Vector3.new(0, 0.2, 0), floor().seatRadius, Color3.fromRGB(255, 206, 90), 0.1)
		table.insert(s.spots, spot)
	end
	local rng = FloorShow.rng
	for _, g in guests do
		if g.standIn then
			-- (Never quicker than a person: at least 0.9 s, the slower ones nearly the whole window.)
			g.react = math.max(0.9, rng:NextNumber(0.5, floor().scramble - 0.3) * (1.15 - g.skill))
		end
	end
	local seats = {}
	for _, spot in s.spots do
		table.insert(seats, { n = spot.n, x = spot.at.X, z = spot.at.Z })
	end
	setPhase(s, "scramble", floor().scramble + 0.4, { seats = seats })
end

local function claim(s: Show, spot: Spot, g: Guest)
	spot.by = g
	g.holding = spot
	local part = spot.part
	if part then
		part.Color = Color3.fromRGB(255, 70, 170)
	end
	broadcast({ op = "seat", n = spot.n, name = g.name, you = false })
	if g.player then
		send(g.player, { op = "safe", kind = "chairs" })
	end
end

local function scrambleStep(s: Show, now: number)
	-- Real guests: the nearest free seat they stand on.
	for _, g in s.guests do
		if g.alive and not g.standIn and not g.holding then
			local root = rootOf(g.player)
			if root then
				local best: Spot? = nil
				local bestD = math.huge
				for _, spot in s.spots do
					if not spot.by then
						local d = flatDistance(root.Position, spot.at)
						if d <= spot.radius and math.abs(root.Position.Y - spot.at.Y) < 10 and d < bestD then
							best, bestD = spot, d
						end
					end
				end
				if best then
					claim(s, best, g)
				end
			end
		end
	end
	-- Stand-ins: when they react, a free seat if there is one.
	for _, g in s.guests do
		if g.alive and g.standIn and not g.holding and g.react and now - s.phaseStart >= g.react then
			g.react = nil
			for _, spot in s.spots do
				if not spot.by then
					claim(s, spot, g)
					break
				end
			end
		end
	end
end

local function closeChairs(s: Show)
	for _, g in aliveGuests(s) do
		if not g.holding then
			out(s, g, "chairs", nil)
		end
	end
end

-- Lights Out: a few circles of light, then the dark.
local function openLights(s: Show)
	local _, radius = FloorShow.arena()
	local guests = aliveGuests(s)
	local n = math.max(1, math.ceil(#guests / floor().circlesPer))
	local r = floor().circleRadius
	for i, p in scatter(n, radius * 0.72, r * 2 + 4) do
		local spot: Spot = { n = i, at = p, radius = r, part = nil, by = nil }
		spot.part = disc("Circle", p + Vector3.new(0, 0.2, 0), r, Color3.fromRGB(150, 230, 255), 0.35)
		table.insert(s.spots, spot)
	end
	local circles = {}
	for _, spot in s.spots do
		table.insert(circles, { n = spot.n, x = spot.at.X, z = spot.at.Z, r = spot.radius })
	end
	setPhase(s, "warn", floor().lightsWarn, { circles = circles })
end

local function inCircle(s: Show, g: Guest): Spot?
	local root = rootOf(g.player)
	if not root then
		return nil
	end
	for _, spot in s.spots do
		if flatDistance(root.Position, spot.at) <= spot.radius + 0.6 and math.abs(root.Position.Y - spot.at.Y) < 10 then
			return spot
		end
	end
	return nil
end

local function closeLights(s: Show)
	local rng = FloorShow.rng
	local before = s.alive
	local inside: { [Spot]: { Guest } } = {}
	for _, g in aliveGuests(s) do
		if g.standIn then
			if rng:NextNumber() > 0.5 + 0.4 * g.skill then
				out(s, g, "dark", nil)
			end
		else
			local spot = inCircle(s, g)
			if not spot then
				out(s, g, "dark", nil)
			else
				inside[spot] = inside[spot] or {}
				table.insert(inside[spot], g)
			end
		end
	end
	-- Everyone made it: one circle fails (never the only one with anybody in it).
	if s.alive == before and s.alive > 1 then
		local choices: { Spot } = {}
		local occupied = 0
		for _, list in inside do
			occupied += #list
		end
		for spot, list in inside do
			if #list > 0 and #list < s.alive then
				table.insert(choices, spot)
			end
		end
		if #choices > 0 and occupied > 0 then
			local spot = choices[rng:NextInteger(1, #choices)]
			broadcast({ op = "circleOut", n = spot.n })
			for _, g in inside[spot] do
				out(s, g, "dark", nil)
			end
		end
	end
end

-- The Spinner: two guests in the ring.
local function teleport(player: Player?, cf: CFrame)
	if not player then
		return
	end
	local character = player.Character
	if character then
		pcall(function()
			Integrity.moved(player, 3)
		end)
		pcall(function()
			(character :: any):PivotTo(cf)
		end)
	end
end

local function openDuel(s: Show)
	local centre = FloorShow.arena()
	local reals: { Guest } = {}
	for _, g in aliveGuests(s) do
		if not g.standIn then
			table.insert(reals, g)
		end
	end
	if #reals < 2 then
		s.kind = "chairs"
		openChairs(s)
		return
	end
	local rng = FloorShow.rng
	local a = table.remove(reals, rng:NextInteger(1, #reals)) :: Guest
	local b = table.remove(reals, rng:NextInteger(1, #reals)) :: Guest
	s.duel = { a = a, b = b }
	local ring = floor().ring
	local aAt = centre + Vector3.new(-ring * 0.45, 3, 0)
	local bAt = centre + Vector3.new(ring * 0.45, 3, 0)
	teleport(a.player, CFrame.lookAt(aAt, bAt))
	teleport(b.player, CFrame.lookAt(bAt, aAt))
	-- (Anyone else waits at the rim.)
	for i, g in reals do
		local angle = (i / math.max(1, #reals)) * math.pi * 2
		teleport(g.player, CFrame.lookAt(centre + Vector3.new(math.cos(angle) * (ring + 9), 3, math.sin(angle) * (ring + 9)), centre))
	end
	local part = disc("Ring", centre + Vector3.new(0, 0.15, 0), ring, Color3.fromRGB(255, 70, 170), 0.55)
	local ringSpot: Spot = { n = 1, at = centre, radius = ring, part = part :: BasePart, by = nil }
	table.insert(s.spots, ringSpot)
	setPhase(s, "duel", floor().duelSeconds, { a = a.name, b = b.name, aId = a.userId, bId = b.userId, ring = ring, x = centre.X, z = centre.Z })
end

local function duelStep(s: Show)
	local d = s.duel
	if not d then
		return
	end
	local centre = FloorShow.arena()
	local ring = floor().ring
	for _, pair in { { d.a, d.b }, { d.b, d.a } } do
		local g, other = pair[1], pair[2]
		local root = rootOf(g.player)
		if not root or flatDistance(root.Position, centre) > ring + 1.5 or root.Position.Y < centre.Y - 8 then
			out(s, g, "ring", other)
			s.duel = nil
			s.phaseEnds = FloorShow.clock()
			return
		end
	end
end

local function closeDuel(s: Show)
	local d = s.duel
	if not d then
		return
	end
	s.duel = nil
	local centre = FloorShow.arena()
	local ra, rb = rootOf(d.a.player), rootOf(d.b.player)
	local da = if ra then flatDistance(ra.Position, centre) else math.huge
	local db = if rb then flatDistance(rb.Position, centre) else math.huge
	-- (At the bell: the one nearer the middle stays.)
	if da >= db then
		out(s, d.a, "bell", d.b)
	else
		out(s, d.b, "bell", d.a)
	end
end

-- A shove: from one duellist to the other, within reach; the one shoved is pushed by their own
-- screen (it moves their character), and the ring decides who's out.
function FloorShow.shove(player: Player): (boolean, string?)
	local s = show
	local d = s and s.duel
	if not s or not d or s.phase ~= "duel" then
		return false, "Not now."
	end
	local g = s.byPlayer[player]
	if not g or (g ~= d.a and g ~= d.b) then
		return false, "Only the two in the ring can shove."
	end
	local now = FloorShow.clock()
	if now - g.lastShove < floor().shoveGap then
		return false, "soon"
	end
	local other = if g == d.a then d.b else d.a
	local mine, theirs = rootOf(player), rootOf(other.player)
	if not mine or not theirs then
		return false, "Not now."
	end
	if flatDistance(mine.Position, theirs.Position) > floor().shoveReach then
		return false, "Too far: get closer."
	end
	g.lastShove = now
	local away = Vector3.new(theirs.Position.X - mine.Position.X, 0, theirs.Position.Z - mine.Position.Z)
	local dir = if away.Magnitude > 0.01 then away.Unit else Vector3.new(1, 0, 0)
	send(other.player, { op = "shoved", x = dir.X, z = dir.Z, power = floor().shovePower, by = g.name })
	broadcast({ op = "shove", from = g.name, to = other.name })
	return true, nil
end

local function bringIn(s: Show)
	local centre, radius = FloorShow.arena()
	local reals: { Guest } = {}
	for _, g in s.guests do
		if g.player then
			table.insert(reals, g)
		end
	end
	for i, g in reals do
		local angle = (i / math.max(1, #reals)) * math.pi * 2
		local p = centre + Vector3.new(math.cos(angle) * radius * 0.5, 3, math.sin(angle) * radius * 0.5)
		teleport(g.player, CFrame.lookAt(p, Vector3.new(centre.X, p.Y, centre.Z)))
	end
end

local function begin(s: Show)
	local now = FloorShow.clock()
	-- (Anyone who joined but is busy elsewhere now, or gone, is left out.)
	for i = #s.guests, 1, -1 do
		local g = s.guests[i]
		local p = g.player
		if p and (p.Parent ~= Players or FloorShow.isBusy(p)) then
			s.byPlayer[p] = nil
			table.remove(s.guests, i)
		end
	end
	s.real = #s.guests
	if s.real == 0 then
		show = nil
		doorState = "closed"
		doorUntil = now + cfg().closedSeconds
		publish()
		return
	end
	-- Stand-ins to make up a show (the free lamps, in order).
	local used: { [number]: boolean } = {}
	for _, g in s.guests do
		used[g.seat] = true
	end
	local rng = FloorShow.rng
	local want = math.max(floor().fill, 2)
	local names = table.clone(STAND_INS)
	local seat = 0
	while #s.guests < want and #s.guests < floor().most do
		seat += 1
		if not used[seat] then
			used[seat] = true
			local name = table.remove(names, rng:NextInteger(1, #names)) or "A Stand-in"
			table.insert(s.guests, { player = nil, name = name, userId = 0, seat = seat, alive = true, place = nil, standIn = true, skill = rng:NextNumber(0.2, 0.85), holding = nil, react = nil, lastShove = -math.huge })
		end
	end
	s.of = #s.guests
	s.alive = s.of
	s.pot = FloorShow.potFor(s.real)
	s.counts = s.real >= (cfg().minRealForRecords or 8)
	s.state = "playing"
	s.startedAt = now
	allLamps(false)
	for _, g in s.guests do
		setLamp(g.seat, true, 0.8)
	end
	local list = {}
	for _, g in s.guests do
		table.insert(list, { name = g.name, seat = g.seat, standIn = g.standIn })
	end
	broadcastAll({ op = "showStart", of = s.of, real = s.real, pot = s.pot, guests = list, counted = s.counts })
	bringIn(s)
	publish()
	startRound(s)
end

local function step(now: number)
	local s = show
	if not s then
		if doorState == "open" and now >= doorUntil then
			doorState = "closed"
			doorUntil = now + cfg().closedSeconds
			publish()
			broadcast({ op = "ballroomClosed", opensIn = cfg().closedSeconds })
		elseif doorState == "closed" and now >= doorUntil then
			FloorShow.openNow(nil)
		end
		return
	end
	if s.state == "gathering" then
		if now >= s.gatherEndsAt then
			begin(s)
		end
		return
	end
	if s.state == "after" then
		if now >= s.afterUntil then
			show = nil
			doorState = "closed"
			doorUntil = now + cfg().closedSeconds
			allLamps(true)
			publish()
		end
		return
	end
	-- Playing.
	if s.phase == "scramble" then
		scrambleStep(s, now)
	elseif s.phase == "duel" then
		duelStep(s)
	end
	if now < s.phaseEnds then
		return
	end
	if s.phase == "intro" then
		if s.kind == "chairs" then
			setPhase(s, "music", FloorShow.rng:NextNumber(floor().musicMin, floor().musicMax))
		elseif s.kind == "lights" then
			openLights(s)
		else
			openDuel(s)
		end
	elseif s.phase == "music" then
		openChairs(s)
	elseif s.phase == "scramble" then
		closeChairs(s)
		setPhase(s, "result", floor().result)
	elseif s.phase == "warn" then
		setPhase(s, "dark", floor().lightsDark)
	elseif s.phase == "dark" then
		closeLights(s)
		setPhase(s, "result", floor().result)
	elseif s.phase == "duel" then
		closeDuel(s)
		setPhase(s, "result", floor().result)
	elseif s.phase == "result" then
		clearSpots(s)
		if s.ending or s.alive <= 1 or realAlive(s) == 0 then
			finish(s)
		else
			startRound(s)
		end
	end
end
FloorShow.step = step

---------------------------------------------------------------------------------------------------
-- Joining, leaving, the door
---------------------------------------------------------------------------------------------------

function FloorShow.join(player: Player): (boolean, string?)
	local now = FloorShow.clock()
	local s = show
	if s and s.byPlayer[player] then
		return true, nil
	end
	if doorState == "closed" and not s then
		queued[player] = true
		return false, string.format("The Ballroom is closed: it opens in %s. You'll be told when it does.", clockText(doorUntil - now))
	end
	if s and s.state ~= "gathering" then
		-- (Asked to be reminded: they are, when it next opens.)
		queued[player] = true
		return false, "Lights Out has started: nobody joins late. You'll be told when it opens again."
	end
	if FloorShow.isBusy(player) then
		return false, "Finish what you're doing first: leave your table or the attraction you're in."
	end
	if not s then
		s = {
			id = tostring(now),
			state = "gathering",
			gatherEndsAt = now + floor().countdown,
			startedAt = 0,
			guests = {},
			byPlayer = {},
			alive = 0,
			of = 0,
			real = 0,
			pot = 0,
			counts = false,
			round = 0,
			kind = "",
			phase = "",
			phaseStart = 0,
			phaseEnds = 0,
			spots = {},
			duel = nil,
			ending = false,
			afterUntil = 0,
		}
		show = s
		broadcastAll({ op = "ballroomCountdown", startsIn = floor().countdown })
	end
	local current = s :: Show
	if #current.guests >= floor().most then
		return false, "Lights Out is full tonight: twenty lamps, all taken."
	end
	local used: { [number]: boolean } = {}
	for _, g in current.guests do
		used[g.seat] = true
	end
	local seat = 1
	while used[seat] do
		seat += 1
	end
	local g: Guest = { player = player, name = Names.of(player), userId = player.UserId, seat = seat, alive = true, place = nil, standIn = false, skill = 1, holding = nil, react = nil, lastShove = -math.huge }
	table.insert(current.guests, g)
	current.byPlayer[player] = g
	current.real = #current.guests
	queued[player] = nil
	setLamp(seat, true, 0.6)
	send(player, { op = "joined", seat = seat, startsAt = at(current.gatherEndsAt), pot = FloorShow.potFor(current.real) })
	broadcast({ op = "gathering", count = #current.guests, startsAt = at(current.gatherEndsAt), pot = FloorShow.potFor(current.real) })
	publish()
	return true, nil
end

function FloorShow.leave(player: Player)
	local s = show
	local g = s and s.byPlayer[player]
	queued[player] = nil
	if not s or not g then
		return
	end
	if s.state == "gathering" then
		s.byPlayer[player] = nil
		local i = table.find(s.guests, g)
		if i then
			table.remove(s.guests, i)
		end
		s.real = #s.guests
		setLamp(g.seat, false, 0.6)
		send(player, { op = "left" })
		if #s.guests == 0 then
			show = nil
		end
		publish()
	elseif s.state == "playing" and g.alive then
		out(s, g, "left", nil)
	end
end

function FloorShow.openNow(by: string?): (boolean, string?)
	if show or doorState == "open" then
		return false, "The Ballroom is open already."
	end
	doorState = "open"
	doorUntil = FloorShow.clock() + cfg().openSeconds
	allLamps(true)
	publish()
	broadcastAll({ op = "ballroomOpen", by = by, closesIn = cfg().openSeconds, pot = FloorShow.potFor(1), perGuest = floor().pot.perGuest, countdown = floor().countdown })
	for player in queued do
		send(player, { op = "reminder" })
	end
	table.clear(queued)
	return true, nil
end

function FloorShow.isClosed(): boolean
	return show == nil and doorState == "closed"
end

function FloorShow.door(): (string, number)
	local s = show
	if s then
		return s.state, if s.state == "gathering" then s.gatherEndsAt - FloorShow.clock() else 0
	end
	return doorState, math.max(0, doorUntil - FloorShow.clock())
end

-- Whether a guest is playing in tonight's show, lamp lit: nothing else takes them meanwhile.
-- (Waiting for it to start, they're free to wander.)
function FloorShow.isSeated(player: Player): boolean
	local s = show
	local g = s and s.byPlayer[player]
	return g ~= nil and (s :: Show).state == "playing" and g.alive
end

function FloorShow.current(): Show?
	return show
end

local function onMessage(player: Player, request: unknown)
	local r = RemoteGuard.message(request, 2, 0)
	if not r then
		RemoteGuard.reject(player, "lightsOut", "malformed")
		return
	end
	local op = r.op
	if op == "join" then
		local ok, why = FloorShow.join(player)
		if not ok and why then
			send(player, { op = "refused", why = why })
		end
	elseif op == "leave" then
		FloorShow.leave(player)
	elseif op == "shove" then
		local ok, why = FloorShow.shove(player)
		if not ok and why and why ~= "soon" then
			send(player, { op = "refused", why = why })
		end
	elseif op == "openNow" then
		if not FloorShow.isClosed() then
			send(player, { op = "refused", why = "The Ballroom is open already." })
			return
		end
		local ok, why = FloorShow.requestOpen(player)
		if not ok and why then
			send(player, { op = "refused", why = why })
		end
	elseif op == "hello" then
		local state, left = FloorShow.door()
		local s = show
		local okOffer, price, held = pcall(FloorShow.openOffer, player)
		send(player, {
			op = "hello",
			state = state,
			left = left,
			joined = s ~= nil and s.byPlayer[player] ~= nil,
			pot = if s then s.pot else FloorShow.potFor(1),
			openPrice = if okOffer and type(price) == "number" then price else nil,
			openHeld = if okOffer and type(held) == "number" then held else 0,
		})
	else
		RemoteGuard.reject(player, "lightsOut", "malformed")
	end
end

function FloorShow.start()
	if started then
		return
	end
	started = true
	for _, model in CollectionService:GetTagged("BallroomTable") do
		if model:IsA("Model") then
			local index = model:GetAttribute("Seat")
			if type(index) == "number" then
				tables[index] = model
				-- (No sorting at these tables now: their chairs are for sitting out a round.)
				local chair = model:FindFirstChild("Chair")
				local prompt = chair and chair:FindFirstChild("SitPrompt")
				if prompt and prompt:IsA("ProximityPrompt") then
					prompt.Enabled = false
				end
			end
		end
	end
	doorState = "open"
	doorUntil = FloorShow.clock() + cfg().openSeconds
	publish()
	RemoteGuard.event(event, "lightsOut", onMessage)
	Players.PlayerRemoving:Connect(function(player: Player)
		FloorShow.leave(player)
		queued[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(function()
				step(FloorShow.clock())
			end)
			if not ok then
				warn("[Maison] Lights Out: " .. tostring(err))
			end
		end
	end)
end

return FloorShow

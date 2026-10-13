--!strict
-- How guests move, watched by the server. Roblox lets each guest's own screen move their
-- character (that's why walking feels instant), so an exploit tool can put a character anywhere,
-- or run it faster than anyone can. The server can't stop that frame by frame, but it can notice:
-- ten times a second it compares where each guest is with where they were, against how fast this
-- guest can truly move just now (Speed.resolve over the events and perks the server itself set).
--   teleport   one step further than anyone could go: put back at once, where they just were
--   speed      over the last second and a half, further than they could have run: put back
--   flight     rising further than any jump or staircase lifts anyone: put back
-- Either way they find nothing for a few seconds (Integrity.trusted, which every pickup asks),
-- and the house hears of it (Integrity.onCaught: analytics).
--
-- What it never does: hold back a guest the house moved itself (every server teleport goes
-- through Integrity.teleport, which says so first), a guest seated or riding, held still, or just
-- arrived, anyone while an effect is throwing guests about (Admin Abuse's launches, black holes,
-- zero-G), or the owner, whose own powers move them however they like.
--
-- A guest whose screen goes quiet (a lag spike) is measured from the last place their screen said
-- they were, when it said so: the burst that follows is a walk, not a jump.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Speed = require(ReplicatedStorage.Shared.Speed)

local Integrity = {}

-- Set by Main: whether a guest is the owner (AdminService.isAdmin, by UserId).
Integrity.isOwner = function(_player: Player): boolean
	return false
end
-- Set by Main: told whenever a guest is caught moving as nobody can (analytics).
Integrity.onCaught = function(_player: Player, _why: string, _distance: number) end

type Sample = { at: Vector3, t: number }
type Track = {
	root: any,
	last: Vector3, -- where their screen last said they were
	lastT: number, -- and when
	history: { Sample }, -- the last window's steps, oldest first
	suspect: number, -- finds nothing until (os.clock)
	grace: number, -- the house moved them, or they just arrived: unchecked until (os.clock)
	caught: { number }, -- when they were caught (the last minute's)
}

-- (The Workspace, looked up when first wanted: the house's teleports work before the watch starts.)
local cachedWorld: Workspace? = nil
local function world(): Workspace
	if not cachedWorld then
		cachedWorld = game:GetService("Workspace")
	end
	return cachedWorld :: Workspace
end

local tracks: { [Player]: Track } = {}
local graceAll = 0 -- everyone moves freely until (os.clock): an effect is throwing guests about
local STEP = 0.1
local started = false

local function cfg(): { [string]: any }
	return (Config.data :: any).Integrity
		or {
			slack = 1.5,
			extra = 10,
			teleport = 30,
			window = 1.5,
			windowSlack = 1.3,
			windowExtra = 8,
			rise = 30,
			suspectFor = 3,
			grace = 2,
			spawnGrace = 4,
			effectGrace = 3,
			lowGravity = 150,
			rubberBand = true,
		}
end

local function rootOf(player: Player): any
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local ok, part = pcall(function()
		return root:IsA("BasePart")
	end)
	return if ok and not part then nil else root
end

-- A property of an instance, or nil where it can't be read.
local function prop(o: any, name: string): any
	local ok, v = pcall(function()
		return o[name]
	end)
	return if ok then v else nil
end

-- Where a root stands (its frame's position, which is its Position).
local function where(root: any): Vector3
	local ok, p = pcall(function()
		return root.CFrame.Position
	end)
	if ok and typeof(p) == "Vector3" then
		return p
	end
	return root.Position
end

local function fresh(root: any, at: Vector3, now: number, grace: number): Track
	return { root = root, last = at, lastT = now, history = { { at = at, t = now } }, suspect = 0, grace = grace, caught = {} }
end

-- Starts a guest's record again from where they stand (after the house moved them).
local function restart(t: Track, at: Vector3, now: number)
	t.last = at
	t.lastT = now
	t.history = { { at = at, t = now } }
end

-- How fast this guest may move just now (studs a second): running, with every event and perk the
-- server set on them.
local function fastest(player: Player): number
	return Speed.resolve(true, world():GetAttribute("SpeedBoost"), player:GetAttribute("SpeedPerk"), player:GetAttribute("AdminSpeed"))
end

-- How high this guest's jump lifts them (studs), from the jump the server gave them.
local function jumpRise(humanoid: any): number
	local power = 50
	local v = prop(humanoid, "JumpPower")
	if type(v) == "number" and v > 0 then
		power = v
	end
	local g = math.max(1, world().Gravity)
	return power * power / (2 * g)
end

-- Whether any of the owner's effects is on (the Workspace's "Fx_" attributes): while one is,
-- guests are thrown about by their own screens, as the effect means them to be.
local function effectOn(): boolean
	for key, value in world():GetAttributes() do
		if string.sub(key, 1, 3) == "Fx_" and value ~= nil and value ~= false then
			return true
		end
	end
	return false
end

-- Whether this guest moves freely just now (nothing is checked, and their record starts again).
local function free(player: Player, t: Track, humanoid: any, now: number, effects: boolean): boolean
	if now < t.grace or now < graceAll or effects then
		return true
	end
	if world().Gravity < cfg().lowGravity then
		return true
	end
	if Integrity.isOwner(player) then
		return true
	end
	if prop(t.root, "Anchored") == true then
		return true
	end
	if prop(humanoid, "SeatPart") ~= nil or prop(humanoid, "Sit") == true or prop(humanoid, "PlatformStand") == true then
		return true
	end
	local ok, state = pcall(function()
		return humanoid:GetState()
	end)
	if ok and (state == Enum.HumanoidStateType.Dead or state == Enum.HumanoidStateType.Physics or state == Enum.HumanoidStateType.Seated or state == Enum.HumanoidStateType.PlatformStanding) then
		return true
	end
	return false
end

-- Puts a guest back at `at` (keeping which way they face), still.
local function putBack(player: Player, t: Track, at: Vector3)
	local character = player.Character
	if not character then
		return
	end
	local facing = CFrame.new()
	local ok, cf = pcall(function()
		return t.root.CFrame
	end)
	if ok and typeof(cf) == "CFrame" then
		facing = cf.Rotation
	end
	pcall(function()
		character:PivotTo(CFrame.new(at) * facing)
	end)
	pcall(function()
		t.root.AssemblyLinearVelocity = Vector3.zero
	end)
end

local function caught(player: Player, t: Track, why: string, distance: number, backTo: Vector3, now: number)
	local c = cfg()
	t.suspect = now + c.suspectFor
	table.insert(t.caught, now)
	while #t.caught > 0 and now - t.caught[1] > 60 do
		table.remove(t.caught, 1)
	end
	if c.rubberBand then
		putBack(player, t, backTo)
		restart(t, backTo, now)
	end
	pcall(Integrity.onCaught, player, why, distance)
end

-- One look at every guest.
function Integrity.step()
	local now = os.clock()
	local c = cfg()
	local effects = effectOn()
	for _, player in Players:GetPlayers() do
		local root = rootOf(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			tracks[player] = nil
			continue
		end
		local at = where(root)
		local t = tracks[player]
		if not t or t.root ~= root then
			-- (A new character: it has just been put somewhere.)
			tracks[player] = fresh(root, at, now, now + c.spawnGrace)
			continue
		end
		if free(player, t, humanoid, now, effects) then
			restart(t, at, now)
			continue
		end
		-- (Nothing new from their screen: measured from the last place it said, when it said so.)
		if (at - t.last).Magnitude < 0.05 then
			continue
		end
		local dt = math.max(STEP, now - t.lastT)
		local speed = fastest(player)
		local flat = Vector3.new(at.X - t.last.X, 0, at.Z - t.last.Z).Magnitude
		local before = t.last
		if flat > (speed * c.slack + c.extra) * dt + c.teleport then
			caught(player, t, "teleport", flat, before, now)
			continue
		end
		table.insert(t.history, { at = at, t = now })
		while #t.history > 2 and now - t.history[1].t > c.window do
			table.remove(t.history, 1)
		end
		t.last = at
		t.lastT = now
		local first = t.history[1]
		local span = now - first.t
		if span >= c.window * 0.5 then
			local far = Vector3.new(at.X - first.at.X, 0, at.Z - first.at.Z).Magnitude
			if far > speed * span * c.windowSlack + c.windowExtra then
				caught(player, t, "speed", far, first.at, now)
				continue
			end
			local rise = at.Y - first.at.Y
			local climb = math.max(c.rise, speed * span * 1.1 + 12, jumpRise(humanoid) * 1.6 + 12)
			if rise > climb then
				caught(player, t, "flight", rise, first.at, now)
				continue
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- What the rest of the house asks
---------------------------------------------------------------------------------------------------

-- The house has moved this guest (a trip, a seat, a ride): their next step isn't a jump of their
-- own. (`seconds`: how long they move freely; the default is a couple of seconds.)
function Integrity.moved(player: Player?, seconds: number?)
	if not player then
		return
	end
	local now = os.clock()
	local t = tracks[player]
	if t then
		t.grace = math.max(t.grace, now + (seconds or cfg().grace))
	else
		local root = rootOf(player)
		if root then
			tracks[player] = fresh(root, where(root), now, now + (seconds or cfg().grace))
		end
	end
end

-- Moves a guest's character there, as the house: the one way the server teleports anyone.
function Integrity.teleport(player: Player?, character: Model, cf: CFrame)
	Integrity.moved(player)
	character:PivotTo(cf)
	local t = player and tracks[player]
	if t then
		restart(t, cf.Position, os.clock())
	end
	Integrity.moved(player)
end

-- An effect is throwing everyone about for `seconds`: nobody is held back meanwhile.
function Integrity.excuseAll(seconds: number)
	graceAll = math.max(graceAll, os.clock() + seconds + cfg().effectGrace)
end

-- Whether this guest may find things now (not just after a move nobody could make).
function Integrity.trusted(player: Player): boolean
	local t = tracks[player]
	return t == nil or os.clock() >= t.suspect
end

-- How many times this guest was caught in the last minute.
function Integrity.strikes(player: Player): number
	local t = tracks[player]
	if not t then
		return 0
	end
	local now = os.clock()
	local n = 0
	for _, at in t.caught do
		if now - at <= 60 then
			n += 1
		end
	end
	return n
end

-- Whether a guest stands within `reach` of `at` (across the floor; `height` up or down) and may
-- find things: what a pickup asks.
function Integrity.near(player: Player, at: Vector3, reach: number, height: number?): boolean
	local root = rootOf(player)
	if not root or not Integrity.trusted(player) then
		return false
	end
	local p = where(root)
	return Vector3.new(p.X - at.X, 0, p.Z - at.Z).Magnitude <= reach and math.abs(p.Y - at.Y) <= (height or 10)
end

function Integrity.forget(player: Player)
	tracks[player] = nil
end

-- (Idempotent: Main starts it, and so does anything that needs it before Main has.)
function Integrity.start()
	if started then
		return
	end
	started = true
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < STEP then
			return
		end
		acc = 0
		Integrity.step()
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		tracks[player] = nil
	end)
end

return Integrity

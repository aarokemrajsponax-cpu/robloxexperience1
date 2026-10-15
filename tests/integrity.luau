--!nocheck
-- How guests move, watched by the server (server/Integrity), under Lune on a fake clock: a guest
-- walking and running as anyone can is never held back; a teleport, a run faster than anyone can,
-- a flight are put back at once and find nothing for a moment; the house's own moves (a trip, a
-- seat, a ride), a seat, a held-still character, the owner's effects and the owner are never
-- caught; a lag spike's burst is a walk, not a jump; and every teleport the server makes goes
-- through Integrity.teleport.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/integrity.luau

local fs = require("@lune/fs")
local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local roblox, Vector3, CFrame = H.roblox, H.Vector3, H.CFrame
local module, services, Config = H.module, H.services, H.Config

-- What Lune's models don't do: pivots.
local function pivotOf(m)
	local pp = m.PrimaryPart or m:FindFirstChild("HumanoidRootPart")
	return if pp then pp.CFrame else CFrame.new()
end
roblox.implementMethod("Model", "GetPivot", pivotOf)
roblox.implementMethod("Model", "PivotTo", function(self, target)
	local delta = target * pivotOf(self):Inverse()
	for _, d in self:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = delta * d.CFrame
		end
	end
end)

local Integrity = module("ServerScriptService", "Server", "Integrity")
local OWNER = 8722595934
Integrity.isOwner = function(p)
	return p.UserId == OWNER
end
local caughtLog = {}
Integrity.onCaught = function(p, why, distance)
	table.insert(caughtLog, { who = p.Name, why = why, distance = distance })
end
run(Integrity.start)

-- A guest with a body (a root and a humanoid) standing at `at`.
local function body(g, at)
	local m = roblox.Instance.new("Model")
	m.Name = g.Name
	local r = roblox.Instance.new("Part")
	r.Name = "HumanoidRootPart"
	r.Size = Vector3.new(2, 2, 1)
	r.CFrame = CFrame.new(at)
	r.Parent = m
	local h = roblox.Instance.new("Humanoid")
	h.Parent = m
	m.PrimaryPart = r
	m.Parent = services.Workspace
	g.Character = m
	return r
end
local function rootOf(g)
	return g.Character:FindFirstChild("HumanoidRootPart")
end
local function at(g)
	return rootOf(g).CFrame.Position
end
-- What an exploit tool (or a guest's own screen) does: moves the root, as replication would.
local function shove(g, by)
	local r = rootOf(g)
	r.CFrame = r.CFrame + by
end
local function caughtSince(n, who, why)
	for i = n + 1, #caughtLog do
		local c = caughtLog[i]
		if c.who == who and (why == nil or c.why == why) then
			return c
		end
	end
	return nil
end
-- Walks (or runs) `g` along +X at `speed` studs a second for `seconds`, a step every tenth.
local function walk(g, speed, seconds, dir)
	local d = dir or Vector3.new(1, 0, 0)
	for _ = 1, math.floor(seconds * 10 + 0.5) do
		shove(g, d * speed * 0.1)
		advance(0.1)
	end
end

local ivy = H.guest("Ivy", 501)
body(ivy, Vector3.new(0, 3, 0))
advance(Config.data.Integrity.spawnGrace + 0.5)

---------------------------------------------------------------------------------------------------
-- 1. Walking and running as anyone can
---------------------------------------------------------------------------------------------------
local n0 = #caughtLog
walk(ivy, Config.data.Movement.walkSpeed, 3)
walk(ivy, Config.data.Movement.runSpeed, 3)
check("walking and running as anyone can: never caught", caughtSince(n0, "Ivy") == nil and Integrity.trusted(ivy) and Integrity.strikes(ivy) == 0, #caughtLog - n0)
check("...and never moved back", math.abs(at(ivy).X - (Config.data.Movement.walkSpeed * 3 + Config.data.Movement.runSpeed * 3)) < 0.5, at(ivy))
-- Up a staircase at a run (as steep as any in the house).
n0 = #caughtLog
walk(ivy, Config.data.Movement.runSpeed, 2, Vector3.new(0.7, 0.7, 0))
check("running up a staircase: not a flight", caughtSince(n0, "Ivy") == nil)
-- A lag spike: nothing from their screen for two seconds, then the walk it missed, all at once.
advance(2)
n0 = #caughtLog
shove(ivy, Vector3.new(Config.data.Movement.runSpeed * 1.8, 0, 0))
advance(0.1)
check("a lag spike's burst (two seconds' running in one step) is a walk, not a jump", caughtSince(n0, "Ivy") == nil and Integrity.trusted(ivy))
-- Falling off the roof is falling.
n0 = #caughtLog
for _ = 1, 15 do
	shove(ivy, Vector3.new(0, -8, 0))
	advance(0.1)
end
check("falling a long way: not caught", caughtSince(n0, "Ivy") == nil)

---------------------------------------------------------------------------------------------------
-- 2. What exploit tools do
---------------------------------------------------------------------------------------------------
-- A teleport: put back at once, where they just were, and nothing found for a moment.
local was = at(ivy)
n0 = #caughtLog
shove(ivy, Vector3.new(220, 0, 140))
advance(0.15)
local c = caughtSince(n0, "Ivy", "teleport")
check("a teleport is caught", c ~= nil and c.distance > 200, c and c.why)
check("...and put back where they were", (at(ivy) - was).Magnitude < 1, (at(ivy) - was).Magnitude)
check("...and finds nothing for a moment", Integrity.trusted(ivy) == false and Integrity.near(ivy, at(ivy), 10) == false)
advance(Config.data.Integrity.suspectFor + 0.2)
check("...then may find things again", Integrity.trusted(ivy) and Integrity.near(ivy, at(ivy), 10) == true)
-- A speed hack: twice their run, held.
was = at(ivy)
n0 = #caughtLog
walk(ivy, Config.data.Movement.runSpeed * 2.2, 2)
c = caughtSince(n0, "Ivy", "speed")
check("running far faster than anyone can is caught", c ~= nil, #caughtLog - n0)
check("...and they get nowhere by it", (at(ivy) - was).Magnitude < Config.data.Movement.runSpeed * 2, (at(ivy) - was).Magnitude)
advance(4)
-- Flying: rising steadily, far above any jump or staircase (twice their run, straight up).
n0 = #caughtLog
walk(ivy, Config.data.Movement.runSpeed * 2, 2.5, Vector3.new(0, 1, 0))
check("flying up is caught", caughtSince(n0, "Ivy", "flight") ~= nil)
check("strikes are counted for the minute", Integrity.strikes(ivy) >= 3, Integrity.strikes(ivy))
advance(4)

---------------------------------------------------------------------------------------------------
-- 3. What's never caught
---------------------------------------------------------------------------------------------------
-- The house's own moves: a trip, a seat across the house, a ride.
n0 = #caughtLog
run(function()
	Integrity.teleport(ivy, ivy.Character, CFrame.new(500, 3, -300))
end)
advance(0.5)
check("the house's own teleport: never caught, and they're there", caughtSince(n0, "Ivy") == nil and (at(ivy) - Vector3.new(500, 3, -300)).Magnitude < 0.5)
Integrity.moved(ivy)
shove(ivy, Vector3.new(0, 300, 0))
advance(0.3)
check("a move the house says it made (a ride's hold high over the Pole): not caught", caughtSince(n0, "Ivy") == nil)
advance(3)
-- Seated: the chair (or the sleigh) moves them.
local h = ivy.Character:FindFirstChildOfClass("Humanoid")
h.Sit = true
walk(ivy, 120, 1)
h.Sit = false
advance(0.3)
check("seated (a sleigh, a chair): never caught", caughtSince(n0, "Ivy") == nil)
-- Held still by the house (anchored).
rootOf(ivy).Anchored = true
shove(ivy, Vector3.new(400, 0, 0))
advance(0.3)
rootOf(ivy).Anchored = false
advance(0.3)
check("held by the house (anchored): never caught", caughtSince(n0, "Ivy") == nil)
-- An effect the owner switched on throws everyone about.
services.Workspace:SetAttribute("Fx_blackHole", 1)
walk(ivy, 150, 1)
services.Workspace:SetAttribute("Fx_blackHole", nil)
advance(0.3)
check("while one of the owner's effects is on: nobody is caught", caughtSince(n0, "Ivy") == nil)
-- A one-shot effect (a rocket launch): everyone moves freely for its length.
run(function()
	Integrity.excuseAll(4)
end)
walk(ivy, 140, 2, Vector3.new(0.3, 1, 0))
check("a launch from one of the owner's effects: not caught", caughtSince(n0, "Ivy") == nil)
advance(Config.data.Integrity.effectGrace + 3)
-- Zero-G: the house's gravity is low.
local gravity = services.Workspace.Gravity
services.Workspace.Gravity = 40
walk(ivy, 50, 2, Vector3.new(0, 1, 0))
services.Workspace.Gravity = gravity
advance(0.3)
check("in zero-G (the house's gravity low): not caught", caughtSince(n0, "Ivy") == nil)
-- A perk and an event: a guest with Velocity Elite in the Quickstep runs faster, and may.
ivy:SetAttribute("SpeedPerk", 1.25)
services.Workspace:SetAttribute("SpeedBoost", 1.2)
walk(ivy, Config.data.Movement.maxSpeed, 3)
ivy:SetAttribute("SpeedPerk", nil)
services.Workspace:SetAttribute("SpeedBoost", nil)
check("running at the house's fastest with a perk and the Quickstep: not caught", caughtSince(n0, "Ivy") == nil)
-- A new character (a respawn) is put somewhere new.
body(ivy, Vector3.new(-900, 3, 900))
advance(0.3)
check("a respawn far away: not caught", caughtSince(n0, "Ivy") == nil)
advance(Config.data.Integrity.spawnGrace)

-- The owner: their own powers move them however they like.
local owner = H.guest("AJKR", OWNER)
body(owner, Vector3.new(0, 3, 0))
advance(Config.data.Integrity.spawnGrace + 0.5)
n0 = #caughtLog
shove(owner, Vector3.new(600, 0, 0))
advance(0.2)
walk(owner, 150, 2)
walk(owner, 80, 2, Vector3.new(0, 1, 0))
check("the owner: never caught (their powers move them as they like)", caughtSince(n0, "AJKR") == nil and Integrity.trusted(owner))

---------------------------------------------------------------------------------------------------
-- 4. Every teleport the server makes goes through Integrity.teleport
---------------------------------------------------------------------------------------------------
local raw = {}
local function scan(dir)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			scan(path)
		elseif string.sub(name, -5) == ".luau" and name ~= "Integrity.luau" then
			local i = 0
			for line in string.gmatch(fs.readFile(path), "[^\n]*") do
				i += 1
				if string.find(line, "[Cc]haracter:PivotTo%(") or string.find(line, "theirs:PivotTo%(") or string.find(line, "%f[%w]c:PivotTo%(") then
					table.insert(raw, path .. ":" .. i)
				end
			end
		end
	end
end
scan("src/server")
check("no server code moves a guest's character but through Integrity.teleport", #raw == 0, table.concat(raw, ", "))

H.finish()

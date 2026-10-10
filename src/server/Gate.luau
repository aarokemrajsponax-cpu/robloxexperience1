--!strict
-- Roblox's MemoryStore (the live leaderboards, the weekend's standings) sometimes doesn't answer:
-- "InternalError: Unknown Error", most often in Studio. Roblox writes each failure to the output in
-- red, caught or not, so asking again and again only fills the owner's screen with red lines. A
-- structure that has just failed is left to rest a while instead (a minute, then two, four... up
-- to half an hour), and the boards show this server's own scores meanwhile. One answer and it's
-- asked as usual again.
--   Reads always wait out the rest. Writes (a guest's score) wait only in Studio: in a live game a
--   score is always offered to the board, whatever happened a minute ago.

local RunService = game:GetService("RunService")

local Gate = {}

local FIRST = 60
local LONGEST = 1800

type Rest = { untilAt: number, wait: number }
local resting: { [string]: Rest } = {}

local function mark(name: string, ok: boolean)
	if ok then
		resting[name] = nil
		return
	end
	local r = resting[name]
	local wait = if r then math.min(LONGEST, r.wait * 2) else FIRST
	resting[name] = { untilAt = os.clock() + wait, wait = wait }
end

-- Whether a structure is resting just now (a read of it would be skipped).
function Gate.resting(name: string): boolean
	local r = resting[name]
	return r ~= nil and os.clock() < r.untilAt
end

-- A read: skipped (false) while the structure rests; otherwise asked, its answer or failure noted.
function Gate.read<T>(name: string, fn: () -> T): (boolean, T?)
	if Gate.resting(name) then
		return false, nil
	end
	local ok, result = pcall(fn)
	mark(name, ok)
	if ok then
		return true, result
	end
	return false, nil
end

-- A write: in Studio it waits out a rest like a read; in a live game it's always tried.
function Gate.write(name: string, fn: () -> ()): boolean
	if RunService:IsStudio() and Gate.resting(name) then
		return false
	end
	local ok = pcall(fn)
	mark(name, ok)
	return ok
end

-- (For the checks: everything back to normal.)
function Gate.reset()
	resting = {}
end

return Gate

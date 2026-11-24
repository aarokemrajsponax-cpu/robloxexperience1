--!strict
-- (Build 102) When the house may announce things on this screen: only once the guest has pressed
-- Play and is in the game, never over the Home Screen or the intro. Every announcement (the Grand
-- Ballroom's Showtime banner, the events strip, headlines, the herald, messages from the owner)
-- asks here first.
--
--   Announce.ready()          true once the guest is playing
--   Announce.after(key, fn)   runs fn now if ready, else once when Play is pressed; a later call
--                             with the same key replaces the waiting one (so nothing stacks)
--   Announce.once(key)        true the first time a key is seen this visit (never the same twice)

local State = require(script.Parent.Parent.State)

local Announce = {}

local waiting: { [string]: () -> () } = {}
local order: { string } = {}
local seen: { [string]: boolean } = {}

function Announce.ready(): boolean
	return State.phase == "play"
end

function Announce.once(key: string): boolean
	if seen[key] then
		return false
	end
	seen[key] = true
	return true
end

function Announce.after(key: string, fn: () -> ())
	if Announce.ready() then
		fn()
		return
	end
	if waiting[key] == nil then
		table.insert(order, key)
	end
	waiting[key] = fn
end

-- Pressed Play: what waited goes out, a moment apart, oldest first (never stacked at once).
local function flush()
	if not Announce.ready() or #order == 0 then
		return
	end
	local list = order
	local fns = waiting
	order = {}
	waiting = {}
	task.spawn(function()
		task.wait(2.5)
		for i, key in list do
			local fn = fns[key]
			if fn then
				pcall(fn)
			end
			if i < #list then
				task.wait(4)
			end
		end
	end)
end

State.PhaseChanged:Connect(flush)

return Announce

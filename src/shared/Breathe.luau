--!strict
-- Long work, done in breaths. Roblox stops any script that runs for about ten seconds without
-- pausing (Studio's "script timeout"), and on a slower computer building the whole house in one
-- go can take longer than that, which leaves an empty world and nobody spawned. Calling
-- Breathe.now() inside a long loop pauses for a frame whenever the work has run a little while,
-- so no stretch ever comes near the limit. Outside a running game (the tests) it never pauses.

local RunService = game:GetService("RunService")

local Breathe = {}

local last = os.clock()
local live: boolean? = nil

-- Pauses for a frame if the work has gone on for more than `budget` seconds (default 0.25).
function Breathe.now(budget: number?)
	if live == nil then
		local ok, running = pcall(function()
			return RunService:IsRunning()
		end)
		live = ok and running == true
	end
	if not live then
		return
	end
	if os.clock() - last > (budget or 0.25) then
		task.wait()
		last = os.clock()
	end
end

-- Starts a fresh breath (call at the start of a long job).
function Breathe.reset()
	last = os.clock()
end

return Breathe

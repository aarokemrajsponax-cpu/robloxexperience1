--!strict
-- How fast a guest walks: the one place every speed effect meets, so no system can overwrite
-- another's. Walking or running, times the house's event (the Quickstep), times the guest's own
-- perk (VIP Velocity Elite, set by the server as the "SpeedPerk" attribute), never above the cap.

local Config = require(script.Parent.Config)

local Speed = {}

-- `running`: Shift (or the left stick) held. `event` and `perk`: multipliers (read from
-- attributes, so anything that isn't a positive number counts as none).
function Speed.resolve(running: boolean, event: any, perk: any): number
	local m = Config.data.Movement
	local base = if running then m.runSpeed else m.walkSpeed
	local e = if type(event) == "number" and event > 0 and event == event then event else 1
	local p = if type(perk) == "number" and perk > 0 and perk == perk then perk else 1
	return math.min(m.maxSpeed, base * e * p)
end

return Speed

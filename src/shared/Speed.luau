--!strict
-- How fast a guest walks: the one place every speed effect meets, so no system can overwrite
-- another's. Walking or running, times the house's event (the Quickstep), times the guest's own
-- perk (VIP Velocity Elite, set by the server as the "SpeedPerk" attribute), never above the cap.
-- The owner's own speed power ("AdminSpeed", set only by the server for the owner) has its own,
-- higher cap.

local Config = require(script.Parent.Config)

local Speed = {}

-- `running`: Shift (or the left stick) held. `event` and `perk`: multipliers (read from
-- attributes, so anything that isn't a positive number counts as none).
-- `trained`: Steal a Luxe's own (its Stride, and the weight of the bag), set by the server as the
-- "SpeedTrained" attribute only while a guest is in the residence; with it the cap is higher.
-- `away`: the attraction a guest is in (the server's "Attraction" attribute). The few whose guards,
-- gaps and timings were set for a guest's pace (Config.Movement.tuned) keep that pace; everywhere
-- else is walked at the house's own, brisker pace (the house is drawn grander). In those few,
-- VIP Velocity Elite's perk doesn't count either: it's for getting round the house, not for winning.
function Speed.tuned(away: any): boolean
	local m = Config.data.Movement :: any
	return type(away) == "string" and type(m.tuned) == "table" and m.tuned[away] == true
end

function Speed.resolve(running: boolean, event: any, perk: any, owner: any, trained: any, away: any): number
	local m = Config.data.Movement :: any
	local tuned = Speed.tuned(away)
	local walk = if tuned then tonumber(m.tunedWalkSpeed) or m.walkSpeed else m.walkSpeed
	local run = if tuned then tonumber(m.tunedRunSpeed) or m.runSpeed else m.runSpeed
	local base = if running then run else walk
	local e = if type(event) == "number" and event > 0 and event == event then event else 1
	-- A bought perk never counts where guests compete (the tuned attractions): no pay-to-win.
	local p = if not tuned and type(perk) == "number" and perk > 0 and perk == perk then perk else 1
	local t = if type(trained) == "number" and trained > 0 and trained == trained then trained else 1
	if type(owner) == "number" and owner > 1 and owner == owner then
		return math.min(Config.data.Admin.speedCap, base * e * p * t * owner)
	end
	local most = if tuned then tonumber(m.tunedMaxSpeed) or m.maxSpeed else m.maxSpeed
	local cap = if t > 1 then math.max(most, tonumber(m.trainedMaxSpeed) or most) else most
	return math.min(cap, base * e * p * t)
end

return Speed

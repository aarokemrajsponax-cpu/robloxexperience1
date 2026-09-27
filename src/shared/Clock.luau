--!strict
-- The clock in timed rooms (Appendix D). Pure arithmetic; the server owns the running clock.

local Config = require(script.Parent.Config)
local Rooms = require(script.Parent.Rooms)

local Clock = {}

function Clock.budget(room: Rooms.Room, dealSize: number): number?
	local t = room.tuning
	if t.clockBase == nil or t.clockPerPiece == nil then
		return nil
	end
	return t.clockBase + t.clockPerPiece * dealSize
end

-- Seconds returned by a correct filing, +50% when the multiplier is high. Never above the budget.
function Clock.refund(room: Rooms.Room, multiplier: number, secondsLeft: number, budget: number): number
	local t = room.tuning
	local c = Config.data.Clock
	if t.clockRefund == nil then
		return secondsLeft
	end
	local refund = t.clockRefund
	if multiplier >= c.refundBoostFromMultiplier then
		refund *= c.refundBoost
	end
	return math.min(budget, secondsLeft + refund)
end

-- Seconds taken by a wrong filing. Never below zero.
function Clock.penalty(room: Rooms.Room, secondsLeft: number): number
	local t = room.tuning
	if t.clockPenalty == nil then
		return secondsLeft
	end
	return math.max(0, secondsLeft - t.clockPenalty)
end

function Clock.isLow(secondsLeft: number): boolean
	return secondsLeft <= Config.data.Clock.lowAt
end

return Clock

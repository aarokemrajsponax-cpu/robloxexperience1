--!strict
-- The Hourly Drop (Build 91), shared by the server (which decides) and every screen (which shows
-- it): on the hour, every hour, by the clock (UTC, so the same moment in every server), a courier's
-- case comes down onto its plinth in the Foyer and stays open for Config.HourlyDrop.openMinutes.
-- Each guest opens it once that hour. Its piece is one of six, in turn by the hour, so each piece
-- is back every six hours: the times are real and the same for everyone, never a made-up clock.
--
--   HourlyDrop.hourOf(t)      which hour `t` is in (hours since 1970, UTC)
--   HourlyDrop.isOpen(t)      whether the case is open at `t`
--   HourlyDrop.closesAt(t)    when this hour's case closes
--   HourlyDrop.nextAt(t)      when the next case comes down (the next hour, on the hour)
--   HourlyDrop.pieceOf(hour)  that hour's piece (a curio id)
--   HourlyDrop.nextOf(id, t)  when that piece is next in the case

local Config = require(script.Parent.Config)

local HourlyDrop = {}

HourlyDrop.HOUR = 3600
-- The pieces, in the order they come (shared/Curios has each).
HourlyDrop.Pieces = { "courierSeal", "midnightRibbon", "courierWatch", "monogramCard", "hourChampagne", "velvetRingBox" }

local function cfg(): { [string]: any }
	return (Config.data :: any).HourlyDrop or {}
end

-- How long the case stays open each hour, in seconds.
function HourlyDrop.window(): number
	return math.clamp((tonumber(cfg().openMinutes) or 15) * 60, 60, HourlyDrop.HOUR)
end

function HourlyDrop.enabled(): boolean
	return cfg().enabled ~= false
end

function HourlyDrop.hourOf(t: number): number
	return math.floor(t / HourlyDrop.HOUR)
end

function HourlyDrop.isOpen(t: number): boolean
	return HourlyDrop.enabled() and t - HourlyDrop.hourOf(t) * HourlyDrop.HOUR < HourlyDrop.window()
end

function HourlyDrop.closesAt(t: number): number
	return HourlyDrop.hourOf(t) * HourlyDrop.HOUR + HourlyDrop.window()
end

function HourlyDrop.nextAt(t: number): number
	return (HourlyDrop.hourOf(t) + 1) * HourlyDrop.HOUR
end

function HourlyDrop.pieceOf(hour: number): string
	return HourlyDrop.Pieces[hour % #HourlyDrop.Pieces + 1]
end

-- When `id` is next in the case: this hour's, if it's that piece and the case is still open.
function HourlyDrop.nextOf(id: string, t: number): number?
	local i = table.find(HourlyDrop.Pieces, id)
	if not i then
		return nil
	end
	local hour = HourlyDrop.hourOf(t)
	if HourlyDrop.pieceOf(hour) == id and HourlyDrop.isOpen(t) then
		return hour * HourlyDrop.HOUR
	end
	for k = 1, #HourlyDrop.Pieces do
		if HourlyDrop.pieceOf(hour + k) == id then
			return (hour + k) * HourlyDrop.HOUR
		end
	end
	return nil
end

-- "4:12" or "1:04:12": a time left, as a clock shows it.
function HourlyDrop.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	local h, m = s // 3600, (s // 60) % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s % 60)
	end
	return string.format("%d:%02d", m, s % 60)
end

return HourlyDrop

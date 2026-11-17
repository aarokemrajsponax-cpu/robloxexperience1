--!strict
-- (Build 93) Showtime: every half hour, at twenty past and ten to (by the house's clock, UTC: the
-- same moment in every server), one of the Grand Ballroom's party games has its Showtime for eight
-- minutes: Luxury Trivia, then the Runway, then the Daily Arena, in turn. Everyone in the house is
-- called to it by a banner with a key that takes them there; a round of it played while Showtime is
-- on pays a Showtime bonus of Gilt, once each Showtime (server/Showtime decides, by the clock and
-- the guest's own record). The games themselves are open all the time, as always: Showtime only
-- gathers everyone at once. (Clear of the Hourly Drop, which comes down on the hour.)
--
-- Pure numbers, shared by the server and the screens: every time here is a Unix time in seconds.

local Showtime = {}

Showtime.EVERY = 30 * 60 -- a Showtime every half hour
Showtime.OFFSET = 20 * 60 -- the first of each hour at twenty past (the next at ten to)
Showtime.LENGTH = 8 * 60 -- each lasts eight minutes
Showtime.GRACE = 3 * 60 -- a round that was under way as it closed still counts, if it ends this soon after

export type Game = { kind: string, name: string, where: string, line: string, glyph: string }

-- The games it calls everyone to, in turn.
Showtime.GAMES = {
	{ kind = "trivia", name = "Luxury Trivia", where = "the Salon of Wits", line = "Seven questions at the podiums: the quickest right answer wins.", glyph = "🎓" },
	{ kind = "runway", name = "The Runway", where = "the Runway", line = "Walk the catwalk in tonight's theme, strike a pose, and the room votes.", glyph = "👠" },
	{ kind = "arena", name = "The Daily Arena", where = "the Daily Arena", line = "Today's quick challenge in the ring, everyone at once.", glyph = "🏟️" },
} :: { Game }

-- Which Showtime a moment falls in (or the last one before it): its number.
function Showtime.slotOf(t: number): number
	return math.floor((t - Showtime.OFFSET) / Showtime.EVERY)
end

function Showtime.startOf(slot: number): number
	return slot * Showtime.EVERY + Showtime.OFFSET
end

function Showtime.closesAt(slot: number): number
	return Showtime.startOf(slot) + Showtime.LENGTH
end

function Showtime.gameOf(slot: number): Game
	return Showtime.GAMES[(slot % #Showtime.GAMES) + 1]
end

-- Whether Showtime is on at `t`.
function Showtime.isOpen(t: number): boolean
	local slot = Showtime.slotOf(t)
	return t >= Showtime.startOf(slot) and t < Showtime.closesAt(slot)
end

-- When the next Showtime begins after `t` (the one on now counts as begun), and its number.
function Showtime.nextAt(t: number): (number, number)
	local slot = Showtime.slotOf(t) + 1
	return Showtime.startOf(slot), slot
end

-- Whether a round of `kind` ending at `t` counts for a Showtime: on now, or closed within the grace
-- (a round under way as it closed). Its number if so.
function Showtime.counts(kind: string, t: number): number?
	local slot = Showtime.slotOf(t)
	if t < Showtime.startOf(slot) or t >= Showtime.closesAt(slot) + Showtime.GRACE then
		return nil
	end
	return if Showtime.gameOf(slot).kind == kind then slot else nil
end

-- "7:42" (minutes and seconds) for a number of seconds.
function Showtime.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Showtime

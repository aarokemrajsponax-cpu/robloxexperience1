--!strict
-- (Build 93) Showtime on the server (shared/Showtime has the schedule): publishes what's on for
-- every screen (the Workspace's "ShowtimeSlot", "ShowtimeOpen" and "ShowtimeGame"), and pays the
-- Showtime bonus to a guest who plays a round of the called game while it's on (the Grand
-- Ballroom tells it each round a guest finished: Gala.played).
--   * Only the server's clock decides whether Showtime is on and which game it called.
--   * Once each Showtime, in the guest's own record (a once-mark per Showtime: rejoining or another
--     server never pays it twice).
--   * Paid outside the Ballroom's own daily cap, through the house's Gilt like any other reward.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Plan = require(ReplicatedStorage.Shared.Showtime)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Achievements = require(script.Parent.Achievements)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)

local Showtime = {}

Showtime.STAT = "showtimes"

-- The clock (set for tests).
Showtime.now = function(): number
	return os.time()
end
-- Counts a Showtime in the guest's record, once for `once` (set by Main: with its XP). Whether it
-- counted.
Showtime.tally = function(player: Player, stat: string, n: number, once: string?): boolean
	return Achievements.tally(player, stat, n, once)
end

local function cfg(): { enabled: boolean, gilt: number }
	return (Config.data :: any).Showtime or { enabled = false, gilt = 0 }
end

-- What's on, for every screen.
function Showtime.publish()
	local now = Showtime.now()
	local slot = Plan.slotOf(now)
	local open = cfg().enabled == true and Plan.isOpen(now)
	Workspace:SetAttribute("ShowtimeSlot", slot)
	Workspace:SetAttribute("ShowtimeOpen", open)
	Workspace:SetAttribute("ShowtimeGame", Plan.gameOf(slot).kind)
end

-- A guest finished a round of one of the Ballroom's games (`kind`: trivia, runway or arena). Pays
-- the Showtime bonus if it's the game Showtime called and it was played while it was on; the Gilt
-- paid (0 if none).
function Showtime.played(player: Player, kind: string): number
	if cfg().enabled ~= true then
		return 0
	end
	local slot = Plan.counts(kind, Showtime.now())
	if not slot then
		return 0
	end
	local data = Profiles.get(player)
	if not data then
		return 0
	end
	if not Showtime.tally(player, Showtime.STAT, 1, tostring(slot)) then
		return 0
	end
	local paid = Gilt.pay(player, data, math.max(0, math.floor(tonumber(cfg().gilt) or 0)), "Showtime")
	local g = Plan.gameOf(slot)
	Remotes.event("Shop"):FireClient(player, {
		op = "notice",
		title = "Showtime",
		line = string.format("+%d Gilt for playing %s at Showtime.", paid, g.name),
	})
	return paid
end

function Showtime.start()
	Showtime.publish()
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(Showtime.publish)
		end
	end)
end

return Showtime

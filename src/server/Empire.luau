--!strict
-- The Empire: everything the house does toward its one aim (build your fortune, master the Maison,
-- become the wealthiest), started together and wired to the rest of the house in one place.
--   Fortune      what every guest owns, the wealth ranks and the Wealthiest boards
--   Herald       feats told to the whole house
--   Attractions  Steal a Luxe, the Maison Basement and the Executive Suite (server/Attractions)
-- Each part starts on its own: one that fails is reported in Output and the rest carry on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Fortune)
local Fortune = require(script.Parent.Fortune)
local Herald = require(script.Parent.Herald)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Empire = {}

---------------------------------------------------------------------------------------------------
-- Hooks (set by Main)
---------------------------------------------------------------------------------------------------
-- Whether a guest is busy at a table (the Salon, a duel, the Ballroom).
Empire.isSeated = function(_player: Player): boolean
	return false
end
-- A badge (Achievements.award), and a count for the Badge Book and XP (AdminService.tally).
Empire.award = function(_player: Player, _key: string) end
Empire.tally = function(_player: Player, _stat: string, _n: number, _once: string?) end
-- Whether a guest is the owner.
Empire.isOwner = function(_player: Player): boolean
	return false
end

Empire.Fortune = Fortune
Empire.Herald = Herald

local started: { string } = {}
local function part(name: string, fn: () -> ())
	local ok, err = xpcall(fn :: any, function(e: any)
		return debug.traceback(tostring(e))
	end)
	if ok then
		table.insert(started, name)
	else
		warn(string.format("[Maison] The Empire: %s didn't start: %s", name, tostring(err)))
	end
end

local ASK_KEYS = { op = true, id = true, n = true, on = true }

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 4, 0)
	if not r then
		RemoteGuard.reject(player, "empireAsk", "malformed")
		return { ok = false, why = "That isn't something the house does." }
	end
	for k in r do
		if not ASK_KEYS[k] then
			RemoteGuard.reject(player, "empireAsk", "malformed")
			return { ok = false, why = "That isn't something the house does." }
		end
	end
	if r.op == "fortune" then
		return Fortune.view(player)
	end
	return { ok = false, why = "That isn't something the house does." }
end

function Empire.start()
	part("Fortunes", function()
		-- A new wealth rank: the guest is told, and from a certain rank the whole house.
		Fortune.ranked = function(player: Player, rank: Rules.Rank, number: number, public: boolean)
			Remotes.event("Empire"):FireClient(player, { op = "rank", rank = number, name = rank.name, line = rank.line })
			Empire.tally(player, "wealthRanks", 1, "rank" .. number)
			if public then
				Herald.feat(player, { kind = "rank", title = "A NEW " .. string.upper(rank.name), line = "has built a fortune worthy of the name " .. rank.name, glyph = "👑", worth = rank.at })
			end
		end
		Fortune.start()
	end)
	part("The herald", Herald.start)
	part("The Empire's questions", function()
		RemoteGuard.invoke(Remotes.func("EmpireAsk"), "empireAsk", onAsk)
	end)
end

-- For tests.
function Empire.started(): { string }
	return started
end

return Empire

--!strict
-- House Standing (§11): Guest → Member → Patron → Connoisseur → Custodian → Keeper of the House.
-- Earned by coming back (Nights attended) and by playing (rounds cleared). Member opens ranked play.

local Config = require(script.Parent.Config)

local Standing = {}

Standing.order = { "Guest", "Member", "Patron", "Connoisseur", "Custodian", "Keeper of the House" }

local KEYS = { "member", "patron", "connoisseur", "custodian", "keeper" }

function Standing.of(nights: number, rounds: number): (string, number)
	local s = Config.data.Standing :: any
	local level = 1
	for i, key in KEYS do
		if nights >= s[key .. "Nights"] and rounds >= s[key .. "Rounds"] then
			level = i + 1
		else
			break
		end
	end
	return Standing.order[level], level
end

function Standing.atLeast(nights: number, rounds: number, name: string): boolean
	local _, level = Standing.of(nights, rounds)
	local want = table.find(Standing.order, name) or 1
	return level >= want
end

return Standing

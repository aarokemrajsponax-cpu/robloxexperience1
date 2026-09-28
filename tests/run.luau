--!nonstrict
-- Pure-rule tests, run outside Roblox with the standalone Luau runtime.
-- Usage: python3 tests/bundle.py > /tmp/bundle.luau && luau /tmp/bundle.luau
--
-- Roblox globals the shared modules touch (Random, Color3, Font, Enum, Vector3, CFrame, os.date)
-- are shimmed below. The shim RNG is deterministic per seed, which is all the rules need.

local function xorshift(seed)
	local state = (seed * 2654435761 + 12345) % 4294967296
	if state == 0 then
		state = 1
	end
	return function()
		state = bit32.bxor(state, bit32.lshift(state, 13) % 4294967296)
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5) % 4294967296)
		return state / 4294967296
	end
end

Random = {}
Random.__index = Random
function Random.new(seed)
	return setmetatable({ next = xorshift(seed or os.clock() * 1e6) }, Random)
end
function Random:NextNumber(a, b)
	local r = self.next()
	if a and b then
		return a + r * (b - a)
	end
	return r
end
function Random:NextInteger(a, b)
	return a + math.floor(self.next() * (b - a + 1))
end

local function colour(r, g, b)
	return setmetatable({ R = r, G = g, B = b }, { __index = { Lerp = function(self, other, t)
		return colour(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
	end } })
end
Color3 = {
	fromRGB = function(r, g, b) return colour(r / 255, g / 255, b / 255) end,
	fromHex = function(h) return colour(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255) end,
	new = function(r, g, b) return colour(r or 0, g or 0, b or 0) end,
}
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
CFrame = { new = function() return {} end, Angles = function() return {} end }
Font = { fromEnum = function(e) return e end, new = function(n) return n end }
Enum = setmetatable({}, { __index = function(_, k) return setmetatable({}, { __index = function(_, v) return k .. "." .. v end }) end })
Instance = { new = function() error("Instance.new is not available in tests") end }
TweenInfo = { new = function(...) return { ... } end }
game = { GetService = function() return {} end }

--[[LOADER]]

local passed, failed = 0, 0
local function check(name, ok, detail)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL  " .. name .. (detail and ("  -> " .. tostring(detail)) or ""))
	end
end

local Seasons = loadModule("Seasons")
local Catalogue = loadModule("Catalogue")
local Rooms = loadModule("Rooms")
local Deal = loadModule("Deal")
local Scoring = loadModule("Scoring")
local Settings = loadModule("Settings")
local Seed = loadModule("Seed")
local Config = loadModule("Config")
local Voice = loadModule("Voice")
local Clock = loadModule("Clock")

-- 1. Every date of a leap year maps to exactly one season.
do
	local daysIn = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
	local total, bad = 0, 0
	local counts = {}
	for m = 1, 12 do
		for d = 1, daysIn[m] do
			total += 1
			local matches = 0
			for _, s in Seasons.List do
				local a, b = s.from[1] * 100 + s.from[2], s.to[1] * 100 + s.to[2]
				local x = m * 100 + d
				local inWin = if a <= b then (x >= a and x <= b) else (x >= a or x <= b)
				if inWin then matches += 1 end
			end
			if matches == 0 then bad += 1 end
			local s = Seasons.forDate(m, d)
			counts[s.id] = (counts[s.id] or 0) + 1
		end
	end
	check("leap year: 366 days", total == 366, total)
	check("leap year: every day has at least one season window", bad == 0, bad)
	check("Feb 29 is Deep Winter", Seasons.forDate(2, 29).id == "frost")
	check("Oct 20 is All Hallows (holiday beats Harvest)", Seasons.forDate(10, 20).id == "hallows")
	check("Nov 1 is All Hallows (holiday beats Long Table)", Seasons.forDate(11, 1).id == "hallows")
	check("Dec 30 is Midnight Toast", Seasons.forDate(12, 30).id == "toast")
	check("Jan 3 is Midnight Toast (wraps)", Seasons.forDate(1, 3).id == "toast")
	check("Jan 7 is Deep Winter", Seasons.forDate(1, 7).id == "frost")
	check("Mar 15 is Emerald Hour", Seasons.forDate(3, 15).id == "emerald")
	check("Mar 20 is First Bloom", Seasons.forDate(3, 20).id == "bloom")
	check("Sep 27 is Harvest Nights", Seasons.forDate(9, 27).id == "harvest")
	check("every season gets at least one day", (function()
		for _, s in Seasons.List do if not counts[s.id] then return false end end
		return true
	end)())
end

-- 2. Catalogue shape.
do
	check("35 core pieces", #Catalogue.Core == 35, #Catalogue.Core)
	check("21 seasonal pieces", #Catalogue.Seasonal == 21, #Catalogue.Seasonal)
	check("6 mythic pieces, one per case", (function()
		if #Catalogue.Mythic ~= 6 then return false end
		local seen = {}
		for _, m in Catalogue.Mythic do
			if seen[m.case] then return false end
			seen[m.case] = true
		end
		return true
	end)())
	check("every cluster piece exists", (function()
		for _, c in Catalogue.Clusters do for _, id in c do if not Catalogue.byId[id] then return false end end end
		return true
	end)())
	check("every case has core pieces", (function()
		for _, c in Catalogue.Cases do if #Catalogue.coreForCase(c.id) == 0 then return false end end
		return true
	end)())
	check("all ids unique", (function()
		local n = 0
		for _ in Catalogue.byId do n += 1 end
		return n == 35 + 21 + 6
	end)())
end

-- 3. Deal rules over 10,000 seeds, in every room and every round 1..8, with and without a season.
do
	local violations = {}
	local function note(kind) violations[kind] = (violations[kind] or 0) + 1 end
	local seeds = 10000
	local tested = 0
	local seasonalSeen, rareSeen = 0, 0
	for _, room in Rooms.all() do
		for round = 1, 8 do
			for i = 1, math.ceil(seeds / 32) do
				local seed = i * 7919 + round * 131 + #room.id
				local seasonId = if i % 2 == 0 then "hallows" else nil
				local result = Deal.generate(seed, room, round, seasonId, { allowMythic = false })
				tested += 1
				local expectedCases = math.min(6, room.tuning.casesRound1 + (round - 1))
				if #result.cases ~= expectedCases then note("cases open") end
				local expectedSize = math.min(room.tuning.firstDeal + math.floor((round - 1) * room.tuning.dealGrowth), room.tuning.maxDeal)
				if #result.pieces ~= expectedSize or result.size ~= expectedSize then note("deal size") end
				local open = {}
				for _, c in result.cases do open[c] = true end
				local counts, perCase, seasonalCount = {}, {}, 0
				for _, p in result.pieces do
					if not open[p.case] then note("closed-case piece") end
					if Catalogue.byId[p.id] == nil then note("unknown piece") end
					if Catalogue.byId[p.id].case ~= p.case then note("case mismatch") end
					counts[p.id] = (counts[p.id] or 0) + 1
					perCase[p.case] = true
					if p.seasonal then
						seasonalCount += 1
						if Catalogue.byId[p.id].season ~= seasonId then note("wrong season piece") end
					end
					if p.rare then rareSeen += 1 end
					if p.mythic then note("mythic when disallowed") end
				end
				for _, c in result.cases do if not perCase[c] then note("open case without a piece") end end
				local cap = if expectedSize >= 19 then 3 else 2
				for id, n in counts do if n > cap then note("repeat cap") end end
				local seasonalOpen = 0
				for _, sp in Catalogue.seasonalFor(seasonId) do if open[sp.case] then seasonalOpen += 1 end end
				local fillers = expectedSize - expectedCases
				if seasonalOpen > 0 and fillers > 0 then
					local want = math.max(1, math.min(4, math.round(expectedSize * 0.18)))
					want = math.min(want, fillers, seasonalOpen * cap)
					if seasonalCount ~= want then note("seasonal count") end
					seasonalSeen += seasonalCount
				elseif seasonalCount ~= 0 then
					note("seasonal without season")
				end
				-- Determinism: same inputs, same deal.
				local again = Deal.generate(seed, room, round, seasonId, { allowMythic = false })
				for k, p in result.pieces do
					local q = again.pieces[k]
					if q.id ~= p.id or q.rare ~= p.rare or q.seasonal ~= p.seasonal then note("not deterministic") end
				end
			end
		end
	end
	local clean = next(violations) == nil
	check(("deal rules hold over %d deals"):format(tested), clean, (function()
		local parts = {}
		for k, v in violations do table.insert(parts, k .. "=" .. v) end
		return table.concat(parts, ", ")
	end)())
	check("seasonal pieces were dealt in season", seasonalSeen > 0)
	check("rare pieces appear", rareSeen > 0)
	-- Rare rate sanity: Salon round 1 chance is 0.062 (+0.10 for value >= 170).
	local rareCount, pieceCount = 0, 0
	local salon = Rooms.get("salon")
	for i = 1, 4000 do
		local r = Deal.generate(i, salon, 1, nil, { allowMythic = false })
		for _, p in r.pieces do pieceCount += 1; if p.rare then rareCount += 1 end end
	end
	local rate = rareCount / pieceCount
	check("Salon round 1 rare rate near 6-8%", rate > 0.045 and rate < 0.10, rate)
	-- Mythic: with allowMythic, over many deals, it can happen and never leaves its case.
	Config.set("Rooms.salon.mythicChance", 50)
	local mythics = 0
	for i = 1, 500 do
		local r = Deal.generate(i, Rooms.get("salon"), 1, nil, { allowMythic = true })
		for _, p in r.pieces do
			if p.mythic then
				mythics += 1
				if Catalogue.mythicForCase(p.case).id ~= p.id then note("mythic wrong case") end
				if p.value ~= 200 then note("mythic value") end
			end
		end
	end
	Config.set("Rooms.salon.mythicChance", 40000)
	check("mythics land in their own case", mythics > 0 and violations["mythic wrong case"] == nil and violations["mythic value"] == nil, mythics)
	-- Lookalikes: Midnight round 3 has all six cases open; clusters must show up often.
	local clusterHits, total = 0, 0
	local midnight = Rooms.get("midnight")
	local inCluster = {}
	for _, c in Catalogue.Clusters do for _, id in c do inCluster[id] = true end end
	for i = 1, 300 do
		local r = Deal.generate(i, midnight, 3, nil, { allowMythic = false })
		for _, p in r.pieces do total += 1; if inCluster[p.id] then clusterHits += 1 end end
	end
	check("Midnight deals lean on lookalike clusters", clusterHits / total > 0.5, clusterHits / total)
end

-- 4. Scoring and grades match worked examples.
do
	check("multiplier: streak 0 -> x1", Scoring.multiplier(0) == 1)
	check("multiplier: streak 1 -> x1", Scoring.multiplier(1) == 1)
	check("multiplier: streak 2 -> x2", Scoring.multiplier(2) == 2)
	check("multiplier: streak 7 -> x4", Scoring.multiplier(7) == 4)
	check("multiplier caps at x10", Scoring.multiplier(50) == 10)
	local chrono = { value = 120, rare = false, seasonal = false, mythic = false }
	check("Chronograph, first filing, Salon = 120", Scoring.filingPoints(chrono, 1, 1.0) == 120)
	check("Chronograph, streak 2, Salon = 240", Scoring.filingPoints(chrono, 2, 1.0) == 240)
	check("Chronograph, streak 2, Midnight = 576", Scoring.filingPoints(chrono, 2, 2.4) == 576)
	local rareChrono = { value = 120, rare = true, seasonal = false, mythic = false }
	check("gilded Chronograph, first filing = 240", Scoring.filingPoints(rareChrono, 1, 1.0) == 240)
	local skull = { value = 210, rare = false, seasonal = true, mythic = false }
	check("Crystal Skull seasonal x1.35, streak 0 = 284 (round(283.5))", Scoring.filingPoints(skull, 0, 1.0) == 284)
	local mythic = { value = 200, rare = false, seasonal = false, mythic = true }
	check("Mythic scores as gilded 200 = 400", Scoring.filingPoints(mythic, 0, 1.0) == 400)
	check("set bonus: run 2 = 0", Scoring.setBonus(2) == 0)
	check("set bonus: run 3 = 120", Scoring.setBonus(3) == 120)
	check("set bonus: run 9 caps at 240", Scoring.setBonus(9) == 240)
	local bonus = Scoring.roundEnd(1, 0, 8, nil, 1.0)
	check("round I perfect, best streak 8, Salon: 600 + 200 = 800", bonus.total == 800, bonus.total)
	local timed = Scoring.roundEnd(2, 1, 5, 12, 1.3)
	-- no perfect; streak 5*25*1.3 = 162.5 -> 163 (round half away? math.round(162.5) = 163); time 12*15*1.3 = 234
	check("round II Velvet with a mistake: 163 + 234 = 397", timed.total == 397, timed.total)
	check("wrong penalty round 3 = 120", Scoring.wrongPenalty(3) == 120)
	local pts, label = Scoring.grade(1, 8, 8, nil)
	check("perfect untimed round grades Flawless at 100", pts == 100 and label == "Flawless", pts)
	local p2, l2 = Scoring.grade(0.9, 4, 10, 0.5)
	-- 0.9^1.4 = 0.86284 -> 51.77 ; 0.4*20 = 8 ; 0.5*20 = 10 -> 69.77 Polished
	check("90% accuracy, streak 4/10, half the clock = Polished (~69.8)", l2 == "Polished" and math.abs(p2 - 69.77) < 0.05, p2)
	local _, l3 = Scoring.grade(0.5, 1, 12, 0)
	check("half right with no clock left = Cleared", l3 == "Cleared")
	local p4 = Scoring.runGrade(1, 3, 3)
	-- streak over max(6, 3): 3/6 = 0.5 -> 10 ; 60 + 20 = 80 -> 90 Immaculate
	check("run grade floors the streak divisor at 6 (90 points)", math.abs(p4 - 90) < 1e-9, p4)
	check("gilt for a 9,000-point run = 225", Scoring.giltForRun(9000) == 225)
	check("gilt caps at 400", Scoring.giltForRun(50000) == 400)
end

-- 5. The clock never leaves its budget.
do
	local velvet = Rooms.get("velvet")
	local budget = Clock.budget(velvet, 10)
	check("Velvet budget for 10 pieces = 14 + 32 = 46", budget == 46, budget)
	check("refund never exceeds the budget", Clock.refund(velvet, 1, 45.8, budget) == 46)
	check("high multiplier refund is +50% (0.8 -> 1.2)", math.abs(Clock.refund(velvet, 4, 10, budget) - 11.2) < 1e-9)
	check("penalty never goes below zero", Clock.penalty(velvet, 1.0) == 0)
	check("Salon has no clock", Clock.budget(Rooms.get("salon"), 8) == nil)
	-- 5,000 random filings in every timed room: the clock stays within [0, budget].
	local rng = Random.new(99)
	local inside = true
	for _, id in { "velvet", "obsidian", "midnight" } do
		local room = Rooms.get(id)
		for size = 10, 28, 6 do
			local b = Clock.budget(room, size)
			local left = b
			for _ = 1, 5000 do
				if rng:NextNumber() < 0.7 then
					left = Clock.refund(room, rng:NextInteger(1, 10), left, b)
				else
					left = Clock.penalty(room, left)
				end
				left = math.max(0, left - rng:NextNumber(0, 1.5)) -- time passing
				if left < 0 or left > b then
					inside = false
				end
			end
		end
	end
	check("the clock never leaves its budget (5,000 random filings per room and size)", inside)
end

-- 6. Settings validate and sanitize.
do
	check("defaults cover every key", (function()
		local d = Settings.defaults()
		for _, def in Settings.Definitions do if d[def.key] == nil then return false end end
		return true
	end)())
	check("valid choice accepted", Settings.validate("chime", "Marimba"))
	check("invalid choice rejected", not Settings.validate("chime", "Kazoo"))
	check("level in range accepted", Settings.validate("musicLevel", 40))
	check("level out of range rejected", not Settings.validate("musicLevel", 140))
	check("unknown key rejected", not Settings.validate("season", "summer"))
	local s = Settings.sanitize({ chime = "Kazoo", musicLevel = 20, junk = true })
	check("sanitize keeps good, drops bad", s.chime == "Bells" and s.musicLevel == 20 and s.junk == nil)
end

-- 7. Seeds and voice helpers.
do
	check("hash is stable", Seed.hash("nightly-2026-11-14") == Seed.hash("nightly-2026-11-14"))
	check("hash differs by date", Seed.nightly(2026, 11, 14) ~= Seed.nightly(2026, 11, 15))
	check("roman IV", Voice.roman(4) == "IV")
	check("roman IX", Voice.roman(9) == "IX")
	check("fill replaces names", Voice.fill("Good to see you again, {name}.", { name = "AJKR" }) == "Good to see you again, AJKR.")
	check("no exclamation marks in any line", (function()
		local function scan(t)
			for _, v in t do
				if type(v) == "string" and v:find("!") then return false end
				if type(v) == "table" and not scan(v) then return false end
			end
			return true
		end
		return scan(Voice)
	end)())
	check("config override by path", Config.set("Rooms.salon.firstDeal", 9) and Config.get("Rooms.salon.firstDeal") == 9)
	Config.set("Rooms.salon.firstDeal", 8)
	check("config rejects unknown path", not Config.set("Rooms.salon.nothing", 1))
	check("config rejects wrong type", not Config.set("Rooms.salon.firstDeal", "nine"))
end

-- 8. The Nightly: the date decides everything, identically everywhere.
do
	local Nightly = loadModule("Nightly")
	-- 28 September 2026 is a Monday (Velvet rules); 2 October 2026 a Friday (Midnight Friday).
	local monday = Nightly.at(os.time({ year = 2026, month = 9, day = 28, hour = 12 }) + 0)
	check("28 Sep 2026 is Monday, Velvet rules", monday.weekday == "monday" and monday.room == "velvet", monday.weekday .. "/" .. monday.room)
	check("the night's key is the UTC date", monday.key == "2026-09-28", monday.key)
	local friday = Nightly.at(monday.day * 86400 + 4 * 86400 + 3600)
	check("Fridays are Midnight Fridays", friday.weekday == "friday" and friday.room == "midnight", friday.weekday)
	local sunday = Nightly.at(monday.day * 86400 - 86400 + 60)
	check("Sundays play Obsidian rules", sunday.weekday == "sunday" and sunday.room == "obsidian", sunday.weekday)
	check("every weekday has rules", (function()
		for i = 0, 6 do
			local n = Nightly.at(monday.day * 86400 + i * 86400 + 100)
			if Rooms.get(n.room) == nil then return false end
		end
		return true
	end)())
	check("same date and round, same seed", Nightly.seed("2026-09-28", 3) == Nightly.seed("2026-09-28", 3))
	check("rounds get different seeds", Nightly.seed("2026-09-28", 1) ~= Nightly.seed("2026-09-28", 2))
	check("dates get different seeds", Nightly.seed("2026-09-28", 1) ~= Nightly.seed("2026-09-29", 1))
	-- Identical deals for every guest: generate the Friday deal twice, compare piece by piece.
	local room = Rooms.get("midnight")
	local a = Deal.generate(Nightly.seed(friday.key, 1), room, 1, "harvest", { allowMythic = false })
	local b = Deal.generate(Nightly.seed(friday.key, 1), room, 1, "harvest", { allowMythic = false })
	local same = #a.pieces == #b.pieces
	for i, p in a.pieces do
		local q = b.pieces[i]
		if p.id ~= q.id or p.rare ~= q.rare or p.seasonal ~= q.seasonal then same = false end
	end
	check("the Nightly deal is identical on every server", same)
	-- Mythics never appear in the Nightly, even at absurd odds.
	Config.set("Rooms.midnight.mythicChance", 2)
	local mythic = false
	for r = 1, 5 do
		for _, p in Deal.generate(Nightly.seed(friday.key, r), room, r, nil, { allowMythic = false }).pieces do
			if p.mythic then mythic = true end
		end
	end
	Config.set("Rooms.midnight.mythicChance", 15000)
	check("no Mythics in the Nightly", not mythic)
	-- Board order: higher score first; equal scores go to the earlier finish.
	local t0 = monday.day * 86400
	check("a higher score ranks higher", Nightly.sortKey(5000, t0 + 3600) > Nightly.sortKey(4999, t0 + 60))
	check("ties go to the earlier finish", Nightly.sortKey(5000, t0 + 60) > Nightly.sortKey(5000, t0 + 3600))
	check("the score reads back from the sort key", Nightly.scoreFromSortKey(Nightly.sortKey(12345, t0 + 999)) == 12345)
end

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	os.exit(1)
end

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

-- 9. Ratings, Marks, Terms, Tête-à-Tête rules, Standing.
do
	local Rating = loadModule("Rating")
	local Duel = loadModule("Duel")
	local Standing = loadModule("Standing")
	-- Glickman's worked example (Glicko-2 paper, 2012): 1500/200/0.06 against three opponents.
	local player = { r = 1500, rd = 200, vol = 0.06 }
	local opps = { { r = 1400, rd = 30, vol = 0.06 }, { r = 1550, rd = 100, vol = 0.06 }, { r = 1700, rd = 300, vol = 0.06 } }
	local after = Rating.update(player, opps, { 1, 0, 0 }, 0.5)
	check("Glicko-2 rating matches the paper (1464.06)", math.abs(after.r - 1464.06) < 0.05, after.r)
	check("Glicko-2 deviation matches the paper (151.52)", math.abs(after.rd - 151.52) < 0.05, after.rd)
	check("Glicko-2 volatility matches the paper (0.05999)", math.abs(after.vol - 0.05999) < 0.00002, after.vol)
	local win = Rating.update(Rating.new(), { Rating.new() }, { 1 })
	local loss = Rating.update(Rating.new(), { Rating.new() }, { 0 })
	check("a win raises a new rating, a loss lowers it", win.r > 1500 and loss.r < 1500)
	check("even ratings are a coin flip", math.abs(Rating.winChance(Rating.new(), Rating.new()) - 0.5) < 1e-9)
	check("Brass below 1200", Rating.mark(1199).label == "Brass")
	check("Silver III at 1200", Rating.mark(1200).label == "Silver III", Rating.mark(1200).label)
	check("Silver I at 1399", Rating.mark(1399).label == "Silver I", Rating.mark(1399).label)
	check("Gold II at 1500", Rating.mark(1500).label == "Gold II", Rating.mark(1500).label)
	check("Diamond I at 1999", Rating.mark(1999).label == "Diamond I", Rating.mark(1999).label)
	check("Onyx at 2000", Rating.mark(2000).label == "Onyx")
	local compressed = Rating.newTerm({ r = 2100, rd = 60, vol = 0.06 })
	check("Term end eases 2100 to 1860 and lifts the deviation to 150", math.abs(compressed.r - 1860) < 1e-9 and compressed.rd == 150)
	check("Sep 27 2026 is the Autumn Term", Rating.term(os.time({ year = 2026, month = 9, day = 27, hour = 12 })).id == "2026-autumn")
	check("Jan 10 2027 is the Winter Term of 2026", Rating.term(os.time({ year = 2027, month = 1, day = 10, hour = 12 })).id == "2026-winter")
	check("hand sizes 14 to 26", Duel.hand(1).pieces == 14 and Duel.hand(5).pieces == 26)
	check("hand I opens four cases", Duel.hand(1).cases == 4)
	local r1 = Duel.room(1)
	local deal = Deal.generate(42, r1, 1, nil, { allowMythic = true })
	check("a hand deals exactly its size", #deal.pieces == 14, #deal.pieces)
	check("hand deals never hold Mythics", (function()
		for s = 1, 200 do
			for _, p in Deal.generate(s, Duel.room(3), 1, nil, { allowMythic = true }).pieces do
				if p.mythic then return false end
			end
		end
		return true
	end)())
	local run2 = Duel.parcels(2, 0, 2)
	local run3 = Duel.parcels(3, 0, 3)
	local run5max = Duel.parcels(6, 3, 5)
	local _, streak6 = Duel.parcels(1, 0, 6)
	check("no parcel for a run of two", run2 == 0)
	check("a run of three sends a parcel", run3 == 1)
	check("at most three parcels per run", run5max == 0)
	check("a streak of six sends a parcel", streak6 == 1)
	local picks = Duel.lookalikes({ "watches", "jewelry", "money", "keys" }, 5, Random.new(7))
	check("parcel pieces come from open cases", (function()
		for _, id in picks do
			local case = Catalogue.byId[id].case
			if case ~= "watches" and case ~= "jewelry" and case ~= "money" and case ~= "keys" then return false end
		end
		return #picks == 5
	end)())
	check("capped hand: fewer pieces left wins", Duel.capWinner({ remaining = 2, accuracy = 0.5, lastFilingAt = 9 }, { remaining = 3, accuracy = 1, lastFilingAt = 1 }) == "a")
	check("capped hand: then higher accuracy", Duel.capWinner({ remaining = 2, accuracy = 0.8, lastFilingAt = 1 }, { remaining = 2, accuracy = 0.9, lastFilingAt = 9 }) == "b")
	check("capped hand: then the earlier last filing", Duel.capWinner({ remaining = 2, accuracy = 0.9, lastFilingAt = 5 }, { remaining = 2, accuracy = 0.9, lastFilingAt = 4 }) == "b")
	check("queue window starts at ±100", Duel.window(0) == 100 and Duel.window(4.9) == 100)
	check("queue window widens by 50 every 5 s", Duel.window(5) == 150 and Duel.window(12) == 200)
	check("queue window stops at ±400", Duel.window(300) == 400)
	local okNear, rankedNear = Duel.pairable({ rating = 1500, waited = 0, ranked = true }, { rating = 1590, waited = 0, ranked = true })
	check("two ranked guests within 100 pair, ranked", okNear and rankedNear)
	local okFar = Duel.pairable({ rating = 1500, waited = 0, ranked = true }, { rating = 1750, waited = 0, ranked = true })
	check("two ranked guests 250 apart wait at first", not okFar)
	local okLater = Duel.pairable({ rating = 1500, waited = 20, ranked = true }, { rating = 1750, waited = 20, ranked = true })
	check("after 20 s the window reaches 250", okLater)
	local okBoth, rankedBoth = Duel.pairable({ rating = 1500, waited = 0, ranked = false }, { rating = 2100, waited = 0, ranked = false })
	check("two unranked guests pair at once, friendly", okBoth and not rankedBoth)
	check("a ranked guest waits for ranked first", not (Duel.pairable({ rating = 1500, waited = 3, ranked = true }, { rating = 1500, waited = 3, ranked = false })))
	local okMixed, rankedMixed = Duel.pairable({ rating = 1500, waited = 31, ranked = true }, { rating = 1500, waited = 0, ranked = false })
	check("then plays friendly once the window is wide", okMixed and not rankedMixed)
	local slow, lowAcc = Duel.standInPace(1000)
	local fast, highAcc = Duel.standInPace(2100)
	check("Stand-ins get faster and surer with rating", fast < slow and highAcc > lowAcc)
	check("a new guest is a Guest", (Standing.of(0, 0)) == "Guest")
	check("3 nights and 20 rounds make a Member", (Standing.of(3, 20)) == "Member")
	check("Member needs both", (Standing.of(10, 5)) == "Guest")
	check("config reads array paths", Config.get("Library.pieces.2") == 17)
	check("config sets array paths", Config.set("Library.pieces.2", 18) and Config.get("Library.pieces.2") == 18)
	Config.set("Library.pieces.2", 17)
end

-- 11. Lights Out.
do
	local LightsOut = loadModule("LightsOut")
	check("lights out: pieces every 1.6 s at first", math.abs(LightsOut.pace(0) - 1.6) < 1e-9 and math.abs(LightsOut.pace(19.9) - 1.6) < 1e-9)
	check("lights out: 0.1 s quicker every 20 s", math.abs(LightsOut.pace(20) - 1.5) < 1e-9 and math.abs(LightsOut.pace(100) - 1.1) < 1e-9)
	check("lights out: never quicker than 0.6 s before Closing Time", math.abs(LightsOut.pace(299) - 0.6) < 1e-9)
	check("lights out: Closing Time tightens by 0.05 every 10 s", math.abs(LightsOut.pace(300) - 0.55) < 1e-9 and math.abs(LightsOut.pace(310) - 0.5) < 1e-9)
	check("lights out: down to 0.35 s", math.abs(LightsOut.pace(1000) - 0.35) < 1e-9)
	check("lights out: Closing Time from 5:00", LightsOut.isClosingTime(300) and not LightsOut.isClosingTime(299))
	check("lights out: lookalikes 0.35, +0.05 every 30 s, up to 0.75", math.abs(LightsOut.lookalike(0) - 0.35) < 1e-9 and math.abs(LightsOut.lookalike(60) - 0.45) < 1e-9 and math.abs(LightsOut.lookalike(9999) - 0.75) < 1e-9)
	check("lights out: five cases, the sixth at 1:00", LightsOut.casesOpen(59) == 5 and LightsOut.casesOpen(60) == 6)
	check("lights out: key bonus steps", LightsOut.keyBonus(1) == 0 and LightsOut.keyBonus(2) == 0.25 and LightsOut.keyBonus(5) == 0.5 and LightsOut.keyBonus(8) == 0.75 and LightsOut.keyBonus(40) == 1)
	local w1, r1, c1 = LightsOut.parcels(3, 0, 3, 0, 0)
	check("lights out: a run of three sends one parcel", w1 == 1 and r1 == 1 and c1 == 0)
	local w2, r2 = LightsOut.parcels(7, 4, 7, 0, 0)
	check("lights out: at most four per run", w2 == 0 and r2 == 0)
	local w3, _, c3 = LightsOut.parcels(3, 0, 3, 2, 0)
	check("lights out: two Keys send 1.25, the quarter carries", w3 == 1 and math.abs(c3 - 0.25) < 1e-9)
	local w4, _, c4 = LightsOut.parcels(4, 1, 4, 2, 0.75)
	check("lights out: the carry becomes a whole parcel", w4 == 2 and math.abs(c4) < 1e-9, w4)
	local w5 = LightsOut.parcels(1, 0, 6, 16, 0)
	check("lights out: a streak of six with sixteen Keys sends two", w5 == 2)
	local rng = Random.new(3)
	local seats = {
		{ index = 1, alive = true, keys = 0, felt = 5, lastSender = 4 },
		{ index = 2, alive = true, keys = 3, felt = 9 },
		{ index = 3, alive = false, keys = 9, felt = 17 },
		{ index = 4, alive = true, keys = 1, felt = 14 },
	}
	check("lights out: Rivals goes to whoever last sent to you", LightsOut.target("rivals", seats[1], seats, rng) == 4)
	check("lights out: Leader goes to the most Keys still lit", LightsOut.target("leader", seats[1], seats, rng) == 2)
	check("lights out: Nearly out goes to the fullest felt still lit", LightsOut.target("nearlyOut", seats[1], seats, rng) == 4)
	local randomOk = true
	for _ = 1, 50 do
		local t = LightsOut.target("random", seats[1], seats, rng)
		if t == 1 or t == 3 then
			randomOk = false
		end
	end
	check("lights out: Random never picks you or a lamp that's out", randomOk)
	check("lights out: nobody left, no target", LightsOut.target("random", seats[1], { seats[1], seats[3] }, rng) == nil)
	check("lights out: Gilt is 100 for the last lamp, 24 for 20th", LightsOut.gilt(1) == 100 and LightsOut.gilt(20) == 24 and LightsOut.gilt(11) == 60)
	check("lights out: points by place plus 8 per Key", LightsOut.points(1, 3) == 124 and LightsOut.points(7, 0) == 25 and LightsOut.points(20, 1) == 8)
	local roomT = LightsOut.room(70)
	check("lights out: the dumbwaiter's rules follow the clock", roomT.tuning.casesRound1 == 6 and math.abs(roomT.tuning.lookalike - 0.45) < 1e-9)
end

-- 12. The Boutique, the Wardrobe and the Ledger.
do
	local Wardrobe = loadModule("Wardrobe")
	local Boutique = loadModule("Boutique")
	local Ledger = loadModule("Ledger")
	local Config = loadModule("Config")
	local ids, dupes = {}, 0
	for _, item in Wardrobe.all do
		if ids[item.id] then
			dupes += 1
		end
		ids[item.id] = true
	end
	check("wardrobe: every id is unique", dupes == 0, dupes)
	local tiersOk = true
	for _, item in Wardrobe.all do
		if item.robux and not table.find(Wardrobe.Tiers, item.robux) and Wardrobe.tierFor(item.robux) < item.robux then
			tiersOk = false
		end
	end
	check("wardrobe: every Robux price maps to a tier at or above it", tiersOk)
	check("wardrobe: 349 sells at the 399 tier", Wardrobe.tierFor(349) == 399 and Wardrobe.tierFor(49) == 49)
	check("wardrobe: nothing sold changes score (no kinds outside style)", (function()
		for _, item in Wardrobe.all do
			if not Wardrobe.KindNames[item.kind] then
				return false
			end
		end
		return true
	end)())
	check("wardrobe: a look without clothing isn't sold", not Wardrobe.deliverable(Wardrobe.get("look_gown")))
	Config.set("Assets.Looks.gown.shirt", 123)
	check("wardrobe: with clothing set it is", Wardrobe.deliverable(Wardrobe.get("look_gown")))
	Config.set("Assets.Looks.gown.shirt", 0)
	check("wardrobe: a chime needs its sound", not Wardrobe.deliverable(Wardrobe.get("chime_harp")))
	check("wardrobe: table styles need nothing uploaded", Wardrobe.deliverable(Wardrobe.get("table_oxblood")))
	local pool = Wardrobe.boutiquePool()
	check("boutique: the pool has only deliverable Robux pieces", #pool >= 15, #pool)
	local t = os.time({ year = 2026, month = 10, day = 7, hour = 12 })
	local today = Boutique.today(t)
	local featured = Boutique.featured(t)
	check("boutique: six pieces a day", #today == 6)
	check("boutique: two featured a week", #featured == 2)
	local same = true
	for i, item in Boutique.today(t + 3600) do
		if item.id ~= today[i].id then
			same = false
		end
	end
	check("boutique: the same shelves all day, everywhere", same)
	local changed = false
	for i, item in Boutique.today(t + 86400) do
		if item.id ~= today[i].id then
			changed = true
		end
	end
	check("boutique: new shelves the next day", changed)
	local overlap = false
	for _, a in today do
		for _, b in featured do
			if a.id == b.id then
				overlap = true
			end
		end
	end
	check("boutique: today's pieces never repeat the featured pair", not overlap)
	check("boutique: featured holds all week", Boutique.featured(t + 86400)[1].id == featured[1].id or os.date("!*t", t + 86400).wday == 2)
	check("boutique: today's piece is on sale", Boutique.onSale(today[1].id, "harvest", t))
	check("boutique: a season's piece only in its season", not Boutique.onSale("season_harvest_table", "frost", t) and Boutique.onSale("season_harvest_table", "harvest", t))
	check("boutique: a Gilt piece isn't sold for Robux", not Boutique.onSale("table_emerald", "harvest", t))
	check("ledger: 1,000 points a page", Ledger.page(999) == 0 and Ledger.page(1000) == 1 and Ledger.page(12345) == 12)
	check("ledger: fifty pages at most", Ledger.page(10 ^ 7) == 50 and Ledger.progress(10 ^ 7) == 1)
	check("ledger: points by source", Ledger.points("filing", 10) == 30 and Ledger.points("nightly") == 300 and Ledger.points("library", 1) == 250 and Ledger.points("library", 0) == 150)
	check("ledger: Ballroom points by place", Ledger.points("ballroom", 1) == 250 and Ledger.points("ballroom", 11) == 150 and Ledger.points("ballroom", 20) == 150)
	local free1 = Ledger.rewards("2026-autumn", "free", 1)
	check("ledger: free pages give Gilt", free1[1].kind == "gilt" and free1[1].amount == 100)
	local free5 = Ledger.rewards("2026-autumn", "free", 5)
	check("ledger: every fifth free page gives a cosmetic", free5[1].kind == "item" and Wardrobe.get(free5[1].id) ~= nil)
	local free50 = Ledger.rewards("2026-autumn", "free", 50)
	check("ledger: the free row ends with the Term's gesture", Wardrobe.get(free50[1].id).kind == "gesture")
	local leather = Ledger.rewards("2026-autumn", "leather", 7)
	check("ledger: Leather-Bound pages give two cosmetics", #leather == 2 and leather[1].id ~= leather[2].id)
	local leather50 = Ledger.rewards("2026-autumn", "leather", 50)
	check("ledger: the Term's signature look on the last page", Wardrobe.get(leather50[1].id).kind == "look")
	check("ledger: editions resolve from their id alone", Ledger.item("ledger:2027-winter:leather:12a") ~= nil)
	-- Pacing (Appendix I2 asks for around week 9 of 13): a steady guest plays 30 minutes on four
	-- nights a week, files about 400 pieces a session, sits the Nightly and does the Evening
	-- Commission most nights.
	local perSession = Ledger.points("filing", 400) + Ledger.points("nightly") + Ledger.points("evening") * 0.6
	local week = 0
	local total = 0
	while Ledger.page(total) < 50 and week < 30 do
		week += 1
		total += perSession * 4
	end
	print(string.format("  (the Ledger at the brief's point values: finished in week %d)", week))
	check("ledger: a steady guest finishes within the Term", week >= 5 and week <= 13, week)
end

-- 13. Commissions.
do
	local Commissions = loadModule("Commissions")
	local t = os.time({ year = 2026, month = 10, day = 7, hour = 12 })
	local a, b = Commissions.evening(t), Commissions.evening(t + 3600)
	check("commissions: the same goal all evening, for everyone", a.id == b.id and a.text == b.text)
	check("commissions: a new one tomorrow", Commissions.evening(t + 86400).id ~= a.id)
	check("commissions: the week's holds all week", Commissions.weekly(t).id == Commissions.weekly(t + 86400).id or os.date("!*t", t + 86400).wday == 2)
	local kinds = {}
	for d = 0, 60 do
		local g = Commissions.evening(t + d * 86400)
		kinds[g.kind] = true
		assert(g.target >= 1 and #g.text > 5)
	end
	check("commissions: evenings vary across the kinds", kinds.file and kinds.rounds and kinds.nightly)
	local g = { id = "x", kind = "file", room = "velvet", case = "jewelry", target = 12, text = "" }
	check("commissions: a filing in the right room and case counts", Commissions.progress(g, "file", "velvet", "jewelry") == 1)
	check("commissions: the wrong case doesn't", Commissions.progress(g, "file", "velvet", "watches") == 0)
	check("commissions: the wrong room doesn't", Commissions.progress(g, "file", "salon", "jewelry") == 0)
	check("commissions: Gilt as Appendix I1", Commissions.reward(false) == 150 and Commissions.reward(true) == 600)
end

-- 14. The Soirée.
do
	local Soiree = loadModule("Soiree")
	local sat = os.time({ year = 2026, month = 10, day = 3, hour = 12 }) -- a Saturday
	local w = Soiree.at(sat)
	check("soirée: on all Saturday", w.active and w.key == "2026-10-03")
	check("soirée: and all Sunday", Soiree.at(sat + 86400).active and Soiree.at(sat + 86400).key == w.key)
	check("soirée: over by Monday", not Soiree.at(sat + 2 * 86400).active)
	check("soirée: on Wednesday, the next one is shown", not Soiree.at(sat - 3 * 86400).active and Soiree.at(sat - 3 * 86400).key == w.key)
	check("soirée: formats alternate weekends", Soiree.at(sat + 7 * 86400).format ~= w.format)
	check("soirée: All Hallows re-dresses it", Soiree.at(os.time({ year = 2026, month = 10, day = 24, hour = 12 })).name == "The All Hallows Soirée")
	check("soirée: Ballroom points as H5", Soiree.points("ballroom", { place = 1, keys = 2 }) == 116 and Soiree.points("ballroom", { place = 12, keys = 0 }) == 10)
	check("soirée: Library points as H5", Soiree.points("library", { won = true }) == 30 and Soiree.points("library", { won = false }) == 5)
	check("soirée: the best five Ballroom evenings count", Soiree.score("ballroom", { 10, 100, 40, 70, 0, 55, 25 }) == 290)
	check("soirée: top 1% earn the medal", Soiree.reward(1, 150) == "medal" and Soiree.reward(2, 150) == "invitation" and Soiree.reward(20, 150) == nil)
	check("soirée: a countdown reads naturally", Soiree.countdown(86400 + 4 * 3600 + 5) == "1 day 4 h" and Soiree.countdown(3 * 3600 + 12 * 60) == "3 h 12 min")
end

-- 10. Rivals.
do
	local Rival = loadModule("Rival")
	local now = 2000000000
	local function card(r, matches, key, score, seenAgo)
		return { name = "x", r = r, matches = matches, nightlyKey = key, nightlyScore = score, seen = now - seenAgo }
	end
	local me = card(1500, 10, "", 0, 0)
	local picked = Rival.pick(me, {
		{ userId = 1, card = card(1700, 5, "", 0, 3600) },
		{ userId = 2, card = card(1540, 8, "", 0, 86400 * 3) },
		{ userId = 3, card = card(1505, 9, "", 0, 86400 * 30) }, -- not seen lately
		{ userId = 4, card = card(1500, 0, "", 0, 60) }, -- never played ranked
	}, now)
	check("rival: the closest rating among connections seen lately", picked and picked.userId == 2, picked and picked.userId)
	local fresh = Rival.pick(card(1500, 0, "", 0, 0), {
		{ userId = 5, card = card(1500, 0, "", 0, 86400) },
		{ userId = 6, card = card(1500, 0, "", 0, 600) },
	}, now)
	check("rival: without ratings, whoever was here most recently", fresh and fresh.userId == 6)
	check("rival: nobody seen lately, nobody picked", Rival.pick(me, { { userId = 7, card = card(1500, 3, "", 0, 86400 * 20) } }, now) == nil)
	local text, ahead = Rival.fact(card(1500, 0, "n1", 900, 0), card(1500, 0, "n1", 1300, 0), "n1")
	check("rival fact: ahead of you on tonight's table", text == "400 points ahead of you on tonight's table." and ahead == false, text)
	text, ahead = Rival.fact(card(1500, 0, "n1", 1301, 0), card(1500, 0, "n1", 1300, 0), "n1")
	check("rival fact: the plate turns when you pass them", text == "1 point behind you on tonight's table." and ahead == true, text)
	text = Rival.fact(card(1500, 0, "n0", 900, 0), card(1500, 0, "n1", 1300, 0), "n1")
	check("rival fact: they've sat tonight's table and you haven't", text == "Has sat tonight's table. You haven't yet.", text)
	text, ahead = Rival.fact(card(1480, 6, "", 0, 0), card(1520, 6, "", 0, 0), "n1")
	check("rival fact: the Library when there's no Nightly", text == "40 rating points ahead of you in the Library." and not ahead, text)
	check("rival: weeks start on Monday", Rival.week(os.time({ year = 2026, month = 9, day = 28, hour = 1 })) == Rival.week(os.time({ year = 2026, month = 10, day = 4, hour = 23 })))
	check("rival: a new week on Monday", Rival.week(os.time({ year = 2026, month = 10, day = 5, hour = 1 })) == Rival.week(os.time({ year = 2026, month = 9, day = 28, hour = 1 })) + 1)
end

print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	os.exit(1)
end

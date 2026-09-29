--!strict
-- Ratings, Marks and Terms (§9.4, Appendix H2, H4). Glicko-2 as published by Glickman (2012);
-- one Tête-à-Tête match is one rating period.

local Config = require(script.Parent.Config)

local Rating = {}

export type Record = { r: number, rd: number, vol: number }

local SCALE = 173.7178

local function g(phi: number): number
	return 1 / math.sqrt(1 + 3 * phi * phi / (math.pi * math.pi))
end

local function expected(mu: number, muJ: number, phiJ: number): number
	return 1 / (1 + math.exp(-g(phiJ) * (mu - muJ)))
end

function Rating.new(): Record
	local c = Config.data.Library
	return { r = c.ratingStart, rd = c.ratingDeviation, vol = c.ratingVolatility }
end

-- Updates `player` after games against `opponents` with `scores` (1 win, 0 loss, 0.5 draw).
function Rating.update(player: Record, opponents: { Record }, scores: { number }, tau: number?): Record
	local t = tau or Config.data.Library.ratingTau
	local mu = (player.r - 1500) / SCALE
	local phi = player.rd / SCALE
	local sigma = player.vol
	if #opponents == 0 then
		local phiStar = math.sqrt(phi * phi + sigma * sigma)
		return { r = player.r, rd = math.min(phiStar * SCALE, 350), vol = sigma }
	end
	local vInv = 0
	local deltaSum = 0
	for i, o in opponents do
		local muJ = (o.r - 1500) / SCALE
		local phiJ = o.rd / SCALE
		local gJ = g(phiJ)
		local e = expected(mu, muJ, phiJ)
		vInv += gJ * gJ * e * (1 - e)
		deltaSum += gJ * (scores[i] - e)
	end
	local v = 1 / vInv
	local delta = v * deltaSum

	-- The new volatility, by the Illinois algorithm (step 5).
	local a = math.log(sigma * sigma)
	local function f(x: number): number
		local ex = math.exp(x)
		local num = ex * (delta * delta - phi * phi - v - ex)
		local den = 2 * (phi * phi + v + ex) ^ 2
		return num / den - (x - a) / (t * t)
	end
	local epsilon = 0.000001
	local A = a
	local B: number
	if delta * delta > phi * phi + v then
		B = math.log(delta * delta - phi * phi - v)
	else
		local k = 1
		while f(a - k * t) < 0 do
			k += 1
		end
		B = a - k * t
	end
	local fA, fB = f(A), f(B)
	local guard = 0
	while math.abs(B - A) > epsilon and guard < 100 do
		guard += 1
		local C = A + (A - B) * fA / (fB - fA)
		local fC = f(C)
		if fC * fB <= 0 then
			A, fA = B, fB
		else
			fA /= 2
		end
		B, fB = C, fC
	end
	local newSigma = math.exp(A / 2)

	local phiStar = math.sqrt(phi * phi + newSigma * newSigma)
	local newPhi = 1 / math.sqrt(1 / (phiStar * phiStar) + 1 / v)
	local newMu = mu + newPhi * newPhi * deltaSum
	return { r = SCALE * newMu + 1500, rd = SCALE * newPhi, vol = newSigma }
end

-- The chance `a` beats `b` (for Stand-ins and matchmaking).
function Rating.winChance(a: Record, b: Record): number
	local mu = (a.r - 1500) / SCALE
	local muJ = (b.r - 1500) / SCALE
	local phiJ = math.sqrt((a.rd / SCALE) ^ 2 + (b.rd / SCALE) ^ 2)
	return expected(mu, muJ, phiJ)
end

export type Mark = { tier: string, division: number?, label: string }

local TIERS = { "Silver", "Gold", "Platinum", "Diamond" }

-- The Mark for a rating: Brass · Silver III–I · Gold III–I · Platinum III–I · Diamond III–I · Onyx.
-- Noir is not a threshold: it's the Term's top Onyx players (decided at the Term's end).
function Rating.mark(rating: number): Mark
	local m = Config.data.Marks
	local bounds = { m.silver, m.gold, m.platinum, m.diamond, m.onyx }
	if rating < bounds[1] then
		return { tier = "Brass", division = nil, label = "Brass" }
	end
	if rating >= bounds[5] then
		return { tier = "Onyx", division = nil, label = "Onyx" }
	end
	for i = 1, 4 do
		local lo, hi = bounds[i], bounds[i + 1]
		if rating >= lo and rating < hi then
			local third = (hi - lo) / 3
			local step = math.floor((rating - lo) / third)
			local division = 3 - math.clamp(step, 0, 2) -- III at the bottom, I at the top
			local numeral = ({ "I", "II", "III" })[division]
			return { tier = TIERS[i], division = division, label = TIERS[i] .. " " .. numeral }
		end
	end
	return { tier = "Brass", division = nil, label = "Brass" }
end

-- Terms are quarters (UTC): Autumn Sep–Nov, Winter Dec–Feb, Spring Mar–May, Summer Jun–Aug.
export type Term = { id: string, name: string }

function Rating.term(time: number?): Term
	local d = os.date("!*t", time or os.time())
	local m, y = d.month, d.year
	if m >= 9 and m <= 11 then
		return { id = y .. "-autumn", name = "Autumn Term " .. y }
	elseif m == 12 then
		return { id = y .. "-winter", name = "Winter Term " .. y }
	elseif m <= 2 then
		return { id = (y - 1) .. "-winter", name = "Winter Term " .. (y - 1) }
	elseif m <= 5 then
		return { id = y .. "-spring", name = "Spring Term " .. y }
	end
	return { id = y .. "-summer", name = "Summer Term " .. y }
end

-- At a Term's end, ratings ease back toward the middle.
function Rating.newTerm(record: Record): Record
	local m = Config.data.Marks
	return {
		r = 1500 + (record.r - 1500) * m.termCompress,
		rd = math.max(record.rd, m.termMinDeviation),
		vol = record.vol,
	}
end

return Rating

--!strict
-- The deal generator (Appendix D). A pure function of (seed, room, round, season):
-- the same inputs give the same deal on every server and every client.

local Catalogue = require(script.Parent.Catalogue)
local Config = require(script.Parent.Config)
local Rooms = require(script.Parent.Rooms)

local Deal = {}

export type DealtPiece = {
	id: string,
	name: string,
	case: string,
	value: number,
	rare: boolean,
	seasonal: boolean,
	mythic: boolean,
}

export type Result = {
	seed: number,
	round: number,
	room: string,
	cases: { string }, -- open cases, in catalogue order
	size: number,
	pieces: { DealtPiece },
}

export type Options = {
	allowMythic: boolean?,
}

function Deal.casesOpen(room: Rooms.Room, round: number): { string }
	local n = math.min(#Catalogue.Cases, room.tuning.casesRound1 + (round - 1))
	local out = {}
	for i = 1, n do
		out[i] = Catalogue.Cases[i].id
	end
	return out
end

function Deal.size(room: Rooms.Room, round: number): number
	local t = room.tuning
	return math.min(t.firstDeal + math.floor((round - 1) * t.dealGrowth), t.maxDeal)
end

local function shuffle<T>(list: { T }, rng: Random)
	for i = #list, 2, -1 do
		local j = rng:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end

local function pickUnderCap(candidates: { string }, rng: Random, counts: { [string]: number }, cap: number): string?
	local eligible = {}
	for _, id in candidates do
		if (counts[id] or 0) < cap then
			table.insert(eligible, id)
		end
	end
	if #eligible == 0 then
		return nil
	end
	return eligible[rng:NextInteger(1, #eligible)]
end

local function toDealt(p: Catalogue.Piece): DealtPiece
	return {
		id = p.id,
		name = p.name,
		case = p.case,
		value = p.value,
		rare = false,
		seasonal = p.season ~= nil,
		mythic = false,
	}
end

function Deal.generate(seed: number, room: Rooms.Room, round: number, seasonId: string?, options: Options?): Result
	local tuning = room.tuning
	local dealCfg = Config.data.Deal
	local rareCfg = Config.data.Rare
	local rng = Random.new(seed)

	local cases = Deal.casesOpen(room, round)
	local open: { [string]: boolean } = {}
	for _, c in cases do
		open[c] = true
	end

	local size = Deal.size(room, round)
	local cap = if size >= dealCfg.largeDealFrom then dealCfg.repeatCapLargeDeal else dealCfg.repeatCap

	local counts: { [string]: number } = {}
	local ids: { string } = {}
	local function take(id: string)
		counts[id] = (counts[id] or 0) + 1
		table.insert(ids, id)
	end

	-- One seed piece for every open case.
	for _, caseId in cases do
		local pool = Catalogue.coreForCase(caseId)
		take(pool[rng:NextInteger(1, #pool)].id)
	end

	-- Filler pools.
	local openIds: { string } = {}
	for _, p in Catalogue.Core do
		if open[p.case] then
			table.insert(openIds, p.id)
		end
	end

	local clusters: { { string } } = {}
	for _, cluster in Catalogue.Clusters do
		local members = {}
		for _, id in cluster do
			local p = Catalogue.byId[id]
			if p and open[p.case] then
				table.insert(members, id)
			end
		end
		if #members >= 3 then
			table.insert(clusters, members)
		end
	end

	local fillerCount = size - #cases
	local fillerStart = #ids + 1
	for _ = 1, fillerCount do
		local chosen: string? = nil
		if #clusters > 0 and rng:NextNumber() < tuning.lookalike then
			local members = clusters[rng:NextInteger(1, #clusters)]
			chosen = pickUnderCap(members, rng, counts, cap)
		end
		if chosen == nil then
			local fresh = {}
			for _, id in openIds do
				if (counts[id] or 0) == 0 then
					table.insert(fresh, id)
				end
			end
			if #fresh > 0 then
				chosen = fresh[rng:NextInteger(1, #fresh)]
			else
				chosen = pickUnderCap(openIds, rng, counts, cap)
			end
		end
		if chosen == nil then
			-- Every open piece is at the cap. Only possible with a tiny catalogue; deal anything open.
			chosen = openIds[rng:NextInteger(1, #openIds)]
		end
		take(chosen :: string)
	end

	local pieces: { DealtPiece } = {}
	for i, id in ids do
		pieces[i] = toDealt(Catalogue.byId[id])
	end

	-- Seasonal pieces replace filler slots only, never a seed, only from open cases.
	local seasonalOpen: { Catalogue.Piece } = {}
	for _, p in Catalogue.seasonalFor(seasonId) do
		if open[p.case] then
			table.insert(seasonalOpen, p)
		end
	end
	if #seasonalOpen > 0 and fillerCount > 0 then
		local want = math.max(dealCfg.seasonalMin, math.min(dealCfg.seasonalMax, math.round(size * dealCfg.seasonalShare)))
		want = math.min(want, fillerCount, #seasonalOpen * cap)
		local slots = {}
		for i = fillerStart, #ids do
			table.insert(slots, i)
		end
		shuffle(slots, rng)
		shuffle(seasonalOpen, rng)
		for k = 1, want do
			local sp = seasonalOpen[((k - 1) % #seasonalOpen) + 1]
			pieces[slots[k]] = toDealt(sp)
		end
	end

	-- Rare.
	local rareChance = math.min(rareCfg.base + round * tuning.rareRate, rareCfg.cap)
	for _, pc in pieces do
		local chance = rareChance + (if pc.value >= rareCfg.highValueFrom then rareCfg.highValueBonus else 0)
		pc.rare = rng:NextNumber() < chance
	end

	-- Mythic: the four rooms only.
	if options and options.allowMythic and tuning.mythicChance > 0 then
		for _, pc in pieces do
			if rng:NextInteger(1, tuning.mythicChance) == 1 then
				local m = Catalogue.mythicForCase(pc.case)
				if m then
					pc.id = m.id
					pc.name = m.name
					pc.value = Config.data.Scoring.mythicValue
					pc.mythic = true
					pc.rare = false
					pc.seasonal = false
				end
			end
		end
	end

	shuffle(pieces, rng)

	return {
		seed = seed,
		round = round,
		room = room.id,
		cases = cases,
		size = size,
		pieces = pieces,
	}
end

return Deal

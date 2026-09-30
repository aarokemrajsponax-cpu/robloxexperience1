--!strict
-- The Ledger (§11, Appendix I2): each Term's book of fifty pages, turned by playing anything,
-- anywhere in the house. Every guest has the free row; the Leather-Bound edition adds a second
-- row, two cosmetics a page, and the Term's signature look on the last page. Every reward is
-- cosmetic. Buying the Leather-Bound edition late unlocks every page already reached.

local Config = require(script.Parent.Config)
local Wardrobe = require(script.Parent.Wardrobe)

local Ledger = {}

export type Reward = { kind: "gilt", amount: number } | { kind: "item", id: string }

local function cfg()
	return Config.data.Ledger
end

-- Pages reached with `points` (0 to 50).
function Ledger.page(points: number): number
	return math.clamp(math.floor(points / cfg().pointsPerPage), 0, cfg().pages)
end

-- Progress through the current page, 0 to 1.
function Ledger.progress(points: number): number
	if Ledger.page(points) >= cfg().pages then
		return 1
	end
	return (points % cfg().pointsPerPage) / cfg().pointsPerPage
end

-- Points for what a guest just did (Appendix I2).
function Ledger.points(source: string, detail: number?): number
	local c = cfg().points
	if source == "filing" then
		return c.filing * (detail or 1)
	elseif source == "nightly" then
		return c.nightly
	elseif source == "evening" then
		return c.evening
	elseif source == "week" then
		return c.week
	elseif source == "library" then
		return c.library + (if detail == 1 then c.libraryWin else 0)
	elseif source == "ballroom" then
		local place = detail or 20
		return c.ballroom + c.ballroomPerPlace * math.max(0, 11 - place)
	end
	return 0
end

local PALETTE = {
	Color3.fromRGB(212, 176, 110), Color3.fromRGB(150, 60, 70), Color3.fromRGB(70, 110, 170),
	Color3.fromRGB(96, 150, 118), Color3.fromRGB(190, 190, 200), Color3.fromRGB(120, 80, 150),
	Color3.fromRGB(230, 150, 110), Color3.fromRGB(60, 60, 66),
}
local EDITION_KINDS: { Wardrobe.Kind } = { "trail", "card", "nameplate", "lamp", "table", "flourish" }

local function termName(termId: string): string
	local season = string.match(termId, "%-(%a+)$") or "term"
	return (string.upper(string.sub(season, 1, 1)) .. string.sub(season, 2)) .. " Term"
end

-- A Ledger edition: made from the Term, the row and the page, and registered with the Wardrobe
-- so it can be owned and worn like anything else.
local function edition(termId: string, row: string, page: number, slot: string): Wardrobe.Item
	local id = string.format("ledger:%s:%s:%d%s", termId, row, page, slot)
	local existing = Wardrobe.get(id)
	if existing then
		return existing
	end
	local n = page * 2 + (if slot == "b" then 1 else 0) + (if row == "leather" then 7 else 0)
	local kind = EDITION_KINDS[(n % #EDITION_KINDS) + 1]
	local colour = PALETTE[(n % #PALETTE) + 1]
	local name = termName(termId)
	local style: { [string]: any } = if kind == "trail" then { colour = colour }
		elseif kind == "card" then { back = colour:Lerp(Color3.new(), 0.6), pattern = if n % 2 == 0 then "pinstripe" else "damask" }
		elseif kind == "nameplate" then { frame = colour, fill = Color3.fromRGB(16, 16, 18) }
		elseif kind == "lamp" then { colour = colour:Lerp(Color3.new(1, 1, 1), 0.55) }
		elseif kind == "table" then { felt = colour:Lerp(Color3.new(), 0.65), rim = Color3.fromRGB(198, 160, 82) }
		else { colour = colour, kind = "leaf" }
	local item: Wardrobe.Item = {
		id = id,
		name = string.format("%s · %s, page %d", name, Wardrobe.KindNames[kind] :: string, page),
		kind = kind :: Wardrobe.Kind,
		line = "From the Ledger, " .. name .. ".",
		source = "ledger",
		style = style,
	}
	Wardrobe.register(item)
	return item
end

-- What a page gives: the free row, or the Leather-Bound row.
function Ledger.rewards(termId: string, row: "free" | "leather", page: number): { Reward }
	if row == "free" then
		if page == cfg().pages then
			local gesture: Wardrobe.Item = {
				id = string.format("ledger:%s:free:%d", termId, page),
				name = termName(termId) .. " Gesture",
				kind = "gesture",
				line = "The Term's gesture, from the last page of the Ledger.",
				source = "ledger",
				style = { animation = "term" },
			}
			Wardrobe.register(gesture)
			return { { kind = "item", id = gesture.id } }
		elseif page % 5 == 0 then
			return { { kind = "item", id = edition(termId, "free", page, "").id } }
		end
		return { { kind = "gilt", amount = cfg().freeGilt } }
	end
	if page == cfg().pages then
		local look: Wardrobe.Item = {
			id = string.format("ledger:%s:leather:%d", termId, page),
			name = termName(termId) .. " Signature Look",
			kind = "look",
			line = "The Term's signature look, on the last page of the Leather-Bound Ledger.",
			source = "ledger",
			style = { outfit = "term" },
		}
		Wardrobe.register(look)
		return { { kind = "item", id = look.id } }
	end
	return { { kind = "item", id = edition(termId, "leather", page, "a").id }, { kind = "item", id = edition(termId, "leather", page, "b").id } }
end

-- Resolves any Ledger item id back to its item (so owned editions survive a server restart).
function Ledger.item(id: string): Wardrobe.Item?
	local found = Wardrobe.get(id)
	if found then
		return found
	end
	local term, row, page = string.match(id, "^ledger:([^:]+):(%a+):(%d+)")
	if term and row and page then
		Ledger.rewards(term, if row == "leather" then "leather" else "free", tonumber(page) :: number)
		return Wardrobe.get(id)
	end
	return nil
end

return Ledger

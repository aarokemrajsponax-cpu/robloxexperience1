--!strict
-- The Ledger, kept (Appendix I2): points from everything a guest does, pages turned, and every
-- page's rewards granted as it's reached (the Leather-Bound row too, once bought; buying late
-- grants every page already reached). A new Term opens a new book.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ledger = require(ReplicatedStorage.Shared.Ledger)
local Rating = require(ReplicatedStorage.Shared.Rating)

local Analytics = require(script.Parent.Analytics)
local Profiles = require(script.Parent.Profiles)

local LedgerService = {}

-- Tells a guest's screen (set by the Shop).
LedgerService.changed = function(_player: Player, _pages: { number }?) end

local function book(data: Profiles.Data): Profiles.Data
	local term = Rating.term().id
	if data.ledger.term ~= term then
		data.ledger.term = term
		data.ledger.points = 0
		data.ledger.freeClaimed = 0
		data.ledger.leatherClaimed = 0
	end
	return data
end

-- The Leather-Bound edition: bought for this Term, or held with the Black Card.
local function leather(data: Profiles.Data): boolean
	return data.ledger.leather[data.ledger.term] == true or (data.blackCard ~= nil and data.blackCard.active)
end

-- Grants every reward on pages reached but not yet given. Returns the pages newly turned.
function LedgerService.claim(player: Player, data: Profiles.Data): { number }
	book(data)
	local term = data.ledger.term
	local reached = Ledger.page(data.ledger.points)
	local turned = {}
	while data.ledger.freeClaimed < reached do
		data.ledger.freeClaimed += 1
		local page = data.ledger.freeClaimed
		table.insert(turned, page)
		for _, reward in Ledger.rewards(term, "free", page) do
			if reward.kind == "gilt" then
				data.gilt += reward.amount -- the Ledger's Gilt isn't softly capped: it was earned already
				Analytics.source(player, "Gilt", reward.amount, data.gilt, "Ledger")
			else
				data.owned[reward.id] = true
			end
		end
	end
	if leather(data) then
		while data.ledger.leatherClaimed < reached do
			data.ledger.leatherClaimed += 1
			for _, reward in Ledger.rewards(term, "leather", data.ledger.leatherClaimed) do
				if reward.kind == "item" then
					data.owned[reward.id] = true
				end
			end
		end
	end
	return turned
end

-- Adds points for something the guest did ("filing", "nightly", "library", "ballroom", ...).
function LedgerService.add(player: Player, source: string, detail: number?)
	local data = Profiles.get(player)
	if not data then
		return
	end
	book(data)
	local points = Ledger.points(source, detail)
	if points <= 0 then
		return
	end
	local cap = Config.data.Ledger.pages * Config.data.Ledger.pointsPerPage
	data.ledger.points = math.min(cap, data.ledger.points + points)
	local turned = LedgerService.claim(player, data)
	LedgerService.changed(player, if #turned > 0 then turned else nil)
end

-- The Leather-Bound edition for this Term (bought, or held with the Black Card).
function LedgerService.bindLeather(player: Player, data: Profiles.Data)
	book(data)
	data.ledger.leather[data.ledger.term] = true
	LedgerService.claim(player, data)
	LedgerService.changed(player, nil)
end

-- What the guest's screen shows of their book.
function LedgerService.view(data: Profiles.Data): { [string]: any }
	book(data)
	local term = data.ledger.term
	local page = Ledger.page(data.ledger.points)
	local nextPage = math.min(page + 1, Config.data.Ledger.pages)
	local function names(row: "free" | "leather", p: number): { string }
		local out = {}
		for _, r in Ledger.rewards(term, row, p) do
			if r.kind == "gilt" then
				table.insert(out, string.format("%d Gilt", r.amount))
			else
				local item = Ledger.item(r.id)
				table.insert(out, if item then item.name else r.id)
			end
		end
		return out
	end
	return {
		term = term,
		points = data.ledger.points,
		page = page,
		pages = Config.data.Ledger.pages,
		progress = Ledger.progress(data.ledger.points),
		leather = leather(data),
		card = data.blackCard ~= nil and data.blackCard.active and data.ledger.leather[term] ~= true,
		nextFree = names("free", nextPage),
		nextLeather = names("leather", nextPage),
		nextPage = nextPage,
	}
end

return LedgerService

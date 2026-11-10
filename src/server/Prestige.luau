--!strict
-- Maison Prestige on the server (shared/Prestige has the laurels): a guest's laurel worked out
-- from what they have done (the badges they've earned and the highest wealth rank they've
-- reached), kept in their record with the day each laurel came, and published on them (the
-- "Prestige" attribute: their nameplate's border and laurel, their title when no Gem Shop title
-- is worn, the ring of light at their feet). A new laurel is said on their screen, and the
-- highest are told to the house. Nothing is ever taken away or reset to climb them, and nothing a
-- screen sends can give one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BadgeBook = require(ReplicatedStorage.Shared.BadgeBook)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Prestige)
local Fortune = require(script.Parent.Fortune)
local Herald = require(script.Parent.Herald)
local Profiles = require(script.Parent.Profiles)

local Prestige = {}

-- Set by Main: the nameplate drawn again (its border and laurel).
Prestige.changed = function(_player: Player) end

local ATTRIBUTE = "Prestige"
local FLOURISH_GAP = 20 -- seconds between one guest's flourishes
local lastFlourish: { [Player]: number } = {}

local function tierOf(key: string): string?
	local b = BadgeBook.byKey[key]
	return if b then b.tier else nil
end

local function page(data: Profiles.Data): { [string]: any }
	local d = data :: any
	if type(d.prestige) ~= "table" then
		d.prestige = { level = 0, at = {} }
	end
	local p = d.prestige
	if type(p.at) ~= "table" then
		p.at = {}
	end
	p.level = tonumber(p.level) or 0
	return p
end

local function deeds(data: Profiles.Data): Rules.Deeds
	local d = data :: any
	local badges = if type(d.badges) == "table" then d.badges else {}
	local rank = tonumber(Fortune.page(data).rank) or 1
	return { badges = badges, rank = rank }
end

-- A guest's laurel points and laurel, as their record stands.
function Prestige.measure(data: Profiles.Data): (number, number, Rules.Deeds)
	local dd = deeds(data)
	local points = Rules.points(dd.badges, tierOf)
	return points, Rules.levelOf(points, dd), dd
end

-- The laurel a guest holds now (0: none).
function Prestige.level(player: Player): number
	local v = player:GetAttribute(ATTRIBUTE)
	return if type(v) == "number" then v else 0
end

-- Works a guest's laurel out again and publishes it. A laurel newly reached is told (unless
-- `quiet`: on arrival, for laurels earned before Prestige began). A laurel once held is kept,
-- whatever happens to the record after.
function Prestige.sync(player: Player, quiet: boolean?)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local p = page(data)
	local _, level = Prestige.measure(data)
	local before = p.level
	if level > before then
		local now = os.time()
		for l = before + 1, level do
			p.at[tostring(l)] = p.at[tostring(l)] or now
		end
		p.level = level
	end
	local held = math.max(before, level)
	if player:GetAttribute(ATTRIBUTE) ~= (if held > 0 then held else nil) then
		player:SetAttribute(ATTRIBUTE, if held > 0 then held else nil)
		local l = Rules.get(held)
		player:SetAttribute("PrestigeTitle", if l then l.name else nil)
		Prestige.changed(player)
	end
	if level > before and not quiet then
		local l = Rules.get(level) :: Rules.Level
		Remotes.event("Empire"):FireClient(player, { op = "prestige", level = level, name = l.name, numeral = l.numeral, rewards = l.rewards })
		if level >= Rules.TOP - 2 then
			Herald.feat(player, {
				kind = "prestige",
				title = "THE " .. string.upper(l.name),
				line = "has earned the " .. l.name .. ", laurel " .. l.numeral .. " of Maison Prestige",
				glyph = "🏛️",
				everywhere = level == Rules.TOP,
			})
		end
	end
end

-- The Prestige card: every laurel, what it needs and brings, and where the guest stands.
function Prestige.view(player: Player): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local p = page(data)
	local points, level, dd = Prestige.measure(data)
	level = math.max(level, p.level)
	local levels = {}
	for _, l in Rules.Levels do
		table.insert(levels, {
			level = l.level,
			name = l.name,
			numeral = l.numeral,
			points = l.points,
			milestone = if l.milestone then l.milestone.line else nil,
			milestoneMet = Rules.met(l.milestone, dd),
			rewards = l.rewards,
			held = l.level <= level,
			since = p.at[tostring(l.level)],
		})
	end
	local nxt = Rules.next(level, points, dd)
	return {
		ok = true,
		level = level,
		points = points,
		top = Rules.TOP,
		levels = levels,
		next = if nxt then { level = nxt.level.level, name = nxt.level.name, short = nxt.short, milestone = if nxt.level.milestone then nxt.level.milestone.line else nil, milestoneMet = nxt.milestoneMet } else nil,
		flourish = level >= Rules.FLOURISH,
	}
end

-- The Laurel Flourish (from the fourth laurel): a shower of gold leaves round the guest, seen by
-- everyone near. At most one every twenty seconds.
function Prestige.flourish(player: Player): { [string]: any }
	if Prestige.level(player) < Rules.FLOURISH then
		return { ok = false, why = "The Flourish comes with the " .. (Rules.get(Rules.FLOURISH) :: Rules.Level).name .. "." }
	end
	local now = os.clock()
	if (lastFlourish[player] or -math.huge) + FLOURISH_GAP > now then
		return { ok = false, why = "One moment: the leaves are still falling." }
	end
	lastFlourish[player] = now
	Remotes.event("Empire"):FireAllClients({ op = "flourish", userId = player.UserId, level = Prestige.level(player) })
	return { ok = true }
end

function Prestige.start()
	Profiles.Loaded:Connect(function(player: Player)
		Prestige.sync(player, true)
	end)
	for _, player in Players:GetPlayers() do
		if Profiles.get(player) then
			Prestige.sync(player, true)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		lastFlourish[player] = nil
	end)
end

return Prestige

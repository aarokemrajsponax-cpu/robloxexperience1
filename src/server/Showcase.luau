--!strict
-- The Vault's and the Suite's displays on the server (shared/Showcase has the rules). Everything
-- is checked here: the featured curios (four at most, each one the guest really holds), the
-- arrangement, who may look round a Vault and who may visit a Suite (the Suite's visits are
-- decided here too: server/SuiteVisits asks), the Suite's themes (bought for the price shown,
-- all of it or none of it, or with the Island Key or a Prestige laurel), invitations to a Suite,
-- and another guest's Vault card (only as its owner allows). The collection's completion and the
-- acquisition history are worked out from the guest's saved record (server/Curios keeps the
-- history as each curio arrives).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CurioList = require(ReplicatedStorage.Shared.Curios)
local Names = require(ReplicatedStorage.Shared.Names)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Rules = require(ReplicatedStorage.Shared.Showcase)
local Analytics = require(script.Parent.Analytics)
local Curios = require(script.Parent.Curios)
local Fortune = require(script.Parent.Fortune)
local Friends = require(script.Parent.Friends)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Showcase = {}

-- A guest's Suite changed who may visit (set by Main: server/SuiteVisits sweeps visitors out).
Showcase.suiteChanged = function(_host: Player) end
-- A friend was invited to a guest's Suite (set by Main: their screen is told).
Showcase.invitedTo = function(_guest: Player, _host: Player) end

export type Page = { featured: { string }, arrange: string, vault: string, suite: string, theme: string, themes: { [string]: boolean } }

local invited: { [Player]: { [number]: boolean } } = {}

-- A guest's page of the displays, tidied (made on first asking).
function Showcase.page(data: Profiles.Data): Page
	local d = data :: any
	if type(d.showcase) ~= "table" then
		d.showcase = {}
	end
	local s = d.showcase
	if type(s.featured) ~= "table" then
		s.featured = {}
	end
	if type(s.arrange) ~= "string" or not Rules.arrangementById[s.arrange] then
		s.arrange = "rarity"
	end
	if type(s.vault) ~= "string" or not Rules.vaultPrivacyById[s.vault] then
		s.vault = "everyone"
	end
	if type(s.suite) ~= "string" or not Rules.suitePrivacyById[s.suite] then
		s.suite = "friends"
	end
	if type(s.themes) ~= "table" then
		s.themes = {}
	end
	s.themes.noir = true
	if type(s.theme) ~= "string" or not Rules.themeById[s.theme] then
		s.theme = "noir"
	end
	return s :: Page
end

-- The featured curios a guest still holds (one traded away leaves its dome empty).
function Showcase.featured(data: Profiles.Data): { string }
	local out = {}
	for _, id in Showcase.page(data).featured do
		if type(id) == "string" and CurioList.byId[id] and Curios.count(data, id) > 0 and not table.find(out, id) then
			table.insert(out, id)
		end
	end
	return out
end

local function islandKey(data: Profiles.Data): boolean
	local a = (data :: any).attractions
	return type(a) == "table" and type(a.island) == "table" and a.island.key == true
end

local function prestige(data: Profiles.Data): number
	local p = (data :: any).prestige
	return if type(p) == "table" then tonumber(p.level) or 0 else 0
end

-- Whether a guest may choose a theme now: bought, or what it comes with is theirs.
function Showcase.themeOpen(data: Profiles.Data, t: Rules.Theme): boolean
	local s = Showcase.page(data)
	if s.themes[t.id] then
		return true
	elseif t.islandKey then
		return islandKey(data)
	elseif t.prestige then
		return prestige(data) >= t.prestige
	end
	return t.gilt == nil and t.gems == nil
end

-- The collection's completion: by family and by rarity, distinct curios held of each.
function Showcase.completion(data: Profiles.Data): { families: { { [string]: any } }, rarities: { { [string]: any } }, held: number, total: number }
	local fam: { [string]: { held: number, total: number } } = {}
	local rar: { [string]: { held: number, total: number } } = {}
	local held, total = 0, 0
	for _, c in CurioList.List do
		local f = fam[c.family] or { held = 0, total = 0 }
		fam[c.family] = f
		local r = rar[c.rarity] or { held = 0, total = 0 }
		rar[c.rarity] = r
		f.total += 1
		r.total += 1
		total += 1
		if Curios.count(data, c.id) > 0 then
			f.held += 1
			r.held += 1
			held += 1
		end
	end
	local families = {}
	for _, id in { "relic", "meme", "delicacy" } do
		local f = fam[id]
		if f then
			table.insert(families, { id = id, held = f.held, total = f.total })
		end
	end
	local rarities = {}
	for _, id in CurioList.Rarities do
		local r = rar[id]
		if r then
			table.insert(rarities, { id = id, held = r.held, total = r.total })
		end
	end
	return { families = families, rarities = rarities, held = held, total = total }
end

-- The last curios a guest came by (newest first), and when each was first had.
local function history(data: Profiles.Data): ({ any }, { [string]: number })
	local c = (data :: any).curios
	local h = if type(c) == "table" and type(c.history) == "table" then c.history else {}
	local first = if type(c) == "table" and type(c.first) == "table" then c.first else {}
	return h, first
end

-- What a guest's screen is told.
function Showcase.view(player: Player): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local s = Showcase.page(data)
	local h, first = history(data)
	local themes = {}
	for _, t in Rules.Themes do
		table.insert(themes, { id = t.id, open = Showcase.themeOpen(data, t), owned = s.themes[t.id] == true, price = Rules.themePrice(t) })
	end
	local invitedList = {}
	local mine = invited[player]
	for userId in (if mine then mine else {}) :: { [number]: boolean } do
		local p = Players:GetPlayerByUserId(userId)
		if p then
			table.insert(invitedList, { userId = userId, name = Names.of(p) })
		end
	end
	local friendsHere = {}
	for _, f in Friends.inServer(player) do
		table.insert(friendsHere, { userId = f.UserId, name = Names.of(f), invited = (invited[player] or {})[f.UserId] == true })
	end
	return {
		ok = true,
		featured = Showcase.featured(data),
		arrange = s.arrange,
		vault = s.vault,
		suite = s.suite,
		theme = s.theme,
		themes = themes,
		completion = Showcase.completion(data),
		history = h,
		first = first,
		friends = friendsHere,
		invited = invitedList,
	}
end

-- Whether `viewer` may look round `host`'s Vault.
function Showcase.mayViewVault(host: Player, viewer: Player): boolean
	if host == viewer then
		return true
	end
	local data = Profiles.get(host)
	if not data then
		return false
	end
	local v = Showcase.page(data).vault
	if v == "everyone" then
		return true
	elseif v == "friends" then
		return Friends.are(host, viewer)
	end
	return false
end

-- Whether `visitor` may walk into `host`'s Suite (server/SuiteVisits asks).
function Showcase.mayVisitSuite(host: Player, visitor: Player): (boolean, string?)
	if host == visitor then
		return true, nil
	end
	local data = Profiles.get(host)
	if not data then
		return false, "Their Suite isn't open just now."
	end
	if not Friends.are(host, visitor) then
		return false, "Only friends on Roblox may visit each other's Suites."
	end
	local s = Showcase.page(data).suite
	if s == "nobody" then
		return false, Names.of(host) .. " keeps their Suite to themselves just now."
	elseif s == "invited" and not (invited[host] or {})[visitor.UserId] then
		return false, Names.of(host) .. "'s Suite is by invitation: ask them to invite you."
	end
	return true, nil
end

-- Another guest's Vault, as its owner allows: their featured curios, their collection's
-- completion, and their rarest.
function Showcase.card(viewer: Player, host: Player): { [string]: any }
	local data = Profiles.get(host)
	if not data then
		return { ok = false, why = "Their Vault isn't open just now." }
	end
	if not Showcase.mayViewVault(host, viewer) then
		return { ok = false, why = Names.of(host) .. " keeps their Vault private." }
	end
	local held = {}
	for _, c in CurioList.List do
		if Curios.count(data, c.id) > 0 then
			table.insert(held, c.id)
		end
	end
	table.sort(held, CurioList.compare)
	local rarest = {}
	for i = 1, math.min(6, #held) do
		table.insert(rarest, held[i])
	end
	return { ok = true, name = Names.of(host), userId = host.UserId, featured = Showcase.featured(data), completion = Showcase.completion(data), rarest = rarest }
end

-- Pays a price: Gilt and/or Gems, all of it or none of it.
local function spend(player: Player, data: Profiles.Data, gilt: number, gems: number, sink: string): boolean
	local d = data :: any
	if (tonumber(d.gilt) or 0) < gilt or (tonumber(d.gems) or 0) < gems then
		return false
	end
	if gilt > 0 then
		d.gilt -= gilt
		Analytics.sink(player, "Gilt", gilt, d.gilt, sink)
		Gilt.changed(player)
	end
	if gems > 0 then
		d.gems -= gems
		player:SetAttribute("Gems", d.gems)
		Analytics.sink(player, "Gems", gems, d.gems, sink)
		Curios.push(player)
	end
	pcall(Fortune.sync, player)
	return true
end

local function publish(player: Player, data: Profiles.Data)
	player:SetAttribute("SuiteTheme", Showcase.page(data).theme)
end
Showcase.publish = publish

local ASK_KEYS = { op = true, items = true, what = true, value = true, userId = true }

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 5, 1)
	if not r then
		RemoteGuard.reject(player, "showcaseAsk", "malformed")
		return { ok = false, why = "That isn't something the house does." }
	end
	for k in r do
		if not ASK_KEYS[k] then
			RemoteGuard.reject(player, "showcaseAsk", "malformed")
			return { ok = false, why = "That isn't something the house does." }
		end
	end
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local s = Showcase.page(data)
	local op = r.op
	if op == "state" then
		return Showcase.view(player)
	elseif op == "feature" then
		local items = r.items
		if type(items) ~= "table" then
			return { ok = false, why = "Choose up to four of your curios." }
		end
		local chosen: { string } = {}
		for _, id in items :: { any } do
			if type(id) ~= "string" or not CurioList.byId[id] then
				return { ok = false, why = "That isn't one of your curios." }
			end
			if Curios.count(data, id) < 1 then
				return { ok = false, why = "You don't hold " .. CurioList.byId[id].name .. "." }
			end
			if not table.find(chosen, id) then
				table.insert(chosen, id)
			end
		end
		if #chosen > Rules.FEATURED then
			return { ok = false, why = string.format("The Vault has %d domes.", Rules.FEATURED) }
		end
		s.featured = chosen
		return Showcase.view(player)
	elseif op == "arrange" then
		if type(r.what) ~= "string" or not Rules.arrangementById[r.what :: string] then
			return { ok = false, why = "That isn't one of the arrangements." }
		end
		s.arrange = r.what :: string
		return Showcase.view(player)
	elseif op == "privacy" then
		local value = r.value
		if r.what == "vault" and type(value) == "string" and Rules.vaultPrivacyById[value] then
			s.vault = value
		elseif r.what == "suite" and type(value) == "string" and Rules.suitePrivacyById[value] then
			s.suite = value
			Showcase.suiteChanged(player)
		else
			return { ok = false, why = "That isn't one of the choices." }
		end
		return Showcase.view(player)
	elseif op == "theme" or op == "buyTheme" then
		local t = if type(r.what) == "string" then Rules.themeById[r.what :: string] else nil
		if not t then
			return { ok = false, why = "That isn't one of the Suite's themes." }
		end
		if not Showcase.themeOpen(data, t) then
			if op ~= "buyTheme" or (t.gilt == nil and t.gems == nil) then
				return { ok = false, why = if t.islandKey then "It comes with the Island Key." elseif t.prestige then "It comes with Maison Prestige " .. t.prestige .. "." else "Buy it first." }
			end
			if not spend(player, data, t.gilt or 0, t.gems or 0, "Suite theme") then
				return { ok = false, why = "You don't have enough for that just now." }
			end
			s.themes[t.id] = true
		end
		s.theme = t.id
		publish(player, data)
		return Showcase.view(player)
	elseif op == "invite" or op == "uninvite" then
		local id = RemoteGuard.number(r.userId, 1, 1e15, true)
		local guest = if id then Players:GetPlayerByUserId(id) else nil
		if not guest or guest == player then
			return { ok = false, why = "They aren't in the house." }
		end
		if not Friends.are(player, guest) then
			return { ok = false, why = "Only friends on Roblox may visit each other's Suites." }
		end
		invited[player] = invited[player] or {}
		if op == "invite" then
			invited[player][guest.UserId] = true
			Showcase.invitedTo(guest, player)
		else
			invited[player][guest.UserId] = nil
			Showcase.suiteChanged(player)
		end
		return Showcase.view(player)
	elseif op == "visit" then
		local id = RemoteGuard.number(r.userId, 1, 1e15, true)
		local host = if id then Players:GetPlayerByUserId(id) else nil
		if not host then
			return { ok = false, why = "They aren't in the house." }
		end
		return Showcase.card(player, host)
	elseif op == "guests" then
		local out = {}
		for _, p in Players:GetPlayers() do
			if p ~= player then
				table.insert(out, { userId = p.UserId, name = Names.of(p), open = Showcase.mayViewVault(p, player) })
			end
		end
		return { ok = true, guests = out }
	end
	return { ok = false, why = "That isn't something the house does." }
end
Showcase.handle = onAsk

function Showcase.start()
	RemoteGuard.invoke(Remotes.func("ShowcaseAsk"), "showcaseAsk", onAsk)
	Profiles.Loaded:Connect(function(player: Player)
		local data = Profiles.get(player)
		if data then
			publish(player, data)
		end
	end)
	for _, player in Players:GetPlayers() do
		local data = Profiles.get(player)
		if data then
			publish(player, data)
		end
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		invited[player] = nil
		for _, list in invited do
			list[player.UserId] = nil
		end
	end)
end

return Showcase

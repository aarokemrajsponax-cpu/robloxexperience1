--!strict
-- The Gem Shop on the server (Shared/GemShop has the list). A guest's screen names what it wants
-- (an item's id) and never a price, an amount or a duration: those come from the list here, and
-- Gems are only taken when the guest holds enough. Auras and titles are kept for good and worn one
-- at a time; Surges run for half an hour from when they're bought; Gilt is changed at the set rate;
-- the Cabinet's curios are bought through Curios (one fixed price each). Nothing is random.
--
-- What everyone sees: the aura worn ("Aura", drawn round the guest on every screen) and the title
-- (under the name on the nameplate).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemList = require(ReplicatedStorage.Shared.GemShop)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Curios = require(script.Parent.Curios)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local GemShop = {}

-- Set by Main.
GemShop.award = function(_player: Player, _key: string) end
GemShop.tally = function(_player: Player, _stat: string, _n: number) end
GemShop.changed = function(_player: Player) end -- the nameplate (a title worn)

type Shop = { owned: { [string]: boolean }, aura: string, title: string, giltUntil: number, xpUntil: number }

local function shop(data: Profiles.Data): Shop
	local d = data :: any
	if type(d.gemShop) ~= "table" then
		d.gemShop = { owned = {}, aura = "", title = "", giltUntil = 0, xpUntil = 0 }
	end
	local s = d.gemShop
	s.owned = if type(s.owned) == "table" then s.owned else {}
	s.aura = if type(s.aura) == "string" then s.aura else ""
	s.title = if type(s.title) == "string" then s.title else ""
	s.giltUntil = if type(s.giltUntil) == "number" then s.giltUntil else 0
	s.xpUntil = if type(s.xpUntil) == "number" then s.xpUntil else 0
	if type(d.gems) ~= "number" then
		d.gems = 0
	end
	return s
end
GemShop.shop = shop

-- What everyone sees: the aura and the title.
function GemShop.apply(player: Player)
	local data = Profiles.get(player)
	if not data then
		return
	end
	local s = shop(data)
	local aura = GemList.byId[s.aura]
	player:SetAttribute("Aura", if aura and aura.kind == "aura" and s.owned[s.aura] then s.aura else nil)
	local title = GemList.byId[s.title]
	player:SetAttribute("Title", if title and title.kind == "title" and s.owned[s.title] then title.name else nil)
	player:SetAttribute("Gems", data.gems)
	player:SetAttribute("GiltSurgeUntil", if s.giltUntil > os.time() then s.giltUntil else nil)
	player:SetAttribute("XPSurgeUntil", if s.xpUntil > os.time() then s.xpUntil else nil)
end

-- The guest's own Surges, for Gilt and Progress.
function GemShop.giltBoost(player: Player): number
	local data = Profiles.get(player)
	return if data and shop(data).giltUntil > os.time() then 1.5 else 1
end
function GemShop.xpSurge(player: Player): boolean
	local data = Profiles.get(player)
	return data ~= nil and shop(data).xpUntil > os.time()
end

function GemShop.state(data: Profiles.Data): { [string]: any }
	local s = shop(data)
	return { ok = true, gems = data.gems, owned = table.clone(s.owned), aura = s.aura, title = s.title, giltUntil = s.giltUntil, xpUntil = s.xpUntil, now = os.time(), cabinet = Curios.cabinet() }
end

local function spend(player: Player, data: Profiles.Data, price: number, what: string): boolean
	if data.gems < price then
		return false
	end
	data.gems -= price
	Analytics.sink(player, "Gems", price, data.gems, what)
	GemShop.tally(player, "gemsSpent", price)
	return true
end

function GemShop.buy(player: Player, data: Profiles.Data, id: string): { [string]: any }
	local item = GemList.byId[id]
	if not item then
		return { ok = false, why = "That isn't in the Gem Shop." }
	end
	local s = shop(data)
	if (item.kind == "aura" or item.kind == "title") and s.owned[id] then
		return { ok = false, why = "You already have it: wear it from here." }
	end
	if data.gems < item.gems then
		return { ok = false, why = string.format("Not enough Gems yet: %d more.", item.gems - data.gems) }
	end
	spend(player, data, item.gems, "gemShop_" .. id)
	if item.kind == "aura" then
		s.owned[id] = true
		s.aura = id
	elseif item.kind == "title" then
		s.owned[id] = true
		s.title = id
		GemShop.award(player, "firstTitle")
	elseif item.kind == "boost" then
		local now = os.time()
		local key = if item.style.boost == "xp" then "xpUntil" else "giltUntil"
		local from = math.max(now, (s :: any)[key])
		;(s :: any)[key] = math.min(now + GemList.SURGE_CAP, from + (item.style.seconds :: number))
		GemShop.award(player, "surge")
	elseif item.kind == "exchange" then
		local gilt = item.style.gilt :: number
		data.gilt += gilt
		Analytics.source(player, "Gilt", gilt, data.gilt, "Gems changed for Gilt")
		Gilt.changed(player)
		GemShop.award(player, "exchange")
	end
	GemShop.apply(player)
	GemShop.changed(player)
	GemShop.tally(player, "gemShop", 0) -- (checks the ladders: auras owned)
	Curios.push(player)
	return GemShop.state(data)
end

function GemShop.equip(player: Player, data: Profiles.Data, kind: string, id: string): { [string]: any }
	local s = shop(data)
	if id ~= "" then
		local item = GemList.byId[id]
		if not item or item.kind ~= kind or not s.owned[id] then
			return { ok = false, why = "You don't have that one yet." }
		end
	end
	if kind == "aura" then
		s.aura = id
	elseif kind == "title" then
		s.title = id
		if id ~= "" then
			GemShop.award(player, "firstTitle")
		end
	else
		return { ok = false, why = "That can't be worn." }
	end
	GemShop.apply(player)
	GemShop.changed(player)
	return GemShop.state(data)
end

local ASK_KEYS = { op = true, id = true, kind = true }

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 3, 0)
	if not r then
		RemoteGuard.reject(player, "gemAsk", "malformed")
		return { ok = false, why = "That isn't something the Gem Shop does." }
	end
	for k in r do
		if not ASK_KEYS[k] then
			RemoteGuard.reject(player, "gemAsk", "malformed")
			return { ok = false, why = "That isn't something the Gem Shop does." }
		end
	end
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	if r.op == "state" then
		return GemShop.state(data)
	elseif r.op == "buy" then
		local id = RemoteGuard.string(r.id, 40)
		if not id then
			return { ok = false, why = "That isn't in the Gem Shop." }
		end
		return GemShop.buy(player, data, id)
	elseif r.op == "curio" then
		local id = RemoteGuard.string(r.id, 40)
		if not id then
			return { ok = false, why = "That isn't sold in the Cabinet." }
		end
		local before = data.gems
		local result = Curios.buy(player, data, id)
		if result.ok then
			GemShop.tally(player, "gemsSpent", before - data.gems)
			GemShop.apply(player)
		end
		return result
	elseif r.op == "equip" then
		local kind = RemoteGuard.oneOf(r.kind, { aura = true, title = true })
		local id = if r.id == "" then "" else RemoteGuard.string(r.id, 40)
		if not kind or id == nil then
			return { ok = false, why = "That can't be worn." }
		end
		return GemShop.equip(player, data, kind, id)
	end
	return { ok = false, why = "That isn't something the Gem Shop does." }
end

function GemShop.start()
	RemoteGuard.invoke(Remotes.func("GemAsk"), "gemAsk", onAsk)
	local function hello(player: Player)
		task.spawn(function()
			local data = Profiles.wait(player, 30)
			if data and player.Parent == Players then
				GemShop.apply(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hello)
	for _, p in Players:GetPlayers() do
		hello(p)
	end
	-- Surges run out on their own: the chips on screen go when they do.
	task.spawn(function()
		while true do
			task.wait(15)
			for _, p in Players:GetPlayers() do
				local a, b = p:GetAttribute("GiltSurgeUntil"), p:GetAttribute("XPSurgeUntil")
				if (type(a) == "number" and a <= os.time()) or (type(b) == "number" and b <= os.time()) then
					GemShop.apply(p)
				end
			end
		end
	end)
end

return GemShop

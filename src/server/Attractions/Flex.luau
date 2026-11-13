--!strict
-- The Flex Studio on the server (shared/Flex has the plan): what each guest may flex (only what is
-- really theirs, worked out from their own record every time), the reels on the Flex Wall, and
-- every like (one each, never your own). Everything a screen shows comes from here; nothing a
-- screen says is taken on trust beyond which of the guest's own things, which set and which of the
-- house's captions they chose. Small Gilt, within the Grand Ballroom's day's cap: the first reel
-- of the day, and a little for each like a guest's reels are given.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Curios = require(ReplicatedStorage.Shared.Curios)
local Fortune = require(ReplicatedStorage.Shared.Fortune)
local Plan = require(ReplicatedStorage.Shared.Flex)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)
local Types = require(script.Parent.Types)

local Flex = {}

-- The clock (set by tests).
Flex.now = os.clock

export type Item = { key: string, kind: string, name: string, glyph: string, rarity: string? }
type Reel = {
	id: number,
	by: string,
	userId: number,
	item: Item,
	set: string,
	caption: string,
	text: string,
	at: number,
	likes: number,
	liked: { [number]: boolean },
}
-- What Gala hands over: its context, its Gilt within the day's cap, the guest's page of the hall,
-- word to everyone in the hall, and whether a guest is busy at one of its activities.
export type Env = {
	ctx: Types.Ctx,
	pay: (player: Player, amount: number, source: string) -> number,
	page: (data: any) -> { [string]: any },
	tell: (m: { [string]: any }) -> (),
	busy: (player: Player) -> string?,
	fortune: (data: any) -> number,
}

local wall: { Reel } = {}
local serial = 0
local lastShot: { [Player]: number } = {}
local live: { by: string, untilAt: number }? = nil
local board: { part: BasePart, labels: { [string]: TextLabel } }? = nil

local function rarityRank(r: string?): number
	return if r then (Curios.RarityRank[r] or 0) else 0
end

-- Everything a guest may flex, from their own record.
function Flex.flexables(data: any, fortuneTotal: number): { Item }
	local out: { Item } = {}
	local rank = Fortune.rank(math.max(0, fortuneTotal))
	table.insert(out, { key = "fortune", kind = "fortune", name = string.format("a %s's Fortune of %s", rank.name, Fortune.format(math.floor(math.max(0, fortuneTotal)))), glyph = "💰" })
	if data.goldKey == true then
		table.insert(out, { key = "goldKey", kind = "key", name = "the Gold Key", glyph = "🔑" })
	end
	if type(data.blackCard) == "table" and data.blackCard.active == true then
		table.insert(out, { key = "blackCard", kind = "key", name = "the Black Card", glyph = "💳" })
	end
	local brainrots, curios = {}, {}
	local items = type(data.curios) == "table" and type(data.curios.items) == "table" and data.curios.items or {}
	for id, n in items do
		local c = if type(id) == "string" then Curios.byId[id] else nil
		if c and type(n) == "number" and n > 0 then
			local item: Item = { key = (if c.family == "meme" then "brainrot:" else "curio:") .. c.id, kind = if c.family == "meme" then "brainrot" else "curio", name = c.name, glyph = c.glyph, rarity = c.rarity }
			if c.family == "meme" then
				table.insert(brainrots, item)
			elseif rarityRank(c.rarity) >= rarityRank("Epic") then
				table.insert(curios, item)
			end
		end
	end
	local function best(a: Item, b: Item): boolean
		local ra, rb = rarityRank(a.rarity), rarityRank(b.rarity)
		if ra ~= rb then
			return ra > rb
		end
		return a.name < b.name
	end
	table.sort(brainrots, best)
	table.sort(curios, best)
	for i = 1, math.min(16, #brainrots) do
		table.insert(out, brainrots[i])
	end
	for i = 1, math.min(8, #curios) do
		table.insert(out, curios[i])
	end
	local pieces = {}
	for id, on in (if type(data.owned) == "table" then data.owned else {}) do
		local w = if type(id) == "string" and on == true then Wardrobe.get(id) else nil
		if w and w.kind ~= "chime" then
			table.insert(pieces, { key = "wardrobe:" .. w.id, kind = "wardrobe", name = w.name, glyph = "👔" } :: Item)
		end
	end
	table.sort(pieces, function(a, b)
		return a.name < b.name
	end)
	for i = 1, math.min(12, #pieces) do
		table.insert(out, pieces[i])
	end
	return out
end

-- A reel as a screen sees it (who liked it stays here; only whether this guest did).
local function view(r: Reel, viewer: Player?): { [string]: any }
	return {
		id = r.id,
		by = r.by,
		userId = r.userId,
		item = { name = r.item.name, glyph = r.item.glyph, rarity = r.item.rarity, kind = r.item.kind },
		set = r.set,
		text = r.text,
		likes = r.likes,
		liked = viewer ~= nil and r.liked[viewer.UserId] == true,
		mine = viewer ~= nil and r.userId == viewer.UserId,
	}
end

local function setLabel(name: string, text: string)
	local b = board
	local l = b and b.labels[name]
	if l then
		l.Text = text
	end
end

-- The Flex Wall: who's shooting now, the newest reel big, the three before it.
local function drawWall()
	local l = live
	if l and Flex.now() < l.untilAt then
		setLabel("Live", "● LIVE  ·  " .. l.by .. " is shooting a reel")
	else
		setLabel("Live", "Stand on the mark to shoot your own")
	end
	local top = wall[1]
	if top then
		setLabel("Top", string.format("@%s  ·  %s %s", top.by, top.item.glyph, top.text))
		setLabel("TopLikes", string.format("♥ %d", top.likes))
	else
		setLabel("Top", "No reels yet tonight. Be the first.")
		setLabel("TopLikes", "")
	end
	for k = 2, 4 do
		local r = wall[k]
		setLabel("Reel" .. k, if r then string.format("@%s  ·  %s  ·  ♥ %d", r.by, r.text, r.likes) else "")
	end
end

function Flex.build(b: { part: BasePart, labels: { [string]: TextLabel } }?)
	board = b
	drawWall()
end

function Flex.step()
	local l = live
	if l and Flex.now() >= l.untilAt then
		live = nil
		drawWall()
	end
end

function Flex.leave(player: Player)
	lastShot[player] = nil
end

-- The picker: what this guest may flex, the sets, the captions, and the wall.
function Flex.list(env: Env, player: Player): { [string]: any }
	local data = env.ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local sets, captions = {}, {}
	for _, s in Plan.Sets do
		table.insert(sets, { id = s.id, name = s.name, line = s.line, glyph = s.glyph })
	end
	for _, c in Plan.Captions do
		table.insert(captions, { id = c.id, text = c.text })
	end
	local reels = {}
	for _, r in wall do
		table.insert(reels, view(r, player))
	end
	local left = 0
	local shot = lastShot[player]
	if shot then
		left = math.max(0, math.ceil(Plan.COOLDOWN - (Flex.now() - shot)))
	end
	return { ok = true, items = Flex.flexables(data, env.fortune(data)), sets = sets, captions = captions, reels = reels, wait = left }
end

-- Shooting a reel: on the mark, something of the guest's own, a set and a caption of the house's.
function Flex.record(env: Env, player: Player, r: { [string]: unknown }): { [string]: any }
	local ctx = env.ctx
	if ctx.inside(player) ~= "gala" then
		return { ok = false, why = "Come into the Grand Ballroom first." }
	end
	local data = ctx.data(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	local at = ctx.at(player, "gala")
	if not at or not Plan.onMark(at) then
		return { ok = false, why = "Stand on the gold mark in the Flex Studio to shoot." }
	end
	local doing = env.busy(player)
	if doing then
		return { ok = false, why = "Finish " .. doing .. " first." }
	end
	local shot = lastShot[player]
	if shot and Flex.now() - shot < Plan.COOLDOWN then
		return { ok = false, why = string.format("One reel at a time: the next in %d seconds.", math.ceil(Plan.COOLDOWN - (Flex.now() - shot))) }
	end
	local key, setId, capId = r.item, r.set, r.line
	if type(key) ~= "string" or #key > 48 then
		return { ok = false, why = "Choose something of yours to flex." }
	end
	local item: Item? = nil
	for _, it in Flex.flexables(data, env.fortune(data)) do
		if it.key == key then
			item = it
		end
	end
	if not item then
		return { ok = false, why = "That isn't yours to flex." }
	end
	if type(setId) ~= "string" or not Plan.setById[setId] then
		return { ok = false, why = "Choose a set." }
	end
	if type(capId) ~= "string" or not Plan.captionById[capId] then
		return { ok = false, why = "Choose a caption." }
	end
	local chosen = item :: Item
	serial += 1
	local reel: Reel = {
		id = serial,
		by = player.DisplayName,
		userId = player.UserId,
		item = chosen,
		set = setId,
		caption = capId,
		text = Plan.caption(capId, chosen.name) or chosen.name,
		at = os.time(),
		likes = 0,
		liked = {},
	}
	table.insert(wall, 1, reel)
	while #wall > Plan.WALL_SIZE do
		table.remove(wall)
	end
	lastShot[player] = Flex.now()
	live = { by = reel.by, untilAt = Flex.now() + Plan.REEL_SECONDS }
	drawWall()
	-- The first reel of the day: a little Gilt.
	local p = env.page(data)
	local gilt = 0
	if (tonumber(p.reels) or 0) == 0 then
		gilt = env.pay(player, Plan.REWARDS.firstReel, "The Flex Studio: your first reel today")
	end
	p.reels = (tonumber(p.reels) or 0) + 1
	env.tell({ kind = "flex", what = "reel", reel = view(reel, nil), live = Plan.REEL_SECONDS })
	return { ok = true, reel = view(reel, player), gilt = gilt }
end

-- A like: in the hall, someone else's reel, once.
function Flex.like(env: Env, player: Player, id: unknown): { [string]: any }
	local ctx = env.ctx
	if ctx.inside(player) ~= "gala" then
		return { ok = false, why = "Come into the Grand Ballroom first." }
	end
	local reel: Reel? = nil
	for _, r in wall do
		if r.id == id then
			reel = r
		end
	end
	if not reel then
		return { ok = false, why = "That reel is off the wall now." }
	end
	local rl = reel :: Reel
	if rl.userId == player.UserId then
		return { ok = false, why = "That's your own reel." }
	end
	if rl.liked[player.UserId] then
		return { ok = false, why = "You've liked it already." }
	end
	rl.liked[player.UserId] = true
	rl.likes += 1
	-- A little for its maker, if they're still here (so many likes a day).
	local maker = Players:GetPlayerByUserId(rl.userId)
	if maker then
		local data = ctx.data(maker)
		if data then
			local p = env.page(data)
			local paidToday = tonumber(p.likesPaid) or 0
			if paidToday < Plan.REWARDS.likesPaid then
				p.likesPaid = paidToday + 1
				env.pay(maker, Plan.REWARDS.like, "The Flex Studio: a like")
			end
		end
	end
	drawWall()
	env.tell({ kind = "flex", what = "likes", id = rl.id, likes = rl.likes })
	return { ok = true, id = rl.id, likes = rl.likes }
end

-- For tests.
function Flex.internals(): { [string]: any }
	return { wall = wall, lastShot = lastShot }
end

return Flex

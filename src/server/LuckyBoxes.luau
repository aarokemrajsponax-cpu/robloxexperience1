--!strict
-- The Luxe Lucky Boxes on the server (shared/LuckyBoxes has the boxes and their odds). A box is a
-- developer product: its receipt is granted here, once (the purchase system's receipts are
-- idempotent, and a failed grant is rolled back and delivered again). The roll is made here, with
-- the server's own random numbers and the odds shown on the box, never anything a screen says.
--
-- Each guest's page (data.luckyBoxes): how many of each box they've opened, how many in a row
-- without the box's guarantee rarity (the pity counter on the box), and their last few opens.
--
-- Only sold to a guest whose Roblox policy allows paid random items (Policy.paidRandomAllowed:
-- false until Roblox says so). Their screen hides the boxes' keys; the purchase is refused here too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Boxes = require(ReplicatedStorage.Shared.LuckyBoxes)
local BrainrotList = require(ReplicatedStorage.Shared.Brainrots)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Brainrots = require(script.Parent.Brainrots)
local Curios = require(script.Parent.Curios)
local Policy = require(script.Parent.Policy)
local Profiles = require(script.Parent.Profiles)
local Catalog = require(script.Parent.Purchases.Catalog)
local Grants = require(script.Parent.Purchases.Grants)
local Store = require(script.Parent.Purchases.Store)

local LuckyBoxes = {}

local LOG = 8 -- the last opens kept
local LATELY = 5 -- this server's latest real opens, shown in the showroom

-- This server's latest opens, as they really came (newest first): who, what, from which box.
local lately: { { [string]: any } } = {}

-- The random numbers (a test can make them fixed) and whether this guest may buy (a test can say).
LuckyBoxes.random = Random.new()
LuckyBoxes.allowed = function(player: Player): boolean
	return Policy.paidRandomAllowed(player)
end

local curioEvent = Remotes.event("Curio")

LuckyBoxes.CLOSED = "Lucky Boxes aren't available on your account: Roblox's settings for it don't allow paid random items. The Cabinet sells the exact curio you choose, and brainrots turn up free at the tables."

type Page = { opened: { [string]: number }, since: { [string]: number }, log: { { [string]: any } } }

local function pageOf(data: Profiles.Data): Page
	local d = data :: any
	if type(d.luckyBoxes) ~= "table" then
		d.luckyBoxes = {}
	end
	local p = d.luckyBoxes
	p.opened = if type(p.opened) == "table" then p.opened else {}
	p.since = if type(p.since) == "table" then p.since else {}
	p.log = if type(p.log) == "table" then p.log else {}
	return p :: Page
end
LuckyBoxes.pageOf = pageOf

-- One open of `box` for this guest: the pick, its mutation, their counters. Returns what came.
function LuckyBoxes.open(player: Player?, data: Profiles.Data, boxId: string): { [string]: any }?
	local box = Boxes.Boxes[boxId]
	if not box then
		return nil
	end
	local page = pageOf(data)
	local since = math.max(0, tonumber(page.since[boxId]) or 0)
	local forced = since + 1 >= box.pity.at
	local rng = LuckyBoxes.random
	local id, rarity = Boxes.pick(boxId, rng:NextNumber(), rng:NextNumber(), forced)
	if not id or not rarity then
		error("an empty Lucky Box: " .. boxId)
	end
	local mut = Boxes.mutation(boxId, rng:NextNumber())
	local before = Curios.count(data, id)
	Curios.give(player, data, id, 1, "luckyBox")
	if mut then
		Brainrots.giveMutation(data, id, mut)
	end
	page.opened[boxId] = (tonumber(page.opened[boxId]) or 0) + 1
	page.since[boxId] = if Boxes.rank(rarity) >= Boxes.rank(box.pity.rarity) then 0 else since + 1
	table.insert(page.log, 1, { box = boxId, id = id, mut = mut, at = os.time() })
	while #page.log > LOG do
		table.remove(page.log)
	end
	local count = before + 1
	return {
		box = boxId,
		id = id,
		rarity = rarity,
		mut = mut,
		new = before == 0,
		count = count,
		stars = BrainrotList.stars(count),
		forced = forced,
		pityLeft = Boxes.pityLeft(boxId, page.since[boxId]),
		rate = BrainrotList.rate(id, count, mut),
	}
end

local function grant(ctx: Grants.Context)
	local reward = ctx.product.Reward
	if reward.Type ~= "LuckyBox" or not Boxes.Boxes[reward.Box] then
		error("not a Lucky Box: " .. tostring(reward.Type))
	end
	local player = ctx.player
	local got = LuckyBoxes.open(player, ctx.data, reward.Box)
	if not got then
		error("the box didn't open")
	end
	ctx:after(function()
		Analytics.custom(player, "LuckyBox", 1, { box = reward.Box, curio = got.id, rarity = got.rarity, mut = got.mut or "", forced = got.forced })
		Curios.push(player)
		curioEvent:FireClient(player, { op = "luckyBox", result = got })
		LuckyBoxes.noteOpen(player, got)
	end)
end

-- A real open, for the showroom's "lately" (this server only). A Mythic is also told to the others
-- here, once, in a line (never to a guest the boxes aren't sold to).
function LuckyBoxes.noteOpen(player: Player, got: { [string]: any })
	table.insert(lately, 1, { name = player.DisplayName, id = got.id, rarity = got.rarity, mut = got.mut, box = got.box })
	while #lately > LATELY do
		table.remove(lately)
	end
	if got.rarity == "Mythic" then
		for _, other in Players:GetPlayers() do
			if other ~= player and LuckyBoxes.allowed(other) then
				curioEvent:FireClient(other, { op = "luckyPull", name = player.DisplayName, id = got.id, rarity = got.rarity, mut = got.mut, box = got.box })
			end
		end
	end
end

-- What the showroom shows: each box (its price from Roblox, whether it's on sale), the odds of
-- every brainrot in it, its mutation odds, the guest's guarantee counter, and their last opens.
function LuckyBoxes.state(player: Player, data: Profiles.Data): { [string]: any }
	local page = pageOf(data)
	local boxes = {}
	for _, boxId in Boxes.Order do
		local b = Boxes.Boxes[boxId]
		local odds = {}
		for _, o in Boxes.odds(boxId) do
			table.insert(odds, { id = o.id, rarity = o.rarity, chance = o.chance, held = Curios.count(data, o.id) })
		end
		table.insert(boxes, {
			id = boxId,
			key = b.key,
			price = Catalog.price(b.key) or b.price,
			priced = Catalog.price(b.key) ~= nil,
			ready = Catalog.enabled(b.key),
			odds = odds,
			mut = { gold = b.mut.gold, diamond = b.mut.diamond, rainbow = b.mut.rainbow, plain = Boxes.plain(boxId) },
			pity = { at = b.pity.at, rarity = b.pity.rarity, left = Boxes.pityLeft(boxId, tonumber(page.since[boxId]) or 0) },
			opened = tonumber(page.opened[boxId]) or 0,
		})
	end
	local log = {}
	for _, e in page.log do
		if type(e) == "table" and type(e.id) == "string" and CurioList.byId[e.id] then
			table.insert(log, { box = e.box, id = e.id, mut = e.mut })
		end
	end
	local recent = {}
	for _, e in lately do
		table.insert(recent, table.clone(e))
	end
	local ok = LuckyBoxes.allowed(player)
	return { ok = true, allowed = ok, why = if ok then nil else LuckyBoxes.CLOSED, boxes = if ok then boxes else {}, log = log, lately = if ok then recent else {} }
end

-- The showroom's requests (CurioAsk): its state, and opening a box (the purchase window).
local function onOp(player: Player, data: Profiles.Data, r: { [string]: any }): { [string]: any }
	if r.op == "luckyState" then
		return LuckyBoxes.state(player, data)
	elseif r.op == "luckyOpen" then
		local box = if type(r.id) == "string" then Boxes.Boxes[r.id] else nil
		if not box then
			return { ok = false, why = "That isn't one of the Lucky Boxes." }
		end
		if not LuckyBoxes.allowed(player) then
			return { ok = false, why = LuckyBoxes.CLOSED, closed = true }
		end
		local ok, why = Store.prompt(player, box.key, "luckyBoxes")
		return { ok = ok, why = why, prompted = ok }
	end
	return { ok = false, why = "That isn't something the showroom does." }
end

function LuckyBoxes.start()
	Grants.register("luckyBox", grant)
	for _, key in Boxes.Order do
		Store.eligibility[Boxes.Boxes[key].key] = function(player: Player, _data: Profiles.Data): (boolean, string?)
			if not LuckyBoxes.allowed(player) then
				return false, LuckyBoxes.CLOSED
			end
			return true, nil
		end
	end
	Curios.ops.luckyState = onOp
	Curios.ops.luckyOpen = onOp
end

return LuckyBoxes

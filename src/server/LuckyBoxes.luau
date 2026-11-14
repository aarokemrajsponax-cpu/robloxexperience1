--!strict
-- The Luxe Lucky Boxes on the server (shared/LuckyBoxes has the boxes and their odds). A box is
-- opened for Gems or (far dearer) Gilt, here (Build 85; until then for Robux): the price is the
-- box's own, never one a screen sends; it's taken and the box opened in one step, with nothing in
-- between to yield, so the same Gems can't open two boxes; if the open fails, it's given back. The
-- roll is made here, with the server's own random numbers and the odds shown on the box.
--
-- Each guest's page (data.luckyBoxes): how many of each box they've opened, how many in a row
-- without the box's guarantee rarity (the pity counter on the box), and their last few opens.
--
-- Gems and Gilt can both be bought with Robux, so the boxes are still paid random items: only
-- opened by a guest whose Roblox policy allows them (Policy.paidRandomAllowed: false until Roblox
-- says so). Their screen hides the boxes; an open is refused here too.

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
local Gilt = require(script.Parent.Gilt)

local LuckyBoxes = {}

local LOG = 8 -- the last opens kept
local LATELY = 5 -- this server's latest real opens, shown in the showroom
local GAP = 1 -- seconds: one open at a time (the reel takes longer than this anyway)
local lastOpen: { [Player]: number } = {}

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

-- Opens a box for Gems or Gilt (`pay`), at the box's own price. Returns what the screen is told.
function LuckyBoxes.buy(player: Player, data: Profiles.Data, boxId: string, pay: string): { [string]: any }
	local box = Boxes.Boxes[boxId]
	if not box then
		return { ok = false, why = "That isn't one of the Lucky Boxes." }
	end
	if pay ~= "gems" and pay ~= "gilt" then
		return { ok = false, why = "Open it with Gems or with Gilt." }
	end
	if not LuckyBoxes.allowed(player) then
		return { ok = false, why = LuckyBoxes.CLOSED, closed = true }
	end
	local now = os.clock()
	if lastOpen[player] and now - lastOpen[player] < GAP then
		return { ok = false, why = "One box at a time." }
	end
	local d = data :: any
	local price = if pay == "gems" then box.gems else box.gilt
	local have = if pay == "gems" then (tonumber(d.gems) or 0) else (tonumber(d.gilt) or 0)
	if have < price then
		return { ok = false, why = if pay == "gems" then "Insufficient Gems" else "Insufficient Gilt", short = price - have, pay = pay }
	end
	lastOpen[player] = now
	-- Taken and opened in one step (nothing here yields); put back as it was if the open fails.
	local gemsBefore, giltBefore = d.gems, d.gilt
	if pay == "gems" then
		d.gems -= price
	else
		d.gilt -= price
	end
	local ok, got = pcall(LuckyBoxes.open, player, data, boxId)
	if not ok or not got then
		d.gems = gemsBefore
		d.gilt = giltBefore
		warn("[Maison] A Lucky Box didn't open: " .. tostring(got))
		return { ok = false, why = "The box wouldn't open. Nothing was taken: try again." }
	end
	got.pay = pay
	got.price = price
	Analytics.sink(player, if pay == "gems" then "Gems" else "Gilt", price, if pay == "gems" then d.gems else d.gilt, "luckyBox_" .. boxId)
	Analytics.custom(player, "LuckyBox", 1, { box = boxId, curio = got.id, rarity = got.rarity, mut = got.mut or "", forced = got.forced })
	if pay == "gilt" then
		Gilt.changed(player)
	end
	Curios.push(player)
	LuckyBoxes.noteOpen(player, got)
	return { ok = true, result = got, gems = d.gems, gilt = d.gilt }
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
			gems = b.gems,
			gilt = b.gilt,
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
	local d = data :: any
	return { ok = true, allowed = ok, why = if ok then nil else LuckyBoxes.CLOSED, boxes = if ok then boxes else {}, log = log, lately = if ok then recent else {}, gems = tonumber(d.gems) or 0, gilt = tonumber(d.gilt) or 0 }
end

-- The showroom's requests (CurioAsk): its state, and opening a box (`id` the box, `key` "gems" or
-- "gilt").
local function onOp(player: Player, data: Profiles.Data, r: { [string]: any }): { [string]: any }
	if r.op == "luckyState" then
		return LuckyBoxes.state(player, data)
	elseif r.op == "luckyOpen" then
		local boxId = if type(r.id) == "string" then r.id else ""
		local pay = if type(r.key) == "string" then r.key else "gems"
		return LuckyBoxes.buy(player, data, boxId, pay)
	end
	return { ok = false, why = "That isn't something the showroom does." }
end

function LuckyBoxes.start()
	Curios.ops.luckyState = onOp
	Curios.ops.luckyOpen = onOp
	Players.PlayerRemoving:Connect(function(player: Player)
		lastOpen[player] = nil
	end)
end

return LuckyBoxes

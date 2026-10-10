--!strict
-- Megalodon Rainmaker: gold rains on the whole house, every guest gets a share of Gilt, and
-- everyone sees who made it rain (ProductConfig megalodonRainmaker).
--
-- The receipt grants the buyer's own bonus Gilt and a rain credit, both in the same durable write
-- as the PurchaseId. The rain itself starts afterwards, when the sky is free: one rain at a time
-- in a house, with a gap between them. Rains waiting their turn are simply the credits held by
-- guests in the house, oldest first; a buyer who leaves takes theirs along (it's in their
-- profile) and it starts in whichever house they're in next.
--
-- Every rain has one event id (its PurchaseId when it starts straight from its purchase, a fresh
-- GUID when it starts from a kept credit). A share is given by writing the Gilt and that id into
-- the recipient's profile together, and only if the id isn't there yet, so nobody is paid twice
-- for one rain: not on a rejoin, not on a second server.
--
--   Joins while it rains:  their share, once (at most Reward.MaxRecipients guests per rain).
--   Leaves while it rains: what they got is theirs (it's saved with their profile).
--   Reconnects:            the event id is already in their profile: nothing more.
--   The buyer leaves:      a rain that has started goes on; one still waiting goes with them.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Names = require(ReplicatedStorage.Shared.Names)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Analytics = require(script.Parent.Parent.Analytics)
local Profiles = require(script.Parent.Parent.Profiles)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)
local Telemetry = require(script.Parent.Telemetry)

local Rain = {}

Rain.KEY = "megalodonRainmaker"
Rain.CREDIT = "rain"
local RAINS_KEPT = 30 -- event ids remembered in each profile

-- Told after Gilt changes hands (set by Main: the guest's purse on screen).
Rain.giltChanged = function(_player: Player) end

type Active = { id: string, by: string, user: string, byUserId: number, endsAt: number, given: { [number]: boolean }, count: number }

local active: Active? = nil
local nextAt = 0 -- os.clock() when the next rain may start
local waitingSince: { [Player]: number } = {} -- when each holder of a rain credit started waiting
local nextIds: { [Player]: { string } } = {} -- PurchaseIds of rains just bought, to start under their own id

local function entry(): ProductConfig.Entry
	return ProductConfig.byKey[Rain.KEY]
end

-- The line the whole house sees.
function Rain.line(name: string): string
	return string.format("%s triggered MEGALODON RAIN!", name)
end

-- The rain falling now, if any.
function Rain.active(): Active?
	if active and os.clock() < active.endsAt then
		return active
	end
	return nil
end

-- Rains waiting their turn in this house (credits held by the guests here).
function Rain.waiting(): number
	local n = 0
	for _, p in Players:GetPlayers() do
		local data = Profiles.get(p)
		if data then
			n += Perks.credits(data, Rain.CREDIT)
		end
	end
	return n
end

-- Gives one guest their share of a rain, once. True if they got it now.
function Rain.give(player: Player, data: Profiles.Data, rain: Active): boolean
	local reward = entry().Reward
	if rain.given[player.UserId] or rain.count >= reward.MaxRecipients then
		return false
	end
	if table.find(data.perks.rains, rain.id) then
		rain.given[player.UserId] = true -- a rejoin: already paid by this rain
		return false
	end
	-- The Gilt and the event id, written together (one profile, one save).
	data.gilt += reward.ShareGilt
	table.insert(data.perks.rains, rain.id)
	while #data.perks.rains > RAINS_KEPT do
		table.remove(data.perks.rains, 1)
	end
	rain.given[player.UserId] = true
	rain.count += 1
	Analytics.source(player, "Gilt", reward.ShareGilt, data.gilt, "Rain")
	Perks.tell(player, { op = "rainShare", id = rain.id, gilt = reward.ShareGilt, by = rain.by })
	Rain.giltChanged(player)
	return true
end

-- Starts a rain from one of `buyer`'s credits, now. False if it can't start now.
local function start(buyer: Player, data: Profiles.Data, id: string?): boolean
	if Rain.active() or os.clock() < nextAt or Perks.credits(data, Rain.CREDIT) <= 0 then
		return false
	end
	if not Perks.use(buyer, data, Rain.CREDIT, Rain.KEY) then
		return false
	end
	local reward, rules = entry().Reward, entry().Rules
	local rain: Active = {
		id = id or HttpService:GenerateGUID(false),
		by = Names.of(buyer),
		user = buyer.Name,
		byUserId = buyer.UserId,
		endsAt = os.clock() + reward.DurationSeconds,
		given = {},
		count = 0,
	}
	active = rain
	nextAt = rain.endsAt + rules.ServerGapSeconds
	if Perks.credits(data, Rain.CREDIT) <= 0 then
		waitingSince[buyer] = nil
	end
	Perks.tellAll({
		op = "rain",
		id = rain.id,
		by = rain.by,
		user = rain.user,
		userId = rain.byUserId,
		share = reward.ShareGilt,
		seconds = reward.DurationSeconds,
		line = Rain.line(rain.by),
	})
	-- Everyone here now gets their share at once; guests who arrive while it falls, as they do.
	local players = Players:GetPlayers()
	table.sort(players, function(a, b)
		return (if a == buyer then 0 else 1) < (if b == buyer then 0 else 1)
	end)
	for _, p in players do
		local d = Profiles.get(p)
		if d then
			Rain.give(p, d, rain)
		end
	end
	Telemetry.log(buyer, Telemetry.Events.Used, Rain.KEY, "rain_started", rain.count)
	Perks.push(buyer)
	return true
end

-- The buyer's next rain: under the PurchaseId it was bought with, if it's one just bought.
local function startFor(player: Player, data: Profiles.Data): boolean
	local ids = nextIds[player]
	local id = if ids and #ids > 0 then ids[1] else nil
	if start(player, data, id) then
		if ids and #ids > 0 then
			table.remove(ids, 1)
		end
		return true
	end
	return false
end

-- Starts the rain that has waited longest, if the sky is free.
local function startNext()
	if Rain.active() or os.clock() < nextAt then
		return
	end
	local best: Player? = nil
	for p, since in waitingSince do
		local data = Profiles.get(p)
		if p.Parent ~= Players or not data or Perks.credits(data, Rain.CREDIT) <= 0 then
			waitingSince[p] = nil
		elseif best == nil or since < waitingSince[best] then
			best = p
		end
	end
	if best then
		local data = Profiles.get(best)
		if data then
			startFor(best, data)
		end
	end
end

local function grant(ctx: Grants.Context)
	local reward = ctx.product.Reward
	-- The buyer's own bonus is part of the receipt: saved with it, whatever happens to the rain.
	ctx.data.gilt += reward.PurchaserBonusGilt
	Perks.add(ctx.data, Rain.CREDIT, 1)
	local player, data, id = ctx.player, ctx.data, ctx.purchaseId
	ctx:after(function()
		Analytics.source(player, "Gilt", reward.PurchaserBonusGilt, data.gilt, "Purchase")
		Rain.giltChanged(player)
		local ids = nextIds[player] or {}
		nextIds[player] = ids
		table.insert(ids, id)
		if not waitingSince[player] then
			waitingSince[player] = os.clock()
		end
		startNext()
		local now = Rain.active()
		if not now or now.id ~= id then
			Perks.push(player)
			Perks.tell(player, {
				op = "notice",
				title = "Megalodon Rainmaker",
				line = string.format("+%d Gilt for you. Your rain is next in line: it starts as soon as the sky is clear.", reward.PurchaserBonusGilt),
			})
		end
	end)
end

function Rain.start()
	Grants.register("rain", grant)
	Store.eligibility[Rain.KEY] = function(_player: Player, data: Profiles.Data): (boolean, string?)
		local rules = entry().Rules
		if Perks.credits(data, Rain.CREDIT) >= (rules.MaxHeld or 3) then
			return false, "Your rains are already waiting their turn."
		end
		if Rain.waiting() >= rules.QueueMax then
			return false, "Rains are already waiting their turn in this house. Try again in a few minutes."
		end
		return true, nil
	end
	Perks.contributors.rain = function(player: Player, data: Profiles.Data): any
		local a = Rain.active()
		local position = 0
		local mine = waitingSince[player]
		if mine then
			position = 1
			for p, since in waitingSince do
				if p ~= player and since < mine then
					position += 1
				end
			end
		end
		return {
			held = Perks.credits(data, Rain.CREDIT),
			position = position,
			falling = if a then { by = a.by, left = math.max(0, math.ceil(a.endsAt - os.clock())) } else nil,
			nextIn = math.max(0, math.ceil(nextAt - os.clock())),
		}
	end
	-- A guest arriving while it rains gets their share (once per rain, whatever server they've
	-- been in); a credit they kept from before (a crash, another house) joins the line.
	Profiles.Loaded:Connect(function(player: Player, data: Profiles.Data)
		local a = Rain.active()
		if a then
			Rain.give(player, data, a)
		end
		if Perks.credits(data, Rain.CREDIT) > 0 and not waitingSince[player] then
			waitingSince[player] = os.clock()
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		waitingSince[player] = nil
		nextIds[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(startNext :: any)
			if not ok then
				warn("[Maison] Megalodon Rain: " .. tostring(err))
			end
		end
	end)
end

return Rain

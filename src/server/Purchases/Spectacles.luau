--!strict
-- Suite spectacles: a show in a guest's own Suite (fireworks, a meme takeover, a golden
-- transformation). A receipt saves one show as a credit (that's what makes it safe); then, the
-- moment the purchase is settled, it plays: at once if they're in their Suite, else the moment they
-- step back into it. One saved from before plays from the Suite's bell. The server spends the
-- credit, then tells their screen to play the show (World/SuiteSpectacle draws it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
local MemeTakeovers = require(ReplicatedStorage.Shared.MemeTakeovers)
local ProductConfig = require(ReplicatedStorage.Shared.ProductConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Profiles = require(script.Parent.Parent.Profiles)
local RemoteGuard = require(script.Parent.Parent.RemoteGuard)
local Catalog = require(script.Parent.Catalog)
local Grants = require(script.Parent.Grants)
local Perks = require(script.Parent.Perks)
local Store = require(script.Parent.Store)

local Spectacles = {}

Spectacles.KEYS = { "spectacleFireworks", "spectacleMemes", "spectacleGolden" }
local IS_KEY: { [string]: boolean } = {}
for _, k in Spectacles.KEYS do
	IS_KEY[k] = true
end
local SECONDS = { spectacleFireworks = 45, spectacleMemes = 90, spectacleGolden = 40 }

-- When the show on each guest's screen ends: shows never overlap (a second Meme Takeover started
-- during one would be lost, and two Golden Transformations would tangle the gold), so the next
-- waits for this one.
local showingUntil: { [Player]: number } = {}

local function busy(player: Player): boolean
	return (showingUntil[player] or 0) > os.clock()
end

local function showing(player: Player, key: string)
	showingUntil[player] = os.clock() + (SECONDS[key] or 20) + 2
end

-- The Meme Takeover's edition this time: one this guest hasn't seen lately (the last few are kept
-- with their perks), so it's never the same show twice in a row. Chosen here, never by their screen.
local RECENT = math.min(6, #MemeTakeovers.List - 1)
local rng = Random.new()
function Spectacles.memeEdition(player: Player): string
	local data = Profiles.get(player)
	local perks: any = if data then data.perks else nil
	local recent: { string } = {}
	if type(perks) == "table" then
		if type(perks.shows) ~= "table" then
			perks.shows = { memes = {} }
		end
		if type(perks.shows.memes) ~= "table" then
			perks.shows.memes = {}
		end
		recent = perks.shows.memes
	end
	local id = MemeTakeovers.pick(recent, rng:NextNumber())
	table.insert(recent, id)
	while #recent > RECENT do
		table.remove(recent, 1)
	end
	return id
end

-- Tells the guest's own screen to play a show (the Meme Takeover with its edition).
local function tellShow(player: Player, key: string)
	Perks.tell(player, {
		op = "spectacle",
		key = key,
		seconds = SECONDS[key],
		variant = if key == "spectacleMemes" then Spectacles.memeEdition(player) else nil,
	})
end

-- The owner tries a show on their own screen, free (House controls; AdminService checks who asks).
function Spectacles.preview(player: Player, key: string): boolean
	if not IS_KEY[key] then
		return false
	end
	-- (Never refused, it's free; a show bought meanwhile waits for it.)
	showing(player, key)
	tellShow(player, key)
	return true
end

-- Each show's name, for House controls.
function Spectacles.names(): { { key: string, name: string } }
	local out = {}
	for _, key in Spectacles.KEYS do
		local e = ProductConfig.byKey[key]
		table.insert(out, { key = key, name = if e then e.UX.DisplayName else key })
	end
	return out
end

local function credit(key: string): string
	return "show:" .. key
end

local function inSuite(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and Layout.zoneAt(root.Position) == "suite"
end

function Spectacles.list(player: Player): { [string]: any }
	local data = Profiles.get(player)
	local out = {}
	for _, key in Spectacles.KEYS do
		local e = ProductConfig.byKey[key]
		table.insert(out, {
			key = key,
			name = e.UX.DisplayName,
			line = e.UX.Line,
			robux = Catalog.price(key) or e.Pricing.ReferencePrice,
			ready = Catalog.enabled(key),
			held = if data then Perks.credits(data, credit(key)) else 0,
		})
	end
	return { ok = true, shows = out }
end

local function onAsk(player: Player, request: unknown): any
	local r = RemoteGuard.message(request, 3, 0)
	if not r then
		RemoteGuard.reject(player, "spectacleAsk", "malformed")
		return { ok = false }
	end
	if r.op == "list" then
		return Spectacles.list(player)
	end
	local key = RemoteGuard.oneOf(r.key, IS_KEY)
	local data = Profiles.get(player)
	if not key or not data then
		return { ok = false, why = "That isn't a show." }
	end
	if r.op == "buy" then
		local ok, why = Store.prompt(player, key, "suite")
		return { ok = ok, why = why, prompted = ok }
	elseif r.op == "play" then
		if not inSuite(player) then
			return { ok = false, why = "Shows play in your Suite." }
		end
		if busy(player) then
			return { ok = false, why = "One show at a time: this one's still on." }
		end
		if not Perks.use(player, data, credit(key), key) then
			return { ok = false, why = "You've none of those to play." }
		end
		showing(player, key)
		tellShow(player, key)
		Perks.push(player)
		return { ok = true }
	end
	return { ok = false }
end

-- Shows just bought, waiting for their guest to be in their Suite (only for this visit: one not
-- played before they leave stays saved, for the bell).
local waiting: { [Player]: { string } } = {}

-- Spends one saved show and plays it. False if there's none to play.
local function playNow(player: Player, key: string): boolean
	local data = Profiles.get(player)
	if not data or not Perks.use(player, data, credit(key), key) then
		return false
	end
	showing(player, key)
	tellShow(player, key)
	Perks.push(player)
	return true
end
Spectacles.playNow = playNow

local function grant(ctx: Grants.Context)
	Perks.add(ctx.data, credit(ctx.key), 1)
	-- (After the purchase is settled: the credit is safely kept first, then spent on the show.)
	ctx:after(function()
		local player, key = ctx.player, ctx.key
		local here = inSuite(player)
		if here and not busy(player) and playNow(player, key) then
			return
		end
		Perks.push(player)
		local list = waiting[player] or {}
		table.insert(list, key)
		waiting[player] = list
		local line = if here then "It plays the moment the show on now ends." else "It plays the moment you step into your Suite."
		Perks.tell(player, { op = "notice", title = ctx.product.UX.DisplayName, line = line })
	end)
end

-- Plays a waiting show when its guest is in their Suite (and the one before it has ended).
function Spectacles.tick()
	for player in showingUntil do
		if player.Parent == nil then
			showingUntil[player] = nil
		end
	end
	for player, list in waiting do
		if player.Parent == nil then
			waiting[player] = nil
		elseif #list > 0 and inSuite(player) and not busy(player) then
			local key = table.remove(list, 1)
			if key then
				playNow(player, key)
			end
			if #list == 0 then
				waiting[player] = nil
			end
		end
	end
end

function Spectacles.start()
	Grants.register("spectacle", grant)
	RemoteGuard.invoke(Remotes.func("SpectacleAsk"), "spectacleAsk", onAsk)
	task.spawn(function()
		while true do
			task.wait(1)
			pcall(Spectacles.tick)
		end
	end)
end

return Spectacles

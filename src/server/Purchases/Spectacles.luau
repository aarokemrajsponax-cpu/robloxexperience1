--!strict
-- Suite spectacles: a show in a guest's own Suite (fireworks, a meme takeover, a golden
-- transformation). A receipt saves one show as a credit; the guest plays it from the Suite's bell
-- when they like, and only while they're in their Suite. The server spends the credit, then tells
-- their screen to play the show (World/SuiteSpectacle draws it).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Layout = require(ReplicatedStorage.Shared.Layout)
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
local SECONDS = { spectacleFireworks = 45, spectacleMemes = 20, spectacleGolden = 30 }

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
		if not Perks.use(player, data, credit(key), key) then
			return { ok = false, why = "You've none of those to play." }
		end
		Perks.tell(player, { op = "spectacle", key = key, seconds = SECONDS[key] })
		Perks.push(player)
		return { ok = true }
	end
	return { ok = false }
end

local function grant(ctx: Grants.Context)
	Perks.add(ctx.data, credit(ctx.key), 1)
	ctx:after(function()
		Perks.push(ctx.player)
		Perks.tell(ctx.player, { op = "notice", title = ctx.product.UX.DisplayName, line = "Yours to play in your Suite, from the bell, whenever you like." })
	end)
end

function Spectacles.start()
	Grants.register("spectacle", grant)
	RemoteGuard.invoke(Remotes.func("SpectacleAsk"), "spectacleAsk", onAsk)
end

return Spectacles

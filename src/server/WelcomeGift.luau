--!strict
-- (Build 93) The house's welcome gift: in a guest's first minute, the Concierge offers them their
-- first brainrot, their own choice of three. It goes straight into their squad, so its tip jar
-- starts filling with Gilt at once and it walks beside them through the house.
--   * Free, and the same three for everyone: chosen, never drawn at random, never sold.
--   * Once a guest, ever (flags.welcomeGift in their own record), and only while they hold no
--     brainrot at all: a guest who already has a squad is never offered it.
--   * The server decides everything: a screen only names which of the three it would like, and
--     anything else is refused.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotList = require(ReplicatedStorage.Shared.Brainrots)
local CurioList = require(ReplicatedStorage.Shared.Curios)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Analytics = require(script.Parent.Analytics)
local Brainrots = require(script.Parent.Brainrots)
local Curios = require(script.Parent.Curios)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local WelcomeGift = {}

-- The three to choose from: Commons, so the gift never outshines what's found by playing.
WelcomeGift.CHOICES = { "croissantino", "pigeonetto", "bananino" } :: { string }

-- Hooks (set by Main): the first-session funnel's step for the gift.
WelcomeGift.claimed = function(_player: Player, _id: string) end

local function flags(data: Profiles.Data): { [string]: boolean }
	local d = data :: any
	if type(d.flags) ~= "table" then
		d.flags = {}
	end
	return d.flags
end

local function holdsBrainrot(data: Profiles.Data): boolean
	for id, n in Curios.bag(data).items do
		if (tonumber(n) or 0) > 0 and BrainrotList.is(id) then
			return true
		end
	end
	return false
end

-- Whether this guest may still have the gift.
function WelcomeGift.eligible(data: Profiles.Data): boolean
	return flags(data).welcomeGift ~= true and not holdsBrainrot(data)
end

-- The three, as a screen shows them (names and rates from the shared lists, never from a screen).
function WelcomeGift.view(): { { [string]: any } }
	local out = {}
	for _, id in WelcomeGift.CHOICES do
		local c = CurioList.byId[id]
		if c then
			table.insert(out, {
				id = id,
				name = c.name,
				line = c.line,
				glyph = c.glyph,
				rarity = c.rarity,
				rate = BrainrotList.rate(id, 1, nil),
				ability = BrainrotList.abilityText(id),
			})
		end
	end
	return out
end

-- Offers the gift to a guest who may have it (the Concierge, as they first come into the Foyer).
-- True if it was offered.
function WelcomeGift.offer(player: Player): boolean
	local data = Profiles.get(player)
	if not data or not WelcomeGift.eligible(data) then
		return false
	end
	Remotes.event("Curio"):FireClient(player, { op = "welcomeGift", choices = WelcomeGift.view() })
	return true
end

-- Whether a guest has nothing left to choose (chosen, or never able to): the tour waits for this.
function WelcomeGift.settled(player: Player): boolean
	local data = Profiles.get(player)
	return data == nil or not WelcomeGift.eligible(data)
end

function WelcomeGift.claim(player: Player, id: unknown): { [string]: any }
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "One moment." }
	end
	if type(id) ~= "string" or not table.find(WelcomeGift.CHOICES, id) then
		RemoteGuard.reject(player, "welcomeGift", "choice")
		return { ok = false, why = "Choose one of the three." }
	end
	if not WelcomeGift.eligible(data) then
		return { ok = false, why = "The house's welcome gift is already yours." }
	end
	-- Marked first: one gift, however often a screen asks.
	flags(data).welcomeGift = true
	Brainrots.settle(data)
	Curios.give(player, data, id, 1, "welcome")
	Curios.push(player)
	Curios.announce(player, id, "A welcome gift from the house. It's in your squad, earning Gilt for you every hour.")
	Analytics.custom(player, "Welcome gift", 1, { curio = id })
	Analytics.step(player, 5)
	pcall(WelcomeGift.claimed, player, id)
	return { ok = true, id = id, rate = Brainrots.rate(data) }
end

local function onAsk(player: Player, request: any): { [string]: any }
	if type(request) ~= "table" then
		RemoteGuard.reject(player, "welcomeGift", "malformed")
		return { ok = false }
	end
	if request.op == "claim" then
		return WelcomeGift.claim(player, request.id)
	elseif request.op == "state" then
		local data = Profiles.get(player)
		return { ok = true, eligible = data ~= nil and WelcomeGift.eligible(data), choices = WelcomeGift.view() }
	end
	RemoteGuard.reject(player, "welcomeGift", "malformed")
	return { ok = false }
end

function WelcomeGift.start()
	RemoteGuard.invoke(Remotes.func("WelcomeGiftAsk"), "welcomeGift", onAsk)
end

return WelcomeGift

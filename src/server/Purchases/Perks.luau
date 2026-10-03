--!strict
-- Credits: what a receipt grants when its effect can't (or shouldn't) happen inside the receipt.
-- A revive, a decree, a rain, a salute or a Golden Hour is first saved as a credit in the buyer's
-- profile (durable, in the same write as the PurchaseId). Spending it is a separate, ordinary
-- action on the server afterwards: right away if it can be (auto-use), or when the guest chooses.
-- So a crash, a full queue or a closed revive window never loses what was paid for: the credit
-- is still there, and auto-use credits are spent the next time the guest arrives.
--
-- Also the guest's perk state for their screen (credits, Luck's time, Velocity), sent on the
-- "Purchase" remote whenever it changes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Profiles = require(script.Parent.Parent.Profiles)
local Telemetry = require(script.Parent.Telemetry)

local Perks = {}

-- Credits spent as soon as they arrive, by credit key: (player, data) -> spent one?
Perks.autoUse = {} :: { [string]: (player: Player, data: Profiles.Data) -> boolean }
-- Parts of the state for the guest's screen, by name: (player, data) -> any.
Perks.contributors = {} :: { [string]: (player: Player, data: Profiles.Data) -> any }

local purchaseEvent = Remotes.event("Purchase")

function Perks.credits(data: Profiles.Data, key: string): number
	return data.perks.credits[key] or 0
end

-- Adds credits (inside a grant).
function Perks.add(data: Profiles.Data, key: string, n: number?)
	data.perks.credits[key] = Perks.credits(data, key) + (n or 1)
end

-- Spends one credit. False if there's none. The profile is saved straight after, so a credit
-- spent on something the whole house sees (a rain, a salute) is very unlikely to come back after
-- a crash and be spent twice.
function Perks.use(player: Player, data: Profiles.Data, key: string, product: string?): boolean
	local have = Perks.credits(data, key)
	if have <= 0 then
		return false
	end
	if have > 1 then
		data.perks.credits[key] = have - 1
	else
		data.perks.credits[key] = nil
	end
	Telemetry.log(player, Telemetry.Events.Used, product or key, "credit", 1)
	local profile = Profiles.profile(player)
	if profile and not Profiles.isMock() then
		pcall(function()
			profile:Save()
		end)
	end
	return true
end

-- Tries to spend an auto-use credit now. True if one was spent.
function Perks.tryAuto(player: Player, key: string): boolean
	local data = Profiles.get(player)
	local fn = Perks.autoUse[key]
	if not data or not fn or Perks.credits(data, key) <= 0 then
		return false
	end
	local ok, used = pcall(fn, player, data)
	if not ok then
		warn("[Maison] Using a credit for " .. key .. ": " .. tostring(used))
		return false
	end
	if used then
		Perks.push(player)
	end
	return used == true
end

-- A guest arrived: spend any auto-use credits left from before (a crash, a full queue).
function Perks.resume(player: Player)
	for key in Perks.autoUse do
		while Perks.tryAuto(player, key) do
			-- one at a time, until there are none or one can't be spent now
		end
	end
end

-- The guest's perk state for their screen.
function Perks.state(player: Player, data: Profiles.Data): { [string]: any }
	local credits = {}
	for key, n in data.perks.credits do
		credits[key] = n
	end
	local out: { [string]: any } = { op = "perks", credits = credits }
	for name, fn in Perks.contributors do
		local ok, value = pcall(fn, player, data)
		if ok then
			out[name] = value
		end
	end
	return out
end

function Perks.push(player: Player)
	local data = Profiles.get(player)
	if data then
		purchaseEvent:FireClient(player, Perks.state(player, data))
	end
end

-- A message to one guest's screen (notices, results).
function Perks.tell(player: Player, message: { [string]: any })
	purchaseEvent:FireClient(player, message)
end

-- A message to every screen in the house (decrees, rains).
function Perks.tellAll(message: { [string]: any })
	purchaseEvent:FireAllClients(message)
end

return Perks

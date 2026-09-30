--!strict
-- What this guest owns and wears, their Gilt and their Ledger, as the server last said. The
-- table, the guide and the sounds read their style from here; the Boutique, the Wardrobe and the
-- Ledger read the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ledger = require(ReplicatedStorage.Shared.Ledger)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Wardrobe = require(ReplicatedStorage.Shared.Wardrobe)

local Closet = {}

Closet.owned = {} :: { [string]: boolean }
Closet.equipped = {} :: { [string]: string }
Closet.gilt = 0
Closet.goldKey = false
Closet.blackCard = { held = false, offered = false }
Closet.credits = {} :: { [string]: number }
Closet.ledger = { page = 0, pages = 50, progress = 0, leather = false, term = "" } :: { [string]: any }

local changed = Instance.new("BindableEvent")
Closet.Changed = changed.Event
local message = Instance.new("BindableEvent")
Closet.Message = message.Event -- (op, message): "open", "gift", "pages", "notice"

-- The item worn for a kind, or nil for the house default.
function Closet.wearing(kind: string): Wardrobe.Item?
	local id = Closet.equipped[kind]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local medal = string.match(id, "^soiree:([%d%-]+):medal$")
	if medal then
		return Wardrobe.soireeMedal(medal)
	end
	return Wardrobe.get(id) or Ledger.item(id)
end

function Closet.style(kind: string): { [string]: any }?
	local item = Closet.wearing(kind)
	return if item then item.style else nil
end

function Closet.ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("ShopAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

function Closet.start()
	Remotes.event("Shop").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "state" then
			local owned = {}
			if type(m.owned) == "table" then
				for _, id in m.owned do
					owned[id] = true
				end
			end
			Closet.owned = owned
			Closet.equipped = if type(m.equipped) == "table" then m.equipped else {}
			Closet.gilt = if type(m.gilt) == "number" then m.gilt else 0
			Closet.goldKey = m.goldKey == true
			if type(m.blackCard) == "table" then
				Closet.blackCard = { held = m.blackCard.held == true, offered = m.blackCard.offered == true }
			end
			Closet.credits = if type(m.credits) == "table" then m.credits else {}
			if type(m.ledger) == "table" then
				Closet.ledger = m.ledger
			end
			changed:Fire()
		else
			message:Fire(m.op, m)
		end
	end)
end

return Closet

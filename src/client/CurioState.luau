--!strict
-- The curios this guest holds, their stars and latest finds, and their Gems, as the server last
-- said (the "Curio" remote). Also passes on what else comes on that remote: a find to reveal,
-- Gems arriving, and a trade's invitations and state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CurioState = {}

CurioState.items = {} :: { [string]: number }
CurioState.favs = {} :: { [string]: boolean }
CurioState.recent = {} :: { string }
CurioState.gems = 0
CurioState.found = 0

local changed = Instance.new("BindableEvent")
CurioState.Changed = changed.Event
-- (op, message) for everything else: "found", "gems", "trade", "tradeInvite", "tradeEnd".
local message = Instance.new("BindableEvent")
CurioState.Message = message.Event

function CurioState.count(id: string): number
	return CurioState.items[id] or 0
end

function CurioState.ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("CurioAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

function CurioState.trade(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("TradeAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

local function apply(m: { [string]: any })
	CurioState.items = if type(m.items) == "table" then m.items else {}
	CurioState.favs = if type(m.favs) == "table" then m.favs else {}
	CurioState.recent = if type(m.recent) == "table" then m.recent else {}
	CurioState.gems = if type(m.gems) == "number" then m.gems else 0
	CurioState.found = if type(m.found) == "number" then m.found else 0
	changed:Fire()
end
CurioState.apply = apply

function CurioState.start()
	Remotes.event("Curio").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "curios" then
			apply(m)
		else
			if m.op == "gems" and type(m.gems) == "number" then
				CurioState.gems = m.gems
				changed:Fire()
			end
			message:Fire(m.op, m)
		end
	end)
end

return CurioState

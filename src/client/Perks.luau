--!strict
-- This guest's perks as the server last said (credits held, God-Mode Luck's time left, VIP
-- Velocity Elite), and the purchase system's messages: notices, decrees, rains. The screen only
-- ever shows what the server sent and asks the server for things by name; it never decides a
-- price, an amount or whether something is owned.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Perks = {}

Perks.state = {} :: { [string]: any }
-- os.clock() when the state arrived (Luck's time counts down from there).
Perks.at = 0

local changed = Instance.new("BindableEvent")
Perks.Changed = changed.Event
local message = Instance.new("BindableEvent")
Perks.Message = message.Event -- (op, message): "notice", "decree", "rain", "rainShare"

-- Credits held for a credit key ("revive", "decree", "rain", ...).
function Perks.held(key: string): number
	local credits = Perks.state.credits
	local n = if type(credits) == "table" then credits[key] else nil
	return if type(n) == "number" then n else 0
end

-- Seconds of God-Mode Luck left, counting down since the server's word.
function Perks.luckLeft(): number
	local luck = Perks.state.luck
	if type(luck) ~= "table" or type(luck.remaining) ~= "number" then
		return 0
	end
	return math.max(0, luck.remaining - (os.clock() - Perks.at))
end

function Perks.ask(request: { [string]: any }): any
	local ok, result = pcall(function()
		return Remotes.func("PerkAsk"):InvokeServer(request)
	end)
	return if ok then result else nil
end

function Perks.start()
	Remotes.event("Purchase").OnClientEvent:Connect(function(m: any)
		if type(m) ~= "table" then
			return
		end
		if m.op == "perks" then
			Perks.state = m
			Perks.at = os.clock()
			changed:Fire()
		elseif type(m.op) == "string" then
			message:Fire(m.op, m)
		end
	end)
	task.spawn(function()
		local s = Perks.ask({ op = "state" })
		if type(s) == "table" and s.op == "perks" then
			Perks.state = s
			Perks.at = os.clock()
			changed:Fire()
		end
	end)
end

return Perks

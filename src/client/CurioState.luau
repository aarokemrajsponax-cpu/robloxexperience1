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
-- The brainrot squad as the server last said (server/Brainrots.state), and when (os.clock()), so
-- the jar can tick up on screen at the rate it said until the next word.
CurioState.squad = nil :: { [string]: any }?
CurioState.squadAt = 0

local changed = Instance.new("BindableEvent")
CurioState.Changed = changed.Event
-- (op, message) for everything else: "found", "gems", "trade", "tradeInvite", "tradeEnd".
local message = Instance.new("BindableEvent")
CurioState.Message = message.Event

function CurioState.count(id: string): number
	return CurioState.items[id] or 0
end

-- The jar now: its Gilt (ticking up at the squad's rate since the server last said), its size,
-- and the rate an hour.
function CurioState.jar(): (number, number, number)
	local s = CurioState.squad
	if not s then
		return 0, 0, 0
	end
	local held = if type(s.held) == "number" then s.held else 0
	local rate = if type(s.rate) == "number" then s.rate else 0
	local cap = math.max(held, if type(s.cap) == "number" then s.cap else 0)
	local since = math.max(0, os.clock() - CurioState.squadAt)
	-- (A Meme Frenzy: the squad earns `frenzyMult` times as much for its first `frenzy` seconds.)
	local boosted = if type(s.frenzy) == "number" then math.min(since, s.frenzy) else 0
	local mult = if type(s.frenzyMult) == "number" then s.frenzyMult else 1
	return math.min(cap, held + rate * (boosted * mult + (since - boosted)) / 3600), cap, rate
end

-- Seconds of Meme Frenzy left now (0 if none), and how many times as much.
function CurioState.frenzy(): (number, number)
	local s = CurioState.squad
	if not s or type(s.frenzy) ~= "number" then
		return 0, 1
	end
	return math.max(0, s.frenzy - (os.clock() - CurioState.squadAt)), if type(s.frenzyMult) == "number" then s.frenzyMult else 1
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
	if type(m.squad) == "table" then
		CurioState.squad = m.squad
		CurioState.squadAt = os.clock()
	end
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

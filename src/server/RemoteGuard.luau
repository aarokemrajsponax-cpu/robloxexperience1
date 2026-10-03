--!strict
-- The trust boundary. Everything a guest's screen sends is untrusted: this rate-limits every
-- client-to-server remote (a token bucket per guest per remote, Config.RemoteLimits) and checks
-- arguments before any game code sees them. It never decides *what* a guest may do (each service
-- does that from server state); it only keeps malformed or flooding traffic out.
--
-- Remote names are not a secret and are not a defence: every remote here is assumed to be found
-- and called by exploit tools with any arguments at any rate. (The first argument, the Player,
-- is the one thing Roblox itself supplies: a client can't choose it.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RemoteGuard = {}

type Bucket = { tokens: number, at: number }
type Limit = { rate: number, burst: number }

local buckets: { [Player]: { [string]: Bucket } } = {}
local warned: { [Player]: { [string]: number } } = {}

-- Called when traffic is refused (set by the purchase system: it logs to analytics).
RemoteGuard.onRejected = function(_player: Player, _remote: string, _why: string) end

local function limitFor(name: string): Limit
	local limits = (Config.data :: any).RemoteLimits or {}
	local l = limits[name] or limits.default or { rate = 4, burst = 8 }
	return { rate = math.max(0.01, tonumber(l.rate) or 4), burst = math.max(1, tonumber(l.burst) or 8) }
end

-- Takes one token from the guest's bucket for `name`. False (and a note) when it's empty.
function RemoteGuard.allow(player: Player, name: string): boolean
	local per = buckets[player]
	if not per then
		per = {}
		buckets[player] = per
	end
	local limit = limitFor(name)
	local now = os.clock()
	local b = per[name]
	if not b then
		b = { tokens = limit.burst, at = now }
		per[name] = b
	end
	b.tokens = math.min(limit.burst, b.tokens + (now - b.at) * limit.rate)
	b.at = now
	if b.tokens < 1 then
		RemoteGuard.reject(player, name, "rate")
		return false
	end
	b.tokens -= 1
	return true
end

-- Records refused traffic, at most once a minute per guest per remote.
function RemoteGuard.reject(player: Player, name: string, why: string)
	local per = warned[player]
	if not per then
		per = {}
		warned[player] = per
	end
	local key = name .. ":" .. why
	local now = os.clock()
	if (per[key] or -math.huge) + 60 > now then
		return
	end
	per[key] = now
	pcall(RemoteGuard.onRejected, player, name, why)
end

---------------------------------------------------------------------------------------------------
-- Argument checks: each returns the value when it's acceptable, nil when it isn't.
---------------------------------------------------------------------------------------------------

-- A finite number within [min, max] (and whole, if asked).
function RemoteGuard.number(v: unknown, min: number, max: number, whole: boolean?): number?
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return nil
	end
	local n = v :: number
	if n < min or n > max or (whole and n ~= math.floor(n)) then
		return nil
	end
	return n
end

-- A string of at most `maxLength` bytes, valid UTF-8, without control characters.
function RemoteGuard.string(v: unknown, maxLength: number): string?
	if type(v) ~= "string" then
		return nil
	end
	local s = v :: string
	if #s > maxLength or utf8.len(s) == nil or string.find(s, "[%c]") then
		return nil
	end
	return s
end

-- One of a fixed set of words.
function RemoteGuard.oneOf(v: unknown, set: { [string]: boolean }): string?
	if type(v) == "string" and set[v :: string] then
		return v :: string
	end
	return nil
end

-- A plain table with at most `maxKeys` string keys and no nested tables deeper than `depth`.
function RemoteGuard.message(v: unknown, maxKeys: number, depth: number?): { [string]: unknown }?
	if type(v) ~= "table" then
		return nil
	end
	local count = 0
	local function ok(t: any, level: number): boolean
		for k, value in t do
			count += 1
			if count > maxKeys * 4 or (type(k) ~= "string" and type(k) ~= "number") then
				return false
			end
			if type(value) == "table" then
				if level >= (depth or 1) or not ok(value, level + 1) then
					return false
				end
			elseif type(value) ~= "string" and type(value) ~= "number" and type(value) ~= "boolean" then
				return false
			end
		end
		return true
	end
	local top = 0
	for _ in v :: any do
		top += 1
	end
	if top > maxKeys or not ok(v, 0) then
		return nil
	end
	return v :: { [string]: unknown }
end

---------------------------------------------------------------------------------------------------
-- Wrappers
---------------------------------------------------------------------------------------------------

-- Connects a RemoteEvent's OnServerEvent through the guard: rate-limited, and a handler error
-- never reaches the guest (it's reported on the server instead).
function RemoteGuard.event(remote: any, name: string, handler: (player: Player, ...any) -> ())
	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not RemoteGuard.allow(player, name) then
			return
		end
		local ok, err = pcall(handler :: any, player, ...)
		if not ok then
			warn(string.format("[Maison] %s from %s failed: %s", name, player.Name, tostring(err)))
		end
	end)
end

-- Sets a RemoteFunction's OnServerInvoke through the guard. A refused or failed call returns
-- `fallback(player)` if given (what that remote's screen expects), else { ok = false, why = ... },
-- instead of erroring on the guest's screen.
function RemoteGuard.invoke(remote: any, name: string, handler: (player: Player, ...any) -> any, fallback: ((player: Player) -> any)?)
	remote.OnServerInvoke = function(player: Player, ...: any): any
		if not RemoteGuard.allow(player, name) then
			return if fallback then fallback(player) else { ok = false, why = "One moment." }
		end
		local results = table.pack(pcall(handler, player, ...))
		if not results[1] then
			warn(string.format("[Maison] %s from %s failed: %s", name, player.Name, tostring(results[2])))
			return if fallback then fallback(player) else { ok = false, why = "The house couldn't do that just now." }
		end
		return table.unpack(results, 2, results.n)
	end
end

function RemoteGuard.start()
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
		warned[player] = nil
	end)
end

return RemoteGuard

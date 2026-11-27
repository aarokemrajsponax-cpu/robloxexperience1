--!strict
-- (Build 107) The house's codes (Config.Codes): typed in at the Codes key under the dock. A code
-- pays once per guest, only while it's open, and only what the server's own table says; what a
-- screen sends is only the text that was typed. Tries are limited, so nobody can guess at speed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Gilt = require(script.Parent.Gilt)
local Profiles = require(script.Parent.Profiles)
local RemoteGuard = require(script.Parent.RemoteGuard)

local Codes = {}

Codes.TRIES = 8 -- tries a guest may make each minute
Codes.now = function(): number
	return os.time()
end

local tries: { [Player]: { at: number, n: number } } = {}

local function table_(): { [string]: any }
	local t = (Config.data :: any).Codes
	return if type(t) == "table" then t else {}
end

-- Seconds since the epoch of a UTC {year, month, day, hour} (the civil calendar, no time zones).
local function utc(t: { number }): number
	local y, m, d = t[1], t[2], t[3]
	if m <= 2 then
		y -= 1
	end
	local era = (if y >= 0 then y else y - 399) // 400
	local yoe = y - era * 400
	local mp = (m + 9) % 12
	local doy = (153 * mp + 2) // 5 + d - 1
	local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
	local days = era * 146097 + doe - 719468
	return days * 86400 + (t[4] or 0) * 3600
end
Codes.utc = utc

-- What a guest typed, made plain: capitals, letters and digits only (nil if it can't be a code).
function Codes.clean(raw: unknown): string?
	if type(raw) ~= "string" or #raw > 40 then
		return nil
	end
	local stripped = (raw :: string):gsub("[%s%-_]", "")
	local s = string.upper(stripped)
	if #s < 3 or #s > 24 or s:find("[^%w]") then
		return nil
	end
	return s
end

-- Whether a code is open at `now`.
function Codes.open(def: { [string]: any }, now: number): boolean
	local from = if type(def.from) == "table" then utc(def.from) else -math.huge
	local to = if type(def.to) == "table" then utc(def.to) else math.huge
	return now >= from and now < to
end

function Codes.redeem(player: Player, raw: unknown): { [string]: any }
	local t = Codes.now()
	local was = tries[player]
	local mine: { at: number, n: number } = if was and t - was.at < 60 then was else { at = t, n = 0 }
	tries[player] = mine
	mine.n += 1
	if mine.n > Codes.TRIES then
		return { ok = false, why = "Too many tries: wait a minute." }
	end
	local code = Codes.clean(raw)
	if not code then
		return { ok = false, why = "That isn't a code." }
	end
	local def = table_()[code]
	if type(def) ~= "table" then
		return { ok = false, why = "That code isn't one of ours." }
	end
	if not Codes.open(def, t) then
		return { ok = false, why = "That code isn't open just now." }
	end
	local data = Profiles.get(player)
	if not data then
		return { ok = false, why = "Your ledger is still being opened." }
	end
	data.codes = if type(data.codes) == "table" then data.codes else {}
	if data.codes[code] then
		return { ok = false, why = "You've already used that code." }
	end
	local gilt = math.max(0, math.floor(tonumber(def.gilt) or 0))
	data.codes[code] = t
	local paid = Gilt.give(player, data, gilt, "code_" .. string.lower(code))
	return { ok = true, code = code, gilt = paid, title = tostring(def.title or code) }
end

function Codes.start()
	RemoteGuard.invoke(Remotes.func("CodeAsk"), "codeAsk", function(player: Player, request: unknown): any
		local code: unknown = if type(request) == "table" then (request :: { [string]: unknown }).code else nil
		return Codes.redeem(player, code)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(p: Player)
		tries[p] = nil
	end)
end

return Codes

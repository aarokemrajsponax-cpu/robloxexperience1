-- (Build 107) The house's codes (server/Codes, Config.Codes): checked on the server, once each per
-- guest, only while open, paying exactly what the table says.
local H = require("./harness")
local check, run = H.check, H.run
local module, profiles, guest = H.module, H.profiles, H.guest
local Config = H.Config
local Codes = module("ServerScriptService", "Server", "Codes")

local def = Config.data.Codes.RICHMAS
check("the Christmas code is in the house's table: RICHMAS, 50,000 Gilt", def ~= nil and def.gilt == 50000)
local opens, closes = Codes.utc(def.from), Codes.utc(def.to)
check("open from 27 November (00:00 UTC) to the end of Christmas Day in New York (26 December, 05:00 UTC)", opens == os.time({ year = 2026, month = 11, day = 27, hour = 0, min = 0, sec = 0 }) - (os.time({ year = 1970, month = 1, day = 1, hour = 0 }) or 0) and closes - opens == (29 * 24 + 5) * 3600, opens)

local ada = guest("Ada", 9101)
local data = profiles[ada].Data
local now = opens + 3600
Codes.now = function()
	return now
end
local r
run(function()
	r = Codes.redeem(ada, "NOTACODE")
end)
check("a code the house doesn't have pays nothing", r.ok == false and string.find(r.why, "isn't one of ours") ~= nil)
run(function()
	r = Codes.redeem(ada, "<script>")
end)
check("...nor anything that isn't a code at all", r.ok == false)
local before = data.gilt
now = opens - 60
run(function()
	r = Codes.redeem(ada, "RICHMAS")
end)
check("before it opens: refused, nothing paid", r.ok == false and data.gilt == before and string.find(r.why, "isn't open") ~= nil)
now = opens + 3600
run(function()
	r = Codes.redeem(ada, " rich-mas ")
end)
check("open: typed any old way (small letters, spaces, a dash), it pays exactly 50,000 Gilt", r.ok == true and r.gilt == 50000 and data.gilt == before + 50000, r.why)
check("...and is marked used on the guest's ledger", type(data.codes) == "table" and data.codes.RICHMAS == now)
run(function()
	r = Codes.redeem(ada, "RICHMAS")
end)
check("once only: a second try pays nothing", r.ok == false and data.gilt == before + 50000 and string.find(r.why, "already") ~= nil)
local bo = guest("Bo", 9102)
now = closes + 1
run(function()
	r = Codes.redeem(bo, "RICHMAS")
end)
check("after Christmas Day: closed, nothing paid", r.ok == false and string.find(r.why, "isn't open") ~= nil)
local cy = guest("Cy", 9103)
now = opens + 7200
local refused = false
for _ = 1, Codes.TRIES + 2 do
	run(function()
		r = Codes.redeem(cy, "GUESS")
	end)
end
refused = string.find(r.why or "", "Too many") ~= nil
run(function()
	r = Codes.redeem(cy, "RICHMAS")
end)
check("guessing at speed is stopped: after a few tries a minute, even the right code waits", refused and r.ok == false)
now += 61
run(function()
	r = Codes.redeem(cy, "RICHMAS")
end)
check("...a minute later it works", r.ok == true and r.gilt == 50000)

H.finish()

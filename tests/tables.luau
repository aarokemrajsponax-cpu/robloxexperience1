--!nocheck
-- The four rooms' tables (TableService) under Lune on a fake clock, against the freeze AJKR met in
-- the Salon after round XIX: a filing that landed in the same instant as the message before it
-- was thrown away by the server, so the round never ended while the screen said 0 pieces left.
--
--   A. Every room, sixty rounds running, with each piece's lift and filing landing together
--   B. Filings that land together are taken in turn, the minimum gap apart (none bounced back);
--      a flood beyond a few is still refused, and every refusal is answered
--   C. Where the table stands (sync): in play, between rounds, a "next" that never landed
--   D. A filing the table can't take (a shut case, the clock run out) is always answered
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/tables.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Config = H.Config

H.stubs["ServerScriptService.Server.Boards"] = function()
	return {
		submit = function() end,
		submitNightly = function()
			return {}
		end,
		nightlyConnections = function()
			return {}
		end,
		saveNightlyLog = function() end,
	}
end
local TableService = H.module("ServerScriptService", "Server", "TableService")
TableService.start()
local tableEvent = H.Remotes.event("Table")

local function since(guest, op, after)
	local out = {}
	for i = after + 1, #guest.inbox do
		if guest.inbox[i].op == op then
			table.insert(out, guest.inbox[i])
		end
	end
	return out
end
local function newest(guest, op, after)
	local list = since(guest, op, after)
	return list[#list]
end

local nextId = 700
local function seat(roomId, mode, triedTonight)
	nextId += 1
	local model = H.Instance.new("Model")
	model.Name = "Table-" .. roomId .. nextId
	model:SetAttribute("Room", roomId)
	model:SetAttribute("TableId", "T-" .. roomId .. nextId)
	local chair = H.Instance.new("Seat")
	chair.Name = "Chair"
	chair.Parent = model
	local g = H.newGuest("G" .. nextId, nextId)
	table.insert(H.guests, g)
	H.newProfile(g, H.TEMPLATE)
	local data = H.profiles[g].Data
	data.best, data.bestRound, data.nightly = {}, {}, { day = -1 }
	data.flags.midnight = true
	if triedTonight then
		data.nightly.day = H.module("ReplicatedStorage", "Shared", "Nightly").at().day
	end
	H.loadedSignal:Fire(g, data)
	local ok
	run(function()
		ok = TableService.seat(g, model, true, mode or "room")
	end)
	advance(1)
	return g, ok, H.lastOp(g, "deal")
end
local function say(g, m)
	tableEvent.OnServerEvent:Fire(g, m)
end
local function leave(g)
	say(g, { op = "leave" })
	advance(1)
end

---------------------------------------------------------------------------------------------------
-- A. Sixty rounds in every room, each lift and filing landing together
---------------------------------------------------------------------------------------------------
for _, roomId in { "salon", "velvet", "obsidian", "midnight" } do
	local g, seated, deal = seat(roomId)
	local cleared, stuck = 0, nil
	for r = 1, 60 do
		if not deal or deal.round ~= r then
			stuck = "no deal for round " .. r
			break
		end
		local mark = #g.inbox
		for _, p in deal.pieces do
			advance(0.25)
			say(g, { op = "lift", uid = p.uid })
			say(g, { op = "file", uid = p.uid, case = p.case })
		end
		advance(0.5)
		if not newest(g, "roundEnd", mark) then
			stuck = string.format("round %d never ended (%d of %d filings answered)", r, #since(g, "filed", mark), #deal.pieces)
			break
		end
		cleared = r
		mark = #g.inbox
		advance(1)
		say(g, { op = "next" })
		advance(0.5)
		deal = newest(g, "deal", mark)
	end
	check(roomId .. ": sixty rounds running, every lift and filing landing together, never stuck", seated and cleared == 60, stuck or cleared)
	leave(g)
end

---------------------------------------------------------------------------------------------------
-- B. Filings that land together
---------------------------------------------------------------------------------------------------
do
	local g, _, deal = seat("midnight") -- (fourteen pieces in its first round)
	local gap = Config.data.FairPlay.minGap
	-- Three sorted quickly, landing in the same instant (a burst after a lag spike).
	local mark = #g.inbox
	for i = 1, 3 do
		local p = deal.pieces[i]
		say(g, { op = "file", uid = p.uid, case = p.case })
	end
	check("three filings at once: the first is taken at once", #since(g, "filed", mark) == 1 and #since(g, "rejected", mark) == 0)
	advance(gap + 0.01)
	check("...the second the minimum gap later", #since(g, "filed", mark) == 2)
	advance(gap + 0.01)
	local filed = since(g, "filed", mark)
	local allRight = #filed == 3
	for _, f in filed do
		allRight = allRight and f.correct == true
	end
	check("...and the third: all three in their cases, none bounced back", allRight and #since(g, "rejected", mark) == 0)
	-- A flood: far more at once than a person can sort.
	advance(1)
	mark = #g.inbox
	local left = {}
	for i = 4, #deal.pieces do
		table.insert(left, deal.pieces[i])
	end
	for _, p in left do
		say(g, { op = "file", uid = p.uid, case = p.case })
	end
	local refused = #since(g, "rejected", mark)
	advance(gap * 10)
	local taken = #since(g, "filed", mark)
	check("a flood: a few wait their turn, the rest are refused, and every one is answered", #left > 7 and taken == 7 and refused == #left - 7 and taken + refused == #left, string.format("%d taken, %d refused of %d", taken, refused, #left))
	-- The refused ones sorted again, in a person's time: the round ends.
	mark = #g.inbox
	for _, p in left do
		advance(0.2)
		say(g, { op = "file", uid = p.uid, case = p.case })
	end
	advance(0.5)
	check("...sorted again in a person's time, the round ends", newest(g, "roundEnd", mark) ~= nil)
	leave(g)
end

---------------------------------------------------------------------------------------------------
-- C. Where the table stands
---------------------------------------------------------------------------------------------------
do
	local g, _, deal = seat("velvet")
	local p1, p2 = deal.pieces[1], deal.pieces[2]
	advance(0.2)
	say(g, { op = "file", uid = p1.uid, case = p1.case })
	advance(0.2)
	local mark = #g.inbox
	say(g, { op = "sync" })
	local s = newest(g, "sync", mark)
	local listed = {}
	for _, p in (s and s.pieces or {}) do
		listed[p.uid] = true
	end
	check("in play: the round, the pieces still to sort (not the one filed), the score and the clock", s ~= nil and s.state == "playing" and s.round == 1 and s.remaining == #deal.pieces - 1 and #s.pieces == #deal.pieces - 1 and listed[p1.uid] == nil and listed[p2.uid] == true and s.score > 0 and s.clock ~= nil)
	-- The round sorted; the card said; "next" never lands; the screen asks.
	for i = 2, #deal.pieces do
		local p = deal.pieces[i]
		advance(0.2)
		say(g, { op = "file", uid = p.uid, case = p.case })
	end
	advance(0.5)
	local card = H.lastOp(g, "roundEnd")
	mark = #g.inbox
	say(g, { op = "sync" })
	s = newest(g, "sync", mark)
	check("between rounds: the state, and the round's card again", s ~= nil and s.state == "roundEnd" and type(s.roundEnd) == "table" and s.roundEnd.round == 1 and s.roundEnd.grade == card.grade)
	mark = #g.inbox
	say(g, { op = "next" })
	advance(0.3)
	say(g, { op = "next" }) -- sent again (the screen didn't hear the deal in time): harmless
	advance(0.3)
	check("a second next for the same card deals once", #since(g, "deal", mark) == 1 and newest(g, "deal", mark).round == 2)
	mark = #g.inbox
	say(g, { op = "sync" })
	s = newest(g, "sync", mark)
	check("...and after it the server says round II is in play (the card forgotten)", s ~= nil and s.state == "playing" and s.round == 2 and s.roundEnd == nil)
	leave(g)
end

---------------------------------------------------------------------------------------------------
-- D. A filing the table can't take is always answered
---------------------------------------------------------------------------------------------------
do
	local g, _, deal = seat("salon")
	local shut
	for _, c in { "watches", "jewelry", "money", "keys", "accessories", "collectibles" } do
		if not table.find(deal.cases, c) then
			shut = c
		end
	end
	local p = deal.pieces[1]
	local mark = #g.inbox
	advance(0.2)
	say(g, { op = "file", uid = p.uid, case = shut })
	check("a filing into a shut case is answered (the piece goes back)", shut ~= nil and newest(g, "rejected", mark) ~= nil and newest(g, "rejected", mark).uid == p.uid)
	leave(g)
	-- The clock runs out a moment before a filing lands (Obsidian).
	local g2, _, deal2 = seat("obsidian")
	advance(deal2.clock.budget + 1)
	check("the clock ran out: the run stops (banked, as no revive is on sale here)", H.lastOp(g2, "reviveOffer") ~= nil or H.lastOp(g2, "banked") ~= nil)
	mark = #g2.inbox
	local q = deal2.pieces[1]
	say(g2, { op = "file", uid = q.uid, case = q.case })
	check("a filing that lands after the clock ran out is answered too", newest(g2, "rejected", mark) ~= nil and newest(g2, "rejected", mark).uid == q.uid)
	leave(g2)
end

do
	-- Tonight's table: one try a night, then the table carries on as its own room. Never a
	-- rehearsal (Build 68: they only confused people).
	local g, ok, deal = seat("obsidian", "nightly")
	check("tonight's table: the first try is the Nightly", ok and deal ~= nil and deal.mode == "nightly", deal and deal.mode)
	-- (Its clock starts with the first piece lifted.)
	say(g, { op = "lift", uid = deal and deal.pieces[1].uid })
	advance((deal and deal.clock and deal.clock.budget or 60) + 1)
	if H.lastOp(g, "reviveOffer") then
		say(g, { op = "noRevive" })
		advance(1)
	end
	local mark = #g.inbox
	say(g, { op = "again" })
	advance(1)
	local again = newest(g, "deal", mark)
	check("Keep playing after the try: the room's own table, not a rehearsal", again ~= nil and again.mode == "room" and again.room == "obsidian", again and again.mode)
	leave(g)
	local g3, ok3, deal3 = seat("velvet", "nightly", true)
	check("asking for tonight's table after the try: the room's own table, said plainly", ok3 and deal3 ~= nil and deal3.mode == "room" and deal3.room == "velvet", deal3 and deal3.mode)
	leave(g3)
end

H.finish()

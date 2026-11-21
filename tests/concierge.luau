--!nocheck
-- The Concierge, upgraded (server/Staff/Concierge, the tour's words and stops), under Lune in the
-- house's test harness: the brief's twelve checks. The welcome on a first visit; a tour that shows
-- every destination and teaches how the house's money works; finding any place (walked, with gold
-- arrows, by default; taken there only when asked); answers with the house's real numbers; what to
-- do next from what a guest has done; the tour replayable; the news shown once to guests from
-- before; his words about the attractions.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/concierge.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3 = H.Vector3
local module, profiles = H.module, H.profiles
local Remotes, Config = H.Remotes, H.Config

H.stubs["ServerScriptService.Server.Staff.Rig"] = function()
	return {
		build = function()
			error("no rigs under Lune")
		end,
		look = function()
			return {}
		end,
	}
end

local Voice = module("ReplicatedStorage", "Shared", "Voice")
local Layout = module("ReplicatedStorage", "Shared", "Layout")
local AttractionList = module("ReplicatedStorage", "Shared", "Attractions")
local Dialogue = module("ServerScriptService", "Server", "Dialogue")
local Concierge = module("ServerScriptService", "Server", "Staff", "Concierge")
local Travel = module("ServerScriptService", "Server", "Travel")
local C = Config.data.Attractions

run(Dialogue.start)
-- (The hooks Main sets.)
local taken = {}
Concierge.dataOf = function(p)
	return profiles[p] and profiles[p].Data
end
Concierge.placeAt = function(id)
	local p = Travel.places()[id]
	if p then
		return p.name, p.at.Position
	end
	return nil, nil
end
Concierge.travel = function(p, id)
	table.insert(taken, { p = p, id = id })
	return true
end
Concierge.newsSeen = function(p)
	return profiles[p].Data.flags.news72 == true
end
Concierge.markNews = function(p)
	profiles[p].Data.flags.news72 = true
end
Concierge.settings = function()
	return Config.data
end

local function lastLine(g)
	for i = #g.inbox, 1, -1 do
		if g.inbox[i].speaker == Voice.Concierge.speaker then
			return g.inbox[i]
		end
	end
	return nil
end
local function choose(g, id)
	local said = lastLine(g)
	run(function()
		Remotes.event("DialogueChoice").OnServerEvent:Fire(g, said.token, id)
	end)
	advance(0.2)
end
local function choiceIds(said)
	local out = {}
	for _, c in said.choices or {} do
		out[c.id] = c.text
	end
	return out
end
local function lastWay(g)
	for i = #g.inbox, 1, -1 do
		if g.inbox[i].op == "way" then
			return g.inbox[i]
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- 1. A first visit: welcomed at once, and offered the tour
---------------------------------------------------------------------------------------------------
local ada = H.guest("Ada", 801)
profiles[ada].Data.flags = profiles[ada].Data.flags or {}
run(function()
	Concierge.greet(ada, true)
end)
local said = lastLine(ada)
check("1. a first visit: welcomed at once, with the house's aim, and offered the tour", said ~= nil and string.find(said.line, "richest guest", 1, true) ~= nil and choiceIds(said).tour ~= nil)
check("...a new guest's tour covers what's new (they won't be offered it again)", profiles[ada].Data.flags.news72 == true)

---------------------------------------------------------------------------------------------------
-- 2-3. The tour: every destination, and the loop
---------------------------------------------------------------------------------------------------
do
	local stops, points = {}, Layout.Tour.points
	for _, s in Layout.Tour.stops do
		stops[s.id] = true
	end
	local titles = {}
	local ok = true
	for _, card in Voice.Tour do
		titles[card.title] = true
		if not stops[card.stop] or (card.place and not points[card.place]) then
			ok = false
		end
	end
	check("2. every tour card stands at a real stop and points at a real place", ok)
	local every = true
	for _, want in { "Steal a Luxe", "The Maison Basement", "The Executive Suite", "The Salon", "The Vault", "The Boutique", "The Grand Ballroom", "The Terrace", "Your Suite" } do
		if not titles[want] then
			every = false
			print("   (missing from the tour: " .. want .. ")")
		end
	end
	check("...and it shows every destination, the three attractions among them", every)
	check("3. it teaches how the house works: the Fortune first, and the loop at the end", string.find(Voice.Tour[1].line, "Fortune", 1, true) ~= nil and string.find(Voice.Tour[#Voice.Tour].line, "Estate", 1, true) ~= nil)
	check("...each pin has its name", Voice.TourPlaces.velvetDoor == "The Luxe Lounge" and Voice.TourPlaces.obsidianDoor == "The Basement Stair" and Voice.TourPlaces.midnightDoor == "The Executive's Anteroom")
end

---------------------------------------------------------------------------------------------------
-- 4-6. Finding a place: every place real; walking by default; taken only when asked
---------------------------------------------------------------------------------------------------
do
	local all = true
	for _, p in Concierge.PLACES do
		local name, at = Concierge.placeAt(p.id)
		if not name or typeof(at) ~= "Vector3" then
			all = false
			print("   (no place for " .. p.id .. ")")
		end
	end
	check("4. every place the Concierge offers is a real place in the house", all and #Concierge.PLACES >= 10)
	check("...the attractions' rooms by their new names", select(1, Concierge.placeAt("velvet")) == "The Luxe Lounge" and select(1, Concierge.placeAt("obsidian")) == "The Basement Stair" and select(1, Concierge.placeAt("midnight")) == "The Executive's Anteroom")
end
run(function()
	Concierge.menu(ada)
end)
said = lastLine(ada)
local ids = choiceIds(said)
check("the menu: what next, find a place, a question, the tour, how to play", ids.next ~= nil and ids.find ~= nil and ids.ask ~= nil and ids.tour ~= nil and ids.how ~= nil)
choose(ada, "find")
said = lastLine(ada)
check("Find a place lists them all", #(said.choices or {}) == #Concierge.PLACES)
choose(ada, "vault")
said = lastLine(ada)
check("...and asks: shown the way, or taken now", choiceIds(said).walk ~= nil and choiceIds(said).now ~= nil)
choose(ada, "walk")
local way = lastWay(ada)
local _, vaultAt = Concierge.placeAt("vault")
check("5. walking by default: gold arrows to the place, on their own screen, nobody moved", way ~= nil and way.place == "vault" and (way.at - vaultAt).Magnitude < 1e-3 and #taken == 0)
run(function()
	Concierge.findPlace(ada, "ballroom")
end)
choose(ada, "now")
check("6. taken there at once only when they ask", #taken == 1 and taken[1].id == "ballroom")

---------------------------------------------------------------------------------------------------
-- 7. Answers, with the house's real numbers
---------------------------------------------------------------------------------------------------
do
	local invite = Concierge.answer("invite")
	check("7. how to get an invitation: the real haul and price", invite ~= nil and string.find(invite, string.format("%d,%03d", C.executive.inviteHaul // 1000, C.executive.inviteHaul % 1000), 1, true) ~= nil and string.find(invite, "25,000", 1, true) ~= nil)
	check("...Stride: the real share a level", string.find(Concierge.answer("stride"), tostring(math.floor(C.luxe.stridePerLevel * 1000 + 0.5) / 10) .. "%", 1, true) ~= nil, Concierge.answer("stride"))
	check("...a skip: the real Gems, and that it's never timed", string.find(Concierge.answer("skip"), tostring(C.basement.skipGems) .. " Gems", 1, true) ~= nil and string.find(Concierge.answer("skip"), "isn't timed", 1, true) ~= nil)
	local blank = true
	for _, q in Voice.Concierge.questions do
		local a = Concierge.answer(q.id)
		if not a or string.find(a, "{", 1, true) then
			blank = false
		end
		if string.find(a or "", "!", 1, true) then
			blank = false
		end
	end
	check("...every answer complete (nothing left unfilled), and in the house's voice (no exclamation marks)", blank)
	choose(ada, "now") -- (nothing pending: ignored)
	run(function()
		Concierge.menu(ada)
	end)
	choose(ada, "ask")
	said = lastLine(ada)
	-- (Build 87) By kind first, and every question in the book to search.
	check("Build 87: the questions come by kind, with the question book to search", #(said.choices or {}) == #Voice.Concierge.qaCategories + 1 and choiceIds(said)["cat:attractions"] ~= nil and choiceIds(said).search ~= nil)
	local everyKind = true
	for _, q in Voice.Concierge.questions do
		local found = false
		for _, c in Voice.Concierge.qaCategories do
			if c.id == q.cat then
				found = true
			end
		end
		if not found then
			everyKind = false
		end
	end
	check("...every question has its kind", everyKind)
	choose(ada, "cat:attractions")
	said = lastLine(ada)
	check("...a kind lists its questions, and Back", choiceIds(said).caught ~= nil and choiceIds(said).back ~= nil and choiceIds(said).rich == nil)
	choose(ada, "caught")
	said = lastLine(ada)
	check("...and answered", said.line == Concierge.answer("caught"))
	check("...an answer about a place offers Guide me there, and Another question", choiceIds(said).guide ~= nil and choiceIds(said).another ~= nil)
	local waysBefore = 0
	for _, m in ada.inbox do
		if m.op == "way" then
			waysBefore += 1
		end
	end
	choose(ada, "guide")
	local waysAfter = 0
	for _, m in ada.inbox do
		if m.op == "way" then
			waysAfter += 1
		end
	end
	check("...Guide me there: the gold arrows, walking", waysAfter == waysBefore + 1 and lastWay(ada).place == "velvet")
	run(function()
		Concierge.menu(ada)
	end)
	choose(ada, "ask")
	choose(ada, "search")
	local book
	for i = #ada.inbox, 1, -1 do
		if ada.inbox[i].op == "ask" then
			book = ada.inbox[i]
			break
		end
	end
	check("...the question book: every question with its answer filled in, to search on the guest's screen", book ~= nil and #book.items == #Voice.Concierge.questions and #book.cats == #Voice.Concierge.qaCategories and (function()
		for _, it in book.items do
			if type(it.a) ~= "string" or string.find(it.a, "{", 1, true) then
				return false
			end
		end
		return true
	end)())
	-- (A breath, so the next choices aren't taken for a guest pressing too fast.)
	advance(5)
end

---------------------------------------------------------------------------------------------------
-- 8. What to do next, from what they've done
---------------------------------------------------------------------------------------------------
do
	local d = profiles[ada].Data
	d.attractions = {}
	local line, place = Concierge.recommend(ada)
	check("8. a new guest: Steal a Luxe", line == Voice.Concierge.recommend.luxe and place == "velvet")
	d.attractions.luxe = { hauls = 2, bag = 1 }
	d.gilt = C.luxe.bagPrice[2]
	line, place = Concierge.recommend(ada)
	check("...a purse that can buy a bigger bag: the upgrade", line == Voice.Concierge.recommend.upgrade and place == "velvet")
	d.gilt = 0
	line, place = Concierge.recommend(ada)
	check("...hauls banked, no Basement yet: the Basement", line == Voice.Concierge.recommend.basement and place == "obsidian")
	d.attractions.executive = { invites = 1 }
	line, place = Concierge.recommend(ada)
	check("...an invitation held: the Executive Suite", line == Voice.Concierge.recommend.executive and place == "midnight")
	run(function()
		Concierge.menu(ada)
	end)
	choose(ada, "next")
	said = lastLine(ada)
	check("asked what next, he says it and offers the way", said.line == Voice.Concierge.recommend.executive and choiceIds(said).go ~= nil)
	-- Every game in the house: the Maison Directory, on the guest's own screen.
	local opened = {}
	Concierge.openDirectory = function(p)
		table.insert(opened, p)
	end
	run(function()
		Concierge.menu(ada)
	end)
	said = lastLine(ada)
	check("his menu offers every game in the house", choiceIds(said).games ~= nil)
	choose(ada, "games")
	check("...which opens the Maison Directory on the guest's screen", #opened == 1 and opened[1] == ada)
end

---------------------------------------------------------------------------------------------------
-- 9-11. The tour replayable; the news shown once to guests from before, and remembered
---------------------------------------------------------------------------------------------------
local tours = 0
for _, m in ada.inbox do
	if m.op == "start" then
		tours += 1
	end
end
run(function()
	Concierge.menu(ada)
end)
choose(ada, "tour")
local after = 0
for _, m in ada.inbox do
	if m.op == "start" then
		after += 1
	end
end
check("9. the tour can be taken again, any time, from the menu", after == tours + 1)
local old = H.guest("Olga", 802)
profiles[old].Data.flags = profiles[old].Data.flags or {}
profiles[old].Data.flags.toured = true
local needs = Concierge.needsTour
Concierge.needsTour = function()
	return false
end
run(function()
	Concierge.greet(old, false)
end)
said = lastLine(old)
check("10. Build 101: a guest from before: welcomed back, never offered a tour (not even of what's new)", said ~= nil and string.find(said.line, "three new attractions", 1, true) == nil and choiceIds(said).tour == nil and profiles[old].Data.flags.news72 == true)
check("11. ...just a hello, with no keys to press", said ~= nil and next(choiceIds(said)) == nil)
local before = #old.inbox
run(function()
	Concierge.greet(old, false)
end)
said = lastLine(old)
check("...next time, simply welcomed back", #old.inbox > before and string.find(said.line, "three new attractions", 1, true) == nil)
Concierge.needsTour = needs

---------------------------------------------------------------------------------------------------
-- 12. He knows the attractions
---------------------------------------------------------------------------------------------------
do
	local A = Voice.Concierge.arrivedIn
	check("12. walked in, he names each attraction's room and what it's for", string.find(A.velvet, "Steal a Luxe", 1, true) ~= nil and string.find(A.obsidian, "Treasury", 1, true) ~= nil and string.find(A.midnight, "Quartermaster", 1, true) ~= nil)
	local voice = true
	for _, key in { "recommend", "find" } do
		for _, line in Voice.Concierge[key] do
			if string.find(line, "!", 1, true) then
				voice = false
			end
		end
	end
	check("...in the house's voice (no exclamation marks)", voice)
	check("every room is open to him (the invitation is at the Suite's lift)", AttractionList.byRoom.midnight ~= nil)
end

---------------------------------------------------------------------------------------------------
-- 13. The Maison Directory's "Walk me there": Travel "way", the Concierge's own gold arrows
---------------------------------------------------------------------------------------------------
do
	Travel.showWay = Concierge.showWay
	run(Travel.start)
	local g = H.guest("Wren", 813)
	advance(1)
	local function travel(m)
		run(function()
			Remotes.event("Travel").OnServerEvent:Fire(g, m)
		end)
		advance(0.2)
	end
	local was = g.root.CFrame.Position
	local before = #g.inbox
	travel({ op = "way", place = "midnight" })
	local got = g.inbox[#g.inbox]
	check("13. Walk me there: the gold arrows to the room, from anywhere", #g.inbox == before + 1 and got.op == "way" and got.place == "midnight" and type(got.name) == "string" and typeof(got.at) == "Vector3")
	check("...and nobody is moved", (g.root.CFrame.Position - was).Magnitude < 0.01)
	travel({ op = "way", place = "nowhere" })
	check("...a place the house doesn't know: refused, plainly", g.inbox[#g.inbox].op == "refused")
	before = #g.inbox
	travel({ op = "teleport", place = "vault" })
	travel({ op = "way", place = 5 })
	check("...and nothing but its own requests is heard", #g.inbox == before)
	check("every place the Directory leads to is one the house knows", (function()
		local Directory = module("ReplicatedStorage", "Shared", "Directory")
		for _, e in Directory.List do
			if not Travel.places()[e.place] then
				return false
			end
		end
		return true
	end)())
end

---------------------------------------------------------------------------------------------------
-- 13. Build 87: a brand-new guest is shown round without a click, once
---------------------------------------------------------------------------------------------------
do
	local nia = H.guest("Nia", 803)
	profiles[nia].Data.flags = profiles[nia].Data.flags or {}
	local auto = Concierge.autoTour
	local due = true
	Concierge.autoTour = function()
		local d = due
		due = false
		return d
	end
	local function starts()
		local n = 0
		for _, m in nia.inbox do
			if m.op == "start" then
				n += 1
			end
		end
		return n
	end
	run(function()
		Concierge.greet(nia, true)
	end)
	local said = lastLine(nia)
	check("13. a brand-new guest: welcomed by name, told the tour is starting and how to end it, nothing to press", said ~= nil and string.find(said.line, "Nia", 1, true) ~= nil and string.find(said.line, "end the tour", 1, true) ~= nil and next(choiceIds(said)) == nil and string.find(said.line, "!", 1, true) == nil, said and said.line)
	check("...not yet: the welcome has its moment first", starts() == 0)
	advance(5.5)
	check("...then the tour begins by itself", starts() == 1)
	run(function()
		Concierge.greet(nia, false)
	end)
	advance(6)
	check("...and never by itself again (the next visit: no tour unless asked)", starts() == 1)
	Concierge.autoTour = auto
end

---------------------------------------------------------------------------------------------------
-- 14. (Build 93) The house's welcome gift: a new guest's first brainrot, their choice of three,
-- before the first tour; chosen once, never twice; the tour waits for it, but not for ever.
---------------------------------------------------------------------------------------------------
do
	local WelcomeGift = module("ServerScriptService", "Server", "WelcomeGift")
	local Brainrots = module("ServerScriptService", "Server", "Brainrots")
	local CuriosS = module("ServerScriptService", "Server", "Curios")
	CuriosS.arrived = Brainrots.arrived
	CuriosS.changing = Brainrots.settle
	run(WelcomeGift.start)
	Concierge.offerGift = WelcomeGift.offer
	Concierge.giftSettled = WelcomeGift.settled
	local auto = Concierge.autoTour
	local dueFor = {}
	Concierge.autoTour = function(p)
		local d = dueFor[p] == true
		dueFor[p] = false
		return d
	end
	local function count(p, op)
		local n = 0
		for _, m in p.inbox do
			if m.op == op then
				n += 1
			end
		end
		return n
	end
	local function last(p, op)
		for i = #p.inbox, 1, -1 do
			if p.inbox[i].op == op then
				return p.inbox[i]
			end
		end
		return nil
	end
	local function ask(p, request)
		advance(1.2)
		local r
		run(function()
			r = Remotes.funcs.WelcomeGiftAsk.OnServerInvoke(p, request)
		end)
		return r
	end
	local ola = H.guest("Ola", 811)
	dueFor[ola] = true
	run(function()
		Concierge.greet(ola, true)
	end)
	local offer = last(ola, "welcomeGift")
	check("14. a brand-new guest is offered the house's welcome gift at once: three brainrots to choose from", offer ~= nil and type(offer.choices) == "table" and #offer.choices == 3)
	local named = offer ~= nil
	for _, o in (offer and offer.choices or {}) do
		if type(o.name) ~= "string" or type(o.rate) ~= "number" or o.rate <= 0 then
			named = false
		end
	end
	check("...each with its name and the Gilt it earns an hour (the server's own numbers)", named)
	local said = lastLine(ola)
	check("...the Concierge says what it is, by name, plainly", said ~= nil and string.find(said.line, "Ola", 1, true) ~= nil and string.find(said.line, "gift", 1, true) ~= nil and string.find(said.line, "!", 1, true) == nil, said and said.line)
	advance(8)
	check("...the tour waits while they choose", count(ola, "start") == 0)
	local od = profiles[ola].Data
	check("a brainrot that isn't one of the three is refused", ask(ola, { op = "claim", id = "moonCheese" }).ok == false and (CuriosS.bag(od).items.moonCheese or 0) == 0)
	local got = ask(ola, { op = "claim", id = "pigeonetto" })
	check("choosing one: it's theirs", got.ok == true and CuriosS.bag(od).items.pigeonetto == 1)
	check("...straight into their squad, so its jar starts filling", table.find(Brainrots.squadOf(od).ids, "pigeonetto") ~= nil and Brainrots.rate(od) > 0)
	check("...and its reveal plays on their screen", last(ola, "found") ~= nil and last(ola, "found").id == "pigeonetto")
	check("a second gift is never given", ask(ola, { op = "claim", id = "croissantino" }).ok == false and (CuriosS.bag(od).items.croissantino or 0) == 0 and CuriosS.bag(od).items.pigeonetto == 1)
	advance(7)
	check("...then the tour begins", count(ola, "start") == 1)
	run(function()
		Concierge.greet(ola, false)
	end)
	check("...and the gift is never offered again", count(ola, "welcomeGift") == 1)

	local pax = H.guest("Pax", 812)
	dueFor[pax] = true
	run(function()
		Concierge.greet(pax, true)
	end)
	advance(20)
	check("a guest who doesn't choose: the tour still waits a little", count(pax, "start") == 0)
	advance(20)
	check("...but never for ever: it begins all the same", count(pax, "start") == 1)
	check("...and the gift stays theirs to choose later", WelcomeGift.eligible(profiles[pax].Data))

	local quin = H.guest("Quin", 813)
	CuriosS.give(nil, profiles[quin].Data, "croissantino", 1, "tables")
	run(function()
		Concierge.greet(quin, false)
	end)
	check("a guest who already has a brainrot is never offered it", count(quin, "welcomeGift") == 0 and ask(quin, { op = "claim", id = "bananino" }).ok == false)
	local rae = H.guest("Rae", 814)
	run(function()
		Concierge.greet(rae, false)
	end)
	check("a returning guest with no brainrot yet is offered it as they come in", count(rae, "welcomeGift") == 1)
	check("nonsense from a screen is refused", ask(rae, { op = "grant", id = "pigeonetto", n = 99 }).ok == false and WelcomeGift.eligible(profiles[rae].Data))
	Concierge.autoTour = auto
end

H.finish()

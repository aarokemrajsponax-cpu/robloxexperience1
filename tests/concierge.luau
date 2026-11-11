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
check("1. a first visit: welcomed at once, with the house's aim, and offered the tour", said ~= nil and string.find(said.line, "wealthiest", 1, true) ~= nil and choiceIds(said).tour ~= nil)
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
	for _, want in { "Steal a Luxe", "The Maison Basement", "The Executive Suite", "The Salon", "The Vault", "The Boutique", "The Ballroom", "The Terrace", "Your Suite" } do
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
	check("the questions are offered", #(said.choices or {}) == #Voice.Concierge.questions)
	choose(ada, "caught")
	said = lastLine(ada)
	check("...and answered", said.line == Concierge.answer("caught"))
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
check("10. a guest from before: welcomed back and offered what's new, once", said ~= nil and string.find(said.line, "three new attractions", 1, true) ~= nil and choiceIds(said).tour ~= nil and profiles[old].Data.flags.news72 == true)
choose(old, "later")
check("11. later: said kindly, and remembered (not asked again)", lastLine(old).line == Voice.Concierge.newsLaterLine)
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

H.finish()

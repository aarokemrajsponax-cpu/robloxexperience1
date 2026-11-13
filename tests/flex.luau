--!nocheck
-- The Flex Studio in the Grand Ballroom (server/Attractions/Flex, its stage in GalaBuild), under
-- Lune on a fake clock, in the house's test harness: the stage as built (the mark's prompt, the
-- kiosk's, the Flex Wall), what each guest may flex (only what is theirs, from their own record),
-- shooting a reel (on the mark, in the hall, one of their own things, a set and a caption of the
-- house's, never two too close together), the wall, likes (one each, never your own) and the small
-- capped Gilt: the first reel of the day, and a little for each like given.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/flex.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles = H.module, H.profiles
local Remotes, Config = H.Remotes, H.Config

local Layout = module("ReplicatedStorage", "Shared", "Layout")
local Plan = module("ReplicatedStorage", "Shared", "Flex")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Game = module("ServerScriptService", "Server", "Attractions", "Gala")
local Flex = module("ServerScriptService", "Server", "Attractions", "Flex")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Herald = module("ServerScriptService", "Server", "Herald")

local T = 5000
Flex.now = function()
	return T
end

local workspace = H.game:GetService("Workspace")
Lobbies.build(workspace)
local ada = H.guest("Ada", 1201)
local bo = H.guest("Bo", 1202)
local cy = H.guest("Cy", 1203)
run(Herald.start)
run(Attractions.start)
local o = Config.data.Attractions.gala.origin
local O = Vector3.new(o[1], o[2], o[3])

local ask = Remotes.funcs.AttractionAsk.OnServerInvoke
local function askAs(g, request)
	advance(0.4)
	local r
	run(function()
		r = ask(g, request)
	end)
	return r
end
local function data(g)
	return profiles[g].Data
end
local function stand(g, at)
	g.Character = g.body
	g.root.CFrame = CFrame.new(at + Vector3.new(0, 3, 0))
end
local function flex(g, what, extra)
	local r = { op = "act", id = "gala", act = "flex", what = what }
	for k, v in extra or {} do
		r[k] = v
	end
	return askAs(g, r)
end
local function last(g, what)
	for i = #g.inbox, 1, -1 do
		local m = g.inbox[i]
		if m.op == "gala" and m.kind == "flex" and (what == nil or m.what == what) then
			return m
		end
	end
	return nil
end
local function find(items, key)
	for _, it in items do
		if it.key == key then
			return it
		end
	end
	return nil
end

---------------------------------------------------------------------------------------------------
-- 1. The stage as built
---------------------------------------------------------------------------------------------------
local panels = {}
for _, p in H.tagged.AttractionPrompt or {} do
	if p:GetAttribute("Attraction") == "gala" and p:GetAttribute("Kind") == "panel" then
		panels[tostring(p:GetAttribute("Panel"))] = p
	end
end
check("the Flex Studio: a prompt on the gold mark to make a reel, and one at the kiosk to like them", panels.flex ~= nil and panels.feed ~= nil and panels.flex.ActionText == "Make a reel" and panels.feed.ActionText == "Like a reel")
local wall = Game.internals().built.flexWall
check("...and the Flex Wall, written by the server: nobody's shot one yet", wall ~= nil and wall.labels.Top.Text == "No reels yet tonight. Be the first." and wall.labels.Live.Text ~= "")

---------------------------------------------------------------------------------------------------
-- 2. In, and what each guest may flex
---------------------------------------------------------------------------------------------------
for _, g in { ada, bo, cy } do
	data(g).gilt = 0
	stand(g, Layout.Ballroom.galaHome)
	check(g.Name .. " goes into the Grand Ballroom", askAs(g, { op = "go", id = "gala" }).ok == true)
	advance(3)
end
-- Ada owns a brainrot, a rare curio, a Wardrobe piece and the Gold Key; Bo owns nothing much.
data(ada).curios = { items = { croissantino = 2, baguettone = 1 }, favs = {}, recent = {}, found = 3, given = {} }
data(ada).owned = { table_oxblood = true }
data(ada).goldKey = true
local r = flex(ada, "list")
check("the picker: everything Ada may flex, from her own record", r.ok == true and find(r.items, "brainrot:croissantino") ~= nil and find(r.items, "wardrobe:table_oxblood") ~= nil and find(r.items, "goldKey") ~= nil and find(r.items, "fortune") ~= nil, r.items and #r.items)
check("...the four sets and the six captions, the house's own", #r.sets == #Plan.Sets and #r.captions == #Plan.Captions)
local rb = flex(bo, "list")
check("Bo's picker: his Fortune, and nothing that isn't his", rb.ok == true and find(rb.items, "fortune") ~= nil and find(rb.items, "goldKey") == nil and find(rb.items, "brainrot:croissantino") == nil)

---------------------------------------------------------------------------------------------------
-- 3. Shooting a reel
---------------------------------------------------------------------------------------------------
stand(ada, O + Vector3.new(0, 0, 20))
r = flex(ada, "record", { item = "brainrot:croissantino", set = "jet", line = "woke" })
check("off the mark: told to stand on it", r.ok == false and string.find(r.why, "gold mark", 1, true) ~= nil, r.why)
stand(ada, O + Plan.MARK.Position)
r = flex(ada, "record", { item = "brainrot:nosuch", set = "jet", line = "woke" })
check("something that isn't hers: refused", r.ok == false and r.why == "That isn't yours to flex.")
r = flex(ada, "record", { item = "goldKey", set = "mars", line = "woke" })
check("a set that isn't one: refused", r.ok == false and r.why == "Choose a set.")
r = flex(ada, "record", { item = "goldKey", set = "jet", line = "Hello everyone" })
check("a caption that isn't the house's (nothing typed is ever shown): refused", r.ok == false and r.why == "Choose a caption.")
r = flex(ada, "record", { item = "brainrot:croissantino", set = "garage", line = "woke" })
check("on the mark, her own brainrot, a set and a caption: shot", r.ok == true and r.reel ~= nil and r.reel.text == "I woke up with Croissantino Furioso." and r.reel.mine == true and r.reel.likes == 0, r.why)
-- (Paid through the house's Gilt, so its boosts apply on top of the base.)
local firstPaid = r.gilt
check("...the first reel of the day: a little Gilt", firstPaid >= Plan.REWARDS.firstReel and firstPaid < Plan.REWARDS.firstReel * 3 and data(ada).gilt == firstPaid, data(ada).gilt)
local first = r.reel
check("...everyone in the hall is told, and the wall shows it live", last(bo, "reel") ~= nil and last(bo, "reel").reel.id == first.id and string.find(wall.labels.Live.Text, "LIVE", 1, true) ~= nil and string.find(wall.labels.Top.Text, "Croissantino", 1, true) ~= nil)
r = flex(ada, "record", { item = "goldKey", set = "yacht", line = "post" })
check("a second straight after: one reel at a time", r.ok == false and string.find(r.why, "One reel at a time", 1, true) ~= nil, r.why)
T += Plan.COOLDOWN + 1
run(function()
	Flex.step()
end)
check("the reel over: the wall no longer says live", string.find(wall.labels.Live.Text, "LIVE", 1, true) == nil)
r = flex(ada, "record", { item = "goldKey", set = "yacht", line = "post" })
check("after a little while, another: the Gold Key", r.ok == true and r.reel.text == "the Gold Key. That's the post.")
check("...no more Gilt for a second reel today", data(ada).gilt == firstPaid and r.gilt == 0)
local second = r.reel
stand(cy, O + Vector3.new(30, 0, -60))
r = flex(cy, "record", { item = "fortune", set = "penthouse", line = "pov" })
check("Cy, nowhere near the mark: refused", r.ok == false)

---------------------------------------------------------------------------------------------------
-- 4. Likes: one each, never your own
---------------------------------------------------------------------------------------------------
r = flex(ada, "like", { n = second.id })
check("liking your own reel: no", r.ok == false and r.why == "That's your own reel.")
r = flex(bo, "like", { n = first.id })
check("Bo likes Ada's first reel", r.ok == true and r.likes == 1)
check("...Ada is paid a little for it", data(ada).gilt - firstPaid >= Plan.REWARDS.like and data(ada).gilt - firstPaid < Plan.REWARDS.like * 3, data(ada).gilt - firstPaid)
check("...and the hall is told the count", last(cy, "likes") ~= nil and last(cy, "likes").id == first.id and last(cy, "likes").likes == 1)
r = flex(bo, "like", { n = first.id })
check("...but only once", r.ok == false and r.why == "You've liked it already.")
r = flex(cy, "like", { n = first.id })
check("Cy likes it too: two", r.ok == true and r.likes == 2)
r = flex(cy, "like", { n = 999 })
check("a reel that isn't on the wall: no", r.ok == false)
local view = flex(bo, "list")
local seen
for _, reel in view.reels do
	if reel.id == first.id then
		seen = reel
	end
end
check("the feed: newest first, each with its likes, and whether this guest liked it (never who else did)", view.reels[1].id == second.id and seen ~= nil and seen.likes == 2 and seen.liked == true and seen.mine == false and seen.likedBy == nil)
-- The likes that pay are capped for the day.
local before = data(ada).gilt
Game.page(Attractions.ctx, data(ada)).likesPaid = Plan.REWARDS.likesPaid
local dee = H.guest("Dee", 1204)
stand(dee, Layout.Ballroom.galaHome)
askAs(dee, { op = "go", id = "gala" })
advance(3)
r = flex(dee, "like", { n = second.id })
check("past the day's likes that pay: the like counts, no more Gilt", r.ok == true and data(ada).gilt == before)
-- Outside the hall: no likes.
askAs(bo, { op = "home" })
advance(3)
r = flex(bo, "like", { n = second.id })
check("out of the Grand Ballroom: no likes from there", r.ok == false and string.find(r.why, "Grand Ballroom", 1, true) ~= nil)

---------------------------------------------------------------------------------------------------
-- 5. Requests that aren't the studio's
---------------------------------------------------------------------------------------------------
r = askAs(ada, { op = "act", id = "gala", act = "flex", what = "record", item = "goldKey", set = "jet", line = "woke", extra = "x" })
check("a request with a field the house doesn't take: refused", r.ok == false)
r = flex(ada, "record", { item = string.rep("x", 200), set = "jet", line = "woke" })
check("an over-long item: refused", r.ok == false)

H.finish()

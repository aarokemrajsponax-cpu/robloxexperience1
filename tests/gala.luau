--!nocheck
-- The Grand Ballroom on the server (server/Attractions/Gala, GalaBuild, server/HallOfFame, the
-- doors in World/Lobbies), under Lune on a fake clock, in the house's test harness: the great
-- doors at the far end of the Ballroom; the hall as built (its prompts, boards and budget); in and
-- home; the jukebox's votes; the dance floor's minutes (and the day's ten); Luxury Trivia (seven
-- questions, the right answer told only when the time is up, the quickest right answer winning);
-- the Runway (two models at least, each walking in turn, the room's votes, never for yourself);
-- the Daily Arena's three challenges; the photo sets; one activity at a time; the day's cap on
-- the hall's Gilt; the Hall of Fame's figures and boards; and requests that aren't the hall's.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/gala.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local Vector3, CFrame = H.Vector3, H.CFrame
local module, profiles = H.module, H.profiles
local Remotes, Config = H.Remotes, H.Config

local Layout = module("ReplicatedStorage", "Shared", "Layout")
local Plan = module("ReplicatedStorage", "Shared", "Gala")
local AttractionList = module("ReplicatedStorage", "Shared", "Attractions")
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Game = module("ServerScriptService", "Server", "Attractions", "Gala")
local Lobbies = module("ServerScriptService", "Server", "World", "Lobbies")
local Herald = module("ServerScriptService", "Server", "Herald")
local HallOfFame = module("ServerScriptService", "Server", "HallOfFame")

local awards, tallies, progress = {}, {}, {}
Attractions.award = function(p, key)
	table.insert(awards, { p = p, key = key })
end
Attractions.tally = function(p, stat, n)
	tallies[p.UserId .. ":" .. stat] = (tallies[p.UserId .. ":" .. stat] or 0) + n
end
Attractions.progress = function(p, kind, n)
	progress[p.UserId .. ":" .. kind] = (progress[p.UserId .. ":" .. kind] or 0) + n
end
local function awarded(g, key)
	for _, a in awards do
		if a.p == g and a.key == key then
			return true
		end
	end
	return false
end

local workspace = H.game:GetService("Workspace")
Lobbies.build(workspace)
local ada = H.guest("Ada", 1101)
local bo = H.guest("Bo", 1102)
local cy = H.guest("Cy", 1103)
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
local function last(g, kind, phase)
	for i = #g.inbox, 1, -1 do
		local m = g.inbox[i]
		if m.op == "gala" and (kind == nil or m.kind == kind) and (phase == nil or m.phase == phase) then
			return m
		end
	end
	return nil
end
local function data(g)
	return profiles[g].Data
end
local function page(g)
	return Game.page(Attractions.ctx, data(g))
end
local function stand(g, at, y)
	g.Character = g.body
	g.root.CFrame = CFrame.new(at + Vector3.new(0, y or 3, 0))
end
local function standOn(g, v, y)
	stand(g, O + v, y)
end
local function act(g, what)
	what.op, what.id = "act", "gala"
	return askAs(g, what)
end
local function gilt(g)
	return data(g).gilt or 0
end
local function inside(g)
	return Attractions.inside(g) == "gala"
end
local I = Game.internals

---------------------------------------------------------------------------------------------------
-- 1. The doors in the Ballroom, and the hall as built
---------------------------------------------------------------------------------------------------
local kinds = {}
local doorAt = nil
for _, p in H.tagged.AttractionPrompt or {} do
	if p:GetAttribute("Attraction") == "gala" then
		local key = p:GetAttribute("Kind") .. ":" .. tostring(p:GetAttribute("Panel") or p:GetAttribute("What") or "")
		kinds[key] = (kinds[key] or 0) + 1
		if p:GetAttribute("Kind") == "go" then
			doorAt = p.Parent.CFrame.Position
		end
	end
end
check("the Grand Ballroom is one of the attractions, entered from the Ballroom", AttractionList.byId.gala ~= nil and AttractionList.byId.gala.room == "ballroom")
check("its great doors stand at the far end of the Ballroom, on the room's axis", doorAt ~= nil and Layout.zoneAt(doorAt) == "ballroom" and math.abs(doorAt.X - Layout.Ballroom.centre.X) < 0.5 and doorAt.Z > Layout.Ballroom.maxZ - 4, doorAt)
check("its prompts: the doors in and home, the jukebox, four Exchange stands, three photo sets, eight podiums, the Arena's gate, the models' book",
	kinds["go:"] == 1 and kinds["home:"] == 1 and kinds["panel:dance"] == 1 and kinds["panel:exchange"] == 4 and kinds["act:frame"] == 1 and kinds["act:rose"] == 1 and kinds["act:moon"] == 1
		and kinds["act:trivia"] == 8 and kinds["act:arena"] == 1 and kinds["act:runway"] == 1, kinds)
local built = I().built
local hall = built and built.model
check("the hall is built", hall ~= nil)
local parts, lights, tiles, frames, boards = 0, 0, 0, 0, 0
for _, d in hall:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		if d.Name == "Tile" then
			tiles += 1
		elseif d.Name == "GalleryFrame" then
			frames += 1
		elseif d.Name == "HallBoard" then
			boards += 1
		end
	elseif d:IsA("Light") then
		lights += 1
	end
end
check("within its budget: under 4,000 parts, at most twenty lights", parts < 4000 and lights <= 20, parts, lights)
check("a dance floor of glass tiles, eight gallery frames, six Hall of Fame boards", tiles > 80 and frames == 8 and boards == 6, tiles, frames, boards)
check("its places: the dance floor, the DJ's booth, the Salon of Wits, the Arena, the Runway, the Exchange, the terrace, the gallery, the bar",
	hall:FindFirstChild("DanceFloor") and hall:FindFirstChild("DJBooth") and hall:FindFirstChild("SalonOfWits") and hall:FindFirstChild("DailyArena") and hall:FindFirstChild("Runway")
		and hall:FindFirstChild("Exchange") and hall:FindFirstChild("MoonlitTerrace") and hall:FindFirstChild("AchievementGallery") and hall:FindFirstChild("Lounges"))
check("each board the server writes is there: the trivia screen, the Runway's, the Arena's", built.screen.labels.Question ~= nil and built.runwayBoard.labels.Theme ~= nil and built.arenaBoard.labels.Name ~= nil)
check("every zone of the plan inside the hall", (function()
	for _, z in Plan.Zones do
		if z.minX < Plan.HALL.minX or z.maxX > Plan.HALL.maxX or z.minZ < Plan.HALL.minZ or z.maxZ > Plan.HALL.maxZ then
			return false
		end
	end
	return true
end)())
check("the podiums, the stage and the Arena are in their own parts of the hall", Plan.zoneAt(Plan.podiumStand(1).Position) == "trivia" and Plan.zoneAt(Plan.podiumStand(8).Position) == "trivia"
	and Plan.zoneAt(Plan.RUNWAY.book) == "runway" and Plan.zoneAt(Plan.RUNWAY.wait.Position) == "runway" and Plan.zoneAt(Plan.ARENA.gate + Vector3.new(-3, 0, 0)) == "arena"
	and Plan.zoneAt(Plan.DANCE.centre) == "dance" and Plan.zoneAt(Plan.ARRIVAL.Position) == "entrance")
check("every trivia question has four different answers", (function()
	for _, q in Plan.Questions do
		if #q.a ~= 4 then
			return false
		end
		local seen = {}
		for _, a in q.a do
			if seen[a] then
				return false
			end
			seen[a] = true
		end
	end
	return #Plan.Questions >= 60
end)(), #Plan.Questions)

---------------------------------------------------------------------------------------------------
-- 2. In, and home
---------------------------------------------------------------------------------------------------
local function goIn(g)
	stand(g, Layout.Ballroom.galaHome)
	return askAs(g, { op = "go", id = "gala" })
end
local r = goIn(ada)
check("a guest in the Ballroom goes in through the great doors", r and r.ok == true and inside(ada), r)
check("and arrives inside the doors home, facing up the hall", (ada.root.CFrame.Position - (O + Plan.ARRIVAL.Position)).Magnitude < 4, ada.root.CFrame.Position)
advance(3)
r = askAs(ada, { op = "home" })
check("home again: back in the Ballroom, before the great doors", r and r.ok == true and not inside(ada) and Layout.zoneAt(ada.root.CFrame.Position) == "ballroom" and (ada.root.CFrame.Position - Layout.Ballroom.galaHome).Magnitude < 4, ada.root.CFrame.Position)
stand(cy, Vector3.new(0, 3, 0))
r = askAs(cy, { op = "go", id = "gala" })
check("from anywhere else, the house says where the doors are", r and r.ok == false and tostring(r.why):find("Ballroom") ~= nil, r)
advance(3)
check("Ada in again", goIn(ada).ok == true)
advance(3)
check("Bo in", goIn(bo).ok == true)
advance(3)
check("Cy in", goIn(cy).ok == true)

---------------------------------------------------------------------------------------------------
-- 3. The jukebox
---------------------------------------------------------------------------------------------------
r = act(ada, { act = "vote", what = "juke", n = 4 })
check("a vote for the next record", r and r.ok == true and r.mine == 4 and r.records[4].votes == 1, r)
check("a record that isn't in the jukebox is refused", act(bo, { act = "vote", what = "juke", n = 99 }).ok == false)
check("nor half a record", act(bo, { act = "vote", what = "juke", n = 2.5 }).ok == false)
act(bo, { act = "vote", what = "juke", n = 4 })
act(cy, { act = "vote", what = "juke", n = 2 })
local before = I().juke.track
advance(Plan.TRACK_SECONDS + 1)
check("when the record's time is up, the most-voted goes on, for everyone in the hall", I().juke.track == 4 and before ~= 4 and last(cy, "juke") ~= nil and last(cy, "juke").track == 4, I().juke.track)
check("and the votes start again", next(I().juke.votes) == nil)

---------------------------------------------------------------------------------------------------
-- 4. The dance floor
---------------------------------------------------------------------------------------------------
local g0 = gilt(bo)
standOn(bo, Plan.DANCE.centre)
advance(10)
check("a few seconds on the dance floor: the On the Floor badge", awarded(bo, "firstDance"))
advance(52)
check("a minute on the floor pays a little", gilt(bo) - g0 == Plan.REWARDS.danceMinute and page(bo).minutes == 1, gilt(bo) - g0)
local m = last(bo, "danced")
check("and the guest is told", m ~= nil and m.minutes == 1 and m.paid == Plan.REWARDS.danceMinute)
page(bo).minutes = Plan.REWARDS.danceMinutes
local g1 = gilt(bo)
advance(61)
check("ten minutes a day pay; the eleventh doesn't", gilt(bo) == g1 and page(bo).minutes == Plan.REWARDS.danceMinutes + 1)
standOn(bo, Vector3.new(0, 0, 60))
local g2 = gilt(bo)
advance(65)
check("off the floor, nothing", gilt(bo) == g2)

---------------------------------------------------------------------------------------------------
-- 5. Luxury Trivia
---------------------------------------------------------------------------------------------------
standOn(ada, Vector3.new(0, 0, 0))
r = act(ada, { act = "join", what = "trivia" })
check("trivia is played at the podiums, in the Salon of Wits", r.ok == false and tostring(r.why):find("Salon") ~= nil, r)
standOn(ada, Vector3.new(-80, 0, 58))
r = act(ada, { act = "join", what = "trivia" })
check("a guest takes a podium", r.ok == true and I().trivia.seats[ada] ~= nil and I().trivia.phase == "lobby", r)
local podium = I().trivia.seats[ada].podium
check("and is put behind it, facing the screen", (ada.root.CFrame.Position - (O + Plan.podiumStand(podium).Position)).Magnitude < 4)
standOn(bo, Vector3.new(-80, 0, 40))
check("a second guest takes another podium", act(bo, { act = "join", what = "trivia" }).ok == true and I().trivia.seats[bo].podium ~= podium)
check("nobody plays twice", act(bo, { act = "join", what = "trivia" }).ok == false)
standOn(cy, Vector3.new(-88, 0, -58))
act(cy, { act = "join", what = "arena" })
standOn(cy, Vector3.new(-80, 0, 70))
r = act(cy, { act = "join", what = "trivia" })
check("one activity at a time: in the Arena's round, no podium", r.ok == false and tostring(r.why):find("Arena") ~= nil, r)
act(cy, { act = "quit", what = "arena" })
check("an answer before any question is refused", act(ada, { act = "answer", n = 1 }).ok == false)
advance(Plan.TRIVIA_LOBBY + 0.5)
local q = last(ada, "trivia", "question")
check("the first question, to everyone in the hall: the question and its four answers, never which is right", q ~= nil and q.n == 1 and #q.choices == 4 and q.right == nil and q.seated == true and last(cy, "trivia", "question") ~= nil and last(cy, "trivia", "question").seated == false, q)
check("the screen in the Salon shows it too", built.screen.labels.Question.Text == q.q)
local function rightOf(n)
	return I().trivia.set[n].right
end
local adaGilt, boGilt = gilt(ada), gilt(bo)
for n = 1, Plan.TRIVIA_QUESTIONS do
	local right = rightOf(n)
	local wrong = right % 4 + 1
	check("question " .. n .. ": Ada answers right", act(ada, { act = "answer", n = right }).ok == true)
	if n == 1 then
		check("an answer is final", act(ada, { act = "answer", n = wrong }).ok == false)
		check("an answer that isn't one of the four is refused", act(bo, { act = "answer", n = 5 }).ok == false)
	end
	advance(1)
	act(bo, { act = "answer", n = if n <= 2 then right else wrong })
	advance(0.3)
	local rv = last(ada, "trivia", "reveal")
	check("everyone has answered: the answer is told at once", rv ~= nil and rv.n == n and rv.right == right and rv.correct == true, rv)
	advance(Plan.TRIVIA_REVEAL + 0.3)
end
local res = last(bo, "trivia", "results")
check("the results: Ada, quickest and right every time, wins", res ~= nil and res.winners[1] == "Ada" and res.standings[1].name == "Ada" and res.standings[1].right == 7 and res.standings[2].right == 2, res)
check("a little Gilt for every right answer, more for the win", gilt(ada) - adaGilt == 7 * Plan.REWARDS.triviaCorrect + Plan.REWARDS.triviaWin and gilt(bo) - boGilt == 2 * Plan.REWARDS.triviaCorrect, gilt(ada) - adaGilt, gilt(bo) - boGilt)
check("the win counts for the Badge Book; the round for both guests' objectives", tallies["1101:triviaWins"] == 1 and tallies["1102:triviaWins"] == nil and progress["1101:trivia"] == 1 and progress["1102:trivia"] == 1)
advance(Plan.TRIVIA_RESULTS + 0.5)
check("then the podiums are free for the next round", I().trivia.phase == "idle" and next(I().trivia.seats) == nil)
-- A guest who leaves the hall leaves the podium.
standOn(ada, Vector3.new(-80, 0, 58))
act(ada, { act = "join", what = "trivia" })
stand(ada, Vector3.new(0, 3, 0))
advance(2) -- (away for a moment and a half: a step outside for a frame isn't leaving)
check("a guest who leaves the hall leaves their podium (and the round, with nobody left)", not inside(ada) and I().trivia.seats[ada] == nil and I().trivia.phase == "idle")
advance(3)
goIn(ada)

---------------------------------------------------------------------------------------------------
-- 6. The Runway
---------------------------------------------------------------------------------------------------
standOn(ada, Vector3.new(0, 0, 0))
check("models sign the book at the Runway", act(ada, { act = "join", what = "runway" }).ok == false)
standOn(ada, Plan.RUNWAY.book, 5.4)
r = act(ada, { act = "join", what = "runway" })
check("Ada signs up for the next show: its theme is chosen", r.ok == true and I().runway.phase == "signup" and string.find(r.title, "The Runway: ") == 1, r)
local theme = Plan.Themes[I().runway.theme]
advance(Plan.RUNWAY_SIGNUP + 0.5)
check("one model alone: the house waits a little longer for a second", I().runway.phase == "signup" and I().runway.extended == true)
advance(Plan.RUNWAY_EXTRA + 0.5)
check("and with still only one, the show is called off", I().runway.phase == "idle")
standOn(ada, Plan.RUNWAY.book, 5.4)
act(ada, { act = "join", what = "runway" })
standOn(bo, Plan.RUNWAY.book + Vector3.new(4, 0, 0), 5.4)
check("Bo signs up too", act(bo, { act = "join", what = "runway" }).ok == true and #I().runway.models == 2)
theme = Plan.Themes[I().runway.theme]
advance(Plan.RUNWAY_SIGNUP + 0.5)
check("the show begins: the first model is put at the top of the catwalk", I().runway.phase == "walk" and I().runway.walking == 1 and (ada.root.CFrame.Position - (O + Plan.RUNWAY.start.Position)).Magnitude < 4.5)
local walk = last(cy, "runway", "walk")
check("everyone in the hall is told who's walking", walk ~= nil and walk.name == "Ada" and walk.n == 1 and walk.of == 2, walk)
check("the model is marked for every screen's spotlight", ada:GetAttribute("RunwayModel") == true)
standOn(ada, Plan.RUNWAY.finish, 5.4)
advance(0.5)
check("on the gold mark: a pose, for every camera in the room", last(cy, "runway", "posed") ~= nil and I().runway.models[1].posed == true)
advance(4)
check("then the next model walks", I().runway.walking == 2 and ada:GetAttribute("RunwayModel") == nil and bo:GetAttribute("RunwayModel") == true)
advance(Plan.RUNWAY_WALK + 0.5)
local vote = last(cy, "runway", "vote")
check("Bo's time is up (no pose): the room votes, between the two looks", I().runway.phase == "vote" and vote ~= nil and #vote.models == 2, vote)
check("nobody votes for their own look", act(ada, { act = "vote", what = "runway", n = ada.UserId }).ok == false)
check("nor for someone who didn't walk", act(ada, { act = "vote", what = "runway", n = cy.UserId }).ok == false)
check("Ada votes Bo", act(ada, { act = "vote", what = "runway", n = bo.UserId }).ok == true)
check("Bo votes Ada", act(bo, { act = "vote", what = "runway", n = ada.UserId }).ok == true)
check("Cy votes Ada", act(cy, { act = "vote", what = "runway", n = ada.UserId }).ok == true)
adaGilt, boGilt = gilt(ada), gilt(bo)
local cyGilt = gilt(cy)
advance(Plan.RUNWAY_VOTE + 0.5)
local result = last(bo, "runway", "results")
check("the most votes wins the show", result ~= nil and result.winner == "Ada" and result.theme == theme.name, result)
check("the winner's Gilt, a little for walking, a little for voting", gilt(ada) - adaGilt == Plan.REWARDS.runwayWalk + Plan.REWARDS.runwayWin + Plan.REWARDS.runwayVote and gilt(bo) - boGilt == Plan.REWARDS.runwayWalk + Plan.REWARDS.runwayVote and gilt(cy) - cyGilt == Plan.REWARDS.runwayVote, gilt(ada) - adaGilt, gilt(bo) - boGilt, gilt(cy) - cyGilt)
check("the win counts for the Badge Book", tallies["1101:runwayWins"] == 1 and progress["1101:runway"] == 1 and progress["1102:runway"] == 1)
advance(Plan.RUNWAY_RESULTS + 0.5)
check("and the next show can be signed for", I().runway.phase == "idle")

---------------------------------------------------------------------------------------------------
-- 7. The Daily Arena (each of its three challenges)
---------------------------------------------------------------------------------------------------
local function arenaRound(challengeId, play)
	local day = 0
	while Plan.challengeFor(day).id ~= challengeId do
		day += 1
	end
	local base = Game.time
	Game.time = function()
		return day * 86400 + 3600
	end
	standOn(ada, Plan.ARENA.gate + Vector3.new(-3, 0, 0))
	standOn(bo, Plan.ARENA.gate + Vector3.new(-3, 0, 4))
	local ra = act(ada, { act = "join", what = "arena" })
	local rb = act(bo, { act = "join", what = "arena" })
	advance(Plan.ARENA_COUNTDOWN + 0.2)
	local started = I().arena.phase == "play" and I().arena.challenge == challengeId
	play()
	advance(Plan.ARENA_RESULTS + 1)
	Game.time = base
	return ra, rb, started
end
-- The spotlight: Ada keeps in it, Bo stays out.
adaGilt, boGilt = gilt(ada), gilt(bo)
local ra, rb, started = arenaRound("spotlight", function()
	for _ = 1, Plan.ARENA_PLAY * 5 do
		local t = H.fakeOs.clock() - I().arena.startedAt
		standOn(ada, Plan.spotlightAt(t))
		standOn(bo, Plan.ARENA.centre + Vector3.new(0, 0, -Plan.ARENA.radius + 2))
		advance(0.2)
		if I().arena.phase ~= "play" then
			break
		end
	end
end)
check("the Spotlight Chase: both join at the gate and are put in the ring", ra.ok == true and rb.ok == true and started)
local arenaRes = last(bo, "arena", "results")
check("keeping in the light scores; outside it, nothing", arenaRes ~= nil and arenaRes.rows[1].name == "Ada" and arenaRes.rows[1].points >= 60 and arenaRes.rows[2].points == 0, arenaRes and arenaRes.rows)
check("the winner's Gilt (points capped), a little for taking part", gilt(ada) - adaGilt == Plan.REWARDS.arenaTakePart + Plan.REWARDS.arenaPoints + Plan.REWARDS.arenaWin and gilt(bo) - boGilt == Plan.REWARDS.arenaTakePart, gilt(ada) - adaGilt, gilt(bo) - boGilt)
check("the win counts for the Badge Book", tallies["1101:arenaWins"] == 1 and progress["1102:arena"] == 1)
-- The Gilded Rush: Ada runs through three coins.
local coinsTaken, gone = 0, 0
arenaRound("coins", function()
	advance(0.3)
	for k = 1, 3 do
		local coin = I().arena.coins[k]
		standOn(ada, coin.pos)
		advance(0.2)
		if I().arena.coins[k].back > 0 then
			gone += 1
		end
	end
	coinsTaken = I().arena.players[ada] and math.floor(I().arena.players[ada].points) or -1
	standOn(ada, Plan.ARENA.centre + Vector3.new(0, 0, Plan.ARENA.radius - 2))
	advance(Plan.ARENA_PLAY)
end)
check("the Gilded Rush: a coin a point, each gone for everyone once taken", coinsTaken >= 3 and gone == 3, coinsTaken, gone)
-- Hold the Dais: alone it scores, shared nobody does.
local alone, shared = 0, 0
arenaRound("dais", function()
	standOn(ada, Plan.ARENA.centre, 4.4)
	standOn(bo, Plan.ARENA.centre + Vector3.new(0, 0, Plan.ARENA.radius - 3))
	advance(5)
	alone = math.floor(I().arena.players[ada].points)
	standOn(bo, Plan.ARENA.centre + Vector3.new(2, 0, 0), 4.4)
	advance(5)
	shared = math.floor(I().arena.players[ada].points) - alone
	advance(Plan.ARENA_PLAY)
end)
check("Hold the Dais: a point a second alone on it; shared, nobody scores", alone >= 4 and alone <= 5 and shared == 0, alone, shared)

---------------------------------------------------------------------------------------------------
-- 8. The photo sets
---------------------------------------------------------------------------------------------------
standOn(cy, Vector3.new(0, 0, 0))
r = act(cy, { act = "pose", what = "frame" })
check("a pose only at the set itself", r.ok == false, r)
check("and only at a set the hall has", act(cy, { act = "pose", what = "throne" }).ok == false)
cyGilt = gilt(cy)
for _, s in Plan.PhotoSets do
	standOn(cy, s.mark.Position + Vector3.new(0, 0, 0), 4)
	r = act(cy, { act = "pose", what = s.id })
	check("a pose at " .. s.name, r.ok == true and last(cy, "pose") ~= nil and last(cy, "pose").set == s.id, r)
end
check("the first pose at each set today pays a little", gilt(cy) - cyGilt == 3 * Plan.REWARDS.photoSet, gilt(cy) - cyGilt)
check("all three: the Picture Perfect badge", awarded(cy, "photoSets"))
local cyGilt2 = gilt(cy)
standOn(cy, Plan.photoById.rose.mark.Position, 4)
act(cy, { act = "pose", what = "rose" })
check("a second pose at a set the same day pays nothing more", gilt(cy) == cyGilt2)

---------------------------------------------------------------------------------------------------
-- 9. The day's cap on the hall's Gilt
---------------------------------------------------------------------------------------------------
local pc = page(cy)
pc.gilt = Plan.REWARDS.dailyGilt - 5
pc.photos = {}
local cyGilt3 = gilt(cy)
standOn(cy, Plan.photoById.moon.mark.Position, 5)
act(cy, { act = "pose", what = "moon" })
check("never more than the day's cap: only what's left of it is paid", gilt(cy) - cyGilt3 == 5 and page(cy).gilt == Plan.REWARDS.dailyGilt, gilt(cy) - cyGilt3)

---------------------------------------------------------------------------------------------------
-- 10. What a screen is told, and requests that aren't the hall's
---------------------------------------------------------------------------------------------------
r = askAs(ada, { op = "state", id = "gala" })
check("the hall's state for a screen: the record playing, the activities, the day's Gilt", r and r.ok == true and r.juke ~= nil and r.juke.name ~= nil and r.trivia ~= nil and r.runway ~= nil and r.arena ~= nil and r.today ~= nil and r.today.cap == Plan.REWARDS.dailyGilt, r)
check("an act the hall doesn't know is refused", act(ada, { act = "fly" }).ok == false)
check("a join for something the hall doesn't have is refused", act(ada, { act = "join", what = "casino" }).ok == false)
check("a vote with no number is refused", act(ada, { act = "vote", what = "juke", n = "loud" }).ok == false)

---------------------------------------------------------------------------------------------------
-- 11. The Hall of Fame
---------------------------------------------------------------------------------------------------
local d = data(ada)
d.gilt = 12345
d.gems = 67
d.curios = d.curios or { items = {} }
d.curios.items = { croissantino = 3, chatCouture = 1 }
local figures = HallOfFame.figures(d)
check("the Hall of Fame's figures from the saved record: Gilt and Gems held, brainrots held", figures.gilt == 12345 and figures.gems == 67 and figures.brainrots == 4, figures)
d.owned = { table_oxblood = true, table_rose = true }
check("and Wardrobe pieces owned", HallOfFame.figures(d).cosmetics >= 2)
run(function()
	HallOfFame.submit(ada)
end)
advance(1)
run(HallOfFame.refresh)
advance(1)
local gb = HallOfFame.board("gilt")
check("submitted, then read from every server's board", #gb >= 1 and gb[1].userId == ada.UserId and gb[1].score == 12345, gb)
run(HallOfFame.draw)
local drawnRow = nil
for _, part in H.tagged.HallBoard or {} do
	if part:GetAttribute("Board") == "gilt" then
		local gui = part:FindFirstChildWhichIsA("SurfaceGui")
		drawnRow = gui and gui:FindFirstChild("Name1")
	end
end
check("and drawn on its board in the hall", drawnRow ~= nil and drawnRow.Text == "Ada", drawnRow and drawnRow.Text)
d.settings.showFortune = "Off"
run(function()
	HallOfFame.submit(ada)
end)
advance(1)
run(HallOfFame.refresh)
advance(1)
check("a guest whose Fortune is private is taken off every board", #HallOfFame.board("gilt") == 0)

---------------------------------------------------------------------------------------------------
-- 12. The Exchange: Gilt and Gems in a trade, beside curios
---------------------------------------------------------------------------------------------------
local TradeService = module("ServerScriptService", "Server", "TradeService")
local Policy = module("ServerScriptService", "Server", "Policy")
Policy.lookup = function(_player)
	return { IsPaidItemTradingAllowed = true }
end
TradeService.start()
local tradeAsk = Remotes.funcs.TradeAsk.OnServerInvoke
local function trade(g, request)
	advance(0.5)
	local tr
	run(function()
		tr = tradeAsk(g, request)
	end)
	return tr
end
local function lastTrade(g)
	for i = #g.inbox, 1, -1 do
		if g.inbox[i].op == "trade" then
			return g.inbox[i]
		end
	end
	return nil
end
data(ada).settings.showFortune = "On"
data(ada).gilt = 20000
data(ada).gems = 50
data(bo).gilt = 1000
data(bo).gems = 400
check("Ada asks Bo to trade", trade(ada, { op = "invite", userId = bo.UserId }).ok == true)
check("and Bo accepts", trade(bo, { op = "accept", userId = ada.UserId }).ok == true and lastTrade(ada) ~= nil)
check("the trade screen is told a trade's limits on Gilt and Gems", lastTrade(ada).maxGilt == TradeService.Settings.maxGilt and lastTrade(ada).maxGems == TradeService.Settings.maxGems and lastTrade(ada).gemsLeft == TradeService.Settings.gemsADay)
check("Gilt beyond what a guest holds is refused", trade(bo, { op = "offer", items = { ["$gilt"] = 5000 } }).ok == false)
check("Gilt beyond a trade's limit is refused", trade(ada, { op = "offer", items = { ["$gilt"] = TradeService.Settings.maxGilt + 1 } }).ok == false)
check("half a Gem is refused", trade(ada, { op = "offer", items = { ["$gems"] = 2.5 } }).ok == false)
r = trade(ada, { op = "offer", items = { ["$gilt"] = 5000, ["$gems"] = 10 } })
check("Ada offers Gilt and Gems", r.ok == true)
r = trade(bo, { op = "offer", items = { ["$gems"] = 120 } })
check("more Gems than a trade carries is refused", r.ok == false)
r = trade(bo, { op = "offer", items = { ["$gems"] = 90, ["$gilt"] = 300 } })
check("Bo offers Gems and Gilt", r.ok == true)
local v = lastTrade(ada).version
check("both sides are shown as the server holds them", lastTrade(bo).theirs["$gilt"] == 5000 and lastTrade(bo).theirs["$gems"] == 10 and lastTrade(ada).theirs["$gems"] == 90)
trade(ada, { op = "ready", version = v })
trade(bo, { op = "ready", version = v })
advance(TradeService.Settings.countdown + 0.5)
run(TradeService.tick)
trade(ada, { op = "confirm", version = v })
r = trade(bo, { op = "confirm", version = v })
check("both confirm: the trade is done", r.ok == true, r)
check("the Gilt and Gems moved, both ways, all at once", data(ada).gilt == 20000 - 5000 + 300 and data(bo).gilt == 1000 + 5000 - 300 and data(ada).gems == 50 - 10 + 90 and data(bo).gems == 400 - 90 + 10, data(ada).gilt, data(bo).gilt, data(ada).gems, data(bo).gems)
check("every screen's Gems are up to date", ada:GetAttribute("Gems") == data(ada).gems and bo:GetAttribute("Gems") == data(bo).gems)
check("and the history says what changed hands", data(ada).trades[1].gave[1] == "5,000 Gilt" and data(ada).trades[1].gave[2] == "10 Gems" and data(ada).trades[1].got[1] == "300 Gilt" and data(ada).trades[1].got[2] == "90 Gems", data(ada).trades[1])
check("a day's trades may send only so many Gems", TradeService.gemsLeft(bo) == TradeService.Settings.gemsADay - 90 and TradeService.gemsLeft(ada) == TradeService.Settings.gemsADay - 10)

H.finish()

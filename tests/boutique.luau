--!nocheck
-- (Build 96) The Boutique's new counter against the real server code, on the fake clock: the
-- sorting tables' pieces off sale (kept by whoever has them), the showpiece nameplates and money
-- moves on the shelves, Gilt boosters (prices and times from the list, never the screen; one of
-- each kind; Gilt really doubled), the Brainrot Market (today's four, the exact one, once a day
-- each), the Boutique key's New mark, the money moves' relay, and the nameplate a showpiece frame
-- and a Gem Shop title build.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/boutique.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module, profiles, guest, askAs = H.module, H.profiles, H.guest, H.askAs
local Config, Wardrobe, Boutique, Gilt = H.Config, H.Wardrobe, H.Boutique, H.Gilt
local roblox = H.roblox
local os = { time = H.fakeOs.time, clock = os.clock, date = os.date }

local BoosterList = module("ReplicatedStorage", "Shared", "Boosters")
local CurioList = module("ReplicatedStorage", "Shared", "Curios")
local GemList = module("ReplicatedStorage", "Shared", "GemShop")
local Boosters = module("ServerScriptService", "Server", "Boosters")
local Brainrots = module("ServerScriptService", "Server", "Brainrots")
local Emotes = module("ServerScriptService", "Server", "Emotes")
local Dressing = module("ServerScriptService", "Server", "Dressing")

-- (As Main wires them.)
Gilt.rush = Boosters.giltMult
Gilt.earned = function(player, paid, fromPlay)
	if fromPlay then
		Boosters.earned(player, paid)
	end
end
Boosters.squadRate = function(data)
	return Brainrots.rate(data)
end
Boosters.squad = function(player, data, mult, seconds, cap)
	return Brainrots.overtime(player, data, mult, seconds, cap)
end

---------------------------------------------------------------------------------------------------
-- 1. The sorting tables' pieces: off every shelf, kept by whoever has them
---------------------------------------------------------------------------------------------------
do
	local ada = guest("Ada", 1)
	local d = profiles[ada].Data
	local function hasRetired(list)
		for _, item in list do
			if Wardrobe.Retired[item.kind] then
				return item.id
			end
		end
		return nil
	end
	check("no felt, lamp, card back or chime on the permanent shelf", hasRetired(Wardrobe.alwaysPool()) == nil)
	check("...nor in the daily rotation", hasRetired(Wardrobe.boutiquePool()) == nil)
	check("...nor for Gilt", hasRetired(Wardrobe.giltPool()) == nil)
	for _, season in { "harvest", "frost", "bloom", "solstice" } do
		check("...nor in the " .. season .. " collection", hasRetired(Wardrobe.seasonPieces(season)) == nil)
	end
	check("today's six and the week's two are all still on sale", #Boutique.today() == 6 and #Boutique.featured() == 2 and hasRetired(Boutique.today()) == nil and hasRetired(Boutique.featured()) == nil)
	check("a felt isn't on sale, even its season's", not Boutique.onSale("table_oxblood", "harvest") and not Boutique.onSale("season_harvest_table", "harvest"))
	d.gilt = 100000
	local r = askAs(ada, { op = "buyGilt", item = "table_emerald" })
	check("a felt can't be bought for Gilt any more (and nothing is taken)", r.ok == false and d.gilt == 100000 and not d.owned.table_emerald)
	local r2 = askAs(ada, { op = "buy", item = "table_oxblood" })
	check("...nor for Robux", r2.ok == false and not d.owned.table_oxblood)
	d.owned.table_oxblood = true
	local worn = askAs(ada, { op = "equip", kind = "table", id = "table_oxblood" })
	check("a felt already had is still worn", worn.ok and d.equipped.table == "table_oxblood")
	local shelves = askAs(ada, { op = "shelves" })
	check("the shelves the screen gets have no retired piece either", hasRetired(shelves.today) == nil and hasRetired(shelves.always) == nil and hasRetired(shelves.gilt) == nil)
end

---------------------------------------------------------------------------------------------------
-- 2. Showpieces: nameplates with a sheen, and money moves, at the real Robux tiers
---------------------------------------------------------------------------------------------------
do
	local always = {}
	for _, item in Wardrobe.alwaysPool() do
		always[item.id] = item
	end
	check("Molten Gold and Money Green are always on the shelves", always.plate_molten ~= nil and always.plate_money ~= nil)
	check("...and Make It Rain", always.emote_makeitrain ~= nil)
	for _, id in { "plate_molten", "plate_money", "plate_diamond", "plate_royal", "plate_inferno", "plate_prism", "emote_makeitrain", "emote_goldflex", "emote_dripcheck", "emote_bigbag", "emote_diamondrain" } do
		local item = Wardrobe.get(id)
		check(id .. " is sold at one of the house's Robux tiers (a product that exists)", item ~= nil and table.find(Wardrobe.Tiers, item.robux) ~= nil and item.source == "boutique")
	end
	check("a money move is ready once its Roblox emote is set (the animation every avatar has)", Wardrobe.deliverable(Wardrobe.get("emote_makeitrain")))
	check("...and its card says the effect is the house's and the emote Roblox's", string.find(Wardrobe.get("emote_makeitrain").line, "Roblox's cheer", 1, true) ~= nil)
	check("a gesture that needs its own animation still waits for it", not Wardrobe.deliverable(Wardrobe.get("gesture_bow")))
	check("the Wardrobe calls them Emotes", Wardrobe.KindNames.gesture == "Emotes")
end

---------------------------------------------------------------------------------------------------
-- 3. Boosters for Gilt
---------------------------------------------------------------------------------------------------
do
	local bo = guest("Bo", 3)
	local d = profiles[bo].Data
	d.gilt = BoosterList.byId.rush.gilt - 1
	local short = askAs(bo, { op = "booster", id = "rush" })
	check("a booster you can't afford is refused, and nothing is taken", short.ok == false and short.short == "Gilt" and d.gilt == BoosterList.byId.rush.gilt - 1)
	check("...and nothing runs", Boosters.giltMult(bo) == 1 and bo:GetAttribute("BoosterGiltUntil") == nil)
	local nope = askAs(bo, { op = "booster", id = "free" })
	check("a booster that isn't on the list is refused", nope.ok == false)
	d.gilt = 100000
	local cheat = askAs(bo, { op = "booster", id = "rush", gilt = 1, seconds = 999999, mult = 50 })
	local rush = BoosterList.byId.rush
	check("the price, the time and the strength are the list's, whatever the screen sends", cheat.ok and d.gilt == 100000 - rush.gilt and Boosters.giltMult(bo) == rush.mult)
	local untilAt = bo:GetAttribute("BoosterGiltUntil")
	check("...it runs for its 15 minutes from now, said to the screen", type(untilAt) == "number" and math.abs(untilAt - (os.time() + rush.seconds)) <= 2 and bo:GetAttribute("BoosterGiltUntilId") == "rush")
	-- Gilt really doubles while it runs.
	d.giltDay = { day = math.floor(os.time() / 86400), earned = 0 }
	local paid
	run(function()
		paid = Gilt.pay(bo, d, 100, "test")
	end)
	check("Gilt earned while it runs is doubled", paid == 200, paid)
	local other = askAs(bo, { op = "booster", id = "grand" })
	check("a different Gilt booster waits until the first is done", other.ok == false and string.find(other.why, "Gilt Rush is running", 1, true) ~= nil and d.gilt == 100000 - rush.gilt + 200)
	local again = askAs(bo, { op = "booster", id = "rush" })
	check("the same one again adds its time", again.ok and math.abs(bo:GetAttribute("BoosterGiltUntil") - (untilAt + rush.seconds)) <= 2)
	for _ = 1, 10 do
		askAs(bo, { op = "booster", id = "rush" })
	end
	check("...never more than two hours ahead", bo:GetAttribute("BoosterGiltUntil") - os.time() <= BoosterList.CAP + 1)
	local xp = askAs(bo, { op = "booster", id = "scholar" })
	check("an XP Rush runs alongside (another kind)", xp.ok and Boosters.xpMult(bo) == 2)
	-- Run out.
	advance(BoosterList.CAP + 5)
	check("when its time is up it stops", Boosters.giltMult(bo) == 1 and Boosters.xpMult(bo) == 1)
	local view = askAs(bo, { op = "shelves" }).boosters
	check("the shelf lists every booster with its price and time", view and #view.list == #BoosterList.List and view.list[1].gilt == BoosterList.List[1].gilt)
	-- Squad Overtime: the brainrot jar.
	local sq = askAs(bo, { op = "booster", id = "overtime" })
	local squad = d.curios and d.curios.squad
	check("Squad Overtime sets the squad's jar to three times as fast for an hour", sq.ok and Boosters.running(d, "squad") ~= nil and squad and squad.boostMult == 3 and math.abs(squad.boostUntil - (Brainrots.now() + 3600)) <= 2)
	-- A Meme Frenzy (×2) while Overtime (×3) runs keeps the ×3.
	run(function()
		Brainrots.frenzy(bo)
	end)
	check("...and a Meme Frenzy on top keeps it ×3 (and adds its time)", squad.boostMult == 3)
end

-- What a booster would add, said from the guest's own play this visit (not before five minutes).
do
	local fi = guest("Fi", 9)
	local d = profiles[fi].Data
	d.giltDay = { day = math.floor(os.time() / 86400), earned = 0 }
	run(function()
		Gilt.pay(fi, d, 300, "test")
	end)
	local early = askAs(fi, { op = "shelves" }).boosters.list[1]
	check("no estimate from a minute's play (it would mislead)", early.estimate == nil)
	advance(9 * 60)
	run(function()
		Gilt.pay(fi, d, 600, "test")
	end)
	local view = askAs(fi, { op = "shelves" }).boosters
	local rushView = view.list[1]
	local minutes = 9 + 0.15 / 60
	local expect = math.floor((900 / minutes) * 15 * 1 / 10 + 0.5) * 10
	check("after a while: a Gilt Rush would add about its time at the guest's own pace", rushView.id == "rush" and math.abs((rushView.estimate or 0) - expect) <= 10, rushView.estimate)
	check("...this visit's Gilt from play, said on the shelf", view.session and view.session.gilt == 900)
	run(function()
		Gilt.give(fi, d, 5000, "the squad's jar")
	end)
	check("Gilt handed over as it stands (the squad's jar) isn't counted as play's pace", askAs(fi, { op = "shelves" }).boosters.session.gilt == 900)
end

---------------------------------------------------------------------------------------------------
-- 4. The Brainrot Market
---------------------------------------------------------------------------------------------------
do
	local cy = guest("Cy", 4)
	local d = profiles[cy].Data
	local four = Boutique.market()
	check("four brainrots a day", #four == 4)
	local rarities = {}
	for _, m in four do
		local c = CurioList.byId[m.id]
		table.insert(rarities, m.rarity)
		check(m.id .. " is a brainrot found in play, never a Mythic or Secret", c and c.family == "meme" and c.rarity ~= "Mythic" and c.rarity ~= "Secret")
		check("...at its rarity's fixed price", m.gilt == Boutique.MarketPrice[c.rarity])
	end
	check("one in each band: Common or Uncommon, Rare, Epic, Legendary", (rarities[1] == "Common" or rarities[1] == "Uncommon") and rarities[2] == "Rare" and rarities[3] == "Epic" and rarities[4] == "Legendary")
	local same = Boutique.market()
	check("every server shows the same four today", same[1].id == four[1].id and same[4].id == four[4].id)
	local tomorrow = Boutique.market(os.time() + 86400)
	check("...and they change at midnight", tomorrow[1].id ~= four[1].id or tomorrow[2].id ~= four[2].id or tomorrow[3].id ~= four[3].id or tomorrow[4].id ~= four[4].id)
	local pick = four[2]
	d.gilt = pick.gilt - 1
	local short = askAs(cy, { op = "market", id = pick.id })
	check("not enough Gilt: refused, nothing taken or given", short.ok == false and d.gilt == pick.gilt - 1 and (d.curios == nil or d.curios.items == nil or (d.curios.items[pick.id] or 0) == 0))
	d.gilt = 1000000
	local bought = askAs(cy, { op = "market", id = pick.id, gilt = 1 })
	local held = (d.curios and d.curios.items and d.curios.items[pick.id]) or 0
	check("bought: the exact one shown, at its price (whatever the screen sends)", bought.ok and d.gilt == 1000000 - pick.gilt and held == 1)
	local twice = askAs(cy, { op = "market", id = pick.id })
	check("one of each a day", twice.ok == false and d.gilt == 1000000 - pick.gilt)
	local notToday
	for _, id in { "croissantino", "frogKing", "goldenGoose", "pizzaVolante", "unicornetto" } do
		if Boutique.marketPrice(id) == nil then
			notToday = id
			break
		end
	end
	local r = askAs(cy, { op = "market", id = notToday })
	check("one that isn't at the Market today is refused", r.ok == false)
	check("a Mythic is never sold", askAs(cy, { op = "market", id = "moonCheese" }).ok == false)
	local view = askAs(cy, { op = "shelves" }).market
	local seen
	for _, m in view do
		if m.id == pick.id then
			seen = m
		end
	end
	check("the shelf says it's yours today, and what it earns an hour", seen and seen.bought == true and type(seen.rate) == "number" and seen.rate > 0)
	advance(86400)
	check("tomorrow, the new four can each be had again", askAs(cy, { op = "shelves" }).market[1].bought == false)
end

---------------------------------------------------------------------------------------------------
-- 5. The Boutique key's New mark
---------------------------------------------------------------------------------------------------
do
	local di = guest("Di", 5)
	check("a guest who hasn't looked today sees New on the Shop key", di:GetAttribute("BoutiqueNew") == true)
	askAs(di, { op = "seen" })
	check("opening the Boutique clears it", di:GetAttribute("BoutiqueNew") == nil and profiles[di].Data.boutiqueSeen == Boutique.day())
end

---------------------------------------------------------------------------------------------------
-- 6. Money moves: only the one you own and wear, one every few seconds, to everyone near
---------------------------------------------------------------------------------------------------
do
	local ed = guest("Ed", 6)
	local fan = guest("Fan", 7)
	ed.Character = ed.body
	fan.Character = fan.body
	local d = profiles[ed].Data
	local function emotes(p)
		local n = 0
		for _, m in p.inbox do
			if m.op == "emote" then
				n += 1
			end
		end
		return n
	end
	local played
	run(function()
		played = Emotes.play(ed)
	end)
	check("no money move worn: nothing plays", played == false and emotes(fan) == 0)
	d.equipped.gesture = "emote_makeitrain"
	run(function()
		played = Emotes.play(ed)
	end)
	check("worn but not owned (a screen's claim): nothing plays", played == false and emotes(fan) == 0)
	d.owned.emote_makeitrain = true
	run(function()
		played = Emotes.play(ed)
	end)
	check("owned and worn: everyone near is told which, and who", played == true and emotes(fan) == 1 and emotes(ed) == 1)
	run(function()
		played = Emotes.play(ed)
	end)
	check("...one every few seconds, no more", played == false and emotes(fan) == 1)
	advance(Emotes.GAP + 0.5)
	run(function()
		played = Emotes.play(ed)
	end)
	check("...and again after", played == true and emotes(fan) == 2)
end

---------------------------------------------------------------------------------------------------
-- 7. The nameplate: a showpiece frame and a Gem Shop title stand out
---------------------------------------------------------------------------------------------------
do
	local gi = guest("Gi", 8)
	local d = profiles[gi].Data
	local head = roblox.Instance.new("Part")
	head.Name = "Head"
	local model = roblox.Instance.new("Model")
	head.Parent = model
	gi.Character = model
	d.owned.plate_molten = true
	d.equipped.nameplate = "plate_molten"
	run(function()
		Dressing.nameplate(gi)
	end)
	local gui = head:FindFirstChild("Nameplate")
	check("a showpiece frame: a wider plate that shines on every screen", gui and gui:GetAttribute("Shine") == true and gui.Size.X.Offset >= 230)
	check("...with its colours running round the frame", gui and gui:FindFirstChild("Sweep", true) ~= nil and gui:FindFirstChild("SheenBand", true) ~= nil)
	d.equipped.nameplate = "plate_silver"
	d.owned.plate_silver = true
	run(function()
		Dressing.nameplate(gi)
	end)
	gui = head:FindFirstChild("Nameplate")
	check("a plain frame doesn't shine (but is still framed in its colours)", gui and gui:GetAttribute("Shine") == nil and gui:FindFirstChild("Sweep", true) ~= nil)
	-- A Gem Shop title: its own colour and glyph.
	d.gemShop = { owned = { title_legend = true }, aura = "", title = "title_legend", companion = "", felt = "", trail = "", giltUntil = 0, xpUntil = 0 }
	gi:SetAttribute("Title", GemList.byId.title_legend.name)
	run(function()
		Dressing.nameplate(gi)
	end)
	gui = head:FindFirstChild("Nameplate")
	local title = gui and gui:FindFirstChild("Title", true)
	check("a Gem Shop title wears its glyph either side, and its sheen", title and string.find(title.Text, "🏆", 1, true) ~= nil and title:FindFirstChildOfClass("UIGradient") ~= nil and gui:GetAttribute("TitleShine") == true)
end

H.finish()

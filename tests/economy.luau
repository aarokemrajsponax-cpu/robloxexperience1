--!nocheck
-- (Build 104) The house's Gilt scale (Config.Gilt.payoutScale), at the game's own setting: every
-- reward for playing pays that many times its base figure, the day's soft cap moves with it, and
-- what a screen shows before a reward is earned is exactly what's then paid. Prizes (a Steal a
-- Luxe set, the island's pearls), the Grand Ballroom's daily cap and the Gilt price of a
-- Robux-priced Boutique piece all follow the same scale. Nothing already saved changes.
--
-- Usage (from the repo root):  rojo sourcemap default.project.json -o sourcemap.json
--                              lune run tests/economy.luau

local H = require("./harness")
local check, run, advance = H.check, H.run, H.advance
local module, profiles = H.module, H.profiles
local Config = H.Config

local GAME_SCALE = 10
Config.data.Gilt.payoutScale = GAME_SCALE

local Fortune = module("ReplicatedStorage", "Shared", "Fortune")
local Gilt = module("ServerScriptService", "Server", "Gilt")

check("the game's own Gilt scale is in force here", Fortune.scale() == GAME_SCALE)
check("a base figure at the house's scale", Fortune.scaled(55) == 550 and Fortune.scaled(0) == 0)

local ada = H.guest("Ada", 8101)
ada.Character = ada.body
local data = profiles[ada].Data
data.gilt = 1000
data.giltDay = { day = math.floor(os.time() / 86400), earned = 0 }
local was = data.gilt

-- The pipeline: quote, pay, and the screen's own sum.
local quoted = Gilt.quote(ada, data, 55)
check("a reward of base 55 is quoted at 550 (no boosts running)", quoted == 550, quoted)
Gilt.publish(ada, data)
check("...and a screen works out the very same figure from what the server publishes", Fortune.quoteFor(ada, 55) == quoted, Fortune.quoteFor(ada, 55))
local paid = Gilt.pay(ada, data, 55, "test")
check("...and that's exactly what's paid", paid == quoted and data.gilt == was + quoted)

-- The soft cap moves with the scale: a whole day's base cap of play pays in full at the scale.
data.giltDay = { day = math.floor(os.time() / 86400), earned = 0 }
local cap = Config.data.Gilt.dailySoftCap
local fullDay = Gilt.quote(ada, data, cap)
check("the day's soft cap is at the scale too (a full day's base pays in full)", fullDay == cap * GAME_SCALE, fullDay)
data.giltDay.earned = cap * GAME_SCALE
local past = Gilt.quote(ada, data, 100)
check("...and past it, the reduced rate applies to the scaled reward", past == math.floor(100 * GAME_SCALE * Config.data.Gilt.softCapRate), past)
Gilt.publish(ada, data)
check("...the screen agrees past the cap as well", Fortune.quoteFor(ada, 100) == past)

-- Prizes and caps that follow the scale.
local Attractions = module("ServerScriptService", "Server", "Attractions")
local Island = module("ServerScriptService", "Server", "Attractions", "Island")
local IslandPlan = module("ReplicatedStorage", "Shared", "Island")
local r = Island.rewards(Attractions.ctx)
check("the island's prizes at the scale (the card shows them, the server pays them)", r.pearl == IslandPlan.PEARL_GILT * GAME_SCALE and r.toast == IslandPlan.TOAST_GILT * GAME_SCALE and r.postcards == IslandPlan.POSTCARDS_GILT * GAME_SCALE, r.pearl)

-- A Robux-priced Boutique piece's Gilt price keeps its worth.
local Shop = module("ServerScriptService", "Server", "Shop")
local Wardrobe = module("ReplicatedStorage", "Shared", "Wardrobe")
local item = nil
for _, it in Wardrobe.all or {} do
	if it.source == "boutique" and it.robux then
		item = it
		break
	end
end
if item and Shop.giltAltFor then
	check("a Robux-priced piece's Gilt price follows the scale", Shop.giltAltFor(item) == math.floor(item.robux * Config.data.Gilt.perRobux * GAME_SCALE))
end

-- Nothing saved changes: a balance stays the balance.
local bo = H.guest("Bo", 8102)
local boData = profiles[bo].Data
boData.gilt = 123364
advance(1)
check("a guest's saved Gilt isn't touched by the scale", boData.gilt == 123364)

H.finish()

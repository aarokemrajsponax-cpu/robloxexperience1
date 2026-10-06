--!strict
-- The product catalog: every developer product and game pass the house sells, in one place, with
-- what it gives, its rules, how it's shown and which server handler grants it. Nothing about a
-- product's economics is written anywhere else: gameplay code asks this module.
--
-- Ids. Developer products are found by their exact Name in Creator Hub (see server
-- Purchases/Catalog), so `Id` can stay 0. Game passes can't be listed from inside a game, so a
-- pass's id must be pasted into `Id` (or Config.Products, which wins and can be set live).
--
-- Prices. Roblox owns the real price (set in Creator Hub; it can differ per player under Roblox's
-- price tests). `ReferencePrice` is the price this catalog was designed around: it's shown only
-- when Roblox hasn't answered, and the risk check compares receipts with it (never to refuse one).
--
-- Validated at server start (ProductConfig.validate): a broken entry is switched off and reported
-- on the owner's screen, never sold.

local BarMenu = require(script.Parent.BarMenu)
local Salutes = require(script.Parent.Salutes)
local Wardrobe = require(script.Parent.Wardrobe)

local ProductConfig = {}

export type ProductType = "DeveloperProduct" | "GamePass"
export type Tier = "Entry" | "Medium" | "Premium" | "Prestige"

export type Entry = {
	Key: string, -- stable: saved in profiles, the ledger and analytics
	Name: string, -- exactly as created in Creator Hub (matched ignoring case and spacing)
	ProductType: ProductType,
	Id: number, -- 0: found by Name (developer products) or not on sale yet (game passes)
	Handler: string, -- the server grant handler (Purchases/Grants)
	Fallback: string?, -- a game pass with no id yet is sold as this developer product instead
	Pricing: { ReferencePrice: number, Tier: Tier, Rationale: string },
	Reward: { [string]: any },
	Rules: { [string]: any },
	UX: { DisplayName: string, Category: string, Line: string, Offer: boolean, Order: number, Action: string },
}

---------------------------------------------------------------------------------------------------
-- Settings for the purchase system itself
---------------------------------------------------------------------------------------------------
ProductConfig.Settings = {
	LedgerStore = "MaisonNoir_PurchaseLedger", -- DataStore holding one record per PurchaseId
	LeaseSeconds = 90, -- a server's claim on a receipt it's granting; another may take over after
	LeaseWaitSeconds = 20, -- a receipt claimed elsewhere waits this long for the claim to lapse
	SaveTimeoutSeconds = 30, -- how long a receipt waits for the profile save that holds it
	ProfileWaitSeconds = 15, -- how long a receipt waits for the buyer's profile to open
	ReceiptBinding = "ProcessReceipt", -- or "BindReceiptHandler" (newer API; see MONETIZATION.md)
	ReceiptsKept = 200, -- PurchaseIds kept in each profile (the idempotency marks)
	LedgerOutboxMax = 50, -- ledger records still to be marked Granted, kept in the profile
	DiscoverEverySeconds = 300, -- re-read the experience's developer products this often
	PriceCacheSeconds = 300,
	MaxGiltMultiplier = 10, -- every Gilt boost together (events, Double Gilt, Luck) never exceeds this
	MaxLedgerMultiplier = 6,
	PromptDebounceSeconds = 1, -- the same purchase window asked for again within this: a double click
	ImpressionGapSeconds = 600, -- an offer shown to a guest is counted once in this long
	LuckWriteSeconds = 5, -- God-Mode Luck's time left is written into the profile this often
	AutoUseRetrySeconds = 15, -- credits that start by themselves (a Golden Hour...) are retried this often
	OutboxFlushSeconds = 120, -- ledger records still to be marked Granted are retried this often
	LedgerTries = 3, -- a ledger write is tried this many times (0.75 s, 1.5 s apart) before it waits
	PassConfirmTries = 5, -- a pass bought here is confirmed with Roblox this many times (2, 4, 6... s apart)
}

-- The fraud-and-anomaly check (server Purchases/Risk). It never refuses or swallows a paid
-- receipt: Normal and Review change nothing for the guest; Restricted only pauses *new* prompts.
ProductConfig.Risk = {
	ReviewAt = 3, -- risk points for Review (logged, the owner is told)
	RestrictAt = 6, -- risk points for Restricted (no new purchase prompts for a while)
	RestrictHours = 6,
	RegionHopHours = 2, -- a different country within this long of the last session: +1
	RegionWindowHours = 24,
	ManyRegions = 3, -- this many countries within the window: +2
	VelocityWindowMinutes = 10,
	VelocityCount = 12, -- receipts within the window: +2
	DailyCount = 60, -- receipts within a day: +2
	FailureWindowMinutes = 60,
	FailureCount = 5, -- failed or deferred grants within the window: +1
	PriceTolerance = 0.5, -- a receipt this far from both the live and the reference price: +1
	RegionsKept = 6,
	PurchasesKept = 80,
	FailuresKept = 12,
}

---------------------------------------------------------------------------------------------------
-- The catalog
---------------------------------------------------------------------------------------------------
local list: { Entry } = {}

local function add(e: Entry)
	table.insert(list, e)
end

-- The five new products (see MONETIZATION.md for each one's segment, value and metrics).
add({
	Key = "velocityElite",
	Name = "VIP Velocity Elite",
	ProductType = "GamePass",
	Id = 0, -- paste the game pass id here (or Config.Products.velocityElite)
	Handler = "velocity",
	Fallback = "velocityEliteProduct",
	Pricing = { ReferencePrice = 499, Tier = "Premium", Rationale = "A permanent pass beside the Gold Key: priced as a one-time luxury, not a consumable." },
	Reward = { Type = "Velocity", SpeedMultiplier = 1.5 },
	Rules = { OneTime = true, Stackable = false, CooldownSeconds = 0 },
	UX = { DisplayName = "VIP Velocity Elite", Category = "Status", Line = "Walk and run 1.5× faster through the house, for good, with a gold trail at your heels. Both can be switched off in Settings.", Offer = true, Order = 30, Action = "prompt" },
})
add({
	Key = "velocityEliteProduct",
	Name = "VIP Velocity Elite", -- the same name as the pass: a pass and a product may share one
	ProductType = "DeveloperProduct",
	Id = 0, -- only used when there's no game pass: the same perk, bought once
	Handler = "velocity",
	Pricing = { ReferencePrice = 499, Tier = "Premium", Rationale = "The same as the pass, for experiences without one; a second purchase becomes Boutique credit." },
	Reward = { Type = "Velocity", SpeedMultiplier = 1.5 },
	Rules = { OneTime = true, Stackable = false, CooldownSeconds = 0, DuplicateCredit = "tier499" },
	UX = { DisplayName = "VIP Velocity Elite", Category = "Status", Line = "Walk and run 1.5× faster through the house, for good, with a gold trail at your heels.", Offer = false, Order = 31, Action = "prompt" },
})
add({
	Key = "chronosDefiance",
	Name = "Chronos Defiance",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "revive",
	Pricing = { ReferencePrice = 89, Tier = "Entry", Rationale = "Offered in a ten-second moment: cheap enough to decide at once, repeatable without regret." },
	Reward = { Type = "Revive", Seconds = 15 },
	Rules = {
		WindowSeconds = 10, -- how long the offer stands when the clock runs out
		PromptWaitSeconds = 60, -- the countdown waits this long at most while Roblox's window is open
		ReceiptWaitSeconds = 25, -- after a purchase, how long the table waits for Roblox's receipt
		MaxUsesPerRound = 1,
		MaxUsesPerRun = 3,
		MaxHeld = 5, -- revives kept for later (a receipt that arrived after the moment passed)
		BoardsCountRevivedPoints = false, -- the boards keep the score from before the revive
		Stackable = true,
		CooldownSeconds = 0,
	},
	UX = { DisplayName = "Chronos Defiance", Category = "Survival", Line = "When the clock runs out in a timed room: +15 seconds and your run goes on.", Offer = true, Order = 60, Action = "prompt" },
})
add({
	Key = "emperorsDecree",
	Name = "Emperor's Decree",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "decree",
	Pricing = { ReferencePrice = 249, Tier = "Premium", Rationale = "A moment of fame with your own words: above a Gold Leaf salute, below the Grand Salute." },
	Reward = { Type = "Decree", DisplaySeconds = 8 },
	Rules = {
		MaxLength = 80,
		GlobalGapSeconds = 20, -- between two decrees in one house
		PlayerCooldownSeconds = 120, -- between two of one guest's decrees
		QueueMax = 3, -- decrees waiting their turn in one house
		PendingSeconds = 300, -- a written decree waits this long for its purchase
		MaxHeld = 5,
		Stackable = true,
		CooldownSeconds = 0,
	},
	UX = { DisplayName = "Emperor's Decree", Category = "Social", Line = "Your words, in gold, across every screen in the house for eight seconds.", Offer = true, Order = 40, Action = "compose" },
})
add({
	Key = "godModeLuck",
	Name = "Luck Booster", -- as created in Creator Hub
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "luck",
	Pricing = { ReferencePrice = 399, Tier = "Premium", Rationale = "Personal and stronger than a Golden Hour (250, 2× for everyone): 2.5× for you, twice as long." },
	Reward = { Type = "Luck", Multiplier = 2.5, DurationSeconds = 1800, Systems = { "gilt", "ledger" } },
	Rules = { Stack = "extend", MaxSeconds = 6 * 3600, Stackable = true, CooldownSeconds = 0 },
	UX = { DisplayName = "Luck Booster", Category = "Boost", Line = "2.5× Gilt and 2.5× Ledger pages for 30 minutes of play. Time only runs while you're in the house. Scores are never boosted.", Offer = true, Order = 20, Action = "prompt" },
})
add({
	Key = "megalodonRainmaker",
	Name = "Megalodon Rainmaker",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "rain",
	Pricing = { ReferencePrice = 699, Tier = "Prestige", Rationale = "The top of the ladder: a spectacle for the whole house that pays every guest, bought for status." },
	Reward = { Type = "Rain", ShareGilt = 150, PurchaserBonusGilt = 500, DurationSeconds = 20, MaxRecipients = 60 },
	Rules = { CooldownSeconds = 0, ServerGapSeconds = 120, QueueMax = 2, MaxHeld = 3, Stackable = true },
	UX = { DisplayName = "Megalodon Rainmaker", Category = "Spectacle", Line = "Gold rains on the whole house: every guest gets 150 Gilt, you get 500 more, and everyone sees who made it rain.", Offer = true, Order = 50, Action = "prompt" },
})

-- Time at the Foyer's grand piano: everyone in the Foyer hears you, and the house's music rests
-- while you play. Time is kept in the profile and only runs while you sit at the keys.
for _, session in {
	{ key = "pianoSession1", name = "Piano Session 1 Minute", minutes = 1, price = 99, tier = "Entry" :: Tier },
	{ key = "pianoSession3", name = "Piano Session 3 Minutes", minutes = 3, price = 349, tier = "Medium" :: Tier },
	{ key = "pianoSession5", name = "Piano Session 5 Minutes", minutes = 5, price = 599, tier = "Premium" :: Tier },
	{ key = "pianoSession10", name = "Piano Session 10 Minutes", minutes = 10, price = 899, tier = "Prestige" :: Tier },
} do
	add({
		Key = session.key,
		Name = session.name,
		ProductType = "DeveloperProduct",
		Id = 0,
		Handler = "piano",
		Pricing = { ReferencePrice = session.price, Tier = session.tier, Rationale = "The house's centrepiece, played for the whole Foyer: AJKR's prices, longer sessions cheaper by the minute." },
		Reward = { Type = "Piano", Seconds = session.minutes * 60 },
		Rules = { Stackable = true, CooldownSeconds = 0 },
		UX = {
			DisplayName = if session.minutes == 1 then "1 minute at the piano" else string.format("%d minutes at the piano", session.minutes),
			Category = "Piano",
			Line = "Play the Foyer's grand piano for everyone in the room. Your time only runs while you sit at the keys.",
			-- Offered at the piano itself, not in the Boutique's list.
			Offer = false,
			Order = 60 + session.minutes,
			Action = "piano",
		},
	})
end

-- The Terrace bar's house specials: a treat you hold and enjoy, at the price on the menu. Saved
-- as a credit first (so a receipt is never lost), and served at once. Cosmetic: no score, no Gilt.
for _, special in {
	{ key = "barGoldSpritz", name = "Gold-Leaf Spritz", item = "goldSpritz", price = 25, tier = "Entry" :: Tier, line = "A glowing sparkling spritz with gold leaf, to hold and sip on the Terrace. No alcohol. Cosmetic only." },
	{ key = "barMacaronTower", name = "Macaron Tower", item = "tower", price = 49, tier = "Entry" :: Tier, line = "Twelve macarons in a gold tower, with sparkles while you hold it. Cosmetic only." },
	{ key = "barGrandPlatter", name = "Grand Platter", item = "platter", price = 99, tier = "Medium" :: Tier, line = "A silver platter of sweets: every guest near you is handed a macaron, free. Cosmetic only." },
} do
	add({
		Key = special.key,
		Name = special.name,
		ProductType = "DeveloperProduct",
		Id = 0,
		Handler = "barTreat",
		Pricing = { ReferencePrice = special.price, Tier = special.tier, Rationale = "A small, fun, plainly priced treat; the platter is shared with everyone near." },
		Reward = { Type = "Treat", Item = special.item },
		Rules = { Stackable = true, CooldownSeconds = 0, MaxHeld = 5 },
		UX = { DisplayName = special.name, Category = "Terrace", Line = special.line, Offer = false, Order = 80, Action = "bar" },
	})
end

-- Gems: the house's rare currency, for the Cabinet's curios (each sold at a fixed Gem price, the
-- exact one you choose). Never random. More Gems per Robux in the bigger packs, said plainly.
for _, pack in {
	{ key = "gems1", name = "Gem Pouch", gems = 120, price = 99, tier = "Entry" :: Tier },
	{ key = "gems2", name = "Gem Case", gems = 650, price = 449, tier = "Medium" :: Tier },
	{ key = "gems3", name = "Gem Trunk", gems = 1500, price = 899, tier = "Premium" :: Tier },
} do
	add({
		Key = pack.key,
		Name = pack.name,
		ProductType = "DeveloperProduct",
		Id = 0,
		Handler = "gems",
		Pricing = { ReferencePrice = pack.price, Tier = pack.tier, Rationale = "Gems buy the Cabinet's curios at fixed prices; bigger packs give more per Robux." },
		Reward = { Type = "Gems", Amount = pack.gems },
		Rules = { Stackable = true, CooldownSeconds = 0 },
		UX = { DisplayName = string.format("%s · %d Gems", pack.name, pack.gems), Category = "Gems", Line = string.format("%d Gems, at once. Spend them in the Cabinet on the exact curio you choose.", pack.gems), Offer = false, Order = 90, Action = "gems" },
	})
end

-- Suite spectacles: a show played in your own Suite whenever you choose (each purchase is one
-- show, kept until you play it). Cosmetic only; nothing random.
for _, show in {
	{ key = "spectacleFireworks", name = "Suite Fireworks", price = 49, tier = "Entry" :: Tier, line = "Fireworks over your Suite's terrace for twenty seconds, whenever you choose." },
	{ key = "spectacleMemes", name = "Meme Takeover", price = 79, tier = "Entry" :: Tier, line = "Every meme curio bursts out and bounces round your Suite for twenty seconds." },
	{ key = "spectacleGolden", name = "Golden Transformation", price = 149, tier = "Medium" :: Tier, line = "Your Suite's lights turn gold and gold leaf falls for thirty seconds." },
} do
	add({
		Key = show.key,
		Name = show.name,
		ProductType = "DeveloperProduct",
		Id = 0,
		Handler = "spectacle",
		Pricing = { ReferencePrice = show.price, Tier = show.tier, Rationale = "A show in your own Suite: priced plainly, kept until played." },
		Reward = { Type = "Spectacle", Show = show.key },
		Rules = { Stackable = true, CooldownSeconds = 0, MaxHeld = 10 },
		UX = { DisplayName = show.name, Category = "Suite", Line = show.line, Offer = false, Order = 85, Action = "spectacle" },
	})
end

-- What the house already sold (unchanged prices and rewards, now in the catalog).
add({
	Key = "doubleGilt",
	Name = "Double Gilt",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "doubleGilt",
	Pricing = { ReferencePrice = 998, Tier = "Prestige", Rationale = "The best-value permanent boost; anchors the ladder." },
	Reward = { Type = "DoubleGilt", Multiplier = 2 },
	Rules = { OneTime = true, Stackable = false, CooldownSeconds = 0, DuplicateCredit = "tier599" },
	UX = { DisplayName = "Double Gilt", Category = "Boost", Line = "Every Gilt you earn, doubled, for good. Your purse fills twice as fast.", Offer = true, Order = 10, Action = "prompt" },
})
add({
	Key = "goldenHour",
	Name = "Golden Hour for Everyone",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "goldenHour",
	Pricing = { ReferencePrice = 250, Tier = "Medium", Rationale = "A generous gesture at an entry price; the buyer is announced." },
	Reward = { Type = "GoldenHour", Minutes = 15 },
	Rules = { Stackable = true, CooldownSeconds = 0, MaxHeld = 5 },
	UX = { DisplayName = "Golden Hour for Everyone", Category = "Social", Line = "Double Gilt for every guest in the house for 15 minutes, with your name announced.", Offer = true, Order = 15, Action = "prompt" },
})
for i, amount in { 1000, 5500, 18000 } do
	local names = { "Gilt Purse", "Gilt Chest", "Gilt Vault" }
	local prices = { 97, 299, 799 }
	local lines = { "%s Gilt, at once.", "%s Gilt, at once. More Gilt for each Robux.", "%s Gilt, at once. The most Gilt for each Robux." }
	local formatted = tostring(amount):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	add({
		Key = "giltPurse" .. i,
		Name = names[i],
		ProductType = "DeveloperProduct",
		Id = 0,
		Handler = "gilt",
		Pricing = { ReferencePrice = prices[i], Tier = if i == 1 then "Entry" elseif i == 2 then "Medium" else "Premium", Rationale = "A Gilt bundle; each step up gives more Gilt per Robux." },
		Reward = { Type = "Gilt", Amount = amount },
		Rules = { Stackable = true, CooldownSeconds = 0 },
		UX = { DisplayName = names[i], Category = "Gilt", Line = string.format(lines[i], formatted), Offer = true, Order = 70 + i, Action = "prompt" },
	})
end
add({
	Key = "goldKey",
	Name = "The Gold Key",
	ProductType = "GamePass",
	Id = 0, -- paste the game pass id here (or Config.Products.goldKey)
	Handler = "goldKey",
	Fallback = "goldKeyProduct",
	Pricing = { ReferencePrice = 1999, Tier = "Prestige", Rationale = "The house's membership: rooms, looks and +20% Gilt." },
	Reward = { Type = "GoldKey" },
	Rules = { OneTime = true, Stackable = false, CooldownSeconds = 0 },
	UX = { DisplayName = "The Gold Key", Category = "Status", Line = "+20% Gilt for good, the Study in your Suite, a gold nameplate, and Gold Key looks.", Offer = true, Order = 25, Action = "prompt" },
})
add({
	Key = "goldKeyProduct",
	Name = "The Gold Key",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "goldKey",
	Pricing = { ReferencePrice = 1999, Tier = "Prestige", Rationale = "The Gold Key for experiences without the pass; a second purchase becomes credit." },
	Reward = { Type = "GoldKey" },
	Rules = { OneTime = true, Stackable = false, CooldownSeconds = 0, DuplicateCredit = "tier599" },
	UX = { DisplayName = "The Gold Key", Category = "Status", Line = "+20% Gilt for good, the Study in your Suite, a gold nameplate, and Gold Key looks.", Offer = false, Order = 26, Action = "prompt" },
})
add({
	Key = "goldKeyGift",
	Name = "Gold Key Gift",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "goldKeyGift",
	Pricing = { ReferencePrice = 1999, Tier = "Prestige", Rationale = "The Gold Key's price, given to another guest." },
	Reward = { Type = "GoldKeyGift" },
	Rules = { Stackable = true, CooldownSeconds = 0 },
	UX = { DisplayName = "The Gold Key, as a gift", Category = "Gifts", Line = "Give another guest in the house the Gold Key.", Offer = false, Order = 27, Action = "none" },
})
add({
	Key = "introduction",
	Name = "The Introduction",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "introduction",
	Pricing = { ReferencePrice = 99, Tier = "Entry", Rationale = "A first-week welcome pack; the cheapest way in." },
	Reward = { Type = "Introduction" },
	Rules = { OneTime = true, Stackable = false, CooldownSeconds = 0, FirstDays = 7, DuplicateCredit = "tier99" },
	UX = { DisplayName = "The Introduction", Category = "Welcome", Line = "A first-week welcome: a jacket, a chime and a painting for your Suite.", Offer = false, Order = 5, Action = "prompt" },
})
add({
	Key = "ledger",
	Name = "Leather-Bound Ledger",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "ledger",
	Pricing = { ReferencePrice = 299, Tier = "Medium", Rationale = "The Term's reward track; every page already reached pays out at once." },
	Reward = { Type = "LeatherLedger" },
	Rules = { OneTime = true, Stackable = false, CooldownSeconds = 0, DuplicateCredit = "tier399" },
	UX = { DisplayName = "Leather-Bound Ledger", Category = "Progress", Line = "The Term's premium row of rewards, every page already reached included.", Offer = false, Order = 80, Action = "prompt" },
})
add({
	Key = "season",
	Name = "Season Collection",
	ProductType = "DeveloperProduct",
	Id = 0,
	Handler = "season",
	Pricing = { ReferencePrice = 399, Tier = "Premium", Rationale = "Only in its season (real, recurring scarcity)." },
	Reward = { Type = "SeasonCollection" },
	Rules = { Stackable = false, CooldownSeconds = 0, DuplicateCredit = "tier399" },
	UX = { DisplayName = "Season Collection", Category = "Style", Line = "The season's pieces, sold only in their season.", Offer = false, Order = 81, Action = "prompt" },
})
for _, s in Salutes.List do
	add({
		Key = "salute_" .. s.id,
		Name = "Salute: " .. (if s.id == "goldLeaf" then "Gold Leaf" elseif s.id == "encore" then "Encore" elseif s.id == "chandelier" then "Chandelier" elseif s.id == "fireworks" then "Fireworks" else "Grand Salute"),
		ProductType = "DeveloperProduct",
		Id = 0,
		Handler = "salute",
		Pricing = { ReferencePrice = s.robux, Tier = if s.robux <= 79 then "Entry" elseif s.robux <= 149 then "Medium" else "Prestige", Rationale = "A spectacle for the whole house; no Gilt, no score." },
		Reward = { Type = "Salute", Salute = s.id },
		Rules = { Stackable = true, CooldownSeconds = 0, MaxHeld = 5 },
		UX = { DisplayName = s.name, Category = "Spectacle", Line = s.line, Offer = false, Order = 90, Action = "prompt" },
	})
end
for _, tier in Wardrobe.Tiers do
	add({
		Key = "tier" .. tostring(tier),
		Name = "Boutique " .. tostring(tier),
		ProductType = "DeveloperProduct",
		Id = 0,
		Handler = "boutiqueTier",
		Pricing = { ReferencePrice = tier, Tier = if tier <= 99 then "Entry" elseif tier <= 249 then "Medium" else "Premium", Rationale = "One product per price tier sells every Boutique piece at that price." },
		Reward = { Type = "BoutiqueTier", Tier = tier },
		Rules = { Stackable = true, CooldownSeconds = 0 },
		UX = { DisplayName = "Boutique " .. tostring(tier), Category = "Style", Line = "A Boutique piece at this price.", Offer = false, Order = 100 + tier, Action = "none" },
	})
end

ProductConfig.List = list
ProductConfig.byKey = {} :: { [string]: Entry }
for _, e in list do
	ProductConfig.byKey[e.Key] = e
end

-- A key's entry, or nil.
function ProductConfig.get(key: string): Entry?
	return ProductConfig.byKey[key]
end

-- Names compare ignoring case and repeated spaces ("Emperor's  decree" = "Emperor's Decree").
function ProductConfig.normalName(name: string): string
	return string.lower((string.gsub(name, "%s+", " ")):match("^%s*(.-)%s*$") or name)
end

---------------------------------------------------------------------------------------------------
-- Validation (run by the server at start)
---------------------------------------------------------------------------------------------------
local function positive(n: any): boolean
	return type(n) == "number" and n == n and n > 0 and n < math.huge
end

local function nonNegative(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < math.huge
end

-- Checks each entry's shape and numbers. Returns the problems found, by key ("" for the whole
-- catalog). `handlers` (the server's grant handlers) is checked when given.
function ProductConfig.validate(handlers: { [string]: boolean }?): { [string]: string }
	local problems: { [string]: string } = {}
	local names: { [string]: string } = {}
	local keys: { [string]: boolean } = {}
	for _, e in list do
		local function bad(why: string)
			if not problems[e.Key] then
				problems[e.Key] = why
			end
		end
		if type(e.Key) ~= "string" or e.Key == "" then
			problems[""] = "an entry has no Key"
			continue
		end
		if keys[e.Key] then
			bad("the Key is used twice")
		end
		keys[e.Key] = true
		if type(e.Name) ~= "string" or #e.Name < 2 or #e.Name > 50 then
			bad("Name must be 2 to 50 characters (Roblox's limit for product names)")
		end
		local n = ProductConfig.normalName(e.Name or "")
		-- Two entries may share a Name only across types (the Gold Key pass and product).
		local other = names[e.ProductType .. ":" .. n]
		if other then
			bad("the Name is the same as " .. other .. "'s")
		end
		names[e.ProductType .. ":" .. n] = e.Key
		if e.ProductType ~= "DeveloperProduct" and e.ProductType ~= "GamePass" then
			bad("ProductType must be DeveloperProduct or GamePass")
		end
		if not nonNegative(e.Id) or e.Id ~= math.floor(e.Id) then
			bad("Id must be 0 or a whole number")
		end
		if not positive(e.Pricing and e.Pricing.ReferencePrice) or e.Pricing.ReferencePrice ~= math.floor(e.Pricing.ReferencePrice) then
			bad("ReferencePrice must be a whole number of Robux above 0")
		end
		if handlers and not handlers[e.Handler] then
			bad("no server handler called '" .. tostring(e.Handler) .. "'")
		end
		if e.Fallback ~= nil then
			local f = ProductConfig.byKey[e.Fallback]
			if not f or f.ProductType ~= "DeveloperProduct" or f.Handler ~= e.Handler then
				bad("Fallback must be a developer product with the same handler")
			end
		end
		local dup = (e.Rules :: { [string]: any }).DuplicateCredit
		if dup ~= nil and (type(dup) ~= "string" or ProductConfig.byKey[dup] == nil or ProductConfig.byKey[dup].Handler ~= "boutiqueTier") then
			bad("DuplicateCredit must name a Boutique tier")
		end
		local r: { [string]: any } = e.Reward or {}
		local rules: { [string]: any } = e.Rules or {}
		if r.Type == "Revive" then
			if not positive(r.Seconds) or not positive(rules.WindowSeconds) or not positive(rules.MaxUsesPerRound) or not positive(rules.MaxUsesPerRun) then
				bad("a revive needs Seconds, WindowSeconds, MaxUsesPerRound and MaxUsesPerRun above 0")
			end
		elseif r.Type == "Decree" then
			if not positive(rules.MaxLength) or rules.MaxLength > 200 or not positive(r.DisplaySeconds) or not nonNegative(rules.GlobalGapSeconds) or not nonNegative(rules.PlayerCooldownSeconds) or not positive(rules.QueueMax) then
				bad("a decree needs MaxLength (1-200), DisplaySeconds, QueueMax and cooldowns")
			end
		elseif r.Type == "Luck" then
			if not positive(r.Multiplier) or r.Multiplier <= 1 or r.Multiplier > 5 or not positive(r.DurationSeconds) or not positive(rules.MaxSeconds) or rules.MaxSeconds < r.DurationSeconds then
				bad("luck needs a Multiplier above 1 (at most 5), DurationSeconds, and MaxSeconds no shorter than one purchase")
			end
			for _, system in (r.Systems or {}) :: { any } do
				if system ~= "gilt" and system ~= "ledger" then
					bad("luck may only boost 'gilt' and 'ledger' (never scores)")
				end
			end
		elseif r.Type == "Rain" then
			if not nonNegative(r.ShareGilt) or not nonNegative(r.PurchaserBonusGilt) or not positive(r.DurationSeconds) or not positive(r.MaxRecipients) then
				bad("a rain needs ShareGilt, PurchaserBonusGilt, DurationSeconds and MaxRecipients")
			end
		elseif r.Type == "Piano" then
			if not positive(r.Seconds) or r.Seconds ~= math.floor(r.Seconds) then
				bad("a piano session needs whole Seconds above 0")
			end
		elseif r.Type == "Spectacle" then
			if r.Show ~= e.Key then
				bad("a spectacle's Show must be its own key")
			end
		elseif r.Type == "Gems" then
			if not positive(r.Amount) or r.Amount ~= math.floor(r.Amount) then
				bad("a Gem pack needs a whole Amount above 0")
			end
		elseif r.Type == "Treat" then
			if type(r.Item) ~= "string" or BarMenu.byId[r.Item] == nil or BarMenu.byId[r.Item].product ~= e.Key then
				bad("a treat needs the menu Item it serves")
			end
		elseif r.Type == "Velocity" then
			if not positive(r.SpeedMultiplier) or r.SpeedMultiplier < 1 or r.SpeedMultiplier > 2 then
				bad("SpeedMultiplier must be between 1 and 2")
			end
		elseif r.Type == "Gilt" then
			if not positive(r.Amount) then
				bad("a Gilt bundle needs an Amount above 0")
			end
		elseif r.Type == "BoutiqueTier" then
			if not positive(r.Tier) then
				bad("a Boutique tier needs its Tier")
			end
		end
		if e.UX == nil or type(e.UX.DisplayName) ~= "string" or type(e.UX.Line) ~= "string" then
			bad("UX needs a DisplayName and a Line")
		end
	end
	return problems
end

return ProductConfig

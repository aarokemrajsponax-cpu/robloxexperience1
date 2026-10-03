# Maison Noir — the money, engineered

How every Robux purchase in the house works: five new products (VIP Velocity Elite, Chronos
Defiance, Emperor's Decree, God-Mode Luck, Megalodon Rainmaker) and everything the Boutique
already sold, all on one receipt processor, one purchase ledger and one product catalog.

The code is the source of truth; this file explains it. Every number below lives in
`src/shared/ProductConfig.luau` (products) or `src/shared/Config.luau` (everything else).

---

## 0. Roblox's limits, and what the design does about them

These are the places where a requested mechanism would be unsafe, unsupported or unreliable on
Roblox as it is, and the closest production-safe design used instead.

| # | The limit | Why it matters | What the house does instead |
| --- | --- | --- | --- |
| 1 | **There are no transactions across DataStores.** A profile and a ledger record (or two guests' profiles) can't be written atomically together. | "Write the reward and mark the receipt" can't be one DataStore operation across two stores. | The **buyer's profile is the authority**: the PurchaseId is saved *in the same profile write* as the reward (ProfileStore's session lock means only one server writes it). The ledger is a cross-server **claim and audit trail**, made consistent eventually through an outbox kept in the profile. A gift saves both profiles, each with its own mark, and is acknowledged only when **both** saves have landed. The residual risk (a crash between the two saves of a gift) is in §13. |
| 2 | **`ProcessReceipt` is one callback per server, and a receipt can be delivered again, to any server, at any time.** `NotProcessedYet` is retried when the buyer next joins or buys, not on a timer. | Every step must be safe to repeat, on another server, mid-way through. | Idempotent at every step (§5, §13). A receipt left unresolved waits for Roblox's next delivery; nothing is lost, but a buyer who never returns is never granted (Roblox's policy, not ours). |
| 3 | **`BindReceiptHandler` is newer, and how it coexists with `ProcessReceipt` isn't documented.** | Binding both could process a receipt twice or not at all. | `ProcessReceipt` by default (long-standing, documented). `ProductConfig.Settings.ReceiptBinding = "BindReceiptHandler"` switches to the newer API (it returns `Enum.ReceiptDecision.Processed / NotProcessedYet`) and falls back to `ProcessReceipt` if it isn't available. Never both. |
| 4 | **There's no API for developer-product refunds or chargebacks.** | "Revoke on refund" can't be implemented for consumables. | Consumables are delivered once and recorded in the ledger (support can see them). Game passes are the exception: `UserOwnsGamePassAsync` stops reporting a refunded pass, so VIP Velocity Elite (as a pass) is taken away on the next visit and an `Entitlement revoked` event is logged. |
| 5 | **"Purchase finished" events are not proof of purchase.** `PromptProductPurchaseFinished` / `PromptGamePassPurchaseFinished` only say a window closed. | Granting from them can be spoofed or can double-grant. | Developer products are granted **only** from receipts. A game pass bought in the server is granted only after `UserOwnsGamePassAsync` confirms it (retried, since Roblox can take a moment), and confirmed again on every arrival. The events are used for UX only (the revive window waits while Roblox's window is open). |
| 6 | **A screen can open Roblox's purchase window by itself.** `PromptProductPurchase` works from a LocalScript. | Server-side eligibility rules ("only during the revive window", "at most six hours of Luck") can't stop a purchase; they only decide when *the house* offers one. | **Every receipt is safe whatever the state.** A revive bought outside its moment is kept as a credit; a decree with nothing written waits; Luck beyond six hours is granted in full; a duplicate one-time product becomes Boutique credit; a rain with others waiting joins the line. Paid value is never refused, cut or lost. |
| 7 | **Game passes can't be listed from inside a game.** Developer products can (`GetDeveloperProductsAsync`). | Passes can't be found by name. | Developer products are matched by their exact Creator Hub **name**. The VIP Velocity Elite pass id must be pasted once (`Config.Products.velocityElite`, which can be set live in Creator Hub → Configs). Until then, the same perk is sold as a developer product with the same name. |
| 8 | **`CurrencySpent` can legitimately differ from the list price** (Roblox's price tests and regional pricing), and Studio test purchases spend 0. | Refusing on price would refuse real, paid purchases. | Price is never a reason to refuse. An amount far from **both** Roblox's live price and the catalog's reference price is one weak risk signal (+1), and only when more than 0 was spent. |
| 9 | **`GetCountryRegionForPlayerAsync` is IP geolocation**: travel, VPNs and mobile networks move it; it can fail. VPN detection is not reliable. | A regional rule built on it would punish legitimate players. | Country is a low-weight signal (a different country within two hours: +1; three countries in a day: +2) and can't reach Restricted alone. It never touches receipts. Failures are ignored. The house makes no claim to detect VPNs. |
| 10 | **Text from players must be filtered for its audience**, and accounts with chat restrictions mustn't post free text. Filtering yields and can fail. | An unfiltered or unattributed broadcast breaks Roblox's rules. | `TextService:FilterStringAsync(..., PublicChat):GetNonChatStringForBroadcastAsync()` for the whole server; `TextChatService:CanUserChatAsync` first (no → the house's six preset lines only). A failure **refuses** (never shows unfiltered text). The filtered text is shown to the buyer **before** they pay. |
| 11 | **Character movement is client-authoritative.** | The server can't enforce a walk speed; an exploiter can already change theirs. | The server only sets a `SpeedPerk` attribute for owners; the guest's screen resolves one speed from every effect through `Shared/Speed` (capped at `Movement.maxSpeed`). The perk gives no advantage in anything scored. Server-side movement anti-cheat is out of scope. |
| 12 | **"Server-wide" can only mean one server.** Cross-server broadcast (MessagingService) is size-limited, rate-limited and not guaranteed. | A global decree or rain would be unreliable and floodable. | Decrees and rains reach **everyone in the buyer's server**, which is what the products say ("the whole house"). |
| 13 | **DataStore keys are at most 50 characters**, and requests are throttled. | A long PurchaseId would make the ledger fail forever; a busy server could be throttled. | Ledger keys are `p_<PurchaseId>`, or a 64-bit hash for an id over 48 characters (the record keeps the full id). About two ledger writes per purchase (claim, mark Granted); a deferral is noted once per server, not on every retry. |
| 14 | **AnalyticsService custom events read only three breakdown fields** (`CustomField01..03`; any other key is dropped silently) and allow about 8,000 combinations per experience. | Named fields would vanish; free-form values would blow the limit. | One schema: product key, outcome/reason (a fixed vocabulary) and segment (3 values). `Analytics.fields` maps them onto the three keys (this also fixed the house's older custom events, which used named keys). |
| 15 | **Paid random items** (anything that sells a chance) carry disclosure rules and are restricted in some places. | A "luck" product that changed drop odds would be a paid random item. | God-Mode Luck boosts **only Gilt and Ledger points**, deterministically, never Mythic odds or anything random, and validation refuses any other system. |
| 16 | **God-Mode Luck "server timestamps":** wall-clock expiry would spend paid time while the buyer is offline or after a crash. | A crash or a disconnect would eat what was paid for. | The profile stores the **seconds of play left**; the server counts it down on its own clock while the guest is in the house, writing it back every few seconds and on leaving. The client never supplies a time. (A wall-clock version is a one-line change if ever wanted.) |

---

## 1. Architecture overview

```
   guest's screen                                    Roblox
   ──────────────                                    ──────
   Boutique / Perk chips / Decree / Revive   ──ask──▶  (server) Store.prompt ──▶ Prompt…Purchase
        ▲  (key only; never a price,                       │ eligibility, risk, debounce
        │   an amount or an id)                            ▼
        │                                           Roblox's purchase window
        │                                                  │ receipt (any server, any time,
        │                                                  ▼  maybe more than once)
        │                                           Receipts.process
        │                                             1 read & validate
        │                                             2 catalog: key for ProductId (or wait)
        │                                             3 buyer & profile (session-locked)
        │                                             4 marked already? → finish / ack
        │                                             5 Ledger.claim (UpdateAsync + lease)
        │                                             6 Risk.onReceipt (never refuses)
        │                                             7 Grants.run (transaction, rollback)
        │                                             8 mark + outbox → save → wait for it
        │                                             9 Ledger.finalize → "granted"
        │                                            10 after-work (effects, credits spent)
        └────── "Purchase" remote: perks, notices, decrees, rains ◀─┘
```

* **Products** are data (`ProductConfig`), validated at start; a broken entry is switched off
  and reported on the owner's screen, never sold.
* **Rewards** are granted in exactly one place (`Receipts` → `Grants`), as transactions.
* **Effects that touch the world** (a revive, a decree, a rain, a salute, a Golden Hour) are
  granted as durable **credits** and spent *after* Roblox has been told; a crash or a closed
  window never loses one.
* **The client** only ever names a product key and shows what the server sends.

---

## 2. Folder and module structure

```
src/shared/
  ProductConfig.luau      the catalog: every product, its price tier, reward, rules, UX; validation
  Speed.luau              the one walking-speed formula (base × event × perk, capped)
  Config.luau             RemoteLimits, Movement.maxSpeed, Products (ids, live-settable)
  Settings.luau           "Your perks": VIP Velocity Elite speed and trail switches
  Remotes.luau            + "Purchase" (server → client) and "PerkAsk" (client → server)
src/server/
  RemoteGuard.luau        rate limits and argument checks for every client → server remote
  Purchases/              (a folder module: init.luau is `Purchases`)
    init.luau             start-up and wiring; the PerkAsk remote
    Catalog.luau          ids (found by name / pasted / live), prices, validation, ambiguity
    Store.luau            purchase prompts; per-product eligibility; impressions
    Receipts.luau         the receipt processor; commit-and-wait; the outbox
    Ledger.luau           DataStore "MaisonNoir_PurchaseLedger": claim / finalize / fail / note
    Grants.luau           handler registry; transactions with snapshot and rollback; after-work
    Perks.luau            credits; auto-use; the perk state sent to screens
    Risk.luau             Normal / Review / Restricted
    Telemetry.luau        the analytics schema and a short in-memory history
    Velocity.luau  Revive.luau  Decree.luau  Luck.luau  Rain.luau     the five products
  Shop.luau               the Boutique's own products' handlers and eligibility; Boutique requests
  TableService.luau       Chronos Defiance's window at timed tables (the table owns the moment)
  Gilt.luau, LedgerService.luau   God-Mode Luck hooks (personal multiplier, capped)
src/client/
  Perks.luau              the perk state and purchase messages, as the server sent them
  UI/RevivePanel.luau     the revive card (the real window, counted down)
  UI/DecreePanel.luau     write → check (filtered preview) → proclaim
  UI/DecreeBanner.luau    the banner every screen shows (decrees and rains)
  UI/PerkChips.luau       Luck's time left; decrees, revives and rains held
  World/RainView.luau     the gold shower
tests/
  harness.luau            the fake Roblox the money tests run in
  purchases.luau          this system, 157 checks (§14)
  shop.luau               the Boutique on top of it, 244 checks
```

---

## 3. ProductConfig

One entry per product (`src/shared/ProductConfig.luau`):

```lua
{
  Key = "chronosDefiance",           -- stable forever: saved in profiles, the ledger, analytics
  Name = "Chronos Defiance",         -- exactly as created in Creator Hub (case and spaces ignored)
  ProductType = "DeveloperProduct",  -- or "GamePass"
  Id = 0,                            -- 0: found by Name (products) / pasted (passes)
  Handler = "revive",                -- the server grant handler
  Fallback = nil,                    -- a pass with no id yet is sold as this product instead
  Pricing = { ReferencePrice = 49, Tier = "Entry", Rationale = "..." },
  Reward = { Type = "Revive", Seconds = 15 },
  Rules = { WindowSeconds = 10, PromptWaitSeconds = 60, ReceiptWaitSeconds = 25,
            MaxUsesPerRound = 1, MaxUsesPerRun = 3, MaxHeld = 5,
            BoardsCountRevivedPoints = false, Stackable = true, CooldownSeconds = 0 },
  UX = { DisplayName = "Chronos Defiance", Category = "Survival", Line = "...",
         Offer = false, Order = 60, Action = "none" },   -- "prompt" | "compose" | "none"
}
```

**Ids.** `Config.Products[key]` (live) wins, then `Id`, then the developer product found with
this `Name`. Two products resolving to one id are both treated as unknown and reported.

**Validated at start** (`ProductConfig.validate`, run by `Catalog.validate`): keys unique;
names 2–50 characters (Roblox's limit) and unique per type; id a whole number; reference price a
whole number above 0; a registered handler; a `Fallback` that is a developer product with the
same handler; a `DuplicateCredit` that names a Boutique tier; and per type: a revive's seconds
and limits, a decree's length (1–200), display time and queue, Luck's multiplier (>1, ≤5),
duration, cap and systems (**only `gilt` and `ledger`**), a rain's amounts, a speed multiplier
between 1 and 2. A failing entry is switched off (never prompted; its receipts wait, §12).

### The five

| | VIP Velocity Elite | Chronos Defiance | Emperor's Decree | God-Mode Luck | Megalodon Rainmaker |
| --- | --- | --- | --- | --- | --- |
| Key | `velocityElite` (+ `velocityEliteProduct`) | `chronosDefiance` | `emperorsDecree` | `godModeLuck` | `megalodonRainmaker` |
| Type | Game Pass (or the same as a one-time developer product) | Developer Product | Developer Product | Developer Product | Developer Product |
| Reference price · tier | 499 · Premium | 49 · Entry | 149 · Medium | 199 · Medium | 699 · Prestige |
| Why that price | a permanent perk beside the Gold Key (499): a one-time luxury | decided in ten seconds: cheap enough to say yes at once, repeatable without regret | a moment of fame with your own words: above a Gold Leaf salute (49), below the Grand Salute (399)… | personal and bigger than a Golden Hour (99, 2× for everyone): 2.5× for you, twice as long | the top of the ladder: spectacle that pays every guest, bought for status |
| Reward | 1.5× walk and run speed + a gold trail, for good | +15 s on the clock, the run goes on | your words in gold on every screen in the server for 8 s | 2.5× Gilt and Ledger points for 30 min of play | every guest +150 Gilt; you +500; a 20 s gold shower and banner |
| Duration | permanent | one use | 8 s on screen | 30 min of play time | 20 s |
| Stack / refresh | one flag; a second purchase becomes Boutique credit (499) | credits stack (kept for later runs) | credits stack | **extends** by the full 30 min each purchase | credits stack; rains queue |
| Eligibility (when it's offered) | not owned | only in the server's revive window (timed rooms; ≤1 per round, ≤3 per run) | a written decree waiting; not on cooldown; queue not full | the house doesn't offer more than 6 h held at once | fewer than 2 rains waiting in the server |
| Cooldowns | — | — | 20 s between decrees in a server; 120 s between one guest's | — | 120 s between rains in a server |
| UI | Boutique → Offers; Settings → Your perks | the revive card at the table | Boutique → Offers → *Write it*; a chip when one is held | Offers (with time left); a chip with a live countdown | Offers; the banner and shower for everyone |
| Server handler | `velocity` | `revive` | `decree` | `luck` | `rain` |

Every product's telemetry, failure behaviour and abuse notes are in §11–§15; the Boutique's older
products (Double Gilt, purses, Golden Hour, the Gold Key, salutes, Boutique tiers, the Ledger,
the Introduction, the season) are in the same catalog with their existing prices.

### Economy and UX, product by product

**VIP Velocity Elite.** *Segment:* explorers and socialisers who cross the (now bigger) house
often; returning players. *Value:* time saved walking, plus a quiet status mark (the gold
trail). *Context:* the Offers page, beside the Gold Key. *Hierarchy:* name, one line, Roblox's
price, one key. *Feedback:* the speed changes at once, the trail appears, a notice says both can
be switched off. *Cross-sell:* the Gold Key (same tier). *Retention:* the house is easier to
roam, so more of it is visited. *Frustration points:* too fast for some → two separate switches
in Settings → Your perks; motion → the trail is thin and short. *Abuse risks:* none new (speed is
client-side anyway, §0.11); nothing scored. *Metrics:* impression → prompt → owned; switch-off
rate (Setting changed events); revocations; session length of owners vs others.

**Chronos Defiance.** *Segment:* competitive players in the timed rooms. *Value:* keeping a good
run alive. *Context:* the moment the clock runs out (the highest intent there is) — and only
then. *Hierarchy:* the real countdown, what it gives (+15 s), what it costs (or "Use a revive (n
held)"), and an equally visible *Bank the run*. *Feedback:* the clock refills, a short toast.
*Cross-sell:* none in that moment (one decision at a time). *Retention:* fewer rage-quits on a
near miss. *Frustration points:* "pay to win" → the boards keep the score from before the revive
(Gilt counts the whole run), said on the card; a slow purchase window → the countdown waits while
Roblox's window is open and says so; a slow receipt → the table waits 25 s, then the revive is
kept for the next run and the guest is told. *Abuse risks:* buying outside the window (§0.6) →
credit kept; spamming → one per round, three per run. *Metrics:* offers, offer → prompt, prompt →
receipt, revives used per run, late receipts (credits kept), run length after a revive.

**Emperor's Decree.** *Segment:* social and expressive players, streamers, groups of friends.
*Value:* attention, with your own words. *Context:* Offers → *Write it*, and a chip while one is
held. *Hierarchy:* write → *Check my words* (the filtered text, exactly as it will appear) →
*Proclaim* with Roblox's price; six house lines below. *Feedback:* a gold banner on every screen
headed "Decree of Name (@username)". *Cross-sell:* salutes (spectacle without words).
*Retention:* social presence. *Frustration points:* the filter → the preview is shown before
paying; a busy house or a cooldown → said before the purchase window, never after. *Abuse
risks:* spam (two cooldowns, a 3-deep queue, 8 s on screen, one banner at a time); impersonation
(the heading is the server's: display name and @username, fixed styling, no custom colours or
fonts); offensive content (Roblox's broadcast filter; text that is mostly filtered is refused;
accounts that can't chat use presets only); flooding (one at a time with a 20 s gap); moderation
(every decree logged with user id, name, text, time and server to `MaisonNoir_DecreeLog`).
*Metrics:* compose → proclaim, filter refusals, decrees per server-hour.

**God-Mode Luck.** *Segment:* progression players (Gilt, the Ledger). *Value:* faster
progress for half an hour of play. *Context:* Offers, with "Active: N minutes of play left" when
running; a chip with the live countdown. *Feedback:* payouts are visibly 2.5×. *Cross-sell:*
Double Gilt (permanent, 2×) is the anchor above it. *Retention:* longer sessions while it runs.
*Frustration points:* "my time ran out while I was away" → time only runs in the house;
stacking → each purchase adds the full 30 minutes (said in the line). *Abuse risks:* economy
inflation → every Gilt boost together is capped at 10×, Ledger at 6×; never scores or odds.
*Metrics:* purchases, repeat interval, Gilt sources while active, expiries.

**Megalodon Rainmaker.** *Segment:* high spenders who buy for status and generosity. *Value:*
spectacle, recognition, and making everyone richer. *Context:* Offers (Prestige tier).
*Feedback:* "NAME triggered MEGALODON RAIN!" on every screen, a 20 s gold shower, "+150 Gilt from
NAME's rain" for each guest. *Cross-sell:* Golden Hour for Everyone. *Retention:* reciprocity;
guests who arrive during the rain get a share. *Frustration points:* waiting → "Your rain is next
in line" (a chip and a notice); the purchase isn't offered when two rains are already waiting.
*Abuse risks:* alt accounts joining for shares → 150 Gilt, once per account per rain, at most 60
guests (≤ 9,000 Gilt per 699 Robux). *Metrics:* rains per day, recipients per rain, Gilt
injected, repeat buyers.

**Honesty rules (all products).** Every price on screen is Roblox's, read by the server; Roblox's
own confirmation window always follows. No invented scarcity, countdowns or social proof: the
only countdowns are real server windows (the revive, Luck's time, events), the only "waiting"
counts are real queues. One-time products are hidden once owned; a duplicate is never lost.

---

## 4. The ledger

DataStore **`MaisonNoir_PurchaseLedger`**, one record per receipt, key `p_<PurchaseId>` (or
`h_<hash>` for an id over 48 characters). Every write is an `UpdateAsync`, tagged with the
buyer's user id (Roblox's data-erasure tooling can find it).

```lua
{ v = 1, id = "<PurchaseId>", state = "Pending" | "Granting" | "Granted" | "Failed",
  playerId, productId, key, spent, firstSeen, updated, server = "<JobId>",
  leaseUntil, attempts, grantedAt?, reason?, risk? }
```

```
(none) ──claim──▶ Granting ──finalize──▶ Granted (terminal)
   │                │  ▲
   │ note           │ fail (handler error; lease dropped)
   ▼                ▼  │ claim (retry)
 Pending ──claim──▶ Failed
```

* **claim** — refused if Granted, or if another server holds a live lease (`leaseUntil` in the
  future, 90 s). A lapsed lease (a server that crashed mid-grant) is taken over; `attempts`
  counts them.
* **finalize** — Granted, after the reward is saved. If the write fails, the entry waits in the
  buyer's profile (`ledgerOutbox`) and is retried on arrival and every two minutes.
* **fail / note** — the reason is kept for support (a handler error, `unknown_product`,
  `product_disabled`, `profile_not_loaded`). A note is written once per server per reason.

In Studio without API access the ledger lives in memory (`Ledger.mock`).

---

## 5. The receipt processor (`Purchases/Receipts.luau`)

1. **Read.** `PlayerId`, `ProductId` (whole, > 0), `PurchaseId` (1–100 characters),
   `CurrencySpent` (≥ 0), `CurrencyType` (Robux, when present). Malformed → logged, unresolved.
2. **Catalog.** The ProductId's key, rebuilt on every receipt (live ids can change). Unknown or
   ambiguous → noted, reported to the owner, **unresolved**: never a default reward. A product
   switched off at start → the same.
3. **Buyer.** Not in this server → unresolved (Roblox delivers it when they join). Profile not
   open within 15 s → unresolved.
4. **Already granted?** The PurchaseId is in the profile → if this server is still waiting for
   that grant's save, finish waiting; otherwise acknowledge (a replay; logged). Granted only once
   the saved copy holds it.
5. **In flight here?** The same PurchaseId being processed on this server → unresolved for now.
6. **Claim** the ledger record. Another server's live lease: wait up to 20 s for it to lapse,
   then re-check the profile and claim again; still busy → unresolved. Ledger says Granted but
   the profile doesn't → acknowledged, **not granted again**, logged and reported.
7. **Risk.** Counted; never stops a receipt.
8. **Grant.** The handler runs as a transaction (§6). An error rolls everything back; the ledger
   says Failed; unresolved.
9. **Commit.** Purchase counted, PurchaseId added (last 200 kept; the ledger covers older
   replays), outbox entry added, gift marks added to touched profiles. Each profile is saved and
   the processor **waits until each saved copy holds its mark** (up to 30 s). Not saved →
   unresolved; the reward stays in memory, so the retry only waits for the save.
10. **Finalize** the ledger, log Granted (and Repeat), then run the handler's after-work.

Decision: `PurchaseGranted` (or `ReceiptDecision.Processed`) only after step 9 succeeded;
otherwise `NotProcessedYet`. The whole step 6–10 is `pcall`-guarded.

---

## 6. Handlers (`Purchases/Grants.luau`)

A handler gets a context: `player`, `data` (their profile), `product` (the catalog entry),
`purchaseId`, `spent`, `risk`, and two methods:

* `ctx:touch(otherPlayer)` → another guest's profile, snapshotted and included in the commit
  (gifts). Their save must land too.
* `ctx:after(fn)` → work for after acknowledgement (effects, messages, spending credits).

Before the handler runs, every touched profile is deep-copied; if it errors, each is restored in
place and nothing is saved or acknowledged. After-work runs step by step, each guarded.

| Handler | Grants (saved with the receipt) | After acknowledgement |
| --- | --- | --- |
| `velocity` | `perks.velocity = true`, or Boutique credit if already owned | speed attribute, trail, notice |
| `revive` | +1 revive credit | spent at once if the table's window is open; else "kept for your next run" |
| `decree` | +1 decree credit | posted at once if one is written and the house isn't busy; else "kept"/"ready" |
| `luck` | +30 min to `perks.luck.remaining` (and the live countdown, in the same step) | screen state, notice |
| `rain` | +500 Gilt to the buyer, +1 rain credit | joins the line; starts when the sky is free |
| Boutique: `boutiqueTier`, `goldKeyGift` | the chosen piece (or a gift via `touch`), else credit | handover by the Concierge, notices |
| `gilt`, `doubleGilt`, `goldKey`, `introduction`, `ledger`, `season` | the reward, or credit if already held | notices, nameplate, screen state |
| `goldenHour`, `salute` | +1 credit | spent at once (auto-use), retried every 15 s and on arrival |

Credits spent on something everyone sees (a rain, a salute, a Golden Hour) save the profile
straight away, so a crash can hardly bring one back to be spent twice (§13).

---

## 7. The regional risk check (`Purchases/Risk.luau`)

Signals the server sees for itself (never a country, price or flag from a screen):

| Signal | Points |
| --- | --- |
| a different country (Roblox's `GetCountryRegionForPlayerAsync`) within 2 h of the last session | +1 |
| 3 or more countries within 24 h | +2 |
| 12 or more receipts within 10 min | +2 |
| 60 or more receipts within a day | +2 |
| 5 or more failed/deferred grants within an hour | +1 |
| an amount far (±50%) from both Roblox's live price and the catalog's, with Robux spent | +1 |

**Normal** (< 3) and **Review** (3–5) change nothing for the guest; Review is logged and the
owner warned. **Restricted** (≥ 6) pauses *new* purchase prompts for 6 hours with a neutral
message ("Purchases are paused on this account for a little while. Anything you've bought is
safe and yours."). Receipts are **always** processed in every state: a paid purchase is never
swallowed or refused because of risk. Thresholds in `ProductConfig.Risk`.

---

## 8. Remote security (`server/RemoteGuard.luau`)

Every client → server remote goes through the guard: a token bucket per guest per remote
(`Config.RemoteLimits`), argument validators, and errors kept on the server.

| Remote | rate / s | burst | Remote | rate / s | burst |
| --- | --- | --- | --- | --- | --- |
| ShopAsk | 8 | 16 | Setting | 8 | 20 |
| PerkAsk | 3 | 6 | Funnel | 2 | 6 |
| Table / duel / ballroom | 30 | 45 | QuickSit | 0.5 | 3 |
| DialogueChoice | 3 | 6 | GetBoard | 1 | 4 |
| Tour | 1 | 4 | Salute | 1 | 3 |
| AdminAsk | 6 | 12 | (default) | 4 | 8 |

* Validators: `number(v, min, max, whole)`, `string(v, maxBytes)` (valid UTF-8, no control
  characters), `oneOf`, `message(v, maxKeys, depth)`.
* Refused traffic is logged (`Shop: Remote rejected`, at most once a minute per guest per remote).
* **What a screen can send to buy:** a product **key** from the catalog's offers (`UX.Offer` and
  `Action = "prompt"`), or its own request type (a Boutique piece, a gift, a revive, a decree's
  words). Never a price, an amount, a product id, a multiplier, an ownership claim or a flag;
  extra fields are ignored.
* Remote names are not secret and are not a defence; every remote is assumed to be called by
  exploit tools with any arguments at any rate.

---

## 9. Client purchase UI

* **Boutique → Offers** (`BoutiquePanel`): the server's list (`Shop.offers`): only what's on
  sale, never what's owned, in the catalog's order, with Roblox's price, a status line (Luck's
  time left, a rain waiting) or why it can't be bought right now. *Write it* opens the decree
  panel; everything else asks the server to prompt.
* **Revive card** (`RevivePanel`): opened by the table's `reviveOffer`; the countdown is the
  server's window; keys *Revive · price* or *Use a revive (n held)*, and *Bank the run*.
* **Decree panel** (`DecreePanel`): text box with a live count to 80; *Check my words* returns the
  filtered text; *Proclaim* only appears after that, with the price or the decrees held.
* **Perk chips** (`PerkChips`): top right while walking (hidden at the table): Luck's countdown,
  "A decree to write", "Revives kept", "Your rain is next in line".
* **Banners** (`DecreeBanner`) and the shower (`RainView`) for everyone in the server.
* **Settings → Your perks**, shown only to owners: VIP Velocity Elite speed and trail.

---

## 10. Server → client message model

`Purchase` remote (server → client):

| op | To | Fields |
| --- | --- | --- |
| `perks` | the guest | `credits`, `luck {remaining, multiplier, systems}`, `velocity {owned, speed, aura, multiplier}`, `revive {held, seconds, window, boardsCountRevived}`, `decree {held, cooldown, queue, maxLength}`, `rain {held, position, falling?, nextIn}` |
| `notice` | the guest | `title`, `line` |
| `decree` | everyone | `id`, `name`, `user`, `text` (filtered), `seconds` |
| `rain` | everyone | `id`, `by`, `user`, `userId`, `share`, `seconds`, `line` |
| `rainShare` | the guest | `id`, `gilt`, `by` |

`Table` remote additions: `reviveOffer` / `reviveUpdate` (`left`, `prompting`, `waitingReceipt`,
`held`, `price`, `onSale`, `add`, `boardsCount`, `score`, `boardScore`, `used`, `usesLeft`,
`why`), `revived` (`clock`, `held`, `used`, `boardScore`); `banked` gains `boardScore` and
`revives`. Client → server: `Table {op = "revive" | "noRevive"}`; `PerkAsk {op = "state" | "buy"
(key) | "decree" | "decreeCompose" (text or preset) | "decreeProclaim"}`.

---

## 11. Logging and analytics

Every purchase event is one `AnalyticsService:LogCustomEvent` with a value and three fields:
`CustomField01` = product key, `CustomField02` = outcome or reason, `CustomField03` = segment
(`new` / `repeat` / `patron`: 0, 1–4, 5+ purchases). Problems also go to the server log, which
the owner sees on screen.

| Event | Value | Outcome/reason vocabulary |
| --- | --- | --- |
| `Shop: Impression` | — | `offers` (once per guest per offer per 10 min) |
| `Shop: Prompt opened` | price | `offers`, `perks`, `shelf`, `gift`, `revive`, `compose`, `salute`, ... |
| `Shop: Prompt closed` | — | `bought`, `closed` (informational only) |
| `Shop: Prompt refused` | — | `not_on_sale`, `restricted`, `ineligible`, `prompt_failed` |
| `Shop: Receipt granted` | Robux spent | risk state at the time; `after_retry` |
| `Shop: Receipt deferred` | Robux | `unknown_product`, `product_disabled`, `profile_not_loaded`, `claimed_elsewhere`, `ledger_unavailable`, `save_pending`, `in_flight` |
| `Shop: Grant failed` | Robux | `handler_error`, `processor_error` |
| `Shop: Duplicate prevented` | Robux | `replayed`, `ledger_granted` |
| `Shop: Repeat purchase` | Robux | times bought before (1–10) |
| `Shop: Product used` | 1 / recipients | `credit`, `rain_started` |
| `Shop: Product expired` | — | `time_up` |
| `Shop: Entitlement revoked` | — | `not_owned` |
| `Shop: Risk signal` | points | `Review:…`, `Restricted:…` |
| `Shop: Validation failed` | — | `bad_player_id`, `bad_product_id`, `bad_purchase_id`, `bad_amount`, `not_robux` |
| `Shop: Remote rejected` | — | `rate`, `malformed` (product field = remote name) |
| `Shop: Ledger write failed` | Robux | `finalize` |

**Metrics to watch** (Creator Hub → Analytics → Custom events): funnel per product (Impression
→ Prompt opened → Prompt closed: bought → Receipt granted); payer conversion and ARPPU by segment;
repeat rate; **health**: Grant failed ≈ 0, Deferred by reason, Ledger write failed, Duplicate
prevented; risk Review/Restricted counts; Remote rejected by remote; product-specific: revives
used per run, decrees per server-hour, rains per day and recipients, Luck expiries, Velocity
switch-offs and revocations; economy sources (Gilt from Purchase, Rain, Ledger).

---

## 12. Failure and retry matrix

| What fails | Roblox is told | The guest | Recovery |
| --- | --- | --- | --- |
| Malformed receipt | NotProcessedYet | nothing granted | logged; never granted |
| Unknown / ambiguous ProductId | NotProcessedYet | nothing granted | owner told; granted on a later delivery once the product is in the catalog |
| Product switched off (broken entry) | NotProcessedYet | — | owner told; granted after the entry is fixed and the server restarts |
| Buyer not in this server | NotProcessedYet | — | Roblox delivers on their next join |
| Profile not open (loading, or still held by their last server) | NotProcessedYet | — | next delivery |
| Ledger unavailable at claim | NotProcessedYet | — | next delivery |
| Another server holds a live claim | NotProcessedYet (after ≤ 20 s wait) | — | that server finishes it, or its lease lapses and a retry takes over |
| Handler error | NotProcessedYet | nothing changes (rolled back) | ledger Failed with the reason; retried on next delivery |
| Profile save doesn't land in 30 s | NotProcessedYet | reward already in memory | the retry waits for the save; never granted twice |
| Ledger can't be marked Granted | **PurchaseGranted** (the reward is saved) | granted | outbox retried on arrival and every 2 min |
| Crash after the save, before Roblox is told | — | granted (saved) | next delivery: PurchaseId found → acknowledged |
| Crash after acknowledgement, before after-work | PurchaseGranted | credit saved | auto-use credits resume on next arrival; revives/decrees/rains wait as credits |
| Revive bought, receipt after the window | PurchaseGranted | "kept for your next run" | the credit is offered at the next clock-out |
| Decree bought, nothing written / house busy | PurchaseGranted | "ready" / "kept for you" | written and proclaimed later without paying again |
| Rain bought while another falls | PurchaseGranted | "next in line" | starts after the gap; follows the buyer to another server |
| Text filter fails | — | "couldn't read that just now" | try again; nothing shown unfiltered |
| `CanUserChatAsync` fails | — | presets only | — |
| `GetCountryRegionForPlayerAsync` fails | — | — | that session has no country |
| `UserOwnsGamePassAsync` fails | — | the saved flag stands | checked again next arrival |
| Prompt can't open | — | "couldn't open; try again" | — |
| `BindReceiptHandler` missing | — | — | falls back to ProcessReceipt; owner told |

---

## 13. Concurrency and idempotency

**Layers that stop a double grant:**
1. **The profile mark** (authoritative). Saved in the same profile write as the reward; ProfileStore's
   session lock lets one server write the profile at a time; the processor acknowledges only
   when `LastSavedData` (what actually landed) holds the mark. If another server stole the
   session, this server's save doesn't land, so it never acknowledges.
2. **The ledger claim** (cross-server). `UpdateAsync` is atomic per key: of two servers claiming
   at once, one sees the other's live lease. It also covers marks older than the 200 kept in the
   profile (the ledger says Granted → acknowledged, never re-granted).
3. **The in-flight set** (one server, one PurchaseId at a time). Marks are added before the save
   wait, so a concurrent delivery sees the mark and only waits for the same save.
4. **Transactions**: no half-applied reward can be saved.

**Scenarios.** *Replay:* mark found → acknowledged (tested). *Two deliveries at once:* one
grants, both acknowledge after the same save (tested). *Two servers:* the lease (tested,
including a lapsed lease taken over). *Crash before save:* nothing saved, ledger lease lapses,
retry grants. *Crash after save:* retry finds the mark. *DataStore failure:* deferred (tested).
*Early rejoin to another server:* the new server can't open the profile until the old one
releases it; receipts wait (unresolved) meanwhile. *Disconnect mid-receipt:* the profile is
released with the reward; the next delivery finds the mark.

**Effects.** Exactly-once is guaranteed for *rewards*. World effects are at-most-once per credit
spend: the credit is spent and the profile saved at once. A crash in the second between spending a
rain/salute credit and that save could bring the credit back and play it again (the guest gets
something twice; never nothing). Rain shares are exactly-once per guest per rain: the share and
the rain's id are written together, and a guest who already holds the id gets nothing (rejoins,
other servers).

**No negative balances.** No new product takes Gilt; credits are only spent when above zero;
Boutique Gilt purchases check the balance first.

**Gifts (residual risk).** A gift saves both profiles before acknowledging. If the server
crashes after the giver's save lands but before the recipient's, Roblox's retry finds the
giver's mark and acknowledges; the recipient's gift could be lost. The window is a fraction of a
second between two saves. (Closing it fully needs a delivery outbox in the giver's profile,
retried until the recipient confirms; noted as a future improvement.)

---

## 14. Test plan

**Automated** (`tools/check.sh` runs all of it; every run must end `0 failed`):

* `tests/purchases.luau` — 157 checks against the real modules on a fake clock:
  A catalog (validation; luck can't touch scores; ids by name; passes need an id; ambiguous ids
  refused) · B receipts (malformed; unknown then fixed; replay; absent buyer; profile not open;
  another server's live lease; a lapsed lease taken over; ledger-granted but missing; a save that
  doesn't land; a failing handler rolled back; the outbox; ledger down; a switched-off product; a
  long PurchaseId; two deliveries at once; a gift saved in both profiles) · C risk (region hop,
  many regions → Review, velocity + odd amount → Restricted, receipts still granted, lifts after
  its hours) · D remotes (flood, nested tables, too many fields, price/amount/id ignored, only
  offers by key) · E Velocity (product, duplicate → credit, Settings, pass confirmed by Roblox
  only, refund revoked, found on arrival, speed formula and cap) · F Chronos Defiance at a real
  timed table (offer, prompt, the wait, receipt → +15 s, one per round, the boards keep the
  pre-revive score, window lapses, late receipt kept, held revive used, declining) · G Decree
  (cleaning, filtering, limits, presets, can't-chat accounts, purchase → banner, the moderation
  log, cooldown, queue of 3, the gap, bought with nothing written) · H Luck (2.5× Gilt and
  Ledger, stacking under a slow save, counts only in play, the 6-hour offer limit, a purchase
  beyond it granted in full, the 10× cap, expiry) · I Rain (buyer bonus saved with the receipt,
  shares, joiners, rejoins, replays, the line, the gap, a buyer who leaves, max recipients) · J
  analytics (three fields, segments, vocabulary, impressions throttled).
* `tests/shop.luau` — 244 checks: the Boutique end to end on the same system.
* Type checking of every script (`luau-lsp`, strict).

**By hand in Studio** (Game Settings → Security → *Enable Studio Access to API Services* on;
Studio purchases are free test purchases):
1. Boutique → Offers lists the five (once created in Creator Hub) with Roblox's prices.
2. God-Mode Luck: buy → the chip counts down; a run's Gilt is 2.5×; leave and rejoin → the time is
   still there.
3. Velocity: buy → faster at once, trail on; Settings → Your perks → switch each off and on.
4. Obsidian table: let the clock run out → the card counts 10 → *Revive* → buy → +15 s. Next
   clock-out in the same round → banked; the run card shows the board score.
5. Decree: *Write it* → type → *Check my words* → *Proclaim* → buy → banner for everyone (use a
   second Studio player via Test → Clients and Servers).
6. Rain with two players: both get +150; a third joining during the shower gets it once.
7. Output shows no `[Maison]` warnings except expected setup notes.

---

## 15. Security review

| Threat | Mitigation |
| --- | --- |
| A screen claims ownership, a price, an amount, a multiplier or a flag | never read; the server asks Roblox (prices, passes) and its own state |
| A screen opens Roblox's purchase window itself | rewards come only from receipts; every receipt is safe in any state (§0.6) |
| Spoofed "purchase finished" events | never grant a product; a pass needs `UserOwnsGamePassAsync` |
| Receipt replay / duplicate delivery / two servers | profile mark + ledger claim + in-flight set (§13) |
| Flooding remotes | token buckets on every remote; refusals logged |
| Malformed payloads | validators; every handler re-checks each field it uses |
| Decree abuse: spam, flooding | 120 s per guest, 20 s per server, queue of 3, 8 s on screen, one at a time |
| Decree abuse: offensive text | Roblox broadcast filter; mostly-filtered text refused; can't-chat accounts get presets; preview before paying |
| Decree abuse: impersonation | heading set by the server (display name and @username); fixed styling; the buyer can't change size, colour or duration |
| Moderation | every decree in `MaisonNoir_DecreeLog` by day: user id, names, text, time, server |
| Alt accounts farming rains | 150 Gilt once per account per rain; ≤ 60 recipients; minor currency only |
| Economy inflation from boosts | Luck only on Gilt/Ledger; every Gilt boost together ≤ 10×, Ledger ≤ 6× |
| Pay-to-win | nothing sold changes a score on a board: a revive's points after the revive don't reach the boards |
| Fraud patterns | the risk check pauses new prompts, never receipts; the owner is warned |
| Analytics poisoning | impressions built by the server; fixed vocabularies |
| Data privacy | ledger records tagged with the buyer's user id (erasure requests); decree log keyed by day (remove a user's entries on request) |
| Obfuscated remote names | not used and not relied on |

---

## 16. Deployment checklist

1. **Studio:** Game Settings → Security → *Enable Studio Access to API Services* (DataStores in
   Studio; otherwise the ledger runs in memory, which is fine for a first look).
2. **Create the developer products** (Creator Hub → your experience → Monetization → Developer
   Products), names exactly as below; the game finds them within five minutes:
   `Chronos Defiance` 49 · `Emperor's Decree` 149 · `God-Mode Luck` 199 · `Megalodon Rainmaker`
   699 · and, if you won't make the pass, `VIP Velocity Elite` 499. (The Boutique's products: see
   LAUNCH.md.)
3. **The VIP Velocity Elite game pass** (recommended): Monetization → Passes → Create a Pass,
   name *VIP Velocity Elite*, price 499, put it on sale; copy its id into Creator Hub → Configs
   as `Products_velocityElite` (live, no republish), or into `Config.Products.velocityElite`. Keep the developer product
   too if you like: owners of either are never charged twice (a second becomes credit).
4. **Publish**, join, and open the owner's error panel: every product problem is listed there
   ("switched off", "two products share the id", a receipt waiting).
5. **Test** each product once in Studio (§14, by hand).
6. **Watch** Analytics → Custom events for a week: Grant failed should stay at 0; Deferred
   reasons should be rare and explainable.
7. **Never rename a product `Key`** in ProductConfig (profiles, the ledger and analytics use it).
   Renaming a product's Creator Hub name means updating its `Name` here too.
8. **To stop selling** something: take it off sale in Creator Hub. Keep its handler: receipts
   already paid for may still arrive.

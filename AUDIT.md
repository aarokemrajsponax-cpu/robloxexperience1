# BECOME THE RICHEST GUEST — Player Simulation, Gameplay & Business Audit (Build 102)

*24 November 2026. Branch `claude/nice-brown-a88p9r`.*

## 0. How this audit was done, and what it can and cannot claim

Every finding below carries one of these labels:

| Label | Meaning |
|---|---|
| **[SIM]** | Checked by the project's automated simulations: the real server modules under Lune (29 suites), and the real client UI under the client harness on three screen profiles (desktop 1280×720, phone 844×390, tablet). |
| **[CODE]** | Read in the source: the behaviour follows from the code, but no simulation exercised it end to end. |
| **[RENDER]** | Seen in a rendering of the client's UI snapshots (an approximation of Roblox's layout, not Roblox itself). |
| **[JUDGEMENT]** | A design opinion: reasoned from the features above, not measured. |
| **[NOT VERIFIED]** | Could not be checked here. |

**What was not done:** nobody played the live experience in Roblox Studio or on a device for this audit. There are no real players, no retention numbers, no revenue, no frame-rate or memory measurements, and no live multiplayer load. The "player personas" are structured walkthroughs of the game's actual systems, written from each player's point of view. They are not recordings of real people. Where a persona "reacts", that reaction is a design judgement.

**Verification totals at the end of this audit** (Build 102, final run):

- Server suites: 29, all passing. Among them: wings 36, purchases 511, shop 594, luxe 260, basement 140, executive 174, gala 132, concierge 65, smoke 659 and run (bundle) 221.
- Client suite: 1569 / 1570 / 1570 checks passing on desktop / phone / tablet (0 failed), including the new elevator, wing-drawing, guide and after-event checks.
- Type check (luau-lsp, strict): clean.
- All 41 server remotes go through the input guard (`RemoteGuard`). None is connected raw. **[CODE]**

---

## 1. The game as built: structure and loop

### 1.1 What a player does

1. **Load.** A full-screen loading scene of the house at night, with real progress (ReplicatedFirst). **[CODE]**
2. **Home Screen.**
   - Title, the player's Gilt, Gems and level, and a big PLAY.
   - Shop, How to play, the Leaderboard, and a live ticker of what's on.
   - Announcements wait until after Play. **[SIM]**
3. **Arrive.**
   - New guests arrive in the Foyer by the Concierge, who greets them and mentions the House Tour. **[SIM]**
   - Returning guests arrive in their own private Suite. **[CODE] + [SIM] (wings)**
4. **First minute.**
   - A gold hand points at HOUSE TOUR for 14 seconds (new guests only, once).
   - The Welcome Gift lets them choose a first brainrot.
   - At about 40 seconds, the quiet guide points at Play: "Your first Gilt". **[SIM]**
5. **Core loop.**
   - Play an attraction and earn Gilt, shown exactly before it's earned.
   - Spend Gilt in the Boutique, or collect brainrots, which earn Gilt per hour.
   - Fortune grows, and so do wealth ranks and the Wealthiest boards.
   - Unlock the next tier: the Executive Suite needs an invitation from the Basement or Steal a Luxe, or one bought with Gilt. **[CODE]**

### 1.2 The ten questions

| # | Question | Answer from the build |
|---|---|---|
| 1 | Immediately after joining? | Home Screen, then PLAY: the Foyer by the Concierge (new) or your own Suite (returning). |
| 2 | First exciting thing? | Steal a Luxe: lift treasure while security sleeps, then run to the getaway car as guards wake. The Welcome Gift brainrot comes first, and is quieter. |
| 3 | Reason to continue? | Exact Gilt per piece, a growing bag, side jobs, bigger bags to buy, and the Executive Suite invitation as a visible next tier. |
| 4 | Reason to return tomorrow? | Daily calendar claim, streak, Tonight's table (once a day), daily and weekly objectives, Showtime and Lights Out schedules, the weekly Grand Auction, AFK Gilt from the brainrot squad. |
| 5 | Reason to explore another area? | The Directory lists every room. The tour visits them. Each attraction has its own loading identity and first-visit card. |
| 6 | Achievement? | Levels, prestige (no reset), 15 Badge Book badges, House Trophies in the Suite, best hauls and times on the boards. |
| 7 | Social interaction? | The Friend Booster (+25% rising to +55% Gilt), friends visiting your Suite (by permission), the Grand Ballroom (dance, Runway, trivia, Flex Studio, Lights Out), trading, Circles of up to 20, the guest book. |
| 8 | Collecting? | Brainrots (3D figures that earn Gilt per hour), 86 curios, Vault cabinets with featured domes, collection completion, Lucky Boxes (odds shown), Grand Auction lots. |
| 9 | Why become the richest? | Fortune is visible on the HUD, ranks are named, and the Wealthiest boards stand in the Foyer. Bought Gilt is excluded from the boards. |
| 10 | Different from other Roblox games? | A single luxury house that holds several genres (heist, obby, boss raid, social ballroom, auction, racing), joined by one wealth number, with private elevator-served Suites. |

**[JUDGEMENT]** The intended structure (attractions, then Gilt, then Fortune, then rank) matches what the code delivers. The weakest joint is between the minute-one welcome and the first attraction. That joint is now handled by the Play pointer and the House Tour, but it still depends on the player choosing to press Play rather than wandering.

---

## 2. Player personas

Each persona's behaviour follows the actual systems. Verdicts are design judgements.

### Persona 1: the action-craving 9-year-old

**Discovery.**
- Title: "BECOME THE RICHEST GUEST" is a clear goal a child understands ("get rich").
- Thumbnail and icon are **[NOT VERIFIED]**. They live on Roblox, not in this repo.

**First 30 seconds.**
- Loading scene, then Home Screen with one huge PLAY. Good.
- In the Foyer: the Welcome card, the Concierge's one line, and the HOUSE TOUR hand.
- Nothing forces them. They can run straight off. **[SIM]**

**First 3 minutes.**
- The Play pointer (at 40 s) leads to the Directory, then Steal a Luxe.
- Lifting treasure, guards waking and the dash to the car is the strongest kid moment in the game.
- The 6.5-second loading hold at each attraction door is the main patience risk. It was a deliberate earlier requirement (the place streams in), and it's now a full-screen scene with real progress, which reads better than a frozen screen. **[CODE]**

**First 10 minutes.**
- The Basement obby (32 stages, checkpoints, skip offered) suits this player.
- The Salon sorting table and the Library auction are slower and more reading-heavy. A 9-year-old will likely skip them. **[JUDGEMENT]**

**Spending.**
- Prices show on every product. Lucky Boxes show their full odds and can be bought with earned Gilt as well as Gems.
- No countdown pressure on purchases. **[CODE]**
- Risk: there are many products (33 developer products and 2 passes). The Boutique is large for a child. **[JUDGEMENT]**

**Verdict.**
- Likely to stay a session if they reach Steal a Luxe or the Basement within about 2 minutes. The guide now makes that likely.
- Leave risks: text-heavy cards, waiting at doors, and the Salon if they wander in first.
- Favourite? Only if the heist and obby feel fast on their device.

### Persona 2: the 15-year-old unwinding player (via TikTok)

- **First session.**
  - The optional House Tour respects their time: it's skippable, replayable and walks with them. **[SIM]**
  - The Concierge answers 23 categorised questions. **[CODE]**
- **Longer play.**
  - The brainrot squad earning Gilt per hour, Suite furnishing and themes, Vault featured domes and House Trophies all build attachment.
  - The Suite is now genuinely theirs: a private wing nobody can walk into. **[SIM]**
- **Return motivation.**
  - The daily calendar, streak, objectives and weekly Auction are meaningful. Streak and calendar reward attendance but don't punish missing a day harshly. **[CODE]**
  - Holidays and seasons dress the house and attractions. **[CODE]**
- **Monetization.**
  - Gamepass value is clear: VIP Velocity Elite speed (never in competitive rooms), the Gold Key's extra Suite rooms.
  - Boosters state exactly what they do and for how long. **[CODE]**
  - Free players can reach everything. Gems come only from Robux, but nothing essential is Gems-only. **[CODE]**
- **Verdict.** A good candidate for a regular game, because of the Suite, the collection and friends. They would recommend it to a friend for the Suite visits and the Ballroom. They'd drift away if the attractions feel the same after a week (see the retention section).

### Persona 3: the critical content creator (24)

- **Praise.**
  - Distinct identity (luxury house, black and gold).
  - Exact-reward honesty.
  - Many genres in one place.
  - 55 different Admin Abuse nights.
  - Private Suites with an elevator: a clean, clippable "my penthouse" moment.
  - A large automated test suite: unusual for Roblox, a technical-quality signal.
- **Criticism.**
  - **Breadth over depth.** Many systems; some (Salon sorting, Lucky Boxes, the Hourly Drop) overlap in purpose.
  - **Brainrots.** The theme borrows a current meme trend, which could age.
  - **Text density.** The house writes a lot of copy, and a creator will notice wordiness.
  - **Visual fidelity.** The UI is consistent; the 3D is built from parts, with no imported meshes or textures (by design and for licensing). It reads as "clean" rather than "AAA". **[JUDGEMENT]**
- **Technical.**
  - No unguarded remotes. Purchases idempotent (511 checks). Private-space access enforced server-side. **[SIM/CODE]**
  - Device behaviour checked only in the harness. **[NOT VERIFIED on hardware]**
- **Content hooks.**
  - Admin Abuse finales.
  - The first-haul celebration.
  - Lights Out's last lamp.
  - Suite tours by elevator.
  - Basement stage 32.
  - The Executive boss fight.
- **Verdict.** Would make one video about an Admin Abuse night or the heist. A second video depends on visible updates and on 3D quality where it matters (Suite and Ballroom).

### Persona 4: the random discovery player

- **Thumbnail, icon, description, screenshots:** **[NOT VERIFIED]**. They're managed on Roblox. Section 8 gives briefs.
- **Title:** strong: a goal, not a place name.
- **Expectation versus experience.** If the thumbnail shows a luxury mansion with a heist, the first 3 minutes deliver it: Steal a Luxe is one door from the Foyer.
  - The risk is a thumbnail promising cars or the island. Luxury Island is "coming soon" in places. The Grand Prix exists but opens on a schedule. **[CODE]**
- **Verdict.** Clicks only if the thumbnail shows a person mid-heist with treasure and the house behind them. Stays if Steal a Luxe is reached fast (now guided).

### Persona 5: the Admin Abuse event player

- **During the event.**
  - Event nights are rich: 55 themed nights with openings, realms, gifts, a finale and a recap. **[CODE]**
  - Notices wait their turn and announcements never stack. **[SIM]**
- **After the event (before this audit):** nothing pointed a first-time event visitor at the rest of the house.
- **Fixed in this audit:** about 24 seconds after an Admin Abuse finale, a newcomer (level 8 or below) is shown once, ever: "The house is open every night: Steal a Luxe, the Basement and the Executive Suite are open all the time. Press Play to pick one." It points at Play and is remembered so it never repeats. **[SIM]**
- **Verdict.** More likely to stay past the event now. A cosmetic event souvenir (see Remaining work) would add a reason to come back.

### Persona 6: acquisition evaluation team

See section 9.

### Persona 7: free-to-play

- Every attraction, the Suite, the Vault and the Ballroom are free.
- Gilt buys bags, invitations, themes and brainrots. Lucky Boxes can be opened with Gilt. **[CODE]**
- Bought Gilt never counts on the Wealthiest boards. **[CODE]**
- **Boosters on the boards: decided by the owner (Build 103).** Paid Gilt boosters (Luck Booster 2.5× for 30 minutes, Double Gilt) multiply earned Gilt, and the owner has decided that **all earnings, boosted ones included, count** toward Fortune and the Wealthiest boards. This is what the code already does, so nothing changed. Bought Gilt itself (Gilt packs) still never counts. **[CODE]**

### Persona 8: the collector

- Strengths:
  - 86 curios.
  - A brainrot roster with rarities and Gold, Diamond and Rainbow variants.
  - Collection completion shown, with featured domes.
  - Acquisition history (the last 40).
  - A Register book. **[CODE]**
- Weakness: no named sets with set rewards ("collect all four Executive pieces"). **[JUDGEMENT]**

### Persona 9: the social player

- Strengths:
  - Friend Booster stacking.
  - Suite visits by permission (friends, invited friends, or nobody), with the 6.5-second elevator ride. **[SIM]**
  - The Ballroom's dance, Runway votes, trivia and Lights Out. Trades. Circles.
- Weakness:
  - Friends can't meet inside each other's Vault: visits are Suite-only, by design.
  - Nothing shared and persistent to build together (for example, a Circle lounge). **[JUDGEMENT]**

### Persona 10: the competitive player

- Strengths:
  - Wealthiest boards (bought Gilt excluded).
  - Best hauls, Basement times, Grand Prix lap boards.
  - Tonight's single daily table.
- Weakness: boosted hours count on the boards (the owner's decision, above). Wealth ranks lack a seasonal reset or season board, so newcomers can't catch long-time players. **[JUDGEMENT]**

### Persona 11: the returning player

- Arrives in their own Suite.
- A short "What's new" (updated in this audit for Build 102: private Suite and Vault, friend permissions, exact Gilt and House Tour). **[CODE]**
- Saved data comes from ProfileStore. Build 102 adds one hidden setting (the guide's progress) and changes no saved fields. **[CODE]**
- The Studio "NOT SAVING" notice appears only when Studio has no API access.

### Persona 12: the mobile player

- **Fixed in Build 102:**
  - The Steal a Luxe card no longer covers the Gilt and the Fortune.
  - The SATCHEL word is hidden on a phone (6 pt, unreadable).
  - The Welcome kicker is a size up.
  - Loading-screen text is a size up.
  - Dance-move names now fit their tiles (they ran together).
  - "1 KEYS" fixed. **[SIM/RENDER]**
- **Remaining:**
  - The Friend Booster card's tags render at about 7 pt on a 390-pt-tall phone. **[RENDER]**
  - Tall cards (the Directory's Executive Suite card, the Lights Out results) render off-screen in the harness. On a real device, `Theme.fitHeight` turns a too-tall card into a scrolling one. The harness can't measure that path. **[NOT VERIFIED]**

### Persona 13: the low-end device player

- Build 102 adds `UI/Quality`: on phones, or when Roblox graphics are set at or below 4, bloom is softer and every particle emitter's rate is halved.
- Loading scenes draw fewer elements (`lite`).
- Other players' private wings are never drawn (`World/WingView`). **[CODE]**
- No frame-rate or memory measurement was possible. **[NOT VERIFIED]**

### Persona 14: the exploit-attempting player (controlled, in simulation)

| Attempt | Result | Evidence |
|---|---|---|
| Fire any remote raw with junk | All 41 server remotes go through `RemoteGuard` (shape, size and rate). | **[CODE]** |
| Enter someone's private Suite or Vault by moving one's own character there | Server watch every 0.3 s sends them to their own wing. | **[SIM]** wings test |
| Ride to a non-friend's Suite, or a friend's closed Suite | Refused. Permission re-checked at the door. | **[SIM]** |
| Follow someone through the elevator | Only the asker rides. | **[SIM]** |
| Double-book elevator rides | Refused while one is under way, plus a 1-second rest. | **[SIM]** |
| Ask "suite" with someone else's id | You get your own Suite. | **[SIM]** |
| Duplicate purchase grants | Receipts idempotent. | **[SIM]** purchases 511 |
| Client-sent reward amounts | Rewards computed server-side (exact Gilt quote = payment). | **[SIM]** luxe, basement |
| Modify another player's furniture or Vault | Furnishing and Vault ops change only the requester's own data. | **[CODE]** |
| **Found and fixed in Build 102** | The elevator's request check accepted at most 2 fields, so **every friend visit would have been refused**. Caught by the new test before release. | **[SIM]** |

### Persona 15: the completionist

- Strengths:
  - Every room is reachable from the Directory.
  - 15 badges, levels and prestige, House Trophies.
  - 32 Basement stages, 70 Luxe pieces.
  - The Executive's seasonal looks and challenges.
  - 55 Admin Abuse nights.
- Weakness: no single "completion" page that shows how much of the house you've done. **[JUDGEMENT]**

---

## 3. World exploration checklist

| Area | Status | How verified |
|---|---|---|
| Home Screen, loading, intro | Working. Full-screen loading with real progress. | [SIM] + [RENDER] |
| Foyer, Concierge, House Tour | Working. Tour skippable, replayable, never stuck. 4 tour walk checks passed after a fix this build. | [SIM] |
| Directory (every destination) | Working. Tall cards on phones unverified (see Persona 12). | [SIM] |
| Private Suite (ownership, privacy, furnishing, seats, themes) | Working in simulation. Furniture drawn in the guest's own wing. | [SIM] wings + client |
| Private Vault (cabinets, featured, Register book) | Working. The Archivist character stays in the house's sealed Vault. | [CODE] |
| Elevator (5.5 / 5.5 / 6.5 s, house) | Working, exact timings. | [SIM] |
| Steal a Luxe (wings, guards, side jobs, exact Gilt, extraction) | Working. | [SIM] luxe 260 + client |
| Maison Basement (32 stages, checkpoints, skips, purses) | Working. Every stage's pay equals its shown reward. | [SIM] basement 140 |
| Executive Suite (invitation, terminals, code, boss, safe) | Working. Rewards now worded as Gilt plus Fortune. | [SIM] executive 174 |
| Grand Ballroom (dance, Runway, trivia, Flex, Lights Out) | Working. Dance tile names fixed for phones. | [SIM] gala 132 + client |
| Grand Auction | Working. | [SIM] auction 35 |
| Grand Prix | Working. | [SIM] races 58, racing 35 |
| Salon (sorting, Tonight's table) | Working. | [SIM] tables, smoke |
| Luxury Island | Exists, with "coming soon" wording in places. | [CODE] |
| Admin and Admin Abuse | Working. Owner-only. Post-event newcomer pointer added. | [SIM] staff, client |
| Seasons and holidays | Working. | [SIM] holidays 107, calendar 46 |
| Daily calendar, streak, hourly drop, AFK, objectives | Working. | [SIM] |
| Badges, prestige, levels | Working. | [SIM] prestige 31 |
| Shop, Boutique, Gem Shop, Lucky Boxes (odds shown) | Working. | [SIM] shop 594, boutique 78 |
| Data saving | ProfileStore. Mock in Studio without API access. | [CODE] |
| Live devices, performance, real multiplayer load | — | [NOT VERIFIED] |

---

## 4. Emotional experience

[JUDGEMENT], from the systems above.

- **Curiosity.** Strong. Every attraction has its own door, loading identity and first-visit card.
- **Excitement.** Highest in the heist chase, the Executive fight, Lights Out's last lamp and Abuse finales.
- **Accomplishment.** First-haul celebration, Basement checkpoints, invitations, levels.
- **Ownership.** Strongest after Build 102: the Suite is now physically yours, reached by your own elevator.
- **Social.** Good tools. They depend on friends being in the same server.
- **Frustration risks:**
  - The 6.5-second door holds.
  - Text density.
  - Too many currencies of meaning for a child: Gilt, Gems, Fortune, levels, Keys.
- **Desire to return.** Schedules (Showtime, Lights Out, the weekly Auction), the calendar, AFK earnings.
- **What to remove, not add:** fewer reward types shown at once, shorter cards.

## 5. Retention and progression

- **Strongest factors:**
  - The private Suite and collection (ownership).
  - Exact rewards (trust).
  - Scheduled social moments.
  - The Executive invitation as a visible goal.
  - The weekly Auction.
- **Weakest factors:**
  - No named collection sets.
  - No season or reset board for newcomers.
  - Booster fairness on the boards.
  - Attraction variety over weeks. Basement courses rotate every 5 minutes and the Executive varies, but the core loops don't escalate after mastery.
- **Analytics needed** (not available here): D1, D7 and D30 retention cohorts, funnel step completion (the onboarding funnel exists in code), time to first attraction, session length, purchase conversion by product. Roblox Creator Hub provides most of these.

## 6. Monetization

- **Inventory** (from `shared/ProductConfig`): 33 developer products and 2 game passes. Examples:
  - VIP Velocity Elite (speed; never in competitive rooms).
  - The Gold Key (extra Suite rooms).
  - Luck Booster and Double Gilt (timed Gilt multipliers).
  - The Introduction.
  - Basement skips.
  - Holiday passes.
  - Jet liveries.
  - Brainrot Penthouse and Feast.
  - Revives.
  - Open the Grand Prix Now.
- **Clarity.** Each product carries a one-line description of exactly what it does. Prices show. No countdowns. Lucky Box odds are shown in full. **[CODE]**
- **Reliability.** Receipts are idempotent and grants are retried. **[SIM]**
- **Launch item [NOT VERIFIED here].** The server reports any developer product not yet created in Creator Hub. In the test harness all are "missing" because the harness has no Creator Hub. **Check the owner's error feed after publishing: the "products aren't on sale yet" list must be empty**, or those items can't be bought.
- **Recommendations:**
  - Bundle cosmetics by theme.
  - Add cosmetic event souvenirs.
  - Keep Gems-only items cosmetic.

## 7. Marketing, discovery and viral potential

**Promise check.** "Explore the mansion. Build your Fortune. Become the richest." The build delivers all three. The single strongest differentiator is **one luxury house with a heist, an obby, a boss raid and a ballroom inside it, plus your own private penthouse up an elevator**.

**Store page briefs** (to make on Roblox; nothing here is live):

- **Icon:** a gold key over a black lacquer door, with the house's diamond mark. Readable at 150 px.
- **Thumbnail 1:** a player mid-sprint out of a gallery, bag of glowing treasure, guard silhouette behind, gold "+1,240 GILT" over them.
- **Thumbnail 2:** a private penthouse from the elevator doors opening, the city far below.
- **Thumbnail 3:** a crowded Ballroom during an Admin Abuse finale.
- **Description (first 2 lines matter most):** "Steal treasure, climb the Basement, beat the Executive and become the richest guest in the house. Every guest gets a private Suite, up their own elevator."
- **Trailer:** door opens, heist dash, bank (exact Gilt), elevator up, private Suite, friend arrives, Ballroom finale, title. 30 seconds.

**20 TikTok concepts.** Hook / first 3 s / show / why watch / why click / ending.

1. "I robbed the richest house on Roblox". Door creak and a sleeping guard. The lift, the wake, the chase, the bank. Tension. Easy goal. End: "+2,000 Gilt in one trip?"
2. "My Roblox penthouse has its own elevator". Doors open on the Suite. The ride, the floor counter, the reveal. Aspirational. Click: "I want one." End: "Friends need permission."
3. "Stage 32 of the Maison Basement". The last jump. The full descent, montage. Challenge. End: "Can you get here?"
4. "Admin Abuse in a mansion". The countdown. Opening, realms, gifts, finale. Spectacle. End: date of the next night.
5. "Rating my friend's Suite". The elevator to their floor (6.5 s). Their furnishing. Social, relatable. End: "Rate mine."
6. "Last lamp lit wins": Lights Out. The dark room. Elimination tension. End: the winner reveal.
7. "I beat the Executive". The boss reveal. Generators, bodyguards, the stun, the safe. Boss fight. End: "The safe was…"
8. "Every brainrot I own". The Vault cabinets glowing. Squad walking. Collection flex. End: "Rarest one?"
9. "The richest guest in the server". The Wealthiest board. A Fortune climbing over a session. Competition. End: "Beat me."
10. "Free vs paid: which is richer?" Two players side by side. A day each. Curiosity. Must be honest. End: the result.
11. "The Concierge knows everything". Ask a weird question. The 23 answers. Comedy. End: "Ask him yourself."
12. "Rarest Lucky Box odds". The odds screen first, then opening with Gilt. Transparency. End: "Odds are on screen."
13. "Grand Auction last seconds". The bid war. Every server bids at once. End: win or lose.
14. "Runway with the worst outfit". The catwalk. Votes. Comedy. End: the score.
15. "I hid in the Steal a Luxe garage". The van side job. A stealth route. End: the bank.
16. "The house at night". The loading screen, then the Foyer lights. Mood and aesthetic. End: the title.
17. "New player, 10 minutes". Fresh account. Honest first session. Relatable. End: "Where should I go next?"
18. "Holiday house". Seasonal dressing. Seasonal search. End: the end date.
19. "Grand Prix in a supercar". The start lights. A race. Speed. End: lap time.
20. "Friend Booster maxed". Four friends join. +55% Gilt. Social incentive. End: "Bring three friends."

**10 YouTube concepts.** These are series a creator could make. Nothing here contacts anyone.

1. "Richest guest in 24 hours" (progression).
2. "Every room in the Maison" (exploration).
3. "Basement 1–32 no skips" (challenge).
4. "Beating the Executive, every season" (variants).
5. "Admin Abuse: all nights explained" (events).
6. "Free-to-play to Wealthiest board" (fairness).
7. "Suite tour tier list with viewers" (community).
8. "Grand Auction strategy" (economy).
9. "Steal a Luxe speedrun" (competitive).
10. "Building the perfect brainrot squad" (collecting).

**Creators.**
- A creator code is not recommended without a reward design.
- Better options: invite small creators to an announced Admin Abuse night, give them a Suite theme as a thank-you, and never require positive coverage.

## 8. Competitive position

[JUDGEMENT]. No live market data was used.

- **Comparable interests:** heist/steal games, obbies, tycoon and collection simulators, roleplay mansions, Admin Abuse event games.
- **What they do well:**
  - One-verb loops that are clear in 5 seconds.
  - Big numbers.
  - Constant reward feedback.
- **Where this game differs:**
  - One house joining many genres.
  - Honest exact rewards.
  - A private elevator penthouse.
  - A luxury, non-cartoon look.
- **The risk is the same as the strength:** breadth can feel unfocused. **Lead every page and video with the heist and the private Suite.**

## 9. Acquisition evaluation (hypothetical)

- **Commercially attractive:**
  - A clear wealth fantasy.
  - Several monetizable systems with honest presentation.
  - A strong live-ops toolkit (55 event nights, seasons, a schedule calendar, an owner console).
  - Unusually thorough automated tests (about 30 suites, thousands of checks).
  - Server-authoritative economy and privacy.
- **Concerns:**
  - No real metrics yet.
  - Breadth versus depth.
  - Booster fairness.
  - A meme-trend theme (brainrots).
  - Part-built 3D.
  - Large text-heavy UI.
  - One codebase dependent on a small team.
- **Before talks:** real D1, D7 and D30 retention, DAU, MAU and CCU, revenue, ARPPU, conversion, top products, and stable performance data on phones.
- **Valuation:** **not possible without metrics.** Any number would be invented. Scenarios only, with stated assumptions:
  - **Early stage** (low CCU, unproven retention): valued on code and IP quality only.
  - **Growing** (sustained CCU and healthy D7): valued on a revenue multiple.
  - **Established** (top-chart presence): valued on proven cash flow and IP.
  - The deciding inputs are exactly the metrics listed above.
- **Would a serious company look further?** Possibly, *after* the game shows retention. The architecture, honesty and live-ops tooling would survive due diligence. What makes it acquisition-worthy rather than interesting is a proven loop: players who return for the heist and the Suite without events.

## 10. Bugs and improvements this audit

| Severity | Issue | Where | Status |
|---|---|---|---|
| Critical | Friend Suite visits always refused (request check allowed 2 fields, visits send 3) | `server/Wings` | **Fixed** (Build 102), test added |
| Critical | Other players could share or see your Suite (only hidden client-side before) | `server/Wings`, `shared/Wing` | **Fixed** (Build 102): physical private wings |
| High | House Tour walk broken by new cards | `shared/Voice` (tour) | **Fixed**, 4 client checks green |
| High | Admin Abuse visitors given no path into the rest of the house | `UI/Guidance`, `World/AbuseShow` | **Fixed**: once-only newcomer pointer |
| High | Steal a Luxe card covered the Gilt bar on phones | `UI/HudCard`, `UI/LuxeHud` | **Fixed** (Build 102) |
| Medium | Dance-move names overlapping on phones | `UI/GalaPanel` | **Fixed** |
| Medium | "1 KEYS" | `Table/TableClient`, `UI/BallroomPanel` | **Fixed** |
| Medium | What's New described Build 100 changes | `shared/Voice` | **Fixed** |
| Medium | First "next step" pointer came at 75 s | `UI/Guidance` | **Fixed**: 40 s |
| Medium | "Estate" and purse-conversion wording confusing | `Voice`, `ExecutiveHud`, `Celebrate`, `FortunePanel` | **Fixed** (Build 102) |
| Low | SATCHEL word unreadable on phones | `UI/SatchelPanel` | **Fixed** (Build 102) |
| Decided | Paid boosters count toward the Wealthiest boards | `server/Gilt` | **Owner's decision: all earnings count, boosted included** (current behaviour, no change) |
| Open | Friend Booster card text about 7 pt on phones | `UI/FriendBooster` | Not changed (layout needs a redesign pass) |
| Open | Archivist not inside private Vaults | `Staff/Archivist` | Not changed |

## 11. Scorecard

Design judgements, informed by the evidence above. Confidence reflects how much was verifiable here.

| Category | Score | Evidence | Remaining weakness | Confidence |
|---|---|---|---|---|
| First impression | 7 | Loading scene, Home Screen, PLAY | Store assets unverified | Medium |
| Discovery appeal | 6 | Strong title | Thumbnail and icon unverified | Low |
| Onboarding | 7 | Optional tour, guide, exact rewards | Text density, door holds | Medium |
| Gameplay | 7 | Heist, obby, boss, ballroom all tested | Loops don't escalate after mastery | Medium |
| Progression | 7 | Levels, prestige, invitations, ranks | No sets, no season board | Medium |
| Exploration | 8 | Every room reachable, the Directory | Island partly "coming soon" | Medium |
| Social | 7 | Booster, Suite visits, Ballroom, trades | Needs friends in-server | Medium |
| Collecting | 7 | 86 curios, brainrots, Vault | No set rewards | Medium |
| UI/UX | 7 | Consistent system, 3 devices tested | Wordy, small text in places | Medium |
| Graphics | 6 | Cohesive look, richer grade | Part-built 3D | Low (no device) |
| Performance | ? | Quality scaling added | Not measured | None |
| Mobile | 6 | Phone profile passes all checks | Small text, tall cards unverified | Low |
| Monetization | 7 | Clear, odds shown, idempotent | Booster fairness, product setup to verify | Medium |
| Retention design | 7 | Calendar, schedules, Suite, Auction | Unmeasured | Low |
| Content potential | 7 | Abuse nights, heist, elevator Suite | Needs creator outreach | Low |
| Technical reliability | 8 | 29 suites, guarded remotes, idempotent receipts | Live load unverified | Medium |
| Overall identity | 8 | Luxury house, wealth goal, private penthouse | Breadth can blur the pitch | Medium |

## 12. Executive verdict

**A solid developing experience, close to polished-and-competitive.** It is technically sound and honest. The heist and the private Suite are its two strongest hooks. It isn't proven: no player data exists yet. The next gains come from focus, not more features:

- lead with the heist and the Suite;
- shorten the copy;
- add collection sets and a season board;
- verify performance and readability on a real phone.

### Remaining work, ranked

1. Play the build on a real phone and a PC. Confirm the elevator, Suite privacy with two accounts, and tall cards scrolling.
2. Confirm in the owner's error feed that no developer product is "not on sale".
3. Make the icon, thumbnails and trailer (section 7).
4. Friend Booster card readability on phones.
5. Collection sets with cosmetic rewards; a seasonal Wealthiest board.
6. An Admin Abuse cosmetic souvenir.
7. Turn on Creator Hub analytics. Review D1, D7 and D30 and the onboarding funnel after launch.

## 13. Addendum: Build 103 (moments, seats, Luxury Island, a full house)

**Verification labels as in section 0.** Nothing here comes from real players; every result below is from the repository's own tests under Lune, or from renders.

- **A full house [TESTED, simulated].** The new `tests/crowd.luau` runs 24 guests in one server for 150 rounds, each doing a random mix of everything: walking to an entrance and going in, lifting and banking in Steal a Luxe, Basement checkpoints in order, every attraction's actions, seats, the elevator, the Boutique, owner-only commands, junk requests, leaving and rejoining. After every round it checks:
  - no request failed inside the server;
  - Gilt and Gems stayed whole and non-negative;
  - each guest was in at most one attraction, and their screen agreed;
  - no seat and no wing was shared;
  - no owner-only command worked for a guest.

  At the end everyone goes home and leaves, and nothing is left behind. Result: 14 passed, 0 failed (33 lifts, 5 banks, 73 checkpoints). It is the real server code under a fake clock, not a load test on Roblox's servers.
- **Seats [TESTED].** Sofas, benches and bar stools in the Grand Ballroom, the Executive Suite and the Island showed "Sit" but refused in silence: the server only registered seats inside the house's own folder. Fixed. Copies of seats in private wings get their own numbers, and refusals always say why. `tests/seats.luau`: 14 passed, 0 failed.
- **Luxury Island [TESTED + RENDERED].** Open, and rebuilt as a resort after the owner's reference picture.
  - Bugs fixed:
    - Island Standing could be farmed by flying in and out (about 28,500 Gilt plus "never sold" rewards).
    - Shown Gilt differed from paid Gilt past the daily cap.
    - A pearl was hidden under a deck.
    - Pearls had no in-water check.
    - Postcard reach was too tight.
    - Guests could be stranded at sea.
    - The jet's airstair came down away from the carpet.
    - The Lookout stair was blocked from the gardens.
  - `tests/island.luau`: 143 passed, 0 failed.
  - Rendered from 13 views.
  - **Not verified:** real terrain smoothing, water and sky; fire, particles and string lights in motion; behaviour on a real phone.
- **Moments, level up, Lucky reel [TESTED + RENDERED].**
  - Centred glowing moments for lifts, banks, checkpoints, secrets, the Executive and Ballroom wins.
  - Level up shows for about 6 s, and its fanfare plays its whole first phrase instead of cutting at 3.4 s.
  - The Lucky reel eases and settles, and always stops inside the result's own tile.
  - **Not heard here:** the music and sounds themselves.
- **Test-only fix.** Two stand-in guests in `tests/shop.luau` shared a UserId, so a giveaway check failed at random. The test is fixed; the game code is unchanged.
- **Final totals on this build:**
  - All 31 server suites pass, including the bundled run (221/0), crowd (14/0), island (143/0), seats (14/0) and shop (594/0, four runs).
  - Client suite: desktop 1574/0, phone 1575/0, tablet 1575/0.

## 14. Addendum: Build 104 (final fixes, island rides, the residence over the city)

Root causes found and fixed this build, each with a test that would have caught it:

| Issue | Root cause | Fix | Test |
|---|---|---|---|
| Caught by the Executive Suite's lasers, Leave: state said home, character still in the Suite | `sendHome` cleared the attraction's state first and moved the character after, unchecked; the character was released from its anchored hold in the same moment it was moved | Move first, while held (server-owned); check the landing and move again if needed; then release state; ease the hold off 0.35 s later; a second look at 1.2 s | tests/executive: caught → Leave ×5, physical position, state, anchor, re-entry |
| Sinking into the sand at the South Beach's cabanas and loungers | Terrain: the land circles filled sand to the lowland's height over the beach before its slope was filled, so the slope added nothing; decks, torches and the Coral Club sat up to 2.8 studs under the sand | The sand above both beach slopes is cleared before the slopes are filled | tests/island: all 86 island seats above the ground model and sat in; all 10 beach decks clear of it |
| Postcard: camera could stay fixed on the view | The postcard set the camera to Scriptable before asking photo mode to start; when photo mode refused, nothing restored it. Also: taken home mid-photo, the camera stayed on the island | Camera restored when photo mode doesn't start; photo mode exits on leaving an attraction | Client suite (3 devices) |
| Buying an island ride was always refused | `how` was missing from the attraction requests' key whitelist | Added | tests/rides |
| The gold hand on HOUSE TOUR never showed | The key clips its children and its parent is the screen (not a GuiObject), so the hand was drawn inside the key | The hand is laid on the screen, following the key's place | Client snapshot rendered |
| 4:3 tablet: the top-right row ran into the Gilt bar | Full row shown on any non-phone | Narrow screens keep How to play and Settings in the Menu | Client suite (tablet) |

New: the island's rides (jet ski, Day Yacht, helicopter; tests/rides 58 checks), the garage removed, the enclosed residence with a glass roof (tests/wings), the city view (client, render-checked), the Gilt payout scale ×10 (tests/economy).

Not verifiable here (needs Studio or a live server): Roblox's own network ownership hand-off on the Leave fix (the logic is tested, the engine's replication isn't); terrain voxel results of the beach carve; how the rides feel to steer (the rules and the server's checks are tested, the physics feel isn't); the two Robux ride products (not yet made in Creator Hub, so not on sale); performance of the city view on low-end phones.

## 15. Addendum: Build 105

**Robux purchases, checked in code and in tests/purchases.luau (518 checks):**

- Every Robux key goes through one server function, `Store.prompt`. No client script calls
  `PromptProductPurchase`. The product ID comes from Creator Hub by the product's exact name
  (Catalog discovery). No ID is typed into the code.
- A product that isn't made in Creator Hub shows as not on sale. Its key never opens a window.
- Receipts are granted once only, and only after the profile is saved. Replays are acknowledged
  without granting again, and unknown products stay unresolved (tests: "a replayed receipt
  grants nothing").
- New in this build: **"Midway Steal"** and **"Basement Push"** (19 Robux each). Make them in
  Creator Hub with exactly these names. Tested: one receipt grants one play, a replay grants
  nothing, and at 10 held no purchase window opens.
- Where the Robux goes: Roblox credits developer-product sales to the experience's owner
  account (or group), not to this code. Check Creator Hub's sales and transactions pages, and
  Roblox's DevEx page for current cash-out eligibility.

**Not proven by tests (needs a real playtest in Studio with two players):** the feel of the push
(physics), the Midway key's reach on a real character, phone thumbstick driving with the new
assist, and how the walking squads look in a crowded server.

# The Maison's economy (Build 73)

Every figure here is the game's own (`src/shared/Config.luau`, `src/shared/Luxe.luau`,
`src/shared/Basement.luau`, `src/shared/AuctionLots.luau`, `src/shared/Fortune.luau`,
`src/shared/Island.luau`, `src/shared/Gala.luau`, `src/shared/Tracks.luau`,
`src/shared/Prestige.luau`, `src/shared/Showcase.luau`, `src/server/Streak.luau`,
`src/server/TradeService.luau`). The
earning rates in section 7 are design estimates from those numbers, **not measured play data**:
check them against live analytics after release and tune the Config, not the code.

## 1. Currencies and what counts

| | What it is | How it changes |
|---|---|---|
| **Gilt** | The spending money | Earned in every attraction and at the tables, spent on upgrades, gear, invitations, bids, the Boutique |
| **Gems** | The rare currency | A few from the rarest finds (each source has a daily cap), bought with Robux, spent at the Gem Shop, on the golden treadmill, a Basement skip, Gem lots |
| **Estate** | Banked wealth from the attractions | Only ever grows: hauls, the Basement's purses, the Executive's prize and safe |
| **Fortune** | The aim of the game | Gilt + Gems × 40 + the collection by rarity + Suite items + Estate |

The **Wealthiest boards** rank the *earned* Fortune: Gilt and Gems bought with Robux are left out.

## 2. Steal a Luxe (the Velvet Room)

| Wing | Pieces (worth) | Guards' sight |
|---|---|---|
| The Garden Hall | 220 to 480 | 36 studs |
| The Long Gallery | 900 to 3,200 (the Ladro brainrot 2,500) | ×1.15 |
| The Strongroom | 4,800 to 9,500 (Gatto 7,000); the Crown Jewel 20,000 | ×1.3 |

- Banked: the whole worth (plus the banker's cut) to the Estate; **20%** of it paid in Gilt
  (subject to the daily Gilt soft cap).
- Gems: 2 for the tiara, the egg or Gatto, 5 for the Crown Jewel; **15 a day** at most.
- Caught: everything in the bag is lost (nothing banked is ever lost).
- A haul worth **8,000** or more brings an invitation to the Executive Suite.

| Upgrade (Gilt) | Levels and prices |
|---|---|
| A bigger bag | 3 → 4, 5, 6, 8, 10 pieces: 1,500 / 4,000 / 10,000 / 25,000 / 60,000 |
| Quiet shoes | seen 15% / 28% / 40% less far: 2,500 / 7,500 / 20,000 |
| The banker's cut | +10% / +20% / +30%: 5,000 / 15,000 / 40,000 |
| The golden treadmill | double Stride: **150 Gems**, once |

Stride: a point a second on a treadmill (two on the golden one); 11 levels; **+3.5% speed a level**,
inside the residence only; never above 62.

## 3. The Maison Basement (the Obsidian Room)

- Each checkpoint, first time in a run: **15 + 5 × n** Gilt (920 for all sixteen).
- Each part's end, to the Estate: **600 / 1,500 / 3,000 / 5,000** (10,100 in all; 2,020 of it as
  Gilt through the cash share).
- The Treasury's chest: **10 Gems** the first clear of the day, **3** after (25 a day at most);
  Topo Tesoriere the first time ever; an invitation to the Executive Suite every clear.
- A skip: **25 Gems**, or a Robux skip (reference price 19) when it's on sale. A skipped stage pays
  nothing and a skipped run is never timed for the boards. The Treasury can't be skipped to.

## 4. The Executive Suite (the Midnight Room)

- An invitation: earned (a Basement clear, a haul of 8,000+), **25,000 Gilt**, or from the owner;
  5 held at most. No chance, no Robux.
- Gear (Gilt, one run): disguise 4,000, decoy 2,500, scanner 3,000, vest 5,000. The sidearm is free.
- Beating the Executive: **25,000** to the Estate and **15 Gems** (20 a day at most) for everyone in
  the Office; Il Dirigente Supremo the first time; the safe, once each: **6,000** to the Estate.

## 5. The Grand Auction (the Library)

- Three lots a week (and a season's), the same in every server; one of a kind, never sold.
- Opening bids **4,000 to 12,000 Gilt**, or **40 to 60 Gems**; each bid at least **5%** more
  (rounded up to 100 Gilt or 5 Gems).
- A bid is taken from the purse when it stands and returned in full when it's beaten.

## 6. Objectives

| | Reward | Typical goal |
|---|---|---|
| The Evening Commission | 150 Gilt | bank two hauls; bank 5,000; reach the Treasury |
| The Week's Commission | 600 Gilt | bank 12 hauls; bank 60,000; beat the Executive |
| The Season's Commission | 5,000 Gilt | bank 500,000; reach the Treasury 15 times |

## 7. Faucets and sinks (estimates to check against live data)

**Faucets.** A good Long Gallery haul (four pieces, ~1,600 each) is ~6,400 to the Estate and
~1,280 Gilt; at about three minutes a haul that is ~128,000 Estate and ~25,000 Gilt an hour
before the soft cap. A Basement clear is 10,100 Estate and ~2,900 Gilt for five to eight minutes.
The Executive is 31,000 Estate for a party's twenty to thirty minutes.

**Sinks.** Luxe upgrades total 190,500 Gilt (and 150 Gems for the golden treadmill); an invitation is 25,000; gear 2,500 to 5,000 a
run; auction lots are open-ended (each week's three lots should absorb the richest players' Gilt);
the Boutique and Gem Shop as before.

**What to watch.** The Estate can grow without limit by design (it's the score). Watch Gilt in
circulation: if median Gilt keeps rising week on week, raise auction opening bids or the
invitation price before touching rewards. If the Executive is rarely attempted, lower the
invitation price or the 8,000 haul mark. All of these are Config values.

## 8. Wealth ranks

Newcomer 0 · Climber 1,000 · Affluent 5,000 · Wealthy 15,000 · Magnate 40,000 · Tycoon 100,000 ·
Baron 250,000 · Mogul 600,000 · Billionaire 1,500,000 · Sovereign of the Maison 5,000,000.

## 9. Luxury Island

- **The Island Key**: the wealth rank of Tycoon first, then **25,000 Gilt** or **250 Gems**, the
  price shown before buying. Once, for good.
- **The day's pearls**: five on the lagoon's floor, the same places for everyone that day,
  **250 Gilt** each, and **2 Gems** for all five. **10 Gems** a day at most from the island.
- **The sunset toast**: **300 Gilt** once a day, **+50** for each friend who toasts within the
  same three minutes (four counted at most).
- **Postcards**: six spots; all six bring a badge and **1,000 Gilt**, once.
- **The Pearl Exchange** (Suite pieces for pearls): the shell lamp 15, the palm lounger 30, the
  coral throne 60, the pearl chandelier 120.
- **Jet liveries** (a look only, never faster): Riviera 12,000 Gilt, Champagne 30,000 Gilt,
  Emerald Club 120 Gems, Rosé 180 Gems; **Midnight Aurora** (reference 149 Robux) and **Sovereign
  Gold** (reference 349 Robux), each sold only once its product exists.
- **Island lights**: Azure Noon 8,000 Gilt, Rosé Dawn 60 Gems, Moonlit 20,000 Gilt.

## 10. The Grand Ballroom (through the Ballroom's great doors)

| Activity | Gilt |
|---|---|
| The dance floor | 8 a minute, ten minutes a day |
| Luxury Trivia | 12 each right answer, 150 for the win |
| The runway | 30 for walking, 8 for voting, 200 for the win |
| The Daily Arena | 25 for taking part, 1 a point (40 at most), 150 for the win |
| The photo sets | 25 for the first pose at each set, each day |

- **2,500 Gilt** a day at most from the whole hall. **1 Gem** for each win, **3 a day** at most.
- Nothing in the hall is bought or random. Winning is answering, walking, voting and playing.

## 11. Racing

- Racing points: **3** to finish, **+3** on the podium, **+6** for the win, **+2** for a personal
  best, **1** a timed lap (20 laps a day count).
- Racing ranks (stripes on any car you drive): Rookie 0, Club Racer 40, Pro 150, Ace 400,
  Champion 1,000, Legend 2,500.

## 12. Maison Prestige (no reset, ever)

- Laurel points from the Badge Book: **1** a bronze badge, **2** silver, **4** gold, **8** platinum.
- Ten laurels at 12, 30, 55, 90, 135, 185, 245, 310, 380 and 460 points. From the fourth up, each
  also needs one great deed: the Treasury, the Executive beaten, the Island Key, an auction lot
  won, a Grand Prix won, then the Billionaire and Sovereign ranks.
- What they bring is a look: titles, borders, a flourish, Suite pieces, the Prestige Plinth. No
  Gilt, Gems or advantage. Nothing is taken away to reach one.

## 13. The displays

- **The Vault's display**: four featured curios, an arrangement, the collection's completion and
  the last forty arrivals. Free.
- **Suite themes**: Maison Noir (free), Ivory Salon **15,000 Gilt**, Emerald Study **20,000 Gilt**,
  Rosé **120 Gems**, Midnight Blue **150 Gems**; Island White with the Island Key, the Laurel Rooms
  with the fourth laurel. Paid once, the price shown first, all of it or none.

## 14. The daily streak

- Days in a row (UTC): each Gilt earned counts for **5% more** a day after the first, up to
  **30%** from the seventh day. A missed day starts it again at one (the best is kept).
- Gems from the house: **5** at three days, **15** at seven, **30** at fourteen, **60** at thirty
  and every thirty days after.
- The streak joins the other boosts, and all of them together stay under the house's one cap.

## 15. Trading money

- Gilt and Gems can be part of a trade: **100,000 Gilt** and **100 Gems** at most on one side, and
  **300 Gems** a day sent at most.
- Gems, and curios bought with Gems, change hands only where Roblox's policies allow trading
  paid items for both guests. Wardrobe pieces stay with whoever bought them.

## 16. The Boutique's terms

Every offer says what it is before it's bought: **Permanent: yours for good**, **Timed** (how
long, and whether the clock runs only while you play), **One use** or **At once**, with the
bundle's contents listed. A Gilt purchase asks once more, with the price, before it's taken.
There are no countdowns on offers, no "was" prices and nothing random for Robux.

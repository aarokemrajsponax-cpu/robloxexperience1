# Trend Watch

How Maison Noir keeps up with what's popular without copying anyone. The rule underneath all of
it: **trends are inspiration only.** The house borrows a *format* (a mechanic, an event shape, a
season's mood) and builds its own version, with its own names, characters, art and music.

## In the game: LIVE OPS → TREND WATCH

The owner's console (the existing one: the **LIVE OPS** page, below the month ahead) has two parts.

- **TREND WATCH**: what guests did most today (since midnight UTC), counted in every server, beside
  yesterday, with the change. These are the house's own numbers: visits, each attraction, the
  Grand Ballroom's trivia, runway and arena, races, trades, curios, salutes, the tables and more.
  Each server keeps its counts and adds them to its own part of the day's record every two minutes
  (one DataStore write; the console adds the parts together; `server/TrendWatch.luau`). Admins can
  read the numbers. Only the owner sees the ideas.
- **TREND IDEAS**: the owner's own notes on trends worth borrowing from, kept for every server.
  Each one is an **idea** until the owner **approves** or **declines** it, and can be removed.
  Approving one changes nothing in the game. It's a note for whoever builds the next update, and
  every change to the list is written in the audit log.

**No outside trend source is connected.** The console says so. Nothing in the game claims to know
what's popular anywhere else, and nothing reads the web. If one is ever connected
(`TrendWatch.SOURCE`), it must be cached and rate-limited, its key kept in the experience's
Secrets (never in code), and its ideas still wait for the owner's approval.

## The borrowing rules

1. Borrow the **shape**, never the **property**: no other game's name, characters, logos, art,
   music, sounds, maps or catchphrases, and no real brands (a "chase" format, yes; a carmaker's
   car, no).
2. Make it the house's own: luxury, gold and noir, the Maison's voice, the Maison's places.
3. Same standards as everything else: the price is always shown first, nothing is ever random for
   money, no gambling, no countdowns that pressure and no fake discounts.
4. Every idea goes on the TREND IDEAS list first. It's built only once the owner approves it.

## What's popular on Roblox (researched 11 November 2026)

Charts move daily, and most figures below come from third-party trackers that read Roblox's own
charts at different moments. They're **snapshots, not live data**. Check Roblox's own Charts page
before relying on any of them.

- **Most played right now.** A snapshot on 9 November 2026 of Roblox's "Top Playing Now" chart put
  *Steal an Egg* first (about 814,000 players), then *Murder Mystery 2* (about 487,000),
  *Brookhaven RP* (about 396,000) and *Blox Fruits* (about 253,000). [1]
- **Top earning (estimates).** One November 2026 list puts *Anime Adventures*, *RIVALS* and *Moped
  Drag* at the top. [2]
- **Fastest growing.** A chart ranking by how fast player counts are rising (data as of 4
  November) surfaced *DONT SPLASH* and *Tesla Roadster Chase*. [3]
- **All-time context.** *99 Nights in the Forest*, a survival-horror game, is reported to have
  peaked at 14.2 million concurrent users. [4]
- **Fashion and runway.** *Dress to Impress* (a themed dress-up runway with voting) remains one of
  the platform's best-known games. [5] Community guides say its theme voting was removed in May
  2026, so treat older guides with care. [6]
- **The "steal" format.** *Steal an Egg*'s loop, as guides describe it: take eggs from guarded
  nests, carry them home (it only counts once you're back in your own base), hatch them into pets
  that earn over time, and combine three of the same for a rarer one. Speed gates the further
  areas, and a night window speeds growth. [7]
- **Roblox's own direction.** In March 2026 Roblox launched **Incubator** and **Jumpstart** for
  "novel games": new genres, mechanics or visual styles. At RDC 2026 it said both would grow, with
  RPG, strategy and shooter games named, aimed partly at players over 18. [8] [9]
- **Genres (secondary sources, figures inconsistent).** Roleplay and casual simulators remain the
  base. Survival-horror is rising. Hybrids that suit casual and dedicated players do well. Short,
  rewarding loops and phone-first pacing keep coming up, and so does co-play (friends invited
  together). [10] [11]
- **Daily rewards (no official benchmark).** Developers report that daily rewards help a little,
  but warn against making them the main reason to come back. A one-day miss that wipes a long
  streak feels harsh. Tie rewards to the game's own loop. [12] [13]

## Where the house already stands

| Trend | Maison Noir's own version |
| --- | --- |
| The "steal" format | **Steal a Luxe**: a residence, guards, a getaway car to bank at, Stride training |
| Fashion runways | **The Grand Ballroom's runway**: twelve of the house's own themes, guests vote |
| Collect and show off | **Curios** and the **Vault's display**: four domes, completion, history, privacy |
| Racing and chases | **The Grand Prix** and timed laps on two circuits, with server-checked gates |
| Obbies | **The Maison Basement**: sixteen stages down to the Treasury |
| Co-play | More Gilt while a friend is in the house, Suite invitations, trading, the Ballroom's group games |
| Coming back daily | **The daily streak**: a little more Gilt each day in a row, Gems at milestones |
| Seasons | Holidays that dress the house *and* the inside of every attraction |

## Ideas for the TREND IDEAS list (not in the game)

These are suggestions only. None is built, and each would go on the list for the owner to decide.

- **A night window for Steal a Luxe** (from the night-growth idea above): one hour each evening when
  the residence pays a little more, shown on the HUD with its real end time.
- **A Boulevard chase** (from the chase format): one guest with a gold car, the rest chasing, in the
  house's own cars. No real brands.
- **A gentle fright for All Hallows'** (from survival-horror): a lights-low evening in the Basement
  with pumpkin lanterns to find. Atmosphere, never gore.
- **Friends' rounds** (from co-play; the house already pays more while a friend is in): a pair's
  run in the Basement, or friends on the same side in the Daily Arena.
- **An RPG thread** (from Roblox's novel-games direction): the Concierge's stories as short
  chapters, earned by playing the attractions.

## Keeping this current

- Look again monthly, starting with Roblox's own Charts page, and update this file with dates and
  sources.
- Compare with the house's own numbers on TREND WATCH. They're the only figures that say what
  *these* guests enjoy.
- Never write a trend down without a source and a date, and never present a snapshot as live.

## Sources (read 11 November 2026)

1. Endgame Tools, "Most played Roblox games right now" (snapshot 9 November 2026):
   https://endgametools.com/en/roblox/charts
2. Bloxrant, "Top Earning Roblox Games List (November 2026)":
   https://bloxrant.com/roblox-top-earning-games
3. StoreSignal, "Roblox Top Trending Experiences": https://www.storesignal.io/roblox/charts
4. Wikipedia, "List of Roblox games": https://en.wikipedia.org/wiki/List_of_Roblox_games
5. Wikipedia, "Dress to Impress (video game)":
   https://en.wikipedia.org/wiki/Dress_to_Impress_(video_game)
6. RBLX Guide, "Dress to Impress themes guide":
   https://rblxguide.com/games/dress-to-impress/updates/themes-guide
7. All Things How, "Steal an Egg beginner guide":
   https://allthings.how/steal-an-egg-beginner-guide-biomes-speed-and-pets-explained/
8. Roblox Newsroom, "Roblox announces Incubator and Jumpstart creator programs" (March 2026):
   https://about.roblox.com/newsroom/2026/03/roblox-announces-incubator-jumpstart-creator-programs
9. GamesBeat, "Roblox plans to expand its Incubator and Jumpstart programs":
   https://gamesbeat.com/roblox-plans-to-expand-its-incubator-and-jumpstart-programs/
10. ExitLag, "Roblox Game Genres and Popularity":
    https://www.exitlag.com/blog/roblox-game-genres-and-popularity/
11. RoWatcher, "Roblox Genre Opportunity Map 2026":
    https://rowatcher.com/news/roblox-genre-opportunity-map-2026-where-smart-developers-are-building-next
12. Roblox Developer Forum, "Do daily rewards actually keep players retention?":
    https://devforum.roblox.com/t/do-daily-rewards-actually-keep-players-retention/3556728
13. RoWatcher, "Daily Login Bonuses Are Lazy Design — Here's What Works Instead":
    https://rowatcher.com/news/daily-login-bonuses-are-lazy-design-here-s-what-works-instead

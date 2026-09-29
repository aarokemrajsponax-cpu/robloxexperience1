# Maison Noir — Roblox Edition

*A table covered in expensive things, and somewhere to put all of it.*
development of AJKR

This repository is the whole experience. Rojo syncs it into Roblox Studio; nothing is built
by hand in Studio. The house is built by the server when it starts.

## Connecting to Studio (each session)

1. Open the project folder (the one with `rojo.exe` and `src`), click the address bar, type
   `powershell`, press **Enter**.
2. Paste this and press **Enter**:
   ```powershell
   irm https://raw.githubusercontent.com/aarokemrajsponax-cpu/robloxexperience1/claude/nice-brown-a88p9r/play.ps1 | iex
   ```
3. In Studio: the **Rojo** button → **Connect** → **Accept**.

Leave that window open. Every change pushed to the branch reaches Studio within seconds.

## What's in Delivery 1 — the dream slice

- **The Street** at night: wet stone and puddles, the narrow black townhouse, lamps, the brass
  plaque, a city skyline in the haze, and falling season weather (leaves in Harvest Nights).
- **The Grand Foyer**: black-and-bone marble, the brass chandelier, the grand piano, the
  Concierge's lectern, the Tonight board, the Wall of Names and the Livre d'Or, four room
  doors (only the Salon opens; the Midnight Room is roped), and the Grand Stair and the
  Boutique, both roped off.
- **The Concierge**: greets you, walks a first-time guest to the Salon (pausing if you fall
  behind), turns to look at you, answers when spoken to in a glass dialogue panel. **The
  Doorman** says "Evening." as you reach the door.
- **The Salon**: burgundy velvet, bookshelves, a fire, and **six working tables**. It has the
  composed table camera, the dealt 3D pieces, drag *or* tap to sort, the gold guide light,
  the climbing chime, the brass odometer counter and multiplier dial, the gilded round card,
  the round summary with a stamped hallmark, and banking to the board.
- **The engine underneath**: seeded deals decided by the server, every filing checked by the
  server, server scoring and grades, fair-play checks, saved profiles (session-locked with
  ProfileStore), settings saved to your profile, Gilt, Nights attended, the Register, one
  config module overlaid live by Roblox Configs, and the first-evening analytics funnel.
- **Intro, title, How to play, Settings, Leaderboard**: all in smoked glass with gold hairlines.

## What's in Delivery 2 — the four rooms and the Nightly

- **All four rooms** off the Foyer, each with six tables and its own look:
  - **The Velvet Room**: deep green walls, lamps on long cords, smoked mirrors, and a tall case
    clock whose hands keep your own time. The clock waits for your first lift.
  - **The Obsidian Room**: black stone, one hard key light over each table, gold only on the edges.
    Every case is open and lookalikes are dealt together.
  - **The Midnight Room**: ink blue, one small lamp per table, the city through a round window.
    Nothing is named and nothing is pointed out. Roped off until you reach round IV in Obsidian;
    then the Concierge tells you, and the door opens for you alone.
- **Timed rooms**: a slim brass rail on the table drains with the clock, turns amber in the last
  ten seconds, and freezes while a panel is open (never in the Nightly).
- **The Nightly**: one table for everyone on Roblox, every night at 00:00 UTC. The same five rounds
  and the same pieces for everyone, rules by weekday (Midnight Fridays). **Tonight's table** is a
  second prompt on every chair. One scored attempt a night, unlimited rehearsals after, and leaving
  early still counts. The **Nightly card** shows the date, the rules, your score, your grade, five
  round hallmarks, your place among your connections and your percentile, with **Share** (Roblox
  capture sharing with launch data) and **Invite** (a friend lands straight at tonight's table).
- **The Tonight board** in the Foyer: tonight's rules, how many guests have sat it, the top five,
  and the Salon's week. The **Leaderboard** now has Tonight plus every room, this week and all time.
- **The Concierge** asks which room and walks you to any of them (Midnight once earned), and tells
  returning guests "Tonight's table is laid." when they haven't sat it yet.

## What's in Delivery 3 — the Club Floor and the Library

- **The Grand Stair** opens to the **Club Floor**: a gallery hall with portraits, a chandelier and
  benches, the **Library** door on the left and the (still closed) **Ballroom** doors on the right.
- **The Library**: dark shelves to the ceiling, a rolling ladder, green reading lamps, and two
  long tables for **Tête-à-Tête**. Two guests sit at opposite ends; the same pieces are dealt to
  both felts; first to three hands takes the table.
  - Hands grow from 14 to 26 pieces and 4 to 6 open cases, with more lookalikes each hand.
  - **Parcels**: three in a row into one case (up to three per run), and a streak of 6, 10 and
    15, each send a sealed parcel of lookalikes across the table. It burns on a two-second fuse
    in your near corner, then spills onto your felt. Your own parcels cancel the ones waiting
    for you first.
  - A wrong case costs a **fumble**: your hand can't lift for 0.8 seconds.
  - Each hand is capped at 60 seconds (the brass rail drains); at the cap, fewer pieces left wins,
    then accuracy, then whoever filed last earlier.
  - You see your rival's felt at the far end of the table, their pieces going into their cases,
    and the brass counters show pieces left. The dial shows hands won.
  - **Ratings** (Glicko-2), **Marks** from Brass to Onyx shown after five placement evenings, and
    **Terms** by the quarter. Ranked needs the Member standing and an account three days old;
    everything else is friendly.
  - Waiting alone for 25 seconds, the Concierge offers a **Stand-in**: a hollow figure fitted to
    your rating. Clearly marked, never ranked.
  - Leaving mid-evening hands the table to the other guest. **Another** asks your rival for a
    rematch.
  - **The queue**: guests waiting alone at different tables are paired by rating (±100,
    widening by 50 every 5 seconds up to ±400); the later guest is shown across to the other
    table. Ranked guests with nobody near their level play friendly once the window is wide.
  - **Invite to the Library**: from the Concierge ("The Library" → "Invite a friend") or the
    "Invite a friend" key while you wait. Your chair is kept for two minutes; the friend lands
    in the Library and is seated opposite you. Invited evenings are friendly.
  - **A dropped connection** holds the chair for 20 seconds and pauses the hand; back in time,
    the guest is seated again with the felt as they left it. Otherwise it's a forfeit.
  - Ranked evenings are written as a loss the moment they start and corrected at the end, so
    leaving can never dodge a result.
  - The **Leaderboard** has a Library tab with ratings.
- **Rivals**: once a week the house picks you a rival from your Roblox connections who play
  here, closest to you in the Library (or whoever was here most recently), or else someone you
  played recently. A small brass plate on your table's rim carries their name and one fact
  (*"40 points ahead of you on tonight's table."*). Pass them and the plate turns, gold side up.

## What's in Delivery 4 — the Ballroom and Lights Out

- **The Ballroom**, through the tall doors on the right of the Club hall: a black-and-gold hall
  with a marble floor, mirrors, drapes and a great chandelier. **Twenty tables in a ring**, each
  under its own lamp on a long cord, each with a brass **dumbwaiter** that sends the pieces up.
  **The Gallery** runs above the entrance (a stair along the west wall), with benches for
  watching. The evening's board on the Gallery's front says what's happening.
- **Lights Out** (Appendix H3):
  - Sit in any chair and the evening **gathers for 30 seconds**; then **Stand-ins** fill every
    empty chair (hollow figures, paced across a range of skill). Twenty lamps, always.
  - The same six pieces open every felt; then the dumbwaiters send **the same piece to every
    felt** every 1.6 seconds, 0.1 s quicker every 20 seconds down to 0.6 s. Lookalikes grow from
    35% to 75%. Five cases, the sixth at 1:00. **Closing Time** at 5:00 tightens to 0.35 s.
  - A felt holds **sixteen**. Go over and your lamp flickers (the brass rail counts three
    seconds); get back under or **your lamp goes out** and the room grows a little darker.
  - **Parcels** as in the Library (at most four per run) go where your tab points: four brass
    tabs, **Random · Rivals · Leader · Nearly out** (Tab key, or the shoulder buttons).
  - **Keys**: a lamp that goes out within five seconds of your parcel landing gives you a Key
    and every Key it held. Keys make your parcels heavier (+25% at 2, up to +100% at 16), and
    the Key leader's lamp glints for everyone.
  - **Out?** A card offers **Watch from the Gallery**, **Next evening** (stay in your chair) or
    Leave. Guests standing in the Ballroom get **Next evening**, **Watch** (the camera drifts
    between the tables still lit) and **Invite** (a friend lands in the Gallery).
  - **The last lamp**: the whole Ballroom goes dark except the winner's lamp, every camera finds
    it from the Gallery, and the Concierge says *"The last lamp in the house is yours."*
  - With no real guest still lit, the evening ends at once and the next one gathers: fast
    re-entry first.
  - **Records** (Last Lamps, top-five finishes, Keys) and the **weekly board** (Soirée points:
    100 · 70 · 55 · 45 · 40 · 25 · 10 · 0, +8 per Key) count only evenings with at least eight
    real guests. Gilt is paid every evening.
  - **Live results from every server** on the Tonight board and in the leaderboard:
    *"Table 12 kept the last lamp with nine Keys."*

## Where things live

| Folder | What |
| --- | --- |
| `src/shared` | Rules used by server and client: `Config` (every tunable number), `Catalogue`, `Seasons`, `Rooms`, `Deal`, `Scoring`, `Clock`, `Nightly`, `Settings`, `Voice` (every line), `Layout` (where everything sits), `PieceModels` (the 3D pieces) |
| `src/server` | `Main` boots it; `World/` builds the house; `Staff/` the Concierge and Doorman; `TableService`, `Profiles`, `Boards`, `Season`, `LiveConfig`, `Analytics`, `Guests`, `Dialogue` |
| `src/client` | `Main` boots it; `UI/` every panel; `Table/` the table on your screen; `World/Ambient` (doors, weather, acoustics); `Camera`, `Sound`, `State` |
| `tests` | `run.luau` (the rules), `smoke.luau` (builds the house and walks it) |

## Changing a number without touching code

Every number is in `src/shared/Config.luau`. To change one live, without republishing, add it
in the Creator Dashboard under **Configs**, writing the path with underscores:
`Rooms_salon_firstDeal = 9`, `Movement_walkSpeed = 14`, `Assets_Music_foyer = rbxassetid://…`.

## Sounds and looks still to choose

The sounds are placeholders taken from Roblox's built-in click and landing sounds; the music
slots are empty. Put ids in `Config.Assets` (or in Configs as above):

| Slot | What it should sound like |
| --- | --- |
| `Sounds.chime` | one clean bell or glass note; the code pitches it up the streak |
| `Sounds.pickup` / `drop` | soft cloth lift, a felt tap |
| `Sounds.wrong` | a muted wooden knock, never a buzzer |
| `Sounds.round` / `complete` | a short warm two-note cadence; a longer one |
| `Sounds.door`, `chair` | a heavy door easing open; a chair on carpet |
| `Music.street` / `foyer` / `salon` | muffled city · jazz piano · soft deep house around 92 BPM |
| `Music.velvet` / `obsidian` / `midnight` | slower and brushed · minimal and taut · sparse piano and room tone |
| `Sounds.low` | the clock's last ten seconds: one soft low tick, played once |

**Staff looks** (`Config.Assets.Concierge` / `Doorman`): a black tailcoat shirt and trousers
(classic clothing ids), white gloves, and optionally a hair accessory. Until then they're
dressed from body colours with a shirt front, a tie, coat tails and the gold lapel key.

**Animations to make and publish under your account** (put their ids in
`Config.Assets.Animations`):

| Animation | Brief |
| --- | --- |
| Concierge idle | hands clasped behind the back, a slow weight shift, a glance down at the ledger |
| Bow | a slight, unhurried bow from the waist, one beat |
| Gesture | an open palm toward a doorway: "this way" |
| Walk-and-lead | an upright, measured walk, hands behind the back |
| Slow applause | three slow claps, chin slightly raised |
| Pianist playing | seated at the keys, gentle hands, a slight sway |
| Tailor folding | folding a garment on the counter, smoothing it once |
| Sitting at the table | settle into the chair, forearms toward the felt |

## Checks

`tools/check.sh` type-checks every script against Roblox's API, runs the rule tests, builds
the house under [Lune](https://github.com/lune-org/lune) and walks its routes, and plays whole
Tête-à-Tête evenings (`tests/duel.luau`) and Lights Out evenings (`tests/ballroom.luau`) against
the real server code on a fake clock, and boots
the whole client against the built house: title, Play, walking, a table by gamepad and by mouse,
the Nightly card, a Tête-à-Tête and a Lights Out evening on screen, and the panels
(`tests/client.luau`):

```sh
TOOLS=/path/to/tools ./tools/check.sh
```

## Building a place file without Studio

```sh
rojo build -o MaisonNoir.rbxl
```

© AJKR

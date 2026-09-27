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

## Where things live

| Folder | What |
| --- | --- |
| `src/shared` | Rules used by server and client: `Config` (every tunable number), `Catalogue`, `Seasons`, `Rooms`, `Deal`, `Scoring`, `Clock`, `Settings`, `Voice` (every line), `Layout` (where everything sits), `PieceModels` (the 3D pieces) |
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

`tools/check.sh` type-checks every script against Roblox's API, runs the rule tests and builds
the house under [Lune](https://github.com/lune-org/lune):

```sh
TOOLS=/path/to/tools ./tools/check.sh
```

## Building a place file without Studio

```sh
rojo build -o MaisonNoir.rbxl
```

© AJKR

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
- **The Concierge**: greets you, offers a first-time guest **the tour** (below), turns to look at
  you, answers when spoken to in a glass dialogue panel.
- **The tour** (the house's tutorial): a first-time guest is offered it on arrival, and anyone can
  ask for it later (press **E** at the Concierge → **Show me the house**). The Concierge walks you
  round the whole house: the Salon and the four rooms, Tonight's board, the Livre d'Or and
  Circles, the Vault, the Boutique
  (Gilt, the Wardrobe, the Ledger), then up the Grand Stair to the Library, the Ballroom and
  Lights Out, the Terrace and your Suite. At each stop the Concierge turns and explains it on a
  card (**Next / Back / End the tour**, sixteen in all) with a gold pin over the thing it means;
  between stops a gold line from you shows the way, and the Concierge waits if you fall behind.
  The last card offers to take you to a table. The guide is your own, drawn only on your screen
  (the house's Concierge is hidden from you meanwhile and stays at the lectern for everyone
  else), so any number of guests can take the tour at once. It walks a fixed route
  (`Layout.Tour`) at `Config.Tour.speed` and passes through nothing solid, so it can't get stuck.
  **The Doorman** says "Evening." as you reach the door.
- **The Salon**: burgundy velvet, bookshelves, a fire, and **six working tables**. It has the
  composed table camera, the dealt 3D pieces, drag *or* tap to sort, the gold guide trail,
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
  second prompt (F) on every chair in the Velvet, Obsidian and Midnight Rooms, never the Salon (the
  Salon has no clock, ever); the Tonight key seats you at one of those tables. The header says
  whose rules it plays by ("Tonight's table · The Velvet Room"). One scored attempt a night, unlimited rehearsals after, and leaving
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

## What's in Delivery 5 — the Boutique and the money

Robux buys style, never score. Nothing sold changes a deal, a clock, a guide, a rating, a Mark,
a Nightly attempt or a Mythic's odds.

- **The Boutique**, through open glass doors in the Foyer's back wall: mirror panels, glass
  counters lit from within, **the Tailor** behind the long counter (speak to them, or ring the
  bell), a **dress form** wearing the week's featured piece, **the Tailor's mirror** (your
  Wardrobe) and **the Ledger** open on a lectern.
- **The shelves**: six pieces a day and two featured each week (the same everywhere, turning at
  midnight UTC), the season's collection (a table style, a trail and a look, only in its
  season), the house's own pieces for **Gilt**, **the Gold Key**, the Leather-Bound Ledger and,
  in a guest's first week only, **the Introduction**.
- **What you can wear**: table styles (your felt and rims, at any table), lamp styles,
  guide-trail colours, nameplate frames (every guest now has an engraved nameplate, with their
  Mark after five ranked evenings), round-card backs, victory flourishes (a Library win, the last
  lamp), chimes, gestures (G or D-pad up) and house looks. Chimes, gestures and looks are only
  sold once their sound, animation or clothing is set in `Config.Assets`.
- **Gifts**: anything on the shelves can be bought for another guest in the house; the
  Concierge hands it over as a wrapped box. If they've left, the buyer keeps it as credit.
- **Receipts are idempotent**: a purchase is written into the profile, the profile is saved,
  and only then is Roblox told it was granted. A retried receipt never grants twice. One
  developer product per price tier; the server keeps the guest's choice with their profile and
  logs the item. A purchase with no choice on file becomes Boutique credit.
- **Prices are always read live** from Roblox (`MarketplaceService`), never written in text.
- **The Gold Key** (a pass): the gold-edged nameplate, three looks, the chair and table trim,
  and +20% on all Gilt.
- **The Ledger**: fifty pages a Term, 1,000 points a page, turned by everything you play
  (3 a filing, 300 for the Nightly, 150 a Library evening +100 a win, 150 a Ballroom evening
  +10 a place above 11th). The free row pays Gilt and a cosmetic every fifth page, and the Term's
  gesture on page 50; the Leather-Bound row adds two pieces a page and the signature look.
  Bought late, it grants every page already reached. At these numbers a steady guest (30
  minutes, four nights a week) finishes around week 8; tune `Ledger.points.filing` live.
- **Settings** now open the Wardrobe and the Ledger too, and the Club settings are live: show
  my Mark, the Ballroom's default parcel tab, rival updates, and offering a Stand-in.
- Lights Out now pays Gilt as Appendix I1: 20 + 4 × (21 − your place).

## What's in Delivery 6 — the Register, the Vault, Mythics, Standing, Commissions, badges

- **The Vault**, through the Foyer's back wall left of the stair: six tall glass cabinets (one
  per case) that fill with the pieces **you** have filed as you walk in, and a centre cabinet
  for your Mythics with their serial numbers. **The Archivist** keeps the Register at a desk by
  the door: *"Everything you've found is kept here."*
- **The Register** is a book: a page for you (House Standing and what the next one needs,
  pieces found, badges, the Commissions), a page per case, the seasonal pieces and the Mythics.
  Every piece is its real 3D model turning in the page; unfound pieces are shadows. The Mythic
  odds are printed, per room.
- **Mythics**: filing one gives it a serial number from a count shared by every server
  (*Black Diamond · No. 00412*); the Concierge tells you, and every server's Tonight board
  announces it.
- **House Standing**: Guest → Member → Patron → Connoisseur → Custodian → Keeper of the House;
  the Concierge tells you when you rise.
- **The Evening Commission** and **the Week's Commission**: one gentle goal a day and a bigger
  one a week, the same for everyone (*"File twelve pieces of jewelry in the Velvet Room"*).
  150 and 600 Gilt, and Ledger points. Missing either costs nothing.
- **Badges** (§11): first round, first Flawless, Midnight unlocked, a season's full set,
  Register milestones (10, 25, 50), first Nightly, first Library win, first Last Lamp, a Mark,
  a Mythic, the Founding Term. Each needs a badge created in the Creator Dashboard and its id in
  `Config.Badges`; `Config.FoundingTerm` names the first Term at launch.

## Delivery 8, first part — the house comes alive, and the Soirée

- **The Concierge notices you**: the Concierge, the Tailor and the Archivist turn their heads
  toward you as you pass (on your own screen, so everyone is looked at). A new guest lingering
  in the Foyer for 25 seconds is walked over to and offered the way to a table. A new House
  Standing or Mark: *"The house has noticed."*
- **The Club Floor's own how-to-play**, the first time you climb the stair: *Same pieces, both
  of you · Three in a row sends a parcel · Keep your lamp lit.*
- **Share** keys at the moments worth sharing (a Last Lamp, a Library win or new Mark, a
  Flawless round), with launch data so a friend lands in the right room.
- **The Soirée**, every weekend (Saturday to Monday, UTC), alternating Ballroom and Library
  weekends; holiday windows re-dress it (*The All Hallows Soirée*). Your best five Ballroom
  evenings or fifteen Library evenings count (Appendix H5 points). Three plays earn the Soirée's
  stamp; after the weekend the top 1% get **the Soirée Medal** (a dated nameplate frame, never
  sold) and the top 10% a dated invitation card. A **gilded countdown board** by the Grand Stair
  (the only clock in the Foyer) and a Soirée tab on the leaderboard.

## Deliveries 8 and 9 — the rest of the house

- **Music that moves with the house.** Every space has its own track, crossfading as you walk.
  The Foyer's music comes **from the grand piano itself**: heard in the Foyer, muffled through
  the street door and up the stair, brighter on a Soirée weekend. **The Pianist** sits at the
  keys (swaying until the Pianist animation is published). A room's music fills out as the run
  builds (`min(1, 0.25 + round × 0.12)`), and the **Ballroom band thins as lamps go out**: the
  whole band, bass and brushes at ten, a single piano and a ticking clock for the final two
  (`Config.Assets.Band`). Ambience per space plus a seasonal layer. Numbers in `Config.Music`.
- **A Private Evening** (a private server): nothing counts for records (no boards, no ranked
  Library, no counted Ballroom evenings, no Soirée; the Nightly plays as a rehearsal). The host
  asks the Concierge to **Set the evening**: the Ballroom's pace, and whether Stand-ins fill the
  empty chairs. `Config.Private`.
- **The Black Card**, a card on the Concierge's lectern (a monthly Roblox subscription): the
  Leather-Bound Ledger while held, one cardholder look each month to keep, a black-lacquer
  nameplate. Hidden in a guest's first ten minutes and until its id is set
  (`Config.Products.blackCard`).
- **The Terrace**, on the Obsidian Room's roof, through French doors in the Club hall's east
  wall. The doors open only in High Summer; weather falls on it for real.
- **The house dresses for every season**: lanterns for All Hallows (and Lights Out by
  candlelight), garlands and a wreath for Yuletide (and wrapped parcels with ribbon fuses),
  copper candelabra for The Long Table, flowers in the season's colour all year.
- **Your Suite**, on the Velvet Room's roof through the Club hall's west door: eleven spots, nineteen
  pieces (Gilt, the Boutique, Standing, the Introduction's painting, the Gold Key chair), the
  bell to furnish it, the wardrobe where your looks hang. The Gold Key opens the Dressing Room
  and the Study. Each guest sees only their own Suite, and nobody else in it.
  - **The bell's page says plainly how it works**: what the Suite is, three numbered steps (get a
    piece, change a spot with ‹ ›, the Gold Key adds two rooms), how many spots hold your own
    pieces and your Gilt. Each spot shows what stands there and up to two pieces you could put
    there with a key to buy one (Gilt pieces any day; Robux pieces when they're on the Boutique's
    shelves). A piece you buy goes straight into its spot if the spot is empty. The Gold Key's
    rooms say what they hold, with a key to see the Gold Key. The first time you walk in, a note
    says to ring the bell.
- **Circles** at the Livre d'Or: names chosen from word lists, a crest from 12 emblems × 8
  colours (each crest one Circle's), 2,000 Gilt to found. Join by invitation or by asking the
  host. The week is the five best members' points; the top Circles hang on the Tonight board and
  have their own board tab; the crest sits on the nameplate. `Config.Circles.enabled` turns it off.
- **Notifications**: the opt-in is asked for once, after a first Nightly. At most one a day:
  your rival passed you, the Soirée has started, the Term ends in three days. Each needs its
  template id in `Config.Notifications.messages` and the Open Cloud key in the experience's
  secrets (see the launch kit).
- **The launch kit**: page text, icon, thumbnails and the gameplay video's shot list are in
  [`LAUNCH.md`](LAUNCH.md).

## Play it, sell it, host it, feel at home in it

- **Playing, in Studio and live.** Press **Play** and you're your own character at once: Roblox's
  own camera (zoom right in or out) and controls, walking from the first second. Studio shows the
  build in the bottom-left corner and prints it in Output (`[Maison] Build 31 ...`), so you can see
  Studio has the latest code. The live game plays the intro over the house (any key skips it);
  the old title screen is off (`Config.Title.show`). Roblox never spawns anyone by itself
  (`Players.CharacterAutoLoads` is off in the Rojo project and at the very top of the server), so
  nobody lands inside the Foyer's floor behind the front doors; every guest is placed in the
  Foyer, in the light (`Config.Movement.firstArrival = "street"` brings back the walk in from the
  street on a first visit). Guests and staff stand at 80% of Roblox's size
  (`Config.Movement.guestScale`), so every room feels a size bigger. Every part of the house starts on its own, so one that fails
  is reported in Output and never stops anyone from walking in, and a separate safety script
  hands back Roblox's own camera, controls and prompts if the house's client ever doesn't start.
- **The guide on the sorting screen.** Pick a piece up and, in the rooms that help you (the Salon
  and the Velvet Room at once, Obsidian after a moment, never in Midnight), a thread of gold light
  runs from it to its case with sparkles twinkling along it and a brighter pulse running toward
  the case, the case lights up, and a gold arrow bobs over it. A carried piece sheds a few
  sparkles in every room. It follows Settings → The guide (Show the way: Always / After a moment
  / Never; Trail: Sparkles / Ribbon / Comet / Runway / Case only; colour; pace) and Glow and
  sparks. A trail bought in the Boutique or won in the Ledger colours it, and a table style and a
  lamp you wear colour the sorting screen's cloth, its edges and its lamplight.
- **Ways to spend Robux**, all style, spectacle or gifts, never score:
  - **Salutes** (a brass card on the piano, and a Salutes tab in the Boutique): a moment bought
    for the whole house. Gold leaf over every guest (49), an encore with a spotlight on you (79),
    every lamp flaring (99), fireworks over the roofs (149), or the Grand Salute: all four,
    announced in every house (399). The giver's name goes on the Tonight board, with a gold star on
    their nameplate for half an hour. Also offered after you keep the last lamp.
  - **Always here**: seven staples always on the Boutique's shelves, beside the daily six and the
    week's two; seventeen more pieces (felts up to the Gilded Baize at 599, lamps, threads,
    nameplates, card backs, flourishes, Suite pieces).
  - **Gifts**: any piece for another guest; **give the Gold Key** to someone; admire a guest and
    choose them a gift from what they'd like.
  - The Gold Key now also opens **the Terrace all year**.
  - **Five more** (Build 30), on one receipt processor and purchase ledger with everything else
    (how it all works, and Roblox's limits it's built around: [`MONETIZATION.md`](MONETIZATION.md)):
    - **God-Mode Luck** (199): 2.5× Gilt and Ledger pages for 30 minutes of play; buying again
      adds 30 more; the time only runs while you're in the house (a chip counts it down). Never a
      score or a Mythic's odds.
    - **Chronos Defiance** (49): when the clock runs out in the Velvet Room, Obsidian or
      Midnight, a card offers +15 seconds for ten real seconds (the countdown waits while
      Roblox's purchase window is open). One per round, three per run; the boards keep your score
      from before the revive, and Gilt counts the whole run. A revive bought too late is kept for
      the next run.
    - **Emperor's Decree** (149): write a line (or choose one of the house's), see it exactly as
      Roblox's filter returns it, then proclaim it: gold on every screen in the server for 8
      seconds under your display name and @username. One every 20 seconds per server, one every
      2 minutes per guest, logged for moderation.
    - **Megalodon Rainmaker** (699): gold rains on the server: every guest gets 150 Gilt (once
      per rain, guests arriving during it too), the buyer 500 more, and everyone sees *"NAME
      triggered MEGALODON RAIN!"*. Rains take turns, two minutes apart.
    - **VIP Velocity Elite** (499, a game pass, or the same as a developer product): 1.5×
      walking and running and a gold trail, for good; both switch off in Settings → Your perks.
  - Every remote a guest's screen can call is rate-limited and checked on the server
    (`Config.RemoteLimits`); a screen can only ever name a product, never a price or an amount.
- **House controls** (the owner's panel): only you see the **House** key (or press **;**).
  Events (Golden Hour, Lucky Hour, the Page-Turner, a Night of Giants, the Quickstep,
  Featherlight, Gold Rain, a Treasure Hunt), in this house or every house, for 5/15/30 minutes;
  any Salute for free; another season for a while; crown a Guest of Honour, spotlight, bring,
  gift Gilt to one guest or everyone, or show someone out; announcements (typed ones filtered by
  Roblox) here or everywhere; and a summons that invites guests in every house to join yours.
  Events change Gilt, Ledger pages and Mythic luck, never a score. Other trusted people:
  `Config.Admin.userIds`.
  - **Admin Abuse Night** (Events, at the top): every event at once with fireworks, for 15, 30
    or 60 minutes; switch on **Every house** first to run it in every server.
  - **Schedule**: pick an event (or Admin Abuse Night), a day and a time in your own clock and a
    length, then **Schedule**. Every server starts it on time, whether you're in the game or
    not, and for the hour before, every player sees "ADMIN ABUSE NIGHT STARTS IN 12:34" at the
    top of the screen. Cancel any from the same page. (Saved in a DataStore: in Studio, turn on
    Game Settings → Security → Enable Studio Access to API Services to try it there.)
  - Anything that breaks shows in a small red panel in the corner of your screen (only yours),
    so a screenshot is enough to say what went wrong. Studio's "can't save" errors
    (StudioAccessToApisNotAllowed) are folded into one line that says how to switch saving on:
    **Home → Game Settings → Security → Enable Studio Access to API Services → Save**. The live
    game always saves; this only matters in Studio.
- **Feeling at home**: the Concierge remembers your last highlight, your milestones and who
  admired you; the table you use most carries your name while you're here and is offered as
  "your usual"; walk up to any guest and **Admire** them (R, or L1); sign the **Livre d'Or** once
  a night with a chosen line for the next guests to read.
- **Photo mode** (Settings → Photo): a free camera, depth of field, film grades, your gesture,
  and a clean capture with the MAISON NOIR mark, shared through Roblox.

## Where things live

| Folder | What |
| --- | --- |
| `src/shared` | Rules used by server and client: `Config` (every tunable number), `ProductConfig` (every product: price tier, reward, rules, how it's shown), `Catalogue`, `Seasons`, `Rooms`, `Deal`, `Scoring`, `Clock`, `Nightly`, `Settings`, `Speed`, `Voice` (every line), `Layout` (where everything sits), `PieceModels` (the 3D pieces) |
| `src/server` | `Main` boots it; `World/` builds the house; `Staff/` the Concierge and Doorman; `Purchases/` every Robux purchase (receipts, the ledger, the five products); `RemoteGuard` (rate limits); `TableService`, `Profiles`, `Boards`, `Season`, `LiveConfig`, `Analytics`, `Guests`, `Dialogue`, `Shop` |
| `src/client` | `Main` boots it; `UI/` every panel; `Table/` the table on your screen; `World/Ambient` (doors, weather, acoustics); `Camera`, `Sound`, `State` |
| `tests` | `run.luau` (the rules), `smoke.luau` (builds the house, dresses it for every season and walks it), `duel`, `ballroom`, `shop`, `purchases`, `client` (`harness.luau`: the fake Roblox the money tests share) |

## Changing a number without touching code

Every number is in `src/shared/Config.luau`. To change one live, without republishing, add it
in the Creator Dashboard under **Configs**, writing the path with underscores:
`Rooms_salon_firstDeal = 9`, `Movement_walkSpeed = 14`, `Assets_Music_foyer = rbxassetid://…`.

## Music and sounds (nothing to upload)

The house has music and table sounds the moment it opens, with nothing to upload: real
recordings from Roblox's own licensed libraries, free to use in any experience.

- **Music** (`Assets.Playlists`): three playlists from Roblox's licensed APM Music library.
  Each plays through in a shuffled order, every guest starting somewhere different, with a
  breath between songs and each song levelled to the others.
  - `lounge`: solo piano (Alan Hawkshaw's *Cocktail Time* and more), played from the Foyer's
    grand piano and heard in the Suite, the Vault and on the Terrace.
  - `table`: a cool-jazz trio (Paul Reeves' *Intimate Jazz Trio*) in the four sorting rooms and
    the Library.
  - `ballroom`: waltzes (Strauss, Tchaikovsky, *Skater's Waltz*).

  Every song is listed in Config with its title and artist. Swap any for another Creator Store
  track by pasting its id.
- **Table sounds** (`Assets.LibrarySounds`): recordings from Roblox's licensed Pro Sound Effects
  library and Roblox's own UI sounds:
  - a dice-on-felt knock as a piece settles into its case;
  - a dull wooden knock for a wrong case;
  - leather as you sit down;
  - a clean chime that climbs a step with each piece in a streak.

  Each has the pitch and level that suit it.

### Optional: the house's own composed audio (`assets/audio`)

The repo also holds original audio composed for the game by `tools/audio/compose.py`, so it
belongs to the game and needs no licence:

| File | What it is | Used for |
| --- | --- | --- |
| `maison-sounds.ogg` | every table sound in one sheet: 25 sounds, 68 takes, so the same action never sounds the same twice | `Assets.SoundSheet`: once set, it replaces the library's table sounds, and the Boutique's four chimes go on sale |
| `maison-lounge.ogg` | a 107 s solo piano ballad, looped | `Assets.Tracks.lounge` (optional) |
| `maison-table.ogg` | a brushed jazz quartet at 96 bpm, 160 s loop | `Assets.Tracks.table` (optional) |
| `maison-ballroom.ogg` | a swing band at 132 bpm, 116 s loop | `Assets.Tracks.ballroom` (optional) |

To use the sheet (about two minutes, once):
1. In Studio: **View → Asset Manager → Bulk Import**.
2. Pick `maison-sounds.ogg` from `assets/audio` and wait for it to upload.
3. Drag it from the Asset Manager's **Audio** folder onto **SoundService** in the Explorer.
4. **File → Publish to Roblox**.

The game finds it by name, so there's no id to copy.

To use one of the composed loops in place of a playlist, paste its id into `Assets.Tracks.<name>`.
Never cut the sheet up or edit it by hand: `src/shared/SoundSheet.luau` says where each take
sits in it, and `python3 tools/audio/compose.py` rewrites both together.

Any slot can still take a Creator Store sound or track instead: a sound set by name in
`Assets.Sounds` wins over the sheet, and a room's own `Assets.Music.<room>` wins over the house
tracks. Optional extras:

| Slot | What it should sound like |
| --- | --- |
| `MusicLayers.<room>` | an optional fuller layer of the same track that rises as the run builds |
| `Band.full` / `bass` / `piano` / `clock` | the Ballroom's band in stems: all of it; bass and brushes; one piano; a ticking clock |
| `Ambience.<space>`, `SeasonAmbience.<season>` | rain on glass, the distant city; a fire (frost), crickets (summer) |

**Staff looks** (`Config.Assets.Concierge` / `Doorman` / `Pianist`): a black tailcoat shirt and trousers
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
| Pianist playing (`Animations.pianist`) | arms and upper body only (the code seats them): gentle hands along the keys, a slight sway |
| Tailor folding | folding a garment on the counter, smoothing it once |
| Sitting at the table | settle into the chair, forearms toward the felt |

## Checks

`tools/check.sh` type-checks every script against Roblox's API, runs the rule tests, builds
the house under [Lune](https://github.com/lune-org/lune) and walks its routes, and plays whole
Tête-à-Tête evenings (`tests/duel.luau`) and Lights Out evenings (`tests/ballroom.luau`) and the money (`tests/shop.luau`,
and the purchase system in `tests/purchases.luau`: replays, two servers, saves that don't land,
rollbacks, the risk check, the remotes and each of the five products) against
the real server code on a fake clock, and boots
the whole client against the built house: title, Play, walking, a table by gamepad and by mouse,
the Nightly card, a Tête-à-Tête and a Lights Out evening on screen, and the panels
(`tests/client.luau`, plus `studio` and `live` runs that boot it exactly as you and your guests
meet it; `tests/guests.luau` checks arriving, spawning and placing):

```sh
TOOLS=/path/to/tools ./tools/check.sh
```

## Building a place file without Studio

```sh
rojo build -o MaisonNoir.rbxl
```

© AJKR

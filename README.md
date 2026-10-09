# Maison Noir — Roblox Edition

*A table covered in expensive things, and somewhere to put all of it.*
development of AJKR

This repository is the whole experience. Rojo syncs it into Roblox Studio; nothing is built
by hand in Studio. The house is built by the server when it starts. The game page, the
questionnaire and the switches to flip are in `LAUNCH.md`; getting the word out (icon,
thumbnails, videos, posts, ads) is in `MARKETING.md`, with the pictures in `marketing/`.

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
  sold) and the top 10% a dated invitation card. Its countdown is the last line of the Foyer's
  **Tonight board** (the only clock in the Foyer), and there's a Soirée tab on the leaderboard.

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
- **Curios and your Collection** (the Menu, or M): 26 silly treasures in eight rarities, Common
  to Secret and Limited, including an original meme set (Croissantino Furioso, Le Roi
  Grenouille, Fromage de la Lune...). Found among the pieces after a banked run (with a little
  Gilt), from events and achievements, or bought in the Cabinet for Gems at a fixed price.
  Search, sort, rarity filter, stars, a card for each. A big reveal for each find, bigger for
  rarer ones. Gems come in three packs for Robux.
- **Trading curios**: admire a guest (R) → Trade. Both choose, lock in, a five-second countdown,
  then both confirm; any change unlocks both, so nothing changes after a confirmation. The
  server checks every step and swaps in one go. Cancel any time; block and report. Curios bought
  with Gems (Robux) trade only where Roblox's policy allows paid item trading for both guests
  (`server/Policy`: asked once per guest, and "no" until Roblox answers); the rest always trade.
- **Live events** (the owner's House panel, or scheduled): Golden Hour, Lucky Hour, the
  Page-Turner, Giants, Quickstep, Featherlight, Gold Rain (each coin also gives a Rain Coin
  curio), the Treasure Hunt, the Brainrot Parade (meme curios loose in the house to catch),
  Disco Night (a mirror ball and colour-cycling Ballroom lights; a Disco Ball curio), and a Night
  of Curios (finds twice as likely). Admin Abuse Night runs them all at once.
- **Suite spectacles**, played in your own Suite the moment you buy one (bought elsewhere, the
  moment you step back into your Suite; bought while a show is on, straight after it, since two
  never overlap; one saved from before plays from the bell): **fireworks** (a 45-second show
  over the whole estate; your camera goes out across the street to watch it, and comes back with
  the key or any step), the **Meme Takeover** (ninety seconds in six acts: a warning siren, a
  portal spewing memes that bounce off the walls (to an electro swing, with air horns, record
  scratches, party horns and a kazoo fanfare for the boss), a conga line dancing round you under disco
  lights, memes raining from the ceiling with confetti, a giant boss meme with laser eyes, then
  chaos and a confetti finale), or the **Golden Transformation**, the Midas touch (forty seconds,
  `World/Midas`): a temple gong, the lights sink, and a ring of gold runs out across the floor
  from where you stand, turning everything it passes to gold (floors, walls, ceilings, every
  piece of furniture, the fireplace); a heavenly choir, gold confetti fluttering through the
  rooms, gold coins raining from the ceiling and ringing as they land round you, shafts of light
  from above, the fire burning gold; a regal fanfare as a jewelled crown settles on your head;
  then the gold ebbs back and everything is exactly as it was. Only you see it.
- **The fireworks: a pyromusical** (`World/Fireworks`), the same for every show (Suite
  Fireworks, the Fireworks salute, the Grand Salute, the Midnight Finale), in three acts, each to
  its own score from Roblox's licensed library: **Hanabi** to taiko drums (Japanese
  chrysanthemums trailing gold, colour-changing peonies, double and triple petals, the thousand
  flowers, rings, Saturn, hearts and stars drawn in the sky, kamuro crowns of gold that hang and
  drip), **Liberty** to *Stars and Stripes Forever* (red, white and blue; thunderous white
  salutes, palms of gold comets with real tails, crackling dragon's eggs, brocade crowns,
  strobes, mines fired from the ground, and Niagara Falls pouring silver down the front of the
  house) and **Majesty** to Handel's *Music for the Royal Fireworks* (searchlights sweeping the
  sky, a canopy of gold, the barrage, the house's monogram written in gold stars, then a wall of
  golden willows over every roof, the *1812 Overture*'s last chords and a cheering crowd). A
  show under 55 seconds plays Hanabi and Majesty. Every star is a streak that stretches as it
  flies, with glitter tails, a white-hot flash and a shockwave; light floods the roofs, smoke
  drifts and catches the later bursts, and the thunder arrives a beat after the light. The
  house's music sinks under the score; slower graphics settings get fewer stars, never a stall
  (`Config.Fireworks`). The night air clears while it plays, and a **Watch the fireworks** key
  takes anyone's camera out across the street (the buyer's goes at once).
- **The quick dock** (left of the screen): **Collection** (C), **Trade** (T: everyone in the house
  with a Trade key each, and your past trades), **Wardrobe** (V), **Gems**, **Suites** (your own,
  or a friend's) and **Invite**, one tap away.
- **Friends together earn more**: while a friend on Roblox is in the same house, both earn 25%
  more Gilt (`Config.Friends.giltBoost`; the server checks the friendship, and the boost shows at
  the left edge: "FRIENDS HERE · +25% GILT").
- **The seasons, every year**: the calendar is the same every year (Harvest Nights, All Hallows,
  The Long Table, Yuletide, Midnight Toast, Deep Winter, Rose Hour, Emerald Hour, First Bloom,
  High Summer), and every Term has its own Limited curio with its year on it (Autumn 2026's
  Gilded Leaf, then the Frost Star, the Spring Blossom, the Summer Sun and the Harvest Moon for
  each season through 2031), each found only while its season is on and shown in the
  Collection once its season has come. `Config.FoundingTerm` is `2026-autumn`.
- **Friend invitations** (Roblox's friend referrals, `server/Referral`): the Invite key opens
  Roblox's own invite prompt. A friend who arrives for the first time through it gets 100 Gilt;
  whoever invited them gets 150 Gilt if they're in the house (any server) when the friend
  arrives, at most 5 a day and 50 in all, and only for Roblox accounts at least 7 days old
  (`Config.Referral`). Only Gilt, decided on the server from what Roblox says.
- **The Menu** (top of the screen): the Collection, Trading, Gems, the Boutique, Wardrobe,
  Ledger, Register, guest book, Circle, How to play, Settings.
- **The Terrace**, on the Obsidian Room's roof, through French doors in the Club hall's east
  wall, open every evening: café tables, sun loungers, a fire pit, the Gold Key's cabana, and
  the Terrace Bar (snacks and drinks for Gilt, none with alcohol; three house specials for
  Robux at the price shown). **You eat it yourself**: click (or tap, or F, or the Take a bite
  key) and your guest lifts it, takes a bite or a sip (crumbs or bubbles, a crunch or a gulp),
  and it gets smaller piece by piece until it's gone. Weather falls on it for real.
- **The house dresses for every season**: lanterns for All Hallows (and Lights Out by
  candlelight), garlands and a wreath for Yuletide (and wrapped parcels with ribbon fuses),
  copper candelabra for The Long Table, flowers in the season's colour all year.
- **Your Suite**, on the Velvet Room's roof through the Club hall's west door: eleven spots, nineteen
  pieces (Gilt, the Boutique, Standing, the Introduction's painting, the Gold Key chair), the
  bell to furnish it, the wardrobe where your looks hang. The Gold Key opens the Dressing Room
  and the Study. **Friends' Suites**: friends on Roblox may visit each other's Suites from the
  **Suites** key on the left (the server checks the friendship; anyone else can't go in): the
  visitor is shown the friend's Suite as the friend has furnished it, the two see each other
  there, the friend is told who's visiting, and out of the Suite the visitor is home again (the
  friend's bell is theirs). Each guest otherwise sees only their own Suite, and nobody else in it: the furniture is
  drawn on your own screen from your own Suite (the server sends each guest only theirs, and
  works out a Suite seat from the sitter's own Suite), and another guest in their Suite at the
  same moment isn't drawn on yours, nor their name, a glow or a light they wear, or their
  footsteps. Suite shows (fireworks, the Meme Takeover, the Golden Transformation) play only on
  the screen of the guest who plays them; Salutes are for the whole house.
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
  build in the bottom-left corner and prints it in Output (`[Maison] Build 33 ...`), so you can see
  Studio has the latest code. The live game plays the intro over the house (any key skips it);
  the old title screen is off (`Config.Title.show`). Roblox never spawns anyone by itself
  (`Players.CharacterAutoLoads` is off in the Rojo project and at the very top of the server), so
  nobody lands inside the Foyer's floor behind the front doors; every guest is placed in the
  Foyer, in the light (`Config.Movement.firstArrival = "street"` brings back the walk in from the
  street on a first visit). Guests and staff stand at 80% of Roblox's size
  (`Config.Movement.guestScale`), and the house itself is built **Grand**: every room, wall,
  ceiling, doorway and stair is opened out by `Layout.SCALE` (1.6 times as wide, deep and
  tall as drawn) while the furniture keeps its true size and moves with its room
  (`World/Grand`), so the Foyer, the rooms, the Ballroom and the Suite have far more space
  around every table and chair. Each staircase has an unseen ramp along its nosings, so every
  guest walks up it smoothly; what stood flush against a wall still does, what stood on a piece
  of furniture moves with it, and the table lamps' cords run up to the higher ceilings
  (marked by the builder with `GrandHang`). The Suite's own furniture is built a size up
  (`Layout.SUITE_FURNITURE`, 1.2) and keeps its drawn distance from the walls it stands against,
  grown with it; its fireplace and front doors are built after the house is grown, at their true
  size (`World/SuiteFinish`). Guests walk at 17 (28 running) and the staff at 13 to cross the
  bigger rooms, and the camera may pull back to 64 studs (`Config.Movement.cameraMaxZoom`). Every part of the house starts on its own, so one that fails
  is reported in Output and never stops anyone from walking in, and a separate safety script
  hands back Roblox's own camera, controls and prompts if the house's client ever doesn't start.
- **The sorting screen: the Jeweller's Desk.** A mahogany desk with brass corner guards, a
  green leather top tooled with a double gold border, the house's crest and the figures on
  brass-edged plaques; the six cases are jewellery drawers, each in its own colour of velvet,
  with an engraved brass name plate and the count on its plinth. A brass ribbon for a run of
  correct pieces; a sweep of light across a drawer's glass as a piece goes in; the word grows
  with the run (Correct, Great, Excellent, Perfect, Legendary).
- **Type.** One type scale across every panel, set crisp: panels are plain frames (no
  CanvasGroups, which blur text), keys never squeeze their letters, and panels sit below the
  keys at the top of the screen.
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
    for the whole house. Gold confetti over every guest (75: a burst, then slips of gold foil
    turning over and over as they fall, glinting, right at any time of year), an encore with a followspot on you (125: its beam seen in the
    air, rose petals falling round you, applause), every lamp flaring in a wave from wherever you
    stand, each chandelier throwing off glints of crystal (175), the full pyromusical over the
    whole estate (299), the Grand Salute: all of it, announced in every house (599), or the
    Midnight Finale: ten great golden numbers and a bell for each on every screen, midnight's
    chimes in a flash of light, then the biggest show the house fires (999). The giver's name goes on the Tonight board, with a gold star on
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
- **The Owner Console** (Build 51): when **XxxXxxX_77797** joins, the screen says *WELCOME BACK,
  OWNER* and the Owner Console opens by itself: every power as a big tile, in nine groups down
  the left (**Abuse, Effects, Holidays, Events, Players, World, Message, Powers, More**). Reopen
  it with the gold **👑 Owner** key or **;**. **ALL SERVERS** (on by default) or **THIS SERVER**
  at the top decides where events, effects, headlines, giveaways and gifts go. Only that one
  account has it: the server checks the UserId (`Config.Admin.ownerUserId = 8722595934`) on
  every request, so nobody else gets anything whatever their screen sends. (In Studio the first
  test player stands in, `Config.Admin.studioFirstPlayer`; never in the live game.) When you
  arrive, your server sees *👑 THE OWNER IS IN THE SERVER! 👑*, your nameplate says **OWNER**, and
  everyone there gets the **Met the Owner** badge.
  - **Abuse**: Admin Abuse Night (15/30/60 min), **MEGA ABUSE** (every effect as a surprise every
    25 seconds, a giveaway every couple of minutes, the Mega Abuse Medal for everyone there),
    countdowns (big numbers on every screen, then Admin Abuse, Mega Abuse, a giveaway or a
    surprise), and **Stop everything**.
  - **Effects** (23, on every screen round every guest; nobody sorting is moved, nobody is hurt):
    rocket launch, dance party, lightning storm, brainrot storm, confetti cannons, shockwave,
    spin, **meteor shower, black hole, aurora, galaxy sky, UFO abduction, blizzard, earthquake,
    rainbow mode, bubble party, gold wave, fire & ice, blackout, tornado, fireworks finale, titan
    meme, zero gravity**. Each is a **switch** (Build 53): tap it and it stays on, with **ON** on
    its tile, until you tap it again; switch on as many as you like together, and **Every effect
    OFF** ends them all (so does Stop everything). Effects that move guests (the rocket, the
    shockwave, the spin, the black hole, the UFO, the tornado, the earthquake...) come round
    again in waves every few seconds (`Config.Admin.fxWaves`); the rest simply stay. Guests who
    arrive while one is on see it too.
  - **At the sorting tables** (Build 53), so nobody sorting misses out: while Admin Abuse or an
    effect is on, the sorting screen itself carries it, drawn on the felt round the pieces (the
    galaxy's stars and a ringed planet, meteors, the tornado's funnel, snow, the UFO's beam, the
    blackout's spotlight, every one of the 23, plus Admin Abuse's and Mega Abuse's own), with a
    ribbon saying what's on. Each deal at a room table gets **golden pieces**, chosen by the
    server: 1 while an effect is on, 2 in Admin Abuse, 3 in Mega Abuse; each glows gold, and
    filing it in the right case pays **+40 Gilt** (`Config.Admin.table`). In **Mega Abuse all
    Gilt is tripled** (Admin Abuse's Golden Hour doubles it). Scores are never touched.
  - **Every server** (Build 53): with **ALL SERVERS** on, what you switch on is also written to
    one small record (`MaisonSchedule` → `live`) that every server reads every 30 seconds
    (`Config.Admin.liveCheck`), so a server that missed the message, or opens later, joins in for
    the time left: Admin Abuse, Mega Abuse, events and effects alike. Stopping is written there
    too, so nothing comes back on by itself.
  - **Music** (Build 53): while Admin Abuse is on, a run of dance tracks plays in place of the
    house's music (Mega Abuse: dubstep and drum and bass); while an effect is on, its own (the
    galaxy, the aurora and zero gravity: something cosmic; the meteors, the black hole, the
    tornado and the storm: something epic; the dance party: disco; the blizzard: winter; the gold
    wave: a brass fanfare; the blackout: spy jazz). Whichever was switched on last plays; when
    all are off, the house's music comes back. See *Music and sounds* below.
  - **Holidays**: the All Hallows' Hunt (pumpkins, bats), the Turkey Trot (turkeys that run from
    you), the Gift Drop (presents and snow), the New Year Countdown (ten seconds, the year's
    biggest fireworks and 200 Gilt for everyone), Sweethearts (love letters, hearts), the Lucky
    Clover (clovers, and a rainbow down to the pot of gold) and the Egg Hunt. Each find pays Gilt
    and a curio to keep; one golden prize per hunt, with a beam of light over it. On the real day
    (Halloween, Thanksgiving, Christmas, New Year, Valentine's Day, St Patrick's Day, Easter; the
    day in UTC, like the Nightly) the house runs its own for the first ten minutes of every hour
    (`Config.Admin.holidayAuto`).
  - **Events**: everything below, plus **Double XP**.
  - **Players**: **giveaways** (250/1,000/5,000 Gilt: one guest in each server wins, drawn on
    every screen, never you), Gilt for everyone, **the Owner's Token** (a curio from you, once a
    day each), bring everyone, freeze, the guest list.
  - **World**: the time of day; dress the house in any season.
  - **Message**: **headlines** across the top of every screen (ten ready-made, or your own words,
    always through Roblox's filter) in gold, red, rainbow, ice or green; announcements; a summons.
  - **Powers**: fly, ghost, invisible, speed, super jump, size, go anywhere.
  - **More**: the schedule, Salutes and Suite shows, and the classic House controls below.
- **The Owner Remote** (outside the game, every server): the same powers from your phone or a
  computer, sent to every live server through Roblox Open Cloud. Three ways, one setup:
  1. **Make the key** (once): Creator Hub → **Open Cloud** → **API Keys** → **Create API Key** →
     name it *Owner Remote* → **Access Permissions**: **messaging-service**, choose **Maison
     Noir**, tick **Publish** → **Security**: add IP `0.0.0.0/0` → **Save & Generate Key** → copy.
  2. **Give it to GitHub** (once): this repository → **Settings** → **Secrets and variables** →
     **Actions** → **New repository secret** → name `ROBLOX_OPEN_CLOUD_KEY` → paste → **Add**.
  3. **Use it**: **GitHub** (phone or computer): **Actions** → **Owner Remote** → **Run workflow**
     → choose from the list (77 powers; effects say **ON**, and **Every effect OFF** ends them)
     → **Run workflow**; every server does it about half a
     minute later. **The Owner Remote page** (the artifact): tap a power, **Send to every
     server** (it starts the same workflow through claude.ai's GitHub connector). **PowerShell**
     (instant, on a computer): `irm https://raw.githubusercontent.com/aarokemrajsponax-cpu/robloxexperience1/claude/nice-brown-a88p9r/remote.ps1 | iex`
     (it asks for the key once and keeps it, encrypted, on that computer).
  The game listens on the topic `MaisonRemote` and checks each command against its own lists
  (a known effect, event, amount, headline...) before doing anything; typed headlines go
  through Roblox's filter. The list of powers is made from the game's own
  (`python3 tools/remote/build.py` after changing events or effects).
- **House controls** (the owner's classic panel, from the console's **More** page): the pages
  below.
  - **Effects for everyone** (Powers, at the top; switches, this house or every house): **Rocket
    launch** (every guest shoots into the sky on a trail of smoke), **Dance party** (everyone
    dances under disco light), **Lightning storm** (forks of lightning round the house, thunder
    after), **Brainrot storm** (the house's memes pour from the sky round every guest), **Confetti
    cannons**, **Shockwave** (a ring of gold blasts out from you and throws guests near you back)
    and **Spin**. Nobody sorting at a table is ever moved; they still see and hear it. Nothing
    changes Gilt or a score. **Time of day**: midnight (the house's own), dawn, noon or sunset.
  - **Powers** (your own): **fly** where the camera looks (Space or E to rise, Q or Ctrl to sink;
    the thumbstick on a phone), **ghost** (through walls and floors, flying or walking), **speed** 1×/2×/3×/5×, a **super jump** 1×/2×/4×, any **size**
    (tiny, normal, giant, colossal), **invisible** (you and your name), **go anywhere** in one
    step (the street, the Foyer, the Salon, the Boutique, the Vault, the Library, the Ballroom,
    the Terrace, the Suite) or **to any guest** (Guests → Go to), **bring everyone** to you, and
    **freeze the house** (it thaws by itself after half a minute). Numbers in `Config.Admin`.
  Events (Golden Hour, Lucky Hour, the Page-Turner, a Night of Giants, a Night of Small Things,
  the Quickstep, Featherlight, Gold Rain, a Treasure Hunt, the Brainrot Parade, Disco Night, the
  House Party: every lamp in the house turning disco), in this house or every house, for
  5/15/30 minutes;
  any Salute for free; any Suite show on your own screen, free, to try it (Spectacle page:
  **Suite shows**); another season for a while; crown a Guest of Honour, spotlight, bring,
  gift Gilt to one guest or everyone, or show someone out; announcements (typed ones filtered by
  Roblox) here or everywhere; and a summons that invites guests in every house to join yours.
  Events change Gilt, Ledger pages and Mythic luck, never a score.
  - **Admin Abuse Night** (Events): every event at once (double Gilt, Mythic luck, the
    Page-Turner, gold rain, a treasure hunt, giants, the Quickstep, Featherlight, the Brainrot
    Parade, Disco Night, the House Party, a Night of Curios), for 15, 30 or 60 minutes. It opens
    with ADMIN ABUSE slammed onto every screen, air horns and fireworks, announced once; every
    screen shows one headline (ADMIN ABUSE NIGHT · 12 EVENTS ON · the time left) with a line
    turning through the events; and every minute there's a surprise for everyone (one of the
    effects above). Switch on **Every house** first to run it in every server.
  - **Stop everything** (Events, at the top): every event, the night's surprises, a freeze and the
    time of day back to normal at once (in every house too, with Every house on).
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
- **Levels, the Gilt bar, badges and the Gem Shop** (Build 51):
  - **The Gilt bar**, top left while you walk: your Gilt (counting up as it comes in, with
    *+25* floating off it), your Gems, and your level with its bar of XP. It steps aside at a
    table and under any panel. Tap the Gems for the Gem Shop, the level for the Badge Book.
  - **Levels 1 to 100**, from how well you play: XP for every piece put away correctly, far more
    for a Flawless round (40) than a Cleared one (8), the Nightly, Library matches and wins, the
    Ballroom (120 more for the last lamp), events, and the first visit of the day. Each level
    pays Gilt (and Gems every tenth) once; LEVEL UP! fills the screen. Your level is the disc on
    your nameplate, its colour by tier (bronze, silver, gold, emerald, sapphire, ruby), with
    titles from Newcomer to Immortal; every tenth level is announced to the house. Double XP
    and an XP Surge make it faster. Numbers in `Config.Levels`.
  - **The Badge Book** (Menu → The Badge Book): **151 badges** in eleven groups (levels, the
    tables, nights, the Library, the Ballroom, your collection, Gilt and Gems, events and Admin
    Abuse, holidays, friends, secrets), each saying how to earn it and how far along you are.
    Earned in the game at once, with a card on screen. Any of them can also be a real Roblox
    badge: make it in Creator Hub (**Associated Items → Badges**) and put its id in
    `Config.Badges` under the same key (`rounds_100`, `holiday_halloween`, `metOwner`...).
  - **The Gem Shop** (the 💎 key on the dock, the Gems on the Gilt bar, or Menu): **12 auras**
    (a glow round you that everyone sees: gold dust, rose, emerald, frost, embers, starlight,
    velvet shadow, hearts, clovers, a crown of stars, galaxy, rainbow), **10 titles** (above your
    name), **Gilt Surge** and **XP Surge** (half an hour each), **Gilt for Gems** at a set rate,
    and the Cabinet's curios (six new ones). Every price is on the card before you choose;
    buying takes two taps (the price, then Confirm); nothing is random; the server decides it.
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
- **The playable grand piano** (the Foyer's, and your own baby grand in the Suite): each key is a
  slice of a licensed APM piano recording (`Assets.PianoSlices`), retuned to it. The recordings
  are fetched soon after you arrive and every key's voices are readied when anyone sits down, so
  the first note sounds at once; one Roblox reports as failed is fetched again after 20 seconds
  and the keys keep playing it meanwhile, never a silent keyboard (`Config.Piano`). The notes
  follow the Effects volume, and the rest of the Foyer hears them from the piano itself.
- **Table sounds** (`Assets.LibrarySounds`): recordings from Roblox's licensed Pro Sound Effects
  library and Roblox's own UI sounds:
  - a dice-on-felt knock as a piece settles into its case;
  - a dull wooden knock for a wrong case;
  - leather as you sit down;
  - a clean chime that climbs a step with each piece in a streak.

  Each has the pitch and level that suit it.
- **Admin Abuse and effect music** (`Assets.AbuseMusic`, `Assets.AbuseThemes`, `World/AbuseMusic`):
  more APM tracks from the same licensed library, each levelled to the others: dance (*Feeling*,
  *Skyhook*, *Stadium Rave*...) for Admin Abuse; dubstep and drum and bass (*Electric Shock*,
  *Next Level*, *Night Run*...) for Mega Abuse; and a set for the effects (cosmic, sci-fi, epic,
  heroic, disco, winter, a brass fanfare, spy jazz). `Assets.AbuseThemes` says which set each
  effect plays, and `Assets.AbuseMusicVolume` how loud.

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

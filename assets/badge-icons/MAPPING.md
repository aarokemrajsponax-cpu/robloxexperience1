# Badge icons (Build 88)

208 medals, one for every badge in the Badge Book (`src/shared/BadgeBook.luau`), made by
`python3 tools/art/badge_icons.py`. The ring is the tier, the enamel the group, the chip the count.

**Roblox ids so far:** `nights_1` (Welcome to the Maison), `metOwner`, `megaAbuse`, `islandKey`, `executiveBoss` and `basementSecrets` (Every Secret) have one in `Config.Badges`.
Every other badge is earned in the game's own Badge Book but isn't a Roblox badge yet, so it isn't
on players' profiles. `created.json` (written by the tool below) lists each one made with it.

### The next five (Build 97): good ones to show on a profile

Each is already earned in the game (its Badge Book entry) and has its medal here. Make them the
same way as the welcome badge below (five a day are free), then send the five ids.

| Key | Name | Description | Image |
|---|---|---|---|
| `crownJewel` | The Crown Jewel | Carry the Crown Jewel out of Steal a Luxe and bank it. | `crownJewel.png` |
| `basementClear` | The Treasury | Reach the Treasury at the foot of the Maison Basement. | `basementClear.png` |
| `gilt_1000000` | Millionaire | Hold 1,000,000 Gilt at once. | `gilt_1000000.png` |
| `firstFlight` | Wheels Up | Fly to Luxury Island. | `firstFlight.png` |
| `holiday_thanksgiving` | Turkey Catcher | Catch a turkey in the Harvest Field. | `holiday_thanksgiving.png` |

Or with the tool (below), in one go: `python tools/badges/create_badges.py --keys
crownJewel,basementClear,gilt_1000000,firstFlight,holiday_thanksgiving --go`.

### Just the welcome badge (free, about two minutes, no tools)

1. Creator Hub -> your experience -> Engagement -> Badges -> Create a Badge.
2. Image: `nights_1.png` (this folder). Name: **Welcome to the Maison**. Description:
   **Join the Maison for the first time: welcome.** Create it (one badge is within Roblox's free
   five a day).
3. Open the new badge and copy its id (the number in its page's address).
4. In `src/shared/Config.luau`, under `Badges`, change `nights_1 = 0` to `nights_1 = <that id>`.
5. Sync and publish (play.ps1, Rojo Connect, Publish).

Every guest then gets it on their first visit, and everyone who has been before gets it on their
next visit; it shows in the Badges on their Roblox profile, and the in-game Badge Book shows its
picture.

### Getting them onto players' profiles, with these pictures

A Roblox badge shows in the Badges section of a player's Roblox inventory and profile as soon as the
game awards it. The game already awards every Badge Book badge whose id is in `Config.Badges`
(as it's earned, and on the next visit for anyone who earned it before), and the in-game Badge Book
switches to the badge's real Roblox picture once it exists. So the only step left is making each
badge on Roblox. Roblox's rules (Creator Hub documentation): **5 badges free per experience every
24 hours (GMT); each one after that costs 100 Robux.** Pictures: 512 x 512, cropped to a circle
(these medals are drawn for that). The 206 left would take about six weeks free, or about 20,000 Robux
at once; the headline ones first is the sensible start.

**The quick way: `tools/badges/create_badges.py`** (needs Python 3). Five a day, free, with the
right picture, name and description, checked with Roblox afterwards and written into
`Config.Badges` for you:

1. Creator Hub -> Open Cloud -> API Keys -> Create API Key: add the badges API system
   (legacy-universe.badge) with **manage-and-spend-robux** (and write) for this experience.
2. In PowerShell, in the project folder: `$env:ROBLOX_API_KEY = "<your key>"` (this window only;
   never paste the key anywhere else, and never into a file).
3. Your Universe ID: Creator Hub -> the experience -> the "..." menu -> Copy Universe ID.
4. `python tools/badges/create_badges.py --universe <id>` shows today's five (nothing is sent).
   `python tools/badges/create_badges.py --universe <id> --go` makes them.
5. Sync and publish (play.ps1, Rojo Connect, Publish). Run step 4 again tomorrow for the next five.

It never pays unless you add `--pay --robux-each 100 --max-robux <your limit>`. Without that, once
today's free ones are used Roblox refuses and nothing is charged. The order: welcome, the Crown
Jewel, the Treasury, the Corner Office, Wheels Up; then the Grand Prix, the auction, Admin Abuse,
Thanksgiving and Christmas; then the fortunes; then the rest. Roblox marks this API "experimental".
`python tools/badges/test_create_badges.py` checks the tool against a stand-in for Roblox.

**By hand instead:** Creator Hub -> the experience -> Engagement -> Badges -> Create a Badge. Name
and description from the table below, the picture from this folder. Copy its id into
`src/shared/Config.luau` -> `Badges` under the same key (add the key if it isn't listed), then sync
and publish.

| Key | Name | Description | Tier | File |
|---|---|---|---|---|
| `level_2` | First Steps | Reach level 2. | bronze | `level_2.png` |
| `level_5` | Apprentice | Reach level 5. | bronze | `level_5.png` |
| `level_10` | Sorter | Reach level 10. | bronze | `level_10.png` |
| `level_15` | On the Rise | Reach level 15. | bronze | `level_15.png` |
| `level_20` | Adept | Reach level 20. | silver | `level_20.png` |
| `level_25` | Quarter Century | Reach level 25. | silver | `level_25.png` |
| `level_30` | Expert | Reach level 30. | silver | `level_30.png` |
| `level_40` | Master | Reach level 40. | silver | `level_40.png` |
| `level_50` | Grandmaster | Reach level 50. | gold | `level_50.png` |
| `level_60` | Emerald | Reach level 60. | gold | `level_60.png` |
| `level_75` | Virtuoso | Reach level 75. | gold | `level_75.png` |
| `level_90` | Living Legend | Reach level 90. | gold | `level_90.png` |
| `level_100` | Immortal | Reach level 100. | platinum | `level_100.png` |
| `firstRound` | First Round | Clear your first round at the tables. | bronze | `firstRound.png` |
| `rounds_10` | Warming Up | Clear 10 rounds at the tables. | bronze | `rounds_10.png` |
| `rounds_50` | Getting the Hang of It | Clear 50 rounds at the tables. | bronze | `rounds_50.png` |
| `rounds_100` | Centurion | Clear 100 rounds at the tables. | silver | `rounds_100.png` |
| `rounds_250` | Regular at the Felt | Clear 250 rounds at the tables. | silver | `rounds_250.png` |
| `rounds_500` | Half a Thousand | Clear 500 rounds at the tables. | silver | `rounds_500.png` |
| `rounds_1000` | The Thousand | Clear 1,000 rounds at the tables. | gold | `rounds_1000.png` |
| `rounds_2500` | Tireless | Clear 2,500 rounds at the tables. | gold | `rounds_2500.png` |
| `rounds_5000` | Unstoppable | Clear 5,000 rounds at the tables. | gold | `rounds_5000.png` |
| `rounds_10000` | Ten Thousand Rounds | Clear 10,000 rounds at the tables. | platinum | `rounds_10000.png` |
| `correct_100` | Neat Hands | Put away 100 pieces correctly. | bronze | `correct_100.png` |
| `correct_500` | Tidy | Put away 500 pieces correctly. | bronze | `correct_500.png` |
| `correct_1000` | The House Hallmark | Put away 1,000 pieces correctly. | bronze | `correct_1000.png` |
| `correct_2500` | Meticulous | Put away 2,500 pieces correctly. | silver | `correct_2500.png` |
| `correct_5000` | Archivist's Pride | Put away 5,000 pieces correctly. | silver | `correct_5000.png` |
| `correct_10000` | Ten Thousand Places | Put away 10,000 pieces correctly. | silver | `correct_10000.png` |
| `correct_25000` | Everything in Its Case | Put away 25,000 pieces correctly. | gold | `correct_25000.png` |
| `correct_50000` | The Great Sorter | Put away 50,000 pieces correctly. | gold | `correct_50000.png` |
| `correct_100000` | A Hundred Thousand | Put away 100,000 pieces correctly. | platinum | `correct_100000.png` |
| `firstFlawless` | Flawless | Play your first Flawless round. | bronze | `firstFlawless.png` |
| `flawless_5` | Spotless | Play 5 Flawless rounds. | bronze | `flawless_5.png` |
| `flawless_10` | Immaculate Taste | Play 10 Flawless rounds. | bronze | `flawless_10.png` |
| `flawless_25` | Precision | Play 25 Flawless rounds. | silver | `flawless_25.png` |
| `flawless_50` | Perfectionist | Play 50 Flawless rounds. | silver | `flawless_50.png` |
| `flawless_100` | A Hundred Without a Slip | Play 100 Flawless rounds. | silver | `flawless_100.png` |
| `flawless_250` | Untouchable | Play 250 Flawless rounds. | gold | `flawless_250.png` |
| `flawless_500` | Machine | Play 500 Flawless rounds. | gold | `flawless_500.png` |
| `flawless_1000` | Flawless Forever | Play 1,000 Flawless rounds. | platinum | `flawless_1000.png` |
| `flawless_salon` | Salon Perfect | A Flawless round in the Salon. | bronze | `flawless_salon.png` |
| `flawless_velvet` | Velvet Perfect | A Flawless round at tonight's table, on a gentle-clock night. | silver | `flawless_velvet.png` |
| `flawless_obsidian` | Obsidian Perfect | A Flawless round at tonight's table, on a brisk-clock night. | gold | `flawless_obsidian.png` |
| `flawless_midnight` | Midnight Perfect | A Flawless round at tonight's table on a Friday, the hardest clock. | platinum | `flawless_midnight.png` |
| `midnight` | After Midnight | Reach round IV of tonight's table on a brisk-clock night. | gold | `midnight.png` |
| `nights_1` | Welcome to the Maison | Join the Maison for the first time: welcome. | bronze | `nights_1.png` |
| `nights_3` | Back Again | Spend 3 nights at the house. | bronze | `nights_3.png` |
| `nights_7` | A Week of Evenings | Spend 7 nights at the house. | bronze | `nights_7.png` |
| `nights_14` | Fortnight | Spend 14 nights at the house. | silver | `nights_14.png` |
| `nights_30` | A Month at the House | Spend 30 nights at the house. | silver | `nights_30.png` |
| `nights_60` | Two Months | Spend 60 nights at the house. | silver | `nights_60.png` |
| `nights_100` | A Hundred Nights | Spend 100 nights at the house. | gold | `nights_100.png` |
| `nights_200` | Part of the Furniture | Spend 200 nights at the house. | gold | `nights_200.png` |
| `nights_365` | A Year at the House | Spend 365 nights at the house. | platinum | `nights_365.png` |
| `firstNightly` | Tonight's Table | Play the Nightly for the first time. | bronze | `firstNightly.png` |
| `nightlies_7` | Nightly Habit | Play the Nightly 7 times. | silver | `nightlies_7.png` |
| `nightlies_30` | Every Night | Play the Nightly 30 times. | gold | `nightlies_30.png` |
| `nightlies_100` | The Hundredth Night | Play the Nightly 100 times. | platinum | `nightlies_100.png` |
| `evenings_1` | The First Present | Open your first present from the Evening Calendar. | bronze | `evenings_1.png` |
| `evenings_7` | The Seventh Evening | Open 7 presents from the Evening Calendar. | silver | `evenings_7.png` |
| `evenings_30` | A Month of Presents | Open 30 presents from the Evening Calendar. | gold | `evenings_30.png` |
| `evenings_100` | The House Regular | Open 100 presents from the Evening Calendar. | platinum | `evenings_100.png` |
| `firstLibraryWin` | First Win | Win your first match in the Library. | bronze | `firstLibraryWin.png` |
| `libraryWins_10` | Ten Wins | Win 10 matches in the Library. | bronze | `libraryWins_10.png` |
| `libraryWins_25` | Formidable | Win 25 matches in the Library. | silver | `libraryWins_25.png` |
| `libraryWins_50` | Fifty Wins | Win 50 matches in the Library. | silver | `libraryWins_50.png` |
| `libraryWins_100` | Library Lion | Win 100 matches in the Library. | gold | `libraryWins_100.png` |
| `libraryWins_250` | Unbeaten Legend | Win 250 matches in the Library. | platinum | `libraryWins_250.png` |
| `libraryMatches_5` | Pull Up a Chair | Play 5 matches in the Library. | bronze | `libraryMatches_5.png` |
| `libraryMatches_25` | Library Regular | Play 25 matches in the Library. | silver | `libraryMatches_25.png` |
| `libraryMatches_100` | Hundred Matches | Play 100 matches in the Library. | platinum | `libraryMatches_100.png` |
| `mark` | A Mark of Your Own | Finish your placement evenings and earn a Mark. | silver | `mark.png` |
| `ballroomEvenings_1` | First Dance | Play your first evening in the Ballroom. | bronze | `ballroomEvenings_1.png` |
| `ballroomEvenings_10` | Ballroom Regular | Play 10 evenings in the Ballroom. | silver | `ballroomEvenings_10.png` |
| `ballroomEvenings_50` | Fifty Evenings | Play 50 evenings in the Ballroom. | gold | `ballroomEvenings_50.png` |
| `ballroomEvenings_100` | Belle of the Ball | Play 100 evenings in the Ballroom. | platinum | `ballroomEvenings_100.png` |
| `firstLastLamp` | The Last Lamp | Keep the last lamp for the first time. | bronze | `firstLastLamp.png` |
| `lastLamps_5` | Lamplighter | Keep the last lamp 5 times. | silver | `lastLamps_5.png` |
| `lastLamps_25` | Keeper of the Light | Keep the last lamp 25 times. | platinum | `lastLamps_25.png` |
| `topFive_1` | Top Five | Finish in the top five for the first time. | bronze | `topFive_1.png` |
| `topFive_10` | Always Near the Top | Finish in the top five 10 times. | silver | `topFive_10.png` |
| `topFive_50` | The Ballroom's Own | Finish in the top five 50 times. | platinum | `topFive_50.png` |
| `register10` | The Register Opens | Put 10 different pieces in your Register. | bronze | `register10.png` |
| `register25` | A Growing Register | Put 25 different pieces in your Register. | silver | `register25.png` |
| `register50` | Half the House | Put 50 different pieces in your Register. | silver | `register50.png` |
| `register_75` | Almost Everything | Put 75 different pieces in your Register. | gold | `register_75.png` |
| `register_100` | The Complete Register | Put 100 different pieces in your Register. | platinum | `register_100.png` |
| `mythic` | A Mythic! | Find your first Mythic. | bronze | `mythic.png` |
| `mythics_3` | Mythic Hunter | Find 3 Mythics. | silver | `mythics_3.png` |
| `mythics_10` | Mythic Collector | Find 10 Mythics. | gold | `mythics_10.png` |
| `mythics_25` | Myth Made Real | Find 25 Mythics. | platinum | `mythics_25.png` |
| `curiosFound_1` | A Curio! | Find your first curio at the tables. | bronze | `curiosFound_1.png` |
| `curiosFound_10` | Curio Hunter | Find 10 curios at the tables. | silver | `curiosFound_10.png` |
| `curiosFound_50` | Cabinet of Wonders | Find 50 curios at the tables. | gold | `curiosFound_50.png` |
| `curiosFound_100` | Hundred Curios | Find 100 curios at the tables. | platinum | `curiosFound_100.png` |
| `curioKinds_5` | Five of a Kind | Hold 5 different curios. | bronze | `curioKinds_5.png` |
| `curioKinds_15` | A Shelf of Curios | Hold 15 different curios. | silver | `curioKinds_15.png` |
| `curioKinds_30` | Curator | Hold 30 different curios. | gold | `curioKinds_30.png` |
| `curioKinds_50` | The Whole Cabinet | Hold 50 different curios. | platinum | `curioKinds_50.png` |
| `seasonSet` | The Full Season | Collect every piece of a season's collection. | gold | `seasonSet.png` |
| `gilt_1000` | Pocket Money | Hold 1,000 Gilt at once. | bronze | `gilt_1000.png` |
| `gilt_10000` | Comfortable | Hold 10,000 Gilt at once. | bronze | `gilt_10000.png` |
| `gilt_50000` | Well Off | Hold 50,000 Gilt at once. | silver | `gilt_50000.png` |
| `gilt_100000` | Six Figures | Hold 100,000 Gilt at once. | silver | `gilt_100000.png` |
| `gilt_500000` | Gilded | Hold 500,000 Gilt at once. | gold | `gilt_500000.png` |
| `gilt_1000000` | Millionaire | Hold 1,000,000 Gilt at once. | platinum | `gilt_1000000.png` |
| `giltEarned_10000` | Earning Your Keep | Earn 10,000 Gilt in all. | bronze | `giltEarned_10000.png` |
| `giltEarned_100000` | A Fortune Made | Earn 100,000 Gilt in all. | silver | `giltEarned_100000.png` |
| `giltEarned_1000000` | A Million Earned | Earn 1,000,000 Gilt in all. | platinum | `giltEarned_1000000.png` |
| `gemsSpent_100` | First Sparkle | Spend 100 Gems. | bronze | `gemsSpent_100.png` |
| `gemsSpent_1000` | Gem Connoisseur | Spend 1,000 Gems. | silver | `gemsSpent_1000.png` |
| `gemsSpent_5000` | Jewel of the House | Spend 5,000 Gems. | platinum | `gemsSpent_5000.png` |
| `firstAura` | Aglow | Own your first aura. | bronze | `firstAura.png` |
| `auras_5` | Radiant | Own 5 auras. | silver | `auras_5.png` |
| `auras_10` | Every Colour | Own 10 auras. | platinum | `auras_10.png` |
| `firstTitle` | Say My Name | Wear a title under your name. | bronze | `firstTitle.png` |
| `surge` | Surging | Use a Gilt Surge or an XP Surge. | bronze | `surge.png` |
| `exchange` | Change, Please | Change Gems for Gilt. | bronze | `exchange.png` |
| `gemWear` | Gems Only | Wear a companion, a felt or a trail only Gems can buy. | silver | `gemWear.png` |
| `abuseNight` | Admin Abuse! | Be in the house for an Admin Abuse Night. | bronze | `abuseNight.png` |
| `abuseNights_5` | Abuse Veteran | Be in the house for 5 Admin Abuse Nights. | silver | `abuseNights_5.png` |
| `abuseNights_25` | Survivor of Chaos | Be in the house for 25 Admin Abuse Nights. | platinum | `abuseNights_25.png` |
| `megaAbuse` | Mega Abuse! | Be in the house for a Mega Abuse. | gold | `megaAbuse.png` |
| `pickups_1` | Finders Keepers | Pick up something at one of the house's events. | bronze | `pickups_1.png` |
| `pickups_25` | Quick Hands | Pick up 25 things at the house's events. | silver | `pickups_25.png` |
| `pickups_100` | Hoarder | Pick up 100 things at the house's events. | gold | `pickups_100.png` |
| `pickups_500` | Vacuum Cleaner | Pick up 500 things at the house's events. | platinum | `pickups_500.png` |
| `goldenKey` | The Golden Key | Find a golden key in a Treasure Hunt. | silver | `goldenKey.png` |
| `paradeCatch` | Caught One! | Catch a meme in the Brainrot Parade. | bronze | `paradeCatch.png` |
| `discoNight` | Disco Fever | Be in the Ballroom on Disco Night. | bronze | `discoNight.png` |
| `giveawayWinner` | Winner! | Win one of the owner's giveaways. | gold | `giveawayWinner.png` |
| `headline` | Breaking News | Be in the house for one of the owner's headlines. | bronze | `headline.png` |
| `fx_blackHole` | Event Horizon | Be pulled up into a black hole. | silver | `fx_blackHole.png` |
| `fx_ufo` | Abducted | Be beamed up by a flying saucer. | silver | `fx_ufo.png` |
| `fx_meteor` | Impact | Live through a meteor shower. | silver | `fx_meteor.png` |
| `fx_titan` | Something Big | See the Titan meme rise over the house. | silver | `fx_titan.png` |
| `holiday_halloween` | All Hallows' Hunter | Find a pumpkin in the Hunt, or a treat on Hallows Lane. | silver | `holiday_halloween.png` |
| `holiday_thanksgiving` | Turkey Catcher | Catch a turkey in the Harvest Field. | silver | `holiday_thanksgiving.png` |
| `holiday_christmas` | Present Opener | Open a present: the Gift Drop's, or a gift from the North Pole. | silver | `holiday_christmas.png` |
| `holiday_newYear` | Happy New Year | Be in the house when the New Year arrives. | silver | `holiday_newYear.png` |
| `holiday_valentine` | Sweetheart | Find a love letter on Valentine's Day. | silver | `holiday_valentine.png` |
| `holiday_stPatrick` | Lucky Clover | Find a four-leaf clover on St Patrick's Day. | silver | `holiday_stPatrick.png` |
| `holiday_easter` | Egg Hunter | Find a painted egg in the Egg Hunt. | silver | `holiday_easter.png` |
| `fullBag` | A Full Bag | Knock at every door on Hallows Lane in one round. | gold | `fullBag.png` |
| `northPole` | To the North Pole | Ride Santa's sleigh to the North Pole. | silver | `northPole.png` |
| `santasHelper` | Santa's Helper | Load ten gifts on Santa's sleigh in one trip. | gold | `santasHelper.png` |
| `goldenTurkeyCaught` | Fastest Bird Alive | Catch the golden turkey in the Harvest Field. | gold | `goldenTurkeyCaught.png` |
| `goldenEggFound` | Hidden Best of All | Find the golden egg in the Great Egg Hunt. | gold | `goldenEggFound.png` |
| `luckOfTheIrish` | Luck of the Irish | Bank a run while the luck of the Irish is on. | silver | `luckOfTheIrish.png` |
| `trades_1` | First Trade | Make your first trade. | bronze | `trades_1.png` |
| `trades_10` | Trader | Make 10 trades. | silver | `trades_10.png` |
| `trades_50` | Merchant of the House | Make 50 trades. | platinum | `trades_50.png` |
| `referrals_1` | Plus One | Invite a friend who comes to the house. | silver | `referrals_1.png` |
| `referrals_5` | Life of the Party | Invite 5 friends who come to the house. | platinum | `referrals_5.png` |
| `friendHere` | Better Together | Be in the house with a friend. | bronze | `friendHere.png` |
| `suiteVisit` | House Call | Visit a friend's Suite. | bronze | `suiteVisit.png` |
| `guestBook` | Signed and Dated | Sign the Livre d'Or. | bronze | `guestBook.png` |
| `circle` | In the Circle | Join a Circle. | bronze | `circle.png` |
| `admired` | Admirer | Admire another guest's look. | bronze | `admired.png` |
| `crownJewel` | The Crown Jewel | Carry the Crown Jewel out of Steal a Luxe and bank it. | gold | `crownJewel.png` |
| `basementClear` | The Treasury | Reach the Treasury at the foot of the Maison Basement. | silver | `basementClear.png` |
| `executiveBoss` | The Corner Office | Beat the Executive in his own office. | gold | `executiveBoss.png` |
| `auctionWin` | Sold to You | Win a lot at the Grand Auction. | gold | `auctionWin.png` |
| `basementQuick` | Under Sixteen Minutes | Clear all thirty-two stages of the Basement in under sixteen minutes, no skips. | gold | `basementQuick.png` |
| `basementSecrets` | Every Secret | Find all eight secrets in the Maison Basement's four courses. | gold | `basementSecrets.png` |
| `islandKey` | The Island Key | Unlock Luxury Island at the Jet Lounge. | gold | `islandKey.png` |
| `firstFlight` | Wheels Up | Fly to Luxury Island. | bronze | `firstFlight.png` |
| `flights_10` | Jet Setter | Fly to Luxury Island 10 times. | silver | `flights_10.png` |
| `flights_50` | Frequent Flyer | Fly to Luxury Island 50 times. | platinum | `flights_50.png` |
| `pearls_5` | Pearl Diver | Bring up 5 pearls from the lagoon. | bronze | `pearls_5.png` |
| `pearls_25` | A String of Pearls | Bring up 25 pearls from the lagoon. | silver | `pearls_25.png` |
| `pearls_100` | The Pearl Necklace | Bring up 100 pearls from the lagoon. | gold | `pearls_100.png` |
| `pearls_300` | Ocean's Treasure | Bring up 300 pearls from the lagoon. | platinum | `pearls_300.png` |
| `firstSunset` | Golden Hour | Toast the sunset on the Island. | bronze | `firstSunset.png` |
| `sunsets_7` | A Week of Sunsets | Toast 7 sunsets on the Island. | silver | `sunsets_7.png` |
| `sunsets_30` | Sunset Regular | Toast 30 sunsets on the Island. | platinum | `sunsets_30.png` |
| `postcards` | Wish You Were Here | Take a photograph at every postcard spot on the Island. | gold | `postcards.png` |
| `firstRace` | Lights Out and Away | Finish a Grand Prix race. | bronze | `firstRace.png` |
| `races_10` | Regular on the Grid | Finish 10 Grand Prix races. | silver | `races_10.png` |
| `races_50` | Fifty Starts | Finish 50 Grand Prix races. | gold | `races_50.png` |
| `races_100` | The Hundred Club | Finish 100 Grand Prix races. | platinum | `races_100.png` |
| `gpWin` | Chequered Flag | Win a Grand Prix race. | bronze | `gpWin.png` |
| `raceWins_5` | Five Wins | Win 5 Grand Prix races. | silver | `raceWins_5.png` |
| `raceWins_25` | Champion | Win 25 Grand Prix races. | gold | `raceWins_25.png` |
| `raceWins_100` | Grand Prix Legend | Win 100 Grand Prix races. | platinum | `raceWins_100.png` |
| `podiums_3` | On the Podium | Finish on the podium 3 times. | bronze | `podiums_3.png` |
| `podiums_10` | Champagne Showers | Finish on the podium 10 times. | silver | `podiums_10.png` |
| `podiums_50` | Fixture on the Podium | Finish on the podium 50 times. | platinum | `podiums_50.png` |
| `firstTrial` | Hot Lap | Drive a timed lap. | bronze | `firstTrial.png` |
| `trialLaps_25` | Lapping It Up | Drive 25 timed laps. | silver | `trialLaps_25.png` |
| `trialLaps_100` | The Hundred Laps | Drive 100 timed laps. | platinum | `trialLaps_100.png` |
| `lapAce` | Lap Ace | Drive a timed lap of the Grand Boulevard in under 12 seconds. | gold | `lapAce.png` |
| `coastAce` | Coast Ace | A timed lap of the Coastal Circuit in under 11 seconds. | gold | `coastAce.png` |
| `runwayWin` | Runway Star | Win a round on the Runway. | bronze | `runwayWin.png` |
| `runwayWins_5` | Cover Look | Win 5 rounds on the Runway. | silver | `runwayWins_5.png` |
| `runwayWins_25` | Icon of the Runway | Win 25 rounds on the Runway. | platinum | `runwayWins_25.png` |
| `triviaWin` | Bright Spark | Win a round of Luxury Trivia. | bronze | `triviaWin.png` |
| `triviaWins_10` | Connoisseur | Win 10 rounds of Luxury Trivia. | silver | `triviaWins_10.png` |
| `triviaWins_50` | The Oracle | Win 50 rounds of Luxury Trivia. | platinum | `triviaWins_50.png` |
| `arenaWin` | Arena Champion | Win one of the Arena's challenges. | bronze | `arenaWin.png` |
| `arenaWins_10` | Ten Crowns | Win 10 of the Arena's challenges. | silver | `arenaWins_10.png` |
| `arenaWins_50` | The Arena's Own | Win 50 of the Arena's challenges. | platinum | `arenaWins_50.png` |
| `photoSets` | Picture Perfect | Strike a pose at every photo set in the Grand Ballroom. | silver | `photoSets.png` |
| `firstDance` | On the Floor | Take to the Grand Ballroom's dance floor. | bronze | `firstDance.png` |
| `metOwner` | Met the Owner | Be in the house with the owner. | gold | `metOwner.png` |
| `foundingTerm` | Founding Member | Play in the house's very first Term. | platinum | `foundingTerm.png` |
| `nightOwl` | Night Owl | Find the Midnight Owl. | platinum | `nightOwl.png` |

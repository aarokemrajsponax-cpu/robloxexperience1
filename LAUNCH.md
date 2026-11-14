# Maison Noir — the launch kit

(Build 76: the step-by-step launch guide, with every product's exact name and price, is the
separate *Maison Noir Launch Guide* document. The thumbnails and video shots in §3 and §4 below
predate the attractions: take fresh ones of the games, as that guide describes.)

Everything the game page needs, and the few switches to flip before the doors open. (How to
get the word out once it's open, with posts, a trailer plan and an ads plan: `MARKETING.md`.) The words
are written to be pasted as they are; the pictures are real shots of the game, taken in Studio
with the camera positions below, so the page never promises something the game isn't.

---

## 1. The game page

**Name** (your decision, §19 #3). Suggestions, shortest first:
- **Maison Noir**
- **Maison Noir: Sort the Night**
- **Maison Noir — a house of fine things**

**Genre:** **Party & casual**, subgenre **Minigame** (Creator Dashboard → the game → Publish
Settings → Game Details). Roblox asks for the genre of the core gameplay loop, and here that's a
house full of different games. The genre can be changed only once every three months.

**Description** (paste as is):

> A grand private house at midnight, full of games, and one question: who is the wealthiest guest?
>
> Slip into a great residence in Steal a Luxe and carry out what you can before the guards see
> you. Climb down the sixteen stages of the Maison Basement to its Treasury. Earn an invitation to
> the Executive Suite and get past its security. Bid at the Grand Auction, keep your lamp lit in
> the Ballroom's Lights Out, race the Grand Prix on the street outside, or sort treasures at the
> Salon's tables at your own pace.
>
> Everything you win grows your Fortune. Fill your Vault, furnish your Suite, and take the private
> jet to Luxury Island.
>
> Fair by design: the Wealthiest boards count only what you earn, never what's bought, and every
> price is shown before you pay.
>
> The house keeps the calendar: lanterns at All Hallows, a harvest at Thanksgiving, snow at
> Christmas.
>
> Made by AJKR

**Tags / keywords to pick where Roblox offers them:** minigames, heist, obby, luxury,
collecting, competitive, seasonal.

**Social links:** none (no links off Roblox, §13).

---

## 2. The icon (512 × 512)

**Ready to upload:** `marketing/icon-512.png` (the house's gold *MN* monogram on black lacquer,
readable down to the size Roblox shows it in lists). Or take one in-game:

- **A single gilded watch on black-green felt, in the pool of light from the table lamp**, seen
  from slightly above, with the brass edge of a case in the corner. The small *MN* hairline
  mark bottom-right.

Keep it for weeks at a time: icons can't be A/B tested on Roblox yet, so compare click-through
by traffic source in Creator Analytics before and after any change.

---

## 3. Thumbnails (1920 × 1080), five real shots

**Ready to upload:** `marketing/thumbnails/` holds seven, rendered from this build of the house
(the cover, the sorting screen itself, the Ballroom, the Terrace, the Library, the Vault, the
house at night), in that order. They show only what's in the game. Real screenshots with guests
in them are even better: add your own as below and let Roblox's testing pick the winner.

Take them in Studio, in **Run** mode (the server builds the house), with this pasted into the
**Command Bar** (View → Command Bar) one line at a time. Each line points Studio's camera at one
shot. Then take the screenshot with Studio's screenshot tool (the **View** tab → **Screenshot**).
(These are the Grand house's positions: every room is 1.6× the size it was drawn.)

```lua
-- 1. The street at night: the facade, the lanterns, the door.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-41.6, 12.8, -70.4), Vector3.new(0, 17.7, -16))
-- 2. The Foyer: the chandelier, the piano, the Grand Stair.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-28.8, 14.5, -6.4), Vector3.new(9.6, 19.2, 44.8))
-- 3. The Ballroom from the Gallery: twenty lamps in a ring.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(97.7, 64, 116.9), Vector3.new(97.7, 35.2, 200.1))
-- 4. The Library: two long tables under green lamps.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-3.2, 43.3, 115.2), Vector3.new(-32, 33.7, 144))
-- 5. The Suite by the fire.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-84, 44, 68), Vector3.new(-88, 45, 96))
```

Then two shots that need a guest at a table (use **Play**, sit at a Salon table, and take them
with Studio's screenshot tool while playing):

6. **A hand filing a gilded watch**: lift a gilded piece and hold it over its case, so the
   guide light shows.
7. **The Ballroom's last lamp**: during a Lights Out evening, the moment only one table is lit.

Upload four or five, and turn on Roblox's **thumbnail testing** (Creator Hub → your experience
→ Places → Thumbnails → test). Keep the winner.

---

## 4. The gameplay video (30–45 seconds)

Upload it **directly in Creator Hub** (YouTube videos on game pages are being removed from
September 30, 2026). No text over it except the name at the end. Record in Play with Studio's
video capture (the **View** tab → **Video Record**) or any screen recorder, at 1920 × 1080.

| Seconds | Shot |
| --- | --- |
| 0–4 | The street at night, snow or leaves falling; the doors open. |
| 4–9 | Walking into the Foyer: the chandelier, the Pianist at the keys, the Concierge's glance. |
| 9–18 | A Salon table: a deal lands, three quick filings climbing the chime, a gilded piece. |
| 18–24 | The Nightly card: the grade stamped, the place among everyone tonight. |
| 24–34 | The Ballroom: lamps going out around the ring, parcels flying, the last lamp. |
| 34–40 | The Vault's cabinets, then the Suite by the fire. |
| 40–45 | Back out to the street. **MAISON NOIR** in gold. |

---

## 5. The maturity questionnaire (Creator Hub → Questionnaire)

Answer it truthfully for what's in the game once your §19 choices are made. With the gambling
and alcohol pieces replaced (§19 #2):
- **Violence, blood, crude humour, romance, fear:** none.
- **Gambling:** none (Lights Out and the rooms are skill games; nothing is wagered).
- **Alcohol:** none, once the Hip Flask and Champagne Coupe are replaced. The Terrace's drinks
  cart and the Suite's drinks cabinet show plain bottles; swap them for a flower cart and a
  curio cabinet if you want to be certain.
- **Paid random items:** **yes** (the Luxe Lucky Boxes, opened for Gems or Gilt, both of which are
  sold for Robux). Each box's odds are shown in full before opening (they add up to 100%; every open gives a brainrot), and the game checks each
  guest's policy (`PolicyService`, `ArePaidRandomItemsRestricted`): until Roblox says paid random
  items aren't restricted for that guest, the showroom's prompt is hidden and the purchase is
  refused on the server. Tick this box, or the experience can be restricted.
- **ArePaidRandomItemsRestricted respected:** **yes** (above).
- **Paid item trading:** **yes.** Gems are sold for Robux, and the curios bought with Gems in
  the Cabinet can be traded between guests. The game already does what Roblox asks of it: it
  checks each guest's policy (`PolicyService`, `IsPaidItemTradingAllowed`) and, where trading
  bought things isn't allowed, keeps Gem-bought curios out of that guest's trades (curios found
  at the tables still trade). Tick this box, or the experience can be restricted.
- **Content from other experiences shown in-game:** **no.**
- **Generative AI that players interact with:** **no** (every line is written in advance).
- **IsPaidItemTradingAllowed respected:** **yes** (above).
- **Players share media from their play:** **yes**, screenshots only, through Roblox's own share
  prompt (Photo mode's Capture, and Share on the Nightly card and at big moments).
- **IsContentSharingAllowed respected:** **yes.** The server asks Roblox for each guest
  (`server/Policy`); until Roblox says yes, that guest's screen shows no Share or Capture key.
- **Social:** Roblox's own chat only; no custom chat.
- **Free-form user creation:** none (no drawing, painting or building by guests; Circle names
  are chosen from lists). The only typing is the Emperor's Decree's words, and those always pass
  Roblox's text filter (`TextService`, filtered for broadcast) before anyone sees them.

Minimal or Mild reaches the youngest catalogue (Roblox Kids); up to Moderate reaches Select.
Reaching under-16s also needs ID and two-step verification on the owner's account and either
Roblox Plus or the refundable publishing fee.

---

## 6. Friend invitations (Creator Hub → Engagement → Referral Rewards)

The game is ready for Roblox's friend referrals: the **Invite** key in the quick dock opens
Roblox's own invite prompt, and a friend who arrives for the first time through it is welcomed
with **100 Gilt**, while the guest who invited them is thanked with **150 Gilt** if they're in
the house (any server) when the friend arrives: at most 5 a day and 50 in all, and only for
Roblox accounts at least 7 days old (all in `Config.Referral`). The game must have been live for
a day before Roblox lets you publish the banner. Then, in Creator Hub → your experience →
Engagement → **Referral Rewards**: add an icon (`marketing/icon-512.png`), and paste:

- **Name:** Bring a friend to the Maison
- **Description:** Invite a friend from the Invite key. On their first visit they get 100 Gilt,
  and you get 150 Gilt if you're in the house when they arrive (up to 5 friends a day).

Keep the banner's words matching `Config.Referral` if you change the numbers.

---

## 7. Switches to flip before the doors open

All in `src/shared/Config.luau` (or live, in Creator Hub → Configs, as `Section_key`):

| What | Where | Value |
| --- | --- | --- |
| The Founding Term | `FoundingTerm` | the Term you launch in: set to `2026-autumn` (change it if you launch after November) |
| Every product | nothing to paste | make each developer product in Creator Hub with its name from the table below; the game finds it by name |
| VIP Velocity Elite (game pass) | `Products.velocityElite` | 2081486302 (pasted). Without an id the perk is sold as a developer product of the same name |
| The Black Card | `Products.blackCard` | the subscription's id (`EXP-…`), or leave `""` to launch without it |
| Badges | `Badges.*` | optional: all 151 work in the game's Badge Book already. To make one a real Roblox badge, create it in Creator Hub → your experience → **Associated Items** → **Badges** (Roblox allows a few free each day, then charges Robux per badge) and put its id under the same key, e.g. `metOwner = 123456` (keys: `src/shared/BadgeBook.luau`). Start with the ones players brag about: `metOwner`, `abuseNight`, `firstFlawless`, `level_50`, `holiday_halloween`. |
| The owner | `Admin.ownerUserId`, `Admin.ownerName` | `8722595934` (your account) and `"AJKR"`: already set; only this account gets the Owner Console, and in the house it always shows as AJKR, never its Roblox username |
| The Owner Remote | GitHub secret `ROBLOX_OPEN_CLOUD_KEY` | an Open Cloud key with **messaging-service → Publish** and **universe-datastores → Read/Create/Update Entry** for Maison Noir (README: The Owner Remote) |
| Circles | `Circles.enabled` | `true` at launch, or `false` for later (§19 #10) |
| Notification templates | `Notifications.messages.*` | from Creator Hub → Engagement → Notifications |
| The house's music and sounds | `Assets.Playlists`, `Assets.LibrarySounds` | nothing: licensed recordings play from the start (README, "Music and sounds"). Optional: upload `assets/audio/maison-sounds.ogg` for the house's own table sounds and the Boutique's chimes |
| Looks, animations | `Assets.*` | see the README's tables |

**The notifications' Open Cloud key** (never in code):
1. Creator Hub → **Open Cloud** → **API Keys** → **Create API Key**.
2. Name it `Maison notifications`. Under **Access Permissions** add **user-notification**,
   choose this experience, tick **write**.
3. Under **Security**, set **Accepted IP Addresses** to `0.0.0.0/0` (Roblox's servers call it).
4. **Save & Generate Key**, and copy it.
5. Creator Hub → your experience → **Secrets** → **Create Secret**: name
   `OpenCloudNotifications`, paste the key, domain `apis.roblox.com`. Save.

**The notification templates** (Creator Hub → your experience → Engagement → Notifications →
Create a notification string), then paste each id into `Notifications.messages`:

| Key | Text | Parameter |
| --- | --- | --- |
| `rivalPassed` | `{experienceName}: {name} just passed you on tonight's table.` | `name` |
| `soiree` | `{name} has started at {experienceName}. Your best evenings this weekend count.` | `name` |
| `termEnding` | `{term} ends in three days at {experienceName}. The Ledger's last pages are waiting.` | `term` |

**Already done (Build 31):** the ten developer products made in Creator Hub (Megalodon
Rainmaker, Emperor's Decree, Chronos Defiance, Luck Booster, The Gold Key, Golden Hour for
Everyone, Gilt Vault, Gilt Chest, Gilt Purse, Double Gilt) have their ids pasted into
`Products` in `src/shared/Config.luau`, so they're on sale whatever their names. Prices are
always Roblox's own. For any product still to make:

**Making the developer products: name them, no ids to copy.** The game finds every developer
product by its exact name (capitals don't matter), so making one in Creator Hub is all it takes
to put it on sale; it appears within five minutes, no republish needed. Start with the first
block (that's where most of the money is):

1. Creator Hub → **Creations** → your experience → **Monetization** → **Developer Products**.
2. **Create a Developer Product**. Type the **name** exactly as below, set the **price**, add a
   small image if you like, **Save**.
3. Repeat for each line. That's it.

| Name (exactly) | Price | What it does |
| --- | --- | --- |
| `God-Mode Luck` | 199 | 2.5× Gilt and Ledger pages for 30 minutes of play (time only runs while they're in the house) |
| `Chronos Defiance` | 49 | when the clock runs out in a timed room: +15 seconds and the run goes on; and in the Executive Suite, caught by security, back in the run (offered only in those moments) |
| `Emperor's Decree` | 149 | the buyer's own words (filtered by Roblox first) in gold on every screen in the server for 8 seconds |
| `Megalodon Rainmaker` | 699 | gold rains on the server: every guest gets 150 Gilt, the buyer 500 more, and everyone sees who made it rain |
| `VIP Velocity Elite` | 299 | 1.5× walking and running speed round the house (not in Steal a Luxe, the Basement or the Executive Suite) and a gold trail, for good (better as a game pass: see below) |
| `Double Gilt` | 399 | every Gilt the buyer earns, doubled, for good (the best seller in games like this) |
| `Gilt Purse` | 49 | 1,000 Gilt |
| `Gilt Chest` | 199 | 5,500 Gilt |
| `Gilt Vault` | 499 | 18,000 Gilt |
| `Golden Hour for Everyone` | 99 | double Gilt for everyone in the server for 15 minutes, buyer announced |
| `The Gold Key` | 499 | +20% Gilt, the Study, gold nameplate and Gold Key looks (now also the game pass 2089628601, pasted in `Products.goldKey`, which is sold first) |
| `The Introduction` | 99 | the first-week starter pack |
| `Salute: Gold Confetti` (an old `Salute: Gold Leaf` still works) / `Salute: Encore` / `Salute: Chandelier` / `Salute: Fireworks` / `Salute: Grand Salute` / `Salute: Midnight Finale` | 75 / 125 / 175 / 299 / 599 / 999 | a moment for the whole house (Fireworks: a 45-second show over the whole estate; Grand Salute: everything, announced in every house; Midnight Finale: a ten-second countdown on every screen, then a 90-second show, announced in every house). Until each exists, Studio shows a free Preview button. |
| `Boutique 49` … `Boutique 599` (ten: 49, 79, 99, 149, 199, 249, 299, 399, 499, 599) | the number in the name | the Boutique's pieces at that price |
| `Leather-Bound Ledger` | 299 | the Term's premium Ledger row |
| `Season Collection` | 399 | the season's pieces |
| `Gold Key Gift` | 499 | the Gold Key, for another guest |
| `Piano Session 1 Minute` | 99 | a minute at the Foyer's grand piano (everyone in the Foyer hears it; time only runs at the keys) |
| `Piano Session 3 Minutes` | 349 | three minutes at the piano |
| `Piano Session 5 Minutes` | 599 | five minutes at the piano |
| `Piano Session 10 Minutes` | 899 | ten minutes at the piano |
| `Gold-Leaf Spritz` | 75 | the Terrace Bar: a glowing spritz with gold leaf to hold and sip (no alcohol; cosmetic) |
| `Macaron Tower` | 149 | the Terrace Bar: a tower of twelve macarons with sparkles (cosmetic) |
| `Suite Fireworks` | 199 | a 45-second pyromusical over the whole estate (for the buyer's screen), played from the Suite when you choose |
| `Meme Takeover` | 299 | ninety seconds, six acts: a meme portal, a conga line round you, meme rain, a giant laser-eyed boss meme, a confetti finale (for the buyer's screen) |
| `Golden Transformation` | 499 | the Midas touch, forty seconds: the Suite turns to gold, gold confetti and coins fall, a choir, a crown; then all as it was (for the buyer's screen) |
| `Gem Pouch` | 199 | 250 Gems, for the Cabinet's curios (each at a fixed Gem price) |
| `Gem Case` | 799 | 1,100 Gems |
| `Gem Trunk` | 1999 | 3,000 Gems |
| `Grand Platter` | 299 | the Terrace Bar: a platter of sweets; every guest near you is handed a macaron (cosmetic) |

Until a `Boutique NN` product exists, the pieces at that price are sold for Gilt only (40 Gilt
for each Robux of the price, `Config.Gilt.perRobux`): a 249 piece is 9,960 Gilt. Make the
product and its pieces' Robux key appears by itself, beside the Gilt price. Anything else in the
Boutique whose product isn't made yet says "not on sale yet" instead of showing a key.

**The VIP Velocity Elite game pass** (a pass shows on the game page, which sells it better):
Creator Hub → your experience → **Monetization** → **Passes** → **Create a Pass**: name
*VIP Velocity Elite*, an image (`assets/passes/vip-velocity-elite.png`), **Save**; open it → **Sales** → on sale, price **299**. Copy the
pass's id (the number in its page address) into Creator Hub → your experience → **Configs** as
`Products_velocityElite` (live, no republish), or into `Products.velocityElite` in
`src/shared/Config.luau`. Guests who bought the developer
product keep it; nobody can pay twice (a second purchase becomes Boutique credit).

Where guests meet them: a gold **Shop** key at the top right while they walk, the **Offers**
page that opens first in the Boutique (Emperor's Decree has *Write it*: words first, then the
purchase), the revive card when a timed room's clock runs out, and (once a session, after a
couple of runs) a small card saying what Double Gilt would have paid for the run just played.
Scores and leaderboards are never for sale, so the boards stay fair and players keep coming back.
How every purchase is processed, logged and protected: **MONETIZATION.md**.

**Private servers** (A Private Evening): Creator Hub → your experience → **Monetization** →
**Private Servers** → Enable, price **199** Robux a month (Appendix I).

**The Black Card** (only if you launch with it, §19 #6): Creator Hub → your experience →
**Monetization** → **Subscriptions** → **Create**: name *The Black Card*, the price tier nearest
US$4.99 a month, description *"The Leather-Bound Ledger while you hold it, a cardholder look
each month to keep, and a black-lacquer nameplate."* Copy its id (`EXP-…`) into
`Products.blackCard`.

© AJKR

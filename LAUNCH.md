# Maison Noir — the launch kit

Everything the game page needs, and the few switches to flip before the doors open. The words
are written to be pasted as they are; the pictures are real shots of the game, taken in Studio
with the camera positions below, so the page never promises something the game isn't.

---

## 1. The game page

**Name** (your decision, §19 #3). Suggestions, shortest first:
- **Maison Noir**
- **Maison Noir: Sort the Night**
- **Maison Noir — a house of fine things**

**Genre:** Puzzle. **Subgenre:** Sorting / Matching. (Set up as what it is: a puzzle and
competition game with a beautiful lobby. Roblox's younger catalogues leave out social
hangouts, so it shouldn't be described as one.)

**Description** (paste as is, about 900 characters):

> A private members' house at midnight, and a table covered in expensive things.
>
> Sort watches, jewels, keys and curios into their cases before the clock runs down. Three in
> a row pays. The light shows you where things belong, and every room plays by its own rules:
> the Salon is gentle, the Obsidian Room is not.
>
> Once a night, everyone on Roblox sits the same table: the Nightly. Up the Grand Stair,
> members compete: head to head in the Library, twenty at a time in the Ballroom, where the
> lamps go out one by one until only one is left.
>
> Collect every piece for your Vault, furnish your Suite, earn your House Standing and a
> hallmark beside your name. Nothing here can be bought that wins a game: everything sold is
> style.
>
> The house follows the calendar: snow at Yuletide, lanterns at All Hallows, the terrace open
> in High Summer.
>
> development of AJKR

**Tags / keywords to pick where Roblox offers them:** puzzle, sorting, collecting, luxury,
competitive, leaderboard, seasonal.

**Social links:** none (no links off Roblox, §13).

---

## 2. The icon (512 × 512)

One idea, taken in-game, no text but the tiny mark:

- **A single gilded watch on black-green felt, in the pool of light from the table lamp**, seen
  from slightly above, with the brass edge of a case in the corner. The small *MN* hairline
  mark bottom-right.

Keep it for weeks at a time: icons can't be A/B tested on Roblox yet, so compare click-through
by traffic source in Creator Analytics before and after any change.

---

## 3. Thumbnails (1920 × 1080), five real shots

Take them in Studio, in **Run** mode (the server builds the house), with this pasted into the
**Command Bar** (View → Command Bar) one line at a time. Each line points Studio's camera at one
shot. Then take the screenshot with Studio's screenshot tool (the **View** tab → **Screenshot**).

```lua
-- 1. The street at night: the facade, the lanterns, the door.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-26, 8, -44), Vector3.new(0, 11, -10))
-- 2. The Foyer: the chandelier, the piano, the Grand Stair.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-18, 9, -4), Vector3.new(6, 12, 28))
-- 3. The Ballroom from the Gallery: twenty lamps in a ring.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(61, 40, 73), Vector3.new(61, 22, 125))
-- 4. The Library: two long tables under green lamps.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-2, 27, 72), Vector3.new(-20, 21, 90))
-- 5. The Suite by the fire.
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(-38, 28, 42), Vector3.new(-52, 24, 58))
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
- **Paid random items:** **no.** Nothing sold is random; Mythics can't be bought.
- **Social:** Roblox's own chat only; no custom chat.
- **Free-form user creation:** none (no typing anywhere; Circle names are chosen from lists).

Minimal or Mild reaches the youngest catalogue (Roblox Kids); up to Moderate reaches Select.
Reaching under-16s also needs ID and two-step verification on the owner's account and either
Roblox Plus or the refundable publishing fee.

---

## 6. Switches to flip before the doors open

All in `src/shared/Config.luau` (or live, in Creator Hub → Configs, as `Section_key`):

| What | Where | Value |
| --- | --- | --- |
| The Founding Term | `FoundingTerm` | the Term you launch in, e.g. `2026-autumn` |
| Every product | nothing to paste | make each developer product in Creator Hub with its name from the table below; the game finds it by name |
| Trusted helpers for House controls | `Admin.userIds` | their Roblox user ids (you, as owner, are always allowed) |
| The Black Card | `Products.blackCard` | the subscription's id (`EXP-…`), or leave `""` to launch without it |
| Badges | `Badges.*` | from Creator Hub → Badges |
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
| `Double Gilt` | 399 | every Gilt the buyer earns, doubled, for good (the best seller in games like this) |
| `Gilt Purse` | 49 | 1,000 Gilt |
| `Gilt Chest` | 199 | 5,500 Gilt |
| `Gilt Vault` | 499 | 18,000 Gilt |
| `Golden Hour for Everyone` | 99 | double Gilt for everyone in the server for 15 minutes, buyer announced |
| `The Gold Key` | 499 | +20% Gilt, the Study, gold nameplate and Gold Key looks (or make a game pass and paste its id in `Products.goldKey`) |
| `The Introduction` | 99 | the first-week starter pack |
| `Salute: Gold Leaf` / `Salute: Encore` / `Salute: Chandelier` / `Salute: Fireworks` / `Salute: Grand Salute` | 49 / 79 / 99 / 149 / 399 | a moment for the whole house |
| `Boutique 49` … `Boutique 599` (ten: 49, 79, 99, 149, 199, 249, 299, 399, 499, 599) | the number in the name | the Boutique's pieces at that price |
| `Leather-Bound Ledger` | 299 | the Term's premium Ledger row |
| `Season Collection` | 399 | the season's pieces |
| `Gold Key Gift` | 499 | the Gold Key, for another guest |

Where guests meet them: a gold **Shop** key at the top right while they walk, the **Offers**
page that opens first in the Boutique, and (once a session, after a couple of runs) a small card
saying what Double Gilt would have paid for the run just played. Scores and leaderboards are
never for sale, so the boards stay fair and players keep coming back.

**Private servers** (A Private Evening): Creator Hub → your experience → **Monetization** →
**Private Servers** → Enable, price **199** Robux a month (Appendix I).

**The Black Card** (only if you launch with it, §19 #6): Creator Hub → your experience →
**Monetization** → **Subscriptions** → **Create**: name *The Black Card*, the price tier nearest
US$4.99 a month, description *"The Leather-Bound Ledger while you hold it, a cardholder look
each month to keep, and a black-lacquer nameplate."* Copy its id (`EXP-…`) into
`Products.blackCard`.

© AJKR

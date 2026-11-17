#!/usr/bin/env python3
"""Icons for every product and pass in shared/ProductConfig (Build 87), in the house style of
assets/passes/*.png: 512 x 512, a dark ground with a faint dot grid, a gold outer ring, an inner
ring in the product's own colour, its motif in the middle with a glow and a few sparkles, and its
short name on a serif pill. Everything that matters sits inside the circle, so a round crop (the
store's, Roblox's purchase prompt) loses nothing.

Writes assets/product-icons/<key>.png and assets/product-icons/MAPPING.md (which file is for which
product, by the exact name in Creator Hub). NOTHING here uploads or assigns anything: upload each
file to its product in Creator Hub yourself (Monetization -> Developer Products / Passes -> the
product -> Icon).

    python3 tools/art/product_icons.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "product-icons")
EMOJI = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
S = 512
GOLD = (232, 186, 82)
GOLD_LIGHT = (255, 226, 150)

# key, the exact name in Creator Hub, its kind, the motif, the label on its pill, its colour.
# (A pass and the product that stands in for it share one picture: they're the same thing.)
PRODUCTS = [
    ("velocityElite", "VIP Velocity Elite", "pass", "⚡", "VELOCITY", (80, 200, 255)),
    ("velocityEliteProduct", "VIP Velocity Elite", "product", "⚡", "VELOCITY", (80, 200, 255)),
    ("chronosDefiance", "Chronos Defiance", "product", "⏳", "CHRONOS", (190, 140, 255)),
    ("reviveVelvet", "Revive: Velvet Room", "product", "🛟", "REVIVE · LUXE", (255, 92, 124)),
    ("reviveObsidian", "Revive: Obsidian Room", "product", "🪜", "REVIVE · BASEMENT", (226, 152, 92)),
    ("reviveMidnight", "Revive: Midnight Room", "product", "🩹", "REVIVE · SUITE", (110, 200, 255)),
    ("emperorsDecree", "Emperor's Decree", "product", "📜", "DECREE", (255, 200, 90)),
    ("godModeLuck", "Luck Booster", "product", "🍀", "LUCK", (110, 230, 140)),
    ("megalodonRainmaker", "Megalodon Rainmaker", "product", "🦈", "RAINMAKER", (90, 170, 255)),
    ("pianoSession1", "Piano Session 1 Minute", "product", "🎹", "1 MINUTE", (200, 200, 220)),
    ("pianoSession3", "Piano Session 3 Minutes", "product", "🎹", "3 MINUTES", (170, 190, 255)),
    ("pianoSession5", "Piano Session 5 Minutes", "product", "🎹", "5 MINUTES", (150, 120, 255)),
    ("pianoSession10", "Piano Session 10 Minutes", "product", "🎹", "10 MINUTES", (255, 150, 220)),
    ("barGoldSpritz", "Gold-Leaf Spritz", "product", "🥂", "SPRITZ", (255, 214, 120)),
    ("barMacaronTower", "Macaron Tower", "product", "🧁", "MACARONS", (255, 160, 200)),
    ("barGrandPlatter", "Grand Platter", "product", "🍽️", "PLATTER", (230, 220, 200)),
    ("gems1", "Gem Pouch", "product", "💎", "GEM POUCH", (120, 210, 255)),
    ("gems2", "Gem Case", "product", "💼", "GEM CASE", (80, 160, 255)),
    ("gems3", "Gem Trunk", "product", "🧳", "GEM TRUNK", (60, 110, 255)),
    ("spectacleFireworks", "Suite Fireworks", "product", "🎆", "FIREWORKS", (255, 120, 220)),
    ("spectacleMemes", "Meme Takeover", "product", "🤪", "MEMES", (255, 180, 60)),
    ("spectacleGolden", "Golden Transformation", "product", "🌟", "GOLDEN", (255, 214, 90)),
    ("doubleGilt", "Double Gilt", "product", "🪙", "DOUBLE GILT", (255, 200, 70)),
    ("goldenHour", "Golden Hour for Everyone", "product", "🌅", "GOLDEN HOUR", (255, 150, 70)),
    ("giltPurse1", "Gilt Purse", "product", "👛", "GILT PURSE", (232, 186, 82)),
    ("giltPurse2", "Gilt Chest", "product", "💰", "GILT CHEST", (240, 170, 60)),
    ("giltPurse3", "Gilt Vault", "product", "🏦", "GILT VAULT", (220, 150, 40)),
    ("goldKey", "The Gold Key", "pass", "🔑", "GOLD KEY", (255, 60, 170)),
    ("goldKeyProduct", "The Gold Key", "product", "🔑", "GOLD KEY", (255, 60, 170)),
    ("goldKeyGift", "Gold Key Gift", "product", "🎁", "GOLD KEY GIFT", (255, 90, 120)),
    ("introduction", "The Introduction", "product", "🎩", "INTRODUCTION", (255, 220, 160)),
    ("ledger", "Leather-Bound Ledger", "product", "📒", "LEDGER", (200, 140, 80)),
    ("season", "Season Collection", "product", "🧥", "SEASON", (170, 120, 255)),
    ("ballroomBomb", "Ballroom: Parcel Bomb", "product", "💣", "PARCEL BOMB", (255, 110, 80)),
    ("ballroomBlackout", "Ballroom: Blackout", "product", "🌑", "BLACKOUT", (140, 140, 170)),
    ("ballroomFreeze", "Ballroom: Butterfingers", "product", "🧈", "BUTTERFINGERS", (255, 230, 120)),
    ("ballroomShield", "Ballroom: Shield", "product", "🛡️", "SHIELD", (120, 220, 255)),
    ("ballroomOpen", "Open the Ballroom Now", "product", "🪩", "BALLROOM NOW", (220, 130, 255)),
    ("grandPrixOpen", "Open the Grand Prix Now", "product", "🏁", "GRAND PRIX NOW", (240, 240, 240)),
    ("grandPrixGarage", "The Private Garage", "product", "🏎️", "PRIVATE GARAGE", (255, 80, 80)),
    ("basementSkip", "Basement: Skip a Stage", "product", "⏭️", "SKIP A STAGE", (226, 152, 92)),
    ("turkeyMore", "Turkey Round-Up: 10 More", "product", "🦃", "10 MORE", (230, 150, 70)),
    ("turkeyHunter", "Turkey Hunter Pass", "product", "🎯", "TURKEY HUNTER", (200, 110, 50)),
    ("sleighRide", "Another Sleigh Ride", "product", "🛷", "SLEIGH RIDE", (255, 90, 90)),
    ("sleighSeason", "Santa's Season Pass", "product", "🎅", "SANTA'S SEASON", (230, 50, 60)),
    ("jetAurora", "Jet Livery: Midnight Aurora", "product", "✈️", "AURORA", (130, 110, 255)),
    ("jetSovereign", "Jet Livery: Sovereign Gold", "product", "🛩️", "SOVEREIGN GOLD", (255, 200, 80)),
    ("brainrotPenthouse", "Brainrot Penthouse", "product", "🏙️", "PENTHOUSE", (255, 140, 200)),
    ("brainrotFeast", "Brainrot Feast", "product", "🍝", "FEAST", (255, 170, 90)),
    ("salute_goldLeaf", "Salute: Gold Confetti", "product", "🎊", "GOLD CONFETTI", (255, 210, 100)),
    ("salute_encore", "Salute: Encore", "product", "👏", "ENCORE", (255, 190, 140)),
    ("salute_chandelier", "Salute: Chandelier", "product", "🕯️", "CHANDELIER", (255, 230, 170)),
    ("salute_fireworks", "Salute: Fireworks", "product", "🎇", "FIREWORKS", (255, 140, 90)),
    ("salute_grand", "Salute: Grand Salute", "product", "🎖️", "GRAND SALUTE", (232, 186, 82)),
    ("salute_sleigh", "Salute: Santa's Flyover", "product", "🦌", "SANTA'S FLYOVER", (200, 120, 80)),
    ("salute_finale", "Salute: Midnight Finale", "product", "🌌", "MIDNIGHT FINALE", (110, 120, 255)),
]
# The Boutique's price tiers: a finer thing for each, its tier on the pill, the colour deepening
# with the price.
TIERS = [(49, "🎀"), (79, "🧣"), (99, "👠"), (149, "👜"), (199, "🕶️"), (249, "💄"), (299, "⌚"), (399, "💍"), (499, "👑"), (599, "🏆")]
for i, (t, motif) in enumerate(TIERS):
    f = i / (len(TIERS) - 1)
    colour = (int(200 + 55 * f), int(200 - 40 * f), int(220 - 160 * f))
    PRODUCTS.append((f"tier{t}", f"Boutique {t}", "product", motif, f"BOUTIQUE {t}", colour))


def emoji_image(ch: str, size: int) -> Image.Image:
    font = ImageFont.truetype(EMOJI, 109)
    tmp = Image.new("RGBA", (160, 160), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((80, 80), ch, font=font, embedded_color=True, anchor="mm")
    box = tmp.getbbox()
    if box:
        tmp = tmp.crop(box)
    w, h = tmp.size
    k = size / max(w, h)
    return tmp.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)


def sparkle(d: ImageDraw.ImageDraw, x: float, y: float, r: float, colour):
    d.polygon([(x, y - r), (x + r * 0.22, y - r * 0.22), (x + r, y), (x + r * 0.22, y + r * 0.22), (x, y + r), (x - r * 0.22, y + r * 0.22), (x - r, y), (x - r * 0.22, y - r * 0.22)], fill=colour)


def icon(key: str, motif: str, label: str, colour) -> Image.Image:
    img = Image.new("RGBA", (S, S), (14, 12, 16, 255))
    d = ImageDraw.Draw(img)
    # A faint dot grid, as on the passes.
    for y in range(16, S, 32):
        for x in range(16, S, 32):
            d.ellipse((x - 4, y - 4, x + 4, y + 4), outline=(40, 38, 46), width=1)
    c = S / 2
    # The disc: a soft glow of the product's colour toward the middle.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for k in range(18, 0, -1):
        r = 228 * k / 18
        a = int(10 + 4 * (18 - k))
        gd.ellipse((c - r, c - r, c + r, c + r), fill=(colour[0], colour[1], colour[2], min(a, 60)))
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    disc = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(disc).ellipse((c - 232, c - 232, c + 232, c + 232), fill=(22, 18, 24, 255))
    img = Image.alpha_composite(img, disc)
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    # The gold ring, and the inner ring in the product's colour.
    d.ellipse((c - 244, c - 244, c + 244, c + 244), outline=GOLD, width=14)
    d.ellipse((c - 250, c - 250, c + 250, c + 250), outline=(120, 92, 36), width=2)
    inner = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(inner).ellipse((c - 222, c - 222, c + 222, c + 222), outline=colour + (255,), width=4)
    img = Image.alpha_composite(img, inner.filter(ImageFilter.GaussianBlur(3)))
    img = Image.alpha_composite(img, inner)
    # The motif, with a glow behind it.
    m = emoji_image(motif, 230)
    halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    hd.ellipse((c - 120, c - 150, c + 120, c + 90), fill=colour + (90,))
    img = Image.alpha_composite(img, halo.filter(ImageFilter.GaussianBlur(40)))
    img.alpha_composite(m, (int(c - m.width / 2), int(c - 30 - m.height / 2)))
    d = ImageDraw.Draw(img)
    # Sparkles, placed by the key so each icon has its own.
    seed = sum(ord(ch) for ch in key)
    for n in range(3):
        a = (seed * (n + 3) * 37) % 360
        rr = 150 + (seed * (n + 1)) % 50
        x = c + math.cos(math.radians(a)) * rr
        y = c - 30 + math.sin(math.radians(a)) * rr * 0.8
        sparkle(d, x, y, 14 - n * 3, (255, 244, 214))
    # The name on its pill, inside the circle.
    size = 34
    font = ImageFont.truetype(SERIF, size)
    while d.textlength(label, font=font) > 300 and size > 18:
        size -= 1
        font = ImageFont.truetype(SERIF, size)
    tw = d.textlength(label, font=font)
    pw, ph = max(170, tw + 56), size + 26
    py = 392
    d.rounded_rectangle((c - pw / 2, py - ph / 2, c + pw / 2, py + ph / 2), radius=ph / 2, fill=(14, 10, 8), outline=GOLD, width=4)
    d.text((c, py + 1), label, font=font, fill=GOLD_LIGHT, anchor="mm")
    return img.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    rows = []
    for key, name, kind, motif, label, colour in PRODUCTS:
        path = os.path.join(OUT, f"{key}.png")
        icon(key, motif, label, colour).save(path, optimize=True)
        rows.append((key, name, kind, f"{key}.png"))
    with open(os.path.join(OUT, "MAPPING.md"), "w") as f:
        f.write("# Product icons (Build 87)\n\n")
        f.write("512 x 512 PNGs, one for every product and pass in `src/shared/ProductConfig.luau`, made by\n")
        f.write("`python3 tools/art/product_icons.py`. Everything that matters sits inside the circle, so a round\n")
        f.write("crop loses nothing.\n\n")
        f.write("**None of these has been uploaded or assigned.** To use one: Creator Hub -> your experience ->\n")
        f.write("Monetization -> Developer Products (or Passes) -> the product with the name below -> its icon ->\n")
        f.write("upload the file. A pass and the product that stands in for it share one picture.\n\n")
        f.write("| Key in ProductConfig | Name in Creator Hub | Kind | File |\n|---|---|---|---|\n")
        for key, name, kind, file in rows:
            f.write(f"| `{key}` | {name} | {kind} | `{file}` |\n")
    print(f"{len(rows)} icons written to {OUT}")


if __name__ == "__main__":
    main()

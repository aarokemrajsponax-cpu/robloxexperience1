#!/usr/bin/env python3
"""Icons for every badge in the Badge Book (shared/BadgeBook), Build 88: 512 x 512 medals, each its
own. The tier is the metal of the ring (bronze, silver, gold, platinum), the group the colour of the
enamel, the badge's glyph in the middle, a laurel round it, its count on a chip at the top when it's
a ladder's step (10, 100, 1,000...), and its name on a ribbon. Roblox shows badges in a circle, so
everything sits inside one.

Reads assets/badge-icons/badges.json (the Badge Book's list: key, name, line, glyph, tier, group)
and writes assets/badge-icons/<key>.png and assets/badge-icons/MAPPING.md. NOTHING here creates,
uploads or assigns a badge: each is made in Creator Hub, and its id put in Config.Badges under the
same key (see MAPPING.md).

    python3 tools/art/badge_icons.py
"""
import json
import math
import os
import re

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "badge-icons")
EMOJI = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
SANS = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
S = 512

METALS = {
    "bronze": ((236, 170, 110), (150, 84, 40)),
    "silver": ((244, 246, 252), (130, 138, 152)),
    "gold": ((255, 230, 140), (176, 120, 30)),
    "platinum": ((230, 246, 255), (120, 160, 210)),
}
GROUPS = {
    "level": (90, 140, 255), "tables": (80, 170, 120), "nights": (110, 90, 200), "library": (150, 100, 60),
    "ballroom": (210, 80, 160), "collection": (230, 170, 60), "wealth": (240, 200, 70), "events": (240, 90, 90),
    "holidays": (220, 60, 70), "social": (90, 200, 220), "attractions": (200, 60, 90), "island": (60, 190, 200),
    "racing": (230, 70, 50), "pavilion": (200, 150, 255), "secrets": (130, 130, 150),
}


def emoji_image(ch, size):
    font = ImageFont.truetype(EMOJI, 109)
    tmp = Image.new("RGBA", (180, 180), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((90, 90), ch, font=font, embedded_color=True, anchor="mm")
    box = tmp.getbbox()
    if box:
        tmp = tmp.crop(box)
    w, h = tmp.size
    k = size / max(w, h)
    return tmp.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)


def ring(img, c, r_out, r_in, light, dark):
    """A metal ring: a vertical gradient from light to dark, between two radii."""
    grad = Image.new("RGBA", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        f = y / S
        col = tuple(int(light[i] * (1 - f) + dark[i] * f) for i in range(3))
        gd.line([(0, y), (S, y)], fill=col + (255,))
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    md.ellipse((c - r_out, c - r_out, c + r_out, c + r_out), fill=255)
    md.ellipse((c - r_in, c - r_in, c + r_in, c + r_in), fill=0)
    img.paste(grad, (0, 0), mask)


def count_of(key):
    m = re.search(r"_(\d+)$", key)
    return int(m.group(1)) if m else None


def short(n):
    if n >= 1_000_000:
        return f"{n // 1_000_000}M"
    if n >= 10_000:
        return f"{n // 1000}K"
    return f"{n:,}"


def medal(b):
    img = Image.new("RGBA", (S, S), (12, 10, 14, 255))
    c = S / 2
    light, dark = METALS.get(b["tier"], METALS["bronze"])
    accent = GROUPS.get(b["group"], (200, 170, 90))
    # The enamel: the group's colour, deep at the edge, lit toward the middle.
    enamel = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ed = ImageDraw.Draw(enamel)
    for k in range(40, 0, -1):
        r = 214 * k / 40
        f = k / 40
        col = tuple(int(accent[i] * (0.25 + 0.55 * (1 - f)) + 10) for i in range(3))
        ed.ellipse((c - r, c - r, c + r, c + r), fill=col + (255,))
    img = Image.alpha_composite(img, enamel)
    ring(img, c, 250, 214, light, dark)
    d = ImageDraw.Draw(img)
    d.ellipse((c - 250, c - 250, c + 250, c + 250), outline=dark, width=3)
    d.ellipse((c - 214, c - 214, c + 214, c + 214), outline=dark, width=3)
    d.ellipse((c - 205, c - 205, c + 205, c + 205), outline=light + (120,), width=2)
    # A laurel round the lower half: leaves along an arc, both sides.
    for side in (-1, 1):
        for i in range(7):
            a = math.radians(110 + i * 14)
            x = c + side * math.cos(a) * -178
            y = c + math.sin(a) * 178
            rot = (a + math.pi / 2) * side
            leaf = Image.new("RGBA", (40, 18), (0, 0, 0, 0))
            ImageDraw.Draw(leaf).ellipse((0, 0, 39, 17), fill=light + (235,), outline=dark)
            leaf = leaf.rotate(math.degrees(-rot) + (180 if side < 0 else 0), expand=True, resample=Image.BICUBIC)
            img.alpha_composite(leaf, (int(x - leaf.width / 2), int(y - leaf.height / 2)))
    # The glyph, with a soft glow behind it.
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((c - 110, c - 130, c + 110, c + 90), fill=light + (110,))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(36)))
    g = emoji_image(b["glyph"], 190)
    img.alpha_composite(g, (int(c - g.width / 2), int(c - 22 - g.height / 2)))
    d = ImageDraw.Draw(img)
    # The count on its chip at the top, for a ladder's step.
    n = count_of(b["key"])
    if n is not None and n > 1:
        f = ImageFont.truetype(SANS, 34)
        t = short(n)
        tw = d.textlength(t, font=f)
        w = max(76, tw + 34)
        d.rounded_rectangle((c - w / 2, 34, c + w / 2, 84), radius=25, fill=(16, 12, 10), outline=light, width=4)
        d.text((c, 60), t, font=f, fill=light, anchor="mm")
    # The name on a ribbon.
    name = b["name"].upper()
    size = 30
    f = ImageFont.truetype(SERIF, size)
    while d.textlength(name, font=f) > 318 and size > 15:
        size -= 1
        f = ImageFont.truetype(SERIF, size)
    tw = d.textlength(name, font=f)
    rw, rh, ry = max(190, tw + 60), size + 24, 392
    d.polygon([(c - rw / 2 - 22, ry - rh / 2 + 6), (c - rw / 2, ry - rh / 2 + 6), (c - rw / 2, ry + rh / 2 + 6), (c - rw / 2 - 22, ry + rh / 2 + 6), (c - rw / 2 - 10, ry + 6)], fill=dark)
    d.polygon([(c + rw / 2 + 22, ry - rh / 2 + 6), (c + rw / 2, ry - rh / 2 + 6), (c + rw / 2, ry + rh / 2 + 6), (c + rw / 2 + 22, ry + rh / 2 + 6), (c + rw / 2 + 10, ry + 6)], fill=dark)
    d.rounded_rectangle((c - rw / 2, ry - rh / 2, c + rw / 2, ry + rh / 2), radius=10, fill=(18, 14, 12), outline=light, width=4)
    d.text((c, ry + 1), name, font=f, fill=light, anchor="mm")
    return img.convert("RGB")


def main():
    badges = json.load(open(os.path.join(OUT, "badges.json")))
    rows = []
    for b in badges:
        # (256 colours keep the repository light; a medal has few of its own.)
        medal(b).quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(os.path.join(OUT, f"{b['key']}.png"), optimize=True)
        rows.append(b)
    with open(os.path.join(OUT, "MAPPING.md"), "w") as f:
        f.write("# Badge icons (Build 88)\n\n")
        f.write(f"{len(rows)} medals, one for every badge in the Badge Book (`src/shared/BadgeBook.luau`), made by\n")
        f.write("`python3 tools/art/badge_icons.py`. The ring is the tier, the enamel the group, the chip the count.\n\n")
        f.write("**None of these has been created, uploaded or assigned in Roblox.** The game already earns every\n")
        f.write("badge in the Badge Book by itself; to make one a real Roblox profile badge too:\n\n")
        f.write("1. Creator Hub -> your experience -> Engagement (or Associated Items) -> Badges -> Create a Badge.\n")
        f.write("2. Name and description: copy them from the table below. Image: the file below.\n")
        f.write("3. Copy the new badge's id and paste it into `src/shared/Config.luau` -> `Badges`, under the same key\n")
        f.write("   (add the key if it isn't listed). Sync and publish. Guests who already earned it get it on their\n")
        f.write("   next visit (`Achievements.syncRoblox`).\n\n")
        f.write("Roblox limits how many badges can be made free each day; check Creator Hub for the current cost.\n")
        f.write("Start with `nights_1` (Welcome to the Maison, every guest's first evening).\n\n")
        f.write("| Key | Name | Description | Tier | File |\n|---|---|---|---|---|\n")
        for b in rows:
            f.write(f"| `{b['key']}` | {b['name']} | {b['line']} | {b['tier']} | `{b['key']}.png` |\n")
    print(f"{len(rows)} badge icons written to {OUT}")


if __name__ == "__main__":
    main()

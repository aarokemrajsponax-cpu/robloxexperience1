#!/usr/bin/env python3
"""Maison Noir's piece illustrations, drawn with the shapes Roblox's UI can draw.

Every piece on the sorting screen is a small illustration made of rounded boxes, circles and
rings with gradients and outlines (Frames, UICorner, UIGradient, UIStroke), so the art needs no
uploaded images and works the moment the code syncs. The same definitions are rendered here to
PNG so they can be looked at and judged before they ship.

Writes:
  src/shared/PieceArt.luau            the shapes, read by src/client/UI/PieceIcon.luau
  tools/art/preview/pieces.png        every piece on the tray, with its name
  tools/art/preview/cases.png         the six case marks

Usage (from the repo root):  python3 tools/art/pieces.py
Needs: Pillow, numpy.

The canvas is 100 x 100. Shapes are placed by their centre. Rotation is clockwise, as in Roblox.
A UIStroke draws outside a shape's edge. ClipsDescendants (`clip`) only works when nothing above
the shape is rotated, so the previewer ignores clips inside rotated groups, exactly as Roblox does.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
PREVIEW = os.path.join(os.path.dirname(os.path.abspath(__file__)), "preview")

# ---------------------------------------------------------------------------------------------
# Materials: gradient stops (t, (r, g, b)).
# ---------------------------------------------------------------------------------------------


def stops(*pairs):
    return [(t, tuple(c)) for t, c in pairs]


GOLD = stops((0, (120, 82, 28)), (0.32, (226, 182, 96)), (0.5, (255, 238, 178)), (0.72, (214, 164, 72)), (1, (128, 88, 32)))
GOLD_SOFT = stops((0, (176, 128, 52)), (0.5, (246, 214, 140)), (1, (168, 120, 46)))
GOLD_DARK = stops((0, (92, 62, 22)), (0.5, (170, 124, 52)), (1, (84, 56, 20)))
ROSE = stops((0, (150, 92, 72)), (0.45, (238, 186, 160)), (1, (150, 90, 70)))
STEEL = stops((0, (104, 110, 122)), (0.38, (214, 220, 228)), (0.55, (246, 248, 252)), (0.78, (170, 176, 188)), (1, (96, 102, 114)))
PLATINUM = stops((0, (150, 156, 166)), (0.45, (238, 242, 246)), (0.6, (255, 255, 255)), (1, (160, 166, 176)))
COPPER = stops((0, (110, 52, 26)), (0.45, (222, 138, 88)), (0.6, (248, 186, 140)), (1, (116, 56, 28)))
BLACK = stops((0, (8, 8, 11)), (0.55, (40, 40, 48)), (1, (14, 14, 18)))
LACQUER = stops((0, (24, 24, 30)), (0.3, (62, 62, 72)), (0.42, (20, 20, 26)), (1, (6, 6, 8)))
IVORY = stops((0, (250, 246, 236)), (1, (214, 204, 182)))
WHITE_DIAL = stops((0, (255, 254, 250)), (1, (222, 218, 208)))
NAVY = stops((0, (20, 32, 72)), (1, (8, 14, 36)))
LEATHER = stops((0, (88, 52, 30)), (0.5, (120, 74, 44)), (1, (64, 36, 20)))
LEATHER_DARK = stops((0, (46, 28, 18)), (1, (24, 14, 10)))
BURGUNDY = stops((0, (110, 30, 52)), (0.55, (76, 18, 36)), (1, (44, 10, 22)))
DIAMOND = stops((0, (182, 214, 244)), (0.35, (255, 255, 255)), (0.6, (206, 232, 252)), (1, (150, 186, 226)))
EMERALD = stops((0, (6, 92, 58)), (0.45, (40, 196, 130)), (0.6, (120, 236, 184)), (1, (4, 70, 44)))
RUBY = stops((0, (110, 6, 22)), (0.45, (226, 40, 70)), (0.6, (255, 120, 140)), (1, (96, 4, 18)))
SAPPHIRE = stops((0, (10, 26, 96)), (0.45, (40, 90, 210)), (0.6, (120, 170, 255)), (1, (8, 20, 80)))
AMBER = stops((0, (150, 70, 6)), (0.45, (246, 164, 40)), (0.6, (255, 214, 120)), (1, (140, 60, 4)))
PEARL = stops((0, (255, 255, 252)), (0.5, (240, 232, 222)), (1, (196, 184, 176)))
BLUE_PEARL = stops((0, (226, 238, 255)), (0.45, (150, 176, 226)), (1, (54, 72, 130)))
NOTE = stops((0, (238, 232, 212)), (1, (204, 196, 170)))
GREEN_NOTE = stops((0, (206, 222, 200)), (1, (160, 184, 156)))
GLASS = stops((0, (226, 236, 246)), (1, (150, 170, 196)))
ONYX = stops((0, (30, 30, 36)), (0.5, (70, 70, 84)), (1, (10, 10, 14)))
BONE = stops((0, (246, 242, 232)), (1, (200, 192, 176)))
GREEN = stops((0, (34, 120, 60)), (1, (14, 70, 32)))
PINK = stops((0, (255, 204, 214)), (1, (226, 128, 154)))
RED_ENAMEL = stops((0, (178, 22, 40)), (0.5, (230, 70, 80)), (1, (110, 8, 22)))
BLUE_ENAMEL = stops((0, (26, 60, 150)), (0.5, (70, 120, 220)), (1, (14, 32, 96)))
ICE = stops((0, (210, 236, 255)), (1, (120, 180, 236)))
IRON = stops((0, (56, 58, 64)), (0.5, (120, 124, 132)), (1, (40, 42, 48)))
BRONZE = stops((0, (104, 70, 36)), (0.5, (196, 150, 90)), (1, (92, 60, 30)))
CREAM = stops((0, (252, 246, 230)), (1, (226, 214, 188)))
WARM_GLOW = stops((0, (255, 236, 170)), (0.5, (255, 168, 70)), (1, (210, 96, 30)))


def solid(c):
    return [(0, tuple(c)), (1, tuple(c))]


# ---------------------------------------------------------------------------------------------
# Drawing
# ---------------------------------------------------------------------------------------------


class Art:
    def __init__(self):
        self.prims = []
        self._stack = [self.prims]

    def _add(self, p):
        self._stack[-1].append(p)
        return p

    def box(self, x, y, w, h, fill=None, r=0, cr=0.0, a=0.0, g=90, stroke=None, clip=None, ga=None):
        """A box centred at (x, y). `fill` is a gradient (or None for no fill); `cr` is the
        corner radius as a fraction of the shorter side (0.5 = round); `a` transparency;
        `stroke` = (thickness, gradient, transparency, rotation)."""
        p = {"t": "box", "x": x, "y": y, "w": w, "h": h, "r": r, "cr": cr, "a": a, "g": g}
        if fill is not None:
            p["fill"] = fill
        if stroke is not None:
            th, sf, sa, sg = list(stroke) + [None, None, 0.0, 90][len(stroke):]
            p["s"] = {"th": th, "fill": sf, "a": sa, "g": sg}
        if clip is not None:
            p["clip"] = clip
        if ga is not None:
            p["ga"] = ga
        return self._add(p)

    def circle(self, x, y, d, fill=None, **kw):
        return self.box(x, y, d, d, fill, cr=0.5, **kw)

    def ellipse(self, x, y, w, h, fill=None, **kw):
        return self.box(x, y, w, h, fill, cr=0.5, **kw)

    def ring(self, x, y, d, th, fill, a=0.0, g=90, h=None, clip=None):
        """A ring whose centre line has diameter d (an empty circle with an outside stroke)."""
        hh = (h if h is not None else d) - th
        return self.box(x, y, d - th, hh, None, cr=0.5, stroke=(th, fill, a, g), clip=clip)

    def text(self, x, y, w, h, text, size, colour, font="bold"):
        return self._add({"t": "text", "x": x, "y": y, "w": w, "h": h, "text": text, "size": size, "fill": solid(colour), "font": font})

    def group(self, r):
        """Shapes drawn inside this rotate together about the canvas centre."""
        art = self

        class _G:
            def __enter__(self_inner):
                g = {"t": "group", "r": r, "kids": []}
                art._add(g)
                art._stack.append(g["kids"])
                return g

            def __exit__(self_inner, *a):
                art._stack.pop()

        return _G()

    # Composite shapes ---------------------------------------------------------------------

    def tri_down(self, x, top, w, fill, g=90, a=0.0):
        """A downward triangle: apex below, flat top edge `w` wide at y = top (a rotated square,
        half of it clipped away)."""
        side = w / math.sqrt(2)
        self.box(x, top, side, side, fill, r=45, g=g, a=a, clip=[x - w / 2 - 1, top, x + w / 2 + 1, top + w / 2 + 1])

    def tri_up(self, x, base, w, fill, g=90, a=0.0):
        side = w / math.sqrt(2)
        self.box(x, base, side, side, fill, r=45, g=g, a=a, clip=[x - w / 2 - 1, base - w / 2 - 1, x + w / 2 + 1, base])

    def sparkle(self, x, y, s, colour=(255, 255, 255)):
        c = solid(colour)
        self.box(x, y, s * 0.16, s, c, cr=0.5)
        self.box(x, y, s, s * 0.16, c, cr=0.5)
        self.box(x, y, s * 0.12, s * 0.62, c, r=45, cr=0.5, a=0.25)
        self.box(x, y, s * 0.12, s * 0.62, c, r=-45, cr=0.5, a=0.25)

    def shine(self, x, y, w, h, r=-35, a=0.55):
        """A soft white highlight streak."""
        self.box(x, y, w, h, solid((255, 255, 255)), r=r, cr=0.5, a=a, ga=[(0, 1), (0.5, 0), (1, 1)], g=0)


# ---------------------------------------------------------------------------------------------
# The pieces
# ---------------------------------------------------------------------------------------------

ART = {}
_PIECES = []


def piece(fn):
    """Registers a piece's drawing (drawn once every helper is defined)."""
    _PIECES.append(fn)
    return fn


def draw_all():
    for fn in _PIECES:
        a = Art()
        fn(a)
        ART[fn.__name__] = a.prims


def indices(a, cx, cy, radius, n, w, h, colour, every=1, big=None):
    for i in range(n):
        ang = 2 * math.pi * i / n
        x = cx + radius * math.sin(ang)
        y = cy - radius * math.cos(ang)
        if big and i % big == 0:
            a.box(x, y, w * 1.6, h * 1.25, solid(colour), r=math.degrees(ang), cr=0.3)
        elif i % every == 0:
            a.box(x, y, w, h, solid(colour), r=math.degrees(ang), cr=0.3)


def hands(a, cx, cy, hour_deg, minute_deg, length, colour=(20, 20, 26), width=2.2):
    c = solid(colour)
    for deg, ln, wd in ((hour_deg, length * 0.62, width * 1.35), (minute_deg, length, width)):
        rad = math.radians(deg)
        x = cx + (ln / 2) * math.sin(rad)
        y = cy - (ln / 2) * math.cos(rad)
        a.box(x, y, wd, ln, c, r=deg, cr=0.5)
    a.circle(cx, cy, width * 2.2, solid(colour))


def wristwatch(a, case, dial, strap, strap_kind="leather", bezel=None, sub=False, moon=False, markers=(30, 30, 36), glow=False):
    # Strap: top and bottom, with stitching on leather and links on a bracelet.
    for y in (17, 83):
        a.box(50, y, 26, 32, strap, cr=0.18, g=0)
        if strap_kind == "leather":
            a.box(50, y, 21, 28, None, cr=0.16, stroke=(0.7, solid((210, 190, 160)), 0.55))
        else:
            for k in range(3):
                yy = y - 9 + k * 9
                a.box(50, yy, 25, 0.9, solid((60, 64, 72)), a=0.35)
    # Lugs
    for dx in (-10, 10):
        for dy in (-24, 24):
            a.box(50 + dx, 50 + dy, 4, 8, case, cr=0.3, g=0)
    # Case
    a.circle(50, 50, 54, case, g=45)
    a.circle(50, 50, 50, case, g=225)
    if bezel:
        a.circle(50, 50, 48, bezel, g=45)
        indices(a, 50, 50, 21.5, 12, 1.4, 3.2, (230, 230, 236), big=3)
    # Crown and pushers
    a.box(77.5, 50, 5, 8, case, cr=0.3, g=0)
    if sub:
        a.box(74.5, 37, 5, 5, case, r=-50, cr=0.3)
        a.box(74.5, 63, 5, 5, case, r=50, cr=0.3)
    d = 38 if bezel else 42
    a.circle(50, 50, d, dial, g=45)
    if moon:
        # The moon window: a half-disc of night sky with a gold moon rising.
        a.circle(50, 62, 16, NAVY, clip=[40, 54, 60, 62])
        a.circle(54, 60, 7, GOLD_SOFT, clip=[40, 54, 60, 62])
        for sx, sy in ((45, 57), (48, 59.5)):
            a.circle(sx, sy, 1, solid((255, 244, 210)), clip=[40, 54, 60, 62])
    if sub:
        for sx, sy in ((50, 39), (40, 52), (60, 52)):
            a.circle(sx, sy, 10, solid((236, 232, 222)), stroke=(0.7, solid((150, 140, 120)), 0.2))
            a.box(sx, sy - 2.2, 0.9, 4.4, solid((40, 40, 46)), cr=0.5)
    indices(a, 50, 50, (d / 2) - 4, 12, 1.2 if not glow else 2.2, 3.4 if not glow else 2.2, markers, big=3)
    if glow:
        for i in range(12):
            ang = 2 * math.pi * i / 12
            a.circle(50 + 13.5 * math.sin(ang), 50 - 13.5 * math.cos(ang), 2.4, solid((206, 250, 214)))
    hands(a, 50, 50, 300, 60, (d / 2) - 5, colour=markers if not glow else (230, 236, 240))
    a.box(50, 50 + (d / 2) * 0.45, 0.8, (d / 2) * 0.9, solid((190, 40, 40)), r=200, cr=0.5)
    a.shine(42, 40, 6, 30, r=-40, a=0.7)


@piece
def chronograph(a):
    wristwatch(a, STEEL, WHITE_DIAL, STEEL, strap_kind="bracelet", sub=True)


@piece
def dressWatch(a):
    wristwatch(a, GOLD, CREAM, LEATHER_DARK)


@piece
def diveWatch(a):
    wristwatch(a, STEEL, BLACK, STEEL, strap_kind="bracelet", bezel=stops((0, (20, 30, 60)), (1, (8, 12, 30))), glow=True, markers=(230, 236, 240))


@piece
def moonphase(a):
    wristwatch(a, ROSE, stops((0, (250, 246, 238)), (1, (220, 212, 200))), LEATHER, moon=True)


@piece
def noirChronometer(a):
    a.circle(50, 50, 84, solid((255, 220, 140)), a=0.86)
    wristwatch(a, LACQUER, BLACK, LEATHER_DARK, bezel=GOLD_DARK, markers=(236, 200, 120))


def pocket_watch(a, case, dial):
    # Bow and crown
    a.ring(50, 15, 16, 3.4, case, g=0)
    a.box(50, 24, 7, 6, case, cr=0.25, g=0)
    a.box(50, 28.5, 9, 3, case, cr=0.3, g=0)
    a.circle(50, 58, 66, case, g=45)
    a.circle(50, 58, 60, stops((0, (150, 108, 40)), (1, (250, 220, 150))), g=225)
    a.circle(50, 58, 52, dial, g=45)
    a.circle(50, 58, 46, None, stroke=(0.6, solid((120, 110, 90)), 0.3))
    for i in range(12):
        ang = 2 * math.pi * i / 12
        x = 50 + 19.5 * math.sin(ang)
        y = 58 - 19.5 * math.cos(ang)
        a.box(x, y, 1.5 if i % 3 else 2.4, 4 if i % 3 else 5.5, solid((40, 36, 32)), r=math.degrees(ang), cr=0.3)
    a.circle(50, 70, 11, None, stroke=(0.6, solid((120, 110, 90)), 0.3))
    a.box(50, 67.8, 0.8, 4.4, solid((40, 36, 32)), cr=0.5)
    hands(a, 50, 58, 120, 330, 19, colour=(30, 30, 46), width=2)
    a.shine(38, 46, 7, 34, r=-40, a=0.6)


@piece
def pocketWatch(a):
    pocket_watch(a, GOLD, WHITE_DIAL)


def band(a, cx, cy, d, th, metal, g=0):
    """A ring's band, seen at a slight angle: an ellipse ring with a darker inside."""
    a.ring(cx, cy, d, th, metal, g=g, h=d * 0.92)
    a.ring(cx, cy + 1.2, d - th * 1.15, th * 0.35, GOLD_DARK if metal is GOLD else stops((0, (70, 72, 80)), (1, (130, 134, 144))), a=0.35, h=(d - th * 1.15) * 0.92)


@piece
def diamondRing(a):
    band(a, 50, 64, 44, 6, GOLD)
    # Prongs
    for dx in (-6, 6):
        a.box(50 + dx, 40, 2.6, 9, GOLD, cr=0.5, g=0)
    a.box(50, 39, 18, 6, GOLD, cr=0.3, g=0)
    # The stone: a crown and a pointed pavilion
    a.box(50, 27, 18, 8, DIAMOND, cr=0.15, g=20)
    a.tri_up(41, 31, 8, DIAMOND, g=20)
    a.tri_up(59, 31, 8, DIAMOND, g=200)
    a.box(50, 31.5, 26, 2, DIAMOND, cr=0.3)
    a.tri_down(50, 32.5, 26, DIAMOND, g=0)
    a.box(50, 37, 1, 9, solid((255, 255, 255)), a=0.4)
    a.box(45, 36, 0.8, 8, solid((180, 210, 240)), r=-28, a=0.3)
    a.box(55, 36, 0.8, 8, solid((180, 210, 240)), r=28, a=0.3)
    a.sparkle(64, 20, 9)


@piece
def signetRing(a):
    band(a, 50, 62, 44, 7, GOLD)
    a.ellipse(50, 38, 32, 22, GOLD, g=45)
    a.ellipse(50, 38, 26, 17, GOLD_DARK, g=225)
    a.ellipse(50, 38, 22, 14, GOLD_SOFT, g=45)
    a.text(50, 38, 20, 14, "N", 11, (110, 76, 24), font="serif")
    a.shine(44, 33, 4, 12, a=0.5)


@piece
def tennisBracelet(a):
    a.ring(50, 52, 60, 2.2, PLATINUM, h=52)
    n = 16
    for i in range(n):
        ang = 2 * math.pi * i / n
        x = 50 + 29 * math.sin(ang)
        y = 52 - 25 * math.cos(ang)
        a.circle(x, y, 7.2, PLATINUM, g=45)
        a.circle(x, y, 5.2, DIAMOND, g=45)
        a.circle(x - 1, y - 1, 1.6, solid((255, 255, 255)))
    a.box(50, 78, 9, 5, PLATINUM, cr=0.3)
    a.sparkle(74, 30, 8)


@piece
def pearlNecklace(a):
    a.ring(50, 46, 62, 1.2, GOLD_SOFT, h=64, clip=[0, 46, 100, 100])
    n = 15
    for i in range(n):
        t = i / (n - 1)
        ang = math.pi * (0.04 + 0.92 * t)
        x = 50 - 30 * math.cos(ang)
        y = 44 + 30 * math.sin(ang)
        a.circle(x, y + 1, 8.4, solid((0, 0, 0)), a=0.75)
        a.circle(x, y, 8.4, PEARL, g=45)
        a.circle(x - 1.6, y - 1.6, 2.4, solid((255, 255, 255)), a=0.1)
    a.box(19.5, 40, 4, 6, GOLD, cr=0.3)
    a.box(80.5, 40, 4, 6, GOLD, cr=0.3)


def drop(a, x, top, metal, stone):
    a.circle(x, top, 10, metal, g=45)
    a.circle(x, top, 6, DIAMOND)
    a.box(x, top + 10, 1.8, 12, metal, cr=0.5)
    # A teardrop: a circle with a rotated square on top, in a gold setting
    a.box(x, top + 31, 17, 17, metal, r=45, g=10, cr=0.1)
    a.circle(x, top + 39, 24, metal, g=10)
    a.box(x, top + 31.5, 13, 13, stone, r=45, g=10, cr=0.1)
    a.circle(x, top + 39, 20, stone, g=10)
    a.circle(x - 4, top + 35, 5, solid((255, 255, 255)), a=0.3)


@piece
def earrings(a):
    drop(a, 32, 16, GOLD, SAPPHIRE)
    drop(a, 68, 16, GOLD, SAPPHIRE)
    a.sparkle(82, 44, 9)


@piece
def cufflinks(a):
    for x, y in ((36, 42), (64, 58)):
        a.box(x, y + 14, 4, 12, GOLD, cr=0.4, g=0)
        a.box(x, y + 21, 12, 4, GOLD, cr=0.5, g=0)
        a.box(x, y, 24, 24, GOLD, cr=0.2, g=45)
        a.box(x, y, 17, 17, ONYX, cr=0.16, g=45)
        a.box(x, y, 6, 6, GOLD_SOFT, r=45, cr=0.1)
        a.shine(x - 4, y - 3, 3, 12, a=0.6)


def bar(a, metal, stamp=(0, 0, 0), word=""):
    # A cast ingot in three-quarter view: a lighter top face, a front face, sloped ends.
    a.box(50, 64, 74, 22, metal, cr=0.08, g=90)
    a.box(50, 47, 58, 14, metal, cr=0.08, g=10)
    a.tri_up(21, 53, 16, metal, g=0)
    a.tri_up(79, 53, 16, metal, g=180)
    a.box(50, 53.5, 72, 1.2, solid((255, 255, 255)), a=0.4)
    a.box(50, 47, 32, 7, None, cr=0.1, stroke=(0.6, solid(stamp), 0.45))
    if word:
        a.text(50, 47, 32, 7, word, 4.6, stamp, font="serif")
    a.shine(34, 64, 4, 18, r=-30, a=0.55)


@piece
def goldBar(a):
    bar(a, GOLD, stamp=(110, 76, 22), word="999.9")


@piece
def platinumBar(a):
    bar(a, PLATINUM, stamp=(90, 96, 106), word="PT 950")


@piece
def copperBar(a):
    bar(a, COPPER, stamp=(96, 44, 20), word="CU")


def note(a, x, y, r, paper, ink):
    a.box(x, y, 64, 32, paper, r=r, cr=0.06, g=60, stroke=(0.8, solid(ink), 0.5))
    a.box(x, y, 56, 24, None, r=r, cr=0.06, stroke=(0.6, solid(ink), 0.55))


@piece
def cashStack(a):
    for i, (dx, dy, r) in enumerate(((-3, 6, -6), (2, 2, 3), (0, -2, -1))):
        note(a, 50 + dx, 52 + dy, r, GREEN_NOTE, (60, 90, 60))
    a.ellipse(50, 50, 14, 10, None, stroke=(0.8, solid((60, 90, 60)), 0.3))
    a.box(50, 50, 10, 34, stops((0, (180, 36, 46)), (1, (120, 18, 28))), r=-1, cr=0.08, g=0)
    a.box(50, 50, 10, 4, GOLD_SOFT, r=-1)


@piece
def goldCoins(a):
    # A short stack and two loose coins
    for i in range(5):
        y = 70 - i * 5
        a.ellipse(38, y + 2, 34, 12, GOLD_DARK, g=0)
        a.ellipse(38, y, 34, 12, GOLD, g=0)
    a.ellipse(38, 48, 34, 12, GOLD_SOFT, g=0)
    a.ellipse(38, 48, 26, 8, None, stroke=(0.7, solid((150, 104, 40)), 0.2))
    coin(a, 68, 56, 30, GOLD)
    crown(a, 68, 56, 12, GOLD_DARK)


def coin(a, x, y, d, metal, glyph=None, colour=(140, 96, 30), size=None):
    a.circle(x, y + 1.5, d, GOLD_DARK if metal is GOLD else metal)
    a.circle(x, y, d, metal, g=45)
    a.circle(x, y, d * 0.82, metal, g=225)
    a.circle(x, y, d * 0.72, None, stroke=(0.7, solid(colour), 0.2))
    if glyph:
        a.text(x, y, d * 0.7, d * 0.6, glyph, size or d * 0.36, colour, font="serif")
    a.shine(x - d * 0.18, y - d * 0.12, d * 0.12, d * 0.5, a=0.55)


@piece
def yearCoin(a):
    coin(a, 50, 50, 64, GOLD, "MMXXVI", size=9)
    indices(a, 50, 50, 28, 40, 0.8, 2.2, (150, 104, 40))


@piece
def luckyCoin(a):
    coin(a, 50, 50, 62, GOLD)
    for dx, dy in ((-5, -5), (5, -5), (-5, 5), (5, 5)):
        a.circle(50 + dx, 48 + dy, 11, GREEN, g=45)
    a.box(52, 62, 2, 10, GREEN, r=-20, cr=0.5)


@piece
def sovereignCoin(a):
    a.circle(50, 50, 86, solid((255, 220, 140)), a=0.86)
    coin(a, 50, 50, 66, GOLD)
    crown(a, 50, 50, 26, GOLD_DARK)
    indices(a, 50, 50, 28.5, 48, 0.8, 2.4, (150, 104, 40))


def crown(a, x, y, w, metal):
    a.box(x, y + w * 0.22, w, w * 0.22, metal, cr=0.15)
    for dx in (-0.36, 0, 0.36):
        a.tri_up(x + dx * w, y + w * 0.12, w * 0.36, metal)
        a.circle(x + dx * w, y - w * 0.1 - (0.06 * w if dx == 0 else 0), w * 0.12, RUBY if dx == 0 else PEARL)


@piece
def moneyClip(a):
    note(a, 50, 56, -4, GREEN_NOTE, (60, 90, 60))
    note(a, 50, 52, 2, GREEN_NOTE, (60, 90, 60))
    a.box(50, 52, 22, 40, STEEL, r=2, cr=0.14, g=0)
    a.box(50, 52, 16, 34, None, r=2, cr=0.14, stroke=(0.6, solid((120, 126, 138)), 0.2))
    a.text(50, 52, 14, 10, "MN", 6, (90, 96, 108), font="serif")
    a.shine(45, 44, 3, 18, a=0.4)


@piece
def carKey(a):
    a.ring(50, 16, 14, 2.8, STEEL)
    a.box(50, 26, 8, 6, STEEL, cr=0.3)
    a.box(50, 56, 36, 54, LACQUER, cr=0.3, g=0)
    a.box(50, 56, 32, 50, None, cr=0.3, stroke=(0.7, solid((90, 90, 100)), 0.3))
    a.box(50, 44, 22, 12, solid((22, 22, 28)), cr=0.2)
    for x in (44, 56):
        a.box(x, 44, 8, 8, stops((0, (150, 156, 168)), (1, (86, 90, 100))), cr=0.3)
    a.box(50, 64, 22, 8, GOLD, cr=0.25, g=0)
    a.circle(50, 76, 5, GOLD_SOFT)
    a.shine(40, 50, 3, 30, r=-8, a=0.7)


@piece
def keyCard(a):
    a.box(50, 52, 70, 44, BLACK, cr=0.1, g=45)
    a.box(50, 52, 64, 38, None, cr=0.08, stroke=(0.7, GOLD, 0.15))
    a.box(50, 40, 70, 7, solid((44, 44, 52)))
    a.box(33, 57, 12, 10, GOLD, cr=0.2)
    a.box(33, 57, 12, 0.6, GOLD_DARK)
    a.box(33, 57, 0.6, 10, GOLD_DARK)
    a.text(62, 58, 26, 10, "SUITE", 5, (220, 182, 100))
    a.shine(66, 48, 3, 24, a=0.7)


@piece
def valetKey(a):
    a.ring(50, 14, 12, 1.6, GOLD_SOFT)
    a.box(50, 22, 1.4, 10, solid((140, 30, 40)), cr=0.5)
    a.box(50, 56, 38, 54, LEATHER, cr=0.24, g=0)
    a.box(50, 56, 32, 48, None, cr=0.22, stroke=(0.6, solid((214, 184, 140)), 0.4))
    a.ring(50, 36, 7, 2.2, GOLD)
    a.box(50, 60, 22, 14, GOLD, cr=0.2)
    a.text(50, 60, 22, 14, "07", 9, (90, 60, 20), font="serif")


def key(a, metal, bow=None, gem=None, length=46):
    with a.group(-40):
        a.ring(30, 50, 26, 6.5, metal, g=45)
        if bow:
            a.circle(30, 50, 8, bow, g=45)
        if gem:
            a.circle(30, 50, 8, gem, g=45)
            a.circle(28.5, 48.5, 2.4, solid((255, 255, 255)), a=0.2)
        a.box(44, 50, 6, 10, metal, cr=0.3)
        a.box(44 + length / 2, 50, length, 6, metal, cr=0.3, g=90)
        a.box(80, 57, 5, 9, metal, cr=0.15)
        a.box(72, 56, 5, 7, metal, cr=0.15)
        a.box(53, 50, 3, 9, metal, cr=0.3)


@piece
def vaultKey(a):
    key(a, GOLD, bow=GOLD_DARK)


@piece
def lodgeKey(a):
    key(a, IRON, bow=IRON, length=42)


@piece
def gardenKey(a):
    key(a, BRONZE, bow=stops((0, (70, 140, 100)), (1, (30, 90, 60))))


@piece
def foundersKey(a):
    a.circle(50, 50, 86, solid((255, 220, 140)), a=0.86)
    key(a, GOLD, gem=RUBY, length=48)


@piece
def sunglasses(a):
    lens = stops((0, (40, 30, 26)), (0.45, (16, 12, 12)), (1, (60, 40, 30)))
    for x in (31, 69):
        a.box(x, 52, 32, 26, lens, cr=0.45, g=60, stroke=(1.6, GOLD, 0.0, 0))
        a.box(x - 6, 47, 5, 16, solid((255, 255, 255)), r=-30, cr=0.5, a=0.7)
    a.box(50, 45, 12, 2.4, GOLD, cr=0.5)
    a.box(9, 42, 10, 2.4, GOLD, r=-14, cr=0.5)
    a.box(91, 42, 10, 2.4, GOLD, r=14, cr=0.5)


@piece
def perfume(a):
    a.box(50, 26, 14, 12, GOLD, cr=0.2, g=0)
    a.box(50, 32, 18, 3, GOLD_DARK, cr=0.3)
    a.box(50, 60, 44, 48, stops((0, (255, 214, 180)), (0.5, (236, 150, 120)), (1, (170, 80, 70))), cr=0.2, g=45, a=0.08)
    a.box(50, 64, 36, 36, stops((0, (255, 190, 150)), (1, (200, 90, 80))), cr=0.16, g=45, a=0.15)
    a.box(50, 60, 20, 10, CREAM, cr=0.1)
    a.box(50, 60, 20, 10, None, cr=0.1, stroke=(0.5, GOLD, 0.2))
    a.text(50, 60, 20, 10, "NOIR", 4.6, (110, 70, 40), font="serif")
    a.shine(36, 54, 4, 28, r=-6, a=0.4)


@piece
def fountainPen(a):
    with a.group(-38):
        a.box(50, 50, 70, 10, LACQUER, cr=0.5, g=90)
        a.box(30, 50, 2.5, 10.4, GOLD, g=0)
        a.box(64, 50, 2.5, 10.4, GOLD, g=0)
        a.box(40, 45.2, 24, 2.2, GOLD, cr=0.5)
        a.box(84.5, 50, 6, 6, GOLD, r=45, cr=0.1)
        a.box(82, 50, 4, 7, GOLD, cr=0.2)
        a.circle(15.5, 50, 9.6, LACQUER)
        a.shine(50, 47.6, 60, 1.4, r=0, a=0.4)


@piece
def obsidianPen(a):
    a.circle(50, 50, 86, solid((255, 220, 140)), a=0.86)
    fountainPen(a)


@piece
def quillPen(a):
    with a.group(-36):
        a.box(50, 50, 72, 1.6, solid((120, 96, 70)), cr=0.5)
        a.ellipse(42, 47, 54, 14, stops((0, (255, 255, 255)), (1, (206, 200, 192))), g=90)
        for i in range(7):
            a.box(26 + i * 7, 46, 0.6, 9, solid((170, 164, 156)), r=30, a=0.3)
        a.box(84, 50, 8, 3, GOLD, r=0, cr=0.5)


@piece
def wallet(a):
    # Cards peeking out, then the billfold with its stitching and fold.
    a.box(40, 32, 22, 16, stops((0, (110, 170, 150)), (1, (70, 130, 110))), r=-6, cr=0.12)
    a.box(58, 31, 22, 16, NAVY, r=5, cr=0.12)
    a.box(50, 56, 72, 46, LEATHER, cr=0.1, g=60)
    a.box(50, 56, 66, 40, None, cr=0.08, stroke=(0.7, solid((222, 192, 150)), 0.35))
    a.box(50, 56, 72, 1.4, solid((0, 0, 0)), a=0.5)
    a.box(50, 64, 16, 2, GOLD_SOFT, cr=0.5)


@piece
def handbag(a):
    # The chain, then the quilted bag, then the clasp.
    for i in range(13):
        t = i / 12
        ang = math.pi * t
        x = 50 - 26 * math.cos(ang)
        y = 40 - 20 * math.sin(ang)
        a.ellipse(x, y, 5.2, 3.6, GOLD, r=math.degrees(ang) + 90)
    a.box(50, 60, 64, 40, BURGUNDY, cr=0.12, g=60)
    for k in range(-4, 5):
        a.box(50 + k * 10, 60, 0.8, 70, solid((30, 6, 14)), r=45, a=0.45, clip=[18, 40, 82, 80])
        a.box(50 + k * 10, 60, 0.8, 70, solid((30, 6, 14)), r=-45, a=0.45, clip=[18, 40, 82, 80])
    a.box(50, 47, 64, 14, stops((0, (130, 40, 64)), (1, (88, 22, 42))), cr=0.12)
    a.box(50, 52, 10, 7, GOLD, cr=0.2, g=0)
    a.box(50, 52, 5, 3, GOLD_DARK, cr=0.3)


@piece
def headphones(a):
    a.ring(50, 52, 64, 6, LACQUER, clip=[0, 0, 100, 54])
    a.ring(50, 52, 64, 1.6, GOLD, clip=[0, 0, 100, 54])
    for x in (21, 79):
        a.box(x, 64, 18, 28, LACQUER, cr=0.4, g=0)
        a.box(x, 64, 14, 24, None, cr=0.4, stroke=(1.2, GOLD, 0.0))
        a.box(x, 54, 6, 6, GOLD, cr=0.2)


@piece
def lighter(a):
    a.box(50, 60, 34, 46, STEEL, cr=0.1, g=0)
    a.box(50, 32, 34, 14, STEEL, cr=0.12, g=0)
    a.box(50, 39.5, 34, 1.2, solid((80, 86, 96)))
    a.circle(40, 25, 7, stops((0, (90, 94, 104)), (1, (180, 186, 196))))
    for k in range(6):
        a.circle(56 + k * 0, 25, 1.4, solid((40, 40, 46)))
    a.box(50, 62, 16, 16, GOLD, r=45, cr=0.1)
    a.shine(42, 60, 3, 30, r=-4, a=0.55)


@piece
def hallowsLantern(a):
    a.ring(50, 18, 18, 2, IRON, clip=[0, 0, 100, 19])
    a.box(50, 24, 30, 6, IRON, cr=0.3)
    a.box(50, 58, 34, 50, WARM_GLOW, cr=0.1, g=90)
    a.circle(50, 60, 22, solid((255, 250, 220)), a=0.25)
    for x in (34, 50, 66):
        a.box(x, 58, 2.4, 50, IRON)
    a.box(50, 85, 40, 6, IRON, cr=0.3)


@piece
def champagneCoupe(a):
    # The Crystal Hourglass: two bulbs of glass between brass ends, sand running down.
    a.box(50, 20, 46, 6, GOLD, cr=0.3, g=0)
    a.box(50, 82, 46, 6, GOLD, cr=0.3, g=0)
    for x in (30, 70):
        a.box(x, 51, 2.6, 58, GOLD_DARK, cr=0.5)
    a.ellipse(50, 36, 30, 30, GLASS, a=0.45)
    a.ellipse(50, 66, 30, 30, GLASS, a=0.45)
    a.ellipse(50, 70, 26, 22, GOLD_SOFT, clip=[30, 70, 70, 82])
    a.ellipse(50, 30, 26, 22, GOLD_SOFT, clip=[30, 30, 70, 46])
    a.box(50, 56, 1.4, 12, GOLD_SOFT)
    a.shine(42, 34, 3, 16, a=0.5)
    a.shine(42, 64, 3, 16, a=0.5)


@piece
def roseVial(a):
    a.box(50, 22, 12, 10, stops((0, (160, 120, 80)), (1, (110, 80, 50))), cr=0.2)
    a.box(50, 30, 16, 4, GOLD, cr=0.3)
    a.box(50, 58, 28, 50, GLASS, cr=0.45, a=0.35)
    a.box(50, 66, 24, 32, stops((0, (255, 130, 160)), (1, (176, 30, 70))), cr=0.45, clip=[30, 50, 70, 90])
    for dx, dy in ((-4, 70), (4, 66), (0, 76)):
        a.circle(50 + dx, dy, 6, RED_ENAMEL)
    a.shine(44, 54, 3, 30, r=-2, a=0.45)


@piece
def hipFlask(a):
    # The Brass Compass
    a.ring(50, 16, 12, 2.4, BRONZE)
    a.circle(50, 54, 68, BRONZE, g=45)
    a.circle(50, 54, 58, CREAM, g=45)
    indices(a, 50, 54, 24, 16, 0.8, 3, (110, 90, 60), big=4)
    for t, (x, y) in (("N", (50, 36)), ("S", (50, 72)), ("E", (68, 54)), ("W", (32, 54))):
        a.text(x, y, 8, 8, t, 6, (90, 70, 40), font="serif")
    a.box(50, 47, 5, 16, RED_ENAMEL, cr=0.5)
    a.box(50, 61, 5, 16, STEEL, cr=0.5)
    a.circle(50, 54, 5, GOLD)


@piece
def wrappedBox(a):
    a.box(50, 62, 54, 40, stops((0, (34, 70, 56)), (1, (16, 42, 32))), cr=0.06, g=60)
    a.box(50, 41, 60, 12, stops((0, (44, 90, 72)), (1, (24, 56, 42))), cr=0.1)
    a.box(50, 56, 8, 52, GOLD, g=0)
    a.box(50, 62, 54, 7, GOLD, clip=[23, 42, 77, 82])
    a.ellipse(41, 30, 16, 11, GOLD, r=-25)
    a.ellipse(59, 30, 16, 11, GOLD, r=25)
    a.circle(50, 33, 7, GOLD_DARK)


@piece
def linenFan(a):
    a.circle(50, 70, 84, CREAM, clip=[6, 26, 94, 70])
    for i in range(11):
        deg = -90 + i * 18
        rad = math.radians(deg)
        a.box(50 + 21 * math.sin(rad), 70 - 21 * math.cos(rad), 0.9, 42, solid((160, 140, 110)), r=deg, a=0.3, clip=[6, 26, 94, 70])
    a.circle(50, 70, 50, None, stroke=(0.8, solid((200, 170, 130)), 0.3), clip=[6, 26, 94, 70])
    a.circle(50, 70, 8, GOLD)
    a.box(50, 78, 3, 14, GOLD_DARK, cr=0.5)


@piece
def looseDiamond(a):
    a.box(50, 37, 34, 14, DIAMOND, cr=0.04, g=20)
    a.tri_up(28, 44, 14, DIAMOND, g=0)
    a.tri_up(72, 44, 14, DIAMOND, g=180)
    a.box(50, 44.5, 62, 1.6, solid((255, 255, 255)))
    a.tri_down(50, 45, 62, DIAMOND, g=0)
    for dx, r in ((-14, -24), (14, 24), (-6, -10), (6, 10)):
        a.box(50 + dx * 0.6, 58, 0.9, 26, solid((150, 186, 226)), r=r, a=0.3)
    a.box(50, 37, 14, 10, solid((255, 255, 255)), a=0.55)
    a.sparkle(72, 26, 12)
    a.sparkle(30, 70, 7)


def gem(a, fill, shape="emerald", w=54, h=42):
    cr = 0.12 if shape == "emerald" else 0.5 if shape == "oval" else 0.3
    a.box(50, 52, w, h, fill, cr=cr, g=45)
    a.box(50, 52, w * 0.78, h * 0.74, fill, cr=cr, g=225)
    a.box(50, 52, w * 0.56, h * 0.48, fill, cr=cr, g=45)
    a.box(50, 52, w * 0.56, h * 0.48, solid((255, 255, 255)), cr=cr, a=0.75)
    a.shine(50 - w * 0.22, 52 - h * 0.18, 4, h * 0.5, a=0.4)
    a.sparkle(50 + w * 0.38, 52 - h * 0.5, 10)


@piece
def emeraldGem(a):
    gem(a, EMERALD, "emerald")


@piece
def rubyGem(a):
    gem(a, RUBY, "cushion", 48, 46)


@piece
def sapphireGem(a):
    gem(a, SAPPHIRE, "oval", 50, 40)


@piece
def blackDiamond(a):
    a.circle(50, 50, 86, solid((210, 190, 255)), a=0.86)
    a.box(50, 37, 34, 14, ONYX, cr=0.04, g=20, stroke=(0.8, solid((190, 170, 240)), 0.3))
    a.tri_up(28, 44, 14, ONYX, g=0)
    a.tri_up(72, 44, 14, ONYX, g=180)
    a.box(50, 44.5, 62, 1.6, solid((170, 150, 220)))
    a.tri_down(50, 45, 62, ONYX, g=0)
    a.box(50, 37, 14, 10, solid((200, 180, 255)), a=0.7)
    a.sparkle(72, 26, 12, (230, 220, 255))


@piece
def vipCard(a):
    a.box(50, 52, 72, 46, BLACK, cr=0.1, g=45, stroke=(1.6, GOLD, 0.0, 0))
    a.box(50, 52, 64, 38, None, cr=0.08, stroke=(0.5, GOLD, 0.4))
    a.circle(32, 52, 18, GOLD, g=45)
    a.circle(32, 52, 14, GOLD_DARK, g=225)
    a.text(32, 52, 12, 12, "V", 10, (255, 230, 160), font="serif")
    for k in range(3):
        a.box(60, 44 + k * 7, 20 if k else 24, 1.6, GOLD_SOFT, cr=0.5, a=0.1 * k)
    a.sparkle(26, 36, 7)


@piece
def chessKing(a):
    a.box(50, 84, 40, 7, GOLD, cr=0.3, g=0)
    a.box(50, 78, 32, 6, GOLD_DARK, cr=0.3)
    a.box(50, 60, 20, 34, GOLD, cr=0.2, g=0)
    a.box(50, 44, 30, 6, GOLD, cr=0.4, g=0)
    a.ellipse(50, 36, 24, 16, GOLD, g=0)
    a.box(50, 20, 4, 14, GOLD, cr=0.3)
    a.box(50, 18, 12, 4, GOLD, cr=0.3)
    a.shine(45, 60, 3, 30, r=0, a=0.5)


@piece
def casinoPlaque(a):
    # The Commemorative Medal: a ribbon, a gold medal, a star in relief.
    a.box(40, 24, 14, 34, RED_ENAMEL, r=-18, cr=0.05)
    a.box(60, 24, 14, 34, BLUE_ENAMEL, r=18, cr=0.05)
    a.box(50, 38, 30, 6, GOLD, cr=0.3)
    coin(a, 50, 62, 42, GOLD)
    for k in range(5):
        deg = k * 72
        rad = math.radians(deg)
        a.box(50 + 5 * math.sin(rad), 62 - 5 * math.cos(rad), 5, 13, GOLD_DARK, r=deg, cr=0.3)


@piece
def objetEgg(a):
    a.box(50, 86, 28, 5, GOLD, cr=0.4)
    a.box(50, 80, 12, 8, GOLD_DARK, cr=0.2)
    a.ellipse(50, 48, 50, 64, BLUE_ENAMEL, g=45)
    a.box(50, 48, 50, 4, GOLD, cr=0.5)
    a.ellipse(50, 48, 30, 62, None, stroke=(1.2, GOLD, 0.2))
    for dy in (-20, 20):
        a.box(50, 48 + dy, 40, 2, GOLD_SOFT, cr=0.5, a=0.2)
    for x in (34, 42, 50, 58, 66):
        a.circle(x, 48, 3.4, PEARL)
    a.circle(50, 17, 6, RUBY)
    a.shine(40, 36, 5, 24, a=0.5)


@piece
def crystalSkull(a):
    clear = stops((0, (226, 240, 255)), (1, (140, 170, 210)))
    a.ellipse(50, 42, 54, 50, clear, a=0.2)
    a.box(50, 64, 34, 22, clear, cr=0.3, a=0.2)
    for x in (39, 61):
        a.ellipse(x, 46, 14, 12, solid((30, 40, 70)), a=0.3)
    a.box(50, 56, 6, 6, solid((30, 40, 70)), r=45, a=0.4)
    for k in range(5):
        a.box(42 + k * 4, 70, 2.4, 7, solid((255, 255, 255)), cr=0.3, a=0.2)
    a.shine(38, 30, 6, 20, a=0.3)


@piece
def ravenBrooch(a):
    a.ellipse(50, 50, 56, 66, GOLD, g=45)
    a.ellipse(50, 50, 48, 58, ONYX, g=45)
    # A small raven in profile: body, head, beak, tail, a silver eye.
    a.ellipse(48, 54, 22, 14, solid((6, 6, 8)), r=-20)
    a.circle(58, 45, 10, solid((6, 6, 8)))
    a.box(64, 46, 6, 2.4, solid((60, 60, 70)), r=10)
    a.box(37, 60, 12, 5, solid((6, 6, 8)), r=-35, cr=0.3)
    a.circle(60, 44, 1.6, solid((230, 230, 240)))
    for k in range(10):
        ang = 2 * math.pi * k / 10
        a.circle(50 + 26 * math.sin(ang), 50 - 31 * math.cos(ang), 3, PEARL)


@piece
def heartLocket(a):
    a.ring(50, 16, 10, 2, GOLD)
    a.box(50, 54, 30, 30, GOLD, r=45, cr=0.08, g=0)
    a.circle(39.5, 43, 30, GOLD, g=45)
    a.circle(60.5, 43, 30, GOLD, g=45)
    a.box(50, 52, 20, 20, RED_ENAMEL, r=45, cr=0.08, g=0)
    a.circle(43, 45, 20, RED_ENAMEL, g=45)
    a.circle(57, 45, 20, RED_ENAMEL, g=45)
    a.shine(40, 40, 4, 12, a=0.5)


@piece
def cloverPin(a):
    a.box(56, 70, 3, 22, GREEN, r=-25, cr=0.5)
    for dx, dy in ((-9, -9), (9, -9), (-9, 9), (9, 9)):
        a.circle(50 + dx, 46 + dy, 20, EMERALD, g=45)
    a.circle(50, 46, 7, GOLD)
    a.sparkle(70, 28, 8)


@piece
def amberRing(a):
    band(a, 50, 64, 44, 6, GOLD)
    a.ellipse(50, 36, 26, 20, GOLD, g=45)
    a.ellipse(50, 35, 21, 15, AMBER, g=45)
    a.circle(46, 32, 4, solid((255, 240, 200)), a=0.3)
    a.sparkle(66, 24, 8)


@piece
def blossomPin(a):
    for k in range(5):
        ang = 2 * math.pi * k / 5
        a.circle(50 + 13 * math.sin(ang), 48 - 13 * math.cos(ang), 22, PINK, g=45)
    a.circle(50, 48, 12, GOLD)
    for k in range(5):
        ang = 2 * math.pi * k / 5 + 0.6
        a.circle(50 + 4 * math.sin(ang), 48 - 4 * math.cos(ang), 2.2, GOLD_SOFT)


@piece
def sunPendant(a):
    for i in range(9):
        t = i / 8
        ang = math.pi * (0.15 + 0.7 * t)
        a.circle(50 - 30 * math.cos(ang), 10 + 14 * math.sin(ang), 2.6, GOLD_SOFT)
    a.ring(50, 30, 8, 2, GOLD)
    for k in range(12):
        deg = k * 30
        rad = math.radians(deg)
        a.box(50 + 19 * math.sin(rad), 60 - 19 * math.cos(rad), 3, 11, GOLD, r=deg, cr=0.5)
    a.circle(50, 60, 28, GOLD, g=45)
    a.circle(50, 60, 20, GOLD_SOFT, g=225)
    a.shine(44, 54, 4, 14, a=0.5)


@piece
def glassOrnament(a):
    a.ring(50, 14, 10, 1.6, GOLD)
    a.box(50, 24, 14, 8, GOLD, cr=0.2, g=0)
    a.circle(50, 58, 58, stops((0, (220, 50, 70)), (0.5, (160, 14, 36)), (1, (70, 4, 16))), g=45)
    a.box(50, 58, 58, 3, GOLD_SOFT, cr=0.5)
    a.ellipse(40, 46, 12, 18, solid((255, 255, 255)), r=-30, a=0.55)


@piece
def iceCrystal(a):
    c = ICE
    for deg in (0, 60, 120):
        a.box(50, 50, 4, 70, c, r=deg, cr=0.5)
        for s in (-1, 1):
            rad = math.radians(deg)
            for dist in (18, 28):
                x = 50 + s * dist * math.sin(rad)
                y = 50 - s * dist * math.cos(rad)
                a.box(x, y, 2.4, 12, c, r=deg + 45, cr=0.5)
                a.box(x, y, 2.4, 12, c, r=deg - 45, cr=0.5)
    a.circle(50, 50, 12, solid((255, 255, 255)), a=0.2)


@piece
def blueMoonPearl(a):
    a.circle(50, 50, 88, solid((180, 200, 255)), a=0.8)
    a.circle(50, 56, 60, solid((0, 0, 0)), a=0.7)
    a.circle(50, 52, 60, BLUE_PEARL, g=45)
    a.circle(40, 40, 18, solid((255, 255, 255)), a=0.45)
    a.circle(38, 38, 7, solid((255, 255, 255)), a=0.1)
    a.sparkle(74, 26, 12)


# ---------------------------------------------------------------------------------------------
# The six case marks: thin gold line drawings, like an engraving.
# ---------------------------------------------------------------------------------------------

CASES = {}
LINE = solid((214, 172, 96))


def case_mark(name):
    def wrap(fn):
        a = Art()
        fn(a)
        CASES[name] = a.prims
        return fn

    return wrap


@case_mark("watches")
def _watches(a):
    a.box(50, 22, 22, 18, None, cr=0.2, stroke=(3, LINE))
    a.box(50, 78, 22, 18, None, cr=0.2, stroke=(3, LINE))
    a.circle(50, 50, 40, solid((0, 0, 0)), a=1, stroke=(3.2, LINE))
    a.box(50, 44, 3, 12, LINE, cr=0.5)
    a.box(55, 52, 3, 10, LINE, r=120, cr=0.5)


@case_mark("jewelry")
def _jewelry(a):
    a.ring(50, 64, 40, 3.2, LINE)
    a.box(50, 30, 16, 16, None, r=45, cr=0.1, stroke=(3, LINE))


@case_mark("money")
def _money(a):
    a.box(50, 50, 70, 40, None, cr=0.1, stroke=(3, LINE))
    a.circle(50, 50, 16, None, stroke=(3, LINE))
    a.circle(28, 50, 4, LINE)
    a.circle(72, 50, 4, LINE)


@case_mark("keys")
def _keys(a):
    with a.group(-40):
        a.ring(30, 50, 24, 3.2, LINE)
        a.box(60, 50, 44, 3.2, LINE, cr=0.5)
        a.box(78, 56, 3.2, 10, LINE, cr=0.5)
        a.box(70, 56, 3.2, 8, LINE, cr=0.5)


@case_mark("accessories")
def _accessories(a):
    a.circle(28, 52, 30, None, stroke=(3, LINE))
    a.circle(72, 52, 30, None, stroke=(3, LINE))
    a.box(50, 47, 14, 3, LINE, cr=0.5)


@case_mark("collectibles")
def _collectibles(a):
    a.circle(50, 36, 38, None, stroke=(3, LINE))
    a.box(40, 72, 9, 30, None, r=-14, cr=0.1, stroke=(3, LINE))
    a.box(60, 72, 9, 30, None, r=14, cr=0.1, stroke=(3, LINE))
    a.circle(50, 36, 12, LINE)


# ---------------------------------------------------------------------------------------------
# Writing the Luau module
# ---------------------------------------------------------------------------------------------


def num(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return s if s not in ("-0", "") else "0"


def lua_stops(st):
    return "{ " + ", ".join(f"{{ {num(t)}, {int(c[0])}, {int(c[1])}, {int(c[2])} }}" for t, c in st) + " }"


def lua_prim(p, indent):
    pad = "\t" * indent
    if p["t"] == "group":
        kids = ",\n".join(lua_prim(k, indent + 1) for k in p["kids"])
        return f'{pad}{{ t = "group", r = {num(p["r"])}, kids = {{\n{kids},\n{pad}}} }}'
    parts = [f't = "{p["t"]}"']
    for k in ("x", "y", "w", "h"):
        parts.append(f"{k} = {num(p[k])}")
    if p["t"] == "text":
        parts.append(f'text = "{p["text"]}"')
        parts.append(f"size = {num(p['size'])}")
        parts.append(f'font = "{p["font"]}"')
        parts.append(f"fill = {lua_stops(p['fill'])}")
        return pad + "{ " + ", ".join(parts) + " }"
    for k in ("r", "cr", "a", "g"):
        if p.get(k):
            parts.append(f"{k} = {num(p[k])}")
    if "fill" in p:
        parts.append(f"fill = {lua_stops(p['fill'])}")
    if "ga" in p:
        parts.append("ga = { " + ", ".join(f"{{ {num(t)}, {num(v)} }}" for t, v in p["ga"]) + " }")
    if "s" in p:
        s = p["s"]
        parts.append(f"s = {{ th = {num(s['th'])}, a = {num(s['a'])}, g = {num(s['g'])}, fill = {lua_stops(s['fill'])} }}")
    if "clip" in p:
        parts.append("clip = { " + ", ".join(num(v) for v in p["clip"]) + " }")
    return pad + "{ " + ", ".join(parts) + " }"


def write_luau():
    lines = [
        "--!nocheck",
        "-- (Generated data: shapes of many kinds in one list, so it isn't type-checked.)",
        "-- The illustrations of every piece and the six case marks, as shapes Roblox's UI draws:",
        "-- written by tools/art/pieces.py (which also renders them to tools/art/preview to be looked",
        "-- at). Regenerate it with that tool; never edit it by hand. Drawn by src/client/UI/PieceIcon.",
        "",
        "local PieceArt = {}",
        "",
        "PieceArt.pieces = {",
    ]
    for name, prims in ART.items():
        body = ",\n".join(lua_prim(p, 2) for p in prims)
        lines.append(f"\t{name} = {{\n{body},\n\t}},")
    lines.append("}")
    lines.append("")
    lines.append("PieceArt.cases = {")
    for name, prims in CASES.items():
        body = ",\n".join(lua_prim(p, 2) for p in prims)
        lines.append(f"\t{name} = {{\n{body},\n\t}},")
    lines.append("}")
    lines += ["", "return PieceArt", ""]
    with open(os.path.join(ROOT, "src", "shared", "PieceArt.luau"), "w") as f:
        f.write("\n".join(lines))


# ---------------------------------------------------------------------------------------------
# The previewer: draws the shapes as Roblox would
# ---------------------------------------------------------------------------------------------

FONTS = {
    "bold": "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "serif": "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf",
}


def gradient(w, h, st, rot, ga=None, base_a=0.0):
    w, h = max(1, int(round(w))), max(1, int(round(h)))
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    U, V = np.meshgrid(u, v)
    rad = math.radians(rot)
    t = np.clip(0.5 + (U - 0.5) * math.cos(rad) + (V - 0.5) * math.sin(rad), 0, 1)
    ts = np.array([s[0] for s in st])
    rgb = np.zeros((h, w, 3))
    for ch in range(3):
        rgb[..., ch] = np.interp(t, ts, [s[1][ch] for s in st])
    alpha = np.full((h, w), 1.0 - base_a)
    if ga:
        gts = np.array([x[0] for x in ga])
        gvs = np.array([x[1] for x in ga])
        alpha = alpha * (1 - np.interp(t, gts, gvs))
    img = np.dstack([rgb, alpha * 255]).astype(np.uint8)
    return Image.fromarray(img, "RGBA")


def rounded_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=max(0, radius), fill=255)
    return m


def draw_box(p, S):
    k = S / 100.0
    W, H = p["w"] * k, p["h"] * k
    T = p["s"]["th"] * k if "s" in p else 0
    pad = int(T + 4)
    cw, ch = int(W + 2 * pad), int(H + 2 * pad)
    layer = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    radius = p.get("cr", 0) * min(W, H)
    inner = (pad, pad, pad + W - 1, pad + H - 1)
    if "s" in p:
        s = p["s"]
        outer = (pad - T, pad - T, pad + W - 1 + T, pad + H - 1 + T)
        om = rounded_mask((cw, ch), outer, radius + T)
        im = rounded_mask((cw, ch), inner, radius)
        ring = Image.fromarray(np.clip(np.array(om, dtype=np.int16) - np.array(im, dtype=np.int16), 0, 255).astype(np.uint8), "L")
        g = gradient(W + 2 * T, H + 2 * T, s["fill"], s["g"], base_a=s["a"])
        gl = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        gl.paste(g, (int(pad - T), int(pad - T)))
        a = np.array(gl)[..., 3].astype(np.float32) * (np.array(ring).astype(np.float32) / 255)
        arr = np.array(gl)
        arr[..., 3] = a.astype(np.uint8)
        layer = Image.alpha_composite(layer, Image.fromarray(arr, "RGBA"))
    if "fill" in p:
        g = gradient(W, H, p["fill"], p.get("g", 90), ga=p.get("ga"), base_a=p.get("a", 0))
        gl = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        gl.paste(g, (pad, pad))
        m = rounded_mask((cw, ch), inner, radius)
        arr = np.array(gl)
        arr[..., 3] = (arr[..., 3].astype(np.float32) * (np.array(m).astype(np.float32) / 255)).astype(np.uint8)
        layer = Image.alpha_composite(layer, Image.fromarray(arr, "RGBA"))
    if p.get("r"):
        layer = layer.rotate(-p["r"], resample=Image.BICUBIC, expand=True)
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(layer, (int(round(p["x"] * k - layer.width / 2)), int(round(p["y"] * k - layer.height / 2))), layer)
    return out


def draw_text(p, S):
    k = S / 100.0
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    font = ImageFont.truetype(FONTS.get(p["font"], FONTS["bold"]), max(4, int(p["size"] * k)))
    d = ImageDraw.Draw(out)
    c = p["fill"][0][1]
    d.text((p["x"] * k, p["y"] * k), p["text"], font=font, fill=tuple(c) + (255,), anchor="mm")
    return out


def render_prims(prims, S, rotated=False):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = S / 100.0
    for p in prims:
        if p["t"] == "group":
            layer = render_prims(p["kids"], S, rotated=rotated or p["r"] != 0)
            if p["r"]:
                layer = layer.rotate(-p["r"], resample=Image.BICUBIC)
        elif p["t"] == "text":
            layer = draw_text(p, S)
        else:
            layer = draw_box(p, S)
            if "clip" in p and not rotated:
                x0, y0, x1, y1 = p["clip"]
                m = Image.new("L", (S, S), 0)
                ImageDraw.Draw(m).rectangle((x0 * k, y0 * k, x1 * k, y1 * k), fill=255)
                arr = np.array(layer)
                arr[..., 3] = (arr[..., 3].astype(np.float32) * (np.array(m).astype(np.float32) / 255)).astype(np.uint8)
                layer = Image.fromarray(arr, "RGBA")
        img = Image.alpha_composite(img, layer)
    return img


def icon_image(prims, px, ss=3):
    return render_prims(prims, px * ss).resize((px, px), Image.LANCZOS)


def tray_background(w, h):
    top, bottom = np.array([28, 20, 12]), np.array([10, 10, 13])
    v = np.linspace(0, 1, h)[:, None, None]
    arr = (top * (1 - v) + bottom * v).repeat(w, axis=1)
    return Image.fromarray(arr.astype(np.uint8), "RGB").convert("RGBA")


def preview():
    os.makedirs(PREVIEW, exist_ok=True)
    names = {}
    try:
        import re

        src = open(os.path.join(ROOT, "src", "shared", "Catalogue.luau")).read()
        for m in re.finditer(r'\(\s*"(\w+)",\s*"([^"]+)"', src):
            names[m.group(1)] = m.group(2)
        for m in re.finditer(r'id = "(\w+)", name = "([^"]+)"', src):
            names[m.group(1)] = m.group(2)
    except OSError:
        pass
    cell, cols = 150, 8
    ids = list(ART.keys())
    rows = math.ceil(len(ids) / cols)
    sheet = tray_background(cols * cell, rows * (cell + 30))
    label = ImageFont.truetype(FONTS["bold"], 13)
    d = ImageDraw.Draw(sheet)
    for i, pid in enumerate(ids):
        x, y = (i % cols) * cell, (i // cols) * (cell + 30)
        shadow = Image.new("RGBA", (cell, cell), (0, 0, 0, 0))
        ImageDraw.Draw(shadow).ellipse((cell * 0.25, cell * 0.8, cell * 0.75, cell * 0.9), fill=(0, 0, 0, 150))
        shadow = shadow.filter(ImageFilter.GaussianBlur(5))
        sheet.alpha_composite(shadow, (x, y))
        sheet.alpha_composite(icon_image(ART[pid], cell - 30), (x + 15, y + 8))
        d.text((x + cell / 2, y + cell + 8), names.get(pid, pid), font=label, fill=(236, 226, 206), anchor="mm")
    sheet.save(os.path.join(PREVIEW, "pieces.png"))
    marks = tray_background(6 * 120, 140)
    for i, (name, prims) in enumerate(CASES.items()):
        marks.alpha_composite(icon_image(prims, 80), (i * 120 + 20, 10))
        ImageDraw.Draw(marks).text((i * 120 + 60, 115), name.upper(), font=label, fill=(236, 226, 206), anchor="mm")
    marks.save(os.path.join(PREVIEW, "cases.png"))


if __name__ == "__main__":
    draw_all()
    write_luau()
    preview()
    print(f"{len(ART)} pieces, {len(CASES)} case marks, {sum(len(v) for v in ART.values())} top-level shapes")

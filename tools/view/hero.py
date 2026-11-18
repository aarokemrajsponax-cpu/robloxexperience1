#!/usr/bin/env python3
"""The house's poster guest, for the thumbnails: a blocky Roblox-proportioned avatar in street-meets-
formal luxury (a cream double-breasted blazer over a black knit, gold chains, black tailored trousers,
white-and-gold trainers, dark shades, a gold watch), posed, added as parts to an exported world
(tools/view/export.luau's format) so the 3D viewer renders him with the house round him.

    python3 tools/view/hero.py <world.json> <out.json> <poses.json>

<poses.json> is a list of { "at": [x, y, z] (feet), "yaw": degrees (0 faces -Z), "pose": name,
"scale": 1 }. Poses: "crossed" (arms folded), "point" (right arm out, pointing), "flex" (cash fan
raised), "run" (mid-stride, a gold bar under the arm), "aim" (stun pistol raised), "dance", "wave".
Everything is made here from parts: no external asset, logo or brand.
"""

from __future__ import annotations

import json
import math
import sys

# --- small rigid-transform kit: (pos, 3x3 rows) -------------------------------------------------


def rot_x(a):
    c, s = math.cos(a), math.sin(a)
    return [[1, 0, 0], [0, c, -s], [0, s, c]]


def rot_y(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, 0, s], [0, 1, 0], [-s, 0, c]]


def rot_z(a):
    c, s = math.cos(a), math.sin(a)
    return [[c, -s, 0], [s, c, 0], [0, 0, 1]]


def mm(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mv(a, v):
    return [sum(a[i][k] * v[k] for k in range(3)) for i in range(3)]


I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]


class CF:
    def __init__(self, p=(0, 0, 0), r=None):
        self.p = list(p)
        self.r = r or I3

    def __mul__(self, o):
        return CF([a + b for a, b in zip(self.p, mv(self.r, o.p))], mm(self.r, o.r))

    def comps(self):
        r = self.r
        return [self.p[0], self.p[1], self.p[2], r[0][0], r[0][1], r[0][2], r[1][0], r[1][1], r[1][2], r[2][0], r[2][1], r[2][2]]


def T(x, y, z):
    return CF((x, y, z))


def R(rx=0.0, ry=0.0, rz=0.0):
    return CF((0, 0, 0), mm(mm(rot_y(math.radians(ry)), rot_x(math.radians(rx))), rot_z(math.radians(rz))))


# --- the outfit ----------------------------------------------------------------------------------
SKIN = [141, 98, 70]
HAIR = [24, 20, 18]
CREAM = [232, 222, 200]
CREAM_DARK = [206, 194, 168]
KNIT = [22, 22, 26]
TROUSER = [28, 28, 32]
GOLD = [236, 186, 76]
WHITE = [244, 242, 236]
SHADE = [14, 14, 18]
CASH = [118, 168, 104]


LOOKS = {
    # The poster guest: cream blazer, black knit, gold.
    "guest": {},
    # The Executive: a navy three-piece, a white shirt and a red tie, silver hair.
    "boss": {"CREAM": [30, 36, 58], "CREAM_DARK": [22, 26, 44], "KNIT": [236, 236, 240], "TROUSER": [30, 36, 58], "HAIR": [190, 190, 196], "WHITE": [20, 18, 18], "SKIN": [222, 184, 150]},
}


def build(at, yaw, pose, scale=1.0, look="guest"):
    global SKIN, HAIR, CREAM, CREAM_DARK, KNIT, TROUSER, WHITE
    base = {"SKIN": [141, 98, 70], "HAIR": [24, 20, 18], "CREAM": [232, 222, 200], "CREAM_DARK": [206, 194, 168], "KNIT": [22, 22, 26], "TROUSER": [28, 28, 32], "WHITE": [244, 242, 236]}
    base.update(LOOKS.get(look, {}))
    SKIN, HAIR, CREAM, CREAM_DARK, KNIT, TROUSER, WHITE = (base[k] for k in ("SKIN", "HAIR", "CREAM", "CREAM_DARK", "KNIT", "TROUSER", "WHITE"))
    parts = []
    root = T(*at) * R(ry=yaw) * CF((0, 0, 0), [[scale, 0, 0], [0, scale, 0], [0, 0, scale]])

    def add(name, size, cf, colour, material="SmoothPlastic", shape="Block", refl=0.0, transp=0.0):
        full = root * cf
        # (Scale lives in root's rotation: pull it back out so the viewer gets a true rotation.)
        r = [[v / scale for v in row] for row in full.r]
        parts.append([name, shape, [s * scale for s in size], CF(full.p, r).comps(), colour, material, transp, refl, True, ""])

    # Proportions (studs, feet at y 0): legs 2.2, torso 2.2, head 1.25.
    hip_y = 2.2
    torso_c = hip_y + 1.1
    sh_y = hip_y + 2.0  # shoulder pivot height
    head_c = hip_y + 2.2 + 0.7

    # Facing: the body faces -Z (toward the camera when yaw 0).
    lean = {"run": 12, "leap": 6, "flex": -4, "dance": 0}.get(pose, 0)
    body = R(rx=-lean)

    # Legs (pivot at the hip).
    def leg(side, swing):
        x = side * 0.5
        pivot = T(x, hip_y, 0) * R(rx=-swing)
        add("Leg", [0.95, 2.0, 1.0], pivot * T(0, -1.0, 0), TROUSER, "Fabric")
        add("TrouserCrease", [0.06, 1.9, 0.02], pivot * T(0, -1.0, -0.51), [44, 44, 50], "Fabric")
        add("Trainer", [1.0, 0.45, 1.35], pivot * T(0, -2.0, -0.12), WHITE, "SmoothPlastic")
        add("TrainerSole", [1.04, 0.14, 1.4], pivot * T(0, -2.17, -0.12), GOLD, "Metal", refl=0.15)
        add("TrainerTick", [0.04, 0.16, 0.7], pivot * T(side * 0.52, -1.95, -0.05), GOLD, "Metal")

    swings = {
        "run": (34, -30),
        "leap": (40, -20),
        "dance": (14, -10),
    }.get(pose, (0, 0))
    leg(-1, swings[0])
    leg(1, swings[1])

    torso = T(0, hip_y, 0) * body
    # Torso: the knit underneath, the blazer over it (open at the front), lapels, buttons, pocket square.
    add("Knit", [1.9, 2.2, 0.95], torso * T(0, 1.1, 0), KNIT, "Fabric")
    for side in (-1, 1):
        add("BlazerFront", [0.62, 2.25, 0.08], torso * T(side * 0.66, 1.1, -0.52), CREAM, "Fabric")
        add("Lapel", [0.34, 1.0, 0.06], torso * T(side * 0.42, 1.7, -0.57) * R(rz=side * -18), CREAM_DARK, "Fabric")
        add("BlazerSide", [0.08, 2.25, 1.0], torso * T(side * 0.99, 1.1, 0), CREAM, "Fabric")
    add("BlazerBack", [2.0, 2.25, 0.08], torso * T(0, 1.1, 0.52), CREAM, "Fabric")
    add("BlazerHem", [2.02, 0.12, 1.06], torso * T(0, 0.04, 0), CREAM_DARK, "Fabric")
    for bx in (-0.62, -0.42):
        for by in (0.6, 1.0):
            add("Button", [0.12, 0.12, 0.05], torso * T(bx, by, -0.58), GOLD, "Metal", "Ball", 0.2)
    add("PocketSquare", [0.3, 0.14, 0.05], torso * T(0.62, 1.62, -0.58), GOLD, "Fabric")
    add("Belt", [1.92, 0.18, 0.98], torso * T(0, 0.12, 0), [16, 16, 18], "Leather")
    add("Buckle", [0.34, 0.2, 0.05], torso * T(0, 0.12, -0.5), GOLD, "Metal", refl=0.25)
    # Chains: two, the long one with a pendant.
    for i, (depth, w) in enumerate(((0.55, 0.9), (1.05, 1.1))):
        y = 2.05 - depth
        add("Chain", [w, 0.08, 0.06], torso * T(0, y, -0.5), GOLD, "Metal", refl=0.3)
        for side in (-1, 1):
            add("ChainSide", [0.08, depth * 0.95, 0.06], torso * T(side * w / 2, y + depth * 0.45, -0.49) * R(rz=side * 12), GOLD, "Metal", refl=0.3)
    add("Pendant", [0.32, 0.32, 0.08], torso * T(0, 0.86, -0.53) * R(rz=45), GOLD, "Metal", refl=0.35)

    # Head (rounded), hair, shades, a gold stud.
    head = torso * T(0, 2.2 + 0.68, 0) * R(ry={"point": -10, "aim": 8}.get(pose, 0))
    add("Neck", [0.6, 0.3, 0.6], torso * T(0, 2.3, 0), SKIN)
    add("Head", [1.25, 1.25, 1.25], head, SKIN, "SmoothPlastic", "Ball")
    add("HeadBlock", [1.15, 1.05, 1.05], head, SKIN)
    add("Hair", [1.22, 0.32, 1.12], head * T(0, 0.58, 0.04), HAIR, "Fabric")
    add("HairBack", [1.2, 0.7, 0.2], head * T(0, 0.3, 0.52), HAIR, "Fabric")
    add("ShadeBar", [1.2, 0.1, 0.06], head * T(0, 0.17, -0.56), GOLD, "Metal", refl=0.3)
    for side in (-1, 1):
        add("ShadeLens", [0.46, 0.3, 0.06], head * T(side * 0.27, 0.08, -0.58), SHADE, "Glass", refl=0.4)
        add("ShadeArm", [0.05, 0.06, 0.6], head * T(side * 0.58, 0.16, -0.28), GOLD, "Metal")
    add("Smile", [0.36, 0.06, 0.04], head * T(0.06, -0.3, -0.56) * R(rz=-8), [70, 40, 34])
    add("EarStud", [0.1, 0.1, 0.1], head * T(0.6, 0, 0), GOLD, "Metal", "Ball", 0.4)

    # Arms (pivot at the shoulder). angles: (rx forward/back, rz out, ry twist).
    arms = {
        "crossed": ((80, 0, 62), (72, 0, -62)),
        "point": ((88, 0, -8), (12, 0, 0)),
        "flex": ((160, 0, 10), (14, 0, 0)),
        "run": ((-40, 0, 0), (60, 0, 18)),
        "aim": ((90, 0, 0), (82, 0, 28)),
        "dance": ((140, 0, -20), (40, 0, 30)),
        "wave": ((165, 0, -15), (0, 0, 0)),
        "leap": ((160, 0, -12), (160, 0, 12)),
    }.get(pose, ((0, 0, 0), (0, 0, 0)))

    def arm(side, angles):
        rx, rz, ry = angles
        # (Positive rx raises the arm forward, toward -Z, the way he faces.)
        pivot = torso * T(side * 1.45, 2.0, 0) * R(rx=rx, rz=side * rz + (side * 4 if rx == 0 else 0), ry=ry)
        add("Sleeve", [0.95, 2.0, 0.98], pivot * T(0, -1.0, 0), CREAM, "Fabric")
        add("Cuff", [0.98, 0.12, 1.0], pivot * T(0, -1.94, 0), CREAM_DARK, "Fabric")
        add("Hand", [0.8, 0.5, 0.8], pivot * T(0, -2.2, 0), SKIN)
        return pivot

    right = arm(1, arms[0])
    left = arm(-1, arms[1])
    add("Watch", [1.0, 0.22, 1.02], left * T(0, -1.86, 0), GOLD, "Metal", refl=0.35)
    add("WatchFace", [0.36, 0.06, 0.36], left * T(0, -1.86, -0.52) * R(rx=90), [20, 60, 70], "Glass", refl=0.4)
    add("Ring", [0.3, 0.12, 0.3], right * T(0.3, -2.25, -0.2), GOLD, "Metal", "Ball", 0.4)

    # Props.
    if pose == "flex":
        for i in range(7):
            add("Note", [0.9, 0.04, 1.6], right * T(0, -2.55, 0) * R(ry=-45 + i * 15, rx=-10) * T(0.0, 0.02 * i, -0.7), CASH, "SmoothPlastic")
    if pose == "run":
        add("GoldBar", [1.6, 0.55, 0.8], left * T(0, -2.3, -0.55) * R(rx=20), [255, 196, 64], "Neon")
        add("GoldBarTop", [1.3, 0.12, 0.6], left * T(0, -2.0, -0.6) * R(rx=20), [255, 236, 150], "Neon")
    if pose == "aim":
        add("Pistol", [0.35, 0.5, 1.4], right * T(0, -2.45, -0.4), [40, 44, 52], "Metal", refl=0.2)
        add("PistolGlow", [0.2, 0.2, 0.2], right * T(0, -2.4, -1.15), [120, 200, 255], "Neon", "Ball")
    if pose == "point":
        add("Finger", [0.18, 0.18, 0.5], right * T(0, -2.5, -0.15), SKIN)
    if look == "boss":
        add("Tie", [0.22, 1.3, 0.04], torso * T(0, 1.4, -0.5), [176, 24, 34], "Fabric")
    return parts


def cash_rain(centre, spread, count, seed=7):
    """Notes and gold coins in the air round `centre` (a shower of money for a poster)."""
    import random
    rnd = random.Random(seed)
    out = []
    for i in range(count):
        p = [centre[0] + rnd.uniform(-spread, spread), centre[1] + rnd.uniform(-spread * 0.3, spread * 0.6), centre[2] + rnd.uniform(-spread * 0.5, spread * 0.5)]
        cf = CF(p) * R(rx=rnd.uniform(-70, 70), ry=rnd.uniform(0, 360), rz=rnd.uniform(-60, 60))
        if i % 3 == 0:
            out.append(["Coin", "Cylinder", [0.12, 0.7, 0.7], cf.comps(), GOLD, "Metal", 0, 0.35, True, ""])
        else:
            out.append(["Note", "Block", [1.3, 0.03, 0.62], cf.comps(), CASH, "SmoothPlastic", 0, 0, True, ""])
    return out


def main():
    world_file, out_file, poses_file = sys.argv[1:4]
    world = json.load(open(world_file))
    for p in json.load(open(poses_file)):
        if p.get("rain"):
            world["parts"].extend(cash_rain(p["rain"], p.get("spread", 6), p.get("count", 40), p.get("seed", 7)))
            continue
        world["parts"].extend(build(p["at"], p.get("yaw", 0), p.get("pose", "crossed"), p.get("scale", 1.0), p.get("look", "guest")))
    json.dump(world, open(out_file, "w"))
    print(f"wrote {out_file}: {len(world['parts'])} parts")


if __name__ == "__main__":
    main()

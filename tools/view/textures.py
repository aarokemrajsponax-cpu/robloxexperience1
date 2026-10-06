#!/usr/bin/env python3
"""Draws every SurfaceGui of an exported house (EXPORT=<file> lune run tests/smoke.luau) to a
transparent PNG, with the same layout code as the UI previews (tools/ui/render.py), for the 3D
viewer to lay on its part's face.

Usage: python3 tools/view/textures.py <world.json> <out-dir>
"""

import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "ui"))
import render as R  # noqa: E402

MAX_SIDE = 1024


def main():
    world = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    os.makedirs(out, exist_ok=True)
    for i, g in enumerate(world["guis"]):
        cw, ch = g["canvas"]
        if cw < 1 or ch < 1:
            continue
        k = min(1.0, MAX_SIDE / max(cw, ch))
        canvas = Image.new("RGBA", (max(1, int(cw * k)), max(1, int(ch * k))), (0, 0, 0, 0))
        base = R.Box(0, 0, cw, ch)
        nodes = [n for n in g["kids"] if R.is_gui(n)]
        try:
            for n in nodes:
                R.place(n, base)
            for n in sorted(nodes, key=lambda n: n.get("z", 1)):
                R.draw_node(canvas, n, 1.0, k)
        except Exception as e:  # one bad gui shouldn't stop the rest
            print(f"gui {i} ({g.get('name')}): {e}")
        canvas.save(os.path.join(out, f"{i}.png"))
    print(f"{len(world['guis'])} surface textures in {out}")


if __name__ == "__main__":
    main()

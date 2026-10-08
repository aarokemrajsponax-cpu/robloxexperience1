#!/usr/bin/env python3
"""Draws a UI snapshot (written by `lune run tests/client.luau full <folder>`) to a PNG, close
enough to Roblox to judge layout, sizes, overlaps, colours and type without opening Studio.

It lays GuiObjects out the way Roblox does (UDim2 against the parent, AnchorPoint, UIScale,
UIPadding, UIListLayout, ClipsDescendants, AutomaticSize for lists and wrapped text) and draws
Frames (colour, transparency, UICorner, UIGradient, UIStroke, rotation) and text. The 3D world
is not drawn: what isn't covered by UI is plain dark grey.

Usage: python3 tools/ui/render.py <snapshot.json> [out.png] [--scale 1]
"""

import json
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

FONT_FILES = {
    "Light": "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "Regular": "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "Medium": "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    "SemiBold": "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "Bold": "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    "Heavy": "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
}
SERIF = "/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf"
_fonts = {}
TOPBAR = 58  # Roblox's top bar inset, for ScreenGuis that don't ignore it

# The house's own faces (tools/ui/get_fonts.sh fetches them from Google Fonts), by the Creator
# Store id the game loads them from. Without them the previews fall back to DejaVu.
FONT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fonts")
WEIGHTS = {"Thin": 100, "ExtraLight": 200, "Light": 300, "Regular": 400, "Medium": 500, "SemiBold": 600, "Bold": 700, "ExtraBold": 800, "Heavy": 900}
POPPINS = {300: "Poppins-Light.ttf", 400: "Poppins-Regular.ttf", 500: "Poppins-Medium.ttf", 600: "Poppins-SemiBold.ttf", 700: "Poppins-SemiBold.ttf"}


def house_font(family, weight, style, px):
    w = WEIGHTS.get(weight, 400)
    if "12187374765" in family:  # Playfair Display
        name = "PlayfairDisplay-Italic[wght].ttf" if style == "Italic" else "PlayfairDisplay[wght].ttf"
        path = os.path.join(FONT_DIR, name)
        if os.path.exists(path):
            f = ImageFont.truetype(path, px)
            try:
                f.set_variation_by_axes([max(400, min(900, w))])
            except Exception:
                pass
            return f
    if "12187366657" in family:  # Lora
        path = os.path.join(FONT_DIR, "Lora[wght].ttf")
        if os.path.exists(path):
            f = ImageFont.truetype(path, px)
            try:
                f.set_variation_by_axes([max(400, min(700, w))])
            except Exception:
                pass
            return f
    if "11702779409" in family:  # Poppins
        nearest = min(POPPINS, key=lambda k: abs(k - w))
        path = os.path.join(FONT_DIR, POPPINS[nearest])
        if os.path.exists(path):
            return ImageFont.truetype(path, px)
    return None


def font(weight, size, family="", style="Normal"):
    px = max(4, int(round(size)))
    key = (family, weight, style, px)
    if key in _fonts:
        return _fonts[key]
    f = house_font(family, weight, style, px)
    if f is None:
        path = SERIF if ("Merriweather" in family or "Garamond" in family or "12187365769" in family) else FONT_FILES.get(weight, FONT_FILES["Regular"])
        # DejaVu runs wide next to the house faces: shrink a touch so widths match better.
        f = ImageFont.truetype(path, max(4, int(round(size * 0.88))))
    _fonts[key] = f
    return f


def kids_of(node, cls):
    return [k for k in node["kids"] if k["class"] == cls]


def first(node, cls):
    for k in node["kids"]:
        if k["class"] == cls:
            return k
    return None


def pads(node, w, h):
    """A node's UIPadding (top, bottom, left, right) in its own unscaled pixels: offset plus
    scale of its own size, as Roblox does."""
    padn = first(node, "UIPadding")
    if not padn:
        return 0, 0, 0, 0
    pt, pb, pl, pr = padn["pad"]
    ps = padn.get("padS")
    if ps:
        pt, pb, pl, pr = pt + ps[0] * h, pb + ps[1] * h, pl + ps[2] * w, pr + ps[3] * w
    return pt, pb, pl, pr


GUI_CLASSES = {"Frame", "TextLabel", "TextButton", "TextBox", "CanvasGroup", "ImageLabel", "ImageButton", "ScrollingFrame", "ViewportFrame"}


def is_gui(n):
    return n["class"] in GUI_CLASSES


def fitted_size(n, width, height):
    """TextScaled: the largest size (up to UITextSizeConstraint's max) whose text fits."""
    cons = first(n, "UITextSizeConstraint")
    hi = cons["maxText"] if cons else 100
    lo = cons["minText"] if cons else 1
    size = hi
    while size > lo:
        f = font(n.get("weight", "Regular"), size, n.get("family", ""), n.get("style", "Normal"))
        if f.getlength(n.get("text", "")) <= width and size * 1.2 <= height + 1:
            break
        size -= 0.5
    return size


def text_block(n, width):
    """Lines and height of a label's text when wrapped to `width`."""
    f = font(n.get("weight", "Regular"), n.get("textSize", 14), n.get("family", ""), n.get("style", "Normal"))
    text = n.get("text", "")
    lines = []
    for para in text.split("\n"):
        if not n.get("wrap") or width <= 0:
            lines.append(para)
            continue
        words, cur = para.split(" "), ""
        for w in words:
            trial = (cur + " " + w).strip() if cur else w
            if f.getlength(trial) <= width or not cur:
                cur = trial
            else:
                lines.append(cur)
                cur = w
        lines.append(cur)
    line_h = n.get("textSize", 14) * 1.2
    return lines, line_h * len(lines), f


class Box:
    def __init__(self, x, y, w, h):
        self.x, self.y, self.w, self.h = x, y, w, h


def measure(node, parent):
    """Computes node['_rect'] (and children's) given the parent's content Box."""
    pos, size = node["pos"], node["size"]
    w = parent.w * size[0] + size[1]
    h = parent.h * size[2] + size[3]
    sc = first(node, "UIScale")
    s = sc["scale"] if sc else 1.0
    node["_s"] = s
    cons = first(node, "UISizeConstraint")
    if cons:
        # (An unbounded MaxSize, math.huge, comes through the JSON as null.)
        hi = cons.get("max") or [None, None]
        lo = cons.get("min") or [0, 0]
        if hi[0] is not None:
            w = min(w, hi[0])
        if hi[1] is not None:
            h = min(h, hi[1])
        w, h = max(w, lo[0] or 0), max(h, lo[1] or 0)
    # Automatic width from a single line of text (tabs and the like): the words plus padding.
    if node.get("auto") in ("X", "XY") and "text" in node and not node.get("wrap"):
        f = font(node.get("weight", "Regular"), node.get("textSize", 14), node.get("family", ""), node.get("style", "Normal"))
        _, _, pl, pr = pads(node, w, h)
        w = max(w, max((f.getlength(line) for line in node.get("text", "").split("\n")), default=0) + pl + pr)
    # Automatic height from wrapped text.
    if node.get("auto") in ("Y", "XY") and "text" in node:
        _, th, _ = text_block(node, w)
        h = max(h, th)
    node["_w0"], node["_h0"] = w, h
    return w * s, h * s


def place(node, parent, at=None):
    w, h = measure(node, parent)
    if at is None:
        ax, ay = node["anchor"]
        px = parent.x + parent.w * node["pos"][0] + node["pos"][1]
        py = parent.y + parent.h * node["pos"][2] + node["pos"][3]
        x, y = px - ax * w, py - ay * h
    else:
        x, y = at
    node["_rect"] = Box(x, y, w, h)
    layout_children(node)
    # Automatic height from a list of children.
    if node.get("auto") in ("Y", "XY") and "text" not in node:
        lst = first(node, "UIListLayout")
        content_h = node.get("_content_h", 0)
        pt, pb, _, _ = pads(node, w, h)
        if lst or any(is_gui(k) for k in node["kids"]):
            new_h = max(h, (content_h + pt + pb) * node["_s"])
            cons = first(node, "UISizeConstraint")
            if cons and cons.get("min"):
                new_h = max(new_h, (cons["min"][1] or 0) * node["_s"])
            if abs(new_h - h) > 0.5:
                ax, ay = node["anchor"]
                if at is None:
                    py = parent.y + parent.h * node["pos"][2] + node["pos"][3]
                    y = py - ay * new_h
                node["_rect"] = Box(x, y, w, new_h)
                layout_children(node)


def layout_children(node):
    r = node["_rect"]
    s = node["_s"]
    pt, pb, pl, pr = pads(node, r.w / s if s else r.w, r.h / s if s else r.h)
    content = Box(r.x + pl * s, r.y + pt * s, r.w - (pl + pr) * s, r.h - (pt + pb) * s)
    # Children are laid out in the unscaled space, then scaled with the parent.
    inner = Box(content.x, content.y, content.w / s if s else content.w, content.h / s if s else content.h)
    lst = first(node, "UIListLayout")
    grid = first(node, "UIGridLayout")
    guis = [k for k in node["kids"] if is_gui(k)]
    if grid:
        cw = inner.w * grid["cell"][0] + grid["cell"][1]
        ch = inner.h * grid["cell"][2] + grid["cell"][3]
        px = inner.w * grid["cellPad"][0] + grid["cellPad"][1]
        py = inner.h * grid["cellPad"][2] + grid["cellPad"][3]
        per_row = max(1, int((inner.w + px) // (cw + px)))
        vis = sorted([k for k in guis if k.get("visible", True)], key=lambda k: k.get("order", 0))
        rows = math.ceil(len(vis) / per_row) if vis else 0
        for i, k in enumerate(vis):
            col, row = i % per_row, i // per_row
            in_row = min(per_row, len(vis) - row * per_row)
            used = in_row * cw + (in_row - 1) * px
            x0 = inner.x + ((inner.w - used) / 2 if grid["hAlign"] == "Center" else 0)
            k["size"] = [0, cw, 0, ch]
            place(k, inner, (x0 + col * (cw + px), inner.y + row * (ch + py)))
        node["_content_h"] = rows * ch + max(0, rows - 1) * py
        for k in guis:
            if "_rect" not in k:
                place(k, inner)
    elif lst:
        guis_v = [k for k in guis if k.get("visible", True)]
        guis_v.sort(key=lambda k: k.get("order", 0))
        padding = lst["padding"][1] + lst["padding"][0] * (inner.h if lst["dir"] == "Vertical" else inner.w)
        sizes = [measure(k, inner) for k in guis_v]
        if lst["dir"] == "Vertical":
            # First pass: lay each child out where it stands, to learn its real (automatic) height.
            heights = []
            for k, (kw, kh) in zip(guis_v, sizes):
                place(k, inner, (inner.x, inner.y))
                heights.append(k["_rect"].h)
            total = sum(heights) + padding * max(0, len(heights) - 1)
            node["_content_h"] = total
            y = inner.y
            if lst["vAlign"] == "Center":
                y = inner.y + (inner.h - total) / 2
            elif lst["vAlign"] == "Bottom":
                y = inner.y + inner.h - total
            for k, (kw, kh) in zip(guis_v, sizes):
                kw = k["_rect"].w
                if lst["hAlign"] == "Center":
                    x = inner.x + (inner.w - kw) / 2
                elif lst["hAlign"] == "Right":
                    x = inner.x + inner.w - kw
                else:
                    x = inner.x
                place(k, inner, (x, y))
                y += k["_rect"].h + padding
        else:
            total = sum(sz[0] for sz in sizes) + padding * max(0, len(sizes) - 1)
            node["_content_h"] = max([sz[1] for sz in sizes] + [0])
            x = inner.x
            if lst["hAlign"] == "Center":
                x = inner.x + (inner.w - total) / 2
            elif lst["hAlign"] == "Right":
                x = inner.x + inner.w - total
            for k, (kw, kh) in zip(guis_v, sizes):
                if lst["vAlign"] == "Center":
                    y = inner.y + (inner.h - kh) / 2
                elif lst["vAlign"] == "Bottom":
                    y = inner.y + inner.h - kh
                else:
                    y = inner.y
                place(k, inner, (x, y))
                x += kw + padding
        for k in guis:
            if "_rect" not in k:
                place(k, inner)
    else:
        bottom = 0
        for k in guis:
            place(k, inner)
            bottom = max(bottom, k["_rect"].y + k["_rect"].h - inner.y)
        node["_content_h"] = bottom
    if s != 1:
        for k in guis:
            scale_tree(k, content.x, content.y, s)


def scale_tree(node, ox, oy, s):
    """Applies a parent's UIScale to a laid-out subtree, about the parent's content corner."""
    if "_rect" in node:
        r = node["_rect"]
        node["_rect"] = Box(ox + (r.x - ox) * s, oy + (r.y - oy) * s, r.w * s, r.h * s)
        node["_S"] = node.get("_S", 1) * s
    for k in node["kids"]:
        if is_gui(k):
            scale_tree(k, ox, oy, s)


def gradient_fill(w, h, grad, base_rgb, base_t):
    w, h = max(1, int(round(w))), max(1, int(round(h))
    )
    u = (np.arange(w) + 0.5) / w
    v = (np.arange(h) + 0.5) / h
    U, V = np.meshgrid(u, v)
    rgb = np.ones((h, w, 3)) * np.array(base_rgb)
    alpha = np.full((h, w), 1 - base_t)
    if grad and grad.get("enabled", True):
        rad = math.radians(grad.get("rot", 0))
        off = grad.get("offset", [0, 0])
        t = 0.5 + (U - 0.5 - off[0]) * math.cos(rad) + (V - 0.5 - off[1]) * math.sin(rad)
        t = np.clip(t, 0, 1)
        cs = grad["colors"]
        ts = [c[0] for c in cs]
        for ch in range(3):
            rgb[..., ch] = rgb[..., ch] * np.interp(t, ts, [c[1 + ch] for c in cs])
        tr = grad["trans"]
        alpha = alpha * (1 - np.interp(t, [x[0] for x in tr], [x[1] for x in tr]))
    arr = np.dstack([np.clip(rgb, 0, 1) * 255, np.clip(alpha, 0, 1) * 255]).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def rounded_mask(size, box, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=max(0, radius), fill=255)
    return m


def draw_node(canvas, node, alpha_mul, k, clip=None):
    if not node.get("visible", True):
        return
    r = node["_rect"]
    group_t = node.get("groupT", 0)
    amul = alpha_mul * (1 - group_t)
    rot = node.get("rot", 0) or 0
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0)) if rot else canvas
    W, H = r.w * k, r.h * k
    X, Y = r.x * k, r.y * k
    corner = first(node, "UICorner")
    radius = 0
    if corner:
        radius = min(W, H) * corner["radius"][0] + corner["radius"][1] * k * node["_s"] * node.get("_S", 1)
        radius = min(radius, min(W, H) / 2)
    grad = first(node, "UIGradient")
    if node["class"] in ("Frame", "TextLabel", "TextButton", "CanvasGroup", "TextBox", "ScrollingFrame") and node.get("bgT", 1) < 1 and W >= 1 and H >= 1:
        fill = gradient_fill(W, H, grad, node["bg"], node["bgT"])
        m = rounded_mask(fill.size, (0, 0, fill.size[0] - 1, fill.size[1] - 1), radius)
        a = np.array(fill)
        a[..., 3] = (a[..., 3].astype(np.float32) * np.array(m) / 255 * amul).astype(np.uint8)
        layer.alpha_composite(Image.fromarray(a, "RGBA"), (int(round(X)), int(round(Y))))
    stroke = first(node, "UIStroke")
    if stroke and stroke.get("enabled", True) and stroke["trans"] < 1 and W >= 1:
        t = max(1, stroke["thickness"] * k * node["_s"] * node.get("_S", 1))
        pad = int(t + 2)
        ow, oh = int(W + 2 * pad), int(H + 2 * pad)
        outer = rounded_mask((ow, oh), (pad - t, pad - t, pad + W - 1 + t, pad + H - 1 + t), radius + t)
        inner = rounded_mask((ow, oh), (pad, pad, pad + W - 1, pad + H - 1), radius)
        ring = np.clip(np.array(outer, dtype=np.int16) - np.array(inner, dtype=np.int16), 0, 255)
        sg = first(stroke, "UIGradient")
        col = gradient_fill(ow, oh, sg, stroke["color"], stroke["trans"])
        a = np.array(col)
        a[..., 3] = (a[..., 3].astype(np.float32) * ring / 255 * amul).astype(np.uint8)
        layer.alpha_composite(Image.fromarray(a, "RGBA"), (int(round(X - pad)), int(round(Y - pad))))
    if "text" in node and node.get("text") and node.get("textT", 1) < 1:
        ts = node["_s"] * node.get("_S", 1)
        pt, pb, pl, pr = pads(node, r.w / ts, r.h / ts)
        avail_w = r.w / ts - pl - pr
        avail_h = r.h / ts - pt - pb
        if node.get("scaled"):
            node = dict(node)
            node["textSize"] = fitted_size(node, avail_w, avail_h)
        lines, th, f0 = text_block(node, avail_w)
        f = font(node.get("weight", "Regular"), node.get("textSize", 14) * ts * k, node.get("family", ""), node.get("style", "Normal"))
        line_h = node.get("textSize", 14) * 1.2 * ts * k
        X, W = X + pl * ts * k, W - (pl + pr) * ts * k
        Y, H = Y + pt * ts * k, H - (pt + pb) * ts * k
        total = line_h * len(lines)
        ya = node.get("yAlign", "Center")
        y = Y + (H - total) / 2 if ya == "Center" else (Y if ya == "Top" else Y + H - total)
        d = ImageDraw.Draw(layer)
        c = node.get("textColor", [1, 1, 1])
        tcol = tuple(int(255 * v) for v in c) + (int(255 * (1 - node["textT"]) * amul),)
        for line in lines:
            lw = f.getlength(line)
            xa = node.get("xAlign", "Center")
            x = X + (W - lw) / 2 if xa == "Center" else (X if xa == "Left" else X + W - lw)
            d.text((x, y + line_h * 0.08), line, font=f, fill=tcol)
            y += line_h
    kids = [kk for kk in node["kids"] if is_gui(kk)]
    kids.sort(key=lambda kk: kk.get("z", 1))
    child_clip = clip
    clips = node.get("clip") or node["class"] in ("CanvasGroup", "ScrollingFrame")
    if clips and not rot:
        child_clip = (X, Y, X + W, Y + H)
    for kk in kids:
        if child_clip and clips:
            sub = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
            draw_node(sub, kk, amul, k, child_clip)
            m = Image.new("L", canvas.size, 0)
            ImageDraw.Draw(m).rectangle(child_clip, fill=255)
            a = np.array(sub)
            a[..., 3] = (a[..., 3].astype(np.float32) * np.array(m) / 255).astype(np.uint8)
            layer.alpha_composite(Image.fromarray(a, "RGBA"))
        else:
            draw_node(layer, kk, amul, k, child_clip)
    if rot:
        cx, cy = X + W / 2, Y + H / 2
        rotated = layer.rotate(-rot, resample=Image.BICUBIC, center=(cx, cy))
        canvas.alpha_composite(rotated)


def render(snapshot, out, k=1.0):
    data = json.load(open(snapshot))
    vw, vh = data["viewport"]
    canvas = Image.new("RGBA", (int(vw * k), int(vh * k)), (34, 34, 38, 255))
    guis = [g for g in data["guis"] if g.get("enabled", True)]
    guis.sort(key=lambda g: g.get("order", 0))
    for g in guis:
        inset = 0 if g.get("ignoreInset") else TOPBAR
        screen = Box(0, inset, vw, vh - inset)
        scale = first(g, "UIScale")
        s = scale["scale"] if scale else 1.0
        # A ScreenGui's UIScale scales its whole canvas.
        base = Box(0, inset, vw / s, (vh - inset) / s)
        for n in [kk for kk in g["kids"] if is_gui(kk)]:
            place(n, base)
            if s != 1:
                scale_tree(n, 0, inset, s)
        layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
        for n in sorted([kk for kk in g["kids"] if is_gui(kk)], key=lambda kk: kk.get("z", 1)):
            draw_node(layer, n, 1.0, k)
        canvas.alpha_composite(layer)
    canvas.convert("RGB").save(out)


if __name__ == "__main__":
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else src.replace(".json", ".png")
    render(src, dst)
    print(dst)

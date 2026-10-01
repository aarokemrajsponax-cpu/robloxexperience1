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


def font(weight, size, family=""):
    path = SERIF if ("Merriweather" in family or "Garamond" in family) else FONT_FILES.get(weight, FONT_FILES["Regular"])
    # DejaVu runs wide next to Gotham: shrink a touch so widths match better.
    px = max(4, int(round(size * 0.88)))
    key = (path, px)
    if key not in _fonts:
        _fonts[key] = ImageFont.truetype(path, px)
    return _fonts[key]


def kids_of(node, cls):
    return [k for k in node["kids"] if k["class"] == cls]


def first(node, cls):
    for k in node["kids"]:
        if k["class"] == cls:
            return k
    return None


GUI_CLASSES = {"Frame", "TextLabel", "TextButton", "TextBox", "CanvasGroup", "ImageLabel", "ImageButton", "ScrollingFrame", "ViewportFrame"}


def is_gui(n):
    return n["class"] in GUI_CLASSES


def text_block(n, width):
    """Lines and height of a label's text when wrapped to `width`."""
    f = font(n.get("weight", "Regular"), n.get("textSize", 14), n.get("family", ""))
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
        w = min(w, cons["max"][0])
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
        padn = first(node, "UIPadding")
        pt, pb = (padn["pad"][0], padn["pad"][1]) if padn else (0, 0)
        if lst or any(is_gui(k) for k in node["kids"]):
            new_h = max(h, (content_h + pt + pb) * node["_s"])
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
    padn = first(node, "UIPadding")
    pt, pb, pl, pr = padn["pad"] if padn else (0, 0, 0, 0)
    content = Box(r.x + pl * s, r.y + pt * s, r.w - (pl + pr) * s, r.h - (pt + pb) * s)
    # Children are laid out in the unscaled space, then scaled with the parent.
    inner = Box(content.x, content.y, content.w / s if s else content.w, content.h / s if s else content.h)
    lst = first(node, "UIListLayout")
    guis = [k for k in node["kids"] if is_gui(k)]
    if lst:
        guis_v = [k for k in guis if k.get("visible", True)]
        guis_v.sort(key=lambda k: k.get("order", 0))
        padding = lst["padding"][1] + lst["padding"][0] * (inner.h if lst["dir"] == "Vertical" else inner.w)
        sizes = [measure(k, inner) for k in guis_v]
        if lst["dir"] == "Vertical":
            total = sum(sz[1] for sz in sizes) + padding * max(0, len(sizes) - 1)
            node["_content_h"] = total
            y = inner.y
            if lst["vAlign"] == "Center":
                y = inner.y + (inner.h - total) / 2
            elif lst["vAlign"] == "Bottom":
                y = inner.y + inner.h - total
            for k, (kw, kh) in zip(guis_v, sizes):
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
        lines, th, f0 = text_block(node, r.w / (node["_s"] * node.get("_S", 1)))
        ts = node["_s"] * node.get("_S", 1)
        f = font(node.get("weight", "Regular"), node.get("textSize", 14) * ts * k, node.get("family", ""))
        line_h = node.get("textSize", 14) * 1.2 * ts * k
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
    clips = node.get("clip") or node["class"] == "CanvasGroup"
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

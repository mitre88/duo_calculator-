#!/usr/bin/env python3
"""Renders the app icon (light / dark / tinted, 1024×1024) into the asset catalog.

    python3 Tools/gen_icon.py

The icon is the "=" of the calculator split by the hinge of the iPhone Duo: four rounded amber
segments on a deep canvas with the app's aurora behind them. Everything is drawn at 2048 px and
downsampled with Lanczos, so the edges are clean at every size. Only Pillow is needed.
An `AppIcon.icon` from Icon Composer (layered Liquid Glass) can replace these files later.
"""
from __future__ import annotations

import json
import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageOps

S = 2048                      # supersampled canvas
OUT_SIZE = 1024
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "App/DuoCalculator/Resources/Assets.xcassets/AppIcon.appiconset"

AMBER = (255, 160, 51)
INDIGO = (77, 72, 230)
TEAL = (41, 184, 199)
CANVAS_TOP = (20, 20, 34)
CANVAS_BOTTOM = (7, 7, 11)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def vertical_gradient(size, top, bottom):
    ramp = Image.linear_gradient("L").resize(size, Image.BICUBIC)
    return ImageOps.colorize(ramp, black=top, white=bottom)


def radial_blob(diameter, color, alpha):
    """Soft disc: opaque at the center, transparent at the edge."""
    mask = ImageOps.invert(Image.radial_gradient("L")).resize((diameter, diameter), Image.BICUBIC)
    mask = mask.point(lambda v: int(v * alpha))
    blob = Image.new("RGBA", (diameter, diameter), color + (0,))
    blob.putalpha(mask)
    return blob


def aurora(size):
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    for (cx, cy, d, color, a) in [
        (0.22, 0.30, 1.35, INDIGO, 0.42),
        (0.80, 0.78, 1.25, TEAL, 0.34),
        (0.68, 0.18, 0.80, AMBER, 0.18),
    ]:
        diameter = int(size[0] * d)
        blob = radial_blob(diameter, color, a)
        layer.alpha_composite(blob, (int(size[0] * cx - diameter / 2), int(size[1] * cy - diameter / 2)))
    return layer.filter(ImageFilter.GaussianBlur(size[0] * 0.04))


def hinge(size, strength):
    """Vertical light seam at the center, fading towards top and bottom."""
    w, h = size
    seam = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(seam)
    width = int(w * 0.010)
    draw.rectangle([w // 2 - width // 2, int(h * 0.10), w // 2 + width // 2, int(h * 0.90)], fill=255)
    seam = seam.filter(ImageFilter.GaussianBlur(w * 0.012))
    # fade the ends
    fade = Image.linear_gradient("L").resize((w, h // 2), Image.BICUBIC)
    ends = Image.new("L", (w, h), 255)
    ends.paste(fade, (0, 0))
    ends.paste(ImageOps.flip(fade), (0, h - h // 2))
    seam = Image.composite(seam, Image.new("L", (w, h), 0), ends.point(lambda v: min(255, int(v * 1.6))))
    seam = seam.point(lambda v: int(v * strength))
    layer = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    layer.putalpha(seam)
    return layer


def segment(box, radius):
    """One rounded amber segment with a glass highlight on its upper half."""
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    fill = vertical_gradient((w, h), lerp(AMBER, (255, 255, 255), 0.22), lerp(AMBER, (0, 0, 0), 0.08)).convert("RGBA")
    # highlight: white band over the top 46 %, fading out
    hl = Image.new("L", (w, h), 0)
    band = Image.linear_gradient("L").resize((w, int(h * 0.46)), Image.BICUBIC)
    hl.paste(ImageOps.invert(band).point(lambda v: int(v * 0.42)), (0, 0))
    fill.alpha_composite(Image.merge("RGBA", (Image.new("L", (w, h), 255),) * 3 + (hl,)))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    fill.putalpha(mask)
    return fill


def glyph(size, shadow=True):
    """The '=' split by the hinge: 2 bars × 2 halves."""
    w, h = size
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    bar_w, bar_h = int(w * 0.56), int(h * 0.112)
    gap_y = int(h * 0.075)            # between the two bars
    gap_x = int(w * 0.040)            # the hinge channel
    radius = bar_h // 2
    cx, cy = w // 2, int(h * 0.50)
    boxes = []
    for sign in (-1, 1):
        y0 = cy + sign * gap_y // 2 - (bar_h if sign < 0 else 0)
        boxes.append((cx - bar_w // 2, y0, cx - gap_x // 2, y0 + bar_h))
        boxes.append((cx + gap_x // 2, y0, cx + bar_w // 2, y0 + bar_h))
    if shadow:
        sh = Image.new("L", size, 0)
        d = ImageDraw.Draw(sh)
        for b in boxes:
            d.rounded_rectangle([b[0], b[1] + int(h * 0.018), b[2], b[3] + int(h * 0.018)], radius=radius, fill=120)
        sh = sh.filter(ImageFilter.GaussianBlur(w * 0.02))
        shadow_layer = Image.new("RGBA", size, (0, 0, 0, 0))
        shadow_layer.putalpha(sh)
        layer.alpha_composite(shadow_layer)
    for b in boxes:
        layer.alpha_composite(segment(b, radius), (b[0], b[1]))
    return layer


def render_light():
    img = vertical_gradient((S, S), CANVAS_TOP, CANVAS_BOTTOM).convert("RGBA")
    img.alpha_composite(aurora((S, S)))
    img.alpha_composite(hinge((S, S), 0.55))
    img.alpha_composite(glyph((S, S)))
    return img.convert("RGB")


def render_dark():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    img.alpha_composite(hinge((S, S), 0.40))
    img.alpha_composite(glyph((S, S), shadow=False))
    return img


def render_tinted():
    dark = render_dark()
    gray = ImageOps.grayscale(dark.convert("RGB"))
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(Image.merge("RGBA", (gray, gray, gray, dark.getchannel("A"))))
    return out


def save(img, name):
    img = img.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)
    img.save(OUT / name, optimize=True)
    print(f"wrote {name} ({(OUT / name).stat().st_size // 1024} KB)")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    save(render_light(), "AppIcon.png")
    save(render_dark(), "AppIcon-Dark.png")
    save(render_tinted(), "AppIcon-Tinted.png")
    contents = {
        "images": [
            {"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": "AppIcon-Dark.png",
             "idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": "AppIcon-Tinted.png",
             "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    (OUT / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")
    print("updated Contents.json")


if __name__ == "__main__":
    main()

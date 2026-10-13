#!/usr/bin/env python3
"""Compose Dúo Calculator App Store screenshots from real simulator captures (see capture.sh).

Canvas sizes are the exact ones App Store Connect accepts:
  APP_IPHONE_DUO  inner display 2853x2007 (landscape), cover display 1398x2034 (portrait)
  APP_IPHONE_67   6.9" iPhone 1320x2868 (portrait), 2868x1320 (landscape)

Usage: compose.py <raw_dir> <out_dir>
Output: <out_dir>/<locale>/<display>/NN-<slug>.png (RGB, no alpha).
Copy rules: the app is paid (no "free"); "iPhone Duo" only as a referential "optimized for".
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

SF = "/System/Library/Fonts/SFNS.ttf"

TOP = (14, 14, 18)
BOTTOM = (3, 3, 5)
WARM = (255, 161, 53)      # the app's "=" key, sampled from the capture
COOL = (40, 92, 84)        # the aurora's green-teal tint
WHITE = (244, 244, 247)
MUTED = (160, 160, 170)
FRAME = (58, 58, 66)

INNER, COVER = (2853, 2007), (1398, 2034)
PHONE_P, PHONE_L = (1320, 2868), (2868, 1320)
NB = " "

# display folder, raw capture (per locale suffix), canvas, slug
SHOTS = [
    ("duo", "duo_inner_open_{lang}.png", INNER, "optimizada-iphone-duo"),
    ("duo", "duo_cover_basic_{lang}.png", COVER, "cerrado-basica"),
    ("duo", "duo_book_{lang}.png", INNER, "semiabierto-libro"),
    ("duo", "duo_history_{lang}.png", INNER, "historial"),
    ("duo", "duo_prog_{lang}.png", INNER, "programador"),
    ("duo", "duo_conv_{lang}.png", INNER, "conversor"),
    ("iphone69", "ip_portrait_sci_{lang}.png", PHONE_P, "iphone-cientifica"),
    ("iphone69", "ip_history_{lang}.png", PHONE_P, "iphone-historial"),
    ("iphone69", "ip_land_{lang}.png", PHONE_L, "iphone-horizontal"),
]

COPY = {
    "es-MX": [
        (f"iPhone{NB}Duo · Abierto", f"Optimizada para iPhone{NB}Duo", "Ábrela y es una científica completa: funciones, memoria y paréntesis en la pantalla grande."),
        (f"iPhone{NB}Duo · Cerrado", "Cerrada, la de siempre", "Teclas grandes y claras en la pantalla exterior."),
        (f"iPhone{NB}Duo · Semiabierto", "El teclado esquiva el pliegue", "En postura de libro, ninguna tecla queda sobre la bisagra."),
        (f"iPhone{NB}Duo · Historial", "Tus cálculos, a un toque", "Toca un resultado para volver a usarlo. Se guarda solo en tu iPhone."),
        (f"iPhone{NB}Duo · Programador", "HEX, DEC, OCT y BIN a la vez", "Operaciones de bits, desplazamientos y palabras de 8 a 64 bits."),
        (f"iPhone{NB}Duo · Conversor", "Convierte unidades al instante", "87 unidades en 11 categorías: longitud, masa, temperatura y más."),
        ("iPhone · Vertical", "Científica en cualquier iPhone", "Elige básica o científica desde el menú, con conversor e historial."),
        ("iPhone · Historial", "Vuelve a cualquier resultado", "Tus últimos 50 cálculos, listos para reutilizar."),
        ("iPhone · Horizontal", "Gíralo y es científica", "Trigonometría, potencias y logaritmos en horizontal."),
    ],
    "en-US": [
        (f"iPhone{NB}Duo · Unfolded", f"Optimized for iPhone{NB}Duo", "Unfold it for a full scientific calculator: functions, memory and parentheses on the big screen."),
        (f"iPhone{NB}Duo · Folded", "Folded, the one you know", "Big, clear keys on the cover screen."),
        (f"iPhone{NB}Duo · Half open", "Keys step around the fold", "In book posture, no key ever sits on the hinge."),
        (f"iPhone{NB}Duo · History", "Every result, one tap away", "Tap a result to use it again. It stays on your iPhone."),
        (f"iPhone{NB}Duo · Programmer", "HEX, DEC, OCT and BIN at once", "Bitwise logic, shifts and 8- to 64-bit words."),
        (f"iPhone{NB}Duo · Converter", "Convert units instantly", "87 units in 11 categories: length, mass, temperature and more."),
        ("iPhone · Portrait", "Scientific on every iPhone", "Pick Basic or Scientific from the menu, with a converter and history."),
        ("iPhone · History", "Go back to any result", "Your last 50 calculations, ready to reuse."),
        ("iPhone · Landscape", "Turn it for scientific", "Trig, powers and logarithms in landscape."),
    ],
}


def font(size: int, weight: str) -> ImageFont.FreeTypeFont:
    f = ImageFont.truetype(SF, size)
    f.set_variation_by_name(weight)
    return f


def background(size):
    w, h = size
    grad = Image.new("RGB", (1, 256))
    for y in range(256):
        t = y / 255
        grad.putpixel((0, y), tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)))
    canvas = grad.resize((w, h), Image.BICUBIC)
    for color, box, alpha in ((WARM, (-0.30, -0.30, 0.55, 0.45), 70), (COOL, (0.45, 0.55, 1.30, 1.35), 90)):
        glow = Image.new("L", (w, h), 0)
        ImageDraw.Draw(glow).ellipse((w * box[0], h * box[1], w * box[2], h * box[3]), fill=alpha)
        glow = glow.filter(ImageFilter.GaussianBlur(min(w, h) * 0.2))
        canvas.paste(Image.new("RGB", (w, h), color), (0, 0), glow)
    return canvas


def wrap(draw, text, fnt, max_w):
    lines, cur = [], ""
    for word in text.split(" "):
        trial = f"{cur} {word}" if cur else word
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)
    return lines


def text_block(img, kicker, headline, subtitle, x, y, max_w, scale, max_head_lines):
    d = ImageDraw.Draw(img)
    f_eye = font(round(32 * scale), "Semibold")
    f_kick = font(round(28 * scale), "Medium")
    f_body = font(round(42 * scale), "Regular")
    for shrink in (1.0, 0.94, 0.88, 0.82, 0.76):
        f_head = font(round(94 * scale * shrink), "Bold")
        head = wrap(d, headline, f_head, max_w)
        # fits, and no one-word last line when it wraps
        if len(head) <= max_head_lines and (len(head) == 1 or len(head[-1].split()) > 1):
            break
    d.text((x, y), "D Ú O   C A L C U L A T O R", font=f_eye, fill=WARM)
    y += round(54 * scale)
    d.text((x, y), kicker, font=f_kick, fill=MUTED)
    y += round(70 * scale)
    for line in head:
        d.text((x, y), line, font=f_head, fill=WHITE)
        y += round(f_head.size * 1.15)
    y += round(20 * scale)
    for line in wrap(d, subtitle, f_body, max_w):
        d.text((x, y), line, font=f_body, fill=MUTED)
        y += round(58 * scale)
    return y


def framed(raw, target_w, radius, border):
    shot = raw.convert("RGB")
    h = round(shot.height * target_w / shot.width)
    shot = shot.resize((target_w, h), Image.LANCZOS)
    out = Image.new("RGBA", (target_w + 2 * border, h + 2 * border), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle((0, 0, out.width - 1, out.height - 1), radius=radius + border, fill=FRAME + (255,))
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, shot.width - 1, shot.height - 1), radius=radius, fill=255)
    out.paste(shot, (border, border), mask)
    shadow = Image.new("RGBA", (out.width + 160, out.height + 160), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((80, 100, 80 + out.width, 100 + out.height), radius=radius + border, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    shadow.paste(out, (80, 80), out)
    return shadow, 80


def compose(raw_path, size, copy):
    kicker, headline, subtitle = copy
    img = background(size)
    w, h = size
    raw = Image.open(raw_path)
    if w > h:
        # Landscape: text on the left, the capture on the right.
        scale = 1.55 if size == INNER else 1.25
        text_w = round(w * (0.30 if size == INNER else 0.27))
        y0 = round(h * (0.24 if size == INNER else 0.2))
        text_block(img, kicker, headline, subtitle, x=round(w * 0.055), y=y0, max_w=text_w, scale=scale, max_head_lines=3)
        target_w = round(w * (0.56 if size == INNER else 0.6))
        target_w = min(target_w, round((h * 0.86) * raw.width / raw.height))
        shot, pad = framed(raw, target_w, radius=round(target_w * 0.035), border=6)
        img.paste(shot, (w - shot.width + pad - round(w * 0.045), (h - shot.height) // 2), shot)
    else:
        # Portrait: text on top, the capture below.
        bottom = text_block(img, kicker, headline, subtitle, x=round(w * 0.08), y=round(h * 0.06),
                            max_w=round(w * 0.84), scale=1.0, max_head_lines=2)
        avail_h = h - bottom - round(h * 0.05)
        target_w = min(round(w * 0.78), round(avail_h * raw.width / raw.height))
        shot, pad = framed(raw, target_w, radius=round(target_w * 0.07), border=6)
        img.paste(shot, ((w - shot.width) // 2, h - shot.height + pad - round(h * 0.035)), shot)
    return img.convert("RGB")


def main():
    raw_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    for locale, copies in COPY.items():
        lang = "es" if locale.startswith("es") else "en"
        counters = {}
        for (display, pattern, size, slug), copy in zip(SHOTS, copies, strict=True):
            raw_name = pattern.format(lang=lang)
            counters[display] = counters.get(display, 0) + 1
            folder = out_dir / locale / display
            folder.mkdir(parents=True, exist_ok=True)
            img = compose(raw_dir / raw_name, size, copy)
            assert img.size == size and img.mode == "RGB", (raw_name, img.size)
            path = folder / f"{counters[display]:02d}-{slug}.png"
            img.save(path, optimize=True)
            print(path)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generates the bedroom's printed and patterned surfaces (docs/AQUARIUM.md) into
assets/textures/room: original, generic late-1980s / early-1990s kid's-room designs (no brands,
characters or logos). Deterministic. Run from the repository root:  python3 tools/gen_room.py

Outputs:
  atlas.png      2048x1024: every printed thing (posters, the window's dusk view, the CRT's game,
                 papers, comics, magazines, book spines, stickers, labels, the rug, the clock
                 digits, ...). Its regions are mirrored in Bedroom.ATLAS (scripts/world/bedroom.gd);
                 keep the two in step.
  wallpaper.png  512 tile: faded cream paper with pinstripes and sprigs.
  blanket.png    512 tile: a loud geometric comforter print.
  wood.png       512 tile: pale wood planks with grain (tinted per piece by vertex colour).
  fabric.png     256 tile: a soft weave for clothes, sheets and cushions.
All are sampled with mipmaps (see the .import files).
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "room")
FONTS = "/usr/share/fonts/truetype/"
R = random.Random(1989)

# Atlas regions (x, y, w, h) in pixels: mirrored in Bedroom.ATLAS.
ATLAS = {
    "white": (1248, 888, 64, 64),
    "poster_space": (0, 0, 400, 540),
    "poster_shapes": (408, 0, 400, 540),
    "poster_sunset": (816, 0, 400, 540),
    "window": (1224, 0, 440, 380),
    "crt": (1672, 0, 368, 276),
    "border": (1224, 388, 440, 64),
    "cassette": (1224, 460, 440, 80),
    "clock": (1672, 284, 176, 64),
    "stickers": (1672, 356, 352, 176),
    "note_paper": (0, 552, 224, 280),
    "homework": (232, 552, 224, 290),
    "calendar": (464, 552, 224, 300),
    "drawing": (0, 852, 224, 168),
    "notebook": (232, 852, 224, 168),
    "cork": (464, 860, 224, 160),
    "comics": (696, 552, 768, 176),
    "magazines": (696, 736, 544, 184),
    "carts": (1248, 736, 192, 144),
    "spines": (1472, 552, 560, 220),
    "rug": (1472, 780, 560, 236),
    "boardgame": (696, 928, 200, 90),
    "pennant": (904, 928, 300, 90),
    "tv_bezel": (1320, 888, 140, 128),
}


def font(size, kind="hand"):
    name = {"hand": "freefont/FreeSansOblique.ttf", "bold": "dejavu/DejaVuSans-Bold.ttf",
            "boldi": "freefont/FreeSansBoldOblique.ttf", "mono": "dejavu/DejaVuSansMono-Bold.ttf",
            "serif": "dejavu/DejaVuSerif-Bold.ttf"}[kind]
    try:
        return ImageFont.truetype(FONTS + name, size)
    except OSError:
        return ImageFont.load_default()


def save(im, name):
    im.save(os.path.join(OUT, name), optimize=True)


def fade(im, k=0.12, tint=(250, 240, 215)):
    """Sun-faded, slightly yellowed print."""
    return Image.blend(im.convert("RGB"), Image.new("RGB", im.size, tint), k)


def vgrad(d, box, top, bot):
    x0, y0, x1, y1 = box
    for y in range(y0, y1):
        k = (y - y0) / max(1, (y1 - y0 - 1))
        d.line([(x0, y), (x1 - 1, y)], fill=tuple(int(a + (b - a) * k) for a, b in zip(top, bot)))


# --- Posters ---------------------------------------------------------------------------------

def poster_space(w, h):
    """A starfield with a ringed planet, a crescent moon and a comet: a glow-in-the-dark style print."""
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    vgrad(d, (0, 0, w, h), (10, 8, 50), (46, 24, 90))
    for _ in range(420):
        x, y, s = R.randrange(w), R.randrange(h), R.choice([1, 1, 1, 1, 2, 2, 3])
        c = R.choice([(255, 255, 240), (200, 220, 255), (255, 230, 180)])
        d.ellipse([x, y, x + s, y + s], fill=c)
    # A nebula smudge.
    neb = Image.new("RGB", (w, h))
    nd = ImageDraw.Draw(neb)
    for _ in range(30):
        x, y, r = R.randrange(0, w), R.randrange(h // 2, h), R.randrange(20, 70)
        nd.ellipse([x - r, y - r, x + r, y + r], fill=(90, 30, 110))
    neb = neb.filter(ImageFilter.GaussianBlur(28))
    im = ImageChops.add(im, neb)
    d = ImageDraw.Draw(im)
    cx, cy, r = 220, 250, 100
    d.ellipse([cx - 165, cy - 30, cx + 165, cy + 30], outline=(230, 180, 120), width=7)
    for i in range(r, 0, -1):
        k = i / r
        d.ellipse([cx - i + (1 - k) * 25, cy - i - (1 - k) * 20, cx + i + (1 - k) * 25, cy + i - (1 - k) * 20],
                  fill=(int(235 - 110 * k), int(140 - 70 * k), int(90 - 40 * k)))
    for band in (-44, -10, 24, 58):
        d.arc([cx - r, cy - r + band, cx + r, cy + r + band], 200, 340, fill=(150, 75, 55), width=6)
    d.arc([cx - 165, cy - 30, cx + 165, cy + 30], 0, 180, fill=(245, 205, 145), width=7)
    d.ellipse([50, 60, 136, 146], fill=(240, 240, 210))
    d.ellipse([72, 52, 158, 138], fill=(16, 12, 58))
    for i in range(50):
        d.ellipse([300 + i * 1.6, 90 + i * 0.9, 305 + i * 1.6, 95 + i * 0.9], fill=(255, 255, max(40, 230 - i * 4)))
    d.text((24, h - 70), "THE OUTER PLANETS", fill=(250, 220, 120), font=font(26, "bold"))
    d.line([(24, h - 36), (w - 24, h - 36)], fill=(250, 220, 120), width=2)
    d.rectangle([0, 0, w - 1, h - 1], outline=(236, 234, 222), width=12)
    return fade(im, 0.06)


def poster_shapes(w, h):
    """A loud early-90s geometric print: squiggles, triangles, dots and zigzags on teal."""
    im = Image.new("RGB", (w, h), (32, 170, 165))
    d = ImageDraw.Draw(im)
    cols = [(250, 90, 150), (255, 210, 40), (40, 40, 60), (250, 250, 245), (150, 90, 220)]
    for _ in range(70):
        c = R.choice(cols)
        x, y = R.randrange(-20, w), R.randrange(-20, h)
        kind = R.randrange(5)
        if kind == 0:
            s = R.randrange(24, 70)
            d.polygon([(x, y), (x + s, y + s // 3), (x + s // 3, y + s)], fill=c)
        elif kind == 1:
            s = R.randrange(8, 20)
            d.ellipse([x, y, x + s, y + s], fill=c)
        elif kind == 2:
            pts = [(x + i * 10, y + (12 if i % 2 else 0)) for i in range(8)]
            d.line(pts, fill=c, width=6)
        elif kind == 3:
            pts = [(x + i * 5, y + 14 * math.sin(i * 0.6)) for i in range(18)]
            d.line(pts, fill=c, width=7)
        else:
            d.rectangle([x, y, x + 30, y + 30], outline=c, width=5)
    d.rectangle([40, 190, w - 40, 300], fill=(40, 40, 60))
    d.text((60, 205), "RADICAL", fill=(255, 210, 40), font=font(58, "boldi"))
    d.rectangle([0, 0, w - 1, h - 1], outline=(250, 250, 245), width=12)
    return fade(im, 0.08)


def poster_sunset(w, h):
    """A neon sunset over a wire-frame grid with mountains and palm silhouettes."""
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    hz = int(h * 0.58)
    vgrad(d, (0, 0, w, hz), (30, 10, 70), (250, 110, 90))
    vgrad(d, (0, hz, w, h), (40, 0, 60), (10, 0, 30))
    cx, cy, r = w // 2, hz - 30, 110
    for i in range(r, 0, -1):
        k = i / r
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=(255, int(230 - 120 * k), int(80 - 40 * k)))
    for k in range(6):
        y = cy + 10 + k * 16
        d.rectangle([cx - r, y, cx + r, y + 3 + k], fill=(250, 110, 90) if y < hz else (40, 0, 60))
    d.polygon([(0, hz), (70, hz - 90), (130, hz - 40), (200, hz - 120), (290, hz - 30), (340, hz - 80), (w, hz - 20), (w, hz)], fill=(60, 20, 90))
    for i in range(-12, 13):
        d.line([(cx, hz), (cx + i * 60, h)], fill=(255, 60, 200), width=2)
    y, s = hz, 6
    while y < h:
        d.line([(0, y), (w, y)], fill=(255, 60, 200), width=2)
        y += s
        s = int(s * 1.35) + 1
    for px, ph in ((50, 250), (w - 60, 220)):
        d.line([(px, hz + 20), (px + 12, hz + 20 - ph)], fill=(15, 5, 25), width=9)
        for a in range(7):
            ang = a / 7 * math.pi * 1.2 + math.pi * 0.9
            d.line([(px + 12, hz + 20 - ph), (px + 12 + math.cos(ang) * 70, hz + 20 - ph + math.sin(ang) * 40 + 30)], fill=(15, 5, 25), width=8)
    d.text((34, 36), "NIGHT DRIVE", fill=(120, 240, 255), font=font(48, "boldi"))
    d.rectangle([0, 0, w - 1, h - 1], outline=(236, 234, 222), width=12)
    return fade(im, 0.05)


def window_view(w, h):
    """Dusk through the window: a deep-blue to amber sky, rooftops with lit windows, a tree."""
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    vgrad(d, (0, 0, w, int(h * 0.5)), (40, 60, 130), (150, 120, 170))
    vgrad(d, (0, int(h * 0.5), w, h), (150, 120, 170), (255, 170, 110))
    for _ in range(12):
        x, y = R.randrange(w), R.randrange(int(h * 0.3))
        d.point((x, y), fill=(240, 240, 255))
    d.ellipse([60, 40, 64, 44], fill=(255, 255, 240))
    base = int(h * 0.72)
    x = -20
    while x < w:
        hw = R.randrange(90, 150)
        hh = R.randrange(50, 90)
        d.rectangle([x, base - hh, x + hw, h], fill=(38, 30, 52))
        d.polygon([(x - 10, base - hh), (x + hw // 2, base - hh - 50), (x + hw + 10, base - hh)], fill=(32, 25, 45))
        for k in range(R.randrange(1, 3)):
            wx = x + 15 + k * 50
            d.rectangle([wx, base - hh + 20, wx + 22, base - hh + 40], fill=(255, 200, 110) if R.random() < 0.7 else (70, 60, 90))
        x += hw + R.randrange(10, 40)
    tx, ty = w - 110, base - 40
    d.rectangle([tx - 6, ty, tx + 6, h], fill=(20, 16, 28))
    for _ in range(60):
        a = R.random() * math.tau
        rr = R.random() * 90
        cx, cy = tx + math.cos(a) * rr, ty - 90 + math.sin(a) * rr * 0.8
        s = R.randrange(18, 36)
        d.ellipse([cx - s, cy - s, cx + s, cy + s], fill=(22, 18, 32))
    d.line([(0, base - 60), (w, base - 70)], fill=(30, 25, 40), width=2)
    return im.filter(ImageFilter.GaussianBlur(1.2))


def crt_screen(w, h):
    """A generic side-scrolling game frame on a curved, scan-lined tube."""
    im = Image.new("RGB", (w, h), (90, 150, 250))
    d = ImageDraw.Draw(im)
    vgrad(d, (0, 0, w, h), (70, 130, 250), (150, 200, 255))
    for i in range(6):
        x = i * 80 - 30
        d.ellipse([x, 150, x + 130, 280], fill=(60, 170, 80))
    for i in range(3):
        x = 40 + i * 120
        d.ellipse([x, 30, x + 60, 52], fill=(250, 250, 250))
        d.ellipse([x + 20, 20, x + 70, 48], fill=(250, 250, 250))
    for x in range(0, w, 20):
        d.rectangle([x, 220, x + 19, h], fill=(190, 110, 60), outline=(110, 60, 30))
    for x in range(200, 300, 20):
        d.rectangle([x, 140, x + 19, 159], fill=(230, 170, 60), outline=(120, 70, 20))
    for x in (80, 110, 140):
        d.ellipse([x, 120, x + 12, 132], fill=(255, 210, 40))
    d.rectangle([150, 184, 170, 219], fill=(230, 60, 60))
    d.rectangle([152, 170, 168, 186], fill=(250, 200, 160))
    d.rectangle([300, 196, 324, 219], fill=(140, 70, 180))
    d.text((12, 8), "SCORE 004250", fill=(255, 255, 255), font=font(18, "mono"))
    d.text((w - 90, 8), "x 3", fill=(255, 255, 255), font=font(18, "mono"))
    for y in range(0, h, 3):
        d.line([(0, y), (w, y)], fill=(0, 0, 0), width=1)
    im = Image.blend(im, Image.new("RGB", (w, h), (0, 0, 0)), 0.15)
    # Vignette like a curved tube.
    vig = Image.new("L", (w, h), 0)
    vd = ImageDraw.Draw(vig)
    vd.rounded_rectangle([8, 8, w - 8, h - 8], radius=40, fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(18))
    return Image.composite(im, Image.new("RGB", (w, h), (12, 16, 14)), vig)


def tv_bezel(w, h):
    """Faux-wood-grain panel for the TV's sides (vinyl woodgrain)."""
    im = Image.new("RGB", (w, h), (120, 78, 45))
    d = ImageDraw.Draw(im)
    for y in range(h):
        k = 0.5 + 0.5 * math.sin(y * 0.35 + math.sin(y * 0.05) * 3)
        d.line([(0, y), (w, y)], fill=(int(100 + 40 * k), int(62 + 26 * k), int(35 + 14 * k)))
    return im


def border(w, h):
    """A wallpaper border strip (repeats seamlessly along its length): ribbons and diamonds."""
    im = Image.new("RGB", (w, h), (238, 226, 205))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w, 6], fill=(90, 140, 160))
    d.rectangle([0, h - 7, w, h], fill=(90, 140, 160))
    n = 5
    step = w / n
    for i in range(n):
        x = i * step
        d.polygon([(x + step * 0.5, 14), (x + step * 0.5 + 18, h / 2), (x + step * 0.5, h - 14), (x + step * 0.5 - 18, h / 2)], fill=(215, 110, 130))
        pts = [(x + t, h / 2 + 12 * math.sin(t / step * math.tau)) for t in range(0, int(step) + 1, 4)]
        d.line(pts, fill=(80, 150, 150), width=4)
        d.ellipse([x + 8, h / 2 - 5, x + 18, h / 2 + 5], fill=(240, 190, 80))
    return fade(im, 0.1)


def cassette_labels(w, h):
    """A strip of four cassette labels: handwritten mixtape titles on striped cards."""
    im = Image.new("RGB", (w, h), (240, 235, 220))
    d = ImageDraw.Draw(im)
    stripes = [(230, 70, 60), (250, 170, 40), (60, 150, 200), (80, 180, 110)]
    cw = w // 4
    for k in range(4):
        x = k * cw
        d.rectangle([x, 0, x + cw - 2, h], fill=(242, 238, 225))
        d.rectangle([x, h - 26, x + cw - 2, h - 18], fill=stripes[k])
        d.rectangle([x + 20, 34, x + cw - 22, 50], fill=(40, 40, 45))
        d.ellipse([x + 26, 36, x + 38, 48], fill=(230, 230, 230))
        d.ellipse([x + cw - 40, 36, x + cw - 28, 48], fill=(230, 230, 230))
        d.text((x + 6, 4), ["MIX #3", "summer", "radio", "road trip"][k], fill=(30, 30, 90), font=font(20))
    return im


def clock_digits(w, h):
    im = Image.new("RGB", (w, h), (12, 8, 8))
    d = ImageDraw.Draw(im)
    d.text((14, 2), "7:42", fill=(255, 45, 30), font=font(54, "mono"))
    return im.filter(ImageFilter.GaussianBlur(0.7))


def stickers(w, h):
    """Eight round stickers (4 x 2): star, heart, rainbow, bolt, smile, planet, A+, dino."""
    im = Image.new("RGB", (w, h), (250, 250, 248))
    d = ImageDraw.Draw(im)
    s = w // 4
    bgs = [(255, 220, 60), (250, 120, 170), (120, 200, 250), (40, 40, 60), (255, 230, 80), (150, 90, 220), (250, 250, 245), (110, 210, 120)]
    for i in range(8):
        cx, cy = (i % 4) * s + s // 2, (i // 4) * s + s // 2
        r = s // 2 - 4
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=bgs[i])
        if i == 0:
            pts = [(cx + math.cos(a * math.pi / 5 - math.pi / 2) * (r * 0.8 if a % 2 == 0 else r * 0.35),
                    cy + math.sin(a * math.pi / 5 - math.pi / 2) * (r * 0.8 if a % 2 == 0 else r * 0.35)) for a in range(10)]
            d.polygon(pts, fill=(250, 120, 40))
        elif i == 1:
            d.ellipse([cx - 22, cy - 18, cx, cy + 4], fill=(230, 30, 60))
            d.ellipse([cx, cy - 18, cx + 22, cy + 4], fill=(230, 30, 60))
            d.polygon([(cx - 21, cy - 2), (cx + 21, cy - 2), (cx, cy + 24)], fill=(230, 30, 60))
        elif i == 2:
            for k, c in enumerate([(230, 50, 50), (250, 160, 30), (250, 230, 50), (60, 180, 80), (60, 110, 220)]):
                rr = 32 - k * 5
                d.arc([cx - rr, cy - rr + 10, cx + rr, cy + rr + 10], 180, 360, fill=c, width=5)
        elif i == 3:
            d.polygon([(cx + 6, cy - 30), (cx - 16, cy + 4), (cx, cy + 4), (cx - 8, cy + 30), (cx + 18, cy - 6), (cx + 2, cy - 6)], fill=(255, 220, 40))
        elif i == 4:
            d.ellipse([cx - 12, cy - 14, cx - 4, cy - 2], fill=(30, 30, 30))
            d.ellipse([cx + 4, cy - 14, cx + 12, cy - 2], fill=(30, 30, 30))
            d.arc([cx - 22, cy - 18, cx + 22, cy + 22], 20, 160, fill=(30, 30, 30), width=4)
        elif i == 5:
            d.ellipse([cx - 18, cy - 18, cx + 18, cy + 18], fill=(250, 180, 80))
            d.arc([cx - 34, cy - 10, cx + 34, cy + 10], 0, 360, fill=(250, 240, 200), width=3)
        elif i == 6:
            d.text((cx - 28, cy - 24), "A+", fill=(220, 30, 40), font=font(38, "bold"))
        else:
            d.ellipse([cx - 20, cy - 6, cx + 16, cy + 14], fill=(40, 120, 60))
            d.line([(cx + 10, cy), (cx + 18, cy - 22)], fill=(40, 120, 60), width=8)
            d.ellipse([cx + 12, cy - 30, cx + 28, cy - 18], fill=(40, 120, 60))
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(255, 255, 255), width=4)
    return im


# --- Papers ----------------------------------------------------------------------------------

def note_paper(w, h):
    """Lined notebook paper with aquarium-care reminders and doodles of an axolotl and a fish."""
    im = Image.new("RGB", (w, h), (250, 248, 238))
    d = ImageDraw.Draw(im)
    for y in range(40, h, 18):
        d.line([(0, y), (w, y)], fill=(170, 195, 230), width=1)
    d.line([(30, 0), (30, h)], fill=(230, 140, 140), width=2)
    for y in (50, 140, 230):
        d.ellipse([8, y, 18, y + 10], fill=(215, 215, 205))
    f = font(17)
    for i, t in enumerate(["feed Gill - a pinch!", "water change sat", "check filter", "no tapping glass!!"]):
        d.text((38, 24 + i * 36), t, fill=(40, 50, 120), font=f)
    ox, oy = 80, 205
    d.ellipse([ox, oy, ox + 80, oy + 34], outline=(60, 60, 70), width=3)
    d.line([(ox + 78, oy + 17), (ox + 120, oy + 10), (ox + 118, oy + 26), (ox + 78, oy + 20)], fill=(60, 60, 70), width=3)
    for g in range(3):
        d.line([(ox + 6, oy + 6 + g * 10), (ox - 14, oy - 2 + g * 12)], fill=(210, 90, 120), width=3)
    d.ellipse([ox + 14, oy + 10, ox + 20, oy + 16], fill=(20, 20, 20))
    d.text((140, 250), ":)", fill=(40, 50, 120), font=font(18))
    return im


def homework(w, h):
    im = Image.new("RGB", (w, h), (247, 246, 240))
    d = ImageDraw.Draw(im)
    for y in range(34, h, 16):
        d.line([(0, y), (w, y)], fill=(185, 205, 230), width=1)
    f = font(14)
    for i in range(14):
        n1, n2 = R.randrange(12, 99), R.randrange(2, 9)
        d.text((14, 20 + i * 19), f"{i + 1}.  {n1} x {n2} = {n1 * n2 if R.random() < 0.7 else ''}", fill=(55, 55, 70), font=f)
    d.text((150, 6), "B+", fill=(210, 40, 40), font=font(30))
    d.ellipse([140, 2, 200, 44], outline=(210, 40, 40), width=2)
    return im


def calendar(w, h):
    """A wall calendar: a picture of a lake on top, a month grid below with days crossed off."""
    im = Image.new("RGB", (w, h), (248, 246, 240))
    d = ImageDraw.Draw(im)
    vgrad(d, (8, 8, w - 8, 130), (120, 170, 220), (200, 220, 235))
    d.polygon([(8, 110), (70, 60), (120, 100), (170, 50), (w - 8, 100), (w - 8, 130), (8, 130)], fill=(70, 110, 90))
    d.rectangle([8, 116, w - 8, 130], fill=(80, 130, 180))
    d.text((40, 136), "SEPTEMBER", fill=(180, 40, 40), font=font(22, "bold"))
    cw, ch = (w - 16) / 7, 22
    for r in range(5):
        for c in range(7):
            x, y = 8 + c * cw, 170 + r * ch
            d.rectangle([x, y, x + cw, y + ch], outline=(170, 170, 170))
            n = r * 7 + c - 2
            if 1 <= n <= 30:
                d.text((x + 3, y + 2), str(n), fill=(60, 60, 70), font=font(11, "bold"))
                if n < 18:
                    d.line([(x + 3, y + 3), (x + cw - 3, y + ch - 3)], fill=(220, 40, 40), width=2)
                    d.line([(x + cw - 3, y + 3), (x + 3, y + ch - 3)], fill=(220, 40, 40), width=2)
    d.ellipse([8 + 5 * cw - 2, 170 + 3 * ch - 2, 8 + 6 * cw + 2, 170 + 4 * ch + 2], outline=(40, 80, 200), width=2)
    return im


def drawing(w, h):
    """A crayon drawing of the axolotl in its tank (the kid's own)."""
    im = Image.new("RGB", (w, h), (252, 250, 244))
    d = ImageDraw.Draw(im)
    for k in range(30):
        y = 30 + R.randrange(h - 40)
        d.line([(10, y), (w - 10, y + R.randrange(-3, 4))], fill=(120, 180, 240), width=3)
    d.rectangle([10, 20, w - 10, h - 10], outline=(40, 40, 40), width=3)
    d.ellipse([60, 70, 160, 115], fill=(250, 150, 180), outline=(200, 70, 110), width=3)
    d.line([(158, 92), (200, 80)], fill=(200, 70, 110), width=5)
    for g in range(3):
        d.line([(70, 80 + g * 10), (40, 60 + g * 16)], fill=(220, 60, 90), width=4)
    d.ellipse([80, 82, 88, 90], fill=(20, 20, 20))
    for x in range(20, w - 20, 16):
        d.ellipse([x, h - 30, x + 12, h - 18], fill=R.choice([(150, 120, 90), (200, 180, 120), (110, 110, 110)]))
    d.text((20, 26), "GILL", fill=(60, 140, 60), font=font(26, "bold"))
    return im


def notebook(w, h):
    """A black-and-white marbled composition-book cover with a label box."""
    im = Image.new("L", (w, h), 0)
    px = im.load()
    for y in range(h):
        for x in range(w):
            v = math.sin(x * 0.09 + math.sin(y * 0.07) * 3 + math.sin((x + y) * 0.03) * 4)
            px[x, y] = 235 if v > 0.55 else 20
    im = im.convert("RGB")
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 18, h], fill=(20, 20, 20))
    d.rectangle([50, 40, w - 40, 100], fill=(250, 250, 245), outline=(20, 20, 20), width=2)
    d.text((58, 48), "SCIENCE", fill=(40, 40, 120), font=font(22))
    d.text((58, 74), "period 3", fill=(40, 40, 120), font=font(16))
    return im


def cork(w, h):
    im = Image.new("RGB", (w, h))
    px = im.load()
    for y in range(h):
        for x in range(w):
            k = R.random()
            px[x, y] = (int(150 + 55 * k), int(105 + 38 * k), int(60 + 26 * k))
    im = im.filter(ImageFilter.GaussianBlur(0.7))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, w - 1, h - 1], outline=(150, 105, 60), width=8)
    return im


# --- Covers, labels and spines ---------------------------------------------------------------

def comics(w, h):
    """Six generic comic-book covers: a title block, a burst, bold colour fields (no characters)."""
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    cw = w // 6
    titles = ["ZAP!", "COSMIC", "MEGA", "TURBO", "ROBO", "GALAXY"]
    bgs = [(230, 60, 50), (60, 90, 200), (250, 190, 40), (50, 160, 90), (150, 70, 180), (30, 30, 40)]
    for k in range(6):
        x = k * cw
        vgrad(d, (x, 0, x + cw - 4, h), bgs[k], tuple(int(c * 0.55) for c in bgs[k]))
        d.rectangle([x, 0, x + cw - 4, 38], fill=(250, 245, 230))
        d.text((x + 6, 4), titles[k], fill=bgs[(k + 2) % 6], font=font(26, "boldi"))
        cx, cy = x + cw // 2, 110
        pts = [(cx + math.cos(a * math.pi / 8) * (44 if a % 2 == 0 else 22), cy + math.sin(a * math.pi / 8) * (44 if a % 2 == 0 else 22)) for a in range(16)]
        d.polygon(pts, fill=(255, 240, 80))
        d.polygon([(cx - 30, h - 10), (cx - 8, cy + 10), (cx + 30, h - 10)], fill=tuple(int(c * 0.3) for c in bgs[k]))
        d.rectangle([x + 4, 42, x + 26, 60], fill=(255, 255, 255))
        d.text((x + 6, 44), "75c", fill=(0, 0, 0), font=font(11, "bold"))
    return fade(im, 0.06)


def magazines(w, h):
    """Four generic magazine covers: masthead, a colour 'photo', coverlines."""
    im = Image.new("RGB", (w, h), (240, 240, 235))
    d = ImageDraw.Draw(im)
    cw = w // 4
    heads = ["GAME ZONE", "SKATE", "SCIENCE KID", "SOUND"]
    cols = [(220, 40, 40), (30, 30, 30), (40, 110, 200), (230, 120, 20)]
    for k in range(4):
        x = k * cw
        vgrad(d, (x + 4, 36, x + cw - 6, h - 4), R.choice([(120, 180, 230), (250, 200, 120), (140, 220, 160)]), R.choice([(60, 60, 120), (200, 80, 90), (40, 90, 60)]))
        d.ellipse([x + 30, 70, x + cw - 30, 150], fill=tuple(int(c * 0.8) for c in cols[k]))
        d.rectangle([x + 2, 0, x + cw - 4, 34], fill=cols[k])
        d.text((x + 6, 6), heads[k], fill=(255, 255, 255), font=font(18 if len(heads[k]) > 6 else 24, "bold"))
        for j in range(3):
            d.rectangle([x + 10, 150 + j * 10, x + 10 + R.randrange(40, cw - 30), 155 + j * 10], fill=(255, 255, 255))
    return im


def carts(w, h):
    """Four game-cartridge label pictures (2 x 2), generic: a racer, a castle, a rocket, a maze."""
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    cw, ch = w // 2, h // 2
    for k in range(4):
        x, y = (k % 2) * cw, (k // 2) * ch
        vgrad(d, (x, y, x + cw - 2, y + ch - 2), [(40, 40, 120), (120, 30, 50), (10, 10, 40), (30, 100, 60)][k], [(250, 120, 60), (250, 200, 80), (80, 60, 160), (180, 240, 120)][k])
        if k == 0:
            d.polygon([(x + 16, y + 50), (x + 80, y + 50), (x + 70, y + 36), (x + 30, y + 36)], fill=(230, 40, 40))
        elif k == 1:
            for t in range(3):
                d.rectangle([x + 20 + t * 22, y + 28 - (t % 2) * 10, x + 36 + t * 22, y + 60], fill=(60, 60, 80))
        elif k == 2:
            d.polygon([(x + 48, y + 10), (x + 60, y + 50), (x + 36, y + 50)], fill=(240, 240, 240))
        else:
            for t in range(4):
                d.line([(x + 10, y + 12 + t * 14), (x + 80, y + 12 + t * 14)], fill=(250, 250, 80), width=3)
        d.rectangle([x, y + ch - 16, x + cw - 2, y + ch - 2], fill=(20, 20, 20))
        d.text((x + 4, y + ch - 16), ["RACE", "QUEST", "BLAST", "MAZE"][k], fill=(255, 255, 255), font=font(11, "bold"))
    return im


def spines(w, h):
    """Book spines side by side (20), white-ish art tinted per book by vertex colour: bands, titles, a
    publisher mark; each column is one spine."""
    im = Image.new("RGB", (w, h), (235, 235, 235))
    d = ImageDraw.Draw(im)
    n = 20
    sw = w // n
    for k in range(n):
        x = k * sw
        base = R.choice([(235, 235, 235), (215, 215, 215), (245, 240, 225)])
        d.rectangle([x, 0, x + sw - 1, h], fill=base)
        style = k % 5
        if style == 0:
            d.rectangle([x, 14, x + sw - 1, 22], fill=(250, 210, 80))
            d.rectangle([x, h - 26, x + sw - 1, h - 18], fill=(250, 210, 80))
        elif style == 1:
            d.rectangle([x, 30, x + sw - 1, 90], fill=(60, 60, 60))
        elif style == 2:
            for j in range(3):
                d.line([(x, 20 + j * 8), (x + sw, 20 + j * 8)], fill=(120, 90, 40), width=2)
        elif style == 3:
            d.rectangle([x + 3, 20, x + sw - 4, h - 40], outline=(255, 255, 255), width=2)
        else:
            d.ellipse([x + 4, h - 34, x + sw - 5, h - 34 + sw - 9], fill=(40, 40, 40))
        # A title: short strokes down the spine.
        y = 40 + R.randrange(30)
        for j in range(R.randrange(4, 9)):
            d.rectangle([x + sw // 2 - 4, y, x + sw // 2 + 4, y + R.randrange(6, 12)], fill=(30, 30, 30) if style != 1 else (250, 250, 250))
            y += 15
    return im


def rug(w, h):
    """A braided oval rug: concentric rings of twisted strands in warm browns, rust, cream and blue.
    Outside the oval is the floor colour (the rug mesh is an oval, this only pads the corners)."""
    im = Image.new("RGB", (w, h))
    px = im.load()
    cols = [(150, 80, 50), (210, 180, 130), (90, 60, 45), (180, 110, 60), (90, 110, 140), (200, 150, 100)]
    for y in range(h):
        for x in range(w):
            u, v = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
            r = math.sqrt(u * u + v * v)
            ring = int(r * 16)
            a = math.atan2(v, u)
            braid = 0.72 + 0.28 * math.sin(a * 90 * max(r, 0.2) + ring * 2.0)
            c = cols[ring % len(cols)] if r <= 1.0 else cols[15 % len(cols)]
            px[x, y] = tuple(int(ch * braid) for ch in c)
    return im


def boardgame(w, h):
    im = Image.new("RGB", (w, h), (30, 90, 170))
    d = ImageDraw.Draw(im)
    for k in range(6):
        d.rectangle([k * 34, 0, k * 34 + 16, h], fill=(250, 200, 40))
    d.rectangle([20, 20, w - 20, h - 20], fill=(240, 60, 60))
    d.text((32, 30), "BOARD GAME", fill=(255, 255, 255), font=font(20, "bold"))
    return im


def pennant(w, h):
    im = Image.new("RGB", (w, h), (40, 60, 140))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 24, h], fill=(250, 250, 245))
    d.text((40, 22), "CAMP PINE LAKE", fill=(250, 210, 60), font=font(28, "bold"))
    return im


# --- Tiles -----------------------------------------------------------------------------------

def wallpaper():
    """Faded cream paper with dusty pinstripes and scattered little sprigs (seamless)."""
    n = 512
    im = Image.new("RGB", (n, n), (236, 226, 204))
    d = ImageDraw.Draw(im)
    for x in range(0, n, 64):
        d.rectangle([x, 0, x + 3, n], fill=(206, 170, 170))
        d.rectangle([x + 10, 0, x + 11, n], fill=(160, 180, 190))
    for x in range(32, n, 64):
        for y in range(0, n, 64):
            yy = y + (32 if (x // 64) % 2 else 0)
            d.line([(x, yy + 6), (x, yy - 6)], fill=(130, 150, 120), width=2)
            d.ellipse([x - 5, yy - 10, x + 1, yy - 4], fill=(200, 120, 130))
            d.ellipse([x - 1, yy - 12, x + 5, yy - 6], fill=(210, 140, 140))
            d.ellipse([x - 7, yy - 2, x - 2, yy + 3], fill=(140, 160, 120))
    rr = random.Random(7)
    px = im.load()
    for y in range(n):
        for x in range(n):
            e = rr.randint(-6, 6)
            c = px[x, y]
            px[x, y] = (c[0] + e, c[1] + e, c[2] + e)
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    save(im, "wallpaper.png")


def blanket():
    """A tiling comforter print: bold triangles, squiggles and confetti on navy (seamless)."""
    n = 512
    im = Image.new("RGB", (n, n), (34, 44, 96))
    d = ImageDraw.Draw(im)
    cols = [(235, 70, 110), (40, 190, 180), (250, 200, 50), (240, 240, 235), (150, 100, 220)]
    rr = random.Random(11)
    shapes = []
    for _ in range(60):
        shapes.append((rr.randrange(n), rr.randrange(n), rr.randrange(3), rr.choice(cols), rr.randrange(24, 60), rr.random() * math.tau))
    for ox in (-n, 0, n):
        for oy in (-n, 0, n):
            for (x, y, kind, c, s, a) in shapes:
                x, y = x + ox, y + oy
                if kind == 0:
                    d.polygon([(x + math.cos(a + t * 2.094) * s, y + math.sin(a + t * 2.094) * s) for t in range(3)], fill=c)
                elif kind == 1:
                    pts = [(x + t * 5 * math.cos(a) - 10 * math.sin(t * 0.7) * math.sin(a), y + t * 5 * math.sin(a) + 10 * math.sin(t * 0.7) * math.cos(a)) for t in range(14)]
                    d.line(pts, fill=c, width=7)
                else:
                    d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=c)
    # Quilting lines.
    for k in range(0, n, 128):
        d.line([(k, 0), (k, n)], fill=(24, 30, 70), width=3)
        d.line([(0, k), (n, k)], fill=(24, 30, 70), width=3)
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    save(im, "blanket.png")


def wood():
    """Pale planks (four across) with grain, knots and dark seams, seamless: tinted per piece."""
    n = 512
    im = Image.new("RGB", (n, n))
    px = im.load()
    rr = random.Random(5)
    planks = 4
    pw = n // planks
    offs = [rr.random() * 100 for _ in range(planks)]
    tones = [rr.uniform(0.9, 1.08) for _ in range(planks)]
    knots = [(rr.randrange(n), rr.randrange(n)) for _ in range(5)]
    for y in range(n):
        for x in range(n):
            p = x // pw
            lx = x - p * pw
            yy = y / n * math.tau
            g = math.sin(lx * 0.25 + offs[p] + 2.2 * math.sin(yy * 2 + offs[p]) + 0.8 * math.sin(yy * 5 + p)) * 0.5 + 0.5
            g2 = math.sin(lx * 1.3 + offs[p] * 3 + math.sin(yy * 3) * 4) * 0.5 + 0.5
            v = 0.78 + 0.13 * g + 0.06 * g2
            for kx, ky in knots:
                dx, dy = x - kx, (y - ky + n // 2) % n - n // 2
                dd = dx * dx * 4 + dy * dy
                if dd < 400:
                    v *= 0.8 + 0.2 * dd / 400
            v *= tones[p]
            if lx < 2 or lx > pw - 2:
                v *= 0.45
            px[x, y] = (int(min(255, 235 * v)), int(min(255, 225 * v)), int(min(255, 210 * v)))
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    save(im, "wood.png")


def fabric():
    """A soft weave (seamless, near-white): multiplied onto clothes, sheets and cushions."""
    n = 256
    im = Image.new("L", (n, n))
    px = im.load()
    rr = random.Random(3)
    for y in range(n):
        for x in range(n):
            w = (math.sin(x * math.pi / 2) * 0.5 + 0.5) * (0.5 + 0.5 * math.sin(y * math.pi / 4))
            px[x, y] = int(215 + 25 * w + rr.randint(-8, 8))
    im = im.filter(ImageFilter.GaussianBlur(0.6)).convert("RGB")
    save(im, "fabric.png")


def atlas():
    im = Image.new("RGB", (2048, 1024), (128, 128, 128))
    makers = {
        "white": lambda w, h: Image.new("RGB", (w, h), (255, 255, 255)),
        "poster_space": poster_space, "poster_shapes": poster_shapes, "poster_sunset": poster_sunset,
        "window": window_view, "crt": crt_screen, "border": border, "cassette": cassette_labels,
        "clock": clock_digits, "stickers": stickers, "note_paper": note_paper, "homework": homework,
        "calendar": calendar, "drawing": drawing, "notebook": notebook, "cork": cork, "comics": comics,
        "magazines": magazines, "carts": carts, "spines": spines, "rug": rug, "boardgame": boardgame,
        "pennant": pennant, "tv_bezel": tv_bezel,
    }
    for key, (x, y, w, h) in ATLAS.items():
        part = makers[key](w, h).convert("RGB")
        # Bleed the edge pixels a few texels out, so mipmaps do not pull in the neighbours.
        pad = 4
        big = part.resize((w + pad * 2, h + pad * 2), Image.NEAREST)
        big.paste(part, (pad, pad))
        im.paste(big.crop((max(0, pad - x), max(0, pad - y), w + pad * 2, h + pad * 2)), (max(0, x - pad), max(0, y - pad)))
        im.paste(part, (x, y))
    save(im, "atlas.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    atlas()
    wallpaper()
    blanket()
    wood()
    fabric()
    print("room textures written")


if __name__ == "__main__":
    main()

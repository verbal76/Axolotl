#!/usr/bin/env python3
"""Generates the bedroom's printed and patterned surfaces (docs/AQUARIUM.md) into
assets/textures/room: original, generic late-1980s / early-1990s kid's-room designs (no brands,
characters or logos). Deterministic. Run from the repository root:  python3 tools/gen_room.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures", "room")
HAND = "/usr/share/fonts/truetype/freefont/FreeSansOblique.ttf"
R = random.Random(1989)


def font(size):
    try:
        return ImageFont.truetype(HAND, size)
    except OSError:
        return ImageFont.load_default()


def save(im, name):
    im.save(os.path.join(OUT, name), optimize=True)


def poster_space():
    """A starfield with a ringed planet and a crescent moon: a glow-in-the-dark style space poster."""
    w, h = 384, 512
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        k = y / h
        d.line([(0, y), (w, y)], fill=(int(12 + 30 * k), int(10 + 18 * k), int(48 + 60 * (1 - k))))
    for _ in range(260):
        x, y, s = R.randrange(w), R.randrange(h), R.choice([1, 1, 1, 2, 2, 3])
        c = R.choice([(255, 255, 240), (200, 220, 255), (255, 230, 180)])
        d.ellipse([x, y, x + s, y + s], fill=c)
    # Planet with rings.
    cx, cy, r = 210, 250, 92
    d.ellipse([cx - 150, cy - 26, cx + 150, cy + 26], outline=(230, 180, 120), width=6)
    for i in range(r, 0, -1):
        k = i / r
        d.ellipse([cx - i, cy - i, cx + i, cy + i], fill=(int(220 - 90 * k), int(120 - 50 * k), int(80 - 30 * k)))
    for band in (-40, -8, 26, 55):
        d.arc([cx - r, cy - r + band, cx + r, cy + r + band], 200, 340, fill=(160, 80, 60), width=5)
    d.arc([cx - 150, cy - 26, cx + 150, cy + 26], 0, 180, fill=(240, 200, 140), width=6)
    # Crescent moon.
    d.ellipse([46, 60, 126, 140], fill=(240, 240, 210))
    d.ellipse([66, 52, 146, 132], fill=(22, 18, 70))
    # A comet.
    for i in range(40):
        d.ellipse([290 + i * 1.6, 90 + i * 0.9, 294 + i * 1.6, 94 + i * 0.9], fill=(255, 255, 230 - i * 4))
    # A white border like a printed poster.
    d.rectangle([0, 0, w - 1, h - 1], outline=(235, 235, 225), width=10)
    save(im, "poster_space.png")


def poster_shapes():
    """Loud early-90s geometric pattern: squiggles, triangles, dots and zigzags on teal."""
    w, h = 384, 512
    im = Image.new("RGB", (w, h), (32, 170, 165))
    d = ImageDraw.Draw(im)
    cols = [(250, 90, 150), (255, 210, 40), (40, 40, 60), (250, 250, 245), (150, 90, 220)]
    for _ in range(46):
        c = R.choice(cols)
        x, y = R.randrange(-20, w), R.randrange(-20, h)
        kind = R.randrange(4)
        if kind == 0:
            s = R.randrange(20, 60)
            d.polygon([(x, y), (x + s, y + s // 3), (x + s // 3, y + s)], fill=c)
        elif kind == 1:
            s = R.randrange(6, 16)
            d.ellipse([x, y, x + s, y + s], fill=c)
        elif kind == 2:
            pts = [(x + i * 8, y + (10 if i % 2 else 0)) for i in range(8)]
            d.line(pts, fill=c, width=5)
        else:
            pts = [(x + i * 4, y + 12 * math.sin(i * 0.6)) for i in range(18)]
            d.line(pts, fill=c, width=6)
    d.rectangle([0, 0, w - 1, h - 1], outline=(250, 250, 245), width=10)
    save(im, "poster_shapes.png")


def blanket():
    """A tiling comforter pattern: bold diagonal bands and triangles in brights on navy."""
    n = 256
    im = Image.new("RGB", (n, n), (30, 40, 90))
    d = ImageDraw.Draw(im)
    cols = [(235, 70, 110), (40, 190, 180), (250, 200, 50), (240, 240, 235)]
    for i in range(-n, n * 2, 64):
        d.polygon([(i, 0), (i + 32, 0), (i + 32 + n, n), (i + n, n)], fill=cols[(i // 64) % 4])
    for x in range(0, n, 64):
        for y in range(0, n, 64):
            d.polygon([(x + 8, y + 40), (x + 28, y + 12), (x + 48, y + 40)], fill=(30, 40, 90))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    save(im, "blanket.png")


def rug():
    """A braided oval rug: concentric rings of twisted strands in warm browns, rust and cream."""
    w, h = 384, 256
    im = Image.new("RGB", (w, h), (0, 0, 0))
    px = im.load()
    cols = [(150, 80, 50), (210, 180, 130), (90, 60, 45), (180, 110, 60), (120, 130, 110)]
    for y in range(h):
        for x in range(w):
            u, v = (x - w / 2) / (w / 2), (y - h / 2) / (h / 2)
            r = math.sqrt(u * u + v * v)
            ring = int(r * 14)
            a = math.atan2(v, u)
            braid = 0.75 + 0.25 * math.sin(a * 60 + ring * 2.0)
            c = cols[ring % len(cols)]
            if r > 1.0:
                c = (0, 0, 0)
            px[x, y] = tuple(int(ch * braid) for ch in c)
    im.putalpha(Image.eval(im.convert("L"), lambda p: 255 if p > 0 else 0))
    save(im, "rug.png")


def cork():
    n = 256
    im = Image.new("RGB", (n, n))
    px = im.load()
    for y in range(n):
        for x in range(n):
            k = R.random()
            px[x, y] = (int(150 + 50 * k), int(105 + 35 * k), int(60 + 25 * k))
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    save(im, "cork.png")


def note_paper():
    """Lined notebook paper with aquarium-care reminders and doodles of an axolotl and a fish."""
    w, h = 256, 320
    im = Image.new("RGB", (w, h), (250, 248, 238))
    d = ImageDraw.Draw(im)
    for y in range(40, h, 18):
        d.line([(0, y), (w, y)], fill=(170, 195, 230), width=1)
    d.line([(34, 0), (34, h)], fill=(230, 140, 140), width=2)
    for y in (60, 150, 240):
        d.ellipse([10, y, 20, y + 10], fill=(215, 215, 205))
    f = font(19)
    lines = ["feed Gill - a pinch!", "water change sat", "check filter", "no tapping the glass"]
    for i, t in enumerate(lines):
        d.text((44, 26 + i * 36), t, fill=(40, 50, 120), font=f)
    # Doodle: an axolotl with feathery gills, and a little fish.
    ox, oy = 90, 240
    d.ellipse([ox, oy, ox + 80, oy + 34], outline=(60, 60, 70), width=3)
    d.line([(ox + 78, oy + 17), (ox + 120, oy + 10), (ox + 118, oy + 26), (ox + 78, oy + 20)], fill=(60, 60, 70), width=3)
    for g in range(3):
        d.line([(ox + 6, oy + 6 + g * 10), (ox - 14, oy - 2 + g * 12)], fill=(210, 90, 120), width=3)
    d.ellipse([ox + 14, oy + 10, ox + 20, oy + 16], fill=(20, 20, 20))
    d.arc([ox + 12, oy + 16, ox + 30, oy + 28], 20, 160, fill=(60, 60, 70), width=2)
    fx, fy = 190, 190
    d.ellipse([fx, fy, fx + 36, fy + 18], outline=(40, 110, 160), width=3)
    d.polygon([(fx + 34, fy + 9), (fx + 50, fy), (fx + 50, fy + 18)], outline=(40, 110, 160))
    d.text((150, 285), ":)", fill=(40, 50, 120), font=font(18))
    save(im, "note_paper.png")


def homework():
    w, h = 256, 330
    im = Image.new("RGB", (w, h), (247, 246, 240))
    d = ImageDraw.Draw(im)
    for y in range(34, h, 16):
        d.line([(0, y), (w, y)], fill=(185, 205, 230), width=1)
    f = font(15)
    for i in range(14):
        n1, n2 = R.randrange(12, 99), R.randrange(2, 9)
        d.text((16, 20 + i * 21), f"{i + 1}.  {n1} x {n2} =", fill=(55, 55, 70), font=f)
    d.text((170, 8), "B+", fill=(210, 40, 40), font=font(28))
    save(im, "homework.png")


def crt_screen():
    """A generic side-scrolling game frame: sky, hills, blocky ground, a little hero and a coin row."""
    w, h = 256, 192
    im = Image.new("RGB", (w, h), (90, 150, 250))
    d = ImageDraw.Draw(im)
    for i in range(5):
        x = i * 70 - 20
        d.ellipse([x, 110, x + 110, 210], fill=(60, 170, 80))
    for x in range(0, w, 16):
        d.rectangle([x, 160, x + 15, 191], fill=(180, 110, 60), outline=(110, 60, 30))
    for x in (60, 90, 120):
        d.ellipse([x, 90, x + 10, 100], fill=(255, 210, 40))
    d.rectangle([150, 128, 166, 159], fill=(230, 60, 60))
    d.rectangle([152, 118, 164, 130], fill=(250, 200, 160))
    for y in range(0, h, 2):
        d.line([(0, y), (w, y)], fill=(0, 0, 0), width=1)
    im = Image.blend(im, Image.new("RGB", (w, h), (0, 0, 0)), 0.18)
    save(im, "crt_screen.png")


def cassette_labels():
    """A strip of cassette labels (handwritten mixtape titles on striped cards)."""
    w, h = 256, 128
    im = Image.new("RGB", (w, h), (240, 235, 220))
    d = ImageDraw.Draw(im)
    stripes = [(230, 70, 60), (250, 170, 40), (60, 150, 200), (80, 180, 110)]
    for k in range(4):
        y = k * 32
        d.rectangle([0, y, w, y + 31], fill=(242, 238, 225))
        d.rectangle([0, y + 22, w, y + 26], fill=stripes[k])
        d.text((8, y + 3), ["MIX #3", "summer tape", "radio stuff", "road trip"][k], fill=(30, 30, 60), font=font(15))
    save(im, "cassette_labels.png")


def wallpaper():
    """Faded wallpaper: soft vertical stripes with a tiny pattern."""
    n = 256
    im = Image.new("RGB", (n, n), (206, 214, 222))
    d = ImageDraw.Draw(im)
    for x in range(0, n, 32):
        d.rectangle([x, 0, x + 12, n], fill=(196, 206, 216))
    for x in range(22, n, 32):
        for y in range(8, n, 32):
            d.ellipse([x, y, x + 5, y + 5], fill=(180, 190, 205))
    save(im, "wallpaper.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    poster_space()
    poster_shapes()
    blanket()
    rug()
    cork()
    note_paper()
    homework()
    crt_screen()
    cassette_labels()
    wallpaper()
    print("room textures written")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Generates the game's procedural textures into assets/textures.

All textures are original and produced from seeded noise, so the output is
deterministic. Run from the repository root:  python3 tools/gen_textures.py
"""
import os
import struct
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
rng = np.random.default_rng(7)


def save_png(path, arr):
    """Minimal PNG writer (no Pillow dependency). arr: HxW (gray) or HxWx3/4 uint8."""
    arr = np.ascontiguousarray(arr)
    if arr.ndim == 2:
        color_type, h, w = 0, arr.shape[0], arr.shape[1]
    else:
        h, w, c = arr.shape
        color_type = {3: 2, 4: 6}[c]
    raw = b"".join(b"\x00" + arr[y].tobytes() for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def fbm(n, falloff=1.6, seed=None):
    """Tileable fractal noise via spectral filtering of white noise, normalised to 0..1."""
    r = np.random.default_rng(seed)
    white = r.standard_normal((n, n))
    fx = np.fft.fftfreq(n)[:, None]
    fy = np.fft.fftfreq(n)[None, :]
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    spec = np.fft.fft2(white) / (f ** falloff)
    spec[0, 0] = 0
    out = np.real(np.fft.ifft2(spec))
    out -= out.min()
    out /= out.max()
    return out


def worley(n, count, seed):
    """Tileable cellular noise. Returns (F1, F2, cell index)."""
    r = np.random.default_rng(seed)
    g = int(round(np.sqrt(count)))
    cell = n / g
    gy, gx = np.mgrid[0:g, 0:g]
    jitter = (r.random((g * g, 2)) - 0.5) * 0.7
    pts = (np.stack([gx.ravel(), gy.ravel()], 1) + 0.5 + jitter) * cell
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    f1 = np.full((n, n), 1e9, np.float32)
    f2 = np.full((n, n), 1e9, np.float32)
    idx = np.zeros((n, n), np.int32)
    for i, (px, py) in enumerate(pts):
        dx = np.abs(xx - px)
        dx = np.minimum(dx, n - dx)
        dy = np.abs(yy - py)
        dy = np.minimum(dy, n - dy)
        d = np.sqrt(dx * dx + dy * dy)
        closer = d < f1
        f2 = np.where(closer, f1, np.minimum(f2, d))
        idx = np.where(closer, i, idx)
        f1 = np.where(closer, d, f1)
    return f1, f2, idx


def main():
    os.makedirs(OUT, exist_ok=True)

    # 1. Generic moss/organic noise: R = coarse fbm, G = fine fbm, B = ridged (cracks).
    a = fbm(256, 1.4, 1)
    b = fbm(256, 0.9, 2)
    c = 1.0 - np.abs(fbm(256, 1.8, 3) * 2 - 1)
    save_png(os.path.join(OUT, "noise_rgb.png"), (np.dstack([a, b, c]) * 255).astype(np.uint8))

    # 2. Aquarium gravel: now tools/gen_gravel.py (gravel2_albedo / gravel2_normal).

    # 3. Algae mask for glass: high values survive longest. Corners/edges biased high so a
    #    little healthy algae detail remains at full restoration.
    m = fbm(512, 1.5, 21) * 0.75 + fbm(512, 0.8, 22) * 0.25
    yy, xx = np.mgrid[0:512, 0:512] / 511.0
    edge = np.maximum(np.abs(xx - 0.5), np.abs(yy - 0.5)) * 2.0
    m = np.clip(m * 0.8 + edge ** 4 * 0.35, 0, 1)
    m = (m - m.min()) / (m.max() - m.min())
    save_png(os.path.join(OUT, "algae_mask.png"), (m * 255).astype(np.uint8))

    # 4. Grime/dirt mask for gravel & glass film.
    g = fbm(256, 1.2, 31)
    save_png(os.path.join(OUT, "grime.png"), (g * 255).astype(np.uint8))
    print("textures written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()

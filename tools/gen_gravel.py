#!/usr/bin/env python3
"""Generates the aquarium gravel textures (docs/AQUARIUM.md) into assets/textures:

  gravel2_albedo.png  RGBA: colour of loose natural gravel; A = height (0 fines .. 1 stone tops)
  gravel2_normal.png  RGB:  tangent-space normal from that height

Loose gravel, not paving: thousands of irregular pebbles of mixed sizes painted one over another in
random order (so they overlap and rest on each other), each first dropping a soft contact shadow on
what is under it, with dark fines showing in the crevices. Restrained natural colours (grey, warm
grey, muted tan, brown, charcoal, a few lighter stones). Seamless (everything wraps). Deterministic.
Run from the repository root:  python3 tools/gen_gravel.py
"""
import os

import numpy as np

from gen_textures import save_png, fbm

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
N = 1024
rng = np.random.default_rng(2031)

PALETTE = np.array([
    [128, 126, 120],  # grey
    [140, 130, 116],  # warm grey
    [150, 132, 104],  # muted tan
    [112, 92, 72],    # brown
    [76, 74, 72],     # charcoal
    [98, 96, 92],     # dark grey
    [176, 168, 152],  # lighter stone (rare)
], np.float32)
WEIGHTS = np.array([0.22, 0.2, 0.16, 0.14, 0.12, 0.12, 0.04])


def main():
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    speck = fbm(N, 0.5, 91)
    grain = fbm(N, 0.2, 92)
    # Fines: dark sandy grit between the stones.
    alb = np.dstack([58 + 30 * speck, 54 + 26 * speck, 48 + 22 * speck]).astype(np.float32)
    alb *= (0.85 + 0.3 * grain)[..., None]
    height = 0.05 * speck
    # Pebbles: many small, fewer medium, a few large (sizes in pixels, radius).
    sizes = np.concatenate([rng.uniform(5, 9, 5200), rng.uniform(9, 16, 2200), rng.uniform(16, 26, 420)])
    rng.shuffle(sizes)
    choice = rng.choice(len(PALETTE), size=len(sizes), p=WEIGHTS)
    for i, r in enumerate(sizes):
        cx, cy = rng.uniform(0, N, 2)
        ang = rng.uniform(0, np.pi)
        ax = r * rng.uniform(0.9, 1.35)
        ay = r * rng.uniform(0.6, 0.95)
        lump = rng.uniform(0, 2 * np.pi, 3)
        ext = int(ax * 1.6) + 3
        x0, y0 = int(cx) - ext, int(cy) - ext
        xs = (np.arange(x0, x0 + 2 * ext) % N)
        ys = (np.arange(y0, y0 + 2 * ext) % N)
        gx, gy = np.meshgrid(np.arange(x0, x0 + 2 * ext) - cx, np.arange(y0, y0 + 2 * ext) - cy)
        ca, sa = np.cos(ang), np.sin(ang)
        u = (gx * ca + gy * sa) / ax
        v = (-gx * sa + gy * ca) / ay
        theta = np.arctan2(v, u)
        # An irregular outline: a lumpy ellipse (never a clean oval).
        rim = 1.0 + 0.09 * np.sin(2 * theta + lump[0]) + 0.06 * np.sin(3 * theta + lump[1]) + 0.04 * np.sin(5 * theta + lump[2])
        d = np.sqrt(u * u + v * v) / rim
        # Contact shadow first, on whatever lies beneath (a soft ring just outside the stone).
        # (Offset away from the light, up-left, so it falls on the lower-right side.)
        us = ((gx - r * 0.18) * ca + (gy - r * 0.22) * sa) / ax
        vs = (-(gx - r * 0.18) * sa + (gy - r * 0.22) * ca) / ay
        ds = np.sqrt(us * us + vs * vs) / rim
        sh = np.clip(1.0 - (ds - 0.8) / 0.6, 0, 1) * (d > 0.95)
        sub_a = alb[np.ix_(ys, xs)]
        alb[np.ix_(ys, xs)] = sub_a * (1.0 - 0.3 * sh)[..., None]
        inside = d < 1.0
        if not inside.any():
            continue
        # Its own rounded top: a dome, a little lit from one side, darker toward its buried edge.
        dome = np.sqrt(np.clip(1.0 - d * d, 0, 1))
        top = 0.25 + 0.75 * (r / 26.0)
        h = 0.18 + dome * top
        sub_h = height[np.ix_(ys, xs)]
        # A stone rests on those under it: only where it rises above what is there.
        m = inside & (h > sub_h * 0.85)
        col = PALETTE[choice[i]] * rng.uniform(0.85, 1.12)
        mott = 0.9 + 0.2 * grain[np.ix_(ys, xs)]
        light = (0.55 + 0.45 * dome) * (1.0 + 0.18 * (-(gx * 0.6 + gy * 0.8) / (ax + 1e-3)).clip(-1, 1)) * mott
        edge = np.clip((1.0 - d) / 0.25, 0, 1)
        shade = light * (0.62 + 0.38 * edge)
        new_c = col[None, None, :] * shade[..., None]
        sub_a = alb[np.ix_(ys, xs)]
        sub_a[m] = new_c[m]
        alb[np.ix_(ys, xs)] = sub_a
        sub_h[m] = np.maximum(sub_h[m], h[m])
        height[np.ix_(ys, xs)] = sub_h
    # A little overall height-based occlusion (crevices darker).
    blur = height.copy()
    for s in (1, 2, 4, 8):
        blur = 0.25 * (np.roll(blur, s, 0) + np.roll(blur, -s, 0) + np.roll(blur, s, 1) + np.roll(blur, -s, 1))
    occ = np.clip(1.0 - (blur - height) * 1.4, 0.55, 1.0)
    alb *= occ[..., None]
    hn = (height - height.min()) / (height.max() - height.min() + 1e-6)
    rgba = np.dstack([np.clip(alb, 0, 255), hn * 255]).astype(np.uint8)
    save_png(os.path.join(OUT, "gravel2_albedo.png"), rgba)
    # Normal map from the height (wrapping): x right, y down in the image.
    k = 3.0
    dx = (np.roll(hn, -1, 1) - np.roll(hn, 1, 1)) * k
    dy = (np.roll(hn, -1, 0) - np.roll(hn, 1, 0)) * k
    nz = np.ones_like(hn)
    ln = np.sqrt(dx * dx + dy * dy + nz * nz)
    nrm = np.dstack([-dx / ln, dy / ln, nz / ln]) * 0.5 + 0.5
    save_png(os.path.join(OUT, "gravel2_normal.png"), (nrm * 255).astype(np.uint8))
    print("gravel2 textures written")


if __name__ == "__main__":
    main()

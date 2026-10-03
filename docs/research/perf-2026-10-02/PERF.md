# Mote performance pass (ledger row 28) — 2026-10-02/03

Measure → bottleneck → hypothesis → smallest change → re-measure. Desktop = 4 vCPU Xeon shared with
other work streams; wall-clock frame times swing ±2 ms from their load, so the numbers below use
the main thread's own CPU time (Linux schedstat) or direct timings of the code itself, with medians.
Desktop headless GDScript ≈ phone × 1.1 (startup study). Tooling: `scripts/tests/perf.gd`
(`--test=perf --perf=title|play|probe|render|gamesteps`, `--groups=direct`), not part of the unit suite.

## 1. Where the title frame goes

**Script work behind the title** (headless, `--perf=title --groups=direct`, each node's own
`_process`/`_physics_process` timed by hand; total ≈ 4.5 ms of a 4.7 ms main-thread frame):

| per frame | ms | | per frame | ms |
|---|---|---|---|---|
| parasites (114; only those near him run) | 1.50 | | ambient fish | 0.17 |
| motes (148) | 0.54 | | Gill (axolotl + model) | 0.27 |
| blooms (48, petals + 2 materials each) | 0.53 | | wake + water fx (shader feeds) | 0.26 |
| food (115) | 0.33 | | follow camera | 0.08 |
| vortices (6) | 0.24 | | everything else (HUD, timers, ecosystem, UI, …) | < 0.05 each |

Ecosystem critters already sleep off play; parasites/motes/food on other balls or > 55 m sleep.
The title orbit itself (`Game._process`, dt-based angle + one ray) is frame-rate independent and
costs 0.03 ms: **the orbit is not faulty; it exposes world cost.**

**Render-side work** (xvfb + vulkan/lavapipe, Mobile renderer, `--fixed-fps 60`, 426×240 so the
rasteriser does not dominate). Main-thread CPU on the title is 13.4–14.4 ms vs 4.7 ms headless:
~9–10 ms of it is the renderer's own CPU work (culling, ~500 draws, ~640 objects, ~1.0 M primitives).
One thing switched off at a time (`--perf=render`, 3 on/off pairs from the same orbit point, median):

| off | main-thread CPU saved | draws |
|---|---|---|
| all creatures (parasites, motes, food, critters, blooms) | 2.1–2.5 ms | −126 |
| other balls | 1.5 ms | −110 |
| vegetation | 1.2 ms | −91 (−620 k prims) |
| aquarium room | 1.2 ms | −118 |
| water fx (specks, puffs) | 0.9 ms | −2 |
| sun shadow | 0.7 ms | −47 |
| creatures over their ball's horizon only | 0.9 ms | −33 |
| per-frame shader feeds (wake, water impulses) | ≤ 0.2 ms (noise) | 0 |

Reading for the phone (inferred, not measured there): QualityScaler steps a title that runs < 54 fps down to its lowest level (see §3), and the uncapped title was
still mostly > 25 ms per frame (dev-000059), so fill rate is unlikely to be the limit; script work is ~4–5 ms; the rest is
the renderer's CPU/driver work for ~500 draws and ~1 M primitives (and GPU vertex work). Lavapipe is
not phone-like in absolute terms; use these shares only relatively.

**Unevenness (CPU side).** The slowest headless title frames came every 0.25 s from the horizon cull
(`MossBall.update_visibility`, all 7 balls on one frame), plus a small unattributed engine-level
spike every 8th frame (+0.8–1.3 ms; no script has that cadence).

## 2. Changes kept (each its own commit; behaviour identical)

1. **Horizon cull reads a cached chunk list** (`moss_ball.gd`). Each pass read two metas off ~2,500
   vegetation nodes. The tagged chunks are now gathered once, and again only when the vegetation's
   children change (`child_order_changed`). Same nodes, same rule, same results
   (`perf_veg_cull_same`: 0 of 15,108 chunk states differ, cameras all round every ball; added and
   removed chunks tracked). Probe, whole tank, interleaved medians: **7.07 → 2.68 ms** under load
   (3.7 → ~1.0 ms on a quieter machine).
2. **One ball per frame** (`game.gd`). Every ball is still culled four times a second by the same rule;
   the pass and the visibility changes it sends to the renderer no longer land on one frame: the
   0.25 s spike (1.9 ms whole tank) becomes at most one ball's pass (0.11 ms with nothing changing).

## 3. Found, not changed (need an owner decision, a shader-stream change, or are native)

- **QualityScaler vs the title's 30 fps cap.** When the title caps itself at 30 fps, QualityScaler
  reads 30 < 54 fps as "slow" and steps quality down to the lowest level within ~16 s (scale 0.7,
  no shadows, no glow, 45 % vegetation); back in play it climbs back one level per ≥ 30 s of > 59 fps
  (+20 s cooldowns). Proposed: skip scaler windows while `Game.title_capped` (or judge against
  `Engine.max_fps`). Changes what the owner sees after the title, so not done unasked.
- **Live world behind the title** (~3 ms of the 4.7 ms script frame: parasite AI, motes, blooms,
  food). Sleeping it keeps exact state but freezes the creatures visible round him on the title.
  Design decision.
- **Creatures over the horizon still drawn** (~33 draws, ~0.9 ms render CPU on the title). Their
  `visible` flag is gameplay state (gone/collected/defeated), so culling needs a render-only route
  (layer mask or `RenderingServer.instance_set_visible`), not `visible`.
- **Per-frame shader feeds** write ~140 material parameters a frame (wake 4 × 18 vegetation materials,
  water 3 × 22 field materials, 2 per bloom, 6 per active parasite). Global shader uniforms (row 35
  already registers globals in code) would make these one write each; a shader change, so for the
  shader stream.
- **Physics/render mismatch in play below 60 fps**: Gill moves at 60 Hz physics ticks while frames
  arrive unevenly; `SceneTree.physics_interpolation` can be switched on from script (no native
  change) but needs `reset_physics_interpolation()` on every teleport (respawn, vortex travel,
  resume) and adds up to one tick of latency. Proposal only.
- Game's other per-frame steps in play are all < 0.13 ms (`--perf=gamesteps`); follow camera 0.08 ms;
  leaf/vegetation sway is already on the GPU. Nothing worth changing there.

# Mote startup audit — findings so far (HARD PAUSED by the owner, 2026-10-01)

Research only: no game code changed. Raw logs/scripts lived in the session scratchpad (`startup/`);
the probe patch and batch scripts are kept next to this file. Desktop = 4 vCPU Xeon 2.1 GHz shared
with other sessions (±10 % noise; use medians).

## 1. Phone figures (owner MOTE DIAGNOSTICS, Build 22 r5; existing mid-run save, online; engine ms)

| Phase (delta) | dev-000030 | dev-000041 | dev-000044 (1st launch after its OTA + migration) |
|---|---|---|---|
| engine start → native bootstrap | 445 | 652 | 583 |
| OTA choose/verify/mount | 104 | 56 | 50 |
| → autoload Settings (script load) | 816 | 865 | 918 |
| loading frame | 27 | 31 | 31 |
| environment + audio | 71 | 77 | 68 |
| aquarium | 286 | 284 | 285 |
| balls 1–7 | 6409 | 6128 | 6788 |
| vortices/axolotl/camera/lights | 238 | 257 | 307 |
| food | 90 | 97 | 90 |
| creatures | 605 | 692 | 715 |
| HUD | 125 | 159 | **360** |
| pause menu | 67 | 91 | **374** |
| title | 8 | 10 | 57 |
| "Preparing graphics" + open | 129 | 74 | **1567** |
| run save opened (`_apply_run`) | – | 177 | **333** |
| first title frame | 187 | 180 | **445** |
| **title usable** | **9616** | **9754** | **12996** |
| boot healthy (after usable) | +2844 | +2832 | +2558 |

dev-000041 per ball: 1197 / 858 / 1603 / 508 / 931 / 390 / 641 ms.

## 2. Desktop baselines

A. Headless, fresh user dir, 5 alternating runs per version — median title-usable (range):
dev-000030 9139 (8794–9657); dev-000041 9141 (8982–10537); dev-000044 9975 (9134–10165);
current 58806d2 9303 (9201–9748). Current phases: script load 1694; aquarium 144; balls
1175/863/1790/608/1196/361/891; creatures 108; HUD 2; pause 36; food 36; first frame 48 ms.

B. Headless with a real save (dev-000041 seed-4242 playthrough save, 150 ids), first / second launch:
041 9570 / 9406; 044 9695 / 10252; current 9725 / 9502. The onboarding migration costs ~14 ms.
A real save adds 300–380 ms in `_apply_run` (0.5 ms fresh).

C. Desktop → phone: GDScript-bound work phone ≈ 0.9 × desktop headless; script load 0.87 s phone vs
1.55–1.8 s desktop (binary tokens in the pack); render/UI that headless skips costs more on the
phone (creatures 114 ms vs 692; HUD 2 vs 159; pause 37 vs 91; aquarium 145 vs 284). Rule of thumb:
phone ≈ 0.9 × desktop headless + 0.7–1.0 s render/UI.

D. xvfb + lavapipe (Mobile renderer), cold / warm: HUD 1712 / 298; pause 447 / 117; balls 10.8 / 8.4 s;
"Preparing graphics" 7.1 / 7.6 s; first title frame 67.5 / 2.25 s (lavapipe recompiles pipelines
every launch, so absolute numbers are not phone-like).

## 3. OTA-upgrade experiment (xvfb, one user dir, n=1)

First title frame: 041 empty cache 63.8 s; 041 warm 2.0 s; **044 first launch after "update" 20.4 s**;
044 second 1.9 s; **current first after 044 17.5 s**; current second not run. A release that changes
shared shader includes pays a large one-time pipeline cost. dev-000044 changed
`health_field.gdshaderinc` (moss, plant, vegetation) and `plant.gdshader`, added `variegation`;
the current build changed `health_field` again plus vortex shaders and the new `drag_mark` shader.

## 4. Critical path (probe build, headless, with save)

- Script load/compile: 1.9 s desktop (~0.87 s phone).
- World build ~7.0 s desktop: terrain tiles 1.90 s (~1.03 M `terrain_height` calls, 13×13 per tile,
  borders ~1.4× redundant; concave collision only 0.16 s); vegetation `scatter` 1.41 s (117 calls);
  per-ball layout 557 / 351 / **1509** / 389 / 659 / 195 / 373 ms; sprouts ~0.53 s;
  `finalize_terrain` 445 / 384 / 254 / 214 / 358 / 131 / 222 ms.
- Creatures 0.1 s desktop / 0.6–0.7 s phone. HUD, menus, title 0.04 s desktop / 0.25–0.75 s phone.
- `_open_run`: catalog 3–6 ms, save read 1 ms, food 30–160 ms, `_apply_run` 300–380 ms.
- First title frame 0.18–0.45 s phone warm; seconds after a shader-changing OTA.
- Launch update gate: caps at 8000 ms from the check start (off in tests; unmeasured). Becomes the
  critical path on slow networks once the build is faster.
- Boot healthy: ~2.5–2.8 s after usable (native, APK only).

Dependencies: world build uses the global `randf` (`levels.gd:979-982`, `level_builder.gd:378`), so
build order matters for seeded determinism (player launches call `randomize()`). Catalog,
repopulation, food, Hard Mode and `_apply_run` need every ball. The title's Aquarium (whole-tank view
from every ball's `veg_transforms`), Treasure and the quality scaler need the whole world. Continue
calls `start_play` (no rebuild); **New Run and Return to Title call `reload_current_scene()`: a full
~7–9 s rebuild** (not yet measured end to end).

## 5. Is the 13.0 s launch a regression?

No, on the evidence. Desktop with the same save: 041 ≈ 044 ≈ current within noise. The phone's
+3.2 s on dev-000044 is in steps cheap on desktop: "Preparing graphics"/open +1.49 s, HUD + pause
+0.48 s, first frame +0.27 s, `_apply_run` +0.16 s, balls +0.66 s (~10 %: plants + device variance).
It was the first launch of a freshly applied OTA. Mostly a one-time pipeline/shader-cache miss plus
the new UI's first text work, a small real plants cost, device variance; the migration (~14 ms) is
not the cause. Prediction: the first launch after dev-000058 is again ~1–3 s slower; the second
returns to ~9.5–10 s. A pasted second-launch diagnostics from the phone would confirm it.

## 6. Biggest bottlenecks

1. `terrain_height` (~1.7 s in tiles plus its share in scatter/food/placement): untyped Variant arrays,
   `cos(ang)` recomputed per call.
2. Vegetation `scatter` 1.4–2.0 s.
3. Ball 3 layout 1.5 s (not yet broken down).
4. Script load 0.87 s phone.
5. Phone render/UI: creatures 0.6–0.7 s, HUD + menus 0.25–0.75 s, first frame 0.2–0.45 s warm.
6. `_apply_run` 0.2–0.35 s.

## 7. OTA-capable suggestions, ranked (estimates; nothing prototyped; benches written, not run)

1. **Thread terrain heights**: each ball's tile height grid on `WorkerThreadPool`; meshes and shapes
   on the main thread as now; ball N's heights on workers while ball N+1 lays out. ~1.0–1.3 s phone.
   Low–medium risk; must be bit-identical (hash vertices + collision faces). No scene tree, no RNG.
2. **Typed `terrain_height`**: packed arrays, precomputed `cos(ang)`, same arithmetic order.
   30–50 % of ~2.5–3 s total, ~0.8–1.2 s. Low risk if bit-identical.
3. **Avoid the post-update shader-cache miss**: no needless edits to shared shader includes; batch
   shader changes into fewer releases; warm world material pipelines behind the loading screen during
   the ball stages; check shader-baker variant coverage. ~1–1.5 s, first launch after such an update
   only (phone confirmation needed).
4. **Lazy / idle-time menu pages, pre-rendered glyphs**: 0.1–0.4 s; first open may pay once.
5. **Bound the launch update gate relative to world-ready** (≤1–2 s after it; otherwise install at the
   next safe moment, already supported). Protects gains on slow networks; verification untouched.
6. **Faster scatter**: typed loops, fill each MultiMesh buffer in one call, same RNG order. 0.3–0.7 s.
7. **New Run without a scene reload**: 7–9 s off time-to-play after New Run. High risk; later.
8. Not recommended: deferring distant balls (title Aquarium/Treasure, catalog, repop, food, save
   restore need the whole world; RNG order) — it would only move the stall.

Baking terrain into the PCK: ~2 s but +10–15 MB and code/data drift risk; 1 + 2 get most of it free.

## 8. Native (APK) only

`HEALTHY_AFTER_MS` and boot order; engine/JNI start (450–650 ms before bootstrap); rendering thread
model and other baked project settings; shader-baker coverage in the bundled baseline. None is needed
for suggestions 1–6.

## 9. Realistic phone outcome

Steady state ~9.7–10 s to a usable title today → ~7.5–8.5 s with 1 + 2, another 0.1–0.4 s with 4;
3 removes most of the one-time +1–3 s after shader-changing updates. Continue stays instant; New Run
stays a full rebuild unless 7 is done.

## 10. Not measured

Phone second launches (owner); thread/typed benches; time-to-play after New Run and Continue (with
frame times in the first seconds); ball 3 breakdown; xvfb current second launch; offline and
slow-network gate timing; real-GPU glyph/creature costs; exported-pack timings (no APK by brief).

## 11. Resuming

`TEMP_PROBES.patch.txt` (379 lines) adds timers to `startup_trace.gd`, `levels.gd`, `moss_ball.gd`,
`vegetation.gd`, `game.gd` and the `--thread-bench`, `--newrun-probe`, `--continue-probe` options.
Apply it to a scratch copy of the game (`patch -p1`), import once, then
`run.sh <copy> <log> --headless --path . -- --startup-probe --thread-bench` (set `SAVES=<save dir>` for
the save case); summarise with `python3 parse.py <dir>`. Old releases can be re-extracted from their
OTA source SHAs. Side issue seen: headless probe runs abort at exit (SIGABRT after the timeline,
possibly the `GillLook.warm_patterns` worker); under xvfb the process does not exit until timeout.
Measurements are unaffected.

## Sources

Godot docs "Reducing stutter from shader (pipeline) compilations" and "Thread-safe APIs"; Godot 4.4
release notes (https://godotengine.org/releases/4.4/); godot issue #69076 (`create_trimesh_shape` on
a worker thread); GDScript static typing benchmarks (https://www.beep.blog/2024-02-14-gdscript-typing/);
godot-docs issue #10300 (packed vs typed arrays).

## 12. Owner phone evidence after the pause (2026-10-01) — hypothesis in §5 CONTRADICTED; startup stays OPEN

Two consecutive restarts on the SAME dev-000058 (58806d2), i.e. not a first launch after an update:

| | restart A | restart B (immediately after) |
|---|---|---|
| all 7 balls built | 8 519.9 ms | 8 840.1 ms |
| food finished | 12 293.6 ms | 12 644.0 ms |
| world ready | 12 316.0 ms | 12 664.0 ms |
| title usable | 12 830.7 ms | 13 398.1 ms |

- The ~13 s is steady state on the phone, not a one-time shader/update event (§5's prediction failed).
- The launch OTA check does not block the title (still running at 10 759 ms; the gate waited 0 ms).
- New lead: **~3.8 s between "balls built" and "food finished"** (dev-000041 phone: vortices/axolotl/
  lights + food + creatures + HUD + pause + title + "Preparing graphics" + `_open_run` ≈ 1.6 s). On
  dev-000044 the "Preparing graphics"/open block alone was 1.57 s and HUD + pause 0.73 s: those
  increases look persistent, not first-launch-only. Next step: the full per-phase timeline from one
  of these launches, then probe that window (pipeline warm-up frame, HUD/menu text, creatures,
  `_open_run`/food) on desktop with the probe patch.
- Balls 8.5–8.8 s vs 6.1 s on dev-000041 (+2.4–2.7 s): content added since 041 (plants, sea fan,
  vortex currents, drag marks, Hard Mode build) needs a per-ball comparison too.

# Reactive vegetation

Expansion 3 of the Mote open-items list. The goal: watching something move through a cornfield
from above. Plants bend, part and recover along the path of the axolotl's body and tail, so you can
follow him even when the vegetation hides him. The field also moves gently on its own.

## Architecture

Everything is instanced and moved on the GPU. There are no per-plant nodes, no per-plant scripts
and no collision.

| Piece | File | Role |
|---|---|---|
| Wake | `scripts/world/wake.gd` (`Wake`, a node under `Game`) | Each frame, builds up to 24 wake points and sends them to the current ball's vegetation materials |
| Vegetation shader | `shaders/vegetation.gdshader` (`wake_bend`) | Bends each plant from its base, one value for the whole plant |
| Families and placement | `scripts/world/vegetation.gd` (`Vegetation`) | Short, medium and tall families; `field`, `corridor`, `family_params` |
| Meshes | `MeshLib.reed_clump`, `MeshLib.reed`, `MeshLib.tuft_mesh` | Creased reeds (a midrib V, not flat cards) and tufts |
| Keep-clear rule | `Levels._veg_keep_clear` | Keeps growth off blooms, motes, holes, cave mouths, platforms, brittle moss and vortex mouths |

### The wake: how the axolotl and other movers disturb plants

Each wake point has a position, a radius, a velocity and a strength.

- **Body and tail.** Five points come from the axolotl's own skeleton: head, mid-body, tail base,
  tail middle and tail tip. They follow his real pose, including the swim and the swipe's curl.
  - Strength is `0.3` while standing (a gentle lean around him, never a blast), rising to about
    `1.2` at a run. Speed is smoothed over 0.25 s, so starting and stopping ramp up and down.
  - Each tail point adds strength from its own sideways speed, so a tail whip sweeps plants hard
    to the side.
- **Bow.** A point just in front of the nose, while moving, so plants ahead start to part before he
  arrives.
- **Trail.** His body position, sampled every 0.1 s at exact times (interpolated between frames).
  It fades over 1 s with a small rebound, so plants behind him recover gradually and overshoot a
  little. Nothing is added while he stands still, so a stop settles within a second.
- **Other movers.** The three nearest live parasites (within 30 m) add their head and tail.
  Plants move around a parasite before you see it. Expansion 5's creatures plug in here.
- **Jumping.** A point above a plant's top (him jumping over it) doesn't touch that plant.

The shader, per plant:
- Every point within 2.5 × its radius pushes the plant away from itself and along its motion.
- The direction is those pushes averaged by strength. The size is the strongest single point,
  capped at 1.6, so the many overlapping points of one body don't add up to a blast.
- `wake_gain` scales it per family.
- A single distance test against the points' bounding sphere skips plants far from every mover,
  so only plants near a mover do the per-point work.

`Wake.bend_at` is the CPU mirror of the shader's function, used by the tests.

### Ambient motion

Each plant has its own sway phase and pace, from a hash of its position, so the field never waves
in unison. Slow gusts roll across the ball, and the aquarium current still moves plants on ball 2.
All of this is subtle next to the wake.

### Families

| Family | Height | Look | Wake |
|---|---|---|---|
| short | about 0.35–0.4 m | tufts; the axolotl stays fully visible | `wake_gain` 0.45: a small local stir, a visible tail sweep |
| medium | about 1 m | creased reed clumps into his body profile | 1.0: clear parting and recovery; he shows through gaps |
| tall | 2.2 m (ball 1 reed bed); 3.0 and 4.2 m on balls 2 and 3 | creased reeds, dense stands | 1.25: can hide most of him; the moving plants show where he is |

`Vegetation.family_params(family, height)` gives any vegetation material a family's behaviour.
Every existing grass, leaf and strand material now uses it.

### Placement primitives (for Expansion 4)

- `Vegetation.field(ball, family, dir, radius_deg, count, seed, opts)`: a patch in natural clumps
  (`clumps`, `clump_deg`, `fill`), thinning toward the edge (`edge`), with an `avoid` rule.
- `Vegetation.corridor(ball, family, from_dir, to_dir, width_deg, count, seed, opts)`: a band
  along a path, narrow at its ends.
- `Levels._stands(seed, threshold)`: dense stands with clearings, for spreading a family over a
  whole ball.
- `Levels._veg_keep_clear(lb, extra)`: the keep-clear rule built from a ball's content.
- All placement is seeded with its own random generator and never touches the global one that
  gameplay uses. Plants are rooted 5 cm into the real terrain, hills included.

## In the current world

- **Ball 1:**
  - short tufts everywhere, as before;
  - a medium field through the meadow, about 900 plants around lat 28, lon 10;
  - a medium corridor from the east down toward the south hills;
  - a tall reed bed, about 950 plants in the southern hills around lat −59, lon 31, where the large
    parasite roams, so you can see it move through the reeds.
  - The tutorial route and everything that must stay readable are kept clear.
- **Balls 2 and 3.** Their long grass (3.0 m and 4.2 m) now grows in dense stands with open
  clearings instead of an even carpet, with the same number of plants. All of it reacts.

## Expansion 6: owner review and the restored reef

- **Rosettes and ferns** (`MeshLib.broadleaf_mesh`, balls 1, 2 and 3). The owner found them
  "too blocky" and too sharp. Each leaf is now a smooth, arching ovate blade with a rounded tip,
  indexed with smooth normals. They sway gently in the current: sway 0.22 (ball 1), 0.2 (ball 2)
  and 0.16 for the jungle ferns, with their wake response unchanged.
- **Stems** (`MeshLib.stem_mesh`) are organic: a flared root, a node every 1.7 m, a slight
  wobble, and bark UVs.
- **Reef corals** (`Levels._accent_flora`). Clusters of flared tube coral grow on every ball
  (`MeshLib.coral_mesh`), about 120 per ball of radius 24 m, scaled with the ball's area. Each
  ball has its own two-colour palette (`Levels.ACCENTS`). They are grey and dead while the moss
  is neglected and take their colour as it heals, so the restored tank ends vivid, the way the
  art direction asks. They are hidden beyond 70 m.
- **Near-camera fade** uses an ordered 4×4 (Bayer) dither in place of per-pixel random noise. The
  random pattern read as a shimmering stipple, which looked like a shadow defect.
- **Caustics** are added to the plant and grass shaders (`docs/LIGHTING.md`).

## Performance

Measured with `--test=shots --only=perf`, the axolotl walking during every measurement, under a
software Vulkan renderer. The frame times are a relative proxy; this renderer runs vertex shaders
on the CPU, so it overstates vertex cost next to a phone GPU.

| View | Before (dev-000019) | After |
|---|---|---|
| Ball 1 tall reed bed | about 60 ms, 100–210k triangles, 155 draw calls | about 70–74 ms, 290–340k triangles, 160–180 draw calls |
| Ball 1 meadow edge | about 71 ms | about 87 ms |
| Ball 1 tutorial, ball 2, ball 3, cave | — | within run-to-run noise |

- Video memory: +0.1 MB.
- CPU: one small list rebuilt per frame (at most 24 points), sent to 4–6 materials.
- Kept in check by:
  - four segments per tall blade and three per medium;
  - 5–6 blades per clump;
  - 65 m and 55 m visibility ranges for the tall and medium patches;
  - the bounds early-out in the shader;
  - a 10-sample trail.

Thermal scaling (`QualityScaler`) thins the new patches along with the rest.

## Tests

`_test_vegetation` in `scripts/tests/unit_tests.gd`:
- Placement:
  - `veg_families_placed`
  - `veg_rooted_on_terrain`
  - `veg_keeps_clear_of_landmarks`
- Gameplay stays unaffected:
  - `veg_has_no_collision`
  - `veg_does_not_slow_or_block` (the same distance covered in the reeds as on open ground)
  - `veg_leaves_gameplay_rng_alone`
- The wake:
  - `wake_follows_axolotl`: strong around him, nothing 5 m away, parting just ahead
  - `wake_grows_with_speed`: standing 0.31, creeping 0.73, running 1.6
  - `wake_recovers_behind`
  - `wake_settles_when_stopped`
  - `wake_tail_whip_sweeps`: 0.31 standing, 1.6 in a whip
  - `wake_parasites_disturb_plants`
  - `wake_frame_rate_independent`: the same walk at 30 and 60 fps leaves the same wake

The run save doesn't hold vegetation, so the relaunch test covers save/load.

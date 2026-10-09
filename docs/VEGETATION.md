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
| Vegetation shader | `shaders/vegetation.gdshader` (`wake_bend`) | Bends each plant from its base (the wake: one value for the whole plant; the ambient flutter: per blade) |
| Plant shader | `shaders/plant.gdshader` (`flutter`) | Ambient flap of the platform and ladder leaves and the hanging roots; stems and cave shells stay rigid |
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

Everything that should bend in water moves a little on its own, even with nothing near it. It stays
subtle next to the wake. The dev-000024 physical playtest found the tank still looking static:
- clumps swayed as one rigid piece;
- a swell rolled across the whole ball in step;
- the platform and climbing leaves did not move at all.

- **Instanced vegetation** (`shaders/vegetation.gdshader`: grass, reeds, rosettes, ferns, corals,
  sprouted stem plants, trailing roots, cave strands). Each plant takes its own phase, pace, size
  (±25%) and sway direction from a hash of its position. Inside a plant, every blade, leaf or stem
  also flutters on its own phase: the meshes give each blade a slightly different random tint, and
  the shader derives the phase from it. Slow swells come and go per plant rather than as one wave
  across the ball. The aquarium current still moves plants on ball 2.
- **Platform and climbing leaves** (`shaders/plant.gdshader`, `flutter`: Giant Stems' ladders and
  canopy, the Canopy Spire, every leaf platform, flexible and current-swayed leaves). Each leaf
  flaps along its own up, about 3–7 cm at the tip, while its stalk and base stay put.
  - A ladder is one merged mesh per stem, so each leaf carries its own up and phase in its vertices
    (`CUSTOM0`, `MeshLib._leaf_into`).
  - A standalone leaf adds its node's position to that phase.
  - Where Gill stands (the middle of a leaf) the flap is about a centimetre. The collision does not
    move.
- **Hanging roots** under the big canopy leaves: they hang from their tops and swing slowly
  sideways, each on its own.
- **Rigid on purpose:** stems and trunks you climb, the terrain and moss, stone, caves, cave shells
  and mounds.

Nothing here uses a script or the gameplay random sequence. It is all vertex-shader work on the
existing instances. The CPU mirrors used by the tests (`Vegetation.ambient_bend`,
`Vegetation.leaf_flutter`) are kept in step with the shaders.

**With disturbance.** The wake, water impulses and the current add to the ambient bend in the same
sum, so a disturbed plant leans away and keeps its own flutter. Once the wake has passed and
decayed (a few seconds), each plant is back to its own gentle motion, never frozen.

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
- **Sprouts: the healed moss ball** (owner reference photo: a sprouted moss ball). `Levels._sprouts`
  grows `sprout` plants, which the vegetation shader keeps at zero size on neglected moss and
  grows in with the moss's health:
  - clusters of stem plants (`MeshLib.stem_plant_mesh`), green below and red to orange at the
    tips like Rotala. Most are small, and a crown of tall ones (3–5.5 m) covers the top of each
    ball, so the healed ball's outline changes across the tank. Gill walks through them like tall
    reeds, and they bend in his wake;
  - leafy fern clumps among them;
  - fine roots trailing from each ball's underside (`MeshLib.root_strands_mesh`).
  They are kept off routes, blooms and vortex mouths like the rest of the vegetation.
- **Variegated leaves** (owner reference: an earth star growing in their terrarium, and a "fire
  and ice" hosta; `shaders/variegation.gdshaderinc`). Living leaves are not flat green:
  - Mossy Meadow's rosettes and the jungle ferns have a pastel-pink margin and soft, wavering
    cream stripes running the length of the leaf, over a slight pink blush (earth star);
  - Current Hollows' rosettes have a white centre fading out to green margins (fire and ice);
  - the sprout ferns alternate between the two styles from ball to ball;
  - the climbing leaves have a subtle pale centre (45%), so their edges stay easy to read.

  It is computed in the shader from the position across the leaf (no extra geometry). Neglected
  leaves stay grey and dull: the variegation shows only as the moss heals.
- **Cost.** Sprouts are not drawn at all until a ball is a quarter restored (zero-size plants still
  cost their triangles). Sprout clumps and corals use lean meshes, with shorter draw distances for
  the small ones.
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

## Performance: dev-000024 playtest polish

Measured with `--test=shots --only=perf` (software Vulkan, a relative proxy), dev-000024 against the
final commit of the pass, on the same machine with nothing else running. The ambient sway is vertex
work on existing instances, so geometry and draw calls are unchanged.
- **Frame time:** every view is within ±11% of before, the median about 1% faster. This is the run-to-run
  noise of this renderer.
- **Video memory:** 93.7 → 98.2 MB, from the colour page's preview target and pattern textures.

| View | dev-000024 | This pass | Change |
|---|---|---|---|
| ball1_66_0 | 528 ms, 503k tris, 303 dc | 550 ms, 503k tris, 303 dc | +4% |
| ball1_10_30 | 228 ms, 301k tris, 276 dc | 207 ms, 295k tris, 274 dc | -9% |
| ball2_10_70 | 238 ms, 275k tris, 214 dc | 227 ms, 168k tris, 224 dc | -5% |
| ball3_10_110 | 200 ms, 235k tris, 213 dc | 206 ms, 236k tris, 201 dc | +3% |
| ball1_-59_31 | 168 ms, 390k tris, 240 dc | 152 ms, 394k tris, 242 dc | -10% |
| ball2_30_-20 | 118 ms, 593k tris, 470 dc | 130 ms, 582k tris, 442 dc | +11% |
| cave_b1 | 125 ms, 373k tris, 206 dc | 129 ms, 374k tris, 203 dc | +3% |
| ball4_terraces | 147 ms, 248k tris, 211 dc | 149 ms, 278k tris, 228 dc | +2% |
| ball5_bridge | 102 ms, 255k tris, 134 dc | 104 ms, 256k tris, 134 dc | +2% |
| ball6_spire_mid | 78 ms, 388k tris, 293 dc | 72 ms, 388k tris, 289 dc | -8% |
| ball7_high_shelf | 95 ms, 137k tris, 165 dc | 93 ms, 138k tris, 171 dc | -1% |
| cave_b7 | 104 ms, 204k tris, 134 dc | 99 ms, 203k tris, 132 dc | -5% |
| restored_ball1_10_30 | 132 ms, 402k tris, 267 dc | 126 ms, 400k tris, 265 dc | -4% |
| restored_ball3_10_110 | 130 ms, 236k tris, 214 dc | 126 ms, 240k tris, 216 dc | -3% |
| restored_open_water | 132 ms, 338k tris, 226 dc | 128 ms, 368k tris, 225 dc | -3% |

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

`_test_ambient_sway` (dev-000024 physical playtest polish):
- `neighbour_plants_sway_out_of_step`: 24 neighbouring reeds within 0.7 m, mean |correlation| 0.33
- `blades_in_a_plant_not_in_lockstep`
- `ambient_sway_small`: a medium reed's tip swings about 0.1 m at most
- `ladder_leaves_each_move_on_their_own`: one phase per leaf; neighbours uncorrelated; tip flap
  within 2–10 cm; every ball's leaves flutter while their stems stay rigid
- `disturbance_adds_to_ambient_then_settles_back`
- `ambient_motion_bounded_gpu_only`: no scripted vegetation nodes, everything instanced

The run save doesn't hold vegetation, so the relaunch test covers save/load.

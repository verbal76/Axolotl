# The world: seven moss balls

Expansion 4 of the Mote open-items list added four moss balls to the original three. Each new ball
branches off the original chain through its own vortex. **Finishing a run now needs all seven balls
fully restored** (owner decision).

## Map

```
            Mossy Meadow (1) ── Current Hollows (2) ── Giant Stems (3)
                  │                     │                    │
           Terrace Steps (4)      Reed Canyon (5)     Canopy Spire (6)
                  │
           Hollow Grotto (7)
```

| # | Ball | Radius (before → world expansion) | Reached from | Character |
|---|---|---|---|---|
| 1 | Mossy Meadow | 24 → 48 m | start | the welcoming playground: the Glade Upland and the Great Ravine, meadow lowlands, the Coral Garden, Root Hollows |
| 2 | Current Hollows | 28 → 56 m | 1 | water movement and cuts: the Cut on the Current Shelf, current streams, bubble columns, Undercut Hollows |
| 3 | Giant Stems | 30 → 60 m | 2 | vertical jungle: the giant spiral, 140 laddered stems, the Great Trunk to the High Crown, the Root Tangle |
| 4 | Terrace Steps | 18 → 36 m | 1 | layered traversal: the Grand and Twin Terraces and their bridge, the Stone Field, Coral Shelves |
| 5 | Reed Canyon | 26 → 52 m | 2 | concealed geography: the long reed canyon, the Reed Maze's hidden ravines, the Secret Clearing, the Stalker Hollow |
| 6 | Canopy Spire | 16 → 32 m | 3 | vertical playground: the spire, the 31 m Sky Spire and its glide shaft, the Low Garden |
| 7 | Hollow Grotto | 22 → 44 m | 4 | caves: three grottoes (the Glow Chamber behind its boulder), the Undercut Ravine, the Shaft, Basalt Columns |

World expansion (docs/WORLD_EXPANSION.md): every ball about doubled in radius (about 4× the
surface) in a tank laid out 1.4× wider. Original content keeps its place on each ball (so it is
twice as far apart) and its completion id; each world gained regions in its own identity.

- Topology is `Levels.LINKS` (`[a, b]` pairs, one vortex each). `Levels.CENTERS`, `RADII`, `NAMES` and
  `PALETTES` hold one entry per ball.
- Each connection has its own faint hue (owner, 2026-09-30: nearby vortices were mistaken for one
  another): `Vortex.TINTS` by its index in `Levels.LINKS` — rose, green, amber, violet, coral, blue —
  the same at both ends and never reshuffled, and no two connections from the same ball alike (ball
  2's three are rose, green and violet). It tints the bright water (foam and streaks on the jets, the
  ring round the pool's eye, the rising debris; `TINT_AMT` 0.5), so they stay water. Destinations,
  travel, progression and saves are untouched. Test `vortex_tints_per_connection`; renders
  `--test=shots --only=vtint` (each ball's mouths together and close up, murky and restored).
- A vortex opens when the ball it leaves is 70% restored (`Vortex.CONNECT_AT`). The original two vortices are unchanged,
  so the original route plays exactly as before.
- A ball can now have several outgoing vortices (`MossBall.vortices`); `vortex_out` stays the
  original chain's for anything that used it.
- New areas are authored relative to where their vortex arrives (`WorldExpansion._rel`), so each
  reads from its entrance.

## New terrain vocabulary (`LevelBuilder`, `MeshLib`)

These extend Expansion 2's pieces (docs/TERRAIN.md), on the same moss-over-stone material, with
collision exactly the drawn triangles. Every piece records its walkable top as metadata, which the
route audit and the test bot read.

| Piece | Call | Shape |
|---|---|---|
| Ridge | `ridge(lat0, lon0, lat1, lon1, height, width, crest_w, seed)` | a long crest swept along a great circle, a walkable top, sides sweeping into the ground, tapered ends you can walk up |
| Terrace | `terrace(lat, lon, [[radius, top], …])` | stacked mounds, each step a plain jump; the tiers follow the ground so the lowest rim is never a wall |
| Arch | `arch(lat0, lon0, lat1, lon1, clearance, width, thick)` | a stone arch you can walk under and along |
| Bridge | `bridge(p0, p1, bow, width, thick)` | a slab spanning two formations (marked "floats by design": it rests on them) |
| Shelf | `shelf(lat, lon, height, r_top, r_stem)` | a wide flat top on a narrow stem: shelter beneath, a platform on top |
| Canopy spiral | `canopy_spiral(xf, count, start, rise, turn, stem_h, stem_r)` | leaves in a rising spiral round a stem, each one a plain jump from the last |
| Stem ladder | `ladder_stem(stem_xf, h, r0, r1, bend, levels, heading0, turn, name)` | leaves spiralling up a stem, one plain jump each; collision follows each leaf's outline |
| Route | `route(name, start, tops, zones, goal)` | not a shape: the designed climb over the tops above, for the audit and the bot |

`MeshLib.sweep` (a profile swept along stations, triangles facing away from the inside) builds the
ridge, arch and bridge. `MeshLib.shelf` builds the shelf. Caves can now hold a **pearl** (refills
health) instead of a heart upgrade, and a ball can have up to four caves darkening its moss
(`MossBall.add_cave`).

## Vertical and canopy routes

Every elevated mote or bloom has a designed route. `_test_route_audit` checks each step against the
jump: a floor to land on, headroom above, rise ≤ 2.6 m (jump 1.85 m, burst ~2.6 m), horizontal gap
≤ 5 m.

| Ball | Route | Climb |
|---|---|---|
| 4 | terraces | three tiers to a crown mote and bloom 3.6 m up |
| 4 | arch | up the arch's ramp to a mote on top (another waits in the shelter underneath) |
| 4 | ridge | along the ridge crest to a mote |
| 5 | bridge | up the north crest, across the natural bridge to a mote and bloom |
| 5 | north crest | the far end of the north crest |
| 6 | spire mid | the spiral's first six leaves to a mote |
| 6 | spire | the whole spiral to the canopy crown (mote and bloom about 14 m up) |
| 6 | shelves | three stacked shelves to a mote |
| 7 | high shelf | along the low ridge crest, then up onto the high shelf's mote |

## Elevated routes: the phone report and the all-ball audit

**Owner phone report (2026-09-28, Giant Stems).** Gill stood under several leaf platforms with no
visible way up. The location was the dense jungle of ball 3.

**Finding.** The jungle had 70 decorative stems with 2–4 big leaves each, 4–20 m up.
- They were not meant to be reached, but they looked like platforms.
- The ones below 9 m were solid.
- Nothing reached them.
- The real canopy climb (the spiral on the giant stem at 28, −30) was never the problem: its first
  leaf is 0.8 m up and in plain view (shots `b3look_*`).

**Repair.** Owner decision: every stem that looks climbable is climbable.
- Each jungle stem is a ladder (`LevelBuilder.ladder_stem`, `Levels._jungle_ladder`):
  - a small leaf 0.9 m up to start;
  - then a leaf every ≤1.0 m, turning 108° each time, up to the stem's big leaves;
  - the big leaves take the ladder levels nearest their original heights.
  - 70 stems, 949 leaves. Each stem is one body and one MultiMesh.
- The ladder leaves' collision follows the drawn leaf outline. The first build used boxes, which
  were full width at the stem and left an invisible corner over the leaf below; Gill's head caught
  it (found by the physical climb test).
- Stems stand at least 9 m apart, so ladders never interleave (one stem's leaf hung over another's
  steps).
- Ferns and tall blades keep 3.8 m back from each ladder's base, so the first leaves can be seen from
  the ground.
- Ladder leaves are on their own physics layer (`LevelBuilder.CLIMB_LAYER`). The axolotl stands on
  them; the ground rays of parasites, food and motes ignore them, so creatures walking under a
  ladder never pop up onto it.
- Bent stems now collide along their bend (a stack of short cylinders), not as a straight cylinder
  that stuck out where the stem curves away.

**The same audit on all seven balls.** Every destination has a registered climb (`route` hints,
plus audit-only climbs for the existing tower, mesa, canopy, tutorial and cave interiors), checked
as ground → first step → landings → top:

| Check | Rule (from Gill's measured movement) | Result |
|---|---|---|
| `climbs_start_with_a_plain_step_from_the_ground` | every climb starts on open ground; first step ≤ 1.6 m up (jump apex 1.85 m), ≤ 3.5 m away | pass; highest first step 1.55 m (the ball 2 mesa's first leaf, unchanged) |
| `routes_reachable_by_design` | every landing has floor and headroom. Ordinary steps are within a **standing plain jump**, measured at 4.0 m reach at 0.5 m up, 3.5 m at 1.0 m and 2.9 m at 1.6 m, +1 m because landing points lie inside surfaces. Burst climbs (tutorial, cave ledges, mesa) may use the burst (measured 5.9–7.0 m at 1.6 m up); limit 5.5 m. Walks up a continuous slope are walks. | 95 climbs pass |
| `elevated_platforms_all_on_climbs` | every standable leaf, cap, swaying leaf, mound or shelf > 2.6 m above the ground lies on a climb | 61 checked, 0 orphans |
| `decor_leaves_do_not_look_like_platforms` | leaves without collision hang like fronds, not flat | pass; ball 2's 34 kelp-top leaves now droop 55° (they looked like platforms 5–9 m up) |
| `climbs_with_plain_jumps` (physical) | Gill climbs with real touch jumps from the ground to the top | both towers, terraces, Canopy Spire, shelves, high shelf: all steps |
| `jungle_ladders_climbed_with_plain_jumps` (physical) | every jungle ladder, ground to top leaf | 70 stems, 949 leaves, all climbed |
| `canopy_climb_with_plain_jumps` (physical, existing) | the Giant Stems canopy spiral | all 16 leaves |

The mesa's swaying leaves ride a 3 m/s current, so that climb needs timing and the water burst. It
is unchanged from the released game, and the playthrough bot climbs it on both seeds. Its first leaf
(1.5 m) is the highest first step in the game: noted for Expansion 6's balance pass.

Other fixes found by the audit:
- Terrace Steps' arch climb starts 1.2 m from the arch, not 2 m.
- Hollow Grotto's high shelf is 2.75 m, not 2.9 m, and the climb lands on its near side (the last
  jump was beyond a standing jump).
- Reed Canyon's bridge bloom sits on the bridge's real top.
- A Hollow Grotto bloom was on a cave's flank, where a resumed run slid 1.4 m
  (`new_blooms_resume_standing`).

## Performance, Expansion 6

Measured the same way (`--test=shots --only=perf`, software Vulkan renderer, two runs each,
averaged, the axolotl walking). The baseline is Expansion 5 (dev-000023). The frame times are
a relative proxy: this renderer rasterises the shadow map on the CPU, so shadow and fill costs
weigh far more here than on a phone GPU.

| View | Before (E5) | First E6 build | Final E6 | Triangles before → final |
|---|---|---|---|---|
| Ball 1 tutorial (first view, includes warm-up) | 498 ms | 584 ms | 549 ms | 442k → 550k |
| Ball 1 meadow | 220 ms | 233 ms | 202 ms | 309k → 413k |
| Ball 2 east | 119 ms | 262 ms | 228 ms | 272k → 274k |
| Ball 3 jungle | 106 ms | 256 ms | 189 ms | 109k → 241k |
| Ball 1 reed bed | 139 ms | 172 ms | 153 ms | 330k → 388k |
| Ball 2 mesa side | 109 ms | 162 ms | 134 ms | 530k → 572k |
| Ball 1 cave | 117 ms | 168 ms | 130 ms | 312k → 371k |
| Ball 4 terraces | 74 ms | 194 ms | 150 ms | 218k → 248k |
| Ball 5 bridge | 94 ms | 139 ms | 106 ms | 134k → 153k |
| Ball 6 spire | 66 ms | 118 ms | 87 ms | 367k → 253k |
| Ball 7 high shelf | 78 ms | 124 ms | 91 ms | 114k → 129k |
| Ball 7 grotto | 89 ms | 133 ms | 103 ms | 199k → 204k |
| Restored meadow | 104 ms | 151 ms | 126 ms | 173k → 394k |
| Restored jungle | 101 ms | 197 ms | 133 ms | 109k → 254k |
| Restored open water | 115 ms | 169 ms | 136 ms | 320k → 339k |

- Video memory: 71 MB → 81 MB (vortex jets, sprouts, corals, creature meshes).
- Where the rest goes (`perfsplit`): with shadows off, the Expansion 6 world costs 13–25% more than
  Expansion 5 in this renderer (caustics, variegation, the richer vegetation). The shadows are
  the remainder, and on a phone that cannot hold its frame rate `QualityScaler` turns them off
  first.
- The parasites' combat reasoning costs about 40 µs per engaged parasite per frame (desktop,
  `parasite_combat_cheap`).

## Leaf platforms (Expansion 6)

The leaves of the spirals and ladders were flat, detached-looking paddles, stacked so closely that
some overlapped. Every climbing leaf was rebuilt and every climb re-audited.

- **Shape.** A broad leaf blade with a narrow neck, a raised midrib and a gentle droop at the tip.
  A petiole (a curved stalk) grows out of the stem into the blade, so the leaf attaches to the
  stem. The blade is one merged mesh per stem (`MeshLib.platform_leaf_mesh`).
- **Collision matches the art.** `MeshLib.leaf_collision_shapes` builds two convex pieces
  (neck and blade) from the drawn outline, at 0.97 of the drawn width. It is cached by size.
  A straight stem's collision now reaches its drawn top. It used to stop 0.5 m short, so the
  top leaves' stalks rooted in nothing.
- **Staging.** The Giant Stems canopy spiral and the Canopy Spire both turn **90°** per leaf
  (was 72°, which left 2–6° between the leaves two apart). The spiral starts at 55°, so the last
  jump lands on the canopy's C3 shelf instead of passing under it. Leaves stand
  `LEAF_CLEAR` (0.15 m) off the stem surface. Climbs start 4.4 m along the first leaf, past its
  broad tip, and every landing target is 1.5 m along a leaf, on the flat of the blade.
- **The canopy route.** The route runs spiral top → C3 → C1 → C2. The spiral's mote is on leaf 7.

Tests (`_test_leaf_geometry`, and `_test_leaf_footing` with real touch input):

| Check | What it proves |
|---|---|
| `leaf_collision_is_the_drawn_leaf` | on every climbing leaf (> 950), rays across the drawn blade hit its own collision within 0.06 m of the drawn surface, and nothing is solid beyond the drawn edge |
| `leaves_grow_from_their_stems` | every stalk's root is inside a stem |
| `leaves_have_room_to_turn` | a 0.7 m circle of footing round every landing point |
| `spiral_leaves_distinct` | neighbouring leaves round every stem and spiral are ≥ 12° apart in plan view (> 900 pairs) |
| `turning_on_a_leaf_keeps_footing`, `edge_landings_hold`, `jump_beside_the_stem_clear`, `underneath_leaves_clear`, `climb_down_never_wedges`, `ladders_climbed_twice` | physical: turning round on a leaf, landing near its edge, jumping beside the stem, walking under leaves, climbing down, and two jungle ladders climbed twice in a row (turning tried on > 140 leaves) |

## Vortices (Expansion 6, owner review)

The owner rejected the first vortex: a solid tube with a cone "jammed into the dirt" that looked
like PS1 graphics. They asked for a revolving spiral of water jets that Gill circles through. The
vortex (`scripts/world/vortex.gd`) is now:

- **Jets.** Five water jets and three thinner inner spray streams wind round the path between the
  balls as a helix (`Vortex._jet_mesh`, `shaders/vortex_jets.gdshader`). They flare out at both
  ends into the pools. The whole spiral revolves about the path (`spin_phase`, faster as the
  vortex strengthens), and foam streaks race along each jet. Before the vortex connects, the
  spiral reaches only part way (`grow`), as before.
- **Tidal pools.** Each end is a swirling pool lying on the moss (`Vortex._pool_mesh`,
  `shaders/vortex_pool.gdshader`): spiral arms of water winding in toward a churning eye, and a lip
  of foam. The pool grows from the eye as the vortex strengthens. Sand, bits of moss and bubbles
  spiral up out of it into the jets (`shaders/vortex_debris.gdshader`). There is no solid geometry.
- **The ride.** Gill is carried round the path beside a jet as the spiral turns, a corkscrew
  (`Vortex.ride_pose`), belly toward the jet. The camera rides in the middle of the spiral. The
  ride's start, end and length (6 s) are unchanged, and so are the mouths' clear radius and every
  vortex test.

## Caves

Seven caves in all (three before). All use the Expansion 2 generator (arched mouths, jambs,
vertical interior, head guard), each seeded from its site.

| Ball | Cave | Reward |
|---|---|---|
| 1–3 | one each, unchanged | heart upgrade |
| 4 | a grotto on the far side | pearl |
| 5 | a grotto at the canyon's end | pearl |
| 7 | the grotto (radius 8 m) | pearl |
| 7 | the cavelet (radius 6.6 m) | pearl |

## Vegetation

The new balls use Expansion 3's families and placement (docs/VEGETATION.md), not hand-scattered
meshes:
- Terrace Steps: open short growth everywhere (1,800) and a medium field on the far side;
- Reed Canyon: tall reeds filling the canyon floor (1,500), short growth beyond the canyon;
- Canopy Spire: short growth in stands with clearings, a medium field and a tall stand;
- Hollow Grotto: a medium corridor between the two ridges, short stands, a tall stand on the far
  side.

Growth is kept off blooms, motes, holes, cave mouths, formations and vortex mouths.

## Tests

In `scripts/tests/unit_tests.gd`:
- `_test_new_areas`:
  - `world_has_seven_balls`
  - `new_balls_distinct`
  - `new_caves_hold_pearls`
  - `new_areas_in_completion`
  - `new_blooms_resume_standing`
- `_test_route_audit`:
  - `routes_reachable_by_design`
  - `climbs_start_with_a_plain_step_from_the_ground`
  - `elevated_platforms_all_on_climbs`
  - `decor_leaves_do_not_look_like_platforms`
  - `elevated_motes_have_routes`
- `_test_climbs_physical` and `_test_jungle_ladders_physical`: real touch jumps up the climbs.
- `_test_vortex_mouths_clear`
- `_test_caves` (seven caves)
- `_test_terrain_grounded` and `_test_no_floating_platforms`: every new formation meets the ground.
- The relaunch test (`_test_run_continue`) saves on Hollow Grotto and continues there.
- The playthrough bot follows the original route, then travels to balls 4, 7, 5 and 6 in turn and
  restores each fully, climbing every route and entering every cave.

## Performance

Measured with `--test=shots --only=perf` under a software Vulkan renderer: the same views before
(dev-000020's source, `7c3f082`) and after, two runs each, averaged, the axolotl walking during every
measurement. The frame times are a relative proxy, not phone numbers.

| View | Before | After | Notes |
|---|---|---|---|
| Ball 1 tutorial | 136 ms, 235 draw calls, 333k tris | 147 ms, 303 draw calls, 455k tris | the new balls are visible across the tank |
| Ball 1 meadow | 89 ms | 97 ms | |
| Ball 1 reed bed | 79 ms | 94 ms | |
| Ball 2 east | 75 ms | 84 ms | |
| Ball 2 mesa side | 66 ms | 70 ms | |
| Ball 3 jungle | 83 ms, 335 draw calls | 87 ms, 240 draw calls | ladder leaves are one MultiMesh per stem |
| Ball 1 cave | 87 ms | 86 ms | |
| Ball 4 terraces / 5 bridge / 6 spire / 7 high shelf / 7 grotto | — | 50 / 77 / 40 / 60 / 70 ms | all within the range of the original views |

- Video memory: 55.4 → 68.6 MB (+13 MB, the four balls' meshes and collision).
- World build (headless): about 1.1 s → 1.8 s. Rendered startup to the first world frame is
  unchanged within noise (5.6–6.2 s before, 6.0–6.2 s after, software renderer).
- Only the current ball runs its creatures, food and vegetation wake; the new balls add no per-frame
  work while the axolotl is elsewhere.


# Terrain vocabulary

Expansion 2 of the Mote open-items list: the reusable terrain pieces and material that every moss
ball uses. Later expansions, especially Expansion 4's new balls, build from these, not from
primitives.

## Material: moss over earth and stone (`shaders/moss.gdshader`)

One material for each ball's ground, its mounds and its caves.

- **Where moss grows.** Faces turned away from the ball's centre (tops, gentle slopes) are moss.
  Steep faces, overhangs, cave walls and ceilings show the earth and stone underneath. The boundary
  is broken up by noise, and moss creeps down steep faces in patches. Flat ground is always moss.
  - Tuning: `moss_slope` (how steep before stone shows) and `moss_blend`.
- **No stretching.** Textures are projected along the surface normal, so vertical faces are as
  crisp as the ground. The projection is biplanar: the two planes that face the surface most, with
  explicit gradients so there is no seam where the choice changes.
- **Scales.** Four noise scales at two fetches each (8 texture fetches; the old material used 9):
  - macro colour variation, including a second moss tint (`moss_tint`);
  - the moss/stone boundary and the rock strata;
  - detail;
  - a soft grain of moss tufts, sampled on a rotated grid so it never visibly repeats.
- **Moss cushions and relief (E6f, 2026-10-02).** Up close the moss used to read as marble swirls
  and radial streaks: the mid layer is warped by the macro layer, and the macro layer's fine grain,
  magnified by a 14 m warp, smeared it. The macro layer is now read from a coarse mip (24 times the
  filter footprint) and the warp is 8 m (`warp`). Seen from afar, the balls show the same broad
  bands as before. The tuft and detail samples also shape the moss into clumps a few centimetres across,
  with shaded gaps and paler tips. Within about 10–30 m of the camera, a bump from the same samples
  (`relief`, 3.5 cm) tilts the normal, so moss clumps and the stone's grain, strata and seams catch
  the light. It uses screen-space derivatives and adds no texture fetches.
- **Restoration.** Restoration still turns the moss from grey to green and stays the main thing the
  eye reads. Stone only greys slightly near sick moss.
- **Per-ball palette.** Each ball's palette in `Levels.PALETTES` sets `moss_*`, `stone_a`,
  `stone_b` and `moss_tint`. A new ball needs only a palette to get its own look.
- **Textures.** No new textures: the existing 256×256 noise texture is reused.

## Mounds: platforms and ledges (`MeshLib.mound`, `LevelBuilder.cushion`)

The natural platform shape, replacing the old cylinders ("cushions"):

- The walkable top is flat at exactly `height`, and never smaller than a cushion's top was, so
  jump routes keep their landing areas.
- A rounded rim, then sides that lean outward going down (75°), then a concave curve sweeping into
  the moss. Nothing meets the ground at 90° (owner phone feedback, 2026-09-28).
- Only the lowest ~0.2 m of that curve is shallow enough to stand on (under 52°), so the flare is
  not a step that makes a jump easier.
- The outline is irregular, from seeded noise. It is always outward and scales each angle's whole
  side evenly, so the designed slopes hold at every angle. It is seeded by the mound's position, so
  the world is the same every launch.
- **The base follows the real terrain.** `LevelBuilder` passes the ground height under every point,
  so the sweep meets hills and the ball's curvature everywhere, not a flat plane, and leaves no
  standable ledge on the downhill side. The top stays level.
- Collision is exactly the drawn triangles.
- The brittle-moss caps (`Platforms.Crumble`) keep their cap shape: they stand on stalks, not on the
  ground.

## Caves (`MeshLib.cave_mound`, `LevelBuilder.cave`)

The old dome was a hemisphere with a doorway made by deleting every quad inside a box. That left
a rectangular, stair-stepped hole, and at the door the two wall surfaces were simply cut, leaving an
open slot inside the wall. The new generator:

- **Mouth.** The outer and inner surfaces are grids of rows (heights) by columns (angles). In every
  row below the arch top, the columns run from one side of the mouth round the back to the other, so
  both surfaces end *exactly* on the arch outline. The arch is rounded, slightly flared at the
  base, and irregular. Rows get closer together toward the crown so it closes in a round curve.
- **Jambs.** Rounded strips join the outer and inner outlines, closing the wall. There is no
  internal slot and no fin.
- **Brow and base.** A brow bulges over the mouth; the base sweeps into the ground like the mounds'.
- **Interior.** Walls rise vertically for 1.9 m before the vault, so no ceiling slopes down to the
  floor. Interior noise only ever widens the cave. Lowest ceiling over any floor point: about 3.9 m.
- **Collision.** Exactly the drawn triangles.
- **Variation.** Each cave is seeded from its site: size, height, mouth width (2.5–2.9 m) and height
  (2.3–2.6 m), and lumps. Expansion 4 can call `LevelBuilder.cave` for new caves and get distinct
  natural shapes. `MeshLib.cave_mound` takes the parameters directly for anything else.

## Stone pillars (`MeshLib.stone_pillar`, `LevelBuilder.stone_column`, `rising_stone`; E6f)

The stepping stones (Mossy Meadow's ravine), the Stone Field and its rising stones (Terrace Steps)
and the Basalt Columns (Hollow Grotto) used to be plain 14-sided cylinders. They are now stone
prisms:
- 7 faces (6 for basalt, 9 for the broad rising stones). The corners are unevenly spaced and sit at
  slightly different distances from the centre. Each face is lit flat, like split stone.
- The top is flat at exactly the design height, with a bevelled rim. Its outline is never inside
  the old radius (the narrowest point is at least 1.0 × radius), so no landing got smaller. Gaps
  between columns are at most about 0.15 m narrower.
- The sides lean out slightly going down, with a short flare at the foot. Above the bottom 0.3 m
  they are steeper than 52° and never overhang, so there is no lip to pull up on. They are buried
  0.6 m, as the cylinders were.
- The shape is seeded by position, so it is the same on every launch. Collision is exactly the
  drawn triangles.

## Stems and trunks (`shaders/plant.gdshader`, `bark`; E6f)

The stem material shows 24 shallow ribs round each stem, wandering with the noise and
anti-aliased with `fwidth`, so far or thin stems fade to plain. It also has long lighter and darker
streaks (one extra stretched fetch), a darker foot where the stem leaves the moss, and near the
camera a bump from the ribs. Before, the stems were smooth tubes. Only the stem material sets
`bark`; leaves and roots are unchanged.

## Gill's head

Gill collides as one 0.3 m sphere at his body, but his head is 0.4–0.55 m ahead of it, so walking
into any wall used to put his head about 0.25 m into it (phone defect).
- The fix is a **head guard** (`Axolotl._guard_head`). After each move, a 0.17 m sphere at his head
  (`head_center`) is tested against the world; where it overlaps a wall or ceiling, he is moved back
  out and stops moving into it. Anything too steep to stand on (over 52°) counts as a wall.
- Ground he can stand on is left to the body, so walking up slopes and all jump routes behave as
  before. His body collision is unchanged.

## Tests

In `scripts/tests/unit_tests.gd`:
- `_test_caves`:
  - `cave_mouths_arched_not_rectangular`
  - `cave_mouth_clearance`
  - `caves_vary`
  - `cave_collision_is_drawn_mesh`
  - `cave_ceiling_clear_over_floor`
  - `cave_walk_in_and_out`
  - `cave_head_stays_out_of_walls`: walks into the walls in ten directions per cave, jumping.
    It fails without the head guard: head in the rock in 3271 of 5000 frames.
- `_test_mounds`:
  - `mounds_tops_at_design_height` (18 mounds)
  - `mounds_flare_not_a_step`: the highest standable point on any flank is 0.23 m above the ground.
  - `head_stays_out_of_mound_walls`
- `_test_mesh_winding`: `mound_faces_outward`, `cave_faces_correct_side` (outer, inner and jambs).
- `_test_terrain_grounded` and `_test_no_floating_platforms`, unchanged: every structure still meets
  the ground and nothing floats.

## Performance

Measured on the same machine before and after, at five fixed views, with `--test=shots --only=perf`
under a software Vulkan renderer. The frame times are a relative proxy, not phone numbers.

- Draw calls: unchanged (0–3 more).
- Triangles: +1–6% (caves about 8.7k triangles each, mounds about 1k each).
- Video memory: +2.5 MB of mesh buffers.
- No new textures.
- Open views: frame time within run-to-run noise.
- Cave interior: about 20% slower. The same geometry with the old material costs the same, so this
  is the tunnel filling more of the screen at that camera position, not the material.

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

| # | Ball | Radius | Reached from | Character |
|---|---|---|---|---|
| 1 | Mossy Meadow | 24 m | start | unchanged |
| 2 | Current Hollows | 28 m | 1 | unchanged (its vortex to 5 is new) |
| 3 | Giant Stems | 30 m | 2 | unchanged (its vortex to 6 is new) |
| 4 | Terrace Steps | 18 m | 1 | open low growth; stepped terraces, a stone arch, a ridge walk, a grotto |
| 5 | Reed Canyon | 26 m | 2 | a canyon of tall reeds between two ridges, a natural bridge between the crests, a grotto at the canyon's end |
| 6 | Canopy Spire | 16 m | 3 | one great stem with a spiral of leaves to a canopy crown; stacked overhanging shelves; no cave |
| 7 | Hollow Grotto | 22 m | 4 | dim basalt; two grottoes, overhanging shelves, low ridges with plant corridors between bare rock |

- Topology is `Levels.LINKS` (`[a, b]` pairs, one vortex each). `Levels.CENTERS`, `RADII`, `NAMES` and
  `PALETTES` hold one entry per ball.
- A vortex opens when the ball it leaves is fully restored. The original two vortices are unchanged,
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
  - `elevated_motes_have_routes`
- `_test_vortex_mouths_clear`
- `_test_caves` (seven caves)
- `_test_terrain_grounded` and `_test_no_floating_platforms`: every new formation meets the ground.
- The relaunch test (`_test_run_continue`) saves on Hollow Grotto and continues there.
- The playthrough bot follows the original route, then travels to balls 4, 7, 5 and 6 in turn and
  restores each fully, climbing every route and entering every cave.

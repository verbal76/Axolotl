# World expansion: seven substantial worlds (design framework, draft)

Owner brief: "MOTE — MAJOR WORLD EXPANSION PROGRAM" (2026-09-28). Ships as ONE dev OTA after
dev-000025. Mossy Meadow first as the template, then worlds 2–7 (not clones).

## Owner decisions

- **Scale:** bigger balls in a bigger tank. Radii roughly double (about 4× surface) and the tank
  grows, with CENTERS re-laid out so the balls still fit and the vortex rides stay pleasant. Content
  is re-authored for the new size, not stretched.
- **Deaths:** a ravine fall costs one frond and puts Gill back at the ravine edge. Losing the last
  frond, from any cause, is a normal death: he re-forms at the last bloom with full health, and
  earned progress is kept (today's death rule). The extreme canopy drop keeps its current
  "never the last" rule.

## Audit findings (current architecture, read-only audit)

- **Build.** `Levels.build_ball(i)` is a per-ball `match` into hand-coded author functions:
  - `_ball1..3` in levels.gd;
  - `terrace_steps`, `reed_canyon`, `canopy_spire` and `hollow_grotto` in world_expansion.gd.

  Each ball is about 80–220 lines of imperative lat/lon calls. The shared vocabulary lives in
  LevelBuilder (cushion, ridge, arch, bridge, shelf, terrace, canopy_spiral, ladder_stem, stems,
  leaves, flex/sway/crumble, cave).
- **Radii and tank.** Radii are 24/28/30/18/26/16/22. The tank is 464×260×354 m. At 2× radius:
  - balls 2 and 5 overlap (-5 m);
  - ball 4 ends up 6 m from the glass.

  So CENTERS must be re-laid out and the tank enlarged, along with the hand-placed aquarium
  dressing (shafts, plant clusters, gravel).
- **Terrain.** It is a base SphereShape3D plus additive cosine hills (h ≥ 0). One mesh per ball
  is rebuilt at 176×88 (15.7k vertices; about 1.7 m spacing at r 48). The safety net teleports Gill
  whenever r < radius − 1.5. Ravines are therefore impossible today: this needs a signed height
  field, chunked patches (mesh + collision per patch) and a safety net measured from local ground.
- **Health field.** A uniform array of 64 angular splats, evaluated per vertex. At 5–6× content
  the splats get evicted (holes appear) and edges coarsen. Move to a per-ball health texture, or
  upload splats per region.
- **Restoration.** Almost entirely visual today. Crumbles solidify when their zone completes
  (with a clear-of-player guard), sprouts appear at 25%, and vortices open at 70%. Geometry gates
  must be applied in both `complete_event` and `restore_event` (save resume), derived from
  `zones[id].completed`.
- **Completion ids depend on authoring order.**
  - Ids: `b<n>.<zone>.parasite.<i>`, `b<n>.bloom.<i>`, `b<n>.cave.<i>`, critters in creation
    order. Inserting content remaps earned ids.
  - Make ids explicit fields, and carry every existing id over verbatim.
  - Catalog v3 has 172 ids, pinned by SHA.
  - The run save stores no position (resume is at a bloom or the arrival point), so old saves
    cannot be stranded by geometry.
- **Performance.**
  - All seven balls are drawn at once, with no per-ball hide or impostor.
  - On the current ball, parasites, motes and food tick with no distance gate.
  - Vegetation is culled in 14 direction chunks per ball, and counts are literals.
  - Ecosystem (0.25 s, 38 m range) is the one existing regional activation model.
- **Route proof.**
  - The audit is geometric (hop reach, rise, headroom) and assumes the ground is connected.
  - The bot has no pathfinding and fixed timeouts.
  - Needed: a per-region walk graph (portals and edges) checked by physics sweeps, reachability
    in restored and unrestored states, and a bot that navigates the graph.

## Proposed framework (to build first, before Mossy Meadow content)

1. **Declarative world data.** `BallDef` → `RegionDef` (anchor lat/lon/heading, size in metres,
   biome, neighbours), each with:
   - terrain ops: ravine, ridge, plateau, hill;
   - features and actors, with explicit completion ids;
   - routes (easy, skilled, exploration), walk edges, ravine edges with respawn anchors;
   - restoration gates (enable/disable feature ids when a zone is restored);
   - vegetation per area, and habitats.

   Positions are in metres in the region frame. One interpreter replaces the per-ball `match`
   blocks.
2. **Chunked signed terrain.** Cube-sphere patches, each with its own mesh and concave collision,
   and a height field bucketed per patch. Ravines are negative. The safety net is measured from
   local ground.
3. **Ravines and recovery.**
   - Ravine volumes and meta: "unsafe", so they are never used as a safe position.
   - `Game.ravine_fall()`: one frond, then a short re-form at the nearest edge anchor. On the last
     frond, a normal death at the last bloom.
4. **Restoration geography.**
   - Gated features: a stem rises into a bridge, leaves unfurl, roots withdraw, a tunnel clears, a
     current changes direction.
   - They use the crumble pattern (clear-of-player guard) and apply on both the live path and
     resume. Routes are valid in both states, with no circular dependencies.
5. **Regional activation.**
   - A RegionManager (0.25 s) keeps the current region and its neighbours "hot" (ticking,
     interactive), the next ring "warm" (visible, not ticking) and the rest "cold".
   - Other balls are drawn as low-poly impostors.
   - Parasites, motes and food are distance-gated.
   - Vegetation MultiMeshes are per region.
6. **Health texture.** A per-ball equirect or cube map (for example 512×256 R8), painted on the
   CPU, sampled per fragment. No splat cap.
7. **Completion v4.** Explicit ids; the v3 ids are kept verbatim; append only; `RunSave.FORMAT`
   stays 1; the percentage recalculates.
8. **Route proof v2.** Walk graph plus physics sweeps, reachability from each arrival in both
   restoration states, ravine-reset tests, and bot A* over region portals. Time budget: the gates
   are about 6 minutes each today; expect about 25–30 minutes for a playthrough to 100%.
9. **Tank re-layout.** New CENTERS and tank bounds. The aquarium dressing is derived from CENTERS.
   Vortex links are unchanged.

## Top risks (from the audit)

1. Completion ids remapped by authoring order.
2. The sphere collider, h ≥ 0 terrain and the safety net block ravines.
3. The 64-splat health array.
4. Vegetation chunking and draw cost.
5. Tank layout collisions.
6. No distance gating on the current ball.
7. Startup build time and memory: generation is GDScript at load, so bake or build lazily per
   region.
8. The bot and route proof don't scale.
9. Mixed degree and metre units, and about 60 hard-coded `dir_ll` calls in tests, the bot and
   shots.
10. Restoration-gated geometry has to be safe in both states and on resume.

## What was built (framework)

- **Stable ids (X1).** Content may carry `meta fixed_id`; `CatalogFrozen.V3` holds the 172
  shipped ids and a test proves every one still exists. Catalog v4 appends only.
- **Terrain (X2).** Cube-sphere tiles (8 m, 10×10 quads), 24 render chunks per ball and a far
  LOD mesh; concave collision per raised tile. Plateaus, and ravines carved into them
  (`add_ravine`), with the base sphere as the floor. Standing on a ravine floor (not on a
  bridge or stone above it) costs one frond and puts Gill back on the rim
  (`Game.ravine_fall`, `Axolotl.ravine_return_point`); on the last frond it is a normal death.
- **Health map (X3a).** A 512×256 equirect texture per ball; no splat cap.
- **Regional activation (X3b).** Parasites, motes and food tick only within 55 m of Gill;
  ground and vegetation chunks below the camera's horizon are not drawn.
- **Restoration gates (X3c).** `RestorationGate` (rise / grow / retract): opens when its zone
  heals, at once on a resumed save, and never moves into Gill.
- **Tank (X4a).** Ball centres spread 1.4× and the tank enlarged so every ball can double.
- **Traversal toys (X4c).** Bubble columns (`MossBall.lift_at`): he is carried up and hangs at
  the top, with his burst restored. Stone columns, fallen-stem bridges, root curtains and the sea
  fan are LevelBuilder vocabulary.
- **Bot (X4c).** Paths round ravines (end-arounds, or a standing bridge), rides columns, enters
  walled hollows by their door, and never follows a target down into a ravine.

## Mossy Meadow (world 1, the template)

Radius 24 → 48 m (surface 7,240 → 28,950 m², 4×). The original content keeps its places on the
ball (so it is twice as far apart) and its completion ids; the tutorial keeps its size in metres
(`Levels.TUT_*`, measured along the upland surface).

| Region | What is there |
|---|---|
| Glade Upland (tut, rim) | The tutorial on a 3.5 m upland over the north, its escarpment falling to the lowlands between latitude 54 and 40 |
| Great Ravine (rim) | 47 m long, 3.6 m floor: walk round either end (easy), two stone columns (skilled), a burst straight over (skilled), or the fallen stem that rises into a bridge when the glade heals |
| Split Crack (crack) | A narrower cut in the western upland, crossed by a natural stone bridge with a Mote on it |
| The Heights (heights) | Three-tier terraces on the eastern upland, a hopper leading up them, a Mote and a snail on top |
| Moss Meadow (meadow) | Rolling lowland fields; the Meadow Stone (a shelf reached from a mound) |
| East Tower lands (east) | The brittle tower and the vortex to Current Hollows |
| Coral Garden (coral) | A 7.5 m sea fan (landmark), dense tube corals, a coral shelf, a shrimp shoal |
| Southern Reed Hills (south) | The large parasite and its reed stalker among the reeds |
| West Stone Ridge (west) | A crest walk with a Mote, a natural arch, the hidden moss cave |
| Fern Grove (fern) | Tall ferns, two bubble columns up to high shelves, a second reed stalker |
| Root Hollows (roots) | Walled by six ridges; a root curtain draws up when the Southern Reed Hills heal, or climb in over a wall |

| Measure | Before | After |
|---|---|---|
| Completion ids on the ball | 25 | 75 |
| Restoration events (parasites + Motes) | 19 | 64 |
| Blooms (respawn points) | 4 | 9 |
| Registered climbs | 3 | 18 |
| Restoration gates | 0 | 2 |
| Creature groups (ecosystem) | 4 | 10 |
| Bot: tutorial, then the whole ball cleared | — | 454 s of play (seed 7), no deaths, 1 ravine fall |

The bot plays about two to three times faster than a first-time player, so the ball is roughly
15–25 minutes for a casual player, as the brief asks. The vortex to world 2 still opens at 70%
(45 of 64 events).

**Mossy Meadow review (performance).** Frame time on the standard views, software renderer (CI
style: only the relative change means anything), dev-000025 source against this build with
Meadow and Current Hollows rebuilt: Meadow views −34% / −21% / −1% (the horizon culling more than
pays for the bigger ball), cave −21%…+21% elsewhere, restored views +13…+16%. Triangles up to
1.75× on Meadow views (882k at the busiest); video memory 98 → 113 MB. The final performance pass
revisits triangle counts for phones.

**Review verdict.** The template works: the ravine reads as a hazard with four crossings, the
upland gives gentle verticality, restoration raises a bridge and opens a doorway, the bot clears
the ball without deaths, and both full playthroughs reach a legitimate 100%. Worlds 2–7 follow
with their own identities (not Meadow's layout).

## Current Hollows (world 2)

Radius 28 → 56. Water movement and terrain cuts.

| Region | What is there |
|---|---|
| The Current Shelf (cut) | An upland cut through by the Cut (24 m, 4.4 m floor) with the ball's current blowing straight across: the current bridge (a stream that carries him over), a burst jump downstream (the current helps; upstream it fights), a kelp leaf that grows across when the east ridge heals, or round either end |
| Undercut Hollows (hollows) | Overhanging coral shelves with Motes on top: step mounds up the lower two, a bubble column up the highest; a spitter parasite |
| The Mesa (mesa) | The swaying living platforms in the current (skilled), and a bubble column that starts to flow when the arrival meadow heals (easy) |
| Kelp Fields (kelp) | Tall kelp stands on the far southern side, Motes among them |
| The Still Pool (still) | The sheltered cap where the current never reaches |
| Arrival meadow, north cap cave, east ridge, south tower, far side | As before, twice as far apart |

Inside a bubble column the current no longer pushes (its upflow shelters him), so columns work on
current balls. Bot: the whole ball cleared in 428 s of play, no deaths.

## Giant Stems (world 3)

Radius 30 → 60. Vertical jungle.

| Region | What is there |
|---|---|
| The giant spiral (canopy) | As before: sixteen leaves round the giant stem to the canopy leaves and the extreme drop; now a bubble column beside it (between its lines of leaves) flows once the lower jungle heals, a shortcut halfway up |
| The Great Trunk and High Crown (crown) | A 30 m giant laddered all the way up, turning less where it is thick (75° a leaf at the base, 108° at the top) so every step is a plain jump; broad crown leaves with a Mote, a bloom and a snail; a hopper leads up the first leaves |
| The jungle | 140 laddered stems (was 70), every one climbed physically by the tests |
| The Root Tangle (tangle) | Old roots arching over one another into low tunnels on the underside, shrimp in the shade |

Motes now perch on climbing leaves too (they fell through them to the ground before, so a Mote
could not sit high on a ladder). Bot: cleared in 664 s of play, no deaths.

## Terrace Steps (world 4)

Radius 18 → 36. Layered traversal.

| Region | What is there |
|---|---|
| The Grand Terraces (grand) | Four broad tiers (the safe way: walk each ring round to its next step), a Mote and a bloom on the crown; the Twin Terrace joined at the third tier by a natural stone bridge |
| The Stone Field (field) | A basin sunk in an upland: across on stone columns (technical, a Mote on the far one), round the rim (safe), or over four broad stones that rise out of the floor once the landing heals |
| The Coral Shelves (coralsh) | Three shelves stepping up out of a coral bed |
| Terraces, arch, ridge, grotto | As before (the arch and terrace climbs start where their first step reads from the ground) |

Bot: cleared in 317 s, no deaths.

## Reed Canyon (world 5)

Radius 26 → 52. Dense vegetation and concealed geography.

| Region | What is there |
|---|---|
| The canyon (canyon, crests) | Keeps its width in metres and doubles in length; 3,000 reeds; the Reed Wall at its end parts when the canyon heals (a shortcut out towards the maze) |
| The Reed Maze (maze) | An upland threaded by two narrow ravines hidden in dense reeds (the reeds stop at the edges, so the gaps read): a fallen log, a running jump + burst, or round their ends; a reed stalker |
| The Secret Clearing (secret) | Over the log and down a tunnel through the reeds: a Mote, a bloom, shrimp, no parasites |
| The Stalker Hollow (dell) | A reed dell ringed by five mounds (sightlines from their tops), Motes on them |

Bot: cleared in 313 s, no deaths, no ravine falls (after moving a parasite off the maze's narrow
strip, where a fight was a fall waiting to happen).

## Canopy Spire (world 6)

Radius 16 → 32. The vertical movement playground.

| Region | What is there |
|---|---|
| The spire and shelves | As before; the shelves keep their spacing in metres |
| The Sky Spire (sky) | A 31 m spiral climb (thirty leaves) to a crown with the whole aquarium below; Motes halfway and on the crown; a hopper and snails on its leaves |
| The glide shaft | Beside the Sky Spire: a wide, gentle down-draft (a bubble column with a negative speed) he drifts down in from the crown, steering as he likes: gliding, the safe way down. Riding a column or drifting down a shaft is no fall; missing it is an extreme drop, which never takes the last frond |
| The Low Garden (garden) | Mounds and coral in the shelter under the spires |

Bot: cleared in 204 s (the smallest ball), no deaths.

## Hollow Grotto (world 7)

Radius 22 → 44. Caves and underground exploration.

| Region | What is there |
|---|---|
| The Glow Chamber (chamber) | The biggest grotto: glow-worms, a cave eel, a pearl on its high ledge; a boulder seals its door until the grotto heals (a restored opening) |
| The Undercut Ravine (undercut) | Through a basalt upland, crossed on two arched stone bridges or round its ends |
| The Shaft (shaft) | A 6 m basalt chimney with a bubble column up its side to its ledge |
| The Basalt Columns (columns) | Stone columns stepping up in a spiral |
| Grotto, cavelet, corridors, far side | As before (the high shelf keeps its step from the ridge in metres) |

Bot: cleared in 288 s, no deaths.

## Across the program

- **Vortex pacing.** The threshold stays 70% of a ball's events. With three to five times as many
  events the vortex now comes after most of a world has been played (Mossy Meadow: 45 of 64 events,
  about 380 s of bot play, 15–20 minutes for a first-time player); it never needs exhaustive cleanup
  (the Root Hollows, the Split Crack or the Heights can be left for later), and two minutes is
  nowhere near enough to reach it.
- **Performance** (software renderer, relative only; dev-000025 source against the final build):
  frame time −37% to +34% across the fifteen standard views, most within ±20%; triangles 1–2.9× on
  the heaviest views; draw calls 0.9–1.7×; video memory 98 → 137 MB. What keeps it there: horizon
  culling of ground and vegetation chunks, vegetation in 35 m cells drawn from their own centres
  with distance ranges, regional activation of parasites, Motes and food (55 m), the existing
  creature activation (38 m), selective shadows, and the phone's adaptive quality scaler.
- **Route proof.** The geometric audit covers every registered climb on every ball (200 climbs),
  including bubble-column lifts and paths that rise on healing; every jungle ladder and the Great
  Trunk are climbed physically; the bot clears every world from its arrival point
  (`--start=clear --ball=N`) and both full playthroughs reach a legitimate 100%.
- **Collision.** Terrain, ravines, stone columns, bridges, logs, gates and the sea fan collide with
  their drawn faces; nothing a player must reach starts in a ravine (`nothing_starts_in_a_ravine`).
- **Found in the final gates, fixed before release.**
  - A restoration gate opened instantly (when a saved run is continued) moved its drawn node but
    left its collision where it stood shut: after Continue, the Meadow's raised stem bridge would
    have had nothing under it, and a retracted wall would have stayed solid. The body now moves
    with the node; `gate_open_on_resume` checks the collision as well (it failed before the fix).
  - Leaf hoppers leap back down to the first steps of their climb; on the Great Trunk and the Sky
    Spire those were under 1 m, on the moss. They now keep to steps at least 1.2 m up, and the
    habitat check tests every perch rather than where each hopper happens to be.
  - The bot, knocked off the stem bridge, was put back on the rim beside it and kept walking its
    crossing line into the ravine. It now lines up at a bridge's end, ends the crossing when it
    falls, plans again, and walks round a crossing it has fallen off twice.

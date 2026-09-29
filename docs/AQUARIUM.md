# The aquarium — room, tank, fish, gravel and the aquarium experiences

The moss balls sit in a real aquarium in a kid's bedroom.

**Scale.** 1 unit ≈ 1 mm, and Gill is about 0.6 units long.

**Tank.** It spans `Aquarium.TANK_MIN` (−290, −110, −260) to `TANK_MAX` (290, 150, 220). The front
glass is +Z.

**Room.** It spans X −1600…1600 and Z −330…3100, with the floor at y −825. Everything in the room is
on render layer `Aquarium.ROOM_LAYER` (2).

## Gravel (`aquarium.gd` `_build_gravel`, `shaders/gravel.gdshader`, `tools/gen_gravel.py`)

- **Floor.** A height mesh with a 4-unit step, shaped by `Aquarium.floor_h(x, z)`:
  - banked up toward the back glass;
  - rolling, heaped against the glass;
  - gathered round the plant clumps and the bubbler (`FLOOR_FEATURES`).

  The bubbler, plants, snail and ooze all sit on `floor_point`.
- **Floor texture.** `gravel2_albedo` (colour, with height in the alpha channel) and `gravel2_normal`
  are generated from real pebble shapes.
  - The shader samples them twice, at different scales and rotations, and blends the two by height
    through a slow mask. The result never repeats as a grid.
  - The pebbles' own normals light the floor, and the crevices stay dark.
  - Caustics are toned down on the floor (×0.5) and on the pebbles (×0.25).
- **3D pebbles.** 48-unit tiles of instanced pebbles, 150 small and 40 big per tile. They are drawn
  only within about 100–134 units of the camera, so close views get real silhouettes and parallax.
- **Stones.** 260 larger stones over the whole floor.
- **Every stone** is one colour (`INSTANCE_CUSTOM`) with grime mottling, darkens where it sinks into
  the gravel, and shares the film that clears as the tank is restored.

## Ambient fish (`scripts/world/ambient_fish.gd`, `shaders/ambient_fish.gdshader`)

There are 13 fish at a middle scale, about 6–18× Gill's length (owner decision):

| Kind | Count | Behaviour |
|---|---|---|
| Tetra | 5 | A loose school; they scatter together |
| Gourami | 2 | Slow and curious |
| Cory | 2 | Stay near the gravel and stop often |
| Angel | 1 | Tall, slow and high in the water |
| Bala shark | 3 | Owner-requested, and the largest fish (length 11). Silver torpedoes with black-edged yellow fins: a fast, skittish trio cruising the open middle and upper water. They bolt together and regroup. |

- **Steering.** A light boid steers them: a wandering waypoint in each kind's depth band, a
  turn-rate limit, and avoidance of the glass, the gravel and every moss ball (with a margin).
- **Reaction to Gill.** Gill coming close alerts them. A very close pass or a bump sends them darting
  off, and a school scatters and then regroups.
- **Noncombatants.** They are never targeted, never hurt and never completion entries.
- **Randomness.** They use their own random generator, never the global one, so the playthroughs are
  unchanged.
- **Test:** `_test_ambient_fish` (6 checks, including `bala_trio_bolts_and_regroups`).
- **Renders:** `--test=shots --only=bala`.

## Bedroom (`scripts/world/bedroom.gd`, `tools/gen_room.py`)

A lived-in late-80s / early-90s kid's room, built as a few merged meshes. It contains:

- **Tank corner:** the tank on a dresser; the hood and its light strip; the filter, air pump and
  tubing; a food tub, a net, a power strip and cords.
- **Desk:** with homework on it.
- **Bed:** a patterned blanket and an alarm clock reading 7:42.
- **TV corner:** a CRT TV and cassettes.
- **Shelf.**
- **Floor:** a rug and things on the floor.
- **Walls:** posters (space, 90s shapes), a corkboard with notes ("feed Gill - a pinch!") and warm
  wallpaper.

The tank throws a cool light (`tank_spill`) onto nearby things. The room's light is warm.

## The aquarium experiences (`scripts/core/presentation.gd`, `scripts/ui/presentation_ui.gd`, `scripts/actors/swimmer.gd`)

**How to get there.** From the title screen ("Aquarium") or from the pause menu during play
("Aquarium"). The pause menu offers it only in ordinary play, never mid-cinematic, mid-fall or while
dead.

**Back.** Back steps out one level: Swim, Live Tank or Inspection → the room → wherever the player
came from. The on-screen Back button, Esc, the pause action and the **Android back gesture** all do
this. `quit_on_go_back` is off: in play, back opens the pause menu, and on the title it quits.

| Mode | What it is | Controls |
|---|---|---|
| **Room** | The bedroom, with the tank as its focal point. The camera has a slow breathing drift. | Tap the tank → Inspection. "Live Tank" and "Swim" buttons. |
| **Aquarium Inspection** | Leaning in at the front glass | Drag to look round the front (bounded yaw ±0.7 and pitch, always outside the glass) |
| **Live Tank** | Full screen and landscape, the phone as the tank's glass. Views: whole tank, left, right, and a slowly circling close-up of Gill in the water. | Nothing is on screen until you touch it; then Back and View appear and fade again. |
| **Swim Mode** | Gill swims freely anywhere in the tank's water | Camera-directed stick (owner decision): push toward where the camera looks, so looking up and pushing forward rises. Drag on the right to look. Up / Down / Faster (held). |

**The run is never touched.** On the way in:

- The run is saved and `Game.state` becomes `"aquarium"`, so the run clock does not count (owner
  decision: never counts).
- The gameplay axolotl is frozen and hidden exactly where he was. On the way out he is put back
  exactly there: same position, basis, velocity, facing and state.
- Parasites, Motes, food, practice targets, crumbling and swaying platforms, and the ecosystem all
  pause.
- Tier-2 actions are cancelled.
- No global random numbers are drawn.

**The tank shown is the real one.** Its restoration, water, plants, creatures and his colours are
all the player's own. A cosmetic stand-in of Gill idles and wanders a little where he really is.

**Swim Mode's body.** Swim Mode uses a separate body, `Swimmer`, and nothing in the run reacts to it.

- Blooms, shrines, Motes, food, damage, falls and the timer all look at `Game.player`, never at the
  swimmer. So Swim Mode earns nothing and Gill cannot be hurt or die.
- It collides with the terrain, leaves and platforms, and with the tank's own collision on layer
  `Aquarium.TANK_LAYER_BIT` (12): the four glass panes, the water surface as a lid, and the gravel
  as drawn. Gameplay never sees that layer, which is built on the first swim.
- It uses the swimming gait (`AxolotlModel.swim`): body undulation, legs tucked when fast, gills
  swept back.
- Fish nearby are more reactive in Swim Mode, and Gill perks up and looks at fish that come close.

**Views from the room.** Room, Inspection and the Live Tank whole-tank views look from the air:

- **Fog.** The water's haze is depth fog that begins at the glass nearest the camera. Murkier water
  hazes sooner.
- **Glass.** The glass shader's `outside` mode is clear apart from its film and algae, with a faint
  grazing sheen, the waterline meniscus and a water tint.
- **A dirty tank reads as a dirty tank from the room.** Its algae-covered glass hides most of the
  inside until it is restored.

**Tests.** `_test_aquarium_experiences` (11 checks) covers:

- 3 full rounds of every mode;
- the clock never counting;
- inspection staying outside the glass;
- the run left untouched (position, basis, earned ids, Tier 2, health and the global RNG);
- the world standing still;
- no node leaks;
- 60 s of hard swimming in every direction staying in the water and out of the moss balls;
- swimming through a parasite earning nothing and leaving Gill unhurt;
- exit restoring Gill;
- from the title back to the title;
- not available mid-cinematic.

**Renders.** `--test=shots --only=aquarium` (murky and clean), `--only=room` and `--only=gravel`.

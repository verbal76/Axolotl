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
- **Seen from the room.** From the room the tank is several hundred units away, so a fish at its
  real size is only 10–20 px long. In the outside views (Room, Inspection, Live Tank) each fish is
  drawn `Aquarium.OUTSIDE_FISH_SCALE` (3.4×) larger, with a little more colour, glow and rim
  (`pop`), and the boid keeps them further from the glass and the moss balls so the larger bodies
  never poke through. This is presentation only: their positions, speeds, steering and gameplay
  size are unchanged, and inside the tank (play and Swim Mode) they are drawn at 1×.
- **Test:** `_test_ambient_fish` (6 checks, including `bala_trio_bolts_and_regroups`), and
  `_test_aquarium_polish` (`live_tank_fish_present`, `fish_scale_only_outside`).
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
| **Swim Mode** | Gill swims freely anywhere in the tank's water | Exactly two controls (owner decision, 2026-09-30). **Left: a flight stick** that aims his nose: left and right turn him; pulling down pitches him up and pushing up pitches him down. **Right: Swim**, held to swim along his nose; let go and he glides to a stop. The camera rides behind his nose. Settings → **Invert swim up/down** reverses only the pitch. Keyboard: move keys aim, jump or lunge holds Swim. |

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
- **A dirty tank reads as a dirty tank from the room** (owner decision: murk is a progression cue).
  The algae grows in from the glass edges and corners, with a light film across the middle, so even
  the dirtiest tank looks deliberate and its fish and moss balls stay readable through the centre.
  A clean tank is clear glass.
- **Far view of the worlds.** Gameplay culls vegetation beyond 55–70 units, which is every plant
  when seen from the room. Instead of raising those ranges, each moss ball builds a thinned copy of
  its own vegetation (every 5th plant, 1.7× larger, the same meshes and materials, one MultiMesh
  per mesh) when an outside view opens, and frees it when the view closes
  (`MossBall.set_far_view`). So the tank from the room shows each world's real plant cover and
  health, and play pays nothing for it.

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

## Menus and settings (2026-09-30 package)

- **One visual language** (`scripts/ui/ui_style.gd`): dark teal panels with a mint edge, rounded
  buttons with a soft shadow, a gold border on hover and focus, a pressed state that visibly darkens
  and shifts, a pink primary button, and round slider grabbers. The title, pause menu, Settings,
  Gill's colours, the aquarium buttons and the Treasure Hunt card all use it. No default grey or
  black boxes remain.
- **Settings from the title.** A gear (the owner's artwork, `assets/ui/settings_gear.png`, used as
  supplied) sits top right of the title, a 96 px touch target. It opens the same Settings as the
  pause menu, diagnostics included. Its **Back** returns to the title, and nothing starts: no run,
  no clock, no save. The in-game Settings are unchanged. (The earlier title Settings button had been
  pushed off a phone screen by the longer menu.)
- **Invert swim up/down** is saved in `settings.cfg` `[controls] swim_invert_y` (default off). The
  settings schema stays 1.
- **Gill's colours** is a split workspace: the controls on the left in their own scrolling column,
  Gill on the right on a neutral studio stage, always visible. Drag on him to turn him (a flick keeps
  him turning briefly). Presets and sliders update him live, and scrolling or sliding never turns
  him. The colours are saved exactly as before (`[gill]`).
- **Tests:** `_test_aquarium_polish`: the two swim controls, stick pitch (default and inverted),
  turning, propulsion and glide, no drift, persistence; the Live Tank fish; the title gear, Settings
  from the title and Back; the colours split, scroll, live updates, drag-to-turn, sliders never
  turning, persistence. `_test_menu_scrollbar` covers the colours column's scrollbar.
- **Renders:** `--test=shots --only=uiq` (title, Settings from the title, the colours workspace
  scrolled, turned and recoloured, the aquarium buttons and the Swim controls).

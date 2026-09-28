# Light and atmosphere in the aquarium

Expansion 6 of the Mote open-items list. The aquarium sits in a child's bedroom, and its light has
sources there. The tank starts neglected, dull and murky, which is the game's premise. As the player
heals it, the water and glass clear, the room's light reaches in, and the tank comes alive.

## Sources

| Source | In the game | Effect in the tank |
|---|---|---|
| Ceiling light above the tank | `Aquarium.sun`, a directional light from almost straight above | The main light. Its direction drives the caustics (`lamp_dir`) and the light shafts. It casts selective shadows |
| Window (+x side of the room) | `Aquarium.window_light`, a cool directional light, no shadows | Reaches in through the side glass only as the glass clears (energy rises with clarity²) |
| Room fill and the desk lamp | Omni lights on the room layer only | Light the bedroom seen through the glass |

## What clarity changes (`Aquarium.apply`, 0 murky .. 1 clear)

| | Murky (start) | Clear (healed) |
|---|---|---|
| Water haze (fog density) | 0.017 | 0.007 (a little always remains, so the far glass and the room recede) |
| Water colour | olive green | rich aqua-blue |
| Ambient | dim, greenish | cool, low (0.62): the light has a direction, and forms model |
| Ceiling light | 0.75, greenish | 1.4, warm white |
| Shadows | faint (opacity 0.4) | crisper (0.78) |
| Window daylight | none | 0.5 |
| Light shafts | faint | clearly visible, streaked |
| Caustics | faint | bright moving web |
| Coral and anemones | grey, dead | vivid, per-ball colours (they follow the moss's own healing) |

The early game is dark but readable. The axolotl's skin has a gentle self-glow, threats glow in
their telegraphs, and the ambient never drops below 0.55.

## Techniques (all mobile-renderer, game layer: nothing depends on project settings)

- **Caustics** (`shaders/aquarium_light.gdshaderinc`) are added to the moss, plant, vegetation and
  gravel materials. Two drifting samples of the noise texture, projected along the lamp; where they
  nearly agree the light gathers into thin lines. The effect is stronger on surfaces facing the lamp,
  stronger nearer the surface, and zero in caves (`cave_factor`). It costs two texture fetches.
- **Light shafts** (`shaders/light_shaft.gdshader`) are open cones along the lamp direction. Two pass
  beside each moss ball, where the player is, and five cross open water. They are additive with soft
  edges and drifting streaks, fade with depth, and fade out within 34 m of the camera, so they never
  read as a solid cone in the face.
- **Selective shadows**: the ceiling light casts two PSSM splits out to 42 m on a 2048 map, with hard
  sampling (soft filters dither without temporal smoothing). The atlas size and filter are set at
  runtime. Terrain, stems, leaves, the axolotl and creatures cast shadows; grass, particles and
  effects do not. Big leaves and canopies shade what is under them.
- **Depth**: AgX tone mapping with a light grade (saturation 0.9, contrast 1.06). The glass
  composites the water column with a vertical gradient: brighter and greener near the surface,
  deeper and bluer toward the gravel. Less than half of the bedroom shows through it.
- **Caves**: glow-worms, the `cave_factor` darkening (−62 %) and no caustics. Enemy telegraphs keep
  their own light.
- **Near-camera plants** use an ordered 4×4 dither to fade, not per-pixel noise.

## Cost

See the performance table in `MOTE_HANDOFF.md` §E6 and the ledger (E6-19).

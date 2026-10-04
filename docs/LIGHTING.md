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
- **Selective shadows.** The ceiling light casts shadows only from a dedicated visual layer
  (`MossBall.SHADOW_CASTER_LAYER`, via `Light3D.shadow_caster_mask`). On that layer are Gill,
  the parasites' bodies, the creatures, the stems and the climbing leaves. The ~950 detailed
  climbing leaves cast through flat 8-triangle outlines of themselves (`MeshLib.leaf_shadow_proxy`,
  shadow-only). Terrain, formations and vegetation receive shadows but cast none. It uses one
  1024 shadow map over the near 30 m with hard sampling (soft filters dither without temporal
  smoothing). The atlas size and filter are set at runtime. Big leaves and canopies shade what is
  under them.
- **Quality scaling.** On a phone that cannot hold 54 fps, `QualityScaler`'s first step turns the
  shadows off (they were most of the lighting's cost), before resolution and density.
- **Depth**: AgX tone mapping with a light grade (saturation 0.9, contrast 1.06). The glass
  composites the water column with a vertical gradient: brighter and greener near the surface,
  deeper and bluer toward the gravel. Less than half of the bedroom shows through it.
- **Caves**: glow-worms, the `cave_factor` darkening (−62 %) and no caustics. Enemy telegraphs keep
  their own light.
- **Near-camera plants** use an ordered 4×4 dither to fade, not per-pixel noise.

## Cost

Measured with `--test=shots --only=perfsplit` (each Expansion 6 feature switched off in turn, and a
tally of shadow casters). In the first build, the shadow pass was nearly all of the added frame
time. Every ball's surface and every formation was redrawn into two shadow splits (about 650k
triangles in a Terrace Steps view, against about 250k without shadows). The vortices, sprouts,
corals and light shafts each cost little. With selective casters, stand-ins and one smaller map,
triangle counts are back near the pre-Expansion 6 figures. The before/after table is in
`docs/WORLD.md` (Performance, Expansion 6).

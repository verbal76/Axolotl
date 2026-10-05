# Mote UI style — primary action buttons (approved direction)

Owner direction, 2026-10-05. **Approved visual reference for the next Mote UI pass.** Not yet implemented:
Mote is feature-frozen and v97 is in physical test, so no button was changed. Apply it in the next
authorized UI pass.

## Reference

The owner pointed to the large green/aqua primary button of a popular mobile game (a style reference
only). What the owner likes:

1. The wide, rounded **pill** shape.
2. Above all, the **surface colour**: not a plain left-to-right gradient but crisp, softly blended,
   slightly irregular regions of neighbouring greens and aquas flowing into one another (almost
   tie-dyed / fluid).

**Do not copy** that game's branding, exact colours, typography, assets, icons or layout. Translate the
idea into Mote's own aquarium identity.

## The style: organic colour inside, razor-clean edges outside

- **Shape:** wide, friendly pill (fully rounded ends), a very clean, crisp silhouette; no bevel.
- **Fill:** softly blended irregular colour regions in aqua, turquoise, fresh aquatic green and a
  restrained moss tone, as if lit by refracted aquarium light, moving water or organic underwater
  colouring. A few large soft regions, never hard bands or stripes; no obvious single-direction gradient.
- **Quality:** clean and polished, not cloudy; organic, not psychedelic; bright and inviting, not neon.
- **Avoid:** hard colour bands, heavy glow, glossy/plastic highlights, busy texture.
- **Typography and icons:** crisp, high-contrast, highly readable (the clean edge is the contrast to
  the fluid fill).
- **Motion (optional, subtle):** at most a very slow drift of the colour regions; never distracting,
  never on every button at once.

## Where it applies (hierarchy)

Primary actions only, so they read as one family: Continue, Start / New Run, Resume, Confirm, Play and
equivalent single most-important actions on a screen. **Not** every button: secondary and tertiary
actions, toggles, list rows, the HUD action buttons and small icon buttons keep their current quieter
styles, so a primary action stays recognisable. At most one primary-styled button per panel where
possible.

## Implementation notes for that pass (when authorized)

- One shared primary-button style (a single `StyleBox` / shader-backed panel and theme variation) used
  by every primary action, not per-screen copies.
- The fluid fill can be a small canvas shader (a few low-frequency noise blobs mixed between 3-4 palette
  colours, anti-aliased rounded-rect mask for the pill) or a pre-rendered texture; keep it cheap on
  mobile and static if motion costs anything noticeable.
- Keep existing touch target sizes and the no-scroll menu fits (existing UI fit tests must still pass);
  check text contrast on every fill region.
- Verify with menu screenshots (`--test=shots`) before any release.

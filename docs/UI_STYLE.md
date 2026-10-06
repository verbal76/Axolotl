# Mote UI style — primary action buttons (approved direction)

Owner direction, 2026-10-05; implemented 2026-10-06 (owner go-ahead after v97 passed physical test).
See "As built" at the end.

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

## As built (2026-10-06)

- **One component:** `UiStyle.make_primary(button)` (or `UiStyle.primary_button(text, cb)`). It sets the
  `PrimaryButton` theme variation (deep sea-teal text `PRIMARY_INK`, no outline, gold pill focus ring)
  and adds an internal `PrimaryFill` control drawn by `shaders/primary_button.gdshader`, sized from the
  button's own rect plus an 8 px shadow margin, so the round ends are computed, never stretched.
- **Fill:** smooth value noise, domain-warped, turned and drawn out along the pill (round regions on a
  pill five times wider than tall read as vertical stripes), mixing `PRIMARY_FILL` (aqua, turquoise,
  aquatic green, moss); slightly brighter above, a hairline light rim at the top, a dark hairline outline,
  a soft drop shadow, a whisper of dither against banding. Each button gets its own seed.
- **Motion:** none. A slow drift was judged not clearly better than the still fill; still costs nothing
  per frame (the shader reads no time; test `primary_fill_still`).
- **States:** hover/focus lift a little, a press darkens and sinks 1.5 px, disabled turns to a quiet deep
  teal pill with pale text (`primary_states_drawn`).
- **Where (by role):** title Play/Continue, pause Resume, tutorial card action (Begin / Got it), skill
  card Unlock, finished-hunt card New hunt. The About page's Close and the Aquarium's Live Tank keep the
  pink they had, under their own `AccentButton` variation. Everything else is unchanged
  (`primary_buttons_by_role`).
- **Contrast:** text ≥ 7:1 against every fill colour, ≥ 4.5:1 at the darkest shading (`primary_text_contrast`).
- **Renders:** `--test=shots --only=primary` (each screen plus 3x close-ups; run with `--resolution
  1560x720` for the phone shape).

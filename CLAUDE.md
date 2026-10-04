# Mote — standing project requirements

## Hot Attic Games studio splash (standing, owner directive 2026-10-04)

- Every cold launch shows, in order: APP START → HOT ATTIC GAMES SPLASH → PRODUCT TITLE → experience.
- The only studio logo is the owner-supplied file **`Hot_Attic_Games_Master_Logo_ALPHA_FINAL.png`**
  (repo root, `res://Hot_Attic_Games_Master_Logo_ALPHA_FINAL.png`, 1536×1024 RGBA with transparency).
  Never redraw, crop, distort, recolour or substitute it. `branding/Hot_Attic_Games_Master_Logo.png` is obsolete.
- About 2–3 s with fades, aspect ratio and transparency kept, simple black background, cold launch only;
  it masks startup work, never strands the user, and must not break OTA, saves or navigation.
- Implementation: `scripts/ui/studio_splash.gd` (the one splash system — do not add a second).
  Details: `docs/HOT_ATTIC_INFRA.md` §4. Tests: `hag_splash_*` in `scripts/tests/hag_tests.gd`.

## Native freeze

`project.godot`, `export_presets.cfg` and `scripts/boot/*` are frozen (runtime r5);
`python3 tools/ota_runtime.py --check` must print OTA-compatible.

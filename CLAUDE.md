# Mote — standing project requirements

## Hot Attic Games studio splash (standing, owner directive 2026-10-04)

- Every cold launch shows, in order: APP START (neutral native frame) → HOT ATTIC GAMES SPLASH → PRODUCT TITLE → experience.
  The studio splash is the FIRST branded image: no Mote artwork in Android's launch screen or the engine
  boot splash (`application/boot_splash/*`, export `splash_screen/*`). Guarded by
  `hag_native_launch_neutral_before_studio_splash`; the r5 APK is the one recorded exception (fixed in r6).
- The only studio logo is the owner-supplied file **`Hot_Attic_Games_Master_Logo_ALPHA_FINAL.png`**
  (repo root, `res://Hot_Attic_Games_Master_Logo_ALPHA_FINAL.png`, 1536×1024 RGBA with transparency).
  Never redraw, crop, distort, recolour or substitute it. `branding/Hot_Attic_Games_Master_Logo.png` is obsolete.
- About 2–3 s with fades, aspect ratio and transparency kept, simple black background, cold launch only;
  it masks startup work, never strands the user, and must not break OTA, saves or navigation.
- Implementation: `scripts/ui/studio_splash.gd` (the one splash system — do not add a second).
  Details: `docs/HOT_ATTIC_INFRA.md` §4. Tests: `hag_splash_*` in `scripts/tests/hag_tests.gd`.

## Vortex navigation colours (permanent, owner rule 2026-10-04)

- **Vortex / water-tunnel colour = DESTINATION IDENTITY.** Each connection's hue (`Vortex.TINTS`, by link)
  lets the player remember which tunnel leads where (arrived through green → green is the way back).
  It must NEVER change with readiness, distress or anything else about travel state.
- **Pad colour = CONNECTION / TRAVEL READINESS.** Only the flat landing/launch pad (the tidal pool at the
  base) shows it: muted red = not usable yet, muted green = usable, with pattern/brightness/motion cues too.
  Driven only by `Vortex.travel_ready()` (the same call the entry check uses).
- So a blue vortex can sit over a red pad or a green pad. Guarded by `vortex_identity_colour_never_follows_readiness`.

## Primary action buttons (owner direction 2026-10-05, implemented 2026-10-06)

Primary actions (Continue/Play, Resume, Begin/Got it, Unlock, New hunt: chosen by role, never by text) are
wide pills with an organic, softly blended aqua/turquoise/aquatic-green/moss fill and razor-clean edges
and typography; every other menu button/toggle is a quiet pill of the same family (dark fill, faint
aqua rim: `SecondaryButton`/`SecondaryToggle`, owner option 2, 2026-10-06). Use the one shared component `UiStyle.make_primary()`
(never a per-screen copy). Style reference only: never copy another game's branding or assets.
Details: `docs/UI_STYLE.md`. Tests: `primary_*` in `_test_primary_buttons`.

## GitHub Actions budget (standing owner directive, 2026-10-06)

Actions minutes are scarce and shared. Before any GitHub-hosted run ask: "Does this need Actions, or can I
prove it locally?" Validate locally first (check_scripts, runtime lock, both unit shards and the playthrough;
recipe in `docs/ACTIONS_BUDGET.md`); push to the release branch only a locally-green release candidate (every
push there publishes an OTA). Docs/Markdown/workflow-only changes start no workflow and carry `[skip ci]`.
No re-runs to "see if a flaky test passes", no unrequested platform builds (iOS only by manual input; APK
only on a native change or on request), no rebuilding a SHA with a verified result. Never trim the OTA
release gates (tests, baked export, logo, signing, verification) to save minutes.

## Native freeze

`project.godot`, `export_presets.cfg` and `scripts/boot/*` are frozen (runtime r6, the 2026-10-09 playtester
APK with the neutral native launch frame; r5 = Android build 22 before it);
`python3 tools/ota_runtime.py --check` must print OTA-compatible.

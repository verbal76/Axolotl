# Mote — requirement ledger (cumulative, 2026-09-27, updated for the one-app release: Mote b22, runtime r5)

This ledger covers every substantive owner requirement given today. Later explicit owner decisions supersede
earlier ones only where the owner changed them.

Status values are:
- **I+V**: implemented and verified;
- **I+NYV**: implemented, not yet verified;
- **PARTIAL**;
- **NOT IMPL**;
- **BLOCKED**;
- **SUPERSEDED**.

"Verified" means an automated check or a rendered capture ran in this environment. No physical device was
available, so nothing here is claimed as device-verified.

Test names refer to `scripts/tests/unit_tests.gd`, `scripts/tests/ota_tests.gd` (both in the unit suite),
`scripts/tests/playthrough_bot.gd`, `tools/ota_e2e_local.sh` (e2e) and `tools/version_drift_check.sh` (drift).

## G — original game specification

| ID | Requirement | Status | Implementation | Evidence | Superseded by |
|---|---|---|---|---|---|
| G-01 | Godot 4 engine (owner-ruled) | I+V | Godot 4.7.2, `project.godot` | all suites run on 4.7.2; CI verify job | |
| G-02 | Original procedural assets (geometry, shaders, audio) | I+V | `scripts/world/mesh_lib.gd`, `shaders/`, `tools/gen_*.py` | builds and renders from source | |
| G-03 | Three spherical moss balls in one aquarium | I+V | `scripts/world/levels.gd` | `reached_ball2`, `reached_ball3`, `all_three_balls_reach_100` | |
| G-04 | Sphere-centred gravity, full surface traversal, stable orientation | I+V | `scripts/actors/axolotl.gd` | `sphere_walk_full_circle`, `stays_on_surface`, `sphere_walk_mostly_grounded` | |
| G-05 | Camera-relative movement with acceleration/deceleration | I+V | `axolotl.gd` | `sphere_walk_*`, `tutorial_jump_then_burst_route` | |
| G-06 | Four-legged underwater scuttle | I+V | `axolotl_model.gd` (salamander gait on spine) | `--test=model` walk renders | |
| G-07 | Push-off first jump | I+V | `axolotl.gd` | `jump_apex` | |
| G-08 | Coyote time | I+V | `axolotl.gd` | `coyote_jump` | |
| G-09 | Jump buffering | I+V | `axolotl.gd` | `jump_buffer` | |
| G-10 | One directional airborne water burst; resets on landing; no double jump | I+V | `axolotl.gd` | `burst_on_second_press`, `burst_follows_direction`, `no_third_air_action`, `landing_resets_burst` | |
| G-11 | Assisted over-the-shoulder camera, no pole flip | I+V | `scripts/camera/follow_cam.gd` | `camera_no_flip` | |
| G-12 | Manual right-side camera swipe | I+NYV | `scripts/ui/hud.gd` | no automated drag test; not tried on a device | |
| G-13 | Diegetic **dorsal** health indicators, 3 active / 3 dormant | SUPERSEDED | | | F-05, F-06 |
| G-14 | 3 unlockable health (one per cave), max 6 | I+V | `platforms.gd` Upgrade, `level_builder.gd` cave | `three_cave_upgrades_to_six`, playthrough upgrades | |
| G-15 | Feeding lunge | I+V | `axolotl.gd`, `game.gd` | `mote_captured_with_lunge`, food tests | |
| G-16 | Three food organisms (+1, +2, full); eating at full health | I+V | `scripts/actors/food.gd` | `drifter_restores_1`, `darter_restores_2`, `burrower_restores_all`, `eat_at_full_health` | |
| G-17 | Distinct food behaviours (drifter, darter senses and darts, burrower retreats) | I+V | `food.gd` | `darter_senses_and_darts`, `burrower_retreats_and_reemerges` | |
| G-18 | Food repopulation out of view | I+V | `game.gd` | `food_repopulates_out_of_view` | |
| G-19 | Regeneration Motes wander, never auto-collected | I+V | `scripts/actors/mote.gd` | `mote_not_auto_collected` | |
| G-20 | Mote local light | I+V | `mote.gd`, pooled lights in `game.gd` / `quality_scaler.gd` | rendered `14_mote` shot | |
| G-21 | Deliberate lunge capture restores the patch | I+V | `mote.gd`, `game.gd` | `mote_captured_with_lunge` | |
| G-22 | Near miss pushes the Mote | I+V | `game.gd` `lunge_miss` | `mote_pushed_by_near_miss` | |
| G-23 | Localised water response and lightweight vegetation response | I+NYV | `scripts/world/water_fx.gd`, `shaders/vegetation.gdshader` impulses | no automated assertion | |
| G-24 | Parasites with 1/2/3-hit durability classes | I+V | `scripts/actors/parasite.gd` | `swipe_kills_small_behind`, `medium_*`, `large_three_stage_desaturation` | |
| G-25 | Head-to-rear desaturation; no enemy health bars | I+V | `parasite.gd`, `shaders/parasite.gdshader` | `desaturation_head_to_rear` | |
| G-26 | Telegraphed parasite attacks | I+NYV | `parasite.gd` windup state | not asserted by a test | |
| G-27 | Dead parasites drift away, then debris hand-off | I+V | `parasite.gd` | `dead_parasite_drifts_then_handoff` | |
| G-28 | Directional ~180° tail swipe | SUPERSEDED | | | F-02 |
| G-29 | No dedicated dodge button (3 action buttons) | I+V | `hud.gd` | HUD renders (stick + 3 buttons) | |
| G-30 | Hard landings: kill small, one stage + knockback on medium | I+V | `game.gd` `pressure_wave` | `hard_landing_kills_small`, `hard_landing_one_stage_on_medium` | |
| G-31 | Four personality landing variants | I+NYV | `axolotl_model.gd` `_animate_landing` | no test asserts each variant | |
| G-32 | Extreme canopy drop: telegraph, 2 stages, costs 1 health, never the last | I+V | `axolotl.gd`, `game.gd` | `dangerous_fall_telegraph`, `extreme_*`, `fall_never_removes_final_segment` | |
| G-33 | Flexible leaves cushion falls and rebound | I+V | `scripts/world/platforms.gd` FlexLeaf | `flex_leaf_cushions_fall`, `flex_leaf_modest_rebound` | |
| G-34 | Checkpoint moss blooms | I+V | `scripts/actors/bloom.gd` | `bloom_activates`, `tutorial_bloom_checkpoint` | |
| G-35 | Regeneration (no death screen), full health, progress kept | I+V | `game.gd` regen cinematic | `death_enters_regeneration`, `regenerates_at_last_bloom`, `regeneration_restores_health`, `restoration_survives_regeneration` | |
| G-36 | Brittle parasite-damaged moss crumbles and regrows | I+V | `platforms.gd` Crumble | `brittle_moss_crumbles`, `brittle_moss_regrows` | |
| G-37 | Continuous local and per-ball restoration; no percentages shown | I+V | `moss_ball.gd` health field, `hud.gd` (no readout) | restoration tests; HUD renders | |
| G-38 | Continuous global aquarium restoration (water, gravel, ooze, algae, bedroom) | I+V | `scripts/world/aquarium.gd` | `aquarium_changes_continuously`, `aquarium_fully_clean` | |
| G-39 | Vortex grows continuously and connects at ~70% with a cinematic | I+V | `scripts/world/vortex.gd`, `game.gd` | `vortex_grows_continuously`, `vortex_closed_below_70`, `vortex_connects_at_70_with_cinematic` | |
| G-40 | Bidirectional vortex travel; Gill surfs and enjoys it | I+V | `vortex.gd`, travel cinematic, model `surf` pose | `vortex_travel_to_ball2`, `vortex_bidirectional`; `16_vortex_surf` render | |
| G-41 | Restoration-responsive music; bedroom sounds recede | I+NYV | `scripts/core/audio_director.gd`, `assets/audio/`; music is the owner's two songs (M-01), muffled while the current ball is murky | songs asserted by `music_*` (M-01); the muffling and bedroom sounds not listened to or asserted | |
| G-42 | Moss Ball #1: classic marimo and tutorial | I+V | `levels.gd` `_ball1` | `tutorial_*`, `tutorial_under_60s` | |
| G-43 | Moss Ball #2: current changes walking, jumping and parasite knockback | I+V | `moss_ball.gd` `current_at`, `levels.gd` `_ball2` | `current_affects_traversal`, `current_affects_jumps`, `current_carries_knocked_parasite` | |
| G-44 | Moss Ball #2 mesa reachable only by current-swayed plants | I+V | `platforms.gd` SwayLeaf | playthrough "on mesa top: true" | |
| G-45 | Moss Ball #3 jungle: dense vegetation, spiral canopy climb | I+V | `levels.gd` `_ball3` | playthrough canopy climb and drop | |
| G-46 | One optional interior cave per ball | I+V | `level_builder.gd` `cave` | playthrough caves on all 3 balls | |
| G-47 | Backtracking between balls | I+V | vortex travel | `backtrack_to_ball2`, `backtrack_to_ball1` | |
| G-48 | Full restoration → quiet payoff → ALL CLEAR → free roam | I+V | `game.gd`, `hud.gd` | `all_clear_after_quiet_period`, `free_roam_after_all_clear`, `all_clear_shown`, `free_roam_continues` | |
| G-49 | Landscape only | I+V (config) | `project.godot` orientation 4 | config; no device check | |
| G-50 | Touch HUD: left stick, Jump/Burst, Swipe and Lunge buttons | I+V | `hud.gd` | `touch_restores_controls`; HUD renders | |
| G-51 | Reduced HUD | I+V | `hud.gd`, `settings.gd` | `reduced_hud_fades_controls` | |
| G-52 | Bluetooth controller support with automatic touch/controller switching | I+V (simulated input) | `settings.gd`, `hud.gd` | `controller_input_hides_touch_controls`; no real controller used | |
| G-53 | Minimal pause/settings | I+V | `scripts/ui/pause_menu.gd` | `pause_menu_pauses`, `pause_menu_resumes` | |
| G-54 | Optional haptics | I+V (setting) | `settings.gd` | `haptics_toggle`; vibration not felt on a device | |
| G-55 | 60 FPS target with automatic thermal/performance scaling | I+NYV | `scripts/core/quality_scaler.gd` | desktop only (headless ~0.8–1.2 ms/frame); no phone measurement | |
| G-56 | Safe-area handling | I+NYV | `hud.gd` safe-area insets | no notched device or test | |
| G-57 | Normal build fully offline | SUPERSEDED | | | R-01 (offline-capable, not offline-only) |
| G-58 | Beginning-to-end verification | I+V (desktop) | `playthrough_bot.gd` | 12/12 on seeds 4242 and 7 | |
| G-59 | Title: live aquarium background, Gill visible, minimal menu | I+V | `scripts/ui/title_screen.gd` | title render (see F/N rows) | |
| G-60 | Honest delivery notes and limitations | I+V | `README.md` | | |

## F — owner feedback and decisions today

| ID | Requirement | Status | Implementation | Evidence | Superseded by |
|---|---|---|---|---|---|
| F-01 | Elevated platforms must not render one-sided or hollow | I+V | `mesh_lib.gd` winding | `cushion_faces_outward`, `stem_faces_outward`, `cave_dome_faces_correct_side` | |
| F-02 | Swipe covers ~270° with a nudge toward the nearest enemy | I+V | `game.gd` `swipe_aim`, `player_swipe` | `swipe_misses_front_cone`, `swipe_hits_270_arc`, `swipe_aim_turns_and_hits_ahead` | |
| F-03 | Smooth rolling hills instead of sunk spheres | I+V | `moss_ball.gd` terrain | `terrain_*` (6 checks); `terrain_*` renders | |
| F-04 | Gill resembles the reference: face, gills, snake-like fluid body and legs | I+V | `axolotl_model.gd`, `shaders/gill.gdshader` | `--test=model` renders (front, side, walk, jump, swipe) | |
| F-05 | The six gills are the health display (owner answer) | I+V | `axolotl_model.gd` `_update_gills` | `gills_glow_when_active_dull_when_lost` | |
| F-06 | Always six gills; health goes from glowing colour to dull and faded when lost | I+V | `axolotl_model.gd` | `six_gills_always_full_size`, `gills_glow_when_active_dull_when_lost` | |
| F-08 | Title stays restrained: no leftover controls or prompts on it | I+V | `hud.gd` `prompts_shown()` | `prompts_hidden_with_controls_eg_on_title`; `docs/screenshots/title_mote.jpg` | |
| F-07 | Install icon from the owner's artwork, everywhere | I+V (APK contents) / needs phone (launcher) | `assets/icon/*`, `tools/make_icons.gd`, the Android preset, `config/icon`; boot splash uses the same artwork (S-06) | `launcher_icons_configured`, `app_icon_is_owner_artwork`; CI b22 APK badging icon; launcher appearance not yet seen on the phone | |
| F-09 | Floating food is catchable (owner: "always above me"; chose lower hover + aimed lunge, darters included) | I+V (automated) | `food.gd` hover 0.3–0.9 m and wake calm; `game.gd` `lunge_target`, catch radius 0.95; `axolotl.gd` lunge homing | `food_hovers_at_head_height`, `lunge_rises_and_turns_to_high_food` (fails with the aim disabled), `lunge_ignores_food_out_of_reach`, `lunge_reach_stays_below_jump`, `lunge_wake_leaves_food_in_place`; feel on the phone not yet verified | drifter hover 0.6–1.8 m |

## O — development OTA channel

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| O-01 | Native shell vs OTA-replaceable game layer | I+V | `scripts/boot/`, `docs/OTA.md` | e2e |
| O-02 | Bootstrap autoload loads the pack before game resources | I+V | `boot.gd` `_init` | e2e steps 9–10 |
| O-03 | `user://ota` storage with an atomic state file | I+V | `ota_core.gd` | unit OTA tests |
| O-04 | Immutable, versioned manifest; mutable channel pointer | I+V | `ota_make_manifest.gd`, `ota-publish.yml` | unit tests, e2e |
| O-05 | Exact source SHA in the manifest | I+V | manifest `source_sha` | e2e step 11 |
| O-06 | Runtime-ID compatibility gate | I+V | `ota_config.gd`, `tools/ota_runtime.py`, `ota/runtime_lock.json` (now r5) | `ota_runtime_mismatch_needs_native_update`, `ota_r3_app_rejects_r4_ota`, `ota_r4_app_rejects_r3_ota`; the gate caught every native change (r3→r4→r5) |
| O-07 | Publisher workflow: tests, PCK, hash, signed manifest, release, pointer, receipt | I+V | `.github/workflows/ota-publish.yml` | `dev-000008` from `d235cb2` (run 36334069998): receipt `published: true`, `pointer_moved: true`; re-downloaded objects re-verified in CI and again independently (signature, PCK SHA-256 and size, `ota_inspect_pack` INSPECT OK) |
| O-08 | Full PCK first, no deltas | I+V | | e2e |
| O-09 | Download to a temp file, then verify size, SHA-256 and signature | I+V | `ota_updater.gd`, `ota_core.gd` | `ota_hash_mismatch_rejected`, `ota_truncated_download_rejected`, e2e step 15 |
| O-10 | Download now, activate on the next clean restart | I+V | `ota_core.gd` | `ota_stage_marks_pending`, `ota_boot_loads_pending`, e2e |
| O-11 | Transactional CURRENT / PREVIOUS / PENDING and rollback | I+V | `ota_core.gd` | `ota_rollback_*`, e2e step 16 |
| O-12 | Boot-health checkpoint with fallback | I+V | `boot.gd`, `ota_core.gd` | `ota_unhealthy_candidate_abandoned`, e2e unhealthy OTA |
| O-13 | Recovery (boot baseline) reachable even when game UI is broken | I+V (scripted) / I+NYV (gesture) | overlay in `boot.gd` (F9, five taps top-left) | e2e disable/enable; tap gesture not tried on a device |
| O-14 | SHA-256 mandatory plus signed manifests | I+V | RSA verify in `ota_core.gd` | `ota_signature_verifies`, `ota_tampered_manifest_rejected`, `ota_wrong_key_rejected` |
| O-15 | Save-schema compatibility gate | I+V | `ota_core.gd` `save_compat` | `ota_newer_save_blocks_older_ota` |
| O-16 | `dev` channel only (channels are pointers) | I+V | `ota_config.gd`; the one Mote app follows `dev` | `ota_channel_mismatch_rejected` |
| O-17 | Diagnostics fields and controls | I+V (text, actions) / I+NYV (touch buttons) | `boot.gd`, `diagnostics_overlay.gd` | `diagnostics_*` tests; buttons not exercised |
| O-18 | Stable HTTPS publication (GitHub Releases) | I+V | `ota-publish.yml` | `ota-dev-000008` release and `ota-channel-dev/latest.json` served publicly |
| O-19 | One real Android end-to-end proof | needs phone | | partial owner evidence: Mote Dev b21 discovered, downloaded and verified dev-000013 (owner's Diagnostics, 18:58 UTC). Full proof needs the current Mote b22 and a newer OTA; see S-14 and MOTE_HANDOFF.md §16 |
| O-20 | Docs: OTA-safe vs APK-required changes | I+V | `docs/OTA.md` | |
| O-21 | Tests: manifest, runtime mismatch, hash, state transitions, rollback | I+V | `ota_tests.gd` | 29 OTA checks |
| O-22 | Every push to the dev branch publishes an OTA | I+V | `ota-publish.yml` trigger | push of `d235cb2` published `dev-000008`; each later push publishes the next id |

## V — game version and identities

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| V-01 | Audit map before editing | I+V | reported in session | |
| V-02 | One canonical `GAME_VERSION` = 0.1.0 | I+V | `scripts/core/game_version.gd` | `game_version_is_one_literal` |
| V-03 | Title shows `v<version>` from the canonical value | I+V | `title_screen.gd` | `title_shows_canonical_version`, drift |
| V-04 | Diagnostics game version | I+V | `boot.gd` | `diagnostics_identity_game_version`, `diagnostics_text_game_version` |
| V-05 | CI reads the version and generates build metadata | I+V | `tools/print_identity.gd`, `build.yml` `build-info.json` | CI ident step; drift |
| V-06 | OTA metadata records the version, checked inside the pack | I+V | `ota_make_manifest.gd`, `ota_inspect_pack.gd` | drift, e2e; CI publish of `dev-000008` INSPECT OK (pack 0.1.0 = manifest = canonical) |
| V-07 | Save metadata carries identity | I+V | `settings.gd` `save_meta` | `save_meta_game_version_and_schema` |
| V-08 | versionCode = CI run number; versionName = native version | I+V | `build.yml` | CI badging `versionCode='9' versionName='0.1.0'` |
| V-09 | Identity separation (SHA, run, OTA, build, schema) | I+V | `boot.gd` `identity()` | `ota_identity_independent_of_game_version`, `native_identity_survives_ota_activation`, `source_and_run_follow_active_ota`, `save_schema_independent` |
| V-10 | Drift regression proving derivation | I+V | `tools/version_drift_check.sh` (CI verify) | mutation run passes; a hard-coded title fails it |
| V-11 | Active OTA means the OTA actually running | I+V | `boot.gd` uses `core.active` | e2e identity lines |
| V-12 | Save schema is independent | I+V | `scripts/core/save_schema.gd` | `save_schema_independent` |

## N — product and character naming

| ID | Requirement | Status | Implementation | Evidence | Superseded |
|---|---|---|---|---|---|
| N-01 | Product "Mote"; title "MOTE" from the canonical source | I+V | `game_version.gd` `PRODUCT_NAME`, `title_screen.gd` | `title_shows_MOTE_from_canonical`; `docs/screenshots/title_mote.jpg` | replaces the "Axolotl" working title |
| N-02 | Protagonist "Gill" on player-facing and diagnostic surfaces | I+V | `CHARACTER_NAME`; diagnostics | `diagnostics_product_and_character` | |
| N-03 | No new exposition ("Meet Gill", "Gill's Adventure") | I+V | | `no_new_exposition_or_name_copies` | |
| N-04 | App label "Mote" | I+V | `export_presets.cfg` | CI b22 badging: `application-label:'Mote'`, package com.verbal76.axolotl. ("Mote Dev" retired, S-01) | replaces "Axolotl" / "Axolotl Dev" |
| N-05 | Package, bundle, signing and OTA identities unchanged | I+V | | `package_ids_unchanged` (com.verbal76.axolotl); certificate and OTA key pins unchanged. com.verbal76.axolotl.dev retired with the Mote Dev app | |
| N-06 | Regeneration Motes keep their name | I+V | `mote.gd` | `regeneration_motes_keep_their_name` | |
| N-07 | No blind refactor of technical identifiers | I+V | `AxolotlModel`, `axolotl.gd`, repo name and package IDs kept | code review | |
| N-08 | Docs describe Mote and Gill | I+V | README, `docs/*` | | |

## C — Mote credentials

| ID | Requirement | Status | Implementation | Evidence | Superseded |
|---|---|---|---|---|---|
| C-01 | New OTA signing keypair; private half only in `MOTE_OTA_SIGNING_KEY` | I+V | new public key in `ota_config.gd` | local sign/verify self-test | first dev key retired |
| C-02 | New PKCS12 keystore, alias `mote_dev`, strong password | I+V | owner's secrets file | keytool open, base64 round-trip identical | first dev keystore retired |
| C-03 | Workflows use `MOTE_*` secret names | I+V | `build.yml`, `ota-publish.yml` | grep shows no generic names | `OTA_SIGNING_KEY`, `ANDROID_DEV_KEYSTORE_B64` |
| C-04 | No private material tracked; `.gitignore` guards | I+V | `.gitignore` | tracked-file and diff scans | |
| C-05 | Owner receives exact values and locations | I+V | secrets file sent | | |
| C-06 | CI shows secret names only, verifies signatures and the APK certificate | I+V | workflows | logs show presence and structure only; apksigner certificate equals the pinned A8:4F:…:E2:C3; the derived OTA public key equals the embedded key and pin `a003a45c…0cf2` | |
| C-07 | Old key retired cleanly; runtime bumps recorded | I+V | `ota/runtime_lock.json` | `ota_runtime.py --check`: r2 (key), r3 (themed icon), r4 (OTA in the Mote app), r5 (startup, splash, shader baker) | |

## A — CI and the end-of-day APK

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| A-01 | CI functional and green | I+V | Build & Verify #22 (run 36352308882: tests + playthrough, Android, iOS) and OTA publish #14 (run 36352306690) green on the release commit `1046057`; the new baked-shader export and APK self-verification ran green on their first CI run |
| A-02 | New APK built from the final native source | I+V | current APK **b22** (`mote-v0.1.0-b22.apk`, Mote, source `1046057`, runtime r5, SHA-256 `7305593e…0aa6924`), signed with the Mote key (certificate pin enforced), built from the branch commit. b21/r4 and b18/r3 superseded |
| A-03 | APK identity report (SHA-256, versionCode, …) | I+V | from the b18 Android job log (Build & Verify run 36335461294) |
| A-04 | Later game changes reach that APK by OTA | I+V | game-layer commits after `1046057` keep r5 (`ota_runtime.py --check`); each push publishes a signed r5 OTA that b22 accepts; an OTA from the APK's own commit is reported up to date (S-10) |
| A-05 | Physical-device verification | BLOCKED | owner's phone (procedure: MOTE_HANDOFF.md §16) |
| A-06 | One Mote APK artifact | I+V | Build & Verify uploads `mote-android-v0.1.0-b<build>` (the APK and `build-info.json`) only; the Mote Dev artifact is retired (S-01) |

## R — OTA delivery rectification (owner ruling, 2026-09-27)

Owner ruling: **Mote is offline-capable, not offline-only.** No connection is needed to play; the installed
Mote app checks for signed, compatible OTAs whenever a connection happens to be available, and never waits
for one. Cause: the owner's phone ran the normal b18 APK (`Flavor: normal`, `OTA Enabled: no`), which had
no OTA client and no INTERNET permission, so dev-000011/dev-000012 could never reach it.

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| R-01 | The Mote app the owner plays receives OTAs and stays fully playable offline | I+V (build) / needs phone | `export_presets.cfg` (Android: `ota` feature + INTERNET), `ota_config.gd` `FEATURE := "ota"` | `normal_build_ota_capable`, `ios_build_has_no_ota`; CI b22: INTERNET present; the APK's bundled game reports `ota_enabled: true`, channel dev |
| R-02 | Pre-rectification audit: dev-000012 contains all work after b18 | I+V | | every change `854ea84..227d0ab` classified: food/lunge in `axolotl.gd`, `food.gd`, `game.gd` present (A); ledger (C); tests present (C). Published PCK vs local export of `227d0ab`: all compiled scripts byte-identical (only `main.scn` random node id, `uid_cache.bin` and a stray CI `identity.json` differ); INSPECT OK; run from the published PCK itself: food/lunge tests 5/5, unit 133/141 (the 8 read raw `.gd`/`export_presets.cfg`/icon sources that exports omit), playthrough 12/12 on seeds 4242 and 7. Missing: none |
| R-03 | Complete game bundled; start never waits for the network | I+V | `boot.gd` mounts only verified local packages in `_init`; checks start after boot health | e2e: boots and reaches health with no channel and with a hanging channel ("startup never waited for the network"); `ota_offline_gameplay_continues` |
| R-04 | Automatic check: at start, on resume, periodically; no hammering | I+V | `Boot.auto_check()`, `auto_check_due()` (start; resume ≥ 15 min; periodic 60 min; failures count) | `ota_auto_check_policy`, `ota_auto_check_waits_for_health_and_ota`; e2e "automatic check runs after start" |
| R-05 | Every OTA failure is non-fatal and keeps the known-good game | I+V | `ota_updater.gd` statuses; not threaded (Godot 4.7.2 threaded HTTPRequest ignores `timeout` on a server that never answers) | `ota_offline_check_nonfatal`, `ota_hanging_server_does_not_block`, `ota_client_rejects_bad_signature`, `ota_client_rejects_bad_hash`, `ota_client_ignores_older_runtime`, `ota_client_newer_runtime_needs_new_app`, `ota_interrupted_download_keeps_known_good`, `ota_download_retry_after_interruption`; e2e offline playthrough 12/12 with the channel unreachable |
| R-06 | Manual controls: check, download, activate, restart, roll back, bundled baseline, re-enable | I+V (actions) / I+NYV (touch buttons) | `diagnostics_overlay.gd` (Activate/Roll back enabled only when they apply) | e2e rollback/disable/enable; buttons not exercised on a device |
| R-07 | Diagnostics: bundled / active / latest / pending / channel / enabled / runtime compatibility / last check / status | I+V | `boot.gd` `diagnostics_text()`, `ota_status()` | `ota_diagnostics_bundled_active_latest` (bundled vs active vs latest, pending, up to date, disabled, not checked yet) |
| R-08 | Old and new runtimes never accept each other's OTAs | I+V | runtime r4; `OtaCore.runtime_mismatch()` ("incompatible runtime" vs "native update required"); older-runtime leftovers dropped at boot | `ota_r4_app_rejects_r3_ota`, `ota_r3_app_rejects_r4_ota`, `ota_older_runtime_package_dropped_after_app_upgrade`; independent: r3 client rejects dev-000013, r4 client rejects dev-000012 |
| R-09 | Keep the dev channel; room for a stable channel later | I+V | both packages follow `dev`; native build info may name `ota_channel` (default `ota_config.gd` `CHANNEL`) | `ota_channel_mismatch_rejected`; CI build-info `channel: dev` |
| R-10 | Replacement APK bundles the current verified gameplay | I+V | b22 bundles `1046057`: all gameplay (game layer unchanged since `227d0ab` except the startup work and the neutral loading-stage wording) | CI b22 `--print-identity` of the APK's own content: source `1046057`, build 22 |
| R-11 | Package plan: Mote Dev kept as an optional test install | SUPERSEDED | | owner decision (one app): see S-01 |
| R-12 | Versioning: GAME_VERSION stays 0.1.0; Android build advances | I+V | | b22 `versionCode='22' versionName='0.1.0'` (b21 before it); drift check passed |
| R-13 | Security: same APK certificate pin and OTA key pin; no secrets exposed | I+V | | CI b22: signed by `A8:4F:…:E2:C3`; embedded key = pin `a003a45c…0cf2`; dev-000014 signature verified independently |
| R-14 | Save schema 1 preserved; upgrade in place keeps saves | I+V (config) / BLOCKED (device) | same package + certificate + higher versionCode | `save_schema_independent`; in-place upgrade not yet done on the phone |
| R-15 | Regression coverage for the new architecture | I+V | `ota_tests.gd`, `ota_http_stub.gd`, `tools/ota_e2e_local.sh` | unit 160/0, playthrough 12/12 ×2, e2e ALL PASSED (31 checks) locally; CI Build & Verify #21 green |
| R-16 | New signed Mote APK | SUPERSEDED | Build & Verify #21 (b21, r4) | superseded by S-11 (b22, r5) |
| R-17 | Matching test OTA on the new runtime | SUPERSEDED | OTA publish #13 (dev-000013, r4) | superseded by S-12 (dev-000014, r5); dev-000013 stays published as evidence |
| R-18 | dev-000012 preserved as historical evidence | I+V | release `ota-dev-000012` untouched | still served; r3 |
| R-19 | Phone acceptance A–N | needs phone | | now with Mote b22 (MOTE_HANDOFF.md §16) |

## S — Startup repair and one-app consolidation (owner decisions, 2026-09-27)

Owner: cold launch showed a near-black screen for ~12 s; repair it (faster, and never looking dead). Then:
consolidate everything into ONE Mote app and ONE current APK (retire Mote Dev; keep the `dev` channel).

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| S-01 | One Android app (Mote, com.verbal76.axolotl); the Mote Dev app retired; `dev` channel kept | I+V | `export_presets.cfg` (Android + iOS only), `build.yml` (one APK) | `android_single_app_preset`; CI b22 produced one artifact |
| S-02 | Startup cause measured, not guessed | I+V | `StartupTrace`, `--startup-probe` | first frame waited on 66 surface + 25 specialization GPU pipeline compiles plus a synchronous world build, behind a plain-colour splash; b18 identical; OTA bootstrap 0.17 ms (no package) / ~20 ms (verify) |
| S-03 | Mote loading screen is the first frame; world built in named stages; no percentages | I+V / needs phone (feel) | `scripts/ui/loading_screen.gd`, `Game._ready` | `startup_loading_screen_is_first_frame`, `startup_milestones_in_order`, `startup_stages_named_no_percentages`, `startup_hands_over_to_game`; desktop first Mote frame 7.0 s → 0.7 s |
| S-04 | Startup never waits for the network; the OTA check starts after the game is usable | I+V | `Boot.auto_check` after boot health | `startup_no_ota_check_before_usable`; e2e: usable before any check with no network and with a hanging server (usable at ~0.7 s while it hangs) |
| S-05 | Startup timing recorded (log, pause menu, Diagnostics) | I+V | `StartupTrace`, `Boot.boot_marks` (native verify/mount ms) | `startup_summary_for_pause_menu`; e2e logs show "native: OTA package chosen … verify 23–27 ms, mount <1 ms" |
| S-06 | Engine boot splash shows the Mote artwork (covers engine start-up) | I+V (APK contents) / needs phone | `project.godot` boot_splash/* (`stretch_mode=0`), `assets/icon/splash.png` | CI b22: splash texture inside the APK; desktop screenshots |
| S-07 | Shaders baked into the APK and OTA packs; CI fails without them | I+V | `shader_baker/enabled`; CI exports on software Vulkan under xvfb | `android_shader_baker_on`; CI b22: 38 baked caches (6 scene/material) in the APK; `tools/pck_files.py --require-baked` on dev-000014: 38 |
| S-08 | Startup changes keep saves, security and determinism | I+V | | e2e `settings.cfg` unchanged across launches; all OTA security tests green; playthrough 12/12 on seeds 4242 and 7 |
| S-09 | Release APK verified from its own content | I+V | `Boot --print-identity`, `build.yml` verify step | CI b22: the APK's bundled game reports source `1046057`, build 22, flavour normal, OTA on dev, runtime r5, save schema 1 |
| S-10 | A fresh install is current: an OTA of the APK's own commit is not re-downloaded | I+V | `OtaUpdater.bundled_source_sha` | `ota_bundled_game_is_up_to_date`, `ota_newer_than_bundled_still_downloads`; live channel: a b22 client reports "up to date (latest dev-000014 is the game bundled in this app)" |
| S-11 | One current Mote APK | I+V | Build & Verify #22, run 36352308882 | `mote-v0.1.0-b22.apk`, SHA-256 `7305593ef86355c00340cf3389b9b71d34ff7a6bf9ae4925ddc1f8fbb0aa6924`, artifact `mote-android-v0.1.0-b22` |
| S-12 | Channel pointer reconciled (no obsolete OTA presented as newer) | I+V | OTA publish #14, run 36352306690 | pointer → dev-000014 (r5, source `1046057`, PCK `223ae3de…52dc6531`, 4,852,728 bytes); signature, key pin, hash, size, baked shaders, inspector verified from public URLs. dev-000013 (r4) is rejected by r5 apps as "incompatible runtime" |
| S-13 | Full reconciliation of recorded requirements | I+V | history, ledger, handoff, docs, markers audited | no missing gameplay; fixed: drift-check preset, e2e preset index, a hard-coded character name in a loading stage (and a stricter test), stale docs |
| S-14 | Real OTA download → activate → rollback on the phone with the current APK | needs phone | | needs b22 installed and the next OTA (any later push without `[skip ci]`) |
| S-15 | iOS team ID for device builds | OPEN (owner input) | `export_presets.cfg` `AXOLOTL000` | iOS is built only as an unsigned simulator build; needs the owner's Apple team ID if iOS devices are wanted |

## P — Phone playtest fixes (owner, 2026-09-27; delivered by OTA dev-000015, P-06 by dev-000016)

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| P-01 | No floating terrain caps: raised formations connect to the ground; collision matches; Gill cannot pass underneath | I+V / needs phone | `Platforms.Crumble._build_stalk`: each raised brittle-moss cap stands on a brittle stalk rooted in the real ground; the whole formation crumbles/regrows; it regrows only once Gill is clear | Root cause: `_tower()`'s brittle-moss bridge caps (cushion-cap profile, 2.5–3.0 m up, nothing beneath). 4 found (ball 1 east, ball 2 south), 4 fixed. `terrain_no_unsupported_platforms`, `brittle_moss_caps_on_grounded_stalks` (both fail without the stalk), `brittle_moss_whole_formation_crumbles`, `brittle_moss_waits_for_gill_to_move`, `brittle_moss_regrows` |
| P-02 | Same defect class, whole world audited | I+V | `MeshLib.dome_shell(sink)`, `LevelBuilder.cave` | 132 grounded structures measured (`terrain_structures_meet_the_ground`); one more found and fixed: ball 1's cave-dome rim 0.16 m above the downhill ground (fixed skirt vs curvature). 79 elevated bodies over water remain, all leaves on stems (tagged `floats_by_design`) |
| P-03 | Centipede-like parasites move as articulated creatures (head leads, wave travels head→tail, turns curve the body, restrained idle, no twitch, no separation, frame-rate independent, deterministic) | I+V / needs phone | `Parasite._update_segments`: distance-driven travelling wave on the existing trail-following segments | 11 `parasite_*` checks (wave 0.089 m peak on a large parasite, tail lags by 64 frames, 30 vs 60 fps within 6 mm, 12–21 µs per creature); playthrough 12/12 on seeds 4242 and 7 |
| P-04 | Deliver as the first real OTA past b22's bundled game; no new APK | I+V | OTA publish #15 (run 36361312212); Build & Verify #23 skipped the APK job (native layer unchanged) | dev-000015, source `637014d`, r5, PCK `4fc048be…c5bdfe` (4,859,880 bytes), baked; signature, pin, hash, inspector verified from public URLs; a b22 client downloads and stages it |
| P-05 | CI builds a new APK only when the native layer changes | I+V | `build.yml` `native` job gates `android` | Build & Verify #23: "Android APK" skipped; tests green |
| P-06 | Moss Ball 3 canopy: the spiral climb can be started from the ground and climbed with plain jumps (owner: "my daughter couldn't get to any of the higher leaves, the double jump isn't enough") | I+V / needs phone | `Levels._ball3` spiral: 16 leaves, 72° apart (5 per turn), first leaf 0.8 m + 1.0 m per step (was 10 leaves, 1.5 m + 1.6 m per step, 60° apart) | Root cause: first leaf ~1.6 m up and 1.6 m steps vs a 1.85 m plain-jump apex, so every step needed a precise jump + burst. Now first leaf 0.89 m, steps 1.00 m, headroom 1.87 m; `canopy_climb_with_plain_jumps` climbs all 16 leaves with one plain jump each; playthrough 12/12 (seeds 4242, 7). Delivered by OTA dev-000016 (source `346a0bc`, PCK `4ac0e085…2a4681`, 4,861,880 bytes, baked; verified from public URLs; a b22 client downloads it); Build & Verify #24 skipped the APK |

## M — Owner's music (owner, 2026-09-28; delivered by OTA dev-000017)

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| M-01 | The owner's two songs, *Aquarium Whimsy* (106.7 s) and *Bubbly Underworld* (98.8 s), are the background music: they alternate on the title and every moss ball, replacing the generated layers | I+V / needs phone | `AudioDirector`: one `Music`-bus player, `SONGS`, `next_song` on `finished`; travelling keeps the current song; the lowpass still opens as the current ball heals. Files: `assets/audio/music_aquarium_whimsy.ogg`, `music_bubbly_underworld.ogg` (Ogg Vorbis, 48 kHz stereo, full length, no loop). The 15 generated `music_b*_l*.wav` layers and their generator are removed | `music_owner_songs_load`, `music_generated_layers_removed`, `music_travel_keeps_song`, `music_songs_alternate`, `music_on_the_music_bus`, `music_next_song_starts_when_one_ends` (a real song end hands over to the other) |
| M-03 | Music not hidden by the muffling (owner: "finish the music") | I+V / needs phone | `AudioDirector`: clear on the title; lowpass 2.2 kHz on a murky ball (was 750 Hz, and 900 Hz on the title) up to 18 kHz healed; log-scale glide instead of snapping | `music_murky_still_recognisable` |
| M-02 | Keep the OTA small (owner chose Ogg Vorbis over WAV) | I+V | Encoded from the owner's WAVs (39 MB) at Vorbis ~q7: 2.71 MB + 2.55 MB, same sample count as the originals | dev-000017 (OTA publish #17, source `618dcf3`, PCK `3ffcb6b1…a9fcc8`, 8,736,680 bytes, baked): signature, hash, inspector verified from public URLs; no `music_b*` layers in the pack; the `music_*` tests pass run from the pack; a b22 client downloads it; Build & Verify #25 skipped the APK |

## MOTE OPEN ITEMS EXPANSION LIST

[x] 1. Timer + completion foundation (dev-000018, verified 2026-09-28)
[ ] 2. Living terrain / texture and material upgrade
[ ] 3. Dense reactive vegetation / cornfield movement
[ ] 4. Additional moss balls + expanded terrain set
[ ] 5. Additional enemies + ecosystem expansion
[ ] 6. Full expansion integration + progression/balance/100%/speedrun reconciliation

Each item ships as its own dev OTA once its automated validation passes, and is ticked only after
that OTA is published and independently verified. Each item is authorised separately.

## E1 — Expansion 1: timer + completion foundation (owner, 2026-09-28)

Design and rules: `docs/COMPLETION.md`. Owner decisions (2026-09-28): add a real run save
(Continue); title Continue + New Run with confirmation; run timer hidden in play by default, with
a pause-menu toggle; completion weighted by category.

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| E1-01 | Per-run timer owned by the save (survives quit, relaunch and OTA restart; no background, pause or title time; wall-clock and time-zone independent; frame-rate deterministic) | I+V / needs phone | `RunClock` (frame deltas in float64 s, 0.25 s frame cap, discard the frame after a resume), `Game._process` ticks only in play; `_notification` suspends and saves | `timer_*` (11), `timer_started_at_play`, `timer_advances_in_play`, `timer_paused_by_pause_menu`, `timer_paused_in_background`, `run_saved_when_backgrounded`, `relaunch/read_timer_continues` |
| E1-02 | Exact start, finish and freeze rules | I+V | Start: first play frame of a new run. Finish: the frame the last moss ball is fully restored. Frozen `finish_s`; later play only adds to `play_s` | `timer_finish_freezes`, `timer_after_finish_frozen`, `run_finished_when_all_balls_restored`, `finish_time_frozen_after_more_play`, `finish_saved` |
| E1-03 | Best valid finish time kept across runs | I+V | `RunSave.record_finish`, `records.best_finish_s`; New Run keeps records | `run_save_best_time`, `run_save_new_run_keeps_records` |
| E1-04 | Central deterministic completion catalog with stable ids; one percentage source | I+V | `Completion` (4 categories with fixed shares 50/20/15/15; 87 entries; ids stamped on world nodes); gameplay only calls `Game._earn(id)` | `completion_ids_unique_and_pinned` (count 87 + SHA-256), `completion_shares_sum_to_100`, `completion_ids_on_world` |
| E1-05 | 0%, partial, finished below 100%, exactly 100%, never above 100%, duplicates once | I+V | `Completion.percent` (100 only when nothing remains; displayed rounded down) | `completion_zero`, `completion_partial`, `completion_finished_below_100` (65%), `completion_exactly_100`, `completion_never_above_100`, `completion_duplicate_counts_once` |
| E1-06 | Expansion-safe: the catalog grows without losing earned progress; documented percentage model | I+V | Growth adds entries and bumps `CATALOG_VERSION`; earned ids are kept, the % can go down; unknown ids are kept but not counted | `completion_growth_changes_denominator`; `docs/COMPLETION.md` "Extending the catalog" |
| E1-07 | Run save: Continue restores the world; New Run; autosave; atomic with backup; newer formats untouched | I+V / needs phone | `RunSave` (`user://run.json`, format 1), `Game._apply_run` (silent restore), `_resume_position` (last bloom once it has settled) | `run_save_*` (9), `relaunch/*` (a real two-process relaunch: same run, ids, timer, restoration, cleared things, cave and health, resume at the last bloom) |
| E1-08 | Existing saves migrated conservatively; nothing invented | I+V | Mote saved no progress before this OTA; `settings.cfg` (schema 1) is unchanged; the new run save records "no earlier progress existed" | `run_save_migration_from_no_progress`, `run_save_migrates_partial_data`, `run_save_outside_ota_storage` |
| E1-09 | Player UI: run time, %, finished, finish time, per-category progress, best; unobtrusive optional HUD timer | I+V / needs phone | Title (Continue / New Run + run line), pause (run panel, Show run timer, New Run with confirmation), HUD timer (top left, faint, off by default), ALL CLEAR shows "Finished in …" | `pause_menu_shows_run`, `title_continue_and_new_run`, `hud_run_timer_toggle`, `finish_time_frozen_after_more_play` |
| E1-10 | Diagnostics: timer state, run time, finished, frozen time, completion, run save format and origin, catalog version | I+V | `Game.run_diagnostics_text` through `StartupTrace.timeline_text` (the r5 bootstrap's game-layer hook; no native change) | `diagnostics_show_run_timer` |
| E1-11 | Ships by OTA, no APK | I+V | Game layer only (no `scripts/boot/`, `project.godot`, `export_presets.cfg` or runtime lock changes); runtime r5 unchanged | dev-000018 (OTA publish #18, source `27d6d44`, PCK `2d980e7e…20e66a`, 8,773,516 bytes, baked, save schema 1): signature with the pinned key (a003a45c…), hash, size, inspector verified from public URLs; a b22 client downloads and stages it; the relaunch phases pass run from the pack; Build & Verify #26: Android APK skipped |

## Precedence notes

- The reconciliation prompt's floor list repeats two items that the owner changed earlier today: "diegetic
  **dorsal** health" and "~**180°** tail swipe". The owner explicitly chose gill-based health (answering my
  question, then confirming "should have 6 … glowing … dull and faded"), and explicitly asked for a 270° swipe.
  Under the precedence rule (explicit later owner decision wins), these are recorded as SUPERSEDED, not reverted.
  If the owner wants them reverted, that is a one-line decision.
- G-57 ("normal build fully offline") is superseded by the owner's later ruling R-01: offline-capable, not
  offline-only. The normal Mote app now carries the OTA client; nothing requires a connection to play.
- R-11 (Mote Dev kept as a test install) is superseded by the owner's later decision S-01: one Mote app.

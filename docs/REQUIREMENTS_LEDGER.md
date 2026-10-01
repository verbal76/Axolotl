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
[x] 2. Living terrain / texture and material upgrade (dev-000019, verified 2026-09-28)
[x] 3. Dense reactive vegetation / cornfield movement (dev-000020, verified 2026-09-28)
[x] 4. Additional moss balls + expanded terrain set (dev-000021, verified 2026-09-28; dev-000022 adds only test fixes)
[x] 5. Additional enemies + ecosystem expansion (dev-000023, verified 2026-09-28)
[x] 6. Full expansion integration + progression/balance/100%/speedrun reconciliation (dev-000024, verified 2026-09-28)

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

## E2 — Expansion 2: living terrain + cave repair (owner, 2026-09-28)

Design: `docs/TERRAIN.md`. Owner decisions (2026-09-28): add a head collider to Gill; "moss over
stone" look; organic mounds instead of cylinders. Owner phone feedback during the work: "Walls are
too straight, it's a perfect 90 into the ground" (the platforms).

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| E2-01 | Cave entrance: natural irregular arched mouth integrated into the terrain, rounded sides, a brow, clear to enter | I+V / needs phone | `MeshLib.cave_mound`: rows × columns warped round the arch; jamb strips with a bullnose; a brow; the base flares into the ground. Root cause: `dome_shell` deleted quads inside a box, making a rectangular stair-stepped hole with an open slot inside the wall. All 3 caves used it; all 3 are repaired | `cave_mouths_arched_not_rectangular` (2.97–3.00 m wide, 2.21–2.41 m high), `cave_mouth_clearance`, `cave_walk_in_and_out`, `cave_faces_correct_side` |
| E2-02 | Cave interior: the head never enters walls or ceiling; collision matches what is drawn | I+V / needs phone | Root cause: Gill collides as one 0.3 m sphere with his head 0.4–0.55 m ahead, and the old dome's ceiling tapered to the floor. Fix: `Axolotl._guard_head` (the head sphere is kept out of walls and ceilings everywhere, body unchanged); interior walls vertical for 1.9 m before the vault; collision = drawn triangles | `cave_head_stays_out_of_walls` (0 of 5000 frames; 3199 of 5000 with the guard disabled), `head_stays_out_of_mound_walls`, `cave_collision_is_drawn_mesh`, `cave_ceiling_clear_over_floor` (lowest 3.87 m) |
| E2-03 | Reusable cave vocabulary with variation | I+V | Seeded per site: size, height, mouth width and height, lumps | `caves_vary` |
| E2-04 | Terrain material: moss over earth/stone, no stretching, organic transitions, variation, per-ball palettes | I+V / needs phone | `shaders/moss.gdshader` (slope-driven moss cover, biplanar, strata, tufts, macro tint; 8 fetches, down from 9); `Levels.PALETTES` stone/tint | visual review of rendered shots; all terrain tests |
| E2-05 | Platforms: organic mounds, no 90° walls into the ground, routes preserved | I+V / needs phone | `MeshLib.mound`: rounded rim, sides leaning out at 75°, concave sweep into the ground following the real terrain; irregular outline; top exact; collision = mesh | `mounds_tops_at_design_height`, `mounds_flare_not_a_step` (0.23 m), `mound_faces_outward`; tutorial, jump/burst, canopy and placement tests; playthroughs |
| E2-06 | No new floating terrain or gaps; previous protections kept | I+V | | `terrain_structures_meet_the_ground` (132 structures), `terrain_no_unsupported_platforms` |
| E2-07 | Mobile performance measured | I+V | `--test=shots --only=perf` | `docs/TERRAIN.md` Performance |
| E2-08 | Ships by OTA, no APK | I+V | game layer only; runtime r5 unchanged | dev-000019 (OTA publish #19, source `4461b84`, PCK `e0c2b637…eef249`, 8,796,124 bytes, baked, save schema 1): signature (pinned key), hash, size and inspector verified from public URLs; a b22 client downloads and stages it; `_test_caves` and `_test_mounds` pass run from the pack; Build & Verify #27 green with no APK build |

## E3 — Expansion 3: reactive vegetation / cornfield movement (owner, 2026-09-28)

Design and measurements: `docs/VEGETATION.md`.

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| E3-01 | Vegetation reacts to the axolotl's body, direction, speed and tail (not one point): parts ahead, displaced beside, recovers behind; stops settle; frame-rate stable | I+V / needs phone | `Wake` (skeleton head/body/tail points, bow, exact-time trail) → `vegetation.gdshader` `wake_bend` | `wake_follows_axolotl`, `wake_grows_with_speed`, `wake_tail_whip_sweeps`, `wake_recovers_behind`, `wake_settles_when_stopped`, `wake_frame_rate_independent` |
| E3-02 | Short, medium and tall families; the tall one can hide him, the movement tracks him | I+V / needs phone | `Vegetation.FAMILIES`, creased reed meshes; ball 1 medium meadow + corridor + tall reed bed; balls 2 and 3 long grass in stands | `veg_families_placed`; rendered shots |
| E3-03 | Ambient motion, not synchronised | I+V / needs phone | per-plant hashed phase and pace, rolling gusts | shader; rendered |
| E3-04 | Other movers disturb vegetation | I+V / needs phone | nearest 3 parasites add head and tail points | `wake_parasites_disturb_plants` |
| E3-05 | Reusable placement for later expansions | I+V | `Vegetation.field`, `corridor`, `family_params`; `Levels._stands`, `_veg_keep_clear` | used for all new placement |
| E3-06 | Readability: paths, caves, blooms, holes, platforms, hazards kept clear; open ground stays | I+V | keep-clear rule; patches, not carpets | `veg_keeps_clear_of_landmarks` |
| E3-07 | No gameplay effect: no collision, no barriers, gameplay RNG untouched, save unaffected | I+V | cosmetic only | `veg_has_no_collision`, `veg_does_not_slow_or_block`, `veg_leaves_gameplay_rng_alone`; relaunch tests; playthroughs |
| E3-08 | Mobile performance measured with movers | I+V | instancing, bounds early-out, reduced segments and visibility ranges | `docs/VEGETATION.md` Performance |
| E3-09 | Ships by OTA, no APK | I+V | game layer only; runtime r5 | dev-000020 (OTA publish #20, source `2206aea`, PCK `c0c6a736…26374b`, 8,832,576 bytes, baked, save schema 1): signature (pinned key), hash, size and inspector verified from public URLs; a b22 client downloads and stages it; `_test_vegetation` passes run from the pack; Build & Verify #28 green with no APK build |

## E4 — Expansion 4: world expansion, more moss balls + expanded terrain set (owner, 2026-09-28)

Design, audit and measurements: `docs/WORLD.md`; catalog: `docs/COMPLETION.md` (version 2).
Owner decisions: new areas branch off the chain; finishing needs every ball restored; round moss balls
plus big formations; four new areas.

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| E4-01 | Four new moss balls, each distinct (size, palette, silhouette, vegetation, landmark), branching off the original chain | I+V / needs phone | `Levels` CENTERS/RADII/NAMES/PALETTES/LINKS; `WorldExpansion` (Terrace Steps, Reed Canyon, Canopy Spire, Hollow Grotto); vortices 1→4, 2→5, 3→6, 4→7 | `world_has_seven_balls`, `new_balls_distinct`; rendered shots |
| E4-02 | Expanded terrain vocabulary: ridges, terraces, arch, natural bridge, shelves, canopy spiral, stem ladders | I+V / needs phone | `LevelBuilder` ridge/terrace/arch/bridge/shelf/canopy_spiral/ladder_stem; `MeshLib.sweep`/`shelf` | `terrain_grounded`, `no_floating_platforms`, `mesh_winding` |
| E4-03 | Vertical and canopy routes, every elevated destination reachable, readable from the ground | I+V / needs phone | `route` hints (95 climbs incl. audit-only legacy climbs) | `routes_reachable_by_design`, `climbs_start_with_a_plain_step_from_the_ground`, `elevated_platforms_all_on_climbs`, `decor_leaves_do_not_look_like_platforms`, `elevated_motes_have_routes`, `climbs_with_plain_jumps`, `jungle_ladders_climbed_with_plain_jumps` |
| E4-04 | Phone report (Giant Stems): leaf platforms with no visible way up | I+V / needs phone | all 70 jungle stems are ladders from 0.9 m (949 leaves), outline collision, spaced 9 m, bases kept clear; bent stems collide along the bend; ball 2 kelp-top leaves droop | the tests in E4-03; shots `climb_*`, `b3look_*` |
| E4-05 | Cave expansion | I+V / needs phone | four new caves (balls 4, 5, 7 ×2) with pearls; up to four caves darken a ball | `caves` (7 caves), `new_caves_hold_pearls` |
| E4-06 | Completion: new content in the catalog, finishing needs all seven balls | I+V | catalog v2: 157 ids (was 87), no id changed | `completion_ids_unique_and_pinned`, `new_areas_in_completion`, playthroughs restore all seven balls |
| E4-07 | Old progress and the original route survive | I+V | ids unchanged; original vortices and layout unchanged (mesa unchanged) | relaunch test; playthroughs 20/20 on seeds 4242 and 7 |
| E4-08 | Save/reload in the new areas | I+V | run save unchanged in format | relaunch test saves on Hollow Grotto and continues there; `new_blooms_resume_standing` |
| E4-09 | Determinism | I+V | all placement seeded; nothing uses the gameplay random generator | playthroughs; `veg_leaves_gameplay_rng_alone` |
| E4-10 | Performance measured | I+V | MultiMesh ladders; per-ball simulation only | `docs/WORLD.md` Performance |
| E4-11 | Ships by OTA, no APK | I+V | game layer only; runtime r5 | dev-000021 (OTA publish #21, run 36383509240, source `9ed29db`, PCK `7415e907…162274`, 8,882,636 bytes, baked, save schema 1): signature (pinned key), hash, size and inspector verified from public URLs; a b22 client downloads, verifies and stages it; `_test_route_audit`, `_test_new_areas`, `_test_completion_catalog`, `_test_caves`, `_test_climbs_physical` pass run from the pack. CI on that commit found `_test_upgrades` stopping silently on Canopy Spire (no cave); fixed with the runner now failing any test that reports nothing: dev-000022 (OTA publish #22, run 36385605395, source `fe3e0fd`, PCK `48597241…1e5894`, 8,883,196 bytes; same game, tests only) verified the same way; Build & Verify #30 green, Android APK job skipped |

## E5 — Expansion 5: ecosystem / creatures / enemies (owner, 2026-09-28)

Design, audit and measurements: `docs/ECOSYSTEM.md`; catalog v3 in `docs/COMPLETION.md`. Owner
decisions: threats = reed stalker, crab guardian, cave eel, pufferfish; ambient = shrimp shoals,
canopy snails, leaf hoppers, cave glow-worms; completion = species discovered + guardians and eels
defeated; guardians and eels stay defeated, stalkers and puffers return, ambient life is not saved.

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| E5-01 | Audit of the existing ecosystem | I+V | | `docs/ECOSYSTEM.md` Audit |
| E5-02 | Varied creatures with distinct behaviour, not reskins | I+V / needs phone | 8 species (`scripts/actors/critters/`) on a shared `Critter` base | per-species tests (E5-05) |
| E5-03 | Habitats give each ball its own life | I+V / needs phone | `Ecosystem.populate`: reeds, grotto mouths and walls, open water, open moss, leaves and shelves, climbs, ceilings | `eco_species_in_their_habitats` |
| E5-04 | Vegetation reveals movers before they are seen | I+V / needs phone | creature wake points (32-point wake) | `stalker_moves_the_reeds_unseen` |
| E5-05 | Fair, readable threats: telegraphs, no attacks through rock, no spawn damage, no chained damage | I+V / needs phone | telegraphs; line-of-sight on terrain; locked pounce line; threats kept off respawn and arrival points | `crab_*`, `eel_*`, `stalker_*`, `puffer_*`, `eco_no_threats_at_respawn_or_arrival` |
| E5-06 | Cave and canopy life | I+V / needs phone | glow-worms in every grotto, guardians, eels; snails and hoppers on climbs | `glowworms_react_to_him`, `snail_tucks_in_when_near`, `hopper_leads_up_the_climb` |
| E5-07 | Scalable cost: distant creatures do no work | I+V | activation within 38 m on the current ball; merged meshes; MultiMeshes | `eco_only_nearby_creatures_run`, `eco_tick_cheap`; `docs/ECOSYSTEM.md` Performance |
| E5-08 | Completion: discoveries and significant threats only, never grind | I+V | catalog v3, 172 ids (+8 species, +3 crabs, +4 eels), no id changed | `completion_ids_unique_and_pinned`, `species_discovered_once`, `crab_defeated_counts_once` |
| E5-09 | Save/load of creature state | I+V | defeated guardians and eels restored from ids | relaunch `read_creatures_restored` |
| E5-10 | Determinism; both playthrough seeds viable | I+V | per-creature seeded generators | `eco_leaves_gameplay_rng_alone`, `eco_deterministic`; playthroughs on seeds 4242 and 7 |
| E5-11 | Ships by OTA, no APK | I+V | game layer only; runtime r5 | dev-000023 (OTA publish #23, run 36411346325, source `9d4fd24`, PCK `c0a4037a…e6f226`, 9,026,936 bytes, baked, save schema 1): signature (pinned key), hash, size, inspector and the E5 sources in the pack verified from public URLs; a b22 client downloads, verifies and stages it; `_test_ecosystem` (30) and `_test_all_clear` (7) pass run from the pack; unit suite 315/315 (fresh user data); playthroughs 20/20 on seeds 7 and 4242, 0 deaths; Build & Verify #31 green, Android APK job skipped |

## E6 — Expansion 6: final integration, visuals, balance, 100% (owner, 2026-09-28)

The consolidated prompt, plus owner review during the pass. Owner rule: the game starts dirty and
dull on purpose and brightens as it is healed. Only real defects in the murky start were changed.
Owner references: a real crab, calm/puffed pufferfish, garden eels, moray eels, a professional
stylised undersea game (the healed look), and a sprouted moss ball.

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| E6-01 | Spiral/ladder leaves: attached, broad, staged, collision = art; every climb audited | I+V / needs phone | petiole leaves, outline collision, 90° spirals, full-height stem collision (`docs/WORLD.md` Leaf platforms) | `_test_leaf_geometry` (4), `_test_leaf_footing` (6), climbs and route audits |
| E6-02 | Gill: an axolotl, soft freckled skin, no plastic shine; collision unchanged | I+V / needs phone | `shaders/axolotl_skin.gdshader`, crossed gill blades | `gill_soft_skin_not_plastic`, `gill_collision_unchanged` |
| E6-03 | Parasites: one continuous body; limp death drift | I+V / needs phone | `shaders/parasite_body.gdshader`, `_limp_chain` | `_test_parasite_body_and_death` |
| E6-04 | E5 creatures reviewed against references | I+V / needs phone | crab, pufferfish, moray eels, garden-eel burrowers, shrimp, snail, motes (`docs/ECOSYSTEM.md` Look) | shots `critterclose`, `feedback` |
| E6-05 | Lighting: sources, shafts, caustics, shadows, caves, depth; restoration clears the tank | I+V / needs phone | `docs/LIGHTING.md` | `aquarium_fully_clean`, shots `review`, `lightdbg`, moments |
| E6-06 | Owner: blocky rosettes, sharp base flowers | I+V / needs phone | smooth arching leaves that sway (`docs/VEGETATION.md`) | shots `feedback` |
| E6-07 | Owner: vortex a revolving spiral of water jets over a tidal pool, Gill corkscrewing through | I+V / needs phone | `docs/WORLD.md` Vortices | `_test_vortex` (6), `vortex_mouths_clear`, shots `vortex` |
| E6-08 | Owner: healed balls sprout like the reference moss ball | I+V / needs phone | `Levels._sprouts` (`docs/VEGETATION.md`) | shots `balls` (murky/clear) |
| E6-09 | Completion reconciled; a legitimate automated 100% | I+V | bot `hundred()`; fixes: the Hollow Grotto cavelet's pearl on the ceiling, eels fought from inside their grottoes | playthroughs seeds 7 and 4242: 88.4% at the finish, then 100% by play, finish time kept, 23/23 each, 0 deaths; `cave_rewards_on_their_top_ledge` |
| E6-10 | Balance review | I+V | finish floor kept at 58.5% (`docs/COMPLETION.md` Balance review) | normal finishes 88.4% on both seeds |
| E6-11 | Timer integrity | I+V | unchanged model | `_test_timer_integrity` (3), `finish_time_kept_through_100` |
| E6-12 | Resume points safe; save and migration | I+V | bloom pulse startles parasites on re-forming | `_test_resume_points_safe`, `_test_run_save_file`, relaunch test |
| E6-13 | Performance is a hard requirement | I+V (proxy) / needs phone | selective shadow casters (a caster layer, flat leaf stand-ins), one 1024 map over 30 m, shadows first to go in `QualityScaler`; sprouts not drawn on neglected balls; lean sprout and coral meshes | `docs/WORLD.md` Performance, Expansion 6 (before/after, 15 views); shots `perfsplit`; `shadows_first_to_scale_down`, `parasite_combat_cheap` |
| E6-14 | Ships by OTA, no APK | I+V | game layer only; runtime r5 | dev-000024 (OTA publish #24, run 36465899336, source `6e6f71e`, PCK `6816257c…d1ed2e7fa`, 9,214,288 bytes, 38 baked shader caches, save schema 1): signature (pinned key), hash, size, inspector (INSPECT OK) and the E6 sources in the pack verified from the public URLs; a b22 client (bundled `1046057`) discovers, downloads, verifies and stages it; 53 E6 checks pass run from the pack; unit suite 364/364 (fresh user data); playthroughs on seeds 7 and 4242: 23/23 each, 0 deaths, 100% by play; OTA end-to-end 42/42; version drift and runtime gate r5 pass; Build & Verify #32 green, Android APK job skipped |
| E6-15 | Owner: leafy plants not solid green (terrarium earth star, fire-and-ice hosta) | I+V / needs phone | `shaders/variegation.gdshaderinc` on the rosettes, ferns and climbing leaves (`docs/VEGETATION.md`) | shots `feedback`, `review` |
| E6-16 | Addendum: parasite combat and AI (sizes, retreat, pack alert, spitter, fairness, sight, determinism, cost) | I+V / needs phone | `scripts/actors/parasite.gd`, `parasite_glob.gd` (`docs/ECOSYSTEM.md` Parasites) | `_test_parasite_combat` (27); playthroughs on both seeds and 100% by play rerun after it; defects it exposed fixed: a parasite climbing a stem out of reach, damage during the vortex-connection shot, latching onto an invulnerable axolotl, stacking while waiting |

## PT — dev-000024 physical playtest polish (owner, 2026-09-28)

The owner reports dev-000024 **physically active and boot-healthy** on the real b22 app (owner's evidence, 2026-09-28). From playing it,
three findings, fixed in a tightly bounded pass (no gameplay rule, progression, completion id, save format,
runtime, native code, collision, attack range, damage or timing changed; not Expansion 7).

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| PT-01 | Gill needs several natural idles (rear-leg lookaround and side scoot required, two more chosen, then the owner's look-up); occasional, random, no immediate repeat, cancelled by any input, never in incompatible states, cosmetic only, no gameplay RNG | I+V / needs phone | `AxolotlModel` idles (lookaround, scoot, head tilt, stretch with yawn and shake, look-up), `Axolotl.idle_allowed` (MOTE_HANDOFF §6) | `_test_gill_idles` (7); shots `gillanim` |
| PT-02 | The tail whip must visibly follow the drawn arc; the arc must agree with the real hit area; combat unchanged | I+V / needs phone | `AxolotlModel.whip_curve`: cock, hip-led strike travelling down the tail, overshoot, recovery; arc drawn to `SWIPE_REACH` from the body centre (was 1.55 m) with its head on the tail tip | `_test_tail_whip` (5): timing (frame 6), reach, damage, rules unchanged, tip sweeps 210°; shots `gillanim` |
| PT-03 | Constant subtle independent sway of all appropriate vegetation (not terrain, stems, stone, caves); neighbours out of step; disturbance still adds; GPU-bounded | I+V / needs phone | per-plant phase, pace, size and direction plus per-blade flutter (`vegetation.gdshader`); per-leaf flap with per-leaf data in ladder meshes, swinging hanging roots (`plant.gdshader`) (`docs/VEGETATION.md` Ambient motion) | `_test_ambient_sway` (6); shots `sway` (motion maps) |
| PT-04 | Owner: the look-up idle kept; a cute little yawn on the stretch | I+V / needs phone | fifth idle `Idle.LOOKUP`; `sfx_gill_yawn` (tools/gen_audio.py `gill()`), played once per stretch | `idles_varied_not_repeated` (all five), `stretch_yawns_once` |
| PT-05 | Owner: a colour picker for Gill's body and freckles; reachable from the title screen; small uploaded or built-in patterns tiled on him | I+V / needs phone | "Gill's colours" (`GillPage`, `GillLook`) from the pause menu and the title screen: seven morph swatches, body/freckle hue and shade, patterns (five built-in or the player's picture via the phone's file picker) as markings or full colour, 1–8 repeats, live preview; per device in settings.cfg `[gill]`, schema 1 unchanged | `_test_gill_colours` (4), `_test_gill_patterns` (4); shots `colours`; the phone's file picker needs the owner's check |
| PT-06 | Performance not undone | I+V (proxy) / needs phone | vertex-shader only; no shadows or casters changed; preview target drawn only while open | `docs/VEGETATION.md` Performance (15 views): within ±11% of dev-000024, median about 1% faster; video memory +4.5 MB; `ambient_motion_bounded_gpu_only` |
| PT-07 | Ships by OTA, no APK | I+V | game layer only; runtime r5 | dev-000025 (OTA publish #25, run 36486884032, source `8c92e5b`, PCK `333d6cd6…25dc52af`, 9,285,292 bytes, 38 baked shader caches, save schema 1): signature (pinned key), hash, size, inspector (INSPECT OK) and the new sources in the pack verified from the public URLs; a b22 client (bundled `1046057`) discovers, downloads, verifies and stages it; 50 checks pass run from the pack; unit suite 390/390 (fresh user data); playthroughs on seeds 7 and 4242: 23/23 each, 0 deaths, 100% by play; OTA end-to-end 42/42; version drift and runtime gate r5 pass; Build & Verify #33 green, Android APK job skipped |

## WX — Major world expansion: seven substantial worlds (owner brief, 2026-09-28)

The owner's 41-section brief. Owner decisions: bigger balls in a bigger tank; a ravine fall costs one
frond and puts Gill back at the edge; losing the last frond is a normal death (re-form at the last
bloom, progress kept); the extreme canopy drop never takes the last frond. Design and results:
`docs/WORLD_EXPANSION.md`. Status "I+V" = implemented and verified automatically; nothing here is
phone-verified until the owner says so (MOTE_HANDOFF §16 item 17).

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| WX-01 | About 4× playable extent per world | I+V | every ball about doubled in radius (Mossy Meadow 24 → 48 m; the others 28→56, 30→60, 18→36, 26→52, 16→32, 22→44), tank laid out 1.4× wider | `WORLD.md`; `docs/WORLD_EXPANSION.md` |
| WX-02 | Much more meaningful density; creature ecology, not enemy spam | I+V | new regions in each world's identity; completion entries 172 → 348; creature groups added in every world | catalog v4 (`docs/COMPLETION.md`); `_test_ecosystem` (30) |
| WX-03 | Ravines and hazards, forgiving failure | I+V | cube-sphere signed terrain, plateaus, ravines (`add_ravine`), `Game.ravine_fall`, `Axolotl.ravine_return_point`; only the floor counts (bridges, stones, logs above it do not) | `_test_ravines`; `nothing_starts_in_a_ravine` |
| WX-04 | Multiple routes (easy / skilled / exploration), verticality, traversal toys | I+V | crossings (walk round, stones, burst, bridges, logs, streams), bubble columns, glide shaft, current streams, terraces, the Great Trunk, the Sky Spire | route audit (200 climbs), `_test_bubble_columns` (3), jungle ladders + Great Trunk climbed physically |
| WX-05 | Restoration changes geography; interconnection | I+V | `RestorationGate` (rise, grow, retract, column): Meadow's stem bridge and root curtain, Current Hollows' kelp leaf and mesa column, Giant Stems' canopy column, Terrace Steps' rising stones, Reed Canyon's Reed Wall, Hollow Grotto's boulder | `_test_restoration_gates` (3), `bubble_column_flows_when_healed` |
| WX-06 | Each world keeps its own identity (no Meadow clones) | I+V | see `docs/WORLD_EXPANSION.md` per world | before/after shots, camera audit shots |
| WX-07 | Completion stable and migration-safe; finish separate from 100% | I+V | explicit ids (`fixed_id`, `freeze_ids`), `CatalogFrozen.V3`; catalog v4 348; finish still 58.5% without caves, blooms or wildlife | `shipped_completion_ids_kept`, `v3_save_migrates` (a v3 save keeps everything, 67%), `completion_ids_unique_and_pinned` |
| WX-08 | Vortex pacing re-evaluated | I+V | 70% kept: with 3–5× the events it comes after most of a world (Meadow 45 of 64, about 380 s of bot play) | playthroughs |
| WX-09 | Performance: culling, regional activation, LOD | I+V (proxy) / needs phone | horizon culling, 35 m vegetation cells with distance ranges, 55 m regional activation, adaptive quality | 15 perf views vs dev-000025 (`docs/WORLD_EXPANSION.md`) |
| WX-10 | Collision matches visuals | I+V | every new piece collides with its drawn faces | terrain, mound, leaf, cave and placement tests |
| WX-11 | Camera and touch practical | I+V (proxy) / needs phone | no camera change needed | camera-audit shots (43 views) |
| WX-12 | Route proof and full playthroughs to a legitimate 100% (seeds 7 and 4242) | I+V | bot: ravine-aware paths, columns, hollows, gates; per-world clear scenario | see the release row |
| WX-13 | Settings scrollbar about 3× easier to grab (owner, from dev-000025) | I+V / needs phone | `UiStyle` scrollbar: 28 px touch target, 8 px drawn | `_test_menu_scrollbar` |
| WX-14 | Ships as ONE dev OTA, no APK | I+V (published dev-000028) / needs phone | game layer only; runtime r5 unchanged (`ota_runtime.py --check`); save schema 1; catalog v4 (348) | local gates on `3526b3e`: unit suite 407/407 (fresh user data); playthroughs seed 7 and 4242: 23/23 each (deaths 1 / 2; all clear at 3,351 s / 3,832 s sim, normal finish 87.9% / 88.2%; 100% by play at 6,018 s / 5,442 s, finish time kept); version drift passes; runtime gate r5 unchanged; OTA end-to-end 42/42. Published **dev-000028** (OTA publish #28, source `bf46566`: the validated content plus two unit-test measurement fixes; PCK `a4c5f8dc…c1075a162b`, 9,384,212 bytes, 38 baked caches): signature (pinned key), hash, size, inspector and the new sources verified from the public URLs; a b22 client stages it; 71 checks pass run from the pack; Build & Verify #38 green, no APK |

## AQ — Master held next-OTA package: Tier 2, the aquarium experiences, the tank (owner brief, 2026-09-29)

One coherent package in one dev OTA, no APK. Owner decisions (asked before implementation):

- pufferfish killable with no new ids;
- aquarium entry from the title and the pause menu;
- Tier-2 unlocks per run (not completion);
- loadout on the pause-menu page;
- landmark shrines in W3, W5 and W7;
- the run timer never counts in the aquarium;
- camera-directed Swim controls;
- fish at mid scale;
- **three bala sharks, the largest fish, a skittish trio** (added during qualification).

Design: `docs/TIER2.md`, `docs/AQUARIUM.md`, `docs/ECOSYSTEM.md` (pufferfish). Nothing here is
phone-verified.

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| AQ-01 | Gravel rebuild | I+V | height-mesh floor (`Aquarium.floor_h`), `gravel2` albedo/height + normal maps (`tools/gen_gravel.py`), dual-sample height blend, instanced pebble tiles near the camera, 260 stones | `--only=gravel` shots |
| AQ-02 | Late-80s / early-90s bedroom Room view | I+V | `Bedroom` (`tools/gen_room.py` textures): tank corner, desk, bed, TV, shelf, posters, corkboard | `--only=room`, `--only=aquarium` shots |
| AQ-03 | Interactive tank in the Room | I+V | tap the tank → Inspection; Live Tank and Swim buttons | `aquarium_modes_and_back` |
| AQ-04 | Aquarium Inspection | I+V | bounded drag round the front glass, never inside it | `aquarium_inspection_outside_glass` |
| AQ-05 | Full-screen landscape Live Tank | I+V | four views (whole tank, left, right, Gill close-up); controls appear on touch then fade | shots `5live_*` |
| AQ-06 | About 10 ambient fish (+3 bala sharks, owner) | I+V | `AmbientFish`: 13 fish of 5 kinds, own RNG, never targets or completion ids | `_test_ambient_fish` (6) incl. `bala_trio_bolts_and_regroups`; `--only=bala` |
| AQ-07 | Free Swim Mode | I+V | `Swimmer` (separate body), tank collision layer 12, swim gait; earns nothing, cannot be hurt | `swim_stays_in_the_water` (289 m swum), `swim_earns_nothing_and_gill_safe` |
| AQ-08 | Pufferfish repair | I+V | hittable, 3 hits, sinks to face him (≥0.9 m), beaten → gone, returns later; no new ids | `puffer_beaten_by_tail_swipes`, `puffer_beaten_is_gone`, `puffer_returns_later`; habitat check reads its home hover |
| AQ-09 | Water Cannon, Bubble Blast, Gill Rush | I+V | `Tier2Combat` | `_test_tier2_rules` (9), `_test_tier2_world` (9); `--only=tier2` shots |
| AQ-10 | Fixed unlock order W3 → Cannon, W5 → Bubble, W7 → Rush | I+V | shrines at High Crown, Secret Clearing, Glow Chamber | `tier2_shrines_in_worlds_3_5_7` |
| AQ-11 | All unlockable, one equipped | I+V | `Tier2.unlock/equip`, `Tier2Loadout` | `tier2_loadout_rules`, `tier2_loadout_equips` |
| AQ-12 | One Tier-2 button; Tail Swipe kept | I+V | `Hud.BTN_SPECIAL` (L / Y) | `tier2_shrine_unlocks_and_equips` |
| AQ-13 | Three distinct glyphs | I+V | `Tier2Glyphs` | `--only=tier2` shots (ready / action / cooling, loadout) |
| AQ-14 | Readable cooldown | I+V | radial refill and ready flash; 5 / 8 / 9 s, shared | `tier2_cooldown_blocks_repeat`, `tier2_swap_keeps_cooldown` |
| AQ-15 | Settings scrollbar about 3× wider (from dev-000028) | SUPERSEDED | Settings and the colours page no longer scroll (`00038-menus-landscape`) | `menu_scrollbar_thumb_sized` retired; superseded by Open issue 7 |
| AQ-16 | Presentation never mutates run, completion, RNG or saves | I+V | `Game.state = "aquarium"`, snapshot/restore, gameplay actors pause | `aquarium_run_untouched`, `aquarium_clock_never_counts`, `aquarium_world_stands_still`, `aquarium_no_leaks` |
| AQ-17 | One dev OTA, no APK | I+V (published **dev-000029**) / needs phone | game layer only; runtime r5 unchanged (`ota_runtime.py --check`); game 0.1.0, save schema 1, catalog v4 (348); no native change, no APK | local gates on `fc08131` (the game content published): unit suite 446/446 with fresh user data; playthroughs seed 7 and 4242: 23/23 each (ALL CLEAR at 3,661 s / 3,039 s, 100% by play at 5,446 s / 4,845 s, 2 deaths each); version drift passes; OTA end-to-end 42/42 (startup usable at 8.27 s with a hanging channel; offline seed 4242 to 100%). Found and fixed in qualification: a parasite could be left buried inside the terrain (World 7 stuck at 97%); startup ~10.4 → ~8 s (the colours page's pattern swatches drawn off the main thread; the gravel floor's heights computed once); Tier-2 and aquarium test isolation; the bot's eel tactic inside grottos. Perf vs dev-000028 (software renderer, proxy): frame time median +9% (bedroom hidden from inside the water when the glass passes <8% of it), video memory 124.6 → 146.5 MB, RAM +17 MB. Published **dev-000029** (OTA publish #29, source `1ad34ea`; PCK `a4c1f12a…2cdda79`, 10,870,736 bytes, 38 baked caches). Verified from the public URLs: signature (pinned key), hash, size, inspector and the new sources; 116/116 checks run from the pack; a b22 client finds it compatible and stages it. Build & Verify #39 green; no APK |

## TH — Treasure Hunt postgame mode (owner brief, 2026-09-29)

One dev OTA, no APK. Design: `docs/TREASURE_HUNT.md`. The first qualification of `8c12b15` failed
seed 4242 twice (TH-B1, TH-B2 below, both playthrough-bot defects).

**Qualification of the final candidate `e8dc1d0`** (fresh user data, one run each; nothing is
phone-verified):

| Gate | Result |
|---|---|
| Unit suite | Passed |
| Seed 7 playthrough | 23/23, ALL CLEAR 5,760 s, 100% at 7,468 s |
| Seed 4242 playthrough | 23/23, ALL CLEAR 3,411 s, 100% at 5,383 s |
| OTA end-to-end | 42/42, including an offline seed 4242 run by the exported game; usable at 7.9 s with a hanging channel |

**Measured alone against dev-000029 `1ad34ea`:**
- Startup to a usable title, headless, 3 alternating runs each: median 8,059 vs 8,029 ms (+0.4%, noise).
- Frame time, software renderer, 20 views including Room, Inspection, Live Tank and Swim, best of
  two A-B-A-B passes: median 176.1 vs 178.4 ms/frame (-1.2%); every view within ±11%.
- Memory: video memory 157.4 MB, unchanged; RAM +2.2 MB, peak +4 MB.

Game 0.1.0, save schema 1, catalog v4 (348), runtime r5. No APK.

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| TH-01 | Unlocks at 100% only, old 100% saves included | I+V | `_test_treasure_unlock` |
| TH-02 | 14 objects, two per world, interleaved, seeded, saved, isolated RNG | I+V | `_test_treasure_generation` |
| TH-03 | Hiding places (ground, tall grass at a clump's edge, leaf, rock, cave); easier first hunt (owner) | I+V | `treasure_spot_kinds_mixed`; `--only=thspots` shots |
| TH-04 | Lunge-only pickup; the find saved before the celebration | I+V | `_test_treasure_play` |
| TH-05 | Celebration: confetti, fireworks, Gill's 2.8 s rear-up dance; finale and card after 14 | I+V | `--only=treasurehunt` shots |
| TH-06 | Full size first hunt, exactly half from the second on | I+V | `treasure_second_hunt_half`, duck full-vs-half shot |
| TH-07 | No completion ids; timer, gameplay RNG and aquarium modes untouched | I+V | unit checks; catalog v4 348 |

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| TH-B1 | Seed 4242 `backtrack_to_ball1` failure | Root-caused (playthrough bot: a walk into a vortex did not end with the ride) and fixed in `d7619e1`; game behaviour correct | `docs/evidence/2026-09-29-release-blockers/`; regression `--start=vortexrace` (fails without the fix, passes with it) |
| TH-B2 | World 7 eel-grotto freeze (seed 4242; also a dev-000029-era run) | **Not a player softlock.** Normal input escapes everywhere near the spot (181 probe points). Root cause is the playthrough bot: on 1 hp it walked straight at food on the far side of the grotto wall, with no progress check. Fixed (food needs a clear line; the food walk gives up without progress) | Same folder; reproduction `--start=eels --eel=b7.eel.0 --hp=2` freezes before the fix and wins after |
| TH-B3 | dev-000030's published-pack check: a hunt that could not be finished (microscope on a tower top with no room beside it) | Fixed for dev-000031. Leaf and rock perches need a standable spot beside them within a lunge (`perch_approach`); saved targets are rechecked when shown, so stuck hunts on phones repair themselves; no spot within 7 m of a vortex mouth; the lunge aims at the object unless food is nearer | Seeded stress `_phase_treasure_stress`: 21 of 336 missed before the fix; after it 420/420 and 140/140 on new seeds. Regression `treasure_no_perch_without_room`. **Qualification of `77f0381`** (release policy, `MOTE_HANDOFF.md` §18 rule 3): treasure tests 37/37; stress 560/560 over 40 seeded hunts (both sizes, 10 on fresh seeds); food tests; unit suite 476/476; seeds 7 and 4242 23/23 to 100%. Not rerun as redundant: OTA end-to-end (OTA client and native layer byte-identical to dev-000030, whose end-to-end passed 42/42) and performance (no startup, rendering or continuous-gameplay code changed). **Published and verified as dev-000031** (source `c2f3126`, PCK `8dc85f64…c8623`, 10,949,816 bytes, 38 baked caches): signature with the pinned key, hash, size, inspection OK; 153/153 tests run from the downloaded pack; stress from the pack 84/84; a b22 client finds it compatible and stages it (matching hash). Nothing phone-verified yet |
| TH-O1 | Debug scenario `--start=eels`: `b5.eel.0` (a missed fight) and `b7.eel.2` (routed over the grotto roof) | Open, pre-existing (identical on dev-000029), not a release gate | `eels_all_dev29.log`, `eels_all_before_food_fix.log` |

## AX: Aquarium / UI / bedroom / exterior / fish / Swim package (dev-000032)

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| AX-01 | Live Tank fish visible, bala sharks noticeable (no fake fish) | I+V | Diagnosed: all 13 alive and simulating, 10-20 px from the room; presentation-only 3.4× display scale plus `pop`; `live_tank_fish_present`, `fish_scale_only_outside` |
| AX-02 | Keep restoration murk as a progression cue; fish readable; clean tank beautiful | I+V | Edge-weighted algae (`glass.gdshader`); murky/half/clean renders |
| AX-03 | Exterior represents the real game (far view, not raised gameplay culling) | I+V | `MossBall.set_far_view`: built while an outside view is open, freed after; plants under 0.45 m left out, 15k triangles per world |
| AX-04 | UI visual language (Treasure Hunt panel as reference), no black boxes, pressed states | I+V | `UiStyle` theme across title, pause, Settings, colours, aquarium, Treasure Hunt; renders |
| AX-05 | Settings gear (owner PNG as supplied) on the title; same Settings with diagnostics; Back to title; no run/timer/save change | I+V | `title_settings_gear`, `title_settings_open_and_back` |
| AX-06 | Gill's colours split workspace; Gill always visible, drag to turn, live updates, persistence | I+V | `colours_split_workspace`, `colours_no_scroll_gill_always_shown` (was `colours_scroll_keeps_gill`; no scrolling since `00038-menus-landscape`), `colours_live_update`, `colours_drag_turns_gill`, `colours_slider_never_turns`, `colours_persist`; renders at 16:9 and 20:9 |
| AX-07 | Swim: exactly two controls; flight-stick pitch (pull down = up); Swim held propels; glide | I+V | `swim_exactly_two_controls`, `swim_touch_controls`, `swim_pitch_default_and_inverted`, `swim_stick_turns_him`, `swim_button_propels_along_nose`, `swim_no_drift_without_input` |
| AX-08 | Persistent "Invert swim up/down" (pitch only) | I+V | `[controls] swim_invert_y`, schema 1; `swim_invert_persists` |
| AX-09 | Bedroom rebuilt as a lived-in late-80s/early-90s room, original unbranded props | I+V | `bedroom.gd`, `gen_room.py`; renders; built after the title (`bedroom_built_after_startup`), unshaded with its own lights (bedroom ~107 → 22 ms/frame on the test renderer) |
| AX-10 | Performance measured | I+V | Like for like vs dev-000031 (`--only=perfaqw`, warm): play unchanged; Swim +3–10%; Inspection/Live +11–26%; Room ≈ +35% (the fish and plants now visible) |
| AX-11 | One OTA, verified | I+V | dev-000032: source `92cb988`, PCK `e3ade9ab…a878bd`, 12,950,784 bytes, runtime r5, game 0.1.0; signature, hash, baked shaders, inspector from public URLs; Build & Verify #42 and OTA publish #32 green; b22 client downloads, verifies and stages it (hash matched). Unit suite 495/0 and seed 4242 23/23 before the last performance fixes; aquarium/UI tests 54/54 on the final code. Pack tests: 168/172 — `treasure_full_hunt_by_lunges` missed one object once (random-seeded hunt; spot not recorded); root-caused and fixed in dev-000033 (LOCO-03) |

## LOCO: Gill locomotion, readable lift columns, Treasure Hunt pickup (dev-000033)

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| LOCO-01 | Open Issue #1 locomotion and traversal | I+V | See Mote Open Issues #1; docs/LOCOMOTION.md |
| LOCO-02 | Open Issue #2 elevated content readable | I+V | See Mote Open Issues #2 |
| LOCO-03 | Every Treasure Hunt object collectable by a lunge (dev-000032 published-pack check: a missed object) | I+V | Stress over 672 hiding places found 3 misses, all the tall rubber duck: pickup was measured to one point 45% up the object, above the lunge's sweep; now to the upright axis (15–85% of height). Re-stressed 671/672, the last a test-helper wedge (fixed: the helper steps round when he cannot move), then 14/14 on that hunt. |
| LOCO-04 | One OTA, verified | I+V | dev-000033: source `fe5bbc6`, PCK `b85c1f34…b7fa25`, 12,977,508 bytes, runtime r5, game 0.1.0; signature, hash, baked shaders and inspector from public URLs; OTA publish #33 green; the b22 client discovers, downloads, verifies and stages it (hash matched); tests from the downloaded pack 172/0 (treasure included). Candidate evidence: full unit suite 509/0, seeds 4242 and 7 23/23 to 100%, rendering unchanged vs dev-000032 (20 views, two rounds), memory +1 MB; after the last ground-probe change the locomotion, model and aquarium tests 37/37. |

## MOTE OPEN ISSUES (owner, 2026-09-29)

| # | Issue | Status |
|---|---|---|
| 1 | **Gill fluid body locomotion and terrain traversal.** Head leads, body follows, tail completes the motion, on the ground and while swimming. The body bends through turns (yaw) and dives and climbs (pitch) progressively, and conforms progressively to terrain. Distributed traction: a short steep lip is pulled over once the front has purchase above it; a long continuous steep face makes him lose traction and slide, with no wall adhesion and no ratcheting. Responsive controls with organic follow-through. Every gameplay contract is preserved (jump, burst, lunge, falls, canopy rule, combat, caves, ravines, saves, completion, Treasure Hunt, the aquarium modes). | Implemented (docs/LOCOMOTION.md): per-segment follow-through (head leads, body and tail follow through turns, climbs and dives, on the ground and swimming, no added input lag); ground conformity (4 probes, re-probed every other frame); distributed traction (a lip up to 0.42 m is pulled over once the front has purchase; one pull per landing on gentle ground, so long or ledged faces never ratchet; faces over 52° slide, no adhesion; ravine walls unchanged; never a new route: 172 elevated bodies × 966 approaches, no pull reaches a top). Tests `_test_gill_traction`, `_test_traction_no_shortcuts`, `_test_gill_body_follow`, `_test_swim_body_follow`; full unit suite 509/0; seeds 4242 and 7 23/23 to 100%; rendering unchanged vs dev-000032; model CPU about +80 µs/frame on the desktop test machine. Ships in the OTA after dev-000032. |

| 2 | **Elevated content reachability** (owner phone finding, 2026-09-30): jellyfish-like content (probably a Regeneration Mote) on top of a tall, sheer mushroom/pillar with no readable route. Investigate the exact place and content, prove or disprove a route within Gill's limits, judge readability, and audit all elevated content. Classify each case: awkward terrain the locomotion work will fix, or missing route geometry that needs a level-design fix. Never solve it by letting him climb sheer walls. | Recorded; investigated alongside Open Issue #1. Screenshot received 2026-09-29 ~22:40 EDT: a thick trunk flaring into a wide cap, standing where dark unrestored ground meets restored teal ground; a pale cyan glow shows over the cap rim, and a column of rising bubbles runs beside the cap (possibly the intended lift). **Investigated (2026-09-29, headless probe of all 7 worlds):** almost certainly (~80%) world 7 Hollow Grotto, "The Shaft": `MeshLib.shelf` built at `world_expansion.gd:758` (lat/lon 1.2, 11.6), cap top 6.0 m up, cap radius 2.4 m, stem radius 1.3 m, a Regeneration Mote on top at 6.5 m (`:765`); the corals are world 7's accent colours. A route exists and passes the route audit: an always-flowing bubble column (`:761`, 5.5 m/s, top ~7.4 m) whose axis is 5.2 m from the pillar's, from whose top he drifts or bursts ~2.7 m onto the cap. **Class B (unreadable route, level design):** the bubbles are small and faint in world 7's dim water, the vent is a low pebble ring, and the column stands 1.5–1.9 m clear of the rim, so it reads as background bubbles, not a lift. The same pattern, weaker, on world 1's two Fern Grove shelves (`levels.gd:545-555`) and world 2's High Hollows shelf. No elevated content depends only on a column that is dormant before restoration (the two gated columns are shortcuts beside an always-present route). Overhanging 2.6–3.4 m shelves reached from step mounds are class A (the lip pull-over will forgive clipped jumps). Nothing requires wall climbing. **Planned fix (ships with the locomotion OTA, not the aquarium one):** move column vents under the cap rim (Shaft ~3.4 m from the axis, Fern Grove ~2.8 m), make every column read as a lift (more, larger, lit bubbles; a glowing vent), and test that each column route's axis is within cap radius + 1.2 m of its platform and that a gated column is not counted as readable while dormant (`unit_tests.gd:672`, `:741`). **Fixed** (same OTA as Open Issue #1): the Shaft column 5.2 → 3.7 m from its axis, Fern Grove 4.0 → 3.0 m, High Hollows 4.6 → 4.2 m, each clear of the cap for him rising; columns read as lifts (120 larger, brighter, cyan-tinted bubbles and a pulsing vent glow shown only while flowing); test `lift_columns_beside_their_platforms` (every always-flowing lift column within 4.3 m of its platform; gated shortcuts exempt); before/after renders from four sides. |
| 3 | **Organic enemy movement** (owner-authorized 2026-09-30; implemented straight after Open Issue #1 is published and verified, with no wait). Deterministic underneath, apparently spontaneous to the observer. Separate intent (the existing AI: wander, patrol, pursue, investigate, attack, retreat, guard, return home, avoid, authored behaviours) from expression (low-frequency wander, medium-frequency weave, vertical drift, speed modulation, small body motion) built from several smooth deterministic signals with non-harmonic frequencies, phases and amplitudes. Per-species personality (small and nervous: quick small corrections; large: broad slow arcs; eels: flowing lateral motion) and per-individual phase from stable identity; no per-frame randomness. Committed attacks, lunges, retreats and scripted moves stay readable: intent dominates; no unfair dodging or arbitrary misses. Terrain, caves, walls, ravines, encounter and world bounds always win. Lightweight on mobile; tested at representative enemy counts. Proof: tests (determinism, individual variation, no synchronisation, bounds, frame-rate independence, collision, pursuit and attacks still work, cost) plus before/after motion captures of several creature types, long enough to expose repetition. Reuse what Gill's locomotion builds where it fits, without widening that work. | Done in dev-000035, `00035-enemy-movement` (delivery verified on the phone; movement verdict pending). **Published and verified 2026-09-30 13:57 EDT**: source 7fa03d7, PCK sha256 f9c1e834…f482c (13,068,484 bytes), signature verified with the pinned key, baked shaders present, inspection OK; OTA publish #35 and Build & Verify #45 green; published-pack tests 230/0; b22 update client discovers, downloads, verifies and stages it (same hash). **Owner phone delivery/activation verified (2026-09-30):** active and latest dev-000035, source 7fa03d7, PCK sha256 f9c1e834…f482c, boot healthy, runtime compatible, 0 rollbacks, no rejected OTAs, nothing pending, this run healthy. The player-facing verdict on the movement itself is still pending (not approved yet). An expression layer (`OrganicMotion`, `scripts/actors/organic_motion.gd`) bends only the direction and speed each creature's existing AI feeds its existing move-and-collide step: 2–3 incommensurate sines per output, per-individual phases, tempo wander, threshold hesitations; no random draws, frame-rate independent; switch `OrganicMotion.enabled`. Personalities per species. Fully off from wind-up on (strikes, pounces, charges, telegraphs), fades out within reach, no pauses while hunting; the glob stays rigid. Grazing moved to each parasite's own RNG (gameplay RNG untouched); the bloom pulse also holds parasites within 10 m off attacking for 3.5 s after he re-forms. Results: straight stretches 26–33% → 6–7%, 180° reversals 13 → 3 per minute (medium); committed attacks bit-identical on vs off; pursuit time 0.99–1.05× baseline; 2.3 µs per creature per frame. Merged onto dev-000034: full suite 523/0, seed 7 23/23 to 100%. Known: grazing in small home areas still loops; small parasites still reverse about 14 times a minute. Design: `docs/ORGANIC_MOTION.md`. |
| 4 | **Locomotion physical-device correction** (owner phone playtest of dev-000033, 2026-09-30; dev-000033 confirmed active and healthy on the b22 phone: source fe5bbc6, PCK b85c1f34…). (A) Gill still does not look liquid/flexible in ordinary play: head leads → shoulders → middle follows the path → hips → tail completes, visibly, in turns, climbs, descents, rolling terrain and swimming. (B) On an ordinary-looking moss incline from fairly flat ground he face-plants into the transition, gets no purchase, does not bend up across it, makes no progress holding forward, and slides sideways along the bottom. Distributed traversal over terrain SHAPE and available purchase, not a max slope; crawlable-looking irregular moss is traversed by holding forward (no jump, burst, wiggling or magic angle), while cliffs, ravine walls, cave walls, authored barriers and platforming restrictions stay. Root-cause the gap between passing tests and the phone (runtime diagnostics: running / overwritten / too weak / traction rarely active / collision architecture defeats it / other); fix the architecture, not a blind tune; prove on real authored terrain; before/after vs dev-000032 from the gameplay camera. Organic Enemy Movement must not be built on body-follow assumptions until this is sound. | Done in dev-000034 (awaiting owner phone check). Root causes, measured on the real game path: the body follow ran and was never overwritten but was too weak to see (tail offset 28 px with it on vs 29 px off in a broad turn); the lip pull's gates almost never passed (D); and the head guard (face-plant) plus the 52° wall slide (sideways slide) won every frame (E). Fix: before treating steep ground as a wall he reads its shape out to 1.6 m (along his heading, and up the face when it turned him aside) and crawls a band of 0.6 m or less that has walkable, still purchase beyond it; everything else is a barrier exactly as before; designed jumps (cushions, terrace tiers, stone columns, rising stones) are marked `jump_only` and never crawled. Model: a time-based follow (about a third of a second from head to tail at a run), a bend held through turns, the head leading the turn, a crawl pose. Evidence: 7/7 owner-type inclines climbed (0/7 on dev-000033); real terrain arch, ridge and dome spots; tail offset 46/62/120 px in broad/sharp/zigzag turns (28/29/63 before); no-shortcut survey 1,928 approaches, 0 shortcuts; 0 crawls within 5.4 m of any vortex mouth; full suite 512/0; seeds 4242 and 7 23/23 to 100%; merged with the vortex tints, focused tests 106/0. Release name `00034-locomotion-fix`. Not changed: sideways traversal along a cross-slope; swimming has test evidence only (turn bend 28°→85°, dive bend 9°→26°). **Published and verified 2026-09-30 13:15 EDT as `00034-locomotion-fix` (dev-000034)**: source 05c11a8, PCK sha256 686a60b4…380aa (13,022,292 bytes), signature verified with the pinned key, baked shaders present, inspection OK; OTA publish #34 and Build & Verify #44 green; published-pack tests 193/0; b22 update client discovers, downloads, verifies and stages it (same hash). **Owner phone result (2026-09-30): "Locomotion is much better"** on active dev-000034: positive physical-device evidence; the locomotion architecture is not reopened. |
| 5 | **Vortex connection identity** (owner, 2026-09-30): nearby vortex entrances were mistaken for one another. A restrained per-connection hue (the same at both ends, stable), predominantly still water; prioritise entrances confusable from the same area; destinations, physics, progression, saves, timers and completion unchanged. Rides with the locomotion correction if clean. | Done in dev-000034 (awaiting owner phone check): `Vortex.TINTS` by link, the same at both ends, no two connections sharing a ball alike (closest pair 0.49 apart); tinted foam/streaks, pool ring and debris at `TINT_AMT` 0.5 over the water colour; destinations, physics, progression, saves, timers and completion untouched. **Published and verified 2026-09-30 13:15 EDT as `00034-locomotion-fix` (dev-000034)**: source 05c11a8, PCK sha256 686a60b4…380aa (13,022,292 bytes), signature verified with the pinned key, baked shaders present, inspection OK; OTA publish #34 and Build & Verify #44 green; published-pack tests 193/0; b22 update client discovers, downloads, verifies and stages it (same hash). Owner phone check pending. |
| 6 | **Gill skill tree + red starfish** (owner approval with changes, 2026-09-30; release `00036-skill-tree`, after 00034 and 00035). The researched 15-node dependency tree is approved as drawn: 5 families (Mote Magnet, Quick Gill, Water Burst, Lunge, Glide) x 3 tiers; roots Lunge I, Quick Gill I, Water Burst I; 9 cross-family prerequisites; costs 1/2/3, 30 in total; the graph proof (acyclic, all reachable, every legal order reaches 15/15, no deadlock) is kept as a test. Glide: hold Jump in the air (no new button); release ends it; Water Burst stays usable in a glide and once per air. **Glide III must be reduced**: local traversal (tower to nearby leaf, leaf to leaf, platform to nearby platform, recovery), never long-distance transport; values from real world geometry, with tests of intended AND still-impossible transfers; natural physics before any arbitrary cap. Permanent Gill progression survives New Run; Tier 2 stays per run; Treasure Hunt unchanged. Its home is chosen by semantics and compatibility (a dedicated permanent-progression store if cleaner; `run.json` NOT pre-approved; never `settings.cfg`); survives OTAs, b22 installs, migration and rollback, with backup/recovery. Exactly 30 authored red starfish with permanent ids, all reachable with no upgrades; touch pickup (also in the air), red with a soft local glow, a distinctive pickup sound. **Loss-proof persistence:** a collected id can never lose its value and a purchase can never be half-applied (derive the balance from authoritative collected ids and purchased nodes); interrupted-save tests. Not in the 348-id completion catalog; shown separately (Red Starfish n/30, Skills n/15); finishes show Skills n/15; no skills-off mode; no respec. Built against the final verified locomotion. | **Downloadable as dev-000037** ("skill tree"; 2026-09-30 18:15 EDT; dev-000036 was a failed, unpublished run: a treasure test wedged on one random hunt spot, harness fixed). Verified: source 7aa6b06, PCK sha256 1926aeeb…ee17 (13,203,980 bytes), signature, baked shaders, inspection, b22 staged; published-pack tests 208 passed, 1 test-harness failure (the sound test read source .wav files that packs never contain; fixed in the next release). Awaiting owner phone check. Dedicated loss-proof store `user://gill_progress.json`; 30 starfish (no-skill sweep 30/30); Glide "tiring wing" (G-III: 32 m from the 29 m High Crown vs 88 m researched; far transfers and barriers stay impossible); graph proof and 12/12 loss-proof cases. Qualification on the merged candidate (with 00035): full suite 575/0, seed 7 23/23, seed 4242 with all skills 23/23. Details: `docs/SKILL_TREE.md`; checklist `docs/evidence/2026-09-30-skill-tree/`. Old issue noted: the Root Hollows curtain can be hopped with no skills (3/10), pre-existing. Follow-up in the opening-audio OTA: Mote Magnet strengthened (a drawn Mote's wander yields to the pull; Magnet III closes about 1.75 m instead of about 0.8 m on average; still never captures) and its test made deterministic. Follow-up (owner phone screenshot): the Skills page opened from the title showed the title menu through it: its dimming layer was anchored and stayed zero-sized when the page opened before its parent had a size. Now sized explicitly to the screen, plus a rounded shaded panel behind the tree. |
| 7 | **No-scroll landscape UI** (owner phone findings, 2026-09-30). Colour Customizer: stop improving scrolling; a wide two-column landscape window with NO scrolling (controls left, large persistent rotatable Gill right; no fallback scroll on small screens). Settings (mid-game): also a narrow scrolling panel the owner fights; make it a wider landscape interface (two-column groups, compact rows, touch-size sliders/toggles), eliminating or greatly reducing scrolling without shrinking below comfortable touch size. | Audited; authorized for the queue as `00038-menus-landscape`. Root cause: STOP-filter controls swallow drags (only 44–52 % of the colours window scrolls). Spec: `docs/research/2026-09-30-DEVICE_AUDIT.md` (owner rulings 2026-09-30). **Implemented** on branch `mote-menus-landscape` (not yet published): no ScrollContainer in either page. Colours: a 590–640 px control column (header with Reset/Done, 4×2 morph swatches, a Body/Freckles × colour/shade slider grid, a 4×2 pattern grid with Upload… as a cell, Full colour + Repeats) beside Gill's stage (570–840 px wide, full height); the upload status is a caption over the stage; a compact swatch size exists for a shorter safe area, still without scrolling. Settings: one panel up to 1212 px wide in the safe area; left column of 64-px actions (Resume, Return to Title, New Run, Aquarium, Treasure Hunt, Gill's colours, Skills), right column with the run and two-column detail, the Tier 2 loadout as one row, 2×2 toggles, Music | Sound, and controller status / startup line beside About / Diagnostics (moved there from the left column so Treasure Hunt and the New Run question fit). Sliders (`TouchSlider`) take hold only on the thumb (sideways) or a tap on the track, never from the wheel or a swipe; swatches, pattern cells and toggles ignore a press that moved more than 16 px. Tests: `settings_opens_on_screen`, `settings_fits_landscape_no_scroll`, `colours_fits_landscape_no_scroll` (1280/1560/1600 × 720, 90 px cut-out either side, Settings at its fullest and from the title), `colours_drags_neither_scroll_nor_recolour`, `colours_taps_and_thumb_still_work`, `settings_drags_neither_scroll_nor_change`, `settings_tap_still_toggles`; renders `--test=shots --only=menus` at 1280×720 and 1600×720. Physical-device check pending. **Pushed as dev-000040** ("menus", 2026-09-30 19:43 EDT): source 3cadf47, PCK sha256 5fffcee3…3353, signature, inspection, b22 staged, published-pack tests 196/0. Awaiting owner phone check. |
| 8 | **Pause menu order** (owner ruling, 2026-09-30): 1. Resume, 2. Return to Title directly beneath it. | Audited; one-line change, rides with `00038-menus-landscape`. Spec: `docs/research/2026-09-30-DEVICE_AUDIT.md` (owner rulings 2026-09-30). **Implemented** on branch `mote-menus-landscape` (not yet published): Resume, then Return to Title directly beneath it (hidden from the title screen's Settings as before); test `pause_order_resume_then_title`. **Pushed as dev-000040** ("menus", 2026-09-30 19:43 EDT): source 3cadf47, PCK sha256 5fffcee3…3353, signature, inspection, b22 staged, published-pack tests 196/0. Awaiting owner phone check. |
| 9 | **Aquarium View: Gill clips into scenery** (owner phone finding with VIEW FILL, 2026-09-30). Gill must swim AROUND things like an animal: curve before contact, head leads and body/tail follow, pass close without entering, body-aware clearance, layered stuck recovery (no visible teleports), organic non-repeating exploration; long-duration measured and rendered proof with VIEW FILL exercised. | Audited; authorized for the queue as `00039-aquarium-gill`. The owner's "VIEW FILL" = the existing **Gill close-up** view (no new mode). Home range ~10 m (soft), occasional natural resting. Root cause: the stand-in has no environment awareness (single-point snap, rigid body); 19/168 homes clip deeply. Spec: `docs/research/2026-09-30-DEVICE_AUDIT.md` (owner rulings 2026-09-30). |
| 10 | **Tall aquarium plants end badly** (owner phone finding + office-plant reference photo, 2026-09-30): the stem must terminate in foliage (taper, tighter spacing, smaller young leaves, a terminal cluster; no bare stick above the last leaf), with per-plant variation. | Audited; authorized for the queue as `00040-plants`. Generator `MeshLib.stem_plant_mesh`; terminal-growth rules and variants specified. Spec: `docs/research/2026-09-30-DEVICE_AUDIT.md` (owner rulings 2026-09-30). |
| 11 | **Normal mode: cleared areas too empty** (owner, 2026-09-30). Enemies repopulate cleared areas modestly and food repopulates (no instant refill, no pop-in, not an exploit); restoration stays permanent: respawned parasites never grey moss, reduce completion or undo restoration. | Audited; authorized for the queue as `00041-repopulation`. Returners ≈⅓ of authored per zone, first ≥5 min after clearing (initial values, tuned after phone feel), off-camera and distance safeguards; no completion, restoration or progression effects; food local targets and cooldowns. Spec: `docs/research/2026-09-30-DEVICE_AUDIT.md` (owner rulings 2026-09-30). |
| 12 | **Hard Mode: territorial tug of war** (owner ruling 2026-09-30: WE ARE GOING TO BUILD IT; queued LAST, after all currently authorized work). Parasites exert slow, systemic pressure toward DEAD; kills and restored Motes push toward LIVING; enemies and food repopulate; neglected restored territory can slowly regress and Gill can push it back; a DEAD ◄──|──► LIVING HUD indicator. Continuous ecological struggle, not chores. Normal stays unchanged in principle (repopulation, but restoration permanent). The research must be overnight-ready: a complete implementation spec (pressure model, repopulation, regression rate/limits, anti-collapse, off-ball and app-closed behaviour, save/load and migration, vortex/progression protection, completion/finish, timer, HUD, balance, Motes, blooms/save points, skill tree, determinism, performance, tests, long-duration simulation, visual QA, release qualification), and the player-facing decisions that would block an autonomous build brought to the owner while available. On the owner's "Build Hard Mode": implement, test, simulate, validate, repair, qualify and publish without further design. | **APPROVED / QUEUED LAST / SPECIFICATION COMPLETE / IMPLEMENTATION NOT YET STARTED. HARD MODE AUTONOMOUS BUILD: READY.** **BUILD AUTHORIZED IN ADVANCE (owner, 2026-09-30 evening, confirmed: "Continue with building hard mode"; the later "requires Build Hard Mode" line was a stale template rule in the owner's prompt maker and does not apply).** Start Hard Mode automatically once 00037–00042 are published and verified (or logged and skipped under rule 6), and run the full autonomous plan without waiting for the owner. If an earlier queue item is blocked on the owner, it is logged here and skipped (handoff §18 rule 6), and Hard Mode still proceeds. Final ruling: slow remote incursions (one remote sphere at a time, every ~15–25 min of play, ~15 % of local pressure, never while closed; fairness margin ≥ 2 × response budget kept; chore-loop metrics in the 12-hour simulation, and frequency or pressure is reduced if they fail). Rulings: floor 0.60; finish as Normal; mode chosen at New Run only; HUD = current sphere + zone tick; remote directional distress on the half of each vortex nearest the threatened sphere, in that link's own colour, progressive S1–S3; travel fairness from measured hops (median 21 s, p90 27.6 s, diameter 5). Build only on the owner's exact "Build Hard Mode". Spec: `docs/research/2026-09-30-DEVICE_AUDIT.md` (owner rulings 2026-09-30). |
| 13 | **Opening audio sounds like static** (owner phone finding, 2026-09-30): the loading screen should sound like a household aquarium (gentle bubbling, soft water movement), with a clean handover to title and game audio, no stacking, settings respected, no startup regression. | **Downloadable as dev-000039** ("opening audio", with the Mote Magnet fix; 2026-09-30 19:07 EDT; run 38 failed on the old Magnet test and published nothing). Verified: source e8f99fa, PCK sha256 23daf56c…afb49, signature, baked shaders, inspection, aerator sound in the pack, b22 staged; published-pack tests 191 passed, 2 test-only failures (a source-reading check and a treasure counter assumption; both fixed in the menus release). Awaiting owner phone check. Two co-prime loops (17 s water movement, 13 s aerator), 0% of speaker-band energy above 3 kHz (was 42%); one player per layer; 1.5 s fade-in; eases 3 dB under the title songs; glides, never jumps; Sound slider applies; startup unchanged. Tests `_test_opening_audio`; checklist `docs/evidence/2026-09-30-opening-audio/`. |
| 14 | **Organic vortex tunnels** (owner, 2026-09-30 evening): the tunnels read as straight PIPES; they must read as MOVING WATER CURRENTS. The visible centreline itself curves and slowly meanders in 3D (sideways, vertical, depth); movement is minimal at the anchored mouths and freest mid-span; several slow deterministic influences per axis at different frequencies and phases (no single sine, corkscrew, snake, hose-shake, rapid wobble or synchronised tunnels); a stable personality per connection; bounded displacement; the route stays clearly readable. Travel is preserved (entrances, exits, behaviour, destinations, unlocks, collision, progression, timing within variance, connection colours); preferably a stable logical path under a deforming visual, but Gill must visibly ride INSIDE the moving current. Water character kept (foam, streaks, jets, bubbles, eye/mouth, transparency). Hard Mode compatibility: a stable normalised parameter u along the connection (0 = sphere A, 0.5 = midpoint, 1 = sphere B) stays available to shaders so either half can be animated independently. Mobile-friendly, measured in worst-case views. Visual proof: side and second angle, several together, long-time non-repetition, Gill travelling inside, both mouths while the centre is displaced, worst-case performance, compared with the shipped straight version. | Authorized; queued as its own OTA `00042-vortex-currents`, after 00041 and before Hard Mode (so Hard Mode's distress is built on the final tunnel). Design direction: keep the logical travel path `Vortex.points`; add a deterministic displacement D(u,t) = w(u)·Σ bounded incommensurate sines per axis with w(u) = sin(πu)^1.5 (zero at the mouths), applied in the tube, pool and debris vertex shaders along the existing along-tube parameter, and evaluated identically on the CPU for Gill's ride and the camera so he stays inside the current. |
| 15 | **Climbable leaves: golden-pothos look** (owner, 2026-09-30 evening, with a reference photo of a variegated golden pothos). The leaves Gill jumps on and climbs (spiral/ladder leaves, canopy and stem leaves) take this look: a lively mid-green leaf with irregular cream-to-yellow variegation streaking outward from a pale midrib along the veins, pale edges in places, a soft sheen; each leaf varies. | Queued inside `00040-plants` (same vegetation-rendering risk surface and performance campaign). Surface look only (shader/texture on the existing leaves), so silhouette, collision and climbing are unchanged (`leaf_collision_is_the_drawn_leaf` keeps passing); owner confirmed 2026-09-30: keep the leaf shape, change only the look. Reference photo kept with the release evidence. |
| 16 | **Leaf shape, thickness and bounce** (owner, 2026-09-30 evening; OPEN item, not yet scheduled). (a) Leaf shape and thickness, for example a heart outline like the pothos reference and a fuller blade, kept open; any change must move the collision with the drawn leaf and re-prove every climb. (b) A light up-and-down bounce when Gill lands on a leaf or bumps one from below while jumping: a visual spring on the leaf (and a gentle give under him) that never changes footing, climb routes or jump heights. | Open; to be designed and scheduled with the owner. |
| 17 | **Starfish progression loop** (owner design correction, 2026-09-30 evening; approved). Supersedes "all 30 reachable with no skills". EXPLORE → COLLECT → BUY SKILLS → REACH NEW STARFISH → HIGHER TIERS → FINAL STARFISH: several easy, visible baseline starfish start the economy; middle ones need Tier I/II abilities; a few late ones need advanced traversal; seeing unreachable starfish ("I need to come back for that") is intended. Architecture: NOT coupled to Treasure Hunt; reuse and adapt its placement-selection logic in a separate starfish procedure with its own lifecycle, a candidate library much larger than 30 (authored or proven places on all seven balls, each tagged with the minimum capability needed), its own constraints, persistence and progression validation; the generator picks exactly 30 (distribution, separation, no overlaps, clearance, a baseline/developing/late mix). Validation: from zero starfish and zero skills, against the real dependency graph and costs, EVERY legal purchase order must stay winnable to 30/30 and 15/15 (no skill whose purchase needs starfish that need it). | Approved; queued as its own OTA after `00042-vortex-currents`, before Hard Mode. **LOCKED (owner, 2026-09-30 evening; not to be reopened except under rule 6).** **Economy decision (owner, 2026-09-30 evening): exactly 30 starfish; the full tree costs 27, so 15/15 is affordable before 30/30 and the last 3 starfish are Tier III traversal payoffs that buy nothing (completion/mastery only).** Costs, solved on the real graph with `tools/starfish_econ_check.py`: Tier I 1 each (5), Tier II 2 each (10), Tier III 2 each except Glide III and Water Burst III at 3 (12); total 27 (was 1/2/3 = 30, which the solver shows can never allow a Tier III-gated starfish: any 1 behind a Tier III deadlocks). Verified: with the three finales behind Glide III, Water Burst III and Quick Gill III, plus 11 to 14 middle starfish behind Tier I/II skills, every legal purchase order from zero stays winnable to 15/15 and then 30/30, and the tree is affordable without the finales. Implementation must re-run the solver on the generated layout's real accessibility tags. The costs change for existing players too: bought nodes keep their state, the derived balance rises by the difference, nothing is revoked. |
| 18 | **Sea fan coral is flat sticks up close** (owner phone screenshot + real gorgonian reference, 2026-10-01). Branches are flat rectangular strips, junctions float or merely cross, the colony is coplanar and paper-thin from the side. Rebuild as real 3D: tapered tubular branches, children emerging continuously from parents with merged junctions, restrained fore/aft depth, natural edge irregularity, no repeated angles or symmetry; keep the broad fan silhouette, visual language and mobile budget; fix other procedural props sharing the same root cause where in scope. Visual proof: gameplay distance, close oblique, 45 deg, near-profile (must not collapse to a line), junction close-up. | In progress inside the plants release (rule 7 evidence). |

Standing working rules (continuous playtest feedback; risk-proportionate qualification):
`MOTE_HANDOFF.md` §18.

## Precedence notes

- The reconciliation prompt's floor list repeats two items that the owner changed earlier today: "diegetic
  **dorsal** health" and "~**180°** tail swipe". The owner explicitly chose gill-based health (answering my
  question, then confirming "should have 6 … glowing … dull and faded"), and explicitly asked for a 270° swipe.
  Under the precedence rule (explicit later owner decision wins), these are recorded as SUPERSEDED, not reverted.
  If the owner wants them reverted, that is a one-line decision.
- G-57 ("normal build fully offline") is superseded by the owner's later ruling R-01: offline-capable, not
  offline-only. The normal Mote app now carries the OTA client; nothing requires a connection to play.
- R-11 (Mote Dev kept as a test install) is superseded by the owner's later decision S-01: one Mote app.

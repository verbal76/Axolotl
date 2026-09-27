# Mote — requirement ledger (cumulative, 2026-09-27)

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
| G-41 | Restoration-responsive music; bedroom sounds recede | I+NYV | `scripts/core/audio_director.gd`, `assets/audio/` | not listened to or asserted | |
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
| G-57 | Normal build fully offline | I+V | `export_presets.cfg` (no INTERNET), OTA gated on the `ota_dev` feature | `normal_build_offline_no_ota`; CI APK manifest check | |
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
| F-07 | Install icon from the owner's artwork, everywhere | I+V (APK contents) / BLOCKED (launcher) | `assets/icon/*`, `tools/make_icons.gd`, both Android presets, `config/icon` | `launcher_icons_configured`, `app_icon_is_owner_artwork`; icons extracted from an exported APK: legacy + adaptive = the artwork, themed (monochrome) = the axolotl traced from it (was Godot's robot); placeholder `icon.svg` removed; not yet seen on the owner's launcher | |
| F-09 | Floating food is catchable (owner: "always above me"; chose lower hover + aimed lunge, darters included) | I+V (automated) | `food.gd` hover 0.3–0.9 m and wake calm; `game.gd` `lunge_target`, catch radius 0.95; `axolotl.gd` lunge homing | `food_hovers_at_head_height`, `lunge_rises_and_turns_to_high_food` (fails with the aim disabled), `lunge_ignores_food_out_of_reach`, `lunge_reach_stays_below_jump`, `lunge_wake_leaves_food_in_place`; feel on the phone not yet verified | drifter hover 0.6–1.8 m |

## O — development OTA channel

| ID | Requirement | Status | Implementation | Evidence |
|---|---|---|---|---|
| O-01 | Native shell vs OTA-replaceable game layer | I+V | `scripts/boot/`, `docs/OTA.md` | e2e |
| O-02 | Bootstrap autoload loads the pack before game resources | I+V | `boot.gd` `_init` | e2e steps 9–10 |
| O-03 | `user://ota` storage with an atomic state file | I+V | `ota_core.gd` | unit OTA tests |
| O-04 | Immutable, versioned manifest; mutable channel pointer | I+V | `ota_make_manifest.gd`, `ota-publish.yml` | unit tests, e2e |
| O-05 | Exact source SHA in the manifest | I+V | manifest `source_sha` | e2e step 11 |
| O-06 | Runtime-ID compatibility gate | I+V | `ota_config.gd`, `tools/ota_runtime.py`, `ota/runtime_lock.json` (now r3) | `ota_runtime_mismatch_needs_native_update`; gate caught today's native change |
| O-07 | Publisher workflow: tests, PCK, hash, signed manifest, release, pointer, receipt | I+V | `.github/workflows/ota-publish.yml` | `dev-000008` from `d235cb2` (run 36334069998): receipt `published: true`, `pointer_moved: true`; re-downloaded objects re-verified in CI and again independently (signature, PCK SHA-256 and size, `ota_inspect_pack` INSPECT OK) |
| O-08 | Full PCK first, no deltas | I+V | | e2e |
| O-09 | Download to a temp file, then verify size, SHA-256 and signature | I+V | `ota_updater.gd`, `ota_core.gd` | `ota_hash_mismatch_rejected`, `ota_truncated_download_rejected`, e2e step 15 |
| O-10 | Download now, activate on the next clean restart | I+V | `ota_core.gd` | `ota_stage_marks_pending`, `ota_boot_loads_pending`, e2e |
| O-11 | Transactional CURRENT / PREVIOUS / PENDING and rollback | I+V | `ota_core.gd` | `ota_rollback_*`, e2e step 16 |
| O-12 | Boot-health checkpoint with fallback | I+V | `boot.gd`, `ota_core.gd` | `ota_unhealthy_candidate_abandoned`, e2e unhealthy OTA |
| O-13 | Recovery (boot baseline) reachable even when game UI is broken | I+V (scripted) / I+NYV (gesture) | overlay in `boot.gd` (F9, five taps top-left) | e2e disable/enable; tap gesture not tried on a device |
| O-14 | SHA-256 mandatory plus signed manifests | I+V | RSA verify in `ota_core.gd` | `ota_signature_verifies`, `ota_tampered_manifest_rejected`, `ota_wrong_key_rejected` |
| O-15 | Save-schema compatibility gate | I+V | `ota_core.gd` `save_compat` | `ota_newer_save_blocks_older_ota` |
| O-16 | `dev` channel only (channels are pointers) | I+V | `ota_config.gd` | `ota_channel_mismatch_rejected` |
| O-17 | Diagnostics fields and controls | I+V (text, actions) / I+NYV (touch buttons) | `boot.gd`, `diagnostics_overlay.gd` | `diagnostics_*` tests; buttons not exercised |
| O-18 | Stable HTTPS publication (GitHub Releases) | I+V | `ota-publish.yml` | `ota-dev-000008` release and `ota-channel-dev/latest.json` served publicly |
| O-19 | One real Android end-to-end proof | BLOCKED | | needs the new Dev APK and the owner's phone |
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
| N-04 | App labels "Mote" / "Mote Dev" | I+V | `export_presets.cfg` | CI badging on the signed APKs: `Mote` (com.verbal76.axolotl, no INTERNET) and `Mote Dev` (com.verbal76.axolotl.dev, INTERNET) | replaces "Axolotl" / "Axolotl Dev" |
| N-05 | Package, bundle, signing and OTA identities unchanged | I+V | | `package_ids_unchanged` | |
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
| C-07 | Old key retired cleanly; runtime bumped to r2 (r3 later for the themed icon) | I+V | `ota/runtime_lock.json` | `ota_runtime.py --check` | |

## A — CI and the end-of-day APK

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| A-01 | CI functional and green | I+V | Build & Verify (tests, Android, iOS) and OTA publish all green on `d235cb2`; the final commit's runs are listed in the PR |
| A-02 | New Mote Dev APK built from the final reconciled source | I+V | signed with the Mote Dev keystore (MOTE_STABLE_KEY=true), certificate pin enforced; built from the branch head commit (not the PR merge ref) |
| A-03 | APK identity report (SHA-256, versionCode, …) | I+V | from the Android job log of the final commit (see the PR description) |
| A-04 | First OTA after that APK comes from today's source | I+V | the OTA published by the final commit's push carries the same source SHA and runtime `android-godot-4.7.2-r2` |
| A-05 | Physical-device verification | BLOCKED | owner's phone |
| A-06 | Normal offline APK as a second artifact | I+V | same run: `mote-android-v0.1.0-b<build>` (no INTERNET, same certificate) |

## Precedence notes

- The reconciliation prompt's floor list repeats two items that the owner changed earlier today: "diegetic
  **dorsal** health" and "~**180°** tail swipe". The owner explicitly chose gill-based health (answering my
  question, then confirming "should have 6 … glowing … dull and faded"), and explicitly asked for a 270° swipe.
  Under the precedence rule (explicit later owner decision wins), these are recorded as SUPERSEDED, not reverted.
  If the owner wants them reverted, that is a one-line decision.

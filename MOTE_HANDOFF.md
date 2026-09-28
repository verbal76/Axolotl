# Mote — development handoff

This is the authoritative handoff for continuing **Mote** in a new coding session. It records the
state after the **one-app release** (Mote b22, runtime r5, OTA dev-000014), cross-checked against
the repository, CI, the APK's own content and the published OTA. Earlier states (b18/r3, b21/r4) are
kept below as history.

> **MOTE AUTHORIZED REPOSITORY: `verbal76/Axolotl`**
> Work only in this repository. The previous coding environment also exposed an unrelated
> repository. An isolation audit found it clean and untouched. Do not open, search, or change any
> other repository in Mote work.

## 0. Identities at handoff (do not confuse these)

| Identity | Value |
|---|---|
| Repository / branch | `verbal76/Axolotl`, `claude/axolotl-aquarium-platformer-3y0qyy` (draft PR #1 into `main`) |
| **Handoff document commit** | The commit that updates this file (`[skip ci]`, documentation only). It is newer than the release commit. |
| **Release commit** (APK + OTA source) | `104605727ab2bc48f6b0b6e2d56a0fd44127c5be` (`1046057`) |
| **The one Android app** | **Mote**, `com.verbal76.axolotl`. The separate Mote Dev app is **retired** (owner, 2026-09-27). |
| **Current APK** | **`mote-v0.1.0-b22.apk`** (artifact `mote-android-v0.1.0-b22`), Android build 22, bundled baseline `1046057` |
| **Current OTA / channel pointer** | **`dev-000024`**, built from `6e6f71e` (Expansion 6: final integration pass; includes dev-000015..23). dev-000014 = b22's own game |
| Runtime | `android-godot-4.7.2-r5` |
| Game version / save schema | `0.1.0` / `1` |
| Requirement authority | `docs/REQUIREMENTS_LEDGER.md` (sections G, F, O, V, N, C, A, R, S, P, M, **E1** and the **MOTE OPEN ITEMS EXPANSION LIST**) |
| History | b18 (`854ea84`, r3); b21 (`a72ae3b`, r4); dev-000010..dev-000013 (r3/r4). Superseded (§8); releases kept as evidence. |

> **PHYSICAL PHONE VERIFICATION OF b22: NOT YET DONE.** The owner is uninstalling the old Mote
> install(s) and installing b22 fresh. Earlier owner evidence: Mote **Dev** b21 discovered, downloaded and
> verified dev-000013 (Diagnostics, 18:58 UTC). Do not treat CI results as device results.

**Every push to the branch publishes a dev OTA unless the commit message contains `[skip ci]`**
(see §12). A documentation-only push without it would publish a new OTA whose game content is
unchanged.

---

## 1. Product identity

| | |
|---|---|
| Product | **Mote**: `PRODUCT_NAME` in `scripts/core/game_version.gd`; the title shows `MOTE` |
| Protagonist | **Gill**, an axolotl: `CHARACTER_NAME` in the same file. The collectible **Regeneration Motes** keep their name. |
| Game version | **0.1.0**: `GAME_VERSION`, the single canonical literal in `scripts/core/game_version.gd` |
| Native version | `0.1.0` (`version/name` in `export_presets.cfg`); a separate identity that happens to share the starting value |
| Android build | versionCode = the Build & Verify workflow's `run_number` (current: **22**) |
| Save schema | `SAVE_SCHEMA = 1`, `MIN_SAVE_SCHEMA = 1` in `scripts/core/save_schema.gd` |
| Package | `com.verbal76.axolotl`, label **Mote**: the one Android app; OTA-capable since r4 |
| Retired | `com.verbal76.axolotl.dev` "Mote Dev" (no longer built, tested or installed) |

These identities are separate, and none is derived from another (full policy in `docs/VERSIONING.md`):

- **GAME_VERSION**: the product version. It changes only by a deliberate MAJOR.MINOR.PATCH decision. Commits, CI runs, APK builds and OTAs never change it.
- **Native build / versionCode**: which installed APK shell is on the device. The CI run number sets it.
- **Git SHA**: the exact commit behind the running code. APK builds record the branch commit, never the PR merge ref.
- **OTA id** (`dev-%06d`): which remote game payload is active.
- **CI run**: which GitHub Actions run built or published it.
- **Save schema**: the persisted-data format. It is independent of all the above.
- **Runtime id**: which OTAs an APK accepts.

Diagnostics shows all of them together (Pause → About / Diagnostics, F9, or five quick taps top-left).

---

## 2. Owner-ruled game design (intent)

This is the design the owner asked for, including later decisions that replaced earlier ones.
§3 records what is implemented.

- **Setting:** an aquarium in a child's bedroom holds three spherical moss balls (marimo). They
  are damaged by parasites, and Gill restores them.
- **Gravity:** sphere-centred gravity, full surface traversal, stable orientation, no flip at the poles.
- **Movement:** camera-relative, with acceleration and deceleration; a four-legged underwater scuttle.
- **Jump:** a push-off first jump, with coyote time and jump buffering.
- **Airborne burst:** one directional water burst per airborne sequence. It resets on landing. No double jump.
- **Lunge (feeding):** catches food and Regeneration Motes. It aims toward food ahead, above or
  below (§5), and never rises higher than the jump.
- **Tail swipe:** covers **~270°**. Everything except a 90° cone straight ahead is hit. The body
  turns toward the **nearest parasite**.
- **Health:** shown on Gill only, by **six gill fronds**. Active gills glow with colour. Lost health
  turns a gill dull and faded, and all six are always present. Base health is 3; one upgrade per
  cave (three caves) raises it to 6.
- **Food:** drifter +1, darter +2, burrower full heal. Food repopulates out of view. Food is
  catchable at head height.
- **Motes:** they wander, cast real local light and are never auto-collected. A deliberate lunge
  captures one and restores its patch. A near miss pushes it away.
- **Parasites:** 1-, 2- and 3-hit types. Health is shown only by colour draining head to rear, with
  no health bars. Attacks are telegraphed, and bodies drift away when dead.
- **Landings:** hard landings kill small parasites and cost medium parasites one stage plus
  knockback. There are four personality landing variants. The extreme canopy drop is telegraphed,
  deals 2 stages and costs 1 health, never the last.
- **Checkpoints:** moss blooms. On death Gill regenerates with no death screen, at full health, and
  progress is kept.
- **Restoration:** continuous, local and per ball, with no percentages shown. Global aquarium
  restoration (water, gravel, ooze, algae, bedroom visibility) follows it. Music (the owner's two songs, alternating) un-muffles and bedroom
  sounds recede as it progresses.
- **Vortex:** grows continuously and connects at ~70% with a short cinematic. Travel works both
  ways and Gill surfs it. Backtracking between balls is allowed.
- **Moss Ball #1:** the classic marimo and the tutorial.
- **Moss Ball #2:** the current changes walking, jumping and parasite knockback. A mesa is
  reachable only by riding current-swayed plants.
- **Moss Ball #3:** dense jungle with a spiral canopy climb. Flexible leaves cushion falls and
  rebound.
- **Caves:** one optional interior cave per ball, each holding a health upgrade.
- **Completion:** after full restoration comes a quiet payoff, then a restrained ALL CLEAR, then free roam.
- **Terrain:** smooth rolling hills. Platforms are solid from every side.
- **Camera:** an assisted over-the-shoulder camera plus a manual camera swipe on the right side.
- **Mobile controls:** a touch HUD with a floating left stick and Jump/Burst, Swipe and Lunge
  buttons (no dodge button). It also has a Reduced HUD option, respects safe areas, and is landscape only.
- **Controller:** Bluetooth controller support, switching automatically between touch and controller.
- **Other settings:** optional haptics and a minimal pause/settings menu.
- **Title:** a live aquarium background with Gill visible, a minimal menu, `MOTE` and `v0.1.0`.
  No exposition such as "Meet Gill".
- **Audio and performance:** original procedural audio. Target is 60 FPS with quiet automatic
  thermal/performance scaling.
- **Assets:** all original and procedural.
- **Launcher icon:** the owner's axolotl artwork (`assets/icon/icon_source.png`).
- **Builds (owner rulings):** Mote is **offline-capable, not offline-only**. The installed Mote app
  bundles the complete current game, needs no connection to launch, play, save or finish, and checks
  for signed, compatible OTAs whenever a connection happens to be available, never waiting for one.
  **One Android app and one APK:** the Mote Dev app is retired; the `dev` OTA channel stays.
- **Startup (owner):** launching must never look dead, and should be as fast as safely possible:
  the engine splash shows the Mote artwork, the first game frame is the Mote loading screen, the
  world is built in named stages behind it, and shaders are baked into the APK.

## 3. Current implementation — code map

Everything below is Godot **4.7.2**, Mobile renderer, GDScript.

| Area | Files |
|---|---|
| Game controller: combat rules, lunge targeting and contact, eating, Motes, prompts, restoration events | `scripts/core/game.gd` |
| Gill: physics, movement, jump, burst, lunge, swipe, landings | `scripts/actors/axolotl.gd` |
| Gill: model, 11-bone skinned spine, six gills, gait, animations | `scripts/actors/axolotl_model.gd`, `shaders/gill.gdshader` |
| Food | `scripts/actors/food.gd` |
| Regeneration Motes | `scripts/actors/mote.gd` |
| Parasites | `scripts/actors/parasite.gd`, `shaders/parasite.gdshader` |
| Checkpoint blooms | `scripts/actors/bloom.gd` |
| Moss balls: gravity frame, terrain hills, restoration field, current | `scripts/world/moss_ball.gd` |
| Level content for the three balls | `scripts/world/levels.gd`, `scripts/world/level_builder.gd` |
| Platforms, sway and flex leaves, crumble, upgrades | `scripts/world/platforms.gd` |
| Procedural meshes (winding matters) | `scripts/world/mesh_lib.gd` |
| Vortex | `scripts/world/vortex.gd` |
| Aquarium and bedroom | `scripts/world/aquarium.gd` |
| Water response | `scripts/world/water_fx.gd`, `shaders/vegetation.gdshader` |
| Camera | `scripts/camera/follow_cam.gd` |
| HUD, pause, title, UI style | `scripts/ui/hud.gd`, `scripts/ui/pause_menu.gd`, `scripts/ui/title_screen.gd`, `scripts/ui/ui_style.gd` |
| Settings and save metadata | `scripts/core/settings.gd` (writes `[meta]` into `user://settings.cfg`) |
| Run save, run timer, completion | `scripts/core/run_save.gd` (`user://run.json`), `run_clock.gd`, `completion.gd`; wiring in `Game` (`_open_run`, `_apply_run`, `_earn`, `_finish_run`). Rules and catalog: `docs/COMPLETION.md` |
| Audio | `scripts/core/audio_director.gd`, `scripts/core/sfx.gd`, `assets/audio/` (sound effects from `tools/gen_audio.py`; music = the owner's two songs, `music_aquarium_whimsy.ogg` and `music_bubbly_underworld.ogg`, Ogg Vorbis from the owner's WAVs) |
| Performance scaling | `scripts/core/quality_scaler.gd` |
| Version and save schema | `scripts/core/game_version.gd`, `scripts/core/save_schema.gd` |
| **Native OTA bootstrap** (ships in the APK) | `scripts/boot/boot.gd` (first autoload), `ota_core.gd`, `ota_updater.gd`, `ota_config.gd` (public key, channel, runtime revision), `diagnostics_overlay.gd` |
| Startup | `scripts/core/startup_trace.gd` (milestones, pause-menu summary, `--startup-probe`), `scripts/ui/loading_screen.gd`, `Game._ready` (staged build), `assets/icon/splash.png` (boot splash, from `tools/make_icons.gd`) |
| Tests | `scripts/tests/test_runner.gd`, `unit_tests.gd`, `ota_tests.gd`, `ota_http_stub.gd` (local HTTP server for the update client), `playthrough_bot.gd`, `shots.gd`, `model_preview.gd`, `perf.gd` |
| Tools | `tools/pck_files.py` (list a pack, `--require-baked`, `--diff`), `tools/ota_runtime.py`, `ota_make_manifest.gd`, `ota_inspect_pack.gd`, `ota_e2e_local.sh`, `version_drift_check.sh`, `print_identity.gd`, `write_native_build_info.py`, `make_icons.gd`, `check_scripts.gd`, `gen_textures.py`, `gen_audio.py` |
| Icons | `assets/icon/`, generated by `tools/make_icons.gd` from `icon_source.png` |
| Docs | `docs/REQUIREMENTS_LEDGER.md`, `docs/COMPLETION.md`, `docs/OTA.md`, `docs/VERSIONING.md`, `README.md`, `docs/screenshots/` |

Running the checks locally (`godot` = the Godot 4.7.2 binary):

```
godot --headless --path . --fixed-fps 60 --max-fps 0 -- --test=unit --out=OUTDIR [--only=_test_food]
godot --headless --path . --fixed-fps 60 --max-fps 0 -- --test=playthrough --seed=4242 --out=OUTDIR   # also --seed=7
bash tools/version_drift_check.sh        # needs `godot` on PATH
bash tools/ota_e2e_local.sh              # needs Linux export templates
python3 tools/ota_runtime.py --check     # runtime gate; --bump when the native layer changes
```

Environment gotcha: do not run `pkill -f` with a pattern that also matches the invoking shell's
own command line. It kills the shell.

## 4. Current verified state (automated)

Evidence on the release commit `1046057`:

| Check | Result |
|---|---|
| Unit suite (mechanics, startup, OTA client/server, packaging, version, naming, gill, terrain, food) | **167 passed, 0 failed** (local; CI gate green) |
| Playthrough bot, seeds 4242 and 7 | **12/12** each |
| Version drift check | passed |
| OTA local end-to-end (`tools/ota_e2e_local.sh`) | ALL PASSED (42 checks, incl. startup order with no network / a hanging server, and a full offline playthrough by the exported game) |
| Runtime gate | `r5 unchanged (godot 4.7.2): OTA-compatible` |
| Build & Verify #22, [run 36352308882](https://github.com/verbal76/Axolotl/actions/runs/36352308882) | success: tests, playthrough, drift, gate; APK b22 exported with shaders baked and verified (§10); iOS simulator build |
| OTA publish #14, [run 36352306690](https://github.com/verbal76/Axolotl/actions/runs/36352306690) | success: `dev-000014`, baked, published, pointer moved |

Startup (desktop, Vulkan Mobile renderer on a software GPU; relative, not phone times): first Mote
frame 7.0 s → 0.7 s cold; usable title 7.0 s → 6.4 s cold. Root cause (measured): a synchronous world
build and 66 + 25 GPU pipeline compilations before the first frame, behind a plain-colour splash; b18
was identical; the OTA bootstrap costs 0.17 ms (no package) or ~20 ms (verification).

Reconciliation audit (history, ledger, handoff, docs, markers): no missing gameplay; the gaps found
were delivery, documentation and consistency issues, fixed in `1046057` (ledger S-13).

## 5. Food and lunge (the final work before handoff; commit `4aa86a3`)

Owner report: floating food was "always above me". Owner choice: lower hover plus an aimed lunge,
darters included.

- **Hover:** drifters and darters hover **0.3–0.9 m** above the ground (`Food.HOVER_MIN` / `HOVER_MAX`). Burrowers are unchanged.
- **Targeting** (`Game.lunge_target`): when a lunge starts, it picks the nearest catchable food that is:
  - within **3.5 m** along the ground (`LUNGE_AIM_RANGE`);
  - within **65°** of the heading (`LUNGE_AIM_CONE`);
  - at most **1.5 m** above (`LUNGE_AIM_ABOVE`) or 1.5 m below (`LUNGE_AIM_BELOW`).
- **Motion** (`axolotl.gd`): during the lunge Gill turns toward the target and **rises or dips** so
  the mouth meets it. The 1.5 m limit stays below the jump apex (JUMP_V²/2g ≈ 1.85 m), so the lunge
  never out-jumps the jump.
- **Catch zone** (`Game.lunge_contact`): a segment from **chest to mouth** with a **0.95 m** radius (`LUNGE_CATCH_RADIUS`).
- **Wake:** food ignores water pushes while Gill lunges and for **0.7 s** afterwards (`Food._calm_t`),
  so a missed lunge no longer blows food away. Swipes and bursts still push food.
- **Darters:** they keep their escape hop when approached or lunged at. The aim works on them,
  typically during the pause after a hop.
- **Motes:** unchanged. The lunge does not aim at Motes, capture still uses the chest-to-mouth
  segment, and a near miss still pushes a Mote.
- **Regression tests** (in `unit_tests.gd` `_test_food_reach`):
  - `food_hovers_at_head_height`
  - `lunge_reach_stays_below_jump`
  - `lunge_ignores_food_out_of_reach`
  - `lunge_rises_and_turns_to_high_food`: verified to fail when the aim is disabled.
  - `lunge_wake_leaves_food_in_place`
- **Playthrough bot:** unaffected, 12/12 on both seeds.

## 6. Gill

- **Health:** six gill fronds, always present and full size. Active gills glow with colour; lost
  health desaturates a gill and removes its glow (`_update_gills`, `gill.gdshader`). Covered by the
  tests `six_gills_always_full_size` and `gills_glow_when_active_dull_when_lost`.
- **Body:** a snake-like skinned 11-bone spine with a travelling S-wave, and salamander-gait legs
  on bone attachments. It is based on the owner's reference image, which is also the launcher icon.
- **Movement:** jump, burst, lunge and landings as described in §2 and §5.
- **Tail swipe:** a 270° arc (`SWIPE_FRONT_DOT = 0.7071`). Aim assist (`Game.swipe_aim`) turns Gill up
  to 60° so that the nearest parasite falls inside the arc. Parasite wiggle uses a simulated clock,
  so playthroughs are deterministic.
- **Tail whip animation (dev-000024 playtest polish).** The phone playtest found a huge arc over a
  barely moving tail. The whip now runs on its own 0.55 s clock (`AxolotlModel.whip_curve`):
  - a short cock to one side;
  - the strike: the hips twist (about 0.4 of the sweep) and the bend travels down the tail, each
    bone a little behind the one before;
  - an overshoot, a settle, and a recovery to his normal pose.

  The tail tip sweeps about 210° and passes straight behind him on the hit frame.
  - The water arc is drawn over the real hit area: the 270° behind and beside, out to `SWIPE_REACH`
    (1.95 m) from his body centre. It was 1.55 m before. Its bright head rides the tail tip.
  - The gameplay is unchanged:
    - `SWIPE_TIME` 0.3 s;
    - the hit on frame 6 (0.09 s);
    - reach 1.95 m plus the target's body;
    - one stage of damage;
    - cooldown 0.38 s;
    - aim assist 60°/80°.
  - Tests: `_test_tail_whip`.
- **Idles (dev-000024 playtest polish).** Standing still, Gill now and then plays one of four
  (`AxolotlModel.Idle`):
  - he rises onto his back legs, looks one way then the other, and drops back to all fours;
  - a little scoot to one side, one to the other, and back to the same spot;
  - a curious head tilt with a blink;
  - a long stretch with a yawn, then a shake from gills to tail.

  The first comes 4–8 s after he stops, then one every 7–16 s. The choice is random, never the same
  one twice running. Any input, action or other animation ends an idle at once. The controller
  allows idles only when nothing else is going on (`Axolotl.idle_allowed`: no jump, burst, lunge or
  feeding, swipe, hit, landing, fall, current pull, cinematic, vortex, death or respawn). Idles are
  cosmetic only:
  - they move the drawn rig, never the gameplay body, its collision or the camera;
  - choice and timing use the model's own random generator, which also runs blinks now;
  - tests: `_test_gill_idles`.

## 7. World

- **Moss balls:** three, with sphere-centred gravity. Moss Ball #2 has current-swept areas (`current_at`)
  and a mesa reached by sway leaves. Moss Ball #3 has the canopy spiral, and flex leaves cushion
  falls and rebound.
- **Caves and upgrades:** caves with health upgrades raise health to 6.
- **Platforms:** solid from every side (mesh winding fix). Covered by the tests `cushion_faces_outward`,
  `stem_faces_outward` and `cave_dome_faces_correct_side`.
- **Terrain:** smooth cosine rolling hills. `MossBall.add_hill` / `terrain_height` / `altitude`
  displace the surface mesh, and each hill has a collision patch. Covered by six `terrain_*` checks.
- **No mountain-texture upgrade was ever requested or implemented.** Do not invent one.

## 8. SUPERSEDED — DO NOT REINTRODUCE

Old prompts, old tests and old commits are **not** authority over these later owner decisions.

| Superseded | Replaced by |
|---|---|
| Dorsal-frond health, 3 active / 3 dormant (ledger G-13; zig-zag fronds from `8557090`) | Six-gill health (F-05, F-06) |
| ~180° directional tail swipe (G-28) | 270° swipe that turns toward the nearest parasite (F-02) |
| Sunk-sphere "lump" hills | Smooth rolling hills (F-03) |
| App labels "Axolotl" / "Axolotl Dev" | "Mote" / "Mote Dev" (package IDs unchanged) |
| Green-ball `icon.svg` placeholder icon | Owner's artwork for the regular, adaptive and themed icons; `config/icon` points to it |
| Food hover 0.6–1.8 m | 0.3–0.9 m plus the aimed lunge (F-09) |
| Generic secrets `OTA_SIGNING_KEY`, `ANDROID_DEV_KEYSTORE_B64`, and every key made before the Mote key regeneration | `MOTE_*` secrets (§13); the old keys are retired |
| Runtimes r1 and r2 | r3 |
| APKs b17 and earlier | b18. Older APKs reject r3 OTAs, and pre-Mote builds are signed with retired keys. |
| Normal Mote APK offline-only: no OTA client, no INTERNET (ledger G-57; b18 and earlier normal builds) | Offline-capable Mote with the OTA client (R-01), runtime r4, b21 |
| Runtime r3, APK b18, OTAs dev-000010..dev-000012 | r4, b21, dev-000013 onward. r3 and r4 reject each other's OTAs. |
| `ota_dev` export feature; OTA packs exported with the `Android Dev` preset | `ota` feature on both Android presets; packs exported with `Android` |
| Threaded HTTPRequest in the update client | Non-threaded (the threaded one ignores its timeout on a server that never answers) |
| The Mote Dev app (`com.verbal76.axolotl.dev`, preset "Android Dev", artifact `mote-android-dev-*`) | One Mote app and one APK (ledger S-01). The `dev` **channel** is not retired. |
| Runtime r4, APK b21, OTA dev-000013 as current | r5, b22, dev-000014 |
| Plain-colour boot splash; whole world built before the first frame | Mote boot splash; loading screen first; staged build (S-03, S-06) |

## 9. OTA architecture (runtime r5)

| | **Mote** (the one Android app) |
|---|---|
| Package / label | `com.verbal76.axolotl` / Mote |
| Export preset | `Android` (custom feature `ota`, `shader_baker/enabled`) |
| INTERNET permission | yes |
| Bundled game | complete, current at the APK's commit |
| OTA | `dev` channel |
| Signing | the pinned Mote certificate |

iOS has no OTA client (unsigned simulator build). The Mote Dev app is retired.

**Offline first.** `Boot._init` mounts only a package already on the device and verified (or none:
the bundled game). No network call happens before the game is usable. The first game frame is the
Mote loading screen; the world is then built in stages. After the game is ready and healthy (3 s),
`Boot.auto_check()` checks in the background; again on resume (≥ 15 min since the last automatic
attempt) and hourly. A verified update is staged as PENDING and runs on the next start. Every failure
keeps the current game. The HTTP client is non-threaded (Godot 4.7.2's threaded HTTPRequest ignores its
timeout when a server never answers) and never blocks the main loop.

**Fresh APK, current channel.** An OTA built from the same commit as the APK's bundled game is
reported "Up to date" and not downloaded (`OtaUpdater.bundled_source_sha`); newer OTAs download as usual.

**How OTA works** (full detail in `docs/OTA.md`):

- **Mounting:** the `Boot` autoload runs first and, in `_init`, mounts a verified Godot PCK before
  any other script or scene loads.
- **Verification (every boot, no caching):** signed manifest (RSA PKCS#1 v1.5, SHA-256), runtime and
  bootstrap checks, size and SHA-256 of the package. Measured cost ~20 ms desktop.
- **Runtime generations:** an OTA for an older runtime is "incompatible runtime" (a leftover package
  is dropped after an APK upgrade); for a newer one, "native update required".
- **Package state:** transactional (current / previous / pending / ready / bad).
- **Recovery:** boot-health rollback after 2 unhealthy starts, manual rollback, bundled-baseline boot
  and re-enable.
- **Hosting:** GitHub Releases. Each OTA gets an immutable prerelease tag `ota-dev-%06d`. The mutable
  pointer `ota-channel-dev/latest.json` only moves forward.
- **Channels:** `dev`. A later stable channel is a second pointer; native build info may name
  `ota_channel` (default `CHANNEL` in `ota_config.gd`).

**Change rules:**

- **OTA-compatible (game layer):** gameplay/UI GDScript (including new scripts and new `class_name`s),
  scenes, shaders, textures, audio, level data, `GameVersion`, `SaveSchema`.
- **Needs a runtime bump and a new APK (native layer):** the Godot version; `project.godot`
  (autoloads, settings, boot splash, icon); `export_presets.cfg` (permissions, package, icons,
  signing, shader baker); anything under `scripts/boot/`; native libraries or plugins.

`python3 tools/ota_runtime.py --check` compares the guarded files against `ota/runtime_lock.json`,
and the OTA workflow refuses to publish when they differ. To make a native change: `--bump`, commit,
then build and install the new APK. (`--relock` only while the revision was never distributed.)

## 10. Current APK

| | |
|---|---|
| File | **`mote-v0.1.0-b22.apk`** |
| Artifact | **`mote-android-v0.1.0-b22`**: [download](https://github.com/verbal76/Axolotl/actions/runs/36352308882/artifacts/10942084891) (signed in to GitHub; zip with the APK and `build-info.json`) |
| Package / label | `com.verbal76.axolotl` / **Mote** |
| Android build / versionCode | 22 (versionName 0.1.0) |
| Build source = bundled baseline | `104605727ab2bc48f6b0b6e2d56a0fd44127c5be` |
| Runtime | `android-godot-4.7.2-r5` |
| Permissions | INTERNET, VIBRATE |
| Game version / save schema | 0.1.0 / 1 |
| APK SHA-256 | `7305593ef86355c00340cf3389b9b71d34ff7a6bf9ae4925ddc1f8fbb0aa6924` |
| Signing certificate SHA-256 | `A8:4F:BA:D5:61:B9:F5:E2:4E:BB:45:E2:95:17:94:F6:17:28:19:56:CF:DB:CA:FF:3A:CF:DB:9E:63:E2:C2:E3` (pin enforced) |
| OTA public key (DER SHA-256) | `a003a45ce422325ef1de52958bd9d4d2a06b912ae119c6c7a7f9e40ff2720cf2` (pin enforced) |
| Baked shaders | 38 caches inside the APK (6 scene/material, the rest engine core) |
| Built by | Build & Verify #22, [run 36352308882](https://github.com/verbal76/Axolotl/actions/runs/36352308882) |

CI verified all of the above from the APK itself, including running the APK's own bundled game
(`--print-identity`): source `1046057`, build 22, flavour normal, OTA on dev, runtime r5, save schema 1.

**Installing:** a fresh install (the owner is uninstalling the old apps first). Later Mote APKs signed
with the same key install **over** b22 and keep its saves. Play Protect's "unknown developer" prompt
is expected; tap **Install anyway**.

## 11. Current OTA

**Latest: `dev-000024`** (OTA publish #24, run 36465899336): source `6e6f71e368d92379a331c827eb772155ab470224`,
runtime r5, PCK `6816257c11b12560e66f18e6fc4dd33925cff89734ee658aa6dee37d1ed2e7fa` (9,214,288 bytes, baked),
save schema 1. **Expansion 6** (ledger E6): leaves grown from their stems with matching collision; Gill's soft
freckled skin; continuous parasite bodies and a limp death; creatures remodelled from the owner's references;
aquarium lighting that clears as the tank heals; vortices as a revolving spiral of water jets over tidal pools;
healed balls sprouting like the owner's moss ball; variegated leaves; parasite combat (per size, retreat, pack
alerts, spitters, attack budget, sight); 100% by play proven on both seeds; selective shadows. Verified from the
public URLs; a b22 client downloads and stages it; Build & Verify #32 green, no APK.

`dev-000023` (OTA publish #23, run 36411346325): source `9d4fd24e6418066abce32d95bb3cccba4f0c1543`,
runtime r5, PCK `c0a4037aea1b4b8aef450a95fa788726cc33417b50cea3295f0cbee62de6f226` (9,026,936 bytes, baked),
save schema 1. **Expansion 5** (ledger E5, `docs/ECOSYSTEM.md`, catalog v3 in `docs/COMPLETION.md`): reed stalkers,
crab guardians, cave eels, pufferfish; shrimp shoals, canopy snails, leaf hoppers, cave glow-worms; 172 completion
ids (Wildlife category). Verified from the public URLs; a b22 client downloads and stages it; Build & Verify #31
green, no APK.

`dev-000022` (OTA publish #22, run 36385605395): source `fe3e0fdaba68fe275f4ed7b19e63cac5a5b76362`,
runtime r5, PCK `485972412e36b10aa8b03381affc8b74246423999db7b162fa0b882b6c1e5894` (8,883,196 bytes, baked),
save schema 1. The same game as dev-000021 plus test fixes (`_test_upgrades` covers pearls; the unit runner
fails a test that stops without reporting). Verified from the public URLs; a b22 client downloads and stages
it; Build & Verify #30 green, no APK.

`dev-000021` (OTA publish #21, run 36383509240): source `9ed29db8209882d09133cba4c9b2dc27fee1ba1d`, runtime r5,
PCK `7415e9072a455aa6ae95e0790cb53d76504072c536019d079ece03bd86162274` (8,882,636 bytes, baked), save schema 1.
**Expansion 4** (ledger E4, `docs/WORLD.md`, catalog v2 in `docs/COMPLETION.md`): four new moss balls
(Terrace Steps, Reed Canyon, Canopy Spire, Hollow Grotto) branching off the chain; ridges, terraces, an arch,
a natural bridge, shelves, canopy spirals; four pearl caves; 157 completion ids; finishing needs all seven
balls. Owner phone report: every Giant Stems jungle stem is a plain-jump ladder; every climb on all seven
balls audited and climbed in tests. Verified from the public URLs; a b22 client downloads and stages it. No APK.

Before it: `dev-000020` (OTA publish #20, run 36374340406): source `2206aea80b5da086ef44f54970e62603c4d56876`,
runtime r5, PCK `c0c6a7365c3d040339764c5d78d06db81de2a35cafb655f3e0570567d226374b` (8,832,576 bytes, baked),
save schema 1. **Expansion 3** (ledger E3, `docs/VEGETATION.md`): reactive vegetation. The wake of the
axolotl's body, tail and trail and of parasites bends plants, which recover behind him. Short, medium and
tall families; ball 1 meadow, corridor and tall reed bed; balls 2 and 3 grass in stands. Verified from
the public URLs; a b22 client downloads and stages it. No APK.

Before it: `dev-000019` (OTA publish #19, run 36371883104): source `4461b844c8b2cd285976bdeb4954c4735f0f24b6`,
runtime r5, PCK `e0c2b637adea45d6d9b85ad59e8a67fff2c02f3ebd56d622510ae410cceef249` (8,796,124 bytes, baked),
save schema 1. **Expansion 2** (ledger E2, `docs/TERRAIN.md`): moss-over-stone terrain material, natural
arched caves (phone defect: square doorway), a head guard (phone defect: head through cave walls),
organic mounds sweeping into the ground (owner: "walls too straight"). Verified from the public URLs; a
b22 client downloads and stages it. No APK.

Before it: `dev-000018` (OTA publish #18, run 36367445453): source `27d6d44eadbaa99fd730666c37b9bc58f60c33b8`,
runtime r5, PCK `2d980e7e68b8c503fae6554cebb3dd5940b9f6ae26591e29a5f7789e0920e66a` (8,773,516 bytes, shaders
baked), save schema 1. **Expansion 1** (ledger E1, `docs/COMPLETION.md`): run save with Continue / New Run,
run timer, completion catalog and %, pause-menu run panel, optional HUD timer, finish time under ALL CLEAR,
Diagnostics section. Also the music: clear title, lighter muffling (M-03). Verified from the public URLs
(signature with the pinned key, hash, size, runtime, baked shaders, inspector); a b22 client downloads and
stages it; the relaunch test passes run from the published pack. No APK (Build & Verify #26: Android job
skipped).

Before it: `dev-000017` (OTA publish #17, run 36364819542): source `618dcf32195fd192c2fc5a711e2fc111aaebc692`,
runtime r5, PCK `3ffcb6b1a3647ee331a549e0f3356fce3e8034f809a9de510b6f8045d9a9fcc8` (8,736,680 bytes, shaders
baked). The owner's songs *Aquarium Whimsy* and *Bubbly Underworld* replace the generated music (ledger M).
Verified from the public URLs; a b22 client downloads it. No APK (Build & Verify #25).

Before it: `dev-000016` (OTA publish #16, run 36363153615): source `346a0bc2d63a6d0dd99de9fb5af3daa7df092af2`,
runtime r5, PCK `4ac0e08572d520623b160b929c3d0494116e5147f33d542f433d2f5eef2a4681` (4,861,880 bytes, shaders
baked). Moss Ball 3 canopy (ledger P-06): 16 spiral leaves, first 0.89 m off the ground, 1.0 m steps, every
step a plain jump. Verified from the public URLs; a b22 client downloads it. No APK (Build & Verify #24).

Before it: `dev-000015` (OTA publish #15, run 36361312212): source `637014dcd639bbd071d0b9be16efc2654eb794e2`,
runtime r5, PCK `4fc048be6af27eb9934f07dee57141a54a8c46bdebcdfc01e6b5dea13bc5bdfe` (4,859,880 bytes, shaders
baked). Game-layer fixes from the phone playtest (ledger P): brittle-moss bridge caps grounded on stalks,
cave-dome skirt, articulated parasite locomotion. Verified from the public URLs; a b22 client downloads it.
No APK was built (Build & Verify #23 skipped the Android job: native layer unchanged).

The table below describes dev-000014, the OTA of b22's own game.

| | |
|---|---|
| OTA id / channel | **`dev-000014`** / `dev` |
| Source | `104605727ab2bc48f6b0b6e2d56a0fd44127c5be` (the same commit b22 bundles) |
| Runtime / bootstrap | `android-godot-4.7.2-r5` / 1 |
| Game version / save schema | 0.1.0 / 1 (min 1) |
| Payload | `axolotl-dev-000014.pck`, 4,852,728 bytes (38 baked shader caches) |
| Payload SHA-256 | `223ae3de4016cc28e80e352a51bfe6d9c54a704dce3c3b0df97ab8ea52dc6531` |
| Pointer | `https://github.com/verbal76/Axolotl/releases/download/ota-channel-dev/latest.json` → `dev-000014` |
| Published by | OTA publish #14, [run 36352306690](https://github.com/verbal76/Axolotl/actions/runs/36352306690) |

Independently verified from the public URLs: signature against the pinned key, hash, size, baked
shaders (`tools/pck_files.py --require-baked`), inspector (INSPECT OK). Live check with the real update
client: a b22 install (bundled `1046057`) reports "up to date (latest dev-000014 is the game bundled in
this app)"; any other bundle is offered dev-000014.

Older OTAs stay published as evidence: dev-000010..dev-000012 (r3), dev-000013 (r4). An r5 app
rejects them ("incompatible runtime"); an r3/r4 app rejects dev-000014 ("native update required").

## 12. CI architecture

| Workflow | File | Triggers | Does |
|---|---|---|---|
| Build & Verify | `.github/workflows/build.yml` | `pull_request`, push to `main`, manual | Script check, unit suite, playthrough bot, version drift, runtime gate; the one Mote APK exported with shaders baked (software Vulkan under xvfb), then verified from the APK itself: package/label/versionCode, INTERNET, certificate pin, OTA-key pin, baked caches, splash, and the bundled game's own identity (`--print-identity`); unsigned iOS simulator build |
| OTA publish (dev channel) | `.github/workflows/ota-publish.yml` | push to `claude/axolotl-aquarium-platformer-3y0qyy`, manual | Runtime gate, tests, PCK export (`Android` preset, shaders baked; fails without them), manifest, signing, inspection, immutable release, re-download and verify, pointer move, receipt artifact `ota-receipt-*` |

Every push to the branch runs both workflows (the second through the PR). A commit message
containing `[skip ci]` skips both.

**Defensive fixes.** Each one exists because a real CI run failed. Do not remove any of them as
"unnecessary complexity" without proving it is obsolete.

- **`683b273`, aapt2 permission inspection.** `aapt dump badging` did not list the permissions. CI
  now reads them from the manifest xmltree (and asserts the Mote APK has INTERNET).
- **`18c64df`, aapt exit-status tolerance.** `B=$(aapt …)` aborted the step under `bash -e`, so it
  now ends in `|| true`. The label and package are still asserted afterwards.
- **`1ae4e69`, OTA PEM normalization.** Pasted keys arrive with spaces, CRLF or re-wrapped lines.
  The workflow rebuilds a canonical PEM.
- **`d235cb2`, body-only key reconstruction.** The stored `MOTE_OTA_SIGNING_KEY` holds only the
  base64 body, without BEGIN/END lines. The workflow restores the markers (PKCS#8 unless the paste
  says RSA). It then requires the derived public key to equal both the key embedded in the APK and
  the pin. Only structural facts are logged, never key material.
- **`a72ae3b`, identity.json outside the project.** CI wrote `identity.json` into the project root,
  so it was packed into APKs and PCKs (found in dev-000012). It is now written to `$RUNNER_TEMP`.
- **`e60b075`, shader baking only under the target renderer.** A headless export bakes nothing, so
  CI exports on software Vulkan (lavapipe) under xvfb and fails if the log shows no baking.
- **`1046057`, the release APK verifies itself.** CI unzips the APK's assets and runs them
  (`--print-identity`), so the bundled baseline is proven from the artifact, not from the source tree.
- **`637014d`, APK only on native change.** Build & Verify's Android job runs only when the pushed
  commits touch `project.godot`, `export_presets.cfg`, `scripts/boot/` or `ota/runtime_lock.json`
  (or on a manual run). Game-layer changes ship by OTA without a new APK.
- **`31ae69d`, real branch SHA.** `pull_request` runs check out GitHub's synthetic merge commit. The
  workflow now checks out and records `SOURCE_SHA` = the PR head commit, and asserts it before export.

Workflow-level pins (public values, not secrets): `MOTE_DEV_CERT_SHA256` and `MOTE_OTA_PUBKEY_DER_SHA256`.

## 13. GitHub secrets (names only)

| Secret | Purpose |
|---|---|
| `MOTE_OTA_SIGNING_KEY` | Private RSA key that signs OTA manifests. It must match the public key in `scripts/boot/ota_config.gd`. |
| `MOTE_ANDROID_DEV_KEYSTORE_B64` | Base64 PKCS12 keystore that signs the Mote APK, so later APKs install over it. (The `DEV` in these names predates the retirement of the Mote Dev app; renaming would mean re-entering secrets.) |
| `MOTE_ANDROID_DEV_KEYSTORE_PASSWORD` | Keystore password |
| `MOTE_ANDROID_DEV_KEY_ALIAS` | Key alias inside the keystore |
| `MOTE_ANDROID_DEV_KEY_PASSWORD` | Key password. It must equal the keystore password (PKCS12), and CI checks this. |

- **Values** are never recorded anywhere in the repository, logs or artifacts. CI reports only presence.
- **Private material:** keys and keystores must never be committed; `.gitignore` guards against it.
- **Missing keystore:** the APK build falls back to a throwaway key with a warning, and the
  certificate pin is then not enforced.
- **Missing OTA key:** the OTA workflow stays green but writes `"published": false`.

## 14. Requirement status

`docs/REQUIREMENTS_LEDGER.md` is the detailed authority: 158 rows (G, F, O, V, N, C, A, R, S).
The reconciliation audit (ledger S-13) classified every recorded requirement plus items found only in
commits/docs:

- **IMPLEMENTED + VERIFIED:** the large majority (all mechanics, OTA, versioning, naming, credentials,
  CI/APK, startup and consolidation rows).
- **IMPLEMENTED + NEEDS PHONE VERIFICATION:** camera swipe feel (G-12), water/vegetation look (G-23),
  telegraphs (G-26), landing variants (G-31), music/bedroom audio (G-41), haptics felt (G-54),
  thermal (G-55), safe areas on a notch (G-56), launcher icon (F-07), lunge feel (F-09), recovery
  gesture and Diagnostics buttons (O-13, O-17, R-06), real OTA end-to-end (O-19, R-01, R-14, R-19,
  S-14), splash/loading appearance and startup time (S-03, S-06).
- **INTENTIONALLY SUPERSEDED:** G-13, G-28, G-57, R-11, R-16, R-17.
- **OPEN:** only S-15, the iOS team ID (owner input; iOS is a simulator build and not a target now).
- **CONTRADICTORY:** none.

## 15. Automated verification gaps

These are implemented but lack automated evidence. They are **not** unimplemented.

- **G-12:** manual camera swipe (no drag test)
- **G-23:** water and vegetation response (no assertion)
- **G-26:** parasite attack telegraphs (not asserted)
- **G-31:** four landing variants (no per-variant test)
- **G-41:** adaptive music and receding bedroom sounds (not asserted or listened to)
- **G-55:** thermal scaling on real hardware (desktop timing only)
- **G-56:** safe areas (no notched device or test)
- **O-17 / R-06:** Diagnostics touch buttons (text and actions are tested; the buttons are not)

## 16. Physical-device acceptance (owner; nothing verified yet on b22)

1. Uninstall every old Axolotl / Mote / Mote Dev app. Install `mote-v0.1.0-b22.apk` (Play Protect: **Install anyway**). The launcher shows the axolotl artwork labelled **Mote**.
2. **Cold launch, airplane mode ON:** the Mote splash (artwork) appears almost at once, then the loading screen (MOTE, artwork, stage names), then the title. It never shows a long featureless black screen.
3. **Pause → About / Diagnostics** (offline):
   - Native: Android Build 22, Flavor normal, Runtime `android-godot-4.7.2-r5`, bundled baseline `104605727ab2…`.
   - OTA: Enabled yes, Channel dev, Active bundled baseline, Status "Offline: update channel not reachable; playing the current game" (or "Not checked yet" in the first seconds).
   - Startup section lists the launch milestones; the pause menu shows "Last launch: Mote on screen after X s, ready after Y s". Please report both numbers (first launch and a second launch).
   - Save Schema 1.
4. Play a little (food/lunge, swipe, gills), then close and reopen: progress/settings kept.
5. **Airplane mode OFF**, restart: Status **Up to date**, Latest on channel **dev-000014**, Runtime compatibility "latest OTA compatible", Last check "up to date (latest dev-000014 is the game bundled in this app, 104605727ab2)". Nothing is downloaded.
6. **OTA download/activate/rollback on the phone:** dev-000015 is newer than b22's own game. Online, restart: it downloads by itself ("ready: restart to run it"), restart → Active dev-0000NN, **Roll back** → restart → bundled baseline, **Boot bundled baseline** / **Re-enable OTA** behave as labelled, saves kept throughout.

7. **After dev-000015 is active:** Moss Ball 1, east tower (the view of the playtest screenshot): the two brittle bridge caps stand on moss stalks down to the ground; Gill cannot walk under them; stepping on a cap makes the whole cap-and-stalk crumble, Gill drops to the ground, and it regrows once Gill moves away. Same on Moss Ball 2's south tower. Watch several parasites crawl, turn and stop: a wave should roll from head to tail, turns should curve the body, no stiff-stick sliding or twitching.

8. **After dev-000016 is active:** Moss Ball 3, the giant stem's canopy: the first spiral leaf is about knee-to-hip height for Gill and reachable with one normal jump from the ground; each next leaf is one normal jump up (no burst needed), all the way to the top leaves next to the canopy.

9. **After dev-000017 is active:** the title plays *Aquarium Whimsy*; when it ends *Bubbly Underworld* starts, then back again. Travelling between moss balls does not restart the song. On a murky ball the music sounds muffled and clears as the ball heals. The pause menu's Music slider controls it.

10. **After dev-000018 is active (Expansion 1):**
    - The title says **Play** the first time. Play a few minutes (clear a parasite, catch a mote, touch a bloom), then fully close Mote (swipe it away) and reopen it: the title now says **Continue** with "Run time … · N% complete". Continue: you're back at the last bloom with the moss you restored still green.
    - Pause: run time, completion by category (moss restored, hidden caves, blooms, milestones), "Game finished: not yet". Leave the pause menu open for a minute: the time does not move. Home button for a minute, come back: the time did not move.
    - Pause → **Show run timer**: a small faint timer top left; turn it off again.
    - Finishing (all three balls restored): "Finished in …" under ALL CLEAR; in Pause, "Game finished: yes" and that time stays fixed while you keep playing. A second run's faster finish becomes "Best finish".
    - New Run (title or pause) asks first; after it the run is fresh and "Best finish" is still shown.
    - Diagnostics (Pause → About / Diagnostics): the "Run timer & completion" section. On first launch of dev-000018 its run save says it is new because earlier versions saved no progress (so earlier finished games are not carried over).
    - The music on the title is clear; on a murky ball it is softer but recognisable.

11. **After dev-000019 is active (Expansion 2):**
    - Each cave's entrance is a rounded, irregular arch in a lumpy mound (no square doorway); walk in and out easily.
    - Inside, walk nose-first into walls and jump under the roof: his head stops at the rock instead of going through.
    - Platforms and ledges are mounds whose sides lean out and sweep into the moss (no 90-degree walls); tops and jumps as before (M1 still a jump, M2 still jump + burst).
    - Steep faces show earth and stone under the moss; flat ground stays moss; restored moss still turns green.

12. **After dev-000020 is active (Expansion 3):**
    - Ball 1: walk through the short grass (a small stir); the medium meadow north-east of the start (it parts round him and closes behind); the tall reed bed in the southern hills (he mostly disappears; follow the moving reeds). Whip the tail in the reeds (a wide sideways sweep); stop (the reeds settle); move again (the disturbance resumes). Watch the large parasite move through the reeds.
    - Grass sways gently on its own, not in unison. Balls 2 and 3's long grass is in stands with clearings.

13. **After dev-000021 is active (Expansion 4):**
    - Four new moss balls: from Mossy Meadow a new vortex leads to Terrace Steps (and from there to Hollow Grotto); from Current Hollows to Reed Canyon; from Giant Stems to Canopy Spire. Each opens when the ball it leaves is 70% restored, like the originals.
    - Giant Stems (your screenshot): every jungle stem now has a small leaf about knee height to start and leaves spiralling up, each one plain jump, all the way to its big leaves. Try two or three stems to the top.
    - Terrace Steps: climb the three terraces to the crown; walk up the arch; walk the ridge. Reed Canyon: tall reeds on the canyon floor; climb the north crest and cross the natural bridge. Canopy Spire: the spiral to the crown, and the stacked shelves. Hollow Grotto: along the low ridge to the high shelf; two grottoes.
    - The new caves hold pearls (they refill health). Ball 2's thin kelp stalks now have drooping leaves (decoration).
    - Finishing now needs all seven balls; the pause menu's completion shows the larger catalog (a finished run's time is kept).

14. **After the Expansion 5 OTA is active (ecosystem):**
    - Mossy Meadow's tall reed bed (south hills), Reed Canyon's floor and Giant Stems' far jungle: watch for reeds moving on their own. A reed stalker is in there. When it rears and hisses (the reeds thrash), step sideways; hit it while it lies low.
    - Grotto mouths on Terrace Steps, Reed Canyon and Hollow Grotto: a crab raises its claws and clacks when you come close. Back off, or stay and fight it (three swipes; sidestep its charge).
    - Inside the grottoes (and Current Hollows' cave): glow-worms dim as you pass. In the walls, eyes brighten and bubbles rise before an eel strikes: step back out of reach, or swipe it while it is out.
    - Pufferfish drift at jump height (Current Hollows, Terrace Steps, Reed Canyon, Hollow Grotto): they puff up when you come close. Go round them.
    - Shrimp shoals scatter when you run at them; snails tuck in on the leaves; leaf hoppers spring up the climbs ahead of you.
    - Each new species shows "New species: …" once; the pause menu's completion has a Wildlife line.

15. **After the Expansion 6 OTA is active (final integration pass):**
    - **Leaves:** Giant Stems' canopy spiral and the Canopy Spire. Each leaf grows out of the stem on a curved stalk and is broad enough to land on, turn round on and aim from. Where you see leaf is where you can stand, and there are no invisible edges. The leaves go round a quarter turn each, so none hides the next. Climb a jungle ladder or two, and climb down again.
    - **Gill:** soft pink skin with freckles, a paler belly, feathery gills. Moist, not shiny plastic.
    - **Parasites:** one smooth bending body, not beads. Defeated, one twitches, then drifts down limp.
    - **Creatures:** the crab has a speckled shell with a red rim, legs and claws. The pufferfish is a calm spotted fish that puffs into a spiny ball. The eels are morays in the grotto walls. The burrowers are garden eels rising from sand mounds. The motes have trailing tentacles. The rosette plants and ferns are smooth and sway.
    - **Light:** at the start the tank is murky and dull (on purpose). As balls heal, the water clears toward aqua, the ceiling light warms, light shafts and moving caustics appear, and the corals take their colour. At ALL CLEAR the tank should look bright and alive. Caves stay dark with glow-worms.
    - **Vortex:** a spiral of water jets revolving over a swirling pool on the moss (no tube, no cone). Sand and bubbles spiral up from the pool. Ride it: Gill corkscrews round inside the spinning jets. The far end is another pool.
    - **Healed balls:** as a ball heals, red-tipped stem plants and ferns sprout over its top like a crown, and roots trail beneath it. Neglected balls have none.
    - **Parasites:** small ones dart in and latch; medium ones circle before they strike; a large one coils (rumbling, scraping) and charges. Sidestep it, then hit it while it rests, head low. Hurt ones may flee and come back healed if left alone. One that spots you alerts its neighbours, and they spread round you. In the far zones of Current Hollows, Giant Stems, Terrace Steps and Reed Canyon, spitters keep their distance and lob glowing globs: dodge them, or swipe one back at its spitter.
    - **Leaves:** healed rosettes and ferns are variegated: pink margins and cream stripes like an earth star, or white-centred like a fire-and-ice hosta.
    - **Frame rate:** watch for stutter in the restored tank, especially with light shafts in view.
    - **100%:** after finishing, the pause menu's completion keeps counting. Everything (blooms, caves, crabs, eels, species) can be earned, and the finish time never changes.

Record results in the ledger (O-19, A-05, R-01, R-14, R-19, S-03, S-06, S-14, F-07, F-09, P-01, P-03, P-06, M-01, M-03, E1-01, E1-07, E1-09, E2-01, E2-02, E2-04, E2-05, E3-01, E3-02, E3-04, E4-01..E4-05, E5-02..E5-06, E6) only with the owner's evidence.

## 17. Repository isolation

**MOTE AUTHORIZED REPOSITORY: `verbal76/Axolotl`.** The new session must be connected only to this
repository. Do not name, open or use any other game repository in Mote development.

## 18. Current stopping point

- **Released:** one Mote APK (b22, r5) with everything approved bundled, OTA on `dev`, channel pointer
  reconciled to dev-000014 (the APK's own game). CI green on `1046057`.
- **Delivered after b22:** dev-000015 (phone-playtest fixes, ledger P) and dev-000016 (ball 3 canopy climb, P-06) and dev-000017 (owner's music, M) and dev-000018 (Expansion 1: timer + completion foundation, E1; music finish, M-03) and dev-000019 (Expansion 2: living terrain + cave repair, E2) and dev-000020 (Expansion 3: reactive vegetation, E3) and dev-000021/22 (Expansion 4: world expansion, E4) and dev-000023 (Expansion 5: ecosystem, E5) and dev-000024 (Expansion 6: final integration pass, E6), by OTA only.
- **MOTE OPEN ITEMS EXPANSION LIST** (also in the ledger; each item is one dev OTA, authorised separately):

  [x] 1. Timer + completion foundation (dev-000018)
  [x] 2. Living terrain / texture and material upgrade (dev-000019)
  [x] 3. Dense reactive vegetation / cornfield movement (dev-000020)
  [x] 4. Additional moss balls + expanded terrain set (dev-000021; dev-000022 test fixes)
  [x] 5. Additional enemies + ecosystem expansion (dev-000023)
  [x] 6. Full expansion integration + progression/balance/100%/speedrun reconciliation (dev-000024)

  New completion-bearing content must extend the catalog as `docs/COMPLETION.md` describes.
- **Expansion list:** all six items are done (dev-000018, dev-000019, dev-000020, dev-000021/22, dev-000023, dev-000024). Do not begin Expansion 7 unless the owner asks for it.
- **Next task:** the owner's phone checks (§16), including the Expansion 6 items (15) and the frame rate.
- **After that:** continue from the owner's feedback. Game-layer changes reach b22 by OTA on push
  (that push is also the first OTA a b22 phone downloads). Native changes need `--bump` and a new APK.

---

## NEW SESSION — READ THIS FIRST

You are continuing an existing game called **Mote** (protagonist **Gill**).

- **Do not** restart it.
- **Do not** recreate completed systems.
- **Do not** reinterpret superseded requirements (§8).
- Work **only** in **`verbal76/Axolotl`**.

**Before editing:**

1. Verify the repository (`verbal76/Axolotl`), the remote, the branch (`claude/axolotl-aquarium-platformer-3y0qyy`) and HEAD.
2. Read this file (`MOTE_HANDOFF.md`) completely.
3. Read `docs/REQUIREMENTS_LEDGER.md`.
4. Inspect the current source.
5. Compare HEAD against the represented source:
   - release commit `1046057` (APK b22 and OTA dev-000014, runtime r5);
   - the handoff commit is documentation only.
6. Report any drift.
7. Report the current APK (Mote b22; the Mote Dev app is retired).
8. Report the current OTA (`dev-000014`, or newer if the channel pointer has moved).
9. Report the physical-device verification state (none unless the owner has supplied evidence).
10. Continue from the documented stopping point (§18).

**Preserve:**

- offline-first play: nothing may wait for, or require, the network;
- the OTA client in the one Mote app, and the startup work (splash, loading screen first, staged build, baked shaders);
- version authority (`GAME_VERSION`);
- the signing architecture and OTA signing;
- runtime compatibility;
- CI, including every defensive fix in §12;
- the owner decisions (§2, §5–§7) and the superseded list (§8);
- the requirement ledger.

**Never:**

- expose GitHub secret values or private key material;
- claim physical-device verification without the owner's evidence.

**Remember:** a push without `[skip ci]` publishes a dev OTA.

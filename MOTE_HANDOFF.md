# Mote — development handoff

This is the authoritative handoff for continuing **Mote** in a new coding session. It records the
state after the **OTA delivery rectification** (runtime r4), cross-checked against the repository,
CI and the published OTA. The earlier b18 / r3 / dev-000012 state is kept below as history.

> **MOTE AUTHORIZED REPOSITORY: `verbal76/Axolotl`**
> Work only in this repository. The previous coding environment also exposed an unrelated
> repository. An isolation audit found it clean and untouched. Do not open, search, or change any
> other repository in Mote work.

## 0. Identities at handoff (do not confuse these)

| Identity | Value |
|---|---|
| Repository / branch | `verbal76/Axolotl`, `claude/axolotl-aquarium-platformer-3y0qyy` (draft PR #1 into `main`) |
| **Handoff document commit** | The commit that updates this file (`[skip ci]`, documentation only). It is newer than every commit below. |
| **Native + OTA source** | `a72ae3b0514ac8bff14a8cc2e507bd3af23831dd` (`a72ae3b`): OTA rectification, runtime r4 |
| **Last gameplay source** | `227d0abab6cadd8cd90536f92fc8dbddf4b29fc3` (`227d0ab`). The game layer at `a72ae3b` is identical to it. |
| **Native APK baseline** | **Mote b21** (`mote-v0.1.0-b21.apk`, `com.verbal76.axolotl`), built from `a72ae3b`; Mote Dev b21 companion |
| **Current OTA** | **`dev-000013`**, built from `a72ae3b`, runtime r4 |
| Runtime | `android-godot-4.7.2-r4` |
| Game version / save schema | `0.1.0` / `1` |
| Requirement authority | `docs/REQUIREMENTS_LEDGER.md` (sections G, F, O, V, N, C, A, **R**) |
| History | b18 (`854ea84`, r3), dev-000010..dev-000012 (r3). Superseded (§8), releases kept as evidence. |

> **PHYSICAL PHONE VERIFICATION OF b21 + dev-000013: NOT YET DONE.**
> Nothing has been verified on a physical device. Do not treat CI results as device results.
> The owner's phone currently runs the **normal b18** app (`Flavor: normal`, `OTA Enabled: no`,
> source `854ea84`), reported by the owner. That is why it never received dev-000011/12.

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
| Android build | versionCode = the Build & Verify workflow's `run_number` (baseline: **21**) |
| Save schema | `SAVE_SCHEMA = 1`, `MIN_SAVE_SCHEMA = 1` in `scripts/core/save_schema.gd` |
| Normal package | `com.verbal76.axolotl`, label **Mote**: the app the owner plays; OTA-capable since r4 |
| Dev package | `com.verbal76.axolotl.dev`, label **Mote Dev**: optional side-by-side test install, same channel |

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
  restoration (water, gravel, ooze, algae, bedroom visibility) follows it. Music heals and bedroom
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
- **Builds (owner ruling, supersedes the offline-only normal build):** Mote is **offline-capable, not
  offline-only**. The installed Mote app bundles the complete game, needs no connection to launch,
  play, save or finish, and checks for signed, compatible OTAs whenever a connection happens to be
  available, never waiting for one. A Mote Dev package remains as an optional test install.

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
| Audio | `scripts/core/audio_director.gd`, `scripts/core/sfx.gd`, `assets/audio/` (from `tools/gen_audio.py`) |
| Performance scaling | `scripts/core/quality_scaler.gd` |
| Version and save schema | `scripts/core/game_version.gd`, `scripts/core/save_schema.gd` |
| **Native OTA bootstrap** (ships in the APK) | `scripts/boot/boot.gd` (first autoload), `ota_core.gd`, `ota_updater.gd`, `ota_config.gd` (public key, channel, runtime revision), `diagnostics_overlay.gd` |
| Tests | `scripts/tests/test_runner.gd`, `unit_tests.gd`, `ota_tests.gd`, `ota_http_stub.gd` (local HTTP server for the update client), `playthrough_bot.gd`, `shots.gd`, `model_preview.gd`, `perf.gd` |
| Tools | `tools/ota_runtime.py`, `ota_make_manifest.gd`, `ota_inspect_pack.gd`, `ota_e2e_local.sh`, `version_drift_check.sh`, `print_identity.gd`, `write_native_build_info.py`, `make_icons.gd`, `check_scripts.gd`, `gen_textures.py`, `gen_audio.py` |
| Icons | `assets/icon/`, generated by `tools/make_icons.gd` from `icon_source.png` |
| Docs | `docs/REQUIREMENTS_LEDGER.md`, `docs/OTA.md`, `docs/VERSIONING.md`, `README.md`, `docs/screenshots/` |

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

Evidence on `a72ae3b` (native + OTA source; game layer = `227d0ab`):

| Check | Result |
|---|---|
| Unit suite (mechanics, OTA client/server, version, naming, packaging, gill, terrain, food) | **160 passed, 0 failed** (local and CI) |
| Playthrough bot, seeds 4242 and 7 | **12/12** each |
| Version drift check | passed |
| OTA local end-to-end (`tools/ota_e2e_local.sh`) | ALL PASSED (31 checks, incl. hanging channel and a full offline playthrough by the exported game) |
| Runtime gate | `r4 unchanged (godot 4.7.2): OTA-compatible` |
| Build & Verify #21, [run 36341864999](https://github.com/verbal76/Axolotl/actions/runs/36341864999) | success: tests and playthrough, Android APKs b21, iOS simulator build |
| OTA publish #13, [run 36341861522](https://github.com/verbal76/Axolotl/actions/runs/36341861522) | success: `dev-000013`, pointer moved |

Pre-rectification audit (ledger R-02): dev-000012 was proved to contain all work after b18. Every
compiled script in the published pack is byte-identical to a local export of `227d0ab`, and the
food/lunge tests pass when run from the published pack itself. Nothing was missing.

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

## 9. OTA architecture (runtime r4)

| | **Mote** | **Mote Dev** |
|---|---|---|
| Package | `com.verbal76.axolotl` | `com.verbal76.axolotl.dev` |
| Export preset | `Android` (custom feature `ota`) | `Android Dev` (custom feature `ota`) |
| INTERNET permission | yes | yes |
| Bundled game | complete (current gameplay) | complete (current gameplay) |
| OTA | `dev` channel | `dev` channel |
| Signing | the Mote certificate (pinned) | the same certificate |

The two apps install side by side. iOS has no OTA client (unsigned simulator build).

**Offline first.** `Boot._init` mounts only a package already on the device and verified (or none:
the bundled game). No network call happens before the game starts. After the game reports ready and
runs for 3 s (boot health), `Boot.auto_check()` starts a background check. It checks again on
resume if ≥ 15 minutes have passed since the last automatic attempt, and every 60 minutes while
running (`auto_check_due()`). A verified update is downloaded, staged as PENDING and runs on the
next start. Every failure (no network, DNS, GitHub down, timeout, bad pointer/manifest/signature/
runtime/hash, interrupted download) keeps the current game. The HTTP client is polled from the
main loop and never blocks it. It is not threaded, because Godot 4.7.2's threaded HTTPRequest
ignores its timeout when a server accepts a connection but never answers.

**How OTA works** (full detail in `docs/OTA.md`):

- **Mounting:** the `Boot` autoload runs first and, in `_init`, mounts a verified Godot PCK before
  any other script or scene loads.
- **Verification:** each PCK must pass a signed manifest (RSA PKCS#1 v1.5, SHA-256), the runtime and
  bootstrap checks, and the size and SHA-256 checks.
- **Runtime generations:** an OTA for an older runtime is "incompatible runtime" (a leftover package
  is dropped after an APK upgrade); for a newer one, "native update required".
- **Package state:** transactional (current / previous / pending / ready / bad).
- **Recovery:** a boot-health check with rollback after 2 unhealthy starts, plus manual rollback,
  bundled-baseline boot and re-enable.
- **Hosting:** GitHub Releases. Each OTA gets an immutable prerelease tag `ota-dev-%06d`. The mutable
  pointer `ota-channel-dev/latest.json` only moves forward.
- **Channels:** both packages follow `dev`. A later stable channel is a second pointer. The native
  build info may name `ota_channel`, and the default is `CHANNEL` in `ota_config.gd`.

**Change rules:**

- **OTA-compatible (game layer):** gameplay/UI GDScript (including new scripts and new `class_name`s),
  scenes, shaders, textures, audio, level data, `GameVersion`, `SaveSchema`.
- **Needs a runtime bump and a new APK (native layer):**
  - the Godot version;
  - `project.godot` (autoloads, settings, icon);
  - `export_presets.cfg` (permissions, package, icons, signing);
  - anything under `scripts/boot/` (bootstrap, verifier, channel, public key);
  - native libraries or plugins.

`python3 tools/ota_runtime.py --check` compares the guarded files against `ota/runtime_lock.json`,
and the OTA workflow refuses to publish when they differ. To make a native change: bump with
`--bump`, commit, then build and install the new APK.

## 10. Current APK baseline

| | |
|---|---|
| File | **`mote-v0.1.0-b21.apk`** (artifact **`mote-android-v0.1.0-b21`**) |
| Package / label | `com.verbal76.axolotl` / **Mote** |
| Build / versionCode | 21 (versionName 0.1.0) |
| Build source | `a72ae3b0514ac8bff14a8cc2e507bd3af23831dd` |
| Bundled gameplay | identical to `227d0ab` (the dev-000012 gameplay) |
| Runtime | `android-godot-4.7.2-r4` |
| Permissions | INTERNET, VIBRATE |
| Game version | 0.1.0 |
| APK SHA-256 | `801c889b61b0d4a55722d3a2243ab91f28868482be3890c2231f998f3c6c6d0d` |
| Signing certificate SHA-256 | `A8:4F:BA:D5:61:B9:F5:E2:4E:BB:45:E2:95:17:94:F6:17:28:19:56:CF:DB:CA:FF:3A:CF:DB:9E:63:E2:C2:E3` (pin enforced in CI) |
| Built by | Build & Verify #21, [run 36341864999](https://github.com/verbal76/Axolotl/actions/runs/36341864999) |

- **Mote Dev companion:** `mote-dev-v0.1.0-b21.apk` (artifact `mote-android-dev-v0.1.0-b21`),
  `com.verbal76.axolotl.dev`, SHA-256 `4cc9bdc4ca007d90a508c7dc968e1989b358de93ecdf392a2ca73567f6bad86b`, same certificate. Optional.
- **Installing:** install b21 **over** the existing Mote app. **Do not uninstall first.** It is the
  same package, the same certificate and a higher versionCode, so Android keeps the save data.
  Play Protect's "unknown developer" prompt is expected; tap **Install anyway**.
- **History:** b18 (`854ea84`, r3) was the previous baseline. Its normal app had no OTA client.

## 11. Current OTA

| | |
|---|---|
| OTA id / channel | **`dev-000013`** / `dev` |
| Source | `a72ae3b0514ac8bff14a8cc2e507bd3af23831dd` (game layer = `227d0ab`) |
| Runtime / bootstrap | `android-godot-4.7.2-r4` / 1 |
| Game version / save schema | 0.1.0 / 1 (min 1) |
| Payload | `axolotl-dev-000013.pck`, 3,387,632 bytes |
| Payload SHA-256 | `a2f0cd0d56272807df9df046e5a9c142e6c479028e9babccb0850fbabc29cd75` |
| OTA public-key SHA-256 (DER) | `a003a45ce422325ef1de52958bd9d4d2a06b912ae119c6c7a7f9e40ff2720cf2` (unchanged) |
| Manifest | `https://github.com/verbal76/Axolotl/releases/download/ota-dev-000013/manifest.json` |
| Pointer | `https://github.com/verbal76/Axolotl/releases/download/ota-channel-dev/latest.json` → `dev-000013` |
| Compatible APK | b21 (r4). b18 (r3) rejects it: "native update required". |
| Published by | OTA publish #13, [run 36341861522](https://github.com/verbal76/Axolotl/actions/runs/36341861522) |

**Independent verification.** The objects were downloaded from the public URLs. The check confirmed:

- the manifest signature verifies against the pinned key embedded in the APK;
- the payload hash and size match the manifest;
- `tools/ota_inspect_pack.gd` reports INSPECT OK;
- the pack matches a local export of `a72ae3b` (only Godot's per-machine `uid_cache.bin` and a random scene node id differ);
- its gameplay files are byte-identical to dev-000012;
- an r3 client rejects it, and an r4 client rejects dev-000012.

It carries the same gameplay as the bundled game. Its purpose is to prove the new APK's
discovery → download → verification → activation → rollback path.

**dev-000012** (`227d0ab`, r3, PCK `83f6de50…ae277db`) remains published as historical evidence.

> **PUBLISHED:** yes. **DOWNLOADED ON THE PHONE:** NOT YET VERIFIED. **ACTIVE ON THE OWNER'S DEVICE:** NOT YET VERIFIED.

## 12. CI architecture

| Workflow | File | Triggers | Does |
|---|---|---|---|
| Build & Verify | `.github/workflows/build.yml` | `pull_request`, push to `main`, manual | Script check, unit suite, playthrough bot, version drift, runtime gate; signed Android APKs (Mote and Mote Dev) with badging, permission (both must have INTERNET), certificate and OTA-key checks; unsigned iOS simulator build |
| OTA publish (dev channel) | `.github/workflows/ota-publish.yml` | push to `claude/axolotl-aquarium-platformer-3y0qyy`, manual | Runtime gate, tests, PCK export (`Android` preset), manifest, signing, inspection, immutable release, re-download and verify, pointer move, receipt artifact `ota-receipt-*` |

Every push to the branch runs both workflows (the second through the PR). A commit message
containing `[skip ci]` skips both.

**Defensive fixes.** Each one exists because a real CI run failed. Do not remove any of them as
"unnecessary complexity" without proving it is obsolete.

- **`683b273`, aapt2 permission inspection.** `aapt dump badging` did not list the permissions. CI
  now reads them from the manifest xmltree and asserts: normal has no INTERNET, dev has INTERNET.
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
- **`31ae69d`, real branch SHA.** `pull_request` runs check out GitHub's synthetic merge commit. The
  workflow now checks out and records `SOURCE_SHA` = the PR head commit, and asserts it before export.

Workflow-level pins (public values, not secrets): `MOTE_DEV_CERT_SHA256` and `MOTE_OTA_PUBKEY_DER_SHA256`.

## 13. GitHub secrets (names only)

| Secret | Purpose |
|---|---|
| `MOTE_OTA_SIGNING_KEY` | Private RSA key that signs OTA manifests. It must match the public key in `scripts/boot/ota_config.gd`. |
| `MOTE_ANDROID_DEV_KEYSTORE_B64` | Base64 PKCS12 keystore that signs both APKs, so updates install over each other |
| `MOTE_ANDROID_DEV_KEYSTORE_PASSWORD` | Keystore password |
| `MOTE_ANDROID_DEV_KEY_ALIAS` | Key alias inside the keystore |
| `MOTE_ANDROID_DEV_KEY_PASSWORD` | Key password. It must equal the keystore password (PKCS12), and CI checks this. |

- **Values** are never recorded anywhere in the repository, logs or artifacts. CI reports only presence.
- **Private material:** keys and keystores must never be committed; `.gitignore` guards against it.
- **Missing keystore:** the APK build falls back to a throwaway key with a warning, and the
  certificate pin is then not enforced.
- **Missing OTA key:** the OTA workflow stays green but writes `"published": false`.

## 14. Requirement status

`docs/REQUIREMENTS_LEDGER.md` is the detailed authority. It has 143 rows in these sections:

- G: original specification
- F: owner feedback
- O: OTA
- V: version and identities
- N: naming
- C: credentials
- A: CI and APK
- R: OTA delivery rectification

Ledger status codes map to the categories below:

- **Implemented + verified (`I+V`):** nearly all rows. "Verified" means automated evidence ran; it
  never means device evidence.
- **Implemented, not yet automated-verified:** listed in §15.
- **Physical device not yet verified:** everything. O-19, A-05 and R-19 are **BLOCKED** until the
  owner tests on the phone. R-01 and R-14 are BLOCKED for their device part. F-07's launcher
  appearance is BLOCKED on the device.
- **Not implemented:** no requested feature. The only gap is a real iOS team ID.
- **Superseded:** G-13, G-28, G-57 (see §8).

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

## 16. Physical-device acceptance (owner; nothing verified yet)

Target: **Mote b21** (`mote-v0.1.0-b21.apk` from artifact `mote-android-v0.1.0-b21`) + **dev-000013**.

**A. Install/upgrade.** Keep the existing Mote app; **do not uninstall** (saves are kept). Open the
APK and choose **Update** (Play Protect: **Install anyway**). Mote Dev, if installed, can stay or be removed.

**B–C. Offline start.** Turn on airplane mode. Launch Mote. It starts straight to the title and plays.
Open **Pause → About / Diagnostics**. Expected before OTA:

```
Native
  Version: 0.1.0
  Android Build: 21
  Flavor: normal
  Godot: 4.7.2
  Runtime: android-godot-4.7.2-r4
  Bundled baseline source: a72ae3b0514ac8bff14a8cc2e507bd3af23831dd
OTA
  Enabled: yes
  Channel: dev
  Status: Offline: update channel not reachable; playing the current game   (or "Not checked yet" in the first seconds)
  Bundled baseline: a72ae3b0514ac8bff14a8cc2e507bd3af23831dd (Android Build 21)
  Active: bundled baseline
  Latest on channel: not checked yet
  Pending (runs after restart): none
Source
  Git SHA (running code): a72ae3b0514ac8bff14a8cc2e507bd3af23831dd
Persistence
  Save Schema: 1
```

Play for a minute (food/lunge, swipe) to confirm the bundled game is current (F-09 behaviour present).

**D–F. Reconnect.** Turn airplane mode off. Close Mote from Recents and reopen it: every start checks
once, a few seconds after the game is up. (Returning to a running app re-checks only if 15 minutes have
passed since the last automatic attempt, and a running app re-checks hourly.) Gameplay never pauses for it. A toast says
"dev-000013 ready: restart to run it". Diagnostics shows `Latest on channel: dev-000013`,
`Status: Update downloaded: dev-000013 runs after the app restarts`, and `Pending: dev-000013 (game 0.1.0, a72ae3b0514a)`.

**G–H. Manual check.** Tap **Check for update**: "up to date (latest dev-000013)", because it is already downloaded.
(**Download update** is enabled only when a check has found something not yet downloaded.)

**I–J. Activate.** Close the app from Recents and reopen it. Expected after OTA:

```
OTA
  Enabled: yes
  Channel: dev
  Status: Up to date   (after the automatic check; "Not checked yet" before it)
  Bundled baseline: a72ae3b0514ac8bff14a8cc2e507bd3af23831dd (Android Build 21)
  Active: dev-000013 (source a72ae3b0514ac8bff14a8cc2e507bd3af23831dd)
  Latest on channel: dev-000013 (checked …)
  Runtime compatibility: this app runs android-godot-4.7.2-r4; latest OTA compatible
  Current: dev-000013 (game 0.1.0, a72ae3b0514a)
Native
  Android Build: 21   (unchanged)
Automation
  Build run (running code): 36341861522   (the OTA's run)
  Native build run: 36341864999
```

**K. Play.** The game still plays normally.

**L. Roll back.** Diagnostics → **Roll back**, then close from Recents and reopen. With no previous
OTA, the bundled game runs (`Active: bundled baseline`). dev-000013 is now listed under
`Rejected OTAs` and is not downloaded again. A later OTA (dev-000014+) is.

**M. Bundled baseline.** Diagnostics → **Boot bundled baseline**, restart: `Status: OTA disabled…`,
`Active: bundled baseline`, and no automatic checks.

**N. Re-enable.** **Re-enable OTA**, restart. It returns to CURRENT, if there is one (after L there
is none, so it stays on the bundled game until the next OTA). To exercise N with an active OTA, do M and N before L.

Record the owner's results in the ledger (O-19, A-05, R-01, R-14, R-19, F-07, F-09) only with the owner's evidence.

## 17. Repository isolation

**MOTE AUTHORIZED REPOSITORY: `verbal76/Axolotl`.** The new session must be connected only to this
repository. Do not name, open or use any other game repository in Mote development.

## 18. Current stopping point

- **Rectification complete in software:** the Mote app itself is OTA-capable and offline-first
  (runtime r4). b21 is built and identity-checked; dev-000013 is published and independently verified;
  CI is green on `a72ae3b`.
- **Next task:** the owner's **phone acceptance of Mote b21 + dev-000013** (§16).
- **After that:** continue from the owner's feedback or from explicitly requested new work. Game-layer
  changes reach b21 by OTA on push. Native changes need `ota_runtime.py --bump` and a new APK.

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
   - last gameplay commit `227d0ab` (game layer unchanged at `a72ae3b`);
   - native + OTA source `a72ae3b` (runtime r4);
   - the handoff commit is documentation only.
6. Report any drift.
7. Report the current native baseline (Mote b21).
8. Report the current OTA (`dev-000013`, or newer if the channel pointer has moved).
9. Report the physical-device verification state (none unless the owner has supplied evidence).
10. Continue from the documented stopping point (§18).

**Preserve:**

- offline-first play: nothing may wait for, or require, the network;
- the OTA client in the Mote app (and Mote Dev);
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

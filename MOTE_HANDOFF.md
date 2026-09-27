# Mote — development handoff

This is the authoritative handoff for continuing **Mote** in a new coding session. It records the
state accepted by the owner in the pre-handoff completion report and cross-checked against the
repository and the published OTA.

> **MOTE AUTHORIZED REPOSITORY: `verbal76/Axolotl`**
> Work only in this repository. The previous coding environment also exposed an unrelated
> repository. An isolation audit found it clean and untouched. Do not open, search, or change any
> other repository in Mote work.

## 0. Identities at handoff (do not confuse these)

| Identity | Value |
|---|---|
| Repository / branch | `verbal76/Axolotl`, `claude/axolotl-aquarium-platformer-3y0qyy` (draft PR #1 into `main`) |
| **Handoff document commit** | The commit that adds this file. It is newer than every commit below and changes documentation only. |
| **Last gameplay source commit** | `227d0abab6cadd8cd90536f92fc8dbddf4b29fc3` (`227d0ab`) |
| **Native APK baseline source** | `854ea84142e4a905e62ad2da6c1e2daf10b24cde` (`854ea84`), built as Mote Dev **b18** |
| **Current OTA** | **`dev-000012`**, built from `227d0ab` |
| Runtime | `android-godot-4.7.2-r3` |
| Game version / save schema | `0.1.0` / `1` |
| Requirement authority | `docs/REQUIREMENTS_LEDGER.md` as of `227d0ab` |

> **PHYSICAL PHONE ACTIVATION OF dev-000012: NOT YET VERIFIED.**
> Nothing has been verified on a physical device. Do not treat CI results as device results.

The handoff commit was pushed with `[skip ci]`, so it built no APK and published no OTA.
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
| Android build | versionCode = the Build & Verify workflow's `run_number` (baseline: **18**) |
| Save schema | `SAVE_SCHEMA = 1`, `MIN_SAVE_SCHEMA = 1` in `scripts/core/save_schema.gd` |
| Normal package | `com.verbal76.axolotl`, label **Mote** |
| Dev package | `com.verbal76.axolotl.dev`, label **Mote Dev** |

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
- **Builds:** a normal offline build plus a separate Dev build that receives over-the-air updates.

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
| Tests | `scripts/tests/test_runner.gd`, `unit_tests.gd`, `ota_tests.gd`, `playthrough_bot.gd`, `shots.gd`, `model_preview.gd`, `perf.gd` |
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

Evidence on the final gameplay source `227d0ab`:

| Check | Result |
|---|---|
| Unit suite (mechanics, OTA, version, naming, packaging, gill, terrain, food tests) | **141 passed, 0 failed** |
| Playthrough bot, seed 4242 | **12/12** |
| Playthrough bot, seed 7 | **12/12** |
| Version drift check | passed: every consumer followed the canonical value |
| OTA local end-to-end (`tools/ota_e2e_local.sh`) | ALL PASSED |
| Runtime gate | `r3 unchanged (godot 4.7.2): OTA-compatible` |
| Build & Verify #20, [run 36337772767](https://github.com/verbal76/Axolotl/actions/runs/36337772767) | success: tests and playthrough, Android APKs, iOS simulator build |
| OTA publish #12, [run 36337769838](https://github.com/verbal76/Axolotl/actions/runs/36337769838) | success: `dev-000012`, `published: true`, `pointer_moved: true` |

The playthrough bot drives only the HUD/gamepad input actions. It completes the tutorial, restores
all three balls to 100%, travels and backtracks through every vortex, reaches ALL CLEAR and
free-roams.

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

## 9. Normal vs Dev architecture

| | Normal **Mote** | **Mote Dev** |
|---|---|---|
| Package | `com.verbal76.axolotl` | `com.verbal76.axolotl.dev` |
| Export preset | `Android` | `Android Dev` (custom feature `ota_dev`) |
| INTERNET permission | **no** | yes |
| OTA | none: always runs the bundled game | `dev` channel |
| Signing | the same Mote Dev certificate | the same Mote Dev certificate |

The two apps install side by side.

**How OTA works** (full detail in `docs/OTA.md`):

- **Mounting:** the `Boot` autoload runs first and, in `_init`, mounts a verified Godot PCK before
  any other script or scene loads.
- **Verification:** each PCK must pass a signed manifest (RSA PKCS#1 v1.5, SHA-256), the runtime and
  bootstrap checks, and the size and SHA-256 checks.
- **Package state:** transactional (current / previous / pending / ready / bad).
- **Recovery:** a boot-health check with rollback after 2 unhealthy starts, plus manual rollback,
  bundled-baseline boot and re-enable.
- **Hosting:** GitHub Releases. Each OTA gets an immutable prerelease tag `ota-dev-%06d`. The mutable
  pointer `ota-channel-dev/latest.json` only moves forward.

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
| File | `mote-dev-v0.1.0-b18.apk` (artifact `mote-android-dev-v0.1.0-b18`) |
| Build / versionCode | 18 |
| Source | `854ea84` |
| Runtime | `android-godot-4.7.2-r3` |
| Package / label | `com.verbal76.axolotl.dev` / Mote Dev |
| Game version | 0.1.0 |
| APK SHA-256 | `8066cbb1b64ef7f3a17e4b8a5b3eca87bfc988508391ef26d0f2958bb9504f6b` |
| Signing certificate SHA-256 | `A8:4F:BA:D5:61:B9:F5:E2:4E:BB:45:E2:95:17:94:F6:17:28:19:56:CF:DB:CA:FF:3A:CF:DB:9E:63:E2:C2:E3` |
| Built by | Build & Verify #18, [run 36335461294](https://github.com/verbal76/Axolotl/actions/runs/36335461294) |

- **Offline companion:** `mote-v0.1.0-b18.apk` in the same run.
- **Newer artifacts:** Build & Verify #19 and #20 also produced APKs (b19 from `4aa86a3`, b20 from
  `227d0ab`). Nothing changed natively after `854ea84`, so **b18 remains the baseline** and the
  newer game content reaches it by OTA.
- **Installing:** remove every older Axolotl / Mote / Mote Dev app first. Android refuses to install
  over an app signed with a different, retired key and shows "App not installed". Play Protect's
  "unknown developer" prompt is expected; tap **Install anyway**.

## 11. Current OTA

| | |
|---|---|
| OTA id / channel | **`dev-000012`** / `dev` |
| Source | `227d0abab6cadd8cd90536f92fc8dbddf4b29fc3` |
| Runtime / bootstrap | `android-godot-4.7.2-r3` / 1 |
| Game version / save schema | 0.1.0 / 1 (min 1) |
| Payload | `axolotl-dev-000012.pck`, 3,373,924 bytes |
| Payload SHA-256 | `83f6de5073af4b679ac7b8babdfbb39a03b59805e7d97c787d1aadbefae277db` |
| OTA public-key SHA-256 (DER) | `a003a45ce422325ef1de52958bd9d4d2a06b912ae119c6c7a7f9e40ff2720cf2` |
| Manifest | `https://github.com/verbal76/Axolotl/releases/download/ota-dev-000012/manifest.json` |
| Pointer | `https://github.com/verbal76/Axolotl/releases/download/ota-channel-dev/latest.json` → `dev-000012` |
| Compatible APK | b18 (r3) |

**Independent verification.** The objects were downloaded from the public URLs, not taken from the
workflow's own report. The check confirmed:

- the manifest signature verifies against the key embedded in the APK;
- the key fingerprint equals the pin;
- the payload hash and size match the manifest;
- the pack's game version equals the manifest and the canonical 0.1.0;
- the source and runtime are as listed above;
- `tools/ota_inspect_pack.gd`, the device's own client code, reports INSPECT OK;
- the pack's scripts are byte-identical to a local export of `227d0ab`.

Earlier OTAs on the same runtime are `dev-000010` (`854ea84`) and `dev-000011` (`4aa86a3`).
`dev-000008` and `dev-000009` are on r2, so b18 rejects them.

> **PUBLISHED:** yes. **PHYSICALLY DOWNLOADED:** NOT YET VERIFIED. **ACTIVE ON OWNER DEVICE:** NOT YET VERIFIED.

## 12. CI architecture

| Workflow | File | Triggers | Does |
|---|---|---|---|
| Build & Verify | `.github/workflows/build.yml` | `pull_request`, push to `main`, manual | Script check, unit suite, playthrough bot, version drift, runtime gate; signed Android APKs (normal and dev) with badging, permission, certificate and OTA-key checks; unsigned iOS simulator build |
| OTA publish (dev channel) | `.github/workflows/ota-publish.yml` | push to `claude/axolotl-aquarium-platformer-3y0qyy`, manual | Runtime gate, tests, PCK export, manifest, signing, inspection, immutable release, re-download and verify, pointer move, receipt artifact `ota-receipt-*` |

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

`docs/REQUIREMENTS_LEDGER.md` is the detailed authority. It has 124 rows in these sections:

- G: original specification
- F: owner feedback
- O: OTA
- V: version and identities
- N: naming
- C: credentials
- A: CI and APK

Ledger status codes map to the categories below:

- **Implemented + verified (`I+V`):** nearly all rows, including all V, N and C rows, every F row
  (F-07 only for its APK contents), and most G, O and A rows. "Verified" means automated evidence
  ran; it never means device evidence.
- **Implemented, not yet automated-verified (`I+NYV`, or partial qualifiers):** listed in §15.
  Rows G-49, G-52 and G-54 are verified only by configuration or simulated input.
- **Physical device not yet verified:** everything. O-19 (a real Android end-to-end run) and A-05
  are **BLOCKED** until the owner tests on the phone. F-07 is verified from the APK contents; its
  launcher appearance is BLOCKED on the device.
- **Not implemented:** no requested feature. The only gap is a real iOS team ID, since the iOS build
  is an unsigned simulator build.
- **Superseded:** G-13 and G-28 (see §8).

## 15. Automated verification gaps

These are implemented but lack automated evidence. They are **not** unimplemented.

- **G-12:** manual camera swipe (no drag test)
- **G-23:** water and vegetation response (no assertion)
- **G-26:** parasite attack telegraphs (not asserted)
- **G-31:** four landing variants (no per-variant test)
- **G-41:** adaptive music and receding bedroom sounds (not asserted or listened to)
- **G-55:** thermal scaling on real hardware (desktop timing only)
- **G-56:** safe areas (no notched device or test)
- **O-17:** Diagnostics touch buttons (text and actions are tested; the buttons are not)

## 16. Physical-device acceptance (owner; nothing verified yet)

1. Uninstall every Axolotl / Mote / Mote Dev app, then install `mote-dev-v0.1.0-b18.apk`. Play Protect should name **Mote Dev**; tap **Install anyway**.
2. The launcher shows the axolotl artwork labelled **Mote Dev**. With Themed icons on, it shows the white axolotl silhouette.
3. The title shows **MOTE** and **v0.1.0**.
4. Open Diagnostics (Pause → About / Diagnostics) **before OTA**:
   - native 0.1.0, build 18, flavor dev, source `854ea84`;
   - runtime `android-godot-4.7.2-r3`;
   - OTA: none (bundled);
   - save schema 1.
5. Tap **Check for update**. "Latest on channel" shows **dev-000012**.
6. Tap **Download update** and wait until it shows ready/pending.
7. Close the app from Recents.
8. Reopen it.
9. Diagnostics shows active OTA **dev-000012**, source `227d0ab`, game 0.1.0, native build still 18.
10. **Food and lunge:** lunge at a drifter from ~2 m, including one slightly above and to the side. Gill turns, rises and catches it. Darters hop first, then are catchable in their pause.
11. **Gill:** six gills; a snake-like body and legs.
12. **Health:** take a hit and one gill dulls and fades. Eating restores it.
13. **Tail swipe:** hits beside and behind Gill, and Gill turns toward the nearest parasite.
14. **Lunge height:** never carries Gill higher than a jump.
15. **Terrain:** smooth hills; platforms solid from every side.
16. **Camera and touch:** stick, buttons, camera swipe.
17. **Performance:** smooth play, and the phone doesn't overheat.
18. **Roll back:** Diagnostics → **Roll back**, then restart. The previous package loads, or the bundled baseline if there is none.
19. **Boot bundled baseline:** restart and confirm OTA shows none. Then **Re-enable OTA**, restart, and dev-000012 returns.
20. Check Diagnostics after steps 9, 18 and 19.

Record the owner's results in the ledger (O-19, A-05, F-07, F-09) only with the owner's evidence.

## 17. Repository isolation

**MOTE AUTHORIZED REPOSITORY: `verbal76/Axolotl`.** The new session must be connected only to this
repository. Do not name, open or use any other game repository in Mote development.

## 18. Current stopping point

- **No half-finished implementation task is being transferred.** The food and lunge work is complete.
- **Delivery is done:** the source is pushed, CI is green on `227d0ab`, and `dev-000012` was
  published and independently verified.
- **Next task:** the **owner's physical-phone acceptance** of **Mote Dev b18 + dev-000012** (§16).
- **After that:** continue from the owner's feedback or from explicitly requested new work.
  Game-layer changes ship to b18 by OTA on push. Native changes need `ota_runtime.py --bump` and a
  new APK.

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
   - last gameplay commit `227d0ab`;
   - native baseline `854ea84`;
   - the handoff commit is documentation only.
6. Report any drift.
7. Report the current native baseline (Mote Dev b18).
8. Report the current OTA (`dev-000012`, or newer if the channel pointer has moved).
9. Report the physical-device verification state (none unless the owner has supplied evidence).
10. Continue from the documented stopping point (§18).

**Preserve:**

- the normal offline build;
- the Dev/OTA build;
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

# Hot Attic Games application infrastructure — Mote

Owner directive (2026-10-03): every Hot Attic Games application carries the same infrastructure:
OTA discovery, a "Please wait, applying update" activation screen, Settings → About with Copy
diagnostics, and the Hot Attic Games studio splash. This page records how Mote meets it, adapted
to Mote's existing signed OTA (`docs/OTA.md`, `docs/VERSIONING.md`), and what needs the next APK.
Ledger row 38.

**Native layer frozen.** Everything here lives in the OTA-delivered game layer (`scripts/core`,
`scripts/ui`, `scripts/tests`, docs). `project.godot`, `export_presets.cfg` and `scripts/boot/*`
were not changed; `python3 tools/ota_runtime.py --check` stays OTA-compatible (runtime r5,
installed APK = Android build 22). Items that need native code are written up as proposals for the
next APK (§6).

## 1. OTA lifecycle (audit, 2026-10-03)

| Step | Where | What happens today |
|---|---|---|
| **Discovery** | native `Boot.auto_check` + game `AutoUpdate` | (a) **Launch ("check first", 2026-10-04):** `AutoUpdate.launch_precheck()` calls `Boot.updater.check(false)` on the first loading-screen frame BEFORE the world is built, waits at most 3 s for the answer, downloads a newer version (at most 45 s) and activates it before anything is built (not on scene reloads, soft-restart re-entry, test runs or when automatic updates are off; see `docs/OTA.md`). (b) **Start:** the native check after boot health. (c) **Resume:** native check on `APPLICATION_RESUMED`/`FOCUS_IN` if 15 min since the last automatic attempt, plus (new) the game layer's wall-clock resume check (below). (d) **Periodic:** native, every 60 min of engine-clock time while running. (e) **Manual:** About → Check for updates. Pointer: `https://github.com/verbal76/Axolotl/releases/download/ota-channel-dev/latest.json` (cache-busted). |
| **Download** | native `OtaUpdater` | pointer → signed manifest + signature → PCK streamed to `packages/.incoming-<id>.pck` (size-capped, 15 s pointer/manifest timeout, 15 min package timeout, non-threaded polling, never blocks the frame). The game layer raises the chunk size to 4 MiB per poll. |
| **Verify** | native `OtaCore.check_manifest` / `stage_incoming` | RSA/SHA-256 signature over the manifest with the pinned public key, channel, schema, runtime id (`android-godot-4.7.2-r5`), bootstrap version, save-schema compatibility, then size + SHA-256 of the PCK. A full-size file with a wrong hash is remembered as bad; interrupted downloads stay retryable. |
| **Stage** | native | verified package renamed into `packages/<id>.pck` → READY → (auto_activate) PENDING. |
| **Activate** | game `AutoUpdate` + `SoftRestart`, native `OtaCore.boot` | **In-process soft restart** at a safe moment: launch (before the title), title screen, or return from background (never in play, menus, cinematics, lessons, aquarium, ending). Native `Boot.core.boot()` re-verifies and mounts PENDING; the game layer is recompiled from the new pack; the main scene reloads. A cold start activates PENDING the same way in `Boot._init`. |
| **Health / commit** | native | the new game must call `Boot.report_ready()` and keep running 3 s; then PENDING → CURRENT, old CURRENT → PREVIOUS. |
| **Rollback** | native | a package that fails to reach health in 2 starts is marked bad and the device falls back CURRENT → PREVIOUS → bundled baseline. Manual Roll back / Use bundled baseline in the native recovery panel (About → Advanced, F9, or five taps top-left). A game layer that does not compile in-process is rejected and the previous package re-mounted. |
| **Offline** | both | nothing waits for the network: boot mounts what is already verified on the device; a failed check is a status ("Offline: …"), counted as an attempt so an offline phone is not hammered; the launch wait is capped at 8 s from the check's start and offline fails fast. |

**Gap found and fixed (OTA-delivered):** r5 measures the 15-minute resume gap on the engine clock
(`Time.get_ticks_msec`, monotonic), which does not advance while the phone sleeps. A player who
opens Mote, pockets the phone overnight and comes back usually got *no* resume check — the update
waited for the hourly periodic check. `AutoUpdate._resume_check()` now applies the same 15-minute gap
on the wall clock against the last recorded check (`state.json` → `events.check.time`, any
outcome). It runs only when the native check did not start (never two at once), honours
`--ota-no-autocheck`, OTA disabled, health and test runs, and sets the native `_last_auto_check_ms`
so the native policy stays coherent. Test: `hag_resume_check_wall_clock`.

**Gaps that need native code (next APK, §6):** the hourly periodic check has the same engine-clock
blind spot; activation is driven from the game layer through r5 internals (`Boot.core.boot`,
`Boot._ready_at`) rather than a public native API; and the native layer emits no activation
signal, so a broken game layer cannot show the activation screen.

## 2. "Please wait, applying update"

**Where activation really happens.** Two places:
1. **In-process soft restart (game layer, the normal path).** `AutoUpdate` → `SoftRestart.apply`:
   save → native `Boot.core.boot()` re-verifies and mounts PENDING → the old game layer is freed and
   recompiled from the new pack → the main scene reloads → the new loading screen appears. Fully
   observable and driven by OTA code. **IMPLEMENTED** here.
2. **Cold start (native).** If the app is killed with an update PENDING, `Boot._init` mounts it before
   any game script exists. Nothing OTA-delivered runs during that window, so no OTA can show anything
   there (the engine boot splash is on screen). **PREPARED/HELD** as native proposal N2 (§6).

**Implementation** (`scripts/core/update_activation.gd`):
- *State* (Engine metadata, survives the script recompile): `begin(id)` when `SoftRestart.apply` starts
  the switch (after the save succeeded, before anything changes), refused while one runs (no duplicate
  activation; `SoftRestart.apply` returns "an update is already being applied"); `finish(false)` when the
  native layer does not mount it; `finish(ok)` from the new version's first loading-screen frame
  (`AutoUpdate.on_loading_visible`). `is_applying()` also expires after 20 s, so it can never stick.
- *Modal*: plain engine nodes only (no game script, so it stays up while every game script is
  recompiled): Mote's loading-screen backdrop, a `UiStyle` panel/font, exactly "Please wait, applying
  update", an indeterminate `ProgressBar` (animated by the engine), `MOUSE_FILTER_STOP` backdrop, layer
  101 above the loading screen. Node name `AutoUpdateCurtain` (unchanged), so any version's loading
  screen lifts it.
- *Never hangs*: an engine-only `Timer` inside the modal (20 s) turns the text into "The update did not
  finish. Mote will try again on the next start.", hides the bar and removes the modal 3 s later. A
  failure before the point of no return removes the modal at once and the existing toast says the
  current version keeps running.
- *Not shown* while idle, checking, downloading, failed, rejected, incompatible, offline, up to date or
  merely staged (`UpdateActivation.phase()` / `shows_modal()`); the earlier "Updating to …" toast during
  activation was removed (the modal says it).
- Tests: `hag_activation_modal_only_when_applying`, `hag_activation_once_and_cleared`,
  `hag_modal_text_indicator_blocks_input`, `hag_modal_single_instance`,
  `hag_modal_safety_timeout_never_hangs`, `hag_no_duplicate_activation`,
  `autoupd_unmountable_activation_failed`. Screenshot: `tests/shots.gd --only=applying`.

## 3. Settings → About / Diagnostics and Copy diagnostics

Settings → **About / Diagnostics** (`scripts/ui/diagnostics_page.gd`) now shows, without scrolling:
the update headline, three concise lines (`AppInfo.about_lines()`: product, version, app build,
running package; update state, channel, runtime; device OS/API/model/locale) and the buttons
**Check for updates**, **Install now** (only when an update waits on the title), **Copy diagnostics**,
**Advanced** (the unchanged native recovery panel) and **Close**. **Technical** (top right) opens the
full report in the page's only scroll area; it is closed every time the page opens.

**Copy diagnostics** (`AppInfo.copy_text()`, `DisplayServer.clipboard_set`) copies plain text: the
standard report below, then the existing native diagnostics (OTA slots and events, startup
timeline, automatic updates, run timer summary). No keys, passwords, user names, home paths or save
file contents (test `hag_copy_text_plain_no_secrets`).

| Section | Field | Source at runtime |
|---|---|---|
| App | app name, version name (game + APK), version code, native runtime id, build identity, source SHA, channel | `Boot.identity()` (native build info baked into the APK + `GameVersion`) |
| App | package id | the app's private data directory (`OS.get_user_data_dir()` = `/data/user/<n>/<package>/files` on Android); otherwise "not exposed by this build (next APK)" |
| Device | OS + version, model, locale | `OS.get_name()`, `OS.get_version()`, `OS.get_model_name()`, `OS.get_locale()` |
| Device | API level | system property `ro.build.version.sdk` via `getprop` (once per process, Android only); otherwise "not exposed" |
| — | captured-at | UTC wall clock when the text is built |
| OTA | updates enabled, channel, runtime compatibility, current OTA id + seq, running source (embedded vs OTA), OTA source SHA, PCK SHA-256, last check | `Boot.core.state` / `Boot.core.active` / `Boot.updater` |
| OTA | update state | `UpdateActivation.phase()`: CURRENT / AVAILABLE / STAGED / APPLYING / FAILED, or a qualified UNKNOWN (not checked yet, checking, offline) or OFF; never guessed |
| Play | target SDK | **not exposed by this build (next APK)**; the line also states what the build configuration implies (Godot 4.7.2 default 36, min 24) and that it was not read from the app |
| Play | Play required target API | 36 (developer.android.com, checked 2026-10-03) |
| Play | PLAY API COMPLIANT | **UNVERIFIED** at runtime (target not exposed); the build configuration implies YES |
| Play | export / signing | debug vs release template (`OS.is_debug_build()`), "signed"; certificate fingerprint not exposed (next APK) |

Tests: `hag_app_info_package_and_play_rules`, `hag_report_has_every_field`,
`hag_copy_text_plain_no_secrets`, `hag_about_concise_fits_no_scroll` (panel on screen, buttons inside,
≥ 56 px, apart, row fits with Install showing, no scroll until Technical), `hag_about_technical_and_copy`;
existing `diagnostics_page_simple`, `settings_fits_landscape_no_scroll`. Screenshots:
`tests/shots.gd --only=about`.

## 4. Hot Attic Games studio splash

`scripts/ui/studio_splash.gd` (`StudioSplash`), started from `Game._ready` right after Mote's loading
screen is added. Black background, the owner-supplied canonical logo
**`res://Hot_Attic_Games_Master_Logo_ALPHA_FINAL.png`** (1536×1024 RGBA, transparent background) centred
and contain-fitted (aspect kept, 12 % margin; never redrawn, cropped, recoloured or substituted).
0.3 s fade-in, shown to 2.2 s, 0.4 s fade-out: about 2.6 s on the wall clock from its first frame. Silent,
input blocked, layer 102 over the loading screen. The world builds behind it, so it masks startup work.

- **Genuine (cold) launch only:** decided once per process (Engine metadata `hag_studio_splash`, which
  survives scene reloads and soft restarts), so Return to Title / New Run and an in-process update never
  show it (`AutoUpdate.soft_restarted()` also excluded). Automated test runs skip it.
- **Never strands the user:** it frees itself after 2.6 s whatever else happens, and gives way at once if
  the "Please wait, applying update" modal appears (update-first launch). If the asset were ever absent
  the splash is skipped (no placeholder) and the timeline records why.
- **Launch order (required):** neutral native frame → Hot Attic Games splash → Mote loading/title → play.
  The Hot Attic Games splash must be the first branded image.
- **VERIFIED OWNER FINDING (v95, 2026-10-04): splash sequencing failure.** On the phone the launch
  reads Mote → Hot Attic Games → Mote. Root cause: the *engine boot splash* of the installed r5 APK
  (`project.godot` `application/boot_splash/image = res://assets/icon/splash.png`, the Mote axolotl,
  on Mote teal) is drawn by the APK before any game code runs; the Mote loading screen after the
  studio splash deliberately reuses the same artwork (it was designed as a seamless hand-over from
  that boot splash). The game layer is already right (studio splash and loading screen are added in
  the same frame, the splash on top, opaque black). Android's own launch screen shows no artwork:
  its icon is the adaptive launcher foreground, which is fully transparent. **Fix (native, next
  APK = runtime r6):** `boot_splash/show_image=false`, `bg_color` black, export preset
  `splash_screen/*` set explicitly (neutral). Prepared on branch `preserve/mote-native-r6-splash`;
  cannot ship by OTA (the APK draws it before an OTA pack is mounted).
- **Recurrence guard:** `StudioSplash.native_launch_problems()` + test
  `hag_native_launch_neutral_before_studio_splash` read `project.godot`, the Android export preset
  and the launch icon's pixels. r5 is the one recorded exception (exactly its two known boot-splash
  problems; anything new fails); every later runtime revision must be clean.
- **Standing requirement:** see `CLAUDE.md` — the only studio logo is
  `Hot_Attic_Games_Master_Logo_ALPHA_FINAL.png`; the old path `branding/Hot_Attic_Games_Master_Logo.png`
  is obsolete.
- Tests: `hag_splash_genuine_launch_and_asset_rules`, `hag_splash_canonical_logo_present`,
  `hag_splash_uses_canonical_logo_with_alpha`, `hag_splash_skipped_when_logo_missing`,
  `hag_splash_black_centred_contain_fit`, `hag_splash_once_per_launch_about_2_6_s`,
  `hag_splash_yields_to_update_modal`, `hag_launch_order_rule`,
  `hag_native_launch_neutral_before_studio_splash`. Release gate: `tools/check_pack_logo.gd` (in `ota-publish.yml`)
  checks the logo is inside each OTA pack, pixel-exact against the canonical file, before the release.

## 5. Android / Google Play audit (2026-10-03)

| Fact | Value | Status / how determined |
|---|---|---|
| Package id | `com.verbal76.axolotl` (established on installed devices; **not renamed**) | VERIFIED: `export_presets.cfg` `package/unique_name`; CI asserts it with `aapt dump badging` |
| versionName | `0.1.0` (`version/name`; equals `GameVersion.GAME_VERSION`, CI checks) | VERIFIED: preset + `build.yml` badging check |
| versionCode | GitHub Actions `run_number` written into the preset at export (installed: 22); preset file holds `1` | VERIFIED: `build.yml` "Export the Mote APK" |
| min SDK | 24 | VERIFIED: preset sets none → Godot 4.7.2 default; template `config.gradle` `minSdk: 24` and the template APK's binary manifest `minSdkVersion=24` |
| target SDK | **36** | VERIFIED (build config): preset sets no `gradle_build/target_sdk` → Godot 4.7.2 default `DEFAULT_TARGET_SDK_VERSION`; template `config.gradle` `targetSdk: 36` (comment: "Also update export_plugin.cpp#DEFAULT_TARGET_SDK_VERSION") and both template APKs' manifests `targetSdkVersion=36`. Not read from an installed APK (the runtime does not expose it) |
| compile SDK | 36 | VERIFIED: template `compileSdk: 36`, manifest `compileSdkVersion=36` |
| Play required target API | 36 for new apps and updates from 2026-08-31 (extension to 2026-11-01 on request) | VERIFIED: developer.android.com/google/play/requirements/target-sdk, fetched 2026-10-03 (support.google.com answer 11926878 was unreachable from here) |
| PLAY API COMPLIANT | **YES** by build configuration (36 ≥ 36); **UNVERIFIED** at runtime | the About page says UNVERIFIED because the running app cannot read its own target SDK in r5 |
| ABIs | arm64-v8a only | VERIFIED: preset |
| Gradle build | off (`gradle_build/use_gradle_build=false`: prebuilt template APK) | VERIFIED: preset |
| APK / AAB | APK only. AAB needs Godot's Gradle build (`use_gradle_build=true`, export format AAB) | Godot's Android exporter only produces AAB with the Gradle build enabled (engine behaviour, from the engine's export options; not re-run here); Play requires AAB for new apps since Aug 2021 (developer.android.com/guide/app-bundle, fetched). **Class B** (native) |
| Export type | **debug template** (`--export-debug`) → `android:debuggable="true"` | VERIFIED: `build.yml`; template `android_debug.apk` manifest has `debuggable=true`. Google Play Console rejects debuggable uploads (UNVERIFIED by fetch; long-standing Play Console rule). **Class B** |
| Signing | APK signed with the stable Mote keystore from GitHub secrets (`MOTE_ANDROID_DEV_KEYSTORE_B64`, `…_PASSWORD`, `…_KEY_ALIAS`, `…_KEY_PASSWORD`), passed as Godot's *debug* keystore; CI verifies with `apksigner` and pins the certificate SHA-256 (`MOTE_DEV_CERT_SHA256`). OTA packs: separate key (`MOTE_OTA_SIGNING_KEY` secret; public half pinned in `ota_config.gd`). Play App Signing / upload key: not set up | VERIFIED from workflows (no secret values read or printed) |
| Permissions | `INTERNET` (OTA), `VIBRATE` (haptics, `Input.vibrate_handheld`); all others off | VERIFIED: preset (`permissions/*=true` only these two); CI lists manifest permissions |
| allowBackup | false (template default) | VERIFIED: template manifest |
| Third-party SDKs | none: no addons, no Android plugins, no analytics/ads/crash reporting; only the Godot template's AndroidX libraries | VERIFIED: repo (no `addons/`, no `android/`), preset |
| Network use | OTA only: HTTPS GET of `latest.json`, the signed manifest + signature and the PCK from GitHub Releases (`github.com/verbal76/Axolotl`); nothing else opens a connection | VERIFIED: only `ota_updater.gd` issues requests |
| Data collection / transmission | none by Mote: no account, no identifiers, no telemetry; saves and diagnostics stay on the device (Copy diagnostics is user-initiated, clipboard only). GitHub necessarily sees the request IP / user agent when updates download | VERIFIED (code); the Data Safety interpretation is an owner decision |
| Privacy policy / Data Safety form | none in the repository; no Play listing exists | VERIFIED absent |

**Remediation classes.** NONE: target API (36 meets the current rule). **A** (OTA, done here): About
diagnostics, activation modal, resume discovery, studio splash code. **B** (native / next APK, documented
only, not done): release export instead of debug; AAB via Gradle build; Play App Signing / upload key;
exposing target SDK, versionCode and certificate fingerprint to the runtime; any Godot engine upgrade.

## 6. Native proposals for the next APK (runtime r6)

- **N1 Wall-clock discovery.** `Boot.auto_check_due` on `Time.get_unix_time_from_system()` for resume and
  periodic checks (the periodic one still uses the engine clock).
- **N2 Activation API + signal.** `Boot.apply_pending(where) -> String` (the soft-restart mount step,
  public) and `signal activation_started(id)` / `activation_finished(id, ok)`; the native recovery overlay
  shows "Please wait, applying update" itself on `activation_started`, so even a broken game layer gets
  the screen. Cold start: if `Boot._init` mounts a PENDING package for the first time, keep a native
  "Please wait, applying update" panel up until the game reports its first frame (or 20 s).
- **N3 Identity fields.** `write_native_build_info.py` adds `package`, `version_code`, `min_sdk`,
  `target_sdk`, `export` (debug/release) and `signing_cert_sha256` (public fingerprint) to
  `native_build_info.gd`; `AppInfo` then shows them instead of "not exposed", and PLAY API COMPLIANT can
  be YES/NO at runtime.
- **N4 Play readiness (Class B).** `--export-release` with release keystore env vars; Gradle build
  (`use_gradle_build=true`) to produce an AAB; Play App Signing with an upload key. Keeps package id.
- **N5 Studio logo in the engine boot splash** (optional): only if the owner wants the logo before any
  game code; otherwise the OTA splash (§4) is enough.

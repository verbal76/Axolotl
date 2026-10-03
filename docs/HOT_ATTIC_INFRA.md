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
| **Discovery** | native `Boot.auto_check` + game `AutoUpdate` | (a) **Launch:** `AutoUpdate.begin_launch_check()` starts `Boot.updater.check(true)` on the first loading-screen frame while the world builds (not on scene reloads or soft restarts). (b) **Start:** the native check after boot health. (c) **Resume:** native check on `APPLICATION_RESUMED`/`FOCUS_IN` if 15 min since the last automatic attempt, plus (new) the game layer's wall-clock resume check (below). (d) **Periodic:** native, every 60 min of engine-clock time while running. (e) **Manual:** About → Check for updates. Pointer: `https://github.com/verbal76/Axolotl/releases/download/ota-channel-dev/latest.json` (cache-busted). |
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

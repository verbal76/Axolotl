# Worker-thread crash in a local unit run (2026-10-12): findings

## What happened

One local `--test=unit --shard=1/2` run (on `d76f786`'s parent line, during the overnight pass, with three
other Godot processes and edits running on the same machine) died with SIGSEGV right after
`desaturation_head_to_rear` (parasite body tests). The log directory was deleted when the gate was
restarted; the backtrace survives in the session transcript:

    [1] libc+0x45330            (signal restorer)
    [2] godot+0x44f7c18
    [3] godot+0x3719889
    [4] godot+0x49993d5
    [5] godot+0x3705157
    [6] godot+0x4006195
    [7] godot+0x4ee6c23
    [8] libc+0x9caa4            start_thread
    [9] libc+0x129c6c           clone3

## Which thread (evidence, 2026-10-12)

- gdb on a live unit run and on an empty Godot project: the engine thread whose stack is
  `nanosleep <- 0x4d9a34a <- 0x3b051a3 <- 0x4406195 <- 0x52e6c23 <- start_thread` exists in every
  headless run, even of an empty project. Frames [6]/[7] of the crash are that thread's wrapper and
  entry, and crash frame [5] (`0x3b05157`) lies 76 bytes before the live `0x3b051a3` in the same
  function: the dummy audio driver's mixing loop (mix, then sleep).
- The row 37 investigation (2026-10-03, symbol work against the same 4.7.2 binary) mapped these frames:
  [5] `AudioDriverDummy::thread_func`, [4] `AudioServer::_driver_process`, [3] `AudioServer::_mix_step`,
  [2] `StringName` copy constructor, reading `playback->bus_details`; and predicted "SIGSEGV with frame
  [2] at godot+44f7c18". Tonight's frame [2] is exactly `godot+44f7c18`.

**Conclusion:** the same engine race as ledger row 37: the main thread retires an
`AudioStreamPlaybackBusDetails` (frame-counted graveyard) while the audio thread is still copying it in
`_mix_step`. Triggers: every `volume_db` write on a playing player, and, inside the engine, every playing
`AudioStreamPlayer3D` on each physics tick. Exposed by an unthrottled headless loop under CPU contention.
Not a game-logic bug and not caused by tonight's changes. Confidence: high for the thread and the code path
(identical frames); the precise trigger of this occurrence cannot be identified.

## What was changed

- `d76f786`: pooled one-shot players (Sfx pools, footsteps) are stopped before their volume changes, so
  those writes never touch a live playback. It cannot remove the engine's own 3D-player swaps.
- `audio_volume_writes_reviewed` (unit test): every `volume_db` write and volume tween in game code is on a
  reviewed list (setup before play, after stop(), AudioDirector.set_volume's audible steps, the 0.8 s
  travel fade). A new one fails the test until it is reviewed against row 37. Negative check: a planted
  write fails it.

## Reproduction attempts (time-boxed)

`race_probe.gd.txt` (rename to .gd in a scratch project): 16 looping players with `volume_db` rewritten
every frame, and separately 16 moving `AudioStreamPlayer3D`, `--headless --max-fps 0`, each pinned to one
core: both survived 240 s. Since the hardening: full unit shards on `d76f786`, `0bc31ec`, `b0ba169` (3 x 2
shards) and the playthrough twice: no crash. Historical rate ~6 per 171 runs (row 37), so these clean runs
do not prove the race is gone.

## Residual risk and options (not applied)

- Phones: mixing runs in the platform audio callback through the same `_mix_step`; frames are paced by
  vsync, so the window is far smaller than in headless tests. Rare, but a hard crash (progress since the
  last autosave is lost).
- Engine-side fix: free retired bus details only after the audio thread finishes a mix step (an atomic
  mix counter); check whether a later Godot 4.x already does this. An engine change is a native (APK)
  change and needs the owner.
- Test-side: unit runs could use `--max-fps 120` (fewer swaps per mix step) if the crash recurs.

## Status: UNRESOLVED (2026-10-12)

The race is in the engine and is not fixed. The mitigations (`d76f786`) and the guard test
(`audio_volume_writes_reviewed`) reduce how often game code hits it; they cannot remove it.

## Recommendation for the eventual engine-side fix (planning only; nothing started)

**Scope.** A small patch to Godot 4.7.2's `servers/audio_server.cpp` (and its header), nothing in the game:
retired `AudioStreamPlaybackBusDetails` objects are freed only after the audio thread has finished every
mix step that could have read them. Concretely: the audio thread increments an atomic `mix_step_epoch`
after each `_mix_step`; the main thread stamps each retired detail with the epoch at retirement, and the
graveyard frees it only once `mix_step_epoch` has moved past that stamp (today the graveyard counts main
frames, which is unrelated to mixing). The alternative, taking the audio lock around the swap in
`set_playback_bus_volumes_linear` and the 3D player's per-tick update, is simpler but adds lock contention
on the main thread. First check the upstream Godot 4.x history for an equivalent fix and prefer
cherry-picking it. Ship it as a custom export template build (same version string with a local patch
suffix in the build metadata), not as an engine upgrade.

**Runtime compatibility.** The OTA pack carries only game content; the engine lives in the APK. A patched
engine is a native change: a new runtime revision (r6 or later, `scripts/boot/ota_config.gd`
`RUNTIME_REVISION`, `ota/runtime_lock.json`), so installed phones on r5 would need the new APK before they
receive OTAs built for it. Plan it with the owner together with the r6 decision (the earlier r6 was rolled
back on 2026-10-11 so build 22 phones keep OTAs): either hold OTAs for r5 phones on a final r5 revision, or
keep publishing r5-compatible packs until testers have installed the new APK. Saves are unaffected (no
save schema change).

**Android rebuild requirements.** Custom Android export templates built from the patched source
(`scons platform=android target=template_release arch=arm64`, plus the Gradle build template), the same
package `com.verbal76.axolotl` and the existing signing key (installs over the current app, saves kept), a
new `versionCode`, the native-freeze files updated in one owner-approved commit, the runtime lock
regenerated with `tools/ota_runtime.py`, and the APK built by Build & Verify on request. Desktop templates
(Windows, Linux) need the same patch so every platform shares one engine.

**Regression risks.** Audio-thread timing (dropouts or added latency if the fix locks), leaks if retired
details are never freed (e.g. when the audio thread is stalled while paused or backgrounded on Android),
music crossfades and 3D attenuation, bus routing, OTA bootstrap behaviour on the new runtime, and export
template differences (shader baking, PCK compatibility).

**Validation.** Locally: the full unit shards and playthrough repeated (row 37's historical rate was about
6 crashes in 171 runs, so at least ~300 clean unthrottled runs give useful confidence), plus
`race_probe.gd.txt` under CPU contention, plus a memory check that retired details are freed. On physical
devices: the owner's Pixel and at least one other Android phone (install over the r5 app, saves kept,
long play sessions with music, 3D creature audio, travel fades, pause/resume and app backgrounding, an OTA
applied on the new runtime); a Windows PC and a Steam Deck once desktop builds use the patched templates.

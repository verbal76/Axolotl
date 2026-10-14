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

## Status (2026-10-13, second pass): eliminated in Mote's game layer; engine fix prepared (needs a native build)

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

## 2026-10-13: game-side safeguard (OTA-compatible), still not a fix

**Mechanism, traced in the code paths.** The use-after-free needs a retired `AudioStreamPlaybackBusDetails`
that the audio thread is still reading. Game code can create retirements in three ways: a `volume_db` write on
a playing player (already reduced to audible steps, row 37), `stop()`/`play()` of a player, and simply having
an `AudioStreamPlayer3D` playing: Godot 4.7.2 recomputes its panning and swaps its bus details on every
physics tick where the mix advanced, whether or not it can be heard. The last is by far the largest.

**Measured exposure** (`_phase_audio_probe`, each ball's start): 14-15 looping 3D players playing (8 bubblers,
6 vortex rushes, the tank's own bubbler among them), and 12-15 of them beyond their own `max_distance`,
i.e. silent. That is roughly 800 silent bus-details swaps a second for at most two audible sources.
**(Correction, second pass: wrong. The 4.7.2 source skips the swap once a 3D player has been out of
earshot for two frames (`audio_stream_player_3d.cpp`, `skip_setting_volumes`), so those silent players
were not swapping. The range gate saved mixing work, not race exposure.)**

**Safeguard.** `AudioDirector.want_loop()` and a range gate (every 0.2 s): a looping 3D source plays only
while the listener is within its `max_distance` plus a margin. It starts 6 m before its audible edge (still
silent there, so nothing is heard starting) and stops 12 m past it (hysteresis). Owners (vortex rush,
gate and column bubblers, the tank bubbler) say whether they want to play; the gate decides when. Pausing
was not used: Godot keeps updating panning for a paused 3D player. After: 1-2 looping 3D players playing per
ball, all within earshot; what is heard is unchanged. One-shot sound effects are untouched.

**Lifecycle hardening (same pass).** `Sfx.play` does nothing before the pool exists or after it left the
tree (`Sfx.ready_to_play`); `Sfx` and `Juice` clear their static instance on exit; the bus setup is
idempotent (each bus and effect created only if missing), so repeated startup or an interrupted earlier
setup never duplicates buses. Backgrounding: no game audio work runs while the app is paused (the engine
stops its driver); a long resume step only settles the ambience glide. Tests: `_test_audio_lifecycle`
(initialization order, repeated startup and rapid transitions, use before init and after disposal, a long
resume step, the range gate following the listener).

**Reproduction, corrected.** The probe kept here until 2026-10-12 called `play()` in `_init`, before its
players were in the tree; Godot refuses that ("Playback can only happen when a node is inside the scene
tree"), so it never played anything and its "survived 240 s" results were not evidence. The corrected
`race_probe.gd.txt` starts playback on the first frame. 2026-10-13, four processes for 900 s each under CPU
contention (two with 128 moving 3D players, two rewriting `volume_db` on 64 players every frame): all
survived with every player still playing. The race remains **not reproduced**; its frames match row 37's
exactly, so the classification stands.

**Status.** The engine race is still possible: audible 3D sources, one-shot effects, music and ambience still
mix through the same engine path. This lowers the exposure the game itself creates; it is not a fix and
must not be described as one. The engine-side recommendation above is unchanged.

## 2026-10-13, second pass: root cause from the source, eliminated in the game layer, engine patch

**Source evidence (Godot 4.7.2-stable, `servers/audio/audio_server.{h,cpp}`).**

| Question | Answer |
|---|---|
| Who creates the routing data | Main thread: `start_playback_stream` and `set_playback_bus_volumes_linear` (`new AudioStreamPlaybackBusDetails`). |
| Who reads it | Audio thread, `_mix_step()`: `playback->bus_details.load()` then a struct copy (line 452), which copies `StringName`s (crash frame [2]). Under the driver mutex. |
| Who replaces it | Main thread: atomic compare-and-swap in `set_playback_bus_volumes_linear`; the old pointer goes into `bus_details_graveyard`. Reached from `AudioStreamPlayer.set_volume_db`/`set_bus` on a playing player and from every playing `AudioStreamPlayer3D` within earshot on each physics tick (`_update_panning`). |
| Who frees it | Main thread: `AudioServer::update()` -> `_cleanup_lists()` deletes it two `update()` calls later. |
| Deferred destruction / refcounting | Deferred by main-thread frames only; no reference counting. The `SafeList` deferral guards iterators of the graveyard list itself, which the audio thread never touches ("TODO document if this is necessary"). |
| Missing synchronisation | `_cleanup_lists()` takes no lock and does not look at the audio thread's progress: the two-frame delay is a timing assumption. A mix step preempted between load and copy for two main frames reads freed memory. |
| Playback deletion, stop, pause, pitch | Safe: playback nodes are freed through `playback_list`'s `SafeList`, which the audio thread iterates; state, pitch and filter values are atomics. |
| Shutdown / background | Same path; no extra exposure (no `update()` runs while the app is paused). |
| Known upstream | Yes: godotengine/godot#124217 (opened 2026-10-06, against 4.7.2, open, no fix PR); a second report there hit it on Linux with the release template. |

Also unsynchronised in 4.7.2: `AudioServer::add_bus` (resizes the bus list with no lock) and the
`mix_count` counter.

**Game-layer elimination (OTA-compatible).** Mote never lets the engine replace a playing sound's routing data:
- no `AudioStreamPlayer3D`: every positional sound is a `SpatialEmitter` played through a `SpatialAudio`
  voice: a plain `AudioStreamPlayer` on a voice bus of its own whose player volume and bus are set only
  while it is stopped; the engine's own 3D model (inverse-distance attenuation, `max_db`, the
  `max_distance` fade, stereo panning at the project's strength, the distance high-shelf) is applied
  each frame to the voice bus (volume, `AudioEffectPanner`, `AudioEffectHighShelfFilter`): plain values
  the audio thread reads, nothing allocated or freed;
- levels that change while playing (the ambience bed, the life layer, the travel whoosh) are bus volumes;
- buses are created once, under `AudioServer.lock()`, and their sends never change.

Sound is unchanged: captured from the mix side by side with a real `AudioStreamPlayer3D` at six positions
and two tones (one above the shelf), left and right levels match to 0.00 dB (`_phase_spatial_match`).
Remaining difference: a bus volume steps between mix blocks where the engine ramps a 3D player's gain
within a block (under 0.2 dB per frame at this game's speeds).

Guarded by `audio_never_replaces_routing_data` (no `AudioStreamPlayer3D`/`2D` or `set_playback_*` in game
code or in the running tree, every `volume_db`/`bus` write reviewed, bus layout changes only under the
lock) and `audio_playing_players_never_rewritten` (live: through seconds of play, no playing player's
volume or bus changes).

**Verification (ThreadSanitizer, `tsan/README.md`).** Stock engine + the old usage: the race reported at
the crash's exact frames. Stock engine + Mote's voices (also under repeated teardown and pause/resume):
no bus-details race. Patched engine + the old usage: no reports at all.

**Engine patch (prepared, not shipped: a native change).** `tsan/godot-4.7.2-audio-bus-details-uaf.patch`
(audio_server.h/.cpp, ~40 lines): an atomic count of finished mix steps; a replaced bus-details block is
freed only once every mix step that had started when it was retired has finished (no lock, no
allocation on the audio thread; `mix_count` made atomic too). It is the fix proposed on #124217.
- Compatibility: engine-internal; no API, file format or save change.
- Native rebuild: custom export templates (Android arm64 debug/release, Linux, Windows) from 4.7.2 +
  the patch; a new APK and runtime revision (r6+), because the engine lives in the APK, not the OTA pack.
- OTA consequences: installed r5 phones keep the unpatched engine; with the game-layer change above they
  no longer trigger the race, so the native fix is defence in depth, not a precondition for an OTA.
- Regression risk: low (the freeing rule only gets stricter; at worst a few blocks live a frame longer);
  watch memory if the audio thread ever stalls for long (retired blocks wait for it).
- Validation: the TSan runs above on the patched build; then the full suites and playthrough on the
  patched templates, and the device checklist (docs/DEVICE_CHECKLIST.md) on the new APK.

# ThreadSanitizer evidence for the 4.7.2 audio routing-data race (2026-10-13)

Godot 4.7.2-stable (ed1daf0) built locally as `template_debug` with `use_tsan=yes` (gcc 13, headless,
GDScript and the fallback text server only; the symbol table kept for the reports). The probe project is
`project.godot.txt`, `main.tscn.txt`, `drive_node.gd.txt` (rename to drop `.txt`) plus Mote's own
`scripts/core/spatial_audio.gd` and `spatial_emitter.gd`, byte-identical to the game's. Each run is
90 s, 24 sources, a listener orbiting fast, sources moving every frame, random stops and restarts, and
4 non-positional loops.

| Run | Engine | Usage | Reports | What they are |
|---|---|---|---|---|
| `stock-engine_stock-usage.txt` | stock 4.7.2 | AudioStreamPlayer3D + volume_db writes on playing players (what Mote did before) | 3 | **The crash's race**: `AudioServer::_cleanup_lists()` frees bus details (`operator delete`, `StringName::unref`) while `AudioServer::_mix_step()` copies them (`StringName::StringName(const&)`); allocated by `set_playback_bus_volumes_linear` from `AudioStreamPlayer3D::_update_panning()`. Plus the unsynchronised `mix_count` read. |
| `stock-engine_mote-voices.txt` | stock 4.7.2 | Mote's SpatialAudio voices, levels on bus volumes | 1 | No bus-details race. Only a debug-build profiling counter (`Bus::Effect::prof_time`, reset by `update()`, added to by `_mix_step()`): a plain integer, nothing freed. |
| `stock-engine_mote-voices-churn.txt` | stock 4.7.2 | the voices, plus the whole voice system freed and remade every 1.5 s and the tree paused/resumed every 0.4 s | 2 | The same profiling counter only. |
| `patched-engine_stock-usage.txt` | 4.7.2 + `godot-4.7.2-audio-bus-details-uaf.patch` | the old usage | **0** | The patch removes the race for any game. |
| `patched-engine_mote-voices.txt` | patched | Mote's voices | 2 | The profiling counter only. |

ThreadSanitizer reports a race when two accesses are not ordered by synchronisation, whether or not the
timing went wrong in that run, so a clean result here is not luck. (A crash needed the audio thread to
be preempted between loading the pointer and copying it; a sanitizer does not.)

The profiling-counter race exists in every debug-template build whose buses have effects (Mote's Music
bus has had a low-pass since 2026-09); shipped APKs are debug exports. It can only make profiler numbers
wrong. It is not the crash and is not addressed here.

Reproduce: `python3 apply_patch.py.txt <godot-src>` (patched run only), build with
`scons platform=linuxbsd target=template_debug use_tsan=yes vulkan=no opengl3=no x11=no wayland=no
modules_enabled_by_default=no module_gdscript_enabled=yes module_text_server_fb_enabled=yes` (keep the
symbol table), export the probe with `--export-pack Linux <binary>.pck` next to the binary, run
`TSAN_OPTIONS=log_path=out <binary> --headless --max-fps 0 -- mode=stock|voices|churn secs=90`.

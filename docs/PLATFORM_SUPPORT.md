# Platform support (2026-10-12)

One codebase (Godot 4.7.2, GDScript, Mobile renderer on Vulkan) for every platform; platforms differ
only in export configuration. Gameplay, saves, assets and tests are shared.

| Platform | Configured | Built | Packaged | Evidence | Physically tested |
|---|---|---|---|---|---|
| Android (arm64) | `export_presets.cfg` "Android" (runtime r5, build 22 native layer; signing via CI secrets) | Build & Verify (CI); latest APK build 132 | `apk-v0.1.0-b132` release; numbered builds: "Mote Build NN APK.apk" | APK SHA-256 5acd013b...6cc4, source 0479663 | Owner's and testers' phones (build 22 / 128 era) |
| Windows x86-64 | preset added at export by `tools/build.py` (the committed file is the Android runtime lock) | locally 2026-10-12 (template `windows_release_x86_64`) | "Mote Build NN EXE.zip" (Mote.exe, PE32+ x86-64, PCK embedded) | local package, verified manifest | **No** (no Windows machine or Wine here) |
| Linux x86-64 (Steam Deck / Steam Machine) | same, `linux_release.x86_64` | locally 2026-10-12 | "Mote Build NN Linux.tar.gz" (Mote.x86_64, mode 755) | local package started, rendered and quit cleanly (xvfb, software Vulkan) | **No** physical Deck yet |

Platform adapters in the shared code:
- **Input**: touch (phones) / controller (`PadNav`, `OnScreenKeyboard`) / keyboard; detection in
  `Settings` (`input_mode`, `last_device`), prompts in `Glyphs`.
- **Updates**: Android only (signed OTA packs, `scripts/boot`, `docs/OTA.md`); desktop builds have no
  OTA client and will be updated by Steam (SteamPipe).
- **Window**: phones landscape (project settings); desktop starts fullscreen (`Settings.apply_window`;
  F11 or Alt+Enter switches, kept per device; `--windowed` on the command line keeps a window).
- **Paths**: `user://` (Godot's per-platform user data directory).

Not available yet (need a Steam App ID / Steamworks): Steam Input action manifest and API glyphs,
Steam's gamepad text input, Steam Cloud. Details and the Valve checklist: `docs/STEAM_DECK.md`.

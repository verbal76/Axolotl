# Mote Build 138: cross-platform release candidate (2026-10-14)

Owner directive "Master cross-platform release candidate" (2026-10-14). Owner authorised the release-branch
fast-forward 54f4070 -> c005561 and a GitHub **prerelease** "Mote Build 138" (not Latest). No OTA was
published; nothing was submitted to Steam or Google Play; `main` (f3779f7) is untouched; earlier releases
and OTAs are unchanged.

## Source

| Item | Value |
|---|---|
| Source SHA | `c0055616355d746377228707b068a25c29c42584` (release branch `claude/mote-game-continuation-bov2x9`, fast-forward from `54f4070`) |
| Game content | identical to `dcaea10` (later commits change only `tools/ota_e2e_local.sh` and docs) |
| Engine | Godot 4.7.2 stable templates (no engine patch) |
| Android native runtime | r5, build 22 native layer, unchanged (`ota_runtime.py --check`: OTA-compatible); existing signing key (certificate pin `A8:4F:BA:D5:...:E2:C2:E3`) |
| Latest published OTA | `dev-000111` (Mote v111-polish-pass-r5). Build 138 bundles the c005561 game, which is newer than dev-000111; no `dev-000112` exists |
| Build number | 138 (= the APK's Android build / Build & Verify run 138) |
| Desktop export | `tools/build.py` presets (Mobile renderer, Vulkan, PCK embedded); Windows resources 0.1.0.138, Hot Attic Games |

## Audio-crash safety (the r5 workaround is in all three builds)

The game layer never asks Godot 4.7.2 to replace a playing sound's routing data (no AudioStreamPlayer3D;
no volume or bus writes on playing players; fixed voice buses created once under `AudioServer.lock()`).
Evidence (automated, on `dcaea10`, re-run on `c005561` by Build & Verify 138): `audio_never_replaces_routing_data`,
`audio_playing_players_never_rewritten`, `_test_audio_lifecycle`, `_phase_spatial_match` (0.00 dB vs the
engine's 3D model), ThreadSanitizer runs (docs/research/crash-2026-10-12/tsan/). The engine defect itself
remains in stock 4.7.2 (Android r5 and the desktop templates); the patch is prepared, not applied.
**Not hardware-verified** until the device checks below are done.

## Steam Deck minimum-compatibility matrix

PASS = shown by an automated test or a check on this build; NOT TESTED = needs the Deck; BLOCKED = needs
something not available (Steam App ID). Nothing here is a Valve "Verified" claim.

| # | Requirement | Status | Evidence |
|---|---|---|---|
| A1 | All menus and pages reachable by controller only (title, Continue, New Run, players, settings, colours, skills, field guide, about, aquarium) | PASS (automated) | `deck_every_page_reachable_by_controller` |
| A2 | Gameplay by controller (move, look, jump, Water Burst, lunge, skills, pause, whole-ball view) | PASS (automated input map) / NOT TESTED on Deck | input map + playthrough bot |
| A3 | B never quits from the title; B is Lunge in play | PASS (automated) | `deck_b_on_title_never_quits`, `deck_b_in_play_is_lunge` |
| A4 | Pause, resume, return to title, quit by controller | PASS (automated) / NOT TESTED on Deck | `deck_every_page_reachable_by_controller` |
| A5 | Visible focus, no focus traps | PASS (automated) / NOT TESTED on Deck | PadNav tests |
| B1 | 1280x800 native, UI 1:1, extra height used (no stretch) | PASS (automated render) / NOT TESTED on Deck | `--test=shots --only=deck --resolution 1280x800`; base 1280x720 `expand` |
| B2 | 1280x720 | PASS (automated) | `pause_fits_fullest_state` (720p), settings fit |
| B3 | Text >= 9 px at 1280x800 (12 px recommended) | PASS (automated): smallest 13 px | `deck_text_at_least_12px` |
| B4 | Handheld readability | NOT TESTED | needs the Deck |
| C1 | Built-in controller recognised; Deck glyphs | PASS (automated: `SteamDeck=1` selects Deck glyphs) / NOT TESTED on Deck | `deck_glyph_families`, `deck_glyphs_follow_input_map` |
| C2 | Controller text entry (player names) | PASS (automated) | `deck_controller_keyboard_types_a_name` (built-in keyboard; Steam's keyboard needs Steamworks) |
| C3 | Mouse/keyboard coexist; trackpad movement does not flip prompts | PASS (automated) | `glyph_library_art_and_switching` |
| C4 | Controller reconnect | NOT TESTED | needs hardware |
| C5 | Steam Input action manifest / API glyphs | BLOCKED | needs Steam App ID + Steamworks |
| D1-D5 | Suspend/resume in play and menus; audio returns; no save loss | NOT TESTED on Deck | desktop pause/resume and audio lifecycle tests pass |
| E1-E9 | Performance (30 fps at 800p default, pacing, load, memory, thermals, extended play) | NOT TESTED | Linux build reached a usable title in a software-Vulkan container; no Deck measurement |
| F1 | Native Linux start, no launcher, no extra libraries | PASS | `Mote.x86_64` links only libc/libm/libdl/libpthread/librt; started, built the world, reached "title usable", quit cleanly (xvfb, llvmpipe Vulkan) |
| F2 | Executable permission in the package | PASS | tar mode 0755, verified by `build.py verify` |
| F3 | Case-sensitive paths | PASS | Linux export loads every resource with no load errors (smoke log: 0 script/parse errors) |
| F4 | Audio backend | NOT TESTED | container has no sound device (fell back to dummy); Deck uses PulseAudio/PipeWire through Godot |
| F5 | Offline single-player | PASS | desktop builds have no OTA client; game never needs the network |
| G1 | Local saves, settings persistence, restart | PASS (automated) | save tests (atomic writes, read-back), playthrough |
| G2 | Steam Cloud | BLOCKED | needs App ID; paths ready (docs/STEAM_CLOUD.md) |
| H1 | Default graphics suitable for Deck | PARTIAL: Mobile renderer, Vulkan, quality scaler; NOT TESTED on Deck | |
| H2 | Fullscreen by default, F11/Alt+Enter, kept per device | PASS (automated) | `Settings.apply_window` tests |

## Gameplay regression

Build & Verify run 138 re-ran both unit shards and the beginning-to-end playthrough on `c005561`. Earlier on
`dcaea10` (same game content): 1145 unsharded, 24/24 playthrough (all seven moss balls restored, 100%),
OTA end-to-end 49/49. Covered areas: movement and jumping (coyote time, jump buffer), Water Burst, lunge,
camera, parasites, health fronds, food and healing, blooms, caves, travel unlock, restoration, completion,
timer, saves, music. No gameplay code changed in this round.

## Steamworks readiness

| Item | Status |
|---|---|
| Steam App ID, partner account, Steam Direct fee (about US$100 per app, recoupable) and the waiting period after paying it | Owner: not started (no App ID). Check the current terms in the Steamworks partner site |
| Store page, Coming Soon page (Valve asks for it at least two weeks before release), store review, build review | Not started; needs App ID |
| Windows depot (`Mote.exe`) and Linux depot (`Mote.x86_64`), launch options | Packages ready; depots need App ID |
| Steam Input manifest, controller-support declaration ("Full controller support"), Deck compatibility review | Game side ready (above); declarations need App ID |
| Steam Cloud | Paths classified; Auto-Cloud setup needs App ID |
| System requirements | To be measured on the owner's Windows PCs and the Deck (do not publish guesses) |
| Supported languages | English only (all text is English) |
| Content survey, pricing, regional pricing | Owner decisions |
| Store text, screenshots, capsule and library art | Text drafts can come from the existing features; screenshots should be captured on real hardware; capsule and library art needs the owner's artwork (no new art direction) |

## Release blockers (commercial, not test blockers)

1. No Steam App ID (blocks depots, Steam Input, Cloud, store pages).
2. Music rights: no provenance for the music files (docs/THIRD_PARTY_ASSETS.md); owner must confirm.
3. Glyph library licence (CC0, Input Prompts by Julio Cacko): recorded; the owner should confirm the live listing once.
4. Physical-device results (Android crash recheck, Windows launch, Deck performance and suspend/resume).
5. Store artwork (capsules, library) and real screenshots.

Nonblocker noted: desktop saves live under Godot's default folder (`%APPDATA%\Godot\app_userdata\Mote`,
`~/.local/share/godot/app_userdata/Mote`). Changing it would touch the frozen `project.godot` and move
existing saves; left as is.

## Owner test instructions

**Android (Pixel 10 Pro XL):** download `Mote Build 138 APK.apk`, install over the existing app (saves are
kept; same signing key). Settings > About should show build 138 and runtime r5. The APK contains the c005561
game, which is newer than the published `dev-000111`. Run docs/DEVICE_CHECKLIST.md A1-A12 (most important:
A3 positional sound, A5 15 minutes of play, A6/A7 background and lock screen, A11 return to title / new run).

**Windows (desktop and laptop):** download `Mote Build 138 EXE.zip`, extract the whole folder, run
`Mote Build 138\Mote.exe` (SmartScreen may warn about an unsigned app: More info > Run anyway). It starts
fullscreen; F11 or Alt+Enter toggles windowed. Test keyboard and mouse, then a controller; sound;
quit and relaunch to check Continue. Saves: `%APPDATA%\Godot\app_userdata\Mote\`.

**Steam Deck:** in Desktop Mode download `Mote Build 138 Linux.tar.gz`, right-click > Extract here (or
`tar -xzf "Mote Build 138 Linux.tar.gz"`). In the folder `Mote Build 138`, the executable is
`Mote.x86_64` (already executable; if not: Properties > Permissions > Is executable, or
`chmod +x Mote.x86_64`). Steam > Games > Add a Non-Steam Game to My Library > Browse > `Mote.x86_64`.
Return to Gaming Mode, launch Mote from the library (Non-Steam). Test controller-only navigation, gameplay,
suspend (power button) and resume in play and in a menu, sound after resume, and note the frame rate
(Performance overlay level 1-2) over 15 minutes.

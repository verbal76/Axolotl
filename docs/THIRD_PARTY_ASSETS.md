# Third-party and supplied assets (inventory, 2026-10-12)

What ships in Mote, where it came from, and the licence evidence actually held. The player-facing
notices (About > Licences, and `THIRD_PARTY_NOTICES.txt` next to desktop builds) are generated from
the running engine plus `Credits.ASSETS` (`scripts/core/credits.gd`), so they always match the build.

| Asset | Files | Origin | Licence | Evidence | Status |
|---|---|---|---|---|---|
| Godot Engine 4.7.2 (runtime, export templates) | the engine in every build | godotengine.org | MIT (Expat) | `Engine.get_license_text()` in the build | Verified; notice shipped in game and desktop packages |
| Godot's bundled third-party components (102: FreeType, HarfBuzz, ICU, libpng, Vorbis, Jolt, Mbed TLS, fonts such as Open Sans / Noto Sans / DroidSans, ...) | inside the engine | upstream projects | Expat, BSD, Apache-2.0, OFL-1.1, Zlib, FTL, MPL-2.0, ... (per component) | `Engine.get_copyright_info()` / `get_license_info()` | Verified; full texts shipped (About > Licences) |
| Controller button prompts, "Input Prompts" pack by Julio Cacko (JulioCacko) | `assets/glyphs/**` (imported subset); original archive `Source.zip`, sha256 `f6c75921b9d6ab2cb2b5249f547c7b7ba19e22da9f4f3b45693cf0912f25ded0` (1633 files, no licence file inside) | owner-supplied studio library (itch.io / FAB listing) | CC0 1.0 Universal (asset licence); listing also says MIT code licence | owner's screenshot of the itch.io listing, 2026-10-12: "License: CC0 1.0 Universal. Free to use in any project, commercial or non-commercial. No attribution required" | **Identified, not independently verified**: confirm on the live listing before commercial release (standard §13) |
| Hot Attic Games studio logo | `Hot_Attic_Games_Master_Logo_ALPHA_FINAL.png` | owner-supplied (studio's own) | studio property | owner directive 2026-10-04 (CLAUDE.md) | Owner asset |
| Mote launcher icon artwork | `assets/icon/*` (cropped by `tools/make_icons.gd`) | owner-supplied artwork | studio property (owner) | commit 3d906a9 ("from the owner's artwork") | Owner asset; rights held by owner (not independently checked) |
| Settings gear | `assets/ui/settings_gear.png` | owner-supplied artwork | studio property (owner) | `docs/AQUARIUM.md` ("the owner's artwork") | Owner asset; rights held by owner (not independently checked) |
| Music: *Aquarium Whimsy*, *Bubbly Underworld* | `assets/audio/music_*.ogg` | owner-supplied songs | owner's | ledger M-01 ("the owner's two songs") | **Owner to confirm commercial rights** (how they were made or licensed is not recorded) |
| Sound effects and ambience | `assets/audio/{sfx,amb,out}_*.wav` (69) | generated in-house by `tools/gen_audio.py` (deterministic synthesis) | studio's own | every file is named in the generator | Verified (generated) |
| Textures | `assets/textures/*` | generated in-house (`tools/gen_textures.py`, `gen_gravel.py`, `gen_room.py`) | studio's own | generators in `tools/` | Verified (generated) |
| 3D models, creatures, world | built in code (`scripts/`, `shaders/`) | studio's own | studio's own | no imported model files | Verified |

No fonts are imported: the UI uses Godot's built-in default font (covered by the engine's notices).

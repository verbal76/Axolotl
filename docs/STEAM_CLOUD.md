# Steam Cloud preparation (2026-10-12; activation waits for a Steam App ID)

Steam Cloud is **not active**: it needs an App ID and Steamworks (Steam Auto-Cloud can then be set up in
the partner site with the paths below, without code). No save is migrated and no schema is changed by
this preparation. What the game writes, under Godot's `user://` (Linux / Steam Deck:
`~/.local/share/godot/app_userdata/Mote/`; Windows: `%APPDATA%\Godot\app_userdata\Mote\`):

| File | Holds | Class | Sync with Steam Cloud? |
|---|---|---|---|
| `run.json` | the main player's current run (atomic write, read-back check) | progress | yes |
| `gill_progress.json` | the main player's lifetime progress: Skills, starfish (atomic) | progress | yes |
| `players.json` | who plays: names, ids (atomic, `.bak` kept) | progress | yes |
| `players/<id>/` | each other player's run, progress and colours (`look.cfg`) | progress | yes |
| `settings.cfg` | device settings (volumes, HUD, haptics, controls, prompts, fullscreen, tutorials) **and** the main player's colours (`[gill]`) and save identity (`[meta]`) | mixed | not as is (see below) |
| `gill_pattern.png` | a cache of the drawn skin pattern (rebuilt from the colours) | cache | no |
| `ota/`, `ota_autoupdate.json` | the Android OTA client's state and packs (desktop builds have none) | device | no |
| `shader_cache/` etc. | engine caches | device | no |

**The one mixed file:** `settings.cfg` carries the main player's colours, which are progress, beside
device settings (studio standard §11: graphics and device settings must not sync). Options for when
Steam Cloud is turned on, without migrating anything now: (a) sync `settings.cfg` only for its `[gill]`
section by moving the main player's colours to `players/main/look.cfg` the way other players' colours
already live (a save change that needs the owner); or (b) leave `settings.cfg` out of the cloud and accept
that the main player's colours do not follow them between devices. Recommendation: (a), done with Steamworks.

Conflicts and offline: every progress file is written atomically and read back, so the cloud only ever
sees whole files; Steam's own conflict dialog (newer vs. older) is the expected behaviour for a
single-player game, and the game already plays fully offline.

Guard: unit test `save_files_classified` fails when game code starts writing a `user://` path that is not
in this table, so a new save file cannot slip past this decision.

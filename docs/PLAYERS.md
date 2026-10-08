# Player profiles (owner, 2026-10-08)

"I want to give my phone to my daughter. I don't want her to scrap my run, but she can save her own
character on there. But all the characters are still called Gill."

- **Who's playing?** The title's player button (beside the gear) opens the page: tap a name to play
  as them (create / select / resume), Rename, New player (asks for a name, up to 6 players, names up
  to 16 characters). No deleting in this pass (owner scope, 2026-10-08).
- **Per player:** the run (completion, best finishes, Treasure Hunt, Hard Mode, lessons), the Red
  Starfish and Skills, and Gill's colours and pattern. **Shared:** sound, haptics, HUD, tutorials,
  controls (device settings).
- **Storage (rollback-safe):** the registry is `user://players.json`. The first player is the
  original save, untouched and unmoved (`run.json`, `gill_progress.json`, the colours in
  `settings.cfg`, `gill_pattern.png`), so an older build still plays it. Other players live in
  `user://players/<id>/` (run.json, gill_progress.json, look.cfg, gill_pattern.png). While another
  player plays, `settings.cfg` keeps the first player's colours unchanged. The list keeps a `.bak`;
  with both copies damaged, every player's folder is still found (names fall back to "Player N").
- Switching saves the current run (and switches only once that save is confirmed), puts on the chosen player's colours and comes back up on the
  title with their run (`Game.switch_player`). Automated runs are always the first player.
- Code: `scripts/core/players.gd`, `scripts/ui/players_page.gd`. Tests: `players_*`, `title_*` in
  `_test_owner_menus_and_players`; `_test_profiles_ab` plays two players end to end in real game
  processes sharing one user:// (the original save byte-for-byte unchanged when profiles appear).

Also from the same owner message: About's Advanced button removed (the installed app's recovery
panel still opens with five quick taps in the top-left corner, or by itself when a launch fails);
About's Close is "‹ Back"; "Save & Return to Title" (leaves only once the save is confirmed; a
failed save stays and says "Not saved: try again"); "Replay tutorial (keeps run)" in Settings during a run
(`Onboarding.replay`: only the lesson record is re-armed; run, progress, Skills and health untouched); the whole-ball button top left (BallView: play stands still, drag to turn the
ball, the same button returns; kept clear of the recovery corner), and no Whole ball button in the
pause menu.

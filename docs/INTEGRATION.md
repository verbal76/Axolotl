# Integrating `claude/mote-release-source` into the release branch (owner-approved 2026-10-12)

Approved conditionally by the owner on 2026-10-12 ("MOTE — FINAL OTA SAFETY CORRECTION AND CONTROLLED
INTEGRATION"): integrate once every safety check passes; integration is **not** permission to publish.

## Conditions checked before the push

- Release branch head before integration: `a3c989d`. The working branch contains it (0 release commits
  missing), so the release branch is **fast-forwarded**; no merge commit, no conflicts.
- Native layer unchanged (`project.godot`, `export_presets.cfg`, `scripts/boot/*`, `ota/runtime_lock.json`
  identical; `tools/ota_runtime.py --check`: r5, OTA-compatible). No save schema or save path changed;
  `settings.cfg` gains two keys (`controls/prompt_style`, `display/fullscreen`) that older games ignore;
  the r5 bootstrap reads only its `[meta] save_schema`, which is unchanged (and the file is now replaced
  atomically, never half-written). No gameplay change.
- **No OTA and no native release can start.** GitHub reads a push's workflow definitions from the pushed
  head. At this head `ota-publish.yml` starts only by hand (`release_guard.py entry-points`: manual
  dispatch only); `apk-release.yml` and `build-release.yml` start only on their request files, which this
  push does not touch. `python3 tools/release_guard.py triggers --from a3c989d --to <head>` reports
  "starts: nothing".
- The full local gate passed on the exact head that was pushed (results below).

## The one trap (why it is a single push)

Every commit before `ebdcae8` on the working branch carries the old rule (any game-file push to the release
branch publishes), and the commits from `ebdcae8` up to the dispatch-only change still start an OTA on a
request-file push. So integration is **one push whose head is the final, corrected commit**. Never push an
intermediate commit of the working branch, or cherry-pick parts of it, to the release branch.

## Procedure (as run)

1. `git fetch origin claude/mote-game-continuation-bov2x9`;
   `git rev-list --count HEAD..origin/claude/mote-game-continuation-bov2x9` must be 0 (otherwise merge the
   release branch into the working branch, re-run the local gate, re-check).
2. `python3 tools/release_guard.py triggers --from origin/claude/mote-game-continuation-bov2x9 --to HEAD`
   must print `starts: nothing`; `python3 tools/release_guard.py entry-points --rev HEAD` must print
   `manual dispatch only`.
3. One fast-forward push, no force: `git push origin HEAD:claude/mote-game-continuation-bov2x9`.
4. Afterwards: the remote head equals the tested SHA; the workflows at that head are the corrected ones;
   no OTA, APK or numbered-build run started. (Build & Verify runs only on pull requests and `main`: it
   tests PR #2's new head, tests only.)

## Result (2026-10-12, 19:16 EDT)

- Release branch `claude/mote-game-continuation-bov2x9`: `a3c989d` -> `d5580fd` (fast-forward, one push, no
  force; `main` untouched at `f3779f7`). This record is a later docs-only commit on top (`[skip ci]`).
- Local gate on `d5580fd` (exact SHA, clean tree): unit shard 1/2 541 passed, 0 failed; shard 2/2 597
  passed, 0 failed (1138, none skipped); playthrough 24/24 (all 7 balls restored); check_scripts 0 parse
  errors; version drift passed; runtime r5 OTA-compatible; `release_guard` lint, self-test (52 cases) and
  entry-points ("manual dispatch only"); `ota_request` self-test (23 cases); actionlint clean;
  `triggers a3c989d..d5580fd`: "starts: nothing".
- Actions after the push: only Build & Verify run 137 (`pull_request` on PR #2, tests; no Android job:
  no native change). No push-event run, no OTA, APK, numbered build or release. Channel pointer still
  `dev-000111`; latest OTA tag `ota-dev-000111`.
- Known, pre-existing (not introduced here): the unit suite run **unsharded** (`--test=unit` without
  `--shard`, not a gate; CI and the release gate always shard) fails 6 order-dependent checks
  (`tunnel_card_waits_for_a_menu`, `tunnel_card_before_the_shot`, `tunnel_one_shot_for_both`,
  `guide_owed_card_once`, `pause_ball_line_fits_landscape_no_scroll`, `parasite_small_found`) on both
  `d5580fd` and the previous release head `a3c989d` (1109 passed, 6 failed there). In that state the
  pause panel overflows 720p (732 px at `a3c989d`, 741 px at `d5580fd`: the Button prompts row is 9 px
  taller than the launch line it replaced); sharded, it fits (696 px). Worth a follow-up; not fixed here.

Rollback: the release branch's previous head is `a3c989d`; reverting is a new commit (CLAUDE.md), never a
force-push.

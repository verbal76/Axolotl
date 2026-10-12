# Integrating `claude/mote-release-source` into the release branch (for owner approval; not done)

Checked on 2026-10-12 against release head `a3c989d`:

- Authoritative: `claude/mote-game-continuation-bov2x9` (`.github/release-source.json`).
- The working branch contains the release head (0 release commits missing), so the release branch can
  be **fast-forwarded**; `git merge-tree` finds **no conflicts** either way.
- Native layer unchanged (`project.godot`, `export_presets.cfg`, `scripts/boot/*`, `ota/runtime_lock.json`
  identical; `tools/ota_runtime.py --check`: r5, OTA-compatible). No save schema or save path changed;
  `settings.cfg` gains two keys (`controls/prompt_style`, `display/fullscreen`) that older games ignore;
  the r5 bootstrap reads only its `[meta] save_schema`, which is unchanged (and the file is now replaced
  atomically, never half-written).
- **No OTA is published by the integration.** GitHub reads a push's workflow definitions from the pushed
  head; at this branch's head `ota-publish.yml` starts only on `.github/ota-publish-request.json`, which the
  branch does not contain. `python3 tools/release_guard.py triggers --from <release head> --to <new head>`
  reports "starts: nothing" for both a fast-forward and a `--no-ff` merge commit (simulated locally).
- Installed phones therefore stay on dev-000111 until an OTA is explicitly requested afterwards.

## The one trap

Every commit **before `ebdcae8`** on this branch still carries the old rule (any game-file push to the
release branch publishes). Integrate in **one push** whose head is this branch's head (or a merge commit
of it). Never push an intermediate commit of this branch, or cherry-pick parts of it, to the release
branch first.

## Procedure

1. Confirm nothing new landed on the release branch: `git fetch origin` and check
   `git rev-list --count HEAD..origin/claude/mote-game-continuation-bov2x9` is 0 (if not, merge the release
   branch into this branch first, re-run the local gate, re-check).
2. Check the push will start nothing:
   `python3 tools/release_guard.py triggers --from origin/claude/mote-game-continuation-bov2x9 --to <head>`
   must print `starts: nothing` (exit 0).
3. Integrate in one push, either:
   - fast-forward: `git push origin <head>:claude/mote-game-continuation-bov2x9`, or
   - a pull request from `claude/mote-release-source` to the release branch, merged with any merge method
     (merge, squash or rebase: each lands as one push whose head has the new workflows).
4. Expected Actions activity: no OTA, no APK release, no numbered build. Build & Verify runs the tests on
   PR #2 (release branch to `main`) for the new head (tests only; about three parallel jobs of 25-35 min),
   and on the integration PR if one is used.
5. Afterwards, when the owner wants it: publish the OTA by request (docs/OTA_PUBLISHING.md) for the new
   head (runtime `android-godot-4.7.2-r5`), and/or a numbered build (docs/RELEASES.md).

Rollback: the release branch's previous head is `a3c989d`; reverting is a new commit (CLAUDE.md), never a
force-push.

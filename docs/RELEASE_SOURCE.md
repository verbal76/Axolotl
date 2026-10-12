# Release source: one codebase, one branch, every platform (owner directive 2026-10-12)

Permanent policy ("Universal Engineering Directive"). The short form lives in `CLAUDE.md`; this file
holds the architecture, the enforcement and the branch ledger.

## Policy

1. **One authoritative codebase.** Every product build (phone OTA pack, playtester APK, desktop/Linux
   build, any later platform) is made from a commit on **one branch**, named in
   `.github/release-source.json` (today `claude/mote-game-continuation-bov2x9`). Changing it needs the
   owner's approval.
2. **Platform parity.** Platforms differ only by export configuration (presets, feature tags, native
   runtime), never by game code on another branch. A coordinated release builds every platform from
   the **same SHA**; each artifact carries a provenance record naming it.
3. **Branches are temporary.** Work happens on short-lived branches, lands on the authoritative branch,
   and only then can ship. `preserve/*` branches are recovery checkpoints, never release sources.
   No branch is deleted merely because it looks obsolete; the ledger below says what each one holds.
4. **No regressions by release.** A release must contain the source of every earlier release of its
   kind. Rolling back means a new commit that reverts, never publishing an older commit.
5. **OTA compatibility** is unchanged: `tools/ota_runtime.py --check` must print OTA-compatible, and
   the native freeze in `CLAUDE.md` stands.
6. **Repository boundary:** this repository only.

## Architecture

| Platform | Workflow | Started by | Source | Provenance shipped with it |
|---|---|---|---|---|
| Phone game (OTA pack, dev channel) | `ota-publish.yml` | manual dispatch only, from the release branch, by an allowed admin account (docs/OTA_PUBLISHING.md) | the resolved SHA (tests, pack and release all use it) | signed `manifest.json` (source SHA, runtime, version), release notes, run receipt |
| Playtester APK | `build.yml` builds; `apk-release.yml` publishes | native change or by hand; then `.github/apk-release-request.json` | the Build & Verify run's `build-info.json` `source_sha` | `build-info.json` (version, Android build, source SHA, runtime, APK sha256, run) |
| Numbered build: APK + Windows + Linux ("Mote Build NN") | `build-release.yml` (docs/RELEASES.md) | by hand, or `.github/build-release-request.json` | the requested SHA (the APK's build-info must name it) | `build-manifest.json` + `checksums.sha256` in the release; each desktop build's identity (build, source SHA, run) in About |

All three run on the same pinned Godot version (4.7.2). `provenance.json` comes from
`tools/release_guard.py provenance`: source SHA, branch, version, build, platform, config, engine,
native runtime, UTC timestamp, toolchain and the run URL.

A coordinated release (for example the phone OTA plus the Linux build of the same game) names the same
SHA in each workflow; each record says which SHA it was, so parity can be checked from the artifacts.

## Enforcement (CI, deterministic)

`tools/release_guard.py`:

- `check --sha S --contains-published GLOB`: runs **in every publishing workflow before anything is
  built or published**. It refuses S unless S is on the authoritative branch, and unless S contains the
  source of every earlier release whose tag matches GLOB (`ota-dev-*`, `apk-v*`, `desktop-*`). So an
  unmerged branch, an abandoned branch, or an outdated commit of the right branch cannot publish.
- `lint`: in the fast job of `tests.yml` (every PR, every release gate). It fails if a publishing
  workflow push-triggers any other branch or stops calling `check`, or if the workflows pin different
  Godot versions.
- `self-test`: proves `check` on a throwaway repository (tip and ancestor pass; side branch, unknown
  commit and an outdated commit fail).

Run locally: `python3 tools/release_guard.py lint && python3 tools/release_guard.py self-test`.

The old Expansions branch `claude/axolotl-aquarium-platformer-3y0qyy` was still a push trigger of
`ota-publish.yml`. It is 415 commits behind, so a push there would have shipped a September game as
the newest OTA. It was removed as a trigger on 2026-10-12; the branch itself is kept.

## Branch ledger (forensic audit 2026-10-12, read-only)

Method: `git fetch --all`; every local branch, remote branch, worktree HEAD and tag compared with the
candidate head `a3e908a` (release head `12bbf71`, then `1ed6d9f`, plus the Deck pass). Per ref: commits
not reachable (`rev-list`), patch-equivalence (`git cherry`), then file-level checks for anything left.
Totals: 65 local branches, 26 remote branches, 52 worktrees, 78 tags. **No legitimate work is missing
from the authoritative line.** Nothing was deleted, rewritten or restored.

### Authoritative and candidates

| Ref | SHA | State | Disposition |
|---|---|---|---|
| `claude/mote-game-continuation-bov2x9` (remote) | `1ed6d9f` | **Authoritative.** r5 polish pass (`0479663`) + republish request | Release source |
| `preserve/mote-deck-pass`, local `deck-pass` | `a3e908a` | Steam Deck pass on `12bbf71`; locally green (541 + 589 unit, 24/24 playthrough); unpublished | Release candidate; lands with the owner's go |
| `claude/mote-release-source` | this work | Deck pass + release head + this policy and guard | Working branch for this directive |
| local `claude/mote-game-continuation-bov2x9` | `a38c5f0` | stale local copy (169 behind the remote) | Fast-forwarded locally; never push from a stale copy |

### Work found outside the authoritative line, and where it went

| Ref | SHA | Unique commits | Classification | Evidence | Disposition |
|---|---|---|---|---|---|
| `claude/mote-menucam-wip`, `menucam` | `01ea6e3` | 5 (leech parasite gait, frame-pacing stats, startup findings) | Superseded | landed as `3b3cd92` Polish B (`frame_stats.gd`, leech parasites) and FINDINGS §13 | Keep; nothing to recover |
| `claude/mote-leaves-wip`, `leaves` | `5a71d34`, `b42d2e9` | 4–5 (pothos leaves) | Superseded | landed as `4c9fc8f` Leaves (dev OTA) | Keep; nothing to recover |
| `claude/mote-polish-a-wip`, `polish-a` | `a663fad`, `a813f4d` | 2–3 (thumb cluster, Exit, gear halo, Diagnostics) | Superseded | landed as `0442f6b` Polish A | Keep; nothing to recover |
| `claude/mote-autoresume-wip`, `autoresume` | `f6b6b75` | 1 (15 s resume window) | Superseded (patch-equivalent) | `RESUME_WINDOW_S` in `auto_update.gd`, FINDINGS §14 | Keep |
| `preserve/mote-prey-pass`, `prey-pass` | `1e5c02a` | 2 (test fixes) | Superseded (patch-equivalent) | `637664d`, `2f6e83e` | Keep |
| `titlepace` | `3f5c28b` | 1 | Superseded (patch-equivalent) | `git cherry` = 0 | Keep |
| `main` (remote) | `f3779f7` | 1 (studio logo upload) | Superseded | identical blob `e11f8c5` in the authoritative tree | Keep. `main` is the default branch and the target of PR #2; not merged here (not authorized) |
| `preserve/mote-audit-round`, `audit-round` | `55fe092` | 3 (thermal pass, video performance setting, freeze corrective) | **Intentionally rolled back** | shipped as v103, froze the owner's Pixel, rolled back by `23d90f4` | Keep; restore **only with owner approval** |
| `mote-starfish-loop` | `74ca5ca` | 1 (starfish gating loop) | **Abandoned by owner decision** | ledger row 17; owner closed gating ("keep simple loop") | Keep; do not restore |
| `claude/axolotl-aquarium-platformer-3y0qyy` | `43de9dd` | 0 (fully merged, 415 behind) | Stale publish trigger | was in `ota-publish.yml` push branches | Removed as a trigger; branch kept |

### Fully merged (0 unique commits; kept as history)

Remote: `claude/mote-treasure-retry-wip`, `preserve/mote-audit`, `preserve/mote-deadarea`, `preserve/mote-hag`,
`preserve/mote-int-{audit,hag,look,startup,testeff}`, `preserve/mote-look`, `preserve/mote-perf`,
`preserve/mote-splash`, `preserve/mote-startup`, `preserve/mote-testeff`, `preserve/mote-v108-pre-r6`,
`preserve/mote-visual-pass`.
Local: `int-*`, `juice-v107`, `v108`, `r6-apk`, `polish-pass`, `release-rb`, `startperf`, `visual-pass`,
`rel-{aqgill,autoupdate,onbrun,treasure,vortex}`, the `mote-*` feature branches, and the
`worktree-agent-*` branches. Every worktree HEAD (`.claude/worktrees/*`, scratch worktrees) is likewise
contained in the authoritative line.

### Releases and the native line

- `ota-dev-000001`…`000108`: r5 (build 22) era. `ota-dev-000109` (`81af996`) and `000110` (`606cf0f`):
  runtime r6, built for APK `apk-v0.1.0-b128`. The owner rolled the native layer back to r5 on
  2026-10-11 (`0479663`) so build-22 phones keep receiving OTAs; r6 phones show "native update
  required" for r5 packs until they install build 132 (r5).
- `ota-dev-000111` (r5 polish pass, source `1ed6d9f`) and `apk-v0.1.0-b132` (r5, source `0479663`, tag on
  `a3c989d`) were published on 2026-10-12 after the owner fixed release creation; GitHub refused a
  workflow-created tag on `0479663` itself, so APK releases tag the request commit (which contains
  the source).

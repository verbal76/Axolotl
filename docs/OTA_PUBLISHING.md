# Publishing an OTA (manual dispatch only, owner decisions 2026-10-12)

An OTA reaches every installed phone on its channel, so it is published only when the owner explicitly
starts it by hand. **The only entry point is Actions > *OTA publish (dev channel)* > Run workflow.**
`ota-publish.yml` has no other trigger: no push (of game files, a version change, a merge, or any file
named like a request), pull request, tag, schedule, release, other workflow (`workflow_run`,
`workflow_call`), `repository_dispatch` or native build can start it.

Enforced and tested:
- `release_guard.py lint` (CI fast job): `ota-publish.yml` is in `dispatch_only` in
  `.github/release-source.json`, so any trigger but `workflow_dispatch`, in any YAML spelling, fails.
- `release_guard.py entry-points`: simulates every event against the real workflow file; only the
  manual run starts it. `self-test` includes the regression that a push changing
  `.github/ota-publish-request.json` starts nothing, and that restoring the old push trigger is refused.

History: until 2026-10-12 every game-file push to the release branch published. A request-file push trigger
(`.github/ota-publish-request.json`) existed on the working branch on 2026-10-12 only; it was removed
before integration and never ran. There is no request file: the form is the request, and its record is
the run (inputs, actor, receipt).

OTA identity is separate from native build numbers (owner, 2026-10-12): an OTA is `dev-000NNN`
("Mote vNNN" on the phone), its own sequence on its channel; a native build is "Mote Build NN"
(docs/RELEASES.md). Neither advances the other. Every OTA's signed manifest names its revision (`ota_id`,
`seq`), exact `source_sha`, compatible `runtime_id`, `channel` and the pack's `pck_sha256` and size; About
shows them on the phone.

## How to publish

1. The commit is on the release branch and locally green (CLAUDE.md, docs/ACTIONS_BUDGET.md).
2. Find the next revision: `python3 tools/ota_request.py next-revision` (after `git fetch --tags`).
3. Actions > *OTA publish (dev channel)* > Run workflow, **from the release branch**
   (`claude/mote-game-continuation-bov2x9`), signed in as the owner, with:

   | field | value |
   |---|---|
   | source_sha | full 40-character SHA on the release branch |
   | runtime_id | `android-godot-4.7.2-r5` (the runtime that commit builds) |
   | channel | `dev` |
   | ota_revision | the exact next revision, e.g. `dev-000112` |
   | ota_name | optional, e.g. `polish-pass` (title "Mote v112-polish-pass") |
   | authorized_by | your GitHub login (must be the account running the workflow) |
   | reason | optional |
   | confirm | `PUBLISH` |

## What is checked (twice)

`tools/ota_request.py validate` runs in the **resolve** job and again, independently (permission read
again from the API), at the start of the **publish** job before anything is built or signed. It refuses
(and nothing is built) unless:

- **Authorization, from GitHub, not from the form:** the authenticated actor (`github.actor`) is the
  account that started this attempt (`github.triggering_actor`; a re-run by another account is refused),
  is listed in `release-source.json` `ota_publishers` (`verbal76`), and has the repository permission
  `admin` (read with the run's token from `GET /repos/{repo}/collaborators/{actor}/permission`);
  `authorized_by` equals that actor (the typed name is never proof by itself); the run was dispatched
  from the release branch (`github.ref`); `confirm` is `PUBLISH`.
- **Source:** a full 40-character SHA, a commit on the release branch that contains every earlier OTA's
  source (`release_guard.py check --contains-published`), not already published.
- **Runtime:** `runtime_id` is exactly what that commit builds (r5 today); the publish job also checks that
  the pack it built reports it, and `ota_runtime.py --check` runs.
- **Channel:** `dev` (the only one).
- **Revision:** `ota_revision` is exactly the next one (`dev-` + one more than the highest `ota-dev-*` tag),
  not already published; the publish job recomputes it from the release list and stops if it differs or
  the release exists.
- The publish job also checks that resolve's SHA, runtime and revision are exactly the requested ones.

Every existing gate still applies, unchanged: the full tests on that SHA (fast, two unit shards, the
playthrough), baked export, the logo, signing with the pinned key, client-side inspection, the immutable
release, re-download and re-verification, the forward-only channel pointer, the receipt. Rollback and the
phones' known-good copy are unchanged (docs/OTA.md).

To retry after a failed run, run it again by hand with the same fields (the revision is still the next one
because nothing was published); a commit or revision already published is refused.

Check locally (the authorization context is what GitHub would supply):

    python3 tools/ota_request.py validate --request req.json --actor verbal76 --triggering-actor verbal76 \
      --permission admin --ref refs/heads/claude/mote-game-continuation-bov2x9 --confirm PUBLISH

## Limitation: what GitHub can and cannot prove (owner action recommended)

GitHub authenticates **accounts**, not people. The checks above prove that an allowed admin account started
the run, from the release branch, with the exact fields. They cannot tell the owner from anything else
acting with the owner's account or credentials (for example, tools that push through the owner's GitHub
connection appear as `verbal76`; the Claude GitHub app itself is refused when it tries to dispatch
workflows, HTTP 403, so it cannot start this workflow). Also, a workflow file is read from the ref it is
run from: an admin who changed the workflow on the release branch could change the checks themselves (the
lint in CI would flag it, but CI does not block a push).

The GitHub control that closes this is already wired in: the publish job runs in the **`ota-dev`
environment**. Until it is configured it has no rules (GitHub creates it on first use). To make every OTA
wait for the owner's own approval in GitHub's UI, the owner sets, in Settings > Environments > `ota-dev`:

1. **Required reviewers:** the owner (leave "Prevent self-review" off, since the owner both starts and approves).
2. **Deployment branches and tags:** "Selected branches" = `claude/mote-game-continuation-bov2x9`.
3. Optionally, move the `MOTE_OTA_SIGNING_KEY` secret from repository secrets to this environment's
   secrets, so only an approved publish job can read it.

Plus a branch protection rule (or ruleset) on the release branch so its workflow files change only by
review. These settings could not be read or changed from this environment (the GitHub API paths for
environments and collaborators are blocked by the session's proxy), so they are **not verified** here.
Until the owner configures them, owner-only authorization rests on the owner's account being the only
admin listed in `ota_publishers`; publication stays stopped unless the owner starts it.

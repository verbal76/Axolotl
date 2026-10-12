# Publishing an OTA (manual only, owner decision 2026-10-12)

An OTA reaches every installed phone on its channel, so it is published only when explicitly asked.
Pushes, merges, passing CI, documentation and version changes publish nothing. (Until 2026-10-12 every
game-file push to the release branch published; `tools/release_guard.py lint` now fails any publishing
workflow that an ordinary push, a pull request or any other event could start.)

OTA identity is separate from native build numbers (owner, 2026-10-12): an OTA is `dev-000NNN`
("Mote vNNN" on the phone), its own sequence on its channel; a native build is "Mote Build NN"
(docs/RELEASES.md). Publishing an OTA never changes a build number, and a numbered build never publishes
an OTA. Every OTA's signed manifest names its revision (`ota_id`, `seq`), exact `source_sha`, compatible
`runtime_id`, `channel` and the pack's `pck_sha256` and size; About shows them on the phone.

## How to ask

1. Make sure the commit is on the release branch and locally green (CLAUDE.md, docs/ACTIONS_BUDGET.md).
2. Either
   - **push a request** to the release branch: write `.github/ota-publish-request.json` and push only
     that change (a commit with no `[skip ci]`):

         {
           "source_sha": "<full 40-character SHA on the release branch>",
           "runtime_id": "android-godot-4.7.2-r5",
           "channel": "dev",
           "ota_name": "short-name",
           "authorized_by": "owner",
           "reason": "what this OTA delivers"
         }

   - or **by hand**: Actions > *OTA publish (dev channel)* > Run workflow, fill the same fields and type
     `PUBLISH` in the confirmation box.

`tools/ota_request.py validate` refuses the request (and nothing is built) unless: the SHA is a full
40-character commit on the release branch and contains every earlier OTA's source; `runtime_id` is
exactly the runtime that commit builds (native layer r5 today); the channel is `dev`; `authorized_by`
is filled; that commit has not already been published. The publish job then checks again that the pack it
built reports the requested runtime, and every existing gate still applies: the full tests on that SHA,
the runtime lock, baked export, logo, signing, client-side inspection, immutable release, re-download
and re-verification, the channel pointer, the receipt. Rollback and the known-good copy on phones are
unchanged (docs/OTA.md).

To publish the same content again after a failed run, push the request file again (any change, such as
the `reason`); a commit already published is refused.

Check locally before asking: `python3 tools/ota_request.py validate --request <file>`.

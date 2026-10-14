# GitHub Actions budget policy (standing owner directive, 2026-10-06)

GitHub-hosted Actions minutes are shared across the owner's projects on a deliberately small monthly
budget. Treat them as scarce. Before starting any GitHub-hosted workflow, ask: **"Does this need GitHub
Actions, or can I prove it locally?"** Use Actions only when GitHub-hosted execution gives necessary
evidence.

## Use Actions for

- The OTA publish run (`ota-publish.yml`): its fast checks, both unit shards, the playthrough, the baked
  export, the logo gate, signing and verification are the release gates. Never bypass or trim them.
- An APK/AAB only when the native layer changed (build.yml's `native` job decides) or the owner asks for
  one for physical testing or release.
- A platform-specific check that genuinely cannot be reproduced locally.

## Do not use Actions for

- Validating routine work: run the suites locally first (see below). CI is not a debugger.
- Docs, Markdown, research, bookkeeping or workflow-only changes: they start no workflow (path filters)
  and are committed with `[skip ci]` as well.
- Re-running an expensive workflow to see whether an intermittent test passes: root-cause it locally.
- Rebuilding a SHA that already has a verified result (build.yml's `covered` job reuses the OTA run's).
- iOS / Windows / desktop builds nobody asked for (the iOS job runs only on a manual run with `ios: true`).

## How the workflows are set up

| Workflow | Starts on | Cost-saving rules |
|---|---|---|
| `ota-publish.yml` | push to the release branch (each push is a release); manual | ignores docs/Markdown/workflow-only pushes; never cancelled mid-way (it publishes) |
| `build.yml` (Build & Verify) | PRs, push to main, manual | ignores docs/Markdown/workflow-only changes; a newer push cancels the older run; skips the suites when an OTA run covers the SHA; APK only on a native change; iOS only by hand |
| `tests.yml` | called by the two above | the suites themselves |

## Local validation (before any release push)

```
G=/path/to/godot   # 4.7.2
godot --headless --path . --import
godot --headless --path . -s tools/check_scripts.gd | grep "Parse Error"   # must print nothing
python3 tools/ota_runtime.py --check                                        # OTA-compatible
# The three suites, in parallel, each with its own user-data dir (they write save files):
XDG_DATA_HOME=/tmp/x1 godot --headless --path . --fixed-fps 60 --max-fps 0 -- --test=unit --shard=1/2
XDG_DATA_HOME=/tmp/x2 godot --headless --path . --fixed-fps 60 --max-fps 0 -- --test=unit --shard=2/2
XDG_DATA_HOME=/tmp/x3 godot --headless --path . --fixed-fps 60 --max-fps 0 -- --test=playthrough
```

Only once these are green does a commit go to the release branch, where the OTA run repeats them as the
signed release gate. Work in progress goes to `preserve/mote-audit-round`, which starts no workflow.

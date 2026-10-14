# Releases: numbered builds (studio standard §5-§9)

One source SHA, one build number, one GitHub Release **"Mote Build NN"** (tag `build-NN`, prerelease,
never "latest"), holding only what was asked for:

    Mote Build NN APK.apk        Android (install over the existing app; saves kept)
    Mote Build NN EXE.zip        Windows x86-64 (Mote.exe + THIRD_PARTY_NOTICES.txt + README.txt)
    Mote Build NN Linux.tar.gz   Linux x86-64 / Steam Deck (Mote.x86_64, executable, + notices + README)
    build-manifest.json          game, build, source SHA and branch, engine, runtime, time, run, and
                                 every artifact's platform, SHA-256 and size
    checksums.sha256

Release source rules (only the release branch; never older than an earlier build): `docs/RELEASE_SOURCE.md`.

## How to make one

The build number with Android is the APK's Android build (its `versionCode`), which Build & Verify
assigns (its run number), so the APK and the numbered build share one number and installs stay in place.

1. **APK** (if Android is wanted): Actions > Build & Verify > Run workflow on the release branch at the
   approved commit. Note its run id and its Android build (artifact `mote-android-v0.1.0-bNN`).
2. **Numbered build**: Actions > *Build & Release (coordinated)* > Run workflow:
   `platform` all | android | windows | linux, `source_sha` (the same commit), `build_number` NN,
   `destination` github_releases | local_only, `apk_run` (the run from step 1, for all/android).
   (Or push `.github/build-release-request.json` with the same fields.)

The workflow checks the SHA's lineage, that NN is new and above every earlier build, runs the tests
(fast checks only when an OTA publish or Build & Verify run already passed the full suites on that SHA),
exports Windows and Linux from the SHA, smoke-runs the Linux package, takes the APK only if its
build-info says the same SHA and number and its SHA-256 matches, writes and verifies the manifest and
checksums, publishes the release, then downloads it again and verifies it. A failed platform stops the
release: a partial build is never published as complete.

It does **not** publish an OTA, upload to Steam or Google Play, or touch any other release.

## Locally (no Actions minutes)

    python3 tools/build.py build --platform all-desktop --sha <commit> --build NN --out dist
    python3 tools/build.py manifest --dir dist --sha <commit> --build NN

`build` refuses a checkout that is not exactly that commit or has uncommitted changes, and leaves
`export_presets.cfg` (part of the Android runtime lock) exactly as it found it. Android needs the
signing secrets, so its APK always comes from Build & Verify (`build.py apk` names and checks it).

## Other release paths (unchanged)

- **OTA** (`ota-publish.yml`): a signed dev-channel OTA for installed phones, published only by a manual
  run by the owner (docs/OTA_PUBLISHING.md). Its id (`dev-000NNN`) is a separate sequence: an OTA never changes a
  build number, and a numbered build never publishes an OTA.
- **APK only** (`apk-release.yml`): the known-working playtester-APK release (`apk-v0.1.0-bNN`; b128 and
  b132 were published with it). **Kept** until the numbered-build workflow has been proven on GitHub.

## Checks on the numbered-build workflow (2026-10-12, local and static; it has not yet run on GitHub)

- Starts only by hand or from `.github/build-release-request.json`; `release_guard.py lint` fails it if
  an ordinary push, PR or other event could start it. Inputs: platform, source_sha, build_number,
  destination, apk_run.
- Source: full SHA, release-branch lineage, contains every earlier `build-*`; build number must be new and
  above the last. Tests run on the SHA (fast only if the full suites already passed there).
- Android signing is unchanged: the APK is the one Build & Verify built and signed with the existing key
  (same package, same certificate pin), taken only if its build-info names the same SHA and number and
  its SHA-256 matches; nothing is re-signed.
- Windows and Linux packaging, names, manifest and checksums: proven locally with `tools/build.py`
  (builds 133-135: Linux package started and quit cleanly; Windows PE checked: icon and version
  resources); refusals proven for a wrong number, wrong source and a tampered artifact.
- actionlint: clean.

## Retiring apk-release.yml (later, owner-approved)

1. Run one numbered build that includes Android (`platform: all`) and confirm on GitHub: release
   "Mote Build NN" with all five files, re-download verification green, the APK installs over the
   current app on a phone and keeps saves.
2. Owner approves the retirement.
3. In one commit: delete `.github/workflows/apk-release.yml` and `.github/apk-release-request.json`,
   remove `apk-release.yml` from `publishing_workflows` in `.github/release-source.json`, keep the
   existing `apk-v0.1.0-bNN` releases and tags untouched, and update this file and CLAUDE.md.
4. `python3 tools/release_guard.py lint` must pass.

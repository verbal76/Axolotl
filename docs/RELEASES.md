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

- **OTA** (`ota-publish.yml`): a signed dev-channel OTA for installed phones, published only on an explicit
  request (docs/OTA_PUBLISHING.md). Its id (`dev-000NNN`) is a separate sequence: an OTA never changes a
  build number, and a numbered build never publishes an OTA.
- **APK only** (`apk-release.yml`): the earlier playtester-APK release (`apk-v0.1.0-bNN`), kept until
  the owner retires it in favour of numbered builds.

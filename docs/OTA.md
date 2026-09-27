# Mote development OTA channel

Install one **Mote Dev** APK once. After that, compatible game changes reach it
over the air (OTA). You push a commit, CI tests it and publishes a signed Godot PCK, and the phone
downloads it and runs it after the next restart. You only build a new APK when the installed
**runtime** changes.

This is an application-level Godot patch channel, not Google Play updating.

## Two layers

| Layer | What it contains | How it changes |
|---|---|---|
| **Native / installed shell** (APK) | Godot 4.7.2 runtime; Android manifest, permissions, package id and signing; export presets; `project.godot` (autoload list, project settings); the OTA bootstrap `scripts/boot/*` (loader, verifier, downloader, recovery screen, public key); the bundled baseline game | New APK only |
| **Game layer** (OTA PCK) | Everything else under `res://`: GDScript, scenes, shaders, textures, audio, UI, level data, `GameVersion`, `SaveSchema` | OTA |

A loaded pack replaces matching `res://` paths. Godot does **not** reload project settings from
a pack, and the bootstrap scripts are already loaded before any pack is mounted. So changes to
those files would silently do nothing over OTA. The CI gate (below) refuses to publish them.

### OTA-safe vs APK-required

OTA-safe (game layer):
- gameplay/UI GDScript, including **new** scripts and new `class_name`s (this was verified with an exported build);
- scenes, resources, shaders, textures, audio, level layout and data;
- the product version (`scripts/core/game_version.gd`).

These need a new APK. `python3 tools/ota_runtime.py --check` fails the OTA workflow if you
change any of them:
- the Godot version (`GODOT_VERSION` in `build.yml`);
- `export_presets.cfg`: permissions, package id, ABI, launcher icon, signing or plugins;
- `project.godot`: autoloads, input or rendering settings, main scene path;
- anything in `scripts/boot/`: the bootstrap, verifier, channel URL or public key;
- native `.so` libraries, Android plugins, Gradle, Java or Kotlin (none are used today).

When one of these changes, bump the runtime with `python3 tools/ota_runtime.py --bump` (the
revision becomes part of the runtime ID, e.g. `android-godot-4.7.2-r2`). Commit, then install
the new Dev APK. Older APKs reject OTAs built for the new runtime ("native update required").

## Boot order

```
APK starts
 -> Boot autoload _init()          (first autoload; native layer)
      pin native build info
      choose PENDING, else CURRENT, else PREVIOUS
      verify: signed manifest, runtime, size, SHA-256
      count the start attempt, then ProjectSettings.load_resource_pack()
 -> Settings autoload, main scene  (loaded from the mounted pack)
 -> game shows title / starts play -> Boot.report_ready()
 -> +3 s running                   -> BOOT HEALTHY (pending becomes current)
 -> update check: pointer -> manifest -> PCK (temp file) -> verify -> READY/PENDING
```

## Storage (device)

`user://ota/` holds the following:
- `state.json` stores CURRENT, PREVIOUS, PENDING, READY, the list of rejected OTAs, boot attempts and health, rollback count, the disabled flag, and the last check/download/verify/load results. It is written atomically.
- `packages/<ota_id>.pck` holds verified packages only.
- Downloads land in `packages/.incoming-<ota_id>.pck` and are promoted only after verification.
- `manifests/<ota_id>.json` and `.json.sig` keep the exact signed bytes, which are re-verified on every boot.

The APK's bundled game is never modified and is always the final fallback.

## Publication (GitHub Releases on this public repo)

- `ota-dev-000123` is an immutable prerelease per OTA. It holds `axolotl-dev-000123.pck`, `manifest.json` and `manifest.json.sig`.
- `ota-channel-dev` is the mutable pointer. Its `latest.json` names the newest OTA's manifest and signature URLs, and it only moves forward.

### Manifest

```json
{
  "schema": 1, "channel": "dev", "ota_id": "dev-000123", "seq": 123,
  "source_sha": "<40-hex GITHUB SHA>", "runtime_id": "android-godot-4.7.2-r1",
  "minimum_bootstrap_version": 1, "game_version": "0.1.0",
  "save_schema": 1, "min_save_schema": 1,
  "pck_url": "https://github.com/verbal76/Axolotl/releases/download/ota-dev-000123/axolotl-dev-000123.pck",
  "pck_sha256": "<sha-256>", "pck_size": 3183988, "created_at": "<UTC>",
  "build_run": {"id": "<run id>", "number": "123", "attempt": "1", "url": "<run url>"}
}
```

The signature is RSA-3072 PKCS#1 v1.5 over SHA-256 of the exact manifest bytes (`openssl dgst -sha256 -sign`).
- The public key is embedded in `scripts/boot/ota_config.gd`, which ships in the APK.
- The private key exists only in the `MOTE_OTA_SIGNING_KEY` Actions secret. Before signing, CI checks that the secret matches the embedded public key.

### Workflow `ota-publish.yml`

It runs on every push to `claude/axolotl-aquarium-platformer-3y0qyy`, or manually through **Run workflow** for any commit. In order, it:

1. checks out the exact commit and records its SHA;
2. runs the runtime gate (`ota_runtime.py --check`);
3. installs Godot 4.7.2 (no export templates are needed for a pack) and imports;
4. reads canonical identities (`tools/print_identity.gd`);
5. runs the script check, mechanics suite and playthrough bot;
6. exports the PCK with the **Android Dev** preset;
7. builds the manifest (`tools/ota_make_manifest.gd`), signs it, then re-checks it with the on-device client code (`tools/ota_inspect_pack.gd`). That check covers signature, runtime, size, SHA-256, and that the game version inside the pack equals the manifest's and the canonical one;
8. creates the immutable release, and fails if the tag already exists;
9. downloads the published objects again and verifies them;
10. moves the channel pointer, but only forward, and confirms that the public URL serves it;
11. writes the **receipt**: source SHA, runtime, OTA id, PCK hash and size, manifest URL, channel pointer, and `published` / `pointer_moved`. It appears in the job summary and as an `ota-receipt-*` artifact.

If `MOTE_OTA_SIGNING_KEY` is missing, the job stays green but the receipt says `"published": false`.

## One-time setup

1. Add five repository secrets (**Settings → Secrets and variables → Actions → New repository secret**):
   - `MOTE_OTA_SIGNING_KEY`: the private PEM that matches the public key in `ota_config.gd`.
   - `MOTE_ANDROID_DEV_KEYSTORE_B64`: the Mote Dev keystore (PKCS12), base64 on one line. With a stable keystore, later APKs install over earlier ones.
   - `MOTE_ANDROID_DEV_KEYSTORE_PASSWORD`, `MOTE_ANDROID_DEV_KEY_ALIAS` (`mote_dev`), `MOTE_ANDROID_DEV_KEY_PASSWORD`.
     PKCS12 keystores, and Godot's signing step, use a single password, so the key password must equal the keystore password. CI checks this.
   - CI reports only whether each secret is present, never its value.
   - The first generic secrets (`OTA_SIGNING_KEY`, `ANDROID_DEV_KEYSTORE_B64`) and their key/keystore are retired and no longer read.
2. Push, or re-run **Build & Verify**, and download the `mote-android-dev-v…` artifact.
3. Install **Mote Dev** once. It installs alongside the normal offline **Mote**.
4. Re-run **OTA publish (dev channel)** (or push). Open Mote Dev, then **Pause → About / Diagnostics**. When "Latest on channel" shows the OTA, close the app from recents and reopen it.

## Recovery

The diagnostics and recovery screen is part of the APK. It still opens when the game layer is broken:
- **Five quick taps in the top-left corner** of any screen, or **F9** on a keyboard;
- **Pause → About / Diagnostics** when the game UI works.

Controls:
- **Check for update**, **Download update**, **Activate on restart** (for when auto-activation is off);
- **Roll back** returns to PREVIOUS on the next start, and the abandoned OTA is not downloaded again;
- **Boot bundled baseline** / **Re-enable OTA**;
- **Copy diagnostics**, **Quit**.

Automatic protections:
- A start that never reaches boot health counts against that OTA. After two such starts it is abandoned, and the next start falls back.
- A package that fails to load is skipped in the same boot.
- A corrupt stored package or state file falls back to the bundled baseline.
- None of these require reinstalling the APK.

Developer and scripted equivalents of the buttons are available as user args:
- `--ota-action=rollback|disable|enable`
- `--ota-quit-after-check`
- `--ota-pointer=http://127.0.0.1:PORT/...` (desktop only)
- `--ota-root=DIR`

## Failure behaviour

| Situation | Result |
|---|---|
| No network / pointer or manifest download fails | keep running the current package |
| Invalid manifest / bad signature | rejected |
| Runtime or bootstrap mismatch | rejected: "native update required" |
| Interrupted or short download | temp file deleted, current package kept, retried later |
| SHA-256 mismatch | temp file deleted, OTA marked rejected (published packages are immutable) |
| Pack fails to mount | fall back to CURRENT, then PREVIOUS, then baseline, in the same boot |
| Never reaches boot health | abandoned after 2 starts, falls back |
| Save schema outside the OTA's range | not activated automatically |

## Save compatibility

`scripts/core/save_schema.gd` defines `SAVE_SCHEMA` (what this build writes) and `MIN_SAVE_SCHEMA` (the oldest it still reads). They are separate from the game version.
- Every manifest carries both values. The client will not activate an OTA that cannot read the save schema currently on disk. This matters when rolling back past a migration.
- Today the only persistent file is `user://settings.cfg` (schema 1). Its `[meta]` section records save_schema, game_version, native_build, flavor, ota_id and source_sha.
- Before an OTA migrates saves, write a pre-migration backup and bump `SAVE_SCHEMA`. Keep `MIN_SAVE_SCHEMA` at the old value until old OTAs no longer need to roll back.

## Verification tooling

- `scripts/tests/ota_tests.gd` is part of the unit suite. It covers manifest validation, runtime and bootstrap mismatch, the signature (tampered or wrong key), hash and size rejection, and state transitions. It also covers unhealthy-start fallback, load-failure fallback, corrupt package and corrupt state, rollback, baseline mode, and a real PCK mount through the verifier.
- `tools/ota_e2e_local.sh` runs the full loop against a real exported game. Desktop Linux stands in for the phone, with a local HTTP server mirroring the Releases layout. It covers milestone steps 1–16 apart from the Android device itself.
- `tools/version_drift_check.sh` is described in `docs/VERSIONING.md`.

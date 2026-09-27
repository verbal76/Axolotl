# Identities and versioning

Mote has several independent identities. Diagnostics shows them together, but no counter
stands in for another, and none is derived from another.

| Identity | Answers | Authority | Example |
|---|---|---|---|
| **Product** | What game is this? | `PRODUCT_NAME` in `scripts/core/game_version.gd` (title shows it upper-case) | `Mote` |
| **Character** | Who is the protagonist? | `CHARACTER_NAME` in the same file | `Gill` |
| **Game version** (product) | What version of Mote is this? | `GAME_VERSION` in `scripts/core/game_version.gd`, the only copy | `0.1.0` |
| **Source** | Which exact commit produced the running code? | git SHA of the APK build (the branch commit, never a PR merge ref), or of the active OTA | `5190d30c…` |
| **Native version** | Which native shell release is installed? | `version/name` in the export preset (Android versionName) | `0.1.0` |
| **Android build** | Which packaged APK is installed? | `version/code`, set by CI to the Build & Verify run number | `27` |
| **Build flavor** | Which package is this (both are offline-first and OTA-capable)? | Export preset: `Android` (normal, "Mote") or `Android Dev` (dev, "Mote Dev") | `normal` |
| **OTA** | Which remote game payload is active *right now*? | the OTA state after boot selection (`Boot.core.active`) | `dev-000042` |
| **Automation** | Which CI run built or published it? | GitHub Actions run id (in native build info and the OTA manifest) | `17234…` |
| **Save schema** | Which persisted-data format is this? | `SAVE_SCHEMA` in `scripts/core/save_schema.gd` | `1` |
| **Runtime** | Which OTAs can this APK run? | `ota_config.gd` + `ota/runtime_lock.json` | `android-godot-4.7.2-r4` |

Values that don't exist for a build are shown as `local`, `unknown` or `none`, never invented.
For example, a local editor run has no Android build and no CI run.

## Game version policy (MAJOR.MINOR.PATCH)

- **MAJOR** marks a deliberate new product generation. It is not bumped during normal development.
- **MINOR** marks a meaningful feature, content or system milestone.
- **PATCH** marks a smaller deliberately released revision or fix.

`0.1.0` means "first deliberate playable proof-of-concept generation". It was established
because the repository had no earlier product version. The only version-like value before this was the
Android versionName `0.1.0` in the export preset, which now stays as the **native** version.

The game version does **not** change because a commit landed, CI ran, an APK was rebuilt,
an OTA was published or infrastructure changed. Several OTAs, and several APK builds, can
all be game `0.1.0`. Because the constant lives in the game layer, an OTA can deliberately
move the game forward (for example to `0.1.1`) without a new APK.

The native versionName is **not** mapped to the game version. It versions the installed shell
and changes only with native releases. It currently shares the starting value `0.1.0`, but the two are separate identities.

## Consumers (all read the canonical constant)

- **Title screen:** `TitleScreen.version_label` shows `GameVersion.display()`, e.g. `v0.1.0`, and nothing else.
- **Diagnostics:** `Boot.identity()` / `Boot.diagnostics_text()` load `GAME_VERSION` from whatever is mounted, so an active OTA reports its own version.
- **Save metadata:** `Settings.save_meta()` writes game_version, save_schema, native_build, flavor, ota_id and source_sha into `settings.cfg [meta]`.
- **CI:** `tools/print_identity.gd` reads it through Godot. APKs are named `mote-v<game>-b<build>.apk` / `mote-dev-v<game>-b<build>.apk` and `build-info.json` records it. CI never types a version.
- **OTA manifests:** `tools/ota_make_manifest.gd` reads it. `tools/ota_inspect_pack.gd` fails publication unless the version *inside the pack* equals the manifest's version and the canonical value.

## Changing the game version

1. Edit the one line in `scripts/core/game_version.gd`.
2. Run the unit suite and `tools/version_drift_check.sh`. Together they check the title, diagnostics, save metadata, CI identity, the manifest and the version inside the pack.
3. Publish an OTA (push) and/or an APK as appropriate.
4. On the device, check the title shows the new `v…` and Diagnostics shows the same game version, with native build, OTA, SHA, run and save schema still reported separately.

Never search-and-replace a version string across the repo. If a consumer doesn't follow the
canonical value, fix that consumer.

## Regression coverage

- **Unit suite** (`ota_tests.gd`):
  - the canonical value is a single literal MAJOR.MINOR.PATCH, not computed from anything;
  - title, diagnostics and save metadata equal it;
  - no other file in `scripts/` or `scenes/` contains the version string;
  - activating an OTA changes the OTA, source and run identities but not the game version, native build/version or save schema.
- **`tools/version_drift_check.sh`** (runs in CI):
  - in a scratch copy it changes **only** the canonical constant to a probe value;
  - it then proves the title, diagnostics, save metadata, CI identity reader, a generated and signed manifest, and the version inside an exported pack all report the probe value;
  - a hard-coded title `"v0.1.0"` was shown to fail it.

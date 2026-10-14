#!/usr/bin/env bash
# Version-drift regression. Proves every product-version consumer DERIVES from the one
# canonical GameVersion.GAME_VERSION: in a scratch copy, change ONLY that constant and check
# that the title screen, diagnostics, save metadata, the CI identity reader, a generated OTA
# manifest and the version inside an exported pack all report the new value.
# A hard-coded copy anywhere (UI, CI, manifest tooling) makes this fail.
# Usage: GODOT=/path/to/godot tools/version_drift_check.sh [probe-version]
set -euo pipefail
GODOT=${GODOT:-godot}
NEW=${1:-9.87.654}
SRC=$(cd "$(dirname "$0")/.." && pwd)
W=$(mktemp -d)
trap 'rm -rf "$W"' EXIT
tar -C "$SRC" --exclude=./.git --exclude=./build -cf - . | tar -xf - -C "$W"
OLD=$(sed -nE 's/^const GAME_VERSION := "([0-9.]+)"$/\1/p' "$SRC/scripts/core/game_version.gd")
sed -i -E "s/^const GAME_VERSION := \"[0-9.]+\"$/const GAME_VERSION := \"$NEW\"/" "$W/scripts/core/game_version.gd"
grep -q "const GAME_VERSION := \"$NEW\"" "$W/scripts/core/game_version.gd"
echo "drift check: canonical $OLD -> $NEW (scratch copy only)"

# Throwaway signing key so the copy can sign and verify its own manifest.
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$W/drift_key.pem" 2>/dev/null
openssl pkey -in "$W/drift_key.pem" -pubout -out "$W/drift_pub.pem"
python3 - "$W" <<'PY'
import re, sys, pathlib
w = pathlib.Path(sys.argv[1])
cfg = w / "scripts/boot/ota_config.gd"
pub = (w / "drift_pub.pem").read_text().strip()
cfg.write_text(re.sub(r'const PUBLIC_KEY_PEM := """.*?"""', lambda _: f'const PUBLIC_KEY_PEM := """{pub}\n"""', cfg.read_text(), flags=re.S))
PY
"$GODOT" --headless --path "$W" --import >/dev/null 2>&1 || true

echo "-- in-game consumers (title, diagnostics, save metadata, identity separation)"
"$GODOT" --headless --path "$W" --fixed-fps 60 --max-fps 0 -- --test=unit --only=_test_ota_and_version \
    --expect_version="$NEW" --out="$W/out" > "$W/unit.log" 2>&1 || true
grep -E "\[TEST\] (FAIL|SUMMARY)|version|title_" "$W/unit.log" | grep -v "^\[TEST\] PASS ota_" || true
grep -qE "\[TEST\] SUMMARY [0-9]+ passed, 0 failed" "$W/unit.log"

echo "-- CI identity reader"
"$GODOT" --headless --path "$W" -s tools/print_identity.gd 2>/dev/null | grep IDENTITY_JSON | tee "$W/id.log"
grep -q "\"game_version\":\"$NEW\"" "$W/id.log"

echo "-- exported pack + generated, signed manifest"
"$GODOT" --headless --path "$W" --export-pack "Android" "$W/game.pck" > /dev/null 2>&1
"$GODOT" --headless --path "$W" -s tools/ota_make_manifest.gd -- pck="$W/game.pck" out="$W/manifest.json" \
    seq=1 sha=0123456789abcdef0123456789abcdef01234567 url=https://example.invalid/drift.pck 2>/dev/null | grep MANIFEST
openssl dgst -sha256 -sign "$W/drift_key.pem" -out "$W/sig.bin" "$W/manifest.json"
base64 -w0 "$W/sig.bin" > "$W/manifest.json.sig"
"$GODOT" --headless --path "$W" -s tools/ota_inspect_pack.gd -- manifest="$W/manifest.json" \
    sig="$W/manifest.json.sig" pck="$W/game.pck" expect_version="$NEW" 2>/dev/null | grep INSPECT
echo "VERSION DRIFT CHECK PASSED: every consumer followed the canonical value ($NEW)"

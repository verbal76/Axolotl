#!/usr/bin/env bash
# End-to-end OTA proof on a real exported game (desktop Linux stands in for the phone).
#
#  1. export an OTA-capable "installed shell" (Linux OTA test preset, throwaway signing key)
#  2. it boots the bundled baseline with no channel, and with a channel server that hangs;
#     the game reaches boot health before the check gives up, and a full playthrough runs
#     to the end with the channel unreachable (offline first)
#  3-4. publish OTA 1 from a modified copy: PCK + signed immutable manifest + channel pointer
#  5-7. the installed game discovers, downloads and verifies it (SHA-256 + signature)
#  8-11. restart: the pack is loaded before game content; the visible change appears and
#        diagnostics report the exact OTA id and source SHA
#  12-14. publish OTA 2, obtained without reinstalling; restart shows it
#  15. publish a corrupt package (hash mismatch): rejected, previous keeps running
#  16. roll back; also: boot bundled baseline, and an OTA that never reaches boot health
#      is abandoned automatically.
#
# Usage: GODOT=/path/to/godot tools/ota_e2e_local.sh   (needs Linux export templates)
set -uo pipefail
GODOT=${GODOT:-godot}
SRC=$(cd "$(dirname "$0")/.." && pwd)
W=${OTA_E2E_DIR:-$(mktemp -d)}
PORT=${OTA_E2E_PORT:-8765}
BASEURL="http://127.0.0.1:$PORT"
DEVICE="$W/device_ota"
FAILS=0
rm -rf "$W/site" "$DEVICE" "$W/copies"
mkdir -p "$W/site" "$W/copies"

pass() { echo "E2E PASS $*"; }
fail() { echo "E2E FAIL $*"; FAILS=$((FAILS + 1)); }
expect() { # expect <label> <log> <pattern>
	if grep -qE "$3" "$2"; then pass "$1"; else fail "$1 (missing /$3/ in $(basename "$2"))"; fi
}
before() { # before <label> <log> <first pattern> <second pattern>: both present, first earlier
	local a b
	a=$(grep -nE "$3" "$2" | head -1 | cut -d: -f1); b=$(grep -nE "$4" "$2" | head -1 | cut -d: -f1)
	if [ -n "$a" ] && [ -n "$b" ] && [ "$a" -lt "$b" ]; then pass "$1"; else fail "$1 (/$3/ line ${a:-none}, /$4/ line ${b:-none})"; fi
}
USABLE="first frame drawn: (title|play) usable"
SETTINGS="$HOME/.local/share/godot/app_userdata/Mote/settings.cfg"
save_hash() { sha256sum "$SETTINGS" 2>/dev/null | cut -d' ' -f1; }

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$W/key.pem" 2>/dev/null
openssl pkey -in "$W/key.pem" -pubout -out "$W/pub.pem"

LINUX_PRESET='
[preset.2]

name="Linux OTA test"
platform="Linux"
runnable=true
dedicated_server=false
custom_features="ota"
export_filter="all_resources"
include_filter=""
exclude_filter="tools/*"
export_path="build/linux/axolotl.x86_64"
encrypt_pck=false
encrypt_directory=false

[preset.2.options]

binary_format/embed_pck=true
binary_format/architecture="x86_64"
'

make_copy() { # make_copy <name> -> path; repo copy with the Linux OTA test preset + test public key
	local d="$W/copies/$1"
	mkdir -p "$d"
	tar -C "$SRC" --exclude=./.git --exclude=./build -cf - . | tar -xf - -C "$d"
	# Godot reads presets 0, 1, 2... until one is missing: append as the next index.
	local n; n=$(grep -cE '^\[preset\.[0-9]+\]$' "$d/export_presets.cfg")
	printf '%s' "$LINUX_PRESET" | sed "s/preset\.2/preset.$n/g" >> "$d/export_presets.cfg"
	python3 - "$d" "$W/pub.pem" <<'PY'
import re, sys, pathlib
d = pathlib.Path(sys.argv[1]); pub = pathlib.Path(sys.argv[2]).read_text().strip()
cfg = d / "scripts/boot/ota_config.gd"
cfg.write_text(re.sub(r'const PUBLIC_KEY_PEM := """.*?"""', lambda _: f'const PUBLIC_KEY_PEM := """{pub}\n"""', cfg.read_text(), flags=re.S))
PY
	echo "$d"
}

mark_game() { # mark_game <copy> <n>: a deliberately visible game-layer change
	python3 - "$1" "$2" <<'PY'
import sys, pathlib
d = pathlib.Path(sys.argv[1]); n = sys.argv[2]
t = d / "scripts/ui/title_screen.gd"
t.write_text(t.read_text().replace('title.text = "Axolotl"', f'title.text = "Axolotl OTA {n}"'))
g = d / "scripts/core/game.gd"
s = g.read_text()
s = s.replace("func _ready() -> void:\n", f'func _ready() -> void:\n\tprint("E2E GAME MARKER OTA {n} title=", "Axolotl OTA {n}")\n', 1)
g.write_text(s)
PY
}

publish() { # publish <copy> <seq> [corrupt|nohealth]
	local d=$1 seq=$2 mode=${3:-}
	local id; id=$(printf "dev-%06d" "$seq")
	local tag="ota-$id" rel="$W/site/ota-$id"
	mkdir -p "$rel" "$W/site/ota-channel-dev"
	(cd "$d" && "$GODOT" --headless --path . --import >/dev/null 2>&1; "$GODOT" --headless --path . --export-pack "Linux OTA test" "$rel/axolotl-$id.pck" >/dev/null 2>&1)
	local sha; sha=$(printf '%040x' "$seq")
	(cd "$d" && "$GODOT" --headless --path . -s tools/ota_make_manifest.gd -- pck="$rel/axolotl-$id.pck" out="$rel/manifest.json" \
		seq="$seq" sha="$sha" platform=linux url="$BASEURL/$tag/axolotl-$id.pck" run_id="e2e-$seq" 2>/dev/null | grep MANIFEST)
	openssl dgst -sha256 -sign "$W/key.pem" -out "$rel/sig.bin" "$rel/manifest.json" && base64 -w0 "$rel/sig.bin" > "$rel/manifest.json.sig"
	if [ "$mode" = corrupt ]; then
		# Same size, flipped bytes: the signed manifest's SHA-256 no longer matches.
		python3 -c "import sys;p=sys.argv[1];b=bytearray(open(p,'rb').read());b[len(b)//2]^=0xFF;b[len(b)//3]^=0xFF;open(p,'wb').write(b)" "$rel/axolotl-$id.pck"
	fi
	printf '{"channel":"dev","ota_id":"%s","seq":%d,"manifest_url":"%s/%s/manifest.json","signature_url":"%s/%s/manifest.json.sig"}\n' \
		"$id" "$seq" "$BASEURL" "$tag" "$BASEURL" "$tag" > "$W/site/ota-channel-dev/latest.json"
	echo "published $id ($mode)"
}

run_game() { # run_game <label> [extra args...]
	local label=$1; shift
	timeout "${RUN_TIMEOUT:-40}" "$W/axolotl.x86_64" --headless -- --ota-root="$DEVICE" \
		--ota-pointer="$BASEURL/ota-channel-dev/latest.json" --ota-quit-after-check "$@" > "$W/run_$label.log" 2>&1
	echo "--- run $label"; grep -E "^\[OTA\]|E2E GAME MARKER|usable" "$W/run_$label.log" | sed 's/"native_[a-z_]*":"[^"]*",//g' | cut -c1-260
}

echo "== building installed shell (baseline)"
BASE=$(make_copy base)
(cd "$BASE" && "$GODOT" --headless --path . --import >/dev/null 2>&1; "$GODOT" --headless --path . --export-debug "Linux OTA test" "$W/axolotl.x86_64" >/dev/null 2>&1)
[ -x "$W/axolotl.x86_64" ] || { echo "E2E FAIL could not export the shell (Linux templates installed?)"; exit 1; }

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$W/site" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 1

run_game 01_baseline_no_channel
expect "2 baseline boots with no channel" "$W/run_01_baseline_no_channel.log" "no OTA selected: running bundled baseline"
expect "2 game reaches boot health offline" "$W/run_01_baseline_no_channel.log" "boot healthy: bundled baseline"
expect "2 automatic check runs after start" "$W/run_01_baseline_no_channel.log" "automatic check \(start\)"
expect "2 unreachable channel keeps current" "$W/run_01_baseline_no_channel.log" "channel unreachable|invalid channel pointer"
before "startup: Mote loading screen is the first frame" "$W/run_01_baseline_no_channel.log" "loading screen visible" "moss ball 1 built"
before "startup: usable before any update check (no network)" "$W/run_01_baseline_no_channel.log" "$USABLE" "automatic OTA check starts|automatic check"
before "startup: usable before the check fails (no network)" "$W/run_01_baseline_no_channel.log" "$USABLE" "channel unreachable"

# A channel server that accepts connections and never answers (a stalled network).
HPORT=$((PORT + 1))
python3 -c "
import socket
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('127.0.0.1', $HPORT)); s.listen(16); held = []
while True: held.append(s.accept()[0])
" >/dev/null 2>&1 &
HANG=$!
sleep 1
run_game 01b_hanging_channel --ota-pointer="http://127.0.0.1:$HPORT/ota-channel-dev/latest.json"
kill $HANG 2>/dev/null
expect "2 hanging channel: game still starts" "$W/run_01b_hanging_channel.log" "boot healthy: bundled baseline"
expect "2 hanging channel: check times out, current kept" "$W/run_01b_hanging_channel.log" "channel unreachable \(network result 13\)"
H=$(grep -n "boot healthy" "$W/run_01b_hanging_channel.log" | head -1 | cut -d: -f1)
U=$(grep -n "channel unreachable" "$W/run_01b_hanging_channel.log" | head -1 | cut -d: -f1)
if [ -n "$H" ] && [ -n "$U" ] && [ "$H" -lt "$U" ]; then pass "2 startup never waited for the network"; else fail "2 startup order (healthy line $H, timeout line $U)"; fi
before "startup: usable before the hanging check times out" "$W/run_01b_hanging_channel.log" "$USABLE" "channel unreachable"
# The server hangs for the full 15 s timeout; the game must have been usable long before that.
UMS=$(grep -m1 -E "$USABLE" "$W/run_01b_hanging_channel.log" | awk '{print int($2)}')
if [ -n "$UMS" ] && [ "$UMS" -lt 10000 ]; then pass "startup: usable at ${UMS} ms while the channel hangs"; else fail "startup: usable at ${UMS:-never} ms with a hanging channel"; fi

# The whole game, start to ALL CLEAR, with the OTA client on and its channel unreachable.
echo "--- offline playthrough (seed 4242, channel unreachable)"
timeout "${PLAY_TIMEOUT:-1200}" "$W/axolotl.x86_64" --headless --fixed-fps 60 --max-fps 0 -- --test=playthrough --seed=4242 \
	--out="$W/offline_play" --ota-root="$W/device_offline" --ota-pointer="http://127.0.0.1:$((PORT + 2))/ota-channel-dev/latest.json" \
	> "$W/run_offline_playthrough.log" 2>&1
grep -E "\[TEST\] SUMMARY|^\[OTA\]" "$W/run_offline_playthrough.log" | cut -c1-200
expect "15 offline: full playthrough completes" "$W/run_offline_playthrough.log" "\[TEST\] SUMMARY 12 passed, 0 failed"
expect "15 offline: OTA check failed quietly during play" "$W/run_offline_playthrough.log" "channel unreachable"

O1=$(make_copy ota1); mark_game "$O1" 1; publish "$O1" 1
SAVE0=$(save_hash)
run_game 02_download_ota1
expect "5-7 discovers, downloads, verifies OTA 1" "$W/run_02_download_ota1.log" "dev-000001 ready: restart to run it"
run_game 03_boot_ota1
expect "9 bootstrap loads OTA 1 before game content" "$W/run_03_boot_ota1.log" "loaded dev-000001 \(pending\)"
expect "10 visible game change from the PCK" "$W/run_03_boot_ota1.log" "E2E GAME MARKER OTA 1"
expect "11 diagnostics: exact OTA id + source SHA" "$W/run_03_boot_ota1.log" "\"ota_id\":\"dev-000001\".*\"source_sha\":\"0000000000000000000000000000000000000001\""
expect "11 product version unchanged by OTA" "$W/run_03_boot_ota1.log" "\"game_version\":\"$(sed -nE 's/^const GAME_VERSION := "([0-9.]+)"$/\1/p' "$SRC/scripts/core/game_version.gd")\""
expect "boot health reached -> CURRENT" "$W/run_03_boot_ota1.log" "boot healthy: dev-000001"
expect "startup: pending OTA activation reaches a usable frame" "$W/run_03_boot_ota1.log" "$USABLE"
if [ -n "$SAVE0" ] && [ "$(save_hash)" = "$SAVE0" ]; then pass "startup: saves untouched by startup, download and activation"; else fail "startup: settings.cfg changed (${SAVE0:-missing} -> $(save_hash))"; fi

O2=$(make_copy ota2); mark_game "$O2" 2; publish "$O2" 2
run_game 04_download_ota2
expect "13 OTA 2 obtained without reinstall" "$W/run_04_download_ota2.log" "dev-000002 ready: restart to run it"
run_game 05_boot_ota2
expect "14 restart shows OTA 2" "$W/run_05_boot_ota2.log" "E2E GAME MARKER OTA 2"
expect "startup: active OTA reaches a usable frame" "$W/run_05_boot_ota2.log" "$USABLE"

O3=$(make_copy ota3); mark_game "$O3" 3; publish "$O3" 3 corrupt
run_game 06_corrupt_ota3
expect "15 corrupt package rejected (hash)" "$W/run_06_corrupt_ota3.log" "rejected dev-000003: SHA-256 mismatch"
expect "15 previous game still running" "$W/run_06_corrupt_ota3.log" "E2E GAME MARKER OTA 2"
[ -e "$DEVICE/packages/.incoming-dev-000003.pck" ] && fail "15 temp file left behind" || pass "15 incomplete/corrupt temp file removed"
run_game 07_after_corrupt
expect "15 next start still OTA 2" "$W/run_07_after_corrupt.log" "loaded dev-000002 \(current\)"
expect "startup: after a rejected OTA the game still reaches a usable frame" "$W/run_07_after_corrupt.log" "$USABLE"

run_game 08_rollback --ota-action=rollback
expect "16 rollback accepted" "$W/run_08_rollback.log" "action rollback: ok"
run_game 09_after_rollback
expect "16 rollback runs OTA 1 again" "$W/run_09_after_rollback.log" "E2E GAME MARKER OTA 1"
expect "15 hash-rejected OTA 3 is not re-downloaded" "$W/run_09_after_rollback.log" "latest is dev-000003, which was rejected or rolled back here"
if python3 -c "import json,sys;s=json.load(open(sys.argv[1]));sys.exit(0 if 'dev-000002' in s['bad'] and s['current'].get('ota_id')=='dev-000001' else 1)" "$DEVICE/state.json"; then pass "16 rolled-back OTA 2 recorded as not-to-reinstall"; else fail "16 rollback state"; fi

run_game 10_disable --ota-action=disable
run_game 11_baseline
expect "recovery: boot bundled baseline" "$W/run_11_baseline.log" "OTA disabled by user: running bundled baseline"
if grep -q "E2E GAME MARKER" "$W/run_11_baseline.log"; then fail "baseline still ran OTA code"; else pass "baseline runs APK game code"; fi
expect "startup: bundled baseline reaches a usable frame" "$W/run_11_baseline.log" "$USABLE"
run_game 12_enable --ota-action=enable
run_game 13_reenabled
expect "recovery: re-enable returns to CURRENT" "$W/run_13_reenabled.log" "E2E GAME MARKER OTA 1"

# An OTA whose game never reaches the boot-health checkpoint (simulates a hang/crash loop).
O4=$(make_copy ota4); mark_game "$O4" 4
sed -i '/Boot.report_ready()/d' "$O4/scripts/core/game.gd"
publish "$O4" 4
run_game 14_download_ota4
RUN_TIMEOUT=12 run_game 15_ota4_start1
RUN_TIMEOUT=12 run_game 16_ota4_start2
expect "unhealthy OTA 4 actually started" "$W/run_15_ota4_start1.log" "E2E GAME MARKER OTA 4"
run_game 17_ota4_abandoned
expect "unhealthy OTA abandoned after repeated starts" "$W/run_17_ota4_abandoned.log" "dev-000004: never reached boot health"
expect "falls back to last healthy OTA" "$W/run_17_ota4_abandoned.log" "E2E GAME MARKER OTA 1"
expect "startup: after abandoning an unhealthy OTA the game reaches a usable frame" "$W/run_17_ota4_abandoned.log" "$USABLE"

echo
echo "device state:"; python3 -c "import json,sys;s=json.load(open(sys.argv[1]));print(' current', s['current'].get('ota_id'),' previous', s['previous'].get('ota_id'),' pending', s['pending'].get('ota_id'),' bad', s['bad'],' rollbacks', s['rollback_count'])" "$DEVICE/state.json"
echo "packages on device: $(ls "$DEVICE/packages" | tr '\n' ' ')"
if [ "$FAILS" -eq 0 ]; then echo "E2E RESULT: ALL PASSED"; else echo "E2E RESULT: $FAILS FAILED"; exit 1; fi

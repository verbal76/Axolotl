extends RefCounted
## NATIVE LAYER — installed with the APK and never replaced by an OTA pack.
## Everything the bootstrap needs to decide what it may load lives here. Changing this file
## (or anything under scripts/boot/) changes the installed runtime: bump RUNTIME_REVISION
## with `python3 tools/ota_runtime.py --bump` and build a new APK.

## Version of the on-device OTA bootstrap protocol. Manifests may demand a minimum.
const BOOTSTRAP_VERSION := 1
## Bumped whenever the native layer changes incompatibly (see ota/runtime_lock.json).
const RUNTIME_REVISION := 3
## The only channel the dev APK follows. Channels are manifest pointers, not packages.
const CHANNEL := "dev"
const REPO := "verbal76/Axolotl"
## Custom export feature that turns the OTA client on (set only by the "Android Dev" preset).
const FEATURE := "ota_dev"

## Public half of the Mote OTA signing key. The private half lives only in the
## MOTE_OTA_SIGNING_KEY GitHub Actions secret. (The first dev key was retired and replaced.)
const PUBLIC_KEY_PEM := """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAkYjF1MocvG9O5PMGNzkt
isiML7/DQW/UCCAKD+xXYhhgui5u9uegfRdkzJR4jR+fTzskU2Y1+OLcoUVEnoff
VN3stGLEKT4gisPxZwXyJmEyJ73kovwWs9m8g9/EhIHiovTwxknOApBGdGtK8zlj
qMlPMNc0sKhD5f0l3Va1STIXYp/vdG8xuBCZVW4Mq9i6QA8U/exKk42fseXGP/RX
jvVfFQSMYzvmI6BkdBncgBlbt1dvIGNL+PxPyVtQCq98tkP6Vv1A7aBlKsgxrQ2d
RLp7kuE3pNi0kRam1ZF1WHptpt7uuLblHPDXYZmDgWI5tnXDqPrqV1xdDI/gD0Qd
LvPAHLtcV079VPOK1NaqVbgM7IFZ+IiV5Tdl35O92h0cFfScgRq+6nCf1MDcFBsq
sRGjCDaohAxjrB6XhZFrG7AneBjB3KSeXX+p/NexrW7Y+2Z16s1Q4b8GuBWBiSk+
MLN2XJi/+jYMQR21sB1rNz8Us+NgFvDL482/GSPOZgOlAgMBAAE=
-----END PUBLIC KEY-----
"""


static func engine_version() -> String:
	var v := Engine.get_version_info()
	return "%d.%d.%d" % [v["major"], v["minor"], v["patch"]]


## e.g. "android-godot-4.7.2-r1". Every OTA manifest must name exactly this.
static func runtime_id(platform := "") -> String:
	if platform == "":
		platform = OS.get_name().to_lower()
	return "%s-godot-%s-r%d" % [platform, engine_version(), RUNTIME_REVISION]


static func release_url(tag: String, asset: String) -> String:
	return "https://github.com/%s/releases/download/%s/%s" % [REPO, tag, asset]


static func channel_tag(channel := CHANNEL) -> String:
	return "ota-channel-%s" % channel


static func pointer_url(channel := CHANNEL) -> String:
	return release_url(channel_tag(channel), "latest.json")

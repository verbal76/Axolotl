extends RefCounted
## NATIVE LAYER — installed with the APK and never replaced by an OTA pack.
## Everything the bootstrap needs to decide what it may load lives here. Changing this file
## (or anything under scripts/boot/) changes the installed runtime: bump RUNTIME_REVISION
## with `python3 tools/ota_runtime.py --bump` and build a new APK.

## Version of the on-device OTA bootstrap protocol. Manifests may demand a minimum.
const BOOTSTRAP_VERSION := 1
## Bumped whenever the native layer changes incompatibly (see ota/runtime_lock.json).
const RUNTIME_REVISION := 1
## The only channel the dev APK follows. Channels are manifest pointers, not packages.
const CHANNEL := "dev"
const REPO := "verbal76/Axolotl"
## Custom export feature that turns the OTA client on (set only by the "Android Dev" preset).
const FEATURE := "ota_dev"

## Public half of the dev OTA signing key. The private half lives only in the
## OTA_SIGNING_KEY GitHub Actions secret.
const PUBLIC_KEY_PEM := """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAyuft9ZXmjRMCoLQtNFLw
niS5MyYRVg1XgEmsoqW2IcInuWDQPuk88ZbAHkKQNubQlToN1GJpd/hqa34kXkmu
voNcqLXI/gS1UHQ6Hv9ImGtxnb+muX/bjfjJnyqeH/miJa+chPBlD4Y21KMrbIJo
CNRgg/0kUnFqcOSzSQLIhOJRIMOGY6CeK2A37gNNW6gcw7C05kNL6sf8O1G5oDab
34i11ZXXeoHuM/rjpq68NIde29BxoFH3ZpvvAqtABp+vc1eYa3sUllopRrZ/f7tm
hy4S3WwlYvOHC1yCTMWGH6BRmwFeSJre5x2zWB5IVt0H4eZoxlZBVsHh7DajEYxz
dQYMaE3QqvctQO98/SlYgKApsLAZ7lTeIwFs1qJbbjSy4RSTbhH0KyrLNF5XNloP
9AB0f2G951YSKy2sYZgDuy5WBd8xSHYXwokhm8Z+3UqJ9InygokeIOL9eCIwSQCX
0obcUe+JpVlBoc8e9QlCPSAW/NklOvAoZNbZDRP6kg2NAgMBAAE=
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

extends SceneTree
## Independent check of a built/published OTA with the SAME client code the phone runs:
## signature, manifest validation (for the given platform runtime), size + SHA-256, then mounts
## the pack and proves the product version INSIDE the pack equals the manifest's game_version
## and the canonical source this workflow was run from.
## Usage: godot --headless --path . -s tools/ota_inspect_pack.gd -- manifest=... sig=... pck=...
##        [platform=android] [expect_version=X]

const OtaCore := preload("res://scripts/boot/ota_core.gd")


func _init() -> void:
	var a := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	var cfg: Script = load("res://scripts/boot/ota_config.gd")
	var canonical: String = (load("res://scripts/core/game_version.gd") as Script).get_script_constant_map()["GAME_VERSION"]
	var tmp := OS.get_user_data_dir().path_join("ota_inspect")
	var core := OtaCore.new(tmp, cfg.runtime_id(a.get("platform", "android")))
	var fails: Array[String] = []
	var res := core.check_manifest(FileAccess.get_file_as_bytes(a["manifest"]), FileAccess.get_file_as_string(a["sig"]))
	if res[1] != "":
		fails.append("manifest: " + res[1])
	var m: Dictionary = res[0]
	if not m.is_empty():
		var why := core.verify_package(m, a["pck"])
		if why != "":
			fails.append("package: " + why)
	if not ProjectSettings.load_resource_pack(a["pck"], true):
		fails.append("pack does not mount")
	var packed: Script = ResourceLoader.load("res://scripts/core/game_version.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var in_pack: String = packed.get_script_constant_map()["GAME_VERSION"] if packed else "unreadable"
	var claimed: String = m.get("game_version", "")
	if in_pack != claimed:
		fails.append("pack contains game %s but manifest claims %s" % [in_pack, claimed])
	if claimed != canonical:
		fails.append("manifest game %s differs from canonical %s" % [claimed, canonical])
	if a.has("expect_version") and a["expect_version"] != in_pack:
		fails.append("expected game %s, pack has %s" % [a["expect_version"], in_pack])
	print("INSPECT ota_id=%s game(pack)=%s game(manifest)=%s canonical=%s sha=%s" % [m.get("ota_id", "?"), in_pack, claimed, canonical, str(m.get("source_sha", "?")).left(12)])
	for f in fails:
		print("INSPECT FAIL ", f)
	print("INSPECT ", "OK" if fails.is_empty() else "FAILED")
	quit(0 if fails.is_empty() else 1)

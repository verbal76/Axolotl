extends SceneTree
## Builds an OTA manifest from an exported PCK. Product version and save schema come from the
## canonical game-layer scripts; runtime identity from the native-layer config.
## Usage: godot --headless --path . -s tools/ota_make_manifest.gd -- pck=... out=... seq=N
##        sha=<40-hex> url=<pck https url> run_id=.. run_number=.. run_attempt=.. run_url=..
##        [platform=android] [channel=dev] [created_at=...]

const OtaCore := preload("res://scripts/boot/ota_core.gd")


func _init() -> void:
	var a := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2:
			a[kv[0]] = kv[1]
	var cfg: Script = load("res://scripts/boot/ota_config.gd")
	var g: Dictionary = (load("res://scripts/core/game_version.gd") as Script).get_script_constant_map()
	var s: Dictionary = (load("res://scripts/core/save_schema.gd") as Script).get_script_constant_map()
	var channel: String = a.get("channel", cfg.get_script_constant_map()["CHANNEL"])
	var seq := int(a["seq"])
	var f := FileAccess.open(a["pck"], FileAccess.READ)
	var size := f.get_length()
	f.close()
	var m := {
		"schema": 1,
		"channel": channel,
		"ota_id": "%s-%06d" % [channel, seq],
		"seq": seq,
		"source_sha": a["sha"],
		"runtime_id": cfg.runtime_id(a.get("platform", "android")),
		"minimum_bootstrap_version": cfg.get_script_constant_map()["BOOTSTRAP_VERSION"],
		"game_version": g["GAME_VERSION"],
		"save_schema": s["SAVE_SCHEMA"],
		"min_save_schema": s["MIN_SAVE_SCHEMA"],
		"pck_url": a["url"],
		"pck_sha256": OtaCore.file_sha256(a["pck"]),
		"pck_size": size,
		"created_at": a.get("created_at", Time.get_datetime_string_from_system(true) + "Z"),
		"build_run": {"id": a.get("run_id", "local"), "number": a.get("run_number", ""),
				"attempt": a.get("run_attempt", ""), "url": a.get("run_url", "")},
	}
	var out := FileAccess.open(a["out"], FileAccess.WRITE)
	out.store_string(JSON.stringify(m, "  ", true) + "\n")
	out.close()
	print("MANIFEST ", m["ota_id"], " game ", m["game_version"], " sha256 ", m["pck_sha256"], " size ", size)
	quit()

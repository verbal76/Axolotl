extends SceneTree
## Prints the canonical identities as JSON for CI. CI READS these; it never defines them.
## Usage: godot --headless --path . -s tools/print_identity.gd [-- platform=android]

func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var gv: Script = load("res://scripts/core/game_version.gd")
	var ss: Script = load("res://scripts/core/save_schema.gd")
	var cfg: Script = load("res://scripts/boot/ota_config.gd")
	var g := gv.get_script_constant_map()
	var s := ss.get_script_constant_map()
	var c := cfg.get_script_constant_map()
	var platform: String = args.get("platform", "android")
	print("IDENTITY_JSON " + JSON.stringify({
		"game_version": g["GAME_VERSION"],
		"save_schema": s["SAVE_SCHEMA"],
		"min_save_schema": s["MIN_SAVE_SCHEMA"],
		"runtime_revision": c["RUNTIME_REVISION"],
		"bootstrap_version": c["BOOTSTRAP_VERSION"],
		"channel": c["CHANNEL"],
		"godot_version": cfg.engine_version(),
		"runtime_id": cfg.runtime_id(platform),
	}))
	quit()

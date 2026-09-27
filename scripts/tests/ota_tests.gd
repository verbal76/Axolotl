extends RefCounted
## OTA client and version/identity regression tests (run inside the unit suite).
## Uses a throwaway RSA key and scratch storage; never touches the real user://ota.

const OtaCore := preload("res://scripts/boot/ota_core.gd")
const RUNTIME := "testos-godot-4.7.2-r1"

var t
var g: Game
var _key: CryptoKey
var _root := ""
var _n := 0


func _init(runner) -> void:
	t = runner
	g = runner.g
	_key = Crypto.new().generate_rsa(2048)


# --- helpers ---------------------------------------------------------------------------------

func _core(fresh := true) -> OtaCore:
	if fresh:
		_n += 1
		_root = OS.get_user_data_dir().path_join("ota_test_%d_%d" % [Time.get_ticks_usec(), _n])
	return OtaCore.new(_root, RUNTIME, "dev", _key.save_to_string(true), 1)


func _write(path: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(data)
	f.close()


func _manifest(seq: int, payload: PackedByteArray, over := {}) -> Dictionary:
	var m := {"schema": 1, "channel": "dev", "ota_id": "dev-%06d" % seq, "seq": seq,
			"source_sha": "%040x" % seq, "runtime_id": RUNTIME, "minimum_bootstrap_version": 1,
			"game_version": GameVersion.GAME_VERSION, "save_schema": 1, "min_save_schema": 1,
			"pck_url": "https://example.invalid/%d.pck" % seq,
			"pck_sha256": OtaCore.sha256_bytes(payload).hex_encode(), "pck_size": payload.size(),
			"created_at": "2026-09-27T00:00:00Z", "build_run": {"id": str(1000 + seq)}}
	m.merge(over, true)
	return m


func _sign(m: Dictionary) -> Array:
	var bytes := JSON.stringify(m, "  ", true).to_utf8_buffer()
	var sig := Crypto.new().sign(HashingContext.HASH_SHA256, OtaCore.sha256_bytes(bytes), _key)
	return [bytes, Marshalls.raw_to_base64(sig)]


## Simulates a finished download of `payload` for manifest m, then stages it.
func _deliver(core: OtaCore, m: Dictionary, payload: PackedByteArray) -> String:
	_write(core.incoming_path(m["ota_id"]), payload)
	var s := _sign(m)
	return core.stage_incoming(s[0], s[1])


func _payload(tag: String) -> PackedByteArray:
	return ("fake pck " + tag).to_utf8_buffer()


# --- tests ---------------------------------------------------------------------------------------

func run() -> void:
	_test_manifest_validation()
	_test_verification()
	_test_transitions()
	_test_boot_health_and_fallback()
	_test_rollback_and_baseline()
	_test_real_pack_mount()
	await _test_version_identity()
	await _test_product_identity()


func _test_manifest_validation() -> void:
	var c := _core()
	var p := _payload("a")
	t.check("ota_manifest_valid_accepted", c.validate_manifest(_manifest(1, p)) == "", c.validate_manifest(_manifest(1, p)))
	var m := _manifest(1, p)
	m.erase("pck_sha256")
	t.check("ota_manifest_missing_field_rejected", c.validate_manifest(m).contains("missing 'pck_sha256'"), c.validate_manifest(m))
	var rt := c.validate_manifest(_manifest(1, p, {"runtime_id": "android-godot-4.8.0-r2"}))
	t.check("ota_runtime_mismatch_needs_native_update", rt.begins_with("native update required"), rt)
	var bs := c.validate_manifest(_manifest(1, p, {"minimum_bootstrap_version": 2}))
	t.check("ota_newer_bootstrap_needs_native_update", bs.begins_with("native update required"), bs)
	t.check("ota_channel_mismatch_rejected", c.validate_manifest(_manifest(1, p, {"channel": "qa"})).contains("channel"), "")
	t.check("ota_plain_http_rejected", c.validate_manifest(_manifest(1, p, {"pck_url": "http://example.invalid/x.pck"})).contains("HTTPS"), "")
	t.check("ota_bad_sha_format_rejected", c.validate_manifest(_manifest(1, p, {"source_sha": "abc"})).contains("source_sha"), "")
	c.device_save_schema = 2
	var sv := c.validate_manifest(_manifest(1, p))
	t.check("ota_newer_save_blocks_older_ota", sv.begins_with("save incompatible"), sv)


func _test_verification() -> void:
	var c := _core()
	var p := _payload("b")
	var m := _manifest(3, p)
	var s := _sign(m)
	t.check("ota_signature_verifies", c.check_manifest(s[0], s[1])[1] == "", c.check_manifest(s[0], s[1])[1])
	var tampered: PackedByteArray = (s[0] as PackedByteArray).duplicate()
	tampered[20] = tampered[20] ^ 1
	t.check("ota_tampered_manifest_rejected", c.check_manifest(tampered, s[1])[1] == "signature verification failed", "")
	var other := Crypto.new().generate_rsa(2048)
	var forged := Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, OtaCore.sha256_bytes(s[0]), other))
	t.check("ota_wrong_key_rejected", c.check_manifest(s[0], forged)[1] == "signature verification failed", "")
	# Hash failure: corrupt bytes of the right size. Nothing changes; the temp file is gone.
	var cur := _manifest(2, _payload("cur"))
	_deliver(c, cur, _payload("cur"))
	var corrupt := p.duplicate()
	corrupt[0] = corrupt[0] ^ 0xFF
	var why := _deliver(c, m, corrupt)
	t.check("ota_hash_mismatch_rejected", why.begins_with("SHA-256 mismatch") and not FileAccess.file_exists(c.incoming_path(m["ota_id"])) and not FileAccess.file_exists(c.package_path(m["ota_id"])) and c.slot("pending")["ota_id"] == "dev-000002" and c.is_bad(m["ota_id"]), why)
	var short := _deliver(c, m, p.slice(0, p.size() - 1))
	t.check("ota_truncated_download_rejected", short.begins_with("size mismatch"), short)


func _test_transitions() -> void:
	var c := _core()
	var loaded: Array[String] = []
	var loader := func(path: String) -> bool:
		loaded.append(path.get_file())
		return true
	var p1 := _payload("1")
	t.check("ota_stage_marks_pending", _deliver(c, _manifest(1, p1), p1) == "" and c.slot("pending")["ota_id"] == "dev-000001" and c.slot("ready").is_empty(), "")
	c = _core(false)
	c.boot(loader)
	t.check("ota_boot_loads_pending", c.active.get("ota_id") == "dev-000001" and loaded == ["dev-000001.pck"], str(loaded))
	c.mark_healthy()
	t.check("ota_healthy_promotes_current", c.slot("current")["ota_id"] == "dev-000001" and c.slot("pending").is_empty() and c.slot("previous").is_empty(), "")
	var p2 := _payload("2")
	_deliver(c, _manifest(2, p2), p2)
	c = _core(false)
	c.boot(loader)
	c.mark_healthy()
	t.check("ota_second_update_keeps_previous", c.slot("current")["ota_id"] == "dev-000002" and c.slot("previous")["ota_id"] == "dev-000001", "")
	t.check("ota_known_seq", c.known_seq() == 2, str(c.known_seq()))
	c.state["auto_activate"] = false
	var p3 := _payload("3")
	_deliver(c, _manifest(3, p3), p3)
	t.check("ota_manual_activation_waits", c.slot("ready")["ota_id"] == "dev-000003" and c.slot("pending").is_empty(), "")
	t.check("ota_activate_on_restart", c.activate_ready() == "" and c.slot("pending")["ota_id"] == "dev-000003", "")


func _test_boot_health_and_fallback() -> void:
	var c := _core()
	var ok := func(_p: String) -> bool: return true
	var p1 := _payload("h1")
	_deliver(c, _manifest(1, p1), p1)
	c.boot(ok)
	c.mark_healthy()
	var p2 := _payload("h2")
	_deliver(c, _manifest(2, p2), p2)
	# dev-000002 starts but never reaches health, twice.
	for i in 2:
		c = _core(false)
		c.boot(ok)
		t.log_line("unhealthy start %d -> %s" % [i + 1, c.active.get("ota_id", "baseline")])
	c = _core(false)
	c.boot(ok)
	t.check("ota_unhealthy_candidate_abandoned", c.active.get("ota_id") == "dev-000001" and c.is_bad("dev-000002") and c.slot("pending").is_empty(), "active %s" % c.active.get("ota_id", "baseline"))
	# Load failure: the new package does not mount -> falls back to CURRENT in the same boot.
	var p3 := _payload("h3")
	_deliver(c, _manifest(3, p3), p3)
	c = _core(false)
	c.boot(func(path: String) -> bool: return not path.ends_with("dev-000003.pck"))
	t.check("ota_load_failure_falls_back", c.active.get("ota_id") == "dev-000001" and c.is_bad("dev-000003"), "active %s" % c.active.get("ota_id", "baseline"))
	# A package corrupted on disk after install is caught at boot and skipped.
	_write(c.package_path("dev-000001"), _payload("h1-corrupted!"))
	c = _core(false)
	c.boot(ok)
	t.check("ota_corrupt_installed_package_not_loaded", c.active.is_empty() and c.is_bad("dev-000001"), "active %s" % c.active.get("ota_id", "baseline"))
	# A broken state file never bricks the install.
	_write(_root.path_join("state.json"), "{not json".to_utf8_buffer())
	c = _core(false)
	c.boot(ok)
	t.check("ota_corrupt_state_boots_baseline", c.active.is_empty() and c.slot("current").is_empty(), "")


func _test_rollback_and_baseline() -> void:
	var c := _core()
	var ok := func(_p: String) -> bool: return true
	for i in [1, 2]:
		var p := _payload("r%d" % i)
		_deliver(c, _manifest(i, p), p)
		c = _core(false)
		c.boot(ok)
		c.mark_healthy()
	t.check("ota_rollback_ok", c.rollback() == "", "")
	c = _core(false)
	c.boot(ok)
	t.check("ota_rollback_runs_previous", c.active.get("ota_id") == "dev-000001" and c.is_bad("dev-000002") and int(c.state["rollback_count"]) == 1, "active %s" % c.active.get("ota_id", "baseline"))
	c.set_disabled(true)
	c = _core(false)
	c.boot(ok)
	t.check("ota_disable_boots_baseline", c.active.is_empty(), "")
	c.set_disabled(false)
	c = _core(false)
	c.boot(ok)
	t.check("ota_reenable_restores_current", c.active.get("ota_id") == "dev-000001", "")


## A real Godot pack built with PCKPacker, verified and mounted through the same path.
func _test_real_pack_mount() -> void:
	var c := _core()
	var src := _root.path_join("probe.txt")
	_write(src, "patched by OTA".to_utf8_buffer())
	var built := _root.path_join("built.pck")
	var pk := PCKPacker.new()
	pk.pck_start(built)
	pk.add_file("res://ota_probe/probe.txt", src)
	pk.flush()
	var bytes := FileAccess.get_file_as_bytes(built)
	_deliver(c, _manifest(1, bytes), bytes)
	c = _core(false)
	c.boot(func(path: String) -> bool: return ProjectSettings.load_resource_pack(path, true))
	var content := FileAccess.get_file_as_string("res://ota_probe/probe.txt")
	t.check("ota_real_pack_mounts_after_verification", c.active.get("ota_id") == "dev-000001" and content == "patched by OTA", content)


# --- product version + identity stack --------------------------------------------------------

func _test_version_identity() -> void:
	var canonical: String = GameVersion.GAME_VERSION
	var expect: String = Settings.test_args.get("expect_version", canonical)
	# The canonical value is a literal MAJOR.MINOR.PATCH, not computed from anything else.
	var src := FileAccess.get_file_as_string("res://scripts/core/game_version.gd")
	var re := RegEx.create_from_string('(?m)^const GAME_VERSION := "(\\d+\\.\\d+\\.\\d+)"$')
	var mt := re.search(src)
	t.check("game_version_is_one_literal", mt != null and mt.get_string(1) == canonical and re.search_all(src).size() == 1, canonical)
	t.check("game_version_matches_expected", canonical == expect, "canonical %s expected %s" % [canonical, expect])
	# Consumers.
	var shown: String = g.title.version_label.text
	t.check("title_shows_canonical_version", shown == "v" + expect, "title shows '%s'" % shown)
	var id: Dictionary = Boot.identity()
	t.check("diagnostics_identity_game_version", id["game_version"] == expect, str(id["game_version"]))
	t.check("diagnostics_text_game_version", Boot.diagnostics_text().contains("Game Version: %s\n" % expect), "")
	var meta: Dictionary = Settings.save_meta()
	t.check("save_meta_game_version_and_schema", meta["game_version"] == expect and meta["save_schema"] == SaveSchema.SAVE_SCHEMA, str(meta))
	# No other copy of the version string anywhere in game code or scenes.
	var copies := _literal_copies("res://scripts", canonical) + _literal_copies("res://scenes", canonical)
	t.check("no_hardcoded_version_copies", copies.is_empty(), ", ".join(copies))
	# Identity separation: activating an OTA changes OTA/source/run identity, never the
	# product version, native build or save schema.
	var saved_core = Boot.core
	var saved_enabled: bool = Boot.ota_enabled
	var before := id
	var c := _core()
	c.active = _manifest(777, _payload("x"), {"source_sha": "f".repeat(40), "build_run": {"id": "424242"}})
	Boot.core = c
	Boot.ota_enabled = true
	var during: Dictionary = Boot.identity()
	Boot.core = saved_core
	Boot.ota_enabled = saved_enabled
	t.check("ota_identity_independent_of_game_version", during["ota_id"] == "dev-000777" and during["game_version"] == before["game_version"], "ota %s game %s" % [during["ota_id"], during["game_version"]])
	t.check("native_identity_survives_ota_activation", during["native_build"] == before["native_build"] and during["native_version"] == before["native_version"] and during["native_source_sha"] == before["native_source_sha"], "")
	t.check("source_and_run_follow_active_ota", during["source_sha"] == "f".repeat(40) and during["build_run"] == "424242", "%s %s" % [during["source_sha"], during["build_run"]])
	t.check("save_schema_independent", during["save_schema"] == SaveSchema.SAVE_SCHEMA and typeof(during["save_schema"]) == TYPE_INT, str(during["save_schema"]))
	await t.frames(1)


# --- product / character identity, packaging ----------------------------------------------

func _presets() -> Dictionary:
	var cf := ConfigFile.new()
	cf.load("res://export_presets.cfg")
	var out := {}
	for sec in cf.get_sections():
		if sec.ends_with(".options"):
			continue
		out[cf.get_value(sec, "name")] = {"base": sec, "opt": sec + ".options", "cf": cf}
	return out


func _opt(presets: Dictionary, name: String, key: String) -> Variant:
	var e: Dictionary = presets[name]
	var cf: ConfigFile = e["cf"]
	for sec in [e["opt"], e["base"]]:
		if cf.has_section_key(sec, key):
			return cf.get_value(sec, key)
	return null


func _test_product_identity() -> void:
	# Owner-ruled names, held in one place.
	t.check("product_names_owner_ruled", GameVersion.PRODUCT_NAME == "Mote" and GameVersion.CHARACTER_NAME == "Gill", "%s / %s" % [GameVersion.PRODUCT_NAME, GameVersion.CHARACTER_NAME])
	var was: bool = g.hud._controls_visible
	g.hud.visible_controls(false)
	var hidden: bool = g.hud.prompts_shown()
	g.hud.visible_controls(true)
	t.check("prompts_hidden_with_controls_eg_on_title", not hidden and g.hud.prompts_shown(), "")
	g.hud.visible_controls(was)
	t.check("title_shows_MOTE_from_canonical", g.title.title_label.text == GameVersion.title() and GameVersion.title() == "MOTE", g.title.title_label.text)
	var diag: String = Boot.diagnostics_text()
	t.check("diagnostics_product_and_character", diag.contains("Product: Mote\n") and diag.contains("Character: Gill\n") and diag.begins_with("MOTE DIAGNOSTICS"), diag.get_slice("\n", 0))
	var id: Dictionary = Boot.identity()
	t.check("identity_product_separate", id["product"] == "Mote" and id["character"] == "Gill" and id["product"] != id["game_version"], "")
	# Packaging: labels follow the product name; package identities and build split unchanged.
	var pr := _presets()
	t.check("android_presets_present", pr.has("Android") and pr.has("Android Dev"), str(pr.keys()))
	t.check("app_label_normal_is_Mote", _opt(pr, "Android", "package/name") == GameVersion.PRODUCT_NAME, str(_opt(pr, "Android", "package/name")))
	t.check("app_label_dev_is_Mote_Dev", _opt(pr, "Android Dev", "package/name") == GameVersion.PRODUCT_NAME + " Dev", str(_opt(pr, "Android Dev", "package/name")))
	t.check("package_ids_unchanged", _opt(pr, "Android", "package/unique_name") == "com.verbal76.axolotl" and _opt(pr, "Android Dev", "package/unique_name") == "com.verbal76.axolotl.dev", "")
	t.check("normal_build_offline_no_ota", _opt(pr, "Android", "permissions/internet") == false and str(_opt(pr, "Android", "custom_features")) == "", "")
	t.check("dev_build_internet_and_ota", _opt(pr, "Android Dev", "permissions/internet") == true and str(_opt(pr, "Android Dev", "custom_features")).contains("ota_dev"), "")
	var icons_ok := true
	for preset in ["Android", "Android Dev"]:
		for key in ["launcher_icons/main_192x192", "launcher_icons/adaptive_foreground_432x432", "launcher_icons/adaptive_background_432x432", "launcher_icons/adaptive_monochrome_432x432"]:
			var path := str(_opt(pr, preset, key))
			icons_ok = icons_ok and path.begins_with("res://assets/icon/") and FileAccess.file_exists(path)
	t.check("launcher_icons_configured", icons_ok, "")
	# The app icon is the owner's artwork everywhere; the first placeholder icon is gone.
	var app_icon := str(ProjectSettings.get_setting("application/config/icon", ""))
	t.check("app_icon_is_owner_artwork", app_icon.begins_with("res://assets/icon/") and not FileAccess.file_exists("res://icon.svg"), app_icon)
	# No new exposition around the name, and the game's Motes keep their name.
	var bad := []
	for f in _all_files("res://scripts") + _all_files("res://scenes"):
		var src := FileAccess.get_file_as_string(f)
		for phrase in ["Gill's", "Meet Gill", "Help Gill", "Adventure"]:
			if src.contains(phrase) and not f.ends_with("ota_tests.gd"):
				bad.append("%s: %s" % [f, phrase])
		if f != "res://scripts/core/game_version.gd" and not f.ends_with("ota_tests.gd") and src.contains('"Gill'):
			bad.append("%s: extra copy of the character name" % f)
	t.check("no_new_exposition_or_name_copies", bad.is_empty(), ", ".join(bad))
	t.check("regeneration_motes_keep_their_name", ResourceLoader.exists("res://scripts/actors/mote.gd") and g.balls[0].motes.size() > 0 and g.balls[0].motes[0] is Mote, "")
	# Gill's six gills: all present at full size; health = colour/glow vs dull and faded.
	var m: AxolotlModel = g.player.model
	var saved := [g.player.health, g.player.max_health]
	m.set_health(2, 4, false)
	await t.frames(20)
	var all_full := m.gills.size() == 6
	for gl in m.gills:
		all_full = all_full and gl.scale.is_equal_approx(Vector3.ONE)
	var lit := true
	for i in 6:
		var glow: float = m.gill_mats[i].get_shader_parameter("glow")
		var desat: float = m.gill_mats[i].get_shader_parameter("desat")
		lit = lit and ((glow > 0.05 and desat < 0.01) if i < 2 else (glow == 0.0 and desat > 0.8))
	t.check("six_gills_always_full_size", all_full, "")
	t.check("gills_glow_when_active_dull_when_lost", lit, "")
	m.set_health(saved[0], saved[1], false)


func _all_files(dir: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_all_files(dir.path_join(d)))
	return out


func _literal_copies(dir: String, v: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		var p := dir.path_join(f)
		if not (f.ends_with(".gd") or f.ends_with(".tscn") or f.ends_with(".tres")):
			continue
		if p == "res://scripts/core/game_version.gd":
			continue
		if FileAccess.get_file_as_string(p).contains(v):
			out.append(p)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_literal_copies(dir.path_join(d), v))
	return out

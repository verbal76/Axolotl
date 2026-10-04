extends RefCounted
## OTA client and version/identity regression tests (run inside the unit suite).
## Uses a throwaway RSA key and scratch storage; never touches the real user://ota.

const OtaCore := preload("res://scripts/boot/ota_core.gd")
const OtaUpdater := preload("res://scripts/boot/ota_updater.gd")
const HttpStub := preload("res://scripts/tests/ota_http_stub.gd")
const BootScript := preload("res://scripts/boot/boot.gd")
const SoftRestart := preload("res://scripts/core/soft_restart.gd")
const UpdateActivationScript := preload("res://scripts/core/update_activation.gd")
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
	_test_runtime_generations()
	_test_auto_check_policy()
	_test_auto_update_policy()
	_test_auto_update_record()
	_test_soft_restart_health_accounting()
	await _test_soft_restart_mechanics()
	await _test_soft_restart_failure_keeps_game()
	await _test_update_client()
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
	# An OTA built for an older revision of this runtime: permanently unusable, not "update the app".
	c.device_save_schema = 0
	var old := c.validate_manifest(_manifest(1, p, {"runtime_id": "testos-godot-4.7.2-r0"}))
	t.check("ota_older_runtime_rejected_as_incompatible", old.begins_with("incompatible runtime"), old)


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


## The r3 -> r4 change: neither generation of app accepts the other's OTAs, and a package left
## over from before an APK upgrade is dropped (not treated as a crash) and the bundled game runs.
func _test_runtime_generations() -> void:
	var p := _payload("gen")
	var r3 := OtaCore.new(OS.get_user_data_dir().path_join("ota_gen3_%d" % Time.get_ticks_usec()), "android-godot-4.7.2-r3", "dev", _key.save_to_string(true), 1)
	var r4 := OtaCore.new(OS.get_user_data_dir().path_join("ota_gen4_%d" % Time.get_ticks_usec()), "android-godot-4.7.2-r4", "dev", _key.save_to_string(true), 1)
	var to_r3 := r4.validate_manifest(_manifest(12, p, {"runtime_id": "android-godot-4.7.2-r3"}))
	var to_r4 := r3.validate_manifest(_manifest(13, p, {"runtime_id": "android-godot-4.7.2-r4"}))
	t.check("ota_r4_app_rejects_r3_ota", to_r3.begins_with("incompatible runtime"), to_r3)
	t.check("ota_r3_app_rejects_r4_ota", to_r4.begins_with("native update required"), to_r4)
	var c := _core()
	c.state["current"] = _manifest(3, p, {"runtime_id": "testos-godot-4.7.2-r0"})
	c.save_state()
	c = _core(false)
	c.boot(func(_path: String) -> bool: return true)
	t.check("ota_older_runtime_package_dropped_after_app_upgrade", c.active.is_empty() and c.slot("current").is_empty() and not c.is_bad("dev-000003") and int(c.state["rollback_count"]) == 0, str(c.state["events"].get("load", {})))


func _test_auto_check_policy() -> void:
	var min_gap: int = BootScript.AUTO_CHECK_MIN_GAP_S * 1000
	var period: int = BootScript.AUTO_CHECK_PERIOD_S * 1000
	var ok := BootScript.auto_check_due("start", 5000, -1) and BootScript.auto_check_due("start", 5000, 4000)
	ok = ok and not BootScript.auto_check_due("resume", 10000, -1)
	ok = ok and not BootScript.auto_check_due("resume", 1000 + min_gap - 1, 1000) and BootScript.auto_check_due("resume", 1000 + min_gap, 1000)
	ok = ok and not BootScript.auto_check_due("periodic", 1000 + min_gap, 1000) and BootScript.auto_check_due("periodic", 1000 + period, 1000)
	t.check("ota_auto_check_policy", ok, "start always; resume after %d min; periodic every %d min" % [BootScript.AUTO_CHECK_MIN_GAP_S / 60, BootScript.AUTO_CHECK_PERIOD_S / 60])
	# The automatic check never runs before the game is up, nor in baseline mode, nor without OTA.
	t.check("ota_auto_check_waits_for_health_and_ota", not Boot.auto_check("start") if not Boot.ota_enabled else true, "")


# --- fully automatic updates (AutoUpdate policy + SoftRestart) ---------------------------------

func _test_auto_update_policy() -> void:
	# On/off switches.
	var none := PackedStringArray()
	t.check("autoupd_on_for_ota_builds", AutoUpdate.off_reason(true, "", none) == "", "")
	t.check("autoupd_off_without_ota_client", AutoUpdate.off_reason(false, "", none) != "", "")
	t.check("autoupd_off_in_test_runs", AutoUpdate.off_reason(true, "unit", none) != "", "")
	t.check("autoupd_off_for_check_and_quit_runs", AutoUpdate.off_reason(true, "", PackedStringArray(["--ota-quit-after-check"])) != "", "")
	t.check("autoupd_launch_check_honours_no_autocheck", AutoUpdate.off_reason(true, "", PackedStringArray(["--ota-no-autocheck"])) == ""
			and AutoUpdate.launch_check_off_reason(true, "", PackedStringArray(["--ota-no-autocheck"])) != "", "")

	# What may be applied: only a verified PENDING the native layer would load, once per id.
	var c := _core()
	var ok := func(_p: String) -> bool: return true
	t.check("autoupd_nothing_waiting", AutoUpdate.applicable(c, {})[1] == "no update waiting", "")
	var p1 := _payload("a1")
	_deliver(c, _manifest(1, p1), p1)
	c.boot(ok)
	c.mark_healthy()
	var p2 := _payload("a2")
	_deliver(c, _manifest(2, p2), p2)
	var r: Array = AutoUpdate.applicable(c, {})
	t.check("autoupd_verified_pending_applicable", (r[0] as Dictionary).get("ota_id") == "dev-000002" and r[1] == "", str(r[1]))
	r = AutoUpdate.applicable(c, {"dev-000002": {"result": "started"}})
	t.check("autoupd_once_per_ota_id", (r[0] as Dictionary).is_empty() and str(r[1]).contains("already tried"), str(r[1]))
	c.state["boot"] = {"ota_id": "dev-000002", "starts": OtaCore.MAX_UNHEALTHY_STARTS, "healthy_id": "dev-000001"}
	r = AutoUpdate.applicable(c, {})
	t.check("autoupd_not_after_unhealthy_starts", (r[0] as Dictionary).is_empty() and str(r[1]).contains("boot health"), str(r[1]))
	c.state["boot"] = {"ota_id": "dev-000001", "starts": 0, "healthy_id": "dev-000001"}
	c.state["disabled"] = true
	t.check("autoupd_not_in_baseline_mode", (AutoUpdate.applicable(c, {})[0] as Dictionary).is_empty(), "")
	c.state["disabled"] = false
	# Tampered after download: the native boot checks would reject it, so it is never applied.
	var cache := {}
	t.check("autoupd_cache_holds_verdict", (AutoUpdate.applicable(c, {}, cache)[0] as Dictionary).get("ota_id") == "dev-000002" and cache.size() == 1, str(cache))
	_write(c.package_path("dev-000002"), _payload("a2-tampered"))
	r = AutoUpdate.applicable(c, {})
	t.check("autoupd_never_applies_what_native_rejects", (r[0] as Dictionary).is_empty() and str(r[1]).contains("would not be loaded by the native layer"), str(r[1]))
	t.check("autoupd_shallow_mode_skips_hash", (AutoUpdate.applicable(c, {}, {}, false)[0] as Dictionary).get("ota_id") == "dev-000002", "")
	(c.state["bad"] as Array).append("dev-000002")
	t.check("autoupd_never_applies_rejected", str(AutoUpdate.applicable(c, {})[1]).contains("rejected"), "")
	var c2 := _core()
	var p3 := _payload("a3")
	_deliver(c2, _manifest(3, p3), p3)
	c2.boot(ok)
	t.check("autoupd_running_pending_not_reapplied", str(AutoUpdate.applicable(c2, {})[1]).contains("already running"), "")

	# Safe moments.
	var title := {"ready_done": true, "state": "title", "title_visible": true, "healthy": true}
	var play := {"ready_done": true, "state": "play", "title_visible": false, "healthy": true}
	t.check("autoupd_safe_on_title", AutoUpdate.safe_moment("title", title) == "", "")
	t.check("autoupd_never_mid_play", AutoUpdate.safe_moment("title", play) != "", AutoUpdate.safe_moment("title", play))
	t.check("autoupd_safe_on_resume_in_play", AutoUpdate.safe_moment("resume", play) == "", "")
	t.check("autoupd_safe_on_resume_on_title", AutoUpdate.safe_moment("resume", title) == "", "")
	var blocked := true
	for k in ["paused", "menu_open", "cinematic", "lesson", "card", "presentation", "ending", "updater_busy"]:
		for base in [title, play]:
			for where in ["title", "resume"]:
				blocked = blocked and AutoUpdate.safe_moment(where, base.merged({k: true}, true)) != ""
	t.check("autoupd_never_in_menus_cinematics_lessons", blocked, "")
	t.check("autoupd_running_version_must_be_healthy", AutoUpdate.safe_moment("title", title.merged({"healthy": false}, true)) != ""
			and AutoUpdate.safe_moment("resume", play.merged({"healthy": false}, true)) != "", "")
	t.check("autoupd_aquarium_not_safe", AutoUpdate.safe_moment("resume", play.merged({"state": "aquarium"}, true)) != "", "")
	t.check("autoupd_launch_only_before_ready", AutoUpdate.safe_moment("launch", {"ready_done": false}) == "" and AutoUpdate.safe_moment("launch", title) != "", "")
	t.check("autoupd_launch_wait_capped", not AutoUpdate.wait_over(0, true, AutoUpdate.CHECK_WAIT_MS) and not AutoUpdate.wait_over(AutoUpdate.CHECK_WAIT_MS - 1, true, AutoUpdate.CHECK_WAIT_MS)
			and AutoUpdate.wait_over(AutoUpdate.CHECK_WAIT_MS, true, AutoUpdate.CHECK_WAIT_MS) and AutoUpdate.wait_over(5, false, AutoUpdate.CHECK_WAIT_MS), "cap %d ms" % AutoUpdate.CHECK_WAIT_MS)
	t.check("autoupd_launch_answer_cap_about_3s", AutoUpdate.CHECK_WAIT_MS <= 3000, "")


func _test_auto_update_record() -> void:
	var saved_path: String = SoftRestart.record_path
	SoftRestart.record_path = OS.get_user_data_dir().path_join("autoupd_record_%d.json" % Time.get_ticks_usec())
	t.check("autoupd_record_empty", SoftRestart.record_read()["attempts"].is_empty() and not SoftRestart.was_attempted("dev-000009"), "")
	SoftRestart.record_attempt("dev-000009", "dev-000008", "title")
	var a: Dictionary = SoftRestart.record_read()["attempts"]
	t.check("autoupd_record_attempt_before_change", SoftRestart.was_attempted("dev-000009") and a["dev-000009"]["result"] == "started" and a["dev-000009"]["from"] == "dev-000008", str(a))
	SoftRestart.record_result("dev-000009", "applied")
	var d := SoftRestart.record_read()
	t.check("autoupd_record_result", d["attempts"]["dev-000009"]["result"] == "applied" and d["last"]["ota_id"] == "dev-000009" and d["last"]["result"] == "applied", str(d["last"]))
	for i in SoftRestart.RECORD_KEEP + 5:
		SoftRestart.record_attempt("dev-%06d" % (100 + i), "x", "title")
	d = SoftRestart.record_read()
	t.check("autoupd_record_bounded", (d["attempts"] as Dictionary).size() == SoftRestart.RECORD_KEEP and (d["order"] as Array).size() == SoftRestart.RECORD_KEEP, "")
	_write(SoftRestart.record_path, "{broken".to_utf8_buffer())
	t.check("autoupd_record_corrupt_is_empty", SoftRestart.record_read()["attempts"].is_empty(), "")
	DirAccess.remove_absolute(SoftRestart.record_path)
	SoftRestart.record_path = saved_path


## The native state machine after an IN-PROCESS mount (what SoftRestart.apply drives through
## OtaCore.boot): the start is counted before the mount, health promotes PENDING -> CURRENT and
## CURRENT -> PREVIOUS, an update that never becomes healthy is abandoned after the same number
## of starts, and rollback still works.
func _test_soft_restart_health_accounting() -> void:
	var c := _core()
	var ok := func(_p: String) -> bool: return true
	var p1 := _payload("s1")
	_deliver(c, _manifest(1, p1), p1)
	c.boot(ok)
	c.mark_healthy()
	var p2 := _payload("s2")
	_deliver(c, _manifest(2, p2), p2)
	# In-process: the same core object (Boot.core) boots again while dev-000001 runs.
	var mounted: Array[String] = []
	var picked := c.boot(func(path: String) -> bool:
		mounted.append(path.get_file())
		return true)
	t.check("autoupd_inprocess_mounts_pending_only", picked.get("ota_id") == "dev-000002" and mounted == ["dev-000002.pck"], str(mounted))
	t.check("autoupd_inprocess_start_counted_before_health", c.state["boot"]["ota_id"] == "dev-000002" and int(c.state["boot"]["starts"]) == 1 and c.slot("pending")["ota_id"] == "dev-000002", str(c.state["boot"]))
	c.mark_healthy()
	t.check("autoupd_inprocess_health_promotes", c.slot("current")["ota_id"] == "dev-000002" and c.slot("previous")["ota_id"] == "dev-000001" and c.slot("pending").is_empty(), "")
	t.check("autoupd_inprocess_rollback_still_works", c.rollback() == "" and c.slot("current")["ota_id"] == "dev-000001" and c.is_bad("dev-000002"), "")
	# An update applied in-process that never reaches health: the cold starts that follow count
	# on from the in-process start and abandon it exactly as before.
	var p3 := _payload("s3")
	_deliver(c, _manifest(3, p3), p3)
	c = _core(false)
	c.boot(ok)
	c.mark_healthy()
	var p4 := _payload("s4")
	_deliver(c, _manifest(4, p4), p4)
	c.boot(ok)   # in-process, never healthy
	var c2 := _core(false)   # cold start 1
	c2.boot(ok)
	t.check("autoupd_unhealthy_inprocess_counts", c2.active.get("ota_id") == "dev-000004" and int(c2.state["boot"]["starts"]) == 2, str(c2.state["boot"]))
	var c3 := _core(false)   # cold start 2
	c3.boot(ok)
	t.check("autoupd_unhealthy_inprocess_abandoned", c3.active.get("ota_id") == "dev-000003" and c3.is_bad("dev-000004") and c3.slot("pending").is_empty(), "active %s" % c3.active.get("ota_id", "baseline"))


## The engine mechanism, in this process: a script and a preloaded resource cached from one pack
## are replaced in place by a second pack (same path), class_name-free and with live code paths
## untouched outside the reloaded directory.
func _test_soft_restart_mechanics() -> void:
	var dir := OS.get_user_data_dir().path_join("autoupd_mech_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(dir)
	var packs: Array[String] = []
	for v in [1, 2]:
		var src := dir.path_join("probe_%d.gd" % v)
		var res := dir.path_join("data_%d.tres" % v)
		_write(src, ('extends RefCounted\nconst DATA := preload("res://autoupd_probe/data.tres")\nconst V := %d\nstatic var calls := 0\nstatic func describe() -> String:\n\tcalls += 1\n\treturn "v%%d %%s calls=%%d" %% [V, DATA.get_meta("text"), calls]\n%s' % [v, "static func only_v2() -> int:\n\treturn 2\n" if v == 2 else ""]).to_utf8_buffer())
		_write(res, ('[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/text = "data-v%d"\n' % v).to_utf8_buffer())
		var inc := dir.path_join("inc_%d.gdshaderinc" % v)
		var shd := dir.path_join("probe_%d.gdshader" % v)
		_write(inc, ("float probe_value() { return %d.0; }\n" % v).to_utf8_buffer())
		_write(shd, ('shader_type spatial;\n#include "res://autoupd_probe/inc.gdshaderinc"\n// v%d\nvoid fragment() { ALBEDO = vec3(probe_value()); }\n' % v).to_utf8_buffer())
		var pck := dir.path_join("p%d.pck" % v)
		var pk := PCKPacker.new()
		pk.pck_start(pck)
		pk.add_file("res://autoupd_probe/probe.gd", src)
		pk.add_file("res://autoupd_probe/data.tres", res)
		pk.add_file("res://autoupd_probe/inc.gdshaderinc", inc)
		pk.add_file("res://autoupd_probe/probe.gdshader", shd)
		pk.flush()
		packs.append(pck)
	ProjectSettings.load_resource_pack(packs[0], true)
	var s: Script = load("res://autoupd_probe/probe.gd")
	var before: String = s.call("describe")
	var shader: Shader = load("res://autoupd_probe/probe.gdshader")
	var include: Resource = load("res://autoupd_probe/inc.gdshaderinc")
	ProjectSettings.load_resource_pack(packs[1], true)
	var stale: String = s.call("describe")
	var r := SoftRestart.reload_game_layer([], "res://autoupd_probe")
	var s2: Script = load("res://autoupd_probe/probe.gd")
	var after: String = s2.call("describe")
	t.check("autoupd_mech_cached_code_is_stale_until_reloaded", before == "v1 data-v1 calls=1" and stale.begins_with("v1 data-v1"), "%s / %s" % [before, stale])
	# (Static vars restart in export templates; the editor binary used by the tests keeps them.)
	t.check("autoupd_mech_script_replaced_in_place", s2 == s and after.begins_with("v2 data-v2 calls=") and s.has_method("only_v2"), after)
	t.check("autoupd_mech_reload_report", int(r["scripts"]) == 1 and int(r["resources"]) == 3 and (r["errors"] as Array).is_empty(), str(r))
	t.check("autoupd_mech_shader_and_include_updated_in_place", load("res://autoupd_probe/probe.gdshader") == shader and shader.code.contains("// v2")
			and str(include.get("code")).contains("return 2.0"), shader.code.left(80))
	t.check("autoupd_mech_native_never_reloaded", SoftRestart.is_native("res://scripts/boot/boot.gd") and SoftRestart.is_native("res://scripts/generated/native_build_info.gd")
			and not SoftRestart.is_native("res://scripts/core/game.gd"), "")


## A soft restart that cannot go ahead leaves the running game exactly as it was: a failed save
## stops it before anything else, and a package the native layer does not mount stops it before
## anything is torn down. Both are recorded.
func _test_soft_restart_failure_keeps_game() -> void:
	var saved := [Boot.core, Boot.ota_enabled, SoftRestart.record_path]
	SoftRestart.record_path = OS.get_user_data_dir().path_join("autoupd_fail_%d.json" % Time.get_ticks_usec())
	var c := _core()
	var p1 := _payload("f1")
	_deliver(c, _manifest(1, p1), p1)   # a "package" that is not a real pack: mounting fails
	Boot.core = c
	var game: Node = g
	var why: String = await SoftRestart.apply(c.slot("pending"), "title", func() -> String: return "disk full")
	t.check("autoupd_save_failure_stops_update", why.contains("progress could not be saved") and c.slot("pending")["ota_id"] == "dev-000001"
			and int(c.state["boot"]["starts"]) == 0 and SoftRestart.record_read()["last"]["result"].begins_with("not applied"), why)
	var boot_before: Dictionary = (c.state["boot"] as Dictionary).duplicate()
	why = await SoftRestart.apply(c.slot("pending"), "title", func() -> String: return "")
	await t.frames(2)
	t.check("autoupd_unmountable_keeps_game", why.contains("did not mount") and is_instance_valid(game) and game.is_inside_tree()
			and get_tree_root().get_node_or_null(SoftRestart.CURTAIN_NAME) == null and Settings.get_script() != null, why)
	t.check("autoupd_unmountable_native_semantics", c.is_bad("dev-000001") and c.active.is_empty() and c.state["boot"] == boot_before, str(c.state["boot"]))
	t.check("autoupd_failure_recorded", str(SoftRestart.record_read()["last"]["result"]).contains("not applied"), str(SoftRestart.record_read()["last"]))
	var act: Dictionary = UpdateActivationScript.state()
	t.check("autoupd_unmountable_activation_failed", act.get("state", "") == "failed" and act.get("ota_id", "") == "dev-000001"
			and not UpdateActivationScript.is_applying(), str(act))
	Boot.core = saved[0]
	Boot.ota_enabled = saved[1]
	DirAccess.remove_absolute(SoftRestart.record_path)
	SoftRestart.record_path = saved[2]


func get_tree_root() -> Window:
	return (Engine.get_main_loop() as SceneTree).root


## Serves a signed update from the local stub and returns its manifest.
func _publish(srv, seq: int, payload: PackedByteArray, over := {}, sig := "") -> Dictionary:
	var id := "dev-%06d" % seq
	var m := _manifest(seq, payload, {"pck_url": srv.url("/%s.pck" % id)})
	m.merge(over, true)
	var s := _sign(m)
	srv.routes["/%s/manifest.json" % id] = s[0]
	srv.routes["/%s/manifest.json.sig" % id] = (sig if sig != "" else s[1]).to_utf8_buffer()
	srv.routes["/%s.pck" % id] = payload
	srv.routes["/latest.json"] = JSON.stringify({"channel": "dev", "ota_id": id, "seq": seq,
			"manifest_url": srv.url("/%s/manifest.json" % id), "signature_url": srv.url("/%s/manifest.json.sig" % id)}).to_utf8_buffer()
	return m


## The real update client against a local server: offline, hung server, discovery, runtime,
## signature, hash and interrupted downloads. Gameplay keeps running the whole time.
func _test_update_client() -> void:
	var srv := HttpStub.new()
	g.add_child(srv)
	if srv.start() == 0:
		t.check("ota_stub_server_listens", false, "no free port")
		return
	var c := _core()
	c.allow_local_http = true
	var up := OtaUpdater.new()
	up.core = c
	up.timeout = 10.0
	up.process_mode = Node.PROCESS_MODE_ALWAYS
	g.add_child(up)
	var known := _manifest(4, _payload("known"))
	_deliver(c, known, _payload("known"))

	# No network: nothing listens on the channel. The game keeps playing while the check runs.
	up.pointer_url = "http://127.0.0.1:%d/latest.json" % (srv.port + 1000)
	var pl: Axolotl = g.player
	var start_pos := pl.global_position
	var f0 := Engine.get_physics_frames()
	pl.bot_input = Vector2(0, 1)
	var r: String = await up.check(true)
	await t.frames(30)
	pl.bot_input = Vector2.ZERO
	var moved := pl.global_position.distance_to(start_pos)
	t.check("ota_offline_check_nonfatal", r.begins_with("channel unreachable") and up.status == "offline" and c.slot("pending")["ota_id"] == "dev-000004", r)
	t.check("ota_offline_gameplay_continues", moved > 0.5 and g.state == "play" and Engine.get_physics_frames() > f0, "moved %.2f m, %d frames" % [moved, Engine.get_physics_frames() - f0])

	# A server that accepts and never answers: the game runs on; the check times out cleanly.
	srv.routes["/latest.json"] = "{}".to_utf8_buffer()
	srv.modes["/latest.json"] = "hang"
	up.pointer_url = srv.url("/latest.json")
	up.timeout = 2.0
	f0 = Engine.get_physics_frames()
	r = await up.check(true)
	var waited := Engine.get_physics_frames() - f0
	t.check("ota_hanging_server_does_not_block", r.begins_with("channel unreachable") and waited >= 60 and c.slot("pending")["ota_id"] == "dev-000004", "%s after %d frames of play" % [r, waited])
	srv.modes.erase("/latest.json")
	up.timeout = 10.0

	# A compatible signed update is discovered, downloaded, verified and staged.
	var m5 := _publish(srv, 5, _payload("five"))
	r = await up.check(true)
	t.check("ota_check_discovers_and_stages_update", r == "dev-000005 ready: restart to run it" and c.slot("pending")["ota_id"] == "dev-000005" and up.status == "downloaded" and up.latest_compat == "compatible", r)
	r = await up.check(true)
	t.check("ota_check_up_to_date", up.status == "up_to_date", r)

	# Wrong runtime (older and newer), bad signature, bad hash: nothing replaces dev-000005.
	_publish(srv, 6, _payload("six"), {"runtime_id": "testos-godot-4.7.2-r0"})
	r = await up.check(true)
	t.check("ota_client_ignores_older_runtime", up.status == "incompatible" and r.contains("incompatible runtime") and c.slot("pending")["ota_id"] == "dev-000005", r)
	_publish(srv, 7, _payload("seven"), {"runtime_id": "testos-godot-4.7.2-r2"})
	r = await up.check(true)
	t.check("ota_client_newer_runtime_needs_new_app", up.status == "incompatible" and r.contains("native update required") and c.slot("pending")["ota_id"] == "dev-000005", r)
	var other := Crypto.new().generate_rsa(2048)
	var p8 := _payload("eight")
	var m8 := _manifest(8, p8, {"pck_url": srv.url("/dev-000008.pck")})
	var forged := Marshalls.raw_to_base64(Crypto.new().sign(HashingContext.HASH_SHA256, OtaCore.sha256_bytes(_sign(m8)[0]), other))
	_publish(srv, 8, p8, {}, forged)
	r = await up.check(true)
	t.check("ota_client_rejects_bad_signature", up.status == "rejected" and r.contains("signature verification failed") and c.slot("pending")["ota_id"] == "dev-000005", r)
	var p9 := _payload("nine")
	_publish(srv, 9, p9)
	var evil := p9.duplicate()
	evil[0] = evil[0] ^ 0xFF
	srv.routes["/dev-000009.pck"] = evil
	r = await up.check(true)
	t.check("ota_client_rejects_bad_hash", up.status == "rejected" and r.contains("SHA-256 mismatch") and c.slot("pending")["ota_id"] == "dev-000005" and not FileAccess.file_exists(c.package_path("dev-000009")), r)

	# Interrupted download: the partial file is discarded and the known-good package stays.
	var p10 := ("ten " + "x".repeat(4000)).to_utf8_buffer()
	_publish(srv, 10, p10)
	srv.modes["/dev-000010.pck"] = "truncate"
	r = await up.check(true)
	t.check("ota_interrupted_download_keeps_known_good", up.status == "failed" and c.slot("pending")["ota_id"] == "dev-000005" and not FileAccess.file_exists(c.incoming_path("dev-000010")) and not FileAccess.file_exists(c.package_path("dev-000010")) and FileAccess.file_exists(c.package_path("dev-000005")), r)
	srv.modes.erase("/dev-000010.pck")
	r = await up.download_available()
	t.check("ota_download_retry_after_interruption", r == "dev-000010 ready: restart to run it" and c.slot("pending")["ota_id"] == "dev-000010", r)

	# The latest OTA is the very game this app bundles: up to date, nothing downloaded; a newer
	# one still arrives.
	var fresh := _core()
	fresh.allow_local_http = true
	var up2 := OtaUpdater.new()
	up2.core = fresh
	up2.timeout = 10.0
	up2.process_mode = Node.PROCESS_MODE_ALWAYS
	up2.pointer_url = srv.url("/latest.json")
	up2.bundled_source_sha = "%040x" % 11
	g.add_child(up2)
	_publish(srv, 11, _payload("eleven"))
	r = await up2.check(true)
	t.check("ota_bundled_game_is_up_to_date", up2.status == "up_to_date" and r.contains("bundled in this app") and fresh.slot("pending").is_empty() and not FileAccess.file_exists(fresh.package_path("dev-000011")), r)
	_publish(srv, 12, _payload("twelve"))
	r = await up2.check(true)
	t.check("ota_newer_than_bundled_still_downloads", r == "dev-000012 ready: restart to run it" and fresh.slot("pending")["ota_id"] == "dev-000012", r)
	up2.queue_free()
	_publish(srv, 10, p10)   # the channel points at dev-000010 again for the checks below

	# Diagnostics: bundled baseline vs active OTA vs latest on channel vs pending, and status.
	var saved := [Boot.core, Boot.updater, Boot.ota_enabled]
	Boot.core = c
	Boot.updater = up
	Boot.ota_enabled = true
	var d1: String = Boot.diagnostics_text()
	var ok1 := d1.contains("  Active: bundled baseline\n") and d1.contains("  Latest on channel: dev-000010 (checked ") \
			and d1.contains("  Pending (runs after restart): dev-000010 ") and d1.contains("  Status: Update downloaded: dev-000010 runs after the app restarts\n") \
			and d1.contains("  Bundled baseline: ") and d1.contains("  Enabled: yes\n")
	c.active = c.slot("pending")
	c.mark_healthy()
	r = await up.check(true)
	var d2: String = Boot.diagnostics_text()
	var ok2 := d2.contains("  Active: dev-000010 (source %s)\n" % ("%040x" % 10)) and d2.contains("  Status: Up to date\n") \
			and d2.contains("  Pending (runs after restart): none\n") and d2.contains("latest OTA compatible\n")
	c.set_disabled(true)
	var d3: String = Boot.diagnostics_text()
	var ok3 := d3.contains("  Status: OTA disabled: running the bundled baseline")
	c.set_disabled(false)
	up.status = "unchecked"
	up.remote = {}
	var d4: String = Boot.diagnostics_text()
	var ok4 := d4.contains("  Status: Not checked yet\n") and d4.contains("  Latest on channel: not checked yet\n")
	Boot.core = saved[0]
	Boot.updater = saved[1]
	Boot.ota_enabled = saved[2]
	t.check("ota_diagnostics_bundled_active_latest", ok1 and ok2 and ok3 and ok4, "%s %s %s %s" % [ok1, ok2, ok3, ok4])
	if not (ok1 and ok2):
		t.log_line(d1)
		t.log_line(d2)
	up.queue_free()
	srv.stop()
	srv.queue_free()
	await t.frames(1)


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
	# (Studio convention 2026-10-04: the title shows the public version "vN", not the semantic one.)
	t.check("title_shows_public_version", shown == GameVersion.display() and not shown.contains(expect), "title shows '%s'" % shown)
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
	# Owner decision: ONE Android app, Mote. The separate Mote Dev app is retired.
	var android := pr.keys().filter(func(k) -> bool: return _opt(pr, k, "platform") == "Android")
	t.check("android_single_app_preset", android == ["Android"], str(android))
	t.check("app_label_normal_is_Mote", _opt(pr, "Android", "package/name") == GameVersion.PRODUCT_NAME, str(_opt(pr, "Android", "package/name")))
	t.check("package_ids_unchanged", _opt(pr, "Android", "package/unique_name") == "com.verbal76.axolotl", "")
	# Owner ruling: the Mote app itself receives OTAs (offline-capable, not offline-only).
	var cfg: Script = load("res://scripts/boot/ota_config.gd")
	var feature: String = cfg.get_script_constant_map()["FEATURE"]
	t.check("normal_build_ota_capable", _opt(pr, "Android", "permissions/internet") == true and str(_opt(pr, "Android", "custom_features")).split(",").has(feature), str(_opt(pr, "Android", "custom_features")))
	t.check("android_shader_baker_on", _opt(pr, "Android", "shader_baker/enabled") == true, "")
	t.check("ios_build_has_no_ota", pr.has("iOS") and not str(_opt(pr, "iOS", "custom_features")).split(",").has(feature), "")
	var icons_ok := true
	for preset in ["Android"]:
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
		# Any string literal naming the character outside the canonical source is a copy.
		if f != "res://scripts/core/game_version.gd" and not f.ends_with("ota_tests.gd") and _name_in_string.search(src) != null:
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


var _name_in_string := RegEx.create_from_string('"[^"\\n]*\\bGill\\b[^"\\n]*"')


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

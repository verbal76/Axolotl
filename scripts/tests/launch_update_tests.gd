extends RefCounted
## "Check first, wait briefly" (owner, 2026-10-04; ledger row 40): at launch the update channel is
## asked BEFORE the world is built (answer awaited at most AutoUpdate.CHECK_WAIT_MS); a newer
## version is downloaded (capped) and activated before anything is built. Drives
## AutoUpdate.launch_precheck with the REAL native update client (OtaUpdater + OtaCore) against
## the test HTTP server; only the activation itself (the soft restart) is replaced by a recorder.
## Runs inside the unit suite (--only=_test_launch_update).

const OtaTests := preload("res://scripts/tests/ota_tests.gd")
const OtaUpdater := preload("res://scripts/boot/ota_updater.gd")
const HttpStub := preload("res://scripts/tests/ota_http_stub.gd")

var t
var g: Game
var ota
var srv
var _au: AutoUpdate


## Records the loading-screen lines the pre-check shows.
class FakeLoading:
	var stages := []
	func set_stage(text: String) -> void:
		stages.append(text)


func _init(runner) -> void:
	t = runner
	g = runner.g
	ota = OtaTests.new(runner)


func run() -> void:
	_test_skip_policy()
	_test_skipped_in_this_run()
	_test_order_in_game_source()
	srv = HttpStub.new()
	g.add_child(srv)
	if srv.start() == 0:
		t.check("launch_stub_server_listens", false, "no free port")
		return
	_au = AutoUpdate.new()
	g.add_child(_au)
	var saved_meta: Variant = Engine.get_meta(AutoUpdate.LAUNCH_META, null)
	var saved_marks: Array = StartupTrace.marks.duplicate()
	await _test_no_update()
	await _test_offline_and_silent_channel()
	await _test_update_found()
	await _test_download_failure()
	StartupTrace.marks = saved_marks
	if saved_meta != null:
		Engine.set_meta(AutoUpdate.LAUNCH_META, saved_meta)
	_au.queue_free()
	srv.queue_free()


# --- helpers ---------------------------------------------------------------------------------

func _updater(core, pointer: String) -> OtaUpdater:
	var up := OtaUpdater.new()
	up.core = core
	up.timeout = 10.0
	up.process_mode = Node.PROCESS_MODE_ALWAYS
	up.pointer_url = pointer
	g.add_child(up)
	return up


func _core():
	var c = ota._core()
	c.allow_local_http = true
	return c


## Runs the pre-check; returns [result, wall ms, calls (check/download/activate in order)].
func _run(up: OtaUpdater, loading: FakeLoading, extra := {}) -> Array:
	var calls: Array[String] = []
	var on_check := func(n: Node) -> void:
		if n is HTTPRequest:
			calls.append("download" if up.status == "downloading" else "check")
	up.child_entered_tree.connect(on_check)
	var deps := {"updater": up,
			"candidate": func() -> Array: return AutoUpdate.applicable(up.core, extra.get("attempts", {})),
			"activate": func(m: Dictionary) -> String:
				calls.append("activate " + str(m.get("ota_id", "?")))
				return str(extra.get("activate_result", ""))}
	for k in ["check_wait_ms", "download_cap_ms"]:
		if extra.has(k):
			deps[k] = extra[k]
	var t0 := Time.get_ticks_msec()
	var r: String = await _au.launch_precheck(loading, deps)
	var ms := Time.get_ticks_msec() - t0
	up.child_entered_tree.disconnect(on_check)
	# Collapse the per-request entries: one "check" (pointer, manifest, signature), one "download".
	var seq := []
	for c in calls:
		if seq.is_empty() or seq[-1] != c:
			seq.append(c)
	return [r, ms, seq]


func _settle(up: OtaUpdater) -> void:
	while up.busy:
		await t.frames(5)


# --- policy ------------------------------------------------------------------------------------

## Skipped on scene reloads, on the re-entry after a soft restart, in test and check-and-quit runs,
## when automatic updates or checks are turned off, in baseline mode and while a check runs.
func _test_skip_policy() -> void:
	var none := PackedStringArray()
	var go := AutoUpdate.precheck_skip_reason(true, "", none, false, false, false, false)
	var bad: Array[String] = []
	var cases := {
		"reload": AutoUpdate.precheck_skip_reason(true, "", none, true, false, false, false),
		"soft restart": AutoUpdate.precheck_skip_reason(true, "", none, false, true, false, false),
		"test run": AutoUpdate.precheck_skip_reason(true, "unit", none, false, false, false, false),
		"playthrough": AutoUpdate.precheck_skip_reason(true, "playthrough", none, false, false, false, false),
		"no auto update": AutoUpdate.precheck_skip_reason(true, "", PackedStringArray(["--no-auto-update"]), false, false, false, false),
		"no autocheck": AutoUpdate.precheck_skip_reason(true, "", PackedStringArray(["--ota-no-autocheck"]), false, false, false, false),
		"check and quit": AutoUpdate.precheck_skip_reason(true, "", PackedStringArray(["--ota-quit-after-check"]), false, false, false, false),
		"no OTA client": AutoUpdate.precheck_skip_reason(false, "", none, false, false, false, false),
		"baseline mode": AutoUpdate.precheck_skip_reason(true, "", none, false, false, true, false),
		"check running": AutoUpdate.precheck_skip_reason(true, "", none, false, false, false, true),
	}
	for k in cases:
		if cases[k] == "":
			bad.append(k)
	t.check("launch_precheck_runs_on_genuine_launch", go == "", go)
	t.check("launch_precheck_skipped_reload_test_off", bad.is_empty(), "not skipped: " + ", ".join(bad))
	var next_ok: bool = AutoUpdate.precheck_next(false, "available", true) == "download"
	for c in [[true, "available", true], [false, "up_to_date", false], [false, "offline", false], [false, "incompatible", false],
			[false, "rejected", false], [false, "failed", false], [false, "available", false], [true, "checking", false]]:
		next_ok = next_ok and AutoUpdate.precheck_next(c[0], c[1], c[2]) == "start"
	t.check("launch_precheck_downloads_only_a_found_update", next_ok, "")
	t.check("launch_precheck_caps", AutoUpdate.CHECK_WAIT_MS <= 3000 and AutoUpdate.CHECK_WAIT_MS >= 1000
			and AutoUpdate.DOWNLOAD_CAP_MS <= 60000 and AutoUpdate.DOWNLOAD_CAP_MS >= 15000
			and not AutoUpdate.wait_over(AutoUpdate.CHECK_WAIT_MS - 1, true, AutoUpdate.CHECK_WAIT_MS)
			and AutoUpdate.wait_over(AutoUpdate.CHECK_WAIT_MS, true, AutoUpdate.CHECK_WAIT_MS) and AutoUpdate.wait_over(5, false, AutoUpdate.CHECK_WAIT_MS),
			"answer %d ms, download %d ms" % [AutoUpdate.CHECK_WAIT_MS, AutoUpdate.DOWNLOAD_CAP_MS])


## This (test) launch: the pre-check was skipped, recorded for Diagnostics, before any world building.
func _test_skipped_in_this_run() -> void:
	var at := -1.0
	for m in StartupTrace.marks:
		if str(m[0]).begins_with("game: launch update check skipped ("):
			at = m[1] / 1000.0
			break
	var info: Dictionary = Engine.get_meta(AutoUpdate.LAUNCH_META, {})
	t.check("launch_precheck_skipped_in_test_runs", at >= 0.0 and at < StartupTrace.ms("aquarium built")
			and str(info.get("result", "")).begins_with("not checked: "), "%s at %.1f ms" % [info.get("result", "?"), at])


## Game._ready asks first: the pre-check (and its early return) comes before the world is built.
func _test_order_in_game_source() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/core/game.gd")
	var a := src.find("await auto_update.launch_precheck(loading) == \"activating\":\n\t\treturn")
	var b := src.find("\tawait _build_world()")
	t.check("launch_precheck_before_world_build", a > 0 and b > a, "precheck at %d, build at %d" % [a, b])


# --- the real update client ----------------------------------------------------------------------

## Up to date: the launch goes on as soon as the channel answers; nothing downloaded or activated.
func _test_no_update() -> void:
	var c = _core()
	var p: PackedByteArray = ota._payload("one")
	ota._deliver(c, ota._manifest(1, p), p)
	ota._publish(srv, 1, p)
	var up := _updater(c, srv.url("/latest.json"))
	var lo := FakeLoading.new()
	var r: Array = await _run(up, lo)
	t.check("launch_no_update_no_delay", str(r[0]).contains("up to date") and int(r[1]) < 1500 and r[2] == ["check"] and lo.stages.is_empty(),
			"%s in %d ms, %s" % [r[0], r[1], r[2]])
	up.queue_free()


## Offline (nothing listens) or a server that never answers: the launch starts within ~3 s and the
## check carries on in the background; a late answer is still acted on.
func _test_offline_and_silent_channel() -> void:
	var c = _core()
	var up := _updater(c, "http://127.0.0.1:%d/latest.json" % (srv.port + 1000))
	var r: Array = await _run(up, FakeLoading.new())
	t.check("launch_offline_starts_at_once", str(r[0]).contains("channel unreachable") and int(r[1]) < AutoUpdate.CHECK_WAIT_MS and r[2] == ["check"],
			"%s in %d ms" % [r[0], r[1]])
	up.queue_free()
	srv.routes["/latest.json"] = "{}".to_utf8_buffer()
	srv.modes["/latest.json"] = "hang"
	up = _updater(c, srv.url("/latest.json"))
	# (HTTPRequest's timeout runs on game time, which outruns the wall clock under --fixed-fps.)
	up.timeout = 30.0
	r = await _run(up, FakeLoading.new())
	var still: bool = up.busy
	t.check("launch_silent_channel_starts_within_3s", str(r[0]).begins_with("no answer within") and still
			and int(r[1]) >= AutoUpdate.CHECK_WAIT_MS and int(r[1]) < AutoUpdate.CHECK_WAIT_MS + 600, "%s in %d ms" % [r[0], r[1]])
	srv.modes.erase("/latest.json")
	await _settle(up)
	t.check("launch_silent_channel_check_finishes_later", up.status == "offline" and not up.busy, up.status_detail)
	up.queue_free()


## A newer compatible version: checked, then downloaded and verified (the loading screen says so),
## then activated, all before the caller builds anything. It is never activated twice.
func _test_update_found() -> void:
	var c = _core()
	var p: PackedByteArray = ota._payload("two")
	ota._publish(srv, 2, p)
	var up := _updater(c, srv.url("/latest.json"))
	var lo := FakeLoading.new()
	var attempts := {}
	var r: Array = await _run(up, lo, {"attempts": attempts})
	t.check("launch_update_download_then_activate", r[0] == "activating" and r[2] == ["check", "download", "activate dev-000002"]
			and str(c.slot("pending").get("ota_id", "")) == "dev-000002" and lo.stages == [AutoUpdate.DOWNLOAD_STAGE],
			"%s in %d ms, %s, stages %s" % [r[0], r[1], r[2], lo.stages])
	# Recorded before anything changes (SoftRestart.record_attempt): a second try is refused.
	attempts["dev-000002"] = {"result": "started"}
	var again: Array = AutoUpdate.applicable(c, attempts)
	# An activation that does not go ahead is tried once; the launch then starts this version.
	var p3: PackedByteArray = ota._payload("three")
	ota._publish(srv, 3, p3)
	var r2: Array = await _run(up, FakeLoading.new(), {"activate_result": "the native layer did not mount it"})
	var once: bool = (r2[2] as Array).count("activate dev-000003") == 1 and str(r2[0]).contains("did not go ahead")
	t.check("launch_update_never_activates_twice", (again[0] as Dictionary).is_empty() and str(again[1]).contains("already tried") and once,
			"%s; %s %s" % [again[1], r2[0], r2[2]])
	up.queue_free()


## A failed or late download: the launch starts on the current version; nothing is activated.
func _test_download_failure() -> void:
	var c = _core()
	var p := ("four " + "x".repeat(4000)).to_utf8_buffer()
	ota._publish(srv, 4, p)
	srv.modes["/dev-000004.pck"] = "truncate"
	var up := _updater(c, srv.url("/latest.json"))
	var r: Array = await _run(up, FakeLoading.new())
	t.check("launch_download_failure_starts_normally", str(r[0]).contains("download did not complete") and not str(r[2]).contains("activate")
			and c.slot("pending").is_empty(), "%s, %s" % [r[0], r[2]])
	srv.modes["/dev-000004.pck"] = "hang"
	up.download_timeout = 3.0
	r = await _run(up, FakeLoading.new(), {"download_cap_ms": 600})
	t.check("launch_download_cap_starts_normally", str(r[0]).begins_with("download still running") and int(r[1]) < 600 + AutoUpdate.CHECK_WAIT_MS
			and not str(r[2]).contains("activate"), "%s in %d ms" % [r[0], r[1]])
	srv.modes.erase("/dev-000004.pck")
	await _settle(up)
	up.queue_free()

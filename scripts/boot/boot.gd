extends Node
## NATIVE LAYER — first autoload. Installed with the APK; an OTA pack can never replace it
## (it and everything it preloads are loaded before any pack is mounted).
##
## Boot order:  APK starts -> Boot._init(): pin native build info, select + verify + mount
## the OTA pack -> remaining autoloads and the main scene load from the mounted pack.
##
## Also owns: the runtime identity stack, the boot-health checkpoint, the update client and
## the recovery/diagnostics screen (reachable even when the game layer is broken: F9, or five
## quick taps in the top-left corner).
##
## Offline first: nothing here waits for the network. The game starts from the newest verified
## package already on the device (or the bundled baseline); update checks run afterwards in the
## background, and any failure just leaves the current game running.

const Config := preload("res://scripts/boot/ota_config.gd")
const OtaCore := preload("res://scripts/boot/ota_core.gd")
const OtaUpdater := preload("res://scripts/boot/ota_updater.gd")
const Overlay := preload("res://scripts/boot/diagnostics_overlay.gd")
const NATIVE_INFO_PATH := "res://scripts/generated/native_build_info.gd"
const HEALTHY_AFTER_MS := 3000
## Automatic update checks: once per start (after boot health), then on returning to the app or
## while it keeps running, never more often than AUTO_CHECK_MIN_GAP_S apart.
const AUTO_CHECK_MIN_GAP_S := 15 * 60
const AUTO_CHECK_PERIOD_S := 60 * 60

var ota_enabled := false
var flavor := "local"
## The update channel this install follows (native build info, else ota_config.gd).
var channel := ""
## Native-shell identity baked in by the APK build (pinned before any pack is mounted).
var native_info: Dictionary = {}
var core: OtaCore
var updater: OtaUpdater
var healthy := false

var _args := {}
var _ready_at := -1
var _ready_frames := 0
var _overlay: Overlay
var _taps: Array[int] = []
var _last_auto_check_ms := -1
## Native startup milestones [label, engine-clock usec]; the game layer's StartupTrace merges
## them into the timeline shown in Diagnostics.
var boot_marks: Array = []


func _init() -> void:
	_mark("native: bootstrap starts (first autoload)")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() == 2 else "true"
	if ResourceLoader.exists(NATIVE_INFO_PATH):
		var s: Script = load(NATIVE_INFO_PATH)
		native_info = s.get_script_constant_map().get("INFO", {})
	flavor = native_info.get("flavor", "local")
	channel = native_info.get("ota_channel", Config.CHANNEL)
	# Every Android build carries the OTA client (the "ota" export feature); a desktop run can
	# ask for it. Automated test runs never touch user://ota unless given their own root.
	ota_enabled = OS.has_feature(Config.FEATURE) or _args.has("ota-force")
	if _args.has("test") and not _args.has("ota-root"):
		ota_enabled = false
	if not ota_enabled:
		_mark("native: bootstrap done (no OTA client)")
		return
	core = OtaCore.new(_args.get("ota-root", "user://ota"), "", channel)
	core.device_save_schema = _device_save_schema()
	var ptr: String = _args.get("ota-pointer", "")
	core.allow_local_http = ptr.begins_with("http://127.0.0.1:") and OS.get_name() != "Android"
	core.boot(func(path: String) -> bool: return ProjectSettings.load_resource_pack(path, true))
	for line in core.boot_log:
		print("[OTA] ", line)
	_mark("native: OTA package chosen (%s): verify %.1f ms, mount %.1f ms, no network" % [core.active.get("ota_id", "bundled game"), core.boot_verify_ms, core.boot_mount_ms])


func _mark(label: String) -> void:
	boot_marks.append([label, Time.get_ticks_usec()])
	print("[STARTUP] %9.1f ms  %s" % [Time.get_ticks_usec() / 1000.0, label])


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ota_enabled:
		updater = OtaUpdater.new()
		updater.core = core
		var ptr: String = _args.get("ota-pointer", "")
		updater.pointer_url = ptr if ptr != "" else Config.pointer_url(channel)
		updater.finished.connect(_on_update_finished)
		add_child(updater)
		# Scriptable equivalents of the recovery buttons (developer / end-to-end runs).
		var action: String = _args.get("ota-action", "")
		if action != "":
			match action:
				"rollback":
					var r: String = core.rollback()
					print("[OTA] action rollback: ", r if r != "" else "ok")
				"disable":
					core.set_disabled(true)
					print("[OTA] action disable: ok")
				"enable":
					core.set_disabled(false)
					print("[OTA] action enable: ok")
			get_tree().quit.call_deferred()


## Save schema currently on disk. A settings file from before schemas existed is schema 1.
static func _device_save_schema() -> int:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") != OK:
		return 0
	return int(cf.get_value("meta", "save_schema", 1))


# --- boot health ---------------------------------------------------------------------------

## Called by the game layer once its entry scene, autoloads and first menu/game state are up.
## Health is recorded after it then keeps running for HEALTHY_AFTER_MS. An OTA whose game
## never calls this (or crashes first) is abandoned after OtaCore.MAX_UNHEALTHY_STARTS starts.
func report_ready() -> void:
	if _ready_at < 0:
		_ready_at = Time.get_ticks_msec()
		_mark("native: game reported ready")


func _process(_dt: float) -> void:
	if healthy:
		auto_check("periodic")
		return
	if _ready_at < 0:
		return
	_ready_frames += 1
	if Time.get_ticks_msec() - _ready_at >= HEALTHY_AFTER_MS and _ready_frames >= 30:
		healthy = true
		_mark("native: boot healthy")
		if ota_enabled:
			core.mark_healthy()
			print("[OTA] boot healthy: ", core.active.get("ota_id", "bundled baseline"))
			auto_check("start")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		auto_check("resume")


## Pure policy: may an automatic check for `reason` run now? "start" always may (once per
## launch); "resume" needs AUTO_CHECK_MIN_GAP_S since the last automatic attempt and "periodic"
## AUTO_CHECK_PERIOD_S. Failed attempts count as attempts, so an offline device is not hammered.
static func auto_check_due(reason: String, now_ms: int, last_ms: int) -> bool:
	if reason == "start" or last_ms < 0:
		return reason == "start"
	var gap := AUTO_CHECK_PERIOD_S if reason == "periodic" else AUTO_CHECK_MIN_GAP_S
	return now_ms - last_ms >= gap * 1000


## Starts a background check (and download of a verified update) if the policy allows it.
## Returns immediately; the result arrives through the updater's `finished` signal.
func auto_check(reason: String) -> bool:
	if not ota_enabled or not healthy or updater == null or updater.busy or core.state["disabled"]:
		return false
	if _args.has("ota-no-autocheck"):
		return false
	var now := Time.get_ticks_msec()
	if not auto_check_due(reason, now, _last_auto_check_ms):
		return false
	_last_auto_check_ms = now
	_mark("native: automatic OTA check starts (%s)" % reason)
	print("[OTA] automatic check (%s)" % reason)
	updater.check(true)
	return true


func _on_update_finished(result: String) -> void:
	print("[OTA] ", result)
	if result.contains("restart to run"):
		toast(result)
	if _overlay != null and _overlay.visible:
		_overlay.refresh()
	if _args.has("ota-quit-after-check"):
		print("[OTA] identity ", JSON.stringify(identity()))
		get_tree().quit()


# --- identity --------------------------------------------------------------------------------

## A constant from a game-layer script, read from whatever is mounted NOW (bundled or OTA).
static func _game_const(path: String, name: String, fallback: Variant) -> Variant:
	var s: Script = load(path) if ResourceLoader.exists(path) else null
	return s.get_script_constant_map().get(name, fallback) if s != null else fallback


## The complete runtime identity stack. Values that do not exist are reported as such
## ("local", "unknown", "none") rather than invented.
func identity() -> Dictionary:
	var act: Dictionary = core.active if ota_enabled else {}
	var run: Dictionary = act.get("build_run", {})
	var native_sha: String = native_info.get("source_sha", "unknown")
	var native_run: String = native_info.get("build_run", "local")
	return {
		"product": _game_const("res://scripts/core/game_version.gd", "PRODUCT_NAME", "unknown"),
		"character": _game_const("res://scripts/core/game_version.gd", "CHARACTER_NAME", "unknown"),
		"game_version": _game_const("res://scripts/core/game_version.gd", "GAME_VERSION", "unknown"),
		"native_version": native_info.get("native_version", "unknown"),
		"native_build": str(native_info.get("native_build", "local")),
		"build_flavor": flavor,
		"native_source_sha": native_sha,
		"native_build_run": native_run,
		"godot_version": Config.engine_version(),
		"runtime_id": Config.runtime_id(),
		"ota_enabled": ota_enabled,
		"ota_channel": channel if ota_enabled else "none",
		"ota_id": act.get("ota_id", "none"),
		"ota_game_version": act.get("game_version", ""),
		"ota_source_sha": act.get("source_sha", ""),
		"ota_pck_sha256": act.get("pck_sha256", ""),
		"ota_build_run": str(run.get("id", "")),
		"source_sha": act.get("source_sha", native_sha),
		"build_run": str(run.get("id", native_run)) if not act.is_empty() else native_run,
		"save_schema": _game_const("res://scripts/core/save_schema.gd", "SAVE_SCHEMA", 0),
	}


func diagnostics_text() -> String:
	var id := identity()
	var build_label := "Android Build" if OS.get_name() == "Android" else "Native Build"
	var L: Array[String] = []
	L.append("%s DIAGNOSTICS" % str(id["product"]).to_upper())
	L.append("")
	L.append("Product: %s" % id["product"])
	L.append("Game Version: %s" % id["game_version"])
	L.append("Character: %s" % id["character"])
	L.append("")
	L.append("Native")
	L.append("  Version: %s" % id["native_version"])
	L.append("  %s: %s" % [build_label, id["native_build"]])
	L.append("  Flavor: %s" % id["build_flavor"])
	L.append("  Godot: %s" % id["godot_version"])
	L.append("  Runtime: %s" % id["runtime_id"])
	L.append("  Bundled baseline source: %s" % id["native_source_sha"])
	L.append("")
	L.append("OTA")
	L.append("  Enabled: %s" % ("yes" if ota_enabled else "no"))
	L.append("  Channel: %s" % id["ota_channel"])
	L.append("  Status: %s" % ota_status())
	L.append("  Bundled baseline: %s (%s %s)" % [id["native_source_sha"], build_label, id["native_build"]])
	if ota_enabled:
		var st: Dictionary = core.state
		var ev: Dictionary = st["events"]
		var active_id: String = id["ota_id"]
		L.append("  Active: %s" % (("%s (source %s)" % [active_id, id["ota_source_sha"]]) if active_id != "none" else "bundled baseline"))
		L.append("  Latest on channel: %s" % latest_text())
		L.append("  Pending (runs after restart): %s" % _slot_text("pending"))
		L.append("  Downloaded, not activated: %s" % _slot_text("ready"))
		L.append("  Runtime compatibility: this app runs %s; latest OTA %s" % [id["runtime_id"], _compat_text()])
		var chk: Dictionary = ev.get("check", {})
		L.append("  Last check: %s" % (("%s  %s" % [chk["result"], chk["time"]]) if not chk.is_empty() else "none"))
		if active_id != "none":
			L.append("  Active OTA claims game: %s%s" % [id["ota_game_version"], "" if id["ota_game_version"] == id["game_version"] else "  (MISMATCH with running game!)"])
			L.append("  Active PCK SHA-256: %s" % id["ota_pck_sha256"])
		L.append("  Current: %s" % _slot_text("current"))
		L.append("  Previous: %s" % _slot_text("previous"))
		for k in [["download", "Last download"], ["verify", "Last verification"], ["load", "Last load"], ["health", "Boot health"], ["rollback", "Last rollback"]]:
			var e: Dictionary = ev.get(k[0], {})
			L.append("  %s: %s" % [k[1], ("%s  %s" % [e["result"], e["time"]]) if not e.is_empty() else "none"])
		L.append("  This run healthy: %s" % ("yes" if healthy else "not yet"))
		L.append("  Rollback count: %d" % int(st["rollback_count"]))
		L.append("  OTA disabled (baseline mode): %s" % ("yes" if st["disabled"] else "no"))
		L.append("  Rejected OTAs: %s" % (", ".join(st["bad"]) if not (st["bad"] as Array).is_empty() else "none"))
	var trace: Script = load("res://scripts/core/startup_trace.gd") if ResourceLoader.exists("res://scripts/core/startup_trace.gd") else null
	if trace != null:
		L.append("")
		L.append("Startup (this launch; ms on the engine clock)")
		L.append(trace.call("timeline_text", boot_marks))
	L.append("")
	L.append("Source")
	L.append("  Git SHA (running code): %s" % id["source_sha"])
	L.append("")
	L.append("Automation")
	L.append("  Build run (running code): %s" % id["build_run"])
	L.append("  Native build run: %s" % id["native_build_run"])
	L.append("")
	L.append("Persistence")
	L.append("  Save Schema: %s" % id["save_schema"])
	return "\n".join(L)


## One line that says whether the game is current. Never guesses: "not checked yet" until a
## check has actually completed.
func ota_status() -> String:
	if not ota_enabled:
		return "no OTA client in this build: it plays its bundled game"
	if core.state["disabled"]:
		return "OTA disabled: running the bundled baseline (Re-enable OTA to resume updates)"
	var pend := core.slot("pending")
	if not pend.is_empty() and pend.get("ota_id", "") != core.active.get("ota_id", ""):
		return "Update downloaded: %s runs after the app restarts" % pend["ota_id"]
	var rdy := core.slot("ready")
	if not rdy.is_empty():
		return "Update downloaded: %s (press Activate on restart)" % rdy["ota_id"]
	var st: String = updater.status if updater != null else "unchecked"
	match st:
		"checking":
			return "Checking the %s channel..." % channel
		"downloading":
			return "Downloading %s..." % updater.remote.get("ota_id", "update")
		"available":
			return "Update available: %s" % updater.remote.get("ota_id", "?")
		"up_to_date":
			return "Up to date"
		"offline":
			return "Offline: update channel not reachable; playing the current game"
		"incompatible":
			return "Latest OTA %s cannot run on this app; playing the current game" % updater.remote.get("ota_id", "?")
		"rejected":
			return "Latest OTA %s was rejected; playing the current game" % updater.remote.get("ota_id", "?")
		"failed":
			return "Update failed (%s); playing the current game" % updater.status_detail
	return "Not checked yet"


func latest_text() -> String:
	if updater == null or updater.remote.is_empty():
		return "not checked yet"
	return "%s (checked %s)" % [updater.remote.get("ota_id", "?"), updater.checked_at]


func _compat_text() -> String:
	var c: String = updater.latest_compat if updater != null else ""
	if c == "":
		return "not checked yet"
	return "compatible" if c == "compatible" else "NOT compatible: " + c


func _slot_text(name: String) -> String:
	var m: Dictionary = core.slot(name)
	if m.is_empty():
		return "none"
	return "%s (game %s, %s)" % [m["ota_id"], m["game_version"], str(m["source_sha"]).left(12)]


# --- recovery / diagnostics UI ----------------------------------------------------------------

func show_diagnostics() -> void:
	if _overlay == null:
		_overlay = Overlay.new()
		_overlay.boot = self
		add_child(_overlay)
	_overlay.open()


func toast(msg: String) -> void:
	if _overlay == null:
		_overlay = Overlay.new()
		_overlay.boot = self
		add_child(_overlay)
	_overlay.toast(msg)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		show_diagnostics()
		return
	var pos := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos.x < 0:
		return
	var vp := get_viewport().get_visible_rect().size
	if pos.x > vp.x * 0.1 or pos.y > vp.y * 0.14:
		return
	var now := Time.get_ticks_msec()
	_taps.append(now)
	while not _taps.is_empty() and now - _taps[0] > 2500:
		_taps.pop_front()
	if _taps.size() >= 5:
		_taps.clear()
		show_diagnostics()

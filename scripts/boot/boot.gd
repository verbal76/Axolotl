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

const Config := preload("res://scripts/boot/ota_config.gd")
const OtaCore := preload("res://scripts/boot/ota_core.gd")
const OtaUpdater := preload("res://scripts/boot/ota_updater.gd")
const Overlay := preload("res://scripts/boot/diagnostics_overlay.gd")
const NATIVE_INFO_PATH := "res://scripts/generated/native_build_info.gd"
const HEALTHY_AFTER_MS := 3000

var ota_enabled := false
var flavor := "local"
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


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1] if kv.size() == 2 else "true"
	if ResourceLoader.exists(NATIVE_INFO_PATH):
		var s: Script = load(NATIVE_INFO_PATH)
		native_info = s.get_script_constant_map().get("INFO", {})
	flavor = native_info.get("flavor", "dev" if OS.has_feature(Config.FEATURE) else "local")
	# The OTA client exists only in the dev flavour (or a desktop run that asks for it).
	# Automated test runs never touch user://ota unless given their own root.
	ota_enabled = OS.has_feature(Config.FEATURE) or _args.has("ota-force")
	if _args.has("test") and not _args.has("ota-root"):
		ota_enabled = false
	if not ota_enabled:
		return
	core = OtaCore.new(_args.get("ota-root", "user://ota"))
	core.device_save_schema = _device_save_schema()
	var ptr: String = _args.get("ota-pointer", "")
	core.allow_local_http = ptr.begins_with("http://127.0.0.1:") and OS.get_name() != "Android"
	core.boot(func(path: String) -> bool: return ProjectSettings.load_resource_pack(path, true))
	for line in core.boot_log:
		print("[OTA] ", line)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ota_enabled:
		updater = OtaUpdater.new()
		updater.core = core
		var ptr: String = _args.get("ota-pointer", "")
		updater.pointer_url = ptr if ptr != "" else Config.pointer_url()
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


func _process(_dt: float) -> void:
	if healthy or _ready_at < 0:
		return
	_ready_frames += 1
	if Time.get_ticks_msec() - _ready_at >= HEALTHY_AFTER_MS and _ready_frames >= 30:
		healthy = true
		if ota_enabled:
			core.mark_healthy()
			print("[OTA] boot healthy: ", core.active.get("ota_id", "bundled baseline"))
			if not _args.has("ota-no-autocheck"):
				updater.check(true)


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
		"ota_channel": Config.CHANNEL if ota_enabled else "none",
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
	if ota_enabled:
		var st: Dictionary = core.state
		var ev: Dictionary = st["events"]
		L.append("  Active OTA (this run): %s" % (id["ota_id"] if id["ota_id"] != "none" else "none (bundled baseline)"))
		if id["ota_id"] != "none":
			L.append("  Active OTA claims game: %s%s" % [id["ota_game_version"], "" if id["ota_game_version"] == id["game_version"] else "  (MISMATCH with running game!)"])
			L.append("  Active OTA source SHA: %s" % id["ota_source_sha"])
			L.append("  Active PCK SHA-256: %s" % id["ota_pck_sha256"])
		L.append("  Current: %s" % _slot_text("current"))
		L.append("  Previous: %s" % _slot_text("previous"))
		L.append("  Pending (next start): %s" % _slot_text("pending"))
		L.append("  Downloaded, not activated: %s" % _slot_text("ready"))
		L.append("  Latest on channel (last check): %s" % updater.remote.get("ota_id", "not checked this run"))
		for k in [["check", "Last update check"], ["download", "Last download"], ["verify", "Last verification"], ["load", "Last load"], ["health", "Boot health"], ["rollback", "Last rollback"]]:
			var e: Dictionary = ev.get(k[0], {})
			L.append("  %s: %s" % [k[1], ("%s  %s" % [e["result"], e["time"]]) if not e.is_empty() else "none"])
		L.append("  This run healthy: %s" % ("yes" if healthy else "not yet"))
		L.append("  Rollback count: %d" % int(st["rollback_count"]))
		L.append("  OTA disabled (baseline mode): %s" % ("yes" if st["disabled"] else "no"))
		L.append("  Rejected OTAs: %s" % (", ".join(st["bad"]) if not (st["bad"] as Array).is_empty() else "none"))
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

class_name AutoUpdate
extends Node
## GAME LAYER — fully automatic OTA updates (owner decision, 2026-10-01).
##
## The r5 native layer (Android build 22) downloads and verifies updates by itself but only
## runs one after a cold start, which Android rarely gives a game. This node closes the gap with
## what r5 already exposes (Boot.updater, Boot.core), and SoftRestart runs the update in-process:
##
##  * Launch: while Mote's loading screen builds the world, the update channel is checked (and
##    a newer verified package downloaded). If one is ready before the world is, or within
##    LAUNCH_CAP_MS of the check starting, the loading screen shows "Updating..." and the new
##    version takes over before the title appears: one launch is enough. Offline, the check
##    fails fast and nothing waits; a stalled network costs at most the cap.
##  * Running: an update downloaded during a session (the native start/resume/periodic checks)
##    installs at the next safe moment: on the title screen, or when the app returns from the
##    background. Never during play, cinematics, lessons, menus or the aquarium. The run and the
##    profile are saved first; the restart lands on the title (Continue resumes the run).
##  * Anything that fails leaves the current version running, with the reason in Diagnostics.
##
## Safety: only PENDING (verified and activated by the native layer) is ever applied, and only
## after the same checks the native layer makes at boot; the native layer itself re-verifies and
## mounts it. Each OTA id is tried at most once in-process; the running version must have
## reached boot health first (except at launch); the new version must reach boot health again
## before the native layer makes it CURRENT, and the native unhealthy-start limit and rollback
## work exactly as after a cold start.

const SoftRestart := preload("res://scripts/core/soft_restart.gd")
const UpdateActivation := preload("res://scripts/core/update_activation.gd")
const OtaCore := preload("res://scripts/boot/ota_core.gd")
## Longest the launch waits for its check and download, from the moment the check starts.
const LAUNCH_CAP_MS := 8000
## Bytes the update download may take per frame (see _on_updater_request).
const DOWNLOAD_CHUNK := 4 * 1024 * 1024
## How often the running game looks for a safe moment.
const POLL_S := 0.25
## Engine metadata: this process already ran its launch check ({result, waited_ms}).
const LAUNCH_META := "mote_launch_check"

var g: Node
var _launch_t0 := -1
var _poll := 0.0
var _resume_due := false
## Seconds after a return from the background during which it still counts as that safe moment
## (owner phone, 2026-10-01: the native layer starts its own check at the same instant, so a single
## attempt always met "an update check is running" and the waiting update sat until the title).
const RESUME_WINDOW_S := 15.0
var _resume_left := 0.0
var _applying := false
var _announced_download := ""
## Package verdicts already computed this session (see applicable()).
var _verified := {}


func _ready() -> void:
	name = "AutoUpdate"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Boot.updater != null and not Boot.updater.finished.is_connected(_on_update_finished):
		Boot.updater.finished.connect(_on_update_finished)
	if Boot.updater != null and not Boot.updater.child_entered_tree.is_connected(_on_updater_request):
		Boot.updater.child_entered_tree.connect(_on_updater_request)


## The r5 updater reads at most 256 KiB per frame (HTTPRequest.download_chunk_size) and polls once
## per frame; while the loading screen builds the world, frames are long, so a ~15 MB package took
## about 8 s on a local server. A larger chunk lets each poll take what the socket has.
func _on_updater_request(n: Node) -> void:
	if n is HTTPRequest:
		(n as HTTPRequest).download_chunk_size = DOWNLOAD_CHUNK


# --- pure policy (unit-tested) ------------------------------------------------------------------

static func _has_flag(args: PackedStringArray, flag: String) -> bool:
	for a in args:
		if a == flag or a.begins_with(flag + "="):
			return true
	return false


## "" when automatic updating is on for this process, otherwise why it is off.
static func off_reason(ota_enabled: bool, test_mode: String, args: PackedStringArray) -> String:
	if not ota_enabled:
		return "no OTA client in this build"
	if test_mode != "":
		return "automated test run"
	if _has_flag(args, "--ota-quit-after-check"):
		return "check-and-quit run"
	if _has_flag(args, "--no-auto-update"):
		return "turned off for this run (--no-auto-update)"
	return ""


## The launch check also honours the native "no automatic checks" switch.
static func launch_check_off_reason(ota_enabled: bool, test_mode: String, args: PackedStringArray) -> String:
	var why := off_reason(ota_enabled, test_mode, args)
	if why == "" and _has_flag(args, "--ota-no-autocheck"):
		why = "automatic checks turned off (--ota-no-autocheck)"
	return why


## [manifest, ""] when PENDING may be applied in-process now, else [{}, why not]. Mirrors the
## checks OtaCore.boot() makes before it mounts anything (and then makes again itself).
## `cache` (id + SHA-256 -> verdict) keeps a package from being hashed again on every poll;
## `deep` false skips the package hash (Diagnostics).
static func applicable(core, attempted: Dictionary, cache := {}, deep := true) -> Array:
	if core == null:
		return [{}, "no OTA client"]
	if bool(core.state.get("disabled", false)):
		return [{}, "OTA disabled (bundled baseline mode)"]
	var m: Dictionary = core.slot("pending")
	if m.is_empty():
		return [{}, "no update waiting"]
	var id := str(m.get("ota_id", ""))
	if id == "" or id == str(core.active.get("ota_id", "")):
		return [{}, "%s is already running" % id]
	if attempted.has(id):
		return [{}, "%s was already tried in-process (%s); the next app start runs it" % [id, str((attempted[id] as Dictionary).get("result", "?"))]]
	if core.is_bad(id):
		return [{}, "%s was rejected or rolled back on this device" % id]
	var b: Dictionary = core.state.get("boot", {})
	if str(b.get("ota_id", "")) == id and int(b.get("starts", 0)) >= OtaCore.MAX_UNHEALTHY_STARTS:
		return [{}, "%s did not reach boot health in %d starts" % [id, int(b.get("starts", 0))]]
	var why: String = core.validate_manifest(m)
	var key := "%s/%s" % [id, str(m.get("pck_sha256", ""))]
	if why == "" and deep:
		if not cache.has(key):
			cache[key] = core.verify_installed(m)
		why = cache[key]
	if why != "":
		return [{}, "%s would not be loaded by the native layer: %s" % [id, why]]
	return [m, ""]


## "" when `where` ("launch" | "title" | "resume") is a safe moment for the game described by
## `c` (see context()), otherwise why not.
static func safe_moment(where: String, c: Dictionary) -> String:
	match where:
		"launch":
			return "" if not c.get("ready_done", false) else "the game is already up"
		"title":
			if not c.get("ready_done", false):
				return "still starting"
			if c.get("state", "") != "title" or not c.get("title_visible", false):
				return "not on the title screen"
		"resume":
			if not c.get("ready_done", false):
				return "still starting"
			if not ["title", "play"].has(c.get("state", "")):
				return "in the %s" % c.get("state", "?")
			if c.get("state", "") == "title" and not c.get("title_visible", false):
				return "the title is covered"
		_:
			return "unknown moment '%s'" % where
	for k in [["paused", "the game is paused"], ["menu_open", "a menu is open"], ["cinematic", "a cinematic is playing"],
			["lesson", "a lesson is running"], ["card", "a card is on screen"], ["presentation", "in the aquarium"],
			["ending", "the ending is playing"]]:
		if c.get(k[0], false):
			return k[1]
	if not c.get("healthy", false):
		return "this version has not reached boot health yet"
	if c.get("updater_busy", false):
		return "an update check is running"
	return ""


## Whether the launch has waited long enough: the check is over, or the cap is reached.
static func launch_wait_over(elapsed_ms: int, busy: bool) -> bool:
	return not busy or elapsed_ms >= LAUNCH_CAP_MS


# --- game state ---------------------------------------------------------------------------------

## What safe_moment() needs, read from the running game.
func context() -> Dictionary:
	var gg = g
	return {
		"ready_done": gg.ready_done,
		"state": gg.state,
		"title_visible": gg.title != null and gg.title.visible,
		"paused": get_tree().paused,
		"menu_open": (gg.pause_menu != null and gg.pause_menu.visible) or (gg.get("diagnostics") != null and gg.diagnostics.visible) or _diagnostics_open(),
		"cinematic": gg.cinematic != "",
		"lesson": gg.onboarding != null and gg.onboarding.staging(),
		"card": gg.onboarding != null and gg.onboarding.ui != null and gg.onboarding.ui.card_kind() != "",
		"presentation": gg.presentation != null and gg.presentation.active(),
		"ending": gg._all_clear_wait >= 0.0 and not gg.all_clear_done,
		"healthy": Boot.healthy,
		"updater_busy": Boot.updater != null and Boot.updater.busy,
	}


## The native Diagnostics / recovery panel (r5 has no public accessor; read defensively).
static func _diagnostics_open() -> bool:
	var ov: Variant = Boot.get("_overlay")
	if ov == null or not is_instance_valid(ov):
		return false
	var panel: Variant = (ov as Object).get("_panel")
	return panel is Control and (panel as Control).is_visible_in_tree()


static func _off() -> String:
	return off_reason(Boot.ota_enabled and Boot.core != null and Boot.updater != null, Settings.test_mode, OS.get_cmdline_user_args())


static func soft_restarted() -> Dictionary:
	return Engine.get_meta(SoftRestart.META, {}) as Dictionary


# --- launch ---------------------------------------------------------------------------------------

## Starts the launch check (once per process, never after a soft restart). Returns immediately;
## the world keeps building meanwhile.
func begin_launch_check() -> void:
	if Engine.has_meta(LAUNCH_META) or not soft_restarted().is_empty():
		return
	var why := launch_check_off_reason(Boot.ota_enabled and Boot.core != null and Boot.updater != null, Settings.test_mode, OS.get_cmdline_user_args())
	if why == "" and (Boot.core.state["disabled"] or Boot.updater.busy):
		why = "OTA disabled" if Boot.core.state["disabled"] else "a check is already running"
	if why != "":
		Engine.set_meta(LAUNCH_META, {"result": "not checked: " + why, "waited_ms": 0})
		return
	Engine.set_meta(LAUNCH_META, {"result": "checking", "waited_ms": 0})
	_launch_t0 = Time.get_ticks_msec()
	StartupTrace.mark("game: launch update check starts")
	print("[AUTOUPDATE] launch check starts")
	Boot.updater.finished.connect(_on_launch_check_finished, CONNECT_ONE_SHOT)
	Boot.updater.check(true)


func _on_launch_check_finished(_result: String) -> void:
	if _launch_t0 >= 0:
		StartupTrace.mark("game: launch update check finished after %d ms (%s)" % [Time.get_ticks_msec() - _launch_t0, Boot.updater.status])


## Called once the world is built, before the title. Waits (capped) for the launch check, then
## applies a verified update if there is one. True when the new version is taking over (the
## caller must stop: this game layer is about to be replaced).
func launch_gate(loading) -> bool:
	if _launch_t0 < 0:
		return false
	var shown := false
	var gate_t0 := Time.get_ticks_msec()
	while not launch_wait_over(Time.get_ticks_msec() - _launch_t0, Boot.updater.busy):
		if not shown and loading != null:
			loading.set_stage("Checking for updates")
			shown = true
		await get_tree().process_frame
	var since_check := Time.get_ticks_msec() - _launch_t0
	var waited := Time.get_ticks_msec() - gate_t0
	_launch_t0 = -1
	var info: Dictionary = Engine.get_meta(LAUNCH_META, {})
	info["waited_ms"] = waited
	info["result"] = Boot.updater.status_detail if not Boot.updater.busy else "still %s after %d ms: continues in the background" % [Boot.updater.status, since_check]
	Engine.set_meta(LAUNCH_META, info)
	StartupTrace.mark("game: launch gate: world ready, waited %d ms more for the update check (%s, %d ms since it started)" % [waited, Boot.updater.status, since_check])
	if Boot.updater.busy:
		return false
	var r := _candidate()
	if r[0].is_empty():
		if r[1] != "no update waiting":
			print("[AUTOUPDATE] launch: not applying: ", r[1])
		return false
	if loading != null:
		loading.set_stage("Updating")
	var why: String = await _apply(r[0], "launch", Callable())
	return why == ""


# --- running ---------------------------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_resume_due = true
		_resume_left = RESUME_WINDOW_S
		_resume_check.call_deferred()


## Whether a return to the app should check the channel, by the WALL clock: the last check (any
## outcome; `last_check_iso` from the native event log, "" when none) is at least `gap_s` ago, or
## the clock went backwards. Pure (unit-tested).
static func resume_check_due(now_unix: float, last_check_iso: String, gap_s: int) -> bool:
	if last_check_iso == "":
		return true
	var t := Time.get_unix_time_from_datetime_string(last_check_iso.trim_suffix("Z"))
	if t <= 0:
		return true
	return now_unix - t >= gap_s or now_unix < t - 60.0


## The native resume check (r5 Boot.auto_check) measures its 15-minute gap on the engine clock,
## which stops while the phone sleeps: back in the app after a night in the pocket, it usually
## decided "too soon" and the update waited for the hourly check. Same gap and the same rules,
## measured on the wall clock; it never runs alongside a native check (busy) and tells the native
## policy it ran, so the two never double up.
func _resume_check() -> void:
	if _off() != "" or _has_flag(OS.get_cmdline_user_args(), "--ota-no-autocheck"):
		return
	if not Boot.healthy or Boot.updater.busy or Boot.core.state["disabled"]:
		return
	var last: Dictionary = (Boot.core.state["events"] as Dictionary).get("check", {})
	if not resume_check_due(Time.get_unix_time_from_system(), str(last.get("time", "")), Boot.AUTO_CHECK_MIN_GAP_S):
		return
	Boot.set("_last_auto_check_ms", Time.get_ticks_msec())
	print("[AUTOUPDATE] resume check (wall clock: last check %s)" % str(last.get("time", "never")))
	Boot.updater.check(true)


func _process(dt: float) -> void:
	if _applying or g == null or not g.ready_done:
		_resume_due = false
		_resume_left = 0.0
		return
	_resume_left = maxf(0.0, _resume_left - dt)
	_poll -= dt
	if _poll > 0.0 and not _resume_due:
		return
	_poll = POLL_S
	var where := "resume" if _resume_due or _resume_left > 0.0 else "title"
	_resume_due = false
	if _off() != "":
		return
	var c := context()
	if safe_moment(where, c) != "":
		return
	var r := _candidate()
	if r[0].is_empty():
		return
	_apply(r[0], where, _save_progress)


## The update to apply, after promoting a READY one the native layer could not activate at
## download time (fully automatic: activation never waits for a button).
func _candidate() -> Array:
	var core = Boot.core
	if core == null:
		return [{}, "no OTA client"]
	if core.slot("pending").is_empty() and core.slot("ready").is_empty():
		return [{}, "no update waiting"]
	core.device_save_schema = Boot._device_save_schema()
	if core.slot("pending").is_empty() and not core.slot("ready").is_empty() and not core.state["disabled"]:
		var why: String = core.activate_ready()
		if why != "":
			return [{}, "downloaded update not activated: " + why]
	return applicable(core, SoftRestart.record_read()["attempts"], _verified)


## Saves the run and the profile; "" or what failed.
func _save_progress() -> String:
	var bad: Array[String] = []
	if g.run_save != null and not g.save_run():
		bad.append("run: " + str(g.run_save.last_save_result))
	if g.gill != null and not g.gill.save():
		bad.append("profile: " + str(g.gill.last_save_result))
	return ", ".join(bad)


func _apply(m: Dictionary, where: String, save: Callable) -> String:
	_applying = true
	print("[AUTOUPDATE] applying %s at %s" % [m["ota_id"], where])
	var why: String = await SoftRestart.apply(m, where, save)
	# (Only reached when the update did not go ahead: otherwise this node no longer exists.)
	if why != "":
		print("[AUTOUPDATE] not applied: ", why)
		Boot.toast("Update %s not installed: playing the current version" % m["ota_id"])
	_applying = false
	return why


func _on_update_finished(result: String) -> void:
	# The native toast says "restart to run it"; with automatic updates that is no longer what
	# happens, so say what will.
	var pend: Dictionary = Boot.core.slot("pending") if Boot.core != null else {}
	if result.contains("restart to run") and not pend.is_empty() and _off() == "" and _announced_download != str(pend.get("ota_id", "")):
		_announced_download = str(pend.get("ota_id", ""))
	# (Owner, 2026-10-04: no update text over the title or loading screen. A downloaded update
	# installs quietly on the title behind "Please wait, applying update"; the native layer's own
	# "restart to run it" toast is cleared too. About / Diagnostics still shows the update state.)
	if result.contains("restart to run"):
		_hide_native_toast.call_deferred()


## Clears the native overlay's toast (r5 shows "… restart to run it" on every download).
static func _hide_native_toast() -> void:
	var ov = Boot.get("_overlay")
	if ov != null and is_instance_valid(ov) and ov.get("_toast") != null:
		ov._toast_t = 0.0
		ov._toast.visible = false


# --- after a soft restart -------------------------------------------------------------------------

## The new game's loading screen is on screen: lift the curtain the old one left up.
static func on_loading_visible() -> void:
	var sr := soft_restarted()
	if sr.is_empty():
		return
	SoftRestart.lift_curtain()
	UpdateActivation.finish(sr.get("to", "") == sr.get("wanted", "") and str(sr.get("result", "")) == "", str(sr.get("result", "")))
	if not sr.get("announced", false):
		var from: String = sr.get("from", "") if sr.get("from", "") != "" else "bundled game"
		if sr.get("to", "") == sr.get("wanted", "") and str(sr.get("result", "")) == "":
			StartupTrace.mark("game: running %s after a soft restart (from %s, %s)" % [sr.get("to", "?"), from, sr.get("where", "?")])
		else:
			StartupTrace.mark("game: update to %s failed in-process; running %s again" % [sr.get("wanted", "?"), sr.get("to", "") if sr.get("to", "") != "" else "the bundled game"])


## The title (or play) is usable: record the outcome once.
static func on_usable() -> void:
	var sr := soft_restarted()
	if sr.is_empty() or sr.get("announced", false):
		return
	sr["announced"] = true
	Engine.set_meta(SoftRestart.META, sr)
	var to: String = sr.get("to", "")
	if sr.get("result", "") == "" and to == sr.get("wanted", ""):
		SoftRestart.record_result(to, "applied in-process at %s; running %s (boot health pending)" % [sr.get("where", "?"), to])


# --- diagnostics ----------------------------------------------------------------------------------

static func diagnostics_text() -> String:
	var L: Array[String] = []
	L.append("Automatic updates")
	var off := _off()
	L.append("  Mode: %s" % ("automatic (launch, title screen, return from background)" if off == "" else "off: " + off))
	var lc: Dictionary = Engine.get_meta(LAUNCH_META, {})
	L.append("  Launch check: %s" % (("%s (title waited %d ms for it; cap %d ms from the check's start)" % [lc.get("result", "?"), int(lc.get("waited_ms", 0)), LAUNCH_CAP_MS]) if not lc.is_empty() else "none this process"))
	var sr := soft_restarted()
	if not sr.is_empty():
		L.append("  This process: soft restart at %s from %s to %s (%s)%s" % [sr.get("where", "?"),
				sr.get("from", "") if sr.get("from", "") != "" else "bundled game", sr.get("to", "?"), sr.get("note", ""),
				("; " + str(sr["result"])) if str(sr.get("result", "")) != "" else ""])
	var rec := SoftRestart.record_read()
	var last: Dictionary = rec["last"]
	L.append("  Last attempt: %s" % (("%s at %s from %s, %s: %s" % [last.get("ota_id", "?"), last.get("where", "?"), last.get("from", "?"), last.get("time", "?"), last.get("result", "?")]) if not last.is_empty() else "none"))
	if Boot.core != null:
		var r := applicable(Boot.core, rec["attempts"], {}, false)
		L.append("  Waiting: %s" % (("%s (installs at the next safe moment)" % r[0]["ota_id"]) if not (r[0] as Dictionary).is_empty() else r[1]))
	return "\n".join(L)

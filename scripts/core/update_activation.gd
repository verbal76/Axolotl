extends RefCounted
## GAME LAYER — "Please wait, applying update": the one moment an update becomes the running code.
##
## Activation is the in-process soft restart (SoftRestart.apply): the native layer re-verifies and
## mounts PENDING, the game layer is recompiled from the new pack and the main scene reloads. This
## file owns what the player sees during exactly that window, and the state that says whether it is
## happening:
##   * begin() when SoftRestart.apply starts the switch (after the save, before anything changes);
##     a second activation while one runs is refused;
##   * finish() when the native layer did not mount it (the old game keeps running), or when the
##     NEW game's loading screen is on screen (success, or the in-process failure that went back);
##   * the state lives in Engine metadata, which survives the script recompile in the middle, and
##     expires by itself after SAFETY_MS, so nothing can report "applying" for ever.
## The modal is built from plain engine nodes only (no game script attached: it stays up while
## every game script is recompiled) and carries its own safety timer: if the new game never lifts
## it, it turns into a short message and removes itself.
## Checking and downloading never show it (they are background work; the game keeps running).

const META := "mote_update_activation"
const TEXT := "Please wait, applying update"
const TIMEOUT_TEXT := "The update did not finish. Mote will try again on the next start."
## Same node name as before, so a version without this file still lifts it (SoftRestart.lift_curtain).
const NODE_NAME := "AutoUpdateCurtain"
const SAFETY_MS := 20000
## How long the timeout message stays before the modal removes itself.
const TIMEOUT_MESSAGE_S := 3.0
const UI_STYLE_PATH := "res://scripts/ui/ui_style.gd"
const BG := Color(0.04, 0.1, 0.1, 1.0)


# --- activation state (Engine metadata: survives scene changes and script reloads) ----------

static func state() -> Dictionary:
	return Engine.get_meta(META, {}) as Dictionary


## True while an activation started less than SAFETY_MS ago and has not finished.
static func is_applying(now_ms := -1) -> bool:
	var s := state()
	if str(s.get("state", "")) != "applying":
		return false
	var now := now_ms if now_ms >= 0 else Time.get_ticks_msec()
	return now - int(s.get("t_ms", 0)) < SAFETY_MS


## Starts the activation of `ota_id`. False (and nothing changes) when one is already running.
static func begin(ota_id: String, now_ms := -1) -> bool:
	if is_applying(now_ms):
		return false
	Engine.set_meta(META, {"state": "applying", "ota_id": ota_id, "t_ms": now_ms if now_ms >= 0 else Time.get_ticks_msec(), "result": ""})
	return true


## Ends the running activation: `ok` true when the new version is the one now starting.
static func finish(ok: bool, result := "") -> void:
	var s := state()
	if str(s.get("state", "")) != "applying":
		return
	s["state"] = "done" if ok else "failed"
	s["result"] = result
	Engine.set_meta(META, s)


## Pure: the update state shown in About. `f` holds the facts:
## ota_enabled, disabled, applying, activation ("" | "done" | "failed"), active_id, pending_id,
## ready_id, updater_status (OtaUpdater.status), has_available.
## One of CURRENT, AVAILABLE, STAGED, APPLYING, FAILED, or a qualified UNKNOWN / OFF.
static func phase(f: Dictionary) -> String:
	if not f.get("ota_enabled", false):
		return "OFF (no OTA client in this build)"
	if f.get("disabled", false):
		return "OFF (OTA disabled: bundled baseline mode)"
	if f.get("applying", false):
		return "APPLYING"
	var pend := str(f.get("pending_id", ""))
	if (pend != "" and pend != str(f.get("active_id", ""))) or str(f.get("ready_id", "")) != "":
		return "STAGED"
	if str(f.get("activation", "")) == "failed":
		return "FAILED"
	match str(f.get("updater_status", "unchecked")):
		"up_to_date":
			return "CURRENT"
		"available", "downloading":
			return "AVAILABLE"
		"failed", "rejected":
			return "FAILED"
		"incompatible":
			return "CURRENT (latest OTA needs a newer app)"
		"checking":
			return "UNKNOWN (checking)"
		"offline":
			return "UNKNOWN (offline)"
		"downloaded":
			return "STAGED"
	return "UNKNOWN (not checked yet)"


## Only actual activation shows the modal.
static func shows_modal(p: String) -> bool:
	return p == "APPLYING"


## The facts phase() needs, read from the running native layer.
static func facts() -> Dictionary:
	var boot: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Boot")
	var core = boot.get("core") if boot != null else null
	var up = boot.get("updater") if boot != null else null
	var on: bool = boot != null and bool(boot.get("ota_enabled")) and core != null
	return {
		"ota_enabled": on,
		"disabled": on and bool(core.state.get("disabled", false)),
		"applying": is_applying(),
		"activation": str(state().get("state", "")),
		"active_id": str(core.active.get("ota_id", "")) if on else "",
		"pending_id": str(core.slot("pending").get("ota_id", "")) if on else "",
		"ready_id": str(core.slot("ready").get("ota_id", "")) if on else "",
		"updater_status": str(up.status) if up != null else "unchecked",
		"has_available": up != null and up.has_available(),
	}


static func current_phase() -> String:
	return phase(facts())


# --- the modal ---------------------------------------------------------------------------------

## Builds the modal under the root (replacing any earlier one) and returns it. Mote's loading-
## screen backdrop (so the hand-over to the new loading screen is seamless) with a Mote panel in
## the middle: the text and an indeterminate bar. Blocks touches and clicks. `safety_s` (tests)
## overrides SAFETY_MS.
static func show_modal(tree: SceneTree, safety_s := -1.0) -> CanvasLayer:
	var old := tree.root.get_node_or_null(NODE_NAME)
	if old != null:
		old.free()
	var c := CanvasLayer.new()
	c.name = NODE_NAME
	c.layer = 101
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var st: Script = load(UI_STYLE_PATH) if ResourceLoader.exists(UI_STYLE_PATH) else null
	if st != null and st.has_method("theme"):
		bg.theme = st.call("theme")
	c.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	panel.add_child(v)
	var label := Label.new()
	label.name = "Message"
	label.text = TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 30)
	v.add_child(label)
	var bar := ProgressBar.new()
	bar.name = "Indicator"
	bar.indeterminate = true
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.25, 0.23, 0.95)
	track.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.5, 0.97, 0.84, 0.95)
	fill.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	v.add_child(bar)
	# Safety: never hang. Engine-only callables (this script may be recompiled meanwhile).
	var safety := Timer.new()
	safety.name = "Safety"
	safety.one_shot = true
	safety.process_mode = Node.PROCESS_MODE_ALWAYS
	safety.wait_time = safety_s if safety_s > 0.0 else SAFETY_MS / 1000.0
	safety.autostart = true
	var gone := Timer.new()
	gone.name = "Remove"
	gone.one_shot = true
	gone.process_mode = Node.PROCESS_MODE_ALWAYS
	gone.wait_time = TIMEOUT_MESSAGE_S if safety_s <= 0.0 else safety_s
	safety.timeout.connect(label.set_text.bind(TIMEOUT_TEXT))
	safety.timeout.connect(bar.hide)
	safety.timeout.connect(gone.start)
	gone.timeout.connect(c.queue_free)
	c.add_child(safety)
	c.add_child(gone)
	tree.root.add_child(c)
	return c


## The modal currently up, or null.
static func modal(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null(NODE_NAME) if tree != null else null

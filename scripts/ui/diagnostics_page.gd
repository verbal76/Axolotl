class_name DiagnosticsPage
extends CanvasLayer
## GAME LAYER — the everyday About / Diagnostics screen (owner, 2026-10-01).
##
## Updates are automatic now (AutoUpdate), so this page shows the state first (version, the
## running OTA, whether Mote is up to date) with the full diagnostics text under it, and keeps
## only what a player needs: Check for updates, Install now (only while an update waits and the
## title is showing), Copy, Close. Every recovery tool (download, activate, roll back, bundled
## baseline, close app) stays in the native panel behind Advanced, unchanged: that panel is part
## of the installed app (scripts/boot), which an OTA cannot change, and its safety checks are the
## same ones this page relies on.

const SoftRestart := preload("res://scripts/core/soft_restart.gd")

var _root: Control
var _panel: PanelContainer
var _status: Label
var _detail: Label
var _text: Label
var _check: Button
var _install: Button
var _say := ""


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.05, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_panel = PanelContainer.new()
	_panel.name = "DiagnosticsPanel"
	var pbox := (UiStyle.theme().get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate() as StyleBoxFlat
	pbox.bg_color.a = 0.98
	pbox.set_content_margin_all(26)
	_panel.add_theme_stylebox_override("panel", pbox)
	_root.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_panel.add_child(v)
	_status = Label.new()
	_status.name = "Status"
	_status.add_theme_font_size_override("font_size", 30)
	_status.add_theme_color_override("font_color", Color(1.0, 0.86, 0.55))
	v.add_child(_status)
	_detail = Label.new()
	_detail.name = "Detail"
	_detail.add_theme_font_size_override("font_size", 21)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_detail)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_text = Label.new()
	_text.name = "Text"
	_text.add_theme_font_size_override("font_size", 17)
	_text.add_theme_color_override("font_color", Color(0.8, 0.92, 0.88, 0.9))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_text)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	_check = _btn(row, "Check", "Check for updates", _on_check)
	_install = _btn(row, "Install", "Install now", _on_install)
	_btn(row, "Copy", "Copy", func(): DisplayServer.clipboard_set(Boot.diagnostics_text()); _say = "Diagnostics copied."; _refresh())
	var adv := _btn(row, "Advanced", "Advanced", func(): Boot.show_diagnostics())
	adv.modulate = Color(1, 1, 1, 0.75)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var close := _btn(row, "Close", "Close", close)
	close.theme_type_variation = "PrimaryButton"
	get_viewport().size_changed.connect(_layout)
	visible = false


func _btn(row: Control, name_: String, text: String, cb: Callable) -> Button:
	var b := UiStyle.button(text, cb)
	b.name = name_
	b.custom_minimum_size = Vector2(150, 64)
	b.add_theme_font_size_override("font_size", 24)
	row.add_child(b)
	return b


func open() -> void:
	_say = ""
	visible = true
	_layout()
	_refresh()
	_check.grab_focus.call_deferred()


func close() -> void:
	visible = false


func _process(_dt: float) -> void:
	if visible:
		_refresh()


func _layout() -> void:
	var vp := _root.get_viewport_rect().size
	var m := Vector2(maxf(40.0, vp.x * 0.05), maxf(24.0, vp.y * 0.05))
	_panel.position = m
	_panel.size = vp - m * 2.0


## The update the automatic installer would take now ({} when none).
static func waiting_update() -> Dictionary:
	if Boot.core == null:
		return {}
	var r: Array = AutoUpdate.applicable(Boot.core, SoftRestart.record_read()["attempts"], {}, false)
	return r[0]


## The headline: up to date, an update on its way / waiting, checking, or OTA off.
static func status_line() -> String:
	if not Boot.ota_enabled or Boot.core == null or Boot.updater == null:
		return "Updates are off in this build"
	if Boot.updater.busy:
		return "Checking for updates..."
	var w := waiting_update()
	if not w.is_empty():
		return "Update %s ready" % w.get("ota_id", "?")
	if Boot.updater.has_available():
		return "Update available"
	if Boot.updater.status == "unchecked":
		return "Not checked yet this session"
	return "Mote is up to date"


func _refresh() -> void:
	var id: Dictionary = Boot.identity()
	_status.text = status_line()
	var active := str(id.get("ota_id", "none"))
	var where := "installs on the title screen" if not waiting_update().is_empty() else ""
	_detail.text = "Version %s  ·  running %s  ·  Android build %s%s%s" % [id.get("game_version", "?"),
			active if active != "none" else "the bundled game", id.get("native_build", "?"),
			("\n" + where) if where != "" else "", ("\n" + _say) if _say != "" else ""]
	var on_title: bool = Game.inst != null and Game.inst.state == "title"
	_install.visible = not waiting_update().is_empty() and on_title
	_check.disabled = Boot.updater == null or not Boot.ota_enabled or Boot.updater.busy
	var t := Boot.diagnostics_text()
	if _text.text != t:
		_text.text = t


func _on_check() -> void:
	_say = "Checking..."
	var r: String = await Boot.updater.check(true)
	_say = r


## An update waits and the title shows: close this page and the settings so the automatic
## installer finds its safe moment straight away (it saves first, as always).
func _on_install() -> void:
	close()
	if Game.inst != null and Game.inst.pause_menu.visible:
		Game.inst.pause_menu.close()

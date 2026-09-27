class_name PauseMenu
extends CanvasLayer
## Small pause/settings menu: Resume, Reduced HUD, audio levels, haptics, controller/touch
## status, Restart Experience, Return to Title.

var _root: Control
var _panel: PanelContainer
var _status: Label
var _reduced: CheckButton
var _haptics: CheckButton
var _music: HSlider
var _sfx: HSlider
var _session_rows: Array[Control] = []
var _from_title := false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.05, 0.05, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	center.add_child(_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, 560)
	_panel.add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var resume := UiStyle.button("Resume", close)
	v.add_child(resume)
	_reduced = CheckButton.new()
	_reduced.text = "Reduced HUD"
	_reduced.toggled.connect(_on_reduced)
	v.add_child(_reduced)
	_haptics = CheckButton.new()
	_haptics.text = "Haptics"
	_haptics.toggled.connect(_on_haptics)
	v.add_child(_haptics)
	_music = _slider(v, "Music")
	_music.value_changed.connect(_on_music)
	_sfx = _slider(v, "Sound")
	_sfx.value_changed.connect(_on_sfx)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 22)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_status)
	var restart := UiStyle.button("Restart Experience", func(): Game.inst.restart_experience())
	v.add_child(restart)
	var title := UiStyle.button("Return to Title", func(): Game.inst.return_to_title())
	v.add_child(title)
	# Version, build, OTA and source identities (and OTA recovery in dev builds).
	v.add_child(UiStyle.button("About / Diagnostics", func(): Boot.show_diagnostics()))
	_session_rows = [restart, title]
	resume.name = "Resume"
	visible = false
	Settings.settings_changed.connect(_refresh)
	Settings.input_mode_changed.connect(func(_m): _refresh())


func _on_reduced(on: bool) -> void:
	Settings.reduced_hud = on
	Settings.save()


func _on_haptics(on: bool) -> void:
	Settings.haptics = on
	Settings.save()
	if on:
		Settings.haptic("tap")


func _on_music(x: float) -> void:
	Settings.music_volume = x
	Settings.save()


func _on_sfx(x: float) -> void:
	Settings.sfx_volume = x
	Settings.save()


func _slider(parent: Control, text: String) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(300, 48)
	row.add_child(s)
	parent.add_child(row)
	return s


func open(from_title := false) -> void:
	_from_title = from_title
	for r in _session_rows:
		r.visible = not from_title
	_refresh()
	visible = true
	if not from_title:
		get_tree().paused = true
	(_panel.find_child("Resume", true, false) as Button).grab_focus.call_deferred()


func close() -> void:
	visible = false
	get_tree().paused = false
	Sfx.play("ui_tap", null, -8.0)


func _refresh() -> void:
	_reduced.set_pressed_no_signal(Settings.reduced_hud)
	_haptics.set_pressed_no_signal(Settings.haptics)
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_status.text = Settings.controller_status()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

class_name TitleScreen
extends CanvasLayer
## Minimal live-environment title: the murky starting aquarium with the axolotl at home.
## Title, Play, Settings. No lore, no exposition.

var _root: Control
var _play: Button
var version_label: Label


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	box.position = Vector2(110, -40)
	box.add_theme_constant_override("separation", 18)
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = 110
	box.offset_top = -170
	_root.add_child(box)
	var title := Label.new()
	title.text = "Axolotl"
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.86))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.18, 0.16, 0.8))
	title.add_theme_constant_override("outline_size", 10)
	box.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)
	_play = UiStyle.button("Play", _on_play)
	box.add_child(_play)
	box.add_child(UiStyle.button("Settings", _on_settings))
	# Product version only; build/OTA/SHA identities live in Diagnostics.
	var ver := Label.new()
	ver.name = "VersionLabel"
	ver.text = GameVersion.display()
	ver.add_theme_font_size_override("font_size", 22)
	ver.add_theme_color_override("font_color", Color(0.85, 0.95, 0.92, 0.7))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ver.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ver.offset_right = -28
	ver.offset_bottom = -20
	_root.add_child(ver)
	version_label = ver
	visible = false


func show_title() -> void:
	visible = true
	_play.grab_focus.call_deferred()


func hide_title() -> void:
	visible = false


func _on_play() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.start_play()


func _on_settings() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.pause_menu.open(true)

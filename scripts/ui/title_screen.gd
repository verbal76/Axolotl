class_name TitleScreen
extends CanvasLayer
## Minimal live-environment title: the murky starting aquarium with Gill at home.
## MOTE, the game version, Play (or Continue / New Run when a run is saved), Settings, and one
## line about the saved run. No lore, no exposition.

var _root: Control
var _play: Button
var _new_run: VBoxContainer
var _treasure: Button
var _run_info: Label
var _column: VBoxContainer
var _colours: Button
var _skills: Button
var _aquarium: Button
var gear: Button
var version_label: Label
var title_label: Label


func _ready() -> void:
	layer = 20
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiStyle.theme()
	add_child(_root)
	# A soft shade behind the menu side, so the menu reads over the live aquarium without a box.
	var shade := TextureRect.new()
	shade.name = "Shade"
	var grad := Gradient.new()
	grad.set_color(0, Color(0.0, 0.05, 0.05, 0.62))
	grad.set_color(1, Color(0.0, 0.05, 0.05, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0.5)
	gt.fill_to = Vector2(1, 0.5)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	var title := Label.new()
	title.name = "Title"
	title.text = GameVersion.title()
	title_label = title
	title.add_theme_color_override("font_color", Color(0.99, 0.8, 0.85))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.16, 0.15, 0.9))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	title.add_theme_constant_override("shadow_offset_y", 4)
	_root.add_child(title)
	_run_info = UiStyle.note()
	_run_info.name = "RunInfo"
	_run_info.autowrap_mode = TextServer.AUTOWRAP_OFF
	_root.add_child(_run_info)
	_column = VBoxContainer.new()
	_column.name = "Menu"
	_root.add_child(_column)
	_play = UiStyle.button("Play", _on_play)
	_play.name = "Play"
	_play.theme_type_variation = "PrimaryButton"
	_column.add_child(_play)
	_new_run = UiStyle.confirm_button("New Run", "Start a new run? This run's progress and time are replaced (your best finish is kept).",
			"Start over", _on_new_run)
	_column.add_child(_new_run)
	_colours = UiStyle.button("%s's colours" % GameVersion.CHARACTER_NAME, _on_colours)
	_colours.name = "GillColours"
	_column.add_child(_colours)
	# The skill tree (docs/SKILL_TREE.md): permanent, so it is here before Play too.
	_skills = UiStyle.button("Skills", _on_skills)
	_skills.name = "Skills"
	_column.add_child(_skills)
	# Treasure Hunt: shown only once the run is complete (100%); never a teaser before.
	_treasure = UiStyle.button("Treasure Hunt", _on_treasure)
	_treasure.name = "TreasureHunt"
	_treasure.visible = false
	_column.add_child(_treasure)
	_aquarium = UiStyle.button("Aquarium", _on_aquarium)
	_aquarium.name = "Aquarium"
	_column.add_child(_aquarium)
	# Settings (with the build, version and OTA diagnostics) straight from the title, before Play or
	# Continue (owner, 2026-09-30): the owner's gear, top right, always on screen.
	gear = UiStyle.gear_button(_on_settings)
	_root.add_child(gear)
	# Product version only; build/OTA/SHA identities live in Diagnostics (behind the gear).
	var ver := Label.new()
	ver.name = "VersionLabel"
	ver.text = GameVersion.display()
	ver.add_theme_font_size_override("font_size", 22)
	ver.add_theme_color_override("font_color", Color(0.85, 0.95, 0.92, 0.7))
	_root.add_child(ver)
	version_label = ver
	get_viewport().size_changed.connect(_layout)
	visible = false


## Fits the title, the menu and the gear inside the display's safe area at any landscape shape.
func _layout() -> void:
	var vp := _root.get_viewport_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var m := Vector4(24, 16, 24, 16)    # left, top, right, bottom
	if win.x > 0 and win.y > 0 and safe.size.x > 0:
		m.x = maxf(m.x, safe.position.x * vp.x / win.x)
		m.y = maxf(m.y, safe.position.y * vp.y / win.y)
		m.z = maxf(m.z, (win.x - safe.end.x) * vp.x / win.x)
		m.w = maxf(m.w, (win.y - safe.end.y) * vp.y / win.y)
	var area := Rect2(m.x, m.y, vp.x - m.x - m.z, vp.y - m.y - m.w)
	var s := clampf(vp.y / 720.0, 0.75, 1.5)
	var shade: Control = _root.get_node("Shade")
	shade.position = Vector2.ZERO
	shade.size = Vector2(minf(vp.x * 0.55, 820 * s), vp.y)
	var left := area.position.x + 56 * s
	title_label.add_theme_font_size_override("font_size", int(100 * s))
	title_label.add_theme_constant_override("outline_size", int(10 * s))
	title_label.position = Vector2(left - 6 * s, area.position.y + 18 * s)
	title_label.size = Vector2(700 * s, 120 * s)
	_run_info.add_theme_font_size_override("font_size", int(21 * s))
	_run_info.position = Vector2(left, title_label.position.y + 116 * s)
	_run_info.size = Vector2(minf(760 * s, area.size.x - 200 * s), 60 * s)
	# The menu column: buttons as tall as fit between the run line and the bottom of the safe area.
	var top := _run_info.position.y + (58 * s if _run_info.visible else 8 * s)
	var n := 0
	for c in _column.get_children():
		if (c as Control).visible:
			n += 1
	var room := area.end.y - 10 * s - top
	var sep := 14.0 * s
	var h := clampf((room - sep * (n - 1)) / maxf(1, n), 50.0 * s, 70.0 * s)
	_column.add_theme_constant_override("separation", int(sep))
	for b in [_play, _colours, _skills, _treasure, _aquarium, _new_run.get_node("Ask")]:
		(b as Button).custom_minimum_size = Vector2(380 * s, h)
		(b as Button).add_theme_font_size_override("font_size", int(clampf(h * 0.44, 22, 34)))
	_column.position = Vector2(left, top)
	_column.size = Vector2(380 * s, 0)
	gear.custom_minimum_size = Vector2(96, 96) * s
	gear.size = gear.custom_minimum_size
	gear.add_theme_constant_override("icon_max_width", int(62 * s))
	gear.pivot_offset = gear.size * 0.5
	gear.position = Vector2(area.end.x - gear.size.x - 4 * s, area.position.y + 4 * s)
	version_label.add_theme_font_size_override("font_size", int(20 * s))
	version_label.reset_size()
	version_label.position = area.end - version_label.size - Vector2(8, 4) * s


func show_title() -> void:
	var g := Game.inst
	var saved := g.has_run_in_progress()
	_play.text = "Continue" if saved else "Play"
	_new_run.visible = saved
	var lines: Array[String] = []
	if saved:
		lines.append(g.run_line())
	if g.best_line() != "":
		lines.append(g.best_line())
	# (Only once there is any: a first launch stays as clean as before.)
	if g.gill != null and (g.gill.stars() > 0 or g.gill.skills() > 0):
		lines.append(g.progress_line())
	_run_info.text = "\n".join(lines)
	_run_info.visible = not lines.is_empty()
	_treasure.visible = g.treasure != null and g.treasure.eligible()
	visible = true
	_layout()
	_play.grab_focus.call_deferred()


func hide_title() -> void:
	visible = false


func _on_play() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.start_play()


func _on_new_run() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.restart_experience()


## Straight to his colours page (the pause menu's, opened from here), with his live preview.
func _on_colours() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.pause_menu.open(true)
	Game.inst.pause_menu._open_gill(true)


## The aquarium experiences (docs/AQUARIUM.md): the bedroom, the tank, Live Tank and Swim Mode.
func _on_treasure() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.treasure.start()
	Game.inst.start_play()


func _on_aquarium() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.presentation.enter("title")


## Straight to the skill tree (the pause menu's page, opened from here).
func _on_skills() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.pause_menu.open(true)
	Game.inst.pause_menu._open_skills(true)


func _on_settings() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.pause_menu.open(true)

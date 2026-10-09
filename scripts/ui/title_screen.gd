class_name TitleScreen
extends CanvasLayer
## Minimal live-environment title: the murky starting aquarium with Gill at home.
## MOTE, the game version, Play (or Continue / New Run when a run is saved), Settings, and one
## line about the saved run. No lore, no exposition.

var _root: Control
var _play: Button
var _new_run: VBoxContainer
var _treasure: Button
var _treasure_ok := false
var _run_info: Label
var _column: VBoxContainer
var _colours: Button
var _skills: Button
var _aquarium: Button
var gear: Button
var player_button: Button
var players_page: PlayersPage
## Exit (owner, 2026-10-01): bottom right, away from the menu column, behind a confirm.
var exit_box: VBoxContainer
var version_label: Label
var title_label: Label
## New Run's question: a two-choice dialog, Normal or Hard Mode (ledger row 12; the mode is chosen
## here only, and a run never changes mode).
const NEW_RUN_QUESTION := "Start a new run? Best finishes are kept. Hard: restored moss can fade."


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
	UiStyle.make_primary(_play)
	_column.add_child(_play)
	_new_run = UiStyle.confirm_button("New Run", NEW_RUN_QUESTION, "Normal", _on_new_run, "Hard", _on_new_run_hard)
	_column.add_child(_new_run)
	# (While its question is open, the other buttons step aside: the question and its two answers
	# need the column's room, and squeezed in they pushed the last buttons off the screen.)
	(_new_run.get_node("Confirm") as Control).visibility_changed.connect(_on_new_run_asking)
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
	# Who's playing (owner, 2026-10-08; Players): the player's name, beside the gear; it opens the
	# page to switch, add, rename or delete players.
	player_button = UiStyle.button("", _on_players)
	player_button.name = "PlayerButton"
	_root.add_child(player_button)
	players_page = PlayersPage.new()
	_root.add_child(players_page)
	players_page.done.connect(func() -> void:
		players_page.visible = false
		player_button.grab_focus.call_deferred())
	exit_box = UiStyle.confirm_button("Exit", "Leave Mote? Your run is saved.", "Exit", func(): Game.inst.exit_game())
	exit_box.name = "Exit"
	exit_box.alignment = BoxContainer.ALIGNMENT_END
	_root.add_child(exit_box)
	(exit_box.get_node("Confirm") as Control).visibility_changed.connect(_layout)
	# Product version only; build/OTA/SHA identities live in Diagnostics (behind the gear).
	var ver := Label.new()
	ver.name = "VersionLabel"
	ver.text = GameVersion.display()
	ver.add_theme_font_size_override("font_size", 22)
	ver.add_theme_color_override("font_color", Color(0.85, 0.95, 0.92, 0.7))
	_root.add_child(ver)
	version_label = ver
	# (Who's playing covers the whole title, Exit and the version line included.)
	_root.move_child(players_page, -1)
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
	# (Room for every line of the run info: two before the skill tree, three with its progress line.)
	var info_lines := maxi(2, _run_info.text.count("\n") + 1)
	# (Measured from the font, not a guessed 29 px a line: the third line, starfish and skills, sat on
	# the Continue button. A clear gap of 18 px always separates the last line from the buttons.)
	var line_h := float(_run_info.get_line_height())
	_run_info.size.y = line_h * info_lines
	var top := _run_info.position.y + (line_h * info_lines + 18 * s if _run_info.visible else 8 * s)
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
	player_button.text = "Player: %s" % Players.current_name()
	player_button.add_theme_font_size_override("font_size", int(24 * s))
	player_button.custom_minimum_size = Vector2(0, 64 * s)
	player_button.reset_size()
	player_button.position = Vector2(gear.position.x - player_button.size.x - 14 * s, gear.position.y + (gear.size.y - player_button.size.y) * 0.5)
	version_label.add_theme_font_size_override("font_size", int(20 * s))
	version_label.reset_size()
	version_label.position = area.end - version_label.size - Vector2(8, 4) * s
	# Exit: modest, bottom right above the version line (a thumb's reach, far from the column's buttons);
	# its question opens upward from there.
	var ask: Button = exit_box.get_node("Ask")
	ask.custom_minimum_size = Vector2(200, 58) * s
	ask.add_theme_font_size_override("font_size", int(24 * s))
	exit_box.reset_size()
	exit_box.position = Vector2(area.end.x - exit_box.size.x - 8 * s, version_label.position.y - exit_box.size.y - 12 * s)


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
	_treasure_ok = g.treasure != null and g.treasure.eligible()
	# (The New Run question starts closed each time the title shows.)
	(_new_run.get_node("Confirm") as Control).visible = false
	(_new_run.get_node("Ask") as Control).visible = true
	(exit_box.get_node("Confirm") as Control).visible = false
	(exit_box.get_node("Ask") as Control).visible = true
	_on_new_run_asking()
	visible = true
	_layout()
	_play.grab_focus.call_deferred()


func _on_new_run_asking() -> void:
	var asking: bool = (_new_run.get_node("Confirm") as Control).visible
	for b in [_colours, _skills, _aquarium]:
		(b as Control).visible = not asking
	_treasure.visible = _treasure_ok and not asking
	if visible:
		_layout()


func hide_title() -> void:
	visible = false


func _on_play() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.begin_play()


func _on_new_run() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.restart_experience()


func _on_new_run_hard() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.restart_experience(HardMode.MODE)


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


func _on_players() -> void:
	players_page.open()


func _on_settings() -> void:
	Sfx.play("ui_tap", null, -6.0)
	Game.inst.pause_menu.open(true)

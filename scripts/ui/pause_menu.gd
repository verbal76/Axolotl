class_name PauseMenu
extends CanvasLayer
## The pause / Settings menu: one wide landscape panel with nothing to scroll (phone audit
## 2026-09-30 §A, owner ruling). Left: the actions, Resume first and Return to Title directly beneath
## it (owner ruling 2026-09-30), then New Run, Aquarium | Whole ball (one row), Treasure Hunt, the colours page (GillPage)
## and Skills (SkillTreePage). Right: this run (time; the ball he is on, its % and tunnel; completion,
## finish, best), the Tier 2 loadout,
## the toggles, Music and Sound, controller/touch status, About / Diagnostics and the startup line.
## Every control is at least 56 px tall.

## The panel's widest, and its left column's width (design px).
const PANEL_MAX_W := 1212.0
const LEFT_W := 400.0
## No control in it is shorter than this (design px).
const MIN_TOUCH := 56.0

var _loadout: Tier2Loadout
var _aquarium: Button
var _treasure: Button
var _root: Control
var _panel: PanelContainer
var _status: Label
var _startup: Label
var _reduced: CheckButton
var _timer_toggle: CheckButton
var _run_time: Label
var _run_detail: RichTextLabel
## The current ball's line shown above the run table ("" when none): BallView.progress_line.
var _ball_line := ""
var _haptics: CheckButton
var _swim_invert: CheckButton
var _resume: Button
var _tutorials: CheckButton
var _music: TouchSlider
var _sfx: TouchSlider
var _left: VBoxContainer
var _right: VBoxContainer
var _session_rows: Array[Control] = []
var _from_title := false
var gill_page: GillPage
var _gill_direct := false        # opened straight from the title screen
## The skill tree (docs/SKILL_TREE.md): a page of its own beside the colours page.
var skill_page: SkillTreePage
var guide_page: FieldGuidePage
var _replay: Button
var _skills_direct := false
var _skills_button: Button


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
	_panel = PanelContainer.new()
	_panel.name = "SettingsPanel"
	var pbox := (UiStyle.theme().get_stylebox("panel", "PanelContainer") as StyleBoxFlat).duplicate() as StyleBoxFlat
	pbox.content_margin_left = 28
	pbox.content_margin_right = 28
	pbox.content_margin_top = 18
	pbox.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", pbox)
	_root.add_child(_panel)
	var cols := HBoxContainer.new()
	cols.name = "Columns"
	cols.add_theme_constant_override("separation", 28)
	_panel.add_child(cols)
	# --- Left: what to do ---
	_left = VBoxContainer.new()
	_left.name = "Actions"
	_left.custom_minimum_size = Vector2(LEFT_W, 0)
	_left.add_theme_constant_override("separation", 8)
	cols.add_child(_left)
	var resume := _action("Resume", close)
	UiStyle.make_primary(resume)
	_resume = resume
	# Return to Title directly beneath Resume (owner ruling 2026-09-30).
	# (Owner, 2026-10-08: says what it does; the run is saved first, as it always was.)
	var title := _action("Save & Return to Title", func() -> void:
		if not Game.inst.return_to_title():
			(_panel.find_child("ReturnToTitle", true, false) as Button).text = "Not saved: try again")
	title.name = "ReturnToTitle"
	var restart := UiStyle.confirm_button("New Run", TitleScreen.NEW_RUN_QUESTION, "Normal", func(): Game.inst.restart_experience(),
			"Hard", func(): Game.inst.restart_experience(HardMode.MODE))
	restart.name = "NewRun"
	for c in restart.find_children("*", "Button", true, false):
		(c as Button).custom_minimum_size.y = 64
	(restart.find_child("Ask", true, false) as Button).custom_minimum_size = Vector2(LEFT_W, 64)
	for c in restart.find_children("*", "Label", true, false):
		(c as Label).add_theme_font_size_override("font_size", 20)
		(c as Label).custom_minimum_size.x = LEFT_W
	_left.add_child(restart)
	# The aquarium experiences (the run is saved and stands still meanwhile). (The whole moss ball
	# is the HUD's top-left button since 2026-10-08, owner: no longer here.)
	var looks := HBoxContainer.new()
	looks.name = "Looks"
	_left.add_child(looks)
	_aquarium = _action("Aquarium", _open_aquarium)
	_aquarium.name = "Aquarium"
	_left.remove_child(_aquarium)
	looks.add_child(_aquarium)
	_aquarium.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Treasure Hunt (postgame, docs/TREASURE_HUNT.md): only once the run is at 100%.
	_treasure = _action("Treasure Hunt", _toggle_treasure)
	_treasure.name = "TreasureHunt"
	var colours := _action("%s's colours" % GameVersion.CHARACTER_NAME, _open_gill)
	colours.name = "GillColours"
	# The skill tree (00036).
	_skills_button = _action("Skills", _open_skills)
	_skills_button.name = "Skills"
	# The Field guide (owner, 2026-10-08): the permanent reference for what the lessons teach
	# (FieldGuidePage), in a run and from the title alike. Half-width beside the colours, in one
	# row as Aquarium | Whole ball (the column has no room for another).
	var guide := _action("Field guide", _open_guide)
	guide.name = "FieldGuide"
	var pair := HBoxContainer.new()
	pair.name = "ColoursGuide"
	pair.add_theme_constant_override("separation", 8)
	_left.add_child(pair)
	_left.move_child(pair, colours.get_index())
	for half in [colours, guide]:
		_left.remove_child(half)
		pair.add_child(half)
		half.custom_minimum_size = Vector2((LEFT_W - 8.0) / 2.0, 64)
		half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		half.add_theme_font_size_override("font_size", 20)
		# (Never wider than half: a long name never pushes the column, and the menu, wider.)
		half.clip_text = true
	# --- Right: this run, then the settings ---
	_right = VBoxContainer.new()
	_right.name = "Details"
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# (10, not 12: room for this ball's line above the run table with nothing to scroll.)
	_right.add_theme_constant_override("separation", 10)
	cols.add_child(_right)
	# This run: time, completion, finished or not, best finish (two columns of detail).
	_run_time = Label.new()
	_run_time.name = "RunTime"
	_run_time.add_theme_font_size_override("font_size", 30)
	_run_time.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_right.add_child(_run_time)
	_run_detail = RichTextLabel.new()
	_run_detail.name = "RunDetail"
	_run_detail.bbcode_enabled = true
	_run_detail.fit_content = true
	_run_detail.scroll_active = false
	_run_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_detail.add_theme_font_size_override("normal_font_size", 20)
	_run_detail.add_theme_color_override("default_color", Color(0.85, 0.95, 0.92, 0.85))
	_right.add_child(_run_detail)
	# Tier 2: equip one of the abilities found this run (shown once one is found), in one row.
	_loadout = Tier2Loadout.new()
	_right.add_child(_loadout)
	# The toggles, two by two.
	var toggles := GridContainer.new()
	toggles.name = "Toggles"
	toggles.columns = 2
	toggles.add_theme_constant_override("h_separation", 10)
	toggles.add_theme_constant_override("v_separation", 8)
	_right.add_child(toggles)
	_timer_toggle = _toggle(toggles, "Show run timer", _on_timer_toggle)
	_timer_toggle.name = "ShowRunTimer"
	_reduced = _toggle(toggles, "Reduced HUD", _on_reduced)
	_reduced.name = "ReducedHUD"
	_haptics = _toggle(toggles, "Haptics", _on_haptics)
	_haptics.name = "Haptics"
	# Swim Mode only: the flight-stick pitch the other way round (owner, 2026-09-30).
	_swim_invert = _toggle(toggles, "Invert swim up/down", func(on: bool) -> void:
		Settings.swim_invert_y = on
		Settings.save())
	_swim_invert.name = "SwimInvert"
	_swim_invert.tooltip_text = "Off: pull the stick down to swim up. On: push it up to swim up. Swim Mode only."
	# Tutorials (owner ruling 2026-10-01, docs/ONBOARDING.md): the intro and the three lessons on
	# every new run. Off skips them; turned off mid-lesson, the lesson ends at once.
	_tutorials = _toggle(toggles, "Tutorials", _on_tutorials)
	_tutorials.name = "Tutorials"
	_tutorials.tooltip_text = "On: every new run starts with the intro and short lessons, and names new creatures as you meet them. Off: none. The Field guide is always here."
	# Replay tutorial (owner, 2026-10-08): this run's lessons, names and hints from the start (the
	# intro on Resume, then each lesson at its moment), so a longtime player sees the new tutorial.
	# Progress is untouched. In a run only (a session row).
	_replay = UiStyle.button("Replay tutorial (keeps run)", _on_replay_tutorial)
	_replay.tooltip_text = "Plays the tutorial again during this run. Your run, progress and Skills stay exactly as they are."
	_replay.name = "ReplayTutorial"
	_replay.custom_minimum_size = Vector2(0, 60)
	_replay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_replay.add_theme_font_size_override("font_size", 22)
	toggles.add_child(_replay)
	# Music | Sound.
	var levels := HBoxContainer.new()
	levels.name = "Levels"
	levels.add_theme_constant_override("separation", 12)
	_right.add_child(levels)
	_music = _slider(levels, "Music")
	_music.value_changed.connect(_on_music)
	_sfx = _slider(levels, "Sound")
	_sfx.value_changed.connect(_on_sfx)
	# Controller/touch status and the launch time, beside About / Diagnostics.
	var foot := HBoxContainer.new()
	foot.name = "Footer"
	foot.add_theme_constant_override("separation", 12)
	_right.add_child(foot)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	foot.add_child(info)
	_status = Label.new()
	_status.name = "ControllerStatus"
	_status.add_theme_font_size_override("font_size", 20)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_status)
	# How long this launch took (the full timeline is in Diagnostics on newer apps).
	_startup = Label.new()
	_startup.name = "StartupLine"
	_startup.add_theme_font_size_override("font_size", 17)
	_startup.add_theme_color_override("font_color", Color(0.85, 0.95, 0.92, 0.6))
	_startup.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_startup)
	# Version, build, OTA and source identities (and OTA recovery in dev builds).
	var about := UiStyle.button("About / Diagnostics", func(): Game.inst.diagnostics.open())
	about.name = "AboutDiagnostics"
	about.custom_minimum_size = Vector2(0, 64)
	about.add_theme_font_size_override("font_size", 24)
	about.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(about)
	_session_rows = [restart, title, _run_time, _run_detail, _loadout, looks, _treasure, _replay]
	# His colours: a page of its own in place of the menu.
	gill_page = GillPage.new()
	gill_page.visible = false
	_root.add_child(gill_page)
	gill_page.done.connect(_close_gill)
	skill_page = SkillTreePage.new()
	skill_page.visible = false
	_root.add_child(skill_page)
	skill_page.done.connect(_close_skills)
	guide_page = FieldGuidePage.new()
	guide_page.visible = false
	_root.add_child(guide_page)
	guide_page.done.connect(_close_guide)
	resume.name = "Resume"
	visible = false
	get_viewport().size_changed.connect(_layout)
	_panel.minimum_size_changed.connect(_on_panel_min_changed)
	Settings.settings_changed.connect(_refresh)
	Settings.input_mode_changed.connect(func(_m): _refresh())


func _open_gill(direct := false) -> void:
	_gill_direct = direct
	_panel.visible = false
	gill_page.refresh()
	gill_page.visible = true
	(gill_page.find_child("Morph_" + Settings.gill_morph, true, false) as Button).grab_focus.call_deferred()


func _open_skills(direct := false) -> void:
	_skills_direct = direct
	_panel.visible = false
	skill_page.open()


func _close_skills() -> void:
	skill_page.visible = false
	_panel.visible = true
	Sfx.play("ui_tap", null, -8.0)
	if _skills_direct:
		_skills_direct = false
		close()
		return
	_refresh()
	(_panel.find_child("Skills", true, false) as Button).grab_focus.call_deferred()


func _open_guide() -> void:
	_panel.visible = false
	guide_page.open()


func _close_guide() -> void:
	guide_page.visible = false
	_panel.visible = true
	Sfx.play("ui_tap", null, -8.0)
	(_panel.find_child("FieldGuide", true, false) as Button).grab_focus.call_deferred()


func _close_gill() -> void:
	gill_page.visible = false
	_panel.visible = true
	if _gill_direct:
		# Straight back to the title screen.
		_gill_direct = false
		close()
		return
	(_panel.find_child("GillColours", true, false) as Button).grab_focus.call_deferred()


func _on_reduced(on: bool) -> void:
	Settings.reduced_hud = on
	Settings.save()


func _on_timer_toggle(on: bool) -> void:
	Settings.show_run_timer = on
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


func _slider(parent: Control, text: String) -> TouchSlider:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.custom_minimum_size = Vector2(84, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	var s := TouchSlider.new()
	s.name = text
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(160, 56)
	parent.add_child(s)
	return s


func _on_replay_tutorial() -> void:
	if Game.inst == null or Game.inst.onboarding == null:
		return
	Game.inst.onboarding.replay()
	_tutorials.set_pressed_no_signal(true)
	close()


func _on_tutorials(on: bool) -> void:
	Settings.tutorials = on
	Settings.save()
	if Game.inst != null and Game.inst.onboarding != null:
		Game.inst.onboarding.tutorials_changed(on)


## A left-column action: the column's width, 64 px tall.
func _action(text: String, cb: Callable) -> Button:
	var b := UiStyle.button(text, cb)
	b.custom_minimum_size = Vector2(LEFT_W, 64)
	b.name = text.replace(" ", "")
	_left.add_child(b)
	return b


## A toggle: 60 px tall, half the right column; a swipe across it never flips it.
func _toggle(parent: Control, text: String, cb: Callable) -> CheckButton:
	var c := UiStyle.pill_toggle(CheckButton.new())
	c.text = text
	c.custom_minimum_size = Vector2(0, 60)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.add_theme_font_size_override("font_size", 22)
	UiStyle.swipe_guard(c)
	c.toggled.connect(func(on: bool) -> void:
		if UiStyle.swiped(c):
			c.set_pressed_no_signal(not on)
			return
		cb.call(on))
	parent.add_child(c)
	return c


## Places the panel in the display's safe area.
func _layout() -> void:
	layout_in(UiStyle.safe_rect(_root.get_viewport(), Vector4(12, 12, 12, 12)))


## Lays the panel out in `area` (the safe area; tests use it to stand in for a phone's screen): up
## to PANEL_MAX_W wide, never wider than the area, as tall as its content, centred in the area.
## (Wrapped text only knows its height once its width is set, so a change in the panel's minimum
## size lays it out again in the same area.)
func layout_in(area: Rect2) -> void:
	_area = area
	var w := minf(maxf(_panel.get_combined_minimum_size().x, PANEL_MAX_W), area.size.x)
	_panel.size = Vector2(w, 0)
	_panel.size = Vector2(w, _panel.get_combined_minimum_size().y)
	_panel.position = (area.position + (area.size - _panel.size) * 0.5).floor()
	_panel.position.y = maxf(_panel.position.y, area.position.y)


var _area := Rect2()
var _relayout_queued := false


func _on_panel_min_changed() -> void:
	if _relayout_queued or _area.size == Vector2.ZERO:
		return
	_relayout_queued = true
	(func() -> void:
		_relayout_queued = false
		layout_in(_area)).call_deferred()


func _toggle_treasure() -> void:
	var tp: TreasurePlay = Game.inst.treasure
	close()
	if tp.hunting():
		tp.stop()
	else:
		tp.start()


func _open_aquarium() -> void:
	if gill_page.visible:
		_close_gill()
	if guide_page.visible:
		_close_guide()
	if skill_page.visible:
		_close_skills()
	visible = false
	get_tree().paused = false
	Sfx.play("ui_tap", null, -8.0)
	Game.inst.presentation.enter("play")


func open(from_title := false) -> void:
	_from_title = from_title
	(_panel.find_child("ReturnToTitle", true, false) as Button).text = "Save & Return to Title"
	if not from_title and Game.inst != null:
		Game.inst.save_run()
	for r in _session_rows:
		r.visible = not from_title
	_refresh()
	visible = true
	if not from_title:
		get_tree().paused = true
	(_panel.find_child("Resume", true, false) as Button).grab_focus.call_deferred()


func close() -> void:
	if gill_page.visible:
		_close_gill()
	if guide_page.visible:
		guide_page.visible = false
		_panel.visible = true
	if skill_page.visible:
		skill_page.visible = false
		_panel.visible = true
		_skills_direct = false
	visible = false
	get_tree().paused = false
	Sfx.play("ui_tap", null, -8.0)


func _refresh() -> void:
	_reduced.set_pressed_no_signal(Settings.reduced_hud)
	_timer_toggle.set_pressed_no_signal(Settings.show_run_timer)
	var g := Game.inst
	if g != null and g.run_save != null:
		_loadout.refresh()
		_loadout.visible = _loadout.visible and not _from_title
		# (Not mid-cinematic, mid-fall or while dead: only from ordinary play.)
		_aquarium.disabled = g.cinematic != "" or g.player.state != "normal"
		var tp: TreasurePlay = g.treasure
		_treasure.visible = not _from_title and tp != null and tp.eligible()
		if tp != null and _treasure.visible:
			_treasure.text = "Stop Treasure Hunt" if tp.hunting() else ("New Treasure Hunt" if TreasureHunt.is_complete(tp.st()) or not TreasureHunt.has_hunt(tp.st()) else "Resume Treasure Hunt")
			_treasure.disabled = g.cinematic != "" or g.player.state != "normal"
		_run_time.text = g.run_line()
		var lines: Array[String] = []
		lines.append("Game finished: " + ("yes" if g.clock.is_finished() else "not yet"))
		lines.append_array(g.completion.summary_lines(g.run_save.earned()))
		# (Permanent, separate from the run's completion: not in the catalog.)
		lines.append(g.progress_line())
		if g.best_line() != "":
			lines.append(g.best_line())
		# (Two columns: the first half of the lines on the left.)
		var half := int(ceil(lines.size() / 2.0))
		_run_detail.text = "[table=2][cell padding=0,0,24,0]%s[/cell][cell]%s[/cell][/table]" % ["\n".join(lines.slice(0, half)), "\n".join(lines.slice(half))]
		# This ball (cohesion audit P2): above the run-wide table, in play only (not from the title
		# or the aquarium, where there is no ball he is playing).
		_ball_line = ball_line()
		if _ball_line != "":
			_run_detail.text = "[color=#e6fff5]%s[/color]\n%s" % [_ball_line, _run_detail.text]
	if g != null and g.gill != null:
		_skills_button.text = "Skills  (%d to spend)" % g.gill.balance() if g.gill.balance() > 0 else "Skills"
	_haptics.set_pressed_no_signal(Settings.haptics)
	_swim_invert.set_pressed_no_signal(Settings.swim_invert_y)
	_tutorials.set_pressed_no_signal(Settings.tutorials)
	# (From the title it is Settings: back to the title, not "resume" a run that is not running.)
	_resume.text = "Back" if _from_title else "Resume"
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_status.text = Settings.controller_status()
	_startup.text = StartupTrace.summary()
	_layout.call_deferred()


## The current ball's line in the run panel (BallView.progress_line), or "" outside a run's play.
func ball_line() -> String:
	var g := Game.inst
	if _from_title or g == null or g.state != "play" or g.player == null or g.player.ball == null:
		return ""
	return BallView.progress_line(g.player.ball, g.vortices)


func _unhandled_input(event: InputEvent) -> void:
	if visible and skill_page.visible:
		return
	if visible and guide_page.visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		_close_guide()
		get_viewport().set_input_as_handled()
		return
	if visible and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()

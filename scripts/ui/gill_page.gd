class_name GillPage
extends Control
## The colours page (owner request after the dev-000024 playtest), opened from the pause menu and
## the title: real axolotl morphs as swatches, fine-tuning sliders for his body and his freckles,
## patterns. Saved per device (Settings, GillLook).
## A landscape workspace (owner, 2026-09-30): the controls on the left and Gill on the right, large,
## always in view, recolouring live. A finger on him turns him round (front, sides, back).
## Nothing scrolls (phone audit 2026-09-30 §A, owner ruling): every control fits the 720-px design
## height on any landscape phone, cut-out included. Sliders take hold only on their thumb or track
## (TouchSlider) and a swipe across the swatches never picks one (UiStyle.swipe_guard).

signal done

var preview: AxolotlModel
var _swatches := {}
var _body_hue: TouchSlider
var _body_bright: TouchSlider
var _dots_hue: TouchSlider
var _dots_bright: TouchSlider
var _turn: Node3D
var _vp: SubViewport
var _patterns := {}
var _full_colour: CheckButton
var _pattern_size: TouchSlider
var _pattern_note: Label
var _file_dialog: FileDialog
## The controls' panel and the stage he stands on (laid out side by side).
var controls: PanelContainer
var stage: SubViewportContainer
## The controls' column inside the panel.
var column: VBoxContainer
## The swatch and pattern cells' heights: roomy, and a compact size for a short safe area.
const SWATCH_H := [62.0, 58.0]
const PATTERN_H := [70.0, 64.0]
## His turn about his middle (radians), its spin from a flick, and whether he has been touched yet.
var yaw := PI * 0.8
var _yaw_v := 0.0
var _dragging := -2
var _touched := false


func _ready() -> void:
	name = "GillPage"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	stage = _preview()
	add_child(stage)
	controls = PanelContainer.new()
	controls.name = "Controls"
	# (Solid enough that nothing behind it shows through the controls.)
	var box := UiStyle._box(Color(UiStyle.PANEL, 0.97), Color(UiStyle.MINT, 0.35))
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	controls.add_theme_stylebox_override("panel", box)
	controls.clip_contents = true
	add_child(controls)
	var v := VBoxContainer.new()
	v.name = "Column"
	v.add_theme_constant_override("separation", 8)
	column = v
	controls.add_child(v)
	# Header: the page's name, Reset and Done.
	var head := HBoxContainer.new()
	head.name = "Header"
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title := Label.new()
	title.text = "%s's colours" % GameVersion.CHARACTER_NAME
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var reset := UiStyle.button("Reset", func() -> void: _pick(Settings.gill_morph))
	reset.name = "Reset"
	reset.custom_minimum_size = Vector2(130, 60)
	reset.add_theme_font_size_override("font_size", 26)
	head.add_child(reset)
	var back := UiStyle.button("Done", func() -> void: done.emit())
	back.name = "Done"
	back.custom_minimum_size = Vector2(130, 60)
	back.add_theme_font_size_override("font_size", 26)
	head.add_child(back)
	# Real morphs as swatches.
	v.add_child(_heading("Colour"))
	var grid := _cells("Morphs")
	v.add_child(grid)
	for m in GillLook.MORPHS:
		var b := Button.new()
		b.name = "Morph_" + m["id"]
		b.text = m["name"]
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		b.add_theme_constant_override("outline_size", 6)
		b.focus_mode = Control.FOCUS_ALL
		var id: String = m["id"]
		b.pressed.connect(func() -> void:
			if not UiStyle.swiped(b):
				_pick(id))
		_cell(grid, b)
		_swatches[id] = b
	# Fine-tuning: his body and his freckles, each a colour and a shade, side by side.
	var tune := GridContainer.new()
	tune.name = "FineTune"
	tune.columns = 3
	tune.add_theme_constant_override("h_separation", 10)
	tune.add_theme_constant_override("v_separation", 8)
	v.add_child(tune)
	for h in ["Fine-tune", "Colour", "Shade"]:
		var l := UiStyle.note(h, 18)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		if h != "Fine-tune":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tune.add_child(l)
	tune.add_child(_row_label("Body"))
	_body_hue = _slider(tune, "Body colour", -0.5, 0.5)
	_body_bright = _slider(tune, "Body shade", 0.6, 1.4)
	tune.add_child(_row_label("Freckles"))
	_dots_hue = _slider(tune, "Freckle colour", -0.5, 0.5)
	_dots_bright = _slider(tune, "Freckle shade", 0.4, 1.6)
	for s in [_body_hue, _body_bright, _dots_hue, _dots_bright]:
		s.value_changed.connect(func(_x: float) -> void: _tuned())
	# Patterns: built-in ones, the player's own picture ("Mine", once there is one) and Upload.
	v.add_child(_heading("Pattern"))
	var pgrid := _cells("Patterns")
	v.add_child(pgrid)
	for pat in GillLook.PATTERNS + [[GillLook.UPLOAD, "Mine"]]:
		var b := Button.new()
		var id: String = pat[0]
		b.name = "Pattern_" + id
		b.text = pat[1]
		b.add_theme_font_size_override("font_size", 18)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func() -> void:
			if not UiStyle.swiped(b):
				_pick_pattern(id))
		_cell(pgrid, b)
		_patterns[id] = b
	var upload := UiStyle.button("Upload…", Callable())
	upload.name = "Upload"
	upload.add_theme_font_size_override("font_size", 20)
	upload.pressed.connect(func() -> void:
		if not UiStyle.swiped(upload):
			_upload())
	_cell(pgrid, upload)
	# Markings or full colour, and how many times it repeats round him.
	var last := HBoxContainer.new()
	last.name = "PatternRow"
	last.add_theme_constant_override("separation", 10)
	v.add_child(last)
	_full_colour = CheckButton.new()
	_full_colour.name = "FullColour"
	_full_colour.text = "Full colour"
	_full_colour.tooltip_text = "Off: the markings take the freckle colour"
	_full_colour.custom_minimum_size = Vector2(200, 58)
	_full_colour.add_theme_font_size_override("font_size", 22)
	UiStyle.swipe_guard(_full_colour)
	_full_colour.toggled.connect(func(on: bool) -> void:
		if UiStyle.swiped(_full_colour):
			_full_colour.set_pressed_no_signal(not on)
			return
		_pattern_tuned())
	last.add_child(_full_colour)
	last.add_child(_row_label("Repeats"))
	# (How many times it repeats round his body: left, a few big; right, many small.)
	_pattern_size = _slider(last, "Pattern repeats", 1.0, 8.0)
	_pattern_size.step = 1.0
	_pattern_size.value_changed.connect(func(_x: float) -> void: _pattern_tuned())
	# What became of an uploaded picture: a caption over his stage, not a row in the column.
	_pattern_note = UiStyle.note("", 20)
	_pattern_note.name = "PatternNote"
	_pattern_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pattern_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pattern_note)
	get_viewport().size_changed.connect(_layout)
	_layout()
	# The preview costs nothing while the page is closed.
	visibility_changed.connect(_on_visibility)
	_on_visibility()
	refresh()


func _on_visibility() -> void:
	var on := is_visible_in_tree()
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	preview.set_process(on)
	if on:
		_style_patterns()
		_layout.call_deferred()


## Controls on the left, his stage filling the rest, inside the display's safe area.
func _layout() -> void:
	layout_in(UiStyle.safe_rect(get_viewport(), Vector4(16, 14, 16, 14)))


## Lays the page out in `area` (the safe area; tests use it to stand in for a phone's screen). The
## column is 46 % of the width (590..640 px); if the area is too short for the roomy swatches, they
## step down to the compact size. Nothing scrolls either way.
func layout_in(area: Rect2) -> void:
	var w := clampf(area.size.x * 0.46, 590.0, 640.0)
	for compact in [0, 1]:
		_size_cells(compact)
		if controls.get_combined_minimum_size().y <= area.size.y:
			break
	controls.position = area.position
	controls.size = Vector2(w, area.size.y)
	stage.position = Vector2(area.position.x + w + 14, area.position.y)
	stage.size = Vector2(area.end.x - stage.position.x, area.size.y)
	_pattern_note.position = stage.position + Vector2(16, stage.size.y - 64)
	_pattern_note.size = Vector2(stage.size.x - 32, 52)
	# (A narrow stage steps the camera back so all of him fits side on.)
	var aspect := stage.size.x / maxf(stage.size.y, 1.0)
	var dist := 3.1 * maxf(1.0, 1.2 / maxf(aspect, 0.3))
	var cam: Camera3D = _vp.get_node("Cam")
	cam.look_at_from_position(Vector3(0.0, 0.2, 0.0) + Vector3(0.0, 0.85, 2.9).normalized() * dist, Vector3(0.0, 0.2, 0.0))


## The swatch and pattern cells at the roomy (0) or compact (1) height.
func _size_cells(compact: int) -> void:
	for b in _swatches.values():
		(b as Control).custom_minimum_size = Vector2(0, SWATCH_H[compact])
	for b in controls.find_child("Patterns", true, false).get_children():
		(b as Control).custom_minimum_size = Vector2(0, PATTERN_H[compact])


func _heading(text: String) -> Label:
	var l := UiStyle.note(text, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_color", Color(UiStyle.MINT, 0.9))
	return l


func _row_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.custom_minimum_size = Vector2(96, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## A 4-wide grid of swatch cells sharing the column's width evenly.
func _cells(grid_name: String) -> GridContainer:
	var g := GridContainer.new()
	g.name = grid_name
	g.columns = 4
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	return g


func _cell(grid: GridContainer, b: Button) -> void:
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, SWATCH_H[0])
	b.clip_text = true
	UiStyle.swipe_guard(b)
	grid.add_child(b)


## His stage: neutral studio light (the colour you pick is the colour you see, without the
## aquarium's tint or haze), a soft floor under him, and his idles. The model is his own, drawn with
## the same look as in the game.
func _preview() -> SubViewportContainer:
	var box := SubViewportContainer.new()
	box.name = "Preview"
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_stage_input)
	var vp := SubViewport.new()
	_vp = vp
	vp.own_world_3d = true
	vp.transparent_bg = false
	vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.1, 0.24, 0.26)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.92, 0.94, 0.96)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.55, 0.0)
	key.light_energy = 1.15
	vp.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(-0.35, -2.4, 0.0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.85, 0.93, 1.0)
	vp.add_child(fill)
	var floor := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.05
	disc.bottom_radius = 1.05
	disc.height = 0.02
	disc.radial_segments = 48
	floor.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.07, 0.18, 0.19)
	fm.roughness = 0.9
	floor.material_override = fm
	floor.position = Vector3(0, -0.01, 0)
	vp.add_child(floor)
	var cam := Camera3D.new()
	cam.name = "Cam"
	cam.fov = 30.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.05, 3.1), Vector3(0.0, 0.2, 0.0))
	_turn = Node3D.new()
	vp.add_child(_turn)
	preview = AxolotlModel.new()
	preview.idle_ok = true
	# (A colour preview turned on a stand: laid straight, no follow-through as it turns.)
	preview.follow = false
	# (Turned about his middle, not his nose.)
	preview.position = Vector3(0, 0, -0.36)
	_turn.add_child(preview)
	return box


## A finger (or the mouse) on his stage turns him; a flick keeps him turning briefly.
func _stage_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed and _dragging == -2:
			_dragging = t.index
			_touched = true
			_yaw_v = 0.0
		elif not t.pressed and t.index == _dragging:
			_dragging = -2
		accept_event()
	elif e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		if d.index == _dragging:
			turn_by(d.relative.x)
			_yaw_v = d.velocity.x * 0.006
		accept_event()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := e as InputEventMouseButton
		_dragging = -1 if mb.pressed else -2
		if mb.pressed:
			_touched = true
			_yaw_v = 0.0
		accept_event()
	elif e is InputEventMouseMotion and _dragging == -1:
		var mm := e as InputEventMouseMotion
		turn_by(mm.relative.x)
		_yaw_v = mm.velocity.x * 0.006
		accept_event()


## Turns him by a horizontal drag of `px` design pixels (a full drag across his stage is about a
## full turn).
func turn_by(px: float) -> void:
	_touched = true
	yaw = wrapf(yaw + px * 0.011, -PI, PI)


var _t := 0.0


func _process(dt: float) -> void:
	if not visible or _turn == null:
		return
	_t += dt
	if _dragging == -2:
		# The flick eases out (no endless spinning).
		yaw = wrapf(yaw + _yaw_v * dt, -PI, PI)
		_yaw_v *= exp(-dt * 5.0)
		if absf(_yaw_v) < 0.02:
			_yaw_v = 0.0
	# Untouched, a slow sway about a three-quarter view keeps his face toward you.
	_turn.rotation.y = yaw + (0.0 if _touched else sin(_t * 0.45) * 0.45)


func _slider(parent: Control, text: String, lo: float, hi: float) -> TouchSlider:
	var s := TouchSlider.new()
	s.name = text.replace(" ", "")
	s.tooltip_text = text
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(150, 56)
	parent.add_child(s)
	return s


## A morph from its swatch: its own colours (the fine-tuning goes back to neutral).
func _pick(id: String) -> void:
	Settings.set_gill_look(id, 0.0, 1.0, 0.0, 1.0)
	refresh()


func _tuned() -> void:
	Settings.set_gill_look(Settings.gill_morph, _body_hue.value, _body_bright.value, _dots_hue.value, _dots_bright.value)
	_style_swatches()


func _pick_pattern(id: String) -> void:
	if id == GillLook.UPLOAD and not GillLook.has_upload():
		_upload()
		return
	Settings.set_gill_pattern(id, Settings.gill_pattern_mode, Settings.gill_pattern_size)
	refresh()


func _pattern_tuned() -> void:
	Settings.set_gill_pattern(Settings.gill_pattern, 1 if _full_colour.button_pressed else 0, int(_pattern_size.value))
	_style_patterns()


## Picks a picture: the phone's own picker where there is one, Godot's file dialog otherwise.
func _upload() -> void:
	_pattern_note.text = ""
	var filters := PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Pictures"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Pick a picture for %s" % GameVersion.CHARACTER_NAME, "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters, _on_native_picked)
		return
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.filters = filters
		_file_dialog.use_native_dialog = false
		_file_dialog.file_selected.connect(import_picture)
		add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.8)


func _on_native_picked(status: bool, paths: PackedStringArray, _filter: int) -> void:
	if status and not paths.is_empty():
		import_picture(paths[0])


## Makes a picked picture his pattern (GillLook.import_pattern), or says why not.
func import_picture(path: String) -> void:
	var err := GillLook.import_pattern(path)
	if err != "":
		_pattern_note.text = err
		return
	_pattern_note.text = "Your picture is on %s." % GameVersion.CHARACTER_NAME
	Settings.set_gill_pattern(GillLook.UPLOAD, Settings.gill_pattern_mode, Settings.gill_pattern_size)
	refresh()


func refresh() -> void:
	_full_colour.set_pressed_no_signal(Settings.gill_pattern_mode == 1)
	_pattern_size.set_value_no_signal(Settings.gill_pattern_size)
	_style_patterns()
	_body_hue.set_value_no_signal(Settings.gill_body_hue)
	_body_bright.set_value_no_signal(Settings.gill_body_bright)
	_dots_hue.set_value_no_signal(Settings.gill_dots_hue)
	_dots_bright.set_value_no_signal(Settings.gill_dots_bright)
	_style_swatches()


## Each swatch shows its morph's body with a freckle-coloured rim; the chosen one is ringed white.
func _style_swatches() -> void:
	for id in _swatches:
		var m := GillLook.morph(id)
		var chosen: bool = id == Settings.gill_morph
		for state in ["normal", "hover", "pressed", "focus"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = m["base"]
			sb.border_color = Color.WHITE if chosen else m["freckle"]
			sb.set_border_width_all(7 if chosen else 5)
			sb.set_corner_radius_all(18)
			if state == "focus":
				sb.draw_center = false
				sb.border_color = Color(1, 1, 1, 0.6)
			(_swatches[id] as Button).add_theme_stylebox_override(state, sb)


## Each pattern swatch shows its pattern; the chosen one is ringed white. "Mine" appears once a
## picture has been uploaded.
func _style_patterns() -> void:
	# (The swatches' pictures only once the page is open: drawing them cost startup ~2 s.)
	var shown := is_visible_in_tree()
	for id in _patterns:
		var b := _patterns[id] as Button
		if shown:
			b.icon = GillLook.pattern_texture(id) if id != "none" else null
		if id == GillLook.UPLOAD:
			b.visible = GillLook.has_upload()
		var chosen: bool = id == Settings.gill_pattern
		for state in ["normal", "hover", "pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.93, 0.9, 0.86) if id != "none" else GillLook.morph(Settings.gill_morph)["base"]
			sb.border_color = Color.WHITE if chosen else Color(0.3, 0.4, 0.4)
			sb.set_border_width_all(7 if chosen else 3)
			sb.set_corner_radius_all(18)
			b.add_theme_stylebox_override(state, sb)
		b.add_theme_color_override("font_color", Color(0.1, 0.12, 0.12))

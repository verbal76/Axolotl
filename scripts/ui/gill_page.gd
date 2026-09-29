class_name GillPage
extends PanelContainer
## The colours page (owner request after the dev-000024 playtest), opened from the pause menu:
## real axolotl morphs as swatches, fine-tuning sliders for his body and his freckles, and a live
## close-up of him that recolours as you tap. Saved per device (Settings, GillLook).

signal done

var preview: AxolotlModel
var _swatches := {}
var _body_hue: HSlider
var _body_bright: HSlider
var _dots_hue: HSlider
var _dots_bright: HSlider
var _turn: Node3D
var _vp: SubViewport
var _patterns := {}
var _full_colour: CheckButton
var _pattern_size: HSlider
var _pattern_note: Label
var _file_dialog: FileDialog


func _ready() -> void:
	name = "GillPage"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(560, 560)
	add_child(scroll)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)
	var title := Label.new()
	title.text = "%s's colours" % GameVersion.CHARACTER_NAME
	title.add_theme_font_size_override("font_size", 30)
	v.add_child(title)
	v.add_child(_preview())
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for m in GillLook.MORPHS:
		var b := Button.new()
		b.name = "Morph_" + m["id"]
		b.text = m["name"]
		b.custom_minimum_size = Vector2(122, 84)
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		b.add_theme_constant_override("outline_size", 6)
		b.focus_mode = Control.FOCUS_ALL
		var id: String = m["id"]
		b.pressed.connect(func() -> void: _pick(id))
		grid.add_child(b)
		_swatches[id] = b
	v.add_child(UiStyle.note("Fine-tune", 22))
	_body_hue = _slider(v, "Body colour", -0.5, 0.5)
	_body_bright = _slider(v, "Body shade", 0.6, 1.4)
	_dots_hue = _slider(v, "Freckle colour", -0.5, 0.5)
	_dots_bright = _slider(v, "Freckle shade", 0.4, 1.6)
	for s in [_body_hue, _body_bright, _dots_hue, _dots_bright]:
		s.value_changed.connect(func(_x: float) -> void: _tuned())
	# Patterns: built-in ones, the player's own picture, as markings or in full colour.
	v.add_child(UiStyle.note("Pattern", 22))
	var pgrid := GridContainer.new()
	pgrid.columns = 4
	pgrid.add_theme_constant_override("h_separation", 10)
	pgrid.add_theme_constant_override("v_separation", 10)
	v.add_child(pgrid)
	for pat in GillLook.PATTERNS + [[GillLook.UPLOAD, "Mine"]]:
		var b := Button.new()
		var id: String = pat[0]
		b.name = "Pattern_" + id
		b.text = pat[1]
		b.custom_minimum_size = Vector2(122, 84)
		b.add_theme_font_size_override("font_size", 18)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func() -> void: _pick_pattern(id))
		pgrid.add_child(b)
		_patterns[id] = b
	var upload := UiStyle.button("Upload a picture…", _upload)
	upload.name = "Upload"
	v.add_child(upload)
	_pattern_note = UiStyle.note("", 20)
	_pattern_note.name = "PatternNote"
	v.add_child(_pattern_note)
	_full_colour = CheckButton.new()
	_full_colour.name = "FullColour"
	_full_colour.text = "Full colour (off: markings in the freckle colour)"
	_full_colour.toggled.connect(func(_on: bool) -> void: _pattern_tuned())
	v.add_child(_full_colour)
	# (How many times it repeats round his body: left, a few big; right, many small.)
	_pattern_size = _slider(v, "Pattern repeats", 1.0, 8.0)
	_pattern_size.step = 1.0
	_pattern_size.value_changed.connect(func(_x: float) -> void: _pattern_tuned())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var reset := UiStyle.button("Reset", func() -> void: _pick(Settings.gill_morph))
	reset.name = "Reset"
	reset.custom_minimum_size = Vector2(200, 64)
	row.add_child(reset)
	var back := UiStyle.button("Done", func() -> void: done.emit())
	back.name = "Done"
	back.custom_minimum_size = Vector2(200, 64)
	row.add_child(back)
	v.add_child(row)
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


## A small stage of his own: soft aquarium light, a slow sway, and his idles.
func _preview() -> Control:
	var box := SubViewportContainer.new()
	box.name = "Preview"
	box.stretch = true
	box.custom_minimum_size = Vector2(520, 230)
	var vp := SubViewport.new()
	_vp = vp
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.08, 0.26, 0.28)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# (Neutral light, so the colour you pick is the colour you see.)
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.environment.ambient_light_energy = 0.65
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.5, 0.0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 38.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 0.62, 2.0), Vector3(0.0, 0.2, 0.15))
	_turn = Node3D.new()
	vp.add_child(_turn)
	preview = AxolotlModel.new()
	preview.idle_ok = true
	_turn.add_child(preview)
	return box


var _t := 0.0


func _process(dt: float) -> void:
	# A slow sway about a three-quarter view, so his face is always toward you.
	if visible and _turn:
		_t += dt
		_turn.rotation.y = PI * 0.8 + sin(_t * 0.45) * 0.55


func _slider(parent: Control, text: String, lo: float, hi: float) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(190, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.name = text.replace(" ", "")
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(300, 48)
	row.add_child(s)
	parent.add_child(row)
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

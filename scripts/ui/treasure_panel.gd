class_name TreasurePanel
extends CanvasLayer
## The Treasure Hunt's small HUD (docs/TREASURE_HUNT.md): top left, under the run timer, only
## what the player needs — the hunt is on, the one object to find now (a little picture of it and
## its name) and how many of the fourteen are found. Never the list, never a world or a direction.
## Also the brief "found it" note, and after the fourteenth the finish card with New hunt / Later.

var tp: TreasurePlay
var _box: PanelContainer
var _icon_vp: SubViewport
var _icon_model: Node3D
var _icon_kind := ""
var _name: Label
var _count: Label
var _msg: Label
var _sub: Label
var _card: PanelContainer
var _card_title: Label
var _card_note: Label
var _msg_t := 0.0
var _s := 1.0


func _ready() -> void:
	layer = 11
	_box = PanelContainer.new()
	_box.name = "TreasureHunt"
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.12, 0.12, 0.55)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 10
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_box.add_theme_stylebox_override("panel", sb)
	add_child(_box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	var icon := SubViewportContainer.new()
	icon.custom_minimum_size = Vector2(64, 64)
	icon.stretch = true
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)
	_icon_vp = SubViewport.new()
	_icon_vp.own_world_3d = true
	_icon_vp.transparent_bg = true
	_icon_vp.size = Vector2i(96, 96)
	_icon_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	icon.add_child(_icon_vp)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.8, 0.6, 0.0)
	_icon_vp.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.environment.ambient_light_energy = 0.7
	_icon_vp.add_child(env)
	var cam := Camera3D.new()
	cam.name = "Cam"
	_icon_vp.add_child(cam)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var head := Label.new()
	head.text = "TREASURE HUNT"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	col.add_child(head)
	_name = Label.new()
	_name.name = "Target"
	_name.add_theme_font_size_override("font_size", 24)
	_name.add_theme_color_override("font_color", Color(0.95, 1.0, 0.97))
	col.add_child(_name)
	_count = Label.new()
	_count.name = "Count"
	_count.add_theme_font_size_override("font_size", 17)
	_count.add_theme_color_override("font_color", Color(0.85, 0.95, 0.92, 0.85))
	col.add_child(_count)
	# The centred note ("found it", "new hunt").
	_msg = _big_label(40)
	_msg.name = "TreasureMessage"
	_sub = _big_label(24)
	_sub.name = "TreasureSub"
	# The finish card.
	_card = PanelContainer.new()
	_card.name = "TreasureComplete"
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.03, 0.14, 0.13, 0.9)
	cs.set_corner_radius_all(22)
	cs.content_margin_left = 30
	cs.content_margin_right = 30
	cs.content_margin_top = 22
	cs.content_margin_bottom = 22
	_card.add_theme_stylebox_override("panel", cs)
	_card.visible = false
	_card.theme = UiStyle.theme()
	# (It pauses the game while it is up, so it must run when paused.)
	_card.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_card)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	_card.add_child(cv)
	_card_title = Label.new()
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_title.add_theme_font_size_override("font_size", 38)
	_card_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	cv.add_child(_card_title)
	_card_note = Label.new()
	_card_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_note.add_theme_font_size_override("font_size", 24)
	cv.add_child(_card_note)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 18)
	cv.add_child(buttons)
	var again := UiStyle.button("New hunt", func():
		_close_card()
		tp.start())
	again.name = "NewHunt"
	buttons.add_child(again)
	var later := UiStyle.button("Later", func():
		_close_card()
		tp.stop())
	later.name = "Later"
	buttons.add_child(later)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _close_card() -> void:
	_card.visible = false
	get_tree().paused = false


func card_open() -> bool:
	return _card.visible


func _big_label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.18, 0.7))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.modulate.a = 0.0
	add_child(l)
	return l


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var ml := 18.0
	var mt := 12.0
	if win.x > 0 and win.y > 0 and safe.size.x > 0:
		ml = maxf(ml, safe.position.x * vp.x / win.x)
		mt = maxf(mt, safe.position.y * vp.y / win.y)
	_s = clampf(vp.y / 720.0, 0.75, 1.4)
	# Top left, below the (optional) run timer; clear of the pause button and every control.
	_box.position = Vector2(ml + 6, mt + 40 * _s)
	_box.scale = Vector2.ONE * _s
	for l in [_msg, _sub]:
		l.size = Vector2(vp.x, 60)
		l.position = Vector2(0, vp.y * (0.2 if l == _msg else 0.2 + 0.075))
	_card.position = vp * 0.5 - _card.size * 0.5


func busy() -> bool:
	return _card.visible or _msg.modulate.a > 0.01


## The object to find now ({} hides the target line) and how many are found.
func set_target(t: Dictionary, found: int) -> void:
	_count.text = "%d / %d" % [found, TreasureHunt.COUNT]
	if t.is_empty():
		_name.text = "—"
		return
	_name.text = TreasureHunt.kind_name(t["kind"])
	if t["kind"] != _icon_kind:
		_set_icon(t["kind"])


func current_name() -> String:
	return _name.text


## The picture: its model, framed three-quarters, rendered once when the target changes.
func _set_icon(kind: String) -> void:
	_icon_kind = kind
	if _icon_model:
		_icon_model.queue_free()
	_icon_model = TreasureModels.node(kind, 1.0)
	_icon_vp.add_child(_icon_model)
	_icon_model.rotation.y = 0.65
	var sz := TreasureModels.size_of(kind)
	var h := TreasureModels.height_of(kind)
	var cam: Camera3D = _icon_vp.get_node("Cam")
	cam.fov = 34.0
	cam.look_at_from_position(Vector3(sz * 0.35, h * 0.5 + sz * 0.55, -sz * 1.75), Vector3(0, h * 0.42, 0))
	_icon_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


func show_message(title: String, sub: String) -> void:
	_flash(_msg, title, 2.2)
	if sub != "":
		_flash(_sub, sub, 3.2)


func show_found(kind_name: String, found: int, final: bool) -> void:
	_count.text = "%d / %d" % [found, TreasureHunt.COUNT]
	if not final:
		_flash(_msg, "Found the %s!" % kind_name.to_lower(), 1.8)
		_flash(_sub, "%d / %d" % [found, TreasureHunt.COUNT], 1.8)
	else:
		_flash(_msg, "Found the %s!" % kind_name.to_lower(), 2.4)


var _tweens := {}


func _flash(l: Label, text: String, hold: float) -> void:
	l.text = text
	# (A new note replaces the one still fading, rather than being faded out by it.)
	var old: Tween = _tweens.get(l)
	if old and old.is_valid():
		old.kill()
	var tw := create_tween()
	_tweens[l] = tw
	tw.tween_property(l, "modulate:a", 1.0, 0.25)
	tw.tween_interval(hold)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)


## After the fourteenth: the finish card. The first hunt's card says the next one is harder.
func show_complete(first: bool) -> void:
	_card_title.text = "TREASURE HUNT COMPLETE!"
	_card_note.text = "%d / %d found.%s" % [TreasureHunt.COUNT, TreasureHunt.COUNT, "\nNext time, the treasures are smaller." if first else ""]
	_card.visible = true
	_card.reset_size()
	_layout()
	# The world waits while the choice is made (touches go to the card, not the controls).
	get_tree().paused = true
	(_card.find_child("NewHunt", true, false) as Button).grab_focus.call_deferred()

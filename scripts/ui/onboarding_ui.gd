class_name OnboardingUi
extends CanvasLayer
## Onboarding's screens (docs/ONBOARDING.md), in Mote's visual language (UiStyle):
## - a card: the world dimmed behind a rounded shaded panel, a heading, one or two short lines and
##   ONE large button (the intro's "Begin", the lessons' "Got it"). The dim takes every touch, so
##   nothing reaches the game behind it. Sized to the safe area: landscape-safe, never scrolls.
## - during the interactive parts, only a small objective chip at the top ("EAT THE JELLYFISH")
##   and a soft ring round the target; neither takes input.

var _root: Control
var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _body: VBoxContainer
var _btn: Button
var _obj: PanelContainer
var _obj_label: Label
var _marker: Marker
var _kind := ""
var _cb := Callable()
## Seconds the current card has been up (bots wait a moment, as a player reads).
var shown_t := 0.0


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Onboarding"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiStyle.theme()
	add_child(_root)
	_marker = Marker.new()
	_marker.name = "TargetMarker"
	_marker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_marker)
	_obj = PanelContainer.new()
	_obj.name = "Objective"
	_obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip := StyleBoxFlat.new()
	chip.bg_color = Color(0.03, 0.13, 0.13, 0.72)
	chip.border_color = Color(UiStyle.MINT, 0.45)
	chip.set_border_width_all(2)
	chip.set_corner_radius_all(22)
	chip.content_margin_left = 22
	chip.content_margin_right = 22
	chip.content_margin_top = 6
	chip.content_margin_bottom = 6
	chip.anti_aliasing = true
	_obj.add_theme_stylebox_override("panel", chip)
	_obj_label = Label.new()
	_obj_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_obj_label.add_theme_color_override("font_color", UiStyle.GOLD)
	_obj_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj.add_child(_obj_label)
	_obj.visible = false
	_root.add_child(_obj)
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.color = Color(0.0, 0.04, 0.04, 0.58)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_root.add_child(_dim)
	_panel = PanelContainer.new()
	_panel.name = "Card"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.visible = false
	_root.add_child(_panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(col)
	_title = Label.new()
	_title.name = "Heading"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color", Color(0.99, 0.8, 0.85))
	_title.add_theme_color_override("font_outline_color", Color(0.04, 0.16, 0.15, 0.9))
	col.add_child(_title)
	_body = VBoxContainer.new()
	_body.name = "Body"
	col.add_child(_body)
	_btn = UiStyle.button("Got it", _on_button)
	_btn.name = "Action"
	UiStyle.make_primary(_btn)
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_btn)
	get_viewport().size_changed.connect(_layout)


func _process(dt: float) -> void:
	if _kind != "":
		shown_t += dt


# --- Cards -----------------------------------------------------------------------------------------

## Shows a card: heading, lines, one button. `intro` marks the intro screen (shown over the title).
func show_card(title: String, lines: Array, button: String, cb: Callable, intro := false) -> void:
	_kind = "intro" if intro else "card"
	_cb = cb
	shown_t = 0.0
	_title.text = title
	for c in _body.get_children():
		c.queue_free()
		_body.remove_child(c)
	for l in lines:
		var lab := Label.new()
		lab.text = str(l)
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_color_override("font_color", UiStyle.INK)
		_body.add_child(lab)
	_btn.text = button
	_dim.visible = true
	_panel.visible = true
	hide_objective()
	_layout()
	_btn.grab_focus.call_deferred()
	# (Autowrapped lines settle their height a frame later.)
	_layout.call_deferred()


func hide_card() -> void:
	_kind = ""
	_cb = Callable()
	_dim.visible = false
	_panel.visible = false
	if _btn.has_focus():
		_btn.release_focus()


## "" (none), "intro" or "card".
func card_kind() -> String:
	return _kind


func waiting_for_tap() -> bool:
	return _kind != "" and _panel.visible


## The card's one button pressed (bots and tests press it as a player taps it).
func tap() -> void:
	if waiting_for_tap():
		_btn.pressed.emit()


func _on_button() -> void:
	Sfx.play("ui_tap", null, -6.0)
	var cb := _cb
	if cb.is_valid():
		cb.call()


func button() -> Button:
	return _btn


func panel() -> PanelContainer:
	return _panel


# --- Objective and marker ----------------------------------------------------------------------------

func show_objective(text: String) -> void:
	_obj_label.text = text
	_obj.visible = true
	_layout()


func hide_objective() -> void:
	_obj.visible = false


func objective_text() -> String:
	return _obj_label.text if _obj.visible else ""


func objective_panel() -> PanelContainer:
	return _obj


func update_marker(world_pos: Vector3, color := UiStyle.DANGER) -> void:
	_marker.world_pos = world_pos
	_marker.color = color
	_marker.queue_redraw()


# --- Layout ------------------------------------------------------------------------------------------

func _layout() -> void:
	if _root == null:
		return
	var vp := _root.get_viewport_rect().size
	layout_in(UiStyle.safe_rect(get_viewport(), Vector4(24, 16, 24, 16)), clampf(vp.y / 720.0, 0.75, 1.5))


## Lays the chip and the card out inside `area` at scale `s` (tests try other screens with this).
func layout_in(area: Rect2, s: float) -> void:
	# Objective chip: top centre, small.
	_obj_label.add_theme_font_size_override("font_size", int(26 * s))
	_obj_label.add_theme_constant_override("outline_size", int(4 * s))
	_obj.reset_size()
	var om := _obj.get_combined_minimum_size()
	_obj.size = om
	_obj.position = Vector2(area.get_center().x - om.x * 0.5, area.position.y + 10 * s)
	# Card: centred in the safe area, as wide as reads comfortably, never taller than the area.
	var w := minf(area.size.x * 0.72, 900.0 * s)
	var big := _kind == "intro"
	_title.add_theme_font_size_override("font_size", int((54 if big else 46) * s))
	_title.add_theme_constant_override("outline_size", int(6 * s))
	(_title.get_parent() as VBoxContainer).add_theme_constant_override("separation", int(20 * s))
	_body.add_theme_constant_override("separation", int(12 * s))
	var inner := w - 68.0
	_title.custom_minimum_size = Vector2(inner, 0)
	for lab in _body.get_children():
		(lab as Label).add_theme_font_size_override("font_size", int(29 * s))
		(lab as Label).custom_minimum_size = Vector2(inner, 0)
	_btn.custom_minimum_size = Vector2(minf(380.0 * s, inner), 92.0 * s)
	_btn.add_theme_font_size_override("font_size", int(36 * s))
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.reset_size()
	var pm := _panel.get_combined_minimum_size()
	_panel.size = pm
	_panel.position = area.get_center() - pm * 0.5


## The soft ring round the objective's target (centred on it).
class Marker extends Control:
	var world_pos := Vector3.INF
	var color := UiStyle.DANGER    # owner, 2026-10-01: red for every objective (food and parasite)
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt
		if world_pos != Vector3.INF:
			queue_redraw()

	func _draw() -> void:
		var g := Game.inst
		if world_pos == Vector3.INF or g == null or g.cam == null or not g.cam.is_position_in_frustum(world_pos):
			return
		var c := g.cam.unproject_position(world_pos)
		var k := clampf(get_viewport_rect().size.y / 720.0, 0.75, 1.5)
		var d := maxf(1.0, g.cam.global_position.distance_to(world_pos))
		var r := clampf(260.0 / d, 26.0, 90.0) * k
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		draw_arc(c, r * (1.0 + pulse * 0.12), 0, TAU, 48, Color(color, 0.45 + 0.4 * pulse), 3.0 * k, true)
		draw_arc(c, r * 1.35, 0, TAU, 48, Color(color, 0.18 * (1.0 - pulse)), 2.0 * k, true)

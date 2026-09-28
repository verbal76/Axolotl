class_name Hud
extends CanvasLayer
## Minimal touch HUD: floating virtual stick (left), camera swipe (right side), three action
## buttons, pause button. Translucent first-use prompts. Health is on the axolotl, not here.

const BTN_JUMP := "jump"
const BTN_SWIPE := "swipe"
const BTN_LUNGE := "lunge"

var root: Control
var canvas: HudCanvas
var all_clear_label: Label
## The optional run timer (Pause → Show run timer): small and faint, top left, play only.
var timer_label: Label
## Under ALL CLEAR: the run's frozen finish time.
var finish_label: Label
## "New species" note at the top of the screen (Expansion 5's discoveries).
var discovery_label: Label

var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _stick_rest := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _cam_touches := {}          # index -> last position
var _btn_touch := {}            # index -> action
var _buttons := {}              # action -> {center, radius}
var _pause_rect := Rect2()
var _safe := Rect2()
var _alpha := 1.0
var _target_alpha := 1.0
var _cinematic := false
var _controls_visible := true
var prompts := {}               # name -> time shown
var _pressed := {}              # action -> glow timer


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	canvas = HudCanvas.new()
	canvas.hud = self
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(canvas)
	all_clear_label = Label.new()
	all_clear_label.text = "ALL CLEAR"
	all_clear_label.set_anchors_preset(Control.PRESET_CENTER)
	all_clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	all_clear_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	all_clear_label.add_theme_font_size_override("font_size", 64)
	all_clear_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.95))
	all_clear_label.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.18, 0.6))
	all_clear_label.add_theme_constant_override("outline_size", 6)
	all_clear_label.modulate.a = 0.0
	all_clear_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	all_clear_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(all_clear_label)
	finish_label = Label.new()
	finish_label.name = "FinishTime"
	finish_label.set_anchors_preset(Control.PRESET_CENTER)
	finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	finish_label.add_theme_font_size_override("font_size", 30)
	finish_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.95))
	finish_label.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.18, 0.6))
	finish_label.add_theme_constant_override("outline_size", 4)
	finish_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	finish_label.offset_top = 56
	finish_label.modulate.a = 0.0
	root.add_child(finish_label)
	discovery_label = Label.new()
	discovery_label.name = "Discovery"
	discovery_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	discovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discovery_label.add_theme_font_size_override("font_size", 28)
	discovery_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.92))
	discovery_label.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.18, 0.6))
	discovery_label.add_theme_constant_override("outline_size", 4)
	discovery_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	discovery_label.offset_top = 70
	discovery_label.modulate.a = 0.0
	root.add_child(discovery_label)
	timer_label = Label.new()
	timer_label.name = "RunTimer"
	timer_label.add_theme_font_size_override("font_size", 22)
	timer_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.96, 0.55))
	timer_label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.09, 0.5))
	timer_label.add_theme_constant_override("outline_size", 3)
	timer_label.visible = false
	root.add_child(timer_label)
	get_viewport().size_changed.connect(_layout)
	Settings.input_mode_changed.connect(func(_m): _update_alpha())
	Settings.settings_changed.connect(_update_alpha)
	_layout()
	_update_alpha()


func _layout() -> void:
	var vp := root.get_viewport_rect().size
	# Respect notches, camera islands, rounded corners and gesture areas.
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var margin_l := 0.0
	var margin_r := 0.0
	var margin_t := 0.0
	var margin_b := 0.0
	if win.x > 0 and win.y > 0 and safe.size.x > 0:
		var sx := vp.x / win.x
		var sy := vp.y / win.y
		margin_l = safe.position.x * sx
		margin_t = safe.position.y * sy
		margin_r = (win.x - safe.end.x) * sx
		margin_b = (win.y - safe.end.y) * sy
	# Extra breathing room for rounded corners / gesture bars.
	margin_l = maxf(margin_l, 18.0)
	margin_r = maxf(margin_r, 18.0)
	margin_b = maxf(margin_b, 16.0)
	margin_t = maxf(margin_t, 12.0)
	_safe = Rect2(margin_l, margin_t, vp.x - margin_l - margin_r, vp.y - margin_t - margin_b)
	var s := clampf(vp.y / 720.0, 0.75, 1.4)
	var jump_c := Vector2(_safe.end.x - 105 * s, _safe.end.y - 105 * s)
	_buttons = {
		BTN_JUMP: {"c": jump_c, "r": 64.0 * s},
		BTN_SWIPE: {"c": jump_c + Vector2(-150, 18) * s, "r": 48.0 * s},
		BTN_LUNGE: {"c": jump_c + Vector2(-32, -145) * s, "r": 48.0 * s},
	}
	_stick_rest = Vector2(_safe.position.x + 165 * s, _safe.end.y - 150 * s)
	if _stick_touch < 0:
		_stick_origin = _stick_rest
	_pause_rect = Rect2(Vector2(_safe.end.x - 64 * s, _safe.position.y + 6), Vector2(56, 56) * s)
	if timer_label:
		timer_label.position = _safe.position + Vector2(6, 4)
	canvas.scale_k = s
	canvas.queue_redraw()


func stick_radius() -> float:
	return 90.0 * canvas.scale_k


func visible_controls(v: bool) -> void:
	_controls_visible = v
	_update_alpha()


func set_cinematic(v: bool) -> void:
	_cinematic = v
	_update_alpha()
	if v:
		_release_all()


func _update_alpha() -> void:
	if not _controls_visible or _cinematic:
		_target_alpha = 0.0
	elif Settings.input_mode == Settings.InputMode.PAD:
		_target_alpha = 0.0
	elif Settings.reduced_hud:
		_target_alpha = 0.12
	else:
		_target_alpha = 1.0


func alpha() -> float:
	return _alpha


## Prompts belong to play: never on the title or when the controls are hidden.
func prompts_shown() -> bool:
	return _controls_visible


func _process(dt: float) -> void:
	_update_timer()
	_alpha = move_toward(_alpha, _target_alpha, dt * 3.0)
	for k in _pressed.keys():
		_pressed[k] = maxf(0.0, _pressed[k] - dt)
	canvas.queue_redraw()


# --- Touch input -------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if not _controls_visible or get_tree().paused:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_touch_down(e.index, e.position)
		else:
			_touch_up(e.index)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		_touch_move(e.index, e.position, e.relative)


func _touch_down(idx: int, pos: Vector2) -> void:
	Settings._set_mode(Settings.InputMode.TOUCH)
	if _cinematic:
		return
	if _pause_rect.grow(10).has_point(pos):
		Game.inst.pause_menu.open()
		get_viewport().set_input_as_handled()
		return
	for action in _buttons:
		var b: Dictionary = _buttons[action]
		if pos.distance_to(b["c"]) <= b["r"] * 1.25:
			_btn_touch[idx] = action
			Input.action_press(action)
			_pressed[action] = 0.25
			get_viewport().set_input_as_handled()
			return
	var vp := root.get_viewport_rect().size
	if pos.x < vp.x * 0.45 and _stick_touch < 0:
		_stick_touch = idx
		# Floating stick: centres where the thumb lands (kept inside the safe area).
		var r := stick_radius()
		_stick_origin = Vector2(clampf(pos.x, _safe.position.x + r, vp.x * 0.45), clampf(pos.y, _safe.position.y + r, _safe.end.y - r))
		_stick_vec = Vector2.ZERO
		get_viewport().set_input_as_handled()
		return
	_cam_touches[idx] = pos
	get_viewport().set_input_as_handled()


func _touch_move(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == _stick_touch:
		var v := (pos - _stick_origin) / stick_radius()
		_stick_vec = v.limit_length(1.0)
		_apply_stick()
	elif _cam_touches.has(idx):
		Game.inst.cam.swipe_delta += rel * (720.0 / maxf(1.0, root.get_viewport_rect().size.y)) * 1.6
		_cam_touches[idx] = pos
		if rel.length() > 2.0:
			Game.inst.notify_action("camera")


func _touch_up(idx: int) -> void:
	if idx == _stick_touch:
		_stick_touch = -1
		_stick_vec = Vector2.ZERO
		_stick_origin = _stick_rest
		_apply_stick()
	if _btn_touch.has(idx):
		Input.action_release(_btn_touch[idx])
		_btn_touch.erase(idx)
	_cam_touches.erase(idx)


func _apply_stick() -> void:
	var v := _stick_vec
	# Small dead zone, then full analog range.
	if v.length() < 0.12:
		v = Vector2.ZERO
	_set_axis("move_right", maxf(0.0, v.x))
	_set_axis("move_left", maxf(0.0, -v.x))
	_set_axis("move_back", maxf(0.0, v.y))
	_set_axis("move_forward", maxf(0.0, -v.y))


func _set_axis(action: String, s: float) -> void:
	if s > 0.0:
		Input.action_press(action, s)
	else:
		Input.action_release(action)


func _release_all() -> void:
	for idx in _btn_touch:
		Input.action_release(_btn_touch[idx])
	_btn_touch.clear()
	_stick_touch = -1
	_stick_vec = Vector2.ZERO
	_stick_origin = _stick_rest
	_apply_stick()
	_cam_touches.clear()


# --- Prompts / messages ------------------------------------------------------------------

func show_prompt(name_: String) -> void:
	prompts[name_] = 0.0


func hide_prompt(name_: String) -> void:
	prompts.erase(name_)


func show_all_clear(finish_text := "") -> void:
	finish_label.text = finish_text
	for l in [all_clear_label, finish_label]:
		var tw := create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 2.5)
		tw.tween_interval(3.5 if l == all_clear_label else 5.5)
		tw.tween_property(l, "modulate:a", 0.0, 3.0)


## A short note that a new species was discovered ("New species: Canopy snail").
func show_discovery(text: String) -> void:
	discovery_label.text = text
	var tw := create_tween()
	tw.tween_property(discovery_label, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.6)
	tw.tween_property(discovery_label, "modulate:a", 0.0, 1.2)


func _update_timer() -> void:
	var g := Game.inst
	var on := Settings.show_run_timer and g != null and g.clock != null and g.state == "play" and _controls_visible
	timer_label.visible = on
	if on:
		timer_label.text = RunClock.format(g.clock.shown_s()) + ("  finished" if g.clock.is_finished() else "")


func button_info() -> Dictionary:
	return _buttons


func stick_info() -> Array:
	return [_stick_origin, _stick_vec, _stick_touch >= 0]


func pause_rect() -> Rect2:
	return _pause_rect


func pressed_glow(action: String) -> float:
	return _pressed.get(action, 0.0) + (0.6 if Input.is_action_pressed(action) else 0.0)


class HudCanvas extends Control:
	var hud: Hud
	var scale_k := 1.0
	var _t := 0.0

	func _process(dt: float) -> void:
		_t += dt

	func _draw() -> void:
		var a := hud.alpha()
		var pa := 1.0 if Settings.input_mode == Settings.InputMode.TOUCH else 0.0
		# Pause button stays subtly visible (also in PAD mode, very faint).
		var pr := hud.pause_rect()
		var pc := pr.get_center()
		var pause_a := maxf(a, 0.25) if not hud._cinematic and hud._controls_visible else 0.0
		draw_circle(pc, pr.size.x * 0.45, Color(0, 0, 0, 0.18 * pause_a))
		draw_rect(Rect2(pc + Vector2(-9, -11) * scale_k, Vector2(6, 22) * scale_k), Color(1, 1, 1, 0.7 * pause_a))
		draw_rect(Rect2(pc + Vector2(3, -11) * scale_k, Vector2(6, 22) * scale_k), Color(1, 1, 1, 0.7 * pause_a))
		if a > 0.001:
			_draw_stick(a)
			for action in hud.button_info():
				_draw_button(action, a)
		if hud.prompts_shown():
			_draw_prompts(pa)

	func _draw_stick(a: float) -> void:
		var info := hud.stick_info()
		var o: Vector2 = info[0]
		var v: Vector2 = info[1]
		var active: bool = info[2]
		var r := hud.stick_radius()
		var base_a := (0.22 if active else 0.12) * a
		draw_circle(o, r, Color(0.8, 1.0, 0.95, base_a * 0.5))
		draw_arc(o, r, 0, TAU, 48, Color(0.85, 1.0, 0.95, base_a * 2.2), 2.0 * scale_k, true)
		draw_circle(o + v * r, r * 0.42, Color(0.9, 1.0, 0.97, (0.45 if active else 0.28) * a))

	func _draw_button(action: String, a: float) -> void:
		var b: Dictionary = hud.button_info()[action]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var glow := clampf(hud.pressed_glow(action), 0.0, 1.0)
		draw_circle(c, r, Color(0.75, 1.0, 0.95, (0.14 + glow * 0.25) * a))
		draw_arc(c, r, 0, TAU, 48, Color(0.9, 1.0, 0.97, (0.45 + glow * 0.5) * a), 2.5 * scale_k, true)
		var ic := Color(1, 1, 1, (0.7 + glow * 0.3) * a)
		var s := r * 0.42
		match action:
			"jump":
				# Upward push with a little bubble.
				draw_polyline(PackedVector2Array([c + Vector2(-s, s * 0.4), c + Vector2(0, -s * 0.6), c + Vector2(s, s * 0.4)]), ic, 4.0 * scale_k, true)
				draw_arc(c + Vector2(0, s * 0.75), s * 0.22, 0, TAU, 16, ic, 2.0 * scale_k, true)
			"swipe":
				# Tail sweep arc.
				draw_arc(c, s * 0.9, PI * 0.15, PI * 1.05, 20, ic, 4.0 * scale_k, true)
				draw_polyline(PackedVector2Array([c + Vector2(-s * 1.05, 0), c + Vector2(-s * 0.8, s * 0.45), c + Vector2(-s * 0.45, s * 0.1)]), ic, 3.0 * scale_k, true)
			"lunge":
				# Forward chevrons (a quick dart forward).
				for k in 2:
					var o := Vector2(0, -s * 0.35 + k * s * 0.6)
					draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.7, s * 0.3), c + o + Vector2(0, -s * 0.3), c + o + Vector2(s * 0.7, s * 0.3)]), ic, 3.5 * scale_k, true)

	func _draw_prompts(pa: float) -> void:
		for p in hud.prompts:
			var pulse := 0.5 + 0.5 * sin(_t * 4.0)
			var col := Color(0.6, 1.0, 0.9, (0.25 + 0.45 * pulse))
			match p:
				"move":
					var info := hud.stick_info()
					var o: Vector2 = info[0]
					var r := hud.stick_radius()
					if pa > 0.0:
						var dot := o + Vector2(sin(_t * 1.6), -absf(cos(_t * 1.6))) * r * 0.6
						draw_circle(dot, r * 0.22, Color(1, 1, 1, 0.35 + 0.3 * pulse))
						draw_arc(o, r * (1.1 + pulse * 0.1), 0, TAU, 48, col, 3.0 * scale_k, true)
					else:
						_pad_glyph(o, "L", col)
				"jump", "swipe", "lunge":
					var b: Dictionary = hud.button_info()[p]
					_ring(b["c"], b["r"], pulse, col, pa, {"jump": "A", "swipe": "X", "lunge": "B"}[p])
				"burst":
					# Double pulse on the jump button: press again while airborne.
					var b: Dictionary = hud.button_info()["jump"]
					var k := fmod(_t * 1.6, 1.0)
					var k2 := fmod(_t * 1.6 + 0.3, 1.0)
					var c: Vector2 = b["c"]
					var r: float = b["r"]
					if pa > 0.0:
						draw_arc(c, r * (1.0 + k * 0.6), 0, TAU, 48, Color(0.6, 1.0, 0.9, 0.7 * (1.0 - k)), 3.0 * scale_k, true)
						draw_arc(c, r * (1.0 + k2 * 0.6), 0, TAU, 48, Color(0.6, 1.0, 0.9, 0.7 * (1.0 - k2)), 3.0 * scale_k, true)
					else:
						_pad_glyph(c, "A A", col)
				"camera":
					var vp := get_viewport_rect().size
					var c := Vector2(vp.x * 0.68, vp.y * 0.42)
					if pa > 0.0:
						var x := sin(_t * 1.8) * 60.0 * scale_k
						draw_circle(c + Vector2(x, 0), 16.0 * scale_k, Color(1, 1, 1, 0.3 + 0.25 * pulse))
						draw_line(c + Vector2(-70, 0) * scale_k, c + Vector2(70, 0) * scale_k, Color(1, 1, 1, 0.18), 2.0 * scale_k, true)
					else:
						_pad_glyph(c, "R", col)

	func _ring(c: Vector2, r: float, pulse: float, col: Color, pa: float, glyph: String) -> void:
		if pa > 0.0:
			draw_arc(c, r * (1.12 + pulse * 0.18), 0, TAU, 48, col, 3.5 * scale_k, true)
		else:
			_pad_glyph(c, glyph, col)

	func _pad_glyph(c: Vector2, g: String, col: Color) -> void:
		# Controller mode: a small translucent button glyph near the bottom-right.
		var vp := get_viewport_rect().size
		var pos := Vector2(vp.x - 120 * scale_k, vp.y - 70 * scale_k)
		draw_circle(pos, 26 * scale_k, Color(0, 0, 0, 0.25))
		draw_string(get_theme_default_font(), pos + Vector2(-9, 9) * scale_k * (1.0 if g.length() == 1 else 1.9), g, HORIZONTAL_ALIGNMENT_CENTER, -1, int(26 * scale_k), col)

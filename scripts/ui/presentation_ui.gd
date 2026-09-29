class_name PresentationUi
extends CanvasLayer
## The controls of the aquarium experiences (docs/AQUARIUM.md), kept to a minimum:
## - everywhere: Back (top left; Android back and Esc do the same);
## - room: "Live Tank" and "Swim" (bottom right), and a hint that tapping the tank looks closer;
## - inspection: drag to look round the front of the tank;
## - Live Tank: nothing on screen until the screen is touched (then Back and View, which fade again);
## - Swim: a stick on the left that steers where the camera looks, drag on the right to look
##   round, and Up, Down and Faster (held) on the right.
## Touch targets are phone-sized and inside the display's safe area.

var p: Presentation
var mode := ""
var swim_stick := Vector2.ZERO
var swim_up := 0.0
var swim_fast := false
var swim_look := Vector2.ZERO

var _root: Control
var _canvas: UiCanvas
var _hint: Label
var _back: Button
var _live_btn: Button
var _swim_btn: Button
var _view_btn: Button
var _stick_touch := -1
var _stick_origin := Vector2.ZERO
var _look_touches := {}
var _btn_touch := {}
var _drag_touch := -1
var _drag_last := Vector2.ZERO
var _tap_start := {}
var _live_show := 0.0
var _safe := Rect2()
var _s := 1.0
var _buttons := {}    # swim: name -> [centre, radius]


func _ready() -> void:
	layer = 22
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_canvas = UiCanvas.new()
	_canvas.ui = self
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_canvas)
	_back = UiStyle.button("‹  Back", func(): p.back())
	_back.name = "AquariumBack"
	_root.add_child(_back)
	_live_btn = UiStyle.button("Live Tank", func(): p.go("live"))
	_live_btn.name = "LiveTank"
	_root.add_child(_live_btn)
	_swim_btn = UiStyle.button("Swim", func(): p.go("swim"))
	_swim_btn.name = "SwimMode"
	_root.add_child(_swim_btn)
	_view_btn = UiStyle.button("View", func():
		p.next_live_view()
		_live_show = 3.0)
	_view_btn.name = "LiveView"
	_root.add_child(_view_btn)
	_hint = UiStyle.note()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var vp := _root.get_viewport_rect().size
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	var ml := 18.0
	var mr := 18.0
	var mt := 12.0
	var mb := 16.0
	if win.x > 0 and win.y > 0 and safe.size.x > 0:
		ml = maxf(ml, safe.position.x * vp.x / win.x)
		mr = maxf(mr, (win.x - safe.end.x) * vp.x / win.x)
		mt = maxf(mt, safe.position.y * vp.y / win.y)
		mb = maxf(mb, (win.y - safe.end.y) * vp.y / win.y)
	_safe = Rect2(ml, mt, vp.x - ml - mr, vp.y - mt - mb)
	_s = clampf(vp.y / 720.0, 0.75, 1.4)
	_back.position = _safe.position + Vector2(6, 6)
	_back.size = Vector2(170, 64) * _s
	_live_btn.size = Vector2(210, 72) * _s
	_swim_btn.size = Vector2(170, 72) * _s
	_swim_btn.position = _safe.end - _swim_btn.size - Vector2(6, 6)
	_live_btn.position = _swim_btn.position - Vector2(_live_btn.size.x + 16, 0)
	_view_btn.size = Vector2(150, 64) * _s
	_view_btn.position = Vector2(_safe.end.x - _view_btn.size.x - 6, _safe.position.y + 6)
	# (Above the bottom row of buttons, never under them.)
	_hint.position = Vector2(_safe.position.x, _swim_btn.position.y - 52 * _s)
	_hint.size = Vector2(_safe.size.x, 40)
	var jump_c := Vector2(_safe.end.x - 105 * _s, _safe.end.y - 105 * _s)
	_buttons = {"fast": [jump_c, 64.0 * _s], "up": [jump_c + Vector2(-150, -40) * _s, 48.0 * _s], "down": [jump_c + Vector2(-150, 80) * _s, 44.0 * _s]}


func set_mode(m: String) -> void:
	mode = m
	_live_btn.visible = m == "room"
	_swim_btn.visible = m == "room"
	_view_btn.visible = m == "live"
	_live_show = 3.0
	match m:
		"room":
			_hint.text = "Tap the aquarium to look closer"
		"inspect":
			_hint.text = "Drag to look around the tank"
		"live":
			_hint.text = ""
		"swim":
			_hint.text = "Steer with the stick · drag right to look · Up, Down, Faster"
	_release()
	_hint.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(_hint, "modulate:a", 0.0 if m != "room" else 0.75, 1.5)


func _process(dt: float) -> void:
	if not visible:
		return
	if mode == "live":
		_live_show = maxf(0.0, _live_show - dt)
		var a := clampf(_live_show, 0.0, 1.0)
		_back.modulate.a = a
		_view_btn.modulate.a = a
		_back.mouse_filter = Control.MOUSE_FILTER_STOP if a > 0.2 else Control.MOUSE_FILTER_IGNORE
		_view_btn.mouse_filter = _back.mouse_filter
	else:
		_back.modulate.a = 1.0
		_back.mouse_filter = Control.MOUSE_FILTER_STOP
	# Keyboard / controller (desktop and tests): the gameplay actions double as swim controls.
	if mode == "swim" and _stick_touch < 0:
		var k := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		if k.length() > 0.05:
			swim_stick = k
		var cam := Input.get_vector("cam_left", "cam_right", "cam_down", "cam_up")
		if cam.length() > 0.05:
			swim_look += Vector2(cam.x, -cam.y) * 2.2 * dt
		if not _btn_touch.values().has("up") and not _btn_touch.values().has("down"):
			swim_up = (1.0 if Input.is_action_pressed("jump") else 0.0) - (1.0 if Input.is_action_pressed("lunge") else 0.0)
		if not _btn_touch.values().has("fast"):
			swim_fast = Input.is_action_pressed("swipe")
	_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		p.back()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			_down(e.index, e.position)
		else:
			_up(e.index, e.position)
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		_move(e.index, e.position, e.relative)


func _over_button(pos: Vector2) -> bool:
	for b in [_back, _live_btn, _swim_btn, _view_btn]:
		if b.visible and b.modulate.a > 0.2 and b.get_global_rect().has_point(pos):
			return true
	return false


func _down(idx: int, pos: Vector2) -> void:
	if mode == "live":
		_live_show = 3.0
	if _over_button(pos):
		return
	_tap_start[idx] = pos
	match mode:
		"inspect":
			_drag_touch = idx
			_drag_last = pos
		"swim":
			for name_ in _buttons:
				var b: Array = _buttons[name_]
				if pos.distance_to(b[0]) <= (b[1] as float) * 1.25:
					_btn_touch[idx] = name_
					_apply_buttons()
					get_viewport().set_input_as_handled()
					return
			var vp := _root.get_viewport_rect().size
			if pos.x < vp.x * 0.45 and _stick_touch < 0:
				_stick_touch = idx
				_stick_origin = pos
				swim_stick = Vector2.ZERO
			else:
				_look_touches[idx] = pos
	get_viewport().set_input_as_handled()


func _move(idx: int, pos: Vector2, rel: Vector2) -> void:
	if idx == _drag_touch and mode == "inspect":
		p.inspect_drag(rel)
	elif idx == _stick_touch:
		var v := (pos - _stick_origin) / (90.0 * _s)
		v = v.limit_length(1.0)
		swim_stick = Vector2(v.x, -v.y) if v.length() > 0.12 else Vector2.ZERO
	elif _look_touches.has(idx):
		swim_look += rel * 0.0055


func _up(idx: int, pos: Vector2) -> void:
	if idx == _drag_touch:
		_drag_touch = -1
	if idx == _stick_touch:
		_stick_touch = -1
		swim_stick = Vector2.ZERO
	_look_touches.erase(idx)
	if _btn_touch.has(idx):
		_btn_touch.erase(idx)
		_apply_buttons()
	var start: Vector2 = _tap_start.get(idx, Vector2.INF)
	_tap_start.erase(idx)
	if mode == "room" and start != Vector2.INF and start.distance_to(pos) < 20.0 and p.tap_hits_tank(pos):
		p.go("inspect")


func _apply_buttons() -> void:
	var held: Array = _btn_touch.values()
	swim_up = (1.0 if held.has("up") else 0.0) - (1.0 if held.has("down") else 0.0)
	swim_fast = held.has("fast")


func _release() -> void:
	_stick_touch = -1
	_drag_touch = -1
	_look_touches.clear()
	_btn_touch.clear()
	swim_stick = Vector2.ZERO
	swim_up = 0.0
	swim_fast = false


func swim_buttons() -> Dictionary:
	return _buttons


class UiCanvas extends Control:
	var ui: PresentationUi

	func _draw() -> void:
		if ui.mode != "swim":
			return
		var s := ui._s
		# The stick.
		if ui._stick_touch >= 0:
			draw_circle(ui._stick_origin, 90.0 * s, Color(0.8, 1.0, 0.95, 0.1))
			draw_arc(ui._stick_origin, 90.0 * s, 0, TAU, 48, Color(0.85, 1.0, 0.95, 0.35), 2.0 * s, true)
			draw_circle(ui._stick_origin + Vector2(ui.swim_stick.x, -ui.swim_stick.y) * 90.0 * s, 38.0 * s, Color(0.9, 1.0, 0.97, 0.45))
		for name_ in ui.swim_buttons():
			var b: Array = ui.swim_buttons()[name_]
			var c: Vector2 = b[0]
			var r: float = b[1]
			var held: bool = ui._btn_touch.values().has(name_)
			draw_circle(c, r, Color(0.75, 1.0, 0.95, 0.3 if held else 0.14))
			draw_arc(c, r, 0, TAU, 40, Color(0.9, 1.0, 0.97, 0.9 if held else 0.5), 2.5 * s, true)
			var ic := Color(1, 1, 1, 0.9)
			var k := r * 0.42
			match name_:
				"up":
					draw_polyline(PackedVector2Array([c + Vector2(-k, k * 0.4), c + Vector2(0, -k * 0.6), c + Vector2(k, k * 0.4)]), ic, 4.0 * s, true)
				"down":
					draw_polyline(PackedVector2Array([c + Vector2(-k, -k * 0.4), c + Vector2(0, k * 0.6), c + Vector2(k, -k * 0.4)]), ic, 4.0 * s, true)
				"fast":
					for j in 2:
						var o := Vector2(-k * 0.35 + j * k * 0.6, 0)
						draw_polyline(PackedVector2Array([c + o + Vector2(-k * 0.3, -k * 0.6), c + o + Vector2(k * 0.3, 0), c + o + Vector2(-k * 0.3, k * 0.6)]), ic, 4.0 * s, true)

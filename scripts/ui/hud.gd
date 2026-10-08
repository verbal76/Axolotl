class_name Hud
extends CanvasLayer
## Minimal touch HUD: floating virtual stick (left), camera swipe (right side), three action
## buttons, pause button. Translucent first-use prompts. Health is on the axolotl, not here.

const BTN_JUMP := "jump"
const BTN_SWIPE := "swipe"
const BTN_LUNGE := "lunge"
## The Tier-2 button (docs/TIER2.md): shown once the run has a Tier-2 ability; its glyph is the
## equipped one and it refills radially while cooling down.
const BTN_SPECIAL := "special"

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
var _special_shown := false
var _special_reveal := 0.0      # fades the button in when first revealed
var _special_ready_flash := 0.0
var _special_was_ready := true
## The red starfish chip (docs/SKILL_TREE.md): small, top left, only for a moment after a pickup.
var star_chip: StarChip
## Hard Mode's DEAD / LIVING bar (VitalityBar), top centre; never shown in Normal.
var vitality_bar: VitalityBar
var _vitality_on := false


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
	star_chip = StarChip.new()
	star_chip.name = "StarChip"
	star_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(star_chip)
	vitality_bar = VitalityBar.new()
	vitality_bar.name = "VitalityBar"
	vitality_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vitality_bar.visible = false
	root.add_child(vitality_bar)
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
		# (Right-thumb cluster for a two-handed landscape grip, owner playtest 2026-10-01: tail swipe
		# further left and larger, lunge higher and larger, so the three are told apart by position.
		# Touch areas (1.25 r) keep >= 25 px of dead space between neighbours at s = 1.)
		BTN_SWIPE: {"c": jump_c + Vector2(-178, 10) * s, "r": 54.0 * s},
		BTN_LUNGE: {"c": jump_c + Vector2(-40, -170) * s, "r": 54.0 * s},
		BTN_SPECIAL: {"c": jump_c + Vector2(-200, -150) * s, "r": 46.0 * s},
	}
	_stick_rest = Vector2(_safe.position.x + 165 * s, _safe.end.y - 150 * s)
	if _stick_touch < 0:
		_stick_origin = _stick_rest
	_pause_rect = Rect2(Vector2(_safe.end.x - 64 * s, _safe.position.y + 6), Vector2(56, 56) * s)
	if timer_label:
		timer_label.position = _safe.position + Vector2(6, 4)
	if star_chip:
		star_chip.k = s
		star_chip.position = _safe.position + Vector2(6, 40 * s)
	if vitality_bar:
		vitality_bar.k = s
		vitality_bar.size = Vector2(VitalityBar.W, VitalityBar.H) * s
		vitality_bar.position = Vector2(_safe.position.x + (_safe.size.x - vitality_bar.size.x) * 0.5, _safe.position.y + 6)
	canvas.scale_k = s
	canvas.queue_redraw()


## Hard Mode: the bar is part of this run's HUD (Game, when the run opens).
func show_vitality(on: bool) -> void:
	_vitality_on = on
	vitality_bar.visible = on
	_update_bar()


## Hard Mode, four times a second: the current sphere's mean V, his zone's V and its pressure.
func set_vitality(mean_v: float, zone_v: float, pressured: bool) -> void:
	vitality_bar.set_values(mean_v, zone_v, pressured)


func _update_bar() -> void:
	if vitality_bar != null:
		vitality_bar.want = _vitality_on and _controls_visible and not _cinematic


## The action button a touch at `pos` presses: the nearest one (relative to its size) whose touch
## area (1.25 x its radius) holds the point, or "" (so an edge touch never favours whichever button
## happens to be checked first).
func button_at(pos: Vector2) -> String:
	var best := ""
	var best_k := INF
	for action in _buttons:
		if action == BTN_SPECIAL and not _special_shown:
			continue
		var b: Dictionary = _buttons[action]
		var k: float = pos.distance_to(b["c"]) / float(b["r"])
		if k <= 1.25 and k < best_k:
			best = action
			best_k = k
	return best


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
	_update_bar()
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
## Prompt hints draw only while the player has the controls: during a cinematic (camera or control
## taken away) the buttons fade out, and their hint ring was left pulsing round an empty space. The
## prompts stay registered and come back with the controls.
func prompts_shown() -> bool:
	return _controls_visible and not _cinematic


func _process(dt: float) -> void:
	_update_timer()
	_alpha = move_toward(_alpha, _target_alpha, dt * 3.0)
	for k in _pressed.keys():
		_pressed[k] = maxf(0.0, _pressed[k] - dt)
	var g := Game.inst
	_special_shown = g != null and g.tier2 != null and g.tier2.any()
	_special_reveal = move_toward(_special_reveal, 1.0 if _special_shown else 0.0, dt * 1.5)
	if _special_shown and g.clock != null:
		var rdy: bool = g.tier2.is_ready(g.clock.play_s)
		if rdy and not _special_was_ready:
			_special_ready_flash = 1.0
		_special_was_ready = rdy
	_special_ready_flash = maxf(0.0, _special_ready_flash - dt * 2.0)
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
	var action := button_at(pos)
	if action != "":
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


## A short note that a new species was discovered ("New species: Canopy snail"), or a first-encounter
## name ("Shrimp — Food"). Notes that come while one is up wait their turn (never overwritten).
func show_discovery(text: String) -> void:
	if _discovery_busy:
		if text != discovery_label.text and not _discovery_queue.has(text):
			_discovery_queue.append(text)
		return
	_discovery_busy = true
	discovery_label.text = text
	var tw := create_tween()
	tw.tween_property(discovery_label, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.6)
	tw.tween_property(discovery_label, "modulate:a", 0.0, 1.2)
	tw.finished.connect(func() -> void:
		_discovery_busy = false
		if not _discovery_queue.is_empty():
			show_discovery(_discovery_queue.pop_front()))


var _discovery_busy := false
var _discovery_queue: Array[String] = []


func _update_timer() -> void:
	var g := Game.inst
	var on := Settings.show_run_timer and g != null and g.clock != null and g.state == "play" and _controls_visible
	timer_label.visible = on
	if on:
		timer_label.text = RunClock.format(g.clock.shown_s()) + ("  finished" if g.clock.is_finished() else "")


func button_info() -> Dictionary:
	return _buttons


## Whether the Tier-2 button is on screen (the run has an ability) and how far it has faded in.
func special_shown() -> bool:
	return _special_shown


func special_alpha() -> float:
	return _special_reveal


## Called when the first Tier-2 ability is found: the button fades in.
func reveal_special() -> void:
	_special_shown = true
	_special_ready_flash = 1.0


## A red starfish collected: the star chip shows the count (and what there is to spend) for a
## few seconds, then fades.
func star_collected(n: int, total: int, balance: int) -> void:
	# (During a Treasure Hunt its box holds the same corner: the chip shows just below it.)
	star_chip.position = _safe.position + Vector2(6, 40 * canvas.scale_k)
	var tp: TreasurePlay = Game.inst.treasure if Game.inst != null else null
	if tp != null and tp.panel != null:
		var br := tp.panel.box_rect()
		if br.size != Vector2.ZERO:
			star_chip.position.y = br.end.y + 8.0
	star_chip.show_count(n, total, balance)


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
				if action == Hud.BTN_SPECIAL:
					if hud.special_shown():
						_draw_special(a * hud.special_alpha())
					continue
				_draw_button(action, a)
		if hud.prompts_shown():
			_draw_prompts(pa)

	func _draw_stick(a: float) -> void:
		var info := hud.stick_info()
		var o: Vector2 = info[0]
		var v: Vector2 = info[1]
		var active: bool = info[2]
		var r := hud.stick_radius()
		var k := (1.0 if active else 0.55) * a
		# Frosted ring with faint direction ticks; the rim lights toward the push.
		draw_circle(o + Vector2(0, 3) * scale_k, r, Color(0, 0.05, 0.05, 0.16 * k))
		draw_circle(o, r, Color(0.08, 0.2, 0.2, 0.28 * k))
		draw_arc(o, r, 0, TAU, 64, Color(0, 0.08, 0.08, 0.35 * k), 4.0 * scale_k, true)
		draw_arc(o, r - 1.5 * scale_k, 0, TAU, 64, Color(0.85, 1.0, 0.95, 0.45 * k), 1.8 * scale_k, true)
		for q in 4:
			var d := Vector2.RIGHT.rotated(q * PI * 0.5)
			draw_line(o + d * r * 0.8, o + d * r * 0.9, Color(0.9, 1.0, 0.97, 0.4 * k), 2.5 * scale_k, true)
		var push := v.length()
		if push > 0.05:
			var ang := v.angle()
			draw_arc(o, r - 1.5 * scale_k, ang - 0.6, ang + 0.6, 24, Color(0.75, 1.0, 0.92, 0.85 * push * k), 4.5 * scale_k, true)
		var kc := o + v * r * 0.75
		var kr := r * 0.4
		draw_circle(kc + Vector2(0, 3) * scale_k, kr, Color(0, 0.05, 0.05, 0.3 * k))
		draw_circle(kc, kr, Color(0.55, 0.85, 0.8, 0.75 * k))
		draw_circle(kc + Vector2(0, -kr * 0.25), kr * 0.7, Color(0.85, 1.0, 0.96, 0.45 * k))
		draw_arc(kc, kr, 0, TAU, 40, Color(1, 1, 1, 0.7 * k), 2.0 * scale_k, true)

	## Frosted glass disc shared by every action button: drop shadow, tinted body, top sheen and a
	## two-tone rim (dark outside so it reads over bright moss). Pressed shrinks it a touch.
	func _glass(c: Vector2, r: float, a: float, glow: float, tint: Color, rim: float) -> float:
		var rr := r * (1.0 - 0.06 * glow)
		draw_circle(c + Vector2(0, 4) * scale_k, rr, Color(0, 0.05, 0.05, 0.22 * a))
		draw_circle(c, rr, Color(tint.r * 0.25, tint.g * 0.3, tint.b * 0.3, (0.42 + glow * 0.2) * a))
		draw_circle(c, rr * 0.92, Color(tint.r, tint.g, tint.b, (0.1 + glow * 0.25) * a))
		draw_circle(c + Vector2(0, -rr * 0.38), rr * 0.55, Color(1, 1, 1, 0.07 * a))
		draw_arc(c, rr, 0, TAU, 64, Color(0, 0.08, 0.08, 0.4 * a), 4.0 * scale_k, true)
		if rim > 0.0:
			draw_arc(c, rr - 1.5 * scale_k, 0, TAU, 64, Color(0.9, 1.0, 0.97, (rim + glow * 0.4) * a), 2.0 * scale_k, true)
		return rr

	## A filled icon with a soft dark under-shadow so it never washes out.
	func _fill(pts: PackedVector2Array, ic: Color) -> void:
		var sh := PackedVector2Array()
		for q in pts:
			sh.append(q + Vector2(0, 2.5) * scale_k)
		draw_colored_polygon(sh, Color(0, 0.06, 0.06, 0.45 * ic.a))
		draw_colored_polygon(pts, ic)

	func _draw_button(action: String, a: float) -> void:
		var b: Dictionary = hud.button_info()[action]
		var c: Vector2 = b["c"]
		var glow := clampf(hud.pressed_glow(action), 0.0, 1.0)
		var r := _glass(c, b["r"], a, glow, Color(0.75, 1.0, 0.95), 0.5)
		var ic := Color(1, 1, 1, (0.85 + glow * 0.15) * a)
		var s := r * 0.46
		match action:
			"jump":
				# A bold up-arrow lifting off a little bubble.
				_fill(PackedVector2Array([c + Vector2(0, -s * 0.95), c + Vector2(s * 0.85, -s * 0.05),
						c + Vector2(s * 0.32, -s * 0.05), c + Vector2(s * 0.32, s * 0.45), c + Vector2(-s * 0.32, s * 0.45),
						c + Vector2(-s * 0.32, -s * 0.05), c + Vector2(-s * 0.85, -s * 0.05)]), ic)
				draw_circle(c + Vector2(0, s * 0.82), s * 0.2, ic)
			"swipe":
				# A tapered tail sweep (thin to thick) ending in an arrowhead.
				var pts := PackedVector2Array()
				var a0 := PI * 0.95
				var a1 := PI * 2.25
				var n := 18
				for q in n + 1:
					var t := float(q) / n
					pts.append(c + Vector2.from_angle(lerpf(a0, a1, t)) * s * 0.95)
				for q in range(n, -1, -1):
					var t := float(q) / n
					pts.append(c + Vector2.from_angle(lerpf(a0, a1, t)) * s * (0.95 - lerpf(0.05, 0.38, t)))
				_fill(pts, ic)
				var tip := Vector2.from_angle(a1)
				var mid := c + tip * s * 0.76
				var fwd := tip.rotated(PI * 0.5)
				_fill(PackedVector2Array([mid + fwd * s * 0.55, mid + tip * s * 0.42 - fwd * s * 0.05,
						mid - tip * s * 0.42 - fwd * s * 0.05]), ic)
			"lunge":
				# A forward dart: solid arrowhead with speed streaks trailing behind.
				_fill(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, s * 0.05),
						c + Vector2(0, -s * 0.22), c + Vector2(-s * 0.75, s * 0.05)]), ic)
				for q in 3:
					var x := (q - 1) * s * 0.42
					var y0 := s * (0.2 + 0.12 * absf(q - 1))
					draw_line(c + Vector2(x, y0), c + Vector2(x, y0 + s * (0.75 - 0.25 * absf(q - 1))),
							Color(ic.r, ic.g, ic.b, ic.a * (0.9 - 0.3 * absf(q - 1))), 3.5 * scale_k, true)

	## The Tier-2 button: the equipped ability's glyph; dimmed with a radial refill while it cools.
	func _draw_special(a: float) -> void:
		var g := Game.inst
		var b: Dictionary = hud.button_info()[Hud.BTN_SPECIAL]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var charge: float = g.tier2.charge(g.clock.play_s) if g.clock != null else 1.0
		var ready := charge >= 1.0
		var glow := clampf(hud.pressed_glow(Hud.BTN_SPECIAL), 0.0, 1.0)
		var tint := Color(0.62, 0.9, 1.0)
		_glass(c, r, a, glow, tint if ready else tint * 0.6, 0.0)
		if not ready:
			# The refill: a bright arc growing clockwise from the top as it recharges.
			draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, Color(0.85, 0.97, 1.0, 0.85 * a), 4.0 * scale_k, true)
			draw_arc(c, r, -PI * 0.5 + TAU * charge, PI * 1.5, 48, Color(1, 1, 1, 0.18 * a), 2.0 * scale_k, true)
		else:
			draw_arc(c, r, 0, TAU, 48, Color(0.9, 1.0, 1.0, (0.55 + glow * 0.45) * a), 2.5 * scale_k, true)
		var flash: float = hud._special_ready_flash
		if flash > 0.0:
			draw_arc(c, r * (1.0 + (1.0 - flash) * 0.5), 0, TAU, 48, Color(0.7, 1.0, 1.0, 0.7 * flash * a), 3.0 * scale_k, true)
		var ic := Color(1, 1, 1, ((0.9 if ready else 0.35) + glow * 0.1) * a)
		Tier2Glyphs.draw(self, g.tier2.equipped, c, r * 0.46, ic, scale_k)

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
				"jump", "swipe", "lunge", "special":
					if p == "special" and not hud.special_shown():
						continue
					var b: Dictionary = hud.button_info()[p]
					_ring(b["c"], b["r"], pulse, col, pa, {"jump": "A", "swipe": "X", "lunge": "B", "special": "Y"}[p])
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

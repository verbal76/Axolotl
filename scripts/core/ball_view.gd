class_name BallView
extends CanvasLayer
## Owner, 2026-10-08: opened by the player (the HUD's whole-ball button, top left; a controller's
## Back / View), it stays until that same button is pressed again: the thumb turns the ball (a drag
## orbits the camera all round it, so every side can be seen) and other touches do nothing. A
## controller's buttons still return. The first-arrival view (`auto`) is unchanged: any press skips.
##
## The whole-ball view on demand (ledger row 21): the tutorial's reveal shot (the camera ~30 m past
## the ball's ground, looking back at the whole moss ball) whenever the player asks for it, from the
## pause menu ("View whole ball") or a controller's Back / View button (keyboard V). It is also the
## first-arrival establishing view (cohesion audit P3): Game._arrived opens it with `auto` for about
## 3 s the first time in a run a tunnel lands him on each ball after Ball 1.
##
## The run stands still while it shows (the tree is paused, as for the pause menu): no damage, no
## current, no clock. Only the camera and this node run. The shot circles slowly round the spot he
## stands on so the ball reads as a ball. Any touch, click, key or button returns; the camera blends
## back to exactly the follow place it left (its yaw, pitch and distance are restored) and only then
## is the run let go, so control comes back exactly where it was.
## The camera safety invariant (FollowCam._enforce_safe) still resolves every frame of it, and the
## shot is kept inside the tank's glass, which the reveal on Ball 1 never needed but outer balls do.

## The camera's distance past the ball's ground (the tutorial reveal's).
const PAST_SURFACE_M := 30.0
## How slowly it circles (rad/s).
const ORBIT_RATE := 0.1
## Kept this far inside the tank's glass and above its floor (m).
const TANK_MARGIN_M := 10.0
## Input in the first moments is the press that opened it, never a request to close.
const GRACE_S := 0.35

var g: Game
var active := false
## Closing: the camera is blending back; the run is still held until it is home.
var returning := false
var t := 0.0
## Returns by itself after this long (s; 0 = only on input): the first-arrival establishing view
## (cohesion audit P3, Game._arrived) is this same view, shown once for about 3 s.
var auto_s := 0.0
## How many times it has opened as a first-arrival view (tests and diagnostics).
var arrivals_shown := 0
var _label: Label
var _saved := {}
## Where the camera actually was when it opened, if it was already on a cinematic shot (a tunnel's
## landing hands straight over to the first-arrival view): the shot eases out from there over
## FROM_S instead of jumping, since the camera's own blend is already complete.
var _from := {}
const FROM_S := 0.8
## How far a drag turns the view (radians per pixel at 720 px tall).
const DRAG_RATE := 0.008
## The camera never comes nearer the ball's centre than its radius plus this (m): where the tank's
## glass or floor would push it closer, that turn is not taken.
const MIN_CLEAR_M := 20.0

## Opened by the player (stays until the button again), not the timed first-arrival view.
var manual := false
## The manual view's orbit: the direction from the ball's centre to the camera, and the camera's up.
var _dir := Vector3.ZERO
var _up := Vector3.UP
## The thumb has turned it (the slow circling stops).
var dragged := false
var _icon: Control


func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiStyle.theme()
	add_child(root)
	_label = Label.new()
	_label.name = "BallViewHint"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color(0.9, 1.0, 0.96, 0.9))
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.08, 0.08, 0.8))
	_label.add_theme_constant_override("outline_size", 6)
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -28
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_label)
	# The whole-ball button, where the HUD draws it: here it means "back to play".
	_icon = _Icon.new()
	_icon.name = "BallViewButton"
	_icon.view = self
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_icon)
	visible = false


class _Icon extends Control:
	var view: BallView

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if view.manual and view.g != null and view.g.hud != null:
			var k := clampf(get_viewport_rect().size.y / 720.0, 0.75, 1.4)
			Hud.HudCanvas.draw_ball_icon(self, view.g.hud.ball_rect(), k, 1.0)


## Whether the view can open now: ordinary play only (not mid-cinematic, mid-fall, dead, or in the
## aquarium experiences).
func can_open() -> bool:
	return g != null and g.state == "play" and g.cinematic == "" and g.player.state == "normal" and not active \
			and (g.presentation == null or not g.presentation.active())


## Opens the view. `auto` > 0: it returns by itself after that many seconds (the first-arrival
## view); any press after GRACE_S still returns at once.
func open(auto := 0.0) -> bool:
	if not can_open():
		return false
	var cam := g.cam
	active = true
	returning = false
	t = 0.0
	auto_s = auto
	manual = auto <= 0.0
	dragged = false
	if auto > 0.0:
		arrivals_shown += 1
	_saved = {"yaw": cam.yaw_dir, "pitch": cam.pitch, "up": cam.cam_up, "dist": cam._cur_dist,
			"hud": g.hud.visible, "onb": g.onboarding != null and g.onboarding.ui != null and g.onboarding.ui.visible,
			"cam_mode": cam.process_mode, "hud_cine": g.hud._cinematic}
	_from = {}
	if cam._cine_weight > 0.0:
		var look: Vector3 = cam._look if cam._look != Vector3.INF else cam.global_position - cam.global_basis.z * 3.0
		_from = {"pos": cam.global_position, "look": look, "up": cam.global_basis.y}
	get_tree().paused = true
	# (Any finger on the stick or a button is let go: the HUD does not see the release while the
	# run is held, and a stick left held would walk him off when it returns.)
	g.hud.set_cinematic(true)
	# (The camera keeps running through the pause: its blend and its safety stage.)
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.cinematic = true
	g.hud.visible = false
	if _saved["onb"]:
		g.onboarding.ui.visible = false
	var how := "Press any button to return" if Settings.input_mode == Settings.InputMode.PAD \
			else "Drag to turn the ball  ·  tap the ball button to return"
	if auto > 0.0:
		how = "Press any button to skip" if Settings.input_mode == Settings.InputMode.PAD else "Tap anywhere to skip"
	_label.text = "%s\n%s" % [caption(g.player.ball, g.vortices), how]
	visible = true
	_aim(0.0)
	var s0 := shot(g.player.ball, g.player.up, g.player.facing, 0.0)
	_dir = ((s0[0] as Vector3) - g.player.ball.global_position).normalized()
	_up = (s0[2] as Vector3).normalized()
	return true


## The ball's name and how restored it is, and, while a tunnel out of it is still shut, when it
## opens (cohesion audit 2026-10-02: nowhere else tells the player how near that is).
static func caption(b: MossBall, vortices: Array) -> String:
	var pct := int(floor(b.restoration * 100.0 + 0.0001))
	var out := "%s  ·  %d%% restored" % [b.display_name if b.display_name != "" else "Moss ball %d" % (b.index + 1), pct]
	for v: Vortex in vortices:
		if v.ball_a == b and not v.connected:
			out += "  ·  a water tunnel opens at %d%%" % int(round(Vortex.CONNECT_AT * 100.0))
			break
	return out


## The pause menu's line for the ball he is on (cohesion audit P2): its name, how restored it is, and
## where its water tunnel stands: "Terrace Steps  ·  42% restored  ·  tunnel opens at 70%" until the
## tunnel out of it opens, "...  ·  74% restored  ·  tunnel open" after ("tunnels open at 70%" /
## "tunnels open" on the two balls with two). 70% only opens the way on; the ball is done at 100%,
## so the tunnel never reads as the ball's end. A ball with no tunnel out: its name and % only.
static func progress_line(b: MossBall, vortices: Array) -> String:
	if b == null:
		return ""
	var pct := int(floor(b.restoration * 100.0 + 0.0001))
	var out := "%s  ·  %d%% restored" % [b.display_name if b.display_name != "" else "Moss ball %d" % (b.index + 1), pct]
	# (Every tunnel out of a ball opens at the same 70%: Mossy Meadow and Current Hollows have two.)
	var outs := vortices.filter(func(v: Vortex) -> bool: return v.ball_a == b)
	if outs.is_empty():
		return out
	var open := b.restoration >= Vortex.CONNECT_AT - 0.0001 or outs.all(func(v: Vortex) -> bool: return v.connected)
	var noun := "tunnel" if outs.size() == 1 else "tunnels"
	if open:
		return out + "  ·  %s open" % noun
	return out + "  ·  %s %s at %d%%" % [noun, "opens" if outs.size() == 1 else "open", int(round(Vortex.CONNECT_AT * 100.0))]


## Starts the return (any input). The run is let go once the camera is home (_process).
func close() -> void:
	if not active or returning:
		return
	returning = true
	visible = false
	var cam := g.cam
	cam.cinematic = false
	_hold_follow()
	cam._cur_dist = _saved["dist"]


func _hold_follow() -> void:
	var cam := g.cam
	cam.yaw_dir = _saved["yaw"]
	cam.pitch = _saved["pitch"]
	cam.cam_up = _saved["up"]
	cam.swipe_delta = Vector2.ZERO


func _finish() -> void:
	var cam := g.cam
	cam.process_mode = _saved["cam_mode"]
	_hold_follow()
	g.hud.visible = _saved["hud"]
	g.hud.set_cinematic(_saved["hud_cine"])
	if _saved["onb"]:
		g.onboarding.ui.visible = true
	active = false
	returning = false
	get_tree().paused = false


func _process(dt: float) -> void:
	if not active:
		return
	t += dt
	# (The follow camera underneath stays exactly as it was left: no drift, no stick, no swipe.)
	_hold_follow()
	if returning:
		if g.cam._cine_weight <= 0.0:
			_finish()
		return
	_aim(t)
	if auto_s > 0.0 and t >= auto_s:
		close()
		return
	# (The balls show only what can be above the camera's horizon; the game's own update is paused.)
	for b in g.balls:
		b.update_visibility(g.cam.global_position)


func _aim(at_t: float) -> void:
	var s := shot(g.player.ball, g.player.up, g.player.facing, at_t * ORBIT_RATE)
	if dragged:
		s = orbit_shot(g.player.ball, _dir, _up)
	if not _from.is_empty() and at_t < FROM_S:
		var k := smoothstep(0.0, 1.0, at_t / FROM_S)
		s = [(_from["pos"] as Vector3).lerp(s[0], k), (_from["look"] as Vector3).lerp(s[1], k),
				(_from["up"] as Vector3).slerp((s[2] as Vector3).normalized(), k)]
	g.cam.cine_pos = s[0]
	g.cam.cine_look = s[1]
	g.cam.cine_up = s[2]


## The whole-ball shot for `b` from the spot whose up is `up` (facing `facing`), circled `orbit`
## radians round that up: [camera place, look-at, camera up]. Kept inside the tank's glass, above
## its floor. Game._cine_frame (the tutorial reveal) uses it too.
static func shot(b: MossBall, up: Vector3, facing: Vector3, orbit := 0.0) -> Array:
	var d := (up * 0.55 - facing * 0.85).normalized()
	if orbit != 0.0:
		d = d.rotated(up, orbit)
	var c := b.global_position
	var pos := in_tank(c + d * (b.radius + PAST_SURFACE_M))
	var dd := (pos - c).normalized()
	var look := c + up * b.radius * 0.25
	var cu := (up - dd * up.dot(dd)).normalized()
	if cu.length() < 0.1:
		cu = Vector3.UP
	return [pos, look, cu]


## The manual view's shot: from `dir` (centre to camera), up `up`: [camera place, look-at, up].
static func orbit_shot(b: MossBall, dir: Vector3, up: Vector3) -> Array:
	var c := b.global_position
	var pos := in_tank(c + dir * (b.radius + PAST_SURFACE_M))
	var dd := (pos - c).normalized()
	var cu := (up - dd * up.dot(dd)).normalized()
	if cu.length() < 0.1:
		cu = Vector3.UP
	return [pos, c, cu]


## Turns the manual view by a drag of `rel` pixels (left/right round the camera's up, up/down over
## the top and bottom). A turn that would bring the camera too near the ball (the tank's glass or
## floor in the way) is not taken.
func turn(rel: Vector2) -> void:
	var b: MossBall = g.player.ball
	if not dragged:
		# (From wherever the slow circling has got to.)
		_dir = (g.cam.cine_pos - b.global_position).normalized()
		_up = g.cam.cine_up.normalized()
	var k := DRAG_RATE * 720.0 / maxf(1.0, get_viewport().get_visible_rect().size.y)
	var d := _dir.rotated(_up, -rel.x * k)
	var u := _up
	var right := u.cross(d).normalized()
	if right.length() > 0.1:
		d = d.rotated(right, rel.y * k)
		u = u.rotated(right, rel.y * k)
	d = d.normalized()
	u = (u - d * u.dot(d)).normalized()
	var s := orbit_shot(b, d, u)
	if (s[0] as Vector3).distance_to(b.global_position) < b.radius + MIN_CLEAR_M:
		return
	_dir = d
	_up = u
	dragged = true


## `p` kept TANK_MARGIN_M inside the glass and above the tank's floor.
static func in_tank(p: Vector3) -> Vector3:
	var lo := Aquarium.TANK_MIN + Vector3.ONE * TANK_MARGIN_M
	var hi := Aquarium.TANK_MAX - Vector3.ONE * TANK_MARGIN_M
	var out := p.clamp(lo, hi)
	out.y = maxf(out.y, Aquarium.floor_point(out.x, out.z).y + TANK_MARGIN_M)
	return out


## The first-arrival view: any touch, click, key or button closes it (after the opening press).
## The player's view: a drag turns the ball, a tap on the whole-ball button returns, and a key or a
## controller button returns. Nothing reaches play either way.
func _input(event: InputEvent) -> void:
	if not active:
		return
	get_viewport().set_input_as_handled()
	if returning:
		return
	if manual:
		if event is InputEventScreenDrag:
			turn((event as InputEventScreenDrag).relative)
			return
		if event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask & MOUSE_BUTTON_MASK_LEFT:
			turn((event as InputEventMouseMotion).relative)
			return
	if t < GRACE_S:
		return
	var tap: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed)
	var press: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed)
	if manual and tap:
		var at: Vector2 = event.position
		if g.hud.ball_rect().grow(10).has_point(at):
			close()
		return
	if tap or press:
		close()

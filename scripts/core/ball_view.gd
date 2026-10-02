class_name BallView
extends CanvasLayer
## The whole-ball view on demand (ledger row 21): the tutorial's reveal shot (the camera ~30 m past
## the ball's ground, looking back at the whole moss ball) whenever the player asks for it, from the
## pause menu ("View whole ball") or a controller's Back / View button (keyboard V).
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
var _label: Label
var _saved := {}


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
	visible = false


## Whether the view can open now: ordinary play only (not mid-cinematic, mid-fall, dead, or in the
## aquarium experiences).
func can_open() -> bool:
	return g != null and g.state == "play" and g.cinematic == "" and g.player.state == "normal" and not active \
			and (g.presentation == null or not g.presentation.active())


func open() -> bool:
	if not can_open():
		return false
	var cam := g.cam
	active = true
	returning = false
	t = 0.0
	_saved = {"yaw": cam.yaw_dir, "pitch": cam.pitch, "up": cam.cam_up, "dist": cam._cur_dist,
			"hud": g.hud.visible, "onb": g.onboarding != null and g.onboarding.ui != null and g.onboarding.ui.visible,
			"cam_mode": cam.process_mode}
	get_tree().paused = true
	# (The camera keeps running through the pause: its blend and its safety stage.)
	cam.process_mode = Node.PROCESS_MODE_ALWAYS
	cam.cinematic = true
	g.hud.visible = false
	if _saved["onb"]:
		g.onboarding.ui.visible = false
	var b := g.player.ball
	var pct := int(round(b.restoration * 100.0))
	var how := "Press any button to return" if Settings.input_mode == Settings.InputMode.PAD else "Tap anywhere to return"
	_label.text = "%s  ·  %d%% restored\n%s" % [b.display_name if b.display_name != "" else "Moss ball %d" % (b.index + 1), pct, how]
	visible = true
	_aim(0.0)
	return true


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
	# (The balls show only what can be above the camera's horizon; the game's own update is paused.)
	for b in g.balls:
		b.update_visibility(g.cam.global_position)


func _aim(at_t: float) -> void:
	var s := shot(g.player.ball, g.player.up, g.player.facing, at_t * ORBIT_RATE)
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


## `p` kept TANK_MARGIN_M inside the glass and above the tank's floor.
static func in_tank(p: Vector3) -> Vector3:
	var lo := Aquarium.TANK_MIN + Vector3.ONE * TANK_MARGIN_M
	var hi := Aquarium.TANK_MAX - Vector3.ONE * TANK_MARGIN_M
	var out := p.clamp(lo, hi)
	out.y = maxf(out.y, Aquarium.floor_point(out.x, out.z).y + TANK_MARGIN_M)
	return out


## Any touch, click, key or button closes it (after the opening press); nothing reaches play.
func _input(event: InputEvent) -> void:
	if not active:
		return
	get_viewport().set_input_as_handled()
	if returning or t < GRACE_S:
		return
	var press: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventJoypadButton and event.pressed)
	if press:
		close()

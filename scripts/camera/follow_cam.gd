class_name FollowCam
extends Camera3D
## Assisted over-the-shoulder camera for spherical surfaces. Keeps its own "up" that eases
## toward the axolotl's local up, and a yaw direction that is parallel-transported across the
## sphere so walking over a pole never flips the view. Supports swipe/stick control,
## obstruction pull-in, and scripted cinematic shots.

var target: Axolotl
var cam_up := Vector3.UP
var yaw_dir := Vector3.FORWARD      # horizontal look direction (tangent to cam_up)
var pitch := 0.32                   # radians above the horizon
var distance := 4.4
var shoulder := 0.35
var _cur_dist := 4.4
var _manual_t := 0.0
var _shake := 0.0
var swipe_delta := Vector2.ZERO     # accumulated by the HUD each frame

# Cinematic override.
var cinematic := false
var cine_pos := Vector3.ZERO
var cine_look := Vector3.ZERO
var cine_up := Vector3.UP
var cine_blend := 0.0
var _cine_weight := 0.0

const PITCH_MIN := -0.25
const PITCH_MAX := 1.1
const SENS := 0.0055


func _ready() -> void:
	fov = 66.0
	near = 0.05
	far = 6000.0


func snap_behind() -> void:
	if target == null:
		return
	cam_up = target.up
	yaw_dir = target.facing
	pitch = 0.32
	_cur_dist = distance
	_place(1.0)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(dt: float) -> void:
	if target == null:
		return
	# Manual input: right-side swipe (HUD) and right stick / keys.
	var stick := Input.get_vector("cam_left", "cam_right", "cam_down", "cam_up")
	var manual := swipe_delta * SENS + Vector2(stick.x, -stick.y) * 2.6 * dt
	swipe_delta = Vector2.ZERO
	if manual.length() > 0.0001:
		_manual_t = 1.6
	_manual_t = maxf(0.0, _manual_t - dt)

	# Ease camera up toward the player's up (sphere-centred gravity).
	var tup := target.up
	var ang := cam_up.angle_to(tup)
	if ang > 0.0001:
		var axis := cam_up.cross(tup)
		if axis.length() > 0.00001:
			var step := minf(ang, ang * minf(1.0, dt * 4.0) + dt * 0.2)
			var q := Quaternion(axis.normalized(), step)
			cam_up = (q * cam_up).normalized()
			yaw_dir = (q * yaw_dir)
	yaw_dir = (yaw_dir - cam_up * yaw_dir.dot(cam_up))
	if yaw_dir.length() < 0.05:
		yaw_dir = target.facing
	yaw_dir = yaw_dir.normalized()

	yaw_dir = yaw_dir.rotated(cam_up, -manual.x)
	pitch = clampf(pitch + manual.y, PITCH_MIN, PITCH_MAX)

	# Assisted follow: drift behind the direction of travel when not manually controlled.
	if _manual_t <= 0.0 and target.state == "normal":
		var mv := target.velocity - cam_up * target.velocity.dot(cam_up)
		if mv.length() > 1.5:
			var desired := mv.normalized()
			var a := yaw_dir.signed_angle_to(desired, cam_up)
			# Don't swing around when walking toward the camera.
			if absf(a) < 2.4:
				yaw_dir = yaw_dir.rotated(cam_up, a * minf(1.0, dt * 1.3))
		pitch = lerpf(pitch, 0.32, minf(1.0, dt * 0.4))

	_place(dt)


func _place(dt: float) -> void:
	var pivot := target.global_position + cam_up * 0.85
	var right := yaw_dir.cross(cam_up).normalized()
	var back := -yaw_dir * cos(pitch) + cam_up * sin(pitch)
	var desired := pivot + back * distance + right * shoulder
	# Obstruction handling: pull in toward the pivot.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pivot, desired, 1 | 2)
	q.exclude = [target.get_rid()]
	q.hit_back_faces = true
	var hit := space.intersect_ray(q)
	var want := distance
	if not hit.is_empty():
		want = maxf(0.6, pivot.distance_to(hit.position) - 0.35)
	_cur_dist = want if want < _cur_dist else lerpf(_cur_dist, want, minf(1.0, dt * 3.0))
	var pos := pivot + (desired - pivot).normalized() * _cur_dist
	var look := pivot + yaw_dir * 1.6 + right * shoulder * 0.6
	if _shake > 0.0:
		pos += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * _shake * 0.4
		_shake = maxf(0.0, _shake - dt * 1.2)

	_cine_weight = move_toward(_cine_weight, 1.0 if cinematic else 0.0, dt * (1.6 if cinematic else 1.2))
	if _cine_weight > 0.0:
		var w := smoothstep(0.0, 1.0, _cine_weight)
		pos = pos.lerp(cine_pos, w)
		look = look.lerp(cine_look, w)
		var u := cam_up.slerp(cine_up.normalized(), w) if cam_up.angle_to(cine_up) > 0.001 else cam_up
		global_position = pos
		if pos.distance_to(look) > 0.01:
			look_at(look, u)
		return
	global_position = pos
	look_at(look, cam_up)

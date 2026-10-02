class_name FollowCam
extends Camera3D
## Assisted over-the-shoulder camera for spherical surfaces. Keeps its own "up" that eases
## toward the axolotl's local up, and a yaw direction that is parallel-transported across the
## sphere so walking over a pole never flips the view. Supports swipe/stick control,
## obstruction pull-in, and scripted cinematic shots.
##
## THE CAMERA SAFETY INVARIANT (owner, 2026-10-02, a class defect: the view was seen inside a moss
## ball on three different paths: free-look, the title orbit, a death). Many systems ask for a
## camera place: the follow camera here, every cinematic shot (deaths and re-forming, ooze, tunnel
## ride and landing, restoration and connection shots, tutorial lessons, the title orbit, through
## cine_pos), camera shake, and the aquarium's presentation (which writes the transform itself).
## Whatever asked, the place is resolved in one stage, `_enforce_safe`, run by this node after every
## other node's _process (process_priority) and so right before the frame is drawn: never under any
## moss ball's ground (measured radially on that ball's own terrain, whichever way up it is) and
## never inside a solid (leaf, stem, rock, mound, cave wall). In test runs `_audit` re-checks the
## transform about to be drawn (after every writer) and counts any frame that breaks it.

var target: Axolotl
var cam_up := Vector3.UP
var yaw_dir := Vector3.FORWARD      # horizontal look direction (tangent to cam_up)
var pitch := 0.32                   # radians above the horizon
var distance := 4.4
var shoulder := 0.35
var _cur_dist := 4.4
## Extra pitch while something (a pillar, a stem, a wall) stands behind him: the camera rises over
## it rather than jamming against the back of his head (owner, 2026-10-02).
var _rise := 0.0
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
const GROUND_CLEAR := 0.45   # m the camera keeps above the terrain
const SOLID_MASK := 1 | 2

## What the camera looks at this frame (for re-aiming after a correction); set by _place.
var _look := Vector3.INF
var _look_up := Vector3.UP
## Frames whose requested place broke the invariant and were corrected (any writer).
var corrected_frames := 0
## Test runs: frames drawn, and frames drawn from an unsafe place (must stay 0), with the worst.
var audited_frames := 0
var unsafe_drawn := 0
var unsafe_worst := ""
## Tests only: off shows what the requested places alone would draw.
var enforce := true


func _ready() -> void:
	fov = 66.0
	near = 0.05
	far = 6000.0
	# (Last of all: after the game, the tutorial, the presentation and anything else has placed it.)
	process_priority = 1000
	if Settings.test_mode != "":
		# (After every node's _process, this one's safety stage included, as the frame is drawn:
		# frame_pre_draw would be exact but headless runs never draw.)
		var a := _Auditor.new()
		a.cam = self
		a.process_priority = 2000
		a.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(a)


func snap_behind() -> void:
	if target == null:
		return
	cam_up = target.up
	yaw_dir = target.facing
	pitch = 0.32
	_cur_dist = distance
	_place(1.0)
	_enforce_safe()


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(dt: float) -> void:
	_look = Vector3.INF
	if target != null:
		_follow(dt)
	_enforce_safe()


func _follow(dt: float) -> void:
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


const RISE_STEPS := [0.3, 0.6, 0.9]
const RISE_MAX := 1.0


## How far the view line from the pivot runs clear at pitch `p` (to the full distance + margin).
func _clear_len(space: PhysicsDirectSpaceState3D, pivot: Vector3, p: float, right: Vector3) -> float:
	var back := -yaw_dir * cos(p) + cam_up * sin(p)
	var to := pivot + back * (distance + 0.35) + right * shoulder
	var q := PhysicsRayQueryParameters3D.create(pivot, to, 1 | 2)
	q.exclude = [target.get_rid()]
	q.hit_back_faces = true
	var hit := space.intersect_ray(q)
	return pivot.distance_to(to) if hit.is_empty() else pivot.distance_to(hit.position)


func _place(dt: float) -> void:
	var pivot := target.global_position + cam_up * 0.85
	var right := yaw_dir.cross(cam_up).normalized()
	# Obstruction handling: rise over what blocks the view behind him, then pull in what is left.
	var space := get_world_3d().direct_space_state
	var rise_to := 0.0
	if _clear_len(space, pivot, pitch, right) < distance * 0.6:
		rise_to = RISE_MAX
		for r in RISE_STEPS:
			if _clear_len(space, pivot, minf(pitch + r, PITCH_MAX + 0.25), right) >= distance * 0.85:
				rise_to = r
				break
	_rise = move_toward(_rise, rise_to, dt * (1.6 if rise_to > _rise else 0.6))
	var p_eff := minf(pitch + _rise, PITCH_MAX + 0.25)
	var back := -yaw_dir * cos(p_eff) + cam_up * sin(p_eff)
	var desired := pivot + back * distance + right * shoulder
	var want := minf(distance, maxf(0.6, _clear_len(space, pivot, p_eff, right) - 0.35))
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
		_look = look
		_look_up = u
		return
	global_position = pos
	look_at(look, cam_up)
	_look = look
	_look_up = cam_up


# --- The safety invariant -----------------------------------------------------------------

## Resolves wherever the camera was put this frame (see the class notes). With a target (play,
## cinematics, title) it is also kept out of solids, seen from what it looks at; the aquarium's
## presentation (no target) is kept off the balls' ground.
func _enforce_safe() -> void:
	if not enforce:
		return
	var p0 := global_position
	var anchor := _look if _look != Vector3.INF else p0 - global_basis.z * 3.0
	var p1 := safe_point(p0, anchor, target != null)
	if p1.distance_squared_to(p0) < 1e-8:
		return
	corrected_frames += 1
	global_position = p1
	# (Still looking at what it was looking at.)
	if _look != Vector3.INF and p1.distance_to(_look) > 0.05:
		look_at(_look, _look_up)


## The nearest valid camera place to `p` for looking at `anchor`: out of any solid between them,
## then at least GROUND_CLEAR above the ground of every moss ball, radially (the ball's own local up,
## from its own terrain: slopes, ridges, ravines, plateaus alike). While he is himself under a ball's
## ground surface (a cave or hollow inside it) that ball is left to the solid check.
func safe_point(p: Vector3, anchor: Vector3, solids := true) -> Vector3:
	# (The two rules can move it into each other's way, e.g. pushed up out of the ground into a
	# leaf: applied in turn until it settles, so the place is valid under both.)
	var out := p
	for i in 4:
		var prev := out
		out = _off_ground(out)
		if solids and is_inside_tree():
			out = _out_of_solids(out, anchor)
		out = _off_ground(out)
		if out.distance_squared_to(prev) < 1e-6:
			break
	return out


func _off_ground(p: Vector3) -> Vector3:
	var out := p
	var g := Game.inst
	if g == null:
		return out
	for b: MossBall in g.balls:
		var rel := out - b.global_position
		var d := rel.length()
		if d > b.radius + 80.0 or d < 0.001:
			continue
		if target != null and target.ball == b and target.state == "normal" and b.altitude(target.global_position) < -0.3:
			continue
		var dir := rel / d
		var floor_r := b.radius + b.terrain_height(dir) + GROUND_CLEAR
		if d < floor_r:
			out = b.global_position + dir * floor_r
	return out


## Out of a solid: along the line to the anchor, the first surface met from the camera is a back
## face (or the camera starts inside a convex shape) only when the camera is inside something; it
## then comes out toward the anchor, to just short of where that solid begins.
func _out_of_solids(p: Vector3, anchor: Vector3) -> Vector3:
	var to := anchor - p
	if to.length() < 0.05:
		return p
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(p, anchor, SOLID_MASK)
	q.hit_from_inside = true
	q.hit_back_faces = true
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return p
	var n: Vector3 = hit.normal
	if n != Vector3.ZERO and n.dot(to) <= 0.0:
		return p
	var q2 := PhysicsRayQueryParameters3D.create(anchor, p, SOLID_MASK)
	var h2 := space.intersect_ray(q2)
	if h2.is_empty():
		return p
	return (h2.position as Vector3) + to.normalized() * 0.3


class _Auditor extends Node:
	var cam: FollowCam
	func _process(_dt: float) -> void:
		cam._audit()


## Test runs: the transform about to be drawn, checked against the invariant (any writer, any order).
func _audit() -> void:
	if not is_inside_tree():
		return
	# (Play is drawn through this camera and nothing else: another camera taking over would
	# bypass the invariant.)
	var g0 := Game.inst
	if not current:
		if g0 != null and g0.state == "play" and get_viewport().get_camera_3d() != null and Settings.test_mode != "shots":
			unsafe_drawn += 1
			if unsafe_worst == "":
				unsafe_worst = "another camera drew play: %s" % get_viewport().get_camera_3d().name
		return
	audited_frames += 1
	var p := global_position
	var anchor := _look if _look != Vector3.INF else p - global_basis.z * 3.0
	var ok := safe_point(p, anchor, target != null).distance_to(p) < 0.02
	if not ok:
		unsafe_drawn += 1
		if unsafe_worst == "":
			var g := Game.inst
			var dg := _off_ground(p).distance_to(p)
			var ds := _out_of_solids(p, anchor).distance_to(p) if target != null else 0.0
			unsafe_worst = "%s at %s (state %s, cinematic '%s'; ground off by %.2f m, solid off by %.2f m)" % ["presentation" if target == null else ("cinematic" if cinematic else "follow"), p.round(), g.state if g else "?", g.cinematic if g else "?", dg, ds]

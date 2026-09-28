class_name CaveEel
extends Critter
## An eel living in a crevice in a grotto's wall (docs/ECOSYSTEM.md). Hidden, only its eyes glow
## faintly in the dark cleft. When the axolotl comes near, in front of the crevice and in its line
## of sight, the eyes brighten and bubbles rise (the telegraph, 0.9 s); then it strikes out along the
## line it saw him on, up to STRIKE_REACH, and pulls back. It never leaves the crevice and never
## strikes through rock. While it is out it can be swiped; two hits defeat it (a completion entry).

const NOTICE_R := 4.2
const STRIKE_REACH := 2.3
const ALERT_TIME := 0.9
const STRIKE_TIME := 0.22
const HOLD_TIME := 0.18
const RETRACT_TIME := 0.5
const COOLDOWN := 2.5
const CONTACT_R := 0.55
const SEGS := 7

## Crevice mouth on the wall, and the wall's normal into the cave.
var mouth: Vector3
var normal: Vector3
var state := "hidden"
var state_t := 0.0
var ext := 0.0
## How far this strike reaches: STRIKE_REACH, or less if rock or a ledge is closer along the line.
var reach := STRIKE_REACH
var _dir := Vector3.FORWARD
var _hurt := false
var _mm: MultiMesh
var _segs_mi: MultiMeshInstance3D
var _head: Node3D
var _eye_mat: StandardMaterial3D
var _bubble_t := 0.0


var _probe_from := Vector3.ZERO
var _probe_dir := Vector3.FORWARD
var _probe_len := 10.0


## Lives in the wall found from `from` (inside the cave) along `dir` (see late_place).
func place(p_ball: MossBall, from: Vector3, dir: Vector3, cave_radius: float, seed_v: int) -> void:
	setup(p_ball, "eel", "grotto wall", seed_v)
	hp = 2
	seen_radius = 4.5
	p_ball.add_child(self)
	_probe_from = from
	_probe_dir = dir.normalized()
	_probe_len = cave_radius + 3.0
	mouth = from + _probe_dir * (cave_radius - 1.5)
	normal = -_probe_dir
	global_position = mouth
	_dir = normal
	visible = false


func late_place() -> void:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_probe_from, _probe_from + _probe_dir * _probe_len, SOLID_MASK))
	if not hit.is_empty():
		mouth = hit["position"]
	# The wall faces back into the cave (the surface is two-sided, so its reported normal may not).
	normal = -_probe_dir
	global_position = mouth
	_dir = normal
	visible = true
	_build()
	_pose()


func _build() -> void:
	# The crevice (a dark cleft, visible even when the eel hides), the body as one batch of
	# segments, the head, and the glowing eyes (their own material: they brighten as it notices him).
	var up := ball.up_at(mouth)
	var cleft := Node3D.new()
	add_child(cleft)
	cleft.global_transform = Transform3D(Basis(normal.cross(up).normalized(), up, normal).orthonormalized(), mouth - normal * 0.02)
	Critter.part(Critter.sphere(0.3, 10), Critter.mat(Color(0.02, 0.02, 0.02)), cleft, Vector3.ZERO, Vector3(0.9, 1.3, 0.12))
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = Critter.sphere(0.13, 8)
	_mm.instance_count = SEGS
	for i in SEGS:
		_mm.set_instance_color(i, Color(0.2, 0.26, 0.22) if i % 2 == 0 else Color(0.5, 0.56, 0.4))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.material_override = Critter.vc_mat()
	mmi.top_level = true
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 60.0
	add_child(mmi)
	_segs_mi = mmi
	_head = Node3D.new()
	_head.top_level = true
	add_child(_head)
	Critter.part(Critter.merge([[Critter.sphere(0.17, 10), Color(0.2, 0.26, 0.22), Critter.xf(Vector3.ZERO, Vector3(0.9, 0.75, 1.5))]]), Critter.vc_mat(), _head)
	_eye_mat = Critter.mat(Color(0.9, 0.95, 0.5), Color(0.8, 1.0, 0.3))
	var eyes := []
	for side in [-1.0, 1.0]:
		eyes.append([Critter.sphere(0.045, 6), Color(1, 1, 1), Critter.xf(Vector3(side * 0.1, 0.07, -0.12))])
	Critter.part(Critter.merge(eyes), _eye_mat, _head)


func tick(dt: float) -> void:
	if defeated or _head == null:
		return
	state_t += dt
	var p := player()
	match state:
		"hidden":
			ext = 0.0
			if state_t > 0.2 and _sees(p):
				_go("alert")
				_dir = _aim(p.body_center())
				Sfx.play("eel_bubbles", mouth)
		"alert":
			_bubble_t -= dt
			if _bubble_t <= 0.0:
				_bubble_t = 0.12
				WaterFX.inst.sparkle(mouth + normal * 0.25 + ball.up_at(mouth) * 0.2, Color(0.8, 0.95, 1.0, 0.7), 4, 0.8, 0.05, 0.9)
			if state_t >= ALERT_TIME:
				_go("strike")
				_hurt = false
				var q := PhysicsRayQueryParameters3D.create(mouth + _dir * 0.2, mouth + _dir * (STRIKE_REACH + 0.2), SOLID_MASK)
				var hit := get_world_3d().direct_space_state.intersect_ray(q)
				reach = STRIKE_REACH if hit.is_empty() else maxf(0.0, (hit["position"] as Vector3).distance_to(mouth) - 0.25)
				Sfx.play("eel_strike", mouth)
		"strike":
			ext = reach * clampf(state_t / STRIKE_TIME, 0.0, 1.0)
			_check_contact(p)
			if state_t >= STRIKE_TIME:
				_go("hold")
		"hold":
			ext = reach
			_check_contact(p)
			if state_t >= HOLD_TIME:
				_go("retract")
		"retract":
			ext = reach * (1.0 - clampf(state_t / RETRACT_TIME, 0.0, 1.0))
			if state_t >= RETRACT_TIME:
				_go("cooldown")
		"cooldown":
			ext = 0.0
			if state_t >= COOLDOWN:
				_go("hidden")
	_pose()


func _go(s: String) -> void:
	state = s
	state_t = 0.0


## The axolotl is near, in front of the crevice and in its line of sight (no rock between).
func _sees(p: Axolotl) -> bool:
	if not player_here():
		return false
	var to := p.body_center() - mouth
	if to.length() > NOTICE_R or to.normalized().dot(normal) < 0.2:
		return false
	return not line_blocked(mouth + normal * 0.25, p.body_center())


## Strike direction toward `target`, kept within 50 degrees of the wall's normal.
func _aim(target: Vector3) -> Vector3:
	var d := (target - mouth).normalized()
	var ang := d.angle_to(normal)
	if ang > deg_to_rad(50.0):
		var axis := normal.cross(d).normalized()
		d = normal.rotated(axis, deg_to_rad(50.0))
	# Never out further than open water allows (the strike stops short of rock).
	return d


func _check_contact(p: Axolotl) -> void:
	if _hurt or not player_here():
		return
	if _dist_to_body(p.body_center()) < CONTACT_R:
		_hurt = true
		strike_player(mouth)


func _dist_to_body(pt: Vector3) -> float:
	var a := mouth
	var b := mouth + _dir * ext
	var ab := b - a
	var k := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return pt.distance_to(a + ab * k)


func _pose() -> void:
	if _head == null:
		return
	var up := ball.up_at(mouth)
	var tail := mouth - normal * 0.5
	var head := mouth + _dir * ext - normal * (0.12 if ext < 0.05 else 0.0)
	for i in SEGS:
		var k := float(i + 1) / (SEGS + 1)
		var p := tail.lerp(head, k)
		# A sideways ripple along the body while it is out.
		p += _dir.cross(up).normalized() * sin(k * 9.0 - state_t * 12.0) * 0.06 * clampf(ext, 0.0, 1.0)
		var sc := lerpf(1.1, 0.75, k)
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sc), p))
	_segs_mi.visible = ext > 0.05 and not defeated
	var look := _dir if ext > 0.05 else normal
	_head.global_transform = Transform3D(Basis(look.cross(up).normalized(), up, -look).orthonormalized(), head)
	_head.visible = not defeated
	var glow := 0.25
	if state == "alert":
		glow = 1.0 + 0.8 * sin(state_t * 30.0)
	elif state in ["strike", "hold", "retract"]:
		glow = 1.6
	_eye_mat.emission_energy_multiplier = glow


func is_hidden() -> bool:
	return defeated or state in ["hidden", "cooldown"]


func discover_point() -> Vector3:
	return mouth + _dir * ext


func hittable() -> bool:
	return not defeated and ext > 0.6


func closest_body_point(pt: Vector3) -> Vector3:
	var a := mouth
	var b := mouth + _dir * ext
	var ab := b - a
	var k := clampf((pt - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return a + ab * k


func body_extent() -> float:
	return 0.18


func hit(stages: int, _from_pos: Vector3) -> bool:
	if not hittable():
		return false
	hp -= stages
	WaterFX.inst.sparkle(mouth + _dir * ext, Color(0.8, 1.0, 0.7, 0.9), 10, 1.2, 0.06, 0.6)
	if hp <= 0:
		defeated = true
		ext = 0.0
		_pose()
		Game.inst.critter_defeated(self)
		return true
	# Stung: it pulls straight back in and stays hidden longer.
	_go("retract")
	state_t = RETRACT_TIME * (1.0 - ext / maxf(reach, 0.01))
	return true


func restore_defeated() -> void:
	defeated = true
	ext = 0.0
	_pose()
